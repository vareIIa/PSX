## Vistas da vegetacao NA CIDADE (PLANO_FLORA_AAA, rodada 3).
##
##     godot --path game --resolution 3840x2160 res://tests/vista_flora.tscn -- \
##         --pular-menu --estilo=moderno --fog=dia_sol --chuva=0 --molhado=0 \
##         --saida=DIR [--vistas=rua_casas,quintal] [--prefixo=antes_] [--sem-vida]
##         [--parar=S] [--vista=nome:ox,oy,oz,ax,ay,az[,fov]]
##
## A bancada_flora mede cada especie sozinha, sob um ceu fixo. Isto aqui e o
## outro lado: a arvore no lugar dela, com a calcada, o muro, o fio, o poste e a
## nevoa da cidade. Cada vista e uma camera propria (o jogador sai da fisica, e
## vai junto so porque o streaming segue ele: memoria "--ir-para nao e regua"),
## e a foto so sai depois que o streaming, a exposicao e o brilho assentam
## (memoria "primeira execucao nao vale captura").
##
## As alturas das vistas sao ACIMA do chao do Relevo, como na rota.
extends Node

## nome: [olho x, olho y acima do chao, olho z, alvo x, alvo y acima do chao,
##        alvo z, fov]
const VISTAS := {
	# De cima, obliquo: onde esta o verde e como ele enche a quadra.
	"alto_residencial": [-200.0, 46.0, 196.0, -200.0, 0.0, 84.0, 60.0],
	"alto_baldio": [-64.0, 38.0, 196.0, -64.0, 0.0, 84.0, 60.0],
	"alto_parque": [-10.0, 34.0, -150.0, -64.0, 0.0, -192.0, 60.0],
	"alto_praca": [312.0, 30.0, -8.0, 271.0, 0.0, -59.0, 60.0],
	"alto_residencial_2": [80.0, 42.0, -60.0, 80.0, 0.0, -172.0, 60.0],
	# Da altura do olho.
	# Rua de paralelepipedo do bairro (x = 64, z -160..-128), no eixo da pista.
	"rua_casas": [64.0, 1.7, -124.0, 64.5, 3.2, -160.0, 62.0],
	"quintal": [104.0, 1.7, -84.0, 116.0, 4.0, -120.0, 62.0],
	"baldio": [-64.0, 1.7, 132.0, -48.0, 1.2, 100.0, 62.0],
	"praca": [252.0, 1.7, -28.0, 282.0, 4.0, -70.0, 62.0],
	"parque": [-64.0, 1.7, -172.0, -40.0, 3.0, -200.0, 62.0],
	"miolo": [-240.0, 1.7, 80.0, -210.0, 3.0, 70.0, 62.0],
	# A avenida com palmeira (a queixa da rodada 3: "arvore gigante sem folhas").
	"avenida_z160": [-262.0, 1.7, 158.0, -180.0, 7.0, 160.0, 62.0],
	"avenida_z160_b": [-120.0, 1.7, 158.5, -200.0, 7.0, 160.0, 62.0],
	"avenida_x160": [-158.0, 1.7, 40.0, -160.0, 7.0, 120.0, 62.0],
	"avenida_z0": [-250.0, 1.7, -1.5, -170.0, 7.0, 0.0, 62.0],
	# As palmeiras que a poda em V pelava (sonda_palmeiras: x = -167,5 e z = 7,6).
	"palmeiras_x160": [-153.0, 1.7, -8.0, -163.0, 9.0, 60.0, 62.0],
	"palmeiras_x160_lado": [-156.0, 1.7, 20.0, -168.0, 10.0, 70.0, 62.0],
	"palmeiras_z0": [-225.0, 1.7, 2.5, -290.0, 9.0, 8.0, 62.0],
	# A fila de palmeiras da avenida x = -160 (canteiro em x = -167,5, z = 9, 20,
	# 41, 52, 73, 84, 105, 116, 137, 148): do olho, a 11, 22, 43, 54, 75, 86, 107,
	# 118, 139 e 150 m. E de baixo, olhando a copa a 9 m.
	"palma_fila": [-161.0, 1.7, -2.0, -167.0, 8.0, 60.0, 62.0],
	"palma_baixo": [-164.5, 1.2, 13.0, -167.5, 15.0, 20.0, 62.0],
	"palma_longe": [-161.0, 1.7, 30.0, -167.0, 9.0, 150.0, 40.0],
	# De perto: a arvore de calcada da avenida (x = -167,5) vista da pista.
	"arvore_rua_perto": [-159.0, 1.7, 30.0, -167.5, 5.5, 44.0, 62.0],
	"arvore_rua_perto_b": [-161.0, 1.7, 96.0, -167.5, 5.5, 108.0, 62.0],
}

const ESPERA_MAX_S := 10.0
const ESTAVEL := 12

var _saida := ""
var _so: PackedStringArray = []
var _prefixo := ""
var _sem_vida := false
var _extra: Dictionary = {}
## `--parar=S`: fica S segundos em cada vista depois da foto (para o `--medir`
## do MedidorQuadro amostrar o regime ali).
var _parar := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
		elif arg.begins_with("--vistas="):
			_so = arg.trim_prefix("--vistas=").split(",", false)
		elif arg.begins_with("--prefixo="):
			_prefixo = arg.trim_prefix("--prefixo=")
		elif arg == "--sem-vida":
			_sem_vida = true
		elif arg.begins_with("--parar="):
			_parar = arg.trim_prefix("--parar=").to_float()
		elif arg.begins_with("--vista="):
			# --vista=nome:ox,oy,oz,ax,ay,az[,fov]  (vista avulsa, sem editar o arquivo)
			var partes := arg.trim_prefix("--vista=").split(":")
			var nums: Array = []
			for p: String in partes[1].split(","):
				nums.append(float(p))
			if nums.size() < 7:
				nums.append(62.0)
			_extra[partes[0]] = nums
	if not _saida.is_empty():
		DirAccess.make_dir_recursive_absolute(_saida)
	var cidade: Node = (load("res://scenes/test/cidade.tscn") as PackedScene).instantiate()
	add_child(cidade)
	_rodar()


func _rodar() -> void:
	var arvore := get_tree()
	var jogador: Node3D = null
	while jogador == null:
		await arvore.physics_frame
		jogador = arvore.get_first_node_in_group(&"player") as Node3D
	var corpo := jogador as CharacterBody3D
	if corpo != null:
		corpo.set_collision_mask_value(1, false)
		corpo.velocity = Vector3.ZERO
		corpo.set_physics_process(false)
		corpo.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cam := Camera3D.new()
	cam.name = "CameraDaVistaFlora"
	cam.near = 0.08
	cam.far = 900.0
	add_child(cam)
	for i in 30:
		await arvore.process_frame
	var todas := VISTAS.duplicate()
	todas.merge(_extra, true)
	var nomes: Array = todas.keys() if _so.is_empty() else Array(_so)
	for nome: String in nomes:
		if not todas.has(nome):
			push_warning("vista_flora: vista %s nao existe" % nome)
			continue
		var v: Array = todas[nome]
		var olho := Vector3(v[0], 0.0, v[2])
		olho.y = Relevo.altura(olho.x, olho.z) + float(v[1])
		var alvo := Vector3(v[3], 0.0, v[5])
		alvo.y = Relevo.altura(alvo.x, alvo.z) + float(v[4])
		# O streaming segue o jogador: ele vai ao chao entre o olho e o alvo,
		# mais perto do olho (e o que precisa estar inteiro na foto).
		var ancora := olho.lerp(alvo, 0.3)
		jogador.global_position = Vector3(ancora.x, Relevo.altura(ancora.x, ancora.z) + 1.0, ancora.z)
		jogador.visible = false
		cam.fov = float(v[6])
		cam.global_position = olho
		cam.look_at(alvo, Vector3.UP if absf((alvo - olho).normalized().y) < 0.98 else Vector3.FORWARD)
		cam.current = true
		await _assentar()
		if _sem_vida:
			_esvaziar()
			for i in 3:
				await arvore.process_frame
		await _fotografar(_prefixo + nome)
		if _parar > 0.0:
			# O MedidorQuadro (`--medir`) separa o regime desta vista no resumo.
			var medidor := get_node_or_null(^"/root/Medidor")
			if medidor != null and medidor.has_method("marcar_parada"):
				medidor.call("marcar_parada", StringName(nome))
			var ate := Time.get_ticks_msec() + int(_parar * 1000.0)
			while Time.get_ticks_msec() < ate:
				await arvore.process_frame
			if medidor != null and medidor.has_method("marcar_parada"):
				medidor.call("marcar_parada", &"")
	print("[vista_flora] fim")
	arvore.quit(0)


func _esvaziar() -> void:
	for caminho: NodePath in [^"/root/Transito", ^"/root/Multidao", ^"/root/Ceu", ^"/root/ChuvaFora"]:
		var s := get_node_or_null(caminho)
		if s == null:
			continue
		if s.has_method("parar"):
			s.call("parar")
		if s.has_method("limpar"):
			s.call("limpar")


func _assentar() -> void:
	var arvore := get_tree()
	for i in 90:
		await arvore.process_frame
	var cm := get_node_or_null(^"/root/ChunkManager")
	if cm != null:
		var anterior := -1
		var iguais := 0
		var ate := Time.get_ticks_msec() + int(ESPERA_MAX_S * 1000.0)
		while iguais < ESTAVEL and Time.get_ticks_msec() < ate:
			await arvore.process_frame
			var n := int(cm.call("chunks_carregados"))
			iguais = iguais + 1 if n == anterior else 0
			anterior = n
	# Chunk novo monta a malha em thread depois de contar: mais meio segundo.
	var fim := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < fim:
		await arvore.process_frame
	var lente := get_node_or_null(^"/root/Lente")
	if lente != null and lente.has_method("assentada"):
		var ate_l := Time.get_ticks_msec() + int(ESPERA_MAX_S * 1000.0)
		while not bool(lente.call("assentada")) and Time.get_ticks_msec() < ate_l:
			await arvore.process_frame
	await _esperar_brilho()


func _esperar_brilho() -> void:
	var anterior := -1.0
	var quietas := 0
	var ate := Time.get_ticks_msec() + int(ESPERA_MAX_S * 1000.0)
	while quietas < 3 and Time.get_ticks_msec() < ate:
		var espera := Time.get_ticks_msec() + 250
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
		quietas = quietas + 1 if absf(media - anterior) < 0.25 else 0
		anterior = media


func _fotografar(nome: String) -> void:
	var escondidos: Array[Node] = []
	for n: Node in get_tree().get_nodes_in_group(&"hud"):
		if n.get("visible") == true:
			n.set("visible", false)
			escondidos.append(n)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	for n: Node in escondidos:
		n.set("visible", true)
	if img == null or _saida.is_empty():
		return
	var caminho := _saida.path_join(nome + ".png")
	img.save_png(caminho)
	print("[vista_flora] %s (%dx%d)" % [caminho, img.get_width(), img.get_height()])
