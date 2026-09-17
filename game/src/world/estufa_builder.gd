## A estufa atras da porta dos fundos da casa da fumaca.
##
## Mesmo contrato de todo interior — dados puros, sem no nenhum, montado na
## thread enquanto a porta abre. Ver Interiores._planta.
##
## O que este comodo tem de dizer
## ------------------------------
## A sala da frente e escura, baixa, quente e cheia de gente. Esta e o oposto
## exato dela em todos os eixos, e e por isso que a porta entre as duas vale a
## pena existir:
##
##   sala        2,45 m de pe direito   luz amber   ar parado e sujo   som alto
##   estufa      2,85 m                 luz branca  ar em movimento    zumbido
##
## Passar de uma para a outra em dois segundos e a coisa toda. Um comodo bonito
## atras de uma porta nao vale nada se for parecido com o comodo da frente.
##
## E uma INSTALACAO, e nao um canteiro. A diferenca esta no equipamento: vaso de
## feltro qualquer um tem; o que diz "isto aqui e montado" e o duto no teto, o
## temporizador na parede, a mangueira gotejando em cada vaso e a manta
## espelhada forrando tudo. A planta e o assunto, mas o equipamento e o que faz
## a planta ser levada a serio.
##
## E uma OPERACAO, e nao uma instalacao
## ------------------------------------
## Ate a fase passada a sala era um quadro: dezesseis plantas prontas, sempre as
## mesmas, sempre no mesmo ponto. Bonita na primeira visita e morta na segunda,
## porque nao havia o que fazer ali nem o que mudar.
##
## Agora a sala tem um CICLO, e ele e o do Schedule I: vaso vazio, terra,
## semente, agua, tempo, colheita. Quem faz o ciclo andar sao tres coisas, e as
## tres precisam estar na planta do comodo:
##
##   de onde sai   a estacao de insumos — sacos de terra, caixa de sementes e
##                 o tanque, todos no mesmo canto, porque buscar e parte do
##                 trabalho e trabalho sem distancia nao e trabalho
##   onde acontece as seis linhas de vaso, que agora nascem em fases
##                 diferentes: as duas ultimas VAZIAS, que e o convite
##   para onde vai a prateleira de potes em cima da bancada, que enche e e o
##                 unico lugar onde o trabalho de ontem aparece hoje
##
## As plantas nao sao mais desenhadas aqui. Este arquivo diz ONDE os vasos
## estao; o que ha dentro de cada um sai do WorldState pela `Plantio` e e
## desenhado pela `Plantacao`, que refaz a propria malha quando alguma coisa
## muda. Ver plantacao.gd.
##
## Planta, em metros, origem no canto sul-oeste:
##
##   z=12.0 +--------------------------------------+
##          |  [canteiro]      ||      [canteiro]  |   6 linhas de 2 vasos
##          |  [canteiro]      ||      [canteiro]  |   de cada lado, com o
##          |  [canteiro]      ||      [canteiro]  |   corredor no meio
##          |  [canteiro]      ||      [canteiro]  |
##          |  [canteiro]      ||      [canteiro]  |   as duas ultimas
##   z=3.55 |  [canteiro]      ||      [canteiro]  |   comecam vazias
##          |                                      |
##          | [bancada]   [varal]      [insumos]   |
##   z=0    +--------------[porta]-----------------+
##         x=0                                  x=7.6
class_name EstufaBuilder
extends RefCounted

const LARGURA := 7.6
const FUNDO := 12.0
const ALTURA := 2.85
const ALTURA_PORTA := 2.1

## Onde o jogador aparece, e para onde olha. Entra de costas para a porta com o
## corredor inteiro pela frente: e o unico enquadramento em que as seis linhas
## de planta aparecem de uma vez.
const ENTRADA := Vector3(3.8, 0.0, 1.35)
const OLHAR := Vector3(3.8, 1.45, 8.4)

## Materiais. Quatro, e cada um existe por uma razao diferente — ver
## tools/gerar_materiais.py.
const MAT: StringName = &"estufa"
const MAT_FOLHA: StringName = &"estufa_folha"
const MAT_RECORTE: StringName = &"estufa_recorte"
const MAT_LUZ: StringName = &"estufa_luz"

## Celulas do atlas da casa, linhas 5 e 6. Ver tools/gerar_casa.py.
const C_FOLHA := Vector2i(0, 5)
const C_BUD := Vector2i(1, 5)
const C_VASO := Vector2i(2, 5)
const C_MYLAR := Vector2i(3, 5)
const C_REFLETOR := Vector2i(4, 5)
const C_MANGUEIRA := Vector2i(5, 5)
const C_TANQUE := Vector2i(6, 5)
const C_PISO := Vector2i(0, 6)
const C_PAINEL := Vector2i(1, 6)
const C_POTE := Vector2i(2, 6)
const C_SECAGEM := Vector2i(3, 6)
const C_SACO := Vector2i(4, 6)
const C_DUTO := Vector2i(5, 6)
const C_LONA := Vector2i(6, 6)
const C_TERRA := Vector2i(7, 6)
const C_LENTE := Vector2i(3, 4)
## Linha 7, colunas 4 a 7: o que entra na sala. O pote vazio existe porque o
## cheio ja existia, e uma prateleira que enche precisa dos dois.
const C_POTE_VAZIO := Vector2i(4, 7)
const C_SACO_TERRA := Vector2i(5, 7)
const C_REGADOR := Vector2i(6, 7)
const C_SEMENTES := Vector2i(7, 7)
## Emprestadas da sala da frente: e o mesmo atlas, e madeira e saquinho ja
## existem la. Celula nova so quando nao ha celula que sirva.
const C_MADEIRA := Vector2i(6, 1)
const C_SAQUINHO := Vector2i(1, 3)

## Os dois canteiros, em X, e as seis linhas, em Z. O corredor no meio tem
## 3,0 m: e a medida em que o jogador anda entre as plantas sem ficar preso e
## ainda assim tem folha dos dois lados do enquadramento.
const CANTEIROS: Array[float] = [1.05, 2.30, 5.30, 6.55]
const LINHAS: Array[float] = [3.55, 5.00, 6.45, 7.90, 9.35, 10.80]

## Altura do vaso. A planta e desenhada pela `Plantacao` e cresce; o vaso e
## sempre o mesmo, e e dele que sai a colisao — que nao muda de fase nenhuma.
const VASO := 0.46

## A estacao de insumos, no canto leste da area de trabalho. Os tres juntos e de
## proposito: e um LUGAR, com nome e distancia, e nao tres objetos espalhados.
const TANQUE := Vector3(6.95, 0.0, 1.15)
const SACOS := Vector3(6.55, 0.0, 2.45)
const SEMENTES := Vector3(6.95, 0.0, 3.05)

## A bancada da colheita, correndo pela parede oeste, e a fila de potes em cima
## dela. Nove potes: doze colheitas por pote, tres plantas por colheita — a
## prateleira cheia e uma estufa que rodou trinta e seis plantas.
const BANCADA := Vector3(0.88, 0.0, 2.00)
const BANCADA_COMP := 2.30
const POTES := 9
const TAMPO := 0.76


static func construir(semente: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente ^ 0x5A17

	var sup: Dictionary = {}
	var props: Array[Dictionary] = []
	var colisao: Array[Dictionary] = []

	_casca(sup, colisao)
	_vasos(sup, colisao)
	_luminarias(sup, props)
	_irrigacao(sup, colisao)
	_ventilacao(sup, props)
	_bancada(sup, colisao, rng)
	_insumos(sup, colisao)
	_secagem(sup, rng)
	_plantacao(props, semente)
	_gente(props, semente)

	var tris := 0
	for mat: StringName in sup:
		tris += PSXMesh.dados_triangulos(sup[mat])

	return {
		"superficies": sup, "props": props, "colisao": colisao,
		"triangulos": tris, "entrada": ENTRADA, "olhar": OLHAR,
		"ambiente": "res://resources/fog/fog_estufa.tres",
		# A folha da porta abre para dentro da estufa, com a dobradica no lado
		# oeste do vao.
		"saida": {
			"pos": Vector3(3.8, 1.05, 0.5),
			"tamanho": Vector3(1.4, 2.1, 1.0),
			"dobradica": Vector3(3.33, 0.0, 0.07),
			"giro": 0.0,
			"angulo": 92.0,
		},
	}


## Onde esta cada vaso, na ordem em que a `Plantio` os conhece.
##
## A ordem importa e nao e arbitraria: e ela que decide quais vasos nascem
## prontos e quais nascem vazios (ver Plantio._esticar), e por isso vai por
## LINHA e nao por coluna. Assim a escada do cultivo se le andando pelo
## corredor, do fundo cheio para a frente vazia, que e a unica forma de a sala
## explicar o proprio ciclo sem uma linha de texto.
static func lugares() -> Array[Vector3]:
	var saida: Array[Vector3] = []
	for z: float in LINHAS:
		for x: float in CANTEIROS:
			saida.append(Vector3(x, 0.0, z))
	return saida


## Onde fica cada pote da prateleira, da esquerda para a direita.
static func potes() -> Array[Vector3]:
	var saida: Array[Vector3] = []
	var passo := (BANCADA_COMP - 0.34) / float(POTES - 1)
	for k in POTES:
		saida.append(Vector3(BANCADA.x - 0.14, TAMPO,
			BANCADA.z - (BANCADA_COMP - 0.34) * 0.5 + passo * float(k)))
	return saida


# --- casca ------------------------------------------------------------------

static func _casca(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	# Piso e teto em quads de um metro com a celula inteira em cada um. Ver
	# AtlasKit: esticar uma celula de 32 px por doze metros da tres pixels por
	# metro, que e borrao.
	AtlasKit.painel_repetido(sup, MAT, Vector2(LARGURA, FUNDO),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
			Vector3(LARGURA * 0.5, 0.0, FUNDO * 0.5)), C_PISO, 1.0)
	AtlasKit.painel_repetido(sup, MAT, Vector2(LARGURA, FUNDO),
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
			Vector3(LARGURA * 0.5, ALTURA, FUNDO * 0.5)), C_LONA, 1.2)

	# As quatro paredes, forradas de manta espelhada. O vao da porta fica na
	# parede sul, no eixo do corredor.
	_parede(sup, 0.0, Vector3(LARGURA * 0.5, 0.0, 0.0), LARGURA,
		Vector2(-0.48, 0.48))
	_parede(sup, PI, Vector3(LARGURA * 0.5, 0.0, FUNDO), LARGURA, Vector2.ZERO)
	_parede(sup, PI * 0.5, Vector3(0.0, 0.0, FUNDO * 0.5), FUNDO, Vector2.ZERO)
	_parede(sup, -PI * 0.5, Vector3(LARGURA, 0.0, FUNDO * 0.5), FUNDO,
		Vector2.ZERO)

	colisao.append({"tamanho": Vector3(LARGURA, 0.4, FUNDO),
		"pos": Vector3(LARGURA * 0.5, -0.2, FUNDO * 0.5)})
	colisao.append({"tamanho": Vector3(LARGURA, 0.4, FUNDO),
		"pos": Vector3(LARGURA * 0.5, ALTURA + 0.2, FUNDO * 0.5)})
	for lado: Array in [
			[Vector3(LARGURA, ALTURA, 0.3), Vector3(LARGURA * 0.5, ALTURA * 0.5, -0.15)],
			[Vector3(LARGURA, ALTURA, 0.3), Vector3(LARGURA * 0.5, ALTURA * 0.5, FUNDO + 0.15)],
			[Vector3(0.3, ALTURA, FUNDO), Vector3(-0.15, ALTURA * 0.5, FUNDO * 0.5)],
			[Vector3(0.3, ALTURA, FUNDO), Vector3(LARGURA + 0.15, ALTURA * 0.5, FUNDO * 0.5)]]:
		colisao.append({"tamanho": lado[0], "pos": lado[1]})


## Uma parede inteira, com vao opcional.
##
## `giro` e a direcao para onde a face olha: 0 e +Z, PI e -Z. `vao` esta em
## coordenada local da parede, medida do meio dela para os lados; Vector2.ZERO
## quer dizer parede cheia.
##
## A parede e feita de colunas de um metro, e o vao come as colunas que caem
## dentro dele — deixando a verga por cima, que e o que separa "porta" de
## "buraco recortado na parede".
static func _parede(sup: Dictionary, giro: float, centro: Vector3,
		comprimento: float, vao: Vector2) -> void:
	var base := Basis(Vector3.UP, giro)
	var colunas := maxi(1, roundi(comprimento))
	var w := comprimento / float(colunas)
	for c in colunas:
		var x0 := -comprimento * 0.5 + w * float(c)
		var meio := x0 + w * 0.5
		var no_vao := vao.x < vao.y and x0 + w > vao.x and x0 < vao.y
		if no_vao:
			var verga := ALTURA - ALTURA_PORTA
			AtlasKit.face(sup, MAT, Vector2(w, verga),
				Transform3D(base, centro + base
					* Vector3(meio, ALTURA_PORTA + verga * 0.5, 0.0)), C_MYLAR)
			continue
		AtlasKit.painel_repetido(sup, MAT, Vector2(w, ALTURA),
			Transform3D(base, centro + base * Vector3(meio, ALTURA * 0.5, 0.0)),
			C_MYLAR, 1.0)


# --- os vasos ---------------------------------------------------------------

## So a colisao dos vasos. O que se ve deles vem da `Plantacao`.
##
## A colisao fica aqui e nao la de proposito: o vaso e o mesmo objeto solido em
## todas as fases — vazio, com terra ou com um pe de um metro e vinte dentro —
## e uma colisao que se refaz junto com a malha seria trabalho de fisica toda
## vez que alguem rega alguma coisa, para nada mudar.
static func _vasos(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	for onde: Vector3 in lugares():
		colisao.append({"tamanho": Vector3(VASO, VASO, VASO),
			"pos": onde + Vector3(0.0, VASO * 0.5, 0.0)})
	# Uma marca de terra derramada em volta de cada vaso. Custa uma placa
	# deitada e e o que faz o piso de epoxi ler como piso de estufa usada: chao
	# limpo com planta em cima le como vitrine.
	for onde: Vector3 in lugares():
		AtlasKit.deitado(sup, MAT, onde + Vector3(0.0, 0.002, 0.0),
			Vector2(VASO * 1.5, VASO * 1.5), C_TERRA, 0.0,
			Color(1.0, 1.0, 1.0, 0.5))


## O prop que ergue a plantacao viva. Uma linha de dados: onde estao os vasos,
## onde estao os potes e onde estao os insumos. Todo o resto e da `Plantacao`.
static func _plantacao(props: Array[Dictionary], semente: int) -> void:
	var onde_vasos: Array = []
	for v: Vector3 in lugares():
		onde_vasos.append(v)
	var onde_potes: Array = []
	for p: Vector3 in potes():
		onde_potes.append(p)
	props.append({
		"tipo": "plantacao",
		"pos": Vector3.ZERO,
		"semente": semente,
		"vasos": onde_vasos,
		"potes": onde_potes,
		"saco": SACOS + Vector3(0.0, 0.45, 0.0),
		"caixa": SEMENTES + Vector3(0.0, 0.88, 0.0),
		"tanque": TANQUE + Vector3(0.0, 0.60, 0.0),
	})


# --- luz --------------------------------------------------------------------

## As luminarias, uma por par de linhas, e o facho que desce delas.
##
## O facho geometrico e o efeito principal do comodo. Numa sala com nevoa curta e
## ar humido, um cone de luz descendo sobre a folha e a diferenca entre "sala com
## planta" e "estufa" — e e a mesma peca que ja acende debaixo dos postes da rua.
static func _luminarias(sup: Dictionary, props: Array[Dictionary]) -> void:
	var y := 2.42
	for x: float in [1.68, 5.92]:
		for z: float in [4.27, 7.17, 10.07]:
			var em := Vector3(x, y, z)
			AtlasKit.caixa(sup, MAT, em, Vector3(1.45, 0.18, 0.72), C_REFLETOR)
			# A lente, virada para baixo, colada na barriga do capuz.
			AtlasKit.face(sup, MAT_LUZ, Vector2(1.30, 0.60),
				Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
					em - Vector3(0.0, 0.10, 0.0)), C_LENTE)
			# Os dois tirantes ate o teto. Luminaria flutuando sem tirante e o
			# tipo de coisa que ninguem sabe nomear e todo mundo estranha.
			for lado: float in [-0.5, 0.5]:
				AtlasKit.tubo(sup, MAT, em + Vector3(lado, 0.09, 0.0),
					em + Vector3(lado, ALTURA - y, 0.0), 0.03, C_MANGUEIRA,
					Color(0.7, 0.7, 0.72))
			props.append({
				"tipo": "lampada",
				"pos": em - Vector3(0.0, 0.16, 0.0),
				"padrao": Lampada.Padrao.ESTAVEL,
				"semente": 8100 + int(x * 10.0) + int(z * 100.0),
				# Branco levemente quente, e nao o magenta de LED moderno: este
				# jogo se passa em 1999, e a lampada de estufa da epoca era
				# vapor de sodio ou halogeneto metalico.
				"cor": Color("fff0cd"),
				"energia": 1.9,
				"alcance": 5.2,
				"facho": true,
				# Cone curto e largo: e um refletor a dois metros e meio do
				# canteiro, e nao um poste a seis metros da calcada.
				"raio_topo": 0.60,
				"raio_base": 1.15,
				"altura_facho": 1.85,
			})

	# A lampada da area de trabalho, e a setima da sala.
	#
	# Passa do orcamento de quatro fontes por chunk do ART-BIBLE, e passa por uma
	# razao que da para medir: a sala DOBROU de comprimento e ganhou uma area de
	# trabalho onde antes havia parede. As seis de cultivo ficam sobre as linhas
	# de planta, a dois metros e meio do chao e com alcance de cinco — a primeira
	# esta a 4,27 m da porta, e a bancada, a estacao de insumos e a prateleira de
	# potes caiam todas na sombra entre a porta e ela.
	#
	# A captura mostrou isso antes de eu perceber lendo: o lugar de onde sai tudo
	# que o jogador precisa era o unico canto escuro do comodo.
	#
	# E uma lampada pelada com quebra-luz de chapa, e nao um refletor: aqui
	# ninguem cultiva nada, so pesa e guarda.
	var trabalho := Vector3(3.05, 2.34, 1.75)
	AtlasKit.caixa(sup, MAT, trabalho, Vector3(0.42, 0.14, 0.42), C_REFLETOR)
	AtlasKit.tubo(sup, MAT, trabalho + Vector3(0.0, 0.07, 0.0),
		trabalho + Vector3(0.0, ALTURA - trabalho.y, 0.0), 0.02, C_MANGUEIRA,
		Color(0.7, 0.7, 0.72))
	props.append({
		"tipo": "lampada",
		"pos": trabalho - Vector3(0.0, 0.12, 0.0),
		"padrao": Lampada.Padrao.ESTAVEL,
		"semente": 8177,
		# Mais fria e mais fraca que as de cultivo: e uma lampada de galpao, e
		# nao equipamento. A diferenca de temperatura separa as duas metades da
		# sala sem uma parede.
		"cor": Color("e8ecf0"),
		"energia": 1.5,
		"alcance": 5.8,
		"facho": false,
	})


# --- agua -------------------------------------------------------------------

## Reservatorio, bomba e a mangueira que goteja em cada vaso.
##
## O gotejo nao e desenhado: seria uma particula por vaso e o ART-BIBLE nao tem
## orcamento para isso. O que existe e a TUBULACAO, que e o que se ve numa
## estufa de verdade — o cano correndo rente ao chao, o T em cada linha e o
## espeto entrando na terra.
##
## A tubulacao nao rega nada, e isso e de proposito: quem rega e quem anda ate
## la com o regador. Uma estufa que se rega sozinha nao tem o que um fazendeiro
## faca, e a profissao inteira ficaria sem assunto.
static func _irrigacao(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	AtlasKit.caixa(sup, MAT, TANQUE + Vector3(0.0, 0.5, 0.0),
		Vector3(0.72, 1.0, 0.86), C_TANQUE)
	colisao.append({"tamanho": Vector3(0.76, 1.0, 0.9),
		"pos": TANQUE + Vector3(0.0, 0.5, 0.0)})
	# A bomba em cima da tampa, com o painel virado para quem entra.
	AtlasKit.caixa(sup, MAT, TANQUE + Vector3(0.0, 1.09, 0.0),
		Vector3(0.30, 0.18, 0.24), C_PAINEL)
	# A torneira, na altura do bico do regador. E o detalhe que explica como a
	# agua sai de um tanque fechado para dentro de uma lata.
	AtlasKit.tubo(sup, MAT, TANQUE + Vector3(-0.30, 0.62, 0.30),
		TANQUE + Vector3(-0.46, 0.62, 0.30), 0.035, C_MANGUEIRA,
		Color(0.78, 0.76, 0.7))
	AtlasKit.tubo(sup, MAT, TANQUE + Vector3(-0.46, 0.62, 0.30),
		TANQUE + Vector3(-0.46, 0.50, 0.30), 0.03, C_MANGUEIRA,
		Color(0.78, 0.76, 0.7))

	var preto := Color(0.85, 0.85, 0.88)
	# Tronco: sai da bomba, desce, corre rente a parede leste ate o fundo.
	AtlasKit.tubo(sup, MAT, TANQUE + Vector3(0.0, 1.05, 0.0),
		Vector3(7.35, 1.05, TANQUE.z), 0.035, C_MANGUEIRA, preto)
	AtlasKit.tubo(sup, MAT, Vector3(7.35, 1.05, TANQUE.z),
		Vector3(7.35, 0.06, TANQUE.z), 0.035, C_MANGUEIRA, preto)
	AtlasKit.tubo(sup, MAT, Vector3(7.35, 0.06, TANQUE.z),
		Vector3(7.35, 0.06, FUNDO - 0.4), 0.035, C_MANGUEIRA, preto)
	# E atravessa o fundo para alimentar o canteiro oeste.
	AtlasKit.tubo(sup, MAT, Vector3(7.35, 0.06, FUNDO - 0.4),
		Vector3(0.35, 0.06, FUNDO - 0.4), 0.035, C_MANGUEIRA, preto)
	AtlasKit.tubo(sup, MAT, Vector3(0.35, 0.06, FUNDO - 0.4),
		Vector3(0.35, 0.06, 2.6), 0.035, C_MANGUEIRA, preto)

	# Um ramal por linha, atravessando os dois vasos daquele lado, e o espeto
	# subindo dentro de cada vaso.
	for z: float in LINHAS:
		for lado in 2:
			var xs: Array[float] = []
			var parede := 0.35
			if lado == 0:
				xs.append(CANTEIROS[0])
				xs.append(CANTEIROS[1])
			else:
				xs.append(CANTEIROS[2])
				xs.append(CANTEIROS[3])
				parede = 7.35
			# O ramal vai da parede ate o vaso MAIS DISTANTE dela, passando
			# por cima do outro: e um cano so por linha, como se faz.
			var fim: float = xs[1] if lado == 0 else xs[0]
			AtlasKit.tubo(sup, MAT, Vector3(parede, 0.06, z),
				Vector3(fim, 0.06, z), 0.026, C_MANGUEIRA, preto)
			for x: float in xs:
				AtlasKit.tubo(sup, MAT, Vector3(x, 0.06, z),
					Vector3(x, VASO + 0.02, z), 0.02, C_MANGUEIRA, preto)


# --- ar ---------------------------------------------------------------------

## Duto no teto, exaustor no fundo e dois ventiladores de parede.
##
## O duto e a peca que faz o comodo ler como montado por alguem que sabia o que
## estava fazendo. Ele nao ilustra nada: e o caminho do ar quente das
## luminarias, e por isso passa EM CIMA delas e sai pela parede do fundo.
static func _ventilacao(sup: Dictionary, props: Array[Dictionary]) -> void:
	var y := ALTURA - 0.24
	var ate := FUNDO - 1.2
	AtlasKit.tubo(sup, MAT, Vector3(1.68, y, 3.4), Vector3(1.68, y, ate),
		0.24, C_DUTO)
	AtlasKit.tubo(sup, MAT, Vector3(5.92, y, 3.4), Vector3(5.92, y, ate),
		0.24, C_DUTO)
	AtlasKit.tubo(sup, MAT, Vector3(1.5, y, ate), Vector3(6.1, y, ate),
		0.24, C_DUTO)
	# A caixa do exaustor, encostada na parede do fundo.
	AtlasKit.caixa(sup, MAT, Vector3(3.8, y, FUNDO - 0.32),
		Vector3(0.62, 0.5, 0.5), C_REFLETOR)
	AtlasKit.tubo(sup, MAT, Vector3(3.8, y, ate),
		Vector3(3.8, y, FUNDO - 0.5), 0.24, C_DUTO)

	# Tres ventiladores de parede, em cantos alternados e fora de fase: em fase,
	# os tres varrem juntos e a sala inteira ondula no mesmo compasso.
	props.append({"tipo": "ventilador", "pos": Vector3(0.22, 1.95, 4.6),
		"giro": PI * 0.5, "fase": 0.0})
	props.append({"tipo": "ventilador", "pos": Vector3(7.38, 1.95, 7.4),
		"giro": -PI * 0.5, "fase": 2.6})
	props.append({"tipo": "ventilador", "pos": Vector3(0.22, 1.95, 10.2),
		"giro": PI * 0.5, "fase": 4.9})

	# O zumbido. Sai do exaustor, e nao do ar: som de sala sem fonte no espaco
	# vira trilha, e este comodo inteiro se explica pelo equipamento.
	props.append({
		"tipo": "som_ambiente",
		"pos": Vector3(3.8, y, FUNDO - 0.5),
		"som": &"estufa_ar",
		"volume": -17.0,
		"alcance": 16.0,
	})


# --- trabalho ---------------------------------------------------------------

## A bancada da colheita: o que ja saiu do vaso.
##
## Corre pela parede oeste e nao atravessada na sala, e isso mudou de proposito:
## e ela que carrega a fila de nove potes, e uma fila so le como fila se tiver
## comprimento. Atravessada, os potes ficavam em duas fileiras curtas e a
## prateleira deixava de ser um placar.
##
## Uma sala so com planta viva le como jardim; a mesma sala com pote, balanca e
## o punhado seco em cima da bancada le como PRODUCAO, que e o que a casa da
## fumaca esconde atras daquela porta.
static func _bancada(sup: Dictionary, colisao: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	AtlasKit.caixa(sup, MAT, BANCADA + Vector3(0.0, 0.72, 0.0),
		Vector3(0.78, 0.06, BANCADA_COMP), C_MADEIRA)
	for canto: Vector3 in [
			Vector3(-0.33, 0.0, -BANCADA_COMP * 0.5 + 0.08),
			Vector3(0.33, 0.0, -BANCADA_COMP * 0.5 + 0.08),
			Vector3(-0.33, 0.0, BANCADA_COMP * 0.5 - 0.08),
			Vector3(0.33, 0.0, BANCADA_COMP * 0.5 - 0.08)]:
		AtlasKit.caixa(sup, MAT, BANCADA + canto + Vector3(0.0, 0.36, 0.0),
			Vector3(0.06, 0.72, 0.06), C_MADEIRA)
	colisao.append({"tamanho": Vector3(0.82, 0.78, BANCADA_COMP + 0.04),
		"pos": BANCADA + Vector3(0.0, 0.39, 0.0)})

	# A balanca, no canto sul do tampo, e o punhado em cima dela. Fica na ponta
	# que o jogador alcanca primeiro ao entrar: e o objeto que explica os nove
	# potes ao lado dele.
	var balanca := BANCADA + Vector3(0.14, TAMPO, -BANCADA_COMP * 0.5 + 0.22)
	AtlasKit.caixa(sup, MAT, balanca + Vector3(0.0, 0.02, 0.0),
		Vector3(0.22, 0.04, 0.18), C_PAINEL)
	AtlasKit.deitado(sup, MAT_RECORTE, balanca + Vector3(0.0, 0.05, 0.0),
		Vector2(0.14, 0.14), C_SAQUINHO, rng.randf_range(0.0, TAU))
	# Saquinhos prontos, espalhados no tampo.
	for k in 3:
		AtlasKit.deitado(sup, MAT_RECORTE,
			balanca + Vector3(0.04 * float(k), 0.0, 0.30 + float(k) * 0.16),
			Vector2(0.18, 0.18), C_SAQUINHO, rng.randf_range(0.0, TAU))

	# Sacos de papel da colheita no chao, ao pe da bancada. Sao o que SAI da
	# sala — os de terra, que sao o que entra, ficam do outro lado e sao de
	# plastico preto: duas pontas do ciclo nao podem ter o mesmo desenho.
	for onde: Vector3 in [Vector3(1.55, 0.0, 1.15), Vector3(1.42, 0.0, 2.95)]:
		AtlasKit.caixa(sup, MAT, onde + Vector3(0.0, 0.21, 0.0),
			Vector3(0.30, 0.42, 0.24), C_SACO, Color.WHITE,
			rng.randf_range(-0.4, 0.4))
		colisao.append({"tamanho": Vector3(0.34, 0.42, 0.28),
			"pos": onde + Vector3(0.0, 0.21, 0.0)})

	# O painel de controle na parede oeste: timer, disjuntor e a canaleta
	# descendo ate a bancada. E o objeto que data a instalacao.
	AtlasKit.face(sup, MAT, Vector2(0.46, 0.40),
		Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.05, 1.62, 1.05)),
		C_PAINEL)
	AtlasKit.tubo(sup, MAT, Vector3(0.06, 1.40, 1.05),
		Vector3(0.06, 0.76, 1.05), 0.04, C_MANGUEIRA, Color(0.8, 0.8, 0.82))


## A estacao de insumos: de onde a sala se abastece.
##
## Tres coisas no mesmo canto, e nenhuma delas e enfeite — cada uma corresponde
## a um degrau do ciclo, e o jogador que nao sabe o que fazer com um vaso vazio
## descobre andando ate aqui:
##
##   sacos de terra   o degrau VAZIO -> TERRA
##   caixa de semente o degrau TERRA -> SEMEADO
##   tanque           o degrau SEMEADO -> CRESCENDO, e todas as regas depois
##
## O regador fica pendurado ao lado do tanque, e nao guardado: e a ferramenta
## que se usa vinte vezes por ciclo, e ferramenta usada vinte vezes por ciclo
## nao volta para a caixa.
static func _insumos(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	# A pilha de sacos de terra. Tres, escalonados, com o de cima aberto: pilha
	# de sacos todos fechados le como carga entregue, e nao como estoque em uso.
	var alturas: Array[float] = [0.0, 0.22, 0.44]
	for k in alturas.size():
		var y: float = alturas[k]
		AtlasKit.caixa(sup, MAT,
			SACOS + Vector3(float(k) * 0.06, y + 0.11, float(k) * -0.05),
			Vector3(0.52, 0.22, 0.76), C_SACO_TERRA, Color.WHITE,
			0.12 * float(k))
	# A boca do saco de cima, com a terra a mostra.
	AtlasKit.deitado(sup, MAT, SACOS + Vector3(0.12, 0.56, -0.10),
		Vector2(0.36, 0.30), C_TERRA, 0.24)
	colisao.append({"tamanho": Vector3(0.66, 0.66, 0.86),
		"pos": SACOS + Vector3(0.06, 0.33, -0.05)})

	# A mesinha da caixa de sementes, encostada na parede leste.
	AtlasKit.caixa(sup, MAT, SEMENTES + Vector3(0.0, 0.74, 0.0),
		Vector3(0.62, 0.05, 0.54), C_MADEIRA)
	for canto: Vector3 in [Vector3(-0.26, 0.0, -0.22), Vector3(0.26, 0.0, -0.22),
			Vector3(-0.26, 0.0, 0.22), Vector3(0.26, 0.0, 0.22)]:
		AtlasKit.caixa(sup, MAT, SEMENTES + canto + Vector3(0.0, 0.37, 0.0),
			Vector3(0.05, 0.74, 0.05), C_MADEIRA)
	AtlasKit.caixa(sup, MAT, SEMENTES + Vector3(0.0, 0.83, 0.0),
		Vector3(0.40, 0.12, 0.30), C_MADEIRA, Color.WHITE, 0.0,
		Vector2i(-1, -1), C_SEMENTES)
	colisao.append({"tamanho": Vector3(0.66, 0.80, 0.58),
		"pos": SEMENTES + Vector3(0.0, 0.40, 0.0)})

	# O regador, pendurado no gancho da face do tanque virada para o corredor.
	#
	# Estava na face de tras, e na captura simplesmente nao existia: e a
	# ferramenta que o ciclo inteiro depende, e o jogador que nao a ve nao tem
	# como saber que regar e possivel. Agora fica na cara de quem entra, na
	# altura do peito, e virado para o unico lado de onde alguem olha.
	var gancho := TANQUE + Vector3(-0.40, 0.74, 0.12)
	AtlasKit.tubo(sup, MAT, gancho + Vector3(0.14, 0.14, 0.0),
		gancho + Vector3(0.0, 0.14, 0.0), 0.02, C_MANGUEIRA,
		Color(0.7, 0.7, 0.72))
	for giro: float in [-PI * 0.5, PI * 0.5]:
		AtlasKit.face(sup, MAT_RECORTE, Vector2(0.34, 0.34),
			Transform3D(Basis(Vector3.UP, giro), gancho), C_REGADOR)


## Os ramos pendurados secando, de cabeca para baixo.
##
## Ficam na entrada e nao no fundo. E a primeira coisa que o jogador atravessa
## depois de abrir a porta, e passar por baixo de um varal de ramo seco explica
## o comodo inteiro antes de ele ver uma planta viva.
static func _secagem(sup: Dictionary, rng: RandomNumberGenerator) -> void:
	var y := 2.18
	var z := 2.35
	AtlasKit.tubo(sup, MAT, Vector3(2.55, y, z), Vector3(5.15, y, z), 0.03,
		C_MANGUEIRA, Color(0.78, 0.78, 0.8))
	for k in 6:
		var x := 2.80 + float(k) * 0.44
		var comp := rng.randf_range(0.58, 0.82)
		var meio := Vector3(x, y - comp * 0.5 - 0.04, z)
		for j in 2:
			AtlasKit.face(sup, MAT_RECORTE, Vector2(0.34, comp),
				Transform3D(Basis(Vector3.UP, PI * 0.5 * float(j)
					+ rng.randf_range(-0.2, 0.2)), meio), C_SECAGEM)


# --- gente ------------------------------------------------------------------

## Quatro vagas de fazendeiro, e quem as ocupa depende da folha de pagamento.
##
## As duas primeiras sao de Jota e Helmer, que estao ali desde antes de o
## jogador saber que a sala existe. As outras duas ficam vazias ate ele
## contratar alguem na rua — e ai a pessoa da rua aparece aqui, trabalhando ao
## lado dos dois, com a mesma ficha civil que tinha na calcada.
##
## O builder nao sabe quem sao: ele roda na thread e a folha de pagamento mora
## no WorldState. O que ele descreve e a CAPACIDADE do comodo — quantos cabem e
## por onde andam —, e quem preenche e `Interiores._fazendeiro`, na thread
## principal. Mesma divisao de sempre: a planta descreve, o no resolve.
##
## Eles nao fumam. Ninguem fuma dentro da propria estufa, e quem monta uma sabe
## disso.
static func _gente(props: Array[Dictionary], semente: int) -> void:
	# Os pontos de parada de cada um cobrem metades diferentes da sala: com a
	# mesma lista, os dois convergiriam para o mesmo vaso e a estufa teria duas
	# pessoas fazendo uma coisa so.
	var oeste: Array[Vector3] = [
		Vector3(3.15, 0.0, 4.4), Vector3(3.15, 0.0, 7.3),
		Vector3(3.15, 0.0, 10.1), Vector3(2.10, 0.0, 2.6),
	]
	var leste: Array[Vector3] = [
		Vector3(4.45, 0.0, 5.1), Vector3(4.45, 0.0, 8.6),
		Vector3(4.45, 0.0, 11.0), Vector3(5.90, 0.0, 2.7),
	]
	# Quem sao, e nao so como se chamam. A cara, a altura, os oculos, o
	# alargador e a tatuagem de cada um saem de `Aparencia.ELENCO`; aqui so vai
	# a chave. Jota na vaga 0 e Helmer na 1 — a vaga 0 anda pelo lado oeste, que
	# e o que o jogador cruza primeiro ao entrar.
	var elenco: Array[StringName] = [&"jota", &"helmer", &"", &""]
	for vaga in 4:
		props.append({
			"tipo": "fazendeiro",
			"vaga": vaga,
			"personagem": elenco[vaga],
			"pos": (ENTRADA + Vector3(-0.9, 0.0, 3.0)) if vaga % 2 == 0
				else (ENTRADA + Vector3(0.9, 0.0, 4.4)),
			"semente": semente + 811 + vaga * 97,
			"pontos": oeste if vaga % 2 == 0 else leste,
			"foco": Vector3(3.8, 0.0, FUNDO - 0.5),
		})
