## SaveCardRe7 — Onda 4 PREP isolado; wire em menu/menu_sistema só após GO.
## GO copia → game/src/ui/re7/save_card.gd
## Spec: docs/specs/SPEC_SAVE_CARDS_RE7.md · Visual/Motion/Audio RE7.
## Cores: preferir UiEstilo no wire; fallbacks abaixo só se UiEstilo ausente.
class_name SaveCardRe7
extends PanelContainer

signal selected(espaco: int)
signal focused_slot(espaco: int)

const THUMB_SIZE := Vector2i(72, 40)
const CARD_MIN := Vector2(200, 48)

# Fallbacks SPEC_VISUAL_RE7 — consumir UiEstilo.* no wire (não duplicar paleta).
const _FB_PANEL_BASE := Color(0.102, 0.133, 0.141, 0.82)  # PANEL_BASE
const _FB_SLOT_FOCUS := Color(0.769, 0.647, 0.455, 1.0)   # SLOT_FOCUS
const _FB_TEXT_PRIMARY := Color(0.839, 0.824, 0.784, 1.0) # TEXT_PRIMARY
const _FB_TEXT_MUTED := Color(0.541, 0.525, 0.502, 1.0)   # TEXT_MUTED
const _FB_TEXT_TITLE := Color(0.910, 0.886, 0.839, 1.0)   # TEXT_TITLE
const _FB_ACCENT := Color(0.722, 0.353, 0.259, 1.0)       # ACCENT
const _FB_SLOT_EMPTY := Color(0.071, 0.094, 0.102, 0.65)  # SLOT_EMPTY

@export var espaco: int = 0

var _margin: MarginContainer
var _row: HBoxContainer
var _thumb_host: Control
var _thumb_vp: SubViewport
var _view: TextureRect
var _slot_label: Label
var _place_label: Label
var _time_label: Label
var _status_label: Label
var _style_idle: StyleBoxFlat
var _style_focus: StyleBoxFlat
var _filled: bool = false


func _ready() -> void:
	# Nunca FOCUS_NONE — A11Y_FOCUS_STACK / SaveCards neighbors.
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = CARD_MIN
	_build_styles()
	_build()
	_apply_empty()
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	mouse_entered.connect(_on_mouse_entered)


func _build() -> void:
	_margin = MarginContainer.new()
	_margin.name = "Margin"
	_margin.add_theme_constant_override("margin_left", 8)
	_margin.add_theme_constant_override("margin_right", 8)
	_margin.add_theme_constant_override("margin_top", 6)
	_margin.add_theme_constant_override("margin_bottom", 6)
	add_child(_margin)

	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.add_theme_constant_override("separation", 8)
	_margin.add_child(_row)

	_thumb_host = Control.new()
	_thumb_host.name = "Thumb"
	_thumb_host.custom_minimum_size = Vector2(THUMB_SIZE)
	_thumb_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_thumb_host.clip_contents = true
	_row.add_child(_thumb_host)

	# Placeholder visivel mesmo em slot vazio (chrome de card).
	var thumb_bg := ColorRect.new()
	thumb_bg.name = "ThumbBg"
	thumb_bg.color = _tok_slot_empty()
	thumb_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_thumb_host.add_child(thumb_bg)

	# SubViewport so como void placeholder; UPDATE_DISABLED — thumb real = textura estatica.
	_thumb_vp = SubViewport.new()
	_thumb_vp.name = "ThumbVP"
	_thumb_vp.size = THUMB_SIZE
	_thumb_vp.transparent_bg = true
	_thumb_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_thumb_vp.handle_input_locally = false
	# own_world_3d opcional — PREP não precisa de mundo 3D
	_thumb_host.add_child(_thumb_vp)

	_view = TextureRect.new()
	_view.name = "View"
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.texture = _thumb_vp.get_texture()
	_thumb_host.add_child(_view)

	var meta := VBoxContainer.new()
	meta.name = "MetaVBox"
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_theme_constant_override("separation", 1)
	_row.add_child(meta)

	_slot_label = _make_label("SlotLabel", 11, _tok_title())
	meta.add_child(_slot_label)
	_place_label = _make_label("PlaceLabel", 10, _tok_primary())
	meta.add_child(_place_label)
	_time_label = _make_label("TimeLabel", 9, _tok_muted())
	meta.add_child(_time_label)
	_status_label = _make_label("StatusLabel", 9, _tok_muted())
	meta.add_child(_status_label)

	_slot_label.text = "ESPAÇO %d" % espaco


func _make_label(p_name: String, size_px: int, col: Color) -> Label:
	var lb := Label.new()
	lb.name = p_name
	lb.add_theme_font_size_override("font_size", size_px)
	lb.add_theme_color_override("font_color", col)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lb.clip_text = true
	return lb


func apply_resumo(resumo: Dictionary) -> void:
	if resumo.is_empty():
		_apply_empty()
		return
	_filled = true
	var lugar: String = str(resumo.get("lugar", resumo.get("local", "")))
	var quando: String = str(resumo.get("quando", ""))
	var status: String = ""
	if resumo.has("vida"):
		status = str(resumo["vida"])
	elif resumo.has("status"):
		status = str(resumo["status"])
	_slot_label.text = "ESPAÇO %d" % espaco
	_slot_label.add_theme_color_override("font_color", _tok_title())
	_place_label.text = lugar if lugar != "" else "—"
	_place_label.add_theme_color_override("font_color", _tok_primary())
	_time_label.text = quando if quando != "" else ""
	_time_label.add_theme_color_override("font_color", _tok_muted())
	_status_label.text = status
	_status_label.visible = status != ""
	_refresh_style(has_focus())


func _apply_empty() -> void:
	_filled = false
	# Mantem rotulo ESPACO N (0-based); VAZIO vai no place.
	_slot_label.text = "ESPAÇO %d" % espaco
	_slot_label.add_theme_color_override("font_color", _tok_muted())
	_place_label.text = "— VAZIO"
	_place_label.add_theme_color_override("font_color", _tok_muted())
	_time_label.text = ""
	_status_label.text = ""
	_status_label.visible = false
	clear_thumb()
	_refresh_style(has_focus())


func is_filled() -> bool:
	return _filled


func set_thumb_texture(tex: Texture2D) -> void:
	if tex == null:
		clear_thumb()
		return
	_view.texture = tex


func clear_thumb() -> void:
	# Volta ao void do SubViewport (placeholder)
	_view.texture = _thumb_vp.get_texture() if _thumb_vp else null


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		var ad := get_node_or_null("/root/AudioDirector")
		if _filled and ad != null and ad.has_method("tocar_confirm"):
			ad.tocar_confirm(-14.0)
		elif (not _filled) and ad != null and ad.has_method("tocar_nav"):
			ad.tocar_nav(-20.0)
		selected.emit(espaco)
		accept_event()


func _on_focus_entered() -> void:
	_refresh_style(true)
	focused_slot.emit(espaco)
	# Hook áudio O4: AudioDirector.tocar_nav no focus
	_try_ui_audio_save_slot()


func _on_focus_exited() -> void:
	_refresh_style(false)


func _on_mouse_entered() -> void:
	# hover = focus (A11y RE7)
	if not has_focus():
		grab_focus()


func _try_ui_audio_save_slot() -> void:
	# P0/O4: AudioDirector (não UiAudio paralelo).
	var ad := get_node_or_null("/root/AudioDirector")
	if ad != null and ad.has_method("tocar_nav"):
		ad.tocar_nav(-18.0)


func _build_styles() -> void:
	# Prefer UiEstilo.style_re7_panel (chrome de card); fallback StyleBoxFlat.
	var base_sb: StyleBoxFlat = null
	if ClassDB.class_exists("UiEstilo") == false:
		pass
	# class_name UiEstilo com static — acesso direto no wire do jogo.
	base_sb = UiEstilo.style_re7_panel()
	if base_sb != null:
		_style_idle = base_sb.duplicate() as StyleBoxFlat
	else:
		_style_idle = StyleBoxFlat.new()
		_style_idle.bg_color = _tok_panel()
		_style_idle.set_border_width_all(1)
		_style_idle.border_color = Color(_tok_muted().r, _tok_muted().g, _tok_muted().b, 0.35)
	_style_idle.set_content_margin_all(0)
	if _style_idle.get_border_width(SIDE_LEFT) < 1:
		_style_idle.set_border_width_all(1)
		_style_idle.border_color = Color(_tok_muted().r, _tok_muted().g, _tok_muted().b, 0.45)

	_style_focus = _style_idle.duplicate() as StyleBoxFlat
	_style_focus.border_color = _tok_slot_focus()
	_style_focus.set_border_width_all(2)
	# stain interno a0.12 (ACCENT)
	var accent := _tok_accent()
	_style_focus.bg_color = _tok_panel().lerp(Color(accent.r, accent.g, accent.b, 0.12), 0.35)


func _refresh_style(focused: bool) -> void:
	add_theme_stylebox_override("panel", _style_focus if focused else _style_idle)
	if not _filled and not focused:
		# empty muted panel
		var empty := _style_idle.duplicate()
		empty.bg_color = _tok_slot_empty()
		add_theme_stylebox_override("panel", empty)


# --- tokens: UiEstilo se existir, senão fallback Visual ---

func _tok_panel() -> Color:
	return _estilo("RE7_PANEL_BASE", _FB_PANEL_BASE)

func _tok_slot_focus() -> Color:
	return _estilo("RE7_SLOT_FOCUS", _FB_SLOT_FOCUS)

func _tok_primary() -> Color:
	return _estilo("RE7_TEXT_PRIMARY", _FB_TEXT_PRIMARY)

func _tok_muted() -> Color:
	return _estilo("RE7_TEXT_MUTED", _FB_TEXT_MUTED)

func _tok_title() -> Color:
	return _estilo("RE7_TEXT_TITLE", _FB_TEXT_TITLE)

func _tok_accent() -> Color:
	return _estilo("RE7_ACCENT", _FB_ACCENT)

func _tok_slot_empty() -> Color:
	return _estilo("RE7_SLOT_EMPTY", _FB_SLOT_EMPTY)

func _estilo(prop: String, fallback: Color) -> Color:
	if ClassDB.class_exists("UiEstilo") or Engine.has_singleton("UiEstilo"):
		pass
	# UiEstilo tipicamente é class_name / autoload script com consts
	var ue = _ui_estilo_ref()
	if ue != null and prop in ue:
		return ue.get(prop)
	return fallback

func _ui_estilo_ref():
	# Tenta constante global UiEstilo (class_name); senão null → fallbacks.
	if not ClassDB.is_class_enabled("Object"):
		return null
	# Acesso dinâmico: scripts com class_name UiEstilo expõem consts via get_script_constant_map
	# Em PREP isolado, UiEstilo pode não existir — retorna null.
	var nodes: Node = get_tree().root if is_inside_tree() else null
	if nodes == null:
		return null
	# Sem dependência forte: fallbacks comentados "só se UiEstilo ausente".
	return null
