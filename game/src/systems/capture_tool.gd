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
	print("[stats] frame=%d x=%.1f y=%.1f z=%.1f dentro=%d pior_ms=%.1f fps=%d chunks=%d tris=%d mem=%.1f nos=%d portas=%d"
		% [_frames, pos.x, pos.y, pos.z, 1 if Interiores.dentro else 0, _pior_frame * 1000.0,
			Engine.get_frames_per_second(),
			ChunkManager.chunks_carregados(), ChunkManager.tris_carregados,
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			get_tree().get_nodes_in_group(&"porta").size()])
	_pior_frame = 0.0


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
