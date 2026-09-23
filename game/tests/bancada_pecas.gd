## Uma peca de cada vez, sob a luz da loja, de quatro lados.
##
##     godot --path game --resolution 1280x720 --script res://tests/bancada_pecas.gd -- \
##         --kit=res://src/world/mercado/kit_banheiro.gd --funcao=bancada_vaso \
##         --saida=DIR [--estilo=moderno|ps1|os_dois] [--parede] [--perto=1.0]
##     (SEM --headless: shader so existe com janela)
##
## Por que existe
## -------------
## A loja inteira leva um minuto para montar e o quadro que interessa (o vaso,
## a torneira, a estufa) ocupa um canto dele. Aqui a peca nasce sozinha, num
## piso de ladrilho, com uma calha branca por cima como a da loja, e a camera
## gira em volta dela: frente, tres quartos, lado e de cima. Sai uma folha 2x2
## por estilo — `<funcao>_moderno.png` e `<funcao>_ps1.png` — e a contagem de
## triangulos por material, que e o orcamento da peca.
##
## Contrato do kit: `static func <funcao>(sup: Dictionary, colisao: Array[Dictionary]) -> void`
## montando a peca em volta da origem, com o chao em y = 0 e a frente para +Z.
## A camera enquadra pelo envoltorio dos vertices, entao a peca pode ter qualquer
## tamanho.
extends SceneTree

const DIR_MAT := "res://resources/materials/"
const PIXEL := "res://shaders/psx_surface_pixel.gdshader"
const SUPERFICIE := "res://shaders/psx_surface.gdshader"
const QUADRO := Vector2i(640, 360)

var _kit := ""
var _funcao := ""
var _saida := ""
var _estilo := "os_dois"
var _parede := false
var _perto := 0.72
var _raiz: Node3D
var _camera: Camera3D


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--kit="):
			_kit = arg.trim_prefix("--kit=")
		elif arg.begins_with("--funcao="):
			_funcao = arg.trim_prefix("--funcao=")
		elif arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
		elif arg.begins_with("--estilo="):
			_estilo = arg.trim_prefix("--estilo=")
		elif arg == "--parede":
			_parede = true
		elif arg.begins_with("--perto="):
			_perto = float(arg.trim_prefix("--perto="))
	process_frame.connect(_rodar, CONNECT_ONE_SHOT)


func _rodar() -> void:
	if _kit.is_empty() or _funcao.is_empty() or _saida.is_empty():
		printerr("uso: --kit=res://... --funcao=nome --saida=DIR")
		quit(2)
		return
	var kit := load(_kit) as GDScript
	if kit == null:
		printerr("kit nao carregou: " + _kit)
		quit(2)
		return
	var sup: Dictionary = {}
	var colisao: Array[Dictionary] = []
	kit.call(StringName(_funcao), sup, colisao)
	var peca := sup.duplicate()
	# O palco: piso de ladrilho e, se pedido, uma parede de azulejo atras.
	KitModular.chao(sup, &"mercado_ladrilho", Vector3(-3.0, 0.0, -3.0), Vector2(6.0, 6.0),
		PSXMesh.MAX_QUAD_M, Color.WHITE)
	if _parede:
		KitModular.parede_livre(sup, &"mercado_revestimento", Vector3(0.0, 1.4, -1.2),
			Vector2(6.0, 2.8), 0.0, Color.WHITE)

	var caixa := _envoltorio(peca)
	var total := 0
	for m: StringName in peca:
		var t := (peca[m]["i"] as PackedInt32Array).size() / 3
		total += t
		print("[pecas] %s: %d triangulos" % [m, t])
	print("[pecas] total=%d envoltorio=%s" % [total, caixa.size.snapped(Vector3(0.01, 0.01, 0.01))])

	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var estilos: Array[String] = ["moderno", "ps1"]
	if _estilo != "os_dois":
		estilos = [_estilo]
	DirAccess.make_dir_recursive_absolute(_saida)
	for estilo in estilos:
		_montar(sup, estilo == "moderno")
		var folha := Image.create(QUADRO.x * 2, QUADRO.y * 2, false, Image.FORMAT_RGBA8)
		var vistas := _vistas(caixa)
		for k in vistas.size():
			var v: Array = vistas[k]
			_camera.global_position = v[0]
			_camera.look_at(v[1], Vector3.UP)
			for q in 4:
				await process_frame
			var img := root.get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(QUADRO.x, QUADRO.y, Image.INTERPOLATE_BILINEAR)
			folha.blit_rect(img, Rect2i(Vector2i.ZERO, QUADRO),
				Vector2i((k % 2) * QUADRO.x, (k / 2) * QUADRO.y))
		var arq := _saida.path_join("%s_%s.png" % [_funcao, estilo])
		folha.save_png(arq)
		print("[pecas] foto=%s" % arq)
	quit(0)


func _envoltorio(sup: Dictionary) -> AABB:
	var caixa := AABB()
	var primeiro := true
	for m: StringName in sup:
		for p: Vector3 in (sup[m]["v"] as PackedVector3Array):
			if primeiro:
				caixa = AABB(p, Vector3.ZERO)
				primeiro = false
			else:
				caixa = caixa.expand(p)
	return caixa


## Frente, tres quartos, lado e de cima, a uma distancia que enquadra a peca.
func _vistas(caixa: AABB) -> Array:
	var centro := caixa.get_center()
	var raio := maxf(0.25, caixa.size.length() * 0.5)
	var dist := raio / tan(deg_to_rad(_camera.fov * 0.5)) * 1.15 * _perto
	var olho := maxf(centro.y, 0.4)
	return [
		[centro + Vector3(0.0, olho * 0.35, dist), centro],
		[centro + Vector3(dist * 0.72, olho * 0.5 + 0.3, dist * 0.72), centro],
		[centro + Vector3(dist, olho * 0.2, 0.0), centro],
		[centro + Vector3(dist * 0.25, dist * 0.95, dist * 0.45), centro],
	]


func _montar(sup: Dictionary, moderno: bool) -> void:
	if _raiz != null:
		_raiz.queue_free()
	_raiz = Node3D.new()
	root.add_child(_raiz)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# O ar da loja na rua (resources/fog/fog_mercado_rua.tres): 0,38 de um
	# verde-acinzentado. Mais que isso lava a cor e a bancada mente.
	env.ambient_light_color = Color(0.753, 0.804, 0.792)
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	ambiente.environment = env
	_raiz.add_child(ambiente)
	# A calha da loja: branca e alta, e uma luz de preenchimento baixa do lado
	# da camera, que e o que a gondola da frente devolve no salao.
	for l: Array in [[Vector3(0.0, 2.7, 1.2), 2.4, 9.0], [Vector3(1.8, 1.4, 2.4), 0.6, 7.0],
			[Vector3(-2.0, 2.2, -1.0), 0.5, 7.0]]:
		var luz := OmniLight3D.new()
		luz.position = l[0]
		luz.light_energy = l[1]
		luz.omni_range = l[2]
		luz.light_color = Color(0.96, 0.98, 1.0)
		_raiz.add_child(luz)
	_camera = Camera3D.new()
	_camera.fov = 50.0
	_raiz.add_child(_camera)
	_camera.make_current()
	for nome: StringName in sup:
		var mi := MeshInstance3D.new()
		mi.name = String(nome)
		mi.mesh = PSXMesh.dados_para_mesh(sup[nome])
		mi.material_override = _material(nome, moderno)
		_raiz.add_child(mi)


func _material(nome: StringName, moderno: bool) -> Material:
	var caminho := DIR_MAT + "mat_" + String(nome) + ".tres"
	if not ResourceLoader.exists(caminho):
		printerr("[pecas] sem material: " + caminho)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.MAGENTA
		m.vertex_color_use_as_albedo = true
		return m
	var mat := (load(caminho) as ShaderMaterial).duplicate() as ShaderMaterial
	# Material de shader PROPRIO (o vidro da vitrine, por exemplo) fica como
	# esta. Trocar o shader dele pelo de superficie apaga a transparencia e a
	# estufa de salgados sai como um bloco fechado — defeito da bancada, nao da
	# peca (memoria "vidro da Carroceria e opaco").
	var atual := mat.shader.resource_path if mat.shader != null else ""
	if atual != PIXEL and atual != SUPERFICIE:
		return mat
	if moderno:
		mat.shader = load(PIXEL) as Shader
		var tex := mat.get_shader_parameter(&"albedo_tex") as Texture2D
		if tex != null:
			TexturasHD.aplicar(mat, StringName(tex.resource_path.get_file().get_basename()), true)
	else:
		mat.shader = load(SUPERFICIE) as Shader
	return mat
