## VitalsMonitor — Onda 3 PREP. Substitui polaroid / tipografia BEM.
## Spec: SPEC_INSPECT_VITALS_RE7 · SPEC_VISUAL_RE7 §5.4 · SPEC_MOTION_RE7 §6.
class_name VitalsMonitor
extends Control

enum Band { OK, WARN, CRIT, DEAD }

const LED_COUNT := 5
const LED_SIZE := Vector2(6, 4)
const LED_GAP := 2.0

@export var manual_ratio: float = -1.0  ## <0 = ler Inventario; ≥0 = override (demo)

var _leds: Array[ColorRect] = []
var _mats_proxy: Array[ColorRect] = []  # ColorRect.modulate = emission stand-in
var _band: Band = Band.OK
var _pulse: Tween
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(48, 28)
	_build()
	_bind_inventario()
	refresh()


func _build() -> void:
	var row := HBoxContainer.new()
	row.name = "LedRow"
	row.add_theme_constant_override("separation", int(LED_GAP))
	row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	row.position = Vector2(0, 4)
	add_child(row)

	for i in LED_COUNT:
		var led := ColorRect.new()
		led.name = "Led%d" % i
		led.custom_minimum_size = LED_SIZE
		led.size = LED_SIZE
		led.color = Color(UiEstilo.RE7_VITAL_OK.r, UiEstilo.RE7_VITAL_OK.g, UiEstilo.RE7_VITAL_OK.b, 0.15)
		row.add_child(led)
		_leds.append(led)
		_mats_proxy.append(led)

	_label = Label.new()
	_label.name = "MicroLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", UiEstilo.RE7_SIZE_MICRO)
	_label.add_theme_color_override("font_color", UiEstilo.RE7_TEXT_MUTED)
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_label.offset_top = -14
	_label.text = ""
	add_child(_label)


func _bind_inventario() -> void:
	if Engine.is_editor_hint():
		return
	var inv := _inventario()
	if inv != null and inv.has_signal("vida_mudou"):
		if not inv.vida_mudou.is_connected(_on_vida_mudou):
			inv.vida_mudou.connect(_on_vida_mudou)


func _inventario() -> Node:
	# Autoload Inventario (systems/inventario.gd).
	return get_node_or_null("/root/Inventario")


func _on_vida_mudou(_atual: int, _maximo: int) -> void:
	refresh()


func set_ratio(ratio: float) -> void:
	manual_ratio = clampf(ratio, 0.0, 1.0)
	refresh()


func refresh() -> void:
	var r := _ratio()
	_band = _band_for(r)
	var lit := _lit_count(r)
	var col := _color_for(_band)
	for i in LED_COUNT:
		var on := i < lit and _band != Band.DEAD
		var target_a := 1.0 if on else 0.12
		_leds[i].color = Color(col.r, col.g, col.b, target_a)
	_label.text = _micro_for(_band)
	_restart_pulse()


func _ratio() -> float:
	if manual_ratio >= 0.0:
		return clampf(manual_ratio, 0.0, 1.0)
	var inv := _inventario()
	if inv == null:
		return 1.0
	var vmax: int = int(inv.get("vida_maxima"))
	var v: int = int(inv.get("vida"))
	return float(v) / float(maxi(1, vmax))


func _band_for(r: float) -> Band:
	if r <= 0.0:
		return Band.DEAD
	if r >= 0.75:
		return Band.OK
	if r >= 0.4:
		return Band.WARN
	return Band.CRIT


func _lit_count(r: float) -> int:
	if r <= 0.0:
		return 0
	return clampi(ceili(r * float(LED_COUNT)), 1, LED_COUNT)


func _color_for(b: Band) -> Color:
	match b:
		Band.OK:
			return UiEstilo.RE7_VITAL_OK
		Band.WARN:
			return UiEstilo.RE7_VITAL_WARN
		Band.CRIT:
			return UiEstilo.RE7_VITAL_CRIT
		_:
			return Color(0.2, 0.2, 0.22)


func _micro_for(b: Band) -> String:
	# Micro-label opcional — LED é primário (Visual §5.4).
	match b:
		Band.OK:
			return "ESTÁVEL"
		Band.WARN:
			return "FERIDO"
		Band.CRIT:
			return "GRAVE"
		_:
			return ""


func _restart_pulse() -> void:
	if _pulse != null:
		_pulse.kill()
		_pulse = null
	if _band == Band.OK or _band == Band.DEAD:
		modulate = Color.WHITE
		return
	var period := 1.2 if _band == Band.WARN else 0.6
	_pulse = create_tween().set_loops()
	_pulse.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(self, "modulate:a", 0.7, period * 0.5)
	_pulse.tween_property(self, "modulate:a", 1.0, period * 0.5)
