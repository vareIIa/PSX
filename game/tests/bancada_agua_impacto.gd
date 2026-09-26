## Bancada da agua nos vidros: o Marea batido com a cabine, a chuva travada, o
## fogo no capo, a luz vermelha do painel, padres parados do lado de fora dos
## tres vidros do ataque e pancadas em tempos fixos (a mesma chamada de grupo que
## o cerco e a cena fazem: `agua_no_vidro.impacto`). Uma camera no olho do
## motorista, quatro vistas em sequencia.
##
##     G=.tools/Godot_v4.7.2-stable_win64_console.exe
##     $G --path game --resolution 3840x2160 --fixed-fps 30 \
##        res://tests/bancada_agua_impacto.tscn -- --chuva=1 --fotos=DIR \
##        [--agua-antiga] [--ate=S] [--sem-fotos-cheias]
##
## Saida em DIR: `f_<vista>_<t>.jpg` (4K) nos instantes parados, e
## `r/r_<t>.jpg` (1920x1080) em todo quadro do primeiro 0,8 s depois de cada
## pancada — o formato do `tools/mosaico_rajada.py`. No log, `[gpu]` por vista:
## media e p10 do tempo de GPU do quadro (ms), para o A/B com `--agua-antiga`.
extends Node3D

## [inicio (s), vista]
const VISTAS := [[0.0, "parabrisa"], [14.0, "motorista"], [21.0, "carona"],
	[26.0, "parabrisa"]]
## [t, vidro, (x, y) no vidro em fracao do centro (m), forca, tipo]
## tipo: 0 mao, 1 cabecada (sangue e tranco), 2 so o tranco do carro.
const PANCADAS := [
	[9.0, "parabrisa", Vector2(-0.30, -0.02), 0.35, 0],
	[10.0, "parabrisa", Vector2(-0.12, 0.02), 0.8, 1],
	[11.5, "parabrisa", Vector2(-0.10, 0.05), 1.0, 1],
	[15.0, "motorista", Vector2(0.14, 0.10), 0.35, 0],
	[16.0, "motorista", Vector2(-0.02, -0.04), 0.55, 1],
	[17.5, "motorista", Vector2(-0.03, -0.02), 0.8, 1],
	[19.0, "motorista", Vector2(-0.05, 0.01), 1.0, 1],
	[22.0, "carona", Vector2(0.12, -0.02), 0.3, 0],
	[23.0, "carona", Vector2(-0.04, -0.03), 0.8, 1],
	[27.0, "parabrisa", Vector2.ZERO, 0.8, 2],
	[28.2, "parabrisa", Vector2.ZERO, 1.0, 2],
]
## Fotos cheias, alem das rajadas.
const FOTOS := [7.8, 12.8, 14.6, 20.4, 21.6, 25.0, 29.5]
const FIM := 30.0
const RAJADA := 0.8

var _carro: CarroCena
var _cam: Camera3D
var _pasta := ""
var _ate := FIM
var _t := 0.0
var _feitas: Dictionary = {}
var _rajada_ate := -1.0
var _vidros: Dictionary = {}
var _sangue: Dictionary = {}
var _gpu: Dictionary = {}
var _vista := ""
var _cheias := true
var _dbg := 0
## `--vista=nome`: uma vista so, do comeco ao fim.
var _vista_fixa := ""
var _caras: Dictionary = {}


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			_pasta = a.trim_prefix("--fotos=")
		elif a.begins_with("--ate="):
			_ate = float(a.trim_prefix("--ate="))
		elif a == "--sem-fotos-cheias":
			_cheias = false
		elif a.begins_with("--vista="):
			_vista_fixa = a.trim_prefix("--vista=")
		elif a.begins_with("--dbg="):
			_dbg = int(a.trim_prefix("--dbg="))
	if not _pasta.is_empty():
		DirAccess.make_dir_recursive_absolute(_pasta.path_join("r"))
	print("[bancada_agua] placa %s  moderno=%s  antiga=%s" % [
		RenderingServer.get_video_adapter_name(),
		str(RenderingServer.global_shader_parameter_get(&"psx_facho_suave")),
		str(AguaVidro.antiga())])
	_palco()
	_carro = CarroCena.new()
	_carro.name = "Carro"
	_carro.com_som = false
	add_child(_carro)
	_carro.preparar_batida()
	_carro.amassar_frente(1.0, 1.0)
	_carro.mostrar_cabine(true)
	_carro.velocidade = 0.0
	_carro.avancar(1.0 / 30.0)
	# O motor morreu na batida: o limpador para onde estava (como na cena).
	if _carro.cabine.limpadores() != null:
		_carro.cabine.limpadores().travado = true
	if _dbg > 0:
		for no: Node in _carro.cabine.get_children():
			var mi := no as MeshInstance3D
			if mi != null and mi.material_override is ShaderMaterial \
					and (mi.material_override as ShaderMaterial).shader.resource_path.contains("vidro_agua"):
				(mi.material_override as ShaderMaterial).set_shader_parameter(&"depurar", _dbg)
	var fogo := IncendioDoCapo.new()
	_carro.add_child(fogo)
	fogo.position = AberturaEstrada.INCENDIO_NO_CARRO
	fogo.pegar_fogo(1.0, 0.1)
	fogo.fumegar(0.6, 0.1)
	var alerta := OmniLight3D.new()
	alerta.light_color = AberturaEstrada.LUZ_ALERTA
	alerta.omni_range = 1.4
	alerta.light_energy = AberturaEstrada.LUZ_ALERTA_FORCA
	alerta.light_volumetric_fog_energy = 0.0
	_carro.cabine.add_child(alerta)
	alerta.position = _carro.cabine.olho() + Vector3(0.10, -0.36, -0.50)
	# O reflexo dela que pega o rosto do lado de fora da janela (a `LuzJanela`
	# da cena, acesa como la).
	var janela := OmniLight3D.new()
	janela.light_color = AberturaEstrada.LUZ_ALERTA.lerp(Color(1.0, 0.55, 0.4), 0.25)
	janela.omni_range = 1.2
	janela.light_energy = 1.3
	janela.light_volumetric_fog_energy = 0.0
	_carro.add_child(janela)
	janela.position = Vector3(-0.92, 0.86, -0.1)

	for a: Dictionary in _carro.medidas().get("aberturas", []):
		if a["tipo"] == &"parabrisa":
			_vidros["parabrisa"] = a
		elif a["tipo"] == &"porta_frente" and int(a["lado"]) == -1:
			_vidros["motorista"] = a
		elif a["tipo"] == &"porta_frente" and int(a["lado"]) == 1:
			_vidros["carona"] = a
	for nome: String in _vidros:
		var s := SangueNoVidro.na_abertura(_vidros[nome], 5.0)
		if s != null:
			_carro.cabine.add_child(s)
			_sangue[nome] = s

	var chao := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(40, 40)
	chao.mesh = plano
	var barro := StandardMaterial3D.new()
	barro.albedo_color = Color(0.06, 0.05, 0.04)
	barro.roughness = 0.3
	chao.material_override = barro
	add_child(chao)
	chao.global_transform = Transform3D(_carro.global_basis, _carro.global_position)

	_padre("Padre", 0, true, "motorista", 0.13, 1.72)
	_padre("Capo", 3, false, "parabrisa", 0.30, 1.62)
	_padre("Carona", 5, false, "carona", 0.16, 1.62)


func _palco() -> void:
	var mundo := WorldEnvironment.new()
	var amb := Environment.new()
	amb.background_mode = Environment.BG_COLOR
	amb.background_color = Color(0.012, 0.014, 0.02)
	amb.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	amb.ambient_light_color = Color(0.25, 0.3, 0.4)
	amb.ambient_light_energy = 0.16
	amb.tonemap_mode = Environment.TONE_MAPPER_AGX
	amb.glow_enabled = true
	amb.glow_intensity = 0.5
	amb.fog_enabled = true
	amb.fog_light_color = Color(0.1, 0.11, 0.13)
	amb.fog_density = 0.03
	mundo.environment = amb
	add_child(mundo)
	var lua := DirectionalLight3D.new()
	lua.rotation_degrees = Vector3(-50, 30, 0)
	lua.light_color = Color(0.55, 0.65, 0.9)
	lua.light_energy = 0.12
	add_child(lua)
	_cam = Camera3D.new()
	_cam.fov = 52.0
	_cam.near = 0.02
	add_child(_cam)
	_cam.make_current()


## Um padre parado do lado de fora do vidro `vidro`, a cara `longe` metros para
## fora do centro dele, olhando para dentro. `boca` e a altura da cara no corpo
## (m): o corpo afunda no chao para a cara cair no vidro.
func _padre(nome: String, i: int, grande: bool, vidro: String, longe: float,
		boca: float) -> void:
	if not _vidros.has(vidro):
		return
	var a: Dictionary = _vidros[vidro]
	var n: Vector3 = a["normal"]
	var centro: Vector3 = a.get("centro", Vector3.ZERO)
	var cara := centro + n * longe
	_caras[vidro] = cara
	var c := Corpo.new()
	c.name = nome
	add_child(c)
	var altura := AberturaEstrada.PADRE_ALTURA if grande else 1.84
	var ombro := AberturaEstrada.PADRE_OMBRO if grande else AberturaEstrada.OMBRO_ENCAPUZADO
	c.montar(AberturaEstrada._aparencia_de_encapuzado(i, altura, ombro, grande))
	c.jeito = {"curvatura": 0.12, "cabeca": 0.18}
	MonstroDaEstrada.vestir(c, i, ombro / 0.42, grande)
	var pe := _carro.to_global(Vector3(cara.x, cara.y - boca, cara.z) + n * 0.1)
	var alvo := _carro.to_global(cara - n * 1.0)
	alvo.y = pe.y
	c.global_position = pe
	c.look_at(alvo, Vector3.UP)
	c.visible = true


func _process(delta: float) -> void:
	_t += delta
	_carro.avancar(delta)
	var vista := _vista_agora()
	if vista != _vista:
		_vista = vista
	_mirar(vista)
	for i in PANCADAS.size():
		var p: Array = PANCADAS[i]
		if _t >= float(p[0]) and not _feitas.has(i):
			_feitas[i] = true
			_bater(p[1], p[2], float(p[3]), int(p[4]))
			_rajada_ate = _t + RAJADA
	for f: float in FOTOS:
		if _t >= f and not _feitas.has(f):
			_feitas[f] = true
			if _cheias:
				_foto("f_%s_%05.2f.jpg" % [vista, _t], true)
	if _t <= _rajada_ate:
		_foto("r/r_%07.2f.jpg" % _t, false)
	_medir(vista)
	if _t >= _ate:
		for v: String in _gpu:
			var l: Array = _gpu[v]
			l.sort()
			var soma := 0.0
			for x: float in l:
				soma += x
			print("[gpu] %-10s n=%3d  media %.2f ms  p10 %.2f  p50 %.2f" % [v, l.size(),
				soma / maxf(1.0, l.size()), l[int(l.size() * 0.1)], l[int(l.size() * 0.5)]])
		print("[bancada_agua] fim")
		get_tree().quit()


func _vista_agora() -> String:
	if not _vista_fixa.is_empty():
		return _vista_fixa
	var v := "parabrisa"
	for par: Array in VISTAS:
		if _t >= float(par[0]):
			v = par[1]
	return v


func _mirar(vista: String) -> void:
	var olho := _carro.cabine.olho()
	var para := olho + Vector3(0.28, -0.05, -1.5)
	if _vidros.has("parabrisa"):
		para = _no_vidro("parabrisa", Vector2(-0.12, 0.02))
	match vista:
		"motorista":
			para = olho + Vector3(-1.0, 0.0, -0.12)
		"carona":
			para = olho + Vector3(1.6, -0.05, -0.30)
	var de := _carro.cabine.to_global(olho)
	_cam.global_transform = Transform3D(Basis.looking_at(_carro.cabine.to_global(para) - de,
		_carro.global_basis.y), de)


## Um ponto do vidro, a `onde` metros do centro (u deitado, v para cima).
func _no_vidro(vidro: String, onde: Vector2) -> Vector3:
	var a: Dictionary = _vidros[vidro]
	var n: Vector3 = a["normal"]
	var v := (Vector3.UP - n * n.dot(Vector3.UP)).normalized()
	var u := v.cross(n).normalized()
	return (a.get("centro", Vector3.ZERO) as Vector3) + u * onde.x + v * onde.y


func _bater(vidro: String, onde: Vector2, forca: float, tipo: int) -> void:
	if not _vidros.has(vidro):
		return
	var a: Dictionary = _vidros[vidro]
	var n: Vector3 = a["normal"]
	var ponto := _no_vidro(vidro, onde)
	if tipo == 2:
		_carro.pancada(0.06 * forca, 0.36 * forca)
		print("[bancada_agua] t=%.2f tranco %.2f" % [_t, forca])
		return
	print("[bancada_agua] t=%.2f pancada %s %.2f" % [_t, vidro, forca])
	get_tree().call_group(&"agua_no_vidro", &"impacto", _carro.cabine.to_global(ponto),
		(_carro.cabine.global_basis * n).normalized(), forca)
	if tipo == 1:
		if _sangue.has(vidro):
			(_sangue[vidro] as SangueNoVidro).golpe(ponto, forca, 1.1)
		_carro.pancada(0.05 * forca, 0.32 * forca)


func _foto(nome: String, cheia: bool) -> void:
	if _pasta.is_empty():
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if not cheia:
		img.resize(1920, 1080, Image.INTERPOLATE_BILINEAR)
	img.save_jpg(_pasta.path_join(nome), 0.92)


func _medir(vista: String) -> void:
	var vp := get_viewport().get_viewport_rid()
	if _t < 0.5:
		RenderingServer.viewport_set_measure_render_time(vp, true)
		return
	# Fora das rajadas e das fotos (a leitura da GPU trava o quadro).
	if _t <= _rajada_ate + 0.3:
		return
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(vp)
	if not _gpu.has(vista):
		_gpu[vista] = []
	(_gpu[vista] as Array).append(gpu)
