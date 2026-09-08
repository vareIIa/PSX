## Pecas da estrada de terra e da mata em volta, em dados brutos.
##
## Mesmo contrato do resto do kit: funcao estatica que escreve num dicionario de
## superficies por material, sem tocar em no nenhum. Quem transforma isso em
## malha e o `EstradaBuilder`.
##
## Por que nao reusa o KitParque
## -----------------------------
## Porque parque e mata sao coisas diferentes, e a diferenca esta exatamente no
## que este arquivo faz. A arvore do parque e larga, isolada e baixa — ela existe
## para ter sombra embaixo e banco do lado, e a paleta dela e de folha noturna
## sob poste de sodio. A arvore de mata fechada e alta, estreita e encostada na
## vizinha: o que se ve dela nunca e a copa inteira, e sim a fatia de tronco
## entre duas outras. Plantar arvore de praca em fila daria uma alameda, e o
## plano pede um corredor.
##
## O `KitParque.arbusto` continua servindo e e usado como esta, porque arbusto e
## arbusto em qualquer lugar.
##
## Nada aqui tem colisao
## ---------------------
## A cena da estrada e sobre trilhos: o carro anda no caminho calculado, e nao
## num corpo de fisica com roda. Gerar caixa de colisao para oitocentos troncos
## que ninguem vai encostar custaria mais que a geometria toda e nao mudaria um
## pixel. Se um dia a estrada virar lugar que se dirige de verdade, e aqui que a
## colisao entra, no mesmo formato do resto do kit.
##
## Orcamento
## ---------
## Medido: 96 triangulos por arvore, 24 por moita de mata, 4 por tufo de capim,
## 224 pelos 32 m de leito. Um trecho de 32 m com dezoito arvores, oito moitas e
## setenta tufos fecha em 2400, e cinco trechos cabem dentro dos 25.000 que o
## ART-BIBLE secao 10 permite ter na tela dentro da nevoa.
class_name KitEstrada
extends RefCounted

# --- materiais --------------------------------------------------------------

const M_LEITO := &"leito"
const M_MATO := &"mato"
const M_CASCA := &"casca"
const M_FOLHA := &"folhagem"
const M_FOLHA_RECORTE := &"folhagem_recorte"
const M_METAL := &"metal"
const M_TABUA := &"tabua"

# --- celulas do mato_atlas --------------------------------------------------
# Linha 0 e planta de pe, recortada no alfa. Linha 1 e chao, opaca.

const C_CAPIM := Vector2i(0, 0)
const C_CAPIM_SECO := Vector2i(1, 0)
const C_SAMAMBAIA := Vector2i(2, 0)
const C_FOLHA_LARGA := Vector2i(3, 0)
const C_MOITA_BAIXA := Vector2i(4, 0)
const C_GALHO_SECO := Vector2i(5, 0)
const C_FLOR := Vector2i(6, 0)
const C_CAPIM_RALO := Vector2i(7, 0)

const C_FOLHICO := Vector2i(0, 1)
const C_BARRO := Vector2i(1, 1)
const C_CASCALHO := Vector2i(2, 1)
const C_POCA := Vector2i(3, 1)

# --- medidas da estrada -----------------------------------------------------

## Meia largura do leito de terra, do eixo ate onde comeca o mato.
const MEIA_PISTA := 3.1
## Onde fica o centro de cada trilha de pneu, medido do eixo. Um metro e dez e
## a bitola de carro de verdade, e e o que faz as duas trilhas da print lerem
## como rastro de roda em vez de duas faixas pintadas.
const TRILHA := 1.10
const MEIA_TRILHA := 0.52

## Passo ao longo da estrada. Nao e escolha de gosto: a UV afim empena dentro de
## cada quad proporcionalmente ao tamanho dele, e o ART-BIBLE secao 4 poe o teto
## em 2 m. Um leito passo 4 sairia com a terra derretendo a cada solavanco.
const PASSO := 1.8

## Cores do leito. Multiplicam a celula, que e quase neutra de proposito.
##
## A trilha e MAIS CLARA que o resto, e nao mais escura: terra pisada por pneu
## perde o folhico e a materia organica e fica mais clara e mais cinzenta que a
## beira. E o desenho que a print mostra e o unico que le como estrada de terra
## em vez de duas faixas de barro.
## Paleta de barro vermelho (ref 04): saturada no facho, escura fora.
const COR_TRILHA := Color(0.98, 0.55, 0.38)
const COR_MEIO := Color(0.72, 0.30, 0.18)
const COR_BEIRA := Color(0.55, 0.24, 0.14)
const COR_FOLHICO := Color(0.42, 0.32, 0.18)

## A secao do leito, do lado esquerdo para o direito. Cada item e
## [inicio, fim, celula, cor] em metros a partir do eixo.
##
## Sete colunas, e nao tres. As duas trilhas precisam de uma faixa de barro de
## cada lado para nao encostarem direto no folhico — sem essa transicao a
## estrada vira um retangulo claro colado na mata, que e o defeito classico de
## estrada de terra em jogo.
const SECAO: Array = [
	[-MEIA_PISTA, -2.05, C_FOLHICO, COR_FOLHICO],
	[-2.05, -TRILHA - MEIA_TRILHA, C_BARRO, COR_BEIRA],
	[-TRILHA - MEIA_TRILHA, -TRILHA + MEIA_TRILHA, C_BARRO, COR_TRILHA],
	[-TRILHA + MEIA_TRILHA, TRILHA - MEIA_TRILHA, C_CASCALHO, COR_MEIO],
	[TRILHA - MEIA_TRILHA, TRILHA + MEIA_TRILHA, C_BARRO, COR_TRILHA],
	[TRILHA + MEIA_TRILHA, 2.05, C_BARRO, COR_BEIRA],
	[2.05, MEIA_PISTA, C_FOLHICO, COR_FOLHICO],
]

# --- paleta da mata ---------------------------------------------------------

## Verdes de mata no fim da tarde. Escuros e puxados para o oliva, porque a luz
## que vale nesta cena e o sol raso vindo de frente: a folha que aparece e a que
## esta em contraluz, e ela e quase preta com a borda quente. Verde de meio-dia
## aqui apaga o poente inteiro.
const VERDES: Array[Color] = [
	Color("46583a"), Color("3d5034"), Color("50603c"), Color("3a4a30"),
]
## Uma copa em cada seis e de folha seca. Sem isto a mata e um tapete verde de
## uma cor so, que e o que denuncia floresta gerada.
const SECOS: Array[Color] = [
	Color("7a6740"), Color("6b5a38"), Color("857046"),
]
const CASCA_TOM := Color("6f6252")

## Subdivisao folgada em tudo que e vegetacao. A textura de folha ja e ruido: a
## grade padrao de 2 m quadruplicaria o custo da copa sem mudar a imagem.
const QUAD_FOLHA := 4.0
const CEDE_COPA := 1.0
const CEDE_TRONCO := 0.12


# --- primitiva --------------------------------------------------------------

## Um quadrilatero qualquer com uma celula do atlas. E o tijolo do leito.
##
## Existe porque nem `KitModular.chao` nem `AtlasKit.deitado` servem: os dois
## desenham retangulo alinhado, e uma estrada que curva e feita de trapezios —
## os dois lados de um trecho tem comprimentos diferentes sempre que a curva
## aperta.
##
## Ordem dos cantos: a e b sao a borda de tras (esquerda e direita), c e d a da
## frente (direita e esquerda). A normal sai do produto vetorial dos dois
## primeiros lados, entao inverter a ordem vira a face para baixo.
static func quad(sup: Dictionary, material: StringName, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3, celula: Vector2i, cor: Color) -> void:
	if not sup.has(material):
		sup[material] = PSXMesh.dados_vazios()
	var dados: Dictionary = sup[material]
	var r := Carroceria.uv(celula)
	var v: PackedVector3Array = dados["v"]
	var n: PackedVector3Array = dados["n"]
	var u: PackedVector2Array = dados["uv"]
	var cc: PackedColorArray = dados["c"]
	var i: PackedInt32Array = dados["i"]

	var base := v.size()
	var normal := (b - a).cross(d - a).normalized()
	for p: Vector3 in [a, b, c, d]:
		v.append(p)
		n.append(normal)
		# Alfa 0: a rigidez ao vento. Chao nao balanca, e o shader le COLOR.a
		# como "quanto este vertice cede" — alfa 1 num leito de estrada faria a
		# terra ondular junto com o capim.
		cc.append(Color(cor.r, cor.g, cor.b, 0.0))
	u.append(r.position + Vector2(0.0, r.size.y))
	u.append(r.position + r.size)
	u.append(r.position + Vector2(r.size.x, 0.0))
	u.append(r.position)
	i.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

	dados["v"] = v
	dados["n"] = n
	dados["uv"] = u
	dados["c"] = cc
	dados["i"] = i


# --- leito ------------------------------------------------------------------

## Um trecho de leito entre duas secoes transversais.
##
## `p0`/`p1` sao os pontos no eixo e `lado0`/`lado1` os vetores unitarios que
## apontam para a direita da estrada em cada um deles. Vem de fora porque quem
## sabe a curva e o caminho, nao o kit.
##
## `desgaste` de 0 a 1 escurece o trecho inteiro. E o que faz a estrada ter
## trechos de barro mais fundo e trechos mais secos sem precisar de outra
## textura: a mesma celula com a cor variando ao longo do caminho.
static func leito(sup: Dictionary, p0: Vector3, lado0: Vector3, p1: Vector3,
		lado1: Vector3, desgaste: float) -> void:
	var tom := lerpf(1.0, 0.78, clampf(desgaste, 0.0, 1.0))
	# Micro-relevo: onda longa + ripple curto + sulco nas trilhas (ref 04 / TP).
	var und0 := Vector3(0.0,
		0.055 * sin(p0.z * 1.35 + p0.x * 0.55)
		+ 0.028 * sin(p0.z * 4.2 + p0.x * 1.1)
		+ 0.012 * sin(p0.x * 3.8), 0.0)
	var und1 := Vector3(0.0,
		0.055 * sin(p1.z * 1.35 + p1.x * 0.55)
		+ 0.028 * sin(p1.z * 4.2 + p1.x * 1.1)
		+ 0.012 * sin(p1.x * 3.8), 0.0)
	for faixa: Array in SECAO:
		var e0: float = faixa[0]
		var e1: float = faixa[1]
		var celula: Vector2i = faixa[2]
		var cor: Color = faixa[3]
		var tom_faixa := tom * (1.06 if celula == C_BARRO else (0.96 if celula == C_CASCALHO else 1.0))
		# Trilha de pneu fica um pouco mais cava — leitura de relevo no facho e no TP.
		var sulco0 := Vector3.ZERO
		var sulco1 := Vector3.ZERO
		if celula == C_BARRO and absf((e0 + e1) * 0.5) > 0.6 and absf((e0 + e1) * 0.5) < 1.7:
			sulco0 = Vector3(0.0, -0.035, 0.0)
			sulco1 = Vector3(0.0, -0.035, 0.0)
		quad(sup, M_LEITO,
			p0 + lado0 * e0 + und0 + sulco0, p0 + lado0 * e1 + und0 * 0.7 + sulco0,
			p1 + lado1 * e1 + und1 * 0.7 + sulco1, p1 + lado1 * e0 + und1 + sulco1,
			celula, Color(cor.r * tom_faixa, cor.g * tom_faixa, cor.b * tom_faixa))


## Mancha de barro escuro solta no meio do leito: o que sobrou da ultima chuva.
##
## Fica meio centimetro acima do leito, e nao no mesmo plano. Coplanar de
## verdade briga com o leito pelo mesmo pixel e a mancha pisca a cada quadro —
## o mesmo defeito que o piso do parque teve, e a mesma correcao.
static func poca(sup: Dictionary, centro: Vector3, lado: Vector3,
		frente: Vector3, tamanho: Vector2) -> void:
	var e := lado * (tamanho.x * 0.5)
	var f := frente * (tamanho.y * 0.5)
	var c := centro + Vector3(0.0, 0.005, 0.0)
	quad(sup, M_LEITO, c - e - f, c + e - f, c + e + f, c - e + f,
		C_POCA, Color(0.55, 0.28, 0.18))


# --- mato de beira ----------------------------------------------------------

## Um tufo de planta em cruz, preso pelo pe.
##
## Dois planos cruzados, e nao um: um plano so desaparece de perfil, e o carro
## passa RENTE a beira — o tufo que some quando o capo chega nele e pior que
## tufo nenhum.
static func tufo(sup: Dictionary, base: Vector3, celula: Vector2i,
		tamanho: float, giro: float, cor: Color) -> void:
	for k in 2:
		var t := Transform3D(Basis(Vector3.UP, giro + PI * 0.5 * float(k)),
			base + Vector3(0.0, tamanho * 0.5, 0.0))
		AtlasKit.folha_ao_vento(sup, M_MATO, Vector2(tamanho, tamanho), t,
			celula, cor)


## A faixa de mato que forra a beira do leito, dos dois lados.
##
## Sorteia celula, tamanho e giro por tufo. O que faz a beira nao ler como
## fileira e o desvio lateral: cada tufo entra num ponto qualquer da faixa de
## um metro e meio entre o leito e a primeira arvore, e nao numa linha.
static func beira(sup: Dictionary, p: Vector3, lado: Vector3,
		rng: RandomNumberGenerator, quantos: int = 7) -> void:
	const CELULAS: Array[Vector2i] = [C_CAPIM, C_CAPIM, C_CAPIM_RALO,
		C_CAPIM_SECO, C_SAMAMBAIA, C_FOLHA_LARGA, C_MOITA_BAIXA, C_FLOR,
		C_GALHO_SECO, C_MOITA_BAIXA]
	for _i in quantos:
		var s := 1.0 if rng.randf() < 0.5 else -1.0
		var d := rng.randf_range(MEIA_PISTA - 0.7, MEIA_PISTA + 3.2)
		var onde := p + lado * (d * s) + lado.cross(Vector3.UP).normalized() * rng.randf_range(-0.55, 0.55)
		var celula: Vector2i = CELULAS[rng.randi() % CELULAS.size()]
		var tam := rng.randf_range(0.65, 1.55)
		if celula == C_FOLHA_LARGA:
			tam *= 1.35
		if celula == C_MOITA_BAIXA:
			tam *= 1.15
		# O tom claro sobe com o tamanho. Planta alta pega o sol raso que o
		# rasteiro nao pega, e essa diferenca e o que da profundidade a beira.
		var cor := Color(1.0, 1.0, 1.0).lerp(Color(0.68, 0.74, 0.58),
			rng.randf_range(0.0, 0.6))
		tufo(sup, onde, celula, tam, rng.randf_range(0.0, TAU), cor)


# --- arvores ----------------------------------------------------------------

## Conifera de mata fechada: alta, estreita e com a saia de baixo fechada.
##
## E a silhueta que domina a print — o pinheiro escuro recortado contra o
## laranja do poente. Cinco saias, e nao quatro: a quinta e a que fecha a ponta
## e faz a arvore terminar em bico em vez de em tronco cortado.
##
## Devolve o raio da base, que quem planta usa para nao encostar duas.
static func conifera(sup: Dictionary, base: Vector3, porte: float,
		rng: RandomNumberGenerator) -> float:
	var altura := lerpf(9.0, 16.0, porte)
	var raio := lerpf(1.5, 2.4, porte)
	var tronco := lerpf(0.26, 0.40, porte)

	# Fuste ate um terco da altura. Acima disso a saia comeca, e o tronco so
	# reaparece em pedacos entre uma saia e outra — que e como se ve tronco numa
	# mata de verdade.
	var fuste := altura * 0.34
	KitModular.caixa_flex(sup, M_CASCA, base + Vector3(0.0, fuste * 0.5, 0.0),
		Vector3(tronco, fuste, tronco), CASCA_TOM, rng.randf_range(0.0, TAU),
		base.y, base.y + altura, 0.0, CEDE_TRONCO,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	var cor := VERDES[rng.randi() % VERDES.size()]
	var camadas := 5
	for i in camadas:
		var t := float(i) / float(camadas - 1)
		# Afunilamento quadratico. Linear da um cone reto, que le como arvore de
		# natal; o quadratico deixa a saia de baixo larga e as de cima juntas,
		# que e o desenho de conifera adulta.
		var largura := raio * 2.0 * (1.0 - t * t * 0.82)
		var y := altura * lerpf(0.26, 0.99, t)
		var alta := altura * 0.16
		# A saia de baixo e opaca e as de cima recortam no alfa. Assim a base
		# fecha o tronco, que e onde a mata precisa ser parede, e o topo fica
		# rendilhado contra o ceu, que e onde ela precisa ser silhueta.
		KitModular.caixa_flex(sup,
			M_FOLHA if i == 0 else M_FOLHA_RECORTE,
			base + Vector3(0.0, y, 0.0),
			Vector3(largura, alta, largura * rng.randf_range(0.86, 1.1)),
			cor.lerp(Color.WHITE, t * 0.14), rng.randf_range(0.0, 0.9),
			base.y, base.y + altura, CEDE_COPA * 0.25, CEDE_COPA * 0.7,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	return raio


## Arvore de folha larga da mata: fuste comprido e copa alta e curta.
##
## A diferenca para a do parque esta nas proporcoes, e ela e o assunto: aqui o
## fuste come 55% da altura, porque numa mata fechada a arvore sobe procurando
## luz e so abre copa em cima. E por isso que uma mata vista de dentro e um
## corredor de troncos com um teto verde longe, e nao um mar de copas.
static func arvore(sup: Dictionary, base: Vector3, porte: float,
		rng: RandomNumberGenerator, seca: bool = false) -> float:
	var altura := lerpf(8.5, 15.0, porte)
	var raio := lerpf(1.8, 3.0, porte)
	var tronco := lerpf(0.28, 0.46, porte)
	var fuste := altura * 0.55

	var giro := rng.randf_range(0.0, TAU)
	var inclina := rng.randf_range(-0.05, 0.05)
	var desvio := Vector3(sin(giro) * inclina, 0.0, cos(giro) * inclina) * fuste
	KitModular.caixa_flex(sup, M_CASCA, base + Vector3(0.0, fuste * 0.28, 0.0),
		Vector3(tronco, fuste * 0.56, tronco), CASCA_TOM, giro,
		base.y, base.y + altura, 0.0, CEDE_TRONCO,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_flex(sup, M_CASCA,
		base + desvio * 0.5 + Vector3(0.0, fuste * 0.78, 0.0),
		Vector3(tronco * 0.8, fuste * 0.56, tronco * 0.8), CASCA_TOM, giro + 0.5,
		base.y, base.y + altura, 0.0, CEDE_TRONCO,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	var topo := base + desvio + Vector3(0.0, fuste, 0.0)
	var paleta := SECOS if seca else VERDES
	var cor := paleta[rng.randi() % paleta.size()]
	var vao := altura - fuste

	# Nucleo opaco no meio da copa. Sem ele os blocos de fora ficam soltos em
	# volta do nada e, contra o ceu claro do poente, a copa aparece vazada — o
	# defeito e muito mais visivel aqui do que na cidade noturna, porque atras
	# dela ha luz em vez de preto.
	KitModular.caixa_flex(sup, M_FOLHA, topo + Vector3(0.0, vao * 0.45, 0.0),
		Vector3(raio * 1.2, vao * 0.62, raio * 1.2), cor,
		rng.randf_range(0.0, TAU), base.y, base.y + altura,
		CEDE_COPA * 0.4, CEDE_COPA * 0.8, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	var n := rng.randi_range(4, 6)
	for i in n:
		var t := float(i) / float(n)
		var ang := t * TAU * 1.6 + rng.randf_range(-0.3, 0.3)
		var alto := lerpf(0.12, 0.94, t) + rng.randf_range(-0.06, 0.06)
		var afunila := clampf(1.0 - absf(alto - 0.5) * 1.3, 0.3, 1.0)
		var dist := raio * afunila * rng.randf_range(0.2, 0.5)
		var lado := raio * afunila * rng.randf_range(0.8, 1.15)
		var tom := cor.lerp(Color.WHITE, rng.randf_range(-0.1, 0.18))
		tom.a = 1.0
		KitModular.caixa_flex(sup, M_FOLHA_RECORTE,
			topo + Vector3(cos(ang) * dist, vao * alto, sin(ang) * dist),
			Vector3(lado, lado * rng.randf_range(0.62, 0.9),
				lado * rng.randf_range(0.85, 1.1)),
			tom, ang, base.y, base.y + altura,
			CEDE_COPA * 0.5, CEDE_COPA, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	return raio


## Massa de mata do fundo: dois ou tres blocos grandes de folha, sem tronco.
##
## E o que fecha o corredor a partir de vinte metros. Uma mata de verdade a essa
## distancia nao mostra arvore nenhuma — mostra uma parede de folha com buracos
## de luz — e desenhar arvore inteira ali custaria seis vezes mais para produzir
## exatamente esta imagem depois que a nevoa passa por cima.
static func massa(sup: Dictionary, base: Vector3, largura: float,
		altura: float, rng: RandomNumberGenerator) -> void:
	var cor := VERDES[rng.randi() % VERDES.size()].lerp(Color("2f3d28"), 0.35)
	cor.a = 1.0
	for i in rng.randi_range(2, 3):
		var desvio := Vector3(rng.randf_range(-largura * 0.3, largura * 0.3),
			0.0, rng.randf_range(-1.5, 1.5))
		var h := altura * rng.randf_range(0.7, 1.05)
		KitModular.caixa_flex(sup, M_FOLHA_RECORTE,
			base + desvio + Vector3(0.0, h * 0.5, 0.0),
			Vector3(largura * rng.randf_range(0.8, 1.2), h,
				largura * rng.randf_range(0.5, 0.9)),
			cor.lerp(Color.WHITE, float(i) * 0.05), rng.randf_range(0.0, TAU),
			base.y, base.y + h, CEDE_COPA * 0.2, CEDE_COPA * 0.55,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)


# --- mobilia de beira de estrada --------------------------------------------

## Tronco caido, meio enterrado no mato. Um a cada tantos trechos.
##
## Existe pelo mesmo motivo que a copa seca: quebra a repeticao. Uma mata em que
## nada caiu nunca le como mata velha.
static func tronco_caido(sup: Dictionary, base: Vector3, comprimento: float,
		giro: float, rng: RandomNumberGenerator) -> void:
	var b := Basis(Vector3.UP, giro) * Basis(Vector3.FORWARD, PI * 0.5)
	KitModular.caixa_flex_inclinada(sup, M_CASCA,
		base + Vector3(0.0, 0.22, 0.0),
		Vector3(0.44, comprimento, 0.44), CASCA_TOM.lerp(Color("564a3c"), 0.4),
		b, base.y, base.y + 0.5, 0.0, 0.0, QUAD_FOLHA)
	# O mato que cresceu por cima. E o que enterra o tronco no chao em vez de
	# deixar ele pousado como um lapis em cima da mesa.
	for _i in rng.randi_range(2, 4):
		var t := rng.randf_range(-0.4, 0.4) * comprimento
		var onde := base + Vector3(sin(giro) * t, 0.0, cos(giro) * t)
		tufo(sup, onde, C_MOITA_BAIXA, rng.randf_range(0.5, 0.8),
			rng.randf_range(0.0, TAU), Color(0.9, 0.92, 0.86))


## Marco de quilometro: o pilarzinho branco de concreto da beira.
##
## E o unico objeto de mao humana que a estrada tem, e por isso ele importa
## mais do que o tamanho sugere: sem nada construido, a mata poderia ser
## qualquer mata. Com ele, aquilo e uma estrada que alguem mediu.
static func marco(sup: Dictionary, base: Vector3, giro: float) -> void:
	KitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, 0.34, 0.0),
		Vector3(0.24, 0.68, 0.16), Color(0.86, 0.84, 0.78), giro,
		PSXMesh.FACE_TODAS, 4.0)
	KitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, 0.62, 0.0),
		Vector3(0.25, 0.14, 0.17), Color(0.34, 0.31, 0.28), giro,
		PSXMesh.FACE_TODAS, 4.0)


## Mourao de cerca com dois fios. Aparece em trecho de pasto, quando a mata
## abre. Nao ha arame de verdade: dois fios finos de metal escuro leem como
## cerca a qualquer distancia em que ela seja visivel.
static func cerca(sup: Dictionary, a: Vector3, b: Vector3,
		rng: RandomNumberGenerator) -> void:
	var delta := b - a
	var comp := delta.length()
	if comp < 1.0:
		return
	var dir := delta / comp
	var giro := atan2(dir.x, dir.z)
	var n := maxi(2, int(comp / 2.1))
	for i in n + 1:
		var p := a + dir * (comp * float(i) / float(n))
		var alt := rng.randf_range(1.15, 1.4)
		# Mourao grosso — precisa ler no facho (ref 04).
		KitModular.caixa_cor(sup, M_TABUA, p + Vector3(0.0, alt * 0.5, 0.0),
			Vector3(0.16, alt, 0.16), Color("7a6548").lerp(Color("5a4a36"), rng.randf() * 0.4),
			giro + rng.randf_range(-0.12, 0.12), PSXMesh.FACE_TODAS, 4.0)
	# Travessas de madeira + fio: silhueta de cerca, nao so fio fino.
	for y: float in [0.48, 0.78, 1.08]:
		var meio := a + delta * 0.5 + Vector3(0.0, y, 0.0)
		var esp := 0.06 if y < 1.0 else 0.035
		var mat := M_TABUA if y < 1.0 else M_METAL
		var cor := Color("6e5a42") if y < 1.0 else Color(0.38, 0.36, 0.32)
		KitModular.caixa_cor(sup, mat, meio,
			Vector3(esp, esp, comp), cor, giro, PSXMesh.FACE_TODAS, 6.0)



## Cipó / galho pendurado sobre a pista — fecha o corredor por cima.
##
## Dois planos cruzados pendurados de um ponto alto; o pe fica na beira e a
## ponta cai sobre o leito. Sem isto a mata e so parede lateral e o quadro
## perde o "teto" que a ref 04 mostra.
static func cipo(sup: Dictionary, ancora: Vector3, sobre_pista: Vector3,
		rng: RandomNumberGenerator) -> void:
	var meio := ancora.lerp(sobre_pista, 0.55) + Vector3(0.0, rng.randf_range(-0.15, 0.45), 0.0)
	var comp := ancora.distance_to(sobre_pista)
	var dir := (sobre_pista - ancora).normalized()
	var giro := atan2(dir.x, dir.z)
	var cor := Color(0.22, 0.32, 0.16).lerp(Color(0.40, 0.48, 0.26), rng.randf())
	# Cordão principal (galho fino) — um pouco mais grosso pra silhueta no para-brisa.
	KitModular.caixa_cor(sup, M_CASCA, meio,
		Vector3(0.09, 0.09, comp * 0.95), Color("3d3228"), giro,
		PSXMesh.FACE_TODAS, 6.0)
	# Folhas/cipós pendurados densos — entram no topo do windshield (ref 04).
	for k in rng.randi_range(6, 9):
		var t := rng.randf_range(0.08, 0.95)
		var p := ancora.lerp(sobre_pista, t)
		var queda := rng.randf_range(1.3, 3.0)
		tufo(sup, p - Vector3(0.0, queda * 0.42, 0.0),
			C_GALHO_SECO if rng.randf() < 0.35 else C_FOLHA_LARGA,
			queda * 0.62, rng.randf_range(0.0, TAU), cor)
		if rng.randf() < 0.55:
			tufo(sup, p - Vector3(rng.randf_range(-0.35, 0.35), queda * 0.55, rng.randf_range(-0.25, 0.25)),
				C_SAMAMBAIA if rng.randf() < 0.5 else C_MOITA_BAIXA,
				queda * 0.4, rng.randf_range(0.0, TAU), cor.lerp(Color(0.35, 0.42, 0.22), 0.3))


## Casinha / oratório de beira — sujeito do facho (ref 04).
##
## Caixa branca gasta + telhado de duas águas. Baixa de propósito: tem de
## caber inteira no cone do farol a ~12–18 m, senão some na nevoa.
static func casa_beira(sup: Dictionary, base: Vector3, giro: float,
		rng: RandomNumberGenerator) -> void:
	var larg := rng.randf_range(2.6, 3.4)
	var fund := rng.randf_range(2.1, 2.7)
	var alt := rng.randf_range(1.85, 2.35)
	# Madeira gasta clara — precisa pegar o facho (ref 04 casinha).
	var parede := Color(0.96, 0.92, 0.82).lerp(Color(0.84, 0.78, 0.66), rng.randf() * 0.35)
	var telha := Color(0.58, 0.30, 0.18).lerp(Color(0.40, 0.20, 0.12), rng.randf())
	var pedra := Color(0.48, 0.44, 0.38).lerp(Color(0.36, 0.40, 0.30), 0.35)
	# Base de alvenaria / pedra (ref 04) — eleva e ancora a casinha.
	var h_base := 0.42
	KitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, h_base * 0.5, 0.0),
		Vector3(larg + 0.45, h_base, fund + 0.4), pedra, giro,
		PSXMesh.FACE_TODAS, 3.0)
	var corpo_y := h_base
	# Corpo de madeira sobre a base.
	KitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, corpo_y + alt * 0.5, 0.0),
		Vector3(larg, alt, fund), parede, giro, PSXMesh.FACE_TODAS, 3.0)
	# Telhado em V raso.
	KitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, corpo_y + alt + 0.38, 0.0),
		Vector3(larg + 0.4, 0.58, fund + 0.3), telha, giro,
		PSXMesh.FACE_TODAS, 3.0)
	# Cumeeira escura — silhueta no facho.
	KitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, corpo_y + alt + 0.7, 0.0),
		Vector3(larg * 0.2, 0.18, fund + 0.15), Color(0.32, 0.22, 0.14), giro,
		PSXMesh.FACE_TODAS, 4.0)
	# Porta escura + janela — legibilidade no facho.
	var frente := Basis(Vector3.UP, giro) * Vector3(0.0, 0.0, fund * 0.5 + 0.03)
	KitModular.caixa_cor(sup, M_TABUA, base + frente + Vector3(0.0, corpo_y + 0.65, 0.0),
		Vector3(0.62, 1.2, 0.07), Color(0.22, 0.16, 0.12), giro,
		PSXMesh.FACE_TODAS, 4.0)
	KitModular.caixa_cor(sup, M_TABUA, base + frente + Vector3(larg * 0.3, corpo_y + 1.25, 0.0),
		Vector3(0.5, 0.45, 0.06), Color(0.12, 0.16, 0.22), giro,
		PSXMesh.FACE_TODAS, 4.0)
	# Arbustos no pe — cola a casa no chao sem tapar a fachada.
	for _i in rng.randi_range(3, 5):
		var ang := rng.randf_range(-1.2, 1.2) + (PI if rng.randf() < 0.35 else 0.0)
		var d := rng.randf_range(1.35, 2.4)
		var off := Basis(Vector3.UP, giro) * Vector3(sin(ang) * d, 0.0, cos(ang) * d)
		tufo(sup, base + off,
			C_MOITA_BAIXA if rng.randf() < 0.6 else C_SAMAMBAIA,
			rng.randf_range(0.75, 1.25), ang,
			Color(0.72, 0.80, 0.60))


## Muro baixo de pedra / tijolo musgoso na beira (ref 04, lado esquerdo).
static func muro_baixo(sup: Dictionary, a: Vector3, b: Vector3,
		rng: RandomNumberGenerator) -> void:
	var delta := b - a
	var comp := delta.length()
	if comp < 0.8:
		return
	var dir := delta / comp
	var giro := atan2(dir.x, dir.z)
	var n := maxi(1, int(comp / 1.4))
	for i in n:
		var p := a + dir * (comp * (float(i) + 0.5) / float(n))
		var h := rng.randf_range(0.45, 0.75)
		var w := comp / float(n) * 0.92
		KitModular.caixa_cor(sup, M_TABUA, p + Vector3(0.0, h * 0.5, 0.0),
			Vector3(0.28, h, w), Color(0.42, 0.40, 0.34).lerp(Color(0.3, 0.38, 0.26), 0.35),
			giro, PSXMesh.FACE_TODAS, 3.5)
