## A cabine do jogador monta, cicla a camera e desmonta direito?
##
##     godot --headless --path game --script res://tests/checar_cabine_jogador.gd
##
## O que se afirma
## ---------------
##   montar     a cabine nasce no carro, com vidro, mapa de agua e limpador.
##   ciclo      a tecla de camera gira LONGE -> PERTO -> DENTRO -> LONGE, e o
##              braco de camera acompanha: perto na PERTO, longe na LONGE. A
##              camera de dentro so e a atual na DENTRO.
##   desmontar  a cabine sai, e a camera volta a ser a de fora.
##
## O jogador, o braco e o carro sao DUBLES: o que se testa e a conversa entre a
## cabine e eles, que e o que quebra em silencio. Foi assim que um
## `(int(vista) + 1) % 3 as Vista` quase entrou — `as` para enum devolve nulo sem
## erro, e o ciclo pararia no primeiro toque.
extends SceneTree

## O braco de camera de mentira: alterna perto e longe, como o `CameraRig`.
const BRACO := """
extends SpringArm3D
var perto := false
var toques := 0
func alternar() -> bool:
	perto = not perto
	toques += 1
	return true
func seguir_veiculo(_v) -> void:
	perto = false
"""

## O jogador de mentira: tem o sinal, e a tecla alterna o braco antes de emitir,
## como `Player._alternar_camera`.
const JOGADOR := """
extends Node3D
signal camera_alternada(terceira_pessoa: bool)
var braco: SpringArm3D
func apertar_camera() -> void:
	braco.alternar()
	camera_alternada.emit(true)
"""

var _falhas := 0
var _casos := 0


## Segundos ate o teste se declarar reprovado. Uma classe que nao compila
## aborta a corrotina no meio, e sem isto o `quit` nunca chega: o teste fica
## pendurado em vez de reprovar. Ja aconteceu com este arquivo.
const PRAZO := 60.0


func _initialize() -> void:
	create_timer(PRAZO).timeout.connect(func() -> void:
		print("
=== FALHOU: o teste nao terminou em %d s ===" % int(PRAZO))
		quit(1))
	_rodar.call_deferred()


func _rodar() -> void:
	var raiz := Node3D.new()
	root.add_child(raiz)
	var camera_de_fora := Camera3D.new()
	raiz.add_child(camera_de_fora)
	camera_de_fora.make_current()

	var jogador := _de_codigo(JOGADOR, Node3D.new()) as Node3D
	raiz.add_child(jogador)
	var braco := _de_codigo(BRACO, SpringArm3D.new()) as SpringArm3D
	jogador.add_child(braco)
	jogador.set(&"braco", braco)

	var carro := VehicleBody3D.new()
	carro.freeze = true
	raiz.add_child(carro)
	var medidas := Carroceria.montar(Carroceria.Modelo.MAREA, CarroCena.TINTA,
		CarroCena.SEMENTE)

	var cab := CabineDoJogador.montar(carro, medidas, jogador)
	_checar("montar: a cabine nasce no carro", cab != null and cab.get_parent() == carro,
		"pai: %s" % (cab.get_parent() if cab != null else null))
	_checar("montar: com mapa de agua e limpador",
		cab != null and cab.cabine.mapa_agua() != null and cab.cabine.limpadores() != null,
		"")
	_checar("montar: comeca de fora", cab.vista == CabineDoJogador.Vista.LONGE
		and camera_de_fora.current, "vista %d" % cab.vista)

	var esperado := [CabineDoJogador.Vista.PERTO, CabineDoJogador.Vista.DENTRO,
		CabineDoJogador.Vista.LONGE, CabineDoJogador.Vista.PERTO,
		CabineDoJogador.Vista.DENTRO, CabineDoJogador.Vista.LONGE]
	var i := 0
	for v: int in esperado:
		i += 1
		jogador.call(&"apertar_camera")
		var perto: bool = braco.get(&"perto")
		var dentro_atual := root.get_viewport().get_camera_3d() != camera_de_fora
		var ok := cab.vista == v
		if v == CabineDoJogador.Vista.PERTO:
			ok = ok and perto and not dentro_atual
		elif v == CabineDoJogador.Vista.LONGE:
			ok = ok and not perto and not dentro_atual
		else:
			ok = ok and dentro_atual
		_checar("ciclo: toque %d" % i, ok,
			"vista %d (esperada %d), braco %s, camera de dentro %s"
				% [cab.vista, v, "perto" if perto else "longe", dentro_atual])

	# Um quadro de fisica com a cabine viva: nao pode quebrar sem chuva nem clima.
	await physics_frame
	await physics_frame

	jogador.call(&"apertar_camera")
	jogador.call(&"apertar_camera")
	_checar("antes de desmontar: dentro", cab.vista == CabineDoJogador.Vista.DENTRO,
		"vista %d" % cab.vista)
	CabineDoJogador.desmontar(cab)
	await process_frame
	await process_frame
	_checar("desmontar: a camera de fora volta", camera_de_fora.current, "")
	_checar("desmontar: a cabine sai do carro", not is_instance_valid(cab), "")
	CabineDoJogador.desmontar(null)
	_checar("desmontar: nulo e aceito", true, "")

	# Carro tomado com NaN: a cabine nao pode deixar o jogador herdar. Ver
	# `CabineDoJogador.sanear`. O NaN e injetado no corpo destravado, que e o
	# estado em que `Carro.assumir` chama `montar`.
	var podre := VehicleBody3D.new()
	raiz.add_child(podre)
	await physics_frame
	podre.angular_velocity = Vector3(NAN, NAN, NAN)
	podre.linear_velocity = Vector3(INF, 0.0, 0.0)
	var limpou := CabineDoJogador.sanear(podre)
	_checar("sanear: acusa o carro podre", limpou, "")
	_checar("sanear: devolve velocidades finitas",
		podre.angular_velocity.is_finite() and podre.linear_velocity.is_finite(),
		"giro %s vel %s" % [podre.angular_velocity, podre.linear_velocity])
	await physics_frame
	await physics_frame
	_checar("sanear: e o corpo segue finito depois de integrar",
		podre.global_position.is_finite() and podre.angular_velocity.is_finite(),
		"pos %s" % podre.global_position)
	_checar("sanear: carro sao nao e tocado", not CabineDoJogador.sanear(carro), "")

	# O caso de verdade: o NaN so no SERVIDOR, com a propriedade do no ainda
	# limpa — e como o carro congelado do transito chega. Lido pelo no, passava.
	var disfarcado := VehicleBody3D.new()
	raiz.add_child(disfarcado)
	await physics_frame
	PhysicsServer3D.body_set_state(disfarcado.get_rid(),
		PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3(NAN, NAN, NAN))
	_checar("sanear: acha o NaN que so o servidor tem",
		CabineDoJogador.sanear(disfarcado), "")
	var giro_servidor: Vector3 = PhysicsServer3D.body_get_state(
		disfarcado.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY)
	_checar("sanear: e limpa o servidor", giro_servidor.is_finite(),
		"giro no servidor %s" % giro_servidor)

	print("\n=== cabine do jogador ===")
	if _casos == 0:
		_falhas += 1
	print("=== %s ===" % ("OK: %d casos" % _casos if _falhas == 0
		else "FALHOU: %d de %d" % [_falhas, _casos]))
	quit(0 if _falhas == 0 else 1)


func _de_codigo(fonte: String, no: Node) -> Node:
	var s := GDScript.new()
	s.source_code = fonte
	s.reload()
	no.set_script(s)
	return no


func _checar(nome: String, passou: bool, detalhe: String) -> void:
	_casos += 1
	if not passou:
		_falhas += 1
	print("  %-40s %s  %s" % [nome, "OK    " if passou else "FALHOU", detalhe])
