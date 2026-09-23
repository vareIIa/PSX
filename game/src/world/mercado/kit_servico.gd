## Copa e escritorio: os moveis que o funcionario usa, com forma de movel.
##
## Por que este arquivo existe
## ---------------------------
## Nas capturas `a15_copa.png` e `a16_escritorio.png` os dois comodos liam como
## deposito de caixas cinzas. O motivo e o mesmo do banheiro (ver
## `kit_banheiro.gd`): a mobilia era `KitModular.caixa_cor` no material `metal`,
## que e 62/255 de albedo. Tudo que fosse tingido de claro saia escuro, e tudo
## tinha a mesma silhueta — um cubo.
##
## Mas aqui ha um segundo defeito, proprio destes comodos: a mobilia era GENERICA
## demais para dizer que comodo e aquele. Copa e escritorio tem a mesma planta,
## o mesmo forro e o mesmo piso; o que separa os dois e o que esta em cima da
## bancada. Por isso este kit gasta triangulos em objeto pequeno de uso —
## garrafa termica, caneca, maquina de cafe, cadeira giratoria — e nao em movel
## grande. Cinco objetos de mao dizem "alguem passa a noite aqui"; uma bancada
## maior nao diz nada.
##
## Orcamento: copa 3000 triangulos, escritorio 2600 (§10.3 do plano).
##
## Convencao: `base` no chao (ou `centro` no meio, quando dito), e a FRENTE olha
## para +Z antes do `giro`. Igual ao `KitMercado`.
class_name KitServico
extends RefCounted

## Formica da bancada e do armario: bege de loja, nao branco.
##
## Todos os tons deste arquivo foram BAIXADOS depois da captura a17: a lampada
## do comodo (energia 2,8, alcance 7,5) multiplica o albedo 236 dos materiais
## claros, e tinta acima de 0,80 estoura em um (memoria "cor de vertice corta em
## um"). Armario, frigobar e bebedouro sairam todos brancos e se fundiram num
## borrao. Movel de loja le como movel quando tem MEIO tom, nao tom cheio.
const FORMICA := Color("d9d2be")
const FORMICA_PORTA := Color("cdc4ae")
## Aco escovado da cuba, da torneira e do rodape.
const INOX := Color("c2c8ca")
const INOX_FUNDO := Color("949c9e")
## Plastico da cadeira, da caneca e do garrafao.
const PLASTICO_CLARO := Color("cfcfc8")
## Chapa pintada da maquina de cafe e do frigobar. Escuro de proposito: e o
## unico volume escuro dos dois comodos, e e ele que da profundidade.
const CHAPA := Color("6b7276")
const CHAPA_ESCURA := Color("3e4346")
const VIDRO_FORNO := Color("2a2e30")

const LADOS := 12


# --- bancada ----------------------------------------------------------------

## Bancada de copa: gabinete de formica com cuba de inox embutida, torneira de
## cano e rodape recuado.
##
## O rodape recuado e o detalhe que faz o gabinete assentar no piso em vez de
## flutuar: com a caixa descendo reta ate o chao, a linha de baixo do movel
## coincide com a linha do rodape da parede e o olho perde a profundidade.
static func bancada(sup: Dictionary, colisao: Array[Dictionary], centro: Vector3,
		comprimento: float, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var alto := 0.86
	var prof := 0.58

	# Corpo, levantado do chao pelo rodape.
	Peca.prisma(sup, &"mercado_formica", Transform3D(b, centro),
		Peca.retangulo_redondo(Vector2(comprimento, prof), 0.015, 1), 0.08, alto,
		FORMICA)
	Peca.prisma(sup, &"mercado_inox", Transform3D(b, centro + b * Vector3(0.0, 0.0, -0.03)),
		Peca.retangulo_redondo(Vector2(comprimento - 0.06, prof - 0.06), 0.01, 1),
		0.0, 0.08, INOX_FUNDO)
	# Tampo, com a beira saliente.
	Peca.prisma(sup, &"mercado_formica", Transform3D(b, centro),
		Peca.retangulo_redondo(Vector2(comprimento + 0.04, prof + 0.04), 0.02, 2),
		alto, alto + 0.035, FORMICA)

	# Portas: dois vincos verticais e um puxador de tubo em cada.
	var portas := maxi(1, int(comprimento / 0.5))
	for k in portas:
		var x := -comprimento * 0.5 + comprimento * (float(k) + 0.5) / float(portas)
		Peca.prisma(sup, &"mercado_formica", Transform3D(b, centro + b * Vector3(x, 0.0, 0.0)),
			Peca.retangulo_redondo(Vector2(comprimento / float(portas) - 0.03, prof + 0.012),
				0.01, 1), 0.12, alto - 0.05, FORMICA_PORTA)
		Peca.tubo(sup, &"mercado_inox", PackedVector3Array([
			centro + b * Vector3(x - 0.06, alto - 0.12, prof * 0.5 + 0.03),
			centro + b * Vector3(x + 0.06, alto - 0.12, prof * 0.5 + 0.03),
		]), 0.008, 6, INOX)

	# Cuba SOBREPOSTA, nao embutida. Nao e escolha de estilo: `Peca.prisma` nao
	# subtrai, e uma cuba afundada no tampo fica coberta pela propria laje do
	# tampo — na primeira foto a bancada saiu lisa, sem pia nenhuma. Cuba de
	# apoio, com a borda 4 cm acima do tampo, e o que a loja usa mesmo e o que a
	# ferramenta desenha: um torno sobe por fora, vinca na borda e desce por
	# dentro, como a cuba do banheiro.
	var cx := -comprimento * 0.28
	Peca.torno(sup, &"mercado_inox",
		Transform3D(b.scaled(Vector3(1.3, 1.0, 1.0)), centro + b * Vector3(cx, 0.0, 0.0)),
		PackedVector2Array([
			Vector2(0.0, alto + 0.036), Vector2(0.155, alto + 0.036),
			Vector2(0.155, alto + 0.036), Vector2(0.17, alto + 0.05),
			Vector2(0.175, alto + 0.075), Vector2(0.175, alto + 0.075),
			Vector2(0.165, alto + 0.082), Vector2(0.165, alto + 0.082),
			Vector2(0.15, alto + 0.06), Vector2(0.13, alto + 0.045),
			Vector2(0.05, alto + 0.04), Vector2(0.0, alto + 0.038),
		]), 14, INOX)
	Peca.cilindro(sup, &"mercado_inox",
		centro + b * Vector3(cx, alto + 0.041, 0.0), 0.022, 0.004, 8, Color("8e9698"))
	# Torneira de cano alto, atras da cuba. Nasce ACIMA do tampo: nascendo em
	# `alto` ela fica dentro da laje e desaparece.
	var zt := -prof * 0.5 + 0.12
	Peca.cilindro(sup, &"mercado_inox",
		centro + b * Vector3(cx, alto + 0.036, zt), 0.026, 0.06, 10, INOX)
	Peca.tubo(sup, &"mercado_inox", PackedVector3Array([
		centro + b * Vector3(cx, alto + 0.09, zt),
		centro + b * Vector3(cx, alto + 0.30, zt),
		centro + b * Vector3(cx, alto + 0.35, zt + 0.05),
		centro + b * Vector3(cx, alto + 0.34, zt + 0.13),
		centro + b * Vector3(cx, alto + 0.28, zt + 0.15),
	]), 0.013, 8, INOX)

	KitModular.solido(colisao, centro + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(comprimento, alto + 0.08, prof + 0.06), giro)


# --- objetos de uso ---------------------------------------------------------

## Garrafa termica de bico, com gargalo, bomba e alca.
##
## E a peca mais barata deste arquivo e a que rende mais: 140 triangulos que
## fazem a bancada ler como copa em uso.
static func garrafa_termica(sup: Dictionary, base: Vector3, giro: float,
		cor: Color = Color("2f4c66")) -> void:
	var b := Basis(Vector3.UP, giro)
	Peca.torno(sup, &"mercado_plastico", Transform3D(b, base),
		PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(0.085, 0.0), Vector2(0.085, 0.0),
			Vector2(0.09, 0.02), Vector2(0.09, 0.22), Vector2(0.075, 0.26),
			Vector2(0.05, 0.28), Vector2(0.05, 0.28), Vector2(0.05, 0.32),
		]), LADOS, cor)
	# Tampa de rosca e bomba.
	Peca.torno(sup, &"mercado_plastico", Transform3D(b, base),
		PackedVector2Array([
			Vector2(0.055, 0.31), Vector2(0.055, 0.36), Vector2(0.055, 0.36),
			Vector2(0.03, 0.38), Vector2(0.0, 0.385),
		]), LADOS, Color("c8402c"))
	# Bico, para o lado da frente.
	Peca.tubo(sup, &"mercado_plastico", PackedVector3Array([
		base + b * Vector3(0.0, 0.30, 0.04),
		base + b * Vector3(0.0, 0.295, 0.10),
		base + b * Vector3(0.0, 0.27, 0.11),
	]), 0.011, 6, Color("d8d8d2"))
	# Alca.
	Peca.tubo(sup, &"mercado_plastico", PackedVector3Array([
		base + b * Vector3(0.0, 0.26, -0.07),
		base + b * Vector3(0.0, 0.33, -0.13),
		base + b * Vector3(0.0, 0.24, -0.16),
		base + b * Vector3(0.0, 0.16, -0.10),
	]), 0.01, 6, cor.darkened(0.2))


## Caneca com alca. `base` no fundo dela.
static func caneca(sup: Dictionary, base: Vector3, giro: float, cor: Color) -> void:
	var b := Basis(Vector3.UP, giro)
	Peca.torno(sup, &"mercado_louca", Transform3D(b, base),
		PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(0.038, 0.0), Vector2(0.038, 0.0),
			Vector2(0.042, 0.012), Vector2(0.042, 0.09), Vector2(0.042, 0.09),
			Vector2(0.036, 0.088), Vector2(0.036, 0.02), Vector2(0.0, 0.016),
		]), 10, cor)
	Peca.tubo(sup, &"mercado_louca", PackedVector3Array([
		base + b * Vector3(0.04, 0.072, 0.0), base + b * Vector3(0.068, 0.062, 0.0),
		base + b * Vector3(0.068, 0.032, 0.0), base + b * Vector3(0.04, 0.024, 0.0),
	]), 0.007, 6, cor)


## Maquina de cafe de po: chapa escura, moedor em cima, bandeja de pingo e o
## copo debaixo do bico.
static func maquina_cafe(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var alto := 0.72
	# Tres volumes, e nao um com um "nicho" por dentro: `Peca.prisma` nao
	# subtrai, entao caixa dentro de caixa nao abre buraco — some. O vao do copo
	# aqui e o espaco VAZIO entre a base e a cabeca da maquina, que e como a
	# maquina de verdade e feita.
	var largura := Vector2(0.38, 0.38)
	# Base: bandeja de pingo e o apoio do copo.
	Peca.prisma(sup, &"mercado_chapa", Transform3D(b, base),
		Peca.retangulo_redondo(largura, 0.02, 2), 0.0, 0.10, CHAPA)
	Peca.prisma(sup, &"mercado_inox", Transform3D(b, base + b * Vector3(0.0, 0.0, 0.03)),
		Peca.retangulo_redondo(Vector2(0.24, 0.20), 0.01, 1), 0.10, 0.112, INOX)
	# Costas: a coluna que sobe atras do vao, rasa.
	Peca.prisma(sup, &"mercado_chapa", Transform3D(b, base + b * Vector3(0.0, 0.0, -0.10)),
		Peca.retangulo_redondo(Vector2(largura.x, 0.18), 0.02, 2), 0.10, 0.38, CHAPA)
	# Cabeca: volta a profundidade cheia, e e dela que sai o bico.
	Peca.prisma(sup, &"mercado_chapa", Transform3D(b, base),
		Peca.retangulo_redondo(largura, 0.02, 2), 0.38, alto, CHAPA)
	# Painel claro na cara da cabeca, com dois botoes. `mercado_luz` acesa aqui
	# estoura o comodo inteiro no MODERNO, entao o painel e so albedo claro.
	Peca.prisma(sup, &"mercado_chapa", Transform3D(b, base),
		Peca.retangulo_redondo(Vector2(0.26, largura.y + 0.014), 0.01, 1), 0.44,
		alto - 0.05, Color("cfd4d2"))
	for lado: float in [-0.07, 0.07]:
		Peca.cilindro(sup, &"mercado_plastico", base + b * Vector3(lado, 0.52, largura.y * 0.5 + 0.012),
			0.018, 0.012, 8, Color("c2452f") if lado < 0.0 else Color("7d8a6a"),
			true, false, b * Basis(Vector3.RIGHT, -PI * 0.5))
	# Bico, pendurado sob a cabeca, apontando para o copo.
	Peca.tubo(sup, &"mercado_inox", PackedVector3Array([
		base + b * Vector3(0.0, 0.38, 0.05), base + b * Vector3(0.0, 0.33, 0.05),
	]), 0.013, 6, INOX)
	# O copo de plastico no apoio. Vazio le como maquina desligada.
	Peca.torno(sup, &"mercado_plastico", Transform3D(b, base + b * Vector3(0.0, 0.112, 0.05)),
		PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(0.026, 0.0), Vector2(0.026, 0.0),
			Vector2(0.036, 0.075), Vector2(0.036, 0.075), Vector2(0.032, 0.073),
			Vector2(0.024, 0.006), Vector2(0.0, 0.004),
		]), 10, Color("f0f0ea"))
	# Moedor: cilindro de plastico fume em cima da cabeca.
	Peca.torno(sup, &"mercado_plastico", Transform3D(b, base + b * Vector3(0.0, alto, -0.02)),
		PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(0.12, 0.0), Vector2(0.12, 0.0),
			Vector2(0.12, 0.14), Vector2(0.10, 0.17), Vector2(0.10, 0.17),
			Vector2(0.0, 0.175),
		]), LADOS, Color("57504a"))
	KitModular.solido(colisao, base + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(0.4, alto, 0.42), giro)


## A mesma maquina, mas de piso: sobre um pedestal de chapa, como a do fim do
## balcao do salao.
##
## Existe porque a maquina de bancada tem 72 cm. Posta direto no chao, ela fica
## na altura do joelho e o jogador nao alcanca o botao — a de verdade vem com
## base fechada, que e onde ficam o galao de agua e o lixo do borra.
static func maquina_cafe_de_piso(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var pedestal := 0.82
	Peca.prisma(sup, &"mercado_chapa", Transform3D(b, base),
		Peca.retangulo_redondo(Vector2(0.42, 0.42), 0.02, 2), 0.06, pedestal, CHAPA)
	Peca.prisma(sup, &"mercado_chapa", Transform3D(b, base),
		Peca.retangulo_redondo(Vector2(0.38, 0.38), 0.01, 1), 0.0, 0.06, CHAPA_ESCURA)
	# Porta do armario embaixo, com puxador: pedestal liso le como caixote.
	Peca.prisma(sup, &"mercado_chapa", Transform3D(b, base + b * Vector3(0.0, 0.0, 0.008)),
		Peca.retangulo_redondo(Vector2(0.36, 0.42), 0.015, 1), 0.12, pedestal - 0.06,
		Color("7b8286"))
	Peca.tubo(sup, &"mercado_inox", PackedVector3Array([
		base + b * Vector3(0.12, 0.62, 0.225), base + b * Vector3(0.12, 0.42, 0.225),
	]), 0.009, 6, INOX)
	maquina_cafe(sup, colisao, base + Vector3(0.0, pedestal, 0.0), giro)
	KitModular.solido(colisao, base + Vector3(0.0, pedestal * 0.5, 0.0),
		Vector3(0.44, pedestal, 0.44), giro)


## Micro-ondas de bancada: porta de vidro escuro, puxador e painel.
static func microondas(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var tam := Vector3(0.48, 0.28, 0.36)
	Peca.prisma(sup, &"mercado_chapa", Transform3D(b, base),
		Peca.retangulo_redondo(Vector2(tam.x, tam.z), 0.015, 1), 0.0, tam.y,
		Color("aeb2ac"))
	# Porta: vidro escuro a esquerda, painel a direita.
	Peca.prisma(sup, &"mercado_chapa", Transform3D(b, base + b * Vector3(-0.07, 0.0, 0.0)),
		Peca.retangulo_redondo(Vector2(0.30, tam.z + 0.02), 0.01, 1), 0.03,
		tam.y - 0.03, VIDRO_FORNO)
	Peca.prisma(sup, &"mercado_chapa", Transform3D(b, base + b * Vector3(0.17, 0.0, 0.0)),
		Peca.retangulo_redondo(Vector2(0.11, tam.z + 0.016), 0.008, 1), 0.03,
		tam.y - 0.03, Color("b4b8b2"))
	Peca.tubo(sup, &"mercado_inox", PackedVector3Array([
		base + b * Vector3(0.08, 0.06, tam.z * 0.5 + 0.02),
		base + b * Vector3(0.08, tam.y - 0.06, tam.z * 0.5 + 0.02),
	]), 0.012, 6, Color("9ea4a4"))
	for pe: Vector3 in [Vector3(-0.2, 0.0, -0.14), Vector3(0.2, 0.0, -0.14),
			Vector3(-0.2, 0.0, 0.14), Vector3(0.2, 0.0, 0.14)]:
		Peca.cilindro(sup, &"mercado_plastico", base + b * pe, 0.012, 0.012, 6,
			Color("4a4e4e"))
	KitModular.solido(colisao, base + Vector3(0.0, tam.y * 0.5, 0.0), tam, giro)


## Frigobar: porta com puxador vertical e o vinco da borracha em volta.
static func frigobar(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var tam := Vector3(0.52, 0.84, 0.52)
	Peca.prisma(sup, &"mercado_chapa", Transform3D(b, base),
		Peca.retangulo_redondo(Vector2(tam.x, tam.z), 0.02, 2), 0.02, tam.y,
		Color("b4b8b0"))
	# Porta, um pouco a frente, com a borracha escura por fora.
	Peca.prisma(sup, &"mercado_chapa", Transform3D(b, base + b * Vector3(0.0, 0.0, 0.012)),
		Peca.retangulo_redondo(Vector2(tam.x - 0.01, tam.z), 0.02, 2), 0.09,
		tam.y - 0.02, Color("a6aaa2"))
	Peca.prisma(sup, &"mercado_chapa", Transform3D(b, base + b * Vector3(0.0, 0.0, 0.006)),
		Peca.retangulo_redondo(Vector2(tam.x - 0.005, tam.z + 0.004), 0.02, 2), 0.08,
		tam.y - 0.01, Color("70746e"))
	Peca.tubo(sup, &"mercado_inox", PackedVector3Array([
		base + b * Vector3(tam.x * 0.5 - 0.06, 0.52, tam.z * 0.5 + 0.03),
		base + b * Vector3(tam.x * 0.5 - 0.06, tam.y - 0.12, tam.z * 0.5 + 0.03),
	]), 0.013, 6, Color("a8aeae"))
	for pe: float in [-1.0, 1.0]:
		Peca.cilindro(sup, &"mercado_plastico",
			base + b * Vector3(pe * (tam.x * 0.5 - 0.05), 0.0, tam.z * 0.5 - 0.06),
			0.016, 0.02, 6, Color("46494a"))
	KitModular.solido(colisao, base + Vector3(0.0, tam.y * 0.5, 0.0), tam, giro)


## Bebedouro de garrafao: coluna, garrafao azul de cabeca para baixo e duas
## torneiras.
static func bebedouro(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var alto := 0.96
	Peca.prisma(sup, &"mercado_plastico", Transform3D(b, base),
		Peca.retangulo_redondo(Vector2(0.32, 0.32), 0.05, 2), 0.02, alto,
		Color("bec2bc"))
	# O nicho das torneiras, recuado e escuro.
	Peca.prisma(sup, &"mercado_plastico", Transform3D(b, base + b * Vector3(0.0, 0.0, 0.04)),
		Peca.retangulo_redondo(Vector2(0.22, 0.14), 0.02, 1), 0.52, 0.74,
		Color("5c6260"))
	for lado: float in [-0.055, 0.055]:
		Peca.tubo(sup, &"mercado_plastico", PackedVector3Array([
			base + b * Vector3(lado, 0.70, 0.10),
			base + b * Vector3(lado, 0.70, 0.17),
			base + b * Vector3(lado, 0.66, 0.18),
		]), 0.009, 6, Color("2d5c86") if lado < 0.0 else Color("c2452f"))
	Peca.prisma(sup, &"mercado_inox", Transform3D(b, base + b * Vector3(0.0, 0.0, 0.10)),
		Peca.retangulo_redondo(Vector2(0.20, 0.10), 0.01, 1), 0.50, 0.508, INOX_FUNDO)
	# Garrafao: gargalo para baixo, encaixado no topo.
	# Colar onde o gargalo encaixa: sem ele o garrafao le como balao num palito.
	Peca.torno(sup, &"mercado_plastico", Transform3D(b, base + Vector3(0.0, alto, 0.0)),
		PackedVector2Array([
			Vector2(0.10, -0.02), Vector2(0.10, 0.03), Vector2(0.10, 0.03),
			Vector2(0.05, 0.05),
		]), LADOS, Color("c8ccc8"))
	Peca.torno(sup, &"mercado_plastico", Transform3D(b, base + Vector3(0.0, alto, 0.0)),
		PackedVector2Array([
			Vector2(0.048, 0.02), Vector2(0.048, 0.07), Vector2(0.115, 0.12),
			Vector2(0.165, 0.22), Vector2(0.17, 0.40), Vector2(0.155, 0.50),
			Vector2(0.155, 0.50), Vector2(0.10, 0.525), Vector2(0.0, 0.53),
		]), LADOS, Color("7fa8bc"))
	KitModular.solido(colisao, base + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(0.34, alto + 0.5, 0.34), giro)


# --- cadeiras ---------------------------------------------------------------

## Cadeira de escritorio: base de cinco pontas com rodinha, coluna a gas,
## assento e encosto estofados.
##
## A base de cinco pontas e a silhueta que diz "escritorio" de longe, e e o que
## a cadeira de quatro pes de caixa nunca dizia.
static func cadeira_giratoria(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var altura_assento := 0.46
	for k in 5:
		var ang := TAU * float(k) / 5.0 + 0.3
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		Peca.tubo(sup, &"mercado_chapa", PackedVector3Array([
			base + b * (dir * 0.04 + Vector3(0.0, 0.07, 0.0)),
			base + b * (dir * 0.26 + Vector3(0.0, 0.055, 0.0)),
		]), 0.022, 6, CHAPA_ESCURA)
		Peca.cilindro(sup, &"mercado_plastico", base + b * (dir * 0.28 + Vector3(0.0, 0.03, 0.0)),
			0.028, 0.022, 8, Color("3a3d3e"), true, true,
			b * Basis(Vector3.FORWARD, PI * 0.5).rotated(Vector3.UP, ang))
	# Coluna a gas.
	Peca.torno(sup, &"mercado_inox", Transform3D(b, base + Vector3(0.0, 0.07, 0.0)),
		PackedVector2Array([
			Vector2(0.055, 0.0), Vector2(0.055, 0.10), Vector2(0.03, 0.12),
			Vector2(0.03, altura_assento - 0.12),
		]), 10, Color("b8bcbc"))
	# Assento: prisma de canto redondo, com a espuma acima da base de plastico.
	Peca.prisma(sup, &"mercado_plastico", Transform3D(b, base),
		Peca.retangulo_redondo(Vector2(0.44, 0.42), 0.08, 2), altura_assento - 0.08,
		altura_assento - 0.04, Color("41464a"))
	Peca.prisma(sup, &"mercado_plastico", Transform3D(b, base),
		Peca.retangulo_redondo(Vector2(0.46, 0.44), 0.09, 2), altura_assento - 0.04,
		altura_assento + 0.02, Color("2f3f4c"))
	# Encosto, inclinado para tras.
	Peca.tubo(sup, &"mercado_chapa", PackedVector3Array([
		base + b * Vector3(0.0, altura_assento - 0.02, -0.18),
		base + b * Vector3(0.0, altura_assento + 0.16, -0.24),
	]), 0.018, 6, CHAPA_ESCURA)
	Peca.prisma(sup, &"mercado_plastico",
		Transform3D(b * Basis(Vector3.RIGHT, 0.14), base + b * Vector3(0.0, altura_assento + 0.34, -0.22)),
		Peca.retangulo_redondo(Vector2(0.42, 0.09), 0.035, 2), -0.18, 0.18,
		Color("2f3f4c"))
	KitModular.solido(colisao, base + Vector3(0.0, 0.4, 0.0),
		Vector3(0.5, 0.8, 0.48), giro)


## Cadeira de plastico monobloco, a cadeira de copa do Brasil inteiro.
static func cadeira_plastica(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float, cor: Color = PLASTICO_CLARO) -> void:
	var b := Basis(Vector3.UP, giro)
	var h := 0.44
	# Assento levemente conico, com a beira caida: e a silhueta da monobloco.
	Peca.prisma(sup, &"mercado_plastico", Transform3D(b, base),
		Peca.retangulo_redondo(Vector2(0.42, 0.40), 0.07, 2), h, h + 0.022, cor)
	Peca.prisma(sup, &"mercado_plastico", Transform3D(b, base),
		Peca.retangulo_redondo(Vector2(0.44, 0.42), 0.08, 2), h - 0.03, h, cor.darkened(0.06))
	# Quatro pes conicos, abrindo para fora.
	for lx: float in [-1.0, 1.0]:
		for lz: float in [-1.0, 1.0]:
			Peca.tubo(sup, &"mercado_plastico", PackedVector3Array([
				base + b * Vector3(lx * 0.155, h, lz * 0.145),
				base + b * Vector3(lx * 0.195, 0.0, lz * 0.185),
			]), 0.018, 6, cor, false, PackedFloat32Array([0.021, 0.014]))
	# Encosto curvo: tres segmentos do tubo ja fazem a curva.
	Peca.tubo(sup, &"mercado_plastico", PackedVector3Array([
		base + b * Vector3(-0.16, h + 0.02, -0.17),
		base + b * Vector3(-0.17, h + 0.24, -0.22),
		base + b * Vector3(-0.15, h + 0.42, -0.24),
	]), 0.016, 6, cor)
	Peca.tubo(sup, &"mercado_plastico", PackedVector3Array([
		base + b * Vector3(0.16, h + 0.02, -0.17),
		base + b * Vector3(0.17, h + 0.24, -0.22),
		base + b * Vector3(0.15, h + 0.42, -0.24),
	]), 0.016, 6, cor)
	Peca.prisma(sup, &"mercado_plastico",
		Transform3D(b * Basis(Vector3.RIGHT, -0.12), base + b * Vector3(0.0, h + 0.33, -0.235)),
		Peca.retangulo_redondo(Vector2(0.34, 0.035), 0.016, 1), -0.10, 0.10, cor)
	KitModular.solido(colisao, base + Vector3(0.0, 0.42, 0.0),
		Vector3(0.46, 0.84, 0.44), giro)


# --- os comodos -------------------------------------------------------------

## Copa: bancada na parede leste, mesa e cadeiras no fundo, frigobar e
## bebedouro no canto.
##
## `x0..x1` e `z0..z1` sao as faces internas do reboco.
static func montar_copa(sup: Dictionary, colisao: Array[Dictionary],
		x0: float, x1: float, z0: float, z1: float) -> void:
	# O tampo corre de z0+1,05 a z0+2,95 (1,9 m de bancada, centro em z0+2,0).
	# Tudo que vai em cima dele mora nessa faixa: a maquina estava na quina e o
	# micro-ondas caia FORA do tampo, flutuando ao lado (captura a16_copa).
	var zc := z0 + 2.0
	bancada(sup, colisao, Vector3(x1 - 0.32, 0.0, zc), 1.9, -PI * 0.5)
	maquina_cafe(sup, colisao, Vector3(x1 - 0.32, 0.896, zc + 0.72), -PI * 0.5)
	microondas(sup, colisao, Vector3(x1 - 0.34, 0.896, zc + 0.2), -PI * 0.5)
	garrafa_termica(sup, Vector3(x1 - 0.30, 0.896, zc - 0.2), 0.4)
	caneca(sup, Vector3(x1 - 0.46, 0.896, zc - 0.34), 1.2, Color("d8d4c8"))
	caneca(sup, Vector3(x1 - 0.52, 0.896, zc - 0.22), -0.5, Color("2f6a5c"))

	frigobar(sup, colisao, Vector3(x0 + 0.34, 0.0, z1 - 0.38), PI)
	bebedouro(sup, colisao, Vector3(x0 + 0.24, 0.0, z0 + 0.6), PI * 0.5)
	# As cadeiras nao entram aqui: elas pertencem a MESA, que o `MercadoBuilder`
	# posiciona, e cadeira no meio do comodo bloqueia a passagem do funcionario.


## Escritorio: a cadeira giratoria virada para o monitor e o frigobar do
## gerente. O resto (mesa, cofre, arquivo, CFTV) segue no `KitMercado`.
static func montar_escritorio(sup: Dictionary, colisao: Array[Dictionary],
		x_mesa: float, z_mesa: float) -> void:
	# De frente para a mesa: giro 0 olha para +Z, e a mesa esta em +Z.
	cadeira_giratoria(sup, colisao, Vector3(x_mesa - 0.06, 0.0, z_mesa - 0.72), 0.12)


# --- bancada ----------------------------------------------------------------

static func bancada_bancada(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	# A maquina vai na ponta OPOSTA a cuba: em cima dela, a maquina esconde a
	# cuba e a foto mente dizendo que a bancada nao tem pia.
	bancada(sup, colisao, Vector3.ZERO, 1.9, 0.0)
	maquina_cafe(sup, colisao, Vector3(0.72, 0.896, 0.0), 0.0)
	garrafa_termica(sup, Vector3(0.24, 0.896, 0.0), 0.4)
	caneca(sup, Vector3(0.05, 0.896, 0.06), 1.2, Color("d8d4c8"))


static func bancada_eletro(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	frigobar(sup, colisao, Vector3(-0.6, 0.0, 0.0), 0.0)
	microondas(sup, colisao, Vector3(0.1, 0.9, 0.0), 0.0)
	bebedouro(sup, colisao, Vector3(0.75, 0.0, 0.0), 0.0)


static func bancada_cadeiras(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	cadeira_giratoria(sup, colisao, Vector3(-0.45, 0.0, 0.0), 0.2)
	cadeira_plastica(sup, colisao, Vector3(0.45, 0.0, 0.0), -0.3)
