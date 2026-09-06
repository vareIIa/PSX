## Pecas de parque, em dados brutos, no mesmo contrato do resto do kit.
##
## Vegetacao no estilo PS1
## -----------------------
## Arvore de PS1 nao e um modelo de arvore: e um tronco de caixa e um punhado de
## blocos de folha empilhados torto, com uma textura ruidosa por cima. O que da a
## leitura nao e a forma da folha, e a silhueta irregular contra a nevoa. Por isso
## nada aqui tem mais que meia duzia de volumes, e todos entram com `max_quad`
## folgado: uma copa de 2,5 m subdividida na grade padrao custa quatro vezes mais
## triangulos e a subdivisao nao aparece, porque a textura ja e ruido.
##
## Orcamento medido: 96 triangulos por arvore, 24 por arbusto. Dezoito arvores e
## uma duzia de arbustos por chunk cabem em 2200, que e um terco do teto.
##
## O vento
## -------
## Nada aqui e animado por script. O balanco vive no psx_surface.gdshader e le a
## rigidez do alfa do vertice: 0 nao sai do lugar, 1 balanca inteiro. Como as
## folhagens do chunk sao fundidas numa malha so, e a posicao de mundo que gera a
## fase, e duas arvores vizinhas entram fora de fase sozinhas.
class_name KitParque
extends RefCounted

## Subdivisao folgada da vegetacao. Ver o comentario de orcamento acima.
const QUAD_FOLHA := 4.0

## Rigidez maxima da copa. Acima disto a arvore comeca a arrastar a base do
## tronco junto e le como gelatina, nao como galho.
const CEDE_COPA := 1.0
const CEDE_TRONCO := 0.14

const ALTURA_BANCO := 0.44
const ALTURA_CERCA := 0.95

## Empilhamento do chao do parque, em metros.
##
## Os planos do parque sao coplanares em espirito, e nao podem ser em numero. Com
## 5 mm entre eles — que era o valor da primeira versao — a 45 m de distancia a
## precisao do buffer de profundidade ja chega perto de 2 mm, os dois planos
## passam a disputar o mesmo pixel e o chao pisca a cada passo do jogador. Foi
## exatamente o defeito reportado na calcada da praca.
##
## Dois centimetros entre camadas resolve com folga em todo o alcance de desenho,
## e o degrau que sobra le como o que e: placa assentada sobre a terra.
##
## A ordem tambem importa e ja estava errada: a areia da quadra ficava em 0,03,
## treze centimetros ABAIXO da grama, e a quadra inteira nascia enterrada.
const Y_GRAMA := 0.16
const Y_TERRA := 0.18
const Y_AREIA := 0.20
const Y_CALCAMENTO := 0.22

## Verdes da copa. Todos rebaixados: folha noturna sob sodio nao e verde de dia,
## e um verde vivo aqui puxa mais o olho que a loja acesa do outro lado da rua.
const VERDES: Array[Color] = [
	Color("6f7d55"), Color("5d6b48"), Color("7a8459"), Color("55613f"),
	Color("68764e"), Color("7f8a62"),
]
## Copa de arvore morta ou de outono. Uma em cada seis, para o parque nao ser um
## tapete verde uniforme.
const SECOS: Array[Color] = [
	Color("8a7448"), Color("796138"), Color("6d5c3d"),
]


# --- vegetacao --------------------------------------------------------------

## Arvore de folha larga. `porte` de 0 a 1 escala altura e copa juntas.
##
## Devolve o raio da copa, que quem chama usa para nao encostar duas arvores.
static func arvore(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		porte: float, rng: RandomNumberGenerator, seca: bool = false) -> float:
	var altura := lerpf(4.6, 8.4, porte)
	var raio_copa := lerpf(1.5, 2.6, porte)
	var tronco := lerpf(0.28, 0.44, porte)

	var cor_casca := Color(1.0, 1.0, 1.0).lerp(Color("8a7a66"), rng.randf_range(0.2, 0.8))
	# Fuste curto e copa alta. Meio a meio deixava a copa espremida num metro e
	# meio de altura, e o que saia era uma laje de folha sobre um pau — o
	# defeito classico de arvore de caixa. Com 40% de fuste a copa tem tres a
	# cinco metros para se espalhar e a silhueta fecha.
	var altura_fuste := altura * 0.40

	# Fuste em duas secoes, a de cima mais fina e levemente torta. Um cilindro
	# reto le como poste; a quebra no meio e o que faz virar tronco.
	var giro := rng.randf_range(0.0, TAU)
	KitModular.caixa_flex(sup, &"casca",
		base + Vector3(0.0, altura_fuste * 0.28, 0.0),
		Vector3(tronco, altura_fuste * 0.56, tronco), cor_casca, giro,
		base.y, base.y + altura, 0.0, CEDE_TRONCO, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	var desvio := Vector3(rng.randf_range(-0.22, 0.22), 0.0, rng.randf_range(-0.22, 0.22))
	KitModular.caixa_flex(sup, &"casca",
		base + desvio * 0.5 + Vector3(0.0, altura_fuste * 0.78, 0.0),
		Vector3(tronco * 0.78, altura_fuste * 0.56, tronco * 0.78),
		cor_casca, giro + 0.6,
		base.y, base.y + altura, 0.0, CEDE_TRONCO, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	var topo_fuste := base + desvio + Vector3(0.0, altura_fuste, 0.0)
	var paleta := SECOS if seca else VERDES
	var cor_base := paleta[rng.randi() % paleta.size()]

	# Copa: seis a oito blocos em espiral em volta do eixo. O afunilamento e o que
	# faz a copa ter forma: sem ele os blocos ficam todos na mesma largura e o
	# conjunto le como caixote. Com ele o meio e largo, o topo e a base sao
	# estreitos, e a silhueta contra a nevoa vira uma copa.
	var vao_copa := altura - altura_fuste

	# Nucleo: um bloco cheio no meio da copa, antes dos outros. Sem ele os blocos
	# externos ficam soltos em volta do tronco e, vistos de perto sob a luz do
	# poste, leem como tabuas penduradas — foi exatamente o que a captura do
	# campo mostrou. O nucleo fecha o vazio e os outros viram o contorno dele.
	KitModular.caixa_flex(sup, &"folhagem",
		topo_fuste + Vector3(0.0, vao_copa * 0.46, 0.0),
		Vector3(raio_copa * 1.25, vao_copa * 0.66, raio_copa * 1.25),
		cor_base, rng.randf_range(0.0, TAU),
		base.y, base.y + altura, CEDE_COPA * 0.5, CEDE_COPA * 0.9,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	var n := rng.randi_range(6, 8)
	for i in n:
		var t := float(i) / float(n)
		var ang := t * TAU * 1.6 + rng.randf_range(-0.3, 0.3)
		var alto := lerpf(0.05, 0.95, t) + rng.randf_range(-0.08, 0.08)
		var afunila := clampf(1.0 - absf(alto - 0.44) * 1.35, 0.28, 1.0)
		# Distancia curta de proposito: os blocos tem de se atravessar. Copa e uma
		# massa unica com a borda irregular, nao um conjunto de pecas em orbita.
		var dist := raio_copa * afunila * rng.randf_range(0.16, 0.44)
		var lado := raio_copa * afunila * rng.randf_range(0.78, 1.08)
		var centro := topo_fuste + Vector3(cos(ang) * dist, vao_copa * alto,
			sin(ang) * dist)
		# Tom por bloco. Sem isso a copa e uma mancha chapada e o volume some.
		var cor := cor_base.lerp(Color.WHITE, rng.randf_range(-0.14, 0.16))
		cor.a = 1.0
		# Recorte por alfa nos blocos de fora. E o que tira a silhueta de caixa
		# da copa: o alfa da textura come o canto do bloco e o que resta contra o
		# ceu e contorno de folha. O nucleo continua opaco, entao a arvore nunca
		# fica vazada.
		KitModular.caixa_flex(sup, &"folhagem_recorte", centro,
			Vector3(lado, lado * rng.randf_range(0.72, 1.0), lado * rng.randf_range(0.85, 1.1)),
			cor, ang,
			base.y, base.y + altura, CEDE_COPA * 0.5, CEDE_COPA,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Um galho saindo de lado, so nas arvores grandes. E o detalhe que quebra a
	# silhueta de pirulito.
	if porte > 0.55:
		var ang_g := rng.randf_range(0.0, TAU)
		var eixo := Vector3(cos(ang_g), 0.0, sin(ang_g))
		var b := Basis(Vector3.UP, ang_g) * Basis(Vector3.FORWARD, 0.75)
		KitModular.caixa_flex_inclinada(sup, &"casca",
			topo_fuste + eixo * (raio_copa * 0.42) + Vector3(0.0, -0.35, 0.0),
			Vector3(0.16, raio_copa * 1.1, 0.16), cor_casca, b,
			base.y, base.y + altura, CEDE_TRONCO, CEDE_COPA * 0.7, QUAD_FOLHA)

	colisao.append({
		"tamanho": Vector3(tronco * 2.0, altura_fuste, tronco * 2.0),
		"pos": base + Vector3(0.0, altura_fuste * 0.5, 0.0),
	})
	return raio_copa


## Conifera. Silhueta oposta a da arvore larga, e e so por isso que ela existe:
## um parque com um tipo so de copa le como copiar e colar.
static func pinheiro(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		porte: float, rng: RandomNumberGenerator) -> float:
	var altura := lerpf(5.0, 8.4, porte)
	var raio := lerpf(1.3, 2.1, porte)
	var tronco := 0.24

	KitModular.caixa_flex(sup, &"casca", base + Vector3(0.0, altura * 0.3, 0.0),
		Vector3(tronco, altura * 0.6, tronco), Color("8a7a66"),
		rng.randf_range(0.0, TAU),
		base.y, base.y + altura, 0.0, CEDE_TRONCO * 0.6,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	var cor := VERDES[rng.randi() % VERDES.size()].lerp(Color("3f4c33"), 0.35)
	cor.a = 1.0
	var camadas := 4
	for i in camadas:
		var t := float(i) / float(camadas - 1)
		var lado := raio * lerpf(1.0, 0.3, t) * 2.0
		var y := altura * lerpf(0.30, 0.98, t)
		# A saia de baixo e opaca e as de cima recortam. Assim a conifera fica
		# fechada na base, onde o tronco tem de sumir, e rendilhada no topo, onde
		# a silhueta encontra o ceu.
		KitModular.caixa_flex(sup,
			&"folhagem" if i == 0 else &"folhagem_recorte",
			base + Vector3(0.0, y, 0.0),
			Vector3(lado, altura * 0.2, lado),
			cor.lerp(Color.WHITE, t * 0.16), rng.randf_range(0.0, 0.8),
			base.y, base.y + altura,
			CEDE_COPA * 0.3, CEDE_COPA * 0.75,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	colisao.append({
		"tamanho": Vector3(0.7, altura * 0.6, 0.7),
		"pos": base + Vector3(0.0, altura * 0.3, 0.0),
	})
	return raio


## Arbusto: dois ou tres blocos baixos. Preenche o chao entre as arvores, que e
## onde o parque costuma ficar vazio demais.
static func arbusto(sup: Dictionary, base: Vector3, raio: float,
		rng: RandomNumberGenerator) -> void:
	var cor := VERDES[rng.randi() % VERDES.size()].lerp(Color("46512f"), 0.25)
	cor.a = 1.0
	for i in rng.randi_range(2, 3):
		var ang := rng.randf_range(0.0, TAU)
		var d := raio * rng.randf_range(0.0, 0.4)
		var lado := raio * rng.randf_range(0.75, 1.2)
		KitModular.caixa_flex(sup, &"arbusto",
			base + Vector3(cos(ang) * d, lado * 0.34, sin(ang) * d),
			Vector3(lado, lado * 0.68, lado * rng.randf_range(0.8, 1.1)),
			cor.lerp(Color.WHITE, float(i) * 0.07), ang,
			base.y, base.y + raio, 0.1, 0.55,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)


## Sebe continua entre dois pontos. Fecha o parque sem virar muro.
static func sebe(sup: Dictionary, colisao: Array[Dictionary],
		a: Vector3, b: Vector3, rng: RandomNumberGenerator) -> void:
	var delta := b - a
	var comp := delta.length()
	if comp < 0.6:
		return
	var dir := delta / comp
	var giro := atan2(dir.x, dir.z)
	var passo := 1.6
	var n := maxi(1, int(comp / passo))
	for i in n:
		var t := (float(i) + 0.5) / float(n)
		var centro := a + dir * (comp * t)
		var alt := rng.randf_range(0.85, 1.12)
		var cor := VERDES[rng.randi() % VERDES.size()].lerp(Color("3d4a2c"), 0.3)
		cor.a = 1.0
		KitModular.caixa_flex(sup, &"arbusto",
			centro + Vector3(0.0, alt * 0.5, 0.0),
			Vector3(comp / float(n) + 0.12, alt, rng.randf_range(0.72, 0.95)),
			cor, giro, a.y, a.y + alt, 0.08, 0.42,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	colisao.append({
		"tamanho": Vector3(absf(dir.x) * comp + 0.8, 1.0, absf(dir.z) * comp + 0.8),
		"pos": a + delta * 0.5 + Vector3(0.0, 0.5, 0.0),
	})


# --- piso -------------------------------------------------------------------

## Faixa de piso do parque, ja recortada pelo chunk que a desenha.
##
## O recorte e o que permite um parque de 160 m nascer de chunks montados em
## threads diferentes sem nenhum deles saber dos outros: cada um desenha a parte
## do retangulo que cai dentro dele.
static func piso(sup: Dictionary, material: StringName, retangulo: Rect2,
		altura: float, cor: Color = Color.WHITE) -> void:
	var corte := retangulo.intersection(Rect2(0.0, 0.0, KitModular.CHUNK, KitModular.CHUNK))
	if corte.size.x < 0.05 or corte.size.y < 0.05:
		return
	if not sup.has(material):
		sup[material] = PSXMesh.dados_vazios()
	var centro := Vector3(corte.position.x + corte.size.x * 0.5, altura,
		corte.position.y + corte.size.y * 0.5)
	PSXMesh.acumular_tingido(sup[material],
		PSXMesh.plane_dados(corte.size, PSXMesh.DEFAULT_UV_PER_M),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), centro), cor)


# --- mobiliario -------------------------------------------------------------

## Banco de praca: pes de concreto e reguas de madeira.
##
## `giro` aponta o encosto: quem senta olha para -Z local, ou seja para onde
## `giro` leva o -Z. Bancos de costas para o caminho sao o erro classico aqui.
static func banco(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float, desgaste: float = 0.0) -> void:
	var madeira := Color("8a6a44").lerp(Color("5a4a38"), desgaste)
	var largura := 1.9

	for lado: float in [-1.0, 1.0]:
		var pe := centro + Vector3(cos(giro) * largura * 0.42 * lado, 0.0,
			-sin(giro) * largura * 0.42 * lado)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			pe + Vector3(0.0, ALTURA_BANCO * 0.5, 0.0),
			Vector3(0.12, ALTURA_BANCO, 0.52), Color("9a968c"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Assento em tres reguas com fresta entre elas. Uma chapa unica le como
	# banco de plastico de ponto de onibus, nao como banco de praca.
	for i in 3:
		var d := (float(i) - 1.0) * 0.17
		KitModular.caixa_cor(sup, &"tabua",
			centro + Vector3(sin(giro) * d, ALTURA_BANCO, cos(giro) * d),
			Vector3(largura, 0.06, 0.14), madeira, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Encosto inclinado para tras.
	for i in 2:
		var y := ALTURA_BANCO + 0.24 + float(i) * 0.18
		KitModular.caixa_cor(sup, &"tabua",
			centro + Vector3(sin(giro) * -0.2, y, cos(giro) * -0.2),
			Vector3(largura, 0.14, 0.06), madeira, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	KitModular.solido(colisao, centro + Vector3(0.0, 0.3, 0.0),
		Vector3(largura, 0.6, 0.55), giro)


## Poste baixo de parque, com globo em vez de braco. Devolve onde pendurar a luz.
static func poste_globo(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3) -> Vector3:
	const ALTURA := 3.6
	KitModular.caixa(sup, &"metal", base + Vector3(0.0, ALTURA * 0.5, 0.0),
		Vector3(0.14, ALTURA, 0.14), 0.0, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa(sup, &"metal", base + Vector3(0.0, 0.22, 0.0),
		Vector3(0.32, 0.44, 0.32), 0.0, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	var globo := base + Vector3(0.0, ALTURA + 0.22, 0.0)
	KitModular.caixa(sup, &"janela_acesa", globo, Vector3(0.46, 0.5, 0.46),
		PI * 0.25, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	colisao.append({"tamanho": Vector3(0.34, ALTURA, 0.34),
		"pos": base + Vector3(0.0, ALTURA * 0.5, 0.0)})
	return globo


## Lixeira de parque: cilindro aproximado por caixa girada, com aro no topo.
static func lixeira(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	KitModular.caixa_cor(sup, &"metal_enferrujado",
		base + Vector3(0.0, 0.34, 0.0), Vector3(0.46, 0.68, 0.46),
		Color("6d6a60"), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.70, 0.0),
		Vector3(0.52, 0.06, 0.52), Color("8c8880"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	colisao.append({"tamanho": Vector3(0.6, 0.72, 0.6),
		"pos": base + Vector3(0.0, 0.36, 0.0)})


## Gradil baixo entre dois pontos, com prumos. Fecha o parque da rua.
static func gradil(sup: Dictionary, colisao: Array[Dictionary],
		a: Vector3, b: Vector3) -> void:
	var delta := b - a
	var comp := delta.length()
	if comp < 0.4:
		return
	var dir := delta / comp
	var giro := atan2(dir.x, dir.z)
	var cor := Color("4a4e50")

	for altura: float in [0.35, ALTURA_CERCA - 0.06]:
		KitModular.caixa_cor(sup, &"metal", a + delta * 0.5 + Vector3(0.0, altura, 0.0),
			Vector3(0.05, 0.05, comp), cor, giro, PSXMesh.FACE_TODAS, 8.0)

	var n := maxi(2, int(comp / 1.4))
	for i in n + 1:
		var t := float(i) / float(n)
		KitModular.caixa_cor(sup, &"metal",
			a + delta * t + Vector3(0.0, ALTURA_CERCA * 0.5, 0.0),
			Vector3(0.06, ALTURA_CERCA, 0.06), cor, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	colisao.append({
		"tamanho": Vector3(absf(dir.x) * comp + 0.2, ALTURA_CERCA, absf(dir.z) * comp + 0.2),
		"pos": a + delta * 0.5 + Vector3(0.0, ALTURA_CERCA * 0.5, 0.0),
	})


# --- brinquedos e quadra ----------------------------------------------------

## Balanco de duas cadeiras. As cadeiras balancam com o mesmo vento das arvores.
##
## A corrente e uma caixa fina com rigidez 0 no travessao e 1 no assento: ela
## verga em vez de girar, mas a 480x270, com a corrente medindo dois pixels, o
## que se le e o assento indo e voltando sozinho num parque vazio.
static func balanco(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float) -> void:
	const ALTURA := 2.35
	const VAO := 2.6
	var cor := Color("6a6560")

	# Dois portais em A, um em cada ponta. O A e o que faz o balanco parar de pe
	# no chao: duas colunas retas leem como trave de gol.
	var eixo_vao := Vector3(sin(giro + PI * 0.5), 0.0, cos(giro + PI * 0.5))
	var eixo_frente := Vector3(sin(giro), 0.0, cos(giro))
	for lado: float in [-1.0, 1.0]:
		var px: Vector3 = centro + eixo_vao * (VAO * 0.5 * lado)
		for inclina: float in [-1.0, 1.0]:
			var b := Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, 0.28 * inclina)
			KitModular.caixa_livre(sup, &"metal",
				px + Vector3(0.0, ALTURA * 0.5, 0.0) + eixo_frente * (0.34 * inclina),
				Vector3(0.09, ALTURA, 0.09), b, cor, QUAD_FOLHA)

	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, ALTURA, 0.0),
		Vector3(0.09, 0.09, VAO + 0.2), cor, giro, PSXMesh.FACE_TODAS, 8.0)

	for i in 2:
		var d := (float(i) - 0.5) * 1.1
		var eixo := Vector3(sin(giro + PI * 0.5), 0.0, cos(giro + PI * 0.5)) * d
		var assento_y := 0.52
		for corrente: float in [-0.22, 0.22]:
			var lat := Vector3(sin(giro), 0.0, cos(giro)) * corrente
			KitModular.caixa_flex(sup, &"corrente",
				centro + eixo + lat + Vector3(0.0, (ALTURA + assento_y) * 0.5, 0.0),
				Vector3(0.035, ALTURA - assento_y, 0.035), Color("7c7a74"), giro,
				assento_y, ALTURA, 1.0, 0.0, PSXMesh.FACE_TODAS, 8.0)
		KitModular.caixa_flex(sup, &"corrente",
			centro + eixo + Vector3(0.0, assento_y, 0.0),
			Vector3(0.5, 0.06, 0.24), Color("4c3f34"), giro,
			assento_y, ALTURA, 1.0, 0.0, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	for lado: float in [-1.0, 1.0]:
		colisao.append({"tamanho": Vector3(0.9, ALTURA, 0.9),
			"pos": centro + eixo_vao * (VAO * 0.5 * lado) + Vector3(0.0, ALTURA * 0.5, 0.0)})


## Escorregador. Rampa inclinada, escada e plataforma.
static func escorregador(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float) -> void:
	const ALTO := 1.75
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var cor := Color("8a5a44")

	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, ALTO, 0.0),
		Vector3(0.9, 0.08, 0.9), Color("6f6a63"), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"metal",
			centro + Vector3(sin(giro + PI * 0.5), 0.0, cos(giro + PI * 0.5)) * (0.4 * lado)
				+ Vector3(0.0, ALTO * 0.5, 0.0),
			Vector3(0.08, ALTO, 0.08), Color("6f6a63"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Rampa: caixa inclinada, base composta porque o giro em Y sozinho nao
	# inclina nada.
	var base := Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, -0.62)
	KitModular.caixa_livre(sup, &"metal",
		centro + frente * 1.15 + Vector3(0.0, ALTO * 0.5, 0.0),
		Vector3(0.66, 2.9, 0.08), base, cor, QUAD_FOLHA)

	# Escada atras.
	for i in 4:
		KitModular.caixa_cor(sup, &"metal",
			centro - frente * (0.5 + float(i) * 0.22)
				+ Vector3(0.0, ALTO - float(i) * 0.42, 0.0),
			Vector3(0.7, 0.06, 0.14), Color("6f6a63"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	colisao.append({"tamanho": Vector3(1.2, ALTO, 1.2),
		"pos": centro + Vector3(0.0, ALTO * 0.5, 0.0)})


## Quadra de areia com meio-fio de concreto e duas traves.
static func quadra_areia(sup: Dictionary, colisao: Array[Dictionary],
		retangulo: Rect2, giro_traves: bool) -> void:
	piso(sup, &"areia", retangulo, Y_AREIA)

	# Meio-fio em volta, em pedacos de tres metros. Assentado sobre a areia, nao
	# sobre a grama: a quadra e uma caixa de areia posta no gramado. Inteiro, ele sairia todo no
	# chunk que contem o meio da aresta e sumiria junto com ele; picado, cada
	# chunk desenha so o pedaco que e dele, igual a cerca do parque.
	var y := Y_AREIA + 0.09
	var arestas := [
		[retangulo.position, Vector2(retangulo.end.x, retangulo.position.y)],
		[Vector2(retangulo.position.x, retangulo.end.y), retangulo.end],
		[retangulo.position, Vector2(retangulo.position.x, retangulo.end.y)],
		[Vector2(retangulo.end.x, retangulo.position.y), retangulo.end],
	]
	for par: Array in arestas:
		var a: Vector2 = par[0]
		var b: Vector2 = par[1]
		var comp := (b - a).length()
		var horizontal := absf(b.x - a.x) > absf(b.y - a.y)
		var n := maxi(1, ceili(comp / 3.0))
		for i in n:
			var p0 := a.lerp(b, float(i) / float(n))
			var p1 := a.lerp(b, float(i + 1) / float(n))
			var meio := (p0 + p1) * 0.5
			if meio.x < 0.0 or meio.x >= KitModular.CHUNK:
				continue
			if meio.y < 0.0 or meio.y >= KitModular.CHUNK:
				continue
			var pedaco := comp / float(n)
			KitModular.caixa_cor(sup, &"meio_fio", Vector3(meio.x, y, meio.y),
				Vector3(pedaco if horizontal else 0.22, 0.18,
					0.22 if horizontal else pedaco),
				Color("a3a099"), 0.0, PSXMesh.FACE_TODAS, 8.0)

	var centro := retangulo.get_center()
	var eixo := retangulo.size.y if giro_traves else retangulo.size.x
	for lado: float in [-1.0, 1.0]:
		var p := Vector3(centro.x, 0.0, centro.y)
		if giro_traves:
			p.z += eixo * 0.46 * lado
		else:
			p.x += eixo * 0.46 * lado
		if p.x < -1.0 or p.x > KitModular.CHUNK + 1.0:
			continue
		if p.z < -1.0 or p.z > KitModular.CHUNK + 1.0:
			continue
		_trave(sup, colisao, p, 0.0 if giro_traves else PI * 0.5)


static func _trave(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	const ALTO := 2.0
	const VAO := 3.0
	var cor := Color("b6b2a8")
	var lateral := Vector3(cos(giro), 0.0, -sin(giro))
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"metal",
			base + lateral * (VAO * 0.5 * lado) + Vector3(0.0, ALTO * 0.5, 0.0),
			Vector3(0.1, ALTO, 0.1), cor, giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, ALTO, 0.0),
		Vector3(VAO + 0.1, 0.1, 0.1), cor, giro, PSXMesh.FACE_TODAS, 8.0)
	colisao.append({"tamanho": Vector3(VAO, ALTO, 0.3), "pos":
		base + Vector3(0.0, ALTO * 0.5, 0.0)})


## Chafariz de praca: tanque octogonal aproximado, agua parada e coluna central.
static func chafariz(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, raio: float) -> void:
	var cor := Color("a8a49a")
	# Oito paredes em volta. Octogono e o meio-termo do PS1 entre circulo e
	# quadrado: le como redondo e custa oito faces.
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var p := centro + Vector3(cos(ang), 0.0, sin(ang)) * raio
		KitModular.caixa_cor(sup, &"concreto_sujo", p + Vector3(0.0, 0.28, 0.0),
			Vector3(raio * 0.8, 0.56, 0.3), cor, -ang + PI * 0.5,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	piso(sup, &"agua", Rect2(centro.x - raio * 0.78, centro.z - raio * 0.78,
		raio * 1.56, raio * 1.56), 0.42, Color("6c7a80"))

	KitModular.caixa_cor(sup, &"concreto_sujo", centro + Vector3(0.0, 0.75, 0.0),
		Vector3(0.5, 1.5, 0.5), cor, PI * 0.25, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo", centro + Vector3(0.0, 1.55, 0.0),
		Vector3(1.1, 0.16, 1.1), cor, PI * 0.25, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	colisao.append({"tamanho": Vector3(raio * 2.0, 0.6, raio * 2.0),
		"pos": centro + Vector3(0.0, 0.3, 0.0)})


## Coreto: piso elevado, seis pilares e telhado. E o marco do parque, o que se ve
## de longe atraves das arvores.
static func coreto(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, raio: float) -> void:
	KitModular.caixa_cor(sup, &"concreto_sujo", centro + Vector3(0.0, 0.22, 0.0),
		Vector3(raio * 2.0, 0.44, raio * 2.0), Color("aba79c"), PI * 0.125,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	for i in 6:
		var ang := TAU * float(i) / 6.0
		KitModular.caixa_cor(sup, &"tabua",
			centro + Vector3(cos(ang), 0.0, sin(ang)) * (raio * 0.86)
				+ Vector3(0.0, 1.6, 0.0),
			Vector3(0.18, 2.3, 0.18), Color("6d5a44"), ang,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	KitModular.caixa_cor(sup, &"metal_enferrujado", centro + Vector3(0.0, 2.9, 0.0),
		Vector3(raio * 2.3, 0.18, raio * 2.3), Color("6a5f52"), PI * 0.125,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal_enferrujado", centro + Vector3(0.0, 3.25, 0.0),
		Vector3(raio * 1.3, 0.5, raio * 1.3), Color("6a5f52"), PI * 0.125,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	colisao.append({"tamanho": Vector3(raio * 2.0, 0.5, raio * 2.0),
		"pos": centro + Vector3(0.0, 0.25, 0.0)})


## Placa do parque na entrada. Nome proprio: sem ele o parque e "um parque", e
## com ele o jogador diz "o parque tal", que e o comeco de saber onde esta.
static func placa(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"metal",
			base + Vector3(cos(giro) * 0.62 * lado, 0.66, -sin(giro) * 0.62 * lado),
			Vector3(0.09, 1.32, 0.09), Color("59554e"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.placa(sup, &"placa_parque", base + Vector3(0.0, 1.5, 0.0),
		Vector2(1.5, 0.62), giro, Color.WHITE, 0.8)
	KitModular.placa(sup, &"placa_parque", base + Vector3(0.0, 1.5, 0.0),
		Vector2(1.5, 0.62), giro + PI, Color(0.8, 0.8, 0.8), 0.8)
	colisao.append({"tamanho": Vector3(1.5, 1.9, 0.3),
		"pos": base + Vector3(0.0, 0.95, 0.0)})
