## Custo e rendimento da varredura de lugares do GPS. Ferramenta, nao teste.
##
##   godot --headless --path game --script res://tests/custo_gps.gd
extends SceneTree


func _init() -> void:
	for raio: int in [8, 10, 12, 14, 16]:
		var t0 := Time.get_ticks_usec()
		var por_categoria: Dictionary = {}
		for cz in range(-raio, raio + 1):
			for cx in range(-raio, raio + 1):
				for ponto: Dictionary in ChunkBuilder.pontos_de_interesse(cx, cz):
					var c: StringName = ponto["tipo"]
					if c == &"porta":
						c = ponto["interior"]
					por_categoria[c] = int(por_categoria.get(c, 0)) + 1
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		var partes := PackedStringArray()
		for c: StringName in por_categoria:
			partes.append("%s=%d" % [c, por_categoria[c]])
		partes.sort()
		print("raio %2d (%4d m)  %6.2f ms   %s"
			% [raio, raio * 32, ms, " ".join(partes)])
	quit()
