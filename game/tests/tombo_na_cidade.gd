## O atropelo na cidade de verdade, pela camera do jogo.
##
##     godot --path game --resolution 1280x720 res://tests/tombo_na_cidade.tscn -- --saida=DIR
##
## Monta a cidade inteira (o mesmo `scenes/test/cidade.tscn` do jogo) como
## filha, pega um carro pela porta do jogador (`TesteCarro._pegar_carro`), poe
## o carro na faixa, planta um pedestre 16 m a frente e pisa. Fotografa pela
## camera do jogo: a batida, o voo, o chao e o levantar. Com o asfalto, a guia e
## as paredes da cidade, e nao o piso liso da bancada.
##
## Com `--jogador`, e o JOGADOR que esta a pe na faixa, e um carro-caixa de
## 1100 kg (corpo rigido no grupo "carro") vem a 40 km/h: cai, perde vida,
## levanta, e a camera e o controle voltam para ele.
##
## Imprime `[tombo] chave=valor` e grava `tombo_NN.png` em DIR.
extends Node

const PASSO := 1.0 / 60.0

var _saida := ""
var _foto := 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
	var cidade: Node = (load("res://scenes/test/cidade.tscn") as PackedScene).instantiate()
	add_child(cidade)
	_rodar(cidade)


func _relatar(chave: String, valor: Variant) -> void:
	print("[tombo] %s=%s" % [chave, valor])


func _fotografar(rotulo: String) -> void:
	if _saida.is_empty():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_saida)
	var nome := "tombo_%02d_%s.png" % [_foto, rotulo]
	img.save_png(_saida.path_join(nome))
	_foto += 1


func _rodar(cidade: Node) -> void:
	var arvore := get_tree()
	var jogador: Node3D = null
	while jogador == null:
		await arvore.physics_frame
		jogador = arvore.get_first_node_in_group(&"player") as Node3D
	if OS.get_cmdline_user_args().has("--jogador"):
		await _jogador_atropelado(cidade, jogador)
		return
	var carro: Carro = await TesteCarro._pegar_carro(cidade, jogador)
	if carro == null:
		_relatar("carro", 0)
		arvore.quit(1)
		return
	Transito.ativo = false
	Transito.limpar()
	await arvore.physics_frame
	_relatar("na_faixa", 1 if await TesteCarro._por_na_reta(cidade, carro) else 0)

	# Pedestre plantado na faixa, 16 m a frente (a frente do carro e -Z).
	var frente := -carro.global_basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var onde := carro.global_position + frente * 16.0
	var espaco := carro.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(onde + Vector3.UP * 3.0, onde + Vector3.DOWN * 6.0, 1)
	q.exclude = [carro.get_rid()]
	var chao := espaco.intersect_ray(q)
	if not chao.is_empty():
		onde.y = (chao["position"] as Vector3).y
	# Bebado: nao desvia (ver `Pedestre._reflexo`), e fica parado na faixa.
	var ficha := RegistroCivil.identidade(777).duplicate()
	ficha["personalidade"] = 5
	var ped := Pedestre.new()
	ped.preparar(ficha, Vector4i.ZERO, Vector4i.ZERO)
	cidade.add_child(ped)
	ped.global_position = onde
	ped.esperar_parado(30.0)
	# Atravessando: de lado para o carro.
	ped.rotation.y = atan2(-frente.z, frente.x)
	await arvore.create_timer(0.3).timeout
	# Camera de lado, seguindo a pessoa: a do jogo fica atras do carro e o
	# proprio carro tapa o atropelo.
	var cam := Camera3D.new()
	cam.fov = 55.0
	cidade.add_child(cam)
	var lado := frente.cross(Vector3.UP).normalized()
	cam.current = true

	var caiu := false
	var t := 0.0
	var pico := 0.0
	var fotos_depois := [0.1, 0.3, 0.6, 1.0, 1.6, 2.6, 4.0]
	var t_batida := -1.0
	while t < 25.0:
		await arvore.physics_frame
		t += PASSO
		var foco := ped.global_position + Vector3.UP * 0.7
		cam.global_position = foco + lado * 6.5 + Vector3.UP * 2.2 - frente * 1.5
		cam.look_at(foco, Vector3.UP)
		var v := absf(carro.velocidade())
		pico = maxf(pico, v)
		if not caiu:
			carro.pilotar(1.0 if v < 11.5 else 0.0, 0.0, 0.0)
			if ped.caido():
				caiu = true
				t_batida = t
				_relatar("velocidade_na_batida_kmh", snappedf(v * 3.6, 0.1))
				await _fotografar("batida")
			elif t > 8.0:
				break
			continue
		# Freia ate parar e solta: pe no freio com o carro parado engata a re.
		carro.pilotar(0.0, 1.0 if v > 0.4 else 0.0, 0.0)
		if not fotos_depois.is_empty() and t - t_batida >= float(fotos_depois[0]):
			await _fotografar("depois_%.1f" % fotos_depois[0])
			fotos_depois.pop_front()
		if ped.de_pe():
			_relatar("levantou_em_s", snappedf(t - t_batida, 0.1))
			await _fotografar("de_pe")
			break
	_relatar("caiu", 1 if caiu else 0)
	_relatar("voou_m", snappedf(ped.global_position.distance_to(onde), 0.1))
	_relatar("em_pe_no_chao", 1 if ped.de_pe() else 0)
	_relatar("fim", 1)
	AudioDirector.silenciar_tudo()
	await arvore.process_frame
	arvore.quit(0)


func _jogador_atropelado(cidade: Node, jogador: Node3D) -> void:
	var arvore := get_tree()
	await arvore.create_timer(4.0).timeout
	Transito.ativo = false
	Transito.limpar()
	var tombo := jogador.get_node_or_null(^"TomboDoJogador") as TomboDoJogador
	_relatar("tem_tombo", 1 if tombo != null else 0)
	if tombo == null:
		arvore.quit(1)
		return
	# Um trecho de rua livre perto: o carro vem por ele, na direcao da faixa.
	var trechos := Vias.trechos_perto(jogador.global_position, 0.0, 60.0)
	if trechos.is_empty():
		_relatar("rua", 0)
		arvore.quit(1)
		return
	# O primeiro trecho com chao montado embaixo (chunk carregado).
	var espaco := jogador.get_world_3d().direct_space_state
	var escolhido: Dictionary = trechos[0]
	for tr: Dictionary in trechos:
		var pt: Vector3 = Transito.ponto_de_nascimento(tr)
		var raio := PhysicsRayQueryParameters3D.create(pt + Vector3.UP, pt + Vector3.DOWN * 2.0, 1)
		if not espaco.intersect_ray(raio).is_empty():
			escolhido = tr
			break
	var q: Vector4i = escolhido["trecho"]
	var dir := Vias.direcao(Vias.trecho_eixo(q), Vias.trecho_sentido(q))
	var ponto: Vector3 = Transito.ponto_de_nascimento(escolhido)
	jogador.global_position = ponto + Vector3.UP * 0.1
	jogador.call("zerar_velocidade")
	await arvore.create_timer(0.5).timeout
	var vida0 := Inventario.vida
	var carro := RigidBody3D.new()
	carro.mass = 1100.0
	carro.continuous_cd = true
	carro.add_to_group(&"carro")
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.7, 1.05, 4.2)
	f.shape = b
	f.position = Vector3(0.0, 0.2 + 0.525, 0.0)
	carro.add_child(f)
	var vis := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = b.size
	vis.mesh = bm
	vis.position = f.position
	carro.add_child(vis)
	cidade.add_child(carro)
	var frente := Vector3(dir.x, 0.0, dir.z).normalized()
	carro.global_position = jogador.global_position - frente * 14.0
	carro.look_at(carro.global_position + frente, Vector3.UP)
	var caiu := false
	var t := 0.0
	var t_batida := -1.0
	var fotos := [0.15, 0.4, 0.8, 1.4, 2.4, 3.6]
	while t < 20.0:
		await arvore.physics_frame
		t += PASSO
		if not caiu:
			carro.linear_velocity = frente * 11.0
			if tombo.caido():
				caiu = true
				t_batida = t
				await _fotografar("jogador_batida")
			elif t > 5.0:
				break
			continue
		carro.linear_velocity = carro.linear_velocity.move_toward(Vector3.ZERO, 0.12)
		if not fotos.is_empty() and t - t_batida >= float(fotos[0]):
			await _fotografar("jogador_%.1f" % fotos[0])
			fotos.pop_front()
		if not tombo.caido():
			await _fotografar("jogador_de_pe")
			break
	var cam := jogador.call("camera") as Camera3D
	_relatar("jogador_caiu", 1 if caiu else 0)
	_relatar("jogador_levantou_em_s", snappedf(t - t_batida, 0.1))
	_relatar("jogador_perdeu_vida", vida0 - Inventario.vida)
	_relatar("controle_de_volta", 0 if bool(jogador.get("travado")) else 1)
	_relatar("camera_de_volta", 1 if cam != null and cam.current else 0)
	_relatar("fim", 1)
	AudioDirector.silenciar_tudo()
	await arvore.process_frame
	arvore.quit(0)
