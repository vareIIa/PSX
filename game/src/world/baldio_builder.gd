## O que tem dentro do terreno baldio.
##
## Por que existe
## -------------
## O baldio era um plano de terra do tamanho da quadra com um muro de um metro e
## oitenta em volta. De cima, e de qualquer janela, e do alto da rua em
## ladeira, lia como um buraco amarelo liso de 150 m no meio da cidade — o mesmo
## "vazio" que o resto do trabalho de fundos veio tirar.
##
## Terreno baldio de cidade do interior nao e liso: e capim alto, moita, uma
## arvore que ninguem plantou, monte de entulho que alguem jogou por cima do
## muro, pichacao na face da rua e, uma vez por quarteirao, a obra parada — os
## pilares e a primeira laje de uma casa que nunca terminou, com o ferro
## espetado para cima. E a silhueta que aparece por cima do muro.
##
## Tudo em coordenada LOCAL do chunk, como o resto do ChunkBuilder. O sorteio e
## do rng do chunk: o baldio nao tem nada que o mapa ou o teste precise achar.
class_name BaldioBuilder
extends RefCounted

## Metros quadrados de terreno por tufo de mato.
const AREA_POR_TUFO := 7.0
const CELULAS_MATO: Array[Vector2i] = [
	KitEstrada.C_CAPIM, KitEstrada.C_CAPIM_SECO, KitEstrada.C_CAPIM_SECO,
	KitEstrada.C_CAPIM_RALO, KitEstrada.C_MOITA_BAIXA, KitEstrada.C_GALHO_SECO,
]


static func construir(sup: Dictionary, colisao: Array[Dictionary],
		faces: Array[Dictionary], quadra: Dictionary, lim: Rect2, cx: int, cz: int,
		rng: RandomNumberGenerator) -> void:
	if not FundosBuilder.ativo:
		return
	var r := lim.grow(-0.8)
	if r.size.x < 3.0 or r.size.y < 3.0:
		return
	_chao(sup, lim, quadra, cx, cz, rng)
	_mato(sup, r, rng)
	_entulho(sup, r, rng)
	_verde(sup, r, rng)
	_pichacao(sup, faces, rng)
	# A obra parada e uma por quarteirao, no chunk do centro dele.
	var centro := MalhaUrbana.centro_da_quadra(quadra) - Vector3(cx * 32.0, 0.0, cz * 32.0)
	if r.has_point(Vector2(centro.x, centro.z)) \
			and posmod(int(quadra["semente"]) / 13, 10) < 4:
		_obra_parada(sup, colisao, Vector3(centro.x, 0.0, centro.z), r, rng)


static func _ponto(r: Rect2, rng: RandomNumberGenerator) -> Vector3:
	return Vector3(rng.randf_range(r.position.x, r.end.x), 0.02,
		rng.randf_range(r.position.y, r.end.y))


## Capim seco por cima da terra, e as trilhas de terra batida que o povo corta
## pelo terreno. Visto do alto e o que faz o baldio ler como mato, e nao como
## um patio de terra: o tufo em cruz, de cima, e um risco.
##
## Cinco e oito centimetros acima da terra do `_baldio`, e nao meio: encostados,
## os planos disputam o pixel a trinta metros e o capim pisca.
##
## As trilhas sao do QUARTEIRAO, em coordenada de mundo: uma de ponta a ponta em
## cada eixo, e cada chunk desenha o pedaco que cai nele. Sorteadas por chunk,
## elas acabavam na costura.
static func _chao(sup: Dictionary, lim: Rect2, quadra: Dictionary, cx: int, cz: int,
		rng: RandomNumberGenerator) -> void:
	KitModular.chao(sup, &"grama", Vector3(lim.position.x, 0.05, lim.position.y),
		lim.size, 8.0, Color(0.8, 0.74, 0.5).lerp(Color(0.62, 0.66, 0.42), rng.randf()))
	var q := MalhaUrbana.retangulo_da_quadra(quadra)
	var h := int(quadra["semente"])
	var origem := Vector2(cx * 32.0, cz * 32.0)
	const LARG := 1.1
	# Trilha no eixo X, numa altura da quadra que so depende da semente.
	var z := q.position.y + q.size.y * (0.25 + 0.5 * float((h / 7) % 100) / 100.0) - origem.y
	if z > lim.position.y and z + LARG < lim.end.y:
		KitModular.chao(sup, &"terra", Vector3(lim.position.x, 0.08, z),
			Vector2(lim.size.x, LARG), 8.0, Color(0.66, 0.6, 0.52))
	var x := q.position.x + q.size.x * (0.25 + 0.5 * float((h / 701) % 100) / 100.0) - origem.x
	if x > lim.position.x and x + LARG < lim.end.x:
		KitModular.chao(sup, &"terra", Vector3(x, 0.085, lim.position.y),
			Vector2(LARG, lim.size.y), 8.0, Color(0.66, 0.6, 0.52))


## Capim e moita em tufo cruzado, o mesmo mato da beira da Estrada Velha.
static func _mato(sup: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var n := int(r.get_area() / AREA_POR_TUFO)
	for k in n:
		var cel := CELULAS_MATO[rng.randi() % CELULAS_MATO.size()]
		var cor := Color(0.82, 0.8, 0.62).lerp(Color(0.6, 0.72, 0.46), rng.randf())
		KitEstrada.tufo(sup, _ponto(r, rng), cel, rng.randf_range(1.0, 2.2),
			rng.randf_range(0.0, PI), cor)


## Monte de entulho: tijolo quebrado, pedaco de laje e um saco de cimento velho.
static func _entulho(sup: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	for monte in rng.randi_range(0, 2):
		var base := _ponto(r.grow(-2.0) if r.size.x > 6.0 and r.size.y > 6.0 else r, rng)
		for k in rng.randi_range(4, 7):
			var tam := Vector3(rng.randf_range(0.3, 1.1), rng.randf_range(0.12, 0.45),
				rng.randf_range(0.25, 0.8))
			var desvio := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
			var mat: StringName = [&"tijolo", &"concreto_sujo", &"concreto"][rng.randi() % 3]
			KitModular.caixa_cor(sup, mat, base + desvio + Vector3(0.0, tam.y * 0.5, 0.0),
				tam, Color(0.85, 0.8, 0.74).lerp(Color(0.6, 0.56, 0.5), rng.randf()),
				rng.randf_range(0.0, PI), PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, 8.0)


## Arbusto e arvoreta que nasceram sozinhos.
static func _verde(sup: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	if Vegetacao.ativo:
		_verde_vivo(sup, r, rng)
		return
	for k in rng.randi_range(1, 3):
		KitParque.arbusto(sup, _ponto(r, rng), rng.randf_range(0.6, 1.2), rng)
	if rng.randf() < 0.45 and r.size.x > 5.0 and r.size.y > 5.0:
		var arvore_rng := RandomNumberGenerator.new()
		arvore_rng.seed = rng.randi()
		var descartavel: Array[Dictionary] = []
		KitParque.arvore(sup, descartavel, _ponto(r.grow(-2.0), rng),
			rng.randf_range(0.0, 0.3), arvore_rng, rng.randf() < 0.3)


## O mesmo, com a Vegetacao: o terreno que ninguem capina fecha em colonião
## ate a cintura, bananeira que alguem plantou e largou, moita, e a arvore que
## nasceu sozinha (abacateiro de caroco jogado, mangueira, ipe). Sorteio proprio,
## com um gasto so do rng do chunk: a quantidade de mato nao mexe no que vem
## depois.
static func _verde_vivo(sup: Dictionary, r: Rect2, rng: RandomNumberGenerator) -> void:
	var v := RandomNumberGenerator.new()
	v.seed = rng.randi()
	var ob := Obra.new()
	var descartavel: Array[Dictionary] = []
	for k in int(r.get_area() / 14.0):
		Vegetacao.touceira(ob, _ponto(r, v), v.randf_range(1.0, 1.9), v)
	for k in v.randi_range(1, 3):
		Vegetacao.arbusto(ob, _ponto(r, v), v.randf_range(1.2, 2.2), Vegetacao.C_ARBUSTO, v)
	if v.randf() < 0.5:
		Vegetacao.bananeira(sup, _ponto(r, v), v)
	if r.size.x > 5.0 and r.size.y > 5.0:
		for k in v.randi_range(0, 2):
			var especie: StringName = [&"abacateiro", &"mangueira", &"ipe_amarelo",
				&"oiti"][v.randi() % 4]
			Vegetacao.arvore(sup, descartavel, _ponto(r.grow(-2.0), v), especie,
				v.randf_range(0.0, 0.5), v)
	ob.despejar(sup)


## Pichacao na face do muro que da para a rua.
static func _pichacao(sup: Dictionary, faces: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	for face: Dictionary in faces:
		var comp := float(face["comprimento"])
		if comp < 6.0 or rng.randf() > 0.7:
			continue
		var normal := KitModular._normal(int(face["direcao"]))
		var giro := atan2(normal.x, normal.z)
		for k in rng.randi_range(1, 2):
			var t := rng.randf_range(2.0, comp - 2.0)
			var p: Vector3 = Vector3(face["canto"]) + Vector3(face["eixo"]) * t \
				+ normal * 0.03 + Vector3(0.0, 0.95, 0.0)
			KitModular.placa(sup, &"pichacao", p, Vector2(2.4, 1.2), giro)


## A obra parada: pilares, a primeira laje e o ferro espetado.
static func _obra_parada(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, r: Rect2, rng: RandomNumberGenerator) -> void:
	var larg := minf(9.0, r.size.x - 2.0)
	var fundo := minf(7.0, r.size.y - 2.0)
	if larg < 4.0 or fundo < 4.0:
		return
	var alt := 2.9
	var concreto := Color(0.72, 0.7, 0.66)
	var nx := 3 if larg > 6.0 else 2
	var nz := 3 if fundo > 6.0 else 2
	for ix in nx:
		for iz in nz:
			var p := centro + Vector3(
				-larg * 0.5 + larg * float(ix) / float(nx - 1), 0.0,
				-fundo * 0.5 + fundo * float(iz) / float(nz - 1))
			KitModular.caixa_cor(sup, &"concreto", p + Vector3(0.0, alt * 0.5, 0.0),
				Vector3(0.3, alt, 0.3), concreto, 0.0,
				PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, 8.0)
			colisao.append({"tamanho": Vector3(0.3, alt, 0.3),
				"pos": p + Vector3(0.0, alt * 0.5, 0.0)})
			# Ferro de espera saindo do topo do pilar.
			for f in 2:
				KitModular.caixa_cor(sup, &"metal_enferrujado",
					p + Vector3(-0.08 + 0.16 * float(f), alt + 0.2 + 0.35, 0.0),
					Vector3(0.025, 0.7, 0.025), Color.WHITE, 0.0,
					PSXMesh.FACE_TODAS, 8.0)
	# A laje de cima, com uma borda quebrada.
	KitModular.caixa_cor(sup, &"concreto", centro + Vector3(0.0, alt + 0.1, 0.0),
		Vector3(larg + 0.3, 0.2, fundo * rng.randf_range(0.6, 1.0) + 0.3), concreto,
		0.0, PSXMesh.FACE_TODAS, 4.0)
	# Meia parede de tijolo sem reboco, que parou na terceira fiada de cima.
	KitModular.caixa_cor(sup, &"tijolo",
		centro + Vector3(0.0, 0.9, -fundo * 0.5), Vector3(larg, 1.8, 0.14),
		Color.WHITE, 0.0, PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, 4.0)
