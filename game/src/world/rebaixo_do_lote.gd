## Afunda o chao da quadra dentro da planta de um lote rigido, sem junta em T.
##
## Por que existe
## -------------
## Na ladeira o lote sobe rigido (ChunkBuilder._erguer_lote) e o chao da quadra
## (a terra do patio, a grama) segue o relevo por baixo dele. Onde o morro sobe
## para o fundo, esse chao atravessa a casa: aparecia dentro do comodo da janela
## aberta e do salao da loja (metade dos lotes tinha algum canto mais de 30 cm
## acima do piso, levantamento da ladeira em PLANO_CASAS_AAA.md).
##
## PredioMercado.afundar_chao faz isso para a loja, mas so parte o triangulo
## vizinho quando ele tambem tem vertice acima do piso. No lado de baixo do morro
## o vizinho nao tem, fica com a aresta inteira contra o ponto novo, e a junta em
## T pisca o limbo no PS1 (bancada_frestas --ps1, chunk -1,0).
##
## Aqui a aresta e reconhecida pela POSICAO das pontas (pecas vizinhas de chao
## tem cada uma os seus vertices), e o ponto novo sai sempre das duas pontas na
## mesma ordem: o triangulo recortado e o vizinho criam, cada um, um vertice no
## mesmo lugar, bit a bit. O vizinho que nao desce ganha os pontos novos das
## arestas dele e e refeito em leque a partir do proprio centro. Dentro da planta
## os vertices sao copias rebaixadas; na borda, uma parede vertical liga o chao de
## fora ao de dentro.
class_name RebaixoDoLote
extends RefCounted

const MATERIAIS: Array[StringName] = [&"terra", &"grama"]
## Chave de bancada: `--sem-rebaixo` deixa o chao da quadra como o relevo pos.
static var ativo := not OS.get_cmdline_user_args().has("--sem-rebaixo")
const _EPS := 0.0005
## Grade da chave de posicao: a mesma da Costura (1/512 m) ja arredondou o chao.
const _Q := 1024.0


## Os arrays de um material, soltos do balde: PackedArray no dicionario copia a
## cada append (memoria do projeto: balde do chunk copia a cada peca).
class Malha extends RefCounted:
	var v: PackedVector3Array
	var n: PackedVector3Array
	var uv: PackedVector2Array
	var uv2: PackedVector2Array
	var c: PackedColorArray
	var tem_uv2 := false

	func _init(d: Dictionary) -> void:
		v = d["v"]
		n = d["n"]
		uv = d["uv"]
		c = d["c"]
		tem_uv2 = d.has("uv2") and (d["uv2"] as PackedVector2Array).size() == v.size()
		if tem_uv2:
			uv2 = d["uv2"]

	func entre(a: int, b: int, t: float) -> int:
		v.append(v[a].lerp(v[b], t))
		n.append(n[a].lerp(n[b], t).normalized())
		uv.append(uv[a].lerp(uv[b], t))
		c.append(c[a].lerp(c[b], t))
		if tem_uv2:
			uv2.append(uv2[a].lerp(uv2[b], t))
		return v.size() - 1

	func copia(a: int, y: float, normal: Vector3 = Vector3.ZERO) -> int:
		var k := entre(a, a, 0.0)
		v[k] = Vector3(v[k].x, y, v[k].z)
		if normal != Vector3.ZERO:
			n[k] = normal
		return k

	func devolver(d: Dictionary) -> void:
		d["v"] = v
		d["n"] = n
		d["uv"] = uv
		d["c"] = c
		if tem_uv2:
			d["uv2"] = uv2


## Afunda `materiais` de `sup` dentro de `pegada` (plano XZ, coordenada do chunk)
## ate `teto`. So mexe no que esta acima dele.
##
## `emenda` falso nao levanta a parede da borda: no porao da casa da fumaca o
## buraco desce 3,8 m e a borda do lado da casa atravessava a boca da estufa, no
## pe da escada, como uma parede de grama. La as paredes do puxadinho ja cobrem
## as quatro bordas.
static func afundar(sup: Dictionary, pegada: Rect2, teto: float,
		materiais: Array[StringName] = MATERIAIS, emenda: bool = true) -> void:
	if not ativo:
		return
	for mat: StringName in materiais:
		if sup.has(mat):
			_afundar(sup[mat], pegada, teto, emenda)


static func _q(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x * _Q), roundi(p.y * _Q), roundi(p.z * _Q))


static func _menor(a: Vector3i, b: Vector3i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	if a.y != b.y:
		return a.y < b.y
	return a.z < b.z


## A aresta pelas posicoes das pontas, e as pontas em ordem fixa (lo, hi).
static func _aresta(m: Malha, a: int, b: int) -> Array:
	var qa := _q(m.v[a])
	var qb := _q(m.v[b])
	if _menor(qb, qa):
		return [[qb, qa], b, a]
	return [[qa, qb], a, b]


static func _afundar(d: Dictionary, r: Rect2, teto: float, emenda: bool = true) -> void:
	var idx: PackedInt32Array = d["i"]
	if idx.is_empty():
		return
	var m := Malha.new(d)
	var dentro_r := r.grow(-_EPS)
	# Quem desce: a caixa em planta cruza o interior da pegada, e ha vertice acima.
	var alvo := {}
	for t in range(0, idx.size(), 3):
		var caixa := Rect2(Vector2(m.v[idx[t]].x, m.v[idx[t]].z), Vector2.ZERO)
		var alto := false
		for j in 3:
			var p := m.v[idx[t + j]]
			caixa = caixa.expand(Vector2(p.x, p.z))
			alto = alto or p.y > teto
		if alto and caixa.intersects(dentro_r):
			alvo[t] = true
	if alvo.is_empty():
		return

	# Aresta (por posicao) -> parametros dos pontos novos nela, na ordem lo -> hi.
	var nas_arestas := {}
	var novo_idx := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		if not alvo.has(t):
			continue
		for peca: Array in _recortar(m, [idx[t], idx[t + 1], idx[t + 2]], r, nas_arestas):
			var dentro: bool = peca[0]
			var poli: PackedInt32Array = peca[1]
			if not dentro:
				for k in range(1, poli.size() - 1):
					novo_idx.append_array(PackedInt32Array([poli[0], poli[k], poli[k + 1]]))
				continue
			# Dentro: copias rebaixadas, e a parede da emenda na borda da pegada.
			var baixos := PackedInt32Array()
			for k in poli.size():
				baixos.append(m.copia(poli[k], minf(m.v[poli[k]].y, teto)))
			for k in range(1, baixos.size() - 1):
				novo_idx.append_array(PackedInt32Array([baixos[0], baixos[k], baixos[k + 1]]))
			if emenda:
				novo_idx.append_array(_emenda(m, poli, baixos, r))

	# Os que nao desceram: os pontos novos nas arestas deles, em leque.
	for t in range(0, idx.size(), 3):
		if alvo.has(t):
			continue
		novo_idx.append_array(_em_leque(m, [idx[t], idx[t + 1], idx[t + 2]], nas_arestas))
	m.devolver(d)
	d["i"] = novo_idx


## Parte o triangulo pela pegada (quatro semiplanos). Devolve [dentro?, poligono],
## com a orientacao do original. Cada vertice do poligono lembra a aresta original
## em que esta, para o ponto novo sair das pontas dela.
static func _recortar(m: Malha, tri: Array, r: Rect2, nas_arestas: Dictionary) -> Array:
	var pecas: Array = []
	# [indice, arestas originais em que o ponto esta (lista de pares de indices)].
	var poli: Array = []
	for k in 3:
		var i: int = tri[k]
		var anterior: int = tri[(k + 2) % 3]
		var seguinte: int = tri[(k + 1) % 3]
		poli.append([i, [Vector2i(anterior, i), Vector2i(i, seguinte)]])
	var planos := [[0, 1.0, r.position.x], [0, -1.0, r.end.x],
		[2, 1.0, r.position.y], [2, -1.0, r.end.y]]
	var feitos := {}
	for p_id in planos.size():
		var pl: Array = planos[p_id]
		var eixo: int = pl[0]
		var sinal: float = pl[1]
		var lim: float = pl[2]
		var dentro: Array = []
		var fora: Array = []
		var n := poli.size()
		for k in n:
			var a: Array = poli[k]
			var b: Array = poli[(k + 1) % n]
			var da := (m.v[int(a[0])][eixo] - lim) * sinal
			var db := (m.v[int(b[0])][eixo] - lim) * sinal
			if da >= 0.0:
				dentro.append(a)
			else:
				fora.append(a)
			if (da >= 0.0) != (db >= 0.0):
				var novo := _ponto(m, a, b, p_id, eixo, lim, feitos, nas_arestas)
				dentro.append(novo)
				fora.append(novo)
		if fora.size() >= 3:
			pecas.append([false, _indices(fora)])
		poli = dentro
		if poli.size() < 3:
			return pecas
	pecas.append([true, _indices(poli)])
	return pecas


static func _indices(poli: Array) -> PackedInt32Array:
	var saida := PackedInt32Array()
	for p: Array in poli:
		saida.append(int(p[0]))
	return saida


## O ponto em que o plano corta o lado a-b do poligono. Se o lado esta numa
## aresta original, o ponto sai das pontas dela em ordem fixa (a mesma conta que
## o vizinho vai fazer) e fica anotado para ele.
static func _ponto(m: Malha, a: Array, b: Array, p_id: int, eixo: int, lim: float,
		feitos: Dictionary, nas_arestas: Dictionary) -> Array:
	var comum := Vector2i(-1, -1)
	for ea: Vector2i in a[1]:
		for eb: Vector2i in b[1]:
			if ea == eb:
				comum = ea
	if comum.x >= 0:
		var ar := _aresta(m, comum.x, comum.y)
		var chave: Array = [ar[0], p_id]
		if not feitos.has(chave):
			var lo: int = ar[1]
			var hi: int = ar[2]
			var t := (lim - m.v[lo][eixo]) / (m.v[hi][eixo] - m.v[lo][eixo])
			feitos[chave] = m.entre(lo, hi, t)
			if not nas_arestas.has(ar[0]):
				nas_arestas[ar[0]] = []
			var ts: Array = nas_arestas[ar[0]]
			if not ts.has(t):
				ts.append(t)
		return [feitos[chave], [comum]]
	# Lado de dentro do triangulo (entre dois pontos de corte): ninguem mais o usa.
	var ia := int(a[0])
	var ib := int(b[0])
	var t2 := (lim - m.v[ia][eixo]) / (m.v[ib][eixo] - m.v[ia][eixo])
	return [m.entre(ia, ib, t2), []]


## O triangulo com os pontos novos das arestas dele: sem nenhum, sai inteiro; com
## algum, vira o poligono da volta em leque a partir do centro, que nao deixa
## triangulo de area zero.
static func _em_leque(m: Malha, tri: Array, nas_arestas: Dictionary) -> PackedInt32Array:
	var volta := PackedInt32Array()
	var partiu := false
	for e in 3:
		var a: int = tri[e]
		var b: int = tri[(e + 1) % 3]
		volta.append(a)
		var ar := _aresta(m, a, b)
		if not nas_arestas.has(ar[0]):
			continue
		var lo: int = ar[1]
		var hi: int = ar[2]
		var ts: Array = (nas_arestas[ar[0]] as Array).duplicate()
		ts.sort()
		if lo != a:
			ts.reverse()
		for t: float in ts:
			if t <= 0.0001 or t >= 0.9999:
				continue
			# A mesma conta de `_ponto`: das pontas, na ordem lo -> hi.
			volta.append(m.entre(lo, hi, t))
			partiu = true
	if not partiu:
		return PackedInt32Array(tri)
	var meio_ab := m.entre(int(tri[0]), int(tri[1]), 0.5)
	var centro := m.entre(meio_ab, int(tri[2]), 1.0 / 3.0)
	var saida := PackedInt32Array()
	for k in volta.size():
		saida.append_array(PackedInt32Array([centro, volta[k], volta[(k + 1) % volta.size()]]))
	return saida


## A parede vertical entre o chao de fora (alto) e o de dentro (rebaixado), nas
## arestas do poligono de dentro que correm na borda da pegada. Normal para
## dentro do lote: e so de la que ela aparece.
static func _emenda(m: Malha, altos: PackedInt32Array, baixos: PackedInt32Array,
		r: Rect2) -> PackedInt32Array:
	var saida := PackedInt32Array()
	var centro := r.get_center()
	var n := altos.size()
	for k in n:
		var a := altos[k]
		var b := altos[(k + 1) % n]
		var pa := m.v[a]
		var pb := m.v[b]
		var na_borda := (absf(pa.x - r.position.x) < 0.001 and absf(pb.x - r.position.x) < 0.001) \
			or (absf(pa.x - r.end.x) < 0.001 and absf(pb.x - r.end.x) < 0.001) \
			or (absf(pa.z - r.position.y) < 0.001 and absf(pb.z - r.position.y) < 0.001) \
			or (absf(pa.z - r.end.y) < 0.001 and absf(pb.z - r.end.y) < 0.001)
		if not na_borda:
			continue
		var ba := baixos[k]
		var bb := baixos[(k + 1) % n]
		if pa.y - m.v[ba].y < 0.005 and pb.y - m.v[bb].y < 0.005:
			continue
		var ao_longo := Vector3(pb.x - pa.x, 0.0, pb.z - pa.z)
		var dentro := Vector3(-ao_longo.z, 0.0, ao_longo.x).normalized()
		var meio := (pa + pb) * 0.5
		if dentro.dot(Vector3(centro.x - meio.x, 0.0, centro.y - meio.z)) < 0.0:
			dentro = -dentro
		var q := PackedInt32Array([m.copia(a, pa.y, dentro), m.copia(b, pb.y, dentro),
			m.copia(bb, m.v[bb].y, dentro), m.copia(ba, m.v[ba].y, dentro)])
		# A face aparece do lado OPOSTO ao produto vetorial (regra do projeto).
		var cruz := (m.v[q[1]] - m.v[q[0]]).cross(m.v[q[2]] - m.v[q[0]])
		if cruz.dot(dentro) > 0.0:
			q = PackedInt32Array([q[1], q[0], q[3], q[2]])
		saida.append_array(PackedInt32Array([q[0], q[1], q[2], q[0], q[2], q[3]]))
	return saida
