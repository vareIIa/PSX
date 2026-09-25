## Bancada de close dos monstros da estrada: o padre principal e um romeiro,
## vestidos pelo mesmo `MonstroDaEstrada.vestir` da abertura, fotografados de
## perto em luz controlada — sem rodar os quarenta segundos da estrada.
##
##     G=.tools/Godot_v4.7.2-stable_win64_console.exe
##     $G --path game --resolution 3840x2160 res://scenes/test/bancada_monstros.tscn -- \
##        --fotos=DIR [--quem=padre|romeiro|ambos] [--luz=neutra|janela|farol|todas] \
##        [--sorriso=0..1] [--sem-capuz] [--rajada=SEGUNDOS] [--so=nome,nome]
##
## Planos (nome do PNG = quem_plano_luz.png): `rosto_frente`, `rosto_34`,
## `rosto_perfil`, `rosto_baixo` (a 0,55 m, de pe), `janela` (a pose curvada da
## janela do carro, a 0,45 m, como a lente ve), `busto` (1,4 m), `corpo`
## (3,6 m) e `farol` (14 m, como no facho). `--rajada=S` fotografa a 10 por
## segundo o plano `busto` com o tique rodando, para julgar pano e faixa em
## movimento (ver tools/mosaico_rajada.py).
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
	"busto", "corpo", "farol"]
const LUZES := ["neutra", "janela", "farol"]
## O padre e os romeiros, como a abertura os monta (`AberturaEstrada`).
const PADRE_ALTURA := 1.95
const ROMEIRO_ALTURA := 1.82
const ENTRE_ELES := 4.0
## Quadros de espera antes da primeira foto (sombra, shader, pano assentando) e
## entre duas fotos.
const AQUECE := 45
const ENTRE_FOTOS := 4

var _pasta := ""
var _quem := "ambos"
var _luzes: Array = ["neutra"]
var _sorriso := 0.35
var _sem_capuz := false
var _rajada := 0.0
var _so: PackedStringArray = []

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
		elif a == "--sem-capuz":
			_sem_capuz = true
		elif a.begins_with("--rajada="):
			_rajada = float(a.trim_prefix("--rajada="))
		elif a.begins_with("--so="):
			_so = a.trim_prefix("--so=").split(",")
	if not _pasta.is_empty():
		DirAccess.make_dir_recursive_absolute(_pasta)
	_montar_palco()
	if _quem != "romeiro":
		_elenco["padre"] = _monstro("Padre", 0, PADRE_ALTURA, true, Vector3.ZERO)
	if _quem != "padre":
		var x := ENTRE_ELES if _quem == "ambos" else 0.0
		_elenco["romeiro"] = _monstro("Romeiro", 1, ROMEIRO_ALTURA, false, Vector3(x, 0, 0))
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
		capuz.sorriso = _sorriso
		if _sem_capuz:
			if capuz.pano != null:
				capuz.pano.visible = false
	c.position = onde
	# De frente para +Z, onde a camera fica: a frente do Corpo e -Z.
	c.basis = Basis(Vector3.UP, PI)
	var rosto: Variant = c.get_meta(&"rosto") if c.has_meta(&"rosto") else null
	print("[bancada_monstros] %s rosto=%s" % [nome,
		"sim" if rosto != null else "nao (buraco do capuz)"])
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


func _rajada_de(quem: String, c: Corpo) -> void:
	_posar(c, "busto")
	var alvo := _enquadrar(c, "busto")
	_acender(_luzes[0], alvo)
	var tique := TiqueMacabro.new(c, 7, TiqueMacabro.Modo.PADRE if quem == "padre"
		else TiqueMacabro.Modo.FUNDO)
	_tiques.append(tique)
	var pasta := _pasta.path_join("rajada_" + quem)
	DirAccess.make_dir_recursive_absolute(pasta)
	var t := 0.0
	var k := 0
	var passo := 0.1
	var proxima := 0.0
	while t < _rajada:
		await get_tree().process_frame
		t += get_process_delta_time()
		if t >= proxima:
			proxima += passo
			await RenderingServer.frame_post_draw
			if not _pasta.is_empty():
				get_viewport().get_texture().get_image().save_png(
					pasta.path_join("r_%.2f.png" % t))
			k += 1
	_tiques.erase(tique)
