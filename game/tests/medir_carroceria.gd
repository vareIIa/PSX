## Custo da carroceria: triangulos e tempo de montagem, por modelo.
##
##     godot --headless --path game --script res://tests/medir_carroceria.gd
##
## `Carroceria.montar` roda a cada carro que o streaming poe na rua, no quadro
## principal: o tempo dela e engasgo. Imprime, por modelo, a primeira montagem
## (que paga o cache) e a media das cinco seguintes com tintas diferentes, e os
## triangulos de lataria, vidro, interior e das quatro rodas.
extends SceneTree


func _initialize() -> void:
	var total_ms := 0.0
	for modelo: int in Carroceria.Modelo.values():
		var nome: String = Carroceria.Modelo.keys()[modelo]
		var t0 := Time.get_ticks_usec()
		var m := Carroceria.montar(modelo, Carroceria.TINTAS[1], 1)
		var primeira := float(Time.get_ticks_usec() - t0) / 1000.0
		# As cinco seguintes com tintas e sementes diferentes, todas limpas
		# (semente fora dos multiplos de sete): e o carro comum da rua depois
		# que o modelo ja passou uma vez.
		var soma := 0.0
		for k in 5:
			t0 = Time.get_ticks_usec()
			m = Carroceria.montar(modelo, Carroceria.TINTAS[k + 3], 2 + k)
			soma += float(Time.get_ticks_usec() - t0) / 1000.0
		var media := soma / 5.0
		total_ms += media
		var corpo := m["corpo"] as ArrayMesh
		var rodas := 0
		for chave: String in ["roda_esq", "roda_dir"]:
			rodas += _tris(m[chave] as ArrayMesh) * 2
		# A versao de longe (so no MODERNO): lataria simples e roda de doze lados.
		var longe: Dictionary = m.get("longe", {})
		var tris_longe := 0
		if not longe.is_empty():
			tris_longe = _tris(longe["corpo"] as ArrayMesh) \
				+ _tris(longe["roda_esq"] as ArrayMesh) * 2 \
				+ _tris(longe["eixo_tras"] as ArrayMesh) \
				+ _tris(m["luzes"] as ArrayMesh)
		print("[custo] %-6s montar %.1f ms (primeira %.1f) | lataria %d, vidro %d, interior %d, rodas %d, luzes %d | perto %d, longe %d" % [
			nome, media, primeira, _tris_sup(corpo, 0), _tris_sup(corpo, 1),
			_tris(m["interior"] as ArrayMesh), rodas, _tris(m["luzes"] as ArrayMesh),
			_tris(corpo) + _tris(m["interior"] as ArrayMesh) + rodas
			+ _tris(m["luzes"] as ArrayMesh), tris_longe])
	print("[custo] media de montagem entre modelos: %.1f ms" % (total_ms / 7.0))
	quit(0)


static func _tris(malha: Mesh) -> int:
	var n := 0
	for s in malha.get_surface_count():
		n += _tris_sup(malha, s)
	return n


static func _tris_sup(malha: Mesh, s: int) -> int:
	if s >= malha.get_surface_count():
		return 0
	var arr := malha.surface_get_arrays(s)
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	if idx.is_empty():
		return (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return idx.size() / 3
