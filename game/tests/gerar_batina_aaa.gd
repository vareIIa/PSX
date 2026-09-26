## Monta a malha da batina AAA (`BatinaAAA.MALHA`) a partir do que o Blender
## exporta (`tools/blender_batina/r_ligar.py`: `batina_aaa.bin` e o cabecalho
## `batina_aaa.json`) e grava o ArrayMesh.
##
##     $G --headless --path game res://scenes/test/gerar_batina_aaa.tscn -- --entrada=DIR
##
## Os canais (ver o shader da `BatinaAAA`):
## - VERTEX: o lugar na ligacao (so para a caixa e para quem nao simula);
## - NORMAL e TANGENT: no referencial local da grade A;
## - UV: a textura; UV2: a coordenada na grade A;
## - CUSTOM0: o desvio na grade A (xyz) e qual grade (w);
## - CUSTOM1: a coordenada na grade B (xy), o peso dela (z) e qual (w);
## - CUSTOM2: o desvio na grade B (xyz) e a area da grade A na ligacao (w);
## - COLOR: o remendo dos tampos (rgb = 0,5 + diferenca de cor / 2, a = AO).
## Uma superficie por peca que some (a batina, cada manga) e uma para capuz e
## murca juntos (meta `superficie_de`: {grade: superficie}).
extends Node


func _ready() -> void:
	var entrada := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--entrada="):
			entrada = a.trim_prefix("--entrada=")
	var cab: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(entrada.path_join("batina_aaa.json")))
	var dados := FileAccess.get_file_as_bytes(entrada.path_join("batina_aaa.bin"))
	var n := int(cab["vertices"])
	var blocos := {}
	for b: Dictionary in cab["blocos"]:
		blocos[b["nome"]] = b
	var pega := func(nome: String) -> PackedFloat32Array:
		var b: Dictionary = blocos[nome]
		var tam := n * int(b["comps"]) * 4
		return dados.slice(int(b["offset"]), int(b["offset"]) + tam).to_float32_array()
	var pos: PackedFloat32Array = pega.call("pos")
	var nor: PackedFloat32Array = pega.call("nor_local")
	var tan: PackedFloat32Array = pega.call("tan_local")
	var uv: PackedFloat32Array = pega.call("uv")
	var ga: PackedFloat32Array = pega.call("ga")
	var oa: PackedFloat32Array = pega.call("oa")
	var gb: PackedFloat32Array = pega.call("gb")
	var ob: PackedFloat32Array = pega.call("ob")
	# `ob` traz o desvio na grade B e, no quarto, a area da grade A na ligacao.
	var co := int((blocos["ob"] as Dictionary)["comps"])
	var bi: Dictionary = blocos["indices"]
	var ind := dados.slice(int(bi["offset"]), int(bi["offset"]) + int(cab["triangulos"]) * 12).to_int32_array()

	var v3 := PackedVector3Array()
	var n3 := PackedVector3Array()
	var t2 := PackedVector2Array()
	var u2 := PackedVector2Array()
	v3.resize(n)
	n3.resize(n)
	t2.resize(n)
	u2.resize(n)
	var c2 := PackedFloat32Array()
	c2.resize(n * 4)
	for i in n:
		v3[i] = Vector3(pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2])
		n3[i] = Vector3(nor[i * 3], nor[i * 3 + 1], nor[i * 3 + 2])
		t2[i] = Vector2(uv[i * 2], uv[i * 2 + 1])
		u2[i] = Vector2(ga[i * 2], ga[i * 2 + 1])
		c2[i * 4] = ob[i * co]
		c2[i * 4 + 1] = ob[i * co + 1]
		c2[i * 4 + 2] = ob[i * co + 2]
		c2[i * 4 + 3] = ob[i * co + 3] if co > 3 else 0.0
	# Uma superficie por peca (a grade de cada triangulo e a da maioria dos
	# vertices dele). Esconder uma peca (a batina de quem sobe no carro, a manga
	# do braco trocado) e trocar o material da superficie dela. Escondendo por
	# vertice, o triangulo da divisa esticava ate o vertice sumido e virava uma
	# coluna de pano dura ate o chao.
	var n_grades := (cab["grades"] as Array).size()
	# Capuz e murca nunca somem: vao juntos (uma chamada de desenho a menos por
	# padre em cada passada). A batina e as mangas, cada uma a sua.
	var grupo := PackedInt32Array()
	grupo.resize(n_grades)
	for k in n_grades:
		grupo[k] = 0 if String(cab["grades"][k]) in ["Capuz", "Murca"] else k
	# (Packed* e valor no GDScript: a peca de cada triangulo num array so.)
	var n_tri := ind.size() / 3
	var peca := PackedInt32Array()
	peca.resize(n_tri)
	for t in n_tri:
		var a := int(oa[ind[t * 3] * 4 + 3] + 0.5)
		var b := int(oa[ind[t * 3 + 1] * 4 + 3] + 0.5)
		var c := int(oa[ind[t * 3 + 2] * 4 + 3] + 0.5)
		peca[t] = grupo[a if (a == b or a == c) else (b if b == c else mini(a, mini(b, c)))]
	var cor_bloco := PackedFloat32Array()
	if blocos.has("cor"):
		cor_bloco = pega.call("cor")
	var fmt := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) \
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT)
	# LOD pela posicao de ligacao (a malha anda pelas grades, mas a topologia e
	# a mesma): de longe, o vertice que faz 16 leituras de textura e o que mais
	# pesa. A normal e local da grade, entao o angulo de normal nao conta.
	var im := ImporterMesh.new()
	## {grade: superficie}
	var superficie_de := {}
	var n_sup := 0
	var novo := PackedInt32Array()
	novo.resize(n)
	for k in n_grades:
		var tri := PackedInt32Array()
		for t in n_tri:
			if peca[t] == k:
				tri.append(ind[t * 3])
				tri.append(ind[t * 3 + 1])
				tri.append(ind[t * 3 + 2])
		if tri.is_empty():
			continue
		novo.fill(-1)
		var usados := PackedInt32Array()
		for i in tri:
			if novo[i] < 0:
				novo[i] = usados.size()
				usados.append(i)
		var m := usados.size()
		var sv := PackedVector3Array()
		var sn := PackedVector3Array()
		var st := PackedVector2Array()
		var su := PackedVector2Array()
		var stan := PackedFloat32Array()
		var s0 := PackedFloat32Array()
		var s1 := PackedFloat32Array()
		var s2 := PackedFloat32Array()
		var sc := PackedColorArray()
		sv.resize(m)
		sn.resize(m)
		st.resize(m)
		su.resize(m)
		stan.resize(m * 4)
		s0.resize(m * 4)
		s1.resize(m * 4)
		s2.resize(m * 4)
		if not cor_bloco.is_empty():
			sc.resize(m)
		for j in m:
			var i := usados[j]
			sv[j] = v3[i]
			sn[j] = n3[i]
			st[j] = t2[i]
			su[j] = u2[i]
			for q in 4:
				stan[j * 4 + q] = tan[i * 4 + q]
				s0[j * 4 + q] = oa[i * 4 + q]
				s1[j * 4 + q] = gb[i * 4 + q]
				s2[j * 4 + q] = c2[i * 4 + q]
			if not cor_bloco.is_empty():
				sc[j] = Color(cor_bloco[i * 4], cor_bloco[i * 4 + 1], cor_bloco[i * 4 + 2], cor_bloco[i * 4 + 3])
		var sind := PackedInt32Array()
		sind.resize(tri.size())
		for q in tri.size():
			sind[q] = novo[tri[q]]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = sv
		arr[Mesh.ARRAY_NORMAL] = sn
		arr[Mesh.ARRAY_TANGENT] = stan
		arr[Mesh.ARRAY_TEX_UV] = st
		arr[Mesh.ARRAY_TEX_UV2] = su
		arr[Mesh.ARRAY_CUSTOM0] = s0
		arr[Mesh.ARRAY_CUSTOM1] = s1
		arr[Mesh.ARRAY_CUSTOM2] = s2
		if not cor_bloco.is_empty():
			arr[Mesh.ARRAY_COLOR] = sc
		arr[Mesh.ARRAY_INDEX] = sind
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, null, str(cab["grades"][k]), fmt)
		for g in n_grades:
			if grupo[g] == k:
				superficie_de[g] = n_sup
		n_sup += 1
	im.generate_lods(180.0, 180.0, [])
	var malha := im.get_mesh()
	malha.resource_name = "BatinaAAA"
	malha.set_meta(&"uv_por_metro", float(cab.get("uv_por_metro", 0.0)))
	malha.set_meta(&"superficie_de", superficie_de)
	var err := ResourceSaver.save(malha, BatinaAAA.MALHA, ResourceSaver.FLAG_COMPRESS)
	print("[gerar_batina_aaa] vertices=%d triangulos=%d grades=%s superficie_de=%s salvo=%s (%d)" % [
		n, ind.size() / 3, str(cab["grades"]), str(superficie_de), BatinaAAA.MALHA, err])
	get_tree().quit()
