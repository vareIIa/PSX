## A mao que segura o celular na leitura, sem carro: fotografada de todos os
## lados, em mosaico, e medida (quanto de cada polpa encosta onde devia, e
## quanto da mao entra no aparelho).
##
##     godot --path game --resolution 1280x720 res://tests/bancada_celular_na_mao.tscn -- --saida=<DIR ABSOLUTO> [--resolver] [--digitar] [--piscar]
##
## `--resolver` roda o `AjusteDaMao` a partir de nove chutes (a palma girada em
## volta do antebraco, e a pegada de agora) e imprime a que ganhou, para virar
## as constantes `LEITURA_*` do `MotoristaCena`; sem ele a bancada fotografa a
## pegada que o jogo usa. `--digitar` fotografa o polegar batendo e segurando o
## apagar, quadro a quadro, e mede o erro da polpa em cada tecla. `--piscar`
## conta os quadros em que a tela sai escura (perto da origem ela nao pisca: o
## vidro que apagava a tela so ganhava a profundidade na estrada, longe dela).
##
## Os mosaicos tem 16 quadros de 320 x 180, lidos da esquerda para a direita e
## de cima para baixo.
extends Node

const PISO := 0.30
const OLHO := Vector3(-0.36, PISO + 0.80, -0.08)
const THUMB := Vector2i(320, 180)

var SP := ""
var cam: Camera3D
var m: MotoristaCena
var _quadros: Array[Image] = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			SP = a.trim_prefix("--saida=").path_join("")
	_rodar()


func _caixa(mundo: Node3D, tam: Vector3, centro: Vector3, cor: Color) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.85
	mi.material_override = mat
	mundo.add_child(mi)
	mi.position = centro


func _mirar(de: Vector3, para: Vector3, fov: float) -> void:
	cam.position = de
	cam.look_at(para, Vector3.UP)
	cam.fov = fov


func _passar(segundos: float) -> void:
	var t := 0.0
	while t < segundos:
		await get_tree().process_frame
		t += get_process_delta_time()


func _foto(nome: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(SP + nome + ".png")


## Guarda o quadro de agora no mosaico.
func _guardar() -> void:
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


func _rodar() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(SP)
	var mundo := Node3D.new()
	add_child(mundo)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("10141a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("304058")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 3.0
	amb.environment = env
	mundo.add_child(amb)
	_caixa(mundo, Vector3(1.6, 0.02, 2.4), Vector3(0.0, PISO - 0.01, 0.0), Color("1d1f24"))
	_caixa(mundo, Vector3(1.6, 0.35, 0.4), Vector3(0.0, PISO + 0.62, OLHO.z - 0.95), Color("2b2521"))
	var hud := get_node_or_null("/root/Celular")
	if hud != null:
		hud.call("fechar_em_silencio")
		hud.process_mode = Node.PROCESS_MODE_DISABLED
	var lua := DirectionalLight3D.new()
	lua.light_color = Color(0.7, 0.75, 0.9)
	lua.light_energy = 0.25
	mundo.add_child(lua)
	lua.rotation = Vector3(-0.9, 0.5, 0.0)
	var luz_verm := OmniLight3D.new()
	luz_verm.light_color = Color(1.0, 0.3, 0.2)
	luz_verm.light_energy = 0.25
	luz_verm.omni_range = 1.4
	mundo.add_child(luz_verm)
	luz_verm.position = OLHO + Vector3(0.10, -0.36, -0.50)

	m = MotoristaCena.new()
	mundo.add_child(m)
	m._olho = OLHO
	m._montar_maos_do_susto(Color(0.78, 0.62, 0.50), Color(0.82, 0.83, 0.86), true)
	m._montar_mao_direita(null, Color(0.78, 0.62, 0.50), Color(0.82, 0.83, 0.86), true)
	var app := AppMensagens.new()
	app.preparar("Viagem", [["Lucas", "Chegamos!! Frio do cão"], ["Mari", "Cadê vc??"],
		["Lucas", "vc vem mesmo né?"]], "Hoje 23:04",
		"Gente, não vou conseguir ir. Deu um problema aqui em casa, desculpa")
	m.ligar_tela(app)
	m._fone.brilho(1.0)

	cam = Camera3D.new()
	cam.near = 0.01
	mundo.add_child(cam)
	cam.current = true

	m.mostrar_celular(true)
	await _passar(0.8)
	var args := OS.get_cmdline_user_args()
	if args.has("--resolver"):
		_resolver()
	await _passar(0.2)
	_medir("pegada")
	if args.has("--piscar"):
		await _contar_piscadas()
		get_tree().quit(0)
		return
	await _fotos_da_leitura()
	if args.has("--digitar"):
		await _fotos_digitando(app)
	get_tree().quit(0)


## Roda o ajuste da leitura a partir de varios chutes e fica com o melhor.
func _resolver() -> void:
	var aj := AjusteDaMao.new(Iphone4S.TAMANHO * 0.5, Iphone4S.RAIO_CANTO, true)
	aj.metas = MotoristaCena.metas_da_leitura(m.polegar_de_repouso())
	# Chutes: a palma girada em volta do antebraco, de oito em oito avos de
	# volta, e a pegada de agora.
	var chutes := []
	var d0 := Vector3(-0.3, 0.6, -0.7).normalized()
	var r0 := (Vector3.RIGHT - d0 * d0.x).normalized()
	for k in 8:
		chutes.append({"o": Vector3(0.018, -0.015, -0.018), "d": d0,
			"dorso": r0.rotated(d0, TAU * float(k) / 8.0),
			"pose": {"dedos": [[40, 50, 35, 0], [40, 50, 35, 0], [40, 50, 35, 0], [45, 55, 38, 0]],
				"polegar": [40, 40, 0, 20, 18]}})
	chutes.append({"o": m.leitura_o, "d": m.leitura_d, "dorso": m.leitura_dorso,
		"pose": m.leitura_pose})
	var melhor := {}
	var custo_melhor := INF
	for i in chutes.size():
		var t0 := Time.get_ticks_usec()
		var p := aj.resolver(chutes[i], 150)
		var med := aj.medir(p)
		print("[ajuste] chute %d: custo=%.1f dentro=%d pior=%.2f mm metas=%s (%.0f ms)" % [i,
			med["custo"], med["dentro"], med["pior_mm"], med["metas_mm"],
			(Time.get_ticks_usec() - t0) / 1000.0])
		if float(med["custo"]) < custo_melhor:
			custo_melhor = med["custo"]
			melhor = p
	print("[ajuste] LEITURA_O := Vector3(%.4f, %.4f, %.4f)" % [melhor["o"].x, melhor["o"].y, melhor["o"].z])
	print("[ajuste] LEITURA_D := Vector3(%.4f, %.4f, %.4f)" % [melhor["d"].x, melhor["d"].y, melhor["d"].z])
	print("[ajuste] LEITURA_DORSO := Vector3(%.4f, %.4f, %.4f)" % [melhor["dorso"].x, melhor["dorso"].y, melhor["dorso"].z])
	print("[ajuste] LEITURA_POSE := %s" % [JSON.stringify(melhor["pose"])])
	m.leitura_o = melhor["o"]
	m.leitura_d = melhor["d"]
	m.leitura_dorso = melhor["dorso"]
	m.leitura_pose = melhor["pose"]
	m.esquecer_polegar()


## Quanto de cada meta a pegada do jogo cumpre, e quanto da malha entra no
## aparelho (os vertices de verdade, e nao as esferas do ajuste).
func _medir(nome: String) -> void:
	var aj := AjusteDaMao.new(Iphone4S.TAMANHO * 0.5, Iphone4S.RAIO_CANTO, true)
	aj.metas = MotoristaCena.metas_da_leitura(m.polegar_de_repouso())
	var pg := {"o": m.leitura_o, "d": m.leitura_d, "dorso": m.leitura_dorso,
		"pose": m.leitura_pose}
	var med := aj.medir(pg)
	print("[medida] %s: custo=%.1f esferas_dentro=%d pior=%.2f mm metas_mm=%s" % [nome,
		med["custo"], med["dentro"], med["pior_mm"], med["metas_mm"]])
	var b := m._braco_leitura
	var fone := m._celular.global_transform
	var inv := fone.affine_inverse() * b.global_transform
	var vs: PackedVector3Array = b.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var dentro := 0
	var pior := 0.0
	var encostando := 0
	for v in vs:
		var sd := AjusteDaMao.distancia(inv * v, Iphone4S.TAMANHO * 0.5, Iphone4S.RAIO_CANTO)
		if sd < -0.0005:
			dentro += 1
			pior = minf(pior, sd)
			print("[medida]   dentro: %s sd=%.2f mm" % [inv * v, sd * 1000.0])
		elif sd < 0.0015:
			encostando += 1
	print("[medida] %s: vertices=%d dentro=%d (pior %.2f mm) encostando=%d" % [nome, vs.size(),
		dentro, pior * 1000.0, encostando])


## A leitura de todos os lados: o olho do jogo, e uma volta em torno do aparelho.
func _fotos_da_leitura() -> void:
	var olho := OLHO + MotoristaCena.OLHO_DA_CENA
	_mirar(olho, m.ponto_da_tela(Vector2(0.5, 0.55)), 30.0)
	await _foto("leitura_olho")
	_mirar(olho, m.ponto_da_tela(Vector2(0.62, 0.78)), 24.0)
	await _foto("leitura_teclado")
	_mirar(olho, m.ponto_da_tela(Vector2(0.5, 0.5)), 60.0)
	await _foto("leitura_aberta")
	# A volta: 8 azimutes por cima e 8 por baixo, no espaco do aparelho.
	for elev: float in [18.0, -25.0]:
		for i in 8:
			var az := deg_to_rad(float(i) * 45.0)
			var e := deg_to_rad(elev)
			var dir := Vector3(sin(az) * cos(e), sin(e), cos(az) * cos(e))
			var fone := m._celular.global_transform
			_mirar(fone * (dir * 0.26), fone * Vector3(0.0, -0.01, 0.0), 42.0)
			await _guardar()
	_mosaico("leitura_volta")
	# De perto, nas quatro bordas: onde cada dedo encosta.
	var perto := [Vector3(-0.12, 0.01, 0.03), Vector3(-0.09, 0.0, -0.09),
		Vector3(0.0, -0.12, 0.02), Vector3(0.11, -0.03, 0.05),
		Vector3(0.02, 0.02, -0.13), Vector3(0.06, -0.10, 0.08),
		Vector3(-0.08, -0.08, 0.06), Vector3(0.0, 0.03, 0.13)]
	for p: Vector3 in perto:
		var fone := m._celular.global_transform
		_mirar(fone * p, fone * Vector3(0.0, -0.015, 0.0), 38.0)
		await _guardar()
	_mosaico("leitura_perto")
	# O tempo: a mesma lente, dois segundos, com medo. O aparelho e a mao tem de
	# andar juntos.
	m.medo = 1.0
	for i in 8:
		await _passar(0.25)
		_mirar(olho, m.ponto_da_tela(Vector2(0.5, 0.55)), 30.0)
		await _guardar()
	_mosaico("leitura_tempo")
	m.medo = 0.0


func _fotos_digitando(app: AppMensagens) -> void:
	var olho := OLHO + MotoristaCena.OLHO_DA_CENA
	m.tecla_encostou.connect(func(_uv: Vector2) -> void: app.apertar_apagar())
	m.tecla_soltou.connect(func(_uv: Vector2) -> void: app.soltar_apagar())
	app.travar_em(14)
	# Tres toques, quadro a quadro, pela lente do jogo e de lado.
	for vista in 2:
		m.teclar(MotoristaCena.APAGAR_UV)
		for i in 16:
			var fone := m._celular.global_transform
			if vista == 0:
				_mirar(olho, m.ponto_da_tela(Vector2(0.60, 0.74)), 30.0)
			else:
				_mirar(fone * Vector3(0.13, -0.10, 0.035), fone * Vector3(0.015, -0.03, 0.0), 34.0)
			await _guardar()
			await _passar(1.0 / 60.0)
		_mosaico("digita_%d" % vista)
		await _passar(0.4)
	# Segurando: o apagar dispara, e ele solta em "Gente, nao vou".
	m.segurar_tecla(MotoristaCena.APAGAR_UV)
	var t := 0.0
	var n := 0
	while app.letras() > 14 and t < 6.0:
		await _passar(0.1)
		t += 0.1
		if int(t * 10.0) % 5 == 0:
			print("[digita] t=%.1f fase=%s segurando=%s apertado=%s apagando=%s t_ap=%.2f letras=%d pol=%s" % [t,
				m._toque_fase, m._segurando, app._apertado, app._apagando, app._t_apertado,
				app.letras(), m._pol_agora])
		if n < 16 and int(t * 10.0) % 3 == 0:
			_mirar(olho, m.ponto_da_tela(Vector2(0.60, 0.74)), 30.0)
			await _guardar()
			n += 1
	m.soltar_tecla()
	# Onde a polpa do polegar ficou em cada solucao guardada, contra o alvo.
	for chave: String in m._pol_cache:
		var uv := Vector2(float(chave.get_slice(",", 0)), float(chave.get_slice(",", 1)))
		var h := float(chave.get_slice(",", 2))
		var e := MaoPosada.esqueleto(m.leitura_o, m.leitura_d, m.leitura_dorso,
			{"dedos": m.leitura_pose["dedos"], "polegar": m._pol_cache[chave]}, true)
		var pp := MaoPosada.polpa(e, 4)
		var alvo := Iphone4S.ponto_da_tela(uv) + Vector3(0, 0, h)
		print("[digita] polegar %s: erro=%.1f mm polpa=%s pol=%s" % [chave,
			(pp["p"] as Vector3).distance_to(alvo) * 1000.0, pp["p"], m._pol_cache[chave]])
	await _passar(0.3)
	_mirar(olho, m.ponto_da_tela(Vector2(0.62, 0.78)), 24.0)
	await _guardar()
	_mosaico("digita_segura")
	print("[digita] sobrou '%s' em %.1f s" % [app.texto_no_campo(), t])


## Quantos quadros seguidos a tela sai escura (a tela "piscando" que a rajada da
## cena achou): 400 quadros, cada um lido depois de desenhado.
func _contar_piscadas() -> void:
	var olho := OLHO + MotoristaCena.OLHO_DA_CENA
	var escuros := []
	cam.near = 0.08
	for i in 600:
		# A lente da cena nunca para: o ofego, o tremor e a cabeca descendo.
		var t := float(i) / 60.0
		var anda := Vector3(sin(t * 7.0) * 0.004, sin(t * 5.3) * 0.003 - t * 0.004, sin(t * 3.1) * 0.01)
		_mirar(olho + anda, m.ponto_da_tela(Vector2(0.5 + sin(t) * 0.05, 0.55)), 30.0 - t * 1.0)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var c := img.get_pixel(img.get_width() / 2, int(img.get_height() * 0.35))
		if c.get_luminance() < 0.3:
			escuros.append([i, snappedf(c.get_luminance(), 0.01)])
	print("[piscar] %d escuros de 600: %s" % [escuros.size(), escuros])
