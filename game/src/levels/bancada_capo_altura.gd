## Bancada da altura dos encapuzados: a silhueta desenhada de cada um, de pe,
## medida na imagem (e nao no parametro `altura` do `Corpo`): capuz, cabeca,
## batina e o que mais a roupa acrescenta.
##
##     G=.tools/Godot_v4.7.2-stable_win64_console.exe
##     $G --path game --resolution 1600x900 \
##        res://scenes/test/bancada_capo_altura.tscn -- --fotos=DIR \
##        [--alturas=1.82:0,1.76:1,1.64:1]
##
## Cada figura e montada como a abertura monta um romeiro (a mesma aparencia,
## o capuz, a batina AAA e o corpo AAA), de frente para a lente, em pe, sem a
## aura. A lente e ortografica: uma linha de pixel e sempre o mesmo tanto de
## metro. Depois de o pano assentar, a foto sai em DIR/altura.png e o log diz,
## por figura, a altura da silhueta (o pixel escuro mais alto) e a largura
## nos ombros.
class_name BancadaCapoAltura
extends Node3D

## [altura, tipo] (o tipo de `AberturaEstrada.FIGURAS`: 1 e o curvado).
var _figuras: Array = [[1.82, 0], [1.76, 1], [1.64, 1]]
var _pasta := ""
var _cam: Camera3D
var _corpos: Array[Corpo] = []
var _t := 0.0
## A lente: o meio (m) e a altura do quadro (m).
const MEIO := 1.1
const QUADRO := 2.6
const PASSO := 0.9
const SEMENTE := 10


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			_pasta = a.trim_prefix("--fotos=")
		elif a.begins_with("--alturas="):
			_figuras = []
			for par: String in a.trim_prefix("--alturas=").split(","):
				var p := par.split(":")
				_figuras.append([float(p[0]), int(p[1]) if p.size() > 1 else 0])
	var mundo := WorldEnvironment.new()
	var amb := Environment.new()
	amb.background_mode = Environment.BG_COLOR
	amb.background_color = Color(0.85, 0.85, 0.85)
	amb.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	amb.ambient_light_color = Color(1, 1, 1)
	amb.ambient_light_energy = 0.6
	amb.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	mundo.environment = amb
	add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40, 20, 0)
	sol.light_energy = 0.6
	add_child(sol)
	for i in _figuras.size():
		var f: Array = _figuras[i]
		var c := Corpo.new()
		c.name = "Figura%d" % i
		add_child(c)
		var altura := float(f[0])
		var tipo := int(f[1])
		c.montar(AberturaEstrada._aparencia_de_encapuzado(SEMENTE, altura,
			AberturaEstrada.OMBRO_ENCAPUZADO, false))
		c.jeito = {"curvatura": [0.05, 0.16, 0.03, 0.22][tipo], "cabeca": 0.1}
		MonstroDaEstrada.vestir(c, SEMENTE, AberturaEstrada.OMBRO_ENCAPUZADO / 0.42, false)
		c.position = Vector3((float(i) - float(_figuras.size() - 1) * 0.5) * PASSO, 0.0, 0.0)
		c.visible = true
		_corpos.append(c)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = QUADRO
	_cam.near = 0.05
	_cam.far = 50.0
	add_child(_cam)
	# A frente do `Corpo` e -Z: a lente fica em -Z olhando +Z.
	_cam.global_transform = Transform3D(Basis.looking_at(Vector3(0, 0, 1), Vector3.UP),
		Vector3(0.0, MEIO, -8.0))
	_cam.make_current()


func _process(delta: float) -> void:
	_t += delta
	for c: Corpo in _corpos:
		c.animar(0.0, delta)
	if _t >= 3.0:
		set_process(false)
		_medir()


func _medir() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if not _pasta.is_empty():
		DirAccess.make_dir_recursive_absolute(_pasta)
		img.save_png(_pasta.path_join("altura.png"))
	var w := img.get_width()
	var h := img.get_height()
	var m_px := QUADRO / float(h)
	var larg_m := m_px * float(w)
	for i in _corpos.size():
		# A lente olha +Z: a direita da foto e o -X do mundo.
		var cx := -_corpos[i].position.x
		var x0 := clampi(int((cx - PASSO * 0.45 + larg_m * 0.5) / m_px), 0, w - 1)
		var x1 := clampi(int((cx + PASSO * 0.45 + larg_m * 0.5) / m_px), 0, w - 1)
		var topo_px := -1
		for y in h:
			for x in range(x0, x1 + 1):
				if img.get_pixel(x, y).get_luminance() < 0.45:
					topo_px = y
					break
			if topo_px >= 0:
				break
		var alt := MEIO + QUADRO * 0.5 - (float(topo_px) + 0.5) * m_px
		# A largura na altura do ombro do corpo (0,79 da altura).
		var yo := int((MEIO + QUADRO * 0.5 - float(_figuras[i][0]) * 0.79) / m_px)
		var esq := -1
		var dir := -1
		for x in range(x0, x1 + 1):
			if img.get_pixel(x, clampi(yo, 0, h - 1)).get_luminance() < 0.45:
				if esq < 0:
					esq = x
				dir = x
		print("[altura] figura %d: corpo %.2f m (tipo %d) -> silhueta %.3f m, largura nos ombros %.3f m" % [
			i, float(_figuras[i][0]), int(_figuras[i][1]), alt, float(dir - esq + 1) * m_px if esq >= 0 else 0.0])
	get_tree().quit()
