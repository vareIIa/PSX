## Chuva. Caixa de particulas que acompanha a camera.
##
## A chuva nao e simulada no mundo, e um volume pequeno colado na camera. E o que
## todo jogo faz, e o que o PS1 fazia: simular chuva num raio de 500 m para ver
## 20 m dela seria pagar caro por nada.
##
## A intensidade cai com a nevoa. Em nevoa densa a visibilidade e de 18 m e o
## risco de chuva simplesmente nao aparece; insistir nele so custa preenchimento.
class_name Chuva
extends GPUParticles3D

const SHADER := "res://shaders/psx_chuva.gdshader"

## Metade da caixa de emissao, em metros.
const CAIXA := Vector3(11.0, 1.0, 11.0)
## Altura da caixa acima da camera.
const ALTURA := 9.0

@export_range(0, 3000, 50) var quantidade: int = 950
@export_range(0.0, 3.0, 0.05) var forca: float = 0.55
## Node3D seguido. Vazio faz a chuva procurar a camera ativa.
@export var alvo: Node3D

var _mat: ShaderMaterial


func _ready() -> void:
	_montar()
	Settings.changed.connect(_aplicar_preset)
	_aplicar_preset()


func _montar() -> void:
	amount = quantidade
	lifetime = 0.9
	preprocess = 0.9        # ja comeca chovendo, sem meio segundo de ceu limpo
	explosiveness = 0.0
	randomness = 1.0
	fixed_fps = 30          # ART-BIBLE secao 10: nada anima a 60 aqui
	interpolate = false
	local_coords = false
	visibility_aabb = AABB(-CAIXA - Vector3(0, ALTURA, 0), (CAIXA + Vector3(0, ALTURA, 0)) * 2.0)
	draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH

	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = CAIXA
	proc.direction = Vector3(0.0, -1.0, 0.0)
	proc.spread = 2.0
	proc.initial_velocity_min = 13.0
	proc.initial_velocity_max = 17.0
	proc.gravity = Vector3(0.0, -6.0, 0.0)
	# Vento leve e constante. Chuva perfeitamente vertical parece cenario de
	# tutorial; um angulo pequeno ja da a sensacao de tempo ruim.
	proc.linear_accel_min = 0.4
	proc.linear_accel_max = 0.9
	proc.color = Color(1.0, 1.0, 1.0, 1.0)
	proc.scale_min = 0.7
	proc.scale_max = 1.25
	process_material = proc

	# Quad alto e fino: o risco vem da forma, nao de motion blur.
	var quad := QuadMesh.new()
	quad.size = Vector2(0.028, 0.42)
	quad.orientation = PlaneMesh.FACE_Z
	draw_pass_1 = quad

	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER)
	material_override = _mat

	# Alinhado ao movimento: o risco aponta para onde a gota cai, e nunca deita,
	# porque chuva deitada nao existe.
	proc.particle_flag_align_y = true


func _aplicar_preset() -> void:
	var preset := Settings.fog_preset()
	# Sem nevoa a chuva aparece inteira; com nevoa densa ela some atras dela.
	var f := 1.0
	if preset.fog_enabled:
		f = clampf(remap(preset.fog_end, 18.0, 45.0, 0.25, 0.8), 0.2, 1.0)
	emitting = f > 0.05
	amount = maxi(50, int(quantidade * f))
	if _mat != null:
		_mat.set_shader_parameter(&"intensidade", forca * f)


func _process(_delta: float) -> void:
	var seguido := alvo
	if seguido == null:
		seguido = get_viewport().get_camera_3d()
	if seguido == null:
		return
	# So a posicao, nunca a rotacao: a caixa girando junto com a cabeca faz a
	# chuva parecer presa ao olhar.
	global_position = seguido.global_position + Vector3(0.0, ALTURA, 0.0)
