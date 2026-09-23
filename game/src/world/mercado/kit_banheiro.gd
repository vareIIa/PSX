## O banheiro da loja: louca de verdade, no lugar das tres caixas empilhadas.
##
## Por que este arquivo existe
## ---------------------------
## Na captura `captures/mercado_aaa/auditoria/a14_banheiro.png` o comodo inteiro
## lia como bloco de granito. Dois defeitos somados:
##
## 1. FORMA. O vaso eram tres `KitModular.caixa_cor` empilhadas e a pia uma
##    coluna quadrada com um tampo quadrado. Silhueta de caixa nao diz "louca"
##    nem com o material certo — o que faz a peca ler como ela mesma a um metro
##    e meio e o CONTORNO: a curva da bacia, o cano da torneira, o sifao.
## 2. MATERIAL. Tudo usava `metal`, cujo albedo e 62/255 no PS1 e 63/255 no HD.
##    Tingir de branco sanitario dava 53/255 — preto, nos DOIS estilos. Nao era
##    problema de HD; era o material errado. Aqui a louca usa `mercado_louca`,
##    o metal da torneira `mercado_inox` e o assento `mercado_plastico`.
##
## Orcamento: 2000 triangulos para o comodo mobiliado (§10.3 do plano). As
## primitivas vem da `Peca`, que entrega silhueta redonda com 12 a 16 lados.
##
## Convencao das pecas: `base` no chao, no eixo do movel, e a FRENTE olha para
## +Z antes do `giro`. Igual ao `KitMercado`, para o construtor nao ter de
## pensar em duas convencoes.
class_name KitBanheiro
extends RefCounted

## Louca sanitaria. Nao e branco puro: o branco puro do albedo com a calha por
## cima estoura e a peca perde o contorno.
const LOUCA := Color("f4f4f0")
const LOUCA_SOMBRA := Color("e2e4e0")
## Assento e tampa: plastico, um tom mais frio que a louca, senao a peca inteira
## le como uma unica massa.
const ASSENTO := Color("eef0ee")
## Aco cromado da torneira, do sifao e da barra de apoio.
const CROMO := Color("e8ecee")
## O espelho: cinza-azul CLARO. Espelho escuro le como furo na parede; o que o
## olho espera e a propria parede de azulejo devolvida.
const ESPELHO := Color("b4c2c6")
const MOLDURA := Color("9aa2a0")
## Plastico do dispenser e da lixeira.
const DISPENSER := Color("d8dad6")

## Lados das superficies de revolucao. Doze basta para a bacia a um metro e
## meio; dezesseis so na cuba, que e a peca que o jogador olha de cima.
const LADOS := 12
const LADOS_CUBA := 14


# --- vaso -------------------------------------------------------------------

## Vaso sanitario com caixa acoplada, assento e botao de descarga.
##
## Tres tornos: pe, bacia e assento. A bacia e um torno ACHATADO (escala 1,15 x
## 1,40), que e o que da o oval; com escala uniforme ela sai redonda e le como
## tambor. A normal vai pela inversa transposta, entao o achatamento nao estraga
## a sombra.
static func vaso(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var xf := func(escala: Vector3, desloca: Vector3) -> Transform3D:
		return Transform3D(b.scaled(escala), base + b * desloca)

	# Pe: largo no chao, afina na canela, alarga de novo para encontrar a bacia.
	# O ponto repetido em y = 0 e o vinco da borda que encosta no ladrilho.
	Peca.torno(sup, &"mercado_louca", xf.call(Vector3(1.05, 1.0, 1.25), Vector3.ZERO),
		PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(0.135, 0.0), Vector2(0.135, 0.0),
			Vector2(0.115, 0.05), Vector2(0.085, 0.17), Vector2(0.10, 0.22),
		]), LADOS, LOUCA_SOMBRA)

	# Bacia: sobe por fora, vinca na borda, desce por dentro ate o fundo.
	# Sem o vinco a sombra desliza macia por cima da borda e a peca perde a
	# aresta que diz onde a louca acaba.
	Peca.torno(sup, &"mercado_louca", xf.call(Vector3(1.15, 1.0, 1.4), Vector3.ZERO),
		PackedVector2Array([
			Vector2(0.10, 0.22), Vector2(0.17, 0.32), Vector2(0.185, 0.40),
			Vector2(0.185, 0.40), Vector2(0.175, 0.415), Vector2(0.175, 0.415),
			Vector2(0.16, 0.38), Vector2(0.135, 0.30), Vector2(0.105, 0.24),
			Vector2(0.075, 0.215),
		]), LADOS, LOUCA)
	# A agua: disco escuro no fundo. Sem ela a bacia le como tigela de louca
	# cheia de luz, porque o interior recebe a calha inteira.
	Peca.torno(sup, &"mercado_louca", xf.call(Vector3(1.15, 1.0, 1.4), Vector3.ZERO),
		PackedVector2Array([
			Vector2(0.075, 0.215), Vector2(0.0, 0.212),
		]), LADOS, Color("8f9a9c"))

	# Assento: anel de plastico apoiado na borda, com a tampa levantada contra a
	# caixa. Tampa fechada esconde a bacia inteira e o comodo volta a ser caixa.
	Peca.torno(sup, &"mercado_plastico", xf.call(Vector3(1.16, 1.0, 1.42), Vector3(0.0, 0.0, 0.01)),
		PackedVector2Array([
			Vector2(0.095, 0.418), Vector2(0.19, 0.422), Vector2(0.19, 0.422),
			Vector2(0.19, 0.445), Vector2(0.19, 0.445), Vector2(0.095, 0.441),
		]), LADOS, ASSENTO)

	# Caixa acoplada, encostada na parede, com a quina vertical arredondada.
	Peca.prisma(sup, &"mercado_louca", Transform3D(b, base + b * Vector3(0.0, 0.0, -0.30)),
		Peca.retangulo_redondo(Vector2(0.38, 0.19), 0.03, 2), 0.42, 0.80, LOUCA)
	Peca.prisma(sup, &"mercado_louca", Transform3D(b, base + b * Vector3(0.0, 0.0, -0.30)),
		Peca.retangulo_redondo(Vector2(0.42, 0.23), 0.05, 2), 0.80, 0.83, LOUCA_SOMBRA)
	# Botao de descarga: o detalhe que faz o jogador reconhecer a caixa.
	Peca.cilindro(sup, &"mercado_inox", base + b * Vector3(0.0, 0.83, -0.30),
		0.032, 0.008, 10, CROMO)
	# Ligacao da caixa com a bacia.
	Peca.tubo(sup, &"mercado_louca", PackedVector3Array([
		base + b * Vector3(0.0, 0.44, -0.30), base + b * Vector3(0.0, 0.44, -0.20),
	]), 0.035, 8, LOUCA_SOMBRA)

	# Papeleira na parede, do lado da mao.
	Peca.tubo(sup, &"mercado_inox", PackedVector3Array([
		base + b * Vector3(0.24, 0.62, -0.34), base + b * Vector3(0.24, 0.62, -0.20),
	]), 0.008, 6, CROMO)
	Peca.torno(sup, &"mercado_louca",
		Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), base + b * Vector3(0.24, 0.62, -0.26)),
		PackedVector2Array([
			Vector2(0.02, -0.055), Vector2(0.055, -0.055), Vector2(0.055, -0.055),
			Vector2(0.055, 0.055), Vector2(0.055, 0.055), Vector2(0.02, 0.055),
		]), 10, Color("fafaf6"))

	KitModular.solido(colisao, base + Vector3(0.0, 0.35, 0.0),
		Vector3(0.44, 0.7, 0.72), giro)


# --- pia --------------------------------------------------------------------

## Pia de coluna com cuba oval, torneira de cano, sifao e espelho.
##
## O sifao existe por um motivo so: e o que se ve primeiro quando o jogador
## chega perto e olha para baixo. Sem ele a coluna e um tronco liso e a pia
## volta a ler como movel de catalogo.
static func pia(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var alto := 0.86

	# Coluna: barriga larga no chao, cintura na canela, ombro sob a cuba.
	Peca.torno(sup, &"mercado_louca",
		Transform3D(b.scaled(Vector3(1.0, 1.0, 0.92)), base),
		PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(0.145, 0.0), Vector2(0.145, 0.0),
			Vector2(0.125, 0.06), Vector2(0.085, 0.34), Vector2(0.09, 0.60),
			Vector2(0.135, alto - 0.14),
		]), LADOS, LOUCA_SOMBRA)

	# Cuba: oval, funda, com a borda vincada e o fundo inclinado para o ralo.
	Peca.torno(sup, &"mercado_louca",
		Transform3D(b.scaled(Vector3(1.35, 1.0, 1.05)), base),
		PackedVector2Array([
			Vector2(0.135, alto - 0.14), Vector2(0.19, alto - 0.06),
			Vector2(0.20, alto), Vector2(0.20, alto),
			Vector2(0.195, alto + 0.015), Vector2(0.195, alto + 0.015),
			Vector2(0.18, alto - 0.005), Vector2(0.15, alto - 0.075),
			Vector2(0.07, alto - 0.12), Vector2(0.025, alto - 0.125),
		]), LADOS_CUBA, LOUCA)
	# Ralo.
	Peca.cilindro(sup, &"mercado_inox", base + Vector3(0.0, alto - 0.128, 0.0),
		0.024, 0.004, 10, Color("c6ccce"))

	# Torneira: corpo, cano em arco e volante. O arco vem de `Peca.tubo` com
	# quatro pontos; com dois o cano sai reto e le como parafuso.
	Peca.cilindro(sup, &"mercado_inox", base + b * Vector3(0.0, alto - 0.01, -0.175),
		0.026, 0.055, 10, CROMO)
	Peca.tubo(sup, &"mercado_inox", PackedVector3Array([
		base + b * Vector3(0.0, alto + 0.03, -0.175),
		base + b * Vector3(0.0, alto + 0.115, -0.175),
		base + b * Vector3(0.0, alto + 0.145, -0.145),
		base + b * Vector3(0.0, alto + 0.14, -0.075),
		base + b * Vector3(0.0, alto + 0.10, -0.055),
	]), 0.014, 8, CROMO)
	Peca.torno(sup, &"mercado_inox",
		Transform3D(b, base + b * Vector3(0.0, alto + 0.045, -0.175)),
		PackedVector2Array([
			Vector2(0.0, 0.03), Vector2(0.05, 0.028), Vector2(0.05, 0.028),
			Vector2(0.045, 0.042), Vector2(0.045, 0.042), Vector2(0.0, 0.044),
		]), 10, CROMO)

	# Sifao: desce da cuba, faz o U e entra na parede.
	Peca.tubo(sup, &"mercado_inox", PackedVector3Array([
		base + b * Vector3(0.0, alto - 0.13, 0.0),
		base + b * Vector3(0.0, 0.50, 0.0),
		base + b * Vector3(0.0, 0.43, 0.005),
		base + b * Vector3(0.0, 0.445, -0.07),
		base + b * Vector3(0.0, 0.50, -0.10),
		base + b * Vector3(0.0, 0.52, -0.20),
	]), 0.019, 8, Color("d2d8da"), false)

	KitModular.solido(colisao, base + Vector3(0.0, 0.48, 0.0),
		Vector3(0.56, 0.96, 0.44), giro)


## Espelho de parede com moldura fina e prateleira de vidro.
##
## `centro` no meio do vidro, contra a parede; a frente olha para +Z apos o
## giro, ou seja, o vidro fica virado para dentro do comodo.
static func espelho(sup: Dictionary, centro: Vector3, tamanho: Vector2,
		giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	Peca.prisma(sup, &"mercado_inox", Transform3D(b, centro),
		Peca.retangulo_redondo(Vector2(tamanho.x + 0.05, 0.022), 0.008, 1),
		-tamanho.y * 0.5 - 0.025, tamanho.y * 0.5 + 0.025, MOLDURA)
	# O vidro, um pouco a frente da moldura.
	KitModular.placa(sup, &"mercado_inox", centro + b * Vector3(0.0, 0.0, 0.014),
		tamanho, giro, ESPELHO)


# --- acessorios -------------------------------------------------------------

## Dispenser de papel ou sabonete, na parede: caixa de plastico com a frente
## chanfrada e o bico embaixo.
static func dispenser(sup: Dictionary, centro: Vector3, giro: float,
		sabonete: bool = false) -> void:
	var b := Basis(Vector3.UP, giro)
	var tam := Vector2(0.18, 0.26) if sabonete else Vector2(0.28, 0.32)
	# Contorno visto de cima: costas retas na parede, frente arredondada.
	var contorno := PackedVector2Array([
		Vector2(-tam.x * 0.5, -0.055), Vector2(tam.x * 0.5, -0.055),
		Vector2(tam.x * 0.5, 0.03), Vector2(tam.x * 0.36, 0.075),
		Vector2(-tam.x * 0.36, 0.075), Vector2(-tam.x * 0.5, 0.03),
	])
	Peca.prisma(sup, &"mercado_plastico", Transform3D(b, centro), contorno,
		-tam.y * 0.5, tam.y * 0.5, DISPENSER)
	if sabonete:
		Peca.tubo(sup, &"mercado_inox", PackedVector3Array([
			centro + b * Vector3(0.0, -tam.y * 0.5, 0.05),
			centro + b * Vector3(0.0, -tam.y * 0.5 - 0.045, 0.05),
		]), 0.008, 6, CROMO)
	else:
		# A boca por onde o papel sai, e a folha pendurada nela.
		Peca.caixa_redonda(sup, &"mercado_plastico",
			centro + b * Vector3(0.0, -tam.y * 0.5 + 0.02, 0.05),
			Vector3(tam.x * 0.62, 0.02, 0.05), 0.008, Color("8e938e"), giro, 1)
		KitModular.placa(sup, &"mercado_louca",
			centro + b * Vector3(0.0, -tam.y * 0.5 - 0.045, 0.052),
			Vector2(tam.x * 0.5, 0.11), giro, Color("fbfbf7"))


## Lixeira de pedal: corpo cilindrico, tampa em cone e o pedal na frente.
static func lixeira_pedal(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var alto := 0.42
	Peca.torno(sup, &"mercado_plastico", Transform3D(b, base),
		PackedVector2Array([
			Vector2(0.0, 0.03), Vector2(0.135, 0.03), Vector2(0.135, 0.03),
			Vector2(0.145, 0.12), Vector2(0.155, alto), Vector2(0.155, alto),
			Vector2(0.14, alto + 0.01),
		]), LADOS, Color("d2d6d2"))
	# Tampa em cone raso, meio aberta: aberta le como lixeira, fechada como pote.
	Peca.torno(sup, &"mercado_plastico",
		Transform3D(b * Basis(Vector3.RIGHT, -0.22), base + b * Vector3(0.0, alto + 0.025, 0.0)),
		PackedVector2Array([
			Vector2(0.16, 0.0), Vector2(0.155, 0.02), Vector2(0.11, 0.05),
			Vector2(0.0, 0.06),
		]), LADOS, Color("c6cac6"))
	# Pedal e haste.
	Peca.caixa_redonda(sup, &"mercado_inox", base + b * Vector3(0.0, 0.035, 0.145),
		Vector3(0.09, 0.012, 0.06), 0.005, Color("b6bcbc"), giro, 1)
	Peca.tubo(sup, &"mercado_inox", PackedVector3Array([
		base + b * Vector3(0.0, 0.04, 0.12), base + b * Vector3(0.0, 0.04, -0.14),
	]), 0.008, 6, Color("b6bcbc"))
	KitModular.solido(colisao, base + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(0.32, alto, 0.32), giro)


## Barra de apoio de parede, em U deitado.
static func barra_apoio(sup: Dictionary, centro: Vector3, comprimento: float,
		giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var meio := comprimento * 0.5
	Peca.tubo(sup, &"mercado_inox", PackedVector3Array([
		centro + b * Vector3(-meio, 0.0, -0.05),
		centro + b * Vector3(-meio, 0.0, 0.055),
		centro + b * Vector3(-meio + 0.05, 0.0, 0.08),
		centro + b * Vector3(meio - 0.05, 0.0, 0.08),
		centro + b * Vector3(meio, 0.0, 0.055),
		centro + b * Vector3(meio, 0.0, -0.05),
	]), 0.017, 8, CROMO)
	for lado: float in [-1.0, 1.0]:
		Peca.cilindro(sup, &"mercado_inox", centro + b * Vector3(lado * meio, 0.0, -0.05),
			0.028, 0.02, 8, MOLDURA, true, true,
			b * Basis(Vector3.RIGHT, -PI * 0.5))


## Ralo de piso: grelha quadrada rente ao ladrilho.
##
## As tres ripas escuras por cima sao o que faz a peca ler como grelha e nao
## como placa: a 480x270 a fresta entre elas cai em menos de um pixel, mas a
## diferenca de cor sobrevive ao dither.
static func ralo(sup: Dictionary, centro: Vector3) -> void:
	Peca.prisma(sup, &"mercado_inox", Transform3D(Basis(), centro),
		Peca.retangulo_redondo(Vector2(0.15, 0.15), 0.012, 1), 0.0, 0.006,
		Color("9ea4a4"))
	for k in 3:
		var z := centro.z + (float(k) - 1.0) * 0.034
		Peca.prisma(sup, &"mercado_inox",
			Transform3D(Basis(), Vector3(centro.x, centro.y, z)),
			Peca.retangulo_redondo(Vector2(0.11, 0.014), 0.004, 1), 0.006, 0.009,
			Color("4e5454"))


## Cano aparente de descida, no canto do comodo: o detalhe de predio antigo que
## nenhuma caixa da.
static func cano_canto(sup: Dictionary, base: Vector3, altura: float) -> void:
	Peca.cilindro(sup, &"mercado_inox", base, 0.035, altura, 8,
		Color("b0b6b2"), false, false)
	for y: float in [0.3, altura - 0.35]:
		Peca.torno(sup, &"mercado_inox", Transform3D(Basis(), base + Vector3(0.0, y, 0.0)),
			PackedVector2Array([
				Vector2(0.035, 0.0), Vector2(0.046, 0.005), Vector2(0.046, 0.005),
				Vector2(0.046, 0.045), Vector2(0.046, 0.045), Vector2(0.035, 0.05),
			]), 8, Color("9aa09c"))


# --- o comodo ---------------------------------------------------------------

## Mobilia o banheiro inteiro. `x0..x1` e `z0..z1` sao as faces internas do
## reboco; `porta_x` e o eixo da porta na parede z0, para nada nascer no vao.
##
## A planta: vaso no fundo contra a parede oeste, pia na parede leste com o
## espelho na altura do rosto, dispenser de papel ao lado do espelho, lixeira
## sob ele, barra de apoio ao lado do vaso e o ralo no meio do piso.
static func montar(sup: Dictionary, colisao: Array[Dictionary],
		x0: float, x1: float, z0: float, z1: float, altura: float,
		porta_x: float) -> void:
	var meio_x := (x0 + x1) * 0.5

	# Vaso: contra a parede do fundo, do lado oeste, virado para a porta.
	vaso(sup, colisao, Vector3(x0 + 0.52, 0.0, z1 - 0.38), PI)
	barra_apoio(sup, Vector3(x0 + 0.02, 0.78, z1 - 0.62), 0.6, PI * 0.5)

	# Pia na parede leste, a meia altura do comodo.
	var x_pia := x1 - 0.26
	pia(sup, colisao, Vector3(x_pia, 0.0, z0 + 1.45), -PI * 0.5)
	espelho(sup, Vector3(x1 - 0.03, 1.46, z0 + 1.45), Vector2(0.52, 0.62), -PI * 0.5)
	dispenser(sup, Vector3(x1 - 0.13, 1.28, z0 + 2.25), -PI * 0.5)
	dispenser(sup, Vector3(x1 - 0.11, 1.28, z0 + 0.72), -PI * 0.5, true)
	lixeira_pedal(sup, colisao, Vector3(x1 - 0.28, 0.0, z0 + 2.85), -0.4)

	# Ralo fora da linha da porta, e o cano no canto do fundo.
	ralo(sup, Vector3(meio_x + 0.2, 0.0, (z0 + z1) * 0.5))
	cano_canto(sup, Vector3(x0 + 0.09, 0.0, z1 - 0.09), altura)

	# Cabides na parede da porta, ao lado do vao: o unico movel que o jogador ve
	# ao fechar a porta atras de si.
	for k in 2:
		Peca.tubo(sup, &"mercado_inox", PackedVector3Array([
			Vector3(porta_x + 0.62 + float(k) * 0.24, 1.62, z0 + 0.03),
			Vector3(porta_x + 0.62 + float(k) * 0.24, 1.60, z0 + 0.10),
		]), 0.01, 6, CROMO)


# --- bancada ----------------------------------------------------------------
# Contrato de `tests/bancada_pecas.gd`: peca sozinha, em volta da origem, com o
# chao em y = 0 e a frente para +Z.

static func bancada_vaso(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	vaso(sup, colisao, Vector3.ZERO, 0.0)


static func bancada_pia(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	pia(sup, colisao, Vector3.ZERO, 0.0)
	espelho(sup, Vector3(0.0, 1.46, -0.23), Vector2(0.52, 0.62), 0.0)


static func bancada_acessorios(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	lixeira_pedal(sup, colisao, Vector3(-0.45, 0.0, 0.0), 0.3)
	dispenser(sup, Vector3(0.1, 0.55, -0.2), 0.0)
	dispenser(sup, Vector3(0.45, 0.55, -0.2), 0.0, true)
	barra_apoio(sup, Vector3(0.28, 0.2, -0.2), 0.6, 0.0)
	ralo(sup, Vector3(0.0, 0.0, 0.3))


## O comodo inteiro, mas centrado na origem: a bancada ilumina em volta do zero,
## e nas coordenadas da loja (x 0..2,8 / z 12,5..16) a foto sai no escuro.
static func bancada_banheiro(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	montar(sup, colisao, -1.4, 1.4, -1.75, 1.75, 2.68, 0.0)
