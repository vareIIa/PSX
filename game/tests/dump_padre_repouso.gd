## Despeja o padre da estrada no repouso, para ajustar a batina AAA no Blender:
## os ossos (repouso global), os colisores do pano, as tres pecas de pano de
## hoje (capuz, murca e batina, no espaco do esqueleto), o cranio debaixo do
## capuz e as malhas (OBJ, em coordenada de mundo; o corpo fica na origem,
## olhando -Z).
##
##     $G --headless --path game res://scenes/test/dump_padre_repouso.tscn -- --saida=DIR
extends Node

const QUEM := [
	# [nome, semente, altura, grande]
	["romeiro", 1, 1.72, false],
	["principal", 0, 1.95, true],
]


func _ready() -> void:
	var saida := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			saida = a.trim_prefix("--saida=")
	DirAccess.make_dir_recursive_absolute(saida)
	for q: Array in QUEM:
		var c := Corpo.new()
		c.name = String(q[0])
		add_child(c)
		var ombro := AberturaEstrada.OMBRO_ENCAPUZADO
		c.montar(AberturaEstrada._aparencia_de_encapuzado(int(q[1]), float(q[2]), ombro, bool(q[3])))
		var capuz := MonstroDaEstrada.vestir(c, int(q[1]), ombro / 0.42, bool(q[3]))
		await get_tree().process_frame
		_despejar(c, capuz, saida.path_join(String(q[0])))
	print("[dump_padre] fim")
	get_tree().quit()


func _despejar(c: Corpo, capuz: CapuzMacabro, base: String) -> void:
	var esq := c.esqueleto()
	var d := {"altura": c.altura(), "ossos": [], "pecas": [], "colisores": [], "cranio": []}
	for i in esq.get_bone_count():
		var t := esq.get_bone_global_rest(i)
		d["ossos"].append({"nome": esq.get_bone_name(i), "pai": esq.get_bone_parent(i),
			"x": _v(t.basis.x), "y": _v(t.basis.y), "z": _v(t.basis.z), "o": _v(t.origin)})
	var pano := capuz.pano
	if pano != null:
		for pc in pano.pecas:
			var rep := []
			var ex := []
			var fo := []
			var pu := []
			var pr := []
			for i in pc.n:
				var o := i * PanoGPU.FIXO_FLOATS
				var ba := int(pc.fixo[o + 3])
				var bb := int(pc.fixo[o + 7])
				var pa := esq.get_bone_global_rest(ba) * Vector3(pc.fixo[o], pc.fixo[o + 1], pc.fixo[o + 2])
				var pb := esq.get_bone_global_rest(bb) * Vector3(pc.fixo[o + 4], pc.fixo[o + 5], pc.fixo[o + 6])
				rep.append(_v(pa.lerp(pb, pc.fixo[o + 8])))
				fo.append(pc.fixo[o + 9])
				pu.append(pc.fixo[o + 10])
				pr.append(1 if pc.fixo[o + 11] == 0.0 else 0)
				ex.append(int(pc.fixo[o + 27]))
			d["pecas"].append({"nome": pc.nome, "w": pc.w, "h": pc.h, "periodico": pc.periodico,
				"repouso": rep, "existe": ex, "folga": fo, "puxa": pu, "preso": pr})
		for col: Array in pano.get("_colisores"):
			var t := esq.get_bone_global_rest(int(col[0]))
			t = Transform3D(t.basis.orthonormalized(), t.origin)
			d["colisores"].append({"osso": int(col[0]), "a": _v(t * (col[1] as Vector3)),
				"b": _v(t * (col[2] as Vector3)), "r": float(col[3])})
	var cab: AABB = capuz.call(&"_elipsoide_da_cabeca", c)
	var tc := esq.get_bone_global_rest(Corpo.Osso.CABECA)
	d["cranio"] = {"centro": _v(tc * cab.get_center()), "meio": _v(cab.size * 0.5)}
	var f := FileAccess.open(base + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	# As malhas visiveis, em mundo, num OBJ so (um grupo por malha).
	var obj := FileAccess.open(base + ".obj", FileAccess.WRITE)
	var n0 := 1
	for mi: MeshInstance3D in _malhas(c):
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		obj.store_line("o %s" % String(mi.get_path()).get_file().replace(" ", "_"))
		var t := mi.global_transform
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			for v in vs:
				var w := t * v
				obj.store_line("v %.5f %.5f %.5f" % [w.x, w.y, w.z])
			if idx.is_empty():
				for k in range(0, vs.size() - 2, 3):
					obj.store_line("f %d %d %d" % [n0 + k, n0 + k + 1, n0 + k + 2])
			else:
				for k in range(0, idx.size() - 2, 3):
					obj.store_line("f %d %d %d" % [n0 + idx[k], n0 + idx[k + 1], n0 + idx[k + 2]])
			n0 += vs.size()
	obj.close()
	print("[dump_padre] ", base, " ossos=", esq.get_bone_count(), " pecas=", d["pecas"].size())


func _malhas(n: Node) -> Array[MeshInstance3D]:
	var r: Array[MeshInstance3D] = []
	for f in n.get_children():
		if f is MeshInstance3D:
			r.append(f)
		r.append_array(_malhas(f))
	return r


static func _v(v: Vector3) -> Array:
	return [v.x, v.y, v.z]
