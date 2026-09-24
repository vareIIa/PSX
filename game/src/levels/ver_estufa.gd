## Rota de captura da estufa DE VERDADE: a debaixo de uma casa da fumaca da rua.
##
## A estufa deixou de ser teleportada, e o que importa nela agora nao cabe na
## rota antiga (`--entrar-estufa`, que monta o comodo dois mil metros acima da
## cidade). Aqui o jogador vai a calcada de uma casa da fumaca que existe no
## mundo, espera o InteriorNoMundo pre-aquecer a casa e a estufa, abre a porta
## dos fundos pelo [E] e DESCE A ESCADA ANDANDO — que e o unico jeito de provar
## que a rampa, o furo no chao da quadra e a troca de ar funcionam. Depois
## fotografa cada trecho por teleporte, com a camera parada.
##
##     godot --path game -- --ver-estufa-mundo --casa=1,-7 --fotos-estufa=DIR
##
## Imprime `[ver_estufa] chave=valor`.
class_name VerEstufa
extends RefCounted

const CASA_PADRAO := Vector2i(1, -7)
const ESPERA_MAX := 25.0


## Engole toda a entrada enquanto a rota roda. A janela de captura abre na frente
## de quem esta usando a maquina e recebe as teclas dele: numa execucao o
## celular abriu no meio da porta, noutra uma conversa com o Helmer congelou os
## dois fazendeiros quarenta segundos e a rota mediu a conversa. Mesmo remedio
## da RotaCaptura: o ultimo filho da raiz ve a entrada primeiro.
class Engolidor extends Node:
	func _ready() -> void:
		_ir_para_o_fim()

	func _ir_para_o_fim() -> void:
		if not is_inside_tree():
			return
		var raiz := get_tree().root
		if get_index() != raiz.get_child_count() - 1:
			raiz.move_child(self, -1)
		get_tree().create_timer(0.5, true, false, true).timeout.connect(_ir_para_o_fim)

	func _input(_evento: InputEvent) -> void:
		get_viewport().set_input_as_handled()


static func executar(cena: Node, jogador: Node3D) -> void:
	var arvore := cena.get_tree()
	IWeed.pausado = true
	var casa := CASA_PADRAO
	var pasta := "user://ver_estufa"
	var so_andar := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--casa="):
			var partes := arg.trim_prefix("--casa=").split(",")
			casa = Vector2i(int(partes[0]), int(partes[1]))
		elif arg.begins_with("--fotos-estufa="):
			pasta = arg.trim_prefix("--fotos-estufa=")
		elif arg == "--so-andar":
			so_andar = true
	DirAccess.make_dir_recursive_absolute(pasta)
	var engolidor := Engolidor.new()
	engolidor.name = "EngoleEntradaDaRota"
	arvore.root.add_child.call_deferred(engolidor)
	await arvore.create_timer(1.0).timeout

	var porta := _porta_da_casa(casa)
	if porta.is_empty():
		_relatar("casa_ausente", casa)
		arvore.quit(1)
		return
	var t: Transform3D = porta["planta"]
	var off := Vector3(casa.x * 32.0, 0.0, casa.y * 32.0)
	var calcada := t * Vector3(2.2, 0.0, -3.5) + off
	calcada.y = Relevo.altura(calcada.x, calcada.z) + 1.0
	jogador.global_position = calcada
	jogador.call("olhar_para", t * Vector3(2.2, 1.5, 0.0) + off)

	var inm := await _esperar_casa(arvore, calcada)
	if inm == null:
		_relatar("casa_nao_montou", 1)
		arvore.quit(1)
		return
	_relatar("estufa_montada", 1 if inm.estufa() != null else 0)

	# O puxadinho visto do quintal, antes de qualquer descida: o furo no chao da
	# quadra so vale para quem esta no porao.
	if not so_andar:
		await _por(arvore, jogador, inm.to_global(Vector3(2.2, -0.2, 19.2)),
			inm.to_global(Vector3(6.8, 1.2, 17.6)))
		await _foto(arvore, pasta, "00_quintal")

	# O corredor, de frente para a porta dos fundos fechada.
	await _por(arvore, jogador, inm.to_global(Vector3(7.4, 0.0, 13.2)),
		inm.to_global(Vector3(7.4, 1.25, 15.6)))
	if not so_andar:
		await _foto(arvore, pasta, "01_porta_fechada")
	var area := _porta_dos_fundos(inm)
	_relatar("porta_achada", 1 if area != null else 0)
	if area != null:
		area.interagir(jogador)
		await arvore.create_timer(0.9).timeout
	if not so_andar:
		await _foto(arvore, pasta, "02_porta_aberta")

	# A descida, andando. Lance A (+Z da casa) ate o patamar do meio, vira, e
	# lance B ate a boca da estufa.
	await _por(arvore, jogador, inm.to_global(Vector3(7.45, 0.0, 14.8)),
		inm.to_global(Vector3(7.45, 0.0, 30.0)))
	await _andar(arvore, jogador, 3.2)
	var p := inm.to_local(jogador.global_position)
	_relatar("lance_a_fim", "%.2f,%.2f,%.2f" % [p.x, p.y, p.z])
	jogador.call("olhar_para", inm.to_global(Vector3(6.05, p.y, 19.3)))
	await _andar(arvore, jogador, 0.7)
	jogador.call("olhar_para", inm.to_global(Vector3(6.05, p.y, 0.0)))
	await _andar(arvore, jogador, 4.2)
	p = inm.to_local(jogador.global_position)
	_relatar("lance_b_fim", "%.2f,%.2f,%.2f" % [p.x, p.y, p.z])
	_relatar("chegou_na_estufa", 1 if p.y < -3.0 and p.z < 15.7 else 0)
	_relatar("interior_tipo", Interiores.tipo_atual())
	if so_andar:
		# E sobe de volta: a rampa tem de servir nos dois sentidos.
		jogador.call("olhar_para", inm.to_global(Vector3(6.05, p.y, 30.0)))
		await _andar(arvore, jogador, 4.0)
		jogador.call("olhar_para", inm.to_global(Vector3(7.45, p.y, 17.0)))
		await _andar(arvore, jogador, 0.8)
		jogador.call("olhar_para", inm.to_global(Vector3(7.45, 0.0, 0.0)))
		await _andar(arvore, jogador, 4.0)
		p = inm.to_local(jogador.global_position)
		_relatar("subiu_ate", "%.2f,%.2f,%.2f" % [p.x, p.y, p.z])
		_relatar("voltou_para_casa", 1 if p.y > -0.2 and p.z < 15.5 else 0)
		_relatar("fim", 1)
		arvore.quit(0)
		return

	var e := inm.estufa()
	var fotos: Array = [
		# Na soleira da porta dos fundos, olhando o vao da escada: a grama da
		# quadra passava aqui, e depois a parede de emenda do buraco dela.
		["02b_soleira", inm.to_global(Vector3(7.45, 0.0, 15.2)),
			inm.to_global(Vector3(6.8, -2.6, 18.2))],
		["03_patamar", inm.to_global(Vector3(7.45, 0.0, 16.25)),
			inm.to_global(Vector3(7.45, -1.2, 19.0))],
		# Do pe do lance B: a boca da estufa de frente, e a porta la em cima.
		["05b_pe_da_escada", inm.to_global(Vector3(6.05, -3.42, 17.2)),
			inm.to_global(Vector3(6.05, -2.4, 15.0))],
		["05c_olhando_a_porta", inm.to_global(Vector3(6.05, -3.42, 16.5)),
			inm.to_global(Vector3(6.05, -0.9, 19.6))],
		["04_guarda", inm.to_global(Vector3(6.3, 0.0, 16.2)),
			inm.to_global(Vector3(6.05, -3.2, 17.4))],
		["05_meio", inm.to_global(Vector3(6.05, -1.71, 19.3)),
			inm.to_global(Vector3(6.05, -3.0, 15.0))],
		["06_boca", inm.to_global(Vector3(6.05, -3.42, 16.45)),
			e.to_global(Vector3(6.0, 1.2, 7.0))],
		["07_lavoura", e.to_global(EstufaBuilder.ENTRADA),
			e.to_global(EstufaBuilder.OLHAR)],
		["08_grade", e.to_global(Vector3(6.0, 0.0, 6.5)),
			e.to_global(Vector3(6.3, -9.0, 8.5))],
		["09_prateleira", e.to_global(Vector3(2.45, 0.0, 2.0)),
			e.to_global(Vector3(0.8, 0.95, 2.0))],
		["10_insumos", e.to_global(Vector3(9.3, 0.0, 1.8)),
			e.to_global(Vector3(11.2, 0.6, 2.2))],
		["11_canteiro", e.to_global(Vector3(3.4, 0.0, 5.6)),
			e.to_global(Vector3(1.9, 0.5, 8.4))],
		["12_elevador", e.to_global(Vector3(6.0, 0.0, 12.6)),
			e.to_global(Vector3(6.0, 1.0, 16.0))],
		["13_de_volta", e.to_global(Vector3(6.0, 0.0, 6.0)),
			e.to_global(Vector3(6.0, 1.6, 0.0))],
	]
	for f: Array in fotos:
		await _por(arvore, jogador, f[1], f[2])
		await _foto(arvore, pasta, String(f[0]))

	# As galerias: de elevador ate o 4 (Saca-Rolha), sai na passarela e anda pela
	# galeria. E o trabalho: o que Jota e Helmer fazem, andar por andar, por 40 s.
	var el := arvore.get_first_node_in_group(&"elevador") as Elevador
	if el != null:
		var cab4 := el.cabine()
		await _esperar_cabine(arvore, el)
		await _por(arvore, jogador, cab4.global_position + Vector3(0.0, 0.05, 0.0)
			+ e.global_transform.basis * Vector3(0.0, 0.0, 0.2),
			e.to_global(Vector3(6.0, 1.4, 6.0)))
		el.botao_do_andar(4).interagir(jogador)
		var espera4 := 0.0
		while espera4 < 30.0 and not el.parada_em(4):
			await arvore.create_timer(0.1).timeout
			espera4 += 0.1
		_relatar("chegou_no_4", 1 if el.parada_em(4) else 0)
		var y4 := EstufaBuilder.nivel(4)
		var galeria: Array = [
			["20_passarela_4", Vector3(6.0, y4, 14.1), Vector3(2.9, y4 + 1.0, 6.0)],
			["21_galeria_4", Vector3(2.9, y4, 13.2), Vector3(1.8, y4 + 0.7, 5.0)],
			["22_estacao_4", Vector3(2.9, y4, 15.0), Vector3(1.6, y4 + 0.5, 17.4)],
			["23_caixote_4", Vector3(8.3, y4, 15.2), Vector3(9.0, y4 + 0.4, 17.0)],
			["24_do_outro_lado", Vector3(3.2, y4, 9.0), Vector3(10.5, y4 + 0.9, 9.0)],
		]
		for f: Array in galeria:
			await _por(arvore, jogador, e.to_global(f[1]), e.to_global(f[2]))
			await _foto(arvore, pasta, String(f[0]))
		var plant := arvore.get_first_node_in_group(&"plantacao") as Plantacao
		for k in 8:
			await arvore.create_timer(5.0).timeout
			var linha := PackedStringArray()
			for no: Node in arvore.get_nodes_in_group(&"convidado"):
				var c := no as Convidado
				if c == null or c.rotina != &"fazendeiro":
					continue
				var andar := EstufaBuilder.andar_de_y(e.to_local(c.global_position).y)
				var alvo: Vector3 = c.get("_alvo")
				linha.append("%s@%d:%s pos=%s alvo=%s est=%d vel=%.2f proc=%s rota=%d elev=%d" % [
					c.name, andar, c.descrever_tarefa(),
					str(e.to_local(c.global_position).snapped(Vector3.ONE * 0.01)),
					str(e.to_local(alvo).snapped(Vector3.ONE * 0.01)),
					int(c.get("_estado")), c.velocity.length(), c.can_process(),
					(c.get("_rota") as Array).size(), int(c.get("_elev_fase"))])
			_relatar("fazendeiros_%d" % k, " | ".join(linha))
		if plant != null:
			var est: Dictionary = plant.get("_estado")
			_relatar("colheitas", str(est.get("colheitas", {})))
		# Outras galerias, por teleporte: a Morcega pendurada, a Gambazona e o 9
		# apagado com a Vagalume acesa.
		for par: Array in [[2, "25_andar_2"], [8, "26_andar_8"], [9, "27_andar_9"]]:
			var yn := EstufaBuilder.nivel(int(par[0]))
			await _por(arvore, jogador, e.to_global(Vector3(3.2, yn, 13.0)),
				e.to_global(Vector3(1.0, yn + 1.1, 5.5)))
			await _foto(arvore, pasta, String(par[1]))
		# De volta a cabine pelo patamar: chama e espera.
		await _por(arvore, jogador, e.to_global(Vector3(6.0, y4, 14.3)),
			e.to_global(Vector3(6.0, y4 + 1.2, 16.0)))
		el.chamada(4).interagir(jogador)
		espera4 = 0.0
		while espera4 < 40.0 and not el.parada_em(4):
			await arvore.create_timer(0.1).timeout
			espera4 += 0.1
		_relatar("voltou_a_cabine", 1 if el.parada_em(4) else 0)

	# O elevador: entra na cabine, desce ao 10 e fotografa o poco passando.
	if el != null:
		var cab := el.cabine()
		await _esperar_cabine(arvore, el)
		await _por(arvore, jogador, cab.global_position + Vector3(0.0, 0.05, 0.2),
			e.to_global(Vector3(6.0, 1.4, 6.0)))
		_relatar("antes_do_10", "dentro=%s andar=%d hab=%s fila=%s" % [el.dentro(jogador),
			el.andar(), el.botao().habilitado, str(el.get("_fila"))])
		el.botao().interagir(jogador)
		_relatar("depois_do_10", "andando=%s fila=%s servindo=%s" % [el.andando(),
			str(el.get("_fila")), el.get("_servindo")])
		var fotos_viagem := 0
		var espera := 0.0
		# A cabine e de todos: um fazendeiro pode ter chamado antes.
		while espera < 60.0 and (el.andando() or not el.no_topo()):
			await arvore.create_timer(0.1).timeout
			espera += 0.1
			var y := cab.position.y
			if fotos_viagem == 0 and y < EstufaBuilder.nivel(4):
				fotos_viagem = 1
				await _foto(arvore, pasta, "15_descendo")
			elif fotos_viagem == 1 and y < EstufaBuilder.nivel(8):
				fotos_viagem = 2
				await _foto(arvore, pasta, "16_andar_8")
		_relatar("chegou_no_10", 1 if el.no_topo() else 0)
		_relatar("cabine_y", "%.2f" % cab.position.y)
		await arvore.create_timer(2.5).timeout
		jogador.call("olhar_para", jogador.global_position + Vector3(0.0, 1.6, 0.0)
			+ e.global_transform.basis * Vector3(0.0, 0.0, -6.0))
		await _foto(arvore, pasta, "17_quarto_10")
		jogador.call("olhar_para", e.to_global(EstufaBuilder.PLANTA
			+ Vector3(0.0, EstufaBuilder.PISO_10 + 1.6, 0.0)))
		await _foto(arvore, pasta, "18_planta_gigante")
		# E olhando para cima, pelo furo da laje: o poco inteiro ate a grade.
		jogador.call("olhar_para", jogador.global_position + Vector3(0.0, 30.0, 0.0)
			+ e.global_transform.basis * Vector3(0.0, 0.0, -1.0))
		await _foto(arvore, pasta, "19_poco_de_baixo")
	_relatar("fim", 1)
	arvore.quit(0)


## A cabine parada e com a grade aberta: os fazendeiros tambem chamam.
static func _esperar_cabine(arvore: SceneTree, el: Elevador) -> void:
	var t := 0.0
	while t < 30.0 and (el.andando() or not el.parada_em(el.andar())):
		await arvore.create_timer(0.1).timeout
		t += 0.1


static func _relatar(chave: String, valor: Variant) -> void:
	print("[ver_estufa] %s=%s" % [chave, valor])


static func _porta_da_casa(casa: Vector2i) -> Dictionary:
	for ponto: Dictionary in ChunkBuilder.pontos_de_interesse(casa.x, casa.y):
		if ponto["tipo"] == &"porta" and ponto["interior"] == &"casa_fumaca" \
				and bool(ponto.get("mundo", false)):
			return ponto
	return {}


## A casa da fumaca mais perto de `onde`, depois de montada e com todos os
## props nascidos (o ultimo nasce um quadro antes da sonda da casa).
static func _esperar_casa(arvore: SceneTree, onde: Vector3) -> InteriorNoMundo:
	var t := 0.0
	while t < ESPERA_MAX:
		await arvore.create_timer(0.25).timeout
		t += 0.25
		var melhor: InteriorNoMundo = null
		var d_melhor := INF
		for no: Node in arvore.get_nodes_in_group(&"interior_mundo"):
			var inm := no as InteriorNoMundo
			if inm == null or inm.planta != &"casa_fumaca":
				continue
			var d := inm.global_position.distance_to(onde)
			if d < d_melhor:
				d_melhor = d
				melhor = inm
		if melhor != null and melhor.estufa() != null and melhor.pronta():
			# Um segundo para o streaming em volta assentar.
			await arvore.create_timer(1.5).timeout
			return melhor
	return null


static func _porta_dos_fundos(inm: Node) -> Interativo:
	var pilha: Array[Node] = [inm]
	while not pilha.is_empty():
		var n: Node = pilha.pop_back()
		pilha.append_array(n.get_children())
		var a := n as Interativo
		if a != null and a.rotulo.contains("fundos"):
			return a
	return null


## A pausa nao abre no meio da rota. Controle ligado ou tecla perdida na janela
## (o Start/ESC e a acao `pausa`) abria o mapa, a arvore parava e a porta nao
## abria: a rota media o menu, e nao a estufa.
static func _calar_pausa(arvore: SceneTree) -> void:
	for hub: Node in arvore.get_nodes_in_group(&"pausa_hub"):
		hub.set_process_unhandled_input(false)
		if bool(hub.get(&"aberta")) and hub.has_method(&"fechar"):
			hub.call(&"fechar")
	arvore.paused = false


static func _por(arvore: SceneTree, jogador: Node3D, onde: Vector3, olhar: Vector3) -> void:
	_calar_pausa(arvore)
	jogador.global_position = onde + Vector3(0.0, 0.05, 0.0)
	if jogador.has_method("zerar_velocidade"):
		jogador.call("zerar_velocidade")
	jogador.call("olhar_para", olhar)
	for _i in 12:
		await arvore.physics_frame
	jogador.call("olhar_para", olhar)


static func _andar(arvore: SceneTree, jogador: Node3D, segundos: float) -> void:
	_calar_pausa(arvore)
	jogador.set("_auto", Vector2(0.0, -1.0))
	var t := 0.0
	while t < segundos:
		await arvore.physics_frame
		t += 1.0 / float(Engine.physics_ticks_per_second)
	jogador.set("_auto", Vector2.ZERO)
	for _i in 6:
		await arvore.physics_frame


static func _foto(arvore: SceneTree, pasta: String, nome: String) -> void:
	_calar_pausa(arvore)
	await arvore.create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var img := arvore.root.get_viewport().get_texture().get_image()
	var caminho := pasta.path_join(nome + ".png")
	img.save_png(caminho)
	_relatar("foto", caminho)
