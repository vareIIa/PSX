## Bancada das pontas soltas do `RostoEnfaixado`: um romeiro com o tique
## rodando de verdade (o `TiqueMacabro.passo` DEPOIS do `Corpo.animar`, como a
## abertura faz), e uma rajada a 10 quadros por segundo da cabeca, sem capuz,
## para julgar se a ponta chicoteia no estalo e assenta.
##
##     $G --path game --resolution 3840x2160 res://scenes/test/bancada_pontas_romeiro.tscn -- \
##        --fotos=DIR [--segundos=4] [--semente=1] [--capuz]
##
## Tambem imprime `[pontas] ms_por_quadro=` (o custo medio da simulacao das
## pontas por quadro, medido em volta do `_process` do rosto).
extends Node3D

var _pasta := ""
var _segundos := 4.0
var _semente := 1
var _capuz := false
var _c: Corpo
var _tique: TiqueMacabro
var _cam: Camera3D


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			_pasta = a.trim_prefix("--fotos=")
		elif a.begins_with("--segundos="):
			_segundos = float(a.trim_prefix("--segundos="))
		elif a.begins_with("--semente="):
			_semente = int(a.trim_prefix("--semente="))
		elif a == "--capuz":
			_capuz = true
	DirAccess.make_dir_recursive_absolute(_pasta)
	var mundo := WorldEnvironment.new()
	var amb := Environment.new()
	amb.background_mode = Environment.BG_COLOR
	amb.background_color = Color(0.03, 0.03, 0.035)
	amb.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	amb.ambient_light_color = Color(0.5, 0.5, 0.55)
	amb.ambient_light_energy = 0.4
	amb.tonemap_mode = Environment.TONE_MAPPER_AGX
	mundo.environment = amb
	add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-35, 160, 0)
	sol.light_energy = 1.5
	sol.shadow_enabled = true
	add_child(sol)

	_c = Corpo.new()
	add_child(_c)
	var ombro := AberturaEstrada.OMBRO_ENCAPUZADO
	_c.montar(AberturaEstrada._aparencia_de_encapuzado(_semente, 1.82, ombro, false))
	_c.jeito = {"curvatura": 0.16, "cabeca": 0.22}
	var capuz := MonstroDaEstrada.vestir(_c, _semente, ombro / 0.42, false)
	if capuz != null and not _capuz:
		var pano := capuz.get_node_or_null("Pano") as Node3D
		if pano != null:
			pano.visible = false
	_c.basis = Basis(Vector3.UP, PI)
	_tique = TiqueMacabro.new(_c, 7, TiqueMacabro.Modo.FUNDO)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.near = 0.02
	add_child(_cam)
	_cam.make_current()
	_rodar()


func _process(delta: float) -> void:
	_c.dominado = false
	_c.animar(0.0, delta)
	_tique.passo(delta)


func _rodar() -> void:
	for _i in 30:
		await get_tree().process_frame
	var esq := _c.esqueleto()
	var cab := esq.global_transform * esq.get_bone_global_rest(Corpo.Osso.CABECA)
	var alvo := cab.origin + Vector3.UP * 0.05
	_cam.global_position = alvo + Vector3(0.25, 0.05, 1.1)
	_cam.look_at(alvo + Vector3.DOWN * 0.08, Vector3.UP)
	var t := 0.0
	var proxima := 0.0
	var quadros := 0
	var gasto := 0.0
	var rosto := _c.get_meta(&"rosto") as Node
	while t < _segundos:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		quadros += 1
		if t >= proxima and not _pasta.is_empty():
			proxima += 0.1
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
				_pasta.path_join("r_%.2f.png" % t))
	# O custo: um passo de fisica e o desenho das fitas, 200 vezes. No jogo sao
	# de 1 a 2 passos por quadro (90 Hz).
	if rosto != null:
		var xf: Transform3D = (rosto as Node3D).global_transform
		var t0 := Time.get_ticks_usec()
		for _i in 200:
			rosto.call(&"_simular", RostoEnfaixado.PASSO_FISICA, xf)
			rosto.call(&"_desenhar_fitas", xf)
		gasto = float(Time.get_ticks_usec() - t0) / 200.0
	print("[pontas] ms_por_passo=%.3f (%d quadros)" % [gasto / 1000.0, quadros])
	get_tree().quit()
