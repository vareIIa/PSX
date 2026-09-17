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

## Altitude e area em uso. Sao variaveis, e nao as constantes acima, porque o
## MODERNO pede uma camada mais alta e mais larga: a esfera de ar so le como
## volume quando ela cabe inteira no quadro, e a 28 m uma nuvem de 25 m de raio
## passa por cima da cabeca do jogador como um teto. Quem escreve e o
## `DiretorCeu`; o padrao continua sendo o do PS1.
@export var altitude: float = ALTITUDE
@export var area: Vector3 = AREA

## A luz que a cidade manda para a barriga da nuvem a noite: sodio, fraca.
const LUZ_DA_CIDADE := Color(0.95, 0.58, 0.30) * 0.22

## Velocidade da deriva do vento, em m/s.
const VENTO := 0.7

@export_range(20, 300, 10) var quantidade_max: int = 120
## Node3D seguido. Vazio faz as nuvens procurar a camera ativa.
@export var alvo: Node3D

var _mat: ShaderMaterial
var _deriva: float = 0.0
## Quanto o RUIDO andou, que nao e o mesmo que quanto o no andou. Ver `_process`.
var _ruido_andou: float = 0.0
## Camada congelada para foto. Ver `congelar`.
var _congelado := false



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
	# O grupo e como o `DiretorCeu` sabe que ja existe camada de nuvem na cena
	# sem varrer a arvore. Uma cena que traga a propria (a Estrada Velha tem ceu
	# proprio) entra no mesmo grupo e nao ganha uma segunda por cima.
	add_to_group(&"nuvens")
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
	visibility_aabb = AABB(Vector3.ONE * -area.x, Vector3.ONE * area.x * 2.0)
	# Semente FIXA: a mesma camada de nuvens em toda execucao. Sem isto cada
	# boot sorteia posicao e tamanho de novo, e a regressao visual da praca —
	# onde o ceu aparece acima da igreja — oscilava 12,6% dos blocos entre duas
	# execucoes da mesma build, no limite da tolerancia.
	use_fixed_seed = true
	seed = 20260916

	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = area
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


## Aplica um preset direto, sem controller de nevoa na cena.
##
## Existe para a bancada do ceu, que monta uma camera, uma luz e uma nuvem e
## mais nada: montar um `FogController` so para entregar um preset arrastaria o
## streaming e a escolha do menu para dentro de uma medida que nao tem nada a
## ver com nenhum dos dois.
func usar_preset(preset: FogPreset) -> void:
	_aplicar_preset(preset)


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
	if _mat == null:
		return

	# No MODERNO a cor sai da LUZ, e nao do contraste com o fundo.
	#
	# O contraste acima e uma regra de billboard pintado: sem iluminacao, a unica
	# forma de a nuvem existir e ser diferente do ceu. Com volume ela e iluminada
	# de verdade — o topo pega sol, a barriga pega ceu — e escurecer a cor base
	# por regra escureceria as duas metades juntas, desfazendo o que o raymarch
	# acabou de calcular.
	var volume := Settings.luz_por_pixel
	_mat.set_shader_parameter(&"usa_volume", volume)
	_mat.set_shader_parameter(&"cor_nuvem", Color.WHITE if volume else cor_base)
	_mat.set_shader_parameter(&"opacidade", clampf(cobertura * 0.85, 0.25, 0.85))
	if not volume:
		return

	# Direcao PARA o sol. A luz direcional aponta pelo -Z dela, entao o rumo da
	# fonte e o +Z da mesma base — a mesma conta que o `FogController` faz ao
	# montar a luz, e a partir do MESMO preset, para as duas nao divergirem.
	var base := Basis.from_euler(Vector3(
		deg_to_rad(preset.sol_rotacao.x), deg_to_rad(preset.sol_rotacao.y), 0.0))
	_mat.set_shader_parameter(&"rumo_do_sol", base.z.normalized())
	# A energia entra na COR, e nao num multiplicador proprio: a nuvem de noite
	# e a mesma massa com um centesimo da luz, e separar as duas coisas so
	# criaria um segundo botao para o mesmo efeito.
	_mat.set_shader_parameter(&"cor_do_sol",
		Color(preset.sol_cor.r, preset.sol_cor.g, preset.sol_cor.b, 1.0)
			* maxf(preset.sol_energia, 0.05))
	# De baixo: de dia o ceu devolvido; de noite a CIDADE, laranja de sodio.
	# A cor ambiente do preset nao serve para isto: na noite de chuva ela e
	# esverdeada por desenho da nevoa, e a camada saiu verde.
	# De dia, o proprio ceu: num dia nublado a abobada inteira ilumina a
	# barriga da nuvem, e com um cinza fixo ela saia mais escura que o fundo,
	# como fumaca.
	var de_baixo := preset.sky_color * 1.25 * maxf(preset.ambient_energy, 0.4)
	if preset.hora_do_dia == FogPreset.HoraDoDia.NOITE:
		de_baixo = LUZ_DA_CIDADE
	_mat.set_shader_parameter(&"cor_do_ceu", de_baixo)
	# Cobertura fechada e ar mais grosso: nublado nao e "mais nuvens", e nuvem
	# mais densa. Sem isto, 100% de cobertura empilhava quads translucidos e o
	# ceu ficava leitoso em vez de pesado.
	_mat.set_shader_parameter(&"extincao", lerpf(0.30, 0.62, cobertura))
	# Bruma do ceu a partir do fim da nevoa: 60 m (noite de chuva) esconde mais
	# da metade da camada, 130 m (dia nublado) um quarto, e ceu sem nevoa nada.
	# Calibrado nas fotos das rotas `ceu_dia` e `ceu_noite`: 130 m deixa um
	# quarto de bruma no alto, 60 m pouco mais da metade.
	var bruma := 0.0
	if preset.fog_enabled:
		bruma = clampf(0.25 + (130.0 - preset.fog_end) * 0.0043, 0.0, 0.8)
	_mat.set_shader_parameter(&"neblina_do_ceu", bruma)
	_mat.set_shader_parameter(&"corte", lerpf(0.42, 0.24, cobertura))


## Para o vento e a forma num instante fixo, para captura.
##
## A silhueta da nuvem com volume depende de HA QUANTO TEMPO a cena esta no ar:
## o ruido corre por dentro dela. Duas execucoes da mesma build chegam a mesma
## parada com relogios diferentes — e a regressao visual acusaria diferenca que
## nao existe, que e o mesmo defeito do carro que passa e do relampago.
func congelar(instante: float = 7.5) -> void:
	_congelado = true
	_deriva = fmod(instante * VENTO, area.x)
	_ruido_andou = instante * VENTO * 0.35
	if _mat != null and Settings.luz_por_pixel:
		_mat.set_shader_parameter(&"deriva",
			Vector3(_ruido_andou, _ruido_andou * 0.17, _ruido_andou * 0.42))


func _process(delta: float) -> void:
	var seguido := alvo
	if seguido == null:
		seguido = get_viewport().get_camera_3d()
	if seguido == null:
		return
	# A deriva do vento vive aqui: o no desliza devagar e as nuvens vao junto,
	# e a cada volta completa ele reenquadra na camera. Assim o ceu nunca fica
	# vazio nem precisa esperar particula nascer.
	if _congelado:
		delta = 0.0
	_deriva = fmod(_deriva + delta * VENTO, area.x)
	# A forma tambem anda, e num ritmo proprio: o no desliza com o vento e o
	# ruido corre por dentro dele mais devagar. Sem os dois, a nuvem atravessa o
	# ceu como um adesivo — mesma silhueta do comeco ao fim.
	if _mat != null and Settings.luz_por_pixel:
		_ruido_andou += delta * VENTO * 0.35
		_mat.set_shader_parameter(&"deriva",
			Vector3(_ruido_andou, _ruido_andou * 0.17, _ruido_andou * 0.42))
	global_position = Vector3(
		seguido.global_position.x + _deriva,
		seguido.global_position.y + altitude,
		seguido.global_position.z
	)
