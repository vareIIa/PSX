## Custo do chunk que tem uma casa da fumaca, contra um vizinho sem. Ferramenta.
##
##   godot --headless --path game --script res://tests/medir_chunk_fumaca.gd
##
## Existe porque a fachada da casa da fumaca vale para TODA casa da fumaca da
## cidade (22 num raio de 24 chunks), e uma peca que se repete tem de caber no
## teto do chunk: 6.000 triangulos e quatro Omni (ART-BIBLE secao 10 e a skill
## psx-city). "Parece barato" nao e medida.
extends SceneTree

## O chunk com a casa da fumaca mais perto da origem, e um vizinho para
## comparar. Ver tests/onde_fumaca.gd.
const COM := Vector2i(3, -6)
const SEM := Vector2i(3, -5)


func _init() -> void:
	KitModular.preparar()
	for c: Vector2i in [COM, SEM]:
		var d := ChunkBuilder.construir(c.x, c.y)
		var sup: Dictionary = d["superficies"]
		var props: Array = d["props"]
		var tris := 0
		for mat: StringName in sup:
			tris += PSXMesh.dados_triangulos(sup[mat])
		var luzes := 0
		var por_tipo: Dictionary = {}
		for p: Dictionary in props:
			var t: String = p.get("tipo", "?")
			por_tipo[t] = int(por_tipo.get(t, 0)) + 1
			if t == "lampada":
				luzes += 1
		var fumaca := false
		for p: Dictionary in props:
			if p.get("tipo", "") == "porta" and p.get("interior", &"") == &"casa_fumaca":
				fumaca = true
		print("--- chunk %s %s ---" % [c, "(casa da fumaca)" if fumaca else ""])
		print("  triangulos: %d de 6000" % tris)
		var nomes: Array = []
		for mat: StringName in sup:
			nomes.append(String(mat))
		nomes.sort()
		print("  superficies: %d  %s" % [sup.size(), ", ".join(nomes)])
		print("  Omni (lampada): %d de 4" % luzes)
		print("  colisao: %d" % (d["colisao"] as Array).size())
		var chaves: Array = por_tipo.keys()
		chaves.sort()
		for t: String in chaves:
			print("    %-16s %d" % [t, por_tipo[t]])
	quit()
