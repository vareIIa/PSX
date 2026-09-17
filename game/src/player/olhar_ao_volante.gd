## O olhar livre de quem esta ao volante (A24 do PLANO_AAA_4K).
##
## Por que isto existe
## -------------------
## Ate aqui o mouse nao fazia nada dentro do carro. Ele girava o CORPO do
## jogador, como a pe, e `Player._ao_volante` puxava o corpo de volta para o rumo
## do carro nove vezes por segundo: o giro sumia em um decimo de segundo, por
## fora e por dentro. Olhar pela janela lateral, conferir quem vem atras ou dar a
## volta no carro parado com a camera eram coisas que o jogo simplesmente nao
## deixava.
##
## O que ele guarda
## ----------------
## So dois angulos — quanto o jogador desviou o olhar do rumo do carro — e a
## regra de volta ao centro. Quem aplica sao os dois donos de camera:
##
##   por fora    `CameraRig.orbitar` gira o braco em volta da cabeca. A volta e
##               inteira: da para ver o carro de frente.
##   por dentro  `CabineDoJogador` gira a camera da cabine. O limite e o do
##               pescoco mais o dos olhos.
##
## Classe pura, sem Node e sem autoload, para a bancada medir sem cidade.
##
## A volta ao centro
## -----------------
## Parado, o olhar fica onde o jogador deixou: e o momento de olhar em volta.
## Andando, depois de um tempo sem mexer no mouse, ele volta para a frente — a
## rua e para onde o carro vai, e quem solta o mouse quer ver a rua.
##
## A volta tem DURACAO fixa, e nao ritmo: com ritmo exponencial meia volta
## levava o dobro de um quarto de volta para "acabar", e o criterio do plano
## (volta em ate 0,8 s) nao teria numero para medir. Ela comeca e termina
## devagar: partir ja na velocidade cheia da um tranco que le como defeito.
class_name OlharAoVolante
extends RefCounted

## Por fora: quanto a camera sobe (negativo) e desce (positivo), em radianos.
## 0,85 sao 49 graus acima do carro. Descer mais que 0,10 enfia o braco no
## asfalto, e o braco encolhe ate a camera ficar colada no para-choque.
const FORA_ARFAGEM_MIN := -0.85
const FORA_ARFAGEM_MAX := 0.10

## Por dentro: o pescoco gira uns 80 graus para cada lado e os olhos mais 35.
## 2,0 rad sao 115 graus — o bastante para ver a janela de tras de lado, e nao
## o banco de tras inteiro, que ninguem sentado ao volante ve. Para cima e para
## baixo, 60 graus: o forro do teto e o proprio colo. E o A24 do plano.
const DENTRO_GUINADA_MAX := 2.0
const DENTRO_ARFAGEM_MIN := -1.05
const DENTRO_ARFAGEM_MAX := 1.05

## Segundos sem mexer no mouse antes de o olhar comecar a voltar.
const ESPERA := 1.2
## Quanto a volta dura, do angulo em que estava ate a frente.
const VOLTA := 0.7
## Abaixo disto, em m/s, o carro esta parado para o olhar: ele nao volta.
const VEL_MINIMA := 2.5

var guinada: float = 0.0
var arfagem: float = 0.0
## Olhando de dentro da cabine? Muda os limites.
var dentro: bool = false

var _parado: float = 99.0
## Tempo desde o comeco da volta; negativo quando nao ha volta em curso.
var _volta_t: float = -1.0
var _de := Vector2.ZERO


## Um movimento de mouse, em pixels. `sens` e a mesma de quem anda a pe
## (`Player.SENSIBILIDADE`): o mouse nao muda de velocidade ao entrar no carro.
func mover(relativo: Vector2, sens: float) -> void:
	guinada -= relativo.x * sens
	arfagem -= relativo.y * sens
	_parado = 0.0
	_volta_t = -1.0
	_limitar()


## Um passo de tempo. `vel` e a velocidade do carro, em m/s.
func passo(delta: float, vel: float) -> void:
	_parado += delta
	if absf(vel) < VEL_MINIMA:
		# Parou no meio da volta: o olhar fica onde estava, e a proxima volta
		# parte dali.
		_volta_t = -1.0
		return
	if _parado < ESPERA or (guinada == 0.0 and arfagem == 0.0):
		return
	if _volta_t < 0.0:
		_volta_t = 0.0
		_de = Vector2(guinada, arfagem)
	_volta_t = minf(_volta_t + delta, VOLTA)
	var k := smoothstep(0.0, VOLTA, _volta_t)
	guinada = lerpf(_de.x, 0.0, k)
	arfagem = lerpf(_de.y, 0.0, k)
	if _volta_t >= VOLTA:
		guinada = 0.0
		arfagem = 0.0
		_volta_t = -1.0


## De volta para a frente, na hora. Ao entrar, ao sair e ao trocar de vista.
func zerar() -> void:
	guinada = 0.0
	arfagem = 0.0
	_parado = 99.0
	_volta_t = -1.0


## Troca os limites. Trocar de vista zera: o angulo de uma camera nao quer dizer
## nada na outra.
func definir_dentro(sim: bool) -> void:
	if sim == dentro:
		return
	dentro = sim
	zerar()


## Olhando para longe da frente? E o que a bancada le.
func desviado() -> bool:
	return absf(guinada) > 0.01 or absf(arfagem) > 0.01


func _limitar() -> void:
	if dentro:
		guinada = clampf(guinada, -DENTRO_GUINADA_MAX, DENTRO_GUINADA_MAX)
		arfagem = clampf(arfagem, DENTRO_ARFAGEM_MIN, DENTRO_ARFAGEM_MAX)
	else:
		# Por fora a volta e inteira. Embrulhado em meia volta para a volta ao
		# centro pegar sempre o caminho curto.
		guinada = wrapf(guinada, -PI, PI)
		arfagem = clampf(arfagem, FORA_ARFAGEM_MIN, FORA_ARFAGEM_MAX)
