## Luzes do carro do jogador: o criterio A22 do PLANO_AAA_4K.
##
##     godot --path game --resolution 1280x720 --script res://tests/bancada_luzes_carro.gd
##
## O que cada medida faz
## ---------------------
## A22a  **Seta do jogador.** A tecla entra pelo mesmo caminho do teclado
##       (`Input.parse_input_event`), e a frequencia e medida pela LAMPADA:
##       quantas vezes ela apaga em quatro segundos de fisica. A constante do
##       periodo diria so o que alguem escreveu.
## A22a  **Pisca da frente.** Aceso na metade acesa do ciclo, brasa na outra, e
##       o lado de la continua brasa. Antes desta fase a lente ambar da frente
##       ficava acesa sempre, piscando ou nao.
## A22a  **Desligamento automatico.** Uma curva de verdade (volante todo) e a
##       volta ao centro apagam a seta; uma troca de faixa (um quinto do
##       volante) NAO apaga. O segundo caso e o controle: sem ele, uma seta que
##       apagasse sozinha a cada quadro passaria no primeiro.
## A22b  **Luz de teto.** Acende ao entrar e se apaga sozinha depois.
extends SceneTree

const FREQ := 1.5
const FOLGA_FREQ := 0.15
const JANELA := 4.0

var _carro_script: GDScript
var _passou := 0
var _total := 0


func _init() -> void:
	_medir()


func _medir() -> void:
	await process_frame
	await process_frame
	_carro_script = load("res://src/world/carro.gd") as GDScript
	print("\n=== A22: luzes do carro ===\n")
	var mundo := Node3D.new()
	root.add_child(mundo)
	var chao := StaticBody3D.new()
	chao.position = Vector3(0.0, -0.5, 0.0)
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(400.0, 1.0, 400.0)
	forma.shape = caixa
	chao.add_child(forma)
	mundo.add_child(chao)
	var c: VehicleBody3D = _carro_script.new()
	c.set(&"modelo", 0)
	c.set(&"semente", 5)
	c.set(&"motorista", 0)
	mundo.add_child(c)
	c.call(&"pousar", Vector3(0.0, 0.8, 0.0), 0.0)
	await physics_frame
	c.call(&"assumir", Node3D.new())
	_entrou_ms = Time.get_ticks_msec()
	await physics_frame

	await _medir_teto(c, 0.5, true)
	await _medir_seta(c)
	await _medir_desliga(c)
	await _medir_teto(c, 7.0, false)
	print("\n%d de %d criterios" % [_passou, _total])
	quit(0 if _passou == _total else 1)


func _conta(nome: String, ok: bool, texto: String) -> void:
	_total += 1
	if ok:
		_passou += 1
	print("%s %s: %s" % ["[ok]" if ok else "[X ]", nome, texto])


func _tecla(acao: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = acao
	ev.pressed = true
	Input.parse_input_event(ev)
	var solta := InputEventAction.new()
	solta.action = acao
	solta.pressed = false
	Input.parse_input_event(solta)


func _fisica(segundos: float) -> void:
	for _q in int(segundos * Engine.physics_ticks_per_second):
		await physics_frame


func _medir_seta(c: VehicleBody3D) -> void:
	_tecla(&"seta_esquerda")
	await physics_frame
	await physics_frame
	var lado: int = c.call(&"seta")
	var apagou := 0
	var antes := bool(c.call(&"seta_acesa"))
	var acesa_cor := 0.0
	var apagada_cor := 99.0
	var outro_lado := 0.0
	var quadros := int(JANELA * Engine.physics_ticks_per_second)
	for _q in quadros:
		await physics_frame
		var agora := bool(c.call(&"seta_acesa"))
		if antes and not agora:
			apagou += 1
		antes = agora
		var l := (c.call(&"cor_pisca_frente", -1) as Color).get_luminance()
		if agora:
			acesa_cor = maxf(acesa_cor, l)
		else:
			apagada_cor = minf(apagada_cor, l)
		outro_lado = maxf(outro_lado,
			(c.call(&"cor_pisca_frente", 1) as Color).get_luminance())
	var freq := float(apagou) / JANELA
	_conta("A22a seta do jogador", lado == -1 and absf(freq - FREQ) <= FOLGA_FREQ,
		"a tecla liga a seta %s, e a lampada apaga %d vezes em %.0f s: %.2f Hz (pedido %.1f)"
			% ["esquerda" if lado == -1 else "(nenhuma)", apagou, JANELA, freq, FREQ])
	var razao := acesa_cor / maxf(apagada_cor, 0.001)
	_conta("A22a pisca da frente", razao >= 2.5 and outro_lado <= apagada_cor + 0.01,
		"acesa %.2f contra %.2f apagada (%.1fx); o lado direito fica em %.2f"
			% [acesa_cor, apagada_cor, razao, outro_lado])
	# A mesma tecla de novo desliga.
	_tecla(&"seta_esquerda")
	await physics_frame
	await physics_frame
	_conta("A22a seta desliga na tecla", int(c.call(&"seta")) == 0,
		"a segunda pressao deixa a seta em %d" % int(c.call(&"seta")))


func _medir_desliga(c: VehicleBody3D) -> void:
	if not bool(c.get(&"ligado")):
		c.call(&"alternar_ignicao")
	# Controle: troca de faixa. Um quinto do volante e volta.
	c.call(&"ligar_seta", 1)
	c.call(&"pilotar", 0.25, 0.0, 0.2)
	await _fisica(1.2)
	c.call(&"pilotar", 0.0, 0.3, 0.0)
	await _fisica(1.2)
	var depois_da_faixa: int = c.call(&"seta")
	# Curva de verdade: volante todo e volta.
	c.call(&"pilotar", 0.25, 0.0, 1.0)
	await _fisica(1.5)
	var na_curva: int = c.call(&"seta")
	c.call(&"pilotar", 0.0, 0.3, 0.0)
	await _fisica(1.5)
	var depois_da_curva: int = c.call(&"seta")
	c.call(&"soltar_piloto")
	_conta("A22a desligamento automatico",
		depois_da_faixa == 1 and na_curva == 1 and depois_da_curva == 0,
		"seta direita: %d depois da troca de faixa, %d no meio da curva, %d com o volante de volta"
			% [depois_da_faixa, na_curva, depois_da_curva])


func _medir_teto(c: VehicleBody3D, quando: float, deve_acender: bool) -> void:
	var cab := c.get_node_or_null(^"CabineDoJogador")
	if cab == null:
		_conta("A22b luz de teto", false, "o carro assumido nao montou cabine")
		return
	# `quando` e medido a partir da entrada: a luz nasceu no `assumir`.
	var ja := float(Time.get_ticks_msec() - _entrou_ms) / 1000.0
	if quando > ja:
		await create_timer(quando - ja).timeout
	var e: float = cab.call(&"luz_de_teto")
	if deve_acender:
		_conta("A22b luz de teto acende", e >= 0.45,
			"meio segundo depois de entrar, a luz de teto esta em %.2f" % e)
	else:
		_conta("A22b luz de teto apaga", e <= 0.001,
			"%.0f s depois de entrar, a luz de teto esta em %.2f" % [quando, e])


var _entrou_ms := 0
