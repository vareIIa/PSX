class_name InventarioGridRE7
extends CanvasLayer

const SlotScr = preload("res://src/ui/inventory_slot_re7.gd")
const ItemScr = preload("res://src/ui/inventory_item_re7.gd")
const COLS := 8
const ROWS := 2
const STAGGER_S := 0.035
const GAP := 4.0

@export var demo_ao_ready: bool = true

var _raiz: Control
var _painel: ColorRect
var _titulo: Label
var _grid: GridContainer
var _slots: Array = []
var _ocupacao: PackedInt32Array = PackedInt32Array()
var _ultimo_focus: Vector2i = Vector2i.ZERO
var _hold_origem: Control = null
var _hold_item = null
var _stick_gate: MenuStickGate = MenuStickGate.new()


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("inventario_grid_re7")
	_ocupacao.resize(COLS * ROWS)
	for i in range(COLS * ROWS):
		_ocupacao[i] = -1
	_montar()
	print("[grid] montados=", _slots.size())
	if demo_ao_ready:
		_carregar_demo()
	_rebuild_focus_neighbors()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# Stick esquerdo → 1 passo neighbor (deadzone≥0.5). Right stick nao navega.
	if event is InputEventJoypadMotion:
		var st: Vector2i = _stick_gate.poll()
		if st != Vector2i.ZERO:
			_mover_focus_stick(st)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if _hold_item != null:
			_cancelar_hold()
		else:
			fechar()
		get_viewport().set_input_as_handled()


func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "Raiz"
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)

	_painel = ColorRect.new()
	_painel.name = "Painel"
	_painel.color = UiEstilo.RE7_PANEL_BASE
	_painel.position = Vector2(12, 28)
	_painel.size = Vector2(456, 90)
	_raiz.add_child(_painel)

	_titulo = Label.new()
	_titulo.name = "Titulo"
	_titulo.text = "INVENTÁRIO"
	_titulo.position = Vector2(8, -20)
	_titulo.size = Vector2(240, 18)
	UiEstilo.aplicar_re7(_titulo, UiEstilo.RE7_SIZE_DISPLAY, 600)
	_titulo.add_theme_color_override(&"font_color", UiEstilo.RE7_TEXT_TITLE)
	_painel.add_child(_titulo)

	_grid = GridContainer.new()
	_grid.name = "GridSlots"
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", int(GAP))
	_grid.add_theme_constant_override("v_separation", int(GAP))
	_grid.position = Vector2(16, 12)
	_painel.add_child(_grid)

	_slots.clear()
	_slots.resize(COLS * ROWS)
	for i in range(COLS * ROWS):
		var x: int = i % COLS
		var y: int = int(i / COLS)
		var slot: Control = SlotScr.new() as Control
		slot.call("configurar", x, y)
		slot.connect("drop_recebido", Callable(self, "_on_drop"))
		slot.connect("solicitado_pick", Callable(self, "_on_pick_teclado"))
		slot.focus_entered.connect(_on_slot_focus_entered.bind(slot))
		_grid.add_child(slot)
		_slots[i] = slot


func abrir() -> void:
	visible = true
	if UIManager != null:
		UIManager.push_menu(_raiz, true, &"inventario")
	_stagger_entrada()
	if _stick_gate != null:
		_stick_gate.reset()
	# SPEC §3.1: ultimo focus da sessao, senao 1o interagivel.
	var alvo: Control = _slot_em(_ultimo_focus.x, _ultimo_focus.y)
	if alvo == null or bool(alvo.get("coberta")) or alvo.focus_mode == Control.FOCUS_NONE:
		alvo = _primeiro_focavel()
	if alvo:
		alvo.grab_focus()


func foco_padrao() -> void:
	var alvo: Control = _slot_em(_ultimo_focus.x, _ultimo_focus.y)
	if alvo == null or bool(alvo.get("coberta")) or alvo.focus_mode == Control.FOCUS_NONE:
		alvo = _primeiro_focavel()
	if alvo:
		alvo.grab_focus()


func fechar() -> void:
	_cancelar_hold()
	if UIManager != null:
		UIManager.remove_menu(_raiz)
	visible = false


func _stagger_entrada() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	for i in range(_slots.size()):
		var s: Control = _slots[i]
		if s == null:
			continue
		s.modulate.a = 0.0
		tw.tween_property(s, "modulate:a", 1.0, 0.12).set_delay(STAGGER_S * float(i)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _idx(x: int, y: int) -> int:
	return y * COLS + x


func _slot_em(x: int, y: int) -> Control:
	if x < 0 or y < 0 or x >= COLS or y >= ROWS:
		return null
	var i := _idx(x, y)
	if i < 0 or i >= _slots.size():
		return null
	return _slots[i] as Control


func _primeiro_focavel() -> Control:
	for s in _slots:
		if s != null and not bool(s.get("coberta")):
			return s as Control
	return null


func _limpar_ocupacao() -> void:
	for i in range(_ocupacao.size()):
		_ocupacao[i] = -1
	for s in _slots:
		if s != null:
			s.call("definir_item", null)


func _size_of(item) -> Vector2i:
	return item.get("size_cells") as Vector2i


func _colocar(ancora: Control, item) -> bool:
	if item == null or not bool(item.call("tamanho_valido")):
		return false
	var sz: Vector2i = _size_of(item)
	var ax := int(ancora.get("grid_x"))
	var ay := int(ancora.get("grid_y"))
	if not _cabe(ax, ay, sz, -1):
		return false
	var ai := _idx(ax, ay)
	for oy in range(sz.y):
		for ox in range(sz.x):
			var cell: Control = _slot_em(ax + ox, ay + oy)
			_ocupacao[_idx(ax + ox, ay + oy)] = ai
			if ox == 0 and oy == 0:
				cell.call("definir_item", item)
			else:
				cell.call("marcar_cobertura")
	return true


func _cabe(x: int, y: int, size: Vector2i, ignorar: int) -> bool:
	if x + size.x > COLS or y + size.y > ROWS:
		return false
	for oy in range(size.y):
		for ox in range(size.x):
			var dono: int = _ocupacao[_idx(x + ox, y + oy)]
			if dono != -1 and dono != ignorar:
				return false
	return true


func pode_dropar(origem: Control, destino: Control, item) -> bool:
	if item == null or destino == null or bool(destino.get("coberta")):
		return false
	var ign := -1
	if origem != null:
		ign = _idx(int(origem.get("grid_x")), int(origem.get("grid_y")))
	return _cabe(int(destino.get("grid_x")), int(destino.get("grid_y")), _size_of(item), ign)


func _on_drop(origem: Control, destino: Control) -> void:
	var item = origem.get("item_ref")
	if item == null or not pode_dropar(origem, destino, item):
		return
	_remover_ancora(origem)
	_colocar(destino, item)
	_rebuild_focus_neighbors()
	destino.grab_focus()


func _remover_ancora(ancora: Control) -> void:
	var item = ancora.get("item_ref")
	if item == null:
		return
	var ax := int(ancora.get("grid_x"))
	var ay := int(ancora.get("grid_y"))
	var ai := _idx(ax, ay)
	var sz: Vector2i = _size_of(item)
	for oy in range(sz.y):
		for ox in range(sz.x):
			var si := _idx(ax + ox, ay + oy)
			if _ocupacao[si] == ai:
				_ocupacao[si] = -1
				_slot_em(ax + ox, ay + oy).call("definir_item", null)


func _on_pick_teclado(slot: Control) -> void:
	if slot == null or bool(slot.get("coberta")):
		return
	if _hold_item == null:
		var cur = slot.get("item_ref")
		if cur == null:
			slot.grab_focus()
			return
		_hold_origem = slot
		_hold_item = cur
		slot.modulate = Color(1.2, 1.15, 0.9, 0.85)
		slot.grab_focus()
		return
	if not pode_dropar(_hold_origem, slot, _hold_item):
		return
	var origem := _hold_origem
	var item = _hold_item
	_hold_origem = null
	_hold_item = null
	if origem != null:
		origem.modulate = Color.WHITE
		_remover_ancora(origem)
	_colocar(slot, item)
	_rebuild_focus_neighbors()
	slot.grab_focus()


func _cancelar_hold() -> void:
	if _hold_origem != null:
		_hold_origem.modulate = Color.WHITE
		_hold_origem.grab_focus()
	_hold_origem = null
	_hold_item = null


func _rebuild_focus_neighbors() -> void:
	for s in _slots:
		var c: Control = s as Control
		if c == null:
			continue
		c.focus_neighbor_left = NodePath("")
		c.focus_neighbor_right = NodePath("")
		c.focus_neighbor_top = NodePath("")
		c.focus_neighbor_bottom = NodePath("")
		if bool(c.get("coberta")):
			c.focus_mode = Control.FOCUS_NONE
			continue
		c.focus_mode = Control.FOCUS_ALL
		var gx := int(c.get("grid_x"))
		var gy := int(c.get("grid_y"))
		var L := _vizinho_livre(gx, gy, -1, 0)
		var R := _vizinho_livre(gx, gy, 1, 0)
		var U := _vizinho_livre(gx, gy, 0, -1)
		var D := _vizinho_livre(gx, gy, 0, 1)
		if L: c.focus_neighbor_left = c.get_path_to(L)
		if R: c.focus_neighbor_right = c.get_path_to(R)
		if U: c.focus_neighbor_top = c.get_path_to(U)
		if D: c.focus_neighbor_bottom = c.get_path_to(D)


func _vizinho_livre(x: int, y: int, dx: int, dy: int) -> Control:
	var cx := x + dx
	var cy := y + dy
	while cx >= 0 and cy >= 0 and cx < COLS and cy < ROWS:
		var s := _slot_em(cx, cy)
		if s != null and not bool(s.get("coberta")):
			return s
		cx += dx
		cy += dy
	return null


func _on_slot_focus_entered(slot: Control) -> void:
	if slot == null:
		return
	_ultimo_focus = Vector2i(int(slot.get("grid_x")), int(slot.get("grid_y")))


func _mover_focus_stick(st: Vector2i) -> void:
	var cur := get_viewport().gui_get_focus_owner()
	if cur == null or not (cur in _slots):
		var a := _primeiro_focavel()
		if a:
			a.grab_focus()
		return
	var gx := int(cur.get("grid_x"))
	var gy := int(cur.get("grid_y"))
	var nxt: Control = null
	if st.x < 0:
		nxt = _vizinho_livre(gx, gy, -1, 0)
	elif st.x > 0:
		nxt = _vizinho_livre(gx, gy, 1, 0)
	elif st.y < 0:
		nxt = _vizinho_livre(gx, gy, 0, -1)
	elif st.y > 0:
		nxt = _vizinho_livre(gx, gy, 0, 1)
	if nxt != null:
		nxt.grab_focus()


func _carregar_demo() -> void:
	_limpar_ocupacao()
	# So 1x1 no demo pra caber sem depender de icones; multi-slot via lanterna/radio se IDs existirem
	# Multi-slot bem visivel no print (PO2 opcional)
	var demo: Array = [
		[&"lanterna", Vector2i(1, 2)],
		[&"arma", Vector2i(2, 1)],
		[&"radio", Vector2i(2, 2)],
		[&"fita", Vector2i(1, 1)],
		[&"bateria", Vector2i(1, 1)],
		[&"chave", Vector2i(1, 1)],
	]
	for entry in demo:
		var id: StringName = entry[0]
		var sz: Vector2i = entry[1]
		var placed := false
		for y in range(ROWS):
			for x in range(COLS):
				var slot := _slot_em(x, y)
				if slot == null or not bool(slot.call("esta_livre")):
					continue
				var wrap = ItemScr.new()
				wrap.set("item_id", id)
				wrap.set("size_cells", sz)
				if _colocar(slot, wrap):
					placed = true
					break
			if placed:
				break
	_rebuild_focus_neighbors()