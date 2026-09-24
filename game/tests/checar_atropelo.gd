## O pedestre de verdade contra carro e contra o jogador.
##
##     godot --headless --fixed-fps 60 --path game res://tests/checar_atropelo.tscn
##
## Cena, e nao `--script`: o Pedestre fala com os autoloads (Sessao, Conversa,
## Cinema), e script solto nao os enxerga na compilacao.
##
## Chao plano, um `Pedestre` parado e, conforme a cena:
##
## - atropelo: corpo rigido de 1100 kg no grupo "carro", a 11 m/s (40 km/h),
##   vindo reto. O pedestre tem de virar boneco de pano (CAIDO) sem a capsula
##   dele parar o carro, e levantar sozinho, de pe, onde o corpo parou;
## - encostada: o mesmo carro a 2 m/s. Tropeca (TROPECANDO) e nao cai;
## - esbarrao: um CharacterBody3D no grupo "player" correndo a 4,6 m/s de
##   encontro. Tropeca para o lado de quem veio; andando a 1 m/s, nada.
extends Node

var _passou := 0
var _total := 0
var _chao: StaticBody3D


var root: Node
var physics_frame: Signal


func _ready() -> void:
	root = get_tree().root
	physics_frame = get_tree().physics_frame
	_rodar()


func _rodar() -> void:
	await get_tree().process_frame
	_chao = StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(300.0, 1.0, 300.0)
	forma.shape = caixa
	forma.position = Vector3(0.0, -0.5, 0.0)
	_chao.add_child(forma)
	root.add_child(_chao)
	await _atropelo()
	await _encostada()
	await _esbarrao()
	await _agarra()
	await _pm()
	print("[atropelo] %d/%d" % [_passou, _total])
	get_tree().quit(0 if _passou == _total else 1)


func _pedestre(onde: Vector3) -> Pedestre:
	var ficha := RegistroCivil.identidade(4242)
	var p := Pedestre.new()
	p.preparar(ficha, Vector4i.ZERO, Vector4i(1, 0, 0, 0))
	root.add_child(p)
	p.global_position = onde
	for i in 4:
		await physics_frame
	return p


func _carro(onde: Vector3, vel: Vector3) -> RigidBody3D:
	var c := RigidBody3D.new()
	c.mass = 1100.0
	c.continuous_cd = true
	c.add_to_group(&"carro")
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.7, 1.05, 4.2)
	f.shape = b
	f.position = Vector3(0.0, 0.2 + 0.525, 0.0)
	c.add_child(f)
	root.add_child(c)
	c.global_position = onde
	c.linear_velocity = vel
	return c


func _atropelo() -> void:
	var p: Pedestre = await _pedestre(Vector3(0.0, 0.0, 0.0))
	p.esperar_parado(30.0)
	# Uma lente perto: e ela que faz o LOD montar a cara que mexe.
	var lente := Camera3D.new()
	root.add_child(lente)
	lente.position = Vector3(3.5, 1.6, -3.0)
	lente.current = true
	# Uma testemunha na calcada, a seis metros.
	var viu: Pedestre = await _pedestre(Vector3(6.0, 0.0, -1.0))
	viu.esperar_parado(30.0)
	var testemunha_reagiu := false
	var carro := _carro(Vector3(0.0, 0.0, 9.0), Vector3(0.0, 0.0, -11.0))
	var caiu := false
	var mais_rapida := 0.0
	var qual_rapida := ""
	var levantou_em := -1.0
	var gemeu := false
	var cara_de_dor := false
	var olhou_para_baixo := false
	var t := 0.0
	while t < 20.0:
		await physics_frame
		t += 1.0 / 60.0
		if not caiu and carro.global_position.z > 3.0:
			carro.linear_velocity.z = -11.0
		if caiu and viu.corpo().reacao() != 0:
			testemunha_reagiu = true
		if caiu and viu.corpo()._pitch > 0.15:
			olhou_para_baixo = true
		if p.caido() and p._fala != null and p._fala.falando() and t > 1.5:
			gemeu = true
		var r := p.corpo().rosto
		if p.caido() and r != null and r.expressao_atual() in [Rosto.Expressao.DOR,
				Rosto.Expressao.DESACORDADO]:
			cara_de_dor = true
		if p.caido():
			caiu = true
			# Nenhuma peca a mais que o dobro do carro: acima disso e explosao
			# de contato, nao atropelo (a lataria nascida na origem do mundo
			# jogou o corpo a 73 m/s).
			var bn := p.get_node_or_null(^"BonecoDePano") as BonecoDePano
			if bn != null:
				for peca: RigidBody3D in bn.pecas():
					if is_instance_valid(peca) and peca.linear_velocity.length() > mais_rapida:
						mais_rapida = peca.linear_velocity.length()
						qual_rapida = "%s em t=%.2f (y %.2f)" % [peca.name, t, peca.global_position.y]
		if caiu and levantou_em < 0.0 and p.de_pe():
			levantou_em = t
			break
		if caiu:
			carro.linear_velocity.z = move_toward(carro.linear_velocity.z, 0.0, 0.1)
	_conta("atropelo: cai", caiu)
	_conta("atropelo: quem viu reage", testemunha_reagiu,
		ReacaoCorpo.nome(viu.corpo().reacao()))
	_conta("atropelo: nenhuma peca explode", mais_rapida < 22.0,
		"peca mais rapida %.1f m/s: %s" % [mais_rapida, qual_rapida])
	_conta("atropelo: levanta sozinho", levantou_em > 0.0, "%.1f s" % levantou_em)
	_conta("atropelo: geme no chao, com boca", gemeu)
	_conta("atropelo: de perto a cara faz dor", cara_de_dor)
	_conta("atropelo: testemunha baixa o olhar para o corpo", olhou_para_baixo)
	var r := p.corpo().reacao()
	_conta("atropelo: levanta sentindo a pancada", p.corpo().mancando > 0.0
		or (r >= ReacaoCorpo.REACAO_DOR_CABECA and r <= ReacaoCorpo.REACAO_DOR_BRACO),
		"%s, mancando %.2f" % [ReacaoCorpo.nome(r), p.corpo().mancando])
	# Jogado para a frente do carro (que vinha para -z), de dois a quinze metros.
	_conta("atropelo: cai a frente do carro", absf(p.global_position.y) < 0.2
		and p.global_position.z < -2.0 and p.global_position.length() < 15.0,
		"em %s" % p.global_position.snappedf(0.1))
	_conta("atropelo: capsula de volta", p.collision_layer == 1 and p.collision_mask == 1)
	_conta("atropelo: excecoes desfeitas", not carro.get_collision_exceptions().has(p))
	p.queue_free()
	viu.queue_free()
	carro.queue_free()
	lente.queue_free()
	await physics_frame


func _encostada() -> void:
	var p: Pedestre = await _pedestre(Vector3(20.0, 0.0, 0.0))
	var carro := _carro(Vector3(20.0, 0.0, 3.0), Vector3(0.0, 0.0, -2.0))
	var tropecou := false
	var caiu := false
	for i in 150:
		await physics_frame
		if not tropecou:
			carro.linear_velocity.z = -2.0
		else:
			carro.linear_velocity.z = 0.0
		tropecou = tropecou or p.estado_nome() == &"tropecando"
		caiu = caiu or p.caido()
	_conta("encostada: tropeca", tropecou)
	_conta("encostada: nao cai", not caiu)
	p.queue_free()
	carro.queue_free()
	await physics_frame


func _esbarrao() -> void:
	var p: Pedestre = await _pedestre(Vector3(-20.0, 0.0, 0.0))
	var j := CharacterBody3D.new()
	j.add_to_group(&"player")
	var f := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.75
	f.shape = cap
	f.position = Vector3(0.0, 0.9, 0.0)
	j.add_child(f)
	j.collision_layer = 0
	j.collision_mask = 0
	root.add_child(j)
	# Andando: 1 m/s de encontro, nao deve fazer nada.
	j.global_position = Vector3(-20.0, 0.0, 1.0)
	var tropecou := false
	for i in 60:
		j.velocity = Vector3(0.0, 0.0, -1.0)
		j.global_position += j.velocity / 60.0
		await physics_frame
		tropecou = tropecou or p.estado_nome() == &"tropecando"
	_conta("esbarrao andando devagar: nada", not tropecou)
	# Correndo: 4,6 m/s. O pedestre tem de sair para -z (a direcao de quem veio).
	# Mira em quem esta andando: o pedestre nao fica parado esperando.
	j.global_position = p.global_position + Vector3(0.0, 0.0, 1.8)
	var z0 := p.global_position.z
	var perto := INF
	tropecou = false
	for i in 90:
		var rumo := (p.global_position - j.global_position) * Vector3(1, 0, 1)
		j.velocity = rumo.normalized() * 4.6 if i < 25 and not tropecou else Vector3.ZERO
		j.global_position += j.velocity / 60.0
		await physics_frame
		tropecou = tropecou or p.estado_nome() == &"tropecando"
		perto = minf(perto, Vector2(j.global_position.x - p.global_position.x,
			j.global_position.z - p.global_position.z).length())
	_conta("esbarrao correndo: tropeca", tropecou, "chegou a %.2f m (%s)" % [perto, p.estado_nome()])
	_conta("esbarrao correndo: vai para o lado do empurrao", p.global_position.z < z0 - 0.15,
		"andou %.2f m em z" % (p.global_position.z - z0))
	p.queue_free()
	j.queue_free()
	await physics_frame


## Tropeca com alguem do lado: se segura nele (a mao chega no ombro) e o outro
## balanca junto.
func _agarra() -> void:
	var p: Pedestre = await _pedestre(Vector3(-40.0, 0.0, 0.0))
	var vizinho: Pedestre = await _pedestre(Vector3(-40.0, 0.0, -0.95))
	p.esperar_parado(30.0)
	vizinho.esperar_parado(30.0)
	p.empurrar(Vector3(0.0, 0.0, -2.0), Vector3(-40.0, 0.0, 2.0))
	var segurou := false
	var mao_perto := INF
	var vizinho_balancou := false
	for i in 120:
		await physics_frame
		var c := p.corpo()
		if c.agarrar != Vector3.INF:
			segurou = true
			var sk := c.esqueleto()
			for ante: int in [Corpo.Osso.ANTEBRACO_E, Corpo.Osso.ANTEBRACO_D]:
				var g := sk.global_transform * sk.get_bone_global_pose(ante)
				var mao := g * Vector3(0.0, -(Corpo.Y_COTOVELO - Corpo.Y_PUNHO)
					* c.altura() / Corpo.ALTURA_REF, 0.0)
				mao_perto = minf(mao_perto, mao.distance_to(c.agarrar))
		vizinho_balancou = vizinho_balancou or vizinho.estado_nome() == &"tropecando"
	_conta("agarra: se segura no vizinho", segurou)
	_conta("agarra: a mao chega no ombro", mao_perto < 0.12, "%.3f m" % mao_perto)
	_conta("agarra: o vizinho balanca", vizinho_balancou)
	p.queue_free()
	vizinho.queue_free()
	await physics_frame


## O PM da blitz e um Corpo solto com capsula: o `TomboDeCorpo` derruba e
## levanta ele como a um pedestre.
func _pm() -> void:
	var c := Corpo.new()
	root.add_child(c)
	c.montar(Aparencia.de_ficha({"id": 77, "sexo": &"M", "idade": 40}))
	c.global_position = Vector3(40.0, 0.0, 0.0)
	var capsula := AnimatableBody3D.new()
	var f := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	f.shape = cap
	f.position = Vector3(0.0, 0.875, 0.0)
	capsula.add_child(f)
	capsula.collision_layer = 1
	c.add_child(capsula)
	var tombo := TomboDeCorpo.ligar(c)
	var carro := _carro(Vector3(40.0, 0.0, 9.0), Vector3(0.0, 0.0, -11.0))
	var caiu := false
	var capsula_fora := false
	var levantou := false
	for i in 900:
		await physics_frame
		c.animar(tombo.rapidez(), 1.0 / 60.0)
		if not caiu:
			carro.linear_velocity.z = -11.0
		else:
			carro.linear_velocity.z = move_toward(carro.linear_velocity.z, 0.0, 0.1)
		if tombo.caido():
			caiu = true
			capsula_fora = capsula_fora or capsula.collision_layer == 0
		if caiu and not tombo.ocupado():
			levantou = true
			break
	_conta("pm: carro derruba", caiu)
	_conta("pm: capsula sai do caminho no chao", capsula_fora)
	_conta("pm: levanta sozinho, de pe fora do carro", levantou and absf(c.global_position.y) < 0.2
		and c.global_position.distance_to(Vector3(40.0, 0.0, 0.0)) > 1.0,
		"em %s" % c.global_position.snappedf(0.1))
	_conta("pm: capsula de volta", capsula.collision_layer == 1)
	c.queue_free()
	carro.queue_free()
	await physics_frame


func _conta(nome: String, ok: bool, texto: String = "") -> void:
	_total += 1
	if ok:
		_passou += 1
	print("  [%s] %s  %s" % ["ok" if ok else "FALHOU", nome, texto])
