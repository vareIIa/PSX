## A trilha de um jogador remoto: os ultimos estados que chegaram, e o estado em
## qualquer instante entre eles.
##
## O `MultiplayerSynchronizer` do Godot 4.7.2 nao interpola — ele entrega o valor
## novo quando chega e pronto (medido: a classe nao tem propriedade de
## interpolacao; `physics_interpolation_mode` e outra coisa, suaviza fisica local
## entre ticks). Aplicar direto a 20 Hz desenha o amigo andando em degraus de
## 12 cm, e um carro a 100 km/h em saltos de 1,4 m. Por isso este buffer existe.
##
## O jogador remoto e desenhado no PASSADO, `ATRASO_INTERPOLACAO` atras do
## servidor. Assim quase sempre ha dois estados em volta do instante pedido, e o
## que se desenha e uma reta entre pontos que de fato aconteceram — nada de
## palpite. Palpite (extrapolacao) so quando o pacote atrasa, e por pouco tempo.
class_name BufferInterpolacao
extends RefCounted

const CAPACIDADE := 40

var _t := PackedFloat64Array()
var _e: Array[Dictionary] = []


## Guarda um estado com a hora do servidor em que ele valia. Fora de ordem ou
## repetido e descartado: UDP entrega assim as vezes, e voltar no tempo e o
## tranco mais visivel que existe.
func empurrar(t: float, e: Dictionary) -> void:
	if not _t.is_empty() and t <= _t[_t.size() - 1]:
		return
	_t.append(t)
	_e.append(e)
	while _t.size() > CAPACIDADE:
		_t.remove_at(0)
		_e.pop_front()


func vazio() -> bool:
	return _t.is_empty()


## Ja ha dado para o instante `t`: ele nao e anterior a primeira amostra.
func cobre(t: float) -> bool:
	return not _t.is_empty() and t >= _t[0]


func ultimo_t() -> float:
	return _t[_t.size() - 1] if not _t.is_empty() else -INF


func ultimo() -> Dictionary:
	return _e[_e.size() - 1] if not _e.is_empty() else {}


func limpar() -> void:
	_t.clear()
	_e.clear()


## O estado no instante `t` (hora do servidor). {} se ainda nao chegou nada.
func amostrar(t: float) -> Dictionary:
	var n := _t.size()
	if n == 0:
		return {}
	if n == 1 or t <= _t[0]:
		return _e[0 if t <= _t[0] else n - 1].duplicate()

	if t >= _t[n - 1]:
		return _extrapolar(t)

	# Busca do par em volta de t. O buffer e curto e t anda para a frente, entao
	# a busca de tras para a frente acha o par em uma ou duas voltas.
	var i := n - 2
	while i > 0 and _t[i] > t:
		i -= 1
	var a := _e[i]
	var b := _e[i + 1]
	if salto(a, b):
		# Teletransporte: fica no ponto velho ate a hora do novo. Deslizar oito
		# metros atravessando parede e pior que sumir e aparecer.
		return a.duplicate()
	var k := (t - _t[i]) / maxf(_t[i + 1] - _t[i], 0.0001)
	return misturar(a, b, k)


## Passou do ultimo estado: continua na mesma velocidade por no maximo
## EXTRAPOLACAO_MAX, e depois para.
func _extrapolar(t: float) -> Dictionary:
	var n := _t.size()
	var b := _e[n - 1]
	var saida := b.duplicate()
	if n < 2:
		return saida
	var a := _e[n - 2]
	if salto(a, b):
		return saida
	var dt_par := _t[n - 1] - _t[n - 2]
	if dt_par <= 0.0001:
		return saida
	var alem := minf(t - _t[n - 1], ProtocoloRede.EXTRAPOLACAO_MAX)
	var pa: Vector3 = a["pos"]
	var pb: Vector3 = b["pos"]
	saida["pos"] = pb + (pb - pa) / dt_par * alem
	return saida


## Dois estados seguidos que nao se ligam por uma reta: mudou de espaco, o
## cliente declarou teletransporte, ou andou mais do que qualquer veiculo anda
## num pacote.
static func salto(a: Dictionary, b: Dictionary) -> bool:
	if int(a.get("espaco", 0)) != int(b.get("espaco", 0)):
		return true
	if int(b.get("flags", 0)) & ProtocoloRede.F_TELEPORTE:
		return true
	var pa: Vector3 = a["pos"]
	var pb: Vector3 = b["pos"]
	var teto := ProtocoloRede.SALTO_TELEPORTE
	if (int(a.get("flags", 0)) | int(b.get("flags", 0))) & ProtocoloRede.F_CARRO:
		# Carro a 250 km/h anda 3,5 m por pacote; com um pacote perdido, 7 m.
		teto *= 3.0
	return pa.distance_to(pb) > teto


## Estado entre `a` e `b`. Posicao e rapidez em reta, giro pelo arco curto, o
## que e discreto (flags, veiculo) troca na metade.
static func misturar(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	k = clampf(k, 0.0, 1.0)
	var saida := (b if k >= 0.5 else a).duplicate()
	var pa: Vector3 = a["pos"]
	var pb: Vector3 = b["pos"]
	saida["pos"] = pa.lerp(pb, k)
	saida["yaw"] = lerp_angle(float(a.get("yaw", 0.0)), float(b.get("yaw", 0.0)), k)
	saida["rapidez"] = lerpf(float(a.get("rapidez", 0.0)), float(b.get("rapidez", 0.0)), k)
	saida["arfagem"] = lerpf(float(a.get("arfagem", 0.0)), float(b.get("arfagem", 0.0)), k)
	return saida
