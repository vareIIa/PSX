## Bancada da manga comprida do braco AAA do padre (`MangaDoPadre`): os dois
## bracos num ombro de dois metros, do lado de fora de um vidro, nas poses das
## janelas da abertura (pendurado, as maos no vidro na altura da cara, as maos
## no vidro alto por cima da cabeca, o braco erguido no ar e a mao na lente), e
## a lente de dentro do carro e de lado.
##
##     G=.tools/Godot_v4.7.2-stable_win64_console.exe
##     $G --path game --resolution 1920x1080 res://scenes/test/bancada_manga_padre.tscn -- \
##        --fotos=DIR [--so=plano,plano] [--rajada] [--braco-sem-manga]
##
## Planos: `pendurado`, `vidro_cara`, `vidro_alto`, `erguido`, `cara` e `sobe`
## (a mao sai de pendurada para o vidro alto; com `--rajada`, 10 quadros por
## segundo). Cada foto sai de dentro (`_dentro`) e de lado (`_lado`).
extends Node3D

## Os ombros do padre de dois metros, e o vidro (z) com a palma encostada.
const OMBRO := Vector3(0.21, 1.52, 0.0)
const VIDRO_Z := 0.36
const PALMA_NO_VIDRO := 0.012
## Quadros para o pano assentar em cada pose.
const ASSENTA := 70

var _pasta := ""
var _so: PackedStringArray = []
var _rajada := false
var _cam: Camera3D
var _bracos: Array[BracoDoPadre] = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			_pasta = a.trim_prefix("--fotos=")
		elif a.begins_with("--so="):
			_so = a.trim_prefix("--so=").split(",")
		elif a == "--rajada":
			_rajada = true
	DirAccess.make_dir_recursive_absolute(_pasta)
	var amb := WorldEnvironment.new()
	amb.environment = Environment.new()
	amb.environment.background_mode = Environment.BG_COLOR
	amb.environment.background_color = Color(0.03, 0.035, 0.045)
	amb.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	amb.environment.ambient_light_color = Color(0.16, 0.17, 0.2)
	amb.environment.ambient_light_energy = 1.0
	amb.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(amb)
	# O farol: de baixo e da frente, quente, com sombra (o carro batido).
	var farol := SpotLight3D.new()
	farol.position = Vector3(0.6, 0.9, 2.6)
	farol.look_at_from_position(farol.position, Vector3(0.0, 1.5, 0.0))
	farol.spot_range = 8.0
	farol.spot_angle = 35.0
	farol.light_energy = 14.0
	farol.light_color = Color(1.0, 0.86, 0.66)
	farol.shadow_enabled = true
	add_child(farol)
	# O ceu da noite por tras, frio e sem sombra.
	var ceu := DirectionalLight3D.new()
	ceu.rotation_degrees = Vector3(-40.0, 160.0, 0.0)
	ceu.light_energy = 0.35
	ceu.light_color = Color(0.6, 0.7, 0.95)
	add_child(ceu)
	_cam = Camera3D.new()
	_cam.fov = 60.0
	_cam.near = 0.01
	add_child(_cam)
	_cam.current = true
	for direita: bool in [true, false]:
		var b := BracoDoPadre.novo("Braco%s" % ("D" if direita else "E"), direita)
		add_child(b)
		b.visible = true
		b.layers = 1
		b.ombro = _ombro(b)
		b.dedos_vivos = 1.0
		# Depuracao: so a manga, sem a pele do braco.
		if OS.get_cmdline_user_args().has("--manga-so-pano"):
			b._pele_mi.visible = false
		_bracos.append(b)
	_rodar()


func _process(delta: float) -> void:
	for b: BracoDoPadre in _bracos:
		b.passo(delta)


func _lado(b: BracoDoPadre) -> float:
	return 1.0 if b.direita else -1.0


func _ombro(b: BracoDoPadre) -> Vector3:
	return Vector3(OMBRO.x * _lado(b), OMBRO.y, OMBRO.z)


func _pendurado(b: BracoDoPadre) -> Dictionary:
	b.polo = Vector3(0.0, -0.3, -1.0).normalized()
	return BracoVivo.pega(_ombro(b) + Vector3(0.04 * _lado(b), -0.60, 0.07), Vector3.DOWN,
		Vector3(_lado(b), 0.0, 0.0), &"relaxada")


## A palma no vidro em (x, y), os dedos para cima e para fora, o dorso para o
## padre (como `PadresNasJanelas`: pega(onde, d, n)).
func _no_vidro(b: BracoDoPadre, x: float, y: float) -> Dictionary:
	var onde := Vector3(x * _lado(b), y, VIDRO_Z - PALMA_NO_VIDRO)
	var d := (Vector3.UP + Vector3(_lado(b), 0.0, 0.0) * 0.25).normalized()
	b.polo = Vector3(_lado(b) * 0.8, -0.6, -0.4).normalized()
	return BracoVivo.pega(onde, d, Vector3.FORWARD, &"apoio")


func _quadros(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_pasta.path_join(nome + ".png"))
	print("[bancada_manga] foto=", nome)


func _quer(p: String) -> bool:
	return _so.is_empty() or _so.has(p)


## As duas lentes: de dentro do carro (atras do vidro, na altura do olho) e de
## lado, um pouco de cima.
func _fotos(nome: String, alvo: Vector3) -> void:
	_cam.global_position = Vector3(0.05, 1.55, VIDRO_Z + 0.62)
	_cam.look_at(alvo)
	await _quadros(2)
	await _foto(nome + "_dentro")
	_cam.global_position = Vector3(1.35, 1.75, 0.55)
	_cam.look_at(alvo + Vector3(0.1, 0.0, -0.1))
	await _quadros(2)
	await _foto(nome + "_lado")


func _pose(poses: Array) -> void:
	for k in _bracos.size():
		_bracos[k].ombro = _ombro(_bracos[k])
		_bracos[k].pular(poses[k])
	await _quadros(ASSENTA)


## Onde estao o braco e a manga (os alvos das particulas pelos ossos da
## procuracao), para conferir a montagem.
func _sonda(nome: String) -> void:
	for b: BracoDoPadre in _bracos:
		var m := b._manga_longa
		if m == null or m._pano == null:
			print("[bancada_manga] %s: sem manga" % nome)
			continue
		var pano := m._pano
		var pc: PanoGPU.PecaDePano = pano.pecas[0]
		var alvos := []
		for i: int in [0, pc.w * 5, pc.n - 1]:
			var o := i * PanoGPU.FIXO_FLOATS
			var a := pano._osso(int(pc.fixo[o + 3])) * Vector3(pc.fixo[o], pc.fixo[o + 1], pc.fixo[o + 2])
			alvos.append(a)
		print("[bancada_manga] %s %s: ombro %s cot %s punho %s | osso0 %s osso1 %s osso2 %s | alvos %s | k %.2f" % [
			nome, "D" if b.direita else "E", b.global_transform * b.ombro, b.global_transform * b.cotovelo_montado,
			b.global_transform * b.punho_montado, pano._osso(0).origin, pano._osso(1).origin,
			pano._osso(2).origin, alvos, m._k])


func _rodar() -> void:
	await _quadros(20)
	var pend: Array = _bracos.map(func(b: BracoDoPadre) -> Dictionary: return _pendurado(b))
	await _pose(pend)
	_sonda("pendurado")
	if _quer("pendurado"):
		await _fotos("pendurado", Vector3(0.0, 1.2, 0.0))
	if _quer("vidro_cara"):
		await _pose(_bracos.map(func(b: BracoDoPadre) -> Dictionary: return _no_vidro(b, 0.24, 1.55)))
		await _fotos("vidro_cara", Vector3(0.0, 1.5, 0.2))
	if _quer("vidro_alto"):
		await _pose(_bracos.map(func(b: BracoDoPadre) -> Dictionary: return _no_vidro(b, 0.28, 1.98)))
		await _fotos("vidro_alto", Vector3(0.0, 1.75, 0.2))
	if _quer("erguido"):
		await _pose(_bracos.map(func(b: BracoDoPadre) -> Dictionary:
			b.polo = Vector3(_lado(b), 0.0, -0.3).normalized()
			return BracoVivo.pega(_ombro(b) + Vector3(0.06 * _lado(b), 0.63, 0.06), Vector3.UP,
				Vector3.FORWARD, &"aberta")))
		await _fotos("erguido", Vector3(0.0, 1.8, 0.0))
	if _quer("cara"):
		var d := _bracos[0]
		_cam.global_position = Vector3(0.05, 1.55, VIDRO_Z + 0.25)
		_cam.look_at(Vector3(0.05, 1.55, 0.0))
		var fwd := -_cam.global_basis.z
		var cima := _cam.global_basis.y
		d.polo = Vector3(1.0, -0.8, -0.2).normalized()
		d.pular(BracoVivo.pega(_cam.global_position + fwd * 0.2 - cima * 0.02,
			(cima + _cam.global_basis.x * 0.3).normalized(), -fwd, AgarraoDoPadre.POSES[&"garra"]))
		_bracos[1].pular(_pendurado(_bracos[1]))
		await _quadros(ASSENTA)
		await _foto("cara_dentro")
	if _quer("sobe"):
		await _pose(_bracos.map(func(b: BracoDoPadre) -> Dictionary: return _pendurado(b)))
		_cam.global_position = Vector3(0.9, 1.7, 1.3)
		_cam.look_at(Vector3(0.1, 1.6, 0.0))
		for b: BracoDoPadre in _bracos:
			b.ir(_no_vidro(b, 0.28, 1.98), 0.9, Vector3(0.0, 0.1, 0.15), 0.5)
		for k in 45:
			await _quadros(2 if _rajada else 6)
			if _rajada or k % 3 == 0:
				await _foto("sobe_%02d" % k)
			if not _rajada and k >= 15:
				break
	print("[bancada_manga] fim")
	get_tree().quit()
