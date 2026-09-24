## Bancada do tombo: o boneco de pano e o levantar em folha de contato.
##
##     godot --path game --resolution 1280x720 --script res://tests/bancada_tombo.gd -- --saida=DIR
##
## Tres folhas, cada uma uma grade de quadros com o tempo escrito embaixo:
##   atropelo.png   carro-caixa de 1100 kg a 32 km/h pega uma pessoa andando,
##                  de lado; do contato ate ela ficar de pe
##   costas.png     o levantar de costas (LevantarDoChao), de lado
##   brucos.png     o levantar de bruços, de lado
##
## A regua (`medir_boneco.gd`, `medir_levantar.gd`) diz que a junta nao abre e
## que o pe nao entra no chao. So a foto diz se aquilo le como gente.
extends SceneTree

const QUADRO := Vector2i(420, 300)
const COLUNAS := 4

var _saida := ""
var _vp: SubViewport
var _mundo: Node3D
var _cam: Camera3D


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
	_rodar()


func _rodar() -> void:
	await process_frame
	_montar_palco()
	await _atropelo()
	await _levantar(false, "costas.png")
	await _levantar(true, "brucos.png")
	quit()


func _montar_palco() -> void:
	_vp = SubViewport.new()
	_vp.size = QUADRO
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_mundo = Node3D.new()
	_vp.add_child(_mundo)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("5b6670")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8e8c80")
	env.ambient_light_energy = 1.0
	ambiente.environment = env
	_mundo.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	luz.light_energy = 1.4
	luz.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(-140.0), 0.0)
	_mundo.add_child(luz)
	# Chao com grade: sem referencia no piso nao da para ver quanto o corpo andou.
	var chao := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(80.0, 1.0, 80.0)
	forma.shape = caixa
	forma.position = Vector3(0.0, -0.5, 0.0)
	chao.add_child(forma)
	_mundo.add_child(chao)
	for i in range(-20, 21):
		for eixo in 2:
			var linha := MeshInstance3D.new()
			var m := BoxMesh.new()
			m.size = Vector3(0.02, 0.002, 40.0) if eixo == 0 else Vector3(40.0, 0.002, 0.02)
			linha.mesh = m
			linha.position = Vector3(float(i), 0.001, 0.0) if eixo == 0 else Vector3(0.0, 0.001, float(i))
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("3d454c")
			linha.material_override = mat
			_mundo.add_child(linha)
	var piso := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80.0, 80.0)
	piso.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color("707a80")
	piso.material_override = pmat
	_mundo.add_child(piso)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_mundo.add_child(_cam)
	_cam.current = true


func _mirar(pos: Vector3, alvo: Vector3) -> void:
	_cam.position = pos
	_cam.look_at(alvo, Vector3.UP)


func _foto() -> Image:
	await process_frame
	await process_frame
	return _vp.get_texture().get_image()


func _folha(quadros: Array, rotulos: Array, nome: String) -> void:
	if _saida == "" or quadros.is_empty():
		return
	var linhas := ceili(float(quadros.size()) / COLUNAS)
	var folha := Image.create(QUADRO.x * COLUNAS, QUADRO.y * linhas, false, Image.FORMAT_RGBA8)
	folha.fill(Color.BLACK)
	for i in quadros.size():
		var img: Image = quadros[i]
		img.convert(Image.FORMAT_RGBA8)
		folha.blit_rect(img, Rect2i(Vector2i.ZERO, QUADRO),
			Vector2i((i % COLUNAS) * QUADRO.x, (i / COLUNAS) * QUADRO.y))
	DirAccess.make_dir_recursive_absolute(_saida)
	folha.save_png(_saida.path_join(nome))
	print("folha ", _saida.path_join(nome), "  ", rotulos)


func _pessoa(id: int) -> Corpo:
	var dono := Node3D.new()
	_mundo.add_child(dono)
	var c := Corpo.new()
	c.detalhado = true
	dono.add_child(c)
	c.montar(Aparencia.de_ficha({"id": id, "sexo": &"M", "idade": 33}))
	return c


func _atropelo() -> void:
	var c := _pessoa(31)
	var dono := c.get_parent() as Node3D
	# Andando para +x, de lado para o carro que vem por +z.
	dono.rotation.y = -PI * 0.5
	for i in 20:
		c.animar(1.3, 1.0 / 60.0)
		await physics_frame
	var carro := RigidBody3D.new()
	carro.mass = 1100.0
	carro.continuous_cd = true
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.7, 1.05, 4.2)
	f.shape = b
	f.position = Vector3(0.0, 0.22 + 0.525, 0.0)
	carro.add_child(f)
	var vis := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = b.size
	vis.mesh = bm
	vis.position = f.position
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color("8a2a24")
	vis.material_override = cm
	carro.add_child(vis)
	_mundo.add_child(carro)
	carro.global_position = Vector3(0.0, 0.0, 4.6)
	carro.linear_velocity = Vector3(0.0, 0.0, -9.0)
	_mirar(Vector3(6.5, 2.2, -1.5), Vector3(0.0, 0.7, -2.5))
	var boneco: BonecoDePano = null
	var quadros: Array = []
	var rotulos: Array = []
	var t := 0.0
	var marcas := [0.0, 0.12, 0.25, 0.4, 0.6, 0.9, 1.3, 2.0, 3.0, 4.5, 6.0, 7.0, 7.6, 8.2, 8.8, 9.5]
	var proxima := 0
	var de_pe := [false]
	var bateu := false
	while t < 14.0 and proxima < marcas.size():
		await physics_frame
		# Flag, e nao `boneco == null`: o boneco se libera ao levantar, e um
		# objeto liberado compara igual a null — a primeira versao atropelava
		# a pessoa de novo assim que ela ficava de pe.
		if not bateu:
			carro.linear_velocity.z = -9.0
			if carro.global_position.z - 2.1 < 0.4:
				bateu = true
				boneco = BonecoDePano.derrubar(c, Vector3(1.3, 0.0, 0.0), carro.linear_velocity,
					0.55, 0.6)
				boneco.levantou.connect(func(o: Vector3, r: float) -> void:
					de_pe[0] = true
					dono.global_position = o
					dono.rotation.y = r)
			continue
		t += 1.0 / 60.0
		# O carro freia depois da batida, como o motorista faria.
		carro.linear_velocity.z = move_toward(carro.linear_velocity.z, 0.0, 7.0 / 60.0)
		if de_pe[0]:
			c.animar(0.0, 1.0 / 60.0)
		if t >= float(marcas[proxima]):
			var foco := c.global_position + Vector3(0.0, 0.6, 0.0)
			_mirar(foco + Vector3(5.0, 2.0, 2.5), foco)
			quadros.append(await _foto())
			rotulos.append("%.2fs" % t)
			proxima += 1
	_folha(quadros, rotulos, "atropelo.png")
	carro.queue_free()
	dono.queue_free()
	await physics_frame


func _levantar(de_brucos: bool, nome: String) -> void:
	var c := _pessoa(44)
	c.dominado = true
	var ch := LevantarDoChao.chaves(de_brucos, c)
	var total := LevantarDoChao.duracao(ch)
	_mirar(Vector3(3.2, 1.1, -0.2), Vector3(0.0, 0.5, 0.1))
	var quadros: Array = []
	var rotulos: Array = []
	for i in 12:
		var t := total * float(i) / 11.0
		LevantarDoChao.aplicar(c, LevantarDoChao.pose_em(ch, t, c))
		quadros.append(await _foto())
		rotulos.append("%.2fs" % t)
	_folha(quadros, rotulos, nome)
	c.get_parent().queue_free()
	await process_frame
