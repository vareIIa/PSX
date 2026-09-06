## Base de tudo que o jogador pode acionar com a tecla de interagir.
##
## E um Area3D e nao um corpo de proposito: o alcance de interacao nao deve ser o
## mesmo da colisao. Uma porta bloqueia o corpo pela colisao do cenario e e
## acionada por uma area maior, um pouco a frente dela, para nao ser preciso
## encostar o nariz na maçaneta.
##
## O jogador encontra o alvo por raio a partir da camera, entao a area precisa
## estar na camada de interacao e nao na de mundo.
class_name Interativo
extends Area3D

## Camada fisica reservada para interacao. A camada 1 e o mundo solido.
const CAMADA := 2

## Texto mostrado no prompt. Curto: cabe pouco numa tela de 480x270.
@export var rotulo: String = "Usar"

## Desligado nao aparece no prompt nem responde. Serve para porta trancada que
## ainda nao tem chave, sem precisar tirar o no da cena.
@export var habilitado: bool = true

signal acionado(quem: Node)


func _ready() -> void:
	collision_layer = CAMADA
	collision_mask = 0
	monitorable = true
	monitoring = false
	input_ray_pickable = true


## Chamado pelo jogador. Sobrescreva em vez de conectar ao sinal quando a
## resposta for o proposito do objeto, e nao um efeito colateral.
func interagir(quem: Node) -> void:
	if not habilitado:
		return
	acionado.emit(quem)


## Texto que o prompt mostra agora. Sobrescreva quando o rotulo mudar com o
## estado, por exemplo abrir e fechar.
func rotulo_atual() -> String:
	return rotulo
