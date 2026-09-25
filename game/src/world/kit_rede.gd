## A geometria da rede eletrica: poste, ferragem, cabo, ramal de casa e estai.
##
## Quem decide onde fica cada coisa e RedeEletrica (pura). Aqui so se desenha, e
## tudo entra por uma Obra: centenas de pecas pequenas por chunk, despejadas no
## balde uma vez so (ver Obra, o custo da copia do balde).
##
## O poste
## -------
## Poste DT de concreto afunilado, de 9 m (so baixa tensao) ou 10,5 m (com
## media). De cima para baixo, na ordem de qualquer rua de Minas:
##   10,1 m   cruzeta de madeira com tres isoladores de pino (media tensao);
##   8,5 m    armacao secundaria de tres roldanas ou o grampo do multiplexado;
##   6,6 m    braco da luminaria, sobre a rua;
##   6,0 m    os cabos de telefone e TV, com a sobra enrolada num poste ou outro.
## Um poste de media em cada cinco tem transformador. O fim de linha ganha estai.
##
## O cabo
## ------
## Catenaria de verdade: y = a cosh((x - x0) / a) + c entre os dois pontos de
## fixacao, com `a` (tracao horizontal sobre peso por metro) proprio de cada
## tipo de cabo. O fio de aluminio da media vai esticado, o multiplexado pesa e
## barriga mais, o ramal de casa barriga muito. Ponta mais alta que a outra (a
## ladeira) sai sozinha da formula: o ponto mais baixo desliza para o lado de
## baixo, como no cabo de verdade.
##
## O balanco ao vento e do shader (psx_surface, `modo_cabo`), e para ele cada
## vertice leva na UV2 a posicao no vao, a profundidade abaixo da corda, a flecha
## e a fase do vao. O vao inteiro balanca junto, como pendulo em volta da corda,
## com o periodo que a flecha dele pede. Ver `_uv2`.
class_name KitRede
extends RefCounted

const MAT_CABO := &"cabo"
## O vao em catenaria tem dois niveis de detalhe (ChunkManager, balde @longe).
## De perto, o tubo de seis lados e a helice do multiplexado. A partir de
## ALCANCE_PERTO, tres lados, metade dos segmentos e sem helice: o shader segura
## o cabo em um pixel de grossura, entao de longe ele continua la, e o que sai e
## triangulo que nao cabia no pixel. Era 16% da casca da cidade
## (tests/bancada_orcamento_chunk.gd, 25/09/2026).
const MAT_CABO_PERTO := &"cabo@perto"
const MAT_CABO_LONGE := &"cabo@longe"
const LADOS_LONGE := 3
## Os isoladores tambem: de perto os discos de louca, de longe um toco so. Nome
## proprio, e nao o metal_pintado@perto da fachada, para as duas malhas terem a
## mesma caixa e trocarem no mesmo ponto (o alcance mede ate o centro dela).
const MAT_LOUCA_PERTO := &"metal_pintado@perto_rede"
const MAT_LOUCA_LONGE := &"metal_pintado@longe_rede"
## `--rede-sem-lod`: tudo num balde so, como era. O par da bancada.
static var lod := not OS.get_cmdline_user_args().has("--rede-sem-lod")
## O concreto claro do meio-fio: o `concreto` de fachada e pardo, e o poste
## lia como de madeira.
const MAT_POSTE := &"meio_fio"
const MAT_FERRO := &"metal"
const MAT_PINTADO := &"metal_pintado"
const MAT_MADEIRA := &"tabua"

const ALTURA_MT := 10.5
const ALTURA_BT := 9.0

## Cruzeta: centro a 35 cm do topo, toda aberta para a rua (estrutura em beco).
## A fase de dentro fica em cima da guia, e nao da calcada: e ali, a 0,85 m da
## guia, que mora o estipe da palmeira imperial da avenida, e a fase atravessava
## o tronco a dez metros de altura.
const CRUZETA_ABAIXO := 0.35
const CRUZETA_DE := -0.15
const CRUZETA_ATE := 2.0
const ISOLADORES: Array[float] = [0.32, 1.06, 1.8]
const ISOLADOR_ALTO := 0.14

## Baixa tensao e telefone, altura no poste.
const BT_COM_MT := 8.45
const BT_SEM_MT := 7.75
const BT_PASSO := 0.28
const TEL_ALTURAS: Array[float] = [6.05, 5.8, 5.55]

## A lampada fica onde sempre ficou: 1,4 m para fora do poste, a 6,35 m. O
## facho, a poca de luz e a regua `luz` foram calibrados ai.
const LAMPADA_FORA := 1.4
const LAMPADA_ALTURA := 6.35

## Raio de cada cabo, em metro. Real, e nao engrossado para aparecer: quem
## segura o fio fino de longe e o shader, que nao deixa o raio cair abaixo de
## ~0,6 px (ver psx_surface, modo_cabo).
const R_MT := 0.0095
const R_BT_NU := 0.0085
const R_MULTIPLEX := 0.019
const R_TEL: Array[float] = [0.0075, 0.012, 0.0165]
const R_RAMAL := 0.0068
const R_ESTAI := 0.0065

## Parametro da catenaria (m). Flecha num vao de 32 m: a^-1 * 128 ~ 0,5 m para a
## media, 0,85 m para o multiplexado.
const A_MT := 260.0
const A_BT_NU := 200.0
const A_MULTIPLEX := 150.0
const A_TEL: Array[float] = [175.0, 160.0, 185.0]
const A_RAMAL := 42.0

const COR_ALUMINIO := Color(0.66, 0.68, 0.70)
const COR_PRETO := Color(0.075, 0.075, 0.08)
const COR_ACO := Color(0.46, 0.47, 0.48)
const COR_AMARELO := Color(0.88, 0.72, 0.12)
const COR_LOUCA := Color(0.52, 0.30, 0.22)
const COR_TRAFO := Color(0.50, 0.55, 0.53)
const COR_LUMINARIA := Color(0.58, 0.60, 0.60)

## Lados do tubo do cabo. Seis: de perto ele e redondo, e de longe tanto faz.
const LADOS := 6


# --- pontos de fixacao --------------------------------------------------------

static func altura(p: Dictionary) -> float:
	return ALTURA_MT if bool(p["mt"]) else ALTURA_BT


static func _no_poste(p: Dictionary, u: float, h: float) -> Vector3:
	return Vector3(p["pe"]) + Vector3(p["rua"]) * u + Vector3(0.0, h, 0.0)


## Onde cada cabo de um grupo prende no poste, em coordenada de mundo.
static func pontos(p: Dictionary, grupo: StringName) -> Array[Vector3]:
	var saida: Array[Vector3] = []
	match grupo:
		&"mt":
			if not bool(p["mt"]):
				return saida
			var h := ALTURA_MT - CRUZETA_ABAIXO + 0.055 + ISOLADOR_ALTO
			var cz := RedeEletrica.cruzeta(p)
			for u: float in ISOLADORES:
				saida.append(Vector3(p["pe"]) + cz * u + Vector3(0.0, h, 0.0))
		&"bt":
			var base := BT_COM_MT if bool(p["mt"]) else BT_SEM_MT
			if int(p["bt"]) == 1:
				for k in 3:
					saida.append(_no_poste(p, 0.21, base - BT_PASSO * float(k)))
			else:
				saida.append(_no_poste(p, 0.17, base - 0.2))
		&"tel":
			for k in clampi(int(p["tel"]), 1, 3):
				saida.append(_no_poste(p, 0.14, TEL_ALTURAS[k]))
	return saida


## Casa os pontos de dois postes pelo lado do vao: quem esta a esquerda de A
## vai para quem esta a esquerda de B. Sem isso o vao que atravessa a rua (a
## cruzeta de cada poste abre para a sua rua) cruzava as tres fases no meio.
static func _casar(a: Array[Vector3], b: Array[Vector3], de: Vector3, ate: Vector3) -> Array:
	var n := mini(a.size(), b.size())
	var dir := Vector3(ate.x - de.x, 0.0, ate.z - de.z).normalized()
	var lateral := Vector3.UP.cross(dir)
	var chave := func(p: Vector3) -> float:
		return (p - de).dot(lateral) * 10.0 + p.y
	var aa := a.duplicate()
	var bb := b.duplicate()
	aa.sort_custom(func(x: Vector3, y: Vector3) -> bool: return chave.call(x) < chave.call(y))
	bb.sort_custom(func(x: Vector3, y: Vector3) -> bool: return chave.call(x) < chave.call(y))
	var saida: Array = []
	# Quando um lado tem mais cabos (armacao de tres para multiplexado de um),
	# o de baixo do lado maior e o que segue.
	for k in n:
		saida.append([aa[aa.size() - n + k] if aa.size() > n else aa[k],
			bb[bb.size() - n + k] if bb.size() > n else bb[k]])
	return saida


# --- vao ----------------------------------------------------------------------

## Um vao entre dois postes, com todos os grupos que os dois tem.
static func vao(ob: Obra, v: Dictionary, origem: Vector3, registro: Array = []) -> void:
	var a: Dictionary = v["a"]
	var b: Dictionary = v["b"]
	var pa: Vector3 = a["pe"]
	var pb: Vector3 = b["pe"]
	var fase := _fase(pa, pb)
	var estica := esticamento(a, b)
	if bool(a["mt"]) and bool(b["mt"]):
		var k := 0
		for par: Array in _casar(pontos(a, &"mt"), pontos(b, &"mt"), pa, pb):
			cabo(ob, par[0] - origem, par[1] - origem, R_MT, A_MT * estica, COR_ALUMINIO,
				fposmod(fase + 0.07 * float(k), 1.0), false, registro)
			k += 1
	var bt_nu := int(a["bt"]) == 1 and int(b["bt"]) == 1
	var k_bt := 0
	for par: Array in _casar(pontos(a, &"bt"), pontos(b, &"bt"), pa, pb):
		if bt_nu:
			cabo(ob, par[0] - origem, par[1] - origem, R_BT_NU, A_BT_NU * estica, COR_ALUMINIO,
				fposmod(fase + 0.31 + 0.05 * float(k_bt), 1.0), false, registro)
		else:
			cabo(ob, par[0] - origem, par[1] - origem, R_MULTIPLEX, A_MULTIPLEX * estica, COR_PRETO,
				fposmod(fase + 0.31, 1.0), true, registro)
		k_bt += 1
	var k_tel := 0
	for par: Array in _casar(pontos(a, &"tel"), pontos(b, &"tel"), pa, pb):
		var info := cabo(ob, par[0] - origem, par[1] - origem, R_TEL[k_tel], A_TEL[k_tel] * estica,
			COR_PRETO, fposmod(fase + 0.53 + 0.11 * float(k_tel), 1.0), false, registro)
		# A caixa de emenda pendurada no meio do vao, num telefone em cada tres.
		if k_tel == clampi(int(a["tel"]), 1, 3) - 1 and _sorteio(pa + pb, 17) % 3 == 0:
			_caixa_de_emenda(ob, info, 0.38 + 0.2 * float(_sorteio(pa, 5) % 3) / 2.0)
		k_tel += 1


## Altura livre minima do cabo mais baixo sobre o chao (telefone sobre a rua).
const LIVRE_MINIMA := 4.9


## Quanto o vao tem de ser mais esticado que o normal para o telefone passar a
## LIVRE_MINIMA do chao. Na ladeira convexa o chao sobe no meio do vao e a
## barriga normal encostava a 3,5 m da calcada; a turma da rede estica o cabo
## (mais tracao, menos flecha), e e isso que se faz aqui, para todos os grupos
## do vao por igual. Plano: 1.
static func esticamento(a: Dictionary, b: Dictionary) -> float:
	var pa := pontos(a, &"tel")
	var pb := pontos(b, &"tel")
	if pa.is_empty() or pb.is_empty():
		return 1.0
	var de: Vector3 = pa[pa.size() - 1]
	var ate: Vector3 = pb[pb.size() - 1]
	var fator := 1.0
	for tentativa in 8:
		var cat := catenaria(de, ate, A_TEL[0] * fator, 10)
		var pior := 99.0
		for q: Vector3 in cat[0]:
			pior = minf(pior, q.y - KitModular.ALTURA_MEIO_FIO - Relevo.altura(q.x, q.z))
		if pior >= LIVRE_MINIMA:
			break
		fator *= 1.6
	return fator


## Fase do balanco do vao, de 0 a 1, pela posicao dos dois postes.
static func _fase(a: Vector3, b: Vector3) -> float:
	return float(_sorteio(a + b, 31) % 1000) / 1000.0


static func _sorteio(p: Vector3, sal: int) -> int:
	return MalhaUrbana._ruido(roundi(p.x * 10.0), roundi(p.z * 10.0), sal)


## Os pontos da catenaria de `de` a `ate` e a profundidade de cada um abaixo da
## corda. `param` e a tracao sobre o peso por metro.
static func catenaria(de: Vector3, ate: Vector3, param: float, segmentos: int) -> Array:
	var pts := PackedVector3Array()
	var prof := PackedFloat32Array()
	var h := Vector2(ate.x - de.x, ate.z - de.z)
	var comp := h.length()
	var dy := ate.y - de.y
	if comp < 0.05 or param <= 0.0:
		for i in segmentos + 1:
			pts.append(de.lerp(ate, float(i) / float(segmentos)))
			prof.append(0.0)
		return [pts, prof]
	var s := sinh(comp / (2.0 * param))
	var arg := dy / (2.0 * param * s)
	var x0 := comp * 0.5 - param * log(arg + sqrt(arg * arg + 1.0))
	var c := de.y - param * cosh(-x0 / param)
	var d := h / comp
	for i in segmentos + 1:
		var t := float(i) / float(segmentos)
		var x := t * comp
		var y := param * cosh((x - x0) / param) + c
		if i == 0:
			y = de.y
		elif i == segmentos:
			y = ate.y
		pts.append(Vector3(de.x + d.x * x, y, de.z + d.y * x))
		prof.append(maxf(0.0, lerpf(de.y, ate.y, t) - y))
	return [pts, prof]


## Um cabo em catenaria. Devolve {pts, prof, flecha, fase} para quem pendura
## coisa nele (caixa de emenda).
static func cabo(ob: Obra, de: Vector3, ate: Vector3, raio: float, param: float,
		cor: Color, fase: float, trancado: bool = false, registro: Array = [],
		tipo: StringName = &"vao") -> Dictionary:
	var comp := Vector2(ate.x - de.x, ate.z - de.z).length()
	var segmentos := clampi(ceili(comp / 1.6), 4, 24)
	var cat := catenaria(de, ate, param, segmentos)
	var pts: PackedVector3Array = cat[0]
	var prof: PackedFloat32Array = cat[1]
	var flecha := 0.0
	for p: float in prof:
		flecha = maxf(flecha, p)
	# Quem mede (tests/checar_fiacao.gd) recebe a linha de cada cabo.
	registro.append([pts, tipo])
	var uv2 := PackedVector2Array()
	for i in pts.size():
		uv2.append(_uv2(float(i) / float(segmentos), prof[i], flecha, fase))
	var mat := MAT_CABO_PERTO if lod else MAT_CABO
	_tubo(ob.malha(mat), pts, raio, cor, uv2)
	if lod:
		# A mesma curva com menos pontos e a mesma flecha: balanca junto.
		var seg_longe := clampi(ceili(comp / 3.2), 3, 12)
		var cat_longe := catenaria(de, ate, param, seg_longe)
		var pts_longe: PackedVector3Array = cat_longe[0]
		var prof_longe: PackedFloat32Array = cat_longe[1]
		var uv2_longe := PackedVector2Array()
		for i in pts_longe.size():
			uv2_longe.append(_uv2(float(i) / float(seg_longe), prof_longe[i], flecha, fase))
		_tubo(ob.malha(MAT_CABO_LONGE), pts_longe, raio, cor, uv2_longe, LADOS_LONGE)
	# O multiplexado e tres fases trancadas em volta do neutro: um fio fino em
	# helice por fora le como cabo trancado sem custar mais que um segundo tubo.
	if trancado:
		var helice := PackedVector3Array()
		var uvh := PackedVector2Array()
		var n := segmentos * 3
		var ref := Vector3.UP
		for i in n + 1:
			var t := float(i) / float(n)
			var f := t * float(segmentos)
			var i0 := mini(floori(f), segmentos - 1)
			var p := pts[i0].lerp(pts[i0 + 1], f - float(i0))
			var tan := (pts[i0 + 1] - pts[i0]).normalized()
			var nrm := ref.cross(tan).normalized()
			var bi := tan.cross(nrm)
			var ang := t * comp / 0.35 * TAU
			helice.append(p + (nrm * cos(ang) + bi * sin(ang)) * raio * 0.85)
			uvh.append(_uv2(t, lerpf(prof[i0], prof[i0 + 1], f - float(i0)), flecha, fase))
		_tubo(ob.malha(mat), helice, raio * 0.42, cor * 1.25, uvh, 3)
	return {"pts": pts, "prof": prof, "flecha": flecha, "fase": fase}


## O que o shader le para balancar o vertice. Inteiro e fracao juntos, para
## caber quatro numeros em dois:
##   x = t (0..1 ao longo do vao)  + floor(profundidade abaixo da corda em mm)
##   y = fase (0..1)               + floor(flecha do vao em mm)
## Profundidade zero (ponta, ou peca rigida) nao se mexe.
static func _uv2(t: float, profundidade: float, flecha: float, fase: float) -> Vector2:
	return Vector2(clampf(t, 0.0, 0.999) + floorf(profundidade * 1000.0),
		clampf(fase, 0.0, 0.999) + floorf(flecha * 1000.0))


## Tubo de `lados` faces pelos pontos, com normal radial (sombreia redondo). O
## alfa da cor leva o raio (em 5 cm), que o shader usa para nao deixar o cabo
## ficar mais fino que um pixel.
static func _tubo(m: ParedeVazada.Malha, pts: PackedVector3Array, raio: float, cor: Color,
		uv2: PackedVector2Array, lados: int = LADOS) -> void:
	if pts.size() < 2:
		return
	var c := Color(cor.r, cor.g, cor.b, clampf(raio / 0.05, 0.0, 1.0))
	var aneis: Array[PackedInt32Array] = []
	var normais: Array[PackedVector3Array] = []
	var anterior := Vector3.ZERO
	var andado := 0.0
	for i in pts.size():
		var tan: Vector3
		if i == 0:
			tan = pts[1] - pts[0]
		elif i == pts.size() - 1:
			tan = pts[i] - pts[i - 1]
		else:
			tan = pts[i + 1] - pts[i - 1]
		tan = tan.normalized()
		var ref := Vector3.UP if absf(tan.y) < 0.9 else Vector3.RIGHT
		var nrm := ref.cross(tan).normalized()
		var bi := tan.cross(nrm).normalized()
		if i > 0:
			andado += pts[i].distance_to(anterior)
		anterior = pts[i]
		var anel := PackedInt32Array()
		var ns := PackedVector3Array()
		for k in lados:
			var ang := TAU * float(k) / float(lados)
			var r := nrm * cos(ang) + bi * sin(ang)
			anel.append(m.vertice(pts[i] + r * raio, r, Vector2(andado * 0.5, float(k) / float(lados)),
				uv2[i] if i < uv2.size() else Vector2.ZERO, c))
			ns.append(r)
		aneis.append(anel)
		normais.append(ns)
	for i in pts.size() - 1:
		for k in lados:
			var k1 := (k + 1) % lados
			var face := (normais[i][k] + normais[i][k1]).normalized()
			m.quad(aneis[i][k], aneis[i][k1], aneis[i + 1][k1], aneis[i + 1][k], face)


## Peca reta em material de cabo que nao balanca (jumper, estai, luva).
static func _reto(ob: Obra, de: Vector3, ate: Vector3, raio: float, cor: Color,
		lados: int = 4) -> void:
	var pts := PackedVector3Array([de, ate])
	_tubo(ob.malha(MAT_CABO), pts, raio, cor, PackedVector2Array([Vector2.ZERO, Vector2.ZERO]),
		lados)


## Caixa de emenda optica pendurada no cabo de telefone, em `t` do vao. Ela
## balanca junto: os vertices levam a mesma UV2 do ponto do cabo onde prendem.
static func _caixa_de_emenda(ob: Obra, info: Dictionary, t: float) -> void:
	var pts: PackedVector3Array = info["pts"]
	var prof: PackedFloat32Array = info["prof"]
	var n := pts.size() - 1
	var f := t * float(n)
	var i0 := clampi(floori(f), 0, n - 1)
	var p := pts[i0].lerp(pts[i0 + 1], f - float(i0))
	var pr := lerpf(prof[i0], prof[i0 + 1], f - float(i0))
	var tan := (pts[i0 + 1] - pts[i0]).normalized()
	var uv := _uv2(t, pr, float(info["flecha"]), float(info["fase"]))
	var m := ob.malha(MAT_CABO)
	var inicio := m.v.size()
	var giro := atan2(tan.x, tan.z)
	ob.livre(MAT_CABO, p + Vector3(0.0, -0.11, 0.0), Vector3(0.14, 0.18, 0.46),
		Basis(Vector3.UP, giro), Color(0.1, 0.1, 0.1, 0.0))
	for k in range(inicio, m.v.size()):
		m.uv2[k] = uv


# --- poste --------------------------------------------------------------------

## O poste inteiro: corpo, ferragem de cada grupo que ele leva, luminaria,
## transformador, estai (se for fim de linha) e a colisao.
static func poste(ob: Obra, p: Dictionary, origem: Vector3, vaos: Array[Dictionary],
		colisao: Array[Dictionary]) -> void:
	var pe: Vector3 = Vector3(p["pe"]) - origem
	var rua: Vector3 = p["rua"]
	var h := altura(p)
	var dir := Vector3.UP.cross(rua).normalized()
	_corpo(ob, pe, rua, dir, h)
	colisao.append({"tamanho": Vector3(0.24, h, 0.24), "pos": pe + Vector3(0.0, h * 0.5, 0.0)})
	var local := p.duplicate()
	local["pe"] = pe

	if bool(p["mt"]):
		_cruzeta(ob, local, RedeEletrica.cruzeta(p))
	_ferragem_bt(ob, local, dir)
	_ferragem_tel(ob, local, dir)
	if bool(p["luz"]):
		_braco_de_luz(ob, pe, rua)
	if bool(p["mt"]) and not bool(p["esquina"]) and _sorteio(Vector3(p["pe"]), 71) % 5 == 0:
		_transformador(ob, local, dir)
	# Fim de linha: o unico vao puxa o poste para um lado so, e o estai segura.
	if vaos.size() == 1:
		var v: Dictionary = vaos[0]
		var outro: Vector3 = v["b"]["pe"] if RedeEletrica._mesmo(v["a"], p) else v["a"]["pe"]
		var aqui: Vector3 = p["pe"]
		var puxa := Vector3(outro.x - aqui.x, 0.0, outro.z - aqui.z).normalized()
		_estai(ob, pe, -puxa, h)


## Poste de luz fora da rede (a serpentina): corpo, luminaria e a colisao fica
## por conta de quem chama. `pe` e local do chunk, `rua` para onde o braco sai.
static func poste_de_luz(sup: Dictionary, pe: Vector3, rua: Vector3) -> void:
	var ob := Obra.new()
	var r := Vector3(rua.x, 0.0, rua.z).normalized()
	_corpo(ob, pe, r, Vector3.UP.cross(r).normalized(), ALTURA_BT)
	_braco_de_luz(ob, pe, r)
	ob.despejar(sup)


## Corpo DT afunilado, de 30x20 cm no pe a 14x11 no topo, com o encardido do
## respingo de chuva embaixo e a plaqueta de numero da concessionaria.
static func _corpo(ob: Obra, pe: Vector3, rua: Vector3, dir: Vector3, h: float) -> void:
	var m := ob.malha(MAT_POSTE)
	var base := Vector2(0.30, 0.20)
	var topo := Vector2(0.14, 0.11)
	# Dois lances: o de baixo encardido. A cor escurece de 0 a 0,7 m.
	var cortes: Array[float] = [-0.3, 0.0, 0.7, h]
	var cores: Array[Color] = [Color(0.5, 0.49, 0.46), Color(0.58, 0.57, 0.53),
		Color(0.8, 0.79, 0.76), Color(0.86, 0.85, 0.82)]
	for s in cortes.size() - 1:
		var y0 := cortes[s]
		var y1 := cortes[s + 1]
		var t0 := clampf(y0 / h, 0.0, 1.0)
		var t1 := clampf(y1 / h, 0.0, 1.0)
		var m0 := base.lerp(topo, t0) * 0.5
		var m1 := base.lerp(topo, t1) * 0.5
		var cantos0: Array[Vector3] = []
		var cantos1: Array[Vector3] = []
		for q: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]:
			cantos0.append(pe + rua * (q.x * m0.x) + dir * (q.y * m0.y) + Vector3(0.0, y0, 0.0))
			cantos1.append(pe + rua * (q.x * m1.x) + dir * (q.y * m1.y) + Vector3(0.0, y1, 0.0))
		for k in 4:
			var k1 := (k + 1) % 4
			var meio := (cantos0[k] + cantos0[k1]) * 0.5 - (pe + Vector3(0.0, y0, 0.0))
			var n := Vector3(meio.x, 0.0, meio.z).normalized()
			var larg := cantos0[k].distance_to(cantos0[k1])
			var a := m.vertice(cantos0[k], n, Vector2(0.0, y0 * 0.5), Vector2.ZERO, cores[s])
			var b := m.vertice(cantos0[k1], n, Vector2(larg * 0.5, y0 * 0.5), Vector2.ZERO, cores[s])
			var c := m.vertice(cantos1[k1], n, Vector2(larg * 0.5, y1 * 0.5), Vector2.ZERO, cores[s + 1])
			var d := m.vertice(cantos1[k], n, Vector2(0.0, y1 * 0.5), Vector2.ZERO, cores[s + 1])
			m.quad(a, b, c, d, n)
		if s == cortes.size() - 2:
			var ia := m.vertice(cantos1[0], Vector3.UP, Vector2.ZERO, Vector2.ZERO, cores[s + 1])
			var ib := m.vertice(cantos1[1], Vector3.UP, Vector2(0.1, 0.0), Vector2.ZERO, cores[s + 1])
			var ic := m.vertice(cantos1[2], Vector3.UP, Vector2(0.1, 0.1), Vector2.ZERO, cores[s + 1])
			var id := m.vertice(cantos1[3], Vector3.UP, Vector2(0.0, 0.1), Vector2.ZERO, cores[s + 1])
			m.quad(ia, ib, ic, id, Vector3.UP)
	# O furo do DT: a face estreita tem o vazado do duplo T. Um rebaixo escuro
	# de cada lado basta para a silhueta ler como poste de concessionaria.
	for lado: float in [1.0, -1.0]:
		var n := dir * lado
		var y0 := 1.2
		var y1 := h - 1.0
		var w0 := lerpf(base.x, topo.x, y0 / h) * 0.28
		var w1 := lerpf(base.x, topo.x, y1 / h) * 0.28
		# 8 mm a frente da face: a 3 mm o rebaixo piscava de longe em todo poste
		# da cidade (tests/bancada_coplanar.gd), e 8 mm ainda nao le como relevo.
		var p0 := pe + n * (lerpf(base.y, topo.y, y0 / h) * 0.5 + 0.008) + Vector3(0.0, y0, 0.0)
		var p1 := pe + n * (lerpf(base.y, topo.y, y1 / h) * 0.5 + 0.008) + Vector3(0.0, y1, 0.0)
		var escuro := Color(0.42, 0.41, 0.39)
		var a := m.vertice(p0 - rua * w0, n, Vector2.ZERO, Vector2.ZERO, escuro)
		var b := m.vertice(p0 + rua * w0, n, Vector2(0.1, 0.0), Vector2.ZERO, escuro)
		var c := m.vertice(p1 + rua * w1, n, Vector2(0.1, 3.0), Vector2.ZERO, escuro)
		var d := m.vertice(p1 - rua * w1, n, Vector2(0.0, 3.0), Vector2.ZERO, escuro)
		m.quad(a, b, c, d, n)
	# Plaqueta de numero, virada para a calcada (o lado de quem anda).
	ob.livre(MAT_PINTADO, pe - rua * (lerpf(base.x, topo.x, 2.3 / h) * 0.5 + 0.006)
		+ Vector3(0.0, 2.3, 0.0), Vector3(0.012, 0.2, 0.13),
		Basis(Vector3.UP, atan2(rua.x, rua.z) + PI * 0.5), Color(0.9, 0.84, 0.3))


static func _giro(v: Vector3) -> float:
	return atan2(v.x, v.z)


## Cruzeta de madeira, duas maos francesas de ferro e os tres isoladores.
static func _cruzeta(ob: Obra, p: Dictionary, cz: Vector3) -> void:
	var rua := cz
	var dir := Vector3.UP.cross(cz).normalized()
	p = p.duplicate()
	p["rua"] = cz
	var h := ALTURA_MT - CRUZETA_ABAIXO
	var meio := (CRUZETA_DE + CRUZETA_ATE) * 0.5
	var comp := CRUZETA_ATE - CRUZETA_DE
	# Encostada na face do poste do lado da linha, como e aparafusada.
	var encosto := dir * 0.1
	ob.livre(MAT_MADEIRA, _no_poste(p, meio, h) + encosto, Vector3(0.09, 0.11, comp),
		Basis(Vector3.UP, _giro(rua)), Color(0.55, 0.5, 0.44))
	for u: float in [CRUZETA_DE + 0.25, CRUZETA_ATE - 0.45]:
		var de := _no_poste(p, 0.0, h - 0.62) + encosto
		var ate := _no_poste(p, u, h - 0.05) + encosto
		_barra(ob, de, ate, 0.03, COR_ACO)
	var louca := MAT_LOUCA_PERTO if lod else MAT_PINTADO
	for u: float in ISOLADORES:
		var base := _no_poste(p, u, h + 0.055) + encosto * 0.0
		ob.cilindro(louca, base, 0.022, 0.05, COR_ACO, 6)
		ob.cilindro(louca, base + Vector3(0.0, 0.03, 0.0), 0.055, 0.03, COR_LOUCA, 8)
		ob.cilindro(louca, base + Vector3(0.0, 0.065, 0.0), 0.045, 0.03, COR_LOUCA, 8)
		ob.cilindro(louca, base + Vector3(0.0, 0.1, 0.0), 0.032, 0.04, COR_LOUCA, 8)
		if lod:
			# De longe o isolador e um ponto de 3 px em cima da cruzeta.
			ob.cilindro(MAT_LOUCA_LONGE, base + Vector3(0.0, 0.03, 0.0), 0.05, 0.11,
				COR_LOUCA, 4)


## Barra reta de ferro entre dois pontos (mao francesa, braco de luz).
static func _barra(ob: Obra, de: Vector3, ate: Vector3, grossura: float, cor: Color) -> void:
	var eixo := ate - de
	var comp := eixo.length()
	if comp < 0.01:
		return
	var b := Basis(Quaternion(Vector3.UP, eixo / comp))
	ob.livre(MAT_FERRO, (de + ate) * 0.5, Vector3(grossura, comp, grossura), b, cor)


## Armacao secundaria (tres roldanas na vertical) ou o grampo do multiplexado.
static func _ferragem_bt(ob: Obra, p: Dictionary, _dir: Vector3) -> void:
	var rua: Vector3 = p["rua"]
	var base := BT_COM_MT if bool(p["mt"]) else BT_SEM_MT
	var giro := _giro(rua)
	if int(p["bt"]) == 1:
		ob.livre(MAT_FERRO, _no_poste(p, 0.1, base - BT_PASSO), Vector3(0.05, BT_PASSO * 2.0 + 0.25,
			0.012), Basis(Vector3.UP, giro + PI * 0.5), COR_ACO)
		for k in 3:
			var c := _no_poste(p, 0.17, base - BT_PASSO * float(k) - 0.045)
			ob.cilindro(MAT_LOUCA_PERTO if lod else MAT_PINTADO, c, 0.042, 0.09,
				COR_LOUCA.lightened(0.15), 8)
			if lod:
				ob.cilindro(MAT_LOUCA_LONGE, c, 0.042, 0.09, COR_LOUCA.lightened(0.15), 4)
	else:
		ob.livre(MAT_FERRO, _no_poste(p, 0.11, base - 0.2), Vector3(0.05, 0.12, 0.09),
			Basis(Vector3.UP, giro), COR_ACO)


## Os grampos do telefone e, num poste em cada quatro, a sobra de cabo enrolada
## (a reserva tecnica, o rolo preto que todo poste de cidade tem).
static func _ferragem_tel(ob: Obra, p: Dictionary, dir: Vector3) -> void:
	var rua: Vector3 = p["rua"]
	var giro := _giro(rua)
	for k in clampi(int(p["tel"]), 1, 3):
		ob.livre(MAT_FERRO, _no_poste(p, 0.1, TEL_ALTURAS[k]), Vector3(0.04, 0.05, 0.07),
			Basis(Vector3.UP, giro), COR_ACO)
	if _sorteio(Vector3(p["pe"]) + Vector3(0.3, 0.0, 0.0), 43) % 4 == 0:
		var centro := _no_poste(p, 0.2, 5.05)
		var anel := PackedVector3Array()
		var n := 14
		var raio := 0.34
		for i in n + 1:
			var a := TAU * float(i) / float(n)
			anel.append(centro + dir * (cos(a) * raio) + Vector3(0.0, sin(a) * raio * 0.8, 0.0)
				+ rua * (0.02 * sin(a * 3.0)))
		var uv := PackedVector2Array()
		uv.resize(anel.size())
		_tubo(ob.malha(MAT_CABO), anel, 0.012, COR_PRETO, uv, 4)
		# A volta de dentro, desencontrada: rolo de verdade nao e um aro so.
		var anel2 := PackedVector3Array()
		for i in n + 1:
			var a := TAU * float(i) / float(n) + 0.4
			anel2.append(centro + dir * (cos(a) * raio * 0.9) + Vector3(0.0, sin(a) * raio * 0.72 - 0.03,
				0.0) + rua * 0.035)
		_tubo(ob.malha(MAT_CABO), anel2, 0.011, COR_PRETO, uv, 4)


## Braco da luminaria e a luminaria, sobre a rua. A luz em si e o no Lampada.
static func _braco_de_luz(ob: Obra, pe: Vector3, rua: Vector3) -> void:
	var sai := pe + rua * 0.1 + Vector3(0.0, 6.55, 0.0)
	var cotovelo := pe + rua * 0.75 + Vector3(0.0, 6.75, 0.0)
	var ponta := pe + rua * (LAMPADA_FORA - 0.2) + Vector3(0.0, 6.62, 0.0)
	_barra(ob, sai, cotovelo, 0.05, COR_ACO)
	_barra(ob, cotovelo, ponta, 0.05, COR_ACO)
	_barra(ob, pe + rua * 0.1 + Vector3(0.0, 6.2, 0.0), cotovelo, 0.03, COR_ACO)
	ob.livre(MAT_FERRO, pe + rua * 0.12 + Vector3(0.0, 6.4, 0.0), Vector3(0.18, 0.46, 0.04),
		Basis(Vector3.UP, _giro(rua) + PI * 0.5), COR_ACO)
	# Carcaca: corpo e tampa, levemente para cima como luminaria de sodio.
	var b := Basis(Vector3.UP, _giro(rua)) * Basis(Vector3.RIGHT, -0.09)
	var centro := pe + rua * LAMPADA_FORA + Vector3(0.0, LAMPADA_ALTURA + 0.16, 0.0)
	ob.livre(MAT_PINTADO, centro, Vector3(0.28, 0.1, 0.62), b, COR_LUMINARIA)
	ob.livre(MAT_PINTADO, centro + Vector3(0.0, 0.075, 0.0) - rua * 0.03,
		Vector3(0.22, 0.05, 0.5), b, COR_LUMINARIA.darkened(0.12))


## Transformador pendurado no poste, com os tres jumpers da media descendo das
## fases e os dois da baixa indo para a armacao.
static func _transformador(ob: Obra, p: Dictionary, dir: Vector3) -> void:
	var pe: Vector3 = p["pe"]
	var rua: Vector3 = p["rua"]
	var base := pe + dir * 0.46 + rua * 0.12 + Vector3(0.0, BT_COM_MT + 0.18, 0.0)
	# Suporte: duas barras abracando o poste.
	for y: float in [0.25, 0.7]:
		ob.livre(MAT_FERRO, pe + dir * 0.2 + rua * 0.12 + Vector3(0.0, BT_COM_MT + 0.18 + y, 0.0),
			Vector3(0.05, 0.05, 0.4), Basis(Vector3.UP, _giro(dir)), COR_ACO)
	ob.cilindro(MAT_PINTADO, base, 0.28, 0.82, COR_TRAFO, 12)
	ob.cilindro(MAT_PINTADO, base + Vector3(0.0, 0.82, 0.0), 0.3, 0.035, COR_TRAFO.darkened(0.1), 12)
	# Aletas de radiador dos dois lados.
	for lado: float in [1.0, -1.0]:
		ob.livre(MAT_PINTADO, base + rua * (0.29 * lado) + Vector3(0.0, 0.4, 0.0),
			Vector3(0.05, 0.6, 0.34), Basis(Vector3.UP, _giro(rua)), COR_TRAFO.darkened(0.08))
	var fases := pontos(p, &"mt")
	for k in 3:
		var bucha := base + Vector3(0.0, 0.855, 0.0) + dir * (-0.12 + 0.12 * float(k))
		ob.cilindro(MAT_PINTADO, bucha, 0.025, 0.14, COR_LOUCA, 6)
		# Chave fusivel na cruzeta, e o jumper descendo dela para a bucha.
		var chave := fases[k] - Vector3(0.0, 0.35, 0.0) + dir * 0.12
		ob.livre(MAT_PINTADO, chave, Vector3(0.04, 0.3, 0.04),
			Basis(Vector3.RIGHT, 0.35), COR_LOUCA.lightened(0.2))
		_reto(ob, fases[k], chave + Vector3(0.0, 0.15, 0.0), 0.006, COR_ALUMINIO)
		_reto(ob, chave - Vector3(0.0, 0.15, 0.0), bucha + Vector3(0.0, 0.14, 0.0), 0.006,
			COR_ALUMINIO)
	var baixa := pontos(p, &"bt")
	for k in mini(2, baixa.size()):
		var saida_bt := base + rua * 0.24 + Vector3(0.0, 0.62 - 0.2 * float(k), 0.0)
		_reto(ob, saida_bt, baixa[k], 0.008, COR_PRETO)


## Estai: cabo de aco do alto do poste ate a ancora na calcada, com a luva
## amarela nos dois metros de baixo (para ninguem tropecar nele de noite).
static func _estai(ob: Obra, pe: Vector3, para: Vector3, h: float) -> void:
	var topo := pe + Vector3(0.0, h - 0.9, 0.0) - para * 0.06
	var ancora := pe + para * 3.1
	ancora.y = pe.y - 0.02
	_reto(ob, topo, ancora, R_ESTAI, COR_ACO)
	var luva := ancora.lerp(topo, 2.0 / topo.distance_to(ancora))
	_reto(ob, ancora + (topo - ancora).normalized() * 0.05, luva, 0.024, COR_AMARELO, 6)
	ob.livre(MAT_FERRO, ancora + Vector3(0.0, 0.03, 0.0), Vector3(0.16, 0.06, 0.16), Basis(),
		COR_ACO.darkened(0.3))


# --- ramal de casa ------------------------------------------------------------

## Ramal de ligacao do poste `p` ate a fachada. `fachada` e o ponto de fixacao
## na parede (local do chunk, altura absoluta), `normal` a direcao da rua.
##
## Casa terrea prende num pontalete (o cano de aco acima do telhado); sobrado,
## na armacao da parede entre os andares. Casa recuada recebe o poste padrao na
## divisa com a calcada, e o fio corre dali para a casa por cima do jardim —
## direto da rua ele passaria rente a fachada do vizinho.
static func ramal(ob: Obra, p: Dictionary, origem: Vector3, fachada: Vector3,
		normal: Vector3, andares: int, recuo: float, divisa: Vector3,
		registro: Array = [], chegada: Vector3 = Vector3.INF) -> void:
	var no_poste := ponto_do_ramal(p, fachada + origem) - origem
	var ponto_casa: Vector3
	if recuo > 0.6:
		# Poste padrao: concreto de 12 cm, caixa do medidor a 1,4 m, e o fio
		# chegando a 4,6 m.
		var pe := divisa - normal * 0.25
		ob.livre(MAT_POSTE, pe + Vector3(0.0, 2.4, 0.0), Vector3(0.13, 4.8, 0.13), Basis(),
			Color(0.8, 0.79, 0.76))
		ob.livre(MAT_PINTADO, pe + normal * 0.1 + Vector3(0.0, 1.45, 0.0), Vector3(0.3, 0.42, 0.14),
			Basis(Vector3.UP, _giro(normal)), Color(0.72, 0.74, 0.72))
		ponto_casa = pe + Vector3(0.0, 4.6, 0.0) + normal * 0.07
		var na_parede := fachada + Vector3(0.0, 3.1 if andares < 2 else 3.4, 0.0)
		cabo(ob, ponto_casa, na_parede, R_RAMAL, A_RAMAL * 0.6, COR_PRETO,
			_fase(ponto_casa, na_parede), false, registro, &"ramal")
	elif andares <= 2:
		# Pontalete: o cano sobe pela fachada e passa do beiral um metro e pouco.
		# Preso na parede, o fio subia ingreme para o poste logo acima da fixacao
		# e furava o beiral e a sacada da propria casa.
		var topo := pontalete(andares)
		var cano := fachada + normal * 0.07
		_barra(ob, cano + Vector3(0.0, topo - 2.1, 0.0), cano + Vector3(0.0, topo + 0.1, 0.0), 0.035,
			COR_ACO)
		ob.livre(MAT_FERRO, cano + Vector3(0.0, topo, 0.0) + normal * 0.03, Vector3(0.06, 0.05, 0.08),
			Basis(Vector3.UP, _giro(normal)), COR_ACO)
		ponto_casa = cano + Vector3(0.0, topo, 0.0) + normal * 0.05
	else:
		# Predio alto: armacao com braco de ferro saindo da parede, que leva a
		# fixacao para alem da sacada. Presa rente, o fio subia para o poste pela
		# beirada do telhadinho da sacada do primeiro andar.
		var h := chegada.y - fachada.y if chegada != Vector3.INF else PAREDE_ALTA
		var na_parede := fachada + normal * 0.04 + Vector3(0.0, h, 0.0)
		ponto_casa = na_parede + normal * (BRACO_PAREDE - 0.04)
		_barra(ob, na_parede, ponto_casa, 0.04, COR_ACO)
		_barra(ob, na_parede - Vector3(0.0, 0.55, 0.0), ponto_casa - normal * 0.1, 0.03, COR_ACO)
		ob.livre(MAT_FERRO, na_parede, Vector3(0.14, 0.7, 0.03),
			Basis(Vector3.UP, _giro(normal)), COR_ACO)
	cabo(ob, no_poste, ponto_casa, R_RAMAL, A_RAMAL, COR_PRETO, _fase(no_poste, ponto_casa),
		false, registro, &"ramal")


## Onde o ramal sai do poste: na altura da baixa, do lado de onde a casa esta.
## Preso na face da rua, o fio da casa de tras passava por dentro do poste.
static func ponto_do_ramal(p: Dictionary, casa: Vector3) -> Vector3:
	var baixa := pontos(p, &"bt")
	var pe: Vector3 = p["pe"]
	var y: float = baixa[baixa.size() - 1].y - 0.12
	var para := Vector3(casa.x - pe.x, 0.0, casa.z - pe.z).normalized()
	return Vector3(pe.x, y, pe.z) + para * 0.16


## Fixacao na parede do predio de tres andares ou mais: acima do guarda-corpo da
## sacada do primeiro andar (4,1 m) e da marquise da loja. A 3,45 m o fio subia
## para o poste por dentro da sacada.
const PAREDE_ALTA := 4.35
## Quanto o braco da armacao sai da parede do predio alto.
const BRACO_PAREDE := 1.05


## Altura do topo do pontalete: um metro e pouco acima da cobertura.
static func pontalete(andares: int) -> float:
	return float(andares) * KitModular.ALTURA_ANDAR + 1.25


# --- poda ---------------------------------------------------------------------

## Os segmentos do cabo mais BAIXO de cada vao que passa sobre o chunk, em
## coordenada local e na altura do chao plano (a arvore e desenhada antes do
## relevo assentar, e sobe com ele). A arvore corta em V o que fica perto.
static func faixas_de_poda(cx: int, cz: int) -> PackedVector3Array:
	var saida := PackedVector3Array()
	var origem := Vector3(cx * RedeEletrica.TAM, 0.0, cz * RedeEletrica.TAM)
	for v: Dictionary in RedeEletrica.vaos_perto(cx, cz):
		var a: Dictionary = v["a"]
		var b: Dictionary = v["b"]
		var pa := pontos(a, &"tel")
		var pb := pontos(b, &"tel")
		if pa.is_empty() or pb.is_empty():
			continue
		var de: Vector3 = pa[pa.size() - 1]
		var ate: Vector3 = pb[pb.size() - 1]
		var cat := catenaria(de, ate, A_TEL[0] * esticamento(a, b), 8)
		var pts: PackedVector3Array = cat[0]
		for i in pts.size() - 1:
			for q: Vector3 in [pts[i], pts[i + 1]]:
				saida.append(q - origem - Vector3(0.0, Relevo.altura(q.x, q.z), 0.0))
	return saida


## A conta do corte (o V em volta do fio) mora em PodaEmV, sem dependencia:
## a arvore usa ela e nao pode arrastar a rede inteira junto.
