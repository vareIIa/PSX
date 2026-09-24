## Os bracos do motorista no susto do celular, sem carro: o banco, o tapete, a
## fumaca e a luz da tela, e a lente onde a cena a poe.
##
##     godot --path game --resolution 1280x720 res://tests/bancada_braco_chao.tscn -- --saida=<DIR ABSOLUTO> [--so-leitura] [--varrer-leitura] [--terceira]
##
## A coreografia inteira, em fotos: a leitura (a mao segurando o aparelho), o
## banco (a esquerda espalma no assento, o indicador no ENVIAR), o chao (o
## braco esticado, a mao agarrando o ar), o empurrao e a pegada, e o aparelho
## subindo na mao ate a leitura. `--terceira` fotografa cada passo tambem de
## fora, pela porta do carona: e dali que um braco do avesso aparece.
##
## Existe porque a cena inteira leva meio minuto ate o chao.
extends Node

var SP := ""
const PISO := 0.30
const OLHO := Vector3(-0.36, PISO + 0.80, -0.08)
const DEBRUCA := Vector3(0.42, -0.26, -0.36)
const ALCANCA := Vector3(0.05, -0.07, -0.09)

var cam: Camera3D
var m: MotoristaCena
var fumaca: FumacaNegra
var terceira := false
var marcas: Array[MeshInstance3D] = []
var porta: Node3D


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			SP = a.trim_prefix("--saida=").path_join("")
	terceira = OS.get_cmdline_user_args().has("--terceira")
	_rodar()


func _caixa(mundo: Node3D, tam: Vector3, centro: Vector3, cor: Color, rug := 0.85) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = rug
	mi.material_override = mat
	mundo.add_child(mi)
	mi.position = centro


func _foto(nome: String, quadros: int = 3) -> void:
	for _i in quadros:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(SP + nome + ".png")


## A foto da lente e, com `--terceira`, a de fora, pela porta do carona.
func _fotos(nome: String) -> void:
	await _foto(nome, 2)
	if not terceira:
		return
	var de := cam.global_transform
	var fov := cam.fov
	for mk in marcas:
		mk.visible = true
	porta.visible = false
	_mirar(Vector3(1.25, PISO + 1.05, -0.35), Vector3(0.0, PISO + 0.45, -0.25), 62.0)
	await _foto(nome + "_fora", 1)
	_mirar(Vector3(0.05, PISO + 1.75, -0.30), Vector3(0.05, PISO + 0.3, -0.33), 70.0)
	await _foto(nome + "_cima", 1)
	for mk in marcas:
		mk.visible = false
	porta.visible = true
	cam.global_transform = de
	cam.fov = fov


func _mirar(de: Vector3, para: Vector3, fov: float) -> void:
	cam.position = de
	cam.look_at(para, Vector3.UP)
	cam.fov = fov


func _passar(segundos: float) -> void:
	var t := 0.0
	while t < segundos:
		await get_tree().process_frame
		t += 1.0 / 60.0


## A lente de agora (como a cena a poe), mirando `para`.
func _lente(debruca: float, alcanca: float, para: Vector3, fov: float) -> void:
	m.debruca_olho = DEBRUCA * debruca + ALCANCA * alcanca
	var olho := OLHO + Vector3(0, 0, 0.2) + m.debruca_olho
	_mirar(olho, para, fov)


func _rodar() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(SP)
	var mundo := Node3D.new()
	add_child(mundo)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("06080b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("243044")
	env.ambient_light_energy = 0.35
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.25
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_intensity = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 3.0
	amb.environment = env
	mundo.add_child(amb)
	# A cabine: tapete, banco do carona, console, painel, porta.
	_caixa(mundo, Vector3(1.6, 0.02, 2.4), Vector3(0.0, PISO - 0.01, 0.0), Color("1d1f24"), 0.95)
	_caixa(mundo, Vector3(0.50, 0.15, 0.48), Vector3(0.36, PISO + 0.22, OLHO.z + 0.16), Color("3a2a26"))
	_caixa(mundo, Vector3(0.50, 0.62, 0.12), Vector3(0.36, PISO + 0.55, OLHO.z + 0.44), Color("3a2a26"))
	_caixa(mundo, Vector3(0.50, 0.15, 0.48), Vector3(-0.36, PISO + 0.22, OLHO.z + 0.16), Color("3a2a26"))
	_caixa(mundo, Vector3(0.16, 0.22, 0.6), Vector3(0.0, PISO + 0.11, OLHO.z - 0.1), Color("2a2c30"))
	_caixa(mundo, Vector3(1.6, 0.35, 0.4), Vector3(0.0, PISO + 0.62, OLHO.z - 0.95), Color("2b2521"))
	_caixa(mundo, Vector3(0.04, 0.9, 1.6), Vector3(0.78, PISO + 0.45, -0.2), Color("3a2a26"))
	porta = mundo.get_child(mundo.get_child_count() - 1)
	# O aparelho do jogo (HUD) nao abre por cima da bancada, nem com tecla.
	var hud := get_node_or_null("/root/Celular")
	if hud != null:
		hud.call("fechar_em_silencio")
		hud.process_mode = Node.PROCESS_MODE_DISABLED
	var luz_verm := OmniLight3D.new()
	luz_verm.light_color = Color(1.0, 0.16, 0.08)
	luz_verm.light_energy = 0.2
	luz_verm.omni_range = 1.4
	mundo.add_child(luz_verm)
	luz_verm.position = OLHO + Vector3(0.10, -0.36, -0.50)
	var lua := DirectionalLight3D.new()
	lua.light_color = Color(0.6, 0.7, 0.9)
	lua.light_energy = 0.08
	mundo.add_child(lua)
	lua.rotation = Vector3(-1.1, 0.4, 0.0)
	if terceira:
		var luz_fora := OmniLight3D.new()
		luz_fora.light_energy = 0.6
		luz_fora.omni_range = 3.0
		mundo.add_child(luz_fora)
		luz_fora.position = Vector3(0.9, PISO + 1.4, 0.2)

	m = MotoristaCena.new()
	mundo.add_child(m)
	m._olho = OLHO
	m._montar_maos_do_susto(Color(0.78, 0.62, 0.50), Color(0.82, 0.83, 0.86), true)
	m._montar_mao_direita(null, Color(0.78, 0.62, 0.50), Color(0.82, 0.83, 0.86), true)
	var img := Image.create(146, 219, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.86, 0.9, 0.96))
	img.fill_rect(Rect2i(8, 20, 90, 22), Color(1, 1, 1))
	img.fill_rect(Rect2i(8, 50, 70, 22), Color(1, 1, 1))
	img.fill_rect(Rect2i(60, 110, 80, 22), Color(0.2, 0.5, 0.95))
	m._fone.ligar(ImageTexture.create_from_image(img))
	m._fone.brilho(1.0)
	# O olho e os ombros, para as fotos de fora.
	for c: Color in [Color.YELLOW, Color.GREEN, Color.RED]:
		var mk := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.025
		sm.height = 0.05
		mk.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mk.material_override = mat
		mk.visible = false
		mundo.add_child(mk)
		marcas.append(mk)

	cam = Camera3D.new()
	cam.near = 0.02
	mundo.add_child(cam)
	cam.current = true

	# A fumaca da cabine.
	var meia := Vector3(0.78, 0.61, 1.1)
	var centro := Vector3(0.0, PISO + meia.y, OLHO.z - 0.15)
	fumaca = FumacaNegra.criar(meia, Vector3(0.73, PISO + 0.12, OLHO.z - 0.45) - centro, 2.6)
	mundo.add_child(fumaca)
	fumaca.position = centro
	fumaca.teto = 0.22 - meia.y
	fumaca.cobre = 0.0

	# 0. A leitura: o aparelho na mao, a lente nele.
	m.mostrar_celular(true)
	var olho_leitura := OLHO + Vector3(0, 0, 0.2)
	await _passar(0.7)
	for i in 3:
		await _passar(0.3)
		_mirar(olho_leitura, m.ponto_da_tela(Vector2(0.5, 0.58)), 34.0)
		await _foto("00_leitura_%d" % i, 1)
	_mirar(olho_leitura, m.ponto_da_tela(Vector2(0.5, 0.4)), 58.0)
	await _foto("00_leitura_aberta")
	_sondar("leitura", m._braco_leitura)
	m.digitando = 1.0
	_mirar(olho_leitura, m.ponto_da_tela(Vector2(0.5, 0.58)), 34.0)
	await _passar(0.07)
	await _foto("00_leitura_digita", 1)
	m.digitando = 0.0
	# De lado e de tras, para ver os dedos nas costas do aparelho.
	var fone := m._celular.global_transform
	_mirar(fone * Vector3(-0.16, 0.02, 0.02), fone.origin, 40.0)
	await _foto("00_leitura_esquerda")
	_mirar(fone * Vector3(0.05, 0.03, -0.20), fone.origin, 45.0)
	await _foto("00_leitura_costas")
	_mirar(fone * Vector3(0.20, -0.06, 0.06), fone.origin, 45.0)
	await _foto("00_leitura_direita")
	if OS.get_cmdline_user_args().has("--varrer-leitura"):
		_varrer_leitura(olho_leitura)
		return
	if OS.get_cmdline_user_args().has("--so-leitura"):
		get_tree().quit(0)
		return

	m.arremessar_celular(0.2)
	await _passar(0.4)
	# 1. O banco: a esquerda espalma no assento, a direita chega com o dedo.
	_lente(0.45, 0.0, m._fone.global_position, 58.0)
	m.medo = 1.0
	var t0 := Time.get_ticks_usec()
	m.alcancar_celular(0.55)
	_marcar()
	await _passar(0.25)
	_marcar()
	await _fotos("01_banco_meio")
	await _passar(0.4)
	_marcar()
	await _fotos("02_banco")
	await m.tocar_tela(0.16)
	await _passar(0.02)
	# 2. O telefone cai; a mao vai atras, e o corpo desce com o apoio firme.
	m.derrubar_celular(0.38)
	m.seguir_ao_chao(0.85)
	var k := 0.0
	while k < 1.0:
		k = minf(1.0, k + 1.0 / 42.0)
		_lente(lerpf(0.45, 1.0, k), 0.0, m.ponto_da_tela(Vector2(0.5, 0.5)), lerpf(58.0, 34.0, k))
		m.apoio_forca = k * 0.4
		await get_tree().process_frame
	_marcar()
	await _fotos("03_chao_chegou")
	m.esforco = 1.0
	fumaca.cobre = 0.5
	var tf := create_tween()
	tf.tween_property(fumaca, "cobre", 0.95, 2.0)
	tf.parallel().tween_property(fumaca, "teto", 0.32 - meia.y, 2.0)
	for i in 5:
		await _passar(0.3)
		fumaca.seguir_fone(m._celular.global_position, 1.0)
		var fov := lerpf(34.0, 24.0, float(i) / 4.0)
		_lente(1.0, 0.0, m.ponto_da_tela(Vector2(0.5, 0.55)).lerp(m.ponto_da_mao_direita(), 0.3), fov)
		await _foto("04_chao_forca_%d" % i, 1)
	_marcar()
	await _fotos("05_chao_forca")
	# 3. O empurrao: o apoio afunda, o corpo desce, a mao fecha no aparelho.
	m.pegar_do_chao(0.42)
	k = 0.0
	while k < 1.0:
		k = minf(1.0, k + 1.0 / 22.0)
		m.apoio_forca = lerpf(0.4, 1.0, k)
		m.esforco = 1.0 - k
		_lente(1.0, 0.0, m.ponto_da_tela(Vector2(0.5, 0.5)).lerp(m.ponto_da_mao_direita(), 0.3), 30.0)
		await get_tree().process_frame
	while m._direita_em != &"segurando":
		await get_tree().process_frame
	_marcar()
	await _fotos("06_pegou")
	_sondar("pegou")
	var fone_g := m._celular.global_transform
	_mirar(fone_g.origin + Vector3(0.12, 0.10, 0.10), fone_g.origin, 50.0)
	await _foto("06_pegou_perto", 1)
	_mirar(fone_g.origin + Vector3(-0.05, 0.16, 0.14), fone_g.origin, 50.0)
	await _foto("06_pegou_perto2", 1)
	# 4. Sobe: o aparelho vem na mao ate a leitura, e o corpo volta ao banco.
	m.erguer_celular(1.1)
	k = 0.0
	var n := 0
	while k < 1.0:
		k = minf(1.0, k + 1.0 / 66.0)
		var e := 1.0 - pow(1.0 - k, 2.0)
		m.apoio_forca = 1.0 - k
		var mira := m.ponto_do_celular()
		_lente(1.0 - e, 1.0 - e, mira, lerpf(30.0, 40.0, e))
		await get_tree().process_frame
		if k > 0.25 and n == 0 or k > 0.6 and n == 1:
			_marcar()
			await _fotos("07_subindo_%d" % n)
			n += 1
	while m._direita_em != &"":
		await get_tree().process_frame
	await _passar(0.3)
	m.debruca_olho = Vector3.ZERO
	_mirar(olho_leitura, m.ponto_da_tela(Vector2(0.5, 0.58)), 34.0)
	await _foto("08_de_volta")
	_sondar("de_volta", m._braco_leitura)
	m.vibrar_na_mao(0.4)
	await _passar(0.12)
	await _foto("09_vibra", 1)
	var t2 := Time.get_ticks_usec()
	var tr := Time.get_ticks_usec()
	for _i in 10:
		m._braco_d.refazer()
	print("[bench] refazer %.2f ms" % [(Time.get_ticks_usec() - tr) / 10000.0])
	print("[foto] ok %.1f s" % [(t2 - t0) / 1e6])
	get_tree().quit(0)


## Poe as marcas no olho e nos ombros de agora.
func _marcar() -> void:
	m._ombros()
	marcas[0].position = m._olho_agora
	marcas[1].position = m._ombro(false)
	marcas[2].position = m._ombro(true)
	print("[bench] olho=%s ombroE=%s ombroD=%s maoE=%s maoD=%s" % [m._olho_agora,
		m._ombro(false), m._ombro(true),
		m._braco_e.pegada.get("o", Vector3.ZERO), m._braco_d.pegada.get("o", Vector3.ZERO)])


func _varrer_leitura(olho: Vector3) -> void:
	var o0 := Vector3(-0.002, -0.046, -0.0088)
	var d0 := Vector3(-0.8, 0.6, 0.10)
	var s0 := Vector3(0.10, 0.0, -1.0)
	var pol := [40, 62, -90, 55, 18]
	var variantes := [
		[o0, d0, s0, [[0, 8, 4, 3], [4, 92, 32, 0], [6, 94, 32, -2], [30, 64, 22, -4]], pol],
		[o0, d0, s0, [[0, 8, 4, 3], [8, 96, 40, 0], [10, 98, 40, -2], [36, 70, 24, -4]], pol],
		[o0 + Vector3(0.006, 0, 0), d0, s0, [[0, 8, 4, 3], [4, 92, 32, 0], [6, 94, 32, -2], [30, 64, 22, -4]], pol],
		[o0, Vector3(-0.9, 0.44, 0.10), s0, [[0, 8, 4, 3], [4, 92, 32, 0], [6, 94, 32, -2], [30, 64, 22, -4]], pol],
		[o0 + Vector3(0.004, -0.004, 0), Vector3(-0.85, 0.52, 0.10), s0, [[-4, 6, 4, 4], [6, 94, 36, 0], [8, 96, 36, -2], [34, 66, 22, -5]], pol],
		[o0 + Vector3(0.0, 0.0, -0.003), d0, s0, [[0, 8, 4, 3], [4, 92, 32, 0], [6, 94, 32, -2], [30, 64, 22, -4]], pol],
	]
	for i in variantes.size():
		var v: Array = variantes[i]
		m.leitura_o = v[0]
		m.leitura_d = v[1]
		m.leitura_dorso = v[2]
		m.leitura_pose = {"dedos": v[3], "polegar": v[4]}
		await _passar(0.1)
		_mirar(olho, m.ponto_da_tela(Vector2(0.5, 0.5)), 30.0)
		await _foto("00_var_%d" % i)
		_mirar(olho, m.ponto_da_tela(Vector2(0.5, 0.58)), 19.0)
		await _foto("00_var_%d_costas" % i)
	get_tree().quit(0)


## Quantos vertices da mao estao DENTRO do aparelho e quantos na frente do
## vidro (em cima da tela), no espaco dele.
func _sondar(nome: String, b: BracoVivo = null) -> void:
	if b == null:
		b = m._braco_d
	var fone := m._celular.global_transform
	var arr := b.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var meia := Iphone4S.TAMANHO * 0.5
	var dentro := 0
	var frente := 0
	var tras := 0
	var inv := fone.affine_inverse() * b.global_transform
	var cx_f := AABB()
	var cx_d := AABB()
	for v in vs:
		var q := inv * v
		if absf(q.x) < meia.x and absf(q.y) < meia.y:
			if absf(q.z) < meia.z:
				dentro += 1
				cx_d = AABB(q, Vector3.ZERO) if dentro == 1 else cx_d.expand(q)
			elif q.z > 0.0 and q.z < 0.05:
				frente += 1
				cx_f = AABB(q, Vector3.ZERO) if frente == 1 else cx_f.expand(q)
			elif q.z < 0.0 and q.z > -0.05:
				tras += 1
	print("[sonda] %s vertices=%d dentro=%d frente_do_vidro=%d costas=%d" % [nome, vs.size(),
		dentro, frente, tras])
	print("[sonda] caixa frente=%s  caixa dentro=%s" % [cx_f, cx_d])
	var pg := BracoVivo.levar(fone.affine_inverse() * m.global_transform, b.pegada)
	print("[sonda] pegada no fone: o=%s d=%s dorso=%s" % [pg["o"], pg["d"], pg["dorso"]])
