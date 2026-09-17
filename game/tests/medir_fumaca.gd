## Orcamento da casa da fumaca e da estufa. Ferramenta, nao teste.
##
##   godot --headless --path game --script res://tests/medir_fumaca.gd
##
## Existe para a conversa de "da para por mais coisa aqui?" ter um numero em vez
## de um palpite: quantos triangulos cada planta gasta, quantas superficies
## (= chamadas de desenho) e quantos props viram no no comodo.
extends SceneTree


func _init() -> void:
	for par: Array in [["casa_fumaca", 77551], ["estufa", 77551 + 4242]]:
		var nome: String = par[0]
		var semente: int = par[1]
		var d: Dictionary = (CasaFumacaBuilder.construir(semente) if nome == "casa_fumaca"
			else EstufaBuilder.construir(semente))
		var sup: Dictionary = d["superficies"]
		var props: Array = d["props"]
		print("--- %s (semente %d) ---" % [nome, semente])
		print("  triangulos totais: %d" % int(d["triangulos"]))
		print("  superficies (draw calls da malha): %d" % sup.size())
		for mat: StringName in sup:
			print("    %-18s %5d tri" % [mat, PSXMesh.dados_triangulos(sup[mat])])
		print("  caixas de colisao: %d" % (d["colisao"] as Array).size())
		var por_tipo: Dictionary = {}
		for p: Dictionary in props:
			var t: String = p.get("tipo", "?")
			por_tipo[t] = int(por_tipo.get(t, 0)) + 1
		print("  props: %d" % props.size())
		for t: String in por_tipo:
			print("    %-18s %d" % [t, por_tipo[t]])
	quit()
