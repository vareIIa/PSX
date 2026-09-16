## O que muda de um interior para outro.
##
## Por que isto existe
## -------------------
## A `CarroCabine` nasceu para UM carro — o Marea da Estrada Velha — e desenha o
## mesmo painel escuro para os sete modelos. Assim que o interior for do carro
## que o jogador dirige na cidade (Fase 6 do PLANO_CHUVA_CABINE_AAA), sentar num
## Fusca e sentar num sedan tem de ser coisas diferentes, e a diferenca nao pode
## virar `if modelo ==` espalhado por dez funcoes de geometria.
##
## Aqui e so TABELA. Quem desenha le daqui.
##
## O que separa os tres interiores
## -------------------------------
##   Fusca    painel de CHAPA na cor da lataria, sem console, piso de borracha,
##            manivela de vidro, banco de vinil claro. E um carro de 1970.
##   Marea    painel de plastico dos anos 90, console com radio, tecido no
##            banco. E o carro da abertura.
##   Caixas   sedan, hatch, perua, picape e taxi: painel reto dos anos 80,
##            console baixo, tecido escuro.
class_name CabineFicha
extends RefCounted

## Cor do forro de porta, do teto, do painel e do banco. Sao os tons de
## SILHUETA que `CarroCabine._laterais` ja tinha calibrado contra a print
## noturna: interior claro vira uma barra brilhante no meio do quadro e disputa
## atencao com a estrada.
const PADRAO := {
	"porta": Color(0.30, 0.29, 0.28),
	"forro": Color(0.26, 0.25, 0.24),
	"teto": Color(0.27, 0.26, 0.25),
	"piso": Color(0.22, 0.21, 0.20),
	"banco": Color(0.28, 0.27, 0.26),
	"moldura": Color(0.24, 0.23, 0.22),
	## Painel na cor da lataria, como em carro de chapa exposta.
	"painel_na_lataria": false,
	## Manivela de vidro em vez de botao. Todo carro desta epoca tem.
	"manivela": true,
	## Alto-falante no forro da porta. O Fusca de serie nao tinha.
	"alto_falante": true,
	## Apoio de braco com puxador.
	"apoio_braco": true,
	## Banco traseiro. A picape nao tem.
	"banco_tras": true,
}

const FICHAS := {
	Carroceria.Modelo.FUSCA: {
		"painel_na_lataria": true,
		"alto_falante": false,
		"apoio_braco": false,
		"porta": Color(0.34, 0.32, 0.30),
		"banco": Color(0.33, 0.31, 0.29),
		"piso": Color(0.19, 0.18, 0.18),
	},
	Carroceria.Modelo.PICAPE: {
		"banco_tras": false,
	},
	Carroceria.Modelo.TAXI: {
		# Taxi roda o dia inteiro: forro mais surrado, banco mais claro de tanto
		# uso. E a unica pista de interior que o jogador tem de que aquele carro
		# trabalha.
		"porta": Color(0.27, 0.26, 0.25),
		"banco": Color(0.31, 0.30, 0.28),
	},
}


## A ficha de um modelo, com os campos que faltam vindos do padrao.
static func de(modelo: int) -> Dictionary:
	var f := PADRAO.duplicate()
	if FICHAS.has(modelo):
		for k: String in FICHAS[modelo]:
			f[k] = FICHAS[modelo][k]
	return f
