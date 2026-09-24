## A serra que fecha o horizonte da cidade: o mar de morros de Minas em cinco
## cristas, a serra de pedra la atras com a torre de TV, e a noite as luzes dos
## sitios pelos morros.
##
## Por que existe
## -------------
## Cidade de Minas e cidade no vale, e o que diz isso de longe e o morro atras do
## casario: morro redondo atras de morro redondo, meia-laranja, a de perto verde
## e com pasto, a de longe azul e quase da cor do ceu. Sem ela a cidade acabava
## numa linha reta de nevoa.
##
## O que mudou da versao de tres faixas
## ------------------------------------
## A primeira serra eram tres faixas de cor chapada com o recorte de uma soma de
## senos: de longe lia como "papel recortado", nunca como morro. Esta tem:
##
## - FORMA de morro mineiro: cada crista e um punhado de morros de topo redondo
##   (`_morros`), fundidos por um maximo suave que arredonda a grota entre eles.
##   A crista de tras e a serra de verdade: longa, com lombo quebrado e um pico
##   (`PICO`), onde fica a torre.
## - ENCOSTA com luz: a normal de cada coluna segue a inclinacao do recorte. O
##   lado do morro virado para o sol clareia, o outro fica na sombra; olhando
##   contra o sol a serra toda escurece, a favor ela abre em verde.
## - COBERTURA por fragmento (`psx_serra.gdshader`): pasto no alto, mata na
##   grota, talhao de eucalipto, estrada de terra vermelha, vocoroca, rocha
##   aflorando no topo da serra de tras, e a copa da mata recortando o cume.
## - SOMBRA DE NUVEM andando por cima do morro, com o vento.
## - A NOITE, as luzes (`psx_serra_luzes.gdshader`): sitios soltos, vilarejos,
##   a cidadezinha vizinha no pe da serra, o balizamento vermelho da torre e o
##   farol de um carro descendo a estrada.
##
## Presa a camera
## --------------
## Morro a esta distancia nao muda de tamanho enquanto se anda um quilometro.
## Seguindo a POSICAO da camera (e nao a rotacao) a serra fica sempre no fundo,
## nunca e alcancada, e cada direcao tem sempre o mesmo morro: quem sobe a rua
## olhando para o norte ve sempre a torre, e isso orienta.
##
## Sem nevoa, pintada COMO se tivesse
## ----------------------------------
## Ela fica a 300 m, alem de onde qualquer nevoa ja fechou: com nevoa de
## profundidade sairia exatamente da cor do fundo. Entao ela e `fog_disabled` e a
## nevoa entra no AR do shader (`vista`): na nevoa densa ela e da cor do fundo e
## some; no dia aberto as cinco cristas se separam.
##
## Logo antes das estrelas, escrevendo profundidade
## -------------------------------------------------
## A primeira serra nao escrevia profundidade, e a noite as estrelas (a 320 m,
## desenhadas depois) apareciam NA FRENTE do morro. Como ela e presa a camera,
## o raio nao muda nada na imagem — so o angulo conta. Entao as cinco cristas
## moram entre 300 e 316 m: alem de tudo o que a cidade desenha (~215 m), antes
## das estrelas e da lua, e a profundidade faz o resto.
class_name SerraDaCidade
extends MeshInstance3D

const GRUPO := &"serra_da_cidade"
const SHADER := "res://shaders/psx_serra.gdshader"
const SHADER_LUZES := "res://shaders/psx_serra_luzes.gdshader"

## Raio de cada crista, da de perto para a de longe.
const RAIOS: Array[float] = [300.0, 304.0, 308.0, 312.0, 316.0]
## Elevacao do cume tipico de cada crista acima do horizonte, em graus. A de
## longe e mais alta: e a serra espiando por cima do mar de morros.
const ELEVACAO: Array[float] = [3.4, 4.4, 5.5, 6.7, 8.6]
## Morros por crista (a de tras e serra, nao morro: ver `perfil`).
const MORROS: Array[int] = [16, 14, 13, 11]
## Largura de um morro, em graus: meia-laranja de perto, mais largo longe.
const LARGURA_MORRO := Vector2(9.0, 24.0)
const LADOS := 360
## O pico da serra de tras (angulo em graus, a partir de +Z, e altura extra).
const PICO := Vector2(38.0, 0.34)
## A copa das arvores sobe ate isto acima do cume, em graus.
const FRANJA := 0.32
## Quanto a crista desce abaixo do horizonte. Do alto do morro da matriz o vale
## esta abaixo da linha do olho, e o fundo alem da cidade tem de ser serra.
const SAIOTE := 300.0
## O vale entre a cidade e a serra, de dia: terra na bruma, cinza-esverdeada.
const BRUMA_DIA := Color(0.56, 0.6, 0.55)
const BRUMA := 0.6
const BRUMA_NOITE := 0.85
## Alcance da nevoa em que a serra comeca e termina de aparecer.
const VISTA := Vector2(40.0, 150.0)
const MORRO_NA_NEVOA := 0.45
## O mesmo para o chao do vale: so aparece com a nevoa muito aberta.
const VISTA_VALE := Vector2(160.0, 400.0)
## Acima disto a camera esta num interior (Interiores.DESLOCAMENTO, 2000 m).
const TETO_INTERIOR := 1000.0
## Onde a linha do horizonte cai na coordenada `marca` (0 no pe, 1 no cume).
const NO_HORIZONTE := 0.65
## Velocidade da sombra de nuvem sobre o morro, em m/s no raio da serra.
const VENTO := Vector2(1.1, 0.45)

## A cidadezinha vizinha: angulo (graus) e largura (graus).
const VIZINHA := Vector2(212.0, 7.0)
## A estrada no pe da serra: angulo do meio e largura do trecho, em graus.
const ESTRADA := Vector2(118.0, 34.0)

var _mat: ShaderMaterial
var _mat_luzes: ShaderMaterial
var _luzes: MeshInstance3D
var _fog: FogController
var _preset: FogPreset
var _vento := Vector2.ZERO
## `--sem-serra`: a mesma foto sem ela, para comparar em par.
var _sem_serra := OS.get_cmdline_user_args().has("--sem-serra")
## Os morros sorteados de cada crista: [centro (rad), meia largura (rad), altura].
static var _morros: Array = []


func _ready() -> void:
	add_to_group(GRUPO)
	name = "SerraDaCidade"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = RAIOS[RAIOS.size() - 1] + SAIOTE
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER)
	_mat.set_shader_parameter(&"no_horizonte", NO_HORIZONTE)
	material_override = _mat
	mesh = _montar()

	_luzes = MeshInstance3D.new()
	_luzes.name = "Luzes"
	_luzes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_luzes.extra_cull_margin = extra_cull_margin
	_mat_luzes = ShaderMaterial.new()
	_mat_luzes.shader = load(SHADER_LUZES)
	_luzes.material_override = _mat_luzes
	_luzes.mesh = _montar_luzes()
	add_child(_luzes)
	visible = false
	_pose_de_captura()


func _process(delta: float) -> void:
	if _fog == null or not is_instance_valid(_fog):
		_fog = get_tree().get_first_node_in_group(&"fog_controller") as FogController
		if _fog == null:
			visible = false
			return
	var preset := _fog.preset_atual()
	if preset != _preset:
		_preset = preset
		if preset != null:
			pintar(preset)
	var cam := get_viewport().get_camera_3d()
	if cam == null or preset == null or _sem_serra:
		visible = false
		return
	global_position = cam.global_position
	# O anel mora logo antes das estrelas (CeuNoturno: 320 m ou 88% do far) e
	# escreve profundidade: e assim que o morro tapa a estrela. Camera de far
	# curto encolhe o anel inteiro — so o angulo importa.
	var ceu := minf(320.0, cam.far * 0.88)
	scale = Vector3.ONE * minf(1.0, (ceu - 3.0) / RAIOS[RAIOS.size() - 1])
	# A planta ortogonal de captura olha de 400 m: o anel tamparia a cidade.
	visible = not preset.ceu_proprio and cam.global_position.y < TETO_INTERIOR \
		and cam.projection == Camera3D.PROJECTION_PERSPECTIVE
	_vento += VENTO * delta
	_mat.set_shader_parameter(&"vento", _vento)


## Repinta a serra a partir do fundo e da nevoa em vigor. So uniformes: o
## Mirante chama isto oito vezes por segundo enquanto abre o ar.
func pintar(preset: FogPreset) -> void:
	if _mat == null:
		return
	var fundo := preset.sky_color
	# Com nevoa o morro e so silhueta na bruma (no maximo MORRO_NA_NEVOA da
	# vista aberta) e o vale some: chao alem da nevoa nao pode aparecer mais
	# nitido que a cidade que ela ja apagou.
	var vista := 1.0 if not preset.fog_enabled \
		else smoothstep(VISTA.x, VISTA.y, preset.fog_end) * MORRO_NA_NEVOA
	var vista_vale := 1.0 if not preset.fog_enabled \
		else smoothstep(VISTA_VALE.x, VISTA_VALE.y, preset.fog_end)
	var dia := preset.hora_do_dia == FogPreset.HoraDoDia.DIA
	var bruma := fundo.lerp(BRUMA_DIA, BRUMA * vista_vale) if dia \
		else fundo * lerpf(1.0, BRUMA_NOITE, vista)
	bruma.a = 1.0
	# O sol do preset, como o FogController o aponta (x = elevacao, y = rumo).
	var rumo := Basis.from_euler(Vector3(deg_to_rad(preset.sol_rotacao.x),
		deg_to_rad(preset.sol_rotacao.y), 0.0)).z
	var nublado := clampf(preset.nuvens, 0.0, 1.0)
	_mat.set_shader_parameter(&"fundo", fundo)
	_mat.set_shader_parameter(&"bruma", bruma)
	_mat.set_shader_parameter(&"cor_sol", preset.sol_cor)
	_mat.set_shader_parameter(&"rumo_sol", rumo)
	_mat.set_shader_parameter(&"vista", vista)
	_mat.set_shader_parameter(&"vista_vale", vista_vale)
	_mat.set_shader_parameter(&"detalhe", 1.0 if Settings.luz_por_pixel else 0.0)
	_mat.set_shader_parameter(&"noite", 0.0 if dia else 1.0)
	if dia:
		# Ceu fechado apaga o sol no morro e deixa so o ambiente, mais alto.
		var sol := clampf(preset.sol_energia / 2.2, 0.0, 1.0) * (1.0 - nublado * 0.8)
		_mat.set_shader_parameter(&"luz_sol", 0.62 * sol)
		_mat.set_shader_parameter(&"luz_ambiente", lerpf(0.5, 0.62, nublado))
		# Sombra de nuvem so com nuvem no ceu, e some quando fecha de vez.
		_mat.set_shader_parameter(&"sombra_nuvem",
			0.09 + 0.2 * smoothstep(0.0, 0.4, nublado) * (1.0 - smoothstep(0.6, 1.0, nublado)))
		# Minas de longe e azul: a crista de perto ja leva um terco de ar.
		_mat.set_shader_parameter(&"ar_perto", 0.3)
		_mat.set_shader_parameter(&"ar_longe", 0.74)
	else:
		# A noite o morro e silhueta, pouco mais escura que o ceu.
		_mat.set_shader_parameter(&"luz_sol", 0.0)
		# Chao a noite e mais escuro que o ceu: o morro e recorte, nao relevo.
		_mat.set_shader_parameter(&"luz_ambiente", 0.012 if preset.tem_lua else 0.006)
		_mat.set_shader_parameter(&"sombra_nuvem", 0.0)
		_mat.set_shader_parameter(&"ar_perto", 0.42)
		_mat.set_shader_parameter(&"ar_longe", 0.78)
	_mat_luzes.set_shader_parameter(&"noite", 0.0 if dia else 1.0)
	_mat_luzes.set_shader_parameter(&"vista", vista)
	_mat_luzes.set_shader_parameter(&"fundo", fundo)


func _montar() -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var ix := PackedInt32Array()
	# Da crista de longe para a de perto: a ordem dos triangulos e a ordem de
	# desenho, e a de perto tem de cobrir a de longe.
	for crista in range(RAIOS.size() - 1, -1, -1):
		var raio: float = RAIOS[crista]
		var elev := tan(deg_to_rad(ELEVACAO[crista])) * raio
		var franja := tan(deg_to_rad(FRANJA)) * raio
		var passo := TAU / float(LADOS)
		var base := v.size()
		for k in LADOS:
			var ang := passo * float(k)
			var h := perfil(ang, crista) * elev
			# Inclinacao do recorte ao longo do arco, em metro por metro.
			var inclina := (perfil(ang + passo * 0.5, crista)
				- perfil(ang - passo * 0.5, crista)) * elev / (raio * passo)
			var fora := Vector3(sin(ang), 0.0, cos(ang))
			var lado := Vector3(cos(ang), 0.0, -sin(ang))
			# A encosta olha para a camera, para cima e para o lado que desce.
			var normal := (-fora + Vector3.UP * 0.8 - lado * inclina * 2.2).normalized()
			var p := fora * raio
			for linha in 4:
				var y: float = [-SAIOTE, 0.0, h, h + franja][linha]
				v.append(p + Vector3(0.0, y, 0.0))
				n.append(normal)
				uv.append(Vector2(float(crista), [0.0, NO_HORIZONTE, 1.0, 1.0][linha]))
				uv2.append(Vector2(1.0 if linha == 3 else 0.0, 0.0))
		for k in LADOS:
			var a := base + k * 4
			var b := base + ((k + 1) % LADOS) * 4
			for faixa in 3:
				ix.append_array([a + faixa, b + faixa, a + faixa + 1,
					a + faixa + 1, b + faixa, b + faixa + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = ix
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return malha


## As luzes da serra: uma malha so, cada quad virado para a camera (o centro).
func _montar_luzes() -> ArrayMesh:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 31_0719
	var quente := Color(1.0, 0.74, 0.4)
	var fria := Color(0.86, 0.93, 1.0)

	# Sitios soltos e vilarejos nas tres cristas de perto. A luz fica numa
	# fracao da altura do morro NAQUELE angulo, entao nunca flutua no ceu.
	var vilas: Array[Vector2] = []
	for i in 6:
		vilas.append(Vector2(rng.randf() * TAU, float(rng.randi_range(0, 2))))
	for i in 150:
		var ang: float
		var crista: int
		if i < 72:
			var vila := vilas[i % vilas.size()]
			ang = vila.x + rng.randfn(0.0, deg_to_rad(1.6))
			crista = int(vila.y)
		else:
			ang = rng.randf() * TAU
			crista = rng.randi_range(0, 2)
		var alto := rng.randf_range(0.04, 0.55) * (0.5 if i < 72 else 1.0)
		var cor := fria if rng.randf() < 0.22 else quente
		cor = cor * rng.randf_range(0.75, 1.0)
		_luz(v, c, uv, uv2, crista, ang, alto, 0.42, cor, 1.0, rng.randf(), Vector2.ZERO)

	# A cidadezinha vizinha: um punhado denso bem no pe da crista 3, sodio.
	var centro := deg_to_rad(VIZINHA.x)
	for i in 46:
		var ang := centro + rng.randfn(0.0, deg_to_rad(VIZINHA.y) * 0.35)
		var alto := absf(rng.randfn(0.0, 0.1)) + 0.02
		var cor := Color(1.0, 0.66, 0.32) if rng.randf() < 0.8 else fria
		_luz(v, c, uv, uv2, 3, ang, alto, 0.62, cor * rng.randf_range(0.7, 1.0),
			1.0, rng.randf(), Vector2.ZERO)
	# A torre da igreja de la, acesa: a unica luz alta da cidadezinha.
	_luz(v, c, uv, uv2, 3, centro + deg_to_rad(0.6), 0.34, 0.5, Color(1.0, 0.9, 0.7),
		1.0, 0.3, Vector2.ZERO)

	# A torre de TV no pico da serra de tras: mastro e dois balizamentos.
	var pico := angulo_da_torre()
	var r4: float = RAIOS[4] - 0.5
	var topo := perfil(pico, 4) * tan(deg_to_rad(ELEVACAO[4])) * RAIOS[4]
	var altura_torre := tan(deg_to_rad(1.25)) * r4
	var fora := Vector3(sin(pico), 0.0, cos(pico))
	var lado := Vector3(cos(pico), 0.0, -sin(pico))
	var pe := fora * r4 + Vector3.UP * (topo - 0.6)
	var cinza := Color(0.2, 0.21, 0.23)
	for q: Array in [[0.26, 0.0, 1.0], [0.5, 0.0, 0.14], [0.8, 0.38, 0.42]]:
		# [meia largura, de, ate] em fracao da altura: mastro, base e antena.
		_quad(v, c, uv, uv2, pe + Vector3.UP * altura_torre * float(q[1]),
			lado * float(q[0]), Vector3.UP * altura_torre * (float(q[2]) - float(q[1])),
			cinza, 0.0, 0.0, Vector2.ZERO)
	for f: float in [1.0, 0.55]:
		var ponto := pe + Vector3.UP * altura_torre * f
		_quad(v, c, uv, uv2, ponto - lado * 0.36 - Vector3.UP * 0.36, lado * 0.36,
			Vector3.UP * 0.72, Color(1.0, 0.12, 0.08), 2.0, 0.0, Vector2.ZERO)

	# A estrada no pe da serra: dois carros, um descendo e um subindo. A altura
	# e a do morro mais baixo do trecho, senao o farol passaria pelo ceu.
	var meio := deg_to_rad(ESTRADA.x)
	var largo := deg_to_rad(ESTRADA.y)
	var r1: float = RAIOS[1]
	var mais_baixo := INF
	for k in 24:
		mais_baixo = minf(mais_baixo, perfil(meio + largo * (float(k) / 23.0 - 0.5), 1))
	var y_estrada := mais_baixo * 0.3 * tan(deg_to_rad(ELEVACAO[1])) * r1
	for carro: Array in [[Color(1.0, 0.95, 0.8), 1.0 / 78.0, 0.0],
			[Color(1.0, 0.18, 0.1), -1.0 / 92.0, 0.37],
			[Color(1.0, 0.92, 0.75), 1.0 / 88.0, 0.61]]:
		var dir := Vector3(sin(meio), 0.0, cos(meio))
		var ld := Vector3(cos(meio), 0.0, -sin(meio))
		var ponto := dir * (r1 - 0.8) + Vector3.UP * y_estrada
		_quad(v, c, uv, uv2, ponto - ld * 0.3 - Vector3.UP * 0.18, ld * 0.3,
			Vector3.UP * 0.36, carro[0], 3.0, float(carro[2]),
			Vector2(float(carro[1]), largo))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return malha


## Uma luz de `tam` metros na encosta da `crista`, a `alto` da altura do morro.
func _luz(v: PackedVector3Array, c: PackedColorArray, uv: PackedVector2Array,
		uv2: PackedVector2Array, crista: int, ang: float, alto: float, tam: float,
		cor: Color, tipo: float, fase: float, giro: Vector2) -> void:
	var raio: float = RAIOS[crista] - 0.6
	# O tamanho vem em metros a 250 m; o angulo e o que vale.
	tam *= raio / 250.0
	var h := perfil(ang, crista) * tan(deg_to_rad(ELEVACAO[crista])) * RAIOS[crista] * alto
	var fora := Vector3(sin(ang), 0.0, cos(ang))
	var lado := Vector3(cos(ang), 0.0, -sin(ang))
	var ponto := fora * raio + Vector3.UP * h
	_quad(v, c, uv, uv2, ponto - lado * tam * 0.5 - Vector3.UP * tam * 0.5,
		lado * tam * 0.5, Vector3.UP * tam, cor, tipo, fase, giro)


## Quad de `canto` a `canto + 2*meia_largura + altura`.
static func _quad(v: PackedVector3Array, c: PackedColorArray, uv: PackedVector2Array,
		uv2: PackedVector2Array, canto: Vector3, meia_largura: Vector3,
		altura: Vector3, cor: Color, tipo: float, fase: float, giro: Vector2) -> void:
	var a := canto - meia_largura if tipo == 0.0 else canto
	var largura := meia_largura * 2.0
	for p: Vector3 in [a, a + largura, a + altura, a + altura, a + largura, a + largura + altura]:
		v.append(p)
		c.append(cor)
		uv.append(Vector2(tipo, fase))
		uv2.append(giro)


## O recorte da crista, entre 0 e ~1,6 (fracao de ELEVACAO), pelo angulo.
##
## Cristas de perto: morros de topo redondo sorteados (semente fixa), fundidos
## por um maximo suave — a grota entre dois morros sai arredondada, como a
## meia-laranja de Minas, e nao em V. A crista de tras e serra: um lombo longo
## e quebrado, com o pico onde fica a torre.
static func perfil(ang: float, crista: int) -> float:
	if _morros.is_empty():
		_sortear_morros()
	ang = fposmod(ang, TAU)
	var fino := 0.03 * sin(ang * 41.0 + float(crista) * 1.7) \
		+ 0.02 * sin(ang * 67.0 + float(crista) * 0.9)
	if crista >= MORROS.size():
		var lombo := 0.62 + 0.2 * sin(ang * 2.0 + 0.8) + 0.1 * sin(ang * 5.0 + 2.1)
		# Quebras da rocha: dentes curtos, mais fortes no alto do lombo.
		lombo += 0.09 * absf(sin(ang * 13.0 + 0.4)) + 0.05 * absf(sin(ang * 31.0 + 1.1))
		var d := _dif(ang, deg_to_rad(PICO.x))
		# O pico e um lombo mais alto e quebrado, nao um cone: Minas nao tem
		# vulcao, tem serra de quartzito com um ponto mais alto.
		var perto_do_pico := maxf(0.0, cos(clampf(d / deg_to_rad(11.0), -1.0, 1.0) * PI * 0.5))
		lombo += PICO.y * pow(perto_do_pico, 1.2) * (0.85 + 0.15 * absf(sin(ang * 53.0)))
		return clampf(lombo + fino, 0.1, 1.7)
	var h := 0.14
	for m: Vector3 in _morros[crista]:
		var d := absf(_dif(ang, m.x))
		if d >= m.y:
			continue
		var b := m.z * pow(0.5 + 0.5 * cos(PI * d / m.y), 1.25)
		h = _max_suave(h, b, 0.16)
	return clampf(h + fino, 0.06, 1.4)


## Onde a torre fica: o ponto mais alto perto do PICO. Os dentes de rocha do
## lombo mudam o topo em fracao de grau, e torre fora do topo fica pendurada
## na encosta.
static func angulo_da_torre() -> float:
	var melhor := deg_to_rad(PICO.x)
	var alto := -INF
	for k in 121:
		var ang := deg_to_rad(PICO.x - 6.0 + 0.1 * float(k))
		var h := perfil(ang, MORROS.size())
		if h > alto:
			alto = h
			melhor = ang
	return melhor


static func _sortear_morros() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1740
	_morros.clear()
	for crista in MORROS.size():
		var lista: Array[Vector3] = []
		var quantos: int = MORROS[crista]
		for i in quantos:
			# Espalhados pela volta, com folga: ninguem nasce em cima do outro.
			var centro := (float(i) + rng.randf_range(-0.3, 0.3)) / float(quantos) * TAU
			var largura := deg_to_rad(rng.randf_range(LARGURA_MORRO.x, LARGURA_MORRO.y)
				* (1.0 + float(crista) * 0.15))
			lista.append(Vector3(centro, largura, rng.randf_range(0.5, 1.05)))
		_morros.append(lista)


## Diferenca de angulo em (-PI, PI].
static func _dif(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)


static func _max_suave(a: float, b: float, r: float) -> float:
	var h := maxf(r - absf(a - b), 0.0)
	return maxf(a, b) + h * h / (4.0 * r)


## `--olhar-horizonte=giro,alto[,inclinacao]`: uma camera no ponto em que o
## jogador nasceu, `alto` metros acima do olho, olhando para o rumo `giro`
## (graus, 0 = +Z). So captura: o horizonte nao se julga da rua, onde o casario
## tapa a serra, e as poses de captura da cidade forcam dia e desenho infinito.
func _pose_de_captura() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--olhar-horizonte="):
			continue
		var q := arg.trim_prefix("--olhar-horizonte=").split(",")
		await get_tree().create_timer(1.0).timeout
		var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
		if jogador == null:
			return
		var cam := Camera3D.new()
		cam.name = "CameraHorizonte"
		cam.fov = 62.0
		cam.far = 420.0
		get_tree().current_scene.add_child(cam)
		cam.global_position = jogador.global_position + Vector3.UP \
			* (1.6 + (float(q[1]) if q.size() > 1 else 0.0))
		cam.rotation = Vector3(deg_to_rad(float(q[2]) if q.size() > 2 else 1.0),
			deg_to_rad(float(q[0])), 0.0)
		cam.current = true
		print("[serra] olhar-horizonte: rumo %s, lente a %.1f m" % [q[0], cam.global_position.y])
		return
