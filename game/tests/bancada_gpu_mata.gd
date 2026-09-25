extends Node3D
# Bancada: GPU da mata da estrada com a camera parada (A/B com --mata-caixa).
# godot --path game --resolution 3840x2160 res://tests/bancada_gpu_mata.tscn -- [--mata-caixa]
# Tres lentes: do carro (1,1 m), de lado (5,6 m do eixo) e aerea (41 m); mediana de 150 quadros.

var _cam: Camera3D
var _vp: RID


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.28, 0.3)
	env.fog_enabled = true
	env.fog_density = 0.012
	env.fog_light_color = Color(0.3, 0.33, 0.36)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.32, 0.35)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40, 30, 0)
	sol.light_energy = 0.3
	add_child(sol)
	var eb := EstradaBuilder.new()
	add_child(eb)
	eb.atualizar(150.0)
	for i in 400:
		eb.atualizar(150.0)
		await get_tree().process_frame
	_cam = Camera3D.new()
	_cam.fov = 62.0
	add_child(_cam)
	_cam.current = true
	var farol := SpotLight3D.new()
	farol.spot_range = 45.0
	farol.spot_angle = 30.0
	farol.light_energy = 6.0
	_cam.add_child(farol)
	_vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	var s := 150.0
	var p := EstradaBuilder.ponto_em(s)
	var dir := EstradaBuilder.direcao_em(s)
	var lado := EstradaBuilder.lado_em(s)
	await _medir("carro", p + Vector3.UP * 1.1, p + dir * 30.0 + Vector3.UP * 1.0)
	await _medir("lado", p + lado * 5.6 + Vector3.UP * 1.05, p + dir * 20.0 + Vector3.UP * 0.8)
	await _medir("aerea", p - dir * 25.0 + Vector3.UP * 41.0, p + dir * 70.0)
	get_tree().quit()


func _medir(nome: String, de: Vector3, para: Vector3) -> void:
	_cam.position = de
	_cam.look_at(para, Vector3.UP)
	for i in 40:
		await get_tree().process_frame
	var v := PackedFloat32Array()
	for i in 150:
		await get_tree().process_frame
		v.append(RenderingServer.viewport_get_measured_render_time_gpu(_vp))
	v.sort()
	print("[gpu] %s mediana %.2f p10 %.2f ms" % [nome, v[v.size() / 2], v[v.size() / 10]])
