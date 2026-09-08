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


## Coreto octogonal da praca: base de pedra, escada, oito pilares de madeira,
## guarda-corpo e telhado de telha. E o marco central da Praca da Matriz.
##
## Seis pilares liam como caramanchao generico; oito fecham o octogono que a
## referencia pede. O telhado e piramide pontuda de faces inclinadas (caixa_livre),
## nao caixas empilhadas — na nevoa a silhueta precisa ler como ponta, e as
## telhas precisam aparecer na face. A escada de pedra com peitoril e o que faz
## a base ler como podium e nao como caixa flutuando.
static func coreto(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, raio: float) -> void:
	var madeira := Color("5a4634")
	var pedra := Color("9a968c")
	var pedra_degrau := Color("b0aca2")
	var pedra_espelho := Color("7a766c")
	var telha := Color("c87840")
	var telha_escura := Color("a85830")
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
		KitModular.caixa_cor(sup, &"tabua",
			meio + Vector3(0.0, y_piso + 1.05, 0.0),
			Vector3(0.07, 0.08, comp), madeira, giro,
			PSXMesh.FACE_TODAS, 8.0)
		KitModular.caixa_cor(sup, &"tabua",
			meio + Vector3(0.0, y_piso + 0.55, 0.0),
			Vector3(0.05, 0.05, comp), madeira, giro,
			PSXMesh.FACE_TODAS, 8.0)

	# Telhado: beiral + piramide pontuda de 8 faces inclinadas (telha legivel).
	# roof_h 4.2: ponta le de longe (pin Cine2) sem engolir o close debaixo do beiral.
	var y_beiral := y_piso + alt_pilar + 0.08
	var eave_r := raio * 1.18
	var roof_h := 4.2
	KitModular.caixa_cor(sup, &"teto", centro + Vector3(0.0, y_beiral, 0.0),
		Vector3(eave_r * 2.15, 0.14, eave_r * 2.15), telha_escura, PI / 8.0,
		PSXMesh.FACE_TODAS, 1.4)
	# Forro sob o beiral (leitura de volume oco).
	KitModular.caixa_cor(sup, &"tabua", centro + Vector3(0.0, y_beiral - 0.06, 0.0),
		Vector3(raio * 1.7, 0.08, raio * 1.7), madeira, PI / 8.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	var pitch := atan2(roof_h, eave_r)
	var hyp := sqrt(eave_r * eave_r + roof_h * roof_h)
	for i in 8:
		var ang := TAU * float(i) / 8.0 + PI / 8.0
		var face_w := 2.0 * eave_r * tan(PI / 8.0)
		# Centro da face a meia hipotenusa (media entre beiral e apex).
		var mid_r := eave_r * 0.48
		var mid_y := y_beiral + roof_h * 0.48
		var pos := centro + Vector3(cos(ang) * mid_r, mid_y, sin(ang) * mid_r)
		# Yaw: face olha pra fora; pitch: sobe ate a ponta.
		var b_face := Basis(Vector3.UP, -ang + PI * 0.5) * Basis(Vector3.RIGHT, pitch)
		# Largura media (afunila no apex) — 0.68 do cordao do beiral.
		var cor_face := telha if (i % 2) == 0 else telha_escura
		KitModular.caixa_livre(sup, &"teto", pos,
			Vector3(face_w * 0.68, hyp * 0.98, 0.11), b_face, cor_face, 1.15)
	# Ponta / finial — silhueta aguda na nevoa (haste um pouco mais alta).
	KitModular.caixa_cor(sup, &"teto",
		centro + Vector3(0.0, y_beiral + roof_h * 0.78, 0.0),
		Vector3(0.48, roof_h * 0.32, 0.48), telha, PI / 8.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal",
		centro + Vector3(0.0, y_beiral + roof_h + 0.28, 0.0),
		Vector3(0.1, 0.55, 0.1), Color("3a3834"), 0.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	colisao.append({"tamanho": Vector3(raio * 2.1, y_piso + 0.2, raio * 2.1),
		"pos": centro + Vector3(0.0, y_piso * 0.5, 0.0)})


## Igreja colonial da Praca da Matriz: nave, torre sineira, cruz e porta em arco.
##
## `giro` aponta a fachada (0 = olha para +Z). A torre fica a esquerda da
## fachada, que e o lado que as refs mostram. Quoins em bloco, porta com
## ombreira/arco e cruz grossa — tudo pensado pra sobrar na nevoa densa.
static func igreja_matriz(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float = 0.0) -> void:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	var reboco := Color("d8d0b8")
	var mancha := Color("8a7a5a")
	var quoin_a := Color("3a2e20")
	var quoin_b := Color("100c08")
	var telha := Color("6a3e24")
	# Contraste porta/ombreira p/ fog=denso @ ~10m / 480x270 (Cine2 deitado):
	# parede um pouco mais escura pra o marco branco sobrar; folha preta pura;
	# cruz CLARA (nao metal escuro) — o escuro some no wash, o claro nao.
	var porta := Color("000000")
	var ombreira := Color("ffffff")
	var trim := Color("000000")
	var cruz_clara := Color("fffff8")
	var largura := 11.0
	var fundura := 8.4
	var parede_h := 5.4
	# Plinto eleva a fachada acima do telhado do coreto no eixo Cine2.
	const PLINTO := 1.35
	KitModular.caixa_cor(sup, &"concreto_sujo",
		centro + Vector3(0.0, PLINTO * 0.5, 0.0),
		Vector3(largura + 1.2, PLINTO, fundura + 1.0), Color("6a6458"), giro,
		PSXMesh.FACE_TODAS, 2.0)
	# Escada de pedra no eixo da porta (frente): sobe do calcamento ao plinto /
	# soleira do portao. Mesma linguagem do coreto (espelho escuro + piso claro +
	# cheeks). CharacterBody3D nao sobe degrau sozinho (lago/escorregador): visual
	# em degraus + rampa de colisao inclinada por baixo.
	var pedra := Color("9a968c")
	var pedra_degrau := Color("b0aca2")
	var pedra_espelho := Color("7a766c")
	var n_degraus := 5
	var larg_escada := 3.2
	var h_deg := PLINTO / float(n_degraus)
	var prof := 0.42
	# Distancia do portal freestanding (mesma conta da porta mais abaixo).
	var portal_afast := fundura * 0.5 + 0.06 + 1.4
	for degrau in n_degraus:
		var t := float(degrau)
		var y_topo := (t + 1.0) * h_deg
		# Baixo = praca (+frente); alto = soleira do portao.
		var afast := portal_afast + 0.12 + (float(n_degraus - 1) - t) * (prof * 0.95)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + frente * (afast - prof * 0.15) + Vector3(0.0, y_topo - h_deg * 0.5, 0.0),
			Vector3(larg_escada - t * 0.05, h_deg, 0.1), pedra_espelho, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + frente * afast + Vector3(0.0, y_topo - 0.04, 0.0),
			Vector3(larg_escada - t * 0.05, 0.08, prof), pedra_degrau, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	var escada_corrida := float(n_degraus) * prof * 0.95 + 0.2
	var escada_meio := portal_afast + 0.12 + escada_corrida * 0.5
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + lado * (larg_escada * 0.5 + 0.12) * sx
				+ frente * escada_meio + Vector3(0.0, PLINTO * 0.42, 0.0),
			Vector3(0.22, PLINTO * 0.84, escada_corrida), pedra, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Rampa andavel sob a escada (pitch sobe em direcao -frente, ate o portao).
	var ang_esc := atan2(PLINTO, escada_corrida)
	var hip_esc := sqrt(PLINTO * PLINTO + escada_corrida * escada_corrida)
	colisao.append({
		"tamanho": Vector3(larg_escada + 0.25, 0.22, hip_esc),
		"pos": centro + frente * escada_meio + Vector3(0.0, PLINTO * 0.5, 0.0),
		"giro": Vector3(ang_esc * cos(giro), giro, -ang_esc * sin(giro)),
	})
	# Plinto andavel + patamar ate a soleira do portal.
	KitModular.solido(colisao, centro + Vector3(0.0, PLINTO * 0.5, 0.0),
		Vector3(largura + 1.2, PLINTO, fundura + 1.0), giro)
	var plinto_borda := fundura * 0.5 + 0.5
	var pat_comp := maxf(0.4, portal_afast - plinto_borda + 0.4)
	KitModular.solido(colisao,
		centro + frente * ((portal_afast + plinto_borda) * 0.5)
			+ Vector3(0.0, PLINTO * 0.5, 0.0),
		Vector3(larg_escada + 0.5, PLINTO, pat_comp), giro)
	centro += Vector3(0.0, PLINTO, 0.0)

	# Nave.
	KitModular.caixa_cor(sup, &"reboco",
		centro + Vector3(0.0, parede_h * 0.5, 0.0),
		Vector3(largura, parede_h, fundura), reboco, giro,
		PSXMesh.FACE_TODAS, 2.5)
	# Saia de weathering na base — mancha que ancora o volume na nevoa.
	KitModular.caixa_cor(sup, &"tijolo",
		centro + frente * (fundura * 0.48) + Vector3(0.0, 0.55, 0.0),
		Vector3(largura * 0.98, 1.1, 0.2), mancha, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Quoins em blocos alternados na fachada (cantos +Z da nave).
	var n_quoin := 8
	for sx: float in [-1.0, 1.0]:
		for k in n_quoin:
			var yk := 0.35 + float(k) * (parede_h * 0.88 / float(n_quoin))
			var cor_q := quoin_a if (k % 2) == 0 else quoin_b
			var alt_q := parede_h * 0.88 / float(n_quoin) - 0.04
			KitModular.caixa_cor(sup, &"tijolo",
				centro + lado * (largura * 0.48 * sx) + frente * (fundura * 0.5 + 0.14)
					+ Vector3(0.0, yk, 0.0),
				Vector3(1.15, alt_q, 0.78), cor_q, giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
			# Face escura no quoin (quebra a silhueta lavada).
			KitModular.caixa_cor(sup, &"metal",
				centro + lado * (largura * 0.48 * sx) + frente * (fundura * 0.5 + 0.52)
					+ Vector3(0.0, yk, 0.0),
				Vector3(1.05, alt_q * 0.92, 0.1), trim if (k % 2) == 1 else Color("2a2018"), giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
		# Quoin tambem no canto traseiro (silhueta lateral).
		KitModular.caixa_cor(sup, &"tijolo",
			centro + lado * (largura * 0.48 * sx) + frente * (fundura * -0.48)
				+ Vector3(0.0, parede_h * 0.45, 0.0),
			Vector3(0.42, parede_h * 0.9, 0.42), mancha, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Frontao e cruz (cruz grossa, projetada pra frente — le na nevoa).
	KitModular.caixa_cor(sup, &"reboco",
		centro + frente * (fundura * 0.02) + Vector3(0.0, parede_h + 0.55, 0.0),
		Vector3(largura * 0.92, 1.1, 0.55), reboco, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"teto",
		centro + Vector3(0.0, parede_h + 0.35, 0.0),
		Vector3(largura + 0.6, 0.35, fundura + 0.6), telha, giro,
		PSXMesh.FACE_TODAS, 2.0)
	# Cruz punch fog=denso: plano do portal (distancia da ombreira), ACIMA do
	# lintel (sem intersect), mid band. Braço largo tipo segundo lintel cream +
	# haste + backplate escuro + janela_acesa pro pin.
	var cruz_c := centro + frente * (fundura * 0.5 + 0.06 + 1.4) + Vector3(0.0, 6.15, 0.0)
	KitModular.caixa_cor(sup, &"metal",
		cruz_c + frente * -0.28, Vector3(4.0, 4.2, 0.45), trim, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal",
		cruz_c + frente * -0.1, Vector3(1.15, 3.7, 0.5), trim, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal",
		cruz_c + frente * -0.1 + Vector3(0.0, 0.55, 0.0),
		Vector3(3.7, 1.15, 0.5), trim, giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Corpo: mesma linguagem da ombreira (concreto_sujo branco).
	KitModular.caixa_cor(sup, &"concreto_sujo",
		cruz_c, Vector3(0.95, 3.4, 0.7), ombreira, giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		cruz_c + Vector3(0.0, 0.55, 0.0), Vector3(3.4, 0.95, 0.7), ombreira, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		cruz_c + frente * 0.32, Vector3(1.05, 3.5, 0.16), Color("ffffff"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		cruz_c + frente * 0.32 + Vector3(0.0, 0.55, 0.0),
		Vector3(3.5, 1.05, 0.16), Color("ffffff"), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa(sup, &"janela_acesa",
		cruz_c + frente * 0.45, Vector3(1.1, 3.6, 0.24), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa(sup, &"janela_acesa",
		cruz_c + frente * 0.45 + Vector3(0.0, 0.55, 0.0),
		Vector3(3.6, 1.1, 0.24), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa(sup, &"janela_acesa",
		cruz_c + frente * 0.58, Vector3(0.85, 3.2, 0.14), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa(sup, &"janela_acesa",
		cruz_c + frente * 0.58 + Vector3(0.0, 0.55, 0.0),
		Vector3(3.2, 0.85, 0.14), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Porta em arco: PORTAL freestanding +1.4 m a frente da nave.
	# Marco OCO (jambas+lintel+soleira) + buraco preto — slab cheio tapava a
	# porta. Rim janela_acesa = truque do poste_lanterna, so na borda.
	var porta_parede := centro + frente * (fundura * 0.5 + 0.06) + Vector3(0.0, 1.85, 0.0)
	var porta_c := porta_parede + frente * 1.4
	# Folha preta na parede (fundo).
	KitModular.caixa_cor(sup, &"porta", porta_parede, Vector3(2.7, 4.1, 0.4), porta, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"porta",
		porta_parede + Vector3(0.0, 1.95, 0.0), Vector3(2.5, 1.0, 0.35), porta, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Buraco preto no plano do portal (le como vao).
	KitModular.caixa_cor(sup, &"porta",
		porta_c + frente * -0.05, Vector3(2.4, 3.9, 0.35), porta, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Ombreira OCA: jambas + lintel + soleira (branco).
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"concreto_sujo",
			porta_c + lado * (1.55 * sx) + Vector3(0.0, 0.05, 0.0),
			Vector3(0.7, 4.5, 0.85), ombreira, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		porta_c + Vector3(0.0, 2.2, 0.0), Vector3(3.5, 0.55, 0.85), ombreira, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)  # lintel
	KitModular.caixa_cor(sup, &"concreto_sujo",
		porta_c + Vector3(0.0, -1.95, 0.0), Vector3(3.5, 0.4, 0.85), ombreira, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)  # soleira
	# Arco em degraus no lintel.
	KitModular.caixa_cor(sup, &"concreto_sujo",
		porta_c + Vector3(0.0, 2.55, 0.05), Vector3(2.6, 0.4, 0.7), ombreira, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		porta_c + Vector3(0.0, 2.85, 0.05), Vector3(1.7, 0.32, 0.7), ombreira, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		porta_c + Vector3(0.0, 3.1, 0.05), Vector3(1.0, 0.28, 0.7), ombreira, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Rim emissivo oco (poste trick).
	var rim_z := porta_c + frente * 0.45
	KitModular.caixa(sup, &"janela_acesa",
		rim_z + Vector3(0.0, 2.2, 0.0), Vector3(3.6, 0.3, 0.14), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa(sup, &"janela_acesa",
		rim_z + Vector3(0.0, -1.95, 0.0), Vector3(3.6, 0.24, 0.14), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa(sup, &"janela_acesa",
			rim_z + lado * (1.7 * sx) + Vector3(0.0, 0.1, 0.0),
			Vector3(0.3, 4.4, 0.14), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Travessa na folha.
	KitModular.caixa_cor(sup, &"metal",
		porta_parede + Vector3(0.0, 0.0, 0.22), Vector3(0.14, 3.7, 0.1), Color("1a1a18"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"janela_apagada",
			centro + frente * (fundura * 0.5 + 0.05) + lado * (2.7 * sx)
				+ Vector3(0.0, 3.6, 0.0),
			Vector3(1.2, 1.4, 0.14), Color("000000"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		# Arco simples sobre cada janela.
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + frente * (fundura * 0.5 + 0.1) + lado * (2.7 * sx)
				+ Vector3(0.0, 4.35, 0.0),
			Vector3(1.45, 0.32, 0.22), ombreira, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"janela_apagada",
		centro + frente * (fundura * 0.5 + 0.05) + Vector3(0.0, 5.05, 0.0),
		Vector3(0.9, 0.9, 0.14), Color("000000"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Torre sineira a esquerda da fachada.
	var torre := centro + lado * (largura * 0.42 + 1.3) - frente * 0.4
	var torre_h := 9.6
	KitModular.caixa_cor(sup, &"reboco", torre + Vector3(0.0, torre_h * 0.5, 0.0),
		Vector3(3.2, torre_h, 3.2), reboco, giro, PSXMesh.FACE_TODAS, 2.5)
	# Quoins da torre (frente).
	for sx: float in [-1.0, 1.0]:
		for k in 6:
			var yk := 0.4 + float(k) * 1.15
			var cor_q := quoin_a if (k % 2) == 0 else quoin_b
			KitModular.caixa_cor(sup, &"tijolo",
				torre + lado * (1.5 * sx) + frente * 1.62 + Vector3(0.0, yk, 0.0),
				Vector3(0.4, 1.0, 0.28), cor_q, giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Vao do sino.
	KitModular.caixa_cor(sup, &"metal",
		torre + frente * 1.62 + Vector3(0.0, 6.55, 0.0),
		Vector3(1.7, 1.7, 0.14), Color("121210"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal",
		torre + Vector3(0.0, 6.5, 0.0), Vector3(0.7, 0.7, 0.7),
		Color("5a5648"), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"teto", torre + Vector3(0.0, torre_h + 0.35, 0.0),
		Vector3(3.7, 0.7, 3.7), telha, giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal",
		torre + Vector3(0.0, torre_h + 0.95, 0.0), Vector3(0.08, 0.55, 0.08),
		trim, giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	colisao.append({"tamanho": Vector3(largura + 0.4, parede_h, fundura + 0.4),
		"pos": centro + Vector3(0.0, parede_h * 0.5, 0.0)})
	colisao.append({"tamanho": Vector3(3.4, torre_h, 3.4),
		"pos": torre + Vector3(0.0, torre_h * 0.5, 0.0)})


## Poste de praca estilo lanterna: mastro preto fino e cabeca quadrada acesa.
## Devolve o ponto da luz (centro da lanterna).
static func poste_lanterna(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3) -> Vector3:
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
	KitModular.caixa(sup, &"janela_acesa", lanterna,
		Vector3(0.36, 0.42, 0.36), 0.0, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal", lanterna + Vector3(0.0, 0.38, 0.0),
		Vector3(0.48, 0.1, 0.48), ferro, PI * 0.25, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	colisao.append({"tamanho": Vector3(0.4, ALTURA, 0.4),
		"pos": base + Vector3(0.0, ALTURA * 0.5, 0.0)})
	return lanterna


## Casa colonial baixa de uma agua, para fechar o perimetro da praca.
static func casa_colonial_baixa(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float, largura: float = 7.5) -> void:
	var fundura := 5.2
	var h := 3.1
	var reboco := Color("d8d0c2")
	var telha := Color("6e452c")
	var trim := Color("2e2c28")
	KitModular.caixa_cor(sup, &"reboco", centro + Vector3(0.0, h * 0.5, 0.0),
		Vector3(largura, h, fundura), reboco, giro, PSXMesh.FACE_TODAS, 2.5)
	KitModular.caixa_cor(sup, &"teto", centro + Vector3(0.0, h + 0.35, 0.0),
		Vector3(largura + 0.5, 0.7, fundura + 0.5), telha, giro,
		PSXMesh.FACE_TODAS, 2.0)
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	KitModular.caixa_cor(sup, &"porta",
		centro + frente * (fundura * 0.5 + 0.04) + Vector3(0.0, 1.15, 0.0),
		Vector3(1.05, 2.2, 0.1), trim, giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"janela_apagada",
			centro + frente * (fundura * 0.5 + 0.04) + lado * (largura * 0.28 * sx)
				+ Vector3(0.0, 1.55, 0.0),
			Vector3(0.95, 1.05, 0.08), Color("2a2a28"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	colisao.append({"tamanho": Vector3(largura, h, fundura),
		"pos": centro + Vector3(0.0, h * 0.5, 0.0)})


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
			Color(0.92, 0.88, 0.78), 3.0)
		colisao.append({"tamanho": laje[1], "pos": centro, "giro": giro})

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
