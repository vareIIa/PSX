## Chapa lisa em grade: a ferramenta das pecas curvas do exterior AAA do carro.
##
## `CarroceriaVarrida.quad` emite quatro vertices por quadrilatero com a normal
## da FACE, e quem alisa depois e `suavizar`, juntando vertices no mesmo lugar.
## Serve para um casco de dezesseis estacoes; nao serve para chapa curva de
## verdade — um para-lama gota, a cupula do Fusca, o aro do farol —, em que a
## normal certa de cada vertice e a da SUPERFICIE, e nao a media de quatro faces
## chapadas. Com a media, o verniz do MODERNO reflete o ceu em facetas, e foi
## isso que fez o Fusca antigo ler como poliedro.
##
## Aqui a peca chega como grade de pontos (linhas x colunas) e a normal de cada
## ponto sai da propria grade, por diferenca central. Os vertices sao
## compartilhados: uma grade de 40 x 30 custa 1.200 vertices, e nao 4.800.
##
## Giro: segue a CONVENCAO DO PROJETO (ver `CarroceriaVarrida.quad`) — a face
## aparece do lado OPOSTO ao produto vetorial do giro. Cada triangulo confere o
## proprio giro contra a normal media dos seus vertices, entao quem chama so
## precisa dizer para que lado e FORA, nunca em que ordem escrever os indices.
class_name ChapaLisa
extends RefCounted


## Emite uma grade.
##
## `pts`     Array de PackedVector3Array, uma por linha, todas do mesmo tamanho.
## `cores`   Array de PackedColorArray no mesmo formato, ou vazio para usar `cor`.
## `sinal`   +1 se (d/dcoluna x d/dlinha) aponta para FORA, -1 se para dentro.
## `centros` opcional, um ponto por linha: a normal e virada para longe dele.
##           Serve a tubo e torno, em que o "fora" e radial e o sinal muda com
##           o sentido do perfil.
## `anel`    a ultima coluna repete a primeira: a normal da costura olha os dois
##           lados, e o anel fecha sem vinco.
## `pular`   Callable(linha, coluna) -> bool: celula furada (janela, fenda).
## `normais` opcional, no formato de `pts`: a normal ja pronta. Serve a chapa
##           com vinco — a normal da grade afundada espalha o sulco de meio
##           centimetro pela faixa inteira de sete, e o capo lia enrugado.
static func grade(dados: Dictionary, pts: Array, cores: Array, cor: Color,
		celula: Vector2i, sinal: float, centros: PackedVector3Array = PackedVector3Array(),
		anel: bool = false, pular: Callable = Callable(), normais: Array = []) -> void:
	var linhas := pts.size()
	if linhas < 2:
		return
	var cols := (pts[0] as PackedVector3Array).size()
	if cols < 2:
		return
	var r := Carroceria.uv(celula)
	var v: PackedVector3Array = dados["v"]
	var n: PackedVector3Array = dados["n"]
	var u: PackedVector2Array = dados["uv"]
	var cc: PackedColorArray = dados["c"]
	var ii: PackedInt32Array = dados["i"]
	var base := v.size()
	if normais.is_empty():
		normais = normais_da_grade(pts, sinal, centros, anel)
	for j in linhas:
		var linha: PackedVector3Array = pts[j]
		var nl: PackedVector3Array = normais[j]
		var cl: PackedColorArray = cores[j] if not cores.is_empty() else PackedColorArray()
		for k in cols:
			v.append(linha[k])
			n.append(nl[k])
			cc.append(cl[k] if not cl.is_empty() else cor)
			u.append(r.position + Vector2(float(k) / float(cols - 1),
				float(j) / float(linhas - 1)) * r.size)
	var tem_pular := pular.is_valid()
	for j in linhas - 1:
		for k in cols - 1:
			if tem_pular and bool(pular.call(j, k)):
				continue
			var a := base + j * cols + k
			var b := a + 1
			var c := a + cols + 1
			var d := a + cols
			# Diagonal mais curta: numa grade que afina (polo de cupula, ponta de
			# para-lama) a diagonal longa faz triangulo de agulha, que acende
			# como risco no verniz.
			if v[a].distance_squared_to(v[c]) <= v[b].distance_squared_to(v[d]):
				_tri(ii, v, n, a, b, c)
				_tri(ii, v, n, a, c, d)
			else:
				_tri(ii, v, n, a, b, d)
				_tri(ii, v, n, b, c, d)
	dados["v"] = v
	dados["n"] = n
	dados["uv"] = u
	dados["c"] = cc
	dados["i"] = ii


## As normais de uma grade, por diferenca central, viradas para fora.
static func normais_da_grade(pts: Array, sinal: float,
		centros: PackedVector3Array = PackedVector3Array(), anel: bool = false) -> Array:
	var linhas := pts.size()
	var cols := (pts[0] as PackedVector3Array).size()
	var saida: Array = []
	for j in linhas:
		var nl := PackedVector3Array()
		nl.resize(cols)
		var jp := maxi(j - 1, 0)
		var jn := mini(j + 1, linhas - 1)
		var la: PackedVector3Array = pts[jp]
		var lb: PackedVector3Array = pts[jn]
		var lc: PackedVector3Array = pts[j]
		for k in cols:
			var kp := k - 1
			var kn := k + 1
			if anel:
				if kp < 0:
					kp = cols - 2
				if kn > cols - 1:
					kn = 1
			else:
				kp = maxi(kp, 0)
				kn = mini(kn, cols - 1)
			var du := lc[kn] - lc[kp]
			var dv := lb[k] - la[k]
			var nn := du.cross(dv)
			# Polo: a linha inteira no mesmo ponto (ponta de lente, pe de cupula).
			# A normal sai da linha vizinha, que ainda tem largura.
			if nn.length_squared() < 1e-14:
				var outra: PackedVector3Array = pts[jn] if jn != j else pts[jp]
				var viz: PackedVector3Array = pts[jn + 1] if jn + 1 < linhas and jn != j else pts[jp]
				du = outra[kn] - outra[kp]
				dv = viz[k] - lc[k]
				nn = du.cross(dv)
				if jn == j:
					nn = -nn
			if nn.length_squared() < 1e-14:
				nn = Vector3.UP
			nn = nn.normalized() * sinal
			if not centros.is_empty():
				var fora := lc[k] - centros[j]
				if fora.length_squared() > 1e-10 and nn.dot(fora) < 0.0:
					nn = -nn
			nl[k] = nn
		saida.append(nl)
	return saida


## Solido de revolucao. `perfil` em (raio, avanco no eixo); `eixo` e a direcao
## do avanco e `ref` um vetor perpendicular a ele (onde o angulo zero mora).
##
## A face olha para a ESQUERDA de quem anda pelo perfil no plano (raio,
## avanco): perfil que avanca olha para fora do eixo, perfil que recolhe o raio
## com o avanco parado olha para a frente. E o que um aro, uma lente ou uma
## caneca querem se o perfil for escrito de tras para a frente e de fora para
## dentro. `radial` troca isso por "para longe do eixo", que so serve a tubo.
static func torno(dados: Dictionary, centro: Vector3, eixo: Vector3, ref: Vector3,
		perfil: PackedVector2Array, lados: int, cores: PackedColorArray, cor: Color,
		celula: Vector2i, sinal: float = 1.0, radial: bool = false) -> void:
	var e := eixo.normalized()
	var x := (ref - e * ref.dot(e)).normalized()
	var y := e.cross(x)
	var pts: Array = []
	var cs: Array = []
	var centros := PackedVector3Array()
	for p in perfil:
		var linha := PackedVector3Array()
		var cl := PackedColorArray()
		var ci: Color = cores[pts.size()] if not cores.is_empty() else cor
		for k in lados + 1:
			var a := TAU * float(k) / float(lados)
			linha.append(centro + e * p.y + (x * cos(a) + y * sin(a)) * p.x)
			cl.append(ci)
		pts.append(linha)
		cs.append(cl)
		centros.append(centro + e * p.y)
	grade(dados, pts, cs, cor, celula, sinal, centros if radial else PackedVector3Array(),
		true)


## Tubo de raio `raio` ao longo de `caminho`, com `lados` faces e tampas planas.
static func tubo(dados: Dictionary, caminho: PackedVector3Array, raio: float,
		lados: int, cor: Color, celula: Vector2i, tampas: bool = true) -> void:
	if caminho.size() < 2:
		return
	var pts: Array = []
	var centros := PackedVector3Array()
	var ref_ant := Vector3.ZERO
	for j in caminho.size():
		var t := (caminho[mini(j + 1, caminho.size() - 1)]
			- caminho[maxi(j - 1, 0)]).normalized()
		var ref := ref_ant
		if ref == Vector3.ZERO or absf(ref.dot(t)) > 0.95:
			ref = Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT
		var x := (ref - t * ref.dot(t)).normalized()
		ref_ant = x
		var y := t.cross(x)
		var linha := PackedVector3Array()
		for k in lados + 1:
			var a := TAU * float(k) / float(lados)
			linha.append(caminho[j] + (x * cos(a) + y * sin(a)) * raio)
		pts.append(linha)
		centros.append(caminho[j])
	grade(dados, pts, [], cor, celula, 1.0, centros, true)
	if not tampas:
		return
	for ponta in [0, caminho.size() - 1]:
		var linha: PackedVector3Array = pts[ponta]
		var fora := (caminho[ponta] - caminho[1 if ponta == 0 else ponta - 1]).normalized()
		for k in lados:
			CarroceriaVarrida.tri(dados, caminho[ponta], linha[k], linha[k + 1], celula,
				cor, cor, cor, fora)


## Leque plano fechando um contorno (tampa de ponta, fundo de lente).
static func leque(dados: Dictionary, contorno: PackedVector3Array, centro: Vector3,
		fora: Vector3, cor: Color, celula: Vector2i) -> void:
	for k in contorno.size() - 1:
		CarroceriaVarrida.tri(dados, centro, contorno[k], contorno[k + 1], celula,
			cor, cor, cor, fora)


## Um triangulo com o giro do projeto (ver `CarroceriaVarrida.quad`).
static func _tri(ii: PackedInt32Array, v: PackedVector3Array, n: PackedVector3Array,
		a: int, b: int, c: int) -> void:
	var cruz := (v[b] - v[a]).cross(v[c] - v[a])
	if cruz.length_squared() < 1e-16:
		return
	if cruz.dot(n[a] + n[b] + n[c]) > 0.0:
		ii.append_array([a, c, b])
	else:
		ii.append_array([a, b, c])


# --------------------------------------------------------------------------
# Curvas
# --------------------------------------------------------------------------

## Hermite monotono (PCHIP) nos nos `xs` crescentes. Nao passa do valor dos
## vizinhos: um perfil de carro medido em estacoes nao pode ganhar calombo entre
## elas so porque a curva quis ser lisa. `lineares` sao indices de trecho que
## ficam retos (para-brisa e vigia sao vidro plano).
static func pchip(xs: PackedFloat64Array, ys: PackedFloat64Array, x: float,
		lineares: PackedInt32Array = PackedInt32Array()) -> float:
	var n := xs.size()
	if x <= xs[0]:
		return ys[0]
	if x >= xs[n - 1]:
		return ys[n - 1]
	var i := 0
	var lo := 0
	var hi := n - 1
	while hi - lo > 1:
		var m := (lo + hi) >> 1
		if xs[m] <= x:
			lo = m
		else:
			hi = m
	i = lo
	var h := xs[i + 1] - xs[i]
	var f := (x - xs[i]) / h
	if i in lineares:
		return lerpf(ys[i], ys[i + 1], f)
	var m0 := _inclinacao(xs, ys, i, lineares)
	var m1 := _inclinacao(xs, ys, i + 1, lineares)
	var f2 := f * f
	var f3 := f2 * f
	return ((2.0 * f3 - 3.0 * f2 + 1.0) * ys[i] + (f3 - 2.0 * f2 + f) * h * m0
		+ (-2.0 * f3 + 3.0 * f2) * ys[i + 1] + (f3 - f2) * h * m1)


static func _inclinacao(xs: PackedFloat64Array, ys: PackedFloat64Array, i: int,
		lineares: PackedInt32Array) -> float:
	var n := xs.size()
	var d_ant := 0.0
	var d_pos := 0.0
	var tem_ant := i > 0
	var tem_pos := i < n - 1
	if tem_ant:
		d_ant = (ys[i] - ys[i - 1]) / (xs[i] - xs[i - 1])
	if tem_pos:
		d_pos = (ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i])
	# Encostado num trecho reto o no NAO herda a inclinacao dele. Herdar deixa
	# a quina do vidro sem vinco, mas a curva do outro lado passa do valor: na
	# base do para-brisa do Fusca a copa descia abaixo de zero e o capo
	# enrugava. A moldura do vidro e uma quina de verdade.
	if not tem_ant:
		return d_pos
	if not tem_pos:
		return d_ant
	if d_ant * d_pos <= 0.0:
		return 0.0
	var w1 := 2.0 * (xs[i + 1] - xs[i]) + (xs[i] - xs[i - 1])
	var w2 := (xs[i + 1] - xs[i]) + 2.0 * (xs[i] - xs[i - 1])
	return (w1 + w2) / (w1 / d_ant + w2 / d_pos)


## Hermite cubico entre dois pontos com tangentes (ja multiplicadas pelo passo).
static func hermite(p0: Vector2, m0: Vector2, p1: Vector2, m1: Vector2,
		f: float) -> Vector2:
	var f2 := f * f
	var f3 := f2 * f
	return ((2.0 * f3 - 3.0 * f2 + 1.0) * p0 + (f3 - 2.0 * f2 + f) * m0
		+ (-2.0 * f3 + 3.0 * f2) * p1 + (f3 - f2) * m1)


## Catmull-Rom centripeta por uma lista de pontos, `por_trecho` amostras em
## cada trecho. Centripeta porque os pontos de controle de peca de carro vem em
## espacamento desigual, e a uniforme faz laco onde dois pontos se aproximam.
static func catmull(pontos: PackedVector3Array, por_trecho: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := pontos.size()
	if n < 2:
		return pontos
	for i in n - 1:
		var p0 := pontos[maxi(i - 1, 0)]
		var p1 := pontos[i]
		var p2 := pontos[i + 1]
		var p3 := pontos[mini(i + 2, n - 1)]
		if i == 0:
			p0 = p1 * 2.0 - p2
		if i + 2 > n - 1:
			p3 = p2 * 2.0 - p1
		var t0 := 0.0
		var t1 := t0 + pow(maxf(p0.distance_to(p1), 1e-5), 0.5)
		var t2 := t1 + pow(maxf(p1.distance_to(p2), 1e-5), 0.5)
		var t3 := t2 + pow(maxf(p2.distance_to(p3), 1e-5), 0.5)
		for s in por_trecho:
			var t := lerpf(t1, t2, float(s) / float(por_trecho))
			var a1 := p0 * (t1 - t) / (t1 - t0) + p1 * (t - t0) / (t1 - t0)
			var a2 := p1 * (t2 - t) / (t2 - t1) + p2 * (t - t1) / (t2 - t1)
			var a3 := p2 * (t3 - t) / (t3 - t2) + p3 * (t - t2) / (t3 - t2)
			var b1 := a1 * (t2 - t) / (t2 - t0) + a2 * (t - t0) / (t2 - t0)
			var b2 := a2 * (t3 - t) / (t3 - t1) + a3 * (t - t1) / (t3 - t1)
			out.append(b1 * (t2 - t) / (t2 - t1) + b2 * (t - t1) / (t2 - t1))
	out.append(pontos[n - 1])
	return out
