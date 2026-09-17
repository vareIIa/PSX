## Chuva fora do carro: os criterios A18 e A19 do PLANO_AAA_4K.
##
##     godot --path game --resolution 1600x900 --script res://tests/bancada_chuva_fora.gd
##     (SEM --headless: shader so existe com janela)
##     --saida=DIR grava as fotos
##
## O que cada medida faz
## ---------------------
## A18a  **Gota na lataria em 1 s.** O capo de um Marea, foto seca e foto um
##       segundo depois de a chuva comecar (a rampa de verdade do `Clima`, 4 s
##       de zero a cheia). Gota e respingo sao desenho de alta frequencia: a
##       medida e a energia do laplaciano da luminancia no capo.
## A18b  **Goteira.** Nao cabe aqui: precisa do chunk. Ver `--rota-goteiras`.
## A18c  **Roupa encharca.** Um `Corpo` de verdade, seco e com o encharcado de
##       30 s de chuva cheia (`DiretorChuvaFora.TEMPO_ENCHARCA`). Luminancia
##       media da silhueta.
## A18d  **Gota na lente so com ceu aberto.** A `GotasLente` com a chuva caindo:
##       gotas e pixels mudados a ceu aberto; depois um telhado sobre a camera,
##       e nenhuma gota em 5 s.
## A19a  **Rastro na poca.** Rua molhada a noite, um poste a frente: o reflexo
##       dele e um risco comprido no asfalto. As rodas passam por cima do risco;
##       dentro do rastro o reflexo cai, e volta quando a chuva fecha a lamina.
## A19b  **Jato d'agua.** O `SprayRoda` de verdade, a 12 m/s, com velocidade
##       constante e acelerando.
## A19c  **Farol risca o asfalto molhado.** O farol do `Carro` (mesma energia,
##       cone e inclinacao) de frente para a camera, rua seca e molhada: o
##       comprimento do risco abaixo do farol.
##
## Tonemap LINEAR: a medida e de luz.
extends SceneTree

const QUADROS := 12
const PIXEL := "res://shaders/psx_surface_pixel.gdshader"
const DIR_MAT := "res://resources/materials/"

var _raiz: Node3D
var _camera: Camera3D
var _env: Environment
var _sol: DirectionalLight3D
var _clima: Node
var _saida := ""
var _tabela := {}
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
	mat_ceu.sky_top_color = Color(0.42, 0.47, 0.55)
	mat_ceu.sky_horizon_color = Color(0.70, 0.72, 0.74)
	mat_ceu.ground_bottom_color = Color(0.12, 0.12, 0.13)
	mat_ceu.ground_horizon_color = Color(0.5, 0.5, 0.52)
	ceu.sky_material = mat_ceu
	_env.sky = ceu
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	ambiente.environment = _env
	_raiz.add_child(ambiente)

	_sol = DirectionalLight3D.new()
	_sol.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	_sol.light_energy = 0.9
	_raiz.add_child(_sol)

	_camera = Camera3D.new()
	_camera.fov = 60.0
	_camera.far = 300.0
	_raiz.add_child(_camera)
	return _raiz


## O chao sai depois dos autoloads: o material le a tabela da `EstiloVisual`,
## que usa `Settings`.
func _montar_chao() -> void:
	# Chao com colisao: o rastro acha o asfalto por raio.
	var chao := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(80.0, 0.2, 80.0)
	forma.shape = caixa
	forma.position = Vector3(0.0, -0.1, 0.0)
	chao.add_child(forma)
	var malha := MeshInstance3D.new()
	malha.mesh = load("res://src/render/psx_mesh.gd").call(&"plane", Vector2(80.0, 80.0))
	malha.material_override = _material(&"mat_asfalto")
	# `PSXMesh.plane` nasce em pe, no plano XY, olhando para +Z.
	malha.rotation_degrees.x = -90.0
	chao.add_child(malha)
	_raiz.add_child(chao)


## Copia do material do jogo com o shader por pixel e a linha da tabela de
## molhabilidade da `EstiloVisual` — o mesmo que o MODERNO faz, sem depender do
## estilo gravado no `settings.cfg` desta maquina.
func _material(nome: StringName) -> ShaderMaterial:
	if _tabela.is_empty():
		_tabela = (load("res://src/render/estilo_visual.gd") as GDScript) \
			.get_script_constant_map()["MOLHABILIDADE"]
	var m := (load(DIR_MAT + String(nome) + ".tres") as ShaderMaterial).duplicate() as ShaderMaterial
	m.shader = load(PIXEL) as Shader
	var d: Dictionary = _tabela.get(nome, {})
	m.set_shader_parameter(&"molha", float(d.get(&"molha", 1.0)))
	m.set_shader_parameter(&"rugosidade_molhada", float(d.get(&"rugosidade", 0.12)))
	m.set_shader_parameter(&"gotas", float(d.get(&"gotas", 0.0)))
	m.set_shader_parameter(&"roupa", float(d.get(&"roupa", 0.0)))
	return m


func _medir() -> void:
	await process_frame
	await process_frame
	# Resolucao cheia na captura: no modo `viewport` a raiz desenha em 480x270,
	# e gota de 5 mm nao existe nessa grade.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_montar_chao()
	_clima = root.get_node(^"Clima")
	var settings := root.get_node(^"Settings")
	# Variavel simples, sem gravar: o spray so sai no MODERNO.
	settings.set(&"luz_por_pixel", true)
	_chover(0.0, true)
	_molhar(0.0)

	await _medir_lataria()
	await _medir_roupa()
	await _medir_lente()
	await _medir_rastro()
	await _medir_spray()
	await _medir_farol()
	print("[chuva-fora] %d de %d criterios" % [_passou, _total])
	quit(0 if _passou == _total else 1)


func _conta(nome: String, ok: bool, texto: String) -> void:
	_total += 1
	if ok:
		_passou += 1
	print("[chuva-fora] %s %s: %s" % [nome, "OK" if ok else "FALHOU", texto])


## Chuva caindo: `imediato` pula a rampa de 4 s do Clima.
func _chover(v: float, imediato: bool) -> void:
	_clima.set(&"_chuva_travada", v)
	if imediato:
		_clima.set(&"chuva", v)
		RenderingServer.global_shader_parameter_set(&"psx_chuva", v)


func _molhar(v: float) -> void:
	_clima.set(&"_travado", v)
	_clima.set(&"molhado", v)
	RenderingServer.global_shader_parameter_set(&"psx_molhado", v)


# ----------------------------------------------------------------------- A18a

func _medir_lataria() -> void:
	var carroceria := load("res://src/render/carroceria.gd") as GDScript
	var modelos: Dictionary = carroceria.get_script_constant_map()["Modelo"]
	var medidas: Dictionary = carroceria.call(&"montar", modelos["MAREA"],
		Color(0.55, 0.08, 0.07), 7)
	var corpo := MeshInstance3D.new()
	corpo.mesh = medidas["corpo"]
	corpo.material_override = _material(&"mat_carro")
	_raiz.add_child(corpo)

	var aabb := corpo.mesh.get_aabb()
	var capo := Vector3(0.0, aabb.end.y * 0.72, aabb.position.z + aabb.size.z * 0.2)
	_camera.look_at_from_position(capo + Vector3(0.9, 0.75, -1.05), capo, Vector3.UP)

	var seca := await _foto("lataria_seca")
	_chover(1.0, false)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1000:
		await process_frame
	await RenderingServer.frame_post_draw
	var chuva_1s: float = _clima.get(&"chuva")
	var molhada := _captura("lataria_1s")
	var e_seca := _energia(seca)
	var e_1s := _energia(molhada)
	_conta("A18a gota na lataria em 1 s", e_1s >= e_seca * 1.5,
		"energia do capo %.4f -> %.4f (%.2fx), chuva %.2f no instante da foto"
		% [e_seca, e_1s, e_1s / maxf(e_seca, 1e-6), chuva_1s])
	_chover(0.0, true)
	corpo.queue_free()


# ----------------------------------------------------------------------- A18c

func _medir_roupa() -> void:
	var registro := root.get_node(^"RegistroCivil")
	var ficha: Dictionary = registro.call(&"identidade", 31337)
	var corpo := (load("res://src/render/corpo.gd") as GDScript).new() as Node3D
	_raiz.add_child(corpo)
	corpo.call(&"montar", ficha["aparencia"])
	await process_frame
	var pele := corpo.find_child("Pele", true, false) as MeshInstance3D
	var mat := _material(&"mat_npc")
	pele.material_override = mat
	_camera.look_at_from_position(Vector3(0.0, 1.0, -2.6), Vector3(0.0, 0.95, 0.0), Vector3.UP)

	var tempo: float = (load("res://src/world/diretor_chuva_fora.gd") as GDScript) \
		.get_script_constant_map()["TEMPO_ENCHARCA"]
	var e30 := minf(1.0, 30.0 / tempo)
	corpo.visible = false
	var fundo := await _foto("roupa_fundo")
	corpo.visible = true
	mat.set_shader_parameter(&"encharcado", 0.0)
	var seca := await _foto("roupa_seca")
	mat.set_shader_parameter(&"encharcado", e30)
	var molhada := await _foto("roupa_30s")
	var mascara := _mascara(fundo, seca)
	var l_seca := _media(seca, mascara)
	var l_molhada := _media(molhada, mascara)
	var escurece := 1.0 - l_molhada / maxf(l_seca, 1e-6)
	_conta("A18c roupa encharca em 30 s", escurece >= 0.20,
		"encharcado %.2f, silhueta %d px, luminancia %.3f -> %.3f (%.0f%% mais escura)"
		% [e30, mascara.size(), l_seca, l_molhada, escurece * 100.0])
	corpo.queue_free()


# ----------------------------------------------------------------------- A18d

func _medir_lente() -> void:
	var carroceria := load("res://src/render/carroceria.gd") as GDScript
	var modelos: Dictionary = carroceria.get_script_constant_map()["Modelo"]
	var medidas: Dictionary = carroceria.call(&"montar", modelos["FUSCA"],
		Color(0.2, 0.3, 0.6), 3)
	var carro := MeshInstance3D.new()
	carro.mesh = medidas["corpo"]
	carro.material_override = _material(&"mat_carro")
	carro.position = Vector3(0.0, 0.0, -4.0)
	_raiz.add_child(carro)
	_camera.look_at_from_position(Vector3(0.6, 1.7, 0.0), Vector3(0.0, 0.8, -4.0), Vector3.UP)

	var lente := (load("res://src/render/gotas_lente.gd") as GDScript).new() as CanvasLayer
	lente.set(&"forcar", 1)
	root.add_child(lente)
	_chover(1.0, true)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 7000:
		await process_frame
	var abertas: int = lente.call(&"quantas")
	# Foto com a chuva parada: o anel de impacto no chao muda a cada quadro e
	# contaria como gota. A gota que ja esta no vidro continua la.
	_chover(0.0, true)
	var com := await _foto("lente_aberta")
	lente.visible = false
	var sem := await _foto("lente_sem")
	# Piso de ruido: duas fotos sem gota diferem pelo tremor do TAA.
	var sem2 := await _foto("lente_sem2")
	lente.visible = true
	var ruido := _fracao_mudada(sem, sem2)
	var mudou_aberto := _fracao_mudada(com, sem) - ruido

	# Telhado a 3 m sobre a camera.
	var teto := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(6.0, 0.2, 6.0)
	forma.shape = caixa
	teto.add_child(forma)
	teto.position = _camera.global_position + Vector3(0.0, 3.0, 0.0)
	_raiz.add_child(teto)
	_chover(1.0, true)
	t0 = Time.get_ticks_msec()
	var maximo := 0
	while Time.get_ticks_msec() - t0 < 5000:
		await process_frame
	var cobertas: int = lente.call(&"quantas")
	_chover(0.0, true)
	com = await _foto("lente_coberta")
	lente.visible = false
	sem = await _foto("lente_coberta_sem")
	var mudou_coberto := _fracao_mudada(com, sem) - ruido
	maximo = cobertas
	_conta("A18d gota na lente so sem cobertura",
		# A gota e mancha fora de foco, de proposito: 0,2% da tela ja e ela.
		abertas >= 3 and mudou_aberto >= 0.002 and maximo == 0
			and mudou_coberto <= 0.0003,
		"ceu aberto: %d gotas, %.2f%% da tela; coberta 5 s: %d gotas, %.3f%% (ruido %.3f%% descontado)"
		% [abertas, mudou_aberto * 100.0, cobertas, mudou_coberto * 100.0, ruido * 100.0])
	lente.queue_free()
	teto.queue_free()
	carro.queue_free()
	_chover(0.0, true)


# ----------------------------------------------------------------------- A19a

func _noite() -> OmniLight3D:
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.02, 0.022, 0.03)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.05, 0.05, 0.06)
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	_sol.visible = false
	var poste := OmniLight3D.new()
	poste.position = Vector3(0.7, 4.5, -16.0)
	poste.omni_range = 18.0
	poste.light_energy = 6.0
	poste.light_color = Color(1.0, 0.72, 0.42)
	_raiz.add_child(poste)
	return poste


## Um carro de mentira: quatro `VehicleWheel3D` e `velocidade()`. O rastro e o
## spray so pedem isso.
func _carro_falso(vel: float) -> Node3D:
	var s := GDScript.new()
	s.source_code = "extends Node3D\nvar v := 0.0\nfunc velocidade() -> float:\n\treturn v\n"
	s.reload()
	var c := Node3D.new()
	c.set_script(s)
	c.set(&"v", vel)
	for k in 4:
		var r := VehicleWheel3D.new()
		r.name = "Roda%d" % k
		r.wheel_radius = 0.3
		r.position = Vector3(0.7 if k % 2 == 0 else -0.7, 0.3, -1.2 if k < 2 else 1.2)
		c.add_child(r)
	_raiz.add_child(c)
	return c


func _rodas(c: Node3D) -> Array[VehicleWheel3D]:
	var lista: Array[VehicleWheel3D] = []
	for k in 4:
		lista.append(c.get_node(NodePath("Roda%d" % k)) as VehicleWheel3D)
	return lista


func _medir_rastro() -> void:
	var poste := _noite()
	_molhar(1.0)
	_camera.look_at_from_position(Vector3(0.7, 1.6, 2.0), Vector3(0.7, 0.0, -12.0), Vector3.UP)
	var antes := await _foto("rastro_antes")

	var carro := _carro_falso(8.0)
	carro.position = Vector3(0.0, 0.0, -3.0)
	var rastro := (load("res://src/world/rastro_molhado.gd") as GDScript).new() as Node3D
	carro.add_child(rastro)
	var rodas := _rodas(carro)
	rastro.call(&"acompanhar", carro, [rodas[2], rodas[3]] as Array[VehicleWheel3D])
	while carro.position.z > -14.0:
		await physics_frame
		carro.position.z -= 8.0 / float(Engine.physics_ticks_per_second)
	# O carro sai do quadro para nao tapar o risco.
	carro.position = Vector3(0.0, 0.0, -60.0)
	await RenderingServer.frame_post_draw
	var logo := _captura("rastro_logo")
	var carimbos: int = rastro.call(&"carimbos")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3500:
		await process_frame
	var depois := await _foto("rastro_depois")

	# Onde a roda passou E o poste reflete: a linha da roda direita, projetada
	# na tela, cruzada com o risco da foto de antes.
	var faixa := _faixa_do_risco(antes)
	var trilha := _linha_na_tela(Vector3(0.7, 0.0, -4.0), Vector3(0.7, 0.0, -13.0), 0.07)
	faixa = _cruzar(faixa, trilha)
	var l_antes := _media_faixa(antes, faixa)
	var l_logo := _media_faixa(logo, faixa)
	var l_depois := _media_faixa(depois, faixa)
	_conta("A19a pneu deixa rastro na poca",
		faixa.size() > 200 and l_antes > 0.02 and carimbos >= 4 and l_logo <= l_antes * 0.75
			and l_depois >= l_antes * 0.95,
		"%d pedacos; reflexo na trilha (%d px) %.3f -> %.3f (%.0f%%) -> %.3f depois de 3,5 s"
		% [carimbos, faixa.size(), l_antes, l_logo, l_logo / maxf(l_antes, 1e-6) * 100.0,
			l_depois])
	carro.queue_free()
	poste.queue_free()


# ----------------------------------------------------------------------- A19b

func _medir_spray() -> void:
	var poste := OmniLight3D.new()
	poste.position = Vector3(2.0, 3.0, 1.0)
	poste.omni_range = 12.0
	poste.light_energy = 4.0
	_raiz.add_child(poste)
	_camera.look_at_from_position(Vector3(3.2, 1.3, 4.5), Vector3(0.0, 0.3, 1.0), Vector3.UP)
	var carro := _carro_falso(12.0)
	var spray := (load("res://src/world/spray_roda.gd") as GDScript).new() as Node3D
	carro.add_child(spray)
	spray.call(&"acompanhar", carro, _rodas(carro))
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1500:
		await process_frame
	var com := await _foto("spray_constante")
	spray.visible = false
	var sem := await _foto("spray_sem")
	spray.visible = true
	var constante := _fracao_mudada(com, sem)

	# Acelerando: a velocidade muda a cada quadro de fisica.
	var v := 8.0
	t0 = Time.get_ticks_msec()
	var foto_acel: Image = null
	while Time.get_ticks_msec() - t0 < 1500:
		await physics_frame
		v = 8.0 + fmod(v - 8.0 + 0.05, 10.0)
		carro.set(&"v", v)
	await RenderingServer.frame_post_draw
	foto_acel = _captura("spray_acelerando")
	var acelerando := _fracao_mudada(foto_acel, sem)
	_conta("A19b jato d'agua da roda",
		constante >= 0.002 and acelerando >= constante * 0.5,
		"%.2f%% da tela a 12 m/s constante; %.2f%% acelerando"
		% [constante * 100.0, acelerando * 100.0])
	carro.queue_free()
	poste.queue_free()


# ----------------------------------------------------------------------- A19c

func _medir_farol() -> void:
	var consts: Dictionary = (load("res://src/world/carro.gd") as GDScript).get_script_constant_map()
	var farol := SpotLight3D.new()
	farol.position = Vector3(0.0, 0.62, -20.0)
	# Virado para a camera (+Z), com a inclinacao do jogo.
	farol.rotation = Vector3(deg_to_rad(float(consts["FAROL_INCLINACAO"])), PI, 0.0)
	farol.spot_range = 26.0
	farol.spot_angle = 34.0
	farol.spot_angle_attenuation = 0.9
	farol.light_energy = 3.2
	farol.light_color = Color(1.0, 0.95, 0.86)
	_raiz.add_child(farol)
	_camera.look_at_from_position(Vector3(0.0, 1.6, -6.0), Vector3(0.0, 0.3, -20.0), Vector3.UP)
	var tela := _camera.unproject_position(farol.global_position)

	_molhar(0.0)
	var seca := await _foto("farol_seco")
	_molhar(1.0)
	var molhada := await _foto("farol_molhado")
	var risco_seco := _comprimento_do_risco(seca, tela)
	var risco_molhado := _comprimento_do_risco(molhada, tela)
	_conta("A19c farol risca o asfalto molhado",
		risco_molhado >= maxi(risco_seco * 2, 20),
		"risco abaixo do farol: seco %d px, molhado %d px" % [risco_seco, risco_molhado])
	farol.queue_free()
	_molhar(0.0)


# ------------------------------------------------------------------ medidas

func _foto(nome: String) -> Image:
	for i in QUADROS:
		await process_frame
	await RenderingServer.frame_post_draw
	return _captura(nome)


func _captura(nome: String) -> Image:
	var img := root.get_texture().get_image()
	if img != null and _saida != "":
		img.save_png("%s/%s.png" % [_saida, nome])
	return img


static func _lum(c: Color) -> float:
	return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722


## Energia media do laplaciano no terco central da imagem.
static func _energia(img: Image) -> float:
	var w := img.get_width()
	var h := img.get_height()
	var soma := 0.0
	var n := 0
	for y in range(h / 3, h * 2 / 3):
		for x in range(w / 3, w * 2 / 3):
			var c := _lum(img.get_pixel(x, y))
			var viz := _lum(img.get_pixel(x - 1, y)) + _lum(img.get_pixel(x + 1, y)) \
				+ _lum(img.get_pixel(x, y - 1)) + _lum(img.get_pixel(x, y + 1))
			soma += absf(4.0 * c - viz)
			n += 1
	return soma / float(n)


static func _mascara(fundo: Image, com: Image) -> PackedInt32Array:
	var m := PackedInt32Array()
	var w := com.get_width()
	for y in com.get_height():
		for x in w:
			var a := fundo.get_pixel(x, y)
			var b := com.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.06:
				m.append(y * w + x)
	return m


static func _media(img: Image, mascara: PackedInt32Array) -> float:
	var w := img.get_width()
	var soma := 0.0
	for i in mascara:
		soma += _lum(img.get_pixel(i % w, i / w))
	return soma / float(maxi(mascara.size(), 1))


static func _fracao_mudada(a: Image, b: Image) -> float:
	var n := 0
	var w := a.get_width()
	var h := a.get_height()
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > 0.1:
				n += 1
	return float(n) / float((w / 2) * (h / 2))


## Colunas e linhas do risco do poste na foto de antes: os pixels do chao mais
## claros que o dobro da mediana, na metade de baixo.
static func _faixa_do_risco(img: Image) -> PackedInt32Array:
	var w := img.get_width()
	var h := img.get_height()
	var valores: Array[float] = []
	for y in range(h / 2, h, 3):
		for x in range(0, w, 3):
			valores.append(_lum(img.get_pixel(x, y)))
	valores.sort()
	var limiar := maxf(valores[valores.size() * 9 / 10], 0.02)
	var faixa := PackedInt32Array()
	for y in range(h / 2, h):
		for x in w:
			if _lum(img.get_pixel(x, y)) >= limiar:
				faixa.append(y * w + x)
	return faixa


## Pixels da tela a menos de `meia` metros do segmento de chao `a`-`b`.
func _linha_na_tela(a: Vector3, b: Vector3, meia: float) -> PackedInt32Array:
	var w := root.get_texture().get_width()
	var h := root.get_texture().get_height()
	var marcados := {}
	var passos := 400
	for i in passos + 1:
		var p := a.lerp(b, float(i) / float(passos))
		var centro := _camera.unproject_position(p)
		var lado := _camera.unproject_position(p + Vector3(meia, 0.0, 0.0))
		var r := maxi(1, int(absf(lado.x - centro.x)))
		for x in range(int(centro.x) - r, int(centro.x) + r + 1):
			var y := int(centro.y)
			if x >= 0 and x < w and y >= 0 and y < h:
				marcados[y * w + x] = true
	return PackedInt32Array(marcados.keys())


static func _cruzar(a: PackedInt32Array, b: PackedInt32Array) -> PackedInt32Array:
	var em_b := {}
	for i in b:
		em_b[i] = true
	var r := PackedInt32Array()
	for i in a:
		if em_b.has(i):
			r.append(i)
	return r


static func _media_faixa(img: Image, faixa: PackedInt32Array) -> float:
	return _media(img, faixa)


## Linhas abaixo do farol, numa coluna de 2% da largura, mais claras que 0,12.
static func _comprimento_do_risco(img: Image, farol: Vector2) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var meia := int(w * 0.01)
	var n := 0
	for y in range(int(farol.y) + int(h * 0.02), h):
		var soma := 0.0
		for x in range(int(farol.x) - meia, int(farol.x) + meia + 1):
			soma += _lum(img.get_pixel(clampi(x, 0, w - 1), y))
		if soma / float(meia * 2 + 1) > 0.12:
			n += 1
	return n
