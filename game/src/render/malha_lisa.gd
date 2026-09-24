## Malha de peca lisa, montada em codigo: caixa de quina redonda, torno, tubo,
## grade de pontos com normal suave e tampa plana.
##
## Por que existe
## --------------
## O interior do carro era feito com `AtlasKit.caixa` e `AtlasKit.face`: caixa de
## quina viva e placa com a peca desenhada na celula do atlas. A 480x270 isso le;
## em 4K, a meio metro da lente, painel de caixa e botao de pixel leem como
## brinquedo. `VolanteEsportivo` resolveu o volante com uma malha propria de
## volta suave, e esta classe e a mesma ferramenta, aberta para o resto da
## cabine — painel, cluster, radio, console, alavanca.
##
## A regra do giro
## ---------------
## Cada vertice nasce com a normal certa, e o triangulo e virado A PARTIR DELA:
## o produto vetorial aponta contra a normal, que e o lado em que a face aparece
## neste projeto (ver a memoria "giro de face aponta ao contrario"). Quem monta
## peca nunca escolhe a ordem dos indices; escolhe para onde a peca olha.
##
## Espaco
## ------
## `xf` e aplicado a todo vertice emitido: a peca e desenhada em volta da propria
## origem, e `xf` a leva para o lugar. So rotacao, translacao e escala uniforme —
## com escala nao uniforme a normal precisaria da inversa transposta.
class_name MalhaLisa
extends RefCounted

var v := PackedVector3Array()
var n := PackedVector3Array()
var uv := PackedVector2Array()
var uv2 := PackedVector2Array()
var c := PackedColorArray()
var i := PackedInt32Array()
## Onde a peca em construcao vai parar. Ver o cabecalho.
var xf := Transform3D.IDENTITY


func vazia() -> bool:
	return i.is_empty()


## Um vertice. `t2` e o segundo UV, que alguns materiais usam como mascara;
## (-1, 0) e o "nada" que todo shader desta cabine entende.
func vertice(p: Vector3, nn: Vector3, t: Vector2 = Vector2.ZERO,
		cor: Color = Color.WHITE, t2: Vector2 = Vector2(-1.0, 0.0)) -> int:
	v.append(xf * p)
	n.append((xf.basis * nn).normalized())
	uv.append(t)
	uv2.append(t2)
	c.append(cor)
	return v.size() - 1


func tri(a: int, b: int, c_: int) -> void:
	var fn := (v[b] - v[a]).cross(v[c_] - v[a])
	if fn.length_squared() < 1e-18:
		return
	if fn.dot(n[a] + n[b] + n[c_]) > 0.0:
		i.append_array([a, c_, b])
	else:
		i.append_array([a, b, c_])


## Costura linhas de indices em quads.
func grade(linhas: Array) -> void:
	for k in linhas.size() - 1:
		var l0: PackedInt32Array = linhas[k]
		var l1: PackedInt32Array = linhas[k + 1]
		for j in mini(l0.size(), l1.size()) - 1:
			tri(l0[j], l1[j], l0[j + 1])
			tri(l0[j + 1], l1[j], l1[j + 1])


## Um quad plano, com a mesma normal nos quatro cantos.
func quad(a: Vector3, b: Vector3, c_: Vector3, d: Vector3, nn: Vector3,
		cor: Color = Color.WHITE, t2: Vector2 = Vector2(-1.0, 0.0)) -> void:
	var ia := vertice(a, nn, Vector2(0, 0), cor, t2)
	var ib := vertice(b, nn, Vector2(1, 0), cor, t2)
	var ic := vertice(c_, nn, Vector2(1, 1), cor, t2)
	var id := vertice(d, nn, Vector2(0, 1), cor, t2)
	tri(ia, ib, ic)
	tri(ia, ic, id)


## Um retangulo no plano XY de `onde`, olhando para +Z, com a UV esticada
## sobre `r_uv` (a regiao da folha, 0..1, com y da imagem para baixo).
func placa(onde: Transform3D, meia: Vector2, r_uv: Rect2,
		cor: Color = Color.WHITE, t2: Vector2 = Vector2(-1.0, 0.0)) -> void:
	var guarda := xf
	xf = xf * onde
	var a := vertice(Vector3(-meia.x, meia.y, 0.0), Vector3.BACK,
		r_uv.position, cor, t2)
	var b := vertice(Vector3(meia.x, meia.y, 0.0), Vector3.BACK,
		r_uv.position + Vector2(r_uv.size.x, 0.0), cor, t2)
	var c_ := vertice(Vector3(meia.x, -meia.y, 0.0), Vector3.BACK,
		r_uv.end, cor, t2)
	var d := vertice(Vector3(-meia.x, -meia.y, 0.0), Vector3.BACK,
		r_uv.position + Vector2(0.0, r_uv.size.y), cor, t2)
	tri(a, b, c_)
	tri(a, c_, d)
	xf = guarda


## Um disco no plano XY de `onde`, olhando para +Z, com a UV de `r_uv` em volta
## do centro dela. `frac` e quanto do meio-lado da regiao o raio do disco cobre:
## o mostrador desenhado na folha nao encosta na borda da regiao.
func disco(onde: Transform3D, r: float, r_uv: Rect2, cor: Color = Color.WHITE,
		lados: int = 48, frac: float = 1.0) -> void:
	var guarda := xf
	xf = xf * onde
	var cuv := r_uv.get_center()
	var meio := r_uv.size * 0.5 * frac
	var centro := vertice(Vector3.ZERO, Vector3.BACK, cuv, cor)
	var anel := PackedInt32Array()
	for k in lados + 1:
		var a := TAU * float(k) / float(lados)
		anel.append(vertice(Vector3(cos(a), sin(a), 0.0) * r, Vector3.BACK,
			cuv + Vector2(cos(a), -sin(a)) * meio, cor))
	for k in lados:
		tri(centro, anel[k], anel[k + 1])
	xf = guarda


## Um poligono plano (tampa de peca varrida), triangulado no proprio plano.
## Os pontos podem vir em qualquer sentido; `nn` diz para onde a tampa olha.
func poligono(pontos: PackedVector3Array, nn: Vector3,
		cor: Color = Color.WHITE) -> void:
	if pontos.size() < 3:
		return
	var eixo_u := (pontos[1] - pontos[0]).normalized()
	if absf(eixo_u.dot(nn)) > 0.9 or eixo_u.length_squared() < 0.5:
		eixo_u = nn.cross(Vector3.UP if absf(nn.y) < 0.9 else Vector3.RIGHT)
	eixo_u = (eixo_u - nn * eixo_u.dot(nn)).normalized()
	var eixo_v := nn.cross(eixo_u).normalized()
	var plano := PackedVector2Array()
	for p: Vector3 in pontos:
		plano.append(Vector2(p.dot(eixo_u), p.dot(eixo_v)))
	var tris := Geometry2D.triangulate_polygon(plano)
	if tris.is_empty():
		return
	var base := v.size()
	for p: Vector3 in pontos:
		vertice(p, nn, Vector2(p.dot(eixo_u), p.dot(eixo_v)), cor)
	for k in range(0, tris.size(), 3):
		tri(base + tris[k], base + tris[k + 1], base + tris[k + 2])


## Grade de pontos com normal suave, tirada das diferencas entre vizinhos e
## virada para longe de `dentro` (um ponto no miolo da peca, ou um Callable
## `(linha, coluna) -> Vector3` quando a peca e comprida ou curva demais para
## um miolo so).
##
## E o "loft" da cabine: o painel inteiro e uma grade destas, cada linha uma
## secao atravessando o carro.
func grade_de_pontos(linhas: Array, cor: Color, dentro: Variant,
		cores: Array = []) -> void:
	var nl := linhas.size()
	if nl < 2:
		return
	var idx: Array = []
	for k in nl:
		var la: PackedVector3Array = linhas[k]
		var linha := PackedInt32Array()
		var cor_k: Color = cores[k] if k < cores.size() else cor
		for j in la.size():
			var p := la[j]
			var ka: PackedVector3Array = linhas[maxi(k - 1, 0)]
			var kb: PackedVector3Array = linhas[mini(k + 1, nl - 1)]
			var d1 := kb[j] - ka[j]
			var d2 := la[mini(j + 1, la.size() - 1)] - la[maxi(j - 1, 0)]
			var miolo: Vector3 = (dentro as Callable).call(k, j) if dentro is Callable \
				else dentro
			var nn := d1.cross(d2)
			if nn.length_squared() < 1e-14:
				nn = p - miolo
			nn = nn.normalized()
			if nn.dot(p - miolo) < 0.0:
				nn = -nn
			linha.append(vertice(p, nn, Vector2(float(j), float(k)), cor_k))
		idx.append(linha)
	grade(idx)


## Caixa de quinas redondas: `meia` e a meia medida, `raio` o raio da quina.
##
## Cada face e uma grade que concentra pontos nas quinas, projetada sobre a
## forma: o miolo fica plano e a borda vira um quarto de cilindro com a normal
## certa. Um bevel so de tres passos ja pega o brilho da quina, que e o que
## separa peca de plastico injetado de caixa de papelao.
##
## `inchar` estufa a face de +Y como almofada: o meio sobe `inchar` metros e a
## borda fica onde estava, com a normal inclinada pela derivada do inchaco. E o
## que separa almofada de tijolo. `passos` subdivide o miolo plano para o
## inchaco ter vertice onde curvar.
func caixa(centro: Vector3, meia: Vector3, raio: float,
		cor: Color = Color.WHITE, base: Basis = Basis(), seg: int = 3,
		inchar: float = 0.0, passos: int = 0) -> void:
	var r := minf(raio, minf(meia.x, minf(meia.y, meia.z)) * 0.999)
	# Quina pequena, poucos passos: um quarto de volta de 1 mm com quatro passos
	# e triangulo que nenhuma tela mostra. Um passo a cada 2,5 mm de raio.
	seg = clampi(ceili(r / 0.0025), 1, seg)
	var nucleo := meia - Vector3.ONE * r
	var eixos := [meia.x, meia.y, meia.z]
	var coords: Array = []
	for e in 3:
		coords.append(_coordenadas_de_borda(float(eixos[e]), r, seg, passos))
	var guarda := xf
	xf = xf * Transform3D(base, centro)
	for eixo in 3:
		for s: float in [-1.0, 1.0]:
			var a := (eixo + 1) % 3
			var b := (eixo + 2) % 3
			var ca: PackedFloat32Array = coords[a]
			var cb: PackedFloat32Array = coords[b]
			var linhas: Array = []
			for ia in ca.size():
				var linha := PackedInt32Array()
				for ib in cb.size():
					var p := Vector3.ZERO
					p[eixo] = s * float(eixos[eixo])
					p[a] = ca[ia]
					p[b] = cb[ib]
					var q := p.clamp(-nucleo, nucleo)
					var d := p - q
					var nn := Vector3.ZERO
					nn[eixo] = s
					if d.length_squared() > 1e-12:
						nn = d.normalized()
						p = q + nn * r
					if inchar != 0.0 and nn.y > 0.0:
						var ux := clampf(p.x / meia.x, -1.0, 1.0)
						var uz := clampf(p.z / meia.z, -1.0, 1.0)
						var fx := 1.0 - ux * ux
						var fz := 1.0 - uz * uz
						var peso := nn.y
						p.y += inchar * fx * fz * peso
						var gx := inchar * (-2.0 * ux / meia.x) * fz * peso
						var gz := inchar * (-2.0 * uz / meia.z) * fx * peso
						nn = (nn + Vector3(-gx, 0.0, -gz)).normalized()
					linha.append(vertice(p, nn, Vector2(p[a], p[b]), cor))
				linhas.append(linha)
			grade(linhas)
	xf = guarda


static func _coordenadas_de_borda(h: float, r: float, seg: int,
		passos: int = 0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if r <= 1e-5:
		out.append(-h)
		for k in range(1, passos + 1):
			out.append(lerpf(-h, h, float(k) / float(passos + 1)))
		out.append(h)
		return out
	for k in seg + 1:
		var fi := PI * 0.5 * (1.0 - float(k) / float(seg))
		out.append(-h + r - r * sin(fi))
	if h - r > 1e-5:
		for k in range(1, passos + 1):
			out.append(lerpf(-h + r, h - r, float(k) / float(passos + 1)))
		for k in seg + 1:
			var fi := PI * 0.5 * float(k) / float(seg)
			out.append(h - r + r * sin(fi))
	else:
		for k in range(1, seg + 1):
			var fi := PI * 0.5 * float(k) / float(seg)
			out.append(h - r + r * sin(fi))
	return out


## Superficie de revolucao em volta do eixo Z local de `onde`. O perfil e uma
## lista de (raio, z) percorrida do eixo em CIMA (+z) para fora e para baixo,
## como o `_torno` do volante: nesse sentido a normal (-dz, dr) aponta para fora
## da peca — para cima no disco de cima, para fora na parede, para baixo no
## disco de baixo. Perfil ao contrario sai com a peca do avesso.
## `ang0`/`ang1` abrem um arco em vez da volta inteira.
func torno(onde: Transform3D, perfil: Array, cor: Color = Color.WHITE,
		lados: int = 32, ang0: float = 0.0, ang1: float = TAU,
		t2: Vector2 = Vector2(-1.0, 0.0)) -> void:
	var guarda := xf
	xf = xf * onde
	# Os lados pelo tamanho da peca: um lado a cada 3 mm de volta, entre 10 e o
	# pedido. Um parafuso de 4 mm com 48 lados eram 48 triangulos por anel que
	# viravam o mesmo pixel.
	var r_max := 0.0
	for q: Vector2 in perfil:
		r_max = maxf(r_max, q.x)
	var arco := absf(ang1 - ang0)
	lados = clampi(ceili(r_max * arco / 0.003), 10, lados)
	var np := perfil.size()
	var normais: Array[Vector2] = []
	for k in np:
		var a: Vector2 = perfil[maxi(k - 1, 0)]
		var b: Vector2 = perfil[mini(k + 1, np - 1)]
		var t := b - a
		normais.append(Vector2(-t.y, t.x).normalized())
	var linhas: Array = []
	for j in lados + 1:
		var fi := lerpf(ang0, ang1, float(j) / float(lados))
		var co := cos(fi)
		var si := sin(fi)
		var linha := PackedInt32Array()
		for k in np:
			var p: Vector2 = perfil[k]
			var nn: Vector2 = normais[k]
			var n3 := Vector3(nn.x * co, nn.x * si, nn.y).normalized()
			if p.x < 1e-5:
				n3 = Vector3(0.0, 0.0, signf(nn.y) if absf(nn.y) > 1e-4 else 1.0)
			linha.append(vertice(Vector3(p.x * co, p.x * si, p.y), n3,
				Vector2(fi / TAU, float(k) / float(maxi(np - 1, 1))), cor, t2))
		linhas.append(linha)
	grade(linhas)
	xf = guarda


## Tubo ao longo de uma linha de pontos, com o referencial transportado de um
## ponto ao seguinte (sem torcer). `raios` pode ter um raio por ponto ou um so.
func tubo(pontos: PackedVector3Array, raios: PackedFloat32Array,
		cor: Color = Color.WHITE, lados: int = 12, tampar: bool = true) -> void:
	var np := pontos.size()
	if np < 2:
		return
	var tangentes: Array[Vector3] = []
	for k in np:
		var a := pontos[maxi(k - 1, 0)]
		var b := pontos[mini(k + 1, np - 1)]
		tangentes.append((b - a).normalized())
	var t0: Vector3 = tangentes[0]
	var ref := Vector3.UP if absf(t0.y) < 0.9 else Vector3.RIGHT
	var u := t0.cross(ref).normalized()
	var linhas: Array = []
	for k in np:
		var t: Vector3 = tangentes[k]
		u = (u - t * u.dot(t)).normalized()
		var w := t.cross(u)
		var r := raios[mini(k, raios.size() - 1)]
		var linha := PackedInt32Array()
		for j in lados + 1:
			var fi := TAU * float(j) / float(lados)
			var nn := u * cos(fi) + w * sin(fi)
			linha.append(vertice(pontos[k] + nn * r, nn,
				Vector2(float(j) / float(lados), float(k)), cor))
		linhas.append(linha)
	grade(linhas)
	if not tampar:
		return
	for ponta: int in [0, np - 1]:
		var t: Vector3 = tangentes[ponta] * (-1.0 if ponta == 0 else 1.0)
		var anel := PackedVector3Array()
		var l: PackedInt32Array = linhas[ponta]
		for j in lados:
			anel.append(xf.affine_inverse() * v[l[j]])
		poligono(anel, t, cor)


## Os arrays da superficie, no formato de `add_surface_from_arrays`. Vazia
## devolve vazio. Quem guarda malha para montar de novo guarda isto, e nao o
## `ArrayMesh`: malha compartilhada e malha que o amassado de um carro deforma
## em todos.
func arrays() -> Array:
	if i.is_empty():
		return []
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = i
	return arrays


## A malha pronta. Vazia devolve nulo.
func malha() -> ArrayMesh:
	if i.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = i
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## Pendura a malha em `pai`, com o material. Devolve o no, ou nulo se vazia.
func por(pai: Node3D, nome: String, mat: Material,
		sombra: bool = false) -> MeshInstance3D:
	var m := malha()
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sombra \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	return mi
