## Costura do chao: fecha as frestas por onde se via o limbo entre duas pecas.
##
## Por que existe
## -------------
## O chao da rua e montado em pecas: a faixa do eixo X, a do eixo Z, a quina do
## cruzamento, as quatro calcadas. Cada peca e subdividida na PROPRIA grade de
## 2 m, entao onde duas se encostam os vertices de uma caem no meio da aresta da
## outra — junta em T. Na conta exata a aresta passa pelo vertice; no
## rasterizador, nao, e sobra um pixel sem dono que pisca conforme a camera anda.
## Com o snap do PS1 ligado o vertice pula para a grade da tela e a fresta vira um
## pixel inteiro. Era a borda do quadrado do cruzamento piscando limbo.
##
## Na borda do chunk nem vertice igual resolve: cada chunk e um no com a propria
## matriz, e o mesmo ponto de mundo sai com arredondamento diferente de cada
## lado. Ali a costura e uma saia.
##
## O que faz
## ---------
## `costurar` roda no ChunkBuilder.construir logo depois do `_solo`, com o chao
## da rua ainda plano; o Relevo.assentar deforma depois os vertices novos e a
## saia junto com os outros:
##
##   1. Arredonda x, y e z de todo vertice do chunk para a grade de GRADE metros.
##      Ponto que devia ser o mesmo passa a ser o mesmo, bit a bit.
##   2. Parte toda aresta de contorno que tem vertice de outra peca no meio,
##      na mesma altura. Some a junta em T.
##   3. Pendura uma saia de SAIA metros em cada aresta que cai na borda do
##      chunk, virada para fora. Quem olha pela fresta da emenda ve a saia do
##      vizinho, com a mesma textura e a normal para cima (a mesma luz do chao).
##
## A solda vale para todo triangulo de chao que ja existe nessa hora (rua,
## calcada, quina) e para o meio-fio inteiro; a saia, so para o chao. A tinta da
## faixa fica fora: e camada 12 mm acima, e a fresta dela mostra o asfalto, nao
## o limbo. O chao que entra depois (a grama do parque) passa por `soldar`, uma
## segunda passada so de solda nos materiais dele.
class_name Costura
extends RefCounted

## Grade do arredondamento, em metros. Potencia de dois: o valor fica exato
## em float.
const GRADE := 1.0 / 512.0
## Quanto a saia desce abaixo da borda. Passa da saia do meio-fio (6 cm) e da
## altura da calcada: da calcada, ela chega abaixo do asfalto.
const SAIA := 0.3
## Superficies que nao entram: tinta e camada por cima do chao.
const FORA: Array[StringName] = [&"marca_via"]
## O quanto o triangulo tem de olhar para cima para contar como chao (cosseno
## com a vertical). A costura roda antes do relevo, com o chao ainda plano.
## Rodar depois dele (com 0,5 para pegar a ladeira) abriu mais frestas no
## cruzamento do que fechou: medido na bancada_frestas, 0 contra 23-48 px.
const CHAO_MINIMO := 0.999
## Materiais soldados inteiros, com as faces verticais: a quina do meio-fio.
const VERTICAIS: Array[StringName] = [&"meio_fio"]

const _Q := 512.0


static func costurar(sup: Dictionary, tam: float) -> void:
	_costurar(sup, sup.keys(), tam, true)


## Segunda passada, so a solda e sem saia, para o chao que entra depois do
## `_solo`: a grama do parque (0,16 m, a altura da calcada) encosta na calcada
## em junta em T, e no PS1 a fresta pisca limbo — debaixo da grama nao ha chao.
## So os materiais da lista sao arredondados e partidos.
static func soldar(sup: Dictionary, materiais: Array) -> void:
	var presentes: Array = []
	for mat: StringName in materiais:
		if sup.has(mat):
			presentes.append(mat)
	if not presentes.is_empty():
		_costurar(sup, presentes, 0.0, false)


static func _costurar(sup: Dictionary, materiais: Array, tam: float, com_saia: bool) -> void:
	# Triangulos de chao, por material: [a, b, c] com indices do material.
	var tris := {}
	# Pontos de chao, arredondados, por linha: x -> [z, y, material, indice] e
	# z -> [x, y, material, indice].
	var por_x := {}
	var por_z := {}
	# Tudo, nao so o chao: o topo do meio-fio tem de cair no mesmo numero que a
	# borda da calcada, senao a costura abre uma fresta nova de meio milimetro.
	for mat: StringName in materiais:
		var todos: PackedVector3Array = sup[mat]["v"]
		for i in todos.size():
			todos[i] = _arredondar(todos[i])
		sup[mat]["v"] = todos
	for mat: StringName in materiais:
		if FORA.has(mat):
			continue
		var d: Dictionary = sup[mat]
		var v: PackedVector3Array = d["v"]
		var idx: PackedInt32Array = d["i"]
		var lista: Array[PackedInt32Array] = []
		var usados := {}
		for k in range(0, idx.size(), 3):
			var a := v[idx[k]]
			var b := v[idx[k + 1]]
			var c := v[idx[k + 2]]
			# O chao (virado para cima, que e o lado de costas para o produto
			# vetorial) e o meio-fio inteiro: a quina de cima dele junta a face
			# vertical (grade de 2 m) com a borda da calcada (outra grade), e a
			# junta em T ali pisca igual. Parede de predio fica fora: dobrava o
			# tempo do chunk.
			var nt := (b - a).cross(c - a)
			if nt.length() < 1e-8:
				continue
			if nt.y > -CHAO_MINIMO * nt.length() and not VERTICAIS.has(mat):
				continue
			lista.append(PackedInt32Array([idx[k], idx[k + 1], idx[k + 2]]))
			usados[idx[k]] = true
			usados[idx[k + 1]] = true
			usados[idx[k + 2]] = true
		if lista.is_empty():
			continue
		for i: int in usados:
			var q := _chave(v[i])
			_guardar(por_x, q.x, Vector3i(q.z, q.y, i), mat)
			_guardar(por_z, q.z, Vector3i(q.x, q.y, i), mat)
		tris[mat] = lista

	var borda := roundi(tam * _Q)
	for mat: StringName in tris:
		var d: Dictionary = sup[mat]
		var contorno := _contorno(tris[mat])
		var feitos: Array[PackedInt32Array] = []
		var fila: Array[PackedInt32Array] = tris[mat].duplicate()
		while not fila.is_empty():
			var t: PackedInt32Array = fila.pop_back()
			var partidos := _partir(d, t, contorno, por_x, por_z)
			if partidos.is_empty():
				feitos.append(t)
			else:
				fila.append_array(partidos)
		_trocar_triangulos(d, tris[mat], feitos)
		if com_saia:
			_saias(d, feitos, contorno, borda)


# --- solda -----------------------------------------------------------------

static func _arredondar(p: Vector3) -> Vector3:
	return Vector3(roundf(p.x * _Q) / _Q, roundf(p.y * _Q) / _Q, roundf(p.z * _Q) / _Q)


static func _chave(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x * _Q), roundi(p.y * _Q), roundi(p.z * _Q))


static func _guardar(linhas: Dictionary, linha: int, ponto: Vector3i, mat: StringName) -> void:
	if not linhas.has(linha):
		linhas[linha] = []
	linhas[linha].append([ponto, mat])


## As arestas que so um triangulo usa, com a ordem em que ele as percorre.
## Aresta de dentro da grade de uma peca tem dois donos e nunca e partida: o que
## encosta nela e a propria peca.
static func _contorno(lista: Array[PackedInt32Array]) -> Dictionary:
	var conta := {}
	for t: PackedInt32Array in lista:
		for e in 3:
			var chave := _aresta(t[e], t[(e + 1) % 3])
			conta[chave] = int(conta.get(chave, 0)) + 1
	var saida := {}
	for chave: Vector2i in conta:
		if conta[chave] == 1:
			saida[chave] = true
	return saida


static func _aresta(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))


## Parte o triangulo pela primeira aresta de contorno que tem ponto de chao no
## meio, em leque a partir do vertice oposto. Devolve os pedacos, ou vazio se
## nao ha o que partir. As arestas novas herdam o contorno.
static func _partir(d: Dictionary, t: PackedInt32Array, contorno: Dictionary,
		por_x: Dictionary, por_z: Dictionary) -> Array[PackedInt32Array]:
	var v: PackedVector3Array = d["v"]
	for e in 3:
		var ia := t[e]
		var ib := t[(e + 1) % 3]
		var ic := t[(e + 2) % 3]
		if not contorno.has(_aresta(ia, ib)):
			continue
		var qa := _chave(v[ia])
		var qb := _chave(v[ib])
		if qa.y != qb.y:
			continue
		var meio: Array[Vector3i] = []
		if qa.x == qb.x and por_x.has(qa.x):
			for p: Array in por_x[qa.x]:
				var s: Vector3i = p[0]
				if s.y == qa.y and s.x > mini(qa.z, qb.z) and s.x < maxi(qa.z, qb.z):
					meio.append(Vector3i(qa.x, qa.y, s.x))
		elif qa.z == qb.z and por_z.has(qa.z):
			for p: Array in por_z[qa.z]:
				var s: Vector3i = p[0]
				if s.y == qa.y and s.x > mini(qa.x, qb.x) and s.x < maxi(qa.x, qb.x):
					meio.append(Vector3i(s.x, qa.y, qa.z))
		if meio.is_empty():
			continue
		# Do lado de a para o de b, sem repetir.
		var ao_longo := func(q: Vector3i) -> int:
			return absi(q.x - qa.x) + absi(q.z - qa.z)
		meio.sort_custom(func(p: Vector3i, q: Vector3i) -> bool:
			return ao_longo.call(p) < ao_longo.call(q))
		var cadeia: Array[int] = [ia]
		var ultimo := Vector3i(-1073741824, 0, 0)
		var comprimento := float(ao_longo.call(qb))
		for q: Vector3i in meio:
			if q == ultimo:
				continue
			ultimo = q
			cadeia.append(_vertice_no_meio(d, ia, ib, float(ao_longo.call(q)) / comprimento,
				Vector3(q) / _Q))
		cadeia.append(ib)
		contorno.erase(_aresta(ia, ib))
		var pedacos: Array[PackedInt32Array] = []
		for k in cadeia.size() - 1:
			contorno[_aresta(cadeia[k], cadeia[k + 1])] = true
			pedacos.append(PackedInt32Array([cadeia[k], cadeia[k + 1], ic]))
		return pedacos
	return []


## Vertice novo sobre a aresta a-b, na fracao `f`, com a posicao exata `p`.
static func _vertice_no_meio(d: Dictionary, a: int, b: int, f: float, p: Vector3) -> int:
	var v: PackedVector3Array = d["v"]
	var n: PackedVector3Array = d["n"]
	var uv: PackedVector2Array = d["uv"]
	var uv2: PackedVector2Array = d.get("uv2", PackedVector2Array())
	var c: PackedColorArray = d["c"]
	var i := v.size()
	v.append(p)
	n.append(n[a].lerp(n[b], f).normalized())
	uv.append(uv[a].lerp(uv[b], f))
	if uv2.size() == i:
		uv2.append(uv2[a].lerp(uv2[b], f))
		d["uv2"] = uv2
	c.append(c[a].lerp(c[b], f))
	d["v"] = v
	d["n"] = n
	d["uv"] = uv
	d["c"] = c
	return i


## Tira do indice os triangulos de chao originais e poe os costurados. Os
## outros (parede, meio-fio, tinta) ficam como estavam, na mesma ordem.
static func _trocar_triangulos(d: Dictionary, velhos: Array[PackedInt32Array],
		novos: Array[PackedInt32Array]) -> void:
	var fora := {}
	for t: PackedInt32Array in velhos:
		fora[Vector3i(t[0], t[1], t[2])] = true
	var idx: PackedInt32Array = d["i"]
	var saida := PackedInt32Array()
	for k in range(0, idx.size(), 3):
		if not fora.has(Vector3i(idx[k], idx[k + 1], idx[k + 2])):
			saida.append_array([idx[k], idx[k + 1], idx[k + 2]])
	for t: PackedInt32Array in novos:
		saida.append_array(t)
	d["i"] = saida


# --- saia ------------------------------------------------------------------

## Uma saia em cada aresta de contorno que cai na borda do chunk (x ou z em 0 ou
## em `borda`, na grade), virada para fora dele.
static func _saias(d: Dictionary, lista: Array[PackedInt32Array], contorno: Dictionary,
		borda: int) -> void:
	var v: PackedVector3Array = d["v"]
	var idx: PackedInt32Array = d["i"]
	for t: PackedInt32Array in lista:
		# So chao: virado para cima e o que fica de costas para o produto
		# vetorial (ver `giro-de-face`), entao chao de verdade da n.y negativo.
		var nt := (v[t[1]] - v[t[0]]).cross(v[t[2]] - v[t[0]])
		if nt.y > -CHAO_MINIMO * nt.length():
			continue
		for e in 3:
			var ia := t[e]
			var ib := t[(e + 1) % 3]
			if not contorno.has(_aresta(ia, ib)):
				continue
			var qa := _chave(v[ia])
			var qb := _chave(v[ib])
			var fora := Vector3.ZERO
			if qa.x == qb.x and (qa.x == 0 or qa.x == borda):
				fora = Vector3(-1.0 if qa.x == 0 else 1.0, 0.0, 0.0)
			elif qa.z == qb.z and (qa.z == 0 or qa.z == borda):
				fora = Vector3(0.0, 0.0, -1.0 if qa.z == 0 else 1.0)
			else:
				continue
			var ja := _copiar_abaixo(d, ia)
			var jb := _copiar_abaixo(d, ib)
			v = d["v"]
			# A face visivel e a do lado oposto ao produto vetorial: para olhar
			# para fora, o produto tem de apontar para dentro.
			var n := (v[ib] - v[ia]).cross(v[jb] - v[ia])
			if n.dot(fora) < 0.0:
				idx.append_array([ia, ib, jb, ia, jb, ja])
			else:
				idx.append_array([ib, ia, ja, ib, ja, jb])
	d["i"] = idx


## Copia do vertice `i` SAIA metros abaixo, com a mesma UV, a mesma cor e a
## normal do chao: a saia vista pela fresta tem a luz e a textura da borda.
static func _copiar_abaixo(d: Dictionary, i: int) -> int:
	var v: PackedVector3Array = d["v"]
	var n: PackedVector3Array = d["n"]
	var uv: PackedVector2Array = d["uv"]
	var uv2: PackedVector2Array = d.get("uv2", PackedVector2Array())
	var c: PackedColorArray = d["c"]
	var j := v.size()
	v.append(v[i] - Vector3(0.0, SAIA, 0.0))
	n.append(n[i])
	uv.append(uv[i])
	if uv2.size() == j:
		uv2.append(uv2[i])
		d["uv2"] = uv2
	c.append(c[i])
	d["v"] = v
	d["n"] = n
	d["uv"] = uv
	d["c"] = c
	return j
