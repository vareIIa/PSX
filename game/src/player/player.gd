## Jogador. Primeira pessoa por padrao, `V` alterna para terceira pessoa.
##
## O yaw fica no corpo e o pitch no pivo da cabeca. Nos dois modos o corpo aponta
## para onde a camera olha, que e o esquema das referencias de terceira pessoa: a
## camera nao orbita livre em volta de um personagem parado.
##
## Velocidade deliberadamente baixa. Survival horror anda devagar porque a tensao
## vem de nao poder simplesmente sair correndo, e correr custa folego.
class_name Player
extends CharacterBody3D

# --- medidas, em metros e m/s -----------------------------------------------
const ALTURA := 1.75
const ALTURA_AGACHADO := 1.05
const RAIO := 0.32
const ALTURA_OLHO := 1.62
const ALTURA_OLHO_AGACHADO := 0.92

const VEL_ANDAR := 2.4
const VEL_CORRER := 4.6
const VEL_AGACHADO := 1.2
const ACELERACAO := 11.0
const DESACELERACAO := 15.0

## Folego em segundos de corrida contínua, e o tempo para recuperar tudo.
const FOLEGO_MAX := 6.0
const FOLEGO_RECUPERA := 4.0

const SENSIBILIDADE := 0.0024
const PITCH_MIN := -1.45
const PITCH_MAX := 1.35

# Bob preso a distancia percorrida, nao a tempo. Preso a tempo ele continua
# balancando quando o jogador anda contra a parede.
const BOB_FREQ := 2.05
const BOB_AMP := 0.035
const BOB_ROLL := 0.011

@onready var _pivo: Node3D = $Pivo
@onready var _braco: CameraRig = $Pivo/Braco
@onready var _corpo: Node3D = $Corpo
@onready var _colisao: CollisionShape3D = $Colisao

## Emitido a cada passo completo. A Fase 5 pendura o som de passo aqui.
signal passo_dado(velocidade: float)
## Emitido quando o jogador troca de camera.
signal camera_alternada(terceira_pessoa: bool)

var folego: float = FOLEGO_MAX
var _pitch: float = 0.0
var _distancia: float = 0.0
var _fase_bob: int = 0
var _agachado: bool = false
var _gravidade: float = 9.8
## Entrada simulada. Usada so pela verificacao automatizada de movimento.
var _auto: Vector2 = Vector2.ZERO
var _auto_correr: bool = false


func _ready() -> void:
	add_to_group(&"player")
	_gravidade = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_montar_colisao()
	_montar_corpo()
	# Numa execucao de captura a janela vive 40 frames; sequestrar o mouse ali
	# so atrapalha quem esta usando a maquina.
	if not _em_captura():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Permite a captura automatizada verificar a terceira pessoa sem simular tecla.
	if OS.get_cmdline_user_args().has("--tp"):
		_alternar_camera()

	# Anda sozinho para a frente. E como a captura verifica que o controlador
	# move de verdade, em vez de so compilar.
	if OS.get_cmdline_user_args().has("--auto-walk"):
		_auto = Vector2(0.0, -1.0)
	# Correndo o jogador cobre o dobro do chao no mesmo tempo, o que e um teste
	# mais duro para o streaming, nao mais facil.
	if OS.get_cmdline_user_args().has("--auto-run"):
		_auto = Vector2(0.0, -1.0)
		_auto_correr = true


func _em_captura() -> bool:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			return true
	return false


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := evento as InputEventMouseMotion
		rotate_y(-mm.relative.x * SENSIBILIDADE)
		_pitch = clampf(_pitch - mm.relative.y * SENSIBILIDADE, PITCH_MIN, PITCH_MAX)
		_pivo.rotation.x = _pitch
		return

	if evento.is_action_pressed("alternar_camera"):
		_alternar_camera()
	elif evento.is_action_pressed("pausa"):
		Input.mouse_mode = (Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED)
	elif evento.is_action_pressed("debug_nevoa"):
		Settings.cycle_fog_preset()


func _alternar_camera() -> void:
	var tp := _braco.alternar()
	_corpo.visible = tp
	camera_alternada.emit(tp)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravidade * delta

	_atualizar_agachar()

	var eixo := _auto if _auto != Vector2.ZERO 		else Input.get_vector("mover_esq", "mover_dir", "mover_frente", "mover_tras")
	var direcao := (transform.basis * Vector3(eixo.x, 0.0, eixo.y)).normalized()

	var quer_correr := (_auto_correr or Input.is_action_pressed("correr")) 		and not _agachado and eixo.length() > 0.1
	var alvo := _velocidade_alvo(quer_correr)
	_atualizar_folego(quer_correr and folego > 0.0, delta)

	var plano := Vector3(velocity.x, 0.0, velocity.z)
	if direcao.length_squared() > 0.01:
		plano = plano.move_toward(direcao * alvo, ACELERACAO * delta)
	else:
		plano = plano.move_toward(Vector3.ZERO, DESACELERACAO * delta)

	velocity.x = plano.x
	velocity.z = plano.z
	move_and_slide()

	_atualizar_bob(delta)


func _velocidade_alvo(correndo: bool) -> float:
	if _agachado:
		return VEL_AGACHADO
	if correndo and folego > 0.0:
		return VEL_CORRER
	return VEL_ANDAR


func _atualizar_folego(gastando: bool, delta: float) -> void:
	if _auto_correr:
		return
	if gastando:
		folego = maxf(0.0, folego - delta)
	else:
		folego = minf(FOLEGO_MAX, folego + delta * (FOLEGO_MAX / FOLEGO_RECUPERA))


func _atualizar_agachar() -> void:
	var quer := Input.is_action_pressed("agachar")
	if quer == _agachado:
		return
	# Levantar so vale se houver espaco. Sem isso o jogador atravessa o teto.
	if not quer and _tem_teto():
		return
	_agachado = quer
	var capsula := _colisao.shape as CapsuleShape3D
	capsula.height = ALTURA_AGACHADO if _agachado else ALTURA
	_colisao.position.y = capsula.height * 0.5
	_corpo.scale.y = (ALTURA_AGACHADO / ALTURA) if _agachado else 1.0


func _tem_teto() -> bool:
	var espaco := get_world_3d().direct_space_state
	var de := global_position + Vector3.UP * ALTURA_AGACHADO
	var para := global_position + Vector3.UP * (ALTURA + 0.05)
	var consulta := PhysicsRayQueryParameters3D.create(de, para)
	consulta.exclude = [get_rid()]
	return not espaco.intersect_ray(consulta).is_empty()


func _atualizar_bob(delta: float) -> void:
	var altura_olho := ALTURA_OLHO_AGACHADO if _agachado else ALTURA_OLHO
	var rapidez := Vector2(velocity.x, velocity.z).length()

	if rapidez < 0.15 or not is_on_floor():
		_pivo.position.y = lerpf(_pivo.position.y, altura_olho, 8.0 * delta)
		_pivo.rotation.z = lerpf(_pivo.rotation.z, 0.0, 8.0 * delta)
		return

	_distancia += rapidez * delta
	var t := _distancia * BOB_FREQ
	var escala := rapidez / VEL_ANDAR

	_pivo.position.y = altura_olho + sin(t * 2.0) * BOB_AMP * escala
	_pivo.rotation.z = sin(t) * BOB_ROLL * escala

	# Um passo por meio ciclo do bob vertical.
	var fase := int(t / PI)
	if fase != _fase_bob:
		_fase_bob = fase
		passo_dado.emit(rapidez)


# --- construcao -------------------------------------------------------------

func _montar_colisao() -> void:
	var capsula := CapsuleShape3D.new()
	capsula.height = ALTURA
	capsula.radius = RAIO
	_colisao.shape = capsula
	_colisao.position.y = ALTURA * 0.5
	_pivo.position.y = ALTURA_OLHO


## Figura em caixas. E placeholder, mas caixa texturizada e literalmente o alvo
## estetico das referencias, entao ele ja le certo em terceira pessoa.
## ART-BIBLE secao 10 permite 900 triangulos no personagem; isto usa 72.
func _montar_corpo() -> void:
	var partes: Array[Array] = [
		# tamanho                        posicao                     cor
		[Vector3(0.40, 0.58, 0.22), Vector3(0.0, 1.16, 0.0), Color("cfc7a8")],  # torso
		[Vector3(0.20, 0.22, 0.20), Vector3(0.0, 1.57, 0.0), Color("c9a98c")],  # cabeca
		[Vector3(0.11, 0.52, 0.13), Vector3(-0.25, 1.16, 0.0), Color("c9a98c")], # braco esq
		[Vector3(0.11, 0.52, 0.13), Vector3(0.25, 1.16, 0.0), Color("c9a98c")],  # braco dir
		[Vector3(0.15, 0.86, 0.17), Vector3(-0.10, 0.44, 0.0), Color("4a5468")], # perna esq
		[Vector3(0.15, 0.86, 0.17), Vector3(0.10, 0.44, 0.0), Color("4a5468")],  # perna dir
	]

	var material := load("res://resources/materials/mat_personagem.tres") as ShaderMaterial
	for parte: Array in partes:
		var mi := MeshInstance3D.new()
		mi.mesh = PSXMesh.box(parte[0], 1.6, PSXMesh.MAX_QUAD_M, parte[2])
		mi.material_override = material
		mi.position = parte[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_corpo.add_child(mi)

	_corpo.visible = false
