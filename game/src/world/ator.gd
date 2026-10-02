## Personagem com nome, dirigido por roteiro. Hoje: o Berg.
##
## Jota, Helmer e o dono da casa continuam sendo `Convidado` (eles ja tem
## rotina, fumo e fala la dentro); a cena os acha por `Elenco.no` e usa
## `Convidado.estacionar/encarar/dizer` mais `Corpo.fazer_gesto`.
##
## Por que nao e Pedestre nem Convidado
## ------------------------------------
## Os dois tem cerebro proprio: o pedestre anda pela malha de rotas e o
## convidado circula pela sala (e o `_ir` dele nao avisa quando chega). Um personagem de cena precisa do contrario —
## ficar exatamente onde o roteiro mandou, andar ate o ponto que o roteiro
## disse, e AVISAR quando chegou, para o corte seguinte esperar por ele. Os
## verbos aqui sao todos `await`aveis por isso.
##
## Fora de cena ele tem um modo solto so: `vagar_em`, que e o Berg andando em
## volta da igreja ate o jogador falar com ele.
##
## O corpo e o mesmo Corpo de todo mundo. A ficha vem do `Elenco`, e nao do
## registro civil sorteado: o Berg tem de ser o Berg em toda partida.
##
## STUB da branch missao1/base: monta corpo, colisao e gatilho; `andar_ate`
## desliza em linha reta sem animar; `vagar_em` fica parado. A tarefa B
## implementa caminhada, giro, olhar, voz (Fala/Voz) e gestos de verdade, e
## pode passar a herdar de Convidado se isso der o fumo e a voz de graca,
## desde que a API abaixo continue igual.
class_name Ator
extends CharacterBody3D

## Velocidade de caminhada e de corrida, em m/s.
const VEL_ANDAR := 1.35
const VEL_CORRER := 3.4

## O jogador apertou interagir perto dele, fora de cena.
signal interagido(quem: Node)
## Chegou no ponto de `andar_ate`.
signal chegou()

## Quem e, pela chave do Elenco (&"berg").
var quem: StringName = &""
var ficha: Dictionary = {}
## Texto do prompt de interacao. Vazio desliga a interacao.
var rotulo: String = "":
	set(v):
		rotulo = v
		if _gatilho != null:
			_gatilho.rotulo = v
			_gatilho.habilitado = not v.is_empty()

var _corpo: Corpo
var _gatilho: Interativo


func preparar(chave: StringName, nova_ficha: Dictionary) -> void:
	quem = chave
	ficha = nova_ficha


func _ready() -> void:
	add_to_group(&"elenco")
	add_to_group(&"npc")
	collision_layer = 1
	collision_mask = 1
	_corpo = Corpo.new()
	_corpo.name = "Corpo"
	add_child(_corpo)
	_corpo.montar(ficha.get("aparencia", {}))
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.26
	capsula.height = 1.25
	forma.shape = capsula
	forma.position = Vector3(0.0, 0.925, 0.0)
	add_child(forma)
	_gatilho = Interativo.new()
	_gatilho.name = "Gatilho"
	add_child(_gatilho)
	var area := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(1.0, 1.9, 1.0)
	area.shape = caixa
	area.position = Vector3(0.0, 0.95, 0.0)
	_gatilho.add_child(area)
	_gatilho.acionado.connect(func(q: Node) -> void: interagido.emit(q))
	rotulo = rotulo


func corpo() -> Corpo:
	return _corpo


# --- verbos de roteiro (todos com await) ------------------------------------

## Anda ate um ponto do mundo e gira para a direcao do passo. Retorna ao chegar.
func andar_ate(alvo: Vector3, correr: bool = false) -> void:
	var v := VEL_CORRER if correr else VEL_ANDAR
	var dur := maxf(0.05, global_position.distance_to(alvo) / v)
	encarar(alvo)
	var t := create_tween()
	t.tween_property(self, "global_position", alvo, dur)
	await t.finished
	chegou.emit()


## Gira o corpo inteiro para olhar um ponto. Instantaneo no stub.
func encarar(ponto: Vector3) -> void:
	var d := ponto - global_position
	if Vector2(d.x, d.z).length() > 0.01:
		rotation.y = atan2(-d.x, -d.z)


## A cabeca acompanha um no (o jogador, quem fala). null solta.
func olhar_para(_alvo: Node3D) -> void:
	pass


## Toca um gesto do corpo e espera ele terminar.
func fazer(g: Corpo.GestoCena) -> void:
	await _corpo.fazer_gesto(g)


func postura(p: Corpo.Postura) -> void:
	_corpo.postura(p)


## Boca e cabeca de quem esta falando. A Escolha chama isto.
func falar(ativo: bool) -> void:
	_corpo.falar(ativo)


## Solta o papel com o telefone no chao a frente dele. Devolve o no do papel,
## que o jogador pode pegar (vira o item &"bilhete_berg" no inventario).
func soltar_papel() -> Node3D:
	return null


## Anda devagar, parando e olhando em volta, dentro de um raio. Para quando o
## roteiro chama qualquer outro verbo.
func vagar_em(_centro: Vector3, _raio: float) -> void:
	pass


## Vai ate a porta, abre, entra e senta. Retorna sentado e com a porta fechada.
## Depende do Carro (tarefa C) para porta e banco.
func entrar_no_carro(c: Carro, banco: Carro.Banco) -> void:
	await c.abrir_porta(banco)
	c.sentar_no_banco(self, banco)
	await c.fechar_porta(banco)


## O contrario de `entrar_no_carro`. Retorna de pe, do lado de fora.
func sair_do_carro(c: Carro, banco: Carro.Banco) -> void:
	await c.abrir_porta(banco)
	c.levantar_do_banco(banco)
	await c.fechar_porta(banco)
