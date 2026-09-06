## Construtor de malha que respeita o contrato PSX.
##
## Existe por causa de uma consequencia obrigatoria da UV afim: a distorcao cresce
## com o tamanho do poligono, entao chao e parede tem que vir subdivididos em quads
## de no maximo 2 m. Um plano de 12 m sem subdivisao nao fica retro, fica ilegivel.
## Ver docs/ART-BIBLE.md secao 4.
##
## Toda funcao vem em dois niveis. As `*_dados` devolvem dicionario de arrays
## puros, sem tocar no servidor de renderizacao, e por isso podem rodar em thread.
## As que devolvem ArrayMesh sao acucar por cima delas e so valem na thread
## principal. O streaming da Fase 3 depende dessa separacao: o custo pesado, que e
## gerar e fundir vertices, sai da thread principal, e so a criacao da malha final
## fica nela.
class_name PSXMesh
extends RefCounted

## ART-BIBLE secao 4 — lado maximo de um quad de superficie, em metros
const MAX_QUAD_M := 2.0

## Uma repeticao de textura a cada 2 m, que casa com a grade do kit modular.
const DEFAULT_UV_PER_M := 0.5


# --- nivel de dados ---------------------------------------------------------

static func dados_vazios() -> Dictionary:
	return {
		"v": PackedVector3Array(),
		"n": PackedVector3Array(),
		"uv": PackedVector2Array(),
		"c": PackedColorArray(),
		"i": PackedInt32Array(),
	}


## Plano subdividido no plano XY, virado para +Z, centrado na origem.
static func plane_dados(
	size: Vector2,
	uv_per_meter: float = DEFAULT_UV_PER_M,
	max_quad: float = MAX_QUAD_M,
	color: Color = Color.WHITE
) -> Dictionary:
	var cols := maxi(1, ceili(size.x / max_quad))
	var rows := maxi(1, ceili(size.y / max_quad))
	var d := dados_vazios()
	var verts: PackedVector3Array = d["v"]
	var norms: PackedVector3Array = d["n"]
	var uvs: PackedVector2Array = d["uv"]
	var cores: PackedColorArray = d["c"]
	var idx: PackedInt32Array = d["i"]

	var half := size * 0.5
	for r in rows + 1:
		for c in cols + 1:
			var px := -half.x + size.x * (float(c) / float(cols))
			var py := -half.y + size.y * (float(r) / float(rows))
			verts.append(Vector3(px, py, 0.0))
			norms.append(Vector3(0.0, 0.0, 1.0))
			# UV ancorada no canto, nao no centro, para tiles casarem entre modulos
			uvs.append(Vector2((px + half.x) * uv_per_meter, (half.y - py) * uv_per_meter))
			cores.append(color)

	var stride := cols + 1
	for r in rows:
		for c in cols:
			var a := r * stride + c
			idx.append_array([a, a + stride, a + 1,
				a + 1, a + stride, a + stride + 1])

	d["v"] = verts
	d["n"] = norms
	d["uv"] = uvs
	d["c"] = cores
	d["i"] = idx
	return d


## Bits de face para `box_dados`. Face que nunca e vista nao precisa existir.
const FACE_FRENTE := 1   ## +Z
const FACE_TRAS := 2     ## -Z
const FACE_DIR := 4      ## +X
const FACE_ESQ := 8      ## -X
const FACE_TOPO := 16    ## +Y
const FACE_BASE := 32    ## -Y
const FACE_TODAS := 63


## Caixa, cada face subdividida. `faces` corta as que ficam enterradas.
##
## Um predio encostado no vizinho nunca mostra a face de tras nem a base. Gerar
## essas faces custa um terco dos triangulos do volume e nao aparece em nada, o
## que num orcamento de 6000 por chunk faz diferenca real.
static func box_dados(
	size: Vector3,
	uv_per_meter: float = DEFAULT_UV_PER_M,
	max_quad: float = MAX_QUAD_M,
	color: Color = Color.WHITE,
	faces: int = FACE_TODAS
) -> Dictionary:
	var half := size * 0.5
	var lista: Array[Array] = [
		[FACE_FRENTE, Vector2(size.x, size.y), Transform3D(Basis(), Vector3(0, 0, half.z))],
		[FACE_TRAS, Vector2(size.x, size.y), Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -half.z))],
		[FACE_DIR, Vector2(size.z, size.y), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(half.x, 0, 0))],
		[FACE_ESQ, Vector2(size.z, size.y), Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-half.x, 0, 0))],
		[FACE_TOPO, Vector2(size.x, size.z), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, half.y, 0))],
		[FACE_BASE, Vector2(size.x, size.z), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -half.y, 0))],
	]
	var d := dados_vazios()
	for face: Array in lista:
		if faces & int(face[0]) == 0:
			continue
		acumular(d, plane_dados(face[1], uv_per_meter, max_quad, color), face[2])
	return d


## Tronco de cone aberto, sem tampas, para o facho de luz sob uma lampada.
##
## O ART-BIBLE secao 8 proibe nevoa volumetrica com raymarch, e a proibicao segue
## valendo. Isto nao e raymarch: e geometria translucida somada por cima da cena,
## que e o que o PS1 fazia, e por isso o facho aparece facetado.
static func cone_dados(
	raio_topo: float,
	raio_base: float,
	altura: float,
	lados: int = 8,
	aneis: int = 3,
	cor_topo: Color = Color(1.0, 1.0, 1.0, 1.0),
	cor_base: Color = Color(1.0, 1.0, 1.0, 0.0)
) -> Dictionary:
	lados = maxi(3, lados)
	aneis = maxi(1, aneis)
	var d := dados_vazios()
	var verts: PackedVector3Array = d["v"]
	var norms: PackedVector3Array = d["n"]
	var uvs: PackedVector2Array = d["uv"]
	var cores: PackedColorArray = d["c"]
	var idx: PackedInt32Array = d["i"]

	for a in aneis + 1:
		var t := float(a) / float(aneis)
		var raio := lerpf(raio_topo, raio_base, t)
		# Alfa cai com o quadrado: luz espalhada perde intensidade rapido perto
		# da fonte e devagar longe dela, e linear le como cone de papel.
		var cor := cor_topo.lerp(cor_base, t * t)
		for l in lados + 1:
			var ang := TAU * float(l) / float(lados)
			var dir := Vector3(cos(ang), 0.0, sin(ang))
			verts.append(dir * raio + Vector3(0.0, -altura * t, 0.0))
			norms.append(dir)
			uvs.append(Vector2(float(l) / float(lados), t))
			cores.append(cor)

	var passo := lados + 1
	for a in aneis:
		for l in lados:
			var v0 := a * passo + l
			idx.append_array([v0, v0 + passo, v0 + 1,
				v0 + 1, v0 + passo, v0 + passo + 1])

	d["v"] = verts
	d["n"] = norms
	d["uv"] = uvs
	d["c"] = cores
	d["i"] = idx
	return d


## Junta `fonte` dentro de `destino`, aplicando a transformacao.
##
## E o coracao da fusao por material. Um chunk com sessenta pecas vira um punhado
## de malhas em vez de sessenta MeshInstance3D, o que e a diferenca entre caber e
## nao caber no teto de draw calls do ART-BIBLE secao 10.
static func acumular(destino: Dictionary, fonte: Dictionary, xform: Transform3D) -> void:
	var dv: PackedVector3Array = destino["v"]
	var dn: PackedVector3Array = destino["n"]
	var duv: PackedVector2Array = destino["uv"]
	var dc: PackedColorArray = destino["c"]
	var di: PackedInt32Array = destino["i"]

	var base := dv.size()
	var fv: PackedVector3Array = fonte["v"]
	var fn: PackedVector3Array = fonte["n"]
	var basis := xform.basis

	for k in fv.size():
		dv.append(xform * fv[k])
		dn.append((basis * fn[k]).normalized())

	duv.append_array(fonte["uv"])
	dc.append_array(fonte["c"])

	var fi: PackedInt32Array = fonte["i"]
	for k in fi.size():
		di.append(fi[k] + base)

	destino["v"] = dv
	destino["n"] = dn
	destino["uv"] = duv
	destino["c"] = dc
	destino["i"] = di


static func dados_vazio(d: Dictionary) -> bool:
	return (d["i"] as PackedInt32Array).is_empty()


static func dados_triangulos(d: Dictionary) -> int:
	return (d["i"] as PackedInt32Array).size() / 3


# --- nivel de recurso, so na thread principal -------------------------------

## Converte dados em ArrayMesh. Toca o servidor de renderizacao, entao nunca
## chame de dentro de uma thread de trabalho.
static func dados_para_mesh(d: Dictionary) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = d["v"]
	arrays[Mesh.ARRAY_NORMAL] = d["n"]
	arrays[Mesh.ARRAY_TEX_UV] = d["uv"]
	arrays[Mesh.ARRAY_COLOR] = d["c"]
	arrays[Mesh.ARRAY_INDEX] = d["i"]

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func plane(
	size: Vector2,
	uv_per_meter: float = DEFAULT_UV_PER_M,
	max_quad: float = MAX_QUAD_M,
	color: Color = Color.WHITE
) -> ArrayMesh:
	return dados_para_mesh(plane_dados(size, uv_per_meter, max_quad, color))


static func box(
	size: Vector3,
	uv_per_meter: float = DEFAULT_UV_PER_M,
	max_quad: float = MAX_QUAD_M,
	color: Color = Color.WHITE,
	faces: int = FACE_TODAS
) -> ArrayMesh:
	return dados_para_mesh(box_dados(size, uv_per_meter, max_quad, color, faces))


static func cone(
	raio_topo: float,
	raio_base: float,
	altura: float,
	lados: int = 8,
	aneis: int = 3,
	cor_topo: Color = Color(1.0, 1.0, 1.0, 1.0),
	cor_base: Color = Color(1.0, 1.0, 1.0, 0.0)
) -> ArrayMesh:
	return dados_para_mesh(
		cone_dados(raio_topo, raio_base, altura, lados, aneis, cor_topo, cor_base))


## Numero de triangulos de uma malha, para conferir budget do ART-BIBLE secao 10.
static func triangle_count(mesh: Mesh) -> int:
	var total := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		total += indices.size() / 3 if not indices.is_empty() \
			else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total
