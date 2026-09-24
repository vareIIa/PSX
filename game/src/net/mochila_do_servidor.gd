## A mochila de um jogador, do lado do servidor (plano 08 secao 1.2).
##
## As mesmas regras de pilha do `Inventario`: 8 espacos, primeiro completa as
## pilhas do mesmo item, depois ocupa espaco vazio, e `adicionar` devolve a SOBRA
## que nao coube (memoria do projeto: a condicao invertida passa no teste e o
## item existe nos dois lugares). Pura: nao le autoload; quem cria diz quanto
## cabe numa pilha de cada item (`pilha`: id -> maximo por espaco, 0 = item que
## nao existe).
class_name MochilaDoServidor
extends RefCounted

const ESPACOS := 8

## Cada espaco: {"id": StringName, "qtd": int} ou {}.
var espacos: Array[Dictionary] = []

var _pilha: Callable


func _init(pilha: Callable) -> void:
	_pilha = pilha
	espacos.resize(ESPACOS)
	for i in ESPACOS:
		espacos[i] = {}


func quantidade(id: StringName) -> int:
	var total := 0
	for e: Dictionary in espacos:
		if not e.is_empty() and e["id"] == id:
			total += int(e["qtd"])
	return total


## Quanto de `id` ainda cabe.
func cabe(id: StringName) -> int:
	var maximo := int(_pilha.call(id))
	if maximo <= 0:
		return 0
	var n := 0
	for e: Dictionary in espacos:
		if e.is_empty():
			n += maximo
		elif e["id"] == id and maximo > 1:
			n += maximo - int(e["qtd"])
	return n


## Poe o que couber; devolve a sobra.
func adicionar(id: StringName, qtd: int) -> int:
	var maximo := int(_pilha.call(id))
	if maximo <= 0 or qtd <= 0:
		return maxi(qtd, 0)
	var resta := qtd
	if maximo > 1:
		for e: Dictionary in espacos:
			if resta <= 0:
				break
			if e.is_empty() or e["id"] != id:
				continue
			var move := mini(maximo - int(e["qtd"]), resta)
			e["qtd"] = int(e["qtd"]) + move
			resta -= move
	for i in espacos.size():
		if resta <= 0:
			break
		if not espacos[i].is_empty():
			continue
		var move := mini(maximo, resta)
		espacos[i] = {"id": id, "qtd": move}
		resta -= move
	return resta


## Tira `qtd` do espaco `i`. Devolve {"id", "qtd"} do que saiu, ou {} se nao da.
func tirar_do_espaco(i: int, qtd: int) -> Dictionary:
	if i < 0 or i >= espacos.size() or espacos[i].is_empty() or qtd <= 0:
		return {}
	var e := espacos[i]
	if int(e["qtd"]) < qtd:
		return {}
	e["qtd"] = int(e["qtd"]) - qtd
	var saiu := {"id": e["id"], "qtd": qtd}
	if int(e["qtd"]) <= 0:
		espacos[i] = {}
	return saiu


## Do formato do `Inventario.para_dicionario` ({"espacos": [{id, qtd}|{}], ...}).
## O que nao presta (item que nao existe, quantidade fora da pilha) fica de fora:
## e o que um cliente adulterado mandaria.
func de_dicionario(dados: Dictionary) -> void:
	for i in ESPACOS:
		espacos[i] = {}
	var lista: Variant = dados.get("espacos", [])
	if not (lista is Array):
		return
	for i in mini((lista as Array).size(), ESPACOS):
		var e: Variant = (lista as Array)[i]
		if not (e is Dictionary) or (e as Dictionary).is_empty():
			continue
		var id := StringName(str((e as Dictionary).get("id", "")))
		var qtd := int((e as Dictionary).get("qtd", 0))
		var maximo := int(_pilha.call(id))
		if maximo <= 0 or qtd <= 0 or qtd > maximo:
			continue
		espacos[i] = {"id": id, "qtd": qtd}


func para_dicionario() -> Dictionary:
	var lista: Array = []
	for e: Dictionary in espacos:
		lista.append({} if e.is_empty() else {"id": String(e["id"]), "qtd": int(e["qtd"])})
	return {"espacos": lista}
