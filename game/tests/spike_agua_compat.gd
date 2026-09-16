## Spikes da Fase 0 do PLANO_CHUVA_CABINE_AAA: o que o Compatibility aguenta.
##
##     godot --path game --script res://tests/spike_agua_compat.gd
##
## SEM --headless: shader so compila de verdade com janela.
##
## O mapa de agua da Fase 4 precisa de ESTADO que atravessa o quadro: a cobertura
## de gota sobe devagar, o limpador zera um setor, a trilha da corredora risca.
## Nada disso existe se o SubViewport limpar o quadro, e nada disso cresce se o
## passo por quadro cair abaixo do degrau de 1/255 do RGBA8. Estes spikes medem,
## um por um, as cinco perguntas que decidem a arquitetura:
##
##   A  SubViewport com CLEAR_MODE_NEVER guarda o quadro anterior?
##   B  `hint_screen_texture` dentro do SubViewport devolve esse quadro anterior?
##   C  passo menor que 1/255 some na quantizacao? E com arredondamento
##      estocastico, cresce?
##   D  `use_hdr_2d` vale no Compatibility (formato de leitura)?
##   E  ping-pong entre dois viewports funciona, como plano B do A+B?
##   F  MultiMesh com INSTANCE_CUSTOM chega no shader? (as corredoras)
##   G  `textureLod` na tela em shader `spatial` desfoca? (o embacado)
extends SceneTree

const LADO := 64
const QUADROS := 20

var _linhas: Array[String] = []


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	await _esperar(4)
	await _spike_persistencia()
	await _spike_pingpong()
	await _spike_multimesh()
	await _spike_desfoque()
	print("\n=== VEREDITO DOS SPIKES (Fase 0) ===")
	for l in _linhas:
		print("  " + l)
	quit(0)


# --- A, B, C, D -------------------------------------------------------------

## Um ColorRect que le o proprio quadro anterior e soma um passo. Se o viewport
## persistir e a leitura da tela valer, o valor cresce QUADROS * passo.
func _spike_persistencia() -> void:
	# 0,0005 por quadro e 0,13 do degrau de 1/255: e o passo REAL do mapa de agua
	# (cobertura de 0 a 1 em ~30 s a 60 fps). Quantizado ao vizinho mais proximo
	# ele vira zero; com arredondamento estocastico, a media acerta.
	for caso: Array in [
			["A/B passo 0,020 (5 degraus/quadro)", 0.02, 0, false],
			["C   passo 0,0005 (0,13 degrau)", 0.0005, 0, false],
			["C   passo 0,0005 + estocastico", 0.0005, 1, false],
			["D   passo 0,0005 + use_hdr_2d", 0.0005, 0, true],
		]:
		var vp := SubViewport.new()
		vp.size = Vector2i(LADO, LADO)
		vp.disable_3d = true
		vp.transparent_bg = false
		vp.use_hdr_2d = bool(caso[3])
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
		root.add_child(vp)

		# Copia o que ja esta no alvo ANTES do ColorRect desenhar: com
		# CLEAR_MODE_NEVER isso e o resultado do quadro passado.
		var bb := BackBufferCopy.new()
		bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		vp.add_child(bb)

		var rect := ColorRect.new()
		rect.size = Vector2(LADO, LADO)
		rect.material = _mat_soma(float(caso[1]), int(caso[2]))
		vp.add_child(rect)

		await _esperar(2)
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		# Contagem EXATA de quadros desenhados: com UPDATE_ALWAYS o viewport
		# continua desenhando durante qualquer espera e a conta perde o sentido.
		# A medida e o DELTA: o valor de partida carrega o aquecimento, e
		# comparar o absoluto com o esperado ja me fez dar tres vereditos
		# errados.
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var base_v := vp.get_texture().get_image().get_pixel(LADO / 2, LADO / 2).r
		var trilha: Array[String] = []
		var img: Image = null
		for i in QUADROS:
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			img = vp.get_texture().get_image()
			if i < 4 or i == QUADROS - 1:
				trilha.append("%d:%.4f" % [i + 1, img.get_pixel(LADO / 2, LADO / 2).r])
		print("    trilha %s -> %s" % [caso[0], ", ".join(trilha)])
		var v := img.get_pixel(LADO / 2, LADO / 2).r - base_v
		var esperado := float(caso[1]) * float(QUADROS)
		var veredito := "OK"
		if v <= 0.0005:
			veredito = "NAO CRESCEU (passo some na quantizacao)"
		elif absf(v - esperado) > esperado * 0.35:
			veredito = "%.2fx o esperado (vies de quantizacao)" % (v / maxf(esperado, 1e-6))
		_linhas.append("%-38s cresceu %.4f em %d quadros  esperado %.4f  formato %s  -> %s" % [
			caso[0], v, QUADROS, esperado, _formato(img.get_format()), veredito])
		vp.queue_free()
		await process_frame


func _mat_soma(passo: float, modo: int) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform sampler2D tela : hint_screen_texture, filter_nearest;
uniform float passo = 0.02;
uniform int modo = 0;
void fragment() {
	float ant = texture(tela, SCREEN_UV).r;
	float v = ant + passo;
	if (modo == 1) {
		// Arredondamento estocastico: com ruido de meio degrau antes de
		// quantizar, o valor MEDIO escrito e o certo mesmo com passo menor
		// que 1/255.
		float ruido = fract(sin(dot(FRAGCOORD.xy + vec2(TIME), vec2(12.9898, 78.233))) * 43758.5453);
		v += (ruido - 0.5) / 255.0;
	}
	COLOR = vec4(clamp(v, 0.0, 1.0), 0.0, 0.0, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter(&"passo", passo)
	m.set_shader_parameter(&"modo", modo)
	return m


# --- E ----------------------------------------------------------------------

## Plano B: dois viewports, cada um lendo a textura do outro.
func _spike_pingpong() -> void:
	var vps: Array[SubViewport] = []
	var rects: Array[ColorRect] = []
	for i in 2:
		var vp := SubViewport.new()
		vp.size = Vector2i(LADO, LADO)
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
		root.add_child(vp)
		var rect := ColorRect.new()
		rect.size = Vector2(LADO, LADO)
		var sh := Shader.new()
		sh.code = """
shader_type canvas_item;
uniform sampler2D anterior : filter_nearest;
uniform float passo = 0.02;
void fragment() {
	COLOR = vec4(clamp(texture(anterior, UV).r + passo, 0.0, 1.0), 0.0, 0.0, 1.0);
}
"""
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter(&"passo", 0.02)
		rect.material = m
		vp.add_child(rect)
		vps.append(vp)
		rects.append(rect)
	await _esperar(2)
	for i in 2:
		(rects[i].material as ShaderMaterial).set_shader_parameter(&"anterior",
			vps[1 - i].get_texture())
		vps[i].render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		vps[i].render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var base_v := vps[0].get_texture().get_image().get_pixel(LADO / 2, LADO / 2).r
	for i in QUADROS:
		for vp in vps:
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	var v := vps[0].get_texture().get_image().get_pixel(LADO / 2, LADO / 2).r - base_v
	# Cada viewport le o OUTRO, entao um passo de 0,02 por quadro em cada um da
	# 0,02 por quadro aqui tambem; a metade sai do atraso de um quadro.
	_linhas.append("%-38s cresceu %.4f em %d quadros  -> %s" % [
		"E   ping-pong entre dois viewports", v, QUADROS,
		"OK" if v > 0.05 else "FALHOU"])
	for vp in vps:
		vp.queue_free()
	await process_frame


# --- F ----------------------------------------------------------------------

## Quatro quadrinhos, cada um com uma cor em INSTANCE_CUSTOM. Se o custom chegar
## no shader, as quatro faixas saem com cores diferentes.
func _spike_multimesh() -> void:
	# 128x128 com ortho 4: 32 px por unidade, e as quatro instancias (x = -1,5 a
	# 1,5) caem em 16, 48, 80 e 112. Com o viewport 128x32 de antes, a largura
	# visivel virava 16 unidades e eu amostrava o fundo.
	var vp := SubViewport.new()
	vp.size = Vector2i(128, 128)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.0
	cam.position = Vector3(0.0, 0.0, 3.0)
	vp.add_child(cam)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8, 0.8)
	mm.mesh = quad
	mm.instance_count = 4
	var cores := [Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1), Color(1, 1, 0)]
	for i in 4:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(-1.5 + i, 0.0, 0.0)))
		mm.set_instance_custom_data(i, cores[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var sh := Shader.new()
	# INSTANCE_CUSTOM so existe em vertex(): lido no fragment da erro de
	# compilacao "Unknown identifier". Vai por varying.
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
varying vec3 custom;
void vertex() { custom = INSTANCE_CUSTOM.rgb; }
void fragment() { ALBEDO = custom; }
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	mmi.material_override = m
	vp.add_child(mmi)

	await _esperar(3)
	var img := vp.get_texture().get_image()
	var lidas: Array[Color] = []
	for i in 4:
		lidas.append(img.get_pixel(16 + i * 32, 64))
	var certo := true
	for i in 4:
		if lidas[i].r < cores[i].r - 0.2 or lidas[i].g < cores[i].g - 0.2 \
				or lidas[i].b < cores[i].b - 0.2:
			certo = false
	_linhas.append("%-38s leu %s -> %s" % ["F   MultiMesh INSTANCE_CUSTOM",
		", ".join(lidas.map(func(c: Color) -> String:
			return "%d%d%d" % [roundi(c.r), roundi(c.g), roundi(c.b)])),
		"OK" if certo else "FALHOU"])
	vp.queue_free()
	await process_frame


# --- G ----------------------------------------------------------------------

## Um xadrez de 8 px atras e, na frente, um quad que amostra a TELA com
## textureLod nivel 4. Se o mip da tela existir, o que sai e cinza liso; se nao
## existir, o xadrez continua la.
func _spike_desfoque() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(128, 128)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.0
	cam.position = Vector3(0.0, 0.0, 3.0)
	vp.add_child(cam)

	var img_x := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var claro := ((x / 8) + (y / 8)) % 2 == 0
			img_x.set_pixel(x, y, Color.WHITE if claro else Color.BLACK)
	var fundo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(4.0, 4.0)
	fundo.mesh = q
	var mat_fundo := StandardMaterial3D.new()
	mat_fundo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_fundo.albedo_texture = ImageTexture.create_from_image(img_x)
	mat_fundo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	fundo.material_override = mat_fundo
	fundo.position = Vector3(0.0, 0.0, -1.0)
	vp.add_child(fundo)

	var frente := MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(1.0, 1.0)
	frente.mesh = q2
	var sh := Shader.new()
	# `blend_mix` + ALPHA poe o quad na fila TRANSPARENTE. Opaco, ele desenha
	# antes de existir copia de tela e a amostra nao quer dizer nada.
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix, depth_draw_never;
uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;
uniform float nivel = 4.0;
void fragment() {
	ALBEDO = textureLod(tela, SCREEN_UV, nivel).rgb;
	ALPHA = 1.0;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	frente.material_override = m
	frente.position = Vector3(0.0, 0.0, 0.0)
	vp.add_child(frente)

	await _esperar(4)
	var img := vp.get_texture().get_image()
	# Desvio dentro do quadrinho da frente (centro da imagem).
	var soma := 0.0
	var soma2 := 0.0
	var n := 0
	for y in range(52, 76):
		for x in range(52, 76):
			var l := img.get_pixel(x, y).r
			soma += l
			soma2 += l * l
			n += 1
	var media := soma / float(n)
	var desvio := sqrt(maxf(0.0, soma2 / float(n) - media * media))
	_linhas.append("%-38s media %.2f desvio %.3f -> %s" % ["G   textureLod na tela (spatial)",
		media, desvio, "OK (desfocou)" if desvio < 0.15 else "SEM MIP (xadrez intacto)"])
	vp.queue_free()
	await process_frame


func _esperar(quadros: int) -> void:
	for i in quadros:
		await process_frame
	await RenderingServer.frame_post_draw


func _formato(f: int) -> String:
	match f:
		Image.FORMAT_RGBA8:
			return "RGBA8"
		Image.FORMAT_RGB8:
			return "RGB8"
		Image.FORMAT_RGBAH:
			return "RGBAH(16f)"
		Image.FORMAT_RGBAF:
			return "RGBAF(32f)"
		_:
			return "fmt%d" % f
