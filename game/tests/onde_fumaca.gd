## Lista as casas da fumaca mais proximas da origem. Ferramenta, nao teste.
##
##   godot --headless --path game --script res://tests/onde_fumaca.gd
extends SceneTree


func _init() -> void:
	var achados: Array[Dictionary] = []
	for cz in range(-24, 25):
		for cx in range(-24, 25):
			for ponto: Dictionary in ChunkBuilder.pontos_de_interesse(cx, cz):
				if ponto["tipo"] != &"porta":
					continue
				if ponto["interior"] != &"casa_fumaca":
					continue
				var p: Vector3 = ponto["pos"]
				var mundo := Vector3(float(cx) * 32.0 + p.x, p.y,
					float(cz) * 32.0 + p.z)
				var achado := {"chunk": Vector2i(cx, cz), "mundo": mundo,
					"d": Vector2(mundo.x, mundo.z).length()}
				# Casa que existe na rua: onde fica o vao, e dois pontos para a
				# captura — na calcada olhando o vao, e dentro olhando a TV.
				if bool(ponto.get("mundo", false)):
					var t: Transform3D = ponto["planta"]
					t.origin += Vector3(float(cx) * 32.0, 0.0, float(cz) * 32.0)
					achado["vao"] = t * KitFumaca.centro_do_vao()
					achado["rua"] = t * Vector3(2.2, 0.0, -3.2)
					achado["sala"] = t * Vector3(2.2, 0.0, 1.4)
					achado["tv"] = t * CasaFumacaBuilder.TV
				achados.append(achado)
	achados.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["d"]) < float(b["d"]))
	print("casas da fumaca num raio de 24 chunks: %d" % achados.size())
	for k in mini(10, achados.size()):
		var a: Dictionary = achados[k]
		var m: Vector3 = a["mundo"]
		print("  chunk %-10s  mundo %7.1f, %7.1f   %6.0f m da origem"
			% [a["chunk"], m.x, m.z, a["d"]])
		if a.has("vao"):
			var v: Vector3 = a["vao"]
			var r: Vector3 = a["rua"]
			var sl: Vector3 = a["sala"]
			var tv: Vector3 = a["tv"]
			print("      vao %.2f,%.2f  --ir-para=%.2f,%.2f,%.2f,%.2f  sala=%.2f,%.2f,%.2f,%.2f"
				% [v.x, v.z, r.x, r.z, v.x, v.z, sl.x, sl.z, tv.x, tv.z])
	quit()
