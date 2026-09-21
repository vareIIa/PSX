extends SceneTree
func _initialize() -> void:
	_rodar.call_deferred()
func _rodar() -> void:
	var alvo := Vector2(18, 152)
	var cx := floori(alvo.x / 32.0)
	var cz := floori(alvo.y / 32.0)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			_montar(cx + dx, cz + dz)
	await physics_frame
	await physics_frame
	var espaco := root.get_world_3d().direct_space_state
	print("chunk %d,%d plano=%s parque=%s" % [cx, cz, Relevo.plano(cx, cz), int(MalhaUrbana.quadra_de(cx, cz)["uso"])])
	for dx in [-6, -3, 0, 3, 6]:
		for dz in [-6, 0, 6]:
			var x: float = alvo.x + dx
			var z: float = alvo.y + dz
			var h := Relevo.altura(x, z)
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, h + 1.5, z), Vector3(x, h - 2.0, z))
			var r := espaco.intersect_ray(q)
			print("  (%.0f,%.0f) chao %.2f  raio %s" % [x, z, h, str((r["position"] as Vector3).y) if not r.is_empty() else "NADA"])
	quit(0)
func _montar(cx: int, cz: int) -> void:
	var dados := ChunkBuilder.construir(cx, cz)
	var raiz := Node3D.new()
	root.add_child(raiz)
	raiz.position = Vector3(cx * 32, 0, cz * 32)
	var corpo := StaticBody3D.new()
	raiz.add_child(corpo)
	for caixa: Dictionary in dados["colisao"]:
		var forma := CollisionShape3D.new()
		if caixa.has("altura"):
			var mapa := HeightMapShape3D.new()
			mapa.map_width = int(caixa["lado"])
			mapa.map_depth = int(caixa["lado"])
			mapa.map_data = caixa["altura"]
			forma.shape = mapa
			forma.position = caixa["pos"]
			forma.scale = Vector3.ONE * float(caixa.get("escala", 1.0))
			corpo.add_child(forma)
			continue
		var box := BoxShape3D.new()
		box.size = caixa["tamanho"]
		forma.shape = box
		forma.position = caixa["pos"]
		if caixa.has("giro"):
			forma.rotation = caixa["giro"]
		corpo.add_child(forma)
