## Grama instanciada perto do jogador (PLANO_FLORA_AAA, etapa 4). So no MODERNO.
##
## O gramado da praca, do parque e do quintal e um plano com a textura HD da
## grama. De cima ele passa; da altura do olho a borda do gramado e uma aresta
## de papel contra o passeio, e o vento nao mexe em nada. Aqui cada chunk que
## carrega ganha tufos de lamina espalhados pelos triangulos da malha `grama`
## dele — a malha ja vem com o relevo aplicado, entao o tufo nasce no chao que
## o jogador pisa, na ladeira inclusive.
##
## Por que nao no ChunkBuilder: tufo e decoracao so do MODERNO, some no PS1
## STYLE, e o sup do chunk e o mesmo para os dois estilos. Aqui ele nasce ao
## lado do chunk, pelo sinal `chunk_carregado`, sem tocar no que o chunk e.
##
## Custo: o espalhamento roda numa thread do WorkerThreadPool (a conta de 10 mil
## tufos no laco principal era engasgo — memoria "sonda por chunk custa
## engasgo"), e o desenho e em celulas de 8 m, cada uma um MultiMesh com alcance
## proprio: so as celulas perto da lente vao para a GPU.
class_name GramaViva
extends Node3D

## Tufos por metro quadrado de gramado.
const DENSIDADE := 36.0
## Lado da celula de desenho (m).
const CELULA := 8.0
## Alcance da celula: alem disso ela nao desenha (a lamina ja encolheu ate o
## chao em `encolhe_ate` do shader, antes disso).
const ALCANCE := 18.0
## Grade do que COBRE o gramado (m). O plano da grama passa por baixo do
## calcamento da praca, e sem esta grade a lamina atravessava a pedra.
const GRADE := 0.25
const MATERIAIS: Array[StringName] = [&"grama", &"grama@perto"]
const SHADER := "res://shaders/grama_viva.gdshader"

static var ativo := not OS.get_cmdline_user_args().has("--sem-grama-viva")
## `--grama-viva-log`: quantos tufos e quanto custa montar, por chunk.
static var log_ := OS.get_cmdline_user_args().has("--grama-viva-log")

var _malha: ArrayMesh
var _material: ShaderMaterial
var _pendentes: Dictionary = {}   # task id -> [coord, no, saida]
var _mato: MatoDeCalcada


func _ready() -> void:
	name = "GramaViva"
	# A folha que cai das copas da rua (rodada 2): filha daqui para sumir junto
	# no PS1 STYLE.
	add_child(FolhasCaindo.new())
	if not ativo:
		return
	_malha = _tufo()
	# O mato do pe do muro e da cova da arvore (rodada 2), que usa o mesmo chao.
	_mato = MatoDeCalcada.new()
	add_child(_mato)
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER) as Shader
	# O chao do chunk vem do proprio ChunkManager, na hora de montar: ler de
	# volta a malha (`surface_get_arrays`) custava ate 9 ms por chunk no laco
	# principal (medido com --grama-viva-log).
	ChunkManager.guardar_superficies = true
	ChunkManager.chunk_carregado.connect(_ao_carregar)


func _process(_delta: float) -> void:
	for id: int in _pendentes.keys():
		if not WorkerThreadPool.is_task_completed(id):
			continue
		WorkerThreadPool.wait_for_task_completion(id)
		var p: Array = _pendentes[id]
		_pendentes.erase(id)
		_montar(p[0], p[1], p[2])
	var ligado := Settings.luz_por_pixel
	if visible != ligado:
		visible = ligado


func _ao_carregar(coord: Vector2i) -> void:
	var no: Node3D = ChunkManager._carregados.get(coord)
	if no == null or not no.has_meta(&"superficies"):
		return
	var sup: Dictionary = no.get_meta(&"superficies")
	no.remove_meta(&"superficies")
	if not Settings.luz_por_pixel:
		return
	var grama: Array = []
	var outros: Array = []
	for material: StringName in sup:
		var d: Dictionary = sup[material]
		var par := [d.get("v", PackedVector3Array()), d.get("i", PackedInt32Array())]
		if MATERIAIS.has(material):
			grama.append(par)
		elif not String(material).begins_with("vegetacao") and not String(material).begins_with("casca") 				and not String(material).begins_with("flor"):
			# `flor` tem cartao deitado (tapete de ipe, vitoria-regia): a grama
			# passa por entre as flores caidas, e nao abre um quadrado.
			outros.append(par)
	if _mato != null:
		_mato.ao_carregar(coord, no, sup)
	if grama.is_empty():
		return
	var saida := {}
	var id := WorkerThreadPool.add_task(_espalhar.bind(grama, outros, hash(coord), saida,
		DENSIDADE * _fator_de_qualidade()))
	_pendentes[id] = [coord, no, saida]


## Na thread: tufos por area em cada triangulo virado para cima, agrupados por
## celula, menos onde alguma coisa deitada cobre o gramado. Nada de arvore de
## cena aqui.
static func _espalhar(grama: Array, outros: Array, semente: int, saida: Dictionary,
		densidade: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var celulas := {}
	var tris := _expandir(grama)
	# Lamina seca: 8 % nas aguas, 26 % no auge da seca (Estacao).
	var seca_frac := 0.08 + 0.18 * Estacao.seca()
	var cobre := _cobertura(_expandir(outros))
	for t in range(0, tris.size() - 2, 3):
		var a := tris[t]
		var b := tris[t + 1]
		var c := tris[t + 2]
		var n := (b - a).cross(c - a)
		var area := n.length() * 0.5
		if area < 0.0001:
			continue
		n = n.normalized()
		if absf(n.y) < 0.75:
			continue
		if n.y < 0.0:
			n = -n
		var qtd := area * densidade
		var inteiro := int(qtd)
		if rng.randf() < qtd - float(inteiro):
			inteiro += 1
		for k in inteiro:
			var r1 := sqrt(rng.randf())
			var r2 := rng.randf()
			var p := a * (1.0 - r1) + b * (r1 * (1.0 - r2)) + c * (r1 * r2)
			var g := Vector2i(floori(p.x / GRADE), floori(p.z / GRADE))
			if cobre.has(g):
				var h: Vector2 = cobre[g]
				# Algo deitado entre 1 cm e 1,5 m acima: calcamento, caminho, piso.
				if h.y > p.y + 0.01 and h.x < p.y + 1.5:
					continue
			var chave := Vector2i(floori(p.x / CELULA), floori(p.z / CELULA))
			if not celulas.has(chave):
				celulas[chave] = PackedFloat32Array()
			var buf: PackedFloat32Array = celulas[chave]
			var giro := rng.randf() * TAU
			var escala := rng.randf_range(0.7, 1.3)
			var alto := escala * rng.randf_range(0.8, 1.25)
			var base := Basis(Vector3.UP, giro).scaled(Vector3(escala, alto, escala))
			# Deita o tufo na normal do chao (ladeira).
			base = Basis(Quaternion(Vector3.UP, n)) * base
			# Transform 3x4 por linhas, e o custom (tom, seca, fase, 0).
			buf.append_array([base.x.x, base.y.x, base.z.x, p.x,
				base.x.y, base.y.y, base.z.y, p.y,
				base.x.z, base.y.z, base.z.z, p.z,
				rng.randf_range(0.85, 1.15), 1.0 if rng.randf() < seca_frac else 0.0,
				rng.randf(), 0.0])
			celulas[chave] = buf
	saida["celulas"] = celulas


## A densidade pela escada de qualidade do MODERNO (QualidadeGrafica): o tufo
## e o item mais caro por pixel do chao, e o primeiro a ceder.
static func _fator_de_qualidade() -> float:
	match Qualidade.nivel:
		QualidadeGrafica.Nivel.BAIXO:
			return 0.35
		QualidadeGrafica.Nivel.MEDIO:
			return 0.6
		QualidadeGrafica.Nivel.ALTO:
			return 0.85
	return 1.0


## [vertices, indices] de cada superficie -> uma lista de triangulos soltos.
static func _expandir(superficies: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for sfc: Array in superficies:
		var v: PackedVector3Array = sfc[0]
		var idx: PackedInt32Array = sfc[1]
		if idx.is_empty():
			out.append_array(v)
		else:
			for k in idx.size():
				out.append(v[idx[k]])
	return out


## Os triangulos deitados de tudo o que nao e grama, rasterizados numa grade:
## por celula, a altura (minima, maxima) do que esta ali.
static func _cobertura(outros: PackedVector3Array) -> Dictionary:
	var g := {}
	for t in range(0, outros.size() - 2, 3):
		var a := outros[t]
		var b := outros[t + 1]
		var c := outros[t + 2]
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-8 or absf(n.normalized().y) < 0.9:
			continue
		var x0 := floori(minf(a.x, minf(b.x, c.x)) / GRADE)
		var x1 := floori(maxf(a.x, maxf(b.x, c.x)) / GRADE)
		var z0 := floori(minf(a.z, minf(b.z, c.z)) / GRADE)
		var z1 := floori(maxf(a.z, maxf(b.z, c.z)) / GRADE)
		if (x1 - x0 + 1) * (z1 - z0 + 1) > 40000:
			continue
		var y := (a.y + b.y + c.y) / 3.0
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.z)
		var c2 := Vector2(c.x, c.z)
		for gx in range(x0, x1 + 1):
			for gz in range(z0, z1 + 1):
				var q := Vector2((float(gx) + 0.5) * GRADE, (float(gz) + 0.5) * GRADE)
				if not Geometry2D.point_is_inside_triangle(q, a2, b2, c2):
					continue
				var k := Vector2i(gx, gz)
				var h: Vector2 = g.get(k, Vector2(INF, -INF))
				g[k] = Vector2(minf(h.x, y), maxf(h.y, y))
	return g


func _montar(coord: Vector2i, no: Node3D, saida: Dictionary) -> void:
	if not is_instance_valid(no) or not no.is_inside_tree():
		return
	var celulas: Dictionary = saida.get("celulas", {})
	var t0 := Time.get_ticks_usec()
	var total := 0
	for chave: Vector2i in celulas:
		var buf: PackedFloat32Array = celulas[chave]
		var n := buf.size() / 16
		if n == 0:
			continue
		total += n
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = _malha
		mm.instance_count = n
		mm.buffer = buf
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "grama_viva_%d_%d" % [chave.x, chave.y]
		mmi.multimesh = mm
		mmi.material_override = _material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = ALCANCE
		mmi.visibility_range_end_margin = 4.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		# O no do chunk ja esta na posicao dele; o tufo foi espalhado em
		# coordenada local da malha, que e a do chunk.
		no.add_child(mmi)
	if log_ and total > 0:
		print("[grama_viva] %s: %d tufos, montagem %.2f ms" % [coord, total, (Time.get_ticks_usec() - t0) / 1000.0])


## O tufo: sete laminas finas em leque, cada uma em dois lances que curvam
## para fora, afinando ate a ponta. UV.y vai de 0 no pe a 1 na ponta.
static func _tufo() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for k in 7:
		var giro := TAU * float(k) / 7.0 + rng.randf_range(-0.4, 0.4)
		var fora := Vector3(cos(giro), 0.0, sin(giro))
		var lado := Vector3(-fora.z, 0.0, fora.x)
		var alto := rng.randf_range(0.08, 0.15)
		var curva := rng.randf_range(0.025, 0.06)
		var larg := rng.randf_range(0.004, 0.006)
		var base := fora * rng.randf_range(0.0, 0.025)
		var pts: Array[Vector3] = [base, base + Vector3(0.0, alto * 0.55, 0.0) + fora * curva * 0.35,
			base + Vector3(0.0, alto, 0.0) + fora * curva]
		var largs: Array[float] = [larg, larg * 0.7, 0.0]
		var tom := rng.randf_range(0.85, 1.1)
		for s in 2:
			var a0 := pts[s] - lado * largs[s]
			var a1 := pts[s] + lado * largs[s]
			var b0 := pts[s + 1] - lado * largs[s + 1]
			var b1 := pts[s + 1] + lado * largs[s + 1]
			var nrm := (pts[s + 1] - pts[s]).cross(lado).normalized()
			var v0 := float(s) / 2.0
			var v1 := float(s + 1) / 2.0
			for q: Array in [[a0, v0], [a1, v0], [b1, v1], [a0, v0], [b1, v1], [b0, v1]]:
				st.set_color(Color(tom, tom, tom))
				st.set_normal(nrm)
				st.set_uv(Vector2(0.5, q[1]))
				st.add_vertex(q[0])
	return st.commit()
