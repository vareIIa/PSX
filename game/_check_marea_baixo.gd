## Sonda: que geometria do Marea fica ABAIXO do plano em que o pneu toca o chao.
##
## Existe por causa de uma lamina escura que aparece pendurada sob o para-choque
## dianteiro em qualquer plano rente ao chao. Ela nao da erro, nao tem material
## proprio e nao some com o farol apagado, entao adivinhar de que peca ela e sai
## mais caro do que perguntar a malha.
##
##     godot --headless --path game --script _check_marea_baixo.gd
extends SceneTree


func _init() -> void:
	var medidas := Carroceria.montar(Carroceria.Modelo.MAREA,
		Color(0.90, 0.88, 0.80), 4410)
	for chave: String in ["corpo", "luzes"]:
		var malha := medidas[chave] as ArrayMesh
		if malha == null:
			continue
		print("--- %s: %d superficies" % [chave, malha.get_surface_count()])
		for si in malha.get_surface_count():
			var arrays := malha.surface_get_arrays(si)
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var min_y := 1e9
			var abaixo := 0
			var piores: Array = []
			for k in v.size():
				min_y = minf(min_y, v[k].y)
				if v[k].y < 0.0:
					abaixo += 1
					if piores.size() < 12:
						piores.append(v[k])
			print("  sup %d: %d vertices, %d triangulos, y minimo %.4f, %d abaixo de zero"
				% [si, v.size(), idx.size() / 3, min_y, abaixo])
			for pv: Vector3 in piores:
				print("    abaixo: (%.3f, %.3f, %.3f)" % [pv.x, pv.y, pv.z])
	quit()
