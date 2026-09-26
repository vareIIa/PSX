## Bancada do andar dos encapuzados de fundo (`AndarMacabro`): quatro deles no
## facho de um farol, na nevoa, sem rodar os quarenta segundos da estrada.
##
##     G=.tools/Godot_v4.7.2-stable_win64_console.exe
##     $G --path game --resolution 1920x1080 res://tests/bancada_andar.tscn -- \
##        --fotos=DIR [--lado] [--vira] [--evento=ergue|entorta|dedos] [--segundos=S]
##
## - Sem opcao: a lente parada na altura do olho de quem dirige, e eles vindo de
##   12 m para ela. Estao no quadro, entao quase param.
## - `--lado`: a lente de lado e eles cruzando o quadro na rapidez de passeio,
##   sem o freio do olhar. Serve para julgar o passo, o tronco e os bracos.
## - `--vira`: a lente vira para o lado por 3 s e volta, varias vezes. A cada
##   volta eles estao mais perto.
## - `--evento=`: o mais perto faz o evento aos 2 s, e de novo a cada 5 s.
## - `--perto`: eles largam a 4-6 m da lente, e nao a 9-12.
## - `--custo=N`: N deles rodando em volta da lente, a 4 a 7 m, e o custo de CPU
##   por quadro (o laco do andar e todos os `_process` do quadro), media de 5 s
##   depois de 2 s de aquecimento. `--sem-pano` desliga o pano deles e
##   `--so-corpo` troca o andar pelo `Corpo` parado: o lado A de cada medida.
##
## A rajada sai a 10 quadros por segundo em DIR/r (640x360; ver
## tools/mosaico_rajada.py) e, um a cada tres, em DIR/cheio na resolucao da
## janela. Imprime `[bancada_andar] chave=valor`.
extends Node3D

const ALTURAS := [1.86, 1.78, 1.92, 1.80]
const TIPOS := [0, 1, 3, 0]
## De onde vem cada um (m, x e z) e a rapidez de passeio (m/s).
const LARGADA := [Vector2(-2.2, -11.0), Vector2(0.4, -12.5), Vector2(2.3, -10.0), Vector2(-0.6, -8.5)]
const ANDA := 0.4
const PARA_PERTO := 2.4
const OLHO := Vector3(0.0, 1.15, 0.0)
const RAJADA := 0.1

var _pasta := ""
var _lado := false
var _vira := false
var _evento := ""
var _segundos := 14.0
var _t := 0.0
var _t_rajada := 0.0
var _n := 0
var _t_evento := 2.0
var _cam: Camera3D
var _corpos: Array[Corpo] = []
var _andares: Array[AndarMacabro] = []
var _custo := 0
var _perto := false
var _sem_pano := false
var _so_corpo := false
var _us_quadro := 0
var _medidas: Dictionary = {"n": 0, "laco": 0.0, "scripts": 0.0, "quadro": 0.0, "pior": 0.0}


## Os `_process` do quadro inteiro: um marco roda primeiro, outro por ultimo.
class Marco extends Node:
	var fim := false
	var bancada: Node

	func _process(_delta: float) -> void:
		bancada.call(&"_marco", fim)


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			_pasta = a.trim_prefix("--fotos=")
		elif a == "--lado":
			_lado = true
		elif a == "--vira":
			_vira = true
		elif a.begins_with("--evento="):
			_evento = a.trim_prefix("--evento=")
		elif a.begins_with("--segundos="):
			_segundos = float(a.trim_prefix("--segundos="))
		elif a.begins_with("--custo="):
			_custo = int(a.trim_prefix("--custo="))
		elif a == "--perto":
			_perto = true
		elif a == "--sem-pano":
			_sem_pano = true
		elif a == "--so-corpo":
			_so_corpo = true
	if not _pasta.is_empty():
		DirAccess.make_dir_recursive_absolute(_pasta.path_join("r"))
		DirAccess.make_dir_recursive_absolute(_pasta.path_join("cheio"))
	_montar_palco()
	if _custo > 0:
		_montar_custo()
		return
	for i in ALTURAS.size():
		var c := _encapuzado(i)
		var l: Vector2 = LARGADA[i]
		if _lado:
			# Cruzando da esquerda para a direita, cada um numa distancia.
			c.position = Vector3(-3.6 - float(i) * 1.1, 0.0, -3.2 - float(i) * 1.3)
			c.basis = Basis.looking_at(Vector3.RIGHT, Vector3.UP)
		else:
			if _perto:
				l *= 0.45
			c.position = Vector3(l.x, 0.0, l.y)
			c.basis = Basis.looking_at(Vector3(-l.x, 0.0, -l.y).normalized(), Vector3.UP)
		_corpos.append(c)
		_andares.append(c.get_meta(&"andar") as AndarMacabro)
	print("[bancada_andar] corpos=%d lado=%s vira=%s evento=%s" % [_corpos.size(), _lado, _vira, _evento])


func _process(delta: float) -> void:
	_t += delta
	if _custo > 0:
		_rodar_custo(delta)
		return
	_mover_lente()
	for i in _corpos.size():
		var c := _corpos[i]
		var andar := _andares[i]
		var dir := Vector3.RIGHT
		var quer := ANDA
		if not _lado:
			var para := _cam.global_position - c.global_position
			para.y = 0.0
			dir = para.normalized()
			if para.length() < PARA_PERTO:
				quer = 0.0
		var v := andar.ritmo(delta, quer, AndarMacabro.olhado(c), not _lado)
		c.global_position += dir * v * delta
		if dir.length_squared() > 0.0:
			c.global_basis = Basis.looking_at(dir, Vector3.UP)
		c.dominado = false
		c.animar(0.0, delta)
		var estalo := andar.passo(delta, _cam.global_position)
		if estalo > 0.0:
			print("[bancada_andar] t=%.2f estalo=%.2f corpo=%d" % [_t, estalo, i])
	if not _evento.is_empty() and _t >= _t_evento:
		_t_evento += 5.0
		var perto := _mais_perto()
		var qual := {"ergue": AndarMacabro.Evento.ERGUE, "entorta": AndarMacabro.Evento.ENTORTA,
			"dedos": AndarMacabro.Evento.DEDOS}.get(_evento, AndarMacabro.Evento.ERGUE) as int
		if perto >= 0 and _andares[perto].evento() == AndarMacabro.Evento.NENHUM:
			_andares[perto].comecar(qual)
			print("[bancada_andar] t=%.2f evento=%s corpo=%d" % [_t, _evento, perto])
	_t_rajada -= delta
	if not _pasta.is_empty() and _t_rajada <= 0.0 and _t > 0.5:
		_t_rajada = RAJADA
		_gravar("r_%07.2f.png" % _t)
	if _t >= _segundos:
		var vistos := 0
		for c: Corpo in _corpos:
			if AndarMacabro.olhado(c):
				vistos += 1
		print("[bancada_andar] fim t=%.1f quadros=%d vistos=%d" % [_t, _n, vistos])
		get_tree().quit(0)


func _mover_lente() -> void:
	if _lado:
		# Acompanha o da frente, de lado, a 3,6 m dele.
		var x := _corpos[0].global_position.x if not _corpos.is_empty() else 0.0
		_cam.global_transform = Transform3D(Basis.looking_at(Vector3(0.0, -0.12, -1.0), Vector3.UP),
			Vector3(x + 0.3, 1.25, 0.4))
		return
	var giro := 0.0
	if _vira:
		# 2,5 s olhando, 0,35 s virando, 3 s de lado, 0,35 s voltando.
		var ciclo := fmod(_t, 6.2)
		giro = smoothstep(2.5, 2.85, ciclo) * (1.0 - smoothstep(5.85, 6.2, ciclo)) * 1.75
	_cam.global_transform = Transform3D(Basis(Vector3.UP, giro)
		* Basis.looking_at(Vector3(0.0, -0.06, -1.0), Vector3.UP), OLHO)


func _mais_perto() -> int:
	var melhor := -1
	var d := INF
	for i in _corpos.size():
		var l := _corpos[i].global_position.distance_to(_cam.global_position)
		if l < d:
			d = l
			melhor = i
	return melhor


func _gravar(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if _n % 3 == 0 or _lado:
		img.save_png(_pasta.path_join("cheio").path_join(nome))
	_n += 1
	img.resize(640, 360, Image.INTERPOLATE_BILINEAR)
	img.save_png(_pasta.path_join("r").path_join(nome))


## Como a estrada monta (`AberturaEstrada._encapuzado`), sem a treva de volume.
func _encapuzado(i: int, semente: int = -1) -> Corpo:
	if semente < 0:
		semente = i
	var c := Corpo.new()
	c.name = "Encapuzado%d" % semente
	add_child(c)
	var altura: float = ALTURAS[i]
	var tipo: int = TIPOS[i]
	var ombro := AberturaEstrada.OMBRO_ENCAPUZADO
	c.montar(AberturaEstrada._aparencia_de_encapuzado(semente + 5, altura, ombro, false))
	c.jeito = {"curvatura": [0.05, 0.16, 0.03, 0.22][tipo],
		"cabeca": [0.08, 0.20, 0.05, 0.26][tipo] + 0.02 * float(i % 3)}
	MonstroDaEstrada.vestir(c, semente + 5, ombro / 0.42, false)
	var aura := AuraNegra.criar(AberturaEstrada.AURA_CAIXA * (altura / 1.9),
		AberturaEstrada.AURA_FIGURA, 0.9)
	c.add_child(aura)
	aura.position = Vector3(0.0, altura * 0.42, 0.0)
	aura.forca = 0.45
	c.set_meta(&"andar", AndarMacabro.new(c, semente + 5))
	return c


func _montar_palco() -> void:
	var mundo := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.022, 0.028)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.17, 0.2)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.fog_enabled = true
	env.fog_light_color = Color(0.1, 0.11, 0.13)
	env.fog_density = 0.02
	mundo.environment = env
	add_child(mundo)
	var chao := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(60, 60)
	chao.mesh = plano
	var barro := StandardMaterial3D.new()
	barro.albedo_color = Color(0.10, 0.08, 0.06)
	barro.roughness = 0.6
	chao.material_override = barro
	add_child(chao)
	# O farol: de tras da lente, baixo, com sombra, como o do carro.
	var farol := SpotLight3D.new()
	farol.light_color = Color(1.0, 0.93, 0.8)
	farol.light_energy = 9.0
	farol.spot_range = 40.0
	farol.spot_angle = 32.0
	farol.shadow_enabled = true
	add_child(farol)
	farol.global_transform = Transform3D(Basis.looking_at(Vector3(0.0, -0.08, -1.0), Vector3.UP),
		Vector3(0.4, 0.75, 0.6))
	var lua := DirectionalLight3D.new()
	lua.light_color = Color(0.75, 0.8, 0.95)
	lua.light_energy = 2.2
	lua.shadow_enabled = true
	add_child(lua)
	lua.rotation = Vector3(-0.7, 0.35, 0.0)
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.near = 0.05
	add_child(_cam)
	_cam.current = true


# --- `--custo=N` ------------------------------------------------------------

func _montar_custo() -> void:
	_segundos = 7.0
	_cam.global_transform = Transform3D(Basis.looking_at(Vector3(0.0, -0.06, -1.0), Vector3.UP), OLHO)
	for i in _custo:
		var c := _encapuzado(i % ALTURAS.size(), i)
		var a := TAU * float(i) / float(_custo)
		var r := 4.0 + float(i % 3) * 1.5
		c.position = Vector3(sin(a) * r, 0.0, -cos(a) * r)
		_corpos.append(c)
		_andares.append(c.get_meta(&"andar") as AndarMacabro)
		if _sem_pano:
			var capuz := c.get_meta(&"capuz") as CapuzMacabro if c.has_meta(&"capuz") else null
			if capuz != null and capuz.pano != null:
				capuz.pano.set_process(false)
				capuz.pano.visible = false
	for fim in [false, true]:
		var m := Marco.new()
		m.fim = fim
		m.bancada = self
		m.process_priority = 100000 if fim else -100000
		add_child(m)
	print("[custo] n=%d sem_pano=%s so_corpo=%s placa=%s" % [_custo, _sem_pano, _so_corpo,
		RenderingServer.get_video_adapter_name()])


func _rodar_custo(delta: float) -> void:
	var us := Time.get_ticks_usec()
	for i in _corpos.size():
		var c := _corpos[i]
		var p := c.global_position
		p.y = 0.0
		var dir := Vector3(-p.z, 0.0, p.x).normalized()
		if _so_corpo:
			c.global_position += dir * 0.4 * delta
			c.global_basis = Basis.looking_at(dir, Vector3.UP)
			c.dominado = false
			c.animar(0.4, delta)
			continue
		var andar := _andares[i]
		var v := andar.ritmo(delta, 0.4, AndarMacabro.olhado(c), false)
		c.global_position += dir * v * delta
		c.global_basis = Basis.looking_at(dir, Vector3.UP)
		c.dominado = false
		c.animar(0.0, delta)
		andar.passo(delta, _cam.global_position)
	if _t > 2.0:
		_medidas["laco"] = float(_medidas["laco"]) + (Time.get_ticks_usec() - us) / 1000.0
	if _t >= _segundos:
		var n := maxf(1.0, float(_medidas["n"]))
		print("[custo] n=%d sem_pano=%s so_corpo=%s quadros=%d laco %.3f ms  scripts %.3f ms  quadro %.2f ms (pior %.1f)" % [
			_custo, _sem_pano, _so_corpo, int(n), float(_medidas["laco"]) / n,
			float(_medidas["scripts"]) / n, float(_medidas["quadro"]) / n, float(_medidas["pior"])])
		get_tree().quit(0)


func _marco(fim: bool) -> void:
	var agora := Time.get_ticks_usec()
	if not fim:
		if _us_quadro > 0 and _t > 2.0:
			var q := (agora - _us_quadro) / 1000.0
			_medidas["quadro"] = float(_medidas["quadro"]) + q
			_medidas["pior"] = maxf(float(_medidas["pior"]), q)
			_medidas["n"] = int(_medidas["n"]) + 1
		_us_quadro = agora
		_medidas["ini"] = agora
	elif _t > 2.0 and _medidas.has("ini"):
		_medidas["scripts"] = float(_medidas["scripts"]) + (agora - int(_medidas["ini"])) / 1000.0
