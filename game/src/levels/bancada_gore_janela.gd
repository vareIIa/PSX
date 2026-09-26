## Bancada do gore do padre na janela: so a `CabecaDoPadre`, sem corpo nem
## carro, fotografada a 0,40 m como a lente a ve no stare, depois de cada
## cabecada (dano 0..3), com a orbita vazia e o `OlhoSolto` pendurado.
##
##     G=.tools/Godot_v4.7.2-stable_win64_console.exe
##     $G --path game --resolution 3840x2160 res://scenes/test/bancada_gore_janela.tscn -- \
##        --fotos=DIR [--so=d0,d1,d2,d3,olho]
##
## A luz imita a do stare (fogo do capo de lado e de baixo, o vermelho do
## painel, o ceu da noite como reflexo): o ceu azul e o que a ferida
## espelhava. A palavra final e sempre na estrada (`--ver-estrada`).
extends Node3D

const DISTANCIA := 0.40
const FOV := 44.0
const ESCALA := 1.1
const SANGUE_NA_CARA := [0.0, 0.34, 0.66, 1.0]

var _pasta := ""
var _so: PackedStringArray = []
var _cam: Camera3D
var _cab: CabecaDoPadre
var _olho: OlhoSolto


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			_pasta = a.trim_prefix("--fotos=")
		elif a.begins_with("--so="):
			_so = a.trim_prefix("--so=").split(",")
	if not _pasta.is_empty():
		DirAccess.make_dir_recursive_absolute(_pasta)
	_palco()
	if not CabecaDoPadre._carregar():
		push_error("cabeca nao carrega")
		get_tree().quit(1)
		return
	_cab = CabecaDoPadre.new()
	add_child(_cab)
	_cab.scale = Vector3.ONE * ESCALA
	# O rosto olha -Z: vira para a lente, em +Z.
	_cab.rotation = Vector3(0.0, PI, 0.0)
	_cab.position = Vector3(0.0, 1.5, 0.0)
	_cab._montar()
	_cab.por_sorriso(0.6)
	_cam.global_position = _cab.global_position + Vector3(0.0, -0.02, DISTANCIA)
	_cam.look_at(_cab.global_position + Vector3(0.0, -0.02, 0.0), Vector3.UP)
	_olho = OlhoSolto.new()
	_olho.preparar(self)
	_rodar()


func _palco() -> void:
	var mundo := WorldEnvironment.new()
	var amb := Environment.new()
	var ceu := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.05, 0.08, 0.16)
	mat.sky_horizon_color = Color(0.16, 0.2, 0.3)
	mat.ground_bottom_color = Color(0.02, 0.02, 0.025)
	mat.ground_horizon_color = Color(0.1, 0.1, 0.12)
	ceu.sky_material = mat
	amb.background_mode = Environment.BG_SKY
	amb.sky = ceu
	amb.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	amb.ambient_light_energy = 0.5
	amb.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	amb.tonemap_mode = Environment.TONE_MAPPER_AGX
	amb.ssao_enabled = true
	mundo.environment = amb
	add_child(mundo)

	var fogo := OmniLight3D.new()
	fogo.light_color = Color(1.0, 0.62, 0.38)
	fogo.omni_range = 6.0
	fogo.light_energy = 2.4
	fogo.shadow_enabled = true
	fogo.position = Vector3(-1.8, 0.9, 1.4)
	add_child(fogo)
	var painel := OmniLight3D.new()
	painel.light_color = Color(1.0, 0.18, 0.12)
	painel.omni_range = 1.6
	painel.light_energy = 0.5
	painel.position = Vector3(0.15, 1.15, 0.55)
	add_child(painel)
	var lua := DirectionalLight3D.new()
	lua.rotation_degrees = Vector3(-50, 20, 0)
	lua.light_color = Color(0.6, 0.7, 1.0)
	lua.light_energy = 0.35
	add_child(lua)

	_cam = Camera3D.new()
	_cam.fov = FOV
	_cam.near = 0.02
	add_child(_cam)
	_cam.make_current()


func _quadros(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	if _pasta.is_empty():
		return
	var img := get_viewport().get_texture().get_image()
	var caminho := _pasta.path_join(nome + ".png")
	img.save_png(caminho)
	print("[bancada_gore] foto=%s" % caminho)


func _quer(nome: String) -> bool:
	return _so.is_empty() or _so.has(nome)


func _rodar() -> void:
	await _quadros(40)
	if _quer("olho_perto"):
		# O olho direito a 9 cm, um pouco de lado: o material do globo.
		var volta := _cam.global_transform
		var od := _cab.get_node("OlhoD") as Node3D
		var frente := _cab.global_basis.z.normalized() * -1.0
		_cam.global_position = od.global_position + frente * 0.09 \
			+ _cab.global_basis.x.normalized() * 0.025 + Vector3.UP * 0.01
		_cam.look_at(od.global_position, Vector3.UP)
		await _quadros(4)
		await _foto("olho_perto")
		_cam.global_transform = volta
	if _quer("boca"):
		# A boca de dentro: repouso, meio sorriso, sorriso inteiro, e os tres
		# visemas no meio sorriso (a fala do stare).
		for s: float in [0.0, 0.6, 1.0]:
			_cab.por_sorriso(s)
			await _quadros(6)
			await _foto("boca_s%02d" % int(s * 10.0))
		_cab.por_sorriso(0.6)
		for v: StringName in [&"A", &"O", &"M"]:
			_cab.falar([[0.0, v, 1.0], [5.0, &"repouso", 0.0]])
			await _quadros(20)
			await _foto("boca_%s" % v)
		_cab.falar([[0.0, &"repouso", 0.0]])
		await _quadros(20)
	for d in 4:
		_cab.por_dano(float(d))
		_cab.por_sangue(float(SANGUE_NA_CARA[d]))
		if _quer("d%d" % d):
			await _quadros(4)
			await _foto("d%d" % d)
	if _quer("olho"):
		_cab.por_orbita_vazia(1.0)
		var o := _cab.olho_esquerdo()
		var para := (_cam.global_position - o.global_position).normalized()
		_olho.soltar(_cab, o, para * 0.2 + Vector3.DOWN * 0.25)
		# O stare: o olho vai e volta no nervo; fotos no tempo da cena.
		var t := 0.0
		var marcas := [0.15, 0.4, 0.8, 1.4, 2.0]
		for m: float in marcas:
			while t < m:
				await get_tree().process_frame
				t += get_process_delta_time()
			await _foto("olho_%02d" % int(m * 10.0))
	print("[bancada_gore] fim")
	get_tree().quit()
