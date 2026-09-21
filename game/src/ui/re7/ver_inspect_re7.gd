extends Control

const CENA_INSPECT := "res://src/ui/re7/inspect_viewport.tscn"
const DEFAULT_ITEM := &"lanterna"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("0a0c0e")
	add_child(bg)
	var title := Label.new()
	title.text = "ONDA 3 — INSPECAO 3D"
	title.position = Vector2(24, 16)
	title.add_theme_color_override(&"font_color", Color("e8e2d6"))
	title.add_theme_font_size_override(&"font_size", 13)
	add_child(title)
	var packed: PackedScene = load(CENA_INSPECT) as PackedScene
	if packed == null:
		push_error("[ver-inspect] missing scene")
		get_tree().quit(1)
		return
	var inspect := packed.instantiate()
	var sz := Vector2(140, 150)
	var screen := get_viewport_rect().size
	inspect.position = Vector2((screen.x - sz.x) * 0.5, (screen.y - sz.y) * 0.5 - 8.0)
	inspect.size = sz
	add_child(inspect)
	await get_tree().process_frame
	if inspect.has_method("enter"):
		inspect.call("enter")
	if inspect.has_method("set_item"):
		inspect.call("set_item", DEFAULT_ITEM)
	if "zoom" in inspect:
		inspect.set("zoom", 1.05)
	for _i in 50:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		push_error("[ver-inspect] no image")
		get_tree().quit(1)
		return
	var abs_dir := _cap_dir()
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var out_path := abs_dir.path_join("onda3_inspect.png")
	var err := img.save_png(out_path)
	print("[ver-inspect] save %s err=%d %dx%d" % [out_path, err, img.get_width(), img.get_height()])
	get_tree().quit(0 if err == OK else 1)


func _cap_dir() -> String:
	var game_root := ProjectSettings.globalize_path("res://").rstrip("/\\")
	return game_root.get_base_dir().path_join("captures/ui/re7_dev").replace("\\", "/")