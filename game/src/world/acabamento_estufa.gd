## O acabamento da estufa: piso, paredes, teto e a pintura de cada andar.
##
## Ate aqui o chao e a parede eram duas celulas de 32 px do atlas da casa, uma
## por metro: o piso lia como camuflagem e a manta das paredes como chiado de TV.
## Nenhuma das duas dizia "isto foi construido". Uma sala de cultivo montada tem
## acabamento de galpao, e e esse acabamento que este arquivo desenha:
##
##   piso     epoxi claro com flocos. O CANTEIRO e pintado de verde-cinza por
##            cima (a mesma textura, outra tinta de vertice), com a faixa
##            amarela de demarcacao em volta — o corredor e onde se anda, o
##            verde e onde se planta, e da para ler isso sem planta nenhuma.
##   parede   bloco de concreto pintado: barra verde-escura ate um metro, a
##            faixa na cor da VARIEDADE do andar e branco ate o teto. Rodape
##            sanitario em meia-cana no pe, como em cozinha industrial.
##   teto     laje moldada em compensado, com a marca da forma.
##   pintura  stencil de spray: o numero do andar, a folha e o nome da
##            variedade na parede sul — o que se ve do outro lado do poco ao
##            sair do elevador —, o numero no piso da passarela, e os avisos.
##
## O 9 e o andar apagado. Nele a tinta e fosforescente (MAT_PINTURA_BRILHO): a
## faixa da parede, a demarcacao dos canteiros e o numero acendem em ciano no
## escuro, que e a unica luz do andar alem da propria Vagalume.
##
## UV em METROS de mundo, e nao por peca: o piso e partido em retangulos (o
## canteiro, a faixa, o corredor), e com UV por peca cada emenda mostraria o
## floco cortado. Projetando pelo mundo, o epoxi atravessa a faixa amarela sem
## costura. As texturas saem de tools/gerar_estufa_acabamento.py.
class_name AcabamentoEstufa
extends RefCounted

const MAT_PISO: StringName = &"estufa_piso"
const MAT_PAREDE: StringName = &"estufa_parede"
const MAT_TETO: StringName = &"estufa_teto"
const MAT_PINTURA: StringName = &"estufa_pintura"
const MAT_PINTURA_BRILHO: StringName = &"estufa_pintura_brilho"

## Uma repeticao de textura a cada dois metros (as quatro texturas tem 2 m).
const UV_POR_M := 0.5
## Lado maximo de um quad. O afim do PS1 entorta a textura de quad grande
## visto de perto, e o piso e o que mais se ve de perto.
const QUAD_PISO := 1.0
const QUAD_PAREDE := 1.1

## A barra escura, a faixa da variedade e o rodape.
const BARRA := 1.05
const FAIXA := 0.08
const RODAPE := 0.1
## Demarcacao do piso.
const LINHA := 0.05

const COR_CORREDOR := Color(1.0, 1.0, 1.0)
const COR_CANTEIRO := Color(0.60, 0.70, 0.58)
const COR_TRABALHO := Color(0.98, 0.95, 0.88)
const COR_BARRA := Color(0.19, 0.31, 0.25)
const COR_RODAPE := Color(0.15, 0.24, 0.2)
const COR_PAREDE := Color(0.98, 0.98, 0.95)
const COR_TETO := Color(0.95, 0.95, 0.93)
const AMARELO := Color(0.96, 0.73, 0.12)
## A tinta do escuro. A emissao do material e que acende; a cor so tinge o
## pouco de luz que ainda chega.
const FOSFORO := Color(0.55, 1.0, 0.92)

# Mapa do atlas de stencil, em unidades de 1024 (tools/gerar_estufa_acabamento.py).
const _DIGITOS := {
	1: Rect2(0, 0, 128, 256), 2: Rect2(128, 0, 128, 256),
	3: Rect2(256, 0, 128, 256), 4: Rect2(384, 0, 128, 256),
	5: Rect2(512, 0, 128, 256), 6: Rect2(640, 0, 128, 256),
	7: Rect2(768, 0, 128, 256), 8: Rect2(896, 0, 128, 256),
	9: Rect2(0, 256, 128, 256), 10: Rect2(128, 256, 256, 256),
}
const _FOLHA := Rect2(384, 256, 256, 256)
const _SETA := Rect2(640, 256, 256, 128)
const _ALERTA := Rect2(896, 256, 128, 128)
## O nome de cada andar e o indice (andar - 1); de 9 em diante, os avisos.
const NOME_PROIBIDO_FUMAR := 10
const NOME_AREA_DE_CULTIVO := 11
const NOME_MANTENHA_LIVRE := 12
const NOME_LAVE_AS_MAOS := 13
const NOME_SO_FUNCIONARIOS := 14
const NOME_NAO_PISE := 15
## Um ponto de tinta cheia, sem borda de spray: a faixa e a demarcacao usam o
## material do stencil com a UV parada aqui, na celula cheia do atlas.
const _CHEIO := Vector2(1008.0 / 1024.0, 448.0 / 1024.0)


static func _rect(r: Rect2) -> Rect2:
	return Rect2(r.position / 1024.0, r.size / 1024.0)


static func rect_nome(k: int) -> Rect2:
	return Rect2(float(k % 2) * 0.5, (512.0 + floorf(float(k) / 2.0) * 64.0) / 1024.0,
		0.5, 64.0 / 1024.0)


## Tudo. `faixas` e a planta de uma laje menos o poco (EstufaBuilder._faixas).
static func construir(sup: Dictionary, faixas: Array) -> void:
	for andar in range(1, EstufaBuilder.ANDARES):
		var y := EstufaBuilder.nivel(andar)
		_piso(sup, faixas, andar, y)
		_teto(sup, faixas, andar, y + EstufaBuilder.pe_direito(andar))
		_paredes(sup, andar, y)
		_pintura(sup, andar, y)
	# O vao de baixo da galeria 9, ate a laje do fundo: so parede lisa, que e o
	# que se ve do poco la no fim.
	var y9 := EstufaBuilder.nivel(9)
	for p: Dictionary in _PAREDES:
		_parede_trecho(sup, MAT_PAREDE, p, 0.0, float(p["comp"]),
			EstufaBuilder.FUNDO_POCO, y9, COR_PAREDE.darkened(0.25))
	# E o forro dele, que e a face de baixo da laje do 9.
	_teto(sup, faixas, 9, y9 - 0.14)


# --- piso -----------------------------------------------------------------------

## Os canteiros de um andar, como retangulos no plano (x, z).
static func canteiros(andar: int) -> Array[Rect2]:
	if andar == 1:
		return [Rect2(0.55, 3.75, 2.7, 11.3), Rect2(8.75, 3.75, 2.7, 11.3)]
	var z0 := EstufaBuilder.GALERIA_LINHAS[0] - 0.65
	var z1 := EstufaBuilder.GALERIA_LINHAS[-1] + 0.65
	var larg := 2.85
	return [
		Rect2(0.0, z0, larg, z1 - z0),
		Rect2(EstufaBuilder.LARGURA - larg, z0, larg, z1 - z0),
		Rect2(0.9, EstufaBuilder.GALERIA_SUL_Z - 0.65, EstufaBuilder.LARGURA - 1.8, 1.3),
	]


static func _piso(sup: Dictionary, faixas: Array, andar: int, y: float) -> void:
	var bases: Array[Rect2] = []
	for f: Array in faixas:
		bases.append(Rect2(f[0], f[2], f[1] - f[0], f[3] - f[2]))
	if andar > 1:
		# A passarela da ponta norte do poco.
		bases.append(Rect2(EstufaBuilder.POCO_X.x, EstufaBuilder.PONTE_Z,
			EstufaBuilder.POCO_X.y - EstufaBuilder.POCO_X.x,
			EstufaBuilder.POCO_Z.y - EstufaBuilder.PONTE_Z))

	var brilha := andar == 9
	var tinta := FOSFORO if brilha else AMARELO
	var mat_tinta := MAT_PINTURA_BRILHO if brilha else MAT_PINTURA
	# Em ordem de prioridade: a linha por cima de tudo, o canteiro, a area de
	# trabalho. O que sobra e corredor.
	var zonas: Array = []
	for c: Rect2 in canteiros(andar):
		for l: Rect2 in _contorno(c, LINHA):
			zonas.append([l, tinta, mat_tinta])
	for c: Rect2 in canteiros(andar):
		zonas.append([c, COR_CANTEIRO, MAT_PISO])
	if andar > 1:
		# O quadro de espera na frente da cancela, que e onde se espera a cabine.
		var espera := Rect2(EstufaBuilder.VAO_X.x, EstufaBuilder.PONTE_Z + 0.12,
			EstufaBuilder.VAO_X.y - EstufaBuilder.VAO_X.x,
			EstufaBuilder.POCO_Z.y - EstufaBuilder.PONTE_Z - 0.12)
		for l: Rect2 in _contorno(espera.grow(-LINHA), LINHA):
			zonas.append([l, tinta, mat_tinta])
		zonas.append([Rect2(0.0, EstufaBuilder.POCO_Z.y, EstufaBuilder.LARGURA,
			EstufaBuilder.FUNDO - EstufaBuilder.POCO_Z.y), COR_TRABALHO, MAT_PISO])
	else:
		zonas.append([Rect2(0.0, 0.0, EstufaBuilder.LARGURA, EstufaBuilder.POCO_Z.x),
			COR_TRABALHO, MAT_PISO])

	for peca: Array in _repartir(bases, zonas, COR_CORREDOR, MAT_PISO):
		var r: Rect2 = peca[0]
		var mat: StringName = peca[2]
		var sobe := 0.0 if mat == MAT_PISO else 0.002
		_plano(sup, mat, Vector3(r.get_center().x, y + sobe, r.get_center().y),
			Vector3.RIGHT, Vector3.UP, r.size, peca[1], QUAD_PISO,
			Vector3.RIGHT, Vector3.BACK, mat != MAT_PISO)
	_ralos(sup, andar, y)


## As quatro linhas em volta de um retangulo, POR FORA dele.
static func _contorno(r: Rect2, larg: float) -> Array[Rect2]:
	return [
		Rect2(r.position.x - larg, r.position.y - larg, r.size.x + larg * 2.0, larg),
		Rect2(r.position.x - larg, r.end.y, r.size.x + larg * 2.0, larg),
		Rect2(r.position.x - larg, r.position.y, larg, r.size.y),
		Rect2(r.end.x, r.position.y, larg, r.size.y),
	]


## Reparte as `bases` pelas `zonas` ([Rect2, cor, material], a primeira ganha):
## cada pedaco de piso sai de um retangulo so, sem sobrepor — piso sobre piso no
## mesmo plano briga no depth e pisca.
static func _repartir(bases: Array[Rect2], zonas: Array, cor_resto: Color,
		mat_resto: StringName) -> Array:
	var saida: Array = []
	var resto: Array[Rect2] = bases.duplicate()
	for z: Array in zonas:
		var zr: Rect2 = z[0]
		var novo: Array[Rect2] = []
		for r: Rect2 in resto:
			var i := r.intersection(zr)
			if i.size.x > 0.002 and i.size.y > 0.002:
				saida.append([i, z[1], z[2]])
			novo.append_array(_menos(r, zr))
		resto = novo
	for r: Rect2 in resto:
		saida.append([r, cor_resto, mat_resto])
	return saida


static func _menos(r: Rect2, b: Rect2) -> Array[Rect2]:
	var i := r.intersection(b)
	if i.size.x <= 0.002 or i.size.y <= 0.002:
		return [r]
	var saida: Array[Rect2] = []
	if i.position.y - r.position.y > 0.002:
		saida.append(Rect2(r.position.x, r.position.y, r.size.x, i.position.y - r.position.y))
	if r.end.y - i.end.y > 0.002:
		saida.append(Rect2(r.position.x, i.end.y, r.size.x, r.end.y - i.end.y))
	if i.position.x - r.position.x > 0.002:
		saida.append(Rect2(r.position.x, i.position.y, i.position.x - r.position.x, i.size.y))
	if r.end.x - i.end.x > 0.002:
		saida.append(Rect2(i.end.x, i.position.y, r.end.x - i.end.x, i.size.y))
	return saida


## Os ralos do corredor: grelha de inox com quatro fendas. E para onde a agua da
## rega escorre, e piso de estufa sem ralo e piso de sala.
static func _ralos(sup: Dictionary, andar: int, y: float) -> void:
	# Na galeria o tapete de borracha cobre o corredor inteiro; o ralo fica na
	# cabeceira sul dele, antes do tapete.
	var zs: Array[float] = [2.2]
	if andar == 1:
		zs = [9.4]
	var xs: Array[float] = [EstufaBuilder.CORREDOR_GALERIA.x, EstufaBuilder.CORREDOR_GALERIA.y]
	if andar == 1:
		xs = [3.55, 8.45]
	for x: float in xs:
		for z: float in zs:
			var c := Vector3(x, y + 0.004, z)
			AtlasKit.caixa(sup, EstufaBuilder.MAT, c, Vector3(0.3, 0.008, 0.3),
				EstufaBuilder.C_MANGUEIRA, Color(0.62, 0.64, 0.66))
			for k in 4:
				AtlasKit.caixa(sup, EstufaBuilder.MAT,
					c + Vector3(-0.09 + 0.06 * float(k), 0.003, 0.0),
					Vector3(0.025, 0.006, 0.22), EstufaBuilder.C_MANGUEIRA,
					Color(0.08, 0.08, 0.08))


# --- teto -----------------------------------------------------------------------

static func _teto(sup: Dictionary, faixas: Array, andar: int, forro: float) -> void:
	var pecas: Array = faixas.duplicate()
	if andar > 1:
		pecas.append([EstufaBuilder.POCO_X.x, EstufaBuilder.POCO_X.y,
			EstufaBuilder.PONTE_Z, EstufaBuilder.POCO_Z.y])
	else:
		# A lavoura tem o forro inteiro: em cima dela nao ha poco, ha a casa.
		pecas = EstufaBuilder._menos_o_vao(0.0)
	for f: Array in pecas:
		var tam := Vector2(f[1] - f[0], f[3] - f[2])
		_plano(sup, MAT_TETO, Vector3((f[0] + f[1]) * 0.5, forro, (f[2] + f[3]) * 0.5),
			Vector3.RIGHT, Vector3.DOWN, tam, COR_TETO, 2.0, Vector3.RIGHT, Vector3.BACK)


# --- paredes --------------------------------------------------------------------

## As quatro paredes. `base` e o ponto de s = 0 no piso, `eixo` o sentido de s,
## `n` para onde a face olha.
const _PAREDES: Array[Dictionary] = [
	{"n": Vector3(0, 0, 1), "eixo": Vector3(1, 0, 0), "base": Vector3(0, 0, 0), "comp": 12.0},
	{"n": Vector3(0, 0, -1), "eixo": Vector3(1, 0, 0), "base": Vector3(0, 0, 18), "comp": 12.0},
	{"n": Vector3(1, 0, 0), "eixo": Vector3(0, 0, 1), "base": Vector3(0, 0, 0), "comp": 18.0},
	{"n": Vector3(-1, 0, 0), "eixo": Vector3(0, 0, 1), "base": Vector3(12, 0, 0), "comp": 18.0},
]


static func _paredes(sup: Dictionary, andar: int, y: float) -> void:
	var v := Variedades.do_andar(andar)
	var brilha := andar == 9
	var cor_faixa := Variedades.cor(v)
	var topo := y + EstufaBuilder.PE
	for p: Dictionary in _PAREDES:
		var comp: float = p["comp"]
		# A boca da escada, na parede sul da lavoura: o trecho dela e partido.
		var trechos: Array = [[0.0, comp]]
		var porta := andar == 1 and (p["n"] as Vector3).z > 0.5
		if porta:
			trechos = [[0.0, EstufaBuilder.BOCA.x], [EstufaBuilder.BOCA.y, comp]]
		for t: Array in trechos:
			_parede_trecho(sup, MAT_PAREDE, p, t[0], t[1], y, y + BARRA, COR_BARRA)
			if brilha:
				_parede_trecho(sup, MAT_PINTURA_BRILHO, p, t[0], t[1], y + BARRA,
					y + BARRA + FAIXA, FOSFORO, true)
			else:
				_parede_trecho(sup, MAT_PAREDE, p, t[0], t[1], y + BARRA,
					y + BARRA + FAIXA, cor_faixa)
			var alto := y + EstufaBuilder.ALTURA_PORTA if porta else topo
			_parede_trecho(sup, MAT_PAREDE, p, t[0], t[1], y + BARRA + FAIXA, alto,
				COR_PAREDE)
			_rodape(sup, p, t[0], t[1], y)
		if porta:
			# Verga: de parede a parede acima da boca.
			_parede_trecho(sup, MAT_PAREDE, p, 0.0, comp,
				y + EstufaBuilder.ALTURA_PORTA, topo, COR_PAREDE)


## Um retangulo de parede, de s0 a s1 ao longo dela e de y0 a y1.
static func _parede_trecho(sup: Dictionary, mat: StringName, p: Dictionary,
		s0: float, s1: float, y0: float, y1: float, cor: Color, cheio := false) -> void:
	if s1 - s0 < 0.005 or y1 - y0 < 0.005:
		return
	var n: Vector3 = p["n"]
	var eixo: Vector3 = p["eixo"]
	var meio: Vector3 = p["base"] + eixo * ((s0 + s1) * 0.5)
	meio.y = (y0 + y1) * 0.5
	var x := Vector3.UP.cross(n)
	# A tinta cheia sai 3 mm da parede: e outro material no mesmo plano.
	if cheio:
		meio += n * 0.003
	_plano(sup, mat, meio, x, n, Vector2(s1 - s0, y1 - y0), cor, QUAD_PAREDE,
		x, Vector3.DOWN, cheio)


## Rodape sanitario: a meia-cana de epoxi no pe da parede, a 45 graus.
static func _rodape(sup: Dictionary, p: Dictionary, s0: float, s1: float, y: float) -> void:
	var n: Vector3 = p["n"]
	var eixo: Vector3 = p["eixo"]
	var meio: Vector3 = p["base"] + eixo * ((s0 + s1) * 0.5) + n * (RODAPE * 0.5)
	meio.y = y + RODAPE * 0.5
	var x := Vector3.UP.cross(n)
	var z := (n + Vector3.UP).normalized()
	_plano(sup, MAT_PISO, meio, x, z, Vector2(s1 - s0, RODAPE * sqrt(2.0)), COR_RODAPE,
		QUAD_PAREDE, x, Vector3.DOWN)


# --- pintura --------------------------------------------------------------------

## O stencil de cada andar.
##
## Na galeria, a parede sul no eixo do poco: e o que esta na frente de quem sai
## do elevador, doze metros adiante, do outro lado do vazio. Um painel pintado na
## cor da variedade, e em cima dele, em branco, o numero, a folha e o nome — o
## grafismo de andar de garagem, que se le de longe e atraves da nevoa. Na
## lavoura, a parede norte, que e o que se ve descendo a escada, dos dois lados
## do vao do elevador.
##
## Branco direto na parede branca sumia (a primeira captura: "LAVE AS MAOS" era
## so uma sombra). Letra sobre parede vai escura; letra clara so sobre painel.
static func _pintura(sup: Dictionary, andar: int, y: float) -> void:
	var v := Variedades.do_andar(andar)
	var brilha := andar == 9
	var mat := MAT_PINTURA_BRILHO if brilha else MAT_PINTURA
	var painel := Variedades.cor(v).darkened(0.3)
	var branco := FOSFORO if brilha else Color(0.96, 0.96, 0.93)
	var escuro := FOSFORO if brilha else Color(0.1, 0.17, 0.14)
	var vermelho := FOSFORO if brilha else Color(0.78, 0.14, 0.1)
	var h := y + 1.85
	if andar == 1:
		var norte := Vector3(0.0, 0.0, EstufaBuilder.FUNDO)
		var x_n := Vector3.LEFT
		var z_n := Vector3.FORWARD
		_painel(sup, norte + Vector3(8.65, h, 0.0), x_n, z_n, Vector2(2.1, 1.2), painel)
		_decalque(sup, mat, norte + Vector3(9.2, h, -0.012), x_n, z_n, Vector2(0.5, 1.0),
			_DIGITOS[1], branco)
		_decalque(sup, mat, norte + Vector3(8.3, h, -0.012), x_n, z_n, Vector2(0.85, 0.85),
			_FOLHA, branco)
		_painel(sup, norte + Vector3(3.5, h, 0.0), x_n, z_n, Vector2(2.7, 0.8), painel)
		_decalque(sup, mat, norte + Vector3(3.5, h + 0.12, -0.012), x_n, z_n,
			Vector2(2.3, 0.2875), rect_nome(0), branco, false)
		_decalque(sup, mat, norte + Vector3(3.5, h - 0.2, -0.012), x_n, z_n,
			Vector2(1.6, 0.2), rect_nome(NOME_AREA_DE_CULTIVO), branco, false)
		# A parede da escada, virada para dentro: quem volta ve o aviso.
		var sul := Vector3(0.0, 0.0, 0.012)
		_decalque(sup, mat, sul + Vector3(9.3, y + 1.7, 0.0), Vector3.RIGHT, Vector3.BACK,
			Vector2(2.0, 0.25), rect_nome(NOME_PROIBIDO_FUMAR), vermelho, false)
		_decalque(sup, mat, sul + Vector3(9.3, y + 2.13, 0.0), Vector3.RIGHT, Vector3.BACK,
			Vector2(0.44, 0.44), _ALERTA, vermelho)
		return

	# A parede sul, do outro lado do poco. No 9 nao ha painel: a tinta que
	# acende e o painel.
	var s := Vector3(0.0, h, 0.0)
	if not brilha:
		_painel(sup, s + Vector3(6.1, 0.0, 0.0), Vector3.RIGHT, Vector3.BACK,
			Vector2(4.4, 1.2), painel)
	_decalque(sup, mat, s + Vector3(4.35, 0.0, 0.012), Vector3.RIGHT, Vector3.BACK,
		Vector2(0.5, 1.0), _DIGITOS[andar], branco)
	_decalque(sup, mat, s + Vector3(5.25, 0.0, 0.012), Vector3.RIGHT, Vector3.BACK,
		Vector2(0.85, 0.85), _FOLHA, branco)
	_decalque(sup, mat, s + Vector3(7.05, 0.12, 0.012), Vector3.RIGHT, Vector3.BACK,
		Vector2(2.3, 0.2875), rect_nome(andar - 1), branco, false)
	_decalque(sup, mat, s + Vector3(7.05, -0.2, 0.012), Vector3.RIGHT, Vector3.BACK,
		Vector2(1.7, 0.2125), rect_nome(NOME_NAO_PISE), branco, false)

	# O numero no piso da passarela, lido por quem sai da cabine: a cabeca dele
	# aponta para o sul, para onde se anda.
	var chao := Vector3(EstufaBuilder.ELEVADOR.x, y + 0.004,
		(EstufaBuilder.PONTE_Z + EstufaBuilder.POCO_Z.y) * 0.5 + 0.06)
	_decalque(sup, mat, chao, Vector3.RIGHT, Vector3.UP, Vector2(0.4, 0.8),
		_DIGITOS[andar], FOSFORO if brilha else AMARELO)

	# Os avisos da parede norte, em cima da estacao e do caixote.
	var norte := Vector3(0.0, y, EstufaBuilder.FUNDO - 0.012)
	_decalque(sup, mat, norte + Vector3(1.75, 1.75, 0.0), Vector3.LEFT, Vector3.FORWARD,
		Vector2(1.6, 0.2), rect_nome(NOME_LAVE_AS_MAOS), escuro, false)
	_decalque(sup, mat, norte + Vector3(10.1, 1.62, 0.0), Vector3.LEFT, Vector3.FORWARD,
		Vector2(1.8, 0.225), rect_nome(NOME_PROIBIDO_FUMAR), vermelho, false)
	_decalque(sup, mat, norte + Vector3(10.1, 2.05, 0.0), Vector3.LEFT, Vector3.FORWARD,
		Vector2(0.4, 0.4), _ALERTA, vermelho)
	_decalque(sup, mat, norte + Vector3(8.1, 2.3, 0.0), Vector3.LEFT, Vector3.FORWARD,
		Vector2(0.8, 0.4), _SETA, escuro)


## Um painel de tinta cheia na parede, 6 mm para fora dela (o stencil vai a 12).
static func _painel(sup: Dictionary, centro: Vector3, x: Vector3, z: Vector3,
		tam: Vector2, cor: Color) -> void:
	_plano(sup, MAT_PINTURA, centro + z * 0.006, x, z, tam, cor, QUAD_PAREDE, x,
		Vector3.DOWN, true)


## Uma placa com um retangulo do atlas de stencil, tingida. `x` e o "para a
## direita" de quem le, `z` para onde a face olha. `atlas` diz se o retangulo esta
## em unidades de 1024 (digito, folha) ou ja normalizado (nome).
static func _decalque(sup: Dictionary, mat: StringName, centro: Vector3, x: Vector3,
		z: Vector3, tam: Vector2, r: Rect2, cor: Color, atlas := true) -> void:
	var rr := _rect(r) if atlas else r
	var d := PSXMesh.placa_dados(tam, 100.0, Color.WHITE)
	var uvs: PackedVector2Array = d["uv"]
	var m := 0.5 / 1024.0
	var dentro := Rect2(rr.position + Vector2(m, m), rr.size - Vector2(m, m) * 2.0)
	for k in uvs.size():
		uvs[k] = dentro.position + uvs[k] * dentro.size
	d["uv"] = uvs
	if not sup.has(mat):
		sup[mat] = PSXMesh.dados_vazios()
	PSXMesh.acumular_tingido(sup[mat], d, Transform3D(Basis(x, z.cross(x), z), centro), cor)


# --- malha ----------------------------------------------------------------------

## Um retangulo subdividido, com a UV projetada do MUNDO: `eu` e `ev` sao os
## eixos de mundo de U e V. `x` e o lado largo do retangulo, `z` a normal.
## `cheio` para a UV no miolo de tinta do atlas de stencil.
static func _plano(sup: Dictionary, mat: StringName, centro: Vector3, x: Vector3,
		z: Vector3, tam: Vector2, cor: Color, quad: float, eu: Vector3, ev: Vector3,
		cheio := false) -> void:
	if not sup.has(mat):
		sup[mat] = PSXMesh.dados_vazios()
	var alvo: Dictionary = sup[mat]
	var inicio := (alvo["v"] as PackedVector3Array).size()
	PSXMesh.acumular_tingido(alvo, PSXMesh.plane_dados(tam, UV_POR_M, quad),
		Transform3D(Basis(x, z.cross(x), z), centro), cor)
	var vs: PackedVector3Array = alvo["v"]
	var uvs: PackedVector2Array = alvo["uv"]
	for k in range(inicio, vs.size()):
		uvs[k] = _CHEIO if cheio else Vector2(vs[k].dot(eu), vs[k].dot(ev)) * UV_POR_M
	alvo["uv"] = uvs
