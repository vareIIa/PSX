## O que uma pessoa da cidade faz para voce. A primeira profissao e FAZENDEIRO.
##
## Por que isto e um sistema e nao dois NPCs
## -----------------------------------------
## Helmer e Jota podiam ser dois bonecos com um roteiro colado neles: andam ate
## o vaso, abaixam, levantam. Ficaria igual na primeira visita e morto na
## segunda, porque o jogador descobre em dois minutos que aquilo nao responde a
## nada.
##
## O que faz a estufa continuar viva e a folha de pagamento ser DE VERDADE:
## Helmer e Jota estao nela desde o comeco, e o jogador pode por mais gente.
## Qualquer pessoa da rua — a mesma com ficha, CPF e mae no registro civil —
## aceita ser contratada, e na proxima vez que a porta dos fundos abrir ela esta
## la dentro, trabalhando com os dois. O sistema e o mesmo para os tres.
##
## Onde fica guardado
## ------------------
## Em duas metades, e cada uma responde uma pergunta diferente:
##
##   na pessoa   Vector2i(id, FalasNpc.PESSOA), chave `profissao`
##               responde "o que ESTE aqui faz?" — e o que a conversa precisa
##
##   na folha    FOLHA, chave por profissao, lista de ids
##               responde "quem trabalha para mim?" — e o que a estufa precisa
##               para saber quanta gente estava la enquanto o jogador nao estava
##
## Guardar so na pessoa obrigaria a varrer cem milhoes de ids para montar a
## lista. Guardar so na folha obrigaria a varrer a folha em toda conversa da
## cidade. As duas juntas custam uma escrita a mais na contratacao, que acontece
## uma vez por pessoa na partida inteira.
class_name Profissoes
extends RefCounted

## Faixa reservada do WorldState, vizinha da das pessoas (424243) e da dos
## interiores (424242). Ver FalasNpc.PESSOA.
const FOLHA := Vector2i(0, 424244)

## O catalogo. Uma entrada hoje; a proxima custa uma linha aqui e nada no resto
## do sistema — que e a razao de a lista existir em vez de um booleano
## `e_fazendeiro` espalhado por quatro arquivos.
##
## `pergunta` e o que o jogador ve na aba de servicos. `aceita` e a resposta na
## hora de fechar o trato, e ela e generica de proposito: quem responde e uma
## pessoa qualquer da rua, e a fala tem de servir para as doze personalidades.
const LISTA: Array[Dictionary] = [
	{
		"chave": &"fazendeiro",
		"titulo": "FAZENDEIRO",
		"resumo": "Cuida da plantacao: terra, semente, agua e colheita.",
		"aceita": [
			"Planta? Sei mexer com planta, sim.",
			"Me diz onde e que eu apareco.",
		],
		"recusa": "Ja tenho o que fazer, obrigado.",
		"demite": "Tudo bem. Foi bom enquanto durou.",
	},
]

const TITULO_SERVICOS := "CONTRATAR SERVICOS"
const TITULO_VOLTAR := "VOLTAR"
const TITULO_DEMITIR := "DISPENSAR"


static func _coord(id: int) -> Vector2i:
	return Vector2i(id, FalasNpc.PESSOA)


static func definicao(chave: StringName) -> Dictionary:
	for d: Dictionary in LISTA:
		if StringName(d["chave"]) == chave:
			return d
	return {}


## O que esta pessoa faz. Vazio e a resposta para quase todo mundo na cidade.
static func de(id: int) -> StringName:
	return StringName(WorldState.obter(_coord(id), &"profissao", &""))


static func e(id: int, chave: StringName) -> bool:
	return de(id) == chave


## Contrata. Devolve falso para quem ja esta contratado em outra coisa — uma
## pessoa tem um emprego, que e o que torna a escolha uma escolha.
static func contratar(id: int, chave: StringName) -> bool:
	if definicao(chave).is_empty():
		return false
	var atual := de(id)
	if atual == chave:
		return false
	if atual != &"":
		return false
	WorldState.definir(_coord(id), &"profissao", chave)
	var lista := empregados(chave)
	if not lista.has(id):
		lista.append(id)
		WorldState.definir(FOLHA, chave, lista)
	return true


static func demitir(id: int) -> bool:
	var atual := de(id)
	if atual == &"":
		return false
	WorldState.definir(_coord(id), &"profissao", &"")
	var lista := empregados(atual)
	lista.erase(id)
	WorldState.definir(FOLHA, atual, lista)
	return true


## Quem trabalha nisto, na ordem em que foi contratado.
##
## A ordem importa: e ela que decide quem aparece na estufa quando ha mais gente
## contratada do que lugar para trabalhar. Quem chegou primeiro fica.
static func empregados(chave: StringName) -> Array:
	var bruto: Variant = WorldState.obter(FOLHA, chave, null)
	var saida: Array = []
	if bruto is Array:
		# O save volta de JSON com tudo em float. Sem esta conversao, `has(id)`
		# nunca encontra ninguem depois de carregar uma partida e a folha de
		# pagamento inteira zera em silencio.
		for v: Variant in bruto:
			saida.append(int(v))
	return saida


static func quantos(chave: StringName) -> int:
	return empregados(chave).size()


## As opcoes da aba de servicos, para a `Conversa` montar a lista.
##
## Quem ja e empregado ve DISPENSAR no lugar do contrato: a mesma aba serve para
## as duas coisas, porque sao a mesma decisao vista de dois lados, e uma segunda
## aba so para demitir seria uma tela a mais para uma linha de texto.
static func opcoes(id: int) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var atual := de(id)
	for d: Dictionary in LISTA:
		var chave := StringName(d["chave"])
		if atual == chave:
			saida.append({
				"chave": StringName("demitir_%s" % chave),
				"titulo": "%s (%s)" % [TITULO_DEMITIR, String(d["titulo"])],
				"visto": true,
			})
			continue
		saida.append({
			"chave": StringName("contratar_%s" % chave),
			"titulo": String(d["titulo"]),
			"visto": atual != &"",
		})
	saida.append({"chave": &"voltar", "titulo": TITULO_VOLTAR, "visto": false})
	return saida


## Fecha (ou desfaz) o trato e devolve o que a pessoa diz. A `Conversa` so
## repassa o texto: quem sabe o que aconteceu com a folha e este arquivo.
static func responder(ficha: Dictionary, chave: StringName) -> Array[String]:
	var id := int(ficha["id"])
	if String(chave).begins_with("demitir_"):
		var qual := StringName(String(chave).trim_prefix("demitir_"))
		var d := definicao(qual)
		demitir(id)
		return [FalasNpc.costurar(String(d.get("demite", "Ta certo.")), ficha)]

	var alvo := StringName(String(chave).trim_prefix("contratar_"))
	var def := definicao(alvo)
	if def.is_empty():
		return ["Nao sei fazer isso."]
	if not contratar(id, alvo):
		return [FalasNpc.costurar(String(def["recusa"]), ficha)]
	var linhas: Array[String] = []
	for l: Variant in def["aceita"]:
		linhas.append(FalasNpc.costurar(String(l), ficha))
	return linhas
