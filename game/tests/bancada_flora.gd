## Bancada da vegetacao (PLANO_FLORA_AAA, etapa 0).
##
##     godot --path game --script res://tests/bancada_flora.gd -- --saida=DIR
##     (SEM --headless: shader so existe com janela)
##
## Flags:
##   --saida=DIR        grava as fotos e o relatorio
##   --estilo=ps1       mede o PS1 STYLE (padrao: MODERNO, luz por pixel e HD)
##   --so=a,b           so estes criterios (cintila, cobertura, lados, fotos)
##   --tam=1920x1080    tamanho da tela da bancada
##   --param=nome:valor uniform forcado nos materiais de folha (A/B de shader)
##
## Por que uma bancada fora da cidade. Na rua a arvore divide o quadro com poste,
## predio, carro, nevoa e a hora do relogio, e duas fotos do mesmo lugar nao se
## comparam. Aqui cada especie e montada SOZINHA pelo mesmo codigo do jogo, sob
## um ceu e um sol fixos, e o que muda entre duas medidas e so a vegetacao.
##
## O que cada criterio mede
## ------------------------
## F1 cintila   Duas fotos da mesma copa com a camera andando UM QUARTO DE PIXEL
##              de lado, sem vento. Num recorte estavel a mascara da copa quase
##              nao muda; num recorte sem mipmap, cada texel de folha acende e
##              apaga e a mascara troca em massa. O numero e a fracao da mascara
##              que trocou, a 15, 40 e 80 m.
## F2 cobertura A AREA da copa na tela vezes a distancia ao quadrado, relativa a
##              de 30 m. Uma copa que se desmancha de longe ("matos voando") perde
##              area; a razao deve ficar perto de 1. A referencia era 12 m e a
##              sibipiruna reprovava em qualquer estilo e qualquer atlas: a copa
##              dela tem 5,5 m de raio, a borda de perto fica a 6,5 m da lente e
##              a area de 12 m sai inflada pela perspectiva, nao pelo recorte.
## F3 lados     Moita de cartao cruzado vista de oito rumos. A area minima sobre a
##              maxima: cartao de uma face so some inteiro de um quadrante.
## F4 fotos     Perto, rua, longe, contra o sol e de cima, para o olho.
##
## A mascara e a diferenca contra uma foto do MESMO quadro sem a planta: o chao e
## o ceu se cancelam e sobra a vegetacao, sem depender de cor de fundo.
extends SceneTree

const DIR_MAT := "res://resources/materials/"
const SH_VERTEX := "res://shaders/psx_surface.gdshader"
const SH_PIXEL := "res://shaders/psx_surface_pixel.gdshader"
const QUADROS := 8
## Diferenca (0..1, por canal) acima da qual um pixel conta como planta.
const LIMIAR := 0.035

var _raiz: Node3D
var _vp: SubViewport
var _camera: Camera3D
var _sol: DirectionalLight3D
var _env: Environment
var _saida := ""
var _moderno := true
var _so: PackedStringArray = []
var _tam := Vector2i(1920, 1080)
var _params: Dictionary = {}
var _materiais: Dictionary = {}
var _relatorio: PackedStringArray = []
var _passou := 0
var _total := 0


func _init() -> void:
	# A arvore pedida e a que cresce: a variedade da rodada 2 trocaria o oiti e a
	# mangueira da fileira a cada ajuste. As especies novas se pedem pelo nome.
	ArvoreEsqueleto.variedade = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
		elif arg == "--estilo=ps1":
			_moderno = false
		elif arg.begins_with("--so="):
			_so = arg.trim_prefix("--so=").split(",")
		elif arg.begins_with("--tam="):
			var p := arg.trim_prefix("--tam=").split("x")
			_tam = Vector2i(int(p[0]), int(p[1]))
		elif arg.begins_with("--param="):
			var q := arg.trim_prefix("--param=").split(":")
			_params[StringName(q[0])] = float(q[1])
	if not _saida.is_empty():
		DirAccess.make_dir_recursive_absolute(_saida)
	root.add_child.call_deferred(_montar())
	_rodar()


func _quer(c: String) -> bool:
	return _so.is_empty() or _so.has(c)


# ------------------------------------------------------------------ cena

func _montar() -> Node:
	var fora := Node.new()
	_vp = SubViewport.new()
	_vp.size = _tam
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_vp.positional_shadow_atlas_size = 2048
	fora.add_child(_vp)
	_raiz = Node3D.new()
	_vp.add_child(_raiz)

	var ambiente := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	var ceu := Sky.new()
	var mat_ceu := ProceduralSkyMaterial.new()
	mat_ceu.sky_top_color = Color(0.32, 0.5, 0.78)
	mat_ceu.sky_horizon_color = Color(0.72, 0.78, 0.84)
	mat_ceu.ground_bottom_color = Color(0.3, 0.28, 0.24)
	mat_ceu.ground_horizon_color = Color(0.6, 0.6, 0.56)
	mat_ceu.sun_angle_max = 20.0
	ceu.sky_material = mat_ceu
	_env.sky = ceu
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 0.9
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	ambiente.environment = _env
	_raiz.add_child(ambiente)

	_sol = DirectionalLight3D.new()
	_sol.light_energy = 1.6
	_sol.light_color = Color(1.0, 0.96, 0.88)
	_sol.shadow_enabled = _moderno
	_sol.directional_shadow_max_distance = 120.0
	_raiz.add_child(_sol)
	_sol_de(Vector3(-0.55, -0.62, -0.56))

	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.near = 0.08
	_camera.far = 600.0
	_raiz.add_child(_camera)
	_camera.current = true
	return fora


func _sol_de(direcao: Vector3) -> void:
	var d := direcao.normalized()
	var up := Vector3.UP if absf(d.y) < 0.95 else Vector3.FORWARD
	_sol.basis = Basis.looking_at(d, up)


## O material do jogo, no estilo pedido, com o conjunto HD como o EstiloVisual
## faz: o id e o nome da textura de albedo.
func _material(nome: StringName) -> Material:
	if _materiais.has(nome):
		return _materiais[nome]
	var caminho := DIR_MAT + "mat_" + String(nome) + ".tres"
	if not ResourceLoader.exists(caminho):
		push_warning("bancada_flora: sem material %s" % caminho)
		return null
	var m := (load(caminho) as ShaderMaterial).duplicate() as ShaderMaterial
	if _moderno:
		m.shader = load(_shader_moderno(nome)) as Shader
		var tex := m.get_shader_parameter(&"albedo_tex") as Texture2D
		if tex != null:
			TexturasHD.aplicar(m, StringName(tex.resource_path.get_file().get_basename()), true)
		if Vegetacao.MATERIAIS_FOLHA.has(nome):
			# Como o EstiloVisual: o cartao de perfil some so na copa.
			m.set_shader_parameter(&"fade_perfil", 1.0 if nome == &"vegetacao" else 0.0)
			for chave: StringName in _params:
				m.set_shader_parameter(chave, _params[chave])
	else:
		m.shader = load(SH_VERTEX) as Shader
	_materiais[nome] = m
	return m


## Que shader o MODERNO usa neste material. Espelha o EstiloVisual.
func _shader_moderno(nome: StringName) -> String:
	if Vegetacao.MATERIAIS_FOLHA.has(nome) and ResourceLoader.exists(Vegetacao.SHADER_FOLHA):
		return Vegetacao.SHADER_FOLHA
	return SH_PIXEL


## Monta um `sup` (material -> dados) num no com uma malha por material.
func _no(sup: Dictionary, nome: String) -> Node3D:
	var no := Node3D.new()
	no.name = nome
	for chave: StringName in sup:
		var d: Dictionary = sup[chave]
		if PSXMesh.dados_vazio(d):
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = PSXMesh.dados_para_mesh(d)
		mi.material_override = _material(StringName(String(chave).get_slice("@", 0)))
		no.add_child(mi)
	_raiz.add_child(no)
	return no


## O chao de grama, 400 m de lado, com o material do jogo na mesma escala de
## textura do gramado (uv_tile 0,5 por metro).
func _chao() -> Node3D:
	var mi := MeshInstance3D.new()
	mi.name = "chao"
	var plano := PlaneMesh.new()
	plano.size = Vector2(400.0, 400.0)
	plano.subdivide_width = 40
	plano.subdivide_depth = 40
	mi.mesh = plano
	var m := _material(&"grama")
	if m != null:
		m = m.duplicate()
		(m as ShaderMaterial).set_shader_parameter(&"uv_tile", Vector2(200.0, 200.0))
		(m as ShaderMaterial).set_shader_parameter(&"use_snap", false)
	mi.material_override = m
	mi.position = Vector3(40.0, 0.0, 0.0)
	_raiz.add_child(mi)
	return mi


## Cada especime, sozinho, na origem. O rng e fixo por nome: a mesma arvore em
## toda execucao.
func _especime(nome: String) -> Node3D:
	var sup := {}
	var col: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(nome)
	var base := Vector3.ZERO
	match nome:
		"mangueira", "oiti", "ipe_amarelo", "ipe_rosa", "sibipiruna", "jaqueira", "abacateiro", \
				"embauba", "quaresmeira", "angico", "reseda", "pata_de_vaca", "ficus", \
				"jabuticabeira", "goiabeira":
			Vegetacao.arvore(sup, col, base, StringName(nome), 0.7, rng)
		"imperial":
			Vegetacao.palmeira(sup, col, base, true, rng)
		"coqueiro":
			Vegetacao.palmeira(sup, col, base, false, rng)
		"bananeira":
			Vegetacao.bananeira(sup, base, rng)
		"bambu":
			Vegetacao.bambu(sup, base, rng)
		"arbusto":
			var ob := Obra.new()
			Vegetacao.arbusto(ob, base, 1.6, Vegetacao.C_ARBUSTO, rng)
			ob.despejar(sup)
		"primavera":
			var ob := Obra.new()
			Vegetacao.arbusto(ob, base, 1.8, Vegetacao.C_PRIMAVERA, rng)
			ob.despejar(sup)
		"touceira":
			var ob := Obra.new()
			Vegetacao.touceira(ob, base, 1.4, rng)
			ob.despejar(sup)
		"parque_arvore":
			KitParque.arvore(sup, col, base, 0.7, rng)
		"parque_arbusto":
			KitParque.arbusto(sup, base, 1.2, rng)
		"parque_palmeira":
			KitParque.palmeira(sup, col, base, 12.0, rng)
		"sebe":
			KitParque.sebe(sup, col, base, base + Vector3(3.2, 0.0, 0.0), rng)
		"moita_flor":
			KitParque.moita_de_flor(sup, base, Vector2i(1, 0), 0.9, 0.3)
		"tufo":
			KitEstrada.tufo(sup, base, Vector2i(0, 0), 0.9, 0.3, Color.WHITE)
		"conifera":
			KitEstrada.conifera(sup, base, 0.6, rng, 0.1)
		"estrada_arvore":
			KitEstrada.arvore(sup, base, 0.5, rng)
		"mamoeiro":
			Plantas.mamoeiro(sup, base, rng)
		"capim_gordura", "espada", "taioba", "mato", "maria", "costela", "horta":
			var ob := Obra.new()
			var cel: Vector2i = {"capim_gordura": Plantas.C_CAPIM_GORDURA, "espada": Plantas.C_ESPADA,
				"taioba": Plantas.C_TAIOBA, "mato": Plantas.C_MATO, "maria": Plantas.C_MARIA,
				"costela": Plantas.C_COSTELA, "horta": Plantas.C_HORTA}[nome]
			Plantas.em_pe(ob.malha(Plantas.MAT), base, 1.2, 1.3, cel, 0.4, 3)
			ob.despejar(sup)
	return _no(sup, nome)


func _altura_de(nome: String) -> float:
	match nome:
		"moita_flor", "tufo":
			return 0.9
		"arbusto", "primavera", "parque_arbusto", "touceira":
			return 1.8
		"bananeira":
			return 4.0
		"imperial", "parque_palmeira":
			return 14.0
	return 9.0


# ------------------------------------------------------------------ fotos

func _foto() -> Image:
	for i in QUADROS:
		await process_frame
	await RenderingServer.frame_post_draw
	return _vp.get_texture().get_image()


func _gravar(img: Image, nome: String) -> void:
	if _saida.is_empty() or img == null:
		return
	img.save_png(_saida.path_join(nome + ".png"))


func _mirar(de: Vector3, para: Vector3) -> void:
	_camera.global_position = de
	var up := Vector3.UP if absf((para - de).normalized().y) < 0.95 else Vector3.FORWARD
	_camera.look_at(para, up)


## Pixels que diferem do fundo.
func _mascara(img: Image, fundo: Image) -> PackedByteArray:
	var a := img.get_data()
	var b := fundo.get_data()
	var n := img.get_width() * img.get_height()
	var m := PackedByteArray()
	m.resize(n)
	var passo := 3 if img.get_format() == Image.FORMAT_RGB8 else 4
	for k in n:
		var o := k * passo
		var d := maxi(maxi(absi(a[o] - b[o]), absi(a[o + 1] - b[o + 1])), absi(a[o + 2] - b[o + 2]))
		m[k] = 1 if d > int(LIMIAR * 255.0) else 0
	return m


func _area(m: PackedByteArray) -> int:
	var s := 0
	for v in m:
		s += v
	return s


func _registrar(linha: String) -> void:
	print(linha)
	_relatorio.append(linha)


func _criterio(nome: String, ok: bool, detalhe: String) -> void:
	_total += 1
	if ok:
		_passou += 1
	_registrar("%s %s  %s" % ["PASSA" if ok else "FALHA", nome, detalhe])


## Sem vento: a medida de cintilacao compara dois quadros, e a copa andando
## entre eles seria lida como instabilidade.
func _vento(ligado: bool) -> void:
	for m: Material in _materiais.values():
		if m is ShaderMaterial:
			var sm := m as ShaderMaterial
			if not sm.has_meta(&"vento0"):
				sm.set_meta(&"vento0", sm.get_shader_parameter(&"vento_forca"))
			sm.set_shader_parameter(&"vento_forca",
				sm.get_meta(&"vento0") if ligado else 0.0)


# ------------------------------------------------------------------ roteiro

func _rodar() -> void:
	await process_frame
	await process_frame
	RenderingServer.global_shader_parameter_set(&"psx_snap", not _moderno)
	RenderingServer.global_shader_parameter_set(&"psx_affine", not _moderno)
	RenderingServer.global_shader_parameter_set(&"psx_molhado", 0.0)
	RenderingServer.global_shader_parameter_set(&"psx_chuva", 0.0)
	_chao()
	_registrar("bancada_flora  estilo=%s  tela=%dx%d" % [
		"moderno" if _moderno else "ps1", _tam.x, _tam.y])

	if _quer("cintila"):
		await _medir_cintila("mangueira")
		await _medir_cintila("parque_arvore")
	if _quer("cobertura"):
		await _medir_cobertura("mangueira")
		await _medir_cobertura("sibipiruna")
		await _medir_cobertura("parque_arvore")
	if _quer("lados"):
		await _medir_lados("moita_flor")
		await _medir_lados("tufo")
		await _medir_lados("touceira")
	if _quer("fotos"):
		await _fotos()

	_registrar("bancada_flora: %d de %d criterios" % [_passou, _total])
	if not _saida.is_empty():
		var f := FileAccess.open(_saida.path_join("relatorio.txt"), FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(_relatorio) + "\n")
	quit(0 if _passou == _total else 1)


## F1. A camera anda um quarto de pixel de lado, sem girar.
func _medir_cintila(nome: String) -> void:
	var no := _especime(nome)
	var alto := _altura_de(nome)
	var alvo := Vector3(0.0, alto * 0.6, 0.0)
	for dist: float in [15.0, 40.0, 80.0]:
		var olho := Vector3(dist * 0.8, 1.7, dist * 0.6)
		var lado := (alvo - olho).cross(Vector3.UP).normalized()
		# Tamanho de um pixel no alvo: a altura visivel dividida pelas linhas.
		var px := 2.0 * dist * tan(deg_to_rad(_camera.fov) * 0.5) / float(_tam.y)
		_vento(false)
		no.visible = false
		_mirar(olho, alvo)
		var fundo := await _foto()
		no.visible = true
		var a := await _foto()
		_mirar(olho + lado * px * 0.25, alvo + lado * px * 0.25)
		var fundo_b := fundo
		no.visible = false
		fundo_b = await _foto()
		no.visible = true
		var b := await _foto()
		var ma := _mascara(a, fundo)
		var mb := _mascara(b, fundo_b)
		var troca := 0
		var uniao := 0
		# Cor: dentro da copa, quanto cada pixel muda de brilho. Recorte estavel
		# com textura sem mipmap passa na mascara e reprova aqui: a silhueta fica,
		# mas cada texel de folha pisca por dentro.
		var da := a.get_data()
		var db := b.get_data()
		var passo := 3 if a.get_format() == Image.FORMAT_RGB8 else 4
		var soma_cor := 0.0
		var n_cor := 0
		for k in ma.size():
			if ma[k] != mb[k]:
				troca += 1
			if ma[k] == 1 or mb[k] == 1:
				uniao += 1
			if ma[k] == 1 and mb[k] == 1:
				var o := k * passo
				soma_cor += absf((da[o] * 0.3 + da[o + 1] * 0.59 + da[o + 2] * 0.11)
					- (db[o] * 0.3 + db[o + 1] * 0.59 + db[o + 2] * 0.11))
				n_cor += 1
		var fr := float(troca) / maxf(float(uniao), 1.0)
		var cor := soma_cor / maxf(float(n_cor), 1.0)
		if dist == 40.0:
			_gravar(a, "cintila_%s_%d" % [nome, int(dist)])
		_criterio("F1 cintila %s %2d m" % [nome, int(dist)], fr < 0.12 and cor < 6.0,
			"silhueta %.1f%%  cor %.1f/255 por pixel (area %d px)" % [fr * 100.0, cor, uniao])
	_vento(true)
	no.queue_free()


## F2. Area vezes distancia ao quadrado, relativa a de 30 m.
func _medir_cobertura(nome: String) -> void:
	var no := _especime(nome)
	var alto := _altura_de(nome)
	var alvo := Vector3(0.0, alto * 0.6, 0.0)
	_vento(false)
	var ref := 0.0
	var linha := ""
	var pior := 1.0
	for dist: float in [30.0, 60.0, 100.0, 160.0]:
		var olho := Vector3(dist * 0.8, alto * 0.6, dist * 0.6)
		_mirar(olho, alvo)
		no.visible = false
		var fundo := await _foto()
		no.visible = true
		var img := await _foto()
		var area := float(_area(_mascara(img, fundo))) * dist * dist
		if ref == 0.0:
			ref = area
		var r := area / maxf(ref, 1.0)
		pior = minf(pior, r)
		linha += "  %d m: %.2f" % [int(dist), r]
	_criterio("F2 cobertura %s" % nome, pior > 0.8, linha.strip_edges())
	_vento(true)
	no.queue_free()


## F3. Oito rumos em volta da moita, a mesma distancia e altura.
func _medir_lados(nome: String) -> void:
	var no := _especime(nome)
	var alvo := Vector3(0.0, 0.45, 0.0)
	var minimo := 1 << 30
	var maximo := 0
	var linha := ""
	_vento(false)
	for k in 8:
		var a := TAU * (float(k) + 0.5) / 8.0
		var olho := Vector3(cos(a), 0.0, sin(a)) * 3.2 + Vector3(0.0, 1.0, 0.0)
		_mirar(olho, alvo)
		no.visible = false
		var fundo := await _foto()
		no.visible = true
		var img := await _foto()
		var area := _area(_mascara(img, fundo))
		minimo = mini(minimo, area)
		maximo = maxi(maximo, area)
		linha += " %d" % area
	var r := float(minimo) / maxf(float(maximo), 1.0)
	_criterio("F3 lados %s" % nome, r > 0.5, "min/max %.2f  areas%s" % [r, linha])
	_vento(true)
	no.queue_free()


## F4. As fotos para o olho: uma fileira de especies, de perto, da rua, de
## longe, contra o sol e de cima.
func _fotos() -> void:
	var nomes: Array[String] = ["mangueira", "ipe_amarelo", "sibipiruna", "oiti",
		"jaqueira", "imperial", "bananeira", "bambu", "parque_arvore", "estrada_arvore",
		"embauba", "quaresmeira", "angico", "conifera"]
	var fileira := Node3D.new()
	_raiz.add_child(fileira)
	for i in nomes.size():
		var no := _especime(nomes[i])
		no.reparent(fileira)
		no.position = Vector3(float(i) * 13.0, 0.0, 0.0)
	var baixos: Array[String] = ["arbusto", "primavera", "touceira", "parque_arbusto",
		"moita_flor", "tufo", "sebe"]
	for i in baixos.size():
		var no := _especime(baixos[i])
		no.reparent(fileira)
		no.position = Vector3(float(i) * 3.2 + 4.0, 0.0, 9.0)

	_mirar(Vector3(58.0, 1.7, 34.0), Vector3(58.0, 5.0, 0.0))
	_gravar(await _foto(), "fileira_rua")
	_mirar(Vector3(132.0, 1.7, 30.0), Vector3(138.0, 6.0, 0.0))
	_gravar(await _foto(), "mata_rua")
	_mirar(Vector3(6.0, 1.7, 17.0), Vector3(13.0, 1.2, 5.0))
	_gravar(await _foto(), "baixos_perto")
	_mirar(Vector3(3.5, 1.7, 7.5), Vector3(0.0, 6.5, 0.0))
	_gravar(await _foto(), "mangueira_perto")
	_mirar(Vector3(26.0, 1.7, 6.0), Vector3(26.0, 6.0, 0.0))
	_gravar(await _foto(), "sibipiruna_perto")
	_mirar(Vector3(58.0, 30.0, 130.0), Vector3(58.0, 4.0, 0.0))
	_gravar(await _foto(), "fileira_longe")
	_mirar(Vector3(58.0, 70.0, 40.0), Vector3(58.0, 0.0, 2.0))
	_gravar(await _foto(), "fileira_de_cima")
	# Contra o sol: o sol vem de tras da fileira, na cara da camera.
	_sol_de(Vector3(0.0, -0.42, 1.0))
	_mirar(Vector3(30.0, 1.7, 26.0), Vector3(30.0, 6.0, 0.0))
	_gravar(await _foto(), "contraluz")
	_sol_de(Vector3(-0.55, -0.62, -0.56))
	fileira.queue_free()
	await _fotos_quintal()


## Rodada 2: a fileira do quintal e da calcada nova.
func _fotos_quintal() -> void:
	var nomes: Array[String] = ["bananeira", "bambu", "mamoeiro", "jabuticabeira", "goiabeira",
		"reseda", "pata_de_vaca", "ficus", "oiti"]
	var fileira := Node3D.new()
	_raiz.add_child(fileira)
	for i in nomes.size():
		var no := _especime(nomes[i])
		no.reparent(fileira)
		no.position = Vector3(float(i) * 10.0, 0.0, 0.0)
	var baixos: Array[String] = ["capim_gordura", "espada", "taioba", "mato", "maria", "costela",
		"horta"]
	for i in baixos.size():
		var no := _especime(baixos[i])
		no.reparent(fileira)
		no.position = Vector3(float(i) * 2.2 + 3.0, 0.0, 9.0)
	_mirar(Vector3(40.0, 1.7, 30.0), Vector3(40.0, 4.0, 0.0))
	_gravar(await _foto(), "quintal_rua")
	_mirar(Vector3(10.0, 1.7, 17.0), Vector3(10.0, 0.8, 8.0))
	_gravar(await _foto(), "quintal_baixos")
	_mirar(Vector3(6.0, 1.7, 9.0), Vector3(6.0, 3.5, 0.0))
	_gravar(await _foto(), "quintal_perto")
	fileira.queue_free()
