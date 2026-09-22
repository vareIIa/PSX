## O mirante em jogo: no parque do alto do morro, a nevoa se abre.
##
## Por que existe
## -------------
## Cidade de morro e cidade de vista. Com a nevoa do jogo a vista acaba em
## trinta, sessenta metros em qualquer lugar, e o alto do morro ficava igual ao
## fundo do vale. O terraco e a luneta sao do MiranteBuilder; aqui mora o ar.
##
## Como e feito
## ------------
## Este no olha o jogador quatro vezes por segundo. Dentro de um parque mirante
## (MiranteBuilder.e_mirante), ele pede a nevoa um clima DERIVADO do que o
## jogador escolheu — a mesma nevoa, mais longe — pela API publica
## (FogController.forcar_preset), sem mexer no controlador. Na saida ele devolve
## (liberar). Se outra coisa ja estiver forcando a nevoa (a abertura, uma
## captura, o interior), ele nao toca; se outra coisa forcar no meio, ele larga.
##
## O clima derivado entra de uma vez — e so assim o streaming ja carrega a vista
## e a chuva e a nuvem (que reiniciam as particulas a cada preset) mudam uma vez
## so. O que o olho ve abrir devagar e o ar: a distancia da nevoa, a densidade do
## volume e a serra sao interpoladas no Environment, do clima de antes ao
## derivado, em ABRIR segundos; na saida, de volta, e so no fim o preset e
## devolvido — aos mesmos numeros, sem salto.
class_name Mirante
extends Node

const GRUPO := &"mirante"
## Quanto a nevoa se abre no mirante, e ate onde. Na chuva abre menos: o ar
## carregado nao deixa, e a gota fica mais densa com a nevoa mais longe (Chuva).
const ABRE := 2.4
const ABRE_CHUVA := 1.6
const FIM_MAXIMO := 150.0
## Tempo de abrir e de fechar, em segundos.
const ABRIR := 3.5
const FECHAR := 2.5
## Dentro: na area util do parque mais ENTRA metros; fora: alem de SAI metros.
## A diferenca e a histerese de quem passeia no portao.
const ENTRA := 3.0
const SAI := 9.0
const PERIODO := 0.25
## A serra repinta os vertices a cada chamada; durante a transicao, no maximo
## tantas vezes por segundo.
const SERRA_HZ := 8.0
## As grandezas do Environment que o preset derivado muda e que sao
## interpoladas. A cor e o ceu sao os mesmos do clima de base.
const GRANDEZAS: Array[StringName] = [&"fog_depth_begin", &"fog_depth_end",
	&"volumetric_fog_density", &"volumetric_fog_length"]

enum Estado { FORA, ABRINDO, ABERTO, FECHANDO }

var _estado := Estado.FORA
## 0 no clima de base, 1 no derivado.
var _k := 0.0
var _base: FogPreset
var _derivado: FogPreset
## O Environment com o clima de base e com o derivado, nas GRANDEZAS.
var _de: Dictionary = {}
var _para: Dictionary = {}
var _fog: FogController
var _jogador: Node3D
var _quadra: Dictionary = {}
var _olhar_em := 0.0
var _serra_em := 0.0


func _ready() -> void:
	add_to_group(GRUPO)
	name = "Mirante"
	process_priority = 10


func _process(delta: float) -> void:
	_olhar_em -= delta
	if _olhar_em <= 0.0:
		_olhar_em = PERIODO
		_olhar()
	match _estado:
		Estado.ABRINDO:
			_k = minf(1.0, _k + delta / ABRIR)
			_misturar(delta)
			if _k >= 1.0:
				_estado = Estado.ABERTO
		Estado.FECHANDO:
			_k = maxf(0.0, _k - delta / FECHAR)
			_misturar(delta)
			if _k <= 0.0:
				if _fog != null and _fog.preset_atual() == _derivado:
					_fog.liberar()
				_soltar()


## Quem esta onde, e o que fazer: abrir, fechar, largar.
func _olhar() -> void:
	if _fog == null or not is_instance_valid(_fog):
		_fog = get_tree().get_first_node_in_group(&"fog_controller") as FogController
	if _jogador == null or not is_instance_valid(_jogador):
		_jogador = get_tree().get_first_node_in_group(&"player") as Node3D
	if _fog == null or _jogador == null:
		return
	# Outra coisa trocou a nevoa por cima (entrou num interior, a abertura
	# comecou, uma captura forcou dia): a vez e dela. Nao devolve nada — o
	# preset em vigor nao e mais o nosso.
	if _estado != Estado.FORA and _fog.preset_atual() != _derivado:
		_soltar()
	var dentro := _no_mirante(_jogador.global_position)
	var escolhido := Settings.fog_preset()
	if dentro:
		if _estado == Estado.FORA:
			if _fog.preset_atual() != escolhido or escolhido == null \
					or not escolhido.fog_enabled:
				return
			_entrar(escolhido)
		elif escolhido != _base and escolhido != null:
			# O jogador trocou o clima no menu com o mirante aberto: deriva de
			# novo, na mesma altura da transicao.
			if not escolhido.fog_enabled:
				_fog.liberar()
				_soltar()
				return
			_entrar(escolhido)
		_estado = Estado.ABRINDO if _k < 1.0 else Estado.ABERTO
	elif _estado == Estado.ABRINDO or _estado == Estado.ABERTO:
		_estado = Estado.FECHANDO


## Poe o clima derivado de `base` e volta o ar ao ponto `_k` da transicao.
func _entrar(base: FogPreset) -> void:
	var env := _fog.environment
	# O "de" e o Environment com o clima de base em vigor. Fora do mirante ele
	# ja esta la; trocando de clima no meio, devolve primeiro para ler.
	if _estado != Estado.FORA:
		_fog.liberar()
	_de = _ler(env)
	_base = base
	_derivado = _abrir(base)
	_fog.forcar_preset(_derivado)
	_para = _ler(env)
	_misturar(0.0, true)
	# A serra repinta sozinha quando ve o preset novo (SerraDaCidade._process),
	# no quadro seguinte e por inteiro. Este no roda depois dela no quadro
	# (process_priority) e repinta por cima no mesmo quadro.
	_serra_em = 0.0


func _soltar() -> void:
	_estado = Estado.FORA
	_k = 0.0
	_derivado = null
	_base = null
	_quadra = {}


## O jogador esta num mirante? Mede na area util do parque, com histerese.
func _no_mirante(p: Vector3) -> bool:
	if p.y > 1000.0:
		return false
	var cx := floori(p.x / MalhaUrbana.TAM)
	var cz := floori(p.z / MalhaUrbana.TAM)
	var q := MalhaUrbana.quadra_de(cx, cz)
	if not _quadra.is_empty() and q["id"] != _quadra["id"]:
		# Saiu da quadra de vez: a folga de SAI e pequena perto de uma quadra.
		q = _quadra
	if not MiranteBuilder.e_mirante(q):
		_quadra = {}
		return false
	var plano := ParqueBuilder.planta(q)
	var area: Rect2 = plano["area"]
	area.position += Vector2(float(int(q["x0"])), float(int(q["z0"]))) * MalhaUrbana.TAM
	var folga := SAI if _estado != Estado.FORA else ENTRA
	var dentro := area.grow(folga).has_point(Vector2(p.x, p.z))
	_quadra = q if dentro else {}
	return dentro


## O clima do mirante: o mesmo do jogador, com a nevoa mais longe e o bairro
## carregado ate onde ela chega (stream_radius nunca menor que o fim dela).
static func _abrir(base: FogPreset) -> FogPreset:
	var p := base.duplicate() as FogPreset
	var abre := ABRE_CHUVA if base.tem_chuva else ABRE
	p.fog_end = clampf(base.fog_end * abre, base.fog_end, FIM_MAXIMO)
	p.fog_begin = minf(base.fog_begin * abre, p.fog_end * 0.5)
	p.stream_radius = maxf(base.stream_radius, ceilf((p.fog_end + 16.0) / 16.0) * 16.0)
	return p


static func _ler(env: Environment) -> Dictionary:
	var d := {}
	for g: StringName in GRANDEZAS:
		d[g] = env.get(g)
	return d


## O ar no ponto `_k` entre o de antes e o derivado, e a serra junto.
func _misturar(delta: float, ja := false) -> void:
	if _fog == null or _derivado == null:
		return
	var env := _fog.environment
	var s := smoothstep(0.0, 1.0, _k)
	for g: StringName in GRANDEZAS:
		env.set(g, lerpf(float(_de[g]), float(_para[g]), s))
	_serra_em -= delta
	if not ja and _serra_em > 0.0 and _k > 0.0 and _k < 1.0:
		return
	_serra_em = 1.0 / SERRA_HZ
	var serra := get_tree().get_first_node_in_group(SerraDaCidade.GRUPO)
	if serra == null:
		return
	# A serra le a vista do fim da nevoa: um preset com o fim de agora.
	var agora := _derivado.duplicate() as FogPreset
	agora.fog_end = float(env.fog_depth_end)
	serra.call("pintar", agora)
