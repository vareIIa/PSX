## Autoload. Carrega e descarrega a cidade em pedacos de 32 m em volta do jogador.
##
## Dois raios diferentes, e a diferenca importa:
##
##   raio de carga    quantos chunks existem na memoria. Vem do preset de nevoa,
##                    porque nevoa e o sistema de oclusao do jogo.
##   raio de render   ate onde a malha e efetivamente desenhada. Vem do fim da
##                    nevoa, sempre menor. Chunk carregado alem disso continua
##                    existindo, com colisao, mas nao entra em draw call.
##
## Sem o segundo raio a conta nao fecha: no preset leve sao 49 chunks carregados,
## e desenhar todos passaria de 90 mil triangulos contra um teto de 25 mil. Com
## ele, a nevoa esconde o corte e o custo cai para o que da para pagar.
##
## A construcao roda em WorkerThreadPool. O ChunkBuilder devolve dados puros, e so
## a criacao de ArrayMesh e dos nos acontece na thread principal, no maximo um
## chunk por frame, porque criar recurso de renderizacao fora dela nao e seguro.
extends Node

const TAM := 32.0
const MAT_DIR := "res://resources/materials/mat_%s.tres"

## Histerese: descarrega um anel alem do que carrega, senao andar em cima da
## fronteira faz o mesmo chunk carregar e descarregar a cada passo.
const FOLGA_DESCARGA := 1

## Teto de construcoes simultaneas na piscina de threads.
const MAX_EM_VOO := 4

signal chunk_carregado(coord: Vector2i)
signal chunk_descarregado(coord: Vector2i)

## Raiz onde os chunks sao pendurados. Definida pela cena da cidade.
var raiz: Node3D
## Node3D seguido pelo streaming. Vazio faz o gerenciador procurar pelo grupo.
var alvo: Node3D

var ativo: bool = false

var _carregados: Dictionary[Vector2i, Node3D] = {}
## coord -> id da tarefa na piscina. Precisa do id para esperar no desligamento.
var _em_voo: Dictionary[Vector2i, int] = {}
var _prontos: Array[Dictionary] = []
var _mutex := Mutex.new()

var _materiais: Dictionary[StringName, ShaderMaterial] = {}
var _coord_atual := Vector2i(2147483647, 0)
var _raio_carga: int = 2
var _alcance_render: float = 26.0

# Estatisticas, lidas pelo overlay de debug e pela verificacao automatizada.
var tris_carregados: int = 0
var construcoes: int = 0


func _ready() -> void:
	KitModular.preparar()
	Settings.changed.connect(_aplicar_preset)
	_aplicar_preset()
	set_process(false)


## Liga o streaming numa cena. Chame depois de definir `raiz`.
func iniciar(nova_raiz: Node3D, novo_alvo: Node3D = null) -> void:
	raiz = nova_raiz
	alvo = novo_alvo
	ativo = true
	_coord_atual = Vector2i(2147483647, 0)
	set_process(true)


func parar() -> void:
	ativo = false
	set_process(false)
	aguardar_tarefas()
	for coord: Vector2i in _carregados.keys():
		_descarregar(coord)
	_prontos.clear()


## Espera toda tarefa em voo terminar.
##
## Sem isso o motor desliga com thread ainda mexendo em dado do jogo, e sai uma
## enxurrada de RID vazado e string estatica sem referencia no fim da execucao.
## O erro nao aparece durante o jogo, so no encerramento, que e onde ninguem olha.
func aguardar_tarefas() -> void:
	for coord: Vector2i in _em_voo.keys():
		var id: int = _em_voo[coord]
		if id >= 0:
			WorkerThreadPool.wait_for_task_completion(id)
	_em_voo.clear()
	_mutex.lock()
	_prontos.clear()
	_mutex.unlock()


func _exit_tree() -> void:
	aguardar_tarefas()


func _aplicar_preset() -> void:
	var preset := Settings.fog_preset()
	_raio_carga = maxi(1, ceili(preset.stream_radius / TAM))
	# Um pouco alem do fim da nevoa, para o chunk aparecer ja apagado pela nevoa
	# em vez de surgir na cara do jogador.
	_alcance_render = (preset.fog_end * 1.5) if preset.fog_enabled else preset.stream_radius
	for coord: Vector2i in _carregados:
		_aplicar_alcance(_carregados[coord])
	# Forca reavaliacao do conjunto desejado no proximo frame.
	_coord_atual = Vector2i(2147483647, 0)


func coord_de(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / TAM), floori(pos.z / TAM))


func chunks_carregados() -> int:
	return _carregados.size()


func _process(_delta: float) -> void:
	if not ativo or raiz == null:
		return
	if alvo == null:
		alvo = get_tree().get_first_node_in_group(&"player") as Node3D
		if alvo == null:
			return

	var coord := coord_de(alvo.global_position)
	if coord != _coord_atual:
		_coord_atual = coord
		_descarregar_distantes(coord)

	# Preenche todo frame, nao so quando o jogador troca de chunk. So na troca, a
	# fila enche uma vez ate o teto de tarefas em voo e para ali: o jogador ficava
	# parado no meio de quatro chunks e o resto da cidade nunca chegava.
	_preencher(coord)
	_materializar_um()


## Pede os chunks que faltam, do mais perto para o mais longe. O jogador olha
## para o que esta perto, entao e esse que nao pode faltar.
func _preencher(centro: Vector2i) -> void:
	if _em_voo.size() >= MAX_EM_VOO:
		return

	var faltando: Array[Vector2i] = []
	for dz in range(-_raio_carga, _raio_carga + 1):
		for dx in range(-_raio_carga, _raio_carga + 1):
			var c := centro + Vector2i(dx, dz)
			if not _carregados.has(c) and not _em_voo.has(c):
				faltando.append(c)
	if faltando.is_empty():
		return

	faltando.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - centro).length_squared() < (b - centro).length_squared())

	for c: Vector2i in faltando:
		if _em_voo.size() >= MAX_EM_VOO:
			break
		_pedir(c)


func _descarregar_distantes(centro: Vector2i) -> void:
	var limite := _raio_carga + FOLGA_DESCARGA
	for c: Vector2i in _carregados.keys():
		var d := c - centro
		if absi(d.x) > limite or absi(d.y) > limite:
			_descarregar(c)


func _pedir(coord: Vector2i) -> void:
	_em_voo[coord] = WorkerThreadPool.add_task(
		_tarefa.bind(coord), false, "chunk %d,%d" % [coord.x, coord.y])


## Roda fora da thread principal. Nao pode tocar em no nem em recurso.
func _tarefa(coord: Vector2i) -> void:
	var dados := ChunkBuilder.construir(coord.x, coord.y)
	dados["coord"] = coord
	_mutex.lock()
	_prontos.append(dados)
	_mutex.unlock()


## No maximo um chunk por frame vira no. Instanciar em lote engasga a imagem, e
## engasgo e justamente o que a Fase 3 promete nao ter.
func _materializar_um() -> void:
	_mutex.lock()
	var dados: Dictionary = _prontos.pop_front() if not _prontos.is_empty() else {}
	_mutex.unlock()
	if dados.is_empty():
		return

	var coord: Vector2i = dados["coord"]
	_em_voo.erase(coord)

	# Pode ter saido do alcance enquanto a thread trabalhava.
	if absi(coord.x - _coord_atual.x) > _raio_carga + FOLGA_DESCARGA \
			or absi(coord.y - _coord_atual.y) > _raio_carga + FOLGA_DESCARGA:
		return
	if _carregados.has(coord):
		return

	_carregados[coord] = _montar(coord, dados)
	construcoes += 1
	tris_carregados += int(dados["triangulos"])
	chunk_carregado.emit(coord)


func _montar(coord: Vector2i, dados: Dictionary) -> Node3D:
	var no := Node3D.new()
	no.name = "chunk_%03d_%03d" % [coord.x, coord.y]
	no.position = Vector3(coord.x * TAM, 0.0, coord.y * TAM)
	no.set_meta(&"triangulos", dados["triangulos"])

	var superficies: Dictionary = dados["superficies"]
	for material: StringName in superficies:
		var d: Dictionary = superficies[material]
		if PSXMesh.dados_vazio(d):
			continue
		var mi := MeshInstance3D.new()
		mi.name = String(material)
		mi.mesh = PSXMesh.dados_para_mesh(d)
		mi.material_override = _material(material)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		no.add_child(mi)

	var corpo := StaticBody3D.new()
	corpo.name = "Colisao"
	for caixa: Dictionary in dados["colisao"]:
		var forma := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = caixa["tamanho"]
		forma.shape = box
		forma.position = caixa["pos"]
		if caixa.has("giro"):
			forma.rotation = caixa["giro"]
		corpo.add_child(forma)
	no.add_child(corpo)

	for prop: Dictionary in dados["props"]:
		var criado := _criar_prop(prop)
		if criado != null:
			no.add_child(criado)

	raiz.add_child(no)
	_aplicar_alcance(no)
	return no


func _criar_prop(prop: Dictionary) -> Node3D:
	if prop.get("tipo", "") != "lampada":
		push_warning("ChunkManager: prop desconhecido '%s'" % prop.get("tipo", ""))
		return null

	var l := Lampada.new()
	l.position = prop["pos"]
	l.padrao = prop["padrao"]
	l.semente = prop["semente"]
	l.cor = prop.get("cor", Color("ffb763"))
	l.energia = prop.get("energia", 3.6)
	l.alcance = prop.get("alcance", 11.5)
	l.facho_visivel = prop.get("facho", true)
	l.raio_base = 3.2
	l.altura_facho = 6.2
	return l


## Corta o desenho no fim da nevoa. A malha continua carregada e com colisao.
func _aplicar_alcance(no: Node3D) -> void:
	for filho: Node in no.get_children():
		if filho is GeometryInstance3D:
			(filho as GeometryInstance3D).visibility_range_end = _alcance_render


func _descarregar(coord: Vector2i) -> void:
	var no: Node3D = _carregados.get(coord)
	if no == null:
		return
	tris_carregados -= int(no.get_meta(&"triangulos", 0))
	_carregados.erase(coord)
	no.queue_free()
	chunk_descarregado.emit(coord)


func _material(nome: StringName) -> ShaderMaterial:
	if _materiais.has(nome):
		return _materiais[nome]
	var caminho := MAT_DIR % nome
	if not ResourceLoader.exists(caminho):
		push_error("ChunkManager: material ausente %s" % caminho)
		return null
	var m := load(caminho) as ShaderMaterial
	_materiais[nome] = m
	return m
