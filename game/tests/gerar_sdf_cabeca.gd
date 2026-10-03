## O campo de distancia da cabeca dos padres de fundo (`BatinaAAA.CABECA_SDF`:
## o pano dos padres que nao sao o principal nao entra na cabeca), em duas
## pontas de `tools/gerar_sdf_cabeca.py`:
##
##     $G --headless --path game res://scenes/test/gerar_sdf_cabeca.tscn -- --despejar=DIR
##         a malha da pele de fundo (`CabecaDoPadre._malha_pele`, a que a
##         `CabecaDeFundo` veste), no espaco da cabeca: DIR/fundo_pos.f32,
##         _nor.f32, _ind.i32 (e a do principal, `principal_*`, so para conferir)
##     $G --headless --path game res://scenes/test/gerar_sdf_cabeca.tscn -- --montar=DIR
##         le DIR/sdf.f32 e DIR/sdf.json (o numpy fez a conta) e grava a textura
##         3D `BatinaAAA.CABECA_SDF`
##
## Base: o `gerar_sdf_cabeca.gd` da frente CAPUZ (worktree PSX_capuz).
extends Node


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--despejar="):
			_despejar(a.trim_prefix("--despejar="))
		elif a.begins_with("--montar="):
			_montar(a.trim_prefix("--montar="))
	get_tree().quit()


func _despejar(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	if not CabecaDoPadre._carregar():
		push_error("gerar_sdf_cabeca: a cabeca nao carrega")
		return
	for par: Array in [["principal", CabecaDoPadre._malha_pele_boca], ["fundo", CabecaDoPadre._malha_pele]]:
		var m := par[1] as Mesh
		if m == null:
			continue
		var arr := m.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var f := PackedFloat32Array()
		var fn := PackedFloat32Array()
		for i in v.size():
			f.append_array([v[i].x, v[i].y, v[i].z])
			fn.append_array([n[i].x, n[i].y, n[i].z])
		_gravar(dir.path_join(par[0] + "_pos.f32"), f.to_byte_array())
		_gravar(dir.path_join(par[0] + "_nor.f32"), fn.to_byte_array())
		_gravar(dir.path_join(par[0] + "_ind.i32"), (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).to_byte_array())
		print("[gerar_sdf_cabeca] %s: %d vertices" % [par[0], v.size()])


func _montar(dir: String) -> void:
	var cab: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("sdf.json")))
	var dados := FileAccess.get_file_as_bytes(dir.path_join("sdf.f32"))
	var nx := int(cab["n"][0])
	var ny := int(cab["n"][1])
	var nz := int(cab["n"][2])
	# As fatias em z empilhadas numa imagem so (nx por ny * nz): a textura 3D
	# nao guarda os dados fora da placa (em --headless o .res saia vazio), e a
	# `BatinaAAA` a monta ao carregar.
	var img := Image.create_from_data(nx, ny * nz, false, Image.FORMAT_RF, dados)
	img.convert(Image.FORMAT_RH)
	img.set_meta(&"fatias", nz)
	img.set_meta(&"minimo", Vector3(cab["minimo"][0], cab["minimo"][1], cab["minimo"][2]))
	img.set_meta(&"tamanho", Vector3(cab["tamanho"][0], cab["tamanho"][1], cab["tamanho"][2]))
	var e2 := ResourceSaver.save(img, BatinaAAA.CABECA_SDF, ResourceSaver.FLAG_COMPRESS)
	var volta := load(BatinaAAA.CABECA_SDF) as Image
	print("[gerar_sdf_cabeca] %dx%dx%d salva=%d em %s; relida %s, centro %.4f" % [nx, ny, nz, e2,
		BatinaAAA.CABECA_SDF, volta.get_size() if volta != null else Vector2i.ZERO,
		volta.get_pixel(nx / 2, (nz / 2) * ny + ny / 2).r if volta != null else 0.0])


func _gravar(caminho: String, b: PackedByteArray) -> void:
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f != null:
		f.store_buffer(b)
