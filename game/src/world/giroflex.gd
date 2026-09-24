## Giroflex de viatura: par de luzes vermelha e azul que alternam.
##
## Pisca sozinho. Antes quem piscava era a `Blitz`, no `_process` dela; com a
## viatura virando carro de verdade, o jogador pode sair dirigindo com ela, e o
## giroflex congelava no ultimo quadro assim que a blitz sumia para tras.
class_name Giroflex
extends Node3D

const PERIODO := 0.28
const ACESA := 4.2
const APAGADA := 0.15

var ligado := true
var _t := 0.0
var _r: OmniLight3D
var _b: OmniLight3D


func _ready() -> void:
	_r = get_node_or_null(^"R") as OmniLight3D
	_b = get_node_or_null(^"B") as OmniLight3D


func _process(delta: float) -> void:
	_t += delta
	var fase := int(floor(_t / PERIODO)) % 2
	if _r != null:
		_r.light_energy = (ACESA if fase == 0 else APAGADA) if ligado else 0.0
	if _b != null:
		_b.light_energy = (ACESA if fase == 1 else APAGADA) if ligado else 0.0
