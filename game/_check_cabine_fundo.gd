extends SceneTree

func _initialize() -> void:
	var path := "res://scenes/player/cabine_fundo_criacao.tscn"
	if not ResourceLoader.exists(path):
		push_error("MISSING " + path)
		quit(1)
		return
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("NOT_PACKED")
		quit(1)
		return
	var root := packed.instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame
	var cam := root.find_child("CameraFP", true, false)
	var cab := root.find_child("Cabine", true, false)
	var pernas := root.find_child("PernasPiloto", true, false)
	print("[ok] cabine_fundo_criacao loaded")
	print("[ok] camera=", cam != null, " cabine=", cab != null, " pernas=", pernas != null)
	if cam == null or cab == null:
		push_error("SCENE_INCOMPLETE")
		quit(2)
		return
	quit(0)
