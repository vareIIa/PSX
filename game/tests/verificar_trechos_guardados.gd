## `Rotas.trechos_perto` e `Vias.trechos_perto` guardados por no devolvem
## EXATAMENTE o que a varredura antiga devolvia, na mesma ordem.
##
##     godot --path game --headless res://tests/verificar_trechos_guardados.tscn
##
## A varredura antiga esta copiada aqui (`_rotas_antigo`, `_vias_antigo`) e as
## duas rodam lado a lado em 400 centros espalhados pela cidade, com as coroas
## que a Multidao, o Transito e a Blitz usam. Imprime `[trechos] ...` e sai 1 se
## qualquer lista diferir. Tambem da o tempo de cada uma.
extends Node

const COROAS_ROTAS: Array[Vector2] = [Vector2(24, 42), Vector2(9, 42), Vector2(4, 40)]
const COROAS_VIAS: Array[Vector2] = [Vector2(34, 58), Vector2(16, 58), Vector2(0, 40),
	Vector2(0, 60), Vector2(10, 58)]


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var centros: Array[Vector3] = []
	for n in 400:
		centros.append(Vector3(rng.randf_range(-2400.0, 2400.0), 0.0,
			rng.randf_range(-2400.0, 2400.0)))
	var falhas := 0
	var t_antigo := 0
	var t_novo := 0
	var comparados := 0
	for c: Vector3 in centros:
		for coroa: Vector2 in COROAS_ROTAS:
			var t0 := Time.get_ticks_usec()
			var a := _rotas_antigo(c, coroa.x, coroa.y)
			var t1 := Time.get_ticks_usec()
			var b := Rotas.trechos_perto(c, coroa.x, coroa.y)
			t_antigo += t1 - t0
			t_novo += Time.get_ticks_usec() - t1
			comparados += 1
			if a != b:
				falhas += 1
				if falhas <= 5:
					print("[trechos] DIFERE rotas centro=%s coroa=%s %d x %d" % [c, coroa, a.size(), b.size()])
		for coroa: Vector2 in COROAS_VIAS:
			var a := _vias_antigo(c, coroa.x, coroa.y)
			var b := Vias.trechos_perto(c, coroa.x, coroa.y)
			comparados += 1
			if a != b:
				falhas += 1
				if falhas <= 5:
					print("[trechos] DIFERE vias centro=%s coroa=%s %d x %d" % [c, coroa, a.size(), b.size()])
	# Regime: o mesmo centro de novo (o jogador parado ou andando dentro do chunk).
	var c0 := centros[0]
	var t2 := Time.get_ticks_usec()
	for n in 50:
		Rotas.trechos_perto(c0 + Vector3(float(n) * 0.3, 0.0, 0.0), 24.0, 42.0)
	var regime_rotas := (Time.get_ticks_usec() - t2) / 50.0 / 1000.0
	var t3 := Time.get_ticks_usec()
	for n in 50:
		Vias.trechos_perto(c0 + Vector3(float(n) * 0.3, 0.0, 0.0), 34.0, 58.0)
	var regime_vias := (Time.get_ticks_usec() - t3) / 50.0 / 1000.0
	var t4 := Time.get_ticks_usec()
	for n in 50:
		_rotas_antigo(c0 + Vector3(float(n) * 0.3, 0.0, 0.0), 24.0, 42.0)
	var antigo_rotas := (Time.get_ticks_usec() - t4) / 50.0 / 1000.0
	var t5 := Time.get_ticks_usec()
	for n in 50:
		_vias_antigo(c0 + Vector3(float(n) * 0.3, 0.0, 0.0), 34.0, 58.0)
	var antigo_vias := (Time.get_ticks_usec() - t5) / 50.0 / 1000.0
	print("[trechos] comparados=%d falhas=%d" % [comparados, falhas])
	print("[trechos] rotas antigo_ms=%.2f guardado_ms=%.3f | vias antigo_ms=%.2f guardado_ms=%.3f" % [
		antigo_rotas, regime_rotas, antigo_vias, regime_vias])
	print("[trechos] primeira_passada rotas antigo_total_ms=%.0f novo_total_ms=%.0f" % [
		t_antigo / 1000.0, t_novo / 1000.0])
	print("[trechos] %s" % ("OK" if falhas == 0 else "FALHOU"))
	get_tree().quit(0 if falhas == 0 else 1)


# --- a varredura antiga, copiada de rotas.gd e vias.gd -----------------------

func _rotas_antigo(centro: Vector3, minimo: float, maximo: float) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var ci := floori(centro.x / Rotas.TAM)
	var cj := floori(centro.z / Rotas.TAM)
	var alcance := ceili(maximo / Rotas.TAM) + 2
	for di in range(-alcance, alcance + 1):
		var i := ci + di
		for dj in range(-alcance, alcance + 1):
			var j := cj + dj
			if not Rotas.existe_no(i, j):
				continue
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					var no := Vector4i(i, j, sx, sz)
					for k in 2:
						var destino := Rotas.vizinhos(no)[k]
						if destino == no or not Rotas.aresta_caminhavel(no, k):
							continue
						var a := Rotas.ponto(no)
						var b := Rotas.ponto(destino)
						var comprimento := a.distance_to(b)
						if comprimento < 1.0:
							continue
						var quantos := maxi(1, int(comprimento / Rotas.PASSO_AMOSTRA))
						for n in range(1, quantos):
							var p := a.lerp(b, float(n) / float(quantos))
							p.y = Relevo.altura(p.x, p.z)
							var d := p.distance_to(centro)
							if d >= minimo and d <= maximo:
								saida.append({"de": no, "para": destino, "ponto": p})
	return saida


func _vias_antigo(centro: Vector3, minimo: float, maximo: float) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var alcance := ceili(maximo / Vias.TAM) + 1
	var ci := roundi(centro.x / Vias.TAM)
	var cj := roundi(centro.z / Vias.TAM)
	for di in range(-alcance, alcance + 1):
		for dj in range(-alcance, alcance + 1):
			var i := ci + di
			var j := cj + dj
			if not Vias.existe_cruzamento(i, j):
				continue
			for eixo: int in [0, 1]:
				for sentido: int in [1, -1]:
					var via := (MalhaUrbana.via_x(i) if eixo == 0 else MalhaUrbana.via_z(j))
					for f in Vias.faixas(via):
						var t := Vias.trecho(eixo, sentido, f)
						var ate := Vias.proximo_cruzamento(i, j, t)
						if ate == Vector2i(i, j):
							continue
						var a := Vias.ponto_de_curva(i, j, t, t)
						var b := Vias.ponto_de_curva(ate.x, ate.y, t, t)
						var comprimento := a.distance_to(b)
						if comprimento < 1.0:
							continue
						var passos := maxi(1, int(comprimento / Vias.PASSO_AMOSTRA))
						for k in range(1, passos):
							var p := a.lerp(b, float(k) / float(passos))
							p.y = Relevo.altura(p.x, p.z)
							var d := Vector2(p.x - centro.x, p.z - centro.z).length()
							if d < minimo or d > maximo:
								continue
							saida.append({"ponto": p, "de": Vector2i(i, j), "para": ate, "trecho": t})
	return saida
