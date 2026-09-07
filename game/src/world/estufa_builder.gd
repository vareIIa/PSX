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
## Planta, em metros, origem no canto sul-oeste:
##
##   z=8.6 +--------------------------------------+
##         |  [canteiro]      ||      [canteiro]  |   4 linhas de 2 vasos
##         |  [canteiro]      ||      [canteiro]  |   de cada lado, com o
##         |  [canteiro]      ||      [canteiro]  |   corredor no meio
##         |  [canteiro]      ||      [canteiro]  |
##   z=2.2 |                                      |
##         | [bancada]  [secagem]      [tanque]   |
##   z=0   +--------------[porta]-----------------+
##        x=0                                  x=7.6
class_name EstufaBuilder
extends RefCounted

const LARGURA := 7.6
const FUNDO := 8.6
const ALTURA := 2.85
const ALTURA_PORTA := 2.1

## Onde o jogador aparece, e para onde olha. Entra de costas para a porta com o
## corredor inteiro pela frente: e o unico enquadramento em que as quatro linhas
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
## Emprestadas da sala da frente: e o mesmo atlas, e madeira e saquinho ja
## existem la. Celula nova so quando nao ha celula que sirva.
const C_MADEIRA := Vector2i(6, 1)
const C_SAQUINHO := Vector2i(1, 3)

## Os dois canteiros, em X, e as quatro linhas, em Z. O corredor no meio tem
## 2,4 m: e a medida em que o jogador anda entre as plantas sem ficar preso e
## ainda assim tem folha dos dois lados do enquadramento.
const CANTEIROS: Array[float] = [1.05, 2.30, 5.30, 6.55]
const LINHAS: Array[float] = [3.00, 4.45, 5.90, 7.35]

## Altura do vaso e da planta. A planta e mais baixa que o jogador de proposito:
## acima da linha dos olhos ela viraria uma parede verde e o comodo sumiria.
const VASO := 0.46
const PLANTA := 1.22


static func construir(semente: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente ^ 0x5A17

	var sup: Dictionary = {}
	var props: Array[Dictionary] = []
	var colisao: Array[Dictionary] = []

	_casca(sup, colisao)
	_canteiros(sup, colisao, rng)
	_luminarias(sup, props)
	_irrigacao(sup, colisao)
	_ventilacao(sup, props)
	_bancada(sup, colisao, rng)
	_secagem(sup, rng)
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


# --- casca ------------------------------------------------------------------

static func _casca(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	# Piso e teto em quads de um metro com a celula inteira em cada um. Ver
	# AtlasKit: esticar uma celula de 32 px por oito metros da quatro pixels por
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


# --- as plantas -------------------------------------------------------------

## Dezesseis plantas em quatro linhas.
##
## Cada uma sao tres placas cruzadas de folhagem mais duas de cabeca florida, e
## as tres placas cruzadas sao o truque que todo jogo da epoca usava para
## vegetacao: de qualquer angulo o olho ve massa em vez de cartaz, e o custo sao
## dez triangulos.
##
## O que faz a plantacao viver e o VENTO, e por isso a folhagem vai por
## `folha_ao_vento`: a rigidez no alfa do vertice prende o pe no vaso e solta a
## ponta. Sem isso a placa inteira desliza de lado e a planta le como decalque.
##
## A variacao por planta e pequena de proposito — altura, giro e um tom de verde
## — mas e o que impede as dezesseis de piscarem como uma so ao balancar.
static func _canteiros(sup: Dictionary, colisao: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	for z: float in LINHAS:
		for x: float in CANTEIROS:
			_planta(sup, colisao, Vector3(x, 0.0, z), rng)


static func _planta(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		rng: RandomNumberGenerator) -> void:
	AtlasKit.caixa(sup, MAT, base + Vector3(0.0, VASO * 0.5, 0.0),
		Vector3(VASO, VASO, VASO), C_VASO, Color.WHITE, 0.0,
		Vector2i(-1, -1), C_TERRA)
	colisao.append({"tamanho": Vector3(VASO, VASO, VASO),
		"pos": base + Vector3(0.0, VASO * 0.5, 0.0)})

	var altura := PLANTA * rng.randf_range(0.86, 1.12)
	var larg := 0.88 * rng.randf_range(0.92, 1.08)
	var giro := rng.randf_range(0.0, TAU)
	# Tom por planta. Vem do tint de vertice e nao de textura nova: e a mesma
	# economia do resto do jogo.
	var verde := 0.88 + rng.randf() * 0.24
	var cor := Color(verde * 0.94, verde, verde * 0.84)

	var meio := base + Vector3(0.0, VASO + altura * 0.5, 0.0)
	for k in 3:
		AtlasKit.folha_ao_vento(sup, MAT_FOLHA, Vector2(larg, altura),
			Transform3D(Basis(Vector3.UP, giro + PI * float(k) / 3.0), meio),
			C_FOLHA, cor)

	# As cabecas floridas, no alto. Sao a razao de a planta estar ali, e sao a
	# unica coisa laranja num comodo inteiro de verde — entao aparecem sozinhas.
	var topo := base + Vector3(0.0, VASO + altura - 0.16, 0.0)
	for k in 2:
		AtlasKit.folha_ao_vento(sup, MAT_FOLHA, Vector2(0.30, 0.46),
			Transform3D(Basis(Vector3.UP, giro + PI * 0.5 * float(k)),
				topo + Vector3(0.0, 0.10, 0.0)), C_BUD, cor)


# --- luz --------------------------------------------------------------------

## As luminarias, uma por par de linhas, e o facho que desce delas.
##
## O facho geometrico e o efeito principal do comodo. Numa sala com nevoa curta e
## ar humido, um cone de luz descendo sobre a folha e a diferenca entre "sala com
## planta" e "estufa" — e e a mesma peca que ja acende debaixo dos postes da rua.
static func _luminarias(sup: Dictionary, props: Array[Dictionary]) -> void:
	var y := 2.42
	for x: float in [1.68, 5.92]:
		for z: float in [3.72, 6.62]:
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


# --- agua -------------------------------------------------------------------

## Reservatorio, bomba e a mangueira que goteja em cada vaso.
##
## O gotejo nao e desenhado: seria uma particula por vaso e o ART-BIBLE nao tem
## orcamento para isso. O que existe e a TUBULACAO, que e o que se ve numa
## estufa de verdade — o cano correndo rente ao chao, o T em cada linha e o
## espeto entrando na terra.
static func _irrigacao(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	var tanque := Vector3(6.85, 0.0, 1.25)
	AtlasKit.caixa(sup, MAT, tanque + Vector3(0.0, 0.5, 0.0),
		Vector3(0.72, 1.0, 0.86), C_TANQUE)
	colisao.append({"tamanho": Vector3(0.76, 1.0, 0.9),
		"pos": tanque + Vector3(0.0, 0.5, 0.0)})
	# A bomba em cima da tampa, com o painel virado para quem entra.
	AtlasKit.caixa(sup, MAT, tanque + Vector3(0.0, 1.09, 0.0),
		Vector3(0.30, 0.18, 0.24), C_PAINEL)

	var preto := Color(0.85, 0.85, 0.88)
	# Tronco: sai da bomba, desce, corre rente a parede leste ate o fundo.
	AtlasKit.tubo(sup, MAT, tanque + Vector3(0.0, 1.05, 0.0),
		Vector3(7.35, 1.05, 1.25), 0.035, C_MANGUEIRA, preto)
	AtlasKit.tubo(sup, MAT, Vector3(7.35, 1.05, 1.25),
		Vector3(7.35, 0.06, 1.25), 0.035, C_MANGUEIRA, preto)
	AtlasKit.tubo(sup, MAT, Vector3(7.35, 0.06, 1.25),
		Vector3(7.35, 0.06, 8.2), 0.035, C_MANGUEIRA, preto)
	# E atravessa o fundo para alimentar o canteiro oeste.
	AtlasKit.tubo(sup, MAT, Vector3(7.35, 0.06, 8.2),
		Vector3(0.35, 0.06, 8.2), 0.035, C_MANGUEIRA, preto)
	AtlasKit.tubo(sup, MAT, Vector3(0.35, 0.06, 8.2),
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
	AtlasKit.tubo(sup, MAT, Vector3(1.68, y, 3.0), Vector3(1.68, y, 7.4),
		0.24, C_DUTO)
	AtlasKit.tubo(sup, MAT, Vector3(5.92, y, 3.0), Vector3(5.92, y, 7.4),
		0.24, C_DUTO)
	AtlasKit.tubo(sup, MAT, Vector3(1.5, y, 7.4), Vector3(6.1, y, 7.4),
		0.24, C_DUTO)
	# A caixa do exaustor, encostada na parede do fundo.
	AtlasKit.caixa(sup, MAT, Vector3(3.8, y, 8.28), Vector3(0.62, 0.5, 0.5),
		C_REFLETOR)
	AtlasKit.tubo(sup, MAT, Vector3(3.8, y, 7.4), Vector3(3.8, y, 8.1),
		0.24, C_DUTO)

	# Dois ventiladores de parede, em cantos opostos e fora de fase: em fase,
	# os dois varrem juntos e a sala inteira ondula no mesmo compasso.
	props.append({"tipo": "ventilador", "pos": Vector3(0.22, 1.95, 4.6),
		"giro": PI * 0.5, "fase": 0.0})
	props.append({"tipo": "ventilador", "pos": Vector3(7.38, 1.95, 6.4),
		"giro": -PI * 0.5, "fase": 2.6})

	# O zumbido. Sai do exaustor, e nao do ar: som de sala sem fonte no espaco
	# vira trilha, e este comodo inteiro se explica pelo equipamento.
	props.append({
		"tipo": "som_ambiente",
		"pos": Vector3(3.8, y, 8.1),
		"som": &"estufa_ar",
		"volume": -17.0,
		"alcance": 16.0,
	})


# --- trabalho ---------------------------------------------------------------

## A bancada da colheita: o que ja saiu do vaso.
##
## Esta parte e curta e faz metade do trabalho. Uma sala so com planta viva le
## como jardim; a mesma sala com pote, saco de papel, balanca e o punhado seco
## em cima da bancada le como PRODUCAO, que e o que a casa da fumaca esconde
## atras daquela porta.
static func _bancada(sup: Dictionary, colisao: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	var mesa := Vector3(1.5, 0.0, 1.15)
	AtlasKit.caixa(sup, MAT, mesa + Vector3(0.0, 0.72, 0.0),
		Vector3(1.70, 0.06, 0.78), C_MADEIRA)
	for canto: Vector3 in [Vector3(-0.78, 0.0, -0.33), Vector3(0.78, 0.0, -0.33),
			Vector3(-0.78, 0.0, 0.33), Vector3(0.78, 0.0, 0.33)]:
		AtlasKit.caixa(sup, MAT, mesa + canto + Vector3(0.0, 0.36, 0.0),
			Vector3(0.06, 0.72, 0.06), C_MADEIRA)
	colisao.append({"tamanho": Vector3(1.74, 0.78, 0.82),
		"pos": mesa + Vector3(0.0, 0.39, 0.0)})

	var tampo := 0.76
	# Tres potes de vidro, com a colheita dentro.
	for k in 3:
		AtlasKit.caixa(sup, MAT_RECORTE,
			mesa + Vector3(-0.62 + float(k) * 0.24, tampo + 0.11, -0.14),
			Vector3(0.17, 0.22, 0.17), C_POTE)
	# A balanca, e o punhado em cima dela.
	AtlasKit.caixa(sup, MAT, mesa + Vector3(0.18, tampo + 0.02, 0.10),
		Vector3(0.22, 0.04, 0.18), C_PAINEL)
	AtlasKit.deitado(sup, MAT_RECORTE,
		mesa + Vector3(0.18, tampo + 0.05, 0.10), Vector2(0.14, 0.14),
		C_SAQUINHO, rng.randf_range(0.0, TAU))
	# Saquinhos prontos, espalhados no tampo.
	for k in 3:
		AtlasKit.deitado(sup, MAT_RECORTE,
			mesa + Vector3(0.46 + float(k) * 0.02, tampo,
				-0.22 + float(k) * 0.2), Vector2(0.18, 0.18), C_SAQUINHO,
			rng.randf_range(0.0, TAU))

	# Sacos de papel no chao, embaixo e ao lado da bancada.
	for onde: Vector3 in [Vector3(0.55, 0.0, 1.9), Vector3(2.45, 0.0, 1.75)]:
		AtlasKit.caixa(sup, MAT, onde + Vector3(0.0, 0.21, 0.0),
			Vector3(0.30, 0.42, 0.24), C_SACO, Color.WHITE,
			rng.randf_range(-0.4, 0.4))
		colisao.append({"tamanho": Vector3(0.34, 0.42, 0.28),
			"pos": onde + Vector3(0.0, 0.21, 0.0)})

	# O painel de controle na parede oeste: timer, disjuntor e a canaleta
	# descendo ate a bancada. E o objeto que data a instalacao.
	AtlasKit.face(sup, MAT, Vector2(0.46, 0.40),
		Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.05, 1.62, 1.15)),
		C_PAINEL)
	AtlasKit.tubo(sup, MAT, Vector3(0.06, 1.40, 1.15),
		Vector3(0.06, 0.76, 1.15), 0.04, C_MANGUEIRA, Color(0.8, 0.8, 0.82))


## Os ramos pendurados secando, de cabeca para baixo.
##
## Ficam na entrada e nao no fundo. E a primeira coisa que o jogador atravessa
## depois de abrir a porta, e passar por baixo de um varal de ramo seco explica
## o comodo inteiro antes de ele ver uma planta viva.
static func _secagem(sup: Dictionary, rng: RandomNumberGenerator) -> void:
	var y := 2.18
	var z := 2.05
	AtlasKit.tubo(sup, MAT, Vector3(0.35, y, z), Vector3(3.05, y, z), 0.03,
		C_MANGUEIRA, Color(0.78, 0.78, 0.8))
	for k in 6:
		var x := 0.62 + float(k) * 0.46
		var comp := rng.randf_range(0.58, 0.82)
		var meio := Vector3(x, y - comp * 0.5 - 0.04, z)
		for j in 2:
			AtlasKit.face(sup, MAT_RECORTE, Vector2(0.34, comp),
				Transform3D(Basis(Vector3.UP, PI * 0.5 * float(j)
					+ rng.randf_range(-0.2, 0.2)), meio), C_SECAGEM)


# --- gente ------------------------------------------------------------------

## Uma pessoa so, cuidando das plantas.
##
## Uma, e nao tres. A sala da frente e cheia porque e uma festa; aqui atras o
## silencio e o assunto, e uma pessoa sozinha entre as linhas de planta e mais
## presenca do que tres seriam. Ela nao fuma: ninguem fuma dentro da propria
## estufa, e quem monta uma sabe disso.
static func _gente(props: Array[Dictionary], semente: int) -> void:
	var pontos: Array[Vector3] = [
		Vector3(3.80, 0.0, 3.2), Vector3(3.80, 0.0, 6.4),
		Vector3(4.10, 0.0, 7.9), Vector3(3.50, 0.0, 2.3),
	]
	props.append({
		"tipo": "convidado",
		"pos": Vector3(3.8, 0.0, 5.4),
		"semente": semente + 811,
		"papel": Convidado.Papel.LIVRE,
		"fuma": false,
		"foco": Vector3(3.8, 0.0, 8.4),
		"pontos": pontos,
	})
