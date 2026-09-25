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
	## O fio que sobe da brasa parada: FITAS, e nao tufos. Ver `_montar_fio`.
	FIO,
}

const TEXTURA := "res://assets/textures/fx_fumaca_puff.png"

@export var tipo: Tipo = Tipo.CIGARRO
## Fumaca a um palmo da lente (a do proprio jogador em primeira pessoa). O
## material comum some entre 15 e 70 cm da camera, para o tufo que passa rente
## nao virar a tela cinza; a baforada de quem esta com o cigarro na boca nasce a
## dez centimetros do olho e sumiria inteira.
@export var perto: bool = false
## Fumaca de rua, a noite: sem o piso de luz propria da baforada. Na casa (ar
## que ja e nevoa quente e clara) o piso faz a baforada sair mais clara que o
## fundo; na rua escura, com a luz de apoio da abertura em cima, ele acendia a
## nuvem em volta da cabeca como uma aureola (plano do poste, 24/09).
@export var rua: bool = false

## O material do tufo e um so para todo o jogo: mesma textura, mesma luz.
static var _material: StandardMaterial3D
## A baforada tem o seu: o mesmo tufo com um piso de luz propria. Ver
## `_material_do_tufo`.
static var _material_baforada: StandardMaterial3D
## Os de perto e o do fio, pela chave (ver `_material_de`).
static var _materiais: Dictionary = {}


func _ready() -> void:
	local_coords = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if tipo == Tipo.FIO:
		_montar_fio()
		return
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
			#
			# E muitos tufos que CRESCEM CEDO. Com 64 tufos nascendo com 7 cm e
			# crescendo por igual a vida toda, a um segundo da boca a baforada
			# era um cacho de bolinhas separadas (bancada do cigarro, 24/09). A
			# fumaca soltada abre logo que sai: meio palmo em dois decimos de
			# segundo, e os tufos vizinhos se fundem num jato so.
			amount = 110
			vida = 3.0
			tamanho = Vector2(0.05, 0.62)
			alfa = 0.42
			p.direction = Vector3(0.0, 0.0, -1.0)
			p.spread = 9.0
			p.gravity = Vector3(0.0, 0.06, 0.0)
			p.initial_velocity_min = 0.85
			p.initial_velocity_max = 1.25
			# Freia forte: o jato vai trinta, quarenta centimetros e vira nuvem
			# parada, que e o que o ar do comodo faz com a fumaca.
			p.damping_min = 1.5
			p.damping_max = 2.1
			p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 0.008
			p.turbulence_noise_strength = 0.6
			p.turbulence_noise_scale = 0.9
			p.turbulence_influence_min = 0.06
			p.turbulence_influence_max = 0.18
			amount_ratio = 0.0
			if perto:
				# A do proprio jogador: nasce a dez centimetros do olho. Com os
				# tufos de 62 cm da baforada comum, o sopro cobria a tela inteira
				# de branco por dois segundos. Menor, mais rala, e sai mais
				# rapido para a frente: a nuvem se forma a meio metro, na rua.
				# E poucos tufos: cada um cobre meia tela a 4K, e com 70 o sopro
				# levava a GPU de 5,5 para 25 ms (medido, POV da bituca).
				amount = 30
				vida = 2.2
				tamanho = Vector2(0.03, 0.30)
				alfa = 0.44
				p.initial_velocity_min = 1.5
				p.initial_velocity_max = 2.0
				p.damping_min = 1.1
				p.damping_max = 1.5
				p.spread = 7.0
			elif rua:
				# Na rua o sopro tem de SUBIR antes de parar. Com a freada e os
				# tufos grandes da casa, a nuvem do sopro para o alto se
				# empilhava em volta da cabeca e virava um disco claro por tras
				# dela (poste, 24/09). Tufo menor, mais espalhado, freando menos.
				tamanho = Vector2(0.04, 0.42)
				alfa = 0.2
				p.spread = 15.0
				p.initial_velocity_min = 1.0
				p.initial_velocity_max = 1.5
				p.damping_min = 0.7
				p.damping_max = 1.1
				p.turbulence_noise_strength = 0.8
	lifetime = vida
	randomness = 0.35
	# A baforada nao existe antes de alguem soltar: nada de pre-processar.
	preprocess = 0.0 if tipo == Tipo.BAFORADA else vida
	p.scale_min = 1.0
	p.scale_max = 1.3
	if tipo == Tipo.BAFORADA:
		p.scale_curve = _curva([Vector2(0.0, tamanho.x / tamanho.y), Vector2(0.12, 0.38),
			Vector2(0.45, 0.75), Vector2(1.0, 1.0)])
	else:
		p.scale_curve = _curva([Vector2(0.0, tamanho.x / tamanho.y), Vector2(1.0, 1.0)])
	p.color_ramp = _rampa(alfa)
	process_material = p

	var quad := QuadMesh.new()
	quad.size = Vector2(tamanho.y, tamanho.y)
	quad.material = _material_perto(tipo == Tipo.BAFORADA) if perto \
		else (_material_de_rua() if rua and tipo == Tipo.BAFORADA
			else _material_do_tufo(tipo == Tipo.BAFORADA))
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
		# A baforada NASCE encostada na cara. Com o esmaecimento de 25 cm do
		# tufo comum, os primeiros trinta centimetros do jato — que e tudo o que
		# ele anda antes de frear — ficavam transparentes contra a caixa da
		# cabeca, e na casa (captura do jogo, tragada funda com baforada 1,0)
		# nao saia fumaca nenhuma da boca. Quatro centimetros bastam para a
		# borda do tufo nao cortar reto no rosto.
		m.proximity_fade_distance = 0.04
		_material_baforada = m
	else:
		_material = m
	return m


## O tufo para fumaca a um palmo da lente: some so a 4-18 cm do olho, e nao a
## 15-70.
static func _material_perto(baforada: bool) -> StandardMaterial3D:
	var chave := "perto_baforada" if baforada else "perto"
	if _materiais.has(chave):
		return _materiais[chave]
	var m := _material_do_tufo(baforada).duplicate() as StandardMaterial3D
	m.distance_fade_min_distance = 0.04
	m.distance_fade_max_distance = 0.18
	m.proximity_fade_distance = 0.03
	if baforada:
		m.emission = Color(0.06, 0.06, 0.06)
	_materiais[chave] = m
	return m


## A baforada da rua: a mesma, com um piso de luz de quase nada.
static func _material_de_rua() -> StandardMaterial3D:
	if _materiais.has("rua_baforada"):
		return _materiais["rua_baforada"]
	var m := _material_do_tufo(true).duplicate() as StandardMaterial3D
	m.emission = Color(0.05, 0.05, 0.05)
	_materiais["rua_baforada"] = m
	return m


# --- o fio ------------------------------------------------------------------

## O fio de fumaca de uma brasa parada.
##
## Fumaca de cigarro em ar parado nao e tufo: sobe como um FIO liso de dez,
## quinze centimetros, e so depois quebra em volutas que abrem e somem. Tufo
## redondo (o `CIGARRO`) le como algodao em cima da brasa — foi o que as
## capturas da casa mostravam. Aqui cada particula arrasta uma FITA do caminho
## que fez (trilha de particula do Godot): a fita nasce fina na brasa, alarga
## subindo, e a turbulencia entorta o caminho, que e o que desenha a voluta. As
## fitas de particulas seguidas se sobrepoem e leem como um fio so.
##
## A largura segue a escala da particula NO INSTANTE de cada pedaco da trilha:
## o pedaco de baixo e de quando ela era nova (fina), o de cima e de agora
## (larga). Nao ha curva de largura na fita, e nem precisa.
func _montar_fio() -> void:
	amount = 16
	lifetime = 3.0
	randomness = 0.25
	preprocess = 3.0
	trail_enabled = true
	trail_lifetime = 0.8
	var p := ParticleProcessMaterial.new()
	p.direction = Vector3.UP
	p.spread = 3.0
	p.initial_velocity_min = 0.06
	p.initial_velocity_max = 0.09
	# O ar quente sobe e acelera; a turbulencia so pega depois dos primeiros
	# centimetros, que e o trecho liso do fio.
	p.gravity = Vector3(0.0, 0.05, 0.0)
	p.damping_min = 0.01
	p.damping_max = 0.03
	p.turbulence_enabled = true
	# Escala pequena: as volutas de cigarro tem de dois a cinco centimetros.
	p.turbulence_noise_scale = 0.45
	p.turbulence_noise_strength = 0.85
	p.turbulence_noise_speed = Vector3(0.0, 0.3, 0.0)
	p.turbulence_noise_speed_random = 0.4
	p.turbulence_influence_min = 0.22
	p.turbulence_influence_max = 0.4
	p.turbulence_influence_over_life = _curva([Vector2(0.0, 0.0), Vector2(0.14, 0.05),
		Vector2(0.4, 0.8), Vector2(1.0, 1.0)])
	p.scale_min = 0.9
	p.scale_max = 1.1
	p.scale_curve = _curva([Vector2(0.0, 0.1), Vector2(0.35, 0.4), Vector2(1.0, 1.0)])
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.08, 0.45, 1.0])
	g.colors = PackedColorArray([
		Color(0.86, 0.87, 0.9, 0.0),
		Color(0.86, 0.87, 0.9, 0.34),
		Color(0.8, 0.81, 0.85, 0.16),
		Color(0.78, 0.79, 0.83, 0.0),
	])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	p.color_ramp = gt
	process_material = p

	var fita := RibbonTrailMesh.new()
	fita.shape = RibbonTrailMesh.SHAPE_CROSS
	fita.size = 0.028
	fita.sections = 6
	fita.section_length = 0.03
	fita.section_segments = 2
	fita.material = _material_do_fio()
	draw_pass_1 = fita
	visibility_aabb = AABB(Vector3(-0.6, -0.1, -0.6), Vector3(1.2, 1.4, 1.2))


## A fita do fio: macia nas duas bordas e nas duas pontas (a textura e feita
## aqui, e nao lida de arquivo: e um degrade de 16 x 32).
static func _material_do_fio() -> StandardMaterial3D:
	if _materiais.has("fio"):
		return _materiais["fio"]
	var img := Image.create(16, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		var v := (float(y) + 0.5) / 32.0
		var ponta := smoothstep(0.0, 0.25, v) * smoothstep(1.0, 0.6, v)
		for x in 16:
			var u := (float(x) + 0.5) / 16.0
			var borda := pow(maxf(0.0, 1.0 - absf(u * 2.0 - 1.0)), 2.2)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, borda * ponta))
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.use_particle_trails = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.disable_receive_shadows = true
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	# Um piso de luz: fumaca fina so aparece onde alguma luz a espalha, mas a
	# de cigarro espalha a da propria brasa e a do ambiente todo — sem piso,
	# no escuro da rua ela sumia no primeiro palmo.
	m.emission_enabled = true
	m.emission = Color(0.05, 0.05, 0.055)
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 0.05
	m.distance_fade_max_distance = 0.16
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_materiais["fio"] = m
	return m
