## Malha da cidade: por onde passam as ruas, onde ficam as quadras e o que cada
## quadra e.
##
## Isto aqui nao gera nenhum vertice. E uma funcao pura da coordenada, e por isso
## pode ser consultada de tres lugares que nunca se falam: a thread que monta o
## chunk, o minimapa que desenha o bairro inteiro sem carregar nada, e o teste
## automatizado. Se a malha fosse decidida dentro do ChunkBuilder, o mapa teria
## de montar geometria para saber onde ha rua, o que custaria segundos.
##
## Como a malha e irregular
## ------------------------
## A primeira versao punha rua em toda fronteira de coordenada par — tabuleiro
## perfeito de 64 m, que le como corredor. A segunda sorteava uma secundaria por
## faixa de 160 m, mas cada uma corria a linha de grade INTEIRA: todo quarteirao
## ainda era casa do mesmo tabuleiro, todo cruzamento tinha quatro bracos e
## nenhuma rua terminava em lugar nenhum.
##
## Agora so a avenida e linha inteira, a cada cinco chunks (160 m) nas duas
## direcoes — a referencia que o jogador usa para nunca se perder. Dentro de
## cada celula entre avenidas, as ruas saem de uma divisao binaria (Tracado): a
## celula e cortada de ponta a ponta, cada metade pode ser cortada de novo na
## outra direcao, e os cortes das duas metades nao combinam. Dai o entroncamento
## em T, a rua que desencontra depois da transversal, a quadra comprida ao lado
## da quadrada. Toda quadra continua um retangulo de chunks, com lado de dois a
## cinco chunks, e toda borda de chunk continua tendo uma via so.
##
## Por isso a via de uma borda e perguntada POR TRECHO: `via_x_em(i, j)` e a via
## da linha x = i * 32 entre z = j * 32 e z = (j + 1) * 32. `via_x(i)` sobrou
## para quem so quer saber se a LINHA e de avenida.
##
## Tudo determinista: a esquina 12,7 tem a mesma rua, a mesma altura de predio e
## a mesma cor de fachada hoje e na proxima execucao.
class_name MalhaUrbana
extends RefCounted

## Classe de uma via. A largura muda com ela, e e a largura que faz a avenida
## parecer avenida sem precisar de placa.
enum Via { NENHUMA, VIELA, RUA, AVENIDA }

## O que ocupa uma quadra.
enum Uso { EDIFICADO, PARQUE, BALDIO }

## Remate do topo do predio. E o detalhe mais barato que existe para diferenciar
## dois volumes de concreto: a silhueta contra o ceu muda por inteiro e custa
## algumas dezenas de triangulos.
enum Coroamento { PLATIBANDA, CAIXA_DAGUA, BEIRAL, ANTENA, TELHADO }

## Carater de uma regiao. Sortear predio a predio deixa a cidade homogenea: tudo
## fica igualmente variado, que e o mesmo que nada ser especial.
enum Distrito { COMERCIAL, RESIDENCIAL, INDUSTRIAL, BALDIO }

## Lado do chunk, repetido aqui porque MalhaUrbana nao depende de KitModular:
## quem consulta a malha pelo mapa nao carrega o kit.
const TAM := 32.0

## Chunks entre avenidas.
const PERIODO := 5

## Lado de um distrito, em chunks.
const DISTRITO_EM_CHUNKS := 4

## Alturas de cidade do INTERIOR, e nao de capital.
##
## Eram 3 a 6 andares no comercio e 2 a 4 nas casas, com mais ou menos um andar
## por predio: a rua residencial era um paredao de quatro pavimentos de janela
## igual e a comercial, um centro de cidade grande. Cidade pequena de Minas e
## casa terrea e sobrado, com o predio de tres ou quatro andares no centro
## sendo o marco da rua — e a mangueira do quintal aparecendo por cima do
## telhado. Os numeros abaixo sao a faixa da QUADRA; cada predio ainda varia um
## andar em volta dela (ChunkBuilder._fileira), entao a rua de casas sai com
## terrea, sobrado e um ou outro de tres.
const PERFIS := {
	Distrito.COMERCIAL: {
		"fachadas": [&"azulejo", &"tijolo", &"concreto"],
		"andares": [2, 4], "loja": 0.7, "janela": 0.34,
		"maquina": 3, "casa": false, "conveniencia": true,
		"parque": 0.10, "sacada": false, "toldo": true,
		"coroamentos": [Coroamento.PLATIBANDA, Coroamento.CAIXA_DAGUA,
			Coroamento.ANTENA, Coroamento.BEIRAL],
	},
	Distrito.RESIDENCIAL: {
		"fachadas": [&"reboco", &"concreto", &"azulejo"],
		"andares": [1, 2], "loja": 0.18, "janela": 0.42,
		"maquina": 6, "casa": true, "conveniencia": false,
		"parque": 0.20, "sacada": true, "toldo": false,
		# Telhado de telha e o que separa cidade do interior de cidade
		# generica: casa de rua em Minas termina em duas aguas com beiral, e
		# nao em laje. Ver `KitPredio.telhado`.
		"coroamentos": [Coroamento.TELHADO, Coroamento.TELHADO,
			Coroamento.BEIRAL, Coroamento.CAIXA_DAGUA],
	},
	Distrito.INDUSTRIAL: {
		# Alvenaria em cima, aco no terreo.
		#
		# A fachada INTEIRA de chapa ondulada, de alto a baixo, era o que fazia
		# a viela ler como corredor de galpao — foi o que o usuario apontou. O
		# galpao de rua brasileira e de alvenaria com porta de aco no terreo, e
		# e assim que `KitModular.fachada` monta quando a massa e de concreto
		# sujo: ela ja escolhe `metal_ondulado` para o vao do terreo.
		"fachadas": [&"concreto_sujo", &"tijolo", &"reboco"],
		"andares": [1, 3], "loja": 0.05, "janela": 0.1,
		"maquina": 8, "casa": false, "conveniencia": false,
		"parque": 0.05, "sacada": false, "toldo": false,
		"coroamentos": [Coroamento.PLATIBANDA, Coroamento.ANTENA,
			Coroamento.CAIXA_DAGUA],
	},
	Distrito.BALDIO: {
		"fachadas": [&"concreto_sujo"],
		"andares": [1, 2], "loja": 0.0, "janela": 0.05,
		"maquina": 99, "casa": false, "conveniencia": false,
		"parque": 0.0, "sacada": false, "toldo": false,
		"coroamentos": [Coroamento.PLATIBANDA],
	},
}

## Tinta da massa do predio, aplicada por vertice. O shader multiplica o albedo
## pela cor, entao a mesma textura de concreto vira oito predios diferentes sem
## custar um arquivo a mais. Tudo perto do branco de proposito: tinta saturada
## vira mancha de cor e some a textura embaixo.
const TINTAS: Array[Color] = [
	Color("ffffff"), Color("d8d2c6"), Color("c6ccd0"), Color("d9c9b6"),
	Color("bec3bb"), Color("cebfb5"), Color("b7bcc5"), Color("d3ceb2"),
	# Tons de rua brasileira, ainda perto do branco para a textura sobreviver.
	Color("ead9a8"), Color("e5c8b4"), Color("c9d6c4"), Color("d2dbe4"),
]

## Cor de casa de cidade do interior, pintada sobre o reboco — uma por casa.
##
## Cal e tinta latex de parede de rua: ocre, amarelo, azul colonial, verde agua,
## rosa, creme, branco encardido. Mais saturadas que TINTAS de proposito, porque
## e o reboco quase branco que recebe, e porque a fileira de casas coloridas e o
## que separa rua de interior de rua de suburbio de concreto. Nenhum canal passa
## de 1: cor de vertice corta em um e nao clareia nada.
const CORES_CASA: Array[Color] = [
	Color("e9d59b"), Color("dcb77f"), Color("a7c3cc"), Color("9fbfa8"),
	Color("e2b3a4"), Color("efe4cb"), Color("c9a39c"), Color("b3c4dc"),
	Color("e6c77e"), Color("f1ede2"), Color("c6d3a3"), Color("d7a98c"),
]


# --- linhas de rua ----------------------------------------------------------

## A LINHA x = i * 32 inteira: AVENIDA se for linha de avenida, NENHUMA se nao.
##
## So a avenida e linha inteira. Rua e viela existem por trecho — pergunte com
## `via_x_em`. Quem usava isto para saber "ha rua aqui" agora ouviria NENHUMA no
## meio de uma rua, e e por isso que o nome ficou so para a avenida: o mapa, a
## blitz e o teto de velocidade do carro so querem saber disso.
static func via_x(i: int) -> Via:
	return Via.AVENIDA if posmod(i, PERIODO) == 0 else Via.NENHUMA


## A LINHA z = j * 32 inteira. Ver `via_x`.
static func via_z(j: int) -> Via:
	return Via.AVENIDA if posmod(j, PERIODO) == 0 else Via.NENHUMA


## Via da linha x = i * 32 no trecho entre z = j * 32 e z = (j + 1) * 32.
static func via_x_em(i: int, j: int) -> Via:
	return Tracado.via_x_em(i, j) as Via


## Via da linha z = j * 32 no trecho entre x = i * 32 e x = (i + 1) * 32.
static func via_z_em(j: int, i: int) -> Via:
	return Tracado.via_z_em(j, i) as Via


## O que cobre o trecho da linha x = i entre z = j * 32 e (j + 1) * 32.
##
## Rua de pedra e a assinatura da cidade do interior: o centro e a avenida foram
## asfaltados, o bairro de casas e a viela continuam no paralelepipedo. Sai por
## TRECHO de corte do Tracado — a rua inteira e de um tipo so, e a mesma nos
## dois chunks de cada lado dela —, e a chance vem do distrito da celula.
static func revestimento_x(i: int, j: int) -> StringName:
	return _revestimento(via_x_em(i, j), 0, i,
		floori(float(i) / PERIODO), floori(float(j) / PERIODO))


## O que cobre o trecho da linha z = j entre x = i * 32 e (i + 1) * 32.
static func revestimento_z(j: int, i: int) -> StringName:
	return _revestimento(via_z_em(j, i), 1, j,
		floori(float(i) / PERIODO), floori(float(j) / PERIODO))


static func _revestimento(v: Via, eixo: int, linha: int, ci: int, cj: int) -> StringName:
	if v == Via.AVENIDA or v == Via.NENHUMA:
		return &"asfalto"
	var chance := 0.65
	if v == Via.RUA:
		match distrito_de(ci * PERIODO, cj * PERIODO):
			Distrito.RESIDENCIAL:
				chance = 0.55
			Distrito.COMERCIAL:
				chance = 0.3
			Distrito.INDUSTRIAL:
				chance = 0.2
			_:
				chance = 0.5
	var h := _ruido(linha * 3 + eixo, ci * 7919 + cj, 4051)
	return &"paralelepipedo" if float(h % 1000) < chance * 1000.0 else &"asfalto"


## Meia largura da pista. A outra metade e do chunk vizinho.
static func meia_pista(v: Via) -> float:
	match v:
		Via.AVENIDA:
			return 4.5
		Via.RUA:
			return 3.0
		Via.VIELA:
			# Um metro e meio, e nao dois. A largura TOTAL da viela nao mudou: os
			# cinquenta centimetros sairam da pista e entraram na calcada, e o
			# recuo continua em tres metros — nenhuma quadra mudou de tamanho.
			# O motivo esta em largura_calcada.
			return 1.5
		_:
			return 0.0


## Faixa de estacionamento / acostamento entre a pista de rolamento e o
## meio-fio. A blitz e os carros encostados vivem aqui — sem isto a viatura
## caia na calcada (MARGEM_ACOST alem da borda do asfalto).
static func largura_estacionamento(v: Via) -> float:
	match v:
		Via.AVENIDA:
			return 2.2
		Via.RUA:
			return 1.8
		_:
			return 0.0


## Meia largura do asfalto total (rolamento + estacionamento).
static func meia_asfalto(v: Via) -> float:
	return meia_pista(v) + largura_estacionamento(v)


static func largura_calcada(v: Via) -> float:
	match v:
		Via.AVENIDA:
			# Era 3,0. Estacionamento de 2,2 m comeu 0,5 m; sobram 2,5 m de
			# calcada — ainda cabe arvore (DA_GUIA) e passagem.
			return 2.5
		Via.RUA:
			return 2.2
		Via.VIELA:
			# Um metro de calcada nao cabe uma pessoa. O pedestre tem 52 cm de
			# largura de colisao; descontando o meio-fio de um lado e a fachada
			# do outro sobravam doze centimetros de folga TOTAL, e a varredura da
			# linha de marcha achou um terco dela intransponivel — tudo viela.
			# Com um metro e meio sobram quase cinquenta de cada lado.
			#
			# A viela continua sendo o que era: pista estreita, sem poste, sem
			# arvore, o unico lugar escuro de uma cidade iluminada a sodio. So
			# deixou de ser um corredor onde quem entra fica preso na primeira
			# soleira.
			return 1.5
		_:
			return 0.0


## Distancia da borda do chunk ate onde a quadra pode comecar.
static func recuo(v: Via) -> float:
	return meia_asfalto(v) + largura_calcada(v)


## As quatro vias que cercam um chunk.
##
##   x0  linha em x = cx * 32          x1  linha em x = (cx + 1) * 32
##   z0  linha em z = cz * 32          z1  linha em z = (cz + 1) * 32
static func bordas(cx: int, cz: int) -> Dictionary:
	return {
		"x0": via_x_em(cx, cz), "x1": via_x_em(cx + 1, cz),
		"z0": via_z_em(cz, cx), "z1": via_z_em(cz + 1, cx),
	}


## O chunk tem alguma rua encostada nele?
##
## Falso quer dizer miolo de quadra grande: lugar onde o jogador nunca pisa e
## que so precisa nao ser um buraco visto de longe.
static func tem_via(cx: int, cz: int) -> bool:
	var b := bordas(cx, cz)
	for chave: String in b:
		if b[chave] != Via.NENHUMA:
			return true
	return false


# --- quadras ----------------------------------------------------------------

## Descreve a quadra a que o chunk pertence.
##
## A quadra, e nao o chunk, e a unidade de decisao arquitetonica. Altura, cor,
## material de fachada, recuo e coroamento saem daqui, entao os quatro ou nove
## chunks de um quarteirao leem como um conjunto so, e a diferenca aparece ao
## atravessar a rua. Sorteando por chunk, a mesma quadra tinha quatro caras e a
## cidade inteira virava ruido.
##
## Campos: x0 x1 z0 z1 (indices de chunk, intervalo semiaberto), id, distrito,
## uso, semente, andares, fachada, tinta, coroamento, recuo_extra, sacada,
## toldo, loja, janela, maquina, casa, conveniencia.
static func quadra_de(cx: int, cz: int) -> Dictionary:
	# O retangulo sai do Tracado: a folha da divisao binaria que contem o chunk.
	var r := Tracado.quadra(cx, cz)
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y

	# O distrito sai do canto da quadra, e nao do chunk. Uma quadra atravessada
	# pela fronteira de dois distritos teria metade dos predios de tijolo e
	# metade de metal ondulado, o que le como erro e nao como transicao.
	var distrito := distrito_de(x0, z0)
	var perfil: Dictionary = PERFIS[distrito]
	var h := _ruido(x0, z0, 9137)

	var uso := Uso.EDIFICADO
	if distrito == Distrito.BALDIO:
		uso = Uso.BALDIO
	elif _cabe_parque(x1 - x0, z1 - z0, h, float(perfil["parque"])):
		uso = Uso.PARQUE

	var faixa: Array = perfil["andares"]
	var minimo := int(faixa[0])
	var maximo := int(faixa[1])
	var paleta: Array = perfil["fachadas"]
	var remates: Array = perfil["coroamentos"]

	return {
		"x0": x0, "x1": x1, "z0": z0, "z1": z1,
		"id": Vector2i(x0, z0),
		"distrito": distrito,
		"uso": uso,
		"semente": h,
		# Altura base da quadra. Cada predio ainda varia um andar em volta dela,
		# senao a fileira vira um paredao de altura unica.
		"andares": minimo + (h / 16) % (maximo - minimo + 1),
		"fachada": paleta[(h / 128) % paleta.size()],
		"tinta": TINTAS[(h / 1024) % TINTAS.size()],
		"coroamento": remates[(h / 8192) % remates.size()],
		# Recuo da fachada em relacao a calcada. Zero na maioria: quadra recuada
		# so vale como excecao, e duas seguidas ja parecem erro de alinhamento.
		"recuo_extra": [0.0, 0.0, 0.0, 1.4, 2.6][(h / 65536) % 5],
		"sacada": bool(perfil["sacada"]) and (h / 32) % 2 == 0,
		"toldo": bool(perfil["toldo"]),
		"loja": float(perfil["loja"]),
		"janela": float(perfil["janela"]),
		"maquina": int(perfil["maquina"]),
		"casa": bool(perfil["casa"]),
		"conveniencia": bool(perfil["conveniencia"]),
	}


## Quadra pequena demais nao vira parque: um parque de um chunk e um canteiro, e
## um canteiro nao paga o gerador. Dois por dois e o minimo que ainda tem miolo.
static func _cabe_parque(largura: int, fundura: int, h: int, chance: float) -> bool:
	if largura < 2 or fundura < 2:
		return false
	return (h % 100) < int(chance * 100.0)


## Distrito de um chunk. Deterministico, como todo o resto.
static func distrito_de(cx: int, cz: int) -> Distrito:
	var rx := floori(float(cx) / float(DISTRITO_EM_CHUNKS))
	var rz := floori(float(cz) / float(DISTRITO_EM_CHUNKS))
	var h := _ruido(rx, rz, 4409)
	# Baldio e mais raro que o resto: terreno vazio e pontuacao, nao paisagem.
	var t := h % 10
	if t < 4:
		return Distrito.COMERCIAL
	if t < 7:
		return Distrito.RESIDENCIAL
	if t < 9:
		return Distrito.INDUSTRIAL
	return Distrito.BALDIO


## Nome do distrito, para o mapa do menu de pausa.
static func nome_do_distrito(d: Distrito) -> String:
	match d:
		Distrito.COMERCIAL:
			return "COMERCIO"
		Distrito.RESIDENCIAL:
			return "RESIDENCIAL"
		Distrito.INDUSTRIAL:
			return "INDUSTRIAL"
		_:
			return "TERRENO BALDIO"


## Retangulo da quadra em metros de mundo, ja descontadas rua e calcada.
##
## E o mesmo numero que ChunkBuilder.area_util devolve por chunk, so que inteiro:
## a area util de um chunk e este retangulo cortado pelo chunk. O mapa desenha
## daqui, e e por isso que a mancha no mapa cai exatamente sobre o predio.
static func retangulo_da_quadra(q: Dictionary) -> Rect2:
	var extra := 0.0
	if int(q["uso"]) == Uso.EDIFICADO:
		extra = float(q["recuo_extra"])
	var v := vias_da_quadra(q)
	var x0 := float(q["x0"]) * TAM + recuo(v["x0"]) + extra
	var x1 := float(q["x1"]) * TAM - recuo(v["x1"]) - extra
	var z0 := float(q["z0"]) * TAM + recuo(v["z0"]) + extra
	var z1 := float(q["z1"]) * TAM - recuo(v["z1"]) - extra
	return Rect2(x0, z0, x1 - x0, z1 - z0)


## A via de cada lado da quadra. Um lado inteiro tem uma via so: ele esta sobre
## o corte que separou esta quadra da vizinha, e um corte e de um tipo so.
static func vias_da_quadra(q: Dictionary) -> Dictionary:
	return {
		"x0": via_x_em(int(q["x0"]), int(q["z0"])),
		"x1": via_x_em(int(q["x1"]), int(q["z0"])),
		"z0": via_z_em(int(q["z0"]), int(q["x0"])),
		"z1": via_z_em(int(q["z1"]), int(q["x0"])),
	}


## Centro da quadra em metros de mundo. O parque usa para ancorar o desenho, e o
## mapa para pousar o icone.
static func centro_da_quadra(q: Dictionary) -> Vector3:
	var x := (float(q["x0"]) + float(q["x1"])) * 0.5 * TAM
	var z := (float(q["z0"]) + float(q["z1"])) * 0.5 * TAM
	return Vector3(x, 0.0, z)


# --- utilitarios ------------------------------------------------------------

## Hash inteiro nao negativo de duas coordenadas mais um sal.
##
## Os primos grandes existem para que chunks em diagonal nao caiam na mesma
## sequencia, que e o defeito classico de derivar semente de soma de coordenada.
static func _ruido(a: int, b: int, sal: int) -> int:
	var h := hash(Vector2i(a, b)) ^ (a * 73856093) ^ (b * 19349663) ^ (sal * 83492791)
	return absi(h) if h != -9223372036854775808 else 7
