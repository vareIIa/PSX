## O verde do miolo de quadra e do fundo de quintal (PLANO_FLORA_AAA, rodada 2).
##
## Vista do alto, a cidade de interior de Minas e meia copa: o miolo da quadra e
## um pomar sem dono — mangueira, abacateiro, jabuticabeira, a touceira de
## bananeira, o mamoeiro, o bambuzal no canto, e o capim alto por baixo. O
## `FundosBuilder._miolo` fazia um gramado liso com uma arvore em duas quadras
## (a foto aerea da rodada 2: retangulos verde-escuros vazios do tamanho de meio
## quarteirao), e o quintal do predio de comercio era so tambor e estrado.
##
## Tudo aqui sai de um rng PROPRIO, semeado pelo lugar e pelo estado do rng do
## chunk (que so se le): nada muda no sorteio de quem vem depois (memoria "rng do
## chunk arrasta o resto").
##
## O chao miudo (capim, mato, taioba, folha caida) vai no balde `plantas@perto`,
## cortado a 40 m pelo ChunkManager: de longe ele e a textura do gramado.
class_name MioloVerde
extends RefCounted

## Lado da grade de plantio do miolo, em metros: uma planta grande por celula.
const PASSO := 6.5
## Tufo de chao por metro quadrado.
const TUFOS_M2 := 0.13
const PERTO := &"plantas@perto"

## Chave de A/B: `--sem-miolo-verde`.
static var ativo := not OS.get_cmdline_user_args().has("--sem-miolo-verde")


## O miolo alem dos muros de fundo, `r` em coordenada local do chunk, chao em
## y = 0 (quem chama assenta no relevo depois). `pegadas` sao os lotes fundos
## (loja de conveniencia) que atravessam o miolo.
static func povoar(sup: Dictionary, r: Rect2, pegadas: Array[Rect2], semente: int) -> void:
	if not ativo or not ArvoreEsqueleto.ativo or r.size.x < 6.0 or r.size.y < 6.0:
		return
	var rr := RandomNumberGenerator.new()
	rr.seed = semente
	var ob := Obra.new()
	var chao := ob.malha(PERTO)
	var copas: Array[Vector3] = []
	var nx := maxi(1, int(r.size.x / PASSO))
	var nz := maxi(1, int(r.size.y / PASSO))
	var sx := r.size.x / float(nx)
	var sz := r.size.y / float(nz)
	var descartavel: Array[Dictionary] = []
	for i in nx:
		for j in nz:
			var p := r.position + Vector2((float(i) + 0.5) * sx, (float(j) + 0.5) * sz) \
				+ Vector2(rr.randf_range(-0.35, 0.35) * sx, rr.randf_range(-0.35, 0.35) * sz)
			var sorte := rr.randf()
			var borda := minf(minf(p.x - r.position.x, r.end.x - p.x),
				minf(p.y - r.position.y, r.end.y - p.y))
			if borda < 1.4 or _na_pegada(pegadas, p, 3.0):
				continue
			var base := Vector3(p.x, 0.0, p.y)
			if sorte < 0.46:
				var esp := Vegetacao.especie_de_quintal(rr)
				var raio := Vegetacao.arvore(sup, descartavel, base, esp, rr.randf_range(0.15, 0.85), rr)
				copas.append(Vector3(p.x, raio, p.y))
			elif sorte < 0.6:
				Plantas.bananeira(sup, base, rr)
				copas.append(Vector3(p.x, 1.5, p.y))
			elif sorte < 0.66:
				Plantas.mamoeiro(sup, base, rr)
			elif sorte < 0.71 and borda < 4.0:
				Plantas.bambu(sup, base, rr)
				copas.append(Vector3(p.x, 2.0, p.y))
			elif sorte < 0.84:
				var cel := Vegetacao.C_ARBUSTO if rr.randf() < 0.75 else Vegetacao.C_PRIMAVERA
				Vegetacao.arbusto(ob, base, rr.randf_range(1.4, 2.4), cel, rr)
			# O resto e clareira: o pomar de verdade tem vao.
	_chao(chao, r, pegadas, copas, rr)
	ob.despejar(sup)


## O chao miudo: capim-gordura e mato por todo lado, a taioba e a costela na
## sombra de copa, e a folha caida embaixo de cada arvore.
static func _chao(m: ParedeVazada.Malha, r: Rect2, pegadas: Array[Rect2], copas: Array[Vector3],
		rr: RandomNumberGenerator) -> void:
	var n := int(r.size.x * r.size.y * TUFOS_M2)
	for k in n:
		var p := Vector2(rr.randf_range(r.position.x + 0.4, r.end.x - 0.4),
			rr.randf_range(r.position.y + 0.4, r.end.y - 0.4))
		if _na_pegada(pegadas, p, 0.5):
			continue
		var sombra := false
		for c: Vector3 in copas:
			if Vector2(c.x, c.z).distance_to(p) < c.y * 0.8:
				sombra = true
				break
		var sorte := rr.randf()
		var cel := Plantas.C_MATO
		var alto := rr.randf_range(0.35, 0.6)
		if sombra:
			if sorte < 0.35:
				cel = Plantas.C_TAIOBA
				alto = rr.randf_range(0.6, 1.0)
			elif sorte < 0.5:
				cel = Plantas.C_COSTELA
				alto = rr.randf_range(0.7, 1.1)
			elif sorte < 0.6:
				cel = Plantas.C_MARIA
				alto = rr.randf_range(0.4, 0.6)
		elif sorte < 0.45:
			cel = Plantas.C_CAPIM_GORDURA
			alto = rr.randf_range(0.6, 1.1)
		Plantas.em_pe(m, Vector3(p.x, 0.0, p.y), alto, alto * rr.randf_range(1.0, 1.4), cel,
			rr.randf() * PI, 2, Color.WHITE.lerp(Color(0.9, 0.95, 0.8), rr.randf()))
	# A folha caida embaixo da copa (mais na seca).
	for c: Vector3 in copas:
		for k in rr.randi_range(2, 4) + roundi(3.0 * Estacao.seca()):
			var a := rr.randf() * TAU
			var d := c.y * 0.85 * sqrt(rr.randf())
			var q := Vector2(c.x + cos(a) * d, c.z + sin(a) * d)
			if not r.has_point(q) or _na_pegada(pegadas, q, 0.2):
				continue
			Plantas.deitado(m, Vector3(q.x, 0.05 + 0.003 * float(k), q.y), rr.randf_range(0.9, 1.6),
				Plantas.C_FOLHA_CAIDA, rr.randf() * TAU, Color(0.85, 0.85, 0.85))


## O fundo do quintal de um lote (FundosBuilder.quintais), depois do que o
## quintal ja montou. Fica na faixa rente ao muro de fundo, que o puxadinho
## (no maximo `q - 1,4` de fundo) nunca alcanca: o mato do pe do muro, a
## espada-de-sao-jorge e a maria-sem-vergonha do canto; e no fundo de comercio,
## que nao tinha planta nenhuma, a arvore ou a bananeira no canto.
static func quintal(sup: Dictionary, face: Dictionary, a: float, b: float, q: float,
		casa: bool, semente: int) -> void:
	if not ativo or not ArvoreEsqueleto.ativo or b - a < 2.4 or q < 2.5:
		return
	var rr := RandomNumberGenerator.new()
	rr.seed = semente
	var ob := Obra.new()
	var m := ob.malha(PERTO)
	var prof := ChunkBuilder.PROF_PREDIO
	var fundo := prof + q
	# Mato no pe do muro de fundo e nos dois muros de divisa.
	var n := int((b - a) * 1.1)
	for k in n:
		var t := rr.randf_range(a + 0.3, b - 0.3)
		var s := fundo - rr.randf_range(0.2, 0.55)
		var cel := Plantas.C_MATO if rr.randf() < 0.75 else Plantas.C_CAPIM_GORDURA
		var alto := rr.randf_range(0.3, 0.7)
		Plantas.em_pe(m, FundosBuilder._ponto(face, t, s), alto, alto * 1.3, cel, rr.randf() * PI, 2)
	for lado: float in [a + 0.25, b - 0.25]:
		for k in int(q * 0.6):
			var s := rr.randf_range(prof + 1.5, fundo - 0.5)
			var alto := rr.randf_range(0.25, 0.5)
			Plantas.em_pe(m, FundosBuilder._ponto(face, lado + rr.randf_range(-0.1, 0.1), s), alto,
				alto * 1.2, Plantas.C_MATO, rr.randf() * PI, 2)
	# O canteiro do canto, na casa: espada-de-sao-jorge, maria-sem-vergonha, taioba.
	if casa and rr.randf() < 0.7:
		var t := a + 0.7 if rr.randf() < 0.5 else b - 0.7
		var cels: Array[Vector2i] = [Plantas.C_ESPADA, Plantas.C_MARIA, Plantas.C_TAIOBA,
			Plantas.C_COSTELA]
		for k in rr.randi_range(2, 4):
			var cel := cels[rr.randi() % cels.size()]
			var alto := rr.randf_range(0.6, 1.0) if cel != Plantas.C_MARIA else rr.randf_range(0.4, 0.6)
			Plantas.em_pe(m, FundosBuilder._ponto(face, t + rr.randf_range(-0.4, 0.4),
				fundo - rr.randf_range(0.4, 1.2)), alto, alto * 1.2, cel, rr.randf() * PI, 3)
	# A trepadeira no muro de fundo: o maracuja ou a unha-de-gato cobrindo um
	# trecho, dos dois lados (o de fora e o que o miolo e o beco veem), e
	# passando um palmo por cima do chapim.
	if rr.randf() < 0.4 and b - a >= 3.0:
		var larg := minf(rr.randf_range(1.6, 3.2), b - a - 0.6)
		var t := rr.randf_range(a + 0.3 + larg * 0.5, b - 0.3 - larg * 0.5)
		var alto := rr.randf_range(1.4, 2.3)
		var fora := KitModular._normal(int(face["direcao"]))
		var maracuja := rr.randf() < 0.55
		var mat := m if maracuja else ob.malha(&"vegetacao@perto")
		var cel := Plantas.C_MARACUJA if maracuja else Vegetacao.C_HERA
		for lado: float in [1.0, -1.0]:
			if lado < 0.0 and rr.randf() < 0.4:
				continue
			var s := fundo - FundosBuilder.ESPESSURA_MURO * 0.5 * lado - 0.03 * lado
			var centro := FundosBuilder._ponto(face, t, s) + Vector3(0.0,
				FundosBuilder.ALTURA_MURO + 0.25 - alto * 0.5, 0.0)
			_na_parede(mat, centro, Vector3(face["eixo"]), fora * lado, larg, alto, cel)
	# O fundo de comercio ganha o verde que so a casa tinha.
	if not casa and q >= 4.0 and rr.randf() < 0.45:
		var t := a + 1.3 if rr.randf() < 0.5 else b - 1.3
		var pe := FundosBuilder._ponto(face, t, fundo - minf(1.8, q * 0.3))
		var sorte := rr.randf()
		if sorte < 0.55 and b - a >= 4.0:
			var descartavel: Array[Dictionary] = []
			Vegetacao.arvore(sup, descartavel, pe, Vegetacao.especie_de_quintal(rr),
				rr.randf_range(0.0, 0.5), rr)
		elif sorte < 0.85:
			Plantas.bananeira(sup, pe, rr)
		else:
			Plantas.mamoeiro(sup, pe, rr)
	ob.despejar(sup)


## Cartao de trepadeira chapado na parede: uma face, virada para `fora`, quase
## sem vento (a rama esta presa no muro).
static func _na_parede(m: ParedeVazada.Malha, centro: Vector3, eixo: Vector3, fora: Vector3,
		larg: float, alto: float, celula: Vector2i) -> void:
	var uv := Vegetacao.uv_de(celula)
	var bx := eixo * larg * 0.5
	var by := Vector3.UP * alto * 0.5
	var cantos: Array[Vector3] = [centro - bx - by, centro + bx - by, centro + bx + by, centro - bx + by]
	var uvs: Array[Vector2] = [Vector2(uv.position.x, uv.end.y), uv.end,
		Vector2(uv.end.x, uv.position.y), uv.position]
	var nrm := (fora + Vector3.UP * 0.2).normalized()
	var ids: Array[int] = []
	for i in 4:
		var topo := 1.0 if i >= 2 else 0.0
		var luz := lerpf(0.8, 1.0, topo)
		ids.append(m.vertice(cantos[i], nrm, uvs[i], Vector2.ZERO, Color(luz, luz, luz, 0.12 * topo)))
	m.quad(ids[0], ids[1], ids[2], ids[3], fora)


static func _na_pegada(pegadas: Array[Rect2], p: Vector2, folga: float) -> bool:
	for pg: Rect2 in pegadas:
		if pg.grow(folga).has_point(p):
			return true
	return false
