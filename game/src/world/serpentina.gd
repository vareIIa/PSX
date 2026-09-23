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
## Quanto a entrada anda reto, da linha da fachada para dentro, antes da curva:
## a fileira e os quintais dela (a fachada da avenida esta a 9,2 m da borda,
## e 9,2 + 18 passa de BORDA).
const ENTRADA := 18.0
## Pernas da serpentina (idas e vindas na encosta).
const PERNAS := 3
## Distancia entre dois pontos do caminho amostrado.
const PASSO := 2.0
## Raio do eixo nas curvas, em metros: a concordancia em arco de circulo de
## rua de verdade. Com a pista e a calcada (4,6 m do eixo), o meio-fio de dentro
## fica com 11 m no cotovelo. A curva da boca sai com ~15 m (ENTRADA e a
## primeira perna); abaixo de 4,6 m a calcada de dentro se dobra e vira ponta.
const RAIO := 16.0

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
	var sorte_sai := rng.randf()
	# As pernas vao de uma beira a outra da encosta, subindo de uma para a
	# outra; a primeira sai para o lado mais longe da entrada.
	var b_baixo := BORDA + 8.0
	var b_alto := LADO - BORDA - 8.0
	var comeca_alto := b_entra < LADO * 0.5
	var pontos: Array[Vector2] = []
	pontos.append(Vector2(fachada, b_entra))
	# 16 m para dentro da BORDA: a curva da boca cabe com raio de 15 m.
	var a_de := BORDA + 16.0
	var a_ate := LADO - BORDA - 16.0
	# Cada perna corre ao longo da encosta numa altura `a`, de uma beira a outra;
	# o cotovelo entre duas pernas sobe de uma `a` para a seguinte na mesma
	# beira. A primeira comeca onde a entrada chegou; a ultima para na altura da
	# saida e dobra em angulo reto para ela — ir ate a beira e voltar em
	# diagonal era um grampo de quase 180 graus.
	for k in PERNAS:
		var a := lerpf(a_de, a_ate, float(k) / float(PERNAS - 1))
		var alto := comeca_alto if k % 2 == 0 else not comeca_alto
		var primeiro := b_baixo if alto else b_alto
		var ultimo := b_alto if alto else b_baixo
		var de := b_entra if k == 0 else primeiro
		if k == PERNAS - 1:
			# Longe o bastante da beira para caberem as duas curvas.
			var folga := RAIO + 14.0
			ultimo = lerpf(primeiro + folga, LADO - BORDA - 14.0, sorte_sai) if alto \
				else lerpf(primeiro - folga, BORDA + 14.0, sorte_sai)
		pontos.append(Vector2(a, de))
		pontos.append(Vector2(a, ultimo))
	var b_sai := pontos[pontos.size() - 1].y
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


## O caminho pelos vertices, com cada canto trocado por um arco de circulo
## tangente as duas retas (a concordancia de projeto de rua), amostrado a cada
## PASSO metros.
static func _amostrar(pontos: Array[Vector2]) -> Array[Vector2]:
	var denso := _arredondar(pontos)
	var n := denso.size()
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
	if saida[saida.size() - 1].distance_to(denso[n - 1]) > 0.3:
		saida.append(denso[n - 1])
	return saida


## Troca cada canto do poligono por um arco de raio RAIO, ou menor quando as
## retas vizinhas sao curtas: uma reta do meio e dividida entre as duas curvas
## das pontas dela, e a primeira e a ultima guardam ENTRADA metros retos junto
## da fachada (o vao na fileira, SerpentinaBuilder.vao_na_face). Devolve os
## pontos densos (arco a cada ~0,5 m); quem chama reamostra.
##
## O Catmull-Rom que havia antes passava PELO vertice: raio de 1 m no
## cotovelo, e a calcada de dentro (4,6 m do eixo) se dobrava em ponta.
static func _arredondar(pontos: Array[Vector2]) -> Array[Vector2]:
	# Tira os pontos repetidos e os que estao no meio de uma reta.
	var p: Array[Vector2] = [pontos[0]]
	for k in range(1, pontos.size()):
		if pontos[k].distance_to(p[p.size() - 1]) < 0.01:
			continue
		if p.size() >= 2 and k + 1 < pontos.size():
			var d1 := (pontos[k] - p[p.size() - 1]).normalized()
			var d2 := (pontos[k + 1] - pontos[k]).normalized()
			if d1.dot(d2) > 0.9999:
				continue
		p.append(pontos[k])
	var n := p.size()
	var saida: Array[Vector2] = [p[0]]
	for k in range(1, n - 1):
		var anterior := p[k - 1]
		var canto := p[k]
		var seguinte := p[k + 1]
		var d_in := (canto - anterior).normalized()
		var d_out := (seguinte - canto).normalized()
		var giro := d_in.angle_to(d_out)
		# Quanto de cada reta vizinha esta curva pode gastar.
		var livre_in := canto.distance_to(anterior) \
			* (1.0 if k == 1 else 0.5) - (ENTRADA if k == 1 else 0.0)
		var livre_out := canto.distance_to(seguinte) \
			* (1.0 if k == n - 2 else 0.5) - (ENTRADA if k == n - 2 else 0.0)
		var meio_giro := tan(absf(giro) * 0.5)
		var raio := minf(RAIO, maxf(minf(livre_in, livre_out), 0.0) / maxf(meio_giro, 0.001))
		var recuo := raio * meio_giro
		var de := canto - d_in * recuo
		# O centro fica do lado de dentro da curva.
		var dentro := Vector2(-d_in.y, d_in.x) * signf(giro)
		var centro := de + dentro * raio
		var passos := maxi(2, ceili(absf(giro) * raio / 0.5))
		for s in passos + 1:
			saida.append(centro + (de - centro).rotated(giro * float(s) / float(passos)))
	saida.append(p[n - 1])
	return saida


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
