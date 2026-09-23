## Primitivas que nao sao caixa: torno, tubo, prisma e esfera.
##
## Por que isto existe
## -------------------
## O kit da loja foi montado quase inteiro com `KitModular.caixa_cor`. Caixa e
## certa para gondola, balcao e parede; e errada para tudo que no mundo e
## redondo. O vaso sanitario era tres caixas empilhadas, a pia uma coluna
## quadrada com um tampo quadrado, o tambor de oleo um cubo — e na captura do
## MODERNO (captures/mercado_aaa/auditoria/a14_banheiro.png) o banheiro inteiro
## lia como bloco de granito, porque silhueta de caixa nao diz "louca" nem com o
## material certo. O que faz um objeto ler como ele mesmo a um metro e meio e o
## CONTORNO: a curva da bacia, o gargalo da garrafa termica, o cano da torneira.
##
## O PS1 fazia isso com poucos lados — 8 a 12 num objeto de mao, 16 num vaso —
## e sombra por vertice. E o que estas funcoes entregam: silhueta redonda com o
## orcamento de triangulos de uma caixa e meia.
##
## Convencoes
## ----------
## - Tudo escreve em `sup[material]`, no formato de `PSXMesh.dados_vazios`, e
##   roda na thread (so arrays, nenhum servidor de renderizacao).
## - `xf` leva a peca para o lugar. Escala nao uniforme e permitida (a bacia
##   oval do vaso e um torno achatado): a normal vai pela inversa transposta.
## - O Godot desenha a face do lado OPOSTO ao produto vetorial dos dois
##   primeiros lados (memoria "giro de face aponta ao contrario"). Em vez de
##   decorar a ordem de cada malha, todo triangulo aqui e emitido por `_tri`,
##   que confere contra a normal pretendida e vira sozinho quando precisa.
## - UV em METROS (0,5 por metro, como `PSXMesh.DEFAULT_UV_PER_M`): u corre em
##   volta, v corre ao longo. Serve a textura de material (louca, inox,
##   plastico), que e de repeticao.
class_name Peca
extends RefCounted

const UV_POR_M := PSXMesh.DEFAULT_UV_PER_M


# --- base ---------------------------------------------------------------------

static func _dados(sup: Dictionary, material: StringName) -> Dictionary:
	if not sup.has(material):
		sup[material] = PSXMesh.dados_vazios()
	return sup[material]


## Um vertice ja transformado. Devolve o indice.
static func _v(d: Dictionary, p: Vector3, n: Vector3, uv: Vector2, cor: Color) -> int:
	var vs: PackedVector3Array = d["v"]
	var ns: PackedVector3Array = d["n"]
	var uvs: PackedVector2Array = d["uv"]
	var u2: PackedVector2Array = d["uv2"]
	var cs: PackedColorArray = d["c"]
	# A segunda UV acompanha o vertice mesmo sem uso: `PSXMesh.acumular` confia
	# no alinhamento das duas na mesma superficie.
	if u2.size() != vs.size():
		u2.resize(vs.size())
	vs.append(p)
	ns.append(n)
	uvs.append(uv)
	u2.append(Vector2.ZERO)
	cs.append(cor)
	d["v"] = vs
	d["n"] = ns
	d["uv"] = uvs
	d["uv2"] = u2
	d["c"] = cs
	return vs.size() - 1


## Um triangulo virado para `normal`. Degenerado nao entra.
static func _tri(d: Dictionary, a: int, b: int, c: int, normal: Vector3) -> void:
	var vs: PackedVector3Array = d["v"]
	var cruz := (vs[b] - vs[a]).cross(vs[c] - vs[a])
	if cruz.length_squared() < 1e-12:
		return
	var idx: PackedInt32Array = d["i"]
	if cruz.dot(normal) > 0.0:
		idx.append_array(PackedInt32Array([a, c, b]))
	else:
		idx.append_array(PackedInt32Array([a, b, c]))
	d["i"] = idx


static func _normal_de(xf: Transform3D, n: Vector3) -> Vector3:
	var m := xf.basis.inverse().transposed() * n
	return m.normalized() if m.length_squared() > 1e-12 else Vector3.UP


# --- torno --------------------------------------------------------------------

## Superficie de revolucao em torno do eixo Y local.
##
## `perfil`: pontos (raio, y) em ordem. Subindo por fora, a face olha para fora;
## descendo por dentro (a bacia, a cuba), olha para o eixo — a normal sai da
## direcao do percurso, e nao de "fora" fixo. Raio 0 fecha o polo. Um ponto
## REPETIDO e um vinco: dos dois lados dele a normal e a do proprio trecho
## (a borda da cuba, a quina da tampa), e sem repeticao a sombra desliza macia.
##
## `arco`: fracao da volta (1 = inteira). Meia volta faz o assento de frente
## aberta, o cano em U.
static func torno(sup: Dictionary, material: StringName, xf: Transform3D,
		perfil: PackedVector2Array, lados: int, cor: Color, arco: float = 1.0) -> void:
	var d := _dados(sup, material)
	var n := perfil.size()
	if n < 2:
		return
	lados = maxi(3, lados)
	# Normal no plano (raio, y) de cada ponto: media dos trechos vizinhos, a
	# menos que um deles tenha comprimento zero (vinco).
	var normais: Array[Vector2] = []
	var comprimento := PackedFloat32Array()
	var acumulado := 0.0
	for k in n:
		var antes := perfil[k] - perfil[k - 1] if k > 0 else Vector2.ZERO
		var depois := perfil[k + 1] - perfil[k] if k < n - 1 else Vector2.ZERO
		var na := Vector2(antes.y, -antes.x).normalized() if antes.length() > 1e-5 else Vector2.ZERO
		var nd := Vector2(depois.y, -depois.x).normalized() if depois.length() > 1e-5 else Vector2.ZERO
		var nk := na + nd
		if nk.length() < 1e-5:
			nk = na if na != Vector2.ZERO else nd
		normais.append(nk.normalized() if nk.length() > 1e-5 else Vector2(1.0, 0.0))
		if k > 0:
			acumulado += antes.length()
		comprimento.append(acumulado)
	# Um anel por ponto do perfil. Pontos repetidos ganham anel proprio, com a
	# normal do lado dele: e isso que faz o vinco.
	var aneis: Array[PackedInt32Array] = []
	var raio_medio := 0.0
	for p in perfil:
		raio_medio = maxf(raio_medio, p.x)
	var volta := TAU * clampf(arco, 0.01, 1.0)
	var colunas := maxi(2, ceili(float(lados) * clampf(arco, 0.01, 1.0))) + 1
	for k in n:
		var anel := PackedInt32Array()
		for l in colunas:
			var ang := volta * float(l) / float(colunas - 1)
			var dir := Vector3(cos(ang), 0.0, sin(ang))
			var local := dir * perfil[k].x + Vector3(0.0, perfil[k].y, 0.0)
			var nl := dir * normais[k].x + Vector3(0.0, normais[k].y, 0.0)
			var uv := Vector2(ang * raio_medio * UV_POR_M, comprimento[k] * UV_POR_M)
			anel.append(_v(d, xf * local, _normal_de(xf, nl), uv, cor))
		aneis.append(anel)
	for k in n - 1:
		if (perfil[k + 1] - perfil[k]).length() < 1e-5:
			continue
		# Normal do trecho, para o `_tri` escolher o giro.
		var t := perfil[k + 1] - perfil[k]
		var nt := Vector2(t.y, -t.x).normalized()
		for l in colunas - 1:
			var ang := volta * (float(l) + 0.5) / float(colunas - 1)
			var dir := Vector3(cos(ang), 0.0, sin(ang))
			var alvo := _normal_de(xf, dir * nt.x + Vector3(0.0, nt.y, 0.0))
			var a := aneis[k][l]
			var b := aneis[k + 1][l]
			var c := aneis[k][l + 1]
			var e := aneis[k + 1][l + 1]
			_tri(d, a, b, c, alvo)
			_tri(d, c, b, e, alvo)


## Cilindro com tampas. `base` no centro da face de baixo.
static func cilindro(sup: Dictionary, material: StringName, base: Vector3,
		raio: float, altura: float, lados: int, cor: Color,
		tampa_topo: bool = true, tampa_base: bool = false,
		orientacao: Basis = Basis()) -> void:
	var perfil := PackedVector2Array()
	if tampa_base:
		perfil.append_array([Vector2(0.0, 0.0), Vector2(raio, 0.0)])
	perfil.append_array([Vector2(raio, 0.0), Vector2(raio, altura)])
	if tampa_topo:
		perfil.append_array([Vector2(raio, altura), Vector2(0.0, altura)])
	torno(sup, material, Transform3D(orientacao, base), perfil, lados, cor)


## Esfera (ou meia, ou achatada pela `xf`). `aneis` de polo a polo.
static func esfera(sup: Dictionary, material: StringName, xf: Transform3D,
		raio: float, lados: int, aneis: int, cor: Color, so_de_cima: bool = false) -> void:
	var perfil := PackedVector2Array()
	var inicio := aneis / 2 if so_de_cima else 0
	for k in range(inicio, aneis + 1):
		var a := PI * (float(k) / float(aneis)) - PI * 0.5
		perfil.append(Vector2(cos(a) * raio, sin(a) * raio))
	if so_de_cima:
		perfil.insert(0, Vector2(0.0, 0.0))
		perfil.insert(1, Vector2(raio, 0.0))
	torno(sup, material, xf, perfil, lados, cor)


# --- tubo ---------------------------------------------------------------------

## Tubo ao longo de uma polilinha: cano de torneira, alca de cesta, pe de cadeira
## tubular, mangueira. `raios` opcional, um por ponto (o bico que afina).
## `fechar`: tampa as duas pontas.
static func tubo(sup: Dictionary, material: StringName, pontos: PackedVector3Array,
		raio: float, lados: int, cor: Color, fechar: bool = true,
		raios: PackedFloat32Array = PackedFloat32Array()) -> void:
	var d := _dados(sup, material)
	var n := pontos.size()
	if n < 2:
		return
	lados = maxi(3, lados)
	# Referencial transportado ao longo do caminho: sem isso o tubo torce nas
	# curvas e as faces se cruzam.
	var tangentes: Array[Vector3] = []
	for k in n:
		var t: Vector3
		if k == 0:
			t = pontos[1] - pontos[0]
		elif k == n - 1:
			t = pontos[n - 1] - pontos[n - 2]
		else:
			t = (pontos[k] - pontos[k - 1]).normalized() + (pontos[k + 1] - pontos[k]).normalized()
		tangentes.append(t.normalized())
	var ref := Vector3.UP if absf(tangentes[0].dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var normal := (ref - tangentes[0] * ref.dot(tangentes[0])).normalized()
	var aneis: Array[PackedInt32Array] = []
	var percorrido := 0.0
	for k in n:
		var t := tangentes[k]
		normal = (normal - t * normal.dot(t)).normalized()
		var bi := normal.cross(t)
		if k > 0:
			percorrido += pontos[k].distance_to(pontos[k - 1])
		# Na dobra, o anel alarga para a parede do tubo nao afinar no cotovelo.
		var r := raios[k] if k < raios.size() else raio
		if k > 0 and k < n - 1:
			var dobra := (pontos[k] - pontos[k - 1]).normalized().dot(t)
			r /= maxf(0.5, dobra)
		var anel := PackedInt32Array()
		for l in lados + 1:
			var ang := TAU * float(l) / float(lados)
			var dir := normal * cos(ang) + bi * sin(ang)
			anel.append(_v(d, pontos[k] + dir * r, dir,
				Vector2(ang * raio * UV_POR_M, percorrido * UV_POR_M), cor))
		aneis.append(anel)
	var vs: PackedVector3Array = d["v"]
	for k in n - 1:
		for l in lados:
			var a := aneis[k][l]
			var b := aneis[k + 1][l]
			var c := aneis[k][l + 1]
			var e := aneis[k + 1][l + 1]
			var meio := (pontos[k] + pontos[k + 1]) * 0.5
			var alvo := ((vs[a] + vs[e]) * 0.5 - meio).normalized()
			_tri(d, a, b, c, alvo)
			_tri(d, c, b, e, alvo)
	if fechar:
		for ponta: int in [0, n - 1]:
			var fora := -tangentes[0] if ponta == 0 else tangentes[n - 1]
			var centro := _v(d, pontos[ponta], fora, Vector2.ZERO, cor)
			var anel_tampa := PackedInt32Array()
			for l in lados + 1:
				var p: Vector3 = (d["v"] as PackedVector3Array)[aneis[ponta][l]]
				anel_tampa.append(_v(d, p, fora, Vector2.ZERO, cor))
			for l in lados:
				_tri(d, centro, anel_tampa[l], anel_tampa[l + 1], fora)


# --- prisma -------------------------------------------------------------------

## Contorno 2D (x, z) extrudado em Y, de `y0` a `y1`, com tampas.
##
## E a caixa que nao e caixa: tampo de mesa com canto arredondado, caixa
## acoplada do vaso, gabinete de monitor chanfrado, porta de armario com
## quina quebrada. `contorno` em qualquer sentido; nao precisa ser convexo.
static func prisma(sup: Dictionary, material: StringName, xf: Transform3D,
		contorno: PackedVector2Array, y0: float, y1: float, cor: Color,
		tampa_topo: bool = true, tampa_base: bool = true) -> void:
	var d := _dados(sup, material)
	var n := contorno.size()
	if n < 3:
		return
	# Sentido do contorno visto de cima, para saber onde e "fora" de cada lado.
	var area := 0.0
	for k in n:
		var p := contorno[k]
		var q := contorno[(k + 1) % n]
		area += p.x * q.y - q.x * p.y
	var sinal := 1.0 if area > 0.0 else -1.0
	var perimetro := 0.0
	for k in n:
		var p := contorno[k]
		var q := contorno[(k + 1) % n]
		var lado := q - p
		if lado.length() < 1e-5:
			continue
		# Fora: perpendicular ao lado, do lado de fora do contorno.
		# No sentido anti-horario (area > 0) o de dentro fica a esquerda do lado.
		var fora2 := Vector2(lado.y, -lado.x).normalized() * sinal
		var fora := _normal_de(xf, Vector3(fora2.x, 0.0, fora2.y))
		var u0 := perimetro * UV_POR_M
		perimetro += lado.length()
		var u1 := perimetro * UV_POR_M
		var a := _v(d, xf * Vector3(p.x, y0, p.y), fora, Vector2(u0, y0 * UV_POR_M), cor)
		var b := _v(d, xf * Vector3(q.x, y0, q.y), fora, Vector2(u1, y0 * UV_POR_M), cor)
		var c := _v(d, xf * Vector3(p.x, y1, p.y), fora, Vector2(u0, y1 * UV_POR_M), cor)
		var e := _v(d, xf * Vector3(q.x, y1, q.y), fora, Vector2(u1, y1 * UV_POR_M), cor)
		_tri(d, a, b, c, fora)
		_tri(d, c, b, e, fora)
	var tris := Geometry2D.triangulate_polygon(contorno)
	for tampa: int in [0, 1]:
		if (tampa == 0 and not tampa_base) or (tampa == 1 and not tampa_topo):
			continue
		var y := y1 if tampa == 1 else y0
		var nl := _normal_de(xf, Vector3.UP if tampa == 1 else Vector3.DOWN)
		var ids := PackedInt32Array()
		for p in contorno:
			ids.append(_v(d, xf * Vector3(p.x, y, p.y), nl, p * UV_POR_M, cor))
		for k in range(0, tris.size(), 3):
			_tri(d, ids[tris[k]], ids[tris[k + 1]], ids[tris[k + 2]], nl)


## Retangulo de `tam` (x, z) com os quatro cantos arredondados em `raio`, em
## `passos` segmentos por canto (1 = chanfro reto). Centrado na origem.
static func retangulo_redondo(tam: Vector2, raio: float, passos: int = 3) -> PackedVector2Array:
	var saida := PackedVector2Array()
	raio = clampf(raio, 0.0, minf(tam.x, tam.y) * 0.5 - 0.001)
	var meio := tam * 0.5 - Vector2(raio, raio)
	var cantos := [Vector2(meio.x, meio.y), Vector2(-meio.x, meio.y),
		Vector2(-meio.x, -meio.y), Vector2(meio.x, -meio.y)]
	for k in 4:
		var c: Vector2 = cantos[k]
		for s in passos + 1:
			var ang := PI * 0.5 * float(k) + PI * 0.5 * float(s) / float(passos)
			saida.append(c + Vector2(cos(ang), sin(ang)) * raio)
	return saida


## Caixa com as arestas verticais arredondadas (ou chanfradas, com `passos` 1).
## `centro` no meio da caixa, como `KitModular.caixa_cor`.
static func caixa_redonda(sup: Dictionary, material: StringName, centro: Vector3,
		tam: Vector3, raio: float, cor: Color, giro: float = 0.0,
		passos: int = 2) -> void:
	prisma(sup, material, Transform3D(Basis(Vector3.UP, giro), centro),
		retangulo_redondo(Vector2(tam.x, tam.z), raio, passos),
		-tam.y * 0.5, tam.y * 0.5, cor)


## Elipse de `semi` (x, z) em `lados` pontos.
static func elipse(semi: Vector2, lados: int) -> PackedVector2Array:
	var saida := PackedVector2Array()
	for k in lados:
		var ang := TAU * float(k) / float(lados)
		saida.append(Vector2(cos(ang) * semi.x, sin(ang) * semi.y))
	return saida


## Quantos triangulos ha em `sup` (todas as superficies). Para a bancada e o
## orcamento de cada peca.
static func triangulos(sup: Dictionary) -> int:
	var t := 0
	for m: StringName in sup:
		t += (sup[m]["i"] as PackedInt32Array).size() / 3
	return t
