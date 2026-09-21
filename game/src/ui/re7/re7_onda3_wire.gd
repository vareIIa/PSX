## Re7Onda3Wire — stubs de integração Onda 3 (SEM editar prancha até GO WIRE do PO1).
## Uso futuro em prancha_inventario.gd (incremental, sem cutover grid):
##   1) exame/inspeção → mount_inspect() no lugar de _mostrar_vitrine auto-spin
##   2) polaroid/BEM   → mount_vitals() no lugar de _estado Label "BEM"
## Preservar tipografia 1b (fonte_re7). HARD: Sem Git · fora Casa da Fumaça · sem Godot agora.
class_name Re7Onda3Wire
extends RefCounted

const CENA_INSPECT := "res://src/ui/re7/inspect_viewport.tscn"
const CENA_VITALS := "res://src/ui/re7/vitals_monitor.tscn"

## Flag mental — prancha só liga quando PO1 der GO WIRE.
const WIRE_ENABLED := true


## Instancia ItemInspectViewport (órbita mouse/stick, damp 0.18s).
static func make_inspect() -> Control:
	var packed := load(CENA_INSPECT) as PackedScene
	if packed == null:
		push_error("[Re7Onda3Wire] inspect_viewport.tscn ausente")
		return null
	return packed.instantiate() as Control


## Instancia VitalsMonitor (LEDs emission/Tween por HP).
static func make_vitals() -> Control:
	var packed := load(CENA_VITALS) as PackedScene
	if packed == null:
		push_error("[Re7Onda3Wire] vitals_monitor.tscn ausente")
		return null
	return packed.instantiate() as Control


## Monta inspeção sob `host`, cobrindo a área da vitrine legado.
## Retorna o nó inspect (chamar enter/set_item no examine).
static func mount_inspect(host: Control, rect: Rect2) -> Control:
	var inspect := make_inspect()
	if inspect == null or host == null:
		return null
	inspect.name = "Re7Inspect"
	inspect.position = rect.position
	inspect.size = rect.size
	host.add_child(inspect)
	return inspect


## Monta vitals sob `host` na área do status/polaroid (Label BEM).
## Inventario.vida_mudou é ligado dentro do VitalsMonitor._ready.
static func mount_vitals(host: Control, rect: Rect2) -> Control:
	var vitals := make_vitals()
	if vitals == null or host == null:
		return null
	vitals.name = "Re7Vitals"
	vitals.position = rect.position
	vitals.size = rect.size
	host.add_child(vitals)
	return vitals


## Checklist GO WIRE (prancha_inventario.gd) — NÃO aplicar até liberação PO1:
## [ ] Em _examinar / examine: esconder _vitrine_view; inspect.enter(); inspect.set_item(id)
## [ ] Em fechar examine: inspect.exit(); restaurar vitrine idle se quiser
## [ ] Em _montar UI: esconder _estado (Label BEM); mount_vitals no Rect2 do status
## [ ] Opcional: manter moldura polaroid, só matar Corpo vivo + tipografia BEM
## [ ] NÃO tocar grid / scrapbook inteiro
## [ ] Diff → PO2 review (sem Godot até GO Jamerson)
static func wire_checklist() -> PackedStringArray:
	return PackedStringArray([
		"examinar → ItemInspectViewport.enter/set_item",
		"BEM/polaroid status → VitalsMonitor LEDs",
		"preservar fonte_re7 (Onda 1b)",
		"sem cutover grid",
		"diff para PO2; sem Godot",
	])