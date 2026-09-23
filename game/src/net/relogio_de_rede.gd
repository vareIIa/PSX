## O relogio do servidor, estimado do lado do cliente.
##
## Cada instantaneo traz a hora do servidor no momento em que saiu. A diferenca
## entre essa hora e a hora local em que ele CHEGOU e o desvio entre os dois
## relogios menos o atraso da viagem. O atraso varia pacote a pacote (fila de
## roteador, Wi-Fi); o desvio nao. Entao o maior valor de uma janela recente e o
## pacote que viajou mais rapido, e e ele que da o desvio mais honesto.
##
## Media simples nao serve: um segundo de Wi-Fi ruim puxaria o relogio para tras,
## e o jogador remoto andaria em camera lenta ate a media esquecer.
##
## O resultado nao e a hora exata do servidor — e ela menos o menor atraso de
## viagem. Isso e o que se quer: todo cliente desenha o passado com a mesma
## referencia, e o `ATRASO_INTERPOLACAO` cobre o resto.
class_name RelogioDeRede
extends RefCounted

## Janela de amostras, em segundos. Longa o bastante para conter um pacote que
## chegou rapido; curta o bastante para acompanhar um relogio que deriva.
const JANELA := 2.0
## Quanto o desvio DESCE em direcao a amostra nova a cada pacote. So a descida e
## suavizada — ver `amostrar`.
const SUAVIZACAO := 0.08
## Teto da descida, em segundos de desvio por segundo de relogio local. Com 5%, o
## relogio estimado anda a no minimo 95% da velocidade real e NUNCA volta.
const DESCIDA_MAX := 0.05

var _t_local := PackedFloat64Array()
var _desvio_amostra := PackedFloat64Array()
var _desvio := 0.0
var _tem := false
var _t_ultimo := 0.0


func amostrar(t_servidor: float, t_local: float) -> void:
	_t_local.append(t_local)
	_desvio_amostra.append(t_servidor - t_local)
	while _t_local.size() > 1 and _t_local[0] < t_local - JANELA:
		_t_local.remove_at(0)
		_desvio_amostra.remove_at(0)
	var melhor := -INF
	for d: float in _desvio_amostra:
		melhor = maxf(melhor, d)
	if not _tem:
		_desvio = melhor
		_tem = true
		_t_ultimo = t_local
		return
	var passo := maxf(t_local - _t_ultimo, 0.0)
	_t_ultimo = t_local
	if melhor > _desvio:
		# Toda amostra e um limite de BAIXO: o pacote nao chega antes de sair,
		# entao hora_do_servidor - hora_local nunca passa do desvio real. Uma
		# amostra acima da estimativa prova que a estimativa estava baixa, e sobe
		# na hora. Subir suavizado era o defeito: o primeiro pacote de quem acabou
		# de entrar costuma chegar atrasado (o processo ainda esta montando cena),
		# e o relogio ficava 0,3 s atras por segundos — o bastante para os estados
		# que ele carimba chegarem velhos e o boneco dele parar no ar (medido:
		# desenho em 7,10 s com a amostra mais nova em 6,88 s).
		_desvio = melhor
	else:
		# Descer so acontece quando a melhor amostra sai da janela, e ai quase
		# sempre e ruido. Devagar, e com teto: o relogio nao pode andar para tras.
		# Um salto para tras faz quem carimba com ele mandar estados MAIS VELHOS
		# que os ja entregues; o buffer do outro lado os descarta e o boneco
		# congela ate o tempo alcancar (medido: amostras de um bot em 6,999 e
		# 7,000 s, depois nada por meio segundo). Havia um corte seco para
		# desvios de mais de 0,5 s; saiu por isso. Servidor que reinicia derruba a
		# conexao, e a proxima sessao comeca com relogio novo.
		var alvo := lerpf(_desvio, melhor, SUAVIZACAO)
		_desvio = maxf(alvo, _desvio - DESCIDA_MAX * passo)


func pronto() -> bool:
	return _tem


## Hora do servidor agora, na referencia do cliente.
func agora(t_local: float) -> float:
	return t_local + _desvio


func zerar() -> void:
	_t_local.clear()
	_desvio_amostra.clear()
	_desvio = 0.0
	_tem = false
	_t_ultimo = 0.0
