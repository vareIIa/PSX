## O titulo enquanto os shaders aquecem: a barra aparece, jogar fica apagado, e
## tudo volta quando termina (`AquecimentoDeShaders`, `PainelAquecimento`).
##
##     godot --path game --resolution 3840x2160 res://tests/bancada_titulo_aquecimento.tscn -- --estilo=moderno --saida=DIR
##
## Monta a cidade de verdade (sem `--pular-menu`), vai do boot ao titulo pela
## mesma porta da cidade e tira duas fotos: `titulo_aquecendo.png` no meio do
## aquecimento e `titulo_pronto.png` depois. Imprime `[titulo] chave=valor`.
extends Node

var _saida := "user://"


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
	var cidade: Node = (load("res://scenes/test/cidade.tscn") as PackedScene).instantiate()
	add_child(cidade)
	_rodar(cidade)


func _relatar(chave: String, valor: Variant) -> void:
	print("[titulo] %s=%s" % [chave, valor])


func _rodar(cidade: Node) -> void:
	var arvore := get_tree()
	var menu: Menu = null
	var t := 0.0
	while menu == null and t < 20.0:
		await arvore.process_frame
		t += get_process_delta_time()
		menu = cidade.get("_menu") as Menu
	if menu == null:
		_relatar("menu", "nao achado")
		arvore.quit(1)
		return
	# O boot ja pediu o aquecimento; o titulo e a porta que a cidade usa ao
	# terminar o boot.
	_relatar("aquecendo_no_boot", not AquecimentoDeShaders.pronto())
	cidade.call(&"_abrir_menu_jogo")
	await arvore.create_timer(0.3).timeout
	_relatar("durante", "pronto=%s novo_jogo_vivo=%s nota='%s'" % [
		AquecimentoDeShaders.pronto(), menu.call(&"_item_vivo", "NOVO JOGO"),
		menu.call(&"_texto_da_nota")])
	var a := AquecimentoDeShaders.instancia()
	_relatar("fracao_na_foto", a.fracao if a != null else 1.0)
	get_viewport().get_texture().get_image().save_png(_saida.path_join("titulo_aquecendo.png"))
	var t0 := Time.get_ticks_msec()
	while not AquecimentoDeShaders.pronto() and Time.get_ticks_msec() - t0 < 30000:
		await arvore.process_frame
	await arvore.create_timer(3.0).timeout
	_relatar("depois", "pronto=%s novo_jogo_vivo=%s continuar_vivo=%s nota='%s'" % [
		AquecimentoDeShaders.pronto(), menu.call(&"_item_vivo", "NOVO JOGO"),
		menu.call(&"_item_vivo", "CONTINUAR"), menu.call(&"_texto_da_nota")])
	get_viewport().get_texture().get_image().save_png(_saida.path_join("titulo_pronto.png"))
	arvore.quit(0)
