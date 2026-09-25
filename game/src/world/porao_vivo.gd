## O porao que aparece na frente da casa de ladeira (PLANO_CASAS_AAA F5, porao
## progressivo; PLANO_BAR_E_CIDADE_AAA C5).
##
## Por que existe
## -------------
## Na ladeira o lote assenta no ponto alto da frente, e do lado de baixo a calcada
## desce: entre ela e o piso fica o embasamento de pedra (Relevo.embasamento). Com
## a calcada 1 a 3 m abaixo, era uma parede cega de pedra, e na rua comercial a
## ComercioVivo ainda pula a loja onde o chao desce mais de 75 cm. Casa de morro
## mineira nao e assim: o porao respira pela gateira, tem janela gradeada quando e
## alto, e porta de madeira no nivel da calcada quando da para ficar em pe dentro.
##
## Pela altura de pedra a vista sob cada ponto da frente:
##   >= 0,55 m  gateira: vao baixo com moldura de cantaria e tres barras
##   >= 1,70 m  janela de porao: vao gradeado com peitoril
##   >= 2,35 m  uma porta de porao por fachada, no ponto mais baixo, rente a calcada
## Os pontos sao os meios das janelas do terreo e, onde a parede e cega, um passo
## de 2,4 m. Porta, garagem, loja, portaria e a escada de encosto da porta ficam
## livres.
##
## Tudo e peca na frente do embasamento (10 cm a frente da fachada): a moldura sai
## 3 cm, o fundo escuro fica 1,2 cm a frente da pedra e dentro da moldura, e
## nenhuma face cai no plano de outra (tests/bancada_coplanar.gd).
class_name PoraoVivo
extends RefCounted

## `--sem-porao` desliga a frente (o par da bancada).
static var ativo := not OS.get_cmdline_user_args().has("--sem-porao")

const GATEIRA := 0.55
const JANELA := 1.7
const PORTA := 2.35
## Frente do embasamento, a partir do plano da fachada (Relevo.embasamento).
const FACE := 0.1
const SAI := 0.03
const MOLDURA := 0.07
const CANTARIA := Color("cfc8b8")
## O fundo do porao: escuro, mas nao preto, senao a grade some nele.
const ESCURO := Color("24211e")
## Ferro pintado e gasto: claro o bastante para ler contra o escuro de dentro.
const FERRO := Color("6c7072")
const MADEIRA := Color("6a4a32")
const PASSO := 2.4
## A face de tras (-Z local, contra a pedra) nunca aparece; a grade so mostra
## frente e lados. Cada gateira custava 96 triangulos, e o chunk de loja da
## ladeira ja passa do teto (verificar_lojas).
const SEM_COSTAS := PSXMesh.FACE_TODAS & ~PSXMesh.FACE_TRAS
const GRADE := PSXMesh.FACE_FRENTE | PSXMesh.FACE_DIR | PSXMesh.FACE_ESQ


## `centro` e o pe da fachada no meio da largura (o mesmo da ParedeVazada), no
## espaco do lote (a soleira em y = 0). `quadros` sao os vaos ja erguidos.
static func frente(ob: Obra, centro: Vector3, largura: float, direcao: int,
		plano: Dictionary, quadros: Array) -> void:
	if not ativo:
		return
	var perfil: PackedFloat32Array = plano.get("perfil", PackedFloat32Array())
	if perfil.size() < 2:
		return
	var menor := 0.0
	for p: float in perfil:
		menor = minf(menor, p)
	if -menor < GATEIRA:
		return
	var normal := KitModular._normal(direcao)
	var lateral := KitModular._lateral(direcao)
	var giro := atan2(normal.x, normal.z)
	var meia := largura * 0.5

	# O que chega ao chao no terreo fica livre: porta (com a escada de encosto,
	# que corre um degrau de 26 cm por 18 cm de altura), garagem, loja, portaria.
	var livres: Array[Vector2] = []
	var janelas: Array[float] = []
	for q: Dictionary in quadros:
		var r: Rect2 = q["rect"]
		if r.position.y >= KitModular.ALTURA_ANDAR - 0.2:
			continue
		if r.position.y < 0.6:
			var alto := maxf(0.0, -FachadaViva.chao_em(plano, r.get_center().x, largura))
			var escada := 0.4 + ceilf(alto / 0.18) * 0.26
			livres.append(Vector2(r.position.x - escada, r.end.x + escada))
		else:
			janelas.append(r.get_center().x)

	var pontos: Array[float] = []
	for x: float in janelas:
		pontos.append(x)
	var n := int(floor((largura - 1.6) / PASSO)) + 1
	for k in n:
		var x := -meia + 0.8 + (float(k) + 0.5) * (largura - 1.6) / float(n)
		var perto := false
		for p: float in pontos:
			if absf(p - x) < 1.3:
				perto = true
		if not perto:
			pontos.append(x)

	# A porta de porao vai no ponto mais baixo em que ela cabe.
	var x_porta := NAN
	var mais_alto := 0.0
	for x: float in pontos:
		var e := -FachadaViva.chao_em(plano, x, largura)
		if e >= PORTA and e > mais_alto and _cabe(x, 0.6, livres, meia):
			mais_alto = e
			x_porta = x

	for x: float in pontos:
		if not _cabe(x, 0.45, livres, meia):
			continue
		var chao := FachadaViva.chao_em(plano, x, largura)
		var e := -chao
		var pe := centro + lateral * x
		if x == x_porta:
			porta(ob, pe, chao, lateral, normal, giro)
		elif e >= JANELA:
			vao(ob, pe, lateral, normal, giro, Vector2(0.7, 0.5),
				minf(chao + 1.05, -0.95), 4, true)
		elif e >= GATEIRA:
			var alt := 0.24 if e < 0.9 else 0.3
			var y0 := clampf(chao + (e - alt) * 0.5, chao + 0.2, -0.3 - alt)
			vao(ob, pe, lateral, normal, giro, Vector2(0.44, alt), y0, 3, false)


static func _cabe(x: float, meia_larg: float, livres: Array[Vector2], meia: float) -> bool:
	if x - meia_larg < -meia + 0.3 or x + meia_larg > meia - 0.3:
		return false
	for l: Vector2 in livres:
		if x + meia_larg > l.x and x - meia_larg < l.y:
			return false
	return true


## Um vao de `tam` com o pe em `y0`: moldura de cantaria, fundo escuro e grade.
## `face` e a distancia de `pe` ate a pedra, ao longo de `normal` (na frente, o
## embasamento fica 10 cm a frente da fachada).
static func vao(ob: Obra, pe: Vector3, lateral: Vector3, normal: Vector3, giro: float,
		tam: Vector2, y0: float, barras: int, travessa: bool, face: float = FACE) -> void:
	var p := func(u: float, y: float, fora: float) -> Vector3:
		return pe + lateral * u + Vector3(0.0, y, 0.0) + normal * (face + fora)
	var w := tam.x
	var h := tam.y
	var m := MOLDURA
	# Verga e peitoril na largura toda; ombreiras entre eles.
	ob.caixa(&"concreto", p.call(0.0, y0 + h + m * 0.5, SAI * 0.5),
		Vector3(w + m * 2.0, m, SAI), CANTARIA, giro, SEM_COSTAS)
	ob.caixa(&"concreto", p.call(0.0, y0 - m * 0.5, SAI * 0.5 + 0.01),
		Vector3(w + m * 2.0 + 0.04, m, SAI + 0.02), CANTARIA.darkened(0.04), giro, SEM_COSTAS)
	for lado: float in [-1.0, 1.0]:
		ob.caixa(&"concreto", p.call(lado * (w + m) * 0.5, y0 + h * 0.5, SAI * 0.5),
			Vector3(m, h, SAI), CANTARIA, giro, SEM_COSTAS)
	# O escuro de dentro, 1,2 cm a frente da pedra e com as bordas na moldura.
	ob.parede(&"metal", p.call(0.0, y0 + h * 0.5, 0.012), Vector2(w + 0.04, h + 0.04), giro,
		ESCURO)
	for k in barras:
		var u := -w * 0.5 + (float(k) + 0.5) * w / float(barras)
		ob.caixa(JanelaViva._p(&"metal"), p.call(u, y0 + h * 0.5, SAI * 0.6),
			Vector3(0.016, h, 0.016), FERRO, giro, GRADE)
	if travessa:
		ob.caixa(JanelaViva._p(&"metal"), p.call(0.0, y0 + h * 0.5, SAI * 0.6 + 0.016),
			Vector3(w, 0.016, 0.016), FERRO, giro, PSXMesh.FACE_FRENTE | PSXMesh.FACE_TOPO
			| PSXMesh.FACE_BASE)


## Porta de madeira do porao, rente a calcada, com ombreira e verga de cantaria e
## a soleira de pedra.
static func porta(ob: Obra, pe: Vector3, chao: float, lateral: Vector3, normal: Vector3,
		giro: float, face: float = FACE) -> void:
	var p := func(u: float, y: float, fora: float) -> Vector3:
		return pe + lateral * u + Vector3(0.0, y, 0.0) + normal * (face + fora)
	var w := 0.9
	var h := 1.95
	var m := 0.12
	ob.caixa(&"concreto", p.call(0.0, chao + h + m * 0.5, 0.025),
		Vector3(w + m * 2.0, m, 0.05), CANTARIA, giro, SEM_COSTAS)
	for lado: float in [-1.0, 1.0]:
		ob.caixa(&"concreto", p.call(lado * (w + m) * 0.5, chao + h * 0.5, 0.025),
			Vector3(m, h, 0.05), CANTARIA, giro, SEM_COSTAS)
	ob.caixa(&"concreto", p.call(0.0, chao + 0.03, 0.08),
		Vector3(w + m * 2.0 + 0.1, 0.06, 0.16), CANTARIA.darkened(0.06), giro)
	# A folha, 1,2 cm a frente da pedra, e o ferrolho.
	ob.parede(&"porta", p.call(0.0, chao + h * 0.5 + 0.03, 0.012), Vector2(w, h - 0.06), giro,
		MADEIRA)
	ob.caixa(JanelaViva._p(&"metal"), p.call(w * 0.32, chao + 1.0, 0.03),
		Vector3(0.14, 0.03, 0.02), FERRO, giro)
