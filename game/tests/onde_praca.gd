## Lista os parques mais proximos da origem, com um ponto de calcada em volta.
## Ferramenta, nao teste.
##
##   godot --headless --path game --script res://tests/onde_praca.gd
extends SceneTree


func _init() -> void:
	var achados: Array[Dictionary] = []
	var vistos := {}
	for cz in range(-14, 15):
		for cx in range(-14, 15):
			var q := MalhaUrbana.quadra_de(cx, cz)
			if int(q["uso"]) != MalhaUrbana.Uso.PARQUE:
				continue
			var centro: Vector3 = MalhaUrbana.centro_da_quadra(q)
			var chave := "%d,%d" % [roundi(centro.x), roundi(centro.z)]
			if vistos.has(chave):
				continue
			vistos[chave] = true
			achados.append({
				"centro": centro,
				"x0": int(q["x0"]), "x1": int(q["x1"]),
				"z0": int(q["z0"]), "z1": int(q["z1"]),
				"nome": ParqueBuilder.planta(q)["nome"],
				"traco": int(ParqueBuilder.planta(q)["traco"]),
				"d": Vector2(centro.x, centro.z).length(),
			})
	achados.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["d"]) < float(b["d"]))
	print("parques achados: %d" % achados.size())
	for k in mini(6, achados.size()):
		var a: Dictionary = achados[k]
		var c: Vector3 = a["centro"]
		print("  %-22s traco %d  centro %7.1f, %7.1f  %5.0f m  chunks x %d..%d z %d..%d  metros x %.0f..%.0f z %.0f..%.0f"
			% [a["nome"], a["traco"], c.x, c.z, a["d"], a["x0"], a["x1"], a["z0"], a["z1"],
				float(a["x0"]) * MalhaUrbana.TAM, float(a["x1"]) * MalhaUrbana.TAM,
				float(a["z0"]) * MalhaUrbana.TAM, float(a["z1"]) * MalhaUrbana.TAM])
	quit()
