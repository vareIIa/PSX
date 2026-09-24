## Bancada do kit de objetos da estufa (KitEstufa).
##
##     godot --path game --script res://tests/bancada_kit_estufa.gd -- --saida=DIR
##     (SEM --headless: shader so existe com janela)
##
## Flags:
##   --saida=DIR      grava as fotos (1600x900) e o relatorio de triangulos
##   --estilo=ps1     PS1 STYLE: 480x270, luz por vertice, snap e UV afim, e a
##                    foto ampliada sem filtro para 1600x900 (padrao: MODERNO)
##   --so=a,b         so estes grupos (potes, plantas, vasos, insumos, bancada,
##                    secagem, variedades)
##
## Por que uma sala de mentira, e nao a estufa. Na estufa cada objeto divide o
## quadro com trinta outros, a planta nasce na fase que o Plantio mandar e o
## pote enche com a colheita do save. Aqui cada peca e montada pelo MESMO codigo
## que o jogo vai chamar, em todas as fases lado a lado, sob a luz da estufa (a
## cor e a energia das lampadas de cultivo e o ar do fog_estufa), e o que muda
## entre duas fotos e so o kit.
extends SceneTree

const DIR_MAT := "res://resources/materials/"
const SH_VERTEX := "res://shaders/psx_surface.gdshader"
const SH_PIXEL := "res://shaders/psx_surface_pixel.gdshader"
const QUADROS := 10
const TAM := Vector2i(1600, 900)

## As lampadas de cultivo da estufa (EstufaBuilder._luminarias).
const COR_LAMPADA := Color("fff0cd")
## O ar da estufa (resources/fog/fog_estufa.tres).
const AR := Color(0.376, 0.392, 0.337)

var _raiz: Node3D
var _vp: SubViewport
var _camera: Camera3D
var _saida := ""
var _moderno := true
var _so: PackedStringArray = []
var _materiais: Dictionary = {}
var _relatorio: PackedStringArray = []
var _lampadas: Array[OmniLight3D] = []
var _env: Environment


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
		elif arg == "--estilo=ps1":
			_moderno = false
		elif arg.begins_with("--so="):
			_so = arg.trim_prefix("--so=").split(",")
	if not _saida.is_empty():
		DirAccess.make_dir_recursive_absolute(_saida)
	root.add_child.call_deferred(_montar())
	_rodar()


func _quer(g: String) -> bool:
	return _so.is_empty() or _so.has(g)


# ------------------------------------------------------------------ cena

func _montar() -> Node:
	var fora := Node.new()
	_vp = SubViewport.new()
	_vp.size = TAM if _moderno else Vector2i(480, 270)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X if _moderno else Viewport.MSAA_DISABLED
	_vp.positional_shadow_atlas_size = 4096
	fora.add_child(_vp)
	_raiz = Node3D.new()
	_vp.add_child(_raiz)

	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = AR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AR
	env.ambient_light_energy = 0.82
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = AR
	env.fog_depth_begin = 2.5
	env.fog_depth_end = 20.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	ambiente.environment = env
	_env = env
	_raiz.add_child(ambiente)

	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.near = 0.03
	_camera.far = 80.0
	_raiz.add_child(_camera)
	_camera.current = true
	return fora


## Uma lampada de cultivo, como a da estufa: 1,9 de energia, 5,2 m de alcance.
func _lampada(onde: Vector3, energia: float = 1.9) -> void:
	var l := OmniLight3D.new()
	l.light_color = COR_LAMPADA
	l.light_energy = energia
	l.omni_range = 5.2
	l.shadow_enabled = _moderno
	l.position = onde
	_raiz.add_child(l)
	_lampadas.append(l)


## O material do jogo, no estilo pedido, como o EstiloVisual faz: psx_surface
## vira psx_surface_pixel com o conjunto HD no MODERNO. O vidro tem shader
## proprio e passa direto.
func _material(nome: StringName) -> Material:
	if _materiais.has(nome):
		return _materiais[nome]
	var caminho := DIR_MAT + "mat_" + String(nome) + ".tres"
	if not ResourceLoader.exists(caminho):
		push_warning("bancada_kit_estufa: sem material %s" % caminho)
		return null
	var m := (load(caminho) as ShaderMaterial).duplicate() as ShaderMaterial
	var sh := m.shader.resource_path
	if sh == SH_VERTEX or sh == SH_PIXEL:
		m.shader = load(SH_PIXEL if _moderno else SH_VERTEX) as Shader
		var tex := m.get_shader_parameter(&"albedo_tex") as Texture2D
		if tex != null:
			TexturasHD.aplicar(m, StringName(tex.resource_path.get_file().get_basename()), _moderno)
		m.set_shader_parameter(&"molha", 0.0)
	_materiais[nome] = m
	return m


## Um `sup` num no com uma malha por material.
func _no(sup: Dictionary, nome: String) -> Node3D:
	var no := Node3D.new()
	no.name = nome
	for chave: StringName in sup:
		var d: Dictionary = sup[chave]
		if PSXMesh.dados_vazio(d):
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = PSXMesh.dados_para_mesh(d)
		mi.material_override = _material(chave)
		no.add_child(mi)
	_raiz.add_child(no)
	return no


func _triangulos(sup: Dictionary) -> int:
	var t := 0
	for chave: StringName in sup:
		t += PSXMesh.dados_triangulos(sup[chave])
	return t


func _registrar(linha: String) -> void:
	print(linha)
	_relatorio.append(linha)


## Uma peca do kit sozinha, so para contar triangulos.
func _contar(nome: String, montar: Callable) -> void:
	var sup := {}
	montar.call(sup)
	var partes: PackedStringArray = []
	for chave: StringName in sup:
		partes.append("%s %d" % [chave, PSXMesh.dados_triangulos(sup[chave])])
	_registrar("tri %-22s %5d   (%s)" % [nome, _triangulos(sup), ", ".join(partes)])


# ------------------------------------------------------------------ o cenario

## Piso e parede da estufa (o mesmo atlas e as mesmas celulas), mesas, e todas
## as pecas do kit em grupos ao longo do X.
func _cenario() -> void:
	var sup := {}
	AtlasKit.painel_repetido(sup, EstufaBuilder.MAT, Vector2(26.0, 8.0),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(10.0, 0.0, 0.0)), EstufaBuilder.C_PISO)
	AtlasKit.painel_repetido(sup, EstufaBuilder.MAT, Vector2(26.0, 3.0),
		Transform3D(Basis(), Vector3(10.0, 1.5, -1.6)), EstufaBuilder.C_MYLAR)
	# Mesas: potes, insumos e a bancada da balanca.
	for x: float in [0.0, 13.2, 16.0]:
		AtlasKit.caixa(sup, EstufaBuilder.MAT, Vector3(x, 0.72, 0.0), Vector3(1.0, 0.06, 0.6),
			EstufaBuilder.C_MADEIRA)
		for canto: Vector2 in [Vector2(-0.45, -0.25), Vector2(0.45, -0.25), Vector2(-0.45, 0.25), Vector2(0.45, 0.25)]:
			AtlasKit.caixa(sup, EstufaBuilder.MAT, Vector3(x + canto.x, 0.36, canto.y),
				Vector3(0.05, 0.72, 0.05), EstufaBuilder.C_MADEIRA)
	# Varal da secagem.
	AtlasKit.tubo(sup, EstufaBuilder.MAT, Vector3(18.6, 2.18, 0.0), Vector3(20.6, 2.18, 0.0), 0.03,
		EstufaBuilder.C_MANGUEIRA, Color(0.78, 0.78, 0.8))
	_no(sup, "cenario")

	# Potes, no tampo (0,76).
	var cheios: Array[float] = [0.0, 0.3, 0.7, 1.0]
	var potes := {}
	for k in 4:
		KitEstufa.pote(potes, Vector3(-0.27 + 0.18 * float(k), 0.75, 0.05), cheios[k], 0.1 * float(k))
	_no(potes, "potes")

	# Plantas: muda, 0,3, 0,6, 1,0 e madura, cada uma no seu vaso.
	var fases: Array[float] = [0.05, 0.3, 0.6, 1.0, 1.0]
	var plantas := {}
	for k in 5:
		var base := Vector3(2.4 + 0.95 * float(k), 0.0, 0.0)
		KitEstufa.vaso(plantas, base, true, 0.3 * float(k % 3), 100 + k)
		KitEstufa.planta(plantas, KitEstufa.boca(base), fases[k], k == 4, 100 + k,
			Color(0.95 + 0.04 * float(k % 2), 1.0, 0.92))
	_no(plantas, "plantas")

	# Vasos: vazio, terra seca, terra molhada.
	var vasos := {}
	KitEstufa.vaso(vasos, Vector3(8.6, 0.0, 0.0), false, 0.0, 201)
	KitEstufa.vaso(vasos, Vector3(9.2, 0.0, 0.0), true, 0.0, 202)
	KitEstufa.vaso(vasos, Vector3(9.8, 0.0, 0.0), true, 1.0, 203)
	_no(vasos, "vasos")

	# Insumos: tanque no chao, sacos empilhados, caixa de sementes e regador na
	# mesa.
	var ins := {}
	KitEstufa.tanque(ins, Vector3(11.4, 0.0, -0.4))
	KitEstufa.saco_terra(ins, Vector3(12.25, 0.0, 0.1), 0.05, false)
	KitEstufa.saco_terra(ins, Vector3(12.28, 0.19, 0.08), 0.18, false)
	KitEstufa.saco_terra(ins, Vector3(12.22, 0.38, 0.1), -0.08, true)
	KitEstufa.caixa_sementes(ins, Vector3(13.35, 0.75, 0.05), -0.25)
	KitEstufa.regador(ins, Transform3D(Basis(Vector3.UP, 0.35), Vector3(12.95, 0.75, 0.0)))
	_no(ins, "insumos")

	# A bancada: balanca e saquinhos.
	var banc := {}
	KitEstufa.balanca(banc, Vector3(15.85, 0.75, 0.0), 0.2)
	KitEstufa.saquinho(banc, Vector3(16.12, 0.75, 0.06), 0.4)
	KitEstufa.saquinho(banc, Vector3(16.2, 0.75, -0.09), -0.9)
	KitEstufa.saquinho(banc, Vector3(16.05, 0.75, 0.16), 2.0)
	_no(banc, "bancada")

	# Ramos secando.
	var sec := {}
	for k in 4:
		KitEstufa.ramo_secando(sec, Vector3(18.9 + 0.45 * float(k), 2.18, 0.0), 0.62 + 0.06 * float(k % 2), 300 + k)
	_no(sec, "secagem")

	for x: float in [0.0, 3.4, 5.4, 9.2, 12.4, 16.0, 19.6]:
		_lampada(Vector3(x, 2.45, 0.9))


# ------------------------------------------------------------------ fotos

func _foto() -> Image:
	for i in QUADROS:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	if not _moderno:
		img.resize(TAM.x, TAM.y, Image.INTERPOLATE_NEAREST)
	return img


func _mirar(de: Vector3, para: Vector3) -> void:
	_camera.global_position = de
	_camera.look_at(para, Vector3.UP)


func _foto_de(nome: String, de: Vector3, para: Vector3, fov: float = 50.0) -> void:
	_camera.fov = fov
	_mirar(de, para)
	var img := await _foto()
	if _saida.is_empty():
		return
	var arquivo := _saida.path_join("%s_%s.png" % [nome, "moderno" if _moderno else "ps1"])
	img.save_png(arquivo)
	_registrar("foto %s" % arquivo)


func _rodar() -> void:
	await process_frame
	await process_frame
	RenderingServer.global_shader_parameter_set(&"psx_snap", not _moderno)
	RenderingServer.global_shader_parameter_set(&"psx_affine", not _moderno)
	RenderingServer.global_shader_parameter_set(&"psx_snap_escala", 1.0)
	RenderingServer.global_shader_parameter_set(&"psx_facho_suave", _moderno)
	RenderingServer.global_shader_parameter_set(&"psx_molhado", 0.0)
	RenderingServer.global_shader_parameter_set(&"psx_chuva", 0.0)
	_registrar("bancada_kit_estufa  estilo=%s" % ("moderno" if _moderno else "ps1"))

	_contar("pote vazio", func(s: Dictionary) -> void: KitEstufa.pote(s, Vector3.ZERO, 0.0))
	_contar("pote cheio", func(s: Dictionary) -> void: KitEstufa.pote(s, Vector3.ZERO, 1.0))
	for c: float in [0.03, 0.08, 0.3, 0.6, 1.0]:
		_registrar("tri planta %.2f            %5d" % [c, KitEstufa.triangulos_planta(c, false)])
	_registrar("tri planta 1.00 madura     %5d" % KitEstufa.triangulos_planta(1.0, true))
	_contar("vaso vazio", func(s: Dictionary) -> void: KitEstufa.vaso(s, Vector3.ZERO, false, 0.0, 1))
	_contar("vaso com terra", func(s: Dictionary) -> void: KitEstufa.vaso(s, Vector3.ZERO, true, 0.5, 1))
	_contar("regador", func(s: Dictionary) -> void: KitEstufa.regador(s, Transform3D()))
	_contar("caixa_sementes", func(s: Dictionary) -> void: KitEstufa.caixa_sementes(s, Vector3.ZERO, 0.0))
	_contar("saco_terra fechado", func(s: Dictionary) -> void: KitEstufa.saco_terra(s, Vector3.ZERO, 0.0, false))
	_contar("saco_terra aberto", func(s: Dictionary) -> void: KitEstufa.saco_terra(s, Vector3.ZERO, 0.0, true))
	_contar("tanque", func(s: Dictionary) -> void: KitEstufa.tanque(s, Vector3.ZERO))
	_contar("balanca", func(s: Dictionary) -> void: KitEstufa.balanca(s, Vector3.ZERO, 0.0))
	_contar("saquinho", func(s: Dictionary) -> void: KitEstufa.saquinho(s, Vector3.ZERO, 0.0))
	_contar("ramo_secando", func(s: Dictionary) -> void: KitEstufa.ramo_secando(s, Vector3(0, 2, 0), 0.7, 1))
	# Deterministico: duas chamadas iguais, mesma malha.
	var a := {}
	var b := {}
	KitEstufa.planta(a, Vector3.ZERO, 0.73, true, 42)
	KitEstufa.planta(b, Vector3.ZERO, 0.73, true, 42)
	var igual := true
	for m: StringName in a:
		igual = igual and (a[m]["v"] as PackedVector3Array) == (b[m]["v"] as PackedVector3Array) \
			and (a[m]["c"] as PackedColorArray) == (b[m]["c"] as PackedColorArray)
	_registrar("deterministico %s" % ("SIM" if igual else "NAO"))
	# Custo de montar: a Plantacao refaz o pe no quadro em que ele cresce.
	for caso: Array in [[0.6, false], [1.0, false], [1.0, true]]:
		var t0 := Time.get_ticks_usec()
		for k in 10:
			KitEstufa.planta({}, Vector3.ZERO, float(caso[0]), bool(caso[1]), k)
		_registrar("ms planta %.2f %s        %6.2f" % [caso[0], "madura" if caso[1] else "      ",
			float(Time.get_ticks_usec() - t0) / 10000.0])

	if _quer("variedades"):
		_contar_variedades()
	_cenario()
	if _quer("variedades"):
		_cenario_variedades()
	# O primeiro quadro monta o shader; a foto so vale depois.
	for i in 20:
		await process_frame

	if _quer("potes"):
		await _foto_de("potes", Vector3(0.0, 1.02, 0.62), Vector3(0.0, 0.83, 0.05), 50.0)
		await _foto_de("potes_1m", Vector3(0.25, 1.35, 1.05), Vector3(0.0, 0.8, 0.0), 50.0)
		await _foto_de("pote_perto", Vector3(0.24, 0.9, 0.28), Vector3(0.18, 0.83, 0.05), 45.0)
	if _quer("plantas"):
		await _foto_de("plantas", Vector3(4.3, 1.45, 3.2), Vector3(4.3, 0.75, 0.0), 55.0)
		await _foto_de("planta_madura", Vector3(6.2, 1.25, 1.35), Vector3(6.2, 1.05, 0.0), 55.0)
		await _foto_de("planta_cheia", Vector3(5.25, 1.25, 1.35), Vector3(5.25, 1.0, 0.0), 55.0)
		await _foto_de("planta_media", Vector3(4.3, 1.0, 1.0), Vector3(4.3, 0.75, 0.0), 55.0)
		await _foto_de("planta_folha", Vector3(5.5, 1.2, 0.55), Vector3(5.25, 0.95, 0.0), 50.0)
		await _foto_de("cola", Vector3(6.35, 1.72, 0.45), Vector3(6.2, 1.5, 0.0), 50.0)
		await _foto_de("muda", Vector3(2.4, 0.62, 0.32), Vector3(2.4, 0.45, 0.0), 45.0)
		await _foto_de("planta_03", Vector3(3.35, 0.95, 0.75), Vector3(3.35, 0.6, 0.0), 50.0)
	if _quer("vasos"):
		await _foto_de("vasos", Vector3(9.2, 1.2, 1.3), Vector3(9.2, 0.3, 0.0), 50.0)
	if _quer("insumos"):
		await _foto_de("insumos", Vector3(12.3, 1.5, 2.3), Vector3(12.3, 0.55, 0.0), 55.0)
		await _foto_de("tanque", Vector3(10.4, 1.2, 1.2), Vector3(11.4, 0.6, -0.4), 50.0)
		await _foto_de("sacos", Vector3(12.25, 1.2, 1.25), Vector3(12.25, 0.3, 0.1), 50.0)
		await _foto_de("sementes", Vector3(13.4, 1.1, 0.45), Vector3(13.35, 0.78, 0.05), 45.0)
		await _foto_de("regador", Vector3(13.0, 1.0, 0.75), Vector3(13.05, 0.87, 0.0), 45.0)
	if _quer("bancada"):
		await _foto_de("bancada", Vector3(16.0, 1.15, 0.55), Vector3(16.02, 0.76, 0.02), 45.0)
	if _quer("secagem"):
		await _foto_de("secagem", Vector3(19.6, 1.55, 1.5), Vector3(19.6, 1.75, 0.0), 55.0)

	if _quer("variedades"):
		await _fotos_variedades()

	if not _saida.is_empty():
		var f := FileAccess.open(_saida.path_join("relatorio_%s.txt" % ("moderno" if _moderno else "ps1")),
			FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(_relatorio) + "\n")
	quit(0)


# ------------------------------------------------------------------ variedades

## Uma fileira por variedade, em Z, longe do resto: a estaca de semeado e o pe
## em 0,05, 0,4, 0,75 e maduro, cada um no recipiente dele, embaixo de um forro
## de mentira a 2,61 m (o pe-direito do andar do poco).
const VAR_X0 := 32.0
const VAR_Z0 := 12.0
const VAR_DZ := 6.0
const VAR_DX := 1.15
const PE_DIREITO := 2.61
const VAR_FASES: Array[float] = [-1.0, 0.05, 0.4, 0.75, 1.0]


func _var_z(i: int) -> float:
	return VAR_Z0 + VAR_DZ * float(i)


func _var_x(k: int) -> float:
	return VAR_X0 + VAR_DX * float(k)


func _contar_variedades() -> void:
	for v: StringName in KitEstufa.FORMAS:
		var linha := "tri %-11s" % v
		for c: float in [0.05, 0.4, 0.75, 1.0]:
			linha += "  %.2f %5d" % [c, KitEstufa.triangulos_variedade(v, c, false)]
		linha += "  madura %5d" % KitEstufa.triangulos_variedade(v, 1.0, true)
		var rec := {}
		KitEstufa.recipiente(rec, Vector3.ZERO, v, true, 0.4, 1, PE_DIREITO)
		linha += "  recipiente %4d" % _triangulos(rec)
		_registrar(linha)
	for v: StringName in KitEstufa.FORMAS:
		var ms := PackedFloat32Array()
		for caso: Array in [[0.4, false], [1.0, false], [1.0, true]]:
			var t0 := Time.get_ticks_usec()
			for k in 10:
				KitEstufa.variedade({}, Vector3.ZERO, float(caso[0]), bool(caso[1]), k, v, PE_DIREITO)
			ms.append(float(Time.get_ticks_usec() - t0) / 10000.0)
		_registrar("ms  %-11s  0.40 %6.2f  1.00 %6.2f  madura %6.2f" % [v, ms[0], ms[1], ms[2]])
	# Deterministico: duas chamadas iguais, mesma malha.
	var igual := true
	for v: StringName in KitEstufa.FORMAS:
		var a := {}
		var b := {}
		KitEstufa.variedade(a, Vector3(1, 2, 3), 0.73, true, 42, v)
		KitEstufa.variedade(b, Vector3(1, 2, 3), 0.73, true, 42, v)
		for m: StringName in a:
			igual = igual and b.has(m) \
				and (a[m]["v"] as PackedVector3Array) == (b[m]["v"] as PackedVector3Array) \
				and (a[m]["c"] as PackedColorArray) == (b[m]["c"] as PackedColorArray)
	_registrar("variedades deterministico %s" % ("SIM" if igual else "NAO"))


func _cenario_variedades() -> void:
	var sup := {}
	var n := KitEstufa.FORMAS.size()
	var z0 := _var_z(0) - 2.0
	var z1 := _var_z(n - 1) + 2.0
	var xm := _var_x(2)
	var larg := VAR_DX * 5.0 + 3.0
	AtlasKit.painel_repetido(sup, EstufaBuilder.MAT, Vector2(larg, z1 - z0),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(xm, 0.0, (z0 + z1) * 0.5)), EstufaBuilder.C_PISO)
	AtlasKit.painel_repetido(sup, EstufaBuilder.MAT, Vector2(larg, z1 - z0),
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(xm, PE_DIREITO, (z0 + z1) * 0.5)),
		EstufaBuilder.C_PAINEL)
	for i in n:
		# A parede do fundo de cada fileira.
		AtlasKit.painel_repetido(sup, EstufaBuilder.MAT, Vector2(larg, PE_DIREITO),
			Transform3D(Basis(), Vector3(xm, PE_DIREITO * 0.5, _var_z(i) - 1.25)), EstufaBuilder.C_MYLAR)
	_no(sup, "var_cenario")
	for i in n:
		var v: StringName = KitEstufa.FORMAS[i]
		var obj := {}
		var info := KitEstufa.recipiente_info(v, PE_DIREITO)
		for k in VAR_FASES.size():
			var pe := Vector3(_var_x(k), 0.0, _var_z(i))
			var sid := 500 + i * 10 + k
			KitEstufa.recipiente(obj, pe, v, true, 0.3 * float(k % 3), sid, PE_DIREITO)
			var terra: Vector3 = pe + (info["terra"] as Vector3)
			var c: float = VAR_FASES[k]
			if c < 0.0:
				KitEstufa.estaca_da_variedade(obj, terra, v, sid)
			else:
				KitEstufa.variedade(obj, terra, c, k == VAR_FASES.size() - 1, sid, v, PE_DIREITO)
		_no(obj, "var_" + String(v))
		for x: float in [_var_x(0) + 0.5, _var_x(2) + 0.1, _var_x(4) - 0.3]:
			_lampada(Vector3(x, 2.42, _var_z(i) + 0.9), 1.7)


## Onde olhar a madura de perto: (altura do alvo, distancia, altura da camera).
func _var_perto(v: StringName) -> Vector3:
	match v:
		&"morcega":
			return Vector3(1.25, 1.7, 1.35)
		&"bonsai":
			return Vector3(0.86, 0.75, 1.2)
		&"saca_rolha":
			return Vector3(0.95, 1.5, 1.2)
		&"girafa":
			return Vector3(2.2, 1.8, 1.7)
		&"pompom":
			return Vector3(1.05, 1.4, 1.35)
		&"chorona":
			return Vector3(0.8, 2.0, 1.2)
		&"gambazona":
			return Vector3(0.95, 1.2, 1.25)
		&"vagalume":
			return Vector3(1.0, 1.5, 1.3)
	return Vector3(1.0, 1.5, 1.3)


func _escuro(sim: bool) -> void:
	for l in _lampadas:
		l.visible = not sim
	_env.ambient_light_energy = 0.1 if sim else 0.82
	_env.background_color = AR * (0.2 if sim else 1.0)
	_env.fog_light_color = AR * (0.2 if sim else 1.0)


func _fotos_variedades() -> void:
	for i in KitEstufa.FORMAS.size():
		var v: StringName = KitEstufa.FORMAS[i]
		var z := _var_z(i)
		await _foto_de("var_%s_fases" % v, Vector3(_var_x(2), 1.45, z + 4.1),
			Vector3(_var_x(2), 1.15, z), 55.0)
		var perto := _var_perto(v)
		var xm := _var_x(4)
		await _foto_de("var_%s_madura" % v, Vector3(xm + perto.y * 0.35, perto.z, z + perto.y),
			Vector3(xm, perto.x, z), 50.0)
		if v == &"vagalume":
			_escuro(true)
			await _foto_de("var_vagalume_escuro", Vector3(_var_x(2), 1.45, z + 4.1),
				Vector3(_var_x(2), 1.15, z), 55.0)
			await _foto_de("var_vagalume_escuro_perto", Vector3(xm + perto.y * 0.35, perto.z, z + perto.y),
				Vector3(xm, perto.x, z), 50.0)
			_escuro(false)
		if v == &"bonsai":
			await _foto_de("var_bonsai_perto", Vector3(xm + 0.2, 1.05, z + 0.55),
				Vector3(xm, 0.85, z), 45.0)
		if v == &"morcega":
			await _foto_de("var_morcega_vaso", Vector3(xm + 0.35, 1.6, z + 0.8),
				Vector3(xm, 2.1, z), 50.0)
