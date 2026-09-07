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
				achados.append({"chunk": Vector2i(cx, cz), "mundo": mundo,
					"d": Vector2(mundo.x, mundo.z).length()})
	achados.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["d"]) < float(b["d"]))
	print("casas da fumaca num raio de 24 chunks: %d" % achados.size())
	for k in mini(10, achados.size()):
		var a: Dictionary = achados[k]
		var m: Vector3 = a["mundo"]
		print("  chunk %-10s  mundo %7.1f, %7.1f   %6.0f m da origem"
			% [a["chunk"], m.x, m.z, a["d"]])
	quit()
