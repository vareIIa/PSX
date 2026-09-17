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

## Ao volante o enquadramento e outro, e tem de ser.
##
## Um carro tem 4,2 m de comprimento e o assento fica no meio dele. A 2,6 m — a
## distancia de quem esta a pe — a camera nasce DENTRO do porta-malas, e o
## SpringArm, que existe justamente para nao atravessar parede, recolhe o braco
## ate zero: a terceira pessoa vira primeira pessoa sem ninguem pedir. Por isso o
## carro e excluido da varredura e a distancia cresce.
##
## Sem ombro: atras de um carro a camera fica na linha do meio, e nao sobre um
## ombro que nao existe.
const DISTANCIA_CARRO := 6.4
const ALTURA_CARRO := 2.1
const OMBRO_CARRO := 0.0
const PITCH_CARRO := 0.20

## A camera de perto, ao volante. A tecla de camera alterna entre esta e a de
## longe — e NAO entre terceira e primeira pessoa, que e o que ela fazia.
##
## O que ela fazia estava quebrado, e a captura `captures/carro/painel.png` da
## rodada passada mostra o defeito inteiro: um quadro de rua a 58 km/h, com
## painel, com marcha engatada e SEM CARRO NENHUM na imagem. Com o braco em
## zero a camera fica no banco do motorista, e o `Carro` da cidade nao tem
## interior — o `CarroCabine` existe, mas so o `CarroCena` o monta. De dentro de
## um casco fechado, com as faces viradas para fora, o que se ve e a rua
## atravessando a lataria. O carro fica invisivel.
##
## Enquanto nao houver cabine no carro dirigivel, primeira pessoa ao volante nao
## e um modo: e um buraco. A tecla continua servindo para alguma coisa — duas
## distancias de perseguicao, que e o que jogo de carro faz com ela.
const DISTANCIA_CARRO_PERTO := 4.2
const ALTURA_CARRO_PERTO := 1.5

## Segundos para completar a troca. Rapido o bastante para nao atrapalhar,
## lento o bastante para o jogador entender que a camera se moveu.
const DURACAO := 0.22

@onready var _camera: Camera3D = $Camera

var terceira_pessoa: bool = false

var _t: float = 0.0
var _de: float = 0.0
var _para: float = 0.0
var _animando: bool = false
## Enquadramento em vigor. Troca ao entrar e ao sair do carro.
var _distancia: float = DISTANCIA_TP
var _ombro: float = OMBRO_TP
var _altura: float = ALTURA_TP
var _pitch: float = PITCH_TP
## Corpo excluido da varredura do braco — o carro que o jogador esta dirigindo.
var _veiculo := RID()
## Ao volante a camera esta na posicao de perto? Ver `DISTANCIA_CARRO_PERTO`.
var _perto_no_carro: bool = false
## Em que modo o jogador estava a pe. Guardado ao entrar no carro e devolvido ao
## sair: entrar num carro nao e uma escolha de camera, e sair nao pode virar
## uma.
var _tp_a_pe: bool = false


func _ready() -> void:
	# O SpringArm colide com o cenario, mas nao pode ser parado pelo proprio
	# jogador nem por area de gatilho.
	collision_mask = 1
	add_excluded_object(get_parent().get_parent().get_rid())
	spring_length = 0.0
	_aplicar(0.0)
	set_process(false)


## Inverte o modo e devolve o estado novo.
##
## Ao volante NAO alterna primeira e terceira pessoa — alterna duas distancias
## de perseguicao. Ver `DISTANCIA_CARRO_PERTO`.
func alternar() -> bool:
	if _veiculo.is_valid():
		_perto_no_carro = not _perto_no_carro
		_distancia = DISTANCIA_CARRO_PERTO if _perto_no_carro else DISTANCIA_CARRO
		_altura = ALTURA_CARRO_PERTO if _perto_no_carro else ALTURA_CARRO
		_animar_para(_distancia)
		return true
	terceira_pessoa = not terceira_pessoa
	_animar_para(_distancia if terceira_pessoa else 0.0)
	return terceira_pessoa


## Passa a enquadrar um veiculo em vez de uma pessoa.
##
## `nulo` desfaz. Chamado por `Player` ao entrar e ao sair do carro, e nao pela
## tecla de camera: quem manda no enquadramento e o que se esta dirigindo, e nao
## em que modo a camera estava quando se entrou.
func seguir_veiculo(v: PhysicsBody3D) -> void:
	if _veiculo.is_valid():
		remove_excluded_object(_veiculo)
		_veiculo = RID()
	# O giro do olhar livre nao passa de um carro para o outro, nem para a pe.
	orbitar(0.0, 0.0)
	if v == null:
		_distancia = DISTANCIA_TP
		_ombro = OMBRO_TP
		_altura = ALTURA_TP
		_pitch = PITCH_TP
		# Devolve o jogador ao modo em que ele estava a pe.
		terceira_pessoa = _tp_a_pe
		_perto_no_carro = false
	else:
		_veiculo = v.get_rid()
		add_excluded_object(_veiculo)
		_distancia = DISTANCIA_CARRO
		_ombro = OMBRO_CARRO
		_altura = ALTURA_CARRO
		_pitch = PITCH_CARRO
		_tp_a_pe = terceira_pessoa
		_perto_no_carro = false
		# Ao volante e SEMPRE de fora. Ver `DISTANCIA_CARRO_PERTO`: com o braco
		# em zero a camera vai parar dentro de um casco sem interior e o carro
		# desaparece da propria imagem.
		terceira_pessoa = true
	if terceira_pessoa:
		_animar_para(_distancia)
	else:
		_aplicar(0.0)


## Gira o braco em volta da cabeca: o olhar livre de quem dirige (A24).
##
## `OlharAoVolante` guarda os angulos; aqui eles viram rotacao do PROPRIO braco,
## e nao do pivo nem do corpo. O pivo e do `Player`, que escreve nele a
## inclinacao e o tranco da batida a cada quadro; o corpo segue o rumo do carro.
## O braco e o unico no que ninguem mais gira — e girando ele a camera da a
## volta no carro com a varredura de colisao junto: encostado num muro, o braco
## encolhe como encolhe atras dele.
func orbitar(guinada: float, arfagem: float) -> void:
	rotation = Vector3(arfagem, guinada, 0.0)


func _animar_para(alvo: float) -> void:
	_de = spring_length
	_para = alvo
	_t = 0.0
	_animando = true
	set_process(true)


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
	var f := comprimento / _distancia if _distancia > 0.0 else 0.0
	_camera.position = Vector3(_ombro * f, _altura * f, 0.0)
	_camera.rotation.x = -_pitch * f
