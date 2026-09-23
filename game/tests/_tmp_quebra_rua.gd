## Mede a quebra da pista: a dobra em V no eixo (declive de um lado da emenda
## contra o do outro) e a quina no topo/fundo da ladeira (declive antes e depois
## do no, e a curvatura sentida em 4 m).
extends SceneTree

const RAIO := 14
const T := 32.0


func _initialize() -> void:
	_rodar.call_deferred()


func _h(x: float, z: float) -> float:
	return Relevo.altura(x, z)


func _rodar() -> void:
	var dobras: Array[float] = []
	var quinas: Array[float] = []
	var declives: Array[float] = []
	var pior_dobra := Vector3.ZERO
	var pior_quina := Vector3.ZERO
	var d := 3.0
	for j in range(-RAIO, RAIO):
		for i in range(-RAIO, RAIO):
			for eixo in 2:
				var via := MalhaUrbana.via_x_em(i, j) if eixo == 0 else MalhaUrbana.via_z_em(j, i)
				if via == MalhaUrbana.Via.NENHUMA:
					continue
				# eixo 0: rua ao longo de z na linha x = i*T (via_x_em(i, j) e o
				# trecho de j a j+1). eixo 1: ao longo de x na linha z = j*T.
				var ao_longo := Vector2(0, 1) if eixo == 0 else Vector2(1, 0)
				var atravessa := Vector2(1, 0) if eixo == 0 else Vector2(0, 1)
				var o := Vector2(i * T, j * T)
				for k in range(1, 16):
					var s := float(k) * 2.0
					var p := o + ao_longo * s
					var c := _h(p.x, p.y)
					var dir := (_h(p.x + atravessa.x * d, p.y + atravessa.y * d) - c) / d
					var esq := (c - _h(p.x - atravessa.x * d, p.y - atravessa.y * d)) / d
					var dobra := absf(dir - esq)
					dobras.append(dobra)
					if dobra > pior_dobra.z:
						pior_dobra = Vector3(p.x, p.y, dobra)
				# quina no no da ponta (s = 0): declive nos 4 m antes e depois
				var a := (_h(o.x, o.y) - _h(o.x - ao_longo.x * 4, o.y - ao_longo.y * 4)) / 4.0
				var b := (_h(o.x + ao_longo.x * 4, o.y + ao_longo.y * 4) - _h(o.x, o.y)) / 4.0
				quinas.append(absf(b - a))
				if absf(b - a) > pior_quina.z:
					pior_quina = Vector3(o.x, o.y, absf(b - a))
				for k in range(0, 16):
					var p0 := o + ao_longo * (k * 2.0)
					var p1 := p0 + ao_longo * 2.0
					declives.append(absf(_h(p1.x, p1.y) - _h(p0.x, p0.y)) / 2.0)
	_dist("dobra em V no eixo (dif. de declive transversal)", dobras)
	_dist("quina no no (dif. de declive em 4 m)", quinas)
	_dist("declive da pista (2 m)", declives)
	print("pior dobra em (%.0f, %.0f): %.1f%%" % [pior_dobra.x, pior_dobra.y, pior_dobra.z * 100])
	print("pior quina em (%.0f, %.0f): %.1f%%" % [pior_quina.x, pior_quina.y, pior_quina.z * 100])
	quit(0)


func _dist(nome: String, g: Array[float]) -> void:
	g.sort()
	var n := g.size()
	var acima := 0
	for x in g:
		if x > 0.04:
			acima += 1
	print("%-50s n=%5d  mediana %5.1f%%  p95 %5.1f%%  max %5.1f%%  >4%% %5.1f%%" % [nome, n,
		g[n / 2] * 100, g[n * 95 / 100] * 100, g[n - 1] * 100, 100.0 * acima / n])
