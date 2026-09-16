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
## Forca do cone volumetrico do farol. Abaixo de 1.0 porque este carro aparece
## de perfil no plano rasante — ver `_montar_farois`.
const INTENSIDADE_FACHO := 0.75
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

## Quanto o apoio das rodas pode subir ou descer por segundo, em metros.
##
## E a suspensao, e ela e um filtro e nao uma mola. O micro-relevo do leito
## (`KitEstrada.ondulacao`) tem 22 cm de amplitude em ondas de 4,6 m, o que a
## 68 km/h da quatro hertz: seguido ao pe da letra, o carro tremeria vinte e
## dois centimetros quatro vezes por segundo, que nao e suspensao, e um
## britadeira. Ignorado, o pneu fica enterrado ate o eixo na crista e boiando
## no vale — que era o que acontecia, e aparece em qualquer plano rente ao
## chao. Meio metro por segundo deixa o carro acompanhar a lombada longa e
## atravessar a ondulacao curta por cima, que e o que um pneu de 60 cm faz.
const APOIO_TAXA := 0.55

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
## Motor audivel. Desligue quando o carro e CENARIO e nao assunto — o fundo da
## criacao de personagem e um carro na tela sem ser a cena que se esta vendo, e
## motor roncando atras de um menu le como som que escapou, nao como ambiencia.
## Tem de ser definido ANTES de entrar na arvore: `_ready` ja monta o som.
var com_som: bool = true

var cabine: CarroCabine
## Onde a camera de dentro do carro se pendura.
var suporte_camera: Node3D
## Pivo atras do Marea para a chase cam (3P).
var suporte_chase: Node3D

var _medidas: Dictionary = {}
var _corpo: MeshInstance3D
var _luzes: MeshInstance3D
## Os quatro pinos de roda, na ordem: frente esquerda, frente direita, tras
## esquerda, tras direita. Cada um no lugar da sua roda, e nao no centro do
## carro — ver `Carroceria.roda_unica`.
var _pinos: Array[Node3D] = []
var _som: MotorSom
var _farol: SpotLight3D
var _facho: MeshInstance3D
var _luz_cabine: OmniLight3D
var _brasa: OmniLight3D
var _rolo: float = 0.0
var _curva: float = 0.0
## Velocidade local do quadro passado, para derivar a aceleracao.
var _vel_anterior := Vector3.ZERO
## `--agua-vel=KMH`: a velocidade que a AGUA do vidro sente, com o carro parado.
##
## A captura segura o carro em zero (ver `AberturaEstrada._segurar_captura`), e
## sem isto a agua do vidro so pode ser fotografada parada — o vento, que e o
## que mais muda o desenho dela, nunca aparece numa captura. So a agua le este
## numero: o carro, a roda e o som continuam parados. Negativo = desligado.
var _vel_agua_forcada: float = _ler_vel_agua()
var _desvio: float = DESVIO_LATERAL
var _esterco_jogador: float = 0.0
## Altura em que as rodas estao apoiadas, em coordenada local da estrada.
## Ver `_apoio_no_leito`.
var _apoio: float = 0.0
var _apoio_valido: bool = false


func _ready() -> void:
	_medidas = Carroceria.montar(MODELO, TINTA, SEMENTE)
	_montar_lataria()
	_montar_eixos()
	_montar_cabine()
	_montar_farois()
	_montar_som()
	_montar_sombra()
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


## Quatro rodas em quatro pinos, e nao dois eixos.
##
## O eixo inteiro num no so funciona para ROLAR e quebra para ESTERCAR: o no
## fica no centro do carro, entao o giro em Y leva as duas rodas num arco em
## volta do centro em vez de girar cada uma no lugar. Ver o cabecalho de
## `Carroceria.roda_unica`.
func _montar_eixos() -> void:
	var eixo := float(_medidas["entre_eixos"]) * 0.5
	var meia_bitola := float(_medidas.get("bitola", 1.42)) * 0.5
	_pinos.clear()
	# Frente visual em -Z, a mesma da lataria depois da meia volta.
	for z: float in [-eixo, eixo]:
		for lado: float in [-1.0, 1.0]:
			var malha: ArrayMesh = (_medidas["roda_dir"] if lado > 0.0
				else _medidas["roda_esq"]) as ArrayMesh
			_pinos.append(_pino_de_roda(malha,
				Vector3(lado * meia_bitola, Carroceria.RAIO_RODA, z)))


func _pino_de_roda(malha: ArrayMesh, onde: Vector3) -> Node3D:
	var no := Node3D.new()
	no.name = "Roda"
	no.position = onde
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
		# Material PROPRIO, e nao o compartilhado.
		#
		# `intensidade` do cone e uma propriedade do material, entao mexer no
		# recurso carregado mexeria em todo carro da cidade junto. O carro desta
		# cena precisa do proprio numero: ele e o unico visto de PERFIL — o plano
		# rasante corre ao lado dele — e um cone aditivo de lado, contra uma
		# estrada quase preta, satura em branco e vira uma cunha chapada. De
		# dentro da cabine, que e de onde os carros da cidade sao vistos, o mesmo
		# cone aponta para longe e o defeito nunca aparecia.
		var mat_cone := (load(MAT_CONE) as ShaderMaterial).duplicate() as ShaderMaterial
		mat_cone.set_shader_parameter(&"intensidade", INTENSIDADE_FACHO)
		_facho.material_override = mat_cone
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
	_luz_cabine.light_energy = 0.32
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


## Acende o farol.
##
## `com_enchimento_externo` liga junto as duas fontes que existem para o carro
## ler de FORA a noite: a brasa da lanterna traseira e o fill que lava a lataria.
## Nenhuma das duas e luz de interior — a brasa fica atras do banco e o fill
## envolve o carro inteiro — e as duas atrapalham quem enquadra a cabine: medidas
## de dentro, elas acendiam um documento erguido no colo MAIS do que a lampada
## do teto, e enquanto estavam no ar nenhuma luz de cena conseguia ser a
## protagonista do quadro.
##
## A luz do painel (`_luz_cabine`) NAO entra nessa conta e segue o farol sempre:
## ela e a iluminacao do proprio mostrador, faz parte do interior e e ela que
## desenha o painel na cena da estrada. Desliga-la deixa o painel preto — que foi
## exatamente o que aconteceu quando este parametro era um "com_interior" que
## levava as tres juntas.
func acender_farois(aceso: bool = true,
		com_enchimento_externo: bool = true) -> void:
	farois_acesos = aceso
	if _farol != null:
		_farol.visible = aceso
	if _facho != null:
		_facho.visible = aceso
	if _luz_cabine != null:
		_luz_cabine.visible = aceso
	var externo := aceso and com_enchimento_externo
	if _brasa != null:
		_brasa.visible = externo
	var fill := get_node_or_null("FillExterior") as OmniLight3D
	if fill != null:
		fill.visible = externo


## Regula a forca do farol e do cone volumetrico.
##
## Porque isto nao e uma constante
## -------------------------------
## Os numeros de fabrica (energia 8,0 e cone 0,75) foram calibrados contra as
## refs NOTURNAS, onde o farol e a unica fonte de luz da cena e tem de
## desenhar a estrada sozinho. Num fim de tarde de chuva o ambiente ja
## desenha tudo, e os mesmos 8,0 nao acrescentam informacao nenhuma: viram um
## estouro branco. Nos dois planos novos da abertura isso apareceu do mesmo
## jeito — uma cunha chapada no meio do quadro, tapando justamente o carro
## que o plano existe para mostrar.
##
## De noite o farol ILUMINA; de dia ele SINALIZA. Sao dois numeros, e quem
## sabe qual deles vale e a cena, que conhece o clima.
func ajustar_farol(energia: float, cone: float) -> void:
	if _farol != null:
		_farol.light_energy = energia
	if _facho == null:
		return
	var mat := _facho.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(&"intensidade", cone)


func mostrar_cabine(visivel: bool) -> void:
	if cabine != null:
		cabine.visible = visivel


## A mancha de contato no chao. Ver `SombraContato`.
##
## Filha do carro, e nao do mundo: ela acompanha posicao e rumo sozinha, e o
## decal projeta para BAIXO no seu proprio eixo, entao a inclinacao da lombada
## e da curva ja entram de graca. Presa ao mundo, ela precisaria refazer todo
## o balanco que `_aplicar_transformada` ja calcula.
func _montar_sombra() -> void:
	var sombra := SombraContato.new()
	sombra.name = "SombraContato"
	# No plano do chao, e nao no meio do carro: o decal projeta do centro da
	# caixa para baixo, e a caixa tem 90 cm.
	sombra.position = Vector3(0.0, 0.05, 0.0)
	add_child(sombra)
	sombra.ajustar(float(_medidas["comprimento"]), float(_medidas["largura"]))


func _montar_som() -> void:
	if not com_som:
		return
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
		# O carro da cena nao tem maquina: a velocidade e roteiro. A rotacao que
		# o som usa e a que aquela velocidade daria no cambio do `Motor`, que e a
		# mesma conta que o transito usa — ver `Carro._soar`.
		var v := velocidade / 3.6
		_som.atualizar(Motor.giro_aparente(v, MODELO),
			clampf(absf(v) / 14.0, 0.2, 0.9), v, true, false, 0.0, delta)
	if cabine != null:
		cabine.marcar(absf(velocidade))
		# O limpador segue `Clima.chuva`, que e o "esta caindo AGORA" e nao a
		# memoria lenta da agua: o limpador para quando a chuva para, e nao cinco
		# minutos depois, com a rua ainda molhada. Sao duas grandezas diferentes e
		# confundi-las e o que deixa o carro varrendo vidro seco.
		cabine.atualizar_clima(Clima.chuva, _vel_local(), _acel_local(delta), delta)
		var volante := _curva / CURVA_CHEIA
		if jogavel:
			volante = clampf(volante + _esterco_jogador, -1.0, 1.0)
		cabine.estercar(volante)


## A velocidade do carro no espaco DELE, em m/s.
##
## O carro da cena nao tem corpo fisico: ele anda no eixo dele, para a frente,
## que em espaco final e -Z. A curva entra como a componente lateral que a agua
## do vidro sente — e a mesma grandeza que o `Carro` da cidade tira do
## `linear_velocity`, e e por isso que `atualizar_clima` recebe um vetor e nao
## um escalar.
func _vel_local() -> Vector3:
	var v := velocidade / 3.6
	if _vel_agua_forcada >= 0.0:
		v = _vel_agua_forcada / 3.6
	return Vector3(v * (_curva / CURVA_CHEIA) * 0.25, 0.0, -v)


static func _ler_vel_agua() -> float:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--agua-vel="):
			return maxf(0.0, a.trim_prefix("--agua-vel=").to_float())
	return -1.0


## A aceleracao do carro no espaco dele, em m/s^2. E ela que empurra a agua para
## a base do para-brisa numa freada (criterio C8).
func _acel_local(delta: float) -> Vector3:
	var v := _vel_local()
	var a := (v - _vel_anterior) / maxf(delta, 1e-4) if delta > 0.0 else Vector3.ZERO
	_vel_anterior = v
	# Um quadro perdido daria um pico de centenas de m/s^2 e jogaria toda a agua
	# do vidro para fora num so passo.
	return a.limit_length(12.0)


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
	var apoio := _apoio_no_leito(s, desvio, delta)
	transform = Transform3D(base,
		Vector3(p.x, apoio, p.z) + lado * desvio
		+ Vector3(0.0, salto * forca, 0.0))

	# Basis composta, e nao Euler: escrever `rotation.y` depois de `rotation.x`
	# corrompe a ordem e a roda comeca a cambar. Mesma correcao que o Carro do
	# transito ja carrega.
	var esterco_roda := -_curva * 1.6
	if jogavel:
		esterco_roda -= _esterco_jogador * 0.45
	var rolagem := Basis(Vector3.RIGHT, _rolo)
	var viradas := Basis(Vector3.UP, esterco_roda) * rolagem
	for k in _pinos.size():
		# Os dois primeiros sao a frente. Cada pino ja esta NO lugar da sua
		# roda, entao o giro acontece em torno do proprio pino.
		_pinos[k].transform.basis = viradas if k < 2 else rolagem


## Marcha em que o carro estaria, para o HUD e para o som.
## Em que altura as quatro rodas se apoiam, em coordenada local da estrada.
##
## O carro andava no `y` cru de `EstradaBuilder.ponto_em`, que e a linha do
## CAMINHO e nao a superficie: entre as duas ha o abaulamento, o sulco da
## trilha e o `LIFT` do leito, que somam ate vinte centimetros. Num plano de
## longe isso nao aparece; no plano da poca, com a lente a 34 cm do barro, o
## pneu some pela metade dentro do chao.
##
## O apoio e o PONTO MAIS ALTO sob as quatro rodas, e nao a media: um pneu
## de sessenta centimetros pousa na crista e ponteia o vale, ele nao afunda
## na media do terreno. Depois disso vem o limitador de velocidade vertical,
## que e a suspensao — ver `APOIO_TAXA`.
func _apoio_no_leito(s: float, desvio: float, delta: float) -> float:
	var meia_bitola := float(_medidas.get("bitola", 1.42)) * 0.5
	var meio_eixo := float(_medidas.get("entre_eixos", 2.57)) * 0.5
	var alto := -1e9
	for ds: float in [meio_eixo, -meio_eixo]:
		var eixo_p := EstradaBuilder.ponto_em(s + ds)
		for de: float in [-meia_bitola, meia_bitola]:
			alto = maxf(alto, eixo_p.y
				+ KitEstrada.altura_da_pista(eixo_p, desvio + de))
	if not _apoio_valido or delta <= 0.0:
		_apoio_valido = true
		_apoio = alto
	else:
		_apoio = move_toward(_apoio, alto, APOIO_TAXA * delta)
	return _apoio


func marcha() -> int:
	var m := 1
	for limite: float in MARCHAS:
		if absf(velocidade) > limite:
			m += 1
	return m


## As medidas da lataria: comprimento, largura, bitola, entre-eixos.
##
## Publica porque quem monta agua em volta do carro precisa saber onde a roda
## toca o chao, e esse numero (a bitola) so existe dentro da `Carroceria`.
## Deduzi-lo pela largura da errado: o Marea recua o eixo 6 cm e o Fusca 20.
func medidas() -> Dictionary:
	return _medidas

## Onde o carro esta agora, sem esperar o proximo quadro. A cena usa para
## enquadrar os planos de fora.
func onde() -> Vector3:
	return global_position
