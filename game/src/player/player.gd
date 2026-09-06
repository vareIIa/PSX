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
## Emitido quando o alvo de interacao muda. Rotulo vazio significa nenhum alvo.
signal alvo_de_interacao(rotulo: String)

var folego: float = FOLEGO_MAX
var _pitch: float = 0.0
var _distancia: float = 0.0
var _fase_bob: int = 0
var _agachado: bool = false
var _gravidade: float = 9.8
## Entrada simulada. Usada so pela verificacao automatizada de movimento.
var _auto: Vector2 = Vector2.ZERO

## Alcance da interacao, em metros. Braco esticado, nao teleporte.
const ALCANCE_INTERACAO := 2.4

var _alvo: Interativo
var _raio: RayCast3D

# --- lanterna ---------------------------------------------------------------
## Autonomia da bateria cheia, em segundos de uso continuo. Curta de proposito:
## e o recurso que faz o jogador escolher entre enxergar e economizar.
const BATERIA_SEGUNDOS := 330.0
## Abaixo disso a luz comeca a falhar, avisando antes de acabar.
const BATERIA_FRACA := 0.16

var lanterna_ligada: bool = false
var bateria: float = 1.0
var _lanterna: SpotLight3D

## Radio de chiado. Filho do jogador porque a proximidade e medida dele.
var radio: Radio
var _auto_correr: bool = false


func _ready() -> void:
	add_to_group(&"player")
	_gravidade = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_montar_colisao()
	_montar_corpo()
	_montar_raio()
	_montar_lanterna()
	_montar_radio()
	passo_dado.connect(_ao_dar_passo)
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
	elif evento.is_action_pressed("lanterna"):
		alternar_lanterna()
	elif evento.is_action_pressed("radio"):
		radio.alternar()
		AudioDirector.tocar_ui(&"interruptor", -6.0)
	elif evento.is_action_pressed("interagir"):
		if _alvo != null:
			_alvo.interagir(self)
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
	_atualizar_alvo()
	_atualizar_lanterna(delta)


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


## Procura o que esta na mira. O raio parte da camera e nao do corpo, senao o
## jogador aponta para uma coisa e aciona outra.
func _atualizar_alvo() -> void:
	var camera := _braco.get_node_or_null("Camera") as Camera3D
	if camera == null:
		return

	_raio.global_transform = camera.global_transform
	_raio.force_raycast_update()

	var achado: Interativo = null
	if _raio.is_colliding():
		var col := _raio.get_collider()
		if col is Interativo and (col as Interativo).habilitado:
			achado = col

	if achado == _alvo:
		return
	_alvo = achado
	alvo_de_interacao.emit(_alvo.rotulo_atual() if _alvo != null else "")


## Devolve o alvo atual, ou null. O HUD usa para nao precisar guardar estado.
func alvo_atual() -> Interativo:
	return _alvo


## Quanto barulho o jogador esta fazendo, de 0 a 1.
##
## E o que o inimigo escuta. Correr denuncia, andar quase nao, agachar nunca.
## Isso transforma a velocidade numa decisao em vez de um botao sempre apertado.
func nivel_de_ruido() -> float:
	if not is_on_floor():
		return 0.0
	var rapidez := Vector2(velocity.x, velocity.z).length()
	if _agachado or rapidez < 0.2:
		return 0.0
	if rapidez > VEL_ANDAR + 0.4:
		return 1.0
	return 0.34 * (rapidez / VEL_ANDAR)


## Superficie sob os pes. Por enquanto sai do contexto, nao do material: dentro
## de casa e madeira, na rua e concreto. A Fase 6 pode ler o material de verdade.
func superficie() -> StringName:
	return &"madeira" if Interiores.dentro else &"concreto"


func _ao_dar_passo(rapidez: float) -> void:
	if _agachado:
		return
	AudioDirector.passo(superficie(), global_position,
		clampf(rapidez / VEL_CORRER, 0.25, 1.0))


# --- lanterna ---------------------------------------------------------------

func _montar_lanterna() -> void:
	_lanterna = SpotLight3D.new()
	_lanterna.name = "Lanterna"
	_lanterna.light_color = Color("fff0d0")
	_lanterna.light_energy = 4.2
	_lanterna.spot_range = 17.0
	_lanterna.spot_angle = 26.0
	_lanterna.spot_angle_attenuation = 0.9
	_lanterna.spot_attenuation = 1.1
	# ART-BIBLE secao 7 — o PS1 nao tinha sombra dinamica
	_lanterna.shadow_enabled = false
	_lanterna.visible = false
	# Presa ao pivo da cabeca, nao ao braco: em terceira pessoa a lanterna
	# continua saindo do personagem, e nao da camera flutuando atras dele.
	_pivo.add_child(_lanterna)


func alternar_lanterna() -> void:
	if not Inventario.tem(&"lanterna"):
		return
	if not lanterna_ligada and bateria <= 0.0:
		AudioDirector.tocar_ui(&"interruptor", -10.0)
		return
	lanterna_ligada = not lanterna_ligada
	_lanterna.visible = lanterna_ligada
	AudioDirector.tocar_ui(&"interruptor", -4.0)


func _atualizar_lanterna(delta: float) -> void:
	if not lanterna_ligada:
		return

	bateria = maxf(0.0, bateria - delta / BATERIA_SEGUNDOS)
	if bateria <= 0.0:
		lanterna_ligada = false
		_lanterna.visible = false
		AudioDirector.tocar_ui(&"interruptor", -12.0)
		return

	# Perto do fim a luz fraqueja. O aviso e a mecanica: sem ele o escuro chega
	# de surpresa e le como punicao arbitraria.
	var base := 4.2
	if bateria < BATERIA_FRACA:
		var f := bateria / BATERIA_FRACA
		base *= 0.35 + 0.65 * f
		base *= 1.0 - 0.4 * maxf(0.0, sin(Time.get_ticks_msec() * 0.011)) * (1.0 - f)
	_lanterna.light_energy = base


## Repoe a bateria. Devolve false quando ja estava cheia.
func trocar_bateria() -> bool:
	if bateria > 0.98:
		return false
	bateria = 1.0
	return true


func _montar_radio() -> void:
	radio = Radio.new()
	radio.name = "Radio"
	add_child(radio)


## Zera a inercia. Teleportar mantendo velocidade faz o jogador sair andando
## sozinho para dentro da parede assim que chega.
func zerar_velocidade() -> void:
	velocity = Vector3.ZERO


## Vira o corpo para um ponto, mantendo o pitch. Usado ao entrar num interior:
## aparecer olhando para a parede e desorientador.
func olhar_para(ponto: Vector3) -> void:
	var d := ponto - global_position
	d.y = 0.0
	if d.length_squared() < 0.001:
		return
	rotation.y = atan2(-d.x, -d.z)
	_pitch = 0.0
	_pivo.rotation.x = 0.0


# --- construcao -------------------------------------------------------------

## Raio de mira na camada de interacao. Separado da colisao do mundo: o raio
## precisa atravessar o cenario ate a area do objeto, e nao parar na parede
## antes dela.
func _montar_raio() -> void:
	_raio = RayCast3D.new()
	_raio.name = "MiraInteracao"
	_raio.enabled = true
	_raio.target_position = Vector3(0.0, 0.0, -ALCANCE_INTERACAO)
	_raio.collide_with_areas = true
	_raio.collide_with_bodies = true
	# Mundo solido mais interacao: uma porta atras de uma parede nao pode ser
	# acionada, entao o raio precisa enxergar as duas camadas e parar na primeira.
	_raio.collision_mask = 1 | Interativo.CAMADA
	add_child(_raio)


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
