## O tracado das ruas dentro de cada celula de avenidas.
##
## Por que existe
## -------------
## A malha anterior punha cada rua secundaria numa linha de grade INTEIRA: a rua
## que passava em x = 224 passava em x = 224 do comeco ao fim do mundo. Com uma
## secundaria sorteada por faixa, todo quarteirao era um retangulo do mesmo
## tabuleiro, todo cruzamento era de quatro bracos, e nenhuma rua terminava em
## lugar nenhum. E a cara de cidade planejada de cima para baixo — o oposto de
## cidade do interior, onde a rua de tras da igreja acaba na parede da escola, a
## transversal muda de lugar depois do largo e metade das esquinas e um T.
##
## Aqui a avenida continua a cada cinco chunks, nas duas direcoes, e e a unica
## linha inteira: e a referencia que o jogador usa para nunca se perder. Dentro
## de cada celula de 5 x 5 chunks entre avenidas, as ruas saem de uma divisao
## binaria: a celula e cortada por uma rua de ponta a ponta, cada metade pode
## ser cortada de novo na outra direcao, e assim ate o quarteirao ter dois chunks
## de lado. Os cortes das duas metades nao combinam — e dai que nasce o T, a
## rua que desencontra da outra do lado de la da transversal e o quarteirao
## comprido ao lado do quadrado.
##
## Toda quadra continua sendo um retangulo de chunks, e toda borda de chunk
## continua tendo uma via so. Quem desenha o chunk, o mapa, o carro e o pedestre
## so precisaram parar de supor que a rua de uma linha vai ate o infinito.
##
## Regra que o transito cobra
## --------------------------
## Rua (dirigivel) so pode terminar em outra via dirigivel. Um corte que encosta
## numa viela vira viela tambem: rua que acaba numa viela e beco sem saida de
## carro, e o carro chegaria na ponta e daria meia-volta no meio do asfalto.
##
## Ancoras
## -------
## A Praca da Matriz e cenario de cutscene com enquadramento fixo em coordenada
## de mundo (o pino do acordar e a IGREJA_ANCORA em cidade.gd). A celula dela e
## ANCORADA: o tracado e o que ela sempre teve — a RUA em x = 224 e a VIELA em
## z = -96 cruzando a celula inteira —, e a quadra da praca continua x 7..10,
## z -3..0 com a mesma area util. Qualquer mudanca aqui move a igreja para fora
## da camera; combine antes com quem cuida da praca.
class_name Tracado
extends RefCounted

## Lado minimo de uma quadra, em chunks. Com um chunk so, a fileira de um lado
## encostaria na do outro e nao sobraria quintal.
const LADO_MINIMO := 2

## Chance de uma via secundaria ser viela, se puder ser rua.
const CHANCE_VIELA := 0.22

## Chance de parar de dividir, pelo maior lado do retangulo. A celula inteira
## quase nunca fica sem rua nenhuma (e onde cabe o parque grande); o retangulo
## de cinco por dois ou tres fica comprido uma vez em oito, que e o quarteirao
## de rua de tras; o de quatro, uma em cinco. Com um quarto e um terco, que foi
## a primeira regua, sobrava quarteirao de 160 x 96 m demais — cidade do
## interior anda de esquina em esquina a cada oitenta metros.
const PARAR_5X5 := 0.06
const PARAR_5 := 0.12
const PARAR_4 := 0.2

static var _cache: Dictionary = {}
static var _trava := Mutex.new()


# --- consulta ---------------------------------------------------------------

## Via na linha x = i * 32, no trecho entre z = j * 32 e z = (j + 1) * 32.
static func via_x_em(i: int, j: int) -> int:
	var p := MalhaUrbana.PERIODO
	if posmod(i, p) == 0:
		return MalhaUrbana.Via.AVENIDA
	var cel := _celula(floori(float(i) / p), floori(float(j) / p))
	return int(cel["vx"].get(Vector2i(i, j), MalhaUrbana.Via.NENHUMA))


## Via na linha z = j * 32, no trecho entre x = i * 32 e x = (i + 1) * 32.
static func via_z_em(j: int, i: int) -> int:
	var p := MalhaUrbana.PERIODO
	if posmod(j, p) == 0:
		return MalhaUrbana.Via.AVENIDA
	var cel := _celula(floori(float(i) / p), floori(float(j) / p))
	return int(cel["vz"].get(Vector2i(j, i), MalhaUrbana.Via.NENHUMA))


## A quadra a que o chunk pertence, em indices de chunk (semiaberta).
static func quadra(cx: int, cz: int) -> Rect2i:
	var p := MalhaUrbana.PERIODO
	var cel := _celula(floori(float(cx) / p), floori(float(cz) / p))
	return cel["bloco"][Vector2i(cx, cz)]


# --- celula -----------------------------------------------------------------

static func _celula(ci: int, cj: int) -> Dictionary:
	var chave := Vector2i(ci, cj)
	_trava.lock()
	var achada: Variant = _cache.get(chave)
	_trava.unlock()
	if achada != null:
		return achada
	var nova := _montar(ci, cj)
	_trava.lock()
	# Teto de memoria. As celulas sao baratas de refazer e quem ja tem uma nas
	# maos continua com ela: o dicionario nao muda depois de montado.
	if _cache.size() > 4096:
		_cache.clear()
	_cache[chave] = nova
	_trava.unlock()
	return nova


static func _montar(ci: int, cj: int) -> Dictionary:
	var p := MalhaUrbana.PERIODO
	var cel := {"vx": {}, "vz": {}, "bloco": {}}
	var r := Rect2i(ci * p, cj * p, p, p)
	var ancora := _ancora(ci, cj)
	if not ancora.is_empty():
		for corte: Array in ancora:
			_marcar(cel, int(corte[0]), int(corte[1]), int(corte[2]), int(corte[3]),
				int(corte[4]))
	elif Serpentina.celula(ci, cj):
		# Celula de encosta: um quarteirao so, e no miolo a rua que sobe o morro
		# em curva (Serpentina). As quatro avenidas em volta continuam.
		pass
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = MalhaUrbana._ruido(ci, cj, 7331)
		# As quatro bordas da celula sao avenida: dirigiveis.
		_dividir(cel, r, [true, true, true, true], rng)
	_blocos(cel, r)
	return cel


## Tracado fixo de uma celula, ou vazio. Cada corte e
## [eixo (0 linha x, 1 linha z), linha, de, ate, via].
static func _ancora(ci: int, cj: int) -> Array:
	# Praca da Matriz: quadra x 7..10 / z -3..0. Ver o cabecalho.
	if ci == 1 and cj == -1:
		return [
			[0, 7, -5, 0, MalhaUrbana.Via.RUA],
			[1, -3, 5, 10, MalhaUrbana.Via.VIELA],
		]
	return []


## Divide `r` recursivamente. `dirigivel` diz, para cada lado [x0, x1, z0, z1],
## se a via que o fecha e dirigivel — um corte so pode ser rua se as duas pontas
## dele encostarem em via dirigivel.
static func _dividir(cel: Dictionary, r: Rect2i, dirigivel: Array,
		rng: RandomNumberGenerator) -> void:
	var w := r.size.x
	var h := r.size.y
	var pode_x := w >= LADO_MINIMO * 2
	var pode_z := h >= LADO_MINIMO * 2
	if not pode_x and not pode_z:
		return
	var parar := PARAR_4
	if w == 5 and h == 5:
		parar = PARAR_5X5
	elif maxi(w, h) == 5:
		parar = PARAR_5
	if rng.randf() < parar:
		return

	# Corta atravessando o lado maior: um quarteirao de 5 x 2 cortado ao
	# comprido viraria duas faixas de um chunk.
	var em_x := pode_x
	if pode_x and pode_z:
		em_x = w > h or (w == h and rng.randf() < 0.5)
	var tamanho := w if em_x else h
	var k := rng.randi_range(LADO_MINIMO, tamanho - LADO_MINIMO)

	# As pontas do corte encostam nos lados perpendiculares a ele.
	var pontas_ok: bool = (bool(dirigivel[2]) and bool(dirigivel[3])) if em_x \
		else (bool(dirigivel[0]) and bool(dirigivel[1]))
	var via := MalhaUrbana.Via.RUA
	if not pontas_ok or rng.randf() < CHANCE_VIELA:
		via = MalhaUrbana.Via.VIELA
	var dirige := via != MalhaUrbana.Via.VIELA

	if em_x:
		var linha := r.position.x + k
		_marcar(cel, 0, linha, r.position.y, r.end.y, via)
		_dividir(cel, Rect2i(r.position.x, r.position.y, k, h),
			[dirigivel[0], dirige, dirigivel[2], dirigivel[3]], rng)
		_dividir(cel, Rect2i(linha, r.position.y, w - k, h),
			[dirige, dirigivel[1], dirigivel[2], dirigivel[3]], rng)
	else:
		var linha := r.position.y + k
		_marcar(cel, 1, linha, r.position.x, r.end.x, via)
		_dividir(cel, Rect2i(r.position.x, r.position.y, w, k),
			[dirigivel[0], dirigivel[1], dirigivel[2], dirige], rng)
		_dividir(cel, Rect2i(r.position.x, linha, w, h - k),
			[dirigivel[0], dirigivel[1], dirige, dirigivel[3]], rng)


static func _marcar(cel: Dictionary, eixo: int, linha: int, de: int, ate: int,
		via: int) -> void:
	for t in range(de, ate):
		if eixo == 0:
			cel["vx"][Vector2i(linha, t)] = via
		else:
			cel["vz"][Vector2i(linha, t)] = via


## Quadras da celula: os chunks ligados sem via entre eles. A divisao binaria
## garante que cada componente e um retangulo, e o retangulo e o que se guarda.
static func _blocos(cel: Dictionary, r: Rect2i) -> void:
	var visto := {}
	for cz in range(r.position.y, r.end.y):
		for cx in range(r.position.x, r.end.x):
			var c := Vector2i(cx, cz)
			if visto.has(c):
				continue
			var fila: Array[Vector2i] = [c]
			var membros: Array[Vector2i] = []
			visto[c] = true
			var mn := c
			var mx := c
			while not fila.is_empty():
				var a: Vector2i = fila.pop_back()
				membros.append(a)
				mn = Vector2i(mini(mn.x, a.x), mini(mn.y, a.y))
				mx = Vector2i(maxi(mx.x, a.x), maxi(mx.y, a.y))
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0),
						Vector2i(0, 1), Vector2i(0, -1)]:
					var b := a + d
					if not r.has_point(b) or visto.has(b):
						continue
					if _separados(cel, a, b):
						continue
					visto[b] = true
					fila.append(b)
			var bloco := Rect2i(mn, mx - mn + Vector2i.ONE)
			for m: Vector2i in membros:
				cel["bloco"][m] = bloco


## Ha via entre dois chunks vizinhos da mesma celula?
static func _separados(cel: Dictionary, a: Vector2i, b: Vector2i) -> bool:
	if a.y == b.y:
		var linha := maxi(a.x, b.x)
		return int(cel["vx"].get(Vector2i(linha, a.y), MalhaUrbana.Via.NENHUMA)) \
			!= MalhaUrbana.Via.NENHUMA
	var linha_z := maxi(a.y, b.y)
	return int(cel["vz"].get(Vector2i(linha_z, a.x), MalhaUrbana.Via.NENHUMA)) \
		!= MalhaUrbana.Via.NENHUMA
