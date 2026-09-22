## Fachada com vao de verdade: a parede tem furo, e o furo tem fundo.
##
## Por que existe
## -------------
## Ate aqui a janela era uma placa colada 5 cm na frente de uma parede lisa
## (KitFachada, KitModular.fachada). De frente passava; de lado, e de qualquer
## angulo com sol, a casa inteira lia como caixa com adesivo: nenhuma janela
## tinha espessura, nenhuma projetava sombra no proprio vao, e nao havia como uma
## janela estar ABERTA, porque atras da placa nao existia nada.
##
## Casa de Minas tem parede grossa (adobe e tijolo macico de 25 a 40 cm): a
## janela fica funda, com a luz batendo no peitoril e a sombra da verga caindo
## no vidro. E isso, mais do que qualquer textura, que faz a fachada ler como
## alvenaria.
##
## O que faz
## ---------
## `erguer` monta o plano da fachada SEM os retangulos dos vaos, e em cada vao
## as faces do recuo (as duas ombreiras, a face de baixo da verga — reta ou em
## arco abatido — e o peitoril, ou a soleira na porta). O conteudo do vao
## (vidro, folha, cortina, o comodo atras da janela aberta) nao sai daqui: quem
## monta a fachada preenche cada vao a partir do quadro que `erguer` devolve (ver
## JanelaViva).
##
## Sem fresta para o limbo
## -----------------------
## Atras da fachada nao ha nada: a massa do predio nao tem face da frente. Uma
## fresta de rasterizacao na parede mostraria o ceu (memoria do projeto: junta
## em T pisca limbo). Por isso:
##   - a parede sai em faixas horizontais, cortadas em toda altura de borda de
##     vao; cada trecho de faixa e costurado em ziguezague entre os vertices da
##     linha de baixo e os da linha de cima, e cada linha tem os cortes das DUAS
##     faixas que ela separa. Nenhum vertice cai no meio da aresta de outro;
##   - ombreira, verga, peitoril e timpano usam os mesmos cortes, calculados pela
##     mesma funcao (`PlanoVazado.ponto`), entao caem no mesmo lugar bit a bit;
##   - por padrao cada vao ganha uma tampa escura rente ao fundo do recuo, que so
##     sai quando quem preenche pede (`"tampa": false`) — a janela aberta, que
##     monta o comodo inteiro.
## A regua e tests/bancada_parede_vazada.gd (raio de todo angulo e juntas em T).
class_name ParedeVazada
extends RefCounted

## Lado maximo de uma celula, em metros (a UV afim do PS1 empena acima disso,
## ART-BIBLE secao 4).
const CELULA := 2.0
## Uma repeticao de textura a cada 2 m, a mesma do KitModular.
const UV_POR_M := 0.5
## Cor da tampa atras do vao: o escuro de um comodo sem luz.
const COR_TAMPA := Color(0.07, 0.065, 0.06)
## Quantos segmentos tem o arco de um vao em arco abatido.
const SEGMENTOS_ARCO := 6
## Recuo padrao do fundo do vao atras do plano da fachada.
const PROF_PADRAO := 0.18

const _EPS := 0.0005


## Acumulador de uma malha. Os arrays sao membros de proposito: PackedArray
## passado por variavel e copiado na escrita, e um append por vertice num
## array compartilhado vira conta quadratica.
class Malha extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var c := PackedColorArray()
	var i := PackedInt32Array()

	func vertice(p: Vector3, normal: Vector3, a_uv: Vector2, a_uv2: Vector2,
			cor: Color) -> int:
		var k := v.size()
		v.append(p)
		n.append(normal)
		uv.append(a_uv)
		uv2.append(a_uv2)
		c.append(cor)
		return k

	## Quad a-b-c-e (em volta), com a face visivel virada para `normal`. A face
	## aparece do lado OPOSTO ao produto vetorial (regra do projeto, ver
	## PSXMesh.placa_dados), entao a ordem sai da conta, e nao decorada.
	func quad(a: int, b: int, cc: int, e: int, normal: Vector3) -> void:
		var produto := (v[b] - v[a]).cross(v[cc] - v[a])
		if produto.dot(normal) > 0.0:
			i.append_array([a, cc, b, a, e, cc])
		else:
			i.append_array([a, b, cc, a, cc, e])

	## Triangulo com a mesma regra. O degenerado (tres pontos na reta) sai.
	func tri(a: int, b: int, cc: int, normal: Vector3) -> void:
		var produto := (v[b] - v[a]).cross(v[cc] - v[a])
		if produto.length_squared() < 1e-12:
			return
		if produto.dot(normal) > 0.0:
			i.append_array([a, cc, b])
		else:
			i.append_array([a, b, cc])

	func despejar(sup: Dictionary, material: StringName) -> void:
		if i.is_empty():
			return
		KitModular.por(sup, material, {"v": v, "n": n, "uv": uv, "uv2": uv2,
			"c": c, "i": i}, Transform3D.IDENTITY)


## O plano da fachada: onde ela esta e para onde olha.
class PlanoVazado extends RefCounted:
	var base: Vector3
	var lateral: Vector3
	var normal: Vector3
	var meia: float
	var altura: float
	var direcao: int

	## Ponto do plano: `x` ao longo da fachada, `y` de altura, `prof` para
	## dentro. Toda peca que encosta em outra passa por aqui, e por isso o mesmo
	## (x, y) da sempre o mesmo Vector3.
	func ponto(x: float, y: float, prof: float) -> Vector3:
		return base + lateral * x + Vector3(0.0, y, 0.0) - normal * prof

	## UV em metros ancorada na borda da parede, continua de trecho para trecho.
	func uv(x: float, y: float) -> Vector2:
		return Vector2((x + meia) * UV_POR_M, (altura - y) * UV_POR_M)

	func uv2(x: float, y: float) -> Vector2:
		return Vector2((x + meia) / (meia * 2.0), (altura - y) / altura)


## Levanta a fachada de `largura` x `altura` com os vaos pedidos e devolve o
## quadro de cada vao, na mesma ordem dos vaos que sobraram (vao que nao cabe na
## parede, ou que invade outro, e descartado).
##
## `base` e o ponto do plano da fachada no meio da largura, no pe da parede.
## `direcao` e a de KitModular.parede (0 = +Z, 1 = +X, 2 = -Z, 3 = -X).
##
## Cada vao e um Dictionary:
##   "rect":  Rect2 em metros no plano da fachada. x a partir do meio da largura
##            (positivo para `lateral`, que e a direita de quem olha a fachada),
##            y a partir do pe da parede.
##   "prof":  recuo do fundo do vao atras do plano, em metros (PROF_PADRAO).
##   "arco":  flecha do arco abatido da verga, em metros (0 = verga reta). A
##            altura do retangulo inclui a flecha.
##   "tampa": false quando quem preenche fecha o fundo sozinho (padrao true).
##   "cor_recuo", "material_recuo": acabamento do recuo, se diferente da parede.
##   Qualquer outra chave volta intacta no quadro (quem monta usa para lembrar o
##   que ia em cada vao).
##
## `faixas`: bandas horizontais de outra cor ou outro material na MESMA grade
## (o barrado pintado da casa colonial, o andar de tijolo aparente da casa por
## terminar). Cada uma e {"y0", "y1", "cor", "material"}; as linhas delas entram
## nos cortes, entao nao ha junta em T entre a banda e o resto da parede.
##
## O quadro devolvido tem, alem das chaves pedidas: "rect", "prof", "arco",
## "boca" (meio do vao no plano da fachada), "fundo" (meio do vao no plano do
## fundo), "pe" (meio da base do vao no plano da fachada), "lateral", "normal",
## "giro", "direcao", "largura", "altura".
static func erguer(sup: Dictionary, material: StringName, base: Vector3,
		largura: float, altura: float, direcao: int, cor: Color,
		vaos: Array, faixas: Array = []) -> Array[Dictionary]:
	var q := PlanoVazado.new()
	q.base = base
	q.lateral = KitModular._lateral(direcao)
	q.normal = KitModular._normal(direcao)
	q.meia = largura * 0.5
	q.altura = altura
	q.direcao = direcao
	var meia := q.meia

	var retangulos: Array[Rect2] = []
	var flechas: Array[float] = []
	var limpos: Array[Dictionary] = []
	for vao: Dictionary in vaos:
		var r: Rect2 = vao["rect"]
		var x0 := maxf(r.position.x, -meia + 0.05)
		var x1 := minf(r.end.x, meia - 0.05)
		var y0 := maxf(r.position.y, 0.0)
		var y1 := minf(r.end.y, altura - 0.05)
		if x1 - x0 < 0.1 or y1 - y0 < 0.1:
			continue
		var novo := Rect2(x0, y0, x1 - x0, y1 - y0)
		# Vao que invade outro sai: dois furos no mesmo lugar deixariam uma
		# parede de largura zero entre eles.
		var colide := false
		for outro: Rect2 in retangulos:
			if outro.grow(0.04).intersects(novo):
				colide = true
				break
		if colide:
			continue
		var limpo := vao.duplicate()
		limpo["rect"] = novo
		var flecha := clampf(float(vao.get("arco", 0.0)), 0.0,
			minf(novo.size.x * 0.5, novo.size.y * 0.45))
		limpo["arco"] = flecha
		retangulos.append(novo)
		flechas.append(flecha)
		limpos.append(limpo)

	# As linhas horizontais: pe e topo da parede, pe e topo de cada vao, o
	# nascimento de cada arco, e o que for preciso para nenhuma faixa passar de
	# CELULA metros.
	var ys: Array[float] = [0.0, altura]
	for f: Dictionary in faixas:
		ys.append_array([clampf(float(f["y0"]), 0.0, altura), clampf(float(f["y1"]), 0.0, altura)])
	for k in retangulos.size():
		ys.append_array([retangulos[k].position.y, retangulos[k].end.y])
		if flechas[k] > 0.0:
			ys.append(retangulos[k].end.y - flechas[k])
	ys = _cortes(ys)

	# Cortes de cada faixa: as bordas da parede e dos vaos que ela atravessa (e
	# as pontas do arco deles), subdivididos em CELULA.
	var cortes_faixa: Array = []
	for j in ys.size() - 1:
		var c: Array[float] = [-meia, meia]
		for k in retangulos.size():
			var r := retangulos[k]
			if r.position.y < ys[j + 1] - _EPS and r.end.y > ys[j] + _EPS:
				c.append_array([r.position.x, r.end.x])
				if flechas[k] > 0.0:
					for s in range(1, SEGMENTOS_ARCO):
						c.append(lerpf(r.position.x, r.end.x, float(s) / SEGMENTOS_ARCO))
		cortes_faixa.append(_cortes(c))
	# Cortes de cada linha: os das duas faixas que ela separa.
	var linhas: Array = []
	for j in ys.size():
		var junta: Array[float] = []
		if j > 0:
			junta.append_array(cortes_faixa[j - 1])
		if j < ys.size() - 1:
			junta.append_array(cortes_faixa[j])
		linhas.append(_unicos(junta))

	var parede := Malha.new()
	var cache := {}
	# Uma malha e um cache de vertices por material de banda.
	var bandas := {material: parede}
	var caches := {String(material) + cor.to_html(): cache}
	for j in ys.size() - 1:
		var ya := ys[j]
		var yb := ys[j + 1]
		var m_faixa := parede
		var c_faixa := cache
		var cor_faixa := cor
		for f: Dictionary in faixas:
			var meio_y := (ya + yb) * 0.5
			if meio_y > float(f["y0"]) and meio_y < float(f["y1"]):
				var mat_f: StringName = f.get("material", material)
				cor_faixa = f.get("cor", cor)
				if not bandas.has(mat_f):
					bandas[mat_f] = Malha.new()
				m_faixa = bandas[mat_f]
				# Um cache por banda (material e cor): na linha entre a banda e a
				# parede cada lado tem o seu vertice, no mesmo ponto.
				var chave_c := String(mat_f) + cor_faixa.to_html()
				if not caches.has(chave_c):
					caches[chave_c] = {}
				c_faixa = caches[chave_c]
		# Trechos da faixa fora dos vaos.
		var fechados: Array[Vector2] = []
		for r: Rect2 in retangulos:
			if r.position.y < yb - _EPS and r.end.y > ya + _EPS:
				fechados.append(Vector2(r.position.x, r.end.x))
		fechados.sort()
		var cursor := -meia
		var trechos: Array[Vector2] = []
		for f: Vector2 in fechados:
			if f.x > cursor + _EPS:
				trechos.append(Vector2(cursor, f.x))
			cursor = maxf(cursor, f.y)
		if meia > cursor + _EPS:
			trechos.append(Vector2(cursor, meia))
		for t: Vector2 in trechos:
			var de_baixo := _cadeia_x(m_faixa, c_faixa, q, cor_faixa, linhas[j], t.x, t.y, ya)
			var de_cima := _cadeia_x(m_faixa, c_faixa, q, cor_faixa, linhas[j + 1], t.x, t.y, yb)
			_ziguezague(m_faixa, de_baixo, de_cima, q.normal)

	var saida: Array[Dictionary] = []
	var recuos := {}
	var tampa := Malha.new()
	for limpo: Dictionary in limpos:
		var mat: StringName = limpo.get("material_recuo", material)
		if not recuos.has(mat):
			recuos[mat] = parede if mat == material else Malha.new()
		saida.append(_recuo(recuos[mat], parede, tampa, cor, q, limpo, ys, linhas))
	parede.despejar(sup, material)
	for mat_f: StringName in bandas:
		if bandas[mat_f] != parede:
			(bandas[mat_f] as Malha).despejar(sup, mat_f)
	for mat: StringName in recuos:
		if recuos[mat] != parede:
			(recuos[mat] as Malha).despejar(sup, mat)
	tampa.despejar(sup, &"reboco")
	return saida


## Ordena, tira repetidos e subdivide o que passar de CELULA.
static func _cortes(valores: Array[float]) -> Array[float]:
	var unicos := _unicos(valores)
	var saida: Array[float] = [unicos[0]]
	for k in range(1, unicos.size()):
		var de := saida[-1]
		var ate := unicos[k]
		var n := maxi(1, ceili((ate - de) / CELULA - 0.001))
		for m in range(1, n + 1):
			saida.append(ate if m == n else lerpf(de, ate, float(m) / n))
	return saida


## Ordena e junta o que estiver a menos de meio milimetro, ficando com o
## primeiro: as duas faixas de uma linha leem o MESMO numero.
static func _unicos(valores: Array[float]) -> Array[float]:
	var ordem := valores.duplicate()
	ordem.sort()
	var saida: Array[float] = []
	for v: float in ordem:
		if saida.is_empty() or v - saida[-1] > _EPS:
			saida.append(v)
	return saida


## Os vertices da linha `y` entre `de` e `ate`, na ordem de x.
static func _cadeia_x(m: Malha, cache: Dictionary, q: PlanoVazado, cor: Color,
		cortes: Array[float], de: float, ate: float, y: float) -> PackedInt32Array:
	var saida := PackedInt32Array()
	for x: float in cortes:
		if x < de - _EPS or x > ate + _EPS:
			continue
		var chave := Vector2(x, y)
		var k: int
		if cache.has(chave):
			k = cache[chave]
		else:
			k = m.vertice(q.ponto(x, y, 0.0), q.normal, q.uv(x, y), q.uv2(x, y), cor)
			cache[chave] = k
		saida.append(k)
	return saida


## Costura duas cadeias paralelas (de baixo e de cima, ou da esquerda e da
## direita) em triangulos, andando sempre pela que esta mais atras.
static func _ziguezague(m: Malha, a: PackedInt32Array, b: PackedInt32Array,
		normal: Vector3) -> void:
	if a.size() < 1 or b.size() < 1 or a.size() + b.size() < 3:
		return
	# Direcao em que as cadeias correm: da primeira a ultima ponta de uma delas.
	var longa := a if a.size() >= b.size() else b
	var eixo := m.v[longa[longa.size() - 1]] - m.v[longa[0]]
	var i := 0
	var j := 0
	while i < a.size() - 1 or j < b.size() - 1:
		var anda_a := j >= b.size() - 1 or (i < a.size() - 1
			and m.v[a[i + 1]].dot(eixo) <= m.v[b[j + 1]].dot(eixo))
		if anda_a:
			m.tri(a[i], b[j], a[i + 1], normal)
			i += 1
		else:
			m.tri(a[i], b[j], b[j + 1], normal)
			j += 1


## As faces do recuo de um vao, mais a tampa, e o quadro dele.
static func _recuo(m: Malha, parede: Malha, tampa: Malha, cor: Color, q: PlanoVazado,
		vao: Dictionary, ys: Array[float], linhas: Array) -> Dictionary:
	var r: Rect2 = vao["rect"]
	var prof := float(vao.get("prof", PROF_PADRAO))
	var flecha: float = vao["arco"]
	var tinta: Color = vao.get("cor_recuo", cor)
	# O recuo e um pouco mais escuro que a parede: pega menos ceu. Sem isso a
	# ombreira ao sol e o reboco da fachada viram um plano so.
	var sombra := tinta.darkened(0.08)
	var nascente := r.end.y - flecha

	# Ombreiras: da base ate o nascimento do arco, cortadas em cada linha.
	var cortes_y: Array[float] = []
	for y: float in ys:
		if y >= r.position.y - _EPS and y <= nascente + _EPS:
			cortes_y.append(y)
	for lado: int in [0, 1]:
		var x := r.position.x if lado == 0 else r.end.x
		var n := q.lateral if lado == 0 else -q.lateral
		for k in cortes_y.size() - 1:
			_faixa(m, q, sombra, Vector2(x, cortes_y[k]), Vector2(x, cortes_y[k + 1]),
				prof, n)

	# Peitoril, ou a soleira na porta: sem ela o raio que entra baixo pelo vao
	# da porta passa por baixo de tudo e acha o avesso da parede.
	var de_baixo := _na_linha(ys, linhas, r.position.y, r.position.x, r.end.x)
	for k in de_baixo.size() - 1:
		_faixa(m, q, tinta, Vector2(de_baixo[k], r.position.y),
			Vector2(de_baixo[k + 1], r.position.y), prof, Vector3.UP)

	# Verga: reta, ou os segmentos do arco. Na reta a face olha para baixo; no
	# arco cada segmento olha para o centro do circulo, abaixo do vao.
	var de_cima := _na_linha(ys, linhas, r.end.y, r.position.x, r.end.x)
	var raio := 0.0
	if flecha > 0.0:
		raio = (r.size.x * r.size.x * 0.25 + flecha * flecha) / (2.0 * flecha)
	var centro_arco := Vector2(r.get_center().x, r.end.y - raio)
	for k in de_cima.size() - 1:
		var xa := de_cima[k]
		var xb := de_cima[k + 1]
		var ya := _y_verga(r, flecha, xa)
		var yb := _y_verga(r, flecha, xb)
		var n := Vector3.DOWN
		if flecha > 0.0:
			var para_dentro := centro_arco - Vector2((xa + xb) * 0.5, (ya + yb) * 0.5)
			if para_dentro.length() > 0.001:
				para_dentro = para_dentro.normalized()
				n = (q.lateral * para_dentro.x + Vector3.UP * para_dentro.y).normalized()
			# O timpano: a parede entre a curva do arco e a linha reta de cima.
			var esquerda := _cadeia_y(parede, q, cor, xa, ya, r.end.y, ys)
			var direita := _cadeia_y(parede, q, cor, xb, yb, r.end.y, ys)
			_ziguezague(parede, esquerda, direita, q.normal)
		_faixa(m, q, sombra, Vector2(xa, ya), Vector2(xb, yb), prof, n)

	# A tampa fica rente ao fim do recuo, e nao atras dele: com folga o raio
	# rasante escorregava entre a ombreira e a tampa para dentro da massa. Ela
	# passa 2 cm de cada lado, escondida atras das ombreiras.
	if bool(vao.get("tampa", true)):
		var n := q.normal
		tampa.quad(
			tampa.vertice(q.ponto(r.position.x - 0.02, r.position.y - 0.02, prof), n,
				Vector2(0, 1), Vector2(0, 1), COR_TAMPA),
			tampa.vertice(q.ponto(r.end.x + 0.02, r.position.y - 0.02, prof), n,
				Vector2(1, 1), Vector2(1, 1), COR_TAMPA),
			tampa.vertice(q.ponto(r.end.x + 0.02, r.end.y + 0.02, prof), n,
				Vector2(1, 0), Vector2(1, 0), COR_TAMPA),
			tampa.vertice(q.ponto(r.position.x - 0.02, r.end.y + 0.02, prof), n,
				Vector2(0, 0), Vector2(0, 0), COR_TAMPA), n)

	var saida := vao.duplicate()
	saida.merge({
		"rect": r, "prof": prof, "arco": flecha, "direcao": q.direcao,
		"boca": q.ponto(r.get_center().x, r.get_center().y, 0.0),
		"fundo": q.ponto(r.get_center().x, r.get_center().y, prof),
		"pe": q.ponto(r.get_center().x, r.position.y, 0.0),
		"lateral": q.lateral, "normal": q.normal, "giro": atan2(q.normal.x, q.normal.z),
		"largura": r.size.x, "altura": r.size.y,
	}, true)
	return saida


## Os cortes da linha de altura `y` entre `de` e `ate`.
static func _na_linha(ys: Array[float], linhas: Array, y: float, de: float,
		ate: float) -> Array[float]:
	var saida: Array[float] = []
	for j in ys.size():
		if absf(ys[j] - y) > _EPS:
			continue
		for x: float in linhas[j]:
			if x >= de - _EPS and x <= ate + _EPS:
				saida.append(x)
		break
	return saida


## Um lado do timpano, de baixo para cima, passando pelas linhas da parede.
static func _cadeia_y(m: Malha, q: PlanoVazado, cor: Color, x: float, y0: float,
		topo: float, ys: Array[float]) -> PackedInt32Array:
	var alturas: Array[float] = [y0]
	for y: float in ys:
		if y > y0 + _EPS and y < topo - _EPS:
			alturas.append(y)
	if topo - y0 > _EPS:
		alturas.append(topo)
	var saida := PackedInt32Array()
	for y: float in alturas:
		saida.append(m.vertice(q.ponto(x, y, 0.0), q.normal, q.uv(x, y), q.uv2(x, y), cor))
	return saida


## Altura da face de baixo da verga em `x`. Arco abatido: um trecho de circulo
## que passa pelas duas pontas do nascimento e sobe `flecha` no meio.
static func _y_verga(r: Rect2, flecha: float, x: float) -> float:
	if flecha <= 0.0:
		return r.end.y
	var meia := r.size.x * 0.5
	var raio := (meia * meia + flecha * flecha) / (2.0 * flecha)
	var dx := x - r.get_center().x
	var sobe := sqrt(maxf(raio * raio - dx * dx, 0.0)) - (raio - flecha)
	return r.end.y - flecha + clampf(sobe, 0.0, flecha)


## Faixa do recuo entre dois pontos da borda do vao, do plano da fachada ate o
## fundo, virada para `n`.
static func _faixa(m: Malha, q: PlanoVazado, cor: Color, p: Vector2, r: Vector2,
		prof: float, n: Vector3) -> void:
	var comprimento := p.distance_to(r)
	var a := m.vertice(q.ponto(p.x, p.y, 0.0), n, Vector2(0.0, 0.0),
		Vector2(0.0, 0.0), cor)
	var b := m.vertice(q.ponto(r.x, r.y, 0.0), n,
		Vector2(comprimento * UV_POR_M, 0.0), Vector2(1.0, 0.0), cor)
	var c := m.vertice(q.ponto(r.x, r.y, prof), n,
		Vector2(comprimento * UV_POR_M, prof * UV_POR_M), Vector2(1.0, 1.0), cor)
	var e := m.vertice(q.ponto(p.x, p.y, prof), n,
		Vector2(0.0, prof * UV_POR_M), Vector2(0.0, 1.0), cor)
	m.quad(a, b, c, e, n)
