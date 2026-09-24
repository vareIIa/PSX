## O painel do carro: corpo esculpido, pala e cluster, centro com difusores,
## toca-fitas e ar, porta-trecos com a tomada, porta-luvas, friso de madeira,
## coluna de direcao com alavancas e chave, e os pedais.
##
## Tudo e colocado a partir de TRES medidas da cabine: o topo do painel
## (`topo`), a borda dele (`lip_z`) e o corta-fogo (`z_frente`). O perfil do
## painel sai delas; cada peca depois pergunta ao perfil onde a face esta na
## altura em que ela mora (`face`), e nunca chuta um z. Chutar z foi o que fez o
## painel antigo encostar no para-brisa em um carro e boiar a tres centimetros da
## face em outro.
class_name CabinePainel
extends RefCounted

## Inclinacao do cluster para tras, para os mostradores olharem para o olho.
const CLUSTER_INCLINACAO := 6.0
## Quanto o plano dos mostradores fica a frente da borda do painel.
##
## Com 1,2 cm o topo dos mostradores (inclinado para tras) entrava atras da
## borda arredondada do painel, que cortava os dois grandes numa faixa reta na
## altura do 40 e do 160. Mais que 3 cm e a aba da pala encosta no aro do
## volante, que passa a 1 cm dela.
const CLUSTER_AVANCO := 0.028
## Meia largura do painel de instrumentos e da pala por cima dele.
const CLUSTER_MEIA := 0.215
const PALA_MEIA := 0.228

## Os mostradores, no plano do cluster (x, y a partir do centro, raio).
const MOSTRADORES := {
	&"velocidade": Vector3(-0.074, 0.010, 0.054),
	&"giro": Vector3(0.074, 0.010, 0.054),
	&"combustivel": Vector3(-0.172, -0.010, 0.029),
	&"temperatura": Vector3(0.172, -0.010, 0.029),
}

## A altura de cada faixa do centro, medida para baixo do topo dele. Vem da
## frente de verdade das pecas: o radio e DIN (178 x 50 mm).
const CENTRO_DIFUSOR := 0.037
const CENTRO_RADIO := 0.099
const CENTRO_AR := 0.160
const CENTRO_CINZEIRO := 0.210
const CENTRO_ALTURA := 0.235
const RADIO_MEIA := Vector2(0.089, 0.025)


static func montar(it: CabineInterior) -> void:
	var p := _perfil(it)
	it.g["_perfil"] = p
	_corpo(it, p)
	_cluster(it, p)
	_centro(it, p)
	_porta_trecos(it)
	_difusores_laterais(it, p)
	_porta_luvas(it, p)
	_friso(it, p)
	_coluna(it)
	_pedais(it, p)


# --- o perfil ---------------------------------------------------------------

## A secao do painel em (z, y), do para-brisa ate o corta-fogo, passando pela
## borda arredondada, pela face e pelo joelho. Cada ponto tem a sua cor: o topo
## escuro contra o reflexo no vidro, a face cor de camurca.
static func _perfil(it: CabineInterior) -> Dictionary:
	var g := it.g
	var topo: float = g["topo"]
	var zl: float = g["lip_z"]
	var zf: float = g["z_frente"]
	var piso: float = g["piso"]
	var yb := maxf(piso + 0.40, topo - 0.29)
	var vidro: Callable = g["vidro"]
	var yg := maxf(topo, float(g["y_vidro"]) + 0.004)
	var zg := float(vidro.call(yg)) + 0.02
	var pts: Array[Vector2] = []
	var cores: Array = []
	var topo_c := CabineInterior.COR_TOPO
	var face_c := CabineInterior.COR_FACE
	var baixo_c := CabineInterior.COR_BAIXO
	pts.append(Vector2(zg, yg))
	cores.append(topo_c)
	for t: float in [0.3, 0.62]:
		pts.append(Vector2(lerpf(zg, zl, t), lerpf(yg, topo, t) + 0.004 + 0.006 * t))
		cores.append(topo_c)
	pts.append(Vector2(zl - 0.05, topo + 0.008))
	cores.append(topo_c)
	# A borda: um quarto de volta de 24 mm, do topo para a face.
	var r := 0.024
	var c := Vector2(zl - r, topo + 0.008 - r)
	var i_borda := pts.size()
	for graus: float in [72.0, 48.0, 24.0, 0.0, -22.0]:
		var a := deg_to_rad(graus)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
		cores.append(topo_c.lerp(face_c, clampf((60.0 - graus) / 60.0, 0.0, 1.0)))
	pts.append(Vector2(zl - 0.006, topo - 0.075))
	cores.append(face_c)
	pts.append(Vector2(zl - 0.013, topo - 0.125))
	cores.append(face_c)
	pts.append(Vector2(zl - 0.019, topo - 0.16))
	cores.append(face_c.lerp(baixo_c, 0.5))
	# O joelho: a face recua para dar lugar a perna.
	pts.append(Vector2(zl - 0.024, yb + 0.06))
	cores.append(baixo_c)
	pts.append(Vector2(zl - 0.031, yb + 0.027))
	cores.append(baixo_c)
	pts.append(Vector2(zl - 0.047, yb + 0.007))
	cores.append(baixo_c)
	pts.append(Vector2(zl - 0.072, yb))
	cores.append(baixo_c)
	var i_joelho := pts.size() - 1
	pts.append(Vector2(lerpf(zl - 0.072, zf, 0.5), yb - 0.02))
	cores.append(baixo_c.darkened(0.3))
	pts.append(Vector2(zf + 0.01, yb - 0.035))
	cores.append(baixo_c.darkened(0.4))
	return {"pts": pts, "cores": cores, "i_face": i_borda + 2, "i_joelho": i_joelho,
		"yb": yb}


## A face do painel na altura `y`: o z dela e a normal (para o motorista).
static func face(p: Dictionary, y: float) -> Dictionary:
	var pts: Array[Vector2] = p["pts"]
	var i0: int = p["i_face"]
	var i1: int = p["i_joelho"]
	for k in range(i0, i1):
		var a := pts[k]
		var b := pts[k + 1]
		if y <= a.y and y >= b.y:
			var t := (a.y - y) / maxf(a.y - b.y, 1e-5)
			var z := lerpf(a.x, b.x, t)
			var d := b - a
			var n := Vector3(0.0, -d.x, d.y).normalized()
			if n.z < 0.0:
				n = -n
			return {"z": z, "n": n}
	var ult := pts[i1]
	return {"z": ult.x, "n": Vector3.BACK}


## Um ponto NA face, `fora` metros para o motorista, e a base da face nele.
static func na_face(p: Dictionary, x: float, y: float, fora: float) -> Transform3D:
	var f := face(p, y)
	var n: Vector3 = f["n"]
	return Transform3D(CabineInterior.base_olhando(n),
		Vector3(x, y, float(f["z"])) + n * fora)


# --- corpo ------------------------------------------------------------------

static func _corpo(it: CabineInterior, p: Dictionary) -> void:
	var pts: Array[Vector2] = p["pts"]
	var cores: Array = p["cores"]
	var linhas: Array = []
	var meias: Array[float] = []
	var colunas := 13
	for k in pts.size():
		var q := pts[k]
		var meia := it.parede(q.y, q.y, q.x) - 0.012
		meias.append(meia)
		var linha := PackedVector3Array()
		for j in colunas:
			var u := lerpf(-1.0, 1.0, float(j) / float(colunas - 1))
			linha.append(Vector3(u * meia, q.y, q.x))
		linhas.append(linha)
	var topo: float = it.g["topo"]
	var zl: float = it.g["lip_z"]
	it.m(&"plastico").grade_de_pontos(linhas, CabineInterior.COR_FACE,
		Vector3(0.0, topo - 0.12, zl - 0.2), cores)
	# As pontas, contra a porta.
	for s: float in [-1.0, 1.0]:
		var tampa := PackedVector3Array()
		for k in pts.size():
			tampa.append(Vector3(s * meias[k], pts[k].y, pts[k].x))
		it.m(&"plastico").poligono(tampa, Vector3(s, 0.0, 0.0),
			CabineInterior.COR_BAIXO)


# --- cluster ----------------------------------------------------------------

## O centro do cluster. O painel antigo o punha na altura do capo mais 7,5 cm;
## isso continua valendo, a nao ser quando o olho esta perto demais (Fusca), em
## que a pala subiria na frente da estrada.
static func centro_do_cluster(it: CabineInterior) -> Vector3:
	var c: Vector3 = it.g["cluster"]
	var olho: Vector3 = it.g["olho"]
	return Vector3(c.x, minf(c.y, olho.y - 0.145), float(it.g["lip_z"]) + CLUSTER_AVANCO)


static func _cluster(it: CabineInterior, p: Dictionary) -> void:
	var c := centro_do_cluster(it)
	var olho: Vector3 = it.g["olho"]
	var topo: float = it.g["topo"]
	var zl: float = it.g["lip_z"]
	var base := Basis(Vector3.RIGHT, deg_to_rad(-CLUSTER_INCLINACAO))
	var xf := Transform3D(base, c)

	# A placa onde os mostradores assentam, escura, e a moldura em volta.
	var pl := it.m(&"plastico")
	pl.xf = xf
	pl.caixa(Vector3(0.0, -0.004, -0.024), Vector3(CLUSTER_MEIA, 0.080, 0.012), 0.010,
		CabineInterior.COR_PECA)
	pl.xf = Transform3D.IDENTITY

	# A pala: da superficie de cima do painel ate a aba sobre os mostradores.
	var alto := minf(c.y + 0.100, olho.y - 0.05)
	var za := c.z
	var perfil: Array[Vector2] = [
		Vector2(zl - 0.085, topo + 0.004),
		Vector2(zl - 0.050, lerpf(topo, alto, 0.8)),
		Vector2(za - 0.024, alto),
		Vector2(za + 0.012, alto - 0.006),
		Vector2(za + 0.030, alto - 0.018),
		Vector2(za + 0.026, alto - 0.028),
		Vector2(za - 0.006, alto - 0.030),
		Vector2(za - 0.034, alto - 0.032),
	]
	var colunas := 17
	var linhas: Array = []
	for k in perfil.size():
		var q := perfil[k]
		var linha := PackedVector3Array()
		for j in colunas:
			var u := lerpf(-1.0, 1.0, float(j) / float(colunas - 1))
			# Nas pontas a pala desce e recua ate morrer no painel.
			var u4 := pow(absf(u), 4.0)
			var z := zl - 0.085 + (q.x - (zl - 0.085)) * (1.0 - 0.75 * u4)
			var y := topo + (q.y - topo) * (1.0 - 0.55 * pow(absf(u), 6.0))
			linha.append(Vector3(c.x + u * PALA_MEIA, y, z))
		linhas.append(linha)
	var miolo := Vector3(c.x, alto - 0.016, za - 0.002)
	pl.grade_de_pontos(linhas, CabineInterior.COR_TOPO,
		func(k: int, j: int) -> Vector3:
			var u := lerpf(-1.0, 1.0, float(j) / float(colunas - 1))
			var q: Vector3 = (linhas[k] as PackedVector3Array)[j]
			return Vector3(q.x, lerpf(miolo.y, topo, pow(absf(u), 6.0) * 0.5),
				lerpf(miolo.z, zl - 0.06, pow(absf(u), 4.0))))
	for s: float in [-1.0, 1.0]:
		var tampa := PackedVector3Array()
		var j := 0 if s < 0.0 else colunas - 1
		for k in perfil.size():
			tampa.append((linhas[k] as PackedVector3Array)[j])
		pl.poligono(tampa, Vector3(s, 0.0, 0.0), CabineInterior.COR_TOPO)

	# Os mostradores, no plano do cluster: face impressa, parede do copo,
	# aro cromado, lente e ponteiro.
	var face_z := -0.011
	for nome: StringName in MOSTRADORES:
		var d: Vector3 = MOSTRADORES[nome]
		var r := d.z
		var centro := Vector3(d.x, d.y, face_z)
		var regiao: Rect2 = _regiao_mostrador(nome)
		var frac := 252.0 / 256.0 if r > 0.04 else 125.0 / 128.0
		it.m(&"impresso").disco(xf * Transform3D(Basis(), centro), r,
			ImpressosCabine.uv(regiao), Color(0.03, 0.03, 0.03, 1.0), 64, frac)
		# O copo: a parede de dentro, do fundo ate o aro.
		pl.torno(xf * Transform3D(Basis(), Vector3(d.x, d.y, 0.0)), [
			Vector2(r + 0.0004, face_z - 0.001), Vector2(r + 0.0004, 0.002)],
			Color(0.035, 0.034, 0.034, 0.6), 64)
		# O aro: plastico preto acetinado, com um filete cromado na boca.
		var aro_xf := xf * Transform3D(Basis(), Vector3(d.x, d.y, 0.0))
		pl.torno(aro_xf, [
			Vector2(r + 0.0012, 0.0036), Vector2(r + 0.0024, 0.0046),
			Vector2(r + 0.0040, 0.0044), Vector2(r + 0.0052, 0.0020),
			Vector2(r + 0.0056, -0.012)], Color(0.035, 0.034, 0.034, 0.35), 64)
		it.m(&"metal").torno(aro_xf, [
			Vector2(r - 0.0002, 0.0008), Vector2(r + 0.0002, 0.0034),
			Vector2(r + 0.0010, 0.0040), Vector2(r + 0.0016, 0.0036)],
			CabineInterior.COR_CROMO, 64)
		it.m(&"lente").torno(xf * Transform3D(Basis(), Vector3(d.x, d.y, 0.0)), [
			Vector2(0.0, 0.0060), Vector2(r * 0.5, 0.0056), Vector2(r + 0.003, 0.0044)],
			Color.WHITE, 48)
		var agulha := r * (0.88 if r > 0.04 else 0.82)
		var pivo_xf := xf * Transform3D(Basis(), Vector3(d.x, d.y, face_z + 0.0035))
		it.pivo(String(nome).capitalize(), pivo_xf,
			func() -> void: _ponteiro(it, agulha, r))
		# O miolo preto que prende o ponteiro.
		pl.torno(pivo_xf, [Vector2(0.0, 0.0046), Vector2(r * 0.12, 0.0040),
			Vector2(r * 0.19, 0.0014), Vector2(r * 0.20, -0.0005)],
			Color(0.02, 0.02, 0.02, 0.2), 24)

	# As luzes-espia: as setas no alto entre os dois grandes, a coluna do meio,
	# e cinto e motor embaixo dos pequenos.
	var espias := {
		ImpressosCabine.Espia.SETA_ESQ: Vector2(-0.0085, 0.056),
		ImpressosCabine.Espia.SETA_DIR: Vector2(0.0085, 0.056),
		ImpressosCabine.Espia.FAROL_ALTO: Vector2(0.0, 0.036),
		ImpressosCabine.Espia.FREIO: Vector2(0.0, 0.019),
		ImpressosCabine.Espia.BATERIA: Vector2(0.0, 0.002),
		ImpressosCabine.Espia.OLEO: Vector2(0.0, -0.015),
		ImpressosCabine.Espia.CINTO: Vector2(-0.172, -0.057),
		ImpressosCabine.Espia.MOTOR: Vector2(0.172, -0.057),
	}
	for k: int in espias:
		var q: Vector2 = espias[k]
		var lado := 0.0072 if k <= ImpressosCabine.Espia.SETA_DIR else 0.0065
		it.m(&"impresso").placa(xf * Transform3D(Basis(), Vector3(q.x, q.y, -0.0115)),
			Vector2(lado, lado), ImpressosCabine.uv(ImpressosCabine.regiao_espia(k)),
			Color(0.02, 0.02, 0.02, 0.0), Vector2(float(k), 0.0))
	it.g["_cluster_xf"] = xf


static func _regiao_mostrador(nome: StringName) -> Rect2:
	match nome:
		&"velocidade":
			return ImpressosCabine.R_VELOCIMETRO
		&"giro":
			return ImpressosCabine.R_CONTA_GIROS
		&"combustivel":
			return ImpressosCabine.R_COMBUSTIVEL
	return ImpressosCabine.R_TEMPERATURA


## O ponteiro: lamina afinando para a ponta, com o contrapeso atras do eixo.
static func _ponteiro(it: CabineInterior, comp: float, r: float) -> void:
	var ml := it.m(&"ponteiro")
	var cauda := r * 0.13
	var w0 := r * 0.055
	var w1 := r * 0.018
	var e := 0.0007
	var pts := [Vector3(-cauda, -w0 * 0.9, 0), Vector3(0.0, -w0, 0),
		Vector3(comp, -w1, 0), Vector3(comp + w1, 0.0, 0),
		Vector3(comp, w1, 0), Vector3(0.0, w0, 0), Vector3(-cauda, w0 * 0.9, 0)]
	var frente := PackedVector3Array()
	for q: Vector3 in pts:
		frente.append(q + Vector3(0, 0, e))
	ml.poligono(frente, Vector3.BACK, Color.WHITE)
	for k in pts.size():
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[(k + 1) % pts.size()]
		var n := Vector3(b.y - a.y, -(b.x - a.x), 0.0).normalized()
		if n.dot((a + b) * 0.5 - Vector3(comp * 0.4, 0, 0)) < 0.0:
			n = -n
		ml.quad(a + Vector3(0, 0, e), b + Vector3(0, 0, e), b, a, n)


# --- centro -----------------------------------------------------------------

## A frente do centro: a base dela e onde cada faixa mora.
static func _centro_xf(it: CabineInterior, p: Dictionary) -> Transform3D:
	var topo: float = it.g["topo"]
	var ref := na_face(p, 0.0, topo - 0.07, 0.012)
	return ref


## Um ponto na frente do centro, na altura `y` (do mundo) e `fora` metros para
## o motorista a partir dela.
static func _no_centro(base: Transform3D, x: float, y: float, fora: float) -> Transform3D:
	var up := base.basis.y
	var dy := (y - base.origin.y) / maxf(up.y, 0.2)
	return Transform3D(base.basis, base.origin + base.basis.x * x + up * dy
		+ base.basis.z * fora)


static func meia_do_centro(it: CabineInterior) -> float:
	var s := it.tomada().origin
	return maxf(0.108, absf(s.x) + 0.034)


static func _centro(it: CabineInterior, p: Dictionary) -> void:
	var topo: float = it.g["topo"]
	var y0 := topo - 0.02
	var y1 := y0 - CENTRO_ALTURA
	var hw := meia_do_centro(it)
	var base := _centro_xf(it, p)
	var pl := it.m(&"plastico")
	var meio := _no_centro(base, 0.0, (y0 + y1) * 0.5, 0.0)
	pl.xf = meio
	# A frente do corpo e o plano z = 0 de `base`: tudo o que mora no centro
	# se monta a partir dele. Com a frente 1 cm adiante, radio e ar ficavam
	# enterrados e so a gaveta e os botoes apareciam.
	# Nove centimetros de fundo bastam: atras disso e o miolo do painel. Com
	# vinte, a quina de tras furava o corta-fogo e saia pelo para-brisa do
	# hatch, que tem o painel mais curto (`checar_cabine_contida`).
	pl.caixa(Vector3(0.0, 0.0, -0.045), Vector3(hw, (y0 - y1) * 0.5, 0.045), 0.010,
		CabineInterior.COR_CENTRO)
	pl.xf = Transform3D.IDENTITY

	# Difusores e o pisca-alerta entre eles.
	var yd := y0 - CENTRO_DIFUSOR
	for s: float in [-1.0, 1.0]:
		_difusor(it, _no_centro(base, s * 0.052, yd, 0.0), 0.078, 0.050)
	var alerta := _no_centro(base, 0.0, yd, 0.0)
	pl.xf = alerta
	pl.caixa(Vector3(0, 0, 0.005), Vector3(0.0105, 0.0105, 0.005), 0.0025,
		CabineInterior.COR_PECA_LISA)
	pl.xf = Transform3D.IDENTITY
	it.m(&"impresso").placa(alerta * Transform3D(Basis(), Vector3(0, 0, 0.0102)),
		Vector2(0.0085, 0.0085),
		ImpressosCabine.uv(ImpressosCabine.regiao_botao(ImpressosCabine.Botao.ALERTA)),
		Color(0.03, 0.03, 0.03, 0.6))

	_radio(it, _no_centro(base, 0.0, y0 - CENTRO_RADIO, 0.0))
	_ar(it, _no_centro(base, 0.0, y0 - CENTRO_AR, 0.0))
	_cinzeiro(it, _no_centro(base, 0.0, y0 - CENTRO_CINZEIRO, 0.0))
	var fundo := _no_centro(base, 0.0, y1, 0.01)
	it.g["_centro"] = {"y0": y0, "y1": y1, "meia": hw, "z_frente": fundo.origin.z}


## Um difusor de ar: moldura, fundo escuro, cinco aletas inclinadas e a
## lingueta de mira no meio. Local: +Z sai da face.
static func _difusor(it: CabineInterior, onde: Transform3D, larg: float,
		alt: float) -> void:
	var pl := it.m(&"plastico")
	pl.xf = onde
	var b := 0.0075
	var prof := 0.006
	var cor := CabineInterior.COR_PECA
	pl.caixa(Vector3(0, alt * 0.5 - b * 0.5, prof), Vector3(larg * 0.5, b * 0.5, prof),
		0.003, cor)
	pl.caixa(Vector3(0, -alt * 0.5 + b * 0.5, prof), Vector3(larg * 0.5, b * 0.5, prof),
		0.003, cor)
	for s: float in [-1.0, 1.0]:
		pl.caixa(Vector3(s * (larg * 0.5 - b * 0.5), 0, prof),
			Vector3(b * 0.5, alt * 0.5 - b * 0.9, prof), 0.003, cor)
	# O fundo, recuado atras das aletas, quase preto.
	pl.quad(Vector3(-larg * 0.5, alt * 0.5, 0.001), Vector3(larg * 0.5, alt * 0.5, 0.001),
		Vector3(larg * 0.5, -alt * 0.5, 0.001), Vector3(-larg * 0.5, -alt * 0.5, 0.001),
		Vector3.BACK, Color(0.012, 0.012, 0.012, 1.0))
	# As palhetas verticais do fundo, que se ve entre as aletas.
	for k in 5:
		var x := lerpf(-larg * 0.5 + b, larg * 0.5 - b, (float(k) + 0.5) / 5.0)
		pl.caixa(Vector3(x, 0, 0.004), Vector3(0.0009, alt * 0.5 - b, 0.003), 0.0006,
			Color(0.03, 0.03, 0.03, 0.8))
	var n := 5
	for k in n:
		var y := lerpf(-alt * 0.5 + b * 1.5, alt * 0.5 - b * 1.5, float(k) / float(n - 1))
		pl.caixa(Vector3(0, y, prof + 0.001), Vector3(larg * 0.5 - b, 0.0012, 0.0055),
			0.0010, Color(0.075, 0.073, 0.070, 0.7), Basis(Vector3.RIGHT, deg_to_rad(14.0)))
	pl.caixa(Vector3(0, 0, prof + 0.0065), Vector3(0.0035, 0.0065, 0.0035), 0.0018,
		CabineInterior.COR_PECA_LISA)
	pl.xf = Transform3D.IDENTITY


## O toca-fitas: chassi, serigrafia, gaveta da fita, visor, dois botoes e as
## teclas de memoria. Local: centro da frente, +Z para o motorista.
static func _radio(it: CabineInterior, onde: Transform3D) -> void:
	var pl := it.m(&"plastico")
	var mm := 0.001
	var cor := Color(0.055, 0.054, 0.054, 0.55)
	pl.xf = onde
	pl.caixa(Vector3(0, 0, 0.003), Vector3(RADIO_MEIA.x + 0.002, RADIO_MEIA.y + 0.002,
		0.005), 0.0025, cor)
	pl.xf = Transform3D.IDENTITY
	it.m(&"impresso").placa(onde * Transform3D(Basis(), Vector3(0, 0, 0.0081)),
		RADIO_MEIA, ImpressosCabine.uv(ImpressosCabine.R_RADIO),
		Color(0.055, 0.054, 0.054, 0.35))
	var p := func(x: float, y: float, z: float) -> Vector3:
		return Vector3((x - 89.0) * mm, (25.0 - y) * mm, z)
	pl.xf = onde
	# A gaveta da fita: tampa fume brilhante e a fresta da boca.
	pl.caixa(p.call(74.0, 17.0, 0.0095), Vector3(0.044, 0.0095, 0.0014), 0.0014,
		Color(0.03, 0.03, 0.032, 0.05))
	pl.caixa(p.call(74.0, 11.5, 0.0112), Vector3(0.040, 0.0006, 0.0004), 0.0003,
		Color(0.008, 0.008, 0.008, 0.9))
	# Teclas de avanco e retrocesso da fita, na ponta direita da gaveta.
	for k in 2:
		pl.caixa(p.call(112.0 + 6.0 * k, 23.5, 0.0098), Vector3(0.0026, 0.0017, 0.0016),
			0.0008, CabineInterior.COR_TECLA)
	# As seis memorias e as duas teclas da direita.
	for k in 6:
		pl.caixa(p.call(37.6 + 14.4 * k, 38.0, 0.0098), Vector3(0.0062, 0.0034, 0.0017),
			0.0012, CabineInterior.COR_TECLA)
	for x: float in [129.5, 145.5]:
		pl.caixa(p.call(x, 38.0, 0.0098), Vector3(0.0065, 0.0034, 0.0017), 0.0012,
			CabineInterior.COR_TECLA)
	# O visor: moldura e o vidro fume por cima dos segmentos.
	pl.caixa(p.call(137.0, 15.0, 0.0086), Vector3(0.0165, 0.0080, 0.0006), 0.0008,
		Color(0.02, 0.02, 0.02, 0.2))
	pl.xf = Transform3D.IDENTITY
	it.m(&"visor").placa(onde * Transform3D(Basis(), p.call(137.0, 15.0, 0.0093)),
		Vector2(0.0150, 0.0068), Rect2(0, 0, 1, 1))
	it.m(&"lente").placa(onde * Transform3D(Basis(), p.call(137.0, 15.0, 0.0097)),
		Vector2(0.0155, 0.0072), Rect2(0, 0, 1, 1))
	# Os dois botoes: volume e sintonia.
	for x: float in [14.0, 164.0]:
		_botao_giratorio(it, onde * Transform3D(Basis(), p.call(x, 21.0, 0.0081)),
			0.0078, 0.011)


## Botao redondo de radio e de ar: colar, corpo serrilhado, tampa cromada e o
## risco que diz para onde aponta. Local: base no plano, +Z para fora.
static func _botao_giratorio(it: CabineInterior, onde: Transform3D, r: float,
		alto: float, risco: float = 90.0) -> void:
	var pl := it.m(&"plastico")
	pl.torno(onde, [
		Vector2(0.0, alto), Vector2(r * 0.72, alto), Vector2(r * 0.86, alto - 0.0008),
		Vector2(r * 0.95, alto - 0.002), Vector2(r, alto - 0.004), Vector2(r, 0.0022),
		Vector2(r * 1.14, 0.0018), Vector2(r * 1.16, 0.0)],
		Color(0.05, 0.049, 0.048, 0.45), 40)
	it.m(&"metal").torno(onde, [
		Vector2(0.0, alto + 0.0004), Vector2(r * 0.66, alto + 0.0004),
		Vector2(r * 0.70, alto - 0.0002)], COR_METAL_ESCOVADO, 32)
	var a := deg_to_rad(risco)
	pl.xf = onde
	pl.caixa(Vector3(cos(a), sin(a), 0.0) * r * 0.40 + Vector3(0, 0, alto + 0.0005),
		Vector3(r * 0.22, 0.0006, 0.0003), 0.0002, Color(0.9, 0.88, 0.84, 0.3),
		Basis(Vector3.BACK, a))
	pl.xf = Transform3D.IDENTITY


const COR_METAL_ESCOVADO := Color(0.70, 0.70, 0.72, 0.6)


## A faixa do ar: placa, as tres escalas impressas e os tres botoes.
static func _ar(it: CabineInterior, onde: Transform3D) -> void:
	var pl := it.m(&"plastico")
	pl.xf = onde
	pl.caixa(Vector3(0, 0, 0.002), Vector3(0.090, 0.023, 0.004), 0.003,
		Color(0.10, 0.096, 0.092, 0.9))
	pl.xf = Transform3D.IDENTITY
	var escalas := [ImpressosCabine.R_VENTILADOR, ImpressosCabine.R_AR_TEMPERATURA,
		ImpressosCabine.R_AR_DIRECAO]
	var riscos := [160.0, 100.0, 45.0]
	for k in 3:
		var x := (float(k) - 1.0) * 0.059
		var c := onde * Transform3D(Basis(), Vector3(x, 0, 0.0062))
		it.m(&"impresso").placa(c, Vector2(0.0205, 0.0205),
			ImpressosCabine.uv(escalas[k]), Color(0.10, 0.096, 0.092, 0.45))
		_botao_giratorio(it, c, 0.0082, 0.012, riscos[k])


## Cinzeiro de gaveta, acendedor e as duas teclas de luz.
static func _cinzeiro(it: CabineInterior, onde: Transform3D) -> void:
	var pl := it.m(&"plastico")
	pl.xf = onde
	pl.caixa(Vector3(-0.012, 0, 0.004), Vector3(0.050, 0.015, 0.004), 0.003,
		Color(0.085, 0.082, 0.079, 0.8))
	# O puxador: a concha escura no alto da gaveta.
	pl.caixa(Vector3(-0.012, 0.009, 0.0072), Vector3(0.018, 0.0025, 0.0012), 0.0012,
		Color(0.02, 0.02, 0.02, 0.9))
	pl.xf = Transform3D.IDENTITY
	# O acendedor: aro cromado e o botao preto com o anel laranja.
	var ac := onde * Transform3D(Basis(), Vector3(0.064, 0, 0.001))
	it.m(&"metal").torno(ac, [Vector2(0.0086, 0.0005), Vector2(0.0092, 0.0035),
		Vector2(0.0110, 0.0040), Vector2(0.0124, 0.0)], CabineInterior.COR_CROMO, 40)
	pl.torno(ac, [Vector2(0.0, 0.0085), Vector2(0.0055, 0.0085),
		Vector2(0.0070, 0.0078), Vector2(0.0078, 0.0060), Vector2(0.0078, 0.0020),
		Vector2(0.0086, 0.0010)], Color(0.03, 0.03, 0.03, 0.25), 32)
	it.m(&"impresso").disco(ac * Transform3D(Basis(), Vector3(0, 0, 0.0086)), 0.0042,
		ImpressosCabine.uv(ImpressosCabine.R_AR_TEMPERATURA), Color(0.03, 0.03, 0.03, 0.2),
		24, 0.1)
	# Teclas basculantes de farol de neblina e desembacador, a esquerda.
	for k in 2:
		var tk := onde * Transform3D(Basis(), Vector3(-0.080 if k == 0 else 0.090, 0.0, 0.0))
		pl.xf = tk
		pl.caixa(Vector3(0, 0, 0.004), Vector3(0.007, 0.0115, 0.004), 0.002,
			CabineInterior.COR_PECA_LISA, Basis(Vector3.RIGHT, deg_to_rad(6.0)))
		pl.xf = Transform3D.IDENTITY
		var icone := ImpressosCabine.Botao.NEBLINA if k == 0 \
			else ImpressosCabine.Botao.DESEMBACADOR
		it.m(&"impresso").placa(tk * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(6.0)),
			Vector3(0, 0, 0.0082)), Vector2(0.005, 0.005),
			ImpressosCabine.uv(ImpressosCabine.regiao_botao(icone)),
			Color(0.05, 0.05, 0.05, 0.5))


# --- porta-trecos -----------------------------------------------------------

## O vao aberto embaixo do ar, com a tomada de 12 V na parede do fundo — o
## lugar do carregador de `AoVolante` — e o que se esquece no carro: uma fita,
## moedas.
static func _porta_trecos(it: CabineInterior) -> void:
	var c: Dictionary = it.g["_centro"]
	var hw: float = c["meia"]
	var y1: float = c["y1"]
	var zf: float = c["z_frente"]
	var tom := it.tomada()
	var eixo := tom.basis.z
	var boca := tom.origin - eixo * 0.012
	var y_prat := tom.origin.y - 0.045
	var tg := tan(deg_to_rad(CabineInterior.TOMADA_INCLINACAO))
	var z_fundo := func(y: float) -> float: return boca.z - (y - boca.y) * tg
	var pl := it.m(&"plastico")
	var escuro := Color(0.075, 0.072, 0.068, 0.95)
	# Fundo inclinado.
	var ya := y_prat - 0.012
	var yb := y1 + 0.012
	pl.quad(Vector3(-hw, yb, z_fundo.call(yb)), Vector3(hw, yb, z_fundo.call(yb)),
		Vector3(hw, ya, z_fundo.call(ya)), Vector3(-hw, ya, z_fundo.call(ya)),
		eixo, escuro)
	# Paredes.
	for s: float in [-1.0, 1.0]:
		var zb: float = z_fundo.call(yb)
		var zc := (zb + zf) * 0.5
		pl.caixa(Vector3(s * (hw - 0.006), (y1 + y_prat) * 0.5, zc),
			Vector3(0.006, (y1 - y_prat) * 0.5 + 0.004, (zf - zb) * 0.5), 0.004,
			CabineInterior.COR_CENTRO)
	# Prateleira com o tapetinho de borracha.
	var zp: float = z_fundo.call(y_prat)
	pl.caixa(Vector3(0, y_prat - 0.007, (zp + zf) * 0.5 + 0.004),
		Vector3(hw, 0.007, (zf - zp) * 0.5 + 0.006), 0.004, CabineInterior.COR_CENTRO)
	pl.caixa(Vector3(0, y_prat + 0.0006, (zp + zf) * 0.5), Vector3(hw - 0.016, 0.0008,
		(zf - zp) * 0.5 - 0.008), 0.0008, CabineInterior.COR_BORRACHA)
	for k in 6:
		var z := lerpf(zp + 0.012, zf - 0.012, float(k) / 5.0)
		pl.caixa(Vector3(0, y_prat + 0.0017, z), Vector3(hw - 0.022, 0.0006, 0.0014),
			0.0005, CabineInterior.COR_BORRACHA)
	# A tomada: aro cromado saindo da parede e o cano escuro por dentro.
	var met := it.m(&"metal")
	var tf := Transform3D(tom.basis, boca)
	met.torno(tf, [Vector2(0.0128, 0.0010), Vector2(0.0132, 0.0060),
		Vector2(0.0150, 0.0068), Vector2(0.0168, 0.0060), Vector2(0.0175, 0.0)],
		CabineInterior.COR_CROMO, 40)
	pl.torno(tf, [Vector2(0.0125, 0.0010), Vector2(0.0125, 0.0062)],
		Color(0.01, 0.01, 0.01, 1.0), 32)
	pl.disco(tf * Transform3D(Basis(), Vector3(0, 0, 0.0012)), 0.0126,
		Rect2(0, 0, 1, 1), Color(0.004, 0.004, 0.004, 1.0), 32)
	met.torno(tf * Transform3D(Basis(), Vector3(0, 0, 0.0012)), [Vector2(0.0, 0.002),
		Vector2(0.0022, 0.0018), Vector2(0.0026, 0.0)], COR_METAL_ESCOVADO, 12)

	# Uma fita cassete largada do lado que a tomada deixa livre, e moedas.
	var lado := -signf(tom.origin.x) if absf(tom.origin.x) > 0.01 else 1.0
	var zc := (zp + zf) * 0.5
	_fita(it, Transform3D(Basis(Vector3.UP, deg_to_rad(-9.0 * lado)),
		Vector3(lado * (hw - 0.064), y_prat + 0.0082, zc)))
	var moedas := [Vector3(0.020, 0.0, 0.018), Vector3(0.036, 0.0015, 0.010),
		Vector3(0.012, 0.0, -0.004)]
	for k in moedas.size():
		var q: Vector3 = moedas[k]
		var cor := CabineInterior.COR_LATAO if k != 1 else COR_METAL_ESCOVADO
		met.torno(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).rotated(Vector3.UP, k * 1.3),
			Vector3(-lado * q.x, y_prat + 0.0028 + q.y, zc + q.z)),
			[Vector2(0.0, 0.0010), Vector2(0.0106, 0.0010), Vector2(0.0110, 0.0),
			Vector2(0.0106, -0.0010)], cor, 28)
	it.g["_porta_trecos"] = {"y_prat": y_prat, "z_fundo": zp, "boca": boca}


## Uma fita cassete: caixa fume, etiqueta de papel e as duas janelas.
static func _fita(it: CabineInterior, onde: Transform3D) -> void:
	var pl := it.m(&"plastico")
	pl.xf = onde
	pl.caixa(Vector3.ZERO, Vector3(0.0502, 0.0060, 0.0319), 0.0015,
		Color(0.06, 0.058, 0.056, 0.1))
	# Etiqueta: papel claro gasto, com a faixa laranja das fitas de gravar.
	pl.caixa(Vector3(0, 0.0059, -0.004), Vector3(0.042, 0.0003, 0.019), 0.0003,
		Color(0.80, 0.76, 0.66, 1.0))
	pl.caixa(Vector3(0, 0.0063, -0.013), Vector3(0.042, 0.0002, 0.0045), 0.0002,
		Color(0.85, 0.42, 0.10, 0.9))
	# Linhas de caneta da etiqueta.
	for k in 2:
		pl.caixa(Vector3(-0.004, 0.0063, 0.001 + 0.006 * k), Vector3(0.030, 0.0001, 0.0004),
			0.0001, Color(0.12, 0.14, 0.30, 1.0))
	# A janela da fita e os dois cubos.
	pl.caixa(Vector3(0, 0.0063, 0.014), Vector3(0.020, 0.0002, 0.005), 0.0002,
		Color(0.015, 0.015, 0.015, 0.05))
	for s: float in [-1.0, 1.0]:
		pl.torno(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
			Vector3(s * 0.021, 0.0064, 0.014)), [Vector2(0.0, 0.0002),
			Vector2(0.0052, 0.0002), Vector2(0.0055, 0.0)], Color(0.85, 0.85, 0.82, 0.4), 16)
	pl.xf = Transform3D.IDENTITY


# --- laterais ---------------------------------------------------------------

static func _difusores_laterais(it: CabineInterior, p: Dictionary) -> void:
	var topo: float = it.g["topo"]
	var y := topo - 0.052
	var f := face(p, y)
	var w := it.parede(y - 0.03, y + 0.03, float(f["z"])) - 0.012
	var c := centro_do_cluster(it)
	for s: float in [-1.0, 1.0]:
		var x := s * (w - 0.068)
		# Onde a pala do cluster ja ocupa, o difusor nao cabe (Fusca).
		if absf(x - c.x) < PALA_MEIA + 0.055:
			continue
		_difusor(it, na_face(p, x, y, 0.001), 0.096, 0.056)


static func _porta_luvas(it: CabineInterior, p: Dictionary) -> void:
	var topo: float = it.g["topo"]
	var lado: float = it.g["lado"]
	var yb: float = p["yb"]
	var hw := meia_do_centro(it)
	var y_alto := topo - 0.078
	var y_baixo := yb + 0.045
	var w := it.parede(y_baixo, y_alto, float(face(p, y_alto)["z"])) - 0.03
	var x0 := hw + 0.03
	var x1 := minf(w, absf(lado) + 0.20)
	if x1 - x0 < 0.16:
		return
	var sinal := -signf(lado) if absf(lado) > 0.01 else 1.0
	var linhas_fresta: Array = []
	var linhas_tampa: Array = []
	var n := 9
	for k in n:
		var y := lerpf(y_alto, y_baixo, float(k) / float(n - 1))
		var f := face(p, y)
		var nn: Vector3 = f["n"]
		var z: float = f["z"]
		var lf := PackedVector3Array()
		var lt := PackedVector3Array()
		for j in 2:
			var x := lerpf(x0, x1, float(j)) * sinal
			lf.append(Vector3(x, y, z) + nn * 0.0012)
			lt.append(Vector3(lerpf(x0 + 0.004, x1 - 0.004, float(j)) * sinal,
				clampf(y, y_baixo + 0.004, y_alto - 0.004), z) + nn * 0.0035)
		linhas_fresta.append(lf)
		linhas_tampa.append(lt)
	var pl := it.m(&"plastico")
	var dentro := Vector3(sinal * (x0 + x1) * 0.5, (y_alto + y_baixo) * 0.5,
		float(it.g["lip_z"]) - 0.25)
	pl.grade_de_pontos(linhas_fresta, Color(0.03, 0.03, 0.03, 1.0), dentro)
	pl.grade_de_pontos(linhas_tampa, CabineInterior.COR_FACE.lightened(0.03), dentro)
	# O puxador: concha escura e a alavanca cromada dentro.
	var ym := y_alto - 0.022
	var xm := sinal * (x0 + x1) * 0.5
	var fxf := na_face(p, xm, ym, 0.004)
	pl.xf = fxf
	pl.caixa(Vector3(0, 0, 0.002), Vector3(0.040, 0.009, 0.003), 0.003,
		Color(0.03, 0.03, 0.03, 0.9))
	pl.xf = Transform3D.IDENTITY
	var met := it.m(&"metal")
	met.xf = fxf
	met.caixa(Vector3(0, 0.001, 0.0055), Vector3(0.034, 0.0045, 0.0018), 0.0016,
		COR_METAL_ESCOVADO)
	met.xf = Transform3D.IDENTITY
	# A fechadura redonda na ponta de fora.
	met.torno(na_face(p, sinal * (x1 - 0.03), ym, 0.004), [Vector2(0.0, 0.003),
		Vector2(0.0045, 0.003), Vector2(0.0055, 0.0015), Vector2(0.006, 0.0)],
		CabineInterior.COR_CROMO, 24)


## O friso de madeira do lado do passageiro, com os dois filetes cromados.
static func _friso(it: CabineInterior, p: Dictionary) -> void:
	var topo: float = it.g["topo"]
	var lado: float = it.g["lado"]
	var y := topo - 0.052
	var hw := meia_do_centro(it)
	var f := face(p, y)
	var w := it.parede(y - 0.02, y + 0.02, float(f["z"])) - 0.012
	var x0 := hw + 0.012
	var x1 := w - 0.128
	if x1 - x0 < 0.08:
		return
	var sinal := -signf(lado) if absf(lado) > 0.01 else 1.0
	var xm := sinal * (x0 + x1) * 0.5
	var fxf := na_face(p, xm, y, 0.0)
	it.m(&"madeira").xf = fxf
	it.m(&"madeira").caixa(Vector3(0, 0, 0.003), Vector3((x1 - x0) * 0.5, 0.0135, 0.0045),
		0.0035, Color(0.50, 0.30, 0.17, 1.0), Basis(), 4)
	it.m(&"madeira").xf = Transform3D.IDENTITY
	var met := it.m(&"metal")
	met.xf = fxf
	for s: float in [-1.0, 1.0]:
		met.caixa(Vector3(0, s * 0.0152, 0.0022), Vector3((x1 - x0) * 0.5, 0.0009, 0.0014),
			0.0008, CabineInterior.COR_CROMO)
	met.xf = Transform3D.IDENTITY


# --- coluna -----------------------------------------------------------------

## A capa da coluna de direcao, as duas alavancas e a chave no contato.
static func _coluna(it: CabineInterior) -> void:
	var w0: Vector3 = it.g["volante"]
	var incl: float = it.g["volante_incl"]
	var eixo_xf := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-incl)), w0)
	# No espaco do pivo: -Z desce para o painel.
	var pl := it.m(&"plastico")
	var linhas: Array = []
	var miolos: Array[Vector3] = []
	var estacoes := [0.092, 0.11, 0.16, 0.22, 0.30, 0.36]
	for k in estacoes.size():
		var t := float(k) / float(estacoes.size() - 1)
		var d: float = estacoes[k]
		var a := lerpf(0.050, 0.060, t)
		var b := lerpf(0.042, 0.056, t)
		# A boca da capa fecha um pouco, como a de verdade, em volta do cubo.
		if k == 0:
			a -= 0.006
			b -= 0.006
		var centro := Vector3(0.0, -0.012 * t, -d)
		var anel := PackedVector3Array()
		for j in 33:
			var fi := TAU * float(j) / 32.0
			var cx := cos(fi)
			var cy := sin(fi)
			# Superelipse: lados retos e quinas cheias, a cara da capa injetada.
			var sx := signf(cx) * pow(absf(cx), 0.55)
			var sy := signf(cy) * pow(absf(cy), 0.55)
			anel.append(eixo_xf * (centro + Vector3(sx * a, sy * b, 0.0)))
		linhas.append(anel)
		miolos.append(eixo_xf * centro)
	pl.grade_de_pontos(linhas, CabineInterior.COR_PECA,
		func(k: int, _j: int) -> Vector3: return miolos[k])
	var boca := PackedVector3Array()
	var primeira: PackedVector3Array = linhas[0]
	for j in 32:
		boca.append(primeira[j])
	pl.poligono(boca, eixo_xf.basis.z, CabineInterior.COR_PECA)

	# As alavancas: seta a esquerda, limpador a direita.
	for s: float in [-1.0, 1.0]:
		var raiz := eixo_xf * Vector3(s * 0.050, 0.004, -0.118)
		var dir := (eixo_xf.basis * Vector3(s, -0.08, 0.18)).normalized()
		var pts := PackedVector3Array()
		var raios := PackedFloat32Array()
		for k in 9:
			var t := float(k) / 8.0
			pts.append(raiz + dir * 0.150 * t + Vector3(0, -0.012 * t * t, 0))
			raios.append(lerpf(0.0062, 0.0050, t) + (0.0018 if t > 0.78 else 0.0))
		pl.tubo(pts, raios, CabineInterior.COR_PECA_LISA, 14)
		pl.xf = Transform3D(CabineInterior.base_olhando(dir), raiz)
		pl.caixa(Vector3(0, 0, 0.004), Vector3(0.011, 0.010, 0.008), 0.004,
			CabineInterior.COR_PECA)
		pl.xf = Transform3D.IDENTITY

	# O contato e a chave, do lado direito da capa.
	var cont := eixo_xf * Transform3D(Basis(Vector3.UP, PI * 0.5).rotated(Vector3.RIGHT, 0.0),
		Vector3(0.058, 0.006, -0.20))
	var met := it.m(&"metal")
	met.torno(cont, [Vector2(0.0, 0.004), Vector2(0.008, 0.004), Vector2(0.0105, 0.0025),
		Vector2(0.0115, 0.0)], CabineInterior.COR_CROMO, 32)
	# A cabeca da chave (plastico preto) e a lamina saindo do contato.
	met.xf = cont
	met.caixa(Vector3(0, 0, 0.012), Vector3(0.0035, 0.0010, 0.009), 0.0006,
		COR_METAL_ESCOVADO)
	met.xf = Transform3D.IDENTITY
	pl.xf = cont
	pl.caixa(Vector3(0, 0, 0.030), Vector3(0.0125, 0.0045, 0.012), 0.0035,
		Color(0.04, 0.04, 0.04, 0.3))
	pl.xf = Transform3D.IDENTITY
	# O chaveiro pendurado: argola e uma plaquinha de couro.
	var argola := cont * Vector3(0, -0.003, 0.043)
	var pts := PackedVector3Array()
	for k in 25:
		var a := TAU * float(k) / 24.0
		pts.append(argola + cont.basis * Vector3(0.0, -cos(a) * 0.009 - 0.009,
			sin(a) * 0.009))
	met.tubo(pts, PackedFloat32Array([0.0008]), COR_METAL_ESCOVADO, 8, false)
	pl.caixa(argola + Vector3(0, -0.046, 0.004), Vector3(0.0035, 0.024, 0.012), 0.003,
		CabineInterior.COR_COURO, Basis(Vector3.RIGHT, 0.12))


# --- pedais -----------------------------------------------------------------

static func _pedais(it: CabineInterior, p: Dictionary) -> void:
	var lado: float = it.g["lado"]
	var piso: float = it.g["piso"]
	var zf: float = it.g["z_frente"]
	var olho: Vector3 = it.g["olho"]
	var yb: float = p["yb"]
	var z := maxf(zf + 0.14, olho.z - 0.62)
	var pl := it.m(&"plastico")
	var met := it.m(&"metal")
	var dentro := -signf(lado) if absf(lado) > 0.01 else 1.0
	var pedais := [
		[lado - 0.125 * dentro, Vector2(0.036, 0.028), 0.16],
		[lado - 0.012 * dentro, Vector2(0.040, 0.030), 0.15],
		[lado + 0.100 * dentro, Vector2(0.022, 0.050), 0.13],
	]
	for pd: Array in pedais:
		var x: float = pd[0]
		var meia: Vector2 = pd[1]
		var y := piso + float(pd[2])
		var base := Basis(Vector3.RIGHT, deg_to_rad(-38.0))
		var c := Vector3(x, y, z)
		pl.caixa(c, Vector3(meia.x, meia.y, 0.006), 0.004, CabineInterior.COR_BORRACHA,
			base)
		# Os frisos de borracha da sapata.
		for k in 4:
			var o := base * Vector3(0, lerpf(-meia.y, meia.y, (float(k) + 0.5) / 4.0) * 0.8,
				0.0065)
			pl.caixa(c + o, Vector3(meia.x * 0.86, 0.0015, 0.0012), 0.001,
				CabineInterior.COR_BORRACHA, base)
		# A haste subindo para dentro do painel.
		var pts := PackedVector3Array([c + base * Vector3(0, 0, -0.006),
			c + Vector3(0, 0.12, -0.05), Vector3(x, yb - 0.02, z - 0.12)])
		met.tubo(pts, PackedFloat32Array([0.006]), Color(0.18, 0.18, 0.19, 0.8), 10)
