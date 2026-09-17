## Janela e fachada: os criterios A34 e A35 do PLANO_AAA_4K.
##
##     godot --path game --resolution 1600x900 --script res://tests/bancada_fachada.gd
##     (SEM --headless: shader so existe com janela)
##     --saida=DIR grava as fotos
##
## O que cada medida faz
## ---------------------
## A34a  **A janela tem fundo.** Duas fotos da MESMA janela, com a camera
##       deslocada de lado e sempre apontada para ela. A medida procura, por
##       correlacao, de quantos PIXELS o desenho andou dentro do vidro e de
##       quantos andou na parede ao lado. Textura chapada anda junto com a
##       parede; comodo de verdade anda por dentro (paralaxe).
## A34b  **A janela reflete o que esta em volta.** Rasante contra de frente, no
##       vidro E no reboco ao lado, na mesma foto. Superficie fosca quase nao
##       muda com o angulo; vidro muda, porque o Fresnel cresce ate 1 na
##       rasante. O numero e o GANHO do vidro sobre o da parede — medir so o
##       vidro mediria o brilho do ambiente da bancada, e nao a janela.
## A34c  **A janela tem esquadria.** Fracao de pixels de caixilho dentro do vao.
## A35   **Tabela de molhabilidade completa.** Varre `resources/materials/`: todo
##       material de superficie tem de estar na tabela da `EstiloVisual`, ter
##       prefixo de abrigado, ou estar na lista `SEM_CHUVA`. Sem isso, material
##       novo cai no padrao 0,12 — o numero da poca — e vira espelho na chuva.
extends SceneTree

const QUADROS := 10
const DIR_MAT := "res://resources/materials/"
const PIXEL := "res://shaders/psx_surface_pixel.gdshader"
const JANELA := "res://shaders/psx_janela.gdshader"
## Onde a parede fica, e o tamanho da janela do `KitModular`.
const JANELA_TAM := Vector2(1.1, 1.3)
const JANELA_Y := 2.2

var _raiz: Node3D
var _camera: Camera3D
var _env: Environment
var _saida := ""
var _passou := 0
var _total := 0


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
	root.add_child.call_deferred(_montar())
	_medir()


func _montar() -> Node3D:
	_raiz = Node3D.new()
	var ambiente := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	var ceu := Sky.new()
	var mat_ceu := ProceduralSkyMaterial.new()
	mat_ceu.sky_top_color = Color(0.35, 0.48, 0.72)
	mat_ceu.sky_horizon_color = Color(0.75, 0.78, 0.82)
	# O "chao" do ceu procedural nao e decoracao: rasante, a janela reflete o
	# que esta na horizontal, que numa rua e a calcada e o predio da frente ao
	# sol. Com chao preto a medida do Fresnel media o vazio.
	mat_ceu.ground_bottom_color = Color(0.34, 0.33, 0.31)
	mat_ceu.ground_horizon_color = Color(0.62, 0.61, 0.58)
	ceu.sky_material = mat_ceu
	_env.sky = ceu
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	ambiente.environment = _env
	_raiz.add_child(ambiente)

	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-42.0, 35.0, 0.0)
	sol.light_energy = 1.1
	_raiz.add_child(sol)

	_camera = Camera3D.new()
	_camera.fov = 55.0
	_raiz.add_child(_camera)
	return _raiz


func _material(nome: StringName, shader: String) -> ShaderMaterial:
	var m := (load(DIR_MAT + String(nome) + ".tres") as ShaderMaterial).duplicate() as ShaderMaterial
	m.shader = load(shader) as Shader
	return m


## Uma parede de reboco com uma janela no meio, montada pelo kit do jogo.
func _montar_parede() -> void:
	var km := load("res://src/world/kit_modular.gd") as GDScript
	var psx := load("res://src/render/psx_mesh.gd") as GDScript
	var sup := {}
	km.call(&"parede", sup, &"reboco", Vector3(0.0, 3.0, 0.0), Vector2(8.0, 6.0), 0)
	km.call(&"parede", sup, &"janela_acesa",
		Vector3(0.0, JANELA_Y, 0.06), JANELA_TAM, 0)
	km.call(&"parede", sup, &"janela_apagada",
		Vector3(2.0, JANELA_Y, 0.06), JANELA_TAM, 0)
	for chave: StringName in sup:
		var mi := MeshInstance3D.new()
		mi.name = String(chave)
		mi.mesh = psx.call(&"dados_para_mesh", sup[chave])
		var nome := StringName("mat_" + String(chave))
		mi.material_override = _material(nome,
			JANELA if String(chave).begins_with("janela") else PIXEL)
		if String(chave).begins_with("janela"):
			mi.material_override.set_shader_parameter(&"acesa", chave == &"janela_acesa")
		_raiz.add_child(mi)


func _medir() -> void:
	await process_frame
	await process_frame
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_montar_parede()
	await _medir_fundo()
	await _medir_reflexo()
	_medir_tabela()
	print("[fachada] %d de %d criterios" % [_passou, _total])
	quit(0 if _passou == _total else 1)


func _conta(nome: String, ok: bool, texto: String) -> void:
	_total += 1
	if ok:
		_passou += 1
	print("[fachada] %s %s: %s" % [nome, "OK" if ok else "FALHOU", texto])


# ----------------------------------------------------------------- A34a e A34c

func _medir_fundo() -> void:
	var alvo := Vector3(0.0, JANELA_Y, 0.0)
	_camera.look_at_from_position(Vector3(-0.35, JANELA_Y, 2.6), alvo, Vector3.UP)
	var a := await _foto("janela_esquerda")
	var caixa_a := _caixa_da_janela(alvo)
	var parede_a := _caixa_da_parede(alvo)
	_camera.look_at_from_position(Vector3(0.35, JANELA_Y, 2.6), alvo, Vector3.UP)
	var b := await _foto("janela_direita")

	# O que vale e o deslocamento do desenho DE DENTRO em relacao a propria
	# esquadria: a janela inteira tambem anda na tela quando a camera anda.
	var anda_vidro := _deslocamento(a, b, caixa_a)
	var anda_moldura := _deslocamento(a, b, _anel_da_janela(alvo))
	var anda_parede := _deslocamento(a, b, parede_a)
	var paralaxe: int = absi(anda_vidro - anda_moldura)
	_conta("A34a a janela tem fundo", paralaxe >= 3,
		"com a camera andando 70 cm: o vidro anda %d px, a esquadria %d px (paralaxe %d px); a parede ao lado anda %d px"
		% [anda_vidro, anda_moldura, paralaxe, anda_parede])

	# Esquadria: pixels escuros e sem brilho no anel de fora do vao.
	var fracao := _fracao_de_esquadria(b, _caixa_da_janela(alvo))
	_conta("A34c a janela tem esquadria", fracao >= 0.08 and fracao <= 0.5,
		"caixilho e montante ocupam %.0f%% do vao" % (fracao * 100.0))


# ----------------------------------------------------------------------- A34b

func _medir_reflexo() -> void:
	# Na janela APAGADA: na acesa, a luz de dentro abafa o Fresnel e a medida
	# vira uma medida de lampada.
	var alvo := Vector3(2.0, JANELA_Y, 0.0)
	_camera.look_at_from_position(alvo + Vector3(0.0, 0.0, 3.0), alvo, Vector3.UP)
	var frente := await _foto("janela_de_frente")
	var l_frente := _media(frente, _caixa_da_janela(alvo))
	var p_frente := _media(frente, _caixa_da_parede(alvo))
	# Rasante: 75 graus fora da normal.
	var d := 3.0
	_camera.look_at_from_position(
		alvo + Vector3(-sin(deg_to_rad(75.0)) * d, 0.0, cos(deg_to_rad(75.0)) * d),
		alvo, Vector3.UP)
	var rasante := await _foto("janela_rasante")
	var l_rasante := _media(rasante, _caixa_da_janela(alvo))
	var p_rasante := _media(rasante, _caixa_da_parede(alvo))
	var ganho_vidro := l_rasante / maxf(l_frente, 1e-4)
	var ganho_parede := p_rasante / maxf(p_frente, 1e-4)
	_conta("A34b a janela reflete o que esta em volta",
		ganho_vidro >= ganho_parede * 1.3,
		"do frontal para a rasante o vidro ganha %.2fx (%.3f -> %.3f) e o reboco ao lado %.2fx"
		% [ganho_vidro, l_frente, l_rasante, ganho_parede])


# ------------------------------------------------------------------------ A35

func _medir_tabela() -> void:
	var ev := (load("res://src/render/estilo_visual.gd") as GDScript).get_script_constant_map()
	var tabela: Dictionary = ev["MOLHABILIDADE"]
	var abrigados: Array = ev["ABRIGADOS"]
	var sem_chuva: Array = ev["SEM_CHUVA"]
	var faltando: Array[String] = []
	for arq: String in DirAccess.get_files_at(DIR_MAT):
		var nome := arq.trim_suffix(".remap")
		if not nome.ends_with(".tres"):
			continue
		var mat := load(DIR_MAT + nome) as ShaderMaterial
		if mat == null or mat.shader == null or not mat.shader.resource_path.contains("psx_surface"):
			continue
		var id := StringName(nome.trim_suffix(".tres"))
		if tabela.has(id) or sem_chuva.has(id):
			continue
		var abrigado := false
		for prefixo: String in abrigados:
			if String(id).begins_with(prefixo):
				abrigado = true
				break
		if not abrigado:
			faltando.append(String(id))
	faltando.sort()
	_conta("A35 tabela de molhabilidade completa", faltando.is_empty(),
		"%d materiais de superficie fora da tabela%s"
		% [faltando.size(), "" if faltando.is_empty() else ": " + ", ".join(faltando)])


# ------------------------------------------------------------------- medidas

func _foto(nome: String) -> Image:
	for i in QUADROS:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img != null and _saida != "":
		img.save_png("%s/%s.png" % [_saida, nome])
	return img


## Retangulo do vao da janela na tela, ja por dentro do caixilho.
func _caixa_da_janela(centro: Vector3) -> Rect2i:
	var a := _camera.unproject_position(centro + Vector3(-JANELA_TAM.x * 0.32, JANELA_TAM.y * 0.3, 0.0))
	var b := _camera.unproject_position(centro + Vector3(JANELA_TAM.x * 0.32, -JANELA_TAM.y * 0.3, 0.0))
	return _rect(a, b)


## O anel da esquadria: a moldura da propria janela, que anda com a parede.
func _anel_da_janela(centro: Vector3) -> Rect2i:
	var a := _camera.unproject_position(centro + Vector3(-JANELA_TAM.x * 0.5, JANELA_TAM.y * 0.5, 0.0))
	var b := _camera.unproject_position(centro + Vector3(JANELA_TAM.x * 0.5, JANELA_TAM.y * 0.42, 0.0))
	return _rect(a, b)


## Um pedaco de parede do mesmo tamanho, ao lado da janela: o controle.
func _caixa_da_parede(centro: Vector3) -> Rect2i:
	var d := Vector3(1.05, 0.0, 0.0)
	var a := _camera.unproject_position(centro + d + Vector3(-JANELA_TAM.x * 0.32, JANELA_TAM.y * 0.3, 0.0))
	var b := _camera.unproject_position(centro + d + Vector3(JANELA_TAM.x * 0.32, -JANELA_TAM.y * 0.3, 0.0))
	return _rect(a, b)


static func _rect(a: Vector2, b: Vector2) -> Rect2i:
	var x0 := int(minf(a.x, b.x))
	var y0 := int(minf(a.y, b.y))
	var x1 := int(maxf(a.x, b.x))
	var y1 := int(maxf(a.y, b.y))
	return Rect2i(x0, y0, maxi(x1 - x0, 1), maxi(y1 - y0, 1))


static func _lum(c: Color) -> float:
	return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722


static func _media(img: Image, r: Rect2i) -> float:
	var soma := 0.0
	var n := 0
	for y in range(maxi(r.position.y, 0), mini(r.end.y, img.get_height())):
		for x in range(maxi(r.position.x, 0), mini(r.end.x, img.get_width())):
			soma += _lum(img.get_pixel(x, y))
			n += 1
	return soma / float(maxi(n, 1))


## De quantos pixels o desenho andou de lado entre duas fotos, por correlacao.
static func _deslocamento(a: Image, b: Image, r: Rect2i) -> int:
	var melhor := 0
	var melhor_erro := 1e9
	for dx in range(-24, 25):
		var soma := 0.0
		var n := 0
		for y in range(maxi(r.position.y, 0), mini(r.end.y, a.get_height()), 2):
			for x in range(maxi(r.position.x, 0), mini(r.end.x, a.get_width()), 2):
				var xb := x + dx
				if xb < 0 or xb >= b.get_width():
					continue
				var p := a.get_pixel(x, y)
				var q := b.get_pixel(xb, y)
				soma += absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)
				n += 1
		if n < 16:
			continue
		var erro := soma / float(n)
		if erro < melhor_erro:
			melhor_erro = erro
			melhor = dx
	return melhor


## Diferenca media por pixel entre duas fotos, dentro do retangulo.
static func _mudanca(a: Image, b: Image, r: Rect2i) -> float:
	var soma := 0.0
	var n := 0
	for y in range(maxi(r.position.y, 0), mini(r.end.y, a.get_height())):
		for x in range(maxi(r.position.x, 0), mini(r.end.x, a.get_width())):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			soma += absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)
			n += 1
	return soma / float(maxi(n, 1)) / 3.0


## Pixels de caixilho: no anel de fora do vao, o que nao e nem vidro escuro nem
## luz de dentro.
static func _fracao_de_esquadria(img: Image, vao: Rect2i) -> float:
	var fora := vao.grow(int(maxf(float(vao.size.x) * 0.22, 3.0)))
	var n := 0
	var quadro := 0
	for y in range(maxi(fora.position.y, 0), mini(fora.end.y, img.get_height())):
		for x in range(maxi(fora.position.x, 0), mini(fora.end.x, img.get_width())):
			if vao.has_point(Vector2i(x, y)):
				continue
			quadro += 1
			var l := _lum(img.get_pixel(x, y))
			if l > 0.02 and l < 0.5:
				n += 1
	return float(n) / float(maxi(quadro, 1))
