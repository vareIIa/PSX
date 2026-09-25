extends SceneTree

func _initialize() -> void:
	_rodar.call_deferred()

func _rodar() -> void:
	for nome: String in ["MAREA", "FUSCA"]:
		var modelo: int = Carroceria.Modelo[nome]
		var m := Carroceria.montar(modelo, CarroCena.TINTA, CarroCena.SEMENTE, true, false)
		var cab := CarroCabine.new()
		root.add_child(cab)
		cab.montar(m)
		var g := cab.interior().g
		var tempos: Array[float] = []
		var tris := {}
		for rep in 3:
			var it2 := CabineInterior.new()
			root.add_child(it2)
			var ti0 := Time.get_ticks_usec()
			it2.montar(g.duplicate())
			tempos.append((Time.get_ticks_usec() - ti0) / 1000.0)
			if rep == 0:
				for mi: MeshInstance3D in it2.find_children("*", "MeshInstance3D", true, false):
					var k := String(mi.name)
					var ar := mi.mesh.surface_get_arrays(0)
					tris[k] = int(tris.get(k, 0)) + (ar[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			it2.queue_free()
			await process_frame
		var total := 0
		for k: String in tris:
			total += int(tris[k])
		print("%s: interior monta em %s ms; %d triangulos; %s" % [nome, tempos, total, tris])
		cab.queue_free()
	quit(0)
