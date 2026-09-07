## Assuntos do morador, e a regra de qual sai em cada conversa.
##
## Nao e arvore de dialogo com escolha. E uma fila de assuntos com condicao: o
## jogo entrega o primeiro que ainda nao foi dito e cuja condicao vale agora, e
## quando acabam todos ele passa a repetir frases curtas. Duas razoes:
##
##   - Escolha de fala pede consequencia, e consequencia que nao existe e pior
##     que nao ter escolha nenhuma.
##   - O que muda a conversa e o que o jogador carrega e ja viu, nao o que ele
##     clica. Falar do bilhete so depois de achar o bilhete faz o morador
##     parecer atento ao mundo, com uma linha de codigo.
##
## Por que ha quatro arcos
## -----------------------
## Havia um: toda casa da cidade tinha o mesmo senhor contando a mesma historia
## da mesma filha. A segunda casa em que o jogador entrava desmontava a primeira,
## porque revelava que aquilo nao era uma pessoa — era o cenario falando.
##
## Agora o arco vem do perfil que CasaBuilder sorteou para a casa, e o perfil ja
## decidiu o movel. A sala com caixas fechadas e a fala de quem esta indo embora
## sao a mesma decisao vista de dois lugares, e e por isso que combinam: nao ha
## sorteio separado que possa discordar.
##
## O nome, a idade e a profissao saem da ficha do RegistroCivil — a mesma
## carteira que sai na rua. Ninguem aqui e escrito a mao.
class_name FalasMorador
extends RefCounted

## O que cada perfil entrega no fim da primeira conversa. Dar alguma coisa e o
## que separa personagem de cartaz falante, e o objeto diz quem e a pessoa tao
## bem quanto a fala: quem esta de mudanca tem pilha sobrando, quem mora sozinho
## ha quarenta anos tem remedio.
const PRESENTE_DO_PERFIL := {
	0: &"remedio",    # FAMILIA
	1: &"remedio",    # IDOSO
	2: &"bateria",    # MUDANCA
	3: &"bandagem",   # ALUGADO
}

## Assuntos comuns a todo mundo. Sao sobre a NEVOA e sobre o radio, que sao do
## jogo e nao da pessoa: qualquer um que more nesta cidade sabe destas duas
## coisas, e e o que faz quatro moradores diferentes parecerem a mesma cidade.
const COMUNS: Array[Dictionary] = [
	{
		"chave": &"nevoa", "quando": &"sempre",
		"linhas": [
			"Comecou na terca, no fim da rua, perto da escola.",
			"No segundo dia ja estava encostada na minha janela.",
			"Mas nao passa da janela. Nunca passou.",
			"Enquanto a luz estiver acesa ela fica do lado de fora.",
			"Eu nao sei por que. So sei que e assim.",
		],
	},
	{
		"chave": &"radio", "quando": &"tem_radio",
		"linhas": [
			"Esse aparelho no seu cinto. Deixe ligado.",
			"O chiado nao e defeito. Ele chia quando tem alguma coisa perto.",
			"Quanto mais forte, mais perto.",
			"E se ele parar de chiar de repente, corra. Nao olhe para tras. Corra.",
		],
	},
	{
		"chave": &"bilhete", "quando": &"tem_bilhete",
		"linhas": [
			"Onde voce achou esse papel?",
			"...E a letra de alguem desta casa. Eu conheco.",
			"Fique com ele.",
			"Eu ja sei o que diz. Faz tres dias que eu sei.",
		],
	},
]

## Os arcos, na ordem do enum CasaBuilder.Perfil. Cada um abre com `chegada`,
## que e a conversa que paga o presente, e fecha com o assunto da porta trancada
## — porque a porta trancada existe em todas as plantas e ficaria sem
## explicacao em tres delas.
##
## `{nome}` e `{primeiro}` sao trocados pela ficha antes de a caixa abrir.
const ARCOS: Array[Array] = [
	# --- FAMILIA -------------------------------------------------------------
	[
		{
			"chave": &"chegada", "quando": &"sempre",
			"linhas": [
				"A porta estava destrancada? ...Eu pedi para ele trancar.",
				"Nao, fique ai. Fique onde eu posso ver.",
				"Minha mulher levou o menino para a casa da mae dela na quarta.",
				"Eu fiquei porque alguem tinha que ficar. E a nossa casa.",
				"{primeiro}. Moro aqui ha onze anos.",
				"Leve isto. Aqui em casa tem de sobra e voce esta com a cara ruim.",
			],
		},
		{
			"chave": &"porta", "quando": &"sempre",
			"linhas": [
				"O quarto no fim do corredor e do menino.",
				"Esta trancado porque eu tranquei.",
				"Enquanto estiver do jeito que ele deixou, ele volta.",
				"Deixe a porta como esta.",
			],
		},
	],
	# --- IDOSO ---------------------------------------------------------------
	[
		{
			"chave": &"chegada", "quando": &"sempre",
			"linhas": [
				"A porta estava destrancada?",
				"...Eu tranquei. Tenho certeza de que tranquei.",
				"Nao, nao. Fique onde esta. Fique.",
				"Faz tres dias que eu nao vejo ninguem de pe.",
				"{primeiro}. Eu moro aqui desde antes da rua ficar assim.",
				"Voce nao devia andar la fora com essa neblina.",
				"Ela nao e neblina. Leve isto. Eu ja nao ando o bastante para precisar.",
			],
		},
		{
			"chave": &"porta", "quando": &"sempre",
			"linhas": [
				"O quarto no fim do corredor esta trancado.",
				"Minha filha dormia ali.",
				"Nao me pergunte mais que isso.",
				"Deixe a porta como esta.",
			],
		},
	],
	# --- MUDANCA -------------------------------------------------------------
	[
		{
			"chave": &"chegada", "quando": &"sempre",
			"linhas": [
				"Se voce veio pelas caixas, o caminhao nao vem mais.",
				"Liguei tres vezes. Na terceira a linha so chiou.",
				"{primeiro}. Eu ia embora sexta.",
				"Metade da minha vida esta fechada com fita ali no canto.",
				"A outra metade eu ja nao sei onde deixei.",
				"Toma. Pilha nova, estava na caixa da cozinha. Nao me serve de nada agora.",
			],
		},
		{
			"chave": &"porta", "quando": &"sempre",
			"linhas": [
				"Aquele quarto eu ja esvaziei. Nao tem nada la.",
				"Tranquei quando terminei. Achei que ia ser a ultima vez.",
				"Nao abra. Se eu abrir de novo eu vou ter que embalar tudo outra vez.",
			],
		},
	],
	# --- ALUGADO -------------------------------------------------------------
	[
		{
			"chave": &"chegada", "quando": &"sempre",
			"linhas": [
				"Opa. Voce e do predio? ...Nao, voce nao e daqui.",
				"Foi mal a bagunca. Eu ia arrumar hoje.",
				"{primeiro}. Eu alugo o quarto da frente, a dona mora no fundo.",
				"Ela nao sai do quarto desde terca. Bate na porta e nao responde.",
				"Eu nao vou entrar la. Nao mesmo.",
				"Pega isso. Achei na gaveta do banheiro, deve servir mais pra voce.",
			],
		},
		{
			"chave": &"porta", "quando": &"sempre",
			"linhas": [
				"O quarto do fundo e o dela. Nunca foi meu.",
				"Eu bati. Eu chamei. Eu escutei ela andar la dentro.",
				"Depois parou de andar.",
				"Deixa quieto.",
			],
		},
	],
]

## Quando os assuntos acabam. Curtas de proposito: conversa longa repetida
## ensina o jogador a nao falar mais com ele.
const REPETICAO: Array[String] = [
	"A luz ainda esta acesa. Enquanto estiver, estamos bem.",
	"Beba agua antes de sair. Voce esta com a cara ruim.",
	"Nao va para a escola depois que escurecer.",
	"Fique mais um pouco, se quiser. A casa e grande demais.",
	"Se voce ouvir uma sirene, nao e socorro.",
]


## Coordenada do estado deste morador. Interiores nao tem coordenada de chunk,
## entao usam a faixa reservada do WorldState.
static func _coord(semente: int) -> Vector2i:
	return Vector2i(semente, WorldState.INTERIOR)


static func _ja_disse(semente: int, chave: StringName) -> bool:
	return bool(WorldState.obter(_coord(semente), StringName("falou_%s" % chave), false))


static func _vale(quando: StringName) -> bool:
	match quando:
		&"tem_radio":
			return Inventario.tem(&"radio")
		&"tem_bilhete":
			return Inventario.tem(&"bilhete")
		_:
			return true


## A fila deste morador: o arco do perfil dele primeiro, os assuntos comuns
## depois. A ordem importa — quem acabou de abrir a porta fala de si antes de
## falar do tempo.
static func _fila(perfil: int) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var arco: Array = ARCOS[clampi(perfil, 0, ARCOS.size() - 1)]
	for bloco: Variant in arco:
		var d: Dictionary = bloco
		saida.append(d)
	for bloco: Dictionary in COMUNS:
		saida.append(bloco)
	return saida


## Troca os marcadores pela ficha. Sem ficha as linhas saem como estao, com um
## nome generico: um morador sem registro ainda tem de conseguir falar.
static func _pessoal(linhas: Array, ficha: Dictionary) -> Array:
	var primeiro := String(ficha.get("primeiro", "Nao importa"))
	var nome := String(ficha.get("nome", primeiro))
	var saida: Array = []
	for bruta: Variant in linhas:
		var linha: String = bruta
		saida.append(linha.replace("{primeiro}", primeiro).replace("{nome}", nome))
	return saida


## Proximo assunto. Devolve `{chave, linhas}`; a chave volta em `concluir`.
static func proxima(semente: int, ficha: Dictionary = {},
		perfil: int = 0) -> Dictionary:
	for bloco: Dictionary in _fila(perfil):
		var chave: StringName = bloco["chave"]
		if _ja_disse(semente, chave) or not _vale(bloco["quando"]):
			continue
		return {
			"chave": chave,
			"linhas": _pessoal(bloco["linhas"] as Array, ficha),
		}

	# Acabaram os assuntos: uma frase por vez, girando.
	var i := int(WorldState.obter(_coord(semente), &"repeticao", 0))
	return {
		"chave": &"repeticao",
		"linhas": [REPETICAO[i % REPETICAO.size()]] as Array,
	}


## Fecha o assunto: marca como dito e paga o que ele tiver a pagar.
static func concluir(semente: int, chave: StringName, perfil: int = 0) -> void:
	var coord := _coord(semente)
	if chave == &"repeticao":
		WorldState.definir(coord, &"repeticao",
			int(WorldState.obter(coord, &"repeticao", 0)) + 1)
		return

	WorldState.definir(coord, StringName("falou_%s" % chave), true)

	if chave == &"chegada":
		var presente: StringName = PRESENTE_DO_PERFIL.get(
			clampi(perfil, 0, 3), &"remedio")
		# Se a bolsa estiver cheia o presente nao some: o assunto volta a ficar em
		# aberto e ele oferece de novo na proxima conversa. Um item que evapora
		# porque o jogador estava carregando bala demais e roubo silencioso.
		if Inventario.adicionar(presente) > 0:
			WorldState.definir(coord, &"falou_chegada", false)
