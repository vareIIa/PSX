extends SceneTree
func _init():
	print("load prancha=", load("res://src/ui/prancha_inventario.gd"))
	print("load menu=", load("res://src/ui/menu_sistema.gd"))
	quit()
