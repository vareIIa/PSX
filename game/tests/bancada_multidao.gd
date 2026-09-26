## Bancada da multidao: dezenas de encapuzados da `MultidaoEncapuzada` andando
## para a lente, no farol e no fogo, sem rodar os quarenta segundos da estrada.
##
##     G=.tools/Godot_v4.7.2-stable_win64_console.exe
##     $G --path game --resolution 1920x1080 res://scenes/test/bancada_multidao.tscn -- \
##        --fotos=DIR [--plano=perto|longe|lado|retrato] [--n=48] [--rajada=S] \
##        [--pular=S] [--visto] [--parada]
##
## Planos:
##   - `perto`: a lente no lugar do carro (1,15 m), eles de 4 a 16 m na frente,
##     andando para ela e parando a 2 m (na estrada param a 10,5: aqui e para
##     ver de perto);
##   - `longe`: a mesma lente, eles de 10 a 50 m;
##   - `lado`: uma fila de `--n` (use 5 ou 6) um atras do outro, e a lente de
##     lado a 7 m, para julgar o andar de perfil;
##   - `retrato`: uma figura so, parada no farol, fotografada de frente, de tres
##     quartos e de perfil a 3 m e de frente a 10 m (os bracos e a mao grande
##     como silhueta).
##
## `--rajada=S` grava um quadro a cada 0,1 s por S segundos em DIR/r
## (r_SSSS.SS.png, o nome que tools/mosaico_rajada.py le). `--pular=S` comeca a
## cena S segundos adiante (relogio dos pescocos e caminhada). Sem `--visto` a
## caminhada anda no relogio (1x, para julgar o passo); com ele, conta como na
## estrada: devagar no que a lente ve.
##
## Um em cada quatro quebra o pescoco dentro da rajada, e cada um tem uma parada
## de verdade (a mesma conta da estrada, adiantada por `--pular`). `--parada`
## forca todos parados olhando a lente, com uma das maos aberta.
##
## A luz aqui nao e a da estrada: o farol (dois fachos de 60 m) e o fogo (laranja
## tremido, 12 m) de frente, na nevoa. A palavra final e sempre na estrada.
extends Node3D

const FAROL_ENERGIA := 14.0
const FOGO_ENERGIA := 3.2
const ALTURA_LENTE := 1.15

var _pasta := ""
var _plano := "perto"
var _n := 48
var _rajada := 0.0
var _pular := 0.0
var _visto := false
var _parada := false
var _cam: Camera3D
var _fogo: OmniLight3D
var _multidao: MultidaoEncapuzada
var _t := 0.0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			_pasta = a.trim_prefix("--fotos=")
		elif a.begins_with("--plano="):
			_plano = a.trim_prefix("--plano=")
		elif a.begins_with("--n="):
			_n = int(a.trim_prefix("--n="))
		elif a.begins_with("--rajada="):
			_rajada = float(a.trim_prefix("--rajada="))
		elif a.begins_with("--pular="):
			_pular = float(a.trim_prefix("--pular="))
		elif a == "--visto":
			_visto = true
		elif a == "--parada":
			_parada = true
	if not _pasta.is_empty():
		DirAccess.make_dir_recursive_absolute(_pasta)
	_palco()
	_multidao = MultidaoEncapuzada.criar(_figuras())
	add_child(_multidao)
	_multidao.mirar(Vector3.ZERO)
	_multidao.parar_a(0.8 if _plano != "longe" else 8.0, 1.0)
	_multidao.pular_para(_pular, _pular)
	_multidao.aparecer(true)
	if _parada:
		_multidao.forcar_parada(1.0)
	var c := _multidao.contagem()
	var arr := MultidaoEncapuzada._malha.surface_get_arrays(0)
	print("[bancada_multidao] plano=%s figuras=%d quebram=%d malha=%d vertices %d triangulos" % [
		_plano, c.x, c.y, (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),
		(arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3])
	_rodar()


func _process(delta: float) -> void:
	_t += delta
	if _visto:
		_multidao.passo(delta)
	else:
		_multidao.pular_para(_pular + _t, _pular + _t)
	# O fogo tremido: dois senos e um sorteio lento.
	_fogo.light_energy = FOGO_ENERGIA * (0.8 + 0.12 * sin(_t * 13.0) + 0.08 * sin(_t * 31.0 + 1.3))


func _figuras() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var lista: Array = []
	if _plano == "retrato":
		lista.append({"pos": Vector3(0.0, 0.0, -6.0), "olha": Vector3.ZERO, "altura": 1.9,
			"rapidez": 0.0, "curvado": 0.35, "quebra": 0.0})
		return lista
	var de := 4.0 if _plano != "longe" else 10.0
	var ate := 16.0 if _plano != "longe" else 50.0
	var ocupado := {}
	var tentativas := 0
	while lista.size() < _n and tentativas < _n * 20:
		tentativas += 1
		var ang := rng.randf_range(-1.1, 1.1)
		var d := lerpf(de, ate, pow(rng.randf(), 1.3))
		var p := Vector3(sin(ang) * d, 0.0, -cos(ang) * d)
		if _plano == "lado":
			# Uma fila em x = 0, um atras do outro, andando para a origem: a lente
			# de lado ve cada um de perfil, sem um tapar o outro.
			p = Vector3(0.0, 0.0, -4.0 - 2.6 * float(lista.size()))
		var cel := Vector2i(floori(p.x / 1.3), floori(p.z / 1.3))
		if ocupado.has(cel):
			continue
		ocupado[cel] = true
		var i := lista.size()
		lista.append({"pos": p, "olha": Vector3.ZERO, "altura": rng.randf_range(1.72, 2.08),
			"rapidez": rng.randf_range(0.16, 0.42),
			"curvado": 0.0 if rng.randf() < 0.6 else rng.randf_range(0.2, 0.85),
			# Um em cada quatro quebra o pescoco dentro da rajada.
			"quebra": (_pular + 1.0 + rng.randf() * maxf(_rajada - 4.0, 2.0)) if i % 4 == 1
				else 0.0})
	return lista


func _palco() -> void:
	var amb := Environment.new()
	amb.background_mode = Environment.BG_COLOR
	amb.background_color = Color(0.010, 0.012, 0.016)
	amb.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	amb.ambient_light_color = Color(0.10, 0.11, 0.14)
	amb.ambient_light_energy = 0.08
	amb.tonemap_mode = Environment.TONE_MAPPER_AGX
	amb.glow_enabled = true
	amb.glow_intensity = 0.5
	amb.glow_hdr_threshold = 1.2
	amb.ssao_enabled = true
	amb.fog_enabled = true
	amb.fog_light_color = Color(0.09, 0.10, 0.12)
	amb.fog_density = 0.035
	var mundo := WorldEnvironment.new()
	mundo.environment = amb
	add_child(mundo)
	var chao := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(200, 200)
	chao.mesh = plano
	var barro := StandardMaterial3D.new()
	barro.albedo_color = Color(0.07, 0.055, 0.045)
	barro.roughness = 0.6
	chao.material_override = barro
	add_child(chao)
	# O farol: dois fachos da altura do carro, um com sombra.
	for lado: float in [-1.0, 1.0]:
		var f := SpotLight3D.new()
		f.light_color = Color(1.0, 0.93, 0.8)
		f.spot_range = 60.0
		f.spot_angle = 24.0
		f.light_energy = FAROL_ENERGIA
		f.shadow_enabled = lado > 0.0
		add_child(f)
		f.position = Vector3(lado * 0.65, 0.75, -1.9)
		f.look_at(Vector3(lado * 1.0, 0.5, -14.0), Vector3.UP)
	_fogo = OmniLight3D.new()
	_fogo.light_color = Color(1.0, 0.45, 0.15)
	_fogo.omni_range = 12.0
	_fogo.light_energy = FOGO_ENERGIA
	add_child(_fogo)
	_fogo.position = Vector3(1.6, 0.9, -2.2)
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.near = 0.05
	add_child(_cam)
	_cam.make_current()
	match _plano:
		"lado":
			_cam.position = Vector3(7.0, 1.2, -9.5)
			_cam.look_at(Vector3(0.0, 1.0, -9.5), Vector3.UP)
		"retrato":
			_cam.position = Vector3(0.0, 1.4, -3.0)
			_cam.look_at(Vector3(0.0, 1.2, -6.0), Vector3.UP)
		_:
			_cam.position = Vector3(0.0, ALTURA_LENTE, 0.0)
			_cam.look_at(Vector3(0.0, 1.0, -12.0), Vector3.UP)


func _quadros(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	if _pasta.is_empty():
		return
	var caminho := _pasta.path_join(nome + ".png")
	get_viewport().get_texture().get_image().save_png(caminho)
	print("[bancada_multidao] foto=%s" % caminho)


func _rodar() -> void:
	await _quadros(40)
	if _plano == "retrato":
		var alvo := Vector3(0.0, 1.1, -6.0)
		for vista: Array in [["frente", Vector3(0.0, 1.3, -3.0)], ["34", Vector3(2.1, 1.3, -3.9)],
				["perfil", Vector3(3.0, 1.3, -6.0)], ["frente10", Vector3(0.0, 1.15, 4.0)],
				["rosto", Vector3(0.0, 1.5, -4.9)]]:
			_cam.position = vista[1]
			_cam.look_at(alvo if vista[0] != "rosto" else Vector3(0.0, 1.62, -6.0), Vector3.UP)
			await _quadros(6)
			await _foto("retrato_" + String(vista[0]))
	else:
		await _foto(_plano + "_inicio")
		if _rajada > 0.0:
			await _gravar_rajada()
		await _foto(_plano + "_fim")
	print("[bancada_multidao] fim")
	get_tree().quit()


func _gravar_rajada() -> void:
	var pasta := _pasta.path_join("r")
	DirAccess.make_dir_recursive_absolute(pasta)
	var inicio := _t
	var proxima := 0.0
	while _t - inicio < _rajada:
		await get_tree().process_frame
		var agora := _t - inicio
		if agora >= proxima:
			proxima += 0.1
			await RenderingServer.frame_post_draw
			if not _pasta.is_empty():
				get_viewport().get_texture().get_image().save_png(
					pasta.path_join("r_%07.2f.png" % agora))
