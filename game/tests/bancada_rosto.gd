## Bancada do rosto: cada expressao e cada boca, em close, em gente diferente.
##
##     godot --path game --resolution 1280x720 --script res://tests/bancada_rosto.gd -- --saida=DIR
##
## A folha (`tools/gerar_rosto.py`) prova o desenho; so a foto prova o LUGAR: o
## recorte colado meio texel ao lado da boca le como duas bocas. Aqui o recorte
## e desenhado pela placa de video, com filtro, tinta de pele e luz, na cabeca
## de verdade.
##
##   rostos.png   linhas = pessoas; colunas = neutro, as 11 expressoes e as 6 bocas
extends SceneTree

const QUADRO := Vector2i(150, 170)

var _saida := ""
var _vp: SubViewport
var _cam: Camera3D


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
	_rodar()


func _rodar() -> void:
	await process_frame
	_vp = SubViewport.new()
	_vp.size = QUADRO
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var mundo := Node3D.new()
	_vp.add_child(mundo)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("4d5761")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a09c90")
	env.ambient_light_energy = 1.1
	ambiente.environment = env
	mundo.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	luz.light_energy = 1.2
	luz.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(-160.0), 0.0)
	mundo.add_child(luz)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	mundo.add_child(_cam)
	_cam.current = true

	var fichas := [
		Aparencia.de_ficha({"id": 3, "sexo": &"M", "idade": 30}),
		Aparencia.de_ficha({"id": 8, "sexo": &"F", "idade": 26}),
		Aparencia.de_ficha({"id": 21, "sexo": &"M", "idade": 58}),
	]
	# Uma de estudio (a cara que o jogador escolhe) e o Helmer.
	var estudio := Aparencia.de_ficha({"id": 5, "sexo": &"F", "idade": 30})
	estudio["linha_rosto"] = Aparencia.LINHA_ESTUDIO_F
	estudio["rosto"] = 2
	fichas.append(estudio)
	var colunas: Array = [["neutra", -1, &""]]
	for e in Rosto.Expressao.values():
		if e != Rosto.Expressao.NEUTRA:
			colunas.append([Rosto.Expressao.keys()[e], e, &""])
	for b: StringName in RostoMeta.BOCAS:
		colunas.append([String(b), -1, b])
	var quadros: Array = []
	for a: Dictionary in fichas:
		var c := Corpo.new()
		c.detalhado = true
		mundo.add_child(c)
		c.montar(a)
		c.animar(0.0, 0.016)
		c.rosto.pisca = false
		var cabeca := c.esqueleto().get_bone_global_pose(Corpo.Osso.CABECA).origin + Vector3(0, 0.15, 0)
		_cam.position = cabeca + Vector3(0.0, 0.0, -0.75)
		_cam.look_at(cabeca, Vector3.UP)
		for col: Array in colunas:
			c.rosto.boca_da_fala(&"", false)
			c.rosto.expressao(Rosto.Expressao.NEUTRA if int(col[1]) < 0 else int(col[1]))
			if col[2] != &"":
				c.rosto.boca_da_fala(col[2])
			await process_frame
			await process_frame
			quadros.append(_vp.get_texture().get_image())
		c.queue_free()
		await process_frame
	if _saida.is_empty():
		quit()
		return
	var folha := Image.create(QUADRO.x * colunas.size(), QUADRO.y * fichas.size(), false,
		Image.FORMAT_RGBA8)
	for i in quadros.size():
		var img: Image = quadros[i]
		img.convert(Image.FORMAT_RGBA8)
		folha.blit_rect(img, Rect2i(Vector2i.ZERO, QUADRO),
			Vector2i((i % colunas.size()) * QUADRO.x, (i / colunas.size()) * QUADRO.y))
	DirAccess.make_dir_recursive_absolute(_saida)
	folha.save_png(_saida.path_join("rostos.png"))
	print("folha rostos: ", colunas.map(func(x: Array) -> String: return String(x[0])))
	quit()
