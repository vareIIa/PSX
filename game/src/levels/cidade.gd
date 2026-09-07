## Cidade com streaming. A cena que se joga a partir da Fase 3.
##
## Nao tem geometria propria: tudo vem do ChunkManager, que monta os chunks em
## volta do jogador conforme ele anda. O mapa e infinito e deterministico, porque
## o conteudo de cada chunk sai da coordenada.
extends Node3D

@onready var _chunks: Node3D = $Chunks
@onready var _player: Node3D = $Player
@onready var _hud: Label = $Debug/Info
@onready var _prompt: Label = $Debug/Prompt

var _menu: Menu
var _prompt_y: float = 0.0
var _dano: ColorRect
var _vida_anterior: int = 100

var _mostrar_debug: bool = false
var _acc: float = 0.0


func _ready() -> void:
	ChunkManager.iniciar(_chunks, _player)
	# A multidao segue o jogador como o streaming segue: mesma raiz, mesmo alvo.
	# Ela nasce depois do ChunkManager de proposito — pedestre so nasce em chunk
	# ja montado, senao nao ha calcada embaixo dele.
	#
	# Fora em --auto-walk: essa e a verificacao do CONTROLADOR, que mede deriva
	# lateral em centimetros com o jogador andando reto. Gente na calcada e outro
	# assunto e vira ruido na medida. Em --auto-run, que e a do streaming, a
	# multidao fica: ali ela e carga de verdade e tem de ser medida junto.
	if not OS.get_cmdline_user_args().has("--auto-walk"):
		Multidao.iniciar(_chunks, _player)
		# O transito segue a mesma raiz e o mesmo alvo. Depois da multidao
		# porque o carro consulta pedestre para nao atropelar ninguem parado no
		# lugar onde ele ia nascer.
		Transito.iniciar(_chunks, _player)
		# Blitz depois do transito: consulta a mesma malha de vias e nao compete
		# com o nascimento de carro no mesmo quadro.
		BlitzManager.iniciar(_chunks, _player)
	add_child(PranchaInventario.new())
	add_child(Minimapa.new())
	_montar_menu()

	_novo_jogo()

	AudioDirector.ambiente(&"chuva_loop", -14.0)
	AudioDirector.ambiente(&"vento_loop", -20.0)
	AudioDirector.ambiente(&"zumbido_loop", -26.0)

	if OS.get_cmdline_user_args().has("--teste-horror"):
		TesteHorror.executar(self, _player)
		return

	if OS.get_cmdline_user_args().has("--teste-casa"):
		TesteCasa.executar(self, _player)
		return

	if OS.get_cmdline_user_args().has("--teste-mercado"):
		TesteMercado.executar(self, _player)
		return

	if OS.get_cmdline_user_args().has("--teste-cidade"):
		TesteCidade.executar(self, _player)
		return

	if OS.get_cmdline_user_args().has("--teste-npc"):
		TesteNpc.executar(self, _player)
		return

	# Caminho de teste da prancha, para a captura automatizada.
	if OS.get_cmdline_user_args().has("--abrir-inventario"):
		Inventario.adicionar(&"pistola")
		Inventario.adicionar(&"municao_9mm", 12)
		Inventario.adicionar(&"chave_apartamento")
		await get_tree().create_timer(1.2).timeout
		for p: Node in get_children():
			if p is PranchaInventario:
				(p as PranchaInventario).abrir()
	_hud.visible = false
	_prompt.text = ""
	_prompt_y = _prompt.position.y
	_montar_dano()
	_player.alvo_de_interacao.connect(_mostrar_prompt)
	Interiores.entrou.connect(func() -> void: _mostrar_prompt(""))

	# Caminho de teste: entra num interior sem precisar achar uma porta. Serve a
	# captura automatizada, que nao tem como navegar ate uma.
	if OS.get_cmdline_user_args().has("--entrar-mercado"):
		await get_tree().create_timer(1.5).timeout
		Interiores.entrar(77451, _player.global_transform, &"mercado")
	elif OS.get_cmdline_user_args().has("--entrar-casa"):
		await get_tree().create_timer(1.5).timeout
		Interiores.entrar(77123, _player.global_transform, &"casa")
		# Enquadra o morador e abre a conversa, para a captura conseguir
		# fotografar as duas coisas sem simular caminhada nem tecla.
		if OS.get_cmdline_user_args().has("--olhar-morador"):
			await get_tree().create_timer(2.5).timeout
			_enquadrar_morador()
	elif OS.get_cmdline_user_args().has("--entrar-fumaca"):
		await get_tree().create_timer(1.5).timeout
		Interiores.entrar(77551, _player.global_transform, &"casa_fumaca")
		# Enquadra a TV e quem esta jogando. Sem isto a captura sai da porta, a
		# cinco metros, e nao da para julgar nem a imagem nem as posturas.
		if OS.get_cmdline_user_args().has("--olhar-tv"):
			await get_tree().create_timer(2.0).timeout
			_enquadrar_tv()
		elif OS.get_cmdline_user_args().has("--olhar-jogadores"):
			await get_tree().create_timer(2.0).timeout
			_enquadrar_papel(Convidado.Papel.SENTADO, Vector3(-1.6, -0.62, -1.1))
		elif OS.get_cmdline_user_args().has("--olhar-fumante"):
			await get_tree().create_timer(2.0).timeout
			_enquadrar_fumante()
	elif OS.get_cmdline_user_args().has("--entrar-interior"):
		await get_tree().create_timer(1.5).timeout
		Interiores.entrar(77123, _player.global_transform)
		# Ida e volta na mesma execucao, para a verificacao cobrir os dois lados
		# da transicao. So entrar provaria metade.
		if OS.get_cmdline_user_args().has("--sair-interior"):
			await get_tree().create_timer(4.0).timeout
			Interiores.sair()
	# Salto para uma coordenada do mundo. Serve a captura, que precisa fotografar
	# um ponto especifico da cidade infinita sem caminhar ate la.
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--ir-para="):
			continue
		var partes := arg.trim_prefix("--ir-para=").split(",")
		if partes.size() < 2:
			continue
		_player.global_position = Vector3(float(partes[0]), 1.0, float(partes[1]))
		if partes.size() >= 4:
			_player.call("olhar_para", Vector3(float(partes[2]), 1.5, float(partes[3])))

	# Vista de cima, so para inspecao. Uma cidade gerada nao da para julgar de
	# dentro dela: a nevoa esconde 45 m e a duvida "a rua transversal saiu no
	# lugar?" nao se responde de olho no chao. Isto poe uma camera propria no
	# alto, olhando para baixo, e fotografa a planta do que o gerador produziu.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--de-cima="):
			var p := arg.trim_prefix("--de-cima=").split(",")
			if p.size() >= 3:
				_camera_de_cima(Vector3(float(p[0]), float(p[2]), float(p[1])),
					deg_to_rad(float(p[3]) if p.size() >= 4 else 90.0),
					deg_to_rad(float(p[4]) if p.size() >= 5 else -45.0))

	# Mapa do pause aberto direto, para a captura. Vem depois do --ir-para: o mapa
	# se centra no jogador na hora de abrir, e abrir antes fotografaria a origem.
	if OS.get_cmdline_user_args().has("--ver-mapa"):
		if OS.get_cmdline_user_args().has("--revelar-mapa"):
			_menu.revelar_mapa()
		_menu.mostrar(Menu.Painel.MAPA)
		if OS.get_cmdline_user_args().has("--revelar-mapa"):
			_menu.revelar_mapa()

	# Desfile de gente, so para captura. Uma cidade povoada nao da para julgar de
	# dentro dela: os pedestres andam, a nevoa esconde metade e nunca ha dois lado
	# a lado para comparar. Isto enfileira N pessoas sorteadas na frente da
	# camera, paradas, e e a unica forma de olhar a variacao do gerador de uma vez.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--desfile="):
			var d := arg.trim_prefix("--desfile=").split(",")
			_desfile(int(d[0]), float(d[1]) if d.size() > 1 else 4.0)

	if OS.get_cmdline_user_args().has("--ver-celular"):
		await get_tree().create_timer(0.8).timeout
		Celular.abrir()
		# Com --ver-ficha a captura ja cai na consulta respondida, que e a tela
		# que importa: a de inicio mostra icones, esta mostra o registro civil
		# funcionando.
		if OS.get_cmdline_user_args().has("--ver-ficha"):
			Celular.consultar_cpf(String(RegistroCivil.jogador.get("cpf", "")))

	# Conversa com alguem da rua, para a captura. Esperar a multidao encontrar o
	# jogador sozinha levaria minutos e sairia diferente a cada execucao; aqui a
	# primeira pessoa viva e trazida para a frente da camera e abordada.
	if OS.get_cmdline_user_args().has("--ver-conversa"):
		await get_tree().create_timer(4.0).timeout
		_abordar_alguem()

	if OS.get_cmdline_user_args().has("--ver-documento"):
		await get_tree().create_timer(0.8).timeout
		Documento.abrir(RegistroCivil.jogador)

	# A captura automatizada precisa do overlay para medir sem depender de tecla.
	if OS.get_cmdline_user_args().has("--debug-info"):
		_mostrar_debug = true
		_hud.visible = true


## Camera de inspecao, apontada para baixo. So captura, nunca no jogo.
##
## O jogador vai junto, e sem colisao: o streaming segue o jogador, entao deixa-lo
## para tras carregaria os chunks do lugar errado e a foto sairia de um vazio.
## Voar sem colisao e o que evita ele cair dentro do predio embaixo da camera.
func _camera_de_cima(onde: Vector3, inclinacao: float, giro: float) -> void:
	_player.global_position = Vector3(onde.x, 1.0, onde.z)
	if _player is CharacterBody3D:
		(_player as CharacterBody3D).set_collision_mask_value(1, false)
	# Sem o corte por distancia nada apareceria: la de cima toda malha esta alem
	# do alcance de desenho, que no jogo e obrigatorio.
	ChunkManager.alcance_infinito = true
	ChunkManager.raio_extra = 3
	ChunkManager.recarregar_preset()

	# Luz zenital propria. A cidade e noturna e iluminada por poste; de cima, sem
	# isto, a planta sai preta.
	var sol := DirectionalLight3D.new()
	sol.light_energy = 1.25
	sol.rotation = Vector3(-inclinacao * 0.8, giro, 0.0)
	add_child(sol)

	var cam := Camera3D.new()
	# Ortogonal para a planta poder ser medida: em perspectiva a rua longe fica
	# mais estreita e nao da para comparar largura de avenida com largura de rua.
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = onde.y
	cam.near = 1.0
	cam.far = 4000.0
	add_child(cam)
	var direcao := Vector3(cos(inclinacao) * sin(giro), sin(inclinacao),
		cos(inclinacao) * cos(giro))
	cam.global_position = Vector3(onde.x, 0.0, onde.z) + direcao * 400.0
	cam.look_at(Vector3(onde.x, 0.0, onde.z), Vector3.UP)
	cam.current = true


## Poe a camera onde se ve a TV, quem esta jogando e o console no chao ao mesmo
## tempo. So captura.
func _enquadrar_tv() -> void:
	var tv := get_tree().get_first_node_in_group(&"televisao") as Node3D
	if tv == null:
		return
	# O deslocamento em Y e da ORIGEM do jogador, e o olho dele fica 1,62 m acima
	# dela. Somar a altura do olho aqui poe a camera encostada no teto de 2,45 e
	# a captura sai fotografando a laje.
	_player.global_position = tv.global_position + Vector3(-1.55, -0.45, -3.1)
	_player.call("olhar_para", tv.global_position + Vector3(0.2, 0.0, 0.0))


## Enquadra de lado quem esta com um papel fixo. So captura.
##
## De lado, e nao de frente: as posturas de sentado e de segurar controle se
## leem no PERFIL — o joelho dobrado, o antebraco a frente da cintura. De frente
## as duas viram um tronco com uma cabeca em cima.
func _enquadrar_papel(papel: int, desloca: Vector3) -> void:
	for no: Node in get_tree().get_nodes_in_group(&"convidado"):
		var c := no as Convidado
		if c == null or c.papel != papel:
			continue
		c.congelar_para_captura()
		# Deslocamento na base da pessoa, pela mesma razao de _enquadrar_fumante:
		# "de lado" so quer dizer alguma coisa em relacao a quem esta posando.
		_player.global_position = c.global_position + c.global_transform.basis * desloca
		_player.call("olhar_para", c.global_position + Vector3(0.0, 0.62, 0.0))
		return


func _enquadrar_fumante() -> void:
	for no: Node in get_tree().get_nodes_in_group(&"convidado"):
		var c := no as Convidado
		if c == null or not c.fumando:
			continue
		# Perto e na altura do peito: e o unico jeito de julgar o que a pessoa
		# tem na mao, que e o que esta captura existe para julgar.
		c.congelar_para_captura()
		# A camera vai pela BASE do convidado, e nao por um deslocamento em
		# coordenada de mundo. O baseado esta na mao direita, e "direita" depende
		# de para onde a pessoa esta virada: com deslocamento fixo em X, a
		# camera caiu do lado errado do corpo e o objeto ficou escondido atras do
		# tronco em todas as capturas — o que se via era o proprio peito na
		# sombra, e eu passei tres rodadas ajustando o material dele.
		var frente := c.global_transform.basis
		_player.global_position = c.global_position + frente * Vector3(0.42, -0.12, -0.92)
		_player.call("olhar_para", c.global_position + Vector3(0.0, 1.52, 0.0))
		return


## Enfileira pessoas paradas na frente do jogador. So captura.
##
## Vem com luz propria de proposito. A cidade e noturna e iluminada a sodio, e
## sob sodio toda pele fica laranja e todo tecido fica marrom — o que e certo
## para o jogo e inutil para julgar o gerador. Aqui a luz e branca e frontal,
## como a de um estudio, porque a pergunta que esta captura responde e "as
## pessoas saem diferentes umas das outras?" e nao "como e a rua a noite".
func _desfile(quantos: int, distancia: float = 4.0) -> void:
	Multidao.parar()
	Transito.parar()
	BlitzManager.parar()
	var frente := -_player.global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var lado := Vector3(-frente.z, 0.0, frente.x)
	var base := _player.global_position + frente * distancia
	var largura := 0.95
	var giro_base := atan2(frente.x, frente.z)

	for i in quantos:
		var id := RegistroCivil.id_de_transeunte(7000 + i * 131)
		var corpo := Corpo.new()
		add_child(corpo)
		corpo.montar(RegistroCivil.identidade(id)["aparencia"])
		corpo.global_position = (base
			+ lado * (float(i) - float(quantos - 1) * 0.5) * largura)
		# Meio virados, para o desfile mostrar rosto e silhueta ao mesmo tempo.
		corpo.rotation.y = giro_base + deg_to_rad(float(i % 3 - 1) * 22.0)
		corpo.animar(0.0, 0.016)

	# Energia baixa e alcance longo. A primeira versao usava 3,2 a um metro e
	# meio: as faces de cima saturavam e cabelo preto saia bege na foto, o que
	# levou a dez minutos procurando defeito de tint que nao existia.
	var luz := OmniLight3D.new()
	luz.light_color = Color("fff4e6")
	luz.light_energy = 1.5
	luz.omni_range = 26.0
	luz.omni_attenuation = 0.6
	luz.shadow_enabled = false
	add_child(luz)
	luz.global_position = base + frente * -3.0 + Vector3(1.5, 3.0, 0.0)


## Traz um pedestre para a frente do jogador e abre a conversa. So captura.
func _abordar_alguem() -> void:
	var vivos := Multidao.lista()
	if vivos.is_empty():
		return
	var quem := vivos[0]
	var frente := -_player.global_transform.basis.z
	frente.y = 0.0
	quem.global_position = _player.global_position + frente.normalized() * 2.2
	# Olhar para a pessoa faz parte: a caixa de fala cobre o terco de baixo da
	# tela, e sem enquadrar o rosto a captura vira uma foto de calcada com
	# legenda.
	_player.call("olhar_para", quem.global_position + Vector3(0.0, 1.5, 0.0))
	await get_tree().create_timer(0.4).timeout
	quem.abordar(_player)
	# Avanca a saudacao ate a lista de assuntos, que e a tela que interessa
	# fotografar: e nela que se ve que ha escolha e que a ultima e o documento.
	if OS.get_cmdline_user_args().has("--ver-assuntos"):
		await get_tree().create_timer(2.2).timeout
		for k in 6:
			Conversa.avancar()
			await get_tree().process_frame


## Poe o jogador de frente para o morador e comeca a conversa. So captura.
func _enquadrar_morador() -> void:
	var npc := get_tree().get_first_node_in_group(&"npc") as Node3D
	if npc == null:
		return
	# Do lado da sala, nao a frente dele: ele comeca virado para a janela, e
	# "a frente" seria do lado de fora da parede oeste. O jogador aparece onde
	# quem entrou estaria, e e o morador que se vira.
	_player.global_position = npc.global_position + Vector3(2.6, 0.15, -3.0)
	_player.call("olhar_para", npc.global_position + Vector3(0.0, 1.4, 0.0))
	await get_tree().create_timer(1.2).timeout
	if npc.has_method("interagir"):
		npc.call("interagir", _player)


## Clarao vermelho ao levar dano. Nao ha barra de vida na tela: a referencia usa
## o estado escrito na prancha, e o unico aviso imediato e este.
func _montar_dano() -> void:
	_dano = ColorRect.new()
	_dano.color = Color(0.62, 0.09, 0.06, 0.0)
	_dano.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Debug.add_child(_dano)
	# So o preset de ancora: definir tamanho junto faz o motor avisar que o
	# retangulo vai ser sobrescrito depois do _ready.
	_dano.set_anchors_preset(Control.PRESET_FULL_RECT)
	Inventario.vida_mudou.connect(_ao_mudar_vida)


func _ao_mudar_vida(atual: int, _maximo: int) -> void:
	if atual >= _vida_anterior:
		_vida_anterior = atual
		return
	_vida_anterior = atual
	_dano.color.a = 0.42
	create_tween().set_ease(Tween.EASE_OUT) 		.tween_property(_dano, "color:a", 0.0, 0.45)
	AudioDirector.tocar_ui(&"ofegante", -8.0)


## Menu de titulo. Abre no comeco e volta com ESC, e enquanto ele esta na tela a
## arvore fica pausada, entao a cidade nao anda sozinha.
func _montar_menu() -> void:
	_menu = Menu.new()
	_menu.jogar.connect(_novo_jogo)
	_menu.continuar.connect(func() -> void: _mostrar_prompt(""))
	add_child(_menu)

	# Nos caminhos de teste o menu atrapalha: eles precisam do jogo rodando.
	# --ver-menu existe para a captura conseguir fotografar o menu mesmo assim.
	if OS.get_cmdline_user_args().has("--ver-menu"):
		return
	if OS.get_cmdline_user_args().has("--ver-opcoes"):
		_menu.mostrar(Menu.Painel.OPCOES)
		return
	if OS.get_cmdline_user_args().has("--ver-nome"):
		_menu.mostrar(Menu.Painel.NOME)
		return
	if OS.get_cmdline_user_args().has("--ver-aparencia"):
		_menu.mostrar(Menu.Painel.APARENCIA)
		return
	for arg: String in OS.get_cmdline_user_args():
		if (arg in ["--teste-horror", "--teste-casa", "--teste-mercado",
					"--teste-cidade", "--teste-npc", "--ver-mapa",
					"--ver-celular", "--ver-ficha", "--ver-documento",
					"--ver-conversa", "--abrir-inventario",
					"--entrar-interior", "--entrar-casa", "--entrar-mercado",
					"--entrar-fumaca"]
				or arg.begins_with("--shot=")
				or arg in ["--auto-run", "--auto-walk"]
				or arg.begins_with("--stats=")
				or arg.begins_with("--desfile=")):
			_menu.esconder()
			return


func _novo_jogo(nome: String = "") -> void:
	WorldState.limpar()
	# A ficha so e emitida aqui quando ainda nao existe nenhuma — no primeiro
	# quadro da cena, ou num caminho de teste que pula o menu.
	#
	# Pelo menu ela ja nasceu na assinatura do nome, ANTES da tela de aparencia,
	# e o jogador passou os ultimos minutos escolhendo rosto, roupa e altura em
	# cima dela. Emitir outra aqui jogaria tudo isso fora e ele comecaria a
	# partida como outra pessoa, sem nenhum aviso.
	if RegistroCivil.jogador.is_empty():
		RegistroCivil.criar_jogador(nome)
	Multidao.limpar()
	Transito.limpar()
	BlitzManager.limpar()
	Inventario.de_dicionario({"espacos": [], "vida": 100})
	# Todo mundo comeca com a carteira no bolso, e ela nunca sai: e o unico item
	# do jogo que nao e recurso, e sim quem voce e.
	Inventario.adicionar(&"identidade")
	Inventario.adicionar(&"lanterna")
	Inventario.adicionar(&"radio")
	Inventario.adicionar(&"bandagem", 2)
	Inventario.adicionar(&"bateria", 1)


## Prompt de acao. Fica vazio quando nao ha alvo: texto permanente na tela vira
## ruido e o jogador para de ler.
func _mostrar_prompt(rotulo: String) -> void:
	_prompt.text = ("[E]  " + rotulo) if rotulo != "" else ""
	if rotulo == "":
		_prompt.modulate.a = 0.0
		return
	# Entra subindo dois pixels. Aparecer instantaneamente na tela puxa o olho
	# com forca demais para o que e so um aviso de que da para apertar E.
	_prompt.modulate.a = 0.0
	_prompt.position.y = _prompt_y + 2.0
	var t := create_tween().set_parallel(true)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(_prompt, "modulate:a", 1.0, 0.12)
	t.tween_property(_prompt, "position:y", _prompt_y, 0.12)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("pausa") and _menu != null and not _menu.visible:
		_menu.mostrar(Menu.Painel.TITULO)
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("debug_info"):
		_mostrar_debug = not _mostrar_debug
		_hud.visible = _mostrar_debug


func _process(delta: float) -> void:
	if not _mostrar_debug:
		return
	_acc += delta
	if _acc < 0.25:
		return
	_acc = 0.0
	_hud.text = _texto()


func _texto() -> String:
	var pos := _player.global_position
	var coord := ChunkManager.coord_de(pos)
	return "\n".join([
		"fps %d" % Engine.get_frames_per_second(),
		"chunk %d,%d" % [coord.x, coord.y],
		"pos %.0f %.0f" % [pos.x, pos.z],
		"carregados %d" % ChunkManager.chunks_carregados(),
		"tris %d" % ChunkManager.tris_carregados,
		"draw %d" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"prim %d" % Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"mem %.1f MB" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0),
		"nevoa %s" % Settings.fog_preset_id,
	])


func _exit_tree() -> void:
	ChunkManager.parar()
	BlitzManager.parar()
