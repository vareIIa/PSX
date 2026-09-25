## O Fusca. Chapa lisa, e nao casco facetado.
##
## Historia curta
## --------------
## A primeira versao empilhava caixas. A segunda varria um anel de OITO pontos
## por dezesseis estacoes: acertou a silhueta de lado (o arco continuo do
## para-choque ao para-choque), mas cada faixa do anel saia chapada — teto reto,
## ombro em quina, para-lama de oito costelas — e com o verniz do MODERNO o
## carro lia como poliedro. O jogador resumiu em 24/09/2026: "nao parece um
## Fusca", e mandou quatro fotos de um Fusca 1600 1984 limpo, bege, polido
## (PRINTS/ref_fusca_aaa). Esta e a terceira.
##
## O que mudou
## -----------
##   * PERFIL continua sendo a verdade da silhueta e da cabine (a casca interna,
##     os vidros de dentro, a agua e o limpador leem dele), mas o exterior nao
##     e mais o anel de oito pontos. Cada coluna do perfil e interpolada em Z
##     por Hermite monotono (`ChapaLisa.pchip`) e a secao e uma curva de
##     Hermite pelos mesmos pontos do anel — soleira, cintura, ombro e quina do
##     teto —, fechando por cima numa COPA (a cupula que o teto chapado nao
##     tinha). A curva passa pelos pontos do anel e estufa para fora entre
##     eles, entao a casca interna continua dentro da chapa.
##   * Tudo que e curvo sai de `ChapaLisa`: grade com normal da superficie,
##     vertices compartilhados, giro pela normal.
##   * Para-lama e uma gota varrida em 24 costelas por 16 pontos de secao, com
##     o cordao de vedacao onde encosta na carroceria.
##   * Farol redondo de verdade: caneca na cor do carro, aro cromado de perfil
##     redondo e lente abaulada com o refletor atras. Lanterna "Fafa" grande no
##     para-lama traseiro, ambar em cima e vermelho embaixo.
##   * Para-choque de lamina cromada com friso de borracha, que dobra nas
##     pontas; estribo de borracha canelada com friso de aluminio.
##   * Portas, capo e tampa do motor sao vinco na chapa; janelas com borracha e
##     moldura cromada; calha de chuva; venezianas da tampa; escapamento duplo.
##
## Coordenadas: +Z na frente, Y para cima, X para a direita, chao em y = 0 e a
## origem no meio do carro. `Carroceria` da a meia volta depois.
##
## Sem class_name de proposito: ver Carroceria._modulo().
extends RefCounted

## Medidas do Fusca real, em metros. `montar` escala se MEDIDAS pedir outra.
const COMP_REF := 4.03
const LARG_REF := 1.55
const ALT_REF := 1.50

## Eixos. Entre-eixos de 2,40 m, roda de 0,30 m de raio.
const Z_EIXO_FRENTE := 1.20
const Z_EIXO_TRAS := -1.20
const Y_EIXO := 0.30

## O besouro visto de lado, da frente para tras.
##
##   z      estacao
##   bot    assoalho
##   cint   linha de cintura (base das janelas)
##   topo   a QUINA do teto: onde a lateral vira teto
##   w_*    meia-largura em cada uma das tres alturas
##
## A silhueta de lado e `topo + COPA`: a copa e quanto o meio do teto (ou do
## capo, ou da tampa) sobe acima da quina. A tabela antiga tinha o teto chato,
## entao `topo` ERA a silhueta; aqui a silhueta medida em PRINTS/ref_fusca foi
## preservada e repartida entre quina e copa.
##
## Por que o teto estreitou (w_topo de 0,47 para 0,36)
## ---------------------------------------------------
## Com a quina a 0,47 m do meio o teto era uma mesa de 94 cm, e nenhuma cupula
## lisa passa por fora de uma mesa sem subir 25 cm acima do carro. O teto do
## Fusca e um arco: a 47 cm do meio ele ja desceu uns 8 cm. A quina recolhida
## e o que deixa a chapa ser redonda E conter a cabine. O para-brisa e o vigia
## ficam largos, porque o vidro plano deles mora entre as duas quinas.
const PERFIL := [
	# z      bot   cint  topo   w_bot w_cint w_topo
	[ 1.90,  0.36, 0.52, 0.55,  0.30, 0.40,  0.22],  # bico
	[ 1.74,  0.31, 0.58, 0.64,  0.35, 0.47,  0.26],  # frente do capo
	[ 1.50,  0.29, 0.64, 0.75,  0.38, 0.51,  0.29],  # capo
	[ 1.18,  0.28, 0.71, 0.86,  0.40, 0.53,  0.31],  # capo, sobre o eixo
	[ 0.86,  0.27, 0.79, 0.96,  0.45, 0.57,  0.36],  # cofre
	[ 0.62,  0.26, 0.87, 1.13,  0.48, 0.60,  0.48],  # base do para-brisa
	[ 0.40,  0.26, 0.91, 1.41,  0.49, 0.61,  0.42],  # topo do para-brisa
	[ 0.05,  0.26, 0.93, 1.455, 0.50, 0.62,  0.36],  # teto, frente
	[-0.30,  0.26, 0.94, 1.465, 0.50, 0.62,  0.33],  # cume
	[-0.66,  0.26, 0.94, 1.445, 0.50, 0.62,  0.34],  # teto, tras
	[-1.00,  0.27, 0.93, 1.35,  0.49, 0.61,  0.37],  # topo do vigia
	[-1.26,  0.29, 0.90, 1.13,  0.47, 0.59,  0.39],  # base do vigia
	[-1.48,  0.31, 0.83, 0.95,  0.46, 0.57,  0.33],  # tampa do motor
	[-1.68,  0.34, 0.70, 0.77,  0.45, 0.54,  0.29],  # tras
	[-1.79,  0.36, 0.50, 0.54,  0.40, 0.49,  0.25],  # rabo
	[-1.87,  0.34, 0.36, 0.38,  0.31, 0.40,  0.19],  # tampa
]
## Quanto o meio sobe acima da quina em cada estacao. Quase nada nas quatro
## estacoes do para-brisa e do vigia: o vidro de fora e a propria chapa
## amostrada sobre o vao, entao a copa ali e a curvatura do vidro — zero na
## base do para-brisa, um pouco no alto e no vigia, como o vidro de verdade.
## O vidro da cabine continua plano, por dentro deste.
const COPA := [0.01, 0.025, 0.04, 0.05, 0.05, 0.0, 0.03, 0.04, 0.045, 0.04,
	0.02, 0.012, 0.03, 0.04, 0.03, 0.01]

## Indices de estacao que delimitam para-brisa e vigia. O trecho entre k e k+1
## e interpolado RETO (vidro plano), e a janela e a coluna A saem do mesmo par.
const SEG_PARABRISA := 5
const SEG_VIGIA := 10

## As tres janelas de cada lado, em (z0, z1, t0, t1): quebra-vento, porta e a
## fixa traseira. `aberturas()` le a MESMA tabela. Ver `AberturasVidro`.
const VAOS_LADO := [
	[0.58, 0.42, 0.14, 0.74],   # quebra-vento, atras da coluna
	[0.38, -0.44, 0.10, 0.74],  # porta
	[-0.58, -0.97, 0.10, 0.66], # fixa traseira
]
## Colagem do vidro da cabine por fora da chapa e a moldura do para-brisa e do
## vigia (a borracha do Fusca e grossa).
const FOLGA_VIDRO := 0.012
const FOLGA_FRONTAL := 0.010
const RECUO_FRONTAL := 0.13

## Onde fica o ombro do anel: 76% da altura, 25% da largura. Era 66/34: a
## janela de lado acabava a 1,30 m e o teto comecava num ombro baixo e
## quadrado. No Fusca a janela sobe ate a calha, perto de 1,34 m, e a cupula
## nasce ali.
const OMBRO := Vector2(0.76, 0.25)

# --- cores ------------------------------------------------------------------

const VIDRO := Color(0.17, 0.20, 0.23)
const VIDRO_FRENTE := Color(0.26, 0.31, 0.35)
const CROMO := Color(0.84, 0.84, 0.86)
const BORRACHA := Color(0.045, 0.045, 0.05)
const PLASTICO := Color(0.075, 0.075, 0.08)
const FUNDO := Color(0.07, 0.065, 0.06)
const ACO_ESCURO := Color(0.16, 0.16, 0.17)

# --- vinco, vao e moldura ---------------------------------------------------

## Vinco de porta, capo e tampa: meia boca e fundo do V, em metros.
const VINCO_MEIA := 0.0045
const VINCO_FUNDO := 0.0055
const VINCO_ESCURO := 0.32
## Espessura da porta em volta de cada vao, vista pela janela.
const FUNDO_VAO := 0.035
## Quanto o vidro de fora fica recuado na borracha.
const RECUO_VIDRO := 0.004

## Portas e tampas, em (z, a) da secao. `a` e o parametro do anel: -1 na
## soleira, 0 na cintura, 1 na quina do teto, 2 no meio do teto.
const PORTA_Z := [0.60, -0.50]
const PORTA_A_BAIXO := -0.84
const PORTA_A_CIMA := 0.82
## Capo e tampa na MESMA coluna do anel: cada vinco em `a` corta a grade de
## ponta a ponta (tres colunas), e dois vincos a 2 cm um do outro eram seis
## colunas a mais no carro inteiro para ninguem ver a diferenca.
const CAPO := {"a": 1.18, "z0": 0.90, "z1": 1.84}
const TAMPA := {"a": 1.18, "z0": -1.30, "z1": -1.80}

# --- para-lamas ---------------------------------------------------------------

## Raio da boca da caixa de roda. A roda tem 0,30.
const R_BOCA := 0.385
## Meia-largura maxima do carro, na barriga do para-lama.
const X_PARALAMA := 0.775

## Cada para-lama em costelas: angulo em volta do eixo (0 = frente, 90 = em
## cima, 180 = tras), raio da linha de cima, meia-largura da barriga e quanto a
## juncao com a carroceria fica abaixo da linha de cima.
##
## O dianteiro sobe do para-choque, faz a sobrancelha do farol entre 30 e 50
## graus e desce ate o estribo. O traseiro e mais cheio, e a lanterna mora na
## rampa de tras, perto dos 140 graus.
const PARALAMA_FRENTE := [
	# graus  raio   barriga  juncao
	[  4.0,  0.555, 0.640,  0.090],
	[ 16.0,  0.610, 0.690,  0.115],
	[ 30.0,  0.645, 0.715,  0.135],
	[ 45.0,  0.660, 0.735,  0.150],
	[ 60.0,  0.645, 0.755,  0.155],
	[ 75.0,  0.625, 0.770,  0.150],
	[ 90.0,  0.612, 0.775,  0.145],
	[105.0,  0.612, 0.772,  0.140],
	[120.0,  0.622, 0.765,  0.130],
	[135.0,  0.625, 0.752,  0.120],
	[150.0,  0.612, 0.735,  0.105],
	[163.0,  0.585, 0.715,  0.090],
	[174.0,  0.545, 0.700,  0.070],
]
const PARALAMA_TRAS := [
	[  6.0,  0.545, 0.700,  0.070],
	[ 18.0,  0.590, 0.720,  0.095],
	[ 33.0,  0.620, 0.745,  0.120],
	[ 50.0,  0.632, 0.765,  0.135],
	[ 68.0,  0.635, 0.775,  0.145],
	[ 86.0,  0.640, 0.775,  0.150],
	[104.0,  0.652, 0.772,  0.150],
	[120.0,  0.665, 0.765,  0.145],
	[134.0,  0.672, 0.752,  0.140],
	[147.0,  0.662, 0.735,  0.130],
	[158.0,  0.635, 0.712,  0.110],
	[168.0,  0.590, 0.680,  0.085],
]

# --- estribo, farol, lanterna, para-choque -------------------------------------

const ESTRIBO_Y := 0.335
const ESTRIBO_X := 0.705
const ESTRIBO_Z := [0.66, -0.64]

## Centro da lente do farol e o quanto ela olha para cima e para fora.
const FAROL := Vector3(0.555, 0.668, 1.775)
const FAROL_R := 0.112
const FAROL_INCLINA := 0.10
const FAROL_ABRE := 0.05

## Centro da lanterna traseira e o tamanho da lente (meia largura, meia altura).
const LANTERNA := Vector3(0.600, 0.690, -1.742)
const LANTERNA_MEIA := Vector2(0.080, 0.128)
## Onde o ambar acaba e o vermelho comeca, na altura da lente (-1 a 1), e o
## quanto a lente estufa no meio.
const DIVISA_LANTERNA := 0.22
const BOJO_LANTERNA := 0.018

const PARACHOQUE_FRENTE := {"z": 1.985, "y": 0.482}
const PARACHOQUE_TRAS := {"z": -1.975, "y": 0.492}


# ==========================================================================
# API usada pela cabine e pela Carroceria
# ==========================================================================

## O perfil deste carro, para quem gera a casca INTERNA dele. Ver `CabineCasca`.
static func perfil_cabine(comp: float, larg: float, teto: float) -> Dictionary:
	return {
		"perfil": PERFIL, "ombro": OMBRO, "vaos": VAOS_LADO,
		"seg_p": SEG_PARABRISA, "seg_v": SEG_VIGIA,
		"recuo_frontal": RECUO_FRONTAL, "folga_vidro": FOLGA_VIDRO,
		"folga_frontal": FOLGA_FRONTAL,
		"escala": Vector3(larg / LARG_REF, teto / ALT_REF, comp / COMP_REF),
	}


## Onde estao os vidros deste carro, no espaco final da lataria.
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
##
## `cor` entra LINEAR em toda cor de vertice pintada (so multiplicacao), porque
## o cache da Carroceria monta o carro em preto e em branco e tinge por conta.
static func montar(corpo: Dictionary, luzes: Dictionary, comp: float,
		larg: float, teto: float, cor: Color, com_vidros_frente: bool) -> void:
	var c := PSXMesh.dados_vazios()
	var l := PSXMesh.dados_vazios()
	var fino := not CarroceriaVarrida.simples

	_casco(c, cor, fino, com_vidros_frente)
	_paralamas(c, cor, fino)
	_estribos(c, fino)
	_farois(c, l, cor, fino)
	_lanternas(c, l, cor, fino)
	_parachoques(c, fino)
	_placas(c, l, cor, fino)
	if fino:
		_janelas_e_frisos(c, cor)
		_capo_e_tampa(c, cor)
		_detalhes_lado(c, cor)
		_baixo(c)

	var e := Vector3(larg / LARG_REF, teto / ALT_REF, comp / COMP_REF)
	var xf := Transform3D(Basis().scaled(e), Vector3.ZERO)
	PSXMesh.acumular(corpo, c, xf)
	PSXMesh.acumular(luzes, l, xf)


# ==========================================================================
# Perfil liso
# ==========================================================================

## As colunas do perfil em Z CRESCENTE, que e o que o Hermite quer: z, e depois
## bot, cint, topo, w_bot, w_cint, w_topo, copa.
static var _zs := PackedFloat64Array()
static var _colunas: Array = []
static var _retos := PackedInt32Array()


static func _preparar() -> void:
	if not _zs.is_empty():
		return
	var n := PERFIL.size()
	for k in range(n - 1, -1, -1):
		_zs.append(float(PERFIL[k][0]))
	for col in 7:
		var valores := PackedFloat64Array()
		for k in range(n - 1, -1, -1):
			valores.append(float(PERFIL[k][col + 1]) if col < 6 else float(COPA[k]))
		_colunas.append(valores)
	# O trecho k do PERFIL (entre k e k+1) e o trecho n-2-k na ordem crescente.
	_retos = PackedInt32Array([n - 2 - SEG_PARABRISA, n - 2 - SEG_VIGIA])


## A estacao lisa num Z: [bot, cint, topo, w_bot, w_cint, w_topo, copa].
static func _est(z: float) -> PackedFloat64Array:
	_preparar()
	var e := PackedFloat64Array()
	e.resize(7)
	for col in 7:
		e[col] = ChapaLisa.pchip(_zs, _colunas[col] as PackedFloat64Array, z, _retos)
	return e


## A secao do lado direito, (x, y), num `a` de -1 (soleira) a 2 (meio do teto).
##
## Abaixo da quina e um Hermite pelos pontos do anel antigo — soleira,
## cintura, ombro e quina —, com as tangentes de Catmull-Rom: a curva passa
## pelos pontos e estufa entre eles. A tangente na soleira aponta para baixo e
## para dentro, que e a chapa dobrando para o assoalho. Acima da quina e a
## copa: uma parabola da quina ao meio, e a tangente dela na quina e a mesma
## que o Hermite de baixo usa, entao o ombro nao tem vinco.
static func _secao(e: PackedFloat64Array, a: float) -> Vector2:
	var bot := e[0]
	var cint := e[1]
	var topo := e[2]
	var wb := e[3]
	var wc := e[4]
	var wt := e[5]
	var copa := e[6]
	if a >= 1.0:
		var u := clampf(2.0 - a, 0.0, 1.0)
		return Vector2(u * wt, topo + copa * (1.0 - u * u))
	var om := OMBRO.x
	var p_bot := Vector2(wb, bot)
	var p_cint := Vector2(wc, cint)
	var p_omb := Vector2(lerpf(wc, wt, OMBRO.y), lerpf(cint, topo, om))
	var p_top := Vector2(wt, topo)
	var q0 := Vector2(wb - 0.10, bot - 0.035)
	var m_bot := (p_cint - q0) / 1.35
	var m_cint := (p_omb - p_bot) / (om + 1.0)
	var m_omb := p_top - p_cint
	var m_top := Vector2(-wt, 2.0 * copa)
	if a < -1.0:
		return p_bot
	if a < 0.0:
		return ChapaLisa.hermite(p_bot, m_bot, p_cint, m_cint, a + 1.0)
	if a < om:
		return ChapaLisa.hermite(p_cint, m_cint * om, p_omb, m_omb * om, a / om)
	var h := 1.0 - om
	return ChapaLisa.hermite(p_omb, m_omb * h, p_top, m_top * h, (a - om) / h)


## Parametro do anel inteiro, A de -1 a 5: -1 a 2 e o lado direito da soleira
## ao meio do teto, 2 a 5 o esquerdo do meio do teto a soleira.
static func _ponto_anel(e: PackedFloat64Array, z: float, aa: float) -> Vector3:
	if aa <= 2.0:
		var p := _secao(e, aa)
		return Vector3(p.x, p.y, z)
	var q := _secao(e, 4.0 - aa)
	return Vector3(-q.x, q.y, z)


static func _ponto(z: float, a: float, s: float) -> Vector3:
	var p := _secao(_est(z), a)
	return Vector3(s * p.x, p.y, z)


## A normal da chapa num (z, a, s), por diferenca.
static func _normal(z: float, a: float, s: float) -> Vector3:
	var da := 0.01
	var dz := 0.01
	var pa := _ponto(z, minf(a + da, 2.0), s) - _ponto(z, maxf(a - da, -1.0), s)
	var pz := _ponto(z + dz, a, s) - _ponto(z - dz, a, s)
	var n := pz.cross(pa).normalized()
	if s < 0.0:
		n = -n
	# Conferencia: fora e para longe do eixo do carro.
	var p := _ponto(z, a, s)
	var e := _est(z)
	var centro := Vector3(0.0, (e[0] + e[2]) * 0.5, z)
	if n.dot(p - centro) < 0.0:
		n = -n
	return n


## Meia-largura da carroceria numa altura, pela secao lisa (bisseccao em `a`).
## E onde o para-lama, o estribo e o cordao encostam.
static func _x_corpo(z: float, y: float) -> float:
	var e := _est(z)
	if y <= e[0]:
		return e[3]
	var lo := -1.0
	var hi := 2.0
	if y >= _secao(e, hi).y:
		return 0.0
	for _i in 30:
		var m := (lo + hi) * 0.5
		if _secao(e, m).y < y:
			lo = m
		else:
			hi = m
	return _secao(e, (lo + hi) * 0.5).x


# ==========================================================================
# Casco
# ==========================================================================

## Linhas de corte da grade. Um vinco so existe se houver vertice NO FUNDO dele
## e dos dois lados da boca; uma janela so tem borda reta se a grade passar
## exatamente pela borda. Os cortes sao essas linhas; o passo base preenche o
## resto.
static func _cortes_z(fino: bool) -> PackedFloat64Array:
	var z0 := float(PERFIL[PERFIL.size() - 1][0])
	var z1 := float(PERFIL[0][0])
	var passo := 0.075 if fino else 0.20
	var obrig: Array[float] = []
	for est: Array in PERFIL:
		obrig.append(float(est[0]))
	for v: Array in VAOS_LADO:
		obrig.append(float(v[0]))
		obrig.append(float(v[1]))
	for k: int in [SEG_PARABRISA, SEG_VIGIA]:
		var zr := _z_frontal(k)
		obrig.append(zr.x)
		obrig.append(zr.y)
	if fino:
		for z: float in PORTA_Z:
			obrig.append_array([z - VINCO_MEIA, z, z + VINCO_MEIA])
		for g: Dictionary in [CAPO, TAMPA]:
			for z: float in [float(g["z0"]), float(g["z1"])]:
				obrig.append_array([z - VINCO_MEIA, z, z + VINCO_MEIA])
	return _juntar(z0, z1, passo, obrig)


## O Z da borda de dentro do vidro frontal, pelo recuo da moldura: [frente, tras].
static func _z_frontal(k: int) -> Vector2:
	var za := float(PERFIL[k][0])
	var zb := float(PERFIL[k + 1][0])
	var zc := (za + zb) * 0.5
	return Vector2(za + (zc - za) * RECUO_FRONTAL, zb + (zc - zb) * RECUO_FRONTAL)


## Cortes em `a` de um lado (-1 a 2).
static func _cortes_a(fino: bool) -> PackedFloat64Array:
	var obrig: Array[float] = [0.0, OMBRO.x, 1.0]
	for v: Array in VAOS_LADO:
		obrig.append(float(v[2]))
		obrig.append(float(v[3]))
	obrig.append(2.0 - (1.0 - RECUO_FRONTAL))
	if fino:
		var ma := 0.012
		obrig.append_array([PORTA_A_BAIXO - ma, PORTA_A_BAIXO, PORTA_A_BAIXO + ma])
		obrig.append_array([PORTA_A_CIMA - ma, PORTA_A_CIMA, PORTA_A_CIMA + ma])
		for g: Dictionary in [CAPO, TAMPA]:
			var a: float = g["a"]
			obrig.append_array([a - ma, a, a + ma])
	var lado := PackedFloat64Array()
	var trechos := [[-1.0, 0.0, 0.17 if fino else 0.5],
		[0.0, 1.0, 0.09 if fino else 0.34], [1.0, 2.0, 0.11 if fino else 0.5]]
	for t: Array in trechos:
		var sub := _juntar(float(t[0]), float(t[1]), float(t[2]), obrig)
		for x in sub:
			if lado.is_empty() or x > lado[lado.size() - 1] + 1e-5:
				lado.append(x)
	return lado


## Junta o passo base com os cortes obrigatorios, sem lasca: amostra base a
## menos de um terco do passo de um corte sai.
static func _juntar(de: float, ate: float, passo: float,
		obrig: Array[float]) -> PackedFloat64Array:
	var dentro: Array[float] = [de, ate]
	for x: float in obrig:
		if x > de + 1e-5 and x < ate - 1e-5:
			dentro.append(x)
	var n := maxi(1, ceili((ate - de) / passo))
	for k in range(1, n):
		var x := lerpf(de, ate, float(k) / float(n))
		var perto := false
		for o: float in dentro:
			if absf(o - x) < passo * 0.34:
				perto = true
				break
		if not perto:
			dentro.append(x)
	dentro.sort()
	var out := PackedFloat64Array()
	for x: float in dentro:
		if out.is_empty() or x > out[out.size() - 1] + 1e-5:
			out.append(x)
	return out


## O anel inteiro em A (-1 a 5), a partir dos cortes de um lado.
static func _anel(lado: PackedFloat64Array) -> PackedFloat64Array:
	var out := PackedFloat64Array(lado)
	for k in range(lado.size() - 2, -1, -1):
		out.append(4.0 - lado[k])
	return out


## O lado (a, s) de um A do anel.
static func _lado_de(aa: float) -> Vector2:
	return Vector2(aa, 1.0) if aa <= 2.0 else Vector2(4.0 - aa, -1.0)


## O vao em que um ponto (z, a) cai, como [z_frente, z_tras, a_baixo, a_cima],
## ou vazio. Laterais e frontais.
static func _vaos_param() -> Array:
	var out: Array = []
	for v: Array in VAOS_LADO:
		out.append([float(v[0]), float(v[1]), float(v[2]), float(v[3])])
	for k: int in [SEG_PARABRISA, SEG_VIGIA]:
		var zr := _z_frontal(k)
		out.append([zr.x, zr.y, 2.0 - (1.0 - RECUO_FRONTAL), 2.0])
	return out


static func _no_vao(vaos: Array, z: float, a: float) -> bool:
	for v: Array in vaos:
		if z < float(v[0]) and z > float(v[1]) and a > float(v[2]) and a < float(v[3]):
			return true
	return false


## O vertice (z, a) esta no fundo de um vinco?
static func _no_vinco(z: float, a: float) -> bool:
	var e := 1e-4
	for zp: float in PORTA_Z:
		if absf(z - zp) < e and a > PORTA_A_BAIXO + e and a < PORTA_A_CIMA - e:
			return true
	for ap: float in [PORTA_A_BAIXO, PORTA_A_CIMA]:
		if absf(a - ap) < e and z < float(PORTA_Z[0]) - e and z > float(PORTA_Z[1]) + e:
			return true
	for g: Dictionary in [CAPO, TAMPA]:
		var ga: float = g["a"]
		var za: float = maxf(float(g["z0"]), float(g["z1"]))
		var zb: float = minf(float(g["z0"]), float(g["z1"]))
		if absf(a - ga) < e and z < za - e and z > zb + e:
			return true
		for zg: float in [za, zb]:
			if absf(z - zg) < e and a > ga + e:
				return true
	return false


## O casco: lados, teto, capo e tampa numa grade so, com os vaos furados, os
## vincos afundados, o vidro nos vaos, o assoalho e as duas pontas arredondadas.
## Devolve os cortes, que as molduras usam.
static func _casco(dados: Dictionary, cor: Color, fino: bool,
		com_vidros_frente: bool) -> Dictionary:
	var zs := _cortes_z(fino)
	var lado := _cortes_a(fino)
	var aas := _anel(lado)
	var vaos := _vaos_param()
	var linhas: Array = []
	var cores: Array = []
	var centros := PackedVector3Array()
	var estacoes: Array = []
	for z in zs:
		var e := _est(z)
		estacoes.append(e)
		var linha := PackedVector3Array()
		for aa in aas:
			linha.append(_ponto_anel(e, z, aa))
		linhas.append(linha)
		centros.append(Vector3(0.0, (e[0] + e[2]) * 0.5, z))
	# Vinco: afunda o vertice do fundo ao longo da normal da chapa ainda lisa.
	var normais := ChapaLisa.normais_da_grade(linhas, 1.0, centros)
	for j in zs.size():
		var linha: PackedVector3Array = linhas[j]
		var nl: PackedVector3Array = normais[j]
		var cl := PackedColorArray()
		for k in aas.size():
			var ls := _lado_de(aas[k])
			var tom := _ao(linha[k], nl[k])
			if fino and _no_vinco(zs[j], ls.x):
				linha[k] -= nl[k] * VINCO_FUNDO
				tom *= VINCO_ESCURO
			cl.append(Color(cor.r * tom, cor.g * tom, cor.b * tom, 1.0))
		linhas[j] = linha
		cores.append(cl)
	var furo := func(j: int, k: int) -> bool:
		var zm := (zs[j] + zs[j + 1]) * 0.5
		var ls := _lado_de((aas[k] + aas[k + 1]) * 0.5)
		return _no_vao(vaos, zm, ls.x)
	ChapaLisa.grade(dados, linhas, cores, cor, Carroceria.C_LATARIA, 1.0, centros,
		false, furo, normais)

	_assoalho(dados, zs, estacoes)
	_ponta(dados, zs, aas, estacoes, true, cor, fino)
	_ponta(dados, zs, aas, estacoes, false, cor, fino)
	_vidros(dados, zs, lado, vaos, com_vidros_frente)
	_bordas_de_vao(dados, vaos, cor, fino)
	return {"zs": zs, "lado": lado, "vaos": vaos}


## Oclusao assada de leve: a chapa que olha para o chao e a barra da soleira
## pegam menos ceu. So multiplica — a tinta continua linear.
static func _ao(p: Vector3, n: Vector3) -> float:
	var baixo := clampf(-n.y, 0.0, 1.0)
	var chao := clampf((0.55 - p.y) / 0.35, 0.0, 1.0)
	return 1.0 - baixo * 0.22 - chao * 0.08


static func _assoalho(dados: Dictionary, zs: PackedFloat64Array,
		estacoes: Array) -> void:
	var linhas: Array = []
	for j in zs.size():
		var e: PackedFloat64Array = estacoes[j]
		linhas.append(PackedVector3Array([Vector3(e[3], e[0], zs[j]),
			Vector3(0.0, e[0] - 0.004, zs[j]), Vector3(-e[3], e[0], zs[j])]))
	var fundo := Carroceria.marcar(FUNDO, Carroceria.Classe.FUNDO)
	ChapaLisa.grade(dados, linhas, [], fundo, Carroceria.C_FUNDO, 1.0,
		PackedVector3Array(), false)
	# O sinal da grade depende do sentido de zs e do anel; confere pela normal.
	_virar_ultima_para(dados, linhas.size() * 3, Vector3.DOWN)


## Confere que a ultima grade emitida (`quantos` vertices) olha para `fora` e
## vira normal e giro se nao olhar. Para placa plana, em que "longe do eixo"
## nao quer dizer nada.
static func _virar_ultima_para(dados: Dictionary, quantos: int, fora: Vector3) -> void:
	var n: PackedVector3Array = dados["n"]
	var ii: PackedInt32Array = dados["i"]
	var ini := n.size() - quantos
	if ini < 0 or n[ini].dot(fora) >= 0.0:
		return
	for k in range(ini, n.size()):
		n[k] = -n[k]
	for t in range(0, ii.size(), 3):
		if ii[t] >= ini:
			var tmp := ii[t + 1]
			ii[t + 1] = ii[t + 2]
			ii[t + 2] = tmp
	dados["n"] = n
	dados["i"] = ii


## A ponta do bico (ou do rabo), arredondada: o ultimo anel encolhe para o
## proprio centro num quarto de elipse e fecha num leque. A tabela antiga
## acabava numa tampa plana — de frente, um recorte de papelao atras do
## para-choque.
static func _ponta(dados: Dictionary, zs: PackedFloat64Array, aas: PackedFloat64Array,
		estacoes: Array, frente: bool, cor: Color, fino: bool) -> void:
	var j := zs.size() - 1 if frente else 0
	var e: PackedFloat64Array = estacoes[j]
	var z := zs[j]
	var dz := 1.0 if frente else -1.0
	var fundo := 0.05 if frente else 0.06
	var contorno := PackedVector3Array()
	for aa in aas:
		contorno.append(_ponto_anel(e, z, aa))
	# Fecha por baixo, pelo assoalho.
	contorno.append(Vector3(0.0, e[0] - 0.004, z))
	contorno.append(contorno[0])
	var centro := Vector3.ZERO
	for p in contorno:
		centro += p / float(contorno.size())
	var angs := [0.0, 25.0, 50.0, 72.0] if fino else [0.0, 60.0]
	var linhas: Array = []
	var cores: Array = []
	var centros := PackedVector3Array()
	for g: float in angs:
		var r := deg_to_rad(g)
		var linha := PackedVector3Array()
		var cl := PackedColorArray()
		for p in contorno:
			var q := centro + (p - centro) * cos(r)
			q.z = z + dz * fundo * sin(r)
			linha.append(q)
			cl.append(Color(cor.r, cor.g, cor.b, 1.0) * _ao(q, Vector3(0, -0.3, dz)))
		linhas.append(linha)
		cores.append(cl)
		centros.append(Vector3(centro.x, centro.y, z - dz * 0.4))
	ChapaLisa.grade(dados, linhas, cores, cor, Carroceria.C_LATARIA, 1.0, centros, true)
	var ultimo: PackedVector3Array = linhas[linhas.size() - 1]
	var c_final := Vector3(centro.x, centro.y, z + dz * fundo)
	ChapaLisa.leque(dados, ultimo, c_final, Vector3(0, 0, dz),
		Color(cor.r, cor.g, cor.b, 1.0), Carroceria.C_LATARIA)


## Vidro de fora em cada vao: a propria chapa amostrada sobre o vao, recuada
## na borracha. A chapa e o vidro saem da mesma funcao, entao o vidro encaixa
## no furo em qualquer curva.
static func _vidros(dados: Dictionary, zs: PackedFloat64Array,
		lado: PackedFloat64Array, vaos: Array, com_vidros_frente: bool) -> void:
	for iv in vaos.size():
		var v: Array = vaos[iv]
		var frontal := iv >= VAOS_LADO.size()
		if frontal and not com_vidros_frente:
			continue
		var celula := Carroceria.C_VIDRO_LADO
		var tom := VIDRO
		if frontal:
			tom = VIDRO_FRENTE
			celula = Carroceria.C_PARABRISA if iv == VAOS_LADO.size() else Carroceria.C_VIDRO_TRAS
		var zz := _sub(zs, float(v[1]), float(v[0]))
		var la := _sub(lado, float(v[2]), float(v[3]))
		var lados: Array = [1.0] if frontal else [1.0, -1.0]
		for s: float in lados:
			var aa := PackedFloat64Array()
			if frontal:
				# De uma borda a outra, passando pelo meio do teto.
				for x in la:
					aa.append(x)
				for k in range(la.size() - 2, -1, -1):
					aa.append(4.0 - la[k])
			else:
				aa = la
			var linhas: Array = []
			var centros := PackedVector3Array()
			for z in zz:
				var e := _est(z)
				var linha := PackedVector3Array()
				for a in aa:
					var p := _ponto_anel(e, z, a) if frontal else _ponto(z, a, s)
					linha.append(p)
				linhas.append(linha)
				centros.append(Vector3(0.0, (e[0] + e[2]) * 0.5, z))
			var normais := ChapaLisa.normais_da_grade(linhas, 1.0, centros)
			for j in linhas.size():
				var linha: PackedVector3Array = linhas[j]
				var nl: PackedVector3Array = normais[j]
				for k in linha.size():
					linha[k] -= nl[k] * RECUO_VIDRO
				linhas[j] = linha
			ChapaLisa.grade(dados, linhas, [], tom, celula, 1.0, centros)


## Os cortes de uma lista entre dois valores, inclusive as pontas.
static func _sub(lista: PackedFloat64Array, de: float, ate: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for x in lista:
		if x >= de - 1e-5 and x <= ate + 1e-5:
			out.append(x)
	return out


## Raio dos cantos de cada vao, em metros, na ordem do laco: frente-baixo,
## frente-cima, tras-cima, tras-baixo (nos frontais "frente" e o lado de +Z:
## a base do para-brisa e o alto do vigia). Janela de Fusca nao tem quina: a
## fixa de tras e quase uma gota, e o vigia e um retangulo de cantos gordos.
const CANTOS_VAO := [
	[0.025, 0.030, 0.020, 0.020],   # quebra-vento
	[0.030, 0.035, 0.075, 0.030],   # porta
	[0.035, 0.050, 0.140, 0.090],   # fixa traseira
	[0.060, 0.070, 0.070, 0.060],   # para-brisa
	[0.110, 0.110, 0.090, 0.090],   # vigia
]


## O contorno de um vao com os cantos arredondados, na chapa.
##
## A grade do casco so fura retangulo em (z, a): arredondar pelo furo pediria
## uma grade fina so para os cantos. Entao o furo continua retangular, e cada
## canto ganha um leque de chapa pintada entre a quina do retangulo e o arco —
## e a borracha, a moldura e a espessura da porta seguem o ARCO. Visto de fora,
## o vidro tem canto redondo.
##
## Devolve "laco" (pontos fechados, primeiro = ultimo), "cantos" ([quina, arco]
## por canto) e "centro".
static func _laco_vao(iv: int, v: Array, s: float) -> Dictionary:
	var frontal := iv >= VAOS_LADO.size()
	var zf := float(v[0])
	var zt := float(v[1])
	var a0 := float(v[2])
	var a1 := float(v[3]) if not frontal else 4.0 - float(v[2])
	var ponto := func(z: float, a: float) -> Vector3:
		return _ponto_anel(_est(z), z, a) if frontal else _ponto(z, a, s)
	var raios: Array = CANTOS_VAO[iv]
	# Cantos em (z, a), e para que lado o arco anda de cada um.
	var cantos := [Vector2(zf, a0), Vector2(zf, a1), Vector2(zt, a1), Vector2(zt, a0)]
	var dentro := [Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1)]
	var laco := PackedVector3Array()
	var quinas: Array = []
	for k in 4:
		var q: Vector2 = cantos[k]
		var d: Vector2 = dentro[k]
		var r: float = raios[k]
		# Escala metro -> parametro ali, nas duas direcoes.
		var p0: Vector3 = ponto.call(q.x, q.y)
		var kz := 0.02 / maxf(p0.distance_to(ponto.call(q.x + d.x * 0.02, q.y)), 1e-4)
		var ka := 0.02 / maxf(p0.distance_to(ponto.call(q.x, q.y + d.y * 0.02)), 1e-4)
		var rz := minf(r * kz, absf(zf - zt) * 0.45)
		var ra := minf(r * ka, absf(a1 - a0) * 0.45)
		var c := q + Vector2(d.x * rz, d.y * ra)
		# O arco vai do lado "anterior" do laco ao "seguinte": frente-baixo sai
		# da borda de baixo e chega na da frente, e assim por diante.
		var ini := Vector2(0.0, -d.y) if k % 2 == 0 else Vector2(-d.x, 0.0)
		var fim := Vector2(-d.x, 0.0) if k % 2 == 0 else Vector2(0.0, -d.y)
		var arco := PackedVector3Array()
		for m in 7:
			var f := float(m) / 6.0 * PI * 0.5
			var dir := ini * cos(f) + fim * sin(f)
			var pa := c + Vector2(dir.x * rz, dir.y * ra)
			arco.append(ponto.call(pa.x, pa.y))
		quinas.append([p0, arco])
		laco.append_array(arco)
	laco.append(laco[0])
	var zm := (zf + zt) * 0.5
	var am := (a0 + a1) * 0.5
	return {"laco": laco, "cantos": quinas, "centro": ponto.call(zm, am),
		"frontal": frontal}


## A espessura da porta em volta de cada vao, os leques de canto e a borracha
## (para-brisa e vigia) ou a moldura cromada (janelas de lado).
static func _bordas_de_vao(dados: Dictionary, vaos: Array, cor: Color,
		fino: bool) -> void:
	var borracha := Carroceria.marcar(BORRACHA, Carroceria.Classe.BORRACHA)
	var tinta := Color(cor.r, cor.g, cor.b, 1.0)
	for iv in vaos.size():
		var v: Array = vaos[iv]
		var frontal := iv >= VAOS_LADO.size()
		for s: float in ([1.0] if frontal else [1.0, -1.0]):
			var l := _laco_vao(iv, v, s)
			var laco: PackedVector3Array = l["laco"]
			var centro: Vector3 = l["centro"]
			for quina: Array in l["cantos"]:
				var q: Vector3 = quina[0]
				var arco: PackedVector3Array = quina[1]
				var n := _normal_aprox(q, s, frontal)
				for m in arco.size() - 1:
					CarroceriaVarrida.tri(dados, q + n * 0.0004, arco[m] + n * 0.0004,
						arco[m + 1] + n * 0.0004, Carroceria.C_LATARIA, tinta, tinta, tinta, n)
			var fundo := PackedVector3Array()
			for p in laco:
				fundo.append(p - _normal_aprox(p, s, frontal) * FUNDO_VAO)
			_faixa(dados, laco, fundo, borracha, Carroceria.C_FUNDO, centro, true)
			if fino:
				_moldura_vao(dados, laco, centro, s, frontal)


## A moldura que fica por fora do vao, em volta do laco: borracha grossa com o
## friso cromado no meio nos frontais, friso cromado fino nas janelas de lado.
static func _moldura_vao(dados: Dictionary, laco: PackedVector3Array, centro: Vector3,
		s: float, frontal: bool) -> void:
	var cromo := Carroceria.marcar(CROMO, Carroceria.Classe.CROMO)
	var borracha := Carroceria.marcar(BORRACHA * 1.3, Carroceria.Classe.BORRACHA)
	var largura := 0.022 if frontal else 0.011
	var altura := 0.004 if frontal else 0.0028
	var a := PackedVector3Array()
	var b := PackedVector3Array()
	var c := PackedVector3Array()
	var nk := laco.size()
	for k in nk:
		var p := laco[k]
		var n := _normal_aprox(p, s, frontal)
		var t := laco[mini(k + 1, nk - 1)] - laco[maxi(k - 1, 0)]
		if k == 0 or k == nk - 1:
			t = laco[1] - laco[nk - 2]
		var fora := n.cross(t).normalized()
		if fora.dot(p - centro) < 0.0:
			fora = -fora
		a.append(p + n * 0.0008)
		b.append(p + fora * largura * 0.5 + n * altura)
		c.append(p + fora * largura + n * 0.0008)
	var alvo := centro - _normal_aprox(centro, s, frontal) * 0.5
	var cor := borracha if frontal else cromo
	_faixa(dados, a, b, cor, Carroceria.C_PARACHOQUE, alvo, false)
	_faixa(dados, b, c, cor, Carroceria.C_PARACHOQUE, alvo, false)
	if frontal:
		# O friso cromado no meio da borracha.
		var d := PackedVector3Array()
		var dd := PackedVector3Array()
		var f := PackedVector3Array()
		for k in nk:
			var n := _normal_aprox(laco[k], s, frontal)
			d.append(b[k].lerp(a[k], 0.25))
			dd.append(b[k] + n * 0.0012)
			f.append(b[k].lerp(c[k], 0.25))
		_faixa(dados, d, dd, cromo, Carroceria.C_PARACHOQUE, alvo, false)
		_faixa(dados, dd, f, cromo, Carroceria.C_PARACHOQUE, alvo, false)


## A normal da chapa num ponto dela, sem conhecer o (z, a): pelo eixo do carro
## naquela altura. Serve a borda de vao, que so precisa saber para onde e dentro.
static func _normal_aprox(p: Vector3, s: float, frontal: bool) -> Vector3:
	if frontal:
		var ea := _est(p.z + 0.02)
		var eb := _est(p.z - 0.02)
		return Vector3(0.0, 0.04, -(ea[2] - eb[2])).normalized()
	var e2 := _est(p.z)
	var c := Vector3(0.0, (e2[1] + e2[2]) * 0.5 - 0.1, p.z)
	var d := (p - c)
	d.z = 0.0
	return d.normalized() if d.length_squared() > 1e-8 else Vector3(s, 0, 0)


## Uma faixa entre duas polilinhas, virada para `alvo` (ou para longe dele).
static func _faixa(dados: Dictionary, l0: PackedVector3Array, l1: PackedVector3Array,
		cor: Color, celula: Vector2i, alvo: Vector3, para_alvo: bool) -> void:
	if l0.size() < 2:
		return
	var linhas: Array = [l0, l1]
	var normais := ChapaLisa.normais_da_grade(linhas, 1.0)
	var meio := l0.size() >> 1
	var n0: Vector3 = (normais[0] as PackedVector3Array)[meio]
	var quer := (alvo - l0[meio]) * (1.0 if para_alvo else -1.0)
	var sinal := 1.0 if n0.dot(quer) >= 0.0 else -1.0
	ChapaLisa.grade(dados, linhas, [], cor, celula, sinal)


# ==========================================================================
# Para-lamas
# ==========================================================================

## Os quatro para-lamas.
##
## Cada costela e uma secao no plano que contem o raio da roda (visto de lado)
## e o eixo X: da juncao com a carroceria, sobe a crista, rola para fora ate a
## barriga, desce ao beicinho e dobra para dentro da boca. Catmull-Rom
## centripeta por esses cinco pontos da a gota lisa; depois vem o forro escuro
## da boca e a parede de dentro. Nas pontas a secao morre na carroceria.
static func _paralamas(dados: Dictionary, cor: Color, fino: bool) -> void:
	for frente: bool in [true, false]:
		var tabela: Array = PARALAMA_FRENTE if frente else PARALAMA_TRAS
		var zc := Z_EIXO_FRENTE if frente else Z_EIXO_TRAS
		var por_trecho := 3 if fino else 1
		var costelas := _costelas(tabela, 2 if fino else 1)
		for s: float in [1.0, -1.0]:
			var chapa: Array = []
			var forro: Array = []
			var cores: Array = []
			var juncao := PackedVector3Array()
			var centros := PackedVector3Array()
			for c: Array in costelas:
				var th := deg_to_rad(float(c[0]))
				var r_out: float = c[1]
				var xw: float = c[2]
				var dj: float = c[3]
				var rad := Vector3(0.0, sin(th), cos(th))
				var ponto := func(x: float, r: float) -> Vector3:
					return Vector3(s * x, Y_EIXO, zc) + rad * r
				var r_j := r_out - dj
				var pj: Vector3 = ponto.call(0.0, r_j)
				var xj := _x_corpo(pj.z, pj.y) - 0.004
				var xt := lerpf(xj, xw, 0.42)
				var ctrl := PackedVector3Array([
					ponto.call(xj, r_j),
					ponto.call(lerpf(xj, xt, 0.55), r_out - dj * 0.30),
					ponto.call(xt, r_out),
					ponto.call(lerpf(xt, xw, 0.72), r_out - 0.035),
					ponto.call(xw, r_out - 0.13),
					ponto.call(xw - 0.012, R_BOCA + 0.030),
					ponto.call(xw - 0.040, R_BOCA),
				])
				var sec := ChapaLisa.catmull(ctrl, por_trecho)
				chapa.append(sec)
				var cl := PackedColorArray()
				for p in sec:
					cl.append(Color(cor.r, cor.g, cor.b, 1.0))
				cores.append(cl)
				juncao.append(ctrl[0])
				centros.append(Vector3(s * lerpf(xj, xw, 0.35), Y_EIXO, zc)
					+ rad * (r_out - 0.16))
				# Forro da boca: do beicinho, por dentro, ate a carroceria.
				var x_in := _x_corpo(zc + cos(th) * R_BOCA, Y_EIXO + sin(th) * R_BOCA)
				forro.append(PackedVector3Array([
					ponto.call(xw - 0.040, R_BOCA),
					ponto.call(xw - 0.070, R_BOCA + 0.012),
					ponto.call(minf(x_in, xw - 0.08), R_BOCA + 0.02),
				]))
			# Pontas: a secao inteira desce ate a juncao, e o para-lama nasce da
			# chapa em vez de acabar numa aresta crua.
			ChapaLisa.grade(dados, chapa, cores, cor, Carroceria.C_LATARIA, 1.0, centros)
			var fundo := Carroceria.marcar(FUNDO, Carroceria.Classe.FUNDO)
			var c_forro := PackedVector3Array()
			for c: Array in costelas:
				var th := deg_to_rad(float(c[0]))
				c_forro.append(Vector3(s * 0.62, Y_EIXO, zc) + Vector3(0.0, sin(th), cos(th)) * (R_BOCA + 0.3))
			ChapaLisa.grade(dados, forro, [], fundo, Carroceria.C_FUNDO, 1.0, c_forro)
			_tampas_paralama(dados, chapa, cor)
			_parede_da_caixa(dados, zc, s, costelas)
			if fino:
				# O cordao de vedacao: a borrachinha entre para-lama e carroceria,
				# que desenha o para-lama de lado quando a luz nao desenha.
				var cordao := Color(cor.r * 0.78, cor.g * 0.78, cor.b * 0.78, 1.0)
				ChapaLisa.tubo(dados, juncao, 0.0045, 6, cordao, Carroceria.C_LATARIA, false)


## As costelas da tabela, reamostradas com mais passos entre as linhas.
static func _costelas(tabela: Array, sub: int) -> Array:
	var out: Array = []
	for k in tabela.size() - 1:
		var a: Array = tabela[k]
		var b: Array = tabela[k + 1]
		for m in sub:
			var f := float(m) / float(sub)
			# Suavizado: smoothstep entre as linhas tira o degrau de inclinacao.
			var g := f * f * (3.0 - 2.0 * f) * 0.5 + f * 0.5
			out.append([lerpf(a[0], b[0], f), lerpf(a[1], b[1], g),
				lerpf(a[2], b[2], g), lerpf(a[3], b[3], g)])
	out.append(tabela[tabela.size() - 1])
	return out


## Fecha as duas pontas do para-lama com um leque, virado para fora do arco.
static func _tampas_paralama(dados: Dictionary, chapa: Array, cor: Color) -> void:
	for ponta in [0, chapa.size() - 1]:
		var sec: PackedVector3Array = chapa[ponta]
		var viz: PackedVector3Array = chapa[1 if ponta == 0 else ponta - 1]
		var centro := Vector3.ZERO
		for p in sec:
			centro += p / float(sec.size())
		var cviz := Vector3.ZERO
		for p in viz:
			cviz += p / float(viz.size())
		var fora := (centro - cviz).normalized()
		var fecha := PackedVector3Array(sec)
		fecha.append(sec[0])
		ChapaLisa.leque(dados, fecha, centro + fora * 0.004,
			fora, Color(cor.r * 0.9, cor.g * 0.9, cor.b * 0.9, 1.0), Carroceria.C_LATARIA)


## A parede de dentro da caixa de roda: escura, na carroceria, do eixo ate a
## boca. Sem ela a roda e vista contra a chapa bege iluminada do casco.
static func _parede_da_caixa(dados: Dictionary, zc: float, s: float,
		costelas: Array) -> void:
	var fundo := Carroceria.marcar(FUNDO * 0.8, Carroceria.Classe.FUNDO)
	var pe := Vector3(0.0, Y_EIXO, zc)
	var arco := PackedVector3Array()
	for c: Array in costelas:
		var th := deg_to_rad(float(c[0]))
		var p := Vector3(0.0, Y_EIXO + sin(th) * (R_BOCA + 0.02), zc + cos(th) * (R_BOCA + 0.02))
		p.x = s * (_x_corpo(p.z, p.y) + 0.003)
		arco.append(p)
	pe.x = s * (_x_corpo(zc, Y_EIXO) + 0.003)
	ChapaLisa.leque(dados, arco, pe, Vector3(s, 0, 0), fundo, Carroceria.C_FUNDO)


# ==========================================================================
# Estribos
# ==========================================================================

## O estribo: chapa com borracha canelada em cima, friso de aluminio na borda
## e a aba escura por baixo. Entra por baixo das pontas dos dois para-lamas.
static func _estribos(dados: Dictionary, fino: bool) -> void:
	var z0: float = ESTRIBO_Z[0]
	var z1: float = ESTRIBO_Z[1]
	var borracha := Carroceria.marcar(BORRACHA * 1.4, Carroceria.Classe.BORRACHA)
	var sulco := Carroceria.marcar(BORRACHA * 0.7, Carroceria.Classe.BORRACHA)
	var aba := Carroceria.marcar(PLASTICO, Carroceria.Classe.PLASTICO)
	var cromo := Carroceria.marcar(CROMO * 0.92, Carroceria.Classe.CROMO)
	var y := ESTRIBO_Y
	for s: float in [1.0, -1.0]:
		var xi0 := _x_corpo(z0, y) - 0.01
		var xi1 := _x_corpo(z1, y) - 0.01
		var xe := ESTRIBO_X - 0.012
		# Borracha canelada: faixas alternadas ao longo do estribo, com um
		# milimetro e meio de relevo.
		var n_ca := 7 if fino else 1
		for k in n_ca:
			var f0 := float(k) / float(n_ca)
			var f1 := float(k + 1) / float(n_ca)
			var alto := 0.0015 if k % 2 == 0 else 0.0
			var cor_f := borracha if k % 2 == 0 else sulco
			var a := Vector3(s * lerpf(xi0, xe, f0), y + alto, z0)
			var b := Vector3(s * lerpf(xi0, xe, f1), y + alto, z0)
			var c := Vector3(s * lerpf(xi1, xe, f1), y + alto, z1)
			var d := Vector3(s * lerpf(xi1, xe, f0), y + alto, z1)
			CarroceriaVarrida.quad(dados, a, b, c, d, Carroceria.C_SOLEIRA,
				cor_f, cor_f, cor_f, cor_f, Vector3.UP)
		# Friso de aluminio na borda: meia-cana de 2,4 cm.
		if fino:
			var cam := PackedVector3Array()
			for k in 9:
				var z := lerpf(z0, z1, float(k) / 8.0)
				cam.append(Vector3(s * (ESTRIBO_X - 0.004), y - 0.004, z))
			ChapaLisa.tubo(dados, cam, 0.012, 10, cromo, Carroceria.C_PARACHOQUE, true)
		# Aba de baixo e fundo.
		CarroceriaVarrida.quad(dados, Vector3(s * ESTRIBO_X, y - 0.012, z0),
			Vector3(s * ESTRIBO_X, y - 0.06, z0), Vector3(s * ESTRIBO_X, y - 0.06, z1),
			Vector3(s * ESTRIBO_X, y - 0.012, z1), Carroceria.C_FUNDO,
			aba, aba, aba, aba, Vector3(s, 0, 0))
		CarroceriaVarrida.quad(dados, Vector3(s * xi0, y - 0.06, z0),
			Vector3(s * ESTRIBO_X, y - 0.06, z0), Vector3(s * ESTRIBO_X, y - 0.06, z1),
			Vector3(s * xi1, y - 0.06, z1), Carroceria.C_FUNDO,
			aba, aba, aba, aba, Vector3.DOWN)


# ==========================================================================
# Farol e pisca
# ==========================================================================

## O eixo do farol de um lado: olha para a frente, um pouco para cima e para fora.
static func _eixo_farol(s: float) -> Vector3:
	return Vector3(s * FAROL_ABRE, FAROL_INCLINA, 1.0).normalized()


## Farol: a caneca na cor do carro saindo do para-lama, o aro cromado de perfil
## redondo, o refletor e a lente abaulada. A lente vai em `luzes` com a celula
## do farol, mapeada em raio a partir do centro da celula — e assim que o
## `psx_carro_luz` desenha os aneis de Fresnel e o ponto da lampada.
static func _farois(dados: Dictionary, luzes: Dictionary, cor: Color, fino: bool) -> void:
	var lados := 24 if fino else 12
	for s: float in [1.0, -1.0]:
		var c := Vector3(s * FAROL.x, FAROL.y, FAROL.z)
		var ax := _eixo_farol(s)
		var ref := Vector3.UP
		var tinta := Color(cor.r, cor.g, cor.b, 1.0)
		# Caneca: cilindro que nasce dentro do para-lama e chega ao aro.
		ChapaLisa.torno(dados, c, ax, ref, PackedVector2Array([
			Vector2(FAROL_R - 0.004, -0.20), Vector2(FAROL_R, -0.12),
			Vector2(FAROL_R + 0.002, -0.030), Vector2(FAROL_R, -0.012)]),
			lados, PackedColorArray(), tinta, Carroceria.C_LATARIA)
		var cromo := Carroceria.marcar(CROMO, Carroceria.Classe.CROMO)
		# Aro: sobe da caneca, rola por cima e morre na lente.
		var aro := PackedVector2Array([
			Vector2(FAROL_R - 0.001, -0.013), Vector2(FAROL_R + 0.005, -0.004),
			Vector2(FAROL_R + 0.004, 0.006), Vector2(FAROL_R - 0.004, 0.014),
			Vector2(FAROL_R - 0.016, 0.017), Vector2(FAROL_R - 0.024, 0.013)])
		if not fino:
			aro = PackedVector2Array([Vector2(FAROL_R, -0.01), Vector2(FAROL_R, 0.01),
				Vector2(FAROL_R - 0.024, 0.013)])
		ChapaLisa.torno(dados, c, ax, ref, aro, lados, PackedColorArray(), cromo,
			Carroceria.C_PARACHOQUE)
		# Refletor escuro atras da lente: sem luz, o farol continua um olho.
		var refletor := Carroceria.marcar(Color(0.30, 0.31, 0.33), Carroceria.Classe.CROMO)
		_disco_lente(dados, c + ax * 0.004, ax, ref, FAROL_R - 0.022, 0.0,
			lados, refletor, Carroceria.C_PARACHOQUE)
		# Lente abaulada.
		_disco_lente(luzes, c + ax * 0.008, ax, ref, FAROL_R - 0.022, 0.020,
			lados, Color.WHITE, Carroceria.C_FAROL)
		_pisca(dados, luzes, s, fino)


## Disco (ou calota, com `bojo` > 0) virado para `ax`, com UV em raio a partir do
## centro da celula.
static func _disco_lente(dados: Dictionary, c: Vector3, ax: Vector3, ref: Vector3,
		raio: float, bojo: float, lados: int, cor: Color, celula: Vector2i) -> void:
	var e := ax.normalized()
	var x := (ref - e * ref.dot(e)).normalized()
	var y := e.cross(x)
	var r := Carroceria.uv(celula)
	var aneis := 5 if bojo > 0.0 else 1
	var v: PackedVector3Array = dados["v"]
	var n: PackedVector3Array = dados["n"]
	var u: PackedVector2Array = dados["uv"]
	var cc: PackedColorArray = dados["c"]
	var ii: PackedInt32Array = dados["i"]
	var base := v.size()
	v.append(c + e * bojo)
	n.append(e)
	cc.append(cor)
	u.append(r.get_center())
	for j in range(1, aneis + 1):
		var f := float(j) / float(aneis)
		var h := bojo * (1.0 - f * f)
		for k in lados + 1:
			var a := TAU * float(k) / float(lados)
			var dir := x * cos(a) + y * sin(a)
			v.append(c + dir * raio * f + e * h)
			var nn := (e + dir * (2.0 * bojo * f / maxf(raio, 1e-4))).normalized()
			n.append(nn)
			cc.append(cor)
			u.append(r.get_center() + Vector2(cos(a), -sin(a)) * r.size * 0.5 * f)
	for k in lados:
		ChapaLisa._tri(ii, v, n, base, base + 1 + k, base + 2 + k)
	for j in range(1, aneis):
		var a0 := base + 1 + (j - 1) * (lados + 1)
		var a1 := a0 + lados + 1
		for k in lados:
			ChapaLisa._tri(ii, v, n, a0 + k, a0 + k + 1, a1 + k + 1)
			ChapaLisa._tri(ii, v, n, a0 + k, a1 + k + 1, a1 + k)
	dados["v"] = v
	dados["n"] = n
	dados["uv"] = u
	dados["c"] = cc
	dados["i"] = ii


## O pisca dos Fuscas brasileiros dos anos 80: a gotinha ambar em cima do
## para-lama, logo atras do farol, olhando para a frente.
static func _pisca(dados: Dictionary, luzes: Dictionary, s: float, fino: bool) -> void:
	var th := deg_to_rad(58.0)
	var r_out := 0.652
	var p := Vector3(s * 0.505, Y_EIXO + sin(th) * r_out, Z_EIXO_FRENTE + cos(th) * r_out)
	var base := Carroceria.marcar(CROMO * 0.95, Carroceria.Classe.CROMO)
	var lados := 12 if fino else 6
	var ax := Vector3(0.0, 0.05, 1.0).normalized()
	ChapaLisa.torno(dados, p + Vector3(0, 0.012, 0), ax, Vector3.UP, PackedVector2Array([
		Vector2(0.001, -0.07), Vector2(0.024, -0.055), Vector2(0.030, -0.02),
		Vector2(0.030, 0.0)]), lados, PackedColorArray(), base, Carroceria.C_PARACHOQUE)
	_disco_lente(luzes, p + Vector3(0, 0.012, 0) + ax * 0.001, ax, Vector3.UP, 0.028,
		0.012, lados, Color(1.0, 0.72, 0.22), Carroceria.C_PISCA)


# ==========================================================================
# Lanternas
# ==========================================================================

## A lanterna "Fafa": a grande, que o Fusca ganhou em 1978. Base de chapa na cor
## do carro saindo do para-lama, gaxeta preta e a lente abaulada dividida —
## ambar em cima (seta), vermelho embaixo (lanterna e freio).
##
## Toda lente de tras vai com a celula da LANTERNA: o `Carro` troca a celula de
## todo vertice traseiro pelo mesmo deslocamento (freio, re, seta), e uma lente
## escrita em outra celula saltaria para a celula errada. A cor ambar vem do
## vertice, que multiplica a textura.
static func _lanternas(dados: Dictionary, luzes: Dictionary, cor: Color, fino: bool) -> void:
	var lados := 24 if fino else 10
	for s: float in [1.0, -1.0]:
		var c := Vector3(s * LANTERNA.x, LANTERNA.y, LANTERNA.z)
		var ax := Vector3(s * 0.18, 0.45, -1.0).normalized()
		var cima := (Vector3.UP - ax * ax.y).normalized()
		var lado := ax.cross(cima)
		var tinta := Color(cor.r, cor.g, cor.b, 1.0)
		# Base: um tubo eliptico curto na cor do carro.
		var meia := LANTERNA_MEIA
		var base_pts: Array = []
		var centros := PackedVector3Array()
		for d: float in [-0.10, -0.03, -0.004]:
			var linha := PackedVector3Array()
			var folga := 0.010 if d > -0.02 else 0.004
			for k in lados + 1:
				var a := TAU * float(k) / float(lados)
				linha.append(c + ax * d + lado * cos(a) * (meia.x + folga)
					+ cima * sin(a) * (meia.y + folga))
			base_pts.append(linha)
			centros.append(c + ax * d)
		ChapaLisa.grade(dados, base_pts, [], tinta, Carroceria.C_LATARIA, 1.0, centros, true)
		# Gaxeta preta em volta da lente.
		var gax := Carroceria.marcar(BORRACHA, Carroceria.Classe.BORRACHA)
		var anel_g: Array = []
		var cg := PackedVector3Array()
		for f: Array in [[0.010, -0.004], [0.004, 0.004]]:
			var linha := PackedVector3Array()
			for k in lados + 1:
				var a := TAU * float(k) / float(lados)
				linha.append(c + ax * float(f[1]) + lado * cos(a) * (meia.x + float(f[0]))
					+ cima * sin(a) * (meia.y + float(f[0])))
			anel_g.append(linha)
			cg.append(c + ax * float(f[1]) - ax * 0.05)
		ChapaLisa.grade(dados, anel_g, [], gax, Carroceria.C_FUNDO, 1.0, cg, true)
		# Lente: calota de superelipse em duas pecas — ambar em cima, na celula do
		# pisca (o `Carro` pisca ela junto com a da frente), e vermelho embaixo,
		# na da lanterna (acende no freio e na re).
		var nv := 5 if fino else 2
		var nu := 8 if fino else 3
		_lente_lanterna(luzes, c, ax, lado, cima, meia, DIVISA_LANTERNA, 1.0, nv, nu,
			Color(1.0, 0.78, 0.30), Carroceria.C_PISCA)
		_lente_lanterna(luzes, c, ax, lado, cima, meia, -1.0, DIVISA_LANTERNA, nv + 3, nu,
			Color.WHITE, Carroceria.C_LANTERNA)
		# Divisao entre ambar e vermelho: um friso cromado fino.
		if fino:
			var cromo := Carroceria.marcar(CROMO, Carroceria.Classe.CROMO)
			var cam := PackedVector3Array()
			for k in 9:
				var fx := lerpf(-0.96, 0.96, float(k) / 8.0)
				var q := Vector2(fx, DIVISA_LANTERNA)
				var bojo := BOJO_LANTERNA * (1.0 - minf(1.0, q.length_squared()))
				cam.append(c + ax * (0.006 + bojo) + lado * fx * meia.x
					+ cima * DIVISA_LANTERNA * meia.y)
			ChapaLisa.tubo(dados, cam, 0.003, 6, cromo, Carroceria.C_PARACHOQUE, false)


## Uma faixa da lente da lanterna, de `fy0` a `fy1` na altura (-1 a 1), com UV
## cobrindo a celula inteira: o prisma do `psx_carro_luz` anda por ela toda.
static func _lente_lanterna(luzes: Dictionary, c: Vector3, ax: Vector3, lado: Vector3,
		cima: Vector3, meia: Vector2, fy0: float, fy1: float, nv: int, nu: int,
		cor: Color, celula: Vector2i) -> void:
	var linhas: Array = []
	for j in nv + 1:
		var fy := lerpf(fy0, fy1, float(j) / float(nv))
		var linha := PackedVector3Array()
		for k in nu + 1:
			var fx := lerpf(-1.0, 1.0, float(k) / float(nu))
			# Superelipse: cantos cheios, como a lente de verdade.
			var q := Vector2(fx, fy)
			var rr := pow(pow(absf(q.x), 3.0) + pow(absf(q.y), 3.0), 1.0 / 3.0)
			if rr > 1.0:
				q /= rr
			var bojo := BOJO_LANTERNA * (1.0 - minf(1.0, q.length_squared()))
			linha.append(c + ax * (0.004 + bojo) + lado * q.x * meia.x + cima * q.y * meia.y)
		linhas.append(linha)
	var ini := (luzes["v"] as PackedVector3Array).size()
	ChapaLisa.grade(luzes, linhas, [], cor, celula, 1.0)
	_virar_ultima_para(luzes, (nv + 1) * (nu + 1), ax)
	var cel := Carroceria.uv(celula)
	var uvs: PackedVector2Array = luzes["uv"]
	for j in nv + 1:
		for k in nu + 1:
			uvs[ini + j * (nu + 1) + k] = cel.position + Vector2(
				float(k) / float(nu), 1.0 - float(j) / float(nv)) * cel.size
	luzes["uv"] = uvs


# ==========================================================================
# Para-choques
# ==========================================================================

## Lamina cromada: perfil em C (face abaulada, dobra em cima e embaixo), varrida
## por um caminho que acompanha a frente e dobra para tras nas pontas, com o
## friso de borracha no meio e os dois suportes escuros.
static func _parachoques(dados: Dictionary, fino: bool) -> void:
	for frente: bool in [true, false]:
		var cfg: Dictionary = PARACHOQUE_FRENTE if frente else PARACHOQUE_TRAS
		var z0: float = cfg["z"]
		var y0: float = cfg["y"]
		var dz := 1.0 if frente else -1.0
		# Caminho em planta (x, recuo), da ponta direita a esquerda.
		var ctrl := PackedVector3Array()
		for q: Vector2 in [Vector2(0.770, 0.300), Vector2(0.785, 0.200),
				Vector2(0.765, 0.105), Vector2(0.700, 0.050), Vector2(0.560, 0.020),
				Vector2(0.300, 0.004), Vector2(0.0, 0.0)]:
			ctrl.append(Vector3(q.x, 0.0, q.y))
		for k in range(ctrl.size() - 2, -1, -1):
			ctrl.append(Vector3(-ctrl[k].x, 0.0, ctrl[k].z))
		var cam := ChapaLisa.catmull(ctrl, 4 if fino else 1)
		var perfil := [Vector2(-0.030, 0.050), Vector2(-0.004, 0.056),
			Vector2(0.011, 0.040), Vector2(0.017, 0.012), Vector2(0.017, -0.012),
			Vector2(0.011, -0.040), Vector2(-0.004, -0.056), Vector2(-0.030, -0.050)]
		var linhas: Array = []
		var centros := PackedVector3Array()
		for k in cam.size():
			var p := cam[k]
			var t := (cam[mini(k + 1, cam.size() - 1)] - cam[maxi(k - 1, 0)])
			# Normal em planta para FORA: para longe de um ponto la dentro do carro.
			var base := Vector3(p.x, y0, z0 - dz * p.z)
			var tw := Vector3(t.x, 0.0, -dz * t.z)
			var fora := Vector3(-tw.z, 0.0, tw.x).normalized()
			if fora.dot(base - Vector3(0.0, y0, z0 - dz * 0.9)) < 0.0:
				fora = -fora
			var linha := PackedVector3Array()
			for q: Vector2 in perfil:
				linha.append(base + fora * q.x + Vector3(0.0, q.y, 0.0))
			linhas.append(linha)
			centros.append(base - fora * 0.15)
		var cromo := Carroceria.marcar(CROMO, Carroceria.Classe.CROMO)
		# Linhas = ao longo, colunas = perfil. Transpor nao precisa: a grade
		# aceita qualquer orientacao, os centros dizem onde e dentro.
		ChapaLisa.grade(dados, linhas, [], cromo, Carroceria.C_PARACHOQUE, 1.0, centros)
		if fino:
			# Friso de borracha no meio da lamina, entre as dobras.
			var friso: Array = []
			var cf := PackedVector3Array()
			for k in cam.size():
				if absf(cam[k].x) > 0.70:
					continue
				var linha: PackedVector3Array = linhas[k]
				var fora := (linha[3] - centros[k]).normalized()
				fora.y = 0.0
				fora = fora.normalized()
				var meio := (linha[3] + linha[4]) * 0.5
				friso.append(PackedVector3Array([
					meio + Vector3(0, 0.009, 0) - fora * 0.001,
					meio + Vector3(0, 0.007, 0) + fora * 0.004,
					meio + Vector3(0, -0.007, 0) + fora * 0.004,
					meio + Vector3(0, -0.009, 0) - fora * 0.001]))
				cf.append(meio - fora * 0.15)
			ChapaLisa.grade(dados, friso, [], Carroceria.marcar(BORRACHA,
				Carroceria.Classe.BORRACHA), Carroceria.C_FUNDO, 1.0, cf)
		# Suportes: duas barras escuras da lamina ate a carroceria.
		var aco := Carroceria.marcar(ACO_ESCURO, Carroceria.Classe.PLASTICO)
		for s: float in [1.0, -1.0]:
			var x := s * 0.36
			var p0 := Vector3(x, y0 - 0.02, z0 - dz * 0.03)
			var p1 := Vector3(x, y0 - 0.05, z0 - dz * 0.26)
			ChapaLisa.tubo(dados, PackedVector3Array([p0, p1]), 0.018, 6, aco,
				Carroceria.C_FUNDO, false)


# ==========================================================================
# Placas
# ==========================================================================

static func _placas(dados: Dictionary, _luzes: Dictionary, cor: Color, fino: bool) -> void:
	var placa := Color(0.86, 0.86, 0.84)
	# Frente: pendurada embaixo do para-choque, como nas refs.
	CarroceriaVarrida.plana(dados, Vector2(0.40, 0.13),
		Transform3D(Basis(Vector3.RIGHT, -0.05), Vector3(0.0, 0.372, 1.972)),
		placa, Carroceria.C_PLACA)
	# Tras: deitada na tampa do motor, com a capelinha cromada da luz em cima.
	var zt := -1.752
	var n := _normal(zt, 2.0, 1.0)
	var p := _ponto(zt, 2.0, 1.0) + n * 0.010
	var bx := Vector3(-1.0, 0.0, 0.0)
	var giro := Basis(bx, n.cross(bx).normalized(), n)
	CarroceriaVarrida.plana(dados, Vector2(0.40, 0.13), Transform3D(giro, p),
		placa, Carroceria.C_PLACA)
	if fino:
		var cromo := Carroceria.marcar(CROMO, Carroceria.Classe.CROMO)
		# A capelinha da luz de placa: meia-cana cromada deitada sobre a placa.
		var zl := -1.672
		var nl := _normal(zl, 2.0, 1.0)
		var pl := _ponto(zl, 2.0, 1.0) - nl * 0.006
		var cap := PackedVector3Array()
		for k in 7:
			var x := lerpf(0.075, -0.075, float(k) / 6.0)
			var dx := absf(x) / 0.075
			cap.append(pl + Vector3(x, 0.0, 0.0) - nl * 0.012 * dx * dx * dx)
		ChapaLisa.tubo(dados, cap, 0.024, 12, cromo, Carroceria.C_PARACHOQUE, true)
	var _c := cor


# ==========================================================================
# Janelas, frisos, capo e tampa
# ==========================================================================

## A calha de chuva por cima das portas. As molduras dos vaos sao de
## `_moldura_vao`.
static func _janelas_e_frisos(dados: Dictionary, cor_tinta: Color) -> void:
	# Calha de chuva: um cordao na cor do carro por cima das janelas.
	for s: float in [1.0, -1.0]:
		var cam := PackedVector3Array()
		for k in 25:
			var z := lerpf(0.40, -0.99, float(k) / 24.0)
			cam.append(_ponto(z, 0.81, s) + _normal(z, 0.81, s) * 0.002)
		ChapaLisa.tubo(dados, cam, 0.0042, 6, Color(cor_tinta.r, cor_tinta.g,
			cor_tinta.b, 1.0), Carroceria.C_LATARIA, true)


## Friso cromado do capo com o emblema na ponta, puxador do capo, venezianas
## da tampa do motor e o puxador dela.
static func _capo_e_tampa(dados: Dictionary, cor: Color) -> void:
	var cromo := Carroceria.marcar(CROMO, Carroceria.Classe.CROMO)
	var preto := Carroceria.marcar(Color(0.035, 0.035, 0.04), Carroceria.Classe.FUNDO)
	var tinta := Color(cor.r, cor.g, cor.b, 1.0)
	# Friso do capo: da base do para-brisa ate o emblema.
	var cam := PackedVector3Array()
	for k in 17:
		var z := lerpf(0.93, 1.72, float(k) / 16.0)
		cam.append(_ponto(z, 2.0, 1.0) + _normal(z, 2.0, 1.0) * 0.003)
	var linhas: Array = []
	var cs := PackedVector3Array()
	for p in cam:
		var n := _normal(p.z, 2.0, 1.0)
		linhas.append(PackedVector3Array([p + Vector3(0.012, -0.002, 0),
			p + Vector3(0.005, 0.0022, 0), p + Vector3(-0.005, 0.0022, 0),
			p + Vector3(-0.012, -0.002, 0)]))
		cs.append(p - n * 0.2)
	ChapaLisa.grade(dados, linhas, [], cromo, Carroceria.C_PARACHOQUE, 1.0, cs)
	# Emblema VW: medalhao cromado com o miolo escuro e o anel.
	var ze := 1.765
	var ne := _normal(ze, 2.0, 1.0)
	var pe := _ponto(ze, 2.0, 1.0)
	ChapaLisa.torno(dados, pe, ne, Vector3.FORWARD, PackedVector2Array([
		Vector2(0.050, -0.004), Vector2(0.052, 0.004), Vector2(0.048, 0.010),
		Vector2(0.040, 0.011), Vector2(0.036, 0.007), Vector2(0.0, 0.008)]), 24,
		PackedColorArray(), cromo, Carroceria.C_PARACHOQUE)
	_emblema_vw(dados, pe + ne * 0.0095, ne, 0.034, cromo, preto)
	# Puxador do capo, logo abaixo do emblema.
	var zp := 1.835
	var pp := _ponto(zp, 2.0, 1.0)
	var np := _normal(zp, 2.0, 1.0)
	ChapaLisa.tubo(dados, PackedVector3Array([pp + np * 0.008 + Vector3(0.045, 0, 0),
		pp + np * 0.014 + Vector3(0.02, 0, 0), pp + np * 0.014 + Vector3(-0.02, 0, 0),
		pp + np * 0.008 + Vector3(-0.045, 0, 0)]), 0.008, 8, cromo,
		Carroceria.C_PARACHOQUE, true)

	# Tampa do motor: a faixa de fendas finas logo abaixo do vigia e os dois
	# blocos de venezianas no meio da tampa.
	var faixa := [-1.315, -1.345]
	for k in 17:
		var u := lerpf(-0.78, 0.78, float(k) / 16.0)
		_fenda(dados, (faixa[0] + faixa[1]) * 0.5, u, 0.024, 0.030, true, tinta, preto)
	for bloco: float in [-0.42, 0.42]:
		for k in 5:
			var z := lerpf(-1.43, -1.53, float(k) / 4.0)
			_fenda(dados, z, bloco, 0.18, 0.010, false, tinta, preto)
	# Puxador da tampa com o VW.
	var zt := -1.60
	var nt := _normal(zt, 2.0, 1.0)
	var pt := _ponto(zt, 2.0, 1.0)
	ChapaLisa.torno(dados, pt, nt, Vector3.UP, PackedVector2Array([
		Vector2(0.034, -0.003), Vector2(0.036, 0.006), Vector2(0.030, 0.012),
		Vector2(0.0, 0.013)]), 20, PackedColorArray(), cromo, Carroceria.C_PARACHOQUE)
	_emblema_vw(dados, pt + nt * 0.0135, nt, 0.024, cromo, preto)
	# O "1600" do lado da tampa: plaqueta cromada.
	var z16 := -1.66
	var p16 := _ponto(z16, 1.62, 1.0)
	var n16 := _normal(z16, 1.62, 1.0)
	ChapaLisa.tubo(dados, PackedVector3Array([p16 + n16 * 0.003 + Vector3(0.05, 0, 0),
		p16 + n16 * 0.003 + Vector3(-0.05, 0, 0)]), 0.006, 6, cromo,
		Carroceria.C_PARACHOQUE, true)


## Uma fenda de veneziana na tampa: o rasgo escuro e o labio na cor do carro
## por cima dele. `u` e a posicao atravessada no meio do teto (-1 a 1).
static func _fenda(dados: Dictionary, z: float, u: float, largura: float,
		altura: float, vertical: bool, tinta: Color, preto: Color) -> void:
	var a := 2.0 - absf(u)
	var s := 1.0 if u >= 0.0 else -1.0
	var p := _ponto(z, a, s)
	var n := _normal(z, a, s)
	var ao_longo := Vector3(0, 0, 1)
	var atravessado := n.cross(ao_longo).normalized()
	ao_longo = atravessado.cross(n).normalized()
	var w := atravessado * (largura * 0.5)
	var h := ao_longo * (altura * 0.5)
	if vertical:
		w = atravessado * (largura * 0.12)
		h = ao_longo * (altura * 0.5)
	var c := p + n * 0.0012
	CarroceriaVarrida.quad(dados, c - w - h, c + w - h, c + w + h, c - w + h,
		Carroceria.C_FUNDO, preto, preto, preto, preto, n)
	# Labio: a borda de cima dobra para fora sobre o rasgo.
	var l0 := c + h + n * 0.0005
	var l1 := c - h * 0.2 + n * 0.0045
	CarroceriaVarrida.quad(dados, l0 - w, l0 + w, l1 + w, l1 - w, Carroceria.C_LATARIA,
		tinta, tinta, tinta * 0.9, tinta * 0.9, (n + ao_longo * 0.4).normalized())


## O "VW" do emblema: dois V, o de baixo invertido, em tubinho cromado sobre o
## miolo escuro.
static func _emblema_vw(dados: Dictionary, c: Vector3, n: Vector3, r: float,
		cromo: Color, preto: Color) -> void:
	var x := Vector3.RIGHT
	var y := n.cross(x).normalized()
	if y.dot(Vector3.UP) < 0.0 and absf(n.y) < 0.7:
		y = -y
	if absf(n.y) >= 0.7:
		y = n.cross(x).normalized() * (1.0 if n.cross(x).z > 0.0 else -1.0)
	CarroceriaVarrida.disco(dados, c - n * 0.0005, Basis(x, y, n), r * 0.92,
		Carroceria.C_FUNDO, preto, 20)
	var fio := r * 0.085
	var v := PackedVector3Array([c + (-x * 0.46 + y * 0.52) * r,
		c + (-x * 0.02 - y * 0.30) * r, c + (x * 0.46 + y * 0.52) * r])
	for k in 2:
		ChapaLisa.tubo(dados, PackedVector3Array([v[k] + n * 0.001, v[k + 1] + n * 0.001]),
			fio, 5, cromo, Carroceria.C_PARACHOQUE, false)
	var w := PackedVector3Array([c + (-x * 0.62 - y * 0.10) * r,
		c + (-x * 0.34 - y * 0.62) * r, c + (0.0 * x - y * 0.08) * r,
		c + (x * 0.34 - y * 0.62) * r, c + (x * 0.62 - y * 0.10) * r])
	for k in 4:
		ChapaLisa.tubo(dados, PackedVector3Array([w[k] + n * 0.002, w[k + 1] + n * 0.002]),
			fio, 5, cromo, Carroceria.C_PARACHOQUE, false)


## Macaneta, fechadura, retrovisores e as meias-luas de ventilacao atras das
## janelas traseiras.
static func _detalhes_lado(dados: Dictionary, cor: Color) -> void:
	var cromo := Carroceria.marcar(CROMO, Carroceria.Classe.CROMO)
	var preto := Carroceria.marcar(PLASTICO, Carroceria.Classe.PLASTICO)
	var fundo := Carroceria.marcar(Color(0.03, 0.03, 0.035), Carroceria.Classe.FUNDO)
	var tinta := Color(cor.r, cor.g, cor.b, 1.0)
	for s: float in [1.0, -1.0]:
		# Macaneta de puxar com o botao, perto do fim da porta.
		var zm := -0.38
		var am := -0.10
		var p := _ponto(zm, am, s)
		var n := _normal(zm, am, s)
		CarroceriaVarrida.quad(dados, p + n * 0.0008 + Vector3(0, -0.02, 0.07),
			p + n * 0.0008 + Vector3(0, -0.02, -0.07), p + n * 0.0008 + Vector3(0, 0.02, -0.07),
			p + n * 0.0008 + Vector3(0, 0.02, 0.07), Carroceria.C_FUNDO,
			fundo, fundo, fundo, fundo, n)
		var cam := PackedVector3Array()
		for k in 7:
			var f := float(k) / 6.0
			var z := lerpf(zm + 0.065, zm - 0.065, f)
			cam.append(_ponto(z, am, s) + _normal(z, am, s) * (0.006 + 0.008 * sin(f * PI)))
		ChapaLisa.tubo(dados, cam, 0.0075, 8, cromo, Carroceria.C_PARACHOQUE, true)
		ChapaLisa.torno(dados, _ponto(zm - 0.05, am, s) + n * 0.008, n, Vector3.UP,
			PackedVector2Array([Vector2(0.009, -0.004), Vector2(0.009, 0.004),
			Vector2(0.0, 0.006)]), 10, PackedColorArray(), cromo, Carroceria.C_PARACHOQUE)
		# Fechadura, abaixo da macaneta.
		var pf := _ponto(zm - 0.03, am - 0.12, s)
		var nf := _normal(zm - 0.03, am - 0.12, s)
		ChapaLisa.torno(dados, pf, nf, Vector3.UP, PackedVector2Array([
			Vector2(0.011, -0.002), Vector2(0.011, 0.004), Vector2(0.0, 0.005)]), 10,
			PackedColorArray(), cromo, Carroceria.C_PARACHOQUE)

		# Retrovisor preto, na quina da porta, olhando para tras.
		var zr := 0.50
		var ar := 0.06
		var pr := _ponto(zr, ar, s)
		var nr := _normal(zr, ar, s)
		var ponta := pr + nr * 0.11 + Vector3(0, 0.07, -0.01)
		ChapaLisa.tubo(dados, PackedVector3Array([pr - nr * 0.005, pr + nr * 0.05
			+ Vector3(0, 0.03, 0), ponta]), 0.009, 6, preto, Carroceria.C_FUNDO, false)
		var ce := ponta + Vector3(s * 0.035, 0.0, -0.01)
		var cabeca: Array = []
		var cc := PackedVector3Array()
		var meia := Vector2(0.060, 0.040)
		for d: float in [0.028, 0.010, -0.012]:
			var linha := PackedVector3Array()
			var enc := 0.72 if d > 0.02 else 1.0
			for k in 21:
				var a := TAU * float(k) / 20.0
				var q := Vector2(cos(a), sin(a))
				var rr := pow(pow(absf(q.x), 4.0) + pow(absf(q.y), 4.0), 0.25)
				q /= rr
				linha.append(ce + Vector3(s * q.x * meia.x * enc, q.y * meia.y * enc, d))
			cabeca.append(linha)
			cc.append(ce + Vector3(0, 0, d))
		ChapaLisa.grade(dados, cabeca, [], preto, Carroceria.C_FUNDO, 1.0, cc, true)
		var tampa_tras: PackedVector3Array = cabeca[2]
		ChapaLisa.leque(dados, tampa_tras, ce + Vector3(0, 0, -0.012), Vector3(0, 0, -1),
			Carroceria.marcar(Color(0.32, 0.36, 0.40), Carroceria.Classe.ESPELHO),
			Carroceria.C_VIDRO_LADO)
		var tampa_frente: PackedVector3Array = cabeca[0]
		ChapaLisa.leque(dados, tampa_frente, ce + Vector3(0, 0, 0.034), Vector3(0, 0, 1),
			preto, Carroceria.C_FUNDO)

		# Meia-lua de ventilacao atras da janela traseira: cinco fendas que
		# acompanham a borda de tras do vidro.
		for k in 5:
			var a := lerpf(0.20, 0.56, float(k) / 4.0)
			var z := -1.035 - 0.02 * sin(float(k) / 4.0 * PI)
			var pv := _ponto(z, a, s)
			var nv := _normal(z, a, s)
			var ao_longo := Vector3(0, 0, 1)
			var cima := nv.cross(ao_longo).normalized() * 0.006
			var w := Vector3(0, 0, 0.022)
			CarroceriaVarrida.quad(dados, pv + nv * 0.001 - w - cima, pv + nv * 0.001 + w - cima,
				pv + nv * 0.001 + w + cima, pv + nv * 0.001 - w + cima, Carroceria.C_FUNDO,
				fundo, fundo, fundo, fundo, nv)
			CarroceriaVarrida.quad(dados, pv + nv * 0.0015 - w + cima,
				pv + nv * 0.0015 + w + cima, pv + nv * 0.005 + w, pv + nv * 0.005 - w,
				Carroceria.C_LATARIA, tinta, tinta, tinta * 0.9, tinta * 0.9, nv)


## O que se ve por baixo: o motor e o cambio escuros atras, o eixo da frente, e o
## escapamento duplo saindo por baixo do para-choque.
static func _baixo(dados: Dictionary) -> void:
	var escuro := Carroceria.marcar(Color(0.09, 0.085, 0.08), Carroceria.Classe.FUNDO)
	var cromo := Carroceria.marcar(CROMO * 0.9, Carroceria.Classe.CROMO)
	# Bloco do motor, sob a tampa, entre as rodas de tras.
	CarroceriaVarrida.quad(dados, Vector3(0.42, 0.20, -1.40), Vector3(-0.42, 0.20, -1.40),
		Vector3(-0.42, 0.20, -1.82), Vector3(0.42, 0.20, -1.82), Carroceria.C_FUNDO,
		escuro, escuro, escuro, escuro, Vector3.DOWN)
	CarroceriaVarrida.quad(dados, Vector3(0.42, 0.20, -1.82), Vector3(-0.42, 0.20, -1.82),
		Vector3(-0.42, 0.36, -1.84), Vector3(0.42, 0.36, -1.84), Carroceria.C_FUNDO,
		escuro, escuro, escuro, escuro, Vector3(0, 0, -1))
	# Escapamento: dois canos cromados.
	for s: float in [1.0, -1.0]:
		var x := s * 0.26
		ChapaLisa.tubo(dados, PackedVector3Array([Vector3(x, 0.27, -1.72),
			Vector3(x, 0.265, -1.86), Vector3(x, 0.262, -1.955)]), 0.021, 10, cromo,
			Carroceria.C_PARACHOQUE, false)
		ChapaLisa.torno(dados, Vector3(x, 0.262, -1.955), Vector3(0, 0, -1), Vector3.UP,
			PackedVector2Array([Vector2(0.021, 0.0), Vector2(0.016, 0.0),
			Vector2(0.016, -0.03)]), 10, PackedColorArray(), escuro, Carroceria.C_FUNDO,
			1.0, false)
	# Barra do eixo da frente, escura, atras do avental.
	ChapaLisa.tubo(dados, PackedVector3Array([Vector3(0.55, 0.30, 1.28),
		Vector3(-0.55, 0.30, 1.28)]), 0.035, 8, escuro, Carroceria.C_FUNDO, true)
