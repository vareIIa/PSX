## Bancada do braco AAA do padre (`BracoDoPadre`): os dois bracos num ombro de
## dois metros, fotografados em cada pose de mao da `MaoPosada`, perto da lente
## (18 cm e 5 cm, como no agarrao), esticando ate o alvo (IK) e com o ombro
## sacudindo (o pano).
##
##     G=.tools/Godot_v4.7.2-stable_win64_console.exe
##     $G --path game --resolution 1920x1080 res://scenes/test/bancada_braco_padre.tscn -- \
##        --fotos=DIR [--so=plano,plano] [--rajada]
##
## Planos: `pendurados`, `poses` (uma foto por pose, mao direita e esquerda),
## `agarrao` (a garra a 18 cm e a mao a 5 cm), `alcance` (a mao indo de perto
## a longe do ombro) e `pano` (o ombro sacudindo). `--rajada` grava 10 quadros
## por segundo nos planos que andam.
extends Node3D

const OMBRO := Vector3(0.24, 1.48, 0.0)
const ESPERA := 20
const POSES := [&"relaxada", &"aberta", &"estica", &"apoio", &"apoio_forca", &"aponta",
	&"garra", &"pegar", &"pinca", &"punho"]

var _pasta := ""
var _so: PackedStringArray = []
var _rajada := false
var _cam: Camera3D
var _d: BracoDoPadre
var _e: BracoDoPadre
var _luz_perto: OmniLight3D


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			_pasta = a.trim_prefix("--fotos=")
		elif a.begins_with("--so="):
			_so = a.trim_prefix("--so=").split(",")
		elif a == "--rajada":
			_rajada = true
	DirAccess.make_dir_recursive_absolute(_pasta)
	var amb := WorldEnvironment.new()
	amb.environment = Environment.new()
	amb.environment.background_mode = Environment.BG_COLOR
	amb.environment.background_color = Color(0.05, 0.055, 0.06)
	amb.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	amb.environment.ambient_light_color = Color(0.22, 0.23, 0.25)
	amb.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(amb)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-35.0, 30.0, 0.0)
	sol.light_energy = 1.4
	sol.shadow_enabled = true
	add_child(sol)
	var contra := DirectionalLight3D.new()
	contra.rotation_degrees = Vector3(-20.0, 200.0, 0.0)
	contra.light_energy = 0.5
	contra.light_color = Color(0.7, 0.8, 1.0)
	add_child(contra)
	_luz_perto = OmniLight3D.new()
	_luz_perto.omni_range = 1.2
	_luz_perto.light_energy = 0.0
	_luz_perto.light_color = Color(1.0, 0.55, 0.35)
	add_child(_luz_perto)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.near = 0.01
	add_child(_cam)
	_cam.current = true
	_d = BracoDoPadre.novo("BracoD", true)
	_e = BracoDoPadre.novo("BracoE", false)
	add_child(_d)
	add_child(_e)
	_d.visible = true
	_e.visible = true
	_d.layers = 1
	_e.layers = 1
	_rodar()


func _pendurar() -> void:
	# Os bracos pendurados, a palma para o corpo, o cotovelo para tras.
	for b: BracoDoPadre in [_d, _e]:
		var lado := 1.0 if b.direita else -1.0
		b.ombro = Vector3(OMBRO.x * lado, OMBRO.y, OMBRO.z)
		b.polo = Vector3(0.0, -0.3, -1.0).normalized()
		b.pular(BracoVivo.pega(b.ombro + Vector3(0.03 * lado, -0.62, 0.08), Vector3.DOWN,
			Vector3(lado, 0.0, 0.0), &"relaxada"))


func _quadros(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _passo(delta: float) -> void:
	_d.passo(delta)
	_e.passo(delta)


func _process(delta: float) -> void:
	_passo(delta)


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_pasta.path_join(nome + ".png"))
	print("[bancada_braco] foto=", nome)


func _quer(p: String) -> bool:
	return _so.is_empty() or _so.has(p)


func _rodar() -> void:
	await _quadros(ESPERA)
	_pendurar()
	if _quer("pendurados"):
		_cam.global_position = Vector3(0.0, 1.2, 1.5)
		_cam.look_at(Vector3(0.0, 1.05, 0.0))
		await _quadros(ESPERA)
		await _foto("pendurados_frente")
		_cam.global_position = Vector3(1.4, 1.2, 0.4)
		_cam.look_at(Vector3(0.0, 1.05, 0.0))
		await _quadros(4)
		await _foto("pendurados_lado")
	if _quer("poses"):
		# A mao direita na frente da lente, dorso para ela, os dedos para cima.
		_cam.global_position = Vector3(0.1, 1.35, 0.75)
		_cam.look_at(Vector3(0.1, 1.35, 0.0))
		for b: BracoDoPadre in [_d, _e]:
			var lado := 1.0 if b.direita else -1.0
			_pendurar()
			for nome: StringName in POSES:
				var o := Vector3(0.14 * lado, 1.30, 0.40)
				b.pular(BracoVivo.pega(o, Vector3(0.0, 1.0, 0.15), Vector3(0.0, 0.0, 1.0), nome))
				b.polo = Vector3(lado, -0.6, -0.4).normalized()
				await _quadros(10)
				await _foto("pose_%s_%s" % ["d" if b.direita else "e", nome])
	if _quer("agarrao"):
		_pendurar()
		_luz_perto.global_position = Vector3(0.3, 1.5, 0.9)
		_luz_perto.light_energy = 1.2
		_cam.global_position = Vector3(0.0, 1.45, 0.62)
		_cam.look_at(Vector3(0.0, 1.45, 0.0))
		var fwd := -_cam.global_basis.z
		var cima := _cam.global_basis.y
		var dir := _cam.global_basis.x
		# a garra a 18 cm, de dorso, os dedos curvados para a lente
		_d.polo = Vector3(1.0, -0.8, -0.2).normalized()
		_d.pular(BracoVivo.pega(_cam.global_position + fwd * 0.18 - cima * 0.03 - dir * 0.03,
			(cima + dir * 0.4).normalized(), -fwd, AgarraoDoPadre.POSES[&"garra"]))
		await _quadros(14)
		await _foto("agarrao_garra_18cm")
		_d.pular(BracoVivo.pega(_cam.global_position + fwd * 0.045 + dir * 0.02,
			(cima + dir * 0.35).normalized(), -fwd, AgarraoDoPadre.POSES[&"tapa"]))
		_d.set_instance_shader_parameter(&"perto_da_lente", 1.0)
		await _quadros(14)
		await _foto("agarrao_tapa_5cm")
		_d.set_instance_shader_parameter(&"perto_da_lente", 0.0)
		_d.set_instance_shader_parameter(&"sangue", 0.85)
		_d.pular(BracoVivo.pega(_cam.global_position + fwd * 0.30,
			(cima).normalized(), fwd, &"apoio"))
		await _quadros(14)
		await _foto("palma_com_sangue")
		_d.set_instance_shader_parameter(&"sangue", 0.0)
		_luz_perto.light_energy = 0.0
	if _quer("alcance"):
		_pendurar()
		_cam.global_position = Vector3(1.3, 1.35, 0.9)
		_cam.look_at(Vector3(0.2, 1.2, 0.3))
		_d.polo = Vector3(0.6, -0.5, -0.6).normalized()
		var n := 24
		for k in n:
			var t := float(k) / float(n - 1)
			var alvo := OMBRO + Vector3(0.05, -0.35 + 0.45 * t, 0.15 + 0.75 * t)
			_d.pular(BracoVivo.pega(alvo, Vector3(0.0, 0.2, 1.0), Vector3(0.0, 1.0, 0.0), &"aberta"))
			await _quadros(3)
			if _rajada or k % 6 == 0 or k == n - 1:
				await _foto("alcance_%02d" % k)
	if _quer("pano"):
		_pendurar()
		_cam.global_position = Vector3(1.2, 1.2, 1.0)
		_cam.look_at(Vector3(0.1, 1.2, 0.0))
		var t0 := 0.0
		for k in 90:
			t0 += 1.0 / 30.0
			var sacode := Vector3(sin(t0 * 9.0) * 0.12, sin(t0 * 5.0) * 0.05, 0.0) \
				* (1.0 if t0 < 1.5 else 0.0)
			_d.ombro = OMBRO + sacode
			_d.pular(BracoVivo.pega(_d.ombro + Vector3(0.03, -0.62, 0.08), Vector3.DOWN,
				Vector3.RIGHT, &"relaxada"))
			await _quadros(1)
			if _rajada or k % 10 == 0:
				await _foto("pano_%02d" % k)
	print("[bancada_braco] fim")
	get_tree().quit()
