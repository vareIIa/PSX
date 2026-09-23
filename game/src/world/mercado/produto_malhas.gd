## A malha de cada FORMA de produto, uma so para todas as marcas.
##
## Uma lata de Brahma e uma de Guarana sao a mesma lata: muda o rotulo, e o
## rotulo vem do atlas pela celula que a instancia carrega (`INSTANCE_CUSTOM`,
## ver `usa_celula` no psx_surface). Muda tambem o tamanho, e o tamanho vem da
## escala da instancia. Por isso cabem nove malhas unitarias para a loja inteira
## e uma `MultiMesh` por forma: nove chamadas de desenho para quase tres mil
## produtos.
##
## A malha unitaria
## ----------------
## Ocupa x e z de -0,5 a 0,5 e y de 0 a 1, com a FRENTE olhando +Z. A instancia
## escala pela medida do catalogo e poe a base na prateleira.
##
## O contrato de UV (vale para toda forma, e o `baixar_rotulos.py` pinta por ele)
## -------------------------------------------------------------------------------
##   v de 0,00 a 0,15   tira de cima: u 0..0,5 e o TOPO (tampa, lacre, dobra),
##                      u 0,5..1 fica livre para a forma usar
##   v de 0,15 a 1,00   a volta inteira do produto, de cima (0,15) para baixo
##                      (1,00) em linha reta com a altura
##   u de 0,00 a 0,50   a FRENTE, da esquerda para a direita de quem olha
##   u de 0,50 a 1,00   o resto da volta: lado, costas, lado
##
## Linear com a altura quer dizer que a arte da garrafa desenha a garrafa
## INTEIRA na celula — liquido, rotulo, ombro, gargalo — nas alturas em que a
## malha os tem. Os perfis de cada forma estao em PERFIS, e o gerador do atlas
## le a mesma tabela (copiada la, com este arquivo citado).
class_name ProdutoMalhas
extends RefCounted

const Forma := CatalogoMercado.Forma

## Lados dos solidos de revolucao. Oito e o menor numero em que a lata ainda le
## redonda a um metro; com seis ela vira porca de parafuso.
const LADOS := 8

## Perfil de revolucao: pares (altura, raio), de baixo para cima, com raio 0,5
## no corpo. O ultimo anel fecha com tampa plana.
## O pe de cada forma e um anel so, sem chanfro: encostado na prateleira ele
## nunca aparece, e o chanfro custava dezesseis triangulos por unidade — um
## quinto dos 103 mil que a loja desenhava na primeira medida.
const PERFIS := {
	Forma.LATA: [Vector2(0.0, 0.47), Vector2(0.92, 0.5), Vector2(1.0, 0.43)],
	Forma.PET: [Vector2(0.0, 0.47), Vector2(0.62, 0.5), Vector2(0.8, 0.25),
		Vector2(0.88, 0.16), Vector2(1.0, 0.17)],
	Forma.GARRAFA: [Vector2(0.0, 0.48), Vector2(0.56, 0.5), Vector2(0.7, 0.3),
		Vector2(0.78, 0.18), Vector2(1.0, 0.17)],
	Forma.POTE: [Vector2(0.0, 0.47), Vector2(0.88, 0.5), Vector2(0.9, 0.53),
		Vector2(1.0, 0.53)],
	Forma.FRASCO: [Vector2(0.0, 0.47), Vector2(0.76, 0.5), Vector2(0.88, 0.3),
		Vector2(0.9, 0.15), Vector2(1.0, 0.15)],
}

## Uma etiqueta de preco: um quad, sem forma de produto.
const ETIQUETA := -1

static var _cache: Dictionary = {}


static func malha(forma: int) -> ArrayMesh:
	if _cache.has(forma):
		return _cache[forma]
	var m: ArrayMesh
	if forma == ETIQUETA:
		m = _etiqueta()
	elif PERFIS.has(forma):
		m = _revolucao(PERFIS[forma])
	elif forma == Forma.PACOTE:
		m = _pacote()
	else:
		m = _caixa()
	_cache[forma] = m
	return m


static func _v_lado(y: float) -> float:
	return 0.15 + 0.85 * (1.0 - clampf(y, 0.0, 1.0))


static func _montar(vs: PackedVector3Array, ns: PackedVector3Array,
		uvs: PackedVector2Array, idx: PackedInt32Array) -> ArrayMesh:
	var cores := PackedColorArray()
	cores.resize(vs.size())
	cores.fill(Color.WHITE)
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = vs
	a[Mesh.ARRAY_NORMAL] = ns
	a[Mesh.ARRAY_TEX_UV] = uvs
	a[Mesh.ARRAY_COLOR] = cores
	a[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m


## Solido de revolucao com a costura nas costas-esquerda (u = 0 e 1).
static func _revolucao(perfil: Array) -> ArrayMesh:
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var aneis := perfil.size()
	for k in LADOS + 1:
		var t := float(k) / float(LADOS)
		# t = 0 em -X (esquerda da frente), 0,5 em +X, passando por +Z.
		var ang := -PI * 0.5 + t * TAU
		var dx := sin(ang)
		var dz := cos(ang)
		for a in aneis:
			var p: Vector2 = perfil[a]
			vs.append(Vector3(dx * p.y, p.x, dz * p.y))
			# Normal do costado, inclinada pelo ombro: a luz por vertice do PS1
			# faz o resto.
			var inclina := 0.0
			if a > 0:
				var q: Vector2 = perfil[a - 1]
				inclina = (q.y - p.y) / maxf(0.001, p.x - q.x)
			ns.append(Vector3(dx, clampf(inclina, -1.5, 1.5), dz).normalized())
			uvs.append(Vector2(t, _v_lado(p.x)))
	for k in LADOS:
		for a in aneis - 1:
			var i0 := k * aneis + a
			var i1 := (k + 1) * aneis + a
			idx.append_array([i0, i0 + 1, i1, i1, i0 + 1, i1 + 1])
	# Tampa: leque no topo, pintado na tira de cima da celula.
	var topo: Vector2 = perfil[aneis - 1]
	var centro := vs.size()
	vs.append(Vector3(0.0, topo.x, 0.0))
	ns.append(Vector3.UP)
	uvs.append(Vector2(0.25, 0.075))
	for k in LADOS:
		var ang := -PI * 0.5 + float(k) / float(LADOS) * TAU
		vs.append(Vector3(sin(ang) * topo.y, topo.x, cos(ang) * topo.y))
		ns.append(Vector3.UP)
		uvs.append(Vector2(0.25 + sin(ang) * 0.22, 0.075 + cos(ang) * 0.07))
	for k in LADOS:
		var a := centro + 1 + k
		var b := centro + 1 + (k + 1) % LADOS
		idx.append_array([centro, b, a])
	return _montar(vs, ns, uvs, idx)


## Caixa sem fundo. Frente, lado direito, costas, lado esquerdo e tampa.
static func _caixa() -> ArrayMesh:
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	# (normal, eixo u da face, u0, u1)
	var faces := [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), 0.0, 0.5],
		[Vector3(1, 0, 0), Vector3(0, 0, -1), 0.5, 0.625],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), 0.625, 0.875],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), 0.875, 1.0],
	]
	for f: Array in faces:
		var n: Vector3 = f[0]
		var e: Vector3 = f[1]
		var base := vs.size()
		for canto: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			var p := n * 0.5 + e * (canto.x - 0.5) + Vector3(0, canto.y, 0)
			vs.append(p)
			ns.append(n)
			uvs.append(Vector2(lerpf(f[2], f[3], canto.x), _v_lado(canto.y)))
		idx.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	var t := vs.size()
	for canto: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		# canto.y = 0 na frente (+Z).
		vs.append(Vector3(canto.x - 0.5, 1.0, 0.5 - canto.y))
		ns.append(Vector3.UP)
		uvs.append(Vector2(canto.x * 0.5, 0.15 - canto.y * 0.15))
	idx.append_array([t, t + 2, t + 1, t, t + 3, t + 2])
	return _montar(vs, ns, uvs, idx)


## Embalagem mole: barriga no meio e fechada numa costura em cima.
##
## E o que separa um saco de salgadinho de uma caixa de sapato. A frente
## estufa 8% no meio e a boca fecha numa aresta com 20% da espessura.
static func _pacote() -> ArrayMesh:
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	# (y, meia espessura, meia largura)
	var secoes := [Vector3(0.0, 0.42, 0.47), Vector3(0.12, 0.5, 0.5),
		Vector3(0.55, 0.54, 0.5), Vector3(0.9, 0.2, 0.49), Vector3(1.0, 0.1, 0.5)]
	# Frente e costas.
	for lado: float in [1.0, -1.0]:
		var base := vs.size()
		for s: Vector3 in secoes:
			for c in 2:
				var x := (-s.z if c == 0 else s.z) * lado
				vs.append(Vector3(x, s.x, s.y * lado))
				ns.append(Vector3(0, 0.25, lado).normalized())
				var u := float(c) * 0.5 if lado > 0.0 else 0.625 + float(c) * 0.25
				uvs.append(Vector2(u, _v_lado(s.x)))
		for i in secoes.size() - 1:
			var a := base + i * 2
			idx.append_array([a, a + 3, a + 1, a, a + 2, a + 3])
	# Laterais: a sanfona, estreita.
	for lado: float in [1.0, -1.0]:
		var base := vs.size()
		for s: Vector3 in secoes:
			for c in 2:
				var z := (s.y if c == 0 else -s.y) * lado
				vs.append(Vector3(s.z * lado, s.x, z))
				ns.append(Vector3(lado, 0, 0))
				var u0 := 0.5 if lado > 0.0 else 0.875
				uvs.append(Vector2(u0 + float(c) * 0.125, _v_lado(s.x)))
		for i in secoes.size() - 1:
			var a := base + i * 2
			idx.append_array([a, a + 3, a + 1, a, a + 2, a + 3])
	# A costura de cima.
	var t := vs.size()
	var ul: Vector3 = secoes[secoes.size() - 1]
	for canto: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		vs.append(Vector3((canto.x - 0.5) * 2.0 * ul.z, 1.0, ul.y * (1.0 - canto.y * 2.0)))
		ns.append(Vector3.UP)
		uvs.append(Vector2(canto.x * 0.5, 0.15 - canto.y * 0.15))
	idx.append_array([t, t + 2, t + 1, t, t + 3, t + 2])
	return _montar(vs, ns, uvs, idx)


## Etiqueta de preco: quad de 1 x 1 em pe, olhando +Z, base em y = 0.
static func _etiqueta() -> ArrayMesh:
	var vs := PackedVector3Array([Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0),
		Vector3(0.5, 1, 0), Vector3(-0.5, 1, 0)])
	var ns := PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	var uvs := PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	return _montar(vs, ns, uvs, PackedInt32Array([0, 2, 1, 0, 3, 2]))


static func triangulos(forma: int) -> int:
	var m := malha(forma)
	return m.surface_get_array_index_len(0) / 3
