## Liga o Settings aos uniforms do post_psx.gdshader. Anexe ao ColorRect da
## camada de pos-processo.
##
## O ColorRect precisa ficar num CanvasLayer acima da cena 3D e cobrir a tela
## inteira. A grade de cor vem do FogPreset ativo, nao do Settings, porque ela e
## propriedade do ambiente e nao preferencia do jogador.
class_name PSXPost
extends ColorRect

## ART-BIBLE secao 2
const INTERNAL_RES := Vector2(480.0, 270.0)
## ART-BIBLE secao 5 — 32 niveis por canal = 5 bits = 15 bits de framebuffer
const COLOR_LEVELS := 32.0

## Opcional. Vazio faz o rig procurar o FogController pelo grupo, o que deixa
## esta cena instanciavel em qualquer nivel sem religar referencia na mao.
@export var fog_controller: FogController

## Grupo em que todo FogController se registra.
const FOG_GROUP := &"fog_controller"

var _mat: ShaderMaterial


func _ready() -> void:
	_mat = material as ShaderMaterial
	if _mat == null:
		push_error("PSXPost em %s: material precisa ser um ShaderMaterial" % name)
		set_process(false)
		return

	_mat.set_shader_parameter(&"internal_res", INTERNAL_RES)
	_mat.set_shader_parameter(&"color_levels", COLOR_LEVELS)

	Settings.changed.connect(_apply_settings)

	if fog_controller == null:
		fog_controller = get_tree().get_first_node_in_group(FOG_GROUP) as FogController
	if fog_controller != null:
		fog_controller.preset_applied.connect(_apply_grade)
		_apply_grade(Settings.fog_preset())

	_apply_settings()


func _apply_settings() -> void:
	_mat.set_shader_parameter(&"chromatic", Settings.chromatic)
	_mat.set_shader_parameter(&"grain", Settings.grain)
	_mat.set_shader_parameter(&"scanline", Settings.scanline)
	_mat.set_shader_parameter(&"vignette", Settings.vignette)
	_mat.set_shader_parameter(&"use_dither", Settings.dither)


func _apply_grade(preset: FogPreset) -> void:
	if preset == null:
		return
	_mat.set_shader_parameter(&"saturation", preset.saturation)
	_mat.set_shader_parameter(&"grade_tint", preset.grade_tint)
