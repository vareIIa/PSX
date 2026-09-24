## O que a pessoa diz e faz quando e esbarrada, derrubada ou atropelada.
##
## Separado de `Personalidade` porque nao e conversa: sao gritos de rua, uma
## palavra ou duas, ditas sem o jogador ter pedido. E porque a reacao depois do
## tombo tambem e do temperamento: o mandao levanta e vem tirar satisfacao, o
## assustado levanta e corre, o bebado nem sabe direito o que houve.
##
## Os indices seguem `Personalidade.LISTA` (DESCONFIADO=0 ... VIGARISTA=11).
class_name FalasTombo
extends RefCounted

enum Depois { ENFRENTA, FOGE, ATORDOADO }

## O que cada temperamento faz depois de levantar.
const DEPOIS: Array[Depois] = [
	Depois.ENFRENTA,   # DESCONFIADO
	Depois.ATORDOADO,  # TAGARELA
	Depois.FOGE,       # APRESSADO
	Depois.ATORDOADO,  # MELANCOLICO
	Depois.ATORDOADO,  # GENTIL
	Depois.ATORDOADO,  # BEBADO
	Depois.ATORDOADO,  # DEVOTO
	Depois.ENFRENTA,   # CINICO
	Depois.FOGE,       # ASSUSTADO
	Depois.ENFRENTA,   # MANDAO
	Depois.ATORDOADO,  # SONHADOR
	Depois.ENFRENTA,   # VIGARISTA
]

## Esbarrao que so balancou ou fez tropecar.
const ESBARRAO := [
	["Olha por onde anda!", "Ei!"],
	["Opa! Tudo bem, tudo bem.", "Nossa!"],
	["Sai da frente!", "To atrasado!"],
	["...", "Hm."],
	["Desculpa! Ah, foi voce.", "Opa, perdao."],
	["Uooa... quem mexeu no chao?", "Calma, calma."],
	["Deus me livre.", "Ai, Senhor."],
	["Legal. Muito legal.", "Parabens."],
	["Ai! Nao, nao!", "Nao me machuca!"],
	["Ta cego?!", "Olha o respeito!"],
	["Oh... desculpa, eu tava longe.", "Hm?"],
	["Opa, opa, devagar, amigo.", "Cuidado com a carteira."],
]

## Depois de cair, ao levantar.
const LEVANTANDO := [
	["Voce vai pagar isso.", "Eu vi sua cara."],
	["Ai, minhas costas... alguem viu isso?", "Eu to bem. Eu acho."],
	["Que dia. Que DIA.", "Nao tenho tempo pra isso."],
	["Claro. Claro que ia ser comigo.", "..."],
	["Ai... ta tudo bem. Ta tudo bem.", "Voce ta bem?"],
	["Eu... eu tava deitado aqui?", "Quem apagou a luz?"],
	["Obrigado, Senhor, to inteiro.", "Deus castiga."],
	["Otimo. Otimo.", "Isso foi de proposito, ne?"],
	["Socorro!", "Me deixa em paz!"],
	["Volta aqui!", "Voce sabe com quem ta falando?"],
	["As estrelas... eram estrelas?", "Que coisa."],
	["Isso vai custar caro, amigo.", "Eu tenho testemunha."],
]

## Atropelado: o grito na hora da pancada.
const PANCADA := ["Ai!", "Aaah!", "Uff!", "Ai, meu Deus!"]


## No chao, gemendo. A marca [dor] segura a careta durante a linha.
const GEMIDO := ["[dor]Aaai...", "[dor]Ai, ai...", "[dor]Uuh...", "[dor]Minha perna...",
	"[dor]Ai, meu Deus...", "[dor]Hmm...", "[dor]Alguem me ajuda..."]

## Papo de rua entre dois pedestres. Ninguem le (nao tem legenda): serve para a
## boca, a voz e o gesto andarem com silabas de verdade, e nao com um murmurio
## sem forma.
const PAPO := ["Rapaz, voce viu isso?", "Ta caro demais, ne.", "Ele falou que vinha.",
	"Nao sei nao...", "E o jogo ontem?", "Vou ver amanha cedo.", "Olha, eu acho que sim.",
	"Minha mae ta boa, gracas a Deus.", "Que calor, hein!", "Vai chover hoje?",
	"Cara, eu nem te conto.", "Pois e, pois e.", "Sei la, viu.", "Mas que coisa!"]


static func gemido(id: int) -> String:
	return String(GEMIDO[absi(id * 7 + Time.get_ticks_msec() / 1300) % GEMIDO.size()])


static func papo(id: int) -> String:
	return String(PAPO[absi(id * 13 + Time.get_ticks_msec() / 700) % PAPO.size()])


static func esbarrao(personalidade: int, id: int) -> String:
	return _escolher(ESBARRAO, personalidade, id)


static func levantando(personalidade: int, id: int) -> String:
	return _escolher(LEVANTANDO, personalidade, id)


static func pancada(id: int) -> String:
	return String(PANCADA[absi(id + Time.get_ticks_msec() / 997) % PANCADA.size()])


static func depois(personalidade: int) -> Depois:
	return DEPOIS[clampi(personalidade, 0, DEPOIS.size() - 1)]


static func _escolher(tabela: Array, personalidade: int, id: int) -> String:
	var linhas: Array = tabela[clampi(personalidade, 0, tabela.size() - 1)]
	# Alterna pela hora e pela pessoa: a mesma pessoa nao repete a mesma frase
	# duas vezes seguidas.
	return String(linhas[absi(id + Time.get_ticks_msec() / 1500) % linhas.size()])
