extends SceneTree
func _initialize() -> void:
	_rodar.call_deferred()
func _rodar() -> void:
	var CB: GDScript = load("res://src/world/chunk_builder.gd")
	for c: Vector2i in [Vector2i(-1, -1), Vector2i(-2, -5), Vector2i(-1, -2), Vector2i(3, -1), Vector2i(4, -1), Vector2i(3, 7), Vector2i(-2, -3), Vector2i(-1, -5), Vector2i(0, 9)]:
		var d: Dictionary = CB.construir(c.x, c.y)
		var origem := Vector3(c.x * 32.0, 0.0, c.y * 32.0)
		var piso := 0.0
		for p: Dictionary in d["props"]:
			if p.get("contexto", &"") == &"loja":
				piso = Vector3(p["pos"]).y
				break
		for l: Dictionary in d["lojas"]:
			var b: Vector3 = Vector3(l["boca"]) + origem
			var n: Vector3 = l["normal"]
			var fora := b + n * 3.2
			var alvo := b - n * 5.0
			var dentro := b - n * 0.9
			var fundo := b - n * 7.0
			print("[loja] %s %s fora=%.2f,%.2f,%.2f,%.2f,%.2f,%.2f dentro=%.2f,%.2f,%.2f,%.2f,%.2f,%.2f" % [
				l["id"], c, fora.x, fora.z, alvo.x, alvo.z, piso + 1.2, piso + 1.62,
				dentro.x, dentro.z, fundo.x, fundo.z, piso + 1.1, piso + 1.62])
	quit(0)
