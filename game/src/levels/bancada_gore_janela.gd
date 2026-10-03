## Bancada do gore do padre na janela: so a `CabecaDoPadre`, sem corpo nem
## carro, fotografada a 0,40 m como a lente a ve no stare, depois de cada
## cabecada (dano 0..3), com a orbita vazia e o `OlhoSolto` pendurado.
##
##     G=.tools/Godot_v4.7.2-stable_win64_console.exe
##     $G --path game --resolution 3840x2160 res://scenes/test/bancada_gore_janela.tscn -- \
##        --fotos=DIR [--so=d0,d1,d2,d3,olho,bd0..bd3,bl0..bl3]
##
## `bdN` e `blN`: a boca de perto (0,2 m) depois do golpe N, de frente e de
## tres quartos: os dentes quebrando (`DentesDoPadre`).
##
## `carne`: a carne do rosto (`CarneDoRosto`) numa cabecada num vidro virtual,
## quadro a quadro, e o sorriso, a fala, a tensao, a dor e o folego. Rode com
## `--fixed-fps 60` antes do `--`; com `--rosto-duro` depois dele, o A/B rigido.
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
	if _cab.dentes() != null:
		_cab.dentes().quebra_dentes = true
		_cab.rasga_boca = true
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
	if _so.has("carne_custo"):
		await _carne_custo()
		print("[bancada_gore] fim")
		get_tree().quit()
		return
	if not _so.is_empty() and String(_so[0]).begins_with("carne"):
		await _carne_bancada()
		print("[bancada_gore] fim")
		get_tree().quit()
		return
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
		for lado: float in [0.0, 1.0]:
			var nome := ("bd%d" if lado == 0.0 else "bl%d") % d
			if not _quer(nome):
				continue
			# A boca de perto: o meio da fenda na malha da cabeca.
			var volta := _cam.global_transform
			var boca := _cab.global_transform * Vector3(0.0, -0.062, -0.09)
			var frente := (_cab.global_basis * Vector3.FORWARD).normalized()
			var dir := frente.rotated(Vector3.UP, deg_to_rad(35.0) * lado)
			_cam.global_position = boca + dir * 0.2 + Vector3.UP * 0.015
			_cam.look_at(boca, Vector3.UP)
			await _quadros(4)
			await _foto(nome)
			_cam.global_transform = volta
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


# --- a carne do rosto (`--so=carne`) ---------------------------------------
# Uma cabecada inteira num vidro virtual (recua, bote, cola, descola), com o
# hit stop, fotografada de frente, de tres quartos e de perfil quadro a quadro;
# depois o sorriso, a fala, a tensao, a dor e a respiracao, de frente e de tres
# quartos. Rode com `--fixed-fps 60` (antes do `--`): cada quadro anda 1/60 s
# do jogo, por mais que a foto demore. Com `--rosto-duro` sai o mesmo roteiro
# com a cara rigida (A/B).

## O vidro fica a isto da testa na pose de repouso (m, o `TESTA_PERTO` da
## cena), e a lente a isto do vidro.
const CARNE_PERTO := 0.075
const CARNE_LENTE := 0.40
## O golpe, com os numeros do primeiro da cena: antecipacao (s), quanto a testa
## vai para tras nela (m), o bote (s), colada (s), descolar (s), o quanto a
## testa passa do vidro (m) e o hit stop (quadros a 0,02).
const CARNE_RECUA := 0.5
const CARNE_LONGE := 0.17
const CARNE_BOTE := 0.08
const CARNE_COLA := 0.25
const CARNE_DESCOLA := 0.22
const CARNE_AMASSA := 0.004
const CARNE_HIT_STOP := 4
## O recorte das fotos a 4K (o rosto, no meio do quadro).
const CARNE_RECORTE := Rect2i(1020, 160, 1800, 1840)

var _cz_vidro := 0.0
var _c_vistas: Array[SubViewport] = []
var _c_n := 0


func _carne_bancada() -> void:
	var carne := CarneDoRosto.de(_cab)
	print("[bancada_carne] carne %s" % ("ligada" if carne != null else "DURA (--rosto-duro)"))
	_cab.por_dano(0.0)
	_cab.por_sangue(0.0)
	_cab.por_sorriso(0.35)
	_cab.rotation = Vector3(0.0, PI, 0.0)
	_cab.position = Vector3(0.0, 1.5, 0.0)
	var testa := _cab.global_transform * CabecadaDoPadre.TESTA
	_cz_vidro = testa.z + CARNE_PERTO
	var o := Vector3(0.0, testa.y, _cz_vidro)
	if carne != null:
		carne.vidro_de_teste(o, Vector3.FORWARD)
	# O vidro que se ve: um fio de reflexo, para o plano aparecer no perfil.
	var vidro := MeshInstance3D.new()
	var q := BoxMesh.new()
	q.size = Vector3(0.5, 0.5, 0.0015)
	vidro.mesh = q
	var mv := StandardMaterial3D.new()
	mv.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mv.albedo_color = Color(0.8, 0.88, 0.95, 0.10)
	mv.roughness = 0.05
	mv.cull_mode = BaseMaterial3D.CULL_DISABLED
	vidro.material_override = mv
	vidro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(vidro)
	vidro.global_position = o + Vector3(0.0, 0.0, 0.00075)
	# As lentes: de frente (a da tela), tres quartos e perfil.
	var alvo := o + Vector3(0.0, -0.04, -0.085)
	_cam.global_position = o + Vector3(0.0, -0.02, CARNE_LENTE)
	_cam.look_at(alvo, Vector3.UP)
	var tq := Vector3(sin(deg_to_rad(40.0)), 0.06, cos(deg_to_rad(40.0))) * CARNE_LENTE
	_c_vistas.append(_carne_vista(Vector2i(3840, 2160), o + tq, alvo))
	_c_vistas.append(_carne_vista(Vector2i(3840, 2160), alvo + Vector3(0.5, 0.0, 0.0), alvo))
	_carne_pose(0.0, 0.0, CARNE_PERTO)
	await _quadros(20)

	# --- a cabecada
	await _carne_golpe(carne)
	# --- sem vidro: a cara parada, o sorriso, a fala, a tensao, a dor, o folego
	if carne != null:
		carne.vidro_de_teste(Vector3.ZERO, Vector3.ZERO)
	vidro.visible = false
	_carne_pose(0.0, 0.0, CARNE_PERTO)
	_cab.por_dano(0.0)
	await _carne_espera(1.2)
	for s: float in [0.0, 0.6, 1.25]:
		_cab.por_sorriso(s)
		await _carne_espera(0.5)
		await _carne_foto("sorriso_%02d" % int(s * 10.0), 2)
	_cab.por_sorriso(0.35)
	await _carne_espera(0.4)
	_cab.falar(CabecaDoPadre.FALA_QUE_BOM)
	var t := 0.0
	for m: Array in [[0.12, "A"], [0.33, "M"], [0.45, "O"], [0.66, "M2"], [1.02, "O2"],
			[1.24, "A2"], [1.72, "O3"]]:
		t = await _carne_ate(t, float(m[0]))
		await _carne_foto("fala_%s" % m[1], 2)
	await _carne_espera(0.6)
	if carne != null:
		carne.golpe_recua = 1.0
	_carne_pose(1.0, 0.0, CARNE_PERTO + CARNE_LONGE)
	await _carne_espera(0.5)
	await _carne_foto("tensao", 2)
	if carne != null:
		carne.golpe_recua = 0.0
	_carne_pose(0.0, 0.0, CARNE_PERTO)
	await _carne_espera(0.8)
	if carne != null:
		carne._doer(1.0)
	t = 0.0
	for m: float in [0.06, 0.22, 0.5, 0.9]:
		t = await _carne_ate(t, m)
		await _carne_foto("dor_%02d" % int(m * 100.0), 2)
	if carne != null:
		carne._esforco = 1.0
	await _carne_espera(1.5)
	t = 0.0
	for m: float in [0.0, 0.4, 0.8, 1.2, 1.6]:
		t = await _carne_ate(t, m)
		await _carne_foto("folego_%02d" % int(m * 10.0), 2)


## Uma lente numa SubViewport do mesmo mundo.
func _carne_vista(tam: Vector2i, de: Vector3, para: Vector3) -> SubViewport:
	var sv := SubViewport.new()
	sv.size = tam
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.use_taa = get_viewport().use_taa
	sv.msaa_3d = get_viewport().msaa_3d
	sv.screen_space_aa = get_viewport().screen_space_aa
	add_child(sv)
	var cam := Camera3D.new()
	cam.fov = FOV
	cam.near = 0.02
	sv.add_child(cam)
	cam.global_position = de
	cam.look_at(para, Vector3.UP)
	cam.current = true
	return sv


## A pose do golpe: o queixo sobe na antecipacao e recolhe no bote (os giros
## da `CabecadaDoPadre`), e a testa fica a `dist` do vidro.
func _carne_pose(recua: float, bote: float, dist: float) -> void:
	_cab.rotation = Vector3(CabecadaDoPadre.QUEIXO_RECUA * recua + CabecadaDoPadre.QUEIXO_BOTE * bote,
		PI, 0.0)
	var testa := _cab.global_transform * CabecadaDoPadre.TESTA
	_cab.position.z += (_cz_vidro - dist) - testa.z


func _carne_golpe(carne: CarneDoRosto) -> void:
	var fases := [["recua", CARNE_RECUA], ["bote", CARNE_BOTE], ["cola", CARNE_COLA],
		["descola", CARNE_DESCOLA], ["depois", 0.6]]
	var longe := CARNE_PERTO + CARNE_LONGE
	var dano := 0.0
	var t_toque := -1.0
	var k := 0
	for f: Array in fases:
		var nome: String = f[0]
		var dur: float = f[1]
		var t := 0.0
		while t < dur:
			var x := clampf(t / dur, 0.0, 1.0)
			var recua := 0.0
			var bote := 0.0
			var dist := CARNE_PERTO
			match nome:
				"recua":
					recua = 0.5 - 0.5 * cos(PI * x)
					dist = lerpf(CARNE_PERTO, longe, sin(PI * 0.5 * x))
				"bote":
					recua = 1.0 - x * x
					bote = x * x
					dist = lerpf(longe, -CARNE_AMASSA, x * x)
				"cola":
					bote = 1.0
					dist = -CARNE_AMASSA
				"descola":
					bote = lerpf(1.0, 0.25, x)
					dist = lerpf(-CARNE_AMASSA, 0.045, sin(PI * 0.5 * x))
				"depois":
					bote = 0.25
					dist = 0.045
			if carne != null:
				carne.golpe_recua = recua
				carne.golpe_bote = bote
			_carne_pose(recua, bote, dist)
			if t_toque >= 0.0:
				dano = minf(1.0, (_c_tempo() - t_toque) / 0.045)
				_cab.por_dano(dano)
			var perto_do_toque := nome == "bote" or (nome == "cola" and t < 0.12)
			if perto_do_toque or k % 2 == 0:
				await _carne_foto("g%03d_%s" % [k, nome], 3)
			await get_tree().process_frame
			var dt := get_process_delta_time()
			t += dt
			_c_relogio += dt
			k += 1
		if nome == "bote":
			# O toque: a pose final do bote e o tempo para uns quadros.
			_carne_pose(0.0, 1.0, -CARNE_AMASSA)
			t_toque = _c_tempo()
			Engine.time_scale = 0.02
			for i in CARNE_HIT_STOP:
				await _carne_foto("g%03d_hitstop%d" % [k, i], 3)
				await get_tree().process_frame
				_c_relogio += get_process_delta_time()
				k += 1
			Engine.time_scale = 1.0
	if carne != null:
		carne.golpe_bote = 0.0


var _c_relogio := 0.0


func _c_tempo() -> float:
	return _c_relogio


func _carne_espera(s: float) -> void:
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()


## Anda do instante `de` ate `ate` (s) e devolve onde parou.
func _carne_ate(de: float, ate: float) -> float:
	var t := de
	while t < ate:
		await get_tree().process_frame
		t += get_process_delta_time()
	return t


## `vistas` fotos do quadro que acabou de desenhar: 1 de frente, 2 mais a de
## tres quartos, 3 mais o perfil. Recortadas no rosto, a 4K.
func _carne_foto(nome: String, vistas: int) -> void:
	await RenderingServer.frame_post_draw
	if _pasta.is_empty():
		return
	var imgs: Array[Image] = [get_viewport().get_texture().get_image()]
	for i in mini(vistas - 1, _c_vistas.size()):
		imgs.append(_c_vistas[i].get_texture().get_image())
	var sufixo := ["f", "t", "p"]
	for i in imgs.size():
		var img := imgs[i]
		# O recorte no meio, na proporcao da altura (a janela nao cabe inteira
		# na tela: sai 3747x2108).
		var k := float(img.get_height()) / 2160.0
		var tam := Vector2i(roundi(CARNE_RECORTE.size.x * k), roundi(CARNE_RECORTE.size.y * k))
		img = img.get_region(Rect2i((img.get_size() - tam) / 2, tam))
		img.save_png(_pasta.path_join("%s_%s.png" % [nome, sufixo[i]]))
	_c_n += 1


## `--so=carne_custo`: o custo de GPU da cabeca a 0,4 m (a cara destruida, o
## sorriso inteiro, a carne ligada com o vidro encostado e a onda andando), em
## 600 quadros; com `--rosto-duro`, o mesmo quadro rigido.
func _carne_custo() -> void:
	var carne := CarneDoRosto.de(_cab)
	_cab.por_dano(3.0)
	_cab.por_sangue(1.0)
	_cab.por_sorriso(1.2)
	var testa := _cab.global_transform * CabecadaDoPadre.TESTA
	# `sem_vidro`: o stare (sem vidro e sem onda), so musculo, folego e tremor.
	var stare := _so.has("sem_vidro")
	if carne != null:
		if stare:
			carne.vidro_de_teste(Vector3.ZERO, Vector3.ZERO)
		else:
			carne.vidro_de_teste(Vector3(0.0, testa.y, testa.z - 0.004), Vector3.FORWARD)
		carne._esforco = 1.0
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	await _quadros(120)
	var soma := 0.0
	var n := 0
	for i in 600:
		if carne != null and i % 60 == 0 and not stare:
			carne._impacto(6.0)
		await get_tree().process_frame
		soma += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		n += 1
	print("[bancada_carne] gpu media %.3f ms em %d quadros (%s)" % [soma / n, n,
		"mole" if carne != null else "duro"])
