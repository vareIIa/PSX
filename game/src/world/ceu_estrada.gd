## O poente da estrada. Uma cupula presa na camera, com o degrade no shader.
##
## Segue a camera, e nao o carro
## -----------------------------
## Porque a cena tem tres cameras: a de dentro do carro, a que voa acima da
## copa e a que fica parada na beira vendo o carro passar. Um ceu preso ao carro
## sairia de quadro nas duas ultimas — a cupula tem 150 m e a camera alta esta a
## trinta metros do capo, o que basta para a borda de baixo entrar na imagem.
## Preso a camera corrente, nunca entra.
##
## O horizonte NAO e escolhido aqui
## --------------------------------
## Ele vem do preset de nevoa em vigor, sempre. E a regra do ART-BIBLE secao 8:
## na altura do olho a cor do ceu tem de ser exatamente a da nevoa, senao a
## juncao vira uma linha reta atravessada no fundo do quadro e o corte de
## desenho fica anunciado. O degrade so existe ACIMA dessa altura, que e onde
## nao ha mais mata para casar com nada.
class_name CeuEstrada
extends Node3D

const SHADER := "res://shaders/psx_ceu_estrada.gdshader"

## Raio da cupula. Tem de caber dentro do `far` de toda camera da cena — o
## `near`/`far` da camera cinematica e 0,05/600, e a de dentro do carro fica em
## 260. Cento e cinquenta passa folgado nas duas e nao chega perto do plano de
## corte, onde o quad seria fatiado no meio.
const RAIO := 150.0
## Vinte e quatro lados. O degrade e calculado por pixel, entao a malha so
## precisa ser redonda o bastante para a interpolacao da direcao nao facetar —
## e nao para desenhar a forma do ceu.
const LADOS := 24
const ANEIS := 12

## Tons do poente. O horizonte fica de fora de proposito: ver o cabecalho.
const BRASA := Color(0.94, 0.53, 0.26)
const ZENITE := Color(0.19, 0.18, 0.31)
const NUVEM := Color(0.35, 0.30, 0.37)

var _malha: MeshInstance3D
var _mat: ShaderMaterial
var _fog: FogController


func _ready() -> void:
	_montar()
	_fog = get_tree().get_first_node_in_group(&"fog_controller") as FogController
	if _fog != null:
		_fog.preset_applied.connect(_aplicar_preset)
		_aplicar_preset(_fog.preset_atual())
	else:
		_aplicar_preset(Settings.fog_preset())
	set_process(true)


func _montar() -> void:
	_malha = MeshInstance3D.new()
	_malha.name = "Cupula"
	var esfera := SphereMesh.new()
	esfera.radius = RAIO
	esfera.height = RAIO * 2.0
	esfera.radial_segments = LADOS
	esfera.rings = ANEIS
	_malha.mesh = esfera
	_mat = ShaderMaterial.new()
	if ResourceLoader.exists(SHADER):
		_mat.shader = load(SHADER)
	else:
		push_error("CeuEstrada: shader ausente em %s" % SHADER)
	_malha.material_override = _mat
	_malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Sem isto a cupula some assim que o centro dela sai do tronco de visao, que
	# acontece toda vez que a camera olha para o lado: o centro esta na propria
	# camera e a caixa que o Godot calcula para a esfera nao ajuda.
	_malha.extra_cull_margin = RAIO
	add_child(_malha)


func _aplicar_preset(preset: FogPreset) -> void:
	if _mat == null or preset == null:
		return
	_mat.set_shader_parameter(&"cor_horizonte", preset.fog_color)
	_mat.set_shader_parameter(&"cor_brasa", BRASA)
	_mat.set_shader_parameter(&"cor_zenite", ZENITE)
	_mat.set_shader_parameter(&"cor_nuvem", NUVEM)
	_mat.set_shader_parameter(&"nuvens", preset.nuvens)
	_mat.set_shader_parameter(&"sol_dir", _azimute_do_sol(preset))
	# Sol apagado e ceu sem poente. Vale para quando alguem apontar esta cupula
	# para um preset noturno por engano: o degrade continua, a brasa nao.
	_mat.set_shader_parameter(&"sol_forca",
		clampf(preset.sol_energia * 0.5, 0.0, 1.4))


## Para que lado do horizonte o sol esta, no plano XZ.
##
## O preset guarda a rotacao da LUZ, que aponta para onde a luz VAI. O sol esta
## do lado oposto — e essa inversao e a diferenca entre a mata sair em contraluz
## e o poente nascer atras da camera, onde ninguem o ve.
static func _azimute_do_sol(preset: FogPreset) -> Vector2:
	var base := Basis.from_euler(Vector3(deg_to_rad(preset.sol_rotacao.x),
		deg_to_rad(preset.sol_rotacao.y), 0.0))
	var frente := base * Vector3(0.0, 0.0, -1.0)
	var plano := Vector2(-frente.x, -frente.z)
	if plano.length_squared() < 0.0001:
		return Vector2(0.0, -1.0)
	return plano.normalized()


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		global_position = cam.global_position
