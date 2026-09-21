class_name InventorySlotRE7
extends Control

signal solicitado_pick(slot)
signal drop_recebido(origem, destino)

const CELL_VISUAL := 28.0
const HIT_MIN := 32.0
## cores via UiEstilo em _atualizar_visual


var grid_x: int = 0
var grid_y: int = 0
var coberta: bool = false
var item_ref = null

var _fundo: ColorRect
var _icone: TextureRect


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(HIT_MIN, HIT_MIN)
	_montar_visual()
	focus_entered.connect(_atualizar_visual)
	focus_exited.connect(_atualizar_visual)
	# A11Y §5 hover = focus (parity D-pad).
	mouse_entered.connect(_on_mouse_entered_focus)
	_atualizar_visual()


func _on_mouse_entered_focus() -> void:
	if coberta:
		return
	if focus_mode == Control.FOCUS_NONE:
		return
	if not has_focus():
		grab_focus()


func _montar_visual() -> void:
	_fundo = ColorRect.new()
	_fundo.name = "Fundo"
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fundo)
	_icone = TextureRect.new()
	_icone.name = "Icone"
	_icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icone.position = Vector2((HIT_MIN - CELL_VISUAL) * 0.5, (HIT_MIN - CELL_VISUAL) * 0.5)
	_icone.size = Vector2(CELL_VISUAL, CELL_VISUAL)
	add_child(_icone)


func configurar(gx: int, gy: int) -> void:
	grid_x = gx
	grid_y = gy
	name = "Slot_%d_%d" % [gx, gy]


func definir_item(item) -> void:
	item_ref = item
	coberta = false
	if _icone == null:
		return
	if item == null:
		_icone.texture = null
	elif item.has_method("resolver_icone"):
		_icone.texture = item.call("resolver_icone")
	_atualizar_visual()


func marcar_cobertura() -> void:
	item_ref = null
	coberta = true
	if _icone:
		_icone.texture = null
	_atualizar_visual()


func esta_livre() -> bool:
	return item_ref == null and not coberta


func _atualizar_visual() -> void:
	if _fundo == null:
		return
	if coberta:
		_fundo.color = Color(UiEstilo.RE7_SLOT_FILL.r, UiEstilo.RE7_SLOT_FILL.g, UiEstilo.RE7_SLOT_FILL.b, 0.55)
	elif item_ref != null:
		_fundo.color = UiEstilo.RE7_SLOT_FILL
	else:
		_fundo.color = UiEstilo.RE7_SLOT_EMPTY
	if has_focus() and not coberta:
		_fundo.color = _fundo.color.lerp(UiEstilo.RE7_SLOT_FOCUS, 0.18)


func _gui_input(event: InputEvent) -> void:
	if coberta:
		return
	if event.is_action_pressed("ui_accept"):
		solicitado_pick.emit(self)
		accept_event()


func _get_drag_data(_at_position: Vector2):
	if coberta or item_ref == null:
		return null
	var preview := TextureRect.new()
	if item_ref.has_method("resolver_icone"):
		preview.texture = item_ref.call("resolver_icone")
	preview.custom_minimum_size = Vector2(CELL_VISUAL, CELL_VISUAL)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return {"origem": self, "item": item_ref}


func _can_drop_data(_at_position: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY or coberta:
		return false
	var origem = data.get("origem")
	if origem == null or origem == self:
		return false
	var layer = get_tree().get_first_node_in_group("inventario_grid_re7")
	if layer != null and layer.has_method("pode_dropar"):
		return layer.call("pode_dropar", origem, self, data.get("item"))
	return esta_livre()


func _drop_data(_at_position: Vector2, data) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var origem = data.get("origem")
	if origem != null:
		drop_recebido.emit(origem, self)