## O adversario da sinuca: escolhe a tacada como um jogador de bar escolhe.
##
## Para cada bola que pode tocar e cada cacapa, a "bola fantasma" (onde a branca
## tem de estar no contato para mandar a bola na cacapa), o corte, o caminho
## livre da branca ate la e da bola ate a cacapa. Fica a de menor nota: perto,
## reta, cacapa aberta. A forca sai da distancia que as duas bolas precisam
## rolar. O erro vem da habilidade: mira e forca com ruido, como mao de gente.
##
## Sem simular a tacada inteira: a 600 Hz ela custa centenas de milhares de
## passos, e o bar nao pode travar um quadro enquanto o Seu Ze pensa. A
## geometria resolve o que um jogador de bar resolve, e a fisica faz o resto.
class_name CerebroSinuca
extends RefCounted

const R := MesaSinuca.R
## Corte maximo que ele tenta. Acima disso a bola quase nao anda.
const CORTE_MAX := deg_to_rad(76.0)
## Velocidade do taco na quebra.
const QUEBRA := 5.6
const V_MIN := 0.35
const V_MAX := 5.2


## A tacada escolhida: {phi, v0, theta, a, b, alvo, cacapa, nota}.
static func escolher(f: FisicaSinuca, alvos: Array[int], habilidade: float,
		rng: RandomNumberGenerator, quebra: bool = false) -> Dictionary:
	var branca := f.r[0]
	var t: Dictionary
	if quebra:
		# Na ponta do triangulo, cheia, um fio de puxada.
		var ponta := f.r[1] if f.na_mesa(1) else MesaSinuca.marca_do_pe()
		t = {"phi": (ponta - branca).angle(), "v0": QUEBRA, "theta": deg_to_rad(4.0),
			"a": 0.0, "b": -0.05, "alvo": 1, "cacapa": -1, "nota": 0.0}
	else:
		t = _melhor(f, alvos)
		if t.is_empty():
			t = _defesa(f, alvos)
	# A mao: quanto pior o jogador, mais o taco tremeu.
	var sigma := lerpf(0.03, 0.0025, clampf(habilidade, 0.0, 1.0))
	t["phi"] = float(t["phi"]) + rng.randfn(0.0, sigma)
	t["v0"] = clampf(float(t["v0"]) * (1.0 + rng.randfn(0.0, lerpf(0.14, 0.04, habilidade))),
		V_MIN, QUEBRA)
	return t


static func _melhor(f: FisicaSinuca, alvos: Array[int]) -> Dictionary:
	var branca := f.r[0]
	var cacapas := MesaSinuca.cacapas()
	var melhor := {}
	var melhor_nota := INF
	for n in alvos:
		if not f.na_mesa(n):
			continue
		var bola := f.r[n]
		for k in cacapas.size():
			var mira := _boca(cacapas[k])
			var para_cacapa := mira - bola
			var d_bc := para_cacapa.length()
			if d_bc < 1e-4:
				continue
			var dir_bc := para_cacapa / d_bc
			# Cacapa do meio so aceita bola chegando de frente.
			if absf(cacapas[k].x) < 0.01 and absf(dir_bc.y) < 0.62:
				continue
			var fantasma := bola - dir_bc * 2.0 * R
			var para_fantasma := fantasma - branca
			var d_bf := para_fantasma.length()
			if d_bf < 1e-4:
				continue
			var dir_bf := para_fantasma / d_bf
			var corte := acos(clampf(dir_bf.dot(dir_bc), -1.0, 1.0))
			if corte > CORTE_MAX:
				continue
			if not _livre(f, branca, fantasma, [0, n]) or not _livre(f, bola, mira, [0, n]):
				continue
			# A branca tem de encontrar ESTA bola primeiro.
			var hit := f.raio(branca, dir_bf)
			if StringName(hit["tipo"]) != &"bola" or int(hit["bola"]) != n:
				continue
			var nota := d_bf * 0.55 + d_bc * 0.9 + corte * corte * 2.4
			if nota < melhor_nota:
				melhor_nota = nota
				melhor = {"phi": dir_bf.angle(), "v0": _forca(d_bf, d_bc, corte),
					"theta": deg_to_rad(3.0), "a": 0.0,
					# Tacada reta: puxada, para a branca nao seguir a bola na cacapa.
					"b": -0.25 if corte < deg_to_rad(12.0) else 0.12,
					"alvo": n, "cacapa": k, "nota": nota}
	return melhor


## Sem tacada limpa: bate cheio na bola legal mais perto, com forca para ir a
## tabela, que e o minimo para nao ser falta.
static func _defesa(f: FisicaSinuca, alvos: Array[int]) -> Dictionary:
	var branca := f.r[0]
	var melhor := -1
	var dist := INF
	for n in alvos:
		if not f.na_mesa(n):
			continue
		var hit := f.raio(branca, (f.r[n] - branca).normalized())
		var livre := StringName(hit["tipo"]) == &"bola" and int(hit["bola"]) == n
		var d := branca.distance_to(f.r[n]) + (0.0 if livre else 10.0)
		if d < dist:
			dist = d
			melhor = n
	if melhor < 0:
		return {"phi": 0.0, "v0": 2.0, "theta": deg_to_rad(3.0), "a": 0.0, "b": 0.0,
			"alvo": -1, "cacapa": -1, "nota": INF}
	return {"phi": (f.r[melhor] - branca).angle(), "v0": 2.6, "theta": deg_to_rad(3.0),
		"a": 0.0, "b": 0.0, "alvo": melhor, "cacapa": -1, "nota": INF}


## O ponto da boca para onde se mira: um pouco para dentro da mesa a partir do
## centro da cacapa, que e onde a bola precisa passar.
static func _boca(c: Vector2) -> Vector2:
	var dentro := -c.normalized() if absf(c.x) > 0.01 else Vector2(0.0, -signf(c.y))
	return c + dentro * 0.03


## Nenhuma bola (fora as ignoradas) encosta no caminho de uma bola de `de` a `ate`.
static func _livre(f: FisicaSinuca, de: Vector2, ate: Vector2, ignorar: Array) -> bool:
	for j in FisicaSinuca.BOLAS:
		if ignorar.has(j) or not f.na_mesa(j):
			continue
		var q := Geometry2D.get_closest_point_to_segment(f.r[j], de, ate)
		if q.distance_to(f.r[j]) < 2.0 * R * 0.98:
			return false
	return true


## Velocidade do taco para a bola chegar na cacapa com folga.
##
## A bola alvo precisa sair com o bastante para rolar `d_bc` (v^2 = 2 mu_r g d)
## mais uma margem; a branca entrega cos(corte) disso no contato, dividido pela
## restituicao; e perde velocidade ate la (deslize e rolamento, um atrito medio).
## O taco passa ~1,54 da propria velocidade para a bola (massa do taco).
static func _forca(d_bf: float, d_bc: float, corte: float) -> float:
	var g := FisicaSinuca.G
	var v_alvo := sqrt(2.0 * FisicaSinuca.MU_R * g * d_bc) * 1.7 + 0.45
	var v_chega := v_alvo / maxf(cos(corte), 0.3) / ((1.0 + FisicaSinuca.E_BOLA) * 0.5)
	var v_branca := sqrt(v_chega * v_chega + 2.0 * 0.06 * g * d_bf)
	var v0 := v_branca * (1.0 + FisicaSinuca.M / FisicaSinuca.M_TACO) * 0.5
	return clampf(v0, V_MIN, V_MAX)


## Onde por a branca com ela na mao: atras da bola fantasma da melhor tacada, a
## 30 cm, onde couber. `so_cabeceira`: atras da linha (a da quebra).
static func bola_na_mao(f: FisicaSinuca, alvos: Array[int], so_cabeceira: bool) -> Vector2:
	var x_max := MesaSinuca.linha_de_cabeceira() if so_cabeceira else MesaSinuca.COMP * 0.5
	if so_cabeceira:
		for dy: float in [0.0, 0.1, -0.1, 0.2, -0.2]:
			var p := Vector2(MesaSinuca.linha_de_cabeceira() - 0.02, dy)
			if f.cabe(p):
				return p
	var cacapas := MesaSinuca.cacapas()
	var melhor := Vector2(MesaSinuca.linha_de_cabeceira(), 0.0)
	var melhor_nota := INF
	for n in alvos:
		if not f.na_mesa(n):
			continue
		for k in cacapas.size():
			var mira := _boca(cacapas[k])
			var dir_bc := (mira - f.r[n]).normalized()
			if absf(cacapas[k].x) < 0.01 and absf(dir_bc.y) < 0.62:
				continue
			var fantasma := f.r[n] - dir_bc * 2.0 * R
			for recuo: float in [0.3, 0.45, 0.2]:
				var p := fantasma - dir_bc * recuo
				if p.x > x_max or not f.cabe(p):
					continue
				if not _livre(f, f.r[n], mira, [0, n]):
					continue
				var nota := f.r[n].distance_to(mira) + recuo
				if nota < melhor_nota:
					melhor_nota = nota
					melhor = p
	if not f.cabe(melhor):
		# Varredura em grade, e nao sorteio: a mesma mesa da o mesmo lugar.
		for ix in 19:
			for iy in 9:
				var p := Vector2(-0.9 + 0.1 * float(ix), -0.4 + 0.1 * float(iy))
				if p.x <= x_max and f.cabe(p):
					return p
	return melhor
