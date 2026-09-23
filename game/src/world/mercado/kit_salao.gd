## Estufa de salgados, lixeira e o resto do balcao, com forma de coisa.
##
## Por que este arquivo existe
## ---------------------------
## `KitMercado.caixa_quente` monta a estufa com cinco caixas: base, vidro, duas
## bandejas e tampa. As bandejas sao caixas de 50 x 6 x 32 cm da cor do salgado,
## e o resultado e exatamente o que o usuario viu: "a estufa de salgados sao
## tabuas empilhadas". Nao ha erro de material aqui — o erro e que PRODUTO nao e
## superficie. Uma bandeja com quinze coxinhas nao e uma placa da cor de
## coxinha; e quinze objetos pequenos, cada um com a propria sombra, e e a
## sombra entre eles que diz que ali ha comida.
##
## O custo disso e uma coxinha de 32 triangulos. Quinze delas custam menos que
## uma gondola, e ficam a um metro do rosto do jogador, no unico ponto quente do
## salao — que e onde vale gastar.
##
## A lixeira e a maquina de cafe do salao sairam do `metal` escuro por outro
## motivo, o mesmo do banheiro: 62/255 de albedo faz qualquer tinta clara virar
## preto. Ver `kit_banheiro.gd`.
class_name KitSalao
extends RefCounted

## Aco da estufa e da lixeira.
const INOX := Color("c2c8ca")
const INOX_ESCURO := Color("848a8c")
## Massa frita: o tom que o dither nao mata. Mais claro que isso vira papel.
const FRITURA := Color("c98a3a")
const PAO_DE_QUEIJO := Color("e3c98a")
const PASTEL := Color("d9b05c")
## Plastico da lixeira: cinza de loja, nao o chumbo de antes.
const LIXEIRA := Color("989e98")

## Lados de um salgado. SEIS, e nao oito: a peca tem 4 cm e cabe em vinte pixels
## na tela, entao o lado a mais nao aparece — mas quinze coxinhas de oito lados
## custavam 1680 triangulos, mais que a estufa inteira. Com seis, a bandeja
## cheia sai por 720.
const LADOS_SALGADO := 6


# --- salgados ---------------------------------------------------------------

## Coxinha: gota de massa, ponta para cima.
##
## O perfil e o objeto todo: fundo redondo, barriga, e o bico. Com uma esfera no
## lugar dela a bandeja le como bandeja de ovo.
static func coxinha(sup: Dictionary, pos: Vector3, giro: float,
		escala: float = 1.0) -> void:
	Peca.torno(sup, &"mercado_produto",
		Transform3D(Basis(Vector3.UP, giro).scaled(Vector3(escala, escala, escala * 0.92)), pos),
		PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(0.028, 0.012), Vector2(0.034, 0.032),
			Vector2(0.026, 0.056), Vector2(0.012, 0.072), Vector2(0.0, 0.085),
		]), LADOS_SALGADO, FRITURA)


## Pao de queijo: bola achatada, com a base assentada.
static func pao_de_queijo(sup: Dictionary, pos: Vector3, escala: float = 1.0) -> void:
	Peca.esfera(sup, &"mercado_produto",
		Transform3D(Basis().scaled(Vector3(escala, escala * 0.78, escala)),
			pos + Vector3(0.0, 0.026 * escala, 0.0)),
		0.032, LADOS_SALGADO, 4, PAO_DE_QUEIJO)


## Pastel: retangulo frito, com a borda enrolada e a leve curva do oleo.
static func pastel(sup: Dictionary, pos: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	Peca.prisma(sup, &"mercado_produto", Transform3D(b, pos),
		Peca.retangulo_redondo(Vector2(0.13, 0.075), 0.012, 1), 0.0, 0.016, PASTEL)
	# A borda: dois cordoes nas pontas, que e o que diz "fechado com garfo".
	for lado: float in [-1.0, 1.0]:
		Peca.tubo(sup, &"mercado_produto", PackedVector3Array([
			pos + b * Vector3(lado * 0.062, 0.009, -0.03),
			pos + b * Vector3(lado * 0.062, 0.009, 0.03),
		]), 0.009, 5, PASTEL.darkened(0.12))


## Uma bandeja com produto: o que enche a estufa.
##
## `tipo`: 0 coxinha, 1 pao de queijo, 2 pastel. `quantos` conta as pecas, nao
## as fileiras — o sorteio decide a grade.
static func bandeja(sup: Dictionary, centro: Vector3, tamanho: Vector2,
		giro: float, tipo: int, semente: int, vazia_a_direita: float = 0.0) -> void:
	var b := Basis(Vector3.UP, giro)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	# A bandeja: chapa rasa com a beira levantada. E ela que faz o produto
	# assentar em vez de flutuar.
	Peca.prisma(sup, &"mercado_inox", Transform3D(b, centro),
		Peca.retangulo_redondo(tamanho, 0.015, 1), 0.0, 0.012, INOX)
	for lado in 4:
		var em_x := lado % 2 == 0
		var sinal := 1.0 if lado < 2 else -1.0
		var comp := tamanho.x if em_x else tamanho.y
		var desloca := Vector3(0.0, 0.0, sinal * tamanho.y * 0.5) if em_x \
			else Vector3(sinal * tamanho.x * 0.5, 0.0, 0.0)
		KitModular.caixa_cor(sup, &"mercado_inox",
			centro + b * (desloca + Vector3(0.0, 0.018, 0.0)),
			Vector3(comp, 0.028, 0.01) if em_x else Vector3(0.01, 0.028, comp),
			INOX_ESCURO, giro)

	# A grade de produto. O passo vem do tamanho da peca, e cada uma recebe um
	# giro e um desvio proprios: fileira alinhada le como bandeja de plastico
	# estampada, que e o defeito que esta funcao existe para consertar.
	var passo := Vector2(0.082, 0.072) if tipo == 0 else \
		(Vector2(0.075, 0.07) if tipo == 1 else Vector2(0.148, 0.09))
	var colunas := maxi(1, int((tamanho.x - 0.03) / passo.x))
	var linhas := maxi(1, int((tamanho.y - 0.03) / passo.y))
	var limite := tamanho.x * (0.5 - vazia_a_direita)
	for c in colunas:
		for l in linhas:
			var x := -tamanho.x * 0.5 + (tamanho.x - passo.x * float(colunas)) * 0.5 \
				+ passo.x * (float(c) + 0.5)
			if x > limite:
				continue
			var z := -tamanho.y * 0.5 + (tamanho.y - passo.y * float(linhas)) * 0.5 \
				+ passo.y * (float(l) + 0.5)
			var p := centro + b * Vector3(x + rng.randf_range(-0.006, 0.006), 0.012,
				z + rng.randf_range(-0.006, 0.006))
			match tipo:
				0:
					coxinha(sup, p, giro + rng.randf_range(-0.5, 0.5),
						rng.randf_range(0.9, 1.1))
				1:
					pao_de_queijo(sup, p, rng.randf_range(0.88, 1.08))
				_:
					pastel(sup, p + Vector3(0.0, 0.002, 0.0),
						giro + rng.randf_range(-0.1, 0.1))


# --- estufa -----------------------------------------------------------------

## Estufa de salgados sobre o tampo do balcao.
##
## Devolve, como a `KitMercado.caixa_quente` que substitui, o ponto de onde sai
## a luz quente — a unica do salao.
##
## `centro` na base, no meio; a frente (o vidro inclinado, o lado do cliente)
## olha para +Z antes do `giro`.
static func estufa(sup: Dictionary, colisao: Array[Dictionary], centro: Vector3,
		giro: float, semente: int = 5501) -> Vector3:
	var b := Basis(Vector3.UP, giro)
	var larg := 0.62
	var prof := 0.44

	# Base de inox com o pe recuado: a estufa apoia no tampo, nao brota dele.
	Peca.prisma(sup, &"mercado_inox", Transform3D(b, centro),
		Peca.retangulo_redondo(Vector2(larg - 0.06, prof - 0.06), 0.01, 1),
		0.0, 0.02, INOX_ESCURO)
	Peca.prisma(sup, &"mercado_inox", Transform3D(b, centro),
		Peca.retangulo_redondo(Vector2(larg, prof), 0.02, 2), 0.02, 0.14, INOX)
	# Tampa, com a caixa da lampada por dentro.
	Peca.prisma(sup, &"mercado_inox", Transform3D(b, centro),
		Peca.retangulo_redondo(Vector2(larg, prof), 0.02, 2), 0.52, 0.60, INOX)
	Peca.prisma(sup, &"mercado_luz", Transform3D(b, centro + b * Vector3(0.0, 0.0, 0.02)),
		Peca.retangulo_redondo(Vector2(larg - 0.12, 0.06), 0.02, 1), 0.505, 0.52,
		Color("ffd9a0"))

	# Montantes dos cantos e o vidro entre eles. Vidro sem montante le como
	# bolha; sao os quatro cantos que dizem que ha uma vitrine ali.
	for lx: float in [-1.0, 1.0]:
		for lz: float in [-1.0, 1.0]:
			Peca.prisma(sup, &"mercado_inox",
				Transform3D(b, centro + b * Vector3(lx * (larg * 0.5 - 0.014),
					0.0, lz * (prof * 0.5 - 0.014))),
				Peca.retangulo_redondo(Vector2(0.028, 0.028), 0.006, 1), 0.14, 0.52,
				INOX_ESCURO)
	for lado in 4:
		var em_x := lado % 2 == 0
		var sinal := 1.0 if lado < 2 else -1.0
		var comp := (larg if em_x else prof) - 0.04
		var desloca := Vector3(0.0, 0.33, sinal * prof * 0.5) if em_x \
			else Vector3(sinal * larg * 0.5, 0.33, 0.0)
		KitModular.placa(sup, &"vitrine_loja", centro + b * desloca,
			Vector2(comp, 0.36), giro + (0.0 if em_x else PI * 0.5) \
				+ (0.0 if sinal > 0.0 else PI), Color("f0e2c4"))

	# Duas bandejas, com produto diferente em cada e a de cima meio vendida. A
	# de baixo e a que o jogador ve de frente; a de cima, de cima.
	bandeja(sup, centro + b * Vector3(0.0, 0.17, 0.0), Vector2(larg - 0.1, prof - 0.1),
		giro, 0, semente)
	bandeja(sup, centro + b * Vector3(0.0, 0.34, 0.0), Vector2(larg - 0.1, prof - 0.1),
		giro, 1, semente + 1, 0.3)
	# A pega de abrir, atras (o lado do atendente).
	Peca.tubo(sup, &"mercado_inox", PackedVector3Array([
		centro + b * Vector3(-0.16, 0.46, -prof * 0.5 - 0.03),
		centro + b * Vector3(0.16, 0.46, -prof * 0.5 - 0.03),
	]), 0.009, 6, INOX_ESCURO)

	KitModular.solido(colisao, centro + Vector3(0.0, 0.3, 0.0),
		Vector3(larg + 0.04, 0.6, prof + 0.04), giro)
	return centro + Vector3(0.0, 0.36, 0.0)


# --- lixeira ----------------------------------------------------------------

## Lixeira de salao: corpo conico, aro e a tampa de boca aberta.
##
## O aro na boca e o detalhe que troca "caixa de lixo" por "lixeira": e nele que
## o saco e preso, e e ele que aparece de cima, que e como o jogador olha.
static func lixeira(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var alto := 0.72
	Peca.torno(sup, &"mercado_plastico",
		Transform3D(b.scaled(Vector3(1.0, 1.0, 0.86)), base),
		PackedVector2Array([
			Vector2(0.0, 0.01), Vector2(0.16, 0.01), Vector2(0.16, 0.01),
			Vector2(0.175, 0.06), Vector2(0.205, alto - 0.08),
			Vector2(0.21, alto), Vector2(0.21, alto),
			Vector2(0.196, alto + 0.004),
		]), 12, LIXEIRA)
	# Aro e boca: o interior escuro, que e o que le como "aberta".
	Peca.torno(sup, &"mercado_plastico",
		Transform3D(b.scaled(Vector3(1.0, 1.0, 0.86)), base),
		PackedVector2Array([
			Vector2(0.196, alto + 0.004), Vector2(0.18, alto - 0.03),
			Vector2(0.17, alto - 0.14),
		]), 12, Color("4e5250"))
	# O saco preto dobrado por cima do aro.
	Peca.torno(sup, &"mercado_plastico",
		Transform3D(b.scaled(Vector3(1.03, 1.0, 0.89)), base),
		PackedVector2Array([
			Vector2(0.2, alto - 0.03), Vector2(0.205, alto - 0.005),
			Vector2(0.205, alto - 0.005), Vector2(0.185, alto - 0.05),
		]), 12, Color("2e3230"))
	KitModular.solido(colisao, base + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(0.44, alto, 0.38), giro)


# --- bancada ----------------------------------------------------------------

static func bancada_estufa(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	estufa(sup, colisao, Vector3.ZERO, 0.0)


static func bancada_lixeira(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	lixeira(sup, colisao, Vector3.ZERO, 0.0)
