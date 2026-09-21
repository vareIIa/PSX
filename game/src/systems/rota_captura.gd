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
## `--rota-4k=DIR`: alem da foto do tamanho da janela, um PNG de 3840x2160 por
## parada, renderizado pelo `ModoFoto` (PLANO_AAA_4K, A29). A rota e quem sabe
## esperar o streaming assentar, entao a foto grande sai daqui e nao de um
## segundo percurso.
var _quatro_k := ""
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
## `--rota-duas-fotos`: uma segunda foto `<parada>_b.png`, 0,15 s depois.
##
## Serve para medir o que uma imagem parada nao mostra: para que lado uma coisa
## anda. Foi assim que a chuva dentro do facho foi pega subindo. O intervalo e de
## RELOGIO, e nao de quadros: a medida roda sem vsync, e 0,15 s ali sao mais de
## cem quadros, enquanto dez quadros seriam 14 ms e nao moveriam nada visivel.
var _duas_fotos := false
## `--rota-censo`: quem esta desenhando, por classe e por dono, em cada parada.
##
## O medidor diz QUANTAS chamadas de desenho ha; o censo diz DE QUEM. Sem ele,
## "230 chamadas" nao aponta para lugar nenhum, e a Fase 1 do plano (oclusao,
## instanciamento, niveis de detalhe) nao sabe onde mexer.
var _censo := false
## `--rota-sem-vida`: tira transito e multidao antes de cada foto.
##
## E o que a regressao visual usa. Com luz global e sondas de reflexo, um carro
## que passa deixa de ser um detalhe no canto: o farol dele rebate na parede e
## entra na sonda, e duas execucoes da mesma parada passam a diferir em 7 de 255
## sobre 22% dos blocos — medido, e o suficiente para a regressao reprovar sem
## que nada tenha mudado. Quem MEDE desempenho nao usa esta flag: ali o transito
## e parte do custo.
var _sem_vida := false
## `--rota-giro=GRAUS`: quanto a camera gira ENTRE as duas fotos.
##
## E a bancada do criterio A7 (borda estavel). Um giro de fracao de grau muda o
## enquadramento em cerca de um pixel; num renderizador estavel a borda anda
## suave, e num instavel ela PISCA. A medida e a fracao de pixels de borda que
## muda muito entre as duas fotos — com anti-serrilhado e sem.
var _giro := 0.0
const INTERVALO_FOTO_S := 0.15
## Espera do brilho: amostras a cada 250 ms, e tres seguidas com menos de um
## quarto de nivel de diferenca na media da tela. Medido na rota noturna: a
## exposicao terminando de andar mexe a media de 0,3 a 0,8 por amostra, e a
## chuva sozinha fica abaixo de 0,25. Com 0,1 a espera batia no prazo em quase
## toda parada.
const BRILHO_PASSO_MS := 250
const BRILHO_QUIETO := 3
const BRILHO_TOLERANCIA := 0.25
## `--rota-decalques`: quantos decalques de cada familia estao acesos em cada
## parada, e o maior numero num chunk so (criterio A17).
var _decalques := false
## `--rota-goteiras`: pontos de goteira montados e gotas na lente, por parada
## (criterio A18).
var _goteiras := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--rota="):
			_nome = arg.trim_prefix("--rota=")
		elif arg.begins_with("--rota-fotos="):
			_fotos = arg.trim_prefix("--rota-fotos=")
		elif arg.begins_with("--rota-4k="):
			_quatro_k = arg.trim_prefix("--rota-4k=")
		elif arg == "--rota-ficar":
			_ficar = true
		elif arg == "--sem-facho":
			_sem_facho = true
		elif arg == "--rota-duas-fotos":
			_duas_fotos = true
		elif arg == "--rota-censo":
			_censo = true
		elif arg == "--rota-sem-vida":
			_sem_vida = true
		elif arg == "--rota-decalques":
			_decalques = true
		elif arg == "--rota-goteiras":
			_goteiras = true
		elif arg.begins_with("--rota-giro="):
			_giro = arg.trim_prefix("--rota-giro=").to_float()
	if _nome.is_empty():
		queue_free()
		return
	# A rota nao aceita entrada nenhuma. A janela abre na frente de quem esta
	# usando a maquina, e teclas digitadas la caem no jogo: duas execucoes da
	# regressao fotografaram o inventario aberto por cima da cidade, cada uma com
	# um item diferente selecionado. `unfocusable` nao bastou. O que basta e ser
	# o ULTIMO filho da raiz — quem recebe `_input` primeiro — e engolir tudo.
	_ir_para_o_fim.call_deferred()
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
		# As alturas da rota sao ACIMA do chao: o chao sobe e desce com o morro
		# (Relevo). Na praca ele e zero e nada muda.
		onde.y += Relevo.altura(onde.x, onde.z)
		olhar.y += Relevo.altura(olhar.x, olhar.z)
		# O jogador vai ao chao do ponto, e nao a altura do olho: e ele que o
		# streaming segue, e ele cai de 1,6 m toda parada se for junto no alto.
		_jogador.global_position = Vector3(onde.x, 1.0 + Relevo.altura(onde.x, onde.z),
			onde.z)
		_camera.global_position = onde
		_camera.look_at(olhar, Vector3.UP)
	await _assentar(assentar)
	if _sem_vida:
		await _esvaziar_a_rua()
	if _sem_facho:
		_esconder_fachos()
	if medidor != null:
		medidor.marcar_parada(nome)
	for i in medir:
		await get_tree().process_frame
	if medidor != null:
		medidor.marcar_parada(&"")
	if _censo:
		_recensear(String(nome))
	if _decalques:
		_contar_decalques(String(nome))
	if _goteiras:
		var cf := get_node_or_null(^"/root/ChuvaFora")
		if cf != null:
			print("[goteiras] %s: %s" % [nome, cf.call(&"censo")])
	await _fotografar(String(nome))
	if _duas_fotos:
		if not is_zero_approx(_giro):
			_camera.rotate_object_local(Vector3.UP, deg_to_rad(_giro))
		var ate := Time.get_ticks_msec() + int(INTERVALO_FOTO_S * 1000.0)
		while Time.get_ticks_msec() < ate:
			await get_tree().process_frame
		await _fotografar(String(nome) + "_b")
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


## Conta o que esta na arvore, por classe e por dono.
func _recensear(parada: String) -> void:
	var por_classe := {}
	var por_dono := {}
	var tris := {}
	for no: Node in _todos(get_tree().current_scene):
		var c := no.get_class()
		por_classe[c] = int(por_classe.get(c, 0)) + 1
		var mi := no as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		# O dono e o chunk, o prop ou a cena: e a coluna que diz onde mexer.
		var dono := "cena"
		var pai := mi.get_parent()
		if pai != null:
			dono = "chunk" if pai.name.begins_with("chunk_") else pai.name
		por_dono[dono] = int(por_dono.get(dono, 0)) + mi.mesh.get_surface_count()
		# `surface_get_format` so existe em ArrayMesh, e ha QuadMesh na cena.
		var n := 0
		for i in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(i)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var vert: PackedVector3Array = arr[Mesh.ARRAY_VERTEX] if arr[Mesh.ARRAY_VERTEX] != null else PackedVector3Array()
			n += (idx.size() / 3) if not idx.is_empty() else (vert.size() / 3)
		tris[dono] = int(tris.get(dono, 0)) + n
	# So os maiores: a lista inteira sao centenas de nos anonimos e nao se le.
	var donos: Array[String] = []
	donos.assign(por_dono.keys())
	donos.sort_custom(func(a: String, b: String) -> bool:
		return int(tris.get(a, 0)) > int(tris.get(b, 0)))
	var linhas: Array[String] = []
	var resto_malhas := 0
	var resto_tris := 0
	for i in donos.size():
		var k := donos[i]
		if i < 8:
			linhas.append("%s=%d(%dk tri)" % [k, por_dono[k], int(tris[k]) / 1000])
		else:
			resto_malhas += int(por_dono[k])
			resto_tris += int(tris[k])
	linhas.append("outros %d donos=%d(%dk tri)" % [maxi(donos.size() - 8, 0),
		resto_malhas, resto_tris / 1000])
	print("[censo] %s malhas: %s" % [parada, "  ".join(linhas)])
	print("[censo] %s nos: MeshInstance3D=%d MultiMeshInstance3D=%d OmniLight3D=%d SpotLight3D=%d StaticBody3D=%d"
		% [parada, int(por_classe.get("MeshInstance3D", 0)),
			int(por_classe.get("MultiMeshInstance3D", 0)),
			int(por_classe.get("OmniLight3D", 0)),
			int(por_classe.get("SpotLight3D", 0)),
			int(por_classe.get("StaticBody3D", 0))])


func _contar_decalques(parada: String) -> void:
	var dr := get_tree().current_scene.get_node_or_null(^"DecalquesRua")
	if dr == null:
		print("[decalques] %s: sem diretor de decalques (PS1 STYLE ou nivel baixo)" % parada)
		return
	var c: Dictionary = dr.call(&"censo")
	print("[decalques] %s: poca %d, oleo %d, pichacao %d, sujeira %d | maior chunk %s com %d"
		% [parada, int(c["poca"]), int(c["oleo"]), int(c["pichacao"]),
			int(c["sujeira"]), c["chunk_mais_cheio"], int(c["max_por_chunk"])])


## Para e limpa transito e multidao, e espera o quadro seguinte.
func _esvaziar_a_rua() -> void:
	# `Ceu` entra na mesma lista: um relampago no meio de uma captura clareia o
	# quadro inteiro por dois quadros, e duas execucoes da MESMA build nunca
	# cairiam no mesmo. E a versao celeste do carro que passa. `ChuvaFora`
	# tambem: gota na lente cai onde o sorteio quer.
	for caminho: NodePath in [^"/root/Transito", ^"/root/Multidao", ^"/root/Ceu",
			^"/root/ChuvaFora"]:
		var sistema := get_node_or_null(caminho)
		if sistema == null:
			continue
		if sistema.has_method("parar"):
			sistema.call("parar")
		if sistema.has_method("limpar"):
			sistema.call("limpar")
	await get_tree().process_frame
	await get_tree().process_frame


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
	# As sondas de reflexo tambem precisam assentar: elas se refazem uma por
	# quadro, e fotografar no meio disso da duas imagens diferentes da mesma
	# parada.
	var sondas := get_tree().current_scene.get_node_or_null(^"SondasReflexo")
	if sondas != null:
		var ate_sonda := Time.get_ticks_msec() + int(ESPERA_MAX_S * 1000.0)
		while not bool(sondas.call("pronta")) and Time.get_ticks_msec() < ate_sonda:
			await get_tree().process_frame

	# E a exposicao automatica. Ela corre por SEGUNDO, e a rota espera por
	# quadro sem teto de fps: cento e vinte quadros a quinhentos por segundo sao
	# um quarto de segundo, e a foto sairia no meio da rampa — a mesma parada com
	# brilhos diferentes a cada execucao.
	var lente := get_node_or_null(^"/root/Lente")
	if lente != null and lente.has_method("assentada"):
		var ate_lente := Time.get_ticks_msec() + int(ESPERA_MAX_S * 1000.0)
		while not bool(lente.call("assentada")) and Time.get_ticks_msec() < ate_lente:
			await get_tree().process_frame
		await _esperar_brilho_parar()

	# Com a cena parada, as sondas se refazem de novo — agora sobre a imagem
	# final — e a GPU ganha uma dezena de quadros para terminar as seis faces.
	if sondas != null and sondas.has_method("refazer_todas"):
		sondas.call("refazer_todas")
		var ate_de_novo := Time.get_ticks_msec() + int(ESPERA_MAX_S * 1000.0)
		while not bool(sondas.call("pronta")) and Time.get_ticks_msec() < ate_de_novo:
			await get_tree().process_frame
		for i in 12:
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


func _ir_para_o_fim() -> void:
	if not is_inside_tree():
		return
	var raiz := get_tree().root
	# Nasce dentro do medidor, que e o PRIMEIRO autoload — e por isso o ultimo a
	# ver entrada. Muda para a raiz, no fim da fila.
	if get_parent() != raiz:
		reparent(raiz)
	if get_index() != raiz.get_child_count() - 1:
		raiz.move_child(self, -1)
	# A cena principal pode entrar depois; conferido de novo a cada segundo.
	var t := get_tree().create_timer(1.0, true, false, true)
	t.timeout.connect(_ir_para_o_fim)


func _input(event: InputEvent) -> void:
	if _nome.is_empty():
		return
	get_viewport().set_input_as_handled()


## Espera o brilho medio da tela parar de mudar.
##
## "Tres segundos desde o salto" nao bastou: na praca, o clima do lugar e
## forcado DEPOIS do salto, a cena clareia mais tarde, e a exposicao comeca a
## andar atrasada. Duas execucoes da mesma build sairam com brilho diferente e a
## regressao mediu 31% dos blocos diferentes numa parada parada. Perguntar a
## propria imagem nao depende de adivinhar quando a luz mudou.
func _esperar_brilho_parar() -> void:
	var t0 := Time.get_ticks_msec()
	var ate := Time.get_ticks_msec() + int(ESPERA_MAX_S * 1000.0)
	var anterior := -1.0
	var quietas := 0
	while quietas < BRILHO_QUIETO and Time.get_ticks_msec() < ate:
		var espera := Time.get_ticks_msec() + BRILHO_PASSO_MS
		while Time.get_ticks_msec() < espera:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img == null:
			continue
		img.resize(64, 36, Image.INTERPOLATE_BILINEAR)
		var soma := 0.0
		for y in img.get_height():
			for x in img.get_width():
				soma += img.get_pixel(x, y).get_luminance()
		var media := soma / float(img.get_width() * img.get_height()) * 255.0
		quietas = quietas + 1 if absf(media - anterior) < BRILHO_TOLERANCIA else 0
		anterior = media
	print("[rota] brilho assentou em %.1f s%s" % [
		float(Time.get_ticks_msec() - t0) / 1000.0,
		"" if quietas >= BRILHO_QUIETO else " (prazo, sem assentar)"])


## A foto sai SEM a HUD, a menos que `--rota-com-hud`.
##
## Nao e estetica: o minimapa e o relogio mudam a cada execucao (22:43 na
## primeira, 22:44 na seguinte), e a regressao visual acusaria diferenca em toda
## captura, sempre, por causa de dois digitos. O pos-processo continua ligado —
## ele nao e HUD, e sem ele a foto nao seria a imagem do jogo.
func _fotografar(nome: String) -> void:
	# A foto de 4K primeiro, e fora do `if`: ela nao depende de `--rota-fotos`,
	# e quem pede so a grande nao quer ser obrigado a gravar a pequena.
	await _fotografar_4k(nome)
	if _fotos.is_empty():
		return
	var lente := get_node_or_null(^"/root/Lente")
	if lente != null and lente.has_method("forca_do_desfoque"):
		print("[rota] %s: camera a %.2f m/s, obturador %.3f" % [nome,
			float(lente.call("velocidade")), float(lente.call("forca_do_desfoque"))])
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


func _fotografar_4k(nome: String) -> void:
	if _quatro_k.is_empty():
		return
	var foto := get_node_or_null(^"/root/Foto")
	if foto == null or not foto.has_method("fotografar_camera"):
		return
	var escondidos: Array[Node] = []
	for n: Node in get_tree().get_nodes_in_group(&"hud"):
		if n.get("visible") == true:
			n.set("visible", false)
			escondidos.append(n)
	await foto.call(&"fotografar_camera", _camera, _quatro_k, nome + "_4k")
	for n: Node in escondidos:
		n.set("visible", true)


static func _v3(v: Variant) -> Vector3:
	var a: Array = v
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
