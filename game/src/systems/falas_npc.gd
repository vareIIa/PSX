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
}


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
static func opcoes(ficha: Dictionary,
		contexto: StringName = &"rua") -> Array[Dictionary]:
	var p := Personalidade.de(int(ficha["personalidade"]))
	var id := int(ficha["id"])
	var saida: Array[Dictionary] = []
	for chave: StringName in Personalidade.ASSUNTOS_COMUNS:
		saida.append({
			"chave": chave,
			"titulo": String(TITULOS[chave]),
			"visto": ja_falou(id, chave),
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
	if ja_falou(id, &"voce") or ja_falou(id, &"documento"):
		return String(ficha["nome"])
	var idade := int(ficha["idade"])
	var homem := StringName(ficha["sexo"]) == &"M"
	if idade >= 62:
		return "SENHOR" if homem else "SENHORA"
	if idade <= 24:
		return "RAPAZ" if homem else "MOCA"
	return "HOMEM" if homem else "MULHER"
