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
class_name FalasMorador
extends RefCounted

const NOME := "SR. WATANABE"

## Item que ele entrega no fim da primeira conversa. Dar alguma coisa e o que
## separa personagem de cartaz falante.
const PRESENTE := &"remedio"

## `quando` diz o que precisa valer para o assunto entrar na fila.
##   sempre        disponivel desde o inicio
##   tem_radio     so depois de o jogador estar com o radio
##   tem_bilhete   so depois de achar um bilhete
const CONVERSAS: Array[Dictionary] = [
	{
		"chave": &"chegada", "quando": &"sempre",
		"linhas": [
			"A porta estava destrancada?",
			"...Eu tranquei. Tenho certeza de que tranquei.",
			"Nao, nao. Fique onde esta. Fique.",
			"Faz tres dias que eu nao vejo ninguem de pe.",
			"Watanabe. Eu moro aqui desde antes da rua ficar assim.",
			"Voce nao devia andar la fora com essa neblina.",
			"Ela nao e neblina. Leve isto. Eu ja nao ando o bastante para precisar.",
		],
	},
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
		"chave": &"porta", "quando": &"sempre",
		"linhas": [
			"O quarto no fim do corredor esta trancado.",
			"Minha filha dormia ali.",
			"Nao me pergunte mais que isso.",
			"Deixe a porta como esta.",
		],
	},
	{
		"chave": &"bilhete", "quando": &"tem_bilhete",
		"linhas": [
			"Onde voce achou esse papel?",
			"...E a letra dela. Ela cortava os setes assim, no meio.",
			"Fique com ele.",
			"Eu ja sei o que diz. Faz tres dias que eu sei.",
		],
	},
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


## Proximo assunto. Devolve `{chave, linhas}`; a chave volta em `concluir`.
static func proxima(semente: int) -> Dictionary:
	for bloco: Dictionary in CONVERSAS:
		var chave: StringName = bloco["chave"]
		if _ja_disse(semente, chave) or not _vale(bloco["quando"]):
			continue
		return {"chave": chave, "linhas": (bloco["linhas"] as Array).duplicate()}

	# Acabaram os assuntos: uma frase por vez, girando.
	var i := int(WorldState.obter(_coord(semente), &"repeticao", 0))
	return {
		"chave": &"repeticao",
		"linhas": [REPETICAO[i % REPETICAO.size()]] as Array,
	}


## Fecha o assunto: marca como dito e paga o que ele tiver a pagar.
static func concluir(semente: int, chave: StringName) -> void:
	var coord := _coord(semente)
	if chave == &"repeticao":
		WorldState.definir(coord, &"repeticao",
			int(WorldState.obter(coord, &"repeticao", 0)) + 1)
		return

	WorldState.definir(coord, StringName("falou_%s" % chave), true)

	if chave == &"chegada":
		# Se a bolsa estiver cheia o presente nao some: o assunto volta a ficar em
		# aberto e ele oferece de novo na proxima conversa. Um item que evapora
		# porque o jogador estava carregando bala demais e roubo silencioso.
		if Inventario.adicionar(PRESENTE) > 0:
			WorldState.definir(coord, &"falou_chegada", false)
