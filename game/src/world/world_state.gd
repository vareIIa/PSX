## Autoload. Guarda o que mudou num chunk depois que ele foi descarregado.
##
## Chunk descarregado perde os nos, entao qualquer alteracao feita pelo jogador,
## como porta aberta ou item pego, tem que viver fora da cena. Sem isso o mundo
## se conserta sozinho quando o jogador da meia volta, que e o pior tipo de bug de
## streaming: ninguem reclama, so acha o jogo estranho.
extends Node

## Faixa de coordenada reservada aos interiores, que nao tem chunk proprio. O
## eixo Z guarda esta marca e o X guarda a semente do interior. Nenhum chunk de
## rua chega perto: seria preciso andar treze milhoes de metros.
const INTERIOR := 424242

## Uma chave mudou. Sozinho ninguem precisa ouvir: quem escreve e o proprio no
## que mudou. Em rede a porta de uma maquina abre porque OUTRA maquina abriu, e o
## no vivo tem de reagir (MULTIPLAYER/PLANO/04, secao 4.5). `valor` nulo = a chave
## deixou de existir (o mundo inteiro foi trocado).
signal mudou(coord: Vector2i, chave: StringName, valor: Variant)

## coord do chunk -> { chave: valor }
var _por_chunk: Dictionary[Vector2i, Dictionary] = {}

## Chunks em que o jogador ja pos o pe. E o que o mapa revela.
##
## Mora aqui, e nao no ChunkManager, porque tem de sobreviver ao descarregamento
## e entrar no save: um mapa que esquece onde voce esteve ao dar meia volta e
## pior que nenhum mapa.
var _visitados: Dictionary[Vector2i, bool] = {}

## A hora do jogo. Mora aqui pelo mesmo motivo dos visitados: tem de sobreviver
## a troca de cena e entrar no save. Um relogio que volta para 22:43 toda vez que
## o jogador entra numa casa nao e relogio, e enfeite.
##
## A conta esta em `Relogio` e nao aqui porque assim da para medir sem abrir
## janela — `tests/checar_hud.gd` mede.
var relogio := Relogio.new()


func visitar(coord: Vector2i) -> void:
	_visitados[coord] = true


func visitado(coord: Vector2i) -> bool:
	return _visitados.has(coord)


func chunks_visitados() -> int:
	return _visitados.size()


## As coordenadas visitadas, para a rede juntar o mapa do grupo.
func coords_visitadas() -> Array[Vector2i]:
	return _visitados.keys()


## Em rede, quem decide o caminho de cada escrita (`MundoEmRede._ao_definir`):
## devolve verdadeiro se tomou conta dela (mandou ao servidor, ja com a previsao
## na tela). Sozinho fica vazio e `definir` e so gravar. Assim os sistemas do
## jogo escrevem igual nos dois modos (plano 13, item 3.4).
var rede := Callable()


func definir(coord: Vector2i, chave: StringName, valor: Variant) -> void:
	if rede.is_valid() and bool(rede.call(coord, chave, valor)):
		return
	definir_local(coord, chave, valor)


## Grava nesta maquina, sem perguntar a rede: o que chegou DELA, e o que so esta
## maquina recalcula (o crescimento do plantio pelo relogio).
func definir_local(coord: Vector2i, chave: StringName, valor: Variant) -> void:
	if not _por_chunk.has(coord):
		_por_chunk[coord] = {}
	_por_chunk[coord][chave] = valor
	mudou.emit(coord, chave, valor)


## A chave volta a "nunca escrita" (a previsao negada de algo que nao existia).
func apagar_local(coord: Vector2i, chave: StringName) -> void:
	if not _por_chunk.has(coord):
		return
	_por_chunk[coord].erase(chave)
	if _por_chunk[coord].is_empty():
		_por_chunk.erase(coord)
	mudou.emit(coord, chave, null)


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
	_visitados.clear()
	relogio = Relogio.new()


## Serializa para o save. Vector2i nao sobrevive a JSON, entao vira string.
func para_dicionario() -> Dictionary:
	var saida: Dictionary = {}
	for coord: Vector2i in _por_chunk:
		saida["%d,%d" % [coord.x, coord.y]] = _por_chunk[coord]
	return saida


## Os visitados vao em lista separada no save. Enfia-los no dicionario por chunk
## faria toda esquina por onde o jogador passou virar um chunk "alterado", e o
## contador de alteracoes do overlay deixaria de significar o que significa.
func visitados_para_lista() -> PackedStringArray:
	var saida := PackedStringArray()
	for coord: Vector2i in _visitados:
		saida.append("%d,%d" % [coord.x, coord.y])
	return saida


func visitados_de_lista(lista: Array) -> void:
	_visitados.clear()
	for chave: String in lista:
		var partes := chave.split(",")
		if partes.size() == 2:
			_visitados[Vector2i(int(partes[0]), int(partes[1]))] = true


func de_dicionario(dados: Dictionary) -> void:
	_por_chunk.clear()
	for chave: String in dados:
		var partes := chave.split(",")
		if partes.size() != 2:
			push_warning("WorldState: chave de chunk invalida '%s'" % chave)
			continue
		_por_chunk[Vector2i(int(partes[0]), int(partes[1]))] = dados[chave]
