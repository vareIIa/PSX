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
var _prancha: PranchaInventario
var _prompt_y: float = 0.0
var _dano: ColorRect
var _vida_anterior: int = 100

var _mostrar_debug: bool = false
var _acc: float = 0.0
var _minimapa: Minimapa
var _titulo_ativo: bool = false
var _titulo_t: float = 0.0
var _titulo_yaw0: float = 0.0
var _boot_casa_pronta: bool = false
var _transicao_crt: bool = false
## Camera propria da cinematic CRT — nao e a gameplay cam do player.
var _cam_crt: Camera3D
var _cam_crt_yaw0: float = 0.0
var _convidados_ocultos: Array[Node] = []
## A coordenada em que a cena poe o jogador, guardada no _ready.
var _ponto_inicial := Vector3.ZERO


func _ready() -> void:
	# Onde o jogador nasce, lido no primeiro quadro e guardado.
	#
	# Nao da para perguntar isso mais tarde. A tela de titulo enquadra a sala da
	# casa da fumaca, e para isso `Interiores.entrar` teleporta quem esta no
	# grupo `player` para dois mil metros de altura — e a bicicleta do respawn,
	# que nasce em paralelo esperando o chao aparecer, iria atras dele e nasceria
	# dentro do comodo. Guardar a coordenada antes de qualquer um mexer no
	# jogador e o que separa as duas coisas.
	_ponto_inicial = _player.global_position
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
	_prancha = PranchaInventario.new()
	add_child(_prancha)
	_minimapa = Minimapa.new()
	add_child(_minimapa)
	add_child(HudMissao.new())
	_montar_menu()

	# Com titulo aberto a ficha nasce no fluxo NOVO JOGO / CONTINUAR.
	# Testes e captura que pulam o menu ainda precisam do setup imediato.
	if not _menu.visible:
		_novo_jogo()
	_por_bicicleta_no_respawn()
	# Caminho de captura: a abertura sem passar pelo menu. Nao da para fotografar
	# uma cena cortada que so existe depois de tres telas de criacao de ficha.
	if OS.get_cmdline_user_args().has("--ver-abertura"):
		_rodar_abertura()
	if OS.get_cmdline_user_args().has("--ver-estrada"):
		_rodar_estrada()

	# A chuva NAO entra aqui. Quem liga e ajusta o loop dela e o proprio no da
	# Chuva, que e quem sabe se o preset em vigor tem chuva — com o volume fixo
	# desta linha, chovia no ouvido em dia de sol.
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
		# A semente escolhe a casa. Com uma so, a captura nunca mostrava mais que
		# um dos quatro perfis, e a variacao da planta nao tinha como ser vista.
		var semente_casa := 77123
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--semente-casa="):
				semente_casa = int(arg.trim_prefix("--semente-casa="))
		Interiores.entrar(semente_casa, _player.global_transform, &"casa")
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
	elif OS.get_cmdline_user_args().has("--entrar-estufa"):
		# Entra na casa e atravessa a porta dos fundos, que e o unico caminho
		# para a estufa. Chamar a estufa direto tambem funcionaria e provaria
		# menos: o que precisa ser fotografado e a travessia inteira, porque e
		# ela que a pilha de comodos do Interiores implementa.
		await get_tree().create_timer(1.5).timeout
		Interiores.entrar(77551, _player.global_transform, &"casa_fumaca")
		await get_tree().create_timer(2.5).timeout
		var meio := (CasaFumacaBuilder.VAO_FUNDOS.x
			+ CasaFumacaBuilder.VAO_FUNDOS.y) * 0.5
		Interiores.atravessar(77551 + 4242, &"estufa",
			Vector3(CasaFumacaBuilder.LARGURA - 1.25, 0.0, meio),
			Vector3(CasaFumacaBuilder.LARGURA - 4.5, 1.5, meio - 0.9))
		# Volta pela mesma porta. A ida sozinha provaria metade: o que a pilha
		# de comodos implementa e o RETORNO — sair da estufa tem de reconstruir a
		# sala e por o jogador do lado de dentro da porta, e nao na calcada.
		if OS.get_cmdline_user_args().has("--sair-estufa"):
			await get_tree().create_timer(3.0).timeout
			Interiores.sair()
		elif OS.get_cmdline_user_args().has("--olhar-canteiro"):
			await get_tree().create_timer(2.5).timeout
			_enquadrar_canteiro()
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

	# Captura da blitz: semeia, espera nascer, teleporta a camera para o funil.
	var _quer_blitz := false
	for _a: String in OS.get_cmdline_user_args():
		if _a == "--olhar-blitz" or _a.begins_with("--olhar-blitz="):
			_quer_blitz = true
			break
	if _quer_blitz:
		await _olhar_blitz()

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

## Semeia uma blitz e teleporta o jogador para enquadra-la (capturas AAA).
##
## Args opcionais:
##   --olhar-blitz=perto|funil|cima|desvio|insp|conversa  (padrao: perto)
##   --blitz-demo  forca cena estatica da fase (insp=NA_JANELA, conversa=CONVERSA)
func _olhar_blitz() -> void:
	BlitzManager.semear()
	var t0 := float(Time.get_ticks_msec()) / 1000.0
	var qual: Blitz = null
	while qual == null:
		var vivas := BlitzManager.lista()
		if not vivas.is_empty():
			qual = vivas[0]
			break
		if float(Time.get_ticks_msec()) / 1000.0 - t0 > 6.0:
			push_warning("[cidade] --olhar-blitz: nenhuma blitz nasceu")
			return
		await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	var modo := "perto"
	var demo := OS.get_cmdline_user_args().has("--blitz-demo")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--olhar-blitz=") and arg.length() > 13:
			modo = arg.trim_prefix("--olhar-blitz=")
		if arg == "--blitz-demo" or arg.begins_with("--blitz-demo="):
			demo = true
	# Demo estatica alinhada a fase pedida (nao depende do carro vivo).
	if demo:
		match modo:
			"insp":
				qual.preparar_captura(Blitz.Fase.NA_JANELA)
			"conversa":
				qual.preparar_captura(Blitz.Fase.CONVERSA)
			"desvio":
				qual.preparar_captura(Blitz.Fase.OCIOSA)
			_:
				qual.preparar_captura(Blitz.Fase.OCIOSA)
		await get_tree().process_frame
		await get_tree().process_frame
	var alvo := qual.ponto_de_parada()
	var b := qual.global_transform.basis
	var cam := alvo
	var olhar := alvo + Vector3.UP * 1.0
	match modo:
		"funil":
			cam = alvo + b * Vector3(1.5, 2.4, 12.0)
			olhar = alvo + b * Vector3(0.0, 0.6, -2.0)
		"cima":
			# Centro perto da viatura/acostamento (nao so o ponto de parada).
			var centro_planta := alvo + b * Vector3(qual._x_acost * 0.5, 0.0, -2.0)
			_camera_de_cima(Vector3(centro_planta.x, 36.0, centro_planta.z),
				deg_to_rad(88.0), deg_to_rad(0.0))
			# Espera chunks + luz entrarem no viewport antes do --shot-frame.
			await get_tree().create_timer(1.5).timeout
			# Re-pina o jogador (streaming segue ele).
			_player.global_position = Vector3(centro_planta.x, 1.0, centro_planta.z)
			print("[cidade] blitz modo=cima em %.1f,%.1f,%.1f" % [centro_planta.x, centro_planta.y, centro_planta.z])
			return
		"desvio":
			cam = alvo + b * Vector3(-5.0, 3.0, 6.0)
			olhar = alvo + b * Vector3(-2.0, 0.5, 0.0)
		"insp":
			# Recuo: carro no funil + oficial na janela no mesmo quadro.
			cam = alvo + b * Vector3(5.2, 2.5, 4.5)
			olhar = alvo + b * Vector3(0.6, 1.05, 0.15)
		"conversa":
			# Do asfalto olhando o acostamento: motorista a pe + oficial.
			var acost := alvo + b * Vector3(qual._x_acost - 0.4, 0.0, 4.2)
			cam = acost + b * Vector3(-4.5, 2.3, 3.0)
			olhar = acost + Vector3.UP * 1.15
		_:
			# Perto: enquadra a malha Viatura (acostamento + zebra).
			var viat_no := qual.get_node_or_null("Viatura") as Node3D
			var viat := (viat_no.global_position if viat_no != null
				else alvo + b * Vector3(qual._x_acost, 0.0, -3.6))
			cam = viat + b * Vector3(3.6, 2.5, 4.8)
			olhar = viat + Vector3.UP * 0.5
	_player.global_position = Vector3(cam.x, maxf(cam.y, 1.2), cam.z)
	if _player.has_method("olhar_para"):
		_player.call("olhar_para", olhar)
	print("[cidade] blitz modo=%s demo=%s em %.1f,%.1f,%.1f cam=%.1f,%.1f,%.1f"
		% [modo, str(demo), alvo.x, alvo.y, alvo.z, cam.x, cam.y, cam.z])


func _camera_de_cima(onde: Vector3, inclinacao: float, giro: float) -> void:
	# Trava o jogador no chao: sem colisao ele caia no void e o streaming
	# descarregava a blitz (A2 saia vazia / preta).
	_player.global_position = Vector3(onde.x, 1.0, onde.z)
	if _player is CharacterBody3D:
		var corpo := _player as CharacterBody3D
		corpo.set_collision_mask_value(1, false)
		corpo.velocity = Vector3.ZERO
		corpo.set_physics_process(false)
		corpo.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	# Sem o corte por distancia nada apareceria: la de cima toda malha esta alem
	# do alcance de desenho, que no jogo e obrigatorio.
	ChunkManager.alcance_infinito = true
	ChunkManager.raio_extra = 3
	ChunkManager.recarregar_preset()

	# Planta de captura: nevoa noturna come a cena ortogonal — forca dia claro.
	var fog := get_node_or_null("Ambiente") as FogController
	if fog != null:
		fog.forcar("res://resources/fog/fog_dia_sol.tres")

	# Luz zenital propria. A cidade e noturna e iluminada por poste; de cima, sem
	# isto, a planta sai preta.
	var sol := DirectionalLight3D.new()
	sol.light_energy = 2.6
	sol.light_color = Color(1.0, 0.98, 0.92)
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
	# De cima em pe, UP e paralelo ao olhar e look_at recusa (A2 saia preta).
	var acima := absf(sin(inclinacao)) > 0.999
	cam.look_at(Vector3(onde.x, 0.0, onde.z),
		Vector3.FORWARD if acima else Vector3.UP)
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


## Enquadra uma planta de perto, dentro do canteiro. So captura.
##
## Perto o bastante para julgar a silhueta da folha, que e a unica coisa que
## precisa estar certa naquela celula, e baixo o bastante para a luminaria e o
## facho dela entrarem no quadro por cima.
func _enquadrar_canteiro() -> void:
	var alvo := Interiores.DESLOCAMENTO + Vector3(
		EstufaBuilder.CANTEIROS[1], 1.05, EstufaBuilder.LINHAS[1])
	_player.global_position = alvo + Vector3(1.05, -0.75, -1.15)
	_player.call("olhar_para", alvo)


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
	# Perto o bastante para o rosto aparecer. A quatro metros o morador sai como
	# silhueta, que e a leitura certa para a ENTRADA da casa e a errada para a
	# captura que existe justamente para julgar a cara dele.
	_player.global_position = npc.global_position + Vector3(1.45, 0.15, -1.65)
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


## Abertura CRT + menu de jogo. ESC no jogo continua sendo a prancha.
func _montar_menu() -> void:
	_menu = Menu.new()
	_menu.jogar.connect(_ao_comecar_pelo_menu)
	_menu.continuar.connect(_ao_continuar_pelo_menu)
	_menu.boot_iniciar.connect(_ao_boot_iniciar)
	add_child(_menu)

	var args := OS.get_cmdline_user_args()
	if args.has("--ver-boot"):
		_abrir_boot()
		return
	if args.has("--ver-menu"):
		_abrir_menu_jogo()
		return
	if args.has("--ver-tv-reveal") or args.has("--ver-tv-close"):
		_abrir_boot()
		# Dispara a transicao sozinha para captura do tubo de perto.
		await get_tree().create_timer(0.8).timeout
		_ao_boot_iniciar()
		return
	if args.has("--ver-opcoes"):
		_menu.mostrar(Menu.Painel.OPCOES)
		return
	if args.has("--ver-nome"):
		_menu.mostrar(Menu.Painel.NOME)
		return
	if args.has("--ver-aparencia"):
		_menu.mostrar(Menu.Painel.APARENCIA)
		return
	if _deve_abrir_titulo(args):
		_abrir_boot()
		return
	_menu.esconder()


## Abre so quando nao ha flag de teste/captura pedindo gameplay direto.
func _deve_abrir_titulo(args: PackedStringArray) -> bool:
	for a: String in args:
		if a in ["--ver-mapa", "--abrir-inventario", "--ver-celular", "--ver-ficha"]:
			return false
		if a.begins_with("--teste-") or a.begins_with("--entrar-"):
			return false
		if a.begins_with("--auto-") or a.begins_with("--shot") or a.begins_with("--ir-para="):
			return false
		if a.begins_with("--de-cima=") or a.begins_with("--desfile="):
			return false
		if a in ["--pular-menu", "--ver-abertura", "--olhar-blitz", "--blitz-demo"] or a.begins_with("--olhar-blitz=") or a.begins_with("--blitz-demo="):
			return false
	return true


func _abrir_boot() -> void:
	_titulo_ativo = false
	_player.travar(true)
	if _minimapa != null:
		_minimapa.visible = false
	_forcar_post_crt()
	_menu.mostrar(Menu.Painel.BOOT)
	# Pre-carrega a Casa da Fumaca atras do CRT opaco.
	_preload_casa_boot()


func _abrir_menu_jogo() -> void:
	_preparar_vista_titulo()
	_menu.fim_transicao_ui()
	_menu.mostrar(Menu.Painel.TITULO)
	_titulo_ativo = true
	if _minimapa != null:
		_minimapa.visible = false


## Enquadra a rua na nevoa e trava o jogador sem pausar a cidade.
func _preparar_vista_titulo() -> void:
	_player.travar(true)
	_player.set_physics_process(false)
	if _player.has_method("liberar_fov"):
		_player.call("liberar_fov")
	var origem := _player.global_position
	_player.global_position = origem + Vector3(0.0, 15.0, 0.0)
	_player.olhar_para(_player.global_position + Vector3(20.0, -15.0, 0.0))
	var pivo := _player.get_node_or_null("Pivo") as Node3D
	if pivo != null:
		pivo.rotation.x = deg_to_rad(-25.0)
	_titulo_yaw0 = _player.rotation.y
	_titulo_t = 0.0
	var fog := get_node_or_null("Ambiente") as FogController
	if fog != null:
		fog.forcar("res://resources/fog/fog_denso.tres")



func _forcar_post_crt() -> void:
	Settings.set_post(&"grain", 0.14)
	Settings.set_post(&"scanline", 0.28)
	Settings.set_post(&"vignette", 0.7)
	Settings.set_post(&"chromatic", 0.9)


func _preload_casa_boot() -> void:
	_boot_casa_pronta = false
	if Interiores.dentro:
		_boot_casa_pronta = true
		_preparar_cena_crt_tv()
		return
	Interiores.entrar(77551, _player.global_transform, &"casa_fumaca", true)
	if not Interiores.entrou.is_connected(_ao_casa_boot_pronta):
		Interiores.entrou.connect(_ao_casa_boot_pronta, CONNECT_ONE_SHOT)


func _ao_casa_boot_pronta() -> void:
	_boot_casa_pronta = true
	_preparar_cena_crt_tv()


## Esconde convidados, forca neve na TV e monta camera propria perto do tubo.
func _preparar_cena_crt_tv() -> void:
	_mostrar_prompt("")
	_ocultar_convidados(true)
	_forcar_tv_estatica(true)
	_garantir_cam_crt()
	_enquadrar_cam_crt(0.0)


func _garantir_cam_crt() -> void:
	if _cam_crt != null and is_instance_valid(_cam_crt):
		return
	_cam_crt = Camera3D.new()
	_cam_crt.name = "CamCrtTv"
	_cam_crt.current = false
	_cam_crt.fov = 38.0
	_cam_crt.near = 0.05
	_cam_crt.far = 80.0
	add_child(_cam_crt)


## Camera sentada no chao, COLADA no tubo. yaw_offset em graus (look L/R).
func _enquadrar_cam_crt(yaw_offset_graus: float) -> void:
	var tv := get_tree().get_first_node_in_group(&"televisao") as Node3D
	if tv == null or _cam_crt == null:
		return
	var frente := -tv.global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	# Sentado no chao, ~1.05 m a frente — enquadra o tubo, nao o chao.
	var olho := tv.global_position + Vector3(0.0, -0.22, 0.0) - frente * 1.05
	_cam_crt.global_position = olho
	var alvo := tv.global_position + Vector3(0.0, 0.02, 0.0)
	_cam_crt.look_at(alvo, Vector3.UP)
	_cam_crt_yaw0 = _cam_crt.rotation.y
	_cam_crt.rotation.y = _cam_crt_yaw0 + deg_to_rad(yaw_offset_graus)
	# Pitch leve para o centro da tela.
	_cam_crt.rotation.x = deg_to_rad(2.0)
	_cam_crt.fov = 32.0
	_cam_crt.current = true
	# Player fora do quadro (atras/baixo), travado — nao e a cam de gameplay.
	_player.travar(true)
	_player.global_position = olho - frente * 0.35 + Vector3(0.0, -0.35, 0.0)
	_player.call("olhar_para", alvo)
	if _player.has_method("definir_fov"):
		_player.call("definir_fov", 36.0)


func _ocultar_convidados(esconder: bool) -> void:
	if esconder:
		_convidados_ocultos.clear()
		for no: Node in get_tree().get_nodes_in_group(&"convidado"):
			_convidados_ocultos.append(no)
			if no is Node3D:
				(no as Node3D).visible = false
			no.set_process(false)
			no.set_physics_process(false)
	else:
		for no: Node in _convidados_ocultos:
			if not is_instance_valid(no):
				continue
			if no is Node3D:
				(no as Node3D).visible = true
			no.set_process(true)
			no.set_physics_process(true)
		_convidados_ocultos.clear()


func _forcar_tv_estatica(ligado: bool) -> void:
	for no: Node in get_tree().get_nodes_in_group(&"televisao"):
		if no.has_method("mostrar_estatica"):
			no.call("mostrar_estatica", ligado)


## Posiciona o jogador no chao diante do tubo (fallback).
func _sentar_frente_tv(perto: bool) -> void:
	_mostrar_prompt("")
	var tv := get_tree().get_first_node_in_group(&"televisao") as Node3D
	if tv == null:
		return
	var afast := 0.92 if perto else 1.15
	var base := tv.global_position + Vector3(0.0, -0.85, 0.0)
	var frente := -tv.global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	_player.global_position = base - frente * afast + Vector3(0.0, 0.05, 0.0)
	_player.call("olhar_para", tv.global_position + Vector3(0.0, -0.05, 0.0))
	if _player.has_method("definir_pitch"):
		_player.call("definir_pitch", deg_to_rad(8.0 if perto else 4.0))
	if _player.has_method("definir_fov"):
		_player.call("definir_fov", 36.0 if perto else 42.0)
	_titulo_yaw0 = _player.rotation.y


func _ao_boot_iniciar() -> void:
	if _transicao_crt:
		return
	_transicao_crt = true
	await _transicao_tv_e_menu()


## Start: estatica + Bzum -> tubo de perto (cam dedicada) -> olhar L/R -> menu B&W.
func _transicao_tv_e_menu() -> void:
	_menu.iniciar_transicao_ui()
	_menu.definir_estatica(1.0, 1.0)
	# Um Bzum + estatica curta — menu.gd nao dispara audio no START.
	AudioDirector.tocar_ui(&"bzum", -4.0)
	AudioDirector.tocar_ui(&"estatica", -10.0)
	# Corta a piscina UI apos o one-shot (nao deixa Bzum/estatica pendurados).
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		AudioDirector.parar_ui()
	)
	if not Interiores.dentro:
		_preload_casa_boot()
	var t0 := float(Time.get_ticks_msec()) / 1000.0
	while not _boot_casa_pronta and float(Time.get_ticks_msec()) / 1000.0 - t0 < 6.0:
		await get_tree().process_frame
	_preparar_cena_crt_tv()
	_mostrar_prompt("")
	_menu.esconder_boot_texto()
	await get_tree().create_timer(0.35).timeout

	# Revela a sala: CRT some, cam dedicada COLADA no tubo (sem NPCs, sem futebol).
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(v: float) -> void:
		_menu.definir_estatica(lerpf(0.85, 0.04, v), lerpf(0.95, 0.0, v))
	, 0.0, 1.0, 1.1)
	await tw.finished
	_menu.definir_estatica(0.0, 0.0)

	# Captura do tubo de perto — congela AQUI.
	var args := OS.get_cmdline_user_args()
	if args.has("--ver-tv-reveal") or args.has("--ver-tv-close"):
		_enquadrar_cam_crt(0.0)
		return

	# Olhar esquerda / direita / frente — so perto da TV.
	await _olhar_cam_crt(-22.0, 0.55)
	await _olhar_cam_crt(22.0, 0.7)
	await _olhar_cam_crt(0.0, 0.5)
	await get_tree().create_timer(0.25).timeout

	AudioDirector.tocar_ui(&"estatica", -12.0)
	_menu.definir_estatica(1.0, 1.0)
	await get_tree().create_timer(0.28).timeout
	_liberar_cam_crt()
	_ocultar_convidados(false)
	_forcar_tv_estatica(false)
	if Interiores.dentro:
		await Interiores.sair()
	_preparar_vista_titulo()
	_menu.fim_transicao_ui()
	_menu.mostrar(Menu.Painel.TITULO)
	_titulo_ativo = true
	_transicao_crt = false


func _olhar_cam_crt(yaw_graus: float, dur: float) -> void:
	if _cam_crt == null:
		await _olhar_sala(yaw_graus, dur)
		return
	var alvo := _cam_crt_yaw0 + deg_to_rad(yaw_graus)
	var ini := _cam_crt.rotation.y
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(v: float) -> void:
		_cam_crt.rotation.y = lerpf(ini, alvo, v)
	, 0.0, 1.0, dur)
	await tw.finished


func _liberar_cam_crt() -> void:
	if _cam_crt != null and is_instance_valid(_cam_crt):
		_cam_crt.current = false
	var cam := _player.get_node_or_null("Pivo/Camera3D") as Camera3D
	if cam == null:
		cam = _player.find_child("Camera3D", true, false) as Camera3D
	if cam != null:
		cam.current = true
	if _player.has_method("liberar_fov"):
		_player.call("liberar_fov")


func _lerp_zoom_tv(pos_a: Vector3, pos_b: Vector3, t: float) -> void:
	_player.global_position = pos_a.lerp(pos_b, t)
	if _player.has_method("definir_fov"):
		_player.call("definir_fov", lerpf(36.0, 42.0, t))
	var tv := get_tree().get_first_node_in_group(&"televisao") as Node3D
	if tv != null:
		_player.call("olhar_para", tv.global_position + Vector3(0.0, -0.05, 0.0))
		if _player.has_method("definir_pitch"):
			_player.call("definir_pitch", deg_to_rad(lerpf(8.0, 4.0, t)))


func _olhar_sala(yaw_graus: float, dur: float) -> void:
	var alvo := _titulo_yaw0 + deg_to_rad(yaw_graus)
	var ini := _player.rotation.y
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(v: float) -> void:
		_player.rotation.y = lerpf(ini, alvo, v)
	, 0.0, 1.0, dur)
	await tw.finished


func _ao_comecar_pelo_menu(nome: String) -> void:
	_sair_do_titulo()
	_novo_jogo(nome)
	_rodar_abertura()


## A cena cortada que abre a partida.
##
## So em NOVO JOGO. Quem apertou CONTINUAR ja viu, e nada irrita mais quem esta
## voltando para um save do que ter de assistir de novo ao mesmo minuto de
## cinema antes de poder andar.
##
## Nao e esperada. A abertura toma conta do jogador e da camera por conta
## propria e devolve os dois no fim; segurar o `_ready` da cena por um minuto
## deixaria o resto da montagem parada atras dela.

## Caminho de captura / inspecao da Estrada Velha (mapa).
## Bob (cinematica) emenda NOVO JOGO -> estrada -> abertura via `_rodar_abertura`.
## Este gancho e so para CaptureTool / AAA do mapa sem passar pelo menu.
func _rodar_estrada() -> void:
	var _scr = load("res://src/levels/abertura_estrada.gd")
	var estrada = _scr.new()
	add_child(estrada)
	estrada.executar(self)

func _rodar_abertura() -> void:
	if OS.get_cmdline_user_args().has("--pular-abertura"):
		return
	var abertura := Abertura.new()
	add_child(abertura)
	abertura.executar(self, _player as Player, _ponto_inicial)


func _ao_continuar_pelo_menu() -> void:
	_sair_do_titulo()
	_mostrar_prompt("")


func _sair_do_titulo() -> void:
	_titulo_ativo = false
	_transicao_crt = false
	_liberar_cam_crt()
	_ocultar_convidados(false)
	_forcar_tv_estatica(false)
	_player.travar(false)
	_player.set_physics_process(true)
	if _player.has_method("liberar_fov"):
		_player.call("liberar_fov")
	var fog := get_node_or_null("Ambiente") as FogController
	if fog != null:
		fog.liberar()
	if _minimapa != null:
		_minimapa.visible = true


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
	Missoes.limpar()
	Inventario.de_dicionario({"espacos": [], "vida": 100})
	# Todo mundo comeca com a carteira no bolso, e ela nunca sai: e o unico item
	# do jogo que nao e recurso, e sim quem voce e.
	Inventario.adicionar(&"identidade")
	Inventario.adicionar(&"lanterna")
	Inventario.adicionar(&"radio")
	Inventario.adicionar(&"bandagem", 2)
	Inventario.adicionar(&"bateria", 1)


## A bicicleta que ja esta ali quando a partida comeca.
##
## Ela nao e sorteada pelo chunk como poste ou lixeira. E um objeto unico,
## colocado a mao no unico lugar do mapa que o jogo garante que o jogador vai
## ver: o ponto onde ele nasce. Um veiculo que so existe se o sorteio quiser
## nao e um veiculo do jogador, e uma surpresa.
##
## Precisa esperar o chunk. O ChunkManager monta em thread, e nos primeiros
## quadros da cena nao ha nem parede em que encostar nem chao para nao cair.
func _por_bicicleta_no_respawn() -> void:
	var onde := _ponto_inicial
	# Espera ter CHAO embaixo do ponto, e nao o chunk marcado como carregado: o
	# que a bicicleta precisa e da colisao existir, e ela so aparece quando o
	# chunk termina de ser materializado na thread principal. Perguntar pelo chao
	# e perguntar exatamente isso, sem depender de como o ChunkManager contabiliza
	# o que ja montou.
	for _k in 300:
		await get_tree().physics_frame
		if _tem_chao(onde):
			break

	var b := Bicicleta.new()
	b.name = "BicicletaDoRespawn"
	b.tinta = Quadro.sortear_tinta(int(RegistroCivil.jogador.get("id", 7)))
	add_child(b)
	var pose := _encosto_mais_perto(onde)
	b.global_position = pose.origin
	b.rotation = Vector3(0.0, pose.basis.get_euler().y, 0.0)
	b.encostar_em_parede()

	# Caminho de captura: sem isto nao ha como fotografar a bicicleta, porque
	# onde ela para depende da parede que o gerador colocou perto do respawn.
	if OS.get_cmdline_user_args().has("--olhar-bicicleta"):
		var de := b.global_position - b.global_transform.basis.x * 2.6
		_player.global_position = Vector3(de.x, b.global_position.y + 0.2, de.z)
		_player.call("olhar_para", b.global_position + Vector3(0.0, 0.62, 0.0))
		# olhar_para so gira a cabeca no eixo vertical, e a bicicleta e baixa: sem
		# baixar o olhar ela fica fora do quadro, embaixo.
		var pivo := _player.get_node_or_null("Pivo") as Node3D
		if pivo != null:
			pivo.rotation.x = -0.34


## Onde encostar a bicicleta: a parede mais proxima do ponto dado.
##
## Dezesseis raios em leque. Nao ha como perguntar ao mundo "onde e a parede
## mais perto" — a geometria do chunk ja foi fundida numa malha so e nao tem
## mais faces com nome — entao a pergunta vira medida, que e a resposta certa
## para uma pergunta sobre um mundo gerado em tempo de execucao.
##
## Sem parede em oito metros ela fica de pe ao lado do jogador. E o caso raro,
## e o codigo nao pode ficar sem resposta para ele: uma bicicleta que as vezes
## nao existe e pior que uma bicicleta de pe na calcada.
func _encosto_mais_perto(centro: Vector3) -> Transform3D:
	var espaco := get_world_3d().direct_space_state
	var altura := centro + Vector3.UP * 1.0
	var melhor_d := 24.0
	var achou := false
	var ponto := Vector3.ZERO
	var normal := Vector3.RIGHT

	for k in 16:
		var ang := TAU * float(k) / 16.0
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var consulta := PhysicsRayQueryParameters3D.create(altura, altura + dir * 24.0, 1)
		var hit := espaco.intersect_ray(consulta)
		if hit.is_empty():
			continue
		# So cenario serve de encosto. Sem este teste o raio acha o proprio
		# jogador — que esta a tres metros, na mesma camada, e e uma superficie
		# vertical perfeita — e a bicicleta nasce encostada nele.
		if not (hit.get("collider") is StaticBody3D):
			continue
		var d := altura.distance_to(hit["position"] as Vector3)
		# Parede de verdade e vertical. Chao e meio-fio tambem respondem ao raio
		# quando ele sai um pouco inclinado, e encostar a bicicleta no meio-fio
		# deixaria ela deitada no ar.
		var n: Vector3 = hit["normal"]
		if absf(n.y) > 0.5 or d >= melhor_d:
			continue
		melhor_d = d
		ponto = hit["position"]
		normal = Vector3(n.x, 0.0, n.z).normalized()
		achou = true

	# Meio metro fora da parede: e o meio da bicicleta, e ela tem meio metro de
	# largura com o guidao. Menos que isso e o guidao dentro do reboco.
	var pos := (ponto + normal * 0.46) if achou else (
		centro + _player.global_transform.basis.x * 1.3)
	pos = _subir_para_a_calcada(pos, normal)
	# O guidao aponta para a parede: e o lado por onde a bicicleta se apoia.
	var giro := atan2(-normal.z, normal.x) if achou else _player.rotation.y
	return Transform3D(Basis(Vector3.UP, giro), pos)


## Sobe o ponto para a calcada, se ele tiver caido no asfalto.
##
## A busca em leque acha a parede mais proxima em oito metros, e quando a parede
## mais proxima esta do outro lado da via ela devolve um ponto no meio da pista —
## e a bicicleta do respawn nascia deitada no asfalto, com carro passando por
## cima. A calcada fica ALTURA_MEIO_FIO acima do asfalto, e essa diferenca de
## altura e a unica pergunta que o mundo gerado responde sem ambiguidade.
##
## Anda para os dois lados da normal porque nao da para saber de que lado esta a
## calcada: a normal aponta para fora da parede achada, e a parede achada pode
## ser a de tras.
const PASSO_CALCADA := 0.25
const BUSCA_CALCADA := 8.0


func _subir_para_a_calcada(de: Vector3, normal: Vector3) -> Vector3:
	var nivel := KitModular.ALTURA_MEIO_FIO - 0.05
	for k in int(BUSCA_CALCADA / PASSO_CALCADA):
		for s: float in [-1.0, 1.0]:
			var p := de + normal * (float(k) * PASSO_CALCADA * s)
			var y := _chao_em(p)
			if y >= nivel:
				p.y = y
				return p
	var fim := de
	fim.y = _chao_em(de)
	return fim


func _tem_chao(onde: Vector3) -> bool:
	var espaco := get_world_3d().direct_space_state
	var consulta := PhysicsRayQueryParameters3D.create(
		Vector3(onde.x, 20.0, onde.z), Vector3(onde.x, -5.0, onde.z), 1)
	return not espaco.intersect_ray(consulta).is_empty()


func _chao_em(onde: Vector3) -> float:
	var espaco := get_world_3d().direct_space_state
	var consulta := PhysicsRayQueryParameters3D.create(
		Vector3(onde.x, 20.0, onde.z), Vector3(onde.x, -5.0, onde.z), 1)
	var hit := espaco.intersect_ray(consulta)
	return (hit["position"] as Vector3).y if not hit.is_empty() else onde.y


## Prompt de acao. Fica vazio quando nao ha alvo: texto permanente na tela vira
## ruido e o jogador para de ler.
func _mostrar_prompt(rotulo: String) -> void:
	if _titulo_ativo or _transicao_crt or (_menu != null and _menu.visible and _menu.painel == Menu.Painel.BOOT):
		rotulo = ""
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
	# ESC / pause fica com a PranchaInventario (inventario scrapbook). O menu
	# de titulo nao reabre no meio da partida — escopo HUD-only.
	if evento.is_action_pressed("debug_info"):
		_mostrar_debug = not _mostrar_debug
		_hud.visible = _mostrar_debug


func _process(delta: float) -> void:
	# Deriva lenta da camera no titulo: a cidade vive, o olhar respira.
	if _titulo_ativo:
		_titulo_t += delta
		var voo = -_player.global_transform.basis.z
		voo.y = 0.0
		if voo.length_squared() > 0.001:
			_player.global_position += voo.normalized() * (4.0 * delta)
		_player.rotation.y = _titulo_yaw0 + sin(_titulo_t * 0.12) * 0.09
		var pivo := _player.get_node_or_null("Pivo") as Node3D
		if pivo != null:
			pivo.rotation.x = deg_to_rad(-25.0 + sin(_titulo_t * 0.18) * 1.2)
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
