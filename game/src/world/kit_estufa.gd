## Kit de objetos da estufa: pote de erva, pe de maconha, vaso de feltro,
## regador, sementes, saco de terra, tanque, balanca, saquinho e ramo secando.
## E as variedades do poco, uma por andar, cada uma no seu recipiente (ver a
## secao "as variedades" no fim).
##
## Por que existe
## -------------
## A estufa desenhava tudo com caixa e uma celula de 32 px do atlas da casa. O
## pote de maconha era um cubo de vidro com uma caixa verde dentro; a planta, dois
## ou tres cartoes cruzados; o regador, um cartao chapado. Nada disso lia como a
## coisa que era, e a sala inteira depende de o jogador reconhecer de relance o
## que cada objeto e — o ciclo do Plantio nao tem tutorial, so objetos.
##
## Aqui cada peca e a forma dela: o pote e um solido de revolucao com ombro,
## rosca, tampa e rotulo; a folha e um leque de foliolos serrilhados, cada um com
## a propria geometria; a flor e um cacho de botoes irregulares com pistilo e
## geada. O atlas e proprio (tools/gerar_estufa_kit.py) porque serrilhado,
## pistilo e tricoma nao cabem em 32 px.
##
## Contrato
## --------
## So funcoes estaticas e puras: nada de no, autoload ou load() de recurso,
## porque a estufa e montada numa thread enquanto a porta abre (ver
## Interiores._planta). Escrevem geometria em `sup` (material -> dados do
## PSXMesh), que quem chama transforma em uma MeshInstance3D por material.
##
## Deterministico: a Plantacao refaz a malha enquanto o jogador olha, e duas
## chamadas com os mesmos argumentos tem de dar a mesma malha, vertice por
## vertice. Todo sorteio sai de `_rng(semente, canal)`, nunca de randf().
##
## Materiais
## ---------
##   estufa_kit        opaco (psx_surface): vaso, terra, tampa, rotulo, caixa,
##                     saco, tanque, balanca, a erva seca do pote e do saquinho
##   estufa_kit_folha  recorte + vento: a planta INTEIRA (caule, folha e flor
##                     juntos, senao a folha balanca e o caule que a segura fica
##                     parado) e o ramo secando. COLOR.a = quanto cede ao vento
##   estufa_kit_vidro  vidro com mistura por alfa (psx_vidro_kit): o pote e o
##                     plastico do saquinho
##   estufa_kit_brilho recorte + vento + emissao forte: so a flor acesa da
##                     Vagalume (ver `variedade`)
##
## Giro de face: a face visivel e a OPOSTA ao produto vetorial (regra do
## projeto, ver PSXMesh.placa_dados). `Balde.tri` decide a ordem pela normal que
## se quer, e por isso nenhuma funcao daqui escreve indice na mao.
class_name KitEstufa
extends RefCounted

const MAT: StringName = &"estufa_kit"
const MAT_FOLHA: StringName = &"estufa_kit_folha"
const MAT_VIDRO: StringName = &"estufa_kit_vidro"
## A flor que acende da Vagalume: recorta e balanca como a folha, e emite forte
## (mat_estufa_kit_brilho). So as colas dela moram aqui.
const MAT_BRILHO: StringName = &"estufa_kit_brilho"

## Medidas que quem monta a sala precisa saber.
const VASO_ALTURA := 0.46
const VASO_RAIO := 0.232
## Onde fica a superficie da terra, do pe do vaso. E dela que a planta nasce.
const TERRA_Y := 0.425
const POTE_ALTURA := 0.172
const POTE_RAIO := 0.055

## Atlas de 512 px. Os retangulos sao os de tools/gerar_estufa_kit.py (REG), em
## pixel; mudar la e aqui juntos.
const ATLAS := 512.0
const R_FOLIOLO := Rect2i(0, 0, 48, 192)
const R_ACUCAR := Rect2i(48, 0, 48, 128)
const R_COTILEDONE := Rect2i(48, 128, 48, 64)
const R_CAULE := Rect2i(96, 0, 32, 128)
const R_SEMENTE := Rect2i(96, 128, 32, 32)
const R_ETIQUETA := Rect2i(96, 160, 32, 32)
const R_BUD := Rect2i(128, 0, 128, 128)
const R_TERRA := Rect2i(256, 0, 128, 128)
const R_FELTRO := Rect2i(384, 0, 128, 128)
const R_ROTULOS: Array[Rect2i] = [Rect2i(128, 128, 128, 64), Rect2i(256, 128, 128, 64),
	Rect2i(384, 128, 128, 64), Rect2i(0, 192, 128, 64)]
const R_TAMPA := Rect2i(136, 192, 48, 48)
const R_SERRILHA := Rect2i(128, 240, 64, 16)
const R_METAL := Rect2i(192, 192, 64, 64)
const R_PLASTICO := Rect2i(256, 192, 64, 64)
const R_SACO := Rect2i(320, 192, 64, 64)
const R_CRIVO := Rect2i(384, 192, 64, 64)
const R_MADEIRA := Rect2i(448, 192, 64, 64)
const R_ROTULO_TERRA := Rect2i(0, 256, 128, 192)
const R_ENVELOPES: Array[Rect2i] = [Rect2i(128, 256, 64, 96), Rect2i(192, 256, 64, 96),
	Rect2i(256, 256, 64, 96), Rect2i(320, 256, 64, 96)]
const R_CAIXA_DENTRO := Rect2i(384, 256, 128, 64)
const R_LCD := Rect2i(384, 320, 64, 32)
const R_PAINEL := Rect2i(448, 320, 64, 64)
const R_TANQUE := Rect2i(384, 352, 64, 64)
const R_PISTILO := Rect2i(128, 352, 64, 64)
const R_SECO := Rect2i(192, 352, 48, 160)
const R_ZIP := Rect2i(0, 448, 64, 16)
# As celulas das variedades (REG_VARIEDADES do gerador).
const R_FOLIOLO_ROXO := Rect2i(240, 352, 48, 160)
const R_BUD_BRILHO := Rect2i(288, 352, 96, 96)
const R_CERAMICA := Rect2i(288, 448, 64, 64)
const R_CASCA := Rect2i(352, 448, 32, 64)

## O foliolo e um losango: pe em v = 1, a linha mais larga em v = 1 - T_LARGO,
## ponta em v = 0. O desenho do atlas cabe dentro dele (ver o gerador).
const T_LARGO := 0.42

## Tons de base. A textura ja traz a cor; isto so varia e envelhece.
const COR_SECA := Color(0.93, 0.88, 0.64)
const COR_FELTRO := Color(1.0, 1.0, 1.0)
const COR_REGADOR := Color(0.36, 0.72, 0.42)
const COR_TANQUE := Color(0.24, 0.46, 0.84)
const COR_VIDRO := Color(0.92, 0.98, 0.95, 0.45)


# --- o balde ----------------------------------------------------------------

## Vertices e triangulos de um material, com arrays de membro.
##
## PackedArray tirado do dicionario do `sup` e copiado na primeira escrita
## (COW), e a copia e do balde inteiro — ver Obra. Aqui cada peca monta no seu
## Balde e despeja UMA vez por material no fim.
class Balde extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var c := PackedColorArray()
	var i := PackedInt32Array()

	func vert(p: Vector3, nrm: Vector3, a_uv: Vector2, cor: Color) -> int:
		v.append(p)
		n.append(nrm)
		uv.append(a_uv)
		c.append(cor)
		return v.size() - 1

	## Triangulo com a face visivel virada para `normal`. Degenerado sai.
	func tri(a: int, b: int, cc: int, normal: Vector3) -> void:
		var produto := (v[b] - v[a]).cross(v[cc] - v[a])
		if produto.length_squared() < 1e-16:
			return
		if produto.dot(normal) > 0.0:
			i.append_array([a, cc, b])
		else:
			i.append_array([a, b, cc])

	## Quad a-b-cc-e em volta.
	func quad(a: int, b: int, cc: int, e: int, normal: Vector3) -> void:
		tri(a, b, cc, normal)
		tri(a, cc, e, normal)

	func dados() -> Dictionary:
		return {"v": v, "n": n, "uv": uv, "c": c, "i": i}


static func _balde(obra: Dictionary, material: StringName) -> Balde:
	if not obra.has(material):
		obra[material] = Balde.new()
	return obra[material]


static func _despejar(sup: Dictionary, obra: Dictionary) -> void:
	for material: StringName in obra:
		var b: Balde = obra[material]
		if b.i.is_empty():
			continue
		if not sup.has(material):
			sup[material] = PSXMesh.dados_vazios()
		PSXMesh.acumular(sup[material], b.dados(), Transform3D.IDENTITY)


# --- sorteio ------------------------------------------------------------------

## Um gerador por (semente, canal). Cada no da planta tem o seu canal, e por isso
## o terceiro no continua igual quando o decimo nasce: a planta cresce, e nao
## troca de cara a cada degrau de crescimento.
static func _rng(semente: int, canal: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(Vector2i(semente, canal)) ^ 0x4D41434F
	return r


## Hash para 0..1, sem estado.
static func _h(a: int, b: int = 0, c: int = 0) -> float:
	var x := (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	x = (x ^ (x >> 13)) * 1274126177
	x = x ^ (x >> 16)
	return float(x & 0xFFFF) / 65536.0


## Semente tirada de uma posicao: o pote numero 3 da prateleira tem sempre o
## mesmo rotulo e os mesmos botoes dentro.
static func _semente_de(p: Vector3) -> int:
	return hash(Vector3i(roundi(p.x * 100.0), roundi(p.y * 100.0), roundi(p.z * 100.0)))


# --- uv -----------------------------------------------------------------------

## Retangulo do atlas em UV, meio texel para dentro: filtro ponto na borda de uma
## celula le a vizinha.
static func _r(p: Rect2i) -> Rect2:
	var m := 0.5 / ATLAS
	return Rect2(Vector2(p.position) / ATLAS + Vector2(m, m),
		Vector2(p.size) / ATLAS - Vector2(m, m) * 2.0)


static func _uv(r: Rect2, u: float, v: float) -> Vector2:
	return r.position + Vector2(u, v) * r.size


## Sub-retangulo (u0, v0, u1, v1 em 0..1) de um retangulo de UV.
static func _sub(r: Rect2, u0: float, v0: float, u1: float, v1: float) -> Rect2:
	return Rect2(_uv(r, u0, v0), r.size * Vector2(u1 - u0, v1 - v0))


## Onda triangular: a textura vai e volta em vez de dar a volta. Espelhada, ela
## fecha em qualquer desenho, e a costura do solido de revolucao some.
static func _onda(x: float) -> float:
	var f := fposmod(x, 2.0)
	return f if f <= 1.0 else 2.0 - f


# --- primitivas ---------------------------------------------------------------

## Solido de revolucao em volta do Y de `xf`. `perfil` sao pares (raio, altura).
##
## A normal sai do proprio perfil: o caminho percorrido com o LADO DE FORA a
## direita. Subindo pelo costado ela aponta para fora; atravessando o topo para
## dentro, aponta para cima; descendo pela parede de dentro, aponta para o eixo.
## Assim uma chamada so faz a boca dobrada do vaso, por fora e por dentro.
## `dentro` inverte tudo, para a parede interna do vidro.
##
## `amassado` desloca o raio por coluna com uma funcao continua da altura: duas
## revolucoes que dividem um anel (o costado e a bainha do vaso) amassam igual e
## nao abrem fresta.
static func _revolucao(b: Balde, xf: Transform3D, perfil: PackedVector2Array,
		lados: int, r: Rect2, v0: float, v1: float, cor: Color,
		dentro: bool = false, rep: float = 2.0, amassado: float = 0.0,
		semente: int = 0, cores: PackedColorArray = PackedColorArray()) -> void:
	var aneis := perfil.size()
	var acum := PackedFloat32Array()
	acum.resize(aneis)
	var total := 0.0
	for a in aneis:
		if a > 0:
			total += perfil[a].distance_to(perfil[a - 1])
		acum[a] = total
	var inicio := b.v.size()
	for k in lados + 1:
		var ang := TAU * float(k) / float(lados)
		var dx := cos(ang)
		var dz := sin(ang)
		var u := _onda(float(k) / float(lados) * rep)
		for a in aneis:
			var p: Vector2 = perfil[a]
			var j := 1.0
			if amassado > 0.0:
				var hk := _h(semente, k % lados, 1)
				j += amassado * ((hk - 0.5) * 1.4 + 0.3 * sin(p.y * 23.0 + hk * 6.0))
			var ant: Vector2 = perfil[maxi(a - 1, 0)]
			var prox: Vector2 = perfil[mini(a + 1, aneis - 1)]
			var tg := prox - ant
			var n2 := Vector2(1.0, 0.0)
			if tg.length_squared() > 1e-14:
				n2 = Vector2(tg.y, -tg.x).normalized()
			var nrm := Vector3(dx * n2.x, n2.y, dz * n2.x)
			if dentro:
				nrm = -nrm
			var cr := cor if cores.is_empty() else cores[a]
			b.vert(xf * Vector3(dx * p.x * j, p.y, dz * p.x * j),
				(xf.basis * nrm).normalized(),
				_uv(r, u, lerpf(v0, v1, acum[a] / maxf(total, 1e-6))), cr)
	for k in lados:
		for a in aneis - 1:
			var i0 := inicio + k * aneis + a
			var i1 := inicio + (k + 1) * aneis + a
			b.quad(i0, i1, i1 + 1, i0 + 1, b.n[i0] + b.n[i1] + b.n[i0 + 1] + b.n[i1 + 1])


## Disco em leque, no plano XZ de `xf` a altura `y`, com a UV em circulo dentro
## do retangulo.
static func _disco(b: Balde, xf: Transform3D, y: float, raio: float, lados: int,
		r: Rect2, cor: Color, cima: bool = true) -> void:
	var nrm := (xf.basis * (Vector3.UP if cima else Vector3.DOWN)).normalized()
	var c0 := b.vert(xf * Vector3(0.0, y, 0.0), nrm, _uv(r, 0.5, 0.5), cor)
	for k in lados:
		var a := TAU * float(k) / float(lados)
		b.vert(xf * Vector3(cos(a) * raio, y, sin(a) * raio), nrm,
			_uv(r, 0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5), cor)
	for k in lados:
		b.tri(c0, c0 + 1 + k, c0 + 1 + (k + 1) % lados, nrm)


## Tubo por uma polilinha, com o raio de cada ponto. O quadro de referencia e
## transportado de ponto a ponto (sem torcer), e por isso a costura corre reta
## pelo caule em vez de dar voltas nele.
static func _tubo(b: Balde, pts: PackedVector3Array, raios: PackedFloat32Array,
		lados: int, r: Rect2, cor: Color, tampa: bool = false,
		cores: PackedColorArray = PackedColorArray()) -> void:
	var m := pts.size()
	if m < 2:
		return
	var t0 := (pts[1] - pts[0]).normalized()
	var ref := Vector3.UP if absf(t0.y) < 0.9 else Vector3.RIGHT
	var nrm := t0.cross(ref).normalized()
	var acum := PackedFloat32Array()
	acum.resize(m)
	var total := 0.0
	for a in m:
		if a > 0:
			total += pts[a].distance_to(pts[a - 1])
		acum[a] = total
	var inicio := b.v.size()
	for a in m:
		var tg: Vector3
		if a == 0:
			tg = pts[1] - pts[0]
		elif a == m - 1:
			tg = pts[a] - pts[a - 1]
		else:
			tg = pts[a + 1] - pts[a - 1]
		tg = tg.normalized()
		var proj := nrm - tg * nrm.dot(tg)
		if proj.length_squared() < 1e-8:
			proj = tg.cross(Vector3.RIGHT if absf(tg.x) < 0.9 else Vector3.FORWARD)
		nrm = proj.normalized()
		var bin := tg.cross(nrm)
		var cr := cor if cores.is_empty() else cores[a]
		for k in lados + 1:
			var ang := TAU * float(k) / float(lados)
			var d := nrm * cos(ang) + bin * sin(ang)
			b.vert(pts[a] + d * raios[a], d,
				_uv(r, _onda(float(k) / float(lados) * 2.0), acum[a] / maxf(total, 1e-6)), cr)
	var passo := lados + 1
	for a in m - 1:
		for k in lados:
			var i0 := inicio + a * passo + k
			b.quad(i0, i0 + 1, i0 + passo + 1, i0 + passo,
				b.n[i0] + b.n[i0 + 1] + b.n[i0 + passo] + b.n[i0 + passo + 1])
	if tampa:
		var fim := pts[m - 1]
		var dir := (pts[m - 1] - pts[m - 2]).normalized()
		var c0 := b.vert(fim, dir, _uv(r, 0.5, 1.0), cores[m - 1] if not cores.is_empty() else cor)
		var anel := inicio + (m - 1) * passo
		for k in lados:
			b.tri(c0, anel + k, anel + k + 1, dir)


## Face retangular virada para +Z de `xf`, com o retangulo de UV inteiro.
static func _placa(b: Balde, xf: Transform3D, tam: Vector2, r: Rect2, cor: Color,
		dupla: bool = false, cor_verso: Color = Color.WHITE) -> void:
	var h := tam * 0.5
	for face in (2 if dupla else 1):
		var s := 1.0 if face == 0 else -1.0
		var nrm := (xf.basis * Vector3(0.0, 0.0, s)).normalized()
		var cr := cor if face == 0 else cor_verso
		var a := b.vert(xf * Vector3(-h.x, h.y, 0.0), nrm, _uv(r, 0.0, 0.0), cr)
		var bb := b.vert(xf * Vector3(h.x, h.y, 0.0), nrm, _uv(r, 1.0, 0.0), cr)
		var cc := b.vert(xf * Vector3(h.x, -h.y, 0.0), nrm, _uv(r, 1.0, 1.0), cr)
		var d := b.vert(xf * Vector3(-h.x, -h.y, 0.0), nrm, _uv(r, 0.0, 1.0), cr)
		b.quad(a, bb, cc, d, nrm)


## Caixa com o retangulo inteiro em cada face; `sem_base` corta a de baixo.
static func _caixa(b: Balde, xf: Transform3D, tam: Vector3, r: Rect2, cor: Color,
		sem_base: bool = true, r_topo: Rect2 = Rect2()) -> void:
	var h := tam * 0.5
	var topo := r if r_topo.size == Vector2.ZERO else r_topo
	_placa(b, xf * Transform3D(Basis(), Vector3(0, 0, h.z)), Vector2(tam.x, tam.y), r, cor)
	_placa(b, xf * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -h.z)), Vector2(tam.x, tam.y), r, cor)
	_placa(b, xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(h.x, 0, 0)), Vector2(tam.z, tam.y), r, cor)
	_placa(b, xf * Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-h.x, 0, 0)), Vector2(tam.z, tam.y), r, cor)
	_placa(b, xf * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, h.y, 0)), Vector2(tam.x, tam.z), topo, cor)
	if not sem_base:
		_placa(b, xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -h.y, 0)), Vector2(tam.x, tam.z), r, cor)


## Um foliolo: losango dobrado na nervura, as duas faces.
##
## Quatro vertices por face: pe, as duas pontas da linha larga e a ponta. Os
## triangulos se dividem PELA NERVURA (pe-ponta), e as bordas sobem `dobra` da
## largura: e a canoa que a folha de maconha faz, e ela e o que separa uma folha
## de um papel recortado quando a luz bate de lado. A ponta cai `queda` do
## comprimento. O serrilhado e o recorte da textura.
static func _foliolo(b: Balde, p0: Vector3, dir: Vector3, lado: Vector3,
		cima: Vector3, comp: float, larg: float, queda: float, r: Rect2,
		cor: Color, cor_verso: Color, dobra: float = 0.2) -> void:
	var nf := dir.cross(lado).normalized()
	if nf.dot(cima) < 0.0:
		nf = -nf
	var pl := p0 + dir * comp * T_LARGO - lado * larg * 0.5 + nf * larg * dobra
	var pr := p0 + dir * comp * T_LARGO + lado * larg * 0.5 + nf * larg * dobra
	var pt := p0 + dir * comp - nf * comp * queda
	var nl := (pl - p0).cross(pt - p0).normalized()
	if nl.dot(nf) < 0.0:
		nl = -nl
	var nr := (pt - p0).cross(pr - p0).normalized()
	if nr.dot(nf) < 0.0:
		nr = -nr
	for face in 2:
		var s := 1.0 if face == 0 else -1.0
		var cr := cor if face == 0 else cor_verso
		var ib := b.vert(p0, nf * s, _uv(r, 0.5, 1.0), cr)
		var il := b.vert(pl, nl * s, _uv(r, 0.0, 1.0 - T_LARGO), cr)
		var ir := b.vert(pr, nr * s, _uv(r, 1.0, 1.0 - T_LARGO), cr)
		var it := b.vert(pt, nf * s, _uv(r, 0.5, 0.0), cr)
		b.tri(ib, il, it, nl * s)
		b.tri(ib, it, ir, nr * s)


## Cartao retangular com o pe em `p0`, nas duas faces: cotiledone e tufo.
static func _cartao(b: Balde, p0: Vector3, dir: Vector3, lado: Vector3,
		cima: Vector3, comp: float, larg: float, r: Rect2, cor: Color,
		cor_verso: Color, queda: float = 0.0) -> void:
	var nf := dir.cross(lado).normalized()
	if nf.dot(cima) < 0.0:
		nf = -nf
	var pt := p0 + dir * comp - nf * comp * queda
	for face in 2:
		var s := 1.0 if face == 0 else -1.0
		var cr := cor if face == 0 else cor_verso
		var a := b.vert(p0 - lado * larg * 0.5, nf * s, _uv(r, 0.0, 1.0), cr)
		var bb := b.vert(p0 + lado * larg * 0.5, nf * s, _uv(r, 1.0, 1.0), cr)
		var cc := b.vert(pt + lado * larg * 0.5, nf * s, _uv(r, 1.0, 0.0), cr)
		var d := b.vert(pt - lado * larg * 0.5, nf * s, _uv(r, 0.0, 0.0), cr)
		b.quad(a, bb, cc, d, nf * s)


## Um botao de flor: elipsoide amassado, com a textura de calice numa janela
## sorteada do atlas (dois botoes vizinhos nunca mostram o mesmo desenho).
##
## `aneis` 2 da tres aneis (6 x lados triangulos); 3 da quatro (8 x lados), para
## o botao grande da ponta da cola e o do pote, que sao o que o olho encontra
## primeiro. O ultimo anel fica perto do polo: o leque do polo usa um UV so no
## vertice do meio, e leque largo estica a textura do calice em listras.
static func _botao(b: Balde, centro: Vector3, raio: Vector3, base: Basis,
		lados: int, aneis: int, rng: RandomNumberGenerator, cor: Color,
		r_bud: Rect2 = Rect2()) -> void:
	var r := _r(R_BUD) if r_bud.size == Vector2.ZERO else r_bud
	var janela := 0.55
	var ou := rng.randf() * (1.0 - janela)
	var ov := rng.randf() * (1.0 - janela)
	var lats := PackedFloat32Array()
	if aneis >= 3:
		lats = PackedFloat32Array([-1.05, -0.4, 0.3, 1.0])
	else:
		lats = PackedFloat32Array([-0.95, 0.0, 0.95])
	var jit := PackedFloat32Array()
	for a in lats.size():
		for k in lados:
			jit.append(1.0 + rng.randf_range(-0.2, 0.16))
	var inicio := b.v.size()
	for a in lats.size():
		var lat := lats[a]
		for k in lados + 1:
			var ang := TAU * float(k) / float(lados) + float(a) * 0.5
			var j := jit[a * lados + (k % lados)]
			var dirl := Vector3(cos(lat) * cos(ang), sin(lat), cos(lat) * sin(ang))
			var p := Vector3(dirl.x * raio.x, dirl.y * raio.y, dirl.z * raio.z) * j
			var u := ou + _onda(float(k) / float(lados) * 2.0) * janela
			var v := ov + (1.0 - (lat + 1.5708) / 3.1416) * janela
			b.vert(centro + base * p, (base * dirl).normalized(), _uv(r, u, v), cor)
	var passo := lados + 1
	for a in lats.size() - 1:
		for k in lados:
			var i0 := inicio + a * passo + k
			b.quad(i0, i0 + 1, i0 + passo + 1, i0 + passo,
				b.n[i0] + b.n[i0 + 1] + b.n[i0 + passo] + b.n[i0 + passo + 1])
	# Os dois polos, um pouco para fora do elipsoide: a ponta do botao e pontuda.
	var sul := b.vert(centro + base * Vector3(0.0, -raio.y * 1.05, 0.0), base * Vector3.DOWN,
		_uv(r, ou + janela * 0.5, ov + janela), cor)
	var norte := b.vert(centro + base * Vector3(0.0, raio.y * 1.2, 0.0), base * Vector3.UP,
		_uv(r, ou + janela * 0.5, ov), cor)
	var ult := inicio + (lats.size() - 1) * passo
	for k in lados:
		b.tri(sul, inicio + k, inicio + k + 1, base * Vector3.DOWN)
		b.tri(norte, ult + k, ult + k + 1, base * Vector3.UP)


# --- a planta -----------------------------------------------------------------

## Pe de maconha do broto a planta florida, em `base` (a superficie da terra).
##
## A forma e a de pinheiro de Natal que a cannabis tem sem poda: nos em pares
## cruzados (cada par 90 graus do anterior), um galho saindo da axila de cada
## folha, os galhos de baixo compridos e os de cima curtos. A folha e o leque de
## 3, 5, 7 ou 9 foliolos, que cresce em numero de foliolo no do meio da planta e
## volta a diminuir no topo.
##
## `crescimento` 0..1:
##   0,00-0,10  muda: dois cotiledones redondos e o primeiro par serrilhado
##   0,10-1,00  o pe, com os nos nascendo de baixo para cima, ate 1,2 m
## `madura` poe as colas: a principal no topo e uma na ponta de cada galho, e o
## par de folhas de baixo amarelando, que e o que a planta faz no fim da flora.
##
## `verde` multiplica a cor da folha (a Plantacao varia o tom por vaso).
static func planta(sup: Dictionary, base: Vector3, crescimento: float,
		madura: bool, semente: int, verde: Color = Color.WHITE) -> void:
	var c := clampf(crescimento, 0.0, 1.0)
	var obra := {}
	var b := _balde(obra, MAT_FOLHA)
	var r0 := _rng(semente, 0)
	var altura := lerpf(0.05, 1.18, pow(c, 0.9)) * r0.randf_range(0.92, 1.06)
	var giro := r0.randf() * TAU
	if c < 0.1:
		_muda(b, base, c / 0.1, semente, giro, verde)
		altura = 0.08
	else:
		_pe(b, base, (c - 0.1) / 0.9, madura, semente, giro, verde, altura)
	_vento_da_planta(b, 0, base, maxf(altura, 0.08))
	_despejar(sup, obra)


## Quantos triangulos a planta tem nesta fase (para medida e orcamento).
static func triangulos_planta(crescimento: float, madura: bool) -> int:
	var sup := {}
	planta(sup, Vector3.ZERO, crescimento, madura, 1)
	var total := 0
	for m: StringName in sup:
		total += PSXMesh.dados_triangulos(sup[m])
	return total


## O alfa do vertice e quanto ele cede ao vento: zero no pe e cresce com a
## altura e com a distancia do caule — a ponta do foliolo de baixo balanca, o
## caule no pe nao sai do lugar.
static func _vento_da_planta(b: Balde, inicio: int, base: Vector3, altura: float) -> void:
	for k in range(inicio, b.v.size()):
		var p := b.v[k] - base
		var t := clampf(p.y / altura, 0.0, 1.0)
		var d := Vector2(p.x, p.z).length()
		var a := clampf(t * t * 0.85 + d * 1.1 * (0.3 + t), 0.0, 1.0)
		var cr := b.c[k]
		cr.a = a
		b.c[k] = cr


## Cor da folha: `verde` com uma variacao por folha, mais clara e amarelada no
## broto novo do topo, mais escura na folha velha de baixo.
static func _cor_folha(verde: Color, rel: float, rng: RandomNumberGenerator,
		amarelo: float = 0.0) -> Color:
	var v := rng.randf_range(0.9, 1.08)
	var cor := Color(verde.r * v, verde.g * v, verde.b * v)
	cor = cor.lerp(Color(1.0, 1.0, 0.78) * verde, clampf((rel - 0.7) * 1.6, 0.0, 0.45))
	cor = cor * lerpf(0.72, 1.0, rel)
	if amarelo > 0.0:
		# A textura e verde, e tinta multiplica: nao ha tom que faca verde virar
		# amarelo. Quem amarela e a folha seca do atlas (ver `_pe`); aqui so
		# esquenta.
		cor = Color(1.0, 0.96, 0.62)
	return _lim(cor)


## Cor de vertice corta em 1: o que passar disso nao clareia, so perde o tom.
static func _lim(c: Color) -> Color:
	return Color(minf(c.r, 1.0), minf(c.g, 1.0), minf(c.b, 1.0), 1.0)


## O verso da folha de maconha e mais claro e acinzentado.
static func _verso(cor: Color) -> Color:
	return _lim(cor.lerp(Color(0.95, 1.0, 0.88), 0.28) * 1.06)


static func _muda(b: Balde, base: Vector3, s: float, semente: int, giro: float,
		verde: Color, r_fol_outro: Rect2 = Rect2()) -> void:
	var rng := _rng(semente, 1)
	var cor_caule := Color(0.9, 1.0, 0.8) * verde
	var h0 := lerpf(0.022, 0.045, s)
	var inclina := Vector3(rng.randf_range(-0.004, 0.004), 0.0, rng.randf_range(-0.004, 0.004))
	var topo := base + Vector3(0.0, h0, 0.0) + inclina
	var r_caule := _r(R_CAULE)
	_tubo(b, PackedVector3Array([base - Vector3(0, 0.004, 0), base + Vector3(0, h0 * 0.5, 0) + inclina * 0.3, topo]),
		PackedFloat32Array([0.0022, 0.0019, 0.0016]), 4, r_caule, cor_caule)
	# Os cotiledones: a folha de semente, redonda e lisa, deitada.
	var r_cot := _r(R_COTILEDONE)
	var cor_cot := _lim(Color(1.0, 1.0, 0.9) * verde)
	for lado in 2:
		var a := giro + PI * float(lado)
		var d := Vector3(cos(a), 0.18, sin(a)).normalized()
		var lat := Vector3.UP.cross(d).normalized()
		var comp := lerpf(0.011, 0.017, s)
		_cartao(b, topo + d * 0.001, d, lat, Vector3.UP, comp, comp * 0.72,
			r_cot, cor_cot, _verso(cor_cot), 0.1)
	if s < 0.25:
		return
	# O primeiro par de folha verdadeira: um foliolo serrilhado so, cruzado com
	# os cotiledones. E a primeira vez que a planta tem cara de maconha.
	var epi := lerpf(0.004, 0.014, s)
	var no1 := topo + Vector3(0.0, epi, 0.0)
	_tubo(b, PackedVector3Array([topo, no1]), PackedFloat32Array([0.0015, 0.0013]), 4, r_caule, cor_caule)
	var r_fol := _r(R_FOLIOLO) if r_fol_outro.size == Vector2.ZERO else r_fol_outro
	var cor := _cor_folha(verde, 0.9, rng)
	var tam := lerpf(0.012, 0.034, (s - 0.25) / 0.75)
	for lado in 2:
		var a := giro + PI * 0.5 + PI * float(lado)
		var d := Vector3(cos(a), 0.5, sin(a)).normalized()
		var lat := Vector3.UP.cross(d).normalized()
		if s < 0.7:
			_foliolo(b, no1, d, lat, Vector3.UP, tam, tam * 0.25, 0.08, r_fol, cor, _verso(cor))
		else:
			_leque(b, no1, Vector3(cos(a), 0.0, sin(a)), 3, tam, tam * 0.2, 0.35,
				rng, cor, r_fol)
	# O olho do topo: duas folhinhas fechadas.
	if s > 0.6:
		for lado in 2:
			var a := giro + PI * float(lado)
			var d := Vector3(cos(a), 1.6, sin(a)).normalized()
			_foliolo(b, no1 + Vector3(0, 0.002, 0), d, Vector3.UP.cross(d).normalized(),
				Vector3.UP, 0.009, 0.0025, 0.0, r_fol, cor * 1.08, _verso(cor))


## Quantos foliolos tem a folha do no `k` (de baixo), num pe de `nos` nos.
static func _foliolos_do_no(k: int, nos: int) -> int:
	var tabela: Array[int] = [3, 5, 5, 7, 7, 7, 9, 9, 7, 7, 7]
	var n: int = tabela[mini(k, tabela.size() - 1)]
	# O topo e broto: folhas novas, com menos foliolos.
	var do_topo := nos - 1 - k
	if do_topo == 0:
		n = mini(n, 3)
	elif do_topo == 1:
		n = mini(n, 5)
	return n


## `opc` (vazio no pe de sempre) e o que as variedades mudam nele:
##   "r_fol"    outra celula de foliolo (a folha roxa da Vagalume)
##   "enxuto"   sem o broto da axila e sem folha de 9: cabe no orcamento de
##              quem soma coisa por cima (a Morcega paga o vaso pendurado)
##   "colas"    Array onde cada cola (e cada ponta de galho) e anotada como
##              {pe, eixo, comp, grossura, ponta}, para quem quer desenhar a
##              flor do proprio jeito
##   "sem_cola" nao desenha a cola (so anota)
##   "cor_caule" outra tinta no caule e nos galhos
static func _pe(b: Balde, base: Vector3, t: float, madura: bool, semente: int,
		giro: float, verde: Color, altura: float, opc: Dictionary = {}) -> void:
	var r_caule := _r(R_CAULE)
	var r_fol: Rect2 = opc.get("r_fol", _r(R_FOLIOLO))
	var enxuto: bool = opc.get("enxuto", false)
	var cor_caule: Color = opc.get("cor_caule", Color(0.86, 0.95, 0.74) * verde)
	cor_caule.a = 1.0
	var nos := 2 + int(round(t * 10.0))
	var r_base := lerpf(0.0035, 0.013, t)

	# A altura de cada no. Entre-no curto embaixo e no topo, maior no meio: o
	# topo apertado e onde a cola principal se forma.
	var ys := PackedFloat32Array()
	for k in nos:
		var f := float(k + 1) / (float(nos) + 0.35)
		ys.append(altura * pow(f, 0.92))
	# O caule: um ponto por no, com um leve zigue-zague (o caule da maconha
	# desvia um pouco a cada no, para o lado oposto a folha).
	var rng_c := _rng(semente, 2)
	var pts := PackedVector3Array([base - Vector3(0, 0.01, 0)])
	var raios := PackedFloat32Array([r_base])
	var eixo: Array[Vector3] = []
	for k in nos:
		var desvio := Vector3(rng_c.randf_range(-1, 1), 0.0, rng_c.randf_range(-1, 1)) * altura * 0.012
		var p := base + Vector3(0.0, ys[k], 0.0) + desvio
		eixo.append(p)
		pts.append(p)
		raios.append(lerpf(r_base, 0.0022, float(k + 1) / float(nos)))
	var ponta := base + Vector3(0.0, altura + 0.02, 0.0)
	pts.append(ponta)
	raios.append(0.0016)
	_tubo(b, pts, raios, 5, r_caule, cor_caule)

	for k in nos:
		var rng := _rng(semente, 100 + k)
		var rel := ys[k] / altura
		var no := eixo[k]
		# Pares cruzados embaixo; no topo da planta florida as folhas passam a
		# sair uma por no, alternadas.
		var par := not (madura and k >= nos - 3)
		var az := giro + float(k) * PI * 0.5 + rng.randf_range(-0.2, 0.2)
		if not par:
			az = giro + float(k) * 2.4
		var n_fol := _foliolos_do_no(k, nos)
		if enxuto:
			n_fol = mini(n_fol, 7)
		var forma := 0.72 + 0.4 * sin(PI * clampf(rel * 1.1, 0.0, 1.0))
		var tam := lerpf(0.06, 0.19, sqrt(t)) * forma
		if k == nos - 1:
			tam *= 0.55
		var amarelo := 0.0
		if madura and k <= 1:
			amarelo = 0.55 - 0.25 * float(k)
		var cor := _cor_folha(verde, rel, rng, amarelo)
		# Sem ternario: ternario de array nao sai tipado e a atribuicao falha.
		var lados_folha: Array[float] = [0.0]
		if par:
			lados_folha.append(PI)
		for lf: float in lados_folha:
			var a := az + lf
			var dh := Vector3(cos(a), 0.0, sin(a))
			var pec := tam * lerpf(1.0, 0.45, rel)
			var caido := lerpf(0.55, 0.1, rel) + rng.randf_range(-0.1, 0.1)
			_leque(b, no, dh, n_fol, tam, pec, caido, rng, cor,
				r_fol if amarelo < 0.3 else _r(R_SECO))
			# O galho sai da axila da folha, um pouco girado. No alto da planta
			# um lado so, alternado: dois galhos por no ate o topo viram vassoura.
			var tem_galho := k >= 1 and k <= nos - 2 and t > 0.12
			if tem_galho and rel > 0.55 and lf > 0.0 and k % 2 == 0:
				tem_galho = false
			var comp_galho := altura * 0.55 * pow(1.0 - rel, 0.8) * smoothstep(0.12, 0.55, t)
			if tem_galho and comp_galho > 0.04:
				_galho(b, no, a + rng.randf_range(0.3, 0.5), comp_galho, rel, madura,
					rng, verde, r_caule, r_fol, cor_caule, t, opc)
			elif k >= 1 and k < nos - 1 and t > 0.12 and not enxuto:
				# Galho que ainda nao saiu: o broto da axila, um leque pequeno em
				# pe. E o que enche o caule entre as folhas grandes.
				var cor_b := _cor_folha(verde, minf(rel + 0.3, 1.0), rng)
				_leque(b, no + Vector3(0, 0.006, 0), dh.rotated(Vector3.UP, 0.4), 5,
					tam * 0.42, 0.004, -0.35, rng, cor_b, r_fol)

	# O topo: broto de folhinhas, ou a cola principal.
	var rng_t := _rng(semente, 3)
	var ultimo := eixo[nos - 1]
	if madura:
		var comp_cola := altura * 0.24
		_cola_do_pe(b, opc, ponta - Vector3(0, comp_cola, 0), Vector3.UP, comp_cola + 0.03,
			0.038 + altura * 0.012, rng_t, verde, 3)
	else:
		_anotar_ponta(opc, ponta - Vector3(0, 0.03, 0), Vector3.UP, 0.05, 0.02)
		var cor_t := _cor_folha(verde, 1.0, rng_t)
		for k in 3:
			var a := giro + float(k) * TAU / 3.0
			_leque(b, ponta - Vector3(0, 0.012, 0), Vector3(cos(a), 0.0, sin(a)), 3,
				0.03 + 0.03 * t, 0.01, -0.5, rng_t, cor_t, r_fol)
	# Folhinhas entre o ultimo no e a ponta.
	if not madura and nos >= 3:
		var cor_m := _cor_folha(verde, 0.95, rng_t)
		var a2 := giro + PI * 0.25
		_leque(b, ultimo.lerp(ponta, 0.5), Vector3(cos(a2), 0, sin(a2)), 5, 0.05 + 0.04 * t,
			0.015, -0.1, rng_t, cor_m, r_fol)


## Um galho: sai do no inclinado, curva para cima e termina em pe. Carrega uma
## ou duas folhas e, na planta florida, uma cola na ponta.
static func _galho(b: Balde, no: Vector3, az: float, comp: float, rel: float,
		madura: bool, rng: RandomNumberGenerator, verde: Color, r_caule: Rect2,
		r_fol: Rect2, cor_caule: Color, t: float, opc: Dictionary = {}) -> void:
	var dh := Vector3(cos(az), 0.0, sin(az))
	var elev := deg_to_rad(rng.randf_range(34.0, 48.0))
	var p1 := no + (dh * cos(elev) + Vector3.UP * sin(elev)) * comp * 0.42
	var p2 := p1 + (dh * 0.45 + Vector3.UP).normalized() * comp * 0.34
	var p3 := p2 + (dh * 0.12 + Vector3.UP).normalized() * comp * 0.28
	var r0 := lerpf(0.0025, 0.0065, t) * (1.1 - rel * 0.6)
	_tubo(b, PackedVector3Array([no, p1, p2, p3]),
		PackedFloat32Array([r0, r0 * 0.8, r0 * 0.6, r0 * 0.45]), 4, r_caule, cor_caule)
	var cor := _cor_folha(verde, rel + 0.15, rng)
	var tam := lerpf(0.05, 0.14, sqrt(t)) * (1.0 - rel * 0.35)
	# Os nos do galho: uma folha em cada, alternando o lado, e a primeira em par
	# (o galho repete o caule em miniatura). A folha cresce para fora do galho.
	var linha := PackedVector3Array([no, p1, p2, p3])
	var nos_g := clampi(int(comp / 0.085), 1, 4)
	if opc.get("enxuto", false):
		nos_g = clampi(int(comp / 0.12), 1, 3)
	for j in nos_g:
		var f := (float(j) + 0.55) / (float(nos_g) + 0.45)
		var p := _na_linha(linha, f)
		var lado_j := 1.0 if j % 2 == 0 else -1.0
		var encolhe := 1.0 - f * 0.45
		var lados_j: Array[float] = [lado_j]
		if j == 0:
			lados_j.append(-lado_j)
		for lj: float in lados_j:
			var a1 := az + lj * rng.randf_range(0.7, 1.2)
			var n_f := 7 if tam * encolhe > 0.085 else 5
			if opc.get("enxuto", false):
				n_f = 5
			_leque(b, p, Vector3(cos(a1), 0.0, sin(a1)), n_f, tam * encolhe,
				tam * encolhe * 0.5, lerpf(0.4, 0.15, f), rng, cor, r_fol)
	if madura:
		_cola_do_pe(b, opc, p2.lerp(p3, 0.3), (p3 - p2).normalized(), p3.distance_to(p2) * 0.8 + 0.04,
			0.022 + comp * 0.03, rng, verde, 2)
	else:
		_anotar_ponta(opc, p3, (p3 - p2).normalized(), 0.04, 0.016)
		var cor_p := _cor_folha(verde, 1.0, rng)
		_leque(b, p3, dh, 3, tam * 0.45, 0.006, -0.3, rng, cor_p, r_fol)


## A cola do pe e do galho. Sem `opc` e a `_cola` de sempre; a variedade que
## pede anota onde ela vai (e, com "sem_cola", desenha a flor do seu jeito).
static func _cola_do_pe(b: Balde, opc: Dictionary, pe: Vector3, eixo: Vector3,
		comp: float, grossura: float, rng: RandomNumberGenerator, verde: Color,
		aneis: int) -> void:
	if opc.has("colas"):
		(opc["colas"] as Array).append({"pe": pe, "eixo": eixo, "comp": comp,
			"grossura": grossura, "ponta": false})
	if not opc.get("sem_cola", false):
		# Enxuta, a cola comprida fica com botoes maiores e menos deles.
		_cola(b, pe, eixo, comp, grossura, rng, verde, aneis, false,
			6 if opc.get("enxuto", false) else 8)


## A ponta de galho que ainda nao floriu, anotada para quem pediu.
static func _anotar_ponta(opc: Dictionary, pe: Vector3, eixo: Vector3, comp: float,
		grossura: float) -> void:
	if opc.has("colas"):
		(opc["colas"] as Array).append({"pe": pe, "eixo": eixo, "comp": comp,
			"grossura": grossura, "ponta": true})


## O ponto a uma fracao `f` do comprimento de uma linha quebrada.
static func _na_linha(pts: PackedVector3Array, f: float) -> Vector3:
	var total := 0.0
	for k in range(1, pts.size()):
		total += pts[k].distance_to(pts[k - 1])
	var alvo := clampf(f, 0.0, 1.0) * total
	for k in range(1, pts.size()):
		var seg := pts[k].distance_to(pts[k - 1])
		if alvo <= seg or k == pts.size() - 1:
			return pts[k - 1].lerp(pts[k], clampf(alvo / maxf(seg, 1e-5), 0.0, 1.0))
		alvo -= seg
	return pts[pts.size() - 1]


## A folha em leque: peciolo e os foliolos abertos na ponta dele.
##
## `dh` e a direcao no chao para onde a folha sai. O plano do leque inclina com
## o peciolo; os foliolos de fora sao menores e caem mais — sao eles que dao a
## silhueta de mao aberta, inconfundivel, que a folha de maconha tem.
## `caido` 0 = folha erguida; 1 = pendurada (a folha velha de baixo).
static func _leque(b: Balde, no: Vector3, dh: Vector3, n: int, tam: float,
		pec: float, caido: float, rng: RandomNumberGenerator, cor: Color,
		r_fol: Rect2) -> void:
	var lado_h := Vector3.UP.cross(dh).normalized()
	var sobe := lerpf(0.9, -0.2, clampf(caido, 0.0, 1.0))
	var c0 := no
	if pec > 0.008:
		var meio := no + dh * pec * 0.5 + Vector3.UP * pec * (0.25 + sobe * 0.3)
		c0 = no + dh * pec + Vector3.UP * pec * sobe * 0.35
		var cor_p := Color(0.85, 0.95, 0.7) * cor
		cor_p.a = 1.0
		_tubo(b, PackedVector3Array([no, meio, c0]),
			PackedFloat32Array([0.0022, 0.0018, 0.0014]), 3, _r(R_CAULE), cor_p)
	# O plano do leque: para a frente e um pouco para cima, girado um tanto.
	var frente := (dh + Vector3.UP * (0.25 - caido * 0.45)).normalized()
	var torce := rng.randf_range(-0.25, 0.25)
	var normal := frente.cross(lado_h).normalized()
	if normal.dot(Vector3.UP) < 0.0:
		normal = -normal
	normal = normal.rotated(frente, torce)
	_leque_livre(b, c0, frente, normal, n, tam, caido, rng, cor, r_fol)


## Os foliolos de um leque ja orientado: pe em `c0`, abrindo em volta de
## `frente` no plano de normal `normal` (a face de cima). Os de fora caem mais,
## para tras da face. `abre` multiplica a abertura (o salgueiro fecha a mao).
static func _leque_livre(b: Balde, c0: Vector3, frente: Vector3, normal: Vector3,
		n: int, tam: float, caido: float, rng: RandomNumberGenerator, cor: Color,
		r_fol: Rect2, abre: float = 1.0, larg_rel: float = 0.265) -> void:
	var meio_n := float(n - 1) * 0.5
	var abertura := deg_to_rad(clampf(18.0 + meio_n * 24.0, 30.0, 110.0)) * abre
	var verso := _verso(cor)
	for k in n:
		var off := float(k) - meio_n
		var fr := absf(off) / maxf(meio_n, 1.0)
		var ang := off / maxf(meio_n, 1.0) * abertura + rng.randf_range(-0.06, 0.06)
		var d := frente.rotated(normal, ang)
		# Os de fora caem mais.
		d = (d - normal * (0.12 + 0.35 * fr * fr + caido * 0.2)).normalized()
		var comp := tam * (1.0 - pow(fr, 1.5) * 0.72) * rng.randf_range(0.92, 1.05)
		var larg := comp * larg_rel
		var lat := normal.cross(d).normalized()
		_foliolo(b, c0 + d * 0.003, d, lat, normal, comp, larg,
			0.1 + 0.12 * fr + caido * 0.1, r_fol, cor, verso)


## A cola: botoes empilhados num eixo, grossos no meio e em ponta no alto, com
## foliolos de acucar (a folhinha coberta de geada) saindo entre eles e um tufo
## de pistilo na ponta.
static func _cola(b: Balde, pe: Vector3, eixo: Vector3, comp: float, grossura: float,
		rng: RandomNumberGenerator, verde: Color, aneis: int,
		seca: bool = false, max_botoes: int = 8) -> void:
	var cor := _lim(Color(1.0, 1.0, 0.92) * verde)
	if seca:
		cor = COR_SECA
	cor.a = 1.0
	var qtd := clampi(int(comp / 0.03) + 2, 2, max_botoes)
	var lado := eixo.cross(Vector3.RIGHT if absf(eixo.x) < 0.9 else Vector3.FORWARD).normalized()
	var outro := eixo.cross(lado)
	var r_acu := _r(R_ACUCAR)
	var cor_acu := Color(0.95, 1.0, 0.9) * verde
	if seca:
		cor_acu = COR_SECA * 0.9
	cor_acu.a = 1.0
	var base := Basis(lado, eixo, outro)
	for k in qtd:
		var tt := (float(k) + 0.5) / float(qtd)
		var raio := grossura * (0.62 + 0.38 * sin(PI * (0.2 + 0.7 * tt))) * (1.0 - 0.55 * pow(tt, 3.0))
		var ang := rng.randf() * TAU
		var fora := (lado * cos(ang) + outro * sin(ang)) * raio * 0.22
		var centro := pe + eixo * comp * tt + fora
		var giro := Basis(eixo, rng.randf() * TAU)
		_botao(b, centro, Vector3(raio, raio * 1.25, raio) * rng.randf_range(0.9, 1.1),
			giro * base, 5, aneis if k == qtd - 1 else 2, rng, cor)
		# Um foliolo de acucar em quase todo botao.
		if rng.randf() < 0.8:
			var a := rng.randf() * TAU
			var saida := (lado * cos(a) + outro * sin(a)).normalized()
			var d := (saida * 0.8 + eixo * 0.6).normalized()
			var lat := eixo.cross(d).normalized()
			_foliolo(b, centro + saida * raio * 0.4, d, lat, eixo, raio * 2.3,
				raio * 0.8, 0.15, r_acu, cor_acu, _verso(cor_acu), 0.25)
	# O tufo de pistilo no alto: dois cartoes cruzados.
	var r_pis := _r(R_PISTILO)
	var topo := pe + eixo * comp * 0.97
	var cor_p := Color(1, 1, 1) if not seca else Color(0.75, 0.62, 0.5)
	for k in 2:
		var lat := (lado if k == 0 else outro)
		_cartao(b, topo - eixo * grossura * 0.35, eixo, lat, lat.cross(eixo), grossura * 1.1,
			grossura * 1.3, r_pis, cor_p, cor_p)


# --- o vaso -------------------------------------------------------------------

## Vaso de feltro (smart pot) de 25 L, com a boca dobrada e costurada, duas alcas
## de fita e a etiqueta. `base` e o centro do fundo.
##
## Vazio, a parede de dentro desce ate o fundo e escurece em direcao a ele: o
## que se ve e um POCO, e nao uma tampa preta. Com terra, a superficie tem
## relevo, e `molhado` escurece a terra e o pe do feltro (o vaso de tecido puxa
## a agua pela parede, e a marca de umido sobe do chao).
static func vaso(sup: Dictionary, base: Vector3, tem_terra: bool, molhado: float,
		semente: int) -> void:
	var obra := {}
	var b := _balde(obra, MAT)
	var rng := _rng(semente, 7)
	var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), base)
	_vaso_em(b, xf, tem_terra, molhado, semente, 16, COR_FELTRO)
	_despejar(sup, obra)


## O vaso de feltro em `xf` (o pe na origem, a boca em +Y). A Morcega o pendura
## de boca para baixo; `lados` menor e o vaso mais barato, e `cor` tinge o
## feltro inteiro.
static func _vaso_em(b: Balde, xf: Transform3D, tem_terra: bool, molhado: float,
		semente: int, lados: int, cor_feltro: Color) -> void:
	var molh := clampf(molhado, 0.0, 1.0) if tem_terra else 0.0
	var r_fel := _r(R_FELTRO)
	var corpo := _sub(r_fel, 0.0, 0.12, 1.0, 1.0)
	var bainha := _sub(r_fel, 0.0, 0.0, 1.0, 0.12)
	var amassa := 0.022

	var perfil := PackedVector2Array([Vector2(0.196, 0.0), Vector2(0.212, 0.01),
		Vector2(0.224, 0.05), Vector2(0.231, 0.16), Vector2(0.232, 0.28),
		Vector2(0.229, 0.37), Vector2(0.226, 0.415)])
	var cores := PackedColorArray()
	for p: Vector2 in perfil:
		cores.append(cor_feltro * (1.0 - 0.4 * molh * (1.0 - smoothstep(0.0, 0.3, p.y))))
	_revolucao(b, xf, perfil, lados, corpo, 1.0, 0.0, cor_feltro, false, 4.0, amassa, semente, cores)
	# A boca: sobe, dobra por cima e desce por dentro, na bainha costurada.
	var boca := PackedVector2Array([Vector2(0.226, 0.415), Vector2(0.231, 0.428),
		Vector2(0.233, 0.446), Vector2(0.228, 0.458), Vector2(0.219, 0.46),
		Vector2(0.213, 0.45), Vector2(0.212, 0.432)])
	_revolucao(b, xf, boca, lados, bainha, 1.0, 0.0, cor_feltro * 0.92, false, 4.0, amassa, semente)
	# A parede de dentro, ate a terra ou ate o fundo.
	var fundo := TERRA_Y - 0.012 if tem_terra else 0.03
	var dentro := PackedVector2Array([Vector2(0.21, fundo), Vector2(0.212, 0.432)])
	var cores_d := PackedColorArray([Color(0.3, 0.3, 0.3) if not tem_terra else Color(0.7, 0.7, 0.7),
		Color(0.85, 0.85, 0.85)])
	_revolucao(b, xf, dentro, lados, corpo, 1.0, 0.0, Color.WHITE, true, 4.0, amassa, semente, cores_d)
	if not tem_terra:
		_disco(b, xf, fundo, 0.212, lados, _sub(r_fel, 0.1, 0.2, 0.9, 1.0), Color(0.22, 0.22, 0.23))
	else:
		_terra(b, xf, molh, semente)

	# As alcas: fita arqueada no plano tangente, presa abaixo da boca dos dois
	# lados. A costura da fita e a mesma bainha.
	for lado in 2:
		var az := PI * 0.5 + PI * float(lado)
		var fita := PackedVector3Array()
		for k in 7:
			var s := float(k) / 6.0
			var a := az + lerpf(-0.2, 0.2, s)
			var rr := 0.236 + 0.012 * sin(PI * s)
			fita.append(Vector3(cos(a) * rr, 0.395 + 0.085 * sin(PI * s), sin(a) * rr))
		_fita(b, xf, fita, 0.034, az, bainha, cor_feltro * 0.8)
	# A etiqueta costurada na parede.
	var az_e := PI * 0.5 + 0.55
	var pe := Vector3(cos(az_e) * 0.2335, 0.36, sin(az_e) * 0.2335)
	var olha := Vector3(cos(az_e), 0.0, sin(az_e))
	_placa(b, xf * Transform3D(Basis.looking_at(-olha, Vector3.UP), pe), Vector2(0.05, 0.05),
		_r(R_ETIQUETA), Color(0.95, 0.95, 0.95))


## Fita de alca: tira dupla-face seguindo `pts`, com a largura no plano tangente
## ao vaso (a face da fita olha para fora, como a alca de verdade).
static func _fita(b: Balde, xf: Transform3D, pts: PackedVector3Array, larg: float,
		az: float, r: Rect2, cor: Color) -> void:
	var radial := Vector3(cos(az), 0.0, sin(az))
	var n := pts.size()
	for face in 2:
		var s := 1.0 if face == 0 else -1.0
		var inicio := b.v.size()
		for k in n:
			var tg := (pts[mini(k + 1, n - 1)] - pts[maxi(k - 1, 0)]).normalized()
			var w := radial.cross(tg).normalized()
			var u := float(k) / float(n - 1)
			var nrm := (xf.basis * (radial * s)).normalized()
			b.vert(xf * (pts[k] + w * larg * 0.5), nrm, _uv(r, u * 2.0 - floorf(u * 2.0), 0.0), cor)
			b.vert(xf * (pts[k] - w * larg * 0.5), nrm, _uv(r, u * 2.0 - floorf(u * 2.0), 1.0), cor)
		for k in n - 1:
			var i0 := inicio + k * 2
			b.quad(i0, i0 + 2, i0 + 3, i0 + 1, (xf.basis * (radial * s)))


## A terra do vaso: disco com relevo, perlita por cima, mais escura molhada.
static func _terra(b: Balde, xf: Transform3D, molh: float, semente: int) -> void:
	var r := _r(R_TERRA)
	var cor := Color(1.0, 1.0, 1.0).lerp(Color(0.5, 0.44, 0.4), molh)
	var aneis: Array[float] = [0.0, 0.075, 0.15, 0.213]
	var lados := 16
	var inicio := b.v.size()
	for a in aneis.size():
		var rr: float = aneis[a]
		var n_col := 1 if a == 0 else lados
		for k in n_col:
			var ang := TAU * float(k) / float(lados)
			var x := cos(ang) * rr
			var z := sin(ang) * rr
			var y := TERRA_Y + 0.006 * (1.0 - rr / 0.213)
			if a > 0 and a < aneis.size() - 1:
				y += (_h(semente, k, a) - 0.5) * 0.012
			elif a == aneis.size() - 1:
				y -= 0.004
			b.vert(xf * Vector3(x, y, z), xf.basis * Vector3.UP,
				_uv(r, 0.5 + x / 0.44, 0.5 + z / 0.44), cor)
	# Normais pela vizinhanca: o relevo tem de pegar luz.
	for a in range(1, aneis.size()):
		for k in lados:
			var i := inicio + 1 + (a - 1) * lados + k
			var dentro := inicio if a == 1 else inicio + 1 + (a - 2) * lados + k
			var prox := inicio + 1 + (a - 1) * lados + (k + 1) % lados
			var ant := inicio + 1 + (a - 1) * lados + (k + lados - 1) % lados
			var nrm := (b.v[prox] - b.v[ant]).cross(b.v[i] - b.v[dentro]).normalized()
			if nrm.dot(xf.basis * Vector3.UP) < 0.0:
				nrm = -nrm
			b.n[i] = (nrm + xf.basis * Vector3.UP).normalized()
	var up := xf.basis * Vector3.UP
	for k in lados:
		b.tri(inicio, inicio + 1 + k, inicio + 1 + (k + 1) % lados, up)
	for a in range(1, aneis.size() - 1):
		for k in lados:
			var i0 := inicio + 1 + (a - 1) * lados + k
			var i1 := inicio + 1 + (a - 1) * lados + (k + 1) % lados
			b.quad(i0, i1, i1 + lados, i0 + lados, up)
	# Graos de perlita soltos por cima: tetraedros brancos.
	var rng := _rng(semente, 8)
	var r_p := _r(R_PLASTICO)
	for k in 7:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 0.18
		var c := Vector3(cos(a) * d, TERRA_Y + 0.006 * (1.0 - d / 0.213) + 0.002, sin(a) * d)
		var t := rng.randf_range(0.004, 0.007)
		var giro := Basis(Vector3.UP, rng.randf() * TAU)
		var pontos: Array[Vector3] = [Vector3(0, t, 0), Vector3(t, -t * 0.3, 0),
			Vector3(-t * 0.5, -t * 0.3, t * 0.85), Vector3(-t * 0.5, -t * 0.3, -t * 0.85)]
		var idx: Array[int] = []
		for p: Vector3 in pontos:
			idx.append(b.vert(xf * (c + giro * p), xf.basis * (giro * p).normalized(),
				_uv(r_p, 0.5 + p.x / t * 0.4, 0.5 + p.z / t * 0.4), Color(0.96, 0.96, 0.94)))
		for f3: Array in [[0, 1, 2], [0, 2, 3], [0, 3, 1]]:
			var ia: int = idx[f3[0]]
			var ib: int = idx[f3[1]]
			var ic: int = idx[f3[2]]
			var cen := (b.v[ia] + b.v[ib] + b.v[ic]) / 3.0 - xf * c
			b.tri(ia, ib, ic, cen)


## Onde a planta nasce num vaso com o pe em `base`.
static func boca(base: Vector3) -> Vector3:
	return base + Vector3(0.0, TERRA_Y, 0.0)


# --- a estaca -----------------------------------------------------------------

## O vaso semeado: palito de madeira espetado na terra com o envelope da semente
## grampeado na ponta, que e como quem planta marca o que plantou. Sem ela o vaso
## semeado e igual ao vaso so com terra — e essa diferenca e metade do que o
## ciclo tem a mostrar. `terra` e o ponto da superficie da terra no meio do vaso.
static func estaca(sup: Dictionary, terra: Vector3, semente: int) -> void:
	var obra := {}
	var b := _balde(obra, MAT)
	var rng := _rng(semente, 21)
	var giro := rng.randf() * TAU
	var tomba := Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.12))
	var pe := terra + Vector3(rng.randf_range(-0.05, 0.05), -0.04, rng.randf_range(0.03, 0.08))
	var xf := Transform3D(tomba, pe)
	_caixa(b, xf * Transform3D(Basis(), Vector3(0.0, 0.12, 0.0)), Vector3(0.012, 0.24, 0.006),
		_r(R_MADEIRA), Color(0.95, 0.86, 0.7))
	# O envelope, de pe, grampeado na frente do palito.
	var env: Rect2i = R_ENVELOPES[rng.randi() % R_ENVELOPES.size()]
	_placa(b, xf * Transform3D(Basis(Vector3.FORWARD, rng.randf_range(-0.1, 0.1)),
		Vector3(0.0, 0.2, 0.0045)), Vector2(0.06, 0.09), _r(env), Color.WHITE, true,
		Color(0.9, 0.88, 0.82))
	# Duas sementes esquecidas na terra, do lado do palito.
	var r_sem := _r(R_SEMENTE)
	for k in 2:
		var c := terra + Vector3(rng.randf_range(-0.09, 0.09), 0.004, rng.randf_range(-0.09, 0.02))
		_placa(b, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.FORWARD, rng.randf() * TAU), c),
			Vector2(0.007, 0.005), r_sem, Color.WHITE)
	_despejar(sup, obra)


# --- o pote -------------------------------------------------------------------

## Pote de vidro de erva, com a base em `onde`. `cheio` 0..1 enche de botoes
## secos ate a altura do ombro; zero e o pote vazio e limpo.
##
## Vidro por dentro e por fora (a parede de tras aparece pelo lado de dentro, e
## e o par de paredes que faz o vidro ler como vidro), fundo grosso, ombro, rosca
## a mostra entre o ombro e a tampa, tampa preta serrilhada e o rotulo de papel
## na frente (+Z girado por `giro`). O rotulo tem verso branco, que aparece pelo
## vidro quando o pote e visto de tras.
static func pote(sup: Dictionary, onde: Vector3, cheio: float, giro: float = 0.0) -> void:
	var obra := {}
	var bv := _balde(obra, MAT_VIDRO)
	var b := _balde(obra, MAT)
	var xf := Transform3D(Basis(Vector3.UP, giro), onde)
	var sid := _semente_de(onde)
	var lados := 14
	var vazio := Rect2()

	# O que tem dentro vem antes do vidro so por clareza; e o vidro que precisa
	# de ordem (dentro antes de fora), e ele esta todo no mesmo balde.
	var q := clampf(cheio, 0.0, 1.0)
	if q > 0.02:
		_erva_no_pote(b, xf, q, sid)

	var fundo_grosso := Color(COR_VIDRO.r * 0.92, COR_VIDRO.g, COR_VIDRO.b * 0.94, 0.9)
	var dentro := PackedVector2Array([Vector2(0.0495, 0.008), Vector2(0.0515, 0.013),
		Vector2(0.0515, 0.117), Vector2(0.0485, 0.129), Vector2(0.042, 0.137),
		Vector2(0.038, 0.141), Vector2(0.038, 0.149)])
	var cores_d := PackedColorArray()
	for p: Vector2 in dentro:
		cores_d.append(fundo_grosso if p.y < 0.012 else COR_VIDRO)
	_revolucao(bv, xf, dentro, lados, vazio, 0.0, 1.0, COR_VIDRO, true, 2.0, 0.0, 0, cores_d)
	_disco(bv, xf, 0.008, 0.0495, lados, vazio, fundo_grosso, true)
	_disco(bv, xf, 0.0, 0.047, lados, vazio, fundo_grosso, false)
	var fora := PackedVector2Array([Vector2(0.047, 0.0), Vector2(0.0532, 0.003),
		Vector2(0.055, 0.011), Vector2(0.055, 0.118), Vector2(0.0522, 0.1305),
		Vector2(0.0462, 0.138), Vector2(0.0412, 0.1415), Vector2(0.041, 0.1445),
		Vector2(0.0428, 0.1462), Vector2(0.0428, 0.1476), Vector2(0.041, 0.149)])
	var cores_f := PackedColorArray()
	for p: Vector2 in fora:
		cores_f.append(fundo_grosso if p.y < 0.012 else (COR_VIDRO if p.y < 0.14 else
			Color(COR_VIDRO.r, COR_VIDRO.g, COR_VIDRO.b, 0.8)))
	_revolucao(bv, xf, fora, lados, vazio, 0.0, 1.0, COR_VIDRO, false, 2.0, 0.0, 0, cores_f)

	# A tampa. Preta na maioria; uma em cada tres e dourada, de metal.
	var metal := _h(sid, 5) < 0.33
	var r_lado := _r(R_METAL) if metal else _r(R_SERRILHA)
	var r_topo := _r(R_METAL) if metal else _r(R_TAMPA)
	var cor_t := Color(1.0, 0.82, 0.46) if metal else Color(1, 1, 1)
	var tampa := PackedVector2Array([Vector2(0.0405, 0.1482), Vector2(0.0462, 0.1482),
		Vector2(0.0466, 0.1500), Vector2(0.0466, 0.1685), Vector2(0.0458, 0.1712),
		Vector2(0.0440, 0.1722)])
	_revolucao(b, xf, tampa, lados, r_lado, 1.0, 0.0, cor_t, false, 6.0)
	_disco(b, xf, 0.1722, 0.044, lados, r_topo, cor_t, true)

	# O rotulo: tira curva colada no costado, virada para a frente.
	var r_rot := _r(R_ROTULOS[int(_h(sid, 9) * 4.0) % 4])
	var a0 := PI * 0.5 - 0.95
	var a1 := PI * 0.5 + 0.95
	var cols := 7
	var y0 := 0.042
	var y1 := 0.104
	for face in 2:
		var rr := 0.0558 if face == 0 else 0.0556
		var inicio := b.v.size()
		for k in cols + 1:
			var s := float(k) / float(cols)
			var a := lerpf(a0, a1, s)
			var rad := Vector3(cos(a), 0.0, sin(a))
			var nrm := (xf.basis * (rad if face == 0 else -rad)).normalized()
			var uv_a := _uv(r_rot, 1.0 - s, 1.0) if face == 0 else _uv(_r(R_PLASTICO), s, 1.0)
			var uv_b := _uv(r_rot, 1.0 - s, 0.0) if face == 0 else _uv(_r(R_PLASTICO), s, 0.0)
			var cr := Color.WHITE if face == 0 else Color(0.9, 0.88, 0.82)
			b.vert(xf * (rad * rr + Vector3(0, y0, 0)), nrm, uv_a, cr)
			b.vert(xf * (rad * rr + Vector3(0, y1, 0)), nrm, uv_b, cr)
		for k in cols:
			var i0 := inicio + k * 2
			var a := lerpf(a0, a1, (float(k) + 0.5) / float(cols))
			var rad := Vector3(cos(a), 0.0, sin(a))
			b.quad(i0, i0 + 2, i0 + 3, i0 + 1, xf.basis * (rad if face == 0 else -rad))
	_despejar(sup, obra)


## Os botoes secos dentro do pote: camadas de quatro em volta, e o de cima
## empilhado no meio. O de baixo do centro nao existe: ninguem o ve.
static func _erva_no_pote(b: Balde, xf: Transform3D, q: float, sid: int) -> void:
	var rng := _rng(sid, 11)
	var h_max := 0.112
	var alto := 0.009 + q * h_max
	var camada := 0.024
	var y := 0.009 + 0.012
	var cor := COR_SECA
	while y - 0.008 < alto:
		var ultima := y + camada * 0.6 > alto
		var qtd := 4
		var a0 := rng.randf() * TAU
		for k in qtd:
			var a := a0 + TAU * float(k) / float(qtd) + rng.randf_range(-0.3, 0.3)
			var d := rng.randf_range(0.02, 0.025)
			var raio := rng.randf_range(0.02, 0.0245)
			var ry := rng.randf_range(0.013, 0.017)
			var cy := y + rng.randf_range(-0.003, 0.003)
			if ultima:
				ry = minf(ry, maxf(0.006, alto - cy + 0.004))
			var c := Vector3(cos(a) * d, cy, sin(a) * d)
			var giro := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.4))
			_botao(b, xf * c, Vector3(raio, ry, raio), xf.basis * giro, 6, 3, rng,
				cor * rng.randf_range(0.9, 1.06))
		if ultima:
			var c2 := Vector3(rng.randf_range(-0.005, 0.005), minf(y + 0.006, alto - 0.004), 0.0)
			_botao(b, xf * c2, Vector3(0.022, 0.014, 0.02), xf.basis, 6, 3, rng, cor)
			break
		y += camada


# --- o regador ----------------------------------------------------------------

## Regador de plastico verde. Origem no centro do fundo; o bico aponta para +X
## local e a alca faz arco no plano XY — de perfil (olhando de +Z ou -Z) ele
## aparece inteiro, que e como fica pendurado no gancho.
static func regador(sup: Dictionary, xform: Transform3D) -> void:
	var obra := {}
	var b := _balde(obra, MAT)
	var r := _r(R_PLASTICO)
	var cor := COR_REGADOR
	var corpo := PackedVector2Array([Vector2(0.082, 0.0), Vector2(0.092, 0.008),
		Vector2(0.097, 0.03), Vector2(0.098, 0.165), Vector2(0.094, 0.198),
		Vector2(0.082, 0.222), Vector2(0.064, 0.236), Vector2(0.058, 0.242),
		Vector2(0.053, 0.244), Vector2(0.05, 0.236), Vector2(0.05, 0.215)])
	var cores := PackedColorArray()
	for p: Vector2 in corpo:
		cores.append(cor if p.x > 0.051 or p.y > 0.24 else cor * 0.45)
	_revolucao(b, xform, corpo, 16, r, 1.0, 0.0, cor, false, 2.0, 0.0, 0, cores)
	_disco(b, xform, 0.0, 0.082, 16, r, cor * 0.8, false)
	# A agua la dentro, escura, para a boca nao ser um buraco para o nada.
	_disco(b, xform, 0.215, 0.05, 12, r, Color(0.16, 0.2, 0.22), true)
	# O bico: sai do pe do corpo e sobe em diagonal.
	var bico := PackedVector3Array([Vector3(0.07, 0.04, 0.0), Vector3(0.15, 0.085, 0.0),
		Vector3(0.26, 0.165, 0.0), Vector3(0.36, 0.245, 0.0)])
	_tubo(b, _pts(xform, bico), PackedFloat32Array([0.019, 0.015, 0.012, 0.011]), 8, r, cor)
	# O crivo: cone que abre e a cara furada.
	var fim := Vector3(0.36, 0.245, 0.0)
	var dir := (fim - Vector3(0.26, 0.165, 0.0)).normalized()
	var cara := fim + dir * 0.034
	_tubo(b, _pts(xform, PackedVector3Array([fim - dir * 0.004, fim + dir * 0.02, cara])),
		PackedFloat32Array([0.011, 0.022, 0.032]), 12, r, cor * 0.95)
	var eixo_y := xform.basis * dir
	var lat := eixo_y.cross(xform.basis * Vector3.FORWARD).normalized()
	var frente := lat.cross(eixo_y).normalized()
	var xf_cara := Transform3D(Basis(lat, eixo_y, frente), xform * cara)
	_disco(b, xf_cara, 0.0, 0.032, 12, _r(R_CRIVO), Color(0.95, 0.95, 0.92), true)
	# A alca: arco de cima, da frente da boca ate as costas.
	var alca := PackedVector3Array()
	for k in 9:
		var s := float(k) / 8.0
		var a := lerpf(-0.3, PI + 0.62, s)
		alca.append(Vector3(-0.02 + cos(a) * 0.088, 0.212 + sin(a) * 0.11, 0.0))
	var raios := PackedFloat32Array()
	for k in 9:
		raios.append(0.0105)
	_tubo(b, _pts(xform, alca), raios, 6, r, cor)
	_despejar(sup, obra)


static func _pts(xf: Transform3D, pts: PackedVector3Array) -> PackedVector3Array:
	var saida := PackedVector3Array()
	for p: Vector3 in pts:
		saida.append(xf * p)
	return saida


# --- as sementes --------------------------------------------------------------

## Estojo de sementes aberto sobre um tampo, com a base em `onde`: caixa de
## madeira, a tampa aberta mostrando o impresso de dentro, quatro envelopes de pe
## no fundo e sementes soltas na frente (algumas escaparam para o tampo).
static func caixa_sementes(sup: Dictionary, onde: Vector3, giro: float) -> void:
	var obra := {}
	var b := _balde(obra, MAT)
	var xf := Transform3D(Basis(Vector3.UP, giro), onde)
	var r_m := _r(R_MADEIRA)
	var cor := Color(1, 1, 1)
	var w := 0.22
	var d := 0.15
	var h := 0.055
	var e := 0.007
	# Por fora: quatro lados.
	for lado in 4:
		var ang := PI * 0.5 * float(lado)
		var larg := w if lado % 2 == 0 else d
		var prof := d if lado % 2 == 0 else w
		_placa(b, xf * Transform3D(Basis(Vector3.UP, ang), Basis(Vector3.UP, ang) * Vector3(0, h * 0.5, prof * 0.5)),
			Vector2(larg, h), r_m, cor)
		# Por dentro, mais escuro.
		_placa(b, xf * Transform3D(Basis(Vector3.UP, ang + PI), Basis(Vector3.UP, ang) * Vector3(0, h * 0.5 + e * 0.5, prof * 0.5 - e)),
			Vector2(larg - e * 2.0, h - e), r_m, cor * 0.72)
		# O topo da parede.
		_placa(b, xf * Transform3D(Basis(Vector3.UP, ang) * Basis(Vector3.RIGHT, -PI * 0.5),
			Basis(Vector3.UP, ang) * Vector3(0, h, prof * 0.5 - e * 0.5)), Vector2(larg, e), r_m, cor * 1.05)
	# O fundo de dentro.
	_placa(b, xf * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, e, 0)),
		Vector2(w - e * 2.0, d - e * 2.0), r_m, cor * 0.6)
	# A tampa, presa na aresta de tras e aberta 105 graus.
	var dobra := Vector3(0, h, -d * 0.5)
	var abre := Basis(Vector3.RIGHT, deg_to_rad(-105.0))
	var centro_t := dobra + abre * Vector3(0, 0, d * 0.5)
	# `abre` leva o +Y da tampa fechada para tras e para cima; a face de dentro
	# (que fechada olhava para baixo) passa a olhar para a frente.
	_placa(b, xf * Transform3D(abre * Basis(Vector3.RIGHT, PI * 0.5), centro_t - abre * Vector3(0, e * 0.5, 0)),
		Vector2(w, d), _r(R_CAIXA_DENTRO), cor)
	_placa(b, xf * Transform3D(abre * Basis(Vector3.RIGHT, -PI * 0.5), centro_t + abre * Vector3(0, e * 0.5, 0)),
		Vector2(w, d), r_m, cor)
	for lado in 2:
		var sx := -1.0 if lado == 0 else 1.0
		_placa(b, xf * Transform3D(abre * Basis(Vector3.UP, sx * PI * 0.5), centro_t + abre * Vector3(sx * w * 0.5, 0, 0)),
			Vector2(d, e), r_m, cor)
	# Os envelopes, de pe na metade de tras, um pouco inclinados.
	var rng := _rng(_semente_de(onde), 21)
	for k in 4:
		var x := -0.075 + 0.05 * float(k) + rng.randf_range(-0.004, 0.004)
		var alt := rng.randf_range(0.07, 0.082)
		var inclina := Basis(Vector3.RIGHT, rng.randf_range(-0.28, -0.12)) * Basis(Vector3.FORWARD, rng.randf_range(-0.06, 0.06))
		var pe := Vector3(x, e, -0.035 + rng.randf_range(-0.004, 0.004))
		_placa(b, xf * Transform3D(inclina, pe + inclina * Vector3(0, alt * 0.5, 0)), Vector2(0.046, alt),
			_r(R_ENVELOPES[k]), Color.WHITE, true, Color(0.9, 0.88, 0.8))
	# As sementes: na frente da caixa e umas no tampo.
	for k in 22:
		var p := Vector3(rng.randf_range(-0.09, 0.09), e + 0.0018, rng.randf_range(0.0, 0.058))
		_semente(b, xf * p, rng)
	for k in 5:
		var p := Vector3(rng.randf_range(-0.05, 0.12), 0.0018, rng.randf_range(0.085, 0.13))
		_semente(b, xf * p, rng)
	_despejar(sup, obra)


## Uma semente: octaedro de 4,5 x 3 x 3 mm com a casca rajada.
static func _semente(b: Balde, c: Vector3, rng: RandomNumberGenerator) -> void:
	var r := _r(R_SEMENTE)
	var base := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
	var ex := Vector3(0.0024, 0, 0)
	var ey := Vector3(0, 0.0016, 0)
	var ez := Vector3(0, 0, 0.0017)
	var eixos: Array[Vector3] = [ex, -ex, ey, -ey, ez, -ez]
	var uvs: Array[Vector2] = [Vector2(0.0, 0.5), Vector2(1.0, 0.5), Vector2(0.5, 0.0),
		Vector2(0.5, 1.0), Vector2(0.25, 0.5), Vector2(0.75, 0.5)]
	var cor := Color(1, 1, 1) * rng.randf_range(0.8, 1.1)
	cor.a = 1.0
	var idx: Array[int] = []
	for k in 6:
		var p: Vector3 = base * eixos[k]
		idx.append(b.vert(c + p, p.normalized(), _uv(r, uvs[k].x, uvs[k].y), cor))
	for sx in [0, 1]:
		for sy in [2, 3]:
			for sz in [4, 5]:
				var a: int = idx[sx]
				var bb: int = idx[sy]
				var cc: int = idx[sz]
				b.tri(a, bb, cc, (b.v[a] + b.v[bb] + b.v[cc]) / 3.0 - c)


# --- o saco de terra ------------------------------------------------------------

## Saco de substrato deitado, com o pe em `onde`: almofada de plastico preto com
## o impresso por cima, as duas pontas soldadas achatadas e a superficie
## amassada. O comprido corre no Z local (girado por `giro`), 0,52 x 0,76 m e
## 0,2 de alto — a mesma pegada da colisao da estufa. `aberto` corta a ponta +Z:
## a aba de plastico dobra para tras e aparece a terra na boca.
static func saco_terra(sup: Dictionary, onde: Vector3, giro: float, aberto: bool) -> void:
	var obra := {}
	var b := _balde(obra, MAT)
	var xf := Transform3D(Basis(Vector3.UP, giro), onde)
	var sid := _semente_de(onde)
	var largura := 0.52
	var comp := 0.72
	var alto := 0.2
	var meio := alto * 0.3
	var nu := 7
	var nv := 9
	var corte := 0.8 if aberto else 2.0
	var r_rot := _r(R_ROTULO_TERRA)
	var r_saco := _r(R_SACO)
	var cor := Color(1, 1, 1)
	# A forma: lente de almofada. Em cima estufa, embaixo apoia no chao, e as
	# duas se encontram na costura em `meio`.
	var topo := func(u: float, v: float) -> Vector3:
		var s := pow(maxf(sin(PI * u), 0.0), 0.5) * pow(maxf(sin(PI * v), 0.0), 0.3)
		var y := meio + (alto - meio) * s + (_h(sid, roundi(u * 40.0), roundi(v * 40.0)) - 0.5) * 0.03 * s
		var x := (u - 0.5) * largura * (1.0 + 0.04 * s)
		return Vector3(x, y, (v - 0.5) * comp)
	var fundo := func(u: float, v: float) -> Vector3:
		var s := pow(maxf(sin(PI * u), 0.0), 0.5) * pow(maxf(sin(PI * v), 0.0), 0.3)
		return Vector3((u - 0.5) * largura * (1.0 + 0.04 * s), meio * (1.0 - pow(s, 0.3)), (v - 0.5) * comp)
	_grade(b, xf, topo, nu, nv, 0.0, minf(corte, 1.0), r_rot, cor, true)
	_grade(b, xf, fundo, nu, nv, 0.0, 1.0, r_saco, cor * 0.8, false)
	# As soldas das pontas: faixa achatada de 3 cm.
	for ponta in 2:
		if ponta == 1 and aberto:
			continue
		var z := (-0.5 if ponta == 0 else 0.5) * comp
		var sz := -1.0 if ponta == 0 else 1.0
		var solda := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, meio, z + sz * 0.015))
		_placa(b, xf * solda, Vector2(largura * 0.97, 0.03), r_saco, cor * 0.9, true, cor * 0.7)
	if aberto:
		# A aba: o plastico de cima da ponta cortada, dobrado para tras por cima
		# do proprio saco.
		var aba := func(u: float, v: float) -> Vector3:
			var p: Vector3 = topo.call(u, corte)
			var t := (v - corte) / (1.0 - corte)
			return p + Vector3(0.0, 0.01 + 0.02 * sin(PI * t), -t * comp * (1.0 - corte) * 0.9)
		_grade(b, xf, aba, nu, 3, corte, 1.0, r_saco, cor * 0.75, true)
		# A terra na boca, em monte.
		var monte := func(u: float, v: float) -> Vector3:
			var p: Vector3 = topo.call(lerpf(0.06, 0.94, u), corte)
			var t := (v - corte) / (1.0 - corte)
			var y := lerpf(p.y - 0.006, meio + 0.01, t * t) + 0.012 * sin(PI * u) * (1.0 - t)
			return Vector3(p.x * (1.0 - 0.1 * t), y, (lerpf(corte, 0.985, t) - 0.5) * comp)
		_grade(b, xf, monte, 6, 4, corte, 1.0, _r(R_TERRA), Color(0.92, 0.9, 0.88), true)
	_despejar(sup, obra)


## Superficie parametrica em grade (u 0..1, v de v0 a v1), com normal pela
## vizinhanca e a UV da grade inteira no retangulo `r`.
static func _grade(b: Balde, xf: Transform3D, f: Callable, nu: int, nv: int,
		v0: float, v1: float, r: Rect2, cor: Color, cima: bool) -> void:
	var inicio := b.v.size()
	var pos: Array[Vector3] = []
	for j in nv + 1:
		for k in nu + 1:
			pos.append(f.call(float(k) / float(nu), lerpf(v0, v1, float(j) / float(nv))))
	var sinal := 1.0 if cima else -1.0
	for j in nv + 1:
		for k in nu + 1:
			var pu: Vector3 = pos[j * (nu + 1) + mini(k + 1, nu)] - pos[j * (nu + 1) + maxi(k - 1, 0)]
			var pv: Vector3 = pos[mini(j + 1, nv) * (nu + 1) + k] - pos[maxi(j - 1, 0) * (nu + 1) + k]
			var nrm := pv.cross(pu).normalized()
			if nrm.y * sinal < 0.0:
				nrm = -nrm
			if nrm.length_squared() < 0.5:
				nrm = Vector3.UP * sinal
			b.vert(xf * pos[j * (nu + 1) + k], (xf.basis * nrm).normalized(),
				_uv(r, float(k) / float(nu), float(j) / float(nv)), cor)
	for j in nv:
		for k in nu:
			var i0 := inicio + j * (nu + 1) + k
			var i1 := i0 + nu + 1
			b.quad(i0, i0 + 1, i1 + 1, i1, b.n[i0] + b.n[i0 + 1] + b.n[i1] + b.n[i1 + 1])


# --- o tanque -----------------------------------------------------------------

## Contorno de retangulo de cantos redondos, no plano XZ.
static func _contorno(meia: Vector2, raio: float, por_canto: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var centros: Array[Vector2] = [Vector2(meia.x - raio, meia.y - raio), Vector2(-meia.x + raio, meia.y - raio),
		Vector2(-meia.x + raio, -meia.y + raio), Vector2(meia.x - raio, -meia.y + raio)]
	for c in 4:
		for k in por_canto:
			var a := PI * 0.5 * float(c) + PI * 0.5 * float(k) / float(por_canto - 1)
			pts.append(centros[c] + Vector2(cos(a), sin(a)) * raio)
	return pts


## Prisma de contorno arredondado, em aneis (y, escala do contorno).
static func _prisma(b: Balde, xf: Transform3D, contorno: PackedVector2Array,
		aneis: PackedVector2Array, r: Rect2, cor: Color, rep: float = 2.0,
		tampa: bool = true, r_tampa: Rect2 = Rect2()) -> void:
	var n := contorno.size()
	var per := PackedFloat32Array()
	per.resize(n + 1)
	var total := 0.0
	for k in n + 1:
		if k > 0:
			total += contorno[k % n].distance_to(contorno[k - 1])
		per[k] = total
	var normais := PackedVector2Array()
	for k in n:
		var t := contorno[(k + 1) % n] - contorno[(k + n - 1) % n]
		normais.append(Vector2(t.y, -t.x).normalized())
	var altura := aneis[aneis.size() - 1].x - aneis[0].x
	var inicio := b.v.size()
	for k in n + 1:
		var p := contorno[k % n]
		var nn := normais[k % n]
		for a in aneis.size():
			var an := aneis[a]
			var ant := aneis[maxi(a - 1, 0)]
			var prox := aneis[mini(a + 1, aneis.size() - 1)]
			var inclina := -(prox.y - ant.y) * 0.3 / maxf(prox.x - ant.x, 0.001)
			var nrm := Vector3(nn.x, clampf(inclina, -2.0, 2.0), nn.y).normalized()
			b.vert(xf * Vector3(p.x * an.y, an.x, p.y * an.y), (xf.basis * nrm).normalized(),
				_uv(r, _onda(per[k] / total * rep), 1.0 - (an.x - aneis[0].x) / altura), cor)
	var m := aneis.size()
	for k in n:
		for a in m - 1:
			var i0 := inicio + k * m + a
			var i1 := inicio + (k + 1) * m + a
			b.quad(i0, i1, i1 + 1, i0 + 1, b.n[i0] + b.n[i1] + b.n[i0 + 1] + b.n[i1 + 1])
	if tampa:
		var ult := aneis[m - 1]
		var up := (xf.basis * Vector3.UP).normalized()
		var rt := r if r_tampa.size == Vector2.ZERO else r_tampa
		var ext := Vector2(0.001, 0.001)
		for p: Vector2 in contorno:
			ext = Vector2(maxf(ext.x, absf(p.x)), maxf(ext.y, absf(p.y)))
		var c0 := b.vert(xf * Vector3(0, ult.x, 0), up, _uv(rt, 0.5, 0.5), cor)
		for k in n:
			var p := contorno[k] * ult.y
			b.vert(xf * Vector3(p.x, ult.x, p.y), up,
				_uv(rt, 0.5 + p.x / ext.x * 0.5, 0.5 + p.y / ext.y * 0.5), cor)
		for k in n:
			b.tri(c0, c0 + 1 + k, c0 + 1 + (k + 1) % n, up)


## Reservatorio de agua: bombona azul de cantos redondos, com dois frisos, a
## tampa de rosca, a bomba em cima e a torneira na face -X (a que olha para o
## corredor na estufa). Pegada 0,72 x 0,86 m e 1,0 m de alto, a mesma da
## colisao; a bomba passa um pouco por cima. `onde` e o centro do pe.
static func tanque(sup: Dictionary, onde: Vector3) -> void:
	var obra := {}
	var b := _balde(obra, MAT)
	var xf := Transform3D(Basis(), onde)
	var r_p := _r(R_PLASTICO)
	var cont := _contorno(Vector2(0.36, 0.43), 0.11, 4)
	var aneis := PackedVector2Array([Vector2(0.0, 0.95), Vector2(0.025, 1.0), Vector2(0.3, 1.0),
		Vector2(0.312, 1.014), Vector2(0.338, 1.014), Vector2(0.35, 1.0), Vector2(0.62, 1.0),
		Vector2(0.632, 1.014), Vector2(0.658, 1.014), Vector2(0.67, 1.0), Vector2(0.94, 1.0),
		Vector2(0.98, 0.95), Vector2(1.0, 0.86)])
	_prisma(b, xf, cont, aneis, r_p, COR_TANQUE, 4.0, true)
	# A tampa de rosca, branca, atras da bomba.
	var xf_t := xf * Transform3D(Basis(), Vector3(-0.1, 1.0, -0.16))
	_revolucao(b, xf_t, PackedVector2Array([Vector2(0.075, -0.005), Vector2(0.075, 0.03),
		Vector2(0.07, 0.036)]), 12, _r(R_PLASTICO), 0.0, 1.0, Color(0.9, 0.9, 0.88), false, 6.0)
	_disco(b, xf_t, 0.036, 0.07, 12, r_p, Color(0.92, 0.92, 0.9), true)
	# A bomba: caixa cinza e o motor deitado.
	var r_m := _r(R_METAL)
	_caixa(b, xf * Transform3D(Basis(), Vector3(0.1, 1.05, 0.12)), Vector3(0.2, 0.1, 0.15), r_m, Color(0.55, 0.57, 0.6))
	_tubo(b, PackedVector3Array([onde + Vector3(0.0, 1.06, 0.12), onde + Vector3(-0.15, 1.06, 0.12)]),
		PackedFloat32Array([0.048, 0.048]), 10, r_m, Color(0.3, 0.32, 0.34), true)
	# A saida da bomba, que vira a mangueira para a parede leste.
	var preto := Color(0.2, 0.2, 0.22)
	_tubo(b, PackedVector3Array([onde + Vector3(0.18, 1.08, 0.12), onde + Vector3(0.26, 1.12, 0.12),
		onde + Vector3(0.36, 1.08, 0.08), onde + Vector3(0.42, 1.05, 0.02)]),
		PackedFloat32Array([0.016, 0.016, 0.016, 0.016]), 6, _r(R_SACO), preto)
	# A torneira, na face -X a 0,62 m, com a alavanca vermelha.
	var lata := Color(1.0, 0.78, 0.4)
	_tubo(b, PackedVector3Array([onde + Vector3(-0.34, 0.62, 0.3), onde + Vector3(-0.42, 0.62, 0.3),
		onde + Vector3(-0.44, 0.605, 0.3), onde + Vector3(-0.445, 0.56, 0.3)]),
		PackedFloat32Array([0.018, 0.015, 0.014, 0.013]), 8, r_m, lata)
	_caixa(b, xf * Transform3D(Basis(), Vector3(-0.4, 0.645, 0.3)), Vector3(0.014, 0.022, 0.07), r_p,
		Color(0.8, 0.16, 0.12))
	# O adesivo de "agua", na mesma face.
	_placa(b, xf * Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-0.3612, 0.8, -0.05)),
		Vector2(0.2, 0.2), _r(R_TANQUE), Color.WHITE)
	_despejar(sup, obra)


# --- a balanca ------------------------------------------------------------------

## Balanca digital de bancada, com o pe em `onde`: corpo preto de cantos
## redondos, prato de inox, visor aceso marcando 28,4 g, os dois botoes, e um
## punhado de erva seca no prato. O visor fica na frente (+Z girado por `giro`).
static func balanca(sup: Dictionary, onde: Vector3, giro: float) -> void:
	var obra := {}
	var b := _balde(obra, MAT)
	var xf := Transform3D(Basis(Vector3.UP, giro), onde)
	var r_p := _r(R_PLASTICO)
	var corpo := Color(0.2, 0.2, 0.22)
	var cont := _contorno(Vector2(0.1, 0.08), 0.016, 4)
	_prisma(b, xf, cont, PackedVector2Array([Vector2(0.0, 0.96), Vector2(0.005, 1.0),
		Vector2(0.026, 1.0), Vector2(0.03, 0.97)]), r_p, corpo, 2.0, true)
	var topo := 0.0302
	var deitar := Basis(Vector3.RIGHT, -PI * 0.5)
	# O visor e os botoes na faixa da frente.
	_placa(b, xf * Transform3D(deitar, Vector3(-0.045, topo + 0.0004, 0.053)), Vector2(0.07, 0.033),
		_r(R_LCD), Color.WHITE)
	_placa(b, xf * Transform3D(deitar, Vector3(0.045, topo, 0.053)), Vector2(0.08, 0.04),
		_sub(_r(R_PAINEL), 0.0, 0.35, 1.0, 0.9), Color.WHITE)
	# O prato de inox.
	var r_m := _r(R_METAL)
	_caixa(b, xf * Transform3D(Basis(), Vector3(0.0, topo + 0.004, -0.02)), Vector3(0.13, 0.008, 0.1), r_m,
		Color(1.0, 1.0, 1.0))
	# O punhado.
	var rng := _rng(_semente_de(onde), 31)
	var prato := Vector3(0.0, topo + 0.008, -0.02)
	for k in 4:
		var p := prato + Vector3(rng.randf_range(-0.02, 0.02), 0.009, rng.randf_range(-0.018, 0.018))
		var raio := rng.randf_range(0.012, 0.017)
		_botao(b, xf * p, Vector3(raio, raio * 0.75, raio * 0.85),
			xf.basis * Basis(Vector3.UP, rng.randf() * TAU), 5, 2, rng, COR_SECA * rng.randf_range(0.92, 1.05))
	for k in 5:
		var p := prato + Vector3(rng.randf_range(-0.045, 0.045), 0.003, rng.randf_range(-0.035, 0.035))
		_botao(b, xf * p, Vector3(0.004, 0.003, 0.004), xf.basis, 4, 2, rng, COR_SECA * 0.9)
	_despejar(sup, obra)


# --- o saquinho -----------------------------------------------------------------

## Saquinho zip deitado no tampo, com erva dentro. `onde` e o centro no tampo; o
## fecho fica em +Z (girado por `giro`). O plastico e o vidro do kit, mais fino.
static func saquinho(sup: Dictionary, onde: Vector3, giro: float) -> void:
	var obra := {}
	var b := _balde(obra, MAT)
	var bv := _balde(obra, MAT_VIDRO)
	var xf := Transform3D(Basis(Vector3.UP, giro), onde)
	var rng := _rng(_semente_de(onde), 41)
	var largura := 0.075
	var comp := 0.1
	# A erva primeiro: dois ou tres botoes achatados pelo plastico.
	var n := 2 + int(rng.randf() * 2.0)
	for k in n:
		var p := Vector3(rng.randf_range(-0.014, 0.014), 0.007, rng.randf_range(-0.03, 0.012))
		var raio := rng.randf_range(0.013, 0.017)
		_botao(b, xf * p, Vector3(raio, 0.0065, raio * 1.2),
			xf.basis * Basis(Vector3.UP, rng.randf() * TAU), 5, 2, rng, COR_SECA * rng.randf_range(0.92, 1.05))
	var bolsa := func(u: float, v: float) -> Vector3:
		var vv := clampf(v / 0.84, 0.0, 1.0)
		var s := pow(maxf(sin(PI * u), 0.0), 0.6) * pow(maxf(sin(PI * vv), 0.0), 0.6) if v < 0.84 else 0.0
		return Vector3((u - 0.5) * largura, 0.0012 + 0.0145 * s, (v - 0.5) * comp)
	var plast := Color(0.96, 0.98, 1.0, 0.25)
	_grade(bv, xf, bolsa, 5, 6, 0.0, 1.0, Rect2(), plast, true)
	# O fecho: a tira vermelha, opaca.
	_placa(b, xf * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.0, 0.0016, comp * 0.5 - 0.009)),
		Vector2(largura * 0.98, 0.008), _r(R_ZIP), Color.WHITE)
	_despejar(sup, obra)


# --- o ramo secando -------------------------------------------------------------

## Galho pendurado de cabeca para baixo no varal, com o barbante em `topo`.
## Caule seco, galhinhos que agora apontam para baixo, colas secas nas pontas e
## as folhas murchas penduradas, amarelo-palha. `comp` e do barbante a ponta.
static func ramo_secando(sup: Dictionary, topo: Vector3, comp: float, semente: int) -> void:
	var obra := {}
	var b := _balde(obra, MAT_FOLHA)
	var rng := _rng(semente, 51)
	var r_c := _r(R_CAULE)
	var r_s := _r(R_SECO)
	var cor_c := Color(0.82, 0.76, 0.52)
	# O barbante.
	_tubo(b, PackedVector3Array([topo + Vector3(0, 0.01, 0), topo - Vector3(0, 0.04, 0)]),
		PackedFloat32Array([0.0016, 0.0016]), 3, _r(R_MADEIRA), Color(1.0, 0.95, 0.8))
	var pe := topo - Vector3(0, 0.04, 0)
	var fim := topo - Vector3(rng.randf_range(-0.02, 0.02), comp, rng.randf_range(-0.02, 0.02))
	var meio := pe.lerp(fim, 0.5) + Vector3(rng.randf_range(-0.02, 0.02), 0, rng.randf_range(-0.02, 0.02))
	_tubo(b, PackedVector3Array([pe, meio, fim]), PackedFloat32Array([0.0055, 0.0045, 0.003]), 4, r_c, cor_c)
	# A cola da ponta, que era o topo da planta.
	_cola(b, fim + Vector3(0, comp * 0.22, 0), Vector3.DOWN, comp * 0.26, 0.03, rng, COR_SECA, 3, true)
	# Os galhinhos: saem do caule e caem, com cola seca e folha murcha.
	var qtd := 3 + int(rng.randf() * 2.0)
	for k in qtd:
		var t := lerpf(0.2, 0.72, float(k) / float(maxi(qtd - 1, 1)))
		var de := pe.lerp(fim, t)
		var az := rng.randf() * TAU
		var fora := Vector3(cos(az), 0.0, sin(az))
		var cg := comp * rng.randf_range(0.2, 0.3)
		var p1 := de + (fora * 0.7 + Vector3.DOWN * 0.7).normalized() * cg * 0.5
		var p2 := p1 + (fora * 0.25 + Vector3.DOWN).normalized() * cg * 0.5
		_tubo(b, PackedVector3Array([de, p1, p2]), PackedFloat32Array([0.003, 0.0025, 0.002]), 3, r_c, cor_c)
		_cola(b, p1.lerp(p2, 0.3), Vector3.DOWN, cg * 0.45, 0.018, rng, COR_SECA, 2, true)
		# Folhas murchas: foliolos pendurados do no, quase na vertical.
		for j in 3:
			var a := az + rng.randf_range(-1.2, 1.2)
			var d := (Vector3(cos(a), 0.0, sin(a)) * 0.3 + Vector3.DOWN).normalized()
			var lat := Vector3.UP.cross(Vector3(cos(a), 0.0, sin(a))).normalized()
			var cf := COR_SECA * rng.randf_range(0.85, 1.05)
			cf.a = 1.0
			_foliolo(b, de + Vector3(cos(a), 0, sin(a)) * 0.01, d, lat, Vector3(cos(a), 0, sin(a)),
				rng.randf_range(0.06, 0.09), 0.018, 0.05, r_s, cf, _verso(cf), 0.35)
	# O alfa: o barbante preso, a ponta solta.
	for k in b.v.size():
		var cr := b.c[k]
		cr.a = clampf((topo.y - b.v[k].y) / maxf(comp, 0.1), 0.0, 1.0) * 0.5
		b.c[k] = cr
	_despejar(sup, obra)


# --- as variedades --------------------------------------------------------------
#
# Uma planta por andar do poco (Variedades.DO_ANDAR), cada uma crescendo do seu
# jeito. A regra das oito e a mesma: a forma e uma PIADA, mas a planta tem de
# continuar sendo maconha de relance — leque serrilhado, cola com pistilo e
# geada. Por isso todas usam as mesmas pecas do pe comum (`_leque`, `_cola`,
# `_botao`) e so muda o esqueleto que as segura.
#
# Cada uma e montada no proprio referencial, com a terra na origem e o +Y para
# onde ela cresce, e so no fim vai para o mundo (`_despejar_em`). A Morcega e a
# mesma conta virada de cabeca para baixo.

## As que tem forma propria. A comum e o `planta`.
const FORMAS: Array[StringName] = [&"morcega", &"bonsai", &"saca_rolha", &"girafa",
	&"pompom", &"chorona", &"gambazona", &"vagalume"]

## A Morcega: do forro ao aro da corrente, e do forro ao fundo do vaso (que,
## pendurado de boca para baixo, fica em cima).
const MORCEGA_CORRENTE := 0.16
const MORCEGA_FUNDO := 0.26
## O bonsai: o tampo do suporte e a terra da bandeja, medidos do pe.
const BONSAI_MESA := 0.62
const BONSAI_TERRA := 0.676


## O pe da variedade `v` nascendo da terra em `terra`. Ver o comentario da
## secao; `pe_direito` e do pe do recipiente ao forro do andar (a Girafa dobra
## embaixo dele, a Morcega e a Chorona medem o chao por ele).
##
## `crescimento` e `madura` como no `planta`: 0 a 0,1 e a muda, e a planta
## madura tem as colas. Deterministico, como tudo aqui.
static func variedade(sup: Dictionary, terra: Vector3, crescimento: float,
		madura: bool, semente: int, v: StringName, pe_direito: float = 2.61) -> void:
	if not FORMAS.has(v):
		planta(sup, terra, crescimento, madura, semente)
		return
	var c := clampf(crescimento, 0.0, 1.0)
	var obra := {}
	var b := _balde(obra, MAT_FOLHA)
	var giro := _rng(semente, 0).randf() * TAU
	var info := recipiente_info(v, pe_direito)
	# Da terra ao chao do andar (a Morcega pendura; a Chorona desce a cortina).
	var solo: float = (info["terra"] as Vector3).y
	var xf := Transform3D(Basis(), terra)
	if v == &"morcega":
		xf = Transform3D(Basis(Vector3.RIGHT, PI), terra)
	if c < 0.1:
		_muda_da_variedade(b, c / 0.1, semente, giro, v)
	else:
		var t := (c - 0.1) / 0.9
		match v:
			&"morcega":
				_morcega(obra, t, madura, semente, giro, minf(1.5, solo - 0.34))
			&"bonsai":
				_bonsai(obra, t, madura, semente, giro)
			&"saca_rolha":
				_saca_rolha(obra, t, madura, semente, giro)
			&"girafa":
				_girafa(obra, t, madura, semente, giro, pe_direito - solo)
			&"pompom":
				_pompom(obra, t, madura, semente, giro)
			&"chorona":
				_chorona(obra, t, madura, semente, giro, solo)
			&"gambazona":
				_gambazona(obra, t, madura, semente, giro)
			&"vagalume":
				_vagalume(obra, t, madura, semente, giro)
	_despejar_em(sup, obra, xf)


## Quantos triangulos a variedade tem nesta fase (para medida e orcamento).
static func triangulos_variedade(v: StringName, crescimento: float, madura: bool) -> int:
	var sup := {}
	variedade(sup, Vector3.ZERO, crescimento, madura, 1, v)
	var total := 0
	for m: StringName in sup:
		total += PSXMesh.dados_triangulos(sup[m])
	return total


## Como `_despejar`, levando a obra do referencial da planta para o mundo.
static func _despejar_em(sup: Dictionary, obra: Dictionary, xf: Transform3D) -> void:
	for material: StringName in obra:
		var b: Balde = obra[material]
		if b.i.is_empty():
			continue
		if not sup.has(material):
			sup[material] = PSXMesh.dados_vazios()
		PSXMesh.acumular(sup[material], b.dados(), xf)


## O mesmo alfa de vento do `_vento_da_planta`, sem escrever elemento por
## elemento no array do balde (cada escrita num PackedArray dividido copia o
## array inteiro). `fator` endurece a planta toda (o bonsai quase nao mexe).
static func _vento_local(b: Balde, inicio: int, altura: float, fator: float = 1.0) -> void:
	var vs := b.v
	var cs := b.c
	b.c = PackedColorArray()
	for k in range(inicio, vs.size()):
		var p := vs[k]
		var t := clampf(p.y / altura, 0.0, 1.0)
		var d := Vector2(p.x, p.z).length()
		var cr := cs[k]
		cr.a = clampf(t * t * 0.85 + d * 1.1 * (0.3 + t), 0.0, 1.0) * fator
		cs[k] = cr
	b.c = cs


## Alfa de vento de um pedaco pendurado: `a0` no ponto preso (`topo`) e sobe
## ate 1 a `queda` metros abaixo dele. A ponta do galho que cai e a que mais
## balanca — o contrario do pe de pe.
static func _vento_pendurado(b: Balde, inicio: int, topo_y: float, queda: float,
		a0: float) -> void:
	var vs := b.v
	var cs := b.c
	b.c = PackedColorArray()
	for k in range(inicio, vs.size()):
		var cr := cs[k]
		cr.a = clampf(a0 + (topo_y - vs[k].y) / maxf(queda, 0.05) * (1.0 - a0), a0, 1.0)
		cs[k] = cr
	b.c = cs


## O referencial de um eixo (x e z em volta dele, y nele).
static func _base_do_eixo(eixo: Vector3) -> Basis:
	var lado := eixo.cross(Vector3.RIGHT if absf(eixo.x) < 0.9 else Vector3.FORWARD).normalized()
	return Basis(lado, eixo, eixo.cross(lado))


## O tom de cada variedade na folha (multiplica a textura).
static func _verde_de(v: StringName) -> Color:
	match v:
		&"morcega":
			return Color(0.86, 0.9, 1.0)
		&"bonsai":
			return Color(0.84, 0.94, 0.78)
		&"saca_rolha":
			return Color(0.86, 1.0, 0.94)
		&"girafa":
			return Color(1.0, 1.0, 0.82)
		&"pompom":
			return Color(0.9, 1.0, 0.86)
		&"chorona":
			return Color(0.8, 0.94, 1.0)
		&"gambazona":
			return Color(1.0, 1.0, 0.8)
		&"vagalume":
			return Color(0.95, 0.9, 1.0)
	return Color.WHITE


## A muda de cada uma: a mesma do pe comum, com o tom da variedade. A Girafa ja
## nasce de pescoco (a muda estiolada, esticada), o bonsai menor, e a Vagalume
## ja roxa.
static func _muda_da_variedade(b: Balde, s: float, semente: int, giro: float,
		v: StringName) -> void:
	var r_fol := _r(R_FOLIOLO_ROXO) if v == &"vagalume" else Rect2()
	_muda(b, Vector3.ZERO, s, semente, giro, _verde_de(v), r_fol)
	var alto := 0.08
	if v == &"girafa" or v == &"bonsai":
		var vs := b.v
		b.v = PackedVector3Array()
		for k in vs.size():
			var p := vs[k]
			if v == &"girafa":
				p.y += 0.1 * smoothstep(0.0, 0.035, p.y)
			else:
				p *= 0.7
			vs[k] = p
		b.v = vs
		alto = 0.2 if v == &"girafa" else 0.06
	_vento_local(b, 0, alto)


# --- Morcega ---------------------------------------------------------------------

## O pe comum de cabeca para baixo: e o `_pe` inteiro, e quem vira e o
## `variedade`. A folha velha "cai" para o forro e a cola aponta o chao — a
## planta nao sabe que esta pendurada, e e isso que tem graca. Enxuta: o vaso
## pendurado e a corrente comem parte do orcamento.
static func _morcega(obra: Dictionary, t: float, madura: bool, semente: int,
		giro: float, alcance: float) -> void:
	var b := _balde(obra, MAT_FOLHA)
	var altura := lerpf(0.1, alcance, pow(t, 0.85)) * _rng(semente, 60).randf_range(0.94, 1.03)
	_pe(b, Vector3.ZERO, t, madura, semente, giro, _verde_de(&"morcega"), altura,
		{"enxuto": true})
	_vento_local(b, 0, altura)


# --- Bonsai ----------------------------------------------------------------------

## Arvore velha de trinta centimetros: tronco grosso e torto de casca, raizes
## a mostra agarrando a terra (nebari), tres galhos quase deitados e a copa em
## almofadas chatas de folha miuda. Florida, cada almofada espeta colinhas.
static func _bonsai(obra: Dictionary, t: float, madura: bool, semente: int,
		giro: float) -> void:
	var b := _balde(obra, MAT_FOLHA)
	var rng := _rng(semente, 70)
	var verde := _verde_de(&"bonsai")
	var r_fol := _r(R_FOLIOLO)
	var r_casca := _r(R_CASCA)
	var cor_casca := Color(1.0, 0.95, 0.9)
	var s := lerpf(0.42, 1.0, smoothstep(0.0, 0.75, t))
	var grosso := lerpf(0.4, 1.0, t)
	var alto := 0.3 * s
	var frente := Vector3(cos(giro), 0.0, sin(giro))
	var lado := Vector3(-frente.z, 0.0, frente.x)

	# O tronco: um S (moyogi), afinando rapido.
	var pts := PackedVector3Array()
	var raios := PackedFloat32Array()
	var n := 7
	for k in n:
		var f := float(k) / float(n - 1)
		var curva := sin(f * PI * 1.55 + 0.35) * 0.05 * s * (1.0 - f * 0.35)
		var torce := sin(f * PI * 2.2 + 1.1) * 0.016 * s
		var jit := Vector3(rng.randf_range(-1, 1), 0.0, rng.randf_range(-1, 1)) * 0.004 * s
		pts.append(frente * (curva - 0.02 * s) + lado * torce + Vector3(0.0, -0.012 + f * alto, 0.0) + jit)
		raios.append(lerpf(0.03, 0.007, pow(f, 0.65)) * grosso)
	raios[0] *= 1.3
	_tubo(b, pts, raios, 7, r_casca, cor_casca)
	# As raizes: saem do pe do tronco e mergulham na terra.
	var nr := 5
	for k in nr:
		var a := giro + TAU * float(k) / float(nr) + rng.randf_range(-0.35, 0.35)
		var d := Vector3(cos(a), 0.0, sin(a))
		var comp := rng.randf_range(0.05, 0.085) * s
		var r := raios[0] * 0.42
		var p0 := pts[0] + Vector3(0.0, 0.02 * s, 0.0) + d * raios[0] * 0.35
		_tubo(b, PackedVector3Array([p0, pts[0] + d * (raios[0] + comp * 0.4) + Vector3(0, 0.006, 0),
			pts[0] + d * (raios[0] + comp) + Vector3(0.0, -0.004, 0.0)]),
			PackedFloat32Array([r, r * 0.6, r * 0.2]), 4, r_casca, cor_casca * 0.92)

	# Os galhos, cada um com a sua almofada na ponta, e a do alto.
	var galhos: Array[Vector3] = [Vector3(0.36, 1.0, 0.0), Vector3(0.56, -1.0, 0.15),
		Vector3(0.74, 0.25, -1.0)]
	var n_galhos := 1 + int(t > 0.3) + int(t > 0.6)
	var almofadas: Array[Vector4] = []
	for g in n_galhos:
		var spec: Vector3 = galhos[g]
		var p := _na_linha(pts, spec.x)
		var d := (lado * spec.y + frente * spec.z).normalized()
		d = d.rotated(Vector3.UP, rng.randf_range(-0.25, 0.25))
		var comp := (0.13 - 0.025 * float(g)) * s
		var r0 := lerpf(raios[0], raios[n - 1], spec.x) * 0.55
		var fim := p + d * comp + Vector3(0.0, 0.012, 0.0)
		_tubo(b, PackedVector3Array([p, p + d * comp * 0.45 - Vector3(0, 0.012 * s, 0), fim]),
			PackedFloat32Array([r0, r0 * 0.7, r0 * 0.4]), 5, r_casca, cor_casca)
		almofadas.append(Vector4(fim.x, fim.y + 0.006, fim.z, lerpf(0.04, 0.078, t) * (1.0 - 0.1 * float(g))))
	var apice := pts[n - 1]
	almofadas.append(Vector4(apice.x, apice.y + 0.008, apice.z, lerpf(0.045, 0.07, t)))
	for k in almofadas.size():
		var a4 := almofadas[k]
		_nuvem(b, Vector3(a4.x, a4.y, a4.z), a4.w, rng, verde, r_fol, madura, t)
	_vento_local(b, 0, 0.3, 0.45)


## Uma almofada da copa do bonsai: tres aneis de leques miudos deitados, o de
## fora caindo e o de dentro mais alto, que e o que da o domo de nuvem.
static func _nuvem(b: Balde, centro: Vector3, raio: float, rng: RandomNumberGenerator,
		verde: Color, r_fol: Rect2, madura: bool, t: float) -> void:
	# O corpo da almofada: um domo achatado verde-escuro por baixo das folhas,
	# que e o que faz a copa ler como MASSA (a nuvem) e nao como estrelas soltas.
	var corpo := PackedVector2Array([Vector2(0.0, -raio * 0.2), Vector2(raio * 0.55, -raio * 0.12),
		Vector2(raio * 0.62, -raio * 0.02), Vector2(raio * 0.4, raio * 0.07), Vector2(0.0, raio * 0.1)])
	_revolucao(b, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), centro), corpo, 7,
		_sub(_r(R_CAULE), 0.1, 0.1, 0.9, 0.9), 0.0, 1.0, _lim(Color(0.09, 0.15, 0.06) * verde))
	var qtds: Array[int] = [9, 6, 3]
	var rrs: Array[float] = [0.5, 0.26, 0.04]
	var dys: Array[float] = [-0.02, 0.12, 0.2]
	var sobes: Array[float] = [-0.12, 0.12, 0.45]
	var tams: Array[float] = [0.66, 0.58, 0.46]
	for anel in 3:
		var qtd := qtds[anel]
		for k in qtd:
			var a := TAU * float(k) / float(qtd) + rng.randf_range(-0.25, 0.25) + float(anel) * 0.5
			var d := Vector3(cos(a), 0.0, sin(a))
			var p := centro + d * raio * rrs[anel] + Vector3(0.0, raio * dys[anel], 0.0)
			var fr := (d + Vector3(0.0, sobes[anel], 0.0)).normalized()
			var nrm := (Vector3.UP - fr * fr.y).normalized()
			var cor := _cor_folha(verde, 0.55 + 0.2 * float(anel), rng)
			_leque_livre(b, p, fr, nrm, 5, raio * tams[anel], 0.15, rng, cor, r_fol)
	if madura:
		for k in 2:
			var a := rng.randf() * TAU
			var d := Vector3(cos(a), 0.0, sin(a))
			var p := centro + d * raio * rng.randf_range(0.15, 0.4) + Vector3(0.0, raio * 0.1, 0.0)
			_cola(b, p, (Vector3.UP + d * 0.3).normalized(), raio * rng.randf_range(0.55, 0.7),
				0.008 + raio * 0.06, rng, verde, 2)
	elif t > 0.4:
		# Broto novo, verde-claro, no alto da almofada.
		var cor_b := _cor_folha(verde, 1.0, rng)
		_leque_livre(b, centro + Vector3(0.0, raio * 0.3, 0.0), Vector3.UP, Vector3.FORWARD,
			3, raio * 0.4, 0.0, rng, cor_b, r_fol)


# --- Saca-Rolha --------------------------------------------------------------------

## O caule e uma mola: sobe em helice de 9 cm de raio, uma volta a cada 20 cm, e
## aperta no alto. As folhas saem por FORA da volta (o leque aponta para longe
## do eixo), e florida a ponta vira uma cola enrolada seguindo a mola.
static func _saca_rolha(obra: Dictionary, t: float, madura: bool, semente: int,
		giro: float) -> void:
	var b := _balde(obra, MAT_FOLHA)
	var rng := _rng(semente, 80)
	var verde := _verde_de(&"saca_rolha")
	var r_fol := _r(R_FOLIOLO)
	var r_caule := _r(R_CAULE)
	var cor_caule := Color(0.86, 0.95, 0.74) * verde
	cor_caule.a = 1.0
	var alto := lerpf(0.1, 1.06, pow(t, 0.85))
	var raio := lerpf(0.05, 0.092, smoothstep(0.0, 0.6, t))
	var voltas := alto / 0.2
	var th_max := voltas * TAU
	var n := maxi(8, int(voltas * 10.0))
	var pts := PackedVector3Array()
	var raios := PackedFloat32Array()
	for k in n + 1:
		var f := float(k) / float(n)
		pts.append(_mola(f, alto, th_max, raio, giro))
		raios.append(lerpf(0.0105, 0.0042, f) * lerpf(0.55, 1.0, t))
	pts[0] = pts[0] - Vector3(0.0, 0.01, 0.0)
	_tubo(b, pts, raios, 5, r_caule, cor_caule)

	# Os nos: um a cada 0,3 de volta, um par de folhas abrindo para fora e um
	# broto em pe entre elas.
	var dth := 0.3 * TAU
	var nos := int(th_max / dth)
	for k in nos:
		var th := (float(k) + 0.6) * dth
		var f := th / th_max
		if f > 0.88:
			break
		var p := _mola(f, alto, th_max, raio, giro)
		var fora := Vector3(cos(giro + th), 0.0, sin(giro + th))
		var n_f := mini(_foliolos_do_no(k, nos + 1), 7)
		var forma := 0.75 + 0.35 * sin(PI * clampf(f * 1.1, 0.0, 1.0))
		var tam := lerpf(0.065, 0.165, sqrt(t)) * forma
		var cor := _cor_folha(verde, f, rng)
		for lado: float in [-1.0, 1.0]:
			_leque(b, p, fora.rotated(Vector3.UP, lado * 0.5 + rng.randf_range(-0.2, 0.2)), n_f,
				tam * (1.0 if lado > 0.0 else 0.86), tam * 0.4, lerpf(0.5, 0.12, f), rng, cor, r_fol)
		if f > 0.12:
			_leque(b, p + Vector3(0.0, 0.01, 0.0), fora, 5, tam * 0.5, 0.004, -0.3, rng,
				_cor_folha(verde, minf(f + 0.2, 1.0), rng), r_fol)
		if madura and f > 0.25 and k % 2 == 0:
			# Galhinho curto para fora, com a cola em pe na ponta.
			var p2 := p + fora * 0.075 + Vector3.UP * 0.05
			_tubo(b, PackedVector3Array([p, p + fora * 0.045 + Vector3.UP * 0.012, p2]),
				PackedFloat32Array([0.0042, 0.0036, 0.003]), 4, r_caule, cor_caule)
			_cola(b, p2 - Vector3(0.0, 0.012, 0.0), (fora * 0.3 + Vector3.UP).normalized(),
				0.075 + 0.04 * f, 0.02 + 0.006 * f, rng, verde, 2)

	# O alto: a cola enrolada, ou o broto.
	if madura:
		var linha := PackedVector3Array()
		for k in 9:
			linha.append(_mola(lerpf(0.72, 1.0, float(k) / 8.0), alto, th_max, raio, giro))
		# e passa um pouco da ponta, subindo
		var ult := linha[linha.size() - 1]
		linha.append(ult + Vector3(0.0, 0.035, 0.0))
		_cola_curva(b, linha, 0.03, rng, verde)
	else:
		var ponta := pts[pts.size() - 1]
		var cor_t := _cor_folha(verde, 1.0, rng)
		for k in 3:
			var a := giro + float(k) * TAU / 3.0
			_leque(b, ponta - Vector3(0.0, 0.01, 0.0), Vector3(cos(a), 0.0, sin(a)), 3,
				0.03 + 0.03 * t, 0.01, -0.5, rng, cor_t, r_fol)
	_vento_local(b, 0, alto)


## O ponto da mola a uma fracao `f` da altura. O raio abre do pe (que nasce no
## meio do vaso) e aperta no alto.
static func _mola(f: float, alto: float, th_max: float, raio: float, giro: float) -> Vector3:
	var y := f * alto
	var r := raio * smoothstep(0.0, 0.09, y) * (1.0 - 0.38 * smoothstep(0.8, 1.0, f))
	var th := giro + f * th_max
	return Vector3(cos(th) * r, y, sin(th) * r)


## Cola ao longo de uma linha curva: botoes seguindo a linha, afinando para a
## ponta, com acucar e o tufo de pistilo no fim.
static func _cola_curva(b: Balde, linha: PackedVector3Array, grossura: float,
		rng: RandomNumberGenerator, verde: Color) -> void:
	var total := 0.0
	for k in range(1, linha.size()):
		total += linha[k].distance_to(linha[k - 1])
	var qtd := clampi(int(total / (grossura * 1.25)) + 1, 3, 12)
	var cor := _lim(Color(1.0, 1.0, 0.92) * verde)
	var cor_acu := _lim(Color(0.95, 1.0, 0.9) * verde)
	var r_acu := _r(R_ACUCAR)
	var tg := Vector3.UP
	for k in qtd:
		var f := (float(k) + 0.5) / float(qtd)
		var p := _na_linha(linha, f)
		tg = (_na_linha(linha, minf(f + 0.05, 1.0)) - _na_linha(linha, maxf(f - 0.05, 0.0))).normalized()
		var base := _base_do_eixo(tg)
		var raio := grossura * (0.72 + 0.28 * sin(PI * (0.15 + 0.7 * f))) * (1.0 - 0.5 * pow(f, 3.0))
		_botao(b, p, Vector3(raio, raio * 1.3, raio) * rng.randf_range(0.9, 1.1),
			Basis(tg, rng.randf() * TAU) * base, 5, 3 if k == qtd - 1 else 2, rng, cor)
		if rng.randf() < 0.75:
			var a := rng.randf() * TAU
			var saida := (base.x * cos(a) + base.z * sin(a)).normalized()
			var d := (saida * 0.8 + tg * 0.6).normalized()
			_foliolo(b, p + saida * raio * 0.4, d, tg.cross(d).normalized(), tg, raio * 2.2,
				raio * 0.8, 0.15, r_acu, cor_acu, _verso(cor_acu), 0.25)
	var fim := linha[linha.size() - 1]
	var bf := _base_do_eixo(tg)
	var r_pis := _r(R_PISTILO)
	for k in 2:
		var lat := bf.x if k == 0 else bf.z
		_cartao(b, fim - tg * grossura * 0.6, tg, lat, lat.cross(tg), grossura * 1.1,
			grossura * 1.3, r_pis, Color.WHITE, Color.WHITE)


# --- Girafa --------------------------------------------------------------------------

## Pescoco fino e altissimo ate bater no forro; la dobra num cotovelo e corre
## deitada por baixo dele. As folhas so na cabeca (o ultimo trecho), e no pe dois
## foliolos secos de quando ela era baixa. O caule tem a malha da girafa, de leve.
## `teto` e da terra ao forro.
static func _girafa(obra: Dictionary, t: float, madura: bool, semente: int,
		giro: float, teto: float) -> void:
	var b := _balde(obra, MAT_FOLHA)
	var rng := _rng(semente, 90)
	var verde := _verde_de(&"girafa")
	var r_fol := _r(R_FOLIOLO)
	var yh := teto - 0.1
	var rc := 0.16
	var lv := yh - rc
	var arco := PI * 0.5 * rc
	var total := lv + arco + 0.75
	var comp := lerpf(0.12, total, pow(t, 0.75))
	var dir := Vector3(cos(giro), 0.0, sin(giro))
	var perp := Vector3(-dir.z, 0.0, dir.x)
	var fase := rng.randf() * TAU
	var geo := Vector4(lv, rc, arco, fase)

	var cor_caule := Color(0.95, 0.97, 0.72)
	var n := maxi(3, int(ceil(comp / 0.06)))
	var pts := PackedVector3Array()
	var raios := PackedFloat32Array()
	for k in n + 1:
		var s := comp * float(k) / float(n)
		pts.append(_girafa_ponto(s, geo, dir, perp))
		raios.append(lerpf(0.016, 0.007, s / total) * lerpf(0.5, 1.0, t))
	pts[0] = pts[0] - Vector3(0.0, 0.01, 0.0)
	var ini_caule := b.v.size()
	_tubo(b, pts, raios, 6, _r(R_CAULE), cor_caule)
	# A malha da girafa: manchas por vertice (anel x lado), e nao por anel, que
	# dariam listras de bambu.
	var cs := b.c
	b.c = PackedColorArray()
	var mancha := Color(0.34, 0.17, 0.06)
	for k in range(ini_caule, cs.size()):
		var j := k - ini_caule
		var anel := j / 7
		var lado := (j % 7) % 6
		if _h(semente, anel / 2 + lado * 31, (anel + lado) % 3) > 0.52 and anel % 5 != 0:
			cs[k] = cor_caule * mancha
	b.c = cs

	# Os dois foliolos secos no pe.
	if t > 0.3:
		var cor_s := Color(1.0, 0.96, 0.7)
		for lado in 2:
			var a := giro + PI * 0.5 + PI * float(lado)
			_leque(b, _girafa_ponto(0.07, geo, dir, perp), Vector3(cos(a), 0.0, sin(a)), 3,
				0.05, 0.012, 0.9, rng, cor_s, _r(R_SECO))

	# A cabeca: folhas no ultimo trecho, alternando os lados do caule.
	var cabeca := lerpf(0.16, 0.9, smoothstep(0.0, 1.0, t))
	var s0 := maxf(comp - cabeca, comp * 0.4)
	var s := comp - 0.04
	var j := 0
	while s > s0:
		var p := _girafa_ponto(s, geo, dir, perp)
		var tg := (_girafa_ponto(s + 0.02, geo, dir, perp) - _girafa_ponto(s - 0.02, geo, dir, perp)).normalized()
		var rel := 1.0 - (comp - s) / cabeca
		var fora := tg.cross(Vector3.UP)
		if fora.length() < 0.3:
			fora = perp.rotated(Vector3.UP, float(j) * 2.4)
		fora = fora.normalized() * (1.0 if j % 2 == 0 else -1.0)
		var tam := lerpf(0.08, 0.17, sqrt(t)) * lerpf(0.85, 1.05, rel)
		var cor := _cor_folha(verde, 0.55 + 0.4 * rel, rng)
		# Perto da ponta, as folhas em par: e a cabeca, mais cheia que o pescoco.
		var lados: Array[float] = [1.0]
		if rel > 0.35:
			lados.append(-1.0)
		for lf: float in lados:
			_leque(b, p, (fora * lf).rotated(Vector3.UP, rng.randf_range(-0.3, 0.3)),
				7 if rel < 0.8 else 5, tam * (1.0 if lf > 0.0 else 0.85), 0.035,
				lerpf(0.5, 0.25, rel), rng, cor, r_fol)
		if madura and j % 3 == 1:
			# Cola de lado: para cima ela bate no forro.
			var eixo := (fora * 0.8 + Vector3.UP * 0.35).normalized()
			var cc := minf(0.12, (teto - 0.035 - p.y) / maxf(eixo.y, 0.2))
			_cola(b, p + fora * 0.012, eixo, maxf(cc, 0.05), 0.027, rng, verde, 2)
		j += 1
		s -= 0.075

	# A ponta: coroa de folhas e o broto, ou a cola principal, que corre para a
	# frente embaixo do forro.
	var ponta := _girafa_ponto(comp, geo, dir, perp)
	var tg_p := (ponta - _girafa_ponto(comp - 0.03, geo, dir, perp)).normalized()
	var cor_t := _cor_folha(verde, 1.0, rng)
	for k in 6:
		var a := giro + float(k) * TAU / 6.0 + 0.4
		_leque(b, ponta, Vector3(cos(a), 0.0, sin(a)), 7 if k % 2 == 0 else 5,
			lerpf(0.06, 0.13, t), 0.02, 0.15, rng, cor_t, r_fol)
	if madura:
		var eixo_p := (tg_p + Vector3.UP * 0.25).normalized()
		var cc := 0.2
		if eixo_p.y > 0.05:
			cc = minf(cc, (teto - 0.04 - ponta.y) / eixo_p.y)
		_cola(b, ponta - tg_p * 0.03, eixo_p, maxf(cc, 0.07), 0.034, rng, verde, 3)
	else:
		for k in 3:
			var a := giro + float(k) * TAU / 3.0
			_leque(b, ponta + tg_p * 0.01, Vector3(cos(a), 0.0, sin(a)), 3, 0.035 + 0.03 * t,
				0.008, -0.5, rng, cor_t, r_fol)
	_vento_local(b, 0, maxf(yh, 0.3), 0.8)


## O ponto do pescoco da girafa a `s` metros do pe. `geo`: (trecho em pe, raio
## do cotovelo, comprimento do cotovelo, fase do balanco).
static func _girafa_ponto(s: float, geo: Vector4, dir: Vector3, perp: Vector3) -> Vector3:
	var lv := geo.x
	var rc := geo.y
	var arco := geo.z
	if s <= lv:
		var balanco := 0.028 * sin(s * 2.6 + geo.w) * smoothstep(0.0, 0.6, s) \
			* (1.0 - smoothstep(lv - 0.55, lv - 0.08, s))
		return Vector3(0.0, maxf(s, 0.0), 0.0) + perp * balanco + dir * balanco * 0.4
	var topo := Vector3(0.0, lv, 0.0)
	if s <= lv + arco:
		var ang := (s - lv) / rc
		return topo + dir * rc * (1.0 - cos(ang)) + Vector3.UP * rc * sin(ang)
	var x := s - lv - arco
	return topo + dir * (rc + x) + Vector3.UP * (rc - 0.014 * absf(sin(x * 5.5)))


# --- Pompom ----------------------------------------------------------------------------

## Topiaria: um palito reto e, na ponta, uma bola perfeita de folha — leques
## deitados na casca da esfera como escama, sobre um miolo escuro que tapa o
## vao. O laco cor-de-rosa no palito e de quem cuida. Florida, as colas espetam
## para fora da bola.
static func _pompom(obra: Dictionary, t: float, madura: bool, semente: int,
		giro: float) -> void:
	var b := _balde(obra, MAT_FOLHA)
	var rng := _rng(semente, 100)
	var verde := _verde_de(&"pompom")
	var r_fol := _r(R_FOLIOLO)
	var r_caule := _r(R_CAULE)
	var cor_caule := Color(0.8, 0.88, 0.66)
	var hs := lerpf(0.1, 0.7, pow(t, 0.8))
	var raio := lerpf(0.065, 0.25, pow(t, 0.7))
	var centro := Vector3(0.0, hs + raio * 0.9, 0.0)
	var g := lerpf(0.5, 1.0, t)
	_tubo(b, PackedVector3Array([Vector3(0.0, -0.01, 0.0), Vector3(0.003, hs * 0.5, -0.002), centro]),
		PackedFloat32Array([0.012 * g, 0.011 * g, 0.009 * g]), 5, r_caule, cor_caule)
	if t > 0.25:
		_laco(b, Vector3(0.0, hs - 0.05, 0.0), giro, lerpf(1.0, 1.6, t))
	_vento_local(b, 0, centro.y)

	var ini := b.v.size()
	# O miolo: escuro, para o vao entre as folhas nao mostrar o fundo.
	_esfera(b, centro, raio * 0.8, 8, 5, r_caule, Color(0.34, 0.46, 0.24))
	# As folhas: pontos de Fibonacci na esfera, cada leque deitado nela.
	var qtd := int(lerpf(14.0, 50.0, t))
	for k in qtd:
		var y := 1.0 - 2.0 * (float(k) + 0.5) / float(qtd)
		var rr := sqrt(maxf(0.0, 1.0 - y * y))
		var ph := float(k) * 2.39996 + giro
		var d := Vector3(cos(ph) * rr, y, sin(ph) * rr)
		if d.y < -0.93:
			continue
		var tg := Vector3.UP - d * d.y
		if tg.length() < 0.1:
			tg = Vector3.RIGHT - d * d.x
		tg = tg.normalized().rotated(d, rng.randf_range(-PI, PI))
		var p := centro + d * raio * 0.74 - tg * raio * 0.22
		var cor := _cor_folha(verde, 0.62 + 0.3 * (y * 0.5 + 0.5), rng)
		_leque_livre(b, p, (tg + d * 0.3).normalized(), d, 7 if raio > 0.12 else 5,
			raio * 0.66, 0.3, rng, cor, r_fol)
	# A franja: leques menores com a ponta para FORA da bola. E o serrilhado da
	# silhueta; sem ela a bola le como esfera pintada.
	var franja := int(float(qtd) * 0.55)
	for k in franja:
		var y := 0.97 - 1.8 * (float(k) + 0.5) / float(franja)
		var rr := sqrt(maxf(0.0, 1.0 - y * y))
		var ph := float(k) * 2.39996 + giro + 1.3
		var d := Vector3(cos(ph) * rr, y, sin(ph) * rr)
		var tg := (Vector3.UP - d * d.y)
		if tg.length() < 0.1:
			tg = Vector3.RIGHT - d * d.x
		tg = tg.normalized().rotated(d, rng.randf_range(-PI, PI))
		var cor := _cor_folha(verde, 0.75 + 0.25 * (y * 0.5 + 0.5), rng)
		_leque_livre(b, centro + d * raio * 0.86, (d * 0.75 + tg * 0.66).normalized(),
			tg.cross(d).normalized(), 5, raio * 0.42, 0.2, rng, cor, r_fol)
	if madura:
		var n_c := 11
		for k in n_c:
			var y := 0.95 - 1.5 * (float(k) + 0.5) / float(n_c)
			var rr := sqrt(maxf(0.0, 1.0 - y * y))
			var ph := float(k) * 2.39996 + giro + 0.7
			var d := Vector3(cos(ph) * rr, y, sin(ph) * rr)
			_cola(b, centro + d * raio * 0.66, d, raio * 0.52, 0.026 + raio * 0.04, rng, verde, 2)
	# A bola balanca inteira, a casca um pouco mais que o miolo.
	var vs := b.v
	var cs := b.c
	b.c = PackedColorArray()
	for k in range(ini, vs.size()):
		var cr := cs[k]
		cr.a = clampf(0.42 + 0.3 * vs[k].distance_to(centro) / raio, 0.0, 1.0)
		cs[k] = cr
	b.c = cs


## Esfera UV (o miolo do Pompom).
static func _esfera(b: Balde, centro: Vector3, raio: float, lados: int, aneis: int,
		r: Rect2, cor: Color) -> void:
	var inicio := b.v.size()
	for a in aneis + 1:
		var lat := -PI * 0.5 + PI * float(a) / float(aneis)
		for k in lados + 1:
			var ang := TAU * float(k) / float(lados)
			var d := Vector3(cos(lat) * cos(ang), sin(lat), cos(lat) * sin(ang))
			b.vert(centro + d * raio, d, _uv(r, _onda(float(k) / float(lados) * 2.0),
				float(a) / float(aneis)), cor)
	var passo := lados + 1
	for a in aneis:
		for k in lados:
			var i0 := inicio + a * passo + k
			b.quad(i0, i0 + 1, i0 + passo + 1, i0 + passo,
				b.n[i0] + b.n[i0 + 1] + b.n[i0 + passo] + b.n[i0 + passo + 1])


## Tira dupla-face seguindo `pts`, com a largura na direcao `larg_dir`: fita.
static func _tira(b: Balde, pts: PackedVector3Array, larg_dir: Vector3, larg: float,
		r: Rect2, cor: Color) -> void:
	var n := pts.size()
	for face in 2:
		var s := 1.0 if face == 0 else -1.0
		var inicio := b.v.size()
		for k in n:
			var tg := (pts[mini(k + 1, n - 1)] - pts[maxi(k - 1, 0)]).normalized()
			var nrm := tg.cross(larg_dir).normalized() * s
			var u := float(k) / float(n - 1)
			b.vert(pts[k] + larg_dir * larg * 0.5, nrm, _uv(r, u, 0.0), cor)
			b.vert(pts[k] - larg_dir * larg * 0.5, nrm, _uv(r, u, 1.0), cor)
		for k in n - 1:
			var i0 := inicio + k * 2
			b.quad(i0, i0 + 2, i0 + 3, i0 + 1, b.n[i0] + b.n[i0 + 2])


## O laco de fita no palito do Pompom: duas orelhas, duas pontas e o no.
static func _laco(b: Balde, no: Vector3, giro: float, esc: float) -> void:
	var fr := Vector3(cos(giro), 0.0, sin(giro))
	var lat := Vector3(-fr.z, 0.0, fr.x)
	var rosa := Color(1.0, 0.1, 0.32)
	var r := _r(R_PLASTICO)
	var no_f := no + fr * 0.012 * esc
	for lado: float in [-1.0, 1.0]:
		var orelha := PackedVector3Array()
		for k in 9:
			var ang := TAU * float(k) / 8.0
			orelha.append(no_f + lat * lado * (0.028 - 0.028 * cos(ang)) * esc
				+ Vector3.UP * 0.017 * sin(ang) * esc * lado + fr * 0.004 * sin(ang * 0.5) * esc)
		_tira(b, orelha, fr, 0.02 * esc, r, rosa)
		var ponta := PackedVector3Array([no_f, no_f + (lat * lado * 0.012 - Vector3.UP * 0.028) * esc,
			no_f + (lat * lado * 0.024 - Vector3.UP * 0.055) * esc])
		_tira(b, ponta, (fr + lat * lado * 0.3).normalized(), 0.016 * esc, r, rosa * 0.9)
	_caixa(b, Transform3D(Basis(Vector3.UP, -giro), no + fr * 0.004 * esc),
		Vector3(0.026, 0.018, 0.028) * esc, r, rosa * 0.85, false)


# --- Chorona -------------------------------------------------------------------------

## Salgueiro: tronco reto ate um metro, e dele saem os galhos em arco — sobem,
## abrem e caem em cortina ate quase o chao, cada fio cheio de folha pendurada
## (leque fechado, foliolo fino, virado para fora). Florida, cada fio termina
## numa cola em gota apontando o chao. `chao` e da terra ao piso.
static func _chorona(obra: Dictionary, t: float, madura: bool, semente: int,
		giro: float, chao: float) -> void:
	var b := _balde(obra, MAT_FOLHA)
	var rng := _rng(semente, 110)
	var verde := _verde_de(&"chorona")
	var r_fol := _r(R_FOLIOLO)
	var r_caule := _r(R_CAULE)
	var cor_caule := Color(0.84, 0.9, 0.76)
	var ht := lerpf(0.12, 1.02, pow(t, 0.8))
	var tronco := PackedVector3Array()
	var raios := PackedFloat32Array()
	for k in 5:
		var f := float(k) / 4.0
		tronco.append(Vector3(sin(f * 2.1 + giro) * 0.012, -0.01 + f * ht, cos(f * 1.7 + giro) * 0.01))
		raios.append(lerpf(0.013, 0.006, f) * lerpf(0.5, 1.0, t))
	_tubo(b, tronco, raios, 5, r_caule, cor_caule)
	# A coroa no alto do tronco: leques em pe, de onde a cortina parece brotar.
	var topo := tronco[4]
	for k in 4:
		var a := giro + float(k) * TAU / 4.0 + 0.3
		_leque(b, topo, Vector3(cos(a), 0.0, sin(a)), 5, lerpf(0.05, 0.11, t), 0.015, -0.1,
			rng, _cor_folha(verde, 0.95, rng), r_fol)
	_vento_local(b, 0, ht, 0.6)

	var nb := clampi(int(round(lerpf(3.0, 9.0, t))), 3, 9)
	var fundo := lerpf(ht * 0.6, -(chao - 0.09), smoothstep(0.1, 1.0, t))
	for k in nb:
		var ini := b.v.size()
		var a := giro + TAU * float(k) / float(nb) + rng.randf_range(-0.2, 0.2)
		var dh := Vector3(cos(a), 0.0, sin(a))
		var lat := Vector3(-dh.z, 0.0, dh.x)
		var p0 := _na_linha(tronco, rng.randf_range(0.8, 0.98))
		var alcance := lerpf(0.09, 0.4, t) * rng.randf_range(0.88, 1.1)
		var sobe := lerpf(0.05, 0.2, t) * rng.randf_range(0.8, 1.2)
		var apice := p0 + dh * alcance * 0.78 + Vector3.UP * sobe
		var fio := PackedVector3Array([p0, p0 + dh * alcance * 0.4 + Vector3.UP * sobe * 0.85,
			apice, p0 + dh * alcance + Vector3.UP * sobe * 0.55])
		var fim_y := fundo + rng.randf_range(-0.03, 0.1)
		var y := fio[3].y - 0.1
		var passos := 0
		while y > fim_y and passos < 20:
			var queda := clampf((fio[3].y - y) / maxf(fio[3].y - fim_y, 0.1), 0.0, 1.0)
			var rad := alcance * (1.02 + 0.12 * queda) + 0.01 * sin(y * 9.0 + float(k))
			if y < 0.1:
				rad = maxf(rad, 0.3)
			fio.append(Vector3(p0.x, 0.0, p0.z) + dh * rad + lat * 0.012 * sin(y * 6.0 + float(k))
				+ Vector3(0.0, y, 0.0))
			y -= 0.11
			passos += 1
		var rs := PackedFloat32Array()
		for j in fio.size():
			rs.append(lerpf(0.0045, 0.0018, float(j) / float(fio.size() - 1)) * lerpf(0.6, 1.0, t))
		_tubo(b, fio, rs, 3, r_caule, cor_caule)
		# As folhas: no arco, leques abertos; na queda, penduradas.
		var total := 0.0
		for j in range(1, fio.size()):
			total += fio[j].distance_to(fio[j - 1])
		var n_f := int(total / 0.1)
		for j in n_f:
			var f := (float(j) + 0.7) / float(n_f + 1)
			var p := _na_linha(fio, f)
			var lado := 1.0 if j % 2 == 0 else -1.0
			var cor := _cor_folha(verde, lerpf(0.95, 0.6, f), rng)
			var tam := lerpf(0.05, 0.105, sqrt(t)) * rng.randf_range(0.85, 1.1)
			if p.y > fio[3].y - 0.04:
				_leque(b, p, (dh + lat * lado * 0.8).normalized(), 5, tam, 0.01, 0.3, rng, cor, r_fol)
				continue
			var frente := (Vector3.DOWN * 0.85 + dh * 0.22 + lat * lado * 0.4).normalized()
			_leque_livre(b, p, frente, dh, 5 if f < 0.4 else 3, tam, 0.1, rng, cor, r_fol,
				0.5, 0.2)
		if madura:
			var ult := fio[fio.size() - 1]
			_cola(b, ult + Vector3(0.0, 0.03, 0.0), Vector3.DOWN, 0.1, 0.026, rng, verde, 2)
			# e uma segunda, menor, no meio de um fio sim, outro nao
			if k % 2 == 0:
				var meio := _na_linha(fio, 0.62)
				_cola(b, meio + dh * 0.01, (Vector3.DOWN + dh * 0.3).normalized(), 0.065, 0.018,
					rng, verde, 2)
		_vento_pendurado(b, ini, apice.y, apice.y - fim_y, 0.3)


# --- Gambazona -----------------------------------------------------------------------

## Quase so cola: pe baixo e troncudo, meia duzia de folhas, e cinco colas
## gordas maiores que qualquer folha — a do meio do tamanho de um antebraco. Os
## botoes vem em cacho (um no eixo e tres em volta por andar), e nao em fila,
## que e o que faz a cola ler gorda e nao comprida.
static func _gambazona(obra: Dictionary, t: float, madura: bool, semente: int,
		giro: float) -> void:
	var b := _balde(obra, MAT_FOLHA)
	var rng := _rng(semente, 120)
	var verde := _verde_de(&"gambazona")
	var r_fol := _r(R_FOLIOLO)
	var r_caule := _r(R_CAULE)
	var cor_caule := Color(0.84, 0.93, 0.7)
	var alto := lerpf(0.08, 0.72, pow(t, 0.85))
	var g := lerpf(0.4, 1.0, t)
	var eixo := PackedVector3Array([Vector3(0.0, -0.01, 0.0), Vector3(0.006, alto * 0.3, 0.0),
		Vector3(-0.004, alto * 0.5, 0.004), Vector3(0.0, alto * 0.62, 0.0)])
	_tubo(b, eixo, PackedFloat32Array([0.024 * g, 0.021 * g, 0.018 * g, 0.015 * g]), 6, r_caule, cor_caule)
	# Poucas folhas, grandes, embaixo: dois pares cruzados.
	for k in 2:
		var no := _na_linha(eixo, 0.12 + 0.22 * float(k))
		for lado in 2:
			var a := giro + float(k) * PI * 0.5 + PI * float(lado)
			var tam := lerpf(0.08, 0.18, sqrt(t)) * (1.0 - 0.12 * float(k))
			_leque(b, no, Vector3(cos(a), 0.0, sin(a)), 7, tam, tam * 0.45, 0.42 - 0.15 * float(k),
				rng, _cor_folha(verde, 0.5 + 0.2 * float(k), rng), r_fol)
	# Os galhos: curtos e grossos, saindo baixo e subindo; a cola ocupa quase
	# o galho inteiro.
	var n_g := 2 + int(t > 0.3) + int(t > 0.55)
	for k in n_g:
		var a := giro + PI * 0.25 + float(k) * TAU / float(n_g) + rng.randf_range(-0.2, 0.2)
		var dh := Vector3(cos(a), 0.0, sin(a))
		var no := _na_linha(eixo, 0.42 + 0.14 * float(k % 2))
		var cg := alto * rng.randf_range(0.26, 0.32)
		var p1 := no + (dh * 0.85 + Vector3.UP * 0.5).normalized() * cg * 0.6
		var p2 := p1 + (dh * 0.35 + Vector3.UP).normalized() * cg * 0.4
		_tubo(b, PackedVector3Array([no, p1, p2]), PackedFloat32Array([0.011 * g, 0.01 * g, 0.009 * g]),
			4, r_caule, cor_caule)
		var dir := (p2 - p1).normalized()
		# Uma folha na axila do galho.
		_leque(b, no + dh * 0.01, dh.rotated(Vector3.UP, 0.6), 5, lerpf(0.06, 0.12, sqrt(t)), 0.03,
			0.3, rng, _cor_folha(verde, 0.75, rng), r_fol)
		if madura:
			_cola_gorda(b, p2 - dir * 0.05, dir, 0.23 * g, 0.056 * g, rng, verde)
		else:
			_botao_verde(b, p2, dir, t, rng, verde, r_fol)
	var ponta := eixo[3]
	if madura:
		_cola_gorda(b, ponta - Vector3(0.0, 0.05, 0.0), Vector3.UP, 0.4 * g, 0.085 * g, rng, verde)
	else:
		_botao_verde(b, ponta, Vector3.UP, t * 1.3, rng, verde, r_fol)
	_vento_local(b, 0, alto, 0.6)


## A ponta da Gambazona antes de florir: um repolho de folhinha em volta de um
## botao verde que ja e gordo.
static func _botao_verde(b: Balde, p: Vector3, eixo: Vector3, t: float,
		rng: RandomNumberGenerator, verde: Color, r_fol: Rect2) -> void:
	var cor := _cor_folha(verde, 1.0, rng)
	var r := 0.012 + 0.024 * clampf(t, 0.0, 1.0)
	var base := _base_do_eixo(eixo)
	_botao(b, p + eixo * r * 0.6, Vector3(r, r * 1.2, r), base, 5, 2, rng,
		_lim(Color(0.82, 0.95, 0.7) * verde))
	for k in 7:
		var anel := 0 if k < 4 else 1
		var a := TAU * float(k) / (4.0 if anel == 0 else 3.0) + float(anel) * 0.8 + rng.randf_range(-0.2, 0.2)
		var saida := (base.x * cos(a) + base.z * sin(a)).normalized()
		var fr := (saida * (1.0 if anel == 0 else 0.5) + eixo * (0.5 if anel == 0 else 1.2)).normalized()
		_leque_livre(b, p - eixo * r * 0.3 * float(1 - anel), fr, saida, 5 if anel == 1 else 7,
			r * (3.2 if anel == 0 else 2.2), 0.25, rng, cor * (0.92 if anel == 0 else 1.0), r_fol)


## Cola gorda: por andar, um botao no eixo e tres em volta, girando; pistilo
## espetado para fora em cachos e acucar em todo andar.
static func _cola_gorda(b: Balde, pe: Vector3, eixo: Vector3, comp: float,
		grossura: float, rng: RandomNumberGenerator, verde: Color) -> void:
	var cor := _lim(Color(1.0, 1.0, 0.88) * verde)
	var cor_acu := _lim(Color(0.95, 1.0, 0.9) * verde)
	var r_acu := _r(R_ACUCAR)
	var r_pis := _r(R_PISTILO)
	var base := _base_do_eixo(eixo)
	var niveis := clampi(int(comp / (grossura * 0.95)) + 1, 3, 7)
	for k in niveis:
		var f := (float(k) + 0.5) / float(niveis)
		var raio := grossura * (0.76 + 0.24 * sin(PI * (0.1 + 0.8 * f))) * (1.0 - 0.55 * pow(f, 2.5))
		var centro := pe + eixo * comp * f
		_botao(b, centro, Vector3(raio * 0.8, raio * 0.95, raio * 0.8),
			Basis(eixo, rng.randf() * TAU) * base, 7, 3 if k == niveis - 1 else 2, rng, cor)
		if k == niveis - 1:
			break
		for j in 3:
			var a := TAU * float(j) / 3.0 + float(k) * 1.1 + rng.randf_range(-0.3, 0.3)
			var saida := (base.x * cos(a) + base.z * sin(a)).normalized()
			var c2 := centro + saida * raio * 0.62 + eixo * rng.randf_range(-0.2, 0.2) * raio
			var cr := cor * rng.randf_range(0.93, 1.04)
			cr.a = 1.0
			_botao(b, c2, Vector3(raio * 0.52, raio * 0.66, raio * 0.52) * rng.randf_range(0.85, 1.1),
				Basis(eixo, rng.randf() * TAU) * base, 6, 2, rng, cr)
			if rng.randf() < 0.6:
				var d := (saida * 0.75 + eixo * 0.6).normalized()
				var lat := eixo.cross(d).normalized()
				_cartao(b, c2 + saida * raio * 0.25, d, lat, lat.cross(d), raio * 0.8, raio * 1.1,
					r_pis, Color.WHITE, Color.WHITE)
		var a2 := rng.randf() * TAU
		var s2 := (base.x * cos(a2) + base.z * sin(a2)).normalized()
		var d2 := (s2 * 0.8 + eixo * 0.6).normalized()
		_foliolo(b, centro + s2 * raio * 0.7, d2, eixo.cross(d2).normalized(), eixo, raio * 1.9,
			raio * 0.7, 0.15, r_acu, cor_acu, _verso(cor_acu), 0.25)
	var topo := pe + eixo * comp * 1.02
	for k in 2:
		var lat := base.x if k == 0 else base.z
		_cartao(b, topo - eixo * grossura * 0.35, eixo, lat, lat.cross(eixo), grossura * 1.0,
			grossura * 1.3, r_pis, Color.WHITE, Color.WHITE)


# --- Vagalume ------------------------------------------------------------------------

## O pe comum de folha roxa quase preta, e no lugar de cada cola um fio de
## botoes que acendem azul-verde — pisca-pisca num pinheiro de Natal. Ainda sem
## flor, so as pontas dos galhos acendem, fraquinho. A flor acesa vai para o
## MAT_BRILHO, e e ela que desenha a planta no andar apagado.
static func _vagalume(obra: Dictionary, t: float, madura: bool, semente: int,
		giro: float) -> void:
	var b := _balde(obra, MAT_FOLHA)
	var bb := _balde(obra, MAT_BRILHO)
	var r0 := _rng(semente, 0)
	r0.randf()
	var altura := lerpf(0.05, 1.12, pow(t, 0.9)) * r0.randf_range(0.94, 1.04)
	var colas: Array = []
	_pe(b, Vector3.ZERO, t, madura, semente, giro, _verde_de(&"vagalume"), altura,
		{"r_fol": _r(R_FOLIOLO_ROXO), "sem_cola": true, "colas": colas, "enxuto": true,
		"cor_caule": Color(0.34, 0.2, 0.36)})
	var rng := _rng(semente, 130)
	for spec: Dictionary in colas:
		_cola_acesa(b, bb, spec, rng, t)
	_vento_local(b, 0, altura)
	_vento_local(bb, 0, altura)


## Uma cor de pisca-pisca: entre verde-agua e azul, cada botao a sua.
static func _luz(rng: RandomNumberGenerator, forca: float) -> Color:
	var c := Color(0.5, 1.0, 0.7).lerp(Color(0.4, 0.84, 1.0), rng.randf())
	c = c * lerpf(0.78, 1.0, rng.randf()) * forca
	c.a = 1.0
	return c


static func _cola_acesa(b: Balde, bb: Balde, spec: Dictionary, rng: RandomNumberGenerator,
		t: float) -> void:
	var pe: Vector3 = spec["pe"]
	var eixo: Vector3 = spec["eixo"]
	var comp: float = spec["comp"]
	var grossura: float = spec["grossura"]
	var r_b := _r(R_BUD_BRILHO)
	var base := _base_do_eixo(eixo)
	if spec["ponta"]:
		if t < 0.3:
			return
		var r := 0.008 + 0.007 * t
		_botao(bb, pe + eixo * r, Vector3(r, r * 1.2, r), base, 5, 2, rng, _luz(rng, 0.55), r_b)
		return
	var r_acu := _r(R_FOLIOLO_ROXO)
	var cor_acu := Color(1.0, 0.96, 1.0)
	# Contas separadas, e nao uma coluna: e o pisca-pisca. Entre elas aparece o
	# acucar roxo.
	var qtd := clampi(int(comp / 0.042) + 2, 3, 6)
	for k in qtd:
		var f := (float(k) + 0.5) / float(qtd)
		var raio := grossura * 0.6 * (1.0 - 0.35 * f)
		var off := (base.x * rng.randf_range(-1, 1) + base.z * rng.randf_range(-1, 1)) * raio * 0.25
		var centro := pe + eixo * comp * f + off
		_botao(bb, centro, Vector3(raio, raio * 1.15, raio), Basis(eixo, rng.randf() * TAU) * base,
			5, 3 if k == qtd - 1 else 2, rng, _luz(rng, 1.0), r_b)
		if rng.randf() < 0.6:
			var a := rng.randf() * TAU
			var saida := (base.x * cos(a) + base.z * sin(a)).normalized()
			var d := (saida * 0.85 + eixo * 0.5).normalized()
			_foliolo(b, centro + saida * raio * 0.5, d, eixo.cross(d).normalized(), eixo,
				raio * 2.0, raio * 0.6, 0.15, r_acu, cor_acu, _verso(cor_acu), 0.25)


# --- os recipientes -------------------------------------------------------------------

## O recipiente da variedade com o pe em `pe`. O vaso de feltro para quase
## todas; o bonsai numa bandeja de ceramica em cima de um suporte de madeira (a
## arvore de trinta centimetros fica na altura do olho de quem se abaixa um
## pouco); a Morcega num vaso pendurado de boca para baixo no forro
## (`pe.y + pe_direito`), com a terra olhando o chao.
static func recipiente(sup: Dictionary, pe: Vector3, v: StringName, tem_terra: bool,
		molhado: float, semente: int, pe_direito: float = 2.61) -> void:
	match v:
		&"bonsai":
			_suporte_bonsai(sup, pe, tem_terra, molhado, semente)
		&"morcega":
			_vaso_pendurado(sup, pe, tem_terra, molhado, semente, pe_direito)
		_:
			vaso(sup, pe, tem_terra, molhado, semente)


## Medidas do recipiente, a partir do pe:
##   "terra"    onde a planta nasce (o que se passa para `variedade`)
##   "colisao"  caixas solidas {tamanho, pos} na altura do corpo (vazio se nao ha)
##   "area"     a caixa da interacao {tamanho, pos}: onde o jogador olha
##   "mao"      onde as maos de quem cuida trabalham (para virar o corpo)
static func recipiente_info(v: StringName, pe_direito: float = 2.61) -> Dictionary:
	match v:
		&"bonsai":
			return {
				"terra": Vector3(0.0, BONSAI_TERRA, 0.0),
				"colisao": [{"tamanho": Vector3(0.46, BONSAI_MESA + 0.06, 0.34),
					"pos": Vector3(0.0, (BONSAI_MESA + 0.06) * 0.5, 0.0)}],
				"area": {"tamanho": Vector3(0.8, 1.2, 0.8), "pos": Vector3(0.0, 0.6, 0.0)},
				"mao": Vector3(0.0, BONSAI_TERRA + 0.05, 0.0),
			}
		&"morcega":
			var terra_y := pe_direito - MORCEGA_FUNDO - TERRA_Y
			var baixo := 0.4
			var alto := minf(pe_direito - 0.05, terra_y + 0.45)
			return {
				"terra": Vector3(0.0, terra_y, 0.0),
				"colisao": [],
				"area": {"tamanho": Vector3(0.8, alto - baixo, 0.8),
					"pos": Vector3(0.0, (alto + baixo) * 0.5, 0.0)},
				"mao": Vector3(0.0, minf(terra_y - 0.1, 1.75), 0.0),
			}
	return {
		"terra": Vector3(0.0, TERRA_Y, 0.0),
		"colisao": [{"tamanho": Vector3(0.47, VASO_ALTURA, 0.47),
			"pos": Vector3(0.0, VASO_ALTURA * 0.5, 0.0)}],
		"area": {"tamanho": Vector3(0.8, 1.1, 0.8), "pos": Vector3(0.0, 0.55, 0.0)},
		"mao": Vector3(0.0, TERRA_Y, 0.0),
	}


## A estaca de semeado no recipiente da variedade: a de sempre; pequena no
## bonsai; de cabeca para baixo, pendurada da terra, na Morcega.
static func estaca_da_variedade(sup: Dictionary, terra: Vector3, v: StringName,
		semente: int) -> void:
	var xf := Transform3D()
	match v:
		&"morcega":
			xf = Transform3D(Basis(Vector3.RIGHT, PI), terra)
		&"bonsai":
			xf = Transform3D(Basis().scaled(Vector3.ONE * 0.45), terra)
		_:
			estaca(sup, terra, semente)
			return
	var tmp := {}
	estaca(tmp, Vector3.ZERO, semente)
	for m: StringName in tmp:
		if not sup.has(m):
			sup[m] = PSXMesh.dados_vazios()
		PSXMesh.acumular(sup[m], tmp[m], xf)


## O suporte do bonsai: mesinha de madeira escura, e em cima a bandeja rasa de
## ceramica esmaltada de azul, de cantos redondos, em quatro pezinhos. Com
## terra: o montinho em volta do tronco, musgo e tres pedrinhas.
static func _suporte_bonsai(sup: Dictionary, pe: Vector3, tem_terra: bool, molhado: float,
		semente: int) -> void:
	var obra := {}
	var b := _balde(obra, MAT)
	var rng := _rng(semente, 71)
	var xf := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.15, 0.15)), pe)
	var r_m := _r(R_MADEIRA)
	var pau := Color(0.17, 0.08, 0.05)
	var e := 0.035
	_caixa(b, xf * Transform3D(Basis(), Vector3(0.0, BONSAI_MESA - e * 0.5, 0.0)),
		Vector3(0.46, e, 0.34), r_m, pau, false)
	var perna := BONSAI_MESA - e
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_caixa(b, xf * Transform3D(Basis(), Vector3(sx * 0.195, perna * 0.5, sz * 0.135)),
				Vector3(0.036, perna, 0.036), r_m, pau * 0.85)
	# A saia embaixo do tampo e a travessa baixa.
	for sz: float in [-1.0, 1.0]:
		_caixa(b, xf * Transform3D(Basis(), Vector3(0.0, perna - 0.028, sz * 0.135)),
			Vector3(0.354, 0.05, 0.02), r_m, pau * 0.8)
		_caixa(b, xf * Transform3D(Basis(), Vector3(sz * 0.195, perna - 0.028, 0.0)),
			Vector3(0.02, 0.05, 0.234), r_m, pau * 0.8)
	_caixa(b, xf * Transform3D(Basis(), Vector3(0.0, 0.1, 0.0)), Vector3(0.354, 0.022, 0.022),
		r_m, pau * 0.75)

	# A bandeja.
	var r_c := _r(R_CERAMICA)
	var esmalte := Color(0.1, 0.2, 0.52)
	var y0 := BONSAI_MESA + 0.012
	var xb := xf * Transform3D(Basis(), Vector3(0.0, y0, 0.0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_caixa(b, xf * Transform3D(Basis(), Vector3(sx * 0.13, BONSAI_MESA + 0.006, sz * 0.08)),
				Vector3(0.03, 0.012, 0.03), r_c, esmalte * 0.8)
	var cont := _contorno(Vector2(0.17, 0.115), 0.03, 3)
	var borda := 0.056
	_prisma(b, xb, cont, PackedVector2Array([Vector2(0.0, 0.95), Vector2(0.006, 1.0),
		Vector2(0.046, 1.005), Vector2(borda, 1.03)]), r_c, esmalte, 3.0, false)
	_prisma(b, xb, cont, PackedVector2Array([Vector2(borda, 1.03), Vector2(borda + 0.0002, 0.93)]),
		r_c, esmalte * 1.08, 3.0, false)
	var inv := cont.duplicate()
	inv.reverse()
	var cheio := BONSAI_TERRA - y0
	_prisma(b, xb, inv, PackedVector2Array([Vector2(cheio - 0.006 if tem_terra else 0.008, 0.93),
		Vector2(borda, 0.93)]), r_c, esmalte * 0.72, 3.0, false)
	if not tem_terra:
		_prisma(b, xb, cont, PackedVector2Array([Vector2(0.006, 0.93), Vector2(0.008, 0.93)]),
			r_c, esmalte * 0.55, 1.0, true, r_c)
		_despejar(sup, obra)
		return
	var molh := clampf(molhado, 0.0, 1.0)
	var cor_t := Color(1.0, 1.0, 1.0).lerp(Color(0.5, 0.44, 0.4), molh)
	var r_t := _r(R_TERRA)
	_prisma(b, xb, cont, PackedVector2Array([Vector2(cheio - 0.004, 0.93), Vector2(cheio, 0.93)]),
		r_t, cor_t, 1.0, true, r_t)
	# O montinho no pe do tronco, com a terra em projecao de cima (a UV de
	# revolucao torcia a textura em redemoinho).
	_monte(b, xf * Transform3D(Basis(), Vector3(0.0, BONSAI_TERRA - 0.001, 0.0)), 0.1, 0.014,
		10, r_t, cor_t)
	# Musgo: manchas de borda torta, verde-escuro, meio afundadas no montinho.
	var r_mu := _sub(_r(R_COTILEDONE), 0.3, 0.3, 0.7, 0.7)
	for k in 4:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.05, 0.12)
		var c := Vector3(cos(a) * d * 1.3, 0.0, sin(a) * d * 0.8)
		var y := BONSAI_TERRA + 0.0015 + maxf(0.0, 0.014 * (1.0 - d / 0.1))
		_musgo(b, xf * Transform3D(Basis(Vector3.UP, rng.randf() * TAU), c + Vector3(0.0, y, 0.0)),
			rng.randf_range(0.025, 0.045), rng, r_mu, Color(0.12, 0.2, 0.07) * (1.0 - 0.3 * molh))
	# Pedrinhas.
	var r_p := _r(R_PLASTICO)
	for k in 3:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.08, 0.13)
		var c := xf * Vector3(cos(a) * d * 1.2, BONSAI_TERRA + 0.004, sin(a) * d * 0.7)
		_pedra(b, c, rng.randf_range(0.009, 0.014), rng, r_p)
	_despejar(sup, obra)


## Montinho de terra: leque de aneis com a UV projetada de cima.
static func _monte(b: Balde, xf: Transform3D, raio: float, alto: float, lados: int, r: Rect2,
		cor: Color) -> void:
	var up := (xf.basis * Vector3.UP).normalized()
	var aneis: Array[float] = [0.0, 0.35, 0.7, 1.0]
	var inicio := b.v.size()
	for a in aneis.size():
		var f: float = aneis[a]
		var n_col := 1 if a == 0 else lados
		for k in n_col:
			var ang := TAU * float(k) / float(lados)
			var x := cos(ang) * raio * f
			var z := sin(ang) * raio * f
			var y := alto * (1.0 - f * f)
			var nrm := (Vector3(cos(ang) * f * 2.0 * alto / raio, 1.0, sin(ang) * f * 2.0 * alto / raio)).normalized()
			b.vert(xf * Vector3(x, y, z), (xf.basis * nrm).normalized(),
				_uv(r, 0.5 + x / (raio * 2.2), 0.5 + z / (raio * 2.2)), cor)
	for k in lados:
		b.tri(inicio, inicio + 1 + k, inicio + 1 + (k + 1) % lados, up)
	for a in range(1, aneis.size() - 1):
		for k in lados:
			var i0 := inicio + 1 + (a - 1) * lados + k
			var i1 := inicio + 1 + (a - 1) * lados + (k + 1) % lados
			b.quad(i0, i1, i1 + lados, i0 + lados, up)


## Mancha de musgo: leque de sete pontas com o raio sorteado.
static func _musgo(b: Balde, xf: Transform3D, raio: float, rng: RandomNumberGenerator, r: Rect2,
		cor: Color) -> void:
	var up := (xf.basis * Vector3.UP).normalized()
	var c0 := b.vert(xf * Vector3.ZERO, up, _uv(r, 0.5, 0.5), cor * 1.1)
	var lados := 7
	for k in lados:
		var a := TAU * float(k) / float(lados)
		var rr := raio * rng.randf_range(0.55, 1.0)
		b.vert(xf * Vector3(cos(a) * rr, -0.001, sin(a) * rr), up,
			_uv(r, 0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5), cor * 0.85)
	for k in lados:
		b.tri(c0, c0 + 1 + k, c0 + 1 + (k + 1) % lados, up)


## Pedrinha: octaedro achatado e torto, cinza.
static func _pedra(b: Balde, c: Vector3, t: float, rng: RandomNumberGenerator, r: Rect2) -> void:
	var base := Basis(Vector3.UP, rng.randf() * TAU)
	var eixos: Array[Vector3] = [Vector3(t * 1.3, 0, 0), Vector3(-t * 1.1, 0, 0), Vector3(0, t * 0.7, 0),
		Vector3(0, -t * 0.3, 0), Vector3(0, 0, t), Vector3(0, 0, -t * 0.9)]
	var cor := Color(0.2, 0.19, 0.18) * rng.randf_range(0.8, 1.2)
	cor.a = 1.0
	var idx: Array[int] = []
	for k in 6:
		var p: Vector3 = base * eixos[k]
		idx.append(b.vert(c + p, p.normalized(), _uv(r, 0.3 + 0.1 * float(k), 0.5), cor))
	for sx in [0, 1]:
		for sy in [2, 3]:
			for sz in [4, 5]:
				var a: int = idx[sx]
				var bb: int = idx[sy]
				var cc: int = idx[sz]
				b.tri(a, bb, cc, (b.v[a] + b.v[bb] + b.v[cc]) / 3.0 - c)


## O vaso da Morcega: o mesmo feltro, de boca para baixo, pendurado no forro.
## Chapinha e corrente curta ate um aro; do aro tres cordas descem por cima do
## fundo (que agora e o topo) e pelo costado ate um cinto de corda na boca, e
## por baixo da boca as tres se amarram em triangulo — e o que "segura a terra"
## na cabeca de quem olha. O triangulo deixa o meio livre para o caule.
static func _vaso_pendurado(sup: Dictionary, pe: Vector3, tem_terra: bool, molhado: float,
		semente: int, pe_direito: float) -> void:
	var obra := {}
	var b := _balde(obra, MAT)
	var rng := _rng(semente, 7)
	var giro := rng.randf() * TAU
	var teto := pe + Vector3(0.0, pe_direito, 0.0)
	var fundo := teto - Vector3(0.0, MORCEGA_FUNDO, 0.0)
	var xf := Transform3D(Basis(Vector3.RIGHT, PI) * Basis(Vector3.UP, giro), fundo)
	_vaso_em(b, xf, tem_terra, molhado, semente, 10, COR_FELTRO)
	var r_m := _r(R_METAL)
	var metal := Color(0.66, 0.66, 0.68)
	_disco(b, Transform3D(Basis(), teto), -0.004, 0.035, 6, r_m, metal * 0.8, false)
	# A corrente: tres elos, cada um virado 90 graus do anterior.
	var aro := teto - Vector3(0.0, MORCEGA_CORRENTE, 0.0)
	var elo := (MORCEGA_CORRENTE - 0.012) / 3.0
	for k in 3:
		var c := teto - Vector3(0.0, 0.006 + elo * (float(k) + 0.5), 0.0)
		var lat := Vector3(cos(giro + float(k) * PI * 0.5), 0.0, sin(giro + float(k) * PI * 0.5))
		var pts := PackedVector3Array()
		for j in 7:
			var a := TAU * float(j) / 6.0
			pts.append(c + lat * cos(a) * 0.011 + Vector3.UP * sin(a) * elo * 0.62)
		_tubo(b, pts, PackedFloat32Array([0.0028, 0.0028, 0.0028, 0.0028, 0.0028, 0.0028, 0.0028]),
			3, r_m, metal)
	_anel(b, aro, 0.02, 0.0035, 6, r_m, metal)
	# As cordas e o cinto.
	var r_cd := _r(R_PLASTICO)
	var corda := Color(0.88, 0.8, 0.62)
	var cinto_y := fundo.y - 0.4
	var laco: Array[Vector3] = []
	for k in 3:
		var a := giro + TAU * float(k) / 3.0 + 0.5
		var d := Vector3(cos(a), 0.0, sin(a))
		var alto := Vector3(pe.x, 0.0, pe.z)
		_tubo(b, PackedVector3Array([aro + d * 0.02, alto + d * 0.2 + Vector3(0.0, fundo.y + 0.012, 0.0),
			alto + d * 0.237 + Vector3(0.0, fundo.y - 0.04, 0.0), alto + d * 0.24 + Vector3(0.0, cinto_y, 0.0),
			alto + d * 0.232 + Vector3(0.0, fundo.y - 0.468, 0.0)]),
			PackedFloat32Array([0.0045, 0.0045, 0.0045, 0.0045, 0.0045]), 3, r_cd, corda)
		laco.append(alto + d * 0.232 + Vector3(0.0, fundo.y - 0.468, 0.0))
	_anel(b, Vector3(pe.x, cinto_y, pe.z), 0.241, 0.005, 8, r_cd, corda * 0.95)
	for k in 3:
		_tubo(b, PackedVector3Array([laco[k], laco[(k + 1) % 3]]), PackedFloat32Array([0.0045, 0.0045]),
			3, r_cd, corda * 0.9)
	_despejar(sup, obra)


## Anel horizontal de fio (aro da corrente, cinto de corda).
static func _anel(b: Balde, centro: Vector3, raio: float, fio: float, lados: int, r: Rect2,
		cor: Color) -> void:
	var pts := PackedVector3Array()
	var rs := PackedFloat32Array()
	for k in lados + 1:
		var a := TAU * float(k) / float(lados)
		pts.append(centro + Vector3(cos(a) * raio, 0.0, sin(a) * raio))
		rs.append(fio)
	_tubo(b, pts, rs, 3, r, cor)
