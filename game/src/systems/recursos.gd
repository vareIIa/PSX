## Listagem de recursos que funciona no editor e no pacote exportado.
##
## Existe por causa de uma diferenca que so aparece depois de exportar, que e o
## pior momento possivel para descobrir qualquer coisa. No projeto aberto,
## `DirAccess.get_files()` devolve `item.tres`. No PCK, o mesmo arquivo aparece
## como `item.tres.remap`, e textura e som aparecem com o sufixo `.import` ou ja
## convertidos. Um filtro por `ends_with(".tres")` acha tudo no editor e nada no
## jogo publicado, sem erro nenhum no meio do caminho: a lista simplesmente vem
## vazia e o inventario fica sem itens.
##
## Toda varredura de pasta em tempo de execucao passa por aqui.
class_name Recursos
extends RefCounted

## Sufixos que o motor acrescenta ao empacotar.
const SUFIXOS := [".remap", ".import"]


## Caminhos completos dos recursos com a extensao dada, dentro de `pasta`.
##
## `extensao` vai sem ponto, por exemplo "tres" ou "wav".
static func listar(pasta: String, extensao: String) -> PackedStringArray:
	var saida := PackedStringArray()
	var dir := DirAccess.open(pasta)
	if dir == null:
		push_error("Recursos: pasta ausente em %s" % pasta)
		return saida

	var alvo := "." + extensao.trim_prefix(".")
	var vistos := {}

	for arquivo: String in dir.get_files():
		var nome := arquivo
		for sufixo: String in SUFIXOS:
			if nome.ends_with(sufixo):
				nome = nome.trim_suffix(sufixo)
				break
		if not nome.ends_with(alvo) or vistos.has(nome):
			continue
		vistos[nome] = true
		saida.append(pasta.path_join(nome))

	saida.sort()
	return saida


## So os nomes, sem pasta nem extensao.
static func nomes(pasta: String, extensao: String) -> PackedStringArray:
	var saida := PackedStringArray()
	for caminho: String in listar(pasta, extensao):
		saida.append(caminho.get_file().get_basename())
	return saida
