## O engasgo de abrir e fechar o celular (tecla C), na cidade de verdade.
##
##     godot --path game --resolution 3840x2160 res://tests/bancada_fps_celular.tscn -- --pular-menu --estilo=moderno
##     ... -- --vezes=12        quantas vezes abre e fecha (padrao 12)
##     ... -- --intervalo=0.8   segundos entre um aperto e o outro (padrao 0.8)
##     ... -- --no-carro        ao volante, parado (padrao: a pe)
##
## Aperta a ACAO `celular` por evento de entrada, e nao chama `Celular.abrir()`:
## o teste que chama o metodo passa por cima de quem trata a tecla (memoria:
## teste que chama o metodo nao aperta a tecla).
##
## Para cada aperto, o pior quadro nos 0,5 s seguintes, as pipelines novas e os
## nos que nasceram. Separa o PRIMEIRO aperto (aquecimento: pipeline, fonte,
## malha da mao) dos seguintes, que e o que o jogador sente apertando varias
## vezes. Imprime `[celular] chave=valor`.
extends Node

var _vezes := 12
var _intervalo := 0.8
var _no_carro := false

var _gravando := false
var _quadros := PackedFloat32Array()
var _pipes := PackedInt32Array()
var _nos := PackedInt32Array()
var _pipes_antes := 0
var _nos_antes := 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--vezes="):
			_vezes = arg.trim_prefix("--vezes=").to_int()
		elif arg.begins_with("--intervalo="):
			_intervalo = arg.trim_prefix("--intervalo=").to_float()
		elif arg == "--no-carro":
			_no_carro = true
	var cidade: Node = (load("res://scenes/test/cidade.tscn") as PackedScene).instantiate()
	add_child(cidade)
	_rodar(cidade)


func _relatar(chave: String, valor: Variant) -> void:
	print("[celular] %s=%s" % [chave, valor])


func _rodar(cidade: Node) -> void:
	var arvore := get_tree()
	var jogador: Node3D = null
	while jogador == null:
		await arvore.physics_frame
		jogador = arvore.get_first_node_in_group(&"player") as Node3D
	if _no_carro:
		var carro: Carro = await TesteCarro._pegar_carro(cidade, jogador)
		if carro == null:
			_relatar("carro", 0)
			arvore.quit(1)
			return
		carro.pilotar(0.0, 1.0, 0.0)
	# A cidade assenta antes: o que se quer e o custo do celular, nao o da carga.
	await arvore.create_timer(6.0).timeout
	_relatar("placa", RenderingServer.get_video_adapter_name())
	_relatar("lugar", "no carro" if _no_carro else "a pe")

	_gravando = true
	var marcas: Array[int] = []
	var rotulos: Array[String] = []
	for i in _vezes * 2:
		marcas.append(_quadros.size())
		rotulos.append("abre" if i % 2 == 0 else "fecha")
		_apertar()
		await arvore.create_timer(_intervalo).timeout
	marcas.append(_quadros.size())
	_gravando = false

	var base := _quadros.duplicate()
	base.sort()
	var mediana := base[base.size() / 2]
	_relatar("mediana_ms", "%.2f" % mediana)
	var linha := PackedStringArray()
	var piores_abre := PackedFloat32Array()
	var piores_fecha := PackedFloat32Array()
	for k in rotulos.size():
		var pior := 0.0
		var pipes := 0
		var nasceram := 0
		for q in range(marcas[k], mini(marcas[k + 1], marcas[k] + 90)):
			# So os quadros dos primeiros 0,5 s depois do aperto.
			pior = maxf(pior, _quadros[q])
			pipes += _pipes[q]
			nasceram += maxi(_nos[q], 0)
		linha.append("%s%d:%.0fms+%dp+%dn" % [rotulos[k], k / 2, pior, pipes, nasceram])
		if k >= 2:
			if rotulos[k] == "abre":
				piores_abre.append(pior)
			else:
				piores_fecha.append(pior)
	_relatar("por_aperto", " ".join(linha))
	piores_abre.sort()
	piores_fecha.sort()
	_relatar("depois_do_primeiro", "abrir pior mediano=%.1f ms max=%.1f | fechar pior mediano=%.1f ms max=%.1f" % [
		piores_abre[piores_abre.size() / 2], piores_abre[piores_abre.size() - 1],
		piores_fecha[piores_fecha.size() / 2], piores_fecha[piores_fecha.size() - 1]])
	arvore.quit(0)


func _apertar() -> void:
	var ev := InputEventAction.new()
	ev.action = &"celular"
	ev.pressed = true
	Input.parse_input_event(ev)
	var solta := InputEventAction.new()
	solta.action = &"celular"
	solta.pressed = false
	get_tree().create_timer(0.08).timeout.connect(func() -> void:
		Input.parse_input_event(solta))


func _process(delta: float) -> void:
	var pipes := int(RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE)) \
		+ int(RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW)) \
		+ int(RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)) \
		+ int(RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH)) \
		+ int(RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS))
	var nos := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if _gravando:
		_quadros.append(delta * 1000.0)
		_pipes.append(pipes - _pipes_antes)
		_nos.append(nos - _nos_antes)
	_pipes_antes = pipes
	_nos_antes = nos
