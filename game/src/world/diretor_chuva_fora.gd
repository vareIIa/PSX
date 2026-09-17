## Autoload `ChuvaFora`: a chuva fora do carro, Fase 6 do PLANO_AAA_4K
## (criterios A18 e A19).
##
## Um diretor, e nao ligacoes espalhadas, pelo mesmo motivo do `DiretorCeu`:
## `ChunkManager`, `Player`, `Corpo` e a cena da cidade tem trabalho nao
## commitado de outras sessoes. Daqui se monta, por fora e so no MODERNO:
##
##   - `GotasLente` — gota no vidro da camera de fora, so com ceu aberto;
##   - `Goteiras` — nos chunks em volta da camera, na borda de toldo e marquise;
##   - `RastroMolhado` — em todo carro do grupo `carro`;
##   - a roupa do jogador, que encharca com o tempo na chuva e seca devagar.
##
## Gente da rua usa o molhado do mundo (`roupa` no `mat_npc`); o jogador tem
## material proprio, porque so ele entra e sai da chuva na frente da camera.
##
## `--sem-chuva-fora` desliga tudo: e o par das medidas de custo e regressao.
class_name DiretorChuvaFora
extends Node

const PASSO := 0.25
## Chunks em volta da camera que ganham goteira: 1 = o 3 x 3.
const RAIO_CHUNKS := 1
## Segundos de chuva cheia ate a roupa encharcar. Meio minuto: e o tempo de
## atravessar dois quarteiroes sem guarda-chuva e chegar ensopado.
const TEMPO_ENCHARCA := 30.0
## Segundos ate secar, ja abrigado.
const TEMPO_SECA := 300.0
## Laje acima desta altura, sobre a cabeca, ainda conta como abrigo.
const ABRIGO_ATE := 6.0
const RAIO_TETO := 40.0
const MATERIAL_GENTE := "res://resources/materials/mat_npc.tres"

## Quanto o jogador esta encharcado, de 0 a 1.
var encharcado: float = 0.0

var _sem := false
var _relogio := 0.0
var _lente: GotasLente
var _lajes: Dictionary[Vector2i, Array] = {}
var _em_voo: Dictionary[Vector2i, int] = {}
var _prontos: Array[Dictionary] = []
var _mutex := Mutex.new()
var _mat_jogador: ShaderMaterial
var _pele: MeshInstance3D
var _ultimo_escrito := -1.0
var _ativo := false
## `parar()`: a regressao visual precisa de imagem repetivel, e gota na lente
## cai onde o sorteio quer. Parado, nao ha gota nova nem goteira andando.
var _parado := false
## `--encharcado=X` trava a roupa do jogador (captura e bancada).
var _travado := -1.0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--sem-chuva-fora":
			_sem = true
		elif arg.begins_with("--encharcado="):
			_travado = clampf(arg.trim_prefix("--encharcado=").to_float(), 0.0, 1.0)
			encharcado = _travado
	ChunkManager.chunk_descarregado.connect(_chunk_saiu)


func _exit_tree() -> void:
	for id: int in _em_voo.values():
		WorkerThreadPool.wait_for_task_completion(id)


func _process(delta: float) -> void:
	_colher()
	_cuidar_da_roupa(delta)
	_relogio -= delta
	if _relogio > 0.0:
		return
	_relogio = PASSO
	var quer := Settings.luz_por_pixel and not _sem and ChunkManager.ativo \
		and ChunkManager.raiz != null and is_instance_valid(ChunkManager.raiz)
	if quer != _ativo:
		_ativo = quer
		if not quer:
			_desmontar()
	if not quer:
		return
	_cuidar_da_lente()
	_cuidar_das_goteiras()
	_cuidar_dos_carros()


# --- lente --------------------------------------------------------------------

func _cuidar_da_lente() -> void:
	if _lente == null or not is_instance_valid(_lente):
		_lente = GotasLente.new()
		add_child(_lente)
	_lente.forcar = 0 if _parado else -1


# --- goteiras -----------------------------------------------------------------

func _cuidar_das_goteiras() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var centro := ChunkManager.coord_de(camera.global_position)
	for dx in range(-RAIO_CHUNKS, RAIO_CHUNKS + 1):
		for dz in range(-RAIO_CHUNKS, RAIO_CHUNKS + 1):
			var c := centro + Vector2i(dx, dz)
			if _lajes.has(c) or _em_voo.has(c) or not ChunkManager.esta_carregado(c):
				continue
			_em_voo[c] = WorkerThreadPool.add_task(_analisar.bind(c), false,
				"goteiras %d,%d" % [c.x, c.y])
	var forca: float = 0.0 if _parado else Clima.chuva
	for no: Node in get_tree().get_nodes_in_group(&"goteiras"):
		(no as Goteiras).chover(forca)


func _analisar(c: Vector2i) -> void:
	var r := Goteiras.analisar(c.x, c.y)
	_mutex.lock()
	_prontos.append(r)
	_mutex.unlock()


func _colher() -> void:
	if _em_voo.is_empty():
		return
	_mutex.lock()
	var prontos := _prontos.duplicate()
	_prontos.clear()
	_mutex.unlock()
	for r: Dictionary in prontos:
		var c: Vector2i = r["coord"]
		if _em_voo.has(c):
			WorkerThreadPool.wait_for_task_completion(_em_voo[c])
			_em_voo.erase(c)
		var chunk := _chunk(c)
		if chunk == null or not _ativo:
			continue
		_lajes[c] = r["lajes"]
		var pontos: PackedVector3Array = r["pontos"]
		if pontos.is_empty() or chunk.has_node(^"Goteiras"):
			continue
		var g := Goteiras.new()
		g.montar(pontos)
		chunk.add_child(g)
		g.chover(0.0 if _parado else Clima.chuva)


func _chunk_saiu(c: Vector2i) -> void:
	_lajes.erase(c)


func _chunk(c: Vector2i) -> Node3D:
	if ChunkManager.raiz == null or not is_instance_valid(ChunkManager.raiz):
		return null
	return ChunkManager.raiz.get_node_or_null(
		NodePath("chunk_%03d_%03d" % [c.x, c.y])) as Node3D


## Ha toldo, marquise ou laje sobre este ponto? So vale para os chunks em volta
## da camera, que sao os analisados.
func coberto(pos: Vector3) -> bool:
	var c := ChunkManager.coord_de(pos)
	var lajes: Array = _lajes.get(c, [])
	if lajes.is_empty():
		return false
	var local := Vector2(pos.x - c.x * Goteiras.TAM, pos.z - c.y * Goteiras.TAM)
	for laje: Dictionary in lajes:
		var y: float = laje["y"]
		if y <= pos.y or y > pos.y + ABRIGO_ATE:
			continue
		var t: PackedVector2Array = laje["tri"]
		if Geometry2D.point_is_inside_triangle(local, t[0], t[1], t[2]):
			return true
	return false


## Nem laje nem colisao acima do ponto.
func ceu_aberto(pos: Vector3) -> bool:
	if coberto(pos):
		return false
	var mundo := get_viewport().world_3d
	if mundo == null:
		return true
	var q := PhysicsRayQueryParameters3D.create(pos, pos + Vector3.UP * RAIO_TETO, 1)
	return mundo.direct_space_state.intersect_ray(q).is_empty()


## Para a parte viva: sem gota na lente e sem goteira. Para a regressao visual.
func parar() -> void:
	_parado = true
	_relogio = 0.0
	for no: Node in get_tree().get_nodes_in_group(&"goteiras"):
		var g := no as Goteiras
		g.chover(0.0)
		g.restart()


func voltar() -> void:
	_parado = false
	_relogio = 0.0


## Pontos de goteira montados agora, e em quantos chunks. Para bancada.
func censo() -> Dictionary:
	var pontos := 0
	var chunks := 0
	for no: Node in get_tree().get_nodes_in_group(&"goteiras"):
		chunks += 1
		pontos += (no as Goteiras).pontos.size()
	return {"pontos": pontos, "chunks": chunks, "analisados": _lajes.size(),
		"gotas_lente": _lente.quantas() if _lente != null else 0}


# --- carros -------------------------------------------------------------------

func _cuidar_dos_carros() -> void:
	for no: Node in get_tree().get_nodes_in_group(&"carro"):
		var carro := no as Node3D
		if carro == null or carro.has_node(^"RastroMolhado"):
			continue
		var rodas: Array[VehicleWheel3D] = []
		for filho: Node in carro.get_children():
			var roda := filho as VehicleWheel3D
			if roda != null:
				rodas.append(roda)
		# As duas de tras: o `Carro` cria frente nos indices 0 e 1. A de
		# frente passa no mesmo sulco e nao muda o desenho.
		if rodas.size() < 4:
			continue
		var r := RastroMolhado.new()
		carro.add_child(r)
		r.acompanhar(carro, [rodas[2], rodas[3]] as Array[VehicleWheel3D])


# --- roupa do jogador ---------------------------------------------------------

func _cuidar_da_roupa(delta: float) -> void:
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador == null:
		return
	if _travado < 0.0:
		var chove: float = Clima.chuva
		var dirigindo := jogador.has_method(&"dirigindo") and bool(jogador.call(&"dirigindo"))
		var na_chuva := chove > 0.05 and not Interiores.dentro and not dirigindo \
			and _ativo and ceu_aberto(jogador.global_position + Vector3.UP * 1.0)
		if na_chuva:
			encharcado = move_toward(encharcado, 1.0, delta * chove / TEMPO_ENCHARCA)
		else:
			encharcado = move_toward(encharcado, 0.0, delta / TEMPO_SECA)
	_vestir(jogador)


func _vestir(jogador: Node3D) -> void:
	var fonte := load(MATERIAL_GENTE) as ShaderMaterial
	var pele := _achar_pele(jogador)
	if pele == null:
		return
	if not _ativo:
		if pele.material_override == _mat_jogador and _mat_jogador != null:
			pele.material_override = fonte
		return
	# O material do jogador e copia do de todo mundo, refeita quando o estilo
	# troca o shader ou o conjunto de textura da fonte.
	if _mat_jogador == null or _mat_jogador.shader != fonte.shader \
			or _mat_jogador.get_shader_parameter(&"usa_hd") != fonte.get_shader_parameter(&"usa_hd"):
		_mat_jogador = fonte.duplicate() as ShaderMaterial
		_ultimo_escrito = -1.0
	if pele.material_override != _mat_jogador:
		pele.material_override = _mat_jogador
	if absf(encharcado - _ultimo_escrito) >= 0.005:
		_ultimo_escrito = encharcado
		_mat_jogador.set_shader_parameter(&"encharcado", encharcado)


func _achar_pele(jogador: Node3D) -> MeshInstance3D:
	if _pele != null and is_instance_valid(_pele) and _pele.is_inside_tree() \
			and jogador.is_ancestor_of(_pele):
		return _pele
	_pele = null
	if not jogador.has_method(&"figura"):
		return null
	var figura := jogador.call(&"figura") as Node
	if figura == null:
		return null
	_pele = figura.find_child("Pele", true, false) as MeshInstance3D
	return _pele


func _desmontar() -> void:
	if _lente != null and is_instance_valid(_lente):
		_lente.queue_free()
	_lente = null
	for no: Node in get_tree().get_nodes_in_group(&"goteiras"):
		no.queue_free()
	for no: Node in get_tree().get_nodes_in_group(&"carro"):
		var r := no.get_node_or_null(^"RastroMolhado")
		if r != null:
			r.queue_free()
	_lajes.clear()
