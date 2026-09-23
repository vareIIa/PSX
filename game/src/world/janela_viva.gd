## O que vai dentro do vao de uma janela: vidro, folha, cortina, flor, grade, e
## o comodo atras quando ela esta aberta.
##
## Por que existe
## -------------
## A rua do interior de Minas se le pelas janelas. Uma casa tem a folha de
## madeira azul escancarada contra a parede e a floreira de geranio no peitoril;
## a vizinha tem tudo fechado porque o dono viajou; a do lado deixa a janela
## aberta e da para ver a sala, o quadro na parede, a cortina de renda mexendo.
## Antes a janela era um retangulo de vidro escuro repetido no mesmo passo em
## todas as casas.
##
## Como se usa
## -----------
##   1. `sortear` decide o ESTADO da janela (modelo, se esta aberta, se tem flor,
##      cortina, grade, que comodo tem atras) a partir do estilo da casa e do
##      jeito do morador. E o estado que da vida: a mesma casa, o mesmo morador.
##   2. O vao sai de ParedeVazada.erguer com `"tampa": precisa_tampa(estado)` —
##      a janela aberta monta o comodo inteiro e nao quer tampa.
##   3. `preencher` poe o conteudo no quadro que ParedeVazada devolveu.
##
## Nada aqui fecha o vao pela metade: todo estado cobre o furo inteiro, com
## vidro, folha ou comodo. A regua e tests/bancada_janela_viva.gd.
##
## Miudeza (flor, vaso, movel do comodo, cortina) vai no balde "material@perto"
## (ChunkManager.ALCANCE_PERTO): some de longe. A casca do comodo nao, senao o
## vao aberto viraria um buraco para o limbo quando a mobilia sumisse.
class_name JanelaViva
extends RefCounted

const PERTO := "@perto"


## O balde "de perto" de um material (ver ChunkManager.ALCANCE_PERTO).
static func _p(material: StringName) -> StringName:
	return StringName(String(material) + PERTO)

## Estado da abertura.
enum Abertura { FECHADA, ENTREABERTA, ABERTA }

## Bancada e captura: `--janelas-abertas` abre toda janela que pode abrir, para
## fotografar o comodo de perto sem cacar a janela sorteada aberta.
static var forcar_aberta := OS.get_cmdline_user_args().has("--janelas-abertas")

## Espessura da folha de madeira.
const FOLHA := 0.035
## Onde fica o vidro, antes do fundo do recuo.
const VIDRO_ANTES_DO_FUNDO := 0.05

## Esquadria de madeira pintada, a cor que a rua de Minas tem: azul colonial,
## verde, sangue-de-boi, ocre, branco e o marrom do verniz velho.
const ESQUADRIAS: Array[Color] = [
	Color("2f5d8a"), Color("3e6b48"), Color("7b2e2a"), Color("b98a2f"),
	Color("e6e1d3"), Color("5b3b24"), Color("2d4f63"), Color("6a8a3a"),
]
## Aluminio, bronze e o ferro pintado de branco ou verde da casa dos anos 70.
const ALUMINIOS: Array[Color] = [
	Color("c9ccce"), Color("8a6a48"), Color("e8e8e4"), Color("4f6b4a"),
]
const CORTINAS: Array[Color] = [
	Color("f2eee4"), Color("e7d9bb"), Color("c9d8e6"), Color("ecc9c6"),
	Color("dcc86e"), Color("b4c9a8"), Color("b95c4d"), Color("f4f1ea"),
]
const PAREDES_INTERNAS: Array[Color] = [
	Color("eadfc6"), Color("d3e3d9"), Color("ead3c9"), Color("dbdcea"),
	Color("f1e7ae"), Color("cde0ea"), Color("f0ebe1"), Color("e9d6a8"),
]
## Celulas do atlas de flores (assets/textures/flores.png, linha 0): margarida,
## geranio vermelho, amarelo, lavanda, a samambaia rala, e a rosa.
const FLORES: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 0), Vector2i(7, 0), Vector2i(2, 0), Vector2i(0, 0),
	Vector2i(3, 0), Vector2i(7, 0), Vector2i(1, 0),
]
const TERRACOTA := Color("b5623b")


## Decide o estado de uma janela.
##
## `estilo`: &"colonial", &"ecletico", &"moderno", &"popular", &"predio".
## `morador`: &"zelosa", &"idoso", &"familia", &"fechada", &"abandonada",
## &"jovem". `andar`: 0 e o terreo. `acesa`: o comodo tem luz.
## `casa` guarda o que e da casa inteira (a mesma cor de esquadria e a mesma
## cortina em todas as janelas dela); quem monta a fachada passa o MESMO
## dicionario para todas as janelas de uma casa.
static func sortear(rng: RandomNumberGenerator, estilo: StringName,
		morador: StringName, andar: int, acesa: bool, casa: Dictionary) -> Dictionary:
	if not casa.has("esquadria"):
		var metal := estilo == &"popular" or estilo == &"predio" or estilo == &"moderno"
		casa["esquadria"] = ALUMINIOS[rng.randi() % ALUMINIOS.size()] if metal \
			else ESQUADRIAS[rng.randi() % ESQUADRIAS.size()]
		casa["cortina"] = CORTINAS[rng.randi() % CORTINAS.size()]
		casa["flor"] = rng.randi() % FLORES.size()
		casa["parede_interna"] = PAREDES_INTERNAS[rng.randi() % PAREDES_INTERNAS.size()]
	var e := {
		"esquadria": casa["esquadria"], "cortina": casa["cortina"],
		"flor": FLORES[(int(casa["flor"]) + rng.randi_range(0, 1)) % FLORES.size()],
		"parede_interna": casa["parede_interna"],
		"acesa": acesa, "estilo": estilo,
	}
	# Modelo pelo estilo da casa.
	match estilo:
		&"colonial":
			e["modelo"] = &"folhas"
		&"ecletico":
			e["modelo"] = &"veneziana" if rng.randf() < 0.6 else &"folhas"
		&"moderno":
			e["modelo"] = &"correr" if rng.randf() < 0.55 else &"veneziana"
		&"popular":
			e["modelo"] = &"basculante" if rng.randf() < 0.55 else &"correr"
		_:
			e["modelo"] = &"correr"

	# Aberta, entreaberta ou fechada: e o morador que decide.
	var p_aberta := 0.18
	var p_entre := 0.22
	match morador:
		&"zelosa":
			p_aberta = 0.42
			p_entre = 0.25
		&"familia":
			p_aberta = 0.34
			p_entre = 0.2
		&"idoso":
			p_aberta = 0.12
			p_entre = 0.45
		&"jovem":
			p_aberta = 0.3
			p_entre = 0.1
		&"fechada", &"abandonada":
			p_aberta = 0.0
			p_entre = 0.08
	var sorte := rng.randf()
	var abertura := Abertura.FECHADA
	if sorte < p_aberta:
		abertura = Abertura.ABERTA
	elif sorte < p_aberta + p_entre:
		abertura = Abertura.ENTREABERTA
	if forcar_aberta:
		abertura = Abertura.ABERTA
	# Basculante fica fechado: as abas basculadas saiam como uma chapa solta na
	# frente do vitro, e a vista do comodo ela nao da.
	if e["modelo"] == &"basculante":
		abertura = Abertura.FECHADA
	e["abertura"] = abertura
	# Folha fechada por inteiro, a casa de quem viajou e a de ninguem.
	e["folhas_fechadas"] = morador == &"fechada" or morador == &"abandonada" \
		or (abertura == Abertura.FECHADA and rng.randf() < 0.35)

	# Flor: floreira embaixo da janela, ou vaso no peitoril.
	var p_flor := {&"zelosa": 0.8, &"idoso": 0.5, &"familia": 0.25, &"jovem": 0.3}
	var pf: float = p_flor.get(morador, 0.08)
	e["floreira"] = andar <= 1 and rng.randf() < pf
	e["vasos"] = 0 if bool(e["floreira"]) or rng.randf() > pf * 0.7 \
		else rng.randi_range(1, 3)
	e["samambaia"] = andar >= 1 and rng.randf() < pf * 0.3
	# Grade: terreo de casa popular e moderna; colonial quase nunca.
	var p_grade := {&"popular": 0.8, &"moderno": 0.65, &"predio": 0.5,
		&"ecletico": 0.3, &"colonial": 0.12}
	e["grade"] = 0
	if andar == 0 and rng.randf() < float(p_grade.get(estilo, 0.3)):
		e["grade"] = 2 if rng.randf() < 0.35 else 1
	e["cortina_na_janela"] = rng.randf() < 0.8
	e["comodo"] = [&"sala", &"quarto", &"cozinha"][rng.randi() % 3]
	e["peitoril_externo"] = estilo != &"popular" or rng.randf() < 0.4
	e["semente"] = rng.randi()
	return e


## O vao da janela deste estado precisa da tampa do ParedeVazada? So a janela
## aberta nao: o comodo atras fecha o fundo.
static func precisa_tampa(estado: Dictionary) -> bool:
	return int(estado.get("abertura", Abertura.FECHADA)) != Abertura.ABERTA \
		or estado.get("modelo", &"") == &"basculante"


## Profundidade do recuo que o estilo pede (parede grossa na colonial).
static func profundidade(estilo: StringName) -> float:
	match estilo:
		&"colonial":
			return 0.32
		&"ecletico":
			return 0.26
		&"popular":
			return 0.14
		_:
			return 0.18


## O quadro de um vao, com as contas de posicao que todas as pecas usam.
class Vao extends RefCounted:
	var pe: Vector3
	var lat: Vector3
	var nor: Vector3
	var giro: float
	var direcao: int
	var w: float
	var h: float
	var prof: float
	var arco: float
	## Altura do vao acima do pe da parede (rect.position.y).
	var base_y: float

	## Ponto do vao: `u` do meio para `lat`, `y` do pe do vao para cima, `d` do
	## plano da fachada para dentro (negativo sai para a rua).
	func p(u: float, y: float, d: float) -> Vector3:
		return pe + lat * u + Vector3(0.0, y, 0.0) - nor * d

	## Base com X ao longo da fachada, Y para cima e Z para a rua.
	func base() -> Basis:
		return Basis(lat, Vector3.UP, nor)


static func _vao(quadro: Dictionary) -> Vao:
	var v := Vao.new()
	v.pe = quadro["pe"]
	v.lat = quadro["lateral"]
	v.nor = quadro["normal"]
	v.giro = quadro["giro"]
	v.direcao = quadro["direcao"]
	v.w = quadro["largura"]
	v.h = quadro["altura"]
	v.prof = quadro["prof"]
	v.arco = quadro.get("arco", 0.0)
	v.base_y = (quadro["rect"] as Rect2).position.y
	return v


## Poe o conteudo do vao. `livre` e quanta parede sobra de cada lado do vao
## (x = esquerda, y = direita), para a folha aberta deitar sem invadir a
## janela vizinha.
static func preencher(sup: Dictionary, quadro: Dictionary, estado: Dictionary,
		livre: Vector2 = Vector2(9.0, 9.0)) -> void:
	var ob := Obra.new()
	preencher_em(ob, quadro, estado, livre)
	ob.despejar(sup)


## O mesmo, num canteiro (Obra) que quem monta a fachada despeja uma vez so.
static func preencher_em(ob: Obra, quadro: Dictionary, estado: Dictionary,
		livre: Vector2 = Vector2(9.0, 9.0)) -> void:
	var v := _vao(quadro)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(estado.get("semente", 1))
	var abertura: int = estado.get("abertura", Abertura.FECHADA)
	var modelo: StringName = estado.get("modelo", &"correr")
	var esquadria: Color = estado["esquadria"]
	# Onde o arco nasce: folha e vidro de correr vao ate ali; acima, a bandeira.
	var h_folha := v.h - v.arco
	var d_vidro := v.prof - VIDRO_ANTES_DO_FUNDO
	var vidro_mat: StringName = &"janela_acesa" if bool(estado["acesa"]) \
		else &"janela_apagada"
	# Vitro de banheiro e de deposito: vidro canelado, que nao deixa ver dentro.
	vidro_mat = estado.get("vidro", vidro_mat)

	if abertura == Abertura.ABERTA and modelo != &"basculante":
		_comodo(ob, v, estado, rng)
		if bool(estado.get("cortina_na_janela", true)):
			_cortinas(ob, v, estado, rng, d_vidro + 0.06)
		# A bandeira do arco continua de vidro, fixa.
		if v.arco > 0.0:
			_vidro(ob, v, vidro_mat, 0.0, h_folha + v.arco * 0.5, v.w + 0.04,
				v.arco + 0.04, d_vidro)
	else:
		_vidro(ob, v, vidro_mat, 0.0, v.h * 0.5, v.w + 0.04, v.h + 0.04, d_vidro)

	match modelo:
		&"folhas", &"veneziana":
			_marco(ob, v, esquadria, d_vidro - 0.02, &"tabua")
			var angulo := 0.0
			if abertura == Abertura.ABERTA:
				angulo = PI - 0.08
			elif abertura == Abertura.ENTREABERTA:
				angulo = rng.randf_range(1.2, 1.9)
			elif not bool(estado.get("folhas_fechadas", false)):
				# Fechada so no vidro: folha aberta de dia, encostada na parede.
				angulo = PI - 0.08 if rng.randf() < 0.6 else rng.randf_range(1.3, 1.8)
			_folhas(ob, v, esquadria, h_folha, angulo, modelo == &"veneziana", livre,
				float(estado.get("afasta_folha", 0.0)))
		&"correr":
			_correr(ob, v, esquadria, h_folha, d_vidro, abertura == Abertura.ABERTA,
				vidro_mat)
		&"basculante":
			_basculante(ob, v, esquadria, h_folha, d_vidro,
				abertura != Abertura.FECHADA)

	if bool(estado.get("peitoril_externo", true)) and v.base_y > 0.3:
		# Peitoril de pedra, saindo 5 cm da parede: e a linha de sombra que
		# assenta a janela na fachada.
		ob.caixa(&"concreto", v.p(0.0, -0.035, -0.02),
			Vector3(v.w + 0.2, 0.07, 0.12 + 0.02), Color("d8d2c2"), v.giro)
	var grade: int = estado.get("grade", 0)
	if grade > 0:
		# Entre a folha fechada (rente a fachada) e o marco do vidro.
		_grade(ob, v, h_folha, grade == 2, maxf(0.045, d_vidro - 0.06))
	if bool(estado.get("floreira", false)) and v.base_y > 0.3:
		_floreira(ob, v, estado, rng)
	elif int(estado.get("vasos", 0)) > 0 and grade == 0:
		_vasos(ob, v, estado, rng, int(estado["vasos"]), d_vidro)
	if bool(estado.get("samambaia", false)):
		_samambaia(ob, v, rng)


# --- vidro e esquadria -------------------------------------------------------

## Placa de vidro no plano `d`, centrada em (u, y). O shader do MODERNO desenha
## caixilho e sala atras pela UV2; no PS1 e a textura de sempre.
static func _vidro(ob: Obra, v: Vao, mat: StringName, u: float, y: float,
		larg: float, alt: float, d: float) -> void:
	ob.parede(mat, v.p(u, y, d), Vector2(larg, alt), v.giro)


## Marco da janela: quatro reguas em volta do vidro, rente a ele.
static func _marco(ob: Obra, v: Vao, cor: Color, d: float, mat: StringName) -> void:
	# Em placa, de frente para a rua: o marco fica no fundo do vao, e a face de
	# lado dele a ombreira ja esconde. Caixa custava 48 triangulos por janela.
	var t := 0.07
	for lado: float in [-1.0, 1.0]:
		ob.placa(mat, v.p(lado * (v.w * 0.5 - t * 0.5), v.h * 0.5, d - 0.02),
			Vector2(t, v.h), v.giro, cor)
	ob.placa(mat, v.p(0.0, v.h - t * 0.5, d - 0.02), Vector2(v.w - t * 2.0, t),
		v.giro, cor)
	ob.placa(mat, v.p(0.0, t * 0.5, d - 0.02), Vector2(v.w - t * 2.0, t), v.giro,
		cor)


## As duas folhas de madeira, dobradas na quina de fora do vao. `angulo` 0 e
## fechada (dentro do vao, na frente do vidro) e PI e aberta, deitada na parede.
## Com pouca parede do lado a folha para no meio do caminho, de lado para a rua.
##
## `afasta` tira a dobradica da parede: com cercadura saliente em volta do vao,
## a folha aberta deita por cima dela em vez de atravessa-la.
static func _folhas(ob: Obra, v: Vao, cor: Color, h_folha: float, angulo: float,
		veneziana: bool, livre: Vector2, afasta: float = 0.0) -> void:
	var lw := v.w * 0.5 - 0.01
	var lh := h_folha - 0.02
	for lado: int in [0, 1]:
		var espaco := livre.x if lado == 0 else livre.y
		var th := angulo
		if th > PI * 0.6 and espaco < lw + 0.06:
			th = PI * 0.55
		var sinal := 1.0 if lado == 0 else -1.0
		# Dobradica na quina do vao, no plano da fachada.
		var dobradica := v.p(-sinal * v.w * 0.5, 0.01 + lh * 0.5, -afasta)
		# Para onde a folha vai da dobradica, e para onde a espessura dela fica.
		var dir := v.lat * (sinal * cos(th)) + v.nor * sin(th)
		var perp := -v.nor * cos(th) + v.lat * (sinal * sin(th))
		var centro := dobradica + dir * (lw * 0.5) + perp * (FOLHA * 0.5 + 0.004)
		var base := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
		ob.livre(&"tabua", centro, Vector3(lw, lh, FOLHA), base, cor)
		if veneziana:
			_palhetas(ob, centro, dir, perp, lw, lh, cor)


## As palhetas da veneziana: placas inclinadas na face de fora da folha.
static func _palhetas(ob: Obra, centro: Vector3, dir: Vector3, perp: Vector3,
		lw: float, lh: float, cor: Color) -> void:
	var n := maxi(4, int(lh / 0.12))
	var passo := (lh - 0.16) / float(n)
	var fora := -perp
	var sombra := cor.darkened(0.25)
	for k in n:
		var y := -lh * 0.5 + 0.08 + passo * (float(k) + 0.5)
		var t := Transform3D(Basis(Vector3.UP.cross(fora), Vector3.UP, fora)
			* Basis(Vector3.RIGHT, -0.55), centro + Vector3(0.0, y, 0.0)
			+ fora * (FOLHA * 0.5 + 0.012))
		ob.cartao(_p(&"tabua"), Vector2(lw - 0.1, passo * 0.95), t, Rect2(0, 0, 1, 1), sombra)


## Janela de correr de aluminio: duas folhas de vidro, uma atras da outra. Aberta,
## a da esquerda correu para tras da outra e metade do vao da para o comodo.
static func _correr(ob: Obra, v: Vao, cor: Color, h_folha: float, d_vidro: float,
		aberta: bool, vidro_mat: StringName) -> void:
	_marco(ob, v, cor, d_vidro - 0.02, &"metal_pintado")
	var meia := v.w * 0.5
	if aberta:
		# A folha da direita fica; a da esquerda corre por tras dela.
		_vidro(ob, v, vidro_mat, meia * 0.5, h_folha * 0.5, meia + 0.02, h_folha,
			d_vidro)
		ob.caixa(&"metal_pintado", v.p(0.0, h_folha * 0.5, d_vidro - 0.01),
			Vector3(0.05, h_folha, 0.04), cor, v.giro)
	else:
		ob.caixa(&"metal_pintado", v.p(0.0, h_folha * 0.5, d_vidro - 0.02),
			Vector3(0.05, h_folha, 0.04), cor, v.giro)


## Vitro basculante de ferro: grade de quadros pequenos e, aberto, as abas do
## meio inclinadas para fora.
static func _basculante(ob: Obra, v: Vao, cor: Color, h_folha: float,
		d_vidro: float, aberto: bool) -> void:
	var ferro := cor.darkened(0.55)
	_marco(ob, v, ferro, d_vidro - 0.02, &"metal")
	var colunas := maxi(2, int(round(v.w / 0.45)))
	var linhas := maxi(3, int(round(h_folha / 0.32)))
	# Montante em placa: o vitro fica no fundo do vao e so se le de frente, e a
	# caixa custava doze triangulos por barra (a casa popular e cheia deles).
	for c in range(1, colunas):
		var u := -v.w * 0.5 + v.w * float(c) / colunas
		ob.placa(&"metal", v.p(u, h_folha * 0.5, d_vidro - 0.015), Vector2(0.03, h_folha),
			v.giro, ferro)
	for l in range(1, linhas):
		var y := h_folha * float(l) / linhas
		ob.placa(&"metal", v.p(0.0, y, d_vidro - 0.02), Vector2(v.w, 0.03), v.giro, ferro)
	if aberto:
		# As abas de uma linha do meio, basculadas 30 graus.
		var l := linhas / 2
		var alt := h_folha / linhas
		var y := alt * (float(l) + 0.5)
		var base := v.base() * Basis(Vector3.RIGHT, -0.5)
		ob.livre(&"janela_apagada",
			v.p(0.0, y, d_vidro - 0.08), Vector3(v.w - 0.06, alt - 0.03, 0.01), base, Color.WHITE)


# --- comodo ------------------------------------------------------------------

## O comodo atras da janela aberta: caixa virada para dentro, com a casca nos
## baldes normais (fecha o vao a qualquer distancia) e a mobilia no balde de
## perto.
static func _comodo(ob: Obra, v: Vao, e: Dictionary, rng: RandomNumberGenerator) -> void:
	# Nunca mais largo que o lote deixa (quem monta passa "larg_max"): o comodo
	# de uma janela perto da divisa sairia pela parede do lado.
	var larg := minf(clampf(v.w + 1.6, 2.4, 3.8), float(e.get("larg_max", 3.8)))
	# "fundo_max": o comodo de tras encontra o da frente no meio da casa, e os
	# dois nao podem se cruzar (FundosVivos.fundo, casa recuada).
	var fundo := minf(rng.randf_range(2.2, 3.2), float(e.get("fundo_max", 3.2)))
	# Chao do comodo: o peitoril de casa fica a ~1 m; nunca abaixo do pe da
	# parede, nem do piso do andar quando quem monta diz qual e ("piso_em", a
	# altura do piso na parede): com a loja de verdade embaixo (LojaViva) o
	# comodo do primeiro andar descia a 2,8 m e aparecia abaixo do forro dela.
	var piso_em := float(e.get("piso_em", 0.0))
	var y_chao := -minf(1.0, maxf(v.base_y - piso_em - 0.02, 0.0))
	var y_teto := v.h + 0.4
	var d0 := v.prof
	var d1 := v.prof + fundo
	var parede: Color = e["parede_interna"]
	var acesa: bool = e["acesa"]
	# Comodo aceso de verdade fica mais quente e mais claro; o apagado, meia luz.
	var tinta := parede.lerp(Color("ffe6bf"), 0.25) if acesa else parede.darkened(0.12)
	var alt := y_teto - y_chao
	var meio_y := (y_teto + y_chao) * 0.5
	var meio_d := (d0 + d1) * 0.5
	# Fundo e lados: planos virados para dentro.
	# Material de interior: emite um pouco na propria cor, porque a caixa so
	# recebe luz pelo vao (ver `interior` em tools/gerar_materiais.py).
	var parede_mat: StringName = &"interior_aceso" if acesa else &"interior"
	_plano(ob, parede_mat, v.p(0.0, meio_y, d1), Vector2(larg, alt), v.nor, v.lat, tinta)
	_plano(ob, parede_mat, v.p(-larg * 0.5, meio_y, meio_d), Vector2(fundo, alt), v.lat,
		-v.nor, tinta.darkened(0.06))
	_plano(ob, parede_mat, v.p(larg * 0.5, meio_y, meio_d), Vector2(fundo, alt), -v.lat,
		v.nor, tinta.darkened(0.06))
	var cozinha: bool = e["comodo"] == &"cozinha"
	_plano(ob, parede_mat if cozinha else &"interior_madeira", v.p(0.0, y_chao, meio_d),
		Vector2(larg, fundo), Vector3.UP, v.lat,
		Color("d9cfc0") if cozinha else Color("b89c78"))
	_plano(ob, parede_mat, v.p(0.0, y_teto, meio_d), Vector2(larg, fundo), Vector3.DOWN,
		v.lat, Color("f4f0e8"))

	# Mobilia, pelo comodo.
	var m := _p(&"interior_madeira")
	match e["comodo"]:
		&"sala":
			# Sofa contra a parede do fundo, estante com a TV num canto, quadro.
			var cor_sofa := [Color("7d4a3a"), Color("5d6b7a"), Color("8a7a52"),
				Color("6a5a7a")][rng.randi() % 4] as Color
			ob.caixa(_p(&"interior"), v.p(0.0, y_chao + 0.22, d1 - 0.45),
				Vector3(1.8, 0.44, 0.8), cor_sofa, v.giro)
			ob.caixa(_p(&"interior"), v.p(0.0, y_chao + 0.6, d1 - 0.12),
				Vector3(1.8, 0.5, 0.22), cor_sofa.darkened(0.1), v.giro)
			_quadro(ob, v, rng, Vector3(rng.randf_range(-0.5, 0.5), y_chao + 1.55, d1 - 0.01))
			var lado := -1.0 if rng.randf() < 0.5 else 1.0
			ob.caixa(m, v.p(lado * (larg * 0.5 - 0.3), y_chao + 0.7, d1 - 0.9),
				Vector3(0.5, 1.4, 1.0), Color("6b4a30"), v.giro)
			ob.caixa(_p(&"metal"),
				v.p(lado * (larg * 0.5 - 0.3), y_chao + 1.05, d1 - 0.9),
				Vector3(0.52, 0.34, 0.5), Color("303236"), v.giro)
		&"quarto":
			# Cama com colcha, guarda-roupa, e o santo na parede.
			var colcha := [Color("c8574a"), Color("e8d9a8"), Color("6a8ab0"),
				Color("d8a0b8"), Color("8ab070")][rng.randi() % 5] as Color
			ob.caixa(m, v.p(0.3, y_chao + 0.22, d1 - 1.0),
				Vector3(1.4, 0.44, 1.95), Color("7a5634"), v.giro)
			ob.caixa(_p(&"interior"), v.p(0.3, y_chao + 0.47, d1 - 1.05),
				Vector3(1.44, 0.08, 1.8), colcha, v.giro)
			ob.caixa(_p(&"interior"), v.p(0.3, y_chao + 0.55, d1 - 0.2),
				Vector3(1.2, 0.14, 0.3), Color("f2efe8"), v.giro)
			ob.caixa(m, v.p(-larg * 0.5 + 0.3, y_chao + 0.95, d1 - 0.7),
				Vector3(0.55, 1.9, 1.2), Color("5c3e26"), v.giro)
			_quadro(ob, v, rng, Vector3(0.3, y_chao + 1.6, d1 - 0.01))
		_:
			# Cozinha: azulejo ate meia parede, armario, geladeira, e o filtro de
			# barro em cima da bancada — o objeto mais mineiro da casa.
			_plano(ob, _p(&"interior"), v.p(0.0, y_chao + 0.8, d1 - 0.005),
				Vector2(larg, 1.6), v.nor, v.lat, Color("f0f0ea"))
			ob.caixa(m, v.p(0.2, y_chao + 0.45, d1 - 0.32),
				Vector3(1.6, 0.9, 0.6), Color("e8e2d2"), v.giro)
			ob.caixa(m, v.p(0.2, y_chao + 1.9, d1 - 0.2),
				Vector3(1.4, 0.6, 0.35), Color("d8cfb8"), v.giro)
			ob.caixa(_p(&"metal_pintado"),
				v.p(-larg * 0.5 + 0.4, y_chao + 0.85, d1 - 0.4),
				Vector3(0.65, 1.7, 0.65), Color("f4f4f0"), v.giro)
			ob.caixa(_p(&"interior"), v.p(0.55, y_chao + 1.07, d1 - 0.3),
				Vector3(0.26, 0.34, 0.26), TERRACOTA, v.giro)

	# Lampada no fio. Acesa, e a luz que se ve da rua.
	var lamp := v.p(rng.randf_range(-0.3, 0.3), y_teto - 0.45, meio_d)
	ob.caixa(_p(&"metal"), lamp + Vector3(0.0, 0.22, 0.0),
		Vector3(0.012, 0.42, 0.012), Color("202020"), v.giro)
	ob.caixa(_p(&"lampada" if acesa else &"metal_pintado"), lamp,
		Vector3(0.09, 0.11, 0.09), Color.WHITE if acesa else Color("e8e4dc"), v.giro)


## Plano virado para `normal`, com `eixo_u` ao longo da largura.
static func _plano(ob: Obra, mat: StringName, centro: Vector3, tamanho: Vector2,
		normal: Vector3, eixo_u: Vector3, cor: Color) -> void:
	ob.plano(mat, centro, tamanho, normal, eixo_u, cor)


## Quadro na parede do fundo: moldura escura e a pintura de uma cor so.
static func _quadro(ob: Obra, v: Vao, rng: RandomNumberGenerator, onde: Vector3) -> void:
	var tam := Vector2(rng.randf_range(0.4, 0.7), rng.randf_range(0.35, 0.55))
	var pintura := [Color("6a8a5a"), Color("c89a4a"), Color("5a6a9a"), Color("a84a3a"),
		Color("d8c8a8")][rng.randi() % 5] as Color
	ob.caixa(_p(&"interior_madeira"), v.p(onde.x, onde.y, onde.z - 0.01),
		Vector3(tam.x + 0.06, tam.y + 0.06, 0.02), Color("4a3422"), v.giro)
	ob.caixa(_p(&"interior"), v.p(onde.x, onde.y, onde.z - 0.025),
		Vector3(tam.x, tam.y, 0.01), pintura, v.giro)


## As duas bandas de cortina atras da janela aberta, presas em cima e soltas
## embaixo: o vento mexe a barra (material `cortina`).
static func _cortinas(ob: Obra, v: Vao, e: Dictionary, rng: RandomNumberGenerator,
		d: float) -> void:
	var cor: Color = e["cortina"]
	var alt := v.h + 0.3
	for lado: float in [-1.0, 1.0]:
		var larg := v.w * rng.randf_range(0.28, 0.42)
		var u := lado * (v.w * 0.5 - larg * 0.5 + 0.12)
		var centro := v.p(u, v.h + 0.2 - alt * 0.5, d)
		var y0 := centro.y - alt * 0.5
		ob.cartao(_p(&"cortina"), Vector2(larg, alt), Transform3D(v.base(), centro),
			Rect2(0.0, 0.0, larg * 0.8, alt * 0.8), cor, 2)


# --- flor, vaso, grade -------------------------------------------------------

## Floreira de alvenaria ou de madeira embaixo do peitoril, com terra e flor.
static func _floreira(ob: Obra, v: Vao, e: Dictionary, rng: RandomNumberGenerator) -> void:
	var larg := v.w + 0.1
	var fundo := 0.26
	var alt := 0.22
	var madeira := rng.randf() < 0.35
	var caixa_cor: Color = (e["esquadria"] as Color) if madeira \
		else [Color("e8e2d4"), TERRACOTA, Color("d8cdb8")][rng.randi() % 3] as Color
	var centro := v.p(0.0, -0.07 - alt * 0.5, -fundo * 0.5 - 0.02)
	ob.caixa(&"tabua" if madeira else &"concreto", centro,
		Vector3(larg, alt, fundo), caixa_cor, v.giro)
	ob.caixa(_p(&"terra"), centro + Vector3(0.0, alt * 0.5 + 0.005, 0.0),
		Vector3(larg - 0.06, 0.012, fundo - 0.06), Color("5a3e2a"), v.giro)
	var n := maxi(2, int(larg / 0.22))
	var celula: Vector2i = e["flor"]
	for k in n:
		var u := -larg * 0.5 + (float(k) + 0.5) * larg / n + rng.randf_range(-0.04, 0.04)
		var tam := rng.randf_range(0.28, 0.4)
		var pe := v.p(u, -0.07 + 0.01, -fundo * 0.5 - 0.02)
		# Uma em cada tres e so folha, para a floreira nao ser um tapete de cor.
		var c := celula if k % 3 != 2 else Vector2i(4, 0)
		_moita(ob, pe, c, tam, v.giro + rng.randf_range(-0.4, 0.4))


## Vasos de barro no peitoril, dentro do vao, na frente do vidro.
static func _vasos(ob: Obra, v: Vao, e: Dictionary, rng: RandomNumberGenerator,
		n: int, d_vidro: float) -> void:
	var d := minf(0.12, d_vidro * 0.5)
	for k in n:
		var u := -v.w * 0.5 + (float(k) + 0.5) * v.w / n + rng.randf_range(-0.05, 0.05)
		var alt := rng.randf_range(0.12, 0.2)
		ob.caixa(_p(&"reboco"), v.p(u, alt * 0.5, d),
			Vector3(0.15, alt, 0.15), TERRACOTA.darkened(rng.randf_range(0.0, 0.2)), v.giro)
		var celula: Vector2i = e["flor"] if rng.randf() < 0.6 else Vector2i(4, 0)
		_moita(ob, v.p(u, alt, d), celula, rng.randf_range(0.25, 0.4),
			v.giro + rng.randf() * PI)


## Samambaia pendurada na verga: o vaso preso por tres fios e a folhagem caindo.
static func _samambaia(ob: Obra, v: Vao, rng: RandomNumberGenerator) -> void:
	var u := (-1.0 if rng.randf() < 0.5 else 1.0) * (v.w * 0.5 + 0.35)
	var topo := v.p(u, v.h + 0.1, -0.25)
	# Mao-francesa: o braco de ferro que sai da parede e segura o gancho.
	ob.caixa(_p(&"metal"), v.p(u, v.h + 0.1, -0.13),
		Vector3(0.025, 0.025, 0.26), Color("303030"), v.giro)
	ob.caixa(_p(&"metal"), topo + Vector3(0.0, -0.2, 0.0),
		Vector3(0.01, 0.4, 0.01), Color("303030"), v.giro)
	var vaso := topo + Vector3(0.0, -0.5, 0.0)
	ob.caixa(_p(&"reboco"), vaso, Vector3(0.24, 0.16, 0.24),
		TERRACOTA, v.giro)
	for k in 3:
		var t := Transform3D(Basis(Vector3.UP, v.giro + PI / 3.0 * k)
			* Basis(Vector3.RIGHT, PI), vaso + Vector3(0.0, -0.2, 0.0))
		folhagem(ob, Vector2(0.5, 0.55), t, Color(0.75, 0.95, 0.7))


## Grade de ferro rente a fachada, dentro do vao. `losango` e o arabesco.
static func _grade(ob: Obra, v: Vao, h_folha: float, losango: bool,
		d: float) -> void:
	var ferro := Color("2c2e30")
	var n := maxi(3, int(v.w / 0.13))
	# Barra em placa, e nao em caixa: dois triangulos contra doze, e de frente o
	# que se le e o ritmo vertical (ver KitFachada._grade).
	for k in range(1, n):
		var u := -v.w * 0.5 + v.w * float(k) / n
		ob.placa(&"metal", v.p(u, h_folha * 0.5, d), Vector2(0.02, h_folha),
			v.giro, ferro)
	for y: float in [0.12, h_folha - 0.12]:
		ob.placa(&"metal", v.p(0.0, y, d - 0.004), Vector2(v.w, 0.035),
			v.giro, ferro)
	if losango:
		# Uma fiada de losangos no meio, em placa: o desenho e o que conta.
		var m := maxi(2, int(v.w / 0.35))
		var passo := v.w / m
		for k in m:
			var u := -v.w * 0.5 + passo * (float(k) + 0.5)
			for inclina: float in [PI * 0.25, -PI * 0.25]:
				var t := Transform3D(v.base() * Basis(Vector3.FORWARD, inclina),
					v.p(u, h_folha * 0.5, d - 0.012))
				ob.cartao(&"metal", Vector2(passo * 0.72, 0.016), t, Rect2(0, 0, 1, 1), ferro)


## Placa de folhagem balancando, com a textura INTEIRA (folhagem_recorte nao e
## atlas: a celula de AtlasKit pegava 1/8 dela e saia uma folha solta).
static func folhagem(ob: Obra, tamanho: Vector2, xform: Transform3D,
		cor: Color = Color(0.7, 0.9, 0.6)) -> void:
	ob.cartao(_p(&"folhagem_recorte"), tamanho, xform, Rect2(0, 0, 1, 1), cor, 1)


## Dois planos cruzados de uma celula do atlas de flores, balancando.
static func _moita(ob: Obra, base: Vector3, celula: Vector2i, tam: float,
		giro: float) -> void:
	for k in 2:
		var t := Transform3D(Basis(Vector3.UP, giro + PI * 0.5 * float(k)),
			base + Vector3(0.0, tam * 0.5, 0.0))
		ob.cartao(_p(&"flor"), Vector2(tam, tam), t, Carroceria.uv(celula), Color.WHITE, 1)
