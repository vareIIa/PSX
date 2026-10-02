## Autoload. Fala roteirizada com escolha, para cena de missao.
##
## Por que nao e a Conversa nem o Dialogo
## --------------------------------------
## A Conversa puxa assunto de um desconhecido gerado pelo registro civil; o
## Dialogo e uma fila de falas sem escolha. Uma cena de missao precisa das duas
## coisas com texto escrito a mao, e precisa que a escolha volte para quem
## chamou (o roteiro) em vez de virar consequencia dentro da propria caixa.
##
## O visual e o mesmo papel colado do Dialogo. A lista de opcoes e a mesma folha
## presa acima da Conversa.
##
## Uso, de dentro de uma funcao com await:
##
##     await Escolha.falar("BERG", ["Eu te vi na praca.", "No chao."], berg)
##     var r: StringName = await Escolha.perguntar("BERG", "Vai entrar ou nao?", [
##         {"chave": &"aceitar", "titulo": "Entrar no carro", "borboleta": &"m1_aceitou_carona_berg", "valor": true},
##         {"chave": &"recusar", "titulo": "Nao, valeu", "borboleta": &"m1_aceitou_carona_berg", "valor": false},
##     ], berg)
##
## Opcao: {chave: StringName, titulo: String, borboleta?: StringName, valor?: Variant}.
## Opcao com `borboleta` grava `Borboleta.marcar(borboleta, valor)` e mostra o
## olho. Sem `borboleta`, e so conversa.
##
## Funciona dentro e fora de cena cortada (autoload Cinema). Fora, trava o jogador como o Dialogo.
##
## STUB da branch missao1/base: fala vai para o log e a pergunta devolve a
## primeira opcao. A tarefa A implementa a caixa.
extends CanvasLayer

signal abriu()
signal fechou()
## Uma opcao foi escolhida. Emitido antes de `perguntar` retornar.
signal escolhido(chave: StringName)

var ativo: bool = false


func _ready() -> void:
	layer = 121


## Mostra as linhas uma a uma, avancando na tecla de interagir. `quem`, quando
## dado, recebe `falar(true/false)` para mexer a boca e a cabeca.
func falar(nome: String, linhas: Array[String], quem: Node3D = null) -> void:
	for l: String in linhas:
		print("[%s] %s" % [nome, l])
	if quem != null and quem.has_method("falar"):
		quem.call("falar", false)
	await get_tree().process_frame


## Mostra a pergunta e a lista. Devolve a `chave` escolhida.
func perguntar(nome: String, pergunta: String, opcoes: Array[Dictionary],
		quem: Node3D = null) -> StringName:
	print("[%s] %s" % [nome, pergunta])
	await get_tree().process_frame
	if opcoes.is_empty():
		return &""
	var o := opcoes[0]
	if o.has("borboleta"):
		Borboleta.marcar(StringName(o["borboleta"]), o.get("valor", true))
	var chave := StringName(o["chave"])
	escolhido.emit(chave)
	if quem != null and quem.has_method("falar"):
		quem.call("falar", false)
	return chave
