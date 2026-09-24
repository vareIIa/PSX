## O boneco de pano medido: junta que abre, corpo que atravessa o chao, tombo
## que nao assenta, pessoa que nao levanta.
##
##     godot --headless --path game --script res://tests/medir_boneco.gd
##
## Cada cena poe um Corpo de pe num piso plano e derruba com `BonecoDePano`:
##
## - atropelo: golpe de 10 m/s (36 km/h) nas canelas, por tras;
## - empurrao: 3 m/s de lado no corpo inteiro;
## - queda: solto a 2,5 m do chao, sem golpe;
## - carro: um RigidBody3D de 1100 kg a 9 m/s bate de verdade no corpo.
##
## O que se mede, a cada passo de fisica, ate a pessoa ficar de pe:
##
## - junta: distancia entre a origem da peca e o ponto do pai em que ela esta
##   presa. O pico do impacto ate JUNTA_ABRE; a media do tombo inteiro ate
##   JUNTA_MEDIA (o pico e o para-choque; a media e o corpo desmontado);
## - joelho e cotovelo ao contrario (canela positiva, antebraco negativo) por
##   mais de QUADROS_DOBRA quadros. Um quadro de 0,4 rad no para-choque a
##   36 km/h e a batida; um quarto de segundo e a junta sem limite.
## - chao: nenhuma peca abaixo de -ATRAVESSA;
## - tempo ate levantar, e se levantou;
## - custo: milissegundos por passo de fisica (media), com a cena parada.
extends SceneTree

const JUNTA_ABRE := 0.08
const JUNTA_MEDIA := 0.015
const DOBRA_ERRADA := 0.25
const QUADROS_DOBRA := 12
const ATRAVESSA := 0.08
const O := Corpo.Osso

var _passou := 0
var _total := 0


func _init() -> void:
	_rodar()


func _rodar() -> void:
	await process_frame
	var chao := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(200.0, 1.0, 200.0)
	forma.shape = caixa
	forma.position = Vector3(0.0, -0.5, 0.0)
	chao.add_child(forma)
	root.add_child(chao)

	var cenas := [
		["atropelo", Vector3.ZERO, Vector3(0.0, 1.2, -10.0), 0.0, false],
		["empurrao", Vector3(3.0, 0.0, 0.0), Vector3.ZERO, 0.0, false],
		["queda", Vector3.ZERO, Vector3.ZERO, 2.5, false],
		["carro", Vector3.ZERO, Vector3.ZERO, 0.0, true],
	]
	for c: Array in cenas:
		await _cena(c[0], c[1], c[2], c[3], c[4])
	print("[boneco] %d/%d" % [_passou, _total])
	quit(0 if _passou == _total else 1)


func _cena(nome: String, vel: Vector3, golpe: Vector3, altura: float, com_carro: bool) -> void:
	var dono := Node3D.new()
	dono.name = "Dono_" + nome
	root.add_child(dono)
	dono.global_position = Vector3(0.0, altura, 0.0)
	var corpo := Corpo.new()
	dono.add_child(corpo)
	corpo.montar(Aparencia.de_ficha({"id": 23, "sexo": &"M", "idade": 30}))
	for i in 3:
		corpo.animar(1.2, 1.0 / 60.0)
		await physics_frame

	var carro: RigidBody3D = null
	var boneco: BonecoDePano = null
	if com_carro:
		carro = RigidBody3D.new()
		carro.mass = 1100.0
		var f := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(1.7, 1.1, 4.2)
		f.shape = b
		f.position = Vector3(0.0, 0.2 + 0.55, 0.0)
		carro.add_child(f)
		root.add_child(carro)
		carro.global_position = Vector3(0.0, 0.0, 3.2)
		carro.linear_velocity = Vector3(0.0, 0.0, -9.0)
		carro.continuous_cd = true
		# O carro chega; o golpe e o contato de verdade, a um passo de encostar.
		for i in 60:
			await physics_frame
			var frente := carro.global_position.z - 2.1
			if frente < 0.45:
				break
		boneco = BonecoDePano.derrubar(corpo, Vector3.ZERO, carro.linear_velocity,
			0.55, 0.6, [])
		# Como no jogo: o corpo sente o perfil de sedan, e nao a caixa do carro.
		LatariaParaCorpo.criar(carro, AABB(Vector3(-0.85, 0.2, -2.1), Vector3(1.7, 1.1, 4.2)),
			boneco.pecas())
	else:
		boneco = BonecoDePano.derrubar(corpo, vel, golpe, 0.5, 0.5, [])

	var levantou := [false]
	# O dono faz o que o pedestre faz: vai para onde a pessoa ficou de pe.
	boneco.levantou.connect(func(o: Vector3, r: float) -> void:
		levantou[0] = true
		dono.global_position = o
		dono.rotation.y = r)
	var pancada := 0.0
	var pior_junta := 0.0
	var soma_junta := 0.0
	var n_junta := 0
	var pior_dobra := 0.0
	var quadros_dobra := 0
	var mais_baixo := INF
	var t := 0.0
	var custo := 0.0
	var passos := 0
	var voou := 0.0
	while t < 25.0 and not levantou[0]:
		var antes := Time.get_ticks_usec()
		await physics_frame
		custo += float(Time.get_ticks_usec() - antes)
		passos += 1
		t += 1.0 / 60.0
		if not is_instance_valid(boneco) or boneco.fase != BonecoDePano.Fase.VOANDO \
				and boneco.fase != BonecoDePano.Fase.CHAO:
			continue
		pancada = boneco.maior_pancada()
		var sk := corpo.esqueleto()
		var dobra_agora := 0.0
		for osso: int in BonecoDePano.PARTES:
			var p := boneco.peca(osso)
			if p == null:
				continue
			mais_baixo = minf(mais_baixo, p.global_position.y)
			voou = maxf(voou, p.global_position.y)
			var pai := sk.get_bone_parent(osso)
			if pai < 0:
				continue
			var pp := boneco.peca(pai)
			var esperado := pp.global_transform * sk.get_bone_rest(osso).origin
			var aberta := esperado.distance_to(p.global_position)
			pior_junta = maxf(pior_junta, aberta)
			soma_junta += aberta
			n_junta += 1
			var local := (pp.global_basis.inverse() * p.global_basis).get_euler()
			if osso == O.CANELA_E or osso == O.CANELA_D:
				dobra_agora = maxf(dobra_agora, local.x)
			elif osso == O.ANTEBRACO_E or osso == O.ANTEBRACO_D:
				dobra_agora = maxf(dobra_agora, -local.x)
		pior_dobra = maxf(pior_dobra, dobra_agora)
		if dobra_agora > DOBRA_ERRADA:
			quadros_dobra += 1

	var media := soma_junta / maxf(1.0, n_junta)
	_conta("%s: junta nao abre" % nome, pior_junta < JUNTA_ABRE and media < JUNTA_MEDIA,
		"pico %.3f m, media %.4f m" % [pior_junta, media])
	_conta("%s: joelho e cotovelo dobram do lado certo" % nome, quadros_dobra <= QUADROS_DOBRA,
		"%d quadros acima de %.2f rad (pico %.2f)" % [quadros_dobra, DOBRA_ERRADA, pior_dobra])
	_conta("%s: nao atravessa o chao" % nome, mais_baixo > -ATRAVESSA, "%.3f m" % mais_baixo)
	_conta("%s: levanta" % nome, levantou[0], "%.1f s" % t)
	_conta("%s: fica de pe no chao" % nome, absf(corpo.global_position.y) < 0.15
		and not corpo.dominado, "y %.2f" % corpo.global_position.y)
	print("  %s: %.2f ms por passo, subiu ate %.2f m, pancada %.1f m/s, andou %.1f m" % [nome,
		custo / 1000.0 / maxf(1.0, passos), voou,
		pancada, Vector2(corpo.global_position.x, corpo.global_position.z).length()])
	if carro != null:
		carro.queue_free()
	dono.queue_free()
	await physics_frame


func _conta(nome: String, ok: bool, texto: String = "") -> void:
	_total += 1
	if ok:
		_passou += 1
	print("  [%s] %s  %s" % ["ok" if ok else "FALHOU", nome, texto])
