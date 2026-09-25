## A mesa de sinuca do bar: medidas, a geometria que a fisica usa (nariz das
## tabelas, bocas, cacapas, triangulo) e o modelo desenhado dela.
##
## Uma fonte so para as tres coisas. A fisica (`FisicaSinuca`) bate a bola no
## nariz da tabela que esta aqui; o desenho poe a borracha exatamente ali; o
## jogo (`JogoSinuca`) converte coordenada da mesa em mundo com a mesma altura
## de pano. Escritas em dois lugares, a bola quica a um centimetro da borracha
## que se ve.
##
## Coordenadas da mesa: x no comprimento, y na largura, z para cima, origem no
## centro do pano (o referencial do pooltool). No Godot, dentro do no da mesa:
## X = x, Y = altura, Z = -y — a troca preserva a mao do sistema, entao vetor
## de giro converte igual a vetor de posicao (`para_godot`).
##
## Mesa de bar de 7 pes: 1,98 x 0,99 de area de jogo, bola de 57,15 mm.
class_name MesaSinuca
extends RefCounted

## Raio da bola (2 1/4 polegadas).
const R := 0.028575
## Area de jogo, de nariz a nariz das tabelas.
const COMP := 1.98
const LARG := 0.99
## Altura do pano acima do chao.
const ALTURA_PANO := 0.79
## Altura do nariz da tabela acima do pano: 0,64 do diametro, a de mesa de
## verdade. E ela que decide o angulo em que a tabela "pega" a bola (Han 2005).
const NARIZ := 0.0366
## Borracha (do nariz ao fundo) e a tabua de madeira por tras dela.
const BORRACHA := 0.05
const MADEIRA := 0.105
## Boca das cacapas, medida entre as pontas das borrachas.
const BOCA_CANTO := 0.118
const BOCA_MEIO := 0.132
## Raio de captura da cacapa: a bola cujo centro entra aqui caiu.
const CAPTURA := 0.058

## Dimensoes de fora a fora, para colisao e para quem arruma o salao.
const FORA := Vector2(COMP + 2.0 * (BORRACHA + MADEIRA), LARG + 2.0 * (BORRACHA + MADEIRA))

## Cores das bolas (1 a 7 lisas, 9 a 15 listradas com a mesma cor).
const CORES: Array[Color] = [
	Color("f4f0e4"), Color("f2c21a"), Color("1f4fb4"), Color("d0281e"),
	Color("5a2a8a"), Color("f07a1a"), Color("1e7a3c"), Color("7a1e22"),
	Color("141414"),
]


## Onde o centro da bola fica, em altura, no referencial do no da mesa.
static func altura_bola() -> float:
	return ALTURA_PANO + R


## Referencial da mesa (x, y, z para cima) para o do no (X, Y, Z).
static func para_godot(p: Vector3) -> Vector3:
	return Vector3(p.x, p.z, -p.y)


## Posicao no pano (x, y) para o no, na altura do centro da bola.
static func no_pano(p: Vector2, acima: float = 0.0) -> Vector3:
	return Vector3(p.x, altura_bola() + acima, -p.y)


## E o inverso, para o mouse que aponta a mesa (bola na mao).
static func do_no(p: Vector3) -> Vector2:
	return Vector2(p.x, -p.z)


## Recuo de cada ponta de borracha a partir do canto, no canto: com as duas
## pontas a esta distancia, a boca (entre elas, na diagonal) e BOCA_CANTO.
static func _recuo_canto() -> float:
	return BOCA_CANTO / sqrt(2.0)


## Centros das seis cacapas: quatro de canto, duas do meio.
static func cacapas() -> PackedVector2Array:
	var hx := COMP * 0.5
	var hy := LARG * 0.5
	var p := PackedVector2Array()
	for sy: float in [-1.0, 1.0]:
		for sx: float in [-1.0, 1.0]:
			p.append(Vector2(sx * (hx + 0.022), sy * (hy + 0.022)))
		p.append(Vector2(0.0, sy * (hy + 0.046)))
	return p


## As borrachas como segmentos: o nariz reto de cada tabela, entre as bocas, e
## as bochechas das cacapas, que viram para dentro da boca. A fisica colide a
## bola (raio R) contra cada segmento, pontas incluidas.
static func segmentos() -> Array[PackedVector2Array]:
	var hx := COMP * 0.5
	var hy := LARG * 0.5
	var d := _recuo_canto()
	var m := BOCA_MEIO * 0.5
	const BOCHECHA := 0.045
	var s: Array[PackedVector2Array] = []
	for sy: float in [-1.0, 1.0]:
		# Tabela comprida, em duas metades (a cacapa do meio no centro).
		for sx: float in [-1.0, 1.0]:
			var a := Vector2(sx * (hx - d), sy * hy)
			var b := Vector2(sx * m, sy * hy)
			s.append(PackedVector2Array([a, b]))
			# Bochecha do canto nesta tabela: sai a 45 graus para a cacapa.
			s.append(PackedVector2Array([a, a + Vector2(sx, sy).normalized() * BOCHECHA]))
			# Bochecha da cacapa do meio: quase reta, fechando um pouco a garganta.
			s.append(PackedVector2Array([b, b + Vector2(-sx * 0.012, sy * BOCHECHA)]))
	for sx: float in [-1.0, 1.0]:
		# Tabela curta (cabeceira e pe).
		var a := Vector2(sx * hx, -(hy - d))
		var b := Vector2(sx * hx, hy - d)
		s.append(PackedVector2Array([a, b]))
		for sy: float in [-1.0, 1.0]:
			var ponta := Vector2(sx * hx, sy * (hy - d))
			s.append(PackedVector2Array([ponta, ponta + Vector2(sx, sy).normalized() * BOCHECHA]))
	return s


## A marca do pe (onde fica a bola da frente do triangulo) e a linha de cabeceira.
static func marca_do_pe() -> Vector2:
	return Vector2(COMP * 0.25, 0.0)


static func linha_de_cabeceira() -> float:
	return -COMP * 0.25


## O triangulo da bola 8: posicao de cada bola (1 a 15) no rack.
##
## A 1 na ponta, a 8 no meio da terceira fileira, e nos dois cantos de tras uma
## lisa e uma listrada. O resto e embaralhado pela semente. Um decimo de
## milimetro entre as bolas: encostadas de verdade, a fisica ja nasce resolvendo
## sobreposicao.
static func triangulo(semente: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var lugares: Array[Vector2] = []
	var passo_x := 2.0 * R * cos(PI / 6.0) + 0.0001
	var pe := marca_do_pe()
	for fileira in 5:
		for j in fileira + 1:
			lugares.append(pe + Vector2(passo_x * float(fileira),
				(float(j) - float(fileira) * 0.5) * (2.0 * R + 0.0001)))
	# Indices em `lugares`: 0 ponta, 4 meio da 3a fileira, 10 e 14 cantos de tras.
	var resto: Array[int] = [2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]
	var lisa_no_canto := 1 + rng.randi() % 7
	var listrada_no_canto := 9 + rng.randi() % 7
	if lisa_no_canto == 1:
		lisa_no_canto = 2
	resto.erase(lisa_no_canto)
	resto.erase(listrada_no_canto)
	# Embaralha deterministico (Fisher-Yates com o rng proprio).
	for k in range(resto.size() - 1, 0, -1):
		var t := rng.randi() % (k + 1)
		var tmp := resto[k]
		resto[k] = resto[t]
		resto[t] = tmp
	var bola_de: Dictionary = {0: 1, 4: 8}
	if rng.randf() < 0.5:
		bola_de[10] = lisa_no_canto
		bola_de[14] = listrada_no_canto
	else:
		bola_de[10] = listrada_no_canto
		bola_de[14] = lisa_no_canto
	var k := 0
	for idx in lugares.size():
		if bola_de.has(idx):
			continue
		bola_de[idx] = resto[k]
		k += 1
	var saida := {}
	for idx: int in bola_de:
		saida[int(bola_de[idx])] = lugares[idx]
	return saida
