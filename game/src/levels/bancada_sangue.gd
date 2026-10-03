## Bancada da Parte 2 (a boca sangrando e o sangue na lente): so a
## `CabecaDoPadre` destruida (dano 3), a 0,45 m da lente, falando "que bom que
## voce veio" com o cuspe; depois a lama do impacto; depois ele por cima,
## pingando na lente (o ultimo olhar).
##
##     G=.tools/Godot_v4.7.2-stable_win64_console.exe
##     $G --path game --resolution 3840x2160 res://scenes/test/bancada_sangue.tscn -- \
##        --fotos=DIR [--rajada]
##
## Atras dele, placas acesas de cores diferentes: e nelas que se ve a lente
## refratar. A luz e a do stare (`bancada_gore_janela`).
extends Node3D

const DISTANCIA := 0.45
const ESCALA := 1.1
## As fotos (s de bancada) e o que acontece em cada tempo.
const FOTOS := [0.25, 0.42, 0.9, 1.6, 2.2, 2.9, 4.8, 5.7, 7.2, 8.9, 10.6]
const LAMA_EM := 5.5
const PINGA_EM := 7.4

var _pasta := ""
var _rajada := false
var _cam: Camera3D
var _cab: CabecaDoPadre
var _t := 0.0
var _fotos := FOTOS.duplicate()
var _lama := false
var _pinga := false
var _rajada_prox := 0.2


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			_pasta = a.trim_prefix("--fotos=")
		elif a == "--rajada":
			_rajada = true
	if not _pasta.is_empty():
		DirAccess.make_dir_recursive_absolute(_pasta)
	set_process(false)
	_palco()
	if not CabecaDoPadre._carregar():
		push_error("cabeca nao carrega")
		get_tree().quit(1)
		return
	_cab = CabecaDoPadre.new()
	add_child(_cab)
	_cab.scale = Vector3.ONE * ESCALA
	_cab.rotation = Vector3(0.0, PI, 0.0)
	_cab.position = Vector3(0.0, 1.5, 0.0)
	_cab._montar()
	if _cab.dentes() != null:
		_cab.dentes().quebra_dentes = true
	_cab.rasga_boca = true
	_cam.global_position = _cab.global_position + Vector3(0.0, -0.05, DISTANCIA)
	_cam.look_at(_cab.global_position + Vector3(0.0, -0.05, 0.0), Vector3.UP)
	var olho := OlhoSolto.new()
	olho.preparar(self)
	for d in 4:
		_cab.por_dano(float(d))
	_cab.por_sangue(1.0)
	_cab.por_orbita_vazia(1.0)
	_cab.por_sorriso(0.35)
	CuspeDeSangue.de(self)
	await _quadros(30)
	_t = 0.0
	print("[bancada_sangue] fala")
	_cab.falar(CabecaDoPadre.FALA_QUE_BOM)
	set_process(true)


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
	amb.tonemap_mode = Environment.TONE_MAPPER_AGX
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
	# O fundo aceso: o fogo, a noite e um farol, para a lente ter o que entortar.
	for c: Array in [[Color(1.0, 0.45, 0.12), Vector3(-0.9, 1.3, -1.5), Vector2(0.9, 1.4)],
			[Color(0.25, 0.35, 0.6), Vector3(0.8, 1.7, -1.8), Vector2(1.2, 1.0)],
			[Color(0.9, 0.9, 0.8), Vector3(0.35, 1.25, -1.2), Vector2(0.12, 0.12)]]:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = c[2]
		q.mesh = qm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c[0]
		q.material_override = m
		q.position = c[1]
		add_child(q)
	_cam = Camera3D.new()
	_cam.fov = 48.0
	_cam.near = 0.01
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
	img.save_png(_pasta.path_join(nome + ".png"))
	# O acumulador cru (R sangue, G lama, B frescor), para a bancada medir.
	var ac := SangueNaLente.de(self)._vp.get_texture().get_image()
	ac.convert(Image.FORMAT_RGBA8)
	ac.save_png(_pasta.path_join(nome + "_acum.png"))
	print("[bancada_sangue] foto=%s" % nome)


func _process(delta: float) -> void:
	if _cab == null:
		return
	_t += delta
	if not _fotos.is_empty() and _t >= float(_fotos[0]):
		var t: float = _fotos.pop_front()
		_foto("s_%04.1f" % t)
	if _rajada and _t >= _rajada_prox and _t < 3.2:
		_rajada_prox += 1.0 / 30.0
		_foto("r_%05.2f" % _t)
	if not _lama and _t >= LAMA_EM:
		_lama = true
		# O impacto no chao: lama com sangue de baixo para cima, e respingo.
		var lente := SangueNaLente.de(self)
		lente.lama(Vector2(0.28, 0.86), 0.26, 0.35)
		lente.lama(Vector2(0.62, 0.95), 0.2, 0.2)
		lente.lama(Vector2(0.12, 0.62), 0.12, 0.5)
		lente.respingo(Vector2(0.45, 0.7), 0.05, 1.2, Vector2(0.3, -1.0))
		print("[bancada_sangue] lama")
	if not _pinga and _t >= PINGA_EM:
		_pinga = true
		# O ultimo olhar: ele por cima, a cara descendo sobre a lente.
		_cam.global_position = _cab.global_position + Vector3(0.05, -0.42, 0.12)
		_cam.look_at(_cab.global_position + Vector3(0.0, -0.08, 0.0), Vector3.FORWARD)
		CuspeDeSangue.de(self).pingar_na_lente(_cab, 3.0)
		print("[bancada_sangue] pinga")
	if _fotos.is_empty() and _t > 11.0:
		print("[bancada_sangue] fim")
		get_tree().quit()
