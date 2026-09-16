## O `VehicleBody3D` vira NaN quando a roda encosta num corpo CONGELADO?
##
##     godot --headless --path game --script res://tests/spike_roda_sobre_congelado.gd
##
## Por que existe
## --------------
## Em 16/09/2026 uma captura da cidade travou com o velocimetro marcando
## -9223372036854775808 — um NaN convertido para inteiro. A posicao do carro do
## jogador tinha virado NaN. Antes disso vinham avisos de
## `Vector3 cannot be normalized, the elements must be finite` em lotes de
## QUATRO, que e o numero de rodas, e eles apareciam ate com o jogador a pe.
##
## Os carros do transito sao `VehicleBody3D` congelados (cinematicos). A
## suspensao de um `VehicleBody3D` e um raio por roda, e o atrito lateral e
## resolvido contra o corpo que o raio acertou, dividindo pela massa e pela
## inercia INVERSAS dele. Esta bancada pergunta so isto, sem nada do jogo: um
## carro dinamico que sobe em cima de um carro congelado vira NaN?
##
## Tres casos, cada um num mundo proprio:
##
##   CHAO      o carro anda no chao estatico. Controle: tem de ficar finito.
##   PAREDE    bate de frente num carro congelado.
##   EM CIMA   nasce com as rodas em cima do teto de um carro congelado e acelera.
##
## E mais dois, que e onde o NaN apareceu de fato — no carro CONGELADO, e nao no
## que bate nele:
##
##   CINEMATICO  um carro congelado movido por `global_transform` a cada quadro,
##               como `Carro._dirigir_ia`, com o rumo mudando quase nada. O motor
##               inventa a velocidade angular de corpo cinematico a partir da
##               rotacao entre dois quadros; ela fica finita?
##   TOMADO      o mesmo carro, destravado no meio do caminho como em
##               `Carro.assumir`, com e sem zerar a velocidade angular.
extends SceneTree

const QUADROS := 600

var _linhas: Array[String] = []


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	await _caso("CHAO", false, Vector3(0, 0.6, 0))
	await _caso("PAREDE", true, Vector3(0, 0.6, 6.0))
	await _caso("EM CIMA", true, Vector3(0, 2.3, 0.8))
	await _cinematico(false, false)
	await _cinematico(true, false)
	await _cinematico(false, true)
	await _cinematico(true, true)
	await _cinematico(false, true, RigidBody3D.FREEZE_MODE_STATIC)
	await _cinematico(true, true, RigidBody3D.FREEZE_MODE_STATIC)
	await _cinematico(false, false, RigidBody3D.FREEZE_MODE_STATIC)
	await _caso("PAREDE ST", true, Vector3(0, 0.6, 6.0), RigidBody3D.FREEZE_MODE_STATIC)
	print("\n=== roda sobre corpo congelado ===")
	for l in _linhas:
		print(l)
	quit(0)


func _caso(nome: String, com_obstaculo: bool, onde: Vector3,
		modo: int = RigidBody3D.FREEZE_MODE_KINEMATIC) -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)
	var chao := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(60, 1, 60)
	forma.shape = caixa
	chao.add_child(forma)
	chao.position = Vector3(0, -0.5, 0)
	mundo.add_child(chao)

	if com_obstaculo:
		var parado := _carro(true)
		parado.freeze_mode = modo as RigidBody3D.FreezeMode
		mundo.add_child(parado)
		parado.global_position = Vector3(0, 0.6, 0)

	var carro := _carro(false)
	mundo.add_child(carro)
	carro.global_position = onde

	var primeiro_nan := -1
	var ultimo_ok := {}
	for q in QUADROS:
		# Para -Z, que e a frente da lataria do jogo: `engine_force` positivo
		# empurra para +Z (medido em `Carro._dirigir`).
		carro.engine_force = -2500.0
		await physics_frame
		var p := carro.global_position
		var v := carro.linear_velocity
		if p.is_finite() and v.is_finite() and carro.angular_velocity.is_finite():
			ultimo_ok = {"q": q, "p": p, "v": v}
		elif primeiro_nan < 0:
			primeiro_nan = q
	_linhas.append("  %-8s %s   %s" % [nome,
		"NaN no quadro %d" % primeiro_nan if primeiro_nan >= 0 else "finito",
		"ultimo finito: %s" % ultimo_ok])
	mundo.queue_free()
	await process_frame


## Um carro congelado andando como o da IA, e depois tomado.
func _cinematico(zerar_giro: bool, parado: bool,
		modo: int = RigidBody3D.FREEZE_MODE_KINEMATIC) -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)
	var chao := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(400, 1, 400)
	forma.shape = caixa
	chao.add_child(forma)
	chao.position = Vector3(0, -0.5, 0)
	mundo.add_child(chao)
	var carro := _carro(true)
	carro.freeze_mode = modo as RigidBody3D.FreezeMode
	mundo.add_child(carro)
	var giro := 0.3
	var pos := Vector3(0, 0.1, 0)
	var nan_cinematico := -1
	for q in 300:
		# Rumo quase parado, com o ruido de uma mira que oscila: e o que
		# `_aproximar_angulo` entrega numa reta.
		if not parado:
			giro += 0.00001 * sin(float(q))
			pos += Vector3(-sin(giro), 0.0, -cos(giro)) * 0.2
		carro.global_transform = Transform3D(Basis(Vector3.UP, giro), pos)
		await physics_frame
		var w := PhysicsServer3D.body_get_state(carro.get_rid(),
			PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY) as Vector3
		var vl := PhysicsServer3D.body_get_state(carro.get_rid(),
			PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY) as Vector3
		if not (w.is_finite() and vl.is_finite()) and nan_cinematico < 0:
			nan_cinematico = q
	# Tomado: destrava como `Carro.assumir`, e — no caso "zerado" — passa pelo
	# mesmo saneador que a cabine do jogador usa.
	carro.freeze = false
	carro.linear_velocity = Vector3(-sin(giro), 0.0, -cos(giro)) * (0.0 if parado else 12.0)
	if zerar_giro:
		CabineDoJogador.sanear(carro)
	var nan_tomado := -1
	var o_que := ""
	for q in 120:
		carro.engine_force = -1500.0
		await physics_frame
		var rodas_ok := true
		for r: Node in carro.get_children():
			if r is VehicleWheel3D and not (r as VehicleWheel3D).global_transform.basis.x.is_finite():
				rodas_ok = false
		if not (carro.global_position.is_finite()
				and carro.angular_velocity.is_finite() and rodas_ok) and nan_tomado < 0:
			nan_tomado = q
			o_que = "pos %s giro %s rodas %s" % [carro.global_position.is_finite(),
				carro.angular_velocity.is_finite(), rodas_ok]
	_linhas.append("  %-8s cinematico: %s   tomado%s: %s" % [
		"PARADO" if parado else "ANDANDO",
		"NaN no quadro %d" % nan_cinematico if nan_cinematico >= 0 else "finito",
		" (saneado)" if zerar_giro else "",
		("NaN no quadro %d (%s finitos)" % [nan_tomado, o_que]) if nan_tomado >= 0
			else "finito"])
	_linhas[_linhas.size() - 1] += "   [%s]" % ("STATIC" if modo == RigidBody3D.FREEZE_MODE_STATIC
		else "KINEMATIC")
	mundo.queue_free()
	await process_frame


## Um carro minimo: caixa de 1,7 x 1,2 x 4,2 m, 1000 kg, quatro rodas.
func _carro(congelado: bool) -> VehicleBody3D:
	var c := VehicleBody3D.new()
	c.mass = 1000.0
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(1.7, 1.2, 4.2)
	forma.shape = caixa
	forma.position = Vector3(0, 0.75, 0)
	c.add_child(forma)
	for x: float in [-0.7, 0.7]:
		for z: float in [-1.3, 1.3]:
			var r := VehicleWheel3D.new()
			r.position = Vector3(x, 0.3, z)
			r.wheel_radius = 0.3
			r.suspension_travel = 0.2
			r.suspension_stiffness = 40.0
			r.wheel_rest_length = 0.15
			r.use_as_traction = z > 0.0
			r.use_as_steering = z < 0.0
			c.add_child(r)
	if congelado:
		# Como os carros do transito: `Carro._congelar(true)`.
		c.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		c.freeze = true
	return c
