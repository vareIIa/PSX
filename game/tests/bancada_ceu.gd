## Nuvem com volume e relampago que acende o ceu: o criterio A16 do
## PLANO_AAA_4K.
##
##     godot --path game --script res://tests/bancada_ceu.gd
##     (SEM --headless: shader so existe com janela)
##     --saida=DIR grava as fotos
##
## Por que bancada, e nao a cidade
## -------------------------------
## Na rua a nuvem esta a setenta metros, atras da nevoa, pela metade no quadro,
## com quarenta vizinhas empilhadas por cima. A pergunta "ela tem volume?" nao
## tem resposta ali. Aqui ha UMA nuvem, inteira no quadro, contra um ceu chapado
## — e o que separa nuvem de ceu e so a cor do fundo.
##
## O que cada medida faz
## ---------------------
## A16a  **Volume.** Um billboard pintado nao sabe onde esta o sol: a luz dele e
##       a mesma em cima e embaixo. Uma massa de ar iluminada fica CLARA NO
##       TOPO e escura na barriga. A medida e a razao entre a luminancia do
##       terco de cima da nuvem e a do terco de baixo, com e sem volume.
## A16b  **O relampago acende a nuvem.** A noite, a nuvem e quase o ceu. Com o
##       clarao no pico, a luminancia dela sobe. E o `Relampago` de verdade
##       tem de escrever o valor que a nuvem le — senao o numero de cima seria
##       um uniforme que nenhum raio acende.
##
## Tonemap LINEAR, e nao o AgX do jogo: a medida e de luz, e o AgX mistura
## canais antes de devolver a cor.
##
## Os scripts do jogo entram por `load()` e nao pelo nome da classe. Referencia
## de classe no corpo de um script de `--script` faz o motor compilar a
## dependencia ANTES de os autoloads existirem, e `Nuvens` usa `Settings`.
extends SceneTree

const QUADROS := 20
## Onde a nuvem fica: a 60 m de altura e 110 m a frente. Longe o bastante para
## caber inteira no quadro, perto o bastante para ocupar um terco dele.
const ALVO := Vector3(0.0, 0.0, -110.0)
const ALTURA := 60.0
## Diametro da nuvem, em metros. O meio da faixa que o `DiretorCeu` sorteia.
const TAMANHO := 70.0
## Quanto a cor precisa desviar do fundo para contar como nuvem.
const LIMIAR := 0.02

var _raiz: Node3D
var _camera: Camera3D
var _env: Environment
var _nuvens: GPUParticles3D
var _mat: ShaderMaterial
var _saida := ""


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
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	ambiente.environment = _env
	_raiz.add_child(ambiente)

	_camera = Camera3D.new()
	_camera.fov = 66.0
	_camera.far = 400.0
	_raiz.add_child(_camera)
	return _raiz


func _medir() -> void:
	await process_frame
	await process_frame
	_camera.look_at_from_position(Vector3(0.0, 1.6, 0.0),
		ALVO + Vector3(0.0, ALTURA, 0.0), Vector3.UP)

	# O ponto que a camada de nuvens segue. Ela se poe em cima dele, na altura
	# pedida, e com o vento congelado fica exatamente ali.
	var ancora := Node3D.new()
	ancora.position = ALVO
	_raiz.add_child(ancora)

	_nuvens = load("res://src/world/nuvens.gd").new() as GPUParticles3D
	_nuvens.set(&"quantidade_max", 1)
	_nuvens.set(&"altitude", ALTURA)
	_nuvens.set(&"area", Vector3(0.01, 0.01, 0.01))
	_nuvens.set(&"alvo", ancora)
	_raiz.add_child(_nuvens)
	await process_frame
	var proc := _nuvens.process_material as ParticleProcessMaterial
	proc.scale_min = TAMANHO
	proc.scale_max = TAMANHO
	_nuvens.restart()
	_mat = _nuvens.material_override as ShaderMaterial
	_nuvens.call(&"congelar", 0.0)

	var passou := 0
	passou += await _medir_volume()
	passou += await _medir_relampago()
	print("[ceu] %d de 2 criterios" % passou)
	quit(0 if passou == 2 else 1)


# ----------------------------------------------------------------------- A16a

func _medir_volume() -> int:
	var dia := _preset(Color(0.52, 0.62, 0.78), 1.6, Color(1.0, 0.96, 0.88),
		Vector2(-62.0, 20.0), Color(0.55, 0.60, 0.70), 0.7)
	_usar(dia)

	_mat.set_shader_parameter(&"usa_volume", false)
	var chapada := await _foto("ceu_chapada")
	_mat.set_shader_parameter(&"usa_volume", true)
	var cheia := await _foto("ceu_volume")

	var r_chapada := _topo_sobre_base(chapada, dia.get(&"sky_color"))
	var r_volume := _topo_sobre_base(cheia, dia.get(&"sky_color"))
	print("[ceu] A16a topo/barriga: billboard %.2f, volume %.2f"
		% [r_chapada, r_volume])
	return 1 if r_volume >= 1.30 and r_volume >= r_chapada * 1.2 else 0


# ----------------------------------------------------------------------- A16b

func _medir_relampago() -> int:
	var noite := _preset(Color(0.035, 0.04, 0.06), 0.06, Color(0.62, 0.70, 0.92),
		Vector2(-48.0, 200.0), Color(0.10, 0.11, 0.15), 0.35)
	_usar(noite)
	_mat.set_shader_parameter(&"usa_volume", true)

	# Numa janela FIXA do ceu, e nao nos pixels "que parecem nuvem": a noite a
	# nuvem apagada e quase da cor do ceu, a mascara por cor nao acha pixel
	# nenhum, e a media do nada e zero. O criterio fala de luminancia do ceu.
	RenderingServer.global_shader_parameter_set(&"psx_relampago", 0.0)
	var apagada := _media_da_janela(await _foto("ceu_noite"))
	RenderingServer.global_shader_parameter_set(&"psx_relampago", 1.0)
	var acesa := _media_da_janela(await _foto("ceu_clarao"))
	RenderingServer.global_shader_parameter_set(&"psx_relampago", 0.0)

	# O raio de verdade: dispara e le o uniforme a cada quadro.
	var raio := load("res://src/world/relampago.gd").new() as Node3D
	_raiz.add_child(raio)
	await process_frame
	raio.call(&"disparar", 1.2)
	# Por TEMPO, e nao por quadros: o envelope dura 0,33 s, e a bancada roda sem
	# teto de fps — quarenta quadros acabavam antes da ultima piscada.
	var pico := 0.0
	var final := 1.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 700:
		await process_frame
		var v := float(raio.call(&"clarao"))
		pico = maxf(pico, v)
		final = v

	print("[ceu] A16b nuvem a noite: %.4f apagada, %.4f no clarao (x%.1f) | raio escreveu pico %.2f e voltou a %.2f"
		% [apagada, acesa, acesa / maxf(apagada, 0.0001), pico, final])
	var ok := acesa >= apagada * 1.5 and acesa - apagada >= 0.02
	ok = ok and pico >= 0.75 and final <= 0.001
	return 1 if ok else 0


# ----------------------------------------------------------------------- comum

func _preset(ceu: Color, sol: float, cor_sol: Color, rumo: Vector2,
		ambiente: Color, energia_ambiente: float) -> Resource:
	var p: Resource = load("res://src/world/fog_preset.gd").new()
	p.set(&"sky_color", ceu)
	p.set(&"nuvens", 1.0)
	# Ceu limpo de nevoa. O `FogPreset` nasce com nevoa ligada e fim em 18 m, e
	# a bruma do ceu sai dai: com o padrao, a nuvem da bancada ficava 73% bruma.
	p.set(&"fog_enabled", false)
	p.set(&"sol_energia", sol)
	p.set(&"sol_cor", cor_sol)
	p.set(&"sol_rotacao", rumo)
	p.set(&"ambient_color", ambiente)
	p.set(&"ambient_energy", energia_ambiente)
	return p


func _usar(preset: Resource) -> void:
	_env.background_color = preset.get(&"sky_color")
	_env.ambient_light_color = preset.get(&"ambient_color")
	_env.ambient_light_energy = preset.get(&"ambient_energy")
	_nuvens.call(&"usar_preset", preset)
	# A contagem de particulas volta ao que o preset pede. A bancada quer uma.
	_nuvens.amount = 1


func _foto(nome: String) -> Image:
	for i in QUADROS:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img != null and _saida != "":
		img.save_png("%s/%s.png" % [_saida, nome])
	return img


## E nuvem este pixel? Tudo que desvia do ceu chapado.
static func _e_nuvem(c: Color, fundo: Color) -> bool:
	return absf(c.r - fundo.r) + absf(c.g - fundo.g) + absf(c.b - fundo.b) > LIMIAR * 3.0


## Luminancia media do terco de cima da nuvem sobre a do terco de baixo.
static func _topo_sobre_base(img: Image, fundo_srgb: Color) -> float:
	if img == null:
		return 0.0
	# O fundo sai na tela com a cor que foi pedida: o motor converte para linear
	# ao desenhar e de volta para sRGB ao mostrar, e o tonemap LINEAR nao mexe.
	var fundo := fundo_srgb
	var y0 := img.get_height()
	var y1 := -1
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 4):
			if _e_nuvem(img.get_pixel(x, y), fundo):
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
				break
	if y1 <= y0:
		return 0.0
	var terco := (y1 - y0) / 3
	var topo := _media_faixa(img, fundo, y0, y0 + terco)
	var base := _media_faixa(img, fundo, y1 - terco, y1)
	return topo / maxf(base, 0.0001)


static func _media_faixa(img: Image, fundo: Color, y0: int, y1: int) -> float:
	var soma := 0.0
	var n := 0
	for y in range(y0, y1 + 1, 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if _e_nuvem(c, fundo):
				soma += c.srgb_to_linear().get_luminance()
				n += 1
	return soma / maxf(float(n), 1.0)


## Luminancia media linear de uma janela no centro do quadro, onde a nuvem esta.
static func _media_da_janela(img: Image) -> float:
	if img == null:
		return 0.0
	var cx := img.get_width() / 2
	var cy := img.get_height() / 2
	var soma := 0.0
	var n := 0
	for y in range(cy - 90, cy + 90, 3):
		for x in range(cx - 90, cx + 90, 3):
			soma += img.get_pixel(x, y).srgb_to_linear().get_luminance()
			n += 1
	return soma / maxf(float(n), 1.0)
