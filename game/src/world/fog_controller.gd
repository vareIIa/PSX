## Aplica o FogPreset ativo ao ambiente. Anexe a um WorldEnvironment.
##
## A nevoa mora no Environment e nao num shader de superficie porque precisa
## incidir depois da iluminacao. Ver docs/ART-BIBLE.md secao 8.
class_name FogController
extends WorldEnvironment

## Quando ligado, segue o preset escolhido pelo jogador em Settings.
## Desligue em interior, onde a nevoa e sempre off e a grade e propria.
@export var follow_settings: bool = true

## Preset usado quando follow_settings esta desligado.
@export var override_preset: FogPreset

## Raio de streaming em metros do preset em uso. O ChunkManager le daqui.
var stream_radius: float = 64.0

## Preset imposto por cima de tudo. Nulo devolve o controle ao jogador.
var _forcado: FogPreset

signal preset_applied(preset: FogPreset)


func _ready() -> void:
	add_to_group(&"fog_controller")
	if environment == null:
		environment = Environment.new()
	if follow_settings:
		Settings.changed.connect(_on_settings_changed)
	_apply()


func _on_settings_changed() -> void:
	_apply()


func _apply() -> void:
	var preset := _resolve_preset()
	if preset == null:
		push_error("FogController em %s: nenhum preset resolvido" % name)
		return

	var env := environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = preset.sky_color

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = preset.ambient_color
	env.ambient_light_energy = preset.ambient_energy

	env.fog_enabled = preset.fog_enabled
	if preset.fog_enabled:
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_depth_begin = preset.fog_begin
		env.fog_depth_end = preset.fog_end
		env.fog_depth_curve = 1.0
		env.fog_light_color = preset.fog_color
		env.fog_light_energy = 1.0
		env.fog_density = 1.0

	# Nada de glow, SSAO ou SSR. O PS1 nao tinha e eles modernizam o look na hora.
	env.glow_enabled = false
	env.ssao_enabled = false
	env.ssr_enabled = false
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false

	stream_radius = preset.stream_radius
	preset_applied.emit(preset)


## Impoe um preset por cima da escolha do jogador. Usado ao entrar num interior,
## onde a nevoa da rua nao faz sentido e o ambiente e propriedade do lugar.
func forcar(caminho: String) -> void:
	if not ResourceLoader.exists(caminho):
		push_error("FogController: preset ausente %s" % caminho)
		return
	_forcado = load(caminho) as FogPreset
	_apply()


func liberar() -> void:
	_forcado = null
	_apply()


func _resolve_preset() -> FogPreset:
	if _forcado != null:
		return _forcado
	if follow_settings:
		return Settings.fog_preset()
	return override_preset
