## O estado do mundo que o servidor manda uma vez, a quem entra (plano 04 caixa E
## e secao 5.1): `[WorldState.para_dicionario(), visitados]` em var_to_bytes,
## comprimido com zstd e cortado em pedacos de 16 KB para o canal 2.
##
## Canal proprio porque o canal confiavel do ENet e ordenado: 40 KB no canal 0
## travariam o chat e todo evento atras deles ate o ultimo pedaco chegar.
##
## Formato: u32 little-endian com o tamanho do bruto, seguido do zstd. O tamanho
## vai na frente porque o decompress do Godot precisa dele, e porque e o que deixa
## recusar uma bomba de descompressao antes de alocar.
##
## Quem chama tira da carga o que e POR JOGADOR antes de empacotar: o Dinheiro e o
## IWeed moram no WorldState, em (-8, 424243) e (-9, 424243) (plano 04 secao 3.1).
class_name CargaDeMundo
extends RefCounted

const PEDACO := 16384
## 8 MB comprimidos. Uma hora de jogo da poucos KB; isto e trava contra lixo.
const TETO_PARTES := 512
const TETO_BRUTO := 32 * 1024 * 1024

## Os quatro primeiros bytes de todo quadro zstd. Conferir antes de descomprimir
## poupa o log de um "Decompression failed." a cada lixo que chegar.
const _MAGICO_ZSTD := [0x28, 0xB5, 0x2F, 0xFD]


## As partes, na ordem. [] se passar dos tetos: o cliente recusaria de qualquer
## jeito, e e melhor o servidor saber na hora de mandar.
static func empacotar(mundo: Dictionary, visitados: PackedStringArray) -> Array[PackedByteArray]:
	var partes: Array[PackedByteArray] = []
	var bruto := var_to_bytes([mundo, visitados])
	if bruto.size() > TETO_BRUTO:
		push_warning("CargaDeMundo: mundo de %d bytes passa do teto" % bruto.size())
		return partes
	var buf := PackedByteArray()
	buf.resize(4)
	buf.encode_u32(0, bruto.size())
	buf.append_array(bruto.compress(FileAccess.COMPRESSION_ZSTD))
	var i := 0
	while i < buf.size():
		partes.append(buf.slice(i, i + PEDACO))
		i += PEDACO
	if partes.size() > TETO_PARTES:
		push_warning("CargaDeMundo: %d partes passam do teto" % partes.size())
		partes.clear()
	return partes


## [mundo: Dictionary, visitados: PackedStringArray], ou [] se qualquer coisa
## nao prestar. Nunca quebra com lixo: os bytes vem de outra maquina.
static func desempacotar(partes: Array) -> Array:
	var buf := PackedByteArray()
	for p: Variant in partes:
		if typeof(p) != TYPE_PACKED_BYTE_ARRAY:
			return []
		buf.append_array(p)
		if buf.size() > TETO_PARTES * PEDACO:
			return []
	if buf.size() < 4 + _MAGICO_ZSTD.size():
		return []
	var tam := buf.decode_u32(0)
	if tam < 1 or tam > TETO_BRUTO:
		return []
	for i in _MAGICO_ZSTD.size():
		if buf[4 + i] != int(_MAGICO_ZSTD[i]):
			return []
	var bruto := buf.slice(4).decompress(tam, FileAccess.COMPRESSION_ZSTD)
	# Abaixo de 4 bytes o bytes_to_var escreve ERROR no log; e nada valido cabe.
	if bruto.size() != tam or bruto.size() < 4:
		return []
	# Sem objetos: quem manda bytes nao instancia nada deste lado.
	var v: Variant = bytes_to_var(bruto)
	if typeof(v) != TYPE_ARRAY:
		return []
	var a: Array = v
	if a.size() != 2 or typeof(a[0]) != TYPE_DICTIONARY or typeof(a[1]) != TYPE_PACKED_STRING_ARRAY:
		return []
	var mundo: Dictionary = a[0]
	for k: Variant in mundo:
		if typeof(k) != TYPE_STRING or not _coord_em_texto(k):
			return []
		if typeof(mundo[k]) != TYPE_DICTIONARY:
			return []
		# StringName no mundo vivo, String no que veio de save (JSON). Outro tipo
		# para o `StringName(chave)` de quem aplica a carga com erro de script.
		for chave: Variant in (mundo[k] as Dictionary):
			if typeof(chave) != TYPE_STRING_NAME and typeof(chave) != TYPE_STRING:
				return []
	return [mundo, a[1]]


## "cx,cz" com dois inteiros, como `WorldState.para_dicionario` escreve.
static func _coord_em_texto(s: String) -> bool:
	var partes := s.split(",")
	return partes.size() == 2 and partes[0].is_valid_int() and partes[1].is_valid_int()


## Junta as partes de uma carga, na ordem que chegarem. Carga nova (outro rev ou
## outro total) substitui a velha. Quem chama zera depois de usar.
class Montagem:
	extends RefCounted

	var rev := -1
	var total := 0
	var bytes := 0
	var _partes: Dictionary = {}

	## Verdadeiro quando a carga esta completa. Parte fora das regras cai sem
	## mexer no que ja chegou.
	func receber(nova_rev: int, parte: int, novo_total: int, dados: PackedByteArray) -> bool:
		if novo_total < 1 or novo_total > TETO_PARTES or parte < 0 or parte >= novo_total:
			return false
		if dados.is_empty() or dados.size() > PEDACO:
			return false
		if nova_rev != rev or novo_total != total:
			zerar()
			rev = nova_rev
			total = novo_total
		if not _partes.has(parte):
			_partes[parte] = dados
			bytes += dados.size()
		return completa()

	func completa() -> bool:
		return total > 0 and _partes.size() == total

	## As partes em ordem, ou [] se ainda falta alguma.
	func partes() -> Array[PackedByteArray]:
		var saida: Array[PackedByteArray] = []
		if not completa():
			return saida
		for i in total:
			saida.append(_partes[i])
		return saida

	func zerar() -> void:
		rev = -1
		total = 0
		bytes = 0
		_partes.clear()
