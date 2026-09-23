## Canteiro de geometria: junta as pecas de uma fachada por material e so
## despeja no chunk no fim.
##
## Por que existe
## -------------
## KitModular.caixa_cor e .placa passam por PSXMesh.acumular, que tira os arrays
## do balde do chunk para uma variavel e devolve no fim. PackedArray e copiado na
## escrita: com o balde ainda referenciado no dicionario, o primeiro append COPIA
## o balde inteiro. Uma peca a mais custa o tamanho do balde, e a fachada viva
## tem centenas de pecas por material — o construir de um chunk comercial foi de
## 17 para 49 ms, quase tudo copia. Aqui cada material e uma
## ParedeVazada.Malha (arrays de membro, sem copia), a caixa sai direto em
## vertices (sem PSXMesh.box_dados, que refazia a malha a cada tamanho novo), e o
## despejo e UM acumular por material por fachada.
##
## As pecas seguem as regras do kit: UV em metro (caixa a 0,8 por metro, placa
## de 0 a 1), face visivel escolhida pela conta (ParedeVazada.Malha.quad) e a
## rigidez ao vento no alfa do vertice para o que balanca.
class_name Obra
extends RefCounted

## UV da caixa, como KitModular._caixa (PSXMesh.box_dados a 0,8 por metro).
const UV_CAIXA := 0.8

var _baldes := {}


func _malha(material: StringName) -> ParedeVazada.Malha:
	var m: ParedeVazada.Malha = _baldes.get(material)
	if m == null:
		m = ParedeVazada.Malha.new()
		_baldes[material] = m
	return m


## O balde de um material, para quem monta vertice a vertice (a telha ondulada do
## TelhadoVivo, com normal por vertice).
func malha(material: StringName) -> ParedeVazada.Malha:
	return _malha(material)


## Caixa girada em Y (`giro`), como KitModular.caixa_cor. `faces` usa os bits de
## PSXMesh (FACE_FRENTE e +Z local, que com o giro da fachada e a rua).
func caixa(material: StringName, centro: Vector3, tamanho: Vector3, cor: Color,
		giro: float = 0.0, faces: int = PSXMesh.FACE_TODAS) -> void:
	livre(material, centro, tamanho, Basis(Vector3.UP, giro), cor, faces)


## Caixa com base qualquer.
func livre(material: StringName, centro: Vector3, tamanho: Vector3, base: Basis,
		cor: Color, faces: int = PSXMesh.FACE_TODAS) -> void:
	var m := _malha(material)
	var h := tamanho * 0.5
	var bx := base.x.normalized()
	var by := base.y.normalized()
	var bz := base.z.normalized()
	# (normal, eixo u, eixo v, meia no eixo normal, tamanho u, tamanho v, bit)
	var lados := [
		[bz, bx, by, h.z, tamanho.x, tamanho.y, PSXMesh.FACE_FRENTE],
		[-bz, -bx, by, h.z, tamanho.x, tamanho.y, PSXMesh.FACE_TRAS],
		[bx, -bz, by, h.x, tamanho.z, tamanho.y, PSXMesh.FACE_DIR],
		[-bx, bz, by, h.x, tamanho.z, tamanho.y, PSXMesh.FACE_ESQ],
		[by, bx, -bz, h.y, tamanho.x, tamanho.z, PSXMesh.FACE_TOPO],
		[-by, bx, bz, h.y, tamanho.x, tamanho.z, PSXMesh.FACE_BASE],
	]
	for l: Array in lados:
		if (faces & int(l[6])) == 0:
			continue
		var n: Vector3 = l[0]
		var u: Vector3 = l[1]
		var v: Vector3 = l[2]
		var mu := float(l[4]) * 0.5
		var mv := float(l[5]) * 0.5
		var c := centro + n * float(l[3])
		var su := float(l[4]) * UV_CAIXA
		var sv := float(l[5]) * UV_CAIXA
		var a := m.vertice(c - u * mu - v * mv, n, Vector2(0.0, sv), Vector2(0.0, 1.0), cor)
		var b := m.vertice(c + u * mu - v * mv, n, Vector2(su, sv), Vector2(1.0, 1.0), cor)
		var d := m.vertice(c + u * mu + v * mv, n, Vector2(su, 0.0), Vector2(1.0, 0.0), cor)
		var e := m.vertice(c - u * mu + v * mv, n, Vector2(0.0, 0.0), Vector2(0.0, 0.0), cor)
		m.quad(a, b, d, e, n)


## Placa vertical virada para a direcao do giro (como KitModular.placa): UV de 0
## a 1, que e o que vidro, cartaz e folha de flor querem.
func placa(material: StringName, centro: Vector3, tamanho: Vector2, giro: float,
		cor: Color = Color.WHITE) -> void:
	var b := Basis(Vector3.UP, giro)
	plano(material, centro, tamanho, b.z, b.x, cor, false)


## Parede vertical com UV em metro (como KitModular.parede_livre): textura de
## superficie, chapa ondulada, reboco. A UV2 vai de 0 a 1 (o shader de janela le).
func parede(material: StringName, centro: Vector3, tamanho: Vector2, giro: float,
		cor: Color = Color.WHITE) -> void:
	var b := Basis(Vector3.UP, giro)
	plano(material, centro, tamanho, b.z, b.x, cor, true)


## Plano virado para `normal`, com `eixo_u` ao longo da largura. `metrica`: UV em
## metro (0,5 por metro) em vez de 0 a 1.
func plano(material: StringName, centro: Vector3, tamanho: Vector2, normal: Vector3,
		eixo_u: Vector3, cor: Color = Color.WHITE, metrica: bool = true) -> void:
	var m := _malha(material)
	var u := eixo_u.normalized() * (tamanho.x * 0.5)
	var v := normal.cross(eixo_u).normalized() * (tamanho.y * 0.5)
	var su := tamanho.x * 0.5 if metrica else 1.0
	var sv := tamanho.y * 0.5 if metrica else 1.0
	var a := m.vertice(centro - u - v, normal, Vector2(0.0, sv), Vector2(0.0, 1.0), cor)
	var b := m.vertice(centro + u - v, normal, Vector2(su, sv), Vector2(1.0, 1.0), cor)
	var c := m.vertice(centro + u + v, normal, Vector2(su, 0.0), Vector2(1.0, 0.0), cor)
	var e := m.vertice(centro - u + v, normal, Vector2(0.0, 0.0), Vector2(0.0, 0.0), cor)
	m.quad(a, b, c, e, normal)


## Cartao em qualquer orientacao (flor, folha, cortina, barra de grade): a UV
## vem de `uv` (retangulo dentro da textura; Rect2(0,0,1,1) para ela inteira).
## `vento` grava a rigidez no alfa do vertice, como PSXMesh.acumular_flexivel:
## 0 = rigido (alfa 1), 1 = pe preso e ponta solta, 2 = topo preso e barra
## solta (cortina). `xform` poe o centro do cartao; a face olha para +Z dela.
func cartao(material: StringName, tamanho: Vector2, xform: Transform3D,
		uv: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0), cor: Color = Color.WHITE,
		vento: int = 0) -> void:
	var m := _malha(material)
	var bx := xform.basis.x.normalized() * (tamanho.x * 0.5)
	var by := xform.basis.y.normalized() * (tamanho.y * 0.5)
	var n := xform.basis.z.normalized()
	var o := xform.origin
	var baixo := 1.0 if vento != 1 else 0.0
	var cima := 1.0 if vento != 2 else 0.0
	if vento == 0:
		baixo = cor.a
		cima = cor.a
	var cb := Color(cor.r, cor.g, cor.b, baixo)
	var cc := Color(cor.r, cor.g, cor.b, cima)
	var a := m.vertice(o - bx - by, n, uv.position + Vector2(0.0, uv.size.y),
		Vector2(0.0, 1.0), cb)
	var b := m.vertice(o + bx - by, n, uv.position + uv.size, Vector2(1.0, 1.0), cb)
	var c := m.vertice(o + bx + by, n, uv.position + Vector2(uv.size.x, 0.0),
		Vector2(1.0, 0.0), cc)
	var e := m.vertice(o - bx + by, n, uv.position, Vector2(0.0, 0.0), cc)
	m.quad(a, b, c, e, n)


## Triangulo com a face virada para `normal` (o frontao da platibanda).
func triangulo(material: StringName, a: Vector3, b: Vector3, c: Vector3, normal: Vector3,
		cor: Color = Color.WHITE) -> void:
	var m := _malha(material)
	var ia := m.vertice(a, normal, Vector2(0.0, 1.0), Vector2(0.0, 1.0), cor)
	var ib := m.vertice(b, normal, Vector2(1.0, 1.0), Vector2(1.0, 1.0), cor)
	var ic := m.vertice(c, normal, Vector2(0.5, 0.0), Vector2(0.5, 0.0), cor)
	m.tri(ia, ib, ic, normal)


## Poligono convexo em leque a partir de `pontos[0]`, virado para `normal`, com UV
## em metro no plano da parede (0,5 por metro, como ParedeVazada). `origem_uv` e o
## ponto do plano que cai na UV (0, 0): passando o canto de cima e da esquerda da
## parede de baixo, o timpano do galpao e o oitao continuam a textura dela, fiada
## com fiada.
func leque(material: StringName, pontos: PackedVector3Array, normal: Vector3,
		eixo_u: Vector3, origem_uv: Vector3, cor: Color = Color.WHITE) -> void:
	if pontos.size() < 3:
		return
	var m := _malha(material)
	var u := eixo_u.normalized()
	var v := normal.cross(u).normalized()
	var idx := PackedInt32Array()
	for p: Vector3 in pontos:
		var d := p - origem_uv
		idx.append(m.vertice(p, normal, Vector2(d.dot(u), -d.dot(v)) * 0.5, Vector2.ZERO, cor))
	for k in range(1, pontos.size() - 1):
		m.tri(idx[0], idx[k], idx[k + 1], normal)


## Quad qualquer a-b-c-d (em volta), virado para `normal`, com UV em metro ao
## longo de `eixo_u` e do outro lado do plano: a agua do telhado, a chapa curva.
func quadra(material: StringName, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		normal: Vector3, eixo_u: Vector3, origem_uv: Vector3, cor: Color = Color.WHITE) -> void:
	var m := _malha(material)
	var u := eixo_u.normalized()
	var v := normal.cross(u).normalized()
	var ids := PackedInt32Array()
	for p: Vector3 in [a, b, c, d]:
		var dd := p - origem_uv
		ids.append(m.vertice(p, normal, Vector2(dd.dot(u), -dd.dot(v)) * 0.5, Vector2.ZERO, cor))
	m.quad(ids[0], ids[1], ids[2], ids[3], normal)


## Prisma de `lados` faces com tampa, de pe em `base` (caixa d'agua, botijao,
## tambor). Normal de vertice radial: de lado ele sombreia redondo, e nao em
## gomos; a face visivel sai da conta pela normal da face (Malha.quad).
func cilindro(material: StringName, base: Vector3, raio: float, alto: float,
		cor: Color, lados: int = 10) -> void:
	var m := _malha(material)
	var cima := Vector3(0.0, alto, 0.0)
	for k in lados:
		var a0 := TAU * k / lados
		var a1 := TAU * (k + 1) / lados
		var r0 := Vector3(cos(a0), 0.0, sin(a0))
		var r1 := Vector3(cos(a1), 0.0, sin(a1))
		var face := (r0 + r1).normalized()
		var u0 := raio * a0 * UV_CAIXA
		var u1 := raio * a1 * UV_CAIXA
		var sv := alto * UV_CAIXA
		var ia := m.vertice(base + r0 * raio, r0, Vector2(u0, sv), Vector2(0.0, 1.0), cor)
		var ib := m.vertice(base + r1 * raio, r1, Vector2(u1, sv), Vector2(1.0, 1.0), cor)
		var ic := m.vertice(base + r1 * raio + cima, r1, Vector2(u1, 0.0), Vector2(1.0, 0.0), cor)
		var ie := m.vertice(base + r0 * raio + cima, r0, Vector2(u0, 0.0), Vector2(0.0, 0.0), cor)
		m.quad(ia, ib, ic, ie, face)
	var tampa := cor.darkened(0.06)
	var centro := m.vertice(base + cima, Vector3.UP, Vector2(0.5, 0.5), Vector2(0.5, 0.5), tampa)
	for k in lados:
		var a0 := TAU * k / lados
		var a1 := TAU * (k + 1) / lados
		var p0 := base + cima + Vector3(cos(a0), 0.0, sin(a0)) * raio
		var p1 := base + cima + Vector3(cos(a1), 0.0, sin(a1)) * raio
		var i0 := m.vertice(p0, Vector3.UP, Vector2(0.5 + cos(a0) * 0.5, 0.5 + sin(a0) * 0.5),
			Vector2.ZERO, tampa)
		var i1 := m.vertice(p1, Vector3.UP, Vector2(0.5 + cos(a1) * 0.5, 0.5 + sin(a1) * 0.5),
			Vector2.ZERO, tampa)
		m.tri(centro, i0, i1, Vector3.UP)


## Um acumular por material, no fim da fachada.
func despejar(sup: Dictionary) -> void:
	for material: StringName in _baldes:
		(_baldes[material] as ParedeVazada.Malha).despejar(sup, material)
	_baldes.clear()
