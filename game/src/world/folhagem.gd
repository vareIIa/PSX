## Som do parque. Um destes por chunk de parque.
##
## O balanco das arvores mora no shader e nao custa CPU nenhuma, mas balanco sem
## som e mimica: o olho ve a copa mexer e o ouvido nao confirma, e o cerebro le
## como bug de animacao. Este no e a confirmacao.
##
## A rajada aqui repete a formula que esta no psx_surface.gdshader:
##
##     rajada = 0.65 + 0.35 * sin(TIME * 0.21 + x * 0.02)
##
## Mesmo relogio, mesma fase pela posicao. Nao e sincronia perfeita — nao precisa
## ser, e nem daria: o shader anda por vertice e isto anda por no. O que importa
## e que a copa esteja no auge do balanco quando a folha soa mais alto, e isso a
## formula compartilhada garante.
##
## Os grilos sao o segundo motivo de este no existir. Um parque vazio de
## madrugada com grilo e um lugar; sem grilo e um cenario. E quando eles param de
## repente, coisa que o jogo ainda vai usar, o jogador entende sozinho.
class_name Folhagem
extends Node3D

const RAIO_AUDIVEL := 30.0
const VOLUME_BASE := -19.0
## Intervalo entre grilos. Longo e irregular: grilo a cada dois segundos vira
## metronomo e o cerebro para de ouvir.
const GRILO_MIN := 3.4
const GRILO_MAX := 9.5

var semente: int = 0

var _folhas: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()
var _proximo_grilo: float = 0.0
var _relogio: float = 0.0


func _ready() -> void:
	_rng.seed = semente
	_proximo_grilo = _rng.randf_range(0.0, GRILO_MAX)
	# A fase entra pela posicao, igual ao shader. Sem ela todos os emissores do
	# parque sobem e descem juntos e a rajada vira uma respiracao unica.
	_relogio = _rng.randf_range(0.0, TAU)

	if AudioDirector.silencioso() or not AudioDirector.tem(&"folhas_loop"):
		set_process(false)
		return

	_folhas = AudioStreamPlayer3D.new()
	_folhas.stream = AudioDirector.stream(&"folhas_loop")
	_folhas.bus = &"Ambiente"
	_folhas.volume_db = VOLUME_BASE
	_folhas.max_distance = RAIO_AUDIVEL
	_folhas.unit_size = 6.0
	_folhas.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	add_child(_folhas)
	_folhas.play()


func _process(delta: float) -> void:
	_relogio += delta

	if _folhas != null:
		var rajada := 0.65 + 0.35 * sin(_relogio * 0.21 + global_position.x * 0.02)
		# Em decibeis, porque volume linear em rajada de vento nao se ouve: a
		# diferenca entre calmaria e sopro tem de ser uns 8 dB para existir.
		_folhas.volume_db = VOLUME_BASE + (rajada - 0.65) * 24.0

	_proximo_grilo -= delta
	if _proximo_grilo > 0.0:
		return
	_proximo_grilo = _rng.randf_range(GRILO_MIN, GRILO_MAX)
	if not AudioDirector.tem(&"grilo"):
		return
	# O grilo nunca soa exatamente onde o emissor esta: ele esta no mato ao lado.
	var desvio := Vector3(_rng.randf_range(-7.0, 7.0), -1.6, _rng.randf_range(-7.0, 7.0))
	AudioDirector.tocar(&"grilo", global_position + desvio,
		_rng.randf_range(-24.0, -17.0), _rng.randf_range(0.9, 1.12))


## Solta o stream na mao. queue_free nao chega a ser processado no desligamento,
## e o loop fica pendurado segurando o WAV — o mesmo vazamento que o
## AudioDirector ja resolveu para os ambientes dele.
func _exit_tree() -> void:
	if _folhas == null:
		return
	_folhas.stop()
	_folhas.stream = null
