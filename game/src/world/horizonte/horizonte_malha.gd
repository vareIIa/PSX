## A malha de uma celula do Horizonte, a partir da grade dela.
##
## Toda celula, em qualquer nivel da arvore, e uma grade de G x G pontos (as
## plantas dos chunks dela, juntadas e reduzidas: Horizonte._grade). O custo de
## uma celula nao depende do nivel, e e isso que deixa o raio crescer.
##
## Roda fora do fio principal.
##
## O que cada ponto da grade vira
## ------------------------------
##   chao     a grade de vertices COMPARTILHADOS da celula inteira, com a altura
##            de cada canto na media dos pontos em volta (a ladeira e rampa, e
##            nao escada). A cor e chapada: o triangulo pega a do vertice que o
##            provoca, e os dois triangulos de um ponto sao provocados pelo
##            canto dele (provoca_no_fim diz qual vertice o renderizador usa).
##            Sem vertice solto, sem junta em T no chao.
##   predio   telhado reto, juntado em retangulos do mesmo topo e da mesma cor;
##            parede ate o topo do vizinho mais baixo (ou enterrada no chao),
##            juntada em faixas ao longo da mesma linha da grade
##   copa     tronco de piramide flutuando sobre o chao (o chao continua
##            embaixo), oito vertices com normal de esfera: de longe le como
##            copa, e nao como cubo
##
## Com `recuo` (niveis da media, ponto de 16 m ou mais), o predio e um bloco por
## ponto, recuado da borda dele: o ponto de 32 m e um chunk inteiro, a rua mora
## na borda do chunk, e o vao entre os blocos e ela. O chao continua embaixo.
##
## A celula desce uma saia de SAIA m na borda: duas celulas vizinhas em niveis
## diferentes nao abrem fresta.
##
## Para o shader (psx_horizonte.gdshader)
## -------------------------------------
##   COLOR.rgb  cor linear da superficie (chapada)
##   COLOR.a    1 parede de predio (tem janela), 0,75 parede lisa, 0,5 copa,
##              0,25 lampada de poste, 0,125 chao e saia, 0 telhado
##   NORMAL     so vale no chao e na copa (suave); telhado e parede tiram a
##              normal da derivada da tela, chapada por triangulo, e por isso o
##              bloco recuado divide os oito vertices entre as seis faces
##   UV         .y: na parede, metros acima do chao; na lampada, o canto (-1..1)
##
## Atributos comprimidos (posicao e UV em 16 bits, normal octaedrica): a celula
## e local ao canto dela, entao 16 bits sao milimetros no nivel 0.
class_name HorizonteMalha
extends RefCounted

## Pontos por lado de toda celula.
const G := 64
const SAIA := 4.0
## Diferenca de altura (m) a partir da qual o ponto e bloco e nao chao.
const BLOCO_MIN := 1.0
## Degrau que o chao guarda (calcada, meio-fio, mureta baixa); o resto do que
## esta abaixo de BLOCO_MIN e achatado.
const DEGRAU_MAX := 0.3
## Quanto o topo da copa encolhe, em fracao do lado do ponto.
const COPA_TOPO := 0.3
## Altura da copa: de longe o tronco nao se ve, e a copa inteira ate o chao
## lia como poste. Ela flutua, com fundo.
const ALTURA_COPA := 5.0
const ESCURECE_PAREDE := 0.8
## Parede mais baixa que isto (m acima do chao) nao ganha janela.
const JANELA_MIN := 3.5
## A parede que encosta no chao desce isto abaixo dele: a rampa entre os cantos
## nao abre fresta embaixo da casa.
const ENTERRA := 0.5
## O telhado passa a parede por isto (m) onde o vizinho e mais baixo: fecha o
## pixel da junta entre a borda do telhado e o topo da parede.
const BEIRA := 0.03
## COLOR.a do chao e da saia (o shader usa a normal do vertice).
const CLASSE_CHAO := 0.125

enum Tipo { CHAO, PREDIO, COPA }

## O renderizador usa o ULTIMO vertice do triangulo para a cor chapada
## (OpenGL, Compatibility); Vulkan, D3D12 e Metal usam o primeiro.
static var provoca_no_fim := false

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()
var _uv := PackedVector2Array()
var _i := PackedInt32Array()

var _s := 1.0
var _recuo := 0.0
var _cor_rua := HorizonteDados.COR_ASFALTO.lerp(HorizonteDados._cor_do_material(&"calcada"), 0.4)
var _topo := PackedFloat32Array()
var _chao := PackedFloat32Array()
var _tipo := PackedByteArray()
var _parede_ok := PackedByteArray()
var _cor_topo := PackedColorArray()
var _cor_parede := PackedColorArray()
## Altura de cada vertice da grade do chao ((G + 1)^2).
var _h := PackedFloat32Array()


## `grade`: G x G pontos no formato da planta (HorizonteDados). `s`: lado do
## ponto em m. `lampadas`: pontos de luz locais a celula. `peso_lampada`:
## quantos postes cada ponto representa (1 = um so). `recuo`: fracao do ponto
## que o bloco de predio deixa livre de cada lado (0 = bloco cheio, juntado).
static func montar(grade: PackedByteArray, s: float, lampadas: PackedVector3Array,
		peso_lampada := 1.0, recuo := 0.0) -> ArrayMesh:
	var m := HorizonteMalha.new()
	m._s = s
	m._recuo = recuo * s
	m._ler(grade)
	m._chao_da_grade()
	if m._recuo > 0.0:
		m._blocos_recuados()
	else:
		m._telhados()
		m._paredes()
	m._copas()
	m._saias()
	m._postes(lampadas, peso_lampada)
	if m._i.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = m._v
	arrays[Mesh.ARRAY_NORMAL] = m._n
	arrays[Mesh.ARRAY_COLOR] = m._c
	arrays[Mesh.ARRAY_TEX_UV] = m._uv
	arrays[Mesh.ARRAY_INDEX] = m._i
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
	return malha


func _ler(grade: PackedByteArray) -> void:
	var n := G * G
	_topo.resize(n)
	_chao.resize(n)
	_tipo.resize(n)
	_parede_ok.resize(n)
	_cor_topo.resize(n)
	_cor_parede.resize(n)
	for p in n:
		var chao := HorizonteDados.chao_de(grade, p)
		var topo := HorizonteDados.topo_de(grade, p)
		var cls := HorizonteDados.classe_de(grade, p)
		var tipo := Tipo.CHAO
		if topo - chao >= BLOCO_MIN:
			var base := cls & 0x7F
			if base == HorizonteDados.Classe.PREDIO:
				tipo = Tipo.PREDIO
			elif base == HorizonteDados.Classe.COPA:
				tipo = Tipo.COPA
		_topo[p] = topo
		_chao[p] = chao
		_tipo[p] = tipo
		_parede_ok[p] = 1 if cls & HorizonteDados.TEM_PAREDE else 0
		_cor_topo[p] = HorizonteDados.cor_topo_de(grade, p)
		_cor_parede[p] = HorizonteDados.cor_parede_de(grade, p)


# --- chao -----------------------------------------------------------------------

func _chao_da_grade() -> void:
	var l := G + 1
	_h.resize(l * l)
	# A superficie de cada ponto: o chao, e o degrau baixo (calcada) do ponto
	# que e chao.
	var sup := PackedFloat32Array()
	sup.resize(G * G)
	for p in G * G:
		sup[p] = _chao[p]
		if _tipo[p] == Tipo.CHAO:
			sup[p] += clampf(_topo[p] - _chao[p], 0.0, DEGRAU_MAX)
	for qz in l:
		for qx in l:
			var soma := 0.0
			var n := 0
			for dz in 2:
				for dx in 2:
					var px := qx - dx
					var pz := qz - dz
					if px < 0 or pz < 0 or px >= G or pz >= G:
						continue
					soma += sup[pz * G + px]
					n += 1
			_h[qz * l + qx] = soma / n
	# Vertices: a cor e a do ponto de que o vertice e o canto (-X, -Z).
	var i0 := _v.size()
	for qz in l:
		for qx in l:
			var q := qz * l + qx
			_v.append(Vector3(qx * _s, _h[q], qz * _s))
			var hx0 := _h[qz * l + maxi(qx - 1, 0)]
			var hx1 := _h[qz * l + mini(qx + 1, G)]
			var hz0 := _h[maxi(qz - 1, 0) * l + qx]
			var hz1 := _h[mini(qz + 1, G) * l + qx]
			var dx := float(mini(qx + 1, G) - maxi(qx - 1, 0)) * _s
			var dz := float(mini(qz + 1, G) - maxi(qz - 1, 0)) * _s
			_n.append(Vector3((hx0 - hx1) / dx, 1.0, (hz0 - hz1) / dz).normalized())
			_c.append(Color(_cor_do_chao(mini(qx, G - 1), mini(qz, G - 1)), CLASSE_CHAO))
			_uv.append(Vector2.ZERO)
	# Dois triangulos por ponto que nao e predio, os dois provocados pelo canto
	# (qx, qz). Debaixo da copa o chao continua; com recuo, debaixo do predio
	# tambem (a rua e a borda do ponto).
	for pz in G:
		for px in G:
			if _tipo[pz * G + px] == Tipo.PREDIO and _recuo <= 0.0:
				continue
			var a := i0 + pz * l + px
			var b := a + 1
			var c := a + l + 1
			var d := a + l
			# Visivel de cima: a -> b -> c e a -> c -> d (a face do Godot e a do
			# lado oposto ao produto vetorial, memoria giro-de-face).
			_tri(a, b, c)
			_tri(a, c, d)


## Cor do chao do ponto: a do topo; debaixo da copa (ou do bloco recuado), a do
## vizinho que e chao (grama, quintal, rua), ou a do topo escurecida.
func _cor_do_chao(px: int, pz: int) -> Color:
	var p := pz * G + px
	if _tipo[p] == Tipo.CHAO:
		return _cor_topo[p]
	if _tipo[p] == Tipo.PREDIO:
		# Com recuo, o vao entre os blocos e a rua: asfalto e calcada.
		return _cor_topo[p] if _recuo <= 0.0 else _cor_rua

	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var qx := px + d.x
		var qz := pz + d.y
		if qx >= 0 and qz >= 0 and qx < G and qz < G and _tipo[qz * G + qx] == Tipo.CHAO:
			return _cor_topo[qz * G + qx]
	return _cor_topo[p] * 1.4


## Triangulo com a cor do vertice `a` (a volta a -> b -> c fica).
func _tri(a: int, b: int, c: int) -> void:
	if provoca_no_fim:
		_i.append_array([b, c, a])
	else:
		_i.append_array([a, b, c])


# --- predio ---------------------------------------------------------------------

## Telhados: retangulos gulosos de pontos de predio com o mesmo topo e a mesma
## cor. Onde todo vizinho do lado e mais baixo, a borda passa BEIRA da parede.
func _telhados() -> void:
	var feito := PackedByteArray()
	feito.resize(G * G)
	for pz in G:
		for px in G:
			var p := pz * G + px
			if feito[p] or _tipo[p] != Tipo.PREDIO:
				continue
			var w := 1
			while px + w < G and _mesmo_telhado(p, pz * G + px + w, feito):
				w += 1
			var h := 1
			var cresce := true
			while cresce and pz + h < G:
				for i in w:
					if not _mesmo_telhado(p, (pz + h) * G + px + i, feito):
						cresce = false
						break
				if cresce:
					h += 1
			for j in h:
				for i in w:
					feito[(pz + j) * G + px + i] = 1
			var y := _topo[p]
			var x0 := px * _s - (BEIRA if _lado_baixo(px, pz, h, 1, Vector2i(-1, 0), y) else 0.0)
			var x1 := (px + w) * _s + (BEIRA if _lado_baixo(px + w - 1, pz, h, 1, Vector2i(1, 0), y) else 0.0)
			var z0 := pz * _s - (BEIRA if _lado_baixo(px, pz, w, 0, Vector2i(0, -1), y) else 0.0)
			var z1 := (pz + h) * _s + (BEIRA if _lado_baixo(px, pz + h - 1, w, 0, Vector2i(0, 1), y) else 0.0)
			_quad(Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1),
				Vector3.UP, Color(_cor_topo[p], 0.0), 0.0, 0.0)


func _mesmo_telhado(p: int, q: int, feito: PackedByteArray) -> bool:
	return not feito[q] and _tipo[q] == Tipo.PREDIO and _topo[q] == _topo[p] \
		and _cor_topo[q] == _cor_topo[p]


## Todo vizinho ao longo de um lado do retangulo e mais baixo que `y`?
## `eixo` 1: o lado corre em Z (comprimento n a partir de pz); 0: em X.
func _lado_baixo(px: int, pz: int, n: int, eixo: int, fora: Vector2i, y: float) -> bool:
	for k in n:
		var qx := px + fora.x + (0 if eixo == 1 else k)
		var qz := pz + fora.y + (k if eixo == 1 else 0)
		if qx < 0 or qz < 0 or qx >= G or qz >= G:
			continue
		var q := qz * G + qx
		if _tipo[q] == Tipo.PREDIO and _topo[q] >= y - 0.05:
			return false
	return true


## Paredes: em cada linha da grade, a face de todo ponto de predio que da para
## um vizinho mais baixo, juntada com a da mesma linha enquanto topo, cor,
## classe e o pe (o topo do vizinho, ou o chao) combinam.
func _paredes() -> void:
	# (normal, passo ao longo, vizinho)
	for lado in 4:
		var fora: Vector2i = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][lado]
		var ao_longo := Vector2i(1, 0) if fora.y != 0 else Vector2i(0, 1)
		for linha in G:
			var run := {}
			for k in G + 1:
				var seg := {}
				if k < G:
					var px := k if fora.y != 0 else linha
					var pz := linha if fora.y != 0 else k
					seg = _segmento(px, pz, fora)
				if not run.is_empty() and not seg.is_empty() and _emenda(run, seg):
					run["fim"] = seg["fim"]
					run["pe_fim"] = seg["pe_fim"]
					run["chao"] = maxf(float(run["chao"]), float(seg["chao"]))
					continue
				if not run.is_empty():
					_parede_de(run, fora)
				run = seg


## A face do ponto (px, pz) virada para `fora`, ou vazio se nao ha parede.
func _segmento(px: int, pz: int, fora: Vector2i) -> Dictionary:
	var p := pz * G + px
	if _tipo[p] != Tipo.PREDIO:
		return {}
	var y1 := _topo[p]
	var qx := px + fora.x
	var qz := pz + fora.y
	var dentro := qx >= 0 and qz >= 0 and qx < G and qz < G
	var q := qz * G + qx
	# Os dois cantos da face, em vertices da grade.
	var a := Vector2i(px, pz)
	var b := Vector2i(px, pz)
	match fora:
		Vector2i(0, -1):
			b = Vector2i(px + 1, pz)
		Vector2i(1, 0):
			a = Vector2i(px + 1, pz)
			b = Vector2i(px + 1, pz + 1)
		Vector2i(0, 1):
			a = Vector2i(px, pz + 1)
			b = Vector2i(px + 1, pz + 1)
		Vector2i(-1, 0):
			b = Vector2i(px, pz + 1)
	var no_chao := not (dentro and _tipo[q] == Tipo.PREDIO)
	var pe_ini := 0.0
	var pe_fim := 0.0
	if no_chao:
		pe_ini = _h[a.y * (G + 1) + a.x] - ENTERRA
		pe_fim = _h[b.y * (G + 1) + b.x] - ENTERRA
	else:
		pe_ini = _topo[q]
		pe_fim = _topo[q]
	if y1 - maxf(pe_ini, pe_fim) < 0.05:
		return {}
	var cor := _cor_topo[p] * ESCURECE_PAREDE
	if _parede_ok[p]:
		cor = _cor_parede[p]
	elif dentro and _parede_ok[q]:
		cor = _cor_parede[q]
	var classe := 1.0 if y1 - _chao[p] >= JANELA_MIN else 0.75
	return {"ini": a, "fim": b, "y1": y1, "pe_ini": pe_ini, "pe_fim": pe_fim,
		"no_chao": no_chao, "cor": cor, "classe": classe, "chao": _chao[p]}


## O segmento `seg` continua a faixa `run`? No chao, o pe da faixa e a reta
## entre as pontas: so emenda se ela continua abaixo do chao no ponto do meio.
func _emenda(run: Dictionary, seg: Dictionary) -> bool:
	if seg["ini"] != run["fim"] or seg["y1"] != run["y1"] or seg["cor"] != run["cor"] \
			or seg["classe"] != run["classe"] or seg["no_chao"] != run["no_chao"]:
		return false
	if not run["no_chao"]:
		return seg["pe_ini"] == run["pe_ini"]
	# Pe da faixa emendada: de pe_ini ate o pe_fim do segmento. O vertice do
	# meio (o fim da faixa de agora) tem de ficar acima dessa reta.
	var ini: Vector2i = run["ini"]
	var meio: Vector2i = run["fim"]
	var fim: Vector2i = seg["fim"]
	var t := float((meio - ini).length()) / float((fim - ini).length())
	var reta := lerpf(float(run["pe_ini"]), float(seg["pe_fim"]), t)
	return reta <= float(run["pe_fim"]) + 0.02


func _parede_de(run: Dictionary, fora: Vector2i) -> void:
	var a: Vector2i = run["ini"]
	var b: Vector2i = run["fim"]
	var y1: float = run["y1"]
	var chao: float = run["chao"]
	var pa := Vector3(a.x * _s, 0.0, a.y * _s)
	var pb := Vector3(b.x * _s, 0.0, b.y * _s)
	var ya: float = run["pe_ini"]
	var yb: float = run["pe_fim"]
	_quad(Vector3(pa.x, ya, pa.z), Vector3(pb.x, yb, pb.z), Vector3(pb.x, y1, pb.z),
		Vector3(pa.x, y1, pa.z), Vector3(fora.x, 0.0, fora.y), Color(run["cor"], run["classe"]),
		ya - chao, y1 - chao, yb - chao)


## Um bloco por ponto de predio, recuado `_recuo` m da borda: telhado e as
## quatro paredes ate o chao (enterradas), sem juntar com o vizinho. Oito
## vertices: os de cima levam a cor do telhado e provocam os dois triangulos
## dele; os de baixo, a da parede, e provocam os da parede.
func _blocos_recuados() -> void:
	var l := G + 1
	var r := _recuo
	for pz in G:
		for px in G:
			var p := pz * G + px
			if _tipo[p] != Tipo.PREDIO:
				continue
			var y1 := _topo[p]
			var x0 := px * _s + r
			var z0 := pz * _s + r
			var x1 := (px + 1) * _s - r
			var z1 := (pz + 1) * _s - r
			var pe := minf(minf(_h[pz * l + px], _h[pz * l + px + 1]),
				minf(_h[(pz + 1) * l + px], _h[(pz + 1) * l + px + 1])) - ENTERRA
			if y1 - pe < 0.05:
				continue
			var cor := _cor_parede[p] if _parede_ok[p] else _cor_topo[p] * ESCURECE_PAREDE
			var classe := 1.0 if y1 - _chao[p] >= JANELA_MIN else 0.75
			var cp := Color(cor, classe)
			var ct := Color(_cor_topo[p], 0.0)
			var v0 := pe - _chao[p]
			var v1 := y1 - _chao[p]
			var i0 := _v.size()
			var cantos := [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]
			for j in 4:
				var q: Vector2 = cantos[j]
				_v.append(Vector3(q.x, pe, q.y))
				_n.append(Vector3.UP)
				_c.append(cp)
				_uv.append(Vector2(0.0, v0))
			for j in 4:
				var q: Vector2 = cantos[j]
				_v.append(Vector3(q.x, y1, q.y))
				_n.append(Vector3.UP)
				_c.append(ct)
				_uv.append(Vector2(0.0, v1))
			# Telhado, visivel de cima, provocado por t0.
			_tri(i0 + 4, i0 + 5, i0 + 6)
			_tri(i0 + 4, i0 + 6, i0 + 7)
			# Paredes -Z, +X, +Z, -X, visiveis de fora, provocadas pela base.
			for lado in 4:
				var b0 := i0 + lado
				var b1 := i0 + (lado + 1) % 4
				_tri(b0, b1, b0 + 4)
				_tri(b1, b1 + 4, b0 + 4)


# --- copa -----------------------------------------------------------------------

## Oito vertices por copa: a base no quadrado cheio, o topo recuado; a normal
## sai do centro (le redonda, e nao caixa).
func _copas() -> void:
	var l := G + 1
	for pz in G:
		for px in G:
			var p := pz * G + px
			if _tipo[p] != Tipo.COPA:
				continue
			var x0 := px * _s
			var z0 := pz * _s
			var x1 := x0 + _s
			var z1 := z0 + _s
			var k := _s * COPA_TOPO
			var chao := minf(minf(_h[pz * l + px], _h[pz * l + px + 1]),
				minf(_h[(pz + 1) * l + px], _h[(pz + 1) * l + px + 1]))
			var topo := _topo[p]
			var base := maxf(chao, topo - ALTURA_COPA)
			var centro := Vector3(x0 + 0.5 * _s, 0.5 * (base + topo), z0 + 0.5 * _s)
			var cor := Color(_cor_topo[p], 0.5)
			var escura := Color(_cor_topo[p] * 0.6, 0.5)
			var i0 := _v.size()
			var pontos := [
				Vector3(x0, base, z0), Vector3(x1, base, z0), Vector3(x1, base, z1), Vector3(x0, base, z1),
				Vector3(x0 + k, topo, z0 + k), Vector3(x1 - k, topo, z0 + k),
				Vector3(x1 - k, topo, z1 - k), Vector3(x0 + k, topo, z1 - k),
			]
			for j in 8:
				var pt: Vector3 = pontos[j]
				_v.append(pt)
				var n := pt - centro
				n.y *= 1.6
				_n.append(n.normalized())
				_c.append(escura if j < 4 else cor)
				_uv.append(Vector2.ZERO)
			# Topo (visivel de cima), provocado pelo topo.
			_tri(i0 + 4, i0 + 5, i0 + 6)
			_tri(i0 + 4, i0 + 6, i0 + 7)
			# Fundo (visivel de baixo), provocado pela base escura.
			_tri(i0 + 0, i0 + 2, i0 + 1)
			_tri(i0 + 0, i0 + 3, i0 + 2)
			# Lados, provocados pelo topo: -Z, +X, +Z, -X.
			for lado in 4:
				var b0 := i0 + lado
				var b1 := i0 + (lado + 1) % 4
				var t0 := b0 + 4
				var t1 := b1 + 4
				_tri(t0, b1, t1)
				_tri(t0, b0, b1)


# --- saia -----------------------------------------------------------------------

## Na borda da celula, do chao ate SAIA m abaixo, virada para fora. Os vertices
## de cima sao os do chao; os de baixo, novos (com a cor da saia, e sao eles que
## provocam).
func _saias() -> void:
	var l := G + 1
	# Cada borda: canto inicial, passo, normal para fora.
	var bordas := [
		[Vector2i(0, 0), Vector2i(1, 0), Vector3(0, 0, -1)],
		[Vector2i(G, 0), Vector2i(0, 1), Vector3(1, 0, 0)],
		[Vector2i(G, G), Vector2i(-1, 0), Vector3(0, 0, 1)],
		[Vector2i(0, G), Vector2i(0, -1), Vector3(-1, 0, 0)],
	]
	for bd: Array in bordas:
		var ini: Vector2i = bd[0]
		var passo: Vector2i = bd[1]
		var normal: Vector3 = bd[2]
		var baixo0 := _v.size()
		for k in l:
			var q: Vector2i = ini + passo * k
			var y := _h[q.y * l + q.x]
			_v.append(Vector3(q.x * _s, y - SAIA, q.y * _s))
			_n.append(normal)
			var px := clampi(q.x - (1 if passo.x < 0 or normal.x > 0 else 0), 0, G - 1)
			var pz := clampi(q.y - (1 if passo.y < 0 or normal.z > 0 else 0), 0, G - 1)
			_c.append(Color(_cor_do_chao(px, pz) * ESCURECE_PAREDE, CLASSE_CHAO))
			_uv.append(Vector2.ZERO)
		for k in G:
			var q0: Vector2i = ini + passo * k
			var q1: Vector2i = q0 + passo
			var t0 := q0.y * l + q0.x
			var t1 := q1.y * l + q1.x
			var b0 := baixo0 + k
			var b1 := baixo0 + k + 1
			# Volta para fora: a de cima e de fora vistas de fora.
			var a := _v[b0]
			var c := _v[t1]
			var b := _v[b1]
			if (b - a).cross(c - a).dot(normal) > 0.0:
				_tri(b0, t1, b1)
				_tri(b0, t0, t1)
			else:
				_tri(b0, b1, t1)
				_tri(b0, t1, t0)


# --- poste ----------------------------------------------------------------------

## Um triangulo por lampada, que o shader vira para a camera e acende a
## noite: o circulo de raio 1 inscrito nele (cantos a distancia 2 do centro).
## `peso`: quantos postes o ponto representa (vai em COLOR.r, o shader cresce).
func _postes(lampadas: PackedVector3Array, peso: float) -> void:
	var cor := Color(clampf((peso - 1.0) / 7.0, 0.0, 1.0), 1.0, 1.0, 0.25)
	for lampada: Vector3 in lampadas:
		var i0 := _v.size()
		for k in 3:
			_v.append(lampada)
			_n.append(Vector3.UP)
			_c.append(cor)
		_uv.append_array([Vector2(-1.7321, -1.0), Vector2(1.7321, -1.0), Vector2(0.0, 2.0)])
		# Os cantos sobem no plano da camera em sentido anti-horario vistos
		# dela; a volta visivel do Godot e a oposta.
		_i.append_array([i0, i0 + 2, i0 + 1])


# --- quadrado solto -------------------------------------------------------------

## Quadrado a-b-c-d com a frente para `normal`, a mesma cor nos quatro. a e b
## embaixo, c e d em cima: UV.y e `va` em a, `vb` em b (sem ele, `va`) e
## `vtopo` em c e d.
func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, cor: Color,
		va: float, vtopo: float, vb := NAN) -> void:
	var i0 := _v.size()
	_v.append_array([a, b, c, d])
	for k in 4:
		_n.append(normal)
		_c.append(cor)
	var v_b := va if is_nan(vb) else vb
	_uv.append_array([Vector2(0.0, va), Vector2(0.0, v_b), Vector2(0.0, vtopo),
		Vector2(0.0, vtopo)])
	# No Godot a face visivel e a do lado OPOSTO ao produto vetorial (memoria
	# giro-de-face-aponta-ao-contrario): acerta a volta pela normal pedida.
	if (b - a).cross(c - a).dot(normal) > 0.0:
		_i.append_array([i0, i0 + 2, i0 + 1, i0, i0 + 3, i0 + 2])
	else:
		_i.append_array([i0, i0 + 1, i0 + 2, i0, i0 + 2, i0 + 3])


func triangulos() -> int:
	return _i.size() / 3
