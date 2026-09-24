## O corpo por baixo da roupa: tronco, membros, pescoco e maos com forma.
##
## Por que tubo, e nao caixa
## -------------------------
## A primeira pessoa deste jogo era onze caixas. Magro e gordo mudavam so a
## largura da caixa do tronco, mais uma caixa de barriga grudada na frente: o
## gordo lia como armario com uma gaveta aberta, e o braco — pendurado no mesmo
## ombro do magro — descia por DENTRO da barriga. Na foto de tres quartos da
## bancada (`bancada_criacao.gd --so=corpos`) o antebraco saia do meio do peito.
##
## Aqui cada parte e um tubo de secao arredondada (superelipse) que passa por
## aneis de medida: gancho, quadril, cinto, barriga, peito, ombro e base do
## pescoco no tronco; deltoide, biceps, cotovelo, antebraco e punho no braco;
## coxa, joelho, panturrilha e tornozelo na perna. O porte mexe em cada anel de
## um jeito — a barriga cresce para a frente e para os lados, o peito pouco, o
## punho quase nada —, e e isso, e nao um fator unico, que faz o gordo ler como
## gordo e o magro como magro.
##
## Junta sem fresta
## ----------------
## O anel do cotovelo, do joelho e da cintura pertence meio a cada osso. Nas
## caixas rigidas o cotovelo abria uma fenda a cada dobra; aqui a dobra estica
## a pele por cima, e continua uma malha e uma chamada de desenho por pessoa.
##
## Dois niveis
## -----------
## Quem aparece de perto (o jogador, o retrato da criacao, a foto da conversa)
## ganha secao de doze lados no tronco, oito nos membros e cinco dedos. O
## pedestre, que passa a quinze metros de nevoa, fica com oito e seis lados e a
## mao em luva com polegar: a mesma silhueta por pouco mais da metade do custo.
class_name Anatomia
extends RefCounted

const LADOS_TRONCO_PERTO := 12
const LADOS_TRONCO_RUA := 8
const LADOS_MEMBRO_PERTO := 8
const LADOS_MEMBRO_RUA := 6
## Expoente da superelipse da secao: 2 e elipse; acima disso, caixa de canto
## redondo. O tronco e mais quadrado que o braco, como e o de gente.
const FORMA_TRONCO := 2.6
const FORMA_MEMBRO := 2.2
## Margem dentro da celula do atlas. No MODERNO o filtro e linear, e a borda
## exata de uma celula puxa um fio da vizinha.
const MARGEM_UV := 0.03

## Altura da barra da manga curta, e quanto a manga fica por cima da pele.
const Y_MANGA_CURTA := 1.20
const FOLGA_MANGA := 0.007
const FOLGA_CALCA := 0.008
## Onde a camisa encontra a calca, no corpo de referencia.
const Y_CINTO := 1.035


## Um anel da secao, em espaco do modelo.
class Anel:
	var c: Vector3
	var w: float
	var f: float
	var b: float
	var osso: int
	var osso2: int
	var peso2: float
	var v: float
	## Dobra do pano: o raio ondula `ondas` (fracao) com `n_ondas` cristas por
	## volta. E o que faz o tubo ler como tecido e nao como cano: a barra da
	## camisa drapeia, a calca amontoa no sapato, a saia tem prega.
	var ondas: float = 0.0
	var n_ondas: int = 0
	var fase: float = 0.0
	## Escurecimento proprio do anel (axila, dobra funda), somado a sombra que a
	## normal ja da.
	var sombra: float = 0.0
	## Saia e aba de casaco: quanto deste anel vai para os ossos de pano da
	## frente e de tras (ver `Corpo._fisica`).
	var pano: float = 0.0
	## Barriga: quanto a frente deste anel acompanha o osso que balanca.
	var barriga: float = 0.0

	func _init(centro: Vector3, meia_largura: float, frente: float, costas: float,
			o: int, v_cel: float, o2: int = -1, p2: float = 0.0) -> void:
		c = centro
		w = meia_largura
		f = frente
		b = costas
		osso = o
		v = v_cel
		osso2 = o2
		peso2 = p2

	func dobra(amplitude: float, cristas: int, desvio: float = 0.0) -> Anel:
		ondas = amplitude
		n_ondas = cristas
		fase = desvio
		return self


## Como pintar o trecho entre dois aneis. Com `costas`, a metade da frente usa
## `cel` e a de tras usa `costas` (o tronco: estampa na frente, liso atras); sem
## ela, a celula da a volta espelhada, que emenda sem costura.
static func faixa(cor: Color, cel: Rect2, costas: Variant = null) -> Dictionary:
	return {"cor": cor, "cel": cel, "costas": costas}


## A parte lisa da celula da calca, abaixo do cinto e das linhas de bolso.
##
## A celula foi desenhada para a caixa da pelve: cinto em cima, bolsos no meio.
## Repetida pela perna inteira ela punha um cinto no tornozelo e listras de bolso
## na coxa, e a calca lia como atadura. Na perna e na saia fica so o tecido, com
## o vinco do meio caindo na frente da canela.
static func tecido(cel: Rect2) -> Rect2:
	# Linhas 21 a 26 da celula: as calcas listradas (2 e 5) tem risco nas
	# linhas 6, 13, 20 e 27, e um risco dentro do recorte virava uma faixa por
	# meia perna.
	return Rect2(cel.position + cel.size * Vector2(0.0, 0.67), cel.size * Vector2(1.0, 0.15))


## Quanto a frente da barriga acompanha o osso que balanca, na altura `y`.
## Zero ate o meio do porte: barriga de magro nao sacode.
static func fator_barriga(a: Dictionary, y: float) -> float:
	var k := smoothstep(0.35, 1.0, gordura(a)) * 0.9
	return k * clampf(1.0 - absf(y - 1.11) / 0.15, 0.0, 1.0)


## O osso de uma peca rigida pregada na frente do tronco (botao, fivela): o da
## barriga, se ela ali balanca mais do que fica, senao o do tronco.
static func osso_na_frente(corpo: Corpo, y: float) -> int:
	if fator_barriga(corpo._aparencia, y) > 0.45:
		return Corpo.Osso.BARRIGA
	return Corpo.Osso.TORSO if y >= Y_CINTO - 0.02 else Corpo.Osso.QUADRIL


## O meio claro de uma celula de pele. A celula de nuca escurece embaixo (a
## sombra do queixo), e esticada num braco inteiro ela virava uma faixa marrom
## atravessando o antebraco.
static func miolo(cel: Rect2) -> Rect2:
	return Rect2(cel.position + cel.size * Vector2(0.2, 0.22), cel.size * Vector2(0.6, 0.34))


# --- medidas ------------------------------------------------------------------

static func gordura(a: Dictionary) -> float:
	return clampf(float(a.get("gordura", 0.5)), 0.0, 1.0)


## A aparencia nao guarda o sexo; o rosto e o perfil guardam.
static func feminino(a: Dictionary) -> bool:
	var linha := int(a.get("linha_rosto", Aparencia.LINHA_ROSTO_M))
	if linha == Aparencia.LINHA_ROSTO_F or linha == Aparencia.LINHA_ESTUDIO_F:
		return true
	return int(a.get("perfil", -1)) == Aparencia.PECA_PERFIL_F \
		and int(a.get("linha_perfil", Aparencia.LINHA_PECAS)) == Aparencia.LINHA_PECAS


## Os aneis do tronco, do gancho a base do pescoco: [y, meia-largura, frente,
## costas], em metros do corpo de referencia (a altura escala o y depois).
##
## A largura sai do "ombro" da aparencia, que no corpo de caixas era a largura
## do tronco inteiro. A barriga entra com expoente: ate a metade do controle ela
## quase nao aparece, e depois cresce rapido — que e como engorda gente.
static func perfil_tronco(a: Dictionary) -> Array:
	var g := gordura(a)
	var s := float(a.get("ombro", 0.42))
	var q := float(a.get("quadril", 0.30))
	var fem := feminino(a)
	var barriga := pow(g, 1.6)
	var seco := 0.93 + 0.07 * g
	var mq := meio_quadril(a)
	var coxa := raio_coxa(a)
	var cintura := (0.33 if fem else 0.35) * s * (0.94 + 0.12 * g)
	return [
		[0.80, mq + coxa * 0.62, 0.07 + 0.03 * g, 0.085 + 0.035 * g + (0.012 if fem else 0.0)],
		[0.915, q * 0.52 * (0.92 + 0.30 * g) + 0.02 * g, 0.092 + 0.02 * g + 0.02 * barriga,
			0.112 + 0.04 * g + (0.022 if fem else 0.0)],
		# O cinto passa POR BAIXO da barriga: a frente dele cresce pouco, e a
		# barra da camisa (ver `tronco`) sobra por cima.
		[Y_CINTO, cintura + 0.075 * g, 0.098 + 0.02 * g + 0.04 * barriga, 0.10 + 0.03 * g],
		# A barriga mais funda fica na altura do umbigo, e sobe afinando ate o
		# peito. Com o maximo no peito, de lado o gordo lia como busto.
		[1.10, s * 0.36 * seco + 0.10 * g, 0.104 + 0.02 * g + 0.15 * barriga, 0.10 + 0.03 * g],
		[1.18, s * 0.40 * seco + 0.085 * g, 0.108 + 0.024 * g + 0.10 * barriga
			+ (0.012 if fem else 0.0), 0.102 + 0.028 * g],
		[1.26, s * 0.44 * seco + 0.055 * g, 0.112 + 0.028 * g + 0.02 * barriga
			+ (0.036 if fem else 0.0), 0.104 + 0.025 * g],
		[1.35, s * 0.50 * (0.94 + 0.06 * g) + 0.04 * g, 0.092 + 0.02 * g
			+ (0.010 if fem else 0.0), 0.10 + 0.02 * g],
		[1.415, 0.085 + 0.035 * g, 0.055 + 0.015 * g, 0.066 + 0.02 * g],
	]


## Meia-largura, frente e costas do tronco na altura `y` (de referencia).
static func medida(perfil: Array, y: float) -> Vector3:
	if perfil.is_empty():
		return Vector3(0.2, 0.12, 0.12)
	var primeiro: Array = perfil[0]
	if y <= float(primeiro[0]):
		return Vector3(primeiro[1], primeiro[2], primeiro[3])
	for k in range(1, perfil.size()):
		var p1: Array = perfil[k]
		if y <= float(p1[0]):
			var p0: Array = perfil[k - 1]
			var t := (y - float(p0[0])) / (float(p1[0]) - float(p0[0]))
			return Vector3(lerpf(p0[1], p1[1], t), lerpf(p0[2], p1[2], t),
				lerpf(p0[3], p1[3], t))
	var ultimo: Array = perfil[perfil.size() - 1]
	return Vector3(ultimo[1], ultimo[2], ultimo[3])


## Profundidade da frente do tronco a `x` do meio, na altura `y`. E onde uma
## peca pregada na roupa (bolso, botao fora do eixo) tem de encostar.
static func frente_em(perfil: Array, y: float, x: float) -> float:
	var m := medida(perfil, y)
	var r := clampf(absf(x) / maxf(m.x, 0.01), 0.0, 1.0)
	return m.y * pow(maxf(0.0, 1.0 - pow(r, FORMA_TRONCO)), 1.0 / FORMA_TRONCO)


## O braco nasce na borda do ombro, e o ombro do gordo e mais largo.
static func meio_ombro(a: Dictionary) -> float:
	var ombro: Array = perfil_tronco(a)[6]
	return float(ombro[1]) + 0.012


## As coxas se afastam com o porte: coxa grossa no mesmo eixo da fina atravessa
## a outra.
static func meio_quadril(a: Dictionary) -> float:
	return float(a.get("quadril", 0.30)) * 0.29 + 0.03 * gordura(a)


static func raio_coxa(a: Dictionary) -> float:
	return 0.075 * (0.88 + 0.45 * gordura(a)) + (0.006 if feminino(a) else 0.0)


## As estacoes do braco: [y, raio em x, raio em z, peso do antebraco, v].
##
## O punho e mais largo em z que em x porque a mao pende com a palma virada para
## a coxa: o punho acompanha a palma.
static func estacoes_braco(a: Dictionary, perto: bool) -> Array:
	var g := gordura(a)
	var cb := 0.86 + 0.42 * g
	var ca := 0.90 + 0.22 * g
	var cp := 0.96 + 0.10 * g
	var todas: Array = [
		# O alto do deltoide continua a rampa do trapezio: nascendo acima do
		# ombro, o braco lia como encaixado de cima, de boneco articulado.
		[1.39, 0.032 * cb, 0.034 * cb, 0.0, 0.0],
		# Arredonda a calota do ombro. Sem ele, entre a tampa e o deltoide ficava
		# uma quina que, com o braco a frente do corpo, lia como ombreira pontuda.
		[1.375, 0.047 * cb, 0.050 * cb, 0.0, 0.07],
		[1.345, 0.056 * cb, 0.060 * cb, 0.0, 0.15],
		[1.23, 0.047 * cb, 0.052 * cb, 0.0, 0.6],
		[1.10, 0.040 * ca, 0.043 * ca, 0.5, 1.0],
		[1.01, 0.042 * ca, 0.046 * ca, 1.0, 0.6],
		[0.865, 0.025 * cp, 0.032 * cp, 1.0, 0.0],
	]
	if perto:
		return todas
	return [todas[0], todas[2], todas[4], todas[6]]


## As estacoes da perna: [y, raio em x, raio em z, peso da canela, v, desvio z].
## A panturrilha fica atras do eixo, e a coxa um pouco a frente.
static func estacoes_perna(a: Dictionary, perto: bool) -> Array:
	var g := gordura(a)
	var cc := 0.90 + 0.30 * g
	var rt := raio_coxa(a)
	var todas: Array = [
		[0.95, rt * 0.95, rt, 0.0, 0.0, 0.0],
		[0.80, rt, rt * 1.08, 0.0, 0.3, -0.005],
		[0.62, rt * 0.80, rt * 0.88, 0.0, 0.7, 0.0],
		[0.47, 0.050 * cc, 0.054 * cc, 0.5, 1.0, 0.0],
		[0.35, 0.050 * cc, 0.057 * cc, 1.0, 0.7, 0.012],
		[0.20, 0.038 * cc, 0.042 * cc, 1.0, 0.35, 0.004],
		[0.06, 0.034, 0.036, 1.0, 0.0, 0.0],
	]
	if perto:
		return todas
	return [todas[0], todas[1], todas[3], todas[4], todas[6]]


## Raio (x, z) do membro na altura `y`, interpolado nas estacoes.
static func raio_em(estacoes: Array, y: float) -> Vector2:
	for k in range(1, estacoes.size()):
		var e1: Array = estacoes[k]
		if y >= float(e1[0]):
			var e0: Array = estacoes[k - 1]
			var t := (float(e0[0]) - y) / (float(e0[0]) - float(e1[0]))
			return Vector2(lerpf(e0[1], e1[1], t), lerpf(e0[2], e1[2], t))
	var ultima: Array = estacoes[estacoes.size() - 1]
	return Vector2(ultima[1], ultima[2])


# --- a malha ------------------------------------------------------------------

static func _spow(v: float, p: float) -> float:
	return signf(v) * pow(absf(v), p)


## Vertice `j` do anel. O zero fica no lado -X, o quarto de volta na frente (-Z)
## e a meia volta no lado +X: frente e costas comecam e acabam nos flancos,
## que e onde a costura da celula menos aparece.
static func _ponto(an: Anel, j: int, lados: int, forma: float) -> Vector3:
	var phi := PI + TAU * float(j) / float(lados)
	var x := an.w * _spow(cos(phi), 2.0 / forma)
	var s := sin(phi)
	var z := (an.f if s < 0.0 else an.b) * _spow(s, 2.0 / forma)
	if an.ondas > 0.0:
		var onda := 1.0 + an.ondas * sin(float(an.n_ondas) * phi + an.fase)
		x *= onda
		z *= onda
	return an.c + Vector3(x, 0.0, z)


## Quanto o vertice `j` fica no fundo de uma dobra, de 0 (crista) a 1 (vale).
static func _vale(an: Anel, j: int, lados: int) -> float:
	if an.ondas <= 0.0:
		return 0.0
	var phi := PI + TAU * float(j) / float(lados)
	return 0.5 - 0.5 * sin(float(an.n_ondas) * phi + an.fase)


## Sombra de pano no vertice: o que olha para baixo escurece (debaixo da
## barriga, da barra, do braco), e o fundo da dobra tambem. Vai na cor do
## vertice, e por isso vale nos dois estilos — no PS1, que nao tem mapa de
## normal, e ela que da o relevo.
static func _tom(an: Anel, j: int, lados: int, normal: Vector3) -> float:
	var t := 1.0 - an.sombra
	if normal.y < 0.0:
		t -= 0.22 * -normal.y
	t -= 0.14 * _vale(an, j, lados) * clampf(an.ondas / 0.04, 0.0, 1.0)
	return clampf(t, 0.55, 1.0)


## Tubo pelos aneis, uma faixa por trecho (`null` pula o trecho).
##
## Os vertices sao por faixa, e nao compartilhados: cada faixa tem a propria
## celula e cor. As normais, estas sim, saem do tubo inteiro — vizinho de cima e
## de baixo —, e e isso que faz a luz passar lisa de uma faixa para a outra.
static func tubo(d: Dictionary, aneis: Array, lados: int, faixas: Array,
		forma: float, tampa_baixo: Variant = null, tampa_cima: Variant = null) -> void:
	var n := aneis.size()
	var pos: Array[PackedVector3Array] = []
	for r in n:
		var ps := PackedVector3Array()
		for j in lados:
			ps.append(_ponto(aneis[r], j, lados, forma))
		pos.append(ps)
	var nor: Array[PackedVector3Array] = []
	for r in n:
		var ns := PackedVector3Array()
		var centro: Vector3 = (aneis[r] as Anel).c
		for j in lados:
			var p := pos[r][j]
			var radial := p - centro
			radial.y = 0.0
			var ao_redor := pos[r][(j + 1) % lados] - pos[r][(j - 1 + lados) % lados]
			var ao_longo := Vector3.ZERO
			# Degrau (barra de manga, bainha): dois aneis na mesma altura nao
			# dizem para onde a superficie vai, e a normal sairia deitada.
			if r > 0 and absf(p.y - pos[r - 1][j].y) > 0.015:
				ao_longo += (p - pos[r - 1][j]).normalized()
			if r < n - 1 and absf(pos[r + 1][j].y - p.y) > 0.015:
				ao_longo += (pos[r + 1][j] - p).normalized()
			var nn := radial
			if ao_longo.length() > 0.01 and ao_redor.length() > 0.0001:
				nn = ao_redor.cross(ao_longo)
				if nn.dot(radial) < 0.0:
					nn = -nn
			ns.append(nn.normalized() if nn.length() > 0.00001 else Vector3.UP)
		nor.append(ns)

	var vs: PackedVector3Array = d["v"]
	var nm: PackedVector3Array = d["n"]
	var uv: PackedVector2Array = d["uv"]
	var cs: PackedColorArray = d["c"]
	var ix: PackedInt32Array = d["i"]
	var bs: PackedInt32Array = d["b"]
	var ws: PackedFloat32Array = d["w"]

	for k in n - 1:
		var fx: Variant = faixas[k]
		if fx == null:
			continue
		var cor: Color = fx["cor"]
		var cel: Rect2 = fx["cel"]
		if fx["costas"] != null:
			_tira(vs, nm, uv, cs, ix, bs, ws, aneis, pos, nor, k, 0, lados / 2, lados,
				cor, cel, false)
			_tira(vs, nm, uv, cs, ix, bs, ws, aneis, pos, nor, k, lados / 2, lados, lados,
				cor, fx["costas"], false)
		else:
			_tira(vs, nm, uv, cs, ix, bs, ws, aneis, pos, nor, k, 0, lados, lados,
				cor, cel, true)
	if tampa_baixo != null:
		_tampa(vs, nm, uv, cs, ix, bs, ws, aneis[0], pos[0], -1.0, tampa_baixo)
	if tampa_cima != null:
		_tampa(vs, nm, uv, cs, ix, bs, ws, aneis[n - 1], pos[n - 1], 1.0, tampa_cima)

	d["v"] = vs
	d["n"] = nm
	d["uv"] = uv
	d["c"] = cs
	d["i"] = ix
	d["b"] = bs
	d["w"] = ws
	var uv2: PackedVector2Array = d.get("uv2", PackedVector2Array())
	uv2.resize(vs.size())
	d["uv2"] = uv2


static func _cel_uv(cel: Rect2, u: float, v: float) -> Vector2:
	return cel.position + Vector2(lerpf(MARGEM_UV, 1.0 - MARGEM_UV, u),
		lerpf(MARGEM_UV, 1.0 - MARGEM_UV, clampf(v, 0.0, 1.0))) * cel.size


## Pesos do vertice: o osso do anel, o da junta, e por cima os de pano (saia:
## frente ou costas conforme o lado do vertice) e o da barriga (so a frente,
## mais no meio que nos flancos). Ate quatro ossos, somando um.
static func _pele(bs: PackedInt32Array, ws: PackedFloat32Array, an: Anel,
		p: Vector3 = Vector3.INF) -> void:
	var os: Array[int] = [an.osso]
	var ps: Array[float] = [1.0]
	if an.osso2 >= 0 and an.peso2 > 0.0:
		os.append(an.osso2)
		ps = [1.0 - an.peso2, an.peso2]
	var frente := 0.0
	var meio := 1.0
	if p != Vector3.INF:
		frente = clampf(-(p.z - an.c.z) / maxf(an.f, 0.01), -1.0, 1.0)
		meio = 1.0 - clampf(absf(p.x - an.c.x) / maxf(an.w, 0.01), 0.0, 1.0)
	if an.pano > 0.0:
		var pf := clampf(0.5 + 0.75 * frente, 0.0, 1.0)
		for i in ps.size():
			ps[i] *= 1.0 - an.pano
		os.append(Corpo.Osso.SAIA_F)
		ps.append(an.pano * pf)
		os.append(Corpo.Osso.SAIA_T)
		ps.append(an.pano * (1.0 - pf))
	elif an.barriga > 0.0 and frente > 0.0:
		var pb := an.barriga * pow(frente, 1.5) * (0.4 + 0.6 * meio)
		for i in ps.size():
			ps[i] *= 1.0 - pb
		os.append(Corpo.Osso.BARRIGA)
		ps.append(pb)
	while os.size() < 4:
		os.append(0)
		ps.append(0.0)
	bs.append_array(os)
	ws.append_array(ps)


static func _tira(vs: PackedVector3Array, nm: PackedVector3Array,
		uv: PackedVector2Array, cs: PackedColorArray, ix: PackedInt32Array,
		bs: PackedInt32Array, ws: PackedFloat32Array, aneis: Array,
		pos: Array[PackedVector3Array], nor: Array[PackedVector3Array], k: int,
		j0: int, j1: int, lados: int, cor: Color, cel: Rect2, espelha: bool) -> void:
	var base := vs.size()
	for jj in range(j0, j1 + 1):
		var t := float(jj - j0) / float(j1 - j0)
		# Frente vista de frente: o -X fica a direita de quem olha, e o u da
		# celula corre da esquerda. Na volta espelhada, 0 -> 1 -> 0.
		var u := (1.0 - absf(1.0 - 2.0 * t)) if espelha else 1.0 - t
		for r: int in [k, k + 1]:
			var an: Anel = aneis[r]
			var p := pos[r][jj % lados]
			var n := nor[r][jj % lados]
			vs.append(p)
			nm.append(n)
			uv.append(_cel_uv(cel, u, an.v))
			var tom := _tom(an, jj % lados, lados, n)
			cs.append(Color(cor.r * tom, cor.g * tom, cor.b * tom, cor.a))
			_pele(bs, ws, an, p)
	# Sentido do triangulo: o motor desenha a face cujo produto vetorial aponta
	# para DENTRO (ver PSXMesh.placa_dados). Confere no primeiro quad util em
	# vez de confiar na ordem dos vertices.
	var inverte := false
	var meio := (j1 - j0) / 2
	var a := base + meio * 2
	var fora := nm[a] + nm[a + 2]
	var face := (vs[a + 1] - vs[a]).cross(vs[a + 2] - vs[a])
	if face.length() < 1e-9:
		face = (vs[a + 3] - vs[a + 1]).cross(vs[a + 2] - vs[a + 1])
	inverte = face.dot(fora) > 0.0
	for q in j1 - j0:
		var p0 := base + q * 2
		var p1 := p0 + 1
		var p2 := p0 + 2
		var p3 := p0 + 3
		if inverte:
			ix.append_array([p0, p2, p1, p2, p3, p1])
		else:
			ix.append_array([p0, p1, p2, p2, p1, p3])


static func _tampa(vs: PackedVector3Array, nm: PackedVector3Array,
		uv: PackedVector2Array, cs: PackedColorArray, ix: PackedInt32Array,
		bs: PackedInt32Array, ws: PackedFloat32Array, an: Anel,
		anel: PackedVector3Array, sentido: float, fx: Dictionary) -> void:
	var cor: Color = fx["cor"]
	var cel: Rect2 = fx["cel"]
	var normal := Vector3(0.0, sentido, 0.0)
	var base := vs.size()
	var lados := anel.size()
	# Tampa de cima abaulada: disco chato no alto do braco vira quina no
	# contorno quando o braco gira, e le como ombreira pontuda.
	var bojo := 0.0 if sentido < 0.0 else minf(an.w, an.f) * 0.45
	vs.append(an.c + normal * bojo)
	nm.append(normal)
	uv.append(_cel_uv(cel, 0.5, 0.5))
	cs.append(cor)
	_pele(bs, ws, an, an.c)
	for j in lados:
		var p := anel[j]
		vs.append(p)
		nm.append(normal)
		uv.append(_cel_uv(cel, 0.5 + (p.x - an.c.x) / maxf(an.w, 0.001) * 0.3,
			0.5 + (p.z - an.c.z) / maxf(an.f, 0.001) * 0.3))
		cs.append(cor)
		_pele(bs, ws, an, p)
	var face := (vs[base + 1] - vs[base]).cross(vs[base + 2] - vs[base])
	var inverte := face.dot(normal) > 0.0
	for j in lados:
		var p1 := base + 1 + j
		var p2 := base + 1 + (j + 1) % lados
		if inverte:
			ix.append_array([base, p2, p1])
		else:
			ix.append_array([base, p1, p2])


# --- as partes ----------------------------------------------------------------

## Pelve e tronco. A camisa comeca um dedo abaixo de onde a calca acaba e um
## dedo mais larga: e a barra caindo por cima do cos, e na barriga grande ela
## sobra para a frente, que e o que se ve de lado.
static func tronco(corpo: Corpo, d: Dictionary, perto: bool, cor_camisa: Color,
		cel_frente: Rect2, cel_costas: Rect2, cor_calca: Color, cel_calca: Rect2,
		por_dentro: bool = false) -> void:
	var perfil := corpo.perfil()
	var a := corpo._aparencia
	var lados := LADOS_TRONCO_PERTO if perto else LADOS_TRONCO_RUA
	var q := Corpo.Osso.QUADRIL
	var t := Corpo.Osso.TORSO
	var topo_pelve := Y_CINTO + 0.03
	var pelve: Array = []
	for y: float in [0.80, 0.915, Y_CINTO, topo_pelve]:
		var m := medida(perfil, y)
		var junta := y >= Y_CINTO
		# Camisa por dentro: o cos da calca fica POR FORA dela, um dedo mais largo.
		var cos_fora := 0.008 if por_dentro and junta else 0.0
		var anel := Anel.new(Vector3(0.0, corpo._y(y), 0.0), m.x + cos_fora, m.y + cos_fora, m.z + cos_fora,
			q, (topo_pelve - y) / (topo_pelve - 0.80), t if junta else -1, 0.5 if junta else 0.0)
		# A sombra do gancho: sem ela a pelve entre as coxas lia como peca clara.
		if y < 0.85:
			anel.sombra = 0.12
		pelve.append(anel)
	var pinta_calca := faixa(cor_calca, cel_calca, cel_calca)
	# A pelve e o mesmo tecido liso da perna; a celula inteira, com cinto e
	# bolsos, so no cos. Com os bolsos na frente da pelve, o pedaco entre as
	# coxas ganhava outro desenho e uma borda reta em cima, e lia como cueca.
	var liso := faixa(cor_calca, tecido(cel_calca), tecido(cel_calca))
	# Sem tampa no gancho: as coxas cobrem, e so se veria deitado no chao.
	tubo(d, pelve, lados, [liso, liso, pinta_calca], FORMA_TRONCO)

	var y_barra := Y_CINTO + 0.012 if por_dentro else Y_CINTO - 0.015
	var topo: float = (perfil[perfil.size() - 1] as Array)[0]
	var alturas: Array[float] = [y_barra]
	if por_dentro:
		# O tecido sobra um pouco acima do cinto, como camisa enfiada na calca.
		alturas.append(Y_CINTO + 0.05)
	for p: Array in perfil:
		# Na rua o anel entre a barriga e o peito sai: de longe a curva le igual.
		if float(p[0]) > Y_CINTO + 0.06 and (perto or absf(float(p[0]) - 1.18) > 0.001):
			alturas.append(float(p[0]))
	var peito: Array = []
	for y: float in alturas:
		# A barra fica um dedo por fora do cinto: a camisa cai por cima da
		# calca, e a barriga grande curva por baixo ate ela. Medida na barriga,
		# a barra virava uma prateleira reta com a calca recuada embaixo.
		var m := medida(perfil, maxf(y, Y_CINTO))
		var sobra := 0.014 if y < Y_CINTO + 0.01 else 0.0
		if por_dentro:
			sobra = -0.002 if y < Y_CINTO + 0.02 else (0.008 if y < Y_CINTO + 0.06 else 0.0)
		var junta := y < 1.08
		var anel := Anel.new(Vector3(0.0, corpo._y(y), 0.0), m.x + sobra, m.y + sobra,
			m.z + sobra, t, (topo - y) / (topo - y_barra), q if junta else -1,
			0.5 if junta else 0.0)
		anel.barriga = fator_barriga(a, y)
		if y == y_barra and not por_dentro:
			# A barra solta drapeia: cinco ondas em volta da cintura.
			anel.dobra(0.035, 5, 0.4)
		elif por_dentro and y > Y_CINTO + 0.03 and y < Y_CINTO + 0.06:
			anel.dobra(0.03, 6, 0.9)
		peito.append(anel)
	var faixas: Array = []
	var pinta := faixa(cor_camisa, cel_frente, cel_costas)
	for k in peito.size() - 1:
		faixas.append(pinta)
	tubo(d, peito, lados, faixas, FORMA_TRONCO, null, faixa(cor_camisa, cel_costas))


## Pescoco, no osso da cabeca como era a caixa. Com o porte ele engrossa e ganha
## papada: o anel do meio avanca por baixo do queixo.
static func pescoco(corpo: Corpo, d: Dictionary, a: Dictionary, perto: bool,
		pele: Color, cel: Rect2) -> void:
	var g := gordura(a)
	var gn := 1.0 + 0.45 * g
	var papada := 0.03 * g * g
	var cab := Corpo.Osso.CABECA
	var aneis: Array = [
		Anel.new(Vector3(0.0, corpo._y(1.385), 0.005), 0.050 * gn, 0.050 * gn, 0.056 * gn,
			cab, 1.0),
		Anel.new(Vector3(0.0, corpo._y(1.455), 0.005), 0.047 * gn, 0.047 * gn + papada,
			0.052 * gn, cab, 0.4),
		Anel.new(Vector3(0.0, corpo._y(1.50), 0.005), 0.046 * gn, 0.046 * gn + papada,
			0.050 * gn, cab, 0.0),
	]
	var pinta := faixa(pele, miolo(cel))
	if not perto:
		# A papada e coisa de retrato; na rua o pescoco e um trecho so.
		aneis.remove_at(1)
		tubo(d, aneis, LADOS_MEMBRO_RUA, [pinta], FORMA_MEMBRO)
		return
	tubo(d, aneis, LADOS_MEMBRO_PERTO, [pinta, pinta], FORMA_MEMBRO)


## Estilo de manga: sem (regata), curta, ou longa.
enum Manga { SEM, CURTA, LONGA }


static func braco(corpo: Corpo, d: Dictionary, a: Dictionary, lado: float,
		perto: bool, manga: int, cor_manga: Color, cel_manga: Rect2, pele: Color,
		cel_pele: Rect2) -> void:
	var est := estacoes_braco(a, perto)
	var x := meio_ombro(a) * lado
	var osso := Corpo.Osso.BRACO_E if lado < 0.0 else Corpo.Osso.BRACO_D
	var ante := Corpo.Osso.ANTEBRACO_E if lado < 0.0 else Corpo.Osso.ANTEBRACO_D
	# Estacoes com a barra da manga curta inserida: dois aneis quase na mesma
	# altura, o de cima com a folga do tecido e o de baixo na pele.
	var lista: Array = []
	for e: Array in est:
		lista.append([float(e[0]), float(e[1]), float(e[2]), float(e[3]), float(e[4])])
	if manga == Manga.CURTA:
		var r := raio_em(est, Y_MANGA_CURTA)
		var nova: Array = []
		var posta := false
		for e: Array in lista:
			if not posta and float(e[0]) < Y_MANGA_CURTA:
				nova.append([Y_MANGA_CURTA + 0.004, r.x, r.y, 0.0, 0.62])
				nova.append([Y_MANGA_CURTA - 0.004, r.x, r.y, 0.0, 0.64])
				posta = true
			nova.append(e)
		lista = nova
	var aneis: Array = []
	var vestido: Array[bool] = []
	# O tecido nao acompanha o afinar do deltoide para o biceps: cai quase reto
	# do ombro ate a barra. Seguindo o musculo, a manga curta do gordo virava
	# manga bufante de blusa.
	var queda := raio_em(est, 1.345) * 0.93
	for i in lista.size():
		var e: Array = lista[i]
		var y: float = e[0]
		var veste := manga == Manga.LONGA or (manga == Manga.CURTA and y > Y_MANGA_CURTA)
		vestido.append(veste)
		var folga := FOLGA_MANGA if veste else 0.0
		var peso: float = e[3]
		var rx: float = e[1]
		var rz: float = e[2]
		if veste and y < 1.345 and y > 1.10:
			rx = maxf(rx, queda.x)
			rz = maxf(rz, queda.y)
		elif veste and y >= 1.385:
			# O alto da manga cobre a curva do ombro sem virar um pompom.
			rx = maxf(rx, queda.x * 0.72)
			rz = maxf(rz, queda.y * 0.72)
		if y > 1.33:
			# O alto do braco fica acima do eixo do ombro, e quando o braco gira
			# para a frente e para dentro esse pedaco gira para FORA: preso so ao
			# braco, furava a jaqueta em ponta. Dividido com o tronco, ele estica.
			# A calota fica inteira no tronco e um dedo para dentro, emendando no
			# trapezio: meio presa, ela ficava para tras quando o braco fechava e
			# aparecia como ponta (ver `bancada_criacao.gd --cor-por-osso`).
			var do_tronco := 1.0 if y > 1.385 else (0.7 if y > 1.36 else 0.4)
			var recuo := 0.014 * lado if y > 1.385 else 0.0
			aneis.append(Anel.new(Vector3(x - recuo, corpo._y(y), 0.0), rx + folga, rz + folga,
				rz + folga, Corpo.Osso.TORSO, e[4], osso if do_tronco < 1.0 else -1,
				1.0 - do_tronco))
			continue
		var anel := Anel.new(Vector3(x, corpo._y(y), 0.0), rx + folga,
			rz + folga, rz + folga, osso if peso < 1.0 else ante,
			e[4], ante if peso > 0.0 and peso < 1.0 else -1, peso if peso < 1.0 else 0.0)
		if veste:
			# Pano de manga amassa onde dobra: na barra da curta, no cotovelo e
			# no punho da comprida, que ainda sobra um pouco sobre a mao.
			if absf(y - (Y_MANGA_CURTA + 0.004)) < 0.001:
				anel.dobra(0.05, 3, 0.7 * lado)
			elif absf(y - 1.10) < 0.001:
				anel.dobra(0.06, 3, 1.9)
			elif absf(y - 1.01) < 0.001:
				anel.dobra(0.035, 2, 0.3)
			elif y < 0.87:
				anel.w += 0.003
				anel.f += 0.003
				anel.b += 0.003
				anel.dobra(0.05, 4, 1.1)
		elif y > 1.25 and y < 1.36:
			# A axila: sombra de onde o braco encosta no tronco.
			anel.sombra = 0.04
		aneis.append(anel)
	var faixas: Array = []
	for k in aneis.size() - 1:
		if vestido[k] and vestido[k + 1]:
			faixas.append(faixa(cor_manga, cel_manga))
		elif vestido[k]:
			# A barra: o avesso da manga, mais escuro, dobrando para a pele.
			faixas.append(faixa(cor_manga.darkened(0.35), cel_manga))
		else:
			faixas.append(faixa(pele, miolo(cel_pele)))
	var cor_ombro := cor_manga if vestido[0] else pele
	var cel_ombro := cel_manga if vestido[0] else miolo(cel_pele)
	var fim_vestido: bool = vestido[vestido.size() - 1]
	# O punho de pele fica dentro da palma e nao precisa de tampa; a boca da
	# manga comprida precisa, senao se ve o oco do tubo por baixo.
	tubo(d, aneis, LADOS_MEMBRO_PERTO if perto else LADOS_MEMBRO_RUA, faixas,
		FORMA_MEMBRO,
		faixa(cor_manga.darkened(0.4), cel_manga) if fim_vestido else null,
		faixa(cor_ombro, cel_ombro))


## Mao pendente, palma virada para a coxa e polegar para a frente.
##
## A caixa unica de antes tinha 8,8 cm de espessura — mais grossa que o punho — e
## os dedos pintados. De perto era uma luva de boxe. Aqui a palma e fina, os
## quatro dedos saem dobrados para dentro, cada um do seu comprimento, e o
## polegar sai da borda da frente. Na rua, os quatro dedos viram um bloco so e
## o polegar some: a dez metros a mao inteira tem dois pixels.
static func mao(corpo: Corpo, d: Dictionary, a: Dictionary, lado: float, perto: bool,
		pele: Color, cel: Rect2) -> void:
	var g := gordura(a)
	var gr := 1.0 + 0.14 * g
	var x := meio_ombro(a) * lado
	var osso := Corpo.Osso.ANTEBRACO_E if lado < 0.0 else Corpo.Osso.ANTEBRACO_D
	var dentro := -lado
	var y_junta := corpo._y(0.776)
	cel = miolo(cel)
	# Palma, um tico para dentro do eixo do punho: e a palma que encosta na coxa.
	corpo._caixa(d, Vector3(0.030 * gr, corpo._y(0.088), 0.080 * gr),
		Vector3(x + dentro * 0.003, corpo._y(0.818), 0.002), pele, cel, osso, {},
		PSXMesh.FACE_TODAS & ~PSXMesh.FACE_TOPO)
	var tom_dedo := pele.darkened(0.07)
	if perto:
		# Indicador na frente, minimo atras; o medio e o mais comprido, e o
		# minimo o que mais fecha.
		var zs := [-0.029, -0.0097, 0.0097, 0.028]
		var comp := [0.064, 0.070, 0.066, 0.052]
		var dobra := [0.30, 0.36, 0.42, 0.50]
		for i in 4:
			var junta := Vector3(x + dentro * 0.004, y_junta, float(zs[i]) * gr)
			var giro := Basis(Vector3.BACK, float(dobra[i]) * dentro)
			var tam := Vector3(0.019 * gr, corpo._y(float(comp[i])), 0.0175 * gr)
			var centro := junta + giro * Vector3(0.0, -tam.y * 0.5, 0.0)
			_caixa_girada_sem_topo(corpo, d, tam, Transform3D(giro, centro), tom_dedo, cel, osso)
	else:
		var giro := Basis(Vector3.BACK, 0.36 * dentro)
		var tam := Vector3(0.022 * gr, corpo._y(0.062), 0.074 * gr)
		var junta := Vector3(x + dentro * 0.004, y_junta, 0.0)
		_caixa_girada_sem_topo(corpo, d, tam, Transform3D(giro,
			junta + giro * Vector3(0.0, -tam.y * 0.5, 0.0)), tom_dedo, cel, osso)
	if not perto:
		return
	# Polegar: da borda da frente, descendo para a frente e para dentro.
	var base_polegar := Vector3(x + dentro * 0.010, corpo._y(0.826), -0.036 * gr)
	var giro_p := Basis(Vector3.BACK, 0.30 * dentro) * Basis(Vector3.RIGHT, 0.62)
	var tam_p := Vector3(0.021 * gr, corpo._y(0.056), 0.021 * gr)
	_caixa_girada_sem_topo(corpo, d, tam_p, Transform3D(giro_p,
		base_polegar + giro_p * Vector3(0.0, -tam_p.y * 0.5, 0.0)), pele, cel, osso)


## Caixa girada sem a face de cima, que fica enterrada na palma.
static func _caixa_girada_sem_topo(corpo: Corpo, d: Dictionary, tamanho: Vector3,
		xform: Transform3D, cor: Color, celula: Rect2, osso: int) -> void:
	var meio := tamanho * 0.5
	for item: Array in Corpo.FACES:
		var bit := int(item[0])
		if bit == PSXMesh.FACE_TOPO:
			continue
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


## Perna inteira, coxa e canela num tubo so, com o joelho dividido entre os dois
## ossos. `calca`: 0 perna nua, 1 calca comprida, 2 bermuda (barra no joelho).
##
## Calca comprida cai reta do joelho para baixo: o tecido nao acompanha a
## panturrilha. E um detalhe que se ve de lado, e e o que separa calca de meia.
static func perna(corpo: Corpo, d: Dictionary, a: Dictionary, lado: float, perto: bool,
		calca: int, cor_calca: Color, cel_calca: Rect2, pele: Color, cel_pele: Rect2) -> void:
	var est := estacoes_perna(a, perto)
	var g := gordura(a)
	var x := meio_quadril(a) * lado
	var coxa := Corpo.Osso.COXA_E if lado < 0.0 else Corpo.Osso.COXA_D
	var canela := Corpo.Osso.CANELA_E if lado < 0.0 else Corpo.Osso.CANELA_D
	var reta := 0.056 * (0.95 + 0.2 * g)
	var y_barra := 0.49
	var lista: Array = []
	for e: Array in est:
		lista.append(e.duplicate())
	if calca == 2:
		var r := raio_em(est, y_barra)
		var nova: Array = []
		var posta := false
		for e: Array in lista:
			if not posta and float(e[0]) < y_barra:
				nova.append([y_barra + 0.004, r.x, r.y, 0.0, 0.95, 0.0])
				nova.append([y_barra - 0.004, r.x, r.y, 0.0, 0.97, 0.0])
				posta = true
			nova.append(e)
		lista = nova
	var amontoa := calca == 1 and int(a.get("calca_estilo", 0)) != Aparencia.CALCA_JOGGER
	if amontoa:
		# A barra amontoa em cima do sapato: um anel a mais, mais largo e
		# ondulado, logo acima do tornozelo. A jogger nao: o elastico prende.
		var nova: Array = []
		for e: Array in lista:
			if float(e[0]) < 0.07:
				nova.append([0.12, 0.036, 0.040, 1.0, 0.18, 0.0])
			nova.append(e)
		lista = nova
	var aneis: Array = []
	var vestido: Array[bool] = []
	for e: Array in lista:
		var y: float = e[0]
		var veste := calca == 1 or (calca == 2 and y > y_barra)
		vestido.append(veste)
		var rx: float = e[1]
		var rz: float = e[2]
		if veste:
			rx += FOLGA_CALCA
			rz += FOLGA_CALCA
			if calca == 1 and y < 0.47:
				rx = maxf(rx, reta)
				rz = maxf(rz, reta * 1.06)
			if amontoa and y < 0.15:
				rx += 0.005
				rz += 0.006
		var peso: float = e[3]
		var anel := Anel.new(Vector3(x, corpo._y(y), float(e[5]) if not veste else 0.0),
			rx, rz, rz, coxa if peso < 1.0 else canela, e[4],
			canela if peso > 0.0 and peso < 1.0 else -1, peso if peso < 1.0 else 0.0)
		if veste:
			if absf(y - 0.12) < 0.001:
				anel.dobra(0.07, 3, 0.8 * lado)
			elif y < 0.07:
				anel.dobra(0.04, 2, 2.2)
			elif absf(y - 0.47) < 0.001:
				# Atras do joelho a calca vinca.
				anel.dobra(0.03, 4, 0.0)
			elif absf(y - y_barra - 0.004) < 0.001:
				anel.dobra(0.04, 3, 0.5)
		aneis.append(anel)
	var liso := tecido(cel_calca)
	var faixas: Array = []
	for k in aneis.size() - 1:
		if vestido[k] and vestido[k + 1]:
			faixas.append(faixa(cor_calca, liso))
		elif vestido[k]:
			faixas.append(faixa(cor_calca.darkened(0.35), liso))
		else:
			faixas.append(faixa(pele, miolo(cel_pele)))
	# Sem tampa: o tornozelo termina dentro do sapato.
	tubo(d, aneis, LADOS_MEMBRO_PERTO if perto else LADOS_MEMBRO_RUA, faixas,
		FORMA_MEMBRO)


## O sapato de sempre (modelo zero), com sola, bico e cadarco de perto.
##
## Era uma caixa de 25 cm. De perto, no retrato e no jogador, ganha o que faz um
## sapato ler como sapato: a sola mais escura e um fio mais larga, o bico mais
## baixo que o peito do pe, o calcanhar alto e o cadarco claro em cima. Na rua
## continua a caixa: a dez metros o pe tem quatro pixels.
static func sapato(corpo: Corpo, d: Dictionary, x: float, osso: int, cor: Color,
		cel: Rect2) -> void:
	if not corpo.detalhado:
		corpo._caixa(d, Vector3(0.128, corpo._y(0.075), 0.25),
			Vector3(x, corpo._y(0.037), -0.045), cor, cel, osso)
		return
	var sola := cor.darkened(0.55)
	# Sola: chata, um pouco mais larga e mais comprida que o cabedal.
	corpo._caixa(d, Vector3(0.130, corpo._y(0.020), 0.262),
		Vector3(x, corpo._y(0.010), -0.047), sola, cel, osso)
	# Cabedal do calcanhar ao peito do pe.
	corpo._caixa(d, Vector3(0.118, corpo._y(0.062), 0.165),
		Vector3(x, corpo._y(0.050), 0.0), cor, cel, osso, {}, PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE)
	# Bico: mais baixo e mais estreito, e a ponta caida.
	Vestuario.caixa_girada(corpo, d, Vector3(0.108, corpo._y(0.040), 0.095),
		Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(x, corpo._y(0.040), -0.125)),
		cor, cel, osso)
	# Cadarco: tira clara em cima do peito do pe.
	corpo._caixa(d, Vector3(0.036, 0.006, 0.075),
		Vector3(x, corpo._y(0.083), -0.045), cor.lightened(0.45), Vestuario._liso(), osso)


# --- pecas de roupa que seguem o corpo -----------------------------------------

## Saia, aba de sobretudo: um tubo aberto em baixo, preso no quadril, que se
## abre ate passar das coxas. As pernas atravessam ao andar, como na caixa de
## antes — e o acordo de corpo rigido do PS1.
static func saia(corpo: Corpo, d: Dictionary, a: Dictionary, y_topo: float,
		y_barra: float, cor: Color, cel: Rect2, osso: int, folga: float = 0.012,
		pregas: float = 0.05) -> void:
	var perfil := corpo.perfil()
	var perto := corpo.detalhado
	var mq := meio_quadril(a)
	var rt := raio_coxa(a)
	var ys: Array[float] = [y_topo, lerpf(y_topo, y_barra, 0.35), y_barra]
	var aneis: Array = []
	for i in ys.size():
		var y: float = ys[i]
		var m := medida(perfil, clampf(y, 0.80, 1.40))
		var t := float(i) / float(ys.size() - 1)
		var w := maxf(m.x + folga, mq + rt + 0.02) * (1.0 + 0.10 * t)
		var f := maxf(m.y + folga, rt * 1.1 + 0.02) * (1.0 + 0.14 * t)
		var b := maxf(m.z + folga, rt * 1.1 + 0.02) * (1.0 + 0.14 * t)
		if i == 0:
			w = m.x + folga
			f = m.y + folga
			b = m.z + folga
		var anel := Anel.new(Vector3(0.0, corpo._y(y), 0.0), w, f, b, osso, t)
		if i > 0:
			var lados := LADOS_TRONCO_PERTO if perto else LADOS_TRONCO_RUA
			# Prega: uma onda por par de lados, alternando vertice a vertice.
			anel.dobra(pregas * t, lados / 2 if pregas >= 0.04 else 4, 0.0)
			# Pano solto: preso no quadril, a barra vai para os ossos de pano,
			# que balancam e se afastam da coxa que avanca.
			if osso == Corpo.Osso.QUADRIL:
				anel.pano = t
				corpo.tem_pano = true
		aneis.append(anel)
	var pinta := faixa(cor, cel, cel)
	tubo(d, aneis, LADOS_TRONCO_PERTO if perto else LADOS_TRONCO_RUA, [pinta, pinta],
		FORMA_TRONCO)


## Faixa em volta do tronco (barra, cos, listra), seguindo a forma do corpo.
static func cinta(corpo: Corpo, d: Dictionary, y0: float, y1: float, folga: float,
		cor: Color, cel: Rect2, osso: int) -> void:
	var perfil := corpo.perfil()
	var aneis: Array = []
	for y: float in [y0, y1]:
		var m := medida(perfil, y)
		aneis.append(Anel.new(Vector3(0.0, corpo._y(y), 0.0), m.x + folga, m.y + folga,
			m.z + folga, osso, 0.5 if y == y0 else 0.0))
	tubo(d, aneis, LADOS_TRONCO_PERTO if corpo.detalhado else LADOS_TRONCO_RUA,
		[faixa(cor, cel)], FORMA_TRONCO)


## Tira pregada na frente do tronco (vista, ziper, bolso, decote): segue a
## barriga de cima a baixo e a curva do peito de um lado ao outro, entao nao
## fura nem flutua na barriga grande.
static func fita(corpo: Corpo, d: Dictionary, largura: float, y0: float, y1: float,
		cor: Color, cel: Rect2, x: float = 0.0, folga: float = 0.003) -> void:
	var perfil := corpo.perfil()
	var ys: Array[float] = [y0]
	for p: Array in perfil:
		if float(p[0]) > y0 + 0.01 and float(p[0]) < y1 - 0.01:
			ys.append(float(p[0]))
	ys.append(y1)
	var colunas := 3 if largura > 0.06 else 1
	var vs: PackedVector3Array = d["v"]
	var nm: PackedVector3Array = d["n"]
	var uv: PackedVector2Array = d["uv"]
	var cs: PackedColorArray = d["c"]
	var ix: PackedInt32Array = d["i"]
	var bs: PackedInt32Array = d["b"]
	var ws: PackedFloat32Array = d["w"]
	var base := vs.size()
	var larg := colunas + 1
	for r in ys.size():
		var y: float = ys[r]
		var osso := Corpo.Osso.TORSO if y >= Y_CINTO - 0.02 else Corpo.Osso.QUADRIL
		var m_y := medida(perfil, y)
		# O mesmo anel que o tronco usa ali, para a tira balancar com a barriga.
		var anel := Anel.new(Vector3(0.0, corpo._y(y), 0.0), m_y.x, m_y.y, m_y.z, osso, 0.0)
		anel.barriga = fator_barriga(corpo._aparencia, y)
		for c in larg:
			var u := float(c) / float(colunas)
			var px := x + (u - 0.5) * largura
			var z := -(frente_em(perfil, y, px) + folga)
			var p := Vector3(px, corpo._y(y), z)
			vs.append(p)
			var inclina := (px / maxf(m_y.x, 0.05)) * 0.6
			nm.append(Vector3(inclina, 0.0, -1.0).normalized())
			uv.append(_cel_uv(cel, 1.0 - u, (y1 - y) / maxf(y1 - y0, 0.001)))
			cs.append(cor)
			_pele(bs, ws, anel, p)
	for r in ys.size() - 1:
		for c in colunas:
			var a0 := base + r * larg + c
			var a1 := a0 + 1
			var b0 := a0 + larg
			var b1 := b0 + 1
			# Vista de frente, x cresce para a esquerda de quem olha: o quad
			# (a0 embaixo, b0 em cima, a1 ao lado) aponta para -Z nesta ordem.
			ix.append_array([a0, a1, b0, a1, b1, b0])
	d["v"] = vs
	d["n"] = nm
	d["uv"] = uv
	d["c"] = cs
	d["i"] = ix
	d["b"] = bs
	d["w"] = ws
	var uv2: PackedVector2Array = d.get("uv2", PackedVector2Array())
	uv2.resize(vs.size())
	d["uv2"] = uv2


## Anel no braco (punho, ombreira) na altura `y0`..`y1`, com folga sobre a pele
## e sobre a manga.
static func anel_braco(corpo: Corpo, d: Dictionary, a: Dictionary, lado: float,
		y0: float, y1: float, folga: float, cor: Color, cel: Rect2) -> void:
	var est := estacoes_braco(a, true)
	var x := meio_ombro(a) * lado
	var osso := Corpo.Osso.BRACO_E if lado < 0.0 else Corpo.Osso.BRACO_D
	var ante := Corpo.Osso.ANTEBRACO_E if lado < 0.0 else Corpo.Osso.ANTEBRACO_D
	var aneis: Array = []
	for y: float in [y0, y1]:
		var r := raio_em(est, y) + Vector2.ONE * (folga + FOLGA_MANGA)
		aneis.append(Anel.new(Vector3(x, corpo._y(y), 0.0), r.x, r.y, r.y,
			ante if y < 1.10 else osso, 0.5 if y == y0 else 0.0))
	# So a boca de baixo tem tampa: a de cima fica dentro da manga.
	tubo(d, aneis, LADOS_MEMBRO_PERTO if corpo.detalhado else LADOS_MEMBRO_RUA,
		[faixa(cor, cel)], FORMA_MEMBRO, faixa(cor.darkened(0.3), cel))


## Anel na perna (barra de jogger, bolso de cargo usa `raio_perna`).
static func anel_perna(corpo: Corpo, d: Dictionary, a: Dictionary, lado: float,
		y0: float, y1: float, folga: float, cor: Color, cel: Rect2) -> void:
	var est := estacoes_perna(a, true)
	var x := meio_quadril(a) * lado
	var coxa := Corpo.Osso.COXA_E if lado < 0.0 else Corpo.Osso.COXA_D
	var canela := Corpo.Osso.CANELA_E if lado < 0.0 else Corpo.Osso.CANELA_D
	var reta := 0.056 * (0.95 + 0.2 * gordura(a))
	var aneis: Array = []
	for y: float in [y0, y1]:
		var r := raio_em(est, y) + Vector2.ONE * (folga + FOLGA_CALCA)
		if y < 0.47:
			r = Vector2(maxf(r.x, reta + folga), maxf(r.y, reta * 1.06 + folga))
		aneis.append(Anel.new(Vector3(x, corpo._y(y), 0.0), r.x, r.y, r.y,
			canela if y < 0.47 else coxa, 0.5 if y == y0 else 0.0))
	# Sem tampa: a boca do punho fica em cima do sapato.
	tubo(d, aneis, LADOS_MEMBRO_PERTO if corpo.detalhado else LADOS_MEMBRO_RUA,
		[faixa(cor, cel)], FORMA_MEMBRO)


## Raio da perna vestida na altura `y`, para quem prega coisa do lado da coxa.
static func raio_perna(a: Dictionary, y: float) -> Vector2:
	return raio_em(estacoes_perna(a, true), y) + Vector2.ONE * FOLGA_CALCA


## Gola que abraca o pescoco (gola alta, corta-vento).
static func gola_tubo(corpo: Corpo, d: Dictionary, a: Dictionary, y0: float, y1: float,
		folga: float, cor: Color, cel: Rect2) -> void:
	var gn := 1.0 + 0.45 * gordura(a)
	var aneis: Array = []
	for y: float in [y0, y1]:
		aneis.append(Anel.new(Vector3(0.0, corpo._y(y), 0.005), 0.050 * gn + folga,
			0.050 * gn + folga, 0.056 * gn + folga, Corpo.Osso.TORSO,
			0.5 if y == y0 else 0.0))
	tubo(d, aneis, LADOS_MEMBRO_PERTO if corpo.detalhado else LADOS_MEMBRO_RUA,
		[faixa(cor, cel)], FORMA_MEMBRO, null, faixa(cor.darkened(0.3), cel))
