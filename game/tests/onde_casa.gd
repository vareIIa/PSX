## Lista as casas comuns (interior `casa`) mais proximas da origem, com o giro
## da porta, para a captura conseguir enquadrar a fachada. Ferramenta, nao teste.
##
##   godot --headless --path game --script res://tests/onde_casa.gd
extends SceneTree


func _init() -> void:
	var achados: Array[Dictionary] = []
	for cz in range(-12, 13):
		for cx in range(-12, 13):
			for ponto: Dictionary in ChunkBuilder.pontos_de_interesse(cx, cz):
				if ponto["tipo"] != &"porta":
					continue
				if ponto["interior"] != &"casa":
					continue
				var p: Vector3 = ponto["pos"]
				var mundo := Vector3(float(cx) * 32.0 + p.x, p.y,
					float(cz) * 32.0 + p.z)
				achados.append({"chunk": Vector2i(cx, cz), "mundo": mundo,
					"giro": float(ponto["giro"]),
					"d": Vector2(mundo.x, mundo.z).length()})
	achados.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["d"]) < float(b["d"]))
	print("casas num raio de 12 chunks: %d" % achados.size())
	for k in mini(8, achados.size()):
		var a: Dictionary = achados[k]
		var m: Vector3 = a["mundo"]
		var g: float = a["giro"]
		# Onde a camera fica para olhar a porta de frente, a 5 m dela.
		var olho := m + Vector3(sin(g), 0.0, cos(g)) * 5.0
		print("  chunk %-9s porta %7.1f,%7.1f  giro %5.2f  camera %7.1f,%7.1f  %5.0f m"
			% [a["chunk"], m.x, m.z, g, olho.x, olho.z, a["d"]])
	quit()
