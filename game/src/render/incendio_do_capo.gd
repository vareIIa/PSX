## O motor pegando fogo depois da batida: vapor e fumaca saindo do capo, e
## depois a chama, com a luz dela tremendo dentro da cabine.
##
## Tres emissores e uma luz, e nada mais: e o que o para-brisa deixa ver, e o
## orcamento da cena ja esta no fim na batida (etapa 9). A fumaca e o mesmo tufo
## da `FumacaParticulas` (`fx_fumaca_puff.png`), escura e ILUMINADA — o farol
## e o proprio fogo a acendem por baixo, e o resto dela some no escuro, como
## fumaca de verdade a noite. A chama e o mesmo tufo em soma, sem luz: ela e a
## luz. As brasas sao faisca que sobe e apaga.
##
## Tudo em coordenada de mundo: o carro esta parado na arvore, e o vento
## da chuva entorta a coluna para o lado.
##
## Quem dosa e a cena: `fumegar` e `pegar_fogo` recebem de 0 a 1 e animam ate
## la, e o resto (o tremor da luz, a quantidade de particula) sai disso.
class_name IncendioDoCapo
extends Node3D

const TEXTURA := "res://assets/textures/fx_fumaca_puff.png"
## A luz do fogo: cor, energia cheia e alcance. Sem sombra — a luz nasce
## dentro do cofre e a lataria ja faz a sombra que importa (o capo tapa o
## chao da frente); sombra de omni custa seis passes.
const LUZ_COR := Color(1.0, 0.52, 0.18)
const LUZ_ENERGIA := 9.0
const LUZ_ALCANCE := 9.0
## O vento empurrando a fumaca, em m/s^2 (mundo).
const VENTO := Vector3(0.35, 0.0, 0.12)

var _fumaca: GPUParticles3D
var _chama: GPUParticles3D
var _brasa: GPUParticles3D
var _luz: OmniLight3D
var _t: float = 0.0
var fumaca: float = 0.0:
	set(v):
		fumaca = clampf(v, 0.0, 1.0)
		if _fumaca != null:
			_fumaca.emitting = fumaca > 0.01
			_fumaca.amount_ratio = maxf(0.05, fumaca)
var fogo: float = 0.0:
	set(v):
		fogo = clampf(v, 0.0, 1.0)
		if _chama != null:
			_chama.emitting = fogo > 0.01
			_chama.amount_ratio = maxf(0.05, fogo)
			_brasa.emitting = fogo > 0.3
			_luz.visible = fogo > 0.01


func _ready() -> void:
	_fumaca = _emissor(48, 4.2, _mat_fumaca(), _processo_fumaca(), 1.0)
	_chama = _emissor(70, 0.75, _mat_chama(), _processo_chama(), 0.45)
	_brasa = _emissor(24, 1.6, _mat_brasa(), _processo_brasa(), 0.035)
	_luz = OmniLight3D.new()
	_luz.light_color = LUZ_COR
	_luz.omni_range = LUZ_ALCANCE
	_luz.omni_attenuation = 1.4
	_luz.shadow_enabled = false
	_luz.light_energy = 0.0
	_luz.position = Vector3(0.0, 0.35, 0.0)
	_luz.visible = false
	add_child(_luz)
	fumaca = 0.0
	fogo = 0.0


## Anima a fumaca ate `alvo` em `duracao` segundos.
func fumegar(alvo: float, duracao: float) -> void:
	create_tween().tween_property(self, "fumaca", alvo, duracao) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


## A chama pega: sobe de onde esta ate `alvo`. Pega depressa e cresce devagar.
func pegar_fogo(alvo: float, duracao: float) -> void:
	var t := create_tween()
	t.tween_property(self, "fogo", minf(alvo, 0.35), 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	t.tween_property(self, "fogo", alvo, maxf(0.01, duracao - 0.25)) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	_t += delta
	if fogo <= 0.01:
		return
	# A chama tremendo: tres senos desencontrados e um sopro lento. Uma luz de
	# fogo que so pulsa num ritmo le como pisca-pisca.
	var f := 0.72 + 0.12 * sin(_t * 11.3) + 0.09 * sin(_t * 17.9 + 1.3) \
		+ 0.07 * sin(_t * 5.1 + 0.4) + 0.1 * sin(_t * 1.3)
	_luz.light_energy = LUZ_ENERGIA * fogo * f
	_luz.position = Vector3(0.05 * sin(_t * 7.0), 0.35 + 0.06 * sin(_t * 9.0 + 2.0), 0.0)


func _emissor(n: int, vida: float, mat: Material, proc: ParticleProcessMaterial,
		tamanho: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = n
	p.lifetime = vida
	p.local_coords = false
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.process_material = proc
	var q := QuadMesh.new()
	q.size = Vector2(tamanho, tamanho)
	q.material = mat
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-4.0, -1.0, -4.0), Vector3(8.0, 8.0, 8.0))
	add_child(p)
	return p


func _processo_fumaca() -> ParticleProcessMaterial:
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.45, 0.05, 0.35)
	p.direction = Vector3.UP
	p.spread = 14.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.0
	p.gravity = Vector3(0.0, 0.25, 0.0) + VENTO
	p.damping_min = 0.15
	p.damping_max = 0.35
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -25.0
	p.angular_velocity_max = 25.0
	p.turbulence_enabled = true
	p.turbulence_noise_scale = 3.0
	p.turbulence_noise_strength = 0.6
	p.turbulence_influence_min = 0.05
	p.turbulence_influence_max = 0.15
	p.scale_min = 0.6
	p.scale_max = 1.1
	p.scale_curve = FumacaParticulas._curva([Vector2(0.0, 0.35), Vector2(0.4, 1.2),
		Vector2(1.0, 2.6)])
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.1, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0.30, 0.29, 0.28, 0.0),
		Color(0.26, 0.25, 0.24, 0.55), Color(0.20, 0.20, 0.20, 0.35),
		Color(0.16, 0.16, 0.17, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	p.color_ramp = gt
	return p


func _processo_chama() -> ParticleProcessMaterial:
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.38, 0.03, 0.25)
	p.direction = Vector3.UP
	p.spread = 8.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.3
	p.gravity = Vector3(0.0, 1.6, 0.0) + VENTO * 0.6
	p.damping_min = 0.4
	p.damping_max = 0.9
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	p.turbulence_enabled = true
	p.turbulence_noise_scale = 4.5
	p.turbulence_noise_strength = 0.9
	p.turbulence_noise_speed = Vector3(0.0, 1.2, 0.0)
	p.turbulence_influence_min = 0.1
	p.turbulence_influence_max = 0.25
	p.scale_min = 0.7
	p.scale_max = 1.3
	# Nasce larga na base e afina subindo: e a forma de lingua da chama.
	p.scale_curve = FumacaParticulas._curva([Vector2(0.0, 0.6), Vector2(0.25, 1.0),
		Vector2(1.0, 0.25)])
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.08, 0.3, 0.65, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.92, 0.62, 0.0),
		Color(1.0, 0.82, 0.45, 0.9), Color(1.0, 0.50, 0.14, 0.75),
		Color(0.75, 0.20, 0.05, 0.35), Color(0.25, 0.06, 0.02, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	p.color_ramp = gt
	return p


func _processo_brasa() -> ParticleProcessMaterial:
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.35, 0.05, 0.25)
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.8
	p.gravity = Vector3(0.0, 0.4, 0.0) + VENTO * 2.0
	p.turbulence_enabled = true
	p.turbulence_noise_scale = 2.0
	p.turbulence_noise_strength = 1.4
	p.turbulence_influence_min = 0.2
	p.turbulence_influence_max = 0.5
	p.scale_min = 0.4
	p.scale_max = 1.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.8, 0.4, 1.0), Color(1.0, 0.4, 0.1, 0.8),
		Color(0.6, 0.1, 0.02, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	p.color_ramp = gt
	return p


## A fumaca: o tufo da `FumacaParticulas`, iluminado, escuro.
func _mat_fumaca() -> StandardMaterial3D:
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
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 0.3
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


## A chama: o mesmo tufo, somado e sem luz. A cor vem da rampa.
func _mat_chama() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = load(TEXTURA) as Texture2D
	# Mais forte que 1: a chama tem de estourar um pouco no bloom, que e o que
	# a camera de verdade faz com fogo a noite.
	m.albedo_color = Color(2.2, 2.0, 1.8, 1.0)
	m.disable_receive_shadows = true
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 0.2
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


## A brasa: um ponto quente e pequeno, sem textura.
func _mat_brasa() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(3.0, 2.2, 1.4, 1.0)
	m.albedo_texture = load(TEXTURA) as Texture2D
	return m
