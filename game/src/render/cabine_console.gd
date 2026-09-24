## O console entre os bancos: a frente embaixo do porta-trecos, o tunel
## esculpido, a coifa de couro com a alavanca do cambio, o freio de mao, os
## porta-copos, e os tapetes de borracha no assoalho.
##
## A alavanca e o freio sao pivos: a alavanca vai para a posicao da marcha que
## o motor engatou (a grade em H impressa no pomo e a mesma), e o freio sobe
## quando e puxado. E o tipo de coisa que o olho confere sem saber que confere.
class_name CabineConsole
extends RefCounted

## O freio de mao, em graus em volta de X: solto quase deitado, puxado alto.
const FREIO_SOLTO := -5.0
const FREIO_PUXADO := -24.0
## Quanto a alavanca do cambio pende para o motorista, e quanto ela anda.
const CAMBIO_RAKE := 9.0
const CAMBIO_LADO := 7.0
const CAMBIO_CURSO := 10.0
## Altura da alavanca, do pivo ao centro do pomo.
const CAMBIO_ALTURA := 0.215


## A posicao da alavanca para uma marcha: x e o giro de lado (+ para a
## esquerda), y o de frente (- para a frente do carro), em radianos.
static func posicao_da_marcha(rotulo: String) -> Vector2:
	var lado := deg_to_rad(CAMBIO_LADO)
	var curso := deg_to_rad(CAMBIO_CURSO)
	match rotulo:
		"1":
			return Vector2(lado, -curso)
		"2":
			return Vector2(lado, curso)
		"3":
			return Vector2(0.0, -curso)
		"4":
			return Vector2(0.0, curso)
		"5":
			return Vector2(-lado, -curso)
		"R":
			return Vector2(-lado, curso)
	return Vector2.ZERO


static func base_da_alavanca(giro: Vector2) -> Basis:
	return Basis(Vector3.RIGHT, deg_to_rad(CAMBIO_RAKE) + giro.y) \
		* Basis(Vector3.BACK, giro.x)


static func montar(it: CabineInterior) -> void:
	var olho: Vector3 = it.g["olho"]
	var piso: float = it.g["piso"]
	var c: Dictionary = it.g["_centro"]
	var pt: Dictionary = it.g["_porta_trecos"]
	var hw: float = c["meia"]
	var y_prat: float = pt["y_prat"]
	var z_fundo: float = pt["z_fundo"]
	var z_frente: float = c["z_frente"]
	var bancos: Vector2 = it.g["bancos"]
	var cw := clampf(bancos.x - bancos.y * 0.5 - 0.014, 0.075, 0.125)
	var z_cambio := olho.z - 0.13
	var z_freio := olho.z + 0.07
	var z_fim := olho.z + 0.52
	var pl := it.m(&"plastico")

	# A frente, do assoalho ate a prateleira do porta-trecos.
	pl.caixa(Vector3(0, (piso - 0.02 + y_prat - 0.014) * 0.5,
		(z_fundo - 0.03 + z_frente + 0.03) * 0.5),
		Vector3(hw, (y_prat - 0.014 - piso + 0.02) * 0.5, (z_frente - z_fundo + 0.06) * 0.5),
		0.014, CabineInterior.COR_CONSOLE)

	# O tunel: secoes em U (sem fundo) ao longo de z, altura e largura por
	# estacao, e a transicao suave entre elas.
	var chaves := [
		[z_frente, y_prat - 0.02, hw - 0.004],
		[z_frente + 0.07, piso + 0.205, cw + 0.012],
		[z_cambio + 0.09, piso + 0.200, cw],
		[z_freio - 0.05, piso + 0.190, cw],
		[z_freio + 0.28, piso + 0.200, cw],
		[z_fim, piso + 0.225, cw + 0.004],
	]
	var linhas: Array = []
	var zs: Array[float] = []
	var passos := 6
	for k in chaves.size() - 1:
		var a: Array = chaves[k]
		var b: Array = chaves[k + 1]
		for i in passos:
			var t := float(i) / float(passos)
			var s := t * t * (3.0 - 2.0 * t)
			var z := lerpf(a[0], b[0], t)
			linhas.append(_secao(z, piso - 0.015, lerpf(a[1], b[1], s), lerpf(a[2], b[2], s)))
			zs.append(z)
	var ult: Array = chaves[chaves.size() - 1]
	linhas.append(_secao(ult[0], piso - 0.015, ult[1], ult[2]))
	zs.append(ult[0])
	pl.grade_de_pontos(linhas, CabineInterior.COR_CONSOLE,
		func(k: int, _j: int) -> Vector3: return Vector3(0.0, piso + 0.06, zs[k]))
	var tampa := linhas[linhas.size() - 1] as PackedVector3Array
	pl.poligono(tampa, Vector3.BACK, CabineInterior.COR_CONSOLE.darkened(0.08))

	_cambio(it, Vector3(0.0, piso + 0.200, z_cambio))
	_freio(it, Vector3(0.0, piso + 0.190, z_freio))
	_porta_copos(it, Vector3(0.0, piso + 0.200, z_freio + 0.33), cw)
	_tapetes(it)


## Uma secao do tunel em U: das duas bordas de baixo, subindo, e o topo com as
## quinas arredondadas.
static func _secao(z: float, y0: float, topo: float, meia: float) -> PackedVector3Array:
	var r := minf(0.028, meia * 0.4)
	var out := PackedVector3Array()
	out.append(Vector3(-meia, y0, z))
	out.append(Vector3(-meia, lerpf(y0, topo - r, 0.5), z))
	for k in 6:
		var a := PI - PI * 0.5 * float(k) / 5.0
		out.append(Vector3(-meia + r + cos(a) * r, topo - r + sin(a) * r, z))
	out.append(Vector3(0.0, topo + 0.002, z))
	for k in 6:
		var a := PI * 0.5 - PI * 0.5 * float(k) / 5.0
		out.append(Vector3(meia - r + cos(a) * r, topo - r + sin(a) * r, z))
	out.append(Vector3(meia, lerpf(y0, topo - r, 0.5), z))
	out.append(Vector3(meia, y0, z))
	return out


## Coifa sanfonada, moldura e a alavanca com o pomo.
static func _cambio(it: CabineInterior, base: Vector3) -> void:
	var pl := it.m(&"plastico")
	var em_pe := Basis(Vector3.RIGHT, -PI * 0.5)
	# A moldura da coifa, rente ao console.
	pl.torno(Transform3D(em_pe, base), [Vector2(0.050, 0.004), Vector2(0.058, 0.0052),
		Vector2(0.066, 0.0035), Vector2(0.069, 0.0)], CabineInterior.COR_PECA, 48)
	# A alavanca num pivo, com a coifa junto: o couro sobe ate o pomo e se
	# inclina com a alavanca. Parada, a coifa deixava 10 cm de haste cromada a
	# mostra, que e cambio de kart e nao de carro de rua.
	it.pivo("Alavanca", Transform3D(Basis(), base + Vector3(0, 0.02, 0)),
		func() -> void:
			var h := CAMBIO_ALTURA
			var perfil: Array = []
			var n := 30
			var alto := h - 0.030
			for k in n + 1:
				var t := 1.0 - float(k) / float(n)
				var y := -0.024 + (alto + 0.024) * t
				var r := lerpf(0.052, 0.0105, pow(t, 0.62)) \
					+ 0.0040 * sin(t * PI * 9.0) * (1.0 - t * 0.7)
				perfil.append(Vector2(r, y))
			it.m(&"plastico").torno(Transform3D(em_pe, Vector3.ZERO), perfil,
				CabineInterior.COR_COURO, 40)
			it.m(&"metal").tubo(PackedVector3Array([Vector3.ZERO, Vector3(0, h - 0.018, 0)]),
				PackedFloat32Array([0.0064]), CabineInterior.COR_CROMO, 16)
			var pomo := Transform3D(em_pe, Vector3(0, h - 0.024, 0))
			var perf: Array = []
			for k in 13:
				var a := PI * 0.5 - PI * float(k) / 12.0
				perf.append(Vector2(cos(a) * 0.0215 + (0.0 if k < 12 else 0.0),
					0.024 + sin(a) * 0.026))
			perf[0] = Vector2(0.0, 0.050)
			perf[1] = Vector2(0.012, 0.0498)
			it.m(&"plastico").torno(pomo, perf, Color(0.03, 0.03, 0.03, 0.08), 40)
			it.m(&"impresso").disco(pomo * Transform3D(Basis(), Vector3(0, 0, 0.0503)),
				0.0105, ImpressosCabine.uv(ImpressosCabine.R_CAMBIO),
				Color(0.03, 0.03, 0.03, 0.0), 32, 1.0))


## O freio de mao: coifa de fenda, a haste e o cabo de plastico com o botao.
static func _freio(it: CabineInterior, base: Vector3) -> void:
	var pl := it.m(&"plastico")
	pl.caixa(base + Vector3(0, 0.004, 0.05), Vector3(0.030, 0.008, 0.085), 0.008,
		CabineInterior.COR_COURO)
	pl.caixa(base + Vector3(0, 0.012, 0.05), Vector3(0.010, 0.0012, 0.070), 0.001,
		Color(0.01, 0.01, 0.01, 1.0))
	it.pivo("FreioDeMao", Transform3D(Basis(), base + Vector3(0, 0.012, 0.0)),
		func() -> void:
			var met := it.m(&"metal")
			met.caixa(Vector3(0, 0.004, 0.07), Vector3(0.006, 0.010, 0.075), 0.003,
				Color(0.30, 0.30, 0.31, 0.6))
			var p := it.m(&"plastico")
			# O cabo: afina para a ponta, com os sulcos de dedo embaixo.
			var linhas: Array = []
			var miolos: Array[Vector3] = []
			for k in 10:
				var t := float(k) / 9.0
				var z := lerpf(0.10, 0.255, t)
				var a := lerpf(0.016, 0.0135, t)
				var b := lerpf(0.016, 0.0125, t)
				var anel := PackedVector3Array()
				for j in 25:
					var fi := TAU * float(j) / 24.0
					var cx := cos(fi)
					var cy := sin(fi)
					var sulco := 0.0
					if cy < -0.3 and t > 0.25 and t < 0.85:
						sulco = 0.0018 * absf(sin(t * PI * 9.0))
					anel.append(Vector3(signf(cx) * pow(absf(cx), 0.7) * a,
						signf(cy) * pow(absf(cy), 0.7) * (b - sulco) + 0.006, z))
				linhas.append(anel)
				miolos.append(Vector3(0, 0.006, z))
			p.grade_de_pontos(linhas, Color(0.05, 0.05, 0.05, 0.6),
				func(k: int, _j: int) -> Vector3: return miolos[k])
			var ponta := PackedVector3Array()
			var ultimo := linhas[linhas.size() - 1] as PackedVector3Array
			for j in 24:
				ponta.append(ultimo[j])
			p.poligono(ponta, Vector3.BACK, Color(0.05, 0.05, 0.05, 0.6))
			met.torno(Transform3D(Basis(), Vector3(0, 0.006, 0.255)), [
				Vector2(0.0, 0.009), Vector2(0.0055, 0.0088), Vector2(0.0072, 0.006),
				Vector2(0.0075, 0.0)], CabineInterior.COR_CROMO, 24))


static func _porta_copos(it: CabineInterior, c: Vector3, cw: float) -> void:
	var pl := it.m(&"plastico")
	var r := minf(0.034, cw * 0.5 - 0.006)
	for s: float in [-1.0, 1.0]:
		var o := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
			c + Vector3(s * (r + 0.004), 0.0, 0.0))
		# Borda, parede de dentro e o fundo.
		pl.torno(o, [Vector2(r - 0.0005, -0.050), Vector2(r - 0.0005, 0.0),
			Vector2(r + 0.002, 0.0028), Vector2(r + 0.005, 0.0)],
			Color(0.06, 0.058, 0.056, 0.7), 40)
		pl.disco(o * Transform3D(Basis(), Vector3(0, 0, -0.049)), r, Rect2(0, 0, 1, 1),
			Color(0.03, 0.03, 0.03, 1.0), 32)


## Tapetes de borracha nos dois pes da frente, com os frisos e o calcanhar.
static func _tapetes(it: CabineInterior) -> void:
	var piso: float = it.g["piso"]
	var olho: Vector3 = it.g["olho"]
	var zf: float = it.g["z_frente"]
	var bancos: Vector2 = it.g["bancos"]
	var pl := it.m(&"plastico")
	var z0 := maxf(zf + 0.10, olho.z - 0.72)
	var z1 := olho.z - 0.02
	var meia_x := minf(0.20, bancos.y * 0.5)
	for s: float in [-1.0, 1.0]:
		var x := s * bancos.x
		var w := it.parede(piso + 0.01, piso + 0.02, (z0 + z1) * 0.5)
		var xm := clampf(x, -(w - meia_x - 0.01), w - meia_x - 0.01)
		pl.caixa(Vector3(xm, piso + 0.004, (z0 + z1) * 0.5),
			Vector3(meia_x, 0.004, (z1 - z0) * 0.5), 0.004,
			Color(0.055, 0.052, 0.050, 1.0))
		for k in 9:
			var z := lerpf(z0 + 0.05, z1 - 0.06, float(k) / 8.0)
			pl.caixa(Vector3(xm, piso + 0.0088, z), Vector3(meia_x - 0.025, 0.0012, 0.004),
				0.001, Color(0.05, 0.048, 0.046, 1.0))
