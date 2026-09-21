class_name InventoryItemRE7
extends Resource

@export var item_id: StringName = &""
@export var size_cells: Vector2i = Vector2i(1, 1)
@export var icone_override: Texture2D

func tamanho_valido() -> bool:
	return size_cells.x >= 1 and size_cells.y >= 1


func resolver_icone() -> Texture2D:
	if icone_override != null:
		return icone_override
	if item_id == &"":
		return null
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var inv := tree.root.get_node_or_null("Inventario")
	if inv == null or not inv.has_method("definicao"):
		return null
	var def = inv.call("definicao", item_id)
	if def == null:
		return null
	return def.icone