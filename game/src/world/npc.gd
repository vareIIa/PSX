## Morador da casa. O unico personagem vivo do jogo com quem da para falar.
##
## Existe menos como sistema e mais como contraste: tudo la fora e nevoa, poste
## queimado e coisa que anda mancando, e aqui dentro tem um senhor de pe na
## janela com a luz acesa. E o encontro que faz a rua parecer pior depois.
##
## A encenacao da entrada e deliberada e vale mais que qualquer fala:
##
##   1. O jogador entra e ve uma silhueta de costas, parada na janela.
##   2. Chegando perto, ela arrasta o pe e se vira.
##   3. Dai em diante a cabeca acompanha o jogador pela sala.
##
## Nada disso e animacao gravada. Sao tres estados e uma rotacao com limite de
## velocidade, que e o que cabe no orcamento e o que a epoca fazia.
class_name Npc
extends Interativo

## A que distancia ele percebe quem entrou.
##
## Curta de proposito. A encenacao so funciona se o jogador tiver tempo de ver a
## silhueta parada de costas antes de ela reagir: se ele virasse assim que a
## porta abre, a imagem que a casa inteira foi montada para dar nunca aconteceria.
const DISTANCIA_NOTA := 2.4
## Rapidez do giro do corpo, em rad/s. Devagar de proposito: gente velha nao
## pivota, e a lentidao e o que da peso a virada.
const VELOCIDADE_GIRO := 1.9
## Alem deste angulo o corpo acompanha a cabeca em vez de so torcer o pescoco.
const ANGULO_CORPO := 0.85

const ALTURA_OLHO := 1.45

enum Estado { ALHEIO, VIRANDO, ATENTO, FALANDO }

## Semente do interior. Serve de chave do que ja foi conversado, para o assunto
## nao reiniciar quando o jogador sai e volta.
@export var semente: int = 0
## Para onde ele olha antes de perceber o jogador.
@export var giro_inicial: float = 0.0

var _figura: Figura
var _estado: Estado = Estado.ALHEIO
var _jogador: Node3D
var _giro_alvo: float = 0.0
var _assunto: StringName = &""


func _ready() -> void:
	super()
	add_to_group(&"npc")
	rotulo = "Falar"
	rotation.y = giro_inicial
	_giro_alvo = giro_inicial
	_montar()


func _montar() -> void:
	_figura = Figura.new()
	_figura.name = "Figura"
	add_child(_figura)
	_figura.montar(Figura.MORADOR)

	# Area de interacao: alta e um pouco larga, para o raio da camera acertar sem
	# o jogador precisar mirar no torso.
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 1.8, 0.9)
	forma.shape = box
	forma.position = Vector3(0.0, 0.9, 0.0)
	add_child(forma)

	# Corpo solido separado, na camada do mundo. Sem isso o jogador atravessa a
	# pessoa, e atravessar a unica pessoa do jogo estraga tudo que ela constroi.
	var corpo := StaticBody3D.new()
	corpo.name = "Corpo"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	var solido := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.28
	capsula.height = 1.5
	solido.shape = capsula
	solido.position = Vector3(0.0, 0.78, 0.0)
	corpo.add_child(solido)
	add_child(corpo)


func _process(delta: float) -> void:
	if _jogador == null:
		_jogador = get_tree().get_first_node_in_group(&"player") as Node3D
		if _jogador == null:
			return

	var para_o_jogador := _jogador.global_position - global_position
	para_o_jogador.y = 0.0
	var distancia := para_o_jogador.length()
	# O -Z do no e a frente, entao o angulo que encara o jogador e este.
	var angulo_encarar := atan2(-para_o_jogador.x, -para_o_jogador.z)

	match _estado:
		Estado.ALHEIO:
			if distancia < DISTANCIA_NOTA:
				_notar(angulo_encarar)
		Estado.VIRANDO:
			if absf(angle_difference(rotation.y, _giro_alvo)) < 0.06:
				rotation.y = _giro_alvo
				_estado = Estado.ATENTO
		Estado.ATENTO:
			if distancia > DISTANCIA_NOTA * 1.7:
				# Perdeu o interesse e volta a olhar a janela. Ficar encarando
				# para sempre transformaria o morador em camera de seguranca.
				_estado = Estado.ALHEIO
				_giro_alvo = giro_inicial
			else:
				_acompanhar(angulo_encarar)
		Estado.FALANDO:
			_acompanhar(angulo_encarar)

	_girar_corpo(delta)

	# A cabeca cobre o que o corpo ainda nao cobriu.
	if _figura != null:
		var sobra := angle_difference(rotation.y, angulo_encarar)
		_figura.olhar_lateral(-sobra if _estado != Estado.ALHEIO else 0.0)
		_figura.animar(0.0, delta)


func _notar(angulo: float) -> void:
	_estado = Estado.VIRANDO
	_giro_alvo = angulo
	# O pe arrastando e o aviso sonoro da virada. Sem som a virada acontece fora
	# do campo de visao do jogador metade das vezes e ele nunca fica sabendo.
	AudioDirector.passo(&"madeira", global_position, 0.55)


## Mantem o corpo dentro do limite do pescoco. So gira quando precisa: corpo
## seguindo o jogador o tempo todo e tao errado quanto corpo congelado.
func _acompanhar(angulo_encarar: float) -> void:
	var sobra := angle_difference(_giro_alvo, angulo_encarar)
	if absf(sobra) > ANGULO_CORPO:
		_giro_alvo = angulo_encarar


func _girar_corpo(delta: float) -> void:
	var passo := VELOCIDADE_GIRO * delta
	var d := angle_difference(rotation.y, _giro_alvo)
	rotation.y += clampf(d, -passo, passo)


func rotulo_atual() -> String:
	if Dialogo.ativo:
		return ""
	return "Falar com o morador"


func interagir(quem: Node) -> void:
	if not habilitado or Dialogo.ativo:
		return
	# Encara antes de abrir a caixa de fala. Conversar com a nuca e o tipo de
	# detalhe que ninguem elogia e todo mundo repara.
	if _jogador != null:
		var d := _jogador.global_position - global_position
		_giro_alvo = atan2(-d.x, -d.z)
	_estado = Estado.FALANDO
	acionado.emit(quem)

	var bloco := FalasMorador.proxima(semente)
	_assunto = bloco["chave"]
	Dialogo.abrir(FalasMorador.NOME, bloco["linhas"])
	Dialogo.fechou.connect(_ao_fechar, CONNECT_ONE_SHOT)


## O assunto so e marcado como dito quando a conversa termina. Marcar na abertura
## faria uma conversa interrompida contar como ouvida.
func _ao_fechar() -> void:
	FalasMorador.concluir(semente, _assunto)
	_estado = Estado.ATENTO
