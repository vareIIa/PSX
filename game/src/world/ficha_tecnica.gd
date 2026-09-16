## O que muda de um carro para outro.
##
## Por que este arquivo existe
## ---------------------------
## Porque ate aqui nao mudava nada. Os sete modelos tinham a mesma massa de
## 980 kg, a mesma suspensao, o mesmo atrito de pneu, a mesma curva de torque e o
## mesmo cambio. So a lataria era diferente. Roubar um Fusca e roubar uma picape
## era a mesma coisa com outra silhueta no retrovisor — e num jogo em que o carro
## esta na rua para ser tomado, QUAL carro esta ali e a decisao mais frequente
## que o jogador toma. Se ela nao muda nada, ela nao e uma decisao.
##
## O que cada numero precisa cumprir
## ---------------------------------
## Nenhum numero aqui e enfeite. Cada um tem de aparecer no volante:
##
##   massa            quanto o carro demora a mudar de ideia — sair e parar
##   torque           quanto ele empurra, e de que giro
##   giro             onde a faixa util acaba; muda o conta-giros do painel
##   relacoes         quantas marchas, e quao longas; o Fusca tem QUATRO
##   tracao           de onde vem a forca. Dianteira perdoa, traseira solta o rabo
##   atrito           quanto o pneu segura antes de escorregar
##   rigidez / curso  quanto o carro deita na curva e quanto ele absorve o buraco
##   centro_massa     onde o peso mora. No Fusca ele mora ATRAS, e isso e o Fusca
##   freio            quanto ele para. NAO e opcional depois que a massa variou:
##                    `brake` do Godot e teto de IMPULSO, entao a desaceleracao
##                    e inversamente proporcional a massa. Com um freio unico, o
##                    Fusca de 820 kg parava a 1,7 g com tambor nas quatro
##   arrasto          quanto o ar segura; e o que da a velocidade final
##
## Os numeros sao de carro de rua brasileiro dos anos noventa, arredondados para
## o que a bancada de `TesteCarro` mede — e foi a bancada que os ajustou, nao o
## gosto. As medidas de cada um estao no relatorio de `tools/verificar_carro.py`.
class_name FichaTecnica
extends RefCounted

enum Tracao { DIANTEIRA, TRASEIRA }

## Curva de torque de referencia, em Nm por rpm, para um motor cujo pico e
## `TORQUE_REF` e cujo corte e `GIRO_REF`.
##
## Ha UMA curva, e nao sete. Cada motor a usa esticada: o pico de torque anda
## junto com o corte de giro, entao um motor que gira ate 4700 faz forca maxima
## em 2300 e um que gira ate 7000 faz em 3400. E o comportamento certo — motor de
## giro baixo e motor de giro alto diferem justamente nisso —, e evita sete
## tabelas que ninguem manteria sincronizadas.
const CURVA: Array[Vector2] = [
	Vector2(800.0, 62.0),
	Vector2(1400.0, 104.0),
	Vector2(2200.0, 128.0),
	Vector2(3200.0, 135.0),
	Vector2(4200.0, 133.0),
	Vector2(5200.0, 120.0),
	Vector2(6100.0, 96.0),
	Vector2(6500.0, 78.0),
]
const TORQUE_REF := 135.0
const GIRO_REF := 6500.0

## Cambio de cinco marchas de carro de rua, usado por quem nao declara o proprio.
const RELACOES_PADRAO: Array[float] = [3.45, 1.95, 1.28, 0.97, 0.76]


const CARROS := {
	# O sedan de referencia: 1.8, cansado, sem vicio nenhum. E a regua contra a
	# qual os outros seis sao mais alguma coisa ou menos alguma coisa.
	Carroceria.Modelo.SEDA: {
		"nome": "seda",
		# 0,85 g: disco na frente, tambor atras, pneu de rua.
		"freio": 32.0,
		"massa": 980.0, "torque": 135.0,
		"giro_corte": 6500.0, "giro_vermelho": 5900.0, "giro_fundo": 7000.0,
		"troca_sobe": 6050.0,
		"relacoes": RELACOES_PADRAO, "diferencial": 4.06,
		"tracao": Tracao.DIANTEIRA,
		"atrito": 3.40, "rigidez": 26.0, "curso": 0.14,
		"centro_massa": Vector3(0.0, -0.18, 0.0), "arrasto": 0.45,
	},
	# 1.0 de tres cilindros: nao tem forca nenhuma e compensa girando. Marchas
	# curtas, corte alto, leve. Anda bem na cidade e morre na subida.
	Carroceria.Modelo.HATCH: {
		"nome": "hatch",
		# 0,85 g. Leve, entao precisa de menos freio para a mesma conta.
		"freio": 29.0,
		"massa": 880.0, "torque": 102.0,
		"giro_corte": 6900.0, "giro_vermelho": 6200.0, "giro_fundo": 7500.0,
		"troca_sobe": 6450.0,
		"relacoes": [3.72, 2.05, 1.35, 1.03, 0.82] as Array[float],
		"diferencial": 4.27,
		"tracao": Tracao.DIANTEIRA,
		"atrito": 3.50, "rigidez": 28.0, "curso": 0.13,
		"centro_massa": Vector3(0.0, -0.19, 0.0), "arrasto": 0.42,
	},
	# Perua: o sedan com duzentos quilos de traseira e mola mais macia. Deita na
	# curva, e o centro de massa sobe e recua — e por isso que ela balanca.
	Carroceria.Modelo.PERUA: {
		"nome": "perua",
		# 0,79 g. Peso atras tira aderencia do eixo que mais freia.
		"freio": 34.0,
		"massa": 1120.0, "torque": 138.0,
		"giro_corte": 6300.0, "giro_vermelho": 5700.0, "giro_fundo": 7000.0,
		"troca_sobe": 5850.0,
		"relacoes": RELACOES_PADRAO, "diferencial": 4.06,
		"tracao": Tracao.DIANTEIRA,
		"atrito": 3.25, "rigidez": 22.0, "curso": 0.17,
		"centro_massa": Vector3(0.0, -0.13, 0.06), "arrasto": 0.52,
	},
	# Picape de cacamba vazia. Motor de torque, tracao TRASEIRA e o peso todo na
	# frente: o eixo que empurra e o que tem menos carga em cima, e e por isso
	# que picape vazia sai de lado na chuva. Alta, pesada e com a cara de um
	# armario contra o vento.
	Carroceria.Modelo.PICAPE: {
		"nome": "picape",
		# 0,72 g. Pesada e com traseira leve: a roda de tras tranca.
		"freio": 35.0,
		"massa": 1240.0, "torque": 168.0,
		"giro_corte": 5300.0, "giro_vermelho": 4800.0, "giro_fundo": 6000.0,
		"troca_sobe": 4950.0,
		"relacoes": [3.90, 2.16, 1.38, 1.00, 0.79] as Array[float],
		"diferencial": 4.30,
		"tracao": Tracao.TRASEIRA,
		"atrito": 3.00, "rigidez": 30.0, "curso": 0.19,
		# Peso a frente (-Z e a frente), que e o que deixa a traseira leve.
		"centro_massa": Vector3(0.0, -0.08, -0.12), "arrasto": 0.62,
	},
	# O mesmo sedan com trezentos mil quilometros: motor sem compressao, mola
	# cansada e pneu careca. Nao e mais lento so no papel — ele escorrega antes.
	Carroceria.Modelo.TAXI: {
		"nome": "taxi",
		# 0,75 g. Pastilha e pneu no fim da vida.
		"freio": 30.0,
		"massa": 1030.0, "torque": 110.0,
		"giro_corte": 5800.0, "giro_vermelho": 5200.0, "giro_fundo": 6500.0,
		"troca_sobe": 5350.0,
		"relacoes": RELACOES_PADRAO, "diferencial": 4.06,
		"tracao": Tracao.DIANTEIRA,
		"atrito": 3.05, "rigidez": 21.0, "curso": 0.16,
		"centro_massa": Vector3(0.0, -0.17, 0.0), "arrasto": 0.47,
	},
	# O carro rapido da rua. Motor grande, mola dura, pneu largo, relacao final
	# longa. E o unico da lista que passa dos 190.
	Carroceria.Modelo.MAREA: {
		"nome": "marea",
		# 0,95 g. Quatro discos e pneu largo; o unico que para de verdade.
		"freio": 43.0,
		"massa": 1160.0, "torque": 185.0,
		"giro_corte": 7000.0, "giro_vermelho": 6300.0, "giro_fundo": 7500.0,
		"troca_sobe": 6600.0,
		"relacoes": [3.42, 2.10, 1.36, 1.03, 0.83] as Array[float],
		"diferencial": 3.79,
		"tracao": Tracao.DIANTEIRA,
		"atrito": 3.70, "rigidez": 32.0, "curso": 0.11,
		"centro_massa": Vector3(0.0, -0.22, 0.0), "arrasto": 0.44,
	},
	# Fusca: motor ATRAS, tracao traseira, QUATRO marchas e giro baixo. O peso
	# no rabo e a coisa toda — e o que o faz sair de traseira na curva e o que
	# faz a direcao ficar leve. Pneu estreito, mola alta e macia.
	Carroceria.Modelo.FUSCA: {
		"nome": "fusca",
		# 0,60 g. TAMBOR nas quatro e pneu estreito. Ele nao para, ele reza.
		"freio": 19.0,
		"massa": 820.0, "torque": 78.0,
		"giro_corte": 4700.0, "giro_vermelho": 4200.0, "giro_fundo": 5000.0,
		"troca_sobe": 4350.0,
		"relacoes": [3.80, 2.06, 1.32, 0.89] as Array[float],
		"diferencial": 4.375,
		"tracao": Tracao.TRASEIRA,
		"atrito": 2.85, "rigidez": 17.0, "curso": 0.21,
		# +Z e a traseira: e onde mora o motor, e e onde mora o problema.
		"centro_massa": Vector3(0.0, -0.12, 0.22), "arrasto": 0.62,
	},
}


## A ficha de um modelo. Modelo desconhecido devolve a do sedan, que e a regua.
static func de(modelo: Carroceria.Modelo) -> Dictionary:
	return CARROS.get(modelo, CARROS[Carroceria.Modelo.SEDA])


## Torque no virabrequim, em Nm, para um motor com este pico e este corte.
##
## A curva de referencia e esticada nos dois eixos: no vertical pelo torque de
## pico, no horizontal pelo corte de giro. Esticar o eixo do giro e o que faz
## um motor de 4700 rpm ter o pico em 2300 e um de 7000 ter em 3400 — sem isso,
## todo motor da cidade teria a mesma faixa boa e a diferenca entre eles seria
## so de volume.
static func torque(rpm: float, torque_pico: float, giro_corte: float) -> float:
	var ref := rpm * (GIRO_REF / maxf(1.0, giro_corte))
	return _na_curva(ref) * (torque_pico / TORQUE_REF)


static func _na_curva(rpm: float) -> float:
	if rpm <= CURVA[0].x:
		return CURVA[0].y
	for k in range(1, CURVA.size()):
		if rpm <= CURVA[k].x:
			var a := CURVA[k - 1]
			var b := CURVA[k]
			return lerpf(a.y, b.y, (rpm - a.x) / maxf(1.0, b.x - a.x))
	return CURVA[CURVA.size() - 1].y
