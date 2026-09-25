## Quem gasta a thread principal na cidade: "todos menos um" por classe de no.
##
##     godot --path game --resolution 3840x2160 res://tests/bancada_censo_cpu.tscn -- --pular-menu --estilo=moderno
##     ... -- --no-carro       sentado ao volante, parado (padrao: a pe)
##     ... -- --janela=1.5     segundos de cada medida (padrao 1.5)
##     ... -- --top=18         quantas classes medir (padrao 18)
##
## Parado, o quadro da cidade dura mais que a GPU (10 ms contra 6,4 medidos em
## 24/09/2026): o gargalo ja e a CPU antes de o carro andar. O `Performance`
## nao ajuda — TIME_PROCESS e o MAXIMO do ultimo segundo, nao o do quadro.
##
## Aqui cada classe com script que processa (as de mais instancias e os
## autoloads) sai do laco por um intervalo (`PROCESS_MODE_DISABLED`, que leva a
## subarvore junto) e volta. Cada medida sem a classe fica ENTRE duas medidas
## com ela, e a diferenca e contra a media das duas: a linha de base anda.
## Vsync desligado aqui mesmo, senao a medida e do monitor.
##
## Imprime `[censo] chave=valor`.
extends Node

var _no_carro := false
var _janela := 1.5
var _top := 18

var _gravando := false
var _quadros := PackedFloat32Array()


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--no-carro":
			_no_carro = true
		elif arg.begins_with("--janela="):
			_janela = arg.trim_prefix("--janela=").to_float()
		elif arg.begins_with("--top="):
			_top = arg.trim_prefix("--top=").to_int()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cidade: Node = (load("res://scenes/test/cidade.tscn") as PackedScene).instantiate()
	add_child(cidade)
	_rodar(cidade)


func _relatar(chave: String, valor: Variant) -> void:
	print("[censo] %s=%s" % [chave, valor])


func _process(delta: float) -> void:
	if _gravando:
		_quadros.append(delta * 1000.0)


func _medir() -> float:
	_quadros.clear()
	# Dois quadros de folga: o que mudou agora aparece no delta seguinte.
	await get_tree().process_frame
	await get_tree().process_frame
	_gravando = true
	await get_tree().create_timer(_janela).timeout
	_gravando = false
	var s := _quadros.duplicate()
	s.sort()
	return s[s.size() / 2] if not s.is_empty() else 0.0


func _rodar(cidade: Node) -> void:
	var arvore := get_tree()
	var jogador: Node3D = null
	while jogador == null:
		await arvore.physics_frame
		jogador = arvore.get_first_node_in_group(&"player") as Node3D
	# O mesmo ponto da bancada de dirigir: avenida x = -160, z = 100.
	var x := -5 * MalhaUrbana.TAM + MalhaUrbana.meia_pista(MalhaUrbana.Via.AVENIDA) * 0.5
	if _no_carro:
		while Transito.raiz == null:
			await arvore.physics_frame
		var c := Carro.new()
		c.preparar({}, Vector2i.ZERO, Vector4i.ZERO, 4242)
		c.modelo = Carroceria.Modelo.HATCH
		Transito.raiz.add_child(c)
		c.pousar(Vector3(x, Relevo.altura(x, 100.0) + 0.6, 100.0), 0.0)
		Transito.registrar_estacionado(c)
		jogador.global_position = c.global_position + Vector3(-2.2, 0.3, 0.0)
		await arvore.create_timer(1.0).timeout
		jogador.call("entrar_no_veiculo_mais_perto")
		c.pilotar(0.0, 1.0, 0.0)
	else:
		jogador.global_position = Vector3(x - 2.25, Relevo.altura(x, 100.0) + 0.3, 100.0)
	await arvore.create_timer(8.0).timeout
	_relatar("placa", RenderingServer.get_video_adapter_name())
	_relatar("lugar", "no carro" if _no_carro else "a pe")

	# Censo: quem processa, agrupado pela classe do script.
	var grupos := {}
	var pilha: Array[Node] = [arvore.root]
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		for f: Node in no.get_children():
			pilha.append(f)
		if no == self or no == arvore.root:
			continue
		var s := no.get_script() as Script
		if s == null:
			continue
		if not (no.is_processing() or no.is_physics_processing()):
			continue
		var nome := s.get_global_name()
		if nome == &"":
			nome = StringName(s.resource_path.get_file().get_basename())
		# Autoload fica com o nome dele: e o custo de UM sistema.
		if no.get_parent() == arvore.root:
			nome = StringName("@" + no.name)
		var lista: Array = grupos.get(nome, [])
		lista.append(no)
		grupos[nome] = lista
	var nomes := grupos.keys()
	nomes.sort_custom(func(a: StringName, b: StringName) -> bool:
		var aa := String(a).begins_with("@")
		var bb := String(b).begins_with("@")
		if aa != bb:
			return aa
		return (grupos[a] as Array).size() > (grupos[b] as Array).size())
	var resumo := PackedStringArray()
	for n: StringName in nomes:
		resumo.append("%s:%d" % [n, (grupos[n] as Array).size()])
	_relatar("processando", ", ".join(resumo))
	_relatar("nos_total", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

	# Os autoloads todos (nao sao muitos) e as classes de mais instancias.
	var medir: Array[StringName] = []
	var classes := 0
	for n: StringName in nomes:
		if String(n).begins_with("@"):
			if n in [&"@Medidor", &"@Settings"]:
				continue
			medir.append(n)
		elif classes < _top:
			medir.append(n)
			classes += 1

	var antes := await _medir()
	_relatar("base_ms", "%.2f" % antes)
	var linhas: Array[String] = []
	for n: StringName in medir:
		var nos: Array = grupos[n]
		# Sem tipo no laco: pedestre e carro somem no meio da medida, e atribuir
		# instancia liberada a uma variavel tipada e erro.
		var modos: Array[int] = []
		for v: Variant in nos:
			if is_instance_valid(v):
				modos.append((v as Node).process_mode)
				(v as Node).process_mode = Node.PROCESS_MODE_DISABLED
			else:
				modos.append(-1)
		var sem := await _medir()
		for i in nos.size():
			var v: Variant = nos[i]
			if is_instance_valid(v) and modos[i] >= 0:
				(v as Node).process_mode = modos[i]
		var depois := await _medir()
		var base := (antes + depois) * 0.5
		linhas.append("%7.2f ms  %-28s n=%-4d base=%.2f sem=%.2f" % [
			base - sem, n, nos.size(), base, sem])
		antes = depois
	linhas.sort()
	linhas.reverse()
	for l: String in linhas:
		print("[censo] ganho ", l)
	arvore.quit(0)
