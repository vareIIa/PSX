extends SceneTree
func _initialize() -> void:
	_rodar.call_deferred()
func _rodar() -> void:
	var CB: GDScript = load("res://src/world/chunk_builder.gd")
	var LV: GDScript = load("res://src/world/loja_viva.gd")
	var n := 0
	var lojas := {}
	var equipe := 0
	var clientes := 0
	var tris_loja: Array[int] = []
	var tris_outro: Array[int] = []
	var t_loja: Array[float] = []
	var t_outro: Array[float] = []
	var candidatos := 0
	for cx in range(-8, 8):
		for cz in range(-10, 10):
			var t0 := Time.get_ticks_usec()
			var d: Dictionary = CB.construir(cx, cz)
			var dt := (Time.get_ticks_usec() - t0) / 1000.0
			n += 1
			var tem := false
			for p: Dictionary in d["props"]:
				if p.get("contexto", &"") == &"loja":
					equipe += 1
					var id := String(LV.RAMOS[int(p["loja"]["ramo"])]["id"])
					if not lojas.has(Vector2i(cx, cz)):
						lojas[Vector2i(cx, cz)] = id
					tem = true
				elif p.get("tipo", "") == "convidado" and p.has("pontos") and not p.has("fuma_") and p.get("semente", 0) >= 91000 + cx * 613 + cz * 1277 + 509 and p.get("semente", 0) < 91000 + cx * 613 + cz * 1277 + 509 + 97 * 4:
					clientes += 1
			var q: Dictionary = MalhaUrbana.quadra_de(cx, cz)
			if LV.tem_loja(cx, cz, q, CB._porta_do_chunk(cx, cz, q)):
				candidatos += 1
			if tem:
				tris_loja.append(int(d["triangulos"]))
				t_loja.append(dt)
			else:
				tris_outro.append(int(d["triangulos"]))
				t_outro.append(dt)
	var por_ramo := {}
	for k: Vector2i in lojas:
		por_ramo[lojas[k]] = int(por_ramo.get(lojas[k], 0)) + 1
	print("[censo] chunks=", n, " candidatos=", candidatos, " lojas=", lojas.size(), " equipe=", equipe, " clientes=", clientes)
	print("[censo] por ramo ", por_ramo)
	print("[censo] lojas: ", lojas)
	var m := func(a: Array) -> String:
		if a.is_empty():
			return "-"
		var s := 0.0
		for v in a:
			s += float(v)
		return "%.0f med / %.0f max" % [s / a.size(), a.max()]
	print("[censo] tris chunk com loja ", m.call(tris_loja), "  sem ", m.call(tris_outro))
	print("[censo] ms chunk com loja ", m.call(t_loja), "  sem ", m.call(t_outro))
	quit(0)
