## O balcao do bar: o que se pede a quem atende, a cobranca e o servico.
##
## Irma da `VendaDaLoja` (o balcao das lojas), e separada dela pelo mesmo motivo:
## mexe em autoload — Dinheiro, Inventario, Conversa — e so a conversa
## (`FalasNpc`, contexto `&"bar"`) chama daqui.
##
## Pedir nao poe nada na mochila. O pedido vai para a `VidaDoBar` do bar, e
## quem atende SERVE: vira para o freezer, a prateleira ou a estufa, volta e
## pousa a garrafa, a dose ou o pires na formica, na frente de quem pediu. E ali
## que o jogador pega ([E]). Sem a `VidaDoBar` (chamada fora do bar), o item vai
## direto para a mochila, como na loja.
class_name VendaDoBar
extends RefCounted

const TITULO_SOBRE := "O QUE TEM HOJE?"
const TITULO_FIADO := "PENDURA NA CONTA?"

## O cardapio, na ordem da conversa. Preco em reais inteiros, como a loja (1998:
## a 600 no boteco a um real e pouco, a dose a menos de um).
const CARDAPIO: Array[Dictionary] = [
	{"id": &"cerveja", "titulo": "UMA CERVEJA", "preco": 2, "de": &"freezer"},
	{"id": &"pinga", "titulo": "UMA PINGA", "preco": 1, "de": &"prateleira"},
	{"id": &"coxinha", "titulo": "UMA COXINHA", "preco": 2, "de": &"estufa"},
	{"id": &"torresmo", "titulo": "UM TORRESMO", "preco": 3, "de": &"estufa"},
	{"id": &"guarana", "titulo": "UM GUARANA", "preco": 1, "de": &"freezer"},
]

## O que o bar diz de si, pelo tom de quem atende (FalasNpc.aspereza).
const SOBRE := {
	"aspero": ["Cerveja, pinga e o que ta na estufa. Cozinha fechou.",
		"Sinuca e ali no fundo. Taco quebrado paga."],
	"neutro": ["Cerveja trincando. Coxinha saiu agora, e o torresmo e da manha.",
		"O jogo ta passando ali na TV, se quiser assistir."],
	"gentil": ["Chegou na hora boa! A cerveja ta estupidamente gelada.",
		"Senta ai, pede um torresmo, que hoje ta caprichado.",
		"E a sinuca ta livre, se voce for bom de taco."],
}

## Resposta de quem atende ao pedido, pelo tom. `%s` e o preco.
const SERVE := {
	"aspero": ["%s. Ja sai."],
	"neutro": ["Pode deixar. %s."],
	"gentil": ["E pra ja! Vou pegar a mais gelada pra voce."],
}

const FIADO := {
	"aspero": ["Ta vendo a placa ali? Fiado so amanha."],
	"neutro": ["Fiado? Ha ha. Le a placa ali, meu filho."],
	"gentil": ["Ai nao da, ne... A placa ta ali, fiado so amanha.",
		"Mas amanha pode, viu?"],
}


static func opcoes(ficha: Dictionary) -> Array[Dictionary]:
	var id := int(ficha["id"])
	var saida: Array[Dictionary] = []
	saida.append({"chave": &"bar_sobre", "titulo": TITULO_SOBRE,
		"visto": FalasNpc.ja_falou(id, &"bar_sobre")})
	for c: Dictionary in CARDAPIO:
		saida.append({"chave": StringName("bar_pedir_" + String(c["id"])),
			"titulo": "%s (%s)" % [c["titulo"], Dinheiro.formatar(int(c["preco"]))],
			"visto": false})
	saida.append({"chave": &"bar_fiado", "titulo": TITULO_FIADO,
		"visto": FalasNpc.ja_falou(id, &"bar_fiado")})
	var p := Personalidade.de(int(ficha["personalidade"]))
	var proprio: Dictionary = p["proprio"]
	saida.append({"chave": &"proprio", "titulo": FalasNpc.costurar(String(proprio["titulo"]), ficha),
		"visto": FalasNpc.ja_falou(id, &"proprio")})
	saida.append({"chave": &"sair", "titulo": FalasNpc.TITULO_SAIR, "visto": false})
	saida.append({"chave": &"documento", "titulo": FalasNpc.TITULO_DOCUMENTO,
		"visto": FalasNpc.ja_falou(id, &"documento")})
	return saida


static func _tom(ficha: Dictionary) -> String:
	var a := FalasNpc.aspereza(Personalidade.de(int(ficha["personalidade"])))
	return "aspero" if a > 0.6 else ("gentil" if a < 0.35 else "neutro")


static func _costurar(linhas: Array, ficha: Dictionary) -> Array[String]:
	var saida: Array[String] = []
	for l: String in linhas:
		saida.append(FalasNpc.costurar(l, ficha))
	return saida


static func responder(ficha: Dictionary, chave: StringName) -> Array[String]:
	var tom := _tom(ficha)
	if chave == &"bar_sobre":
		return _costurar(SOBRE[tom], ficha)
	if chave == &"bar_fiado":
		return _costurar(FIADO[tom], ficha)
	var texto := String(chave)
	if texto.begins_with("bar_pedir_"):
		return _pedir(StringName(texto.trim_prefix("bar_pedir_")), ficha)
	return ["Hm."]


static func item(id: StringName) -> Dictionary:
	for c: Dictionary in CARDAPIO:
		if c["id"] == id:
			return c
	return {}


static func _pedir(id: StringName, ficha: Dictionary) -> Array[String]:
	var c := item(id)
	if c.is_empty():
		return ["Isso acabou."]
	var preco := int(c["preco"])
	if Dinheiro.saldo() < preco:
		return ["Da %s. Voce ta sem, ne?" % Dinheiro.formatar(preco),
			"Fiado so amanha, ta na placa."]
	var nome := String(c["titulo"]).get_slice(" ", 1)
	if not Dinheiro.pagar(preco, nome):
		return ["Da %s." % Dinheiro.formatar(preco)]
	var vida := _vida_de(Conversa.quem())
	if vida != null:
		vida.pedir(id)
	else:
		# Fora do bar (ninguem para servir): direto para a mochila, com a sobra
		# devolvida em dinheiro, como na loja.
		var sobra := Inventario.adicionar(id)
		if sobra > 0:
			Dinheiro.receber(preco * sobra, "DEVOLVIDO")
			return ["Nao cabe mais nada nessa mochila.", "Esvazia ela e volta."]
	var linhas: Array = SERVE[_tom(ficha)]
	var saida: Array[String] = []
	for l: String in linhas:
		saida.append(l % Dinheiro.formatar(preco) if l.contains("%s") else l)
	return saida


## A `VidaDoBar` de quem esta atendendo: ela se anota no atendente quando o acha.
static func _vida_de(quem: Node) -> VidaDoBar:
	if quem == null or not is_instance_valid(quem) or not quem.has_meta(&"vida_do_bar"):
		return null
	var v: Object = quem.get_meta(&"vida_do_bar")
	return v as VidaDoBar if is_instance_valid(v) else null
