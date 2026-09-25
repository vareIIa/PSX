## A maquina de refrigerante encostada na fachada (ChunkBuilder._maquina).
##
## Por que existe
## -------------
## A de antes era uma caixa de metal com um quad na frente: textura de ladrilho de
## calcada com emissao 2,0. De dia e de noite lia como um painel branco estourado
## sem desenho — "um marcador de depuracao" (PLANO_BAR_E_CIDADE_AAA, C2).
##
## Agora e maquina de verdade, com as mesmas pecas da cervejeira do bar:
##   - caixa pintada na cor da marca, pe escuro e chapeu com a faixa acesa;
##   - vitrine de vidro (`vitrine_loja`) sobre a camara clara com o tubo de luz,
##     e cinco grades de lata com rotulo do mercado (`ProdutosDoBar`, MultiMesh);
##   - painel de moedas a direita: visor, fenda de moeda, noteiro e a coluna de
##     botoes; gaveta de retirada embaixo.
## Tudo em material que o chunk ja usa (e o aquecimento de shaders ja conhece).
##
## Local da maquina: x pela frente (positivo a direita de quem olha da rua), y do
## chao da calcada, z para a rua. `base` e o meio do pe dela.
class_name MaquinaDeVenda
extends RefCounted

const LARGURA := 1.1
const ALTURA := 1.86
const FUNDO := 0.72
const PE := 0.1
const CHAPEU := 0.2
## A vitrine ocupa a esquerda; o painel de moedas, a direita.
const VITRINE := 0.74
const MARCAS: Array[Color] = [Color("b3241f"), Color("1d4f96"), Color("1f7a3a"),
	Color("c24a14")]
const LATAS: Array = [&"coca_lata", &"guarana_lata", &"fanta_lata", &"sprite_lata",
	&"pepsi_lata", &"soda_lata"]


## A maquina na calcada, com a colisao e o prop dos produtos.
static func montar(sup: Dictionary, colisao: Array[Dictionary], props: Array[Dictionary],
		base: Vector3, direcao: int, semente: int) -> void:
	var normal := KitModular._normal(direcao)
	var giro := atan2(normal.x, normal.z)
	var b := Basis(Vector3.UP, giro)
	var em := func(l: Vector3) -> Vector3:
		return base + b * l
	var marca: Color = MARCAS[posmod(semente, MARCAS.size())]
	var escuro := Color("2a2c2e")
	var frente := FUNDO * 0.5
	var meia := LARGURA * 0.5

	# Casco: pe, laterais e costas na cor da marca, chapeu com a faixa acesa.
	KitModular.caixa_cor(sup, &"metal_pintado", em.call(Vector3(0.0, PE * 0.5, 0.0)),
		Vector3(LARGURA, PE, FUNDO), escuro, giro)
	# Laterais e costas param no chapeu: subindo ate o topo, a face de fora delas
	# caia no plano da do chapeu.
	var corpo_h := ALTURA - PE - CHAPEU
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"metal_pintado",
			em.call(Vector3(lado * (meia - 0.03), PE + corpo_h * 0.5, 0.0)),
			Vector3(0.06, corpo_h, FUNDO), marca, giro)
	KitModular.caixa_cor(sup, &"metal_pintado",
		em.call(Vector3(0.0, PE + corpo_h * 0.5, -frente + 0.03)),
		Vector3(LARGURA - 0.12, corpo_h, 0.06), marca.darkened(0.25), giro)
	KitModular.caixa_cor(sup, &"metal_pintado",
		em.call(Vector3(0.0, ALTURA - CHAPEU * 0.5, 0.0)),
		Vector3(LARGURA, CHAPEU, FUNDO), marca, giro)
	KitModular.caixa_cor(sup, &"mercado_luz",
		em.call(Vector3(0.0, ALTURA - CHAPEU * 0.5, frente + 0.008)),
		Vector3(LARGURA - 0.14, CHAPEU * 0.5, 0.012), Color("fff4e0"), giro)

	# Camara: fundo claro, tubo de luz em cima, grades e as latas.
	var x_vit := -meia + 0.06 + VITRINE * 0.5
	var vit_y0 := 0.52
	var vit_y1 := ALTURA - CHAPEU - 0.04
	KitModular.caixa_cor(sup, &"mercado_chapa",
		em.call(Vector3(x_vit, (vit_y0 + vit_y1) * 0.5, -frente + 0.075)),
		Vector3(VITRINE, vit_y1 - vit_y0, 0.02), Color("eef2f2"), giro)
	KitModular.caixa_cor(sup, &"mercado_luz",
		em.call(Vector3(x_vit, vit_y1 - 0.03, frente - 0.12)),
		Vector3(VITRINE - 0.06, 0.025, 0.025), Color("eaf2ff"), giro)
	var itens: Array = []
	var dentro := VITRINE * 0.5 - 0.05
	for n in 5:
		var y := vit_y0 + 0.04 + float(n) * 0.225
		KitModular.caixa_cor(sup, &"mercado_chapa",
			em.call(Vector3(x_vit, y - 0.008, 0.0)),
			Vector3(VITRINE, 0.016, FUNDO - 0.16), Color("aeb6ba"), giro)
		ProdutosDoBar.fileira(itens, LATAS, em.call(Vector3(x_vit - dentro, y, frente - 0.14)),
			em.call(Vector3(x_vit + dentro, y, frente - 0.14)), giro, 3, 0.09, semente + 13 * n)
	props.append(ProdutosDoBar.prop(itens, base))

	# Vidro com a moldura, 4 cm atras da frente do casco.
	var vidro_y := (vit_y0 + vit_y1) * 0.5
	KitModular.placa(sup, &"vitrine_loja", em.call(Vector3(x_vit, vidro_y, frente - 0.04)),
		Vector2(VITRINE, vit_y1 - vit_y0), giro, Color.WHITE)
	# A moldura sai 6 mm a frente do painel e da gaveta, que ficam no plano do casco.
	for y: float in [vit_y0 - 0.02, vit_y1 + 0.02]:
		KitModular.caixa_cor(sup, &"metal_pintado", em.call(Vector3(x_vit, y, frente - 0.014)),
			Vector3(VITRINE + 0.04, 0.04, 0.04), escuro, giro)

	# Painel de moedas: chapa escura, visor, fenda, noteiro e os botoes.
	var x_pai := meia - 0.06 - (LARGURA - 0.12 - VITRINE) * 0.5
	var larg_pai := LARGURA - 0.12 - VITRINE - 0.02
	KitModular.caixa_cor(sup, &"metal_pintado",
		em.call(Vector3(x_pai, (vit_y0 + vit_y1) * 0.5, frente - 0.02)),
		Vector3(larg_pai, vit_y1 - vit_y0, 0.04), Color("3a3d40"), giro)
	KitModular.caixa_cor(sup, &"mercado_luz", em.call(Vector3(x_pai, vit_y1 - 0.14, frente + 0.004)),
		Vector3(larg_pai - 0.08, 0.06, 0.01), Color("7fe0a0"), giro)
	KitModular.caixa_cor(sup, &"metal", em.call(Vector3(x_pai, vit_y1 - 0.3, frente + 0.006)),
		Vector3(0.05, 0.1, 0.014), Color("c8ccce"), giro)
	KitModular.caixa_cor(sup, &"metal", em.call(Vector3(x_pai, vit_y1 - 0.46, frente + 0.006)),
		Vector3(larg_pai - 0.1, 0.06, 0.014), Color("202224"), giro)
	for k in 6:
		KitModular.caixa_cor(sup, &"metal_pintado",
			em.call(Vector3(x_pai, vit_y1 - 0.6 - float(k) * 0.085, frente + 0.006)),
			Vector3(larg_pai - 0.12, 0.05, 0.014), Color("d8dadc"), giro)

	# Gaveta de retirada: boca escura com a aba.
	KitModular.caixa_cor(sup, &"metal_pintado", em.call(Vector3(0.0, (PE + vit_y0) * 0.5, frente - 0.02)),
		Vector3(LARGURA - 0.12, vit_y0 - PE - 0.04, 0.04), marca.darkened(0.15), giro)
	KitModular.caixa_cor(sup, &"metal", em.call(Vector3(x_vit, PE + 0.17, frente + 0.004)),
		Vector3(0.46, 0.16, 0.012), Color("121314"), giro)

	# A caixa de colisao e alinhada aos eixos: deitada na fachada do eixo X.
	var tam := Vector3(1.2, 1.9, 0.7) if absf(normal.z) > 0.5 else Vector3(0.7, 1.9, 1.2)
	colisao.append({"tamanho": tam, "pos": base + Vector3(0.0, 0.95, 0.0)})
