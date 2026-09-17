## Autoload. Captura automatizada de tela para validar o look sem olho humano
## no loop.
##
## Existe porque `--headless` nao compila shader: o unico jeito de provar que o
## psx_surface e o post_psx funcionam de verdade e abrir uma janela, renderizar
## alguns frames e gravar o resultado. E o nivel 3 de validacao descrito em
## docs/PADROES-ENGENHARIA.md.
##
##     godot --path game -- --shot=out.png --shot-frame=30 --shot-quit
##
## `--shot-frame` conta frames de FISICA, nao de render. A fisica roda em passo
## fixo de 60 Hz, entao o frame 60 e sempre 1,0 s de simulacao, independente da
## velocidade da maquina. Sem isso nada que se anima no tempo, como o piscar dos
## postes, sairia igual em duas capturas seguidas.
extends Node

const DEFAULT_FRAME := 30

## Quantos quadros de fisica antes da captura o mouse se move e clica.
##
## Eram 8 e 5, e isso mediu errado uma tela inteira: a captura saia 83 ms depois
## do clique, e a cascata de entrada do menu leva meio segundo. A tela aparecia
## vazia, e a conclusao natural — e falsa — era que o clique nao tinha
## funcionado. Cinquenta quadros dao 0,83 s, que cobre toda animacao de interface
## deste projeto (a mais longa e a cortina do titulo, 0,85 s, e ela nao entra nos
## caminhos que se clica).
##
## O intervalo entre mover e clicar continua curto: `mouse_entered` dispara no
## quadro seguinte ao movimento, e cinco quadros bastam para o hover assentar.
const ANTES_MOUSE := 50
const ANTES_CLIQUE := 45
## Deslocamento no plano abaixo do qual a amostra conta como travamento.
const LIMITE_TRAVADO := 0.5

var _target_path: String = ""
var _target_frame: int = DEFAULT_FRAME
var _quit_after: bool = false
## Passo de amostragem do nivel das lampadas, em frames de fisica. Zero desliga.
var _sample_step: int = 0
## Passo do relatorio de desempenho, em frames de fisica. Zero desliga.
var _stats_step: int = 0
var _pior_frame: float = 0.0
var _frames: int = 0
var _done: bool = false
## Onde o jogador estava no relatorio anterior. Serve para detectar
## travamento entre duas amostras, que e o unico defeito de rua que a
## medida de distancia acusa sem dizer a causa.
var _pos_anterior := Vector3.INF
## Onde por o ponteiro antes da captura, em coordenada de interface. Ver
## `_mover_mouse`. `INF` quer dizer "nao mexe no mouse".
var _mouse_em := Vector2.INF
var _clicar: bool = false
## Onde o ponteiro foi parar, em pixel de JANELA. Guardado porque
## `Window.get_mouse_position()` nao acompanha `warp_mouse` no mesmo quadro — e
## clicar na coordenada errada e o mesmo que nao clicar, so que em silencio.
var _mouse_janela := Vector2.ZERO
## Botoes de controle a apertar antes da captura, em ordem. Ver `_apertar_botao`.
var _botoes: PackedInt32Array = []
## Segunda foto, tirada no quadro DESENHADO seguinte ao da primeira.
##
## Existe para medir o que um quadro so nao mostra: se uma animacao anda ou
## PISCA. "A agua no vidro e uma foto piscando" nao se prova com uma imagem —
## prova-se com a diferenca entre duas seguidas: quanto do vidro muda, e quanto.
var _segunda: String = ""
## Quadros de fisica entre dois botoes da sequencia. Um aperto por quadro leria
## como um botao so segurado; seis quadros (0,1 s) e o ritmo de um polegar.
const INTERVALO_BOTAO := 6


func _ready() -> void:
	# Imune a pausa: a prancha de inventario pausa a arvore, e uma captura que
	# para junto nunca dispara e a execucao fica presa para sempre.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args(OS.get_cmdline_user_args())
	set_process(_stats_step > 0)
	if _target_path.is_empty() and _stats_step == 0:
		set_physics_process(false)
		return
	print("[capture] gravando %s no frame de fisica %d" % [_target_path, _target_frame])


func _parse_args(args: PackedStringArray) -> void:
	for arg: String in args:
		if arg.begins_with("--shot="):
			_target_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--shot-frame="):
			_target_frame = maxi(1, arg.trim_prefix("--shot-frame=").to_int())
		elif arg == "--shot-quit":
			_quit_after = true
		elif arg.begins_with("--sample="):
			_sample_step = maxi(1, arg.trim_prefix("--sample=").to_int())
		elif arg.begins_with("--stats="):
			_stats_step = maxi(1, arg.trim_prefix("--stats=").to_int())
		elif arg.begins_with("--mouse="):
			var xy := arg.trim_prefix("--mouse=").split(",")
			if xy.size() == 2:
				_mouse_em = Vector2(xy[0].to_float(), xy[1].to_float())
		elif arg == "--clique":
			_clicar = true
		elif arg.begins_with("--shot-seguinte="):
			_segunda = arg.trim_prefix("--shot-seguinte=")
		elif arg.begins_with("--botoes="):
			for b: String in arg.trim_prefix("--botoes=").split(",", false):
				_botoes.append(b.to_int())


## O pior frame de render entre dois relatorios. E o numero que diz se houve
## engasgo; a media de fps nao diz.
func _process(delta: float) -> void:
	_pior_frame = maxf(_pior_frame, delta)


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frames += 1

	if _sample_step > 0 and _frames % _sample_step == 0:
		for l: Node in get_tree().get_nodes_in_group(&"lampada"):
			print("[amostra] %d %s %.3f" % [_frames, l.name, l.nivel])

	if _stats_step > 0 and _frames % _stats_step == 0:
		_relatar()

	# O mouse entra em cena ANTES da captura, e nao no mesmo quadro.
	#
	# Sem isto nao ha como provar que uma tela clicavel responde ao clique: a
	# captura fotografa o que o teclado fez, e o caminho do mouse — que e outro
	# caminho de codigo inteiro, com `mouse_entered`, `gui_input` e a conversao
	# de coordenada da `CanvasLayer` no meio — nunca e exercitado por ninguem.
	# O menu de titulo passou a existencia inteira assim, e a carteira tambem.
	#
	# Dois quadros de intervalo entre mover e clicar porque `mouse_entered` so
	# dispara no processamento do quadro seguinte ao movimento; clicar junto
	# acionaria o item que estava escolhido antes.
	if _mouse_em != Vector2.INF and _frames == maxi(1, _target_frame - ANTES_MOUSE):
		_mover_mouse()
	if _clicar and _frames == maxi(2, _target_frame - ANTES_CLIQUE):
		_disparar_clique()
	# Os botoes terminam onde o clique terminaria, e comecam tanto antes quanto a
	# sequencia pede: o ultimo aperto ainda tem os 45 quadros da animacao pela
	# frente, como o clique tem.
	if not _botoes.is_empty():
		var inicio := _target_frame - ANTES_CLIQUE - (_botoes.size() - 1) * INTERVALO_BOTAO
		var passo := _frames - maxi(2, inicio)
		if passo >= 0 and passo % INTERVALO_BOTAO == 0:
			var i := passo / INTERVALO_BOTAO
			if i < _botoes.size():
				_apertar_botao(_botoes[i])

	if _frames < _target_frame:
		return
	_done = true

	if _target_path.is_empty():
		# Medicao sem captura: nada a gravar, so encerrar no frame combinado.
		_finish(0)
		return
	_capture()


## Poe o ponteiro numa coordenada da INTERFACE (480x270), e nao da janela.
##
## A captura roda em 1280x720 ou 1920x1080 conforme quem chama, e o alvo do
## clique e um retangulo escrito em coordenada de interface. Converter aqui, uma
## vez, e o que deixa a mesma linha de comando valer em qualquer resolucao.
func _mover_mouse() -> void:
	var janela := get_window()
	if janela == null:
		return
	var escala := Vector2(janela.size) / UiEstilo.TELA
	var alvo := _mouse_em * minf(escala.x, escala.y)
	# Pillarbox: o `aspect = keep` centraliza a area util quando a janela nao e
	# 16:9, e o ponteiro tem de cair no mesmo lugar que a interface desenha.
	alvo += (Vector2(janela.size) - UiEstilo.TELA * minf(escala.x, escala.y)) * 0.5
	_mouse_janela = alvo
	Input.warp_mouse(alvo)
	var ev := InputEventMouseMotion.new()
	ev.position = alvo
	ev.global_position = alvo
	Input.parse_input_event(ev)
	print("[capture] mouse em %.0f,%.0f da interface (%.0f,%.0f na janela)"
		% [_mouse_em.x, _mouse_em.y, alvo.x, alvo.y])


func _disparar_clique() -> void:
	var pos := _mouse_janela
	for apertado: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = apertado
		ev.position = pos
		ev.global_position = pos
		Input.parse_input_event(ev)
	print("[capture] clique em %.0f,%.0f" % [pos.x, pos.y])


## Aperta e solta um botao de controle, como um polegar faria.
##
## Existe pelo mesmo motivo do clique: o caminho do joypad e outro caminho de
## codigo, e ate `Controle` existir ele nao era exercitado por ninguem — o mapa
## de entrada nao tinha uma ligacao de controle sequer.
func _apertar_botao(indice: int) -> void:
	for apertado: bool in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = indice as JoyButton
		ev.pressed = apertado
		ev.pressure = 1.0 if apertado else 0.0
		ev.device = 0
		Input.parse_input_event(ev)
	print("[capture] botao %d do controle" % indice)


func _relatar() -> void:
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	var pos := jogador.global_position if jogador != null else Vector3.ZERO
	# A direcao entra no relatorio porque so a posicao nao diz o que esta no
	# quadro. Sem ela, conferir uma captura de interior vira adivinhacao sobre
	# qual parede e qual.
	var frente := Vector3.ZERO
	if jogador != null:
		frente = -jogador.global_transform.basis.z
	print("[stats] frame=%d x=%.1f y=%.1f z=%.1f dentro=%d pior_ms=%.1f fps=%d chunks=%d tris=%d mem=%.1f nos=%d portas=%d olhar=%.2f,%.2f"
		% [_frames, pos.x, pos.y, pos.z, 1 if Interiores.dentro else 0, _pior_frame * 1000.0,
			Engine.get_frames_per_second(),
			ChunkManager.chunks_carregados(), ChunkManager.tris_carregados,
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			get_tree().get_nodes_in_group(&"porta").size(), frente.x, frente.z])
	_pior_frame = 0.0
	_denunciar_travamento(jogador, pos)


## Quem esta segurando o jogador.
##
## A distancia percorrida acusa que ele parou, e nao por que. Sem esta linha a
## investigacao vira palpite — foi assim que um terco da calcada ficou bloqueada
## por colisao de predio invisivel desde a Fase 3, sem nenhum teste apontar o no.
## Custa nada: so imprime quando ha travamento de verdade.
func _denunciar_travamento(jogador: Node3D, pos: Vector3) -> void:
	var antes := _pos_anterior
	_pos_anterior = pos
	if antes == Vector3.INF or Interiores.dentro:
		return
	# Andando, mesmo devagar, a janela de amostra cobre metros. Meio metro em
	# dois segundos so acontece parado ou empurrando alguma coisa.
	var andou := Vector2(pos.x - antes.x, pos.z - antes.z).length()
	if andou > LIMITE_TRAVADO:
		return
	var corpo := jogador as CharacterBody3D
	if corpo == null:
		return
	print("[travado] frame=%d andou=%.2f pos=%.1f,%.1f colisoes=%d"
		% [_frames, andou, pos.x, pos.z, corpo.get_slide_collision_count()])
	for i in corpo.get_slide_collision_count():
		var bat := corpo.get_slide_collision(i)
		var col: Object = bat.get_collider()
		if col == null:
			continue
		var n := col as Node3D
		var normal := bat.get_normal()
		print("[travado]   no=%s classe=%s em=%.1f,%.1f,%.1f normal=%.2f,%.2f,%.2f"
			% [n.name if n != null else "?", col.get_class(),
				n.global_position.x if n != null else 0.0,
				n.global_position.y if n != null else 0.0,
				n.global_position.z if n != null else 0.0,
				normal.x, normal.y, normal.z])


func _capture() -> void:
	# Espera o fim do desenho do frame corrente, senao a textura vem do anterior.
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_error("[capture] viewport nao devolveu imagem")
		_finish(1)
		return

	var dir := _target_path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	var err := image.save_png(_target_path)
	if err != OK:
		push_error("[capture] falha ao gravar %s (erro %d)" % [_target_path, err])
		_finish(1)
		return

	print("[capture] ok %s (%dx%d)" % [_target_path, image.get_width(), image.get_height()])
	if not _segunda.is_empty():
		await RenderingServer.frame_post_draw
		var outra := get_viewport().get_texture().get_image()
		if outra != null and outra.save_png(_segunda) == OK:
			print("[capture] ok %s (quadro seguinte)" % _segunda)
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador != null:
		print("[capture] jogador em %.2f, %.2f, %.2f"
			% [jogador.global_position.x, jogador.global_position.y, jogador.global_position.z])
	for l: Node in get_tree().get_nodes_in_group(&"lampada"):
		print("[lampada] %s %.3f" % [l.name, l.nivel])

	_finish(0)


func _finish(code: int) -> void:
	if _quit_after:
		get_tree().quit(code)
