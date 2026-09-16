## O relevo do conjunto HD sob luz rasante: o criterio A9 do PLANO_AAA_4K.
##
##     godot --path game --script res://tests/bancada_relevo.gd
##     (SEM --headless: shader so compila com janela)
##
## O que se pergunta
## -----------------
## "Superficie tem relevo que responde a luz" nao se prova na rua. Na cidade a
## luz do dia vem de cima, e de cima um mapa de normal quase nao aparece: medido,
## a mesma parede com e sem relevo deu desvio de luminancia 18,51 contra 18,53.
## Relevo se ve na luz RASANTE — a que corre paralela a parede e transforma cada
## cova em sombra.
##
## Entao a bancada monta o que a rua nao oferece: um painel de 4 m com a textura,
## uma luz a 8 graus do plano dele, e mais nada. A medida e o desvio padrao da
## luminancia no painel, com o mapa de normal e sem ele. A razao entre os dois e
## o numero do A9.
##
## Por que desvio e nao diferenca media
## ------------------------------------
## Relevo nao clareia nem escurece a parede: ele TROCA claro por escuro dentro
## dela. A media fica quase igual (foi o que a rua mostrou); o que muda e o
## espalhamento. Por isso o criterio e sobre variancia.
extends SceneTree

## Superficies medidas. Todas do conjunto HD.
const ALVOS: Array[StringName] = [&"metal_ondulado", &"tijolo", &"calcada", &"asfalto"]
## Graus acima do plano do painel. Oito e rasante de verdade: o sol de fim de
## tarde numa parede, ou o facho de um farol no asfalto.
const RASANTE := 8.0
## De que lado, dentro do plano do painel, a luz chega.
##
## Tres azimutes porque o relevo tem DIRECAO. O mapa do metal ondulado varia
## quase so no eixo Y da tangente (desvio 52,6 no canal verde contra 1,3 no
## vermelho): luz rasante vinda pelo X atravessa a nervura sem produzir sombra
## nenhuma, e a primeira versao desta bancada mediu 1,03x por causa disso. O que
## vale e a melhor das direcoes — na rua o sol e o farol vem de todas.
const AZIMUTES: Array[float] = [0.0, 45.0, 90.0]
## Quantos quadros esperar antes de fotografar. O primeiro nao vale nunca.
const QUADROS := 12
## Lado do painel, em metros, e quantas vezes a textura se repete nele.
##
## Duas repeticoes em 4 m da 2 m por repeticao, que e a densidade MEDIDA na rua:
## `tests/medir_texel.gd` da 512 px/m para o asfalto, e 1024 px / 512 px/m = 2 m.
## A primeira versao usava oito repeticoes — quatro vezes mais comprimido que o
## jogo —, e nessa escala o relevo de tijolo e de calcada vira detalhe de um
## pixel, que a luz nao tem como sombrear.
const LADO := 4.0
const REPETE := 2.0

var _raiz: Node3D
var _painel: MeshInstance3D
var _mat: ShaderMaterial
## `--saida=DIR` grava as fotos da bancada; `--depurar` pinta a normal.
var _saida := ""
var _luz: DirectionalLight3D
## `--forca=N`: a forca do relevo medida. Serve para calibrar material por
## material, que e o que a Fase 3 faz com `TexturasHD.RELEVO`.
var _forca := 1.0


## Poe a luz a RASANTE graus do plano, chegando pelo azimute pedido.
func _apontar(azimute: float) -> void:
	var a := deg_to_rad(azimute)
	var e := deg_to_rad(RASANTE)
	# Do painel para a luz. O painel olha para +Z, entao o plano dele e o XY.
	var para_luz := Vector3(cos(a) * cos(e), sin(a) * cos(e), sin(e))
	_luz.basis = Basis.looking_at(-para_luz, Vector3.FORWARD)


func _flag(nome: String) -> bool:
	return OS.get_cmdline_user_args().has(nome)


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
		elif arg.begins_with("--forca="):
			_forca = maxf(arg.trim_prefix("--forca=").to_float(), 0.0)
	root.add_child.call_deferred(_montar())
	_medir()


func _montar() -> Node3D:
	_raiz = Node3D.new()

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.0, 3.4)
	camera.fov = 60.0
	_raiz.add_child(camera)

	# Ambiente PROPRIO, e preto.
	#
	# Sem isto a bancada herda o ambiente padrao do projeto, e a luz ambiente
	# lava o painel: medido, o mesmo painel com e sem relevo dava desvio 7,07
	# contra 6,90 — a direcional respondia por quase nada do que se via. Relevo
	# so se mede onde a unica luz e a que eu coloquei.
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.ambient_light_energy = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	ambiente.environment = env
	_raiz.add_child(ambiente)

	# Luz rasante, vindo da esquerda e quase paralela ao painel.
	_luz = DirectionalLight3D.new()
	_luz.light_energy = 3.0
	_raiz.add_child(_luz)
	_apontar(0.0)

	var plano := PlaneMesh.new()
	plano.size = Vector2(LADO, LADO)
	plano.orientation = PlaneMesh.FACE_Z
	_painel = MeshInstance3D.new()
	_painel.mesh = plano
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/psx_surface_pixel.gdshader")
	_mat.set_shader_parameter(&"tint", Color.WHITE)
	_mat.set_shader_parameter(&"uv_tile", Vector2(REPETE, REPETE))
	_mat.set_shader_parameter(&"use_snap", false)
	_mat.set_shader_parameter(&"use_affine", false)
	_mat.set_shader_parameter(&"rugosidade", 0.88)
	_mat.set_shader_parameter(&"depurar_relevo", _flag("--depurar"))
	_painel.material_override = _mat
	_raiz.add_child(_painel)
	return _raiz


func _medir() -> void:
	await process_frame
	await process_frame
	print("[relevo] luz a %.0f graus do plano, forca %.1f; painel de %.0f m com %.0f repeticoes"
		% [RASANTE, _forca, LADO, REPETE])
	var passou := 0
	var medidos := 0
	for nome: StringName in ALVOS:
		if not TexturasHD.tem(nome):
			print("[relevo] %s: sem conjunto HD, pulado" % nome)
			continue
		var razao := 0.0
		var com := 0.0
		var sem := 0.0
		for azimute: float in AZIMUTES:
			_apontar(azimute)
			var c := await _desvio(nome, _forca)
			var s := await _desvio(nome, 0.0)
			var r := c / maxf(s, 0.001)
			if r > razao:
				razao = r
				com = c
				sem = s
		medidos += 1
		if razao >= 1.5:
			passou += 1
		print("[relevo] %-16s desvio com relevo %6.2f  sem %6.2f  razao %.2fx"
			% [nome, com, sem, razao])
	print("[relevo] %d de %d superficies com relevo visivel (razao >= 1,5x)"
		% [passou, medidos])
	quit(0 if medidos > 0 and passou == medidos else 1)


func _desvio(nome: StringName, relevo: float) -> float:
	TexturasHD.aplicar(_mat, nome, true)
	_mat.set_shader_parameter(&"relevo", relevo)
	for i in QUADROS:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null:
		return 0.0
	if _saida != "":
		img.save_png("%s/%s_relevo%.0f.png" % [_saida, nome, relevo * 10.0])
	# So o miolo do painel: a borda tem o fundo e o degrade da luz.
	var x0 := int(img.get_width() * 0.32)
	var x1 := int(img.get_width() * 0.68)
	var y0 := int(img.get_height() * 0.32)
	var y1 := int(img.get_height() * 0.68)
	var soma := 0.0
	var n := 0
	var vals: PackedFloat32Array = []
	for y in range(y0, y1, 2):
		for x in range(x0, x1, 2):
			var c := img.get_pixel(x, y)
			var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			vals.append(l)
			soma += l
			n += 1
	if n == 0:
		return 0.0
	var media := soma / float(n)
	var acc := 0.0
	for v: float in vals:
		acc += (v - media) * (v - media)
	return sqrt(acc / float(n)) * 255.0
