## A arvore de calcada embaixo da rede: quanto dela a poda tira (rodada 3).
##
##     godot --headless --path game res://tests/sonda_poda.tscn -- --chunk=-6,3
##
## Para cada arvore de rua do chunk: especie, altura do fio mais baixo por perto,
## a escala de `_cabe_embaixo_do_fio` e quantos triangulos de folha sobram com e
## sem a poda. Cena, e nao --script (ChunkBuilder precisa dos autoloads).
extends Node


func _ready() -> void:
	var c := Vector2i(-6, 3)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--chunk="):
			var p := a.trim_prefix("--chunk=").split(",")
			c = Vector2i(int(p[0]), int(p[1]))
	var poda := KitRede.faixas_de_poda(c.x, c.y)
	var bordas := MalhaUrbana.bordas(c.x, c.y)
	print("[sonda_poda] chunk %s: %d pontos de fio" % [c, poda.size()])
	for base: Vector3 in ChunkBuilder.arvores(c.x, c.y):
		var rua := ChunkBuilder._arvore_de_rua(bordas, base)
		var especie := ChunkBuilder._especie_de_rua(c.x, c.y, base, not rua)
		var fio := INF
		for q: Vector3 in poda:
			if Vector2(q.x - base.x, q.z - base.z).length() < 4.0:
				fio = minf(fio, q.y)
		var tris := []
		for com_poda in [false, true]:
			var sup := {}
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(base)
			if especie == &"palmeira":
				Vegetacao.palmeira(sup, [] as Array[Dictionary], base, true, rng,
					poda if com_poda else PackedVector3Array())
			else:
				Vegetacao.arvore(sup, [] as Array[Dictionary], base, especie, 0.1, rng,
					poda if com_poda else PackedVector3Array())
			var t := 0
			for k: StringName in sup:
				if String(k).begins_with("copa") or String(k).begins_with("vegetacao") \
						or String(k).begins_with("plantas"):
					t += (sup[k]["i"] as PackedInt32Array).size() / 3
			tris.append(t)
		print("  %s em (%.1f, %.1f) rua=%s: fio %.2f m, folha sem poda %d, com poda %d" % [
			especie, base.x, base.z, rua, fio, tris[0], tris[1]])
	get_tree().quit()
