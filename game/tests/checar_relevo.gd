## O morro da cidade, sem montar chunk: o que tem de ser plano e plano, e as
## ruas tem o declive de Minas.
##
##     godot --headless --path game --script res://tests/checar_relevo.gd
##
## O que ele prova
## ---------------
##   praca      os nove chunks da Praca da Matriz em y = 0, exatos: a abertura e
##              cenario de cutscene com camera cravada em coordenada de mundo.
##   parque     todo chunk de parque plano (o ParqueBuilder monta plano e o chunk
##              sobe inteiro); patamar de bar e casa da fumaca tambem.
##   declive    rua e viela com mediana de ladeira e uma parte acima de 20% (a
##              escadaria); avenida aterrada, com teto.
##   pista lisa a rua corre na linha de nos, na emenda de dois chunks. Com a
##              bilinear ela dobrava em V no eixo (p95 14%, ate 44%) e fazia
##              quina no topo da ladeira (p95 13%, ate 50%). Mede a diferenca de
##              declive transversal dos dois lados do eixo e a de declive ao
##              longo, 4 m antes e depois de cada no.
##
## Imprime a distribuicao por tipo de via, que e o numero para calibrar Morros.
## Sai com 1 se algum criterio falhar.
extends SceneTree

const RAIO := 24
## Teto da avenida: o trecho colado num parque em encosta chega perto disto.
const AVENIDA_MAX := 0.32
const AVENIDA_P95 := 0.16
## Rua e viela: entre 1% e 10% dos trechos acima de 20% viram escadaria.
const ESCADARIA := Vector2(0.01, 0.10)
const RUA_MEDIANA_MIN := 0.02
## Pista lisa: diferenca de declive (dobra no eixo, quina no no). Com o Hermite
## a medida da 3,3% e 3,9% no p95; a bilinear dava 14% e 13%.
const DOBRA_P95 := 0.05
const QUINA_P95 := 0.06

var _falhas: PackedStringArray = []
var _total := 0


func _initialize() -> void:
	_rodar.call_deferred()


func _afirmar(msg: String, cond: bool) -> void:
	_total += 1
	if not cond:
		_falhas.append(msg)


## A dobra no eixo e a quina no no, nas ruas do raio (so ate 14 chunks: e
## amostragem densa). E o chao do parque por dentro, nao so nos cantos: a
## interpolacao e cubica e poderia inchar no meio.
func _pista_lisa() -> void:
	var t := Relevo.TAM
	var dobras: Array[float] = []
	var quinas: Array[float] = []
	var inchado := 0
	for j in range(-14, 14):
		for i in range(-14, 14):
			if int(MalhaUrbana.quadra_de(i, j)["uso"]) == MalhaUrbana.Uso.PARQUE:
				var base := Relevo.no(i, j)
				for k in 16:
					var y := Relevo.altura((i + (k % 4 + 0.5) / 4.0) * t,
						(j + (k / 4 + 0.5) / 4.0) * t)
					if absf(y - base) > 0.01:
						inchado += 1
						break
			for eixo in 2:
				var via := MalhaUrbana.via_x_em(i, j) if eixo == 0 \
					else MalhaUrbana.via_z_em(j, i)
				if via == MalhaUrbana.Via.NENHUMA:
					continue
				var ao := Vector2(0, 1) if eixo == 0 else Vector2(1, 0)
				var at := Vector2(1, 0) if eixo == 0 else Vector2(0, 1)
				var o := Vector2(i, j) * t
				for k in range(1, 16):
					var p := o + ao * (k * 2.0)
					var c := Relevo.altura(p.x, p.y)
					var dir := Relevo.altura(p.x + at.x * 3.0, p.y + at.y * 3.0) - c
					var esq := c - Relevo.altura(p.x - at.x * 3.0, p.y - at.y * 3.0)
					dobras.append(absf(dir - esq) / 3.0)
				var c0 := Relevo.altura(o.x, o.y)
				var antes := c0 - Relevo.altura(o.x - ao.x * 4.0, o.y - ao.y * 4.0)
				var depois := Relevo.altura(o.x + ao.x * 4.0, o.y + ao.y * 4.0) - c0
				quinas.append(absf(depois - antes) / 4.0)
	dobras.sort()
	quinas.sort()
	var dobra: float = dobras[dobras.size() * 95 / 100]
	var quina: float = quinas[quinas.size() * 95 / 100]
	print("-- pista: dobra no eixo p95 %.1f%% (max %.1f%%), quina no no p95 %.1f%% (max %.1f%%)"
		% [dobra * 100.0, dobras[-1] * 100.0, quina * 100.0, quinas[-1] * 100.0])
	_afirmar("pista sem dobra no eixo (p95 %.1f%% <= %.0f%%)" % [dobra * 100.0,
		DOBRA_P95 * 100.0], dobra <= DOBRA_P95)
	_afirmar("ladeira sem quina no no (p95 %.1f%% <= %.0f%%)" % [quina * 100.0,
		QUINA_P95 * 100.0], quina <= QUINA_P95)
	_afirmar("parque plano por dentro (%d inchados)" % inchado, inchado == 0)


func _rodar() -> void:
	var t0 := Time.get_ticks_msec()
	var por_via := {1: [], 2: [], 3: []}
	var hmin := INF
	var hmax := -INF
	for j in range(-RAIO, RAIO):
		for i in range(-RAIO, RAIO):
			var h := Relevo.no(i, j)
			hmin = minf(hmin, h)
			hmax = maxf(hmax, h)
			var vx := int(MalhaUrbana.via_x_em(i, j))
			if vx != 0:
				por_via[vx].append(absf(Relevo.no(i, j + 1) - h) / Relevo.TAM)
			var vz := int(MalhaUrbana.via_z_em(j, i))
			if vz != 0:
				por_via[vz].append(absf(Relevo.no(i + 1, j) - h) / Relevo.TAM)
	print("\n=== relevo: %d nos em %d ms, altura %.1f a %.1f m ===\n"
		% [4 * RAIO * RAIO, Time.get_ticks_msec() - t0, hmin, hmax])

	var nomes := {1: "viela", 2: "rua", 3: "avenida"}
	for v: int in [1, 2, 3]:
		var g: Array = por_via[v]
		g.sort()
		var n := g.size()
		var acima := 0
		for x: float in g:
			if x > 0.2:
				acima += 1
		var mediana: float = g[n / 2]
		var p95: float = g[n * 95 / 100]
		var maximo: float = g[n - 1]
		var frac := float(acima) / float(n)
		print("-- %-8s %4d trechos  mediana %4.1f%%  p95 %4.1f%%  max %4.1f%%  >20%% %4.1f%%"
			% [nomes[v], n, mediana * 100.0, p95 * 100.0, maximo * 100.0, frac * 100.0])
		if v == 3:
			_afirmar("avenida com teto (max %.1f%% <= %.0f%%)" % [maximo * 100.0,
				AVENIDA_MAX * 100.0], maximo <= AVENIDA_MAX)
			_afirmar("avenida aterrada (p95 %.1f%% <= %.0f%%)" % [p95 * 100.0,
				AVENIDA_P95 * 100.0], p95 <= AVENIDA_P95)
		else:
			_afirmar("%s tem ladeira (mediana %.1f%% >= %.0f%%)" % [nomes[v],
				mediana * 100.0, RUA_MEDIANA_MIN * 100.0], mediana >= RUA_MEDIANA_MIN)
			_afirmar("%s tem escadaria sem virar escada (%.1f%% acima de 20%%)" % [nomes[v],
				frac * 100.0], frac >= ESCADARIA.x and frac <= ESCADARIA.y)

	var praca := true
	for cz in range(-3, 0):
		for cx in range(7, 10):
			praca = praca and Relevo.plano(cx, cz)
	_afirmar("Praca da Matriz plana em zero", praca)
	_afirmar("pin 270,-40 em zero", absf(Relevo.altura(270.0, -40.0)) < 0.002)

	var parques := 0
	var tortos := 0
	var patamares := 0
	var patamar_torto := 0
	for cz in range(-RAIO, RAIO):
		for cx in range(-RAIO, RAIO):
			var c := [Relevo.no(cx, cz), Relevo.no(cx + 1, cz), Relevo.no(cx, cz + 1),
				Relevo.no(cx + 1, cz + 1)]
			var desnivel := maxf(maxf(c[0], c[1]), maxf(c[2], c[3])) \
				- minf(minf(c[0], c[1]), minf(c[2], c[3]))
			if int(MalhaUrbana.quadra_de(cx, cz)["uso"]) == MalhaUrbana.Uso.PARQUE:
				parques += 1
				if desnivel > 0.01:
					tortos += 1
					print("  parque torto %s: %.2f m" % [Vector2i(cx, cz), desnivel])
			elif Relevo.tem_patamar(cx, cz):
				patamares += 1
				if desnivel > 0.01:
					patamar_torto += 1
					print("  patamar torto %s: %.2f m" % [Vector2i(cx, cz), desnivel])
	print("-- %d chunks de parque, %d patamares" % [parques, patamares])
	_afirmar("todo parque plano (%d tortos)" % tortos, tortos == 0)
	_afirmar("todo patamar plano (%d tortos)" % patamar_torto, patamar_torto == 0)
	_afirmar("ha parque no raio (a regua ve alguma coisa)", parques > 0)
	_afirmar("ha patamar no raio (a regua ve alguma coisa)", patamares > 0)
	_pista_lisa()

	print("")
	if _falhas.is_empty():
		print("OK — %d assercoes" % _total)
		quit(0)
		return
	print("FALHOU — %d de %d assercoes" % [_falhas.size(), _total])
	for f: String in _falhas:
		print("  x %s" % f)
	quit(1)
