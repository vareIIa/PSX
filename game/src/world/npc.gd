## Morador da casa. O personagem com quem da para falar dentro de casa.
##
## Existe menos como sistema e mais como contraste: tudo la fora e nevoa, poste
## queimado e coisa que anda mancando, e aqui dentro tem alguem de pe na janela
## com a luz acesa. E o encontro que faz a rua parecer pior depois.
##
## A encenacao da entrada e deliberada e vale mais que qualquer fala:
##
##   1. O jogador entra e ve uma silhueta de costas, parada na janela.
##   2. Chegando perto, ela arrasta o pe e se vira.
##   3. Dai em diante a cabeca acompanha o jogador pela sala.
##
## Nada disso e animacao gravada. Sao tres estados e uma rotacao com limite de
## velocidade, que e o que cabe no orcamento e o que a epoca fazia.
##
## Por que ele usa Corpo, e nao Figura
## -----------------------------------
## Usava `Figura`: seis caixas rigidas, sem rosto, sem cabelo, sem esqueleto.
## Isso foi o corpo de todo mundo ate a rua ganhar `Corpo` — onze ossos, atlas de
## rosto, cabelo e roupa por celula de textura, tudo saindo da ficha do
## RegistroCivil. O morador ficou para tras e a diferenca aparecia na hora: o
## jogador cruzava com dezenas de pessoas de rosto na calcada e entrava em casa
## para falar com um manequim de caixas. A pessoa mais importante do jogo era a
## unica sem cara.
##
## Agora ele monta do mesmo jeito que um pedestre. O ganho nao e so visual: como
## a ficha vem do registro, o morador tem nome, idade, profissao e CPF de
## verdade, e da para procurar ele no celular depois de conversar.
class_name Npc
extends Interativo

## A que distancia ele percebe quem entrou.
##
## Curta de proposito. A encenacao so funciona se o jogador tiver tempo de ver a
## silhueta parada de costas antes de ela reagir: se ele virasse assim que a
## porta abre, a imagem que a casa inteira foi montada para dar nunca aconteceria.
const DISTANCIA_NOTA := 2.4
## Rapidez do giro do corpo, em rad/s. Devagar de proposito: ninguem pivota em
## casa, e a lentidao e o que da peso a virada.
const VELOCIDADE_GIRO := 1.9
## Alem deste angulo o corpo acompanha a cabeca em vez de so torcer o pescoco.
const ANGULO_CORPO := 0.85

enum Estado { ALHEIO, VIRANDO, ATENTO, FALANDO }

## Semente do interior. Serve de chave do que ja foi conversado, para o assunto
## nao reiniciar quando o jogador sai e volta.
@export var semente: int = 0
## Para onde ele olha antes de perceber o jogador.
@export var giro_inicial: float = 0.0

## Ficha do RegistroCivil. Quem cria o no preenche antes de pendurar na arvore;
## vazia, o morador cai numa aparencia neutra em vez de sumir.
var ficha: Dictionary = {}
## Perfil da casa, de CasaBuilder.Perfil. Decide o arco de conversa.
var perfil: int = 0

var _corpo: Corpo
var _estado: Estado = Estado.ALHEIO
var _jogador: Node3D
var _giro_alvo: float = 0.0
var _assunto: StringName = &""
var _nome: String = ""


## Chamado por Interiores antes de pendurar o no. A ficha nao entra pelo
## construtor porque quem resolve o registro e a thread principal, e o builder
## que decidiu a casa rodou noutra.
func preparar(nova_ficha: Dictionary, novo_perfil: int) -> void:
	ficha = nova_ficha
	perfil = novo_perfil


func _ready() -> void:
	super()
	add_to_group(&"npc")
	_nome = String(ficha.get("nome", "MORADOR")).to_upper()
	rotulo = "Falar"
	rotation.y = giro_inicial
	_giro_alvo = giro_inicial
	_montar()


func _montar() -> void:
	_corpo = Corpo.new()
	_corpo.name = "Corpo"
	add_child(_corpo)
	_corpo.montar(ficha.get("aparencia", {}))
	# O jeito da pessoa: como anda, fica parada e mexe as maos (ver `Jeito`).
	_corpo.jeito = Jeito.de(ficha)

	var altura := _corpo.altura()

	# Area de interacao: alta e um pouco larga, para o raio da camera acertar sem
	# o jogador precisar mirar no torso.
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, altura + 0.1, 0.9)
	forma.shape = box
	forma.position = Vector3(0.0, (altura + 0.1) * 0.5, 0.0)
	add_child(forma)

	# Corpo solido separado, na camada do mundo. Sem isso o jogador atravessa a
	# pessoa, e atravessar a pessoa da casa estraga tudo que ela constroi.
	var corpo := StaticBody3D.new()
	corpo.name = "Solido"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	var solido := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.26
	# A capsula acompanha a altura da pessoa: com valor fixo, quem tem 1,55 m
	# ficava com meio metro de coluna invisivel acima da propria cabeca.
	capsula.height = maxf(0.9, altura - 0.22)
	solido.shape = capsula
	solido.position = Vector3(0.0, capsula.height * 0.5 + 0.11, 0.0)
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
	if _corpo != null:
		var sobra := angle_difference(rotation.y, angulo_encarar)
		_corpo.olhar_lateral(-sobra if _estado != Estado.ALHEIO else 0.0)
		_corpo.animar(0.0, delta)


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
	# Depois da primeira conversa o rotulo passa a dizer o nome. E a diferenca
	# entre falar com "o morador" e voltar para falar com alguem.
	if _nome != "" and RegistroCivil.ja_conhece(int(ficha.get("id", -1))):
		return "Falar com %s" % String(ficha.get("primeiro", "")).to_upper()
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

	var bloco := FalasMorador.proxima(semente, ficha, perfil)
	_assunto = bloco["chave"]
	if _corpo != null:
		_corpo.falar(true)
	Dialogo.abrir(_nome, bloco["linhas"], self, ficha)
	Dialogo.fechou.connect(_ao_fechar, CONNECT_ONE_SHOT)


## O corpo, para a `Fala` gesticular e mexer a boca com ele.
func corpo() -> Corpo:
	return _corpo


## O assunto so e marcado como dito quando a conversa termina. Marcar na abertura
## faria uma conversa interrompida contar como ouvida.
func _ao_fechar() -> void:
	FalasMorador.concluir(semente, _assunto, perfil)
	# Conversou, entao o registro passa a conhecer a pessoa: o nome aparece no
	# rotulo e a ficha pode ser procurada no celular. E a mesma regra do
	# pedestre abordado na rua.
	RegistroCivil.conhecer(int(ficha.get("id", -1)))
	if _corpo != null:
		_corpo.falar(false)
	_estado = Estado.ATENTO
