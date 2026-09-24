## Bancada da dor: a cara no tombo, a mao onde doi e o mancar, em folha de
## contato.
##
##     godot --path game --resolution 1280x720 --script res://tests/bancada_dor.gd -- --saida=DIR
##
##   cara.png       close da cabeca num atropelo: susto, medo no ar, careta na
##                  pancada, gemido no chao, careta levantando. O rotulo traz a
##                  expressao que o `Rosto` diz estar mostrando.
##   apagado.png    o mesmo com pancada feia: olho fechado no chao (desacordado)
##   mancando.png   de lado, um ciclo de passo mancando da perna direita, e
##                  embaixo o mesmo ciclo sem mancar
##
## A regua da cara e o rotulo; a foto diz se le como dor.
extends SceneTree

const QUADRO := Vector2i(300, 240)
const COLUNAS := 4
const DT := 1.0 / 60.0

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
	if not OS.get_cmdline_user_args().has("--so-mancar"):
		await _tombo(31, 0.6, 9.0, "cara.png")
		await _tombo(12, 1.0, 12.0, "apagado.png")
	await _mancar()
	await _agarra()
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
	ambiente.environment = env
	_mundo.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	luz.light_energy = 1.4
	luz.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(-140.0), 0.0)
	_mundo.add_child(luz)
	var chao := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(80.0, 1.0, 80.0)
	forma.shape = caixa
	forma.position = Vector3(0.0, -0.5, 0.0)
	chao.add_child(forma)
	_mundo.add_child(chao)
	var piso := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80.0, 80.0)
	piso.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color("707a80")
	piso.material_override = pmat
	_mundo.add_child(piso)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_mundo.add_child(_cam)
	_cam.current = true


func _foto() -> Image:
	await process_frame
	await process_frame
	return _vp.get_texture().get_image()


func _folha(quadros: Array, rotulos: Array, nome: String) -> void:
	if _saida == "" or quadros.is_empty():
		return
	var linhas := ceili(float(quadros.size()) / COLUNAS)
	var folha := Image.create(QUADRO.x * COLUNAS, QUADRO.y * linhas, false, Image.FORMAT_RGBA8)
	for i in quadros.size():
		var img: Image = quadros[i]
		img.convert(Image.FORMAT_RGBA8)
		folha.blit_rect(img, Rect2i(Vector2i.ZERO, QUADRO),
			Vector2i((i % COLUNAS) * QUADRO.x, (i / COLUNAS) * QUADRO.y))
	DirAccess.make_dir_recursive_absolute(_saida)
	folha.save_png(_saida.path_join(nome))
	print("folha ", nome, "  ", rotulos)


func _pessoa(id: int) -> Corpo:
	var dono := Node3D.new()
	_mundo.add_child(dono)
	var c := Corpo.new()
	c.detalhado = true
	dono.add_child(c)
	c.montar(Aparencia.de_ficha({"id": id, "sexo": &"M", "idade": 33}))
	return c


func _cabeca(c: Corpo) -> Transform3D:
	var sk := c.esqueleto()
	return sk.global_transform * sk.get_bone_global_pose(Corpo.Osso.CABECA)


## A lente vai para a frente da cara (a -Z do osso da cabeca), sempre acima do
## chao, e olha para ela.
func _close(c: Corpo) -> void:
	var cab := _cabeca(c)
	var cara := cab * Vector3(0.0, 0.12, 0.0)
	var frente := -cab.basis.z
	var pos := cara + frente * 0.75 + Vector3.UP * 0.15
	pos.y = maxf(pos.y, 0.35)
	_cam.position = pos
	_cam.look_at(cara, Vector3.UP if absf((cara - pos).normalized().y) < 0.95 else Vector3.FORWARD)


func _tombo(id: int, pancada: float, golpe: float, nome: String) -> void:
	var c := _pessoa(id)
	var dono := c.get_parent() as Node3D
	dono.rotation.y = -PI * 0.5
	for i in 20:
		c.animar(1.3, DT)
		await physics_frame
	var boneco := BonecoDePano.derrubar(c, Vector3(1.3, 0.0, 0.0), Vector3(0.0, 0.0, -golpe),
		0.55, pancada)
	var de_pe := [false]
	boneco.levantou.connect(func(o: Vector3, r: float) -> void:
		de_pe[0] = true
		dono.global_position = o
		dono.rotation.y = r)
	var marcas := [0.05, 0.3, 0.7, 1.4, 2.4, 3.4, 4.4, 5.4, 6.4, 7.4, 8.4, 9.4]
	var quadros: Array = []
	var rotulos: Array = []
	var proxima := 0
	var t := 0.0
	var dor := {}
	while t < 14.0 and proxima < marcas.size():
		await physics_frame
		t += DT
		if not de_pe[0] and is_instance_valid(boneco):
			dor = boneco.onde_doi()
		if de_pe[0]:
			c.animar(0.0, DT)
		elif c.rosto != null:
			c.rosto.passo(DT)
		if t >= float(marcas[proxima]):
			_close(c)
			quadros.append(await _foto())
			var fase := "de pe" if de_pe[0] else String(BonecoDePano.Fase.keys()[boneco.fase])
			rotulos.append("%.1fs %s %s" % [t, fase,
				Rosto.Expressao.keys()[c.rosto.expressao_atual()] if c.rosto != null else "-"])
			proxima += 1
	print("onde doi: ", dor)
	_folha(quadros, rotulos, nome)
	dono.queue_free()
	await physics_frame


func _mancar() -> void:
	var quadros: Array = []
	var rotulos: Array = []
	for vista: Array in [[1.0, false], [0.0, false], [1.0, true], [0.0, true]]:
		var manca: float = vista[0]
		var c := _pessoa(31)
		c.mancando = manca
		c.perna_ruim = 1
		(c.get_parent() as Node3D).rotation.y = -PI * 0.5
		for i in 40:
			c.animar(1.1, DT)
		# De lado, ou de frente (a pessoa anda para +x).
		_cam.position = Vector3(3.4, 1.0, 0.3) if vista[1] else Vector3(0.6, 1.0, 3.2)
		_cam.look_at(Vector3(0.0, 0.85, 0.0), Vector3.UP)
		# Um ciclo de passo em oito quadros (o ciclo inteiro e 15 poses).
		for k in 8:
			for i in 7:
				c.animar(1.1, DT)
			quadros.append(await _foto())
			rotulos.append("%s %s %d" % ["manca" if manca > 0.0 else "normal",
				"frente" if vista[1] else "lado", k])
		c.get_parent().queue_free()
		await process_frame
	_folha(quadros, rotulos, "mancando.png")


## Quem tropeca se segura no ombro do vizinho: de frente e de cima.
func _agarra() -> void:
	var c := _pessoa(31)
	var outro := _pessoa(12)
	(outro.get_parent() as Node3D).position = Vector3(0.0, 0.0, -0.8)
	(outro.get_parent() as Node3D).rotation.y = PI * 0.5
	c.debater = 0.5
	c.inclinacao = Vector2(0.0, 0.15)
	for i in 20:
		outro.animar(0.0, DT)
		c.agarrar = outro.global_position + Vector3.UP * 1.3
		c.animar(0.0, DT)
	var quadros: Array = []
	for vista: Vector3 in [Vector3(2.4, 1.4, -0.4), Vector3(-2.2, 1.6, 1.2), Vector3(0.3, 3.2, 0.2)]:
		_cam.position = vista
		_cam.look_at(Vector3(0.0, 1.0, -0.4), Vector3.UP if vista.y < 3.0 else Vector3.FORWARD)
		quadros.append(await _foto())
	_folha(quadros, ["lado", "tras", "cima"], "agarra.png")
