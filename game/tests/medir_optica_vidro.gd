## A optica do vidro, camada por camada, com numero.
##
##     godot --path game --script res://tests/medir_optica_vidro.gd -- --saida=DIR
##
## SEM --headless: e medida de pixel.
##
## Por que uma bancada, e nao a cutscene
## -------------------------------------
## Na estrada tudo acontece junto — a gota, o embacado, a sujeira, o ceu que
## muda, o carro que balanca — e "parece melhor" nao fecha fase. Aqui ha um vidro
## so, em pe, a um metro da lente, e atras dele tres faixas que respondem uma
## pergunta cada:
##
##   CLARA   cinza 0,87 (0,74 linear), acima do limiar: a gota ACENDE sobre ela?
##   ESCURA  cinza 0,25, abaixo do limiar: a gota nao inventa luz ali?
##   XADREZ  quadrados: o embacado DESFOCA? (contraste entre vizinhos)
##
## e mais tres sobre o proprio vidro:
##
##   LEQUE   dentro do leque das palhetas a sujeira e menor que fora?
##   VEU     no PS1 STYLE, vidro seco, sem embacado e sem sujeira: o pontilhado
##           e MULTIPLICADO, entao o vidro nao pode mudar um pixel do fundo.
##           Somado, ele pintava um veu no quadro inteiro (ver a memoria
##           "dither somado nao respeita o zero").
##   LEITURA no PS1 a 480x270 a gota ainda acende em pixels inteiros. Na
##           primeira rodada desta bancada ela era menor que um pixel e o vidro
##           molhado era so grao.
##
## E duas que so o MODERNO tem, porque o PS1 STYLE e um preset e nao o teto do
## jogo:
##
##   REALCE     sobre o fundo ESCURO, onde nenhuma luz de tras acende a gota, o
##              ponto especular do ceu ainda aparece.
##   DISPERSAO  sobre o xadrez cinza (r = g = b), a borda da gota separa as
##              cores. No PS1 a separacao tem de ser ZERO.
##
## MODERNO roda a 1280x720 e PS1 a 480x270, que sao as telas de verdade: a
## mesma gota metrica tem tamanhos diferentes em pixel nas duas, e medir as duas
## na mesma resolucao escondia exatamente o defeito da gota sub-pixel.
extends SceneTree

const MODERNO := Vector2i(1280, 720)
const PS1 := Vector2i(480, 270)
const FOV := 74.0
## Onde o vidro esta, e o tamanho dele: 2,4 x 1,2 m, a um metro.
const Z_VIDRO := -1.0
const VIDRO_TAM := Vector2(2.4, 1.2)

## Faixas, em fracao da tela, ja descontada a margem de refracao.
const FAIXA_CLARA := Rect2(0.085, 0.15, 0.215, 0.70)
const FAIXA_ESCURA := Rect2(0.375, 0.15, 0.25, 0.70)
const FAIXA_XADREZ := Rect2(0.70, 0.15, 0.225, 0.70)
const VIDRO := Rect2(0.085, 0.15, 0.83, 0.70)

## Cores do fundo em sRGB, que e como o `StandardMaterial3D` as le.
##
## A tela que o shader do vidro amostra e LINEAR: o cinza 0,80 da primeira
## rodada valia 0,60 linear, colado no limiar de brilho (0,55), e a gota "nao
## acendia" porque por desenho so luz forte acende. 0,87 sRGB sao 0,74 linear —
## um ceu encoberto claro, ou o cone do farol na nevoa.
const CINZA_CLARO := 0.87
const CINZA_ESCURO := 0.25
## Quanto acima do fundo seco um pixel tem de ficar para contar como aceso.
const ACESO := 0.04

## O leque de bancada: pivo embaixo no meio, varrendo da horizontal esquerda
## ate quase a vertical.
const LEQUE_PIVO := Vector2(1.2, 1.25)
const LEQUE_RAIOS := Vector2(0.05, 1.6)
const LEQUE_ANGULOS := Vector2(-1.55, -0.15)

var _saida := ""
var _falhas := 0
var _linhas: Array[String] = []


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			_saida = a.trim_prefix("--saida=")
	_rodar.call_deferred()


func _rodar() -> void:
	await _moderno()
	await _ps1()
	print("\n=== optica do vidro ===")
	for l in _linhas:
		print(l)
	if _linhas.is_empty():
		_falhas += 1
	print("\n=== %s ===" % ("OPTICA OK" if _falhas == 0 else "FALHOU: %d caso(s)" % _falhas))
	quit(0 if _falhas == 0 else 1)


func _moderno() -> void:
	RenderingServer.global_shader_parameter_set(&"psx_facho_suave", true)
	var cena := _cena(MODERNO)
	var vp: SubViewport = cena["vp"]
	var mat: ShaderMaterial = cena["mat"]

	# --- brilho ---
	_por(mat, 0.0, 0.0, 0.0)
	var seco := await _foto(vp, "moderno_seco")
	_por(mat, 1.0, 1.0, 0.0)
	var molhado := await _foto(vp, "moderno_molhado")
	var clara := _px(FAIXA_CLARA, MODERNO)
	var escura := _px(FAIXA_ESCURA, MODERNO)
	var d_clara := _delta_medio(seco, molhado, clara)
	var d_escura := _delta_medio(seco, molhado, escura)
	var fundo := _media_rect(seco, clara)
	var acesos := _acima(molhado, clara, fundo + ACESO)
	var acesos_secos := _acima(seco, clara, fundo + ACESO)
	_checar("brilho: a gota acende sobre o claro",
		acesos > 50 and acesos_secos == 0,
		"%d pixels acima do fundo molhado (seco: %d)" % [acesos, acesos_secos])
	_checar("brilho: acende mais no claro que no escuro", d_clara > d_escura,
		"luminancia media %+.4f no claro, %+.4f no escuro" % [d_clara, d_escura])
	var fundo_escuro := _media_rect(seco, escura)
	var realces := _acima(molhado, escura, fundo_escuro + 0.10)
	_checar("MODERNO: realce especular sobre o escuro", realces > 30,
		"%d pixels 0,10 acima do fundo escuro" % realces)
	var cores := _separadas(molhado, _px(FAIXA_XADREZ, MODERNO))
	var cores_secas := _separadas(seco, _px(FAIXA_XADREZ, MODERNO))
	_checar("MODERNO: dispersao na borda da gota", cores > 30 and cores_secas == 0,
		"%d pixels com vermelho e azul separados (seco: %d)" % [cores, cores_secas])

	# --- desfoque ---
	# Com o vidro embacado DE TODO toda a luz passa espalhada, e o contraste do
	# xadrez tem de ir embora. Com 0,6 passam 40% de luz direta, nitida — que e
	# o veu de verdade —, entao ali o numero e so informativo.
	var xadrez := _px(FAIXA_XADREZ, MODERNO)
	var c_seco := _contraste(seco, xadrez)
	_por(mat, 0.0, 0.0, 0.6)
	var meio := _contraste(await _foto(vp, "moderno_embacado_06"), xadrez)
	_por(mat, 0.0, 0.0, 1.0)
	var cheio := _contraste(await _foto(vp, "moderno_embacado_10"), xadrez)
	_checar("embacado cheio desfoca o xadrez", cheio <= c_seco * 0.4,
		"contraste entre vizinhos %.4f -> %.4f (%.0f%%); com 0,6: %.0f%%"
			% [c_seco, cheio, 100.0 * cheio / maxf(c_seco, 1e-6),
				100.0 * meio / maxf(c_seco, 1e-6)])

	# --- leque na sujeira ---
	_por(mat, 0.0, 0.0, 0.0)
	mat.set_shader_parameter(&"sujeira", 0.3)
	mat.set_shader_parameter(&"depurar", 5)
	mat.set_shader_parameter(&"tem_leque", true)
	mat.set_shader_parameter(&"leque_a", LEQUE_PIVO)
	mat.set_shader_parameter(&"leque_b", LEQUE_PIVO)
	mat.set_shader_parameter(&"leque_raios", LEQUE_RAIOS)
	mat.set_shader_parameter(&"leque_angulos", LEQUE_ANGULOS)
	var suja := await _foto(vp, "moderno_sujeira")
	var dentro := _media_em(suja, _dentro_do_leque(), MODERNO)
	var fora := _media_em(suja, _fora_do_leque(), MODERNO)
	_checar("leque limpa a sujeira", dentro < fora * 0.4,
		"sujeira media %.3f no leque, %.3f fora (%.0f%%)"
			% [dentro, fora, 100.0 * dentro / maxf(fora, 1e-6)])
	vp.queue_free()
	await process_frame


func _ps1() -> void:
	RenderingServer.global_shader_parameter_set(&"psx_facho_suave", false)
	var cena := _cena(PS1)
	var vp: SubViewport = cena["vp"]
	var mat: ShaderMaterial = cena["mat"]
	var vidro: MeshInstance3D = cena["vidro"]
	var area := _px(VIDRO, PS1)

	_por(mat, 0.0, 0.0, 0.0)
	var com := await _foto(vp, "ps1_seco")
	vidro.visible = false
	var sem := await _foto(vp, "ps1_sem_vidro")
	vidro.visible = true
	var veu := _diferenca_max(com, sem, area)
	_checar("PS1: vidro seco nao pinta veu", veu < 1.5 / 255.0,
		"maior diferenca para o fundo: %.4f (%.1f niveis)" % [veu, veu * 255.0])

	_por(mat, 1.0, 1.0, 0.0)
	var molhado := await _foto(vp, "ps1_molhado")
	var clara := _px(FAIXA_CLARA, PS1)
	var acesos := _acima(molhado, clara, _media_rect(com, clara) + ACESO)
	_checar("PS1: a gota acende em pixel inteiro", acesos > 20,
		"%d pixels acima do fundo na faixa clara" % acesos)
	var cores := _separadas(molhado, _px(FAIXA_XADREZ, PS1))
	_checar("PS1: sem dispersao", cores == 0,
		"%d pixels com vermelho e azul separados" % cores)
	RenderingServer.global_shader_parameter_set(&"psx_facho_suave", true)
	vp.queue_free()
	await process_frame


## A bancada: fundo de tres faixas, lente, vidro.
func _cena(tam: Vector2i) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = tam
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	amb.environment = env
	vp.add_child(amb)

	var cam := Camera3D.new()
	cam.fov = FOV
	vp.add_child(cam)
	cam.make_current()

	_fundo(vp, -4.0, -1.4, _chapado(Color(CINZA_CLARO, CINZA_CLARO, CINZA_CLARO)))
	_fundo(vp, -1.2, 1.2, _chapado(Color(CINZA_ESCURO, CINZA_ESCURO, CINZA_ESCURO)))
	_fundo(vp, 1.4, 4.0, _xadrez())

	var vidro := _vidro()
	vp.add_child(vidro)
	var mat := vidro.material_override as ShaderMaterial
	mat.set_shader_parameter(&"usa_mapa", false)
	mat.set_shader_parameter(&"vidro_seco", 0.0)
	mat.set_shader_parameter(&"sujeira", 0.0)
	mat.set_shader_parameter(&"embacado", 0.0)
	return {"vp": vp, "mat": mat, "vidro": vidro}


func _por(mat: ShaderMaterial, cobertura: float, intensidade: float,
		embacado: float) -> void:
	mat.set_shader_parameter(&"cobertura", cobertura)
	mat.set_shader_parameter(&"intensidade", intensidade)
	mat.set_shader_parameter(&"embacado", embacado)


## Um vidro de para-brisa em pe, a um metro da lente. Montado pelo MESMO caminho
## da cabine: `VidroCabine.referenciais` e `montar`.
func _vidro() -> MeshInstance3D:
	var h := VIDRO_TAM * 0.5
	var pontos := PackedVector3Array([
		Vector3(-h.x, h.y, Z_VIDRO), Vector3(h.x, h.y, Z_VIDRO),
		Vector3(h.x, -h.y, Z_VIDRO), Vector3(-h.x, -h.y, Z_VIDRO)])
	var abertura := {
		"tipo": &"parabrisa", "lado": 0, "pontos": pontos,
		# Para FORA da cabine, que aqui e o lado de la da lente.
		"normal": Vector3(0.0, 0.0, -1.0), "centro": Vector3(0.0, 0.0, Z_VIDRO),
	}
	var paineis := VidroCabine.referenciais([abertura])
	var mi := MeshInstance3D.new()
	mi.mesh = VidroCabine.montar(paineis)
	mi.material_override = VidroCabine.material()
	return mi


## Um ponto do vidro, em metros (u atravessa, v desce), na tela.
func _px_do_vidro(m: Vector2, tam: Vector2i) -> Vector2i:
	var tv := tan(deg_to_rad(FOV) * 0.5)
	var meia_l := tv * float(tam.x) / float(tam.y) * absf(Z_VIDRO)
	var meia_a := tv * absf(Z_VIDRO)
	var x := m.x - VIDRO_TAM.x * 0.5
	var y := VIDRO_TAM.y * 0.5 - m.y
	return Vector2i(int((x / meia_l * 0.5 + 0.5) * tam.x),
		int((0.5 - y / meia_a * 0.5) * tam.y))


func _dentro_do_leque() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in 12:
		for j in 12:
			var ang := lerpf(-1.2, -0.5, i / 11.0)
			var r := lerpf(0.35, 1.2, j / 11.0)
			var m := LEQUE_PIVO + Vector2(sin(ang), -cos(ang)) * r
			if m.x > 0.05 and m.y > 0.05:
				out.append(m)
	return out


func _fora_do_leque() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in 12:
		for j in 12:
			# A direita do pivo o angulo e positivo: fora do leque.
			out.append(Vector2(lerpf(1.6, 2.25, i / 11.0), lerpf(0.15, 1.05, j / 11.0)))
	return out


## Media LINEAR nos pontos. O canal de depuracao e escrito linear e a imagem do
## viewport sai em sRGB: medida em sRGB, a razao 0,15 aparecia como 0,41.
func _media_em(img: Image, pontos: Array[Vector2], tam: Vector2i) -> float:
	var soma := 0.0
	for m: Vector2 in pontos:
		var p := _px_do_vidro(m, tam)
		soma += _lum(img.get_pixel(p.x, p.y).srgb_to_linear())
	return soma / float(maxi(pontos.size(), 1))


func _media_rect(img: Image, r: Rect2i) -> float:
	var soma := 0.0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			soma += _lum(img.get_pixel(x, y))
	return soma / float(r.get_area())


## Uma faixa do fundo, a tres metros, entre dois X.
func _fundo(vp: SubViewport, x0: float, x1: float, mat: Material) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(x1 - x0, 6.0)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.position = Vector3((x0 + x1) * 0.5, 0.0, -3.0)
	vp.add_child(mi)


func _chapado(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


## Xadrez de quadrados de ~4 px da grade de 480x270 na distancia do fundo.
func _xadrez() -> StandardMaterial3D:
	var img := Image.create(44, 132, false, Image.FORMAT_RGB8)
	for y in 132:
		for x in 44:
			var claro := (x + y) % 2 == 0
			img.set_pixel(x, y, Color.WHITE if claro else Color(0.1, 0.1, 0.1))
	var m := _chapado(Color.WHITE)
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m


func _foto(vp: SubViewport, nome: String) -> Image:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if _saida != "":
		img.save_png(_saida.path_join("optica_%s.png" % nome))
	return img


func _px(r: Rect2, tam: Vector2i) -> Rect2i:
	return Rect2i(int(r.position.x * tam.x), int(r.position.y * tam.y),
		int(r.size.x * tam.x), int(r.size.y * tam.y))


func _lum(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114


func _delta_medio(a: Image, b: Image, r: Rect2i) -> float:
	var soma := 0.0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			soma += _lum(b.get_pixel(x, y)) - _lum(a.get_pixel(x, y))
	return soma / float(r.get_area())


func _acima(img: Image, r: Rect2i, limiar: float) -> int:
	var n := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if _lum(img.get_pixel(x, y)) > limiar:
				n += 1
	return n


## Diferenca media entre vizinhos na horizontal: o que o desfoque apaga.
func _contraste(img: Image, r: Rect2i) -> float:
	var soma := 0.0
	var n := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x - 1):
			soma += absf(_lum(img.get_pixel(x, y)) - _lum(img.get_pixel(x + 1, y)))
			n += 1
	return soma / float(maxi(n, 1))


func _diferenca_max(a: Image, b: Image, r: Rect2i) -> float:
	var pior := 0.0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			pior = maxf(pior, maxf(absf(p.r - q.r), maxf(absf(p.g - q.g),
				absf(p.b - q.b))))
	return pior


## Pixels em que vermelho e azul se separam: o fundo e cinza, entao so a
## dispersao da gota faz isso.
func _separadas(img: Image, r: Rect2i) -> int:
	var n := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := img.get_pixel(x, y)
			if absf(c.r - c.b) > 0.04:
				n += 1
	return n


func _checar(nome: String, passou: bool, detalhe: String) -> void:
	if not passou:
		_falhas += 1
	_linhas.append("  %-42s %s   %s" % [nome, "OK    " if passou else "FALHOU", detalhe])
