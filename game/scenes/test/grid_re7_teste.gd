extends Node

const _ITEM := preload("res://src/ui/inventory_item_re7.gd")
const _SLOT := preload("res://src/ui/inventory_slot_re7.gd")
const _GRID := preload("res://src/ui/inventario_grid_re7.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var _a = _ITEM
	var _b = _SLOT
	var grid: CanvasLayer = _GRID.new() as CanvasLayer
	grid.set("demo_ao_ready", true)
	add_child(grid)
	await get_tree().process_frame
	await get_tree().process_frame
	if grid.has_method("abrir"):
		grid.call("abrir")
	await get_tree().create_timer(0.25).timeout
	# Garante focus no primeiro slot para o print
	var slots = grid.get_node_or_null("Raiz/Painel/GridSlots")
	if slots and slots.get_child_count() > 0:
		var first: Control = slots.get_child(0)
		first.grab_focus()