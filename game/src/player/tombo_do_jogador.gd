## O jogador atropelado: cai como qualquer um e levanta como qualquer um.
##
## Mora fora do `Player` de proposito: o controlador ja faz andar, correr,
## agachar, dirigir, pedalar e a camera de tres jeitos, e o tombo so precisa de
## quatro coisas dele — travar o controle, mostrar o corpo, a figura (`Corpo`)
## e devolver a camera. Tudo isso ja e publico.
##
## Enquanto o corpo esta no chao:
## - o controle fica travado e o no do jogador acompanha o quadril (o mapa, o
##   streaming e a voz continuam achando o jogador onde ele caiu);
## - uma camera de terceira pessoa segue o corpo, afastada e acima, como no
##   GTA IV quando o personagem sai rolando;
## - a vida cai com a pancada (`Inventario.ferir`). Se zerar, o corpo NAO
##   levanta: o `Desmaio` escurece a tela e acorda o jogador no orelhao, e so
##   entao o corpo e devolvido.
##
## Carro devagar nao derruba: empurra o jogador, com um baque e um arranhao de
## vida, como o pedestre que so cambaleia.
class_name TomboDoJogador
extends Node

const RAIO := 0.32
const MASSA := 78.0
## Ate que rapidez relativa o carro so empurra (m/s).
const EMPURRA := 3.4
## Dano por m/s acima do empurrao, e o teto.
const DANO_POR_MS := 7.0
const DANO_MAXIMO := 95
## Camera: distancia e altura do corpo, e quao depressa ela acompanha.
const CAMERA_LONGE := 4.2
const CAMERA_ALTO := 2.1
const CAMERA_SEGUE := 4.0

var _jogador: CharacterBody3D
var _boneco: BonecoDePano
var _camera: Camera3D
var _corpo_visivel_antes := false
var _com_excecao: Array[PhysicsBody3D] = []
var _desde_empurrao := 9.0
var _desmaiou := false
## Quanto tempo a figura ainda manca (perna batida no atropelo). So a figura:
## a velocidade do jogador e a de sempre, que manca e o corpo, nao o controle.
var _t_manca := 0.0


func _ready() -> void:
	name = "TomboDoJogador"
	_jogador = get_parent() as CharacterBody3D


## Esta no chao (ou levantando)?
func caido() -> bool:
	return _boneco != null


func _physics_process(delta: float) -> void:
	if _jogador == null:
		return
	_desde_empurrao += delta
	if _boneco != null:
		_seguir(delta)
		return
	var figura := _jogador.call("figura") as Corpo
	if _t_manca > 0.0:
		_t_manca -= delta
		if figura != null:
			figura.mancando = minf(figura.mancando, clampf(_t_manca / 4.0, 0.0, 1.0))
	# Vida baixa: a figura manca ate curar (o amigo na rede ve o mesmo, F_FERIDO).
	if figura != null and Inventario.vida * 10 <= Inventario.vida_maxima * 3:
		figura.mancando = maxf(figura.mancando, 0.6)
	elif figura != null and _t_manca <= 0.0 and figura.mancando > 0.0:
		figura.mancando = 0.0
	if bool(_jogador.get("travado")) or _jogador.call("dirigindo") \
			or _jogador.get("_bike") != null:
		return
	var bate := Atropelo.quem_bate(get_tree(), _jogador.global_position,
		_jogador.velocity, RAIO, delta)
	if bate.is_empty():
		return
	var rel: Vector3 = bate["rel"]
	var carro: Node3D = bate["carro"]
	if rel.length() < EMPURRA:
		_empurrar(carro, bate["vc"])
		return
	derrubar(carro, rel)


func _empurrar(carro: Node3D, vc: Vector3) -> void:
	if _desde_empurrao < 0.6:
		return
	_desde_empurrao = 0.0
	vc.y = 0.0
	_jogador.velocity += vc * 0.9
	Inventario.ferir(3, carro.global_position)
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio != null:
		audio.call(&"tocar", &"baque_corpo_2", _jogador.global_position + Vector3.UP, -8.0, 0.9)


## Derruba o jogador com o golpe do `carro` (rapidez relativa `rel`).
func derrubar(carro: Node3D, rel: Vector3) -> void:
	var figura := _jogador.call("figura") as Corpo
	if figura == null or _boneco != null:
		return
	var v := rel.length()
	Inventario.ferir(mini(DANO_MAXIMO, int((v - EMPURRA) * DANO_POR_MS) + 8),
		carro.global_position)
	_desmaiou = Inventario.vida <= 0
	var corpo_visual := _jogador.get_node_or_null(^"Corpo") as Node3D
	_corpo_visivel_antes = corpo_visual != null and corpo_visual.visible
	_jogador.call("mostrar_corpo", true)
	_jogador.call("travar", true)
	_excecoes(true)
	_boneco = BonecoDePano.derrubar(figura, _jogador.velocity, Atropelo.golpe(rel),
		0.5, Atropelo.pancada(v), [_jogador])
	_boneco.levantar_sozinho = not _desmaiou
	_boneco.levantou.connect(_ao_levantar, CONNECT_ONE_SHOT)
	LatariaParaCorpo.criar(carro, Atropelo.caixa_do_carro(carro), _boneco.pecas())
	Atropelo.tranco_no_carro(carro, rel, MASSA)
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio != null:
		audio.call(&"tocar", &"atropelo_pancada", _jogador.global_position + Vector3.UP * 0.6,
			linear_to_db(clampf(v / 10.0, 0.4, 1.3)), randf_range(0.9, 1.08))
	_montar_camera()
	if _desmaiou:
		var d := get_tree().get_first_node_in_group(&"desmaio")
		if d != null and d.has_signal(&"acordou"):
			d.connect(&"acordou", _ao_acordar_do_desmaio, CONNECT_ONE_SHOT)


func _montar_camera() -> void:
	var de_jogo := _jogador.call("camera") as Camera3D
	_camera = Camera3D.new()
	_camera.name = "CameraDoTombo"
	_camera.top_level = true
	add_child(_camera)
	if de_jogo != null:
		_camera.fov = de_jogo.fov
		_camera.near = de_jogo.near
		_camera.far = de_jogo.far
	# Ja nasce afastada, atras e acima, no rumo em que o jogador olhava. Nascendo
	# na camera de primeira pessoa, o primeiro quadro era a nuca do proprio
	# boneco a um palmo da lente.
	var atras := _jogador.global_basis.z
	atras.y = 0.0
	atras = atras.normalized() if atras.length() > 0.01 else Vector3.BACK
	var p := _jogador.global_position + Vector3.UP * 0.9
	_camera.global_position = p + atras * CAMERA_LONGE + Vector3.UP * CAMERA_ALTO
	_camera.look_at(p, Vector3.UP)
	_camera.current = true


## O no do jogador acompanha o quadril; a camera acompanha os dois.
func _seguir(delta: float) -> void:
	if not is_instance_valid(_boneco):
		_restaurar()
		return
	var p := _boneco.onde_esta()
	var chao := _boneco.corpo.global_position.y if _boneco.corpo != null else p.y
	_jogador.global_position = Vector3(p.x, chao, p.z)
	_jogador.velocity = Vector3.ZERO
	if _camera == null:
		return
	var atras := _camera.global_position - p
	atras.y = 0.0
	if atras.length() < 0.1:
		atras = Vector3.BACK
	var alvo := p + atras.normalized() * CAMERA_LONGE + Vector3.UP * CAMERA_ALTO
	_camera.global_position = _camera.global_position.lerp(alvo, minf(1.0, CAMERA_SEGUE * delta))
	_camera.look_at(p + Vector3.UP * 0.4, Vector3.UP)


func _ao_levantar(onde: Vector3, rumo: float) -> void:
	var dor: Dictionary = _boneco.onde_doi() if is_instance_valid(_boneco) else {}
	var figura := _jogador.call("figura") as Corpo
	if figura != null and not dor.is_empty() 			and String(dor["parte"]).begins_with("perna"):
		figura.perna_ruim = -1 if dor["parte"] == &"perna_e" else 1
		figura.mancando = clampf(float(dor["forca"]) / 9.0, 0.45, 1.0)
		_t_manca = 14.0
	_jogador.global_position = onde
	_jogador.rotation.y = rumo
	_restaurar()


## O Desmaio levou o jogador ao orelhao: o corpo de pe la, sem levantar do
## chao daqui.
func _ao_acordar_do_desmaio(_onde: String) -> void:
	if is_instance_valid(_boneco):
		_boneco.encerrar()
	_restaurar()


func _restaurar() -> void:
	_boneco = null
	_excecoes(false)
	if _camera != null:
		_camera.queue_free()
		_camera = null
	var de_jogo := _jogador.call("camera") as Camera3D
	if de_jogo != null:
		de_jogo.current = true
	_jogador.call("mostrar_corpo", _corpo_visivel_antes)
	if not _desmaiou:
		_jogador.call("travar", false)
	_desmaiou = false


## Enquanto caido, carro nenhum tromba na capsula do jogador (ela esta em cima
## do quadril, no meio da rua): quem bate e nas pecas.
func _excecoes(ligar: bool) -> void:
	if ligar:
		for n: Node in get_tree().get_nodes_in_group(&"carro"):
			var corpo := n as PhysicsBody3D
			if corpo != null:
				corpo.add_collision_exception_with(_jogador)
				_com_excecao.append(corpo)
		return
	for corpo in _com_excecao:
		if is_instance_valid(corpo):
			corpo.remove_collision_exception_with(_jogador)
	_com_excecao.clear()
