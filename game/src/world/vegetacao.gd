## A vegetacao da cidade: arvore de copa de cartao, palmeira, bananeira, bambu,
## arbusto, touceira e a mata de encosta.
##
## Por que existe
## -------------
## A arvore que havia (KitParque.arvore, KitEstrada.arvore) era tronco e cinco
## caixas de folha: de perto passava, de longe era um cubo verde, e a cidade
## tinha pouca — a calcada da avenida, uma rua de casas, tres no quintal. Cidade
## do interior de Minas vista do alto e metade copa: a mangueira do quintal
## passando do telhado, o ipe florido na praca, o coqueiro e a bananeira no
## fundo, o bambuzal na grota, a mata fechando o morro.
##
## Como a copa e feita
## -------------------
## Cartao: um quadrilatero com a silhueta de um ramo no alfa (atlas de
## tools/gerar_vegetacao.py, material `vegetacao`, recorte 0,5). A copa e um
## elipsoide coberto de cartoes virados para fora, cada um com as duas faces, e
## a normal de CADA vertice aponta do centro da copa para ele: a luz do sol cai
## redonda no volume, como numa arvore, e nao chapada em cada cartao. A cor de
## vertice escurece o baixo e o miolo (a sombra que a copa faz em si mesma), e
## tres cartoes escuros cruzados no meio tapam o ceu atras.
##
## O vento e o do shader (vento_forca do material, a mesma da casca): o alfa da
## cor de vertice e a rigidez, 0 preso e 1 solto, subindo com a altura como em
## PSXMesh.acumular_flexivel — o tronco e a copa cedem juntos, sem junta abrindo.
##
## Tudo em coordenada LOCAL do chunk; o sorteio vem do rng de quem planta.
## `--sem-vegetacao` volta a arvore de caixa onde ela havia (bancada).
class_name Vegetacao
extends RefCounted

const MAT := &"vegetacao"
const CASCA := KitEstrada.M_CASCA

## Materiais de folha. No MODERNO eles trocam o psx_surface_pixel pelo shader de
## folhagem (EstiloVisual), que tem luz atravessando a folha, recorte estavel de
## longe e o vento de tres camadas. No PS1 STYLE seguem no psx_surface.
const MATERIAIS_FOLHA: Array[StringName] = [&"vegetacao", &"folhagem",
	&"folhagem_recorte", &"arbusto", &"flor", &"mato", &"plantas"]
const SHADER_FOLHA := "res://shaders/psx_folha_pixel.gdshader"

static var ativo := not OS.get_cmdline_user_args().has("--sem-vegetacao")

## Celulas do atlas (coluna, linha), ver tools/gerar_vegetacao.py.
const C_MANGUEIRA := Vector2i(0, 0)
const C_MIUDO := Vector2i(1, 0)
const C_CLARO := Vector2i(2, 0)
const C_SECO := Vector2i(3, 0)
const C_IPE_AMARELO := Vector2i(0, 1)
const C_IPE_ROSA := Vector2i(1, 1)
const C_PRIMAVERA := Vector2i(2, 1)
const C_MATA := Vector2i(3, 1)
const C_PALMA := Vector2i(0, 2)
const C_BANANEIRA := Vector2i(1, 2)
const C_BAMBU := Vector2i(2, 2)
const C_ARBUSTO := Vector2i(3, 2)
const C_TOUCEIRA := Vector2i(0, 3)
const C_HERA := Vector2i(1, 3)
const C_FLOR := Vector2i(2, 3)
const C_SOMBRA := Vector2i(3, 3)

## Margem de cada celula que a UV nao pega (o desenho ja tem margem propria).
const _INSET := 0.004

## Especies de arvore: altura (min, max), fuste (fracao da altura em que a copa
## comeca), copa (raio horizontal e vertical, fracao da altura), cartoes, celula
## e o tamanho do cartao (fracao do raio).
const ESPECIES := {
	&"mangueira": {"alto": Vector2(7.0, 11.5), "fuste": 0.28, "copa": Vector2(0.5, 0.38),
		"cartoes": 30, "celula": C_MANGUEIRA, "cartao": 0.95, "tronco": 0.5},
	&"oiti": {"alto": Vector2(5.0, 7.5), "fuste": 0.34, "copa": Vector2(0.42, 0.34),
		"cartoes": 20, "celula": C_MIUDO, "cartao": 1.0, "tronco": 0.32},
	&"abacateiro": {"alto": Vector2(8.0, 12.5), "fuste": 0.3, "copa": Vector2(0.3, 0.4),
		"cartoes": 24, "celula": C_CLARO, "cartao": 1.0, "tronco": 0.36},
	&"jaqueira": {"alto": Vector2(9.0, 14.0), "fuste": 0.35, "copa": Vector2(0.36, 0.36),
		"cartoes": 26, "celula": C_MANGUEIRA, "cartao": 0.9, "tronco": 0.55},
	&"ipe_amarelo": {"alto": Vector2(6.0, 9.5), "fuste": 0.42, "copa": Vector2(0.4, 0.26),
		"cartoes": 18, "celula": C_IPE_AMARELO, "cartao": 0.8, "tronco": 0.3},
	&"ipe_rosa": {"alto": Vector2(6.0, 9.5), "fuste": 0.42, "copa": Vector2(0.4, 0.26),
		"cartoes": 18, "celula": C_IPE_ROSA, "cartao": 0.8, "tronco": 0.3},
	&"sibipiruna": {"alto": Vector2(8.0, 12.0), "fuste": 0.45, "copa": Vector2(0.55, 0.22),
		"cartoes": 24, "celula": C_MIUDO, "cartao": 0.85, "tronco": 0.4},
}

## Tom da casca por especie: o ipe e cinza liso, a mangueira escura e rachada.
const CASCAS := {&"ipe_amarelo": Color("8a8378"), &"ipe_rosa": Color("8a8378"),
	&"sibipiruna": Color("7c7466"), &"jaqueira": Color("5e5244")}


## A arvore de copa: tronco, dois ou tres galhos e a copa de cartao. Devolve o
## raio da copa. `colisao` recebe o tronco (vazio = sem colisao).
static func arvore(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		especie: StringName, porte: float, rng: RandomNumberGenerator) -> float:
	# A arvore por esqueleto (etapa 2 do PLANO_FLORA_AAA) gasta o mesmo sorteio
	# desta; `--arvore-caixa` volta esta aqui.
	if ArvoreEsqueleto.ativo:
		return ArvoreEsqueleto.arvore(sup, colisao, base, especie, porte, rng)
	var e: Dictionary = ESPECIES.get(especie, ESPECIES[&"oiti"])
	var alto_v: Vector2 = e["alto"]
	var altura := lerpf(alto_v.x, alto_v.y, clampf(porte, 0.0, 1.0))
	var copa_v: Vector2 = e["copa"]
	var raio := Vector3(copa_v.x, copa_v.y, copa_v.x) * altura \
		* Vector3(rng.randf_range(0.88, 1.12), rng.randf_range(0.9, 1.1), rng.randf_range(0.88, 1.12))
	var fuste := altura * float(e["fuste"])
	var tronco := float(e["tronco"]) * lerpf(0.7, 1.15, porte)
	var tom_casca: Color = CASCAS.get(especie, KitEstrada.CASCA_TOM)
	var y_topo := base.y + altura

	# Tronco em dois lances, o de cima um pouco torto; e os galhos que abrem para
	# a copa — sem eles a copa de cartao flutua em cima de um poste.
	var giro := rng.randf_range(0.0, TAU)
	var inclina := rng.randf_range(-0.06, 0.06)
	var desvio := Vector3(sin(giro) * inclina, 0.0, cos(giro) * inclina) * fuste
	KitModular.caixa_flex(sup, CASCA, base + Vector3(0.0, fuste * 0.3, 0.0),
		Vector3(tronco, fuste * 0.62, tronco), tom_casca, giro, base.y, y_topo, 0.0,
		KitEstrada.CEDE_TRONCO, PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, KitEstrada.QUAD_FOLHA)
	KitModular.caixa_flex(sup, CASCA, base + desvio * 0.5 + Vector3(0.0, fuste * 0.8, 0.0),
		Vector3(tronco * 0.78, fuste * 0.5, tronco * 0.78), tom_casca, giro + 0.6, base.y,
		y_topo, 0.0, KitEstrada.CEDE_TRONCO, PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE,
		KitEstrada.QUAD_FOLHA)
	var centro := base + desvio + Vector3(0.0, fuste + raio.y * 0.92, 0.0)
	var n_galhos := rng.randi_range(2, 4)
	for k in n_galhos:
		var a := giro + TAU * float(k) / float(n_galhos) + rng.randf_range(-0.4, 0.4)
		var fora := Vector3(cos(a), 0.0, sin(a))
		var de := base + desvio + Vector3(0.0, fuste * rng.randf_range(0.85, 1.0), 0.0)
		var ate := centro + fora * raio.x * 0.55 + Vector3(0.0, raio.y * rng.randf_range(-0.2, 0.3), 0.0)
		var eixo := ate - de
		var comp := eixo.length()
		var b := Basis(Quaternion(Vector3.UP, eixo.normalized()))
		KitModular.caixa_flex_inclinada(sup, CASCA, (de + ate) * 0.5,
			Vector3(tronco * 0.45, comp, tronco * 0.45), tom_casca, b, base.y, y_topo,
			0.0, KitEstrada.CEDE_TRONCO + 0.3, KitEstrada.QUAD_FOLHA)
	colisao.append({"tamanho": Vector3(tronco, fuste, tronco),
		"pos": base + Vector3(0.0, fuste * 0.5, 0.0)})

	var ob := Obra.new()
	var celula: Vector2i = e["celula"]
	var tinta := Color.WHITE.lerp(Color(0.86, 0.94, 0.8), rng.randf_range(0.0, 0.6))
	copa(ob, centro, raio, celula, int(e["cartoes"]), float(e["cartao"]), rng, base.y,
		y_topo, tinta, 0.1 if especie.begins_with("ipe") else 0.03)
	ob.despejar(sup)
	return maxf(raio.x, raio.z)


## A copa: um elipsoide de raio `raio` coberto de `n` cartoes da `celula`, com o
## miolo escuro. `seca` e a fracao de cartoes amarelados (a folha que cai no
## inverno seco de Minas; no ipe e a folha no meio da flor).
static func copa(ob: Obra, centro: Vector3, raio: Vector3, celula: Vector2i, n: int,
		tam: float, rng: RandomNumberGenerator, y_base: float, y_topo: float,
		tinta: Color = Color.WHITE, seca: float = 0.08) -> void:
	var m := ob.malha(MAT)
	var r_medio := (raio.x + raio.y + raio.z) / 3.0
	# O miolo: tres cartoes escuros cruzados, dois tercos do volume.
	for k in 3:
		var b := Basis(Vector3.UP, PI / 3.0 * float(k) + rng.randf_range(0.0, 0.5))
		_cartao(m, centro, b, Vector2(raio.x, raio.y) * 1.3, C_SOMBRA, centro, raio, tinta,
			y_base, y_topo, 0.88)
	# Os de fora, em espiral de Fibonacci sobre o elipsoide, sem o fundo reto.
	var ouro := PI * (3.0 - sqrt(5.0))
	# Mais cartoes e menores: poucos e grandes empilhavam em pratos.
	n = int(float(n) * 1.5)
	tam *= 0.8
	for k in n:
		var yy := 1.0 - (float(k) + 0.5) / float(n) * 1.75
		var rr := sqrt(maxf(0.0, 1.0 - yy * yy))
		var th := ouro * float(k) + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(th) * rr, yy, sin(th) * rr)
		var p := centro + dir * raio * rng.randf_range(0.62, 0.82)
		# O cartao olha para fora, girado em torno da propria normal, e inclinado
		# um pouco para cima: visto de baixo ele nao some de perfil.
		var fora := (dir + Vector3(0.0, 0.12, 0.0)).normalized()
		var b := Basis(Quaternion(Vector3.BACK, fora)) * Basis(Vector3.BACK, rng.randf() * TAU)
		var lado := r_medio * tam * rng.randf_range(0.85, 1.2)
		var cel := celula
		if rng.randf() < seca:
			cel = C_SECO if celula != C_IPE_AMARELO and celula != C_IPE_ROSA else C_MIUDO
		_cartao(m, p, b, Vector2(lado, lado), cel, centro, raio, tinta, y_base, y_topo, 1.0)


## Um cartao de duas faces com a normal de copa em cada vertice.
static func _cartao(m: ParedeVazada.Malha, p: Vector3, b: Basis, tam: Vector2,
		celula: Vector2i, centro: Vector3, raio: Vector3, tinta: Color, y_base: float,
		y_topo: float, luz: float) -> void:
	var bx := b.x * (tam.x * 0.5)
	var by := b.y * (tam.y * 0.5)
	var n := b.z
	var uv := uv_de(celula)
	var cantos: Array[Vector3] = [p - bx - by, p + bx - by, p + bx + by, p - bx + by]
	var uvs: Array[Vector2] = [uv.position + Vector2(0.0, uv.size.y), uv.end,
		uv.position + Vector2(uv.size.x, 0.0), uv.position]
	var ids: Array[int] = []
	for k in 4:
		var q := cantos[k]
		var rel := (q - centro) / Vector3(maxf(raio.x, 0.1), maxf(raio.y, 0.1), maxf(raio.z, 0.1))
		var normal := (rel.normalized() + Vector3(0.0, 0.25, 0.0)).normalized()
		# Sombra da propria copa: embaixo e no meio mais escuro.
		var ao := clampf(0.48 + 0.34 * (rel.y * 0.5 + 0.5) + 0.12 * minf(rel.length(), 1.0), 0.42, 0.92)
		ao *= luz
		var t := clampf((q.y - y_base) / maxf(y_topo - y_base, 0.1), 0.0, 1.0)
		var cede := KitEstrada.CEDE_COPA * lerpf(0.35, 1.0, t * t)
		ids.append(m.vertice(q, normal, uvs[k], Vector2.ZERO,
			Color(tinta.r * ao, tinta.g * ao, tinta.b * ao, cede)))
	m.quad(ids[0], ids[1], ids[2], ids[3], n)
	m.quad(ids[0], ids[1], ids[2], ids[3], -n)


## Retangulo da celula no atlas.
static func uv_de(celula: Vector2i) -> Rect2:
	return Rect2(Vector2(celula) * 0.25 + Vector2(_INSET, _INSET),
		Vector2(0.25 - _INSET * 2.0, 0.25 - _INSET * 2.0))


# --- palmeira, bananeira, bambu ---------------------------------------------------

## Palmeira: a imperial (reta, cinza, alta, com o palmito verde no alto) ou o
## coqueiro (torto, mais baixo). As folhas sao cartoes de palma pendurados do
## topo, arqueando para fora.
static func palmeira(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		imperial: bool, rng: RandomNumberGenerator) -> void:
	var altura := rng.randf_range(11.0, 16.0) if imperial else rng.randf_range(6.5, 9.5)
	var y_topo := base.y + altura + 2.0
	var lances := 5
	var giro := rng.randf_range(0.0, TAU)
	var curva := 0.0 if imperial else rng.randf_range(0.8, 1.8)
	if ArvoreEsqueleto.ativo:
		# Os mesmos sorteios, na mesma ordem, antes de construir (etapa 2).
		var n_e := rng.randi_range(11, 15)
		var comp_e := rng.randf_range(3.4, 4.4) if imperial else rng.randf_range(3.0, 3.8)
		var folhas := PackedVector3Array()
		for k in n_e:
			var a := TAU * float(k) / float(n_e) + rng.randf_range(-0.2, 0.2)
			var queda := rng.randf_range(-0.9, 0.35) if k % 3 != 0 else rng.randf_range(0.4, 0.8)
			folhas.append(Vector3(a, queda, rng.randf_range(-0.5, 0.5)))
		ArvoreEsqueleto.palmeira(sup, colisao, base, imperial, altura, giro, curva, folhas, comp_e)
		return
	var dir := Vector3(cos(giro), 0.0, sin(giro))
	var grosso := 0.42 if imperial else 0.3
	var tom := Color.WHITE if imperial else Color("b0a290")
	var casca := &"casca_palmeira" if imperial else CASCA
	var topo := base
	for k in lances:
		var t0 := float(k) / float(lances)
		var t1 := float(k + 1) / float(lances)
		var p0 := base + Vector3(0.0, altura * t0, 0.0) + dir * curva * t0 * t0
		var p1 := base + Vector3(0.0, altura * t1, 0.0) + dir * curva * t1 * t1
		var eixo := p1 - p0
		var b := Basis(Quaternion(Vector3.UP, eixo.normalized()))
		# A imperial engrossa no pe e afina no meio (a barriga do estipe).
		var g := grosso * (1.0 - 0.25 * t0) if imperial else grosso * (1.0 - 0.2 * t0)
		KitModular.caixa_flex_inclinada(sup, casca, (p0 + p1) * 0.5,
			Vector3(g, eixo.length() + 0.05, g), tom, b, base.y, y_topo, 0.0,
			KitEstrada.CEDE_TRONCO + 0.25)
		topo = p1
	if imperial:
		# O palmito: o verde liso entre o estipe cinza e a folha.
		KitModular.caixa_flex(sup, &"folhagem", topo + Vector3(0.0, 0.9, 0.0),
			Vector3(grosso * 0.85, 1.8, grosso * 0.85), Color(0.55, 0.72, 0.42), giro,
			base.y, y_topo, 0.3, 0.45, PSXMesh.FACE_TODAS, 4.0)
		topo += Vector3(0.0, 1.8, 0.0)
	colisao.append({"tamanho": Vector3(grosso, altura, grosso),
		"pos": base + Vector3(0.0, altura * 0.5, 0.0)})
	var ob := Obra.new()
	var m := ob.malha(MAT)
	var n := rng.randi_range(11, 15)
	var comp := rng.randf_range(3.4, 4.4) if imperial else rng.randf_range(3.0, 3.8)
	for k in n:
		var a := TAU * float(k) / float(n) + rng.randf_range(-0.2, 0.2)
		var fora := Vector3(cos(a), 0.0, sin(a))
		# Folha nova para cima, a velha pendendo.
		var queda := rng.randf_range(-0.9, 0.35) if k % 3 != 0 else rng.randf_range(0.4, 0.8)
		var eixo := (fora * cos(queda) + Vector3(0.0, sin(queda), 0.0)).normalized()
		var lado := fora.cross(Vector3.UP).normalized()
		# O cartao deitado: x ao longo da folha, a face quase para cima.
		var cima := eixo.cross(lado).normalized()
		if cima.y < 0.0:
			cima = -cima
		var giro_folha := rng.randf_range(-0.5, 0.5)
		var b := Basis(eixo, lado.rotated(eixo, giro_folha), cima.rotated(eixo, giro_folha))
		var centro := topo + eixo * comp * 0.46
		_cartao(m, centro, b, Vector2(comp, comp), C_PALMA, topo, Vector3(comp, comp * 0.5, comp),
			Color.WHITE, base.y, y_topo, 1.0)
	ob.despejar(sup)


## Touceira de bananeira: tres a cinco pes de caule verde e as folhas largas
## abertas em leque, rasgadas pelo vento.
static func bananeira(sup: Dictionary, base: Vector3, rng: RandomNumberGenerator) -> void:
	# Em 3D (Plantas, rodada 2 do PLANO_FLORA_AAA), com o mesmo sorteio gasto.
	if ArvoreEsqueleto.ativo:
		Plantas.bananeira(sup, base, rng)
		return
	var ob := Obra.new()
	var m := ob.malha(MAT)
	var pes := rng.randi_range(3, 5)
	var y_topo := base.y + 5.0
	for k in pes:
		var a := rng.randf_range(0.0, TAU)
		var p := base + Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.0, 0.9)
		var alto := rng.randf_range(1.6, 3.2)
		KitModular.caixa_flex(sup, &"folhagem", p + Vector3(0.0, alto * 0.5, 0.0),
			Vector3(0.22, alto, 0.22), Color(0.62, 0.66, 0.44), a, base.y, y_topo, 0.0,
			0.35, PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, 4.0)
		var topo := p + Vector3(0.0, alto, 0.0)
		for f in rng.randi_range(4, 7):
			var af := rng.randf_range(0.0, TAU)
			var fora := Vector3(cos(af), 0.0, sin(af))
			# A folha sobe e arqueia: de 25 a 70 graus acima da horizontal.
			var sobe := rng.randf_range(0.45, 1.2)
			var eixo := (fora * cos(sobe) + Vector3(0.0, sin(sobe), 0.0)).normalized()
			var lado := fora.cross(Vector3.UP).normalized().rotated(eixo, rng.randf_range(-0.6, 0.6))
			var frente := lado.cross(eixo).normalized()
			var comp := rng.randf_range(1.6, 2.4)
			var b := Basis(lado, eixo, frente)
			var cel := C_BANANEIRA if rng.randf() < 0.85 else C_SECO
			_cartao(m, topo + eixo * comp * 0.5, b, Vector2(comp * 0.75, comp), cel, topo,
				Vector3(2.0, 2.0, 2.0), Color.WHITE, base.y, y_topo, 1.0)
	ob.despejar(sup)


## Moita de bambu: quatro cartoes altos cruzados.
static func bambu(sup: Dictionary, base: Vector3, rng: RandomNumberGenerator) -> void:
	if ArvoreEsqueleto.ativo:
		Plantas.bambu(sup, base, rng)
		return
	var ob := Obra.new()
	var m := ob.malha(MAT)
	var alto := rng.randf_range(6.0, 9.0)
	var larg := alto * 0.7
	var centro := base + Vector3(0.0, alto * 0.5 - 0.1, 0.0)
	for k in 4:
		var b := Basis(Vector3.UP, PI * 0.25 * float(k) + rng.randf_range(0.0, 0.3))
		_cartao(m, centro, b, Vector2(larg, alto), C_BAMBU, centro,
			Vector3(larg * 0.5, alto * 0.5, larg * 0.5), Color.WHITE, base.y, base.y + alto, 1.0)
	ob.despejar(sup)


# --- miudos -------------------------------------------------------------------

## Arbusto sem tronco: uma copa baixa encostada no chao. `celula` e C_ARBUSTO,
## C_PRIMAVERA (a buganvilia) ou C_FLOR (o canteiro).
static func arbusto(ob: Obra, base: Vector3, tamanho: float, celula: Vector2i,
		rng: RandomNumberGenerator) -> void:
	var raio := Vector3(tamanho * 0.6, tamanho * 0.45, tamanho * 0.6)
	var centro := base + Vector3(0.0, raio.y * 0.8, 0.0)
	copa(ob, centro, raio, celula, rng.randi_range(6, 9), 1.15, rng, base.y,
		base.y + tamanho * 2.5, Color.WHITE, 0.05)


## Touceira de capim alto (colonião): dois cartoes em cruz.
static func touceira(ob: Obra, base: Vector3, alto: float, rng: RandomNumberGenerator) -> void:
	var m := ob.malha(MAT)
	var centro := base + Vector3(0.0, alto * 0.5 - 0.05, 0.0)
	var giro := rng.randf() * PI
	for k in 2:
		var b := Basis(Vector3.UP, giro + PI * 0.5 * float(k))
		_cartao(m, centro, b, Vector2(alto * 1.1, alto), C_TOUCEIRA, centro,
			Vector3(alto, alto, alto), Color.WHITE, base.y, base.y + alto * 1.6, 1.0)


## Um capao de mata, para a encosta: tres cartoes largos em estrela com a
## silhueta de cinco copas encostadas. De longe e o morro coberto; de perto,
## o pe dele fica atras do pasto.
static func mata(ob: Obra, base: Vector3, tamanho: float, rng: RandomNumberGenerator) -> void:
	var m := ob.malha(MAT)
	var alto := tamanho * rng.randf_range(0.8, 1.0)
	var centro := base + Vector3(0.0, alto * 0.42, 0.0)
	var raio := Vector3(tamanho * 0.5, alto * 0.5, tamanho * 0.5)
	var giro := rng.randf() * PI
	for k in 3:
		var b := Basis(Vector3.UP, giro + PI / 3.0 * float(k))
		_cartao(m, centro, b, Vector2(tamanho, alto), C_MATA, centro, raio,
			Color.WHITE.lerp(Color(0.9, 0.96, 0.84), rng.randf()), base.y, base.y + alto * 1.3, 1.0)
	# Um cartao deitado por cima: visto do alto do morro a mata nao e uma estrela.
	var deitado := Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.BACK, rng.randf() * TAU)
	_cartao(m, centro + Vector3(0.0, alto * 0.2, 0.0), deitado, Vector2(tamanho, tamanho) * 0.85,
		C_MANGUEIRA, centro, raio, Color(0.8, 0.86, 0.74), base.y, base.y + alto * 1.3, 1.0)


## Uma especie de arvore de quintal, pelo sorteio (a mangueira ganha).
static func especie_de_quintal(rng: RandomNumberGenerator) -> StringName:
	var r := rng.randf()
	if r < 0.36:
		return &"mangueira"
	if r < 0.54:
		return &"abacateiro"
	if r < 0.66:
		return &"jaqueira"
	if r < 0.78:
		return &"oiti"
	if r < 0.89:
		return &"ipe_amarelo"
	return &"ipe_rosa"
