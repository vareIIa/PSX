## Buraco pro limbo nas quinas: ponta de calcada e esquina de predio.
##
##     godot --path game --resolution 1280x720 --script res://tests/bancada_quinas.gd
##     (SEM --headless: precisa desenhar)
##     -- --saida=DIR   grava a foto de cada pose que falhar
##
## Por que existe
## -------------
## As duas frestas eram geometria que faltava, e nao sombra nem nevoa: a ponta da
## calcada do eixo X nao tinha face (16 cm abertos para o vao sob a laje) e a
## massa do predio comecava 6 cm atras da fachada, deixando uma fenda do chao ao
## telhado na ponta da fileira. Na cidade de verdade isso nao se mede: `--ir-para`
## nao e regua (o pedestre empurra o jogador) e a nevoa escurece o que vaza.
##
## Aqui os chunks sao montados sozinhos, cada material em cor chapada sem luz, e o
## fundo e magenta puro. Magenta na foto e, por construcao, um raio que nao bateu
## em nada: um buraco. As camaras olham para baixo, entao ceu nunca entra no
## quadro.
##
## Poses
## -----
## Toda ponta de calcada do eixo X que da para uma pista transversal, e toda
## quina de quadra onde duas ruas se encontram, nos chunks de -RAIO a RAIO.
extends SceneTree

const RAIO := 2
const TAM := KitModular.CHUNK
const MAGENTA := Color(1.0, 0.0, 1.0)
## Pixels magenta tolerados por pose. Zero: fresta de um pixel ja e o defeito.
const LIMITE := 0

var _camera: Camera3D
var _saida := ""
## O chao do patio. Some nas poses de predio: a fresta da quina da para o patio,
## e com ele a vista o raio acha terra em vez do fundo e o buraco passa.
var _patio: Array[MeshInstance3D] = []


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
	_montar.call_deferred()


func _montar() -> void:
	RenderingServer.set_default_clear_color(MAGENTA)
	var raiz := Node3D.new()
	root.add_child(raiz)
	var mats := {}
	for cz in range(-RAIO - 1, RAIO + 2):
		for cx in range(-RAIO - 1, RAIO + 2):
			var sup: Dictionary = ChunkBuilder.construir(cx, cz)["superficies"]
			for mat: StringName in sup:
				if PSXMesh.dados_vazio(sup[mat]):
					continue
				if not mats.has(mat):
					mats[mat] = _chapado(mat)
				var mi := MeshInstance3D.new()
				mi.mesh = PSXMesh.dados_para_mesh(sup[mat])
				mi.material_override = mats[mat]
				mi.position = Vector3(cx * TAM, 0.0, cz * TAM)
				raiz.add_child(mi)
				if mat == &"terra":
					_patio.append(mi)

	_camera = Camera3D.new()
	_camera.fov = 60.0
	_camera.near = 0.02
	root.add_child(_camera)
	_camera.current = true

	var falhas := 0
	var poses := _poses()
	for pose: Dictionary in poses:
		# As poses sao montadas no plano; cada ponta sobe pelo chao do morro
		# (Relevo), senao a camera da quina nascia dentro da ladeira.
		var de: Vector3 = pose["de"]
		var para: Vector3 = pose["para"]
		de.y += Relevo.altura(de.x, de.z)
		para.y += Relevo.altura(para.x, para.z)
		_camera.look_at_from_position(de, para)
		for mi: MeshInstance3D in _patio:
			mi.visible = pose["tipo"] != "predio"
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		# Na quina, so a faixa do meio: e onde a aresta cai. Nas bordas do quadro
		# o fundo aparece por cima de predio baixo, e isso nao e buraco.
		var n := _magenta(img, 0.35 if pose["tipo"] == "predio" else 0.0)
		if n > LIMITE:
			falhas += 1
			print("FALHA  %-8s chunk %s  %d px magenta" % [pose["tipo"], pose["chunk"], n])
			if _saida != "":
				img.save_png("%s/%s_%d_%d_%d.png" % [_saida, pose["tipo"],
					pose["chunk"].x, pose["chunk"].y, int(pose["k"])])
	print("bancada_quinas: %d poses, %d com buraco" % [poses.size(), falhas])
	print("PASSOU" if falhas == 0 else "FALHOU")
	quit(0 if falhas == 0 else 1)


static func _chapado(mat: StringName) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Mesmo descarte do jogo (psx_surface e cull_back): a bancada tem de esconder
	# exatamente as faces que o jogo esconde, senao o avesso tapa o buraco.
	m.cull_mode = BaseMaterial3D.CULL_BACK
	var h := String(mat).hash()
	# Cor longe do magenta: o canal verde nunca zera.
	m.albedo_color = Color((h & 0xff) / 255.0, 0.3 + ((h >> 8) & 0xff) / 512.0,
		((h >> 16) & 0xff) / 255.0)
	return m


static func _magenta(img: Image, margem: float) -> int:
	var n := 0
	var w := img.get_width()
	for y in range(0, img.get_height(), 2):
		for x in range(int(w * margem), int(w * (1.0 - margem)), 2):
			var c := img.get_pixel(x, y)
			if c.r > 0.9 and c.b > 0.9 and c.g < 0.1:
				n += 1
	return n


static func _poses() -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for cz in range(-RAIO, RAIO + 1):
		for cx in range(-RAIO, RAIO + 1):
			var b := MalhaUrbana.bordas(cx, cz)
			var lim := ChunkBuilder.area_util(cx, cz)
			var o := Vector3(cx * TAM, 0.0, cz * TAM)
			var px0 := MalhaUrbana.meia_asfalto(b["x0"])
			var px1 := MalhaUrbana.meia_asfalto(b["x1"])
			var pz0 := MalhaUrbana.meia_asfalto(b["z0"])
			var pz1 := MalhaUrbana.meia_asfalto(b["z1"])
			var chunk := Vector2i(cx, cz)

			# Pontas das calcadas do eixo X: camera na pista transversal, 1,1 m
			# antes da ponta, olhando para baixo contra ela.
			var faixas: Array[float] = []
			if lim.position.x - px0 > 0.05:
				faixas.append((px0 + lim.position.x) * 0.5)
			if TAM - px1 - lim.end.x > 0.05:
				faixas.append((lim.end.x + TAM - px1) * 0.5)
			for x: float in faixas:
				if pz0 > 0.05:
					_contra(saida, "ponta", chunk, o + Vector3(x, 0.0, pz0), Vector3.FORWARD)
				if pz1 > 0.05:
					_contra(saida, "ponta", chunk, o + Vector3(x, 0.0, TAM - pz1), Vector3.BACK)

			# O meio-fio comprido dos dois eixos, no meio da quadra.
			var meio := lim.get_center()
			if lim.position.x - px0 > 0.05:
				_contra(saida, "meio_fio", chunk, o + Vector3(px0, 0.0, meio.y), Vector3.LEFT)
			if TAM - px1 - lim.end.x > 0.05:
				_contra(saida, "meio_fio", chunk, o + Vector3(TAM - px1, 0.0, meio.y), Vector3.RIGHT)
			if lim.position.y - pz0 > 0.05:
				_contra(saida, "meio_fio", chunk, o + Vector3(meio.x, 0.0, pz0), Vector3.FORWARD)
			if TAM - pz1 - lim.end.y > 0.05:
				_contra(saida, "meio_fio", chunk, o + Vector3(meio.x, 0.0, TAM - pz1), Vector3.BACK)

			# Quinas de quadra com rua dos dois lados: camera na diagonal de
			# fora, a 1 m, olhando a aresta do predio.
			if int(MalhaUrbana.quadra_de(cx, cz)["uso"]) != MalhaUrbana.Uso.EDIFICADO:
				continue
			for sx: int in [0, 1]:
				for sz: int in [0, 1]:
					var via_x: MalhaUrbana.Via = b["x0" if sx == 0 else "x1"]
					var via_z: MalhaUrbana.Via = b["z0" if sz == 0 else "z1"]
					if via_x == MalhaUrbana.Via.NENHUMA or via_z == MalhaUrbana.Via.NENHUMA:
						continue
					var canto := Vector3(lim.position.x if sx == 0 else lim.end.x, 0.0,
						lim.position.y if sz == 0 else lim.end.y)
					var fora := Vector3(-1.0 if sx == 0 else 1.0, 0.0,
						-1.0 if sz == 0 else 1.0)
					saida.append({"tipo": "predio", "chunk": chunk, "k": saida.size(),
						"de": o + canto + fora * 0.8 + Vector3(0.0, 1.9, 0.0),
						"para": o + canto + Vector3(0.0, 0.9, 0.0)})
	return saida


## Camera na rua, a 0,7 m da borda de calcada em `borda`, olhando para ela a 45
## graus. `rua` aponta da borda para o lado da pista.
static func _contra(saida: Array[Dictionary], tipo: String, chunk: Vector2i,
		borda: Vector3, rua: Vector3) -> void:
	saida.append({"tipo": tipo, "chunk": chunk, "k": saida.size(),
		"de": borda + rua * 0.7 + Vector3(0.0, 0.75, 0.0),
		"para": borda - rua * 0.1})
