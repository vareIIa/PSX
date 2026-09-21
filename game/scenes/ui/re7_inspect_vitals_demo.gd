## Demo isolada Onda 3 — inspeção 3D + vitals (sem cutover na prancha).
extends Control

const DEFAULT_ITEM := &"lanterna"

@onready var _inspect: ItemInspectViewport = $ItemInspectViewport
@onready var _vitals: VitalsMonitor = $VitalsMonitor
@onready var _hint: Label = $Hint
@onready var _title: Label = $Title
@onready var _frame: Panel = $InspectFrame

var _shot_mode := ""
var _item_id: StringName = DEFAULT_ITEM


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	if has_meta("onda3_force_shot"):
		_shot_mode = str(get_meta("onda3_force_shot"))
	print("[onda3-demo] shot=", _shot_mode, " item=", _item_id)
	_layout_for_mode()
	await get_tree().process_frame
	_boot_inspect()
	_boot_vitals()
	if _shot_mode != "":
		await _capture_and_quit()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--onda3-shot="):
			_shot_mode = arg.trim_prefix("--onda3-shot=").strip_edges()
		elif arg.begins_with("--onda3-item="):
			_item_id = StringName(arg.trim_prefix("--onda3-item=").strip_edges())


func _layout_for_mode() -> void:
	var show_inspect := _shot_mode == "" or _shot_mode == "inspect"
	var show_vitals := _shot_mode == "" or _shot_mode.begins_with("vitals")
	_inspect.visible = show_inspect
	_frame.visible = show_inspect
	_vitals.visible = show_vitals
	_hint.visible = _shot_mode == ""
	if _shot_mode == "inspect":
		_title.text = "ONDA 3 — INSPECAO 3D"
		_inspect.position = Vector2(570, 285)
		_inspect.size = Vector2(140, 150)
		_frame.position = Vector2(562, 277)
		_frame.size = Vector2(156, 166)
		_vitals.visible = false
	elif _shot_mode.begins_with("vitals"):
		_title.text = "ONDA 3 — VITALS %s" % _shot_mode.trim_prefix("vitals_").to_upper()
		_inspect.visible = false
		_frame.visible = false
		_vitals.position = Vector2(560, 320)
		_vitals.scale = Vector2(3.5, 3.5)
	else:
		_title.text = "ONDA 3 — DEMO ISOLADA"


func _boot_inspect() -> void:
	if not is_instance_valid(_inspect) or not _inspect.visible:
		return
	_inspect.enter()
	_inspect.set_item(_item_id)
	_inspect.zoom = 1.05


func _boot_vitals() -> void:
	if not is_instance_valid(_vitals) or not _vitals.visible:
		return
	var ratio := 1.0
	match _shot_mode:
		"vitals_ok":
			ratio = 1.0
		"vitals_warn":
			ratio = 0.55
		"vitals_crit":
			ratio = 0.2
		_:
			ratio = 1.0
	_vitals.set_ratio(ratio)


func _capture_dir() -> String:
	var game_root := ProjectSettings.globalize_path("res://")
	return game_root.path_join("../captures/ui/re7_dev").simplify_path()


func _capture_and_quit() -> void:
	var frames := 50 if _shot_mode == "vitals_crit" else 36
	for i in frames:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var tex := get_viewport().get_texture()
	if tex == null:
		push_error("[onda3] viewport texture null")
		get_tree().quit(1)
		return
	var img := tex.get_image()
	if img == null:
		push_error("[onda3] viewport image null")
		get_tree().quit(1)
		return
	var abs_dir := _capture_dir()
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var out_path := abs_dir.path_join(_file_for_mode(_shot_mode))
	var err := img.save_png(out_path)
	if err != OK:
		push_error("[onda3] save falhou %s (%d)" % [out_path, err])
		get_tree().quit(1)
		return
	print("[onda3] ok %s (%dx%d)" % [out_path, img.get_width(), img.get_height()])
	get_tree().quit(0)


func _file_for_mode(mode: String) -> String:
	match mode:
		"inspect":
			return "onda3_inspect.png"
		"vitals_ok":
			return "onda3_vitals_ok.png"
		"vitals_warn":
			return "onda3_vitals_warn.png"
		"vitals_crit":
			return "onda3_vitals_crit.png"
		_:
			return "onda3_%s.png" % mode