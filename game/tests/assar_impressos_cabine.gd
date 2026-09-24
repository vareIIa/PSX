## Assa `ImpressosCabine.FOLHA`: desenha a folha num SubViewport e grava o PNG.
##
##     godot --path game --script res://tests/assar_impressos_cabine.gd
##     godot --headless --path game --import
##
## SEM --headless: o renderizador falso nao desenha nada e o PNG sairia vazio.
## Depois de assar, o `--import` gera a textura com mipmaps (o .import dela pede).
extends SceneTree


func _initialize() -> void:
	_assar.call_deferred()


func _assar() -> void:
	var vp := SubViewport.new()
	vp.size = ImpressosCabine.TAMANHO
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var tela := Control.new()
	tela.size = Vector2(ImpressosCabine.TAMANHO)
	tela.draw.connect(func() -> void: ImpressosCabine.desenhar(tela))
	vp.add_child(tela)
	for k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var caminho := ProjectSettings.globalize_path(ImpressosCabine.FOLHA)
	var erro := img.save_png(caminho)
	print("[impressos] %s -> %s (%s)" % [img.get_size(), caminho, error_string(erro)])
	quit(0 if erro == OK else 1)
