## Nome de uma coisa do mundo que o gerador nao numerou: porta, gaveta, luz.
##
## Sai de onde o gerador a pos, em decimetros relativos a origem do chunk (plano
## 04 secao 3.3). Caminho de no e instance id nao servem: o Godot numera prop sem
## nome com um contador do processo, e `@Porta@37` aqui e `@Porta@112` la. Duas
## maquinas com a mesma VERSAO poem a mesma porta no mesmo decimetro.
##
## O que isto nao aguenta: o gerador mudar a posicao da porta. Mas ai e versao
## diferente, e a assinatura da cidade recusa na entrada.
class_name ChaveMundo
extends RefCounted

## Igual a `ChunkManager.TAM`. Repetido porque classe pura nao alcanca autoload.
const CHUNK := 32.0


## Chunk de rua que contem a posicao. Coordenada negativa arredonda para baixo:
## x = -0,1 esta no chunk -1, nao no 0. Posicao nao finita vira (0, 0); quem
## precisa distinguir usa `da_rua`, que devolve chave vazia.
static func coord_da_rua(pos: Vector3) -> Vector2i:
	if not _finita(pos):
		return Vector2i.ZERO
	return Vector2i(floori(pos.x / CHUNK), floori(pos.z / CHUNK))


static func origem_da_rua(coord: Vector2i) -> Vector3:
	return Vector3(coord.x * CHUNK, 0.0, coord.y * CHUNK)


## `local` e relativo a origem do chunk (ou do interior). &"" se nao for finito.
static func de_posicao(local: Vector3, prefixo: String = "porta") -> StringName:
	if not _finita(local):
		return &""
	return StringName("%s_%d_%d_%d" % [prefixo, roundi(local.x * 10.0),
		roundi(local.y * 10.0), roundi(local.z * 10.0)])


## [coord do chunk, chave] de uma coisa na rua, a partir da posicao global.
## [Vector2i.ZERO, &""] se a posicao nao for finita.
static func da_rua(pos_global: Vector3, prefixo: String = "porta") -> Array:
	if not _finita(pos_global):
		return [Vector2i.ZERO, &""]
	var coord := coord_da_rua(pos_global)
	return [coord, de_posicao(pos_global - origem_da_rua(coord), prefixo)]


static func _finita(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)
