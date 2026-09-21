## Runner SUPPORT Onda 3 — captura isolada (sem cutover na prancha).
## Uso:
##   Godot --path game res://src/ui/re7/ver_onda3_re7.tscn -- --onda3-shot=inspect|vitals_ok|vitals_warn|vitals_crit
extends Node

const DEMO := "res://scenes/ui/re7_inspect_vitals_demo.tscn"
const OUT_DIR_REL := "../captures/ui/re7_dev"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var mode := _shot_mode()
	if mode == "":
		mode = "inspect"
	print("[ver-onda3] mode=", mode)
	var packed := load(DEMO) as PackedScene
	if packed == null:
		push_error("[ver-onda3] falha load demo")
		get_tree().quit(1)
		return
	var demo := packed.instantiate() as Control
	# Força modo via meta antes do _ready do demo — setamos args já parseados nele.
	demo.set_meta("onda3_force_shot", mode)
	add_child(demo)
	# Failsafe: se o demo nao sair em 12s, mata.
	var kill := get_tree().create_timer(12.0)
	kill.timeout.connect(func() -> void:
		push_error("[ver-onda3] timeout 12s")
		get_tree().quit(2)
	)


func _shot_mode() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--onda3-shot="):
			return arg.trim_prefix("--onda3-shot=").strip_edges()
	return ""