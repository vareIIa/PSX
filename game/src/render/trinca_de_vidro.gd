## A trinca de um vidro do carro, vista de dentro (`psx_trinca_vidro`).
##
## A lamina e o PROPRIO contorno da janela (`Carroceria.montar` -> `aberturas`),
## quatro milimetros para dentro do vidro, e nao um quadrado colado nele: a
## trinca chega ate a borda da borracha e para nela, como no vidro de verdade,
## sem um retangulo sobrando para fora da janela.
##
## A UV e em METROS no plano do vidro, com +y para cima: o shader mede raio e
## espessura de fio em metros, e o mesmo desenho serve ao para-brisa e a uma
## janela de porta sem esticar.
class_name TrincaDeVidro
extends MeshInstance3D

const SHADER := "res://shaders/psx_trinca_vidro.gdshader"
## Quanto para dentro do vidro a lamina fica, em metros: o vidro da cabine
## (`VidroCabine`) mora a 4 mm, e a lamina fica logo atras dele, do lado do
## motorista — nos mesmos 4 mm os dois brigariam pelo pixel.
const PARA_DENTRO := 0.008

## Quantas radiais (no maximo 32, o tamanho dos vetores do shader).
const RADIAIS := 23

var _mat: ShaderMaterial
var _cresce: float = 0.0
var _alcance: float = 0.55
## O plano do vidro, no espaco do carro: origem, u deitado, v para cima.
var _o := Vector3.ZERO
var _u := Vector3.RIGHT
var _v := Vector3.UP
var impacto := Vector3.ZERO
## Por radial: angulo (rad, no plano u-v), comprimento (fracao do alcance) e
## atraso (fracao do crescer em que ela parte).
var angulos := PackedFloat32Array()
var comprimentos := PackedFloat32Array()
var atrasos := PackedFloat32Array()


## Monta a trinca na abertura `a` (espaco do carro), com a pancada em `onde`
## (espaco do carro; e projetado no vidro).
static func na_abertura(a: Dictionary, onde: Vector3, semente: float = 7.0) -> TrincaDeVidro:
	var contorno: PackedVector3Array = a.get("contorno", a.get("pontos", PackedVector3Array()))
	var n: Vector3 = a.get("normal", Vector3.ZERO)
	if contorno.size() < 3 or n.length_squared() < 0.5:
		return null
	var t := TrincaDeVidro.new()
	t.name = "Trinca_%s" % String(a.get("tipo", &"vidro"))
	t._montar(contorno, n.normalized(), onde, semente)
	return t


func _montar(contorno: PackedVector3Array, n: Vector3, onde: Vector3, semente: float) -> void:
	# A base do plano: v sobe (o "cima" projetado no vidro), u deitado nele.
	var v := (Vector3.UP - n * n.dot(Vector3.UP))
	if v.length_squared() < 1e-4:
		v = Vector3.FORWARD - n * n.dot(Vector3.FORWARD)
	v = v.normalized()
	var u := v.cross(n).normalized()
	var o := contorno[0]
	var pts2 := PackedVector2Array()
	for p: Vector3 in contorno:
		pts2.append(Vector2((p - o).dot(u), (p - o).dot(v)))
	var tris := Geometry2D.triangulate_polygon(pts2)
	if tris.is_empty():
		# Contorno com a volta ao contrario: a triangulacao quer anti-horario.
		pts2.reverse()
		contorno = contorno.duplicate()
		contorno.reverse()
		tris = Geometry2D.triangulate_polygon(pts2)
	var vs := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i: int in tris:
		vs.append(contorno[i] - n * PARA_DENTRO)
		uvs.append(pts2[i])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_o = o
	_u = u
	_v = v
	var no_vidro := Vector2((onde - o).dot(u), (onde - o).dot(v))
	impacto = o + u * no_vidro.x + v * no_vidro.y
	# O sorteio das radiais: tortas, nenhuma igual, as pares longas.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(semente * 7919.0)
	for k in RADIAIS:
		angulos.append((float(k) + 0.5 + (rng.randf() - 0.5) * 0.75) / RADIAIS * TAU)
		comprimentos.append(rng.randf_range(0.35, 1.0) * (1.0 if k % 2 == 0 else 0.7))
		atrasos.append(rng.randf() * 0.45)
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER) as Shader
	_mat.set_shader_parameter(&"impacto", no_vidro)
	_mat.set_shader_parameter(&"semente", semente)
	_mat.set_shader_parameter(&"radiais", float(RADIAIS))
	_mat.set_shader_parameter(&"angulos", angulos)
	_mat.set_shader_parameter(&"comprimentos", comprimentos)
	_mat.set_shader_parameter(&"atrasos", atrasos)
	_mat.set_shader_parameter(&"cresce", 0.0)
	material_override = _mat


## A trinca anda de onde esta ate `ate` em `duracao` segundos. Rachadura corre
## depressa e freia: sai quase toda no primeiro terco.
func crescer(ate: float, duracao: float) -> void:
	var t := create_tween()
	t.tween_method(por_cresce, _cresce, ate, duracao) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func por_cresce(k: float) -> void:
	_cresce = k
	_mat.set_shader_parameter(&"cresce", k)


## Qualquer parametro do shader: `alcance`, `miolo`, `luz`, `brilho`, `agua`,
## `forca_fio`.
func ajustar(nome: StringName, valor: Variant) -> void:
	_mat.set_shader_parameter(nome, valor)
	if nome == &"alcance":
		_alcance = float(valor)


## As radiais como andam AGORA, no espaco do carro: a direcao de cada uma com o
## comprimento ja percorrido. A mesma conta de `andou` do shader.
func radiais_no_carro() -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in angulos.size():
		var c := clampf((_cresce - atrasos[k]) / (1.0 - atrasos[k]), 0.0, 1.0)
		c = 1.0 - (1.0 - c) * (1.0 - c)
		var l := _alcance * comprimentos[k] * c
		out.append((_u * cos(angulos[k]) + _v * sin(angulos[k])) * l)
	return out
