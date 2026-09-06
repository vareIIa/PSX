## Autoload. Captura automatizada de tela para validar o look sem olho humano
## no loop.
##
## Existe porque `--headless` nao compila shader: o unico jeito de provar que o
## psx_surface e o post_psx funcionam de verdade e abrir uma janela, renderizar
## alguns frames e gravar o resultado. E o nivel 3 de validacao descrito em
## docs/PADROES-ENGENHARIA.md.
##
##     godot --path game -- --shot=out.png --shot-frame=30 --shot-quit
##
## `--shot-frame` precisa ser generoso: shader compila no primeiro uso e o
## primeiro frame sai sem ele.
extends Node

const DEFAULT_FRAME := 30

var _target_path: String = ""
var _target_frame: int = DEFAULT_FRAME
var _quit_after: bool = false
var _frames: int = 0
var _done: bool = false


func _ready() -> void:
	_parse_args(OS.get_cmdline_user_args())
	if _target_path.is_empty():
		set_process(false)
		return
	print("[capture] gravando %s no frame %d" % [_target_path, _target_frame])


func _parse_args(args: PackedStringArray) -> void:
	for arg: String in args:
		if arg.begins_with("--shot="):
			_target_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--shot-frame="):
			_target_frame = maxi(1, arg.trim_prefix("--shot-frame=").to_int())
		elif arg == "--shot-quit":
			_quit_after = true


func _process(_delta: float) -> void:
	if _done:
		return
	_frames += 1
	if _frames < _target_frame:
		return
	_done = true
	_capture()


func _capture() -> void:
	# Espera o fim do desenho do frame corrente, senao a textura vem do anterior.
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_error("[capture] viewport nao devolveu imagem")
		_finish(1)
		return

	var dir := _target_path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	var err := image.save_png(_target_path)
	if err != OK:
		push_error("[capture] falha ao gravar %s (erro %d)" % [_target_path, err])
		_finish(1)
		return

	print("[capture] ok %s (%dx%d)" % [_target_path, image.get_width(), image.get_height()])
	_finish(0)


func _finish(code: int) -> void:
	if _quit_after:
		get_tree().quit(code)
