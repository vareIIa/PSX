## As plantas de quintal em 3D (PLANO_FLORA_AAA, rodada 2).
##
## A bananeira e o bambu da Vegetacao eram cartoes cruzados: de frente passavam,
## de lado eram quatro placas em estrela, e o bambu de nove metros era um painel
## com um desenho de bambu. Sao as duas plantas que mais aparecem em quintal de
## Minas, junto da mangueira. Aqui:
##
##   bananeira   touceira de pseudocaule roliço, folha em FITA que sobe e verga
##               (a celula da folha de bananeira esticada ao longo da nervura),
##               a folha velha seca pendurada no caule, os filhotes em volta e,
##               na mae, o cacho com o coracao roxo
##   bambu       colmos roliços que abrem em arco, com os ramos de folha em lanca
##               pendurados do meio para cima
##   mamoeiro    caule fino e cinza, a coroa de folha palmada em peciolo longo e
##               os mamoes grudados no caule
##   miudezas    capim-gordura, espada-de-sao-jorge, taioba, mato de calcada,
##               maria-sem-vergonha, costela-de-adao, horta, folha caida: cartoes
##               em pe cruzados (ou deitados) do atlas `plantas`
##
## O sorteio: `bananeira` e `bambu` substituem os da Vegetacao e gastam do rng de
## quem planta exatamente o que os de antes gastavam, na mesma ordem (memoria "rng
## do chunk arrasta o resto"); o resto do desenho sai de um rng proprio. As
## miudezas sao chamadas por quem ja tem rng proprio (MioloVerde).
class_name Plantas
extends RefCounted

const MAT := &"plantas"
const CASCA := KitEstrada.M_CASCA
## O caule verde (bananeira, mamoeiro, bambu): textura propria, porque a casca e
## parda e a tinta de vertice nao passa de 1.
const CAULE := &"caule"

const C_BAMBU_RAMO := Vector2i(0, 0)
const C_MAMAO_FOLHA := Vector2i(1, 0)
const C_BANANA_CACHO := Vector2i(2, 0)
const C_MAMAO_FRUTOS := Vector2i(3, 0)
const C_CAPIM_GORDURA := Vector2i(0, 1)
const C_ESPADA := Vector2i(1, 1)
const C_TAIOBA := Vector2i(2, 1)
const C_MATO := Vector2i(3, 1)
const C_MARIA := Vector2i(0, 2)
const C_JABUTICABA := Vector2i(1, 2)
const C_GOIABA := Vector2i(2, 2)
const C_MARACUJA := Vector2i(3, 2)
const C_SAMAMBAIA := Vector2i(0, 3)
const C_COSTELA := Vector2i(1, 3)
const C_FOLHA_CAIDA := Vector2i(2, 3)
const C_HORTA := Vector2i(3, 3)

const COPA := KitEstrada.CEDE_COPA
const TRONCO := KitEstrada.CEDE_TRONCO


# --- bananeira -------------------------------------------------------------------

## A touceira de bananeira. Gasta do `rng` de quem planta o mesmo que a de
## cartao (Vegetacao.bananeira) gastava, e usa esses numeros para o lugar, a
## altura e o rumo de cada folha: a planta nova fica onde estava a velha.
static func bananeira(sup: Dictionary, base: Vector3, rng: RandomNumberGenerator) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([rng.state, roundi(base.x * 10.0), roundi(base.z * 10.0), 31])
	# --- os sorteios da de cartao, na ordem dela ---------------------------
	var pes: Array[Dictionary] = []
	var n_pes := rng.randi_range(3, 5)
	for k in n_pes:
		var a := rng.randf_range(0.0, TAU)
		var d := rng.randf_range(0.0, 0.9)
		var alto := rng.randf_range(1.6, 3.2)
		var folhas: Array[Vector4] = []
		var secas: Array[bool] = []
		for f in rng.randi_range(4, 7):
			var af := rng.randf_range(0.0, TAU)
			var sobe := rng.randf_range(0.45, 1.2)
			var rolo := rng.randf_range(-0.6, 0.6)
			var comp := rng.randf_range(1.6, 2.4)
			folhas.append(Vector4(af, sobe, rolo, comp))
			secas.append(rng.randf() >= 0.85)
		pes.append({"p": base + Vector3(cos(a), 0.0, sin(a)) * d, "alto": alto,
			"folhas": folhas, "secas": secas})
	# ----------------------------------------------------------------------
	var ob := Obra.new()
	var casca := ob.malha(CAULE)
	var folha := ob.malha(Vegetacao.MAT)
	var y_topo := base.y + 5.5
	var mae := 0
	for k in pes.size():
		if float(pes[k]["alto"]) > float(pes[mae]["alto"]):
			mae = k
	for k in pes.size():
		var pe: Dictionary = pes[k]
		var p: Vector3 = pe["p"]
		# A de cartao media ate o topo da folha; o caule de verdade e mais alto
		# que o "alto" de antes, que era so o caule sem a coroa.
		var alto := float(pe["alto"]) * 1.15
		var topo := _pseudocaule(casca, p, alto, r, base.y, y_topo)
		var folhas: Array[Vector4] = pe["folhas"]
		var secas: Array[bool] = pe["secas"]
		for i in folhas.size():
			var fo := folhas[i]
			if secas[i]:
				_folha_seca(folha, topo - Vector3(0.0, r.randf_range(0.1, 0.5), 0.0), fo.x, fo.w * 0.8,
					base.y, y_topo)
			else:
				_folha_de_bananeira(folha, topo, fo.x, fo.y, fo.z, fo.w * 1.2, base.y, y_topo, r)
		# A de cartao tinha quatro a sete folhas; a coroa de verdade tem mais,
		# e a do meio sai quase em pe, ainda enrolada.
		for i in r.randi_range(2, 3):
			_folha_de_bananeira(folha, topo, r.randf_range(0.0, TAU), r.randf_range(0.7, 1.3),
				r.randf_range(-0.5, 0.5), r.randf_range(1.8, 2.6), base.y, y_topo, r)
		if k == mae and r.randf() < 0.55:
			_cacho(casca, ob.malha(MAT), topo, r.randf_range(0.0, TAU), base.y, y_topo)
	# Os filhotes: dois ou tres brotos de folha em pe no pe da touceira.
	for k in r.randi_range(1, 3):
		var a := r.randf_range(0.0, TAU)
		var p := base + Vector3(cos(a), 0.0, sin(a)) * r.randf_range(0.6, 1.2)
		# O filhote e so folha em pe saindo do chao, sem caule a vista.
		var alto := r.randf_range(0.25, 0.5)
		var topo := _pseudocaule(casca, p, alto, r, base.y, y_topo)
		for f in r.randi_range(3, 4):
			_folha_de_bananeira(folha, topo - Vector3(0.0, 0.1, 0.0), r.randf_range(0.0, TAU),
				r.randf_range(1.05, 1.4), r.randf_range(-0.3, 0.3), r.randf_range(0.9, 1.3), base.y,
				y_topo, r, 0.0)
	ob.despejar(sup)


## O pseudocaule: tubo verde-pardo que afina um pouco, com a base enterrada.
## Devolve o topo, de onde saem as folhas.
static func _pseudocaule(m: ParedeVazada.Malha, p: Vector3, alto: float,
		r: RandomNumberGenerator, y_chao: float, y_topo: float) -> Vector3:
	var grosso := lerpf(0.07, 0.13, clampf(alto / 3.5, 0.0, 1.0))
	var torto := Vector3(r.randf_range(-1, 1), 0.0, r.randf_range(-1, 1)) * alto * 0.04
	var pts := PackedVector3Array()
	var raios := PackedFloat32Array()
	var cedes := PackedFloat32Array()
	for i in 5:
		var t := float(i) / 4.0
		pts.append(p + Vector3(0.0, -0.2 + (alto + 0.2) * t, 0.0) + torto * t * t)
		raios.append(grosso * lerpf(1.15, 0.75, t))
		var h := clampf((alto * t) / maxf(y_topo - y_chao, 0.1), 0.0, 1.0)
		cedes.append(TRONCO * 2.0 * h)
	var tom := Color.WHITE.lerp(Color(0.86, 0.8, 0.7), r.randf_range(0.0, 0.5))
	ArvoreEsqueleto._tubo(m, pts, raios, cedes, 6, tom, 0.0, 0.0, y_chao, alto)
	return pts[4]


## Folha de bananeira em fita: a nervura sai do topo no rumo `af`, `sobe` acima
## da horizontal, e verga com o peso; a lamina e a celula da bananeira esticada
## na nervura (a celula e desenhada em pe, peciolo embaixo), com as duas metades
## caidas um pouco (o V aberto da folha).
static func _folha_de_bananeira(m: ParedeVazada.Malha, topo: Vector3, af: float, sobe: float,
		rolo: float, comp: float, y_chao: float, y_topo: float, r: RandomNumberGenerator,
		peciolo: float = 0.25) -> void:
	var fora := Vector3(cos(af), 0.0, sin(af))
	var eixo := (fora * cos(sobe) + Vector3(0.0, sin(sobe), 0.0)).normalized()
	var lado := fora.cross(Vector3.UP).normalized().rotated(eixo, rolo * 0.4)
	var meia := comp * 0.26
	# Peciolo curto antes da lamina: a folha nao nasce colada no caule.
	var de := topo + eixo * peciolo
	var verga := lerpf(0.55, 0.25, clampf((sobe - 0.45) / 0.75, 0.0, 1.0))
	var uv := Vegetacao.uv_de(Vegetacao.C_BANANEIRA)
	const SEG := 5
	var pts: Array[Vector3] = []
	for i in SEG + 1:
		var s := float(i) / float(SEG)
		pts.append(de + eixo * comp * s + Vector3(0.0, -verga * comp * s * s, 0.0))
	var ids_e: Array[int] = []
	var ids_m: Array[int] = []
	var ids_d: Array[int] = []
	var tinta := Color(1.0, 1.0, 1.0).lerp(Color(0.9, 0.96, 0.78), r.randf())
	for i in SEG + 1:
		var s := float(i) / float(SEG)
		var tg := (pts[mini(i + 1, SEG)] - pts[maxi(i - 1, 0)]).normalized()
		var cima := tg.cross(lado).normalized()
		if cima.y < 0.0:
			cima = -cima
		# As metades caem para fora: a borda desce um pouco abaixo da nervura.
		var cai := -cima * meia * 0.22 * sin(PI * minf(1.0, s * 1.1))
		var h := clampf((pts[i].y - y_chao) / maxf(y_topo - y_chao, 0.1), 0.0, 1.0)
		var cede := lerpf(TRONCO * 2.0, COPA, s) * lerpf(0.5, 1.0, h)
		var luz := lerpf(0.78, 1.0, s)
		var cor := Color(tinta.r * luz, tinta.g * luz, tinta.b * luz, cede)
		var v := lerpf(uv.end.y, uv.position.y, s)
		var n := (cima + tg * 0.1).normalized()
		# UV2.y = 1: a folha larga nao some de perfil (rodada 3). Cada metade tem a
		# propria normal; com o fade de perfil da copa, a metade de lado sumia e a
		# folha de bananeira virava fita estreita de palmeira (bancada `quintal_perto`).
		var sp := Vector2(0.0, 1.0)
		ids_e.append(m.vertice(pts[i] + lado * meia + cai, (n + lado * 0.3).normalized(),
			Vector2(uv.position.x + uv.size.x * 0.1, v), sp, cor))
		ids_m.append(m.vertice(pts[i], n, Vector2(uv.position.x + uv.size.x * 0.5, v), sp, cor))
		ids_d.append(m.vertice(pts[i] - lado * meia + cai, (n - lado * 0.3).normalized(),
			Vector2(uv.position.x + uv.size.x * 0.9, v), sp, cor))
	for i in SEG:
		var tg := (pts[i + 1] - pts[i]).normalized()
		var cima := tg.cross(lado).normalized()
		if cima.y < 0.0:
			cima = -cima
		for par: Array in [[ids_e, ids_m], [ids_m, ids_d]]:
			var a: Array[int] = par[0]
			var b: Array[int] = par[1]
			m.quad(a[i], a[i + 1], b[i + 1], b[i], cima)
			m.quad(a[i], a[i + 1], b[i + 1], b[i], -cima)


## A folha velha, seca e parda, pendurada ao longo do caule.
static func _folha_seca(m: ParedeVazada.Malha, de: Vector3, af: float, comp: float,
		y_chao: float, y_topo: float) -> void:
	var fora := Vector3(cos(af), 0.0, sin(af))
	var eixo := (fora * 0.3 + Vector3.DOWN).normalized()
	var lado := fora.cross(Vector3.UP).normalized()
	var p := de + eixo * comp * 0.45
	var b := Basis(lado, -eixo, lado.cross(-eixo).normalized())
	Vegetacao._cartao(m, p, b, Vector2(comp * 0.35, comp * 0.9), Vegetacao.C_BANANEIRA, de,
		Vector3(1.0, 2.0, 1.0), Color(0.78, 0.62, 0.36), y_chao, y_topo, 0.9)


## O cacho: engaco que sai da coroa, verga para fora e pende; o cacho e o
## coracao sao dois cartoes cruzados da celula `banana_cacho` pendurados na ponta.
static func _cacho(casca: ParedeVazada.Malha, m: ParedeVazada.Malha, topo: Vector3, a: float,
		y_chao: float, y_topo: float) -> void:
	var fora := Vector3(cos(a), 0.0, sin(a))
	var pts := PackedVector3Array([topo, topo + fora * 0.35 + Vector3(0.0, 0.1, 0.0),
		topo + fora * 0.6 - Vector3(0.0, 0.15, 0.0)])
	var raios := PackedFloat32Array([0.04, 0.035, 0.03])
	var cedes := PackedFloat32Array([TRONCO * 2.0, TRONCO * 2.5, TRONCO * 3.0])
	ArvoreEsqueleto._tubo(casca, pts, raios, cedes, 4, Color(0.9, 0.95, 0.8), 0.0, 0.0, y_chao,
		y_topo - y_chao)
	var ponta := pts[2]
	var alto := 1.1
	var centro := ponta - Vector3(0.0, alto * 0.5, 0.0)
	for k in 2:
		var b := Basis(Vector3.UP, a + PI * 0.5 * float(k))
		Vegetacao._cartao(m, centro, b, Vector2(alto * 0.62, alto), C_BANANA_CACHO, centro,
			Vector3(0.4, 0.6, 0.4), Color.WHITE, y_chao, y_topo, 1.0)


# --- bambu -----------------------------------------------------------------------

## Moita de bambu: gasta do `rng` de quem planta o mesmo que a de cartao
## (Vegetacao.bambu): a altura e quatro giros.
static func bambu(sup: Dictionary, base: Vector3, rng: RandomNumberGenerator) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([rng.state, roundi(base.x * 10.0), roundi(base.z * 10.0), 37])
	var alto := rng.randf_range(6.0, 9.0)
	for k in 4:
		rng.randf_range(0.0, 0.3)
	var ob := Obra.new()
	var casca := ob.malha(CAULE)
	var folha := ob.malha(MAT)
	var y_topo := base.y + alto
	# O verde comum, ou o bambu-imperial amarelo.
	var tom_base := Color(0.7, 0.86, 0.62) if r.randf() < 0.7 else Color(1.0, 0.92, 0.5)
	for c in r.randi_range(11, 16):
		var a := r.randf_range(0.0, TAU)
		var d := 0.55 * sqrt(r.randf())
		var pe := base + Vector3(cos(a), 0.0, sin(a)) * d
		var fora := Vector3(cos(a), 0.0, sin(a)).rotated(Vector3.UP, r.randf_range(-0.5, 0.5))
		var h := alto * r.randf_range(0.65, 1.05)
		# Sobe reto e abre em arco na ponta, mais o de fora da moita.
		var abre := h * lerpf(0.12, 0.4, d / 0.55) * r.randf_range(0.8, 1.2)
		var pts := PackedVector3Array()
		var raios := PackedFloat32Array()
		var cedes := PackedFloat32Array()
		for i in 5:
			var t := float(i) / 4.0
			pts.append(pe + Vector3(0.0, -0.1 + h * t, 0.0) + fora * abre * t * t
				- Vector3(0.0, abre * 0.25 * t * t * t, 0.0))
			raios.append(lerpf(0.05, 0.018, t))
			cedes.append(lerpf(0.0, COPA * 0.8, t * t))
		var tom := tom_base * r.randf_range(0.85, 1.0)
		tom.a = 1.0
		ArvoreEsqueleto._tubo(casca, pts, raios, cedes, 4, tom, 0.0, 0.0, base.y, h)
		# Os ramos de folha, do meio para cima, virados para fora da moita.
		var n := r.randi_range(3, 5)
		for i in n:
			var t := lerpf(0.4, 1.0, (float(i) + r.randf()) / float(n))
			var q := _no(pts, t)
			var gira := r.randf_range(-1.2, 1.2)
			var sai := fora.rotated(Vector3.UP, gira)
			var cima := (sai * 0.9 + Vector3.UP * 0.35).normalized()
			var tam := r.randf_range(1.0, 1.5) * lerpf(0.8, 1.1, t)
			var centro := q + cima * tam * 0.45
			for k in 2:
				var eixo_x := cima.cross(Vector3.UP).normalized().rotated(cima, PI * 0.5 * float(k) + 0.3)
				var b := Basis(eixo_x, cima, eixo_x.cross(cima).normalized())
				Vegetacao._cartao(folha, centro, b, Vector2(tam * 0.9, tam), C_BAMBU_RAMO, base
					+ Vector3(0.0, alto * 0.6, 0.0), Vector3(1.5, alto * 0.5, 1.5), Color.WHITE, base.y,
					y_topo, 1.0)
	ob.despejar(sup)


static func _no(pts: PackedVector3Array, t: float) -> Vector3:
	var f := clampf(t, 0.0, 1.0) * float(pts.size() - 1)
	var i := mini(int(f), pts.size() - 2)
	return pts[i].lerp(pts[i + 1], f - float(i))


# --- mamoeiro --------------------------------------------------------------------

## Mamoeiro: caule fino e reto, cinza-esverdeado, as folhas palmadas em peciolo
## longo so no alto e os mamoes grudados no caule logo abaixo delas. Quem chama
## passa um rng proprio (nao gasta de ninguem).
static func mamoeiro(sup: Dictionary, base: Vector3, r: RandomNumberGenerator) -> void:
	var ob := Obra.new()
	var casca := ob.malha(CAULE)
	var folha := ob.malha(MAT)
	var alto := r.randf_range(2.6, 5.0)
	var y_topo := base.y + alto + 1.2
	var torto := Vector3(r.randf_range(-1, 1), 0.0, r.randf_range(-1, 1)) * 0.12
	var pts := PackedVector3Array()
	var raios := PackedFloat32Array()
	var cedes := PackedFloat32Array()
	for i in 5:
		var t := float(i) / 4.0
		pts.append(base + Vector3(0.0, -0.2 + (alto + 0.2) * t, 0.0) + torto * alto * t * t)
		raios.append(lerpf(0.12, 0.07, t))
		cedes.append(TRONCO * 2.0 * t * t)
	# Cinza-esverdeado: o caule da bananeira lavado de cinza.
	ArvoreEsqueleto._tubo(casca, pts, raios, cedes, 6, Color(0.82, 0.8, 0.74), 0.0, 0.0, base.y, alto)
	var topo := pts[4]
	var n := r.randi_range(14, 20)
	for k in n:
		var a := TAU * float(k) / float(n) + r.randf_range(-0.2, 0.2)
		var fora := Vector3(cos(a), 0.0, sin(a))
		# As novas em pe, as velhas quase deitadas.
		var sobe := lerpf(1.1, 0.1, float(k % 4) / 3.0) + r.randf_range(-0.1, 0.1)
		var dir := (fora * cos(sobe) + Vector3.UP * sin(sobe)).normalized()
		var comp_p := r.randf_range(0.8, 1.2)
		var ponta := topo + dir * comp_p - Vector3(0.0, 0.1 * comp_p, 0.0)
		var pp := PackedVector3Array([topo, (topo + ponta) * 0.5 + Vector3(0.0, 0.04, 0.0), ponta])
		ArvoreEsqueleto._tubo(casca, pp, PackedFloat32Array([0.022, 0.016, 0.012]),
			PackedFloat32Array([TRONCO * 2.0, COPA * 0.5, COPA * 0.8]), 3, Color(0.86, 0.96, 0.62),
			0.0, 0.0, base.y, alto)
		# A lamina: o cartao da folha palmada, quase deitado, com o peciolo dela
		# (embaixo na celula) apontando para o caule.
		var tam := r.randf_range(1.3, 1.8)
		var frente := (fora * 0.25 + Vector3.UP).normalized().rotated(fora.cross(Vector3.UP).normalized(),
			-sobe * 0.35)
		var cima := fora
		var eixo_x := cima.cross(frente).normalized()
		var b := Basis(eixo_x, frente.cross(eixo_x).normalized(), frente)
		Vegetacao._cartao(folha, ponta + fora * tam * 0.35, b, Vector2(tam, tam), C_MAMAO_FOLHA, topo,
			Vector3(1.2, 0.6, 1.2), Color.WHITE, base.y, y_topo, 1.0)
	# Os mamoes: dois cartoes cruzados com o caule passando pelo meio.
	var meio := topo - Vector3(0.0, 0.5, 0.0)
	for k in 2:
		var bb := Basis(Vector3.UP, r.randf_range(0.0, PI) + PI * 0.5 * float(k))
		Vegetacao._cartao(folha, meio, bb, Vector2(0.55, 0.85), C_MAMAO_FRUTOS, meio,
			Vector3(0.3, 0.5, 0.3), Color.WHITE, base.y, y_topo, 1.0)
	ob.despejar(sup)


# --- miudezas ---------------------------------------------------------------------

## Planta em pe: `n` cartoes cruzados da `celula`, o pe (meio da borda de baixo
## da celula) no chao. A normal abre para fora do eixo e para cima: a touceira
## tem volume redondo, e nao duas placas acesas por igual.
static func em_pe(m: ParedeVazada.Malha, base: Vector3, alto: float, larg: float,
		celula: Vector2i, giro: float, n: int = 2, tinta: Color = Color.WHITE,
		cede_topo: float = COPA * 0.8) -> void:
	var uv := Vegetacao.uv_de(celula)
	for k in n:
		var dir := Vector3(cos(giro + PI * float(k) / float(n)), 0.0, sin(giro + PI * float(k) / float(n)))
		var face := dir.cross(Vector3.UP).normalized()
		var cantos: Array[Vector3] = [base - dir * larg * 0.5 - Vector3(0.0, 0.04, 0.0),
			base + dir * larg * 0.5 - Vector3(0.0, 0.04, 0.0),
			base + dir * larg * 0.5 + Vector3(0.0, alto, 0.0),
			base - dir * larg * 0.5 + Vector3(0.0, alto, 0.0)]
		var uvs: Array[Vector2] = [Vector2(uv.position.x, uv.end.y), uv.end,
			Vector2(uv.end.x, uv.position.y), uv.position]
		var ids: Array[int] = []
		for i in 4:
			var q := cantos[i]
			var sobe := clampf((q.y - base.y) / maxf(alto, 0.01), 0.0, 1.0)
			var lado := (q - base) * Vector3(1.0, 0.0, 1.0)
			var nrm := (lado.normalized() * 0.6 + Vector3.UP * (0.5 + 0.5 * sobe)).normalized()
			var luz := lerpf(0.7, 1.0, sobe)
			ids.append(m.vertice(q, nrm, uvs[i], Vector2.ZERO,
				Color(tinta.r * luz, tinta.g * luz, tinta.b * luz, cede_topo * sobe * sobe)))
		m.quad(ids[0], ids[1], ids[2], ids[3], face)
		m.quad(ids[0], ids[1], ids[2], ids[3], -face)


## Cartao deitado no chao (folha caida). Uma face so, para cima; sem vento.
static func deitado(m: ParedeVazada.Malha, centro: Vector3, lado: float, celula: Vector2i,
		giro: float, tinta: Color = Color.WHITE) -> void:
	var uv := Vegetacao.uv_de(celula)
	var bx := Vector3(cos(giro), 0.0, sin(giro)) * lado * 0.5
	var bz := Vector3(-sin(giro), 0.0, cos(giro)) * lado * 0.5
	var cantos: Array[Vector3] = [centro - bx - bz, centro + bx - bz, centro + bx + bz, centro - bx + bz]
	var uvs: Array[Vector2] = [Vector2(uv.position.x, uv.end.y), uv.end,
		Vector2(uv.end.x, uv.position.y), uv.position]
	var ids: Array[int] = []
	for i in 4:
		ids.append(m.vertice(cantos[i], Vector3.UP, uvs[i], Vector2.ZERO,
			Color(tinta.r, tinta.g, tinta.b, 0.0)))
	m.quad(ids[0], ids[1], ids[2], ids[3], Vector3.UP)
