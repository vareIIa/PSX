## SaveCardsPanelRe7 — Onda 4 · wired em MenuSistema pagina CARREGAR.
## Spec: docs/specs/SPEC_SAVE_CARDS_RE7.md · sinais legado pediu_carregar / pediu_voltar.
class_name SaveCardsPanelRe7
extends MarginContainer

signal pediu_carregar(espaco: int)
signal pediu_voltar()

const SLOT_COUNT := 3

var _root_vbox: VBoxContainer
var _cards: Array[SaveCardRe7] = []
var _voltar: Button
var _hints: Label


func _ready() -> void:
	add_theme_constant_override("margin_left", 8)
	add_theme_constant_override("margin_right", 8)
	add_theme_constant_override("margin_top", 8)
	add_theme_constant_override("margin_bottom", 8)
	custom_minimum_size = Vector2(220, 200)
	_build()
	refresh_from_savegame()
	_wire_focus_neighbors()
	call_deferred("_focus_default")


func _build() -> void:
	_root_vbox = VBoxContainer.new()
	_root_vbox.name = "RootVBox"
	_root_vbox.add_theme_constant_override("separation", 6)
	add_child(_root_vbox)

	var title := Label.new()
	title.name = "Title"
	title.text = "CARREGAR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	# TEXT_TITLE — consumir UiEstilo no wire
	title.add_theme_color_override("font_color", Color(0.910, 0.886, 0.839, 1.0))
	_root_vbox.add_child(title)

	var cards_vbox := VBoxContainer.new()
	cards_vbox.name = "CardsVBox"
	cards_vbox.add_theme_constant_override("separation", 4)
	_root_vbox.add_child(cards_vbox)

	for i in SLOT_COUNT:
		var card := SaveCardRe7.new()
		card.name = "SaveCardRe7_%d" % i
		card.espaco = i
		card.selected.connect(_on_card_selected)
		card.focused_slot.connect(_on_card_focused)
		cards_vbox.add_child(card)
		_cards.append(card)

	_voltar = Button.new()
	_voltar.name = "Voltar"
	_voltar.text = "VOLTAR"
	_voltar.focus_mode = Control.FOCUS_ALL
	_voltar.custom_minimum_size = Vector2(0, 32)
	_voltar.pressed.connect(_on_voltar_pressed)
	_root_vbox.add_child(_voltar)

	_hints = Label.new()
	_hints.name = "Hints"
	_hints.text = "[A] carregar  ·  [B] voltar"
	_hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hints.add_theme_font_size_override("font_size", 9)
	_hints.add_theme_color_override("font_color", Color(0.541, 0.525, 0.502, 1.0))  # TEXT_MUTED fb
	_root_vbox.add_child(_hints)


func refresh_from_savegame() -> void:
	var sg := _save_game()
	for i in SLOT_COUNT:
		var resumo: Dictionary = {}
		if sg != null and sg.has_method("resumo"):
			var r = sg.resumo(i)
			if r is Dictionary:
				resumo = r
		else:
			resumo = _demo_resumo(i)
		_cards[i].apply_resumo(resumo)
		# Thumb local se existir (SaveThumbCapture); senão placeholder
		var tex: Texture2D = SaveThumbCapture.load_thumb_local(i)
		if tex != null:
			_cards[i].set_thumb_texture(tex)
		else:
			_cards[i].clear_thumb()


func _demo_resumo(espaco: int) -> Dictionary:
	# Demo isolada quando SaveGame ausente (PREP / headless).
	if espaco == 0:
		return {
			"quando": "2026-09-18T21:04:00",
			"lugar": "TELEFONE DA R…",
			"status": "ESTÁVEL",
		}
	if espaco == 1:
		return {
			"quando": "2026-09-17T14:22:11",
			"local": "PORÃO",
		}
	return {}  # slot 2 VAZIO


func _save_game() -> Node:
	return get_node_or_null("/root/SaveGame")


func _on_card_selected(espaco: int) -> void:
	pediu_carregar.emit(espaco)


func _on_card_focused(_espaco: int) -> void:
	pass  # áudio no card (tocar_nav)


func _on_voltar_pressed() -> void:
	var ad := get_node_or_null("/root/AudioDirector")
	if ad != null and ad.has_method("tocar_nav"):
		ad.tocar_nav(-18.0)
	pediu_voltar.emit()


func _wire_focus_neighbors() -> void:
	for i in SLOT_COUNT:
		var prev: Control = _cards[i - 1] if i > 0 else _voltar
		var next: Control = _cards[i + 1] if i < SLOT_COUNT - 1 else _voltar
		_cards[i].focus_mode = Control.FOCUS_ALL
		_cards[i].focus_neighbor_top = _cards[i].get_path_to(prev)
		_cards[i].focus_neighbor_bottom = _cards[i].get_path_to(next)
		# Left/right: loop vertical (card↔card / card↔voltar) — gap fill A11Y_FOCUS_STACK.
		_cards[i].focus_neighbor_left = _cards[i].get_path_to(prev)
		_cards[i].focus_neighbor_right = _cards[i].get_path_to(next)
	_voltar.focus_mode = Control.FOCUS_ALL
	_voltar.focus_neighbor_top = _voltar.get_path_to(_cards[SLOT_COUNT - 1])
	_voltar.focus_neighbor_bottom = _voltar.get_path_to(_cards[0])
	_voltar.focus_neighbor_left = _voltar.get_path_to(_cards[SLOT_COUNT - 1])
	_voltar.focus_neighbor_right = _voltar.get_path_to(_cards[0])


func foco_padrao() -> void:
	_focus_default()


func _focus_default() -> void:
	# Primeiro não-vazio; senão card 0
	for card in _cards:
		if card.is_filled():
			card.grab_focus()
			return
	if _cards.size() > 0:
		_cards[0].grab_focus()
