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
	{
		"chave": &"entregador",
		"titulo": "ENTREGADOR",
		"resumo": "Pega pedido no iWeed, leva ate o cliente e volta com o dinheiro.",
		"aceita": [
			"Entrega? Fechou. Me passa o endereco no aplicativo.",
			"Moto eu nao tenho, mas perna tenho de sobra.",
		],
		"recusa": "Andar com isso no bolso pela cidade? Nem pensar.",
		"demite": "Beleza. Devolvo a mochila amanha.",
	},
]

## Quantas funcoes uma pessoa acumula. Duas: Jota e Helmer plantam e entregam,
## e o jogador pode fazer o mesmo com quem contratar. Tres seria um faz-tudo, e
## faz-tudo nao e escolha.
const MAX_FUNCOES := 2

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


## A primeira funcao desta pessoa. Vazio e a resposta para quase todo mundo na
## cidade. Quem precisa de todas pergunta a `funcoes`.
static func de(id: int) -> StringName:
	var f := funcoes(id)
	return f[0] if not f.is_empty() else &""


## Tudo o que esta pessoa faz para o jogador, na ordem da contratacao.
##
## Guardado em `funcoes`; a chave antiga `profissao` continua sendo a primeira,
## para um save de antes da segunda funcao abrir com a folha certa.
static func funcoes(id: int) -> Array[StringName]:
	var saida: Array[StringName] = []
	var bruto: Variant = WorldState.obter(_coord(id), &"funcoes", null)
	if bruto is Array:
		for v: Variant in bruto:
			if String(v) != "":
				saida.append(StringName(String(v)))
		return saida
	var velho := StringName(WorldState.obter(_coord(id), &"profissao", &""))
	if velho != &"":
		saida.append(velho)
	return saida


## Os titulos das funcoes, para quem desenha: "FAZENDEIRO", "ENTREGADOR".
static func titulos(id: int) -> PackedStringArray:
	var saida := PackedStringArray()
	for chave: StringName in funcoes(id):
		saida.append(String(definicao(chave).get("titulo", String(chave).to_upper())))
	return saida


static func e(id: int, chave: StringName) -> bool:
	return funcoes(id).has(chave)


static func _gravar_funcoes(id: int, lista: Array[StringName]) -> void:
	var bruto: Array = []
	for f: StringName in lista:
		bruto.append(String(f))
	WorldState.definir(_coord(id), &"funcoes", bruto)
	WorldState.definir(_coord(id), &"profissao", lista[0] if not lista.is_empty() else &"")


## Contrata. Devolve falso para quem ja faz isso ou ja acumula MAX_FUNCOES.
static func contratar(id: int, chave: StringName) -> bool:
	if definicao(chave).is_empty():
		return false
	var atuais := funcoes(id)
	if atuais.has(chave) or atuais.size() >= MAX_FUNCOES:
		return false
	atuais.append(chave)
	_gravar_funcoes(id, atuais)
	var lista := empregados(chave)
	if not lista.has(id):
		lista.append(id)
		WorldState.definir(FOLHA, chave, lista)
	return true


## Dispensa de uma funcao, ou de todas quando `chave` vem vazia.
static func demitir(id: int, chave: StringName = &"") -> bool:
	var atuais := funcoes(id)
	if atuais.is_empty() or (chave != &"" and not atuais.has(chave)):
		return false
	var saem: Array[StringName] = []
	if chave == &"":
		saem.assign(atuais)
	else:
		saem.append(chave)
	for f: StringName in saem:
		atuais.erase(f)
		var lista := empregados(f)
		lista.erase(id)
		WorldState.definir(FOLHA, f, lista)
	_gravar_funcoes(id, atuais)
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
	var atuais := funcoes(id)
	for d: Dictionary in LISTA:
		var chave := StringName(d["chave"])
		if atuais.has(chave):
			saida.append({
				"chave": StringName("demitir_%s" % chave),
				"titulo": "%s (%s)" % [TITULO_DEMITIR, String(d["titulo"])],
				"visto": true,
			})
			continue
		saida.append({
			"chave": StringName("contratar_%s" % chave),
			"titulo": String(d["titulo"]),
			"visto": not atuais.is_empty(),
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
		demitir(id, qual)
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
