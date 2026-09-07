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


## Som da chuva. Quem manda nele e este no, e nao a cena.
##
## Antes a cidade ligava o loop no _ready com volume fixo, e ele nunca mais era
## consultado: chovia no ouvido em preset de sol, e nao mudava de forca quando a
## chuva apertava. Duas verdades sobre o mesmo clima em dois arquivos, e so uma
## delas olhava o preset.
const SOM := &"chuva_loop"
## Volume do aguaceiro cheio, em dB.
const VOL_CHEIO := -13.0
## Praticamente mudo. Nao e `parar_ambiente` porque o loop fica sempre no ar: um
## tocador que para e volta reabre o som do comeco, e o corte se ouve.
const VOL_MUDO := -60.0
## Quanto o volume anda por segundo, em dB. Chuva que entra e sai por corte le
## como bug; por rampa le como porta fechando.
const FADE := 16.0

## Ondas lentas de intensidade, em segundos.
##
## E aqui que a chuva deixa de soar como amostra em ciclo. O arquivo e ruido sem
## nenhum evento reconhecivel — nao ha estalo nem gota que se possa reconhecer
## voltando —, mas ruido de volume constante o ouvido tambem cansa em meio
## minuto e passa a ouvir "o loop". Duas ondas de periodo primo entre si sobre o
## volume dao um aguaceiro que aperta e afrouxa e que so se repete de verdade a
## cada onze minutos, que e mais tempo do que qualquer um passa parado na chuva.
const ONDA_LONGA := 41.0
const ONDA_CURTA := 17.0
## Amplitude da onda longa, em dB. A curta vale metade disto.
const ONDA_DB := 3.2

const FOG_GROUP := &"fog_controller"

## FogController da cena. E ele, nao Settings, que sabe o clima em vigor:
## dentro de um interior o controller impoe um preset proprio e a escolha de rua
## do jogador nao vale mais.
var _fog: FogController

## Forca da chuva em vigor, de 0 a 1. Sai do preset e alimenta som e particula.
var _intensidade: float = 0.0
var _volume: float = VOL_MUDO
var _relogio: float = 0.0


## Liga este no ao preset em vigor. Sem controller na cena (cena de teste solta)
## cai em Settings, que ao menos reflete a escolha do jogador.
func _seguir_fog() -> void:
	_fog = get_tree().get_first_node_in_group(FOG_GROUP) as FogController
	if _fog != null:
		_fog.preset_applied.connect(_aplicar_preset)
	else:
		Settings.changed.connect(_aplicar_preset_de_settings)


## Leva o loop embora junto com a cena. Sem isto a chuva continua tocando na
## proxima cena, onde nao ha nem particula nem quem baixe o volume dela.
func _exit_tree() -> void:
	AudioDirector.parar_ambiente(SOM)


func _aplicar_preset_de_settings() -> void:
	_aplicar_preset(Settings.fog_preset())


func _preset_ativo() -> FogPreset:
	return _fog.preset_atual() if _fog != null else Settings.fog_preset()

func _ready() -> void:
	_montar()
	_seguir_fog()
	_aplicar_preset(_preset_ativo())
	# Entra mudo e sobe pela rampa do _process. Ligar aqui no volume final faria
	# a chuva estourar no primeiro quadro da cena, antes de a cidade aparecer.
	AudioDirector.ambiente(SOM, VOL_MUDO)


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


func _aplicar_preset(preset: FogPreset) -> void:
	if preset == null:
		return
	# Clima sem chuva: desliga tudo imediatamente.
	if not preset.tem_chuva:
		_intensidade = 0.0
		emitting = false
		amount = 50
		if _mat != null:
			_mat.set_shader_parameter(&"intensidade", 0.0)
		return
	# Com chuva: a intensidade ainda cai com a nevoa. Em nevoa densa a
	# visibilidade e de 18 m e o risco de chuva simplesmente nao aparece;
	# insistir nele so custa preenchimento.
	var f := 1.0
	if preset.fog_enabled:
		f = clampf(remap(preset.fog_end, 18.0, 45.0, 0.25, 0.8), 0.2, 1.0)
	_intensidade = f
	emitting = f > 0.05
	amount = maxi(50, int(quantidade * f))
	if _mat != null:
		_mat.set_shader_parameter(&"intensidade", forca * f)


func _process(delta: float) -> void:
	_atualizar_som(delta)
	var seguido := alvo
	if seguido == null:
		seguido = get_viewport().get_camera_3d()
	if seguido == null:
		return
	# So a posicao, nunca a rotacao: a caixa girando junto com a cabeca faz a
	# chuva parecer presa ao olhar.
	global_position = seguido.global_position + Vector3(0.0, ALTURA, 0.0)


## Volume do loop de chuva neste quadro.
##
## O preset da o teto e as duas ondas dizem onde ele esta dentro dele. Sem chuva
## no preset o alvo e o silencio, e a rampa cuida da transicao — inclusive a de
## entrar num interior, onde o FogController impoe o preset do comodo e a chuva
## some do lado de fora da porta em pouco mais de tres segundos.
func _atualizar_som(delta: float) -> void:
	_relogio += delta
	var alvo_db := VOL_MUDO
	if _intensidade > 0.05:
		# A onda curta entra com metade da amplitude e fora de fase: e o que
		# impede as duas de baterem sempre no mesmo pico.
		var onda := sin(TAU * _relogio / ONDA_LONGA) * ONDA_DB
		onda += sin(TAU * _relogio / ONDA_CURTA + 1.3) * ONDA_DB * 0.5
		alvo_db = VOL_CHEIO + linear_to_db(_intensidade) * 0.6 + onda
	_volume = move_toward(_volume, alvo_db, FADE * delta)
	AudioDirector.volume_ambiente(SOM, _volume)
