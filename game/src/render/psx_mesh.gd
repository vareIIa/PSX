## Construtor de malha que respeita o contrato PSX.
##
## Existe por causa de uma consequencia obrigatoria da UV afim: a distorcao cresce
## com o tamanho do poligono, entao chao e parede tem que vir subdivididos em quads
## de no maximo 2 m. Um plano de 12 m sem subdivisao nao fica retro, fica ilegivel.
## Ver docs/ART-BIBLE.md secao 4.
##
## Toda geometria do kit modular da Fase 3 vai sair daqui, entao a regra fica
## garantida por construcao em vez de por disciplina.
class_name PSXMesh
extends RefCounted

## ART-BIBLE secao 4 — lado maximo de um quad de superficie, em metros
const MAX_QUAD_M := 2.0

## Uma repeticao de textura a cada 2 m, que casa com a grade do kit modular.
const DEFAULT_UV_PER_M := 0.5


## Plano subdividido no plano XY, virado para +Z, centrado na origem.
## Use Transform3D para posicionar e girar.
static func plane(
	size: Vector2,
	uv_per_meter: float = DEFAULT_UV_PER_M,
	max_quad: float = MAX_QUAD_M,
	color: Color = Color.WHITE
) -> ArrayMesh:
	var cols := maxi(1, ceili(size.x / max_quad))
	var rows := maxi(1, ceili(size.y / max_quad))

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()

	var half := size * 0.5
	for r in rows + 1:
		for c in cols + 1:
			var px := -half.x + size.x * (float(c) / float(cols))
			var py := -half.y + size.y * (float(r) / float(rows))
			verts.append(Vector3(px, py, 0.0))
			norms.append(Vector3(0.0, 0.0, 1.0))
			# UV ancorada no canto, nao no centro, para tiles casarem entre modulos
			uvs.append(Vector2((px + half.x) * uv_per_meter, (half.y - py) * uv_per_meter))
			colors.append(color)

	var stride := cols + 1
	for r in rows:
		for c in cols:
			var a := r * stride + c
			var b := a + 1
			var d := a + stride
			var e := d + 1
			idx.append_array([a, d, b, b, d, e])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Caixa fechada, cada face subdividida. Para prop e volume solido.
static func box(
	size: Vector3,
	uv_per_meter: float = DEFAULT_UV_PER_M,
	max_quad: float = MAX_QUAD_M,
	color: Color = Color.WHITE
) -> ArrayMesh:
	var half := size * 0.5
	# face: tamanho do plano, e transform que o leva para o lugar
	var faces: Array[Array] = [
		[Vector2(size.x, size.y), Transform3D(Basis(), Vector3(0, 0, half.z))],
		[Vector2(size.x, size.y), Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -half.z))],
		[Vector2(size.z, size.y), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(half.x, 0, 0))],
		[Vector2(size.z, size.y), Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-half.x, 0, 0))],
		[Vector2(size.x, size.z), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, half.y, 0))],
		[Vector2(size.x, size.z), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -half.y, 0))],
	]

	var mesh := ArrayMesh.new()
	for face: Array in faces:
		_append_transformed(mesh, plane(face[0], uv_per_meter, max_quad, color), face[1])
	return mesh


## Numero de triangulos de uma malha, para conferir budget do ART-BIBLE secao 10.
static func triangle_count(mesh: Mesh) -> int:
	var total := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		total += indices.size() / 3 if not indices.is_empty() \
			else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


static func _append_transformed(target: ArrayMesh, source: ArrayMesh, xform: Transform3D) -> void:
	var arrays := source.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]

	for i in verts.size():
		verts[i] = xform * verts[i]
		norms[i] = (xform.basis * norms[i]).normalized()

	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
