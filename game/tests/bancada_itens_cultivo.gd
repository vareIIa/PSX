## Bancada dos cinco itens do cultivo: fotografa cada um nas tres telas que o
## jogo usa para mostrar item, com a luz e a camera DE CADA UMA copiadas aqui:
##
##   vitrine   prancha_inventario._montar_vitrine (128 px, o item girando)
##   icone     scenes/tools/bake_icones.gd (192 px reduzido a 96, pose 3/4); e o
##             mesmo PNG que o ItemNoChao desenha como sprite na rua
##   inspecao  re7/inspect_viewport.gd (fundo escuro, luz pontual), em 4x
##
##     .tools/Godot_v4.7.2-stable_win64_console.exe --path game res://tests/bancada_itens_cultivo.tscn -- --saida=<pasta> [--bake-icones] [--so=maconha] [--variedades]
##
## --variedades troca os cinco pelos oito itens das variedades da estufa (um por
## andar); com --bake-icones regrava SO esses oito.
##
## Com janela, nunca --headless: o renderer dummy nao desenha, e os shaders
## destes itens (vidro, erva, estudio) so compilam de verdade com GPU.
##
## --bake-icones regrava SO os cinco icones em res://assets/icones. O bake geral
## (scenes/tools/bake_icones.tscn) regrava os dezesseis e passaria por cima do
## icone que outra frente tenha mudado. Por isso o estudio do bake esta COPIADO
## aqui, e tem de acompanhar o de la se aquele mudar.
extends Node

const IDS: Array[StringName] = [
	&"terra", &"semente_maconha", &"regador", &"maconha", &"super_maconha",
]
const VARIEDADES: Array[StringName] = [
	&"erva_morcega", &"erva_bonsai", &"erva_saca_rolha", &"erva_girafa",
	&"erva_pompom", &"erva_chorona", &"erva_gambazona", &"erva_vagalume",
]
## Icones ja existentes, so para comparar tamanho e peso na folha.
const VIZINHOS: Array[StringName] = [&"remedio", &"bateria", &"lanterna", &"radio"]

var _saida := ""
var _bake := false
var _so := ""
var _ids: Array[StringName] = IDS
var _vizinhos: Array[StringName] = VIZINHOS


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			_saida = a.trim_prefix("--saida=")
		elif a == "--bake-icones":
			_bake = true
		elif a.begins_with("--so="):
			_so = a.trim_prefix("--so=")
		elif a == "--variedades":
			_ids = VARIEDADES
			_vizinhos = [&"maconha", &"super_maconha"]
	if _saida.is_empty():
		_saida = ProjectSettings.globalize_path("user://bancada_itens_cultivo")
	DirAccess.make_dir_recursive_absolute(_saida)
	await get_tree().process_frame

	var icones: Array[Image] = []
	for id: StringName in _ids:
		if not _so.is_empty() and String(id) != _so:
			continue
		_medir(id)
		var giros: Array[Image] = []
		for g in 4:
			giros.append(_ampliar(await _foto_vitrine(id, 0.6 + float(g) * PI * 0.5), 3))
		_lado_a_lado(giros, Color("1a1816")).save_png(_saida.path_join("%s_vitrine.png" % id))
		var icone := await _foto_icone(id)
		_ampliar(icone, 4).save_png(_saida.path_join("%s_icone.png" % id))
		icones.append(icone)
		var pertos: Array[Image] = [await _foto_inspecao(id, 0.6), await _foto_inspecao(id, 0.6 + PI)]
		_lado_a_lado(pertos, Color("0a0b0c")).save_png(_saida.path_join("%s_inspecao.png" % id))
		if _bake:
			var caminho := ProjectSettings.globalize_path("res://assets/icones/%s.png" % id)
			print("[bancada] icone %s -> %s (%s)" % [id, caminho, error_string(icone.save_png(caminho))])

	# Folha: os novos ao lado de icones vizinhos que ja existem, na escala 3x.
	var folha: Array[Image] = []
	for img in icones:
		folha.append(_ampliar(img, 3))
	for id: StringName in _vizinhos:
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/icones/%s.png" % id))
		if img != null:
			img.convert(Image.FORMAT_RGBA8)
			folha.append(_ampliar(img, 3))
	if not folha.is_empty():
		_lado_a_lado(folha, Color("2a2622")).save_png(_saida.path_join("folha_icones.png"))
	print("[bancada] ok -> %s" % _saida)
	get_tree().quit(0)


## Triangulos e tempo de montagem, frio (malhas ainda nao em cache) e quente.
func _medir(id: StringName) -> void:
	var t0 := Time.get_ticks_usec()
	var frio := ItemModelo.criar(id)
	var ms_frio := float(Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	var quente := ItemModelo.criar(id)
	var ms_quente := float(Time.get_ticks_usec() - t0) / 1000.0
	var tris := 0
	var malhas := 0
	for mi: Node in frio.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh != null:
			tris += int(mesh.get_faces().size() / 3.0)
			malhas += 1
	print("[bancada] %s: %d triangulos em %d malhas; montagem %.1f ms fria, %.1f ms quente"
		% [id, tris, malhas, ms_frio, ms_quente])
	frio.free()
	quente.free()


func _viewport(tam: Vector2i, msaa: Viewport.MSAA, transparente: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = tam
	vp.own_world_3d = true
	vp.transparent_bg = transparente
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = msaa
	vp.handle_input_locally = false
	add_child(vp)
	return vp


func _ambiente(vp: SubViewport, fundo: Color, cor: Color, energia: float) -> void:
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = fundo
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = cor
	env.ambient_light_energy = energia
	ambiente.environment = env
	vp.add_child(ambiente)


func _sol(vp: SubViewport, energia: float, rot: Vector2, cor: Color, sombra: bool) -> void:
	var luz := DirectionalLight3D.new()
	luz.light_energy = energia
	luz.light_color = cor
	luz.shadow_enabled = sombra
	luz.rotation = Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), 0.0)
	vp.add_child(luz)


func _camera(vp: SubViewport, fov: float, pos: Vector3) -> void:
	var cam := Camera3D.new()
	cam.fov = fov
	cam.near = 0.05
	cam.far = 40.0
	cam.position = pos
	vp.add_child(cam)
	cam.look_at(Vector3(0.0, 0.05, 0.0), Vector3.UP)
	cam.current = true


func _tirar(vp: SubViewport) -> Image:
	for i in 4:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	vp.queue_free()
	return img


## Copia de prancha_inventario._montar_vitrine.
func _foto_vitrine(id: StringName, giro: float) -> Image:
	var vp := _viewport(Vector2i(128, 128), Viewport.MSAA_2X, true)
	_ambiente(vp, Color(0, 0, 0, 0), Color("c8c0a8"), 0.95)
	_sol(vp, 1.7, Vector2(-40.0, 38.0), Color.WHITE, false)
	_sol(vp, 0.4, Vector2(-18.0, -55.0), Color("a8b8d0"), false)
	_camera(vp, 30.0, Vector3(0.95, 0.75, 2.05))
	var raiz := Node3D.new()
	raiz.rotation = Vector3(deg_to_rad(-18.0), giro, 0.0)
	vp.add_child(raiz)
	raiz.add_child(ItemModelo.criar(id))
	return await _tirar(vp)


## Copia de scenes/tools/bake_icones.gd (_preparar, _bake_tudo, _crop_alpha).
func _foto_icone(id: StringName) -> Image:
	var vp := _viewport(Vector2i(192, 192), Viewport.MSAA_4X, true)
	_ambiente(vp, Color(0, 0, 0, 0), Color("c8c0a8"), 0.70)
	_sol(vp, 1.55, Vector2(-42.0, 38.0), Color.WHITE, true)
	_sol(vp, 0.55, Vector2(-20.0, -50.0), Color("a8b8d0"), false)
	_camera(vp, 28.0, Vector3(1.05, 0.85, 2.15))
	var host := Node3D.new()
	vp.add_child(host)
	var chao := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 0.85
	disco.bottom_radius = 0.85
	disco.height = 0.02
	disco.radial_segments = 20
	chao.mesh = disco
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.05, 0.04, 0.03, 0.45)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	chao.material_override = sm
	chao.position = Vector3(0.0, -0.72, 0.0)
	vp.add_child(chao)
	host.add_child(ItemModelo.criar(id))
	host.rotation = Vector3(deg_to_rad(-22.0), deg_to_rad(38.0), deg_to_rad(4.0))
	var img := await _tirar(vp)
	img.resize(96, 96, Image.INTERPOLATE_LANCZOS)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.08:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif c.a < 1.0:
				c.a = 1.0 if c.a > 0.35 else c.a
				img.set_pixel(x, y, c)
	return img


## Copia de re7/inspect_viewport.gd, em 4x (140 x 150 -> 560 x 600).
func _foto_inspecao(id: StringName, giro: float) -> Image:
	var vp := _viewport(Vector2i(560, 600), Viewport.MSAA_4X, false)
	_ambiente(vp, Color(0.04, 0.045, 0.05), Color(0.12, 0.14, 0.16), 0.35)
	var key := OmniLight3D.new()
	key.light_color = Color(1.0, 0.92, 0.82)
	key.light_energy = 2.4
	key.omni_range = 6.0
	key.position = Vector3(1.2, 1.6, 1.4)
	vp.add_child(key)
	var rim := OmniLight3D.new()
	rim.light_color = Color(0.55, 0.72, 0.95)
	rim.light_energy = 1.1
	rim.omni_range = 5.0
	rim.position = Vector3(-1.4, 0.6, -1.1)
	vp.add_child(rim)
	_camera(vp, 30.0, Vector3(0.95, 0.75, 2.05))
	var pivo := Node3D.new()
	pivo.rotation = Vector3(deg_to_rad(-18.0), giro, 0.0)
	vp.add_child(pivo)
	pivo.add_child(ItemModelo.criar(id))
	return await _tirar(vp)


func _ampliar(img: Image, k: int) -> Image:
	var out := img.duplicate() as Image
	out.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	return out


func _lado_a_lado(imgs: Array[Image], fundo: Color) -> Image:
	var vao := 8
	var w := vao
	var h := 0
	for img in imgs:
		w += img.get_width() + vao
		h = maxi(h, img.get_height())
	var out := Image.create(w, h + vao * 2, false, Image.FORMAT_RGBA8)
	out.fill(fundo)
	var x := vao
	for img in imgs:
		out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, vao))
		x += img.get_width() + vao
	return out
