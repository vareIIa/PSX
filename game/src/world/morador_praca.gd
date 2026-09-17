## Quem mora num casebre da Praca da Matriz: sai de casa, anda pela praca e
## volta para dentro.
##
## Por que herda de Convidado e nao de Pedestre
## --------------------------------------------
## `Pedestre` e dirigido por `Rotas`, que le a malha de ruas da cidade e devolve
## esquinas de calcada. Uma praca de 80 m nao tem esquina nenhuma por dentro: o
## grafo passa PELA VOLTA dela, e um morador dirigido por ele sairia andando
## pela avenida em vez de atravessar o calcamento ate a porta da igreja.
##
## `Convidado` com `Papel.LIVRE` ja faz o que falta: circula por uma lista de
## pontos, para, encosta em alguem, conversa e volta. O que ele nao tem e casa.
##
## Por que a casa entra aqui e nao dentro de Convidado
## ---------------------------------------------------
## `Convidado` e a mesma classe da sala da casa da fumaca, do balcao do mercado
## e da mesa da TV do bar. Enfiar porta e sumico na maquina de estados dele
## mexeria nos tres lugares para atender um. Aqui nao ha uma linha da maquina
## dele reescrita: o ciclo mora em `_process`, que a classe mae nao usa (ela roda
## em `_physics_process`), e a unica coisa que esta classe toca e `pontos` — que
## e publico e existe exatamente para ser trocado.
##
## Por que ninguem atravessa o vao
## --------------------------------
## Porque nao da. O vao da casa tem 1,05 m, a folha da porta ocupa metade dele e
## o corpo e um monte de caixas: qualquer animacao de entrar mostra o ombro
## atravessando a ombreira. O que acontece de verdade e o truque que a `Porta` do
## jogo ja usa para esconder a construcao do interior na thread — a folha abre, o
## trinco estala, e o resto o jogador preenche sozinho. Some na soleira e volta
## de la minutos depois, e ninguem pergunta como.
class_name MoradorPraca
extends Convidado

enum Fase { FORA, INDO, DENTRO }

## Onde e a soleira da casa dele, em coordenada de mundo.
@export var soleira := Vector3.ZERO
## Para onde a casa olha. Ele vira de frente para a porta antes de sumir — de
## costas para ela, o sumico le como o boneco desaparecendo no meio da rua.
@export var giro_da_casa: float = 0.0

## Quanto tempo ele fica na praca antes de ir para casa, e quanto fica dentro.
##
## Os dois sao longos de proposito. Um morador que entra e sai a cada trinta
## segundos vira um cuco de relogio, e o jogador passa a olhar para a porta em
## vez de olhar para a praca. Nesta escala ele completa uma ida e volta a cada
## dois ou tres minutos, que e mais ou menos o tempo de atravessar a praca,
## olhar a igreja e voltar — ou seja: o jogador ve o movimento acontecer uma vez
## e nao o ve repetir.
const TEMPO_FORA := Vector2(75.0, 190.0)
const TEMPO_DENTRO := Vector2(40.0, 120.0)

## A que distancia da soleira ele ja esta "na porta".
##
## 1,3 m e o raio da capsula mais a soleira de pedra. Menor que isso ele
## encosta na parede e a recuperacao de penetracao do motor o empurra para
## tras — ele ficaria oscilando na frente de casa sem nunca chegar.
const NA_PORTA := 1.3

var _fase: Fase = Fase.FORA
var _quando := 0.0
var _rota_da_praca: Array[Vector3] = []
var _relogio := 0.0


func _ready() -> void:
	super()
	_rota_da_praca = pontos.duplicate()
	# Comeca em ponto aleatorio do ciclo, pelo mesmo motivo que a `Lampada`
	# sorteia o estado inicial: quatro moradores que saem de casa no mesmo
	# segundo leem como cena programada, e e exatamente o que e.
	_quando = randf_range(TEMPO_FORA.x * 0.2, TEMPO_FORA.y)


func _process(delta: float) -> void:
	_relogio += delta
	match _fase:
		Fase.FORA:
			if _relogio >= _quando:
				_ir_para_casa()
		Fase.INDO:
			if global_position.distance_to(soleira) <= NA_PORTA:
				_entrar()
			# Desistencia por tempo. Sem ela, um morador que fique preso atras
			# de um canteiro nunca mais chega em casa e fica empurrando o murete
			# pelo resto da partida — e nao ha ninguem para ver e consertar.
			elif _relogio >= _quando + 90.0:
				_entrar()
		Fase.DENTRO:
			if _relogio >= _quando:
				_sair()


## Troca a rota da praca pela soleira. `Convidado` sorteia o proximo destino da
## lista quando termina a espera atual, entao a troca vale a partir do proximo
## destino e nao no mesmo frame — o que e melhor do que parece: ele nao vira nos
## calcanhares no meio de uma conversa, termina o que estava fazendo e vai.
func _ir_para_casa() -> void:
	_fase = Fase.INDO
	_relogio = 0.0
	_quando = 0.0
	pontos = [soleira] as Array[Vector3]


func _entrar() -> void:
	_fase = Fase.DENTRO
	_relogio = 0.0
	_quando = randf_range(TEMPO_DENTRO.x, TEMPO_DENTRO.y)
	rotation.y = giro_da_casa
	AudioDirector.tocar(&"porta_abre", soleira, -6.0)
	_ocultar(true)


func _sair() -> void:
	_fase = Fase.FORA
	_relogio = 0.0
	_quando = randf_range(TEMPO_FORA.x, TEMPO_FORA.y)
	# Reaparece um passo A FRENTE da soleira, e nao em cima dela: em cima, a
	# capsula nasce dentro da parede e o motor a cospe para o lado.
	var para_fora := Vector3(sin(giro_da_casa), 0.0, cos(giro_da_casa))
	global_position = soleira + para_fora * 0.8
	pontos = _rota_da_praca.duplicate()
	AudioDirector.tocar(&"porta_trinco", soleira, -8.0)
	_ocultar(false)


## Sumir e voltar. Nao basta `visible`: um corpo invisivel continua empurrando
## o jogador e continua respondendo a tecla de interacao, e conversar com uma
## pessoa que nao esta na tela e pior do que ela nao existir.
func _ocultar(dentro: bool) -> void:
	visible = not dentro
	set_physics_process(not dentro)
	velocity = Vector3.ZERO
	# `set_deferred`: mexer em forma de colisao no meio do passo de fisica e o
	# caminho mais curto para um travamento do servidor.
	for filho: Node in get_children():
		var forma := filho as CollisionShape3D
		if forma != null:
			forma.set_deferred(&"disabled", dentro)
		var area := filho as Area3D
		if area != null:
			area.set_deferred(&"monitorable", not dentro)
			area.set_deferred(&"monitoring", not dentro)
