## O mato da rua (PLANO_FLORA_AAA, rodada 2): o tufo que nasce no pe do muro,
## na junta da calcada com a fachada, e na cova da arvore de calcada.
##
## Rua de cidade do interior nao e calcada lavada: tem a tiririca e o picao no
## pe de toda parede, e a cova do oiti e um canteiro de capim. Vem em manchas —
## trecho limpo, trecho com mato —, nunca em fileira.
##
## Como a GramaViva (de quem e filho, e que lhe passa o chao de cada chunk que
## monta): so no MODERNO, instanciado por MultiMesh no no do chunk, cortado a
## ALCANCE. Nao mexe no ChunkBuilder: a linha da fachada vem de
## `ChunkBuilder.faces_de_rua` e a cova de `ChunkBuilder.arvores`, as duas
## publicas e sem sorteio; a altura vem dos triangulos da propria calcada. O
## sorteio e proprio (semeado pelo chunk).
class_name MatoDeCalcada
extends Node3D

const ALCANCE := 45.0
## Passo ao longo do pe da fachada, e a chance de um trecho ser de mato.
const PASSO := 0.32
const MANCHA := 0.35
const GRADE := 0.25

var _malha: ArrayMesh
var _material: ShaderMaterial
var _pendentes: Dictionary = {}


func _ready() -> void:
	name = "MatoDeCalcada"
	_malha = _tufo()


## Chamado pela GramaViva com as superficies do chunk que acabou de montar.
func ao_carregar(coord: Vector2i, no: Node3D, sup: Dictionary) -> void:
	if OS.get_cmdline_user_args().has("--sem-mato-de-calcada") or not ArvoreEsqueleto.ativo:
		return
	var chao: Array = []
	for material: StringName in sup:
		var nome := String(material)
		if nome.begins_with("calcada") or nome.begins_with("terra"):
			var d: Dictionary = sup[material]
			chao.append([d.get("v", PackedVector3Array()), d.get("i", PackedInt32Array())])
	if chao.is_empty():
		return
	var faces := ChunkBuilder.faces_de_rua(MalhaUrbana.bordas(coord.x, coord.y),
		ChunkBuilder.area_util(coord.x, coord.y))
	var covas := ChunkBuilder.arvores(coord.x, coord.y)
	var saida := {}
	var id := WorkerThreadPool.add_task(_espalhar.bind(chao, faces, covas, hash([coord, 77]), saida))
	_pendentes[id] = [no, saida]


func _process(_delta: float) -> void:
	for id: int in _pendentes.keys():
		if not WorkerThreadPool.is_task_completed(id):
			continue
		WorkerThreadPool.wait_for_task_completion(id)
		var p: Array = _pendentes[id]
		_pendentes.erase(id)
		# O chunk pode ter saido do alcance enquanto a thread trabalhava.
		if not is_instance_valid(p[0]):
			continue
		_montar(p[0], p[1])


## Na thread: a grade de altura do chao da calcada, e os tufos.
static func _espalhar(chao: Array, faces: Array[Dictionary], covas: Array[Vector3], semente: int,
		saida: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var altura := _grade(GramaViva._expandir(chao))
	var buf := PackedFloat32Array()
	# Pe da fachada, em manchas: cada trecho de ~1,5 m e de mato ou limpo.
	for f: Dictionary in faces:
		var canto: Vector3 = f["canto"]
		var eixo: Vector3 = f["eixo"]
		var fora := KitModular._normal(int(f["direcao"]))
		var comp := float(f["comprimento"])
		var t := 0.3
		var com_mato := rng.randf() < MANCHA
		var trecho := rng.randf_range(0.8, 2.2)
		while t < comp - 0.3:
			trecho -= PASSO
			if trecho <= 0.0:
				com_mato = rng.randf() < MANCHA
				trecho = rng.randf_range(0.8, 2.2)
			if com_mato and rng.randf() < 0.8:
				var p := canto + eixo * (t + rng.randf_range(-0.12, 0.12)) \
					+ fora * rng.randf_range(0.06, 0.22)
				var y: float = altura.get(Vector2i(floori(p.x / GRADE), floori(p.z / GRADE)), NAN)
				if is_finite(y):
					var h := rng.randf_range(0.14, 0.4)
					var cel := Plantas.C_MATO if rng.randf() < 0.88 else Plantas.C_CAPIM_GORDURA
					_por(buf, Vector3(p.x, y, p.z), h, cel, rng)
			t += PASSO
	# A cova da arvore: um canteiro de capim em volta do tronco.
	for c: Vector3 in covas:
		for k in rng.randi_range(3, 7):
			var a := rng.randf() * TAU
			var d := rng.randf_range(0.2, 0.42)
			var p := c + Vector3(cos(a) * d, 0.0, sin(a) * d)
			var y: float = altura.get(Vector2i(floori(p.x / GRADE), floori(p.z / GRADE)), NAN)
			if not is_finite(y):
				y = c.y
			var cel := Plantas.C_MATO
			var sorte := rng.randf()
			if sorte < 0.1:
				cel = Plantas.C_MARIA
			elif sorte < 0.2:
				cel = Plantas.C_CAPIM_GORDURA
			_por(buf, Vector3(p.x, y, p.z), rng.randf_range(0.2, 0.5), cel, rng)
	saida["buf"] = buf


## Um tufo: transform 3x4 por linhas e o custom (a celula do atlas).
static func _por(buf: PackedFloat32Array, p: Vector3, h: float, cel: Vector2i,
		rng: RandomNumberGenerator) -> void:
	var w := h * rng.randf_range(1.1, 1.5)
	var b := Basis(Vector3.UP, rng.randf() * PI).scaled(Vector3(w, h, w))
	var uv := Vegetacao.uv_de(cel)
	buf.append_array([b.x.x, b.y.x, b.z.x, p.x,
		b.x.y, b.y.y, b.z.y, p.y - 0.02,
		b.x.z, b.y.z, b.z.z, p.z,
		uv.position.x, uv.position.y, uv.size.x, uv.size.y])


## Por celula da grade, a altura do chao da calcada (o mais alto que for deitado).
static func _grade(tris: PackedVector3Array) -> Dictionary:
	var g := {}
	for t in range(0, tris.size() - 2, 3):
		var a := tris[t]
		var b := tris[t + 1]
		var c := tris[t + 2]
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-8 or absf(n.normalized().y) < 0.8:
			continue
		var x0 := floori(minf(a.x, minf(b.x, c.x)) / GRADE)
		var x1 := floori(maxf(a.x, maxf(b.x, c.x)) / GRADE)
		var z0 := floori(minf(a.z, minf(b.z, c.z)) / GRADE)
		var z1 := floori(maxf(a.z, maxf(b.z, c.z)) / GRADE)
		if (x1 - x0 + 1) * (z1 - z0 + 1) > 40000:
			continue
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.z)
		var c2 := Vector2(c.x, c.z)
		for gx in range(x0, x1 + 1):
			for gz in range(z0, z1 + 1):
				var q := Vector2((float(gx) + 0.5) * GRADE, (float(gz) + 0.5) * GRADE)
				if not Geometry2D.point_is_inside_triangle(q, a2, b2, c2):
					continue
				# A altura no ponto, pelo plano do triangulo.
				var nn := n.normalized()
				var y := a.y - (nn.x * (q.x - a.x) + nn.z * (q.y - a.z)) / nn.y
				var k := Vector2i(gx, gz)
				g[k] = maxf(float(g.get(k, -INF)), y)
	return g


func _montar(no: Node3D, saida: Dictionary) -> void:
	if not is_instance_valid(no) or not no.is_inside_tree():
		return
	var buf: PackedFloat32Array = saida.get("buf", PackedFloat32Array())
	var n := buf.size() / 16
	if n == 0:
		return
	if _material == null:
		# O mat_plantas ja trocado pelo EstiloVisual (shader de folha, HD), com a
		# celula vindo da instancia.
		var base := load("res://resources/materials/mat_plantas.tres") as ShaderMaterial
		_material = base.duplicate() as ShaderMaterial
		_material.set_shader_parameter(&"usa_celula", true)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _malha
	mm.instance_count = n
	mm.buffer = buf
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "mato_de_calcada"
	mmi.multimesh = mm
	mmi.material_override = _material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = ALCANCE
	mmi.visibility_range_end_margin = 5.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	no.add_child(mmi)


## O tufo unitario: dois cartoes em cruz de 1 x 1, pe em y = 0, com as duas
## faces; a UV da celula inteira (0..1), que o shader leva para a celula da
## instancia. Alfa da cor = rigidez ao vento (0 no pe).
static func _tufo() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 2:
		var d := Vector3(cos(PI * 0.5 * float(k)), 0.0, sin(PI * 0.5 * float(k)))
		var face := d.cross(Vector3.UP).normalized()
		var cantos: Array[Vector3] = [-d * 0.5, d * 0.5, d * 0.5 + Vector3.UP, -d * 0.5 + Vector3.UP]
		var uvs: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for lado: float in [1.0, -1.0]:
			# Ternario nao tipa array (memoria "armadilhas mudas do Godot").
			var ordem: Array[int] = [0, 1, 2, 0, 2, 3]
			if lado < 0.0:
				ordem = [0, 2, 1, 0, 3, 2]
			for i: int in ordem:
				var q := cantos[i]
				var nrm := (q * Vector3(1, 0, 1) * 0.6 + face * lado * 0.3 + Vector3.UP * (0.5 + 0.5 * q.y)).normalized()
				st.set_normal(nrm)
				st.set_uv(uvs[i])
				var luz := lerpf(0.72, 1.0, q.y)
				st.set_color(Color(luz, luz, luz, 0.55 * q.y * q.y))
				st.add_vertex(q)
	return st.commit()
