## A mao que SEGURA: acha a pegada (onde a palma fica e quanto cada dedo dobra)
## a partir de onde cada polpa tem de encostar num objeto em forma de caixa
## (o celular).
##
## Por que existe
## --------------
## A pegada do celular era escrita a mao: um referencial de palma e a dobra de
## cada no, em graus, ajustados olhando a foto de frente. De frente passava; de
## lado e por tras os dedos nao encostavam em nada — o indicador saia espetado
## para fora da silhueta, o medio e o anelar passavam a um centimetro da borda,
## e as pontas que apareciam na moldura estavam NA FRENTE do vidro, soltas. O
## aparelho parecia boiar entre os dedos, e mexia com eles sem estar preso a
## eles.
##
## Como funciona
## -------------
## Um ajuste por minimos quadrados (Levenberg-Marquardt, jacobiano numerico)
## sobre 27 numeros: o meio da palma (3), o giro da mao (3) e a pose — quatro
## dedos com [mcp, pip, dip, abre] e o polegar com [radial, palmar, giro, mcp,
## ip]. O que ele persegue sao `metas`:
##
##     polpa    a polpa do dedo `dedo` (4 e o polegar) no ponto `p`, com a unha
##              olhando para `n` (a normal da face em que ela encosta);
##     encosta  um ponto da falange `falange` do dedo, a `t` do comprimento,
##              tangenciando a caixa (distancia = raio do dedo ali);
##     rumo     a mao apontando para `d` (do punho para os nos): e o antebraco
##              que tem de sair para o lado do ombro.
##
## E o que ele nunca deixa: nenhum pedaco da mao dentro da caixa. A mao vira um
## punhado de esferas (as juntas e o meio de cada falange, cinco por fileira da
## palma) e cada uma que entra na caixa custa caro. Cada angulo fica perto de
## uma pose de descanso, com peso pequeno, para a mao nao achar uma solucao de
## contorcionista.
class_name AjusteDaMao
extends RefCounted

## Onde cada coisa esta no vetor de parametros.
const I_O := 0
const I_GIRO := 3
const I_DEDOS := 6
const I_POLEGAR := 22
const N := 27

## Limites de cada angulo (graus). Dedo: [mcp, pip, dip, abre]; polegar:
## [radial, palmar, giro, mcp, ip].
const DEDO_MIN := [-25.0, 0.0, -5.0, -18.0]
const DEDO_MAX := [95.0, 115.0, 85.0, 18.0]
const POLEGAR_MIN := [-15.0, -25.0, -160.0, -15.0, -25.0]
const POLEGAR_MAX := [90.0, 100.0, 100.0, 60.0, 85.0]

## Pesos (residuo em milimetros): quanto custa cada grau longe do descanso, a
## unha fora da normal (por unidade), e cada milimetro dentro da caixa.
const PESO_DESCANSO := 0.02
const PESO_ACOPLA := 0.15
const PESO_NORMAL := 10.0
const PESO_DENTRO := 4.0
## O dip acompanha o pip: numa mao de gente os dois nos de cima dobram juntos.
const DIP_DO_PIP := 0.7
## Folga antes de contar como dentro (m), e quanto cada esfera cresce para a
## conta de dentro: a malha tem o calombo dos nos e a quina da palma, que as
## esferas nao tem — com as esferas justas a base do polegar entrava 4 mm na
## lateral do aparelho.
const FOLGA := 0.0003
const MARGEM := 1.18

## Descanso: a mao meio fechada, como fica solta.
const DESCANSO_DEDO := [30.0, 40.0, 28.0, 0.0]
const DESCANSO_POLEGAR := [40.0, 40.0, 0.0, 20.0, 18.0]

var meia: Vector3
var raio_canto: float
var direita: bool
var metas: Array = []
## Quais parametros o ajuste mexe (indices do vetor).
var livres: PackedInt32Array
## So o polegar esta livre: o resto da mao nao muda, e so as esferas dele
## entram na conta.
var _so_polegar: bool = false
var _base := Basis()
var _descanso := PackedFloat64Array()


func _init(meia_caixa: Vector3, raio_do_canto: float, e_direita: bool) -> void:
	meia = meia_caixa
	raio_canto = raio_do_canto
	direita = e_direita
	livres = PackedInt32Array(range(N))
	_descanso.resize(N)
	for i in 4:
		for j in 4:
			_descanso[I_DEDOS + i * 4 + j] = DESCANSO_DEDO[j]
	for j in 5:
		_descanso[I_POLEGAR + j] = DESCANSO_POLEGAR[j]


## Deixa livre so o polegar (para a ponta dele ir de tecla em tecla).
func so_polegar() -> void:
	livres = PackedInt32Array(range(I_POLEGAR, N))
	_so_polegar = true


## Distancia com sinal ate a caixa de cantos arredondados (no plano x-y, como o
## aparelho): negativa dentro.
static func distancia(p: Vector3, meia_: Vector3, rc: float) -> float:
	var qx := absf(p.x) - (meia_.x - rc)
	var qy := absf(p.y) - (meia_.y - rc)
	var d2 := Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() + minf(maxf(qx, qy), 0.0) - rc
	var wz := absf(p.z) - meia_.z
	return Vector2(maxf(d2, 0.0), maxf(wz, 0.0)).length() + minf(maxf(d2, wz), 0.0)


## Resolve a partir da pegada `inicio` ({o, d, dorso, pose}) e devolve a
## pegada ajustada. `iteracoes` e o teto; ele para antes quando nao melhora.
func resolver(inicio: Dictionary, iteracoes: int = 40) -> Dictionary:
	var d0: Vector3 = (inicio["d"] as Vector3).normalized()
	var s0: Vector3 = inicio["dorso"]
	s0 = (s0 - d0 * s0.dot(d0)).normalized()
	_base = Basis(s0.cross(d0).normalized(), s0, d0)
	var x := _vetor(inicio)
	var r := _residuos(x)
	var custo := _soma2(r)
	var lam := 0.01
	var m := r.size()
	var n := livres.size()
	for _it in iteracoes:
		var colunas: Array[PackedFloat64Array] = []
		for a in n:
			var j := livres[a]
			var h := 0.05 if j < I_GIRO else 0.1
			var x2 := x.duplicate()
			x2[j] += h
			var r2 := _residuos(x2)
			var col := PackedFloat64Array()
			col.resize(m)
			for k in m:
				col[k] = (r2[k] - r[k]) / h
			colunas.append(col)
		# A = J'J, g = J'r
		var a_ := PackedFloat64Array()
		a_.resize(n * n)
		var g := PackedFloat64Array()
		g.resize(n)
		for p in n:
			var cp := colunas[p]
			var s := 0.0
			for k in m:
				s += cp[k] * r[k]
			g[p] = s
			for q in range(p, n):
				var cq := colunas[q]
				var t := 0.0
				for k in m:
					t += cp[k] * cq[k]
				a_[p * n + q] = t
				a_[q * n + p] = t
		var aceitou := false
		for _tenta in 8:
			var sis := a_.duplicate()
			for p in n:
				sis[p * n + p] += lam * (sis[p * n + p] + 1e-3)
			var passo := _resolver_linear(sis, g, n)
			var xn := x.duplicate()
			for p in n:
				xn[livres[p]] -= passo[p]
			_limitar(xn)
			var rn := _residuos(xn)
			var cn := _soma2(rn)
			if cn < custo:
				var ganho := custo - cn
				x = xn
				r = rn
				custo = cn
				lam = maxf(lam * 0.3, 1e-7)
				aceitou = true
				if ganho < 1e-5 * custo + 1e-9:
					return _pegada(x)
				break
			lam *= 6.0
		if not aceitou:
			break
	return _pegada(x)


## O custo da pegada (soma dos quadrados dos residuos, em mm^2) e quantas
## esferas da mao ficaram dentro da caixa.
func medir(pegada: Dictionary) -> Dictionary:
	var d0: Vector3 = (pegada["d"] as Vector3).normalized()
	var s0: Vector3 = pegada["dorso"]
	s0 = (s0 - d0 * s0.dot(d0)).normalized()
	_base = Basis(s0.cross(d0).normalized(), s0, d0)
	var x := _vetor(pegada)
	var e := _esqueleto(x)
	var dentro := 0
	var pior := 0.0
	for esf: Array in _esferas(e, false):
		var sd := distancia(esf[0], meia, raio_canto) - float(esf[1])
		if sd < -FOLGA:
			dentro += 1
			pior = minf(pior, sd)
	var metas_ := []
	for meta: Dictionary in metas:
		metas_.append(snappedf(_erro_da_meta(e, meta) * 1000.0, 0.01))
	return {"custo": _soma2(_residuos(x)), "dentro": dentro, "pior_mm": pior * 1000.0,
		"metas_mm": metas_}


# --- vetor <-> pegada -----------------------------------------------------------

func _vetor(p: Dictionary) -> PackedFloat64Array:
	var x := PackedFloat64Array()
	x.resize(N)
	var o: Vector3 = p["o"]
	x[0] = o.x * 1000.0
	x[1] = o.y * 1000.0
	x[2] = o.z * 1000.0
	var pose: Dictionary = p["pose"]
	for i in 4:
		for j in 4:
			x[I_DEDOS + i * 4 + j] = float(pose["dedos"][i][j])
	for j in 5:
		x[I_POLEGAR + j] = float(pose["polegar"][j])
	return x


func _quadro(x: PackedFloat64Array) -> Basis:
	var w := Vector3(x[3], x[4], x[5])
	if w.length() < 1e-6:
		return _base
	return Basis(w.normalized(), deg_to_rad(w.length())) * _base


func _pose(x: PackedFloat64Array) -> Dictionary:
	var dedos := []
	for i in 4:
		var f := []
		for j in 4:
			f.append(snappedf(x[I_DEDOS + i * 4 + j], 0.01))
		dedos.append(f)
	var pol := []
	for j in 5:
		pol.append(snappedf(x[I_POLEGAR + j], 0.01))
	return {"dedos": dedos, "polegar": pol}


func _pegada(x: PackedFloat64Array) -> Dictionary:
	var b := _quadro(x)
	return {"o": Vector3(x[0], x[1], x[2]) * 0.001, "d": b.z.normalized(),
		"dorso": b.y.normalized(), "pose": _pose(x)}


func _limitar(x: PackedFloat64Array) -> void:
	for i in 4:
		for j in 4:
			var k := I_DEDOS + i * 4 + j
			x[k] = clampf(x[k], DEDO_MIN[j], DEDO_MAX[j])
	for j in 5:
		var k := I_POLEGAR + j
		x[k] = clampf(x[k], POLEGAR_MIN[j], POLEGAR_MAX[j])


func _esqueleto(x: PackedFloat64Array) -> Dictionary:
	var b := _quadro(x)
	return MaoPosada.esqueleto(Vector3(x[0], x[1], x[2]) * 0.001, b.z, b.y, _pose(x), direita)


# --- residuos -----------------------------------------------------------------

func _residuos(x: PackedFloat64Array) -> PackedFloat64Array:
	var e := _esqueleto(x)
	var r := PackedFloat64Array()
	for meta: Dictionary in metas:
		_residuo_da_meta(e, meta, r)
	for esf: Array in _esferas(e, _so_polegar):
		var sd := distancia(esf[0], meia, raio_canto) - float(esf[1]) * float(esf[2]) + FOLGA
		r.append(minf(sd, 0.0) * 1000.0 * PESO_DENTRO)
	# Perto do descanso, e o dip acompanhando o pip.
	var de := I_POLEGAR if _so_polegar else I_DEDOS
	for k in range(de, N):
		r.append((x[k] - _descanso[k]) * PESO_DESCANSO)
	if not _so_polegar:
		for i in 4:
			var b := I_DEDOS + i * 4
			r.append((x[b + 2] - DIP_DO_PIP * x[b + 1]) * PESO_ACOPLA)
	return r


func _residuo_da_meta(e: Dictionary, meta: Dictionary, r: PackedFloat64Array) -> void:
	var peso: float = meta.get("peso", 1.0)
	match meta["tipo"]:
		&"polpa":
			var pp := MaoPosada.polpa(e, int(meta["dedo"]))
			var dp: Vector3 = (pp["p"] as Vector3) - (meta["p"] as Vector3)
			# Com `face`, a polpa pode escorregar pela face (peso `t_peso`), mas
			# nao sair dela.
			if meta.has("face"):
				var f: Vector3 = (meta["face"] as Vector3).normalized()
				var fora := dp.dot(f)
				r.append(fora * 1000.0 * peso)
				dp = (dp - f * fora) * float(meta.get("t_peso", 0.3))
			r.append(dp.x * 1000.0 * peso)
			r.append(dp.y * 1000.0 * peso)
			r.append(dp.z * 1000.0 * peso)
			var dn: Vector3 = (pp["dorso"] as Vector3) - (meta["n"] as Vector3).normalized()
			var pn: float = meta.get("peso_n", 1.0) * PESO_NORMAL
			r.append(dn.x * pn)
			r.append(dn.y * pn)
			r.append(dn.z * pn)
		&"encosta":
			r.append(_erro_da_meta(e, meta) * 1000.0 * peso)
		&"rumo":
			var dd: Vector3 = (e["dd"] as Vector3) - (meta["d"] as Vector3).normalized()
			r.append(dd.x * PESO_NORMAL * peso)
			r.append(dd.y * PESO_NORMAL * peso)
			r.append(dd.z * PESO_NORMAL * peso)


## Quanto a meta erra, em metros (para o relatorio e para `encosta`).
func _erro_da_meta(e: Dictionary, meta: Dictionary) -> float:
	match meta["tipo"]:
		&"polpa":
			var pp := MaoPosada.polpa(e, int(meta["dedo"]))
			if meta.has("face"):
				return absf(((pp["p"] as Vector3) - (meta["p"] as Vector3)).dot(
					(meta["face"] as Vector3).normalized()))
			return (pp["p"] as Vector3).distance_to(meta["p"])
		&"encosta":
			var i := int(meta["dedo"])
			var k := int(meta["falange"])
			var t: float = meta.get("t", 0.5)
			var dedo: Dictionary = e["polegar"] if i == 4 else e["dedos"][i]
			var juntas: Array[Vector3] = dedo["juntas"]
			var raios := MaoPosada.raios_do_dedo(i)
			var p := juntas[k].lerp(juntas[k + 1], t)
			var rad := lerpf(float(raios[k]), float(raios[k + 1]), t) * MaoModelada.DEDO_ACHATA
			return distancia(p, meia, raio_canto) - rad
	return 0.0


## A mao em esferas: [centro, raio, margem]. As juntas e o meio de cada falange,
## a bola da ponta, e a palma em cinco por fileira. A bola da ponta nao tem
## margem: e a polpa, e ela tem de poder encostar.
func _esferas(e: Dictionary, so_polegar_: bool) -> Array:
	var saida := []
	var achata := MaoModelada.DEDO_ACHATA
	var ids := [4] if so_polegar_ else [0, 1, 2, 3, 4]
	for i: int in ids:
		var dedo: Dictionary = e["polegar"] if i == 4 else e["dedos"][i]
		var juntas: Array[Vector3] = dedo["juntas"]
		var raios := MaoPosada.raios_do_dedo(i)
		# A base do dedo fica dentro da palma: so conta do meio da primeira
		# falange em diante (a palma responde por ela).
		var de := 1 if i < 4 else 0
		for k in range(de, juntas.size() - 1):
			# A margem so na base: dali para a ponta o dedo e liso, e com ela o
			# polegar nao deitava a ultima falange no vidro.
			var mg := MARGEM if k <= 1 and i == 4 or k == 1 and i < 4 else 1.0
			saida.append([juntas[k], float(raios[k]) * achata, mg])
			saida.append([(juntas[k] + juntas[k + 1]) * 0.5,
				(float(raios[k]) + float(raios[k + 1])) * 0.5 * achata, mg if k == 0 else 1.0])
		var pp := MaoPosada.polpa(e, i)
		saida.append([pp["centro"], float(raios[3]) * achata, 1.0])
	# A membrana entre o polegar e o indicador (`MaoPosada._membrana`): mexe
	# com o polegar.
	var no_p: Vector3 = (e["polegar"]["juntas"] as Array[Vector3])[1]
	var no_i: Vector3 = (e["dedos"][0]["juntas"] as Array[Vector3])[0]
	for t: float in [0.25, 0.5, 0.75]:
		saida.append([no_p.lerp(no_i, t), 0.0065, MARGEM])
	if so_polegar_:
		return saida
	var q: Dictionary = e["q"]
	var ld: Vector3 = e["ld"]
	for fileira: Array in MaoModelada.PALMA:
		var esp: float = fileira[2]
		var meia_l := float(fileira[1]) * 0.5 - esp * 0.5
		for u: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var c := MaoModelada._na_palma(q, ld, float(fileira[3]) + u * meia_l,
				float(fileira[0]), esp * 0.5)
			saida.append([c, esp * 0.5, MARGEM])
	return saida


static func _soma2(r: PackedFloat64Array) -> float:
	var s := 0.0
	for v in r:
		s += v * v
	return s


## Resolve A x = b (n x n, A em linhas) por eliminacao com pivo.
static func _resolver_linear(a: PackedFloat64Array, b: PackedFloat64Array, n: int) -> PackedFloat64Array:
	var m := a.duplicate()
	var v := b.duplicate()
	for c in n:
		var piv := c
		var maior := absf(m[c * n + c])
		for l in range(c + 1, n):
			if absf(m[l * n + c]) > maior:
				maior = absf(m[l * n + c])
				piv = l
		if maior < 1e-12:
			continue
		if piv != c:
			for k in n:
				var t := m[c * n + k]
				m[c * n + k] = m[piv * n + k]
				m[piv * n + k] = t
			var tv := v[c]
			v[c] = v[piv]
			v[piv] = tv
		for l in range(c + 1, n):
			var f := m[l * n + c] / m[c * n + c]
			if f == 0.0:
				continue
			for k in range(c, n):
				m[l * n + k] -= f * m[c * n + k]
			v[l] -= f * v[c]
	var x := PackedFloat64Array()
	x.resize(n)
	for c in range(n - 1, -1, -1):
		var s := v[c]
		for k in range(c + 1, n):
			s -= m[c * n + k] * x[k]
		x[c] = s / m[c * n + c] if absf(m[c * n + c]) > 1e-12 else 0.0
	return x
