## As variedades da estufa: uma por andar do poco, cada uma crescendo do seu
## jeito.
##
## Regra pura, como a `Plantio`: nada de no nem de recurso, porque quem pergunta
## e a thread que monta a estufa, a `Plantacao` que desenha e a conta de
## ausencia que colhe sem ninguem olhando. Os tres tem de concordar sobre o que
## cresce em cada andar, e so concordam se a resposta mora num lugar so.
##
## Por que uma por andar
## ---------------------
## O poco tem dez andares e a lista pintada no elevador dava nome a cada um. Um
## andar que so tem nome e piada contada uma vez; um andar com uma planta que
## so existe ali e uma razao para descer. A variedade CASA com a placa: o 2 e a
## SECAGEM, e a Morcega cresce de cabeca para baixo, pendurada do forro como
## ramo secando; o 8 e o ANDAR DO CHEIRO, e a Gambazona e cola pura; o 9 e o
## apagado, e a Vagalume acende no escuro.
##
## A forma e do KitEstufa (`variedade`); o item colhido, com nome, icone e
## modelo, e de resources/itens. Aqui so o que liga um ao outro.
class_name Variedades
extends RefCounted

## O andar de cada variedade. O 1 e a lavoura, e o 10 e o quarto da planta
## gigante (SuperQuarto), que nao e canteiro.
const DO_ANDAR := {
	1: &"comum",
	2: &"morcega",
	3: &"bonsai",
	4: &"saca_rolha",
	5: &"girafa",
	6: &"pompom",
	7: &"chorona",
	8: &"gambazona",
	9: &"vagalume",
}

## `minutos`: relogio do primeiro gole a colheita (a lavoura e 12, ver
## Plantio.MINUTOS_ATE_MADURA). `rende`: quanto uma planta da. `cor`: o tom da
## variedade (rotulo, pote, icone, a luz do andar). `nome` e `descricao` vao
## para o item.
const DADOS := {
	&"comum": {
		"nome": "Maconha", "item": &"maconha", "minutos": 12.0, "rende": 3,
		"cor": Color(0.42, 0.62, 0.26),
		"forma": "O pe de sempre: pinheiro de Natal de folha em leque.",
	},
	&"morcega": {
		"nome": "Morcega", "item": &"erva_morcega", "minutos": 14.0, "rende": 3,
		"cor": Color(0.55, 0.42, 0.62),
		"forma": "Cresce de cabeca para baixo, do vaso pendurado no forro ate "
			+ "quase o chao. A cola aponta para o piso.",
		"descricao": "Do andar da secagem. Ja nasce pendurada: pula uma etapa.",
	},
	&"bonsai": {
		"nome": "Bonsai do Jota", "item": &"erva_bonsai", "minutos": 20.0, "rende": 2,
		"cor": Color(0.78, 0.52, 0.30),
		"forma": "Arvore velha em miniatura: tronco grosso e torto, copa em "
			+ "nuvens chatas, trinta centimetros de altura. Numa bandeja rasa.",
		"descricao": "Trinta centimetros de planta e vinte minutos de paciencia. "
			+ "O Jota fala com ela.",
	},
	&"saca_rolha": {
		"nome": "Saca-Rolha", "item": &"erva_saca_rolha", "minutos": 11.0, "rende": 3,
		"cor": Color(0.30, 0.68, 0.64),
		"forma": "O caule sobe em espiral, uma mola, com as folhas saindo por "
			+ "fora da volta e as colas enroladas no alto.",
		"descricao": "O caule sobe em mola. Quem fuma diz que a ideia tambem.",
	},
	&"girafa": {
		"nome": "Girafa", "item": &"erva_girafa", "minutos": 9.0, "rende": 2,
		"cor": Color(0.92, 0.74, 0.28),
		"forma": "Pescoco fino e altissimo ate bater no forro, e ai dobra e "
			+ "corre deitada por baixo dele; as folhas so la em cima.",
		"descricao": "Cresce rapido, alto e burro: bate no teto e continua.",
	},
	&"pompom": {
		"nome": "Pompom", "item": &"erva_pompom", "minutos": 13.0, "rende": 4,
		"cor": Color(0.92, 0.46, 0.62),
		"forma": "Topiaria: uma bola perfeita de folha em cima de um palito, "
			+ "pirulito de jardim, com as colas espetadas na bola.",
		"descricao": "Redonda de nascenca. Ninguem poda.",
	},
	&"chorona": {
		"nome": "Chorona", "item": &"erva_chorona", "minutos": 15.0, "rende": 3,
		"cor": Color(0.40, 0.50, 0.80),
		"forma": "Salgueiro: os galhos sobem e caem em cortina ate o chao, "
			+ "cheios de folha pendurada.",
		"descricao": "Do andar que nao se desce (serio). Chora e ninguem sabe por que.",
	},
	&"gambazona": {
		"nome": "Gambazona", "item": &"erva_gambazona", "minutos": 18.0, "rende": 5,
		"cor": Color(0.62, 0.78, 0.22),
		"forma": "Quase so cola: botoes gordos maiores que as folhas, que sao "
			+ "poucas. Solta fumaca verde.",
		"descricao": "O andar do cheiro tem um motivo, e e este.",
	},
	&"vagalume": {
		"nome": "Vagalume", "item": &"erva_vagalume", "minutos": 16.0, "rende": 2,
		"cor": Color(0.36, 0.92, 0.86),
		"forma": "Folha roxa quase preta e colas que acendem no escuro, "
			+ "azul-verde, como pisca-pisca.",
		"descricao": "Do andar apagado. Brilha no escuro, e voce tambem.",
	},
}


## Os vasos, na ordem da `Plantio`: os 24 da lavoura primeiro (o save antigo ja
## tem esses, e eles continuam onde estavam) e depois 41 por galeria, do 2 ao
## 9 (EstufaBuilder.vasos_da_galeria). Quem monta a sala (EstufaBuilder.lugares_todos) e quem conta o tempo
## (Plantio) leem a mesma conta.
const VASOS_DA_LAVOURA := 24
const VASOS_POR_ANDAR := 41
const ANDARES_DE_GALERIA := 8


static func total_de_vasos() -> int:
	return VASOS_DA_LAVOURA + VASOS_POR_ANDAR * ANDARES_DE_GALERIA


## O andar do vaso `i`: 1 na lavoura, 2 a 9 nas galerias.
static func andar_do_vaso(i: int) -> int:
	if i < VASOS_DA_LAVOURA:
		return 1
	return 2 + (i - VASOS_DA_LAVOURA) / VASOS_POR_ANDAR


static func do_vaso(i: int) -> StringName:
	return do_andar(andar_do_vaso(i))


static func do_andar(andar: int) -> StringName:
	return DO_ANDAR.get(andar, &"comum")


static func dados(v: StringName) -> Dictionary:
	return DADOS.get(v, DADOS[&"comum"])


static func item(v: StringName) -> StringName:
	return dados(v)["item"]


static func nome(v: StringName) -> String:
	return dados(v)["nome"]


static func minutos(v: StringName) -> float:
	return float(dados(v)["minutos"])


static func rende(v: StringName) -> int:
	return int(dados(v)["rende"])


static func cor(v: StringName) -> Color:
	return dados(v)["cor"]


## Todas as variedades menos a comum, na ordem dos andares. E a lista dos
## itens novos.
static func especiais() -> Array[StringName]:
	var saida: Array[StringName] = []
	for andar: int in range(2, 10):
		saida.append(do_andar(andar))
	return saida
