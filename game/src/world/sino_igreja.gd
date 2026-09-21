## O sino da sineira da Praca da Matriz: bate a hora cheia, uma badalada por hora.
##
## Por que nao e um `som_ambiente`
## -------------------------------
## `som_ambiente` toca em laco, e sino nao e laco: e um evento, com hora marcada,
## que o jogador pode contar. Onze badaladas as onze da noite dizem a hora sem
## HUD nenhum — e dizem mais que a hora, porque ninguem tocou o sino.
##
## A hora vem de `WorldState.relogio`, a mesma do HUD. O sino so reage a VIRADA
## da hora: ao nascer ele anota o minuto em que esta e espera o proximo zero.
## Nascer as 23:00 em ponto nao faz tocar — o chunk carregando nao e a hora
## chegando, e um sino que toca toda vez que o jogador volta a praca e alarme.
##
## Alcance longo de proposito, e atenuacao quadratica como todo som 3D do jogo:
## sino se ouve do outro lado do bairro. Quem apaga ele de longe e o proprio
## streaming, que descarrega o chunk da torre.
class_name SinoIgreja
extends Node3D

## Intervalo entre badaladas, em segundos. O `sino_igreja.wav` tem 4,5 s de
## cauda; 2,6 s deixa uma badalada entrar na cauda da anterior, que e como sino
## de bronze soa quando alguem puxa a corda com ritmo.
const INTERVALO := 2.6

var som: StringName = &"sino_igreja"

var _tocador: AudioStreamPlayer3D
var _minuto := -1
var _faltam := 0
var _proxima := 0.0


func _ready() -> void:
	_tocador = AudioStreamPlayer3D.new()
	_tocador.name = "Sino"
	_tocador.stream = AudioDirector.stream(som)
	_tocador.bus = &"SFX"
	_tocador.volume_db = -3.0
	_tocador.unit_size = 14.0
	_tocador.max_distance = 160.0
	_tocador.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	add_child(_tocador)
	_minuto = WorldState.relogio.minutos()
	# Teste: tres badaladas dois segundos depois de nascer. A hora cheia leva
	# ate oito minutos e meio reais para chegar, e `--hora` e desfeito pela
	# largada do jogo antes de valer.
	if OS.get_cmdline_user_args().has("--sino-agora"):
		_faltam = 3
		_proxima = 2.0
		print("[sino] teste — %d badaladas" % _faltam)


func _process(delta: float) -> void:
	if _tocador.stream == null:
		return
	var m := WorldState.relogio.minutos()
	if m != _minuto:
		_minuto = m
		if m % 60 == 0:
			# Doze badaladas ao meio-dia e a meia-noite, e nao zero.
			var hora := int(m / 60.0) % 12
			_faltam = 12 if hora == 0 else hora
			_proxima = 0.0
			print("[sino] %s — %d badaladas" % [WorldState.relogio.texto(), _faltam])
	if _faltam <= 0:
		return
	_proxima -= delta
	if _proxima > 0.0:
		return
	_tocador.play()
	_faltam -= 1
	_proxima = INTERVALO
