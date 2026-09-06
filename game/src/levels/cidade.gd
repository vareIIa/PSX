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
	add_child(PranchaInventario.new())
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
	if OS.get_cmdline_user_args().has("--entrar-casa"):
		await get_tree().create_timer(1.5).timeout
		Interiores.entrar(77123, _player.global_transform, &"casa")
		# Enquadra o morador e abre a conversa, para a captura conseguir
		# fotografar as duas coisas sem simular caminhada nem tecla.
		if OS.get_cmdline_user_args().has("--olhar-morador"):
			await get_tree().create_timer(2.5).timeout
			_enquadrar_morador()
	elif OS.get_cmdline_user_args().has("--entrar-interior"):
		await get_tree().create_timer(1.5).timeout
		Interiores.entrar(77123, _player.global_transform)
		# Ida e volta na mesma execucao, para a verificacao cobrir os dois lados
		# da transicao. So entrar provaria metade.
		if OS.get_cmdline_user_args().has("--sair-interior"):
			await get_tree().create_timer(4.0).timeout
			Interiores.sair()
	# A captura automatizada precisa do overlay para medir sem depender de tecla.
	if OS.get_cmdline_user_args().has("--debug-info"):
		_mostrar_debug = true
		_hud.visible = true


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
	for arg: String in OS.get_cmdline_user_args():
		if arg in ["--teste-horror", "--teste-casa", "--abrir-inventario",
				"--entrar-interior", "--entrar-casa"] 				or arg.begins_with("--shot=") or arg == "--auto-run" 				or arg == "--auto-walk" or arg.begins_with("--stats="):
			_menu.esconder()
			return


func _novo_jogo() -> void:
	WorldState.limpar()
	Inventario.de_dicionario({"espacos": [], "vida": 100})
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
