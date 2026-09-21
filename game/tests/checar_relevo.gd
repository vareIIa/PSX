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

var _falhas: PackedStringArray = []
var _total := 0


func _initialize() -> void:
	_rodar.call_deferred()


func _afirmar(msg: String, cond: bool) -> void:
	_total += 1
	if not cond:
		_falhas.append(msg)


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

	print("")
	if _falhas.is_empty():
		print("OK — %d assercoes" % _total)
		quit(0)
		return
	print("FALHOU — %d de %d assercoes" % [_falhas.size(), _total])
	for f: String in _falhas:
		print("  x %s" % f)
	quit(1)
