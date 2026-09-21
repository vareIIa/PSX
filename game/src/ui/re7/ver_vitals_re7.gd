extends Control

const CENA_VITALS := "res://src/ui/re7/vitals_monitor.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var band := "ok"
	for arg in OS.get_cmdline_user_args():
		if arg == "--ver-vitals-re7":
			band = "ok"
		elif arg.begins_with("--ver-vitals-re7="):
			band = arg.trim_prefix("--ver-vitals-re7=").strip_edges().to_lower()
	var ratio := 1.0
	match band:
		"warn":
			ratio = 0.55
		"crit":
			ratio = 0.2
		"dead":
			ratio = 0.0
		_:
			ratio = 1.0
			band = "ok"
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("0a0c0e")
	add_child(bg)
	var title := Label.new()
	title.text = "ONDA 3 — VITALS %s" % band.to_upper()
	title.position = Vector2(24, 16)
	title.add_theme_color_override(&"font_color", Color("e8e2d6"))
	title.add_theme_font_size_override(&"font_size", 13)
	add_child(title)
	var packed: PackedScene = load(CENA_VITALS) as PackedScene
	if packed == null:
		push_error("[ver-vitals] missing")
		get_tree().quit(1)
		return
	var vitals := packed.instantiate()
	var screen := get_viewport_rect().size
	vitals.position = Vector2(screen.x * 0.5 - 30.0, screen.y * 0.5 - 24.0)
	vitals.scale = Vector2(3.2, 3.2)
	add_child(vitals)
	await get_tree().process_frame
	if vitals.has_method("set_ratio"):
		vitals.call("set_ratio", ratio)
	var frames := 60 if band == "crit" else 42
	for _i in frames:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		push_error("[ver-vitals] no image")
		get_tree().quit(1)
		return
	var abs_dir := _cap_dir()
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var named := abs_dir.path_join("onda3_vitals_%s.png" % band)
	var err := img.save_png(named)
	if band == "ok":
		img.save_png(abs_dir.path_join("onda3_vitals.png"))
	print("[ver-vitals] save %s err=%d %dx%d" % [named, err, img.get_width(), img.get_height()])
	get_tree().quit(0 if err == OK else 1)


func _cap_dir() -> String:
	var game_root := ProjectSettings.globalize_path("res://").rstrip("/\\")
	return game_root.get_base_dir().path_join("captures/ui/re7_dev").replace("\\", "/")