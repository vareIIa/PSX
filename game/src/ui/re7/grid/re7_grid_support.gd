## SUPPORT Onda 2 — wiring/captura do inventário grid RE7.
## NÃO é o grid em si (Grid LEAD: res://src/ui/inventario_grid_re7.*).
## Diegetic (inspect/vitals) fica em re7/ irmão — não misturar.
class_name Re7GridSupport
extends RefCounted

const CENA := "res://src/ui/inventario_grid_re7.tscn"
const CAPTURE_REL := "captures/ui/re7_dev/onda2_grid.png"
const FLAG_CLI := "--ver-grid-re7"


## Caminho absoluto do PNG de aceite Onda 2 (repo root /captures/...).
static func caminho_capture_png() -> String:
	# project root = res:// == game/; captures ficam em ../captures no monorepo.
	var base := ProjectSettings.globalize_path("res://").rstrip("/\\")
	var parent := base.get_base_dir()
	return parent.path_join(CAPTURE_REL).replace("\\", "/")


static func cli_pediu_grid(args: PackedStringArray = PackedStringArray()) -> bool:
	if args.is_empty():
		args = OS.get_cmdline_user_args()
	for a: String in args:
		if a == FLAG_CLI or a.begins_with(FLAG_CLI + "="):
			return true
	return false


## Abre via UIManager com force (ignora UiEstilo.RE7_GRID=false).
static func abrir_para_capture() -> Node:
	return UIManager.abrir_inventario_grid(true, true)
