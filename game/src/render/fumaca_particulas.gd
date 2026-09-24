## Fumaca de verdade: tufos macios que sobem, abrem e somem.
##
## Por que isto substitui as placas cruzadas
## -----------------------------------------
## A fumaca do cigarro e dos cinzeiros eram duas placas de 26 x 70 cm cruzadas,
## com a celula de fumaca do atlas correndo por cima. Na captura do MODERNO
## (captures/fumaca_v2/antes) elas liam como TUBOS DE NEON parados no ar, e a do
## fumante da calcada como uma fita laranja e verde — a UV correndo vazava para
## as celulas vizinhas do atlas.
##
## Fumaca e o contrario de placa: e volume que se desfaz. Aqui cada tufo nasce
## pequeno e denso na brasa, sobe devagar, abre, gira e some, e a turbulencia
## entorta o fio. A particula e ILUMINADA: o tufo que passa na frente da TV pega o
## azul dela, o que passa pela lampada do som pega o magenta — e a fumaca que
## ninguem ilumina some no escuro, como some de verdade.
##
## Coordenada de MUNDO: quem fuma e anda deixa o rastro para tras.
class_name FumacaParticulas
extends GPUParticles3D

enum Tipo {
	## A brasa na mao de quem fuma: fio fino, tufo pequeno.
	CIGARRO,
	## O cinzeiro com a bituca acesa: fio mais lento e mais alto.
	CINZEIRO,
	## A que escapa pela porta e pela janela: tufo largo, espalhado.
	NUVEM,
	## A que sai da boca de quem soltou a tragada: jato que nasce rapido para a
	## FRENTE do emissor (-Z), freia no ar e abre em nuvem. Nasce desligada
	## (`amount_ratio` 0); quem dosa e a `Blunt`, pela forca da baforada.
	BAFORADA,
}

const TEXTURA := "res://assets/textures/fx_fumaca_puff.png"

@export var tipo: Tipo = Tipo.CIGARRO

## O material do tufo e um so para todo o jogo: mesma textura, mesma luz.
static var _material: StandardMaterial3D
## A baforada tem o seu: o mesmo tufo com um piso de luz propria. Ver
## `_material_do_tufo`.
static var _material_baforada: StandardMaterial3D


func _ready() -> void:
	local_coords = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Tufo de fumaca nao e objeto: nao pode tapar a lente de quem encosta.
	var p := ParticleProcessMaterial.new()
	p.direction = Vector3.UP
	p.spread = 7.0
	p.gravity = Vector3(0.0, 0.035, 0.0)
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -22.0
	p.angular_velocity_max = 22.0
	p.damping_min = 0.02
	p.damping_max = 0.06
	p.turbulence_enabled = true
	p.turbulence_noise_scale = 2.4
	p.turbulence_noise_speed_random = 0.4

	var vida := 3.2
	var tamanho := Vector2(0.05, 0.42)
	var alfa := 0.32
	match tipo:
		Tipo.CIGARRO:
			amount = 22
			p.initial_velocity_min = 0.10
			p.initial_velocity_max = 0.18
			p.turbulence_noise_strength = 0.35
			p.turbulence_influence_min = 0.04
			p.turbulence_influence_max = 0.10
		Tipo.CINZEIRO:
			amount = 18
			vida = 4.2
			tamanho = Vector2(0.04, 0.55)
			alfa = 0.26
			p.initial_velocity_min = 0.07
			p.initial_velocity_max = 0.13
			p.turbulence_noise_strength = 0.3
			p.turbulence_influence_min = 0.03
			p.turbulence_influence_max = 0.08
		Tipo.NUVEM:
			amount = 12
			vida = 5.0
			tamanho = Vector2(0.25, 1.1)
			alfa = 0.14
			p.spread = 35.0
			p.initial_velocity_min = 0.08
			p.initial_velocity_max = 0.16
			p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			p.emission_box_extents = Vector3(0.35, 0.3, 0.05)
			p.turbulence_noise_strength = 0.5
			p.turbulence_influence_min = 0.05
			p.turbulence_influence_max = 0.12
		Tipo.BAFORADA:
			# Densa e opaca: na casa da fumaca o ar ja e nevoa quente, e com 40
			# tufos a 0,46 a baforada sumia nela (captura do jogo, tragada funda).
			amount = 64
			vida = 3.4
			tamanho = Vector2(0.07, 0.7)
			alfa = 0.66
			p.direction = Vector3(0.0, 0.0, -1.0)
			p.spread = 11.0
			p.gravity = Vector3(0.0, 0.05, 0.0)
			p.initial_velocity_min = 0.75
			p.initial_velocity_max = 1.15
			# Freia forte: o jato vai trinta, quarenta centimetros e vira nuvem
			# parada, que e o que o ar do comodo faz com a fumaca.
			p.damping_min = 1.3
			p.damping_max = 1.9
			p.turbulence_noise_strength = 0.45
			p.turbulence_influence_min = 0.05
			p.turbulence_influence_max = 0.14
			amount_ratio = 0.0
	lifetime = vida
	randomness = 0.35
	# A baforada nao existe antes de alguem soltar: nada de pre-processar.
	preprocess = 0.0 if tipo == Tipo.BAFORADA else vida
	p.scale_min = 1.0
	p.scale_max = 1.3
	p.scale_curve = _curva([Vector2(0.0, tamanho.x / tamanho.y), Vector2(1.0, 1.0)])
	p.color_ramp = _rampa(alfa)
	process_material = p

	var quad := QuadMesh.new()
	quad.size = Vector2(tamanho.y, tamanho.y)
	quad.material = _material_do_tufo(tipo == Tipo.BAFORADA)
	draw_pass_1 = quad
	visibility_aabb = AABB(Vector3(-1.5, -0.3, -1.5), Vector3(3.0, 4.0, 3.0))


static func _curva(pontos: Array[Vector2]) -> CurveTexture:
	var c := Curve.new()
	for pt: Vector2 in pontos:
		c.add_point(pt)
	var t := CurveTexture.new()
	t.curve = c
	return t


## Transparente no nascimento, cheio logo depois, e se desfazendo ate zero. Um
## tufo que nasce opaco poe um bloco branco em cima da brasa.
static func _rampa(alfa: float) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.12, 0.5, 1.0])
	g.colors = PackedColorArray([
		Color(0.86, 0.86, 0.84, 0.0),
		Color(0.86, 0.86, 0.84, alfa),
		Color(0.80, 0.80, 0.80, alfa * 0.55),
		Color(0.76, 0.76, 0.78, 0.0),
	])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


## A baforada ganha um piso de emissao. Fumaca soltada numa sala acesa e mais
## CLARA que o ar atras dela — espalha a luz de todas as lampadas, e nao so da
## que bate de frente. Sem isto, na casa da fumaca (ar que ja e nevoa quente e
## clara) a baforada saia como uma coluna marrom mais escura que o fundo.
static func _material_do_tufo(baforada: bool = false) -> StandardMaterial3D:
	if baforada and _material_baforada != null:
		return _material_baforada
	if not baforada and _material != null:
		return _material
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = load(TEXTURA) as Texture2D
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.disable_receive_shadows = true
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	# Some antes de encostar na lente: tufo a um palmo do olho vira a tela inteira
	# cinza.
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 0.15
	m.distance_fade_max_distance = 0.7
	# Encostado numa parede ou no teto ele nao corta em linha reta.
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 0.25
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if baforada:
		m.emission_enabled = true
		m.emission = Color(0.36, 0.35, 0.34)
		_material_baforada = m
	else:
		_material = m
	return m
