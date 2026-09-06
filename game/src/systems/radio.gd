## Radio de chiado. O principal sistema de tensao do jogo.
##
## Nao mostra nada na tela e nao aponta direcao: so fica mais alto conforme algo
## se aproxima. O jogador vira a cabeca sozinho tentando entender de onde vem, e
## e nesse instante que o jogo funciona. Um indicador visual de perigo resolveria
## a mesma informacao e mataria o efeito.
##
## Duas camadas, e a segunda importa: chiado de base que sobe com a proximidade,
## e estalos de interferencia que so entram quando esta perto de verdade. Uma
## camada so nao distingue "ha algo por perto" de "esta na sua nuca".
class_name Radio
extends Node3D

## Distancia em que o chiado comeca a aparecer.
const ALCANCE := 26.0
## Distancia em que o chiado ja esta no maximo.
const ALCANCE_MAXIMO := 3.5

const VOL_MIN_DB := -46.0
const VOL_MAX_DB := -5.0
const VOL_INTERFERENCIA_DB := -8.0

## Suavizacao da variacao. Sem ela o chiado pula quando o inimigo entra e sai da
## linha de visao, e o pulo entrega a mecanica.
const SUAVIZACAO := 3.5

@export var ligado: bool = false:
	set(v):
		ligado = v
		_aplicar_ligado()

## Exige o item no inventario. Desligue para testar sem coletar nada.
@export var exige_item: bool = true

signal ligou()
signal desligou()

## De 0 a 1, o quanto o chiado esta forte agora. Outros sistemas podem ler.
var intensidade: float = 0.0

var _chiado: AudioStreamPlayer
var _interferencia: AudioStreamPlayer
var _alvo: float = 0.0


func _ready() -> void:
	_chiado = _criar(&"estatica")
	_interferencia = _criar(&"interferencia")
	_aplicar_ligado()


func _criar(nome: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"Radio"
	p.volume_db = -80.0
	if AudioDirector.tem(nome):
		p.stream = AudioDirector.stream(nome)
		# Chiado e interferencia sao loops continuos: o radio nunca cala, so
		# fica baixo demais para ser ouvido.
		if p.stream is AudioStreamWAV:
			var w := p.stream as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_end = w.data.size() / 2
	add_child(p)
	return p


func _exit_tree() -> void:
	if _chiado != null:
		_chiado.stop()
		_chiado.stream = null
	if _interferencia != null:
		_interferencia.stop()
		_interferencia.stream = null


func alternar() -> void:
	ligado = not ligado


func disponivel() -> bool:
	return not exige_item or Inventario.tem(&"radio")


func _aplicar_ligado() -> void:
	if _chiado == null:
		return
	var ativo := ligado and disponivel()
	if ativo:
		if not _chiado.playing:
			_chiado.play()
		if not _interferencia.playing:
			_interferencia.play()
		ligou.emit()
	else:
		_chiado.stop()
		_interferencia.stop()
		intensidade = 0.0
		desligou.emit()


func _physics_process(delta: float) -> void:
	if not ligado or not disponivel():
		return

	_alvo = _proximidade()
	intensidade = move_toward(intensidade, _alvo, SUAVIZACAO * delta)

	if intensidade <= 0.001:
		_chiado.volume_db = -80.0
		_interferencia.volume_db = -80.0
		return

	_chiado.volume_db = lerpf(VOL_MIN_DB, VOL_MAX_DB, intensidade)
	# A interferencia entra so no ultimo terco: e o aviso de que acabou o tempo
	# de decidir.
	var f := clampf((intensidade - 0.62) / 0.38, 0.0, 1.0)
	_interferencia.volume_db = lerpf(-80.0, VOL_INTERFERENCIA_DB, f)


## Proximidade do inimigo mais perto, de 0 a 1.
##
## Cresce ao quadrado de proposito: linear faz o chiado subir cedo demais e o
## jogador se acostuma. Ao quadrado, quase nada muda ate ficar perto, e ai muda
## depressa.
func _proximidade() -> float:
	var perto := INF
	for i: Node in get_tree().get_nodes_in_group(&"inimigo"):
		var d := global_position.distance_to((i as Node3D).global_position)
		perto = minf(perto, d)

	if perto >= ALCANCE:
		return 0.0
	var t := 1.0 - clampf((perto - ALCANCE_MAXIMO) / (ALCANCE - ALCANCE_MAXIMO), 0.0, 1.0)
	return t * t
