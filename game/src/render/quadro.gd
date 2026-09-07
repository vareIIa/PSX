## A bicicleta de PS1: tubos de quatro e seis lados, e duas rodas que sao um
## quadrilatero recortado cada uma.
##
## Por que nao e uma Carroceria
## ----------------------------
## Carro e volume: caixa, chanfro, vidro. Bicicleta e LINHA — o que o olho
## reconhece nela e o desenho do quadro contra o fundo, e nao a superficie. Por
## isso aqui nao ha uma unica caixa estrutural: ha um construtor de TUBO, e o
## resto e a lista de catorze tubos que formam um quadro de bicicleta de rua.
##
## Um tubo e um prisma de quatro ou seis lados. O que faz ele ler como cano
## redondo nao e a contagem de lados, e a UV: V corre ao redor da circunferencia,
## e a celula do atlas tem uma faixa clara no meio e escura embaixo. O prisma de
## quatro lados sai com brilho no alto e sombra por baixo, que e tudo que o olho
## precisa a essa distancia.
##
## Orcamento de chamada de desenho
## -------------------------------
## Cinco, e nao uma, porque quatro pedacos PRECISAM girar por conta propria:
##
##   quadro     tubos, selim, canote, corrente, refletor  — nao gira
##   guidao     mesa, garfo, guidao, manoplas, sino, farol — gira no esterco
##   roda       pneu e raios                               — gira no rolamento
##   pedivela   bracos, pedais e coroa                     — gira com a pedalada
##
## A malha da roda e UMA so, usada pelas duas: elas sao identicas e nada no
## desenho distingue dianteira de traseira numa bicicleta.
##
## Cerca de 270 triangulos ao todo. E mais que o teto de prop do ART-BIBLE
## secao 10, e menos que um carro — o que esta certo, porque isto nao e cenario:
## e um veiculo que o jogador ve de perto, parado, encostado numa parede.
class_name Quadro
extends RefCounted

const MATERIAL := "res://resources/materials/mat_bicicleta.tres"

## Atlas de 128x128 dividido em celulas de 32. Ver tools/gerar_bicicleta.py.
const CELULA := 32.0
const ATLAS := 128.0

const C_TUBO := Vector2i(0, 0)
const C_CROMO := Vector2i(1, 0)
const C_COURO := Vector2i(2, 0)
const C_BORRACHA := Vector2i(3, 0)
const C_PNEU := Vector2i(0, 1)
const C_ARO := Vector2i(1, 1)
const C_COROA := Vector2i(2, 1)
const C_LATAO := Vector2i(3, 1)
const C_FAROL := Vector2i(0, 2)
const C_REFLETOR := Vector2i(1, 2)
const C_CORRENTE := Vector2i(2, 2)

# --- medidas, em metros -----------------------------------------------------
## Aro 26 com pneu de rua: 0,34 m do cubo ao chao. E a medida que decide a
## altura de tudo, porque o cubo da roda e o unico ponto do desenho cuja altura
## nao e escolha.
const RAIO_RODA := 0.34
## O pneu e uma cinta um pouco mais estreita que o raio total, para o aro
## desenhado na textura aparecer por dentro dele.
const RAIO_PNEU := 0.325
const LARGURA_PNEU := 0.045
## Meia-medida do quadrilatero dos raios. O circulo do aro ocupa quase a celula
## inteira (15,5 px de 16), entao o quadrilatero e um pouco maior que o aro.
const MEIA_ARO := 0.312
## Lados do pneu. Doze e o ponto em que a roda para de ter quina visivel a
## 480x270; o decimo terceiro nao muda um pixel e custa dois triangulos.
const LADOS_PNEU := 12

const ENTRE_EIXOS := 1.06
## Onde ficam os dois cubos, contados do centro da bicicleta.
const EIXO_FRENTE := -ENTRE_EIXOS * 0.5
const EIXO_TRAS := ENTRE_EIXOS * 0.5

## Centro do movimento central — onde o pedivela gira.
const PEDALEIRA := Vector3(0.0, 0.27, 0.20)
## Comprimento do braco do pedivela.
const BRACO_PEDAL := 0.17

const ALTURA_SELIM := 1.00
const ALTURA_GUIDAO := 1.045
## Largura do guidao, de ponta a ponta.
const LARGURA_GUIDAO := 0.58

## Pintura do quadro. Tom de esmalte de bicicleta velha: nada saturado, porque
## uma bicicleta encostada numa parede na chuva nao brilha.
const TINTAS: Array[Color] = [
	Color(0.24, 0.42, 0.36), Color(0.52, 0.18, 0.16),
	Color(0.20, 0.30, 0.48), Color(0.68, 0.62, 0.48),
	Color(0.30, 0.30, 0.32),
]

const CROMO := Color(0.78, 0.80, 0.82)
const PRETO := Color(0.22, 0.22, 0.23)
const COURO := Color(0.34, 0.24, 0.18)


## Tudo que a Bicicleta precisa para se montar.
##
## Devolve as quatro malhas mais as medidas de que o no depende para posicionar
## os pivos. Quem chama nao precisa saber onde fica a caixa de direcao — so que
## o guidao gira em volta do eixo dianteiro.
static func montar(tinta: Color) -> Dictionary:
	var quadro := PSXMesh.dados_vazios()
	var guidao := PSXMesh.dados_vazios()
	var roda := PSXMesh.dados_vazios()
	var pedivela := PSXMesh.dados_vazios()

	_quadro(quadro, tinta)
	_selim(quadro)
	_corrente(quadro)
	_guidao(guidao)
	_roda(roda)
	_pedivela(pedivela)

	return {
		"quadro": PSXMesh.dados_para_mesh(quadro),
		"guidao": PSXMesh.dados_para_mesh(guidao),
		"roda": PSXMesh.dados_para_mesh(roda),
		"pedivela": PSXMesh.dados_para_mesh(pedivela),
		"triangulos": (PSXMesh.dados_triangulos(quadro)
			+ PSXMesh.dados_triangulos(guidao)
			+ PSXMesh.dados_triangulos(roda) * 2
			+ PSXMesh.dados_triangulos(pedivela)),
		"cor": tinta,
	}


static func sortear_tinta(semente: int) -> Color:
	return TINTAS[absi(semente * 2654435761) % TINTAS.size()]


# --- pecas ------------------------------------------------------------------

## Os pontos do quadro, nomeados uma vez so.
##
## Estao aqui, e nao espalhados pelas funcoes, porque tres pecas diferentes
## precisam concordar sobre eles: o tubo horizontal e o tubo inferior se
## encontram na caixa de direcao, e o garfo — que mora em outra malha, porque
## gira — precisa nascer exatamente onde a caixa de direcao termina.
const P_DIRECAO_ALTA := Vector3(0.0, 0.995, -0.405)
const P_DIRECAO_BAIXA := Vector3(0.0, 0.755, -0.355)
const P_SELIM_ALTO := Vector3(0.0, 0.88, 0.310)
const P_CUBO_TRAS := Vector3(0.0, RAIO_RODA, EIXO_TRAS)


static func _quadro(dados: Dictionary, tinta: Color) -> void:
	# Losango classico: selim, horizontal, inferior e caixa de direcao.
	_tubo(dados, PEDALEIRA, P_SELIM_ALTO, 0.026, 6, C_TUBO, tinta)
	_tubo(dados, Vector3(0.0, 0.855, 0.295), Vector3(0.0, 0.950, -0.385),
		0.024, 6, C_TUBO, tinta)
	_tubo(dados, PEDALEIRA, Vector3(0.0, 0.790, -0.375), 0.028, 6, C_TUBO, tinta)
	_tubo(dados, P_DIRECAO_BAIXA, P_DIRECAO_ALTA, 0.032, 6, C_TUBO, tinta)

	# Triangulo traseiro: bainhas embaixo, tirantes em cima, dois de cada.
	for s: float in [1.0, -1.0]:
		var cubo := P_CUBO_TRAS + Vector3(s * 0.052, 0.0, 0.0)
		_tubo(dados, PEDALEIRA + Vector3(s * 0.045, 0.0, 0.0), cubo,
			0.014, 4, C_TUBO, tinta)
		_tubo(dados, Vector3(0.0, 0.845, 0.295), cubo, 0.013, 4, C_TUBO, tinta)

	# Canote, cromado, saindo do tubo do selim.
	_tubo(dados, Vector3(0.0, 0.850, 0.300), Vector3(0.0, ALTURA_SELIM - 0.02, 0.312),
		0.017, 4, C_CROMO, CROMO)

	# Refletor traseiro, atras do canote. Duas faces, porque ele so existe para
	# ser visto de tras e de tras ele e um retangulo vermelho.
	_placa(dados, Vector2(0.07, 0.045),
		Transform3D(Basis(), Vector3(0.0, 0.90, 0.345)),
		C_REFLETOR, Color.WHITE)


## O selim. Nao e uma caixa: e um bico afinado na frente, e a diferenca entre os
## dois e a unica coisa que diz de longe que aquilo e um assento de bicicleta.
static func _selim(dados: Dictionary) -> void:
	var y := ALTURA_SELIM
	var z := 0.312
	var tras_e := Vector3(-0.055, y, z + 0.105)
	var tras_d := Vector3(0.055, y, z + 0.105)
	var meio_e := Vector3(-0.045, y, z - 0.02)
	var meio_d := Vector3(0.045, y, z - 0.02)
	var bico_e := Vector3(-0.012, y - 0.01, z - 0.135)
	var bico_d := Vector3(0.012, y - 0.01, z - 0.135)

	_quadrilatero(dados, tras_d, tras_e, meio_e, meio_d, C_COURO, COURO)
	_quadrilatero(dados, meio_d, meio_e, bico_e, bico_d, C_COURO, COURO)

	# Saia do selim: a faixa vertical em volta, que da espessura ao couro. O
	# contorno e percorrido no sentido horario visto de cima, entao cada aresta
	# vira um quadrilatero virado para fora sem precisar de caso especial.
	var baixo := Vector3(0.0, -0.035, 0.0)
	var contorno: Array[Vector3] = [tras_d, meio_d, bico_d, bico_e, meio_e, tras_e]
	for k in contorno.size():
		var a: Vector3 = contorno[k]
		var b: Vector3 = contorno[(k + 1) % contorno.size()]
		_quadrilatero(dados, a, b, b + baixo, a + baixo, C_COURO, COURO * 0.7)


## Os dois ramos da corrente, da coroa ao cubo traseiro.
##
## E um quadrilatero por ramo, no plano da coroa, com os elos desenhados na
## textura. Corrente modelada seriam cento e poucos elos para uma linha de dois
## pixels de espessura na tela.
static func _corrente(dados: Dictionary) -> void:
	var x := 0.062
	var coroa_alta := Vector3(x, PEDALEIRA.y + 0.095, PEDALEIRA.z)
	var coroa_baixa := Vector3(x, PEDALEIRA.y - 0.095, PEDALEIRA.z)
	var cubo_alto := Vector3(x, P_CUBO_TRAS.y + 0.032, P_CUBO_TRAS.z)
	var cubo_baixo := Vector3(x, P_CUBO_TRAS.y - 0.032, P_CUBO_TRAS.z)
	var fino := Vector3(0.0, 0.016, 0.0)

	_quadrilatero(dados, coroa_alta - fino, cubo_alto - fino, cubo_alto + fino,
		coroa_alta + fino, C_CORRENTE, PRETO, true)
	_quadrilatero(dados, coroa_baixa - fino, cubo_baixo - fino, cubo_baixo + fino,
		coroa_baixa + fino, C_CORRENTE, PRETO, true)


## Tudo que gira quando se esterca: garfo, mesa, guidao, manoplas, sino e farol.
##
## As coordenadas sao relativas ao PIVO do esterco, que fica no eixo dianteiro.
## O eixo de esterco de verdade e inclinado, o da caixa de direcao; aqui ele e
## vertical, e a diferenca a 480x270 e menor que um pixel em qualquer angulo que
## a bicicleta consiga fazer.
static func _guidao(dados: Dictionary) -> void:
	var dz := -EIXO_FRENTE

	# Garfo: duas pernas da coroa do garfo ate o cubo, com uma leve curva para
	# a frente na ponta — que e o avanco, e e o que impede a bicicleta de
	# parecer um triciclo cortado ao meio.
	var coroa := Vector3(0.0, 0.740, -0.365 + dz)
	for s: float in [1.0, -1.0]:
		var meio := Vector3(s * 0.038, 0.520, -0.385 + dz)
		var cubo := Vector3(s * 0.046, RAIO_RODA, 0.0)
		_tubo(dados, coroa, meio, 0.018, 4, C_CROMO, CROMO)
		_tubo(dados, meio, cubo, 0.015, 4, C_CROMO, CROMO)

	# Mesa: da caixa de direcao ate a barra.
	var topo_direcao := Vector3(0.0, 0.985, P_DIRECAO_ALTA.z + dz)
	var centro_barra := Vector3(0.0, ALTURA_GUIDAO, P_DIRECAO_ALTA.z + dz + 0.055)
	_tubo(dados, topo_direcao, centro_barra, 0.019, 4, C_CROMO, CROMO)

	# Barra reta com as duas pontas puxadas para tras, que e o guidao de
	# bicicleta de cidade. Guidao reto de ponta a ponta le como bicicleta de
	# corrida, e esta nao e.
	var meia := LARGURA_GUIDAO * 0.5 - 0.06
	for s: float in [1.0, -1.0]:
		var ponta_reta := centro_barra + Vector3(s * meia, 0.0, 0.0)
		var ponta_curva := ponta_reta + Vector3(s * 0.055, 0.006, 0.062)
		_tubo(dados, centro_barra, ponta_reta, 0.016, 4, C_CROMO, CROMO)
		_tubo(dados, ponta_reta, ponta_curva, 0.016, 4, C_CROMO, CROMO)
		# Manopla de borracha, engrossada por cima da ponta.
		_tubo(dados, ponta_curva - Vector3(s * 0.052, 0.0, 0.0) * 0.9,
			ponta_curva, 0.023, 4, C_BORRACHA, Color(0.9, 0.9, 0.9))

	_sino(dados, centro_barra + Vector3(-meia + 0.085, 0.012, 0.030))
	_farol(dados, Vector3(0.0, 0.700, -0.435 + dz))


## O sino. Cupula de latao com a alavanca de polegar.
##
## Doze triangulos numa peca de tres centimetros parece caro, e nao e: e a peca
## que o jogador pede pelo nome, e o objeto que ele vai olhar de perto para
## conferir se existe antes de apertar a tecla.
static func _sino(dados: Dictionary, centro: Vector3) -> void:
	var raio := 0.028
	var altura := 0.030
	var lados := 6
	var latao := Color(1.0, 1.0, 1.0)

	# Cinta lateral.
	for k in lados:
		var a0 := TAU * float(k) / float(lados)
		var a1 := TAU * float(k + 1) / float(lados)
		var p0 := centro + Vector3(cos(a0) * raio, 0.0, sin(a0) * raio)
		var p1 := centro + Vector3(cos(a1) * raio, 0.0, sin(a1) * raio)
		var alto := Vector3(0.0, altura, 0.0)
		_quadrilatero(dados, p1, p0, p0 + alto, p1 + alto, C_LATAO, latao)

	# Tampa: leque de seis triangulos, um pouco menor que a cinta, que e o que
	# faz a cupula parecer abaulada em vez de um copo.
	var topo := centro + Vector3(0.0, altura + 0.006, 0.0)
	for k in lados:
		var a0 := TAU * float(k) / float(lados)
		var a1 := TAU * float(k + 1) / float(lados)
		var p0 := centro + Vector3(cos(a0) * raio * 0.94, altura, sin(a0) * raio * 0.94)
		var p1 := centro + Vector3(cos(a1) * raio * 0.94, altura, sin(a1) * raio * 0.94)
		_triangulo(dados, p0, p1, topo, C_LATAO, latao)

	# Alavanca do polegar, do lado de fora.
	var l0 := centro + Vector3(-raio - 0.004, 0.006, -0.006)
	var l1 := l0 + Vector3(-0.020, 0.0, 0.0)
	_quadrilatero(dados, l0, l1, l1 + Vector3(0.0, 0.0, 0.016),
		l0 + Vector3(0.0, 0.0, 0.016), C_LATAO, latao * 0.8, true)


## Farol de dinamo, preso na coroa do garfo. Nao acende sozinho: a Bicicleta
## pendura uma SpotLight3D nele quando o jogador liga.
static func _farol(dados: Dictionary, centro: Vector3) -> void:
	var caixa := Vector3(0.072, 0.062, 0.048)
	_caixa(dados, caixa, centro, C_CROMO, CROMO)
	_placa(dados, Vector2(0.062, 0.052),
		Transform3D(Basis(Vector3.UP, PI),
			centro + Vector3(0.0, 0.0, -caixa.z * 0.5 - 0.002)),
		C_FAROL, Color.WHITE)


## A roda: uma cinta de doze lados para o pneu e um quadrilatero para o resto.
##
## O quadrilatero e o motivo de a bicicleta ter roda de bicicleta e nao roda de
## carrinho. Aro, raios e cubo estao desenhados nele com alfa, e o material
## corta o vazio — entao ve-se a rua ATRAVES da roda, que e a coisa que mais
## distingue uma bicicleta de qualquer outro veiculo do jogo.
##
## Ele vem em duas copias com o giro invertido porque o shader corta a face de
## tras. Sem a segunda copia a roda desapareceria ao se olhar a bicicleta do
## outro lado, que e metade das vezes.
static func _roda(dados: Dictionary) -> void:
	var meia_larg := LARGURA_PNEU * 0.5
	for k in LADOS_PNEU:
		var a0 := TAU * float(k) / float(LADOS_PNEU)
		var a1 := TAU * float(k + 1) / float(LADOS_PNEU)
		var d0 := Vector3(0.0, sin(a0), cos(a0))
		var d1 := Vector3(0.0, sin(a1), cos(a1))
		var p0 := d0 * RAIO_PNEU
		var p1 := d1 * RAIO_PNEU
		var lado := Vector3(meia_larg, 0.0, 0.0)
		# Cada segmento leva a celula inteira: doze repeticoes da banda ao redor
		# da roda, de graca, porque a UV nunca sai da celula.
		_quadrilatero(dados, p0 - lado, p1 - lado, p1 + lado, p0 + lado,
			C_PNEU, PRETO, false, (d0 + d1).normalized())

	for giro: bool in [false, true]:
		var s := -1.0 if giro else 1.0
		var a := Vector3(0.0, -MEIA_ARO, s * MEIA_ARO)
		var b := Vector3(0.0, -MEIA_ARO, -s * MEIA_ARO)
		var c := Vector3(0.0, MEIA_ARO, -s * MEIA_ARO)
		var d := Vector3(0.0, MEIA_ARO, s * MEIA_ARO)
		_quadrilatero(dados, a, b, c, d, C_ARO, Color(0.86, 0.88, 0.9))


## Bracos, pedais e coroa. Gira em volta do proprio X, na pedaleira.
static func _pedivela(dados: Dictionary) -> void:
	# Coroa, no plano da corrente, recortada como a roda e pelo mesmo motivo.
	for giro: bool in [false, true]:
		var s := -1.0 if giro else 1.0
		var r := 0.098
		var x := 0.062
		_quadrilatero(dados, Vector3(x, -r, s * r), Vector3(x, -r, -s * r),
			Vector3(x, r, -s * r), Vector3(x, r, s * r), C_COROA, CROMO)

	# Os dois bracos, opostos por construcao: quando um esta em cima o outro
	# esta embaixo, senao a pedalada nao le como pedalada.
	for s: float in [1.0, -1.0]:
		var raiz := Vector3(s * 0.036, 0.0, 0.0)
		var ponta := raiz + Vector3(s * 0.022, s * BRACO_PEDAL, 0.0)
		_tubo(dados, raiz, ponta, 0.015, 4, C_CROMO, CROMO)
		_caixa(dados, Vector3(0.088, 0.018, 0.062),
			ponta + Vector3(s * 0.048, 0.0, 0.0), C_BORRACHA, Color(0.9, 0.9, 0.9))


# --- primitivas -------------------------------------------------------------

## Retangulo de UV de uma celula, com meio texel de margem para o filtro nearest
## nao puxar a celula vizinha na borda.
static func uv(c: Vector2i) -> Rect2:
	var m := 0.5 / ATLAS
	return Rect2(
		Vector2(float(c.x) * CELULA / ATLAS + m, float(c.y) * CELULA / ATLAS + m),
		Vector2(CELULA / ATLAS - m * 2.0, CELULA / ATLAS - m * 2.0))


## Um tubo de `lados` faces entre dois pontos.
##
## A UV corre com U ao longo do tubo e com V ao redor dele. E o V que faz o
## trabalho: a celula tem o brilho no meio e a sombra na base, entao dar a cada
## face uma fatia diferente de V produz a curva de luz de um cilindro num solido
## que tem quatro lados.
static func _tubo(dados: Dictionary, de: Vector3, ate: Vector3, raio: float,
		lados: int, celula: Vector2i, cor: Color) -> void:
	var eixo := ate - de
	var comp := eixo.length()
	if comp < 0.0001:
		return
	eixo /= comp
	# Base perpendicular ao eixo. O UP so serve de referencia e nao pode ser
	# paralelo ao eixo, senao o produto vetorial some — o que acontece de fato
	# no canote, que e vertical.
	var referencia := Vector3.UP if absf(eixo.y) < 0.9 else Vector3.FORWARD
	var u := eixo.cross(referencia).normalized()
	var v := eixo.cross(u).normalized()

	var r := uv(celula)
	var verts: PackedVector3Array = dados["v"]
	var norms: PackedVector3Array = dados["n"]
	var uvs: PackedVector2Array = dados["uv"]
	var cores: PackedColorArray = dados["c"]
	var idx: PackedInt32Array = dados["i"]

	for k in lados:
		var a0 := TAU * float(k) / float(lados)
		var a1 := TAU * float(k + 1) / float(lados)
		var n0 := u * cos(a0) + v * sin(a0)
		var n1 := u * cos(a1) + v * sin(a1)
		var base := verts.size()
		var normal := (n0 + n1).normalized()
		for p: Vector3 in [de + n0 * raio, ate + n0 * raio,
				ate + n1 * raio, de + n1 * raio]:
			verts.append(p)
			norms.append(normal)
			cores.append(cor)
		var v0 := r.position.y + r.size.y * (float(k) / float(lados))
		var v1 := r.position.y + r.size.y * (float(k + 1) / float(lados))
		uvs.append(Vector2(r.position.x, v0))
		uvs.append(Vector2(r.position.x + r.size.x, v0))
		uvs.append(Vector2(r.position.x + r.size.x, v1))
		uvs.append(Vector2(r.position.x, v1))
		idx.append_array([base, base + 2, base + 1, base, base + 3, base + 2])

	dados["v"] = verts
	dados["n"] = norms
	dados["uv"] = uvs
	dados["c"] = cores
	dados["i"] = idx


## Quadrilatero arbitrario com uma celula do atlas, na ordem a-b-c-d.
static func _quadrilatero(dados: Dictionary, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3, celula: Vector2i, cor: Color, dois_lados: bool = false,
		normal_dada: Vector3 = Vector3.ZERO) -> void:
	var r := uv(celula)
	var verts: PackedVector3Array = dados["v"]
	var norms: PackedVector3Array = dados["n"]
	var uvs: PackedVector2Array = dados["uv"]
	var cores: PackedColorArray = dados["c"]
	var idx: PackedInt32Array = dados["i"]

	var normal := normal_dada
	if normal == Vector3.ZERO:
		normal = (d - a).cross(b - a).normalized()
	var base := verts.size()
	for p: Vector3 in [a, b, c, d]:
		verts.append(p)
		norms.append(normal)
		cores.append(cor)
	uvs.append(r.position + Vector2(0.0, r.size.y))
	uvs.append(r.position + r.size)
	uvs.append(r.position + Vector2(r.size.x, 0.0))
	uvs.append(r.position)
	idx.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	if dois_lados:
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

	dados["v"] = verts
	dados["n"] = norms
	dados["uv"] = uvs
	dados["c"] = cores
	dados["i"] = idx


static func _triangulo(dados: Dictionary, a: Vector3, b: Vector3, c: Vector3,
		celula: Vector2i, cor: Color) -> void:
	var r := uv(celula)
	var verts: PackedVector3Array = dados["v"]
	var norms: PackedVector3Array = dados["n"]
	var uvs: PackedVector2Array = dados["uv"]
	var cores: PackedColorArray = dados["c"]
	var idx: PackedInt32Array = dados["i"]

	var normal := (c - a).cross(b - a).normalized()
	var base := verts.size()
	for p: Vector3 in [a, b, c]:
		verts.append(p)
		norms.append(normal)
		cores.append(cor)
	uvs.append(r.position + Vector2(0.0, r.size.y))
	uvs.append(r.position + r.size)
	uvs.append(r.position + Vector2(r.size.x * 0.5, 0.0))
	idx.append_array([base, base + 2, base + 1])

	dados["v"] = verts
	dados["n"] = norms
	dados["uv"] = uvs
	dados["c"] = cores
	dados["i"] = idx


## Placa de uma celula, virada para -Z antes da transformacao.
static func _placa(dados: Dictionary, tamanho: Vector2, xform: Transform3D,
		celula: Vector2i, cor: Color) -> void:
	var d := PSXMesh.placa_dados(tamanho, 100.0, Color.WHITE)
	var r := uv(celula)
	var uvs: PackedVector2Array = d["uv"]
	for k in uvs.size():
		uvs[k] = r.position + uvs[k] * r.size
	d["uv"] = uvs
	PSXMesh.acumular_tingido(dados, d, xform, cor)


## Caixa de seis faces, todas na mesma celula. Serve ao pedal e ao farol, que
## sao pequenos demais para valer face por face.
static func _caixa(dados: Dictionary, tamanho: Vector3, centro: Vector3,
		celula: Vector2i, cor: Color) -> void:
	var h := tamanho * 0.5
	var faces: Array[Array] = [
		[Vector2(tamanho.x, tamanho.y), Transform3D(Basis(), Vector3(0, 0, h.z))],
		[Vector2(tamanho.x, tamanho.y),
			Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -h.z))],
		[Vector2(tamanho.z, tamanho.y),
			Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(h.x, 0, 0))],
		[Vector2(tamanho.z, tamanho.y),
			Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-h.x, 0, 0))],
		[Vector2(tamanho.x, tamanho.z),
			Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, h.y, 0))],
		[Vector2(tamanho.x, tamanho.z),
			Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -h.y, 0))],
	]
	for f: Array in faces:
		var xform: Transform3D = f[1]
		xform.origin += centro
		_placa(dados, f[0], xform, celula, cor)
