## Rota fixa de captura e medida (PLANO_AAA_4K, secao 4.3).
##
## Nasce do `MedidorQuadro` quando a linha de comando tem `--rota=NOME`:
##
##     godot --path game -- --rota=noite_chuva --fog=noite_chuva --chuva=1.0 \
##         --molhado=0.85 --medir=medida.csv --rota-fotos=captures/referencia/moderno
##
## Por que existe. Duas medidas do mesmo jogo, tiradas andando ate um lugar
## parecido, nao se comparam: na Fase 6 da chuva o primeiro A/B foi inconclusivo
## porque cada execucao pegou um carro e uma rua diferentes. Aqui o percurso e
## sempre o mesmo, parada por parada, e cada fase mede o MESMO quadro que a fase
## anterior mediu.
##
## Tres regras que a rota segue, todas aprendidas na marra:
##
## - A camera e PROPRIA e o jogador sai da fisica. Como jogador vivo, um pedestre
##   encosta nele e o enquadramento muda sozinho (memoria "--ir-para nao e
##   regua"). O jogador vai junto so porque o streaming segue ele.
## - Nada e capturado antes de assentar. O chunk monta em thread; a primeira
##   execucao fotografa a cidade pela metade (memoria "primeira execucao nao vale
##   captura").
## - O clima NAO e aplicado aqui: a rota exige as flags e recusa rodar sem elas.
##   Se a rota mexesse em `Settings` por dentro, a linha de comando escrita no
##   relatorio nao reproduziria a medida.
class_name RotaCaptura
extends Node

const ARQUIVO := "res://resources/rotas/cidade.json"
## Quanto tempo, no maximo, esperar o streaming parar de crescer numa parada.
const ESPERA_MAX_S := 8.0
## Quadros seguidos com o mesmo numero de chunks para a parada contar assentada.
const ESTAVEL := 12
## Cao de guarda da rota inteira. Uma execucao de quatro, medida, ficou presa e
## so morreu no `timeout` de 300 s de quem chamou; uma rota que nao termina
## sozinha nao serve para rodar em serie.
const PRAZO_S := 120.0

var medidor: MedidorQuadro

var _nome := ""
var _fotos := ""
var _ficar := false
var _rota: Dictionary = {}
var _jogador: Node3D
var _camera: Camera3D
var _parada_agora := "(nenhuma)"
## `--sem-facho`: esconde o cone de luz somado de poste e farol.
##
## E um interruptor de DIAGNOSTICO, nao um ajuste: a mesma parada com e sem ele
## separa o que e luz de verdade (a onidirecional do poste, o `SpotLight3D` do
## farol) do que e geometria somada por cima. Sem essa separacao, "a luz parece
## um cone" e uma frase sobre duas coisas ao mesmo tempo.
var _sem_facho := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--rota="):
			_nome = arg.trim_prefix("--rota=")
		elif arg.begins_with("--rota-fotos="):
			_fotos = arg.trim_prefix("--rota-fotos=")
		elif arg == "--rota-ficar":
			_ficar = true
		elif arg == "--sem-facho":
			_sem_facho = true
	if _nome.is_empty():
		queue_free()
		return
	_rota = _ler_rota(_nome)
	if _rota.is_empty():
		get_tree().quit(2)
		return
	if not _conferir_flags():
		get_tree().quit(2)
		return
	_executar()


func _ler_rota(nome: String) -> Dictionary:
	var texto := FileAccess.get_file_as_string(ARQUIVO)
	var tudo: Variant = JSON.parse_string(texto)
	if typeof(tudo) != TYPE_DICTIONARY:
		push_error("[rota] %s ilegivel" % ARQUIVO)
		return {}
	var d: Dictionary = tudo
	if not d.has(nome):
		var nomes: Array = []
		for k: String in d.keys():
			if not k.begins_with("_"):
				nomes.append(k)
		push_error("[rota] %s nao existe. Ha: %s" % [nome, ", ".join(nomes)])
		return {}
	return d[nome]


## A rota nao aplica o clima; ela cobra. Uma medida que se reproduz e uma medida
## cuja linha de comando esta inteira no relatorio.
func _conferir_flags() -> bool:
	var pedidas: Array = _rota.get("flags", [])
	var faltando: Array[String] = []
	for f: String in pedidas:
		var chave := f.split("=")[0]
		var tem := false
		for a: String in OS.get_cmdline_user_args():
			if a == chave or a.begins_with(chave + "="):
				tem = true
				break
		if not tem:
			faltando.append(f)
	if faltando.is_empty():
		return true
	print("[rota] faltam flags para a rota %s: %s" % [_nome, " ".join(faltando)])
	print("[rota] linha completa: godot --path game -- --rota=%s %s --medir=medida.csv"
		% [_nome, " ".join(PackedStringArray(pedidas))])
	return false


func _executar() -> void:
	await _esperar_jogador()
	_estacionar()
	_montar_camera()
	_vigiar()
	print("[rota] %s: %d paradas" % [_nome, (_rota.get("paradas", []) as Array).size()])
	var assentar: int = int(_rota.get("assentar", 120))
	var medir: int = int(_rota.get("medir", 180))
	for parada: Dictionary in _rota.get("paradas", []):
		await _parar(parada, assentar, medir)
	print("[rota] fim")
	if not _ficar:
		get_tree().quit(0)


## Mata a execucao se a rota nao terminar no prazo, dizendo em que parada parou.
func _vigiar() -> void:
	var t := get_tree().create_timer(PRAZO_S, true, false, true)
	t.timeout.connect(func() -> void:
		print("[rota] PRAZO estourado (%.0f s) na parada %s; encerrando"
			% [PRAZO_S, _parada_agora])
		get_tree().quit(3))


func _esperar_jogador() -> void:
	while true:
		_jogador = get_tree().get_first_node_in_group(&"player") as Node3D
		if _jogador != null and get_tree().current_scene != null:
			return
		await get_tree().process_frame


## Tira o jogador da fisica sem tira-lo do mundo: o streaming segue ele.
func _estacionar() -> void:
	var corpo := _jogador as CharacterBody3D
	if corpo == null:
		return
	corpo.set_collision_mask_value(1, false)
	corpo.velocity = Vector3.ZERO
	corpo.set_physics_process(false)
	corpo.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING


func _montar_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "CameraDaRota"
	_camera.fov = 70.0
	_camera.near = 0.08
	_camera.far = 400.0
	get_tree().current_scene.add_child(_camera)
	_camera.current = true


func _parar(parada: Dictionary, assentar: int, medir: int) -> void:
	var nome := StringName(parada.get("nome", "?"))
	_parada_agora = String(nome)
	if parada.has("interior"):
		await _entrar_no_interior(parada)
	else:
		var onde := _v3(parada.get("onde", [0, 1.62, 0]))
		var olhar := _v3(parada.get("olhar", [0, 1.62, 1]))
		# O jogador vai ao chao do ponto, e nao a altura do olho: e ele que o
		# streaming segue, e ele cai de 1,6 m toda parada se for junto no alto.
		_jogador.global_position = Vector3(onde.x, 1.0, onde.z)
		_camera.global_position = onde
		_camera.look_at(olhar, Vector3.UP)
	await _assentar(assentar)
	if _sem_facho:
		_esconder_fachos()
	if medidor != null:
		medidor.marcar_parada(nome)
	for i in medir:
		await get_tree().process_frame
	if medidor != null:
		medidor.marcar_parada(&"")
	await _fotografar(String(nome))
	print("[rota] parada %s medida (%d quadros)" % [nome, medir])


func _entrar_no_interior(parada: Dictionary) -> void:
	var interiores := get_node_or_null(^"/root/Interiores")
	if interiores == null:
		push_warning("[rota] sem Interiores; parada de interior pulada")
		return
	interiores.call("entrar", int(parada.get("interior", 0)),
		_jogador.global_transform, &"apartamento", true)
	# A entrada tem cortina e montagem em thread; sem esperar `dentro`, a foto
	# sai da rua.
	var ate := Time.get_ticks_msec() + int(ESPERA_MAX_S * 1000.0)
	while not bool(interiores.get("dentro")) and Time.get_ticks_msec() < ate:
		await get_tree().process_frame
	# Dentro, o chao e o do comodo: a camera segue o jogador, com o rumo escrito
	# na rota (a planta e semeada, entao o rumo vale sempre a mesma parede).
	var olho := float(parada.get("olho", 1.62))
	_camera.global_position = _jogador.global_position + Vector3(0.0, olho, 0.0)
	_camera.global_rotation = Vector3(0.0, deg_to_rad(float(parada.get("rumo", 0.0))), 0.0)


## Esconde todo cone de luz somado que existir agora na arvore.
##
## Depois de assentar, porque chunk novo traz poste novo: adiantar isto so
## esconderia os postes que ja estavam la.
func _esconder_fachos() -> void:
	var n := 0
	for no: Node in _todos(get_tree().current_scene):
		var m := no as MeshInstance3D
		if m == null or not m.name.begins_with("Facho"):
			continue
		m.visible = false
		n += 1
	print("[rota] %d fachos escondidos" % n)


func _todos(raiz: Node) -> Array[Node]:
	var fora: Array[Node] = []
	if raiz == null:
		return fora
	for f: Node in raiz.get_children():
		fora.append(f)
		fora.append_array(_todos(f))
	return fora


## Espera o streaming parar de crescer, e nunca menos que `quadros`.
func _assentar(quadros: int) -> void:
	for i in quadros:
		await get_tree().process_frame
	var cm := get_node_or_null(^"/root/ChunkManager")
	if cm == null:
		return
	var anterior := -1
	var iguais := 0
	var ate := Time.get_ticks_msec() + int(ESPERA_MAX_S * 1000.0)
	while iguais < ESTAVEL and Time.get_ticks_msec() < ate:
		await get_tree().process_frame
		var n := int(cm.call("chunks_carregados"))
		iguais = iguais + 1 if n == anterior else 0
		anterior = n


## A foto sai SEM a HUD, a menos que `--rota-com-hud`.
##
## Nao e estetica: o minimapa e o relogio mudam a cada execucao (22:43 na
## primeira, 22:44 na seguinte), e a regressao visual acusaria diferenca em toda
## captura, sempre, por causa de dois digitos. O pos-processo continua ligado —
## ele nao e HUD, e sem ele a foto nao seria a imagem do jogo.
func _fotografar(nome: String) -> void:
	if _fotos.is_empty():
		return
	# `CanvasItem` e `CanvasLayer` nao tem ancestral comum com `visible`, e o
	# grupo tem dos dois; por isso a propriedade e lida pelo nome.
	var escondidos: Array[Node] = []
	if not OS.get_cmdline_user_args().has("--rota-com-hud"):
		for n: Node in get_tree().get_nodes_in_group(&"hud"):
			if n.get("visible") == true:
				n.set("visible", false)
				escondidos.append(n)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	for n: Node in escondidos:
		n.set("visible", true)
	if img == null:
		push_error("[rota] viewport nao devolveu imagem em %s" % nome)
		return
	if not DirAccess.dir_exists_absolute(_fotos):
		DirAccess.make_dir_recursive_absolute(_fotos)
	var caminho := _fotos.path_join(nome + ".png")
	if img.save_png(caminho) != OK:
		push_error("[rota] falha ao gravar %s" % caminho)
		return
	print("[rota] foto %s (%dx%d)" % [caminho, img.get_width(), img.get_height()])


static func _v3(v: Variant) -> Vector3:
	var a: Array = v
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
