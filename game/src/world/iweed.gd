## iWeed: o aplicativo de entregas da estufa, e o motor que roda por tras dele.
##
## O que ele e
## -----------
## A estufa produz; alguem tem de levar. Clientes de verdade da cidade — gente
## com ficha, CPF e mae no registro civil — pedem pelo aplicativo: o que querem,
## quanto, onde encontrar e entre que horas. O jogador aceita e vai, ou deixa o
## pedido para a equipe, e Jota e Helmer saem da estufa, andam ate o ponto,
## entregam e voltam com o dinheiro. O mesmo pedido, as duas maos.
##
## E o laco que faltava para a plantacao ter sentido: vaso -> prateleira ->
## pedido -> dinheiro. Quem planta e quem entrega sao as mesmas pessoas, pela
## mesma folha de pagamento (`Profissoes`), e o app mostra as duas coisas.
##
## Por que um relogio proprio
## --------------------------
## `Relogio` nao conta dias: da a volta na meia-noite. Agenda de entrega precisa
## de tempo que so anda para a frente, entao este no soma os segundos do relogio
## do jogo num contador absoluto, em minutos de jogo, gravado no WorldState. Um
## minuto de jogo sao 30 s reais (Relogio.RITMO = 2); todo prazo daqui esta em
## minutos de jogo.
##
## Onde fica guardado
## ------------------
## Tudo em WorldState, na faixa COORD, em tipos que sobrevivem ao JSON do save:
## numero, texto, lista e dicionario de texto. Nada de Vector3 (volta como texto)
## e todo inteiro lido passa por int() (volta como float).
class_name IWeed
extends Node

const COORD := Vector2i(-9, 424243)

## O cardapio. `unidade` e o preco de uma dose, sorteado na faixa; `qtd` a faixa
## de quantidade de um pedido.
const PRODUTOS := {
	"maconha": {"item": &"maconha", "nome": "MACONHA", "unidade": Vector2i(12, 18),
		"qtd": Vector2i(1, 4)},
	"super": {"item": &"super_maconha", "nome": "SUPER", "unidade": Vector2i(45, 70),
		"qtd": Vector2i(1, 2)},
}
## O que fica com quem entrega quando e a equipe. O resto cai no saldo.
const COMISSAO := 0.3

## Prazos, em minutos de jogo (x30 = segundos reais).
const INTERVALO := Vector2(3.0, 6.5)
const ANTECEDENCIA := Vector2(3.0, 6.0)
const JANELA := Vector2(7.0, 11.0)
const PRAZO_ACEITAR := 2.5
## Pedidos abertos ao mesmo tempo, somando caixa de entrada e agenda.
const MAX_ABERTOS := 4
const MAX_CLIENTES := 12
const CLIENTES_INICIAIS := 3
## Distancia do ponto de encontro ate onde o jogador esta quando o pedido nasce.
const RAIO := Vector2(40.0, 190.0)
## Passo da equipe na conta de viagem, em m/s.
const PASSO_EQUIPE := 1.35
## O cliente do jogador aparece no ponto a esta distancia e some a SOME.
const APARECE := 80.0
const SOME := 125.0
## A cena da equipe so e encenada com o jogador perto; longe, resolve na conta.
const ENCENA := 55.0
## Quanto tempo a Super pronta espera o jogador antes de a dupla colher.
const SUPER_ESPERA := 12.0

## Peso de cada tipo de lugar no sorteio do ponto de encontro. Orelhao primeiro:
## e o ponto de encontro de 1998.
const LUGARES := {
	&"telefone": 3.0, &"bar": 2.2, &"parque": 2.0, &"mercado": 1.2,
	&"apartamento": 1.0, &"casa": 0.35,
}
const NOMES_LUGAR := {
	&"telefone": "ORELHAO", &"bar": "BAR", &"parque": "PRACA",
	&"mercado": "MERCADINHO", &"apartamento": "PORTARIA", &"casa": "PORTAO",
}

## A loja do app: onde o dinheiro vira coisa. `precos` tem um valor por nivel;
## `item` vai para o inventario, o resto e melhoria da estufa ou da equipe.
const LOJA: Array[Dictionary] = [
	{"id": "semente", "nome": "SEMENTES (4)", "desc": "Vao pro seu bolso. Planta nos vasos vazios.",
		"precos": [20], "item": &"semente_maconha", "qtd": 4},
	{"id": "terra", "nome": "SACO DE TERRA (4)", "desc": "Quatro vasos de terra boa.",
		"precos": [15], "item": &"terra", "qtd": 4},
	{"id": "regador", "nome": "REGADOR", "desc": "Para regar voce mesmo.",
		"precos": [25], "item": &"regador", "qtd": 1},
	{"id": "lampada", "nome": "LAMPADA DE CULTIVO", "desc": "A estufa cresce 25% mais rapido por nivel.",
		"precos": [120, 240, 400]},
	{"id": "irrigacao", "nome": "IRRIGACAO", "desc": "A agua dura o dobro nos vasos.",
		"precos": [300]},
	{"id": "bicicleta", "nome": "BICICLETA DA EQUIPE", "desc": "Jota e Helmer entregam na metade do tempo.",
		"precos": [350]},
	{"id": "luz_roxa", "nome": "LUZ ROXA DO ANDAR 10", "desc": "A Super volta em 20 minutos, nao 30.",
		"precos": [500]},
	{"id": "propaganda", "nome": "PROPAGANDA NO BAIRRO", "desc": "Um cliente novo na hora.",
		"precos": [80], "repete": true},
]

## Lugar feminino leva "a"/"na"; o resto, "ao"/"no". INDO AO PORTARIA doia.
const LUGAR_FEMININO := ["PORTARIA", "PRACA"]

const VERDE := Color("6fe39a")
const ALERTA := Color("ff8a5c")
const OURO := Color("f2d46b")
## Mensagem de cliente na notificacao: azul de balao de conversa.
const AZUL := Color("8fcaff")

## O que o cliente escreve ao pedir. %d quantidade, %s produto, %s preco.
const PEDIDO_TEXTOS := [
	"Oi! Tem %d de %s? Pago %s.",
	"Fala. Preciso de %d %s pra hoje. %s, pode ser?",
	"Boa noite. Me ve %d de %s? Tenho %s aqui.",
	"E ai, sumido. %d %s, %s. Fechou?",
]

## O que acabou de acontecer, para o HUD mostrar como notificacao do aparelho.
signal notificacao(titulo: String, texto: String, cor: Color)
signal mudou()

## Para rotinas de teste que medem a estufa parada. O relogio continua contando.
static var pausado := false

var _rng := RandomNumberGenerator.new()
var _abs := -1.0
var _abs_gravado := -1.0
var _visto_s := -1.0
var _tique := 0.0
var _ultimo_fora := Vector3.INF
var _clientes_no_mundo: Dictionary = {}
var _em_cena: Dictionary = {}
## Pontos de encontro ja lidos, por chunk: [[categoria, mundo], ...]. Ler os
## ~170 chunks do raio de uma vez custava 9 ms num quadro so — um engasgo a
## cada pedido. Agora sao tres chunks por quadro, do mais perto para o mais
## longe, e o sorteio so consulta o que ja foi lido.
var _pontos: Dictionary = {}
var _anel: Array[Vector2i] = []


func _ready() -> void:
	add_to_group(&"iweed")
	_rng.randomize()
	# A blitz no caminho mora aqui dentro: so existe onde existe iWeed.
	add_child(BlitzNoCaminho.new())


static func instancia() -> IWeed:
	var arvore := Engine.get_main_loop() as SceneTree
	if arvore == null:
		return null
	return arvore.get_first_node_in_group(&"iweed") as IWeed


# --- estado -------------------------------------------------------------------

static func _ler(chave: StringName, padrao: Variant) -> Variant:
	return WorldState.obter(COORD, chave, padrao)


static func _gravar(chave: StringName, valor: Variant) -> void:
	WorldState.definir(COORD, chave, valor)


## Minutos de jogo desde que o iWeed comecou a contar. So anda para a frente.
static func agora() -> float:
	var i := instancia()
	if i != null and i._abs >= 0.0:
		return i._abs
	return float(_ler(&"abs", 0.0))


static func ativo() -> bool:
	return bool(_ler(&"ativo", false))


## Se o jogador esta recebendo pedidos. Desligado, tudo vai direto para a equipe.
static func online() -> bool:
	return bool(_ler(&"online", false))


static func definir_online(ligado: bool) -> void:
	_gravar(&"online", ligado)
	var i := instancia()
	if i != null:
		if ligado and float(_ler(&"proximo", 0.0)) > agora() + 1.5:
			# Ficar online chama o proximo pedido para logo: quem abriu o app para
			# trabalhar nao quer esperar seis minutos de jogo.
			_gravar(&"proximo", agora() + 1.0)
		i.mudou.emit()


static func pedidos() -> Array:
	var bruto: Variant = _ler(&"pedidos", [])
	return bruto if bruto is Array else []


static func pedido(n: int) -> Dictionary:
	for p: Dictionary in pedidos():
		if int(p["n"]) == n:
			return p
	return {}


static func de_estado(estados: Array) -> Array:
	var saida: Array = []
	for p: Dictionary in pedidos():
		if estados.has(String(p["estado"])):
			saida.append(p)
	return saida


## Caixa de entrada: pedidos esperando alguem aceitar.
static func abertos() -> Array:
	return de_estado(["novo"])


## Agenda: aceitos e a caminho, do mais cedo para o mais tarde.
static func agenda() -> Array:
	var lista := de_estado(["aceito", "a_caminho"])
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["inicio"]) < float(b["inicio"]))
	return lista


## Encerrados, do mais recente para o mais antigo.
static func historico() -> Array:
	var lista := de_estado(["entregue", "atrasado", "falhou", "expirado", "recusado"])
	lista.reverse()
	return lista


static func clientes() -> Array:
	var bruto: Variant = _ler(&"clientes", [])
	return bruto if bruto is Array else []


static func cliente(id: int) -> Dictionary:
	for c: Dictionary in clientes():
		if int(c["id"]) == id:
			return c
	return {}


## Quem entrega pelo app: a folha de entregadores, dupla primeiro.
static func equipe() -> Array[int]:
	var saida: Array[int] = []
	for id: Variant in Profissoes.empregados(&"entregador"):
		saida.append(int(id))
	return saida


## "JOTA", "HELMER" ou o primeiro nome de quem foi contratado.
static func apelido(id: int) -> String:
	var papel := RegistroCivil.personagem_de(id)
	if papel != &"":
		return String(papel).to_upper()
	return String(RegistroCivil.identidade(id).get("primeiro", "?"))


## "MARLENE S." — cabe numa linha de celular e ainda e alguem.
static func nome_curto(id: int) -> String:
	var f := RegistroCivil.identidade(id)
	var sobrenome := String(f.get("sobrenome", ""))
	var inicial := (sobrenome.substr(sobrenome.rfind(" ") + 1, 1) + ".") \
		if not sobrenome.is_empty() else ""
	return ("%s %s" % [String(f.get("primeiro", "?")), inicial]).strip_edges()


## "no" ou "na", pelo genero do lugar.
static func no_lugar(lugar: String) -> String:
	return "na" if LUGAR_FEMININO.has(lugar) else "no"


static func nome_do_produto(produto: String) -> String:
	return String(PRODUTOS.get(produto, {}).get("nome", produto.to_upper()))


static func hora(minuto_abs: float) -> String:
	# O minuto absoluto nao sabe que horas sao; o relogio do jogo sabe, e a
	# diferenca entre os dois e so o tempo que falta.
	var falta := minuto_abs - agora()
	var m := posmod(WorldState.relogio.minutos() + int(roundf(falta)), 1440)
	return "%02d:%02d" % [m / 60, m % 60]


## Quanto falta, legivel: "4 MIN", "40 S".
static func falta(minuto_abs: float) -> String:
	var min_jogo := minuto_abs - agora()
	if min_jogo <= 0.0:
		return "AGORA"
	var s_reais := min_jogo * 60.0 / Relogio.RITMO
	if s_reais < 60.0:
		return "%d S" % ceili(s_reais)
	return "%d MIN" % ceili(s_reais / 60.0)


# --- loja ---------------------------------------------------------------------

static func item_da_loja(id: String) -> Dictionary:
	for d: Dictionary in LOJA:
		if String(d["id"]) == id:
			return d
	return {}


static func nivel(id: String) -> int:
	return int(_ler(StringName("up_" + id), 0))


## Preco do proximo nivel, ou -1 quando ja esta no maximo.
static func preco(id: String) -> int:
	var d := item_da_loja(id)
	if d.is_empty():
		return -1
	var precos: Array = d["precos"]
	if d.has("item") or bool(d.get("repete", false)):
		return int(precos[0])
	var n := nivel(id)
	return int(precos[n]) if n < precos.size() else -1


## Compra. Devolve o que o app mostra: vazio e sucesso nao ha — sempre ha uma
## frase, e `ok` diz se deu.
static func comprar(id: String) -> Dictionary:
	var d := item_da_loja(id)
	var custo := preco(id)
	if d.is_empty() or custo < 0:
		return {"ok": false, "texto": "JA NO MAXIMO"}
	if Dinheiro.saldo() < custo:
		return {"ok": false, "texto": "SALDO INSUFICIENTE"}
	if d.has("item"):
		var sobra := Inventario.adicionar(d["item"], int(d["qtd"]))
		var entrou := int(d["qtd"]) - sobra
		if entrou <= 0:
			return {"ok": false, "texto": "SEM ESPACO NA MOCHILA"}
		# Paga so o que coube, proporcional: loja que cobra o que nao entregou
		# e golpe, e golpe o jogo ja tem o suficiente.
		custo = int(ceilf(float(custo) * float(entrou) / float(int(d["qtd"]))))
	elif id == "propaganda":
		var i := instancia()
		if i == null or clientes().size() >= MAX_CLIENTES:
			return {"ok": false, "texto": "CARTEIRA CHEIA"}
		var novo := i._novo_cliente()
		if novo < 0:
			return {"ok": false, "texto": "NINGUEM RESPONDEU"}
	else:
		_gravar(StringName("up_" + id), nivel(id) + 1)
	Dinheiro.pagar(custo, String(d["nome"]))
	aplicar_melhorias()
	var inst := instancia()
	if inst != null:
		inst.mudou.emit()
	return {"ok": true, "texto": "COMPRADO"}


## Passa as melhorias compradas para as regras que elas mudam.
static func aplicar_melhorias() -> void:
	Plantio.fator_crescimento = 1.0 + 0.25 * float(nivel("lampada"))
	Plantio.fator_agua = 2.0 if nivel("irrigacao") > 0 else 1.0


# --- estoque ------------------------------------------------------------------

## O que a equipe tem para entregar. A maconha e a prateleira da estufa, que os
## fazendeiros enchem colhendo; a Super e o que o jogador deixou com a dupla ou
## o que ela colheu la em cima.
static func estoque(produto: String) -> int:
	if produto == "super":
		return EntregasDaSuper.pendentes()
	var semente := int(_ler(&"estufa", 0))
	if semente == 0:
		return 0
	var e := Plantio.estado(semente, int(_ler(&"vasos", Plantio.POTES)))
	return int(e.get("colhido", 0))


static func _tirar_do_estoque(produto: String, n: int) -> bool:
	if estoque(produto) < n:
		return false
	if produto == "super":
		WorldState.definir(EntregasDaSuper.COORD, &"pendentes", EntregasDaSuper.pendentes() - n)
		return true
	var semente := int(_ler(&"estufa", 0))
	var e := Plantio.estado(semente, int(_ler(&"vasos", Plantio.POTES)))
	e["colhido"] = int(e.get("colhido", 0)) - n
	Plantio.gravar(semente, e)
	return true


## A estufa se apresenta ao iWeed quando e montada. A primeira vez liga o app:
## antes de o jogador conhecer a dupla nao ha quem planta nem quem entrega.
static func registrar_estufa(semente: int, vasos: int) -> void:
	if int(_ler(&"estufa", 0)) == 0:
		_gravar(&"estufa", semente)
		_gravar(&"vasos", vasos)
	var i := instancia()
	if i != null and i._ultimo_fora != Vector3.INF and _ler(&"base_x", null) == null:
		# A porta da casa: o ultimo lugar da rua antes de entrar. E dali que a
		# equipe sai, na conta de tempo de viagem.
		_gravar(&"base_x", i._ultimo_fora.x)
		_gravar(&"base_z", i._ultimo_fora.z)
	if not ativo():
		_gravar(&"ativo", true)
		# Dois minutos reais antes do primeiro pedido: a primeira visita e para
		# conhecer a dupla, e nao para ver Jota sair pela porta no primeiro olhar.
		_gravar(&"proximo", agora() + 4.0)


# --- equipe -------------------------------------------------------------------

## Se esta pessoa esta na rua com uma entrega agora.
static func fora_em_entrega(id: int) -> bool:
	var t := agora()
	for p: Dictionary in pedidos():
		if int(p.get("entregador", -1)) != id:
			continue
		var estado := String(p["estado"])
		if estado == "a_caminho":
			return true
		if (estado == "entregue" or estado == "atrasado" or estado == "falhou") 				and float(p.get("volta", 0.0)) > t:
			return true
	return false


## O que a pessoa da equipe esta fazendo, em uma linha, e se esta fora.
static func situacao(id: int) -> Dictionary:
	var t := agora()
	for p: Dictionary in pedidos():
		if int(p.get("entregador", -1)) != id:
			continue
		var estado := String(p["estado"])
		var lugar := String(p.get("lugar", ""))
		if estado == "a_caminho":
			var fem := LUGAR_FEMININO.has(lugar)
			if t < float(p["chega"]) - 0.4:
				return {"texto": "INDO %s %s" % ["A" if fem else "AO", lugar], "fora": true,
					"quando": "CHEGA %s" % hora(float(p["chega"])), "n": int(p["n"])}
			return {"texto": "ENTREGANDO %s %s" % ["NA" if fem else "NO", lugar], "fora": true, "quando": "",
				"n": int(p["n"])}
		if estado == "falhou" and float(p.get("volta", 0.0)) > t:
			return {"texto": "DETIDO NA BLITZ", "fora": true,
				"quando": "SOLTO %s" % hora(float(p["volta"])), "n": int(p["n"])}
		if (estado == "entregue" or estado == "atrasado") and float(p.get("volta", 0.0)) > t:
			return {"texto": "VOLTANDO PRA ESTUFA", "fora": true,
				"quando": "VOLTA %s" % hora(float(p["volta"])), "n": int(p["n"])}
	var no := _convidado_vivo(id)
	if no != null:
		var tarefa := no.descrever_tarefa()
		if not tarefa.is_empty():
			return {"texto": tarefa, "fora": false, "quando": "", "n": -1}
	if Profissoes.e(id, &"fazendeiro"):
		return {"texto": "CUIDANDO DA ESTUFA", "fora": false, "quando": "", "n": -1}
	return {"texto": "DISPONIVEL", "fora": false, "quando": "", "n": -1}


static func _convidado_vivo(id: int) -> Convidado:
	var arvore := Engine.get_main_loop() as SceneTree
	if arvore == null:
		return null
	for no: Node in arvore.get_nodes_in_group(&"convidado"):
		var c := no as Convidado
		if c != null and not c.ficha.is_empty() and int(c.ficha["id"]) == id:
			return c
	return null


static func _coord_pessoa(id: int) -> Vector2i:
	return Vector2i(id, FalasNpc.PESSOA)


## Numeros do perfil de quem trabalha: entregas, no prazo, atrasos, quanto
## rendeu e quantas tarefas fez na estufa.
static func estatisticas(id: int) -> Dictionary:
	var c := _coord_pessoa(id)
	return {
		"entregas": int(WorldState.obter(c, &"iw_entregas", 0)),
		"no_prazo": int(WorldState.obter(c, &"iw_no_prazo", 0)),
		"ganho": int(WorldState.obter(c, &"iw_ganho", 0)),
		"tarefas": int(WorldState.obter(c, &"tarefas", 0)),
		"colheitas": int(WorldState.obter(c, &"colheitas", 0)),
	}


static func _somar(id: int, chave: StringName, n: int) -> void:
	var c := _coord_pessoa(id)
	WorldState.definir(c, chave, int(WorldState.obter(c, chave, 0)) + n)


## Chamado pelo Convidado a cada tarefa feita na estufa, e pela conta de
## ausencia. E o que o perfil mostra como trabalho na plantacao.
static func contar_tarefa(id: int, acao: StringName) -> void:
	_somar(id, &"tarefas", 1)
	if acao == &"colher":
		_somar(id, &"colheitas", 1)


# --- conversa com o cliente ----------------------------------------------------

## A conversa do pedido: [[autor, texto, minuto_do_dia], ...]. Autor "c" e o
## cliente, "eu" e o jogador, "eq" e alguem da equipe.
static func mensagens(p: Dictionary) -> Array:
	var bruto: Variant = p.get("msgs", [])
	return bruto if bruto is Array else []


static func _msg(p: Dictionary, autor: String, texto: String) -> void:
	var lista: Array = mensagens(p).duplicate()
	var m := WorldState.relogio.minutos() if WorldState.relogio != null else 0
	lista.append([autor, texto, m])
	p["msgs"] = lista


## Mensagem do cliente que tambem vira notificacao do aparelho.
func _cliente_diz(p: Dictionary, texto: String) -> void:
	_msg(p, "c", texto)
	notificacao.emit("%s" % nome_curto(int(p["cliente"])).to_upper(), texto, AZUL)


## Contraproposta, uma por pedido. `fator` 1.25 ou 1.5. O cliente aceita com
## chance que cai com o tamanho do pedido de aumento e sobe com a satisfacao;
## recusar 50% a mais e desistir do pedido.
static func negociar(n: int, fator: float) -> Dictionary:
	var p := pedido(n)
	var i := instancia()
	if p.is_empty() or String(p["estado"]) != "novo" or bool(p.get("negociado", false)) \
			or i == null:
		return {"ok": false}
	var novo := int(roundf(float(p["preco"]) * fator))
	p["negociado"] = true
	_msg(p, "eu", "Faco por %s." % Dinheiro.formatar(novo))
	var s := float(cliente(int(p["cliente"])).get("satisfacao", 50.0))
	var chance := clampf(0.9 - (fator - 1.0) * 1.5 + (s - 50.0) / 150.0, 0.05, 0.95)
	var aceitou := i._rng.randf() < chance
	if aceitou:
		p["preco"] = novo
		_msg(p, "c", ["Caro, hein. Mas fechou.", "Ta bom, vai.", "So porque e voce."][n % 3])
		_mexer_satisfacao(int(p["cliente"]), -3.0)
	elif fator >= 1.45:
		p["estado"] = "recusado"
		_msg(p, "c", "Ta de brincadeira. Esquece.")
		_mexer_satisfacao(int(p["cliente"]), -8.0)
	else:
		_msg(p, "c", "Nao. O preco e esse.")
	# Pensar custa tempo: o prazo para aceitar anda um pouco.
	p["expira"] = maxf(float(p["expira"]), agora() + 1.0)
	_gravar(&"pedidos", pedidos())
	i.mudou.emit()
	return {"ok": true, "aceitou": aceitou, "cancelou": String(p["estado"]) == "recusado"}


static func responder_cliente(n: int, texto: String) -> void:
	var p := pedido(n)
	if p.is_empty():
		return
	_msg(p, "eu", texto)
	_gravar(&"pedidos", pedidos())


## Pede mais um minuto e meio de jogo, uma vez por pedido. O cliente topa, mas
## fica menos contente.
static func atrasar(n: int) -> bool:
	var p := pedido(n)
	if p.is_empty() or String(p["estado"]) != "aceito" or bool(p.get("atrasou", false)):
		return false
	p["atrasou"] = true
	p["fim"] = float(p["fim"]) + 1.5
	_msg(p, "eu", "Vou atrasar um pouco. Segura ai?")
	_msg(p, "c", "Ta. Mas nao demora.")
	_mexer_satisfacao(int(p["cliente"]), -3.0)
	_gravar(&"pedidos", pedidos())
	var i := instancia()
	if i != null:
		i.mudou.emit()
	return true


# --- acoes do jogador ---------------------------------------------------------

## Aceita o pedido para o jogador entregar pessoalmente. Traca a rota no GPS.
static func aceitar(n: int) -> bool:
	var p := pedido(n)
	if p.is_empty() or String(p["estado"]) != "novo":
		return false
	p["estado"] = "aceito"
	p["quem"] = ""
	_msg(p, "eu", "Fechado. Chego la.")
	_gravar(&"pedidos", pedidos())
	marcar_no_gps(n)
	var i := instancia()
	if i != null:
		i.mudou.emit()
	return true


static func recusar(n: int) -> void:
	var p := pedido(n)
	if p.is_empty() or String(p["estado"]) != "novo":
		return
	p["estado"] = "recusado"
	_msg(p, "eu", "Hoje nao vai dar.")
	_mexer_satisfacao(int(p["cliente"]), -4.0)
	_gravar(&"pedidos", pedidos())
	var i := instancia()
	if i != null:
		i.mudou.emit()


## Passa um pedido (novo ou aceito pelo jogador) para a equipe. Falso quando
## ninguem esta livre ou o estoque nao cobre.
static func passar(n: int) -> bool:
	var i := instancia()
	var p := pedido(n)
	if i == null or p.is_empty():
		return false
	var estado := String(p["estado"])
	if estado != "novo" and not (estado == "aceito" and String(p["quem"]) == ""):
		return false
	var ok := i._dar_para_equipe(p, agora())
	if ok:
		_gravar(&"pedidos", pedidos())
		if not Gps.destino.is_empty() and int(Gps.destino.get("iweed", -1)) == n:
			Gps.destino = {}
			Gps.rota = PackedVector2Array()
			Gps.destino_mudou.emit()
		i.mudou.emit()
	return ok


static func ponto(p: Dictionary) -> Vector3:
	return Vector3(float(p["x"]), float(p["y"]), float(p["z"]))


## Traca a rota ate o ponto de encontro, no mesmo GPS do pause e do minimapa.
static func marcar_no_gps(n: int) -> void:
	var p := pedido(n)
	if p.is_empty():
		return
	var onde := ponto(p)
	Gps.destino = {
		"categoria": &"iweed",
		"nome": "%s  %s" % [String(p["lugar"]), nome_curto(int(p["cliente"]))],
		"mundo": onde,
		"chunk": Vector2i(floori(onde.x / Mapa.TAM), floori(onde.z / Mapa.TAM)),
		"icone": &"telefone",
		"endereco": String(p.get("rua", "")),
		"iweed": n,
	}
	var jogador := (Engine.get_main_loop() as SceneTree).get_first_node_in_group(&"player") as Node3D
	var de := jogador.global_position if jogador != null else onde
	var i := instancia()
	if Interiores.dentro and i != null and i._ultimo_fora != Vector3.INF:
		de = i._ultimo_fora
	Gps.rota = Rota.tracar(de, onde)
	Gps.destino_mudou.emit()


## O proximo pedido que o JOGADOR tem de entregar, ou vazio.
static func proxima_do_jogador() -> Dictionary:
	for p: Dictionary in agenda():
		if String(p["estado"]) == "aceito" and String(p["quem"]) == "":
			return p
	return {}


## O jogador entrega em maos. Chamado pelo cliente no ponto de encontro.
## Devolve {ok, fala, efeito} para o cliente encenar.
static func entregar_em_maos(n: int) -> Dictionary:
	var p := pedido(n)
	if p.is_empty() or String(p["estado"]) != "aceito":
		return {"ok": false, "fala": "Ue, cancelaram?"}
	var produto := String(p["produto"])
	var item: StringName = PRODUTOS[produto]["item"]
	var qtd := int(p["qtd"])
	if Inventario.quantidade(item) < qtd:
		var tem := Inventario.quantidade(item)
		return {"ok": false, "fala": ("Cade? Eu pedi %d de %s." % [qtd, nome_do_produto(produto).to_lower()])
			if tem == 0 else "Ta faltando. Eu pedi %d, voce tem %d." % [qtd, tem]}
	Inventario.remover(item, qtd)
	var t := agora()
	var no_prazo := t <= float(p["fim"]) + 0.01
	p["estado"] = "entregue"
	p["quando"] = t
	_msg(p, "c", "Recebido. Valeu!")
	var preco := int(p["preco"])
	Dinheiro.receber(preco, "ENTREGA  %s" % nome_curto(int(p["cliente"])))
	_somar_jogador(preco)
	var i := instancia()
	var efeito := -1
	if produto == "super" and i != null:
		efeito = i._sortear_efeito()
		p["efeito"] = efeito
	_depois_da_entrega(p, no_prazo, efeito)
	if bool(cliente(int(p["cliente"])).get("x9", false)):
		_revelar_x9(int(p["cliente"]))
		BlitzNoCaminho.x9_do_jogador()
		if i != null:
			i.notificacao.emit("CUIDADO: ERA X9", "%s te entregou. Tem blitz por perto."
				% nome_curto(int(p["cliente"])), ALERTA)
		Cinema.fala("JOTA (celular): Esse cliente e X9! Some dai, esconde a mercadoria.")
	_gravar(&"pedidos", pedidos())
	if not Gps.destino.is_empty() and int(Gps.destino.get("iweed", -1)) == n:
		Gps.destino = {}
		Gps.rota = PackedVector2Array()
		Gps.destino_mudou.emit()
	if i != null:
		i.notificacao.emit("ENTREGUE", "+%s  %s" % [Dinheiro.formatar(preco),
			nome_curto(int(p["cliente"]))], OURO)
		i.mudou.emit()
	var falas := ["Valeu. Ta certinho.", "Chegou no horario. Assim da gosto.",
		"Isso ai. Vou avaliar com cinco estrelas."]
	return {"ok": true, "fala": falas[int(p["n"]) % falas.size()], "efeito": efeito}


static func _somar_jogador(preco: int) -> void:
	_gravar(&"voce_entregas", int(_ler(&"voce_entregas", 0)) + 1)
	_gravar(&"voce_ganho", int(_ler(&"voce_ganho", 0)) + preco)


# --- clientes -----------------------------------------------------------------

static func _mexer_satisfacao(id: int, quanto: float) -> void:
	var lista := clientes()
	for c: Dictionary in lista:
		if int(c["id"]) == id:
			c["satisfacao"] = clampf(float(c["satisfacao"]) + quanto, 0.0, 100.0)
	_gravar(&"clientes", lista)


## Contabilidade comum as duas maos: satisfacao, contagem, indicacao e o efeito
## da Super na ficha do cliente.
static func _depois_da_entrega(p: Dictionary, no_prazo: bool, efeito: int) -> void:
	var id := int(p["cliente"])
	var lista := clientes()
	var i := instancia()
	for c: Dictionary in lista:
		if int(c["id"]) != id:
			continue
		c["pedidos"] = int(c["pedidos"]) + 1
		var s := float(c["satisfacao"]) + (12.0 if no_prazo else -6.0)
		if String(p["produto"]) == "super":
			s += 8.0
		c["satisfacao"] = clampf(s, 0.0, 100.0)
		match efeito:
			EntregasDaSuper.Efeito.OLHO_DE_GATO:
				c["olho"] = true
			EntregasDaSuper.Efeito.EXPLODE:
				c["estado"] = "explodiu"
			EntregasDaSuper.Efeito.VOA:
				c["estado"] = "orbita"
	_gravar(&"clientes", lista)
	# O efeito tambem vai para as listas da rua: olho de gato em quem aparecer
	# na calcada, voo de volta no ceu.
	if efeito == EntregasDaSuper.Efeito.OLHO_DE_GATO:
		_anexar(EntregasDaSuper.COORD, &"olhos", id)
	elif efeito == EntregasDaSuper.Efeito.VOA:
		_anexar(EntregasDaSuper.COORD, &"voadores", id)
	# Cliente contente indica gente. E o unico jeito de a carteira crescer, e
	# e o que faz entregar no horario valer mais que o preco do pedido.
	if i != null and no_prazo and float(cliente(id).get("satisfacao", 0.0)) >= 55.0 \
			and clientes().size() < MAX_CLIENTES and i._rng.randf() < 0.35:
		var novo := i._novo_cliente(id)
		if novo >= 0:
			i.notificacao.emit("NOVO CLIENTE", "%s indicou %s" % [nome_curto(id),
				nome_curto(novo)], VERDE)


## O X9 aparece na carteira como X9 e nao pede mais nada.
static func _revelar_x9(id: int) -> void:
	var lista := clientes()
	for c: Dictionary in lista:
		if int(c["id"]) == id:
			c["estado"] = "x9"
	_gravar(&"clientes", lista)


static func _anexar(coord: Vector2i, chave: StringName, id: int) -> void:
	var lista: Array = []
	for v: Variant in WorldState.obter(coord, chave, []):
		lista.append(int(v))
	if not lista.has(id):
		lista.append(id)
	WorldState.definir(coord, chave, lista)


func _novo_cliente(indicado_por: int = -1) -> int:
	var lista := clientes()
	for tentativa in 6:
		var semente := int(_ler(&"serie_cliente", 0)) * 7919 + 4101 + tentativa * 131
		_gravar(&"serie_cliente", int(_ler(&"serie_cliente", 0)) + 1)
		var id := RegistroCivil.id_de_faixa(semente, 19, 64)
		if id < 0 or not cliente(id).is_empty():
			continue
		if RegistroCivil.personagem_de(id) != &"" or id == RegistroCivil.id_do_jogador():
			continue
		lista.append({
			"id": id, "desde": agora(), "pedidos": 0, "satisfacao": 50.0,
			"gosto": "super" if _rng.randf() < 0.35 else "maconha",
			"estado": "ativo", "olho": false, "indicado_por": indicado_por,
			# Um em cada oito entrega quem vende. Ninguem sabe ate receber.
			"x9": _rng.randf() < 0.12 and indicado_por >= 0,
		})
		_gravar(&"clientes", lista)
		return id
	return -1


func _cliente_ativo_sorteado() -> Dictionary:
	var ativos: Array = []
	var ocupados: Array = []
	for p: Dictionary in de_estado(["novo", "aceito", "a_caminho"]):
		ocupados.append(int(p["cliente"]))
	for c: Dictionary in clientes():
		if String(c["estado"]) == "ativo" and not ocupados.has(int(c["id"])) \
				and float(c["satisfacao"]) > 12.0:
			ativos.append(c)
	if ativos.is_empty():
		return {}
	return ativos[_rng.randi() % ativos.size()]


# --- laco ---------------------------------------------------------------------

func _process(delta: float) -> void:
	_atualizar_relogio()
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador != null and not Interiores.dentro:
		_ultimo_fora = jogador.global_position
	if _ultimo_fora != Vector3.INF and ativo():
		_ler_pontos(3)
	_tique -= delta
	if _tique > 0.0:
		return
	_tique = 0.25
	# Todo tique, e nao so na compra: o save carregado traz os niveis de volta
	# e as regras estaticas voltam ao padrao a cada partida.
	aplicar_melhorias()
	if not ativo() or pausado:
		return
	_rodar(agora())


func _atualizar_relogio() -> void:
	var guardado := float(_ler(&"abs", 0.0))
	if _abs < 0.0 or not is_equal_approx(guardado, _abs_gravado):
		# Primeiro quadro, ou o save trocou o WorldState por baixo: vale o
		# gravado.
		_abs = guardado
		_abs_gravado = guardado
		_visto_s = -1.0
	var s := WorldState.relogio.segundos
	if _visto_s >= 0.0:
		var passo := fposmod(s - _visto_s, float(Relogio.DIA))
		# Relogio que "anda" mais de meio dia num quadro voltou para tras
		# (definir_texto num teste, save antigo): nao conta.
		if passo < float(Relogio.DIA) * 0.5:
			_abs += passo / 60.0
	_visto_s = s
	if absf(_abs - _abs_gravado) >= 0.05:
		_gravar(&"abs", _abs)
		_abs_gravado = _abs


func _rodar(t: float) -> void:
	var mexeu := false
	if clientes().is_empty():
		for k in CLIENTES_INICIAIS:
			_novo_cliente()
		mexeu = true
	if t >= float(_ler(&"proximo", 0.0)):
		_gravar(&"proximo", t + _rng.randf_range(INTERVALO.x, INTERVALO.y))
		mexeu = _gerar_pedido(t) or mexeu
	_cuidar_da_estufa(t)

	var lista := pedidos()
	for p: Dictionary in lista:
		match String(p["estado"]):
			"novo":
				if t >= float(p["expira"]):
					if not _dar_para_equipe(p, t):
						p["estado"] = "expirado"
						if online():
							notificacao.emit("PEDIDO PERDIDO", "%s desistiu de esperar"
								% nome_curto(int(p["cliente"])), ALERTA)
					mexeu = true
			"aceito":
				# O cliente escreve: chegou no ponto, e cobra quando a janela
				# passa dos 70% sem ninguem aparecer.
				if not bool(p.get("avisou_chegada", false)) and t >= float(p["inicio"]):
					p["avisou_chegada"] = true
					_cliente_diz(p, "To aqui %s %s." % [no_lugar(String(p["lugar"])),
						String(p["lugar"]).to_lower()])
					mexeu = true
				var janela := float(p["fim"]) - float(p["inicio"])
				if not bool(p.get("cobrou", false)) \
						and t >= float(p["inicio"]) + janela * 0.7:
					p["cobrou"] = true
					_cliente_diz(p, "Vai demorar? To esperando.")
					mexeu = true
				if t > float(p["fim"]) and not _em_cena.has(int(p["n"])):
					_msg(p, "c", "Cansei. Fui embora.")
					p["estado"] = "falhou"
					_mexer_satisfacao(int(p["cliente"]), -22.0)
					notificacao.emit("CLIENTE FOI EMBORA", "%s cansou de esperar no %s"
						% [nome_curto(int(p["cliente"])), String(p["lugar"])], ALERTA)
					_limpar_gps(int(p["n"]))
					mexeu = true
			"a_caminho":
				if t >= float(p["chega"]) and not _em_cena.has(int(p["n"])):
					_chegou_a_equipe(p, t)
					mexeu = true
			"entregue", "atrasado", "falhou":
				if int(p.get("entregador", -1)) >= 0 and not bool(p.get("voltou", false)) 						and t >= float(p.get("volta", 0.0)):
					p["voltou"] = true
					Interiores.voltar_da_entrega(int(p["entregador"]))
					mexeu = true
	if mexeu:
		_podar(lista)
		_gravar(&"pedidos", lista)
		mudou.emit()
	_clientes_fisicos(t)


func _limpar_gps(n: int) -> void:
	if not Gps.destino.is_empty() and int(Gps.destino.get("iweed", -1)) == n:
		Gps.destino = {}
		Gps.rota = PackedVector2Array()
		Gps.destino_mudou.emit()


## Guarda os ultimos vinte encerrados; o resto vira so numero no perfil.
func _podar(lista: Array) -> void:
	var fechados := 0
	for k in range(lista.size() - 1, -1, -1):
		var estado := String(lista[k]["estado"])
		var aberto := estado == "novo" or estado == "aceito" or estado == "a_caminho" \
			or (float(lista[k].get("volta", 0.0)) > agora())
		if aberto:
			continue
		fechados += 1
		if fechados > 20:
			lista.remove_at(k)


func _gerar_pedido(t: float) -> bool:
	if de_estado(["novo", "aceito", "a_caminho"]).size() >= MAX_ABERTOS:
		return false
	var livres := _equipe_livre()
	if not online() and livres.is_empty():
		return false
	var c := _cliente_ativo_sorteado()
	if c.is_empty():
		return false
	var perto := _ultimo_fora
	if perto == Vector3.INF:
		return false
	var lugar := _sortear_ponto(perto)
	if lugar.is_empty():
		return false
	var produto := String(c["gosto"])
	# Super so e pedida quando existe: cliente nao pede o que ninguem nunca viu.
	if produto == "super" and EntregasDaSuper.pendentes() <= 0 \
			and Inventario.quantidade(&"super_maconha") <= 0:
		produto = "maconha"
	var def: Dictionary = PRODUTOS[produto]
	var qtd := _rng.randi_range(def["qtd"].x, def["qtd"].y)
	# Offline, quem atende e a equipe: pedido que o estoque nao cobre so viraria
	# uma notificacao de "pedido perdido" a cada dois minutos.
	if not online():
		qtd = mini(qtd, estoque(produto))
		if qtd <= 0:
			return false
	var unidade := _rng.randi_range(def["unidade"].x, def["unidade"].y)
	var preco := qtd * unidade
	if float(c["satisfacao"]) >= 70.0:
		preco = int(roundf(float(preco) * 1.1))
	var inicio := t + _rng.randf_range(ANTECEDENCIA.x, ANTECEDENCIA.y)
	var n := int(_ler(&"serie", 0)) + 1
	_gravar(&"serie", n)
	var onde: Vector3 = lugar["mundo"]
	var p := {
		"n": n, "cliente": int(c["id"]), "produto": produto, "qtd": qtd,
		"preco": preco, "criado": t, "inicio": inicio,
		"fim": inicio + _rng.randf_range(JANELA.x, JANELA.y),
		"expira": t + PRAZO_ACEITAR,
		"x": onde.x, "y": onde.y, "z": onde.z,
		"lugar": String(lugar["nome"]), "rua": String(lugar["rua"]),
		"estado": "novo", "quem": "", "entregador": -1,
	}
	_msg(p, "c", String(PEDIDO_TEXTOS[n % PEDIDO_TEXTOS.size()]) % [qtd,
		nome_do_produto(produto).to_lower(), Dinheiro.formatar(preco)])
	var nome_lugar := String(lugar["nome"])
	var onde_fica := "%s %s" % [no_lugar(nome_lugar), nome_lugar.to_lower()]
	if not String(lugar["rua"]).is_empty():
		onde_fica += " da %s" % String(lugar["rua"]).capitalize()
	_msg(p, "c", "To %s, entre %s e %s." % [onde_fica, hora(inicio), hora(float(p["fim"]))])
	var lista := pedidos()
	lista.append(p)
	_gravar(&"pedidos", lista)
	if online():
		notificacao.emit("NOVO PEDIDO", "%s  %dx %s  %s" % [nome_curto(int(c["id"])),
			qtd, nome_do_produto(produto), Dinheiro.formatar(preco)], VERDE)
	else:
		# Offline, o pedido nem passa pela caixa de entrada.
		p["expira"] = t
	return true


## Le ate `quantos` chunks ainda nao lidos em volta de onde o jogador esta.
func _ler_pontos(quantos: int) -> void:
	var alcance := ceili(RAIO.y / Mapa.TAM)
	if _anel.is_empty():
		for dz in range(-alcance, alcance + 1):
			for dx in range(-alcance, alcance + 1):
				_anel.append(Vector2i(dx, dz))
		_anel.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.length_squared() < b.length_squared())
	var c := Vector2i(floori(_ultimo_fora.x / Mapa.TAM), floori(_ultimo_fora.z / Mapa.TAM))
	var lidos := 0
	for d: Vector2i in _anel:
		var k := c + d
		if _pontos.has(k):
			continue
		_pontos[k] = _pontos_do_chunk(k.x, k.y)
		lidos += 1
		if lidos >= quantos:
			return
	# Tudo em volta lido: esquece o que ficou muito para tras.
	if _pontos.size() > 900:
		for k: Variant in _pontos.keys():
			var v := (k as Vector2i) - c
			if absi(v.x) > alcance + 6 or absi(v.y) > alcance + 6:
				_pontos.erase(k)


static func _pontos_do_chunk(cx: int, cz: int) -> Array:
	var saida: Array = []
	for ponto_bruto: Dictionary in ChunkBuilder.pontos_de_interesse(cx, cz):
		var categoria: StringName = ponto_bruto["tipo"]
		if categoria == &"porta":
			categoria = StringName(ponto_bruto.get("interior", &""))
		if not LUGARES.has(categoria):
			continue
		var local: Vector3 = ponto_bruto["pos"]
		saida.append([categoria, Vector3(float(cx) * Mapa.TAM + local.x, local.y,
			float(cz) * Mapa.TAM + local.z)])
	return saida


## Um lugar com nome, entre RAIO.x e RAIO.y de onde o jogador esta: orelhao,
## bar, praca, mercadinho. Os mesmos pontos que o GPS lista.
func _sortear_ponto(perto: Vector3) -> Dictionary:
	var c := Vector2i(floori(perto.x / Mapa.TAM), floori(perto.z / Mapa.TAM))
	var alcance := ceili(RAIO.y / Mapa.TAM)
	var candidatos: Array = []
	var total := 0.0
	for cz in range(c.y - alcance, c.y + alcance + 1):
		for cx in range(c.x - alcance, c.x + alcance + 1):
			for par: Array in _pontos.get(Vector2i(cx, cz), []):
				var categoria: StringName = par[0]
				var mundo: Vector3 = par[1]
				var d := Vector2(mundo.x - perto.x, mundo.z - perto.z).length()
				if d < RAIO.x or d > RAIO.y:
					continue
				var peso: float = LUGARES[categoria]
				total += peso
				candidatos.append({"peso": peso, "mundo": mundo, "categoria": categoria})
	if candidatos.is_empty():
		return {}
	var r := _rng.randf() * total
	var escolhido: Dictionary = candidatos[0]
	for k: Dictionary in candidatos:
		r -= float(k["peso"])
		if r <= 0.0:
			escolhido = k
			break
	var mundo: Vector3 = escolhido["mundo"]
	var rua := NomesDeRua.rua_perto(mundo)
	return {
		"mundo": mundo,
		"nome": String(NOMES_LUGAR.get(escolhido["categoria"], "PONTO")),
		"rua": rua,
	}


func _equipe_livre() -> Array[int]:
	var livres: Array[int] = []
	for id in equipe():
		if fora_em_entrega(id):
			continue
		# Quem esta com o jogador no andar 10 esta ocupado mostrando a planta.
		var no := _convidado_vivo(id)
		if no != null and no.estacionado():
			continue
		livres.append(id)
	return livres


func _base() -> Vector3:
	var x: Variant = _ler(&"base_x", null)
	if x == null:
		return _ultimo_fora if _ultimo_fora != Vector3.INF else Vector3.ZERO
	return Vector3(float(x), 0.0, float(_ler(&"base_z", 0.0)))


## Entrega o pedido a quem estiver livre na equipe, se o estoque cobrir.
func _dar_para_equipe(p: Dictionary, t: float) -> bool:
	var livres := _equipe_livre()
	if livres.is_empty():
		return false
	var produto := String(p["produto"])
	if not _tirar_do_estoque(produto, int(p["qtd"])):
		return false
	# Quem entregou menos vai. Divide o trabalho sem sorteio, e o perfil dos
	# dois cresce junto.
	livres.sort_custom(func(a: int, b: int) -> bool:
		return int(estatisticas(a)["entregas"]) < int(estatisticas(b)["entregas"]))
	var id := livres[0]
	var d := Vector2(float(p["x"]) - _base().x, float(p["z"]) - _base().z).length()
	var passo := PASSO_EQUIPE * (2.0 if nivel("bicicleta") > 0 else 1.0)
	var viagem := clampf(d / passo * Relogio.RITMO / 60.0, 1.0, 9.0)
	p["estado"] = "a_caminho"
	p["quem"] = String(RegistroCivil.personagem_de(id))
	p["entregador"] = id
	p["sai"] = t
	p["chega"] = maxf(t + viagem, float(p["inicio"]))
	p["volta"] = float(p["chega"]) + viagem
	notificacao.emit("%s PEGOU O PEDIDO" % apelido(id), "%dx %s  %s  %s" % [int(p["qtd"]),
		nome_do_produto(produto), nome_curto(int(p["cliente"])), String(p["lugar"])], VERDE)
	var no := _convidado_vivo(id)
	if no != null:
		no.sair_para_entregar()
	return true


func _chegou_a_equipe(p: Dictionary, t: float) -> void:
	var onde := ponto(p)
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	var perto := jogador != null and not Interiores.dentro \
		and Vector2(jogador.global_position.x - onde.x,
			jogador.global_position.z - onde.z).length() < ENCENA
	var efeito := _sortear_efeito() if String(p["produto"]) == "super" else -1
	var no_prazo := float(p["chega"]) <= float(p["fim"]) + 0.01
	p["estado"] = "entregue" if no_prazo else "atrasado"
	p["quando"] = t
	p["efeito"] = efeito
	var id := int(p["entregador"])
	# X9: quem entregou e abordado, a mercadoria fica com a policia e a equipe
	# perde a pessoa por uns minutos.
	if bool(cliente(int(p["cliente"])).get("x9", false)):
		p["estado"] = "falhou"
		p["volta"] = t + 8.0
		_msg(p, "c", "...")
		_revelar_x9(int(p["cliente"]))
		notificacao.emit("%s FOI ABORDADO" % apelido(id), "%s era X9. Volta em uns 8 minutos."
			% nome_curto(int(p["cliente"])), ALERTA)
		return
	_msg(p, "c", ("Chegou o %s. Valeu!" if no_prazo else "Demorou, mas o %s chegou.")
		% apelido(id).capitalize())
	var preco := int(p["preco"])
	var parte := int(roundf(float(preco) * (1.0 - COMISSAO)))
	Dinheiro.receber(parte, "%s ENTREGOU  %s" % [apelido(id), nome_curto(int(p["cliente"]))])
	_somar(id, &"iw_entregas", 1)
	_somar(id, &"iw_ganho", preco)
	if no_prazo:
		_somar(id, &"iw_no_prazo", 1)
	_depois_da_entrega(p, no_prazo, efeito)
	notificacao.emit("%s ENTREGOU" % apelido(id), "+%s  %s%s" % [Dinheiro.formatar(parte),
		nome_curto(int(p["cliente"])), "" if no_prazo else "  (ATRASADO)"], OURO)
	if perto:
		_encenar_equipe(p, efeito)


func _sortear_efeito() -> int:
	var eds := get_tree().get_first_node_in_group(&"entregas_da_super") as EntregasDaSuper
	if eds != null:
		return eds.sortear()
	return EntregasDaSuper.Efeito.OLHO_DE_GATO


## A cena da equipe, quando o jogador esta perto do ponto: o cliente esperando,
## o entregador chegando pela calcada, a troca, o trago e o efeito.
func _encenar_equipe(p: Dictionary, efeito: int) -> void:
	var eds := get_tree().get_first_node_in_group(&"entregas_da_super") as EntregasDaSuper
	if eds == null:
		return
	var n := int(p["n"])
	var cli := _cliente_no_mundo(p, false)
	if cli == null:
		return
	_em_cena[n] = true
	cli.ocupar()
	await eds.encenar(cli, int(p["entregador"]), efeito, String(p["produto"]))
	_em_cena.erase(n)
	_clientes_no_mundo.erase(n)
	if is_instance_valid(cli):
		cli.ir_embora()


# --- no mundo -----------------------------------------------------------------

## Poe o cliente do jogador no ponto quando o jogador chega perto, e tira quando
## ele se afasta ou o pedido acaba.
func _clientes_fisicos(t: float) -> void:
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	var vivos: Dictionary = {}
	for p: Dictionary in pedidos():
		if String(p["estado"]) != "aceito" or String(p["quem"]) != "":
			continue
		var n := int(p["n"])
		if jogador == null or Interiores.dentro or t < float(p["inicio"]) - 0.3:
			continue
		var onde := ponto(p)
		var d := Vector2(jogador.global_position.x - onde.x,
			jogador.global_position.z - onde.z).length()
		var existe: bool = _clientes_no_mundo.has(n) and is_instance_valid(_clientes_no_mundo[n])
		if existe:
			if d < SOME:
				vivos[n] = true
		elif d < APARECE:
			var cli := _cliente_no_mundo(p, true)
			if cli != null:
				vivos[n] = true
	for n: Variant in _clientes_no_mundo.keys():
		if vivos.has(n) or _em_cena.has(int(n)):
			continue
		var cli: Variant = _clientes_no_mundo[n]
		_clientes_no_mundo.erase(n)
		if is_instance_valid(cli):
			var estado := String(pedido(int(n)).get("estado", ""))
			if estado == "falhou":
				(cli as ClienteIWeed).ir_embora()
			elif estado != "entregue":
				(cli as Node).queue_free()


func _cliente_no_mundo(p: Dictionary, do_jogador: bool) -> ClienteIWeed:
	var n := int(p["n"])
	if _clientes_no_mundo.has(n) and is_instance_valid(_clientes_no_mundo[n]):
		return _clientes_no_mundo[n]
	var cli := ClienteIWeed.new()
	cli.name = "ClienteIWeed%d" % n
	add_child(cli)
	var chegando := do_jogador and agora() < float(p["inicio"]) + 0.6
	cli.preparar(RegistroCivil.identidade(int(p["cliente"])), n, ponto(p), do_jogador, chegando)
	_clientes_no_mundo[n] = cli
	return cli


## Chamado pelo cliente quando o jogador aperta [E] nele.
func entregue_pelo_jogador(n: int, cli: ClienteIWeed) -> void:
	var r := entregar_em_maos(n)
	if not bool(r["ok"]):
		cli.reclamar(String(r["fala"]))
		return
	_em_cena[n] = true
	await cli.receber(String(r["fala"]), String(pedido(n).get("produto", "")))
	var efeito := int(r.get("efeito", -1))
	var eds := get_tree().get_first_node_in_group(&"entregas_da_super") as EntregasDaSuper
	if eds != null and is_instance_valid(cli):
		await eds.efeito_em(cli, efeito)
	_em_cena.erase(n)
	_clientes_no_mundo.erase(n)
	if is_instance_valid(cli):
		cli.ir_embora()


# --- estufa sem o jogador -----------------------------------------------------

## A plantacao anda enquanto o jogador esta na rua. `Plantacao._ready` ja faz
## essa conta quando a porta abre; aqui ela e feita aos poucos, para a
## prateleira encher de verdade e a equipe ter o que entregar sem o jogador
## precisar entrar la a cada pedido.
func _cuidar_da_estufa(t: float) -> void:
	var semente := int(_ler(&"estufa", 0))
	if semente == 0 or get_tree().get_first_node_in_group(&"plantacao") != null:
		return
	if t < float(_ler(&"estufa_tique", 0.0)):
		return
	_gravar(&"estufa_tique", t + 2.0)
	var fazendeiros: Array[int] = []
	for id: Variant in Profissoes.empregados(&"fazendeiro"):
		if not fora_em_entrega(int(id)):
			fazendeiros.append(int(id))
	var antes := int(Plantio.estado(semente, int(_ler(&"vasos", Plantio.POTES))).get("colhido", 0))
	Plantio.sincronizar(semente, int(_ler(&"vasos", Plantio.POTES)), fazendeiros.size())
	var feitas := Plantio.ultimas_tarefas
	if feitas > 0 and not fazendeiros.is_empty():
		for k in feitas:
			_somar(fazendeiros[k % fazendeiros.size()], &"tarefas", 1)
	var depois := int(Plantio.estado(semente, int(_ler(&"vasos", Plantio.POTES))).get("colhido", 0))
	if depois > antes and not fazendeiros.is_empty():
		_somar(fazendeiros[_rng.randi() % fazendeiros.size()], &"colheitas", 1)
	# A Super la de cima: pronta ha mais de SUPER_ESPERA sem o jogador colher,
	# a dupla colhe e guarda para entregar.
	if EntregasDaSuper.planta_pronta() and not fazendeiros.is_empty():
		var desde := float(_ler(&"super_pronta_desde", -1.0))
		if desde < 0.0:
			_gravar(&"super_pronta_desde", t)
		elif t - desde >= SUPER_ESPERA:
			_gravar(&"super_pronta_desde", -1.0)
			WorldState.definir(EntregasDaSuper.COORD, &"pronta", false)
			WorldState.definir(EntregasDaSuper.COORD, &"cresce", EntregasDaSuper.minutos_de_crescer())
			WorldState.definir(EntregasDaSuper.COORD, &"pendentes",
				EntregasDaSuper.pendentes() + EntregasDaSuper.DOSES_POR_COLHEITA)
			var quem := fazendeiros[_rng.randi() % fazendeiros.size()]
			_somar(quem, &"colheitas", 1)
			notificacao.emit("%s COLHEU A SUPER" % apelido(quem), "+%d doses no estoque"
				% EntregasDaSuper.DOSES_POR_COLHEITA, VERDE)
	else:
		_gravar(&"super_pronta_desde", -1.0)
