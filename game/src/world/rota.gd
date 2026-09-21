## Caminho por rua de um ponto a outro da cidade. Funcao pura da coordenada.
##
## Por que da para tracar rota numa cidade infinita
## -----------------------------------------------
## Porque a malha nao e conteudo, e regra. `MalhaUrbana.via_x_em(i, j)` responde
## que rua passa em x = i * 32 naquele trecho sem que exista um triangulo ali, e responde a
## mesma coisa hoje e na proxima execucao. Entao o grafo de cruzamentos pode ser
## construido sob demanda, em volta so do trecho que interessa, e some depois.
##
## E a mesma promessa que o GPS ja cumpre ao listar um endereco em rua onde
## ninguem pisou (`gps.gd`). Sem isto, tracar rota exigiria a cidade carregada —
## e a cidade carregada tem 64 m de raio, enquanto o destino esta a 400.
##
## O que ela devolve
## -----------------
## Uma linha quebrada em coordenada de mundo (x, z). O primeiro ponto e onde o
## jogador esta, o ultimo e o destino, e o meio sao cruzamentos. As duas pontas
## sao ligadas em reta ao cruzamento mais perto: ninguem esta exatamente em cima
## de uma esquina, e fingir que esta faria a rota comecar a vinte metros de onde
## a pessoa esta.
##
## Por que avenida custa menos
## ---------------------------
## Porque o caminho mais curto nao e o caminho que se explica. Uma rota que corta
## seis vielas economiza trinta metros e e impossivel de seguir; uma que desce a
## avenida e vira uma vez e mais longa e o jogador chega. O peso por classe de
## via e o que faz a rota preferir o caminho que ele consegue contar para si
## mesmo — e a viela continua la para quem quiser cortar.
class_name Rota
extends RefCounted

const TAM := MalhaUrbana.TAM

## Peso por classe de via. Multiplica a distancia real, entao 1,0 e "o metro da
## avenida vale um metro" e 1,6 e "o metro da viela custa como 1,6".
const PESO := {
	MalhaUrbana.Via.AVENIDA: 1.0,
	MalhaUrbana.Via.RUA: 1.18,
	MalhaUrbana.Via.VIELA: 1.7,
}

## Folga de busca em volta da caixa que contem origem e destino, em chunks.
##
## Sem folga o A* fica preso quando a linha reta entre os dois pontos cai num
## miolo de quadra grande e a saida e por fora. Seis chunks sao 192 m de desvio
## permitido para cada lado, que cobre qualquer quarteirao que o gerador produz —
## o maior tem 160 m.
const FOLGA := 6

## Teto de nos visitados. Rede contra caixa gigante: um destino a dois mil metros
## pediria uma varredura que ninguem quer pagar num quadro. Acima disto a rota sai
## pelo melhor caminho achado ate ali, que ainda aponta para o lado certo.
const MAX_NOS := 6000


## Traca o caminho. Devolve vazio quando nao ha rota — o que so acontece com
## destino fora da caixa de busca, ja que a malha e conexa por construcao.
static func tracar(de: Vector3, para: Vector3) -> PackedVector2Array:
	var origem := Vector2(de.x, de.z)
	var destino := Vector2(para.x, para.z)
	var caixa := _caixa(origem, destino)
	var ini := _cruzamento_perto(origem, caixa)
	var fim := _cruzamento_perto(destino, caixa)
	var saida := PackedVector2Array()
	if ini == Vector2i.MAX or fim == Vector2i.MAX:
		return saida
	if ini == fim:
		saida.append(origem)
		saida.append(destino)
		return saida

	var veio := _buscar(ini, fim, caixa)
	if veio.is_empty():
		return saida

	# Reconstroi de tras para a frente e inverte: o A* so sabe de onde veio.
	var caminho: Array[Vector2i] = []
	var no := fim
	while no != ini:
		caminho.append(no)
		if not veio.has(no):
			return saida
		no = veio[no]
	caminho.append(ini)
	caminho.reverse()

	saida.append(origem)
	for c: Vector2i in caminho:
		saida.append(_mundo(c))
	saida.append(destino)
	return _simplificar(saida)


## Distancia percorrida pela rota, em metros. Serve para o aparelho dizer quanto
## falta ANDANDO, que e diferente da linha reta que a bussola mede.
static func comprimento(linha: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, linha.size()):
		total += linha[i - 1].distance_to(linha[i])
	return total


## A que distancia o ponto esta da rota. Quem anda sai dela, e quem sai precisa
## de uma rota nova — este e o numero que decide quando refazer.
static func desvio(linha: PackedVector2Array, ponto: Vector2) -> float:
	if linha.size() < 2:
		return INF
	var menor := INF
	for i in range(1, linha.size()):
		menor = minf(menor, _dist_ao_segmento(ponto, linha[i - 1], linha[i]))
	return menor


# --- grafo ------------------------------------------------------------------

## Caixa de busca em indices de chunk, ja com a folga.
static func _caixa(a: Vector2, b: Vector2) -> Rect2i:
	var ax := floori(minf(a.x, b.x) / TAM) - FOLGA
	var az := floori(minf(a.y, b.y) / TAM) - FOLGA
	var bx := ceili(maxf(a.x, b.x) / TAM) + FOLGA
	var bz := ceili(maxf(a.y, b.y) / TAM) + FOLGA
	return Rect2i(ax, az, bx - ax, bz - az)


static func _mundo(c: Vector2i) -> Vector2:
	return Vector2(float(c.x) * TAM, float(c.y) * TAM)


## Ha esquina no ponto de grade (i, j)? Quando uma via de cada eixo encosta
## nele — o cruzamento e o entroncamento em T. A mesma regra do pedestre.
static func _e_cruzamento(i: int, j: int) -> bool:
	return Rotas.existe_no(i, j)


## Cruzamento mais proximo do ponto, dentro da caixa. Varre em aneis a partir da
## celula do ponto: o primeiro anel que tem um cruzamento tem o mais perto, e a
## malha garante um a cada cinco chunks no maximo.
static func _cruzamento_perto(p: Vector2, caixa: Rect2i) -> Vector2i:
	var ci := roundi(p.x / TAM)
	var cj := roundi(p.y / TAM)
	for anel in range(0, MalhaUrbana.PERIODO + 2):
		var melhor := Vector2i.MAX
		var melhor_d := INF
		for dj in range(-anel, anel + 1):
			for di in range(-anel, anel + 1):
				# So a casca do anel: o miolo ja foi visto na volta anterior.
				if anel > 0 and absi(di) != anel and absi(dj) != anel:
					continue
				var i := ci + di
				var j := cj + dj
				if not _dentro(caixa, i, j) or not _e_cruzamento(i, j):
					continue
				var d := p.distance_squared_to(_mundo(Vector2i(i, j)))
				if d < melhor_d:
					melhor_d = d
					melhor = Vector2i(i, j)
		if melhor != Vector2i.MAX:
			return melhor
	return Vector2i.MAX


static func _dentro(caixa: Rect2i, i: int, j: int) -> bool:
	return i >= caixa.position.x and i <= caixa.position.x + caixa.size.x \
		and j >= caixa.position.y and j <= caixa.position.y + caixa.size.y


## Vizinhos de um cruzamento: o proximo cruzamento em cada um dos quatro lados,
## andando sobre a via que sai dali. Nao e "a celula ao lado" — entre dois
## cruzamentos pode haver ate cinco chunks sem esquina nenhuma.
##
## Devolve `[{"no": Vector2i, "custo": float}]`.
static func _vizinhos(no: Vector2i, caixa: Rect2i) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	# A rua existe por trecho: anda um chunk de cada vez enquanto houver via, e
	# soma o custo de cada trecho pela classe DELE — a mesma linha pode ser rua
	# de um lado da transversal e viela do outro.
	for passo: int in [1, -1]:
		# Leste/oeste, sobre a linha z = no.y * 32.
		var i := no.x
		var custo := 0.0
		while true:
			var via := MalhaUrbana.via_z_em(no.y, i if passo > 0 else i - 1)
			if via == MalhaUrbana.Via.NENHUMA:
				break
			custo += TAM * _peso(via)
			i += passo
			if not _dentro(caixa, i, no.y):
				break
			if _e_cruzamento(i, no.y):
				saida.append({"no": Vector2i(i, no.y), "custo": custo})
				break
		# Norte/sul, sobre a linha x = no.x * 32.
		var j := no.y
		custo = 0.0
		while true:
			var via := MalhaUrbana.via_x_em(no.x, j if passo > 0 else j - 1)
			if via == MalhaUrbana.Via.NENHUMA:
				break
			custo += TAM * _peso(via)
			j += passo
			if not _dentro(caixa, no.x, j):
				break
			if _e_cruzamento(no.x, j):
				saida.append({"no": Vector2i(no.x, j), "custo": custo})
				break
	return saida


static func _peso(v: int) -> float:
	return float(PESO.get(v, 1.4))


## A* com lista aberta em array. Sem fila de prioridade de proposito: a caixa de
## busca tem algumas centenas de cruzamentos e a varredura linear custa menos que
## manter um heap em GDScript — e o custo esta medido em `tests/custo_rota.gd`.
static func _buscar(ini: Vector2i, fim: Vector2i, caixa: Rect2i) -> Dictionary:
	var veio: Dictionary[Vector2i, Vector2i] = {}
	var g: Dictionary[Vector2i, float] = {ini: 0.0}
	var f: Dictionary[Vector2i, float] = {ini: _h(ini, fim)}
	var aberto: Array[Vector2i] = [ini]
	var fechado: Dictionary[Vector2i, bool] = {}
	var visitados := 0

	while not aberto.is_empty():
		var melhor := 0
		for k in range(1, aberto.size()):
			if f.get(aberto[k], INF) < f.get(aberto[melhor], INF):
				melhor = k
		var atual: Vector2i = aberto[melhor]
		if atual == fim:
			return veio
		aberto.remove_at(melhor)
		fechado[atual] = true
		visitados += 1
		if visitados > MAX_NOS:
			return veio

		for viz: Dictionary in _vizinhos(atual, caixa):
			var n: Vector2i = viz["no"]
			if fechado.has(n):
				continue
			var tentativa: float = g[atual] + float(viz["custo"])
			if tentativa >= g.get(n, INF):
				continue
			veio[n] = atual
			g[n] = tentativa
			f[n] = tentativa + _h(n, fim)
			if not aberto.has(n):
				aberto.append(n)
	return {}


## Heuristica: Manhattan em metros, no peso da avenida.
##
## Manhattan e nao linha reta porque nao da para cortar quadra — andar em
## diagonal nao existe nesta malha. E no peso MENOR de todos, senao a estimativa
## passaria do custo real e o A* deixaria de achar o melhor caminho.
static func _h(a: Vector2i, b: Vector2i) -> float:
	return (absf(float(a.x - b.x)) + absf(float(a.y - b.y))) * TAM \
		* float(PESO[MalhaUrbana.Via.AVENIDA])


## Tira o ponto do meio quando tres seguidos sao colineares.
##
## O A* devolve um no por esquina atravessada, inclusive as que a rota so passa
## reto. Num desenho de mapa isso nao muda um pixel, mas o chevron do "proximo
## giro" contaria seis curvas numa avenida reta.
static func _simplificar(linha: PackedVector2Array) -> PackedVector2Array:
	if linha.size() < 3:
		return linha
	var saida := PackedVector2Array()
	saida.append(linha[0])
	for i in range(1, linha.size() - 1):
		var a := linha[i] - linha[i - 1]
		var b := linha[i + 1] - linha[i]
		if a.length_squared() < 0.01 or b.length_squared() < 0.01:
			continue
		if absf(a.normalized().cross(b.normalized())) > 0.02:
			saida.append(linha[i])
	saida.append(linha[linha.size() - 1])
	return saida


static func _dist_ao_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := ab.length_squared()
	if t < 0.0001:
		return p.distance_to(a)
	var u := clampf((p - a).dot(ab) / t, 0.0, 1.0)
	return p.distance_to(a + ab * u)
