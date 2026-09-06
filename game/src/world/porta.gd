## Porta. Leva a um interior, ou nao leva a lugar nenhum quando esta trancada.
##
## A folha gira de verdade, e a animacao existe por um motivo funcional alem do
## estetico: ela e a janela de tempo em que o interior e construido na thread. Se
## a porta abrisse instantaneamente nao haveria onde esconder a construcao, e
## voltaria a tela de carregamento que a Fase 4 promete nao ter.
##
## A abertura tem tres tempos, e a divisao e o que da peso:
##
##   1. a macaneta gira e o trinco estala
##   2. a folha cede e abre, desacelerando
##   3. assenta alguns graus de volta, como porta que passou do ponto
##
## Folha que sai girando sozinha num movimento so le como porta de cenario. Os
## tres tempos cabem exatamente no orcamento de tempo da construcao.
class_name Porta
extends Interativo

## Quanto a folha gira ao abrir, em graus.
const ANGULO := 96.0
## Quanto ela volta ao assentar.
const ASSENTA := 5.0
## Sacudida da folha trancada, em graus. Pequena: porta trancada quase nao anda,
## e e justamente o quase que comunica que esta travada.
const CHACOALHO := 2.4

## Semente do interior. Deriva da posicao no mundo, entao a mesma porta leva
## sempre ao mesmo lugar.
@export var semente: int = 0

## Que planta a porta abre. Ver Interiores.entrar.
@export var interior: StringName = &"apartamento"

## Trancada nao abre e nao constroi nada: so chacoalha e devolve o som.
@export var trancada: bool = false

var _folha: Node3D
var _macaneta: MeshInstance3D
var _aberta: bool = false
var _ocupada: bool = false


func _ready() -> void:
	super()
	add_to_group(&"porta")
	_montar()


func _montar() -> void:
	# Pivo na dobradica, nao no centro: porta girando pelo meio e o erro classico
	# que faz a folha atravessar a parede.
	_folha = Node3D.new()
	_folha.name = "Folha"
	add_child(_folha)

	var mi := MeshInstance3D.new()
	mi.name = "Malha"
	mi.mesh = PSXMesh.box(Vector3(0.9, 2.05, 0.07), 1.0)
	mi.material_override = load("res://resources/materials/mat_porta.tres")
	mi.position = Vector3(0.45, 1.025, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_folha.add_child(mi)

	# Macaneta na ponta livre da folha. Custa doze triangulos e e o que faz a
	# folha ler como porta em vez de tapume: e nela que o olho procura para
	# saber de que lado a coisa abre.
	_macaneta = MeshInstance3D.new()
	_macaneta.name = "Macaneta"
	_macaneta.mesh = PSXMesh.box(Vector3(0.05, 0.05, 0.16), 2.0)
	_macaneta.material_override = load("res://resources/materials/mat_metal.tres")
	_macaneta.position = Vector3(0.79, 1.02, 0.0)
	_macaneta.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_folha.add_child(_macaneta)

	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Area de acionamento maior que a folha e um pouco a frente: nao deve ser
	# preciso encostar o nariz na macaneta.
	box.size = Vector3(1.3, 2.1, 1.0)
	forma.shape = box
	forma.position = Vector3(0.45, 1.05, 0.0)
	add_child(forma)


func rotulo_atual() -> String:
	if trancada:
		return "Trancada"
	if _aberta:
		return "Entrando..."
	return "Entrar na casa" if interior == &"casa" else "Entrar"


func interagir(quem: Node) -> void:
	if not habilitado or _ocupada or Interiores.dentro:
		return
	if trancada:
		_sacudir()
		return
	_abrir(quem)


# --- abertura ---------------------------------------------------------------

func _abrir(quem: Node) -> void:
	_aberta = true
	_ocupada = true
	habilitado = false

	AudioDirector.tocar(&"porta_trinco", global_position, -4.0)

	var t := create_tween()
	# 1. macaneta.
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(_macaneta, "rotation:z", -0.55, 0.09)
	# 2. a folha cede. O rangido entra aqui e nao no comeco: no comeco ele se
	# perde debaixo do estalo do trinco.
	t.tween_callback(func() -> void:
		AudioDirector.tocar(&"porta_abre", global_position, -6.0))
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_folha, "rotation:y", deg_to_rad(-ANGULO),
		Interiores.ABERTURA * 0.72)
	# 3. assenta.
	t.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(_folha, "rotation:y", deg_to_rad(-ANGULO + ASSENTA),
		Interiores.ABERTURA * 0.19)

	# O retorno guarda a pose do jogador, nao a da porta: sair de costas para a
	# porta e o que a pessoa espera.
	var retorno := (quem as Node3D).global_transform if quem is Node3D \
		else global_transform
	Interiores.entrar(semente, retorno, interior)
	Interiores.entrou.connect(_ao_entrar, CONNECT_ONE_SHOT)


func _ao_entrar() -> void:
	# A porta volta a fechar enquanto ninguem olha, para estar fechada na volta.
	_folha.rotation.y = 0.0
	_macaneta.rotation.z = 0.0
	_aberta = false
	_ocupada = false
	habilitado = true


## Porta trancada: a macaneta gira ate o fim do curso, a folha bate duas vezes
## contra o batente e volta. E a resposta que o jogador precisa para entender que
## a porta e real e que a chave e que falta, em vez de ser cenario pintado.
func _sacudir() -> void:
	_ocupada = true
	AudioDirector.tocar(&"porta_trava", global_position, -3.0)

	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(_macaneta, "rotation:z", -0.32, 0.07)
	for k in 2:
		t.tween_property(_folha, "rotation:y", deg_to_rad(-CHACOALHO), 0.06)
		t.tween_property(_folha, "rotation:y", 0.0, 0.08)
	t.parallel().tween_property(_macaneta, "rotation:z", 0.0, 0.12)
	t.tween_callback(func() -> void: _ocupada = false)
