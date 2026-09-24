## O amigo na rede fala pela boca e manca ferido (fase 7 do plano de
## personagens). Cena, e nao --script: a `Voz` usa o AudioDirector.
##
##     godot --headless --path game res://tests/checar_amigo_fala.tscn
extends Node

var _passou := 0
var _total := 0


func _ready() -> void:
	_rodar()


func _rodar() -> void:
	await get_tree().process_frame
	var av := AvatarRemoto.new()
	add_child(av)
	av.configurar(7, {"nome": "TESTE",
		"aparencia": Aparencia.de_ficha({"id": 55, "sexo": &"F", "idade": 28})})
	var figura: Corpo = null
	for n in av.find_children("*", "Corpo", true, false):
		figura = n
	av.falar("Bora pro bar, galera?")
	var bocas := {}
	var falando := false
	for i in 90:
		await get_tree().process_frame
		if figura.rosto != null:
			bocas[figura.rosto.estado(&"boca")] = true
		var f := av.get_node_or_null(^"Fala") as Fala
		falando = falando or (f != null and f.falando())
	_conta("chat vira fala do avatar", falando)
	_conta("a boca mexe (tres estados ou mais)", bocas.size() >= 3, str(bocas.keys()))
	print("[amigo_fala] %d/%d" % [_passou, _total])
	get_tree().quit(0 if _passou == _total else 1)


func _conta(nome: String, ok: bool, texto: String = "") -> void:
	_total += 1
	if ok:
		_passou += 1
	print("  [%s] %s  %s" % ["ok" if ok else "FALHOU", nome, texto])
