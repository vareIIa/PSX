## Os bares da cidade para o mapa, o radar e o GPS: o do Seu Ze (ponto de
## interesse de sempre) e os da BarVivo que ja foram montados perto do jogador.
##
## Por que nao entram em `ChunkBuilder.pontos_de_interesse`
## -------------------------------------------------------
## Aquela funcao e pura: le a coordenada e devolve os pontos sem construir nada,
## e a rede conta com isso (o dedicado e o cliente enxergam o mesmo). O lote do
## bar da BarVivo sai do sorteio da fileira (`repartir`, com o rng do chunk
## gasto pelo que veio antes): nao ha conta que diga onde ele fica sem montar o
## chunk. Fixar o bar no comeco da face, como o Seu Ze, mudaria um em quatro
## quarteiroes comerciais da cidade (memoria "rng do chunk arrasta o resto").
##
## Entao o bar se anuncia quando o chunk dele e montado (o prop `ponto_bar`, de
## KitBar.salao), e o mapa mostra o que o jogador ja passou perto — o mesmo
## contrato da nevoa do mapa, que so revela o percorrido.
class_name BaresDaCidade
extends RefCounted

static var _por_chunk: Dictionary = {}
static var _trava := Mutex.new()


## O prop `ponto_bar` de um chunk montado: {"pos" (local do chunk, ja no chao
## da ladeira), "giro", "nome"}.
static func registrar(coord: Vector2i, prop: Dictionary) -> void:
	var ponto := {"tipo": &"bar", "pos": prop["pos"], "giro": float(prop.get("giro", 0.0)),
		"nome": String(prop.get("nome", "BAR")), "interior": &"bar"}
	_trava.lock()
	_por_chunk[coord] = [ponto]
	_trava.unlock()


static func do_chunk(cx: int, cz: int) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	_trava.lock()
	var lista: Array = _por_chunk.get(Vector2i(cx, cz), [])
	for p: Dictionary in lista:
		saida.append(p.duplicate())
	_trava.unlock()
	return saida


## Os pontos de interesse do chunk mais os bares ja vistos nele. E o que o mapa,
## o radar e o GPS leem.
static func pontos(cx: int, cz: int) -> Array[Dictionary]:
	var saida := ChunkBuilder.pontos_de_interesse(cx, cz)
	saida.append_array(do_chunk(cx, cz))
	return saida


static func quantos() -> int:
	_trava.lock()
	var n := _por_chunk.size()
	_trava.unlock()
	return n
