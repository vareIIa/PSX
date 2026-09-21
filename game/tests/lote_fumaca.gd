## Quanto cabe atras da fachada de cada casa da fumaca. Ferramenta, nao teste.
##
## A casa cresce para dentro do patio; o fundo dela nao pode passar da area util
## do chunk (a calcada da rua de tras) nem cruzar a fileira do outro eixo.
##
##   godot --headless --path game --script res://tests/lote_fumaca.gd
extends SceneTree


func _init() -> void:
	var menor_fundo := INF
	var menor_frente := INF
	var n := 0
	for cz in range(-24, 25):
		for cx in range(-24, 25):
			var quadra := MalhaUrbana.quadra_de(cx, cz)
			for ponto: Dictionary in ChunkBuilder.pontos_de_interesse(cx, cz):
				if ponto["tipo"] != &"porta" or ponto["interior"] != &"casa_fumaca":
					continue
				if not bool(ponto.get("mundo", false)):
					continue
				n += 1
				var lim := ChunkBuilder.area_util(cx, cz)
				var t: Transform3D = ponto["planta"]
				# Fundo livre: da fachada ate a borda da area util, ao longo do
				# eixo +Z da planta (para dentro do lote).
				var dentro := t.basis.z.normalized()
				var o := t.origin
				var fundo := INF
				if absf(dentro.x) > 0.5:
					fundo = (lim.end.x - o.x) if dentro.x > 0.0 else (o.x - lim.position.x)
				else:
					fundo = (lim.end.y - o.z) if dentro.z > 0.0 else (o.z - lim.position.y)
				# Frente livre: o comprimento da face.
				var face := ChunkBuilder._face_de_rua(cx, cz)
				var comp := float(face.get("comprimento", 0.0))
				menor_fundo = minf(menor_fundo, fundo)
				menor_frente = minf(menor_frente, comp)
				if fundo < 13.0:
					print("  chunk %s fundo livre %.2f  face %.1f  quadra casa=%s"
						% [Vector2i(cx, cz), fundo, comp, quadra["casa"]])
	print("casas: %d  menor fundo livre %.2f  menor face %.2f" % [n, menor_fundo, menor_frente])
	quit()
