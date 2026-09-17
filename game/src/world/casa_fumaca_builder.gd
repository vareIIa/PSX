## A casa da fumaca: sala de amigos com a TV ligada e a partida rolando.
##
## Mesmo contrato do CasaBuilder e do MercadoBuilder — dados puros, sem no
## nenhum, montado na thread enquanto a porta abre.
##
## O que este comodo tem de dizer no primeiro quadro
## -------------------------------------------------
## A cidade inteira do jogo e vazia, molhada e iluminada a sodio. Este e o unico
## lugar dela com gente demais num espaco de menos, luz azul de tubo, som alto e
## cheiro. O contraste e o produto: quando o jogador sai por aquela porta, a rua
## fica pior do que estava antes de ele entrar.
##
## Por isso a luz. Nao ha lampada de teto acesa aqui — ha a TV, duas luminarias
## de canto, a lampada colorida do som e as brasas na mao de quem esta fumando.
## Um comodo assim, iluminado por cima, vira uma sala de estar qualquer. A luz e
## quente de proposito: o ar denso, a fumaca no teto e o amber das luminarias tem
## de ler sauna, nao neon.
##
## Por que a sala e grande
## -----------------------
## A primeira versao tinha 7,2 por 6,4 m e lia como sala de apartamento com
## gente demais dentro. O comodo nao e uma sala com visita: e uma casa em que
## esta rolando uma festa, e festa precisa de espaco VAZIO no meio — o chao onde
## ninguem pos movel, por onde as pessoas circulam e onde o jogador entra sem
## esbarrar em ninguem. Os 9,8 por 8,2 m de agora existem para esse vazio no
## meio, e nao para caber mais movel.
##
## Planta, em metros, origem no canto sul-oeste:
##
##   z=8.2 +----------------------------------------------+
##         |  [estante]      [rack e TV]        [caixa]    |
##         |                                              |
##         |  [sofa]   (o chao onde jogam)     [poltrona]  |
##   z=4.0 |           [mesa]                     [PORTA]  |  -> estufa
##         |                                              |
##         |  [mochilas]              [bancada de bebida]  |
##   z=0   +---------[entrada]----------------------------+
##        x=0                                          x=9.8
class_name CasaFumacaBuilder
extends RefCounted

const ALTURA := 2.55
const ALTURA_PORTA := 2.05
const RODAPE := 0.11

const LARGURA := 9.8
const FUNDO := 8.2

## Onde o jogador aparece, e para onde olha. Chega de frente para a TV, com a
## sala inteira entre ele e ela: e o quadro que explica o comodo sem uma linha.
const ENTRADA := Vector3(2.2, 0.0, 0.9)
const OLHAR := Vector3(4.6, 1.15, 7.6)

## O tubo, contra a parede do fundo.
##
## O Z aqui e o da IMAGEM, e nao o do movel. A ordem em profundidade tem de ser
## exatamente esta, do jogador para a parede:
##
##   FUNDO-0.81  a imagem            (prop Televisao)
##   FUNDO-0.80  a moldura preta     (caixa fina)
##   FUNDO-0.78  a frente do gabinete
##   FUNDO-0.06  o fundo do gabinete, encostado na parede
##
## Na primeira versao a moldura ficou cinco centimetros a frente da imagem e a
## partida simplesmente nao aparecia: o que se via era um retangulo claro no
## fundo da sala. Foi a captura que mostrou — lendo o codigo, as duas linhas
## pareciam certas.
const TV := Vector3(4.6, 0.98, FUNDO - 0.81)
## Onde o console fica no chao, e de onde saem os cabos.
const CONSOLE := Vector3(4.05, 0.0, FUNDO - 1.48)

## O vao da porta dos fundos, na parede leste, em Z.
const VAO_FUNDOS := Vector2(5.9, 6.9)

## Materiais deste comodo.
const MAT: StringName = &"casa"
const MAT_RECORTE: StringName = &"casa_recorte"

## Celulas do atlas da casa. Ver tools/gerar_casa.py.
##
## Existem porque KitModular.caixa mapeia UV POR METRO sobre a textura inteira:
## uma caixa de meio metro com o atlas da casa pega um retalho arbitrario dele.
## O sofa saiu vestindo o gramado do jogo de futebol e a mesa saiu com um
## saquinho estampado no tampo — foi a captura que mostrou, porque lendo o
## codigo os dois eram so `&"casa"`.
##
## Aqui cada peca diz que celula quer, e o AtlasKit mapeia as faces nela.
const C_TV := Vector2i(0, 1)
const C_TV_TRAS := Vector2i(1, 1)
const C_MOLDURA := Vector2i(2, 1)
const C_CABO := Vector2i(5, 1)
## O console, em tres faces. A celula unica de antes — `(3,1)`, preta com uma
## listra — continua no atlas e nao e mais usada aqui: ver `console()` em
## tools/gerar_casa.py para por que tres.
const C_PS2_FRENTE := Vector2i(4, 2)
const C_PS2_LADO := Vector2i(5, 2)
const C_PS2_TOPO := Vector2i(6, 2)
## O DualShock 2, a mesma celula que o Convidado pendura na mao.
const C_CONTROLE := Vector2i(7, 2)
const C_MADEIRA := Vector2i(6, 1)
const C_SOFA := Vector2i(7, 1)
const C_CD := Vector2i(0, 2)
## O cartaz velho, unico, que os quatro da parede usavam. Fora de uso: ver
## `_casca` e a linha 7 do atlas.
const C_POSTER := Vector2i(1, 2)
const C_CARTAZ_BANDA := Vector2i(0, 7)
const C_CARTAZ_TIME := Vector2i(1, 7)
const C_CARTAZ_FILME := Vector2i(2, 7)
const C_CARTAZ_CARRO := Vector2i(3, 7)
const C_CINZEIRO := Vector2i(2, 2)
const C_GARRAFA := Vector2i(3, 2)
const C_SAQUINHO := Vector2i(1, 3)
const C_MOCHILA := Vector2i(2, 3)
const C_LIXA := Vector2i(3, 3)
const C_SHAPE := Vector2i(4, 3)
const C_SOM_FRENTE := Vector2i(5, 3)
const C_SOM_LADO := Vector2i(6, 3)
## Papelao da caixa de pizza. Nao ha celula de pizza no atlas e nao vai haver
## uma: a lona parda da mochila, tingida de claro e vista de cima, e papelao a
## trinta e dois pixels. Celula nova so quando nao ha celula que sirva.
const C_PAPELAO := Vector2i(2, 3)


## A escada de valor do comodo, medida e nao estimada.
##
## Piso, teto e parede saiam com 125,5, 128,4 e 150,1 de luminancia (media da
## textura vezes o tint do material, ver a Fase 3 do PLANO_CASA_FUMACA). Ou
## seja: **o piso e o teto estavam a TRES pontos um do outro**, e a parede a
## vinte e cinco dos dois. Um comodo em que as tres superficies tem o mesmo
## valor nao tem leitura vertical nenhuma — foi por isso que toda captura daqui
## saiu como uma massa marrom uniforme, antes mesmo da nevoa entrar na conta.
##
## A escada certa sai da luz que o comodo TEM. Nao ha lampada de teto (ver
## `_luzes`): quem acende aqui e a TV, duas luminarias de canto, a lampada do
## som e as brasas, tudo na altura do peito ou abaixo. Entao:
##
##   teto     55   o mais escuro, e ninguem ilumina, e tem fumaca na frente
##   piso    100   pega as pocas das luminarias
##   parede  145   e onde a luz bate
##
## O teto tambem vai para o FRIO. Escuro e quente ainda le marrom; escuro e
## azulado le sombra, e sombra e o que ha la em cima.
const TETO_TINTA := Color(0.40, 0.43, 0.48)
const PISO_TINTA := Color(0.84, 0.78, 0.72)

## A janela da parede oeste. Ver `_janela_da_rua`.
const JANELA_Z := 2.35
const JANELA_Y := 1.52
const JANELA := Vector2(1.02, 1.12)


## Paredes de quem nao escolheu a cor: o branco encardido do aluguel, puxado
## um pouco para o creme quente — sob a fumaca amber, parede cinza le fria.
const CORES_PAREDE: Array[Color] = [
	Color("c4b49a"),
	Color("bca890"),
	Color("c8b294"),
]


static func construir(semente: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente

	var sup: Dictionary = {}
	var props: Array[Dictionary] = []
	var colisao: Array[Dictionary] = []

	var cor: Color = CORES_PAREDE[rng.randi() % CORES_PAREDE.size()]

	_casca(sup, cor)
	_colisao(colisao)
	_rack_e_tv(sup, colisao, props)
	_console_e_cabos(sup, props)
	_sofa(sup, colisao)
	_poltrona(sup, colisao)
	_mesa(sup, colisao, rng)
	_estante(sup, colisao, rng)
	_bancada(sup, colisao, rng)
	_canto_do_som(sup, colisao, props)
	_porta_dos_fundos(sup, props, semente)
	_tralha(sup, colisao, rng)
	_fumaca(sup)
	_luzes(props)
	_assentos(props)
	_o_que_da_para_pegar(props)
	_gente(props, semente)

	var tris := 0
	for mat: StringName in sup:
		tris += PSXMesh.dados_triangulos(sup[mat])

	return {
		"superficies": sup, "props": props, "colisao": colisao,
		"triangulos": tris, "entrada": ENTRADA, "olhar": OLHAR,
		# Ambiente proprio: nevoa amber curta, grade quente — o ar de sauna
		# que some assim que a porta fecha atras do jogador.
		"ambiente": "res://resources/fog/fog_fumaca.tres",
		"saida": {
			"pos": Vector3(2.2, 1.0, 0.45),
			"tamanho": Vector3(1.3, 2.0, 0.9),
			"dobradica": Vector3(1.65, 0.0, 0.06),
			"giro": 0.0,
			"angulo": 92.0,
		},
	}


# --- casca ------------------------------------------------------------------

static func _casca(sup: Dictionary, cor: Color) -> void:
	KitModular.chao(sup, &"piso", Vector3.ZERO, Vector2(LARGURA, FUNDO),
		PSXMesh.MAX_QUAD_M, PISO_TINTA)
	var teto := PSXMesh.plane_dados(Vector2(LARGURA, FUNDO))
	# acumular_tingido, e nao KitModular.por: `por` nao tem cor, e o teto deste
	# comodo precisa de uma. Ver TETO_TINTA para o porque.
	if not sup.has(&"teto"):
		sup[&"teto"] = PSXMesh.dados_vazios()
	PSXMesh.acumular_tingido(sup[&"teto"], teto,
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
			Vector3(LARGURA * 0.5, ALTURA, FUNDO * 0.5)), TETO_TINTA)
	_manchas_do_teto(sup)

	var mat: StringName = &"reboco"
	# Perimetro anti horario visto de cima, para as normais olharem para dentro.
	KitModular.parede_com_vaos(sup, mat, Vector2(0.0, 0.0), Vector2(LARGURA, 0.0),
		ALTURA, [Vector2(1.65, 2.75)], ALTURA_PORTA, cor, RODAPE)
	# A parede leste carrega o vao da porta dos fundos.
	KitModular.parede_com_vaos(sup, mat, Vector2(LARGURA, 0.0),
		Vector2(LARGURA, FUNDO), ALTURA, [VAO_FUNDOS], ALTURA_PORTA, cor, RODAPE)
	KitModular.parede_com_vaos(sup, mat, Vector2(LARGURA, FUNDO),
		Vector2(0.0, FUNDO), ALTURA, [], ALTURA_PORTA, cor, RODAPE)
	KitModular.parede_com_vaos(sup, mat, Vector2(0.0, FUNDO), Vector2(0.0, 0.0),
		ALTURA, [], ALTURA_PORTA, cor, RODAPE)

	# Cartazes. Numa parede grande eles contam mais, e nao menos: parede limpa de
	# nove metros le como corredor de escola. Quatro, tortos, em alturas
	# diferentes — alinhados eles virariam exposicao.
	# E cada um e um cartaz DIFERENTE. Os quatro usavam a mesma celula — o poster
	# de time, repetido em quatro alturas e quatro inclinacoes — e quatro copias
	# numa parede de nove metros e oitenta nao leem como quatro cartazes: leem
	# como gerador. Ver `cartazes()` em tools/gerar_casa.py.
	var cartazes: Array[Array] = [
		[Vector3(0.62, 1.62, FUNDO - 0.02), PI, Vector2(0.62, 0.86), C_CARTAZ_BANDA],
		[Vector3(LARGURA - 0.03, 1.55, 2.4), -PI * 0.5, Vector2(0.58, 0.80), C_CARTAZ_TIME],
		[Vector3(0.03, 1.70, 5.2), PI * 0.5, Vector2(0.54, 0.74), C_CARTAZ_FILME],
		[Vector3(7.5, 1.48, FUNDO - 0.02), PI, Vector2(0.50, 0.70), C_CARTAZ_CARRO],
	]
	for c: Array in cartazes:
		var onde: Vector3 = c[0]
		var giro: float = c[1]
		var tam: Vector2 = c[2]
		AtlasKit.face(sup, MAT, tam, Transform3D(Basis(Vector3.UP, giro), onde),
			c[3] as Vector2i)

	_janela_da_rua(sup)
	_fita_do_cartaz_que_saiu(sup)


## Quatro pedacos de fita crepe na parede, no formato de um cartaz que nao esta
## mais la.
##
## E oito triangulos e conta uma coisa que nenhum objeto novo contaria: que este
## comodo tem historico. Cartaz na parede diz o que a pessoa gosta HOJE; o
## retangulo de fita amarelada onde havia um diz que ela ja gostou de outra
## coisa, e que ninguem passou pano naquela parede desde entao.
static func _fita_do_cartaz_que_saiu(sup: Dictionary) -> void:
	var meio := Vector3(3.95, 1.72, FUNDO - 0.02)
	for canto: Vector2 in [Vector2(-0.27, 0.38), Vector2(0.27, 0.38),
			Vector2(-0.27, -0.38), Vector2(0.27, -0.38)]:
		AtlasKit.face(sup, MAT, Vector2(0.085, 0.05),
			Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.FORWARD, 0.5),
				meio + Vector3(canto.x, canto.y, 0.0)),
			C_PAPELAO, Color(0.94, 0.90, 0.74))


## As duas manchas amarelas no teto, sobre onde se fuma.
##
## Saem do PROPRIO material do teto, tingidas por vertice, e nao de uma celula
## nova do atlas. Uma mancha de fumaca de verdade e um degrade, e degrade aqui
## nao existe: `psx_surface` so tem opaco ou recorte duro (`alpha_cutoff` e
## SCISSOR, nao mistura). Duas placas concentricas — uma larga e fraca, uma
## estreita e forte — dao a mesma leitura a 480x270 e custam o material que ja
## esta na cena.
##
## E o detalhe que diz a IDADE do lugar. Um comodo sujo diz que ninguem limpou
## ontem; a mancha diz que ha anos tem gente fumando embaixo daquele ponto.
static func _manchas_do_teto(sup: Dictionary) -> void:
	# A base e a MESMA do teto — `Basis(RIGHT, PI/2)`, que vira a normal para
	# baixo. `KitModular.placa` gira em Y e deixa a placa EM PE: a primeira
	# versao pendurou quatro paineis verticais no ar na altura do teto.
	for onde: Vector3 in [Vector3(2.85, 0.0, 4.0), Vector3(5.0, 0.0, 5.7)]:
		for anel: Array in [[1.55, Color(0.82, 0.78, 0.62)],
				[0.92, Color(0.66, 0.60, 0.44)]]:
			var lado: float = anel[0]
			# UV por metro igual a do proprio teto, e nao a 100 do atlas: a
			# mancha e a mesma textura de reboco, so que mais escura. Com a UV
			# do atlas ela sairia com o reboco repetido cem vezes por metro, ou
			# seja ruido.
			var d := PSXMesh.plane_dados(Vector2(lado, lado),
				PSXMesh.DEFAULT_UV_PER_M, 4.0)
			PSXMesh.acumular_tingido(sup[&"teto"], d,
				Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
					Vector3(onde.x, ALTURA - 0.012, onde.z)),
				(anel[1] as Color) * TETO_TINTA)


## A janela da parede oeste, com cortina meio aberta e o sodio da rua entrando.
##
## Este comodo nao tinha UM vao alem da porta. Uma sala fechada de nove metros e
## oitenta, sem nada por onde o lado de fora existir, le como caixa — e o comodo
## inteiro e construido em cima do contraste com a rua molhada e vazia que o
## jogador acabou de atravessar. Sem janela, esse contraste so acontece na hora
## em que ele sai.
##
## O que entra por ela nao e luz branca: e o LARANJA de sodio do poste, que e a
## unica cor da cidade la fora. Num comodo amber, magenta e azul de tubo, o
## sodio e a quarta fonte e a unica que vem de fora do predio.
static func _janela_da_rua(sup: Dictionary) -> void:
	var z := JANELA_Z
	var meio := Vector3(0.06, JANELA_Y, z)
	# O vidro. Tingido para baixo: o que se ve pela janela as onze da noite nao
	# e uma vidraca acesa, e o reflexo do poste da calcada num vidro sujo.
	KitModular.parede_livre(sup, &"janela_acesa", meio, JANELA, PI * 0.5,
		Color(0.62, 0.40, 0.22))
	# Caixilho e peitoril, em madeira.
	for par: Array in [
			[Vector3(0.0, JANELA.y * 0.5 + 0.05, 0.0), Vector3(0.10, 0.09, JANELA.x + 0.18)],
			[Vector3(0.0, -JANELA.y * 0.5 - 0.06, 0.0), Vector3(0.16, 0.10, JANELA.x + 0.18)],
			[Vector3(0.0, 0.0, JANELA.x * 0.5 + 0.05), Vector3(0.10, JANELA.y, 0.09)],
			[Vector3(0.0, 0.0, -JANELA.x * 0.5 - 0.05), Vector3(0.10, JANELA.y, 0.09)],
			[Vector3(0.0, 0.0, 0.0), Vector3(0.08, JANELA.y, 0.05)]]:
		AtlasKit.caixa(sup, MAT, meio + (par[0] as Vector3), par[1] as Vector3,
			C_MADEIRA, Color(0.62, 0.56, 0.48))
	# Cortina, meio aberta e so de um lado. Fechada, ela apaga a janela; aberta
	# dos dois, vira enfeite simetrico. Torta e a unica das tres que le como
	# cortina de casa alugada.
	#
	# "Meio aberta" e uma medida, e a primeira versao errou ela: 0,62 e 0,34 de
	# pano sobre um vidro de 1,02 deixavam DEZESSEIS centimetros de vao. A
	# captura mostrou uma janela fechada com uma fresta, que e outra coisa.
	# Assim sobram 47 cm — quase metade, que e o que a palavra diz.
	for lado: Array in [[0.36, 0.34], [-0.40, 0.24]]:
		var desloca: float = lado[0]
		var largura: float = lado[1]
		AtlasKit.caixa(sup, MAT, Vector3(0.17, JANELA_Y + 0.06, z + desloca),
			Vector3(0.05, JANELA.y + 0.16, largura), C_SOFA,
			Color(0.86, 0.80, 0.72))
	# O varao.
	AtlasKit.caixa(sup, MAT, Vector3(0.17, JANELA_Y + JANELA.y * 0.5 + 0.14, z),
		Vector3(0.035, 0.035, JANELA.x + 0.34), C_CABO, Color(0.70, 0.66, 0.60))


static func _colisao(colisao: Array[Dictionary]) -> void:
	# Piso e as quatro paredes. O teto nao entra: ninguem chega la.
	colisao.append({"tamanho": Vector3(LARGURA, 0.4, FUNDO),
		"pos": Vector3(LARGURA * 0.5, -0.2, FUNDO * 0.5)})
	for lado: Array in [
			[Vector3(LARGURA, ALTURA, 0.3), Vector3(LARGURA * 0.5, ALTURA * 0.5, -0.15)],
			[Vector3(LARGURA, ALTURA, 0.3), Vector3(LARGURA * 0.5, ALTURA * 0.5, FUNDO + 0.15)],
			[Vector3(0.3, ALTURA, FUNDO), Vector3(-0.15, ALTURA * 0.5, FUNDO * 0.5)],
			[Vector3(0.3, ALTURA, FUNDO), Vector3(LARGURA + 0.15, ALTURA * 0.5, FUNDO * 0.5)]]:
		colisao.append({"tamanho": lado[0], "pos": lado[1]})


# --- a TV -------------------------------------------------------------------

## O rack e o gabinete, em caixas fundidas no comodo; a tela vira prop.
##
## O tubo de uma TV dessas e fundo: setenta centimetros de gabinete para trinta
## de imagem. Essa profundidade e o objeto — desenhada rasa, a TV vira um monitor
## e a data do comodo se perde.
static func _rack_e_tv(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary]) -> void:
	var rack := Vector3(TV.x, 0.0, FUNDO - 0.36)
	AtlasKit.caixa(sup, MAT, rack + Vector3(0.0, 0.28, 0.0),
		Vector3(1.6, 0.56, 0.7), C_MADEIRA)
	colisao.append({"tamanho": Vector3(1.5, 0.6, 0.62),
		"pos": rack + Vector3(0.0, 0.3, 0.0)})

	# Gabinete: a caixa funda, e a moldura preta em volta do tubo.
	AtlasKit.caixa(sup, MAT, Vector3(TV.x, TV.y, FUNDO - 0.42),
		Vector3(0.90, 0.80, 0.72), C_TV, Color.WHITE, 0.0,
		Vector2i(-1, -1), C_TV_TRAS)
	# A moldura fica ATRAS da imagem, encostada nela: e o vao preto em volta do
	# tubo, e nao uma tampa por cima dele.
	AtlasKit.caixa(sup, MAT, Vector3(TV.x, TV.y, TV.z + 0.025),
		Vector3(0.84, 0.72, 0.03), C_MOLDURA)
	colisao.append({"tamanho": Vector3(0.94, 0.84, 0.78),
		"pos": Vector3(TV.x, TV.y, FUNDO - 0.44)})

	# A imagem. Vira PI porque o tubo esta na parede do fundo e olha para a sala.
	props.append({
		"tipo": "televisao",
		"pos": Vector3(TV.x, TV.y, TV.z),
		"giro": PI,
	})


## O console no chao e a fiacao. Sao seis caixas finas e valem mais que o
## console: um PS2 limpo em cima do rack le como vitrine, e o mesmo console no
## chao com o cabo esticado ate o sofa le como sabado a noite.
##
## O aparelho fica EM PE na base, e nao deitado. A silhueta vertical e o que
## identifica um PS2 de tres metros; deitado ele e um retangulo escuro no chao
## do tamanho de uma caixa de pizza, que foi o que a captura mostrou. As medidas
## sao as de catalogo — 78 x 301 x 182 mm — com a base por baixo.
##
## E cada face tem a sua celula. A versao anterior mandava a mesma imagem para
## as seis, entao a costura do leitor aparecia no topo e no fundo e a frente nao
## tinha porta de controle nenhuma. `AtlasKit.caixa` aceita celula separada para
## a frente e para o topo desde que exista, e nunca tinha sido usada aqui.
static func _console_e_cabos(sup: Dictionary, props: Array[Dictionary]) -> void:
	# Base do suporte vertical.
	AtlasKit.caixa(sup, MAT, CONSOLE + Vector3(0.0, 0.011, 0.0),
		Vector3(0.115, 0.022, 0.165), C_PS2_TOPO)
	# O aparelho. Vira PI para a frente — com as portas e o LED — encarar quem
	# esta jogando, que esta em -Z a partir daqui.
	var meio := CONSOLE + Vector3(0.0, 0.172, 0.0)
	AtlasKit.caixa(sup, MAT, meio, Vector3(0.078, 0.301, 0.182),
		C_PS2_LADO, Color.WHITE, PI, C_PS2_FRENTE, C_PS2_TOPO)

	# O LED azul.
	#
	# E a unica luz fria BAIXA da casa, e o comodo inteiro e construido em cima
	# de nao ter luz de teto — ver `_luzes`. Um ponto azul a vinte centimetros
	# do chao, num canto onde so chega amber, e o que faz o aparelho existir
	# quando ninguem esta olhando direto para ele.
	props.append({
		"tipo": "lampada",
		"pos": meio + Vector3(0.0, 0.10, -0.10),
		"padrao": Lampada.Padrao.ESTAVEL,
		"semente": 7735,
		"cor": Color("5ab4ff"),
		"energia": 0.42,
		"alcance": 0.85,
	})

	# Cabo de video subindo ate a traseira da TV.
	_cabo(sup, CONSOLE + Vector3(0.0, 0.06, 0.05),
		Vector3(TV.x, 0.62, FUNDO - 0.5))
	# Os dois cabos de controle, saindo para quem esta jogando. Passam pelo chao
	# em L, como cabo de verdade passa: reto ate o meio e depois virando.
	#
	# As duas pontas terminam no CONTROLE, e nao no meio do corpo de quem
	# segura. Antes iam parar em (4.44, 0.34, 5.42), que e o eixo do convidado —
	# e as duas maos dele param vinte centimetros a frente disso. Os numeros de
	# chegada sao os que `tests/medir_sentado.gd` mede para cada postura, com o
	# corpo virado para a TV.
	_cabo(sup, CONSOLE + Vector3(0.06, 0.03, 0.0), Vector3(4.42, 0.06, 5.92))
	_cabo(sup, Vector3(4.42, 0.06, 5.92), Vector3(4.44, 0.34, 5.62))
	_cabo(sup, CONSOLE + Vector3(-0.06, 0.03, 0.0), Vector3(5.18, 0.06, 6.10))
	_cabo(sup, Vector3(5.18, 0.06, 6.10), Vector3(5.16, 0.99, 5.28))

	# O terceiro controle, largado no chao com o cabo enrolado.
	#
	# Sao duas pessoas jogando e tres controles na sala, e a terceira e a que
	# conta a historia: alguem estava jogando antes, perdeu e largou. Dois
	# controles para duas pessoas le como equipamento; tres le como rodizio.
	_controle_no_chao(sup, Vector3(3.42, 0.0, 6.22), 0.8)
	_cabo(sup, Vector3(3.42, 0.03, 6.22), Vector3(3.70, 0.03, 6.55))
	_cabo(sup, Vector3(3.70, 0.03, 6.55), CONSOLE + Vector3(-0.04, 0.03, -0.02))

	# Em cima do rack: a caixa do jogo aberta e um memory card.
	var tampo := 0.56
	AtlasKit.deitado(sup, MAT, Vector3(TV.x - 0.58, tampo, FUNDO - 0.28),
		Vector2(0.14, 0.125), C_CD, 0.22)
	AtlasKit.deitado(sup, MAT, Vector3(TV.x - 0.42, tampo, FUNDO - 0.26),
		Vector2(0.12, 0.12), C_CD, -0.35, Color(0.72, 0.74, 0.78))
	AtlasKit.caixa(sup, MAT, Vector3(TV.x + 0.56, tampo + 0.006, FUNDO - 0.30),
		Vector3(0.042, 0.012, 0.058), C_PS2_TOPO, Color.WHITE, 0.4)


## Um controle deitado no chao, de bruços. Mesmas tres caixas que o Convidado
## segura — ver `Convidado._montar_controle` para por que a forma sai da
## geometria e nao de um recorte.
static func _controle_no_chao(sup: Dictionary, onde: Vector3,
		giro: float) -> void:
	AtlasKit.caixa(sup, MAT, onde + Vector3(0.0, 0.014, 0.0),
		Vector3(0.105, 0.028, 0.052), C_CONTROLE, Color.WHITE, giro)
	var b := Basis(Vector3.UP, giro)
	for lado: float in [-1.0, 1.0]:
		AtlasKit.caixa(sup, MAT, onde + b * Vector3(lado * 0.055, 0.013, 0.030),
			Vector3(0.034, 0.026, 0.070), C_CONTROLE, Color(0.88, 0.88, 0.9),
			giro)


static func _cabo(sup: Dictionary, de: Vector3, para: Vector3) -> void:
	AtlasKit.tubo(sup, MAT, de, para, 0.022, C_CABO, Color(0.7, 0.7, 0.72))


# --- mobilia ----------------------------------------------------------------

static func _sofa(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	var base := Vector3(0.92, 0.0, 4.05)
	# Assento, encosto e dois bracos. Quatro caixas: a quinta nao acrescenta
	# nada que se veja a esta distancia.
	AtlasKit.caixa(sup, MAT, base + Vector3(0.0, 0.22, 0.0),
		Vector3(0.86, 0.44, 1.95), C_SOFA)
	AtlasKit.caixa(sup, MAT, base + Vector3(-0.31, 0.55, 0.0),
		Vector3(0.24, 0.66, 1.95), C_SOFA)
	for z: float in [-0.92, 0.92]:
		AtlasKit.caixa(sup, MAT, base + Vector3(0.02, 0.48, z),
			Vector3(0.80, 0.24, 0.18), C_SOFA)
	colisao.append({"tamanho": Vector3(0.95, 0.9, 2.0),
		"pos": base + Vector3(-0.05, 0.45, 0.0)})


## Uma poltrona solta do lado leste, virada de esguelha para a TV.
##
## De esguelha, e nao de frente. Movel apontado para a tela em fileira le como
## sala de cinema; torto, le como alguem que puxou a poltrona para conversar e
## nao devolveu para o lugar.
static func _poltrona(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	var base := Vector3(7.35, 0.0, 4.55)
	var giro := -0.7
	var b := Basis(Vector3.UP, giro)
	var tecido := Color(0.92, 0.9, 0.96)
	AtlasKit.caixa(sup, MAT, base + Vector3(0.0, 0.22, 0.0),
		Vector3(0.82, 0.44, 0.86), C_SOFA, tecido, giro)
	AtlasKit.caixa(sup, MAT, base + b * Vector3(0.0, 0.55, -0.31),
		Vector3(0.82, 0.66, 0.22), C_SOFA, tecido, giro)
	for lado: float in [-0.42, 0.42]:
		AtlasKit.caixa(sup, MAT, base + b * Vector3(lado, 0.48, 0.02),
			Vector3(0.16, 0.24, 0.80), C_SOFA, tecido, giro)
	colisao.append({"tamanho": Vector3(0.95, 0.9, 0.95),
		"pos": base + Vector3(0.0, 0.45, 0.0)})


static func _mesa(sup: Dictionary, colisao: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	var mesa := Vector3(2.85, 0.0, 4.0)
	AtlasKit.caixa(sup, MAT, mesa + Vector3(0.0, 0.38, 0.0),
		Vector3(0.78, 0.05, 1.25), C_MADEIRA)
	for canto: Vector3 in [Vector3(-0.33, 0.0, -0.55), Vector3(0.33, 0.0, -0.55),
			Vector3(-0.33, 0.0, 0.55), Vector3(0.33, 0.0, 0.55)]:
		AtlasKit.caixa(sup, MAT, mesa + canto + Vector3(0.0, 0.19, 0.0),
			Vector3(0.06, 0.38, 0.06), C_MADEIRA)
	colisao.append({"tamanho": Vector3(0.82, 0.42, 1.3),
		"pos": mesa + Vector3(0.0, 0.21, 0.0)})

	# O que esta em cima da mesa. Sao placas deitadas, e nao volumes: a
	# espessura de um saquinho e de uma caixa de CD nao existe a esta distancia,
	# e cada um deles em caixa custaria seis faces para mostrar uma.
	var tampo := mesa.y + 0.41
	AtlasKit.deitado(sup, MAT, Vector3(mesa.x - 0.16, tampo, mesa.z - 0.34),
		Vector2(0.24, 0.24), C_CINZEIRO, rng.randf_range(0.0, TAU))
	# Os saquinhos. Dois na mesa e mais alguns espalhados: e o objeto que da nome
	# a casa e ele tem de ser legivel de longe, entao vai maior do que seria.
	AtlasKit.deitado(sup, MAT_RECORTE,
		Vector3(mesa.x + 0.14, tampo, mesa.z - 0.12), Vector2(0.19, 0.19),
		C_SAQUINHO, rng.randf_range(0.0, TAU))
	AtlasKit.deitado(sup, MAT_RECORTE,
		Vector3(mesa.x - 0.08, tampo, mesa.z + 0.28), Vector2(0.16, 0.16),
		C_SAQUINHO, rng.randf_range(0.0, TAU))
	AtlasKit.deitado(sup, MAT, Vector3(mesa.x + 0.20, tampo, mesa.z + 0.46),
		Vector2(0.15, 0.15), C_CD, rng.randf_range(0.0, TAU))
	AtlasKit.deitado(sup, MAT, Vector3(mesa.x - 0.20, tampo, mesa.z + 0.05),
		Vector2(0.22, 0.10), C_GARRAFA, rng.randf_range(0.0, TAU))


## A estante de compensado no canto noroeste: CD, fita, tralha.
##
## Numa sala grande ela e estrutural e nao enfeite — e o que quebra a parede
## oeste em duas alturas e impede que sofa e TV fiquem sozinhos num vazio.
static func _estante(sup: Dictionary, colisao: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	var em := Vector3(0.62, 0.0, 6.9)
	AtlasKit.caixa(sup, MAT, em + Vector3(0.0, 0.82, 0.0),
		Vector3(0.42, 1.64, 1.3), C_MADEIRA)
	colisao.append({"tamanho": Vector3(0.46, 1.7, 1.34),
		"pos": em + Vector3(0.0, 0.85, 0.0)})
	# As prateleiras, mais escuras, saindo um dedo da frente.
	for y: float in [0.52, 0.94, 1.36]:
		AtlasKit.caixa(sup, MAT, em + Vector3(0.03, y, 0.0),
			Vector3(0.46, 0.04, 1.26), C_MADEIRA, Color(0.72, 0.68, 0.62))
		# Fileira de caixinha de CD, de pe, encostada uma na outra.
		var n := 5 + rng.randi() % 4
		for k in n:
			AtlasKit.face(sup, MAT, Vector2(0.024, 0.15),
				Transform3D(Basis(Vector3.UP, PI * 0.5),
					em + Vector3(0.24, y + 0.10, -0.5 + float(k) * 0.03)),
				C_CD, Color(0.9 + rng.randf() * 0.2, 0.9, 0.9))


## A bancada de bebida, perto da entrada.
##
## E o movel que transforma "sala com gente" em "festa". Ninguem apoia sete
## garrafas e uma pilha de copo numa mesa de centro; isso vai numa superficie
## improvisada perto da porta, que e onde quem chega larga o que trouxe.
static func _bancada(sup: Dictionary, colisao: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	var em := Vector3(7.6, 0.0, 1.15)
	AtlasKit.caixa(sup, MAT, em + Vector3(0.0, 0.74, 0.0),
		Vector3(1.70, 0.06, 0.72), C_MADEIRA)
	for canto: Vector3 in [Vector3(-0.78, 0.0, -0.30), Vector3(0.78, 0.0, -0.30),
			Vector3(-0.78, 0.0, 0.30), Vector3(0.78, 0.0, 0.30)]:
		AtlasKit.caixa(sup, MAT, em + canto + Vector3(0.0, 0.37, 0.0),
			Vector3(0.07, 0.74, 0.07), C_MADEIRA)
	colisao.append({"tamanho": Vector3(1.74, 0.8, 0.76),
		"pos": em + Vector3(0.0, 0.4, 0.0)})

	# Garrafas de pe, em fileira desalinhada. De pe e nao deitadas: garrafa em
	# pe le como bebida servida, deitada le como bagunca — e as duas coisas
	# precisam existir na sala, cada uma no seu lugar.
	var tampo := 0.77
	for k in 7:
		var x := -0.72 + float(k) * 0.22 + rng.randf_range(-0.03, 0.03)
		var z := rng.randf_range(-0.16, 0.16)
		var alto := rng.randf() < 0.6
		AtlasKit.caixa(sup, MAT_RECORTE,
			em + Vector3(x, tampo + (0.13 if alto else 0.09), z),
			Vector3(0.08, 0.26 if alto else 0.18, 0.08), C_GARRAFA,
			Color.WHITE, rng.randf_range(0.0, TAU))
	# Pilha de copo e o cinzeiro da bancada.
	AtlasKit.caixa(sup, MAT_RECORTE, em + Vector3(0.62, tampo + 0.11, -0.2),
		Vector3(0.09, 0.22, 0.09), C_GARRAFA, Color(0.86, 0.9, 0.94))
	AtlasKit.deitado(sup, MAT, em + Vector3(-0.5, tampo, 0.24),
		Vector2(0.24, 0.24), C_CINZEIRO, rng.randf_range(0.0, TAU))
	# A caixa de pizza no canto do tampo.
	AtlasKit.caixa(sup, MAT, em + Vector3(0.2, tampo + 0.03, 0.2),
		Vector3(0.42, 0.06, 0.42), C_PAPELAO, Color(0.94, 0.88, 0.76),
		rng.randf_range(-0.3, 0.3))


## O canto do som: a caixa dos anos 2000, empilhada em cima de um caixote.
static func _canto_do_som(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary]) -> void:
	var caixa := Vector3(LARGURA - 0.75, 0.0, FUNDO - 0.85)
	AtlasKit.caixa(sup, MAT, caixa + Vector3(0.0, 0.22, 0.0),
		Vector3(0.5, 0.44, 0.42), C_MADEIRA)
	# A frente com os cones vira para o meio da sala, ou seja para -Z.
	AtlasKit.caixa(sup, MAT, caixa + Vector3(0.0, 0.72, 0.0),
		Vector3(0.42, 0.56, 0.36), C_SOM_LADO, Color.WHITE, PI, C_SOM_FRENTE)
	colisao.append({"tamanho": Vector3(0.52, 1.0, 0.44),
		"pos": caixa + Vector3(0.0, 0.5, 0.0)})

	# A batida sai daqui, e nao de lugar nenhum. Um som de sala que nao tem
	# fonte no espaco vira trilha; com fonte, o jogador anda em direcao a ela.
	props.append({
		"tipo": "som_ambiente",
		"pos": caixa + Vector3(0.0, 0.9, 0.0),
		"som": &"funk_batida",
		"volume": -13.0,
		"alcance": 16.0,
		"pasta": "casa",
	})


# --- a porta dos fundos -----------------------------------------------------

## A porta que leva a estufa.
##
## E a unica porta do jogo que abre de um interior para outro interior, e por
## isso ela e um prop e nao a `saida` da planta — ver Interiores.atravessar.
##
## Fica na parede leste, longe da entrada e depois da poltrona: quem entra na
## casa nao a ve de cara. O jogador atravessa a sala, passa pela roda de gente e
## so entao repara que ha outra porta ali — o que faz o achado valer alguma
## coisa em vez de ser a segunda coisa que ele ve.
static func _porta_dos_fundos(sup: Dictionary, props: Array[Dictionary],
		semente: int) -> void:
	var meio := (VAO_FUNDOS.x + VAO_FUNDOS.y) * 0.5

	# Batente escuro em volta do vao. Vao sem batente le como buraco recortado
	# na parede, e nao como porta.
	for z: float in [VAO_FUNDOS.x - 0.05, VAO_FUNDOS.y + 0.05]:
		AtlasKit.face(sup, MAT, Vector2(0.10, ALTURA_PORTA),
			Transform3D(Basis(Vector3.UP, -PI * 0.5),
				Vector3(LARGURA - 0.04, ALTURA_PORTA * 0.5, z)),
			C_MADEIRA, Color(0.5, 0.45, 0.4))
	AtlasKit.face(sup, MAT, Vector2(1.2, 0.10),
		Transform3D(Basis(Vector3.UP, -PI * 0.5),
			Vector3(LARGURA - 0.04, ALTURA_PORTA + 0.05, meio)),
		C_MADEIRA, Color(0.5, 0.45, 0.4))

	props.append({
		"tipo": "porta_interna",
		"pos": Vector3(LARGURA - 0.55, 1.05, meio),
		"tamanho": Vector3(1.1, 2.1, 1.4),
		"dobradica": Vector3(LARGURA - 0.07, 0.0, VAO_FUNDOS.x + 0.05),
		# A folha corre ao longo de +Z a partir da dobradica, e abre para DENTRO
		# da sala: girando para o outro lado ela entraria na parede.
		"giro": -PI * 0.5,
		"angulo": -92.0,
		"rotulo": "Abrir a porta dos fundos",
		"destino": &"estufa",
		# Semente propria: a estufa e o mesmo lugar toda vez que se volta a
		# ESTA casa, e um lugar diferente na casa da fumaca da outra esquina.
		"semente": semente + 4242,
		"volta": Vector3(LARGURA - 1.25, 0.0, meio),
		"volta_olhar": Vector3(LARGURA - 4.5, 1.5, meio - 0.9),
	})


## O que esta pelo chao. E o que mais diz sobre quem mora aqui, e o que menos
## custa: sao placas e caixas soltas, sem colisao, para o jogador nao tropecar
## numa mochila a cada passo.
static func _tralha(sup: Dictionary, colisao: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	# Skate encostado na parede leste, de pe, apoiado pelo rabo.
	# O shape fica de pe, encostado e um pouco tombado — que e como skate fica
	# quando ninguem esta usando. Deitado no chao ele some sob a perspectiva.
	var skate := Vector3(LARGURA - 0.28, 0.0, 2.6)
	AtlasKit.caixa_livre(sup, MAT, skate + Vector3(0.0, 0.40, 0.0),
		Vector3(0.20, 0.80, 0.03), Basis(Vector3.FORWARD, 0.2), C_SHAPE,
		Color.WHITE, C_LIXA)
	for y: float in [0.10, 0.70]:
		for lado: float in [-0.07, 0.07]:
			AtlasKit.caixa(sup, MAT, skate + Vector3(-0.06, y, lado),
				Vector3(0.06, 0.06, 0.06), C_CABO, Color(0.75, 0.72, 0.66))

	# Tres mochilas largadas: perto da porta, ao pe do sofa e do lado da estante.
	for onde: Vector3 in [Vector3(1.15, 0.0, 1.25), Vector3(1.72, 0.0, 5.0),
			Vector3(1.35, 0.0, 7.4)]:
		AtlasKit.caixa(sup, MAT, onde + Vector3(0.0, 0.17, 0.0),
			Vector3(0.30, 0.34, 0.22), C_MOCHILA, Color.WHITE,
			rng.randf_range(0.0, TAU))
		colisao.append({"tamanho": Vector3(0.34, 0.36, 0.26),
			"pos": onde + Vector3(0.0, 0.18, 0.0)})

	# Cinzeiros espalhados: um na mesa e um na bancada ja existem, e mais tres
	# pelo chao e pelo rack. Cinco cinzeiros num comodo so nao e exagero — e o
	# que denuncia que a noite comecou ha muito tempo.
	AtlasKit.deitado(sup, MAT, Vector3(5.95, 0.0, 4.35), Vector2(0.24, 0.24),
		C_CINZEIRO, rng.randf_range(0.0, TAU))
	AtlasKit.deitado(sup, MAT, Vector3(TV.x - 0.62, 0.57, FUNDO - 0.5),
		Vector2(0.22, 0.22), C_CINZEIRO, rng.randf_range(0.0, TAU))
	AtlasKit.deitado(sup, MAT, Vector3(2.75, 0.45, 3.55), Vector2(0.21, 0.21),
		C_CINZEIRO, rng.randf_range(0.0, TAU))
	# Os dois do chao ao lado de quem joga. Sao eles que sustentam as colunas de
	# fumaca que entram no plano da abertura — fumaca subindo de lugar nenhum
	# le como efeito, subindo de um cinzeiro le como sala.
	for onde: Vector3 in [Vector3(5.58, 0.0, 5.88), Vector3(3.86, 0.0, 5.05)]:
		AtlasKit.deitado(sup, MAT, onde, Vector2(0.23, 0.23), C_CINZEIRO,
			rng.randf_range(0.0, TAU))
	# E mais saquinho, no chao ao lado de quem esta jogando.
	for onde: Vector3 in [Vector3(4.95, 0.0, 6.35), Vector3(2.75, 0.45, 4.45),
			Vector3(TV.x + 0.62, 0.57, FUNDO - 0.5)]:
		AtlasKit.deitado(sup, MAT_RECORTE, onde, Vector2(0.17, 0.17),
			C_SAQUINHO, rng.randf_range(0.0, TAU))
	# Garrafas caidas.
	for onde: Vector3 in [Vector3(2.25, 0.0, 2.85), Vector3(6.4, 0.0, 6.2),
			Vector3(8.6, 0.0, 3.1)]:
		AtlasKit.deitado(sup, MAT_RECORTE, onde, Vector2(0.22, 0.14),
			C_GARRAFA, rng.randf_range(0.0, TAU))
	# Caixinhas de CD pelo chao, do lado do console.
	for k in 4:
		AtlasKit.deitado(sup, MAT, Vector3(3.3 + float(k) * 0.24, 0.0, 6.9),
			Vector2(0.15, 0.15), C_CD, rng.randf_range(0.0, TAU))


# --- fumaca -----------------------------------------------------------------

## A camada parada embaixo do teto, e os fios que sobem dos cinzeiros.
##
## Sao quatro placas horizontais e nao uma. Uma placa so, por mais densa que
## fosse, tem espessura zero: passando por baixo dela o jogador ve uma linha
## reta atravessando a sala. Quatro, em alturas diferentes e com opacidades
## decrescentes, dao ESPESSURA — a fumaca fica mais fechada em cima e vai
## rareando na altura da cabeca, que e como fumaca de cigarro se acomoda num
## comodo fechado e e o que da a leitura de sauna.
##
## A UV corre nas quatro, com deriva no material, e cada uma tem um numero de
## repeticoes diferente. Iguais, elas se moveriam em bloco e a camada leria como
## uma imagem so deslizando; diferentes, elas se cruzam e o desenho muda sozinho
## o tempo todo.
##
## As repeticoes subiram junto com a sala: sao por PLACA, e nao por metro, entao
## mantidas as antigas a nuvem esticaria de 7 para 10 m e viraria borrao.
## A camada mais baixa fica ACIMA do olho do jogador, e nao na altura dele.
##
## Estava em 1,72 m. O olho de quem anda pela casa fica a 1,62: a placa passava
## doze centimetros acima da lente, e uma placa vista quase de perfil nao lê
## como camada — ela ocupa a tela inteira. O material do teto tem
## `fade_de_raspao = 0`, que e a unica coisa que atenuaria isso, e o zero e
## deliberado (o comentario em psx_fumaca.gdshader:43 explica: com o fade ligado
## a camada some SEMPRE, porque a normal dela aponta para baixo e o jogador olha
## para a frente).
##
## Entao o conserto nao e religar o fade, e sim tirar as placas da altura do
## olho. Medido na captura da entrada: com 1,72 a fumaca ocupava 55% do quadro;
## com 2,02 e as opacidades abaixo, ela volta a ser o teto do comodo.
const CAMADAS_FUMACA: Array = [
	[2.46, 0.52, 3.6],
	[2.30, 0.38, 2.8],
	[2.16, 0.26, 2.0],
	[2.02, 0.14, 1.5],
]

static func _fumaca(sup: Dictionary) -> void:
	for camada: Array in CAMADAS_FUMACA:
		var altura: float = camada[0]
		var opacidade: float = camada[1]
		var repeticoes: float = camada[2]
		# Tint quente no vertice: o material ja e amber, e o vertice reforca
		# vapor em vez de nevoa fria quando a TV ilumina a camada de tras.
		var d := PSXMesh.placa_dados(Vector2(LARGURA - 0.2, FUNDO - 0.2), 100.0,
			Color(1.0, 0.92, 0.82, opacidade))
		var uvs: PackedVector2Array = d["uv"]
		for k in uvs.size():
			uvs[k] = uvs[k] * repeticoes
		d["uv"] = uvs
		if not sup.has(&"fumaca_teto"):
			sup[&"fumaca_teto"] = PSXMesh.dados_vazios()
		# Virada para baixo: quem olha para ela esta embaixo dela.
		PSXMesh.acumular(sup[&"fumaca_teto"], d,
			Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
				Vector3(LARGURA * 0.5, altura, FUNDO * 0.5)))

	# Os fios que sobem dos cinzeiros. Duas placas cruzadas cada, para nao
	# sumirem quando o jogador contorna a mesa.
	#
	# As duas ultimas sao do lado de quem esta jogando, e existem por causa do
	# plano 05 da abertura: as quatro primeiras ficam na mesa, no chao do meio e
	# na bancada, e nenhuma delas cai dentro do enquadramento que filma os dois
	# jogadores. Um comodo que se chama casa da fumaca precisa de fumaca no
	# quadro em que ele aparece.
	for onde: Vector3 in [Vector3(2.69, 0.42, 3.66), Vector3(5.95, 0.02, 4.35),
			Vector3(2.75, 0.47, 3.55), Vector3(7.10, 0.79, 1.39),
			Vector3(5.58, 0.02, 5.88), Vector3(3.86, 0.02, 5.05)]:
		_coluna_de_fumaca(sup, onde, 0.26, 1.5)


## Uma coluna de fumaca subindo de um ponto.
static func _coluna_de_fumaca(sup: Dictionary, base: Vector3, largura: float,
		altura: float) -> void:
	if not sup.has(&"fumaca_baseado"):
		sup[&"fumaca_baseado"] = PSXMesh.dados_vazios()
	for giro: float in [0.0, PI * 0.5]:
		# Transparente no pe e cheia no alto: a fumaca so vira visivel depois de
		# subir alguns centimetros, e comecar opaca no cinzeiro poe um bloco
		# branco em cima da bituca.
		var d := PSXMesh.placa_dados(Vector2(largura, altura), altura * 0.5,
			Color(1.0, 0.94, 0.86, 0.68))
		PSXMesh.acumular(sup[&"fumaca_baseado"], d,
			Transform3D(Basis(Vector3.UP, giro),
				base + Vector3(0.0, altura * 0.5, 0.0)))


# --- luz e gente ------------------------------------------------------------

## Nao ha lampada de teto.
##
## E a decisao mais importante do comodo. A sala e iluminada pela TV, por duas
## luminarias de canto, pela lampada colorida do som e pelas brasas — e e isso
## que faz o lugar ser o que e. Com luz de teto, tudo aqui vira uma sala de
## estar com objetos espalhados.
static func _luzes(props: Array[Dictionary]) -> void:
	props.append({
		"tipo": "lampada",
		"pos": Vector3(0.75, 1.42, 3.05),
		"padrao": Lampada.Padrao.ESTAVEL,
		"semente": 7731,
		"cor": Color("ffc089"),
		"energia": 1.15,
		"alcance": 4.2,
	})
	props.append({
		"tipo": "lampada",
		"pos": Vector3(2.85, 1.05, 4.0),
		"padrao": Lampada.Padrao.ESTAVEL,
		"semente": 7732,
		"cor": Color("ffb070"),
		"energia": 0.55,
		"alcance": 2.8,
	})
	# A luminaria da bancada, do outro lado da sala. Numa sala de quase dez
	# metros, duas luzes no mesmo canto deixam metade do comodo no escuro — e
	# escuro demais deixa de ser atmosfera e vira "nao da para ver".
	props.append({
		"tipo": "lampada",
		"pos": Vector3(7.6, 1.55, 1.15),
		"padrao": Lampada.Padrao.ESTAVEL,
		"semente": 7733,
		"cor": Color("ffbe86"),
		"energia": 0.95,
		"alcance": 3.6,
	})
	# O sodio que entra pela janela.
	#
	# E a quarta cor do comodo e a unica que vem de FORA do predio: amber das
	# luminarias, magenta do som, azul do tubo, e este laranja duro de poste. Ela
	# fica logo dentro do vao, apontada para o meio da sala, e o que ela faz de
	# util e por uma cunha de luz no piso — a cunha e o que diz que ha rua do
	# outro lado daquela parede.
	props.append({
		"tipo": "lampada",
		# Fica 80 cm PARA DENTRO da sala, e nao encostada no vao. Uma Omni
		# colada na janela acende a cortina de dentro — luz de rua batendo no
		# pano pelo lado errado — e a captura saiu com um retangulo laranja
		# chapado onde devia haver vidro. Afastada, o que ela acende e o piso.
		"pos": Vector3(0.82, JANELA_Y - 0.25, JANELA_Z),
		"padrao": Lampada.Padrao.ESTAVEL,
		"semente": 7736,
		"cor": Color("ff9640"),
		"energia": 0.78,
		"alcance": 3.4,
		"atenuacao": 1.5,
	})

	# A lampada colorida em cima do som. E a unica luz fria da casa, e e ela que
	# diz festa: uma sala inteira amber le como sala; um canto magenta dentro
	# dela le como alguem que trocou a lampada de proposito.
	props.append({
		"tipo": "lampada",
		"pos": Vector3(LARGURA - 0.75, 1.85, FUNDO - 0.85),
		"padrao": Lampada.Padrao.ESTAVEL,
		"semente": 7734,
		"cor": Color("c060c8"),
		"energia": 0.85,
		"alcance": 3.4,
	})


## Os dois lugares de sentar, e para onde eles olham.
##
## O sofa encara a TV de frente e e o assento da partida: sentado nele, o jogador
## ve o jogo do lugar de quem mora aqui, com o facho do tubo vindo na cara e a
## fumaca subindo entre ele e a tela. Em pe, no meio da sala, esse quadro nao
## existe.
##
## A poltrona esta de esguelha e olha para o MEIO da sala, e nao para a tela: ela
## e a cadeira de quem veio conversar, e quem senta nela ve a roda de gente com a
## TV de canto. Dois assentos com o mesmo enquadramento seriam um assento
## desenhado duas vezes.
##
## A lente desce para 86 cm no sofa e 90 na poltrona — assento de sofa velho
## afunda mais que poltrona. Nao e detalhe gratuito: e a diferenca que faz o
## jogador sentir que trocou de movel.
static func _assentos(props: Array[Dictionary]) -> void:
	props.append({
		"tipo": "assento",
		"pos": Vector3(0.92, 0.70, 4.05),
		"tamanho": Vector3(1.1, 1.1, 2.1),
		"onde": Vector3(1.62, 0.0, 4.05),
		"olhar": Vector3(TV.x, 0.98, TV.z),
		"olho": 0.86,
		"rotulo": "Sentar no sofa",
		"rotulo_levantar": "Levantar do sofa",
	})
	props.append({
		"tipo": "assento",
		"pos": Vector3(7.35, 0.70, 4.55),
		"tamanho": Vector3(1.1, 1.1, 1.1),
		"onde": Vector3(6.72, 0.0, 4.62),
		"olhar": Vector3(4.0, 1.15, 4.2),
		"olho": 0.90,
		"rotulo": "Sentar na poltrona",
		"rotulo_levantar": "Levantar da poltrona",
	})


## O que da para levar embora.
##
## Tres coisas na bancada e uma na mesa, e as quatro sao objetos que ja estavam
## DESENHADOS ali — garrafa, cinzeiro, saquinho. Ate agora eram malha fundida no
## comodo: o jogador via, chegava perto e nao acontecia nada. Um cenario cheio de
## coisa que nao se pega ensina o jogador a parar de tentar, e depois disso ele
## tambem nao tenta no lugar onde tinha.
static func _o_que_da_para_pegar(props: Array[Dictionary]) -> void:
	var bancada := Vector3(7.6, 0.0, 1.15)
	props.append({
		"tipo": "item", "item": &"remedio", "quantidade": 1, "indice": 0,
		"pos": bancada + Vector3(-0.28, 0.86, -0.18),
	})
	props.append({
		"tipo": "item", "item": &"bandagem", "quantidade": 1, "indice": 1,
		"pos": bancada + Vector3(0.36, 0.86, 0.22),
	})
	props.append({
		"tipo": "item", "item": &"bateria", "quantidade": 1, "indice": 2,
		"pos": Vector3(2.85, 0.44, 4.32),
	})


## Quem esta na sala.
##
## Dois sao os jogadores e nao saem do lugar. Os outros circulam. A maioria esta
## fumando, que e o que da nome a casa — mas nao todos: um comodo em que todo
## mundo faz a mesma coisa ao mesmo tempo le como coreografia.
##
## Sao oito, e nao seis, porque a sala cresceu. Densidade e o assunto: as mesmas
## seis pessoas num comodo de oitenta metros quadrados leriam como sala grande
## meio vazia, que e o oposto do que este lugar tem de ser.
static func _gente(props: Array[Dictionary], semente: int) -> void:
	# Os pontos por onde os que circulam andam. Ficam longe do eixo entre a TV e
	# quem esta jogando: alguem passando na frente da tela a cada dez segundos
	# seria engracado uma vez e irritante nas outras.
	var pontos: Array[Vector3] = [
		Vector3(1.7, 0.0, 2.1), Vector3(1.9, 0.0, 6.2),
		Vector3(6.6, 0.0, 2.4), Vector3(8.4, 0.0, 5.4),
		Vector3(3.3, 0.0, 1.8), Vector3(6.2, 0.0, 7.0),
		Vector3(8.7, 0.0, 6.9), Vector3(3.6, 0.0, 2.9),
	]
	var meio := Vector3(4.4, 0.0, 4.2)

	# O que esta sentado no chao, e o que esta de pe atras dele.
	props.append(_pessoa(semente, 101, Vector3(4.44, 0.0, 5.42),
		Convidado.Papel.SENTADO, false, Vector3(TV.x, 0.0, TV.z), pontos, true))
	props.append(_pessoa(semente, 202, Vector3(5.16, 0.0, 5.10),
		Convidado.Papel.EM_PE, false, Vector3(TV.x, 0.0, TV.z), pontos, true))

	# Mais seis circulando. Quatro fumando: a proporcao importa e e o que separa
	# uma casa de amigos de um cartaz.
	var lugares: Array[Vector3] = [
		Vector3(1.75, 0.0, 3.3), Vector3(6.9, 0.0, 3.5),
		Vector3(2.6, 0.0, 5.9), Vector3(7.9, 0.0, 6.4),
		Vector3(6.3, 0.0, 1.6), Vector3(6.9, 0.0, 2.3),
	]
	for k in lugares.size():
		props.append(_pessoa(semente, 303 + k * 97, lugares[k],
			Convidado.Papel.LIVRE, k != 2 and k != 4, meio, pontos))

	# O dono da casa.
	#
	# Encostado na parede leste, ao lado da porta dos fundos, fumando. Tres
	# decisoes numa posicao so:
	#
	#   nao circula    quem manda no lugar nao anda pela sala procurando com
	#                  quem falar; fica parado e os outros e que vao ate ele
	#   canto oposto   entra-se pelo sul, e ele esta no extremo nordeste: a
	#                  terceira etapa da missao obriga a ATRAVESSAR o comodo, que
	#                  e o unico jeito de a sala ser vista em vez de so cruzada
	#   ao lado da porta dos fundos   ele guarda o unico outro caminho da casa
	#
	# A poltrona (7,35 / 4,55) foi a primeira escolha e estava errada: o
	# Convidado e um CharacterBody3D e nasceria dentro da caixa de colisao do
	# movel, empurrado para fora no primeiro quadro.
	var dono := _pessoa(semente, 911, Vector3(9.32, 0.0, 5.25),
		Convidado.Papel.ENCOSTADO, true, meio, [] as Array[Vector3])
	dono["dono"] = true
	dono["idade_min"] = 28
	dono["idade_max"] = 44
	props.append(dono)


static func _pessoa(semente: int, sal: int, onde: Vector3, papel: int,
		fuma: bool, foco: Vector3, pontos: Array[Vector3],
		controle: bool = false) -> Dictionary:
	return {
		"tipo": "convidado",
		"pos": onde,
		"semente": semente + sal,
		"papel": papel,
		"fuma": fuma,
		"controle": controle,
		"foco": foco,
		"pontos": pontos,
		# Todo mundo desta sala conversa no contexto da casa, e nao no da rua:
		# e o que poe "O QUE TA ROLANDO AQUI?" na lista de assuntos.
		"contexto": &"casa",
	}
