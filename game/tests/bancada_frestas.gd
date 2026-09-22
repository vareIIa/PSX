## Frestas pro limbo no chao: o quadrado do cruzamento, a calcada, a quina.
##
##     godot --path game --resolution 1280x720 --script res://tests/bancada_frestas.gd
##     godot --path game --resolution 480x270  --script res://tests/bancada_frestas.gd -- --ps1
##     (SEM --headless: precisa desenhar)
##     -- --centro=cx,cz   chunk do meio (padrao 0,0)
##     -- --raio=N         poses nos chunks a N do centro (padrao 2)
##     -- --saida=DIR      grava a foto das poses que falharem
##
## Por que existe
## -------------
## `bancada_quinas` olha poses fixas, de perto e de cima. O defeito que sobrou
## pisca: um pixel abre e fecha conforme a camera anda. E a cara de fresta de
## rasterizacao, a aresta de uma malha e a de outra passando pelo mesmo lugar
## sem dividir vertice, e o snap do PS1 transforma isso em fresta de um pixel
## inteiro. Aqui a camera roda em volta de cada cruzamento e corre rasante ao
## longo do meio-fio, a altura do olho, como o jogador anda.
##
## A regua: fundo preto e todo material com vermelho acima de 0,3 (sem luz).
## Pixel preto ABAIXO do horizonte cujo raio, marchado contra o relevo, bate no
## chao a menos de ALCANCE metros e buraco: ali tinha de haver chao. O ponto
## onde o raio bate da o endereco do buraco em coordenada de mundo.
##
## Controle positivo: antes de tudo, o chunk do centro perde um triangulo de chao
## e uma pose olha para o buraco. Se a regua nao o ve, ela nao vale nada.
extends SceneTree

const TAM := 32.0
const OLHO := 1.65
const ALCANCE := 45.0
## Pixels de buraco tolerados por pose. Zero: fresta de um pixel ja e o defeito.
const LIMITE := 0

var _camera: Camera3D
var _saida := ""
var _ps1 := false
var _centro := Vector2i.ZERO
var _raio := 2
## So estas poses (indices), para reproduzir uma falha.
var _so: Array[int] = []
var _mats := {}
var _raiz: Node3D
## Os pixels de buraco da ultima medida, para marcar na foto.
var _px_buraco: Array[Vector2i] = []
var _foto: Image
## Chunk -> superficies, para o raio de diagnostico.
var _sups := {}
var CB: GDScript
var RL: GDScript
var PM: GDScript
var MU: GDScript
var VI: GDScript
var KM: GDScript


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
		elif arg == "--ps1":
			_ps1 = true
		elif arg.begins_with("--centro="):
			var p := arg.trim_prefix("--centro=").split(",")
			_centro = Vector2i(int(p[0]), int(p[1]))
		elif arg.begins_with("--so="):
			for k: String in arg.trim_prefix("--so=").split(","):
				_so.append(int(k))
		elif arg.begins_with("--raio="):
			_raio = int(arg.trim_prefix("--raio="))
	_rodar.call_deferred()


func _rodar() -> void:
	CB = load("res://src/world/chunk_builder.gd")
	RL = load("res://src/world/relevo.gd")
	PM = load("res://src/render/psx_mesh.gd")
	MU = load("res://src/world/malha_urbana.gd")
	VI = load("res://src/world/vias.gd")
	KM = load("res://src/world/kit_modular.gd")
	RenderingServer.set_default_clear_color(Color.BLACK)
	_raiz = Node3D.new()
	root.add_child(_raiz)
	var t0 := Time.get_ticks_msec()
	var margem := 3
	for cz in range(_centro.y - _raio - margem, _centro.y + _raio + margem + 1):
		for cx in range(_centro.x - _raio - margem, _centro.x + _raio + margem + 1):
			var sup: Dictionary = CB.construir(cx, cz)["superficies"]
			_sups[Vector2i(cx, cz)] = sup
			_por_chunk(cx, cz, sup)
	print("[frestas] %d chunks montados em %d ms (%s)" % [_raiz.get_child_count(),
		Time.get_ticks_msec() - t0, "PS1 snap" if _ps1 else "moderno"])

	_camera = Camera3D.new()
	_camera.fov = 70.0
	_camera.near = 0.05
	_camera.far = 400.0
	root.add_child(_camera)
	_camera.current = true

	var ok_controle := await _controle_positivo()
	var poses := _poses().filter(func(q: Dictionary) -> bool: return _na_rua(q["de"]))
	var buracos := {}
	var falhas := 0
	t0 = Time.get_ticks_msec()
	if not _so.is_empty():
		poses = poses.filter(func(q: Dictionary) -> bool: return _so.has(int(q["k"])))
	for pose: Dictionary in poses:
		var achados := await _medir(pose["de"], pose["para"])
		if achados.is_empty():
			continue
		falhas += 1
		print("  pose %s %d  %d px  de %s para %s" % [pose["tipo"], int(pose["k"]),
			achados.size(), pose["de"], pose["para"]])
		if not _so.is_empty():
			_diagnosticar()
		for p: Vector3 in achados:
			var chave := Vector2i(roundi(p.x), roundi(p.z))
			if not buracos.has(chave):
				buracos[chave] = {"n": 0, "tipos": {}, "p": p}
			buracos[chave]["n"] += 1
			buracos[chave]["tipos"][pose["tipo"]] = true
		if _saida != "":
			_foto.save_png("%s/%s_%d_cru.png" % [_saida, pose["tipo"], int(pose["k"])])
			_marcar(_foto).save_png(
				"%s/%s_%d.png" % [_saida, pose["tipo"], int(pose["k"])])
	print("[frestas] %d poses em %d ms" % [poses.size(), Time.get_ticks_msec() - t0])

	var lista := buracos.values()
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["n"] > b["n"])
	for b: Dictionary in lista.slice(0, 120):
		var p: Vector3 = b["p"]
		var c := Vector2i(floori(p.x / TAM), floori(p.z / TAM))
		print("  %4d px  mundo (%.2f, %.2f, %.2f)  chunk %s local (%.2f, %.2f)  %s" % [
			b["n"], p.x, p.y, p.z, c, p.x - c.x * TAM, p.z - c.y * TAM,
			",".join(PackedStringArray(b["tipos"].keys()))])
	print("[frestas] controle positivo: %s" % ("viu o buraco" if ok_controle else "NAO VIU"))
	print("bancada_frestas: %d poses, %d com buraco, %d pontos" % [poses.size(), falhas,
		buracos.size()])
	var passou := falhas == 0 and ok_controle
	print("PASSOU" if passou else "FALHOU")
	quit(0 if passou else 1)


func _por_chunk(cx: int, cz: int, sup: Dictionary) -> Node3D:
	var no := Node3D.new()
	no.position = Vector3(cx * TAM, 0.0, cz * TAM)
	_raiz.add_child(no)
	for mat: StringName in sup:
		if PM.dados_vazio(sup[mat]):
			continue
		if not _mats.has(mat):
			_mats[mat] = _chapado(mat)
		var mi := MeshInstance3D.new()
		mi.mesh = PM.dados_para_mesh(sup[mat])
		mi.material_override = _mats[mat]
		no.add_child(mi)
	return no


## O chunk do centro montado de novo sem UM triangulo de chao da pista, perto do
## canto (0, 0). A saia da Costura tapa fresta de costura de proposito, entao o
## controle e o chao que falta mesmo. Tem de aparecer.
func _controle_positivo() -> bool:
	var base := Vector3(_centro.x * TAM, 0.0, _centro.y * TAM)
	var alvo: Node3D = null
	for no: Node3D in _raiz.get_children():
		if no.position == base:
			alvo = no
	var sup: Dictionary = CB.construir(_centro.x, _centro.y)["superficies"]
	var alvo_p := Vector2(1.0, 1.0)
	var tirado := false
	for mat: StringName in sup:
		var d: Dictionary = sup[mat]
		var v: PackedVector3Array = d["v"]
		var idx: PackedInt32Array = d["i"]
		for k in range(0, idx.size(), 3):
			var m := (v[idx[k]] + v[idx[k + 1]] + v[idx[k + 2]]) / 3.0
			if not tirado and Vector2(m.x, m.z).distance_to(alvo_p) < 1.0 					and (v[idx[k + 1]] - v[idx[k]]).cross(v[idx[k + 2]] - v[idx[k]]).y < 0.0:
				print("[frestas] controle tira %s em %s" % [mat, m])
				idx[k + 1] = idx[k]
				idx[k + 2] = idx[k]
				tirado = true
		d["i"] = idx
	alvo.visible = false
	var falso := _por_chunk(_centro.x, _centro.y, sup)
	var achados := await _medir(base + Vector3(4.0, OLHO, 4.0), base + Vector3(1.0, 0.0, 1.0))
	if _saida != "":
		_foto.save_png("%s/controle.png" % _saida)
	_raiz.remove_child(falso)
	falso.queue_free()
	alvo.visible = true
	return tirado and not achados.is_empty()


## Posiciona a camera (as alturas de `de` e `para` sao sobre o chao) e devolve o
## ponto de mundo de cada pixel de buraco.
func _medir(de: Vector3, para: Vector3) -> Array[Vector3]:
	de.y += RL.altura(de.x, de.z)
	para.y += RL.altura(para.x, para.z)
	_camera.look_at_from_position(de, para)
	# O autoload de qualidade liga TAA e AA: a media entre quadros apaga a
	# fresta de um pixel que o olho ve piscar. A regua mede o quadro cru.
	root.use_taa = false
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	_foto = img.duplicate()
	img.convert(Image.FORMAT_R8)
	var w := img.get_width()
	var h := img.get_height()
	# O horizonte do plano: abaixo dele so ha chao, ou fundo alem do mundo
	# montado, que o raio marchado separa.
	var topo := 0
	for y in range(0, h, 4):
		if _camera.project_ray_normal(Vector2(w * 0.5, y) * root.get_visible_rect().size
				/ Vector2(w, h)).y < -0.02:
			topo = y
			break
	# A janela estica a base de 480x270 do projeto: o raio da camera e pedido
	# na coordenada da viewport, nao na do pixel da foto.
	var escala := root.get_visible_rect().size / Vector2(w, h)
	var dados := img.get_data()
	var saida: Array[Vector3] = []
	_px_buraco.clear()
	# De baixo para cima: o chao perto primeiro. Logo abaixo do horizonte fica o
	# fim do mundo montado, uma faixa preta da largura da tela que gastava o teto
	# de pixels antes de chegar a qualquer buraco.
	var i := dados.rfind(0)
	var vistos := 0
	while i >= topo * w and vistos < 4000:
		vistos += 1
		var px := (Vector2(i % w, i / w) + Vector2(0.5, 0.5)) * escala
		var hit: Variant = _marchar(_camera.project_ray_origin(px), _camera.project_ray_normal(px))
		if hit != null:
			saida.append(hit)
			_px_buraco.append(Vector2i(i % w, i / w))
		i = dados.rfind(0, i - 1) if i > 0 else -1
	return saida


## Para ate seis pixels de buraco espalhados: o que o raio do pixel de cima, de
## baixo, da esquerda e da direita acerta. Sao as duas bordas da fresta.
func _diagnosticar() -> void:
	var w := _foto.get_width()
	var h := _foto.get_height()
	var escala := root.get_visible_rect().size / Vector2(w, h)
	var passo := maxi(1, _px_buraco.size() / 6)
	for n in range(0, _px_buraco.size(), passo):
		var q := _px_buraco[n]
		print("    pixel ", q)
		for d: Vector2i in [Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0), Vector2i.ZERO]:
			var px := (Vector2(q + d) + Vector2(0.5, 0.5)) * escala
			var hit := _lancar(_camera.project_ray_origin(px), _camera.project_ray_normal(px))
			if hit.is_empty():
				print("      %s nada" % d)
			else:
				var p: Vector3 = hit["p"]
				var c: Vector2i = hit["c"]
				print("      %s %s  chunk %s local (%.3f, %.3f, %.3f)  t %.2f" % [d, hit["mat"],
					c, p.x - c.x * TAM, p.y, p.z - c.y * TAM, hit["t"]])


## O triangulo mais perto que o raio acerta, entre os chunks montados.
func _lancar(o: Vector3, d: Vector3) -> Dictionary:
	var melhor := {}
	var t_melhor := 80.0
	for c: Vector2i in _sups:
		var base := Vector3(c.x * TAM, 0.0, c.y * TAM)
		# Chunk longe da linha do raio fica de fora.
		var centro := base + Vector3(16.0, 0.0, 16.0)
		var ate := centro - o
		var ao_longo := ate.dot(d)
		if ao_longo < -30.0 or ao_longo > t_melhor + 30.0:
			continue
		var perto := o + d * clampf(ao_longo, 0.0, t_melhor)
		if Vector2(perto.x - centro.x, perto.z - centro.z).length() > 30.0:
			continue
		var ol := o - base
		var sup: Dictionary = _sups[c]
		for mat: StringName in sup:
			var v: PackedVector3Array = sup[mat]["v"]
			var idx: PackedInt32Array = sup[mat]["i"]
			for k in range(0, idx.size(), 3):
				var a := v[idx[k]]
				var b := v[idx[k + 1]]
				var e := v[idx[k + 2]]
				var r: Variant = Geometry3D.ray_intersects_triangle(ol, d, a, b, e)
				if r == null:
					continue
				var t := (Vector3(r) - ol).length()
				# Mesmo descarte do jogo: face de costas nao conta. A face visivel e a do
				# lado OPOSTO ao produto vetorial (o chao da (0, -1, 0) e se ve de cima).
				if t < t_melhor and (b - a).cross(e - a).dot(d) > 0.0:
					t_melhor = t
					melhor = {"mat": mat, "p": Vector3(r) + base, "c": c, "t": t}
	return melhor


## A foto com um quadrado ciano em volta de cada pixel de buraco.
func _marcar(img: Image) -> Image:
	img.convert(Image.FORMAT_RGB8)
	for q: Vector2i in _px_buraco:
		for d in range(-4, 5):
			for e: Vector2i in [Vector2i(q.x + d, q.y - 4), Vector2i(q.x + d, q.y + 4),
					Vector2i(q.x - 4, q.y + d), Vector2i(q.x + 4, q.y + d)]:
				if e.x >= 0 and e.y >= 0 and e.x < img.get_width() and e.y < img.get_height():
					img.set_pixelv(e, Color.CYAN)
	return img


## Onde o raio cruza o relevo, ou null se ele passa de ALCANCE sem bater.
func _marchar(o: Vector3, d: Vector3) -> Variant:
	var passo := 0.1
	var t := 0.0
	var antes: float = o.y - RL.altura(o.x, o.z)
	while t < ALCANCE:
		t += passo
		var p := o + d * t
		var acima: float = p.y - RL.altura(p.x, p.z)
		# O chao da rua fica ate 30 cm acima ou abaixo do mapa (calcada, patamar);
		# so conta raio que desce bem abaixo dele.
		if acima < -0.35:
			return p if antes > -0.35 else null
		antes = acima
		passo = minf(0.5, 0.1 + t * 0.02)
	return null


func _chapado(mat: StringName) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader()
	var h := String(mat).hash()
	m.set_shader_parameter(&"cor", Color(0.3 + (h & 0xff) / 400.0,
		0.2 + ((h >> 8) & 0xff) / 400.0, ((h >> 16) & 0xff) / 255.0))
	m.set_shader_parameter(&"snap", _ps1)
	# A grade do PS1 (psx_surface: snap_resolution 240x135 x psx_snap_escala).
	var escala := float(DisplayServer.window_get_size().x) / 480.0
	m.set_shader_parameter(&"grade", Vector2(240.0, 135.0) * escala)
	return m


var _sh: Shader
func _shader() -> Shader:
	if _sh == null:
		_sh = Shader.new()
		# Mesmo cull_back e mesmo snap do psx_surface.
		_sh.code = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec4 cor : source_color;
uniform bool snap;
uniform vec2 grade;
void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (snap && clip.w > 0.0) {
		vec3 ndc = clip.xyz / clip.w;
		ndc.xy = floor(ndc.xy * grade) / grade;
		clip = vec4(ndc * clip.w, clip.w);
	}
	POSITION = clip;
}
void fragment() { ALBEDO = cor.rgb; }
"""
	return _sh


## A camera esta onde o jogador anda: rua ou calcada, fora da area util do
## lote. Dentro do predio o que se ve e o avesso da fachada, e isso nao e fresta.
func _na_rua(p: Vector3) -> bool:
	var cx := floori(p.x / TAM)
	var cz := floori(p.z / TAM)
	var lim: Rect2 = CB.area_util(cx, cz)
	return not lim.grow(0.3).has_point(Vector2(p.x - cx * TAM, p.z - cz * TAM))


func _poses() -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Cruzamentos: todo no de grade onde duas ou mais ruas chegam. Camera em anel,
	# a altura do olho, olhando o miolo e as quatro bordas dele.
	for j in range(_centro.y - _raio, _centro.y + _raio + 2):
		for i in range(_centro.x - _raio, _centro.x + _raio + 2):
			var bracos := int(VI.braco_n(i, j)) + int(VI.braco_s(i, j)) \
				+ int(VI.braco_l(i, j)) + int(VI.braco_o(i, j))
			if bracos < 2:
				continue
			var c := Vector3(i * TAM, 0.0, j * TAM)
			for r: float in [4.5, 9.0, 15.0]:
				for a in 8:
					var ang := TAU * (a + 0.5) / 8.0 + rng.randf_range(-0.1, 0.1)
					var de := c + Vector3(cos(ang), 0.0, sin(ang)) * r + Vector3(0, OLHO, 0)
					var mira := c + Vector3(rng.randf_range(-3, 3), 0.0, rng.randf_range(-3, 3))
					saida.append({"tipo": "cruzamento", "k": saida.size(), "de": de,
						"para": mira})
	# Calcada: camera na pista, rasante ao longo do meio-fio, olhando 6 a 14 m
	# adiante. E o angulo em que a emenda da calcada com a rua vira uma linha.
	for cz in range(_centro.y - _raio, _centro.y + _raio + 1):
		for cx in range(_centro.x - _raio, _centro.x + _raio + 1):
			var b: Dictionary = MU.bordas(cx, cz)
			var o := Vector3(cx * TAM, 0.0, cz * TAM)
			var px0: float = MU.meia_asfalto(b["x0"])
			var px1: float = MU.meia_asfalto(b["x1"])
			var pz0: float = MU.meia_asfalto(b["z0"])
			var pz1: float = MU.meia_asfalto(b["z1"])
			for s: float in [-1.0, 1.0]:
				if px0 > 0.05:
					var x := px0 - 1.2
					var z := 16.0 + s * rng.randf_range(4.0, 12.0)
					saida.append({"tipo": "calcada", "k": saida.size(),
						"de": o + Vector3(x, OLHO, z),
						"para": o + Vector3(px0 + 0.3, 0.0, z - s * rng.randf_range(6, 14))})
				if px1 > 0.05:
					var x := TAM - px1 + 1.2
					var z := 16.0 + s * rng.randf_range(4.0, 12.0)
					saida.append({"tipo": "calcada", "k": saida.size(),
						"de": o + Vector3(x, OLHO, z),
						"para": o + Vector3(TAM - px1 - 0.3, 0.0, z - s * rng.randf_range(6, 14))})
				if pz0 > 0.05:
					var z := pz0 - 1.2
					var x := 16.0 + s * rng.randf_range(4.0, 12.0)
					saida.append({"tipo": "calcada", "k": saida.size(),
						"de": o + Vector3(x, OLHO, z),
						"para": o + Vector3(x - s * rng.randf_range(6, 14), 0.0, pz0 + 0.3)})
				if pz1 > 0.05:
					var z := TAM - pz1 + 1.2
					var x := 16.0 + s * rng.randf_range(4.0, 12.0)
					saida.append({"tipo": "calcada", "k": saida.size(),
						"de": o + Vector3(x, OLHO, z),
						"para": o + Vector3(x - s * rng.randf_range(6, 14), 0.0, TAM - pz1 - 0.3)})
	return saida
