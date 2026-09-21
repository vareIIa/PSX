extends SceneTree
func _init():
	var s = load("res://src/ui/ui_manager.gd")
	print("ui_manager=", s)
	if s:
		var n = s.new()
		print("has vitals=", n.has_method("abrir_ver_vitals_re7"))
		print("has inspect=", n.has_method("abrir_ver_inspect_re7"))
	quit()
