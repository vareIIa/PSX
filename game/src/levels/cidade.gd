## Cidade com streaming. A cena que se joga a partir da Fase 3.
##
## Nao tem geometria propria: tudo vem do ChunkManager, que monta os chunks em
## volta do jogador conforme ele anda. O mapa e infinito e deterministico, porque
## o conteudo de cada chunk sai da coordenada.
extends Node3D

@onready var _chunks: Node3D = $Chunks
@onready var _player: Node3D = $Player
@onready var _hud: Label = $Debug/Info

var _menu: Menu
var _prancha: PranchaInventario
var _vida_anterior: int = 100

var _mostrar_debug: bool = false
var _acc: float = 0.0
var _minimapa: Minimapa
var _faixa: HudCidade
var _titulo_ativo: bool = false
var _titulo_t: float = 0.0
var _titulo_yaw0: float = 0.0
var _boot_casa_pronta: bool = false
## Relogio do plano do boot, para a aproximacao lenta antes do START.
var _boot_t: float = 0.0
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
	# Faixa de estado no rodape: onde estou, que horas sao, lanterna e vida.
	# Camada 100, como o minimapa — o motivo esta escrito em `faixa_layout.gd`.
	_faixa = HudCidade.new()
	_faixa.alvo = _player
	add_child(_faixa)
	_montar_menu()

	# Com titulo aberto a ficha nasce no fluxo NOVO JOGO / CONTINUAR.
	# Testes e captura que pulam o menu ainda precisam do setup imediato.
	if not _menu.visible:
		_novo_jogo()
	_por_bicicleta_no_respawn()
	# Caminho de captura: a abertura sem passar pelo menu. Nao da para fotografar
	# uma cena cortada que so existe depois de tres telas de criacao de ficha.
	if OS.get_cmdline_user_args().has("--ver-abertura") or OS.get_cmdline_user_args().has("--ver-estrada") or OS.get_cmdline_user_args().has("--ver-estrada-cabine") or OS.get_cmdline_user_args().has("--ver-praca"):
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

	if OS.get_cmdline_user_args().has("--teste-bar"):
		TesteBar.executar(self, _player)
		return

	if OS.get_cmdline_user_args().has("--teste-cidade"):
		TesteCidade.executar(self, _player)
		return

	if OS.get_cmdline_user_args().has("--teste-npc"):
		TesteNpc.executar(self, _player)
		return

	# Cartao de missao sozinho, para a captura automatizada da Fase 1 da UI.
	#
	# A missao de verdade so nasce no fim da abertura, que sao dois minutos de
	# cena cortada — impossivel de fotografar num quadro fixo. Aqui ela comeca
	# direto, do mesmo jeito que `Abertura` a comeca, para o cartao ser
	# comparavel com a referencia sem depender do roteiro.
	#
	#   --ver-missao        etapa nova, com dica na tela
	#   --ver-missao=tira   depois de encolher, sem a dica
	#   --ver-missao=longo  titulo e objetivo nos piores casos do checar_hud
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--ver-missao"):
			continue
		var modo := arg.trim_prefix("--ver-missao").trim_prefix("=")
		await get_tree().create_timer(0.6).timeout
		_missao_de_captura(modo)
		break

	# Faixa de estado forcada, para a captura da Fase 2 da UI.
	#
	#   --ver-faixa            como o jogo comeca: vida cheia, sem barra
	#   --ver-faixa=ferido     dano recente, a barra aparece e fica T_LEITURA
	#   --ver-faixa=grave      abaixo de VIDA_GRAVE, a barra nao some mais
	#   --hora=HH:MM           o relogio anda, e captura tem de sair igual duas vezes
	#   --prompt=TEXTO         forca o aviso de acao sem precisar achar um alvo
	#
	# Os ajustes sem espera vem primeiro, num passe proprio. Na primeira versao
	# eles dividiam o laco com `--ver-faixa`, que espera 0,6 s e depois pulsa por
	# 4,2 s — entao a hora e o prompt so eram aplicados DEPOIS do quadro
	# fotografado, dependendo da ordem em que as flags apareciam na linha de
	# comando. A captura saia com 22:43 e sem prompt, e nada no codigo dizia por
	# que.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hora=") and _faixa != null:
			_faixa.definir_hora(arg.trim_prefix("--hora="))
		elif arg.begins_with("--prompt="):
			_mostrar_prompt(arg.trim_prefix("--prompt="))

	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--ver-faixa"):
			continue
		var vida := arg.trim_prefix("--ver-faixa").trim_prefix("=")
		Inventario.adicionar(&"lanterna")
		if _player != null:
			_player.call("alternar_lanterna")
		if vida == "":
			break
		await get_tree().create_timer(0.6).timeout
		# Origem a frente e a esquerda do jogador, para a captura mostrar o
		# clarao direcional e nao so o vermelho na tela inteira.
		var origem := Vector3.INF
		if _player != null:
			var lado := _player.global_transform.basis * Vector3(-4.0, 0.0, -3.0)
			origem = _player.global_position + lado
		Inventario.ferir(28 if vida == "ferido" else 72, origem)
		# O clarao dura meio segundo; a captura cai num quadro fixo que nao da
		# para sincronizar. Pulsar mantem o clarao no ar durante a janela toda.
		if _faixa != null:
			for _i in 14:
				_faixa.piscar_dano(origem)
				await get_tree().create_timer(0.3).timeout
		break

	# Prancha com o menu de sistema aberto, para a captura da Fase 4 da UI.
	#   --ver-pausa           painel raiz
	#   --ver-pausa=imagem    os seis ajustes de imagem
	#   --ver-pausa=som       os quatro deslizadores de volume
	#   --ver-pausa=carregar  os tres espacos de save
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--ver-pausa"):
			continue
		var pag := arg.trim_prefix("--ver-pausa").trim_prefix("=")
		Inventario.adicionar(&"pistola")
		Inventario.adicionar(&"bandagem", 2)
		await get_tree().create_timer(1.0).timeout
		_prancha.abrir()
		var ms := _prancha.menu_sistema()
		if ms != null:
			match pag:
				"imagem": ms.abrir_em(MenuSistema.Pagina.VIDEO)
				"som": ms.abrir_em(MenuSistema.Pagina.AUDIO)
				"carregar": ms.abrir_em(MenuSistema.Pagina.CARREGAR)
				_: ms.abrir_em(MenuSistema.Pagina.RAIZ)
		break

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
	_montar_dano()
	_player.alvo_de_interacao.connect(_mostrar_prompt)
	Interiores.entrou.connect(func() -> void: _mostrar_prompt(""))

	# Caminho de teste: entra num interior sem precisar achar uma porta. Serve a
	# captura automatizada, que nao tem como navegar ate uma.
	var rua_tipo := ""
	var parque_tipo := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--ver-rua="):
			rua_tipo = arg.trim_prefix("--ver-rua=")
		elif arg.begins_with("--ver-parque="):
			parque_tipo = arg.trim_prefix("--ver-parque=")
	if OS.get_cmdline_user_args().has("--ver-fachada-da-loja"):
		# Fica DE FORA do interior de proposito: e a captura da calcada, com a
		# vitrine e o portao da garagem no mesmo quadro.
		await get_tree().create_timer(1.5).timeout
		_ir_para_fachada_da_loja()
	elif OS.get_cmdline_user_args().has("--ver-fachada-do-bar"):
		await get_tree().create_timer(1.5).timeout
		_ir_para_fachada_do_bar()
	elif not rua_tipo.is_empty():
		await get_tree().create_timer(1.5).timeout
		_ir_para_rua(rua_tipo)
	elif not parque_tipo.is_empty():
		await get_tree().create_timer(1.5).timeout
		_ir_para_parque(parque_tipo)
	elif OS.get_cmdline_user_args().has("--entrar-bar"):
		await get_tree().create_timer(1.5).timeout
		Interiores.entrar(88051, _player.global_transform, &"bar")
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--bar-cena="):
				await get_tree().create_timer(2.0).timeout
				_cena_do_bar(arg.trim_prefix("--bar-cena="))
	elif OS.get_cmdline_user_args().has("--entrar-mercado"):
		await get_tree().create_timer(1.5).timeout
		Interiores.entrar(77451, _player.global_transform, &"mercado")
		# A loja tem sete comodos; a captura nao sabe andar ate eles.
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--mercado-cena="):
				await get_tree().create_timer(2.0).timeout
				_cena_do_mercado(arg.trim_prefix("--mercado-cena="))
		if OS.get_cmdline_user_args().has("--abrir-terminal"):
			await get_tree().create_timer(2.0).timeout
			_cena_do_mercado("terminal")
			await get_tree().create_timer(0.4).timeout
			_abrir_terminal_do_mercado()
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
		_forcar_fog_praca_se_pin()
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
	if OS.get_cmdline_user_args().has("--olhar-transito"):
		await _olhar_transito()

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

	# Rota tracada antes de qualquer captura de mapa, para o tracado aparecer na
	# foto. `tracar_rota_no_primeiro` escolhe o primeiro resultado do filtro em
	# vigor, que e o mesmo caminho que a tecla faz — e nao um atalho que so o
	# teste conhece.
	if OS.get_cmdline_user_args().has("--com-rota"):
		await get_tree().create_timer(0.4).timeout
		# Abrir ANTES de filtrar nao e cerimonia: a varredura de lugares roda em
		# `abrir()`, e sem ela a lista esta vazia, o filtro nao acha nada e a rota
		# sai vazia em silencio. Foi assim que a primeira captura desta fase saiu
		# com o mapa sem tracado nenhum e pareceu bug de desenho.
		Gps.abrir()
		Gps.filtrar_por(&"casa_fumaca")
		Gps.tracar_rota_no_primeiro()
		if not OS.get_cmdline_user_args().has("--ver-gps"):
			Gps.fechar()

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
			_camera_blitz_olho(cam, olhar, 50.0)
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
			_camera_blitz_olho(cam, olhar, 48.0)
		"insp":
			# Close-up D AAA: sweet-spot v15 — porta/janela, capo fora.
			var demo_c := qual.get_node_or_null("CarroDemo") as Node3D
			var ofi := qual.get_node_or_null("Oficial_0") as Node3D
			if demo_c != null and ofi != null:
				var porta: Vector3 = demo_c.global_position + b * Vector3(0.92, 1.25, -0.35)
				cam = demo_c.global_position + b * Vector3(2.25, 1.5, -0.8)
				olhar = (ofi.global_position + Vector3(0.0, 1.48, 0.0)) * 0.7 + porta * 0.3
			else:
				cam = alvo + b * Vector3(2.2, 1.48, -0.75)
				olhar = alvo + b * Vector3(0.9, 1.35, -0.3)
			_camera_blitz_olho(cam, olhar, 30.0, true)
		"conversa":
			# E AAA: par ATRAS do sedan (+Z); camera da pista; PM + motorista face a face fora da malha.
			var ofi2 := qual.get_node_or_null("Oficial_0") as Node3D
			var mot := qual.get_node_or_null("MotoristaInsp") as Node3D
			var demo_e := qual.get_node_or_null("CarroDemo") as Node3D
			if ofi2 != null and mot != null:
				var meio: Vector3 = (ofi2.global_position + mot.global_position) * 0.5
				meio.y = 0.0
				cam = meio + (-b.x) * 4.6 + Vector3.UP * 1.72
				olhar = meio + Vector3.UP * 1.38
				if demo_e != null:
					olhar = olhar * 0.86 + (demo_e.global_position + Vector3.UP * 0.7) * 0.14
			else:
				var acost := alvo + b * Vector3(qual._x_acost + 1.0, 0.0, 5.0)
				cam = acost + (-b.x) * 4.0 + Vector3.UP * 1.75
				olhar = acost + Vector3.UP * 1.35
			_camera_blitz_olho(cam, olhar, 42.0, true)
		_:
			# A/perto: elevado da pista olhando acostamento — zebra + viatura inclinada.
			var viat_no := qual.get_node_or_null("Viatura") as Node3D
			var viat := (viat_no.global_position if viat_no != null
				else alvo + b * Vector3(qual._x_acost, 0.0, -3.6))
			# Elevado da pista: zebra no chao + viatura inclinada no meio-fio.
			cam = viat + b * Vector3(-2.8, 3.2, 5.2)
			olhar = viat + b * Vector3(0.35, 0.2, -0.8)
			_camera_blitz_olho(cam, olhar, 36.0, true)
	print("[cidade] blitz modo=%s demo=%s em %.1f,%.1f,%.1f cam=%.1f,%.1f,%.1f"
		% [modo, str(demo), alvo.x, alvo.y, alvo.z, cam.x, cam.y, cam.z])

## Camera dedicada de captura blitz (perspectiva). Evita confusao origem/olho do player.
## Mantem o player no chao perto do alvo para o streaming nao descarregar a cena.
func _camera_blitz_olho(olho: Vector3, olhar: Vector3, fov: float, dia: bool = false) -> void:
	# Ancora o streaming sob a camera (nao no olhar): close-up nao engole o player no frame.
	var ancora := Vector3(olho.x, 1.0, olho.z)
	_player.global_position = ancora
	_player.visible = false
	# Captura limpa: bikes no raio da camera poluem close-ups (D) e disparam prompt.
	for no in get_tree().get_nodes_in_group("bicicleta"):
		if no is Node3D and no.global_position.distance_to(olho) < 22.0:
			(no as Node3D).visible = false
	if _player is CharacterBody3D:
		var corpo := _player as CharacterBody3D
		corpo.set_collision_mask_value(1, false)
		corpo.velocity = Vector3.ZERO
		corpo.set_physics_process(false)
		corpo.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	ChunkManager.alcance_infinito = true
	ChunkManager.raio_extra = 2
	ChunkManager.recarregar_preset()
	if dia:
		var fog := get_node_or_null("Ambiente") as FogController
		if fog != null:
			fog.forcar("res://resources/fog/fog_dia_sol.tres")
		var sol := DirectionalLight3D.new()
		sol.light_energy = 2.4
		sol.light_color = Color(1.0, 0.98, 0.92)
		sol.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(35.0), 0.0)
		add_child(sol)
	# Luz de preenchimento curta — nevoa noturna come close-ups.
	var fill := OmniLight3D.new()
	fill.light_energy = 2.8
	fill.light_color = Color(1.0, 0.95, 0.85)
	fill.omni_range = 14.0
	fill.shadow_enabled = false
	add_child(fill)
	fill.global_position = olho + Vector3(0.0, 1.5, 0.0)
	var cam := Camera3D.new()
	cam.fov = fov
	cam.near = 0.08
	cam.far = 400.0
	add_child(cam)
	cam.global_position = olho
	var up := Vector3.UP
	var dir := olhar - olho
	if absf(dir.normalized().dot(Vector3.UP)) > 0.92:
		up = Vector3.FORWARD
	cam.look_at(olhar, up)
	cam.current = true


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


## Enquadra um carro de caixa do transito. A vitrine prova lataria; isto prova
## que o Carro vivo — eixos, meia volta, motorista — chegou na rua com roda.
func _olhar_transito() -> void:
	var t0 := float(Time.get_ticks_msec()) / 1000.0
	var carro: Carro = null
	var caixa: Array[int] = [
		int(Carroceria.Modelo.SEDA), int(Carroceria.Modelo.HATCH),
		int(Carroceria.Modelo.PERUA), int(Carroceria.Modelo.PICAPE),
		int(Carroceria.Modelo.TAXI),
	]
	while carro == null:
		var caixa_vivo: Carro = null
		var qualquer: Carro = null
		for c: Carro in Transito.lista():
			if not is_instance_valid(c):
				continue
			qualquer = c
			if caixa.has(int(c.modelo)):
				caixa_vivo = c
				break
		carro = caixa_vivo if caixa_vivo != null else qualquer
		if carro != null:
			break
		if float(Time.get_ticks_msec()) / 1000.0 - t0 > 10.0:
			push_warning("[cidade] --olhar-transito: nenhum carro nasceu")
			return
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	if not is_instance_valid(carro):
		return
	# Congela: senão o carro foge da camera entre o enquadro e o --shot-frame.
	carro.freeze = true
	carro.set("ligado", false)
	await get_tree().process_frame
	if not is_instance_valid(carro):
		return
	var p := carro.global_position
	var b := carro.global_transform.basis
	var olho := p + b * Vector3(2.8, 1.45, -4.2)
	var olhar := p + Vector3(0.0, 0.50, 0.0)
	_player.visible = false
	if _player is CharacterBody3D:
		var corpo := _player as CharacterBody3D
		corpo.set_collision_mask_value(1, false)
		corpo.velocity = Vector3.ZERO
		corpo.set_physics_process(false)
		corpo.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_player.global_position = Vector3(olho.x, 1.0, olho.z)
	var velha := get_viewport().get_camera_3d()
	if velha != null:
		velha.current = false
	var fill := OmniLight3D.new()
	fill.light_energy = 3.2
	fill.light_color = Color(1.0, 0.95, 0.85)
	fill.omni_range = 12.0
	fill.shadow_enabled = false
	add_child(fill)
	fill.global_position = olho + Vector3(0.0, 1.2, 0.0)
	var cam := Camera3D.new()
	cam.fov = 42.0
	cam.near = 0.08
	cam.far = 200.0
	add_child(cam)
	cam.global_position = olho
	cam.look_at(olhar, Vector3.UP)
	cam.current = true
	print("[cidade] olhar-transito modelo=%d em %.1f,%.1f,%.1f"
		% [int(carro.modelo), p.x, p.y, p.z])


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


## Som de dano. O clarao, a direcao e a barra de vida sao da faixa
## (`hud_cidade.gd`): quem desenha "voce levou" tem de ser o mesmo que desenha
## "sobrou tanto", senao as duas metades da frase discordam. Aqui fica so o que
## nao e imagem.
func _montar_dano() -> void:
	Inventario.vida_mudou.connect(_ao_mudar_vida)


func _ao_mudar_vida(atual: int, _maximo: int) -> void:
	if atual >= _vida_anterior:
		_vida_anterior = atual
		return
	_vida_anterior = atual
	AudioDirector.tocar_ui(&"ofegante", -8.0)


## Abertura CRT + menu de jogo. ESC no jogo continua sendo a prancha.
func _montar_menu() -> void:
	_menu = Menu.new()
	_menu.jogar.connect(_ao_comecar_pelo_menu)
	_menu.continuar.connect(_ao_continuar_pelo_menu)
	_menu.boot_iniciar.connect(_ao_boot_iniciar)
	add_child(_menu)

	var args := OS.get_cmdline_user_args()
	# --noite=cerracao|limpa|garoa|abafada fixa o humor da mata. Sem ela a cena
	# sorteia, que e o que o jogo faz — e uma captura que sorteia nao compara
	# com nada.
	for a: String in args:
		if a.begins_with("--noite="):
			_menu.noite_forcada = StringName(a.trim_prefix("--noite="))
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
		# No jogo a ficha ja existe quando esta tela abre: ela nasce na assinatura
		# da tela anterior. Entrando direto por bandeira, o registro esta vazio e
		# a carteira sai sem nome, sem CPF e sem zona de leitura — meia captura,
		# justo nas tres coisas que costumam quebrar de layout.
		if RegistroCivil.jogador.is_empty():
			var nome := ""
			for a: String in args:
				if a.begins_with("--nome-teste="):
					nome = a.trim_prefix("--nome-teste=")
			RegistroCivil.criar_jogador(nome)
		_menu.mostrar(Menu.Painel.APARENCIA)
		return
	if _deve_abrir_titulo(args):
		_abrir_boot()
		return
	_menu.esconder()


## Abre so quando nao ha flag de teste/captura pedindo gameplay direto.
func _deve_abrir_titulo(args: PackedStringArray) -> bool:
	for a: String in args:
		if a in ["--ver-mapa", "--abrir-inventario", "--ver-celular", "--ver-ficha",
				"--com-rota", "--ver-gps"]:
			return false
		if a.begins_with("--ver-pausa"):
			return false
		if a.begins_with("--ver-missao"):
			return false
		if a.begins_with("--teste-") or a.begins_with("--entrar-"):
			return false
		if a.begins_with("--auto-") or a.begins_with("--shot") or a.begins_with("--ir-para="):
			return false
		if a.begins_with("--de-cima=") or a.begins_with("--desfile="):
			return false
		if a in ["--pular-menu", "--ver-abertura", "--ver-estrada", "--ver-estrada-cabine", "--ver-praca", "--olhar-blitz", "--blitz-demo", "--olhar-transito", "--ver-fachada-do-bar"] or a.begins_with("--olhar-blitz=") or a.begins_with("--blitz-demo=") or a.begins_with("--ver-rua=") or a.begins_with("--ver-parque="):
			return false
	return true


func _abrir_boot() -> void:
	_titulo_ativo = false
	_player.travar(true)
	if _minimapa != null:
		_minimapa.visible = false
	if _faixa != null:
		_faixa.visible = false
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
	if _faixa != null:
		_faixa.visible = false


## Enquadra a rua na nevoa e trava o jogador sem pausar a cidade.
##
## Por que a camera desceu para 3,2 m
## ---------------------------------
## Porque a versao anterior fotografava o lado de LA da nevoa, e isso e conta, nao
## gosto. Ela subia o jogador 15 m e olhava 25 graus para baixo; o chao no quadro
## fica entao a 15 / sen(25) = 35,5 m. O preset forcado e `fog_denso`, que fecha
## em `fog_end = 18 m`, e o corte de desenho do ChunkManager sai de
## `fog_end * ALCANCE_EXTRA`, uns 24 m. Tudo que a tela de titulo enquadrava
## estava 17 m depois do fim da nevoa e 11 m depois do corte de desenho — a tela
## era, por aritmetica, um retangulo cinza, e nenhum ajuste de interface
## consertaria isso.
##
## Aqui a camera corre a 3,2 m olhando quase na horizontal: o asfalto, o meio-fio,
## o cone do poste e a fachada dos dois lados caem todos dentro dos 18 m, e a
## nevoa engole o fundo — que e o que faz a rua parecer nao ter fim. Mas ela so
## engole o que primeiro apareceu.
##
## E a mesma licao que `abertura.gd` ja tinha pago no plano da avenida e escrito
## por extenso nas constantes AVENIDA_A. Ela estava documentada a um arquivo de
## distancia e a tela de titulo repetiu o erro mesmo assim.
const TITULO_ALTURA := 3.2
## Quase na horizontal. Dois graus para baixo poem o meio-fio no terco de baixo do
## quadro sem apontar a lente para o chao.
const TITULO_PITCH := -2.0
## Deriva. A 1,1 m/s a rua anda o suficiente para a imagem nao ser um quadro
## parado, e devagar o bastante para ninguem sentir que o jogo comecou sozinho.
## A versao anterior corria 4 m/s — movendo uma parede cinza a 4 m/s.
const TITULO_DERIVA := 1.1


func _preparar_vista_titulo() -> void:
	_player.travar(true)
	_player.set_physics_process(false)
	if _player.has_method("liberar_fov"):
		_player.call("liberar_fov")
	# Com a mata montada, o menu cobre a tela inteira e a cidade nao aparece —
	# entao nao ha o que enquadrar, e mover o jogador so faria o streaming
	# derrubar e remontar chunk atras de uma imagem que ninguem ve. A vista de
	# rua continua existindo para o caminho em que a cena da estrada nao carrega.
	var precisa_enquadrar := _menu == null or not _menu.tem_fundo_mata()
	if precisa_enquadrar:
		var vista := _vista_de_rua(_player.global_position)
		_player.global_position = vista["pos"]
		_player.rotation.y = float(vista["yaw"])
		var pivo := _player.get_node_or_null("Pivo") as Node3D
		if pivo != null:
			pivo.rotation.x = deg_to_rad(TITULO_PITCH)
	_titulo_yaw0 = _player.rotation.y
	_titulo_t = 0.0
	var fog := get_node_or_null("Ambiente") as FogController
	if fog != null:
		fog.forcar("res://resources/fog/fog_denso.tres")


## Onde por a camera para haver RUA no quadro, e para que lado olhar.
##
## Pergunta a malha, e nao a fisica: `MalhaUrbana` diz onde passa via sem que
## exista um triangulo montado, e a resposta e a mesma em toda execucao. Um raio
## de colisao daria resposta diferente conforme o streaming tivesse ou nao
## terminado de montar o chunk, e a tela de titulo abre exatamente no instante em
## que ele ainda esta montando.
##
## Devolve `{"pos": Vector3, "yaw": float}`.
func _vista_de_rua(de: Vector3) -> Dictionary:
	var tam := MalhaUrbana.TAM
	var melhor_pos := de + Vector3(0.0, TITULO_ALTURA, 0.0)
	var melhor_yaw := _player.rotation.y
	var melhor_d := INF
	# Varre as linhas de grade em volta e fica com a via mais perto. Duas voltas
	# de cinco chunks cobrem o periodo inteiro da malha: ha avenida a cada cinco,
	# entao sempre ha via dentro desse alcance.
	var ci := roundi(de.x / tam)
	var cj := roundi(de.z / tam)
	for d in range(-MalhaUrbana.PERIODO, MalhaUrbana.PERIODO + 1):
		var i := ci + d
		if MalhaUrbana.via_x(i) != MalhaUrbana.Via.NENHUMA:
			var x := float(i) * tam
			var dist := absf(x - de.x)
			if dist < melhor_d:
				melhor_d = dist
				# Via em x = i*32 corre ao longo de Z. Olhar no sentido em que o
				# jogador ja estava evita um corte de 180 graus ao sair do menu.
				var frente := -_player.global_transform.basis.z
				var sentido := 1.0 if frente.z >= 0.0 else -1.0
				melhor_pos = Vector3(x, de.y + TITULO_ALTURA, de.z)
				melhor_yaw = 0.0 if sentido > 0.0 else PI
		var j := cj + d
		if MalhaUrbana.via_z(j) != MalhaUrbana.Via.NENHUMA:
			var z := float(j) * tam
			var dist2 := absf(z - de.z)
			if dist2 < melhor_d:
				melhor_d = dist2
				var frente2 := -_player.global_transform.basis.z
				var sentido2 := 1.0 if frente2.x >= 0.0 else -1.0
				melhor_pos = Vector3(de.x, de.y + TITULO_ALTURA, z)
				melhor_yaw = -PI * 0.5 if sentido2 > 0.0 else PI * 0.5
	return {"pos": melhor_pos, "yaw": melhor_yaw}


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


## Monta o plano da sala: gente VIVA, neve na TV, camera propria no plano largo.
##
## Os convidados nao sao mais escondidos. `_ocultar_convidados(true)` estava aqui
## desde o comeco e apagava as oito pessoas que andam, fumam e conversam — no
## unico plano do jogo que existe para mostrar que a casa esta cheia. O vazio da
## tela era decisao de codigo, nao limitacao de cena.
##
## A TV continua em estatica: ela e a origem do titulo, e a neve dela e a unica
## luz que se mexe no comodo — e o que faz as silhuetas piscarem.
func _preparar_cena_crt_tv() -> void:
	_mostrar_prompt("")
	_ocultar_convidados(false)
	_forcar_tv_estatica(true)
	_garantir_cam_crt()
	_enquadrar_cam_crt(0.0, SALA_LARGA_DIST, SALA_LARGA_FOV)
	# O boot passa a mostrar a sala de verdade em vez da placa parada.
	if _menu != null:
		_menu.usar_fundo_vivo(true)
	_boot_t = 0.0


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


## Distancia e abertura do plano largo da sala, e do plano colado no tubo.
##
## O largo existe porque o plano da casa tem UM proposito, escrito em
## `abertura.gd`: dizer que aquela casa e cheia de gente viva. Colado a 1,05 m do
## tubo com 32 graus de abertura, nenhuma das oito pessoas cabe no quadro — o
## plano dizia o contrario do que foi escrito para dizer.
const SALA_LARGA_DIST := 3.4
const SALA_LARGA_FOV := 62.0
const SALA_PERTO_DIST := 1.05
const SALA_PERTO_FOV := 32.0


## Camera diante do tubo. `dist` em metros e `fov` em graus; yaw_offset em graus
## para o olhar L/R.
func _enquadrar_cam_crt(yaw_offset_graus: float, dist: float = SALA_PERTO_DIST,
		fov: float = SALA_PERTO_FOV) -> void:
	var tv := get_tree().get_first_node_in_group(&"televisao") as Node3D
	if tv == null or _cam_crt == null:
		return
	var frente := -tv.global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	# Sentado no chao. Perto enquadra o tubo; longe enquadra a sala e quem esta
	# nela. A altura sobe um pouco com a distancia, senao o plano largo fotografa
	# o chao do comodo.
	var altura := lerpf(-0.22, 0.32, clampf((dist - SALA_PERTO_DIST)
		/ maxf(SALA_LARGA_DIST - SALA_PERTO_DIST, 0.001), 0.0, 1.0))
	var olho := tv.global_position + Vector3(0.0, altura, 0.0) - frente * dist
	_cam_crt.global_position = olho
	var alvo := tv.global_position + Vector3(0.0, 0.02, 0.0)
	_cam_crt.look_at(alvo, Vector3.UP)
	_cam_crt_yaw0 = _cam_crt.rotation.y
	_cam_crt.rotation.y = _cam_crt_yaw0 + deg_to_rad(yaw_offset_graus)
	# Pitch leve para o centro da tela.
	_cam_crt.rotation.x = deg_to_rad(2.0)
	_cam_crt.fov = fov
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
	if args.has("--ver-tv-close"):
		_enquadrar_cam_crt(0.0)
		return
	if args.has("--ver-tv-reveal"):
		_enquadrar_cam_crt(0.0, SALA_LARGA_DIST, SALA_LARGA_FOV)
		return

	# Olhar a sala PRIMEIRO, no plano largo, onde ha gente para ver. Depois
	# empurrar ate o tubo. A ordem importa: colado no tubo desde o primeiro
	# quadro, o olhar L/R varria parede.
	await _olhar_cam_crt(-20.0, 0.8)
	await _olhar_cam_crt(18.0, 0.9)
	await _olhar_cam_crt(0.0, 0.6)
	await _empurrar_ate_o_tubo(1.4)
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


## Aproximacao lenta do plano largo ate o tubo. E o corte que liga "a sala" a
## "a televisao": sem ele o jogo saltava de um enquadramento para o outro e o
## jogador nao entendia que a TV que vira o menu e aquela TV.
func _empurrar_ate_o_tubo(dur: float) -> void:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(v: float) -> void:
		_enquadrar_cam_crt(0.0,
			lerpf(SALA_LARGA_DIST, SALA_PERTO_DIST, v),
			lerpf(SALA_LARGA_FOV, SALA_PERTO_FOV, v))
	, 0.0, 1.0, dur)
	await tw.finished


func _olhar_cam_crt(yaw_graus: float, dur: float) -> void:
	if _cam_crt == null:
		await _olhar_sala(yaw_graus, dur)
		return
	var alvo := _cam_crt_yaw0 + deg_to_rad(yaw_graus)
	var ini := _cam_crt.rotation.y
	var fov := _cam_crt.fov
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(v: float) -> void:
		_cam_crt.rotation.y = lerpf(ini, alvo, v)
		_cam_crt.fov = fov
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
## Ordem: Estrada Velha (carro) -> preto/emenda -> Abertura (praca). A estrada
## nao devolve o controle; a Abertura abre ainda no preto com
## Cinema.fechar_de_imediato.
##
## Nao e esperada pelos chamadores. A sequencia toma conta do jogador e da
## camera por conta propria e devolve os dois no fim; segurar o `_ready` da
## cena por um minuto deixaria o resto da montagem parada atras dela.
##
## `--pular-abertura` pula as duas. `--ver-abertura` exercita o caminho inteiro
## (estrada + praca).

## Caminho de captura / inspecao da Estrada Velha (mapa) sem passar pelo menu.
func _rodar_estrada() -> void:
	var _scr = load("res://src/levels/abertura_estrada.gd")
	var estrada = _scr.new()
	add_child(estrada)
	estrada.executar(self)


var _fog_praca_ok := false
func _forcar_fog_praca_se_pin() -> void:
	if _fog_praca_ok:
		return
	var args := OS.get_cmdline_user_args()
	var pin := false
	for a in args:
		if a.begins_with("--ir-para=270") or a == "--ver-praca":
			pin = true
			break
	if not pin:
		return
	var fog := get_node_or_null("Ambiente") as FogController
	if fog == null:
		fog = get_tree().get_first_node_in_group(&"fog_controller") as FogController
	if fog != null:
		fog.forcar(FogController.PRESET_PRACA)
		_fog_praca_ok = true
		print("[cidade] fog praca -> praca_noite")

func _rodar_abertura() -> void:
	_forcar_fog_praca_se_pin()
	var args := OS.get_cmdline_user_args()
	var pin_praca := false
	for a in args:
		if a.begins_with("--ir-para=270"):
			pin_praca = true
			break
	if args.has("--ver-praca") or pin_praca:
		var fog := get_node_or_null("Ambiente") as FogController
		if fog != null:
			fog.forcar(FogController.PRESET_PRACA)
			print("[cidade] fog pin_praca -> praca_noite")
	if args.has("--pular-abertura"):
		return
	var so_estrada := (OS.get_cmdline_user_args().has("--ver-estrada")
		or OS.get_cmdline_user_args().has("--ver-estrada-cabine"))
	var so_praca := OS.get_cmdline_user_args().has("--ver-praca")
	if not so_praca:
		var estrada := AberturaEstrada.new()
		add_child(estrada)
		await estrada.executar(self)
		if so_estrada:
			return
	# Ainda no preto: Abertura.executar comeca com Cinema.fechar_de_imediato.
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
	if _faixa != null:
		_faixa.visible = true


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
## Missao plantada so para a captura do cartao. Nao passa pelo roteiro.
func _missao_de_captura(modo: String) -> void:
	if modo == "longo":
		Missoes.comecar({
			"id": &"captura_longa",
			"titulo": "O ESCRITORIO DE REGISTRO CIVIL DA MATRIZ",
			"etapas": [
				{
					"texto": "Leve o envelope lacrado ate o balcao do registro civil antes que o expediente termine.",
					"dica": "[E] falar   [TAB] bolsa   [M] abre o GPS",
				},
				{"texto": "Volte com o protocolo.", "dica": ""},
			],
			"alvo": {"mundo": _player.global_position + Vector3(240.0, 0.0, -180.0)},
		})
	else:
		Missoes.comecar_primeira(_player.global_position)
	if modo == "tira":
		# Pula a espera de leitura: a tira e o estado em que o cartao passa a
		# maior parte da partida, e e ela que precisa ser conferida.
		for no: Node in get_tree().get_nodes_in_group(&"hud"):
			if no is HudMissao:
				await get_tree().create_timer(0.5).timeout
				(no as HudMissao).encolher_agora()


func _mostrar_prompt(rotulo: String) -> void:
	if _titulo_ativo or _transicao_crt or (_menu != null and _menu.visible and _menu.painel == Menu.Painel.BOOT):
		rotulo = ""
	# Quem desenha e a faixa: o prompt tem de saber a altura dela para nao
	# escrever por cima, e so um dos dois pode ser o dono dessa conta.
	if _faixa != null:
		_faixa.definir_prompt(("[E]  " + rotulo) if rotulo != "" else "")


func _unhandled_input(evento: InputEvent) -> void:
	# ESC / pause fica com a PranchaInventario (inventario scrapbook). O menu
	# de titulo nao reabre no meio da partida — escopo HUD-only.
	if evento.is_action_pressed("debug_info"):
		_mostrar_debug = not _mostrar_debug
		_hud.visible = _mostrar_debug


func _process(delta: float) -> void:
	# Deriva lenta da camera no titulo: a cidade vive, o olhar respira.
	if _titulo_ativo and (_menu == null or not _menu.tem_fundo_mata()):
		_titulo_t += delta
		var voo := -_player.global_transform.basis.z
		voo.y = 0.0
		if voo.length_squared() > 0.001:
			_player.global_position += voo.normalized() * (TITULO_DERIVA * delta)
		# Respiracao, e nao panoramica. O giro e um terco do que era: com a camera
		# a 3,2 m ha fachada perto dos dois lados, e o mesmo balanco que passava
		# despercebido contra uma parede cinza vira enjoo contra parede de predio.
		_player.rotation.y = _titulo_yaw0 + sin(_titulo_t * 0.12) * 0.03
		var pivo := _player.get_node_or_null("Pivo") as Node3D
		if pivo != null:
			pivo.rotation.x = deg_to_rad(TITULO_PITCH + sin(_titulo_t * 0.18) * 0.6)
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


## Enquadramentos do mercado para a captura automatizada.
##
## Existe porque a captura nao sabe andar. O mercado passou a ter sete comodos e
## duas bocas para a rua, e nenhum deles se julga por numero: se o corredor de
## servico ficou verde demais, se o portao esta do lado errado da fachada ou se o
## monitor do balcao le como monitor, so a imagem responde. Cada nome aqui e um
## quadro que alguem vai olhar.
##
##     godot --path game -- --entrar-mercado --mercado-cena=garagem \
##         --shot=out.png --shot-frame=90 --shot-quit
##
## As coordenadas sao de PLANTA, as mesmas do MercadoBuilder, somadas ao
## deslocamento em que os interiores vivem. As DUAS alturas — a de ficar e a de
## olhar — sao medidas do chao do comodo, como quem le a planta espera.
##
## Que `olhar_para` mede o alvo a partir da ORIGEM do jogador, que fica no pe, e
## problema de `_cena_do_mercado` e nao de quem escreve a tabela. A primeira
## rodada destas capturas saiu com nove fotos do forro porque o alvo do balcao,
## a 1,15 m do chao, esta 47 cm ABAIXO do olho e mesmo assim mandava a camera
## para cima. Corrigir na tabela seria escrever nove numeros negativos sem
## explicacao nenhuma no arquivo.
const CENAS_MERCADO := {
	# O quadro que a loja existe para dar: corredor central, camara fria no fim.
	"salao": [Vector3(12.8, 0.0, 2.0), Vector3(12.8, 1.45, 11.5)],
	# O caixa inteiro, com o computador na ponta.
	"caixa": [Vector3(10.6, 0.0, 5.0), Vector3(8.15, 1.15, 4.6)],
	# O monitor de perto, que e de onde se aperta E.
	"terminal": [Vector3(9.1, 0.0, 5.4), Vector3(8.15, 1.28, 5.4)],
	# A porta de servico vista do salao: e a travessia que separa as duas caras
	# da loja, e ela tem de parecer uma porta em que da vontade de mexer.
	"porta_servico": [Vector3(9.4, 0.0, 6.9), Vector3(6.6, 1.35, 6.6)],
	# O corredor de ponta a ponta, com a maquina de refri no fim.
	"corredor": [Vector3(6.1, 0.0, 6.6), Vector3(0.8, 1.3, 7.4)],
	# A garagem de dentro, olhando para o portao fechado.
	"garagem": [Vector3(4.4, 0.0, 5.1), Vector3(1.4, 1.25, 1.4)],
	# O deposito: estante, palete e caixa. E o oposto da gondola do salao.
	"deposito": [Vector3(4.6, 0.0, 2.2), Vector3(0.6, 1.3, 3.4)],
	# Da porta, olhando a pia. O box fica no fundo a esquerda, aberto, que e
	# como um banheiro de loja se le: cuba na parede e uma porta de box ao lado.
	"banheiro": [Vector3(1.55, 0.0, 8.7), Vector3(2.55, 1.15, 10.4)],
	# A copa com a mesa, o quadro de avisos e os armarios.
	"copa": [Vector3(5.05, 0.0, 9.05), Vector3(5.05, 1.1, 12.3)],
	# O atendimento, na ordem em que ele acontece. Sao quatro quadros do MESMO
	# balcao, e e essa repeticao que os torna uteis: o que muda de um para o outro
	# nao e o enquadramento, e o estado do gesto.
	# Todos de DENTRO do caixa, e nao da fila. Do lado do cliente ele proprio
	# tapa o balcao — de perto, uma pessoa em pe ocupa o quadro inteiro. De
	# dentro, ela aparece do outro lado do tampo, que e onde o interlocutor tem
	# de estar, e o balcao inteiro fica a vista com a carteira em cima dele.
	"balcao": [Vector3(7.25, 0.0, 4.1), Vector3(8.5, 1.04, 5.1)],
	"carteira": [Vector3(7.25, 0.0, 4.4), Vector3(8.3, 1.03, 4.75)],
	"leitura": [Vector3(7.25, 0.0, 4.6), Vector3(8.1, 1.04, 5.06)],
	"busca": [Vector3(7.3, 0.0, 4.9), Vector3(8.3, 1.27, 5.4)],
}

## Cenas que precisam de alguem apertando alguma coisa depois de a camera pousar.
const ACIONAM_MERCADO: Array[String] = ["carteira", "leitura", "busca"]


func _abrir_terminal_do_mercado() -> void:
	# Abre a ficha de alguem que o registro ja tem. A captura da tela cheia
	# existe para julgar a consulta, nao o CRT desligado sobre o balcao.
	if not Terminal.pode_abrir() and not Terminal.ativo:
		return
	if not Terminal.ativo:
		Terminal.abrir()
	var id := RegistroCivil.id_de_transeunte(90210)
	Terminal.consultar_cpf(RegistroCivil.cpf_de(id))


func _cena_do_mercado(nome: String) -> void:
	if not CENAS_MERCADO.has(nome):
		push_warning("cidade: cena de mercado desconhecida '%s'" % nome)
		return
	var par: Array = CENAS_MERCADO[nome]
	var onde: Vector3 = par[0]
	var alvo: Vector3 = par[1]
	_player.global_position = Interiores.DESLOCAMENTO + onde
	# Baixa o alvo pela altura do olho: a tabela fala em altura de chao e
	# `olhar_para` mede do pe. Ver o cabecalho.
	_player.call("olhar_para", Interiores.DESLOCAMENTO + alvo
		- Vector3(0.0, Player.ALTURA_OLHO, 0.0))
	if _player.has_method("zerar_velocidade"):
		_player.call("zerar_velocidade")
	if ACIONAM_MERCADO.has(nome):
		await _acionar_cena_do_mercado(nome)


## Aperta o que a cena pede, depois que a camera ja pousou.
##
## A captura nao tem dedos, e tres dos quadros do balcao so existem DEPOIS de
## alguem acionar alguma coisa: a carteira aberta, o leitor apitando, a busca por
## nome com resultado na tela. Sem isto os tres sairiam do mesmo balcao parado.
func _acionar_cena_do_mercado(nome: String) -> void:
	var interior := get_tree().current_scene.get_node_or_null("Interior")
	var balcao: Node = null
	if interior != null:
		balcao = interior.get_node_or_null("AtendimentoBalcao")
	match nome:
		"carteira":
			if balcao != null:
				(balcao.get_node("Identidade") as Interativo).interagir(_player)
		"leitura":
			if balcao == null:
				return
			# Abre e fecha a carteira, que e o que arma o leitor, e so entao passa
			# no sensor. E a sequencia do jogador, sem atalho: um leitor acionado
			# por fora nao acenderia.
			(balcao.get_node("Identidade") as Interativo).interagir(_player)
			await get_tree().create_timer(0.4).timeout
			Documento.fechar()
			await get_tree().create_timer(0.3).timeout
			(balcao.get_node("Leitor") as Interativo).interagir(_player)
		"busca":
			# Procura pelo sobrenome do cliente do balcao: e o caso em que a busca
			# por nome costuma devolver mais de um, que e o quadro que vale ver.
			var alvo := "SILVA"
			if balcao != null:
				var f := RegistroCivil.identidade(
					int(balcao.get_meta(&"id_da_carteira", -1)))
				if not f.is_empty():
					alvo = String(f["sobrenome"]).split(" ")[0]
			Terminal.buscar(alvo)


## Planta o jogador na calcada, de frente para uma loja de verdade da cidade.
##
## E a unica captura do mercado que NAO acontece dentro dele, e a que mais
## importa depois desta mudanca: a fachada agora tem duas bocas — a vitrine com a
## porta automatica e, ao lado, o portao da garagem. De que LADO o portao caiu e
## uma coisa que so a imagem responde, porque o lado sai de uma cadeia de sinais
## (a normal da face, o eixo local da porta, a base do jogador) em que cada elo
## esta certo sozinho e o conjunto pode sair espelhado.
##
## A loja e procurada e nao escolhida a dedo: uma coordenada fixa deixaria de ter
## loja no dia em que a regra de distrito mudar, e a captura sairia de uma parede
## qualquer sem ninguem perceber.
## Planta o jogador na calcada de uma quadra do tipo pedido.
##
## `residencial` e `comercial` leem MalhaUrbana: casa vs predio de loja. A
## captura da variedade de fachada nao pode ser a da HIKARI — aquela ja tem
## letreiro proprio e distorce o julgamento do resto da rua.
func _ir_para_parque(tipo: String) -> void:
	var mapa := {
		"praca": ParqueBuilder.Traco.PRACA,
		"lago": ParqueBuilder.Traco.LAGO,
		"parquinho": ParqueBuilder.Traco.PARQUINHO,
		"bosque": ParqueBuilder.Traco.BOSQUE,
		"campo": ParqueBuilder.Traco.CAMPO,
	}
	var quer: int = int(mapa.get(tipo, -1))
	for raio in range(0, 28):
		for cx in range(-raio, raio + 1):
			for cz in range(-raio, raio + 1):
				if maxi(absi(cx), absi(cz)) != raio:
					continue
				var quadra := MalhaUrbana.quadra_de(cx, cz)
				if int(quadra["uso"]) != MalhaUrbana.Uso.PARQUE:
					continue
				var plano := ParqueBuilder.planta(quadra)
				if quer >= 0 and int(plano["traco"]) != quer:
					continue
				var area: Rect2 = plano["area"]
				var origem := Vector3(float(int(quadra["x0"])) * KitModular.CHUNK, 0.0,
					float(int(quadra["z0"])) * KitModular.CHUNK)
				var y := KitModular.ALTURA_MEIO_FIO + 0.06
				if int(plano["traco"]) == ParqueBuilder.Traco.LAGO:
					var lago := ParqueBuilder.lago_de(plano)
					_player.global_position = origem + Vector3(lago.get_center().x, y,
						lago.end.y + 3.2)
					_player.call("olhar_para", origem + Vector3(lago.get_center().x,
						0.4 - Player.ALTURA_OLHO, lago.get_center().y))
				else:
					# Calcada do portao SUL, olhando para dentro.
					_player.global_position = origem + Vector3(area.get_center().x, y,
						area.end.y + 1.6)
					_player.call("olhar_para", origem + Vector3(area.get_center().x,
						1.5 - Player.ALTURA_OLHO, area.end.y - 12.0))
				if _player.has_method("zerar_velocidade"):
					_player.call("zerar_velocidade")
				return
	push_warning("cidade: nenhum parque '%s' em 28 chunks" % tipo)


func _ir_para_rua(tipo: String) -> void:
	var quer_casa := tipo == "residencial"
	for raio in range(0, 12):
		for cx in range(-raio, raio + 1):
			for cz in range(-raio, raio + 1):
				if maxi(absi(cx), absi(cz)) != raio:
					continue
				var quadra := MalhaUrbana.quadra_de(cx, cz)
				if int(quadra["uso"]) != MalhaUrbana.Uso.EDIFICADO:
					continue
				var dist: int = quadra["distrito"]
				if quer_casa and dist != MalhaUrbana.Distrito.RESIDENCIAL:
					continue
				if not quer_casa and dist != MalhaUrbana.Distrito.COMERCIAL:
					continue
				var faces := ChunkBuilder.faces_de_rua(
					MalhaUrbana.bordas(cx, cz), ChunkBuilder.area_util(cx, cz))
				if faces.is_empty():
					continue
				_plantar_na_face(faces[0], cx, cz)
				return
	push_warning("cidade: nenhuma rua %s em 12 chunks" % tipo)


func _plantar_na_face(face: Dictionary, cx: int, cz: int) -> void:
	var origem := Vector3(float(cx) * KitModular.CHUNK, 0.0,
		float(cz) * KitModular.CHUNK)
	var direcao: int = face["direcao"]
	var normal := KitModular._normal(direcao)
	var lateral := KitModular._lateral(direcao)
	var meio: Vector3 = origem + Vector3(face["canto"]) \
		+ Vector3(face["eixo"]) * (float(face["comprimento"]) * 0.5)
	# De esguelha: de frente a fachada e um retangulo e o vizinho some. Vinte
	# graus mostram dois predios e a variedade que a rua ganhou.
	_player.global_position = meio + normal * 8.5 + lateral * 5.0 \
		+ Vector3(0.0, KitModular.ALTURA_MEIO_FIO + 0.05, 0.0)
	_player.call("olhar_para",
		meio + Vector3(0.0, 2.1 - Player.ALTURA_OLHO, 0.0))
	if _player.has_method("zerar_velocidade"):
		_player.call("zerar_velocidade")


func _ir_para_fachada_da_loja() -> void:
	for raio in range(0, 9):
		for cx in range(-raio, raio + 1):
			for cz in range(-raio, raio + 1):
				if maxi(absi(cx), absi(cz)) != raio:
					continue
				for ponto: Dictionary in ChunkBuilder.pontos_de_interesse(cx, cz):
					if ponto.get("tipo", &"") != &"porta":
						continue
					if ponto.get("interior", &"") != &"mercado":
						continue
					_plantar_na_calcada(ponto, cx, cz)
					return
	push_warning("cidade: nenhuma loja encontrada em 9 chunks")


## O `pos` de um ponto de interesse e LOCAL ao chunk, e nao do mundo.
##
## Quem monta a cidade nunca precisou saber disso: o ChunkManager poe o no do
## chunk em (cx*32, 0, cz*32) e todo prop entra como filho dele, entao o motor
## faz a soma. Aqui nao ha no nenhum — o jogador e teleportado para um numero —
## e a soma tem de ser feita a mao.
##
## Custou uma tarde. A captura da fachada saia de um predio escuro qualquer a
## sessenta metros da loja, e como a foto mostrava UM predio com UMA porta, ela
## parecia a loja com a vitrine apagada. O diagnostico que resolveu foi imprimir
## a coordenada do chunk junto com a da porta: 2,-2 com z=20,66 nao fecha.
func _plantar_na_calcada(ponto: Dictionary, cx: int, cz: int) -> void:
	var origem := Vector3(float(cx) * KitModular.CHUNK, 0.0,
		float(cz) * KitModular.CHUNK)
	var giro := float(ponto["giro"])
	var normal := Vector3(sin(giro), 0.0, cos(giro))
	var lateral := Vector3(cos(giro), 0.0, -sin(giro))
	# O centro da frente de loja fica uma folha adiante da batente esquerda, e o
	# portao a AFASTAMENTO_PORTAO dele. O olho vai para o meio dos dois, senao a
	# captura enquadra uma coisa ou a outra e nao a relacao entre elas, que e
	# justamente o que precisa ser julgado.
	var centro := origem + Vector3(ponto["pos"]) + lateral * Porta.FOLHA_LARGURA
	var meio := centro + lateral * (KitMercado.AFASTAMENTO_PORTAO * 0.5)

	# `--fachada-alvo=` desloca o alvo pela calcada, em metros, a partir do meio.
	# Serve para fotografar a vitrine e o portao de perto, um de cada vez: no
	# quadro que pega os dois inteiros nenhum dos dois tem pixel suficiente para
	# se julgar.
	var desvio := 0.0
	var distancia := 9.5
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fachada-alvo="):
			desvio = float(arg.trim_prefix("--fachada-alvo="))
		elif arg.begins_with("--fachada-dist="):
			distancia = float(arg.trim_prefix("--fachada-dist="))
	meio += lateral * desvio

	# Do outro lado da rua. De perto a fachada nao cabe no quadro, e o ponto
	# desta captura e justamente a RELACAO entre as duas bocas — vitrine e
	# portao —, que so existe quando as duas aparecem juntas.
	_player.global_position = meio + normal * distancia + Vector3(0.0, 0.15, 0.0)
	# Meia altura do letreiro, descontando o olho: ver o cabecalho de
	# CENAS_MERCADO. Aqui o erro seria pior que la dentro, porque a captura sai
	# apontada para o ceu e o ceu de madrugada e uma tela preta.
	_player.call("olhar_para",
		meio + Vector3(0.0, 2.4 - Player.ALTURA_OLHO, 0.0))
	if _player.has_method("zerar_velocidade"):
		_player.call("zerar_velocidade")


## Enquadramentos do bar para a captura. Coordenadas de planta, iguais as do
## BarBuilder, somadas ao deslocamento dos interiores. Alturas de chao; olhar_para
## mede do pe, entao a tabela desconta ALTURA_OLHO no chamador.
const CENAS_BAR := {
	"salao": [Vector3(5.0, 0.0, 1.55), Vector3(5.0, 1.40, 5.6)],
	"vao": [Vector3(5.0, 0.0, 2.2), Vector3(5.0, 1.45, 0.15)],
	"balcao": [Vector3(5.7, 0.0, 5.35), Vector3(8.1, 1.18, 4.65)],
	"tv": [Vector3(3.6, 0.0, 3.35), Vector3(0.55, 1.70, 3.35)],
	"calcada": [Vector3(5.0, 0.0, 1.4), Vector3(2.5, 0.85, 2.1)],
}


func _cena_do_bar(nome: String) -> void:
	if not CENAS_BAR.has(nome):
		push_warning("cidade: cena de bar desconhecida '%s'" % nome)
		return
	var par: Array = CENAS_BAR[nome]
	var onde: Vector3 = par[0]
	var alvo: Vector3 = par[1]
	_player.global_position = Interiores.DESLOCAMENTO + onde
	_player.call("olhar_para", Interiores.DESLOCAMENTO + alvo
		- Vector3(0.0, Player.ALTURA_OLHO, 0.0))
	if _player.has_method("zerar_velocidade"):
		_player.call("zerar_velocidade")


func _ir_para_fachada_do_bar() -> void:
	var cena := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--bar-cena="):
			cena = arg.trim_prefix("--bar-cena=")
	for raio in range(0, 9):
		for cx in range(-raio, raio + 1):
			for cz in range(-raio, raio + 1):
				if maxi(absi(cx), absi(cz)) != raio:
					continue
				for ponto: Dictionary in ChunkBuilder.pontos_de_interesse(cx, cz):
					if ponto.get("tipo", &"") != &"porta":
						continue
					if ponto.get("interior", &"") != &"bar":
						continue
					_plantar_na_calcada_do_bar(ponto, cx, cz, cena)
					return
	push_warning("cidade: nenhum bar encontrado em 9 chunks")


func _plantar_na_calcada_do_bar(ponto: Dictionary, cx: int, cz: int,
		cena: String) -> void:
	var origem := Vector3(float(cx) * KitModular.CHUNK, 0.0,
		float(cz) * KitModular.CHUNK)
	var giro := float(ponto["giro"])
	var normal := Vector3(sin(giro), 0.0, cos(giro))
	var lateral := Vector3(cos(giro), 0.0, -sin(giro))
	var centro := origem + Vector3(ponto["pos"]) + lateral * (KitBar.LARGURA_VAO * 0.5)
	var distancia := 8.5
	var alvo_y := 2.55
	if cena == "calcada" or cena == "vao":
		distancia = 4.6
		alvo_y = 1.15 if cena == "calcada" else 1.55
		if cena == "calcada":
			centro += normal * KitBar.AFASTAMENTO_MESA
	_player.global_position = centro + normal * distancia + Vector3(0.0, 0.15, 0.0)
	_player.call("olhar_para",
		centro + Vector3(0.0, alvo_y - Player.ALTURA_OLHO, 0.0))
	if _player.has_method("zerar_velocidade"):
		_player.call("zerar_velocidade")

