## Braco de camera. Alterna entre primeira e terceira pessoa sem corte.
##
## O truque e nao ter duas cameras. Uma unica Camera3D pendurada num SpringArm3D
## cujo comprimento vai de 0 ate o valor de terceira pessoa: comprimento zero poe
## a camera no proprio pivo da cabeca, que e exatamente a primeira pessoa. A
## transicao sai de graca e o SpringArm ainda resolve a camera atravessar parede,
## que e o problema classico da terceira pessoa.
class_name CameraRig
extends SpringArm3D

## Distancia da camera em terceira pessoa. As referencias usam um enquadramento
## alto e recuado, nao um over-shoulder colado.
const DISTANCIA_TP := 2.6
## Deslocamento lateral em terceira pessoa, para o corpo nao tapar o centro.
const OMBRO_TP := 0.72
const ALTURA_TP := 0.85

## Inclinacao para baixo em terceira pessoa, em radianos. As referencias olham
## o personagem de cima, mostrando bastante chao.
const PITCH_TP := 0.16

## Segundos para completar a troca. Rapido o bastante para nao atrapalhar,
## lento o bastante para o jogador entender que a camera se moveu.
const DURACAO := 0.22

@onready var _camera: Camera3D = $Camera

var terceira_pessoa: bool = false

var _t: float = 0.0
var _de: float = 0.0
var _para: float = 0.0
var _animando: bool = false


func _ready() -> void:
	# O SpringArm colide com o cenario, mas nao pode ser parado pelo proprio
	# jogador nem por area de gatilho.
	collision_mask = 1
	add_excluded_object(get_parent().get_parent().get_rid())
	spring_length = 0.0
	_aplicar(0.0)
	set_process(false)


## Inverte o modo e devolve o estado novo.
func alternar() -> bool:
	terceira_pessoa = not terceira_pessoa
	_de = spring_length
	_para = DISTANCIA_TP if terceira_pessoa else 0.0
	_t = 0.0
	_animando = true
	set_process(true)
	return terceira_pessoa


func _process(delta: float) -> void:
	if not _animando:
		set_process(false)
		return

	_t = minf(1.0, _t + delta / DURACAO)
	# Suavizacao nas duas pontas: a troca nao pode dar solavanco.
	var k := _t * _t * (3.0 - 2.0 * _t)
	_aplicar(lerpf(_de, _para, k))

	if _t >= 1.0:
		_animando = false
		set_process(false)


func _aplicar(comprimento: float) -> void:
	spring_length = comprimento
	# O ombro e a altura entram proporcionais a distancia, senao em primeira
	# pessoa a camera ficaria deslocada do olho.
	var f := comprimento / DISTANCIA_TP if DISTANCIA_TP > 0.0 else 0.0
	_camera.position = Vector3(OMBRO_TP * f, ALTURA_TP * f, 0.0)
	_camera.rotation.x = -PITCH_TP * f
