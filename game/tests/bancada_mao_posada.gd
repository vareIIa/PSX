## As poses da `MaoPosada`, lado a lado, de tres angulos: de cima e de tras
## (como o dono ve a propria mao), de lado e de frente.
##
##     godot --path game --resolution 1280x720 res://tests/bancada_mao_posada.tscn -- --saida=<DIR ABSOLUTO>
extends Node

var SP := ""
var cam: Camera3D


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			SP = a.trim_prefix("--saida=").path_join("")
	_rodar()


func _foto(nome: String, quadros: int = 3) -> void:
	for _i in quadros:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(SP + nome + ".png")


func _rodar() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(SP)
	var mundo := Node3D.new()
	add_child(mundo)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("30343c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8090a8")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	amb.environment = env
	mundo.add_child(amb)
	var sol := DirectionalLight3D.new()
	sol.light_energy = 1.2
	mundo.add_child(sol)
	sol.rotation = Vector3(-0.9, 0.5, 0.0)
	cam = Camera3D.new()
	cam.near = 0.02
	mundo.add_child(cam)
	cam.current = true

	var nomes: Array = MaoPosada.POSES.keys()
	var bracos: Array[BracoVivo] = []
	for i in nomes.size():
		var b := BracoVivo.criar("B%d" % i, true, Color(0.78, 0.62, 0.50),
			Color(0.82, 0.83, 0.86), true)
		mundo.add_child(b)
		var x := (float(i) - (nomes.size() - 1) * 0.5) * 0.16
		# A palma para baixo, os dedos para -Z, o ombro atras e acima.
		var o := Vector3(x, 0.0, 0.0)
		b.ombro = o + Vector3(0.12, 0.25, 0.5)
		b.polo = Vector3(1, -1, 0)
		b.pular(BracoVivo.pega(o, Vector3.FORWARD, Vector3.UP, nomes[i]))
		b.visible = true
		b.passo(0.0)
		bracos.append(b)
		var rot := Label3D.new()
		rot.text = String(nomes[i])
		rot.pixel_size = 0.0006
		rot.position = o + Vector3(0, 0.07, 0.05)
		rot.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mundo.add_child(rot)
	var largura := nomes.size() * 0.16
	cam.fov = 40.0
	cam.position = Vector3(0.0, 0.45, 0.55 + largura * 0.3)
	cam.look_at(Vector3(0, 0, -0.06), Vector3.UP)
	await _foto("00_de_cima")
	cam.position = Vector3(0.0, 0.10, -0.45 - largura * 0.35)
	cam.look_at(Vector3(0, -0.02, 0), Vector3.UP)
	await _foto("01_de_frente")
	cam.position = Vector3(0.0, -0.40, 0.2 + largura * 0.3)
	cam.look_at(Vector3(0, 0, -0.06), Vector3.UP)
	await _foto("02_de_baixo")
	# De perto, uma por uma, de lado.
	for i in nomes.size():
		var o := Vector3((float(i) - (nomes.size() - 1) * 0.5) * 0.16, 0.0, 0.0)
		cam.fov = 45.0
		cam.position = o + Vector3(-0.22, 0.06, -0.08)
		cam.look_at(o + Vector3(0, -0.01, -0.06), Vector3.UP)
		await _foto("10_lado_%s" % nomes[i], 2)
	var tr := Time.get_ticks_usec()
	for _i in 20:
		bracos[0].refazer()
	print("[bench] refazer %.2f ms" % [(Time.get_ticks_usec() - tr) / 20000.0])
	get_tree().quit(0)
