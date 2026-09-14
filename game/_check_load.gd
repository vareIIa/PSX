extends SceneTree
func _init():
	for p in ["res://src/levels/abertura.gd", "res://src/world/kit_parque.gd", "res://src/world/parque_builder.gd", "res://src/levels/cidade.gd"]:
		var s = load(p)
		print("LOAD ", p, " -> ", s)
	quit()
