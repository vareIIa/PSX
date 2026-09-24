## A forma de cada peca de roupa, e o que se usa no rosto.
##
## O atlas da o PADRAO do tecido e a cor de vertice da a COR; o que faltava era a
## FORMA. Uma camisa social e uma camiseta com a mesma estampa eram a mesma
## caixa, e a 480x270 o que separa uma da outra nao e a textura: e a gola, a
## carreira de botoes, o capuz caido nas costas, a barra da bota subindo pela
## canela. Tudo isso aqui e caixa pequena pendurada no mesmo esqueleto, na mesma
## malha e no mesmo material do corpo — nenhuma chamada de desenho a mais.
##
## A regra do zero
## ---------------
## Modelo zero e sempre a peca de antes. A cidade inteira sorteia zero (ver
## `Aparencia.de_ficha`), entao nenhum pedestre ganha um triangulo por causa
## deste arquivo: so quem escolheu uma forma paga por ela.
##
## Mora fora de `Corpo` por dois motivos: o Corpo ja e o arquivo das poses, e
## trabalho novo em arquivo novo sobrevive a sessao paralela que reverter o
## compartilhado.
class_name Vestuario
extends RefCounted

## O corpo e a malha em montagem. Os tamanhos e alturas daqui sao os mesmos da
## tabela de `Corpo._construir`, e escalam com a altura pela mesma `_y`.
static var _mat_recorte: ShaderMaterial = null


# --- utilitario ---------------------------------------------------------------

## Caixa com orientacao propria: a lapela e a unica peca de roupa que nao e
## alinhada com o corpo, e sem ela o paleto vira um colete.
static func caixa_girada(corpo: Corpo, d: Dictionary, tamanho: Vector3,
		xform: Transform3D, cor: Color, celula: Rect2, osso: int) -> void:
	var meio := tamanho * 0.5
	for item: Array in Corpo.FACES:
		var normal: Vector3 = item[1]
		var tam2 := Vector2.ZERO
		var base := Basis()
		if absf(normal.z) > 0.5:
			tam2 = Vector2(tamanho.x, tamanho.y)
			base = Basis() if normal.z > 0.0 else Basis(Vector3.UP, PI)
		elif absf(normal.x) > 0.5:
			tam2 = Vector2(tamanho.z, tamanho.y)
			base = Basis(Vector3.UP, PI * 0.5 * signf(normal.x))
		else:
			tam2 = Vector2(tamanho.x, tamanho.z)
			base = Basis(Vector3.RIGHT, -PI * 0.5 * signf(normal.y))
		corpo._face(d, tam2, xform * Transform3D(base, normal * meio), cor, celula, osso)


static func _liso() -> Rect2:
	return Aparencia.uv_da_celula(Aparencia.PECA_MANGA, Aparencia.LINHA_PECAS)


static func _pele_cel() -> Rect2:
	return Aparencia.uv_da_celula(Aparencia.PECA_NUCA, Aparencia.LINHA_PECAS)


# --- tronco -------------------------------------------------------------------

## Gola de camisa em volta da base do pescoco.
##
## Fica entre o topo do tronco (1,38) e o comeco do pescoco (1,425), que e
## justamente a fresta que o retrato 3x4 tinha de tapar com um pescoco postico.
## Com gola, a fresta vira colarinho.
static func _gola(corpo: Corpo, d: Dictionary, cor: Color, c: float, alta: float,
		pontas: bool) -> void:
	# `c` era o fator dos membros; a gola abraca o pescoco, que engrossa com o
	# porte do jeito dele (ver `Anatomia.pescoco`).
	c = _fator_pescoco(corpo)
	var y := corpo._y(1.395 + alta * 0.5)
	var h := corpo._y(0.035 + alta)
	var liso := _liso()
	corpo._caixa(d, Vector3(0.14 * c, h, 0.025), Vector3(0.0, y, 0.058 * c), cor,
		liso, Corpo.Osso.TORSO)
	for lado: float in [-1.0, 1.0]:
		corpo._caixa(d, Vector3(0.022, h, 0.12 * c),
			Vector3(0.068 * c * lado, y, 0.0), cor, liso, Corpo.Osso.TORSO)
		if pontas:
			# As pontas do colarinho descem em diagonal para o peito.
			var z := Anatomia.frente_em(corpo.perfil(), 1.378, 0.03) + 0.004
			caixa_girada(corpo, d, Vector3(0.045, corpo._y(0.034), 0.012),
				Transform3D(Basis(Vector3.FORWARD, 0.55 * lado),
					Vector3(0.030 * lado, corpo._y(1.378), -z)),
				cor, liso, Corpo.Osso.TORSO)


## Quanto o pescoco engrossou, na escala em que a gola foi medida (0,94 no
## magro).
static func _fator_pescoco(corpo: Corpo) -> float:
	return (1.0 + 0.45 * Anatomia.gordura(corpo._aparencia)) * 0.94


## Profundidade da frente do tronco (positiva), a `x` do meio.
static func _frente(corpo: Corpo, y: float, x: float = 0.0) -> float:
	return Anatomia.frente_em(corpo.perfil(), y, x)


## Lapelas de paleto: dois paineis inclinados da gola ate o meio do peito.
##
## Encostam no ponto mais saliente do peito na faixa que cobrem: no peito da
## mulher e na barriga do gordo o painel plano teria a ponta enterrada.
static func _lapelas(corpo: Corpo, d: Dictionary, cor: Color, _hd: float,
		largura: float) -> void:
	var z := 0.0
	for y: float in [1.22, 1.26, 1.30, 1.34, 1.38]:
		z = maxf(z, _frente(corpo, y, 0.052))
	for lado: float in [-1.0, 1.0]:
		caixa_girada(corpo, d, Vector3(largura, corpo._y(0.17), 0.012),
			Transform3D(Basis(Vector3.FORWARD, -0.32 * lado),
				Vector3(0.052 * lado, corpo._y(1.30), -z - 0.006)),
			cor, _liso(), Corpo.Osso.TORSO)


## Tira da camisa aparecendo no vao do agasalho aberto.
static func _vao(corpo: Corpo, d: Dictionary, a: Dictionary, _hd: float,
		largura: float, alto: float, y: float) -> void:
	var cel := Aparencia.uv_da_celula(int(a["camisa"]), Aparencia.LINHA_CAMISA)
	var cor: Color = a["camisa_cor"]
	if int(a.get("camisa_estilo", 0)) == Aparencia.CAMISA_REGATA and alto > 0.2:
		cor = a.get("pele", Color.WHITE)
		cel = _pele_cel()
	Anatomia.fita(corpo, d, largura, y - alto * 0.5, y + alto * 0.5, cor, cel)


## A camisa social sem agasalho vai por dentro da calca, com cinto. E a unica:
## camiseta, polo e moletom por dentro leriam como uniforme.
static func camisa_por_dentro(a: Dictionary) -> bool:
	return int(a.get("camisa_estilo", 0)) == Aparencia.CAMISA_SOCIAL \
		and not bool(a.get("casaco", false))


static func _botoes(corpo: Corpo, d: Dictionary, cor: Color, _hd: float,
		ys: Array, x: float = 0.0) -> void:
	for y: float in ys:
		var osso := Anatomia.osso_na_frente(corpo, y)
		corpo._caixa(d, Vector3(0.012, 0.012, 0.005),
			Vector3(x, corpo._y(y), -_frente(corpo, y, x) - 0.005), cor, _liso(), osso)


## Punho na ponta da manga. Punho e o detalhe que diz "manga comprida de
## verdade" de longe: sem ele o braco inteiro e um tubo da cor da camisa.
static func _punhos(corpo: Corpo, d: Dictionary, cor: Color, _c: float,
		_meio_ombro: float, alto: float = 0.035) -> void:
	for lado: float in [-1.0, 1.0]:
		Anatomia.anel_braco(corpo, d, corpo._aparencia, lado, 0.868 + alto, 0.868,
			0.004, cor, _liso())


## Barra em volta do tronco, seguindo a forma: na caixa ela era uma caixa, e na
## barriga redonda ficava um aro quadrado flutuando.
static func _barra(corpo: Corpo, d: Dictionary, cor: Color, _hw: float,
		_hd: float, y: float, alto: float = 0.035) -> void:
	var osso := Corpo.Osso.TORSO if y >= Anatomia.Y_CINTO - 0.02 else Corpo.Osso.QUADRIL
	Anatomia.cinta(corpo, d, y - alto * 0.5, y + alto * 0.5, 0.010, cor, _liso(), osso)


static func camisa(corpo: Corpo, d: Dictionary, a: Dictionary, c: float,
		c_tronco: float) -> void:
	var estilo := int(a.get("camisa_estilo", 0))
	if estilo == 0:
		return
	var cor: Color = a["camisa_cor"]
	var escura := cor.darkened(0.22)
	var clara := cor.lightened(0.25)
	var hw := float(a.get("ombro", 0.42)) * c_tronco * 0.5
	var hd := 0.225 * c_tronco * 0.5
	var coberto := bool(a.get("casaco", false)) \
		and int(a.get("casaco_tipo", 1)) != Aparencia.CASACO_COLETE
	var meio_ombro := float(a.get("ombro", 0.42)) * 0.5 + 0.015

	match estilo:
		Aparencia.CAMISA_REGATA:
			if not coberto:
				# Decote: a pele aparecendo no alto do peito e o que faz a caixa
				# ler como regata, e nao como camiseta com o braco pelado.
				Anatomia.fita(corpo, d, 0.13, 1.335, 1.40, a.get("pele", Color.WHITE),
					Anatomia.miolo(_pele_cel()))
		Aparencia.CAMISA_SOCIAL:
			_gola(corpo, d, clara, c, 0.0, true)
			if not coberto:
				Anatomia.fita(corpo, d, 0.02, 1.05, 1.37, escura, _liso())
				_botoes(corpo, d, clara, hd, [1.32, 1.24, 1.16, 1.08])
			if camisa_por_dentro(a):
				# Cinto de couro por cima do cos, fivela de metal na frente.
				var couro := Color("3a2a20")
				Anatomia.cinta(corpo, d, 1.03, 1.062, 0.014, couro, _liso(),
					Corpo.Osso.QUADRIL)
				var zf := _frente(corpo, 1.046) + 0.026
				corpo._caixa(d, Vector3(0.042, corpo._y(0.034), 0.008),
					Vector3(0.0, corpo._y(1.046), -zf), Color("c8b27a"), _liso(),
					Corpo.Osso.QUADRIL)
				corpo._caixa(d, Vector3(0.026, corpo._y(0.018), 0.004),
					Vector3(0.0, corpo._y(1.046), -zf - 0.005), couro, _liso(),
					Corpo.Osso.QUADRIL)
				# Bolso no peito esquerdo de quem veste.
				var xb := Anatomia.medida(corpo.perfil(), 1.28).x * 0.5
				Anatomia.fita(corpo, d, 0.05, 1.25, 1.305, escura, _liso(), xb)
				_punhos(corpo, d, clara, c, meio_ombro)
		Aparencia.CAMISA_POLO:
			_gola(corpo, d, cor, c, 0.0, true)
			if not coberto:
				Anatomia.fita(corpo, d, 0.022, 1.29, 1.38, escura, _liso())
				_botoes(corpo, d, clara, hd, [1.355, 1.31])
		Aparencia.CAMISA_MOLETOM:
			# O capuz fica sempre: caido por cima da gola do agasalho e o jeito
			# mais comum de usar os dois, e e a silhueta que se ve de costas.
			var cg := _fator_pescoco(corpo)
			var costas := Anatomia.medida(corpo.perfil(), 1.38).z
			corpo._caixa(d, Vector3(0.20 * cg, corpo._y(0.10), 0.07),
				Vector3(0.0, corpo._y(1.40), costas + 0.03), cor, _liso(),
				Corpo.Osso.TORSO)
			for lado: float in [-1.0, 1.0]:
				corpo._caixa(d, Vector3(0.03, corpo._y(0.10), 0.10 * cg),
					Vector3(0.085 * cg * lado, corpo._y(1.41), 0.035), cor, _liso(),
					Corpo.Osso.TORSO)
			if not coberto:
				# Bolso canguru: segue a barriga, que e onde ele fica.
				var larg := Anatomia.medida(corpo.perfil(), 1.105).x * 1.15
				Anatomia.fita(corpo, d, larg, 1.065, 1.15, escura, _liso(), 0.0, 0.006)
				_barra(corpo, d, escura, hw, hd, 1.045, 0.04)
				for lado: float in [-1.0, 1.0]:
					Anatomia.fita(corpo, d, 0.008, 1.285, 1.375, clara, _liso(),
						0.026 * lado, 0.005)
				_punhos(corpo, d, escura, c, meio_ombro, 0.04)
		Aparencia.CAMISA_GOLA_ALTA:
			Anatomia.gola_tubo(corpo, d, a, 1.37, 1.47, 0.012, cor, _liso())
			if not coberto:
				_punhos(corpo, d, escura, c, meio_ombro, 0.05)


static func casaco(corpo: Corpo, d: Dictionary, a: Dictionary, c: float,
		c_tronco: float) -> void:
	if not bool(a.get("casaco", false)):
		return
	var tipo := int(a.get("casaco_tipo", Aparencia.CASACO_JAQUETA))
	if tipo <= Aparencia.CASACO_JAQUETA:
		return
	var cor: Color = a["casaco_cor"]
	var escura := cor.darkened(0.28)
	var clara := cor.lightened(0.22)
	var hw := float(a.get("ombro", 0.42)) * c_tronco * 0.5
	var hd := 0.225 * c_tronco * 0.5
	var meio_ombro := float(a.get("ombro", 0.42)) * 0.5 + 0.015
	var liso := _liso()

	match tipo:
		Aparencia.CASACO_COURO:
			_vao(corpo, d, a, hd, 0.07, 0.30, 1.225)
			_lapelas(corpo, d, escura, hd, 0.036)
			_gola(corpo, d, cor, c, 0.02, false)
			# O ziper nas duas bordas do vao, em metal claro.
			for lado: float in [-1.0, 1.0]:
				Anatomia.fita(corpo, d, 0.006, 1.06, 1.34, Color("b8b4aa"), liso,
					0.037 * lado, 0.004)
			_barra(corpo, d, escura, hw, hd, 1.055)
			_punhos(corpo, d, escura, c, meio_ombro)
		Aparencia.CASACO_SOBRETUDO:
			# A aba longa pendura no QUADRIL e desce ate o joelho. As pernas
			# passam por dentro dela ao andar, como a saia: e o mesmo acordo de
			# corpo rigido que o PS1 fazia.
			Anatomia.saia(corpo, d, a, 1.06, 0.58, cor,
				Aparencia.uv_da_celula(int(a.get("casaco_cel", 0)),
					Aparencia.LINHA_CASACO), Corpo.Osso.QUADRIL, 0.018)
			_lapelas(corpo, d, escura, hd, 0.046)
			_gola(corpo, d, cor, c, 0.03, false)
			_barra(corpo, d, escura, hw, hd, 1.065, 0.032)
			corpo._caixa(d, Vector3(0.03, corpo._y(0.03), 0.006),
				Vector3(0.0, corpo._y(1.065), -_frente(corpo, 1.065) - 0.016),
				Color("b8a070"), liso, Corpo.Osso.TORSO)
			for lado: float in [-1.0, 1.0]:
				_botoes(corpo, d, escura, hd, [1.20, 1.13], 0.045 * lado)
			_punhos(corpo, d, escura, c, meio_ombro, 0.05)
		Aparencia.CASACO_CORTA_VENTO:
			Anatomia.gola_tubo(corpo, d, a, 1.375, 1.45, 0.018, cor, liso)
			Anatomia.fita(corpo, d, 0.007, 1.04, 1.38, Color("b8b4aa"), liso)
			# Faixa de outra cor atravessando o peito: e o corta-vento dos anos
			# noventa, e e o que separa a peca de uma jaqueta lisa a vinte metros.
			_barra(corpo, d, clara, hw - 0.004, hd - 0.004, 1.27, 0.06)
			_barra(corpo, d, escura, hw, hd, 1.055)
			_punhos(corpo, d, escura, c, meio_ombro)
		Aparencia.CASACO_COLETE:
			_vao(corpo, d, a, hd, 0.06, 0.10, 1.335)
			_botoes(corpo, d, escura, hd, [1.26, 1.19, 1.12])
			for lado: float in [-1.0, 1.0]:
				var xb := Anatomia.medida(corpo.perfil(), 1.13).x * 0.5 * lado
				Anatomia.fita(corpo, d, 0.05, 1.123, 1.137, escura, liso, xb, 0.004)
		Aparencia.CASACO_BLAZER:
			_vao(corpo, d, a, hd, 0.05, 0.26, 1.25)
			_lapelas(corpo, d, escura, hd, 0.04)
			_gola(corpo, d, cor, c, 0.0, false)
			# Ombreira: o paleto alarga o ombro, e e o ombro largo que le como
			# roupa de trabalho de escritorio.
			for lado: float in [-1.0, 1.0]:
				Anatomia.anel_braco(corpo, d, a, lado, 1.385, 1.33, 0.008, cor, liso)
			# A barra do paleto passa da cintura e cai por cima do quadril.
			Anatomia.saia(corpo, d, a, 1.06, 0.95, cor, liso, Corpo.Osso.TORSO, 0.016)
			var xl := Anatomia.medida(corpo.perfil(), 1.29).x * 0.55
			Anatomia.fita(corpo, d, 0.022, 1.283, 1.297, Color("e8e2d2"), liso, xl,
				0.005)
			_botoes(corpo, d, escura, hd, [1.10, 1.04])
			_punhos(corpo, d, escura, c, meio_ombro, 0.03)


# --- pernas -------------------------------------------------------------------

static func calca(corpo: Corpo, d: Dictionary, a: Dictionary, c: float,
		c_tronco: float) -> void:
	var estilo := int(a.get("calca_estilo", 0))
	if estilo == 0:
		return
	var cor: Color = a["calca_cor"]
	var escura := cor.darkened(0.22)
	var meio_quadril := Anatomia.meio_quadril(a)
	var liso := _liso()
	match estilo:
		Aparencia.CALCA_CARGO:
			for lado: float in [-1.0, 1.0]:
				var osso := Corpo.Osso.COXA_E if lado < 0.0 else Corpo.Osso.COXA_D
				var x := (meio_quadril + Anatomia.raio_perna(a, 0.62).x + 0.011) * lado
				corpo._caixa(d, Vector3(0.022, corpo._y(0.10), 0.085 * c),
					Vector3(x, corpo._y(0.62), 0.0), escura, liso, osso)
				corpo._caixa(d, Vector3(0.026, corpo._y(0.02), 0.09 * c),
					Vector3(x, corpo._y(0.675), 0.0), escura.darkened(0.2), liso, osso)
		Aparencia.CALCA_JOGGER:
			# Punho elastico no tornozelo: a perna da calca afina ate ele.
			for lado: float in [-1.0, 1.0]:
				Anatomia.anel_perna(corpo, d, a, lado, 0.13, 0.075, 0.004, escura, liso)
			Anatomia.cinta(corpo, d, 0.985, 1.025, 0.004, escura, liso,
				Corpo.Osso.QUADRIL)
		Aparencia.CALCA_BERMUDA:
			# A barra no joelho ja sai da perna (ver `Anatomia.perna`).
			pass
		Aparencia.CALCA_SAIA_LONGA:
			Anatomia.saia(corpo, d, a, 0.97, 0.30, cor,
				Anatomia.tecido(Aparencia.uv_da_celula(int(a["calca"]), Aparencia.LINHA_CALCA)),
				Corpo.Osso.QUADRIL, 0.012, 0.04)


## Quem desenha a canela: a calca, ou a pele (saia e bermuda).
static func canela_a_mostra(a: Dictionary) -> bool:
	if bool(a.get("saia", false)):
		return true
	return int(a.get("calca_estilo", 0)) == Aparencia.CALCA_BERMUDA


## O calcado do modelo escolhido. Devolve false para o modelo zero, e o Corpo
## desenha o sapato de sempre.
static func sapato(corpo: Corpo, d: Dictionary, a: Dictionary, x: float,
		osso: int, cel_sapato: Rect2) -> bool:
	var estilo := int(a.get("sapato_estilo", 0))
	if estilo == 0:
		return false
	var cor: Color = a["sapato_cor"]
	var liso := _liso()
	match estilo:
		Aparencia.SAPATO_CANO_ALTO:
			corpo._caixa(d, Vector3(0.13, corpo._y(0.075), 0.25),
				Vector3(x, corpo._y(0.047), -0.045), cor, cel_sapato, osso)
			corpo._caixa(d, Vector3(0.132, corpo._y(0.075), 0.155),
				Vector3(x, corpo._y(0.115), 0.0), cor, cel_sapato, osso)
			# Solado branco: e o que le como tenis de basquete e nao como bota.
			corpo._caixa(d, Vector3(0.134, corpo._y(0.022), 0.256),
				Vector3(x, corpo._y(0.011), -0.045), Color("e4e0d6"), liso, osso)
		Aparencia.SAPATO_BOTA:
			corpo._caixa(d, Vector3(0.132, corpo._y(0.17), 0.158),
				Vector3(x, corpo._y(0.15), 0.0), cor, cel_sapato, osso)
			corpo._caixa(d, Vector3(0.13, corpo._y(0.075), 0.262),
				Vector3(x, corpo._y(0.047), -0.05), cor, cel_sapato, osso)
			corpo._caixa(d, Vector3(0.134, corpo._y(0.024), 0.266),
				Vector3(x, corpo._y(0.012), -0.05), cor.darkened(0.5), liso, osso)
		Aparencia.SAPATO_SOCIAL:
			corpo._caixa(d, Vector3(0.114, corpo._y(0.055), 0.24),
				Vector3(x, corpo._y(0.035), -0.04), cor, liso, osso)
			# O bico afina: uma caixa menor na ponta.
			corpo._caixa(d, Vector3(0.09, corpo._y(0.04), 0.05),
				Vector3(x, corpo._y(0.028), -0.18), cor, liso, osso)
			corpo._caixa(d, Vector3(0.116, corpo._y(0.012), 0.27),
				Vector3(x, corpo._y(0.006), -0.052), cor.darkened(0.45), liso, osso)
		Aparencia.SAPATO_CHINELO:
			corpo._caixa(d, Vector3(0.115, corpo._y(0.018), 0.25),
				Vector3(x, corpo._y(0.009), -0.045), cor, liso, osso)
			corpo._caixa(d, Vector3(0.094, corpo._y(0.045), 0.215),
				Vector3(x, corpo._y(0.041), -0.04), a.get("pele", Color.WHITE),
				_pele_cel(), osso)
			corpo._caixa(d, Vector3(0.10, corpo._y(0.012), 0.02),
				Vector3(x, corpo._y(0.066), -0.10), cor.lightened(0.3), liso, osso)
	return true


# --- cabeca -------------------------------------------------------------------

## Chapeus 5 a 7. Os quatro primeiros continuam em `Corpo._montar_chapeu`.
static func chapeu(corpo: Corpo, d: Dictionary, a: Dictionary, celula: Rect2) -> bool:
	var tipo := int(a.get("chapeu_tipo", 0))
	if tipo < 5 or not bool(a.get("chapeu", false)):
		return false
	var cor: Color = a.get("chapeu_cor", Color("6f6a60"))
	var topo := 1.7175
	match tipo:
		5:
			# Boina: disco largo caido para um lado, com o pino no alto.
			corpo._caixa(d, Vector3(0.25, corpo._y(0.045), 0.25),
				Vector3(0.022, corpo._y(topo + 0.022), 0.01), cor, celula,
				Corpo.Osso.CABECA)
			corpo._caixa(d, Vector3(0.02, corpo._y(0.016), 0.02),
				Vector3(0.022, corpo._y(topo + 0.052), 0.01), cor, celula,
				Corpo.Osso.CABECA)
		6:
			corpo._caixa(d, Vector3(0.222, corpo._y(0.07), 0.232),
				Vector3(0.0, corpo._y(topo + 0.03), 0.0), cor, celula,
				Corpo.Osso.CABECA)
			corpo._caixa(d, Vector3(0.216, corpo._y(0.016), 0.11),
				Vector3(0.0, corpo._y(topo + 0.002), 0.16), cor, celula,
				Corpo.Osso.CABECA)
		_:
			# Faixa na testa, por cima do cabelo.
			corpo._caixa(d, Vector3(0.236, corpo._y(0.032), 0.246),
				Vector3(0.0, corpo._y(topo - 0.045), 0.0), cor, celula,
				Corpo.Osso.CABECA)
	return true


## Onde fica o olho na cara, em metros do modelo. Sai da celula de 32 px: o olho
## ocupa as colunas 6 a 11 e 20 a 25 e as linhas 13 a 15 nos rostos de estudio,
## que sao os que tem as feicoes fixas.
const OLHO_X := 0.0468
const OLHO_Y := 1.6065
const CARA_Z := -0.1115


static func oculos(corpo: Corpo, d: Dictionary, a: Dictionary) -> void:
	var tipo := int(a.get("oculos", 0))
	if tipo <= 0:
		return
	var y := corpo._y(OLHO_Y)
	var z := CARA_Z - 0.012
	var liso := _liso()
	var osso := Corpo.Osso.CABECA
	var aro := Color("2a2624")
	var lente := Color("141619")
	var larg := 0.056
	var alto := 0.038
	var esp := 0.006
	match tipo:
		Aparencia.OCULOS_ARO_FINO:
			aro = Color("b89a5a")
			larg = 0.046
			alto = 0.032
			esp = 0.004
		Aparencia.OCULOS_ESPORTIVO:
			aro = Color("2c3440")
			lente = Color("1c2a3a")

	if tipo == Aparencia.OCULOS_ESPORTIVO:
		corpo._caixa(d, Vector3(0.20, 0.036, 0.006), Vector3(0.0, y, z), lente,
			liso, osso)
		corpo._caixa(d, Vector3(0.206, 0.008, 0.01), Vector3(0.0, y + 0.02, z),
			aro, liso, osso)
	else:
		for lado: float in [-1.0, 1.0]:
			var cx := OLHO_X * lado
			if tipo == Aparencia.OCULOS_ESCURO:
				corpo._caixa(d, Vector3(larg + 0.004, alto + 0.004, 0.004),
					Vector3(cx, y - 0.002, z), lente, liso, osso)
				corpo._caixa(d, Vector3(larg + 0.006, 0.009, 0.01),
					Vector3(cx, y + alto * 0.5 + 0.002, z), aro, liso, osso)
			else:
				# Aro de quatro barras. Quatro caixas finas custam mais do que uma
				# placa com furo desenhado, e sao o que aparece de perfil.
				corpo._caixa(d, Vector3(larg, esp + 0.001, 0.008),
					Vector3(cx, y + alto * 0.5, z), aro, liso, osso)
				corpo._caixa(d, Vector3(larg, esp, 0.008),
					Vector3(cx, y - alto * 0.5, z), aro, liso, osso)
				for borda: float in [-1.0, 1.0]:
					corpo._caixa(d, Vector3(esp, alto, 0.008),
						Vector3(cx + borda * larg * 0.5, y, z), aro, liso, osso)
		corpo._caixa(d, Vector3(OLHO_X * 2.0 - larg + 0.004, 0.005, 0.008),
			Vector3(0.0, y + 0.008, z), aro, liso, osso)
	# Hastes ate a orelha: sem elas, de perfil, os oculos flutuam na frente da
	# cara.
	for lado: float in [-1.0, 1.0]:
		corpo._caixa(d, Vector3(0.006, 0.006, 0.12),
			Vector3(0.1095 * lado, y + 0.012, z + 0.064), aro, liso, osso)


## Barba cheia tem volume: o recorte pinta a cara, e estas caixas dao o maxilar
## e o queixo que o recorte nao da de perfil.
static func barba_volume(corpo: Corpo, d: Dictionary, a: Dictionary,
		cel_cabelo: Rect2) -> void:
	var tipo := int(a.get("barba", 0))
	if tipo < Aparencia.BARBA_CHEIA:
		return
	var cor: Color = a["cabelo_cor"]
	var osso := Corpo.Osso.CABECA
	var espessa := tipo == Aparencia.BARBA_ESPESSA
	for lado: float in [-1.0, 1.0]:
		corpo._caixa(d, Vector3(0.012, corpo._y(0.10), 0.15),
			Vector3(0.1135 * lado, corpo._y(1.52), -0.03), cor, cel_cabelo, osso)
	corpo._caixa(d, Vector3(0.20, 0.014, 0.14),
		Vector3(0.0, corpo._y(1.4725) - 0.006, -0.035), cor, cel_cabelo, osso)
	if espessa:
		corpo._caixa(d, Vector3(0.15, corpo._y(0.07), 0.03),
			Vector3(0.0, corpo._y(1.485), CARA_Z - 0.012), cor, cel_cabelo, osso)


## O quad da barba, colado na cara. Malha separada porque o recorte precisa de
## material com corte de alfa, e o corpo nao pode ter: a pele inteira sairia
## furada onde o atlas tem alfa zero.
static func dados_recorte(corpo: Corpo, a: Dictionary) -> Dictionary:
	var d := PSXMesh.dados_com_ossos()
	var tipo := int(a.get("barba", 0))
	if tipo <= 0:
		return d
	var celula := Aparencia.uv_da_celula(tipo - 1, Aparencia.LINHA_BARBA)
	var xform := Transform3D(Basis(Vector3.UP, PI),
		Vector3(0.0, corpo._y(1.595), CARA_Z - 0.0015))
	corpo._face(d, Vector2(0.214, corpo._y(0.245)), xform, a["cabelo_cor"],
		celula, Corpo.Osso.CABECA)
	return d


## Os olhos fechados: o mesmo quad da cara, com a celula da palpebra tingida
## pela pele. Quem liga e desliga e `Corpo` (ver `piscar`).
const PALPEBRA_COLUNA := 5


static func dados_palpebra(corpo: Corpo, a: Dictionary) -> Dictionary:
	var d := PSXMesh.dados_com_ossos()
	var celula := Aparencia.uv_da_celula(PALPEBRA_COLUNA, Aparencia.LINHA_BARBA)
	# Um milimetro a frente da barba, para os dois recortes nao brigarem.
	var xform := Transform3D(Basis(Vector3.UP, PI),
		Vector3(0.0, corpo._y(1.595), CARA_Z - 0.0025))
	corpo._face(d, Vector2(0.214, corpo._y(0.245)), xform, a.get("pele", Color.WHITE),
		celula, Corpo.Osso.CABECA)
	return d


## O material do corpo com recorte ligado. Um so para todo mundo, refeito se o
## estilo grafico trocou o shader do material de origem.
static func material_recorte(base: ShaderMaterial) -> ShaderMaterial:
	if _mat_recorte == null or _mat_recorte.shader != base.shader:
		_mat_recorte = base.duplicate() as ShaderMaterial
		_mat_recorte.set_shader_parameter(&"alpha_cutoff", 0.5)
	return _mat_recorte
