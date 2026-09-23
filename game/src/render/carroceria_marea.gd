## O Marea: o sedan tres-volumes das refs, varrido pela mesma maquina do Fusca.
##
## Mesmo motor, tabela oposta. O Fusca e uma abobada com quatro para-lamas
## aparafusados por fora; este carro e uma CAIXA cuja lateral ja e a largura
## toda. As duas diferencas que isso produz valem mais que qualquer detalhe:
##
##   * nao ha peca de para-lama. O casco varrido vai de ponta a ponta com
##     w_cint no maximo, e a roda entra num arco RECORTADO nele. Tentar dar
##     para-lama a um sedan oitentista poe um calombo onde a ref tem chapa reta;
##   * o OMBRO sobe para (0.80, 0.20). No Fusca ele fica em (0.66, 0.34), que
##     arqueia a secao inteira; aqui a lateral e reta ate 80% da altura e so
##     entao vira, o que da o unico chanfro que um sedan tres-volumes tem — o do
##     encontro da porta com o teto. Trocar esses dois numeros e o que separa
##     "abobada" de "caixa".
##
## O terceiro volume tambem e so tabela: a coluna `topo` sobe do capo (0,90) ao
## teto (1,39), corre reta, e DESCE de volta a tampa do porta-malas (1,00). Sao
## os dois degraus — para-brisa e vigia — que fazem os tres volumes existirem.
## Um sedan modelado com o teto descendo direto para o rabo vira fastback.
##
## Este e o carro mais importante do jogo: e o padrao do transito E o carro da
## Estrada Velha (carro_cena.gd). Por isso ele custa MENOS triangulo que o
## Fusca, que aparece em 28% da rua e nunca e jogavel.
##
## Refs: PRINTS/CARROS/MAREA.
## Sem class_name de proposito: ver Carroceria._modulo(). Registrar a classe aqui
## fecha um ciclo com Carroceria e derruba a compilacao do projeto inteiro.
extends RefCounted

## Medidas do sedan das refs, em metros. PERFIL e autorado nelas; se
## Carroceria.MEDIDAS pedir outro tamanho, `montar` escala o resultado inteiro.
const COMP_REF := 4.36
const LARG_REF := 1.66
const ALT_REF := 1.39

## Eixos, medidos do centro. Entre-eixos de 2,57 m.
const Z_EIXO_FRENTE := 1.285
const Z_EIXO_TRAS := -1.285

## Ombro do anel: 80% da altura, 20% da largura. Lateral reta com um chanfro so
## no alto — a diferenca de leitura entre este carro e o Fusca mora aqui.
const OMBRO := Vector2(0.80, 0.20)

## Sujeira, na mesma receita do Fusca: gradiente de vertice do barro na soleira
## ao creme no teto, com a celula SUJA do atlas por cima.
const BARRO := Color(0.42, 0.33, 0.22)
const SUJEIRA_TETO := 0.88
const SUJEIRA_FORCA := 0.55

const VIDRO := Color(0.16, 0.19, 0.22)
const VIDRO_FRENTE := Color(0.24, 0.29, 0.33)

const CROMO := Color(0.70, 0.70, 0.72)
const PLASTICO := Color(0.30, 0.30, 0.31)
const SOMBRA := Color(0.10, 0.10, 0.11)

## O sedan visto de lado, da frente para tras.
##
## `bot` e o assoalho, `cint` a linha de cintura (base das janelas, e onde a
## lataria e mais larga) e `topo` a linha de cima. As tres meias-larguras sao
## medidas nessas tres alturas.
##
## Repare que w_cint fica em 0,83 — a largura CHEIA — do capo ao porta-malas.
## E isso que faz o carro ser uma caixa: no Fusca essa coluna despenca para 0,32
## no bico porque la quem faz a largura sao os para-lamas.
const PERFIL := [
	# z      bot   cint  topo    w_bot w_cint w_topo
	[ 2.14,  0.44, 0.62, 0.80,   0.56, 0.68,  0.60],   # bico
	[ 2.04,  0.32, 0.70, 0.865,  0.64, 0.77,  0.68],   # frente
	[ 1.82,  0.28, 0.78, 0.885,  0.69, 0.81,  0.73],   # capo, frente
	[ 1.35,  0.26, 0.83, 0.90,   0.71, 0.825, 0.76],   # capo
	[ 0.88,  0.26, 0.87, 0.925,  0.72, 0.83,  0.775],  # cofre / base do vidro
	[ 0.44,  0.26, 0.91, 1.31,   0.72, 0.83,  0.70],   # topo do para-brisa
	[ 0.05,  0.26, 0.93, 1.385,  0.72, 0.83,  0.685],  # teto, frente
	[-0.60,  0.26, 0.94, 1.39,   0.72, 0.83,  0.685],  # teto, tras
	[-0.98,  0.26, 0.94, 1.35,   0.72, 0.83,  0.68],   # topo do vigia
	[-1.42,  0.27, 0.93, 1.015,  0.71, 0.825, 0.72],   # base do vigia
	[-1.86,  0.29, 0.90, 1.00,   0.69, 0.81,  0.71],   # tampa do porta-malas
	[-2.06,  0.33, 0.78, 0.955,  0.64, 0.77,  0.68],   # traseira
	[-2.14,  0.42, 0.66, 0.86,   0.56, 0.68,  0.60],   # rabo
]

## Estacoes que delimitam para-brisa e vigia. Em const porque o vidro e a coluna
## saem do MESMO par: mexendo na tabela, os dois andam juntos.
const SEG_PARABRISA := 4
const SEG_VIGIA := 8

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
## As quatro janelas de cada lado, em (z0, z1, t0, t1). Em const, e nao dentro
## de `_janelas_lado`, porque `aberturas()` le a MESMA tabela: o interior da
## cabine e o vidro de fora nao podem divergir. Ver `AberturasVidro`.
const VAOS_LADO := [
	[0.84, 0.46, 0.12, 0.82],    # quebra-vento, sob a rampa do para-brisa
	[0.42, -0.34, 0.10, 0.82],   # porta dianteira
	[-0.41, -0.85, 0.10, 0.80],  # porta traseira
	[-0.90, -1.04, 0.10, 0.68],  # fixa da coluna C
]
## Quanto o vidro fica colado por fora do flanco e da rampa, e o quanto a
## moldura de lataria come do para-brisa e do vigia.
const FOLGA_VIDRO := 0.012
const FOLGA_FRONTAL := 0.010
const RECUO_FRONTAL := 0.10

## Estado da montagem corrente: as ripas de limpador na chapa saem quando o
## carro tem cabine. `montar` nao roda em paralelo — mesma convencao do modulo
## da caixa.
static var _com_limpadores: bool = true


## Onde estao os vidros deste carro, no espaco final da lataria.
##
## Sai das MESMAS tabelas que `_janelas_lado` e `_parabrisa_e_vigia` desenham,
## passando pela mesma escala e pela mesma meia volta que `Carroceria.montar`
## aplica. Quem monta interior le daqui em vez de adivinhar. Ver
## `AberturasVidro`.
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


## O perfil deste carro, para quem gera a casca INTERNA dele.
##
## Mesma tese das `aberturas`: o interior tem de sair do mesmo casco que a
## lataria, e nao de medida chutada. Ver `CabineCasca`.
static func perfil_cabine(comp: float, larg: float, teto: float) -> Dictionary:
	return {
		"perfil": PERFIL, "ombro": OMBRO, "vaos": VAOS_LADO,
		"seg_p": SEG_PARABRISA, "seg_v": SEG_VIGIA,
		"recuo_frontal": RECUO_FRONTAL, "folga_vidro": FOLGA_VIDRO,
		"folga_frontal": FOLGA_FRONTAL,
		"escala": Vector3(larg / LARG_REF, teto / ALT_REF, comp / COMP_REF),
	}


## Monta o Marea inteiro dentro de `corpo` e `luzes`.
##
## `com_limpadores` false tira as duas ripas deitadas no cowl. Serve ao carro
## que tem cabine: la o limpador e um no com pivo, que varre de verdade, e as
## ripas assadas na lataria virariam um segundo par de limpadores parados.
static func montar(corpo: Dictionary, luzes: Dictionary, comp: float,
		larg: float, teto: float, cor: Color, com_vidros_frente: bool,
		com_limpadores: bool = true) -> void:
	_com_limpadores = com_limpadores
	var c := PSXMesh.dados_vazios()
	var l := PSXMesh.dados_vazios()

	_casco(c, cor)
	_janelas_lado(c)
	if com_vidros_frente:
		_parabrisa_e_vigia(c)
	_frente(c, l, cor)
	_traseira(c, l, cor)
	_flancos(c, cor)

	var e := Vector3(larg / LARG_REF, teto / ALT_REF, comp / COMP_REF)
	PSXMesh.acumular(corpo, c, Transform3D(Basis().scaled(e), Vector3.ZERO))
	PSXMesh.acumular(luzes, l, Transform3D(Basis().scaled(e), Vector3.ZERO))


# --------------------------------------------------------------------------
# Perfil e casco: atalhos para CarroceriaVarrida
# --------------------------------------------------------------------------

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


static func _sujo(cor: Color, y: float) -> Color:
	return CarroceriaVarrida.sujo(cor, BARRO, y, SUJEIRA_TETO, SUJEIRA_FORCA)


static func _casco(dados: Dictionary, cor: Color) -> void:
	CarroceriaVarrida.casco(dados, PERFIL, OMBRO, Carroceria.C_LATARIA_SUJA,
		func(y: float) -> Color: return _sujo(cor, y), -1000.0, true, VAOS_LADO,
		[[SEG_PARABRISA, RECUO_FRONTAL], [SEG_VIGIA, RECUO_FRONTAL]], _vincos())


## As frestas das quatro portas, da soleira, do capo e da tampa, e as quatro
## caixas de roda, como recorte do casco (PLANO_CARROS_AAA, F6). Eram faixas
## escuras coladas por fora — ver `CarroceriaVarrida.casco`.
const PORTAS := [0.86, -0.37, -1.02]
const T_SOLEIRA := -0.84
const Z_CAPO := 0.95
const Z_TAMPA := -1.46


static func _vincos() -> Dictionary:
	var lado: Array = []
	for z: float in PORTAS:
		var topo := OMBRO.x
		for v: Array in VAOS_LADO:
			if z <= float(v[0]) + 0.015 and z >= float(v[1]) - 0.015:
				topo = float(v[2])
		lado.append([z, T_SOLEIRA, topo])
	var zf: float = PERFIL[0][0]
	var zt: float = PERFIL[PERFIL.size() - 1][0]
	return {
		"lado": lado,
		"lado_h": [[T_SOLEIRA, float(PORTAS[0]), float(PORTAS[PORTAS.size() - 1])]],
		"topo": [[0.74, zf - 0.03, Z_CAPO], [0.76, Z_TAMPA, zt + 0.03]],
		"topo_x": [[Z_CAPO, 0.74], [Z_TAMPA, 0.76]],
		"arcos": [
			CarroceriaVarrida.contorno_arco(PERFIL, Z_EIXO_FRENTE, 0.30, ARCO, 0.26),
			CarroceriaVarrida.contorno_arco(PERFIL, Z_EIXO_TRAS, 0.30, ARCO, 0.18),
		],
	}


# --------------------------------------------------------------------------
# Vidros
# --------------------------------------------------------------------------

## As quatro janelas de cada lado: quebra-vento, porta dianteira, porta traseira
## e a fixa da coluna C.
##
## Sao recortes colados por fora do flanco, e nao buracos. O que sobra de
## lataria entre eles vira coluna A, coluna B e coluna C sem custar geometria de
## moldura — quatro portas ficam legiveis de graca.
static func _janelas_lado(dados: Dictionary) -> void:
	for s: float in [1.0, -1.0]:
		var fora := Vector3(s, 0.0, 0.0)
		for v: Array in VAOS_LADO:
			var d := fora * FOLGA_VIDRO
			# Uma fatia por trecho entre estacoes: ver `AberturasVidro.cortes`.
			var zs := AberturasVidro.cortes(PERFIL, v)
			for k in zs.size() - 1:
				CarroceriaVarrida.quad(dados,
					_ponto_lado(zs[k], v[2], s) + d, _ponto_lado(zs[k + 1], v[2], s) + d,
					_ponto_lado(zs[k + 1], v[3], s) + d, _ponto_lado(zs[k], v[3], s) + d,
					Carroceria.C_VIDRO_LADO, VIDRO, VIDRO, VIDRO, VIDRO, fora)


## Para-brisa e vigia.
##
## UMA face, virada para fora. Com o cull_back do psx_surface a camera de dentro
## ve o verso cullado e enxerga a rua; com face dos dois lados o motorista fica
## olhando para um plano preto solido — foi o P0 da Estrada Velha, e este carro
## E o da Estrada Velha. Nao trocar por face dupla sem alfa de verdade.
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
		var i := CarroceriaVarrida.inset(q0, q1, q2, q3, RECUO_FRONTAL)
		var fora := CarroceriaVarrida.normal_placa(q0, q1, q3)
		var d := fora * FOLGA_FRONTAL
		var celula := (Carroceria.C_PARABRISA if k == SEG_PARABRISA
			else Carroceria.C_VIDRO_TRAS)
		CarroceriaVarrida.quad(dados, i[0] + d, i[1] + d, i[2] + d, i[3] + d,
			celula, VIDRO_FRENTE, VIDRO_FRENTE, VIDRO_FRENTE, VIDRO_FRENTE,
			fora)


# --------------------------------------------------------------------------
# Arcos de roda
# --------------------------------------------------------------------------

## Contorno do arco, em offsets (dz, dy) a partir do centro da roda.
##
## QUADRADO de canto arredondado, e nao semicirculo: e a assinatura da caixa
## oitentista. Um arco redondo num sedan destes le como carro dos anos 60.
## O pneu tem 0,30 de raio: 6 cm de folga e o que faz ele PREENCHER o arco. Com
## os 12 cm que havia antes sobrava cava escura demais em volta, e como o pneu
## tambem e escuro os dois viravam uma mancha preta unica do tamanho da porta.
const ARCO := [
	Vector2(0.375, 0.00), Vector2(0.335, 0.235), Vector2(0.145, 0.365),
	Vector2(-0.105, 0.355), Vector2(-0.295, 0.255), Vector2(-0.375, 0.00),
]


# --------------------------------------------------------------------------
# Frente
# --------------------------------------------------------------------------

static func _frente(dados: Dictionary, luzes: Dictionary, _cor: Color) -> void:
	var zf := 2.145
	# Grade: painel fundo escuro com ripas horizontais claras por cima. As ripas
	# sao o que a ref mostra de mais longe da frente deste carro.
	CarroceriaVarrida.quad(dados,
		Vector3(-0.40, 0.63, zf), Vector3(0.40, 0.63, zf),
		Vector3(0.40, 0.80, zf), Vector3(-0.40, 0.80, zf),
		Carroceria.C_GRADE, SOMBRA, SOMBRA, SOMBRA, SOMBRA, Vector3.BACK)
	for k in 6:
		var yy := lerpf(0.655, 0.785, float(k) / 5.0)
		CarroceriaVarrida.plana(dados, Vector2(0.76, 0.012),
			Transform3D(Basis(), Vector3(0.0, yy, zf + 0.006)),
			CROMO * 0.86, Carroceria.C_GRADE)

	for s: float in [1.0, -1.0]:
		# Farol RETANGULAR, deitado. Num sedan oitentista ele e largo e baixo;
		# o disco redondo do Fusca aqui daria carro de outra decada.
		CarroceriaVarrida.plana(dados, Vector2(0.30, 0.155),
			Transform3D(Basis(), Vector3(s * 0.545, 0.735, zf + 0.004)),
			Color(0.16, 0.17, 0.19), Carroceria.C_GRADE)
		CarroceriaVarrida.plana(dados, Vector2(0.265, 0.125),
			Transform3D(Basis(), Vector3(s * 0.545, 0.735, zf + 0.010)),
			Color(0.34, 0.37, 0.40), Carroceria.C_FAROL)
		# Aro cromado com a lente recuada dentro (F4).
		CarroceriaVarrida.moldura_luz(dados,
			Transform3D(Basis(), Vector3(s * 0.545, 0.735, zf + 0.004)),
			Vector2(0.265, 0.125), 0.010, 0.016, 0.010, CROMO * 0.9,
			Carroceria.C_PARACHOQUE)
		CarroceriaVarrida.plana(luzes, Vector2(0.235, 0.10),
			Transform3D(Basis(), Vector3(s * 0.545, 0.735, zf + 0.016)),
			Color.WHITE, Carroceria.C_FAROL)
		# Pisca ambar na quina de fora, colado no farol.
		CarroceriaVarrida.plana(luzes, Vector2(0.075, 0.115),
			Transform3D(Basis(), Vector3(s * 0.715, 0.730, zf + 0.010)),
			Color(1.0, 0.66, 0.16), Carroceria.C_PISCA)

	_parachoque(dados, zf + 0.035, 0.50, true)
	CarroceriaVarrida.plana(dados, Vector2(0.30, 0.10),
		Transform3D(Basis(), Vector3(0.0, 0.615, zf + 0.052)),
		Color(0.86, 0.86, 0.84), Carroceria.C_PLACA)

	# Vinco e frestas do capo.
	# Veneziana do cofre e os dois limpadores, NA TAMPA, nao no vidro.
	#
	# A base do para-brisa e a estacao 4 (z=0,88). Qualquer peca com z menor
	# que isso sobe a rampa do vidro e, vista de fora, vira um retangulo preto
	# boiando a frente do para-brisa — o "bug preto voando" da camera 3P.
	# A veneziana mora no meio do capo (z=1,22) e os limpadores no cowl, uns
	# dez centimetros a frente da base do vidro (z=1,00), deitados na chapa.
	for s: float in [1.0, -1.0]:
		var zc := 1.22
		CarroceriaVarrida.plana(dados, Vector2(0.34, 0.055),
			Transform3D(_base_topo(zc),
				_ponto_topo(zc, s * 0.42) + _normal_topo(zc) * 0.008),
			SOMBRA, Carroceria.C_GRADE)
		if not _com_limpadores:
			continue
		var zl := 1.00
		CarroceriaVarrida.plana(dados, Vector2(0.40, 0.018),
			Transform3D(_base_topo(zl) * Basis(Vector3.BACK, s * 0.30),
				_ponto_topo(zl, s * 0.34) + _normal_topo(zl) * 0.014),
			Color(0.18, 0.18, 0.19), Carroceria.C_PARACHOQUE)


# --------------------------------------------------------------------------
# Traseira
# --------------------------------------------------------------------------

static func _traseira(dados: Dictionary, luzes: Dictionary, cor: Color) -> void:
	var zt := -2.145
	var costas := Basis(Vector3.UP, PI)

	# Painel traseiro fundo com a placa recuada dentro dele.
	CarroceriaVarrida.quad(dados,
		Vector3(0.34, 0.66, zt), Vector3(-0.34, 0.66, zt),
		Vector3(-0.34, 0.845, zt), Vector3(0.34, 0.845, zt),
		Carroceria.C_TRASEIRA, SOMBRA * 1.8, SOMBRA * 1.8,
		SOMBRA * 1.6, SOMBRA * 1.6, Vector3.FORWARD)
	CarroceriaVarrida.plana(dados, Vector2(0.30, 0.10),
		Transform3D(costas, Vector3(0.0, 0.75, zt - 0.008)),
		Color(0.84, 0.84, 0.82), Carroceria.C_PLACA)

	for s: float in [1.0, -1.0]:
		# Lanterna alta e retangular, dividida como na ref: vermelho grande,
		# quadrado branco de re no meio-baixo e a tira ambar na quina de fora.
		var lx := s * 0.545
		CarroceriaVarrida.plana(dados, Vector2(0.315, 0.235),
			Transform3D(costas, Vector3(lx, 0.775, zt - 0.004)),
			Color(0.12, 0.12, 0.13), Carroceria.C_GRADE)
		CarroceriaVarrida.moldura_luz(dados,
			Transform3D(costas, Vector3(lx, 0.775, zt - 0.004)),
			Vector2(0.315, 0.235), 0.010, 0.016, 0.016, PLASTICO * 0.7,
			Carroceria.C_PARACHOQUE)
		CarroceriaVarrida.plana(luzes, Vector2(0.185, 0.205),
			Transform3D(costas, Vector3(lx - s * 0.055, 0.775, zt - 0.010)),
			Color.WHITE, Carroceria.C_LANTERNA)
		CarroceriaVarrida.plana(luzes, Vector2(0.085, 0.075),
			Transform3D(costas, Vector3(lx - s * 0.055, 0.715, zt - 0.016)),
			Color.WHITE, Carroceria.C_RE)
		CarroceriaVarrida.plana(luzes, Vector2(0.075, 0.205),
			Transform3D(costas, Vector3(lx + s * 0.105, 0.775, zt - 0.010)),
			Color(1.0, 0.62, 0.14), Carroceria.C_PISCA)

	_parachoque(dados, zt - 0.035, 0.52, false)
	# Escapamento saindo por baixo, do lado do motorista.
	CarroceriaVarrida.plana(dados, Vector2(0.055, 0.05),
		Transform3D(costas, Vector3(0.34, 0.36, zt - 0.05)),
		Color(0.17, 0.16, 0.15), Carroceria.C_PARACHOQUE)

	# Fresta da tampa do porta-malas, e o beicinho da borda de tras.
	var zb := -2.02
	CarroceriaVarrida.plana(dados, Vector2(1.24, 0.030),
		Transform3D(_base_topo(zb), _ponto_topo(zb, 0.0)
			+ _normal_topo(zb) * 0.014),
		_sujo(cor, 1.0) * 1.06, Carroceria.C_TETO)


## Lamina de para-choque, contornando as pontas.
##
## Barra reta le como tabua pregada no bico; para-choque so vira para-choque
## quando dobra para tras nas duas pontas. Tres faces (frente, topo pegando luz
## e a de baixo em sombra) mais a saia escura por baixo, que e o que a ref tem.
static func _parachoque(dados: Dictionary, z: float, y: float,
		frente: bool) -> void:
	var dz := 1.0 if frente else -1.0
	var larg := 0.80
	var alt := 0.135
	var us := [-1.0, -0.62, 0.0, 0.62, 1.0]
	var recuos := [0.16, 0.045, 0.0, 0.045, 0.16]
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
		var recuo := Vector3(0, 0, dz * 0.085)
		CarroceriaVarrida.quad(dados, a0, b0, b1, a1, Carroceria.C_PARACHOQUE,
			CROMO * 1.06, CROMO * 1.06, CROMO * 0.9, CROMO * 0.9, fora)
		CarroceriaVarrida.quad(dados, a0, b0, b0 - recuo, a0 - recuo,
			Carroceria.C_PARACHOQUE, CROMO * 1.16, CROMO * 1.16,
			CROMO * 0.88, CROMO * 0.88, Vector3.UP)
		# Barriga da lamina, RECUANDO para o carro — e nao uma aba caindo reta.
		# Vertical, ela virava uma barra preta de um metro e meio pendurada sob o
		# bico, solta da lataria. Recuada, e so a espessura do para-choque vista
		# de baixo, que e o que a ref mostra.
		CarroceriaVarrida.quad(dados, a1, b1, b1 - recuo, a1 - recuo,
			Carroceria.C_PARACHOQUE, PLASTICO * 0.85, PLASTICO * 0.85,
			SOMBRA, SOMBRA, Vector3.DOWN)


# --------------------------------------------------------------------------
# Flancos: o que faz um sedan de quatro portas ler como um
# --------------------------------------------------------------------------

## Frisos, recortes de porta, macanetas, veneziana da coluna C e retrovisor.
##
## De lado, um sedan tres-volumes e uma chapa de quatro metros. Sem estes riscos
## nao ha o que contar nela — nao da para saber que sao quatro portas, nem onde
## uma acaba e a outra comeca. Custam pouco e sao a maior parte da leitura.
static func _flancos(dados: Dictionary, _cor: Color) -> void:
	# O friso de borracha e cortado em cada fresta de porta: e uma peca por
	# painel, e inteiro ele atravessaria o vinco.
	# So entre as caixas de roda: depois da traseira a cintura cai, e o friso
	# que ia ate o rabo descia em diagonal por cima do arco.
	var cortes: Array = [Z_EIXO_FRENTE - 0.42]
	cortes.append_array(PORTAS)
	cortes.append(Z_EIXO_TRAS + 0.42)
	for s: float in [1.0, -1.0]:
		# Friso de cromo da cintura, logo abaixo das janelas.
		CarroceriaVarrida.friso(dados, PERFIL, OMBRO, s, 0.86, -1.12, 0.02,
			0.014, 0.004, CROMO * 0.95, Carroceria.C_PARACHOQUE, 6)
		# Frisao de borracha na porta, na altura em que a ref bate a sujeira.
		for k in cortes.size() - 1:
			var za: float = float(cortes[k]) - (0.006 if k > 0 else 0.0)
			var zb: float = float(cortes[k + 1]) + (0.006 if k + 1 < cortes.size() - 1 else 0.0)
			CarroceriaVarrida.friso(dados, PERFIL, OMBRO, s, za, zb, -0.245,
				0.034, 0.009, PLASTICO * 1.05, Carroceria.C_PARACHOQUE, 3)
		# Macanetas das duas portas, abaixo da cintura.
		for z: float in [-0.12, -0.74]:
			CarroceriaVarrida.macaneta(dados, PERFIL, OMBRO, s, z, -0.10,
				CROMO * 0.9, Carroceria.C_PARACHOQUE)
		# Veneziana da coluna C: quatro ripas curtas, detalhe de decada.
		var fora := Vector3(s, 0.0, 0.0)
		for k in 4:
			var yy := 0.10 + float(k) * 0.055
			CarroceriaVarrida.plana(dados, Vector2(0.115, 0.016),
				Transform3D(Basis(Vector3.UP, s * PI * 0.5),
					_ponto_lado(-1.14, yy, s) + fora * 0.004),
				SOMBRA, Carroceria.C_GRADE)

	# Retrovisor, so do lado do motorista. Depois da meia volta que a Carroceria
	# aplica, o +X daqui vira o -X do mundo, que e onde fica o volante.
	var raiz := _ponto_lado(0.80, 0.16, 1.0)
	var esp := raiz + Vector3(0.075, 0.035, 0.02)
	CarroceriaVarrida.plana(dados, Vector2(0.085, 0.055),
		Transform3D(Basis(Vector3.UP, 0.26), esp),
		Carroceria.marcar(Color(0.28, 0.32, 0.36), Carroceria.Classe.ESPELHO),
		Carroceria.C_VIDRO_LADO)
	CarroceriaVarrida.plana(dados, Vector2(0.085, 0.055),
		Transform3D(Basis(Vector3.UP, PI + 0.26), esp),
		PLASTICO, Carroceria.C_PARACHOQUE)
	CarroceriaVarrida.quad(dados, raiz, esp + Vector3(0.0, -0.024, 0.0),
		esp + Vector3(0.0, -0.024, 0.028), raiz + Vector3(0.0, 0.0, 0.028),
		Carroceria.C_PARACHOQUE, PLASTICO, PLASTICO, PLASTICO, PLASTICO,
		Vector3.UP)
