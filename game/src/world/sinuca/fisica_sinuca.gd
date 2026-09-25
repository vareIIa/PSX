## Fisica da sinuca: dezesseis bolas num pano, determinista e em passo fixo.
##
## Por que propria, e nao o motor do Godot
## --------------------------------------
## RigidBody3D numa mesa de sinuca nao segura as tres coisas que fazem o jogo:
## a bola que DESLIZA antes de rolar (a puxada e o "stun" dependem disso), o
## efeito lateral que muda o rebote na tabela, e a mesma tacada dar o mesmo
## resultado (a IA mira contando com isso, e o teste tambem). Os jogos de sinuca
## em Godot que se acham abertos usam o motor e herdam os tres defeitos.
##
## As equacoes sao as do pooltool (Evan Kiefl, JOSS 2024; "The physics of
## pool/billiards", 2020), com os parametros padrao dele:
##
## - cada bola esta PARADA, GIRANDO no lugar, ROLANDO ou DESLIZANDO, e cada
##   estado tem solucao fechada (posicao, velocidade e giro em funcao do tempo)
##   e duracao conhecida; o passo avanca pela formula, trocando de estado no
##   instante exato em que a velocidade relativa do contato zera;
## - bola com bola: choque instantaneo sem atrito, restituicao E_BOLA;
## - bola com tabela: modelo de Han (2005), com a altura do nariz da tabela;
## - tacada: impulso num ponto da bola, com a massa do taco (efeito lateral,
##   puxada, seguida).
##
## Referencial da mesa (MesaSinuca): x no comprimento, y na largura, z para
## cima. O giro `w` e um Vector3 nesse referencial.
##
## A deteccao de choque e por sobreposicao a 600 Hz: a bola mais rapida de uma
## quebra (uns 10 m/s) anda 1,7 cm por passo, menos que o raio. O choque achado
## e rebobinado ate o instante do contato, resolvido, e avancado o que sobrou
## do passo.
class_name FisicaSinuca
extends RefCounted

const G := 9.81
const M := 0.170097
## Taco de 20 oncas. Entra no quanto da velocidade do taco vira bola.
const M_TACO := 0.567
const R := MesaSinuca.R
## Atritos do pooltool: deslize, rolamento e o giro no lugar (proporcional a R).
const MU_S := 0.2
const MU_R := 0.01
const MU_SP := 10.0 * 2.0 / 5.0 / 9.0 * R
const E_BOLA := 0.95
const E_TABELA := 0.85
const F_TABELA := 0.2
const PASSO := 1.0 / 600.0
const EPS_V := 1e-4
const EPS_W := 1e-3
const BOLAS := 16
## Desvio (squirt) da bola branca por efeito lateral, em radianos por R de
## deslocamento: bater a direita manda a bola um pouco para a esquerda.
const SQUIRT := 0.035
## Deslocamento maximo do ponto de contato, em fracoes de R. Alem disso o taco
## escorrega (miscue).
const EFEITO_MAX := 0.6

enum Estado { PARADA, GIRANDO, ROLANDO, DESLIZANDO, CACAPA }

var r := PackedVector2Array()
var v := PackedVector2Array()
var w := PackedVector3Array()
var estado := PackedInt32Array()
## Orientacao de cada bola no referencial do no da mesa (Godot). So desenho, mas
## sai daqui para o numero girar junto com o giro de verdade.
var orientacao: Array[Quaternion] = []
## O que aconteceu desde a ultima tacada: taco, bola, tabela, cacapa. As regras
## e o som leem daqui.
var eventos: Array[Dictionary] = []
var tempo := 0.0

var _segmentos: Array[PackedVector2Array] = []
var _cacapas := PackedVector2Array()
var _theta := 0.0
var _sobra := 0.0


func _init() -> void:
	r.resize(BOLAS)
	v.resize(BOLAS)
	w.resize(BOLAS)
	estado.resize(BOLAS)
	orientacao.resize(BOLAS)
	for i in BOLAS:
		orientacao[i] = Quaternion.IDENTITY
	_segmentos = MesaSinuca.segmentos()
	_cacapas = MesaSinuca.cacapas()
	# Angulo em que o nariz da tabela pega a bola: asin(h/R - 1), Han (2005).
	_theta = asin(clampf(MesaSinuca.NARIZ / R - 1.0, -1.0, 1.0))


## Arruma o triangulo e a branca atras da linha de cabeceira.
func arrumar(semente: int) -> void:
	var rack := MesaSinuca.triangulo(semente)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente * 31 + 7
	for i in BOLAS:
		v[i] = Vector2.ZERO
		w[i] = Vector3.ZERO
		estado[i] = Estado.PARADA
		r[i] = rack.get(i, Vector2.ZERO)
		# O numero de cada bola para um lado: triangulo com todos os numeros
		# virados para cima le como foto de catalogo.
		orientacao[i] = Quaternion(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1),
			rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, TAU))
	r[0] = Vector2(MesaSinuca.linha_de_cabeceira(), 0.0)
	orientacao[0] = Quaternion.IDENTITY
	eventos.clear()
	tempo = 0.0


func duplicar() -> FisicaSinuca:
	var f := FisicaSinuca.new()
	f.r = r.duplicate()
	f.v = v.duplicate()
	f.w = w.duplicate()
	f.estado = estado.duplicate()
	f.orientacao = orientacao.duplicate()
	f.tempo = tempo
	return f


func em_movimento() -> bool:
	for i in BOLAS:
		var e := estado[i]
		if e != Estado.PARADA and e != Estado.CACAPA:
			return true
	return false


func na_mesa(i: int) -> bool:
	return estado[i] != Estado.CACAPA


## Uma bola cabe em `p`? Dentro das tabelas e sem encostar em outra.
func cabe(p: Vector2, ignorar: int = 0) -> bool:
	if absf(p.x) > MesaSinuca.COMP * 0.5 - R or absf(p.y) > MesaSinuca.LARG * 0.5 - R:
		return false
	for j in BOLAS:
		if j == ignorar or estado[j] == Estado.CACAPA:
			continue
		if r[j].distance_to(p) < 2.0 * R + 0.001:
			return false
	return true


## Poe uma bola de volta na mesa (a branca na mao, a 8 recolocada).
func por(i: int, p: Vector2) -> void:
	r[i] = p
	v[i] = Vector2.ZERO
	w[i] = Vector3.ZERO
	estado[i] = Estado.PARADA


## A tacada na branca.
##
## `v0` e a velocidade do taco (m/s), `phi` a direcao no pano, `theta` a
## elevacao do taco, `a` e `b` o ponto de contato em fracoes de R: `a` positivo
## a direita de quem taca, `b` positivo acima do centro. O impulso passa pelo
## ponto de contato na direcao do taco; a bola sai na direcao do taco e gira em
## torno de Q x D (Q o ponto, D a direcao), com a massa do taco no denominador
## como no pooltool.
func tacar(v0: float, phi: float, theta: float, a: float, b: float) -> void:
	var ab := Vector2(a, b)
	if ab.length() > EFEITO_MAX:
		ab = ab.normalized() * EFEITO_MAX
	var aa := ab.x * R
	var bb := ab.y * R
	var rumo := phi - SQUIRT * ab.x
	var d := Vector3(cos(rumo) * cos(theta), sin(rumo) * cos(theta), -sin(theta))
	var lado := d.cross(Vector3(0.0, 0.0, 1.0)).normalized()
	var cima := lado.cross(d)
	var c := sqrt(maxf(0.0, R * R - aa * aa - bb * bb))
	var q := lado * aa + cima * bb - d * c
	var vel := 2.0 * v0 / (1.0 + M / M_TACO + 5.0 / (2.0 * R * R) * (aa * aa + bb * bb))
	v[0] = Vector2(d.x, d.y) * vel
	w[0] = q.cross(d) * vel * 5.0 / (2.0 * R * R)
	_classificar(0)
	eventos.clear()
	eventos.append({"tipo": &"taco", "a": 0, "forca": vel, "t": tempo, "pos": r[0]})


## Avanca `dt` segundos em passos fixos. O que sobra de um quadro entra no
## proximo, para o resultado nao depender do quadro.
func avancar(dt: float) -> void:
	_sobra += dt
	var guarda := 0
	while _sobra >= PASSO and guarda < 64:
		_sobra -= PASSO
		guarda += 1
		_passo(PASSO)
		if not em_movimento():
			_sobra = 0.0
			return


## Simula ate tudo parar (ou `limite` segundos). Para a bancada e para a IA.
func ate_parar(limite: float = 30.0) -> void:
	var t := 0.0
	while em_movimento() and t < limite:
		_passo(PASSO)
		t += PASSO


# --- o passo ------------------------------------------------------------------

func _passo(h: float) -> void:
	for i in BOLAS:
		var e := estado[i]
		if e == Estado.PARADA or e == Estado.CACAPA:
			continue
		_evoluir(i, h)
		_girar(i, h)
	for _k in 3:
		if not _choques_de_bolas(h):
			break
	_choques_de_tabela(h)
	_cacapas_pegam()
	tempo += h


## Avanca uma bola `h` segundos pela solucao fechada do estado dela, trocando de
## estado no instante em que ele acaba.
func _evoluir(i: int, h: float) -> void:
	var resta := h
	var guarda := 0
	while resta > 1e-12 and guarda < 6:
		guarda += 1
		var e := estado[i]
		if e == Estado.PARADA or e == Estado.CACAPA:
			return
		var fim := _duracao(i)
		var dt := minf(resta, fim)
		_mover(i, dt)
		resta -= dt
		if dt >= fim:
			_transicao(i)


func _duracao(i: int) -> float:
	match estado[i]:
		Estado.DESLIZANDO:
			return 2.0 * _deslize(i).length() / (7.0 * MU_S * G)
		Estado.ROLANDO:
			return v[i].length() / (MU_R * G)
		Estado.GIRANDO:
			return absf(w[i].z) * 2.0 * R / (5.0 * MU_SP * G)
	return INF


## Velocidade do ponto de contato com o pano: u = v + R z x w.
func _deslize(i: int) -> Vector2:
	var vv := v[i]
	var ww := w[i]
	return Vector2(vv.x - R * ww.y, vv.y + R * ww.x)


func _mover(i: int, dt: float) -> void:
	var ww := w[i]
	var wz := signf(ww.z) * maxf(0.0, absf(ww.z) - 5.0 * MU_SP * G / (2.0 * R) * dt)
	match estado[i]:
		Estado.DESLIZANDO:
			var vv := v[i]
			var u := _deslize(i).normalized()
			r[i] = r[i] + vv * dt - 0.5 * MU_S * G * dt * dt * u
			v[i] = vv - MU_S * G * dt * u
			# O atrito no contato empurra o giro para o de rolar: dw/dt = k (z x u).
			var k := 5.0 * MU_S * G / (2.0 * R) * dt
			w[i] = Vector3(ww.x - k * u.y, ww.y + k * u.x, wz)
		Estado.ROLANDO:
			var vv := v[i]
			var vh := vv.normalized()
			r[i] = r[i] + vv * dt - 0.5 * MU_R * G * dt * dt * vh
			var nv := vv - MU_R * G * dt * vh
			v[i] = nv
			w[i] = Vector3(-nv.y / R, nv.x / R, wz)
		Estado.GIRANDO:
			w[i] = Vector3(0.0, 0.0, wz)


func _transicao(i: int) -> void:
	match estado[i]:
		Estado.DESLIZANDO:
			var vv := v[i]
			w[i] = Vector3(-vv.y / R, vv.x / R, w[i].z)
			_classificar(i)
		Estado.ROLANDO:
			v[i] = Vector2.ZERO
			w[i] = Vector3(0.0, 0.0, w[i].z)
			estado[i] = Estado.GIRANDO if absf(w[i].z) > EPS_W else Estado.PARADA
		Estado.GIRANDO:
			w[i] = Vector3.ZERO
			estado[i] = Estado.PARADA


func _classificar(i: int) -> void:
	if estado[i] == Estado.CACAPA:
		return
	var vv := v[i]
	var ww := w[i]
	if vv.length() < EPS_V and absf(ww.x) < EPS_W and absf(ww.y) < EPS_W:
		v[i] = Vector2.ZERO
		w[i] = Vector3(0.0, 0.0, ww.z)
		estado[i] = Estado.GIRANDO if absf(ww.z) > EPS_W else Estado.PARADA
	elif _deslize(i).length() > 1e-3:
		estado[i] = Estado.DESLIZANDO
	else:
		w[i] = Vector3(-vv.y / R, vv.x / R, ww.z)
		estado[i] = Estado.ROLANDO


## Gira a orientacao desenhada pelo giro de verdade, no referencial do no.
func _girar(i: int, h: float) -> void:
	var g := MesaSinuca.para_godot(w[i])
	var ang := g.length() * h
	if ang < 1e-7:
		return
	orientacao[i] = (Quaternion(g / g.length(), ang) * orientacao[i]).normalized()


# --- choques ------------------------------------------------------------------

## Bola com bola. Devolve se houve algum choque (o passo repete a busca, porque
## um choque no meio do triangulo empurra a bola para cima da vizinha).
func _choques_de_bolas(h: float) -> bool:
	var houve := false
	for i in BOLAS:
		if estado[i] == Estado.CACAPA:
			continue
		for j in range(i + 1, BOLAS):
			if estado[j] == Estado.CACAPA:
				continue
			var ei := estado[i]
			var ej := estado[j]
			if (ei == Estado.PARADA or ei == Estado.GIRANDO) \
					and (ej == Estado.PARADA or ej == Estado.GIRANDO):
				continue
			var d := r[j] - r[i]
			var dist2 := d.length_squared()
			if dist2 >= 4.0 * R * R:
				continue
			var dv := v[j] - v[i]
			if dv.dot(d) >= 0.0:
				continue
			_choque(i, j, h)
			houve = true
	return houve


func _choque(i: int, j: int, h: float) -> void:
	# Rebobina os dois ate o instante do contato (movimento reto no passo).
	var d := r[j] - r[i]
	var dv := v[j] - v[i]
	var a := dv.length_squared()
	var tau := 0.0
	if a > 1e-12:
		var b := 2.0 * d.dot(dv)
		var c := d.length_squared() - 4.0 * R * R
		var disc := b * b - 4.0 * a * c
		if disc > 0.0:
			tau = clampf((-b - sqrt(disc)) / (2.0 * a), -h, 0.0)
	r[i] += v[i] * tau
	r[j] += v[j] * tau
	var n := (r[j] - r[i]).normalized()
	var vin := v[i].dot(n)
	var vjn := v[j].dot(n)
	var troca := (1.0 + E_BOLA) * 0.5 * (vin - vjn)
	v[i] -= n * troca
	v[j] += n * troca
	r[i] -= v[i] * tau
	r[j] -= v[j] * tau
	# Sobreposicao que sobrou (triangulo apertado): separa pelo meio.
	var sobra := 2.0 * R - r[i].distance_to(r[j])
	if sobra > 0.0:
		r[i] -= n * (sobra * 0.5 + 1e-6)
		r[j] += n * (sobra * 0.5 + 1e-6)
	_classificar(i)
	_classificar(j)
	eventos.append({"tipo": &"bola", "a": i, "b": j, "forca": vin - vjn, "t": tempo,
		"pos": (r[i] + r[j]) * 0.5})


func _choques_de_tabela(h: float) -> void:
	for i in BOLAS:
		var e := estado[i]
		if e == Estado.PARADA or e == Estado.GIRANDO or e == Estado.CACAPA:
			continue
		for seg: PackedVector2Array in _segmentos:
			var q := Geometry2D.get_closest_point_to_segment(r[i], seg[0], seg[1])
			var para := q - r[i]
			var dist := para.length()
			if dist >= R or dist < 1e-9:
				continue
			var n := para / dist
			var vn := v[i].dot(n)
			if vn <= 0.0:
				continue
			var tau := clampf(-(R - dist) / vn, -h, 0.0)
			r[i] += v[i] * tau
			_tabela(i, n)
			r[i] -= v[i] * tau
			# Garante que saiu da borracha.
			var q2 := Geometry2D.get_closest_point_to_segment(r[i], seg[0], seg[1])
			if r[i].distance_to(q2) < R:
				r[i] = q2 - (q2 - r[i]).normalized() * (R + 1e-6)
			_classificar(i)
			eventos.append({"tipo": &"tabela", "a": i, "forca": vn, "t": tempo, "pos": q})


## Choque com a tabela pelo modelo de Han (2005), como o pooltool resolve.
##
## `n` aponta da bola para a borracha. Tudo e escrito no referencial da tabela
## (x = n, y = z x n, z para cima) e volta no fim. A velocidade vertical que o
## modelo produz (a bola "pula" um pouco) e descartada: o pano segura.
func _tabela(i: int, n: Vector2) -> void:
	var ex := n
	var ey := Vector2(-n.y, n.x)
	var vx := v[i].dot(ex)
	var vy := v[i].dot(ey)
	var wxy := Vector2(w[i].x, w[i].y)
	var wx := wxy.dot(ex)
	var wy := wxy.dot(ey)
	var wz := w[i].z
	var st := sin(_theta)
	var ct := cos(_theta)
	var sx := vx * st + R * wy
	var sy := -vy - R * wz * ct + R * wx * st
	var c := vx * ct
	var e := E_TABELA
	# Impulsos divididos pela massa (P/m).
	var px: float
	var py: float
	var pz: float
	if sqrt(sx * sx + sy * sy) * 2.0 / 7.0 <= (1.0 + e) * c:
		px = -sx * 2.0 / 7.0 * st - (1.0 + e) * c * ct
		py = sy * 2.0 / 7.0
		pz = sx * 2.0 / 7.0 * ct - (1.0 + e) * c * st
	else:
		var phi := atan2(sy, sx)
		var mu := F_TABELA
		px = -mu * (1.0 + e) * c * cos(phi) * st - (1.0 + e) * c * ct
		py = mu * (1.0 + e) * c * sin(phi)
		pz = mu * (1.0 + e) * c * cos(phi) * ct - (1.0 + e) * c * st
	vx += px
	vy += py
	var k := 5.0 / (2.0 * R)
	wx += -k * py * st
	wy += k * (px * st - pz * ct)
	wz += k * py * ct
	v[i] = ex * vx + ey * vy
	var nw := ex * wx + ey * wy
	w[i] = Vector3(nw.x, nw.y, wz)


## A bola cujo centro entrou no raio de captura de uma cacapa caiu. Por
## garantia, a que passou da linha das tabelas mais de um raio (so e possivel
## dentro da garganta de uma cacapa) cai na mais perto.
func _cacapas_pegam() -> void:
	var hx := MesaSinuca.COMP * 0.5 + R
	var hy := MesaSinuca.LARG * 0.5 + R
	for i in BOLAS:
		var e := estado[i]
		if e == Estado.PARADA or e == Estado.CACAPA:
			continue
		var perto := -1
		var melhor := INF
		for k in _cacapas.size():
			var dd := r[i].distance_to(_cacapas[k])
			if dd < melhor:
				melhor = dd
				perto = k
		var fora := absf(r[i].x) > hx or absf(r[i].y) > hy
		if melhor < MesaSinuca.CAPTURA or fora:
			var veloc := v[i].length()
			estado[i] = Estado.CACAPA
			v[i] = Vector2.ZERO
			w[i] = Vector3.ZERO
			eventos.append({"tipo": &"cacapa", "a": i, "cacapa": perto, "t": tempo,
				"pos": _cacapas[perto], "forca": veloc})


# --- mira ---------------------------------------------------------------------

## O que uma bola de raio R saindo de `o` na direcao `d` encontra primeiro: outra
## bola (com a posicao da "bola fantasma" no contato) ou uma tabela (com o
## ponto e a normal). Para a linha-guia e para a IA.
func raio(o: Vector2, d: Vector2, ignorar: int = 0) -> Dictionary:
	d = d.normalized()
	var melhor := INF
	var res := {"tipo": &"nada", "t": INF}
	for j in BOLAS:
		if j == ignorar or estado[j] == Estado.CACAPA:
			continue
		var f := o - r[j]
		var b := f.dot(d)
		var c := f.length_squared() - 4.0 * R * R
		var disc := b * b - c
		if disc < 0.0:
			continue
		var t := -b - sqrt(disc)
		if t > 1e-6 and t < melhor:
			melhor = t
			res = {"tipo": &"bola", "bola": j, "t": t, "fantasma": o + d * t}
	for seg: PackedVector2Array in _segmentos:
		var hit := _raio_capsula(o, d, seg[0], seg[1])
		if hit.is_empty():
			continue
		var t: float = hit["t"]
		if t > 1e-6 and t < melhor:
			melhor = t
			res = {"tipo": &"tabela", "t": t, "fantasma": o + d * t, "normal": hit["normal"]}
	return res


## Raio contra o segmento "engordado" de R (capsula): as duas retas paralelas e
## os dois circulos das pontas. `normal` aponta da tabela para a bola.
func _raio_capsula(o: Vector2, d: Vector2, a: Vector2, b: Vector2) -> Dictionary:
	var melhor := INF
	var normal := Vector2.ZERO
	var eixo := b - a
	var comp := eixo.length()
	if comp > 1e-9:
		var e := eixo / comp
		var n := Vector2(-e.y, e.x)
		var dn := d.dot(n)
		if absf(dn) > 1e-9:
			for lado: float in [1.0, -1.0]:
				var t := (lado * R - (o - a).dot(n)) / dn
				if t <= 1e-6 or t >= melhor:
					continue
				var p := o + d * t
				var s := (p - a).dot(e)
				if s >= 0.0 and s <= comp:
					melhor = t
					normal = n * lado
	for p: Vector2 in [a, b]:
		var f := o - p
		var bb := f.dot(d)
		var c := f.length_squared() - R * R
		var disc := bb * bb - c
		if disc < 0.0:
			continue
		var t := -bb - sqrt(disc)
		if t > 1e-6 and t < melhor:
			melhor = t
			normal = (o + d * t - p) / R
	if melhor == INF:
		return {}
	return {"t": melhor, "normal": normal}
