extends SceneTree
func _init() -> void:
	var s = load("res://src/ui/inventory_item_re7.gd")
	var t = load("res://src/ui/inventory_slot_re7.gd")
	var g = load("res://src/ui/inventario_grid_re7.gd")
	print("[check] item=", s != null, " slot=", t != null, " grid=", g != null)
	quit(0 if (s and t and g) else 1)
