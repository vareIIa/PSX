## Uma sala que existe NA RUA, atras da propria porta.
##
## Por que isto existe
## -------------------
## Toda porta do jogo abria para um painel de reboco cinza, e o comodo era
## montado dois mil metros acima da cidade, atras de uma cortina preta. Aqui a
## planta e a mesma (o mesmo CasaFumacaBuilder, os mesmos props), so que montada
## em coordenada de rua, no lote que o ChunkBuilder reservou atras do vao. O que
## se ve pela porta aberta e a sala, porque ela esta la.
##
## Os tres degraus
## ---------------
##   casca        sempre, com o chunk: paredes de fora, telhado, fachada vazada
##   pre-aquecida jogador a PREAQUECER: dados na thread, malha num quadro, um
##                prop por quadro depois dele; gente parada em pose, sem IA
##   ativa        jogador a ATIVAR ou dentro: IA, teto de chuva, soleira
##
## Montar a planta custa 2,5 ms na thread (medido). O que engasga e NASCER —
## gente, luz, shader — e por isso isso acontece longe, um por quadro, e nao no
## instante em que a porta abre.
##
## A soleira
## ---------
## Nao ha teleporte, entao "entrar" e cruzar a faixa `SOLEIRA` andando. A nevoa
## e o ambiente da casa se misturam com os da rua pela posicao do jogador nela
## (FogPreset.misturar), e `Interiores` e avisado na metade — missao, HUD e GPS
## reagem igual reagiam a porta teleportada.
class_name InteriorNoMundo
extends Node3D

## Camada de desenho de tudo que e de dentro de uma casa da rua.
##
## Luz de dentro so acende o que e de dentro, e luz de rua (poste, sol, lua) nao
## acende o que e de dentro. Sem sombra ligada, uma Omni atravessa parede: a
## lampada magenta do som pintaria a calcada, e o poste da esquina, o piso da
## sala. Camada 11 porque nenhuma outra do projeto a usa.
const CAMADA := 1 << 10

## Distancias da porta, em metros.
const PREAQUECER := 32.0
const DESCARREGAR := 48.0
const ATIVAR := 9.0
## Passo da reavaliacao de distancia. Soleira e nevoa correm todo quadro.
const PASSO := 0.2

## A faixa da soleira em Z de planta: antes dela e rua, depois e casa. Comeca
## meio metro FORA da parede, que e onde o ar da sala ja chega pela porta.
const SOLEIRA := Vector2(-0.7, 1.1)
## Menor mudanca de peso que vale reaplicar o ambiente. O FogController refaz o
## Environment inteiro a cada troca; vinte trocas numa travessia bastam.
const PASSO_PESO := 0.05

const SHADER_SUPERFICIE := "res://shaders/psx_surface_pixel.gdshader"

@export var planta: StringName = &"casa_fumaca"
@export var semente: int = 0

var _tarefa: int = -1
var _mutex := Mutex.new()
var _pronto: Dictionary = {}
var _dados: Dictionary = {}
var _conteudo: Node3D
var _fila: Array[Dictionary] = []
var _relogio: float = 0.0
var _ativa: bool = false
var _dentro: bool = false
var _peso: float = 0.0
var _forcei: bool = false
var _preset_casa: FogPreset
var _teto: TetoChuva


func _ready() -> void:
	add_to_group(&"interior_mundo")
	get_tree().node_added.connect(_ao_nascer)
	# Voltando de um comodo teleportado (a estufa, pela porta dos fundos) o
	# FogController foi liberado por `Interiores.sair`; o ambiente da casa tem de
	# ser reescrito mesmo sem o peso mudar.
	Interiores.saiu.connect(_ao_sair_de_comodo)


func _ao_sair_de_comodo() -> void:
	_forcei = false
	_peso = -1.0
	# Quem saiu foi o comodo teleportado: a soleira tem de anunciar a sala de
	# novo, mesmo que o jogador tenha reaparecido do lado de dentro dela.
	if not Interiores.no_mundo:
		_dentro = false


func _exit_tree() -> void:
	if _tarefa >= 0:
		WorkerThreadPool.wait_for_task_completion(_tarefa)
		_tarefa = -1
	if _dentro:
		_dentro = false
		Interiores.sair_do_mundo(self)
	_liberar_ambiente()
	_abrigar_chuva(0.0)


func _process(delta: float) -> void:
	_colher_tarefa()
	if not _fila.is_empty():
		_nascer_um()

	_relogio += delta
	if _relogio >= PASSO:
		_relogio = 0.0
		_reavaliar()
	if _ativa:
		_soleira()


# --- degraus ------------------------------------------------------------------

## De onde se mede a distancia. Dentro de um comodo teleportado a partir daqui
## (a estufa), o corpo do jogador esta dois mil metros acima; o que conta e onde
## ele vai reaparecer — a sala —, senao ela descarregaria nas costas dele.
func _referencia() -> Vector3:
	if Interiores.isolado():
		return Interiores.posicao_de_retorno()
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	return jogador.global_position if jogador != null else Vector3.INF


func _reavaliar() -> void:
	var ref := _referencia()
	if ref == Vector3.INF:
		return
	var porta := to_global(KitFumaca.centro_do_vao())
	var d := Vector2(ref.x - porta.x, ref.z - porta.z).length()

	var montada := _conteudo != null or _tarefa >= 0
	if not montada and d <= PREAQUECER:
		_tarefa = WorkerThreadPool.add_task(_construir.bind(planta, semente),
			false, "interior_no_mundo")
	elif montada and d > DESCARREGAR and not _dentro:
		_descarregar()
		return

	# Dentro do lote conta como perto, qualquer que seja a distancia da porta: a
	# casa tem 15 m de fundo, e quem carrega um save na cozinha ou volta da
	# estufa pela porta dos fundos esta a mais de ATIVAR da porta da rua sem
	# nunca ter cruzado a soleira.
	_ativar(_conteudo != null and (d <= ATIVAR or _dentro or _no_lote(to_local(ref))))


func _construir(tipo: StringName, s: int) -> void:
	var d := Interiores.planta_de(tipo, s)
	_mutex.lock()
	_pronto = d
	_mutex.unlock()


func _colher_tarefa() -> void:
	if _tarefa < 0:
		return
	_mutex.lock()
	var d := _pronto
	_mutex.unlock()
	if d.is_empty():
		return
	WorkerThreadPool.wait_for_task_completion(_tarefa)
	_tarefa = -1
	_pronto = {}
	_dados = d
	_montar_malhas()


## A malha e a colisao da sala, num quadro so. Sao nove superficies e dezenove
## caixas: 0,13 ms medidos. Os props vao para a fila.
func _montar_malhas() -> void:
	_conteudo = Node3D.new()
	_conteudo.name = "Sala"
	add_child(_conteudo)

	var superficies: Dictionary = _dados["superficies"]
	for material: StringName in superficies:
		var d: Dictionary = superficies[material]
		if PSXMesh.dados_vazio(d):
			continue
		var mi := MeshInstance3D.new()
		mi.name = String(material)
		mi.mesh = PSXMesh.dados_para_mesh(d)
		mi.material_override = Interiores.material(material)
		mi.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if Interiores.projeta(material)
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		_conteudo.add_child(mi)

	var corpo := StaticBody3D.new()
	corpo.name = "Colisao"
	for caixa: Dictionary in _dados["colisao"]:
		var forma := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = caixa["tamanho"]
		forma.shape = box
		forma.position = caixa["pos"]
		corpo.add_child(forma)
	_conteudo.add_child(corpo)

	# O diretor da casa: caminho, usos e a porta. Entra ANTES dos props, porque
	# cada convidado se apresenta a ele no proprio _ready.
	var casa := CasaViva.new()
	casa.name = "CasaViva"
	_conteudo.add_child(casa)
	casa.montar(_dados, self)
	var porta := _porta_da_rua()
	if porta != null:
		casa.ligar_porta(porta)

	_fila.clear()
	for prop: Dictionary in _dados["props"]:
		_fila.append(prop)
	var caminho := String(_dados.get("ambiente", ""))
	_preset_casa = load(caminho) as FogPreset if ResourceLoader.exists(caminho) else null


## A porta de verdade que da para este vao: a Porta do chunk mais perto dele.
func _porta_da_rua() -> Porta:
	var vao := to_global(KitFumaca.centro_do_vao())
	for no: Node in get_tree().get_nodes_in_group(&"porta"):
		var p := no as Porta
		if p != null and p.mundo and p.global_position.distance_to(vao) < 2.0:
			return p
	return null


## O jogador ja cruzou a soleira.
func jogador_dentro() -> bool:
	return _dentro


## Um prop por quadro. A casa da fumaca tem 23: meio segundo a sessenta quadros,
## e o jogador ainda esta a trinta metros.
func _nascer_um() -> void:
	if _conteudo == null:
		_fila.clear()
		return
	var prop: Dictionary = _fila.pop_front()
	var no := Interiores.criar_prop(prop)
	if no == null:
		return
	if no is ItemNoChao:
		# O item e registrado pela semente do comodo, e `Interiores` so conhece a
		# do comodo teleportado em vigor. Sem isto, pegar o remedio da bancada
		# gravava a coleta na ficha de outra casa e ele voltava na proxima visita.
		(no as ItemNoChao).chunk = Vector2i(semente, WorldState.INTERIOR)
	_conteudo.add_child(no)
	if no is Convidado and not _ativa:
		no.process_mode = Node.PROCESS_MODE_DISABLED
	if _fila.is_empty():
		_sonda_da_casa()


## Sonda de reflexo da casa, feita uma vez quando o ultimo prop nasce.
##
## So depois do ultimo: a sonda fotografa o comodo no quadro em que entra, e
## antes disso as luminarias ainda nao existem — o reflexo sairia de uma sala
## apagada. `interior` tira o ceu da conta, e a projecao em caixa faz o reflexo
## no taco cair no lugar da luminaria, e nao no infinito. Camada propria nas
## duas pontas, como a luz: a rua nao entra no reflexo da sala.
func _sonda_da_casa() -> void:
	if _conteudo == null or not Settings.luz_por_pixel:
		return
	if _conteudo.get_node_or_null(^"SondaDaCasa") != null:
		return
	var alto := CasaFumacaBuilder.ALTURA
	var p := ReflectionProbe.new()
	p.name = "SondaDaCasa"
	p.size = Vector3(CasaFumacaBuilder.LARGURA, alto, CasaFumacaBuilder.FUNDO)
	p.position = Vector3(CasaFumacaBuilder.LARGURA * 0.5, alto * 0.5,
		CasaFumacaBuilder.FUNDO * 0.5)
	p.origin_offset = Vector3(0.0, 1.5 - alto * 0.5, 0.0)
	p.interior = true
	p.box_projection = true
	p.enable_shadows = true
	p.max_distance = 20.0
	p.ambient_mode = ReflectionProbe.AMBIENT_ENVIRONMENT
	p.cull_mask = CAMADA
	p.reflection_mask = CAMADA
	p.update_mode = ReflectionProbe.UPDATE_ONCE
	_conteudo.add_child(p)


func _descarregar() -> void:
	_ativar(false)
	_fila.clear()
	if _conteudo != null:
		_conteudo.queue_free()
		_conteudo = null
	_dados = {}
	_liberar_ambiente()


func _ativar(sim: bool) -> void:
	if sim == _ativa:
		return
	_ativa = sim
	if _conteudo != null:
		for no: Node in _conteudo.get_children():
			if no is Convidado:
				no.process_mode = (Node.PROCESS_MODE_INHERIT if sim
					else Node.PROCESS_MODE_DISABLED)
	if sim:
		_marcar_jogador()
		_teto = TetoChuva.new()
		_teto.name = "TetoChuva"
		_teto.dono = self
		# A caixa inteira do lote, do chao ao ceu: chuva nao cai dentro de casa.
		_teto.teto = {
			"min": Vector3(-KitFumaca.PAREDE, -1.0, -KitFumaca.PAREDE),
			"max": Vector3(CasaFumacaBuilder.LARGURA + KitFumaca.PAREDE, 60.0,
				CasaFumacaBuilder.FUNDO + KitFumaca.PAREDE),
		}
		add_child(_teto)
	else:
		if _teto != null:
			_teto.queue_free()
			_teto = null
		if _dentro:
			_dentro = false
			Interiores.sair_do_mundo(self)
		_abrigar_chuva(0.0)
		_liberar_ambiente()


# --- soleira ------------------------------------------------------------------

static func _no_lote(p: Vector3) -> bool:
	return p.x > -0.3 and p.x < CasaFumacaBuilder.LARGURA + 0.3 		and p.z > 0.0 and p.z < CasaFumacaBuilder.FUNDO + 0.3 		and p.y > -1.5 and p.y < 3.5


func _soleira() -> void:
	if Interiores.isolado():
		return
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador == null:
		return
	var p := to_local(jogador.global_position)
	var peso := 0.0
	var dentro_do_lote := p.x > -0.3 and p.x < CasaFumacaBuilder.LARGURA + 0.3 \
		and p.z < CasaFumacaBuilder.FUNDO + 0.3 and p.y > -1.5 and p.y < 3.5
	if dentro_do_lote:
		peso = smoothstep(SOLEIRA.x, SOLEIRA.y, p.z)

	var dentro := peso >= 0.5
	if dentro != _dentro:
		_dentro = dentro
		if dentro:
			var porta := Transform3D(global_transform.basis,
				to_global(KitFumaca.centro_do_vao()))
			Interiores.entrar_no_mundo(self, planta, semente, porta)
		else:
			Interiores.sair_do_mundo(self)

	_abrigar_chuva(peso)
	if absf(peso - _peso) >= PASSO_PESO or (peso <= 0.0 and _peso > 0.0) \
			or (peso >= 1.0 and _peso < 1.0):
		_peso = peso
		_aplicar_ambiente(peso)


func _aplicar_ambiente(peso: float) -> void:
	var fog := get_tree().get_first_node_in_group(&"fog_controller") as FogController
	if fog == null or _preset_casa == null:
		return
	if peso <= 0.0:
		_liberar_ambiente()
		return
	fog.forcar_preset(FogPreset.misturar(Settings.fog_preset(), _preset_casa, peso))
	_forcei = true


func _liberar_ambiente() -> void:
	if not _forcei:
		return
	_forcei = false
	_peso = 0.0
	var fog := get_tree().get_first_node_in_group(&"fog_controller") as FogController
	if fog != null:
		fog.liberar()


## O som da chuva atravessando o telhado. `Chuva.abrigo` e o mesmo que a cabine
## do carro usa: a chuva continua caindo e sendo ouvida, so que abafada.
func _abrigar_chuva(peso: float) -> void:
	for no: Node in get_tree().get_nodes_in_group(&"chuva"):
		var ch := no as Chuva
		if ch != null:
			ch.abrigo = peso


# --- camadas ------------------------------------------------------------------

func _ao_nascer(no: Node) -> void:
	if _conteudo != null and _conteudo.is_ancestor_of(no):
		_marcar(no)


## Tudo de dentro vai para a CAMADA, e toda luz de dentro so acende a CAMADA. A
## malha da sala e abrigada da chuva por instancia: o material e o mesmo de
## qualquer comodo, mas o piso desta casa continua seco com a rua encharcando.
func _marcar(no: Node) -> void:
	if no is Light3D:
		(no as Light3D).light_cull_mask = CAMADA
	elif no is GeometryInstance3D:
		var g := no as GeometryInstance3D
		g.layers = CAMADA
		var mat := g.material_override as ShaderMaterial
		if mat != null and mat.shader != null \
				and mat.shader.resource_path == SHADER_SUPERFICIE:
			g.set_instance_shader_parameter(&"abrigo", 1.0)


## O jogador e visto pelas duas luzes: a da rua e a da casa.
func _marcar_jogador() -> void:
	var jogador := get_tree().get_first_node_in_group(&"player")
	if jogador == null:
		return
	var pilha: Array[Node] = [jogador]
	while not pilha.is_empty():
		var n: Node = pilha.pop_back()
		if n is GeometryInstance3D:
			(n as GeometryInstance3D).layers |= CAMADA
		pilha.append_array(n.get_children())
