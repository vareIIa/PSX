## Bancada dos gestos: cada ocio, gesto de fala e reacao no pico, e o andar com
## as maos do jeito.
##
##     godot --path game --resolution 1280x720 --script res://tests/bancada_gestos.gd -- --saida=DIR
##
##   gestos.png   um quadro por gesto, de tres quartos, no meio do envelope
##   andar.png    o mesmo passo com maos livres, no bolso, atras e no celular
##
## `--so=TRECHO` fotografa so os gestos cujo nome tem o trecho, de frente e de
## costas (`--so=dor` confere a mao que vai ao lugar que doi, inclusive a lombar).
extends SceneTree

const QUADRO := Vector2i(180, 240)

var _saida := ""
var _so := ""
var _vp: SubViewport
var _cam: Camera3D


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
		elif arg.begins_with("--so="):
			_so = arg.trim_prefix("--so=")
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
	env.ambient_light_energy = 1.0
	ambiente.environment = env
	mundo.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	luz.light_energy = 1.3
	luz.rotation = Vector3(deg_to_rad(-30.0), deg_to_rad(-150.0), 0.0)
	mundo.add_child(luz)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	mundo.add_child(_cam)
	_cam.current = true
	_cam.position = Vector3(1.6, 1.25, -2.6)
	_cam.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)

	var c := Corpo.new()
	c.detalhado = true
	mundo.add_child(c)
	c.montar(Aparencia.de_ficha({"id": 17, "sexo": &"M", "idade": 34}))
	var tipos: Array[int] = []
	for t in range(ReacaoCorpo.OCIO_PESO, ReacaoCorpo.REACAO_MAO_NA_CABECA + 1):
		if _so.is_empty() or ReacaoCorpo.nome(t).contains(_so):
			tipos.append(t)
	var quadros: Array = []
	var nomes: Array = []
	for t in tipos:
		c.reagir(0)
		c.animar(0.0, 0.016)
		c.reagir(t)
		var pico := ReacaoCorpo.duracao(t) * 0.5
		var passo := 1.0 / 15.0
		var andou := 0.0
		while andou < pico:
			c.animar(0.0, passo)
			andou += passo
		quadros.append(await _foto())
		nomes.append(ReacaoCorpo.nome(t))
		if not _so.is_empty():
			_cam.position = Vector3(-1.4, 1.25, 2.7)
			_cam.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
			quadros.append(await _foto())
			_cam.position = Vector3(1.6, 1.25, -2.6)
			_cam.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
	_folha(quadros, 8, "gestos.png")
	print("gestos: ", nomes)
	if not _so.is_empty():
		quit()
		return

	var andar: Array = []
	for m in [Jeito.Maos.LIVRES, Jeito.Maos.BOLSO, Jeito.Maos.ATRAS, Jeito.Maos.CELULAR]:
		c.reagir(0)
		var j := Jeito.neutro()
		j["maos"] = m
		c.jeito = j
		for i in 12:
			c.animar(1.3, 1.0 / 30.0)
		andar.append(await _foto())
	_folha(andar, 4, "andar.png")

	# Corpo inteiro: correndo (duas fases), agachado parado e andando,
	# pedalando (duas fases da pedivela) e dirigindo.
	var inteiro: Array = []
	c.jeito = Jeito.neutro()
	for fase in [0, 8]:
		for i in 30 + fase:
			c.animar(4.6, 1.0 / 60.0)
		inteiro.append(await _foto())
	c.agachado = true
	for i in 20:
		c.animar(0.0, 1.0 / 30.0)
	inteiro.append(await _foto())
	for i in 10:
		c.animar(1.0, 1.0 / 30.0)
	inteiro.append(await _foto())
	c.agachado = false
	c.postura(Corpo.Postura.PEDALANDO)
	for k in [0.3, 2.2]:
		c.pedal_fase = k
		for i in 12:
			c.animar(0.0, 1.0 / 30.0)
		inteiro.append(await _foto())
	c.altura_assento = 0.30
	c.postura(Corpo.Postura.DIRIGINDO)
	for i in 12:
		c.animar(0.0, 1.0 / 30.0)
	inteiro.append(await _foto())
	_folha(inteiro, 7, "corpo_inteiro.png")
	quit()


func _foto() -> Image:
	await process_frame
	await process_frame
	return _vp.get_texture().get_image()


func _folha(quadros: Array, colunas: int, nome: String) -> void:
	if _saida.is_empty():
		return
	var linhas := ceili(float(quadros.size()) / colunas)
	var folha := Image.create(QUADRO.x * colunas, QUADRO.y * linhas, false, Image.FORMAT_RGBA8)
	for i in quadros.size():
		var img: Image = quadros[i]
		img.convert(Image.FORMAT_RGBA8)
		folha.blit_rect(img, Rect2i(Vector2i.ZERO, QUADRO),
			Vector2i((i % colunas) * QUADRO.x, (i / colunas) * QUADRO.y))
	DirAccess.make_dir_recursive_absolute(_saida)
	folha.save_png(_saida.path_join(nome))
