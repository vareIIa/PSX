## Bake de icones de inventario a partir dos meshes de ItemModelo.
##
## Abre um SubViewport de estudio, renderiza cada item em PNG 96x96 com fundo
## transparente e grava em res://assets/icones/. Tambem monta a folha de contato
## em ../captures/icones_roleta.png (relativo ao projeto game/).
##
## Precisa de GPU real (--headless usa renderer dummy e nao grava textura):
##     .tools/Godot_..._console.exe --path game --rendering-driver d3d12 res://scenes/tools/bake_icones.tscn
## Ou: python tools/gerar_itens.py
extends Node3D

const OUT_DIR := "res://assets/icones"
const SIZE := 96
const SUPER := 2

var _vp: SubViewport
var _host: Node3D
var _cam: Camera3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _preparar()
	await _bake_tudo()
	print("[bake_icones] ok")
	get_tree().quit(0)


func _preparar() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE * SUPER, SIZE * SUPER)
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.handle_input_locally = false
	add_child(_vp)

	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c8c0a8")
	env.ambient_light_energy = 0.70
	ambiente.environment = env
	_vp.add_child(ambiente)

	var key := DirectionalLight3D.new()
	key.light_energy = 1.55
	key.shadow_enabled = true
	key.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(38.0), 0.0)
	_vp.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.55
	fill.light_color = Color("a8b8d0")
	fill.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(-50.0), 0.0)
	_vp.add_child(fill)

	_cam = Camera3D.new()
	_cam.fov = 28.0
	_cam.near = 0.05
	_cam.far = 40.0
	_cam.position = Vector3(1.05, 0.85, 2.15)
	_vp.add_child(_cam)
	_cam.look_at(Vector3(0.0, 0.05, 0.0), Vector3.UP)
	_cam.current = true

	_host = Node3D.new()
	_vp.add_child(_host)

	# Sombra de contato (disco escuro no chao do estudio).
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
	_vp.add_child(chao)

	await RenderingServer.frame_post_draw


func _bake_tudo() -> void:
	var abs_out := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(abs_out)

	var sheet_imgs: Array[Image] = []
	var sheet_ids: Array[String] = []

	for id: StringName in ItemModelo.IDS:
		_limpar_host()
		var modelo := ItemModelo.criar(id)
		_host.add_child(modelo)
		_enquadrar(modelo)
		# Pose de inventario: leve inclinacao 3/4, como na print.
		_host.rotation = Vector3(deg_to_rad(-22.0), deg_to_rad(38.0), deg_to_rad(4.0))
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw

		var img: Image = _vp.get_texture().get_image()
		if img == null:
			push_error("[bake_icones] sem imagem para %s" % id)
			continue
		img.convert(Image.FORMAT_RGBA8)
		if SUPER != 1:
			img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		_crop_alpha(img)
		var caminho := abs_out.path_join("%s.png" % String(id))
		var err := img.save_png(caminho)
		print("[bake_icones] %s -> %s (%s)" % [id, caminho, error_string(err)])
		sheet_imgs.append(img.duplicate())
		sheet_ids.append(String(id))

	_salvar_folha(sheet_imgs, sheet_ids)


func _limpar_host() -> void:
	for c in _host.get_children():
		_host.remove_child(c)
		c.free()
	_host.rotation = Vector3.ZERO
	_host.position = Vector3.ZERO
	_host.scale = Vector3.ONE


func _enquadrar(modelo: Node3D) -> void:
	# Escala generica: a maioria dos volumes cabe em ~1.4 unidades.
	var escala := 1.0
	match modelo.name:
		"pistola", "pe_de_cabra":
			escala = 0.95
		"municao_9mm", "identidade":
			escala = 1.05
		"bilhete":
			escala = 1.1
		"chave_apartamento":
			escala = 1.15
		"bateria", "remedio":
			escala = 1.05
		_:
			escala = 1.0
	modelo.scale = Vector3.ONE * escala


func _crop_alpha(img: Image) -> void:
	# Empurra um pouco de contraste no alfa para o nearest filter da UI.
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.08:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif c.a < 1.0:
				c.a = 1.0 if c.a > 0.35 else c.a
				img.set_pixel(x, y, c)


func _salvar_folha(imgs: Array[Image], ids: Array[String]) -> void:
	if imgs.is_empty():
		return
	var cols := 6
	var rows := int(ceili(float(imgs.size()) / float(cols)))
	var cell := SIZE + 8
	var folha := Image.create(cols * cell + 8, rows * cell + 8, false, Image.FORMAT_RGBA8)
	folha.fill(Color("1a1816"))
	for i in imgs.size():
		var col := i % cols
		var row := i / cols
		var dst := Vector2i(8 + col * cell, 8 + row * cell)
		folha.blit_rect(imgs[i], Rect2i(Vector2i.ZERO, imgs[i].get_size()), dst)
	var jogo := ProjectSettings.globalize_path("res://").rstrip("/").rstrip("\\")
	var caminho := jogo.get_base_dir().path_join("captures/icones_roleta.png")
	DirAccess.make_dir_recursive_absolute(caminho.get_base_dir())
	folha.save_png(caminho)
	print("[bake_icones] folha %s (%d itens)" % [caminho, imgs.size()])
