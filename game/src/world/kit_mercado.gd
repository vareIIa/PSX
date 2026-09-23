## Movel de loja de conveniencia. So dados, nada de no: roda na thread junto com
## o resto da construcao do interior.
##
## A diferenca em relacao ao KitCasa nao e de tecnica, e de metodo. Movel de casa
## e caixa tingida, porque cada peca tem forma propria. Loja e o contrario: a
## gondola e uma caixa lisa, e quem faz a loja parecer cheia e a imagem pregada
## na frente dela. Modelar produto por produto custaria mil triangulos por
## gondola e, a 480x270 com dither por cima, nao ficaria melhor.
##
## Por isso quase tudo aqui usa KitModular.placa: a UV vai de 0 a 1 e a imagem
## cobre o painel inteiro uma vez so, sem repetir e sem cortar.
class_name KitMercado
extends RefCounted

# --- medidas padrao ---------------------------------------------------------
const ALTURA_GONDOLA := 1.52
const ALTURA_GONDOLA_PAREDE := 1.95
const PROF_GONDOLA := 0.86
const ALTURA_BALCAO := 0.98

## Aco pintado, o material de toda estrutura de loja.
const ESTRUTURA := Color("c4c6c2")
const ESTRUTURA_ESCURA := Color("6e716e")
const RODAPE_LOJA := Color("4a4d4c")
## A espinha perfurada das gondolas, atras do produto.
const ESPINHA := Color("c8cac6")
## A faixa clara na beira da prateleira, onde a etiqueta fica.
const FAIXA_PRECO := Color("e6e4dc")
## A camara fria por dentro: chapa branca acesa e grade de arame.
const INTERIOR_GELADEIRA := Color("e4ecef")
const GRADE_GELADEIRA := Color("b8c0c4")

## Quantas variantes de prateleira existem. Alternar entre elas evita a fileira
## de gondolas identicas, que e o que denuncia geometria repetida.
const VARIANTES := 3

## Distancia entre o painel de imagem e a estrutura em que ele e pregado.
##
## Tres centimetros e muito para um adesivo e pouco para virar degrau, e existe
## por causa da profundidade: com meio centimetro as duas superficies caem no
## mesmo valor de profundidade a poucos metros de distancia e passam a piscar
## uma na frente da outra a cada passo do jogador.
const FOLGA_PAINEL := 0.03

## Quanto a frente da loja se projeta da fachada do predio.
##
## Loja de conveniencia de verdade avanca sobre a calcada, e aqui isso resolve
## dois problemas de uma vez: fica parecida com a referencia e para de brigar
## com a parede do predio, que estava aparecendo atraves do vidro.
const SALIENCIA := 0.3

## Subdivisao dos paineis de imagem, em metros.
##
## Menor que o padrao do projeto de proposito. A UV afim empena a textura dentro
## de cada quad, e a prateleira e o caso pior possivel: a imagem e feita de
## linhas horizontais, que sao justamente o que o empeno denuncia. Com dois
## quads num painel de tres metros e meio as fileiras saem tortas.
const SUBDIVISAO_PAINEL := 0.65


static func _solido(colisao: Array[Dictionary], centro: Vector3,
		tamanho: Vector3, giro: float = 0.0) -> void:
	KitModular.solido(colisao, centro, tamanho, giro)


static func _prateleira(variante: int) -> StringName:
	return StringName("mercado_prateleira_%d" % (posmod(variante, VARIANTES)))


# --- gondolas ---------------------------------------------------------------

## Ilha de prateleira, dos dois lados e nas duas pontas. `comprimento` corre no
## eixo local X e `giro` gira em torno de Y.
##
## Ate a F1 a gondola era uma caixa lisa com a foto de uma prateleira pregada
## na frente. Agora o produto e coisa (`PrateleiraViva`), e o movel e o que ele
## e numa loja de verdade: a espinha perfurada no meio, a base, as chapas nos
## niveis do `Planograma` e a faixa clara na beira de cada chapa, onde a
## etiqueta amarela fica pendurada. Os niveis moram no planograma, e nao aqui:
## a chapa e a lata que pousa nela tem de concordar ao milimetro.
static func gondola(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, comprimento: float, giro: float, _variante: int) -> void:
	var b := Basis(Vector3.UP, giro)
	var alto := ALTURA_GONDOLA
	var meia := PROF_GONDOLA * 0.5
	var prof := Planograma.PROF_ILHA
	var ponta := Planograma.PONTA_ILHA
	var total := comprimento + ponta * 2.0
	var em := func(local: Vector3) -> Vector3:
		return centro + b * local

	# Espinha: a chapa perfurada que segura tudo, e o que aparece no vao entre
	# uma lata e outra. Escura, para o produto ler na frente dela.
	KitModular.caixa_cor(sup, &"mercado_espinha", em.call(Vector3(0.0, alto * 0.5, 0.0)),
		Vector3(comprimento, alto, 0.06), ESPINHA, giro)
	for lado: float in [1.0, -1.0]:
		# Base: a primeira prateleira e o tampo dela.
		KitModular.caixa_cor(sup, &"mercado_chapa",
			em.call(Vector3(0.0, Planograma.NIVEIS_ILHA[0] * 0.5, lado * meia * 0.5)),
			Vector3(comprimento, Planograma.NIVEIS_ILHA[0], meia), RODAPE_LOJA, giro)
		for n in Planograma.NIVEIS_ILHA.size():
			var y: float = Planograma.NIVEIS_ILHA[n]
			if n > 0:
				KitModular.caixa_cor(sup, &"mercado_chapa",
					em.call(Vector3(0.0, y - Planograma.CHAPA * 0.5, lado * (0.03 + prof * 0.5))),
					Vector3(comprimento, Planograma.CHAPA, prof + 0.01), ESTRUTURA, giro,
					PSXMesh.FACE_TODAS & ~PSXMesh.FACE_TRAS & ~PSXMesh.FACE_FRENTE)
			_beira(sup, em.call(Vector3(0.0, y, lado * (meia + 0.006))), comprimento,
				giro + (0.0 if lado > 0.0 else PI))

	# Pontas: a cabeceira de cada lado, com prateleira propria. Numa loja de
	# verdade e o melhor lugar de exposicao, e aqui e o que o jogador ve de
	# frente ao entrar no corredor.
	for sinal: float in [1.0, -1.0]:
		var xe := sinal * (comprimento * 0.5 + 0.015)
		KitModular.caixa_cor(sup, &"mercado_chapa", em.call(Vector3(xe, alto * 0.5, 0.0)),
			Vector3(0.03, alto, PROF_GONDOLA), ESPINHA, giro)
		var xc := sinal * (comprimento * 0.5 + 0.03 + prof * 0.5)
		KitModular.caixa_cor(sup, &"mercado_chapa",
			em.call(Vector3(xc, Planograma.NIVEIS_ILHA[0] * 0.5, 0.0)),
			Vector3(prof, Planograma.NIVEIS_ILHA[0], PROF_GONDOLA), RODAPE_LOJA, giro)
		for n in Planograma.NIVEIS_ILHA.size():
			var y: float = Planograma.NIVEIS_ILHA[n]
			if n > 0:
				KitModular.caixa_cor(sup, &"mercado_chapa",
					em.call(Vector3(xc, y - Planograma.CHAPA * 0.5, 0.0)),
					Vector3(prof + 0.01, Planograma.CHAPA, PROF_GONDOLA), ESTRUTURA, giro,
					PSXMesh.FACE_TODAS & ~PSXMesh.FACE_DIR & ~PSXMesh.FACE_ESQ)
			_beira(sup, em.call(Vector3(sinal * (total * 0.5 + 0.006), y, 0.0)),
				PROF_GONDOLA, giro + sinal * PI * 0.5)

	# Testeira: a faixa escura no topo, onde a loja pendura o cartaz do corredor.
	KitModular.caixa_cor(sup, &"mercado_chapa", em.call(Vector3(0.0, alto + 0.045, 0.0)),
		Vector3(total + 0.04, 0.09, PROF_GONDOLA + 0.04), ESTRUTURA_ESCURA, giro)

	_solido(colisao, em.call(Vector3(0.0, alto * 0.5, 0.0)),
		Vector3(total, alto, PROF_GONDOLA), giro)


## A faixa de preco na beira de uma prateleira. `giro` aponta a frente dela.
static func _beira(sup: Dictionary, frente: Vector3, comprimento: float, giro: float) -> void:
	KitModular.caixa_cor(sup, &"mercado_chapa", frente + Vector3(0.0, -0.02, 0.0),
		Vector3(comprimento, 0.04, 0.012), FAIXA_PRECO, giro)


## Prateleira encostada na parede: mais alta, cheia so de um lado.
## A frente olha para +Z local.
static func gondola_parede(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, comprimento: float, giro: float, _variante: int) -> void:
	var b := Basis(Vector3.UP, giro)
	var fundo := 0.5
	var alto := ALTURA_GONDOLA_PAREDE
	var prof := Planograma.PROF_PAREDE
	var em := func(local: Vector3) -> Vector3:
		return centro + b * local
	var costas := -fundo * 0.5 + 0.02
	KitModular.caixa_cor(sup, &"mercado_espinha", em.call(Vector3(0.0, alto * 0.5, costas)),
		Vector3(comprimento, alto, 0.04), ESPINHA, giro)
	KitModular.caixa_cor(sup, &"mercado_chapa",
		em.call(Vector3(0.0, Planograma.NIVEIS_PAREDE[0] * 0.5, 0.02)),
		Vector3(comprimento, Planograma.NIVEIS_PAREDE[0], fundo - 0.04), RODAPE_LOJA, giro)
	for n in Planograma.NIVEIS_PAREDE.size():
		var y: float = Planograma.NIVEIS_PAREDE[n]
		if n > 0:
			KitModular.caixa_cor(sup, &"mercado_chapa",
				em.call(Vector3(0.0, y - Planograma.CHAPA * 0.5, fundo * 0.5 - prof * 0.5)),
				Vector3(comprimento, Planograma.CHAPA, prof + 0.01), ESTRUTURA, giro,
				PSXMesh.FACE_TODAS & ~PSXMesh.FACE_TRAS)
		_beira(sup, em.call(Vector3(0.0, y, fundo * 0.5 + 0.006)), comprimento, giro)
	# Laterais: a chapa que fecha cada ponta da prateleira.
	for sinal: float in [1.0, -1.0]:
		KitModular.caixa_cor(sup, &"mercado_chapa",
			em.call(Vector3(sinal * (comprimento * 0.5 + 0.012), alto * 0.5, 0.0)),
			Vector3(0.024, alto, fundo), ESTRUTURA, giro)
	KitModular.caixa_cor(sup, &"mercado_chapa", em.call(Vector3(0.0, alto + 0.045, 0.0)),
		Vector3(comprimento + 0.05, 0.09, fundo + 0.04), ESTRUTURA_ESCURA, giro)

	_solido(colisao, em.call(Vector3(0.0, alto * 0.5, 0.0)),
		Vector3(comprimento, alto, fundo), giro)


# --- camara fria ------------------------------------------------------------

## Parede de geladeira com portas de vidro. Devolve as posicoes das luzes de
## dentro, que quem chama registra como props.
##
## E a parede do fundo de toda loja de conveniencia, e a unica coisa da cena que
## brilha sozinha em branco frio. Faz o fundo da loja puxar o olho, que e o que
## leva o jogador a atravessar o corredor inteiro.
static func geladeira_parede(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, comprimento: float, giro: float,
		portas: int) -> Array[Vector3]:
	var b := Basis(Vector3.UP, giro)
	var prof := 0.72
	var alto := 2.1
	var luzes: Array[Vector3] = []
	var em := func(local: Vector3) -> Vector3:
		return centro + b * local

	# A camara por dentro: fundo claro, teto, base e as duas laterais. Oca de
	# proposito — o produto mora ai dentro (`PrateleiraViva`), atras das portas
	# de vidro que ela mesma monta e abre.
	var frente := prof * 0.5
	KitModular.caixa_cor(sup, &"mercado_chapa", em.call(Vector3(0.0, alto * 0.5, -frente + 0.03)),
		Vector3(comprimento, alto, 0.06), INTERIOR_GELADEIRA, giro)
	KitModular.caixa_cor(sup, &"mercado_chapa", em.call(Vector3(0.0, alto - 0.05, 0.0)),
		Vector3(comprimento, 0.1, prof), ESTRUTURA_ESCURA, giro)
	KitModular.caixa_cor(sup, &"mercado_chapa",
		em.call(Vector3(0.0, Planograma.NIVEIS_GELADEIRA[0] * 0.5, 0.0)),
		Vector3(comprimento, Planograma.NIVEIS_GELADEIRA[0], prof), ESTRUTURA_ESCURA, giro)
	for sinal: float in [1.0, -1.0]:
		KitModular.caixa_cor(sup, &"mercado_chapa",
			em.call(Vector3(sinal * (comprimento * 0.5 - 0.03), alto * 0.5, 0.0)),
			Vector3(0.06, alto, prof), ESTRUTURA_ESCURA, giro)
	# Grades: chapa fina clara, com a beira de etiqueta na frente.
	for n in Planograma.NIVEIS_GELADEIRA.size():
		var y: float = Planograma.NIVEIS_GELADEIRA[n]
		if n > 0:
			KitModular.caixa_cor(sup, &"mercado_chapa",
				em.call(Vector3(0.0, y - 0.01, frente - 0.02 - Planograma.PROF_GELADEIRA * 0.5)),
				Vector3(comprimento - 0.1, 0.02, Planograma.PROF_GELADEIRA), GRADE_GELADEIRA,
				giro, PSXMesh.FACE_TOPO | PSXMesh.FACE_BASE | PSXMesh.FACE_FRENTE)
		_beira(sup, em.call(Vector3(0.0, y, frente - 0.012)), comprimento - 0.1, giro)

	# Os montantes entre as portas, na linha da frente.
	var largura_porta := comprimento / float(portas)
	for k in portas + 1:
		var dx := -comprimento * 0.5 + float(k) * largura_porta
		KitModular.caixa_cor(sup, &"mercado_chapa", em.call(Vector3(dx, alto * 0.5, frente)),
			Vector3(0.05, alto - 0.1, 0.05), ESTRUTURA_ESCURA, giro)
	for k in portas:
		var dx := -comprimento * 0.5 + (float(k) + 0.5) * largura_porta
		luzes.append(em.call(Vector3(dx, 1.7, frente - 0.25)))
	# O tubo de luz atras de cada montante, o que faz a geladeira brilhar.
	for k in portas + 1:
		var dx := -comprimento * 0.5 + float(k) * largura_porta
		KitModular.caixa_cor(sup, &"mercado_luz", em.call(Vector3(dx, 1.05, frente - 0.05)),
			Vector3(0.025, 1.7, 0.025), Color("eef6ff"), giro)

	# Testeira iluminada em cima, onde vai o nome da secao.
	KitModular.caixa_cor(sup, &"mercado_luz",
		centro + b * Vector3(0.0, alto - 0.12, prof * 0.5 + FOLGA_PAINEL),
		Vector3(comprimento - 0.06, 0.2, 0.03), Color("dbe8ee"), giro)

	_solido(colisao, centro + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(comprimento, alto, prof), giro)
	return luzes


# --- caixa e balcao ---------------------------------------------------------

## Balcao do caixa, com registradora e vitrine quente.
##
## `giro` aponta a frente do balcao, o lado onde o cliente para.
static func balcao(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, comprimento: float, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var prof := 0.68

	KitModular.caixa_cor(sup, &"mercado_chapa",
		centro + Vector3(0.0, ALTURA_BALCAO * 0.5, 0.0),
		Vector3(comprimento, ALTURA_BALCAO, prof), Color("b9bcb8"), giro)
	# Tampo em tom quente, o unico da loja: e ele que marca onde fica o atendente.
	KitModular.caixa_cor(sup, &"tabua",
		centro + Vector3(0.0, ALTURA_BALCAO + 0.02, 0.0),
		Vector3(comprimento + 0.08, 0.05, prof + 0.08), Color("8f7a5c"), giro)
	KitModular.caixa_cor(sup, &"mercado_chapa", centro + Vector3(0.0, 0.055, 0.0),
		Vector3(comprimento + 0.02, 0.11, prof - 0.1), RODAPE_LOJA, giro)

	# Registradora: o operador fica atras do balcao (-Z local), o cliente na
	# frente (+Z). Teclado inclinado e visor grande para quem opera; o visor
	# pequeno de total, no poste, para quem paga.
	var reg := centro + b * Vector3(comprimento * 0.5 - 0.42, 0.0, -0.06)
	KitModular.caixa_cor(sup, &"mercado_chapa", reg + Vector3(0.0, ALTURA_BALCAO + 0.12, 0.0),
		Vector3(0.38, 0.15, 0.36), Color("4f5250"), giro)
	# Gaveta de dinheiro, com a frente do lado do operador.
	KitModular.caixa_cor(sup, &"mercado_chapa", reg + b * Vector3(0.0, ALTURA_BALCAO + 0.08, -0.185),
		Vector3(0.34, 0.07, 0.02), Color("3a3c3b"), giro)
	KitModular.caixa_livre(sup, &"mercado_chapa", reg + b * Vector3(0.0, ALTURA_BALCAO + 0.215, -0.07),
		Vector3(0.32, 0.04, 0.2), b * Basis(Vector3.RIGHT, 0.32), Color("2f3130"))
	for linha in 4:
		for col in 6:
			KitModular.caixa_cor(sup, &"mercado_chapa", reg + b * Vector3(-0.125 + float(col) * 0.05,
				ALTURA_BALCAO + 0.215 + 0.03 * float(linha) * 0.33,
				-0.14 + float(linha) * 0.042), Vector3(0.036, 0.018, 0.03),
				Color("d8d4c8") if col < 5 else Color("c8574a"), giro)
	KitModular.caixa_cor(sup, &"mercado_luz",
		reg + b * Vector3(0.0, ALTURA_BALCAO + 0.3, 0.1),
		Vector3(0.24, 0.1, 0.03), Color("9fd6c0"), giro + PI)
	# O visor do cliente, num poste, olhando o salao.
	KitModular.caixa_cor(sup, &"mercado_chapa", reg + b * Vector3(0.14, ALTURA_BALCAO + 0.3, 0.16),
		Vector3(0.025, 0.2, 0.025), Color("3a3c3b"), giro)
	KitModular.caixa_cor(sup, &"mercado_luz",
		reg + b * Vector3(0.14, ALTURA_BALCAO + 0.42, 0.17),
		Vector3(0.13, 0.05, 0.03), Color("7fe0a0"), giro)

	# Bandeja de moeda e o pote de canudo, os dois detalhes que sempre existem.
	KitModular.caixa_cor(sup, &"mercado_chapa",
		centro + b * Vector3(comprimento * 0.5 - 0.86, ALTURA_BALCAO + 0.06, 0.1),
		Vector3(0.2, 0.03, 0.14), Color("6a6d6a"), giro)
	KitModular.caixa_cor(sup, &"mercado_chapa",
		centro + b * Vector3(-comprimento * 0.5 + 0.3, ALTURA_BALCAO + 0.13, 0.0),
		Vector3(0.1, 0.17, 0.1), Color("c8ccc4"), giro)

	_solido(colisao, centro + Vector3(0.0, ALTURA_BALCAO * 0.5, 0.0),
		Vector3(comprimento, ALTURA_BALCAO + 0.2, prof), giro)


## Vitrine quente do balcao, onde ficam os salgados. Devolve a posicao da luz.
##
## E a unica luz quente da loja. Existe para o balcao nao virar mais um bloco
## branco: uma fonte alaranjada num canto de sala toda branca marca o lugar.
static func caixa_quente(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float) -> Vector3:
	var b := Basis(Vector3.UP, giro)
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, 0.06, 0.0),
		Vector3(0.62, 0.12, 0.44), Color("8e918e"), giro)
	KitModular.caixa_cor(sup, &"vitrine_loja", centro + Vector3(0.0, 0.32, 0.0),
		Vector3(0.58, 0.4, 0.4), Color("f0d8a8"), giro)
	# Duas bandejas com produto dentro do vidro.
	for k in 2:
		KitModular.caixa_cor(sup, &"tabua",
			centro + b * Vector3(0.0, 0.2 + float(k) * 0.16, 0.0),
			Vector3(0.5, 0.06, 0.32), Color("c9a25e"), giro)
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, 0.54, 0.0),
		Vector3(0.62, 0.06, 0.44), Color("8e918e"), giro)
	_solido(colisao, centro + Vector3(0.0, 0.3, 0.0), Vector3(0.66, 0.6, 0.48))
	return centro + Vector3(0.0, 0.36, 0.0)


## Maquina de cafe, ao lado do balcao.
static func maquina_cafe(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.42, 0.0),
		Vector3(0.5, 0.84, 0.5), Color("54575a"), giro)
	KitModular.caixa_cor(sup, &"mercado_luz", base + b * Vector3(0.0, 0.62, 0.26),
		Vector3(0.3, 0.2, 0.03), Color("c8dcd4"), giro)
	KitModular.caixa_cor(sup, &"metal", base + b * Vector3(0.0, 0.3, 0.2),
		Vector3(0.24, 0.22, 0.12), Color("2e3032"), giro)
	_solido(colisao, base + Vector3(0.0, 0.42, 0.0), Vector3(0.52, 0.84, 0.52))


# --- vitrine e revistas -----------------------------------------------------

## Revisteiro inclinado sob a janela da frente.
##
## Fica de proposito encostado no vidro: e onde a loja de verdade poe as
## revistas, para quem passa na rua ver gente em pe la dentro. Aqui nao ha
## ninguem em pe, e e justamente essa a graca.
static func revisteiro(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, comprimento: float, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	KitModular.caixa_cor(sup, &"mercado_chapa", centro + Vector3(0.0, 0.26, 0.0),
		Vector3(comprimento, 0.52, 0.42), ESTRUTURA, giro)

	# Tres niveis inclinados, cada um com a capa aparecendo.
	for nivel in 3:
		var y := 0.56 + float(nivel) * 0.32
		var z := -0.04 - float(nivel) * 0.09
		KitModular.caixa_cor(sup, &"mercado_chapa", centro + b * Vector3(0.0, y, z),
			Vector3(comprimento, 0.03, 0.3), ESTRUTURA_ESCURA, giro)
		KitModular.placa(sup, _prateleira(nivel + 1),
			centro + b * Vector3(0.0, y + 0.14, z + 0.07),
			Vector2(comprimento - 0.06, 0.28), giro, Color(1.0, 1.0, 1.0))

	_solido(colisao, centro + Vector3(0.0, 0.55, 0.0),
		Vector3(comprimento, 1.1, 0.5), giro)


## Pilha de cestas de compra, junto da entrada.
##
## Cinco cestas de plastico vermelho, uma dentro da outra, com as alcas de arame
## deitadas para os lados. Era uma pilha de cinco caixas maciças: de cima nao se
## via o fundo de nenhuma, e cesta que nao se ve por dentro nao e cesta — e e a
## peca que a F3 poe no braco do fregues.
static func cestas(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	for k in 5:
		var vermelho := Color("c0362c") if k % 2 == 0 else Color("b3322a")
		cesta(sup, base + Vector3(0.0, float(k) * 0.055, 0.0), giro + float(k) * 0.035,
			vermelho, k == 4)
	_solido(colisao, base + Vector3(0.0, 0.22, 0.0), Vector3(0.46, 0.44, 0.34))


## Uma cesta de compra, com o fundo em `base`. `alcas_em_pe`: as alcas de arame
## levantadas (a de cima da pilha, a que vai no braco); deitadas, as de baixo.
static func cesta(sup: Dictionary, base: Vector3, giro: float, cor: Color,
		alcas_em_pe: bool = false) -> void:
	var b := Basis(Vector3.UP, giro)
	var alto := 0.22
	var fundo := Vector2(0.34, 0.24)
	var boca := Vector2(0.42, 0.3)
	var parede := 0.012
	# Fundo.
	KitModular.caixa_cor(sup, &"mercado_plastico", base + Vector3(0.0, parede * 0.5, 0.0),
		Vector3(fundo.x, parede, fundo.y), cor.darkened(0.12), giro)
	# Quatro paredes abertas para fora: a cesta afunila, e e o afunilado que
	# deixa uma entrar na outra.
	for lado in 4:
		var em_x := lado < 2
		var s := -1.0 if lado % 2 == 0 else 1.0
		var larg := (fundo.y + boca.y) * 0.5 if em_x else (fundo.x + boca.x) * 0.5
		var afasta := ((boca.x - fundo.x) if em_x else (boca.y - fundo.y)) * 0.5
		var meio := ((fundo.x + boca.x) * 0.25) if em_x else ((fundo.y + boca.y) * 0.25)
		var inclina := atan2(afasta, alto) * s
		var local := Vector3(s * meio, alto * 0.5, 0.0) if em_x else Vector3(0.0, alto * 0.5, s * meio)
		var giro_parede := Basis(Vector3.FORWARD, inclina) if em_x 			else Basis(Vector3.RIGHT, -inclina)
		var tam := Vector3(parede, alto, larg) if em_x else Vector3(larg, alto, parede)
		KitModular.caixa_livre(sup, &"mercado_plastico", base + b * local, tam,
			b * giro_parede, cor)
		# Janelas vazadas da parede: tres faixas escuras, que de longe leem como
		# a grade da cesta.
		for f in 3:
			var y := 0.06 + float(f) * 0.05
			var recuo := afasta * (y / alto)
			var p := Vector3(s * (fundo.x * 0.5 + recuo + 0.004), y, 0.0) if em_x 				else Vector3(0.0, y, s * (fundo.y * 0.5 + recuo + 0.004))
			var t := Vector3(0.004, 0.022, larg * 0.78) if em_x else Vector3(larg * 0.78, 0.022, 0.004)
			KitModular.caixa_livre(sup, &"mercado_plastico", base + b * p, t,
				b * giro_parede, cor.darkened(0.55))
	# Borda grossa da boca, que e onde a mao pega.
	for lado in 4:
		var em_x := lado < 2
		var s := -1.0 if lado % 2 == 0 else 1.0
		var p := Vector3(s * boca.x * 0.5, alto, 0.0) if em_x else Vector3(0.0, alto, s * boca.y * 0.5)
		var t := Vector3(0.022, 0.02, boca.y + 0.02) if em_x else Vector3(boca.x + 0.02, 0.02, 0.022)
		KitModular.caixa_cor(sup, &"mercado_plastico", base + b * p, t, cor.lightened(0.05), giro)
	# Alcas de arame cromado, uma de cada lado comprido.
	for s: float in [-1.0, 1.0]:
		var pontos := PackedVector3Array()
		for k in 7:
			var a := PI * float(k) / 6.0
			var arco := Vector3(cos(a) * boca.x * 0.36, sin(a) * 0.14, 0.0)
			if not alcas_em_pe:
				# Tombada para fora, pendurada rente a parede: e assim que a
				# alca fica quando uma cesta entra na outra.
				arco = Vector3(arco.x, -arco.y * 0.7, s * (0.016 + arco.y * 0.12))
			pontos.append(base + b * (Vector3(0.0, alto + 0.012, s * boca.y * 0.5) + arco))
		Peca.tubo(sup, &"mercado_inox", pontos, 0.004, 5, Color.WHITE, false)

## Lixeira de tampa basculante.
static func lixeira(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.35, 0.0),
		Vector3(0.42, 0.7, 0.36), Color("7d807c"), giro)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.73, 0.0),
		Vector3(0.46, 0.06, 0.4), Color("54575a"), giro)
	_solido(colisao, base + Vector3(0.0, 0.35, 0.0), Vector3(0.44, 0.7, 0.38))


## Tapete de entrada. Escuro contra o piso quase branco, entao marca a soleira
## sem precisar de degrau.
static func tapete_entrada(sup: Dictionary, centro: Vector3,
		tamanho: Vector2, giro: float) -> void:
	KitModular.caixa_cor(sup, &"reboco", centro + Vector3(0.0, 0.008, 0.0),
		Vector3(tamanho.x, 0.016, tamanho.y), Color("53565a"), giro)


# --- iluminacao -------------------------------------------------------------

## Calha fluorescente dupla. Devolve a posicao da lampada.
##
## A luz da loja e o personagem principal do comodo: branca, chapada e sem
## sombra, o oposto de tudo que existe la fora. Por isso sao varias calhas em
## linha e nao uma lampada central.
static func calha(sup: Dictionary, teto: float, x: float, z: float,
		comprimento: float, giro: float = 0.0) -> Vector3:
	var centro := Vector3(x, teto - 0.07, z)
	# Material proprio, e fora da sombra (Interiores.SEM_SOMBRA). A lampada fica
	# sete centimetros abaixo da carcaca, e com a carcaca projetando, o forro em
	# volta de cada calha ganhava uma cunha preta que nenhuma luminaria de loja
	# faz: a luz de verdade sai dos tubos, que ficam por baixo dela.
	KitModular.caixa_cor(sup, &"mercado_calha", centro,
		Vector3(comprimento, 0.1, 0.3), Color("e4e8e4"), giro)
	# Os dois tubos, lado a lado.
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"mercado_luz",
			centro + Basis(Vector3.UP, giro) * Vector3(0.0, -0.055, lado * 0.07),
			Vector3(comprimento - 0.12, 0.03, 0.09), Color("f2f8f4"), giro)
	return centro + Vector3(0.0, -0.12, 0.0)


## Cartaz de corredor pendurado no teto, virado para os dois lados.
##
## Nao leva o nome da loja. Dentro da loja o nome ja e sabido, e repeti-lo em
## cada corredor faz o cenario parecer montado com as pecas que havia em vez de
## com as pecas certas.
## Um RECORTE da textura num painel, em vez da imagem inteira.
##
## `KitModular.placa` manda a UV de 0 a 1 e cobre o painel com a imagem toda.
## A placa de corredor precisa de uma FAIXA do atlas `mercado_secao`: tres
## placas com tres palavras diferentes, saindo de um material so — ou seja, de
## um lote de desenho so.
##
## Subdivide em `colunas` quads de proposito. A UV afim empena a imagem dentro
## de cada quad, e texto e o caso pior: com um quad so, a palavra sai torta de
## viés, que e como a placa antiga ja lia.
static func placa_recorte(sup: Dictionary, material: StringName, centro: Vector3,
		tamanho: Vector2, giro: float, cor: Color, uv0: Vector2, uv1: Vector2,
		colunas: int = 4) -> void:
	if not sup.has(material):
		sup[material] = PSXMesh.dados_vazios()
	var d: Dictionary = sup[material]
	var vs: PackedVector3Array = d["v"]
	var ns: PackedVector3Array = d["n"]
	var uvs: PackedVector2Array = d["uv"]
	var uvs2: PackedVector2Array = d["uv2"]
	var cs: PackedColorArray = d["c"]
	var idx: PackedInt32Array = d["i"]
	var base := Basis(Vector3.UP, giro)
	var frente := base * Vector3(0.0, 0.0, 1.0)
	var inicio := vs.size()
	for linha in 2:
		for coluna in colunas + 1:
			var u := float(coluna) / float(colunas)
			var v := float(linha)
			vs.append(centro + base * Vector3((u - 0.5) * tamanho.x,
				(v - 0.5) * tamanho.y, 0.0))
			ns.append(frente)
			# v cresce para baixo na imagem, como em `PSXMesh.placa_dados`.
			var uv := Vector2(lerpf(uv0.x, uv1.x, u), lerpf(uv1.y, uv0.y, v))
			uvs.append(uv)
			uvs2.append(uv)
			cs.append(cor)
	for coluna in colunas:
		var a := inicio + coluna
		var b := inicio + coluna + 1
		var c := inicio + colunas + 1 + coluna
		var e := inicio + colunas + 2 + coluna
		idx.append_array(PackedInt32Array([a, c, b, b, c, e]))
	d["v"] = vs
	d["n"] = ns
	d["uv"] = uvs
	d["uv2"] = uvs2
	d["c"] = cs
	d["i"] = idx


## Placa de corredor pendurada no teto. `variante` escolhe a faixa do atlas:
## 0 biscoitos, 1 bebidas, 2 mercearia — a mesma ordem das paletas de gondola.
static func placa_corredor(sup: Dictionary, teto: float, x: float, z: float,
		giro: float, cor: Color, variante: int = 0, faixas: int = 3) -> void:
	var v0 := float(variante % faixas) / float(faixas)
	var v1 := float(variante % faixas + 1) / float(faixas)
	for lado in 2:
		placa_recorte(sup, &"mercado_secao", Vector3(x, teto - 0.42, z),
			Vector2(1.1, 0.28), giro + (0.0 if lado == 0 else PI), cor,
			Vector2(0.0, v0), Vector2(1.0, v1))
	KitModular.caixa_cor(sup, &"mercado_chapa", Vector3(x, teto - 0.16, z),
		Vector3(0.02, 0.3, 0.02), ESTRUTURA_ESCURA)


# --- fachada ----------------------------------------------------------------

## Frente da loja vista da rua: vidro aceso, faixa de tres cores e o letreiro.
##
## `centro` fica na base, no meio da largura, e `giro` gira a frente para a rua.
## Existe para a loja ser reconhecivel de longe: na nevoa o jogador ve a mancha
## branca e as tres cores muito antes de ler qualquer coisa, e e isso que faz
## ele atravessar a rua para ver o que e.
static func fachada_loja(sup: Dictionary, centro: Vector3, largura: float,
		giro: float, vao: float = 1.8) -> void:
	var b := Basis(Vector3.UP, giro)
	var frente := b * Vector3(0.0, 0.0, 1.0)
	var alto := 2.62

	# A frente inteira avanca SALIENCIA sobre a calcada. Colada na fachada, o
	# vidro e a parede do predio caiam na mesma profundidade e a parede aparecia
	# atraves do vidro conforme o jogador andava.
	var plano := centro + frente * SALIENCIA

	# Laterais que fecham o volume. Sem elas da para ver por dentro da saliencia
	# pela quina, e a loja vira um painel solto na frente do predio.
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"metal",
			centro + frente * (SALIENCIA * 0.5) + b * Vector3(lado * largura * 0.5, alto * 0.5, 0.0),
			Vector3(0.12, alto, SALIENCIA), ESTRUTURA_ESCURA, giro)

	# Vidro do terreo em duas faixas: o vao do meio e da porta e nao pode receber
	# painel, senao a folha abre atras de uma parede.
	var sobra := (largura - vao) * 0.5
	for lado: float in [-1.0, 1.0]:
		if sobra < 0.3:
			continue
		KitModular.placa(sup, &"mercado_vidro",
			plano + b * Vector3(lado * (vao * 0.5 + sobra * 0.5), 1.24, 0.0),
			Vector2(sobra, 2.4), giro, Color("e6f2f4"), SUBDIVISAO_PAINEL)

		# Montantes de aluminio, que quebram o vidro em vaos.
		var montantes := maxi(1, int(round(sobra / 1.3)))
		for k in montantes + 1:
			var dx := lado * (vao * 0.5) + lado * sobra * (float(k) / float(montantes))
			KitModular.caixa_cor(sup, &"metal",
				plano + frente * 0.05 + b * Vector3(dx, 1.24, 0.0),
				Vector3(0.09, 2.4, 0.1), ESTRUTURA, giro)

	# Travessa sobre o vidro, fechando o topo do volume.
	KitModular.caixa_cor(sup, &"metal",
		centro + frente * (SALIENCIA * 0.5) + Vector3(0.0, alto - 0.07, 0.0),
		Vector3(largura + 0.12, 0.14, SALIENCIA + 0.06), ESTRUTURA, giro)

	# Faixa de tres cores acima do vidro. E o codigo visual da loja, e a essa
	# altura ja e a unica coisa legivel na nevoa.
	var cores: Array[Color] = [Color("e27a26"), Color("3a8c54"), Color("c63a34")]
	for i in cores.size():
		KitModular.caixa_cor(sup, &"metal",
			plano + frente * 0.02 + Vector3(0.0, alto + 0.11 + float(i) * 0.14, 0.0),
			Vector3(largura + 0.16, 0.14, 0.1), cores[i], giro)

	# Letreiro aceso, acima da faixa.
	KitModular.placa(sup, &"mercado_letreiro",
		plano + frente * 0.08 + Vector3(0.0, 3.62, 0.0),
		Vector2(minf(largura * 0.72, 3.4), 0.86), giro, Color.WHITE, SUBDIVISAO_PAINEL)

	# Marquise, projetada alem do letreiro.
	KitModular.caixa_cor(sup, &"metal",
		centro + frente * (SALIENCIA + 0.24) + Vector3(0.0, 3.1, 0.0),
		Vector3(largura + 0.24, 0.1, 0.76), ESTRUTURA_ESCURA, giro)


# --- bloco de servico -------------------------------------------------------
#
# Daqui para baixo e o lado de dentro da loja: garagem, corredor, banheiro e
# copa. O metodo nao muda — caixa lisa vestida por imagem —, mas a paleta e o
# oposto da do salao, e de proposito.
#
# O salao e branco, alto e sem sombra, e o comodo inteiro existe para ser
# desconfortavel de tao limpo. Os fundos sao verde de reparticao, concreto
# encardido e papelao. A troca acontece atravessando UMA porta, e e ela que
# conta ao jogador que ele saiu da parte da loja que e vitrine e entrou na parte
# que e trabalho. Sem essa virada, o bloco de servico seria so mais metro
# quadrado do mesmo lugar.

## Verde de oleo ate a meia altura, o acabamento de todo fundo de loja e de toda
## repartilcao publica brasileira dos anos noventa.
const VERDE_SERVICO := Color("8fa392")
const VERDE_SERVICO_ESCURO := Color("5f7566")
## Concreto queimado da garagem. Escuro o bastante para o portao de aco claro
## recortar contra ele.
const PISO_SERVICO := Color("6e6f6a")
const BRANCO_SANITARIO := Color("dfe3de")

## Pe direito da garagem. Abaixo dos 3,35 m em que comeca o primeiro andar do
## predio da fileira (a laje fica em cima dela na rua): com os 3,35 de quando a
## loja vivia dois mil metros acima da cidade, o forro da garagem atravessava o
## piso do apartamento de cima.
const ALTURA_GARAGEM := 2.98
## Altura util do vao do portao. Caminhao de entrega nao entra; carrinho de
## carga e palete entram, que e o que a loja recebe.
const ALTURA_PORTAO := 2.62
const LARGURA_PORTAO := 3.4

## Distancia entre o eixo da porta automatica e o eixo do portao da garagem, na
## FACHADA — na rua, e nao na planta.
##
## Nao e a mesma distancia de dentro, e nao pode ser. A planta do salao tem 11,4
## m de largura e a frente de loja desenhada no chunk tem 6,4: interior e
## fachada nunca coincidiram neste jogo, porque o interior vive dois mil metros
## acima da cidade. O que PRECISA coincidir e o par de numeros usado aqui — onde
## o ChunkBuilder desenha o portao na calcada, e para onde `Interiores` empurra
## o jogador quando ele sai por dentro dele. Os dois leem esta constante.
##
## Meia frente de loja (3,2) mais meio portao (1,7) mais um palmo de pilar.
const AFASTAMENTO_PORTAO := 5.2


# --- portao de enrolar ------------------------------------------------------

## Batente do portao da garagem: as duas guias laterais, a verga e o tambor.
##
## A FOLHA nao sai daqui quando o portao e o de dentro: ela sobe, entao precisa
## ser um no proprio, e quem a cria e o Interiores a partir do prop. Do lado da
## rua nao ha animacao nenhuma para fazer, e ai a folha entra fechada junto —
## e o que `com_folha` decide.
##
## `centro` fica na base, no meio do vao, e `giro` gira a frente do portao para
## quem olha.
static func portao_garagem(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, largura: float, giro: float,
		com_folha: bool = false, colide: bool = true) -> void:
	var b := Basis(Vector3.UP, giro)
	var meia := largura * 0.5

	# Guias laterais. Sao elas que fazem a folha ler como portao de enrolar e
	# nao como chapa apoiada no vao: o olho procura por onde a coisa corre.
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"metal",
			centro + b * Vector3(lado * (meia + 0.09), ALTURA_PORTAO * 0.5, 0.0),
			Vector3(0.18, ALTURA_PORTAO + 0.3, 0.22), ESTRUTURA_ESCURA, giro)

	# Verga e tambor onde a folha se enrola, logo acima do vao.
	KitModular.caixa_cor(sup, &"metal",
		centro + b * Vector3(0.0, ALTURA_PORTAO + 0.16, 0.0),
		Vector3(largura + 0.36, 0.32, 0.34), ESTRUTURA, giro)
	KitModular.caixa_cor(sup, &"metal",
		centro + b * Vector3(0.0, ALTURA_PORTAO + 0.16, -0.03),
		Vector3(largura + 0.1, 0.24, 0.26), ESTRUTURA_ESCURA, giro)

	# Soleira: a faixa de aco embutida no piso, gasta pela roda do carrinho.
	KitModular.caixa_cor(sup, &"metal", centro + b * Vector3(0.0, 0.015, 0.0),
		Vector3(largura + 0.2, 0.03, 0.3), RODAPE_LOJA, giro)

	# O vao e sempre fechado por colisao, com folha desenhada ou sem.
	#
	# Dentro da garagem a folha e um no que sobe, e mesmo assim o bloco fica: o
	# portao nunca chega a ficar aberto com o jogador do lado de dentro, porque
	# aciona-lo JA E sair para a rua. Sem este bloco, um portao meio aberto no
	# meio da animacao deixaria o jogador andar para fora da planta, e do outro
	# lado do vao nao ha cidade nenhuma — ha dois mil metros de ar.
	#
	# Na loja que existe na rua o portao abre DE VERDADE, e ai o bloco fixo e o
	# defeito: quem fecha o vao e a folha do `PortaoEnrolar`, com corpo proprio
	# subindo junto com ela. `colide` falso deixa o vao para ela.
	if colide:
		KitModular.solido(colisao, centro + Vector3(0.0, ALTURA_PORTAO * 0.5, 0.0),
			Vector3(largura, ALTURA_PORTAO, 0.24), giro)

	if com_folha:
		folha_portao(sup, centro, largura, giro, 0.0)


## A folha do portao, desenhada como imagem numa chapa fina.
##
## `subida` e quanto ela ja subiu, de 0 (fechada) a ALTURA_PORTAO (aberta). Do
## lado da rua entra sempre em 0; dentro da garagem quem move e o prop, e este
## desenho serve so ao portao que nunca abre.
static func folha_portao(sup: Dictionary, base: Vector3, largura: float,
		giro: float, subida: float) -> void:
	var altura := maxf(0.05, ALTURA_PORTAO - subida)
	KitModular.placa(sup, &"mercado_portao",
		base + Basis(Vector3.UP, giro) * Vector3(0.0, subida + altura * 0.5, 0.05),
		Vector2(largura, altura), giro, Color.WHITE, SUBDIVISAO_PAINEL)
	KitModular.caixa_cor(sup, &"metal",
		base + Vector3(0.0, subida + altura * 0.5, 0.0),
		Vector3(largura, altura, 0.08), Color("9ea19c"), giro)


# --- portas de dentro -------------------------------------------------------

## Batente de porta de servico: o marco de madeira em volta do vao.
##
## A folha nao vem daqui pelo mesmo motivo do portao — ela gira, entao e no. O
## marco fica porque um vao sem marco le como buraco na parede, e o bloco de
## servico tem quatro deles em vinte metros quadrados.
##
## `profundidade` e a espessura da parede mais um palmo. O marco tem de cobrir a
## parede de ponta a ponta: com os 16 cm de antes numa divisoria de 20, sobrava
## uma fresta de dois centimetros de cada lado, e olhando de esguelha pelo vao
## via-se o vazio entre as duas faces da parede.
static func batente(sup: Dictionary, centro: Vector3, largura: float,
		altura: float, giro: float, cor: Color = Color("7a6f5e"),
		profundidade: float = 0.16) -> void:
	var b := Basis(Vector3.UP, giro)
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"porta",
			centro + b * Vector3(lado * (largura * 0.5 + 0.04), altura * 0.5, 0.0),
			Vector3(0.08, altura + 0.08, profundidade), cor, giro)
	KitModular.caixa_cor(sup, &"porta",
		centro + b * Vector3(0.0, altura + 0.04, 0.0),
		Vector3(largura + 0.16, 0.08, profundidade), cor, giro)


## Placa de identificacao acima da porta, do tamanho em que se le a dois metros.
static func placa_porta(sup: Dictionary, centro: Vector3, giro: float,
		cor: Color) -> void:
	KitModular.caixa_cor(sup, &"mercado_chapa", centro, Vector3(0.42, 0.16, 0.03), cor, giro)
	KitModular.caixa_cor(sup, &"mercado_chapa",
		centro + Basis(Vector3.UP, giro) * Vector3(0.0, 0.0, 0.02),
		Vector3(0.3, 0.06, 0.02), Color("f2f4f0"), giro)


# --- banheiro ---------------------------------------------------------------

## Pia com espelho e saboneteira.
static func pia(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	# Cuba sobre coluna, que e o que se ve em banheiro de loja: nada de bancada.
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.36, 0.0),
		Vector3(0.2, 0.72, 0.2), BRANCO_SANITARIO, giro)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.78, 0.0),
		Vector3(0.52, 0.14, 0.42), BRANCO_SANITARIO, giro)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.86, 0.0),
		Vector3(0.4, 0.03, 0.3), Color("c8cec8"), giro)
	# Torneira.
	KitModular.caixa_cor(sup, &"metal", base + b * Vector3(0.0, 0.94, -0.14),
		Vector3(0.05, 0.16, 0.05), Color("b6bab6"), giro)
	KitModular.caixa_cor(sup, &"metal", base + b * Vector3(0.0, 1.0, -0.06),
		Vector3(0.04, 0.04, 0.14), Color("b6bab6"), giro)

	# Espelho. E a peca que faz o comodo virar banheiro num relance: retangulo
	# escuro na altura do rosto, com moldura fina.
	KitModular.caixa_cor(sup, &"metal", base + b * Vector3(0.0, 1.48, -0.16),
		Vector3(0.56, 0.66, 0.03), Color("55636a"), giro)
	KitModular.caixa_cor(sup, &"metal", base + b * Vector3(0.0, 1.48, -0.18),
		Vector3(0.62, 0.72, 0.02), ESTRUTURA, giro)

	KitModular.caixa_cor(sup, &"metal", base + b * Vector3(0.42, 1.16, -0.14),
		Vector3(0.12, 0.2, 0.09), Color("d4d8d2"), giro)
	KitModular.solido(colisao, base + Vector3(0.0, 0.5, 0.0),
		Vector3(0.56, 1.0, 0.46), giro)


## Vaso sanitario com caixa acoplada.
static func vaso(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	KitModular.caixa_cor(sup, &"metal", base + b * Vector3(0.0, 0.2, 0.04),
		Vector3(0.36, 0.4, 0.5), BRANCO_SANITARIO, giro)
	KitModular.caixa_cor(sup, &"metal", base + b * Vector3(0.0, 0.42, 0.06),
		Vector3(0.4, 0.06, 0.54), Color("cfd4ce"), giro)
	# Caixa acoplada, encostada na parede.
	KitModular.caixa_cor(sup, &"metal", base + b * Vector3(0.0, 0.55, -0.28),
		Vector3(0.42, 0.7, 0.2), BRANCO_SANITARIO, giro)
	KitModular.solido(colisao, base + Vector3(0.0, 0.35, 0.0),
		Vector3(0.44, 0.7, 0.7), giro)


## Divisoria de box: chapa que nao encosta no chao nem no teto.
##
## O vao embaixo e o detalhe que conta: divisoria inteira le como parede, e a
## diferenca entre um banheiro e uma sala pequena e justamente esse vao.
static func divisoria_box(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, comprimento: float, giro: float) -> void:
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, 1.15, 0.0),
		Vector3(comprimento, 1.7, 0.05), Color("9aa8a0"), giro)
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"metal",
			centro + Basis(Vector3.UP, giro) * Vector3(lado * (comprimento * 0.5 - 0.04), 0.15, 0.0),
			Vector3(0.06, 0.3, 0.06), ESTRUTURA_ESCURA, giro)
	KitModular.solido(colisao, centro + Vector3(0.0, 1.15, 0.0),
		Vector3(comprimento, 1.7, 0.08), giro)


## Secador de mao ou toalheiro de papel, na parede.
static func toalheiro(sup: Dictionary, centro: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	KitModular.caixa_cor(sup, &"metal", centro, Vector3(0.28, 0.36, 0.14),
		Color("c2c8c2"), giro)
	KitModular.caixa_cor(sup, &"metal", centro + b * Vector3(0.0, -0.2, 0.02),
		Vector3(0.2, 0.06, 0.12), Color("eef0ea"), giro)


# --- copa e escritorio ------------------------------------------------------

## Mesa de trabalho encostada na parede.
static func mesa_trabalho(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, comprimento: float, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var alto := 0.74
	var prof := 0.62
	# `mercado_chapa`, e nao `metal`: com albedo 62/255 o tampo claro saia preto
	# nas duas fidelidades e a mesa lia como bloco de granito (captura
	# a16_copa). Ver `kit_banheiro.gd`.
	KitModular.caixa_cor(sup, &"mercado_chapa", centro + Vector3(0.0, alto, 0.0),
		Vector3(comprimento, 0.05, prof), Color("b0b4ac"), giro)
	for lado: float in [-1.0, 1.0]:
		for atras: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"mercado_chapa",
				centro + b * Vector3(lado * (comprimento * 0.5 - 0.07),
					alto * 0.5, atras * (prof * 0.5 - 0.06)),
				Vector3(0.05, alto, 0.05), Color("8a8f8c"), giro)
	KitModular.solido(colisao, centro + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(comprimento, alto, prof), giro)


## Cadeira dobravel de metal, do tipo que toda copa tem uma.
static func cadeira(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.45, 0.0),
		Vector3(0.4, 0.04, 0.38), Color("9ea6a8"), giro)
	KitModular.caixa_cor(sup, &"metal", base + b * Vector3(0.0, 0.7, -0.17),
		Vector3(0.38, 0.44, 0.04), Color("9ea6a8"), giro)
	for lado: float in [-1.0, 1.0]:
		for atras: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"metal",
				base + b * Vector3(lado * 0.16, 0.22, atras * 0.16),
				Vector3(0.03, 0.45, 0.03), ESTRUTURA_ESCURA, giro)
	KitModular.solido(colisao, base + Vector3(0.0, 0.35, 0.0),
		Vector3(0.44, 0.7, 0.42), giro)


## Quadro de avisos de cortica, com os papeis pregados.
static func quadro_avisos(sup: Dictionary, centro: Vector3, largura: float,
		giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	KitModular.caixa_cor(sup, &"tabua", centro, Vector3(largura + 0.08, largura * 0.66 + 0.08, 0.05),
		Color("6d573c"), giro)
	KitModular.placa(sup, &"mercado_avisos", centro + b * Vector3(0.0, 0.0, 0.04),
		Vector2(largura, largura * 0.66), giro, Color.WHITE, SUBDIVISAO_PAINEL)


## Armario de vestiario, com as portas marcadas por vinco.
static func armario_vestiario(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, portas: int, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var largura_porta := 0.36
	var largura := largura_porta * float(portas)
	var alto := 1.82
	var prof := 0.42

	KitModular.caixa_cor(sup, &"mercado_chapa", centro + Vector3(0.0, alto * 0.5 + 0.1, 0.0),
		Vector3(largura, alto, prof), Color("8fa39a"), giro)
	# Pes, para o armario nao nascer do piso.
	KitModular.caixa_cor(sup, &"mercado_chapa", centro + Vector3(0.0, 0.05, 0.0),
		Vector3(largura - 0.06, 0.1, prof - 0.08), Color("5e6663"), giro)

	for k in portas:
		var dx := -largura * 0.5 + (float(k) + 0.5) * largura_porta
		# Vinco entre portas e o veneziano de cima, que e o que faz a chapa ler
		# como armario e nao como geladeira.
		KitModular.caixa_cor(sup, &"mercado_chapa",
			centro + b * Vector3(dx, alto * 0.5 + 0.1, prof * 0.5 + 0.01),
			Vector3(largura_porta - 0.03, alto - 0.06, 0.02), Color("7e948a"), giro)
		for linha in 3:
			KitModular.caixa_cor(sup, &"mercado_chapa",
				centro + b * Vector3(dx, alto - 0.18 - float(linha) * 0.08, prof * 0.5 + 0.03),
				Vector3(largura_porta - 0.12, 0.02, 0.02), Color("6e7773"), giro)
		KitModular.caixa_cor(sup, &"mercado_chapa",
			centro + b * Vector3(dx + largura_porta * 0.32, 0.92, prof * 0.5 + 0.03),
			Vector3(0.04, 0.1, 0.03), Color("c6ccc4"), giro)

	KitModular.solido(colisao, centro + Vector3(0.0, alto * 0.5 + 0.1, 0.0),
		Vector3(largura, alto + 0.2, prof), giro)


## Maquina de refrigerante da copa. Devolve a posicao da luz do visor.
##
## Vermelha, e a unica cor saturada do bloco de servico. Num corredor todo verde
## e cinza ela e o ponto para onde o olho vai, e e por isso que ela esta ali: e
## o marco que diz ao jogador onde ele esta quando volta da garagem.
static func maquina_refri(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> Vector3:
	var b := Basis(Vector3.UP, giro)
	var alto := 1.86
	KitModular.caixa_cor(sup, &"mercado_chapa", base + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(0.86, alto, 0.72), Color("a83029"), giro)
	KitModular.caixa_cor(sup, &"mercado_chapa", base + Vector3(0.0, alto - 0.05, 0.0),
		Vector3(0.9, 0.1, 0.76), Color("2f3234"), giro)
	# Visor iluminado com a lista de produto.
	KitModular.caixa_cor(sup, &"mercado_luz", base + b * Vector3(-0.06, 1.14, 0.37),
		Vector3(0.56, 1.06, 0.03), Color("e8d9b4"), giro)
	# Botoeira e a boca de retirada.
	for k in 4:
		KitModular.caixa_cor(sup, &"mercado_chapa",
			base + b * Vector3(0.32, 1.44 - float(k) * 0.14, 0.37),
			Vector3(0.1, 0.06, 0.03), Color("e0e4dc"), giro)
	KitModular.caixa_cor(sup, &"mercado_chapa", base + b * Vector3(0.0, 0.34, 0.34),
		Vector3(0.56, 0.3, 0.1), Color("2f3234"), giro)
	KitModular.solido(colisao, base + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(0.88, alto, 0.74), giro)
	return base + b * Vector3(-0.06, 1.14, 0.5)


## Balde de limpeza com espremedor e o cabo do rodo.
static func balde_mop(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	KitModular.caixa_cor(sup, &"mercado_plastico", base + Vector3(0.0, 0.18, 0.0),
		Vector3(0.44, 0.36, 0.34), Color("d9b430"), giro)
	KitModular.caixa_cor(sup, &"mercado_plastico", base + b * Vector3(0.0, 0.46, -0.06),
		Vector3(0.3, 0.2, 0.2), Color("c4a22c"), giro)
	# Cabo encostado, torto. Vertical demais le como poste.
	KitModular.caixa_livre(sup, &"tabua", base + Vector3(0.16, 0.72, 0.06),
		Vector3(0.04, 1.4, 0.04),
		Basis(Vector3.UP, giro) * Basis(Vector3.FORWARD, 0.16),
		Color("9c8460"))
	KitModular.solido(colisao, base + Vector3(0.0, 0.25, 0.0),
		Vector3(0.46, 0.5, 0.36), giro)


## Sacos de lixo pretos, amontoados.
static func sacos_lixo(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		quantos: int, giro: float) -> void:
	for k in quantos:
		var ang := giro + float(k) * 1.9
		var raio := 0.28 + float(k % 2) * 0.1
		var pos := base + Vector3(cos(ang) * raio, 0.0, sin(ang) * raio)
		var alto := 0.42 + float((k * 7) % 3) * 0.08
		KitModular.caixa_cor(sup, &"metal", pos + Vector3(0.0, alto * 0.5, 0.0),
			Vector3(0.44, alto, 0.42), Color("26282a"), ang)
		# No de cima: a ponta que fecha o saco.
		KitModular.caixa_cor(sup, &"metal", pos + Vector3(0.0, alto + 0.05, 0.0),
			Vector3(0.14, 0.12, 0.14), Color("1d1f21"), ang)
	KitModular.solido(colisao, base + Vector3(0.0, 0.3, 0.0),
		Vector3(0.9, 0.6, 0.9), giro)


## Grade de ventilacao na parede alta.
static func grade_ar(sup: Dictionary, centro: Vector3, tamanho: Vector2,
		giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	KitModular.caixa_cor(sup, &"metal", centro,
		Vector3(tamanho.x, tamanho.y, 0.1), Color("8d928c"), giro)
	var lamelas := maxi(3, int(tamanho.y / 0.09))
	for k in lamelas:
		var y := -tamanho.y * 0.5 + (float(k) + 0.5) * (tamanho.y / float(lamelas))
		KitModular.caixa_cor(sup, &"metal", centro + b * Vector3(0.0, y, 0.06),
			Vector3(tamanho.x - 0.06, 0.035, 0.03), Color("53585a"), giro)


## Bancada de copa: pia pequena, garrafa termica e caixa de cafe.
static func bancada_copa(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, comprimento: float, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var alto := 0.9
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(comprimento, alto, 0.58), Color("b4aa96"), giro)
	KitModular.caixa_cor(sup, &"tabua", centro + Vector3(0.0, alto + 0.025, 0.0),
		Vector3(comprimento + 0.06, 0.05, 0.62), Color("7d6a4e"), giro)
	# Cuba embutida.
	KitModular.caixa_cor(sup, &"metal", centro + b * Vector3(-comprimento * 0.28, alto + 0.03, 0.0),
		Vector3(0.42, 0.03, 0.38), Color("8e948e"), giro)
	KitModular.caixa_cor(sup, &"metal", centro + b * Vector3(-comprimento * 0.28, alto + 0.2, -0.2),
		Vector3(0.04, 0.26, 0.04), Color("b6bab6"), giro)
	# Garrafa termica e a caixa de cafe, os dois objetos que essa bancada sempre
	# tem. Sao seis caixas e mudam o comodo de "sala vazia" para "alguem passa a
	# noite aqui".
	KitModular.caixa_cor(sup, &"metal", centro + b * Vector3(comprimento * 0.16, alto + 0.19, 0.0),
		Vector3(0.16, 0.3, 0.16), Color("2f4c66"), giro)
	KitModular.caixa_cor(sup, &"metal", centro + b * Vector3(comprimento * 0.16, alto + 0.36, 0.0),
		Vector3(0.1, 0.06, 0.1), Color("c2452f"), giro)
	KitModular.caixa_cor(sup, &"tabua", centro + b * Vector3(comprimento * 0.34, alto + 0.12, 0.02),
		Vector3(0.2, 0.16, 0.14), Color("8a5f38"), giro)
	KitModular.solido(colisao, centro + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(comprimento, alto + 0.1, 0.6), giro)


# --- garagem ----------------------------------------------------------------

## Estante de deposito, cheia de caixa e engradado.
##
## Irma da gondola do salao e trabalha igual: a estrutura e caixa lisa e quem
## enche e a imagem. A diferenca esta na imagem — no deposito nada esta
## alinhado, e e isso que separa os dois comodos.
static func estante_estoque(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, comprimento: float, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var alto := 2.1
	var prof := 0.62

	# Montantes e travessas. Estante de deposito e vazada: sem os montantes
	# aparecendo, a imagem colada le como armario fechado.
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"metal",
			centro + b * Vector3(lado * comprimento * 0.5, alto * 0.5, 0.0),
			Vector3(0.08, alto, prof), Color("6b5a4c"), giro)
	for nivel in 5:
		KitModular.caixa_cor(sup, &"metal",
			centro + Vector3(0.0, float(nivel) * (alto / 4.0), 0.0),
			Vector3(comprimento, 0.05, prof), Color("6b5a4c"), giro)

	KitModular.placa(sup, &"mercado_estoque",
		centro + b * Vector3(0.0, alto * 0.5, prof * 0.5 - FOLGA_PAINEL),
		Vector2(comprimento - 0.1, alto - 0.08), giro, Color.WHITE, SUBDIVISAO_PAINEL)

	KitModular.solido(colisao, centro + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(comprimento, alto, prof), giro)


## Palete de madeira com uma pilha de caixa em cima.
static func palete(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		caixas: int, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	# Estrado: tres travessas e as tabuas por cima.
	for k in 3:
		KitModular.caixa_cor(sup, &"tabua",
			base + b * Vector3(0.0, 0.05, -0.44 + float(k) * 0.44),
			Vector3(1.14, 0.1, 0.12), Color("8a7452"), giro)
	KitModular.caixa_cor(sup, &"tabua", base + Vector3(0.0, 0.13, 0.0),
		Vector3(1.16, 0.06, 1.02), Color("9a8460"), giro)

	# Pilha, cada caixa um pouco girada. Alinhadas leem como render de catalogo.
	for k in caixas:
		var alto := 0.42
		var y := 0.16 + alto * 0.5 + float(k) * alto
		var desvio := float((k * 13) % 7 - 3) * 0.02
		var torto := giro + float((k * 7) % 5 - 2) * 0.05
		KitModular.caixa_cor(sup, &"mercado_papelao",
			base + Vector3(desvio, y, -desvio), Vector3(0.92, alto, 0.86),
			Color.WHITE, torto)

	var pilha := 0.16 + float(caixas) * 0.42
	KitModular.solido(colisao, base + Vector3(0.0, pilha * 0.5, 0.0),
		Vector3(1.16, pilha, 1.04), giro)


## Carrinho de carga encostado na parede.
static func carrinho_carga(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var inclinado := Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, 0.22)
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_livre(sup, &"metal",
			base + b * Vector3(lado * 0.2, 0.62, -0.12),
			Vector3(0.05, 1.24, 0.05), inclinado, Color("8d9298"))
	KitModular.caixa_livre(sup, &"metal", base + b * Vector3(0.0, 1.16, -0.24),
		Vector3(0.46, 0.05, 0.05), inclinado, Color("8d9298"))
	# Pa, deitada no chao.
	KitModular.caixa_cor(sup, &"metal", base + b * Vector3(0.0, 0.06, 0.18),
		Vector3(0.46, 0.03, 0.3), Color("70767c"), giro)
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"metal", base + b * Vector3(lado * 0.24, 0.12, -0.06),
			Vector3(0.06, 0.24, 0.24), Color("2b2d30"), giro)
	KitModular.solido(colisao, base + Vector3(0.0, 0.6, 0.0),
		Vector3(0.5, 1.2, 0.5), giro)


## Tambor de oleo, o movel de canto de garagem.
static func tambor(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		cor: Color, giro: float) -> void:
	KitModular.caixa_cor(sup, &"metal_enferrujado", base + Vector3(0.0, 0.44, 0.0),
		Vector3(0.56, 0.88, 0.56), cor, giro)
	for k in 2:
		KitModular.caixa_cor(sup, &"metal",
			base + Vector3(0.0, 0.28 + float(k) * 0.32, 0.0),
			Vector3(0.6, 0.05, 0.6), cor.darkened(0.25), giro)
	KitModular.solido(colisao, base + Vector3(0.0, 0.44, 0.0),
		Vector3(0.58, 0.88, 0.58), giro)


# --- computador do balcao ---------------------------------------------------

## Monitor de tubo, teclado e gabinete, sobre o balcao.
##
## Devolve o ponto onde fica a AREA de acionamento, um pouco a frente da tela: e
## de la que o jogador aperta para abrir a consulta em tela cheia.
##
## A tela nao e preta. Leva a textura da propria janela do sistema, acesa, para
## que de tres metros de distancia ja se veja que ha alguma coisa ligada no
## balcao — sem isso o monitor e um cubo escuro e ninguem chega perto para
## descobrir que ele funciona.
static func computador(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> Vector3:
	var b := Basis(Vector3.UP, giro)
	var bege := Color("cfc7ac")

	# Tubo: o corpo e um tronco, mas em caixa. Duas caixas encaixadas dao o
	# perfil do CRT sem custar a malha de um tronco de verdade.
	KitModular.caixa_cor(sup, &"mercado_chapa", base + b * Vector3(0.0, 0.19, -0.1),
		Vector3(0.36, 0.34, 0.3), bege.darkened(0.08), giro)
	KitModular.caixa_cor(sup, &"mercado_chapa", base + b * Vector3(0.0, 0.21, 0.06),
		Vector3(0.42, 0.4, 0.12), bege, giro)
	# Base giratoria.
	KitModular.caixa_cor(sup, &"mercado_chapa", base + b * Vector3(0.0, 0.02, -0.04),
		Vector3(0.34, 0.04, 0.28), bege.darkened(0.16), giro)

	# A tela, levemente recuada dentro da moldura.
	KitModular.placa(sup, &"mercado_terminal",
		base + b * Vector3(0.0, 0.22, 0.125), Vector2(0.32, 0.3), giro,
		Color.WHITE, SUBDIVISAO_PAINEL)
	# Led de energia.
	KitModular.caixa_cor(sup, &"mercado_secao", base + b * Vector3(0.14, 0.04, 0.13),
		Vector3(0.02, 0.02, 0.01), Color("6ae08a"), giro)

	# Teclado, na frente do monitor, inclinado como todo teclado da epoca.
	KitModular.caixa_livre(sup, &"mercado_chapa", base + b * Vector3(0.0, 0.015, 0.28),
		Vector3(0.42, 0.03, 0.16),
		b * Basis(Vector3.RIGHT, -0.1), bege)
	for linha in 4:
		KitModular.caixa_cor(sup, &"mercado_chapa",
			base + b * Vector3(0.0, 0.035, 0.235 + float(linha) * 0.03),
			Vector3(0.36, 0.008, 0.02), Color("9a9686"), giro)

	# Gabinete deitado sob o monitor — e ele que da a altura de mesa de caixa.
	KitModular.caixa_cor(sup, &"mercado_chapa", base + b * Vector3(-0.02, -0.06, -0.06),
		Vector3(0.46, 0.12, 0.42), bege.darkened(0.04), giro)
	KitModular.caixa_cor(sup, &"mercado_chapa", base + b * Vector3(0.1, -0.06, 0.15),
		Vector3(0.14, 0.02, 0.02), Color("6e6a5e"), giro)

	KitModular.solido(colisao, base + Vector3(0.0, 0.1, 0.0),
		Vector3(0.48, 0.5, 0.5), giro)
	return base + b * Vector3(0.0, 0.24, 0.38)


# --- o balcao atende ---------------------------------------------------------

## A carteira que o cliente larga no balcao.
##
## Torta de proposito, e por isso `giro` recebe um angulo quebrado de quem chama.
## Documento pousado no eixo do balcao le como item de cenario colocado ali pelo
## level design; documento atravessado le como uma coisa que alguem jogou. E a
## unica diferenca entre as duas leituras sao oito graus.
##
## Grande demais para a escala: doze por oito centimetros contra os oito e meio
## por cinco e meio de uma carteira de verdade. A 480 por 270, de pe atras de um
## balcao, uma carteira em tamanho real ocupa nove pixels e nao da para saber que
## e uma carteira — e o jogador precisa reconhece-la antes de pensar em aperta-la.
static func identidade_no_balcao(sup: Dictionary, centro: Vector3,
		giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	# Corpo do cartao, quase deitado.
	KitModular.caixa_cor(sup, &"metal", centro, Vector3(0.12, 0.006, 0.08),
		Color("e4e0d2"), giro)
	# Foto, no canto esquerdo. O retangulo escuro e o que faz o cartao ler como
	# documento e nao como guardanapo.
	KitModular.caixa_cor(sup, &"metal", centro + b * Vector3(-0.036, 0.004, 0.0),
		Vector3(0.032, 0.002, 0.044), Color("5a6068"), giro)
	# Faixa de titulo em cima e as duas linhas de dado ao lado da foto.
	KitModular.caixa_cor(sup, &"metal", centro + b * Vector3(0.0, 0.004, -0.03),
		Vector3(0.108, 0.002, 0.008), Color("8d99a6"), giro)
	for k in 2:
		KitModular.caixa_cor(sup, &"metal",
			centro + b * Vector3(0.014, 0.004, -0.006 + float(k) * 0.016),
			Vector3(0.056, 0.002, 0.005), Color("9aa0a4"), giro)
	# Codigo de barras, que e o que se passa no leitor.
	KitModular.caixa_cor(sup, &"metal", centro + b * Vector3(0.018, 0.004, 0.028),
		Vector3(0.05, 0.002, 0.012), Color("2b2d30"), giro)


## Leitor de codigo do balcao. Devolve onde fica a luz vermelha.
##
## E uma cunha com uma janela de vidro virada para cima, que e a forma de todo
## leitor de balcao desde os anos oitenta: inclinada porque o operador passa o
## codigo por cima dela sem levantar o braco.
##
## A janela nasce APAGADA, num vermelho escuro quase marrom. Quem acende e a
## lampada que o prop pendura em cima dela, e o contraste entre os dois estados e
## a resposta inteira do aparelho — nao ha mostrador, nao ha texto, nao ha nada
## alem do vidro passar de marrom a vermelho e apitar.
static func leitor_codigo(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> Vector3:
	var b := Basis(Vector3.UP, giro)
	var corpo := Color("3d4045")

	# Cunha: uma caixa baixa atras e uma inclinada na frente.
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.045, 0.0),
		Vector3(0.26, 0.09, 0.22), corpo, giro)
	KitModular.caixa_livre(sup, &"metal", base + b * Vector3(0.0, 0.105, 0.01),
		Vector3(0.24, 0.03, 0.2), b * Basis(Vector3.RIGHT, -0.22), corpo)

	# A janela de leitura, embutida na face inclinada.
	#
	# `metal`, e nao `mercado_vidro`. O vidro da loja e EMISSIVO — e o material da
	# camara fria e da vitrine, que brilham sozinhos — e uma janela emissiva fica
	# vermelha acesa o tempo inteiro, inclusive com o aparelho parado. O aviso
	# some: nao ha diferenca entre ligado e desligado para o jogador ver.
	#
	# Sem emissao, a janela e so uma chapa vermelho-escura, quase marrom, e quem
	# acende e a lampada que o prop pendura em cima dela. O contraste entre os
	# dois estados e a resposta inteira do aparelho.
	var janela := base + b * Vector3(0.0, 0.125, 0.016)
	KitModular.caixa_livre(sup, &"metal", janela,
		Vector3(0.19, 0.012, 0.15), b * Basis(Vector3.RIGHT, -0.22),
		Color("4a1512"))

	# Pe de borracha e o cabo saindo por tras. Duas caixas, e sao elas que tiram
	# o aparelho de "cubo apoiado" para "aparelho ligado em alguma coisa".
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.008, 0.0),
		Vector3(0.24, 0.016, 0.2), Color("212326"), giro)
	KitModular.caixa_cor(sup, &"metal", base + b * Vector3(0.0, 0.04, -0.14),
		Vector3(0.03, 0.03, 0.09), Color("1a1c1e"), giro)

	KitModular.solido(colisao, base + Vector3(0.0, 0.07, 0.0),
		Vector3(0.28, 0.14, 0.24), giro)
	return janela + b * Vector3(0.0, 0.06, 0.0)


# --- a frente envidracada -----------------------------------------------------
#
# A loja passou a existir na rua (PLANO_MERCADO_AAA, F1): o vidro que se ve da
# calcada e o mesmo que se ve do caixa. Por isso a vitrine e descrita UMA vez,
# em coordenada de planta, e cada lado a monta com o seu `em`: o comodo
# teleportado (MercadoBuilder, abertura) com a identidade e vidro fosco aceso,
# o predio da rua (PredioMercado) com a transformada do lote e vidro de verdade.

## Plano do vidro, em Z de planta: no meio da parede da frente, que vai de
## -PAREDE (a fachada) a 0 (o reboco de dentro).
const VIDRO_Z := -0.13
## Onde o vidro comeca e termina em Y de planta. Embaixo, o peitoril de granito
## que esconde o encontro com o piso; em cima, a travessa de aluminio.
const VIDRO_Y := Vector2(0.12, 2.46)
## A calcada fica um degrau abaixo do piso da loja (KitFumaca.PISO_Y).
const CALCADA_Y := -(KitFumaca.PISO_Y - KitModular.ALTURA_MEIO_FIO)
## Maior vao entre montantes. Vidro de vitrine brasileira de 1998 e temperado de
## 8 mm em placas de ate 1,4 m; mais largo que isso, a loja le como galpao.
const VAO_MONTANTE := 1.35
const ALUMINIO := Color("b9bcb6")


## Monta a frente envidracada do salao. `em` leva da planta a quem desenha.
##
## `giro_vidro` diz para onde o painel olha: PI (para a rua) no vidro de
## verdade, que e desenhado dos dois lados pelo proprio shader; 0 (para dentro)
## no vidro fosco do comodo teleportado, que e superficie comum de um lado so.
##
## `base_y` e onde o peitoril encosta no passeio, em Y de planta. Na ladeira a
## calcada desce ao longo da fachada, e o granito tem de chegar ao ponto mais
## baixo dela: parado em CALCADA_Y, ele abria uma fresta para o vazio embaixo
## do vidro no lado de baixo da rua.
static func vitrine_loja(sup: Dictionary, colisao: Array[Dictionary],
		em: Transform3D, x0: float, x1: float, porta_x0: float, porta_x1: float,
		material_vidro: StringName, cor_vidro: Color, giro_vidro: float,
		com_colisao: bool, base_y: float = CALCADA_Y) -> void:
	var g0 := em.basis.get_euler().y
	var alto := VIDRO_Y.y - VIDRO_Y.x
	var meio_y := (VIDRO_Y.x + VIDRO_Y.y) * 0.5
	var trechos: Array[Vector2] = [Vector2(x0, porta_x0), Vector2(porta_x1, x1)]
	for tr: Vector2 in trechos:
		var larg := tr.y - tr.x
		if larg < 0.2:
			continue
		# Peitoril: granito escuro do piso da loja ate a calcada. Fecha o degrau
		# por fora e segura o vidro por dentro.
		KitModular.caixa_cor(sup, &"metal",
			em * Vector3((tr.x + tr.y) * 0.5, (base_y + VIDRO_Y.x) * 0.5, -0.125),
			Vector3(larg, VIDRO_Y.x - base_y, 0.25), RODAPE_LOJA, g0)
		# Placas de vidro entre montantes, todas da mesma largura: montante em
		# passo irregular denuncia que a fachada foi cortada para caber.
		var n := maxi(1, ceili(larg / VAO_MONTANTE))
		var passo := larg / float(n)
		for k in n:
			var cx := tr.x + passo * (float(k) + 0.5)
			KitModular.placa(sup, material_vidro,
				em * Vector3(cx, meio_y, VIDRO_Z), Vector2(passo - 0.03, alto),
				g0 + giro_vidro, cor_vidro, SUBDIVISAO_PAINEL)
		for k in n + 1:
			KitModular.caixa_cor(sup, &"metal",
				em * Vector3(tr.x + passo * float(k), meio_y, VIDRO_Z),
				Vector3(0.06, alto, 0.16), ALUMINIO, g0)
		if com_colisao:
			KitModular.solido(colisao,
				em * Vector3((tr.x + tr.y) * 0.5, (CALCADA_Y + VIDRO_Y.y + 0.1) * 0.5, -0.125),
				Vector3(larg, VIDRO_Y.y + 0.1 - CALCADA_Y, 0.25), g0)

	# Travessa de ponta a ponta, por cima do vidro e da porta.
	KitModular.caixa_cor(sup, &"metal",
		em * Vector3((x0 + x1) * 0.5, VIDRO_Y.y + 0.05, -0.13),
		Vector3(x1 - x0, 0.1, 0.22), ALUMINIO, g0)
	# Chapa de soleira da porta, rente ao piso: o aco escovado em que a folha
	# corre por baixo. E o que diz, sem texto, que ali o vidro abre.
	KitModular.caixa_cor(sup, &"metal",
		em * Vector3((porta_x0 + porta_x1) * 0.5, -0.01, -0.1),
		Vector3(porta_x1 - porta_x0 + 0.06, 0.02, 0.34), Color("8e918e"), g0)


# --- o balcao por dentro --------------------------------------------------------

## Parede de cigarro atras do caixa, pendurada na divisa. A frente olha para +Z
## local.
##
## E o fundo de todo caixa de loja brasileira de 1998, e a peca que diz "caixa"
## antes da registradora: ninguem mais vende cigarro na prateleira, so quem esta
## atras do balcao alcanca. Cada marca e uma CORRIDA de macos (tres a cinco da
## mesma cor lado a lado), e nao um maco por caixa: com um retangulo por maco
## sairiam 160 caixas, e a 480x270 o olho so le a corrida.
static func expositor_cigarro(sup: Dictionary, centro: Vector3,
		comprimento: float, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var alto := Planograma.CIGARRO_ALTO
	var prof := Planograma.CIGARRO_PROF
	var em := func(local: Vector3) -> Vector3:
		return centro + b * local
	# Caixa aberta na frente: fundo, teto, base e laterais. Os macos sao da
	# `PrateleiraViva`, em fileiras nos niveis do planograma.
	KitModular.caixa_cor(sup, &"mercado_chapa", em.call(Vector3(0.0, alto * 0.5, -prof * 0.5 + 0.01)),
		Vector3(comprimento, alto, 0.02), Color("2c2e31"), giro)
	for sinal: float in [1.0, -1.0]:
		KitModular.caixa_cor(sup, &"mercado_chapa",
			em.call(Vector3(sinal * (comprimento * 0.5 + 0.01), alto * 0.5, 0.0)),
			Vector3(0.02, alto, prof), Color("2c2e31"), giro)
	KitModular.caixa_cor(sup, &"mercado_chapa", em.call(Vector3(0.0, alto + 0.005, 0.0)),
		Vector3(comprimento + 0.04, 0.02, prof), Color("2c2e31"), giro)
	# Testeira acesa com o nome das marcas.
	KitModular.caixa_cor(sup, &"mercado_luz", em.call(Vector3(0.0, alto + 0.07, prof * 0.5 - 0.02)),
		Vector3(comprimento, 0.1, 0.04), Color("e8e2cf"), giro)
	var passo := (alto - 0.08) / float(Planograma.CIGARRO_FILEIRAS)
	for f in Planograma.CIGARRO_FILEIRAS:
		var y := 0.04 + passo * float(f)
		KitModular.caixa_cor(sup, &"mercado_chapa", em.call(Vector3(0.0, y - 0.006, 0.0)),
			Vector3(comprimento, 0.012, prof), Color("3a3c40"), giro)
		# Regua de preco na beira de cada fileira.
		_beira(sup, em.call(Vector3(0.0, y + 0.005, prof * 0.5 + 0.006)), comprimento - 0.02, giro)


## Baleiro de balcao: tres degraus de chiclete e bala, e o pote de pirulito.
##
## Fica do lado do CLIENTE, entre ele e a registradora, que e onde toda loja
## poe: e a compra de impulso de quem ja esta com a carteira na mao.
static func expositor_balas(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var cores: Array[Color] = [Color("e2463c"), Color("f2c53d"), Color("3c8fd6"),
		Color("58b05a"), Color("e87fb0"), Color("f08a2a")]
	for degrau in 3:
		var y := 0.04 + float(degrau) * 0.07
		var z := 0.07 - float(degrau) * 0.07
		KitModular.caixa_cor(sup, &"mercado_chapa", base + b * Vector3(0.0, y, z),
			Vector3(0.46, 0.08, 0.08), Color("d6d8d4"), giro)
	# Pote de pirulito: o vidro e o que da o brilho, e os palitos saindo por cima
	# sao o que o faz ler como pirulito e nao como pote de moeda.
	var pote := base + b * Vector3(0.3, 0.0, 0.02)
	KitModular.caixa_cor(sup, &"vitrine_loja", pote + Vector3(0.0, 0.1, 0.0),
		Vector3(0.14, 0.2, 0.14), Color("c9d6d8"), giro)
	for k in 4:
		KitModular.caixa_cor(sup, &"mercado_plastico",
			pote + b * Vector3(-0.03 + float(k % 2) * 0.06, 0.24, -0.02 + float(k >> 1) * 0.04),
			Vector3(0.035, 0.035, 0.035), cores[k], giro)
	KitModular.solido(colisao, base + Vector3(0.05, 0.14, 0.0), Vector3(0.62, 0.28, 0.3), giro)


## Freezer horizontal de sorvete, encostado no vidro da frente.
##
## A tampa e de vidro de correr, e por baixo dela aparece o sorvete. E a unica
## peca da loja que se ve de CIMA, e por isso a tampa leva a emissao do vidro da
## loja: sem luz propria, o freezer visto do alto e uma caixa branca.
static func freezer_sorvete(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, comprimento: float, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var alto := 0.84
	var prof := 0.68
	KitModular.caixa_cor(sup, &"mercado_chapa", base + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(comprimento, alto, prof), Color("eceeea"), giro)
	# Faixa da marca na frente: azul com filete vermelho, a cara do freezer de
	# sorveteria de 1998.
	KitModular.caixa_cor(sup, &"mercado_chapa", base + b * Vector3(0.0, 0.46, prof * 0.5 + 0.004),
		Vector3(comprimento - 0.1, 0.22, 0.01), Color("1f4f9c"), giro, PSXMesh.FACE_FRENTE)
	KitModular.caixa_cor(sup, &"mercado_chapa", base + b * Vector3(0.0, 0.34, prof * 0.5 + 0.006),
		Vector3(comprimento - 0.1, 0.03, 0.01), Color("d8322a"), giro, PSXMesh.FACE_FRENTE)
	KitModular.caixa_cor(sup, &"mercado_chapa", base + Vector3(0.0, 0.05, 0.0),
		Vector3(comprimento - 0.04, 0.1, prof - 0.06), RODAPE_LOJA, giro)
	# O sorvete, visto pelo vidro: potes e picoles em fileiras de cor.
	var cores: Array[Color] = [Color("f4d27a"), Color("7a4a2e"), Color("e98aa8"),
		Color("f3f0e6"), Color("6fbf6a"), Color("e8a13a")]
	var n := maxi(3, int(comprimento / 0.24))
	for k in n:
		var x := -comprimento * 0.5 + 0.1 + (comprimento - 0.2) * (float(k) + 0.5) / float(n)
		for fileira in 2:
			KitModular.caixa_cor(sup, &"mercado_plastico",
				base + b * Vector3(x, alto - 0.12, -0.14 + float(fileira) * 0.28),
				Vector3((comprimento - 0.2) / float(n) - 0.03, 0.08, 0.24),
				cores[(k + fileira * 3) % cores.size()], giro, PSXMesh.FACE_TOPO)
	# Tampa de vidro, em duas folhas desencontradas.
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"vitrine_loja",
			base + b * Vector3(lado * comprimento * 0.24, alto + 0.012 + (0.012 if lado > 0 else 0.0), 0.0),
			Vector3(comprimento * 0.52, 0.012, prof - 0.08), Color("b8d4dc"), giro)
	KitModular.caixa_cor(sup, &"mercado_chapa", base + Vector3(0.0, alto + 0.02, 0.0),
		Vector3(comprimento + 0.02, 0.03, prof + 0.02), Color("c9ccc8"), giro,
		PSXMesh.FACE_TODAS & ~PSXMesh.FACE_TOPO)
	KitModular.solido(colisao, base + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(comprimento, alto + 0.05, prof), giro)


# --- a sala do monitor ----------------------------------------------------------

## O monitor do circuito fechado e o videocassete que grava. Devolve o centro da
## tela, que e onde a F7 pendura as quatro cameras.
##
## Monitor de tubo de 14 polegadas, preto e branco, com a tela partida em quatro.
## Por baixo, o gravador de lapso de tempo — o VHS que grava um quadro por
## segundo e cabe vinte e quatro horas numa fita. E a unica memoria que a loja
## tem do que aconteceu nela, e e ela que "os de fora" nao conseguem enganar.
static func monitor_cftv(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> Vector3:
	var b := Basis(Vector3.UP, giro)
	var cinza := Color("5b5e5c")
	# Videocassete.
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.05, 0.0),
		Vector3(0.43, 0.1, 0.3), Color("202224"), giro)
	KitModular.caixa_cor(sup, &"mercado_secao", base + b * Vector3(0.1, 0.06, 0.151),
		Vector3(0.1, 0.022, 0.005), Color("5fe07a"), giro)
	KitModular.caixa_cor(sup, &"metal", base + b * Vector3(-0.08, 0.06, 0.151),
		Vector3(0.16, 0.012, 0.006), Color("0e0f10"), giro)
	# Tubo.
	var tubo := base + Vector3(0.0, 0.1, 0.0)
	KitModular.caixa_cor(sup, &"metal", tubo + b * Vector3(0.0, 0.17, -0.06),
		Vector3(0.3, 0.28, 0.26), cinza.darkened(0.12), giro)
	KitModular.caixa_cor(sup, &"metal", tubo + b * Vector3(0.0, 0.18, 0.08),
		Vector3(0.36, 0.34, 0.08), cinza, giro)
	# A tela acesa: fosforo esverdeado, partida em quatro por uma cruz escura.
	var tela := tubo + b * Vector3(0.0, 0.19, 0.122)
	KitModular.caixa_cor(sup, &"mercado_luz", tela, Vector3(0.27, 0.21, 0.006),
		Color("8fa89a"), giro)
	KitModular.caixa_cor(sup, &"metal", tela + b * Vector3(0.0, 0.0, 0.004),
		Vector3(0.27, 0.008, 0.004), Color("1a1c1b"), giro)
	KitModular.caixa_cor(sup, &"metal", tela + b * Vector3(0.0, 0.0, 0.004),
		Vector3(0.008, 0.21, 0.004), Color("1a1c1b"), giro)
	KitModular.solido(colisao, base + Vector3(0.0, 0.25, 0.0), Vector3(0.45, 0.5, 0.4), giro)
	return tela


## Camera do circuito, presa na parede alta. A lente aponta para +Z local,
## inclinada para baixo.
##
## O LED vermelho e o detalhe inteiro: camera sem LED le como caixa de luz de
## emergencia, e com ele o jogador sabe, do outro lado do salao, que esta sendo
## filmado.
static func camera_cftv(sup: Dictionary, pos: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var inclinada := b * Basis(Vector3.RIGHT, -0.42)
	KitModular.caixa_cor(sup, &"metal", pos + b * Vector3(0.0, 0.02, -0.12),
		Vector3(0.06, 0.1, 0.12), Color("8a8d8a"), giro)
	KitModular.caixa_livre(sup, &"metal", pos + b * Vector3(0.0, -0.02, 0.04),
		Vector3(0.1, 0.09, 0.24), inclinada, Color("d8d8d2"))
	KitModular.caixa_livre(sup, &"metal", pos + b * Vector3(0.0, -0.07, 0.16),
		Vector3(0.07, 0.06, 0.02), inclinada, Color("141516"))
	KitModular.caixa_livre(sup, &"mercado_secao", pos + b * Vector3(0.035, -0.02, 0.15),
		Vector3(0.016, 0.016, 0.01), inclinada, Color("ff3020"))


## Espelho convexo de canto. Ve-se o corredor de tras nele, pelo menos na
## intencao: o reflexo de verdade e da F5. Aqui ele e o disco prateado com borda
## preta que toda loja pendura na quina que o caixa nao enxerga.
static func espelho_convexo(sup: Dictionary, pos: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, 0.35)
	KitModular.caixa_livre(sup, &"metal", pos, Vector3(0.5, 0.5, 0.05), b, Color("26282a"))
	KitModular.caixa_livre(sup, &"mercado_inox", pos + b * Vector3(0.0, 0.0, 0.03),
		Vector3(0.42, 0.42, 0.03), b, Color("c6ccd0"))
	KitModular.caixa_livre(sup, &"mercado_inox", pos + b * Vector3(0.0, 0.0, 0.05),
		Vector3(0.28, 0.28, 0.02), b, Color("dfe4e6"))


## Cofre de chao, com o disco do segredo e a manopla.
static func cofre(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.26, 0.0),
		Vector3(0.46, 0.52, 0.44), Color("3c4a44"), giro)
	KitModular.caixa_cor(sup, &"metal", base + b * Vector3(0.0, 0.26, 0.223),
		Vector3(0.38, 0.44, 0.01), Color("33403a"), giro)
	KitModular.caixa_cor(sup, &"metal", base + b * Vector3(-0.06, 0.32, 0.235),
		Vector3(0.09, 0.09, 0.02), Color("b7b9b2"), giro)
	KitModular.caixa_cor(sup, &"metal", base + b * Vector3(0.1, 0.24, 0.24),
		Vector3(0.03, 0.12, 0.03), Color("a9aca5"), giro)
	KitModular.solido(colisao, base + Vector3(0.0, 0.26, 0.0), Vector3(0.48, 0.52, 0.46), giro)


## Arquivo de aco de quatro gavetas, bege de reparticao.
static func arquivo(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var alto := 1.32
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(0.47, alto, 0.62), Color("b9b29c"), giro)
	for g in 4:
		var y := 0.18 + float(g) * 0.31
		KitModular.caixa_cor(sup, &"metal", base + b * Vector3(0.0, y, 0.312),
			Vector3(0.43, 0.28, 0.006), Color("aca58f"), giro)
		KitModular.caixa_cor(sup, &"metal", base + b * Vector3(0.0, y + 0.07, 0.322),
			Vector3(0.14, 0.025, 0.02), Color("8d8a80"), giro)
		KitModular.caixa_cor(sup, &"metal", base + b * Vector3(0.0, y + 0.1, 0.318),
			Vector3(0.07, 0.035, 0.006), Color("ebe6d6"), giro)
	KitModular.solido(colisao, base + Vector3(0.0, alto * 0.5, 0.0), Vector3(0.48, alto, 0.64), giro)


# --- a garagem e o estoque ------------------------------------------------------

## Botoeira do portao: sobe, para, desce. Presa na parede ao lado do vao.
static func botoeira(sup: Dictionary, centro: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	KitModular.caixa_cor(sup, &"metal", centro, Vector3(0.12, 0.24, 0.07),
		Color("9ea19c"), giro)
	var cores: Array[Color] = [Color("2f2f2f"), Color("c8342c"), Color("2f2f2f")]
	for k in 3:
		KitModular.caixa_cor(sup, &"metal",
			centro + b * Vector3(0.0, 0.07 - float(k) * 0.07, 0.04),
			Vector3(0.05, 0.04, 0.02), cores[k], giro)
	# O conduite descendo do tambor. Sem ele a caixa e um enfeite colado.
	KitModular.caixa_cor(sup, &"metal", centro + b * Vector3(0.0, 0.62, -0.01),
		Vector3(0.025, 1.0, 0.025), Color("8a8d88"), giro)


## Palete de bebida: engradados empilhados em camadas, com as tampinhas
## aparecendo por cima.
##
## Cada camada sao DUAS fileiras de engradado, e nao um por caixa: 48 caixas
## numa pilha que so se ve de passagem pelo corredor. A cor e a da marca — o
## vermelho do refrigerante, o verde do guarana, o amarelo da cerveja —, e e
## ela que diz "bebida" antes da forma.
static func palete_bebida(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, camadas: int, giro: float, cor: Color) -> void:
	var b := Basis(Vector3.UP, giro)
	for k in 3:
		KitModular.caixa_cor(sup, &"tabua",
			base + b * Vector3(0.0, 0.05, -0.44 + float(k) * 0.44),
			Vector3(1.14, 0.1, 0.12), Color("8a7452"), giro)
	KitModular.caixa_cor(sup, &"tabua", base + Vector3(0.0, 0.13, 0.0),
		Vector3(1.16, 0.06, 1.02), Color("9a8460"), giro)
	var alto := 0.3
	for c in camadas:
		var y := 0.16 + alto * (float(c) + 0.5)
		for fileira: float in [-1.0, 1.0]:
			var desvio := float((c * 13 + int(fileira) * 5) % 5 - 2) * 0.012
			KitModular.caixa_cor(sup, &"metal",
				base + b * Vector3(desvio, y, fileira * 0.25),
				Vector3(1.08, alto - 0.02, 0.48), cor.darkened(0.08 * float(c % 2)), giro)
	# Tampinhas: a face de cima da ultima camada, escura e pontilhada pelo dither.
	KitModular.caixa_cor(sup, &"metal",
		base + Vector3(0.0, 0.16 + alto * float(camadas) + 0.012, 0.0),
		Vector3(1.02, 0.02, 0.94), Color("3a2a1c"), giro, PSXMesh.FACE_TOPO)
	var pilha := 0.16 + alto * float(camadas)
	KitModular.solido(colisao, base + Vector3(0.0, pilha * 0.5, 0.0),
		Vector3(1.16, pilha, 1.04), giro)
