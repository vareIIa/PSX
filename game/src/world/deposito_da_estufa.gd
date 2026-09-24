## O deposito da colheita: a pilha de sacos costurados, a vitrine de sacos
## abertos e os potes que ja nao cabem na prateleira.
##
## O que ele tem de contar
## -----------------------
## Quanto a estufa rendeu, e DE QUE. Tudo o que Jota e Helmer colhem sobe de
## elevador ate aqui na sacola, e a sacola vira saco de produto:
##
##   pilha     dois paletes com sacos de rafia COSTURADOS, cheios ate a orelha,
##             impressos com a variedade que tem dentro (o nome grande, o emblema
##             dela, ANDAR n — tools/gerar_estufa_sacos_rotulados.py). Empilhados
##             como em deposito de graos: quatro em pe no palete, dois deitados
##             por cima, atravessados, e um no topo cruzando os dois
##   vitrine   o terceiro palete, na ponta da bancada: oito sacos ABERTOS, um por
##             variedade, com a boca enrolada para fora e a erva amontoada — a
##             Morcega roxa, a Gambazona verde-limao, a Vagalume acesa. O monte
##             de cada um sobe e desce com o estoque dela, e uma plaquinha com o
##             nome esta espetada na erva. E de la que o jogador tira
##   potes     a erva comum vai para os potes: a prateleira, depois uma segunda
##             fila no tampo, depois caixotes de pote empilhados no chao
##
## A pilha sai do ESTOQUE (Plantio.colheitas), e nao de uma lista de enfeite; os
## sacos que os fazendeiros jogaram (Plantio.pilha) dizem so a ORDEM e o tamanho
## de cada um. Quem tira erva, pela vitrine ou pelo iWeed, ve o saco de cima da
## pilha murchar e sumir.
##
## Estatico e sem no: a Plantacao monta tudo isto na thread, como os vasos.
class_name DepositoDaEstufa
extends RefCounted

## Unidades de erva num saco cheio da pilha: a sacola de dez plantas.
const SACO := 30
const ALTURA_PALETE := 0.144
const PALETE := Vector2(1.2, 1.0)
const MAT_SACOS: StringName = &"estufa_sacos"

## Os tres paletes: centro no chao e giro. Os dois da pilha encostados na parede
## sul, a esquerda de quem desce a escada; a vitrine na ponta da bancada.
const PALETES: Array[Dictionary] = [
	{"centro": Vector3(2.35, 0.0, 0.62), "giro": 0.0},
	{"centro": Vector3(3.65, 0.0, 0.62), "giro": 0.0},
	{"centro": Vector3(2.55, 0.0, 2.78), "giro": PI * 0.5},
]
const PILHA := 2
const VITRINE := 2

## O saco costurado cheio: largura, espessura e altura (em pe).
const SACO_W := 0.56
const SACO_T := 0.4
const SACO_H := 0.78
## As vagas de um palete da pilha: (x, camada, z) do centro do palete. Camada 0
## em pe, 1 deitado ao comprido (em Z), 2 deitado atravessado (em X).
const VAGAS: Array[Vector3] = [
	Vector3(-0.29, 0.0, 0.22), Vector3(0.29, 0.0, 0.22),
	Vector3(-0.29, 0.0, -0.22), Vector3(0.29, 0.0, -0.22),
	Vector3(-0.29, 1.0, 0.0), Vector3(0.29, 1.0, 0.0),
	Vector3(0.0, 2.0, 0.0),
]
## Onde os deitados assentam: um pouco abaixo do alto da camada de baixo, porque
## saco pesado afunda na costura e no ombro do que esta embaixo.
const TOPO_0 := ALTURA_PALETE + SACO_H * 0.8
const TOPO_1 := TOPO_0 + SACO_T * 0.78 * 0.82

## Onde o fazendeiro para para jogar a sacola, e para onde olha: o corredor entre
## os paletes, de frente para a pilha da parede sul.
const PONTO := Vector3(2.45, 0.0, 1.68)
const OLHAR := Vector3(3.0, 0.8, 0.6)

## De onde a pilha e vista por quem entra: as frentes olham para ca.
const PLATEIA := Vector3(5.2, 0.0, 2.4)

## As celulas do atlas dos sacos (4 x 3 de 512 x 682 num 2048).
const CELULA_VERSO := 9
const CELULA_RAFIA := 10


static func celula(k: int) -> Rect2:
	var m := 1.0 / 2048.0
	return Rect2(float(k % 4) * 0.25 + m, floorf(float(k) / 4.0) * 682.0 / 2048.0 + m,
		0.25 - m * 2.0, 682.0 / 2048.0 - m * 2.0)


static func celula_da_frente(v: StringName) -> int:
	for andar in range(1, 10):
		if Variedades.do_andar(andar) == v:
			return andar - 1
	return 0


static func vagas() -> int:
	return PILHA * VAGAS.size()


# --- a conta ----------------------------------------------------------------

## Os sacos da pilha, em ordem de vaga: [{"v", "q"}].
##
## `pilha` e a ordem em que foram jogados (Plantio.pilha); `estoque`, quanto
## existe de cada variedade. Os mais antigos ficam cheios e o de cima e o que
## murcha quando a erva sai. O que existe e nao veio de sacola (a colheita do
## jogador, o trabalho feito com a estufa vazia) entra depois, em sacos de SACO.
## `ocultos`: os ultimos sacos da pilha ainda estao no ar, e nao desenham.
static func sacos(pilha: Array, estoque: Dictionary, ocultos: int) -> Array:
	var resto := {}
	for v: StringName in estoque:
		if v != &"comum":
			resto[v] = int(estoque[v])
	var saida: Array = []
	var visiveis := pilha.size() - ocultos
	for k in pilha.size():
		var e: Dictionary = pilha[k]
		var v := StringName(e["v"])
		var q := mini(int(e["q"]), int(resto.get(v, 0)))
		if q <= 0:
			continue
		resto[v] = int(resto[v]) - q
		if k < visiveis:
			saida.append({"v": v, "q": q})
	for andar in range(2, 2 + Variedades.ANDARES_DE_GALERIA):
		var v := Variedades.do_andar(andar)
		var q := int(resto.get(v, 0))
		while q > 0:
			var c := mini(q, SACO)
			saida.append({"v": v, "q": c})
			q -= c
	return saida


## A pilha sem os sacos que ja nao existem: cada entrada com o que o estoque
## ainda paga dela. Chamado antes de empilhar, para a lista nao crescer para
## sempre com saco vendido.
static func podada(pilha: Array, estoque: Dictionary) -> Array:
	var resto := {}
	for v: StringName in estoque:
		resto[v] = int(estoque[v])
	var saida: Array = []
	for e: Dictionary in pilha:
		var v := StringName(e["v"])
		var q := mini(int(e["q"]), int(resto.get(v, 0)))
		if q <= 0:
			continue
		resto[v] = int(resto[v]) - q
		saida.append({"v": String(v), "q": q})
	return saida


## As medidas do saco com `q` unidades: largura, espessura e altura. Meio vazio,
## ele afina e encolhe; a Gambazona (cinco por planta) estufa.
static func medidas(q: int) -> Vector3:
	var f := clampf(float(q) / float(SACO), 0.2, 1.6)
	return Vector3(SACO_W * (0.9 + 0.1 * sqrt(f)), SACO_T * (0.55 + 0.45 * minf(f, 1.35)),
		SACO_H * (0.72 + 0.28 * minf(f, 1.2)))


## As medidas na vaga: deitado, o saco espalha — mais largo e mais baixo.
static func medidas_na_vaga(k: int, q: int) -> Vector3:
	var m := medidas(q)
	if deitado(k):
		return Vector3(m.x * 1.08, m.y * 0.78, m.z)
	return m


static func deitado(k: int) -> bool:
	return int((VAGAS[mini(k, vagas() - 1) % VAGAS.size()] as Vector3).y) > 0


## O saco na vaga `k` com medidas `m`, na coordenada da plantacao: a origem e o
## meio do fundo do saco, +Y a altura dele e -Z a frente impressa.
static func lugar(k: int, m: Vector3) -> Transform3D:
	var k2 := mini(k, vagas() - 1)
	var pal: Dictionary = PALETES[k2 / VAGAS.size()]
	var vg: Vector3 = VAGAS[k2 % VAGAS.size()]
	var giro := float(pal["giro"])
	var bp := Basis(Vector3.UP, giro)
	var base: Vector3 = pal["centro"]
	var h := KitEstufa._h(k2, 17)
	var camada := int(vg.y)
	var jit := (h - 0.5) * 0.18
	if camada == 0:
		# Em pe, com a frente virada para quem entra, um pouco torto.
		var pe: Vector3 = base + bp * Vector3(vg.x, 0.0, vg.z) + Vector3(0.0, ALTURA_PALETE, 0.0)
		var olha := PLATEIA - pe
		olha.y = 0.0
		var yaw := atan2(-olha.x, -olha.z) + jit
		var tomba := Basis(Vector3.RIGHT, 0.04 * (h - 0.5))
		return Transform3D(Basis(Vector3.UP, yaw) * tomba, pe)
	# Deitados: a frente (-Z do saco) para cima. Na camada 1 o comprimento corre
	# em Z do palete; na 2, em X. A origem (o fundo) vai para uma ponta.
	var comp := Vector3(0.0, 0.0, 1.0) if camada == 1 else Vector3(1.0, 0.0, 0.0)
	var y := (TOPO_0 if camada == 1 else TOPO_1) + m.y * 0.5
	var eixo_y := bp * comp
	var eixo_z := Vector3.DOWN
	var eixo_x := eixo_y.cross(eixo_z)
	var b := Basis(eixo_x, eixo_y, eixo_z) * Basis(Vector3.FORWARD, jit)
	var centro: Vector3 = base + bp * Vector3(vg.x, 0.0, vg.z) + Vector3(0.0, y - m.y * 0.5 + m.y * 0.5, 0.0)
	var origem := centro - b.y * (m.z * 0.5)
	origem.y = y
	return Transform3D(b, origem)


## Para onde a sacola voa na vaga `k`, e com que tamanho chega: o centro do saco
## costurado e um raio que da o volume dele.
static func voo(k: int, q: int) -> Dictionary:
	var m := medidas_na_vaga(k, q)
	var t := lugar(k, m)
	var centro := t * Vector3(0.0, m.z * 0.5, 0.0)
	var b := t.basis * Basis.from_scale(Vector3(1.0, 1.25, 0.8))
	return {"lugar": Transform3D(b, centro), "raio": (m.x + m.y + m.z) / 6.0}


## A altura da colisao de cada palete: a pilha pelo numero de sacos, a vitrine
## fixa.
static func alturas(n: int) -> Array[float]:
	var saida: Array[float] = []
	for p in PALETES.size():
		if p == VITRINE:
			saida.append(ALTURA_PALETE + 0.4)
			continue
		var aqui := clampi(n - p * VAGAS.size(), 0, VAGAS.size())
		var alto := ALTURA_PALETE
		if aqui > 0:
			alto = TOPO_0
		if aqui > 4:
			alto = TOPO_1
		if aqui > 6:
			alto = TOPO_1 + SACO_T
		saida.append(alto)
	return saida


# --- o desenho --------------------------------------------------------------

## Na thread: a pilha e a vitrine. O que passa das vagas vai para o saco do
## topo, que estufa.
static func desenhar(sup: Dictionary, lista: Array, estoque: Dictionary) -> void:
	var n := mini(lista.size(), vagas())
	for k in n:
		var s: Dictionary = lista[k]
		var v := StringName(s["v"])
		var q := int(s["q"])
		if k == n - 1:
			for j in range(n, lista.size()):
				q += int((lista[j] as Dictionary)["q"])
		var m := medidas_na_vaga(k, q)
		var obra := {}
		saco_costurado(obra, m, v, 9001 + k * 131, deitado(k))
		KitEstufa._despejar_em(sup, obra, lugar(k, m))
	for i in Variedades.ANDARES_DE_GALERIA:
		var v := Variedades.do_andar(i + 2)
		var obra := {}
		saco_aberto(obra, v, int(estoque.get(v, 0)), 4400 + i * 37)
		KitEstufa._despejar_em(sup, obra, Transform3D(Basis(Vector3.UP,
			vitrine_giro(i)), vitrine_lugar(i)))


## O saco costurado: almofada de rafia em pe, com a boca costurada reta em cima
## e as duas orelhas nas pontas da costura, a barriga que a carga empurra e o
## fundo sentado. Frente (-Z) com a impressao da variedade, verso (+Z) com o
## COLHEITA DA CASA. Origem no meio do fundo.
static func saco_costurado(obra: Dictionary, m: Vector3, v: StringName, semente: int,
		deitado_: bool = false) -> void:
	var b := KitEstufa._balde(obra, MAT_SACOS)
	var tinta := Color.WHITE.lerp(Variedades.cor(v), 0.1)
	var nu := 12
	var nv := 11
	for lado in 2:
		var frente := lado == 0
		var r := celula(celula_da_frente(v) if frente else CELULA_VERSO)
		var pos: Array[Vector3] = []
		for j in nv + 1:
			var t := float(j) / float(nv)
			for i in nu + 1:
				var u := float(i) / float(nu)
				pos.append(_ponto_da_almofada(m, u, t, frente, semente, deitado_))
		var inicio := b.v.size()
		for j in nv + 1:
			for i in nu + 1:
				var p: Vector3 = pos[j * (nu + 1) + i]
				var du: Vector3 = pos[j * (nu + 1) + mini(i + 1, nu)] - pos[j * (nu + 1) + maxi(i - 1, 0)]
				var dv: Vector3 = pos[mini(j + 1, nv) * (nu + 1) + i] - pos[maxi(j - 1, 0) * (nu + 1) + i]
				var n := du.cross(dv).normalized()
				var fora := Vector3(p.x * 0.2, 0.0, p.z)
				if n.dot(fora) < 0.0:
					n = -n
				if n.length_squared() < 0.5:
					n = Vector3.FORWARD if frente else Vector3.BACK
				# A frente e lida por quem esta de frente: a direita dele e -X.
				var uu := float(i) / float(nu)
				var uv := KitEstufa._uv(r, uu, 1.0 - float(j) / float(nv))
				b.vert(p, n, uv, tinta)
		for j in nv:
			for i in nu:
				var i0 := inicio + j * (nu + 1) + i
				var i1 := i0 + nu + 1
				b.quad(i0, i0 + 1, i1 + 1, i1, b.n[i0] + b.n[i0 + 1] + b.n[i1] + b.n[i1 + 1])
	# O fundo, sentado: um leque no anel de baixo.
	var rf := celula(CELULA_RAFIA)
	var c0 := b.vert(Vector3(0.0, 0.0, 0.0), Vector3.DOWN, KitEstufa._uv(rf, 0.5, 0.5),
		tinta.darkened(0.3))
	var anel: Array[int] = []
	for i in 17:
		var a := TAU * float(i) / 16.0
		anel.append(b.vert(Vector3(cos(a) * m.x * 0.47, 0.004, sin(a) * m.y * 0.48),
			Vector3.DOWN, KitEstufa._uv(rf, 0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5),
			tinta.darkened(0.3)))
	for i in 16:
		b.tri(c0, anel[i], anel[i + 1], Vector3.DOWN)
	# A costura da boca: o cordao de linha de uma orelha a outra, e a etiqueta de
	# papelao na cor da variedade presa nela.
	var kb := KitEstufa._balde(obra, KitEstufa.MAT)
	var linha := PackedVector3Array()
	var raios := PackedFloat32Array()
	for i in 13:
		var u := float(i) / 12.0
		var p := _ponto_da_almofada(m, u, 1.0, true, semente, deitado_)
		linha.append(Vector3(p.x, p.y + 0.004, 0.0))
		raios.append(0.011)
	KitEstufa._tubo(kb, linha, raios, 4, KitEstufa._r(KitEstufa.R_SACO), Color(0.86, 0.8, 0.64))
	var canto := _ponto_da_almofada(m, 0.9, 1.0, true, semente, deitado_)
	var cor := Variedades.cor(v).lightened(0.2)
	KitEstufa._placa(kb, Transform3D(Basis(Vector3.RIGHT, 0.25) * Basis(Vector3.UP, 0.3),
		canto + Vector3(0.0, -0.06, -0.012)), Vector2(0.06, 0.085),
		KitEstufa._r(KitEstufa.R_ETIQUETA), cor, true, cor.darkened(0.2))


## Um ponto da almofada: `u` atravessa a face de uma orelha a outra (0 a 1),
## `t` sobe do fundo a costura. A secao e uma superelipse (retangulo de canto
## redondo) que engorda na barriga e fecha em linha na costura.
static func _ponto_da_almofada(m: Vector3, u: float, t: float, frente: bool,
		semente: int, deitado_: bool = false) -> Vector3:
	var W := m.x
	var T := m.y
	var H := m.z
	# Meia espessura: sentado embaixo, barriga no meio, fechado na costura. Deitado
	# nao ha fundo sentado: as duas pontas sao costura, e o meio e a barriga.
	# Em pe, o peso assenta embaixo: o fundo e a parte mais gorda do saco.
	var perfil := lerpf(1.05, 0.95, smoothstep(0.0, 0.5, t)) * (1.0 - 0.94 * smoothstep(0.52, 1.0, t))
	if deitado_:
		perfil = lerpf(0.3, 1.0, smoothstep(0.0, 0.35, t)) * (1.0 - 0.92 * smoothstep(0.6, 1.0, t))
	var b := T * 0.5 * perfil
	# A costura franze a boca: o saco estreita no alto, e nao abre em aba.
	var a := W * 0.5 * (0.95 + 0.07 * sin(PI * t) - 0.08 * smoothstep(0.7, 1.0, t))
	# u 0..1 atravessa meia volta da superelipse: de +X a -X pela frente (-Z),
	# que e a esquerda para a direita de quem olha a frente.
	var fi := PI * u
	var c := cos(fi)
	var s := sin(fi)
	var n := 0.8
	var x := a * signf(c) * pow(absf(c), n)
	var z := b * pow(absf(s), n)
	if frente:
		z = -z
	else:
		x = -x
	# A carga empelota a rafia; a costura cede no meio (o saco "senta" o ombro).
	var pel := (KitEstufa._h(semente, int(u * 12.0), int(t * 11.0)) - 0.5) * 0.018
	z += signf(z) * pel * smoothstep(0.05, 0.3, t) * (1.0 - smoothstep(0.8, 1.0, t))
	var y := H * t - 0.05 * H * sin(PI * u) * smoothstep(0.75, 1.0, t)
	# As orelhas: as pontas da costura sobem e saem para fora.
	var orelha := smoothstep(0.82, 1.0, t) * (1.0 - smoothstep(0.0, 0.12, minf(u, 1.0 - u)))
	x += signf(x) * 0.025 * orelha
	y += 0.025 * orelha
	if deitado_:
		# Deitado por cima dos outros, o meio cede: +Z do saco e o chao.
		z += 0.055 * sin(PI * t)
	return Vector3(x, y, z)


# --- a vitrine --------------------------------------------------------------

## As oito vagas da vitrine, no palete da ponta da bancada: duas fileiras de
## quatro, na ordem dos andares.
static func vitrine_lugar(i: int) -> Vector3:
	var pal: Dictionary = PALETES[VITRINE]
	var bp := Basis(Vector3.UP, float(pal["giro"]))
	var col := i % 4
	var fila := i / 4
	var local := Vector3(-0.45 + 0.3 * float(col), 0.0, -0.22 + 0.44 * float(fila))
	return (pal["centro"] as Vector3) + bp * local + Vector3(0.0, ALTURA_PALETE, 0.0)


static func vitrine_giro(i: int) -> float:
	var olha := PLATEIA - vitrine_lugar(i)
	return atan2(-olha.x, -olha.z) + (KitEstufa._h(i, 41) - 0.5) * 0.5


## Um saco aberto da vitrine: rafia com a boca enrolada para fora, e dentro o
## monte da variedade — tanto mais alto quanto mais estoque ela tem (cheio com
## tres sacos da pilha). Vazio, o saco murcha e mostra o fundo. A plaquinha com
## o nome, recortada da propria impressao do saco, fica espetada no monte.
static func saco_aberto(obra: Dictionary, v: StringName, estoque: int, semente: int) -> void:
	var b := KitEstufa._balde(obra, MAT_SACOS)
	var nivel := clampf(float(estoque) / float(SACO * 3), 0.0, 1.0)
	var R := 0.13
	var alto := 0.2 + 0.1 * nivel
	var tinta := Color.WHITE.lerp(Variedades.cor(v), 0.12)
	var rf := celula(CELULA_RAFIA)
	var perfil: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(R * 0.9, 0.005), Vector2(R * 1.02, alto * 0.35),
		Vector2(R * 1.0, alto * 0.8), Vector2(R * 1.04, alto), Vector2(R * 1.2, alto + 0.025),
		Vector2(R * 1.3, alto - 0.015), Vector2(R * 1.2, alto - 0.05), Vector2(R * 1.06, alto - 0.03),
		Vector2(R * 0.96, alto - 0.01), Vector2(R * 0.92, alto * 0.4),
	]
	var lados := 16
	var inicio := b.v.size()
	var aneis := perfil.size()
	for k in lados + 1:
		var ang := TAU * float(k) / float(lados)
		var d := Vector3(cos(ang), 0.0, sin(ang))
		var j := 1.0 + (KitEstufa._h(semente, k % lados) - 0.5) * 0.08
		for a in aneis:
			var p: Vector2 = perfil[a]
			var ant: Vector2 = perfil[maxi(a - 1, 0)]
			var prox: Vector2 = perfil[mini(a + 1, aneis - 1)]
			var tg := prox - ant
			var n2 := Vector2(tg.y, -tg.x).normalized() if tg.length_squared() > 1e-10 else Vector2.RIGHT
			var dentro := a >= 9
			var nrm := Vector3(d.x * n2.x, n2.y, d.z * n2.x)
			if dentro:
				nrm = -nrm
			var cor := tinta if not dentro else tinta.darkened(0.45)
			b.vert(Vector3(d.x * p.x * j, p.y, d.z * p.x * j), nrm,
				KitEstufa._uv(rf, float(k) / float(lados), float(a) / float(aneis - 1)), cor)
	for k in lados:
		for a in aneis - 1:
			var i0 := inicio + k * aneis + a
			var i1 := inicio + (k + 1) * aneis + a
			b.quad(i0, i1, i1 + 1, i0 + 1, b.n[i0] + b.n[i1] + b.n[i0 + 1] + b.n[i1 + 1])
	# O fundo de dentro: vazio, o saco mostra o pano, e nao o palete.
	KitEstufa._disco(b, Transform3D.IDENTITY, alto * 0.4, R * 0.93, lados, rf,
		tinta.darkened(0.55))

	# O monte: botoes da variedade numa cupula, mais alto quanto mais estoque.
	if estoque > 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = semente
		var brilha := v == &"vagalume"
		var bb := KitEstufa._balde(obra, KitEstufa.MAT_BRILHO if brilha else KitEstufa.MAT_FOLHA)
		var verde := KitEstufa._verde_de(v)
		var cor_b := Color(0.84, 0.97, 0.66) * verde
		cor_b.a = 1.0
		var r_bud := KitEstufa._r(KitEstufa.R_BUD_BRILHO if brilha else KitEstufa.R_BUD)
		var topo := lerpf(alto * 0.45, alto + 0.03, nivel)
		var qtd := 14 + int(26.0 * nivel)
		for k in qtd:
			var ang := rng.randf() * TAU
			var rr := sqrt(rng.randf()) * R * 0.9
			var cupula := (1.0 - (rr * rr) / (R * R)) * (0.05 + 0.06 * nivel)
			var c := Vector3(cos(ang) * rr, topo + cupula + rng.randf_range(-0.01, 0.01),
				sin(ang) * rr)
			var rb := rng.randf_range(0.024, 0.036)
			var eixo := (Vector3.UP + Vector3(rng.randf_range(-0.8, 0.8), 0.0,
				rng.randf_range(-0.8, 0.8))).normalized()
			KitEstufa._botao(bb, c, Vector3(rb, rb * 1.35, rb), KitEstufa._base_do_eixo(eixo)
				* Basis(Vector3.UP, rng.randf() * TAU), 5, 2, rng, cor_b, r_bud)
		# Folhinha de acucar solta por cima.
		var r_acu := KitEstufa._r(KitEstufa.R_ACUCAR)
		var cor_acu := Color(0.95, 1.0, 0.88) * verde
		cor_acu.a = 1.0
		for k in 4:
			var ang := rng.randf() * TAU
			var saida := Vector3(cos(ang), 0.0, sin(ang))
			var p0 := saida * R * 0.5 + Vector3.UP * (topo + 0.05 * nivel + 0.02)
			var d := (saida + Vector3.UP * 0.5).normalized()
			KitEstufa._foliolo(bb, p0, d, d.cross(Vector3.UP).normalized(), Vector3.UP, 0.06,
				0.02, 0.15, r_acu, cor_acu, cor_acu.darkened(0.15), 0.25)

	# A plaquinha: o nome recortado da impressao do saco, num palito espetado.
	var kb := KitEstufa._balde(obra, KitEstufa.MAT)
	var fixo := Vector3(R * 0.35, 0.0, R * 0.2)
	var alto_placa := alto + 0.1 + 0.05 * nivel
	KitEstufa._caixa(kb, Transform3D(Basis(), fixo + Vector3(0.0, alto_placa * 0.5, 0.0)),
		Vector3(0.008, alto_placa, 0.008), KitEstufa._r(KitEstufa.R_MADEIRA),
		Color(0.9, 0.8, 0.6))
	var r := celula(celula_da_frente(v))
	var nome := Rect2(r.position + Vector2(r.size.x * 0.06, r.size.y * 0.55),
		Vector2(r.size.x * 0.88, r.size.y * 0.14))
	KitEstufa._placa(b, Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, 0.12),
		fixo + Vector3(0.0, alto_placa + 0.02, -0.004)), Vector2(0.2, 0.06), nome, Color.WHITE,
		true, Color.WHITE)


# --- os potes ---------------------------------------------------------------

## Os caixotes de pote, empilhados no chao na ponta norte da bancada.
const CAIXOTE_POTES := Vector3(0.95, 0.0, 3.45)
const CAIXOTE_TAM := Vector3(0.52, 0.26, 0.36)
const CAIXOTES := 3
const POTES_POR_CAIXOTE := 6
## A segunda fila do tampo, na frente da primeira.
const SEGUNDA_FILA := 5


## Os lugares de pote alem da prateleira: a segunda fila no tampo (na metade
## norte, longe da balanca) e seis por caixote. `potes`: a prateleira (Plantacao).
static func vagas_de_pote(potes: Array) -> Array[Vector3]:
	var saida: Array[Vector3] = []
	if potes.size() < SEGUNDA_FILA:
		return saida
	for k in range(potes.size() - SEGUNDA_FILA, potes.size()):
		saida.append((potes[k] as Vector3) + Vector3(0.27, 0.0, 0.0))
	for c in CAIXOTES:
		var fundo := CAIXOTE_POTES + Vector3(0.0, CAIXOTE_TAM.y * float(c) + 0.03, 0.0)
		for k in POTES_POR_CAIXOTE:
			saida.append(fundo + Vector3(-0.15 + 0.15 * float(k % 3), 0.0,
				-0.085 + 0.17 * float(k / 3)))
	return saida


## Na thread: os caixotes que ja tem pote (um caixote so aparece quando o
## primeiro pote dele existe) e os potes extras, `cheios` e o parcial.
static func desenhar_potes_extras(sup: Dictionary, potes: Array, extras: int,
		parcial: float) -> void:
	var vagas_p := vagas_de_pote(potes)
	var total := mini(extras + (1 if parcial > 0.06 else 0), vagas_p.size())
	for k in total:
		var cheio := 1.0 if k < extras else parcial
		KitEstufa.pote(sup, vagas_p[k], cheio, PI * 0.5 + sin(float(k) * 1.7) * 0.4)
	var em_caixote := total - SEGUNDA_FILA
	for c in CAIXOTES:
		if em_caixote <= c * POTES_POR_CAIXOTE:
			break
		_caixote(sup, CAIXOTE_POTES + Vector3(0.0, CAIXOTE_TAM.y * float(c), 0.0), c)


## Caixote de feira: fundo, quatro paredes de ripa com fresta.
static func _caixote(sup: Dictionary, base: Vector3, k: int) -> void:
	var t := CAIXOTE_TAM
	var madeira := Color(0.92, 0.8, 0.62) * (0.92 + 0.08 * float(k % 2))
	madeira.a = 1.0
	var giro := (KitEstufa._h(k, 5) - 0.5) * 0.12
	var b := Basis(Vector3.UP, giro)
	AtlasKit.caixa(sup, EstufaBuilder.MAT, base + Vector3(0.0, 0.012, 0.0),
		Vector3(t.x, 0.024, t.z), EstufaBuilder.C_MADEIRA, madeira, giro)
	for ripa in 2:
		var y := 0.06 + float(ripa) * 0.12
		for lado: float in [-1.0, 1.0]:
			AtlasKit.caixa(sup, EstufaBuilder.MAT, base + b * Vector3(0.0, y, lado * (t.z * 0.5 - 0.01)),
				Vector3(t.x, 0.08, 0.018), EstufaBuilder.C_MADEIRA, madeira, giro)
			AtlasKit.caixa(sup, EstufaBuilder.MAT, base + b * Vector3(lado * (t.x * 0.5 - 0.01), y, 0.0),
				Vector3(0.018, 0.08, t.z), EstufaBuilder.C_MADEIRA, madeira, giro)
	# Os quatro cantos, que seguram as ripas.
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			AtlasKit.caixa(sup, EstufaBuilder.MAT,
				base + b * Vector3(cx * (t.x * 0.5 - 0.03), t.y * 0.5, cz * (t.z * 0.5 - 0.03)),
				Vector3(0.04, t.y, 0.04), EstufaBuilder.C_MADEIRA, madeira.darkened(0.1), giro)


# --- os paletes (geometria fixa do comodo) ---------------------------------

## O palete de madeira: cinco tabuas no tampo, tres travessas, nove tacos e tres
## tabuas embaixo. Vai no EstufaBuilder, com a colisao baixa; a pilha em cima
## tem colisao propria, na Plantacao, que cresce com ela.
static func paletes(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	for p: Dictionary in PALETES:
		var c: Vector3 = p["centro"]
		var giro := float(p["giro"])
		var b := Basis(Vector3.UP, giro)
		var pinho := Color(0.94, 0.8, 0.6)
		for k in 5:
			var z := -PALETE.y * 0.5 + 0.07 + float(k) * (PALETE.y - 0.14) / 4.0
			AtlasKit.caixa(sup, EstufaBuilder.MAT, c + b * Vector3(0.0, ALTURA_PALETE - 0.011, z),
				Vector3(PALETE.x, 0.022, 0.1), EstufaBuilder.C_MADEIRA,
				pinho * (0.9 + 0.1 * float(k % 2)), giro)
		for k in 3:
			var z := -PALETE.y * 0.5 + 0.05 + float(k) * (PALETE.y - 0.1) / 2.0
			AtlasKit.caixa(sup, EstufaBuilder.MAT, c + b * Vector3(0.0, 0.1, z),
				Vector3(PALETE.x, 0.022, 0.1), EstufaBuilder.C_MADEIRA, pinho.darkened(0.12), giro)
			AtlasKit.caixa(sup, EstufaBuilder.MAT, c + b * Vector3(0.0, 0.011, z),
				Vector3(PALETE.x, 0.022, 0.1), EstufaBuilder.C_MADEIRA, pinho.darkened(0.2), giro)
			for x: float in [-PALETE.x * 0.5 + 0.05, 0.0, PALETE.x * 0.5 - 0.05]:
				AtlasKit.caixa(sup, EstufaBuilder.MAT, c + b * Vector3(x, 0.056, z),
					Vector3(0.1, 0.068, 0.1), EstufaBuilder.C_MADEIRA, pinho.darkened(0.3), giro)
		var tam := b * Vector3(PALETE.x, 0.0, PALETE.y)
		colisao.append({"tamanho": Vector3(absf(tam.x), ALTURA_PALETE, absf(tam.z)),
			"pos": c + Vector3(0.0, ALTURA_PALETE * 0.5, 0.0)})
