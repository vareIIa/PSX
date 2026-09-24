## O iPhone do jogo na mao do jogador, fotografado etapa por etapa: tirar do
## bolso, a trava, o inicio, a loja (sem saldo, instalando, instalado), o modo de
## editar, cada app, o braco visto de fora, e guardar. Mede tambem o raio do
## mouse: o centro da tela projetado tem de voltar como uv (0,5; 0,5).
##
##     godot --path game --resolution 1920x1080 res://tests/bancada_celular_jogo.tscn -- --teste-celular --saida=<DIR ABSOLUTO> [--so=<etapa>]
extends Node

const THUMB := Vector2i(480, 270)

var SP := ""
var _so := ""
var jogador: Node3D
var _quadros: Array[Image] = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			SP = a.trim_prefix("--saida=").path_join("")
		elif a.begins_with("--so="):
			_so = a.trim_prefix("--so=")
	_rodar()


func _caixa(pai: Node3D, tam: Vector3, centro: Vector3, cor: Color) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.8
	mi.material_override = mat
	pai.add_child(mi)
	mi.position = centro
	var corpo := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = tam
	col.shape = forma
	corpo.add_child(col)
	mi.add_child(corpo)


func _passar(segundos: float) -> void:
	var fim := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < fim:
		await get_tree().process_frame


func _foto(nome: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SP + nome + ".png")
	print("[foto] ", nome)


func _guardar_quadro() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_BILINEAR)
	_quadros.append(img)


func _mosaico(nome: String, colunas: int = 4) -> void:
	if _quadros.is_empty():
		return
	var linhas := ceili(float(_quadros.size()) / float(colunas))
	var out := Image.create(THUMB.x * colunas, THUMB.y * linhas, false, _quadros[0].get_format())
	for i in _quadros.size():
		out.blit_rect(_quadros[i], Rect2i(Vector2i.ZERO, THUMB),
			Vector2i((i % colunas) * THUMB.x, (i / colunas) * THUMB.y))
	out.save_png(SP + nome + ".png")
	_quadros.clear()
	print("[mosaico] ", nome)


func _montar_mundo() -> void:
	var mundo := Node3D.new()
	mundo.name = "Mundo"
	add_child(mundo)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0d1118")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3a4a66")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	amb.environment = env
	mundo.add_child(amb)
	_caixa(mundo, Vector3(20.0, 0.2, 20.0), Vector3(0.0, -0.1, 0.0), Color("3a3833"))
	_caixa(mundo, Vector3(6.0, 3.0, 0.3), Vector3(0.0, 1.5, -3.5), Color("6b5a4a"))
	_caixa(mundo, Vector3(0.8, 1.0, 0.8), Vector3(1.4, 0.5, -2.2), Color("2f4a6b"))
	var lua := DirectionalLight3D.new()
	lua.light_color = Color(0.7, 0.78, 0.95)
	lua.light_energy = 0.35
	lua.shadow_enabled = true
	mundo.add_child(lua)
	lua.rotation = Vector3(-0.8, 0.6, 0.0)
	var poste := OmniLight3D.new()
	poste.light_color = Color(1.0, 0.78, 0.5)
	poste.light_energy = 2.0
	poste.omni_range = 7.0
	mundo.add_child(poste)
	poste.position = Vector3(-1.8, 2.8, -1.5)


## As metas da pegada do jogo, no espaco do aparelho: cada polpa onde encosta e
## para onde a unha olha. As pontas do indicador, do medio e do anelar NA
## lateral esquerda (e nao dobradas sobre o vidro), o minimo de prateleira
## embaixo, a falange de cada um deitada nas costas, a tenar na quina direita e
## o polegar pairando sobre o canto de baixo a direita da tela, fora do que se
## le.
## Onde a polpa do polegar encosta na lateral direita (m); `--polegar=y,z` troca.
static var polegar_y := 0.010
static var polegar_z := -0.0005
## Altura das polpas do indicador, do medio e do anelar na lateral esquerda (m);
## `--dedos=a,b,c` troca.
static var dedos_y: Array[float] = [0.028, 0.004, -0.019]


static func metas_do_jogo() -> Array:
	var m := IphoneDeJogo.TAMANHO * 0.5
	var lado := Vector3(-1.0, 0.0, 0.0)
	# A polpa na face LATERAL, no meio da espessura, 1 mm para fora (encostando
	# ela afundava 1,8 mm), e a ponta saindo alem da borda — de frente, ao lado
	# da tela e nao em cima dela. Duas tentativas que nao servem: a polpa na
	# aresta de tras nao cabe (o dedo sobra 4 cm para a largura do aparelho e
	# dobra pela frente), e deixando a polpa deslizar pela face (`face`) ela
	# corria em z e enganchava 18 mm na frente do vidro.
	var z := -0.0008
	return [
		{"tipo": &"polpa", "dedo": 0, "p": Vector3(-m.x - 0.001, dedos_y[0], z), "n": lado, "peso_n": 0.6},
		{"tipo": &"polpa", "dedo": 1, "p": Vector3(-m.x - 0.001, dedos_y[1], z), "n": lado, "peso_n": 0.6},
		{"tipo": &"polpa", "dedo": 2, "p": Vector3(-m.x - 0.001, dedos_y[2], z), "n": lado, "peso_n": 0.6},
		{"tipo": &"polpa", "dedo": 3, "p": Vector3(-0.013, -m.y, -0.0015),
			"n": Vector3(-0.2, -1.0, 0.0), "peso": 0.7, "peso_n": 0.3,
			"face": Vector3(0.0, -1.0, 0.0), "t_peso": 0.3},
		{"tipo": &"encosta", "dedo": 0, "falange": 0, "t": 0.8, "peso": 0.8},
		{"tipo": &"encosta", "dedo": 1, "falange": 0, "t": 0.7, "peso": 1.0},
		{"tipo": &"encosta", "dedo": 2, "falange": 0, "t": 0.7, "peso": 1.0},
		{"tipo": &"encosta", "dedo": 4, "falange": 0, "t": 0.55, "peso": 0.8},
		# O polegar deitado ao longo da LATERAL direita, apontando para cima (o
		# risco do jogador na foto): a polpa na face do aluminio, um milimetro para
		# fora, e nada dele na frente do vidro. Na moldura de baixo ele cruzava o
		# aparelho de lado e lia como dedo atravessado.
		{"tipo": &"polpa", "dedo": 4, "p": Vector3(m.x + 0.001, polegar_y, polegar_z),
			"n": Vector3(1.0, 0.0, 0.0), "peso": 0.8, "peso_n": 0.6},
		{"tipo": &"encosta", "dedo": 4, "falange": 1, "t": 0.5, "peso": 0.5},
		# Os nos atras da borda direita, os dedos para a esquerda pelas costas e o
		# punho saindo para a direita e para baixo, para o ombro.
		{"tipo": &"rumo", "d": Vector3(-0.85, 0.45, -0.1), "peso": 0.2},
	]


## As metas da mao DIREITA com o aparelho deitado (o Mapas), no referencial
## deitado (x para a direita de quem olha, y para cima, z saindo do vidro): a
## caixa e a do aparelho com largura e altura trocadas. A ponta direita e a do
## botao de inicio. O polegar na moldura dela, abaixo do botao; o indicador na
## borda de cima; o medio e o anelar nas costas; o minimo por baixo, de apoio.
## A esquerda e o espelho desta (`CelularNaMao._espelho`).
static func metas_deitado() -> Array:
	var m := Vector3(IphoneDeJogo.TAMANHO.y, IphoneDeJogo.TAMANHO.x, IphoneDeJogo.TAMANHO.z) * 0.5
	return [
		{"tipo": &"polpa", "dedo": 0, "p": Vector3(0.034, m.y + 0.001, -0.0008), "n": Vector3(0, 1, 0),
			"peso_n": 0.5},
		{"tipo": &"polpa", "dedo": 1, "p": Vector3(0.028, 0.010, -m.z - 0.001), "n": Vector3(0, 0, -1),
			"peso_n": 0.5},
		{"tipo": &"polpa", "dedo": 2, "p": Vector3(0.034, -0.009, -m.z - 0.001), "n": Vector3(0, 0, -1),
			"peso_n": 0.5},
		{"tipo": &"polpa", "dedo": 3, "p": Vector3(0.046, -m.y - 0.001, -0.0015), "n": Vector3(0, -1, 0),
			"peso": 0.6, "peso_n": 0.3},
		{"tipo": &"polpa", "dedo": 4, "p": Vector3(0.050, -0.014, m.z + 0.0015), "n": Vector3(0, 0, 1),
			"peso": 0.9, "peso_n": 0.5},
		{"tipo": &"encosta", "dedo": 4, "falange": 0, "t": 0.55, "peso": 0.6},
		{"tipo": &"encosta", "dedo": 1, "falange": 0, "t": 0.6, "peso": 0.6},
		{"tipo": &"rumo", "d": Vector3(-0.35, 0.9, -0.2), "peso": 0.2},
	]


func _resolver_deitado() -> void:
	var m := Vector3(IphoneDeJogo.TAMANHO.y, IphoneDeJogo.TAMANHO.x, IphoneDeJogo.TAMANHO.z) * 0.5
	var aj := AjusteDaMao.new(m, IphoneDeJogo.RAIO_CANTO, true)
	aj.metas = metas_deitado()
	var chutes := [
		{"o": Vector3(0.040, -0.010, -0.022), "d": Vector3(-0.3, 0.95, 0.0), "dorso": Vector3(0.0, 0.1, -1.0),
			"pose": {"dedos": [[20, 45, 30, 0], [25, 50, 35, 0], [25, 50, 35, 0], [35, 55, 40, 0]],
				"polegar": [40, 50, -60, 30, 18]}},
		{"o": Vector3(0.048, -0.018, -0.020), "d": Vector3(-0.5, 0.85, -0.1), "dorso": Vector3(0.1, 0.1, -1.0),
			"pose": {"dedos": [[15, 40, 30, 0], [25, 55, 40, 0], [30, 55, 40, 0], [40, 60, 40, 0]],
				"polegar": [40, 62, -90, 55, 18]}},
		{"o": Vector3(0.035, -0.005, -0.025), "d": Vector3(-0.1, 0.99, 0.0), "dorso": Vector3(0.2, 0.0, -1.0),
			"pose": {"dedos": [[25, 50, 35, 0], [30, 55, 40, 0], [30, 55, 40, 0], [40, 60, 40, 0]],
				"polegar": [30, 44, 62, 18, 16]}},
		{"o": Vector3(0.052, -0.025, -0.018), "d": Vector3(-0.6, 0.75, -0.2), "dorso": Vector3(0.0, 0.2, -1.0),
			"pose": {"dedos": [[10, 35, 25, 0], [20, 45, 30, 0], [25, 50, 35, 0], [35, 55, 38, 0]],
				"polegar": [0, 68, -90, 10, 8]}},
		{"o": Vector3(0.045, -0.012, -0.024), "d": Vector3(-0.25, 0.9, -0.3), "dorso": Vector3(0.1, 0.3, -0.9),
			"pose": {"dedos": [[20, 40, 30, 0], [25, 50, 35, 0], [30, 55, 40, 0], [40, 60, 40, 0]],
				"polegar": [50, 36, 44, 16, 26]}},
	]
	# Mais pontos de partida, sorteados em volta da pegada que a mao faz: a palma
	# atras da ponta direita, os dedos subindo pelas costas, o polegar dando a
	# volta na ponta ate a moldura da frente.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var poses := [chutes[0]["pose"], chutes[1]["pose"], chutes[2]["pose"], chutes[4]["pose"],
		{"dedos": [[5, 20, 15, 0], [10, 25, 18, 0], [10, 25, 18, 0], [15, 30, 20, 0]],
			"polegar": [30, 60, -80, 30, 20]}]
	for k in 26:
		chutes.append({"o": Vector3(rng.randf_range(0.030, 0.062), rng.randf_range(-0.030, 0.010),
				rng.randf_range(-0.032, -0.014)),
			"d": Vector3(rng.randf_range(-0.7, 0.2), rng.randf_range(0.5, 1.0), rng.randf_range(-0.5, 0.1)),
			"dorso": Vector3(rng.randf_range(-0.1, 0.5), rng.randf_range(-0.3, 0.3), -1.0),
			"pose": poses[k % poses.size()]})
	var melhor := {}
	var custo_melhor := INF
	for i in chutes.size():
		var p := aj.resolver(chutes[i], 220)
		var med := aj.medir(p)
		var e0 := MaoDoCelular.esqueleto(p["o"], p["d"], p["dorso"], p["pose"], true)
		# Nada sobre a tela deitada (74 x 49 mm): nenhuma ponta de dedo na frente
		# do vidro dentro dela, e o polegar so na moldura.
		var sobre := 0.0
		for dedo in 5:
			var c: Vector3 = MaoDoCelular.polpa(e0, dedo)["centro"]
			var r := float(MaoDoCelular.raios_do_dedo(dedo)[3])
			if c.z + r > m.z:
				sobre = maxf(sobre, IphoneDeJogo.TELA.y * 0.5 - (c.x - r))
		var c4: Vector3 = MaoDoCelular.polpa(e0, 4)["centro"]
		print("[deitado] chute %d: custo=%.1f dentro=%d pior=%.2f mm sobre a tela %.1f mm polegar (%.1f, %.1f, %.1f) metas=%s" % [
			i, med["custo"], med["dentro"], med["pior_mm"], sobre * 1000.0, c4.x * 1000.0, c4.y * 1000.0,
			c4.z * 1000.0, med["metas_mm"]])
		# O polegar tem de estar DE FRENTE, na moldura: nem na testa do aparelho,
		# nem atras dele.
		var custo := float(med["custo"]) + float(med["dentro"]) * 60.0 - float(med["pior_mm"]) * 400.0 \
			+ maxf(0.0, sobre * 1000.0 - 1.5) * 150.0 \
			+ (0.0 if c4.z > m.z else 1500.0) + maxf(0.0, (c4.x - (m.x - 0.006)) * 1000.0) * 200.0
		print("[deitado]   nota %.1f" % custo)
		if custo < custo_melhor:
			custo_melhor = custo
			melhor = p
	print("[deitado] DEITADA_O := Vector3(%.4f, %.4f, %.4f)" % [melhor["o"].x, melhor["o"].y, melhor["o"].z])
	print("[deitado] DEITADA_D := Vector3(%.4f, %.4f, %.4f)" % [melhor["d"].x, melhor["d"].y, melhor["d"].z])
	print("[deitado] DEITADA_DORSO := Vector3(%.4f, %.4f, %.4f)" % [melhor["dorso"].x, melhor["dorso"].y,
		melhor["dorso"].z])
	print("[deitado] DEITADA_POSE := %s" % JSON.stringify(melhor["pose"]))


## Acha a pegada do jogo pelo `AjusteDaMao` (so aqui, fora do jogo) e imprime as
## constantes `PEGADA_*` do `CelularNaMao`.
func _resolver() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--polegar="):
			var pp := a.trim_prefix("--polegar=").split(",")
			polegar_y = pp[0].to_float()
			polegar_z = pp[1].to_float()
		elif a.begins_with("--dedos="):
			var dd := a.trim_prefix("--dedos=").split(",")
			dedos_y = [dd[0].to_float(), dd[1].to_float(), dd[2].to_float()]
	var aj := AjusteDaMao.new(IphoneDeJogo.TAMANHO * 0.5, IphoneDeJogo.RAIO_CANTO, true)
	aj.metas = metas_do_jogo()
	if OS.get_cmdline_user_args().has("--so-polegar"):
		# A mao e os quatro dedos ficam onde estao (a pegada do jogo); so o
		# polegar procura a lateral. Varios pontos de partida do polegar.
		aj.so_polegar()
		var melhor_p := {}
		var custo_p := INF
		for pol: Array in [CelularNaMao.PEGADA_POSE["polegar"], [58, 26, 34, 4, 8], [64, 22, 36, 0, 4],
				[40, 30, 10, 5, 10], [70, 10, 20, 10, 5], [30, 20, -20, 5, 5], [50, 0, 0, 0, 0]]:
			var chute := {"o": CelularNaMao.PEGADA_O, "d": CelularNaMao.PEGADA_D,
				"dorso": CelularNaMao.PEGADA_DORSO,
				"pose": {"dedos": CelularNaMao.PEGADA_POSE["dedos"], "polegar": pol}}
			var p := aj.resolver(chute, 200)
			var med := aj.medir(p)
			var e0 := MaoDoCelular.esqueleto(p["o"], p["d"], p["dorso"], p["pose"], true)
			var c4: Vector3 = MaoDoCelular.polpa(e0, 4)["centro"]
			var r4 := float(MaoDoCelular.raios_do_dedo(4)[3])
			var meia := IphoneDeJogo.TAMANHO * 0.5
			var na_frente := maxf(0.0, c4.z + r4 - meia.z) if c4.x - r4 < meia.x else 0.0
			var custo := float(med["custo"]) + float(med["dentro"]) * 60.0 + na_frente * 1000.0 * 80.0
			print("[ajuste] polegar %s: custo=%.1f dentro=%d pior=%.2f mm polpa (%.1f, %.1f, %.1f) na frente %.1f mm" % [
				pol, med["custo"], med["dentro"], med["pior_mm"], c4.x * 1000.0, c4.y * 1000.0, c4.z * 1000.0,
				na_frente * 1000.0])
			if custo < custo_p:
				custo_p = custo
				melhor_p = p
		print("[ajuste] POLEGAR := %s" % JSON.stringify(melhor_p["pose"]["polegar"]))
		return
	var iteracoes := 260
	var chutes := [
		{"o": Vector3(0.012, -0.030, -0.016), "d": Vector3(-0.8, 0.55, 0.0),
			"dorso": Vector3(0.1, 0.0, -1.0),
			"pose": {"dedos": [[15, 45, 35, 0], [25, 55, 40, 0], [30, 55, 40, 0], [45, 55, 35, 0]],
				"polegar": [58, 26, 34, 4, 8]}},
		{"o": Vector3(0.006, -0.040, -0.018), "d": Vector3(-0.6, 0.75, -0.1),
			"dorso": Vector3(0.2, 0.0, -1.0),
			"pose": {"dedos": [[10, 40, 30, 0], [20, 50, 38, 0], [28, 52, 40, 0], [45, 55, 35, 0]],
				"polegar": [64, 22, 36, 0, 4]}},
		{"o": Vector3(0.000, -0.020, -0.020), "d": Vector3(-0.9, 0.35, 0.0),
			"dorso": Vector3(0.0, 0.1, -1.0),
			"pose": {"dedos": [[20, 40, 30, 0], [25, 50, 35, 0], [30, 55, 40, 0], [50, 60, 40, 0]],
				"polegar": [50, 36, 44, 16, 26]}},
		{"o": Vector3(0.022, -0.030, -0.012), "d": Vector3(-0.85, 0.45, 0.0),
			"dorso": Vector3(0.0, 0.0, -1.0),
			"pose": {"dedos": [[15, 30, 20, 0], [20, 40, 28, 0], [22, 45, 30, 0], [30, 55, 35, 0]],
				"polegar": [40, 50, -60, 30, 18]}},
		{"o": Vector3(0.018, -0.040, -0.013), "d": Vector3(-0.75, 0.6, -0.1),
			"dorso": Vector3(0.1, 0.0, -1.0),
			"pose": {"dedos": [[10, 35, 25, 2], [15, 45, 30, 0], [20, 50, 32, -2], [30, 60, 40, -4]],
				"polegar": [35, 45, -50, 25, 20]}},
		{"o": Vector3(0.026, -0.020, -0.013), "d": Vector3(-0.95, 0.25, 0.0),
			"dorso": Vector3(0.0, 0.1, -1.0),
			"pose": {"dedos": [[20, 35, 25, 0], [25, 40, 28, 0], [25, 45, 30, 0], [35, 55, 35, 0]],
				"polegar": [45, 40, -40, 20, 15]}},
		{"o": Vector3(0.006, -0.044, -0.013), "d": Vector3(-0.35, 0.8, -0.45),
			"dorso": Vector3(0.2, 0.1, -1.0),
			"pose": {"dedos": [[10, 30, 20, 2], [20, 50, 35, 0], [25, 50, 35, -2], [35, 55, 38, -4]],
				"polegar": [40, 50, -60, 30, 18]}},
		{"o": CelularNaMao.PEGADA_O, "d": CelularNaMao.PEGADA_D, "dorso": CelularNaMao.PEGADA_DORSO,
			"pose": CelularNaMao.PEGADA_POSE},
		{"o": CelularNaMao.PEGADA_O, "d": CelularNaMao.PEGADA_D, "dorso": CelularNaMao.PEGADA_DORSO,
			"pose": {"dedos": CelularNaMao.PEGADA_POSE["dedos"], "polegar": [30, 20, -40, 10, 15]}},
		{"o": Vector3(0.010, -0.040, -0.016), "d": Vector3(-0.5, 0.8, -0.3),
			"dorso": Vector3(0.3, 0.0, -1.0),
			"pose": {"dedos": [[25, 40, 28, 2], [30, 45, 30, 0], [30, 45, 30, -2], [40, 55, 35, -4]],
				"polegar": [30, 40, -40, 25, 20]}},
		{"o": Vector3(0.004, -0.050, -0.011), "d": Vector3(-0.2, 0.9, -0.4),
			"dorso": Vector3(0.1, 0.2, -1.0),
			"pose": {"dedos": [[5, 20, 14, 3], [15, 40, 28, 0], [20, 45, 30, -3], [30, 50, 35, -6]],
				"polegar": [45, 55, -70, 35, 20]}},
	]
	var melhor := {}
	var custo_melhor := INF
	for i in chutes.size():
		var p := aj.resolver(chutes[i], iteracoes)
		var med := aj.medir(p)
		print("[ajuste] chute %d: custo=%.1f dentro=%d pior=%.2f mm metas=%s" % [i, med["custo"],
			med["dentro"], med["pior_mm"], med["metas_mm"]])
		# O que decide: quanto as pontas do indicador, do medio e do anelar passam
		# da frente do vidro (o que o olho le como dedo atravessando) e quanto da
		# mao entra no aparelho.
		var e0 := MaoDoCelular.esqueleto(p["o"], p["d"], p["dorso"], p["pose"], true)
		# Sobre a tela: quanto a borda de dentro da ponta avanca alem da borda do
		# vidro (a tela comeca 4,7 mm para dentro da lateral), com a ponta na
		# frente dele.
		var frente := 0.0
		var sobre := 0.0
		var meia := IphoneDeJogo.TAMANHO * 0.5
		for dedo in 3:
			var c0: Vector3 = MaoDoCelular.polpa(e0, dedo)["centro"]
			var rp := float(MaoDoCelular.raios_do_dedo(dedo)[3])
			var f := c0.z + rp - meia.z
			frente = maxf(frente, f)
			if f > 0.0:
				sobre = maxf(sobre, (c0.x + rp) - (-IphoneDeJogo.TELA.x * 0.5))
		# O polegar: quanto a polpa dele entra na frente do vidro (tem de ficar na
		# lateral, fora da frente).
		var c4: Vector3 = MaoDoCelular.polpa(e0, 4)["centro"]
		var r4 := float(MaoDoCelular.raios_do_dedo(4)[3])
		# Na lateral o polegar (mais grosso que o aparelho) aparece de frente ao
		# lado dele, e isso e o certo; o que nao pode e ele entrar sobre a TELA.
		var polegar_frente := 0.0
		if c4.z + r4 > meia.z:
			polegar_frente = maxf(0.0, IphoneDeJogo.TELA.x * 0.5 - (c4.x - r4))
		print("[ajuste]   frente da ponta %.1f mm, sobre a tela %.1f mm, polegar na frente %.1f mm em (%.1f, %.1f)" % [
			frente * 1000.0, sobre * 1000.0, polegar_frente * 1000.0, c4.x * 1000.0, c4.y * 1000.0])
		var custo := float(med["custo"]) + float(med["dentro"]) * 60.0 - float(med["pior_mm"]) * 400.0 \
			+ maxf(0.0, frente * 1000.0 - 6.0) * 60.0 + maxf(0.0, sobre * 1000.0) * 150.0 \
			+ maxf(0.0, polegar_frente * 1000.0 - 2.0) * 80.0
		if custo < custo_melhor:
			custo_melhor = custo
			melhor = p
	print("[ajuste] PEGADA_O := Vector3(%.4f, %.4f, %.4f)" % [melhor["o"].x, melhor["o"].y, melhor["o"].z])
	print("[ajuste] PEGADA_D := Vector3(%.4f, %.4f, %.4f)" % [melhor["d"].x, melhor["d"].y, melhor["d"].z])
	print("[ajuste] PEGADA_DORSO := Vector3(%.4f, %.4f, %.4f)" % [melhor["dorso"].x, melhor["dorso"].y,
		melhor["dorso"].z])
	print("[ajuste] PEGADA_POSE := %s" % JSON.stringify(melhor["pose"]))
	var e := MaoDoCelular.esqueleto(melhor["o"], melhor["d"], melhor["dorso"], melhor["pose"], true)
	var m := IphoneDeJogo.TAMANHO * 0.5
	for i in 5:
		var c: Vector3 = MaoDoCelular.polpa(e, i)["centro"]
		print("[ajuste] polpa %d centro (%.1f, %.1f, %.1f) mm, frente da ponta %.1f mm" % [i, c.x * 1000.0,
			c.y * 1000.0, c.z * 1000.0, (c.z + float(MaoDoCelular.raios_do_dedo(i)[3]) - m.z) * 1000.0])


func _rodar() -> void:
	await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--resolver-deitado"):
		_resolver_deitado()
		get_tree().quit(0)
		return
	if OS.get_cmdline_user_args().has("--resolver"):
		_resolver()
		get_tree().quit(0)
		return
	DirAccess.make_dir_recursive_absolute(SP)
	_montar_mundo()
	jogador = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Node3D
	add_child(jogador)
	jogador.global_position = Vector3(0.0, 0.05, 0.0)
	await _passar(0.8)
	await _foto("00_antes")

	# Tirando do bolso: quadro a quadro.
	Celular.abrir()
	for i in 12:
		await _guardar_quadro()
		await _passar(0.05)
	_mosaico("01_subindo")
	await _passar(0.6)
	await _foto("02_bloqueio")
	_medir_raio()
	if OS.get_cmdline_user_args().has("--medir"):
		await _de_perto()
		get_tree().quit(0)
		return

	Celular.call("_acionar")
	await _passar(0.12)
	await _foto("03_destravando")
	await _passar(0.7)
	await _foto("04_inicio")

	# A loja: a pagina da Cobrinha (sem saldo), e instalar as Notas.
	var inicio: SoInicio = Celular.get("_inicio")
	Celular.call("_lancar", &"loja", inicio.rect_do_icone(103))
	await _passar(0.12)
	await _foto("05_abrindo_app")
	await _passar(0.5)
	await _foto("06_loja")
	var loja := Celular.get("_app") as AppLoja
	loja.call("_abrir_detalhe", &"cobrinha")
	await _passar(0.3)
	await _foto("07_loja_detalhe")
	loja.call("_apertar_botao", &"cobrinha")
	await _passar(0.2)
	await _foto("08_loja_armado")
	loja.call("_apertar_botao", &"cobrinha")
	await _passar(0.4)
	await _foto("09_sem_saldo")
	Celular.call("_responder_alerta", 0)
	loja.call("_abrir_detalhe", &"notas")
	loja.call("_apertar_botao", &"notas")
	loja.call("_apertar_botao", &"notas")
	await _passar(0.9)
	await _foto("10_baixando")
	await _passar(2.5)
	await _foto("11_instalado")
	inicio.acao(&"editar")
	await _passar(0.3)
	await _foto("12_editando")
	Celular.call("pedir_apagar", &"iweed")
	await _passar(0.4)
	await _foto("13_apagar")
	Celular.call("_responder_alerta", 0)
	inicio.acao(&"editar")

	for id: StringName in [&"ajustes", &"portal", &"contatos", &"telefone", &"mensagens", &"trampo",
			&"iweed", &"calculadora", &"notas", &"lanterna", &"bussola", &"tempo", &"radio",
			&"cobrinha"]:
		if not _so.is_empty() and String(id) != _so:
			continue
		Celular.call("_lancar_sem_zoom", id)
		await _passar(0.35)
		await _foto("20_app_" + String(id))
	var cob := Celular.get("_apps").get(&"cobrinha") as AppCobrinha
	if cob != null:
		cob.acao(&"ok")
		await _passar(1.2)
		await _foto("21_cobrinha_jogando")
	var aj := Celular.get("_apps").get(&"ajustes") as AppAjustes
	if aj != null:
		Celular.call("_lancar_sem_zoom", &"ajustes")
		aj.mostrar_uso()
		await _passar(0.3)
		await _foto("22_ajustes_uso")
	if _so.is_empty() or _so == "mapas":
		await _mapas()
	Celular.call("_lancar_sem_zoom", &"lanterna")
	Celular.lanterna(true)
	await _passar(0.3)
	await _foto("23_lanterna_acesa")
	Celular.lanterna(false)

	# O braco de fora: uma segunda camera olhando o rig de lado e de cima.
	var rig := Celular.get("_rig") as CelularNaMao
	var cam_jogo := get_viewport().get_camera_3d()
	var fora := Camera3D.new()
	fora.near = 0.01
	fora.fov = 40.0
	add_child(fora)
	for de: Vector3 in [Vector3(0.45, 0.1, -0.1), Vector3(-0.35, 0.25, -0.35), Vector3(0.2, -0.3, -0.5),
			Vector3(0.0, 0.5, 0.2)]:
		var alvo := rig.fone.global_position
		fora.global_position = cam_jogo.global_transform * de
		fora.look_at(alvo, Vector3.UP)
		fora.current = true
		await _guardar_quadro()
	_mosaico("30_braco_de_fora", 2)
	cam_jogo.current = true

	Celular.fechar()
	for i in 8:
		await _guardar_quadro()
		await _passar(0.05)
	_mosaico("40_guardando")
	await _passar(0.6)
	await _foto("41_guardado")
	get_tree().quit(0)


## O Mapas: o aparelho deitando nas duas maos, a busca com os alfinetes, o
## balao, a rota, a pagina dobrada e o satelite; os bracos vistos de fora; e a
## volta para em pe.
func _mapas() -> void:
	Celular.call("_lancar_sem_zoom", &"mapas")
	for i in 8:
		await _guardar_quadro()
		await _passar(0.06)
	_mosaico("50_mapas_girando")
	await _passar(0.4)
	await _foto("51_mapas_deitado")
	var m := Celular.get("_apps").get(&"mapas") as AppMapas
	Gps.filtrar_por(&"mercado")
	await _passar(1.4)
	await _foto("52_mapas_busca")
	m.acao(&"baixo")
	await _passar(0.9)
	await _foto("53_mapas_balao")
	m.acao(&"ok")
	await _passar(1.0)
	await _foto("54_mapas_rota")
	m.acao_extra(&"opcoes")
	await _passar(0.7)
	await _foto("55_mapas_pagina")
	m.tocar(["opcao", 3])
	await _passar(0.5)
	await _foto("56_mapas_satelite")
	m.tocar(["opcao", 2])
	m.acao_extra(&"examinar")
	m.acao_extra(&"examinar")
	await _passar(0.8)
	await _foto("57_mapas_bussola")
	var rig := Celular.get("_rig") as CelularNaMao
	var cam_jogo := get_viewport().get_camera_3d()
	var fora := Camera3D.new()
	fora.near = 0.01
	fora.fov = 40.0
	add_child(fora)
	for de: Vector3 in [Vector3(0.0, 0.05, 0.25), Vector3(0.35, 0.1, -0.1), Vector3(-0.35, 0.15, -0.2),
			Vector3(0.0, 0.45, -0.3)]:
		fora.global_position = cam_jogo.global_transform * de
		fora.look_at(rig.fone.global_position, Vector3.UP)
		fora.current = true
		await _guardar_quadro()
	_mosaico("58_deitado_de_fora", 2)
	cam_jogo.current = true
	fora.queue_free()
	Celular.call("_voltar")
	Celular.call("_voltar")
	for i in 8:
		await _guardar_quadro()
		await _passar(0.08)
	_mosaico("59_mapas_endireitando")


## As bordas do aparelho de perto, onde cada dedo encosta.
func _de_perto() -> void:
	var rig := Celular.get("_rig") as CelularNaMao
	var cam_jogo := get_viewport().get_camera_3d()
	var fora := Camera3D.new()
	fora.near = 0.005
	fora.fov = 38.0
	add_child(fora)
	for de: Vector3 in [Vector3(-0.14, 0.02, 0.05), Vector3(-0.10, -0.02, -0.10), Vector3(0.0, -0.13, 0.03),
			Vector3(0.12, -0.04, 0.06), Vector3(0.03, 0.02, -0.14), Vector3(0.0, 0.0, 0.16)]:
		var xf := rig.fone.global_transform
		fora.global_position = xf * de
		fora.look_at(xf * Vector3(0.0, -0.01, 0.0), xf.basis.y)
		fora.current = true
		await _guardar_quadro()
	_mosaico("50_de_perto", 3)
	cam_jogo.current = true
	fora.queue_free()


## Quanto da malha do braco entra no aparelho: a distancia com sinal de cada
## vertice a caixa de canto arredondado do iPhone, no espaco dele. Separa por
## regiao (lateral esquerda: as pontas dos dedos; direita: o polegar e a
## tenar; costas: a palma e as falanges; frente: o que cruza o vidro).
func _medir_dedos(rig: CelularNaMao) -> void:
	var b := rig.braco
	var inv := rig.fone.global_transform.affine_inverse() * b.global_transform
	var vs: PackedVector3Array = b.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var meia := IphoneDeJogo.TAMANHO * 0.5
	var raio := IphoneDeJogo.RAIO_CANTO
	var regioes := {"esquerda": [0, 0.0], "direita": [0, 0.0], "costas": [0, 0.0], "frente": [0, 0.0],
		"encostando": [0, 0.0]}
	for v0 in vs:
		var p := inv * v0
		var q2 := Vector2(absf(p.x), absf(p.y)) - Vector2(meia.x - raio, meia.y - raio)
		var d2 := Vector2(maxf(q2.x, 0.0), maxf(q2.y, 0.0)).length() + minf(maxf(q2.x, q2.y), 0.0) - raio
		var dz := absf(p.z) - meia.z
		var d := Vector2(maxf(d2, 0.0), maxf(dz, 0.0)).length() + minf(maxf(d2, dz), 0.0)
		var chave := ""
		if d < -0.0004:
			if dz > d2:
				chave = "frente" if p.z > 0.0 else "costas"
			else:
				chave = "esquerda" if p.x < 0.0 else "direita"
		elif d < 0.0015:
			chave = "encostando"
		if chave.is_empty():
			continue
		regioes[chave][0] = int(regioes[chave][0]) + 1
		regioes[chave][1] = minf(float(regioes[chave][1]), d)
	for k: String in regioes:
		print("[dedos] %s: %d vertices, pior %.2f mm" % [k, int(regioes[k][0]), float(regioes[k][1]) * 1000.0])
	# As polpas e as juntas no espaco do aparelho: z acima da face do vidro
	# (+4,65 mm) com |x| dentro da borda e dedo sobre a tela.
	var e := MaoDoCelular.esqueleto(CelularNaMao.PEGADA_O, CelularNaMao.PEGADA_D,
		CelularNaMao.PEGADA_DORSO, CelularNaMao.PEGADA_POSE, true)
	for i in 5:
		var pp := MaoDoCelular.polpa(e, i)
		var p: Vector3 = pp["p"]
		var c: Vector3 = pp["centro"]
		var raio_f: float = MaoDoCelular.raios_do_dedo(i)[3]
		# O quanto a ponta invade a frente: a frente da ponta (centro + raio em z)
		# acima do vidro, e para dentro da borda em x.
		print("[polpa %d] p=(%.1f, %.1f, %.1f) mm  centro=(%.1f, %.1f, %.1f)  frente_da_ponta=%.1f mm  dentro_da_borda=%.1f mm" % [
			i, p.x * 1000.0, p.y * 1000.0, p.z * 1000.0, c.x * 1000.0, c.y * 1000.0, c.z * 1000.0,
			(c.z + raio_f - meia.z) * 1000.0, (meia.x - absf(c.x) + raio_f) * 1000.0])


## O centro e os cantos da tela, projetados e desprojetados: o raio do mouse
## tem de devolver o mesmo uv.
func _medir_raio() -> void:
	var rig := Celular.get("_rig") as CelularNaMao
	if rig == null:
		print("[raio] sem rig")
		return
	var pior := 0.0
	for uv: Vector2 in [Vector2(0.5, 0.5), Vector2(0.1, 0.1), Vector2(0.9, 0.12), Vector2(0.15, 0.9),
			Vector2(0.88, 0.85)]:
		var p := rig.na_tela(uv)
		var volta := rig.uv_da_tela(p)
		pior = maxf(pior, volta.distance_to(uv))
		print("[raio] uv %s -> tela %s -> uv %s" % [uv, p, volta])
	print("[raio] pior erro %.4f" % pior)
	_medir_dedos(rig)
	var cima := rig.na_tela(Vector2(0.5, 0.0))
	var baixo := rig.na_tela(Vector2(0.5, 1.0))
	var alto := get_viewport().get_visible_rect().size.y
	print("[raio] a tela ocupa %.0f%% da altura do quadro" % (absf(baixo.y - cima.y) / alto * 100.0))
