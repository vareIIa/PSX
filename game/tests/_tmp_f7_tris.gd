extends SceneTree
func _initialize() -> void:
	_rodar.call_deferred()
func _rodar() -> void:
	var CB: GDScript = load("res://src/world/chunk_builder.gd")
	for c: Vector2i in [Vector2i(10, 4), Vector2i(11, 4), Vector2i(6, 4)]:
		var d: Dictionary = CB.construir(c.x, c.y)
		var t := 0
		for m: StringName in d["superficies"]:
			if String(m) in ["anuncio_empena"]:
				t += 1
		print("[tris] ", c, " ", d["triangulos"], " anuncio? ", t)
	quit(0)
