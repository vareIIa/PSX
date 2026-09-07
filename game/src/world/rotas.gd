## Por onde um pedestre anda.
##
## Nao ha malha de navegacao assada, e nao pode haver: a cidade e infinita e
## nasce em thread, entao qualquer coisa que precise ser cozida antes esta fora.
## Mas nao faz falta — a cidade JA e um grafo, e ele esta escrito em
## MalhaUrbana. Basta ler.
##
## O no e uma esquina de calcada
## -----------------------------
## Toda linha de rua que existe cruza com outra. Em cada cruzamento ha quatro
## cantos de calcada, e um pedestre esta sempre indo de um canto a outro. Entao
## o no e a quadrupla (i, j, sx, sz):
##
##   i, j     indices das linhas de rua que se cruzam
##   sx, sz   em qual dos quatro cantos, -1 ou +1
##
## E as arestas sao as quatro coisas que se pode fazer num canto:
##
##   seguir a calcada no eixo Z ate o proximo cruzamento
##   seguir a calcada no eixo X ate o proximo cruzamento
##   atravessar a rua transversal, indo para o canto vizinho
##   atravessar a rua propria, indo para o outro lado
##
## Nada disso e guardado. Tudo sai de MalhaUrbana.via_x e via_z na hora, que sao
## funcoes puras da coordenada — o mesmo motivo pelo qual o mapa consegue
## desenhar um bairro inteiro sem montar geometria.
class_name Rotas
extends RefCounted

const TAM := MalhaUrbana.TAM

## Ate onde procurar a proxima linha de rua. Uma faixa sem secundaria da quadra
## de 160 m, ou cinco chunks; o dobro disso e folga de sobra.
const ALCANCE_BUSCA := 12


## Onde corre a linha de marcha, contada do meio da rua.
##
## Nao e o meio da calcada: e 62% dela, do lado do PREDIO. A diferenca de doze
## por cento parece detalhe e nao e — ela decide se a cidade tem calcada
## caminhavel ou uma fileira de armadilhas.
##
## As contas, numa avenida: a pista tem 4,5 de meia largura e a calcada 3,0.
##
##   poste    em 4,5 + 0,80 = 5,30
##   arvore   em 4,5 + 1,05 = 5,55, com uns 20 cm de tronco -> chega a 5,75
##   meio da calcada  6,00, e o pedestre tem 26 cm de raio -> comeca em 5,74
##
## Ou seja: no meio da calcada o ombro do pedestre encosta no tronco de TODA
## arvore da avenida, a cada onze metros. Ele empurra, nao passa, e fica ali.
## Isso apareceu como sete a nove pessoas por minuto sendo recolhidas por
## desistirem de andar — a multidao estava funcionando e a calcada e que nao
## deixava. Em 62% a linha corre em 6,36 e sobra um terco de metro de cada lado.
static func recuo_de_marcha(v: int) -> float:
	var calcada := MalhaUrbana.largura_calcada(v)
	# Do lado do predio, mas nunca a menos de 60 cm da fachada. Numa calcada
	# larga o 62% manda; numa estreita manda o limite, e a linha volta para perto
	# do meio, que e onde ela cabe.
	var afastamento := minf(calcada * 0.62, calcada - 0.6)
	return MalhaUrbana.meia_pista(v) + maxf(afastamento, calcada * 0.4)


## Quanto o pedestre pode sair da linha para os lados, em metros.
##
## Cada pessoa anda na sua faixa dentro da calcada, senao todas caminham em fila
## indiana pelo mesmo pixel. Mas a faixa nao pode ser a mesma em toda via: na
## avenida sobra meio metro para cada lado e na viela sobram quinze centimetros.
## Uma folga fixa jogava metade da viela contra a parede.
static func folga_lateral(v: int) -> float:
	return maxf(0.0, MalhaUrbana.largura_calcada(v) * 0.5 - 0.5)


## Folga lateral da aresta `k` de um no.
static func folga_da_aresta(no: Vector4i, k: int) -> float:
	return folga_lateral(MalhaUrbana.via_z(no.y) if k == 1
		else MalhaUrbana.via_x(no.x))


static func existe_x(i: int) -> bool:
	return MalhaUrbana.via_x(i) != MalhaUrbana.Via.NENHUMA


static func existe_z(j: int) -> bool:
	return MalhaUrbana.via_z(j) != MalhaUrbana.Via.NENHUMA


## Posicao do canto de calcada no mundo. Y fica em zero: quem anda resolve a
## altura por raio, porque a calcada tem quinze centimetros de guia e o caminho
## de um pedestre atravessa isso o tempo todo.
static func ponto(no: Vector4i) -> Vector3:
	var ox := recuo_de_marcha(MalhaUrbana.via_x(no.x))
	var oz := recuo_de_marcha(MalhaUrbana.via_z(no.y))
	return Vector3(float(no.x) * TAM + float(no.z) * ox, 0.0,
		float(no.y) * TAM + float(no.w) * oz)


static func _proxima_x(i: int, direcao: int) -> int:
	for passo in range(1, ALCANCE_BUSCA):
		var k := i + direcao * passo
		if existe_x(k):
			return k
	return i


static func _proxima_z(j: int, direcao: int) -> int:
	for passo in range(1, ALCANCE_BUSCA):
		var k := j + direcao * passo
		if existe_z(k):
			return k
	return j


## As quatro saidas de um canto, em ordem fixa:
##   0 seguir no eixo Z    1 seguir no eixo X
##   2 atravessar a transversal    3 atravessar a propria
##
## A ordem importa porque quem anda usa o indice para preferir seguir reto: um
## pedestre que sorteia entre as quatro com peso igual fica girando na esquina.
static func vizinhos(no: Vector4i) -> Array[Vector4i]:
	var saida: Array[Vector4i] = []
	var j2 := _proxima_z(no.y, no.w)
	saida.append(Vector4i(no.x, j2, no.z, -no.w) if j2 != no.y else no)
	var i2 := _proxima_x(no.x, no.z)
	saida.append(Vector4i(i2, no.y, -no.z, no.w) if i2 != no.x else no)
	saida.append(Vector4i(no.x, no.y, no.z, -no.w))
	saida.append(Vector4i(no.x, no.y, -no.z, no.w))
	return saida


## Canto de calcada mais proximo de um ponto qualquer.
static func no_mais_proximo(pos: Vector3) -> Vector4i:
	var ci := floori(pos.x / TAM)
	var cj := floori(pos.z / TAM)
	var melhor := Vector4i(ci, cj, 1, 1)
	var melhor_d := INF
	for di in range(-2, 3):
		var i := ci + di
		if not existe_x(i):
			continue
		for dj in range(-2, 3):
			var j := cj + dj
			if not existe_z(j):
				continue
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					var no := Vector4i(i, j, sx, sz)
					var d := ponto(no).distance_squared_to(pos)
					if d < melhor_d:
						melhor_d = d
						melhor = no
	return melhor


## Pontos de calcada numa coroa em volta de um lugar, com o trecho a que
## pertencem. E de onde a multidao faz gente aparecer: perto o bastante para o
## jogador cruzar com ela, longe o bastante para a nevoa cobrir o instante.
##
## Por que trecho e nao esquina
## ---------------------------
## A primeira versao so sabia nascer em ESQUINA, e a rua ficou vazia. O motivo e
## a propria malha: avenida a cada 160 m e uma secundaria no meio da faixa, entao
## os cruzamentos ficam a 64, 96 ou 160 m uns dos outros. Uma coroa de 24 a 42 m
## em volta do jogador quase nunca contem um cruzamento — quando ele esta no meio
## do quarteirao, nao contem nenhum, e ninguem nascia.
##
## Gente anda no meio do quarteirao. O ponto de nascimento tem de ser qualquer
## lugar da calcada, e o trecho vem junto para quem nasceu ali ja saber para onde
## estava indo.
const PASSO_AMOSTRA := 7.0

static func trechos_perto(centro: Vector3, minimo: float,
		maximo: float) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var ci := floori(centro.x / TAM)
	var cj := floori(centro.z / TAM)
	var alcance := ceili(maximo / TAM) + 2

	for di in range(-alcance, alcance + 1):
		var i := ci + di
		if not existe_x(i):
			continue
		for dj in range(-alcance, alcance + 1):
			var j := cj + dj
			if not existe_z(j):
				continue
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					var no := Vector4i(i, j, sx, sz)
					# So as duas saidas que percorrem calcada; as outras duas sao
					# travessias de rua, que sao curtas e nao valem como berco.
					for k in 2:
						var destino := vizinhos(no)[k]
						if destino == no or not aresta_caminhavel(no, k):
							continue
						_amostrar(saida, no, destino, centro, minimo, maximo)
	return saida


static func _amostrar(saida: Array[Dictionary], de: Vector4i, para: Vector4i,
		centro: Vector3, minimo: float, maximo: float) -> void:
	var a := ponto(de)
	var b := ponto(para)
	var comprimento := a.distance_to(b)
	if comprimento < 1.0:
		return
	var quantos := maxi(1, int(comprimento / PASSO_AMOSTRA))
	for n in range(1, quantos):
		var t := float(n) / float(quantos)
		var p := a.lerp(b, t)
		var d := p.distance_to(centro)
		if d >= minimo and d <= maximo:
			saida.append({"de": de, "para": para, "ponto": p})


## Cantos numa coroa em volta de um ponto. Continua servindo a quem precisa de
## esquina de verdade, como a verificacao.
static func esquinas_perto(centro: Vector3, minimo: float,
		maximo: float) -> Array[Vector4i]:
	var saida: Array[Vector4i] = []
	var ci := floori(centro.x / TAM)
	var cj := floori(centro.z / TAM)
	var alcance := ceili(maximo / TAM) + 1
	for di in range(-alcance, alcance + 1):
		var i := ci + di
		if not existe_x(i):
			continue
		for dj in range(-alcance, alcance + 1):
			var j := cj + dj
			if not existe_z(j):
				continue
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					var no := Vector4i(i, j, sx, sz)
					var d := ponto(no).distance_to(centro)
					if d >= minimo and d <= maximo:
						saida.append(no)
	return saida


## Da para andar por esta via? Todas, desde que a calcada caiba uma pessoa.
##
## A viela cabe: a calcada dela foi para um metro e meio. O que ela nao tem e
## MOVIMENTO — ver `atrativo_da_aresta`. Ela continua sendo o atalho escuro sem
## poste que a MalhaUrbana descreve; so deixou de ser um corredor onde quem entra
## fica preso na primeira soleira.
static func caminhavel(v: int) -> bool:
	return MalhaUrbana.largura_calcada(v) >= 1.4


## Peso de gente da aresta `k`.
##
## Viela leva um quinto: da para passar por ela e quase ninguem passa. E o que a
## torna o que ela deve ser — um atalho escuro por onde o jogador vai encontrar
## uma pessoa a cada tanto, e nao um fluxo de pedestres.
static func atrativo_da_aresta(no: Vector4i, k: int) -> float:
	if k >= 2:
		return 1.0
	var v := MalhaUrbana.via_z(no.y) if k == 1 else MalhaUrbana.via_x(no.x)
	return 0.2 if v == MalhaUrbana.Via.VIELA else 1.0


## A aresta `k` de um no corre por uma via caminhavel?
##
## As arestas 0 e 1 seguem calcada — a 0 pela linha X do no, a 1 pela linha Z. As
## outras duas atravessam a rua, e atravessar uma viela e curto e permitido.
static func aresta_caminhavel(no: Vector4i, k: int) -> bool:
	if k == 0:
		return caminhavel(MalhaUrbana.via_x(no.x))
	if k == 1:
		return caminhavel(MalhaUrbana.via_z(no.y))
	return true


## Quanto movimento de gente uma esquina tem, de 0 a 1.
##
## Sai do distrito, e nao de sorteio: rua de comercio tem gente, galpao nao tem,
## e terreno baldio nao tem ninguem. E isso que faz o jogador sentir que mudou de
## bairro sem precisar de placa.
static func movimento(no: Vector4i) -> float:
	var distrito := MalhaUrbana.distrito_de(no.x, no.y)
	match distrito:
		MalhaUrbana.Distrito.COMERCIAL:
			return 1.0
		MalhaUrbana.Distrito.RESIDENCIAL:
			return 0.65
		MalhaUrbana.Distrito.INDUSTRIAL:
			return 0.22
		_:
			return 0.05
