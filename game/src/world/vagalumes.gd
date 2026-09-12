## Enxame de vaga-lume na beira da mata.
##
## Por que MultiMesh e nao um no por bicho
## ---------------------------------------
## Porque sao 90 pontos e cada um precisa de fase propria. Noventa
## `MeshInstance3D` sao noventa desenhos e noventa transformadas subindo para a
## GPU todo quadro, para desenhar noventa quadrados de dois pixels. Um
## `MultiMesh` e um desenho so, e a fase de cada bicho viaja em
## `INSTANCE_CUSTOM`, que e o campo que existe exatamente para isso.
##
## O ART-BIBLE proibe nevoa volumetrica com raymarch e a proibicao vale aqui
## junto: nada disto e simulacao. Sao quads, seno e dither — o que o PS1 tinha.
##
## Onde eles ficam
## ---------------
## Na mata dos dois lados, nunca sobre o asfalto. Vaga-lume em cima da pista le
## como particula de motor de jogo; vaga-lume entre o mato e a arvore le como
## interior de Minas em noite quente. `FAIXA_MIN` e o que guarda essa diferenca.
class_name Vagalumes
extends MultiMeshInstance3D

## Quantos bichos. Noventa e o numero em que o enxame ainda le como bichos
## separados; acima disso vira poeira luminosa e abaixo, tres LEDs no escuro.
const QUANTOS := 90

## Onde eles nascem, em metros, medido do centro da pista.
##
## A faixa e estreita porque o lugar e estreito. Entre a beira do asfalto e a
## parede de mata sobram uns tres metros; mais para dentro o bicho nasce ATRAS
## da arvore e o teste de profundidade o come — a primeira versao espalhava ate
## 13 m e a captura saiu com tres pixels verdes na tela inteira, sem erro nenhum
## no log.
const FAIXA_MIN := 3.4
const FAIXA_MAX := 6.5
## Quanto a frente e atras da origem do no.
const ALCANCE := 26.0
const RECUO := 8.0

## Um terco do enxame nasce PERTO DA LENTE, e nao na beira da mata.
##
## Nao e truque de captura: e como se ve vaga-lume de verdade. Os do fundo sao
## um piscar distante que o olho registra sem olhar; os que passam a um metro e
## meio do rosto sao o motivo de alguem parar o carro para ver. Sem esse grupo o
## enxame inteiro vira ruido de fundo de tres pixels.
##
## A camera do menu fica 7,2 m atras do carro (`MENU_RECUO`), entao "perto da
## lente" e Z positivo pequeno no espaco deste no.
const PERTO_FRACAO := 0.34
const PERTO_Z := Vector2(-1.0, 6.4)
const PERTO_X := Vector2(1.8, 5.2)
const PERTO_Y := Vector2(0.45, 2.0)
## Os de perto sao desenhados menores para saírem do mesmo tamanho na tela que
## os do fundo. Sem isto um bicho a dois metros vira uma bola branca de doze
## pixels — grande o bastante para estourar o blend_add e perder a cor, que era
## a unica coisa que dizia que aquilo e vaga-lume.
const PERTO_ESCALA := 0.2
## Altura: rasteiro. Vaga-lume de serra anda na altura do mato, nao da copa.
const ALTURA_MIN := 0.25
const ALTURA_MAX := 2.30

## Lado do quad, em metros.
##
## 0,24 da quatro pixels a dez metros na resolucao interna. Parece grande para
## um bicho e nao e: o fundo do menu leva um veu em gradiente por cima e depois
## o CRT, e um ponto de dois pixels em blend_add nao sobrevive aos dois. Medido
## com 0,17: um pixel verde na tela inteira.
const LADO := 0.24

## Ritmo das piscadas, em piscadas por segundo. A faixa e larga de proposito:
## bicho que pisca no mesmo compasso do vizinho denuncia o gerador.
const RITMO_MIN := 0.22
const RITMO_MAX := 0.70

const DERIVA_MIN := 0.25
const DERIVA_MAX := 1.10

const SHADER := "res://shaders/psx_vagalume.gdshader"

## Semente fixa: o enxame tem de sair igual em duas execucoes, senao nenhuma
## captura desta frente vale como comparacao.
const SEMENTE := 20260912

var _mat: ShaderMaterial


func _ready() -> void:
	# O fundo do menu roda com a arvore pausada.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Cada bicho e desenhado onde nasceu; o vai-e-vem e a piscada moram no
	# shader. Mexer nas transformadas por script seria noventa escritas por
	# quadro para andar dois centimetros.
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_montar()


func _montar() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(LADO, LADO)

	_mat = ShaderMaterial.new()
	if ResourceLoader.exists(SHADER):
		_mat.shader = load(SHADER)
	quad.material = _mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = QUANTOS

	var r := RandomNumberGenerator.new()
	r.seed = SEMENTE
	for i in QUANTOS:
		# Um lado ou o outro da pista, nunca o meio.
		var lado := 1.0 if r.randf() < 0.5 else -1.0
		var pos: Vector3
		var escala := 1.0
		if float(i) / float(QUANTOS) < PERTO_FRACAO:
			pos = Vector3(
				lado * r.randf_range(PERTO_X.x, PERTO_X.y),
				r.randf_range(PERTO_Y.x, PERTO_Y.y),
				r.randf_range(PERTO_Z.x, PERTO_Z.y))
			escala = PERTO_ESCALA
		else:
			pos = Vector3(
				lado * r.randf_range(FAIXA_MIN, FAIXA_MAX),
				r.randf_range(ALTURA_MIN, ALTURA_MAX),
				r.randf_range(-ALCANCE, RECUO))
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(
			Vector3.ONE * escala), pos))
		mm.set_instance_custom_data(i, Color(
			r.randf() * TAU,
			r.randf_range(RITMO_MIN, RITMO_MAX),
			r.randf_range(DERIVA_MIN, DERIVA_MAX),
			# Brilho relativo: os do fundo mais fracos, e nao por distancia —
			# por bicho. Um enxame de pontos todos iguais e uma grade.
			r.randf_range(0.45, 1.0)))
	multimesh = mm


## Quantos por cento do enxame acendem. A cena baixa isto na garoa e na
## cerracao em vez de tirar o no da arvore: sumir de uma vez le como falha de
## streaming, apagar le como tempo fechando.
func definir_densidade(valor: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter(&"densidade", clampf(valor, 0.0, 1.0))
