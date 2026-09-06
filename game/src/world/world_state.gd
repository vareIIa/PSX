## Autoload. Guarda o que mudou num chunk depois que ele foi descarregado.
##
## Chunk descarregado perde os nos, entao qualquer alteracao feita pelo jogador,
## como porta aberta ou item pego, tem que viver fora da cena. Sem isso o mundo
## se conserta sozinho quando o jogador da meia volta, que e o pior tipo de bug de
## streaming: ninguem reclama, so acha o jogo estranho.
extends Node

## coord do chunk -> { chave: valor }
var _por_chunk: Dictionary[Vector2i, Dictionary] = {}


func definir(coord: Vector2i, chave: StringName, valor: Variant) -> void:
	if not _por_chunk.has(coord):
		_por_chunk[coord] = {}
	_por_chunk[coord][chave] = valor


func obter(coord: Vector2i, chave: StringName, padrao: Variant = null) -> Variant:
	if not _por_chunk.has(coord):
		return padrao
	return _por_chunk[coord].get(chave, padrao)


func estado_do_chunk(coord: Vector2i) -> Dictionary:
	return _por_chunk.get(coord, {})


func tem_estado(coord: Vector2i) -> bool:
	return _por_chunk.has(coord)


## Numero de chunks com alteracao registrada. Serve para o overlay de debug.
func chunks_alterados() -> int:
	return _por_chunk.size()


func limpar() -> void:
	_por_chunk.clear()


## Serializa para o save. Vector2i nao sobrevive a JSON, entao vira string.
func para_dicionario() -> Dictionary:
	var saida: Dictionary = {}
	for coord: Vector2i in _por_chunk:
		saida["%d,%d" % [coord.x, coord.y]] = _por_chunk[coord]
	return saida


func de_dicionario(dados: Dictionary) -> void:
	_por_chunk.clear()
	for chave: String in dados:
		var partes := chave.split(",")
		if partes.size() != 2:
			push_warning("WorldState: chave de chunk invalida '%s'" % chave)
			continue
		_por_chunk[Vector2i(int(partes[0]), int(partes[1]))] = dados[chave]
