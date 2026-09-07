## Uma bicicleta. Fica encostada na parede ate alguem subir nela.
##
## Por que nao e um VehicleBody3D como o carro
## -------------------------------------------
## Porque bicicleta de verdade cai. Um corpo rigido de duas rodas so fica de pe
## por efeito giroscopico e por correcao continua de quem pedala, e nenhuma das
## duas coisas existe num motor de fisica de jogo: o resultado seria uma
## bicicleta tombada no chao meio segundo depois de o jogador soltar a tecla, o
## que e realista e injogavel.
##
## Entao aqui e cinematica. Um CharacterBody3D com velocidade escalar, guinada
## integrada e gravidade — o mesmo esqueleto do jogador a pe, com outra curva de
## aceleracao. A bicicleta nunca cai, nunca capota e nunca entala, e a sensacao
## de duas rodas nao vem da fisica: vem da INCLINACAO na curva, do esterco que
## fecha com a velocidade e da roda-livre que tica quando se para de pedalar.
## Sao tres detalhes de aparencia que valem mais que a simulacao.
##
## O que gira
## ----------
##   rodas      no rolamento, sempre que a bicicleta anda
##   pedivela   SO quando se pedala — a roda-livre existe para isso
##   guidao     no esterco, junto com o garfo e a roda dianteira
##
## Pedal que gira sozinho enquanto a bicicleta desce a ladeira e o erro que mais
## denuncia bicicleta de jogo, e evitar ele custa uma linha.
class_name Bicicleta
extends CharacterBody3D

## Velocidade de cruzeiro e de arranque, em m/s. 7,2 m/s sao 26 km/h — mais
## rapido que o jogador correndo (4,6) e bem mais lento que o carro (40 km/h),
## que e exatamente o lugar que uma bicicleta deve ocupar entre os dois.
const VEL_MAX := 7.2
const VEL_RE := 1.4
## Aceleracao da pedalada. Baixa: a bicicleta demora uns tres segundos para
## chegar na velocidade de cruzeiro, e e essa demora que da peso a ela.
const ACELERA := 3.2
const FREIA := 7.5
## Quanto a bicicleta perde por segundo com o pedal parado. E o arrasto do ar
## mais o atrito, e e o que faz a roda-livre ter para que servir.
const ARRASTO := 1.35

## Esterco em radianos por segundo, parado e a toda. Guidao de bicicleta gira
## muito mais que volante de carro em baixa velocidade — e assim que se faz uma
## curva de esquina a passo — e quase nada em velocidade, senao a bicicleta
## vira no proprio eixo a 26 km/h.
const GIRO_LENTO := 2.3
const GIRO_RAPIDO := 0.75
## Angulo maximo do guidao, so para o desenho.
const GUIDAO_MAX := 0.62
## Quanto a bicicleta deita na curva, no maximo. E o unico sinal de que ela tem
## duas rodas e nao quatro.
const INCLINACAO_MAX := 0.34

## Angulo em que ela fica escorada quando parada perto de uma parede.
const ENCOSTO := 0.26
## Ate onde procurar parede para escorar.
const ALCANCE_PAREDE := 1.05

## Metros que a bicicleta anda a cada volta completa do pedivela. E a marcha:
## 5,5 m e uma relacao de bicicleta de rua, e e ela que decide se a pedalada
## fica frenetica ou preguicosa na tela.
const DESENVOLVIMENTO := 5.5

## Abaixo disto a roda-livre para de ticar e a rolagem cala.
const VEL_SILENCIO := 0.5

signal sino_tocado

var montado: bool = false
var tinta: Color = Quadro.TINTAS[0]

var _malhas: Dictionary = {}
var _guidao: Node3D
var _roda_frente: Node3D
var _roda_tras: Node3D
var _pedivela: Node3D
var _farol: SpotLight3D
var _rolagem: AudioStreamPlayer3D
var _catraca: AudioStreamPlayer3D
var _sino: AudioStreamPlayer3D

var _velocidade: float = 0.0
var _giro: float = 0.0
var _esterco: float = 0.0
var _inclinacao: float = 0.0
var _rolo: float = 0.0
var _pedal: float = 0.0
var _pedalando: bool = false
## Angulo de escora. Zero quando alguem esta em cima.
var _encostada: float = 0.0
var _gravidade: float = 9.8


func _ready() -> void:
	add_to_group(&"bicicleta")
	collision_layer = 1
	collision_mask = 1
	_gravidade = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_giro = rotation.y

	_malhas = Quadro.montar(tinta)
	_montar_visual()
	_montar_colisao()
	_montar_som()
	set_physics_process(false)


# --- montagem ---------------------------------------------------------------

func _montar_visual() -> void:
	var material := load(Quadro.MATERIAL) as ShaderMaterial

	var quadro := MeshInstance3D.new()
	quadro.name = "Quadro"
	quadro.mesh = _malhas["quadro"]
	quadro.material_override = material
	quadro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quadro)

	# O pivo do esterco fica no eixo dianteiro, e as coordenadas da malha do
	# guidao ja vem contadas a partir dele (ver Quadro._guidao).
	_guidao = Node3D.new()
	_guidao.name = "Guidao"
	_guidao.position = Vector3(0.0, 0.0, Quadro.EIXO_FRENTE)
	add_child(_guidao)
	var mg := MeshInstance3D.new()
	mg.mesh = _malhas["guidao"]
	mg.material_override = material
	mg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_guidao.add_child(mg)

	# A dianteira e filha do guidao: ela gira junto com o garfo, que e a unica
	# razao de o esterco de bicicleta ser visivel.
	_roda_frente = _nova_roda(material, Vector3(0.0, Quadro.RAIO_RODA, 0.0))
	_guidao.add_child(_roda_frente)
	_roda_tras = _nova_roda(material,
		Vector3(0.0, Quadro.RAIO_RODA, Quadro.EIXO_TRAS))
	add_child(_roda_tras)

	_pedivela = Node3D.new()
	_pedivela.name = "Pedivela"
	_pedivela.position = Quadro.PEDALEIRA
	add_child(_pedivela)
	var mp := MeshInstance3D.new()
	mp.mesh = _malhas["pedivela"]
	mp.material_override = material
	mp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pedivela.add_child(mp)

	# Farol de dinamo. Nao ha bateria numa bicicleta destas: a luz vem da roda,
	# e por isso ela apaga quando a bicicleta para. E o detalhe que faz o farol
	# valer a pena existir — um farol que so acende andando conta ao jogador
	# como a bicicleta funciona sem uma linha de texto.
	_farol = SpotLight3D.new()
	_farol.name = "Farol"
	_farol.position = Vector3(0.0, 0.70, -0.46)
	_farol.rotation.x = deg_to_rad(-7.0)
	_farol.spot_range = 14.0
	_farol.spot_angle = 30.0
	_farol.spot_angle_attenuation = 1.1
	_farol.light_energy = 0.0
	_farol.light_color = Color(1.0, 0.94, 0.78)
	_farol.shadow_enabled = false
	_guidao.add_child(_farol)


func _nova_roda(material: ShaderMaterial, onde: Vector3) -> Node3D:
	var pivo := Node3D.new()
	pivo.name = "Roda"
	pivo.position = onde
	var m := MeshInstance3D.new()
	m.mesh = _malhas["roda"]
	m.material_override = material
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivo.add_child(m)
	return pivo


## Uma caixa so, e baixa.
##
## A silhueta real da bicicleta e quase toda vazio — se a colisao acompanhasse o
## desenho, o jogador ficaria preso na roda dianteira ao tentar passar entre ela
## e a parede. A caixa vai ate a altura do selim e nao mais: assim da para
## encostar nela e nao da para ficar entalado.
func _montar_colisao() -> void:
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(0.52, 1.02, Quadro.ENTRE_EIXOS + 0.22)
	forma.shape = caixa
	forma.position = Vector3(0.0, 0.51, 0.0)
	add_child(forma)


func _montar_som() -> void:
	_rolagem = AudioStreamPlayer3D.new()
	_rolagem.name = "Rolagem"
	_rolagem.bus = &"SFX"
	_rolagem.stream = AudioDirector.stream(&"bicicleta_loop")
	_rolagem.max_distance = 24.0
	_rolagem.unit_size = 3.0
	_rolagem.volume_db = -60.0
	add_child(_rolagem)

	_catraca = AudioStreamPlayer3D.new()
	_catraca.name = "Catraca"
	_catraca.bus = &"SFX"
	_catraca.stream = AudioDirector.stream(&"catraca_loop")
	_catraca.max_distance = 20.0
	_catraca.unit_size = 3.0
	_catraca.volume_db = -60.0
	add_child(_catraca)

	_sino = AudioStreamPlayer3D.new()
	_sino.name = "Sino"
	_sino.bus = &"SFX"
	_sino.stream = AudioDirector.stream(&"sino_bicicleta")
	_sino.max_distance = 45.0
	_sino.unit_size = 7.0
	_sino.volume_db = -4.0
	add_child(_sino)


# --- quem monta -------------------------------------------------------------

## A mais perto do ponto, ou nula. Mesmo papel que Transito.mais_perto tem para
## o carro, mas sem registro central: bicicleta nao e frota, e o grupo basta.
static func mais_perto(arvore: SceneTree, pos: Vector3, raio: float) -> Bicicleta:
	var melhor: Bicicleta = null
	var melhor_d := raio
	for b: Node in arvore.get_nodes_in_group(&"bicicleta"):
		var bike := b as Bicicleta
		if bike == null or not is_instance_valid(bike):
			continue
		var d := bike.global_position.distance_to(pos)
		if d < melhor_d:
			melhor_d = d
			melhor = bike
	return melhor


func assumir(_quem: Node) -> void:
	montado = true
	_encostada = 0.0
	_giro = rotation.y
	rotation = Vector3(0.0, _giro, 0.0)
	set_physics_process(true)
	if _rolagem.stream != null and not _rolagem.playing:
		_rolagem.play()
	if _catraca.stream != null and not _catraca.playing:
		_catraca.play()


func devolver() -> void:
	montado = false
	_velocidade = 0.0
	velocity = Vector3.ZERO
	_esterco = 0.0
	_inclinacao = 0.0
	_guidao.rotation.y = 0.0
	_farol.light_energy = 0.0
	_rolagem.stop()
	_catraca.stop()
	set_physics_process(false)
	encostar_em_parede()


## Toca a campainha. Duas batidas do polegar, que e o que o arquivo tem dentro.
func tocar_sino() -> void:
	if _sino.stream == null:
		return
	_sino.play()
	sino_tocado.emit()


## Onde o jogador senta. O corpo dele fica a cavalo do quadro, com os olhos na
## altura de quem esta sentado no selim — que e mais baixo que de pe, e e por
## isso que a rua parece outra de cima da bicicleta.
func assento() -> Vector3:
	return global_position + global_transform.basis.y * 0.02


## Onde ele desce. Pelo lado esquerdo, que e o lado de descer de bicicleta, e
## pelo direito se houver parede a esquerda.
func ponto_de_saida() -> Vector3:
	var espaco := get_world_3d().direct_space_state
	for lado: Vector3 in [-global_transform.basis.x, global_transform.basis.x]:
		var de := global_position + Vector3.UP * 0.9
		var ate := de + lado * 1.0
		var consulta := PhysicsRayQueryParameters3D.create(de, ate, 1)
		consulta.exclude = [get_rid()]
		if espaco.intersect_ray(consulta).is_empty():
			return global_position + lado * 0.85
	return global_position + Vector3.UP * 0.4


func velocidade() -> float:
	return _velocidade


## Procura parede dos dois lados e deita a bicicleta contra a que achar.
##
## E a mesma pergunta que o jogo ja faz para decidir onde cuspir quem sai do
## carro, virada do avesso: em vez de fugir da parede, procurar uma. Sem parede
## por perto ela fica de pe — nao ha cavalete no modelo, mas uma bicicleta de pe
## na calcada e menos estranho que uma deitada no ar.
##
## So inclina; nao muda de lugar. Chamar isto ao descer nao pode arrastar a
## bicicleta um metro para o lado debaixo do jogador, e quem a coloca no mundo
## ja sabe encostar ela na parede certa.
func encostar_em_parede() -> void:
	var mundo := get_world_3d()
	if mundo == null:
		return
	var espaco := mundo.direct_space_state
	# Quem colocou a bicicleta no mundo pode ter girado ela depois do _ready.
	_giro = rotation.y
	_encostada = 0.0
	for s: float in [1.0, -1.0]:
		var de := global_position + Vector3.UP * 0.75
		var ate := de + global_transform.basis.x * s * ALCANCE_PAREDE
		var consulta := PhysicsRayQueryParameters3D.create(de, ate, 1)
		consulta.exclude = [get_rid()]
		if espaco.intersect_ray(consulta).is_empty():
			continue
		# Deitar em volta da origem, que fica no chao, afunda a roda um
		# centimetro — R(1-cos 15 graus) — e nao os oito que afundaria se o pivo
		# estivesse na altura do cubo. Nao vale corrigir.
		_encostada = -ENCOSTO * s
		break
	_aplicar_pose()


func _aplicar_pose() -> void:
	rotation = Vector3(0.0, _giro, _encostada + _inclinacao)


# --- ciclo ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not montado:
		return

	var acelera := Input.get_action_strength(&"mover_frente")
	var freia := Input.get_action_strength(&"mover_tras")
	var esq := Input.get_action_strength(&"mover_esq")
	var dir := Input.get_action_strength(&"mover_dir")

	_pedalando = acelera > 0.05 and _velocidade > -0.05
	if _pedalando:
		_velocidade = minf(VEL_MAX, _velocidade + ACELERA * acelera * delta)
	elif freia > 0.05:
		# A mesma tecla freia e, com a bicicleta parada, anda de re — que numa
		# bicicleta e o jogador empurrando ela com os pes no chao, devagar.
		if _velocidade > 0.05:
			_velocidade = maxf(0.0, _velocidade - FREIA * freia * delta)
		else:
			_velocidade = maxf(-VEL_RE, _velocidade - ACELERA * freia * delta)
	else:
		_velocidade = move_toward(_velocidade, 0.0, ARRASTO * delta)

	# Esterco: muito parado, quase nada a toda. Sem isso a bicicleta a 26 km/h
	# faz uma curva de 90 graus no lugar.
	var quanto := clampf(absf(_velocidade) / VEL_MAX, 0.0, 1.0)
	var taxa := lerpf(GIRO_LENTO, GIRO_RAPIDO, quanto)
	var manete := esq - dir
	_esterco = move_toward(_esterco, manete, delta * 5.0)
	# Parada, ela nao gira sozinha: so quem anda esterca.
	if absf(_velocidade) > 0.15:
		_giro += _esterco * taxa * delta * signf(_velocidade)

	# A inclinacao acompanha o esterco e a velocidade. Deitar parado seria queda.
	_inclinacao = lerpf(_inclinacao, -_esterco * INCLINACAO_MAX * quanto,
		minf(1.0, 6.0 * delta))
	_guidao.rotation.y = _esterco * GUIDAO_MAX * lerpf(1.0, 0.25, quanto)
	_aplicar_pose()

	var frente := Vector3(-sin(_giro), 0.0, -cos(_giro))
	velocity.x = frente.x * _velocidade
	velocity.z = frente.z * _velocidade
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravidade * delta
	move_and_slide()

	# Bateu em alguma coisa de frente: perde o embalo em vez de raspar na parede
	# a toda por dez segundos.
	if is_on_wall() and absf(_velocidade) > 1.0:
		_velocidade *= 0.35

	_girar(delta)
	_atualizar_som()
	_farol.light_energy = clampf(absf(_velocidade) / VEL_MAX, 0.0, 1.0) * 2.6


func _girar(delta: float) -> void:
	_rolo += _velocidade / Quadro.RAIO_RODA * delta
	# O sinal e negativo porque a frente e -Z: girando no sentido positivo de X
	# o alto da roda andaria para tras.
	_roda_frente.rotation.x = -_rolo
	_roda_tras.rotation.x = -_rolo
	if _pedalando:
		_pedal += _velocidade / DESENVOLVIMENTO * TAU * delta
		_pedivela.rotation.x = -_pedal


func _atualizar_som() -> void:
	var v := absf(_velocidade)
	var quanto := clampf(v / VEL_MAX, 0.0, 1.0)
	if v < VEL_SILENCIO:
		_rolagem.volume_db = -60.0
		_catraca.volume_db = -60.0
		return
	# A rolagem sobe com a velocidade, na altura e no volume.
	_rolagem.pitch_scale = clampf(0.62 + quanto * 0.75, 0.4, 2.0)
	_rolagem.volume_db = -26.0 + quanto * 11.0
	# A catraca so existe quando NAO se pedala. E o som mais reconhecivel de uma
	# bicicleta depois do sino, e ele conta exatamente o que esta acontecendo:
	# a bicicleta esta andando por inercia.
	if _pedalando:
		_catraca.volume_db = -60.0
	else:
		_catraca.pitch_scale = clampf(0.45 + quanto * 1.25, 0.4, 2.2)
		_catraca.volume_db = -30.0 + quanto * 12.0
