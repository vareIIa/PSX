## Escrita por diferenca para os valores do mundo que sao dicionario (a prateleira
## da loja, o plantio da estufa).
##
## O jogo grava o dicionario inteiro. Em rede, se dois jogadores tiram produto da
## mesma prateleira no mesmo segundo, cada um manda a prateleira "sem o seu", e o
## segundo a chegar devolve o produto do primeiro: item duplicado. Mandando so o
## que mudou, o servidor aplica as duas mudancas sobre o que ele tem, e as duas
## ficam.
##
## Remendo: {"p": {chave: valor_ou_remendo}, "a": [chaves apagadas]}. Um valor
## que e ele mesmo remendo vem marcado por "__r" (dicionario do jogo nunca usa
## essa chave), e se aplica por dentro. Lista e escalar trocam inteiros.
class_name FusaoDeMundo
extends RefCounted

const MARCA := "__r"
## Profundidade maxima de um valor aceito da rede. A prateleira chega a 4, e o
## remendo dela ao dobro (cada nivel ganha um "p"). O teto e contra pilha de
## recursao de quem manda lixo; o tamanho ja e limitado em bytes.
const FUNDO_MAX := 16


## O remendo que leva `antes` a `depois`. Vazio ({"p": {}, "a": []}) se iguais.
static func diferenca(antes: Variant, depois: Dictionary) -> Dictionary:
	var a: Dictionary = antes if antes is Dictionary else {}
	var p := {}
	var apagadas: Array = []
	for k: Variant in depois:
		var v: Variant = depois[k]
		if not a.has(k):
			p[k] = _copia(v)
			continue
		var velho: Variant = a[k]
		if v is Dictionary and velho is Dictionary:
			var sub := diferenca(velho, v)
			if not vazio(sub):
				sub[MARCA] = true
				p[k] = sub
		elif typeof(v) != typeof(velho) or v != velho:
			p[k] = _copia(v)
	for k: Variant in a:
		if not depois.has(k):
			apagadas.append(k)
	return {"p": p, "a": apagadas}


static func vazio(remendo: Dictionary) -> bool:
	return (remendo.get("p", {}) as Dictionary).is_empty() and (remendo.get("a", []) as Array).is_empty()


## `base` com o remendo aplicado. Nao altera `base`. Remendo torto (vindo de um
## cliente) devolve null: quem chama recusa o pedido.
static func aplicar(base: Variant, remendo: Variant) -> Variant:
	if not (remendo is Dictionary):
		return null
	var r: Dictionary = remendo
	var p: Variant = r.get("p", {})
	var ap: Variant = r.get("a", [])
	if not (p is Dictionary) or not (ap is Array):
		return null
	var saida: Dictionary = (base as Dictionary).duplicate(true) if base is Dictionary else {}
	for k: Variant in (ap as Array):
		saida.erase(k)
	for k: Variant in (p as Dictionary):
		if typeof(k) == TYPE_STRING and String(k) == MARCA:
			continue
		var v: Variant = p[k]
		if v is Dictionary and (v as Dictionary).has(MARCA):
			var dentro: Variant = aplicar(saida.get(k), v)
			if dentro == null:
				return null
			saida[k] = dentro
		else:
			saida[k] = _copia(v)
	return saida


## So dado de jogo: escalar finito, texto, vetor inteiro, lista e dicionario disso,
## ate FUNDO_MAX de profundidade. Objeto, Callable, NaN e afins nunca entram no
## mundo de ninguem.
static func valor_limpo(v: Variant, fundo: int = 0) -> bool:
	if fundo > FUNDO_MAX:
		return false
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_VECTOR2I, TYPE_VECTOR3I:
			return true
		TYPE_FLOAT:
			return is_finite(float(v))
		TYPE_STRING, TYPE_STRING_NAME:
			return String(v).length() <= 256
		TYPE_VECTOR2:
			var q: Vector2 = v
			return is_finite(q.x) and is_finite(q.y)
		TYPE_VECTOR3:
			var p: Vector3 = v
			return is_finite(p.x) and is_finite(p.y) and is_finite(p.z)
		TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_STRING_ARRAY:
			return true
		TYPE_ARRAY:
			for x: Variant in (v as Array):
				if not valor_limpo(x, fundo + 1):
					return false
			return true
		TYPE_DICTIONARY:
			var d: Dictionary = v
			for k: Variant in d:
				var tk := typeof(k)
				if tk != TYPE_STRING and tk != TYPE_STRING_NAME and tk != TYPE_INT:
					return false
				if not valor_limpo(d[k], fundo + 1):
					return false
			return true
	return false


static func _copia(v: Variant) -> Variant:
	if v is Dictionary:
		return (v as Dictionary).duplicate(true)
	if v is Array:
		return (v as Array).duplicate(true)
	return v
