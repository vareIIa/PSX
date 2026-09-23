## TEMPORARIO (F7). Lista empenas (coordenada de mundo) para escolher pose.
extends SceneTree


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var CB: GDScript = load("res://src/world/chunk_builder.gd")
	var EV: GDScript = load("res://src/world/empena_viva.gd")
	EV.set("registrar", true)
	var n := 0
	var area := 0.0
	var tij := 0
	for cz in range(-9, 6):
		for cx in range(-3, 16):
			(EV.get("registro") as Array).clear()
			CB.construir(cx, cz)
			for r: Dictionary in EV.get("registro"):
				n += 1
				if bool(r["tijolo"]):
					tij += 1
				var m: Vector3 = r["meio"] + Vector3(cx * 32.0, 0.0, cz * 32.0)
				var f: Vector3 = r["fora"]
				if float(r["alto"]) > 3.0 or bool(r["anuncio"]):
					print("[empena] (%d,%d) %s alto %.1f tijolo %s anuncio %s base %.1f meio %.1f,%.1f,%.1f fora %.0f,%.0f" % [cx, cz,
						r["estilo"], r["alto"], r["tijolo"], r["anuncio"], r["base"], m.x, m.y, m.z, f.x, f.z])
	print("[empena] total %d, tijolo %d" % [n, tij])
	quit(0)
