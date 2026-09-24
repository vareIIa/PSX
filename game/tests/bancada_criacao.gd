## Bancada da criacao de personagem: roupa, rosto e reacao fora da tela.
##
##     godot --path game --resolution 1280x720 --script res://tests/bancada_criacao.gd -- --saida=DIR
##
## A tela de criacao mostra UMA pessoa num retrato de 104 px, uma peca de cada
## vez. Julgar forma de roupa assim e olhar por um buraco de fechadura: a gola
## da social e o capuz do moletom so se comparam lado a lado, grandes, com a
## mesma luz. Esta bancada monta a fileira inteira num SubViewport proprio e
## fotografa.
##
## Tres fotos:
##   roupas.png   oito corpos inteiros, cada um com um conjunto de modelos
##   rostos.png   os dezesseis rostos de estudio, com barba e oculos variados
##   reacoes.png  cada reacao no pico, para conferir onde a mao chegou
extends SceneTree

const TAMANHO := Vector2i(1600, 720)

var _saida := ""
var _so := ""
var _cor_por_osso := false
var _vp: SubViewport


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
		elif arg.begins_with("--so="):
			_so = arg.trim_prefix("--so=")
		elif arg == "--cor-por-osso":
			_cor_por_osso = true
	_rodar()


func _base(sexo: StringName, id: int) -> Dictionary:
	return Aparencia.de_ficha({"id": id, "sexo": sexo, "idade": 31})


func _montar_palco() -> Node3D:
	_vp = SubViewport.new()
	_vp.size = TAMANHO
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var mundo := Node3D.new()
	_vp.add_child(mundo)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("4d5761")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8e8c80")
	env.ambient_light_energy = 1.05
	ambiente.environment = env
	mundo.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	luz.light_energy = 1.45
	luz.rotation = Vector3(deg_to_rad(-22.0), deg_to_rad(-150.0), 0.0)
	mundo.add_child(luz)
	return mundo


func _camera(mundo: Node3D, pos: Vector3, alvo: Vector3, fov: float) -> void:
	var cam := Camera3D.new()
	cam.fov = fov
	cam.near = 0.05
	mundo.add_child(cam)
	cam.position = pos
	cam.look_at(alvo, Vector3.UP)
	cam.current = true


func _corpo(mundo: Node3D, a: Dictionary, x: float, perto: bool = true) -> Corpo:
	var c := Corpo.new()
	c.detalhado = perto
	mundo.add_child(c)
	c.montar(a)
	c.position = Vector3(x, 0.0, 0.0)
	c.animar(0.0, 0.016)
	if _cor_por_osso:
		_pintar_por_osso(c)
	return c


## Diagnostico: cada vertice na cor do osso de maior peso. Uma ponta na malha
## diz de quem ela e sem precisar adivinhar.
const CORES_OSSO := [Color.WHITE, Color.GREEN, Color.YELLOW, Color.RED, Color.ORANGE,
	Color.BLUE, Color.CYAN, Color.MAGENTA, Color.PURPLE, Color.BROWN, Color.PINK]


func _pintar_por_osso(c: Corpo) -> void:
	for filho in c.esqueleto().get_children():
		var m := filho as MeshInstance3D
		if m == null:
			continue
		var arr := m.mesh.surface_get_arrays(0)
		var os: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var ps: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var cs: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		for k in cs.size():
			var o := os[k * 4] if ps[k * 4] >= ps[k * 4 + 1] else os[k * 4 + 1]
			cs[k] = CORES_OSSO[o % CORES_OSSO.size()]
		arr[Mesh.ARRAY_COLOR] = cs
		var novo := ArrayMesh.new()
		novo.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		m.mesh = novo


func _foto(nome: String) -> void:
	for i in 6:
		await process_frame
	var img := _vp.get_texture().get_image()
	if _saida != "":
		DirAccess.make_dir_recursive_absolute(_saida)
		img.save_png(_saida.path_join(nome))
		print("foto ", _saida.path_join(nome))


func _limpar(mundo: Node3D) -> void:
	for filho in mundo.get_children():
		if filho is Corpo or filho is Camera3D:
			filho.queue_free()
	await process_frame


## Cinco corpulencias, com e sem agasalho, e as maos de perto.
##
## O gordo e onde a caixa rigida mais mente: o braco pendurado no ombro cai
## DENTRO da barriga, e isso so se ve de tres quartos. Por isso tres vistas.
func _fotos_de_corpos(mundo: Node3D) -> void:
	var gorduras := [0.0, 0.25, 0.5, 0.75, 1.0]
	for vista: Array in [["corpos_frente.png", 0.0], ["corpos_lado.png", PI * 0.5],
			["corpos_tres_quartos.png", 0.7]]:
		for i in 10:
			var sexo: StringName = &"M" if i < 5 else &"F"
			var base := _base(sexo, 120 + i)
			var aj := Aparencia.ajustes_de(base)
			aj[&"gordura"] = gorduras[i % 5]
			aj[&"altura"] = 1.74 if sexo == &"M" else 1.64
			aj[&"rosto"] = 8 + i % 8
			aj[&"chapeu_tipo"] = 0
			aj[&"oculos"] = 0
			aj[&"casaco_estilo"] = 0
			aj[&"camisa_estilo"] = 0 if i % 2 == 0 else 1
			aj[&"camisa_cor"] = Aparencia.ROUPAS[10 - i % 3]
			aj[&"calca_cor"] = Aparencia.CALCAS[1 + i % 4]
			var c := _corpo(mundo, Aparencia.com_ajustes(base, aj),
				(float(i) - 4.5) * 0.78, i % 5 != 4)
			c.rotation.y = float(vista[1])
		_camera(mundo, Vector3(0.0, 0.95, -9.4), Vector3(0.0, 0.90, 0.0), 30.0)
		await _foto(String(vista[0]))
		await _limpar(mundo)
	# Maos e bracos de perto: o gordo e o magro, a tres quartos.
	for i in 2:
		var base := _base(&"M", 140 + i)
		var aj := Aparencia.ajustes_de(base)
		aj[&"gordura"] = 1.0 if i == 0 else 0.1
		aj[&"casaco_estilo"] = 0
		aj[&"camisa_estilo"] = 1
		aj[&"chapeu_tipo"] = 0
		var c := _corpo(mundo, Aparencia.com_ajustes(base, aj), (float(i) - 0.5) * 0.9)
		c.rotation.y = 0.6
	_camera(mundo, Vector3(0.0, 1.05, -2.6), Vector3(0.0, 1.0, 0.0), 32.0)
	await _foto("corpos_maos.png")
	await _limpar(mundo)
	# Gordo e gorda, de lado e de tres quartos, grandes: a barriga, a barra da
	# camisa sobre o cinto e o braco passando por fora.
	for i in 4:
		var sexo: StringName = &"M" if i < 2 else &"F"
		var base := _base(sexo, 150 + i)
		var aj := Aparencia.ajustes_de(base)
		aj[&"gordura"] = 1.0
		aj[&"casaco_estilo"] = 0
		aj[&"camisa_estilo"] = 0
		aj[&"calca_estilo"] = 0
		aj[&"chapeu_tipo"] = 0
		aj[&"camisa_cor"] = Aparencia.ROUPAS[10]
		aj[&"calca_cor"] = Aparencia.CALCAS[2]
		var c := _corpo(mundo, Aparencia.com_ajustes(base, aj), (float(i) - 1.5) * 0.85)
		c.rotation.y = PI * 0.5 if i % 2 == 0 else 0.7
	_camera(mundo, Vector3(0.0, 1.0, -4.2), Vector3(0.0, 0.92, 0.0), 32.0)
	await _foto("corpos_gordos.png")
	await _limpar(mundo)
	# De jaqueta, parada e no pico de cada reacao de braco: o ombro e o que mais
	# sofre quando o braco sobe com a manga por cima.
	var tipos := [ReacaoCorpo.NENHUMA, ReacaoCorpo.ROUPA, ReacaoCorpo.ROSTO,
		ReacaoCorpo.CHAPEU]
	for i in tipos.size():
		var base := _base(&"F", 160)
		var aj := Aparencia.ajustes_de(base)
		aj[&"gordura"] = 1.0
		aj[&"casaco_estilo"] = 1
		aj[&"chapeu_tipo"] = 0
		aj[&"casaco_cor"] = Aparencia.ROUPAS[11]
		var c := _corpo(mundo, Aparencia.com_ajustes(base, aj), (float(i) - 1.5) * 0.8)
		if int(tipos[i]) != ReacaoCorpo.NENHUMA:
			c.reagir(int(tipos[i]))
			c.animar(0.0, ReacaoCorpo.duracao(int(tipos[i])) * 0.45)
	_camera(mundo, Vector3(0.0, 1.25, -3.2), Vector3(0.0, 1.2, 0.0), 32.0)
	await _foto("corpos_ombro.png")
	await _limpar(mundo)
	# A mesma reacao de ROUPA de quatro lados.
	for i in 4:
		var base := _base(&"F", 160)
		var aj := Aparencia.ajustes_de(base)
		aj[&"gordura"] = 1.0
		aj[&"casaco_estilo"] = 1
		aj[&"chapeu_tipo"] = 0
		aj[&"casaco_cor"] = Aparencia.ROUPAS[11]
		var c := _corpo(mundo, Aparencia.com_ajustes(base, aj), (float(i) - 1.5) * 0.8)
		c.rotation.y = [0.0, 0.8, PI * 0.5, PI][i]
		c.reagir(ReacaoCorpo.ROUPA)
		c.animar(0.0, ReacaoCorpo.duracao(ReacaoCorpo.ROUPA) * 0.45)
	_camera(mundo, Vector3(0.0, 1.25, -3.2), Vector3(0.0, 1.2, 0.0), 32.0)
	await _foto("corpos_ombro_roupa.png")
	await _limpar(mundo)
	# Dobras grandes: joelho e cotovelo com a pele dividida entre dois ossos.
	# Andando em tres fases, sentado e dirigindo, de lado.
	var estados := [["andar", 0.0], ["andar", 0.35], ["andar", 0.7],
		["assento", 0.0], ["dirigindo", 0.0]]
	for i in estados.size():
		var base := _base(&"M", 170 + i)
		var aj := Aparencia.ajustes_de(base)
		aj[&"gordura"] = 0.75
		aj[&"casaco_estilo"] = 0
		aj[&"chapeu_tipo"] = 0
		var c := _corpo(mundo, Aparencia.com_ajustes(base, aj), (float(i) - 2.0) * 0.9)
		c.rotation.y = PI * 0.5
		match String(estados[i][0]):
			"andar":
				c.animar(1.4, float(estados[i][1]) * 1.6)
			"assento":
				c.postura(Corpo.Postura.ASSENTO)
				c.animar(0.0, 0.1)
			"dirigindo":
				c.postura(Corpo.Postura.DIRIGINDO)
				c.animar(0.0, 0.1)
	_camera(mundo, Vector3(0.0, 0.9, -5.2), Vector3(0.0, 0.8, 0.0), 32.0)
	await _foto("corpos_dobras.png")
	await _limpar(mundo)
	await _fotos_de_roupa_andando(mundo)


## Roupa no meio do passo, com a fisica de pano ja rodando: saia, saia longa,
## sobretudo, barriga e camisa social por dentro. De lado e de tres quartos.
func _fotos_de_roupa_andando(mundo: Node3D) -> void:
	var trajes := [
		{"sexo": &"F", "calca_estilo": 4, "gordura": 0.3},
		{"sexo": &"F", "calca_estilo": 5, "gordura": 0.5},
		{"sexo": &"M", "casaco_estilo": 3, "gordura": 0.4},
		{"sexo": &"M", "camisa_estilo": 0, "gordura": 1.0},
		{"sexo": &"M", "camisa_estilo": 2, "gordura": 0.6},
	]
	for vista: Array in [["roupa_andando_lado.png", PI * 0.5],
			["roupa_andando_tres_quartos.png", 0.7]]:
		var corpos: Array[Corpo] = []
		for i in trajes.size():
			var t: Dictionary = trajes[i]
			var base := _base(t["sexo"], 190 + i)
			var aj := Aparencia.ajustes_de(base)
			aj[&"casaco_estilo"] = 0
			aj[&"chapeu_tipo"] = 0
			for k: String in t:
				if k != "sexo":
					aj[StringName(k)] = t[k]
			aj[&"camisa_cor"] = Aparencia.ROUPAS[10 - i % 3]
			aj[&"casaco_cor"] = Aparencia.ROUPAS[5]
			aj[&"calca_cor"] = Aparencia.CALCAS[1 + i % 5]
			var c := _corpo(mundo, Aparencia.com_ajustes(base, aj), (float(i) - 2.0) * 0.9)
			c.rotation.y = float(vista[1])
			corpos.append(c)
		# Meio segundo de passo, com o corpo andando de verdade para a mola ver
		# a aceleracao.
		for q in 34:
			for c in corpos:
				c.position += c.global_basis * Vector3(0.0, 0.0, -1.4 / 60.0)
				c.animar(1.4, 1.0 / 60.0)
			await process_frame
		_camera(mundo, Vector3(0.0, 0.9, -5.4), Vector3(0.0, 0.8, 0.0), 32.0)
		await _foto(String(vista[0]))
		await _limpar(mundo)


const CONJUNTOS: Array[Dictionary] = [
	{"sexo": &"M", "camisa_estilo": 2, "casaco_estilo": 6, "calca_estilo": 0,
		"sapato_estilo": 3, "oculos": 1, "barba": 3, "rosto": 8},
	{"sexo": &"M", "camisa_estilo": 3, "casaco_estilo": 0, "calca_estilo": 1,
		"sapato_estilo": 1, "rosto": 9, "chapeu_tipo": 6},
	{"sexo": &"M", "camisa_estilo": 4, "casaco_estilo": 0, "calca_estilo": 2,
		"sapato_estilo": 1, "rosto": 10, "barba": 1},
	{"sexo": &"M", "camisa_estilo": 1, "casaco_estilo": 0, "calca_estilo": 3,
		"sapato_estilo": 4, "rosto": 11, "oculos": 2, "chapeu_tipo": 1},
	{"sexo": &"M", "camisa_estilo": 5, "casaco_estilo": 3, "calca_estilo": 0,
		"sapato_estilo": 2, "rosto": 12, "barba": 4, "chapeu_tipo": 3},
	{"sexo": &"F", "camisa_estilo": 0, "casaco_estilo": 4, "calca_estilo": 2,
		"sapato_estilo": 1, "rosto": 8, "oculos": 4},
	{"sexo": &"F", "camisa_estilo": 2, "casaco_estilo": 2, "calca_estilo": 5,
		"sapato_estilo": 3, "rosto": 9, "chapeu_tipo": 5},
	{"sexo": &"F", "camisa_estilo": 1, "casaco_estilo": 5, "calca_estilo": 4,
		"sapato_estilo": 4, "rosto": 10, "oculos": 3, "chapeu_tipo": 7},
]


func _aparencia_do_conjunto(conj: Dictionary, id: int) -> Dictionary:
	var sexo: StringName = conj["sexo"]
	var base := _base(sexo, id)
	var ajustes := Aparencia.ajustes_de(base)
	for k: String in conj:
		if k == "sexo":
			continue
		ajustes[StringName(k)] = conj[k]
	# Cores contrastadas: roupa escura some no fundo cinza da bancada.
	ajustes[&"camisa_cor"] = Aparencia.ROUPAS[12 - (id % 3) * 2]
	ajustes[&"casaco_cor"] = Aparencia.ROUPAS[4 + id % 5]
	ajustes[&"calca_cor"] = Aparencia.CALCAS[id % 8]
	ajustes[&"sapato_cor"] = Aparencia.paleta("SAPATOS")[3 + id % 6]
	ajustes[&"chapeu_cor"] = Aparencia.ROUPAS[9]
	return Aparencia.com_ajustes(base, ajustes)


func _rodar() -> void:
	await process_frame
	var mundo := _montar_palco()

	# --- corpos: do magro ao gordo, de frente, de lado e de tres quartos ------
	await _fotos_de_corpos(mundo)
	if _so == "corpos":
		quit(0)
		return

	# --- roupas: corpo inteiro, de frente e de tres quartos -------------------
	for vista: Array in [["roupas_frente.png", 0.0], ["roupas_lado.png", 0.75]]:
		var n := CONJUNTOS.size()
		for i in n:
			var c := _corpo(mundo, _aparencia_do_conjunto(CONJUNTOS[i], 40 + i),
				(float(i) - float(n - 1) * 0.5) * 0.85)
			c.rotation.y = float(vista[1])
		_camera(mundo, Vector3(0.0, 0.95, -8.2), Vector3(0.0, 0.92, 0.0), 30.0)
		await _foto(String(vista[0]))
		await _limpar(mundo)

	# --- reacoes: cada uma no meio, de frente e de tres quartos ---------------
	for vista: Array in [["reacoes_frente.png", 0.0], ["reacoes_lado.png", 0.8]]:
		var tipos: Array = ReacaoCorpo.POSES.keys()
		var n := tipos.size()
		for i in n:
			var tipo: int = tipos[i]
			var conj: Dictionary = CONJUNTOS[i % CONJUNTOS.size()].duplicate()
			conj["sexo"] = &"M"
			conj["casaco_estilo"] = 0
			conj["chapeu_tipo"] = 1 if tipo == ReacaoCorpo.CHAPEU else 0
			conj["oculos"] = 1 if tipo == ReacaoCorpo.OCULOS else 0
			var c := _corpo(mundo, _aparencia_do_conjunto(conj, 80 + i),
				(float(i) - float(n - 1) * 0.5) * 0.72)
			c.rotation.y = float(vista[1])
			c.reagir(tipo)
			c.animar(0.0, ReacaoCorpo.duracao(tipo) * 0.45)
		_camera(mundo, Vector3(0.0, 1.0, -8.6), Vector3(0.0, 0.95, 0.0), 32.0)
		await _foto(String(vista[0]))
		await _limpar(mundo)

	# --- rostos: os dezesseis de estudio, de perto ----------------------------
	var barbas := [0, 1, 2, 3, 4, 5, 0, 0]
	var oculos := [0, 0, 1, 0, 2, 0, 3, 4]
	for sexo: StringName in [&"M", &"F"]:
		for i in 8:
			var base := _base(sexo, 60 + i)
			var aj := Aparencia.ajustes_de(base)
			aj[&"rosto"] = 8 + i
			aj[&"chapeu_tipo"] = 0
			aj[&"barba"] = barbas[i] if sexo == &"M" else 0
			aj[&"oculos"] = oculos[i]
			aj[&"altura"] = 1.72
			var c := _corpo(mundo, Aparencia.com_ajustes(base, aj),
				(float(i) - 3.5) * 0.30)
			c.rotation.y = 0.0 if i % 2 == 0 else 0.35
		_camera(mundo, Vector3(0.0, 1.60, -3.0), Vector3(0.0, 1.60, 0.0), 30.0)
		await _foto("rostos_%s.png" % String(sexo).to_lower())
		await _limpar(mundo)

	quit(0)
