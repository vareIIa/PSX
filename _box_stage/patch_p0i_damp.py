from pathlib import Path
path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\re7\inspect_viewport.gd")
text = path.read_text(encoding="utf-8")

# Replace SPIN_HALF_LIFE comment to tie to token
text = text.replace(
    "const SPIN_HALF_LIFE := 0.18",
    "const SPIN_HALF_LIFE := 0.18  ## ~T_RE7_SPIN_DAMP/2 (SPEC_MOTION_RE7 §5)"
)

old_ready = """func _ready() -> void:\n\tmouse_filter = Control.MOUSE_FILTER_STOP\n\tfocus_mode = Control.FOCUS_ALL\n\tcustom_minimum_size = Vector2(VIEW_SIZE)\n\t_decay = log(2.0) / SPIN_HALF_LIFE\n\t_build()\n\tset_process(false)\n\tset_process_unhandled_input(false)\n"""

new_ready = """func _ready() -> void:\n\tmouse_filter = Control.MOUSE_FILTER_STOP\n\tfocus_mode = Control.FOCUS_ALL\n\tcustom_minimum_size = Vector2(VIEW_SIZE)\n\t# half-life ~0,18s; janela visível ≈ UiEstilo.T_RE7_SPIN_DAMP (0,28–0,40).\n\tvar half := SPIN_HALF_LIFE\n\tif Engine.get_main_loop() != null:\n\t\thalf = maxf(0.12, UiEstilo.T_RE7_SPIN_DAMP * 0.5)\n\t_decay = log(2.0) / half\n\t_build()\n\tscale = Vector3(1, 1, 1) if false else Vector2.ONE\n\tset_process(false)\n\tset_process_unhandled_input(false)\n"""
# Fix the silly Vector3 line - use Vector2.ONE only
new_ready = """func _ready() -> void:\n\tmouse_filter = Control.MOUSE_FILTER_STOP\n\tfocus_mode = Control.FOCUS_ALL\n\tcustom_minimum_size = Vector2(VIEW_SIZE)\n\t# half-life ~0,18s; janela visível ≈ UiEstilo.T_RE7_SPIN_DAMP (0,28–0,40).\n\tvar half := maxf(0.12, UiEstilo.T_RE7_SPIN_DAMP * 0.5)\n\t_decay = log(2.0) / half\n\t_build()\n\tscale = Vector2.ONE\n\tset_process(false)\n\tset_process_unhandled_input(false)\n"""

if old_ready not in text:
    raise SystemExit("ready block not found")
text = text.replace(old_ready, new_ready, 1)

old_enter = """func enter() -> void:\n\t_active = true\n\t_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS\n\tset_process(true)\n\tset_process_unhandled_input(true)\n\tgrab_focus()\n"""

new_enter = """func enter() -> void:\n\t_active = true\n\t_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS\n\tset_process(true)\n\tset_process_unhandled_input(true)\n\tgrab_focus()\n\t# Enter: viewport scale 0,96→1 em T_RE7_PANEL (EXPO out). Sem BACK/ELASTIC.\n\tscale = Vector2(0.96, 0.96)\n\tif _item_slot != null:\n\t\t_item_slot.scale = Vector3(0.96, 0.96, 0.96)\n\tvar tw := create_tween()\n\ttw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)\n\ttw.set_parallel(true)\n\ttw.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)\n\ttw.tween_property(self, \"scale\", Vector2.ONE, UiEstilo.T_RE7_PANEL)\n\tif _item_slot != null:\n\t\ttw.tween_property(_item_slot, \"scale\", Vector3.ONE, UiEstilo.T_RE7_PANEL)\n"""

if old_enter not in text:
    raise SystemExit("enter block not found")
text = text.replace(old_enter, new_enter, 1)

old_exit = """func exit() -> void:\n\t_active = false\n\t_dragging = false\n\t_omega_yaw = 0.0\n\t_omega_pitch = 0.0\n\t_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED\n\tset_process(false)\n\tset_process_unhandled_input(false)\n\tclosed.emit()\n"""

new_exit = """func exit() -> void:\n\t# Exit: matar ω imediatamente; fechar em T_RE7_CLOSE (EXPO in). Sem elastic.\n\t_active = false\n\t_dragging = false\n\t_omega_yaw = 0.0\n\t_omega_pitch = 0.0\n\tset_process(false)\n\tset_process_unhandled_input(false)\n\tvar tw := create_tween()\n\ttw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)\n\ttw.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)\n\ttw.tween_property(self, \"scale\", Vector2(0.96, 0.96), UiEstilo.T_RE7_CLOSE)\n\ttw.tween_callback(func() -> void:\n\t\t_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED\n\t\tscale = Vector2.ONE\n\t\tif _item_slot != null:\n\t\t\t_item_slot.scale = Vector3.ONE\n\t\tclosed.emit()\n\t)\n"""

if old_exit not in text:
    raise SystemExit("exit block not found")
text = text.replace(old_exit, new_exit, 1)

# Ensure damp comment in _process
text = text.replace(
    "\telif not _dragging:\n\t\tvar damp := exp(-_decay * delta)",
    "\telif not _dragging:\n\t\t# Spin damp: ω *= e^(-λΔt), λ=ln2/half_life — SPEC_MOTION_RE7 §5 (sem BACK/ELASTIC).\n\t\tvar damp := exp(-_decay * delta)"
)

path.write_text(text, encoding="utf-8")
print("inspect patched")