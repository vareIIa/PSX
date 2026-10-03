## Play curto da batida: o carro bate, o celular vai no vidro e cai, a mao fecha nele.
##
## Nao entra no roteiro da introducao. Abra esta cena e rode com F6
## (Executar Cena Atual). F5 continua sendo a cidade, para as outras sessoes.
## A imagem fica parada na pegada. F8 sai.
extends AberturaEstrada


func _ready() -> void:
	# Roda por ultimo no quadro, depois de quem quer que pegue o cursor.
	process_priority = 100
	_soltar_mouse()
	_rodar()


func _process(delta: float) -> void:
	super._process(delta)
	_soltar_mouse()


func _input(_evento: InputEvent) -> void:
	_soltar_mouse()


func _soltar_mouse() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _rodar() -> void:
	var mundo_pai := Node3D.new()
	mundo_pai.name = "Cena"
	add_child(mundo_pai)
	_cena = mundo_pai
	var fog := FogController.new()
	fog.name = "Ambiente"
	add_child(fog)
	Cinema.fechar_de_imediato()
	Cinema.iniciar(true)
	_montar_mundo()
	_cam = Cinema.assumir()
	if _cam != null:
		_far_anterior = _cam.far
		_cam.far = 900.0
		_cam.near = 0.08
	set_process(true)
	if _motorista == null:
		push_error("play_batida_chao: a cabine nao montou o motorista")
		return
	_branco = BrancoDoSusto.new()
	_cena.add_child(_branco)
	_montar_fumaca()
	_carro.farol_de_verdade(true)
	_carro.preparar_batida()
	_preaquecer_a_batida()
	_comecar(Plano.DENTRO, 60.0)
	var app := AppMensagens.new()
	app.preparar(FALAS["grupo"], CONVERSA_DO_GRUPO, FALAS["grupo_hora"], FALAS["desculpa"])
	_motorista.ligar_tela(app)
	await _aquecer_na_lente()
	await Cinema.clarear(0.7)
	app.sem_teclado = true
	_motorista.mostrar_celular(true)
	await _esperar(0.2)
	_motorista.arremessar_celular(0.08)
	await _esperar(0.12)
	_fov_cena = DENTRO_FOV
	_bater()
	_foco_de = func() -> Vector3: return _motorista.ponto_do_celular()
	_foco_peso = 0.0
	_animar(&"_foco_peso", 1.0, 0.35)
	await _esperar(1.15)
	_motorista.vibrar_celular(0.4)
	_motorista.medo = 1.0
	_motorista.alcancar_no_chao(1.05)
	await _esperar(0.35)
	_animar(&"_debruca", 1.0, 0.7)
	_animar(&"_fov_cena", CHAO_FOV, 0.7, Tween.TRANS_SINE)
	_animar(&"_ofego", 1.0, 0.5)
	await _esperar(0.9)
	var t_forca := create_tween()
	t_forca.tween_property(_motorista, "esforco", 1.0, 0.5)
	t_forca.parallel().tween_property(_motorista, "apoio_forca", 0.45, 0.5)
	await _esperar(0.7)
	_foco_de = func() -> Vector3:
		return _motorista.ponto_do_celular().lerp(_motorista.ponto_da_mao_direita(), 0.25)
	_animar(&"_fov_cena", PEGAR_FOV, PEGAR_TEMPO * 0.8, Tween.TRANS_SINE)
	var t_emp := create_tween()
	t_emp.tween_property(_motorista, "apoio_forca", 1.0, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t_emp.parallel().tween_property(_motorista, "esforco", 0.0, 0.4)
	await _motorista.pegar_do_chao(PEGAR_TEMPO)
	print("[play_batida_chao] pegou. F8 para sair.")
	while is_inside_tree():
		await get_tree().process_frame
