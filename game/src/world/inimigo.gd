## Inimigo. Percebe por visao em cone e por ruido.
##
## A percepcao e o desenho de jogo, nao a inteligencia. Um inimigo que sempre
## sabe onde voce esta nao assusta, irrita. Um que perde o rastro e fica
## procurando faz o jogador prender a respiracao atras de uma parede, que e o
## que se quer.
##
## Ruido vem do jogador, nao de um raio: correr faz barulho, agachar nao. Isso
## transforma a velocidade numa decisao em vez de um botao sempre apertado.
class_name Inimigo
extends CharacterBody3D

enum Estado { PARADO, VAGANDO, ALERTA, PERSEGUINDO, PERDIDO }

const ALTURA := 1.85
const RAIO := 0.36

const VEL_VAGANDO := 0.9
const VEL_ALERTA := 1.6
const VEL_PERSEGUINDO := 3.1
const ACELERACAO := 6.0

## Visao. O cone e estreito de proposito: passar por tras e uma opcao real.
const ALCANCE_VISAO := 17.0
const ANGULO_VISAO := 52.0
## Alcance de escuta com o jogador fazendo o maximo de barulho.
const ALCANCE_ESCUTA := 22.0

## Quanto tempo continua procurando depois de perder o alvo. Desistir na hora
## faz o inimigo parecer cego; nunca desistir faz parecer onisciente.
const MEMORIA := 7.0
const TEMPO_ALERTA := 2.5

@export var semente: int = 0
@export var patrulha_raio: float = 9.0

signal viu_o_jogador()
signal perdeu_o_jogador()

var estado: Estado = Estado.PARADO
## Ultimo ponto onde o jogador foi percebido. E para la que ele vai.
var ultimo_visto := Vector3.ZERO

var _jogador: Node3D
var _origem := Vector3.ZERO
var _destino := Vector3.ZERO
var _t_estado: float = 0.0
var _memoria: float = 0.0
var _rng := RandomNumberGenerator.new()
var _gravidade: float = 9.8
var _passo_acc: float = 0.0
var _corpo: Node3D


func _ready() -> void:
	add_to_group(&"inimigo")
	_rng.seed = semente if semente != 0 else hash(get_path())
	_gravidade = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_origem = global_position
	_montar()
	_trocar(Estado.VAGANDO)


func _montar() -> void:
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.height = ALTURA
	capsula.radius = RAIO
	forma.shape = capsula
	forma.position = Vector3(0.0, ALTURA * 0.5, 0.0)
	add_child(forma)

	# Figura em caixas, mais alta e mais estreita que a do jogador, com a cabeca
	# baixa. Silhueta errada assusta mais que detalhe: o cerebro percebe que a
	# proporcao nao fecha antes de conseguir dizer por que.
	_corpo = Node3D.new()
	_corpo.name = "Corpo"
	add_child(_corpo)

	var partes: Array[Array] = [
		[Vector3(0.38, 0.72, 0.24), Vector3(0.0, 1.16, 0.0), Color("6b6355")],
		[Vector3(0.19, 0.21, 0.2), Vector3(0.0, 1.5, 0.08), Color("8a7f6d")],
		[Vector3(0.1, 0.66, 0.11), Vector3(-0.26, 1.1, 0.02), Color("6b6355")],
		[Vector3(0.1, 0.66, 0.11), Vector3(0.26, 1.1, 0.02), Color("6b6355")],
		[Vector3(0.13, 0.8, 0.15), Vector3(-0.1, 0.4, 0.0), Color("4a4438")],
		[Vector3(0.13, 0.8, 0.15), Vector3(0.1, 0.4, 0.0), Color("4a4438")],
	]
	var material := load("res://resources/materials/mat_personagem.tres") as ShaderMaterial
	for parte: Array in partes:
		var mi := MeshInstance3D.new()
		mi.mesh = PSXMesh.box(parte[0], 1.6, PSXMesh.MAX_QUAD_M, parte[2])
		mi.material_override = material
		mi.position = parte[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_corpo.add_child(mi)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravidade * delta

	_jogador = _jogador if is_instance_valid(_jogador) \
		else get_tree().get_first_node_in_group(&"player") as Node3D

	_t_estado += delta
	_perceber(delta)
	_agir(delta)

	move_and_slide()
	_sonorizar(delta)


# --- percepcao --------------------------------------------------------------

func _perceber(delta: float) -> void:
	if _jogador == null:
		return

	var percebeu := _ve_o_jogador() or _ouve_o_jogador()

	if percebeu:
		ultimo_visto = _jogador.global_position
		_memoria = MEMORIA
		if estado != Estado.PERSEGUINDO:
			_trocar(Estado.ALERTA if estado == Estado.VAGANDO or estado == Estado.PARADO
				else Estado.PERSEGUINDO)
			viu_o_jogador.emit()
		return

	if _memoria > 0.0:
		_memoria -= delta
		if _memoria <= 0.0 and estado in [Estado.PERSEGUINDO, Estado.ALERTA]:
			_trocar(Estado.PERDIDO)
			perdeu_o_jogador.emit()


func _ve_o_jogador() -> bool:
	var alvo := _jogador.global_position + Vector3(0.0, 1.2, 0.0)
	var olho := global_position + Vector3(0.0, 1.5, 0.0)
	var d := alvo - olho
	var dist := d.length()
	if dist > ALCANCE_VISAO:
		return false

	# Perseguindo, o cone abre: ja sabe onde voce esta, nao precisa reencontrar.
	var meio_angulo := ANGULO_VISAO if estado != Estado.PERSEGUINDO else 100.0
	var frente := -global_transform.basis.z
	if rad_to_deg(frente.angle_to(d.normalized())) > meio_angulo:
		return false

	return _enxerga(olho, alvo)


## Ouve pelo ruido que o jogador esta fazendo agora, atenuado pela distancia.
## Parede nao bloqueia som, so o abafa, entao a escuta ignora linha de visao.
func _ouve_o_jogador() -> bool:
	if not _jogador.has_method("nivel_de_ruido"):
		return false
	var ruido: float = _jogador.call("nivel_de_ruido")
	if ruido <= 0.01:
		return false
	var dist := global_position.distance_to(_jogador.global_position)
	return dist < ALCANCE_ESCUTA * ruido


## Ha linha de visao ate o alvo?
##
## Nao basta perguntar se o raio bateu em alguma coisa: o corpo do jogador esta
## na mesma camada do cenario, entao o raio sempre bate nele e a resposta seria
## sempre "bloqueado". O que importa e se o primeiro obstaculo E o jogador.
func _enxerga(de: Vector3, para: Vector3) -> bool:
	var espaco := get_world_3d().direct_space_state
	var consulta := PhysicsRayQueryParameters3D.create(de, para)
	consulta.exclude = [get_rid()]
	consulta.collision_mask = 1
	var acerto := espaco.intersect_ray(consulta)
	if acerto.is_empty():
		return true
	return acerto.get("collider") == _jogador


# --- comportamento ----------------------------------------------------------

func _trocar(novo: Estado) -> void:
	if estado == novo:
		return
	estado = novo
	_t_estado = 0.0
	match novo:
		Estado.VAGANDO: _sortear_destino()
		Estado.PERDIDO: _destino = ultimo_visto


func _agir(delta: float) -> void:
	var alvo := Vector3.ZERO
	var vel := 0.0

	match estado:
		Estado.PARADO:
			if _t_estado > _rng.randf_range(2.0, 5.0):
				_trocar(Estado.VAGANDO)
		Estado.VAGANDO:
			alvo = _destino
			vel = VEL_VAGANDO
			if global_position.distance_to(_destino) < 1.2 or _t_estado > 14.0:
				_trocar(Estado.PARADO)
		Estado.ALERTA:
			# Para e vira para o barulho antes de sair andando. Reagir
			# instantaneamente le como trapaca.
			alvo = ultimo_visto
			vel = VEL_ALERTA if _t_estado > 0.8 else 0.0
			if _t_estado > TEMPO_ALERTA:
				_trocar(Estado.PERSEGUINDO)
		Estado.PERSEGUINDO:
			alvo = ultimo_visto
			vel = VEL_PERSEGUINDO
		Estado.PERDIDO:
			alvo = _destino
			vel = VEL_ALERTA
			if global_position.distance_to(_destino) < 1.5 or _t_estado > 6.0:
				_trocar(Estado.VAGANDO)

	var plano := Vector3(velocity.x, 0.0, velocity.z)
	if vel > 0.0:
		var d := alvo - global_position
		d.y = 0.0
		if d.length_squared() > 0.04:
			plano = plano.move_toward(d.normalized() * vel, ACELERACAO * delta)
			_encarar(d, delta)
	else:
		plano = plano.move_toward(Vector3.ZERO, ACELERACAO * 2.0 * delta)

	velocity.x = plano.x
	velocity.z = plano.z


func _encarar(direcao: Vector3, delta: float) -> void:
	var alvo := atan2(-direcao.x, -direcao.z)
	rotation.y = rotate_toward(rotation.y, alvo, 4.0 * delta)


func _sortear_destino() -> void:
	var ang := _rng.randf() * TAU
	var r := _rng.randf_range(2.0, patrulha_raio)
	_destino = _origem + Vector3(cos(ang) * r, 0.0, sin(ang) * r)


func _sonorizar(delta: float) -> void:
	var rapidez := Vector2(velocity.x, velocity.z).length()
	if rapidez < 0.2:
		return
	_passo_acc += rapidez * delta
	if _passo_acc < 1.15:
		return
	_passo_acc = 0.0
	AudioDirector.passo(&"concreto", global_position, 0.55)


## Distancia ate o jogador. O radio usa para dosar o chiado.
func distancia_do_jogador() -> float:
	if _jogador == null:
		return INF
	return global_position.distance_to(_jogador.global_position)
