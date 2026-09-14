extends SceneTree
func _init():
	var s = load("res://src/world/estrada_builder.gd")
	print("builder loaded=", s)
	var k = load("res://src/world/kit_estrada.gd")
	print("kit loaded=", k)
	quit()
