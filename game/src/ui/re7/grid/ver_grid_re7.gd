## Runner SUPPORT — captura isolada do grid (sem prancha).
## Uso:
##   .tools\Godot_..._console.exe --path game res://src/ui/re7/grid/ver_grid_re7.tscn -- --ver-grid-re7 --shot-quit
## Ou via cidade (main) + CaptureTool:
##   ... --path game -- --ver-grid-re7 --shot=<abs>/captures/ui/re7_dev/onda2_grid.png --shot-frame=90 --shot-quit
extends Node

const OUT_FALLBACK := "user://onda2_grid.png"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var quer := Re7GridSupport.cli_pediu_grid(args) or true
	# Sempre abre neste main-scene (é o propósito do runner).
	if quer:
		UIManager.abrir_inventario_grid(true, true)
	await get_tree().create_timer(0.85).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		push_error("[ver-grid-re7] viewport sem imagem")
		get_tree().quit(1)
		return
	var out_path := Re7GridSupport.caminho_capture_png()
	var dir := out_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var err := img.save_png(out_path)
	if err != OK:
		# fallback user://
		out_path = ProjectSettings.globalize_path(OUT_FALLBACK)
		err = img.save_png(out_path)
	if err != OK:
		push_error("[ver-grid-re7] falha save %s (%d)" % [out_path, err])
		get_tree().quit(1)
		return
	print("[ver-grid-re7] ok %s (%dx%d)" % [out_path, img.get_width(), img.get_height()])
	get_tree().quit(0)
