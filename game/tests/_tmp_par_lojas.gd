extends SceneTree
func _initialize() -> void:
	_rodar.call_deferred()
func _rodar() -> void:
	var CB: GDScript = load("res://src/world/chunk_builder.gd")
	var LV: GDScript = load("res://src/world/loja_viva.gd")
	for c: Vector2i in [Vector2i(-2, -5), Vector2i(0, 7), Vector2i(0, 9), Vector2i(1, -10), Vector2i(2, 5), Vector2i(4, -9), Vector2i(4, 7)]:
		LV.set("ativo", true)
		var a: Dictionary = CB.construir(c.x, c.y)
		LV.set("ativo", false)
		var b: Dictionary = CB.construir(c.x, c.y)
		var por := {}
		for m: StringName in a["superficies"]:
			var na := 0
			var nb := 0
			var sa: Variant = a["superficies"][m]
			na = _tris(sa)
			if b["superficies"].has(m):
				nb = _tris(b["superficies"][m])
			if na - nb > 150:
				por[m] = na - nb
		print("[par] ", c, " com ", a["triangulos"], " sem ", b["triangulos"], " delta ", int(a["triangulos"]) - int(b["triangulos"]), " ", por)
	quit(0)
func _tris(s: Variant) -> int:
	if s is Dictionary and s.has("indices"):
		return (s["indices"] as PackedInt32Array).size() / 3
	if s is Array and s.size() > Mesh.ARRAY_INDEX and s[Mesh.ARRAY_INDEX] != null:
		return (s[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return 0
