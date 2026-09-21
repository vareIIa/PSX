## O controle do PS2 largado no tapete: pegar e jogar a partida da TV.
##
## Pegar o controle senta o jogador no tapete de frente para a TV, como o sofa
## faz, e fecha a lente num tubo de 29 polegadas (FOV 16): a tres metros a tela
## tem 55 cm e, no campo de visao normal, o jogo seria um selo no fundo da sala.
## A partir dai a entrada e da partida (PartidaPS2), e nao do corpo:
##
##     andar        mover o jogador da vez
##     [E] / A      passe (sem a bola: bote)
##     [Q] / Y      chute (tambem [L] / X, que e o quadrado)
##     [Shift] / L3 correr
##     [Esc] / B    largar o controle
##
## A entrada e lida em `_input`, antes da prancha e do jogador, e consumida: o
## Esc aqui larga o controle em vez de abrir a bolsa, e o E chuta a bola em vez
## de procurar o que ha na mira.
class_name ControlePS2
extends Interativo

## Onde o jogador senta e para onde olha, no espaco do no pai (o comodo).
@export var onde: Vector3 = Vector3.ZERO
@export var olhar: Vector3 = Vector3.ZERO
@export var olho: float = 0.78

const FOV := 16.0
const ALCANCE_TV := 8.0
const DICA := "[E/A] passe   [Q/Y] chute   [Shift] correr   [Esc/B] largar"

var _jogador: Node3D
var _partida: PartidaPS2
var _antes: Transform3D


func _ready() -> void:
	super()
	rotulo = "Pegar o controle e jogar"
	acionado.connect(_pegar)
	set_process_input(false)
	set_process(false)


func _pegar(quem: Node) -> void:
	var j := quem as Node3D
	if _jogador != null or j == null or not j.has_method("travar"):
		return
	var tv := _tv_mais_perto()
	if tv == null or tv.partida() == null:
		return
	_partida = tv.partida()
	_jogador = j
	_antes = j.global_transform
	var raiz := get_parent() as Node3D
	j.global_position = raiz.to_global(onde)
	j.call("definir_olho", olho)
	j.call("olhar_para", raiz.to_global(olhar))
	j.call("travar", true)
	j.set("fov_override", FOV)
	if j.has_method("ocupar"):
		# Rotulo sem acao: a saida e o Esc, lido aqui. O [E] e passe.
		j.call("ocupar", DICA, Callable())
	_partida.humano = true
	habilitado = false
	set_process_input(true)
	set_process(true)
	AudioDirector.tocar_ui(&"clique", -10.0)


func _largar() -> void:
	if _jogador == null:
		return
	_jogador.global_transform = _antes
	_jogador.call("liberar_olho")
	_jogador.call("travar", false)
	_jogador.set("fov_override", -1.0)
	if _jogador.has_method("desocupar"):
		_jogador.call("desocupar")
	_partida.humano = false
	_partida.entrada(Vector2.ZERO, false)
	_jogador = null
	habilitado = true
	set_process_input(false)
	set_process(false)


func _exit_tree() -> void:
	# A casa descarregando com o jogador jogando (teleporte, save): devolve o
	# corpo antes de sumir, senao ele fica travado sem ninguem para soltar.
	_largar()


func _input(evento: InputEvent) -> void:
	if _jogador == null:
		return
	if evento.is_action_pressed("pausa"):
		_largar()
	elif evento.is_action_pressed("interagir"):
		_partida.passe()
	elif evento.is_action_pressed("examinar") or evento.is_action_pressed("lanterna"):
		_partida.chute()
	elif not (evento.is_action("correr") or evento.is_action("interagir")
			or evento.is_action("examinar") or evento.is_action("lanterna")):
		return
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _jogador == null or _partida == null:
		return
	_partida.entrada(
		Input.get_vector("mover_esq", "mover_dir", "mover_frente", "mover_tras"),
		Input.is_action_pressed("correr"))


func _tv_mais_perto() -> Televisao:
	var melhor: Televisao = null
	var d_melhor := ALCANCE_TV
	for no: Node in get_tree().get_nodes_in_group(&"televisao"):
		var tv := no as Televisao
		if tv == null:
			continue
		var d := tv.global_position.distance_to(global_position)
		if d < d_melhor:
			d_melhor = d
			melhor = tv
	return melhor
