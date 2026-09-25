## O desenho da mesa de sinuca (MesaSinuca e so medida e geometria).
##
## Separado de proposito: a fisica e as regras rodam na bancada headless
## (`tests/bancada_sinuca.gd`, com `--script`), onde nao ha autoload. Este
## arquivo puxa KitBar e MoveisDoBar, que puxam meia cidade; se morasse junto das
## medidas, a bancada nao compilava.
class_name DesenhoSinuca
extends RefCounted

const R := MesaSinuca.R
const COMP := MesaSinuca.COMP
const LARG := MesaSinuca.LARG
const ALTURA_PANO := MesaSinuca.ALTURA_PANO
const NARIZ := MesaSinuca.NARIZ
const BORRACHA := MesaSinuca.BORRACHA
const MADEIRA := MesaSinuca.MADEIRA
const BOCA_MEIO := MesaSinuca.BOCA_MEIO
const FORA := MesaSinuca.FORA


static func cacapas() -> PackedVector2Array:
	return MesaSinuca.cacapas()


static func _recuo_canto() -> float:
	return MesaSinuca.BOCA_CANTO / sqrt(2.0)


static var _molde: Dictionary = {}
static var _trava: Mutex = Mutex.new()

const FELTRO := &"bar_feltro"
const MADEIRA_MAT := &"tabua"
const COURO := Color("3a2416")
const MOGNO := Color("5a2e1a")
const MOGNO_ESCURO := Color("3a1c10")
const FELTRO_COR := Color("2a8a4a")
const MIUDO := &"mercado_louca@perto"


## A mesa inteira como molde (material -> dados), no referencial do no: X no
## comprimento, Y para cima, Z = -y. Montada uma vez; as threads do chunk so
## copiam (ver MoveisDoBar, mesma razao). Cores em sRGB, passadas para linear
## (o psx_surface multiplica a COLOR crua no albedo linear).
static func molde() -> Dictionary:
	_trava.lock()
	if _molde.is_empty():
		var m := _fazer()
		for mat: StringName in m:
			var cores: PackedColorArray = m[mat]["c"]
			for k in cores.size():
				var alfa := cores[k].a
				cores[k] = cores[k].srgb_to_linear()
				cores[k].a = alfa
			m[mat]["c"] = cores
		# A cupula ja vem linear do MoveisDoBar: entra depois da conversao.
		_luminaria(m)
		_molde = m
	_trava.unlock()
	return _molde


## Poe a mesa em `sup` e a colisao do movel. `centro` no chao, `giro` do
## comprimento (X local).
static func por(sup: Dictionary, colisao: Array[Dictionary], centro: Vector3,
		giro: float) -> void:
	MoveisDoBar.por(sup, molde(), Transform3D(Basis(Vector3.UP, giro), centro))
	KitModular.solido(colisao, centro + Vector3(0.0, ALTURA_PANO * 0.5, 0.0),
		Vector3(FORA.x, ALTURA_PANO + NARIZ + 0.02, FORA.y), giro)


## Ponto do pano (x, y) em XZ do no, na altura `y`.
static func _xz(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, -p.y)


## Contorno (x, y) da mesa para o (x, z) do no, que e o que Peca.prisma quer.
static func _contorno(pts: Array[Vector2]) -> PackedVector2Array:
	var c := PackedVector2Array()
	for p in pts:
		c.append(Vector2(p.x, -p.y))
	return c


## Arco de `de` ate `ate` em volta de `c`, pelo lado de `via` (direcao a partir
## do centro). Acrescenta os pontos em `pts`, as duas pontas inclusive.
static func _arco(pts: Array[Vector2], c: Vector2, de: Vector2, ate: Vector2,
		via: Vector2, passos: int = 5) -> void:
	var raio := (de - c).length()
	var a0 := (de - c).angle()
	var delta := wrapf((ate - c).angle() - a0, 0.0, TAU)
	var meio := a0 + delta * 0.5
	if Vector2(cos(meio), sin(meio)).dot(via) < 0.0:
		delta -= TAU
	for k in passos + 1:
		var ang := a0 + delta * float(k) / float(passos)
		pts.append(c + Vector2(cos(ang), sin(ang)) * raio)


## Pano com o recorte das seis cacapas, ate o fundo das borrachas.
static func _contorno_pano(raio: float) -> Array[Vector2]:
	var ex := COMP * 0.5 + BORRACHA
	var ey := LARG * 0.5 + BORRACHA
	var cc := cacapas()
	var pts: Array[Vector2] = []
	# Anti-horario: meio de baixo, baixo-direita, cima-direita, meio de cima,
	# cima-esquerda, baixo-esquerda (indices de `cacapas`).
	var ordem: Array[int] = [2, 1, 4, 5, 3, 0]
	for i in ordem:
		var c: Vector2 = cc[i]
		if absf(c.x) < 0.01:
			var sy := signf(c.y)
			var dx := sqrt(maxf(0.0, raio * raio - pow(ey - absf(c.y), 2.0)))
			_arco(pts, c, Vector2(sy * dx, sy * ey), Vector2(-sy * dx, sy * ey),
				Vector2(0.0, -sy))
		else:
			var sx := signf(c.x)
			var sy := signf(c.y)
			var dx := sqrt(maxf(0.0, raio * raio - pow(ey - absf(c.y), 2.0)))
			var dy := sqrt(maxf(0.0, raio * raio - pow(ex - absf(c.x), 2.0)))
			var na_comprida := Vector2(c.x - sx * dx, sy * ey)
			var na_curta := Vector2(sx * ex, c.y - sy * dy)
			# Andando anti-horario, os cantos de baixo-direita e de cima-esquerda
			# chegam pela tabela comprida; os outros dois, pela curta.
			var pela_comprida := (sx > 0.0) == (sy < 0.0)
			var de := na_comprida if pela_comprida else na_curta
			var ate := na_curta if pela_comprida else na_comprida
			_arco(pts, c, de, ate, Vector2(-sx, -sy).normalized())
	return pts


## A tabua de uma metade (sy = +1 em cima, -1 embaixo): um U que abraca as tres
## cacapas daquele lado pelo lado de fora.
static func _contorno_tabua(sy: float, raio: float) -> Array[Vector2]:
	var ex := COMP * 0.5 + BORRACHA
	var ey := LARG * 0.5 + BORRACHA
	var fx := FORA.x * 0.5
	var fy := FORA.y * 0.5
	var cc := cacapas()
	var dir_c: Vector2 = cc[4] if sy > 0.0 else cc[1]
	var esq_c: Vector2 = cc[3] if sy > 0.0 else cc[0]
	var meio_c: Vector2 = cc[5] if sy > 0.0 else cc[2]
	var pts: Array[Vector2] = []
	var dy := sqrt(maxf(0.0, raio * raio - pow(ex - absf(dir_c.x), 2.0)))
	var dx := sqrt(maxf(0.0, raio * raio - pow(ey - absf(dir_c.y), 2.0)))
	var dm := sqrt(maxf(0.0, raio * raio - pow(ey - absf(meio_c.y), 2.0)))
	pts.append(Vector2(ex, 0.0))
	_arco(pts, dir_c, Vector2(ex, dir_c.y - sy * dy), Vector2(dir_c.x - dx, sy * ey),
		Vector2(1.0, sy).normalized())
	_arco(pts, meio_c, Vector2(dm, sy * ey), Vector2(-dm, sy * ey), Vector2(0.0, sy))
	_arco(pts, esq_c, Vector2(esq_c.x + dx, sy * ey), Vector2(-ex, esq_c.y - sy * dy),
		Vector2(-1.0, sy).normalized())
	pts.append(Vector2(-ex, 0.0))
	pts.append(Vector2(-fx, 0.0))
	pts.append(Vector2(-fx, sy * fy))
	pts.append(Vector2(fx, sy * fy))
	pts.append(Vector2(fx, 0.0))
	return pts


static func _fazer() -> Dictionary:
	var s := {}
	var hx := COMP * 0.5
	var hy := LARG * 0.5
	var topo_tabela := ALTURA_PANO + NARIZ + 0.012
	var fora := FORA * 0.5

	# Pano, recortado nas cacapas: sem o recorte o topo dele tampava o copo.
	Peca.prisma(s, FELTRO, Transform3D.IDENTITY, _contorno(_contorno_pano(0.06)),
		ALTURA_PANO - 0.04, ALTURA_PANO, FELTRO_COR)

	# Borrachas: a pegada de cada tabela com as bochechas cortadas a 45 graus, da
	# altura do pano ate o nariz. E ela que a fisica ve (MesaSinuca.segmentos).
	var d := _recuo_canto()
	var m := BOCA_MEIO * 0.5
	var b := BORRACHA
	var borracha := FELTRO_COR.darkened(0.1)
	for sy: float in [-1.0, 1.0]:
		for sx: float in [-1.0, 1.0]:
			var pts: Array[Vector2] = [
				Vector2(sx * (hx - d), sy * hy), Vector2(sx * m, sy * hy),
				Vector2(sx * (m - 0.012), sy * (hy + b)), Vector2(sx * (hx - d + b), sy * (hy + b)),
			]
			Peca.prisma(s, FELTRO, Transform3D.IDENTITY, _contorno(pts),
				ALTURA_PANO - 0.01, ALTURA_PANO + NARIZ + 0.006, borracha)
	for sx: float in [-1.0, 1.0]:
		var pts: Array[Vector2] = [
			Vector2(sx * hx, -(hy - d)), Vector2(sx * hx, hy - d),
			Vector2(sx * (hx + b), hy - d + b), Vector2(sx * (hx + b), -(hy - d + b)),
		]
		Peca.prisma(s, FELTRO, Transform3D.IDENTITY, _contorno(pts),
			ALTURA_PANO - 0.01, ALTURA_PANO + NARIZ + 0.006, borracha)

	# Tabua de mogno, em dois U que abracam as cacapas. O topo fica um dedo acima
	# do nariz, como na mesa de verdade.
	for sy: float in [-1.0, 1.0]:
		Peca.prisma(s, MADEIRA_MAT, Transform3D.IDENTITY, _contorno(_contorno_tabua(sy, 0.078)),
			ALTURA_PANO - 0.08, topo_tabela, MOGNO)

	# Cacapas: o copo de couro escuro e o aro por cima da tabua.
	for c: Vector2 in cacapas():
		var raio := 0.064
		Peca.torno(s, MADEIRA_MAT, Transform3D(Basis.IDENTITY, _xz(c, 0.0)), PackedVector2Array([
			Vector2(0.0, ALTURA_PANO - 0.16), Vector2(raio * 0.8, ALTURA_PANO - 0.16),
			Vector2(raio, ALTURA_PANO - 0.08), Vector2(raio + 0.012, topo_tabela + 0.002),
			Vector2(raio + 0.012, topo_tabela + 0.002), Vector2(raio - 0.004, topo_tabela + 0.005),
			Vector2(raio - 0.006, ALTURA_PANO - 0.02), Vector2(0.0, ALTURA_PANO - 0.05),
		]), 12, COURO)

	# Diamantes de madreperola no topo das tabuas: tres por meia comprida, tres
	# na curta. E por eles que quem joga mede a tabela.
	var yd := topo_tabela + 0.001
	var meio_tabua := b + MADEIRA * 0.5
	for sy: float in [-1.0, 1.0]:
		for k: int in [-3, -2, -1, 1, 2, 3]:
			_diamante(s, _xz(Vector2(float(k) * COMP / 8.0, sy * (hy + meio_tabua)), yd))
	for sx: float in [-1.0, 1.0]:
		for k: int in [-1, 0, 1]:
			_diamante(s, _xz(Vector2(sx * (hx + meio_tabua), float(k) * LARG / 4.0), yd))

	# Saia de mogno, o friso de baixo e os quatro pes torneados.
	Peca.prisma(s, MADEIRA_MAT, Transform3D.IDENTITY,
		Peca.retangulo_redondo(FORA - Vector2(0.04, 0.04), 0.03, 1),
		0.5, ALTURA_PANO - 0.08, MOGNO_ESCURO)
	Peca.prisma(s, MADEIRA_MAT, Transform3D.IDENTITY,
		Peca.retangulo_redondo(FORA, 0.035, 1), 0.47, 0.52, MOGNO)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var pe := Vector3(sx * (fora.x - 0.16), 0.0, sy * (fora.y - 0.14))
			Peca.torno(s, MADEIRA_MAT, Transform3D(Basis.IDENTITY, pe), PackedVector2Array([
				Vector2(0.0, 0.0), Vector2(0.075, 0.0), Vector2(0.075, 0.0),
				Vector2(0.08, 0.05), Vector2(0.055, 0.1), Vector2(0.05, 0.22),
				Vector2(0.075, 0.3), Vector2(0.06, 0.38), Vector2(0.065, 0.48),
			]), 8, MOGNO_ESCURO)
	return s


## Luminaria de tres cupulas sobre o pano, numa travessa de madeira presa no
## forro por dois cabos. Entra no molde ja convertido para linear.
static func _luminaria(s: Dictionary) -> void:
	var alto := ALTURA_PANO + 0.95
	var t := {}
	Peca.prisma(t, MADEIRA_MAT, Transform3D.IDENTITY,
		Peca.retangulo_redondo(Vector2(COMP * 0.72, 0.07), 0.02, 1), alto + 0.12, alto + 0.16,
		MOGNO.srgb_to_linear())
	for k: int in [-1, 1]:
		Peca.tubo(t, &"metal_pintado", PackedVector3Array([
			Vector3(float(k) * COMP * 0.3, alto + 0.16, 0.0),
			Vector3(float(k) * COMP * 0.3, KitBar.ALTURA_SALAO, 0.0),
		]), 0.006, 3, Color(0.02, 0.02, 0.02), false)
	for mat: StringName in t:
		if not s.has(mat):
			s[mat] = PSXMesh.dados_vazios()
		PSXMesh.acumular(s[mat], t[mat], Transform3D.IDENTITY)
	var cupula := MoveisDoBar.cupula()
	for k: int in [-1, 0, 1]:
		var em := Vector3(float(k) * COMP * 0.3, alto, 0.0)
		for mat: StringName in cupula:
			if not s.has(mat):
				s[mat] = PSXMesh.dados_vazios()
			# A cupula de boteco, maior: 1,3 vez a do pendente do salao.
			PSXMesh.acumular(s[mat], cupula[mat],
				Transform3D(Basis.IDENTITY.scaled(Vector3(1.3, 1.1, 1.3)), em))


## Diamante de madreperola: losango raso.
static func _diamante(s: Dictionary, p: Vector3) -> void:
	Peca.prisma(s, MIUDO, Transform3D(Basis.IDENTITY, p), PackedVector2Array([
		Vector2(0.012, 0.0), Vector2(0.0, 0.007), Vector2(-0.012, 0.0), Vector2(0.0, -0.007),
	]), 0.0, 0.002, Color("efe8da"))


static var _porta_tacos: Dictionary = {}


## Porta-tacos de parede: a tabua, o apoio de baixo, a presilha de cima e tres
## tacos em pe. Costas na parede (z = 0), frente para +Z, base no chao.
static func porta_tacos() -> Dictionary:
	_trava.lock()
	if _porta_tacos.is_empty():
		var s := {}
		Peca.prisma(s, MADEIRA_MAT, Transform3D.IDENTITY,
			Peca.retangulo_redondo(Vector2(0.42, 0.03), 0.01, 1), 0.12, 1.62, MOGNO)
		for y: float in [0.2, 1.38]:
			Peca.prisma(s, MADEIRA_MAT, Transform3D.IDENTITY, PackedVector2Array([
				Vector2(-0.21, 0.015), Vector2(0.21, 0.015), Vector2(0.21, 0.09),
				Vector2(-0.21, 0.09),
			]), y, y + 0.04, MOGNO_ESCURO)
		for k in 3:
			var x := -0.12 + 0.12 * float(k)
			var inclina := 0.012 * float(k - 1)
			Peca.tubo(s, MADEIRA_MAT, PackedVector3Array([
				Vector3(x, 0.24, 0.055), Vector3(x + inclina, 1.0, 0.055),
			]), 0.012, 6, Color("3a2016"), true, PackedFloat32Array([0.0145, 0.0105]))
			Peca.tubo(s, MADEIRA_MAT, PackedVector3Array([
				Vector3(x + inclina, 1.0, 0.055), Vector3(x + inclina * 1.8, 1.68, 0.055),
			]), 0.008, 6, Color("d8b67c"), false, PackedFloat32Array([0.0105, 0.0062]))
			Peca.tubo(s, MIUDO, PackedVector3Array([
				Vector3(x + inclina * 1.8, 1.68, 0.055), Vector3(x + inclina * 1.82, 1.7, 0.055),
			]), 0.0062, 6, Color("f2efe6"), true)
		for mat: StringName in s:
			var cores: PackedColorArray = s[mat]["c"]
			for k in cores.size():
				var alfa := cores[k].a
				cores[k] = cores[k].srgb_to_linear()
				cores[k].a = alfa
			s[mat]["c"] = cores
		_porta_tacos = s
	_trava.unlock()
	return _porta_tacos
