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
			Vector3(rng.randf_range(0.72, 0.95), alt, comp / float(n) + 0.12),
			cor, giro, a.y, a.y + alt, 0.08, 0.42,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	colisao.append({
		"tamanho": Vector3(absf(dir.x) * comp + 0.28, 1.0, absf(dir.z) * comp + 0.28),
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


## Colisao do piso do parque, recortada pelo chunk. Topo em `altura`, igual
## a calcada (0,16 m), senao o jogador cai para o asfalto e nao sai do parque.
static func piso_solido(colisao: Array[Dictionary], retangulo: Rect2,
		altura: float) -> void:
	var corte := retangulo.intersection(Rect2(0.0, 0.0, KitModular.CHUNK, KitModular.CHUNK))
	if corte.size.x < 0.05 or corte.size.y < 0.05:
		return
	var esp := 0.24
	colisao.append({
		"tamanho": Vector3(corte.size.x, esp, corte.size.y),
		"pos": Vector3(corte.position.x + corte.size.x * 0.5, altura - esp * 0.5,
			corte.position.y + corte.size.y * 0.5),
	})


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

	# 12 cm de espessura. 20 cm por eixo (o antigo) comia o vao do portao
	# quando o trecho era curto, e o jogador nao saia da praca.
	var esp := 0.12
	colisao.append({
		"tamanho": Vector3(absf(dir.x) * comp + esp, ALTURA_CERCA,
			absf(dir.z) * comp + esp),
		"pos": a + delta * 0.5 + Vector3(0.0, ALTURA_CERCA * 0.5, 0.0),
	})


## Pilares do portao. O vao entre eles e o caminho; a placa fica NUM pilar,
## nunca no meio — placa no eixo era parede no unico lugar por onde se sai.
static func pilares_portao(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float, meia_vao: float) -> void:
	var lateral := Vector3(cos(giro), 0.0, -sin(giro))
	var pedra := Color("5c5a52")
	for lado: float in [-1.0, 1.0]:
		var p := centro + lateral * (meia_vao * lado)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			p + Vector3(0.0, 1.05, 0.0), Vector3(0.34, 2.1, 0.34), pedra, giro)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			p + Vector3(0.0, 2.16, 0.0), Vector3(0.46, 0.14, 0.46),
			Color("8a867c"), giro)
		KitModular.solido(colisao, p + Vector3(0.0, 1.05, 0.0),
			Vector3(0.34, 2.1, 0.34), giro)


# --- brinquedos e quadra ----------------------------------------------------

## Tinta de brinquedo de parquinho de bairro: velha, fosca, nunca aco novo.
##
## Os tons sao mais claros do que a tinta que se quer ver. Eles MULTIPLICAM a
## textura de metal, que ja e cinza medio, e a cidade e noturna: a primeira
## versao usava a cor final e o gira-gira saia preto, lendo como um buraco no
## meio da areia.
const AZUL_BRINQUEDO := Color("8fbcd6")
const VERMELHO_BRINQUEDO := Color("d4796a")
const AMARELO_BRINQUEDO := Color("e8c377")
const VERDE_BRINQUEDO := Color("9cc487")
const CANO := Color("c2beb4")

## Balanco de duas cadeiras.
##
## O quadro sao dois portais em A ligados por um travessao, e cada uma das tres
## linhas abaixo conserta um defeito que a captura do parquinho mostrou:
##
##   O travessao corre no EIXO DOS PORTAIS, `giro + PI/2`. Com `giro` ele nascia
##   atravessado de noventa graus, saindo de um portal para o vazio — era a
##   primeira coisa que se via ao chegar no parquinho e o motivo de o brinquedo
##   ler como quebrado.
##
##   A perna do A inclina PARA DENTRO, e por isso o sinal do angulo e negativo.
##   Com ele positivo o topo abria e os pes fechavam: um V equilibrado numa
##   ponta so, que e o oposto do que segura o balanco de pe.
##
##   A corrente prende nas PONTAS do assento, ao longo do travessao. Presa na
##   frente e atras, como estava, ela passava fora da tabua de 26 cm e o assento
##   aparecia solto entre dois fios.
##
## O balanco de leve nao e script: a corrente entra no material `corrente`, que
## verga com o vento do psx_surface, com rigidez 1 embaixo e 0 em cima — ela sai
## do travessao parada e chega no assento andando. Quem chama alinha o vao com o
## eixo dominante de VENTO_DIR, senao o assento vai de lado em vez de ir e voltar.
const BALANCO_ALTURA := 2.4
const BALANCO_VAO := 3.0
## Abertura da perna do A. Acima disto o portal come o vao do assento vizinho.
const BALANCO_INCLINA := 0.30

static func balanco(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float) -> void:
	# Ao longo do travessao e no sentido do balanco. Todo o resto sai destes dois.
	var eixo := Vector3(cos(giro), 0.0, -sin(giro))
	var frente := Vector3(sin(giro), 0.0, cos(giro))

	# A perna e mais comprida que a altura porque esta inclinada, e o pe abre
	# metade da projecao. Os dois numeros saem do mesmo angulo; sem isso o topo
	# do A nao encosta no travessao.
	var perna := BALANCO_ALTURA / cos(BALANCO_INCLINA)
	var abre := tan(BALANCO_INCLINA) * BALANCO_ALTURA * 0.5

	for lado: float in [-1.0, 1.0]:
		var px := centro + eixo * (BALANCO_VAO * 0.5 * lado)
		for inclina: float in [-1.0, 1.0]:
			var b := Basis(Vector3.UP, giro) \
				* Basis(Vector3.RIGHT, -BALANCO_INCLINA * inclina)
			KitModular.caixa_livre(sup, &"metal",
				px + Vector3(0.0, BALANCO_ALTURA * 0.5, 0.0) + frente * (abre * inclina),
				Vector3(0.1, perna, 0.1), b, CANO, QUAD_FOLHA)
		# Travessa da perna, a um terco da altura. E o que fecha o A: sem ela as
		# duas pernas leem como dois postes tortos que por acaso se encontram.
		var y_t := BALANCO_ALTURA * 0.34
		var vao_t := tan(BALANCO_INCLINA) * (BALANCO_ALTURA - y_t) * 2.0
		KitModular.caixa_cor(sup, &"metal", px + Vector3(0.0, y_t, 0.0),
			Vector3(0.07, 0.07, vao_t), CANO, giro, PSXMesh.FACE_TODAS, 8.0)

	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, BALANCO_ALTURA, 0.0),
		Vector3(0.11, 0.11, BALANCO_VAO + 0.3), CANO, giro + PI * 0.5,
		PSXMesh.FACE_TODAS, 8.0)

	var assento_y := 0.5
	for i in 2:
		var sob := centro + eixo * ((float(i) - 0.5) * BALANCO_VAO * 0.42)
		var cor_assento := VERMELHO_BRINQUEDO if i == 0 else AZUL_BRINQUEDO
		for corrente: float in [-0.19, 0.19]:
			KitModular.caixa_flex(sup, &"corrente",
				sob + eixo * corrente
					+ Vector3(0.0, (BALANCO_ALTURA + assento_y) * 0.5, 0.0),
				Vector3(0.035, BALANCO_ALTURA - assento_y, 0.035), Color("7c7a74"),
				giro, assento_y, BALANCO_ALTURA, 1.0, 0.0, PSXMesh.FACE_TODAS, 8.0)
		KitModular.caixa_flex(sup, &"corrente", sob + Vector3(0.0, assento_y, 0.0),
			Vector3(0.46, 0.07, 0.26), cor_assento, giro,
			assento_y, BALANCO_ALTURA, 1.0, 0.0, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# So os portais tem colisao. O assento anda, e uma caixa parada debaixo dele
	# seria uma parede invisivel no meio do vao.
	for lado: float in [-1.0, 1.0]:
		KitModular.solido(colisao,
			centro + eixo * (BALANCO_VAO * 0.5 * lado)
				+ Vector3(0.0, BALANCO_ALTURA * 0.5, 0.0),
			Vector3(0.24, BALANCO_ALTURA, abre * 2.0 + 0.2), giro)


## Escorregador: torre com guarda-corpo, rampa que encosta no chao e escada.
##
## A rampa antiga era solta no ar — comprimento chutado, topo furando a
## plataforma trinta centimetros acima dela e pe enterrado na areia. Aqui o
## comprimento SAI do angulo e da altura, entao ela comeca na borda da
## plataforma e termina no chao por construcao, em qualquer altura de torre.
const ESCORREGA_ALTO := 1.9
## Inclinacao da rampa. 35 graus: escorrega na leitura e ainda e piso andavel
## para o CharacterBody3D, que so trata como chao ate 45.
const ESCORREGA_ANG := 0.62
const ESCORREGA_LARGURA := 0.66

static func escorregador(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float) -> void:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var eixo := Vector3(cos(giro), 0.0, -sin(giro))
	var meia := 0.52

	# Torre: quatro pes e o piso.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"metal",
				centro + eixo * (meia * 0.86 * sx) + frente * (meia * 0.86 * sz)
					+ Vector3(0.0, ESCORREGA_ALTO * 0.5, 0.0),
				Vector3(0.09, ESCORREGA_ALTO, 0.09), CANO, giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, ESCORREGA_ALTO, 0.0),
		Vector3(meia * 2.0, 0.09, meia * 2.0), AZUL_BRINQUEDO, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Guarda-corpo nos dois lados e no fundo. E o que faz a torre ler como
	# brinquedo e nao como mesa alta.
	var y_guarda := ESCORREGA_ALTO + 0.52
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"metal",
			centro + eixo * (meia * sx) + Vector3(0.0, y_guarda, 0.0),
			Vector3(0.06, 0.06, meia * 2.0), CANO, giro, PSXMesh.FACE_TODAS, 8.0)
		for sz: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"metal",
				centro + eixo * (meia * sx) + frente * (meia * sz)
					+ Vector3(0.0, ESCORREGA_ALTO + 0.26, 0.0),
				Vector3(0.06, 0.52, 0.06), CANO, giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal",
		centro - frente * meia + Vector3(0.0, y_guarda, 0.0),
		Vector3(meia * 2.0, 0.06, 0.06), CANO, giro, PSXMesh.FACE_TODAS, 8.0)

	# A rampa. `comp` e a hipotenusa que fecha a altura com o angulo e `avanco` a
	# projecao dela no chao: saem do mesmo triangulo, e e por isso que ela encosta
	# nas duas pontas.
	var comp := ESCORREGA_ALTO / sin(ESCORREGA_ANG)
	var avanco := ESCORREGA_ALTO / tan(ESCORREGA_ANG)
	var base := Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, ESCORREGA_ANG - PI * 0.5)
	var meio_rampa := centro + frente * (meia + avanco * 0.5) \
		+ Vector3(0.0, ESCORREGA_ALTO * 0.5 + 0.06, 0.0)
	KitModular.caixa_livre(sup, &"metal", meio_rampa,
		Vector3(ESCORREGA_LARGURA, comp + 0.3, 0.08), base, Color("b9b5aa"),
		QUAD_FOLHA)
	# Borda dos dois lados. Sem ela a rampa e uma tabua inclinada; com ela vira
	# calha, que e a forma que se reconhece de longe.
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_livre(sup, &"metal",
			meio_rampa + eixo * (ESCORREGA_LARGURA * 0.5 * sx)
				+ Vector3(0.0, 0.09, 0.0),
			Vector3(0.08, comp + 0.3, 0.2), base, AMARELO_BRINQUEDO, QUAD_FOLHA)

	# Escada atras: dois montantes inclinados e os degraus entre eles.
	var recuo := 0.95
	var ang_escada := atan2(recuo, ESCORREGA_ALTO)
	var b_escada := Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, ang_escada)
	var comp_escada := sqrt(recuo * recuo + ESCORREGA_ALTO * ESCORREGA_ALTO)
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_livre(sup, &"metal",
			centro - frente * (meia + recuo * 0.5) + eixo * (meia * 0.8 * sx)
				+ Vector3(0.0, ESCORREGA_ALTO * 0.5, 0.0),
			Vector3(0.07, comp_escada, 0.07), b_escada, CANO, QUAD_FOLHA)
	var degraus := 4
	for i in degraus:
		var t := (float(i) + 0.6) / float(degraus)
		KitModular.caixa_cor(sup, &"metal",
			centro - frente * (meia + recuo * (1.0 - t))
				+ Vector3(0.0, ESCORREGA_ALTO * t, 0.0),
			Vector3(meia * 1.6, 0.06, 0.16), VERMELHO_BRINQUEDO, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Colisao: a torre em pe e a rampa inclinada de verdade. A rampa com caixa
	# reta viraria um degrau intransponivel na frente do brinquedo.
	KitModular.solido(colisao, centro + Vector3(0.0, ESCORREGA_ALTO * 0.5, 0.0),
		Vector3(meia * 2.0, ESCORREGA_ALTO, meia * 2.0), giro)
	colisao.append({
		"tamanho": Vector3(ESCORREGA_LARGURA + 0.16, 0.16, comp),
		"pos": meio_rampa,
		"giro": Vector3(-ESCORREGA_ANG * cos(giro), giro, ESCORREGA_ANG * sin(giro)),
	})


## Gangorra. Parada e torta: uma ponta no chao e a outra no alto e a pose em que
## gangorra de parquinho vazio passa a vida.
const GANGORRA_COMP := 3.2
const GANGORRA_PIVO := 0.52

static func gangorra(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float, cor: Color) -> void:
	var eixo := Vector3(cos(giro), 0.0, -sin(giro))
	var frente := Vector3(sin(giro), 0.0, cos(giro))

	KitModular.caixa_cor(sup, &"concreto_sujo",
		centro + Vector3(0.0, GANGORRA_PIVO * 0.5, 0.0),
		Vector3(0.5, GANGORRA_PIVO, 0.34), Color("9a968c"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	var ang := atan2(GANGORRA_PIVO * 0.8, GANGORRA_COMP * 0.5)
	var b := Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, -ang)
	KitModular.caixa_livre(sup, &"tabua",
		centro + Vector3(0.0, GANGORRA_PIVO + 0.06, 0.0),
		Vector3(0.3, 0.09, GANGORRA_COMP), b, cor, QUAD_FOLHA)

	# Assento e alca em cada ponta, na altura que a tabua tem ali.
	for lado: float in [-1.0, 1.0]:
		var dy := sin(ang) * GANGORRA_COMP * 0.42 * lado
		var p := centro + frente * (GANGORRA_COMP * 0.42 * lado) \
			+ Vector3(0.0, GANGORRA_PIVO + 0.1 + dy, 0.0)
		KitModular.caixa_cor(sup, &"tabua", p, Vector3(0.34, 0.07, 0.34), cor,
			giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
		var alca := p + frente * (0.36 * lado)
		KitModular.caixa_cor(sup, &"metal", alca + Vector3(0.0, 0.24, 0.0),
			Vector3(0.36, 0.05, 0.05), CANO, giro, PSXMesh.FACE_TODAS, 8.0)
		for sx: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"metal",
				alca + eixo * (0.16 * sx) + Vector3(0.0, 0.12, 0.0),
				Vector3(0.05, 0.24, 0.05), CANO, giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)

	KitModular.solido(colisao, centro + Vector3(0.0, GANGORRA_PIVO * 0.5, 0.0),
		Vector3(0.6, GANGORRA_PIVO, GANGORRA_COMP * 0.7), giro)


## Gira-gira: disco octogonal, mastro e quatro alcas.
##
## O octogono sai de duas caixas cruzadas a 45 graus, que e o truque de sempre —
## le como redondo, custa doze triangulos e nao pede malha propria.
static func gira_gira(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, raio: float) -> void:
	var altura := 0.42
	# O tampo e claro e as nervuras e que sao pintadas. Com o disco inteiro na
	# cor da tinta, visto de cima ele lia como um buraco escuro na areia — dois
	# metros e meio de mancha, a peca mais chamativa do parquinho pelo motivo
	# errado.
	for k in 2:
		KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, altura, 0.0),
			Vector3(raio * 2.0, 0.1, raio * 0.84), Color("c8c4b8"),
			PI * 0.5 * float(k), PSXMesh.FACE_TODAS, QUAD_FOLHA)
	for k in 2:
		KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, altura + 0.05, 0.0),
			Vector3(raio * 1.9, 0.04, 0.14), VERDE_BRINQUEDO,
			PI * 0.5 * float(k), PSXMesh.FACE_TODAS, 8.0)
	# Saia sob o disco, para ele nao ler como chapa flutuando.
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, altura * 0.5, 0.0),
		Vector3(raio * 1.1, altura, raio * 1.1), Color("6f6a63"), PI * 0.25,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, 0.6, 0.0),
		Vector3(0.12, 1.2, 0.12), CANO, 0.0, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Quatro alcas, do alto do mastro para a borda do disco.
	for i in 4:
		var ang := TAU * float(i) / 4.0 + PI * 0.125
		var fora := Vector3(cos(ang), 0.0, sin(ang))
		var b := Basis(Vector3.UP, -ang + PI * 0.5) * Basis(Vector3.RIGHT, 0.85)
		KitModular.caixa_livre(sup, &"metal",
			centro + fora * (raio * 0.44) + Vector3(0.0, 0.8, 0.0),
			Vector3(0.06, raio * 1.15, 0.06), b, AMARELO_BRINQUEDO, QUAD_FOLHA)

	colisao.append({"tamanho": Vector3(raio * 1.8, 0.6, raio * 1.8),
		"pos": centro + Vector3(0.0, 0.3, 0.0)})


## Trepa-trepa: duas escadas de ponta e as barras por cima.
const TREPA_ALTO := 1.85
const TREPA_COMP := 3.0
const TREPA_LARG := 1.1

static func trepa_trepa(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float) -> void:
	var eixo := Vector3(cos(giro), 0.0, -sin(giro))
	var frente := Vector3(sin(giro), 0.0, cos(giro))

	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"metal",
				centro + eixo * (TREPA_LARG * 0.5 * sx)
					+ frente * (TREPA_COMP * 0.5 * sz)
					+ Vector3(0.0, TREPA_ALTO * 0.5, 0.0),
				Vector3(0.08, TREPA_ALTO, 0.08), AZUL_BRINQUEDO, giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
		# Longarina, de ponta a ponta.
		KitModular.caixa_cor(sup, &"metal",
			centro + eixo * (TREPA_LARG * 0.5 * sx) + Vector3(0.0, TREPA_ALTO, 0.0),
			Vector3(0.08, 0.08, TREPA_COMP), AZUL_BRINQUEDO, giro,
			PSXMesh.FACE_TODAS, 8.0)
		# Degraus da escada de ponta, que e por onde se sobe.
		for i in 3:
			KitModular.caixa_cor(sup, &"metal",
				centro + frente * (TREPA_COMP * 0.5 * sx)
					+ Vector3(0.0, TREPA_ALTO * (float(i) + 1.0) / 4.0, 0.0),
				Vector3(0.05, 0.05, TREPA_LARG), CANO, giro + PI * 0.5,
				PSXMesh.FACE_TODAS, 8.0)

	var barras := 5
	for i in barras:
		var t := (float(i) + 0.5) / float(barras)
		KitModular.caixa_cor(sup, &"metal",
			centro + frente * lerpf(-TREPA_COMP * 0.5, TREPA_COMP * 0.5, t)
				+ Vector3(0.0, TREPA_ALTO, 0.0),
			Vector3(0.05, 0.05, TREPA_LARG), CANO, giro + PI * 0.5,
			PSXMesh.FACE_TODAS, 8.0)

	for sz: float in [-1.0, 1.0]:
		KitModular.solido(colisao,
			centro + frente * (TREPA_COMP * 0.5 * sz)
				+ Vector3(0.0, TREPA_ALTO * 0.5, 0.0),
			Vector3(TREPA_LARG + 0.2, TREPA_ALTO, 0.2), giro)


## Bichinho de mola. O unico brinquedo que se mexe sozinho de perto: entra no
## material `corrente`, com o pe rigido e a cabeca solta, e ginga no mesmo vento
## que balanca a arvore atras dele. E o detalhe que diz que o parquinho esta
## vazio agora, e nao abandonado.
static func mola(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float, cor: Color) -> void:
	var assento := 0.62
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var topo := base.y + 1.0

	KitModular.caixa_cor(sup, &"concreto_sujo", base + Vector3(0.0, 0.05, 0.0),
		Vector3(0.44, 0.1, 0.44), Color("9a968c"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_flex(sup, &"corrente", base + Vector3(0.0, assento * 0.5, 0.0),
		Vector3(0.14, assento, 0.14), Color("6f6a63"), giro,
		base.y, topo, 0.0, 0.7, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Corpo, cabeca e alca, todos flexiveis a partir do pe: e o conjunto que
	# ginga, nao a mola sozinha.
	KitModular.caixa_flex(sup, &"corrente",
		base + Vector3(0.0, assento + 0.16, 0.0), Vector3(0.34, 0.3, 0.86), cor,
		giro, base.y, topo, 0.0, 0.9, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_flex(sup, &"corrente",
		base + frente * 0.34 + Vector3(0.0, assento + 0.44, 0.0),
		Vector3(0.26, 0.34, 0.26), cor, giro, base.y, topo, 0.0, 1.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_flex(sup, &"corrente",
		base + frente * 0.16 + Vector3(0.0, assento + 0.44, 0.0),
		Vector3(0.44, 0.05, 0.05), CANO, giro, base.y, topo, 0.0, 1.0,
		PSXMesh.FACE_TODAS, 8.0)

	KitModular.solido(colisao, base + Vector3(0.0, 0.45, 0.0),
		Vector3(0.5, 0.9, 0.9), giro)


## Caixa de areia com meio-fio em volta.
##
## O piso sai em ladrilhos de 2,5 m com tom e nivel proprios, e nao num plano so.
## E o mesmo tratamento do calcamento do caminho, pelo mesmo motivo: superficie
## grande, chapada e perfeitamente plana nao existe em parque nenhum, e a areia
## uniforme era a peca que mais denunciava o gerador. O tom sai do INDICE do
## ladrilho, entao dois chunks que desenham pedacos da mesma caixa concordam
## sobre ele sem falar um com o outro.
const LADRILHO_AREIA := 2.5
const DESNIVEL_AREIA := 0.008

static func caixa_de_areia(sup: Dictionary, retangulo: Rect2) -> void:
	var nx := maxi(1, int(round(retangulo.size.x / LADRILHO_AREIA)))
	var nz := maxi(1, int(round(retangulo.size.y / LADRILHO_AREIA)))
	var passo := Vector2(retangulo.size.x / float(nx), retangulo.size.y / float(nz))
	for j in nz:
		for i in nx:
			var p := retangulo.position + Vector2(passo.x * float(i), passo.y * float(j))
			# Sobreposicao, senao o degrau entre dois ladrilhos abre fresta e
			# aparece a grama por baixo.
			var r := Rect2(p - Vector2(0.05, 0.05), passo + Vector2(0.1, 0.1))
			var t := _tom(i, j)
			# O tom varia em BRILHO, nao em matiz. Sorteando os tres canais
			# separados, como estava, cada ladrilho puxava para um lado do
			# circulo de cor e a caixa de areia saia com remendos rosa e verdes.
			var tom := lerpf(0.9, 1.08, t)
			piso(sup, &"areia", r,
				Y_AREIA + lerpf(-DESNIVEL_AREIA, DESNIVEL_AREIA, _tom(i + 7, j + 3)),
				Color(tom, tom * 0.995, tom * 0.98))
	_meio_fio_em_volta(sup, retangulo)


## Meio-fio picado em pedacos de tres metros. Inteiro, ele sairia todo no chunk
## que contem o meio da aresta e sumiria junto com ele.
static func _meio_fio_em_volta(sup: Dictionary, retangulo: Rect2) -> void:
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


## Ruido puro do indice do ladrilho. Nao pode sair de RandomNumberGenerator pelo
## mesmo motivo de todo sorteio do parque: dois chunks desenham pedacos
## diferentes da mesma caixa e tem de concordar sobre o tom de cada ladrilho.
static func _tom(i: int, j: int) -> float:
	var h := (i * 73856093) ^ (j * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(absi(h) % 100003) / 100003.0


## Quadra de areia com meio-fio de concreto e duas traves.
##
## `com_traves` existe porque o parquinho usava esta mesma peca e ganhava DUAS
## TRAVES DE GOL em cima dos brinquedos: a caixa de areia das criancas com um
## campo de futebol desenhado por cima.
static func quadra_areia(sup: Dictionary, colisao: Array[Dictionary],
		retangulo: Rect2, giro_traves: bool, com_traves: bool = true) -> void:
	caixa_de_areia(sup, retangulo)
	if not com_traves:
		return

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


# --- telhados ---------------------------------------------------------------

## Celula das aguas de telhado, em metros.
##
## Nao e enfeite. Com `vertex_lighting` a luz so existe no vertice: uma agua de
## seis metros feita de dois triangulos e atravessada pelo facho do poste no
## meio e continua preta, porque nao ha vertice onde a luz bate. Um metro e meio
## poe vertice dentro do pocao de cada lampiao da praca.
const QUAD_TELHA := 1.5

## Telha de barro da praca, em duas faces. Sao constantes compartilhadas de
## proposito: igreja, coreto e casario sao o MESMO barro, e quando cada peca
## escolhia o proprio tom o coreto saia laranja vivo ao lado de um casario
## marrom escuro — tres telhados de tres cidades diferentes na mesma foto.
##
## A diferenca entre as duas faces e o que da a dobra. Sob luz de vertice quase
## rasante, duas aguas do mesmo tom leem como um plano so e a cumeeira some.
const TELHA_CLARA := Color("b06a3c")
const TELHA_ESCURA := Color("7a4224")

## Uma agua de telhado: quadrilatero plano, subdividido, virado para `olhar`.
##
## Os cantos vem no contorno: `a` e `b` no beiral, `c` sobre `b` e `d` sobre `a`
## na cumeeira. Degenerado e valido — com `c` e `d` no mesmo ponto a agua vira
## a face triangular de uma piramide, e o telhado do coreto e o da sineira usam
## exatamente esse caso.
##
## Quem chama diz so para onde a agua OLHA. A regra de que a face aparece do
## lado OPOSTO ao produto vetorial mora aqui dentro, e em lugar nenhum mais:
## ela ja derrubou o Fusca, os cinco carros de caixa e o chao inteiro da
## estrada, e o jeito de nao errar uma quarta vez e nao ter onde errar.
static func agua_de_telhado(sup: Dictionary, material: StringName,
		a: Vector3, b: Vector3, c: Vector3, d: Vector3, cor: Color,
		olhar: Vector3, uv_por_m: float = 0.5,
		max_quad: float = QUAD_TELHA) -> void:
	var k := (b - a).cross(d - a)
	if k.length_squared() < 1e-9:
		return
	var normal := k.normalized()
	if normal.dot(olhar) < 0.0:
		normal = -normal
	# `direto` guarda a decisao de giro; a regra e aplicada uma vez, nao por celula.
	var direto := k.dot(olhar) < 0.0

	var comp_beiral := maxf(a.distance_to(b), c.distance_to(d))
	var comp_queda := maxf(a.distance_to(d), b.distance_to(c))
	var nu := maxi(1, ceili(comp_beiral / max_quad))
	var nv := maxi(1, ceili(comp_queda / max_quad))

	var fonte := PSXMesh.dados_vazios()
	var fv: PackedVector3Array = fonte["v"]
	var fn: PackedVector3Array = fonte["n"]
	var fuv: PackedVector2Array = fonte["uv"]
	var fc: PackedColorArray = fonte["c"]
	var fi: PackedInt32Array = fonte["i"]
	for iv in nv + 1:
		var v := float(iv) / float(nv)
		for iu in nu + 1:
			var u := float(iu) / float(nu)
			fv.append(a.lerp(b, u).lerp(d.lerp(c, u), v))
			fn.append(normal)
			# UV ancorada em metro de mundo: a telha tem o mesmo tamanho na
			# igreja e na casinha, que e o que faz o casario ler como um conjunto.
			fuv.append(Vector2(u * comp_beiral * uv_por_m,
				(1.0 - v) * comp_queda * uv_por_m))
			fc.append(cor)
	for iv in nv:
		for iu in nu:
			var i0 := iv * (nu + 1) + iu
			var i1 := i0 + 1
			var i2 := i0 + nu + 1
			var i3 := i2 + 1
			if direto:
				fi.append_array([i0, i1, i3, i0, i3, i2])
			else:
				fi.append_array([i0, i3, i1, i0, i2, i3])
	fonte["v"] = fv
	fonte["n"] = fn
	fonte["uv"] = fuv
	fonte["c"] = fc
	fonte["i"] = fi
	if not sup.has(material):
		sup[material] = PSXMesh.dados_vazios()
	PSXMesh.acumular(sup[material], fonte, Transform3D.IDENTITY)


## Telhado de duas aguas. A cumeeira corre no Z local e as aguas caem para o X
## local; `giro` gira o conjunto. Devolve a altura do pico acima de `base.y`,
## que quem chama usa para pousar cruz, cumeeira ou frontao sem refazer a conta.
##
## `base` e o centro do vao no nivel do BEIRAL, nao no chao: a inclinacao e a
## unica coisa que a peca precisa saber, e amarra-la ao chao obrigaria toda
## chamada a somar a altura da parede de novo.
##
## As duas aguas ganham cores diferentes de proposito. A noite, sob luz de
## vertice quase rasante, duas aguas do mesmo tom leem como um plano so e a
## cumeeira some; meio tom de diferenca devolve a dobra sem custar geometria.
## `beiral_ponta` e separado do lateral porque a igreja precisa dele em zero: o
## frontao e a parede da fachada subindo ACIMA da telha, e um beiral avancando
## na ponta poe telha na frente do frontao e come justamente a silhueta
## triangular que as refs 01 e 02 mostram. No casario os dois sao iguais.
static func telhado_duas_aguas(sup: Dictionary, base: Vector3,
		largura: float, comprimento: float, altura: float, giro: float,
		cor: Color, cor_sombra: Color, beiral: float = 0.45,
		material: StringName = &"teto", beiral_ponta: float = -1.0) -> float:
	if beiral_ponta < 0.0:
		beiral_ponta = beiral
	var eixo := Basis(Vector3.UP, giro)
	var hx := largura * 0.5 + beiral
	var hz := comprimento * 0.5 + beiral_ponta
	for sx: float in [-1.0, 1.0]:
		var a := base + eixo * Vector3(hx * sx, 0.0, -hz * sx)
		var b := base + eixo * Vector3(hx * sx, 0.0, hz * sx)
		var c := base + eixo * Vector3(0.0, altura, hz * sx)
		var d := base + eixo * Vector3(0.0, altura, -hz * sx)
		var olhar := (eixo * Vector3(altura * sx, hx, 0.0)).normalized()
		agua_de_telhado(sup, material, a, b, c, d,
			cor if sx > 0.0 else cor_sombra, olhar)
	# Cumeeira: sem ela as duas aguas se encontram numa aresta de um pixel e o
	# dither serrilha a linha do topo a cada passo do jogador.
	KitModular.caixa_cor(sup, material, base + eixo * Vector3(0.0, altura, 0.0),
		Vector3(0.34, 0.2, comprimento + beiral_ponta * 2.0), cor_sombra, giro,
		PSXMesh.FACE_TODAS, QUAD_TELHA)
	# Forro do beiral. As aguas sao de face UNICA — `agua_de_telhado` orienta
	# cada uma para fora — e o beiral avanca meio metro alem da parede. Debaixo
	# desse balanco, portanto, nao existia superficie nenhuma: quem olhasse a
	# casa de baixo para cima, ou de tras com a lente abaixo da linha do beiral,
	# via o telhado pelo lado de dentro, que e o mesmo que nao ver telhado.
	#
	# Uma placa horizontal no nivel do beiral fecha o vao inteiro de uma vez, e
	# de quebra da espessura a borda: telha sem espessura le como papel recortado.
	KitModular.caixa_cor(sup, material, base + eixo * Vector3(0.0, -0.05, 0.0),
		Vector3(largura + beiral * 2.0, 0.1, comprimento + beiral_ponta * 2.0),
		cor_sombra.lerp(Color.BLACK, 0.45), giro, PSXMesh.FACE_TODAS, 2.0)
	return altura


## Oitao: o triangulo que fecha a ponta do telhado de duas aguas. Fica no plano
## da parede, nao na ponta do beiral — o beiral avanca por cima dele e e essa
## sombra que da profundidade a fachada.
static func oitao(sup: Dictionary, material: StringName, base: Vector3,
		largura: float, altura: float, giro: float, cor: Color,
		max_quad: float = QUAD_TELHA) -> void:
	var eixo := Basis(Vector3.UP, giro)
	var a := base + eixo * Vector3(-largura * 0.5, 0.0, 0.0)
	var b := base + eixo * Vector3(largura * 0.5, 0.0, 0.0)
	var pico := base + eixo * Vector3(0.0, altura, 0.0)
	agua_de_telhado(sup, material, a, b, pico, pico, cor,
		eixo * Vector3(0.0, 0.0, 1.0), 0.5, max_quad)


## Telhado piramidal de `lados` aguas sobre um poligono de raio `raio`.
## Serve a sineira (4) e ao coreto (8) com a mesma conta.
static func telhado_piramide(sup: Dictionary, material: StringName,
		base: Vector3, raio: float, altura: float, lados: int, giro: float,
		cor: Color, cor_sombra: Color) -> void:
	var apex := base + Vector3(0.0, altura, 0.0)
	for i in lados:
		var ang0 := TAU * float(i) / float(lados) + giro
		var ang1 := TAU * float(i + 1) / float(lados) + giro
		var p0 := base + Vector3(cos(ang0) * raio, 0.0, sin(ang0) * raio)
		var p1 := base + Vector3(cos(ang1) * raio, 0.0, sin(ang1) * raio)
		var meio := (ang0 + ang1) * 0.5
		# A agua olha para fora e para cima; a componente Y sobe com a altura.
		var olhar := Vector3(cos(meio) * altura, raio, sin(meio) * altura).normalized()
		agua_de_telhado(sup, material, p0, p1, apex, apex,
			cor if (i % 2) == 0 else cor_sombra, olhar)


## Coreto octogonal da praca: base de pedra, escada, oito pilares de madeira,
## guarda-corpo e telhado de telha. E o marco central da Praca da Matriz.
##
## Telhado = 8 triangulos (apex -> beiral). Caixa inclinada lia V/borboleta
## no perfil; face sem espessura fecha a silhueta /\ das refs 01/03.
## A escada de pedra com peitoril faz a base ler como podium.
static func coreto(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, raio: float) -> void:
	var madeira := Color("5a4634")
	var pedra := Color("9a968c")
	var pedra_degrau := Color("b0aca2")
	var pedra_espelho := Color("7a766c")
	var telha := TELHA_CLARA
	var telha_escura := TELHA_ESCURA
	var y_piso := 0.58

	# Base octogonal aproximada: caixa girada 22.5 graus + anel de pedra.
	KitModular.caixa_cor(sup, &"concreto_sujo", centro + Vector3(0.0, y_piso * 0.5, 0.0),
		Vector3(raio * 2.05, y_piso, raio * 2.05), pedra, PI / 8.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	for i in 8:
		var ang := TAU * float(i) / 8.0 + PI / 8.0
		var p := centro + Vector3(cos(ang), 0.0, sin(ang)) * (raio * 0.95)
		KitModular.caixa_cor(sup, &"concreto_sujo", p + Vector3(0.0, y_piso * 0.5, 0.0),
			Vector3(raio * 0.72, y_piso, 0.28), pedra, -ang + PI * 0.5,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Escada no lado +Z (sul da praca, olhando a igreja ao norte).
	# Quatro degraus com espelho escuro + piso claro e peitoris laterais —
	# sem isso some na nevoa e vira bloco unico.
	var n_degraus := 4
	var larg_escada := 1.55
	for degrau in n_degraus:
		var t := float(degrau)
		var h_deg := y_piso / float(n_degraus)
		var y_topo := (t + 1.0) * h_deg
		var prof := 0.38
		var afast := raio + 0.12 + t * 0.36
		# Espelho (riser).
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + Vector3(0.0, y_topo - h_deg * 0.5, afast - prof * 0.15),
			Vector3(larg_escada - t * 0.08, h_deg, 0.1), pedra_espelho, 0.0,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		# Piso do degrau (tread).
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + Vector3(0.0, y_topo - 0.04, afast),
			Vector3(larg_escada - t * 0.08, 0.08, prof), pedra_degrau, 0.0,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Peitoris / cheeks da escada.
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + Vector3(sx * (larg_escada * 0.5 + 0.08), y_piso * 0.45,
				raio + 0.55),
			Vector3(0.18, y_piso * 0.9, 1.55), pedra, 0.0,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Oito pilares; guarda-corpo pula o vao sul (+Z) — portal pro eixo da igreja.
	var alt_pilar := 2.35
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var p := centro + Vector3(cos(ang), 0.0, sin(ang)) * (raio * 0.82)
		KitModular.caixa_cor(sup, &"tabua",
			p + Vector3(0.0, y_piso + alt_pilar * 0.5, 0.0),
			Vector3(0.16, alt_pilar, 0.16), madeira, ang,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		var ang2 := TAU * float(i + 1) / 8.0
		# Segmento que olha pro sul (escada / pin Cine2): sem grade.
		var mid_ang := ang + (ang2 - ang) * 0.5
		if sin(mid_ang) > 0.55:
			continue
		var a := centro + Vector3(cos(ang), 0.0, sin(ang)) * (raio * 0.82)
		var b := centro + Vector3(cos(ang2), 0.0, sin(ang2)) * (raio * 0.82)
		var meio := (a + b) * 0.5
		var comp := a.distance_to(b)
		var giro := atan2(b.x - a.x, b.z - a.z)
		# Corrimao e frechal; entre eles as ripas verticais das refs.
		KitModular.caixa_cor(sup, &"tabua",
			meio + Vector3(0.0, y_piso + 1.05, 0.0),
			Vector3(0.09, 0.1, comp), madeira, giro,
			PSXMesh.FACE_TODAS, 8.0)
		KitModular.caixa_cor(sup, &"tabua",
			meio + Vector3(0.0, y_piso + 0.18, 0.0),
			Vector3(0.08, 0.09, comp), madeira, giro,
			PSXMesh.FACE_TODAS, 8.0)
		# Ripa grossa e vao largo de proposito. Ripa de 5 cm a doze metros nao
		# chega a um pixel em 480x270: vira o mesmo chiado do dither e o gradil
		# inteiro cintila. Com 9 cm e vao igual, de longe le como massa cheia e
		# de perto — que e como a ref 03 ve o coreto, na lanterna — le como ripa.
		var n_ripa := maxi(2, int(comp / 0.30))
		for r in n_ripa:
			var t := (float(r) + 0.5) / float(n_ripa)
			KitModular.caixa_cor(sup, &"tabua",
				a.lerp(b, t) + Vector3(0.0, y_piso + 0.6, 0.0),
				Vector3(0.09, 0.82, 0.09), madeira.lerp(Color("3a2c1e"), 0.25),
				giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Telhado octogonal (ref 01/03): 8 aguas apex->beiral, SEM caixa inclinada.
	# Caixa_livre com espessura no perfil lia V/borboleta (aresta fina = vale).
	var y_beiral := y_piso + alt_pilar + 0.08
	var eave_r := raio * 1.28
	var roof_h := 3.25
	# Beiral + forro: volume sob a agua, fora da silhueta /\ .
	KitModular.caixa_cor(sup, &"teto", centro + Vector3(0.0, y_beiral + 0.02, 0.0),
		Vector3(eave_r * 2.12, 0.14, eave_r * 2.12), telha_escura, PI / 8.0,
		PSXMesh.FACE_TODAS, 1.35)
	KitModular.caixa_cor(sup, &"tabua", centro + Vector3(0.0, y_beiral - 0.08, 0.0),
		Vector3(raio * 1.7, 0.1, raio * 1.7), madeira, PI / 8.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Caibros aparentes sob a agua (ref 03: o coreto e visto POR BAIXO, de perto,
	# e sem eles o beiral e uma tampa lisa boiando sobre os pilares).
	for i in 16:
		var ang_c := TAU * float(i) / 16.0 + PI / 16.0
		var fora := Vector3(cos(ang_c), 0.0, sin(ang_c))
		KitModular.caixa_cor(sup, &"tabua",
			centro + fora * (eave_r * 0.62) + Vector3(0.0, y_beiral - 0.16, 0.0),
			Vector3(0.08, 0.1, eave_r * 1.2), madeira.lerp(Color("2e2418"), 0.35),
			ang_c + PI * 0.5, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	telhado_piramide(sup, &"teto",
		centro + Vector3(0.0, y_beiral, 0.0), eave_r, roof_h, 8, PI / 8.0,
		telha, telha_escura)
	# Pico curto — fecha a ponta sem engolir as aguas.
	KitModular.caixa_cor(sup, &"teto",
		centro + Vector3(0.0, y_beiral + roof_h - 0.05, 0.0),
		Vector3(0.35, 0.4, 0.35), telha, PI / 8.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Lanterna sob o teto (ref 03 — ponto amarelo no centro).
	KitModular.caixa_cor(sup, &"metal",
		centro + Vector3(0.0, y_beiral + 0.45, 0.0),
		Vector3(0.14, 0.22, 0.14), Color("e8c040"), 0.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	colisao.append({"tamanho": Vector3(raio * 2.1, y_piso + 0.2, raio * 2.1),
		"pos": centro + Vector3(0.0, y_piso * 0.5, 0.0)})


## Igreja colonial da Praca da Matriz: nave branca manchada, frontao triangular
## com oculo, telhado de duas aguas em telha, sineira a esquerda e sacristia
## baixa a direita.
##
## Historico das versoes que nao funcionaram, para nao voltarem:
##
## 1. Portal freestanding +1,4 m a frente da nave, cruz no ar e rim
##    `janela_acesa` na ombreira. Na nevoa densa lia como retangulo luminoso
##    ("construcao na frente"), nao como capela.
## 2. Frontao em degraus — tres caixas empilhadas — e telhado de caixa chapada.
##    Lia como zigurate: a silhueta que chega a 480x270 e a do contorno, e um
##    contorno em escada nao e um contorno triangular. O telhado, visto de cima,
##    era um retangulo marrom sem caimento nenhum.
##
## Aqui o frontao e UM triangulo e o telhado tem duas aguas de verdade, com o
## mesmo `PICO` nos dois: a aresta inclinada e funcao so da posicao, entao as
## duas superficies concordam sobre onde ela passa e nao abre fenda entre elas.
static func igreja_matriz(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float = 0.0) -> void:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	# Branco colonial com mancha quente; quoin de tijolo legivel, nao preto puro
	# (preto some no wash do fog=denso). Porta verde-escura como a ref 02.
	var reboco := Color("fff6e6")
	var reboco_claro := Color("fff8ea")
	var mancha := Color("8a7355")
	var quoin_a := Color("5c4030")
	var quoin_b := Color("3e2c20")
	var telha := TELHA_CLARA
	var telha_sombra := TELHA_ESCURA
	var porta := Color("0c100c")
	var marco := Color("3a342c")
	var trim := Color("2a241c")
	var largura := 12.4
	var fundura := 12.0
	var parede_h := 7.0
	# Caimento do telhado e altura do frontao. Sao o MESMO numero de proposito:
	# o triangulo do frontao e a ponta da agua tem de descrever a mesma reta.
	# 2,2 e o teto, nao um gosto. A camera travada do pin ve ate ~10,25 m no
	# plano da fachada; com plinto 0,55 e parede 7,0 sobra isso para o
	# frontao mais a cruz. Frontao colonial e raso mesmo — os das refs 01 e
	# 02 nao passam de vinte graus.
	var pico := 2.2
	var beiral := 0.55
	# Plinto baixo: eleva a soleira sem inventar uma plataforma luminosa.
	const PLINTO := 0.55
	KitModular.caixa_cor(sup, &"concreto_sujo",
		centro + Vector3(0.0, PLINTO * 0.5, 0.0),
		Vector3(largura + 0.8, PLINTO, fundura + 0.8), Color("7a766c"), giro,
		PSXMesh.FACE_TODAS, 2.0)
	# Tres degraus curtos no eixo da porta — mesma linguagem do coreto, sem
	# portal solto na frente.
	var pedra_degrau := Color("b0aca2")
	var pedra_espelho := Color("7a766c")
	var n_degraus := 4
	var larg_escada := 3.6
	var h_deg := PLINTO / float(n_degraus)
	var prof := 0.38
	var soleira_afast := fundura * 0.5 + 0.08
	for degrau in n_degraus:
		var t := float(degrau)
		var y_topo := (t + 1.0) * h_deg
		var afast := soleira_afast + 0.1 + (float(n_degraus - 1) - t) * (prof * 0.95)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + frente * (afast - prof * 0.15) + Vector3(0.0, y_topo - h_deg * 0.5, 0.0),
			Vector3(larg_escada - t * 0.04, h_deg, 0.1), pedra_espelho, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + frente * afast + Vector3(0.0, y_topo - 0.04, 0.0),
			Vector3(larg_escada - t * 0.04, 0.08, prof), pedra_degrau, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	var escada_corrida := float(n_degraus) * prof * 0.95 + 0.15
	var escada_meio := soleira_afast + 0.1 + escada_corrida * 0.5
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + lado * (larg_escada * 0.5 + 0.1) * sx
				+ frente * escada_meio + Vector3(0.0, PLINTO * 0.42, 0.0),
			Vector3(0.18, PLINTO * 0.84, escada_corrida), Color("9a968c"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	var ang_esc := atan2(PLINTO, escada_corrida)
	var hip_esc := sqrt(PLINTO * PLINTO + escada_corrida * escada_corrida)
	colisao.append({
		"tamanho": Vector3(larg_escada + 0.2, 0.22, hip_esc),
		"pos": centro + frente * escada_meio + Vector3(0.0, PLINTO * 0.5, 0.0),
		"giro": Vector3(ang_esc * cos(giro), giro, -ang_esc * sin(giro)),
	})
	KitModular.solido(colisao, centro + Vector3(0.0, PLINTO * 0.5, 0.0),
		Vector3(largura + 0.8, PLINTO, fundura + 0.8), giro)
	centro += Vector3(0.0, PLINTO, 0.0)

	# Nave — volume branco que a nevoa ainda le como edificio.
	KitModular.caixa_cor(sup, &"reboco",
		centro + Vector3(0.0, parede_h * 0.5, 0.0),
		Vector3(largura, parede_h, fundura), reboco, giro,
		PSXMesh.FACE_TODAS, 2.5)
	# Saia de weathering na base da fachada (mancha ancora o volume).
	KitModular.caixa_cor(sup, &"tijolo",
		centro + frente * (fundura * 0.5 + 0.02) + Vector3(0.0, 0.45, 0.0),
		Vector3(largura * 0.98, 0.9, 0.16), mancha, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Placa frontal mais clara: no denso o volume reboco puro lava; esta face
	# empurrada da nave sobra como branco colonial sem emissivo.
	#
	# Ela e PARTIDA em tres — dois montantes e uma verga — e nao uma laje unica.
	# A laje unica passava por cima do vao da porta, e dai vinham os dois
	# defeitos reportados: a face dela e a face da folha da porta caiam no MESMO
	# plano (as duas em F+0,12, sendo F a face da nave), duas superficies
	# olhando para fora na mesma profundidade brigavam pelo pixel e a porta
	# PISCAVA; e quando a placa ganhava o teste, aparecia reboco claro no lugar
	# da porta, que le como ver ATRAVES dela.
	#
	# Partida, a placa vira a moldura do vao de verdade: a porta passa a ficar
	# num recuo, com o vao escuro visivel atras dela, e nenhuma face
	# compartilha profundidade com nenhuma outra. Ver a tabela de profundidades
	# no bloco da porta.
	const PLACA_E := 0.26
	var placa_y := parede_h * 0.52
	var placa_h := parede_h * 0.88
	var placa_meia := largura * 0.46
	var placa_z := fundura * 0.5 + PLACA_E * 0.5
	# Vao reservado para a porta. Os montantes param nele; a verga comeca
	# em cima dele. Todo mundo le a mesma borda a partir da MESMA conta, senao
	# os tres discordam sobre onde o vao esta e abre fresta.
	var vao_meia := 1.45
	var vao_topo := 4.0
	for sx: float in [-1.0, 1.0]:
		var mont := placa_meia - vao_meia
		KitModular.caixa_cor(sup, &"reboco",
			centro + frente * placa_z
				+ lado * ((vao_meia + placa_meia) * 0.5 * sx)
				+ Vector3(0.0, placa_y, 0.0),
			Vector3(mont, placa_h, PLACA_E), reboco_claro, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	var verga_base := maxf(vao_topo, placa_y - placa_h * 0.5)
	var verga_h := (placa_y + placa_h * 0.5) - verga_base
	if verga_h > 0.05:
		KitModular.caixa_cor(sup, &"reboco",
			centro + frente * placa_z
				+ Vector3(0.0, verga_base + verga_h * 0.5, 0.0),
			Vector3(vao_meia * 2.0, verga_h, PLACA_E), reboco_claro, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Reboco descascado: manchas de tijolo aparente na fachada e nas laterais.
	# E o que separa "igreja velha" de "igreja branca". Passou a usar o mesmo
	# `descascado` do casario — antes era um laço proprio que so punha UM
	# retangulo por mancha, e retangulo unico numa parede lisa le como cartaz.
	descascado(sup, centro + frente * (fundura * 0.5 + 0.05), lado, frente,
		largura, parede_h, giro, 17, 5, mancha)
	# As laterais da nave levam mais: e o lado que a chuva bate e ninguem cuida.
	for sx: float in [-1.0, 1.0]:
		descascado(sup, centro + lado * (largura * 0.5 + 0.05) * sx,
			frente, lado * sx, fundura, parede_h, giro + PI * 0.5,
			41 + int(sx) * 7, 4, mancha)
	# Quoins de tijolo nos cantos da fachada — bloco grosso, contraste quente.
	var n_quoin := 7
	for sx: float in [-1.0, 1.0]:
		for k in n_quoin:
			var yk := 0.35 + float(k) * (parede_h * 0.9 / float(n_quoin))
			var cor_q := quoin_a if (k % 2) == 0 else quoin_b
			var alt_q := parede_h * 0.9 / float(n_quoin) - 0.05
			KitModular.caixa_cor(sup, &"tijolo",
				centro + lado * (largura * 0.48 * sx) + frente * (fundura * 0.5 + 0.12)
					+ Vector3(0.0, yk, 0.0),
				Vector3(0.85, alt_q, 0.55), cor_q, giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Cornija: a faixa clara que separa parede de telhado, dando a volta. E ela
	# que desenha a linha horizontal do beiral contra o ceu preto.
	KitModular.caixa_cor(sup, &"reboco",
		centro + Vector3(0.0, parede_h - 0.16, 0.0),
		Vector3(largura + 0.34, 0.34, fundura + 0.34), reboco_claro, giro,
		PSXMesh.FACE_TODAS, 2.0)

	# --- telhado de duas aguas, cumeeira no eixo da nave ---------------------
	# A cumeeira corre da fachada para o fundo, entao a ponta que olha a praca e
	# o frontao. Beiral de ponta ZERO: a telha para no plano da fachada e quem
	# sobe acima dela e a alvenaria do frontao.
	var y_beiral := parede_h
	telhado_duas_aguas(sup, centro + Vector3(0.0, y_beiral, 0.0),
		largura, fundura, pico, giro, telha, telha_sombra, beiral,
		&"teto", 0.0)
	var hx := largura * 0.5 + beiral
	# Frontao: UM triangulo, na largura exata da agua, para dividirem a aresta.
	oitao(sup, &"reboco", centro + frente * (fundura * 0.5) + Vector3(0.0, y_beiral, 0.0),
		hx * 2.0, pico, giro, reboco_claro)
	oitao(sup, &"reboco", centro - frente * (fundura * 0.5) + Vector3(0.0, y_beiral, 0.0),
		hx * 2.0, pico, giro + PI, reboco)
	# Cornija rampante: as duas tabuas claras que acompanham o frontao. Alem de
	# serem o remate colonial das refs, cobrem a costura entre o triangulo de
	# alvenaria e a ponta da telha.
	var comp_rampa := sqrt(hx * hx + pico * pico)
	for sx: float in [-1.0, 1.0]:
		var ang := atan2(pico, -hx * sx)
		var base_ramp := Basis(Vector3.UP, giro) * Basis(Vector3(0.0, 0.0, 1.0), ang)
		KitModular.caixa_livre(sup, &"reboco",
			centro + frente * (fundura * 0.5 + 0.1)
				+ lado * (hx * 0.5 * sx) + Vector3(0.0, y_beiral + pico * 0.5, 0.0),
			Vector3(comp_rampa, 0.26, 0.2), base_ramp, reboco_claro, 1.2)
	# Oculo no frontao (ref 02): moldura clara + vao preto, na altura em que o
	# triangulo ainda e largo o bastante para os dois caberem.
	var oculo := centro + frente * (fundura * 0.5 + 0.12) + Vector3(0.0, y_beiral + 0.78, 0.0)
	KitModular.caixa_cor(sup, &"reboco", oculo,
		Vector3(1.16, 1.16, 0.08), reboco_claro, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"reboco", oculo, Vector3(0.82, 0.82, 0.1),
		reboco_claro, giro + PI * 0.25, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"janela_apagada", oculo + frente * 0.06,
		Vector3(0.62, 0.62, 0.06), Color("08090a"), giro + PI * 0.25,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Cruz no pico do frontao — pequena, no plano da parede, nunca no ar.
	# Cruz do frontao, TORTA. Sete graus e pouco para gritar e o bastante
	# para o olho reclamar: numa fachada onde tudo o mais e prumo e nivel,
	# a unica coisa fora de esquadro e a cruz. Nao inventa nada de enredo,
	# so recusa a leitura de "igreja em ordem".
	const CRUZ_TORTA := 0.12
	var cruz_alt := y_beiral + pico + 0.34
	var cruz_c := centro + frente * (fundura * 0.5) + Vector3(0.0, cruz_alt, 0.0)
	var cruz_b := Basis(Vector3.UP, giro) * Basis(Vector3(0.0, 0.0, 1.0), CRUZ_TORTA)
	KitModular.caixa_livre(sup, &"metal", cruz_c,
		Vector3(0.2, 0.9, 0.2), cruz_b, Color("2a2218"), QUAD_FOLHA)
	KitModular.caixa_livre(sup, &"metal",
		cruz_c + cruz_b * Vector3(0.0, 0.16, 0.0),
		Vector3(0.8, 0.2, 0.2), cruz_b, Color("2a2218"), QUAD_FOLHA)
	# Pinaculos nos ombros do frontao: os dois cubinhos que as igrejas coloniais
	# tem onde a rampa encontra a cornija. Quebram o V do encontro.
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"reboco",
			centro + frente * (fundura * 0.5) + lado * (hx * 0.94 * sx)
				+ Vector3(0.0, y_beiral + 0.3, 0.0),
			Vector3(0.44, 0.7, 0.44), reboco_claro, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# --- fachada: porta e janelas -------------------------------------------
	#
	# TABELA DE PROFUNDIDADES, medida a partir de F = face frontal da nave.
	# Nenhuma face olhando para fora pode dividir plano com outra; e por dividir
	# que a porta piscava.
	#
	#   vao preto        F+0,00 .. F+0,05
	#   folhas           F+0,05 .. F+0,19
	#   almofadas        F+0,19 .. F+0,24
	#   placa clara      F+0,00 .. F+0,26   (partida, com vao para a porta)
	#   marco de pedra   F+0,00 .. F+0,34   (unica peca que avanca da placa)
	#
	# A porta fica portanto RECUADA 7 cm atras da face da placa, dentro de um
	# marco que avanca 8 cm — que e como um portal de pedra se comporta, e o que
	# faz o vao ler como vao em vez de retangulo pintado.
	var porta_l := 2.9
	var porta_h := 4.0
	var porta_c := centro + frente * (fundura * 0.5 + 0.12) + Vector3(0.0, 2.0, 0.0)
	# Vao PRETO no fundo do portal. Antes ficava 45 cm ATRAS de `porta_c`, ou
	# seja enterrado dentro da nave, que e solida: nunca foi visto por ninguem e
	# a porta nao tinha profundidade nenhuma. Agora ele encosta na face da nave,
	# dentro do vao aberto na placa, e e o que aparece pela fresta da folha
	# entreaberta — com paralaxe de verdade quando o jogador anda de lado.
	KitModular.caixa_cor(sup, &"janela_apagada",
		porta_c - frente * 0.095, Vector3(porta_l, porta_h, 0.05),
		Color("050506"), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Porta dupla ENTREABERTA. A folha da direita gira para dentro sobre a
	# ombreira; a da esquerda fica fechada. Uma igreja aberta as onze e quinze da
	# noite nao precisa de legenda nenhuma para incomodar — e a porta simetrica
	# e chapada que estava aqui antes lia como fachada de maquete.
	var folha_l := porta_l * 0.5
	const ABERTURA := 0.42
	for sx: float in [-1.0, 1.0]:
		var giro_folha := giro + (ABERTURA if sx > 0.0 else 0.0)
		# Dobradica na ombreira: o centro da folha e o eixo mais meia folha
		# girada, senao a porta abre atravessando a propria parede.
		var eixo := porta_c + lado * (folha_l * sx)
		var giro_l := Vector3(cos(giro_folha), 0.0, -sin(giro_folha))
		var centro_folha := eixo - giro_l * (folha_l * 0.5 * sx)
		KitModular.caixa_cor(sup, &"porta", centro_folha,
			Vector3(folha_l, porta_h, 0.14), porta, giro_folha,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		# Almofadas: dois paineis rasos por folha, so para a porta nao ser um
		# retangulo preto liso quando a lanterna bate nela de perto.
		var frente_folha := Vector3(sin(giro_folha), 0.0, cos(giro_folha))
		for py: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"porta",
				centro_folha + frente_folha * 0.09 + Vector3(0.0, 0.95 * py, 0.0),
				Vector3(folha_l * 0.66, 1.5, 0.05),
				porta.lerp(Color("2a2e26"), 0.6), giro_folha,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"metal",
			centro_folha + frente_folha * 0.11
				- giro_l * (folha_l * 0.36 * sx) + Vector3(0.0, -0.1, 0.0),
			Vector3(0.12, 0.12, 0.12), Color("6b5a3a"), giro_folha,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Marco de pedra (ombreira). Centro em F+0,17 com 0,34 de espessura: encosta
	# na face da nave e avanca 8 cm alem da placa, entao e a unica peca do
	# portal que sobressai — e por isso a que desenha a sombra do vao.
	var marco_z := frente * 0.05
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"tijolo",
			porta_c + marco_z + lado * (porta_l * 0.5 + 0.2) * sx,
			Vector3(0.38, porta_h + 0.3, 0.34), marco, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"tijolo",
		porta_c + marco_z + Vector3(0.0, porta_h * 0.5 + 0.14, 0.0),
		Vector3(porta_l + 0.78, 0.36, 0.34), marco, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Arco em degraus sobre a porta. O recuo de cada degrau sai de `frente`, e
	# nao de um `Vector3(0, y, 0.02)` como estava: aquele 0,02 era um passo no Z
	# do MUNDO, que so calha de ser a profundidade da fachada enquanto `giro`
	# for zero. Uma igreja girada empurraria os degraus para o lado.
	KitModular.caixa_cor(sup, &"tijolo",
		porta_c + marco_z - frente * 0.02 + Vector3(0.0, porta_h * 0.5 + 0.46, 0.0),
		Vector3(porta_l * 0.82, 0.32, 0.3), marco, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"tijolo",
		porta_c + marco_z - frente * 0.05 + Vector3(0.0, porta_h * 0.5 + 0.74, 0.0),
		Vector3(porta_l * 0.52, 0.24, 0.26), marco, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Duas janelas altas na fachada, com moldura clara e peitoril. A moldura
	# clara e obrigatoria: a versao anterior punha so o vao escuro num reboco ja
	# manchado e as duas janelas liam como duas cunhas pretas sem explicacao.
	for sx: float in [-1.0, 1.0]:
		var jan := centro + frente * (fundura * 0.5 + 0.05) + lado * (4.05 * sx) \
			+ Vector3(0.0, 5.15, 0.0)
		KitModular.caixa_cor(sup, &"reboco", jan,
			Vector3(1.62, 2.0, 0.1), reboco_claro, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"janela_apagada", jan + frente * 0.05,
			Vector3(1.2, 1.6, 0.08), Color("0a0a0a"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"janela_apagada", jan + frente * 0.08,
			Vector3(0.07, 1.52, 0.06), Color("241c14"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"tijolo",
			jan + Vector3(0.0, 1.02, 0.02), Vector3(1.72, 0.24, 0.2), marco, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			jan + frente * 0.1 + Vector3(0.0, -1.06, 0.0),
			Vector3(1.8, 0.16, 0.28), Color("b2ae9e"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# --- sacristia: volume baixo colado a direita ---------------------------
	# Sem ela a igreja e um prisma simetrico, e prisma simetrico le como caixa.
	# O anexo mais baixo de um lado so e o que da escala a nave nas refs 01 e 04.
	var sac_l := 5.0
	var sac_f := 7.4
	var sac_h := 4.0
	var sac := centro + lado * (largura * 0.5 + sac_l * 0.5 - 0.3) - frente * 1.5
	KitModular.caixa_cor(sup, &"reboco", sac + Vector3(0.0, sac_h * 0.5, 0.0),
		Vector3(sac_l, sac_h, sac_f), reboco, giro, PSXMesh.FACE_TODAS, 2.5)
	KitModular.caixa_cor(sup, &"tijolo",
		sac + frente * (sac_f * 0.5 + 0.02) + Vector3(0.0, 0.4, 0.0),
		Vector3(sac_l * 0.98, 0.8, 0.12), mancha, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"reboco",
		sac + Vector3(0.0, sac_h - 0.14, 0.0),
		Vector3(sac_l + 0.26, 0.28, sac_f + 0.26), reboco_claro, giro,
		PSXMesh.FACE_TODAS, 2.0)
	telhado_duas_aguas(sup, sac + Vector3(0.0, sac_h, 0.0),
		sac_l, sac_f, 1.15, giro, telha, telha_sombra, 0.42)
	for sz: float in [-1.0, 1.0]:
		oitao(sup, &"reboco",
			sac + frente * ((sac_f * 0.5) * sz) + Vector3(0.0, sac_h, 0.0),
			sac_l + 0.84, 1.15, giro + (0.0 if sz > 0.0 else PI), reboco_claro)
	KitModular.caixa_cor(sup, &"janela_apagada",
		sac + frente * (sac_f * 0.5 + 0.04) + Vector3(0.0, 1.75, 0.0),
		Vector3(0.9, 1.15, 0.08), Color("1a1a18"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.solido(colisao, sac + Vector3(0.0, sac_h * 0.5, 0.0),
		Vector3(sac_l, sac_h, sac_f), giro)

	# --- sineira a esquerda da fachada --------------------------------------
	var torre := centro + lado * -(largura * 0.48 + 1.15) - frente * 0.35
	# 15,5 m por 3,6 de lado da 4,3:1. A versao anterior era 17,5 por 2,7 —
	# 6,5:1 — e nessa proporcao a sineira nao le como sineira, le como
	# chamine: de longe e uma coluna cinza sem largura para o campanario
	# aparecer. Continua alta o bastante para espiar por cima da nevoa, que
	# e a razao de ela ser alta.
	var torre_h := 17.0
	var torre_l := 4.0
	KitModular.caixa_cor(sup, &"reboco", torre + Vector3(0.0, torre_h * 0.5, 0.0),
		Vector3(torre_l, torre_h, torre_l), reboco, giro, PSXMesh.FACE_TODAS, 2.5)
	# Face clara do lado da praca — ancora a silhueta no fog.
	KitModular.caixa_cor(sup, &"reboco",
		torre + frente * (torre_l * 0.5 + 0.04) + Vector3(0.0, torre_h * 0.48, 0.0),
		Vector3(torre_l * 0.86, torre_h * 0.9, 0.12), reboco_claro, giro,
		PSXMesh.FACE_TODAS, 2.5)
	# Quoins nos dois cantos da face da praca.
	for sx: float in [-1.0, 1.0]:
		for k in 9:
			var yk := 0.4 + float(k) * (torre_h * 0.82 / 9.0)
			KitModular.caixa_cor(sup, &"tijolo",
				torre + lado * (torre_l * 0.44 * sx) + frente * (torre_l * 0.5 + 0.08)
					+ Vector3(0.0, yk, 0.0),
				Vector3(0.42, torre_h * 0.82 / 9.0 - 0.08, 0.3),
				quoin_a if (k % 2) == 0 else quoin_b, giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Cordao a meia altura: sem ele a torre e um poste de 17 m sem escala.
	KitModular.caixa_cor(sup, &"reboco",
		torre + Vector3(0.0, torre_h * 0.52, 0.0),
		Vector3(torre_l + 0.3, 0.26, torre_l + 0.3), reboco_claro, giro,
		PSXMesh.FACE_TODAS, 2.0)

	# Campanario: vao em arco nas quatro faces, com sino dentro do que olha a
	# praca. O arco e feito em degraus, mesma linguagem do arco da porta.
	var y_sino := torre_h - 3.1
	for f in 4:
		var ang_f := giro + TAU * float(f) / 4.0
		var fora := Vector3(sin(ang_f), 0.0, cos(ang_f))
		var trans := Vector3(cos(ang_f), 0.0, -sin(ang_f))
		var _t := trans
		var boca := torre + fora * (torre_l * 0.5 + 0.03) + Vector3(0.0, y_sino, 0.0)
		KitModular.caixa_cor(sup, &"janela_apagada", boca,
			Vector3(1.75, 2.05, 0.1), Color("07080a"), ang_f,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"janela_apagada", boca + Vector3(0.0, 1.16, 0.0),
			Vector3(1.35, 0.32, 0.1), Color("07080a"), ang_f,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"janela_apagada", boca + Vector3(0.0, 1.44, 0.0),
			Vector3(0.78, 0.26, 0.1), Color("07080a"), ang_f,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		# Aduela clara em volta do vao: e o que faz o buraco ler como arco e nao
		# como borrao escuro na torre.
		for sx: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"reboco",
				boca + trans * (1.02 * sx) + Vector3(0.0, 0.1, 0.0),
				Vector3(0.34, 2.45, 0.16), reboco_claro, ang_f,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"reboco", boca + Vector3(0.0, 1.66, 0.0),
			Vector3(1.9, 0.3, 0.16), reboco_claro, ang_f,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"reboco", boca + Vector3(0.0, -1.18, 0.0),
			Vector3(2.1, 0.24, 0.22), reboco_claro, ang_f,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# O sino: massa escura pendurada no vao. Nao acende, nao toca — so tira o
	# retangulo preto de "vazio" e poe "tem um sino ali".
	KitModular.caixa_cor(sup, &"metal",
		torre + Vector3(0.0, y_sino + 0.55, 0.0), Vector3(1.4, 0.12, 1.4),
		Color("2b2620"), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal",
		torre + Vector3(0.0, y_sino + 0.05, 0.0), Vector3(0.68, 0.82, 0.68),
		Color("4a3b22"), giro + PI * 0.25, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal",
		torre + Vector3(0.0, y_sino - 0.42, 0.0), Vector3(0.86, 0.14, 0.86),
		Color("3a2e1a"), giro + PI * 0.25, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Cornija do campanario e piramide de telha de verdade. A versao anterior
	# empilhava tres caixas cada vez menores: de perto lia como bolo, e de longe
	# — que e como a torre e vista, espiando por cima da nevoa — lia como borrao.
	KitModular.caixa_cor(sup, &"reboco",
		torre + Vector3(0.0, torre_h - 0.22, 0.0),
		Vector3(torre_l + 0.6, 0.44, torre_l + 0.6), reboco_claro, giro,
		PSXMesh.FACE_TODAS, 2.0)
	telhado_piramide(sup, &"teto", torre + Vector3(0.0, torre_h, 0.0),
		(torre_l + 0.6) * 0.72, 2.3, 4, giro + PI * 0.25, telha, telha_sombra)
	KitModular.caixa_cor(sup, &"metal",
		torre + Vector3(0.0, torre_h + 2.6, 0.0), Vector3(0.12, 0.8, 0.12),
		trim, giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal",
		torre + Vector3(0.0, torre_h + 2.8, 0.0), Vector3(0.52, 0.12, 0.12),
		trim, giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	colisao.append({"tamanho": Vector3(largura + 0.4, parede_h, fundura + 0.4),
		"pos": centro + Vector3(0.0, parede_h * 0.5, 0.0)})
	colisao.append({"tamanho": Vector3(torre_l + 0.4, torre_h, torre_l + 0.4),
		"pos": torre + Vector3(0.0, torre_h * 0.5, 0.0)})


## Adro: o muro baixo que cerca o terreiro da igreja, com portao no eixo.
##
## Toda matriz colonial tem um. Aqui ele entra por tres razoes, nessa ordem:
##
## 1. O take da revelacao (`praca_5` na decupagem) nao tinha NADA entre a lente
##    e a fachada — camera, vinte metros de pedra vazia, igreja. Um muro de 90 cm
##    atravessando o terco inferior do quadro poe uma camada intermediaria e a
##    igreja passa a estar ATRAS de alguma coisa, que e o comeco de estar longe.
## 2. Separa o chao da igreja do chao da praca. Sem ele o edificio esta pousado
##    no mesmo calcamento por onde o jogador anda, e nada diz onde um acaba.
## 3. Portao aberto num muro fechado e uma decisao: o jogo esta convidando a
##    entrar. Isso vale mais que qualquer legenda.
##
## `meia_abertura` e metade do vao do portao, no eixo da porta da igreja.
static func adro(sup: Dictionary, colisao: Array[Dictionary], centro: Vector3,
		largura: float, giro: float, meia_abertura: float = 1.7) -> void:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var _f := frente
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	var pedra := Color("6f6b61")
	var pedra_topo := Color("8d887c")
	const ALTURA := 0.92
	const ESPESSURA := 0.42

	# Os dois trechos, um de cada lado do portao. Comprimento so em funcao da
	# posicao — se cada trecho calculasse a propria borda por outro caminho, os
	# dois discordariam sobre onde o vao comeca e abriria fresta no portao.
	var meia := largura * 0.5
	for sx: float in [-1.0, 1.0]:
		var comp := meia - meia_abertura
		if comp <= 0.2:
			continue
		var meio_x := (meia_abertura + meia) * 0.5 * sx
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + lado * meio_x + Vector3(0.0, ALTURA * 0.5, 0.0),
			Vector3(comp, ALTURA, ESPESSURA), pedra, giro,
			PSXMesh.FACE_TODAS, 2.0)
		# Rincheira: a pedra clara de acabamento no topo do muro. E ela que
		# desenha a linha horizontal do adro contra o calcamento escuro; sem ela
		# o muro some no chao e vira um degrau sem explicacao.
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + lado * meio_x + Vector3(0.0, ALTURA + 0.05, 0.0),
			Vector3(comp, 0.14, ESPESSURA + 0.16), pedra_topo, giro,
			PSXMesh.FACE_TODAS, 2.0)
		KitModular.solido(colisao,
			centro + lado * meio_x + Vector3(0.0, ALTURA * 0.5, 0.0),
			Vector3(comp, ALTURA, ESPESSURA), giro)

	# Pilares do portao, mais altos que o muro, com pinaculo. Sao o unico
	# elemento vertical do adro e e por eles que o olho acha o eixo da porta.
	for sx: float in [-1.0, 1.0]:
		var p := centro + lado * (meia_abertura * sx)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			p + Vector3(0.0, 0.78, 0.0), Vector3(0.62, 1.56, 0.62), pedra, giro,
			PSXMesh.FACE_TODAS, 2.0)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			p + Vector3(0.0, 1.62, 0.0), Vector3(0.78, 0.16, 0.78), pedra_topo,
			giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			p + Vector3(0.0, 1.84, 0.0), Vector3(0.34, 0.34, 0.34), pedra_topo,
			giro + PI * 0.25, PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.solido(colisao, p + Vector3(0.0, 0.78, 0.0),
			Vector3(0.62, 1.56, 0.62), giro)


## Cruz de pedra fincada, levemente fora de prumo. Peca de adro.
##
## Tres ou quatro delas de lado, nunca em fileira e nunca no eixo: fileira le
## como cemiterio, e cemiterio e outra cena. Tortas porque pedra fincada em
## terra batida ha cem anos nao fica reta, e porque o olho estranha antes de
## saber por que.
static func cruz_de_pedra(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, altura: float, giro: float, tombo: float) -> void:
	var pedra := Color("5e5a51")
	var eixo := Basis(Vector3.UP, giro) * Basis(Vector3(0.0, 0.0, 1.0), tombo)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		base + Vector3(0.0, 0.12, 0.0), Vector3(0.5, 0.24, 0.5),
		pedra.lerp(Color("3f3d36"), 0.4), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_livre(sup, &"concreto_sujo",
		base + eixo * Vector3(0.0, altura * 0.5 + 0.2, 0.0),
		Vector3(0.16, altura, 0.16), eixo, pedra, QUAD_FOLHA)
	KitModular.caixa_livre(sup, &"concreto_sujo",
		base + eixo * Vector3(0.0, altura * 0.78 + 0.2, 0.0),
		Vector3(0.62, 0.16, 0.16), eixo, pedra, QUAD_FOLHA)
	colisao.append({"tamanho": Vector3(0.5, altura, 0.5),
		"pos": base + Vector3(0.0, altura * 0.5, 0.0)})


## Campo santo: o cemiterio murado atras da matriz.
##
## Nasceu de uma observacao que eu tinha deixado passar. Eu vinha ajustando a
## praca pelo quadro da cutscene, que olha a igreja de frente; mas a praca e
## espaco que o jogador ANDA, e a planta de cima mostrava o que a cutscene nunca
## enquadra — de calcamento nu, do fundo da igreja ate a rua, um vazio maior que
## a praca inteira. Cenario que so funciona de um angulo nao e cenario, e
## decoracao de palco.
##
## Cemiterio atras da igreja e a disposicao colonial correta (o campo santo da
## matriz), resolve o vazio com o assunto que a cena ja tem, e nao inventa
## enredo nenhum: uma igreja de 1800 tem mortos no quintal.
##
## Tres coisas sustentam a leitura a 480x270:
##   - o MURO, que fecha a silhueta e diz "outro recinto";
##   - as CRUZES em fileira torta, que sao verticais repetidas — o olho conta
##     antes de identificar;
##   - os tumulos de caixa, massas grandes que sobrevivem a minificacao quando
##     as cruzes ja viraram risco.
static func campo_santo(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, tamanho: Vector2, giro: float, semente: int) -> void:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	var pedra := Color("6a665c")
	var pedra_topo := Color("878175")
	const MURO_H := 1.45
	const MURO_E := 0.4
	var hx := tamanho.x * 0.5
	var hz := tamanho.y * 0.5
	# Portao no meio do lado que olha a igreja (frente).
	const MEIA_PORTA := 1.5

	for sz: float in [-1.0, 1.0]:
		# O lado da frente e o unico partido; o de tras e corrido.
		if sz > 0.0:
			for sx: float in [-1.0, 1.0]:
				var comp := hx - MEIA_PORTA
				if comp <= 0.2:
					continue
				KitModular.caixa_cor(sup, &"concreto_sujo",
					centro + frente * (hz * sz)
						+ lado * ((MEIA_PORTA + hx) * 0.5 * sx)
						+ Vector3(0.0, MURO_H * 0.5, 0.0),
					Vector3(comp, MURO_H, MURO_E), pedra, giro,
					PSXMesh.FACE_TODAS, 2.0)
				KitModular.caixa_cor(sup, &"concreto_sujo",
					centro + frente * (hz * sz)
						+ lado * ((MEIA_PORTA + hx) * 0.5 * sx)
						+ Vector3(0.0, MURO_H + 0.06, 0.0),
					Vector3(comp, 0.14, MURO_E + 0.14), pedra_topo, giro,
					PSXMesh.FACE_TODAS, 2.0)
		else:
			KitModular.caixa_cor(sup, &"concreto_sujo",
				centro + frente * (hz * sz) + Vector3(0.0, MURO_H * 0.5, 0.0),
				Vector3(tamanho.x, MURO_H, MURO_E), pedra, giro,
				PSXMesh.FACE_TODAS, 2.0)
			KitModular.caixa_cor(sup, &"concreto_sujo",
				centro + frente * (hz * sz) + Vector3(0.0, MURO_H + 0.06, 0.0),
				Vector3(tamanho.x, 0.14, MURO_E + 0.14), pedra_topo, giro,
				PSXMesh.FACE_TODAS, 2.0)
		KitModular.solido(colisao, centro + frente * (hz * sz)
			+ Vector3(0.0, MURO_H * 0.5, 0.0),
			Vector3(tamanho.x, MURO_H, MURO_E), giro)
	# Laterais corridas.
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + lado * (hx * sx) + Vector3(0.0, MURO_H * 0.5, 0.0),
			Vector3(MURO_E, MURO_H, tamanho.y), pedra, giro,
			PSXMesh.FACE_TODAS, 2.0)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + lado * (hx * sx) + Vector3(0.0, MURO_H + 0.06, 0.0),
			Vector3(MURO_E + 0.14, 0.14, tamanho.y), pedra_topo, giro,
			PSXMesh.FACE_TODAS, 2.0)
		KitModular.solido(colisao, centro + lado * (hx * sx)
			+ Vector3(0.0, MURO_H * 0.5, 0.0),
			Vector3(MURO_E, MURO_H, tamanho.y), giro)
	# Pilares do portao.
	for sx: float in [-1.0, 1.0]:
		var p := centro + frente * hz + lado * (MEIA_PORTA * sx)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			p + Vector3(0.0, 1.0, 0.0), Vector3(0.6, 2.0, 0.6), pedra, giro,
			PSXMesh.FACE_TODAS, 2.0)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			p + Vector3(0.0, 2.1, 0.0), Vector3(0.74, 0.16, 0.74), pedra_topo,
			giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.solido(colisao, p + Vector3(0.0, 1.0, 0.0),
			Vector3(0.6, 2.0, 0.6), giro)

	# Cruzeiro: a cruz grande do meio, que todo campo santo tem. E o unico
	# elemento alto la dentro, e por isso e ele que aparece por cima do muro
	# quando o jogador ainda esta longe.
	cruz_de_pedra(sup, colisao, centro + frente * (hz * 0.15),
		2.5, giro + 0.1, 0.03)

	# Sepulturas em fileira torta. A grade e regular, o conteudo nao: cada celula
	# sorteia entre cruz, tumulo de caixa e nada. Fileira perfeitamente cheia le
	# como grade de cenario; buraco na fileira le como lugar que foi usado.
	var nx := maxi(2, int(tamanho.x / 2.6))
	var nz := maxi(2, int(tamanho.y / 2.8))
	for j in nz:
		for i in nx:
			var chave := semente + j * 97 + i * 31
			var t := _tom(chave, 13)
			if t < 0.24:
				continue
			var fx := (float(i) + 0.5) / float(nx) - 0.5
			var fz := (float(j) + 0.5) / float(nz) - 0.5
			# Folga de 1,6 m no muro e 2,4 m na boca do portao.
			if absf(fx) * tamanho.x > hx - 1.6 or absf(fz) * tamanho.y > hz - 1.6:
				continue
			if fz > 0.22 and absf(fx) * tamanho.x < 2.4:
				continue
			var p := centro + lado * (fx * tamanho.x + lerpf(-0.4, 0.4, _tom(chave, 17))) \
				+ frente * (fz * tamanho.y + lerpf(-0.35, 0.35, _tom(chave, 19)))
			if t < 0.62:
				cruz_de_pedra(sup, colisao, p,
					lerpf(0.7, 1.15, _tom(chave, 23)),
					giro + lerpf(-0.5, 0.5, _tom(chave, 29)),
					lerpf(-0.16, 0.16, _tom(chave, 31)))
			else:
				# Tumulo de caixa: massa grande, que e o que sobra da leitura
				# quando a cruz ja virou um risco de um pixel.
				var giro_t := giro + lerpf(-0.3, 0.3, _tom(chave, 37))
				KitModular.caixa_cor(sup, &"concreto_sujo",
					p + Vector3(0.0, 0.24, 0.0),
					Vector3(1.05, 0.48, 2.0),
					pedra.lerp(Color("4b4841"), _tom(chave, 41)), giro_t,
					PSXMesh.FACE_TODAS, 2.0)
				KitModular.caixa_cor(sup, &"concreto_sujo",
					p + Vector3(0.0, 0.52, 0.0),
					Vector3(1.18, 0.1, 2.12), pedra_topo, giro_t,
					PSXMesh.FACE_TODAS, 2.0)
				KitModular.solido(colisao, p + Vector3(0.0, 0.26, 0.0),
					Vector3(1.05, 0.52, 2.0), giro_t)


## Poste de praca estilo lanterna: mastro preto fino e cabeca quadrada acesa.
## Devolve o ponto da luz (centro da lanterna).
##
## `aceso` falso troca o vidro por `janela_apagada` escuro. Um poste declarado
## morto no prop de luz mas com o globo ainda em `janela_acesa` seria pior que o
## defeito que ele existe para criar: o anel de luz teria um buraco no chao e
## uma lanterna brilhando por cima dele.
static func poste_lanterna(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, aceso: bool = true) -> Vector3:
	const ALTURA := 4.2
	var ferro := Color("1c1c1c")
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.18, 0.0),
		Vector3(0.38, 0.36, 0.38), ferro, 0.0, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, ALTURA * 0.5, 0.0),
		Vector3(0.11, ALTURA, 0.11), ferro, 0.0, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, ALTURA - 0.15, 0.0),
		Vector3(0.28, 0.08, 0.28), ferro, 0.0, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	var lanterna := base + Vector3(0.0, ALTURA + 0.28, 0.0)
	KitModular.caixa_cor(sup, &"metal", lanterna + Vector3(0.0, 0.22, 0.0),
		Vector3(0.42, 0.08, 0.42), ferro, 0.0, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	if aceso:
		KitModular.caixa(sup, &"janela_acesa", lanterna,
			Vector3(0.36, 0.42, 0.36), 0.0, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	else:
		KitModular.caixa_cor(sup, &"janela_apagada", lanterna,
			Vector3(0.36, 0.42, 0.36), Color("14161a"), 0.0,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal", lanterna + Vector3(0.0, 0.38, 0.0),
		Vector3(0.48, 0.1, 0.48), ferro, PI * 0.25, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	colisao.append({"tamanho": Vector3(0.4, ALTURA, 0.4),
		"pos": base + Vector3(0.0, ALTURA * 0.5, 0.0)})
	return lanterna


## Fundura e pe-direito do casario colonial. Uma agua so para todo o perimetro:
## as casas da praca sao um conjunto, e altura de beiral variando de modulo para
## modulo destroi a linha continua que as refs 01 e 02 mostram.
const CASA_FUNDURA := 5.6
const CASA_PE_DIREITO := 3.5
const CASA_PICO := 1.55
const CASA_BEIRAL := 0.55

## Caiacao do casario. Nenhuma e branca pura: no fog denso o branco puro lava e
## a fileira inteira vira um bloco leitoso sem junta entre as casas.
const CAIACOES: Array[Color] = [
	Color("f3ead6"), Color("e9dfc8"), Color("f6efdd"), Color("e2d8c0"),
	Color("efe4cc"), Color("e6dcc6"),
]

## Esquadria colonial: azul desbotado, verde-garrafa, marrom queimado. Sao as
## unicas cores saturadas do casario, e por isso sao elas que dizem onde e a
## porta a doze metros de distancia.
const ESQUADRIAS: Array[Color] = [
	Color("2b3a4a"), Color("24352c"), Color("3a2a20"), Color("2e3f52"),
	Color("2a2f24"),
]


## Reboco descascado: manchas de tijolo aparente numa parede caiada.
##
## `plano` e o ponto no PLANO DA PAREDE, `direita` e `frente` os eixos dela.
## Tudo em metros, tudo grande: a 480x270 uma mancha de 30 cm nao chega a tres
## pixels e vira o mesmo chiado do dither. Meio metro e o piso do que sobrevive,
## e por isso as faixas comecam em 0,55.
##
## Duas camadas de proposito. A mancha sozinha le como adesivo colado na parede;
## com uma borda um tom acima em volta, le como reboco que caiu e deixou a
## argamassa aparecendo na beirada — que e o que a ref 02 mostra na igreja.
static func descascado(sup: Dictionary, plano: Vector3, direita: Vector3,
		frente: Vector3, largura: float, altura: float, giro: float,
		semente: int, quantas: int, tijolo: Color,
		borda: Color = Color("8a7355")) -> void:
	for k in quantas:
		var w := lerpf(0.55, 1.35, _tom(semente + k * 53, 17))
		var hh := lerpf(0.4, 0.9, _tom(semente + k * 89, 19))
		# O CLAMP nao e zelo, e conserto. Antes o sorteio ia ate 0,42 da
		# largura e 0,86 da altura, contando que quem chamasse passasse a
		# extensao certa da parede. Na captura apareceram manchas soltas no
		# ar, uma metade dentro e metade fora de uma empena: quem chama erra,
		# e o jeito de nao errar e a funcao nao aceitar o erro. Aqui a mancha
		# inteira — os dois blocos e a borda — cabe dentro de `largura` x
		# `altura` por construcao, e nenhum chamador consegue empurra-la para
		# fora da parede.
		var meia_w := w * 0.5 + 0.12
		var lim_x := maxf(0.0, largura * 0.5 - meia_w)
		var topo := maxf(0.7, altura - hh * 1.5 - 0.2)
		var fx := lerpf(-lim_x, lim_x, _tom(semente + k * 131, 7))
		var fy := lerpf(0.55, topo, _tom(semente + k * 197, 11))
		var p := plano + direita * fx + Vector3(0.0, fy, 0.0)
		var cor_t := tijolo.lerp(Color("3e2c20"), _tom(semente + k, 23))
		# Dois blocos deslocados, e nao um. Um retangulo unico le como CARTAZ
		# colado na parede — foi exatamente assim que a primeira versao saiu na
		# captura. Dois em L quebram a silhueta, e e a silhueta que diz se
		# aquilo e reboco que caiu ou papel que alguem pregou.
		var w2 := w * lerpf(0.45, 0.75, _tom(semente + k * 71, 29))
		var h2 := hh * lerpf(0.5, 0.85, _tom(semente + k * 97, 31))
		var dx := (w - w2) * 0.5 * (1.0 if (k % 2) == 0 else -1.0)
		var dy := (hh + h2) * 0.5 * 0.82
		KitModular.caixa_cor(sup, &"reboco", p + frente * 0.02,
			Vector3(w + 0.16, hh + 0.14, 0.05), borda, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"reboco",
			p + direita * dx + Vector3(0.0, dy, 0.0) + frente * 0.02,
			Vector3(w2 + 0.14, h2 + 0.12, 0.05), borda, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"tijolo", p + frente * 0.05,
			Vector3(w, hh, 0.05), cor_t, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"tijolo",
			p + direita * dx + Vector3(0.0, dy, 0.0) + frente * 0.05,
			Vector3(w2, h2, 0.05), cor_t.lerp(Color("5c4030"), 0.35), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)


## Escorrido de agua: a lingua escura que desce de um peitoril ou de um vao.
##
## Numa fachada caiada e o desgaste mais barato que existe, e o que mais data o
## predio, porque so aparece onde a agua passa ha anos. Estreito e comprido:
## e a unica feicao fina que sobrevive a 480x270, porque o olho a le como
## direcao, nao como forma.
static func escorrido(sup: Dictionary, topo: Vector3, frente: Vector3,
		comprimento: float, largura: float, giro: float, cor: Color) -> void:
	KitModular.caixa_cor(sup, &"reboco",
		topo + frente * 0.03 + Vector3(0.0, -comprimento * 0.5, 0.0),
		Vector3(largura, comprimento, 0.05), cor, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)


## Duas tabuas cruzadas pregadas num vao. Grossas de proposito: a 480x270 uma
## ripa de 6 cm a doze metros nao chega a um pixel, e o X — que e a leitura
## inteira da peca — vira dois riscos de dither.
##
## E CLARAS, nao escuras. A primeira versao usava marrom de madeira velha, que e
## o que a madeira e, e o X sumia: tabua escura sobre vao escuro nao tem
## contraste com nada, e so aparecia nas pontas que passavam da moldura. Madeira
## crua pregada por fora pega a luz do lampiao e le como barra clara contra
## preto — que e como a coisa se ve de verdade, e como Silent Hill desenha.
static func _tabuas_cruzadas(sup: Dictionary, centro: Vector3, giro: float,
		largura: float, altura: float,
		cor: Color = Color("a08d6b")) -> void:
	var comp := sqrt(largura * largura + altura * altura) * 0.98
	for sx: float in [-1.0, 1.0]:
		var ang := atan2(altura * sx, largura)
		var base := Basis(Vector3.UP, giro) * Basis(Vector3(0.0, 0.0, 1.0), ang)
		KitModular.caixa_livre(sup, &"tabua", centro,
			Vector3(comp, 0.28, 0.06), base, cor, 2.0)


## Um modulo de casa colonial: parede caiada, saia de mofo, porta alta que da na
## calcada e janela de esquadria escura. Nao poe telhado — quem chama decide se
## a casa e isolada ou parte de uma fileira germinada, e o telhado corrido e a
## diferenca entre as duas.
##
## `faces_parede` deixa o chamador matar as paredes-meia. Nao e economia de
## triangulo: dois modulos encostados tem a parede lateral EXATAMENTE no mesmo
## plano, e duas faces coplanares brigam por profundidade e piscam a cada passo.
## Quem nao existe nao pisca.
static func _modulo_colonial(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float, largura: float, semente: int,
		faces_parede: int = PSXMesh.FACE_TODAS) -> void:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	var h := CASA_PE_DIREITO
	var f := CASA_FUNDURA
	var caiacao := CAIACOES[absi(semente * 7 + 3) % CAIACOES.size()]
	var esquadria := ESQUADRIAS[absi(semente * 13 + 5) % ESQUADRIAS.size()]
	var face := centro + frente * (f * 0.5)

	KitModular.caixa_cor(sup, &"reboco", centro + Vector3(0.0, h * 0.5, 0.0),
		Vector3(largura, h, f), caiacao, giro, faces_parede, 2.5)
	# Saia de mofo na base. E a marca que mais diz "colonial gasto" nas refs, e
	# vem de graca: um metro de parede escurecido ancora a casa no chao em vez
	# de deixa-la boiando sobre o paralelepipedo.
	KitModular.caixa_cor(sup, &"reboco",
		face + Vector3(0.0, 0.45, 0.0),
		Vector3(largura * 0.99, 0.9, 0.08), caiacao.lerp(Color("4a4a3c"), 0.55),
		giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Friso sob o beiral: linha clara que separa parede de telha. Sem ela, a
	# noite, a parede caiada e a telha escura se encostam num degrade e o
	# beiral some.
	KitModular.caixa_cor(sup, &"reboco",
		face + Vector3(0.0, h - 0.18, 0.0),
		Vector3(largura * 0.99, 0.22, 0.14), caiacao.lerp(Color.WHITE, 0.35),
		giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Reboco caido na fachada. Antes so a igreja tinha: o casario era caiacao
	# lisa de cima a baixo e lia como parede recem-pintada num lugar que a
	# historia diz estar largado ha tempo.
	descascado(sup, face, lado, frente, largura, h, giro,
		semente * 3 + 11, 2 + (absi(semente) % 2), Color("6b4a33"))

	# --- os fundos --------------------------------------------------------
	#
	# Eram uma laje branca lisa. Ninguem projeta cena para o fundo da casa, mas
	# o jogador anda por tras dela, e la a fileira inteira virava um muro de
	# reboco novo sem uma marca. O fundo de casa colonial e o lado que ninguem
	# caia: mais mofo, mais tijolo a mostra, uma janelinha alta de servico e o
	# tubo de descida da agua.
	var fundo := centro - frente * (f * 0.5)
	var atras := -frente
	KitModular.caixa_cor(sup, &"reboco", fundo + Vector3(0.0, 0.55, 0.0),
		Vector3(largura * 0.99, 1.1, 0.08),
		caiacao.lerp(Color("3c4034"), 0.68), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	descascado(sup, fundo, lado, atras, largura, h, giro + PI,
		semente * 5 + 29, 3 + (absi(semente) % 3), Color("6b4a33"))
	# Janela alta de servico: vao escuro sem moldura clara. E o unico furo do
	# fundo, e e alto porque cozinha colonial tem janela no alto da parede.
	var jf := fundo + lado * lerpf(-largura * 0.24, largura * 0.24, _tom(semente, 61)) \
		+ Vector3(0.0, 2.35, 0.0)
	KitModular.caixa_cor(sup, &"janela_apagada", jf + atras * 0.05,
		Vector3(0.72, 0.62, 0.08), Color("15140f"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo", jf + atras * 0.08 + Vector3(0.0, -0.36, 0.0),
		Vector3(0.86, 0.1, 0.2), Color("8e8a7c"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	escorrido(sup, jf + Vector3(0.0, -0.4, 0.0), atras, 1.5, 0.5, giro,
		caiacao.lerp(Color("2e3228"), 0.6))
	# Tubo de descida na quina, com a mancha que ele deixa no reboco.
	var quina := fundo + lado * (largura * (0.44 if (absi(semente) % 2) == 0 else -0.44))
	KitModular.caixa_cor(sup, &"metal", quina + atras * 0.1 + Vector3(0.0, h * 0.5, 0.0),
		Vector3(0.14, h, 0.14), Color("3b3a34"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	escorrido(sup, quina + Vector3(0.0, 1.0, 0.0), atras, 1.0, 0.34, giro,
		caiacao.lerp(Color("2e3228"), 0.55))

	# Quem esta pregado e quem esta acordado.
	#
	# Uma fileira em que todo vao e igual le como cenario; a variacao e o que faz
	# o jogador ler CASA por casa. Tres em dez com tabua cruzada dizem que este
	# lugar esvaziou, e uma em onze com a janela acesa as onze e quinze da noite
	# desfaz a leitura de "cidade abandonada" — que e pior, porque entao tem
	# alguem. A janela acesa nao custa luz nenhuma: `janela_acesa` tem emissao
	# propria no material.
	var tapada := _tom(semente, 41) < 0.40
	var acesa := not tapada and _tom(semente, 43) < 0.14
	var porta_l := 1.05
	var porta_h := 2.35
	var porta_x := lerpf(-largura * 0.22, largura * 0.22, float(absi(semente) % 5) / 4.0)
	var porta_c := face + lado * porta_x + Vector3(0.0, porta_h * 0.5, 0.0)
	KitModular.caixa_cor(sup, &"reboco", porta_c + frente * 0.04,
		Vector3(porta_l + 0.34, porta_h + 0.2, 0.09),
		caiacao.lerp(Color.WHITE, 0.45), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"porta", porta_c + frente * 0.07,
		Vector3(porta_l, porta_h, 0.08), esquadria, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"porta", porta_c + frente * 0.1,
		Vector3(0.05, porta_h * 0.94, 0.05), esquadria.lerp(Color.BLACK, 0.5),
		giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	if tapada:
		_tabuas_cruzadas(sup, porta_c + frente * 0.13, giro, porta_l + 0.1, 2.2)
	# Soleira de pedra: um degrau raso, que e como a porta encosta na rua nas refs.
	KitModular.caixa_cor(sup, &"concreto_sujo",
		face + lado * porta_x + frente * 0.16 + Vector3(0.0, 0.06, 0.0),
		Vector3(porta_l + 0.4, 0.12, 0.34), Color("a8a496"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Janelas nos vaos que sobraram, com peitoril claro embaixo.
	for sx: float in [-1.0, 1.0]:
		var jx := porta_x + sx * (porta_l * 0.5 + 0.28 + largura * 0.16)
		if absf(jx) > largura * 0.5 - 0.75:
			continue
		var jan := face + lado * jx + Vector3(0.0, 1.85, 0.0)
		KitModular.caixa_cor(sup, &"reboco", jan + frente * 0.04,
			Vector3(1.22, 1.42, 0.09),
			caiacao.lerp(Color("241f18") if tapada else Color.WHITE, 0.45), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		# So a janela da DIREITA acende. Duas acesas na mesma casa leem como
		# "casa habitada"; uma so le como comodo, e comodo tem alguem dentro.
		if acesa and sx > 0.0:
			KitModular.caixa(sup, &"janela_acesa", jan + frente * 0.07,
				Vector3(0.98, 1.18, 0.08), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
			KitModular.caixa_cor(sup, &"janela_apagada", jan + frente * 0.11,
				Vector3(0.08, 1.12, 0.06), Color("120f0a"), giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
		else:
			KitModular.caixa_cor(sup, &"janela_apagada", jan + frente * 0.07,
				Vector3(0.98, 1.18, 0.08), esquadria, giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
			KitModular.caixa_cor(sup, &"janela_apagada", jan + frente * 0.1,
				Vector3(0.05, 1.1, 0.05), esquadria.lerp(Color.BLACK, 0.5), giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
		if tapada:
			_tabuas_cruzadas(sup, jan + frente * 0.13, giro, 1.16, 1.3)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			jan + frente * 0.12 + Vector3(0.0, -0.78, 0.0),
			Vector3(1.34, 0.13, 0.24), Color("b2ae9e"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	colisao.append({"tamanho": Vector3(largura, h, f),
		"pos": centro + Vector3(0.0, h * 0.5, 0.0), "giro": Vector3(0.0, giro, 0.0)})


## Cabana colonial isolada: um modulo com telhado proprio e os dois oitoes.
##
## E a peca das casas soltas alem das fileiras, as que aparecem pelas frestas.
## Fora de esquadro elas dizem, sem uma linha de dialogo, que aqui a rua nao
## mandou em nada: numa praca colonial tudo se alinha, e a casa torta e a
## primeira coisa que o olho estranha.
static func casa_colonial_baixa(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float, largura: float = 7.5,
		semente: int = 0) -> void:
	var s := semente if semente != 0 else int(centro.x * 7.0)
	_modulo_colonial(sup, colisao, centro, giro, largura, s)
	_telhado_de_casario(sup, centro, giro, largura,
		CAIACOES[absi(s) % CAIACOES.size()])


## Fileira de casario colonial germinado: modulos encostados, telhado corrido.
##
## `de` e `ate` sao as pontas da linha de FACHADA, no chao; a casa cresce para
## tras. `giro` e a direcao para onde a fachada olha.
##
## As casas coloniais em volta de uma praca sao germinadas — parede comum, sem
## vao — e por isso o telhado e UM so, da primeira a ultima. A versao anterior
## plantava cinco casas independentes de 8 m a cada 4 m de passo: elas se
## atravessavam pela metade, as fachadas ficavam coplanares e cada telhado
## repetia o do vizinho no mesmo plano. Ficava de pe porque tudo era caixa
## chapada; com agua inclinada de verdade viraria uma briga de profundidade
## acesa em metade do perimetro da praca.
static func fileira_colonial(sup: Dictionary, colisao: Array[Dictionary],
		de: Vector3, ate: Vector3, giro: float, semente: int) -> void:
	var eixo := ate - de
	var comp := eixo.length()
	if comp < 3.0:
		return
	var dir := eixo / comp
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var giro_fila := atan2(dir.x, dir.z)

	# Modulos de 4,2 a 6,2 m — a largura de uma casa de porta e duas janelas.
	# O ultimo absorve a sobra para a fileira fechar exatamente no `ate`.
	var larguras: Array[float] = []
	var somado := 0.0
	var k := 0
	while somado < comp - 0.01:
		var w := lerpf(4.2, 6.2, _tom(semente + k * 31, 71))
		if comp - somado - w < 3.4:
			w = comp - somado
		larguras.append(w)
		somado += w
		k += 1

	var andado := 0.0
	for i in larguras.size():
		var w: float = larguras[i]
		var centro := de + dir * (andado + w * 0.5) - frente * (CASA_FUNDURA * 0.5)
		# Ponta da fileira mantem a lateral; o miolo mata as duas paredes-meia.
		var faces := PSXMesh.FACE_TODAS
		if i > 0:
			faces &= ~PSXMesh.FACE_ESQ
		if i < larguras.size() - 1:
			faces &= ~PSXMesh.FACE_DIR
		_modulo_colonial(sup, colisao, centro, giro, w, semente + i * 17, faces)
		# Pilastra da parede-meia: a linha vertical que conta onde acaba uma casa
		# e comeca a outra. Sem ela a fileira le como um galpao comprido.
		if i > 0:
			KitModular.caixa_cor(sup, &"reboco",
				de + dir * andado + frente * 0.06
					+ Vector3(0.0, CASA_PE_DIREITO * 0.5, 0.0),
				Vector3(0.3, CASA_PE_DIREITO, 0.12),
				CAIACOES[absi(semente + i) % CAIACOES.size()].lerp(Color("6b6354"), 0.4),
				giro_fila + PI * 0.5, PSXMesh.FACE_TODAS, QUAD_FOLHA)
		andado += w

	var meio := de.lerp(ate, 0.5) - frente * (CASA_FUNDURA * 0.5)
	_telhado_de_casario(sup, meio, giro, comp, CAIACOES[absi(semente) % CAIACOES.size()])


## Telhado do casario: duas aguas caindo para a rua, oitoes nas pontas e a
## tabica escura na linha do beiral.
##
## A cumeeira corre PARALELA a fachada — e o "duas aguas caindo para a rua" das
## refs. `telhado_duas_aguas` deixa a cumeeira no Z local e as aguas caindo no X
## local, entao a fileira entra girada de um quarto de volta.
static func _telhado_de_casario(sup: Dictionary, centro: Vector3, giro: float,
		comprimento: float, caiacao: Color) -> void:
	var telha := TELHA_CLARA
	var telha_sombra := TELHA_ESCURA
	var giro_cumeeira := giro + PI * 0.5
	var y_beiral := CASA_PE_DIREITO
	telhado_duas_aguas(sup, centro + Vector3(0.0, y_beiral, 0.0),
		CASA_FUNDURA, comprimento, CASA_PICO, giro_cumeeira,
		telha, telha_sombra, CASA_BEIRAL)
	# Oitoes no plano das paredes de ponta, sob o avanco do beiral.
	var ao_longo := Vector3(sin(giro_cumeeira), 0.0, cos(giro_cumeeira))
	for sx: float in [-1.0, 1.0]:
		oitao(sup, &"reboco",
			centro + ao_longo * (comprimento * 0.5 * sx) + Vector3(0.0, y_beiral, 0.0),
			CASA_FUNDURA, CASA_PICO,
			giro_cumeeira + (0.0 if sx > 0.0 else PI), caiacao)
	# Tabica: a tabua escura que fecha a ponta da telha. E ela que desenha a
	# linha reta do beiral contra o ceu, e o beiral e metade da silhueta.
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	for sz: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"tabua",
			centro + frente * ((CASA_FUNDURA * 0.5 + CASA_BEIRAL) * sz)
				+ Vector3(0.0, y_beiral - 0.04, 0.0),
			Vector3(0.1, 0.2, comprimento + CASA_BEIRAL * 2.0),
			Color("32241a"), giro_cumeeira, PSXMesh.FACE_TODAS, QUAD_TELHA)


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


# --- lago -------------------------------------------------------------------

## Lamina d'agua, um pouco abaixo da grama. Ver Y_GRAMA acima: a agua tem de
## ficar ABAIXO da margem, senao a borda do plano flutua sobre o barranco.
const Y_AGUA := 0.05
## Fundo do lago. Um metro e oitenta: passa da cabeca do jogador (1,75), que e
## o que separa "nadar" de "andar com agua na cintura".
const FUNDO_LAGO := -1.80
## Largura do barranco, em metros. E a rampa por onde se entra e se sai.
const MARGEM_LAGO := 3.4


## Escava o lago dentro de `r` e enche.
##
## Por que o barranco e feito de quatro lajes inclinadas e nao de degraus
## ---------------------------------------------------------------------
## Degrau e o jeito obvio e esta errado aqui: CharacterBody3D nao sobe degrau
## sozinho, entao um lago em degraus e uma armadilha — o jogador entra e nao
## volta. Quatro rampas de vinte e oito graus, uma por lado, sao subida e
## descida ao mesmo tempo, e o buraco que sobra em cada canto nao prende
## ninguem porque ali ja se esta nadando.
##
## As lajes se atravessam nos cantos de proposito. Recortar o canto custaria
## quatro triangulos por quina para consertar uma interseccao que fica um metro
## e meio debaixo de agua turva.
static func lago(sup: Dictionary, colisao: Array[Dictionary], r: Rect2) -> void:
	var interno := r.grow(-MARGEM_LAGO)
	if interno.size.x < 2.0 or interno.size.y < 2.0:
		return

	piso(sup, &"terra", interno, FUNDO_LAGO, Color(0.46, 0.48, 0.42))

	var queda := Y_GRAMA - FUNDO_LAGO
	var ang := atan2(queda, MARGEM_LAGO)
	var comp := sqrt(queda * queda + MARGEM_LAGO * MARGEM_LAGO)
	var meio_y := (Y_GRAMA + FUNDO_LAGO) * 0.5
	# [centro, tamanho, giro] de cada barranco. Ver a nota sobre o sinal do
	# angulo no cabecalho: a ponta que desce e sempre a de dentro.
	var lajes := [
		[Vector3(r.get_center().x, meio_y, (r.position.y + interno.position.y) * 0.5),
			Vector3(r.size.x, 0.4, comp), Vector3(ang, 0.0, 0.0)],
		[Vector3(r.get_center().x, meio_y, (r.end.y + interno.end.y) * 0.5),
			Vector3(r.size.x, 0.4, comp), Vector3(-ang, 0.0, 0.0)],
		[Vector3((r.position.x + interno.position.x) * 0.5, meio_y, r.get_center().y),
			Vector3(comp, 0.4, r.size.y), Vector3(0.0, 0.0, -ang)],
		[Vector3((r.end.x + interno.end.x) * 0.5, meio_y, r.get_center().y),
			Vector3(comp, 0.4, r.size.y), Vector3(0.0, 0.0, ang)],
	]
	for laje: Array in lajes:
		var centro: Vector3 = laje[0]
		if centro.x < -8.0 or centro.x > KitModular.CHUNK + 8.0:
			continue
		if centro.z < -8.0 or centro.z > KitModular.CHUNK + 8.0:
			continue
		var giro: Vector3 = laje[2]
		var base := Basis.from_euler(giro)
		KitModular.caixa_livre(sup, &"areia", centro, laje[1], base,
			Color(0.58, 0.50, 0.40), 3.0)
		colisao.append({"tamanho": laje[1], "pos": centro, "giro": giro})

	# Fundo caminhavel. Sem isto, com o chao do chunk furado, o jogador caia
	# abaixo do mundo no meio do lago.
	piso(sup, &"terra", interno, FUNDO_LAGO, Color(0.32, 0.36, 0.30))
	piso_solido(colisao, interno, FUNDO_LAGO + 0.08)

	# A lamina por ultimo, e por cima de tudo. O quad grande cai na subdivisao
	# padrao de dois metros, que e a resolucao da onda do psx_agua.
	piso(sup, &"agua_lago", r, Y_AGUA)

	# Fita de espuma na margem, so nos dois lados longos. Nos quatro ela vira
	# moldura de piscina; em dois le como a agua batendo onde bate mais vento.
	var fita := 0.9
	piso(sup, &"espuma", Rect2(r.position.x, r.position.y, r.size.x, fita),
		Y_AGUA + 0.012)
	piso(sup, &"espuma", Rect2(r.position.x, r.end.y - fita, r.size.x, fita),
		Y_AGUA + 0.012)


## Nenufar boiando. Deitado, e por isso usa a celula de vista de cima.
static func nenufar(sup: Dictionary, onde: Vector3, tam: float, giro: float,
		com_flor: bool) -> void:
	AtlasKit.deitado(sup, &"flor", onde, Vector2(tam, tam),
		Vector2i(1, 1) if com_flor else Vector2i(0, 1), giro,
		Color(0.92, 0.95, 0.88))


## Um par de planos cruzados com uma celula do atlas de flores.
##
## Cruzados, e nao billboard: billboard num jogo de PS1 e anacronismo, e a 480
## de largura o giro do plano se ve como um estalo. Dois planos a noventa graus
## leem como volume de qualquer angulo e custam quatro triangulos.
static func moita_de_flor(sup: Dictionary, base: Vector3, celula: Vector2i,
		tam: float, giro: float, cor: Color = Color.WHITE) -> void:
	for k in 2:
		var t := Transform3D(Basis(Vector3.UP, giro + PI * 0.5 * float(k)),
			base + Vector3(0.0, tam * 0.5, 0.0))
		AtlasKit.folha_ao_vento(sup, &"flor", Vector2(tam, tam), t, celula, cor)


## Deque de madeira avancando sobre a agua. E de onde se ve o lago inteiro, e e
## de onde o jogador pula.
static func deque(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		comprimento: float, giro: float) -> void:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var altura := Y_GRAMA + 0.28
	var n := maxi(2, int(comprimento / 0.42))
	for i in n:
		var t := (float(i) + 0.5) / float(n)
		var p := base + frente * (comprimento * t)
		if p.x < -1.0 or p.x > KitModular.CHUNK + 1.0:
			continue
		if p.z < -1.0 or p.z > KitModular.CHUNK + 1.0:
			continue
		var tom := 0.86 + fmod(float(i) * 0.37, 0.24)
		KitModular.caixa_cor(sup, &"tabua", p + Vector3(0.0, altura, 0.0),
			Vector3(1.7, 0.08, comprimento / float(n) - 0.05),
			Color("7a6449") * tom, giro, PSXMesh.FACE_TODAS, 8.0)
	# Estacas. Duas por par, a cada metro e meio.
	var pares := maxi(2, int(comprimento / 1.5))
	for i in pares + 1:
		var p := base + frente * (comprimento * float(i) / float(pares))
		for lado: float in [-1.0, 1.0]:
			var e := p + Vector3(cos(giro), 0.0, -sin(giro)) * (0.72 * lado)
			if e.x < -1.0 or e.x > KitModular.CHUNK + 1.0:
				continue
			if e.z < -1.0 or e.z > KitModular.CHUNK + 1.0:
				continue
			KitModular.caixa_cor(sup, &"tabua",
				e + Vector3(0.0, (altura + FUNDO_LAGO) * 0.5, 0.0),
				Vector3(0.14, altura - FUNDO_LAGO, 0.14), Color("5f4d38"), giro,
				PSXMesh.FACE_TODAS, 8.0)
	colisao.append({
		"tamanho": Vector3(absf(sin(giro)) * comprimento + 1.7 * absf(cos(giro)),
			0.3, absf(cos(giro)) * comprimento + 1.7 * absf(sin(giro))),
		"pos": base + frente * (comprimento * 0.5) + Vector3(0.0, altura - 0.1, 0.0),
	})
