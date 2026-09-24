## A conversa na cidade de verdade: o busto fala com a boca, e o texto anda
## junto com ela.
##
##     godot --path game --resolution 1280x720 res://tests/conversa_na_cidade.tscn -- --pular-menu --saida=DIR
##
## Planta um pedestre na frente do jogador, abre a conversa pela porta de
## sempre (`Pedestre.abordar`) e fotografa a tela inteira a cada 0,13 s durante
## a saudacao. Imprime `[conversa] chave=valor`: quantos estados de boca
## diferentes apareceram, e se o texto e a boca terminaram juntos.
extends Node

var _saida := ""


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
	var cidade: Node = (load("res://scenes/test/cidade.tscn") as PackedScene).instantiate()
	add_child(cidade)
	_rodar(cidade)


func _relatar(chave: String, valor: Variant) -> void:
	print("[conversa] %s=%s" % [chave, valor])


func _rodar(cidade: Node) -> void:
	var arvore := get_tree()
	var jogador: Node3D = null
	while jogador == null:
		await arvore.physics_frame
		jogador = arvore.get_first_node_in_group(&"player") as Node3D
	await arvore.create_timer(4.0).timeout
	var frente := -jogador.global_basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var ped := Pedestre.new()
	ped.preparar(RegistroCivil.identidade(1234), Vector4i.ZERO, Vector4i.ZERO)
	cidade.add_child(ped)
	ped.global_position = jogador.global_position + frente * 1.6
	ped.esperar_parado(60.0)
	await arvore.create_timer(0.5).timeout
	ped.abordar(jogador)
	var fala := Conversa.get_node_or_null(^"Fala") as Fala
	var bocas := {}
	var fotos := 0
	var t := 0.0
	var proxima := 0.0
	while t < 6.0:
		await arvore.process_frame
		t += get_process_delta_time()
		fala = Conversa.get_node_or_null(^"Fala") as Fala
		var rosto: Rosto = null
		var busto = Conversa.get("_retrato_corpo")
		if busto is Corpo:
			rosto = (busto as Corpo).rosto
		if rosto != null:
			bocas[rosto.estado(&"boca")] = true
		if t >= proxima and fotos < 12 and not _saida.is_empty():
			proxima += 0.13
			var img := get_viewport().get_texture().get_image()
			DirAccess.make_dir_recursive_absolute(_saida)
			img.save_png(_saida.path_join("conversa_%02d.png" % fotos))
			fotos += 1
		if fala != null and not fala.falando() and t > 1.0:
			break
	_relatar("tem_fala", 1 if fala != null else 0)
	_relatar("bocas_distintas", bocas.size())
	_relatar("boca_fechou_no_fim", 1 if bocas.has(&"") else 0)
	var texto = Conversa.get("_texto")
	_relatar("texto_inteiro_no_fim", 1 if texto is Label and (texto as Label).visible_characters < 0 else 0)
	_relatar("fim", 1)
	AudioDirector.silenciar_tudo()
	await arvore.process_frame
	arvore.quit(0)
