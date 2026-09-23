## O que o servidor aceita de movimento de um cliente.
##
## O movimento a pe e do cliente (plano 04 secao 4): quem anda sente o proprio
## passo sem esperar o servidor, e 80 ms de ida e volta a 2,4 m/s sao 20 cm que
## ninguem percebe. O preco e que o cliente pode mentir. Este validador e a
## guarda: nao reconcilia quadro a quadro, so recusa o que nenhum corpo do jogo
## consegue fazer.
##
## A regra e de distancia por tempo, com o tempo medido duas vezes. No relogio do
## servidor os pacotes chegam amontoados (dois no mesmo quadro depois de um
## soluco de Wi-Fi), e o segundo pareceria um salto. Pelo numero de sequencia o
## cliente diz quanto tempo passou — e ele pode mentir nisso tambem, entao o que
## vale e o MENOR dos dois, com uma folga de meio segundo sobre o relogio do
## servidor.
class_name ValidadorMovimento
extends RefCounted

## Velocidades maximas por modo, em m/s, com folga.
##
## A pe: `Player.VEL_CORRER` (4,6) mais 60% — descida de escada e empurrao de
## pedestre passam disso por um instante. Bicicleta e carro: o que o veiculo mais
## rapido do jogo faz, com folga. 75 m/s sao 270 km/h.
const VEL_A_PE := 4.6 * 1.6
const VEL_BICICLETA := 16.0
const VEL_CARRO := 75.0
## Queda livre depois de 3 s (~30 m/s) com folga. Subir tao rapido nao existe.
const VEL_VERTICAL := 45.0
## Metros que sempre passam, somados ao limite: arredondamento, degrau, o
## empurrao do pedestre (`--ir-para nao e regua`, memoria do projeto).
const FOLGA := 1.5
## De quanto em quanto tempo o servidor aceita um teletransporte declarado pelo
## cliente no MESMO espaco (acordar no orelhao, carregar save, `--ir-para`).
##
## O que isto nao impede, dito com todas as letras (plano 06 secao 7): um
## cliente adulterado pode declarar um salto a cada 3 s e "viajar" pela cidade.
## Num servidor de amigos o desonesto nao ganha nada que o honesto nao tenha; a
## contagem vai no log. Em servidor publico, o desmaio passa a ser do servidor
## (Fase 3) e este atalho fecha.
const INTERVALO_TELEPORTE := 3.0

var _pos := Vector3.ZERO
var _t := -1.0
var _seq := -1
var _espaco := 0
var _ultimo_teleporte := -INF

## Teletransportes declarados e aceitos. Para o log do servidor.
var teleportes: int = 0

## Quantas vezes este cliente passou do limite. O servidor decide o que fazer com
## isso (ConfigServidor.validacao).
var suspeitas: int = 0
var ultima_suspeita: String = ""


## Confere um estado novo. Verdadeiro se e plausivel. Quando nao e, o validador
## NAO avanca: a proxima conta parte do ultimo ponto aceito.
func conferir(pos: Vector3, flags: int, espaco: int, seq: int, t_servidor: float) -> bool:
	if _t < 0.0 or espaco != _espaco:
		# Primeiro estado, ou mudou de espaco: entrar num interior e um salto de
		# 2000 m legitimo, e o destino e calculado pelo proprio jogo.
		_aceitar(pos, espaco, seq, t_servidor)
		return true

	if (flags & ProtocoloRede.F_TELEPORTE) and t_servidor - _ultimo_teleporte >= INTERVALO_TELEPORTE:
		_ultimo_teleporte = t_servidor
		teleportes += 1
		_aceitar(pos, espaco, seq, t_servidor)
		return true

	var dt_servidor := maxf(t_servidor - _t, 0.0)
	var dt_seq := float(maxi(seq - _seq, 1)) / float(ProtocoloRede.TICK_HZ)
	var dt := maxf(dt_servidor, minf(dt_seq, dt_servidor + 0.5))
	dt = maxf(dt, 1.0 / float(ProtocoloRede.TICK_HZ))

	var vmax := VEL_A_PE
	if flags & ProtocoloRede.F_CARRO:
		vmax = VEL_CARRO
	elif flags & ProtocoloRede.F_BICICLETA:
		vmax = VEL_BICICLETA
	var horizontal := Vector2(pos.x - _pos.x, pos.z - _pos.z).length()
	var vertical := absf(pos.y - _pos.y)
	var limite_h := vmax * dt + FOLGA
	var limite_v := VEL_VERTICAL * dt + FOLGA
	if horizontal > limite_h or vertical > limite_v:
		suspeitas += 1
		ultima_suspeita = "%.1f m em %.2f s (limite %.1f m)" % [
			maxf(horizontal, vertical), dt,
			limite_h if horizontal > limite_h else limite_v]
		return false
	_aceitar(pos, espaco, seq, t_servidor)
	return true


## Ultimo ponto aceito — para onde o servidor devolve quem passou do limite.
func ultimo_aceito() -> Vector3:
	return _pos


## Esquece o historico. Usado quando o proprio servidor move o jogador
## (chegada, correcao): a proxima posicao do cliente e o ponto de partida.
func reiniciar() -> void:
	_t = -1.0
	_seq = -1


func _aceitar(pos: Vector3, espaco: int, seq: int, t: float) -> void:
	_pos = pos
	_espaco = espaco
	_seq = seq
	_t = t
