## Compila scripts COM os autoloads carregados, sem janela e sem cenario.
##
##     godot --headless --path game res://tests/checar_scripts.tscn -- --arquivo=res://src/render/corpo.gd ...
##
## O `--check-only --script` para no primeiro autoload que o arquivo (ou um
## script de que ele depende) cita, com "Identifier not found", e nunca chega ao
## erro de verdade: um `.map` num PackedStringArray passou por ele e abriu uma
## janela cinza que ficou parada ate alguem fechar. Aqui a arvore ja tem os
## autoloads, e o erro que aparece e o do arquivo. Imprime `[checar] ok|ERRO` e
## sai com 1 se algum nao compilou.
extends Node


func _ready() -> void:
	var ruins := 0
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--arquivo="):
			continue
		var caminho := arg.trim_prefix("--arquivo=")
		var s := ResourceLoader.load(caminho, "", ResourceLoader.CACHE_MODE_REPLACE) as GDScript
		if s == null or not s.can_instantiate():
			print("[checar] ERRO ", caminho)
			ruins += 1
		else:
			print("[checar] ok ", caminho)
	get_tree().quit(1 if ruins > 0 else 0)
