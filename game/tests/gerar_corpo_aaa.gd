## Monta a malha do corpo dos padres (`CorpoAAA.MALHA`) a partir do que o
## Blender exporta (`tools/blender_corpo/k_corpo.py`: `corpo_aaa.bin` e o
## cabecalho `corpo_aaa.json`) e grava o ArrayMesh, com LOD.
##
##     $G --headless --path game res://scenes/test/gerar_corpo_aaa.tscn -- --entrada=DIR
##
## Os ossos de cada vertice sao os indices do `Corpo` (uma ligacao por osso, na
## ordem, na Skin da `CorpoAAA`). COLOR: r o barro dos pes, g a tunica.
## Vao junto, como metadado da malha:
## - `repouso`: a origem de cada osso no esqueleto em que o corpo foi assado
##   (o romeiro de 1,72 m), para a Skin de outra altura;
## - `colisores`: as capsulas do pano medidas no corpo ([osso, a, b, raio], a e
##   b no esqueleto, Godot);
## - `altura_ref`.
extends Node

## Ate onde sobe o barro da estrada nos pes e nas canelas (m, no repouso).
const LAMA_ALTURA := 0.24
## Os ossos que a tunica escura cobre (o que se ve por baixo da murca, pela
## gola e pela manga le como pano, e nao como pele): quadril, tronco, cabeca
## (o pescoco do corpo, que entra no da cabeca), bracos e coxas. Ficam de pele
## o antebraco com a mao e a canela com o pe.
const TUNICA := [0, 1, 2, 3, 5, 7, 9]


func _ready() -> void:
	var entrada := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--entrada="):
			entrada = a.trim_prefix("--entrada=")
	var cab: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(entrada.path_join("corpo_aaa.json")))
	var dados := FileAccess.get_file_as_bytes(entrada.path_join("corpo_aaa.bin"))
	var n := int(cab["vertices"])
	var blocos := {}
	for b: Dictionary in cab["blocos"]:
		blocos[b["nome"]] = b
	var pega := func(nome: String) -> PackedFloat32Array:
		var b: Dictionary = blocos[nome]
		var tam := n * int(b["comps"]) * 4
		return dados.slice(int(b["offset"]), int(b["offset"]) + tam).to_float32_array()
	var pos: PackedFloat32Array = pega.call("pos")
	var nor: PackedFloat32Array = pega.call("nor")
	var tan: PackedFloat32Array = pega.call("tan")
	var uv: PackedFloat32Array = pega.call("uv")
	var ossos: PackedFloat32Array = pega.call("ossos")
	var pesos: PackedFloat32Array = pega.call("pesos")
	var bi: Dictionary = blocos["indices"]
	var ind := dados.slice(int(bi["offset"]), int(bi["offset"]) + int(cab["triangulos"]) * 12).to_int32_array()

	var v3 := PackedVector3Array()
	var n3 := PackedVector3Array()
	var t2 := PackedVector2Array()
	var ob := PackedInt32Array()
	# O barro dos pes, pela altura no repouso (e nao pela pose: o padre que
	# sobe no carro leva o pe sujo junto).
	var lama := PackedColorArray()
	lama.resize(n)
	v3.resize(n)
	n3.resize(n)
	t2.resize(n)
	ob.resize(n * 4)
	for i in n:
		v3[i] = Vector3(pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2])
		n3[i] = Vector3(nor[i * 3], nor[i * 3 + 1], nor[i * 3 + 2])
		t2[i] = Vector2(uv[i * 2], uv[i * 2 + 1])
		var l := 1.0 - smoothstep(0.0, LAMA_ALTURA, v3[i].y)
		# A tunica escura por baixo da batina: o peso nos ossos que ela cobre.
		var roupa := 0.0
		for k in 4:
			if int(ossos[i * 4 + k]) in TUNICA:
				roupa += pesos[i * 4 + k]
		lama[i] = Color(l, clampf(roupa, 0.0, 1.0), 0.0, 1.0)
		for k in 4:
			ob[i * 4 + k] = int(ossos[i * 4 + k])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v3
	arr[Mesh.ARRAY_NORMAL] = n3
	arr[Mesh.ARRAY_TANGENT] = tan
	arr[Mesh.ARRAY_TEX_UV] = t2
	arr[Mesh.ARRAY_COLOR] = lama
	arr[Mesh.ARRAY_BONES] = ob
	arr[Mesh.ARRAY_WEIGHTS] = pesos
	arr[Mesh.ARRAY_INDEX] = ind
	# As formas dos dedos (`k_dedos`), por lado: no modo relativo o Godot 4.7
	# guarda e soma DESLOCAMENTO (alvo - base), de posicao e de normal; com o
	# alvo inteiro a mao ia parar a meio metro. O LOD vem de um `ImporterMesh`
	# so da base (os indices).
	var alvos := []
	for nome: String in cab.get("formas", []):
		var fp: PackedFloat32Array = pega.call("forma_%s_pos" % nome)
		var fnr: PackedFloat32Array = pega.call("forma_%s_nor" % nome)
		var pv := PackedVector3Array()
		var pn := PackedVector3Array()
		pv.resize(n)
		pn.resize(n)
		for i in n:
			pv[i] = Vector3(fp[i * 3], fp[i * 3 + 1], fp[i * 3 + 2]) - v3[i]
			pn[i] = Vector3(fnr[i * 3], fnr[i * 3 + 1], fnr[i * 3 + 2]) - n3[i]
		var al := []
		al.resize(Mesh.ARRAY_MAX)
		al[Mesh.ARRAY_VERTEX] = pv
		al[Mesh.ARRAY_NORMAL] = pn
		al[Mesh.ARRAY_TANGENT] = tan
		alvos.append(al)
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr)
	im.generate_lods(25.0, 60.0, [])
	var lods := {}
	for i in im.get_surface_lod_count(0):
		lods[im.get_surface_lod_size(0, i)] = im.get_surface_lod_indices(0, i)
	var malha := ArrayMesh.new()
	malha.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_RELATIVE
	for nome: String in cab.get("formas", []):
		malha.add_blend_shape(nome)
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, alvos, lods)
	malha.resource_name = "CorpoAAA"
	var rep := PackedVector3Array()
	for p: Array in cab["repouso"]:
		rep.append(Vector3(p[0], p[1], p[2]))
	var cols := []
	for c: Array in cab["colisores"]:
		var a: Array = c[1]
		var b: Array = c[2]
		cols.append([int(c[0]), Vector3(a[0], a[1], a[2]), Vector3(b[0], b[1], b[2]), float(c[3])])
	malha.set_meta(&"repouso", rep)
	malha.set_meta(&"colisores", cols)
	malha.set_meta(&"altura_ref", float(cab["altura_ref"]))
	var err := ResourceSaver.save(malha, CorpoAAA.MALHA, ResourceSaver.FLAG_COMPRESS)
	print("[gerar_corpo_aaa] vertices=%d triangulos=%d lods=%d formas=%s colisores=%d salvo=%s (%d)" % [
		n, ind.size() / 3, lods.size(), str(cab.get("formas", [])), cols.size(), CorpoAAA.MALHA, err])
	get_tree().quit()
