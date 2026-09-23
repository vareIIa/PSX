## Quanto resta em cada vaga de cada loja, e onde esta o que saiu dela.
##
## PLANO_MERCADO_AAA, 4.5. O planograma e deterministico pela semente da loja:
## ele diz como a loja AMANHECE. Aqui mora so a diferenca — as vagas que alguem
## mexeu — no `WorldState`, que entra no save junto com o resto do mundo.
##
## Conservacao
## -----------
## Toda unidade que sai de uma vaga vai para um lugar contado: a mao do jogador,
## a cesta de um freguês, vendida, furtada ou no chao. O teste soma os lugares
## e compara com o que falta nas vagas (memoria `adicionar-devolve-a-sobra`: o
## item que existe em dois lugares passa em todo teste que conta um lado so).
## Por isso nenhum codigo tira unidade de vaga sem dizer para onde ela foi:
## `tirar` e `por` sao o unico caminho, e os dois levam o destino.
##
## Cada vaga guardada leva o SKU junto. Se o catalogo ou o planograma mudarem
## entre um save e outro, a vaga de indice 40 pode passar a ser outro produto; a
## diferenca antiga e descartada em vez de por guarana onde agora e cafe.
class_name EstoqueMercado
extends RefCounted

## Faixa reservada do WorldState, vizinha das do dinheiro (-8) e do iWeed (-9).
const COORD := Vector2i(-10, 424245)

enum Destino { MAO, CESTA, VENDIDO, FURTADO, CHAO }

## Emitido por quem muda uma vaga, para quem desenha a loja acompanhar.
## `EstoqueMercado.mudou` nao existe como sinal estatico em GDScript; quem
## desenha pergunta `versao()` e redesenha quando ela muda.
static var _versao: int = 0


static func _chave(loja: int) -> StringName:
	return StringName("loja_%d" % loja)


static func _dados(loja: int) -> Dictionary:
	var bruto: Variant = WorldState.obter(COORD, _chave(loja), {})
	return (bruto as Dictionary).duplicate(true) if bruto is Dictionary else {}


static func _gravar(loja: int, d: Dictionary) -> void:
	WorldState.definir(COORD, _chave(loja), d)
	_versao += 1


static func versao() -> int:
	return _versao


## Aplica o que foi salvo sobre as vagas do planograma (que chegam como o
## planograma montou). Chamado uma vez, por quem monta a loja.
static func aplicar(loja: int, vagas: Array) -> void:
	var mexidas: Dictionary = _dados(loja).get("vagas", {})
	for chave: Variant in mexidas:
		var i := int(chave)
		if i < 0 or i >= vagas.size():
			continue
		var salvo: Dictionary = mexidas[chave]
		var v: Dictionary = vagas[i]
		if StringName(salvo.get("sku", "")) != StringName(v["sku"]):
			continue
		var cols: Array = salvo.get("colunas", [])
		if cols.size() != int(v["frentes"]):
			continue
		var novas := PackedInt32Array()
		for q: Variant in cols:
			novas.append(clampi(int(q), 0, int(v["fundo"])))
		v["colunas"] = novas


static func _guardar_vaga(loja: int, indice: int, v: Dictionary) -> Dictionary:
	var d := _dados(loja)
	var mexidas: Dictionary = d.get("vagas", {})
	var cols: Array = []
	for q: int in v["colunas"]:
		cols.append(q)
	mexidas[str(indice)] = {"sku": String(v["sku"]), "colunas": cols}
	d["vagas"] = mexidas
	return d


## Tira a unidade da frente de uma coluna. Falso se ela esta vazia.
static func tirar(loja: int, vagas: Array, indice: int, coluna: int,
		destino: Destino) -> bool:
	var v: Dictionary = vagas[indice]
	var cols: PackedInt32Array = v["colunas"]
	if coluna < 0 or coluna >= cols.size() or cols[coluna] <= 0:
		return false
	cols[coluna] -= 1
	v["colunas"] = cols
	var d := _guardar_vaga(loja, indice, v)
	var saidas: Dictionary = d.get("saidas", {})
	var k := str(destino)
	saidas[k] = int(saidas.get(k, 0)) + 1
	d["saidas"] = saidas
	_gravar(loja, d)
	return true


## Devolve uma unidade a uma coluna, vinda de `origem`. Falso se nao cabe.
static func por(loja: int, vagas: Array, indice: int, coluna: int,
		origem: Destino) -> bool:
	var v: Dictionary = vagas[indice]
	var cols: PackedInt32Array = v["colunas"]
	if coluna < 0 or coluna >= cols.size() or cols[coluna] >= int(v["fundo"]):
		return false
	cols[coluna] += 1
	v["colunas"] = cols
	var d := _guardar_vaga(loja, indice, v)
	var saidas: Dictionary = d.get("saidas", {})
	var k := str(origem)
	saidas[k] = int(saidas.get(k, 0)) - 1
	d["saidas"] = saidas
	_gravar(loja, d)
	return true


## Quantas unidades desta loja estao em cada destino (so o que saiu e nao
## voltou). A soma e o que falta nas prateleiras.
static func saidas(loja: int) -> Dictionary:
	var bruto: Dictionary = _dados(loja).get("saidas", {})
	var saida: Dictionary = {}
	for d in Destino.values():
		saida[d] = int(bruto.get(str(d), 0))
	return saida


# --- a mao do jogador ---------------------------------------------------------

## O que o jogador tem na mao, vindo da loja: {sku, loja} ou vazio.
##
## Guardado aqui, e nao no inventario, porque ainda nao e dele: o produto so vira
## item quando passa pelo caixa (F4). Entra no save para que carregar um jogo
## com a lata na mao nao faca a lata sumir do mundo — sairia da prateleira e
## nao estaria em lugar nenhum.
static func na_mao() -> Dictionary:
	var bruto: Variant = WorldState.obter(COORD, &"mao", {})
	return (bruto as Dictionary).duplicate() if bruto is Dictionary else {}


static func segurar(sku: StringName, loja: int) -> void:
	WorldState.definir(COORD, &"mao", {"sku": String(sku), "loja": loja})
	_versao += 1


static func soltar() -> void:
	WorldState.definir(COORD, &"mao", {})
	_versao += 1
