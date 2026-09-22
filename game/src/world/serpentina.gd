## A rua que sobe o morro em curva: a serpentina da celula de encosta.
##
## Por que existe
## -------------
## A cidade e uma grade: toda rua mora na borda de um chunk, reta. No morro de
## Minas a rua de bairro nao sobe reta — ela corta a encosta de lado, faz a
## volta num cotovelo e corta de volta, e as casas acompanham a curva de frente
## para ela. Sem isso o morro tem ladeira e escadaria, mas nao tem o desenho de
## cidade de morro.
##
## Como convive com a grade
## ------------------------
## A serpentina mora DENTRO de uma celula de 5 x 5 chunks entre quatro avenidas
## (MalhaUrbana.PERIODO). A celula de encosta nao e repartida pelo Tracado: e um
## quarteirao so, com a fileira de casas de sempre de frente para as avenidas
## em volta, e no miolo a serpentina. Ela entra pela avenida do lado de baixo,
## por um vao na fileira, e sai pela do lado de cima. O resto da cidade — o
## transito, a multidao, o mapa por quadra — continua vendo a grade; quem sabe
## da curva e o chunk que a desenha (SerpentinaBuilder), a colisao do chao
## (Relevo.mapa_de_colisao) e o mapa, que risca a linha.
##
## Tudo aqui e funcao pura da celula, com cache: o caminho, as casas e os vaos.
## Coordenadas em metros de MUNDO, no plano XZ.
class_name Serpentina
extends RefCounted

const TAM := MalhaUrbana.TAM
const PERIODO := MalhaUrbana.PERIODO
const LADO := TAM * PERIODO

## Meia largura da pista e largura da calcada, em metros.
const MEIA_PISTA := 3.0
const CALCADA := 1.6
## Desnivel minimo entre as duas avenidas opostas para a celula virar encosta.
const DESNIVEL_MINIMO := 12.0
## Chance de uma celula que se qualifica ter serpentina.
const CHANCE := 60
## Faixa das bordas da celula que e da fileira de frente para a avenida e dos
## quintais dela: a curva e as casas da serpentina ficam para dentro disto.
const BORDA := 26.0
## Quanto a entrada anda reto, da linha da fachada para dentro, antes da curva.
const ENTRADA := 20.0
## Pernas da serpentina (idas e vindas na encosta).
const PERNAS := 3
## Distancia entre dois pontos do caminho amostrado.
const PASSO := 2.0

## Lote das casas da serpentina, e o fundo delas: o mesmo da fileira
## (ChunkBuilder.PROF_PREDIO), porque a parede de fundos e a de FundosBuilder.
const LOTE := 8.0
const FUNDO_CASA := 8.0

static var _cache: Dictionary = {}
static var _trava := Mutex.new()


## A celula (ci, cj) tem serpentina?
static func celula(ci: int, cj: int) -> bool:
	return not dados(ci, cj).is_empty()


## A celula que contem o chunk (cx, cz).
static func celula_do_chunk(cx: int, cz: int) -> Vector2i:
	return Vector2i(floori(float(cx) / float(PERIODO)), floori(float(cz) / float(PERIODO)))


## Os dados da serpentina da celula, ou vazio:
##   caminho   PackedVector2Array, pontos a cada PASSO m, da entrada a saida
##   entradas  Array de {"ponto", "para_dentro"}: onde a rua cruza a linha da
##             fachada, e para que lado ela entra na celula
##   casas     Array de {"centro", "giro", "largura"}: frente da casa no chao
static func dados(ci: int, cj: int) -> Dictionary:
	var chave := Vector2i(ci, cj)
	_trava.lock()
	var achado: Variant = _cache.get(chave)
	_trava.unlock()
	if achado != null:
		return achado
	var novo := _montar(ci, cj)
	_trava.lock()
	if _cache.size() > 2048:
		_cache.clear()
	_cache[chave] = novo
	_trava.unlock()
	return novo


static func _montar(ci: int, cj: int) -> Dictionary:
	# A Praca da Matriz tem tracado ancorado (Tracado._ancora).
	if ci == 1 and cj == -1:
		return {}
	var x0 := ci * PERIODO
	var z0 := cj * PERIODO
	if MalhaUrbana.distrito_de(x0, z0) != MalhaUrbana.Distrito.RESIDENCIAL:
		return {}
	if MalhaUrbana._ruido(ci, cj, 6601) % 100 >= CHANCE:
		return {}
	# O meio de cada lado da celula, na altura do morro.
	var meio := PERIODO / 2
	var oeste := (Morros.bruto(x0, z0 + meio) + Morros.bruto(x0, z0 + meio + 1)) * 0.5
	var leste := (Morros.bruto(x0 + PERIODO, z0 + meio)
		+ Morros.bruto(x0 + PERIODO, z0 + meio + 1)) * 0.5
	var sul := (Morros.bruto(x0 + meio, z0) + Morros.bruto(x0 + meio + 1, z0)) * 0.5
	var norte := (Morros.bruto(x0 + meio, z0 + PERIODO)
		+ Morros.bruto(x0 + meio + 1, z0 + PERIODO)) * 0.5
	var em_x := absf(leste - oeste) >= absf(norte - sul)
	var desnivel := maxf(absf(leste - oeste), absf(norte - sul))
	if desnivel < DESNIVEL_MINIMO:
		return {}

	# Eixo `a` sobe o morro, de 0 (lado de baixo) a LADO; `b` corre ao longo da
	# encosta. `para_mundo` leva (a, b) para XZ de mundo.
	var origem := Vector2(float(x0), float(z0)) * TAM
	var sobe_positivo := (leste > oeste) if em_x else (norte > sul)
	var para_mundo := func(a: float, b: float) -> Vector2:
		var aa := a if sobe_positivo else LADO - a
		return origem + (Vector2(aa, b) if em_x else Vector2(b, aa))

	var rng := RandomNumberGenerator.new()
	rng.seed = MalhaUrbana._ruido(ci, cj, 6607)
	var fachada := MalhaUrbana.recuo(MalhaUrbana.Via.AVENIDA)
	var b_entra := rng.randf_range(BORDA + 14.0, LADO - BORDA - 14.0)
	var b_sai := rng.randf_range(BORDA + 14.0, LADO - BORDA - 14.0)
	# As pernas vao de uma beira a outra da encosta, subindo de uma para a
	# outra; a primeira sai para o lado mais longe da entrada.
	var b_baixo := BORDA + 8.0
	var b_alto := LADO - BORDA - 8.0
	var comeca_alto := b_entra < LADO * 0.5
	var pontos: Array[Vector2] = []
	pontos.append(Vector2(fachada, b_entra))
	pontos.append(Vector2(fachada + ENTRADA, b_entra))
	var a_de := BORDA + 12.0
	var a_ate := LADO - BORDA - 12.0
	# Cada perna corre ao longo da encosta numa altura `a`, de uma beira a outra;
	# o cotovelo entre duas pernas sobe de uma `a` para a seguinte na mesma
	# beira. A primeira comeca onde a entrada chegou.
	for k in PERNAS:
		var a := lerpf(a_de, a_ate, float(k) / float(PERNAS - 1))
		var alto := comeca_alto if k % 2 == 0 else not comeca_alto
		var primeiro := b_baixo if alto else b_alto
		var ultimo := b_alto if alto else b_baixo
		pontos.append(Vector2(a, b_entra if k == 0 else primeiro))
		pontos.append(Vector2(a, ultimo))
	pontos.append(Vector2(LADO - fachada - ENTRADA, b_sai))
	pontos.append(Vector2(LADO - fachada, b_sai))

	var caminho := PackedVector2Array()
	for p: Vector2 in _amostrar(pontos):
		caminho.append(para_mundo.call(p.x, p.y))

	var dentro_entra: Vector2 = para_mundo.call(fachada + 1.0, b_entra) \
		- para_mundo.call(fachada, b_entra)
	var dentro_sai: Vector2 = para_mundo.call(LADO - fachada - 1.0, b_sai) \
		- para_mundo.call(LADO - fachada, b_sai)
	var entradas: Array[Dictionary] = [
		{"ponto": caminho[0], "para_dentro": dentro_entra.normalized()},
		{"ponto": caminho[caminho.size() - 1], "para_dentro": dentro_sai.normalized()},
	]
	var saida := {
		"celula": Vector2i(ci, cj),
		"caminho": caminho,
		"entradas": entradas,
		"retangulo": Rect2(origem, Vector2(LADO, LADO)),
	}
	saida["casas"] = _casas(caminho, Rect2(origem, Vector2(LADO, LADO)), rng)
	return saida


## Catmull-Rom centripeta pelos pontos, amostrada a cada PASSO metros.
static func _amostrar(pontos: Array[Vector2]) -> Array[Vector2]:
	var denso: Array[Vector2] = []
	var n := pontos.size()
	for k in n - 1:
		var p0 := pontos[maxi(k - 1, 0)]
		var p1 := pontos[k]
		var p2 := pontos[k + 1]
		var p3 := pontos[mini(k + 2, n - 1)]
		var passos := maxi(4, ceili(p1.distance_to(p2) / 0.5))
		for s in passos:
			denso.append(_catmull(p0, p1, p2, p3, float(s) / float(passos)))
	denso.append(pontos[n - 1])
	# Reamostra por comprimento de arco.
	var saida: Array[Vector2] = [denso[0]]
	var falta := PASSO
	for k in range(1, denso.size()):
		var a := denso[k - 1]
		var b := denso[k]
		var seg := a.distance_to(b)
		while seg >= falta:
			a = a.lerp(b, falta / seg)
			saida.append(a)
			seg = a.distance_to(b)
			falta = PASSO
		falta -= seg
	if saida[saida.size() - 1].distance_to(denso[denso.size() - 1]) > 0.3:
		saida.append(denso[denso.size() - 1])
	return saida


static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	# Centripeta (alfa 0,5): sem laco nem cuspide no cotovelo.
	var t0 := 0.0
	var t1 := t0 + sqrt(maxf(p0.distance_to(p1), 0.001))
	var t2 := t1 + sqrt(maxf(p1.distance_to(p2), 0.001))
	var t3 := t2 + sqrt(maxf(p2.distance_to(p3), 0.001))
	var tt := lerpf(t1, t2, t)
	var a1 := p0 * ((t1 - tt) / (t1 - t0)) + p1 * ((tt - t0) / (t1 - t0))
	var a2 := p1 * ((t2 - tt) / (t2 - t1)) + p2 * ((tt - t1) / (t2 - t1))
	var a3 := p2 * ((t3 - tt) / (t3 - t2)) + p3 * ((tt - t2) / (t3 - t2))
	var b1 := a1 * ((t2 - tt) / (t2 - t0)) + a2 * ((tt - t0) / (t2 - t0))
	var b2 := a2 * ((t3 - tt) / (t3 - t1)) + a3 * ((tt - t1) / (t3 - t1))
	return b1 * ((t2 - tt) / (t2 - t1)) + b2 * ((tt - t1) / (t2 - t1))


## As casas dos dois lados da serpentina, de frente para ela.
##
## Anda pelo caminho de lote em lote; em cada lado, a casa entra se a planta
## dela nao encosta na pista (nem de outra perna da serpentina), nem numa casa
## ja posta, nem na faixa da fileira da avenida.
static func _casas(caminho: PackedVector2Array, celula: Rect2,
		rng: RandomNumberGenerator) -> Array[Dictionary]:
	var casas: Array[Dictionary] = []
	var miolo := celula.grow(-BORDA)
	var afasta := MEIA_PISTA + CALCADA
	var passo_lote := int(LOTE / PASSO)
	var k := int(ENTRADA / PASSO) + 2
	while k < caminho.size() - int(ENTRADA / PASSO) - 2:
		var a := caminho[k - 1]
		var b := caminho[k + 1]
		var tangente := (b - a).normalized()
		var normal := Vector2(-tangente.y, tangente.x)
		for lado: float in [1.0, -1.0]:
			var frente := caminho[k] + normal * lado * afasta
			var olha := -normal * lado
			var larg := rng.randf_range(6.0, 8.0)
			if not _cabe(frente, olha, larg, caminho, miolo, casas):
				continue
			casas.append({
				"frente": frente,
				"olha": olha,
				"largura": larg,
				"andares": 1 + (1 if rng.randf() < 0.35 else 0),
				"semente": rng.randi(),
			})
		k += passo_lote
	return casas


## A planta da casa (retangulo de `larg` x FUNDO_CASA atras da linha `frente`,
## olhando para `olha`) cabe ali?
static func _cabe(frente: Vector2, olha: Vector2, larg: float,
		caminho: PackedVector2Array, miolo: Rect2,
		casas: Array[Dictionary]) -> bool:
	var lado := Vector2(-olha.y, olha.x)
	var fundo := -olha
	var cantos: Array[Vector2] = [
		frente - lado * (larg * 0.5), frente + lado * (larg * 0.5),
		frente + fundo * FUNDO_CASA - lado * (larg * 0.5),
		frente + fundo * FUNDO_CASA + lado * (larg * 0.5),
		frente + fundo * (FUNDO_CASA * 0.5),
	]
	for c: Vector2 in cantos:
		if not miolo.has_point(c):
			return false
		if distancia(caminho, c) < MEIA_PISTA + CALCADA - 0.05:
			return false
	var centro := frente + fundo * (FUNDO_CASA * 0.5)
	for outra: Dictionary in casas:
		var c2: Vector2 = Vector2(outra["frente"]) - Vector2(outra["olha"]) * (FUNDO_CASA * 0.5)
		if c2.distance_to(centro) < (larg + float(outra["largura"])) * 0.5 + 0.8:
			return false
	return true


## Distancia do ponto ate o caminho, em metros.
static func distancia(caminho: PackedVector2Array, p: Vector2) -> float:
	var melhor := INF
	for k in range(1, caminho.size()):
		var a := caminho[k - 1]
		var b := caminho[k]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		melhor = minf(melhor, p.distance_to(a + ab * t))
	return melhor


## A serpentina da celula do chunk, se houver.
static func do_chunk(cx: int, cz: int) -> Dictionary:
	var c := celula_do_chunk(cx, cz)
	return dados(c.x, c.y)
