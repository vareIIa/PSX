## A escadaria de pedra: o trecho de rua que passou de 20% (Ladeira).
##
## Por que existe
## -------------
## No morro a rua mais ingreme nao e rampa de asfalto: e escadaria, de pedra,
## com corrimao de ferro no meio e frade na boca para carro nenhum entrar. E a
## imagem mais mineira que a cidade pode ter, e e tambem a regra de jogo: ali o
## carro nao passa (Vias), a pe se passa.
##
## Geometria
## ---------
## Cada chunk desenha a meia-faixa de rua que e dele, como faz com o asfalto: a
## borda x0 e a meia-pista de x = 0 a meia_asfalto, e assim por diante. Para as
## duas metades de uma rua casarem, o desenho dos degraus sai do TRECHO e nao do
## chunk: o comeco e o fim (`extensao_x`, `extensao_z`) contam as ruas que
## cruzam dos dois lados do no, o numero de degraus sai do desnivel no eixo da
## rua, e a altura de cada piso sai do chao (Relevo) no meio dele — de cada lado
## da faixa, entao o piso acompanha a inclinacao de lado da rua e nao flutua
## sobre a sarjeta.
##
## A colisao continua sendo o mapa de alturas do chunk (Relevo.mapa_de_colisao):
## rampa lisa sob os degraus, porque o CharacterBody3D nao sobe degrau. O piso
## fica a meio espelho da rampa, para cima ou para baixo — o pe nao some.
##
## Coordenadas: tudo no espaco LOCAL do chunk. `ao_longo` e a coordenada no
## sentido da rua (z para a borda x, x para a borda z), de 0 a 32.
class_name EscadariaBuilder
extends RefCounted

const TAM := MalhaUrbana.TAM
## Espelho maximo do degrau, em metros.
const ESPELHO := 0.17
## Quanto o meio-fio ao lado da escada desce abaixo do chao. O piso do degrau fica
## a ate meio espelho abaixo da rampa do Relevo (a do meio-fio), e com a saia de
## sempre (6 cm) abria uma cunha para baixo da calcada no pe de cada espelho.
const SAIA := ESPELHO + KitModular.SAIA_MEIO_FIO
## Patamar liso entre a caixa do cruzamento e o primeiro degrau: e onde fica o
## frade.
const PATAMAR := 1.4
const MATERIAL := &"pedra_parque"
const COR_PISO := Color(0.8, 0.78, 0.74)
const COR_ESPELHO := Color(0.58, 0.56, 0.53)
## Bocel: a quina do piso que avanca sobre o espelho, gasta e mais clara. E o
## que faz a escada ler como escada de pedra de longe, e nao como rampa listrada.
const BOCEL := Vector2(0.03, 0.05)
const COR_BOCEL := Color(0.9, 0.88, 0.83)
## Cada degrau e uma pedra: o tom varia nesta faixa, degrau a degrau.
const TOM_DEGRAU := Vector2(0.9, 1.06)
const UV_POR_METRO := 0.5
## Frade de pedra na boca da escadaria. Dois por meia-faixa: o vao entre eles
## passa gente e nao passa carro.
const FRADE := Vector3(0.24, 0.8, 0.24)
const COR_FRADE := Color(0.7, 0.68, 0.64)
## Distancia alvo entre frades vizinhos (e do primeiro ate o eixo).
const VAO_FRADE := 1.35
## Corrimao de ferro no eixo da rua.
const CORRIMAO_ALTURA := 0.92
const CORRIMAO_PASSO := 3.2
const COR_CORRIMAO := Color(0.22, 0.23, 0.22)


## Onde comecam e acabam os degraus no trecho da linha x = i entre os nos j e
## j + 1, medido de j*32 no sentido +Z. Conta a rua mais larga que cruza em
## cada no, dos dois lados, e o patamar do frade.
static func extensao_x(i: int, j: int) -> Vector2:
	var de := maxf(MalhaUrbana.meia_asfalto(MalhaUrbana.via_z_em(j, i - 1)),
		MalhaUrbana.meia_asfalto(MalhaUrbana.via_z_em(j, i)))
	var ate := maxf(MalhaUrbana.meia_asfalto(MalhaUrbana.via_z_em(j + 1, i - 1)),
		MalhaUrbana.meia_asfalto(MalhaUrbana.via_z_em(j + 1, i)))
	return Vector2(de + PATAMAR, TAM - ate - PATAMAR)


## O mesmo para o trecho da linha z = j entre os nos i e i + 1, medido de i*32
## no sentido +X.
static func extensao_z(j: int, i: int) -> Vector2:
	var de := maxf(MalhaUrbana.meia_asfalto(MalhaUrbana.via_x_em(i, j - 1)),
		MalhaUrbana.meia_asfalto(MalhaUrbana.via_x_em(i, j)))
	var ate := maxf(MalhaUrbana.meia_asfalto(MalhaUrbana.via_x_em(i + 1, j - 1)),
		MalhaUrbana.meia_asfalto(MalhaUrbana.via_x_em(i + 1, j)))
	return Vector2(de + PATAMAR, TAM - ate - PATAMAR)


## Os degraus de uma meia-faixa, com frades nas duas bocas e, se `corrimao`, o
## corrimao no eixo da rua.
##
## `eixo_z`: a rua corre em Z (borda x0 ou x1). `faixa`: a meia-faixa no eixo
## transversal, de faixa.x a faixa.y. `eixo_da_rua`: a coordenada transversal do
## meio da rua (0 ou 32). `extensao`: `extensao_x` ou `extensao_z` do trecho.
static func construir(sup: Dictionary, colisao: Array[Dictionary], cx: int, cz: int,
		eixo_z: bool, faixa: Vector2, eixo_da_rua: float, extensao: Vector2,
		corrimao: bool) -> void:
	var de := extensao.x
	var ate := extensao.y
	if ate - de < 2.0:
		return
	var a := faixa.x
	var b := faixa.y
	var ponto := func(s: float, t: float) -> Vector3:
		return Vector3(t, 0.0, s) if eixo_z else Vector3(s, 0.0, t)
	var chao := func(s: float, t: float) -> float:
		return Relevo.local(cx, cz, ponto.call(s, t))

	# Quantos degraus: pelo desnivel no eixo da rua, que as duas metades medem
	# igual. Nunca menos de dois.
	var desnivel := absf(float(chao.call(ate, eixo_da_rua)) - float(chao.call(de, eixo_da_rua)))
	var n := maxi(2, ceili(desnivel / ESPELHO))
	var passo := (ate - de) / float(n)
	var sentido := Vector3(0.0, 0.0, 1.0) if eixo_z else Vector3(1.0, 0.0, 0.0)

	# Altura de cada borda de degrau, dos dois lados da faixa: antes do primeiro
	# e depois do ultimo e o chao do patamar.
	var antes_a: float = chao.call(de, a)
	var antes_b: float = chao.call(de, b)
	for k in n + 1:
		var s0 := de + passo * float(k)
		var piso_a: float
		var piso_b: float
		if k < n:
			var meio := s0 + passo * 0.5
			piso_a = chao.call(meio, a)
			piso_b = chao.call(meio, b)
			var p00: Vector3 = ponto.call(s0, a)
			var p10: Vector3 = ponto.call(s0 + passo, a)
			var p11: Vector3 = ponto.call(s0 + passo, b)
			var p01: Vector3 = ponto.call(s0, b)
			p00.y = piso_a
			p10.y = piso_a
			p11.y = piso_b
			p01.y = piso_b
			quad(sup, MATERIAL, p00, p10, p11, p01, Vector3.UP,
				_tingir(COR_PISO, _tom(cx, cz, eixo_z, k)))
		else:
			piso_a = chao.call(ate, a)
			piso_b = chao.call(ate, b)
		# O espelho entre o piso anterior e este, virado para o lado mais baixo.
		var sobe := (piso_a + piso_b) - (antes_a + antes_b)
		if absf(sobe) > 0.01:
			var e0: Vector3 = ponto.call(s0, a)
			var e1: Vector3 = ponto.call(s0, b)
			var baixo := -sentido if sobe > 0.0 else sentido
			quad(sup, MATERIAL,
				Vector3(e0.x, antes_a, e0.z), Vector3(e1.x, antes_b, e1.z),
				Vector3(e1.x, piso_b, e1.z), Vector3(e0.x, piso_a, e0.z),
				baixo, _tingir(COR_ESPELHO, _tom(cx, cz, eixo_z, k + 997)))
			# O bocel do degrau de cima, avancando para o lado de baixo.
			var alto_a := piso_a if sobe > 0.0 else antes_a
			var alto_b := piso_b if sobe > 0.0 else antes_b
			var f0 := Vector3(e0.x, alto_a, e0.z) + baixo * BOCEL.x
			var f1 := Vector3(e1.x, alto_b, e1.z) + baixo * BOCEL.x
			quad(sup, MATERIAL, Vector3(e0.x, alto_a, e0.z), Vector3(e1.x, alto_b, e1.z),
				f1, f0, Vector3.UP, COR_BOCEL)
			quad(sup, MATERIAL, f0 - Vector3(0.0, BOCEL.y, 0.0),
				f1 - Vector3(0.0, BOCEL.y, 0.0), f1, f0, baixo, _tingir(COR_BOCEL, 0.92))
		antes_a = piso_a
		antes_b = piso_b

	# Frades nas duas bocas, no patamar, a VAO_FRADE um do outro e do eixo: o
	# vao passa gente (0,9 m ou mais) e nao passa carro (1,7 m de largura).
	var borda := b if absf(b - eixo_da_rua) > absf(a - eixo_da_rua) else a
	var meia := absf(borda - eixo_da_rua)
	var quantos := maxi(1, roundi(meia / VAO_FRADE))
	for boca: float in [de - PATAMAR * 0.5, ate + PATAMAR * 0.5]:
		for f in quantos:
			var t := lerpf(eixo_da_rua, borda, (float(f) + 0.5) / float(quantos))
			var pe: Vector3 = ponto.call(boca, t)
			pe.y = chao.call(boca, t)
			KitModular.caixa_cor(sup, MATERIAL, pe + Vector3(0.0, FRADE.y * 0.5, 0.0),
				FRADE, COR_FRADE, 0.0, PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, 4.0)
			colisao.append({"tamanho": FRADE + Vector3(0.0, 0.4, 0.0),
				"pos": pe + Vector3(0.0, FRADE.y * 0.5 - 0.2, 0.0)})

	if corrimao:
		_corrimao(sup, eixo_z, eixo_da_rua, de, ate, cx, cz)


## A cor com o valor multiplicado e o alfa intacto (o alfa do vertice e canal
## do shader, nao transparencia).
static func _tingir(c: Color, t: float) -> Color:
	return Color(c.r * t, c.g * t, c.b * t, c.a)


## Tom da pedra do degrau `k` desta meia-faixa: funcao pura, a mesma em toda
## montagem do chunk.
static func _tom(cx: int, cz: int, eixo_z: bool, k: int) -> float:
	var h := (cx * 73856093) ^ (cz * 19349663) ^ (k * 83492791) ^ (1 if eixo_z else 0)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	var t := float(absi(h) % 10007) / 10007.0
	return lerpf(TOM_DEGRAU.x, TOM_DEGRAU.y, t)


## Corrimao de ferro no eixo da rua: pilarete a cada CORRIMAO_PASSO e a barra de
## cima acompanhando a ladeira. Sem colisao: e fino, e prender o jogador num
## ferro de seis centimetros no meio da escada seria pior que atravessa-lo.
static func _corrimao(sup: Dictionary, eixo_z: bool, t: float, de: float, ate: float,
		cx: int, cz: int) -> void:
	var n := maxi(1, ceili((ate - de) / CORRIMAO_PASSO))
	var passo := (ate - de) / float(n)
	var anterior := Vector3.ZERO
	for k in n + 1:
		var s := de + passo * float(k)
		var pe := Vector3(t, 0.0, s) if eixo_z else Vector3(s, 0.0, t)
		pe.y = Relevo.local(cx, cz, pe)
		var topo := pe + Vector3(0.0, CORRIMAO_ALTURA, 0.0)
		KitModular.caixa_cor(sup, &"metal", pe + Vector3(0.0, CORRIMAO_ALTURA * 0.5, 0.0),
			Vector3(0.05, CORRIMAO_ALTURA, 0.05), COR_CORRIMAO, 0.0,
			PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, 8.0)
		if k > 0:
			# A barra: uma fita vertical de 6 cm de topo a topo, vista dos dois
			# lados.
			var lado := Vector3(1.0, 0.0, 0.0) if eixo_z else Vector3(0.0, 0.0, 1.0)
			for face: float in [1.0, -1.0]:
				quad(sup, &"metal", anterior + Vector3(0.0, -0.03, 0.0),
					topo + Vector3(0.0, -0.03, 0.0), topo + Vector3(0.0, 0.03, 0.0),
					anterior + Vector3(0.0, 0.03, 0.0), lado * face, COR_CORRIMAO)
		anterior = topo


## Um quadrilatero livre (a, b, c, d em volta), com a face visivel para o lado
## de `normal`. UV em metros no plano do quadrilatero.
##
## A ordem dos indices segue a regra do projeto: a face que aparece e a do lado
## OPOSTO ao produto vetorial (ver KitEstrada.quad). O produto e conferido
## contra a normal pedida, entao quem chama nao precisa acertar o sentido.
static func quad(sup: Dictionary, material: StringName, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3, normal: Vector3, cor: Color) -> void:
	if not sup.has(material):
		sup[material] = PSXMesh.dados_vazios()
	var dados: Dictionary = sup[material]
	var v: PackedVector3Array = dados["v"]
	var n: PackedVector3Array = dados["n"]
	var uv: PackedVector2Array = dados["uv"]
	var uv2: PackedVector2Array = dados.get("uv2", PackedVector2Array())
	var cores: PackedColorArray = dados["c"]
	var ix: PackedInt32Array = dados["i"]
	var base := v.size()
	var nrm := normal.normalized()
	var horizontal := absf(nrm.y) > 0.7
	var tangente := Vector3(-nrm.z, 0.0, nrm.x)
	for p: Vector3 in [a, b, c, d]:
		v.append(p)
		n.append(nrm)
		cores.append(cor)
		var q := Vector2(p.x, p.z) if horizontal else Vector2(p.dot(tangente), p.y)
		uv.append(q * UV_POR_METRO)
		uv2.append(q * UV_POR_METRO)
	if (b - a).cross(c - a).dot(nrm) > 0.0:
		ix.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	else:
		ix.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	dados["v"] = v
	dados["n"] = n
	dados["uv"] = uv
	dados["uv2"] = uv2
	dados["c"] = cores
	dados["i"] = ix
