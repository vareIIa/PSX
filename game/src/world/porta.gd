## Porta de rua que leva a um interior.
##
## A folha gira de verdade, e a animacao existe por um motivo funcional alem do
## estetico: ela e a janela de tempo em que o interior e construido na thread. Se
## a porta abrisse instantaneamente nao haveria onde esconder a construcao, e
## voltaria a tela de carregamento que a Fase 4 promete nao ter.
class_name Porta
extends Interativo

## Quanto a folha gira ao abrir, em graus.
const ANGULO := 96.0
## A duracao vem do Interiores em tempo de execucao. Copiar o numero aqui como
## const criaria duas fontes de verdade que divergem no primeiro ajuste.

## Semente do interior. Deriva da posicao no mundo, entao a mesma porta leva
## sempre ao mesmo apartamento.
@export var semente: int = 0

var _folha: Node3D
var _aberta: bool = false


func _ready() -> void:
	super()
	add_to_group(&"porta")
	rotulo = "Entrar"
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

	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Area de acionamento maior que a folha e um pouco a frente: nao deve ser
	# preciso encostar o nariz na macaneta.
	box.size = Vector3(1.3, 2.1, 1.0)
	forma.shape = box
	forma.position = Vector3(0.45, 1.05, 0.0)
	add_child(forma)


func rotulo_atual() -> String:
	return "Entrando..." if _aberta else "Entrar"


func interagir(quem: Node) -> void:
	if not habilitado or _aberta or Interiores.dentro:
		return
	_aberta = true
	habilitado = false

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_folha, "rotation:y", deg_to_rad(-ANGULO), Interiores.ABERTURA)

	# O retorno guarda a pose do jogador, nao a da porta: sair de costas para a
	# porta e o que a pessoa espera.
	var retorno := (quem as Node3D).global_transform if quem is Node3D \
		else global_transform
	Interiores.entrar(semente, retorno)
	Interiores.entrou.connect(_ao_entrar, CONNECT_ONE_SHOT)


func _ao_entrar() -> void:
	# A porta volta a fechar enquanto ninguem olha, para estar fechada na volta.
	_folha.rotation.y = 0.0
	_aberta = false
	habilitado = true
