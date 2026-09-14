extends SceneTree

func _init() -> void:
	var path := "res://src/world/malha_urbana.gd"
	# Probe quads near 270,-40
	var px := 270.0
	var pz := -40.0
	var TAM := 32.0
	# Try common chunk sizes
	for try_tam in [32.0, 48.0, 64.0, 96.0]:
		pass
	quit()
