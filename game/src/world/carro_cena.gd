## O carro da cena da estrada: a lataria do transito, com interior, andando
## sobre trilhos.
##
## Por que nao e um `Carro`
## -----------------------
## O `Carro` do transito e um `VehicleBody3D` com quatro rodas de fisica, e
## precisa ser: ele divide a rua com outros seis, freia em semaforo e e dirigido
## pelo jogador. Nada disso existe aqui. Esta cena e um plano de cinema de
## oitenta segundos numa estrada que nem colisao tem — botar suspensao de
## verdade nisso seria assinar embaixo de um carro capotando no meio da fala.
##
## O que ele reaproveita, e reaproveita inteiro, e a APARENCIA: `Carroceria`
## monta a mesma lataria, os mesmos eixos e as mesmas luzes que o transito usa.
## Quando o carro dos NPCs melhorar, este melhora junto, sem uma linha aqui.
##
## O balanco
## ---------
## Um carro em estrada de terra a 65 km/h nao anda liso, e essa e a diferenca
## entre a cena parecer filmada e parecer um passeio de trilho de brinquedo. O
## balanco tem tres camadas somadas: o chacoalho miudo do cascalho, a lombada
## comprida do relevo (que ja vem do proprio caminho) e a inclinacao na curva.
## Nenhuma delas e aleatoria por quadro — todas saem de senos do tempo, senao o
## resultado e tremor de camera, e nao suspensao.
class_name CarroCena
extends Node3D

## Marea creme sujo das refs de chase (Estrada Velha).
const TINTA := Color(0.90, 0.88, 0.80)
const SEMENTE := 4410
const MODELO := Carroceria.Modelo.MAREA
const DESVIO_JOGAVEL := 1.35

## Onde o carro anda em relacao ao eixo da estrada. Levemente a direita, que e a
## mao da via — e o que faz a trilha de pneu da direita passar debaixo do carro
## em vez de ao lado dele.
const DESVIO_LATERAL := 0.16

## De quanto em quanto tempo o balanco miudo se repete, por metro andado. Nao e
## por segundo: buraco de estrada e uma coisa do CHAO, e a frequencia com que o
## carro bate nele tem de subir junto com a velocidade, senao acelerar deixa a
## estrada mais lisa.
const CHACOALHO_ONDA := [
	{"amp": 0.014, "onda": 3.4},
	{"amp": 0.008, "onda": 1.7},
	{"amp": 0.022, "onda": 9.8},
]
## Amplitude do arfar e do rolar — terra treme mais que asfalto.
const ARFAR := 0.72
const ROLAR := 0.55
## Quanto o carro inclina para fora na curva, em graus por unidade de curvatura.
const INCLINA_CURVA := 3.1

## Quanto a frente olha para calcular a curva. Vinte metros e o que o motorista
## enxerga na estrada: menos que isso e o volante corrige buraco, mais e o
## volante antecipa curva que ainda nao chegou.
const OLHAR_A_FRENTE := 20.0
## Curvatura que corresponde a volante todo virado.
const CURVA_CHEIA := 0.55

## Marchas por velocidade, em km/h. Terra: teto mais baixo que asfalto.
const MARCHAS := [12.0, 28.0, 55.0, 78.0]
const VEL_MAX_JOGAVEL := 72.0
const ACEL_JOGAVEL := 18.0
const FREIO_JOGAVEL := 32.0
const MOTOR_JOGAVEL := 9.0
const ESTERCO_RESPOSTA := 1.7
const MAT_CONE := "res://resources/materials/mat_cone_luz.tres"

var estrada: EstradaBuilder
## Distancia percorrida ao longo da estrada, em metros.
var distancia: float = 0.0
## Velocidade em km/h. A cena mexe nisto para o carro chegar e sair de cena.
var velocidade: float = 0.0
## Quando true, WASD manda na velocidade e no desvio lateral.
var jogavel: bool = false
var farois_acesos: bool = false

var cabine: CarroCabine
## Onde a camera de dentro do carro se pendura.
var suporte_camera: Node3D
## Pivo atras do Marea para a chase cam (3P).
var suporte_chase: Node3D

var _medidas: Dictionary = {}
var _corpo: MeshInstance3D
var _luzes: MeshInstance3D
var _eixo_frente: Node3D
var _eixo_tras: Node3D
var _som: MotorSom
var _farol: SpotLight3D
var _facho: MeshInstance3D
var _luz_cabine: OmniLight3D
var _brasa: OmniLight3D
var _rolo: float = 0.0
var _curva: float = 0.0
var _desvio: float = DESVIO_LATERAL
var _esterco_jogador: float = 0.0


func _ready() -> void:
	# Estrada FP: sem para-brisa opaco (P0). Trânsito continua com vidro via montar default.
	_medidas = Carroceria.montar(MODELO, TINTA, SEMENTE, false)
	_montar_lataria()
	_montar_eixos()
	_montar_cabine()
	_montar_farois()
	_montar_som()
	assentar()


func _montar_lataria() -> void:
	_corpo = MeshInstance3D.new()
	_corpo.name = "Lataria"
	_corpo.mesh = _medidas["corpo"] as ArrayMesh
	_corpo.material_override = load(Carroceria.MATERIAL) as ShaderMaterial
	_corpo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_corpo)

	_luzes = MeshInstance3D.new()
	_luzes.name = "Luzes"
	_luzes.mesh = _medidas["luzes"] as ArrayMesh
	_luzes.material_override = load(Carroceria.MATERIAL_LUZ) as ShaderMaterial
	_luzes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_luzes)


func _montar_eixos() -> void:
	var eixo := float(_medidas["entre_eixos"]) * 0.5
	_eixo_frente = _eixo_visual("EixoFrente",
		_medidas["eixo_frente"] as ArrayMesh, eixo)
	_eixo_tras = _eixo_visual("EixoTras",
		_medidas["eixo_tras"] as ArrayMesh, -eixo)


func _eixo_visual(nome: String, malha: ArrayMesh, z: float) -> Node3D:
	var no := Node3D.new()
	no.name = nome
	no.position = Vector3(0.0, Carroceria.RAIO_RODA, z)
	add_child(no)
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.material_override = load(Carroceria.MATERIAL) as ShaderMaterial
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	no.add_child(mi)
	return no


func _montar_cabine() -> void:
	cabine = CarroCabine.new()
	cabine.name = "Cabine"
	add_child(cabine)
	cabine.montar(_medidas)

	suporte_camera = Node3D.new()
	suporte_camera.name = "Olho"
	suporte_camera.position = cabine.olho()
	add_child(suporte_camera)

	suporte_chase = Node3D.new()
	suporte_chase.name = "Chase"
	var comp := float(_medidas["comprimento"])
	suporte_chase.position = Vector3(0.25, float(_medidas["altura"]) + 0.55,
		comp * 0.55 + 1.8)
	add_child(suporte_chase)


func _montar_farois() -> void:
	_farol = SpotLight3D.new()
	_farol.name = "Farol"
	var comp := float(_medidas["comprimento"])
	# Z negativo alem do nariz: Marea e mais longo; farol enterrado no casco
	# apaga o facho no FP/TP (proporcao WIP Renato).
	_farol.position = Vector3(0.0, 0.78, -comp * 0.5 - 0.45)
	_farol.rotation.x = deg_to_rad(-8.0)
	_farol.spot_range = 38.0
	_farol.spot_angle = 46.0
	_farol.spot_angle_attenuation = 0.8
	_farol.light_energy = 8.0
	_farol.light_color = Color(1.0, 0.88, 0.68)
	_farol.shadow_enabled = false
	_farol.visible = false
	add_child(_farol)

	_facho = MeshInstance3D.new()
	_facho.name = "Facho"
	var cor_f := Color(1.0, 0.93, 0.8, 0.55)
	_facho.mesh = PSXMesh.cone(0.12, 3.2, 12.0, 8, 3,
		cor_f, Color(cor_f.r, cor_f.g, cor_f.b, 0.0))
	if ResourceLoader.exists(MAT_CONE):
		_facho.material_override = load(MAT_CONE)
	_facho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_facho.sorting_offset = -1.0
	_facho.position = _farol.position
	_facho.rotation.x = PI * 0.5 + deg_to_rad(-9.0)
	_facho.visible = false
	add_child(_facho)

	# Fill fraco na cabine: sem ele o painel some na noite (refs mostram vinil).
	_luz_cabine = OmniLight3D.new()
	_luz_cabine.name = "LuzCabine"
	_luz_cabine.position = Vector3(-0.2, 1.15, -0.15)
	_luz_cabine.omni_range = 2.4
	_luz_cabine.light_energy = 0.55
	_luz_cabine.light_color = Color(1.0, 0.92, 0.82)
	_luz_cabine.shadow_enabled = false
	_luz_cabine.visible = false
	add_child(_luz_cabine)

	_brasa = OmniLight3D.new()
	_brasa.name = "Brasa"
	_brasa.position = Vector3(0.0, 0.55, float(_medidas["comprimento"]) * 0.5)
	_brasa.omni_range = 3.2
	_brasa.light_energy = 0.7
	_brasa.light_color = Color(1.0, 0.22, 0.16)
	_brasa.shadow_enabled = false
	_brasa.visible = false
	add_child(_brasa)

	# Fill externo fraco: Marea creme precisa ler na 3P a noite.
	var fill := OmniLight3D.new()
	fill.name = "FillExterior"
	fill.position = Vector3(0.0, 1.4, 0.2)
	fill.omni_range = 4.0
	fill.light_energy = 0.35
	fill.light_color = Color(0.95, 0.75, 0.55)
	fill.shadow_enabled = false
	fill.visible = false
	add_child(fill)


func acender_farois(aceso: bool = true) -> void:
	farois_acesos = aceso
	if _farol != null:
		_farol.visible = aceso
	if _facho != null:
		_facho.visible = aceso
	if _luz_cabine != null:
		_luz_cabine.visible = aceso
	if _brasa != null:
		_brasa.visible = aceso
	var fill := get_node_or_null("FillExterior") as OmniLight3D
	if fill != null:
		fill.visible = aceso


func mostrar_cabine(visivel: bool) -> void:
	if cabine != null:
		cabine.visible = visivel


func _montar_som() -> void:
	_som = MotorSom.new()
	_som.name = "Motor"
	add_child(_som)
	_som.acordar()


# --- movimento --------------------------------------------------------------

## Poe o carro no lugar sem andar. Serve ao primeiro quadro e a inspecao.
func assentar() -> void:
	_aplicar_transformada(0.0)


func dirigir(delta: float) -> void:
	if not jogavel:
		return
	var acelera := Input.get_action_strength(&"mover_frente")
	var freia := Input.get_action_strength(&"mover_tras")
	var esq := Input.get_action_strength(&"mover_esq")
	var dir_in := Input.get_action_strength(&"mover_dir")

	if acelera > 0.05:
		velocidade = move_toward(velocidade, VEL_MAX_JOGAVEL * acelera,
			ACEL_JOGAVEL * delta)
	elif freia > 0.05:
		velocidade = move_toward(velocidade, -18.0 * freia, FREIO_JOGAVEL * delta)
	else:
		velocidade = move_toward(velocidade, 0.0, MOTOR_JOGAVEL * delta)

	var alvo_esterco := (esq - dir_in)
	_esterco_jogador = move_toward(_esterco_jogador, alvo_esterco,
		ESTERCO_RESPOSTA * delta)
	var alvo_desvio := DESVIO_LATERAL + _esterco_jogador * DESVIO_JOGAVEL
	_desvio = lerpf(_desvio, alvo_desvio, clampf(delta * 2.0, 0.0, 1.0))


func avancar(delta: float) -> void:
	if jogavel:
		dirigir(delta)
	var passo := velocidade / 3.6 * delta
	distancia += passo
	# Negativo: uma roda que anda para a frente gira para tras em torno do
	# proprio +X. E a mesma conta de `Carro._girar_rodas`, e trocar o sinal poe
	# o carro andando com as rodas girando ao contrario — que e um defeito que
	# ninguem consegue nao ver depois que reparou uma vez.
	_rolo = wrapf(_rolo - passo / Carroceria.RAIO_RODA, -PI, PI)
	if estrada != null:
		estrada.atualizar(distancia)
	_aplicar_transformada(delta)
	if _som != null:
		_som.atualizar(velocidade / 3.6, marcha(), true, delta)
	if cabine != null:
		cabine.marcar(absf(velocidade))
		var volante := _curva / CURVA_CHEIA
		if jogavel:
			volante = clampf(volante + _esterco_jogador, -1.0, 1.0)
		cabine.estercar(volante)


func _aplicar_transformada(delta: float) -> void:
	var s := distancia
	var p := EstradaBuilder.ponto_em(s)
	var dir := EstradaBuilder.direcao_em(s)
	var lado := EstradaBuilder.lado_em(s)

	# A curva que vem: o quanto a direcao daqui a vinte metros difere da de
	# agora, com sinal. E o mesmo numero que vira volante na cabine e inclinacao
	# do carro, e por isso os dois nunca discordam.
	var adiante := EstradaBuilder.direcao_em(s + OLHAR_A_FRENTE)
	var curva_alvo := signf(adiante.cross(dir).y) * adiante.angle_to(dir)
	# Suaviza. O volante de um motorista nao acompanha a derivada da estrada
	# quadro a quadro; ele antecipa e corrige, e o atraso e o que da vida.
	_curva = lerpf(_curva, curva_alvo, clampf(delta * 2.6, 0.0, 1.0)) if delta > 0.0 \
		else curva_alvo

	var base := Basis.looking_at(dir, Vector3.UP)
	if jogavel and absf(_esterco_jogador) > 0.01:
		base = base * Basis(Vector3.UP, _esterco_jogador * 0.12)
	var salto := 0.0
	var fase := 0.0
	for onda: Dictionary in CHACOALHO_ONDA:
		salto += float(onda["amp"]) * sin(s / float(onda["onda"]) * TAU)
		fase += sin(s / float(onda["onda"]) * TAU + 1.1)
	# O chacoalho some com o carro parado: um carro de motor ligado vibra, mas
	# nao pula. Sem isto o plano com o carro parado treme sozinho.
	var forca := clampf(absf(velocidade) / 40.0, 0.0, 1.0)
	var arfa := deg_to_rad(ARFAR * fase * 0.5 * forca)
	var rola := deg_to_rad(ROLAR * sin(s / 5.3 * TAU) * forca
		- INCLINA_CURVA * (_curva / CURVA_CHEIA + _esterco_jogador * 0.35))
	base = base * Basis(Vector3.RIGHT, arfa) * Basis(Vector3.FORWARD, rola)

	var desvio := _desvio if jogavel else DESVIO_LATERAL
	transform = Transform3D(base,
		p + lado * desvio + Vector3(0.0, salto * forca, 0.0))

	# Basis composta, e nao Euler: escrever `rotation.y` depois de `rotation.x`
	# corrompe a ordem e a roda comeca a cambar. Mesma correcao que o Carro do
	# transito ja carrega.
	var esterco_roda := -_curva * 1.6
	if jogavel:
		esterco_roda -= _esterco_jogador * 0.45
	if _eixo_frente != null:
		_eixo_frente.transform.basis = (Basis(Vector3.UP, esterco_roda)
			* Basis(Vector3.RIGHT, _rolo))
	if _eixo_tras != null:
		_eixo_tras.transform.basis = Basis(Vector3.RIGHT, _rolo)


## Marcha em que o carro estaria, para o HUD e para o som.
func marcha() -> int:
	var m := 1
	for limite: float in MARCHAS:
		if absf(velocidade) > limite:
			m += 1
	return m


## Onde o carro esta agora, sem esperar o proximo quadro. A cena usa para
## enquadrar os planos de fora.
func onde() -> Vector3:
	return global_position
