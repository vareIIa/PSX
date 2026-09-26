## Bancada do retrovisor interno: o reflexo esta certo, na mao certa, com o
## brilho certo?
##
##     godot --path game --resolution 1600x900 res://tests/bancada_retrovisor.tscn -- --saida=DIR [--noite] [--estilo=ps1]
##
## SEM --headless: o reflexo e um SubViewport de verdade.
##
## O que ela monta: o Marea parado num chao cinza, e ATRAS dele, a 7 m, um
## painel com uma coluna VERMELHA do lado do motorista (-x), uma VERDE do lado
## do carona (+x) e um "L" branco (le errado se a imagem estiver sem inverter),
## e a 18 m um par de farois de um carro vindo.
##
## O que ela mede, alem das fotos:
##   mao     no espelho, o vermelho tem de estar a ESQUERDA do verde (como num
##           retrovisor de verdade: o que esta atras a sua esquerda aparece do
##           lado esquerdo do espelho).
##   brilho  o painel cinza visto pelo espelho contra o mesmo painel visto
##           direto (virando a cabeca): a razao tem de ficar perto da
##           refletancia (~0,85).
##   custo   ms de quadro com e sem o espelho (`ativo`).
extends Node3D

const TAM_PAINEL := Vector2(5.0, 2.6)
const Z_PAINEL := 7.0

var _saida := ""
var _noite := false
var _modelo := "MAREA"
var _cab: CarroCabine
var _cam: Camera3D
var _carro: Node3D
var _vermelho_espelho := Color()


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			_saida = a.trim_prefix("--saida=")
		elif a.begins_with("--modelo="):
			_modelo = a.trim_prefix("--modelo=").to_upper()
		elif a == "--noite":
			_noite = true
	if _saida != "":
		DirAccess.make_dir_recursive_absolute(_saida)
	_montar()
	_rodar.call_deferred()


func _montar() -> void:
	var amb := WorldEnvironment.new()
	amb.add_to_group(&"fog_controller")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	if _noite:
		env.background_color = Color(0.02, 0.025, 0.035)
		env.ambient_light_color = Color(0.08, 0.09, 0.12)
	else:
		env.background_color = Color(0.55, 0.60, 0.66)
		env.ambient_light_color = Color(0.55, 0.57, 0.62)
	env.ambient_light_energy = 0.8
	env.fog_enabled = true
	env.fog_light_color = env.background_color
	env.fog_density = 0.01
	amb.environment = env
	add_child(amb)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-38.0, 150.0, 0.0)
	sol.light_energy = 0.10 if _noite else 1.0
	sol.shadow_enabled = true
	add_child(sol)

	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	chao.mesh = pm
	chao.material_override = _cor(Color(0.22, 0.22, 0.23))
	add_child(chao)

	_carro = Node3D.new()
	add_child(_carro)
	var medidas := Carroceria.montar(Carroceria.Modelo[_modelo] as Carroceria.Modelo, CarroCena.TINTA,
		CarroCena.SEMENTE, true, false)
	var lataria := MeshInstance3D.new()
	lataria.mesh = medidas["corpo"] as ArrayMesh
	_carro.add_child(lataria)
	# De dentro, o vidro de fora some (como `CarroCena.mostrar_cabine`).
	if lataria.mesh.get_surface_count() > 1:
		lataria.set_surface_override_material(1, CarroCena._material_invisivel())
	_cab = CarroCabine.new()
	_carro.add_child(_cab)
	_cab.montar(medidas)

	# O painel de teste, atras do carro (+Z e a traseira).
	var painel := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(TAM_PAINEL.x, TAM_PAINEL.y, 0.1)
	painel.mesh = bm
	painel.position = Vector3(0.0, 1.3, Z_PAINEL)
	painel.material_override = _cor(Color(0.5, 0.5, 0.5))
	add_child(painel)
	_caixa(Vector3(-1.0, 1.3, Z_PAINEL - 0.2), Vector3(0.6, 2.2, 0.2), Color(0.8, 0.06, 0.05))
	_caixa(Vector3(1.0, 1.3, Z_PAINEL - 0.2), Vector3(0.6, 2.2, 0.2), Color(0.06, 0.7, 0.10))
	# "L" visto de dentro do carro virando a cabeca: haste a esquerda do
	# observador que olha para +Z (isto e, em +x), pe indo para -x.
	_caixa(Vector3(0.35, 1.45, Z_PAINEL - 0.2), Vector3(0.18, 1.1, 0.2), Color(0.95, 0.95, 0.95))
	_caixa(Vector3(0.05, 0.99, Z_PAINEL - 0.2), Vector3(0.6, 0.18, 0.2), Color(0.95, 0.95, 0.95))
	# Farois de um carro atras.
	for s: float in [-0.65, 0.65]:
		var f := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.24
		f.mesh = sm
		var m := StandardMaterial3D.new()
		m.emission_enabled = true
		m.emission = Color(1.0, 0.95, 0.85)
		m.emission_energy_multiplier = 6.0
		m.albedo_color = Color.BLACK
		f.material_override = m
		f.position = Vector3(s + 2.8, 0.75, 18.0)
		add_child(f)

	# A luz de enchimento da cabine do `CarroCena`, igual.
	if _noite:
		var luz := OmniLight3D.new()
		luz.position = Vector3(-0.2, 1.15, -0.15)
		luz.omni_range = 2.4
		luz.light_energy = 0.32
		luz.light_color = Color(1.0, 0.92, 0.82)
		_carro.add_child(luz)

	_cam = Camera3D.new()
	_cam.near = 0.02
	add_child(_cam)
	_cam.make_current()


func _cor(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _caixa(p: Vector3, t: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = t
	mi.mesh = bm
	mi.position = p
	mi.material_override = _cor(c)
	add_child(mi)


func _olho() -> Vector3:
	# O olho do plano de dentro da abertura: o do suporte, 20 cm para tras.
	return _cab.olho() + Vector3(0.0, 0.0, 0.20)


func _vista(nome: String, fov: float, olhar: Vector3, de: Vector3 = Vector3.INF) -> void:
	var o := _olho() if de == Vector3.INF else de
	_cam.fov = fov
	_cam.global_transform = Transform3D(Basis(), o).looking_at(olhar, Vector3.UP)
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if _saida != "":
		img.save_png(_saida.path_join("retro_%s_%s%s.png" % [_modelo.to_lower(), nome, "_noite" if _noite else ""]))
	print("[retro] %s ok (quadros do espelho=%d, imagem=%s)" % [nome,
		_cab.retrovisor.quadros, _cab.retrovisor.imagem().get_size()
			if _cab.retrovisor.imagem() != null else Vector2.ZERO])


func _rodar() -> void:
	# Deixa a exposicao automatica assentar.
	for i in 90:
		await get_tree().process_frame
	var r := _cab.retrovisor
	var pl := r.plano()
	var centro := pl.origin
	print("[retro] vidro em %s normal %s olho %s" % [centro, pl.basis.z, _olho()])
	# A estrada, como no plano de dentro.
	await _vista("frente", 66.0, _olho() + Vector3(0, -0.04, -1.0))
	# O espelho de perto, do olho.
	await _vista("espelho", 14.0, centro)
	_medir_mao()
	# Virando a cabeca: o painel direto.
	await _vista("tras", 40.0, Vector3(0.0, 1.3, Z_PAINEL))
	_brilho()
	# De fora, pelo para-brisa: o espelho de costas, so a carcaca.
	await _vista("fora", 40.0, centro, Vector3(0.6, 1.5, -4.5))
	await _vista("carona", 30.0, centro, _olho() + Vector3(0.8, 0.0, 0.1))
	await _custo()
	get_tree().quit(0)


## Centroide do vermelho e do verde na foto do espelho.
func _medir_mao() -> void:
	var img := get_viewport().get_texture().get_image()
	var sv := Vector2.ZERO
	var nv := 0
	var sg := Vector2.ZERO
	var ng := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if c.r > 0.25 and c.r > c.g * 2.2 and c.r > c.b * 2.2:
				sv += Vector2(x, y)
				nv += 1
			elif c.g > 0.20 and c.g > c.r * 1.8 and c.g > c.b * 1.8:
				sg += Vector2(x, y)
				ng += 1
	if nv == 0 or ng == 0:
		print("[retro] MAO: sem cor suficiente (vermelho %d, verde %d)" % [nv, ng])
		return
	var v := sv / nv
	var g := sg / ng
	_vermelho_espelho = _media(img, v)
	print("[retro] MAO: vermelho x=%.0f verde x=%.0f -> %s" % [v.x, g.x,
		"CERTA" if v.x < g.x else "INVERTIDA"])


## A mesma coluna vermelha vista direto: a razao espelho/direto e a
## refletancia que chegou na tela (depois do AgX, entao so aproximada).
func _brilho() -> void:
	var img := get_viewport().get_texture().get_image()
	var s := Vector2.ZERO
	var n := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if c.r > 0.25 and c.r > c.g * 2.2 and c.r > c.b * 2.2:
				s += Vector2(x, y)
				n += 1
	if n == 0 or _vermelho_espelho.r == 0.0:
		print("[retro] BRILHO: sem vermelho direto (%d)" % n)
		return
	var d := _media(img, s / n)
	print("[retro] BRILHO: vermelho no espelho %s, direto %s, razao R %.2f"
		% [_vermelho_espelho, d, _vermelho_espelho.r / maxf(0.001, d.r)])


func _media(img: Image, c: Vector2) -> Color:
	var soma := Color(0, 0, 0, 0)
	var n := 0
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var x := clampi(int(c.x) + dx, 0, img.get_width() - 1)
			var y := clampi(int(c.y) + dy, 0, img.get_height() - 1)
			soma += img.get_pixel(x, y)
			n += 1
	return soma / float(n)


func _custo() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _vista("frente", 66.0, _olho() + Vector3(0, -0.04, -1.0))
	var r := _cab.retrovisor
	var vp_espelho := r.get_node("Reflexo") as SubViewport
	RenderingServer.viewport_set_measure_render_time(vp_espelho.get_viewport_rid(), true)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var com := await _ms(240)
	var gpu_e := RenderingServer.viewport_get_measured_render_time_gpu(vp_espelho.get_viewport_rid())
	var cpu_e := RenderingServer.viewport_get_measured_render_time_cpu(vp_espelho.get_viewport_rid())
	var gpu_t := RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
	r.ativo = false
	var sem := await _ms(240)
	r.ativo = true
	print("[retro] CUSTO: quadro com espelho %.2f ms, sem %.2f ms; espelho gpu %.2f cpu %.2f ms (tela gpu %.2f), imagem %s"
		% [com, sem, gpu_e, cpu_e, gpu_t, vp_espelho.size])


func _ms(n: int) -> float:
	var t0 := Time.get_ticks_usec()
	for i in n:
		await get_tree().process_frame
	return float(Time.get_ticks_usec() - t0) / 1000.0 / float(n)
