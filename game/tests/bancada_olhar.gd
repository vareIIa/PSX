## Olhar livre ao volante: o criterio A24 do PLANO_AAA_4K.
##
##     godot --path game --resolution 1280x720 res://tests/bancada_olhar.tscn -- --teste-olhar
##
## A flag nao e enfeite. Sem um `--teste-*` o `Player` prende o ponteiro ao
## nascer, e o mouse de quem esta usando a maquina passa a girar a camera no meio
## da medida: a primeira rodada acusou a camera 37 graus torta com o carro
## parado, e era a mao de alguem. A bancada reprova sem ela.
## Cena, e nao `--script`: o jogador e o carro dependem de autoload, e numa cena
## a lista de autoload ja existe quando o script e compilado.
##
## O que cada medida faz
## ---------------------
## A24a  **Limites de dentro.** Mouse muito para o lado e muito para cima: a
##       cabeca para em 115 graus e em 60 graus, que e o que o plano pede
##       (pelo menos 100 e 60).
## A24b  **Volta inteira por fora.** Tres quartos de volta de mouse para um lado
##       e a camera anda tres quartos de volta.
## A24c  **Volta ao centro.** Andando, o olhar fica onde o jogador deixou ate a
##       espera acabar, e depois chega na frente em ate 0,8 s.
## A24d  **Parado nao volta.** Cinco segundos com o carro parado e o olhar
##       continua de lado.
## A24e  **O mouse gira a camera de fora.** A medida e a direcao REAL da camera
##       em uso, e nao o numero guardado. Com CONTROLE: o caminho antigo — girar
##       o corpo — e aplicado tambem, e a bancada exige que ele suma em meio
##       segundo. Sem o controle, uma regua que so lesse o numero aprovaria o
##       defeito que motivou tudo isto.
## A24f  **O mouse gira a cabeca de dentro.** Mesma medida, com a camera da
##       cabine em uso.
## A24g  **Volta andando, na camera.** O carro anda e a camera de fora volta
##       para tras dele sozinha.
## A24h  **Descer zera.** O braco sai do carro sem giro nenhum: a pe o mouse gira
##       o corpo, e um braco torto deixaria a camera de lado para sempre.
extends Node

const SENS := 0.0024
const GRAU := PI / 180.0

var _passou := 0
var _total := 0


func _ready() -> void:
	_medir.call_deferred()


func _conta(nome: String, ok: bool, texto: String) -> void:
	_total += 1
	if ok:
		_passou += 1
	print("%s %s: %s" % ["[ok]" if ok else "[X ]", nome, texto])


func _medir() -> void:
	print("\n=== A24: olhar livre ao volante ===\n")
	if not OS.get_cmdline_user_args().has("--teste-olhar"):
		print("[X ] falta `-- --teste-olhar`: sem ela o mouse da maquina gira a camera")
		get_tree().quit(1)
		return
	_medir_logica()
	await _medir_no_carro()
	print("\n%d de %d criterios" % [_passou, _total])
	get_tree().quit(0 if _passou == _total and _total > 0 else 1)


# --- logica pura ------------------------------------------------------------

func _medir_logica() -> void:
	var o := OlharAoVolante.new()
	o.definir_dentro(true)
	o.mover(Vector2(-5000.0, -5000.0), SENS)
	var g := rad_to_deg(o.guinada)
	var a := rad_to_deg(o.arfagem)
	o.mover(Vector2(10000.0, 10000.0), SENS)
	var g2 := rad_to_deg(o.guinada)
	var a2 := rad_to_deg(o.arfagem)
	_conta("A24a limites de dentro",
		g >= 100.0 and g2 <= -100.0 and a >= 60.0 - 0.5 and a2 <= -60.0 + 0.5
			and g <= 120.0 and a <= 61.0,
		"para os lados %.0f / %.0f graus, para cima e para baixo %.0f / %.0f graus"
			% [g, g2, a, a2])

	o = OlharAoVolante.new()
	# Tres quartos de volta em passos pequenos, como o mouse manda.
	var alvo := 1.5 * PI
	var px := alvo / SENS
	var andou := 0.0
	var antes := o.guinada
	for _k in 200:
		o.mover(Vector2(-px / 200.0, 0.0), SENS)
		andou += wrapf(o.guinada - antes, -PI, PI)
		antes = o.guinada
	_conta("A24b volta inteira por fora", absf(rad_to_deg(andou) - 270.0) < 1.0,
		"o mouse pediu 270 graus e a camera andou %.1f" % rad_to_deg(andou))

	o = OlharAoVolante.new()
	o.mover(Vector2(-600.0, 0.0), SENS)
	var dt := 1.0 / 60.0
	var t := 0.0
	var parado_ate := -1.0
	var chegou := -1.0
	while t < 5.0:
		o.passo(dt, 10.0)
		t += dt
		if parado_ate < 0.0 and absf(o.guinada) < deg_to_rad(82.0) * 0.99:
			parado_ate = t
		if chegou < 0.0 and absf(o.guinada) < deg_to_rad(1.0):
			chegou = t
			break
	var volta := chegou - parado_ate
	_conta("A24c volta ao centro",
		parado_ate >= OlharAoVolante.ESPERA - dt and chegou > 0.0 and volta <= 0.8,
		"a 36 km/h o olhar fica %.2f s parado de lado e chega na frente %.2f s depois (pedido: ate 0,8 s)"
			% [parado_ate, volta])

	o = OlharAoVolante.new()
	o.mover(Vector2(-600.0, 0.0), SENS)
	for _k in 300:
		o.passo(dt, 0.0)
	_conta("A24d parado nao volta", absf(rad_to_deg(o.guinada) - 82.5) < 0.5,
		"cinco segundos parado, o olhar continua em %.1f graus" % rad_to_deg(o.guinada))


# --- no carro, com a camera de verdade ---------------------------------------

func _medir_no_carro() -> void:
	var mundo := Node3D.new()
	add_child(mundo)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	mundo.add_child(luz)
	var chao := StaticBody3D.new()
	chao.position = Vector3(0.0, -0.5, 0.0)
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(600.0, 1.0, 600.0)
	forma.shape = caixa
	chao.add_child(forma)
	var piso := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(600.0, 600.0)
	piso.mesh = plano
	piso.position = Vector3(0.0, 0.5, 0.0)
	chao.add_child(piso)
	mundo.add_child(chao)

	var jogador := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	mundo.add_child(jogador)
	jogador.global_position = Vector3(3.0, 0.2, 0.0)
	var c := Carro.new()
	c.modelo = 0
	c.semente = 5
	c.motorista = Carro.Motorista.NINGUEM
	mundo.add_child(c)
	c.pousar(Vector3(0.0, 0.8, 0.0), 0.0)
	for _q in 10:
		await get_tree().physics_frame
	jogador.call(&"_entrar_no_carro", c)
	if not c.ligado:
		c.alternar_ignicao()
	await _esperar(1.0)

	var braco := jogador.get_node(^"Pivo/Braco") as SpringArm3D
	var cab := c.get_node_or_null(^"CabineDoJogador")

	# A24e — por fora, com controle.
	var sem := _angulo_da_camera(c)
	jogador.rotate_y(-deg_to_rad(80.0))
	await _esperar(0.5)
	var controle := _angulo_da_camera(c)
	_mouse(jogador, Vector2(-80.0 * GRAU / SENS, 0.0))
	await _esperar(0.5)
	var com := _angulo_da_camera(c)
	_conta("A24e o mouse gira a camera de fora",
		absf(com - 80.0) < 4.0 and absf(controle) < 5.0 and absf(sem) < 3.0,
		"antes %.1f graus; girar o corpo (o caminho antigo) some em meio segundo, sobra %.1f; o mouse deixa a camera em %.1f (pedido 80)"
			% [sem, controle, com])

	# A24f — por dentro. O ciclo da tecla e longe, perto, dentro.
	jogador.olhar.zerar()
	if cab != null:
		cab.call(&"_ir_para", 2)
	await _esperar(0.3)
	var dentro_cam := get_viewport().get_camera_3d()
	var e_da_cabine := cab != null and dentro_cam != null and cab.is_ancestor_of(dentro_cam)
	_mouse(jogador, Vector2(-60.0 * GRAU / SENS, -30.0 * GRAU / SENS))
	await _esperar(0.3)
	var gd := _angulo_da_camera(c)
	var ad := _arfagem_da_camera()
	_conta("A24f o mouse gira a cabeca de dentro",
		e_da_cabine and absf(gd - 60.0) < 4.0 and absf(ad - 30.0) < 5.0,
		"camera da cabine em uso: %s; para a esquerda %.1f graus (pedido 60), para cima %.1f (pedido 30)"
			% [e_da_cabine, gd, ad])

	# A24g — de volta para fora, olha de lado e anda.
	if cab != null:
		cab.call(&"_ir_para", 0)
	await _esperar(0.3)
	_mouse(jogador, Vector2(90.0 * GRAU / SENS, 0.0))
	await _esperar(0.2)
	c.pilotar(0.6, 0.0, 0.0)
	var t := 0.0
	var de_lado_ate := -1.0
	var na_frente := -1.0
	while t < 6.0:
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		var ang := absf(_angulo_da_camera(c))
		if de_lado_ate < 0.0 and absf(jogador.olhar.guinada) < deg_to_rad(89.0):
			de_lado_ate = t
		if de_lado_ate > 0.0 and ang < 3.0:
			na_frente = t
			break
	var kmh := absf(c.velocidade()) * 3.6
	c.soltar_piloto()
	_conta("A24g volta andando, na camera",
		na_frente > 0.0 and de_lado_ate >= 0.9,
		"andando (%.0f km/h), a camera ficou de lado %.2f s e voltou para tras do carro %.2f s depois"
			% [kmh, de_lado_ate, na_frente - de_lado_ate])

	# A24h — descer com o olhar de lado.
	_mouse(jogador, Vector2(60.0 * GRAU / SENS, 20.0 * GRAU / SENS))
	await _esperar(0.1)
	var torto := braco.rotation.length()
	jogador.call(&"_sair_do_carro")
	await _esperar(0.1)
	_conta("A24h descer zera", torto > 0.3 and braco.rotation.length() < 0.001,
		"o braco estava girado %.2f rad ao volante e ficou em %.3f depois de descer"
			% [torto, braco.rotation.length()])


## Entrega um movimento de mouse pelo mesmo caminho do mouse de verdade.
##
## O `Player` so aceita movimento com o ponteiro preso. Preso aqui so o tempo de
## entregar o evento, e solto em seguida: prender o ponteiro de quem esta usando
## a maquina durante a bancada inteira giraria a camera com o mouse dele.
func _mouse(jogador: Node, relativo: Vector2) -> void:
	# Em passos, como o mouse manda: um salto de 1300 px passaria por cima de
	# limites que um mouse real encontra no caminho.
	var passos := maxi(1, int(ceilf(relativo.length() / 40.0)))
	var antes := Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for _k in passos:
		var ev := InputEventMouseMotion.new()
		ev.relative = relativo / float(passos)
		jogador.call(&"_unhandled_input", ev)
	Input.mouse_mode = antes


func _esperar(segundos: float) -> void:
	for _q in int(segundos * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
	await get_tree().process_frame


## Quanto a camera em uso esta virada em relacao a frente do carro, em graus,
## no plano do chao. Positivo para a esquerda.
func _angulo_da_camera(c: Node3D) -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 999.0
	var f := -cam.global_basis.z
	var k := -c.global_basis.z
	f.y = 0.0
	k.y = 0.0
	if f.length() < 0.01 or k.length() < 0.01:
		return 999.0
	return rad_to_deg(k.normalized().signed_angle_to(f.normalized(), Vector3.UP))


func _arfagem_da_camera() -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 999.0
	var f := -cam.global_basis.z
	return rad_to_deg(asin(clampf(f.y, -1.0, 1.0)))
