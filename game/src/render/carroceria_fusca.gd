## O Fusca. Um perfil varrido, e nao uma pilha de caixas.
##
## Os outros carros da Carroceria sao caixas chanfradas porque um sedan generico
## E uma caixa: a silhueta dele nao guarda informacao que valha triangulo. A do
## Fusca guarda tudo. A coisa que faz alguem reconhecer um Fusca a trinta metros
## dentro da nevoa e UMA linha — o arco continuo que sai do para-choque da
## frente, sobe o capo, atravessa o teto e desce ate o para-choque de tras sem
## um canto no caminho. Empilhar caixa nao produz essa linha; produz caixas
## empilhadas, que foi exatamente o que a primeira tentativa entregou.
##
## Entao aqui o casco nao e montado, e VARRIDO. PERFIL descreve o besouro visto
## de lado como uma lista de estacoes em Z, cada uma com tres alturas (assoalho,
## cintura, topo) e tres meias-larguras. Varrer isso da tres coisas de uma vez:
##
##   1. o arco, de graca, porque ele E a coluna `topo` da tabela;
##   2. a barriga que estufa na cintura e afina no teto — a tumblehome, que e o
##      que faz a cupula ler como redonda num modelo de trinta faces;
##   3. um sistema de coordenadas. _ponto_lado e _ponto_topo devolvem ONDE a
##      lataria esta num dado Z, entao janela, friso de porta e veneziana sao
##      POSICIONADOS na superficie em vez de chutados no espaco. Quad chutado no
##      espaco foi o que fez os detalhes da primeira tentativa flutuarem a dez
##      centimetros do carro.
##
## Para-lamas, estribo, farol e para-choque ficam FORA do varrido, como pecas
## aparafusadas — que e como sao num Fusca de verdade, e o unico jeito de
## poderem estufar para fora da largura do casco. O casco entre os para-lamas e
## estreito (o capo tem 0,80 m de largura num carro de 1,55 m); quem faz a
## largura toda sao os quatro para-lamas. Modelar isso como uma caixa unica de
## 1,55 e o erro que transforma Fusca em Kombi.
##
## Refs: PRINTS/CARROS/FUSCA e PRINTS/ref_fusca.
## Sem class_name de proposito: ver Carroceria._fusca(). Registrar a classe aqui
## fecha um ciclo com Carroceria e derruba a compilacao do projeto inteiro.
extends RefCounted

## Medidas do Fusca 1300 real, em metros. A tabela PERFIL e autorada nelas; se
## Carroceria.MEDIDAS pedir outro tamanho, `montar` escala o resultado inteiro.
const COMP_REF := 4.03
const LARG_REF := 1.55
const ALT_REF := 1.50

## Eixos, medidos do centro. Entre-eixos de 2,40 m.
const Z_EIXO_FRENTE := 1.20
const Z_EIXO_TRAS := -1.20
## Raio do arco da caixa de roda. A roda tem 0,30. Com os 14 cm de folga que
## havia antes sobrava um vao de ceu entre o pneu e o para-lama e o carro parecia
## levantado de suspensao; 8 cm e o que faz o pneu preencher o arco como nas refs.
const R_ARCO := 0.38
## Raio de onde nasce a barriga do para-lama. E MAIOR que o buraco de proposito:
## encolher os dois juntos apertava o pneu mas achatava o para-lama junto, e o
## que da a gota do Fusca e justamente a distancia entre o beicinho e a barriga.
const R_LOMBO := 0.46
## Meia-largura maxima, na barriga do para-lama. E ela que define a largura do
## carro, nao o casco.
const X_PARALAMA := 0.775

## Barro das refs. O Fusca do jogo nunca sai limpo: a lataria e um gradiente de
## vertice do creme no teto para o barro na soleira, e a celula SUJA do atlas
## poe a mancha por cima. Sujeira por cor de vertice sai de graca — a alternativa
## era uma celula de atlas por altura, que e textura que nao temos.
const BARRO := Color(0.40, 0.31, 0.20)
## Ate onde a sujeira sobe, e quanto ela pesa la embaixo.
const SUJEIRA_TETO := 0.92
const SUJEIRA_FORCA := 0.62

## Vidro. Escuro de proposito: nas refs a janela e quase preta com um resto de
## reflexo, e e esse contraste que separa a cupula da lataria clara.
const VIDRO := Color(0.17, 0.20, 0.23)
const VIDRO_FRENTE := Color(0.26, 0.31, 0.35)

const CROMO := Color(0.72, 0.72, 0.74)
const BORRACHA := Color(0.13, 0.13, 0.14)
const SOMBRA := Color(0.10, 0.10, 0.11)
## Fresta de painel. Nao e SOMBRA: um risco preto de 7 cm no capo le como listra
## pintada, nao como junta de chapa. Escuro o bastante para ler, claro o
## bastante para continuar sendo lataria.
const FRESTA := Color(0.24, 0.20, 0.15)

## O besouro visto de lado, da frente para tras.
##
## `z` anda para tras; `bot` e o assoalho, `cint` a linha de cintura (onde a
## lataria e mais larga e onde comeca a janela) e `topo` o arco. As tres
## meias-larguras sao medidas nessas tres alturas.
##
## A coluna `cint` e o que estava faltando na primeira tentativa. Sem uma linha
## de cintura o casco vira um tubo: nao ha onde a porta acabar e a janela
## comecar, e nao ha o ombro que projeta a sombra que da volume ao carro.
##
## A coluna `topo` NAO foi desenhada no olho: saiu de medir a silhueta de
## PRINTS/ref_fusca/01_lado.png em vinte e uma fatias e converter cada altura
## para metro (a ref tem 1,50 m de altura). Tres coisas que o olho tinha errado
## e a medida corrigiu, todas grandes:
##
##   * o capo estava 20 cm alto demais. Num Fusca o capo mergulha num VALE entre
##     os dois para-lamas — de lado, quem faz a silhueta da frente e o para-lama,
##     nao o capo. Com o capo alto os dois somem num volume so e o carro vira um
##     sedan dos anos 40;
##   * o para-brisa comecava tarde demais e deitado demais, o que jogava a
##     cabine para tras e alongava o capo;
##   * o rabo estava 35 cm alto demais. O Fusca despenca atras da tampa do motor,
##     e era esse rabo empinado que fazia a traseira ler como fastback.
const PERFIL := [
	# z      bot   cint  topo   w_bot w_cint w_topo
	[ 1.90,  0.46, 0.50, 0.53,  0.26, 0.32,  0.20],  # bico
	[ 1.74,  0.39, 0.55, 0.63,  0.31, 0.40,  0.25],  # frente do capo
	[ 1.50,  0.33, 0.61, 0.77,  0.34, 0.44,  0.28],  # capo
	[ 1.18,  0.29, 0.70, 0.91,  0.37, 0.47,  0.32],  # capo, sobre o eixo
	[ 0.86,  0.27, 0.79, 1.02,  0.43, 0.55,  0.36],  # cofre
	[ 0.62,  0.26, 0.87, 1.15,  0.46, 0.58,  0.42],  # base do para-brisa
	[ 0.40,  0.26, 0.91, 1.42,  0.47, 0.59,  0.45],  # topo do para-brisa
	[ 0.05,  0.26, 0.93, 1.48,  0.48, 0.59,  0.465], # teto, frente
	[-0.30,  0.26, 0.94, 1.50,  0.48, 0.59,  0.47],  # cume
	[-0.66,  0.26, 0.94, 1.47,  0.48, 0.59,  0.462], # teto, tras
	[-1.00,  0.27, 0.93, 1.35,  0.47, 0.585, 0.44],  # topo do vigia
	[-1.26,  0.29, 0.90, 1.13,  0.46, 0.57,  0.40],  # base do vigia
	[-1.48,  0.31, 0.83, 0.97,  0.45, 0.55,  0.37],  # tampa do motor
	[-1.68,  0.34, 0.70, 0.80,  0.44, 0.53,  0.34],  # tras
	[-1.79,  0.36, 0.50, 0.56,  0.39, 0.48,  0.29],  # rabo
	[-1.87,  0.34, 0.36, 0.39,  0.31, 0.40,  0.22],  # tampa
]

## Indices de estacao que delimitam para-brisa e vigia. Ficam em const porque a
## janela e a coluna A saem do MESMO par de estacoes: se a tabela mudar, os dois
## andam juntos e ninguem fica com vidro fora do buraco.
const SEG_PARABRISA := 5
const SEG_VIGIA := 10

## O vidro lateral vai ate a coluna A (17/09/2026)
## -----------------------------------------------
## O jogador reportou que "a janela esquerda do carro nao existe, e fechada". Do
## banco do motorista, olhando para a frente, o terco esquerdo do quadro era
## chapa: o quebra-vento era um retangulo baixo (metade da altura da janela) 10
## cm atras da coluna, e o triangulo entre a rampa do para-brisa e a cintura era
## lataria. Num carro de verdade esse triangulo e vidro — o quebra-vento dos
## carros brasileiros da epoca e exatamente essa peca —, e a coluna A e um friso.
##
## Agora o quebra-vento vai da base do para-brisa ate o topo dele, com a mesma
## fracao de altura da porta, e o vidro da porta comeca 4 cm atras dele. Os dois
## ficam DENTRO de um trecho entre duas estacoes do perfil, e por isso a aresta
## de cima de cada um acompanha a rampa da coluna exatamente: a janela de fora,
## o recorte da casca de dentro e o vidro da cabine continuam o mesmo vidro. A
## fresta da porta dianteira vai para a frente do quebra-vento, e o retrovisor
## para a base da coluna, como num carro de verdade.
##
## As tres janelas de cada lado, em (z0, z1, t0, t1). Em const porque
## `aberturas()` le a MESMA tabela que `_janelas_lado` desenha — o vidro de
## dentro e o de fora tem de ser o mesmo. Ver `AberturasVidro`.
const VAOS_LADO := [
	[0.58, 0.42, 0.14, 0.74],   # quebra-vento, atras da coluna
	[0.38, -0.44, 0.10, 0.74],  # porta
	[-0.58, -0.97, 0.10, 0.66], # fixa traseira
]
## Colagem do vidro por fora da chapa, e a moldura que o Fusca come do
## para-brisa e do vigia (mais larga que a dos outros: a borracha e grossa).
const FOLGA_VIDRO := 0.012
const FOLGA_FRONTAL := 0.010
const RECUO_FRONTAL := 0.13


## O perfil deste carro, para quem gera a casca INTERNA dele. Ver `CabineCasca`.
static func perfil_cabine(comp: float, larg: float, teto: float) -> Dictionary:
	return {
		"perfil": PERFIL, "ombro": OMBRO, "vaos": VAOS_LADO,
		"seg_p": SEG_PARABRISA, "seg_v": SEG_VIGIA,
		"recuo_frontal": RECUO_FRONTAL, "folga_vidro": FOLGA_VIDRO,
		"folga_frontal": FOLGA_FRONTAL,
		"escala": Vector3(larg / LARG_REF, teto / ALT_REF, comp / COMP_REF),
	}


## Onde estao os vidros deste carro, no espaco final da lataria. Ver
## `AberturasVidro` e o gemeo em `carroceria_marea.gd`.
static func aberturas(comp: float, larg: float, teto: float) -> Array[Dictionary]:
	var e := Vector3(larg / LARG_REF, teto / ALT_REF, comp / COMP_REF)
	var nomes := AberturasVidro.nomes(VAOS_LADO.size())
	var out: Array[Dictionary] = []
	for s: float in [1.0, -1.0]:
		for i in VAOS_LADO.size():
			out.append(AberturasVidro.registro(nomes[i], int(s),
				AberturasVidro.lado(PERFIL, OMBRO, VAOS_LADO[i], s, FOLGA_VIDRO),
				e, FOLGA_VIDRO,
				AberturasVidro.contorno(PERFIL, OMBRO, VAOS_LADO[i], s, FOLGA_VIDRO)))
	out.append(AberturasVidro.registro(&"parabrisa", 0,
		AberturasVidro.frontal(PERFIL, SEG_PARABRISA, RECUO_FRONTAL, FOLGA_FRONTAL),
		e, FOLGA_FRONTAL))
	out.append(AberturasVidro.registro(&"vigia", 0,
		AberturasVidro.frontal(PERFIL, SEG_VIGIA, RECUO_FRONTAL, FOLGA_FRONTAL),
		e, FOLGA_FRONTAL))
	return out


## Monta o Fusca inteiro dentro de `corpo` e `luzes`.
static func montar(corpo: Dictionary, luzes: Dictionary, comp: float,
		larg: float, teto: float, cor: Color, com_vidros_frente: bool) -> void:
	var c := PSXMesh.dados_vazios()
	var l := PSXMesh.dados_vazios()

	_casco(c, cor)
	_janelas_lado(c, cor)
	if com_vidros_frente:
		_parabrisa_e_vigia(c)
	_paralamas(c, cor)
	_cavas(c)
	_estribos(c, cor)
	_frente(c, l, cor)
	_traseira(c, l, cor)
	_detalhes(c, cor)

	# A tabela e autorada no Fusca de 4,03 m. Se Carroceria.MEDIDAS pedir outro
	# tamanho, escala aqui em vez de espalhar fatores pela geometria toda.
	var e := Vector3(larg / LARG_REF, teto / ALT_REF, comp / COMP_REF)
	var xf := Transform3D(Basis().scaled(e), Vector3.ZERO)
	PSXMesh.acumular(corpo, c, xf)
	PSXMesh.acumular(luzes, l, xf)


# --------------------------------------------------------------------------
# Perfil e casco: tudo em CarroceriaVarrida
# --------------------------------------------------------------------------
#
# As funcoes abaixo sao atalhos de uma linha para a ferramenta compartilhada.
# Existem para o resto do arquivo continuar escrevendo `_ponto_lado(z, t, s)` em
# vez de repetir PERFIL e OMBRO em cada uma das dezenas de chamadas: o Fusca tem
# UM perfil so, e amarrar os dois aqui e o que mantem legiveis as pecas
# aparafusadas la embaixo.

## Onde fica o ombro do anel: 66% da altura, 34% da largura. A defasagem entre
## as duas e o que arqueia a cupula do besouro.
const OMBRO := Vector2(0.66, 0.34)


static func _estacao(z: float) -> Array:
	return CarroceriaVarrida.estacao(PERFIL, z)


static func _ponto_lado(z: float, t: float, s: float) -> Vector3:
	return CarroceriaVarrida.ponto_lado(PERFIL, OMBRO, z, t, s)


static func _ponto_topo(z: float, u: float) -> Vector3:
	return CarroceriaVarrida.ponto_topo(PERFIL, z, u)


static func _normal_topo(z: float) -> Vector3:
	return CarroceriaVarrida.normal_topo(PERFIL, z)


static func _base_topo(z: float) -> Basis:
	return CarroceriaVarrida.base_topo(PERFIL, z)


static func _x_casco(z: float, y: float) -> float:
	return CarroceriaVarrida.x_casco(PERFIL, OMBRO, z, y)


static func _casco(dados: Dictionary, cor: Color) -> void:
	CarroceriaVarrida.casco(dados, PERFIL, OMBRO, Carroceria.C_LATARIA_SUJA,
		func(y: float) -> Color: return _sujo(cor, y), -1000.0, true, VAOS_LADO,
		[[SEG_PARABRISA, RECUO_FRONTAL], [SEG_VIGIA, RECUO_FRONTAL]], _vincos())


## As frestas da porta, do capo da frente e da tampa do motor, como sulco na
## chapa (PLANO_CARROS_AAA, F6). Eram tiras escuras coladas por fora. O Fusca
## nao recorta caixa de roda: quem faz o arco dele e o para-lama aparafusado.
const PORTA := [0.60, -0.50]
const T_SOLEIRA := -0.84


static func _vincos() -> Dictionary:
	var lado: Array = []
	for z: float in PORTA:
		var topo := OMBRO.x
		for v: Array in VAOS_LADO:
			if z <= float(v[0]) + 0.015 and z >= float(v[1]) - 0.015:
				topo = float(v[2])
		lado.append([z, T_SOLEIRA, topo])
	return {
		"lado": lado,
		"lado_h": [[T_SOLEIRA, float(PORTA[0]), float(PORTA[1])]],
		"topo": [[0.74, 1.80, 0.92], [0.66, -1.16, -1.70]],
		"topo_x": [[1.80, 0.74], [0.92, 0.74], [-1.16, 0.66], [-1.70, 0.66]],
	}


# --------------------------------------------------------------------------
# Vidros
# --------------------------------------------------------------------------

## As tres janelas de cada lado: quebra-vento, porta e a fixa traseira.
##
## Sao recortes COLADOS por fora do flanco alto, e nao buracos. O que sobra de
## lataria entre eles vira coluna A, coluna B e coluna C sem custar geometria de
## moldura — a mesma economia que a Carroceria ja usa nos outros carros.
static func _janelas_lado(dados: Dictionary, _cor: Color) -> void:
	for s: float in [1.0, -1.0]:
		for v: Array in VAOS_LADO:
			var fora := Vector3(s, 0.0, 0.0)
			var d := fora * FOLGA_VIDRO
			# Uma fatia por trecho entre estacoes: ver `AberturasVidro.cortes`.
			var zs := AberturasVidro.cortes(PERFIL, v)
			for k in zs.size() - 1:
				_quad(dados,
					_ponto_lado(zs[k], v[2], s) + d, _ponto_lado(zs[k + 1], v[2], s) + d,
					_ponto_lado(zs[k + 1], v[3], s) + d, _ponto_lado(zs[k], v[3], s) + d,
					Carroceria.C_VIDRO_LADO, VIDRO, VIDRO, VIDRO, VIDRO, fora)
	# Friso da cintura: a linha que separa porta de janela. Duas faces por lado
	# e o que faz a lateral parar de ler como um paralelepipedo pintado.
	for s: float in [1.0, -1.0]:
		var fora := Vector3(s, 0.0, 0.0)
		var a := _ponto_lado(0.60, 0.04, s) + fora * 0.010
		var b := _ponto_lado(-1.00, 0.04, s) + fora * 0.010
		var c := _ponto_lado(-1.00, -0.02, s) + fora * 0.010
		var d := _ponto_lado(0.60, -0.02, s) + fora * 0.010
		_quad(dados, a, b, c, d, Carroceria.C_PARACHOQUE,
			CROMO, CROMO, CROMO, CROMO, fora)


## Para-brisa e vigia.
##
## UMA face, virada para fora. Com o cull_back do psx_surface a camera de dentro
## ve o verso cullado e enxerga a rua; por face dos dois lados o motorista fica
## olhando para um plano preto solido, que foi o P0 da Estrada Velha.
static func _parabrisa_e_vigia(dados: Dictionary) -> void:
	for k: int in [SEG_PARABRISA, SEG_VIGIA]:
		var za: float = PERFIL[k][0]
		var zb: float = PERFIL[k + 1][0]
		var ea: Array = (PERFIL[k] as Array).slice(1)
		var eb: Array = (PERFIL[k + 1] as Array).slice(1)
		var q0 := Vector3(-ea[5], ea[2], za)
		var q1 := Vector3(ea[5], ea[2], za)
		var q2 := Vector3(eb[5], eb[2], zb)
		var q3 := Vector3(-eb[5], eb[2], zb)
		var i := _inset(q0, q1, q2, q3, RECUO_FRONTAL)
		var fora := CarroceriaVarrida.normal_placa(q0, q1, q3)
		var d := fora * FOLGA_FRONTAL
		var celula := (Carroceria.C_PARABRISA if k == SEG_PARABRISA
			else Carroceria.C_VIDRO_TRAS)
		_quad(dados, i[0] + d, i[1] + d, i[2] + d, i[3] + d, celula,
			VIDRO_FRENTE, VIDRO_FRENTE, VIDRO_FRENTE, VIDRO_FRENTE, fora)


# --------------------------------------------------------------------------
# Para-lamas
# --------------------------------------------------------------------------

## Os quatro para-lamas, como arcos varridos por fora do casco.
##
## Cada um e um "C" varrido ao longo do arco da roda: ombro (do casco ate a
## barriga), parede (da barriga ate o beicinho) e o forro escuro por baixo. O
## forro nao e detalhe: sem ele, olhando de lado da para ver a rua atraves da
## caixa de roda, e o arco deixa de existir.
##
## `esp` engorda o para-lama na frente e no alto, que e onde o Fusca poe a gota
## do farol. Um arco de espessura constante le como aro de bicicleta.
static func _paralamas(dados: Dictionary, cor: Color) -> void:
	for frente: bool in [true, false]:
		# O arco traseiro comeca mais alto: indo ate 15 graus ele passava do rabo
		# do carro e o para-lama terminava no ar, lendo como uma aba chapada
		# pregada na traseira em vez de morrer na lataria.
		# O arco dianteiro comeca no ZERO, contornando a frente da roda ate o
		# bico. Comecando a 15 graus sobrava um vao entre a ponta do para-lama e
		# o capo, e de frente dava para enxergar por dentro da caixa de roda:
		# dois buracos pretos ladeando o capo. O traseiro comeca mais alto pelo
		# motivo oposto — ali embaixo nao ha mais carro para o para-lama seguir.
		var angs := ([0.0, 22.0, 45.0, 68.0, 92.0, 120.0, 150.0, 180.0]
			if frente
			else [28.0, 45.0, 62.0, 80.0, 98.0, 120.0, 150.0, 180.0])
		var zc := Z_EIXO_FRENTE if frente else Z_EIXO_TRAS
		var dz := 1.0 if frente else -1.0
		# Raio da barriga em cada costela. Sai da mesma medida da silhueta que
		# gerou PERFIL: entre z=1,75 e z=1,15 quem faz a linha de cima do Fusca
		# e o para-lama, entao estes numeros perseguem a curva da ref ponto a
		# ponto. Espessura uniforme, que era o que havia antes, da um aro de
		# bicicleta; a gota so aparece quando o raio varia.
		var raio := ([0.700, 0.672, 0.630, 0.620, 0.650, 0.700, 0.660, 0.600]
			if frente
			else [0.600, 0.620, 0.625, 0.630, 0.655, 0.680, 0.640, 0.580])
		var largo := ([0.640, 0.720, 0.760, X_PARALAMA, X_PARALAMA, 0.750,
			0.700, 0.650] if frente
			else [0.580, 0.690, 0.745, 0.765, 0.765, 0.740, 0.690, 0.640])
		for s: float in [1.0, -1.0]:
			var ribs := []
			for k in angs.size():
				var a: float = deg_to_rad(angs[k])
				var cz := cos(a)
				var sy := sin(a)
				var r_out: float = raio[k]
				var p_out := Vector3(0.0, 0.30 + sy * r_out, zc + dz * cz * r_out)
				var p_raiz := Vector3(0.0, 0.30 + sy * (r_out - 0.09),
					zc + dz * cz * (r_out - 0.09))
				var p_in := Vector3(0.0, 0.30 + sy * R_ARCO, zc + dz * cz * R_ARCO)
				# Nas duas pontas do arco o para-lama tem a largura DO CASCO, ou
				# seja, protuberancia zero: ele nasce da lataria e volta para ela.
				# Com largura fixa ate a ultima costela, o arco acabava no ar com
				# uma aresta crua, e de tras os dois para-lamas traseiros liam
				# como abas de chapa penduradas. Morrer dentro do casco custa
				# zero triangulo e dispensa tampa.
				var xw: float = largo[k]
				if k == 0 or k == angs.size() - 1:
					xw = _x_casco(p_out.z, p_out.y) + 0.012
				# Ponto do MEIO do ombro, erguido quase ate a barriga. Sem ele o
				# ombro e um quadrilatero unico do casco ate a barriga: chapado,
				# e de tras os dois para-lamas traseiros liam como duas abas de
				# chapa pregadas no carro. Curvatura na travessia custa uma faixa
				# e e o que transforma aba em volume.
				var r_meio: float = r_out - 0.018
				var xr: float = _x_casco(p_raiz.z, p_raiz.y)
				ribs.append([
					Vector3(s * xr, p_raiz.y, p_raiz.z),
					Vector3(s * lerpf(xr, xw, 0.58),
						0.30 + sy * r_meio, zc + dz * cz * r_meio),
					Vector3(s * xw, p_out.y, p_out.z),
					Vector3(s * (xw - 0.035), p_in.y, p_in.z),
					Vector3(s * _x_casco(p_in.z, p_in.y), p_in.y, p_in.z),
				])
			for k in ribs.size() - 1:
				# Cada costela sai de um Array destipado, entao os quatro pontos
				# vem para variaveis anotadas antes de qualquer conta. Sem isso o
				# parser nao infere o tipo de `meio` e o script inteiro nao carrega.
				var a0: Array = ribs[k]
				var a1: Array = ribs[k + 1]
				var r0: Vector3 = a0[0]
				var m0: Vector3 = a0[1]
				var c0: Vector3 = a0[2]
				var l0: Vector3 = a0[3]
				var f0: Vector3 = a0[4]
				var r1: Vector3 = a1[0]
				var m1: Vector3 = a1[1]
				var c1: Vector3 = a1[2]
				var l1: Vector3 = a1[3]
				var f1: Vector3 = a1[4]
				# O radial e medido SO no plano do arco (z,y). Com o X da barriga
				# dentro dele o vetor apontava quase todo para o lado, o ombro do
				# para-lama — que e uma faixa quase horizontal — ficava com
				# `normal.dot(fora)` perto de zero e o culling sorteava a face.
				# Resultado: o ombro sumia e aparecia o forro preto por baixo,
				# pintando de preto o flanco inteiro do carro.
				var radial := Vector3(0.0,
					(c0.y + c1.y) * 0.5 - 0.30,
					(c0.z + c1.z) * 0.5 - zc).normalized()
				# Ombro, em duas faixas: casco -> meio -> barriga.
				_quad(dados, r0, r1, m1, m0, Carroceria.C_LATARIA_SUJA,
					_sujo(cor, r0.y), _sujo(cor, r1.y),
					_sujo(cor, m1.y), _sujo(cor, m0.y), radial)
				_quad(dados, m0, m1, c1, c0, Carroceria.C_LATARIA_SUJA,
					_sujo(cor, m0.y), _sujo(cor, m1.y),
					_sujo(cor, c1.y), _sujo(cor, c0.y),
					(radial + Vector3(s * 0.55, 0.0, 0.0)).normalized())
				# Parede externa: da barriga ate o beicinho do arco.
				_quad(dados, c0, c1, l1, l0, Carroceria.C_LATARIA_SUJA,
					_sujo(cor, c0.y), _sujo(cor, c1.y),
					_sujo(cor, l1.y), _sujo(cor, l0.y),
					Vector3(s, 0.0, 0.0))
				# Forro, virado para dentro do arco.
				_quad(dados, l0, l1, f1, f0, Carroceria.C_FUNDO,
					SOMBRA, SOMBRA, SOMBRA, SOMBRA, -radial)
				# Costura: o risco onde o para-lama e aparafusado na lataria.
				#
				# De lado, um para-lama que so estufa em X e invisivel — o olho
				# nao ve profundidade, ve contorno. Nas refs quem desenha os
				# para-lamas na vista lateral nao e a barriga: e esta linha. Sem
				# ela o Fusca de perfil vira um casco liso com dois buracos de
				# roda, que era como o modelo lia ate aqui.
				var cd := radial * 0.008
				_quad(dados, r0 + cd, r1 + cd,
					r1.lerp(c1, 0.22) + cd, r0.lerp(c0, 0.22) + cd,
					Carroceria.C_SOLEIRA, FRESTA, FRESTA, FRESTA, FRESTA, radial)


## A cava: um fundo escuro dentro do arco de roda.
##
## O arco e um recorte no PARA-LAMA, mas atras dele o casco continua inteiro —
## nao ha caixa de roda escavada na lataria, e nem deveria haver: seria furar o
## volume varrido para ganhar nada. So que, sem nada, o que aparece dentro do
## arco e a barriga do casco bem iluminada, e o arco deixa de ler como buraco e
## passa a ler como uma marca pintada em volta da roda.
##
## Dois triangulos por roda resolvem: uma placa escura logo por fora do casco,
## do tamanho do arco. Ela nao e vista de lugar nenhum a nao ser por dentro do
## arco, que e exatamente onde se quer sombra.
static func _cavas(dados: Dictionary) -> void:
	for zc: float in [Z_EIXO_FRENTE, Z_EIXO_TRAS]:
		for s: float in [1.0, -1.0]:
			var xc := s * (_x_casco(zc, 0.30 + R_ARCO * 0.4) + 0.012)
			var r := R_ARCO * 0.96
			# MEIA lua, do eixo para cima, e nao um quadrado. Quadrado sobra por
			# baixo do para-lama e vira uma caixa preta pendurada embaixo do
			# carro — troca um arco sem sombra por um defeito bem pior.
			var lados := 6
			for k in lados:
				var a0 := PI * float(k) / float(lados)
				var a1 := PI * float(k + 1) / float(lados)
				_tri(dados,
					Vector3(xc, 0.30, zc),
					Vector3(xc, 0.30 + sin(a0) * r, zc + cos(a0) * r),
					Vector3(xc, 0.30 + sin(a1) * r, zc + cos(a1) * r),
					Carroceria.C_FUNDO, SOMBRA, SOMBRA, SOMBRA,
					Vector3(s, 0.0, 0.0))


## Os estribos, entre para-lama e para-lama. Um Fusca sem estribo tem um vao
## preto de meio metro embaixo da porta e passa a ler como carrinho de rolima.
static func _estribos(dados: Dictionary, _cor: Color) -> void:
	var z0 := 0.62
	var z1 := -0.62
	var y := 0.33
	var xe := 0.685
	for s: float in [1.0, -1.0]:
		var xi0 := s * _x_casco(z0, y)
		var xi1 := s * _x_casco(z1, y)
		# Piso do estribo.
		_quad(dados, Vector3(xi0, y, z0), Vector3(s * xe, y, z0),
			Vector3(s * xe, y, z1), Vector3(xi1, y, z1),
			Carroceria.C_SOLEIRA, BARRO, BARRO, BARRO, BARRO, Vector3.UP)
		# Aba de fora, que e onde a sombra do estribo mora.
		_quad(dados, Vector3(s * xe, y, z0), Vector3(s * xe, y - 0.09, z0),
			Vector3(s * xe, y - 0.09, z1), Vector3(s * xe, y, z1),
			Carroceria.C_SOLEIRA, BARRO * 0.55, BARRO * 0.55, BARRO * 0.55,
			BARRO * 0.55, Vector3(s, 0.0, 0.0))


# --------------------------------------------------------------------------
# Frente
# --------------------------------------------------------------------------

static func _frente(dados: Dictionary, luzes: Dictionary, cor: Color) -> void:
	# Vinco central do capo. Uma tira so, um tom acima da lataria: e o que faz o
	# capo ler como duas aguas em vez de uma tabua.
	for k in 5:
		var za := lerpf(0.90, 1.82, float(k) / 5.0)
		var zb := lerpf(0.90, 1.82, float(k + 1) / 5.0)
		var na := _normal_topo(za) * 0.008
		var nb := _normal_topo(zb) * 0.008
		_quad(dados,
			_ponto_topo(za, -0.09) + na, _ponto_topo(za, 0.09) + na,
			_ponto_topo(zb, 0.09) + nb, _ponto_topo(zb, -0.09) + nb,
			Carroceria.C_CAPO, _sujo(cor, 1.0) * 1.08, _sujo(cor, 1.0) * 1.08,
			_sujo(cor, 1.0) * 1.08, _sujo(cor, 1.0) * 1.08, Vector3.UP)
	# Recorte do capo: duas tiras escuras acompanhando a borda. Frestas de painel
	# sao o detalhe mais barato que existe e o que mais faz o carro parecer
	# montado de pecas em vez de esculpido num sabao.

	# O farol nasce DO ARCO do para-lama, e nao de um par de numeros soltos.
	#
	# Cravado a mao ele ficava sempre alguns centimetros abaixo do ombro do
	# para-lama — e o ombro e uma faixa larga atravessando o carro, entao ele
	# TAPAVA o farol inteiro. De frente o Fusca ficava cego: dava para ver o
	# pisca ambar e mais nada. Derivar a posicao do mesmo arco que desenha o
	# para-lama garante que o farol fique por FORA da casca, com o nacele
	# estufando, que e como ele fica no carro de verdade.
	# 62 graus poe o farol SOBRE A RODA dianteira, que e onde ele mora num
	# Fusca — nao no bico. A 58 graus, com o nacele grande, ele furava a linha
	# de cima do para-lama 26 cm acima da ref.
	var ang_farol := deg_to_rad(62.0)
	var r_farol := 0.612
	var yf := 0.30 + sin(ang_farol) * r_farol
	var zf := Z_EIXO_FRENTE + cos(ang_farol) * r_farol
	for s: float in [1.0, -1.0]:
		# Farol: aro escuro afundado no para-lama, lente clara no corpo e o
		# emissivo por cima. A lente vai TAMBEM no corpo porque na vitrine (e em
		# qualquer cena sem luz) o material emissivo sozinho some, e o Fusca sem
		# os dois olhos redondos deixa de ser Fusca.
		var base := Vector3(s * 0.505, yf, zf)
		var giro := Basis(Vector3.UP, s * -0.18) * Basis(Vector3.RIGHT, 0.16)
		# Aro CLARO, lente ESCURA. Ao contrario do que o instinto pede: farol
		# apagado nao brilha, ele e um vidro fundo. Com a lente clara que estava
		# aqui os dois farois desapareciam — creme sobre para-lama creme, e o aro
		# escuro de dois centimetros virava um pixel a 480p. Escuro contra o bege
		# da lataria, eles voltam a ser a cara do carro.
		_disco(dados, base + giro * Vector3(0, 0, 0.004), giro, 0.104,
			Carroceria.C_PARACHOQUE, CROMO * 1.10)
		_disco(dados, base + giro * Vector3(0, 0, 0.020), giro, 0.084,
			Carroceria.C_FAROL, Color(0.28, 0.30, 0.32))
		_disco(dados, base + giro * Vector3(0, 0, 0.024), giro, 0.046,
			Carroceria.C_FAROL, Color(0.46, 0.48, 0.49))
		# O emissivo so aparece de farol aceso; de dia quem le e o disco escuro.
		_disco(luzes, base + giro * Vector3(0, 0, 0.028), giro, 0.068,
			Carroceria.C_FAROL, Color.WHITE)
		# Pisca ambar em cima do para-lama, quase no bico.
		var pp := Vector3(s * 0.565, 0.595, 1.795)
		_plana(luzes, Vector2(0.105, 0.06),
			Transform3D(Basis(Vector3.UP, s * -0.34) * Basis(Vector3.RIGHT, -0.95), pp),
			Color(1.0, 0.66, 0.16), Carroceria.C_PISCA)

	# Para-choque de lamina com as duas bengalas, e a placa.
	_parachoque(dados, 1.99, 0.47, true)
	_plana(dados, Vector2(0.28, 0.10),
		Transform3D(Basis(Vector3.RIGHT, -0.42), Vector3(0.0, 0.50, 1.88)),
		Color(0.86, 0.86, 0.84), Carroceria.C_PLACA)


# --------------------------------------------------------------------------
# Traseira
# --------------------------------------------------------------------------

static func _traseira(dados: Dictionary, luzes: Dictionary, _cor: Color) -> void:
	# Venezianas da tampa do motor. Duas famílias, como nas refs: a fileira fina
	# no ombro, logo abaixo do vigia, e o painel largo no meio da tampa.
	for k in 5:
		var z := lerpf(-1.20, -1.32, float(k) / 4.0)
		var nz := _normal_topo(z) * 0.010
		var p := _ponto_topo(z, 0.0) + nz
		_plana(dados, Vector2(0.46, 0.022),
			Transform3D(_base_topo(z), p), SOMBRA, Carroceria.C_GRADE)
	for k in 7:
		var z := lerpf(-1.38, -1.64, float(k) / 6.0)
		var nz := _normal_topo(z) * 0.010
		var p := _ponto_topo(z, 0.0) + nz
		var e := _estacao(z)
		_plana(dados, Vector2(e[5] * 1.32, 0.026),
			Transform3D(_base_topo(z), p), SOMBRA, Carroceria.C_GRADE)
	# Puxador da tampa e a fresta em volta dela.
	var zp := -1.36
	_plana(dados, Vector2(0.16, 0.030),
		Transform3D(_base_topo(zp), _ponto_topo(zp, 0.0) + _normal_topo(zp) * 0.016),
		CROMO, Carroceria.C_PARACHOQUE)

	for s: float in [1.0, -1.0]:
		# Lanterna alta no para-lama traseiro: ambar em cima, vermelho embaixo.
		var lp := Vector3(s * 0.57, 0.78, -1.56)
		var giro := Basis(Vector3.UP, PI + s * 0.24) * Basis(Vector3.RIGHT, -0.16)
		_plana(luzes, Vector2(0.070, 0.070),
			Transform3D(giro, lp + giro * Vector3(0, 0.040, 0.02)),
			Color(1.0, 0.55, 0.14), Carroceria.C_LANTERNA)
		_plana(luzes, Vector2(0.070, 0.052),
			Transform3D(giro, lp + giro * Vector3(0, -0.030, 0.02)),
			Color.WHITE, Carroceria.C_FREIO)
		_plana(dados, Vector2(0.088, 0.140),
			Transform3D(giro, lp + giro * Vector3(0, 0.005, 0.008)),
			BORRACHA, Carroceria.C_GRADE)

	_parachoque(dados, -1.99, 0.49, false)
	# Placa e a luz dela, e o escapamento saindo por baixo.
	_plana(dados, Vector2(0.28, 0.10),
		Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, 0.62),
			Vector3(0.0, 0.60, -1.72)),
		Color(0.80, 0.80, 0.78), Carroceria.C_PLACA)
	_plana(luzes, Vector2(0.055, 0.026),
		Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, 0.62),
			Vector3(0.0, 0.72, -1.66)),
		Color(0.95, 0.93, 0.80), Carroceria.C_RE)
	for s: float in [1.0, -1.0]:
		_plana(dados, Vector2(0.05, 0.045),
			Transform3D(Basis(Vector3.UP, PI), Vector3(s * 0.20, 0.34, -1.83)),
			Color(0.18, 0.17, 0.16), Carroceria.C_PARACHOQUE)


## Lamina de para-choque com as duas bengalas verticais.
##
## O Fusca nao tem para-choque de plastico rente: tem uma barra afastada da
## lataria, e sao a SOMBRA entre a barra e o carro e o jeito como ela CONTORNA as
## pontas que dao profundidade a frente. A primeira versao era uma placa reta e
## lia como uma tabua pregada no bico — barra de para-choque so vira para-choque
## quando dobra para tras nas duas pontas.
##
## Por isso a lamina e varrida em cinco estacoes atravessadas, com a ponta
## recuando `RECUO_PONTA`, e tem as tres faces (frente, topo e a de baixo em
## sombra) em vez de um plano so.
static func _parachoque(dados: Dictionary, z: float, y: float,
		frente: bool) -> void:
	var dz := 1.0 if frente else -1.0
	var larg := 0.66
	var alt := 0.10
	var fundura := 0.07
	# u atravessa o carro; `recuo` e quanto aquela estacao volta para tras.
	var us := [-1.0, -0.66, 0.0, 0.66, 1.0]
	var recuos := [0.13, 0.035, 0.0, 0.035, 0.13]
	var pontos := []
	for k in us.size():
		var zz: float = z - dz * recuos[k]
		pontos.append([
			Vector3(us[k] * larg, y + alt * 0.5, zz),
			Vector3(us[k] * larg, y - alt * 0.5, zz),
		])
	for k in pontos.size() - 1:
		var a: Array = pontos[k]
		var b: Array = pontos[k + 1]
		var a0: Vector3 = a[0]
		var a1: Vector3 = a[1]
		var b0: Vector3 = b[0]
		var b1: Vector3 = b[1]
		var fora := Vector3(0.0, 0.0, dz)
		# Face da lamina.
		_quad(dados, a0, b0, b1, a1, Carroceria.C_PARACHOQUE,
			CROMO, CROMO, CROMO * 0.92, CROMO * 0.92, fora)
		# Topo, pegando luz, e a barriga em sombra.
		_quad(dados, a0, b0, b0 - Vector3(0, 0, dz * fundura),
			a0 - Vector3(0, 0, dz * fundura), Carroceria.C_PARACHOQUE,
			CROMO * 1.14, CROMO * 1.14, CROMO * 0.85, CROMO * 0.85, Vector3.UP)
		_quad(dados, a1, b1, b1 - Vector3(0, 0, dz * fundura),
			a1 - Vector3(0, 0, dz * fundura), Carroceria.C_PARACHOQUE,
			SOMBRA, SOMBRA, SOMBRA, SOMBRA, Vector3.DOWN)
	# Bengalas: as duas colunas verticais que sobem da lamina ate a lataria.
	var base := Basis(Vector3.UP, 0.0 if frente else PI)
	for s: float in [1.0, -1.0]:
		var bx := s * 0.25
		var bz := z - dz * 0.005
		_plana(dados, Vector2(0.052, 0.19),
			Transform3D(base, Vector3(bx, y + 0.05, bz + dz * 0.012)),
			CROMO * 1.06, Carroceria.C_PARACHOQUE)
		for f: float in [1.0, -1.0]:
			_plana(dados, Vector2(0.030, 0.19),
				Transform3D(base * Basis(Vector3.UP, f * PI * 0.5),
					Vector3(bx + f * s * 0.028, y + 0.05, bz)),
				CROMO * 0.80, Carroceria.C_PARACHOQUE)


# --------------------------------------------------------------------------
# Detalhes de lataria
# --------------------------------------------------------------------------

static func _detalhes(dados: Dictionary, _cor: Color) -> void:
	for s: float in [1.0, -1.0]:
		# A porta e vinco na chapa (`_vincos`); aqui so a macaneta, com volume.
		CarroceriaVarrida.macaneta(dados, PERFIL, OMBRO, s, -0.38, -0.06,
			CROMO, Carroceria.C_PARACHOQUE)

	# Retrovisor, so no lado do motorista. Depois da meia volta que a Carroceria
	# aplica, o +X daqui vira o -X do mundo, que e onde o volante fica num carro
	# brasileiro.
	var haste := _ponto_lado(0.56, 0.10, 1.0)
	var esp := haste + Vector3(0.055, 0.075, 0.015)
	_plana(dados, Vector2(0.075, 0.05),
		Transform3D(Basis(Vector3.UP, 0.30), esp),
		Carroceria.marcar(Color(0.30, 0.34, 0.38), Carroceria.Classe.ESPELHO),
		Carroceria.C_VIDRO_LADO)
	_plana(dados, Vector2(0.075, 0.05),
		Transform3D(Basis(Vector3.UP, PI + 0.30), esp),
		CROMO * 0.8, Carroceria.C_PARACHOQUE)
	# Haste ligando o espelho a lataria. Sem ela o espelho flutua ao lado do
	# carro como um retangulo cinza solto, que e como estava.
	_quad(dados, haste, esp + Vector3(0.0, -0.022, 0.0),
		esp + Vector3(0.0, -0.022, 0.026), haste + Vector3(0.0, 0.0, 0.026),
		Carroceria.C_PARACHOQUE, CROMO * 0.7, CROMO * 0.7, CROMO * 0.7,
		CROMO * 0.7, Vector3.UP)


# --------------------------------------------------------------------------
# Utilidades de malha: atalhos para CarroceriaVarrida
# --------------------------------------------------------------------------

## Sujeira por altura: barro na soleira, creme no teto.
static func _sujo(cor: Color, y: float) -> Color:
	return CarroceriaVarrida.sujo(cor, BARRO, y, SUJEIRA_TETO, SUJEIRA_FORCA)


static func _quad(dados: Dictionary, p0: Vector3, p1: Vector3, p2: Vector3,
		p3: Vector3, celula: Vector2i, c0: Color, c1: Color, c2: Color,
		c3: Color, fora: Vector3) -> void:
	CarroceriaVarrida.quad(dados, p0, p1, p2, p3, celula, c0, c1, c2, c3, fora)


static func _tri(dados: Dictionary, p0: Vector3, p1: Vector3, p2: Vector3,
		celula: Vector2i, c0: Color, c1: Color, c2: Color,
		fora: Vector3) -> void:
	CarroceriaVarrida.tri(dados, p0, p1, p2, celula, c0, c1, c2, fora)


static func _plana(dados: Dictionary, tamanho: Vector2, xform: Transform3D,
		cor: Color, celula: Vector2i) -> void:
	CarroceriaVarrida.plana(dados, tamanho, xform, cor, celula)


static func _disco(dados: Dictionary, centro: Vector3, giro: Basis, raio: float,
		celula: Vector2i, cor: Color) -> void:
	CarroceriaVarrida.disco(dados, centro, giro, raio, celula, cor)


static func _inset(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
		f: float) -> Array:
	return CarroceriaVarrida.inset(p0, p1, p2, p3, f)
