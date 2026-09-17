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
## Sem dither, nao ha corte: 256 niveis, que e o que a tela ja tem.
##
## O corte de 15 bits e o pontilhado sao UMA coisa no PS1: o console escrevia
## pontilhado num framebuffer de 15 bits, e o pontilhado existia para esconder
## o corte. O MODERNO desliga o pontilhado e herdava o corte sozinho — 32 niveis
## sem nada por cima, ou seja, faixa. Medido na rota `ceu_dia`: a borda de uma
## nuvem contra o ceu nublado saiu em degraus largos, e como cada canal vira de
## nivel num ponto diferente, os degraus sairam coloridos.
const COLOR_LEVELS_SEM_DITHER := 256.0

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
	_mat.set_shader_parameter(&"color_levels",
		COLOR_LEVELS if Settings.dither else COLOR_LEVELS_SEM_DITHER)


func _apply_grade(preset: FogPreset) -> void:
	if preset == null:
		return
	_mat.set_shader_parameter(&"saturation", preset.saturation)
	_mat.set_shader_parameter(&"grade_tint", preset.grade_tint)
