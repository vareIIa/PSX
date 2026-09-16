## O que fica DENTRO da casca: porta, banco e console.
##
## Por que isto existe separado da casca
## -------------------------------------
## `CabineCasca` responde "onde estao as paredes", e a resposta sai do perfil da
## lataria — e geometria deduzida. O que esta aqui nao da para deduzir de perfil
## nenhum: maçaneta, manivela, apoio de braco, pino de trava, banco. E o que o
## olho reconhece como CARRO por dentro, e e o que o jogador reportou faltando:
##
##     "no canto inferior esquerdo da janela da esquerda do carro, nao tem a
##      parte de maçaneta do carro, parte interior nao existe e invisivel"
##
## Tudo aqui e colocado em relacao a DUAS medidas que a casca devolve — o
## assoalho e a linha da janela — e nunca em relacao a largura do carro. E o que
## faz o mesmo codigo servir ao Fusca e a picape sem tabela por modelo: o que
## muda entre eles esta em `CabineFicha`.
class_name CabineMoveis
extends RefCounted

# --- celulas do painel_atlas ------------------------------------------------

const C_VINIL := Vector2i(0, 0)
const C_PORTA := Vector2i(3, 0)
const C_CARPETE := Vector2i(4, 0)
const C_FORRO := Vector2i(5, 0)
const C_DIFUSOR := Vector2i(4, 1)
const C_METAL := Vector2i(7, 1)

# --- porta ------------------------------------------------------------------

## Altura das pecas, medida PARA BAIXO a partir da linha da janela. Sao as
## medidas de um carro de verdade: a maçaneta fica logo abaixo do peitoril, ao
## alcance da mao que ja esta no volante, e a manivela bem mais embaixo, na
## altura do cotovelo.
const H_PEITORIL := 0.018
const H_MACANETA := 0.115
const H_APOIO := 0.175
const H_MANIVELA := 0.255

## Onde cada peca fica ao longo da porta, de 0 (frente) a 1 (tras).
const U_MACANETA := 0.13
const U_MANIVELA := 0.30
const U_APOIO := 0.52
const U_TRAVA := 0.93
const U_ALTO_FALANTE := 0.22
const U_BOLSA := 0.62

## Quanto cada peca avanca para dentro da cabine, a partir do forro.
const SAI_PEITORIL := 0.045
const SAI_APOIO := 0.062
const SAI_MACANETA := 0.030
const SAI_MANIVELA := 0.026


## O forro de porta e o que vive nele, de um lado.
##
## `abertura` e o vao da porta dianteira, como `Carroceria` devolve: quatro
## cantos em espaco final, na ordem baixo-frente, baixo-tras, alto-tras,
## alto-frente. `piso` e o assoalho que a casca devolveu.
static func porta(sup: Dictionary, material: StringName, abertura: Dictionary,
		ficha: Dictionary, piso: float, olho: Vector3, info: Dictionary) -> void:
	var pontos: PackedVector3Array = abertura["pontos"]
	if pontos.size() < 4:
		return
	var frente := pontos[0]
	var tras := pontos[1]
	var s := signf(frente.x)
	# O forro mora na parede da casca, e a parede esta recuada para dentro da
	# chapa; o vidro esta colado por FORA dela. Entre um e outro ha a folga do
	# vidro mais o recuo da casca.
	var y_janela := (frente.y + tras.y) * 0.5
	# A parede e perguntada NA ALTURA de cada peca: a secao do carro afina para
	# baixo, e um alto-falante colocado pela largura da linha da janela atravessa
	# a porta por fora.
	var x_parede := CabineCasca.parede_x(info, y_janela,
		(frente.z + tras.z) * 0.5, s)
	var comp := absf(tras.z - frente.z)
	var z_meio := (frente.z + tras.z) * 0.5

	# Peitoril: a faixa horizontal onde o cotovelo apoia, e a borda de cima do
	# forro. E a peca que separa "janela" de "porta" na imagem.
	AtlasKit.caixa(sup, material,
		Vector3(_x_peca(info, y_janela - H_PEITORIL, 0.034, z_meio, s)
			- s * SAI_PEITORIL * 0.5, y_janela - H_PEITORIL, z_meio),
		Vector3(SAI_PEITORIL, 0.034, comp), C_VINIL, ficha["moldura"])

	# Apoio de braco com puxador em cima. Duas pecas, porque e assim que se
	# reconhece um: uma prancha horizontal e um cabo por cima dela.
	if bool(ficha["apoio_braco"]):
		var z_apoio := _u(frente, tras, U_APOIO)
		var x_apoio := _x_peca(info, y_janela - H_APOIO, 0.055, z_apoio, s)
		AtlasKit.caixa(sup, material,
			Vector3(x_apoio - s * SAI_APOIO * 0.5, y_janela - H_APOIO, z_apoio),
			Vector3(SAI_APOIO, 0.055, comp * 0.34), C_PORTA, ficha["porta"])
		AtlasKit.caixa(sup, material,
			Vector3(x_apoio - s * SAI_APOIO * 0.75,
				y_janela - H_APOIO + 0.050, z_apoio),
			Vector3(SAI_APOIO * 0.5, 0.030, comp * 0.24), C_VINIL,
			ficha["moldura"])

	# Maçaneta: uma concha escura afundada no forro e a alavanca dentro dela.
	# Sem a concha a alavanca le como um risco claro solto na porta.
	var z_mac := _u(frente, tras, U_MACANETA)
	var x_mac := _x_peca(info, y_janela - H_MACANETA, 0.075, z_mac, s)
	AtlasKit.face(sup, material, Vector2(0.115, 0.075),
		Transform3D(Basis(Vector3.UP, -s * PI * 0.5),
			Vector3(x_mac - s * 0.004, y_janela - H_MACANETA, z_mac)),
		C_VINIL, Color(0.13, 0.13, 0.13))
	AtlasKit.caixa(sup, material,
		Vector3(x_mac - s * SAI_MACANETA * 0.5, y_janela - H_MACANETA,
			z_mac - 0.012),
		Vector3(SAI_MACANETA, 0.022, 0.080), C_METAL, Color(0.62, 0.62, 0.64))

	# Manivela do vidro: disco e pomo. E o detalhe que data o carro — nenhum
	# carro popular brasileiro desta epoca tinha vidro eletrico.
	if bool(ficha["manivela"]):
		var z_man := _u(frente, tras, U_MANIVELA)
		var x_man := _x_peca(info, y_janela - H_MANIVELA, 0.070, z_man, s)
		AtlasKit.caixa(sup, material,
			Vector3(x_man - s * SAI_MANIVELA * 0.5, y_janela - H_MANIVELA, z_man),
			Vector3(SAI_MANIVELA, 0.070, 0.070), C_VINIL, Color(0.20, 0.20, 0.21))
		AtlasKit.caixa(sup, material,
			Vector3(x_man - s * (SAI_MANIVELA + 0.018),
				y_janela - H_MANIVELA - 0.030, z_man + 0.026),
			Vector3(0.026, 0.026, 0.026), C_VINIL, Color(0.26, 0.26, 0.27))

	# Pino da trava, em pe no peitoril, atras. Dois centimetros de nada que
	# dizem "esta porta tem fechadura".
	var z_trava := _u(frente, tras, U_TRAVA)
	AtlasKit.caixa(sup, material,
		Vector3(_x_peca(info, y_janela + 0.022, 0.052, z_trava, s) - s * 0.030,
			y_janela + 0.022, z_trava),
		Vector3(0.013, 0.052, 0.013), C_METAL, Color(0.58, 0.58, 0.60))

	# Alto-falante e bolsa, na parte de baixo do forro — onde antes nao havia
	# forro nenhum.
	var y_baixo := piso + (y_janela - piso) * 0.30
	if bool(ficha["alto_falante"]):
		var z_alto := _u(frente, tras, U_ALTO_FALANTE)
		AtlasKit.face(sup, material, Vector2(0.135, 0.135),
			Transform3D(Basis(Vector3.UP, -s * PI * 0.5),
				Vector3(_x_peca(info, y_baixo, 0.135, z_alto, s) - s * 0.004,
					y_baixo, z_alto)),
			C_DIFUSOR, Color(0.42, 0.41, 0.40))
	var z_bolsa := _u(frente, tras, U_BOLSA)
	AtlasKit.caixa(sup, material,
		Vector3(_x_peca(info, y_baixo, 0.110, z_bolsa, s) - s * 0.028,
			y_baixo, z_bolsa),
		Vector3(0.050, 0.110, comp * 0.30), C_PORTA,
		Color(ficha["porta"]).darkened(0.25))


# --- bancos -----------------------------------------------------------------

## Os bancos. `z_olho` e onde a cabeca do motorista esta, e e dela que sai a
## posicao do banco: o encosto tem de ficar ATRAS da cabeca, e nao numa medida
## fixa que muda de sentido quando o carro encurta.
static func bancos(sup: Dictionary, material: StringName, ficha: Dictionary,
		piso: float, olho: Vector3, z_tras: float, info: Dictionary) -> void:
	# A largura sai da PAREDE na altura do encosto, e nao da largura do carro:
	# no Fusca a lateral fecha dez centimetros entre a cintura e o assoalho, e
	# um banco dimensionado pela largura cheia atravessa a porta.
	var z_encosto_f := olho.z + 0.42
	var meia := absf(CabineCasca.parede_x(info, piso + 0.50, z_encosto_f, 1.0))
	var largura := clampf(meia * 0.62, 0.30, 0.50)
	var lado := clampf(absf(olho.x), 0.0, meia - largura * 0.5 - 0.02)
	for x: float in [-lado, lado]:
		_banco(sup, material, ficha, x, piso, olho.z + 0.16, z_encosto_f,
			largura)
	if not bool(ficha["banco_tras"]):
		return
	# Banco corrido atras: um so, largo. A traseira aparece pouco, entao ela
	# custa duas caixas e nao seis.
	var z_encosto := lerpf(z_encosto_f, z_tras, 0.72)
	var largura_tras := absf(CabineCasca.parede_x(info, piso + 0.45,
		z_encosto, 1.0)) * 1.72
	AtlasKit.caixa(sup, material,
		Vector3(0.0, piso + 0.22, z_encosto - 0.24),
		Vector3(largura_tras, 0.15, 0.46), C_PORTA, ficha["banco"])
	AtlasKit.caixa(sup, material,
		Vector3(0.0, piso + 0.50, z_encosto),
		Vector3(largura_tras, 0.52, 0.14), C_PORTA, ficha["banco"])


static func _banco(sup: Dictionary, material: StringName, ficha: Dictionary,
		x: float, piso: float, z_assento: float, z_encosto: float,
		largura: float) -> void:
	# Assento, encosto e apoio de cabeca. O encosto inclina para tras: em pe ele
	# le como cadeira de cozinha.
	AtlasKit.caixa(sup, material, Vector3(x, piso + 0.22, z_assento),
		Vector3(largura, 0.15, 0.48), C_PORTA, ficha["banco"])
	AtlasKit.caixa_livre(sup, material,
		Vector3(x, piso + 0.53, z_encosto + 0.03),
		Vector3(largura, 0.60, 0.13), Basis(Vector3.RIGHT, deg_to_rad(-9.0)),
		C_PORTA, ficha["banco"])
	AtlasKit.caixa(sup, material, Vector3(x, piso + 0.88, z_encosto + 0.09),
		Vector3(largura * 0.5, 0.13, 0.11), C_PORTA,
		Color(ficha["banco"]).darkened(0.12))


# --- console ----------------------------------------------------------------

## Tunel central e alavanca de cambio, apoiados no assoalho de verdade.
##
## Antes eles se apoiavam no "piso" falso da altura do capo, e o pomo do cambio
## ficava UM CENTIMETRO abaixo do olho do motorista — na imagem, uma caixinha
## boiando na frente do rosto. Com o assoalho no lugar certo, o pomo cai 43 cm
## abaixo do olho, que e onde a mao procura por ele.
static func console(sup: Dictionary, material: StringName, ficha: Dictionary,
		piso: float, olho: Vector3, z_frente: float, largura: float) -> void:
	var z0 := z_frente + 0.10
	var z1 := olho.z + 0.55
	var comp := maxf(0.4, z1 - z0)
	AtlasKit.caixa(sup, material,
		Vector3(0.0, piso + 0.11, (z0 + z1) * 0.5),
		Vector3(largura, 0.22, comp), C_CARPETE,
		Color(ficha["piso"]).lightened(0.05))
	var z_cambio := olho.z + 0.26
	AtlasKit.caixa(sup, material, Vector3(0.0, piso + 0.32, z_cambio),
		Vector3(0.036, 0.20, 0.036), C_METAL, Color(0.55, 0.55, 0.57))
	AtlasKit.caixa(sup, material, Vector3(0.0, piso + 0.44, z_cambio),
		Vector3(0.068, 0.068, 0.068), C_VINIL, Color(0.22, 0.21, 0.20))


# --- conta ------------------------------------------------------------------

## Onde a parede esta para uma PECA, e nao para um ponto.
##
## A parede afina para baixo, entao uma caixa encostada nela pelo centro fura a
## lateral com a aresta de baixo. A medida que vale e a do ponto mais estreito
## que a peca ocupa: o y de baixo dela.
static func _x_peca(info: Dictionary, y_centro: float, altura: float,
		z: float, s: float) -> float:
	return CabineCasca.parede_x(info, y_centro - altura * 0.5, z, s)


## Um ponto ao longo da porta: 0 na borda da frente, 1 na de tras.
static func _u(frente: Vector3, tras: Vector3, u: float) -> float:
	return lerpf(frente.z, tras.z, u)
