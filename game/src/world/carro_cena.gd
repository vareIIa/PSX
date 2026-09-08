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

## Tinta do carro do protagonista. Nao e sorteada: e o verde escuro da print, e
## e a mesma cor em toda partida porque este carro e dele.
const TINTA := Color(0.34, 0.42, 0.34)
const SEMENTE := 4407

## Onde o carro anda em relacao ao eixo da estrada. Levemente a direita, que e a
## mao da via — e o que faz a trilha de pneu da direita passar debaixo do carro
## em vez de ao lado dele.
const DESVIO_LATERAL := 0.16

## De quanto em quanto tempo o balanco miudo se repete, por metro andado. Nao e
## por segundo: buraco de estrada e uma coisa do CHAO, e a frequencia com que o
## carro bate nele tem de subir junto com a velocidade, senao acelerar deixa a
## estrada mais lisa.
const CHACOALHO_ONDA := [
	{"amp": 0.011, "onda": 3.7},
	{"amp": 0.006, "onda": 1.9},
	{"amp": 0.017, "onda": 11.3},
]
## Amplitude do arfar e do rolar, em graus, na mesma logica.
const ARFAR := 0.55
const ROLAR := 0.42
## Quanto o carro inclina para fora na curva, em graus por unidade de curvatura.
const INCLINA_CURVA := 2.6

## Quanto a frente olha para calcular a curva. Vinte metros e o que o motorista
## enxerga na estrada: menos que isso e o volante corrige buraco, mais e o
## volante antecipa curva que ainda nao chegou.
const OLHAR_A_FRENTE := 20.0
## Curvatura que corresponde a volante todo virado.
const CURVA_CHEIA := 0.55

## Marchas por velocidade, em km/h. A tabela e a da print: 68 km/h e terceira.
const MARCHAS := [15.0, 32.0, 70.0, 95.0]

var estrada: EstradaBuilder
## Distancia percorrida ao longo da estrada, em metros.
var distancia: float = 0.0
## Velocidade em km/h. A cena mexe nisto para o carro chegar e sair de cena.
var velocidade: float = 0.0

var cabine: CarroCabine
## Onde a camera de dentro do carro se pendura.
var suporte_camera: Node3D

var _medidas: Dictionary = {}
var _corpo: MeshInstance3D
var _luzes: MeshInstance3D
var _eixo_frente: Node3D
var _eixo_tras: Node3D
var _som: MotorSom
var _rolo: float = 0.0
var _curva: float = 0.0


func _ready() -> void:
	_medidas = Carroceria.montar(Carroceria.Modelo.SEDA, TINTA, SEMENTE)
	_montar_lataria()
	_montar_eixos()
	_montar_cabine()
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


func _montar_som() -> void:
	_som = MotorSom.new()
	_som.name = "Motor"
	add_child(_som)
	_som.acordar()


# --- movimento --------------------------------------------------------------

## Poe o carro no lugar sem andar. Serve ao primeiro quadro e a inspecao.
func assentar() -> void:
	_aplicar_transformada(0.0)


func avancar(delta: float) -> void:
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
		cabine.marcar(velocidade)
		cabine.estercar(_curva / CURVA_CHEIA)


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
	var salto := 0.0
	var fase := 0.0
	for onda: Dictionary in CHACOALHO_ONDA:
		salto += float(onda["amp"]) * sin(s / float(onda["onda"]) * TAU)
		fase += sin(s / float(onda["onda"]) * TAU + 1.1)
	# O chacoalho some com o carro parado: um carro de motor ligado vibra, mas
	# nao pula. Sem isto o plano com o carro parado treme sozinho.
	var forca := clampf(velocidade / 45.0, 0.0, 1.0)
	var arfa := deg_to_rad(ARFAR * fase * 0.5 * forca)
	var rola := deg_to_rad(ROLAR * sin(s / 5.3 * TAU) * forca
		- INCLINA_CURVA * _curva / CURVA_CHEIA)
	base = base * Basis(Vector3.RIGHT, arfa) * Basis(Vector3.FORWARD, rola)

	transform = Transform3D(base,
		p + lado * DESVIO_LATERAL + Vector3(0.0, salto * forca, 0.0))

	# Basis composta, e nao Euler: escrever `rotation.y` depois de `rotation.x`
	# corrompe a ordem e a roda comeca a cambar. Mesma correcao que o Carro do
	# transito ja carrega.
	if _eixo_frente != null:
		_eixo_frente.transform.basis = (Basis(Vector3.UP, -_curva * 1.6)
			* Basis(Vector3.RIGHT, _rolo))
	if _eixo_tras != null:
		_eixo_tras.transform.basis = Basis(Vector3.RIGHT, _rolo)


## Marcha em que o carro estaria, para o HUD e para o som.
func marcha() -> int:
	var m := 1
	for limite: float in MARCHAS:
		if velocidade > limite:
			m += 1
	return m


## Onde o carro esta agora, sem esperar o proximo quadro. A cena usa para
## enquadrar os planos de fora.
func onde() -> Vector3:
	return global_position
