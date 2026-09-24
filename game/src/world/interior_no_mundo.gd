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
## Camada da estufa debaixo da casa da fumaca.
##
## Propria, e nao a da casa, pelo mesmo motivo que a casa tem uma: sem sombra, a
## luz atravessa laje. Os seis refletores da lavoura estao 1,2 m abaixo do piso
## da sala e alcancam 5 m — na camada da casa, a sala inteira acenderia de branco
## por baixo do sofa, e a TV magenta pintaria o forro da estufa. Camada 12.
const CAMADA_ESTUFA := 1 << 11

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
## A estufa pendurada debaixo da casa, quando a planta tem uma.
var _estufa: Node3D
var _preset_estufa: FogPreset
## Quanto do ar da estufa ja esta aplicado (0 na casa, 1 la embaixo).
var _peso_estufa: float = 0.0
## O corpo de colisao do chunk, que o jogador atravessa descendo a escada. Ver
## `_furar_o_chao`.
var _chao_do_chunk: CollisionObject3D
var _chao_furado: bool = false


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
	_furar_o_chao(false)
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
	var porta := to_global(LoteNoMundo.centro_do_vao(planta))
	var d := Vector2(ref.x - porta.x, ref.z - porta.z).length()

	# As distancias sao da planta: a casa da fumaca tem porta de madeira e 9 m
	# bastam; o mercado e vitrine e acorda de longe (LoteNoMundo).
	var preaquecer := LoteNoMundo.preaquecer(planta)
	var montada := _conteudo != null or _tarefa >= 0
	if not montada and d <= preaquecer:
		_tarefa = WorkerThreadPool.add_task(_construir.bind(planta, semente),
			false, "interior_no_mundo")
	elif montada and d > preaquecer + (DESCARREGAR - PREAQUECER) and not _dentro:
		_descarregar()
		return

	# Dentro do lote conta como perto, qualquer que seja a distancia da porta: a
	# casa tem 15 m de fundo, e quem carrega um save na cozinha ou volta da
	# estufa pela porta dos fundos esta a mais de ATIVAR da porta da rua sem
	# nunca ter cruzado a soleira.
	_ativar(_conteudo != null and (d <= LoteNoMundo.ativar(planta) or _dentro
		or _no_lote(to_local(ref))))


func _construir(tipo: StringName, s: int) -> void:
	var d := LoteNoMundo.planta_de(tipo, s)
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

	_conteudo.add_child(corpo_de_caixas(_dados["colisao"]))
	_montar_estufa()

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
		_fila.append({"prop": prop, "pai": _conteudo})
	if _estufa != null:
		var de_la: Dictionary = _dados["estufa"]["dados"]
		for prop: Dictionary in de_la["props"]:
			_fila.append({"prop": prop, "pai": _estufa})
	var caminho := String(_dados.get("ambiente", ""))
	_preset_casa = load(caminho) as FogPreset if ResourceLoader.exists(caminho) else null


## Colisao em caixas; `giro` (euler) para a rampa da escada.
static func corpo_de_caixas(caixas: Array) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.name = "Colisao"
	for caixa: Dictionary in caixas:
		var forma := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = caixa["tamanho"]
		forma.shape = box
		forma.position = caixa["pos"]
		if caixa.has("giro"):
			forma.rotation = caixa["giro"]
		corpo.add_child(forma)
	return corpo


## A estufa debaixo da casa (CasaFumacaBuilder, `estufa`): um no com a pose
## dela, as malhas e a colisao. Os props vao para a mesma fila dos da casa, com
## este no de pai — e por isso os fazendeiros la de baixo nao acham a CasaViva
## da sala (Convidado procura a do proprio pai) e nao sobem para o sofa.
func _montar_estufa() -> void:
	_estufa = null
	if not _dados.has("estufa"):
		return
	var e: Dictionary = _dados["estufa"]
	var d: Dictionary = e["dados"]
	_estufa = Node3D.new()
	_estufa.name = "Estufa"
	_estufa.transform = e["xform"]
	_conteudo.add_child(_estufa)
	var superficies: Dictionary = d["superficies"]
	for material: StringName in superficies:
		var sd: Dictionary = superficies[material]
		if PSXMesh.dados_vazio(sd):
			continue
		var mi := MeshInstance3D.new()
		mi.name = String(material)
		mi.mesh = PSXMesh.dados_para_mesh(sd)
		mi.material_override = Interiores.material(material)
		mi.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if Interiores.projeta(material)
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		_estufa.add_child(mi)
	_estufa.add_child(corpo_de_caixas(d["colisao"]))
	var caminho := String(d.get("ambiente", ""))
	_preset_estufa = load(caminho) as FogPreset if ResourceLoader.exists(caminho) else null


## O no da estufa desta casa, ou nulo.
func estufa() -> Node3D:
	return _estufa


## A casa montada e com todos os props nascidos.
func pronta() -> bool:
	return _conteudo != null and _fila.is_empty() and _tarefa < 0


## A porta de verdade que da para este vao: a Porta do chunk mais perto dele.
func _porta_da_rua() -> Porta:
	var vao := to_global(LoteNoMundo.centro_do_vao(planta))
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
	var vez: Dictionary = _fila.pop_front()
	var prop: Dictionary = vez["prop"]
	var pai := vez["pai"] as Node3D
	if not is_instance_valid(pai):
		return
	var no := Interiores.criar_prop(prop)
	if no == null:
		return
	if no is ItemNoChao:
		# O item e registrado pela semente do comodo, e `Interiores` so conhece a
		# do comodo teleportado em vigor. Sem isto, pegar o remedio da bancada
		# gravava a coleta na ficha de outra casa e ele voltava na proxima visita.
		(no as ItemNoChao).chunk = Vector2i(semente, WorldState.INTERIOR)
	pai.add_child(no)
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
	var sala := LoteNoMundo.sala(planta)
	var alto := sala.y
	var p := ReflectionProbe.new()
	p.name = "SondaDaCasa"
	p.size = Vector3(sala.x, alto, sala.z)
	p.position = Vector3(sala.x * 0.5, alto * 0.5, sala.z * 0.5)
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
		var gente: Array[Node] = _conteudo.get_children()
		if _estufa != null:
			gente.append_array(_estufa.get_children())
		for no: Node in gente:
			if no is Convidado:
				no.process_mode = (Node.PROCESS_MODE_INHERIT if sim
					else Node.PROCESS_MODE_DISABLED)
	if sim:
		_marcar_jogador()
		_teto = TetoChuva.new()
		_teto.name = "TetoChuva"
		_teto.dono = self
		# A caixa inteira do lote, do chao ao ceu: chuva nao cai dentro de casa.
		# Com estufa, do fundo do poco ao ceu e ate o fim do puxadinho.
		var caixa := LoteNoMundo.caixa(planta)
		_teto.teto = {"min": caixa.position, "max": caixa.end}
		add_child(_teto)
	else:
		if _teto != null:
			_teto.queue_free()
			_teto = null
		if _dentro:
			_dentro = false
			Interiores.sair_do_mundo(self)
		_furar_o_chao(false)
		_abrigar_chuva(0.0)
		_liberar_ambiente()


# --- soleira ------------------------------------------------------------------

func _no_lote(p: Vector3) -> bool:
	return LoteNoMundo.no_lote(planta, p)


func _soleira() -> void:
	if Interiores.isolado():
		return
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador == null:
		return
	var p := to_local(jogador.global_position)
	var peso := 0.0
	# Sem limite na frente: a calcada inteira conta, e quem decide e a faixa da
	# soleira. O resto da caixa do lote separa a loja da rua do lado.
	var embaixo := LoteNoMundo.embaixo(planta, p)
	if embaixo:
		# Na escada ou na estufa, a casa inteira ja ficou para tras. A ponta norte
		# da estufa passa por baixo da calcada, e ali a faixa da soleira diria
		# "rua" a trinta metros de profundidade.
		peso = 1.0
	elif LoteNoMundo.no_lote(planta, p, INF):
		peso = smoothstep(SOLEIRA.x, SOLEIRA.y, p.z)
	_furar_o_chao(embaixo)
	# O ar da estufa entra pela escada: nada no patamar da porta, tudo no pe
	# dela. A mesma mistura da soleira, um degrau abaixo.
	var peso_estufa := 0.0
	if _preset_estufa != null and embaixo:
		peso_estufa = smoothstep(-0.6, -3.0, p.y)

	var dentro := peso >= 0.5
	if dentro != _dentro:
		_dentro = dentro
		if dentro:
			var porta := Transform3D(global_transform.basis,
				to_global(LoteNoMundo.centro_do_vao(planta)))
			Interiores.entrar_no_mundo(self, planta, semente, porta)
		else:
			Interiores.sair_do_mundo(self)

	_abrigar_chuva(peso)
	var mudou_estufa := absf(peso_estufa - _peso_estufa) >= PASSO_PESO \
		or (peso_estufa <= 0.0 and _peso_estufa > 0.0) \
		or (peso_estufa >= 1.0 and _peso_estufa < 1.0)
	if absf(peso - _peso) >= PASSO_PESO or (peso <= 0.0 and _peso > 0.0) \
			or (peso >= 1.0 and _peso < 1.0) or mudou_estufa:
		_peso = peso
		_peso_estufa = peso_estufa
		_aplicar_ambiente(peso)


func _aplicar_ambiente(peso: float) -> void:
	var fog := get_tree().get_first_node_in_group(&"fog_controller") as FogController
	if fog == null or _preset_casa == null:
		return
	if peso <= 0.0:
		_liberar_ambiente()
		return
	var ar := FogPreset.misturar(Settings.fog_preset(), _preset_casa, peso)
	if _preset_estufa != null and _peso_estufa > 0.0:
		ar = FogPreset.misturar(ar, _preset_estufa, _peso_estufa)
	fog.forcar_preset(ar)
	_forcei = true


func _liberar_ambiente() -> void:
	if not _forcei:
		return
	_forcei = false
	_peso = 0.0
	_peso_estufa = 0.0
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


# --- o chao da rua ------------------------------------------------------------

## Deixa o jogador atravessar a colisao do chao do chunk, e so ela.
##
## A escada do porao desce por dentro do puxadinho, e o chao da quadra e uma
## laje de 40 cm (ou o mapa de alturas, na ladeira) que passa exatamente ali: o
## jogador pisava nela no primeiro degrau abaixo do quintal e nao descia mais.
## Furar a laje no ChunkBuilder seria recortar o chao de todo chunk com casa da
## fumaca para um buraco que so importa a quem esta dentro do lote. Aqui a
## excecao vale so para o corpo do jogador, e so enquanto ele esta na escada ou
## na estufa — onde o puxadinho, a estufa e a casa tem colisao propria em volta.
func _furar_o_chao(sim: bool) -> void:
	if sim == _chao_furado:
		return
	var jogador := get_tree().get_first_node_in_group(&"player") as CollisionObject3D
	_achar_chao_do_chunk()
	if jogador == null or _chao_do_chunk == null:
		_chao_furado = false
		return
	var fisica := jogador as PhysicsBody3D
	if fisica == null:
		return
	_chao_furado = sim
	if sim:
		fisica.add_collision_exception_with(_chao_do_chunk)
	else:
		fisica.remove_collision_exception_with(_chao_do_chunk)


# --- camadas ------------------------------------------------------------------

func _achar_chao_do_chunk() -> void:
	if _chao_do_chunk == null or not is_instance_valid(_chao_do_chunk):
		var pai := get_parent()
		_chao_do_chunk = pai.get_node_or_null(^"Colisao") as CollisionObject3D \
			if pai != null else null


func _ao_nascer(no: Node) -> void:
	if _conteudo != null and _conteudo.is_ancestor_of(no):
		var na_estufa := _estufa != null and (_estufa == no or _estufa.is_ancestor_of(no))
		_marcar(no, CAMADA_ESTUFA if na_estufa else CAMADA)
		# Quem mora na estufa esta debaixo da laje da quadra, e a colisao do chunk
		# (o chao da rua, a casca do lote) passa pela altura da cabeca dele: Jota e
		# Helmer ficavam presos no primeiro passo, raspando o teto que o jogador
		# atravessa por excecao (`_furar_o_chao`). A mesma excecao, para sempre.
		if na_estufa and no is CharacterBody3D:
			_achar_chao_do_chunk()
			if _chao_do_chunk != null:
				(no as CharacterBody3D).add_collision_exception_with(_chao_do_chunk)


## Tudo de dentro vai para a CAMADA, e toda luz de dentro so acende a CAMADA. A
## malha da sala e abrigada da chuva por instancia: o material e o mesmo de
## qualquer comodo, mas o piso desta casa continua seco com a rua encharcando.
func _marcar(no: Node, camada: int = CAMADA) -> void:
	if no is Light3D:
		(no as Light3D).light_cull_mask = camada
	elif no is GeometryInstance3D:
		var g := no as GeometryInstance3D
		g.layers = camada
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
			(n as GeometryInstance3D).layers |= CAMADA | CAMADA_ESTUFA
		pilha.append_array(n.get_children())
