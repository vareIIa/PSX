## A tomada e o carregador do iPhone, e a bateria: encaixar o cubo, plugar o
## aparelho (fio ate o bolso), tira-lo com o fio no conector, deixa-lo no chao,
## pega-lo, andar para longe ate o plugue saltar, guardar o carregador; e a
## bateria zerando (spinner, pilha vazia) e voltando na tomada (maca, trava).
##
##     godot --path game --resolution 1920x1080 res://tests/bancada_carregador.tscn -- --saida=<DIR ABSOLUTO>
extends Node

var SP := ""
var jogador: Node3D
var tomada: Tomada


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			SP = a.trim_prefix("--saida=").path_join("")
	DirAccess.make_dir_recursive_absolute(SP)
	_rodar()


func _caixa(pai: Node3D, tam: Vector3, centro: Vector3, cor: Color) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.85
	mi.material_override = mat
	pai.add_child(mi)
	mi.position = centro
	var corpo := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = tam
	col.shape = forma
	corpo.add_child(col)
	mi.add_child(corpo)


func _passar(segundos: float) -> void:
	var fim := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < fim:
		await get_tree().process_frame


func _foto(nome: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SP + nome + ".png")
	print("[foto] ", nome)


func _rodar() -> void:
	await get_tree().process_frame
	var mundo := Node3D.new()
	add_child(mundo)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("16181c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8a8070")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	amb.environment = env
	mundo.add_child(amb)
	_caixa(mundo, Vector3(8.0, 0.2, 8.0), Vector3(0.0, -0.1, 0.0), Color("6a5440"))
	_caixa(mundo, Vector3(8.0, 2.5, 0.2), Vector3(0.0, 1.25, -0.1), Color("c9b9a0"))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.88, 0.7)
	lamp.light_energy = 1.6
	lamp.omni_range = 6.0
	lamp.shadow_enabled = true
	mundo.add_child(lamp)
	lamp.position = Vector3(0.6, 2.2, 1.2)
	tomada = Tomada.criar({"pos": Vector3(0.0, PontosDeTomada.ALTURA, 0.0), "giro": 0.0})
	mundo.add_child(tomada)

	jogador = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Node3D
	add_child(jogador)
	jogador.global_position = Vector3(0.15, 0.05, 1.1)
	Inventario.adicionar(&"carregador", 1)
	await _passar(0.6)
	jogador.call("definir_pitch", -0.75)
	await _passar(0.3)
	await _foto("00_tomada")
	print("[carregador] rotulo: ", tomada.rotulo_atual())

	tomada.interagir(jogador)
	await _passar(1.5)
	await _foto("01_cubo_e_fio")
	var pts: PackedVector3Array = tomada.get(&"_cabo").get(&"_p")
	print("[carregador] fio: ", pts[0], " ", pts[5], " ", pts[13], " ", pts[20], " ", pts[pts.size() - 1])
	print("[carregador] rotulo: ", tomada.rotulo_atual(), " | tem na bolsa: ", Inventario.tem(&"carregador"))

	tomada.interagir(jogador)
	await _passar(1.2)
	await _foto("02_plugado_no_bolso")
	print("[carregador] plugado=%s carregando=%s" % [Celular.plugado, Celular.carregando()])

	jogador.call("definir_pitch", -0.2)
	Celular.abrir()
	await _passar(1.4)
	await _foto("03_na_mao_com_fio")
	Celular.fechar()
	await _passar(0.8)

	jogador.call("definir_pitch", -0.75)
	tomada.interagir(jogador)
	await _passar(1.0)
	await _foto("04_no_chao")
	print("[carregador] longe=%s rotulo=%s" % [Celular.longe, tomada.rotulo_atual()])
	Celular.abrir()
	await _passar(0.3)
	print("[carregador] abriu longe? ", Celular.ativo)

	# De fora: o fio no chao entre a tomada e o aparelho.
	var fora := Camera3D.new()
	fora.fov = 45.0
	add_child(fora)
	fora.global_position = Vector3(0.9, 0.7, 1.1)
	fora.look_at(Vector3(0.0, 0.1, 0.3), Vector3.UP)
	fora.current = true
	await _passar(0.2)
	await _foto("05_de_fora_no_chao")
	var cam := jogador.call("camera") as Camera3D
	cam.current = true

	tomada.interagir(jogador)
	await _passar(0.5)
	# Anda para tras ate o fio esticar.
	for i in 40:
		jogador.global_position += Vector3(0.0, 0.0, 0.06)
		await get_tree().physics_frame
		if not Celular.plugado:
			print("[carregador] soltou a %.2f m da parede" % jogador.global_position.z)
			break
	await _passar(0.8)
	fora.current = true
	fora.global_position = Vector3(1.4, 1.1, 2.2)
	fora.look_at(Vector3(0.0, 0.2, 0.6), Vector3.UP)
	await _passar(0.4)
	await _foto("06_soltou_de_fora")
	cam.current = true
	print("[carregador] rotulo depois de soltar: ", tomada.rotulo_atual())

	# A bateria: zera com o aparelho na mao.
	Celular.bateria = 0.205
	Celular.abrir()
	await _passar(1.0)
	await _foto("07_bateria_20")
	Celular.call("_responder_alerta", 0)
	Celular.bateria = 0.0004
	await _passar(0.9)
	await _foto("08_desligando")
	await _passar(1.5)
	Celular.call("_input", _tecla(KEY_E))
	await _passar(0.2)
	await _foto("09_morto_pilha_vazia")
	Celular.fechar()
	await _passar(0.6)
	# Volta para perto e pluga: liga sozinho com a maca.
	jogador.global_position = Vector3(0.15, 0.05, 1.1)
	await _passar(0.3)
	# O plugue solto fica no chao; pluga pela tomada de novo.
	tomada.interagir(jogador)
	Celular.bateria = 0.019
	Celular.abrir()
	await _passar(1.5)
	await _foto("10_ligando_maca")
	await _passar(4.5)
	await _foto("11_ligou_trava")
	print("[carregador] ligado=%s bateria=%.3f" % [Celular.ligado(), Celular.bateria])
	get_tree().quit(0)


func _tecla(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	return e
