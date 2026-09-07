## O som do motor, e a marcha que se ouve nele.
##
## Nao ha gravacao por rotacao nem banco de amostras: ha UM loop de motor e a
## afinacao dele. O que transforma isso em carro e o cambio — a rotacao sobe
## dentro da marcha, cai de um golpe quando troca, e sobe de novo. E esse
## dente-de-serra que o ouvido reconhece como "o carro engatou a terceira", e
## nao o timbre.
##
## Sem o cambio, a afinacao subiria em rampa continua do zero aos cem e o motor
## soaria como um secador de cabelo com o botao girando devagar — que e
## exatamente como soa em quase todo jogo que nao simula a troca.
class_name MotorSom
extends Node3D

## Afinacao no fundo e no fim de cada marcha. A faixa e estreita de proposito:
## um motor de carro de cidade nao gira dos 700 aos 8000.
const AFINACAO_MIN := 0.62
const AFINACAO_MAX := 1.46
## Marcha lenta, com o carro parado e ligado.
const AFINACAO_LENTA := 0.52

## Quao depressa a afinacao persegue o valor calculado. Instantanea, a troca de
## marcha vira um degrau; lenta demais, a subida atrasa em relacao ao carro.
const SUAVIDADE := 9.0
## A troca demora isto para completar, e nesse tempo o motor alivia.
const TEMPO_TROCA := 0.22

var _motor: AudioStreamPlayer3D
var _extra: AudioStreamPlayer3D
var _afinacao: float = AFINACAO_LENTA
var _marcha: int = 1
var _trocando: float = 0.0
var _ligado: bool = false


func _ready() -> void:
	_motor = AudioStreamPlayer3D.new()
	_motor.name = "Loop"
	_motor.bus = &"SFX"
	_motor.max_distance = 42.0
	_motor.unit_size = 5.0
	_motor.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	_motor.volume_db = -14.0
	add_child(_motor)

	_extra = AudioStreamPlayer3D.new()
	_extra.name = "Eventos"
	_extra.bus = &"SFX"
	_extra.max_distance = 30.0
	_extra.unit_size = 4.0
	_extra.volume_db = -10.0
	add_child(_extra)


func partir() -> void:
	_ligado = true
	_tocar(&"motor_partida", -8.0)
	_iniciar_loop()


func desligar() -> void:
	_ligado = false
	_motor.stop()


func acordar() -> void:
	if _ligado:
		_iniciar_loop()


func _iniciar_loop() -> void:
	var s := AudioDirector.stream(&"motor_loop")
	if s == null:
		return
	_motor.stream = s
	_motor.pitch_scale = _afinacao
	if not _motor.playing:
		_motor.play()


## Chamado todo quadro pelo carro.
func atualizar(velocidade: float, marcha: int, ligado: bool, delta: float) -> void:
	if ligado != _ligado:
		if ligado:
			partir()
		else:
			desligar()
	if not _ligado:
		return
	if not _motor.playing:
		_iniciar_loop()

	if marcha != _marcha:
		# Subiu de marcha: alivio e batida. Descer nao bate — o cambio
		# automatico reduz sozinho e ninguem ouve isso de fora do carro.
		if marcha > _marcha:
			_trocando = TEMPO_TROCA
			_tocar(&"motor_marcha", -16.0)
		_marcha = marcha

	_trocando = maxf(0.0, _trocando - delta)

	var alvo := _afinacao_da_marcha(velocidade, _marcha)
	if _trocando > 0.0:
		# Durante a troca o motor cai para o fundo da marcha nova, que e o que
		# se ouve de fora: o corte.
		alvo = AFINACAO_MIN
	_afinacao = lerpf(_afinacao, alvo, minf(1.0, SUAVIDADE * delta))
	_motor.pitch_scale = clampf(_afinacao, 0.4, 2.0)
	# Motor acelerado e mais alto que motor em marcha lenta, e a diferenca de
	# doze decibeis e o que da peso a arrancada.
	_motor.volume_db = -20.0 + clampf(
		(_afinacao - AFINACAO_LENTA) / (AFINACAO_MAX - AFINACAO_LENTA), 0.0, 1.0) * 9.0


## Onde a rotacao esta DENTRO da marcha atual.
##
## Cada marcha cobre uma faixa de velocidade; dentro dela a rotacao vai do fundo
## ao teto. Duas marchas seguidas cobrem faixas cada vez mais largas, entao a
## quinta sobe devagar e a primeira estoura em dois segundos — que e como um
## cambio real se comporta e o que da a sensacao de peso.
static func _afinacao_da_marcha(velocidade: float, marcha: int) -> float:
	var faixas := Carro.MARCHAS
	var k := clampi(marcha - 1, 0, faixas.size() - 1)
	var piso := 0.0 if k == 0 else faixas[k - 1]
	var teto: float = faixas[k]
	var t := clampf((velocidade - piso) / maxf(0.5, teto - piso), 0.0, 1.0)
	if velocidade < 0.35:
		return AFINACAO_LENTA
	return lerpf(AFINACAO_MIN, AFINACAO_MAX, t)


func _tocar(nome: StringName, db: float) -> void:
	var s := AudioDirector.stream(nome)
	if s == null:
		return
	_extra.stream = s
	_extra.volume_db = db
	_extra.play()
