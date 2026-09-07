## Nuvens. Volume de particulas horizontais sobre a camera.
##
## Cada particula e um quad grande semitransparente que representa uma porcao
## de massa de ar. O conjunto cria a ilusao de camada de nuvens ao redor do
## jogador, como os jogos PS1 faziam com planos horizontais moveis.
##
## A cobertura e a cor vem do FogPreset ativo:
##   - nuvens = 0.0  →  sem nuvens (preset dia ensolarado, noite estrelada)
##   - nuvens = 0.5  →  parcialmente nublado
##   - nuvens = 1.0  →  totalmente coberto (neblina)
##
## De dia as nuvens sao brancas/cinzas; a noite sao cinza-escuro. A cor e
## ajustada pela mistura entre sky_color do preset e branco.
class_name Nuvens
extends GPUParticles3D

const SHADER := "res://shaders/psx_nuvens.gdshader"

## Altitude das nuvens acima da camera em metros.
const ALTITUDE := 28.0
## Metade da area horizontal de emissao.
const AREA := Vector3(80.0, 2.0, 80.0)

## Velocidade da deriva do vento, em m/s.
const VENTO := 0.7

@export_range(20, 300, 10) var quantidade_max: int = 120
## Node3D seguido. Vazio faz as nuvens procurar a camera ativa.
@export var alvo: Node3D

var _mat: ShaderMaterial
var _deriva: float = 0.0



const FOG_GROUP := &"fog_controller"

## FogController da cena. E ele, nao Settings, que sabe o clima em vigor:
## dentro de um interior o controller impoe um preset proprio e a escolha de rua
## do jogador nao vale mais.
var _fog: FogController


## Liga este no ao preset em vigor. Sem controller na cena (cena de teste solta)
## cai em Settings, que ao menos reflete a escolha do jogador.
func _seguir_fog() -> void:
	_fog = get_tree().get_first_node_in_group(FOG_GROUP) as FogController
	if _fog != null:
		_fog.preset_applied.connect(_aplicar_preset)
	else:
		Settings.changed.connect(_aplicar_preset_de_settings)


func _aplicar_preset_de_settings() -> void:
	_aplicar_preset(Settings.fog_preset())


func _preset_ativo() -> FogPreset:
	return _fog.preset_atual() if _fog != null else Settings.fog_preset()

func _ready() -> void:
	_montar()
	_seguir_fog()
	_aplicar_preset(_preset_ativo())


func _montar() -> void:
	# Construcao igual a das estrelas, e por medida, nao por gosto: a versao
	# anterior emitia ao longo de 18 s de vida e `get_aabb()` voltava zerado no
	# primeiro segundo — nao havia nuvem nenhuma no mundo para desenhar. Aqui as
	# nuvens nascem todas de uma vez e ficam; a deriva do vento vem do proprio
	# no acompanhando a camera, nao da velocidade de cada particula.
	amount = quantidade_max
	lifetime = 9999.0
	one_shot = false
	explosiveness = 1.0
	randomness = 0.0
	fixed_fps = 0
	interpolate = false
	local_coords = true
	visibility_aabb = AABB(Vector3.ONE * -AREA.x, Vector3.ONE * AREA.x * 2.0)

	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = AREA
	proc.direction = Vector3(1.0, 0.0, 0.2)
	proc.spread = 0.0
	proc.gravity = Vector3.ZERO
	proc.initial_velocity_min = 0.0
	proc.initial_velocity_max = 0.0
	# Escala grande: cada quad representa um pedaco de nuvem.
	proc.scale_min = 12.0
	proc.scale_max = 28.0
	proc.color = Color(1.0, 1.0, 1.0, 1.0)
	process_material = proc

	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)   # escala via process material
	draw_pass_1 = quad

	_mat = ShaderMaterial.new()
	if ResourceLoader.exists(SHADER):
		_mat.shader = load(SHADER)
	else:
		push_error("Nuvens: shader ausente em %s" % SHADER)
	material_override = _mat


func _aplicar_preset(preset: FogPreset) -> void:
	if preset == null:
		return
	var cobertura := preset.nuvens

	# Sem nuvens: desliga emissao.
	if cobertura < 0.05:
		emitting = false
		visible = false
		return

	visible = true
	emitting = true
	amount = maxi(10, int(quantidade_max * cobertura))

	# A cor da nuvem sai do ceu por CONTRASTE, nunca por aproximacao. Misturar
	# nuvem com a cor do ceu, como fazia a versao anterior, produzia uma nuvem
	# da cor do fundo; a nevoa entao terminava o servico e empurrava o resto
	# para o mesmo tom. Nuvem que nao contrasta com o ceu nao e nuvem, e ceu.
	#
	# Em ceu claro a nuvem e mais escura que ele; em ceu noturno, mais clara.
	# Nos dois casos o afastamento e o mesmo, e o que muda e so a direcao.
	var ceu := preset.sky_color
	var claro := ceu.get_luminance() > 0.32
	var cor_base := ceu.darkened(0.34) if claro else ceu.lightened(0.30)
	if _mat != null:
		_mat.set_shader_parameter(&"cor_nuvem", cor_base)
		_mat.set_shader_parameter(&"opacidade", clampf(cobertura * 0.85, 0.25, 0.85))


func _process(delta: float) -> void:
	var seguido := alvo
	if seguido == null:
		seguido = get_viewport().get_camera_3d()
	if seguido == null:
		return
	# A deriva do vento vive aqui: o no desliza devagar e as nuvens vao junto,
	# e a cada volta completa ele reenquadra na camera. Assim o ceu nunca fica
	# vazio nem precisa esperar particula nascer.
	_deriva = fmod(_deriva + delta * VENTO, AREA.x)
	global_position = Vector3(
		seguido.global_position.x + _deriva,
		seguido.global_position.y + ALTITUDE,
		seguido.global_position.z
	)
