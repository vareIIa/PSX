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
	var so_sacola := false
	var so_lida := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--casa="):
			var partes := arg.trim_prefix("--casa=").split(",")
			casa = Vector2i(int(partes[0]), int(partes[1]))
		elif arg.begins_with("--fotos-estufa="):
			pasta = arg.trim_prefix("--fotos-estufa=")
		elif arg == "--so-andar":
			so_andar = true
		elif arg == "--so-sacola":
			so_sacola = true
		elif arg == "--so-lida":
			so_lida = true
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
	if so_lida:
		await _lida(arvore, jogador, e, pasta)
		_relatar("fim", 1)
		arvore.quit(0)
		return
	if so_sacola:
		await _sacola(arvore, jogador, e, pasta)
		_relatar("fim", 1)
		arvore.quit(0)
		return
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
		# O acabamento: o painel pintado da parede sul, visto do patamar (o que
		# se ve ao sair da cabine) e de perto, e o 9 fosforescente.
		for par: Array in [[4, "28_painel_do_patamar", Vector3(6.0, 1.6, 13.9)],
				[6, "29_painel_de_perto", Vector3(6.1, 1.6, 2.7)],
				[9, "30_painel_9", Vector3(6.0, 1.6, 13.9)]]:
			var yn := EstufaBuilder.nivel(int(par[0]))
			var de: Vector3 = par[2]
			await _por(arvore, jogador, e.to_global(Vector3(de.x, yn, de.z)),
				e.to_global(Vector3(6.1, yn + 1.75, 0.0)))
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


## A sacola de colheita (SacolaDeColheita) e o deposito (DepositoDaEstufa).
##
## A pilha ja comeca com uma safra (doze sacos de variedades diferentes e a
## prateleira transbordando de potes), para a foto dela valer. Um fazendeiro com
## a sacola CHEIA no corredor da lavoura tem de ir sozinho aos paletes e jogar o
## saco na pilha; o outro, no 4, com tres plantas, segue colhendo. A camera
## acompanha o de sacola cheia, e fotografa o saco no ar quando ele voa.
static func _sacola(arvore: SceneTree, jogador: Node3D, e: Node3D, pasta: String) -> void:
	var plant := arvore.get_first_node_in_group(&"plantacao") as Plantacao
	var faz: Array[Convidado] = []
	for no: Node in arvore.get_nodes_in_group(&"convidado"):
		var c := no as Convidado
		if c != null and c.rotina == &"fazendeiro":
			faz.append(c)
	_relatar("sacola_fazendeiros", faz.size())
	if faz.size() < 2 or plant == null:
		return
	var est: Dictionary = plant.get("_estado")
	# A safra de antes: a pilha e os potes.
	var safra: Array = [[&"morcega", 30], [&"bonsai", 20], [&"saca_rolha", 30],
		[&"girafa", 20], [&"pompom", 40], [&"chorona", 30], [&"gambazona", 50],
		[&"vagalume", 20], [&"morcega", 30], [&"saca_rolha", 30], [&"pompom", 40],
		[&"gambazona", 50]]
	var colheitas := {}
	var pilha: Array = []
	for par: Array in safra:
		colheitas[par[0]] = int(colheitas.get(par[0], 0)) + int(par[1])
		pilha.append({"v": String(par[0]), "q": int(par[1])})
	est["colheitas"] = colheitas
	est["pilha"] = pilha
	est["colhido"] = Plantio.POTES * Plantio.POR_POTE + 70
	var y4 := EstufaBuilder.nivel(4)
	var cheio := faz[0]
	var meio := faz[1]
	for par: Array in [[cheio, 10, Vector3(3.4, 0.0, 7.0), &"gambazona"],
			[meio, 3, Vector3(3.2, y4, 9.0), &"saca_rolha"]]:
		var c: Convidado = par[0]
		var id := int(c.ficha["id"])
		Plantio.esvaziar_sacola(est, id)
		for k in int(par[1]):
			Plantio.por_na_sacola(est, id, par[3], 5 if par[3] == &"gambazona" else 3)
		c.call("_largar_elevador")
		c.set("_tarefa", {})
		(c.get("_rota") as Array).clear()
		c.set("_elev_fase", 0)
		c.global_position = e.to_global(par[2])
		c.set("_y_piso", c.position.y)
		c.set("_estado", Convidado.Estado.PARADO)
		c.set("_espera", 0.4)
	# Gravado, como faz a colheita de verdade: a Plantacao rele o estado do
	# WorldState a cada meio segundo (`sincronizar`).
	plant.call("_gravar")
	for c: Convidado in [cheio, meio]:
		var s := plant.sacola(int(c.ficha["id"]))
		(c.get("_saco") as SacolaDeColheita).restaurar(s["carga"], int(s["plantas"]))
		c.set("_saco_lido", true)
	await arvore.create_timer(1.5).timeout
	await _por(arvore, jogador, e.to_global(Vector3(5.6, 0.0, 3.1)),
		e.to_global(Vector3(2.6, 0.6, 1.3)))
	await _foto(arvore, pasta, "33_pilha_antes")
	var sc := cheio.get("_saco") as SacolaDeColheita
	var voou := false
	for k in 30:
		var b := cheio.global_transform.basis.orthonormalized()
		if cheio.descrever_tarefa().begins_with("JOGANDO"):
			# Vai jogar: a camera ja fica de frente para a pilha, e fotografa o saco
			# no meio do arco, quadro a quadro.
			await _por(arvore, jogador, e.to_global(Vector3(5.0, 0.0, 2.6)),
				e.to_global(Vector3(2.8, 1.0, 1.0)))
			var espera := 0.0
			while espera < 8.0 and not (sc.voando() and float(sc.get("_voo")) > 0.45):
				await arvore.physics_frame
				espera += 1.0 / 60.0
			await RenderingServer.frame_post_draw
			voou = sc.voando()
			_relatar("no_ar", "saco=%s voo=%.2f" % [
				str(e.to_local(sc.global_position).snapped(Vector3.ONE * 0.01)),
				float(sc.get("_voo"))])
			var img := arvore.root.get_viewport().get_texture().get_image()
			img.save_png(pasta.path_join("34_no_ar.png"))
			break
		var cam := cheio.global_position + b.z * 2.7 - b.x * 0.7
		await _por(arvore, jogador, cam, cheio.global_position + Vector3.UP * 0.8)
		if k % 3 == 0:
			await _foto(arvore, pasta, "31_sacola_%02d" % k)
		_relatar("sacola_%02d" % k, "%s plantas=%d pos=%s" % [cheio.descrever_tarefa(),
			sc.plantas, str(e.to_local(cheio.global_position).snapped(Vector3.ONE * 0.01))])
		await arvore.create_timer(0.5).timeout
	_relatar("voou", 1 if voou else 0)
	await arvore.create_timer(2.0).timeout
	est = plant.get("_estado")
	_relatar("pilha_depois", "%d sacos, gambazona=%d" % [
		DepositoDaEstufa.sacos(Plantio.pilha_de(est), est.get("colheitas", {}), 0).size(),
		Plantio.colheita_de(est, &"gambazona")])
	await _por(arvore, jogador, e.to_global(Vector3(5.6, 0.0, 3.1)),
		e.to_global(Vector3(2.6, 0.6, 1.3)))
	await _foto(arvore, pasta, "35_pilha_depois")
	await _por(arvore, jogador, e.to_global(Vector3(2.6, 0.0, 1.75)),
		e.to_global(Vector3(0.9, 0.9, 3.3)))
	await _foto(arvore, pasta, "36_potes")
	await _por(arvore, jogador, e.to_global(Vector3(4.4, 0.0, 3.2)),
		e.to_global(Vector3(2.5, 0.7, 0.4)))
	await _foto(arvore, pasta, "37_pilha_de_perto")
	await _por(arvore, jogador, e.to_global(Vector3(2.7, 0.0, 2.0)),
		e.to_global(Vector3(2.6, 0.55, 0.9)))
	await _foto(arvore, pasta, "38_saco_de_frente")
	await _por(arvore, jogador, e.to_global(Vector3(3.6, 0.0, 3.3)),
		e.to_global(Vector3(2.5, 0.25, 2.8)))
	await _foto(arvore, pasta, "39_vitrine")
	var b2 := meio.global_transform.basis.orthonormalized()
	await _por(arvore, jogador, meio.global_position - b2.x * 2.2 - b2.z * 1.0,
		meio.global_position + Vector3.UP * 0.8)
	await _foto(arvore, pasta, "32_sacola_media")
	_relatar("sacola_media", meio.descrever_tarefa())


## A lida com a sacola (LidaDaSacola), em rajadas: cada gesto fotografado em
## camera lenta, com o relogio da lida no nome do quadro, para o mosaico
## (tools/mosaico_rajada.py).
static func _lida(arvore: SceneTree, jogador: Node3D, e: Node3D, pasta: String) -> void:
	var plant := arvore.get_first_node_in_group(&"plantacao") as Plantacao
	var faz: Array[Convidado] = []
	for no: Node in arvore.get_nodes_in_group(&"convidado"):
		var c := no as Convidado
		if c != null and c.rotina == &"fazendeiro":
			faz.append(c)
	if faz.size() < 2 or plant == null:
		_relatar("lida_sem_fazendeiros", faz.size())
		return
	var est: Dictionary = plant.get("_estado")
	var a := faz[0]
	var b := faz[1]
	# O vaso da lavoura mais perto do corredor do meio, pronto para colher.
	var vaso := -1
	var md := INF
	for i in Variedades.VASOS_DA_LAVOURA:
		var d := plant.vasos_em[i].distance_to(Vector3(3.0, 0.0, 6.0))
		if d < md:
			md = d
			vaso = i
	var vs: Array = plant.vasos()
	vs[vaso * Plantio.CAMPOS + Plantio.FASE] = Plantio.Fase.PRONTA
	vs[vaso * Plantio.CAMPOS + Plantio.CRESCIMENTO] = Plantio.MIL
	vs[vaso * Plantio.CAMPOS + Plantio.AGUA] = Plantio.MIL
	# A colhe com quatro plantas de comum no saco (ja vai ao chao); B espera no
	# deposito com o saco cheio de Gambazona.
	var onde: Vector3 = plant.vasos_em[vaso]
	var de: Vector3 = a.call("_de_onde_mexer", onde)
	_tomar(a, plant, de, [[&"comum", 3], [&"comum", 3], [&"comum", 3], [&"comum", 3]])
	_tomar(b, plant, DepositoDaEstufa.PONTO + Vector3(2.4, 0.0, 1.4),
		[[&"gambazona", 5], [&"gambazona", 5], [&"gambazona", 5], [&"gambazona", 5],
		[&"gambazona", 5], [&"gambazona", 5], [&"gambazona", 5], [&"gambazona", 5],
		[&"gambazona", 5], [&"gambazona", 5]])
	plant.call("_gravar")
	plant.call("_refazer")
	for c: Convidado in [a, b]:
		var s := plant.sacola(int(c.ficha["id"]))
		(c.get("_saco") as SacolaDeColheita).restaurar(s["carga"], int(s["plantas"]))
		c.set("_saco_lido", true)
	await arvore.create_timer(1.5).timeout

	# 1. Colher, e pegar o saco do chao depois.
	a.set("_tarefa", {"acao": &"colher", "vaso": vaso, "onde": onde})
	a.set("_buscando", false)
	a.call("_encarar", plant.to_global(onde))
	for _i in 30:
		await arvore.physics_frame
	var ba := a.global_transform.basis.orthonormalized()
	# Da frente, pela esquerda dele, que e onde o saco vai ao chao: a mao que
	# guarda o punhado fica de frente para a lente.
	var cam1 := a.global_position - ba.x * 1.7 - ba.z * 1.5 + Vector3.UP * 1.75
	await _por(arvore, jogador, a.global_position + ba.x * 3.2, a.global_position)
	a.call("_chegou_na_tarefa")
	await _rajada(arvore, pasta, "lida_colher", 5.6, cam1,
		a.global_position - ba.z * 0.3 + Vector3.UP * 0.7, _sonda(a))
	var sa := a.get("_saco") as SacolaDeColheita
	_relatar("colheu", "plantas=%d fase=%d" % [sa.plantas, Plantio.fase_de(plant.vasos(), vaso)])

	# 2. Arremessar o saco cheio: de frente para a pilha, vista do lado.
	var ponto := plant.to_global(DepositoDaEstufa.PONTO)
	b.global_position = ponto
	b.set("_y_piso", b.position.y)
	b.set("_tarefa", {"acao": &"esvaziar", "onde": DepositoDaEstufa.OLHAR, "vaso": -1})
	b.set("_buscando", false)
	b.call("_encarar", plant.to_global(DepositoDaEstufa.OLHAR))
	for _i in 40:
		await arvore.physics_frame
	await _por(arvore, jogador, plant.to_global(Vector3(5.2, 0.0, 3.4)),
		plant.to_global(Vector3(2.7, 1.0, 1.1)))
	b.call("_chegou_na_tarefa")
	await _rajada(arvore, pasta, "lida_arremesso", 3.9, plant.to_global(Vector3(4.45, 2.1, 3.0)),
		plant.to_global(Vector3(2.55, 0.85, 1.2)), _sonda(b))
	est = plant.get("_estado")
	_relatar("arremesso", "pilha=%d gambazona=%d" % [
		DepositoDaEstufa.sacos(Plantio.pilha_de(est), est.get("colheitas", {}), 0).size(),
		Plantio.colheita_de(est, &"gambazona")])

	# 3. Despejar a comum nos potes da bancada.
	var d3 := plant.ponto_do_deposito(true)
	_tomar(a, plant, d3["de"], [[&"comum", 3], [&"comum", 3], [&"comum", 3],
		[&"comum", 3], [&"comum", 3], [&"comum", 3]])
	plant.call("_gravar")
	var s3 := plant.sacola(int(a.ficha["id"]))
	sa.restaurar(s3["carga"], int(s3["plantas"]))
	a.set("_tarefa", {"acao": &"esvaziar", "onde": d3["olhar"], "vaso": -1})
	a.call("_encarar", plant.to_global(d3["olhar"]))
	for _i in 40:
		await arvore.physics_frame
	await _por(arvore, jogador, plant.to_global(Vector3(2.3, 0.0, 4.9)),
		plant.to_global(Vector3(d3["de"])))
	var antes := int(plant.get("_estado").get("colhido", 0))
	a.call("_chegou_na_tarefa")
	await _rajada(arvore, pasta, "lida_despejar", 3.5, plant.to_global(Vector3(2.1, 1.9, 4.1)),
		plant.to_global(Vector3(d3["de"]) + Vector3(-0.35, 0.9, 0.0)))
	_relatar("despejou", "plantas=%d colhido %d -> %d" % [sa.plantas, antes,
		int(plant.get("_estado").get("colhido", 0))])

	# 4. Pegar do chao um saco pesado (a forca).
	_tomar(b, plant, DepositoDaEstufa.PONTO + Vector3(1.8, 0.0, 1.6),
		[[&"pompom", 4], [&"pompom", 4], [&"pompom", 4], [&"pompom", 4], [&"pompom", 4],
		[&"pompom", 4], [&"pompom", 4], [&"pompom", 4]])
	plant.call("_gravar")
	var sb := b.get("_saco") as SacolaDeColheita
	var s4 := plant.sacola(int(b.ficha["id"]))
	sb.restaurar(s4["carga"], int(s4["plantas"]))
	for _i in 30:
		await arvore.physics_frame
	var bb := b.global_transform.basis.orthonormalized()
	# Trabalhando "para sempre" enquanto o saco assenta no chao e a camera chega;
	# zerar o relogio termina o trabalho, e quem termina pega o saco (Convidado).
	b.set("_ate_terminar", 999.0)
	b.set("_estado", Convidado.Estado.TRABALHANDO)
	sb.pousar(b.global_position - bb.x * 0.8 + bb.z * 0.12)
	for _i in 50:
		await arvore.physics_frame
	await _por(arvore, jogador, b.global_position - bb.z * 3.4 + bb.x * 1.6,
		b.global_position)
	b.set("_ate_terminar", 0.0)
	await _rajada(arvore, pasta, "lida_pegar", 2.3,
		b.global_position - bb.z * 2.3 + bb.x * 1.1 + Vector3.UP * 1.85,
		b.global_position - bb.x * 0.2 + Vector3.UP * 0.7, _sonda(b))
	_relatar("pegou", "pousada=%s costas=%s" % [sb.esta_pousada(), sb.nas_costas()])

	# 5. Andando pelo corredor com o saco pesado nas costas: o tranco de ajeitar.
	b.global_position = plant.to_global(Vector3(3.8, 0.0, 3.6))
	b.set("_y_piso", b.position.y)
	(b.get("_rota") as Array).clear()
	b.set("_tarefa", {})
	b.set("_t_ajeitar", 0.9)
	for _i in 20:
		await arvore.physics_frame
	await _por(arvore, jogador, plant.to_global(Vector3(6.4, 0.0, 6.6)),
		plant.to_global(Vector3(3.8, 0.9, 5.0)))
	b.call("_ir", plant.to_global(Vector3(3.8, 0.0, 9.5)))
	await _rajada(arvore, pasta, "lida_ajeitar", 2.6, plant.to_global(Vector3(5.6, 1.7, 6.4)),
		plant.to_global(Vector3(3.8, 0.85, 5.2)), _sonda(b))


## Uma linha por quadro da rajada: a lida e o saco (no referencial de quem o
## carrega), a velocidade dele e o empurrao do mundo agora.
static func _sonda(c: Convidado) -> Callable:
	var sc := c.get("_saco") as SacolaDeColheita
	return func() -> String:
		var l: LidaDaSacola = c.get("_lida")
		var loc := c.global_basis.orthonormalized().inverse() * (sc.global_position - c.global_position)
		return "%s t=%.2f saco=%s pous=%s mao=%s v=%s R=%.2f" % [
			"-" if l == null else LidaDaSacola.Tipo.keys()[l.tipo], -1.0 if l == null else l.t,
			str(loc.snapped(Vector3.ONE * 0.01)), sc.esta_pousada(), sc.nas_maos(),
			str((sc.get("_v") as Vector3).snapped(Vector3.ONE * 0.01)), sc.raio()]


## Tira o fazendeiro do que fazia e o poe em `local` (coordenada da plantacao),
## parado, com o saco refeito com `plantas` ([variedade, unidades] por planta).
##
## O estado e relido AQUI, e gravado: a Plantacao troca o dicionario dela pelo
## do WorldState a cada meio segundo, e o que se escreve num lido antes some.
static func _tomar(c: Convidado, plant: Plantacao, local: Vector3, plantas: Array) -> void:
	if c.get("_lida") != null:
		c.call("_cancelar_lida")
	var est: Dictionary = plant.get("_estado")
	var id := int(c.ficha["id"])
	Plantio.esvaziar_sacola(est, id)
	for par: Array in plantas:
		Plantio.por_na_sacola(est, id, par[0], int(par[1]))
	plant.call("_gravar")
	var s := plant.sacola(id)
	(c.get("_saco") as SacolaDeColheita).restaurar(s["carga"], int(s["plantas"]))
	c.set("_saco_lido", true)
	c.call("_largar_elevador")
	c.set("_tarefa", {})
	(c.get("_rota") as Array).clear()
	c.set("_elev_fase", 0)
	c.global_position = plant.to_global(local)
	c.set("_y_piso", c.position.y)
	c.set("_estado", Convidado.Estado.PARADO)
	c.set("_espera", 30.0)
	c.velocity = Vector3.ZERO


## Fotografa `segundos` de jogo em camera lenta. O nome de cada quadro e o
## tempo de jogo desde o comeco da rajada.
##
## O relogio e o da FISICA (ticks contados), e nao o de parede: salvar um PNG
## por quadro trava o quadro, a fisica fica para tras do relogio real, e o
## tempo de parede esticava o gesto quase duas vezes. `onde`/`olhar`: uma camera
## livre, alta, no lugar da do jogador (a 1,6 m do chao e a dois metros, o saco
## cheio tapa o corpo inteiro).
static func _rajada(arvore: SceneTree, pasta: String, nome: String, segundos: float,
		onde: Vector3 = Vector3.INF, olhar: Vector3 = Vector3.ZERO,
		sonda: Callable = Callable()) -> void:
	_calar_pausa(arvore)
	var dir := pasta.path_join(nome)
	DirAccess.make_dir_recursive_absolute(dir)
	var antiga := arvore.root.get_viewport().get_camera_3d()
	var livre: Camera3D = null
	if onde.is_finite():
		livre = Camera3D.new()
		livre.name = "CameraDaRajada"
		if antiga != null:
			livre.fov = antiga.fov
			livre.attributes = antiga.attributes
			livre.environment = antiga.environment
			livre.near = 0.05
		arvore.current_scene.add_child(livre)
		livre.global_position = onde
		livre.look_at(olhar)
		livre.current = true
	var ticks := [0]
	var contar := func() -> void: ticks[0] += 1
	arvore.physics_frame.connect(contar)
	Engine.time_scale = 0.15
	var t := 0.0
	while t < segundos:
		await RenderingServer.frame_post_draw
		t = float(ticks[0]) * 0.15 / float(Engine.physics_ticks_per_second)
		var img := arvore.root.get_viewport().get_texture().get_image()
		img.save_png(dir.path_join("r_%.3f.png" % t))
		if sonda.is_valid():
			_relatar("sonda", "%.3f %s" % [t, sonda.call()])
		await arvore.physics_frame
	Engine.time_scale = 1.0
	arvore.physics_frame.disconnect(contar)
	if livre != null:
		livre.queue_free()
		if antiga != null:
			antiga.current = true
	_relatar("rajada", "%s %.2f s" % [dir, t])


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
