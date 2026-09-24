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
## E um POCO, e ele DESCE
## ----------------------
## A casa da fumaca e terrea: 2,45 m de pe direito, telhado de fibrocimento,
## laje nenhuma. Debaixo do piso dela ha trinta metros de buraco.
##
## A estufa existe na rua, debaixo da propria casa (ver CasaFumacaBuilder,
## `ESTUFA_NA_CASA`). Ja foi um comodo teleportado dois mil metros acima da
## cidade, e a porta dos fundos abria para o limbo ou jogava o jogador la em
## cima; agora ela abre para o puxadinho do quintal, a escada desce 3,4 m, e o
## que esta no pe da escada e esta sala, montada junto com a casa.
##
## Por que para BAIXO. Atras da casa nao cabe: o quintal tem quatro metros e,
## medido nas trinta casas da fumaca da cidade, o chao atras delas desce ate
## 1,87 m (ladeira) — a laje da estufa furaria o quintal do vizinho. Debaixo da
## casa o chunk e patamar, e o chao e plano em todas. E um predio de dez andares
## nao cabe em cima de casa terrea nenhuma sem aparecer da rua.
##
## A piada continua sendo a mesma, de cabeca para baixo, e continua tendo de
## acontecer no PRIMEIRO QUADRO: o corredor central da lavoura e uma GRADE de
## piso sobre um vazio de 4,2 x 11,6 m que desce os dez andares. Quem entra
## anda em cima dele e ve, entre os pes, oito galerias acesas sumindo na nevoa.
## A grade e o que deixa o fazendeiro andar em linha reta de um vaso a outro
## sem cair no buraco, que e o que um corredor aberto com guarda-corpo faria.
##
## Anda-se nos dez. O de cima e a lavoura — a maconha de sempre, os 24 vasos, a
## bancada, os insumos —, o decimo, no FUNDO, e o quarto de Jota e Helmer, e cada
## um dos oito do meio cultiva uma variedade propria (Variedades), que cresce do
## seu jeito e casa com a placa do andar. O elevador para em todos, e Jota e
## Helmer descem nele para regar e colher.
##
## Planta da LAVOURA, em metros, origem no canto sul-oeste. O que esta entre as
## barras duplas e grade: e o poco.
##
##   z=18.0 +----------------------------------------------+
##          |                     [elev]                   |
##   z=15.0 |   [canteiro]     ++========++    [canteiro]   |  6 linhas de 2
##          |   [canteiro]     ||        ||    [canteiro]   |  vasos de cada
##          |   [canteiro]     ||  poco  ||    [canteiro]   |  lado
##          |   [canteiro]     ||  grade ||    [canteiro]   |
##          |   [canteiro]     ||        ||    [canteiro]   |  as duas ultimas
##   z=4.4  |   [canteiro]     ||        ||    [canteiro]   |  comecam vazias
##   z=3.4  |                  ++========++                 |
##          |  [bancada]      [varal]         [insumos]     |
##   z=0    +---------------------[escada]-----------------+
##         x=0                                          x=12.0
##
## Corte, em metros (y = 0 e o piso da lavoura; a casa esta 3,4 m acima):
##
##    2.75 +==============================================+  forro (piso da casa)
##         |  canteiro   |  grade  :      |  canteiro     |  a lavoura
##    0.00 +-------------+=========:======+---------------+
##         |  galeria 2  |       :        |  galeria 2    |  8 galerias de 2,75
##         |  ...        |  poco :  vazio |  ...          |
##  -24.75 +=====================+========================+  laje do fundo
##         |            ANDAR 10 - o quarto               |  4,1 m de pe direito
##  -29.25 +==============================================+
class_name EstufaBuilder
extends RefCounted

const LARGURA := 12.0
const FUNDO := 18.0
## Pe-direito de um andar comum. O terreo tem este, e e ele que poe a folha da
## planta a meio metro do forro da galeria — a sensacao de aperto embaixo e o
## que faz o poco no meio parecer alto.
const PE := 2.75
const ANDARES := 10
## A face de cima da laje do fundo, que e o chao do poco visto da grade: nove
## andares de PE abaixo da lavoura.
const FUNDO_POCO := -PE * 9.0
## O quarto do fundo e o mais alto. E o ultimo andar: tem de ser o maior.
const ALTURA_SALA := 4.1
## O piso do andar 10: a laje do fundo tem 40 cm.
const PISO_10 := FUNDO_POCO - 0.4 - ALTURA_SALA
## O forro do quarto, que e a face de baixo da laje do fundo.
const TETO_10 := PISO_10 + ALTURA_SALA
const ALTURA_PORTA := 2.1
## A boca da escada na parede sul, em x. A escada da casa chega aqui (ver
## CasaFumacaBuilder, `ESCADA_B`): mesmos 1,2 m de largura, no eixo do poco.
const BOCA := Vector2(5.4, 6.6)
## A casa de maquinas em cima do vao do elevador. A talha tem de ficar ACIMA da
## cabine parada na lavoura, e o forro da lavoura passa a 21 cm do teto dela: o
## vao sobe um nicho ate quase o piso da casa, e a polia mora la dentro.
const NICHO := 3.3


## A altura do piso de cada andar, 1 (a lavoura) a 10 (o quarto do fundo).
## A passarela das galerias: a ponta norte do poco, do vao do elevador as duas
## galerias. Sem ela a porta da cabine abria para o vazio em todo andar do meio.
const PONTE := 1.4
const PONTE_Z := POCO_Z.y - PONTE
## Onde se espera o elevador, na frente da cancela: na lavoura, em cima da
## grade; nas galerias, no meio da passarela. O y e o do andar (`nivel`).
const PATAMAR := Vector3(6.0, 0.0, 14.3)

## Os vasos de cada galeria (Variedades.VASOS_POR_ANDAR): de cada lado do poco
## tres colunas de seis, a noventa centimetros uma da outra e as linhas a 1,9 m
## — copa encostando em copa, que e como uma sala de cultivo e (a foto de
## referencia do jogador: fileira fechada debaixo da barra de luz, e o corredor
## estreito entre elas) —, e uma fileira de cinco ao pe da parede sul.
const GALERIA_COLUNAS: Array[float] = [0.55, 1.45, 2.35, 9.65, 10.55, 11.45]
const GALERIA_LINHAS: Array[float] = [3.9, 5.8, 7.7, 9.6, 11.5, 13.2]
const GALERIA_SUL_X: Array[float] = [1.5, 3.9, 6.0, 8.1, 10.5]
const GALERIA_SUL_Z := 1.0
## Os dois corredores compridos das galerias, entre os vasos e o poco.
const CORREDOR_GALERIA := Vector2(3.2, 8.8)
## A estacao de cada galeria, no canto noroeste (a lavoura tem a dela no sul):
## tanque, saco de terra e caixa de semente. O caixote da colheita fica do
## outro lado do vao.
const EST_TANQUE := Vector3(1.0, 0.0, 16.9)
const EST_SACO := Vector3(2.35, 0.0, 17.1)
const EST_SEMENTES := Vector3(3.55, 0.0, 17.3)
const EST_CAIXOTE := Vector3(9.0, 0.0, 17.0)


## Do piso ao forro. Na galeria o forro e a laje do andar de cima (14 cm).
static func pe_direito(andar: int) -> float:
	if andar >= 2 and andar < ANDARES:
		return PE - 0.14
	if andar >= ANDARES:
		return ALTURA_SALA
	return PE


## O andar de uma altura do comodo: o piso mais proximo abaixo dos pes.
static func andar_de_y(y: float) -> int:
	if y < FUNDO_POCO - 0.5:
		return ANDARES
	return clampi(int(floor(-y / PE + 0.5)) + 1, 1, ANDARES - 1)


static func nivel(n: int) -> float:
	if n >= ANDARES:
		return PISO_10
	return -PE * float(n - 1)

## O vazio no meio, em x e em z. Nenhuma laje de galeria entra aqui: e o buraco
## por onde se ve o topo do terreo.
##
## 4,2 m de largura nao e generoso por acaso. Mais estreito, o poco vira duto de
## ventilacao e a folha das galerias fecha a vista; mais largo, as galerias
## viram varandas finas e a estufa perde a lavoura. Este e o numero em que o
## jogador anda no corredor com planta dos dois lados E ve os dez andares sem
## encostar na parede.
##
## Em z o poco comeca 3,4 m depois da parede da escada. A faixa de piso cheio
## antes dele e a area de trabalho — bancada, insumos, varal —, e ela precisa
## ser chao de verdade: e onde o jogador chega pela escada e onde o fazendeiro
## busca terra e semente. A grade comeca logo depois, na linha de visada de
## quem desce: o primeiro passo na lavoura ja e em cima do vazio.
const POCO_X := Vector2(3.9, 8.1)
const POCO_Z := Vector2(3.4, 15.0)

## O vao do elevador: um entalhe de 2 x 2 na galeria norte, no eixo do poco.
##
## Fica no fim do corredor e na linha de visada da porta de proposito. O quadro
## de entrada ja olha para la, e a cabine amarela com a corrente subindo vinte e
## cinco metros e o que diz, sem texto, que o predio tem um andar de cima.
const VAO_X := Vector2(5.0, 7.0)
const VAO_Z := Vector2(15.0, 17.0)
const ELEVADOR := Vector3(6.0, 0.0, 16.0)
## O SUPER QUARTO ocupa a faixa norte do andar 10, de parede a parede.
const SALA_Z := 11.0
## A planta gigante, no chao do andar 10 (some PISO_10 para ter a altura).
const PLANTA := Vector3(2.4, 0.0, 14.6)

## Onde o jogador pisa ao sair da escada, e para onde olha. De costas para a
## boca da escada, com o corredor inteiro pela frente: e o unico enquadramento em
## que as seis linhas de planta aparecem de uma vez.
const ENTRADA := Vector3(6.0, 0.0, 1.35)
## A mira desce: cai no meio da grade, oito metros a frente e um e meio abaixo
## do piso. Enquadra as duas fileiras de vaso e, entre elas, as galerias acesas
## pela grade — que e o que este comodo tem que nenhuma estufa tem.
const OLHAR := Vector3(6.0, -1.5, 9.5)

## Materiais. Quatro, e cada um existe por uma razao diferente — ver
## tools/gerar_materiais.py.
const MAT: StringName = &"estufa"
const MAT_FOLHA: StringName = &"estufa_folha"
const MAT_RECORTE: StringName = &"estufa_recorte"
const MAT_LUZ: StringName = &"estufa_luz"
## O atlas proprio do andar 10: quadros, chapa do elevador e placas. Ver
## tools/gerar_quadros_maconha.py, que tem o mesmo mapa.
const MAT_QUADROS: StringName = &"estufa_quadros"
const RECT_CHAPA := Rect2(0.0, 832.0 / 1024.0, 0.25, 192.0 / 1024.0)
const RECT_PLACA_QUARTO := Rect2(0.25, 832.0 / 1024.0, 0.5, 96.0 / 1024.0)
const RECT_PLACA_PLANTA := Rect2(0.25, 928.0 / 1024.0, 0.5, 96.0 / 1024.0)
const RECT_EXPLODE := Rect2(0.75, 832.0 / 1024.0, 0.25, 96.0 / 1024.0)
const RECT_VOA := Rect2(0.75, 928.0 / 1024.0, 0.25, 96.0 / 1024.0)


static func rect_quadro(k: int) -> Rect2:
	return Rect2(float(k % 4) * 0.25, floorf(float(k) / 4.0) * 0.25, 0.25, 0.25)


static func rect_andar(n: int) -> Rect2:
	return Rect2(float((n - 1) % 2) * 0.5,
		(512.0 + floorf(float(n - 1) / 2.0) * 64.0) / 1024.0, 0.5, 64.0 / 1024.0)


## Uma placa com um retangulo do atlas dos quadros. `chave` e a da superficie:
## o elevador monta a propria malha e usa outra.
static func placa_atlas(sup: Dictionary, chave: StringName, centro: Vector3,
		tam: Vector2, giro: float, r: Rect2) -> void:
	var d := PSXMesh.placa_dados(tam, 100.0, Color.WHITE)
	var uvs: PackedVector2Array = d["uv"]
	# Meio pixel para dentro: filtro ponto na borda de uma celula le a vizinha.
	var m := 0.5 / 1024.0
	var rr := Rect2(r.position + Vector2(m, m), r.size - Vector2(m, m) * 2.0)
	for k in uvs.size():
		uvs[k] = rr.position + uvs[k] * rr.size
	d["uv"] = uvs
	if not sup.has(chave):
		sup[chave] = PSXMesh.dados_vazios()
	PSXMesh.acumular(sup[chave], d, Transform3D(Basis(Vector3.UP, giro), centro))

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
const CANTEIROS: Array[float] = [1.20, 2.60, 9.40, 10.80]
const LINHAS: Array[float] = [4.40, 6.40, 8.40, 10.40, 12.40, 14.40]

## Altura do vaso. A planta e desenhada pela `Plantacao` e cresce; o vaso e
## sempre o mesmo, e e dele que sai a colisao — que nao muda de fase nenhuma.
const VASO := 0.46

## A estacao de insumos, no canto leste da area de trabalho. Os tres juntos e de
## proposito: e um LUGAR, com nome e distancia, e nao tres objetos espalhados.
const TANQUE := Vector3(11.35, 0.0, 1.15)
const SACOS := Vector3(10.95, 0.0, 2.45)
const SEMENTES := Vector3(11.35, 0.0, 3.05)

## A bancada da colheita, correndo pela parede oeste, e a fila de potes em cima
## dela. Nove potes: doze colheitas por pote, tres plantas por colheita — a
## prateleira cheia e uma estufa que rodou trinta e seis plantas.
const BANCADA := Vector3(0.95, 0.0, 2.00)
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
	_grade_do_poco(sup)
	_nicho(sup)
	_galerias(sup, colisao)
	_estacoes_das_galerias(sup, colisao)
	_equipamento_das_galerias(sup, colisao, props)
	_vasos(sup, colisao)
	_vasos_das_galerias(sup, colisao)
	_luminarias(sup, props)
	_irrigacao(sup, colisao)
	_ventilacao(sup, props)
	_bancada(sup, colisao, rng)
	_insumos(sup, colisao)
	_secagem(sup, rng)
	_andaime(sup)
	_guarda_do_vao(sup, colisao)
	_placas_de_andar(sup)
	_andares_vivos(sup)
	_andar_dez(sup, colisao, props)
	props.append({"tipo": "elevador", "pos": ELEVADOR, "topo": PISO_10,
		"polia": NICHO - 0.42})
	props.append({"tipo": "super_quarto", "pos": Vector3.ZERO, "piso": PISO_10})
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
			"pos": Vector3(6.0, 1.05, 0.5),
			"tamanho": Vector3(1.4, 2.1, 1.0),
			"dobradica": Vector3(5.53, 0.0, 0.07),
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


## Todos os vasos, na ordem da `Plantio` (Variedades): os 24 da lavoura e seis
## por galeria, do 2 ao 9.
static func lugares_todos() -> Array[Vector3]:
	var saida := lugares()
	for andar in range(2, 2 + Variedades.ANDARES_DE_GALERIA):
		for v: Vector3 in vasos_da_galeria():
			saida.append(v + Vector3(0.0, nivel(andar), 0.0))
	return saida


## Os vasos de uma galeria, no plano do andar (y zero).
static func vasos_da_galeria() -> Array[Vector3]:
	var saida: Array[Vector3] = []
	for z: float in GALERIA_LINHAS:
		for x: float in GALERIA_COLUNAS:
			saida.append(Vector3(x, 0.0, z))
	for x: float in GALERIA_SUL_X:
		saida.append(Vector3(x, 0.0, GALERIA_SUL_Z))
	return saida


## De que lado de uma coisa da galeria se mexe nela, pelo corredor: a coluna de
## dentro e as estacoes, do lado do corredor; as duas de fora, pelo vao entre
## as linhas (a de dentro esta na frente); a fileira sul, pelo norte dela.
static func lado_de_mexer(onde: Vector3, afasta: float) -> Vector3:
	if onde.z < POCO_Z.x:
		return Vector3(0.0, 0.0, afasta)
	if onde.z < PONTE_Z and (onde.x < 1.9 or onde.x > LARGURA - 1.9):
		return Vector3(0.0, 0.0, -afasta)
	if onde.x < POCO_X.x:
		return Vector3(afasta, 0.0, 0.0)
	return Vector3(-afasta, 0.0, 0.0)


## A estacao de insumos e o caixote de cada andar de galeria, em coordenada do
## comodo, com a altura do andar. `saco`, `caixa` e `tanque` sao onde a mao vai
## (a mesma convencao da estacao da lavoura, ver `_plantacao`).
static func estacoes() -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for andar in range(2, 2 + Variedades.ANDARES_DE_GALERIA):
		var y := Vector3(0.0, nivel(andar), 0.0)
		saida.append({
			"andar": andar,
			"variedade": Variedades.do_andar(andar),
			"tanque": EST_TANQUE + y + Vector3(0.0, 0.6, 0.0),
			"saco": EST_SACO + y + Vector3(0.0, 0.3, 0.0),
			"caixa": EST_SEMENTES + y + Vector3(0.0, 0.75, 0.0),
			"caixote": EST_CAIXOTE + y + Vector3(0.0, 0.5, 0.0),
		})
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
	# Piso e forro em quads de um metro com a celula inteira em cada um. Ver
	# AtlasKit: esticar uma celula de 32 px por doze metros da tres pixels por
	# metro, que e borrao. O piso e a planta menos o poco (que e grade, ver
	# `_grade_do_poco`) e menos o vao do elevador.
	for f: Array in _faixas():
		AtlasKit.painel_repetido(sup, MAT, Vector2(f[1] - f[0], f[3] - f[2]),
			Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
				Vector3((f[0] + f[1]) * 0.5, 0.0, (f[2] + f[3]) * 0.5)), C_PISO, 1.0)
	# O forro da lavoura e o piso da casa por baixo. Vem de lona e nao de laje:
	# e forro de estufa, e a lona reflete a luz dos refletores de volta para a
	# folha. Com o furo do nicho da talha, em cima do vao.
	for r: Array in _menos_o_vao(0.0):
		AtlasKit.painel_repetido(sup, MAT, Vector2(r[1] - r[0], r[3] - r[2]),
			Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
				Vector3((r[0] + r[1]) * 0.5, PE, (r[2] + r[3]) * 0.5)),
			C_LONA, 1.6)
	# O chao do poco: a face de cima da laje do fundo, vista da grade trinta
	# metros acima. Com o furo por onde a cabine desce ao quarto.
	for r: Array in _menos_o_vao(0.0):
		AtlasKit.painel_repetido(sup, MAT, Vector2(r[1] - r[0], r[3] - r[2]),
			Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
				Vector3((r[0] + r[1]) * 0.5, FUNDO_POCO, (r[2] + r[3]) * 0.5)),
			C_LONA, 2.5, Color(0.62, 0.62, 0.6))

	# As quatro paredes, forradas de manta espelhada, do forro da lavoura ao
	# chao do poco. A boca da escada fica na parede sul, no eixo do poco.
	#
	# A faixa da lavoura e a do poco sao desenhadas com passos diferentes. Uma
	# parede de 24,75 m no passo de um metro sao 25 quads por coluna de um metro,
	# e as doze colunas da parede sul sozinhas dariam 600 triangulos de manta que
	# ninguem consegue olhar de perto: abaixo da lavoura a celula cobre dois
	# metros e meio, e o unico lugar onde isso se nota e o lugar onde o jogador
	# nao chega.
	_parede(sup, 0.0, Vector3(LARGURA * 0.5, 0.0, 0.0), LARGURA,
		BOCA - Vector2(LARGURA * 0.5, LARGURA * 0.5))
	_parede(sup, PI, Vector3(LARGURA * 0.5, 0.0, FUNDO), LARGURA, Vector2.ZERO)
	_parede(sup, PI * 0.5, Vector3(0.0, 0.0, FUNDO * 0.5), FUNDO, Vector2.ZERO)
	_parede(sup, -PI * 0.5, Vector3(LARGURA, 0.0, FUNDO * 0.5), FUNDO,
		Vector2.ZERO)

	# O piso da lavoura e solido por inteiro, grade incluida: e nela que se
	# anda. So o vao do elevador fica aberto (ver Elevador, a cancela).
	for r: Array in _menos_o_vao(0.0):
		colisao.append({"tamanho": Vector3(r[1] - r[0], 0.4, r[3] - r[2]),
			"pos": Vector3((r[0] + r[1]) * 0.5, -0.2, (r[2] + r[3]) * 0.5)})
	# As paredes sao solidas so na altura da lavoura. O jogador nao voa, e uma
	# caixa de colisao de 27 m de altura entra em toda consulta de fisica do
	# comodo para nunca ser tocada por ninguem. A sul abre na boca da escada.
	var solido := PE + 0.5
	var y := PE * 0.5
	for lado: Array in [
			[Vector3(BOCA.x, solido, 0.3), Vector3(BOCA.x * 0.5, y, -0.15)],
			[Vector3(LARGURA - BOCA.y, solido, 0.3),
				Vector3((LARGURA + BOCA.y) * 0.5, y, -0.15)],
			[Vector3(LARGURA, solido, 0.3), Vector3(LARGURA * 0.5, y, FUNDO + 0.15)],
			[Vector3(0.3, solido, FUNDO), Vector3(-0.15, y, FUNDO * 0.5)],
			[Vector3(0.3, solido, FUNDO), Vector3(LARGURA + 0.15, y, FUNDO * 0.5)]]:
		colisao.append({"tamanho": lado[0], "pos": lado[1]})


## A grade sobre o poco: barra de chapa a cada 12 cm e travessa a cada 60.
##
## E geometria, e nao textura com furo. Uma celula de grade esticada por 4 x 12 m
## seria borrao ou exigiria um atlas novo; em barra, cada fresta e fresta de
## verdade, a luz das galerias passa entre elas e a vertigem vem de graca. Custa
## uns 700 triangulos, menos que duas plantas.
##
## As barras correm ao longo de Z, o sentido em que se anda: vista de quem desce
## a escada, a grade le como trilho puxando o olho para o fundo da sala.
static func _grade_do_poco(sup: Dictionary) -> void:
	var aco := Color(0.44, 0.45, 0.46)
	var passo := 0.12
	var n := int((POCO_X.y - POCO_X.x) / passo)
	var folga := ((POCO_X.y - POCO_X.x) - passo * float(n)) * 0.5
	for k in n + 1:
		var x := POCO_X.x + folga + passo * float(k)
		AtlasKit.tubo(sup, MAT, Vector3(x, -0.02, POCO_Z.x),
			Vector3(x, -0.02, POCO_Z.y), 0.04, C_MANGUEIRA, aco)
	var z := POCO_Z.x + 0.3
	while z < POCO_Z.y - 0.1:
		AtlasKit.tubo(sup, MAT, Vector3(POCO_X.x, -0.05, z),
			Vector3(POCO_X.y, -0.05, z), 0.035, C_MANGUEIRA, aco.darkened(0.2))
		z += 0.6
	# A cantoneira da borda: o que diz que a grade esta APOIADA em alguma coisa.
	for par: Array in [
			[Vector3(POCO_X.x, -0.04, POCO_Z.x), Vector3(POCO_X.y, -0.04, POCO_Z.x)],
			[Vector3(POCO_X.x, -0.04, POCO_Z.y), Vector3(POCO_X.y, -0.04, POCO_Z.y)],
			[Vector3(POCO_X.x, -0.04, POCO_Z.x), Vector3(POCO_X.x, -0.04, POCO_Z.y)],
			[Vector3(POCO_X.y, -0.04, POCO_Z.x), Vector3(POCO_X.y, -0.04, POCO_Z.y)]]:
		AtlasKit.tubo(sup, MAT, par[0], par[1], 0.08, C_MANGUEIRA,
			Color(0.62, 0.55, 0.2))


## O nicho da talha: o vao do elevador sobe acima do forro ate quase o piso da
## casa, e a viga, o motor amarelo e a polia moram la dentro.
static func _nicho(sup: Dictionary) -> void:
	var lx := VAO_X.y - VAO_X.x
	var lz := VAO_Z.y - VAO_Z.x
	var alto := NICHO - PE
	var meio_y := PE + alto * 0.5
	for f: Array in [
			[Vector2(lz, alto), Vector3(VAO_X.x, meio_y, ELEVADOR.z), PI * 0.5],
			[Vector2(lz, alto), Vector3(VAO_X.y, meio_y, ELEVADOR.z), -PI * 0.5],
			[Vector2(lx, alto), Vector3(ELEVADOR.x, meio_y, VAO_Z.x), 0.0],
			[Vector2(lx, alto), Vector3(ELEVADOR.x, meio_y, VAO_Z.y), PI]]:
		AtlasKit.face(sup, MAT, f[0], Transform3D(Basis(Vector3.UP, f[2]), f[1]),
			C_LONA, Color(0.5, 0.5, 0.48))
	AtlasKit.face(sup, MAT, Vector2(lx, lz), Transform3D(Basis(Vector3.RIGHT,
		PI * 0.5), Vector3(ELEVADOR.x, NICHO, ELEVADOR.z)), C_LONA,
		Color(0.4, 0.4, 0.4))
	var zinco := Color(0.62, 0.63, 0.60)
	var viga := NICHO - 0.1
	AtlasKit.caixa(sup, MAT, Vector3(ELEVADOR.x, viga, ELEVADOR.z),
		Vector3(lx - 0.04, 0.14, 0.16), C_LONA, zinco)
	AtlasKit.caixa(sup, MAT, Vector3(ELEVADOR.x + 0.5, viga - 0.22, ELEVADOR.z),
		Vector3(0.36, 0.28, 0.28), C_LONA, Color(0.9, 0.7, 0.14))
	AtlasKit.caixa(sup, MAT, Vector3(ELEVADOR.x, viga - 0.3, ELEVADOR.z),
		Vector3(0.06, 0.32, 0.32), C_MANGUEIRA, Color(0.3, 0.3, 0.32))


## As quatro faixas de uma laje de galeria: a planta inteira menos o poco.
##
## Devolve [x0, x1, z0, z1] de cada faixa. Serve para a laje, para o forro de
## baixo e para saber onde cabe pe — tudo que e "andar" e isto menos o buraco.
static func _faixas() -> Array:
	# A faixa norte sai em tres pedacos: o entalhe do elevador come o meio dela.
	var todas := [
		[0.0, LARGURA, 0.0, POCO_Z.x],
		[0.0, VAO_X.x, POCO_Z.y, FUNDO],
		[VAO_X.y, LARGURA, POCO_Z.y, FUNDO],
		[VAO_X.x, VAO_X.y, VAO_Z.y, FUNDO],
		[0.0, POCO_X.x, POCO_Z.x, POCO_Z.y],
		[POCO_X.y, LARGURA, POCO_Z.x, POCO_Z.y],
	]
	# Faixa de largura zero e o poco encostado na parede: laje de papel, fora.
	return todas.filter(func(f: Array) -> bool:
		return f[1] - f[0] > 0.01 and f[3] - f[2] > 0.01)


## As oito galerias, 2 a 9, debaixo da grade.
##
## Cada uma e a mesma receita — laje anelar, passarela na ponta do vao,
## guarda-corpo na beira do poco e uma calha de luz acesa no forro. Repetir a
## receita e o ponto: o que convence de que ha dez andares e a mesma coisa se
## repetindo ate sumir na nevoa; o que muda de um para o outro e a planta.
##
## A luz das galerias e emissao pura, que custa zero e e o que o olho le a vinte
## metros. A luz que ACENDE a galeria e do Elevador, uma por andar e so nos
## andares perto do jogador: oito `lampada` estourariam o orcamento de fontes do
## ART-BIBLE oito vezes.
static func _galerias(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	for andar in range(2, ANDARES):
		var y := nivel(andar)
		var faixas := _faixas()
		# A passarela e laje como as outras: une as duas galerias pela ponta
		# norte do poco e e onde a porta da cabine abre.
		faixas.append([POCO_X.x, POCO_X.y, PONTE_Z, POCO_Z.y])
		for f: Array in faixas:
			var x0: float = f[0]
			var x1: float = f[1]
			var z0: float = f[2]
			var z1: float = f[3]
			var meio := Vector3((x0 + x1) * 0.5, y, (z0 + z1) * 0.5)
			var tam := Vector2(x1 - x0, z1 - z0)
			# O piso da galeria, visto de cima pela grade — a face que importa.
			AtlasKit.painel_repetido(sup, MAT, tam,
				Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), meio), C_PISO, 2.0)
			# E o forro, que so a cabine do elevador ve, de passagem.
			AtlasKit.painel_repetido(sup, MAT, tam,
				Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
					meio - Vector3(0.0, 0.14, 0.0)), C_LONA, 2.0)
			# E se pisa: cada andar tem a sua variedade e alguem para cuidar dela.
			colisao.append({"tamanho": Vector3(tam.x, 0.14, tam.y),
				"pos": meio - Vector3(0.0, 0.07, 0.0)})
		_borda_do_poco(sup, colisao, y)
		# O 9 e o "???" da lista, e e o unico andar apagado do predio. Da grade,
		# a faixa escura perto do fundo e a primeira pergunta.
		if andar != 9:
			_luz_de_galeria(sup, y)


## Guarda-corpo em volta do vazio, e a viga que fecha a beira da laje.
##
## Sem a viga a laje aparece de baixo como uma folha de papel de 14 cm; com ela
## o andar tem espessura, que e a diferenca entre pavimento e prateleira.
static func _borda_do_poco(sup: Dictionary, colisao: Array[Dictionary], y: float) -> void:
	# As quatro beiras do poco, a norte na beira da passarela; e as tres do vao
	# do elevador que nao sao a porta (a quarta tem a cancela do Elevador).
	var trechos: Array = [
		[Vector2(POCO_X.x, POCO_Z.x), Vector2(POCO_X.y, POCO_Z.x)],
		[Vector2(POCO_X.x, POCO_Z.x), Vector2(POCO_X.x, PONTE_Z)],
		[Vector2(POCO_X.y, POCO_Z.x), Vector2(POCO_X.y, PONTE_Z)],
		[Vector2(POCO_X.x, PONTE_Z), Vector2(POCO_X.y, PONTE_Z)],
		[Vector2(VAO_X.x, VAO_Z.x), Vector2(VAO_X.x, VAO_Z.y)],
		[Vector2(VAO_X.x, VAO_Z.y), Vector2(VAO_X.y, VAO_Z.y)],
		[Vector2(VAO_X.y, VAO_Z.y), Vector2(VAO_X.y, VAO_Z.x)],
	]
	var aco := Color(0.72, 0.73, 0.75)
	for t: Array in trechos:
		var a := Vector3(t[0].x, y, t[0].y)
		var b := Vector3(t[1].x, y, t[1].y)
		# A viga de beira, rente ao forro.
		AtlasKit.tubo(sup, MAT, a - Vector3(0.0, 0.07, 0.0),
			b - Vector3(0.0, 0.07, 0.0), 0.09, C_MANGUEIRA, aco)
		# O corrimao, a um metro, e o montante a cada dois metros e meio.
		AtlasKit.tubo(sup, MAT, a + Vector3(0.0, 1.0, 0.0),
			b + Vector3(0.0, 1.0, 0.0), 0.035, C_MANGUEIRA, aco)
		var comp := a.distance_to(b)
		var passos := maxi(1, int(comp / 2.5))
		for i in range(1, passos + 1):
			var em := a.lerp(b, float(i) / float(passos + 1))
			AtlasKit.tubo(sup, MAT, em, em + Vector3(0.0, 1.0, 0.0), 0.03,
				C_MANGUEIRA, aco)
		# O guarda-corpo segura: sao vinte metros de poco.
		var d := (b - a).abs()
		colisao.append({"tamanho": Vector3(maxf(d.x, 0.08), 1.1, maxf(d.z, 0.08)),
			"pos": (a + b) * 0.5 + Vector3(0.0, 0.55, 0.0)})


## A calha acesa no forro da galeria, nas duas bordas compridas do poco.
##
## E emissao, e nao luz: o que se ve de vinte metros abaixo e a LINHA acesa, e
## uma linha acesa nao precisa iluminar nada para existir. Oito andares de linha
## dupla sumindo para cima e o quadro inteiro do comodo.
static func _luz_de_galeria(sup: Dictionary, y: float) -> void:
	var comp := POCO_Z.y - POCO_Z.x - 0.6
	var meio_z := (POCO_Z.x + POCO_Z.y) * 0.5
	for x: float in [POCO_X.x - 0.55, POCO_X.y + 0.55]:
		AtlasKit.face(sup, MAT_LUZ, Vector2(0.34, comp),
			Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
				Vector3(x, y - 0.17, meio_z)),
			C_LENTE)
		AtlasKit.caixa(sup, MAT, Vector3(x, y - 0.11, meio_z),
			Vector3(0.44, 0.12, comp), C_REFLETOR)
	# A fita acesa na cara da viga, virada para o vazio. A calha de cima acende
	# a galeria de baixo e so se ve de dentro dela; o que se ve da grade, olhando
	# para o fundo, e esta linha — oito pares delas encolhendo ate a nevoa.
	for lado: Array in [[POCO_X.x + 0.05, PI * 0.5], [POCO_X.y - 0.05, -PI * 0.5]]:
		AtlasKit.face(sup, MAT_LUZ, Vector2(comp, 0.05),
			Transform3D(Basis(Vector3.UP, lado[1]),
				Vector3(lado[0], y - 0.05, meio_z)), C_LENTE)


## A estacao de insumos de cada galeria e o caixote da colheita do andar.
##
## Cada andar e autossuficiente: descer ate o 6 para regar e subir ate a lavoura
## para encher o regador seria a profissao inteira dentro do elevador. O que o
## andar cultiva fica no caixote dele, por variedade (Plantio.colheitas), e e
## de la que o jogador tira a erva daquele andar.
static func _estacoes_das_galerias(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	for e: Dictionary in estacoes():
		var y := Vector3(0.0, nivel(int(e["andar"])), 0.0)
		KitEstufa.tanque(sup, EST_TANQUE + y)
		colisao.append({"tamanho": Vector3(0.76, 1.0, 0.9),
			"pos": EST_TANQUE + y + Vector3(0.0, 0.5, 0.0)})
		KitEstufa.saco_terra(sup, EST_SACO + y, PI * 0.5, true)
		colisao.append({"tamanho": Vector3(0.8, 0.22, 0.56),
			"pos": EST_SACO + y + Vector3(0.0, 0.11, 0.0)})
		# O caixote virado de pe serve de mesa para a caixa de semente.
		AtlasKit.caixa(sup, MAT, EST_SEMENTES + y + Vector3(0.0, 0.3, 0.0),
			Vector3(0.52, 0.6, 0.44), C_MADEIRA, Color(0.86, 0.8, 0.7), 0.08)
		KitEstufa.caixa_sementes(sup, EST_SEMENTES + y + Vector3(0.0, 0.6, 0.0), PI)
		colisao.append({"tamanho": Vector3(0.56, 0.62, 0.48),
			"pos": EST_SEMENTES + y + Vector3(0.0, 0.31, 0.0)})
		# O caixote da colheita, com a variedade escrita na tampa pela cor.
		var cor := Variedades.cor(StringName(e["variedade"]))
		AtlasKit.caixa(sup, MAT, EST_CAIXOTE + y + Vector3(0.0, 0.25, 0.0),
			Vector3(0.74, 0.5, 0.52), C_MADEIRA, Color(0.9, 0.84, 0.72), -0.06)
		AtlasKit.caixa(sup, MAT, EST_CAIXOTE + y + Vector3(0.0, 0.52, 0.0),
			Vector3(0.6, 0.04, 0.4), C_LONA, cor, -0.06)
		colisao.append({"tamanho": Vector3(0.78, 0.5, 0.56),
			"pos": EST_CAIXOTE + y + Vector3(0.0, 0.25, 0.0)})


## Uma parede inteira, com vao opcional.
##
## `giro` e a direcao para onde a face olha: 0 e +Z, PI e -Z. `vao` esta em
## coordenada local da parede, medida do meio dela para os lados; Vector2.ZERO
## quer dizer parede cheia.
##
## A parede e feita de colunas de um metro, e a coluna que o vao corta e partida
## nas bordas dele: a boca tem a largura exata da escada que chega nela, com a
## verga por cima — que e o que separa "porta" de "buraco recortado na parede".
static func _parede(sup: Dictionary, giro: float, centro: Vector3,
		comprimento: float, vao: Vector2) -> void:
	var base := Basis(Vector3.UP, giro)
	var colunas := maxi(1, roundi(comprimento))
	var w := comprimento / float(colunas)
	var tem_vao := vao.x < vao.y
	for c in colunas:
		var x0 := -comprimento * 0.5 + w * float(c)
		var x1 := x0 + w
		# Os pedacos desta coluna: [de, ate, pe]. Fora do vao o pe e o chao;
		# dentro, a verga.
		var pedacos: Array = [[x0, x1, 0.0]]
		if tem_vao and x1 > vao.x and x0 < vao.y:
			pedacos = []
			if x0 < vao.x:
				pedacos.append([x0, vao.x, 0.0])
			pedacos.append([maxf(x0, vao.x), minf(x1, vao.y), ALTURA_PORTA])
			if x1 > vao.y:
				pedacos.append([vao.y, x1, 0.0])
		for p: Array in pedacos:
			var de: float = p[0]
			var ate: float = p[1]
			var pe: float = p[2]
			if ate - de < 0.01:
				continue
			# A faixa da lavoura, que e a unica que alguem olha de perto.
			AtlasKit.painel_repetido(sup, MAT, Vector2(ate - de, PE - pe),
				Transform3D(base, centro + base
					* Vector3((de + ate) * 0.5, (PE + pe) * 0.5, 0.0)), C_MYLAR,
				minf(1.0, ate - de))
		# E o resto do poco, ate a laje do fundo.
		AtlasKit.painel_repetido(sup, MAT, Vector2(w, -FUNDO_POCO),
			Transform3D(base, centro + base
				* Vector3(x0 + w * 0.5, FUNDO_POCO * 0.5, 0.0)), C_MYLAR, 2.5)


# --- elevador e andar 10 ----------------------------------------------------

## A planta inteira menos o vao do elevador, como [x0, x1, z0, z1], a partir de
## `z0`. Serve para a laje do teto do poco, para a colisao dela e para o piso do
## andar 10.
static func _menos_o_vao(z0: float) -> Array:
	return [
		[0.0, LARGURA, z0, VAO_Z.x],
		[0.0, VAO_X.x, VAO_Z.x, FUNDO],
		[VAO_X.y, LARGURA, VAO_Z.x, FUNDO],
		[VAO_X.x, VAO_X.y, VAO_Z.y, FUNDO],
	]


## O andaime do elevador: quatro montantes do quarto do fundo ao nicho da talha,
## um anel em cada laje e uma diagonal por andar nas tres faces fechadas.
##
## A face sul fica sem diagonal de proposito. E por ela que a cabine abre, e e
## por ela que quem esta descendo ve o poco passar.
static func _andaime(sup: Dictionary) -> void:
	var zinco := Color(0.62, 0.63, 0.60)
	for x: float in [VAO_X.x, VAO_X.y]:
		for z: float in [VAO_Z.x, VAO_Z.y]:
			AtlasKit.tubo(sup, MAT, Vector3(x, PISO_10, z),
				Vector3(x, NICHO - 0.05, z), 0.05, C_LONA, zinco)
	# Um anel por laje, do piso da lavoura a laje do fundo, e um no meio do
	# quarto. Descendo, a cabine passa por todos eles.
	var aneis: Array[float] = []
	for andar in range(1, ANDARES):
		aneis.append(nivel(andar))
	aneis.append(FUNDO_POCO)
	aneis.append(PISO_10 + 2.5)
	var a := Vector3(VAO_X.x, 0.0, VAO_Z.x)
	var b := Vector3(VAO_X.y, 0.0, VAO_Z.x)
	var c := Vector3(VAO_X.y, 0.0, VAO_Z.y)
	var d := Vector3(VAO_X.x, 0.0, VAO_Z.y)
	for y: float in aneis:
		var h := Vector3(0.0, y, 0.0)
		for par: Array in [[a, b], [b, c], [c, d], [d, a]]:
			AtlasKit.tubo(sup, MAT, par[0] + h, par[1] + h, 0.03, C_LONA,
				zinco)
	for k in aneis.size() - 2:
		var y0 := Vector3(0.0, aneis[k], 0.0)
		var y1 := Vector3(0.0, aneis[k + 1], 0.0)
		var vira := k % 2 == 1
		for face: Array in [[a, d], [b, c], [d, c]]:
			var de: Vector3 = face[1] if vira else face[0]
			var para: Vector3 = face[0] if vira else face[1]
			AtlasKit.tubo(sup, MAT, de + y0, para + y1, 0.022, C_LONA,
				zinco)
	# O furo na laje do fundo: as quatro bordas de 40 cm por onde a cabine
	# passa. Sem elas o furo le como textura faltando.
	var meio := FUNDO_POCO - 0.2
	var lz := VAO_Z.y - VAO_Z.x
	var lx := VAO_X.y - VAO_X.x
	for f: Array in [
			[Vector2(lz, 0.4), Vector3(VAO_X.x, meio, ELEVADOR.z), PI * 0.5],
			[Vector2(lz, 0.4), Vector3(VAO_X.y, meio, ELEVADOR.z), -PI * 0.5],
			[Vector2(lx, 0.4), Vector3(ELEVADOR.x, meio, VAO_Z.x), 0.0],
			[Vector2(lx, 0.4), Vector3(ELEVADOR.x, meio, VAO_Z.y), PI]]:
		AtlasKit.face(sup, MAT, f[0], Transform3D(Basis(Vector3.UP, f[2]), f[1]),
			C_LONA, Color(0.7, 0.7, 0.68))
	# A boca do vao na lavoura: cantoneira amarela e preta nas tres beiras que
	# nao sao a porta. E o unico buraco do piso em que se pode cair.
	for par: Array in [[a, b], [b, c], [c, d], [d, a]]:
		AtlasKit.tubo(sup, MAT, (par[0] as Vector3) + Vector3(0.0, 0.01, 0.0),
			(par[1] as Vector3) + Vector3(0.0, 0.01, 0.0), 0.07, C_LONA,
			Color(0.9, 0.7, 0.14))


## O guarda-corpo em volta do vao do elevador, na lavoura: as tres beiras que
## nao sao a porta da cabine. A quarta tem a cancela, que e do Elevador e so
## abre com a cabine parada aqui.
static func _guarda_do_vao(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	var amarelo := Color(0.9, 0.7, 0.14)
	var f := 0.1
	var trechos: Array = [
		[Vector3(VAO_X.x - f, 0.0, VAO_Z.x), Vector3(VAO_X.x - f, 0.0, VAO_Z.y + f)],
		[Vector3(VAO_X.y + f, 0.0, VAO_Z.x), Vector3(VAO_X.y + f, 0.0, VAO_Z.y + f)],
		[Vector3(VAO_X.x - f, 0.0, VAO_Z.y + f), Vector3(VAO_X.y + f, 0.0, VAO_Z.y + f)],
	]
	for t: Array in trechos:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		for y: float in [0.5, 1.0]:
			AtlasKit.tubo(sup, MAT, a + Vector3(0.0, y, 0.0), b + Vector3(0.0, y, 0.0),
				0.045, C_LONA, amarelo)
		var meio := (a + b) * 0.5
		var tam := (b - a).abs() + Vector3(0.08, 0.0, 0.08)
		colisao.append({"tamanho": Vector3(tam.x, 1.1, tam.z),
			"pos": meio + Vector3(0.0, 0.55, 0.0)})


## A faixa de cada andar, pendurada de uma galeria a outra na frente do vao.
##
## Estava pintada na parede da porta, e a dezesseis metros a nevoa comia todas:
## a primeira captura de dentro da cabine nao mostrou placa nenhuma. Aqui ela
## fica a um metro e trinta da grade e cruza a linha do olho de quem sobe, uma
## por andar. E tem as duas faces: da porta do terreo, olhando para cima, a
## pilha de faixas subindo e a lista inteira de uma vez.
static func _placas_de_andar(sup: Dictionary) -> void:
	var z := VAO_Z.x - 0.3
	var tabua := Color(0.24, 0.23, 0.21)
	for n in range(1, ANDARES):
		var y := nivel(n) + 2.2
		var centro := Vector3(ELEVADOR.x, y, z)
		AtlasKit.caixa(sup, MAT, centro, Vector3(3.08, 0.44, 0.03), C_LONA, tabua)
		for giro: float in [0.0, PI]:
			var frente := Vector3(sin(giro), 0.0, cos(giro))
			placa_atlas(sup, MAT_QUADROS, centro + frente * 0.02,
				Vector2(3.0, 0.375), giro, rect_andar(n))
		# Arame das pontas ate a viga da galeria de cima.
		var viga := nivel(n) + PE - 0.07
		for s: float in [-1.0, 1.0]:
			AtlasKit.tubo(sup, MAT, centro + Vector3(s * 1.5, 0.2, 0.0),
				Vector3(ELEVADOR.x + s * (POCO_X.y - POCO_X.x) * 0.5, viga, z),
				0.008, C_MANGUEIRA)


## O cenario dos andares interditados: a nevoa verde do 8 e a porta do 7.
##
## O que depende da viagem — as batidas nessa porta e os olhos no escuro do
## 9 — mora no Elevador, que sabe onde a cabine esta. Aqui fica so o que existe
## parado, e existe para dar razao a lista: "O ANDAR DO CHEIRO" tem cheiro, e
## "NAO DESCER (SERIO)" tem uma porta que alguem bate por dentro.
static func _andares_vivos(sup: Dictionary) -> void:
	# O cheiro do 8: placas cruzadas da fumaca do teto da casa, tingidas de verde
	# pela cor do vertice. O shader some com elas longe, entao da porta do
	# terreo nao se ve nada — so de dentro da cabine, passando.
	var y8 := nivel(8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x8C8
	for x: float in [POCO_X.x - 1.1, POCO_X.y + 1.1]:
		var z := 1.4
		while z < POCO_Z.y - 0.8:
			var em := Vector3(x + rng.randf_range(-0.4, 0.4),
				y8 + rng.randf_range(0.5, 0.9), z)
			for j in 2:
				var d := PSXMesh.placa_dados(Vector2(2.2, 1.2), 100.0,
					Color(0.5, 1.0, 0.32, 0.6))
				if not sup.has(&"fumaca_teto"):
					sup[&"fumaca_teto"] = PSXMesh.dados_vazios()
				PSXMesh.acumular(sup[&"fumaca_teto"], d, Transform3D(
					Basis(Vector3.UP, PI * 0.5 * float(j) + rng.randf_range(-0.3, 0.3)),
					em))
			z += rng.randf_range(1.8, 2.6)
	# A porta do 7, na parede do fundo atras do elevador. Quem sobe passa a um
	# metro dela, e ela tem uma tranca por fora.
	var y7 := nivel(7)
	var porta := Vector3(ELEVADOR.x, y7 + 1.0, FUNDO - 0.04)
	AtlasKit.caixa(sup, MAT, porta, Vector3(0.92, 2.0, 0.05), C_MADEIRA,
		Color(0.55, 0.5, 0.46))
	AtlasKit.caixa(sup, MAT, porta + Vector3(0.0, 0.0, -0.035),
		Vector3(0.7, 0.07, 0.03), C_LONA, Color(0.3, 0.3, 0.3))
	AtlasKit.caixa(sup, MAT, porta + Vector3(0.3, 0.0, -0.06),
		Vector3(0.09, 0.14, 0.05), C_LONA, Color(0.62, 0.55, 0.2))


## O SUPER QUARTO DA MACONHA: o andar 10, no fundo do poco, e o unico de baixo
## em que se pisa.
##
## Nao e estufa, e oficina de quimico. Uma planta so, de dois metros e meio,
## sob luz roxa; bancada de inox com becher; as duas prateleiras de que o Helmer
## fala ("explode na de baixo, voa na de cima"); e oito quadros nas paredes.
## Sai da cabine olhando para o sul, e o sul e a parede da placa e dos quadros.
static func _andar_dez(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary]) -> void:
	var h := ALTURA_SALA
	var fundo_sala := FUNDO - SALA_Z
	var meio_z := (SALA_Z + FUNDO) * 0.5
	var meio_y := PISO_10 + h * 0.5
	var cal := Color(0.86, 0.88, 0.82)

	# O piso e inteiro: a cabine chega de CIMA, pelo furo do forro, e para
	# rente a ele.
	KitModular.caixa_cor(sup, &"piso_ceramico",
		Vector3(LARGURA * 0.5, PISO_10 - 0.01, meio_z),
		Vector3(LARGURA, 0.02, fundo_sala), Color.WHITE, 0.0, PSXMesh.FACE_TOPO)
	colisao.append({"tamanho": Vector3(LARGURA, 0.4, fundo_sala),
		"pos": Vector3(LARGURA * 0.5, PISO_10 - 0.2, meio_z)})
	for r: Array in _menos_o_vao(SALA_Z):
		KitModular.caixa_cor(sup, &"teto",
			Vector3((r[0] + r[1]) * 0.5, TETO_10 + 0.01, (r[2] + r[3]) * 0.5),
			Vector3(r[1] - r[0], 0.02, r[3] - r[2]), Color.WHITE, 0.0,
			PSXMesh.FACE_BASE)
	KitModular.parede_livre(sup, &"reboco", Vector3(LARGURA * 0.5, meio_y, SALA_Z),
		Vector2(LARGURA, h), 0.0, cal)
	KitModular.parede_livre(sup, &"reboco", Vector3(LARGURA * 0.5, meio_y, FUNDO),
		Vector2(LARGURA, h), PI, cal)
	KitModular.parede_livre(sup, &"reboco", Vector3(0.0, meio_y, meio_z),
		Vector2(fundo_sala, h), PI * 0.5, cal)
	KitModular.parede_livre(sup, &"reboco", Vector3(LARGURA, meio_y, meio_z),
		Vector2(fundo_sala, h), -PI * 0.5, cal)
	for lado: Array in [
			[Vector3(LARGURA, h, 0.3), Vector3(LARGURA * 0.5, meio_y, SALA_Z - 0.15)],
			[Vector3(LARGURA, h, 0.3), Vector3(LARGURA * 0.5, meio_y, FUNDO + 0.15)],
			[Vector3(0.3, h, fundo_sala), Vector3(-0.15, meio_y, meio_z)],
			[Vector3(0.3, h, fundo_sala), Vector3(LARGURA + 0.15, meio_y, meio_z)]]:
		colisao.append({"tamanho": lado[0], "pos": lado[1]})

	# A parede sul: a placa do andar, o letreiro em cima e quatro quadros em
	# volta. E o primeiro quadro de quem sai da cabine — e Jota e Helmer ficam
	# em pe logo abaixo da placa "SO O JOTA E O HELMER", por isso ela vai acima
	# da cabeca deles e nao na altura do olho.
	placa_atlas(sup, MAT_QUADROS, Vector3(ELEVADOR.x, PISO_10 + 2.25, SALA_Z + 0.03),
		Vector2(2.4, 0.3), 0.0, rect_andar(ANDARES))
	KitModular.caixa_cor(sup, &"tabua", Vector3(ELEVADOR.x, PISO_10 + 3.0, SALA_Z + 0.02),
		Vector3(2.9, 0.62, 0.04), Color(0.55, 0.42, 0.16))
	placa_atlas(sup, MAT_QUADROS, Vector3(ELEVADOR.x, PISO_10 + 3.0, SALA_Z + 0.05),
		Vector2(2.8, 0.525), 0.0, RECT_PLACA_QUARTO)
	for q: Array in [[1.7, 0], [4.05, 2], [7.95, 3], [10.3, 1]]:
		_quadro(sup, Vector3(q[0], PISO_10 + 1.85, SALA_Z), Vector2(1.1, 1.1),
			0.0, q[1])
	for q: Array in [[12.4, 4], [16.8, 5]]:
		_quadro(sup, Vector3(0.0, PISO_10 + 1.85, q[0]), Vector2(1.0, 1.0),
			PI * 0.5, q[1])
	for q: Array in [[12.2, 6], [17.1, 7]]:
		_quadro(sup, Vector3(LARGURA, PISO_10 + 1.85, q[0]), Vector2(1.0, 1.0),
			-PI * 0.5, q[1])

	_planta_gigante(sup, colisao, PLANTA + Vector3(0.0, PISO_10, 0.0))
	_bancada_inox(sup, colisao, Vector3(11.45, PISO_10, 14.6))

	# Tres luzes: roxa na planta, branca fria na bancada, e uma quente no meio
	# para os quadros. Cada uma com o proprio capuz e lente acesa.
	for l: Array in [
			[Vector3(2.4, TETO_10 - 0.42, 14.6), Color(0.72, 0.36, 1.0), 2.4, 6.5, true, 1101],
			[Vector3(10.7, TETO_10 - 0.42, 14.6), Color(0.82, 0.92, 1.0), 1.4, 6.0, false, 1102],
			[Vector3(ELEVADOR.x, TETO_10 - 0.42, 12.6), Color("ffe0b0"), 1.3, 6.0, false, 1103]]:
		var em: Vector3 = l[0]
		var cor: Color = l[1]
		AtlasKit.caixa(sup, MAT, em + Vector3(0.0, 0.1, 0.0),
			Vector3(0.7, 0.14, 0.46), C_REFLETOR)
		AtlasKit.tubo(sup, MAT, em + Vector3(0.0, 0.17, 0.0),
			Vector3(em.x, TETO_10, em.z), 0.02, C_MANGUEIRA)
		AtlasKit.face(sup, MAT_LUZ, Vector2(0.6, 0.36),
			Transform3D(Basis(Vector3.RIGHT, PI * 0.5), em + Vector3(0.0, 0.025, 0.0)),
			C_LENTE, cor.lightened(0.3))
		var p := {
			"tipo": "lampada", "pos": em - Vector3(0.0, 0.1, 0.0),
			"padrao": Lampada.Padrao.ESTAVEL, "semente": l[5],
			"cor": cor, "energia": l[2], "alcance": l[3], "facho": l[4],
		}
		if l[4]:
			p["raio_topo"] = 0.3
			p["raio_base"] = 1.2
			p["altura_facho"] = 2.9
		props.append(p)


## Quadro com moldura dourada. A arte sai 3 cm a frente, pela mesma razao do
## KitCasa.quadro: com o snap de vertice, um centimetro nao separa dois planos.
static func _quadro(sup: Dictionary, centro: Vector3, tam: Vector2, giro: float,
		k: int) -> void:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	KitModular.caixa_cor(sup, &"tabua", centro + frente * 0.02,
		Vector3(tam.x + 0.12, tam.y + 0.12, 0.04), Color(0.62, 0.47, 0.17), giro)
	placa_atlas(sup, MAT_QUADROS, centro + frente * 0.045, tam, giro,
		rect_quadro(k))


## A planta do andar 10: dois metros e meio num vaso de duzentos litros.
##
## Nove camadas de folha em cruz, estreitando para cima, e cola no topo. E a
## mesma folha que balanca na lavoura — o ventilador nao chega aqui, mas o
## material balanca sozinho, e uma planta parada a esse tamanho le como enfeite.
static func _planta_gigante(sup: Dictionary, colisao: Array[Dictionary],
		p: Vector3) -> void:
	AtlasKit.caixa(sup, MAT, p + Vector3(0.0, 0.36, 0.0), Vector3(0.86, 0.72, 0.86),
		C_VASO, Color(0.42, 0.36, 0.32))
	AtlasKit.deitado(sup, MAT, p + Vector3(0.0, 0.725, 0.0), Vector2(0.8, 0.8),
		C_TERRA, 0.0)
	colisao.append({"tamanho": Vector3(0.9, 0.75, 0.9),
		"pos": p + Vector3(0.0, 0.375, 0.0)})
	var caule := Color(0.34, 0.46, 0.22)
	AtlasKit.tubo(sup, MAT, p + Vector3(0.0, 0.7, 0.0), p + Vector3(0.0, 3.2, 0.0),
		0.06, C_LONA, caule)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x10A
	# Sete andares de galho, quatro por andar, girando. Cada galho termina num
	# tufo de folha e numa cola em pe. O que separa esta planta de um pinheiro
	# e o VAO entre os tufos: cone fechado de folha le como arvore de Natal, e
	# foi o que a primeira captura mostrou.
	for camada in 7:
		var t := float(camada) / 6.0
		var y := 1.0 + t * 1.95
		var comp := lerpf(0.95, 0.3, t)
		for k in 4:
			var a := TAU * float(k) / 4.0 + float(camada) * 0.95 + rng.randf_range(-0.2, 0.2)
			var base := p + Vector3(0.0, y, 0.0)
			var ponta := base + Vector3(cos(a) * comp, comp * 0.45, sin(a) * comp)
			AtlasKit.tubo(sup, MAT, base, ponta, 0.022, C_LONA, caule)
			var tam := lerpf(0.75, 0.42, t)
			for j in 3:
				AtlasKit.face(sup, MAT_FOLHA, Vector2(tam, tam * 0.85),
					Transform3D(Basis(Vector3.UP, a + PI / 3.0 * float(j)),
						ponta + Vector3(0.0, 0.05, 0.0)), C_FOLHA)
			for j in 2:
				AtlasKit.face(sup, MAT_FOLHA, Vector2(0.2, 0.32),
					Transform3D(Basis(Vector3.UP, a + PI * 0.5 * float(j)),
						ponta + Vector3(0.0, 0.3, 0.0)), C_BUD)
	# A cola do topo nao mora aqui: e o que se colhe, e sai do SuperQuarto,
	# que a esconde e a devolve. Ver `colas_da_colheita`.
	# A placa na estaca, virada para o meio da sala.
	var estaca := p + Vector3(0.95, 0.0, -0.3)
	AtlasKit.tubo(sup, MAT, estaca, estaca + Vector3(0.0, 0.95, 0.0), 0.02,
		C_MANGUEIRA, Color(0.5, 0.38, 0.22))
	placa_atlas(sup, MAT_QUADROS, estaca + Vector3(0.025, 0.92, 0.0),
		Vector2(0.8, 0.15), PI * 0.5, RECT_PLACA_PLANTA)


## O que a colheita leva: a cola do topo em tres gomos e quatro colas grandes
## no meio da copa. Montado pelo SuperQuarto numa malha propria, para sumir
## quando o jogador colhe e voltar quando a planta cresce — a planta sem elas
## continua planta, e e isso que diz "ja colheram aqui".
static func colas_da_colheita(sup: Dictionary, p: Vector3) -> void:
	for g in 3:
		for j in 2:
			AtlasKit.face(sup, MAT_FOLHA, Vector2(0.34, 0.42),
				Transform3D(Basis(Vector3.UP, PI * 0.5 * float(j) + float(g)),
					p + Vector3(0.0, 3.0 + float(g) * 0.24, 0.0)), C_BUD)
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.4
		var em := p + Vector3(cos(a) * 0.42, 2.25 + float(k % 2) * 0.35, sin(a) * 0.42)
		for j in 2:
			AtlasKit.face(sup, MAT_FOLHA, Vector2(0.26, 0.4),
				Transform3D(Basis(Vector3.UP, a + PI * 0.5 * float(j)), em), C_BUD)


## A bancada de inox na parede leste e as duas prateleiras em cima dela.
##
## A de baixo diz EXPLODE e a de cima diz VOA, com os potes na cor de cada uma.
## E a fala do Helmer virada objeto: quem ler a placa antes de ouvir a frase
## entende a frase na hora.
static func _bancada_inox(sup: Dictionary, colisao: Array[Dictionary],
		b: Vector3) -> void:
	var inox := Color(0.8, 0.82, 0.84)
	AtlasKit.caixa(sup, MAT, b + Vector3(0.0, 0.9, 0.0), Vector3(0.8, 0.05, 2.3),
		C_LONA, inox)
	AtlasKit.caixa(sup, MAT, b + Vector3(0.02, 0.44, 0.0), Vector3(0.72, 0.84, 2.2),
		C_REFLETOR, Color(0.7, 0.72, 0.74))
	colisao.append({"tamanho": Vector3(0.8, 0.92, 2.3),
		"pos": b + Vector3(0.0, 0.46, 0.0)})
	var liquidos: Array[Color] = [Color(0.4, 1.0, 0.35), Color(0.75, 0.4, 1.0),
		Color(1.0, 0.7, 0.25)]
	for k in 7:
		var alto := 0.14 + float(k % 3) * 0.05
		AtlasKit.caixa(sup, MAT, b + Vector3(-0.18 + float(k % 2) * 0.12,
			0.925 + alto * 0.5, -0.95 + float(k) * 0.3), Vector3(0.09, alto, 0.09),
			C_POTE, liquidos[k % 3])
	for fila in 2:
		var y := 1.5 + float(fila) * 0.55
		var tabua := Vector3(LARGURA - 0.16, b.y + y, b.z)
		AtlasKit.caixa(sup, MAT, tabua, Vector3(0.3, 0.04, 1.8), C_LONA, inox)
		placa_atlas(sup, MAT_QUADROS, tabua + Vector3(-0.16, -0.13, 0.0),
			Vector2(0.6, 0.225), -PI * 0.5, RECT_EXPLODE if fila == 0 else RECT_VOA)
		var cor := Color(1.0, 0.45, 0.3) if fila == 0 else Color(0.45, 0.65, 1.0)
		for k in 5:
			AtlasKit.caixa(sup, MAT, tabua + Vector3(0.0, 0.1, -0.7 + float(k) * 0.35),
				Vector3(0.12, 0.16, 0.12), C_POTE, cor)


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


## O equipamento de uma galeria de cultivo, andar por andar.
##
## Uma galeria so com vaso e luz de teto le como deposito. O que diz "estufa
## montada por quem sabe" e o que esta em volta da planta: o rack de poste
## galvanizado com a barra de lampada tubular sobre cada fileira, o eletrocalha
## amarela no forro e o cabo preto caindo dela ate cada barra, a regua de
## tomada com o timer presa no poste, o ventilador de garra no poste soprando
## ao longo da fileira, o duto flexivel prateado, a mangueira de gotejo no chao
## com um espeto em cada vaso, o prato preto debaixo do vaso, o tapete de
## borracha no corredor e a sujeira de quem trabalha ali — terra derramada,
## folha seca, balde, mangueira enrolada e vaso vazio empilhado.
##
## As barras sao T5 fluorescente, e nao LED: o jogo se passa em 1999 (ver
## `_luminarias`). Acesas por emissao, alternando o branco quente e o frio. A
## luz que acende a galeria e do Elevador, so no andar de quem olha.
static func _equipamento_das_galerias(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary]) -> void:
	var zinco := Color(0.66, 0.67, 0.64)
	var preto := Color(0.16, 0.16, 0.17)
	var amarelo := Color(0.9, 0.7, 0.14)
	# As pontas do rack longe do vao por onde se chega a coluna de fora.
	var z0 := GALERIA_LINHAS[0] - 1.3
	var z1 := GALERIA_LINHAS[GALERIA_LINHAS.size() - 1] + 1.3
	for andar in range(2, 2 + Variedades.ANDARES_DE_GALERIA):
		var y := nivel(andar)
		var teto := y + pe_direito(andar)
		var rng := RandomNumberGenerator.new()
		rng.seed = 0xA17 + andar * 131
		var v := Variedades.do_andar(andar)
		for lado in 2:
			# O eixo do rack, sob a coluna do meio, e a borda do corredor.
			var xp := 1.45 if lado == 0 else LARGURA - 1.45
			var corredor := CORREDOR_GALERIA.x if lado == 0 else CORREDOR_GALERIA.y
			var dentro := 1.0 if lado == 0 else -1.0
			# Sem ternario: ternario de array nao sai tipado e a atribuicao falha.
			# Da parede para o corredor.
			var colunas: Array[float] = [GALERIA_COLUNAS[0], GALERIA_COLUNAS[1],
				GALERIA_COLUNAS[2]]
			if lado == 1:
				colunas = [GALERIA_COLUNAS[5], GALERIA_COLUNAS[4], GALERIA_COLUNAS[3]]
			# --- o rack: postes, travessas e as duas longarinas do alto
			var alto_rack := teto - 0.3
			for z: float in [z0, (z0 + z1) * 0.5, z1]:
				AtlasKit.tubo(sup, MAT, Vector3(xp, y, z), Vector3(xp, teto, z), 0.035,
					C_MANGUEIRA, zinco)
				AtlasKit.caixa(sup, MAT, Vector3(xp, y + 0.01, z), Vector3(0.14, 0.02, 0.14),
					C_REFLETOR, zinco)
				AtlasKit.tubo(sup, MAT, Vector3(colunas[0] - 0.3 * dentro, alto_rack, z),
					Vector3(colunas[2] + 0.3 * dentro, alto_rack, z), 0.025, C_MANGUEIRA, zinco)
				colisao.append({"tamanho": Vector3(0.08, pe_direito(andar), 0.08),
					"pos": Vector3(xp, y + pe_direito(andar) * 0.5, z)})
			for x: float in colunas:
				AtlasKit.tubo(sup, MAT, Vector3(x, alto_rack, z0), Vector3(x, alto_rack, z1),
					0.022, C_MANGUEIRA, zinco)
			# --- as barras de lampada. A Morcega pende do forro sobre a coluna:
			# no 2 a barra corre entre as colunas. A Girafa sobe ate o forro e
			# corre por ele: no 5 a barra encosta no teto.
			var barras: Array[float] = colunas
			if v == &"morcega":
				barras = [(colunas[0] + colunas[1]) * 0.5, (colunas[1] + colunas[2]) * 0.5]
			var y_barra := alto_rack - 0.14
			if v == &"girafa":
				y_barra = teto - 0.1
			for k in barras.size():
				var x: float = barras[k]
				var quente := (k + lado + andar) % 2 == 0
				var cor_luz := Color("fff0cd") if quente else Color("e6f2ff")
				var comp := z1 - z0 - 0.3
				var meio := Vector3(x, y_barra, (z0 + z1) * 0.5)
				AtlasKit.caixa(sup, MAT, meio, Vector3(0.26, 0.05, comp), C_REFLETOR,
					Color(0.78, 0.8, 0.82))
				# Dois tubos por calha, com um palmo de chapa entre eles. No 9, o
				# apagado, os tubos estao la e nao acendem: quem ilumina o andar e
				# a Vagalume.
				for t: float in [-0.065, 0.065]:
					var xf_tubo := Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
						meio + Vector3(t, -0.028, 0.0))
					if andar == 9:
						AtlasKit.face(sup, MAT, Vector2(0.045, comp - 0.1), xf_tubo,
							C_REFLETOR, Color(0.42, 0.44, 0.44))
					else:
						AtlasKit.face(sup, MAT_LUZ, Vector2(0.045, comp - 0.1), xf_tubo,
							C_LENTE, cor_luz)
				# Os tirantes de corrente ate a longarina.
				for zt: float in [z0 + 0.4, z1 - 0.4]:
					AtlasKit.tubo(sup, MAT, Vector3(x, y_barra + 0.025, zt),
						Vector3(x, maxf(alto_rack, y_barra + 0.03), zt), 0.006,
						C_MANGUEIRA, preto)
			# --- o eletrocalha amarelo no forro, na beira do corredor, e o cabo
			# caindo dele em barriga ate a ponta de cada barra.
			var xe := corredor + dentro * 0.45
			AtlasKit.caixa(sup, MAT, Vector3(xe, teto - 0.12, (z0 + z1) * 0.5 + 1.5),
				Vector3(0.2, 0.06, z1 - z0 + 3.0), C_LONA, amarelo)
			for z: float in [z0 + 0.2, (z0 + z1) * 0.5, z1 - 0.2]:
				AtlasKit.tubo(sup, MAT, Vector3(xe, teto - 0.09, z), Vector3(xe, teto, z),
					0.01, C_MANGUEIRA, zinco)
			for k in barras.size():
				var x: float = barras[k]
				for zc: float in [z0 + 0.15, z1 - 0.15]:
					_cabo(sup, Vector3(xe, teto - 0.13, zc), Vector3(x, y_barra + 0.02, zc),
						0.22 + rng.randf() * 0.12, preto)
			# Um cabo solto descendo o poste do meio ate a regua com o timer.
			var zm := (z0 + z1) * 0.5
			var regua := Vector3(xp + dentro * 0.06, y + 1.25, zm + 0.05)
			AtlasKit.caixa(sup, MAT, regua, Vector3(0.05, 0.36, 0.07), C_PAINEL,
				Color(0.9, 0.9, 0.88))
			AtlasKit.caixa(sup, MAT, regua + Vector3(0.0, 0.3, 0.0), Vector3(0.07, 0.12, 0.09),
				C_PAINEL, Color(0.92, 0.9, 0.84))
			_cabo(sup, Vector3(xe, teto - 0.13, zm), regua + Vector3(0.0, 0.36, 0.0),
				0.35, preto)
			for k in 3:
				_cabo(sup, regua + Vector3(0.0, 0.1 - float(k) * 0.09, 0.0),
					Vector3(colunas[k % 3], alto_rack, zm + 0.3 + float(k) * 0.4),
					0.3 + float(k) * 0.08, preto)
			# --- o ventilador de garra no poste, soprando ao longo da fileira.
			for par: Array in [[z0 + 0.12, 0.0], [z1 - 0.12, PI]]:
				var zv: float = par[0]
				AtlasKit.caixa(sup, MAT, Vector3(xp, y + 1.78, zv), Vector3(0.1, 0.08, 0.1),
					C_LONA, preto)
				props.append({"tipo": "ventilador",
					"pos": Vector3(xp, y + 1.78, zv + (0.12 if par[1] == 0.0 else -0.12)),
					"giro": par[1], "fase": rng.randf() * 6.0})
			# --- o duto flexivel prateado, rente a parede.
			var xd := 0.32 if lado == 0 else LARGURA - 0.32
			AtlasKit.tubo(sup, MAT, Vector3(xd, teto - 0.22, 2.2), Vector3(xd, teto - 0.22, 16.2),
				0.13, C_DUTO)
			# --- o chao: gotejo, prato, tapete.
			for x: float in colunas:
				AtlasKit.tubo(sup, MAT, Vector3(x + 0.26 * dentro, y + 0.02, z0 + 0.3),
					Vector3(x + 0.26 * dentro, y + 0.02, z1 - 0.3), 0.012, C_MANGUEIRA, preto)
				for z: float in GALERIA_LINHAS:
					AtlasKit.tubo(sup, MAT, Vector3(x + 0.26 * dentro, y + 0.02, z),
						Vector3(x + 0.12 * dentro, y + 0.47, z), 0.006, C_MANGUEIRA, preto)
			# A linha mestra junto da parede, do tanque da estacao ao sul.
			AtlasKit.tubo(sup, MAT, Vector3(xd, y + 0.03, z0 + 0.3),
				Vector3(xd, y + 0.03, EST_TANQUE.z - 0.5), 0.02, C_MANGUEIRA, preto)
			AtlasKit.tubo(sup, MAT, Vector3(xd, y + 0.03, z0 + 0.3),
				Vector3(colunas[2] + 0.26 * dentro, y + 0.02, z0 + 0.3), 0.016, C_MANGUEIRA, preto)
			# O tapete de borracha do corredor, em dois pedacos com a emenda.
			for metade in 2:
				var za := 2.6 + float(metade) * 6.9
				AtlasKit.deitado(sup, MAT, Vector3(corredor, y + 0.006, za + 3.4),
					Vector2(0.8, 6.8), C_LONA, 0.0, Color(0.22, 0.22, 0.23))
		# Os pratos pretos debaixo de cada vaso (o da Morcega pega o que pinga).
		if v != &"bonsai":
			for p: Vector3 in vasos_da_galeria():
				AtlasKit.caixa(sup, MAT, p + Vector3(0.0, y + 0.012, 0.0),
					Vector3(0.54, 0.024, 0.54), C_LONA, Color(0.13, 0.13, 0.14))
		# A sujeira de quem trabalha: terra e folha seca pelo chao.
		for k in 18:
			var onde := Vector3(rng.randf_range(0.3, 11.7), y + 0.004,
				rng.randf_range(0.4, 14.6))
			if onde.x > POCO_X.x - 0.1 and onde.x < POCO_X.y + 0.1 and onde.z > POCO_Z.x:
				continue
			if k % 3 == 0:
				AtlasKit.deitado(sup, MAT_FOLHA, onde, Vector2(0.16, 0.16), C_FOLHA,
					rng.randf() * TAU, Color(0.85, 0.76, 0.42))
			else:
				AtlasKit.deitado(sup, MAT, onde, Vector2(0.5, 0.35) * rng.randf_range(0.6, 1.3),
					C_TERRA, rng.randf() * TAU, Color(1.0, 1.0, 1.0, 0.55))
		# A mangueira enrolada e o balde, perto do tanque; vasos vazios empilhados
		# no canto sul-leste.
		var rolo := Vector3(2.1, y + 0.03, 15.9)
		for volta in 3:
			var r := 0.26 - float(volta) * 0.03
			var ant := rolo + Vector3(r, 0.02 * float(volta), 0.0)
			for k in range(1, 11):
				var a := TAU * float(k) / 10.0
				var pt := rolo + Vector3(cos(a) * r, 0.02 * float(volta), sin(a) * r)
				AtlasKit.tubo(sup, MAT, ant, pt, 0.02, C_MANGUEIRA, Color(0.2, 0.42, 0.2))
				ant = pt
		AtlasKit.tubo(sup, MAT, Vector3(0.55, y, 15.6), Vector3(0.55, y + 0.34, 15.6), 0.14,
			C_LONA, Color(0.2, 0.36, 0.7))
		for k in 3:
			KitEstufa.vaso(sup, Vector3(11.3, y + 0.14 * float(k), 0.55), false, 0.0,
				andar * 10 + k)
		colisao.append({"tamanho": Vector3(0.5, 0.75, 0.5),
			"pos": Vector3(11.3, y + 0.37, 0.55)})


## Um cabo pendurado entre dois pontos, com a barriga `queda` metros abaixo da
## reta. Seis pedacos: o bastante para ler como cabo, e nao como vara.
static func _cabo(sup: Dictionary, a: Vector3, b: Vector3, queda: float, cor: Color) -> void:
	var ant := a
	for k in range(1, 7):
		var t := float(k) / 6.0
		var pt := a.lerp(b, t) - Vector3(0.0, sin(t * PI) * queda, 0.0)
		AtlasKit.tubo(sup, MAT, ant, pt, 0.007, C_MANGUEIRA, cor)
		ant = pt


## A colisao dos recipientes das galerias (KitEstufa.recipiente_info: o da
## Morcega pende do forro e nao tem, o do Bonsai e a mesinha) e a terra
## derramada em volta de cada um, como na lavoura.
static func _vasos_das_galerias(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	var todos := lugares_todos()
	for i in range(Variedades.VASOS_DA_LAVOURA, todos.size()):
		var onde := todos[i]
		var andar := Variedades.andar_do_vaso(i)
		var info := KitEstufa.recipiente_info(Variedades.do_vaso(i), pe_direito(andar))
		for c: Dictionary in info["colisao"]:
			colisao.append({"tamanho": c["tamanho"], "pos": onde + Vector3(c["pos"])})
		AtlasKit.deitado(sup, MAT, onde + Vector3(0.0, 0.002, 0.0),
			Vector2(VASO * 1.5, VASO * 1.5), C_TERRA, 0.0,
			Color(1.0, 1.0, 1.0, 0.5))


## O prop que ergue a plantacao viva. Uma linha de dados: onde estao os vasos,
## onde estao os potes e onde estao os insumos. Todo o resto e da `Plantacao`.
static func _plantacao(props: Array[Dictionary], semente: int) -> void:
	var onde_vasos: Array = []
	for v: Vector3 in lugares_todos():
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
		"estacoes": estacoes(),
	})


# --- luz --------------------------------------------------------------------

## As luminarias, uma por par de linhas, e o facho que desce delas.
##
## O facho geometrico e o efeito principal do comodo. Numa sala com nevoa curta e
## ar humido, um cone de luz descendo sobre a folha e a diferenca entre "sala com
## planta" e "estufa" — e e a mesma peca que ja acende debaixo dos postes da rua.
static func _luminarias(sup: Dictionary, props: Array[Dictionary]) -> void:
	var y := 2.42
	for x: float in [1.90, 10.10]:
		for z: float in [5.40, 9.40, 13.40]:
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
					em + Vector3(lado, PE - y, 0.0), 0.03, C_MANGUEIRA,
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
	var trabalho := Vector3(5.25, 2.34, 1.75)
	AtlasKit.caixa(sup, MAT, trabalho, Vector3(0.42, 0.14, 0.42), C_REFLETOR)
	# Pendurada pelo fio no forro, a quarenta centimetros dele: e a primeira luz
	# que quem desce a escada ve, e tem de estar na altura da cabeca.
	AtlasKit.tubo(sup, MAT, trabalho + Vector3(0.0, 0.07, 0.0),
		Vector3(trabalho.x, PE, trabalho.z), 0.006, C_MANGUEIRA)
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
	# A bombona com a bomba em cima e a torneira na face do corredor, na altura
	# do bico do regador: o detalhe que explica como a agua sai de um tanque
	# fechado para dentro de uma lata (KitEstufa.tanque).
	KitEstufa.tanque(sup, TANQUE)
	colisao.append({"tamanho": Vector3(0.76, 1.0, 0.9),
		"pos": TANQUE + Vector3(0.0, 0.5, 0.0)})

	var preto := Color(0.85, 0.85, 0.88)
	# Onde o tronco corre rente a parede leste: 35 cm dela, como do lado oeste.
	var leste_x := LARGURA - 0.35
	# Tronco: sai da bomba, desce, corre rente a parede leste ate o fundo.
	AtlasKit.tubo(sup, MAT, TANQUE + Vector3(0.0, 1.05, 0.0),
		Vector3(leste_x, 1.05, TANQUE.z), 0.035, C_MANGUEIRA, preto)
	AtlasKit.tubo(sup, MAT, Vector3(leste_x, 1.05, TANQUE.z),
		Vector3(leste_x, 0.06, TANQUE.z), 0.035, C_MANGUEIRA, preto)
	AtlasKit.tubo(sup, MAT, Vector3(leste_x, 0.06, TANQUE.z),
		Vector3(leste_x, 0.06, FUNDO - 0.4), 0.035, C_MANGUEIRA, preto)
	# E atravessa o fundo para alimentar o canteiro oeste.
	AtlasKit.tubo(sup, MAT, Vector3(leste_x, 0.06, FUNDO - 0.4),
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
				parede = leste_x
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
	# Rente ao forro da galeria do segundo andar: o ar quente das luminarias sai
	# por baixo da laje, e nao vinte metros acima dela.
	var y := PE - 0.24
	# O travessao corre rente a parede do fundo, atras do andaime. A 1,2 m dela
	# ele cortava o vao do elevador na altura do teto da cabine.
	var ate := FUNDO - 0.6
	AtlasKit.tubo(sup, MAT, Vector3(1.90, y, 3.4), Vector3(1.90, y, ate),
		0.24, C_DUTO)
	AtlasKit.tubo(sup, MAT, Vector3(10.10, y, 3.4), Vector3(10.10, y, ate),
		0.24, C_DUTO)
	AtlasKit.tubo(sup, MAT, Vector3(1.7, y, ate), Vector3(10.3, y, ate),
		0.24, C_DUTO)
	# A caixa do exaustor, encostada na parede do fundo.
	AtlasKit.caixa(sup, MAT, Vector3(6.0, y, FUNDO - 0.32),
		Vector3(0.62, 0.5, 0.5), C_REFLETOR)
	AtlasKit.tubo(sup, MAT, Vector3(6.0, y, ate),
		Vector3(6.0, y, FUNDO - 0.5), 0.24, C_DUTO)

	# Tres ventiladores de parede, em cantos alternados e fora de fase: em fase,
	# os tres varrem juntos e a sala inteira ondula no mesmo compasso.
	props.append({"tipo": "ventilador", "pos": Vector3(0.22, 1.95, 6.0),
		"giro": PI * 0.5, "fase": 0.0})
	props.append({"tipo": "ventilador", "pos": Vector3(LARGURA - 0.22, 1.95, 9.6),
		"giro": -PI * 0.5, "fase": 2.6})
	props.append({"tipo": "ventilador", "pos": Vector3(0.22, 1.95, 13.4),
		"giro": PI * 0.5, "fase": 4.9})

	# O zumbido. Sai do exaustor, e nao do ar: som de sala sem fonte no espaco
	# vira trilha, e este comodo inteiro se explica pelo equipamento.
	props.append({
		"tipo": "som_ambiente",
		"pos": Vector3(6.0, y, FUNDO - 0.5),
		"som": &"estufa_ar",
		"volume": -17.0,
		"alcance": 22.0,
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
	# O visor olha para o corredor (+X), que e de onde se chega a bancada.
	var balanca := BANCADA + Vector3(0.14, TAMPO, -BANCADA_COMP * 0.5 + 0.22)
	KitEstufa.balanca(sup, balanca, PI * 0.5)
	# Saquinhos prontos, espalhados no tampo.
	for k in 3:
		KitEstufa.saquinho(sup,
			balanca + Vector3(0.04 * float(k), 0.0, 0.30 + float(k) * 0.16),
			PI * 0.5 + rng.randf_range(-0.6, 0.6))

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
	# Saco deitado tem 20 cm; em cima do outro ele cede um pouco.
	for k in 3:
		KitEstufa.saco_terra(sup,
			SACOS + Vector3(float(k) * 0.06, float(k) * 0.19, float(k) * -0.05),
			0.12 * float(k), k == 2)
	colisao.append({"tamanho": Vector3(0.66, 0.66, 0.86),
		"pos": SACOS + Vector3(0.06, 0.33, -0.05)})

	# A mesinha da caixa de sementes, encostada na parede leste.
	AtlasKit.caixa(sup, MAT, SEMENTES + Vector3(0.0, 0.74, 0.0),
		Vector3(0.62, 0.05, 0.54), C_MADEIRA)
	for canto: Vector3 in [Vector3(-0.26, 0.0, -0.22), Vector3(0.26, 0.0, -0.22),
			Vector3(-0.26, 0.0, 0.22), Vector3(0.26, 0.0, 0.22)]:
		AtlasKit.caixa(sup, MAT, SEMENTES + canto + Vector3(0.0, 0.37, 0.0),
			Vector3(0.05, 0.74, 0.05), C_MADEIRA)
	# O estojo aberto, virado para o corredor (-X).
	KitEstufa.caixa_sementes(sup, SEMENTES + Vector3(0.0, 0.765, 0.0), -PI * 0.5)
	colisao.append({"tamanho": Vector3(0.66, 0.80, 0.58),
		"pos": SEMENTES + Vector3(0.0, 0.40, 0.0)})

	# O regador, pendurado no gancho da face do tanque virada para o corredor.
	#
	# Estava na face de tras, e na captura simplesmente nao existia: e a
	# ferramenta que o ciclo inteiro depende, e o jogador que nao a ve nao tem
	# como saber que regar e possivel. Agora fica na cara de quem entra, na
	# altura do peito, e virado para o unico lado de onde alguem olha.
	#
	# O gancho sai da face do corredor entre o adesivo e o canto norte, e a alca
	# atravessada por ele: o regador pende de perfil para quem vem pelo
	# corredor, com o bico passando da quina do tanque.
	var pino := TANQUE + Vector3(0.0, 0.88, -0.28)
	AtlasKit.tubo(sup, MAT, pino + Vector3(-0.30, 0.0, 0.0),
		pino + Vector3(-0.56, 0.0, 0.0), 0.012, C_MANGUEIRA,
		Color(0.7, 0.7, 0.72))
	# A alca (KitEstufa.regador) tem o alto por dentro a 31 cm do pe, 2 cm atras
	# do meio; girado um quarto de volta, o bico aponta -Z.
	KitEstufa.regador(sup, Transform3D(Basis(Vector3.UP, PI * 0.5),
		pino + Vector3(-0.48, -0.31, -0.02)))


## Os ramos pendurados secando, de cabeca para baixo.
##
## Ficam na entrada e nao no fundo. E a primeira coisa que o jogador atravessa
## depois de abrir a porta, e passar por baixo de um varal de ramo seco explica
## o comodo inteiro antes de ele ver uma planta viva.
static func _secagem(sup: Dictionary, rng: RandomNumberGenerator) -> void:
	# Alto o bastante para o ramo terminar acima da cabeca: com volume de verdade
	# (KitEstufa.ramo_secando), ramo na altura do olho e ramo atravessando o rosto
	# de quem entra.
	var y := 2.4
	var z := 2.35
	AtlasKit.tubo(sup, MAT, Vector3(4.40, y, z), Vector3(7.60, y, z), 0.03,
		C_MANGUEIRA, Color(0.78, 0.78, 0.8))
	for k in 6:
		var x := 4.68 + float(k) * 0.45
		var comp := rng.randf_range(0.42, 0.56)
		KitEstufa.ramo_secando(sup, Vector3(x, y - 0.03, z), comp, rng.randi())


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
		Vector3(3.35, 0.0, 5.4), Vector3(3.35, 0.0, 9.4),
		Vector3(3.35, 0.0, 13.4), Vector3(2.20, 0.0, 2.6),
	]
	var leste: Array[Vector3] = [
		Vector3(8.65, 0.0, 6.4), Vector3(8.65, 0.0, 10.4),
		Vector3(8.65, 0.0, 14.4), Vector3(9.90, 0.0, 2.7),
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
			"foco": Vector3(6.0, 0.0, FUNDO - 0.5),
		})
