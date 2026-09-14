## Ferramenta de carro varrido: perfil em Z, seccao em anel, e o giro certo.
##
## Nasceu inteira dentro do Fusca. Quando o Marea chegou, ou isto virava modulo
## ou eram duzentas e trinta linhas copiadas — e a copia levaria junto a
## CONVENCAO DE GIRO documentada em `quad`, que e o tipo de regra que, existindo
## em dois arquivos, diverge no primeiro dia em que alguem mexer num deles.
##
## O que mora aqui e o que nao depende de QUAL carro:
##
##   * as primitivas de malha (quad, tri, plana, disco) e o giro correto;
##   * a leitura do perfil — dado um Z, onde esta a lataria — que e o que
##     permite POSICIONAR detalhe na superficie em vez de chutar no espaco;
##   * a varredura do casco.
##
## O que NAO mora aqui e a tabela de perfil e as pecas aparafusadas (para-lama,
## grade, farol, para-choque): e ali que Fusca e Marea sao carros diferentes.
## Um besouro e uma abobada com para-lamas por fora; um sedan tres-volumes e uma
## caixa cuja lateral ja E a largura toda. Mesma maquina, tabelas opostas.
##
## Depende de Carroceria (celulas do atlas, uv). Carroceria NAO depende disto —
## ela resolve fusca/marea em runtime, o que e o que impede a referencia ciclica
## que derruba a compilacao do projeto inteiro.
class_name CarroceriaVarrida
extends RefCounted

## Colunas do perfil, depois de tirar o Z.
const BOT := 0
const CINT := 1
const TOPO := 2
const W_BOT := 3
const W_CINT := 4
const W_TOPO := 5


# --------------------------------------------------------------------------
# Ler o perfil
# --------------------------------------------------------------------------

## Interpola a estacao do perfil num Z qualquer.
##
## `perfil` anda da FRENTE para tras, entao z desce com o indice.
static func estacao(perfil: Array, z: float) -> Array:
	var n := perfil.size()
	if z >= perfil[0][0]:
		return (perfil[0] as Array).slice(1)
	if z <= perfil[n - 1][0]:
		return (perfil[n - 1] as Array).slice(1)
	for k in n - 1:
		var a: Array = perfil[k]
		var b: Array = perfil[k + 1]
		if z <= a[0] and z >= b[0]:
			var t: float = (a[0] - z) / (a[0] - b[0])
			var r: Array = []
			for j in range(1, 7):
				r.append(lerpf(a[j], b[j], t))
			return r
	return (perfil[n - 1] as Array).slice(1)


## Meia-largura e altura da seccao num `t`.
##
## `t` vai de -1 (assoalho) por 0 (cintura) ate 1 (topo). O ponto do OMBRO nao
## esta na tabela: e derivado de `ombro` = (fracao de altura, fracao de largura).
## A defasagem entre as duas e o que arqueia a seccao — 0.66/0.34 da a cupula do
## Fusca, 0.80/0.20 da a lateral quase reta de um sedan com so um chanfro no
## encontro com o teto.
##
## Toda consulta passa por aqui, e nao por uma reta da cintura ao topo. Com a
## reta, todo detalhe acima da cintura cai DENTRO da lataria: no Fusca as tres
## janelas de cada lado sumiram inteiras, engolidas pela barriga do ombro.
static func secao(e: Array, t: float, ombro: Vector2) -> Vector2:
	if t < 0.0:
		return Vector2(lerpf(e[W_CINT], e[W_BOT], -t), lerpf(e[CINT], e[BOT], -t))
	var w_omb: float = lerpf(e[W_CINT], e[W_TOPO], ombro.y)
	var y_omb: float = lerpf(e[CINT], e[TOPO], ombro.x)
	if t <= ombro.x:
		var k: float = t / ombro.x
		return Vector2(lerpf(e[W_CINT], w_omb, k), lerpf(e[CINT], y_omb, k))
	var k2: float = (t - ombro.x) / (1.0 - ombro.x)
	return Vector2(lerpf(w_omb, e[W_TOPO], k2), lerpf(y_omb, e[TOPO], k2))


## Ponto na lateral do casco. `s` e o lado (+1 / -1).
static func ponto_lado(perfil: Array, ombro: Vector2, z: float, t: float,
		s: float) -> Vector3:
	var wy := secao(estacao(perfil, z), t, ombro)
	return Vector3(s * wy.x, wy.y, z)


## Ponto na superficie de cima. `u` de -1 a 1 atravessa o carro.
static func ponto_topo(perfil: Array, z: float, u: float) -> Vector3:
	var e := estacao(perfil, z)
	return Vector3(u * e[W_TOPO], e[TOPO], z)


## Normal da superficie de cima num Z, para descolar friso e veneziana da
## lataria sem que afundem quando o painel sobe.
static func normal_topo(perfil: Array, z: float) -> Vector3:
	var d := 0.04
	var a := estacao(perfil, z + d)
	var b := estacao(perfil, z - d)
	return Vector3(0.0, 2.0 * d, -(a[TOPO] - b[TOPO])).normalized()


## Base orientada com a superficie de cima, para grudar peca chapada nela.
static func base_topo(perfil: Array, z: float) -> Basis:
	var n := normal_topo(perfil, z)
	return Basis(Vector3.RIGHT, n.cross(Vector3.RIGHT).normalized(), n)


## Meia-largura do casco numa altura. Busca por amostragem porque a relacao
## y->t deixou de ser linear quando o ombro entrou, e resolver na mao dava X
## errado no pe do para-lama — que e onde qualquer fresta abre para dentro.
static func x_casco(perfil: Array, ombro: Vector2, z: float, y: float) -> float:
	var e := estacao(perfil, z)
	if y < e[CINT]:
		var t2: float = clampf(inverse_lerp(e[CINT], e[BOT], y), 0.0, 1.0)
		return lerpf(e[W_CINT], e[W_BOT], t2)
	var melhor := 0.0
	var dist := INF
	for k in 13:
		var t := float(k) / 12.0
		var wy := secao(e, t, ombro)
		var d: float = absf(wy.y - y)
		if d < dist:
			dist = d
			melhor = t
	return secao(e, melhor, ombro).x


# --------------------------------------------------------------------------
# Varrer o casco
# --------------------------------------------------------------------------

## O anel de oito pontos de uma estacao, em ordem de volta.
static func anel(e: Array, ombro: Vector2) -> Array:
	var o := secao(e, ombro.x, ombro)
	return [
		Vector3(-e[W_BOT], e[BOT], 0.0), Vector3(e[W_BOT], e[BOT], 0.0),
		Vector3(e[W_CINT], e[CINT], 0.0), Vector3(o.x, o.y, 0.0),
		Vector3(e[W_TOPO], e[TOPO], 0.0), Vector3(-e[W_TOPO], e[TOPO], 0.0),
		Vector3(-o.x, o.y, 0.0), Vector3(-e[W_CINT], e[CINT], 0.0),
	]


## Varre o perfil: oito faixas por trecho, mais as tampas do bico e do rabo.
##
## `tinta` recebe a altura e devolve a cor — e por onde entra a sujeira que sobe
## do barro na soleira ao creme no teto.
static func casco(dados: Dictionary, perfil: Array, ombro: Vector2,
		celula: Vector2i, tinta: Callable, pular_topo_z: float = -1000.0,
		tampa_tras: bool = true) -> void:
	var n := perfil.size()
	for k in n - 1:
		var ea: Array = (perfil[k] as Array).slice(1)
		var eb: Array = (perfil[k + 1] as Array).slice(1)
		var za: float = perfil[k][0]
		var zb: float = perfil[k + 1][0]
		var ra := anel(ea, ombro)
		var rb := anel(eb, ombro)
		var eixo_a := Vector3(0.0, (ea[BOT] + ea[TOPO]) * 0.5, za)
		var eixo_b := Vector3(0.0, (eb[BOT] + eb[TOPO]) * 0.5, zb)
		for j in 8:
			# j == 4 e a faixa do teto (os dois pontos em TOPO). A picape pula
			# essa faixa na cacamba para o vao ficar aberto, nao um teto de perua.
			if j == 4 and (za + zb) * 0.5 <= pular_topo_z:
				continue
			var j2 := (j + 1) % 8
			var q0: Vector3 = ra[j] + Vector3(0, 0, za)
			var q1: Vector3 = ra[j2] + Vector3(0, 0, za)
			var q2: Vector3 = rb[j2] + Vector3(0, 0, zb)
			var q3: Vector3 = rb[j] + Vector3(0, 0, zb)
			var meio := (q0 + q1 + q2 + q3) * 0.25
			var fora := meio - (eixo_a + eixo_b) * 0.5
			if not fora.is_finite() or fora.length_squared() < 1e-12:
				fora = Vector3.UP
			else:
				fora = fora.normalized()
			# O assoalho e a unica faixa que ninguem ve de perto: vai escura
			# para nao devolver luz de baixo e denunciar que o carro e oco.
			var cel := Carroceria.C_FUNDO if j == 0 else celula
			var esc := 0.35 if j == 0 else 1.0
			quad(dados, q0, q1, q2, q3, cel,
				tinta.call(q0.y) * esc, tinta.call(q1.y) * esc,
				tinta.call(q2.y) * esc, tinta.call(q3.y) * esc, fora)
	tampa(dados, perfil, ombro, 0, celula, tinta, Vector3.BACK)
	if tampa_tras:
		tampa(dados, perfil, ombro, n - 1, celula, tinta, Vector3.FORWARD)


## Fecha uma ponta do varrido. Quatro triangulos por ponta, e sao eles que
## impedem de ver o carro por dentro quando ele vem de frente.
static func tampa(dados: Dictionary, perfil: Array, ombro: Vector2, k: int,
		celula: Vector2i, tinta: Callable, fora: Vector3) -> void:
	var e: Array = (perfil[k] as Array).slice(1)
	var z: float = perfil[k][0]
	var r := anel(e, ombro)
	for j in range(1, 7):
		var a: Vector3 = r[0] + Vector3(0, 0, z)
		var b: Vector3 = r[j] + Vector3(0, 0, z)
		var c: Vector3 = r[j + 1] + Vector3(0, 0, z)
		tri(dados, a, b, c, celula,
			tinta.call(a.y), tinta.call(b.y), tinta.call(c.y), fora)


# --------------------------------------------------------------------------
# Primitivas de malha
# --------------------------------------------------------------------------

## Quatro pontos, uma celula do atlas, uma cor por vertice.
##
## `fora` diz para que lado a face olha. Nao da para deduzir do poligono: os
## dois lados de um carro sao a mesma sequencia espelhada em X, o que produz a
## MESMA ordem de giro nos dois e faz o culling comer um deles.
##
## CONVENCAO DE GIRO DO PROJETO: a face aparece do lado OPOSTO ao produto
## vetorial do seu giro. Quem prova isso e PSXMesh.placa_dados, que declara
## normal +Z e emite [0,2,1] — cujo produto vetorial da -Z; a calota em
## Carroceria._roda faz igual. Escrever o giro "para o lado da normal", que e o
## instinto, deixa TODA face virada para dentro: o carro vira um casco oco em
## que se ve o assoalho escuro por cima e a lataria some. Custou tres rodadas de
## depuracao no Fusca; nao reinventar.
static func quad(dados: Dictionary, p0: Vector3, p1: Vector3, p2: Vector3,
		p3: Vector3, celula: Vector2i, c0: Color, c1: Color, c2: Color,
		c3: Color, fora: Vector3) -> void:
	var r := Carroceria.uv(celula)
	var v: PackedVector3Array = dados["v"]
	var n: PackedVector3Array = dados["n"]
	var u: PackedVector2Array = dados["uv"]
	var cc: PackedColorArray = dados["c"]
	var i: PackedInt32Array = dados["i"]
	var normal := (p1 - p0).cross(p3 - p0)
	if normal.length_squared() < 1e-12:
		normal = (p2 - p1).cross(p0 - p1)
	normal = normal.normalized()
	var invertido := normal.dot(fora) < 0.0
	if invertido:
		normal = -normal
	# Subdivisao. Painel grande num quadrilatero so faz a UV afim do
	# psx_surface escorregar junto com a camera, que e o defeito que o resto do
	# jogo nao tem porque PSXMesh.placa_dados subdivide em MAX_QUAD_M. Detalhe
	# pequeno — friso, macaneta, veneziana — nao passa do limite e continua
	# saindo em dois triangulos, entao isto nao cobra nada de quem nao precisa.
	var passo_m: float = Carroceria.PASSO_PAINEL
	var cols := maxi(1, ceili(
		maxf(p0.distance_to(p1), p3.distance_to(p2)) / passo_m))
	var linhas := maxi(1, ceili(
		maxf(p0.distance_to(p3), p1.distance_to(p2)) / passo_m))
	var base := v.size()
	for j in linhas + 1:
		var fy := float(j) / float(linhas)
		for k in cols + 1:
			var fx := float(k) / float(cols)
			v.append(p0.lerp(p1, fx).lerp(p3.lerp(p2, fx), fy))
			n.append(normal)
			cc.append(c0.lerp(c1, fx).lerp(c3.lerp(c2, fx), fy))
			u.append(r.position + Vector2(fx, 1.0 - fy) * r.size)
	var larg := cols + 1
	for j in linhas:
		for k in cols:
			var q := base + j * larg + k
			if invertido:
				i.append_array([q, q + 1, q + larg + 1,
					q, q + larg + 1, q + larg])
			else:
				i.append_array([q, q + larg + 1, q + 1,
					q, q + larg, q + larg + 1])
	dados["v"] = v
	dados["n"] = n
	dados["uv"] = u
	dados["c"] = cc
	dados["i"] = i


static func tri(dados: Dictionary, p0: Vector3, p1: Vector3, p2: Vector3,
		celula: Vector2i, c0: Color, c1: Color, c2: Color,
		fora: Vector3) -> void:
	var r := Carroceria.uv(celula)
	var v: PackedVector3Array = dados["v"]
	var n: PackedVector3Array = dados["n"]
	var u: PackedVector2Array = dados["uv"]
	var cc: PackedColorArray = dados["c"]
	var i: PackedInt32Array = dados["i"]
	var normal := (p1 - p0).cross(p2 - p0).normalized()
	var invertido := normal.dot(fora) < 0.0
	if invertido:
		normal = -normal
	var base := v.size()
	for p: Vector3 in [p0, p1, p2]:
		v.append(p)
		n.append(normal)
	cc.append(c0)
	cc.append(c1)
	cc.append(c2)
	u.append(r.position + Vector2(0.0, r.size.y))
	u.append(r.position + r.size)
	u.append(r.position)
	if invertido:
		i.append_array([base, base + 1, base + 2])
	else:
		i.append_array([base, base + 2, base + 1])
	dados["v"] = v
	dados["n"] = n
	dados["uv"] = u
	dados["c"] = cc
	dados["i"] = i


## Placa plana com uma celula do atlas.
static func plana(dados: Dictionary, tamanho: Vector2, xform: Transform3D,
		cor: Color, celula: Vector2i) -> void:
	var d := PSXMesh.placa_dados(tamanho, Carroceria.PASSO_PAINEL, Color.WHITE)
	var r := Carroceria.uv(celula)
	var uvs: PackedVector2Array = d["uv"]
	for k in uvs.size():
		uvs[k] = r.position + uvs[k] * r.size
	d["uv"] = uvs
	PSXMesh.acumular_tingido(dados, d, xform, cor)


## Disco facetado virado para +Z da base. Farol redondo com celula quadrada nao
## passa por redondo nem a trinta metros.
static func disco(dados: Dictionary, centro: Vector3, giro: Basis, raio: float,
		celula: Vector2i, cor: Color, lados: int = 8) -> void:
	var r := Carroceria.uv(celula)
	var v: PackedVector3Array = dados["v"]
	var n: PackedVector3Array = dados["n"]
	var u: PackedVector2Array = dados["uv"]
	var cc: PackedColorArray = dados["c"]
	var i: PackedInt32Array = dados["i"]
	var normal := (giro * Vector3.BACK).normalized()
	var base := v.size()
	v.append(centro)
	n.append(normal)
	cc.append(cor)
	u.append(r.get_center())
	for k in lados + 1:
		var a := TAU * float(k) / float(lados)
		v.append(centro + giro * Vector3(cos(a) * raio, sin(a) * raio, 0.0))
		n.append(normal)
		cc.append(cor)
		u.append(r.get_center() + Vector2(cos(a), -sin(a)) * r.size * 0.5)
	for k in lados:
		i.append_array([base, base + 2 + k, base + 1 + k])
	dados["v"] = v
	dados["n"] = n
	dados["uv"] = u
	dados["c"] = cc
	dados["i"] = i


## Puxa os quatro cantos de um quadrilatero na direcao do centro.
static func inset(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
		f: float) -> Array:
	var c := (p0 + p1 + p2 + p3) * 0.25
	return [p0.lerp(c, f), p1.lerp(c, f), p2.lerp(c, f), p3.lerp(c, f)]


# --------------------------------------------------------------------------
# Pintura
# --------------------------------------------------------------------------

## Sujeira por altura: barro na soleira, cor limpa no teto.
##
## Sai de graca por cor de vertice. A alternativa era uma celula de atlas por
## faixa de altura, que e textura que este projeto nao tem.
static func sujo(cor: Color, barro: Color, y: float, teto: float,
		forca: float) -> Color:
	var f := clampf((teto - y) / teto, 0.0, 1.0)
	return cor.lerp(barro, f * f * forca)
