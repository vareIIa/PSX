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

	if _frames < _target_frame:
		return
	_done = true

	if _target_path.is_empty():
		# Medicao sem captura: nada a gravar, so encerrar no frame combinado.
		_finish(0)
		return
	_capture()


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
