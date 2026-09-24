## O forro das portas: o painel que segue a parede curva da casca, o peitoril,
## o miolo de veludo, a faixa de carpete, o apoio de braco com o puxador, a
## macaneta na concha, a manivela do vidro, o pino da trava, o alto-falante e o
## bolso — com a flanela amarela que todo carro brasileiro tem na porta.
##
## Tudo e medido do VAO da porta (`Carroceria.montar` -> `aberturas`) e da
## parede da casca naquela altura (`CabineCasca.parede_x`): a secao do carro
## afina para baixo, e peca posta pela largura do carro atravessa a porta.
class_name CabinePortas
extends RefCounted

## Quanto o forro fica para dentro da parede da casca.
const AFASTA := 0.008
## Alturas, medidas para baixo da linha da janela.
const H_APOIO := 0.175
const H_MACANETA := 0.105
const H_MANIVELA := 0.245
## Onde cada peca fica ao longo da porta, de 0 (frente) a 1 (tras).
const U_MACANETA := 0.14
const U_MANIVELA := 0.36
const U_APOIO := 0.55
const U_TRAVA := 0.92
const U_ALTO_FALANTE := 0.20

const COR_FORRO := Color(0.165, 0.152, 0.140, 1.0)
const COR_PEITORIL := Color(0.105, 0.098, 0.092, 1.0)
const COR_CARPETE := Color(0.075, 0.070, 0.066, 1.0)
const COR_FLANELA := Color(0.93, 0.74, 0.16, 0.0)


static func montar(it: CabineInterior) -> void:
	var aberturas: Array = it.g.get("aberturas", [])
	var ficha: Dictionary = it.g["ficha"]
	for a: Dictionary in aberturas:
		var tipo: StringName = a["tipo"]
		if tipo != &"porta_frente" and tipo != &"porta_tras":
			continue
		var pontos: PackedVector3Array = a["pontos"]
		if pontos.size() < 4:
			continue
		_porta(it, pontos, int(a["lado"]), tipo == &"porta_frente", ficha)


## A parede no ponto (y, z), recuada `AFASTA`, no lado `s`.
static func _x(it: CabineInterior, y: float, z: float, s: float) -> float:
	var info: Dictionary = it.g["info"]
	return s * (absf(CabineCasca.parede_x(info, y, z, 1.0)) - AFASTA)


## Uma base na parede em (y, z): +Y da base olha para DENTRO do carro (a face
## que aparece), +Z corre para tras ao longo da porta, +X sobe pela parede.
##
## Numa porta ela e de mao direita, na outra de mao esquerda — e o espelho, e
## tem de ser: a macaneta fica na frente das DUAS portas. A malha nao liga para
## isso, porque o giro de cada triangulo sai da normal (`MalhaLisa.tri`).
static func _na_parede(it: CabineInterior, y: float, z: float, s: float,
		fora: float) -> Transform3D:
	var x := _x(it, y, z, s)
	var xa := _x(it, y + 0.02, z, s)
	var xb := _x(it, y - 0.02, z, s)
	var sobe := Vector3(xa - xb, 0.04, 0.0).normalized()
	var dentro := Vector3(-s, 0.0, 0.0)
	dentro = (dentro - sobe * dentro.dot(sobe)).normalized()
	var tras := sobe.cross(dentro).normalized()
	if tras.z < 0.0:
		tras = -tras
	return Transform3D(Basis(sobe, dentro, tras), Vector3(x, y, z) + dentro * fora)


static func _porta(it: CabineInterior, pontos: PackedVector3Array, s: int,
		dianteira: bool, ficha: Dictionary) -> void:
	var piso: float = it.g["piso"]
	var frente := pontos[0]
	var tras := pontos[1]
	var y_jan := (frente.y + tras.y) * 0.5
	var z0 := minf(frente.z, tras.z) + 0.012
	var z1 := maxf(frente.z, tras.z) - 0.012
	var comp := z1 - z0
	var sf := float(s)
	var pl := it.m(&"plastico")

	# O painel: uma grade na parede, do assoalho ate a janela.
	var linhas: Array = []
	var cores: Array = []
	var ys: Array[float] = []
	var n := 14
	for k in n + 1:
		var t := float(k) / float(n)
		ys.append(lerpf(piso + 0.02, y_jan - 0.004, t))
	for y: float in ys:
		var linha := PackedVector3Array()
		for j in 13:
			var z := lerpf(z0, z1, float(j) / 12.0)
			linha.append(Vector3(_x(it, y, z, sf), y, z))
		linhas.append(linha)
		cores.append(COR_CARPETE if y < piso + 0.13 else COR_FORRO)
	pl.grade_de_pontos(linhas, COR_FORRO,
		func(k: int, j: int) -> Vector3:
			var q: Vector3 = (linhas[k] as PackedVector3Array)[j]
			return Vector3(q.x + sf * 0.3, q.y, q.z), cores)

	# O peitoril: a faixa de cima, onde o cotovelo apoia.
	var zm := (z0 + z1) * 0.5
	var peit := _na_parede(it, y_jan - 0.022, zm, sf, 0.0)
	pl.caixa(peit * Vector3(0, 0.014, 0), Vector3(0.022, 0.016, comp * 0.5), 0.012,
		COR_PEITORIL, peit.basis, 3, 0.0, 0)

	# O miolo de veludo, estofado, entre o peitoril e o bolso.
	var y_alto := y_jan - 0.075
	var y_baixo := piso + 0.215
	if y_alto - y_baixo > 0.12:
		# Em gomos horizontais, como o encosto do banco: o forro e o banco eram
		# o mesmo tecido e a mesma costura.
		var tec := it.m(&"tecido")
		var cor_miolo := Color(ficha["banco"]) * Color(1.10, 0.96, 0.82)
		var gomos := 3
		var passo := (y_alto - y_baixo) / float(gomos)
		for k in gomos:
			var yk := y_baixo + passo * (float(k) + 0.5)
			var miolo := _na_parede(it, yk, zm + 0.01, sf, 0.0)
			tec.caixa(miolo * Vector3(0, 0.004, 0),
				Vector3(passo * 0.5 - 0.002, 0.008, comp * 0.5 - 0.06), 0.010,
				Color(cor_miolo, 1.0), miolo.basis, 3, 0.006, 4)
		# O friso que separa o miolo do forro de baixo.
		var fr := _na_parede(it, y_baixo - 0.008, zm, sf, 0.0)
		pl.caixa(fr * Vector3(0, 0.006, 0), Vector3(0.004, 0.005, comp * 0.5 - 0.03),
			0.003, COR_PEITORIL, fr.basis)

	# O apoio de braco, com o puxador fundo.
	if bool(ficha["apoio_braco"]):
		var za := lerpf(z0, z1, U_APOIO)
		var ap := _na_parede(it, y_jan - H_APOIO, za, sf, 0.0)
		var lc := comp * (0.36 if dianteira else 0.30)
		pl.caixa(ap * Vector3(0, 0.034, 0), Vector3(0.020, 0.036, lc * 0.5), 0.016,
			COR_PEITORIL, ap.basis, 3, 0.0, 0)
		pl.caixa(ap * Vector3(0.020, 0.030, -lc * 0.18), Vector3(0.002, 0.022, 0.050),
			0.002, Color(0.02, 0.02, 0.02, 1.0), ap.basis)

	# A macaneta: concha escura e a alavanca cromada deitada nela.
	var zmac := lerpf(z0, z1, U_MACANETA)
	var mac := _na_parede(it, y_jan - H_MACANETA, zmac, sf, 0.0)
	pl.caixa(mac * Vector3(0, 0.004, 0), Vector3(0.028, 0.006, 0.048), 0.006,
		Color(0.02, 0.02, 0.02, 0.9), mac.basis)
	it.m(&"metal").caixa(mac * Vector3(0.004, 0.011, -0.004), Vector3(0.008, 0.004, 0.040),
		0.0035, CabineInterior.COR_CROMO, mac.basis)

	# A manivela do vidro: base, braco e o pomo que gira.
	if bool(ficha["manivela"]):
		var zman := lerpf(z0, z1, U_MANIVELA)
		var man := _na_parede(it, y_jan - H_MANIVELA, zman, sf, 0.0)
		var eixo := Transform3D(man.basis * Basis(Vector3.RIGHT, -PI * 0.5), man.origin)
		it.m(&"plastico").torno(eixo, [Vector2(0.0, 0.016), Vector2(0.010, 0.016),
			Vector2(0.016, 0.008), Vector2(0.020, 0.0)], COR_PEITORIL, 32)
		var giro := deg_to_rad(-35.0)
		var dir := man.basis * Vector3(cos(giro), 0.0, sin(giro))
		var braco_c := man.origin + man.basis.y * 0.020 + dir * 0.038
		it.m(&"metal").caixa(braco_c, Vector3(0.042, 0.0035, 0.007), 0.003,
			CabineInterior.COR_CROMO, Basis(dir, man.basis.y, dir.cross(man.basis.y)))
		var pomo := man.origin + man.basis.y * 0.022 + dir * 0.074
		it.m(&"plastico").torno(Transform3D(eixo.basis, pomo), [Vector2(0.0, 0.034),
			Vector2(0.008, 0.033), Vector2(0.010, 0.026), Vector2(0.009, 0.006),
			Vector2(0.0065, 0.0)], Color(0.05, 0.05, 0.05, 0.2), 20)

	# O pino da trava, em pe no peitoril.
	var ztr := lerpf(z0, z1, U_TRAVA)
	var y_tr := y_jan - 0.004
	var xtr := _x(it, y_tr, ztr, sf) - sf * 0.028
	it.m(&"metal").torno(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(xtr, y_tr, ztr)),
		[Vector2(0.0, 0.036), Vector2(0.004, 0.035), Vector2(0.0055, 0.031),
		Vector2(0.0048, 0.0)], CabineInterior.COR_CROMO, 16)

	# O alto-falante, na parte de baixo da porta da frente.
	if dianteira and bool(ficha["alto_falante"]):
		var zal := lerpf(z0, z1, U_ALTO_FALANTE)
		var yal := piso + 0.19
		var al := _na_parede(it, yal, zal, sf, 0.0)
		var ax := Transform3D(al.basis * Basis(Vector3.RIGHT, -PI * 0.5), al.origin)
		var r := 0.062
		pl.torno(ax, [Vector2(0.0, 0.004), Vector2(r, 0.004), Vector2(r + 0.004, 0.009),
			Vector2(r + 0.010, 0.006), Vector2(r + 0.013, 0.0)], Color(0.03, 0.03, 0.03, 0.9),
			48)
		# A grade: aneis finos em relevo sobre o disco escuro.
		for k in range(1, 7):
			var rr := r * float(k) / 7.0
			pl.torno(ax, [Vector2(rr - 0.0016, 0.0042), Vector2(rr, 0.0056),
				Vector2(rr + 0.0016, 0.0042)], Color(0.06, 0.06, 0.06, 0.8), 48)
		it.m(&"metal").torno(ax, [Vector2(0.0, 0.0072), Vector2(0.010, 0.0068),
			Vector2(0.013, 0.0045)], Color(0.35, 0.35, 0.37, 0.5), 24)

	# O bolso de baixo: a aba que sai da porta, e o fundo escuro dentro.
	var zb0 := z0 + comp * (0.34 if dianteira else 0.12)
	var zb1 := z1 - 0.05
	if zb1 - zb0 > 0.12:
		var zbm := (zb0 + zb1) * 0.5
		var bo := _na_parede(it, piso + 0.135, zbm, sf, 0.0)
		pl.caixa(bo * Vector3(0, 0.034, 0), Vector3(0.055, 0.006, (zb1 - zb0) * 0.5),
			0.005, COR_PEITORIL, bo.basis)
		pl.caixa(bo * Vector3(-0.010, 0.016, 0), Vector3(0.045, 0.012, (zb1 - zb0) * 0.5 - 0.006),
			0.004, Color(0.015, 0.015, 0.015, 1.0), bo.basis)
		# A flanela amarela dobrada, com a ponta para fora, na porta do motorista.
		if dianteira and s < 0:
			var tec := it.m(&"tecido")
			var fl := bo * Transform3D(Basis(Vector3.BACK, 0.25), Vector3(0.050, 0.020,
				(zb1 - zb0) * 0.2))
			tec.caixa(fl.origin, Vector3(0.030, 0.010, 0.075), 0.008, COR_FLANELA,
				fl.basis, 3, 0.004, 3)
			tec.caixa(fl * Vector3(0.028, 0.004, -0.035), Vector3(0.012, 0.006, 0.030),
				0.005, COR_FLANELA, fl.basis * Basis(Vector3.BACK, 0.6))
