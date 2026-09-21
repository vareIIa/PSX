## Monta a conversa de uma pessoa: junta o temperamento com a ficha civil.
##
## A Personalidade da o texto e a ficha da os fatos. Aqui os dois se costuram:
## o {profissao} da fala vira COSTUREIRA, o {parente} vira o nome de quem mora
## na mesma casa, o {bairro} vira o distrito do endereco. E o que faz dois
## desconfiados dizerem a mesma coisa sobre a nevoa e coisas diferentes sobre a
## propria vida.
##
## O que fica guardado, e por que quase nada fica
## ----------------------------------------------
## So o que o jogador fez: quais assuntos ele ja puxou com quem. Isso mora no
## WorldState, na faixa de coordenada reservada as pessoas, e entra no save. O
## resto — nome, fala, familia — nao se guarda porque se deduz do id, e deduzir
## e mais barato que carregar.
class_name FalasNpc
extends RefCounted

## Faixa de coordenada do WorldState reservada as pessoas. Vizinha da dos
## interiores e igualmente longe de qualquer chunk de rua: seria preciso andar
## treze milhoes de metros para uma esquina cair aqui.
const PESSOA := 424243

## Titulo da opcao que abre o documento. E sempre a ultima, e e sempre a mesma
## frase: o jogador tem de aprender que existe em toda conversa.
const TITULO_DOCUMENTO := "VER IDENTIDADE"
const TITULO_SAIR := "ENCERRAR"
## So aparece com o sujeito ao volante. O jogador e investigador: nao arromba
## carro, pede o carro — e a diferenca entre as duas coisas e esta linha.
const TITULO_DESCER := "PEDIR PARA DESCER DO VEICULO"

## Titulos dos assuntos comuns. Curtos: a caixa de fala tem 440 pixels de largura
## e a lista inteira precisa caber sem quebrar linha.
const TITULOS := {
	&"nevoa": "SOBRE A NEVOA",
	&"bairro": "SOBRE ESTE BAIRRO",
	&"voce": "QUEM E VOCE?",
	&"role": "O QUE TA ROLANDO AQUI?",
	&"plantio": "COMO VAI A PLANTACAO?",
	&"super": "E ESSA PLANTA AI?",
	&"entregar": "LEVA A SUPER PROS CLIENTES",
}

## Se o jogador esta no andar 10 da estufa agora. Quem liga e desliga e o
## SuperQuarto, na hora em que a dupla muda de andar.
static var andar_dez := false

## O assunto que so existe dentro da casa da fumaca.
##
## Por que ele nao entra na tabela de temperamentos
## ------------------------------------------------
## `Personalidade` tem doze temperamentos, cada um com resposta propria para os
## tres assuntos da rua. Escrever o assunto da casa la dentro custaria doze
## blocos novos para um lugar so — e, pior, estaria errado: numa festa as doze
## pessoas estao falando DA MESMA COISA. O que muda entre elas nao e o assunto,
## e o tom.
##
## Entao as linhas sao tres — aspera, neutra e gentil — escolhidas pela mesma
## `aspereza` deste arquivo, que o transito ja usa para decidir quem buzina. O
## desconfiado e o mandao respondem seco, o gentil e o sonhador puxam conversa,
## e a ficha entra no texto como em todo o resto do sistema.
const ROLE := {
	"aspero": [
		["Ta rolando o que voce ta vendo.", "Se e pra ficar, fica. Se nao, a porta e ali."],
		["Nada. Sempre nada.", "E melhor assim."],
	],
	"neutro": [
		["Bomba Patch. Ta {idade} a {idade} desde as oito.",
			"Quem perde sai. Ninguem sai faz duas horas."],
		["Isso aqui nao acaba, entendeu? So vai diminuindo.",
			"Amanha tem de novo."],
	],
	"gentil": [
		["Voce chegou na hora boa. Senta ali, tem lugar.",
			"Se quiser alguma coisa, na bancada tem."],
		["A gente se junta aqui desde antes da nevoa.",
			"E o unico lugar que continuou igual. Nao sei se e bom."],
	],
}

## O que o dono da casa responde, e o que ele paga.
##
## E o unico bloco deste arquivo escrito para UMA pessoa, e vale a excecao: e o
## fim da primeira missao do jogo. Ate agora ela terminava no instante em que o
## jogador cruzava a porta — o comodo mais trabalhado do jogo era cenario de um
## "OBJETIVO CUMPRIDO" e nada mais.
const ROLE_DONO := [
	"Voce e o cara da praca. Ja ouvi falar.",
	"Ninguem entra nessa cidade faz tempo, {primeiro}. Sair e que e o problema.",
	"Toma. Voce vai precisar mais do que eu.",
]


## O que se responde na estufa, e e a unica fala do jogo que le o MUNDO antes de
## falar.
##
## Todo o resto deste arquivo costura a ficha civil no texto: nome, mae, bairro.
## Aqui entra o estado da plantacao — quantos vasos estao prontos, quantos estao
## com sede, quantos estao vazios —, e por isso perguntar a Helmer como vai a
## plantacao devolve o numero que o jogador pode conferir andando ate la.
##
## E o que separa um fazendeiro de um boneco que diz "ta indo bem": a frase dele
## tem de poder estar ERRADA se o jogador nao cuidar, senao nao e informacao, e
## enfeite. O bloco e escolhido pelo que mais pesa agora, nesta ordem: colher
## primeiro, sede depois, vaso vazio por ultimo — a mesma ordem de urgencia que
## `Plantio.proxima_tarefa` usa para decidir o que fazer, porque e a mesma
## cabeca falando e trabalhando.
const PLANTIO := {
	"pronta": [
		"Tem {n} pra colher agora. Ja ja eu pego.",
		"Nao repara a bagunca, e dia de corte: {n} no ponto.",
	],
	"sede": [
		"{n} pedindo agua. O tanque ta cheio, e so ir la.",
		"Tem {n} com sede. Nesse calor de lampada, seca rapido.",
	],
	"vazio": [
		"Tem {n} vaso vazio esperando terra. Saco ta ali no canto.",
		"Sobrou espaco: {n} vaso limpo. Se quiser plantar, e so pegar terra.",
	],
	"em_dia": [
		"Ta tudo em dia. Agora e esperar as folhas fecharem.",
		"Nada pra fazer agora. So olhar crescer, que e a parte boa.",
	],
}

## O que alguem que NAO cuida da estufa responde sobre ela.
##
## Existe porque o jogador pode contratar quem quiser, e a pessoa recem-chegada
## na sala nao tem a menor ideia do que esta acontecendo ali. Ela precisa soar
## como recem-chegada, senao contratar alguem nao muda nada — e a diferenca
## entre Helmer e um estranho de primeiro dia e metade do que a profissao vale.
const PLANTIO_DE_FORA := [
	"Pergunta pros caras, eu cheguei agora.",
	"So sei que e quente aqui dentro.",
]


static func _coord(id: int) -> Vector2i:
	return Vector2i(id, PESSOA)


static func ja_falou(id: int, chave: StringName) -> bool:
	return bool(WorldState.obter(_coord(id), StringName("npc_%s" % chave), false))


static func marcar(id: int, chave: StringName) -> void:
	WorldState.definir(_coord(id), StringName("npc_%s" % chave), true)


## Troca os marcadores pelo dado da ficha.
##
## Nao usa format_string do motor de proposito: uma chave que nao existe some
## em silencio em vez de deixar "{parente}" na tela, e numa cidade gerada e
## garantido que uma hora uma chave vai faltar.
static func costurar(texto: String, ficha: Dictionary) -> String:
	if not texto.contains("{"):
		return texto
	var vinculos := RegistroCivil.vinculos(int(ficha["id"]))
	var parente := ""
	var relacao := ""
	if not vinculos.is_empty():
		var v: Dictionary = vinculos[absi(int(ficha["id"])) % vinculos.size()]
		parente = String(v["nome"]).split(" ")[0]
		relacao = String(v["relacao"]).to_lower()

	var distrito := MalhaUrbana.distrito_de(int(ficha["cx"]), int(ficha["cz"]))
	var trocas := {
		"{nome}": String(ficha["nome"]),
		"{primeiro}": String(ficha["primeiro"]),
		"{sobrenome}": String(ficha["sobrenome"]).split(" ")[0],
		"{profissao}": String(ficha["profissao"]),
		"{idade}": str(int(ficha["idade"])),
		"{mae}": String(ficha["mae"]),
		"{bairro}": MalhaUrbana.nome_do_distrito(distrito),
		"{natural}": String(ficha["naturalidade"]).split(" - ")[0],
		"{parente}": parente if parente != "" else "vizinho",
		"{relacao}": relacao if relacao != "" else "conhecido",
	}
	var saida := texto
	for chave: String in trocas:
		saida = saida.replace(chave, String(trocas[chave]))
	return saida


static func _linhas(bruto: Array, ficha: Dictionary) -> Array[String]:
	var saida: Array[String] = []
	for l: Variant in bruto:
		saida.append(costurar(String(l), ficha))
	return saida


## Uma frase de abertura, escolhida pelo id: a mesma pessoa cumprimenta sempre
## do mesmo jeito, e e isso que a faz parecer a mesma pessoa.
static func saudacao(ficha: Dictionary) -> String:
	var p := Personalidade.de(int(ficha["personalidade"]))
	var lista: Array = p["saudacao"]
	var id := int(ficha["id"])
	if RegistroCivil.ja_conhece(id) and ja_falou(id, &"voce"):
		# Segunda conversa em diante. Reconhecer quem ja parou uma vez custa uma
		# linha e muda a cidade inteira de tom.
		return costurar("Voce de novo." if int(ficha["personalidade"]) % 3 == 0
			else "Ah. E voce.", ficha)
	return costurar(String(lista[id % lista.size()]), ficha)


## As opcoes da conversa, na ordem em que aparecem. A ultima e sempre o
## documento, e a penultima e sempre a saida.
## O assunto do andar 10. So Jota e Helmer sabem dele, e cada um conta a sua
## metade: Jota vende, Helmer conta. O numero do Helmer e a unica coisa exata da
## conversa, que e o papel dele tambem la embaixo (ver PLANTIO).
const SUPER_MACONHA := {
	&"jota": [
		"Essa aqui nao e pra vender na praca nao.",
		"Dois trago e o cliente fica com olho de gato: enxerga no escuro, atravessa o beco sem tropecar no meio-fio.",
		"Tem a linha de cima tambem. Metade dos cliente explode... e pros mais ousado, voam.",
		"Quem voa sempre volta. Nunca no mesmo bairro, mas volta.",
	],
	&"helmer": [
		"Olho de gato e em nove de cada dez. O decimo enxerga som.",
		"A gente ainda nao sabe o que fazer com esse.",
		"Separei por prateleira: explode na de baixo, voa na de cima.",
		"Ja trocou uma vez. Foi um dia comprido.",
	],
}
const SUPER_MACONHA_DE_NOVO := {
	&"jota": ["Ja testei no gato da vizinha. Ficou com olho de gente. Deu errado ao contrario."],
	&"helmer": ["Nao encosta na planta. Ela lembra."],
}
const SUPER_MACONHA_DE_FORA := ["Isso ai e com o Jota e o Helmer. Eu so rego."]

## Quem recebe as doses e sai para entregar. A entrega em si acontece na rua,
## na frente do jogador — ver EntregasDaSuper. Aqui e so o acerto.
const ENTREGAR := {
	&"jota": ["{n} dose. Deixa com a gente.", "Fica de olho na rua. Quando sair a entrega, a gente te chama no celular."],
	&"helmer": ["{n}. Anotado.", "Um de nos leva. Voce assiste da rua, que e onde a coisa acontece."],
}


static func opcoes(ficha: Dictionary,
		contexto: StringName = &"rua") -> Array[Dictionary]:
	var p := Personalidade.de(int(ficha["personalidade"]))
	var id := int(ficha["id"])
	var saida: Array[Dictionary] = []
	# A folha desenha oito linhas (Conversa.MAX_OPCOES) e a estufa ja usa as
	# oito. Com Super no bolso, falando com Jota ou Helmer, o acerto da entrega
	# toma o lugar do bairro — que volta quando o bolso esvazia.
	var dono := RegistroCivil.personagem_de(id)
	var vai_entregar := contexto == &"estufa" 		and (dono == &"jota" or dono == &"helmer") 		and Inventario.tem(EntregasDaSuper.ITEM)
	for chave: StringName in Personalidade.ASSUNTOS_COMUNS:
		if vai_entregar and chave == &"bairro":
			continue
		saida.append({
			"chave": chave,
			"titulo": String(TITULOS[chave]),
			"visto": ja_falou(id, chave),
		})
	# Dentro da casa da fumaca, o assunto do lugar entra ANTES do assunto
	# proprio da pessoa: quem acabou de entrar numa festa pergunta o que esta
	# rolando antes de perguntar da vida de quem abriu a porta.
	if contexto == &"casa":
		saida.append({
			"chave": &"role",
			"titulo": String(TITULOS[&"role"]),
			"visto": ja_falou(id, &"role"),
		})
	if contexto == &"estufa":
		# No andar 10 a lavoura nao esta a vista: a pergunta e a da planta de la.
		var assunto: StringName = &"super" if andar_dez else &"plantio"
		saida.append({
			"chave": assunto,
			"titulo": String(TITULOS[assunto]),
			"visto": ja_falou(id, assunto),
		})
		if vai_entregar:
			saida.append({
				"chave": &"entregar",
				"titulo": String(TITULOS[&"entregar"]),
				"visto": false,
			})
	var proprio: Dictionary = p["proprio"]
	saida.append({
		"chave": &"proprio",
		"titulo": costurar(String(proprio["titulo"]), ficha),
		"visto": ja_falou(id, &"proprio"),
	})
	if contexto == &"volante":
		saida.append({"chave": &"descer", "titulo": TITULO_DESCER,
			"visto": ja_falou(id, &"descer")})
	# Contratar aparece com QUALQUER pessoa de pe, e nao so na estufa. E o que
	# faz a profissao ser um sistema da cidade e nao um detalhe de um comodo: o
	# jogador descobre a aba conversando com alguem na calcada, e so depois
	# entende para que serve quando encontra Jota e Helmer trabalhando.
	#
	# Ao volante, nao. Quem esta sendo tirado do proprio carro por um
	# investigador nao esta em posicao de negociar emprego, e oferecer isso ali
	# faria a cena inteira soar como menu.
	if contexto != &"volante":
		saida.append({"chave": &"servicos",
			"titulo": Profissoes.TITULO_SERVICOS,
			"visto": Profissoes.de(id) != &""})
	saida.append({"chave": &"sair", "titulo": TITULO_SAIR, "visto": false})
	saida.append({"chave": &"documento", "titulo": TITULO_DOCUMENTO,
		"visto": ja_falou(id, &"documento")})
	return saida


## Resposta a um assunto. Repetir o mesmo assunto devolve uma frase curta em vez
## do bloco inteiro: ninguem conta a mesma historia duas vezes com a mesma
## paciencia, e a repeticao literal e o que denuncia caixa de dialogo de jogo.
static func responder(ficha: Dictionary, chave: StringName) -> Array[String]:
	var p := Personalidade.de(int(ficha["personalidade"]))
	var id := int(ficha["id"])
	var repetido := ja_falou(id, chave)
	marcar(id, chave)

	if chave == &"role":
		return _role(p, ficha, repetido)
	if chave == &"plantio":
		return _plantio(ficha)
	if chave == &"entregar":
		var quem_entrega := RegistroCivil.personagem_de(id)
		var n := Inventario.quantidade(EntregasDaSuper.ITEM)
		if n <= 0 or not ENTREGAR.has(quem_entrega):
			return ["Cade? Nao to vendo Super nenhuma com voce."]
		Inventario.remover(EntregasDaSuper.ITEM, n)
		EntregasDaSuper.encomendar(n)
		var falas: Array[String] = []
		for linha: String in ENTREGAR[quem_entrega]:
			falas.append(linha.replace("{n}", str(n)))
		return falas
	if chave == &"super":
		var quem := RegistroCivil.personagem_de(id)
		var tabela: Dictionary = SUPER_MACONHA_DE_NOVO if repetido else SUPER_MACONHA
		var linhas: Array[String] = []
		linhas.assign(tabela.get(quem, SUPER_MACONHA_DE_FORA))
		return linhas
	if chave == &"documento":
		return [costurar(String(p["documento"]), ficha)]
	if chave == &"descer":
		return _descer(p, ficha, repetido)
	if chave == &"sair":
		var adeus: Array = p["despedida"]
		return [costurar(String(adeus[id % adeus.size()]), ficha)]

	if repetido:
		return [_repeticao(p, ficha, chave)]

	if chave == &"proprio":
		var proprio: Dictionary = p["proprio"]
		return _linhas(proprio["linhas"], ficha)
	return _linhas(p[String(chave)], ficha)


## Quao aspera e a pessoa, de 0 a 1.
##
## Nao esta na tabela de temperamentos porque nao e um eixo do sistema de fala:
## e uma leitura que so o transito precisa, e acrescentar um campo em doze
## entradas para uso de um arquivo so seria pior do que ler o nome aqui.
static func aspereza(p: Dictionary) -> float:
	match StringName(p.get("nome", "")):
		&"MANDAO", &"CINICO":
			return 0.9
		&"APRESSADO", &"DESCONFIADO", &"VIGARISTA":
			return 0.72
		&"GENTIL", &"DEVOTO", &"ASSUSTADO", &"MELANCOLICO", &"SONHADOR":
			return 0.2
		_:
			return 0.5


## O que o motorista diz ao ser tirado do proprio carro.
##
## Ninguem entrega o carro contente, e ninguem se recusa: o jogador tem
## credencial. A variacao vem do temperamento e e a unica coisa que diferencia
## um cidadao do outro nessa hora — que e justamente o que a rua precisa mostrar.
static func _descer(p: Dictionary, ficha: Dictionary, repetido: bool) -> Array[String]:
	if repetido:
		return [costurar("Ja desci uma vez. O carro e seu, entao.", ficha)]
	var tom := aspereza(p)
	if tom > 0.66:
		return _linhas([
			"De novo isso. Todo mes e a mesma historia.",
			"Ta bom. Mas anota ai que o carro e meu, {sobrenome}, placa e tudo.",
		], ficha)
	if tom < 0.34:
		return _linhas([
			"Ah... claro, claro. Deixa eu so pegar minha sacola.",
			"Devolve depois, moco. E o que eu tenho.",
		], ficha)
	return _linhas([
		"Investigacao, e? Ta.",
		"Deixo a chave. Nao bate ele, pelo amor de Deus.",
	], ficha)


## O xingamento de dentro do carro. Nao ha palavra: a Voz sintetiza silabas e o
## que identifica a coisa e a cadencia curta e a subida no fim. O texto existe
## so para dar tamanho a fala — quanto mais longo, mais silabas.
static func xingamento(ficha: Dictionary) -> String:
	var id := int(ficha.get("id", 0))
	var p := Personalidade.de(int(ficha.get("personalidade", 0)))
	var lista: Array = [
		"Anda logo!",
		"Vai! Ta esperando o que?!",
		"Que e isso, gente, sai da frente!",
		"Nao acredito nisso...",
		"O sinal ja abriu, meu senhor!",
		"Toda vida a mesma coisa nessa rua!",
	]
	if aspereza(p) > 0.66:
		lista.append("Tira essa lata da minha frente!")
		lista.append("Voce aprendeu a dirigir aonde?!")
	return String(lista[absi(id + int(Time.get_ticks_msec() / 700)) % lista.size()])


## O assunto da casa. Tom pela aspereza, conteudo pelo lugar.
##
## O dono tem bloco proprio e o resto da sala divide tres. Quem pergunta duas
## vezes ouve uma frase curta, como em qualquer outro assunto.
static func _role(p: Dictionary, ficha: Dictionary, repetido: bool) -> Array[String]:
	var id := int(ficha["id"])
	if bool(ficha.get("dono_da_casa", false)):
		if repetido:
			return [costurar("Fica a vontade, {primeiro}.", ficha)]
		return _linhas(ROLE_DONO, ficha)
	if repetido:
		return [costurar("Mesma coisa de sempre. Ninguem vai embora.", ficha)]
	var aspera := aspereza(p)
	var faixa := "neutro"
	if aspera >= 0.7:
		faixa = "aspero"
	elif aspera <= 0.25:
		faixa = "gentil"
	var blocos: Array = ROLE[faixa]
	return _linhas(blocos[id % blocos.size()], ficha)


## Como vai a plantacao. A resposta e o estado de verdade da sala.
##
## `ficha["estufa"]` e um censo — quantos vasos em cada fase — posto ali pelo
## Convidado no instante em que a conversa abre (ver Convidado.abordar). Vem
## por ali e nao de uma consulta daqui porque este arquivo e regra de fala: ele
## nao conhece no, cena nem arvore, e nao vai comecar a conhecer agora.
##
## Repetir a pergunta NAO devolve frase curta, ao contrario de todo o resto: a
## resposta muda com o tempo, e um "ja te falei" sobre uma informacao que
## envelhece seria a unica fala do jogo que piora ao ser util.
static func _plantio(ficha: Dictionary) -> Array[String]:
	var id := int(ficha["id"])
	if not Profissoes.e(id, &"fazendeiro"):
		return [costurar(String(PLANTIO_DE_FORA[id % PLANTIO_DE_FORA.size()]),
			ficha)]
	var censo: Dictionary = ficha.get("estufa", {})
	var faixa := "em_dia"
	var n := 0
	if int(censo.get(&"pronta", 0)) > 0:
		faixa = "pronta"
		n = int(censo[&"pronta"])
	elif int(censo.get(&"sede", 0)) > 0:
		faixa = "sede"
		n = int(censo[&"sede"])
	elif int(censo.get(&"vazio", 0)) > 0:
		faixa = "vazio"
		n = int(censo[&"vazio"])
	var blocos: Array = PLANTIO[faixa]
	var texto := String(blocos[id % blocos.size()])
	return [costurar(texto.replace("{n}", str(n)), ficha)]


static func _repeticao(p: Dictionary, ficha: Dictionary, chave: StringName) -> String:
	match chave:
		&"nevoa":
			return costurar("Ja te falei da nevoa. Nao mudou nada.", ficha)
		&"bairro":
			return costurar("O bairro continua o mesmo. Pior, se muda.", ficha)
		&"voce":
			return costurar("{primeiro} {sobrenome}. Nao vai mudar.", ficha)
		_:
			var adeus: Array = p["despedida"]
			return costurar(String(adeus[0]), ficha)


## Nome que a caixa de fala mostra na fita.
##
## Antes de o jogador perguntar o nome, a pessoa e o que ela aparenta: HOMEM ou
## MULHER e a idade por faixa. Depois de perguntar, passa a ser o nome dela. E a
## diferenca entre povoar a cidade e conhecer alguem.
static func rotulo(ficha: Dictionary) -> String:
	var id := int(ficha["id"])
	# Quem tem apelido e conhecido por ele antes de qualquer pergunta. Jota e
	# Helmer nao sao dois desconhecidos que por acaso estao ali: a casa inteira
	# os chama assim, e o jogador que abre aquela porta ja ouve o nome.
	# A identidade deles continua abrindo e continua trazendo o nome de registro
	# — que e, muitas vezes, a graca de perguntar.
	var apelido := String(ficha.get("apelido", ""))
	if not apelido.is_empty():
		return apelido
	if ja_falou(id, &"voce") or ja_falou(id, &"documento"):
		return String(ficha["nome"])
	var idade := int(ficha["idade"])
	var homem := StringName(ficha["sexo"]) == &"M"
	if idade >= 62:
		return "SENHOR" if homem else "SENHORA"
	if idade <= 24:
		return "RAPAZ" if homem else "MOCA"
	return "HOMEM" if homem else "MULHER"
