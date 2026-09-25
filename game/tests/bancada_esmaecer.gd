## Como o Godot esmaece uma malha no fim e no comeco da faixa de visibilidade.
##
##     godot --path game res://tests/bancada_esmaecer.tscn
##     ... -- --psx      as placas com o material do chunk (psx_surface), e nao o padrao
##
## Por que existe
## -------------
## A troca de nivel de detalhe do chunk (balde @perto some a ALCANCE_PERTO, o
## @longe aparece no mesmo ponto) precisa de uma transicao sem estalo. O
## `visibility_range_fade_mode` faz isso, mas a documentacao nao diz se o
## esmaecimento pontilha ou mistura por transparencia, nem se o fim de uma malha
## e o comeco da outra no mesmo numero se completam ou deixam um vao no meio.
##
## Aqui duas placas no mesmo lugar, a de perto branca e a de longe vermelha, com
## o material do jogo (psx_surface) e fundo preto. A camera recua de 1 em 1 m
## atravessando a troca, e para cada distancia sai a cobertura (quanto da placa
## esta desenhado) e a fracao de pixels "puros" (so branco, so vermelho ou so
## fundo): pontilhado da puro perto de 1, mistura da puro perto de 0.
extends Node3D

const TROCA := 20.0
const MARGEM := 4.0

var _cam: Camera3D
var _perto: MeshInstance3D
var _longe: MeshInstance3D


func _ready() -> void:
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	amb.environment = env
	add_child(amb)
	_cam = Camera3D.new()
	_cam.fov = 20.0
	add_child(_cam)
	_perto = _placa(Color.WHITE)
	_longe = _placa(Color.RED)
	_perto.visibility_range_end = TROCA
	_perto.visibility_range_end_margin = MARGEM
	_perto.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_longe.visibility_range_begin = TROCA
	_longe.visibility_range_begin_margin = MARGEM
	_longe.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	await get_tree().process_frame
	for d in range(int(TROCA - MARGEM * 2.0), int(TROCA + MARGEM * 2.0) + 1):
		_cam.position = Vector3(0.0, 0.0, float(d))
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_medir(float(d), get_viewport().get_texture().get_image())
	get_tree().quit(0)


func _placa(cor: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	mi.mesh = q
	if OS.get_cmdline_user_args().has("--psx"):
		# O material de verdade do chunk. A cor sai da textura, entao a leitura e
		# so a cobertura contra o fundo preto.
		mi.material_override = ChunkManager._material(&"reboco")
	else:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = cor
		mi.material_override = m
	add_child(mi)
	return mi


func _medir(d: float, img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var branco := 0
	var vermelho := 0
	var puros := 0
	var n := 0
	var soma := 0.0
	for y in range(h / 2 - 20, h / 2 + 20):
		for x in range(w / 2 - 20, w / 2 + 20):
			var c := img.get_pixel(x, y)
			n += 1
			soma += maxf(c.r, maxf(c.g, c.b))
			var e_branco := c.g > 0.9
			var e_vermelho := c.r > 0.9 and c.g < 0.1
			var e_fundo := c.r < 0.1
			if e_branco:
				branco += 1
			if e_vermelho:
				vermelho += 1
			if e_branco or e_vermelho or e_fundo:
				puros += 1
	print("[esmaecer] d=%.0f branco=%.2f vermelho=%.2f cobertura=%.2f puros=%.2f" % [d,
		float(branco) / n, float(vermelho) / n, soma / n, float(puros) / n])
