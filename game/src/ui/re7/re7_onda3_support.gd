## SUPPORT Onda 3 — wiring/captura inspect + vitals RE7.
## NÃO edita inspect_viewport / vitals_monitor (Diegetic LEAD).
## NÃO toca prancha_inventario.gd.
## Demo Diegetic: res://scenes/ui/re7_inspect_vitals_demo.tscn
class_name Re7Onda3Support
extends RefCounted

const CENA_DEMO := "res://scenes/ui/re7_inspect_vitals_demo.tscn"
const CENA_INSPECT := "res://src/ui/re7/inspect_viewport.tscn"
const CENA_VITALS := "res://src/ui/re7/vitals_monitor.tscn"
const CAPTURE_DIR_REL := "captures/ui/re7_dev"
const FLAG_INSPECT := "--ver-inspect-re7"
const FLAG_VITALS := "--ver-vitals-re7"
const DEFAULT_ITEM := &"lanterna"


## Repo-root captures/ui/re7_dev (res:// == game/).
static func dir_capture() -> String:
	var base := ProjectSettings.globalize_path("res://").rstrip("/\\")
	var parent := base.get_base_dir()
	return parent.path_join(CAPTURE_DIR_REL).replace("\\", "/")


static func caminho_png(nome: String) -> String:
	return dir_capture().path_join(nome).replace("\\", "/")


static func cli_pediu_inspect(args: PackedStringArray = PackedStringArray()) -> bool:
	if args.is_empty():
		args = OS.get_cmdline_user_args()
	for a: String in args:
		if a == FLAG_INSPECT or a.begins_with(FLAG_INSPECT + "="):
			return true
	return false


## Retorna "" | "ok" | "warn" | "crit". Vazio = não pediu.
static func cli_vitals_band(args: PackedStringArray = PackedStringArray()) -> String:
	if args.is_empty():
		args = OS.get_cmdline_user_args()
	for a: String in args:
		if a == FLAG_VITALS:
			return "ok"
		if a.begins_with(FLAG_VITALS + "="):
			var v := a.trim_prefix(FLAG_VITALS + "=").strip_edges().to_lower()
			if v in ["ok", "warn", "crit", "dead"]:
				return v
			return "ok"
	return ""


static func cli_pediu_vitals(args: PackedStringArray = PackedStringArray()) -> bool:
	return cli_vitals_band(args) != ""


static func ratio_for_band(band: String) -> float:
	match band:
		"ok":
			return 1.0
		"warn":
			return 0.55
		"crit":
			return 0.2
		"dead":
			return 0.0
		_:
			return 1.0


static func arquivo_inspect() -> String:
	return "onda3_inspect.png"


static func arquivo_vitals(band: String) -> String:
	match band:
		"ok":
			return "onda3_vitals_ok.png"
		"warn":
			return "onda3_vitals_warn.png"
		"crit":
			return "onda3_vitals_crit.png"
		"dead":
			return "onda3_vitals_dead.png"
		_:
			return "onda3_vitals.png"


## Alias genérico também escrito como onda3_vitals.png (banda ok).
static func arquivo_vitals_primary(band: String) -> String:
	if band == "ok" or band == "":
		return "onda3_vitals.png"
	return arquivo_vitals(band)
