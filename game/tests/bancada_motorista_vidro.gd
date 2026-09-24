## O motorista da IA visto de fora, pelo vidro: de lado, de tres quartos e de
## frente, a 4-6 m, com o estilo do jogo (cena: o EstiloVisual e autoload).
##
##     godot --path game --resolution 1280x720 res://tests/bancada_motorista_vidro.tscn -- --saida=DIR
##
## Existe porque a memoria "vidro da carroceria e opaco" (21/09) dizia que nenhum
## motorista aparece de fora; o vidro ganhou superficie e shader proprios depois.
extends Node

const QUADRO := Vector2i(480, 300)
var _saida := ""


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
	_rodar()


func _rodar() -> void:
	await get_tree().process_frame
	var mundo := Node3D.new()
	add_child(mundo)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("7d8a94")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b0aca0")
	ambiente.environment = env
	mundo.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	luz.light_energy = 1.3
	luz.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(-130.0), 0.0)
	mundo.add_child(luz)
	var chao := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(200.0, 1.0, 200.0)
	forma.shape = caixa
	forma.position = Vector3(0.0, -0.5, 0.0)
	chao.add_child(forma)
	mundo.add_child(chao)
	var piso := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200.0, 200.0)
	piso.mesh = pm
	mundo.add_child(piso)
	var c := (load("res://src/world/carro.gd") as GDScript).new() as VehicleBody3D
	c.set(&"modelo", 0)
	c.set(&"semente", 11)
	c.set(&"ficha", RegistroCivil.identidade(9191))
	c.set(&"motorista", 1)
	mundo.add_child(c)
	c.call(&"pousar", Vector3(0.0, 0.8, 0.0), 0.0)
	var cam := Camera3D.new()
	cam.fov = 45.0
	mundo.add_child(cam)
	cam.current = true
	for i in 30:
		await get_tree().physics_frame
	var fotos: Array[Image] = []
	for pos: Vector3 in [Vector3(-4.2, 1.5, 0.0), Vector3(-3.5, 1.6, -3.5), Vector3(0.0, 1.5, -5.5)]:
		cam.position = pos
		cam.look_at(Vector3(-0.35, 1.0, 0.0), Vector3.UP)
		for i in 4:
			await get_tree().process_frame
		fotos.append(get_viewport().get_texture().get_image())
	var folha := Image.create(QUADRO.x * 3, QUADRO.y, false, Image.FORMAT_RGBA8)
	for i in fotos.size():
		var img := fotos[i]
		img.convert(Image.FORMAT_RGBA8)
		img.resize(QUADRO.x, QUADRO.y)
		folha.blit_rect(img, Rect2i(Vector2i.ZERO, QUADRO), Vector2i(i * QUADRO.x, 0))
	if not _saida.is_empty():
		folha.save_png(_saida.path_join("motorista_vidro.png"))
	var m := c.get(&"_motorista_corpo") as Corpo
	print("[motorista_vidro] motorista montado: ", m != null)
	if m != null:
		var sk := m.esqueleto()
		var cab := sk.global_transform * sk.get_bone_global_pose(Corpo.Osso.CABECA)
		var quad := sk.global_transform * sk.get_bone_global_pose(Corpo.Osso.QUADRIL)
		var med: Dictionary = c.get(&"_medidas")
		print("[motorista_vidro] postura %s  quadril y %.2f  pescoco y %.2f  topo da cabeca ~%.2f  teto %s  corpo.y %.2f  altura %.2f" % [
			Corpo.Postura.keys()[m.postura_atual()], quad.origin.y, cab.origin.y,
			cab.origin.y + 0.25, med.get("altura_teto", med.get("altura", "?")), m.global_position.y, m.altura()])
	get_tree().quit()
