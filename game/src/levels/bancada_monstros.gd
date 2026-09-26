## Bancada de close dos monstros da estrada: o padre principal e um romeiro,
## vestidos pelo mesmo `MonstroDaEstrada.vestir` da abertura, fotografados de
## perto em luz controlada — sem rodar os quarenta segundos da estrada.
##
##     G=.tools/Godot_v4.7.2-stable_win64_console.exe
##     $G --path game --resolution 3840x2160 res://scenes/test/bancada_monstros.tscn -- \
##        --fotos=DIR [--quem=padre|romeiro|ambos] [--luz=neutra|janela|farol|todas] \
##        [--sorriso=0..1] [--sem-capuz] [--rajada=SEGUNDOS] [--so=nome,nome] \
##        [--semente=N] [--trio [--sementes=a,b,c]] [--custo=N [--quadros=Q]] ##        [--esconder=No,No]
##
## Planos (nome do PNG = quem_plano_luz.png): `rosto_frente`, `rosto_34`,
## `rosto_perfil`, `rosto_baixo` (a 0,55 m, de pe), `janela` (a pose curvada da
## janela do carro, a 0,45 m, como a lente ve), `busto` (1,4 m), `corpo`
## (3,6 m), `lado` (3,6 m, de perfil: o braco fora do corpo), `braco` (a mao
## direita pendurada, a 0,9 m) e `farol` (14 m, como no facho). `--rajada=S`
## fotografa a 10 por segundo o plano `busto` com o tique rodando, para julgar
## pano e faixa em movimento (ver tools/mosaico_rajada.py).
##
## `--trio` poe tres romeiros de semente diferente lado a lado (a variacao da
## cabeca e dos bracos por semente) e fotografa `trio_perto` (2,8 m),
## `trio_corpo` (5,5 m), `trio_fogo` (9 m, no fogo) e `trio_farol` (14 m).
## `--rajada-plano=braco` poe a rajada na mao (os dedos abrem e fecham pela
## chamada `dedos` que os `BracosPodres` deixam no corpo); `--sem-tique` deixa
## o corpo parado na rajada.
##
## `--custo=N` nao fotografa: veste N romeiros num leque de 3 a 9 m da lente, no
## farol e no fogo, e imprime o custo — ms de vestir (rosto e bracos a parte),
## triangulos, materiais distintos e nos com `_process` por peca, e o quadro
## (CPU e GPU medidos pelo viewport) por Q quadros. O A/B e pelas bandeiras
## `--romeiro-faixa` (o rosto velho) e `--bracos-de-caixa` (sem bracos podres),
## sempre em par, uma rodada logo apos a outra. `--custo-dedos` chama a
## `dedos` dos `BracosPodres` todo quadro, nas duas maos de todos (o custo da
## chamada e das formas no esqueleto).
##
## A luz aqui nao e a da estrada. `neutra` e para julgar forma e textura (chave
## branca a 45 graus e um contra); `janela` imita o vermelho do painel e o fogo
## do capo; `farol` e o facho de frente na nevoa. A palavra final e sempre na
## estrada (`--ver-estrada`, INTRO-PADRE/HANDOFF.md).
##
## Imprime `[bancada_monstros] chave=valor`.
class_name BancadaMonstros
extends Node3D

const PLANOS := ["rosto_frente", "rosto_34", "rosto_perfil", "rosto_baixo", "janela",
	"busto", "corpo", "lado", "braco", "farol"]
const PLANOS_TRIO := ["trio_perto", "trio_corpo", "trio_fogo", "trio_farol"]
const LUZES := ["neutra", "janela", "farol"]
## O padre e os romeiros, como a abertura os monta (`AberturaEstrada`).
const PADRE_ALTURA := 1.95
const ROMEIRO_ALTURA := 1.82
const ENTRE_ELES := 4.0
## O trio: sementes, alturas (as da `AberturaEstrada.FIGURAS`) e o vao entre eles.
const TRIO_SEMENTES := [1, 6, 11]
const TRIO_ALTURAS := [1.82, 1.78, 1.88]
const TRIO_VAO := 1.25
## Quadros de espera antes da primeira foto (sombra, shader, pano assentando) e
## entre duas fotos.
const AQUECE := 45
const ENTRE_FOTOS := 4
## A medida de custo: quadros de aquecimento e o leque (colunas, vao, fileiras).
const CUSTO_AQUECE := 90
const CUSTO_COLUNAS := 6
const CUSTO_VAO := Vector2(1.3, 2.2)

var _pasta := ""
var _quem := "ambos"
var _luzes: Array = ["neutra"]
var _sorriso := 0.35
var _sorriso_dado := false
var _sem_capuz := false
var _rajada := 0.0
var _so: PackedStringArray = []
var _semente := 1
var _trio := false
var _sementes: Array = TRIO_SEMENTES.duplicate()
var _custo := 0
var _quadros_custo := 240
var _esconder: PackedStringArray = []
var _rajada_plano := "busto"
var _sem_tique := false
var _custo_dedos := false

var _cam: Camera3D
var _luz_chave: DirectionalLight3D
var _luz_contra: DirectionalLight3D
var _luz_painel: OmniLight3D
var _luz_fogo: OmniLight3D
var _luz_farol: SpotLight3D
var _ambiente: Environment
var _elenco: Dictionary = {}
var _tiques: Array[TiqueMacabro] = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			_pasta = a.trim_prefix("--fotos=")
		elif a.begins_with("--quem="):
			_quem = a.trim_prefix("--quem=")
		elif a.begins_with("--luz="):
			var l := a.trim_prefix("--luz=")
			_luzes = LUZES.duplicate() if l == "todas" else [l]
		elif a.begins_with("--sorriso="):
			_sorriso = float(a.trim_prefix("--sorriso="))
			_sorriso_dado = true
		elif a == "--sem-capuz":
			_sem_capuz = true
		elif a.begins_with("--rajada="):
			_rajada = float(a.trim_prefix("--rajada="))
		elif a.begins_with("--so="):
			_so = a.trim_prefix("--so=").split(",")
		elif a.begins_with("--semente="):
			_semente = int(a.trim_prefix("--semente="))
		elif a == "--trio":
			_trio = true
		elif a.begins_with("--sementes="):
			_sementes = []
			for s: String in a.trim_prefix("--sementes=").split(","):
				_sementes.append(int(s))
		elif a.begins_with("--custo="):
			_custo = int(a.trim_prefix("--custo="))
		elif a.begins_with("--quadros="):
			_quadros_custo = int(a.trim_prefix("--quadros="))
		elif a == "--custo-dedos":
			_custo_dedos = true
		elif a == "--sem-tique":
			_sem_tique = true
		elif a.begins_with("--rajada-plano="):
			_rajada_plano = a.trim_prefix("--rajada-plano=")
		elif a.begins_with("--esconder="):
			_esconder = a.trim_prefix("--esconder=").split(",")
	if not _pasta.is_empty():
		DirAccess.make_dir_recursive_absolute(_pasta)
	_montar_palco()
	if _custo > 0:
		_medir_custo()
		return
	if _trio:
		for k in _sementes.size():
			var x := (float(k) - float(_sementes.size() - 1) * 0.5) * TRIO_VAO
			_elenco["romeiro%d" % int(_sementes[k])] = _monstro("Romeiro%d" % k,
				int(_sementes[k]), float(TRIO_ALTURAS[k % TRIO_ALTURAS.size()]), false,
				Vector3(x, 0, 0))
		_rodar_trio()
		return
	if _quem != "romeiro":
		_elenco["padre"] = _monstro("Padre", 0, PADRE_ALTURA, true, Vector3.ZERO)
	if _quem != "padre":
		var x := ENTRE_ELES if _quem == "ambos" else 0.0
		_elenco["romeiro"] = _monstro("Romeiro", _semente, ROMEIRO_ALTURA, false,
			Vector3(x, 0, 0))
	_rodar()


func _process(delta: float) -> void:
	# O tique DEPOIS do animar, como na estrada: antes, o animar do quadro
	# escrevia a pose por cima e a rajada nao mostrava tique nenhum.
	for c: Corpo in _elenco.values():
		c.dominado = false
		c.animar(0.0, delta)
	for t in _tiques:
		t.passo(delta)


func _monstro(nome: String, i: int, altura: float, grande: bool, onde: Vector3) -> Corpo:
	var c := Corpo.new()
	c.name = nome
	add_child(c)
	var ombro := AberturaEstrada.PADRE_OMBRO if grande else AberturaEstrada.OMBRO_ENCAPUZADO
	c.montar(AberturaEstrada._aparencia_de_encapuzado(i, altura, ombro, grande))
	c.jeito = {"curvatura": 0.05, "cabeca": 0.14} if grande \
		else {"curvatura": 0.16, "cabeca": 0.22}
	var capuz := MonstroDaEstrada.vestir(c, i, ombro / 0.42, grande)
	if capuz != null:
		# O romeiro fica no sorriso que a semente deu, como na estrada, a nao
		# ser que a linha de comando peca outro.
		if grande or _sorriso_dado:
			capuz.sorriso = _sorriso
		if _sem_capuz:
			if capuz.pano != null:
				capuz.pano.visible = false
	c.position = onde
	# De frente para +Z, onde a camera fica: a frente do Corpo e -Z.
	c.basis = Basis(Vector3.UP, PI)
	# Diagnostico: some com as pecas pelo nome do no (`--esconder=Pele,Murca`).
	for nome_no: String in _esconder:
		for n: Node in c.find_children(nome_no, "", true, false):
			if n is Node3D:
				(n as Node3D).visible = false
	# O braco no repouso: ate onde a ponta dos dedos desce e onde fica a mao,
	# contra o joelho e a batina.
	var bd := c.esqueleto().get_node_or_null("BracoPodreD") as MeshInstance3D
	if bd != null and bd.mesh != null:
		var cx := bd.mesh.get_aabb()
		var s := altura / Corpo.ALTURA_REF
		print("[bancada_monstros] %s braco_repouso ponta_y=%.3f joelho_y=%.3f x=%.3f..%.3f ombro_x=%.3f formas=%d" % [
			nome, cx.position.y, Corpo.Y_JOELHO * s, cx.position.x, cx.end.x,
			absf(c.esqueleto().get_bone_global_rest(Corpo.Osso.BRACO_D).origin.x),
			bd.get_blend_shape_count()])
	var rosto: Variant = c.get_meta(&"rosto") if c.has_meta(&"rosto") else null
	print("[bancada_monstros] %s rosto=%s" % [nome,
		(rosto as Node).get_class() + ":" + String((rosto as Node).name) if rosto != null
		else "nao (buraco do capuz)"])
	return c


func _montar_palco() -> void:
	var mundo := WorldEnvironment.new()
	_ambiente = Environment.new()
	_ambiente.background_mode = Environment.BG_COLOR
	_ambiente.background_color = Color(0.012, 0.013, 0.016)
	_ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_ambiente.ambient_light_color = Color(0.10, 0.11, 0.13)
	_ambiente.ambient_light_energy = 0.35
	_ambiente.tonemap_mode = Environment.TONE_MAPPER_AGX
	_ambiente.glow_enabled = true
	_ambiente.glow_intensity = 0.5
	_ambiente.glow_hdr_threshold = 1.2
	_ambiente.ssao_enabled = true
	mundo.environment = _ambiente
	add_child(mundo)

	var chao := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(40, 40)
	chao.mesh = plano
	var barro := StandardMaterial3D.new()
	barro.albedo_color = Color(0.09, 0.07, 0.055)
	barro.roughness = 0.55
	chao.material_override = barro
	add_child(chao)

	_luz_chave = DirectionalLight3D.new()
	_luz_chave.rotation_degrees = Vector3(-35, 35, 0)
	_luz_chave.light_energy = 1.4
	_luz_chave.shadow_enabled = true
	add_child(_luz_chave)
	_luz_contra = DirectionalLight3D.new()
	_luz_contra.rotation_degrees = Vector3(-20, 200, 0)
	_luz_contra.light_color = Color(0.7, 0.8, 1.0)
	_luz_contra.light_energy = 0.6
	add_child(_luz_contra)

	_luz_painel = OmniLight3D.new()
	_luz_painel.light_color = AberturaEstrada.LUZ_ALERTA
	_luz_painel.omni_range = 1.6
	_luz_painel.light_energy = 1.6
	add_child(_luz_painel)
	_luz_fogo = OmniLight3D.new()
	_luz_fogo.light_color = Color(1.0, 0.45, 0.15)
	_luz_fogo.omni_range = 6.0
	_luz_fogo.light_energy = 2.2
	_luz_fogo.shadow_enabled = true
	add_child(_luz_fogo)
	_luz_farol = SpotLight3D.new()
	_luz_farol.light_color = Color(1.0, 0.93, 0.8)
	_luz_farol.spot_range = 40.0
	_luz_farol.spot_angle = 18.0
	_luz_farol.light_energy = 14.0
	_luz_farol.shadow_enabled = true
	add_child(_luz_farol)

	_cam = Camera3D.new()
	_cam.fov = 55.0
	_cam.near = 0.02
	add_child(_cam)
	_cam.make_current()


func _acender(luz: String, alvo: Vector3) -> void:
	_luz_chave.visible = luz == "neutra"
	_luz_contra.visible = luz == "neutra"
	_luz_painel.visible = luz == "janela"
	_luz_fogo.visible = luz == "janela"
	_luz_farol.visible = luz == "farol"
	_ambiente.ambient_light_energy = 0.35 if luz == "neutra" else 0.06
	var para_cam := (_cam.global_position - alvo)
	para_cam.y = 0.0
	para_cam = para_cam.normalized()
	var lado := para_cam.cross(Vector3.UP)
	# O painel: embaixo e um pouco ao lado da lente, como o vermelho do carro.
	_luz_painel.global_position = alvo + para_cam * 0.55 + lado * 0.15 + Vector3.DOWN * 0.35
	# O fogo do capo: de lado e de baixo, longe.
	_luz_fogo.global_position = alvo - lado * 2.5 + para_cam * 1.5 + Vector3.DOWN * 0.9
	# O farol: da altura do carro, atras da lente.
	_luz_farol.global_position = Vector3(alvo.x, 0.75, _cam.global_position.z + 2.0)
	_luz_farol.look_at(alvo + Vector3.DOWN * 0.4, Vector3.UP)


## Onde fica a cara de `c`, no mundo (o mesmo ponto que a abertura mira).
static func rosto_de(c: Corpo) -> Vector3:
	var esq := c.esqueleto()
	var cab := esq.global_transform * esq.get_bone_global_pose(Corpo.Osso.CABECA)
	return cab.origin + cab.basis.orthonormalized().y * 0.11


## O punho direito de `c`, no mundo (o fim do osso do antebraco).
static func punho_de(c: Corpo) -> Vector3:
	var esq := c.esqueleto()
	var ante := esq.global_transform * esq.get_bone_global_pose(Corpo.Osso.ANTEBRACO_D)
	var s := c.altura() / Corpo.ALTURA_REF
	return ante * Vector3(0.0, (Corpo.Y_PUNHO - Corpo.Y_COTOVELO) * s, 0.0)


func _posar(c: Corpo, plano: String) -> void:
	var janela := plano == "janela"
	c.agachado = janela
	c.inclinacao = Vector2(0.0, AberturaEstrada.PADRE_JANELA_CURVA) if janela else Vector2.ZERO
	c.olhar_lateral(0.0, AberturaEstrada.PADRE_JANELA_PITCH if janela else 0.0)
	for _i in 30:
		c.animar(0.0, 0.05)


func _enquadrar(c: Corpo, plano: String) -> Vector3:
	var r := rosto_de(c)
	var base := c.global_position
	var frente := Vector3.BACK
	var alvo := r
	var de := r + frente * 0.55
	match plano:
		"rosto_34":
			de = r + frente.rotated(Vector3.UP, deg_to_rad(35)) * 0.55
		"rosto_perfil":
			de = r + frente.rotated(Vector3.UP, deg_to_rad(80)) * 0.55
		"rosto_baixo":
			de = r + frente * 0.5 + Vector3.DOWN * 0.3
		"janela":
			de = r + frente * 0.45 + Vector3.DOWN * 0.05
		"busto":
			alvo = r + Vector3.DOWN * 0.3
			de = alvo + frente * 1.4
		"corpo":
			alvo = base + Vector3.UP * 1.0
			de = alvo + frente * 3.6
		"lado":
			alvo = base + Vector3.UP * 1.0
			de = alvo + Vector3.RIGHT * 3.6
		"braco":
			# A mao direita dele fica a esquerda da lente (ele olha para +Z).
			alvo = punho_de(c) + Vector3.DOWN * 0.14
			de = alvo + frente.rotated(Vector3.UP, deg_to_rad(-30)) * 0.9 + Vector3.UP * 0.1
		"farol":
			alvo = base + Vector3.UP * 1.1
			de = Vector3(base.x, 1.15, base.z + 14.0)
	_cam.global_position = de
	_cam.look_at(alvo, Vector3.UP)
	return alvo


func _quadros(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	if _pasta.is_empty():
		return
	var img := get_viewport().get_texture().get_image()
	var caminho := _pasta.path_join(nome + ".png")
	img.save_png(caminho)
	print("[bancada_monstros] foto=%s" % caminho)


func _rodar() -> void:
	await _quadros(AQUECE)
	for quem: String in _elenco:
		var c: Corpo = _elenco[quem]
		# So quem esta na foto fica visivel: o outro fazia sombra e fundo.
		for outro: Corpo in _elenco.values():
			outro.visible = outro == c
		for plano: String in PLANOS:
			if not _so.is_empty() and not _so.has(plano):
				continue
			_posar(c, plano)
			var alvo := _enquadrar(c, plano)
			for luz: String in _luzes:
				_acender("farol" if plano == "farol" else luz, alvo)
				await _quadros(ENTRE_FOTOS)
				await _foto("%s_%s_%s" % [quem, plano, luz])
				if plano == "farol":
					break
		if _rajada > 0.0:
			await _rajada_de(quem, c)
	print("[bancada_monstros] fim")
	get_tree().quit()


## Os tres lado a lado, e depois o rosto e o braco de cada um de perto.
func _rodar_trio() -> void:
	await _quadros(AQUECE)
	for c: Corpo in _elenco.values():
		_posar(c, "corpo")
	for plano: String in PLANOS_TRIO:
		if not _so.is_empty() and not _so.has(plano):
			continue
		var alvo := Vector3(0.0, 1.05, 0.0)
		var de := Vector3(0.0, 1.35, 2.8)
		var luzes: Array = _luzes
		match plano:
			"trio_corpo":
				de = Vector3(0.0, 1.3, 5.5)
				alvo = Vector3(0.0, 0.95, 0.0)
			"trio_fogo":
				de = Vector3(1.5, 1.2, 9.0)
				alvo = Vector3(0.0, 1.0, 0.0)
				luzes = ["janela"]
			"trio_farol":
				de = Vector3(0.0, 1.15, 14.0)
				alvo = Vector3(0.0, 1.1, 0.0)
				luzes = ["farol"]
		_cam.global_position = de
		_cam.look_at(alvo, Vector3.UP)
		for luz: String in luzes:
			_acender(luz, alvo)
			if plano == "trio_fogo":
				# O fogo do capo de lado e perto deles, como na estrada.
				_luz_fogo.global_position = Vector3(-3.2, 0.5, 2.2)
				_luz_fogo.omni_range = 9.0
				_luz_painel.visible = false
			await _quadros(ENTRE_FOTOS)
			await _foto("trio_%s_%s" % [plano.trim_prefix("trio_"), luz])
			_luz_fogo.omni_range = 6.0
	for quem: String in _elenco:
		var c: Corpo = _elenco[quem]
		for plano: String in ["rosto_34", "braco"]:
			if not _so.is_empty() and not _so.has(plano):
				continue
			_posar(c, plano)
			var alvo := _enquadrar(c, plano)
			for luz: String in _luzes:
				_acender(luz, alvo)
				await _quadros(ENTRE_FOTOS)
				await _foto("%s_%s_%s" % [quem, plano, luz])
	if _rajada > 0.0:
		var c: Corpo = _elenco.values()[0]
		await _rajada_de("trio", c, true)
	print("[bancada_monstros] fim")
	get_tree().quit()


func _rajada_de(quem: String, c: Corpo, trio: bool = false) -> void:
	_posar(c, _rajada_plano)
	var alvo := _enquadrar(c, _rajada_plano)
	if trio:
		alvo = Vector3(0.0, 1.05, 0.0)
		_cam.global_position = Vector3(0.0, 1.35, 3.4)
		_cam.look_at(alvo, Vector3.UP)
	_acender(_luzes[0], alvo)
	var quem_tique: Array = _elenco.values() if trio else [c]
	var novos: Array[TiqueMacabro] = []
	for k in quem_tique.size():
		if _sem_tique:
			break
		var t := TiqueMacabro.new(quem_tique[k] as Corpo, 7 + k * 5, TiqueMacabro.Modo.PADRE
			if quem == "padre" else TiqueMacabro.Modo.FUNDO)
		novos.append(t)
		_tiques.append(t)
	var pasta := _pasta.path_join("rajada_" + quem)
	DirAccess.make_dir_recursive_absolute(pasta)
	var t := 0.0
	var proxima := 0.0
	var passo := 0.1
	# Os dedos: se o vestir deixou a chamada (`BracosPodres`), eles abrem e
	# fecham devagar, cada mao num ritmo, para a rajada mostrar a pele dos dedos.
	while t < _rajada:
		await get_tree().process_frame
		t += get_process_delta_time()
		for k in quem_tique.size():
			var cc := quem_tique[k] as Corpo
			if cc.has_meta(&"dedos"):
				var dedos := cc.get_meta(&"dedos") as Callable
				dedos.call(-1.0, 0.5 + 0.5 * sin(t * 1.3 + float(k)))
				dedos.call(1.0, 0.5 + 0.5 * sin(t * 0.9 + 2.0 + float(k)))
		if t >= proxima:
			proxima += passo
			await RenderingServer.frame_post_draw
			if not _pasta.is_empty():
				get_viewport().get_texture().get_image().save_png(
					pasta.path_join("r_%.2f.png" % t))
	for tq in novos:
		_tiques.erase(tq)


# --- custo ------------------------------------------------------------------

## Veste `_custo` romeiros num leque de frente para a lente, no farol e no fogo,
## e imprime o que cada peca custa: vestir, triangulos, materiais, `_process`,
## e o quadro.
func _medir_custo() -> void:
	var ms_rosto: Array[float] = []
	var ms_bracos: Array[float] = []
	var ms_total: Array[float] = []
	var ombro := AberturaEstrada.OMBRO_ENCAPUZADO
	for k in _custo:
		var i := 1 + k
		var c := Corpo.new()
		c.name = "Custo%d" % k
		add_child(c)
		var alt := float(TRIO_ALTURAS[k % TRIO_ALTURAS.size()])
		c.montar(AberturaEstrada._aparencia_de_encapuzado(i, alt, ombro, false))
		c.jeito = {"curvatura": 0.16, "cabeca": 0.22}
		var t0 := Time.get_ticks_usec()
		MonstroDaEstrada.vestir(c, i, ombro / 0.42, false)
		ms_total.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		var col := k % CUSTO_COLUNAS
		var fil := k / CUSTO_COLUNAS
		c.position = Vector3((float(col) - float(CUSTO_COLUNAS - 1) * 0.5) * CUSTO_VAO.x
			+ 0.4 * float(fil % 2), 0.0, -3.0 - float(fil) * CUSTO_VAO.y)
		c.basis = Basis(Vector3.UP, PI)
		_elenco["custo%d" % k] = c
	# O rosto e os bracos sozinhos, em corpos a mais fora do leque: o capuz e o
	# pano nao mudam no A/B. O ultimo corpo tem altura nova: a malha dos bracos
	# e montada ali (o primeiro vestir de cada altura), os outros pegam a pronta.
	var ms_bracos_novo := 0.0
	for k in 4:
		var c := Corpo.new()
		add_child(c)
		var alt := float(TRIO_ALTURAS[k % TRIO_ALTURAS.size()]) if k < 3 else 1.93
		c.montar(AberturaEstrada._aparencia_de_encapuzado(90 + k, alt, ombro, false))
		c.set_meta(&"bracos_de_fora", true)
		var capuz := CapuzMacabro.vestir(c, 90 + k, ombro / 0.42, true)
		var t0 := Time.get_ticks_usec()
		var r := MonstroDaEstrada.rosto_de_fundo(c, capuz, 90 + k)
		if r != null:
			c.set_meta(&"rosto", r)
		var t1 := Time.get_ticks_usec()
		BracosPodres.vestir(c)
		var t2 := Time.get_ticks_usec()
		ms_rosto.append(float(t1 - t0) / 1000.0 if r != null else -1.0)
		if k < 3:
			ms_bracos.append(float(t2 - t1) / 1000.0)
		else:
			ms_bracos_novo = float(t2 - t1) / 1000.0
		c.queue_free()
	_cam.global_position = Vector3(0.0, 1.45, 3.5)
	_cam.look_at(Vector3(0.0, 1.0, -4.0), Vector3.UP)
	_acender("farol", Vector3(0.0, 1.0, -4.0))
	_luz_fogo.visible = true
	_luz_fogo.omni_range = 9.0
	_luz_fogo.global_position = Vector3(-3.5, 0.4, -2.0)

	var rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	# Sem vsync: com ele o quadro mede o monitor (memoria vsync-esconde-a-medida).
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _quadros(CUSTO_AQUECE)
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var quadro: Array[float] = []
	var antes := Time.get_ticks_usec()
	var us_dedos := 0.0
	var t_dedos := 0.0
	for _q in _quadros_custo:
		if _custo_dedos:
			# Como o andar vai chamar: todo quadro, as duas maos de todos.
			t_dedos += 1.0 / 60.0
			var td := Time.get_ticks_usec()
			var k := 0
			for c: Corpo in _elenco.values():
				var dedos := c.get_meta(&"dedos", Callable()) as Callable
				if dedos.is_valid():
					dedos.call(-1.0, 0.5 + 0.5 * sin(t_dedos * 1.7 + float(k)))
					dedos.call(1.0, 0.5 + 0.5 * sin(t_dedos * 1.1 + float(k) * 2.0))
				k += 1
			us_dedos += float(Time.get_ticks_usec() - td)
		await get_tree().process_frame
		var agora := Time.get_ticks_usec()
		quadro.append(float(agora - antes) / 1000.0)
		antes = agora
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	# O `_process` de cada rosto que tem um (a faixa simula as pontas), chamado a
	# mao: TIME_PROCESS e o pior quadro do segundo, nao serve para isto.
	var us_rosto := 0.0
	var com_process := 0
	for c: Corpo in _elenco.values():
		var r := c.get_meta(&"rosto", null) as Node
		if r == null or not r.is_processing():
			continue
		com_process += 1
		var t0 := Time.get_ticks_usec()
		for _k in 50:
			r._process(1.0 / 60.0)
		us_rosto += float(Time.get_ticks_usec() - t0) / 50.0
	var prim := RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var chamadas := RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)

	var pecas := {"rosto": {}, "bracos": {}, "pano": {}, "corpo": {}, "outro": {}}
	for p: String in pecas:
		pecas[p] = {"tris": 0, "mats": {}, "nos": 0, "process": 0}
	for c: Corpo in _elenco.values():
		_contar(c, c, pecas)
	print("[bancada_monstros] custo placa=%s romeiros=%d" % [
		RenderingServer.get_video_adapter_name(), _custo])
	print("[bancada_monstros] custo vestir_ms total_1o=%.2f total_med=%.2f bracos_prontos=%s bracos_altura_nova=%.2f rosto=%s" % [
		ms_total[0], _mediana(ms_total.slice(1)), str(ms_bracos), ms_bracos_novo,
		str(ms_rosto)])
	for p: String in pecas:
		var d: Dictionary = pecas[p]
		print("[bancada_monstros] custo peca=%s tris=%d tris_por_romeiro=%d materiais=%d nos=%d com_process=%d" % [
			p, d["tris"], int(d["tris"]) / maxi(_custo, 1), (d["mats"] as Dictionary).size(),
			d["nos"], d["process"]])
	print("[bancada_monstros] custo quadro_med=%.2f quadro_p10=%.2f gpu_med=%.2f gpu_p10=%.2f cpu_render_med=%.2f primitivas=%d chamadas=%d" % [
		_mediana(quadro), _percentil(quadro, 0.1), _mediana(gpu), _percentil(gpu, 0.1),
		_mediana(cpu), prim, chamadas])
	print("[bancada_monstros] custo rosto_process us_por_quadro_todos=%.1f rostos_com_process=%d dedos_us_por_quadro_todos=%.1f" % [
		us_rosto, com_process, us_dedos / float(_quadros_custo)])
	if not _pasta.is_empty():
		await _foto("custo")
	print("[bancada_monstros] fim")
	get_tree().quit()


## Soma triangulos, materiais e nos de `n` (e filhos) na peca de cada um.
func _contar(n: Node, c: Corpo, pecas: Dictionary) -> void:
	var peca := _peca_de(n, c)
	var d: Dictionary = pecas[peca]
	d["nos"] = int(d["nos"]) + 1
	if n.is_processing() or n.is_physics_processing():
		d["process"] = int(d["process"]) + 1
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null and mi.visible:
		var mats: Dictionary = d["mats"]
		for s in mi.mesh.get_surface_count():
			var am := mi.mesh as ArrayMesh
			if am != null:
				var ni := am.surface_get_array_index_len(s)
				d["tris"] = int(d["tris"]) + (ni if ni > 0 else am.surface_get_array_len(s)) / 3
			var m := mi.material_override if mi.material_override != null \
				else mi.get_active_material(s)
			if m != null:
				mats[m.get_instance_id()] = true
	for f in n.get_children():
		_contar(f, c, pecas)


## A peca de um no: pelo caminho dele dentro do corpo.
static func _peca_de(n: Node, c: Corpo) -> String:
	var caminho := String(c.get_path_to(n))
	if caminho.contains("Cabeca") or caminho.contains("Faixas") or caminho.contains("Rosto"):
		return "rosto"
	if caminho.contains("BracoPodre"):
		return "bracos"
	if n is PanoGPU or caminho.contains("PanoGPU") or caminho.contains("Pano") \
			or caminho.contains("Murca") or caminho.contains("Batina"):
		return "pano"
	if caminho.contains("Pele") or n == c:
		return "corpo"
	return "outro"


static func _mediana(v: Array) -> float:
	return _percentil(v, 0.5)


static func _percentil(v: Array, p: float) -> float:
	if v.is_empty():
		return 0.0
	var s := v.duplicate()
	s.sort()
	return float(s[clampi(int(p * float(s.size() - 1)), 0, s.size() - 1)])
