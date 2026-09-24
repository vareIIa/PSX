## O ceu do interior: urubu rodando na termica, bando de maritaca gritando por
## cima do telhado, garca cruzando devagar, o teco-teco que passa zumbindo e o
## jato la no alto riscando o azul. E, de longe, o bem-te-vi de dia e o
## cachorro latindo no sitio a noite.
##
## Por que existe
## -------------
## A serra conta onde a cidade esta; isto conta QUANDO. Cidade de interior de
## Minas nao e silenciosa nem vazia em cima: tem sempre um urubu na termica do
## meio da tarde, a maritaca passa berrando no fim do dia, e o barulho de um
## aviaozinho e acontecimento. Sem nada no ceu, o ceu e papel de parede.
##
## Pouco, e de longe
## -----------------
## Nada disto e para ser olhado de perto, e nada disto pode virar ruido. Sao
## dois ou tres urubus por termica, um bando a cada minuto e pouco, um aviao a
## cada varios minutos. O que da vida e o intervalo: o ceu esta quase sempre
## quieto, e de vez em quando alguma coisa passa.
##
## Mundo e camera
## --------------
## Passaro e teco-teco moram no MUNDO: andando por baixo deles, eles mudam de
## lugar no quadro, como devem. O jato mora preso a camera (a 360 m, logo
## alem da serra), porque a dez quilometros de altura ele nao se mexe por
## quem anda um quarteirao.
##
## Clima
## -----
## Passaro e teco-teco so de dia, sem chuva e com a vista aberta. O jato de dia
## com ceu limpo (o rastro precisa de azul atras) e a noite sem nevoa — a
## noite ele e so luz piscando. Com nevoa, a propria nevoa da cena apaga o
## passaro a cem metros; o som continua.
##
## Captura
## -------
## `parar()` congela e esconde tudo: a regressao visual nao pode ter um urubu
## passando na foto. `--ver-ceu-vivo` poe cada coisa na frente da camera, para
## a foto de conferencia.
class_name CeuVivo
extends Node3D

const GRUPO := &"ceu_vivo"
const SHADER_PASSARO := "res://shaders/psx_passaro.gdshader"
const SHADER_AVIAO := "res://shaders/psx_aviao.gdshader"
const SHADER_RASTRO := "res://shaders/psx_rastro.gdshader"
## Acima disto a camera esta num interior (Interiores.DESLOCAMENTO, 2000 m).
const TETO_INTERIOR := 1000.0
const MAX_PASSAROS := 48

enum Especie { URUBU, MARITACA, GARCA }
## Envergadura (m), cor de silhueta, batidas por segundo e abertura da batida.
## O urubu quase nao bate: plana na termica balancando a asa em V. A maritaca
## bate rapido e sem parar. A garca bate devagar e fundo, e e branca contra o
## morro.
const ENVERGADURA: Array[float] = [1.75, 0.5, 1.6]
const COR: Array[Color] = [Color(0.07, 0.065, 0.06), Color(0.14, 0.24, 0.1),
	Color(0.93, 0.93, 0.9)]
const BATIDA: Array[float] = [2.6, 9.0, 2.3]
const ABERTURA: Array[float] = [0.55, 0.75, 0.8]
## Quanto o passaro e desenhado maior que de verdade. A oitenta metros um urubu
## de 1,75 m, visto de baixo e de lado, vira um ponto de oito pixels que ninguem
## le como ave; um pouco maior, a silhueta da asa aparece.
const ESCALA_DE_LEITURA := 1.45

## Termicas de urubu ao mesmo tempo, e urubus por termica.
const TERMICAS := 2
const URUBUS := Vector2i(2, 4)
## Altura da termica acima do chao, e distancia dela ate a camera.
const TERMICA_ALTURA := Vector2(45.0, 85.0)
const TERMICA_LONGE := Vector2(90.0, 170.0)
## Termica mais longe que isto e recolocada (fora da vista).
const TERMICA_SOLTA := 260.0
## O vento que arrasta a termica, m/s.
const VENTO := Vector3(0.7, 0.0, 0.3)

## Segundos entre dois bandos, e o primeiro depois de chegar.
const INTERVALO_BANDO := Vector2(40.0, 110.0)
const METADE_DO_CAMINHO := 190.0

## Teco-teco: intervalo, altura acima do chao, velocidade (m/s), metade do
## caminho (m, bem alem do far: o motor se ouve antes de se ver).
const INTERVALO_TECO := Vector2(150.0, 320.0)
const TECO_ALTURA := Vector2(120.0, 180.0)
const TECO_VELOCIDADE := 46.0
const TECO_CAMINHO := 1500.0
## Jato: intervalo, duracao da travessia, raio da casca em que ele mora.
const INTERVALO_JATO := Vector2(80.0, 210.0)
const JATO_TRAVESSIA := Vector2(110.0, 170.0)
const JATO_RAIO := 360.0
## Amostras do rastro: uma a cada RASTRO_PASSO s, ate RASTRO_AMOSTRAS.
const RASTRO_PASSO := 0.4
const RASTRO_AMOSTRAS := 90

## Sons de longe: intervalo entre dois, de dia e de noite.
const INTERVALO_LONGE_DIA := Vector2(16.0, 45.0)
const INTERVALO_LONGE_NOITE := Vector2(22.0, 65.0)
const BEM_TE_VI: Array[StringName] = [&"bem_te_vi_1", &"bem_te_vi_2"]
const CACHORRO: Array[StringName] = [&"cachorro_longe_1", &"cachorro_longe_2",
	&"cachorro_longe_3"]
const MARITACA: Array[StringName] = [&"maritaca_1", &"maritaca_2", &"maritaca_3"]

var _rng := RandomNumberGenerator.new()
var _fog: FogController
var _preset: FogPreset
var _parado := false
var _tempo := 0.0

var _mm: MultiMesh
var _mmi: MultiMeshInstance3D
## Cada termica: {"centro": Vector3, "aves": Array[Dictionary]}.
var _termicas: Array[Dictionary] = []
## Cada bando: {"especie", "origem", "dir", "s", "velocidade", "membros", "grito"}.
var _bandos: Array[Dictionary] = []
var _proximo_bando := 0.0

var _teco: MeshInstance3D
var _mat_teco: ShaderMaterial
var _teco_voo: Dictionary = {}
var _proximo_teco := 0.0
var _som_teco: AudioStreamPlayer3D

var _jato: MeshInstance3D
var _mat_jato: ShaderMaterial
var _rastro: MeshInstance3D
var _mat_rastro: ShaderMaterial
var _rastro_malha: ImmediateMesh
var _jato_voo: Dictionary = {}
var _proximo_jato := 0.0
var _som_jato: AudioStreamPlayer3D
var _amostras: Array[Vector3] = []
var _idades: Array[float] = []
var _amostra_em := 0.0

var _vozes: Array[AudioStreamPlayer3D] = []
var _proximo_longe := 0.0

## O clima em vigor, lido uma vez por troca de preset.
var _dia := true
var _limpo := false
var _vista := 1.0
var _fundo := Color(0.53, 0.72, 0.92)


func _ready() -> void:
	add_to_group(GRUPO)
	name = "CeuVivo"
	# Semente fixa: a mesma sessao tem o mesmo ceu, e um defeito que so aparece
	# no terceiro bando se reproduz.
	_rng.seed = 19_1970
	_montar_passaros()
	_montar_teco()
	_montar_jato()
	for i in 4:
		_vozes.append(_tocador("Longe%d" % i))
	_som_teco = _tocador("MotorTeco")
	_som_jato = _tocador("RoncoJato")
	_proximo_bando = _rng.randf_range(12.0, 35.0)
	_proximo_teco = _rng.randf_range(35.0, 90.0)
	_proximo_jato = _rng.randf_range(20.0, 60.0)
	_proximo_longe = _rng.randf_range(6.0, 15.0)
	if OS.get_cmdline_user_args().has("--ver-ceu-vivo"):
		_demonstrar.call_deferred()


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if not _ler_clima() or cam == null or _parado \
			or cam.global_position.y > TETO_INTERIOR or _preset.ceu_proprio:
		_esconder()
		return
	_tempo += delta
	var olho := cam.global_position
	var chao := Relevo.altura(olho.x, olho.z)
	var voa := _dia and _limpo and _vista > 0.5

	_cuidar_das_termicas(delta, cam, voa)
	_cuidar_dos_bandos(delta, olho, chao, voa)
	_desenhar_passaros()
	_cuidar_do_teco(delta, olho, chao, voa, cam)
	_cuidar_do_jato(delta, cam)
	_cuidar_dos_sons_de_longe(delta, olho)


## Congela e esconde tudo (rota de captura, regressao visual).
func parar() -> void:
	_parado = true
	_esconder()


func voltar() -> void:
	_parado = false


func _esconder() -> void:
	if _mmi != null:
		_mmi.visible = false
	if _teco != null:
		_teco.visible = false
	if _jato != null:
		_jato.visible = false
		_rastro.visible = false
	for p: AudioStreamPlayer3D in [_som_teco, _som_jato]:
		if p != null and p.playing:
			p.stop()


func _ler_clima() -> bool:
	if _fog == null or not is_instance_valid(_fog):
		_fog = get_tree().get_first_node_in_group(&"fog_controller") as FogController
		if _fog == null:
			return false
	var preset := _fog.preset_atual()
	if preset == null:
		return false
	if preset != _preset:
		_preset = preset
		_dia = preset.hora_do_dia == FogPreset.HoraDoDia.DIA
		_limpo = not preset.tem_chuva
		_vista = 1.0 if not preset.fog_enabled \
			else smoothstep(60.0, 160.0, preset.fog_end)
		_fundo = preset.sky_color
		for m: ShaderMaterial in [_mat_teco, _mat_jato, _mat_rastro]:
			m.set_shader_parameter(&"fundo", _fundo)
			m.set_shader_parameter(&"noite", 0.0 if _dia else 1.0)
	return true


# --- passaros ---------------------------------------------------------------

func _montar_passaros() -> void:
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.use_custom_data = true
	_mm.mesh = _malha_passaro()
	_mm.instance_count = MAX_PASSAROS
	_mm.visible_instance_count = 0
	_mmi = MultiMeshInstance3D.new()
	_mmi.name = "Passaros"
	_mmi.multimesh = _mm
	_mmi.top_level = true
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PASSARO)
	_mmi.material_override = mat
	# O MultiMesh anda pelo ceu inteiro: a caixa dele e o ceu.
	_mmi.custom_aabb = AABB(Vector3(-4000, -500, -4000), Vector3(8000, 1500, 8000))
	add_child(_mmi)


## Passaro de meia envergadura 1, bico para -Z. Corpo em losango, cauda em
## leque, e cada asa em duas partes (a de fora dobra mais na batida).
static func _malha_passaro() -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var c := PackedColorArray()
	var tri := func(a: Vector3, b: Vector3, d: Vector3, asa: float) -> void:
		for p: Vector3 in [a, b, d]:
			v.append(p)
			uv.append(Vector2(clampf(absf(p.x), 0.0, 1.0), asa))
			c.append(Color.WHITE)
	# Corpo e cauda.
	tri.call(Vector3(0, 0, -0.42), Vector3(0.07, 0, -0.05), Vector3(-0.07, 0, -0.05), 0.0)
	tri.call(Vector3(0.07, 0, -0.05), Vector3(0.05, 0, 0.3), Vector3(-0.07, 0, -0.05), 0.0)
	tri.call(Vector3(-0.07, 0, -0.05), Vector3(0.05, 0, 0.3), Vector3(-0.05, 0, 0.3), 0.0)
	tri.call(Vector3(0.05, 0, 0.3), Vector3(0.14, 0, 0.46), Vector3(-0.14, 0, 0.46), 0.0)
	tri.call(Vector3(0.05, 0, 0.3), Vector3(-0.14, 0, 0.46), Vector3(-0.05, 0, 0.3), 0.0)
	for lado: float in [-1.0, 1.0]:
		var r0 := Vector3(0.06 * lado, 0, -0.16)
		var r1 := Vector3(0.06 * lado, 0, 0.14)
		var m0 := Vector3(0.5 * lado, 0, -0.14)
		var m1 := Vector3(0.5 * lado, 0, 0.16)
		var p0 := Vector3(1.0 * lado, 0, 0.02)
		var p1 := Vector3(0.94 * lado, 0, 0.14)
		tri.call(r0, m0, r1, 1.0)
		tri.call(r1, m0, m1, 1.0)
		tri.call(m0, p0, m1, 1.0)
		tri.call(m1, p0, p1, 1.0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = c
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return malha


## Uma ave para o desenho deste quadro: onde esta, para onde vai, quanto
## inclina na curva e o angulo da asa agora.
var _desenho: Array[Dictionary] = []


func _cuidar_das_termicas(delta: float, cam: Camera3D, voa: bool) -> void:
	if not voa:
		_termicas.clear()
		return
	var olho := cam.global_position
	var frente := -cam.global_basis.z
	while _termicas.size() < TERMICAS:
		_termicas.append(_nova_termica(olho, frente, _termicas.is_empty()))
	for k in _termicas.size():
		var t := _termicas[k]
		var centro: Vector3 = t["centro"] + VENTO * delta
		t["centro"] = centro
		var plano := Vector2(centro.x - olho.x, centro.z - olho.z)
		if plano.length() > TERMICA_SOLTA:
			_termicas[k] = _nova_termica(olho, frente, false)
			continue
		for ave: Dictionary in t["aves"]:
			var w: float = ave["w"]
			var r: float = ave["raio"]
			var ang: float = float(ave["ang"]) + w * delta
			ave["ang"] = ang
			var pos := centro + Vector3(cos(ang) * r, float(ave["dy"])
				+ sin(_tempo * 0.21 + float(ave["fase"])) * 3.0, sin(ang) * r)
			var vel := Vector3(-sin(ang), 0.0, cos(ang)) * r * w
			# Inclinacao da curva: tan = v^2 / (r g).
			var inclina := atan(vel.length_squared() / (r * 9.8)) * signf(w)
			# Plana balancando a asa em V; de vez em quando umas batidas.
			var asa := 0.14 + 0.06 * sin(_tempo * 1.3 + float(ave["fase"]))
			var surto := fposmod(_tempo + float(ave["fase"]) * 7.0, 11.0)
			if surto < 1.4:
				asa = sin(surto * TAU * BATIDA[Especie.URUBU]) * ABERTURA[Especie.URUBU]
			_desenho.append({"especie": Especie.URUBU, "pos": pos, "vel": vel,
				"inclina": inclina, "asa": asa})


func _nova_termica(olho: Vector3, frente: Vector3, qualquer: bool) -> Dictionary:
	# Termica nova nasce fora da vista (atras de quem olha), menos a primeira.
	var ang := _rng.randf() * TAU
	for tentativa in 8:
		var d := Vector3(cos(ang), 0.0, sin(ang))
		if qualquer or d.dot(Vector3(frente.x, 0.0, frente.z).normalized()) < -0.2:
			break
		ang = _rng.randf() * TAU
	var dist := _rng.randf_range(TERMICA_LONGE.x, TERMICA_LONGE.y)
	var centro := olho + Vector3(cos(ang), 0.0, sin(ang)) * dist
	centro.y = Relevo.altura(centro.x, centro.z) \
		+ _rng.randf_range(TERMICA_ALTURA.x, TERMICA_ALTURA.y)
	var aves: Array[Dictionary] = []
	var sentido := 1.0 if _rng.randf() < 0.5 else -1.0
	for i in _rng.randi_range(URUBUS.x, URUBUS.y):
		var raio := _rng.randf_range(14.0, 30.0)
		aves.append({"raio": raio, "w": sentido * 9.0 / raio,
			"ang": _rng.randf() * TAU, "dy": _rng.randf_range(-8.0, 10.0),
			"fase": _rng.randf() * TAU})
	return {"centro": centro, "aves": aves}


func _cuidar_dos_bandos(delta: float, olho: Vector3, chao: float, voa: bool) -> void:
	_proximo_bando -= delta
	if voa and _proximo_bando <= 0.0 and _bandos.size() < 2:
		_proximo_bando = _rng.randf_range(INTERVALO_BANDO.x, INTERVALO_BANDO.y)
		_novo_bando(olho, chao, -1, Vector3.ZERO)
	var i := _bandos.size() - 1
	while i >= 0:
		var b := _bandos[i]
		var s: float = float(b["s"]) + float(b["velocidade"]) * delta
		b["s"] = s
		if s > METADE_DO_CAMINHO * 2.0 or not voa:
			_bandos.remove_at(i)
			i -= 1
			continue
		var especie: int = b["especie"]
		var dir: Vector3 = b["dir"]
		var lado := dir.cross(Vector3.UP).normalized()
		var base: Vector3 = b["origem"] + dir * s
		for m: Dictionary in b["membros"]:
			var off: Vector3 = m["off"]
			var fase: float = m["fase"]
			var pos := base + lado * off.x + Vector3.UP * off.y - dir * off.z
			# O bando nao e rigido: cada um sobe, desce e abre um pouco.
			pos += Vector3.UP * sin(_tempo * 0.9 + fase) * 1.2 \
				+ lado * sin(_tempo * 0.6 + fase * 1.7) * 1.5
			var bate := sin(_tempo * TAU * BATIDA[especie] + fase)
			var asa := bate * ABERTURA[especie]
			if especie == Especie.GARCA and fposmod(_tempo * 0.35 + fase, 3.0) < 0.9:
				# Garca planeja entre as batidas, asa quase reta.
				asa = 0.05
			_desenho.append({"especie": especie, "pos": pos, "vel": dir,
				"inclina": sin(_tempo * 0.5 + fase) * 0.15, "asa": asa})
		# Maritaca grita enquanto passa.
		if especie == Especie.MARITACA:
			var perto := base.distance_to(olho)
			b["grito"] = float(b["grito"]) - delta
			if perto < 150.0 and float(b["grito"]) <= 0.0:
				b["grito"] = _rng.randf_range(0.35, 1.4)
				_tocar_longe(MARITACA[_rng.randi() % MARITACA.size()], base,
					-3.0 - 20.0 * log(maxf(perto, 25.0) / 25.0) / log(10.0),
					_rng.randf_range(0.93, 1.08))
		i -= 1


## Um bando que cruza o ceu passando ao lado da camera. `especie` -1 sorteia;
## `passagem` diferente de zero forca o ponto em que ele passa (captura).
func _novo_bando(olho: Vector3, chao: float, especie: int, passagem: Vector3) -> void:
	if especie < 0:
		especie = Especie.MARITACA if _rng.randf() < 0.6 else Especie.GARCA
	var rumo := _rng.randf() * TAU
	var dir := Vector3(cos(rumo), 0.0, sin(rumo))
	var lado := dir.cross(Vector3.UP).normalized()
	var altura := _rng.randf_range(22.0, 38.0) if especie == Especie.MARITACA \
		else _rng.randf_range(35.0, 60.0)
	if passagem == Vector3.ZERO:
		var desvio := _rng.randf_range(30.0, 90.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
		passagem = olho + lado * desvio
		passagem.y = chao + altura
	else:
		dir = (passagem - olho)
		dir.y = 0.0
		dir = dir.normalized().cross(Vector3.UP)
	var membros: Array[Dictionary] = []
	if especie == Especie.MARITACA:
		# Maritaca voa aos pares, o bando solto.
		var pares := _rng.randi_range(2, 5)
		for p in pares:
			var centro := Vector3(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-2.0, 2.0),
				float(p) * _rng.randf_range(2.5, 4.5))
			for k in 2:
				membros.append({"off": centro + Vector3(float(k) * 0.9, 0.0, float(k) * 0.4),
					"fase": _rng.randf() * TAU})
	else:
		# Garca em linha diagonal, a de tras um pouco de lado.
		for k in _rng.randi_range(3, 6):
			membros.append({"off": Vector3(float(k) * 2.4, float(k) * 0.3, float(k) * 1.8),
				"fase": _rng.randf() * TAU})
	_bandos.append({"especie": especie, "origem": passagem - dir * METADE_DO_CAMINHO,
		"dir": dir, "s": 0.0, "membros": membros, "grito": 0.0,
		"velocidade": 15.0 if especie == Especie.MARITACA else 9.5})


func _desenhar_passaros() -> void:
	var n := mini(_desenho.size(), MAX_PASSAROS)
	for i in n:
		var a: Dictionary = _desenho[i]
		var especie: int = a["especie"]
		var vel: Vector3 = a["vel"]
		var frente := Vector3(vel.x, 0.0, vel.z).normalized()
		if frente == Vector3.ZERO:
			frente = Vector3.FORWARD
		var base := Basis.looking_at(frente, Vector3.UP)
		base = base * Basis(Vector3.BACK, float(a["inclina"]))
		base = base.scaled_local(Vector3.ONE * ENVERGADURA[especie] * 0.5 * ESCALA_DE_LEITURA)
		_mm.set_instance_transform(i, Transform3D(base, a["pos"]))
		_mm.set_instance_color(i, COR[especie])
		_mm.set_instance_custom_data(i, Color(float(a["asa"]), 0.0, 0.0, 0.0))
	_mm.visible_instance_count = n
	_mmi.visible = n > 0
	_desenho.clear()


# --- teco-teco --------------------------------------------------------------

func _montar_teco() -> void:
	_mat_teco = ShaderMaterial.new()
	_mat_teco.shader = load(SHADER_AVIAO)
	_teco = MeshInstance3D.new()
	_teco.name = "TecoTeco"
	_teco.top_level = true
	_teco.mesh = _malha_aviao(false)
	_teco.material_override = _mat_teco
	_teco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_teco.visible = false
	add_child(_teco)


func _cuidar_do_teco(delta: float, olho: Vector3, chao: float, voa: bool, cam: Camera3D) -> void:
	_proximo_teco -= delta
	if _teco_voo.is_empty():
		if voa and _proximo_teco <= 0.0:
			_proximo_teco = _rng.randf_range(INTERVALO_TECO.x, INTERVALO_TECO.y)
			_novo_teco(olho, chao, Vector3.ZERO)
		else:
			_teco.visible = false
			return
	var s: float = float(_teco_voo["s"]) + TECO_VELOCIDADE * delta
	_teco_voo["s"] = s
	if s > TECO_CAMINHO * 2.0:
		_teco_voo = {}
		_teco.visible = false
		_som_teco.stop()
		return
	var dir: Vector3 = _teco_voo["dir"]
	var pos: Vector3 = _teco_voo["origem"] + dir * s
	# Um balanco lento de asa: aviaozinho de interior nao voa em trilho.
	var base := Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.BACK, sin(_tempo * 0.4) * 0.06)
	_teco.global_transform = Transform3D(base, pos)
	var dist := pos.distance_to(olho)
	_teco.visible = dist < cam.far * 0.95 and _vista > 0.5
	_mat_teco.set_shader_parameter(&"ar", clampf(dist / 520.0, 0.0, 0.75) * _vista
		+ (1.0 - _vista))
	# O motor: volume pela distancia, altura pelo efeito Doppler.
	if AudioDirector.tem(&"aviao_teco_loop"):
		if not _som_teco.playing:
			_som_teco.stream = AudioDirector.em_loop(&"aviao_teco_loop")
			_som_teco.play()
		_som_teco.global_position = pos
		_som_teco.volume_db = clampf(-4.0 - 20.0 * log(maxf(dist, 60.0) / 150.0) / log(10.0),
			-60.0, 0.0)
		var aproxima := dir.dot((olho - pos).normalized()) * TECO_VELOCIDADE
		_som_teco.pitch_scale = 343.0 / (343.0 - aproxima)


func _novo_teco(olho: Vector3, chao: float, passagem: Vector3) -> void:
	var rumo := _rng.randf() * TAU
	var dir := Vector3(cos(rumo), 0.0, sin(rumo))
	if passagem == Vector3.ZERO:
		var lado := dir.cross(Vector3.UP).normalized()
		passagem = olho + lado * _rng.randf_range(120.0, 320.0) \
			* (1.0 if _rng.randf() < 0.5 else -1.0)
		passagem.y = chao + _rng.randf_range(TECO_ALTURA.x, TECO_ALTURA.y)
	else:
		dir = (passagem - olho)
		dir.y = 0.0
		dir = dir.normalized().cross(Vector3.UP)
	_teco_voo = {"origem": passagem - dir * TECO_CAMINHO, "dir": dir, "s": 0.0}


## Aviao com bico para -Z. `jato`: asa enflechada, fuselagem prata, e o tamanho
## que um jato a dez quilometros tem na casca de JATO_RAIO. Senao, teco-teco de
## asa alta, branco com faixa vermelha, em metros de verdade.
static func _malha_aviao(jato: bool) -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var c := PackedColorArray()
	var quad := func(a: Vector3, b: Vector3, d: Vector3, e: Vector3, cor: Color,
			tipo: float, fase: float) -> void:
		for p: Vector3 in [a, b, d, a, d, e]:
			v.append(p)
			c.append(cor)
			uv.append(Vector2(tipo, fase))
	var k := 0.16 if jato else 1.0
	var casco := Color(0.82, 0.83, 0.86) if jato else Color(0.92, 0.91, 0.87)
	var faixa := Color(0.62, 0.64, 0.68) if jato else Color(0.7, 0.14, 0.1)
	# Fuselagem: uma fita no plano horizontal e outra no vertical.
	var comp := (9.0 if jato else 3.9) * k
	var larg := (0.55 if jato else 0.55) * k
	quad.call(Vector3(-larg, 0, -comp), Vector3(larg, 0, -comp), Vector3(larg * 0.5, 0, comp),
		Vector3(-larg * 0.5, 0, comp), casco, 0.0, 0.0)
	quad.call(Vector3(0, -larg, -comp), Vector3(0, larg, -comp), Vector3(0, larg * 0.6, comp),
		Vector3(0, -larg * 0.3, comp), faixa, 0.0, 0.0)
	if jato:
		# Asa enflechada e empenagem.
		for lado: float in [-1.0, 1.0]:
			quad.call(Vector3(0, 0, -1.2 * k), Vector3(8.0 * lado * k, 0, 2.6 * k),
				Vector3(8.0 * lado * k, 0, 3.5 * k), Vector3(0, 0, 2.2 * k), casco, 0.0, 0.0)
			quad.call(Vector3(0, 0, 6.8 * k), Vector3(3.0 * lado * k, 0, 8.6 * k),
				Vector3(3.0 * lado * k, 0, 9.2 * k), Vector3(0, 0, 8.6 * k), casco, 0.0, 0.0)
		quad.call(Vector3(0, 0, 6.4 * k), Vector3(0, 3.0 * k, 8.8 * k),
			Vector3(0, 3.0 * k, 9.4 * k), Vector3(0, 0, 9.0 * k), faixa, 0.0, 0.0)
		# Luzes: as de navegacao e o estrobo, maiores que de verdade — a dez
		# quilometros uma luz e um ponto, nao um tamanho.
		var l := 0.55
		for luz: Array in [[Vector3(-8.0 * k, 0, 3.0 * k), Color(1.0, 0.15, 0.1), 1.0, 0.0],
				[Vector3(8.0 * k, 0, 3.0 * k), Color(0.2, 1.0, 0.35), 1.0, 0.0],
				[Vector3(0, 0.4 * k, 0), Color(1.0, 1.0, 1.0), 2.0, 0.0],
				[Vector3(0, 0, 9.3 * k), Color(1.0, 1.0, 1.0), 2.0, 0.5]]:
			var p: Vector3 = luz[0]
			quad.call(p + Vector3(-l, 0, -l), p + Vector3(l, 0, -l), p + Vector3(l, 0, l),
				p + Vector3(-l, 0, l), luz[1], luz[2], luz[3])
			quad.call(p + Vector3(-l, -l, 0), p + Vector3(l, -l, 0), p + Vector3(l, l, 0),
				p + Vector3(-l, l, 0), luz[1], luz[2], luz[3])
	else:
		# Asa alta, reta, com a faixa na ponta; profundor e deriva.
		for lado: float in [-1.0, 1.0]:
			quad.call(Vector3(0.3 * lado, 0.5, -1.4), Vector3(4.6 * lado, 0.55, -1.3),
				Vector3(4.6 * lado, 0.55, -0.1), Vector3(0.3 * lado, 0.5, -0.1), casco, 0.0, 0.0)
			quad.call(Vector3(4.0 * lado, 0.56, -1.31), Vector3(4.6 * lado, 0.56, -1.3),
				Vector3(4.6 * lado, 0.56, -0.1), Vector3(4.0 * lado, 0.56, -0.1), faixa, 0.0, 0.0)
			quad.call(Vector3(0, 0.1, 3.0), Vector3(1.6 * lado, 0.1, 3.2),
				Vector3(1.6 * lado, 0.1, 3.8), Vector3(0, 0.1, 3.8), casco, 0.0, 0.0)
		quad.call(Vector3(0, 0.2, 2.9), Vector3(0, 1.5, 3.4), Vector3(0, 1.5, 3.9),
			Vector3(0, 0.2, 3.9), faixa, 0.0, 0.0)
		quad.call(Vector3(0, 0.55, -1.4), Vector3(0, 0.55, -0.1), Vector3(0, 0.2, 0.2),
			Vector3(0, 0.2, -1.6), Color(0.35, 0.45, 0.55), 0.0, 0.0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = c
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return malha


# --- jato -------------------------------------------------------------------

func _montar_jato() -> void:
	_mat_jato = ShaderMaterial.new()
	_mat_jato.shader = load(SHADER_AVIAO)
	_mat_jato.set_shader_parameter(&"ar", 0.35)
	_jato = MeshInstance3D.new()
	_jato.name = "Jato"
	_jato.top_level = true
	_jato.mesh = _malha_aviao(true)
	_jato.material_override = _mat_jato
	_jato.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_jato.visible = false
	add_child(_jato)
	_mat_rastro = ShaderMaterial.new()
	_mat_rastro.shader = load(SHADER_RASTRO)
	_rastro_malha = ImmediateMesh.new()
	_rastro = MeshInstance3D.new()
	_rastro.name = "Rastro"
	_rastro.top_level = true
	_rastro.mesh = _rastro_malha
	_rastro.material_override = _mat_rastro
	_rastro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rastro.extra_cull_margin = JATO_RAIO * 2.0
	_rastro.visible = false
	add_child(_rastro)


## O rumo (vetor unitario) do jato no instante `k` (0..1) da travessia.
static func _rumo_jato(voo: Dictionary, k: float) -> Vector3:
	var az: float = float(voo["az0"]) + float(voo["giro"]) * k
	var el: float = float(voo["el0"]) + (float(voo["elmax"]) - float(voo["el0"])) * sin(PI * k)
	return Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el))


func _cuidar_do_jato(delta: float, cam: Camera3D) -> void:
	_proximo_jato -= delta
	var pode := (_dia and _limpo and _preset.nuvens < 0.5 and _vista > 0.8) \
		or (not _dia and not _preset.fog_enabled and not _preset.tem_chuva)
	if _jato_voo.is_empty():
		if pode and _proximo_jato <= 0.0:
			_proximo_jato = _rng.randf_range(INTERVALO_JATO.x, INTERVALO_JATO.y)
			_novo_jato(_rng.randf() * TAU, 0.0)
		elif _amostras.is_empty():
			_jato.visible = false
			_rastro.visible = false
			return
	var olho := cam.global_position
	var raio := minf(JATO_RAIO, cam.far * 0.86)
	var rumo := Vector3.ZERO
	if not _jato_voo.is_empty():
		var t: float = float(_jato_voo["t"]) + delta
		_jato_voo["t"] = t
		var k := t / float(_jato_voo["dura"])
		if k >= 1.0 or not pode:
			_jato_voo = {}
			_som_jato.stop()
		else:
			rumo = _rumo_jato(_jato_voo, k)
			var adiante := _rumo_jato(_jato_voo, minf(k + 0.01, 1.0))
			var frente := (adiante - rumo).normalized()
			# O jato visto de baixo: a barriga para a camera, bico no rumo.
			var cima := -rumo
			var base := Basis.looking_at(frente, cima)
			_jato.global_transform = Transform3D(base.scaled_local(Vector3.ONE * raio / JATO_RAIO),
				olho + rumo * raio)
			_jato.visible = true
			_amostra_em -= delta
			if _amostra_em <= 0.0 and _dia:
				_amostra_em = RASTRO_PASSO
				_amostras.push_front(rumo)
				_idades.push_front(0.0)
			if AudioDirector.tem(&"jato_longe_loop"):
				if not _som_jato.playing:
					_som_jato.stream = AudioDirector.em_loop(&"jato_longe_loop")
					_som_jato.play()
				_som_jato.global_position = olho + rumo * 80.0
				# O ronco chega mais forte com o jato alto (mais perto) e some
				# nas pontas da travessia.
				_som_jato.volume_db = -30.0 + 12.0 * rumo.y + 20.0 * log(maxf(sin(PI * k), 0.01)) / log(10.0)
	if _jato_voo.is_empty():
		_jato.visible = false
	for i in _idades.size():
		_idades[i] += delta
	while not _idades.is_empty() and _idades[-1] > RASTRO_PASSO * RASTRO_AMOSTRAS:
		_idades.pop_back()
		_amostras.pop_back()
	_desenhar_rastro(olho, raio, rumo)


func _novo_jato(az0: float, elmax: float) -> void:
	var giro := deg_to_rad(_rng.randf_range(100.0, 160.0)) * (1.0 if _rng.randf() < 0.5 else -1.0)
	_jato_voo = {"az0": az0, "giro": giro, "el0": deg_to_rad(13.0),
		"elmax": elmax if elmax > 0.0 else deg_to_rad(_rng.randf_range(28.0, 65.0)),
		"dura": _rng.randf_range(JATO_TRAVESSIA.x, JATO_TRAVESSIA.y), "t": 0.0}
	_amostras.clear()
	_idades.clear()
	_amostra_em = 0.0


## A fita do rastro, das amostras (mais nova primeiro). Fina e opaca logo
## atras do aviao, larga e transparente no fim.
func _desenhar_rastro(olho: Vector3, raio: float, rumo_agora: Vector3) -> void:
	_rastro_malha.clear_surfaces()
	if _amostras.size() < 2 or not _dia:
		_rastro.visible = false
		return
	_rastro.visible = true
	_rastro.global_position = olho
	var vida := RASTRO_PASSO * RASTRO_AMOSTRAS
	_rastro_malha.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _amostras.size():
		var d := _amostras[i]
		var idade := _idades[i]
		# Um fio de ceu limpo entre o motor e o comeco do rastro.
		if idade < 0.8 and rumo_agora != Vector3.ZERO:
			continue
		var prox := _amostras[mini(i + 1, _amostras.size() - 1)]
		var ante := _amostras[maxi(i - 1, 0)]
		var ao_longo := (ante - prox).normalized()
		var lado := d.cross(ao_longo).normalized()
		var largura := (0.25 + idade * 0.035) * raio / JATO_RAIO
		var alfa := pow(clampf(1.0 - idade / vida, 0.0, 1.0), 1.3) * 0.8 \
			* smoothstep(0.8, 3.0, idade)
		var cor := Color(1.0, 1.0, 1.0, alfa)
		var p := d * (raio + 2.0)
		_rastro_malha.surface_set_color(cor)
		_rastro_malha.surface_add_vertex(p - lado * largura)
		_rastro_malha.surface_set_color(cor)
		_rastro_malha.surface_add_vertex(p + lado * largura)
	_rastro_malha.surface_end()


# --- sons de longe ----------------------------------------------------------

func _tocador(nome: String) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = nome
	p.bus = &"Ambiente"
	# O volume e escrito a mao pela distancia: a atenuacao do motor mata tudo
	# alem de poucas dezenas de metros, e aqui tudo e longe. O 3D fica so para
	# o lado de onde o som vem.
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	p.max_distance = 0.0
	p.panning_strength = 0.8
	add_child(p)
	return p


func _tocar_longe(nome: StringName, onde: Vector3, volume_db: float, afinacao: float) -> void:
	if not AudioDirector.tem(nome) or AudioDirector.silencioso():
		return
	for p: AudioStreamPlayer3D in _vozes:
		if p.playing:
			continue
		p.stream = AudioDirector.stream(nome)
		p.global_position = onde
		p.volume_db = volume_db
		p.pitch_scale = afinacao
		p.play()
		return


## O bem-te-vi de dia; a noite, o cachorro do sitio, as vezes respondido por
## outro. Vem de um lado qualquer, longe, e nao repete o mesmo seguido.
func _cuidar_dos_sons_de_longe(delta: float, olho: Vector3) -> void:
	_proximo_longe -= delta
	if _proximo_longe > 0.0:
		return
	var faixa := INTERVALO_LONGE_DIA if _dia else INTERVALO_LONGE_NOITE
	_proximo_longe = _rng.randf_range(faixa.x, faixa.y)
	var ang := _rng.randf() * TAU
	var onde := olho + Vector3(cos(ang), 0.3, sin(ang)) * 40.0
	if _dia:
		if not _limpo:
			return
		_tocar_longe(BEM_TE_VI[_rng.randi() % BEM_TE_VI.size()], onde,
			_rng.randf_range(-20.0, -14.0), _rng.randf_range(0.96, 1.04))
		return
	_tocar_longe(CACHORRO[_rng.randi() % CACHORRO.size()], onde,
		_rng.randf_range(-24.0, -18.0), _rng.randf_range(0.9, 1.08))
	if _rng.randf() < 0.4:
		# O outro cachorro responde, do outro lado e mais longe.
		var resposta := olho + Vector3(cos(ang + 2.4), 0.3, sin(ang + 2.4)) * 40.0
		get_tree().create_timer(_rng.randf_range(1.2, 2.6)).timeout.connect(
			_tocar_longe.bind(CACHORRO[_rng.randi() % CACHORRO.size()], resposta,
				_rng.randf_range(-28.0, -23.0), _rng.randf_range(0.85, 1.0)))


# --- captura ----------------------------------------------------------------

## `--ver-ceu-vivo`: cada coisa na frente da camera, para a foto de conferencia.
func _demonstrar() -> void:
	await get_tree().create_timer(1.5).timeout
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var olho := cam.global_position
	var frente := -cam.global_basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var chao := Relevo.altura(olho.x, olho.z)
	var centro := olho + frente * 75.0
	centro.y = olho.y + 30.0
	_termicas.clear()
	var t := _nova_termica(olho, frente, true)
	t["centro"] = centro
	_termicas.append(t)
	var cruza := olho + frente * 55.0
	cruza.y = olho.y + 14.0
	_novo_bando(olho, chao, Especie.GARCA, cruza)
	_bandos[-1]["s"] = METADE_DO_CAMINHO - 12.0
	var cruza2 := olho + frente * 40.0 + frente.cross(Vector3.UP) * 8.0
	cruza2.y = olho.y + 9.0
	_novo_bando(olho, chao, Especie.MARITACA, cruza2)
	_bandos[-1]["s"] = METADE_DO_CAMINHO - 18.0
	var teco := olho + frente * 150.0
	teco.y = olho.y + 45.0
	_novo_teco(olho, chao, teco)
	_teco_voo["s"] = TECO_CAMINHO - 60.0
	var az := atan2(frente.x, frente.z)
	_novo_jato(az - 0.9, deg_to_rad(24.0))
	_jato_voo["t"] = float(_jato_voo["dura"]) * 0.42
	_jato_voo["giro"] = 1.6
	# O rastro de quem ja vinha voando: amostras do caminho ate agora.
	var k := float(_jato_voo["t"]) / float(_jato_voo["dura"])
	for i in RASTRO_AMOSTRAS:
		var kk := k - float(i) * RASTRO_PASSO / float(_jato_voo["dura"])
		if kk < 0.0:
			break
		_amostras.append(_rumo_jato(_jato_voo, kk))
		_idades.append(float(i) * RASTRO_PASSO)
	print("[ceu_vivo] demonstracao: termica, garcas, maritacas, teco-teco e jato na frente")
