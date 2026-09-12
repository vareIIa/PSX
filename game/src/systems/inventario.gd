## Autoload. Bolsa do jogador, com espaco contado.
##
## O limite de espaco nao e burocracia: e o sistema que faz o jogador escolher
## entre carregar municao ou curativo, e e dessa escolha que vem a tensao. Bolsa
## infinita transforma survival horror em passeio.
##
## Municao e cura contam em unidades inteiras, nunca em porcentagem. "Tres balas"
## assusta; "37% de municao" nao diz nada.
extends Node

const DIR_ITENS := "res://resources/itens/"
const ESPACOS := 8

signal mudou()
signal item_recebido(item: Item, quantidade: int)
signal espaco_insuficiente(item: Item)
signal vida_mudou(atual: int, maximo: int)
## De onde veio a pancada, em coordenada de mundo. `Vector3.INF` quer dizer
## "de lugar nenhum" — queda, veneno, roteiro.
##
## Existe separado de `vida_mudou` porque quem quer a direcao (o clarao de dano)
## e quem quer o numero (a faixa, a prancha) nao sao o mesmo leitor, e `curar`
## nunca tem direcao.
signal feriu(pontos: int, origem: Vector3)

## Cada espaco e {item: Item, qtd: int} ou vazio.
var espacos: Array[Dictionary] = []

var vida: int = 100
var vida_maxima: int = 100

var _catalogo: Dictionary[StringName, Item] = {}


func _ready() -> void:
	espacos.resize(ESPACOS)
	for i in ESPACOS:
		espacos[i] = {}
	_carregar_catalogo()


func _carregar_catalogo() -> void:
	# Recursos.listar e nao DirAccess direto: no pacote exportado os .tres viram
	# .tres.remap e um filtro ingenuo devolve lista vazia, deixando o jogo sem
	# item nenhum sem dar erro.
	for caminho: String in Recursos.listar(DIR_ITENS, "tres"):
		var item := load(caminho) as Item
		if item == null or item.id == &"":
			push_error("Inventario: %s nao e um Item valido" % caminho)
			continue
		_catalogo[item.id] = item

	if _catalogo.is_empty():
		push_error("Inventario: catalogo vazio, nenhum item carregado de %s" % DIR_ITENS)


func _exit_tree() -> void:
	_catalogo.clear()
	for i in espacos.size():
		espacos[i] = {}


func definicao(id: StringName) -> Item:
	return _catalogo.get(id)


func todos_os_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _catalogo:
		ids.append(id)
	ids.sort()
	return ids


# --- consulta ---------------------------------------------------------------

func quantidade(id: StringName) -> int:
	var total := 0
	for e: Dictionary in espacos:
		if not e.is_empty() and (e["item"] as Item).id == id:
			total += int(e["qtd"])
	return total


func tem(id: StringName, minimo: int = 1) -> bool:
	return quantidade(id) >= minimo


func espacos_livres() -> int:
	var n := 0
	for e: Dictionary in espacos:
		if e.is_empty():
			n += 1
	return n


# --- alteracao --------------------------------------------------------------

## Adiciona o que couber. Devolve quanto sobrou sem lugar.
##
## Devolver a sobra em vez de recusar tudo importa: pegar duas de tres balas e
## deixar uma no chao e uma decisao legitima, e o mundo tem que lembrar dela.
func adicionar(id: StringName, qtd: int = 1) -> int:
	var item := definicao(id)
	if item == null:
		push_warning("Inventario: item desconhecido '%s'" % id)
		return qtd

	var resta := qtd

	if item.e_empilhavel():
		for e: Dictionary in espacos:
			if resta <= 0:
				break
			if e.is_empty() or (e["item"] as Item).id != id:
				continue
			var cabe: int = item.max_pilha - int(e["qtd"])
			var move := mini(cabe, resta)
			e["qtd"] = int(e["qtd"]) + move
			resta -= move

	for i in espacos.size():
		if resta <= 0:
			break
		if not espacos[i].is_empty():
			continue
		var move := mini(item.max_pilha if item.e_empilhavel() else 1, resta)
		espacos[i] = {"item": item, "qtd": move}
		resta -= move

	if resta < qtd:
		item_recebido.emit(item, qtd - resta)
		mudou.emit()
	if resta > 0:
		espaco_insuficiente.emit(item)
	return resta


func remover(id: StringName, qtd: int = 1) -> bool:
	if not tem(id, qtd):
		return false
	var resta := qtd
	for i in espacos.size():
		if resta <= 0:
			break
		var e := espacos[i]
		if e.is_empty() or (e["item"] as Item).id != id:
			continue
		var tira := mini(int(e["qtd"]), resta)
		e["qtd"] = int(e["qtd"]) - tira
		resta -= tira
		if int(e["qtd"]) <= 0:
			espacos[i] = {}
	mudou.emit()
	return true


## Usa o item de um espaco. Devolve true se algo aconteceu.
func usar(indice: int) -> bool:
	if indice < 0 or indice >= espacos.size() or espacos[indice].is_empty():
		return false
	var item: Item = espacos[indice]["item"]

	if item.tipo == Item.Tipo.CURA and item.cura > 0:
		if vida >= vida_maxima:
			return false   # nao desperdica curativo com a vida cheia
		curar(item.cura)
		if item.consumivel:
			remover(item.id, 1)
		return true

	return false


func curar(pontos: int) -> void:
	vida = clampi(vida + pontos, 0, vida_maxima)
	vida_mudou.emit(vida, vida_maxima)


func ferir(pontos: int, origem: Vector3 = Vector3.INF) -> void:
	vida = clampi(vida - pontos, 0, vida_maxima)
	feriu.emit(pontos, origem)
	vida_mudou.emit(vida, vida_maxima)


## Rotulo de estado no painel, como na referencia de inventario.
func estado() -> String:
	var f := float(vida) / float(maxi(1, vida_maxima))
	if f >= 0.75:
		return "BEM"
	if f >= 0.4:
		return "FERIDO"
	if f > 0.0:
		return "GRAVE"
	return "MORTO"


func cor_do_estado() -> Color:
	var f := float(vida) / float(maxi(1, vida_maxima))
	if f >= 0.75:
		return Color("8fd96a")
	if f >= 0.4:
		return Color("e8c351")
	return Color("d4553f")


# --- persistencia -----------------------------------------------------------

func para_dicionario() -> Dictionary:
	var lista: Array = []
	for e: Dictionary in espacos:
		lista.append({} if e.is_empty()
			else {"id": String((e["item"] as Item).id), "qtd": int(e["qtd"])})
	return {"espacos": lista, "vida": vida}


func de_dicionario(dados: Dictionary) -> void:
	for i in espacos.size():
		espacos[i] = {}
	var lista: Array = dados.get("espacos", [])
	for i in mini(lista.size(), espacos.size()):
		var e: Dictionary = lista[i]
		if e.is_empty():
			continue
		var item := definicao(StringName(e.get("id", "")))
		if item == null:
			continue
		espacos[i] = {"item": item, "qtd": int(e.get("qtd", 1))}
	vida = int(dados.get("vida", vida_maxima))
	mudou.emit()
	vida_mudou.emit(vida, vida_maxima)
