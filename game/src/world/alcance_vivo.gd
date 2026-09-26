## A vida do braco direito do motorista da estrada no susto, do aro ao chao do
## carona e de volta a leitura: o ombro que avanca e desce atras da mao, o
## cotovelo que gira, o punho que atrasa e assenta, o tremor de medo, as tentativas
## de alcancar o celular caido e o peso dele saindo do chao.
##
## Por que existe
## --------------
## Medido na rodada de base (25/09, `diag_pegar_celular.gd --diag-denso=15.5:23.4`),
## o braco se mexia como um boneco de corda:
## - o ombro preso a lente: do chao ate a pinca ficou no mesmo lugar em relacao a ela
##   (0,8 cm de desvio em 1,8 s). Nao avancava nem descia para o alcance, e na ida a
##   mao chegava ao chao com o ombro parado, o braco de cima esticando 37 cm;
## - o braco reto de ponta a ponta: o ombro a 98 cm do punho, o cotovelo em 175 graus
##   o tempo todo no chao e na pinca, girando -105 graus e parado. Uma vara presa num
##   ponto fixo;
## - a mao no chao so fazia dois senos (os picos do espectro em 1,1 e 1,6 Hz), e o
##   tremor eram cinco senos (riscas em 13 e 15 Hz);
## - a pinca em tres idas de smoothstep (anda, para, anda, para, anda), e com o
##   aparelho na mao o tremor ia a zero, erguendo inclusive;
## - o erguer, uma curva so, saindo do chao a 2 m/s no primeiro quadro, sem peso.
##
## O que ha aqui: ruido liso (no lugar dos senos), molas amortecidas (o ombro, o
## giro do cotovelo, o atraso do punho, o balanco do aparelho), uma curva monotona
## que passa pelos pontos sem parar neles, as tentativas no chao e as contas do ombro
## no alcance. Quem monta o braco continua sendo a `MotoristaCena`.
##
## Carregado pelo caminho, sem `class_name`.
extends RefCounted


# --- ruido ---------------------------------------------------------------------

static func _h(i: float, s: float) -> float:
	return fposmod(sin(i * 127.1 + s * 311.7) * 43758.5453, 1.0) * 2.0 - 1.0


## Ruido de gradiente numa dimensao: liso, de -1 a 1, sem periodo e sem risca no
## espectro. O tremor de gente e isso, e nao uma soma de senos, que o olho le como
## motor ligado.
static func ruido(x: float, s: float = 0.0) -> float:
	var i := floorf(x)
	var f := x - i
	var u := f * f * f * (f * (f * 6.0 - 15.0) + 10.0)
	return lerpf(_h(i, s) * f, _h(i + 1.0, s) * (f - 1.0), u) * 2.0


static func ruido3(x: float, s: float) -> Vector3:
	return Vector3(ruido(x, s), ruido(x, s + 17.31), ruido(x, s + 41.97))


## Tres oitavas do `ruido3`.
static func fractal3(x: float, s: float) -> Vector3:
	return ruido3(x, s) * 0.62 + ruido3(x * 2.13 + 5.1, s + 3.3) * 0.28 \
		+ ruido3(x * 4.37 + 9.7, s + 7.7) * 0.10


# --- molas ---------------------------------------------------------------------

## Uma mola amortecida num vetor: `hz` a frequencia natural e `amort` a razao de
## amortecimento (1 chega sem passar; abaixo disso passa um pouco e volta, que e o
## assentar de um membro de verdade). Passo semi-implicito em fatias de 1/240 s.
class Mola:
	var x := Vector3.ZERO
	var v := Vector3.ZERO
	var hz: float = 3.0
	var amort: float = 0.7

	func _init(f: float = 3.0, z: float = 0.7) -> void:
		hz = f
		amort = z

	func pular(p: Vector3) -> void:
		x = p
		v = Vector3.ZERO

	func passo(alvo: Vector3, dt: float) -> Vector3:
		if dt <= 0.0:
			return x
		var t := minf(dt, 0.1)
		var w := TAU * hz
		var n := maxi(1, ceili(t * 240.0))
		var h := t / float(n)
		for _i in n:
			v += (-2.0 * amort * w * v - w * w * (x - alvo)) * h
			x += v * h
		return x


## A mesma mola num numero.
class MolaF:
	var x: float = 0.0
	var v: float = 0.0
	var hz: float = 3.0
	var amort: float = 0.7

	func _init(f: float = 3.0, z: float = 0.7) -> void:
		hz = f
		amort = z

	func pular(p: float) -> void:
		x = p
		v = 0.0

	func passo(alvo: float, dt: float) -> float:
		if dt <= 0.0:
			return x
		var t := minf(dt, 0.1)
		var w := TAU * hz
		var n := maxi(1, ceili(t * 240.0))
		var h := t / float(n)
		for _i in n:
			v += (-2.0 * amort * w * v - w * w * (x - alvo)) * h
			x += v * h
		return x


# --- curvas --------------------------------------------------------------------

## Uma curva monotona pelos pontos (`xs` crescentes, `ys` sem descer), lisa (C1),
## parada nas duas pontas e passando pelos pontos do meio SEM parar neles
## (Fritsch-Carlson). E o que troca uma fila de smoothsteps, que para em cada
## ponto: a mao de gente desacelera numa passagem, mas nao estaciona nela.
static func curva(xs: PackedFloat32Array, ys: PackedFloat32Array, x: float) -> float:
	var n := xs.size()
	if n == 0:
		return 0.0
	if x <= xs[0]:
		return ys[0]
	if x >= xs[n - 1]:
		return ys[n - 1]
	var d := PackedFloat32Array()
	d.resize(n - 1)
	for k in n - 1:
		d[k] = (ys[k + 1] - ys[k]) / maxf(xs[k + 1] - xs[k], 1e-6)
	var m := PackedFloat32Array()
	m.resize(n)
	m[0] = 0.0
	m[n - 1] = 0.0
	for k in range(1, n - 1):
		m[k] = 0.0 if d[k - 1] * d[k] <= 0.0 else (d[k - 1] + d[k]) * 0.5
	for k in n - 1:
		if absf(d[k]) < 1e-9:
			m[k] = 0.0
			m[k + 1] = 0.0
			continue
		var a := m[k] / d[k]
		var b := m[k + 1] / d[k]
		var s := a * a + b * b
		if s > 9.0:
			var t := 3.0 / sqrt(s)
			m[k] = t * a * d[k]
			m[k + 1] = t * b * d[k]
	var i := 0
	while i < n - 2 and x > xs[i + 1]:
		i += 1
	var h := xs[i + 1] - xs[i]
	var u := (x - xs[i]) / maxf(h, 1e-6)
	var u2 := u * u
	var u3 := u2 * u
	return (2.0 * u3 - 3.0 * u2 + 1.0) * ys[i] + (u3 - 2.0 * u2 + u) * h * m[i] \
		+ (-2.0 * u3 + 3.0 * u2) * ys[i + 1] + (u3 - u2) * h * m[i + 1]


## Sai depressa e chega devagar, parada nas duas pontas: 1 - (1-k)^3 (1+3k). O
## smoothstep e simetrico, e gente que estica o braco atras de alguma coisa sai de
## uma vez e freia chegando.
static func arranque(k: float) -> float:
	var c := clampf(k, 0.0, 1.0)
	var r := 1.0 - c
	return 1.0 - r * r * r * (1.0 + 3.0 * c)


# --- as tentativas no chao -------------------------------------------------------

## As tentativas de alcancar o celular caido, contadas da chegada da mao ao chao
## (s): comeco, subida, esforco no alto, volta, quanto estica (0 a 1) e quanto os
## dedos fecham no ar (0 a 1). Ritmo desigual de proposito: quem tem medo nao puxa
## em compasso. A terceira e a que quase pega (os dedos fecham na borda do
## aparelho), e acaba antes da pinca (a cena a chama 1,83 s depois da chegada): a
## mao sai para pegar de verdade da volta dela.
const TENTATIVAS := [
	[-0.18, 0.30, 0.10, 0.34, 0.62, 0.40],
	[0.52, 0.20, 0.18, 0.30, 0.84, 0.70],
	[1.08, 0.22, 0.24, 0.24, 1.00, 1.00],
	[1.86, 0.21, 0.30, 0.30, 0.92, 0.85],
]
## Alem da tabela (a cena demorou a pinca), uma tentativa a cada tanto (s).
const TENTATIVA_DEPOIS := 0.74
## Os dedos fecham depois de a mao chegar no alto (s): a ponta da cadeia e a
## ultima a mexer.
const DEDOS_ATRASAM := 0.09
## A antecipacao: antes de cada tentativa a mao recolhe um nada (fracao do
## estirao) e so entao vai (s).
const ANTECIPA := 0.12
const ANTECIPA_T := 0.12


## Um pulso de tentativa em `u` segundos do comeco: sobe de arranque, segura
## forcando um pouco mais, volta.
static func _pulso(u: float, sobe: float, segura: float, desce: float) -> float:
	if u <= 0.0:
		return 0.0
	if u < sobe:
		return arranque(u / sobe)
	u -= sobe
	if u < segura:
		return 1.0 + 0.05 * (u / segura)
	u -= segura
	if u < desce:
		return 1.05 * (1.0 - smoothstep(0.0, 1.0, u / desce))
	return 0.0


## O que as tentativas pedem em `tc`: `a` quanto a mao estica (0 recolhida pelo
## cinto, 1 no alto), `garra` quanto os dedos fecham, `forca` o esforco (sobe no
## alto de cada uma).
static func tentativa(tc: float) -> Dictionary:
	var a := 0.0
	var antes := 0.0
	var garra := 0.0
	var forca := 0.0
	var linhas: Array = TENTATIVAS.duplicate()
	var ultima: Array = TENTATIVAS[TENTATIVAS.size() - 1]
	var fim: float = float(ultima[0]) + float(ultima[1]) + float(ultima[2]) + float(ultima[3])
	if tc > fim - 0.6:
		var n := int((tc - float(ultima[0])) / TENTATIVA_DEPOIS) + 1
		for j in range(1, n + 1):
			var jit := ruido(float(j) * 0.71, 5.3) * 0.08
			linhas.append([float(ultima[0]) + TENTATIVA_DEPOIS * float(j) + jit, 0.21, 0.26,
				0.28, 0.9 + 0.08 * ruido(float(j), 2.2), 0.85])
	for l: Array in linhas:
		var u := tc - float(l[0])
		var sobe: float = l[1]
		var segura: float = l[2]
		var desce: float = l[3]
		if u > -ANTECIPA_T and u <= 0.0:
			antes = minf(antes, -ANTECIPA * sin(PI * (u + ANTECIPA_T) / ANTECIPA_T))
		if u <= 0.0 or u > sobe + segura + desce + DEDOS_ATRASAM + 0.3:
			continue
		a = maxf(a, _pulso(u, sobe, segura, desce) * float(l[4]))
		# Os dedos fecham com atraso e abrem na volta, um pouco antes do braco.
		garra = maxf(garra, _pulso(u - DEDOS_ATRASAM, sobe * 0.8, segura * 0.9, desce * 0.7)
			* float(l[5]))
		var alto := smoothstep(sobe * 0.6, sobe, u) * (1.0 - smoothstep(sobe + segura,
			sobe + segura + desce * 0.5, u))
		forca = maxf(forca, alto * float(l[4]))
	return {"a": a + antes, "garra": garra, "forca": forca}


# --- o ombro -----------------------------------------------------------------------

## O ombro no alcance: quanto avanca para o lado do alvo (a escapula corre para a
## frente no gradil) e quanto desce (o tronco dobra para o lado do braco que
## estica), com o alcance todo; e o tanto a mais que cada tentativa empurra contra o
## cinto (m).
## (Descendo 4,5 cm, o braco de cima encostava na quina do assento do carona na
## chegada da ida e no comeco do erguer: 0,3 e 1,3 cm.)
const OMBRO_AVANCA := 0.075
const OMBRO_DESCE := 0.03
const OMBRO_EMPURRA := 0.03
const OMBRO_EMPURRA_DESCE := 0.012
## O corpo nunca fica parado: a respiracao presa e o equilibrio no cinto (m).
const OMBRO_BALANCA := 0.006


## Quanto o ombro sai do lugar de repouso (`ombro`, o da `MotoristaCena._ombro`)
## para o alcance do `alvo` (o aparelho): `quanto` de 0 a 1 o alcance pedido, e
## `empurra` a tentativa de agora.
static func ombro_no_alcance(ombro: Vector3, alvo: Vector3, quanto: float,
		empurra: float, t: float) -> Vector3:
	var para := alvo - ombro
	para.y = 0.0
	var frente := para.normalized() if para.length_squared() > 1e-6 else Vector3.ZERO
	var desloca := frente * (OMBRO_AVANCA * quanto + OMBRO_EMPURRA * empurra) \
		+ Vector3.DOWN * (OMBRO_DESCE * quanto + OMBRO_EMPURRA_DESCE * empurra)
	return desloca + fractal3(t * 0.45, 61.0) * OMBRO_BALANCA * (0.4 + quanto)


# --- a mao ---------------------------------------------------------------------------

## O atraso do punho: a mao que anda deixa os dedos para tras, girando no punho,
## tanto mais quanto mais depressa (rad por m/s, e o teto).
const PUNHO_ARRASTA := 0.11
const PUNHO_ARRASTA_MAX := 0.20


## O giro do atraso do punho (vetor de rotacao) para a mao de dedos `d` andando a
## `vel` (m/s).
static func arrasto_do_punho(d: Vector3, vel: Vector3) -> Vector3:
	var ao_lado := vel - d * vel.dot(d)
	var rapido := ao_lado.length()
	if rapido < 1e-4:
		return Vector3.ZERO
	var eixo := d.cross(-ao_lado / rapido)
	if eixo.length_squared() < 1e-8:
		return Vector3.ZERO
	return eixo.normalized() * minf(rapido * PUNHO_ARRASTA, PUNHO_ARRASTA_MAX)


## Gira a pegada `p` em volta do ponto `pivo` pelo vetor de rotacao `r`.
static func girar_pegada(p: Dictionary, pivo: Vector3, r: Vector3) -> Dictionary:
	var ang := r.length()
	if ang < 1e-6:
		return p
	var b := Basis(r / ang, ang)
	var q := p.duplicate()
	q["o"] = pivo + b * ((p["o"] as Vector3) - pivo)
	q["d"] = (b * (p["d"] as Vector3)).normalized()
	q["dorso"] = (b * (p["dorso"] as Vector3)).normalized()
	return q


## O tremor de medo na mao solta: o fino (8-14 Hz, o que a adrenalina faz) e o
## lento (a mao procurando, 1 Hz), em metros; o do punho em radianos.
const TREME_FINO := 0.0009
const TREME_FINO_FORCA := 0.0016
const TREME_LENTO := 0.0025
const TREME_LENTO_FORCA := 0.004
const TREME_GIRO := 0.012
const TREME_GIRO_FORCA := 0.022
## Os dedos, cada um por si (graus).
const DEDOS_TREMEM := 2.0
const DEDOS_TREMEM_FORCA := 4.5


## O deslocamento do tremor em `t` (m), com `medo` e `forca` de 0 a 1.
static func tremor(t: float, medo: float, forca: float, semente: float) -> Vector3:
	var fino := fractal3(t * 11.0, semente) * (TREME_FINO * medo + TREME_FINO_FORCA * forca)
	var lento := fractal3(t * 1.1, semente + 29.0) * (TREME_LENTO * medo
		+ TREME_LENTO_FORCA * forca)
	return fino + lento


## O giro do tremor no punho em `t` (vetor de rotacao, rad).
static func tremor_do_punho(t: float, medo: float, forca: float, semente: float) -> Vector3:
	return fractal3(t * 8.5, semente + 51.0) * (TREME_GIRO * medo + TREME_GIRO_FORCA * forca)


## A pose com cada no tremendo por ruido, dedo a dedo e sem compasso (`graus` de
## amplitude). O `MaoPosada.viva` faz o mesmo com senos.
static func pose_tremida(p: Dictionary, t: float, graus: float, semente: float) -> Dictionary:
	if graus <= 0.0:
		return p
	var dedos := []
	for i in 4:
		var d: Array = p["dedos"][i]
		var s := semente + float(i) * 13.7
		var mexe := ruido(t * 6.5, s) * 0.7 + ruido(t * 15.0, s + 3.1) * 0.3
		dedos.append([float(d[0]) + mexe * graus * 0.5, float(d[1]) + mexe * graus,
			float(d[2]) + mexe * graus * 0.6, float(d[3]) + ruido(t * 2.2, s + 7.0) * graus * 0.3])
	var pol: Array = (p["polegar"] as Array).duplicate()
	pol[3] = float(pol[3]) + ruido(t * 5.0, semente + 70.0) * graus * 0.7
	pol[4] = float(pol[4]) + ruido(t * 7.0, semente + 80.0) * graus * 0.8
	return {"dedos": dedos, "polegar": pol}


# --- o aparelho na mao, subindo ---------------------------------------------------

## O erguer (fracao do tempo -> fracao do caminho): o tranco que arranca o aparelho
## do chao e a subida que freia chegando. A curva de antes, 1 - (1-k)^2,6, saia do
## chao a 2 m/s ja no primeiro quadro; esta parte parada e pega essa velocidade em
## uns 90 ms (o tranco: ~20 m/s2), e dali segue a de antes. Uma versao com a mao
## freando depois do tranco (o peso) atrasava a subida 13 cm no caminho e o
## antebraco descia 2,5 cm no assento do carona: o peso ficou no balanco do
## aparelho (`giro_do_peso`).
const ERGUER_K := [0.0, 0.05, 0.13, 0.30, 0.50, 0.70, 0.86, 1.0]
const ERGUER_E := [0.0, 0.055, 0.27, 0.60, 0.835, 0.955, 0.993, 1.0]


static func erguer(k: float) -> float:
	return curva(PackedFloat32Array(ERGUER_K), PackedFloat32Array(ERGUER_E), k)


## O balanco do aparelho na pinca: a aceleracao da mao empurra o centro dele para
## tras do ponto de pega, e ele gira nela; o punho segura e devolve (rad por m/s2
## e o teto, em rad).
const PESO_GANHO := 0.9
const PESO_MAX := 0.11
## O tremor do aparelho na mao (m e rad): e a mao inteira tremendo, com ele junto.
const FONE_TREME := 0.0011
const FONE_TREME_LENTO := 0.0018
const FONE_TREME_GIRO := 0.010


## O giro que a aceleracao `acel` (m/s2) pede no aparelho, com o centro dele a
## `braco` do ponto de pega (vetor de rotacao, rad).
static func giro_do_peso(braco: Vector3, acel: Vector3) -> Vector3:
	return braco.cross(-acel).limit_length(PESO_MAX / PESO_GANHO) * PESO_GANHO
