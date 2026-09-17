## As regras do cultivo. Sem no, sem malha, sem cena: so o estado e o que o faz
## mudar.
##
## Este arquivo e o equivalente de `FalasNpc` para a estufa — regra pura, lida e
## gravada no WorldState, consultada por quem tem no. Quem desenha e
## `Plantacao`; quem trabalha e o `Convidado` de rotina `fazendeiro`; quem
## contrata e `Profissoes`. Nenhum dos tres sabe a regra, e por isso os tres
## nunca discordam.
##
## A escada, que e a do Schedule I
## --------------------------------
## O vaso comeca VAZIO. Nao ha planta nenhuma ali, e e de proposito: a primeira
## coisa que o jogador ve na estufa nao pode ser so uma plantacao pronta, senao
## o sistema inteiro e invisivel. Tem de haver vaso vazio na sala para o jogador
## perguntar "e esse?".
##
##   VAZIO      -> por terra          -> TERRA
##   TERRA      -> plantar semente    -> SEMEADO
##   SEMEADO    -> regar              -> CRESCENDO
##   CRESCENDO  -> o tempo passa      -> PRONTA        (so enquanto houver agua)
##   PRONTA     -> colher             -> TERRA, e a terra envelhece um uso
##
## A terra aguenta tres colheitas e depois volta a VAZIO. E o que impede a
## estufa de virar moto-perpetuo e o que da ao saco de terra uma razao de
## existir depois da primeira vez.
##
## Por que o tempo e do RELOGIO e nao do quadro
## --------------------------------------------
## `WorldState.relogio` corre com o jogo inteiro, inclusive com o jogador do
## outro lado da cidade. Se o crescimento contasse quadro dentro do comodo, sair
## da estufa congelaria a plantacao e voltar nunca mostraria nada de novo — e a
## unica graca de um cultivo e voltar e encontrar diferente.
##
## Entao cada plantacao guarda o MINUTO em que foi vista pela ultima vez, e
## quem entra paga a diferenca de uma vez so (`sincronizar`). E a mesma conta
## para dez minutos e para dez horas.
class_name Plantio
extends RefCounted

enum Fase { VAZIO, TERRA, SEMEADO, CRESCENDO, PRONTA }

## Quatro numeros por vaso, nesta ordem. Ficam num array plano de inteiros e nao
## num dicionario por vaso porque isto vai para o save em JSON, e um array de
## inteiros e a unica forma que atravessa JSON sem virar outra coisa do outro
## lado.
const FASE := 0
const AGUA := 1          ## 0 a 1000
const CRESCIMENTO := 2   ## 0 a 1000
const USOS := 3          ## quantas colheitas esta terra ja deu
const CAMPOS := 4

const MIL := 1000

## Quanto tempo de RELOGIO, em minutos, uma planta leva do primeiro gole ate a
## colheita. Doze minutos de relogio sao seis de jogo: o relogio corre ao dobro
## (ver Relogio.RITMO).
##
## Seis minutos reais e o tempo do Schedule I, e nao e coincidencia — e o tempo
## em que um jogador aceita ficar por perto vendo. Mais que isso ele sai e nunca
## mais volta para ver; menos que isso nao ha cultivo, ha botao.
const MINUTOS_ATE_MADURA := 12.0

## Quanto tempo a agua de uma rega dura. Menor que o ciclo DE PROPOSITO: uma
## planta precisa de duas regas para chegar ao fim, e e essa folga que da
## trabalho ao fazendeiro. Com agua bastando para o ciclo inteiro, regar seria
## um botao apertado uma vez e a profissao nao teria o que fazer.
const MINUTOS_DE_AGUA := 8.0

## Abaixo disso o fazendeiro considera o vaso com sede. Nao e zero: quem cuida
## de planta rega antes de ela secar.
const SEDE := 0.35

const USOS_DA_TERRA := 3

## Quanto sai de uma planta. Tres, e nao um: um pote de vidro por planta e uma
## prateleira que nunca enche, e a prateleira cheia e o placar da estufa.
const RENDIMENTO := 3

## Quanto tempo de relogio um fazendeiro leva por tarefa. Serve para dois
## lugares: o passo do NPC quando o jogador esta olhando, e o quanto de trabalho
## foi feito enquanto ele estava fora. Ter o mesmo numero nos dois e o que
## impede a estufa de andar mais rapido quando ninguem ve.
const MINUTOS_POR_TAREFA := 1.2

## Capacidade do regador, em regas.
const REGADOR := 6

## O que cabe na prateleira de potes. Passou disso, a colheita para de aparecer
## — mas continua contando, porque quem colheu colheu.
const POTES := 9
const POR_POTE := 12

## O que ja estava na prateleira quando o jogador abriu aquela porta pela
## primeira vez.
##
## Nao e zero. Jota e Helmer trabalham ali desde antes de o jogador saber que a
## sala existe, e uma prateleira de nove potes vazios diria o contrario — que
## nada nunca saiu dali, o que faz a estufa inteira parecer um cenario montado
## para a visita.
##
## Dois potes cheios e um pela metade: o bastante para a fila LER como fila e
## para o oitavo e o nono continuarem sendo espaco vazio esperando trabalho.
const COLHEITA_JA_FEITA := 30


static func coord(semente: int) -> Vector2i:
	return Vector2i(semente, WorldState.INTERIOR)


# --- leitura e escrita ------------------------------------------------------

## O estado da plantacao desta estufa. Cria na primeira visita, le nas outras.
##
## `quantos` e o numero de vasos que o comodo tem hoje. Ele pode CRESCER entre
## uma visita e outra — e a estufa e expansivel de proposito — e por isso a
## lista e esticada aqui em vez de ser conferida: vaso novo entra vazio, que e
## exatamente o que um vaso novo e.
static func estado(semente: int, quantos: int) -> Dictionary:
	var c := coord(semente)
	var bruto: Variant = WorldState.obter(c, &"plantio", null)
	var d: Dictionary = {}
	if bruto is Dictionary:
		d = bruto
	var vasos: Array = d.get("vasos", [])
	if vasos.size() < quantos * CAMPOS:
		vasos = _esticar(vasos, quantos, semente)
	return {
		"vasos": vasos,
		"colhido": int(d.get("colhido", COLHEITA_JA_FEITA)),
		"regador": int(d.get("regador", REGADOR)),
		"minuto": float(d.get("minuto", float(WorldState.relogio.minutos()))),
	}


static func gravar(semente: int, e: Dictionary) -> void:
	WorldState.definir(coord(semente), &"plantio", {
		"vasos": e["vasos"],
		"colhido": int(e["colhido"]),
		"regador": int(e["regador"]),
		"minuto": float(e["minuto"]),
	})


## A plantacao que o jogador encontra na primeira vez que abre aquela porta.
##
## Nao e sorteada de qualquer jeito: a estufa tem de ENSINAR o ciclo sem uma
## linha de texto. Entao a sala mostra a escada inteira de uma vez, do vaso
## vazio ao pe carregado, e quem anda pelo corredor le a ordem pela ordem das
## linhas — que e como se explica um processo sem explicar nada.
##
## As duas ultimas linhas nascem VAZIAS — oito vasos de vinte e quatro. Sao a
## parte da estufa que ainda nao existe, e e o convite: a sala diz que cabe mais.
##
## Oito, e nao doze. Com metade da sala vazia a estufa lia como abandonada, que
## e o oposto do que ela tem de dizer: ali dentro ha uma operacao rodando, e o
## espaco livre e espaco de CRESCER e nao de sobra.
static func _esticar(vasos: Array, quantos: int, semente: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente ^ 0x9E3779B9
	var saida: Array = vasos.duplicate()
	var antes := saida.size() / CAMPOS
	for i in range(antes, quantos):
		var fase := Fase.VAZIO
		var agua := 0
		var cresc := 0
		# As tres primeiras linhas de quatro vasos contam a historia; da quarta
		# em diante o comodo espera o jogador.
		if i < 4:
			fase = Fase.PRONTA
			agua = rng.randi_range(300, 700)
			cresc = MIL
		elif i < 12:
			fase = Fase.CRESCENDO
			agua = rng.randi_range(400, 900)
			cresc = rng.randi_range(180, 820)
		elif i < 16:
			fase = Fase.TERRA if i % 2 == 0 else Fase.SEMEADO
		saida.append(fase)
		saida.append(agua)
		saida.append(cresc)
		saida.append(0)
	return saida


# --- leitura de um vaso -----------------------------------------------------

static func fase_de(vasos: Array, i: int) -> Fase:
	return int(vasos[i * CAMPOS + FASE]) as Fase


static func agua_de(vasos: Array, i: int) -> float:
	return float(vasos[i * CAMPOS + AGUA]) / float(MIL)


static func crescimento_de(vasos: Array, i: int) -> float:
	return float(vasos[i * CAMPOS + CRESCIMENTO]) / float(MIL)


static func usos_de(vasos: Array, i: int) -> int:
	return int(vasos[i * CAMPOS + USOS])


static func quantos(vasos: Array) -> int:
	return vasos.size() / CAMPOS


static func _por(vasos: Array, i: int, campo: int, valor: int) -> void:
	vasos[i * CAMPOS + campo] = clampi(valor, 0, MIL if campo != USOS else 99)


# --- a acao que cada vaso pede ----------------------------------------------

## O que falta neste vaso. Vazio quer dizer "nada a fazer agora".
##
## Uma funcao so, e e ela que decide TUDO: o rotulo que aparece para o jogador,
## o que o fazendeiro vai fazer quando chegar la, e o que foi feito enquanto
## ninguem estava olhando. Tres consumidores, uma regra — que e a unica forma
## de os tres nunca discordarem sobre o que aquele vaso precisa.
static func acao(vasos: Array, i: int) -> StringName:
	match fase_de(vasos, i):
		Fase.VAZIO:
			return &"terra"
		Fase.TERRA:
			return &"semente"
		Fase.SEMEADO:
			return &"agua"
		Fase.PRONTA:
			return &"colher"
		Fase.CRESCENDO:
			if agua_de(vasos, i) < SEDE:
				return &"agua"
	return &""


## O rotulo do prompt, na voz do jogo e nao na do sistema.
static func rotulo(vasos: Array, i: int) -> String:
	match acao(vasos, i):
		&"terra":
			return "Por terra no vaso"
		&"semente":
			return "Plantar a semente"
		&"agua":
			return "Regar"
		&"colher":
			return "Colher"
	return "Deixar crescer"


## Aplica uma acao. Devolve quanto foi colhido — zero para tudo que nao e
## colheita, e zero tambem para a acao que nao cabia.
##
## Nao consulta inventario nem estoque: quem tem saco de terra na mao e quem
## chama. A regra so sabe o que o vaso aceita.
static func aplicar(vasos: Array, i: int, o_que: StringName) -> int:
	if o_que != acao(vasos, i):
		return 0
	match o_que:
		&"terra":
			_por(vasos, i, FASE, Fase.TERRA)
			_por(vasos, i, USOS, 0)
			_por(vasos, i, CRESCIMENTO, 0)
		&"semente":
			_por(vasos, i, FASE, Fase.SEMEADO)
			_por(vasos, i, CRESCIMENTO, 0)
		&"agua":
			_por(vasos, i, AGUA, MIL)
			if fase_de(vasos, i) == Fase.SEMEADO:
				_por(vasos, i, FASE, Fase.CRESCENDO)
		&"colher":
			var usos := usos_de(vasos, i) + 1
			_por(vasos, i, CRESCIMENTO, 0)
			_por(vasos, i, USOS, usos)
			# A terra gasta volta a ser vaso vazio, e nao terra ruim: terra
			# ruim seria um quarto estado que ninguem enxerga na tela.
			_por(vasos, i, FASE,
				Fase.VAZIO if usos >= USOS_DA_TERRA else Fase.TERRA)
			return RENDIMENTO
	return 0


# --- o tempo ----------------------------------------------------------------

## Paga a diferenca de relogio desde a ultima vez que este comodo foi visto.
##
## `fazendeiros` e quanta gente estava trabalhando aqui enquanto o jogador nao
## estava. Zero e o caso honesto: a agua acaba, o crescimento para onde parou e
## a estufa espera. Com gente contratada, o trabalho acontece — mas em passo de
## gente, `MINUTOS_POR_TAREFA` por tarefa, e nao tudo de uma vez. E a diferenca
## entre contratar alguem e apertar um botao de "pular para o fim".
static func sincronizar(semente: int, quantidade: int,
		fazendeiros: int) -> Dictionary:
	var e := estado(semente, quantidade)
	var agora := float(WorldState.relogio.minutos())
	var passou: float = agora - float(e["minuto"])
	# O relogio vira a meia-noite e volta a zero. Sem isto, a plantacao inteira
	# recebe um dia negativo de uma vez e nada cresce nunca mais.
	if passou < 0.0:
		passou += float(Relogio.DIA) / 60.0
	e["minuto"] = agora
	if passou <= 0.0:
		return e

	var vasos: Array = e["vasos"]
	_correr_o_tempo(vasos, passou)
	if fazendeiros > 0:
		var tarefas := int(float(fazendeiros) * passou / MINUTOS_POR_TAREFA)
		e["colhido"] = int(e["colhido"]) + _trabalhar(vasos, tarefas)
	gravar(semente, e)
	return e


## O que o tempo sozinho faz: seca a terra e empurra o que tem agua.
##
## O crescimento so anda enquanto ha agua, e por isso a conta e feita em dois
## passos — quantos minutos daquele intervalo tiveram agua, e so esses contam.
## Somar o intervalo inteiro faria a planta crescer no vaso seco, que e
## exatamente o que a mecanica existe para nao deixar acontecer.
static func _correr_o_tempo(vasos: Array, minutos: float) -> void:
	for i in quantos(vasos):
		if fase_de(vasos, i) != Fase.CRESCENDO:
			continue
		var agua := agua_de(vasos, i)
		var com_agua: float = minf(minutos, agua * MINUTOS_DE_AGUA)
		var cresc: float = crescimento_de(vasos, i) + com_agua / MINUTOS_ATE_MADURA
		_por(vasos, i, AGUA, int((agua - minutos / MINUTOS_DE_AGUA) * MIL))
		_por(vasos, i, CRESCIMENTO, int(cresc * MIL))
		if cresc >= 1.0:
			_por(vasos, i, FASE, Fase.PRONTA)


## Gasta `tarefas` de trabalho de fazendeiro na plantacao. Devolve a colheita.
##
## Usa `proxima_tarefa`, que e a mesma funcao que o NPC vivo usa para decidir
## para onde andar. Duas simulacoes do mesmo trabalho — uma com o jogador na
## sala e outra sem — que discordassem seriam o tipo de erro que so aparece
## depois de o jogador ja ter desconfiado do sistema inteiro.
static func _trabalhar(vasos: Array, tarefas: int) -> int:
	var colhido := 0
	for _k in tarefas:
		var t := proxima_tarefa(vasos)
		if t.is_empty():
			break
		colhido += aplicar(vasos, int(t["vaso"]), StringName(t["acao"]))
	return colhido


## O proximo vaso que precisa de alguma coisa, e do que ele precisa.
##
## A ordem nao e a dos vasos, e a da urgencia: primeiro colher, porque vaso
## cheio nao produz mais nada e ocupa lugar; depois matar a sede de quem ja esta
## crescendo, porque planta seca perde o que ja andou; e so entao comecar coisa
## nova. E a ordem em que qualquer um que cuide de planta faz, e ela e o que faz
## o fazendeiro parecer que sabe o que esta fazendo.
##
## `perto_de` desempata pela distancia quando ha varios da mesma urgencia: sem
## isso o NPC atravessa a sala para regar o vaso 0 com um vaso com sede ao lado
## do pe dele, e nada denuncia mais depressa um roteiro do que isso.
static func proxima_tarefa(vasos: Array, posicoes: Array[Vector3] = [],
		perto_de := Vector3.ZERO) -> Dictionary:
	var ordem: Array[StringName] = [&"colher", &"agua", &"semente", &"terra"]
	for alvo: StringName in ordem:
		var melhor := -1
		var melhor_d := INF
		for i in quantos(vasos):
			if acao(vasos, i) != alvo:
				continue
			var d := 0.0
			if i < posicoes.size():
				d = posicoes[i].distance_squared_to(perto_de)
			if d < melhor_d:
				melhor_d = d
				melhor = i
		if melhor >= 0:
			return {"vaso": melhor, "acao": alvo}
	return {}


# --- leitura para quem mostra -----------------------------------------------

## Quantos potes da prateleira estao cheios, e quanto tem no que esta enchendo.
## E o placar da sala: a prateleira e o unico lugar em que o trabalho de ontem
## aparece hoje.
static func prateleira(colhido: int) -> Dictionary:
	var cheios: int = mini(colhido / POR_POTE, POTES)
	var resto: float = 0.0
	if cheios < POTES:
		resto = float(colhido % POR_POTE) / float(POR_POTE)
	return {"cheios": cheios, "parcial": resto}


## Quantos vasos estao em cada fase, mais quantos estao com sede.
##
## Serve a verificacao e ao fazendeiro: e este censo que Helmer le antes de
## responder "tem quatro pra colher". `sede` nao e uma fase — e um vaso
## crescendo com pouca agua —, e por isso e contado a parte e pode somar com
## `crescendo`.
static func censo(vasos: Array) -> Dictionary:
	var c := {&"vazio": 0, &"terra": 0, &"semeado": 0, &"crescendo": 0,
		&"pronta": 0, &"sede": 0}
	var nomes: Array[StringName] = [&"vazio", &"terra", &"semeado",
		&"crescendo", &"pronta"]
	for i in quantos(vasos):
		var n := nomes[int(fase_de(vasos, i))]
		c[n] = int(c[n]) + 1
		if acao(vasos, i) == &"agua":
			c[&"sede"] = int(c[&"sede"]) + 1
	return c
