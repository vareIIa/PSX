## A aura negra dos padres: fumaca preta que sobe devagar e se enrola em volta
## do corpo, e que depois entra no carro.
##
## Por que existe
## --------------
## O padre parado na estrada era uma pessoa de preto. Com a aura ele e uma
## mancha que o farol nao consegue clarear: o facho bate, a chuva brilha, e em
## volta dele o ar continua escuro e se mexendo. E a mesma treva que depois
## passa pelas frestas da porta enquanto o telefone esta caido no tapete.
##
## Como e feita
## ------------
## Particulas de GPU em billboard, pretas, com a transparencia de uma textura de
## fumaca feita aqui (ruido dentro de um disco macio). Nascem numa caixa, sobem,
## sao torcidas por turbulencia e somem. Fade de proximidade: onde a fumaca
## encosta no chao, no corpo ou no banco ela esmaece, e nao corta em linha reta.
## Em coordenada de mundo: o que ja saiu fica no ar quando o dono se mexe.
##
## `forca` doseia por `amount_ratio`, e nao por `amount`: trocar `amount`
## reinicia o sistema e a fumaca some de uma vez.
class_name AuraNegra
extends GPUParticles3D

## Cor da fumaca: quase preto, puxado para o vinho. Preto puro some no preto
## do fundo; com um fio de cor ele se le contra o mato escuro.
const COR := Color(0.018, 0.006, 0.010)

var forca: float = 1.0:
	set(v):
		forca = clampf(v, 0.0, 1.0)
		amount_ratio = forca

static var _textura: ImageTexture


## Uma aura dentro da caixa `tamanho` (centrada na origem do no), com
## `quantidade` baforadas de `baforada` metros.
static func criar(tamanho: Vector3, quantidade: int = 40, baforada: float = 0.9,
		vida: float = 3.2) -> AuraNegra:
	var a := AuraNegra.new()
	a.name = "AuraNegra"
	a.amount = quantidade
	a.lifetime = vida
	a.preprocess = vida
	a.local_coords = false
	a.fixed_fps = 30
	a.visibility_aabb = AABB(-tamanho * 1.5 - Vector3.ONE, tamanho * 3.0 + Vector3.ONE * 2.0)
	a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var q := QuadMesh.new()
	q.size = Vector2(baforada, baforada)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_color = COR
	m.albedo_texture = _fumaca()
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 0.35
	q.material = m
	a.draw_pass_1 = q

	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.emission_box_extents = tamanho * 0.5
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.03
	p.initial_velocity_max = 0.16
	p.gravity = Vector3(0.0, 0.05, 0.0)
	p.damping_min = 0.2
	p.damping_max = 0.5
	p.turbulence_enabled = true
	p.turbulence_noise_strength = 1.4
	p.turbulence_noise_scale = 1.8
	p.turbulence_noise_speed_random = 0.4
	p.turbulence_influence_min = 0.06
	p.turbulence_influence_max = 0.14
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -18.0
	p.angular_velocity_max = 18.0
	p.scale_min = 0.6
	p.scale_max = 1.35
	var cresce := Curve.new()
	cresce.add_point(Vector2(0.0, 0.45))
	cresce.add_point(Vector2(1.0, 1.25))
	var ct := CurveTexture.new()
	ct.curve = cresce
	p.scale_curve = ct
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.22, Color(1, 1, 1, 0.85))
	g.add_point(0.65, Color(1, 1, 1, 0.65))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	p.color_ramp = gt
	a.process_material = p
	return a


## A revoada: fiapos de treva voando entre os encapuzados, rente ao chao e a
## altura das cabecas, fazendo curva em volta deles. Cada um e uma fita com
## rastro (`RibbonTrailMesh` em cruz, para nao sumir de perfil), preta e
## esfiapada nas pontas; a turbulencia forte e que faz a curva.
static func revoada(tamanho: Vector3, quantidade: int = 90, vida: float = 3.4) -> AuraNegra:
	var a := AuraNegra.new()
	a.name = "Revoada"
	a.amount = quantidade
	a.lifetime = vida
	a.preprocess = vida
	a.local_coords = false
	a.fixed_fps = 30
	a.trail_enabled = true
	a.trail_lifetime = 0.85
	a.visibility_aabb = AABB(-tamanho * 0.5 - Vector3.ONE * 6.0, tamanho + Vector3.ONE * 12.0)
	a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var fita := RibbonTrailMesh.new()
	fita.shape = RibbonTrailMesh.SHAPE_CROSS
	fita.size = 0.55
	fita.sections = 8
	fita.section_length = 0.25
	fita.section_segments = 2
	var afina := Curve.new()
	afina.add_point(Vector2(0.0, 0.1))
	afina.add_point(Vector2(0.35, 1.0))
	afina.add_point(Vector2(1.0, 0.0))
	fita.curve = afina
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.use_particle_trails = true
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(COR.r, COR.g, COR.b, 0.8)
	m.albedo_texture = _fiapo()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 0.4
	fita.material = m
	a.draw_pass_1 = fita

	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.emission_box_extents = tamanho * 0.5
	p.direction = Vector3.RIGHT
	p.spread = 180.0
	p.flatness = 0.85
	p.initial_velocity_min = 1.4
	p.initial_velocity_max = 3.2
	p.gravity = Vector3(0.0, 0.08, 0.0)
	p.damping_min = 0.05
	p.damping_max = 0.2
	p.turbulence_enabled = true
	p.turbulence_noise_strength = 4.0
	p.turbulence_noise_scale = 3.2
	p.turbulence_noise_speed_random = 0.6
	p.turbulence_influence_min = 0.25
	p.turbulence_influence_max = 0.55
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.15, Color(1, 1, 1, 0.9))
	g.add_point(0.75, Color(1, 1, 1, 0.7))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	p.color_ramp = gt
	a.process_material = p
	return a


## A fumaca corre para `direcao` a `velocidade` m/s, sem subir: e a treva
## passando pela fresta da porta e escorrendo pelo tapete.
func escorrer(direcao: Vector3, velocidade: float) -> void:
	var p := process_material as ParticleProcessMaterial
	p.direction = direcao.normalized()
	p.spread = 35.0
	p.initial_velocity_min = velocidade * 0.6
	p.initial_velocity_max = velocidade * 1.2
	p.gravity = Vector3(0.0, 0.02, 0.0)


## Liga a aura ja formada em volta do dono: o `preprocess` roda de novo, e o que
## tinha ficado no ar de outro lugar some.
func acender(k: float = 1.0) -> void:
	forca = k
	emitting = true
	restart()


static func _fumaca() -> ImageTexture:
	if _textura != null:
		return _textura
	# 160 px e cinco oitavas, com o ruido torcido por outro: a meio metro da
	# lente a baforada de 96 px lia como um disco borrado com manchas.
	var n := 160
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var ruido := FastNoiseLite.new()
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.fractal_type = FastNoiseLite.FRACTAL_FBM
	ruido.fractal_octaves = 5
	ruido.frequency = 0.028
	ruido.domain_warp_enabled = true
	ruido.domain_warp_amplitude = 22.0
	ruido.domain_warp_frequency = 0.02
	ruido.seed = 1077
	for y in n:
		for x in n:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5) / float(n) * 2.0 - Vector2.ONE
			var disco := clampf(1.0 - p.length(), 0.0, 1.0)
			var v := ruido.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var alfa := clampf(pow(disco, 1.1) * smoothstep(0.28, 0.85, v) * 1.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alfa))
	img.generate_mipmaps()
	_textura = ImageTexture.create_from_image(img)
	return _textura


static var _textura_fiapo: ImageTexture


## A fita da revoada: esfiapada nas bordas (u) e rasgada ao longo (v).
static func _fiapo() -> ImageTexture:
	if _textura_fiapo != null:
		return _textura_fiapo
	var w := 64
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var ruido := FastNoiseLite.new()
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.fractal_type = FastNoiseLite.FRACTAL_FBM
	ruido.fractal_octaves = 4
	ruido.frequency = 0.05
	ruido.seed = 4077
	for y in h:
		for x in w:
			var u := (float(x) + 0.5) / float(w) * 2.0 - 1.0
			var v := ruido.get_noise_2d(float(x) * 1.6, float(y) * 0.45) * 0.5 + 0.5
			var miolo := 1.0 - smoothstep(0.15 + v * 0.5, 1.0, absf(u))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(miolo * smoothstep(0.25, 0.7, v) * 1.4,
				0.0, 1.0)))
	img.generate_mipmaps()
	_textura_fiapo = ImageTexture.create_from_image(img)
	return _textura_fiapo
