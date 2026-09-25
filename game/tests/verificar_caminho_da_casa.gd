## A malha de caminho da `CasaViva` sai IGUAL com as faces guardadas por
## tamanho (`CasaViva.faces_da_caixa`) e com um BoxMesh por caixa (o jeito antigo).
##
##     godot --path game --headless res://tests/verificar_caminho_da_casa.tscn
##
## O jeito antigo custava 10 a 16 ms por sala no fio principal (regera a malha
## primitiva no RenderingServer a cada caixa). A caixa unitaria escalada, que
## seria ainda mais barata, NAO passa aqui: `get_faces` devolve a posicao
## comprimida da GPU e, no mercado, dez vertices do caminho andavam 8 cm. As duas
## fontes sao assadas com a mesma NavigationMesh da CasaViva, para cada planta e
## tres sementes, e os vertices e poligonos tem de bater.
extends Node


func _ready() -> void:
	var falhas := 0
	for planta: StringName in [&"casa_fumaca", &"mercado"]:
		for semente: int in [11, 222, 3333]:
			var dados := LoteNoMundo.planta_de(planta, semente)
			var todas: Array = dados["colisao"].duplicate()
			todas.append_array(dados.get("so_caminho", []))
			var velha := NavigationMeshSourceGeometryData3D.new()
			var caixa := BoxMesh.new()
			for c: Dictionary in todas:
				caixa.size = c["tamanho"]
				velha.add_faces(caixa.get_faces(), Transform3D(Basis(), c["pos"]))
			var nova := NavigationMeshSourceGeometryData3D.new()
			for c: Dictionary in todas:
				nova.add_faces(CasaViva.faces_da_caixa(c["tamanho"]), Transform3D(Basis(), c["pos"]))
			var a := _assar(velha)
			var b := _assar(nova)
			var iguais := a.get_vertices() == b.get_vertices() \
				and a.get_polygon_count() == b.get_polygon_count()
			if iguais:
				for i in a.get_polygon_count():
					if a.get_polygon(i) != b.get_polygon(i):
						iguais = false
						break
			# Ordem diferente dos mesmos poligonos ainda e o mesmo caminho: compara
			# o conjunto de poligonos, cada um pelas posicoes dos cantos.
			var mesma_forma := iguais or _forma(a) == _forma(b)
			print("[caminho] %s/%d caixas=%d vertices=%d/%d poligonos=%d/%d %s" % [
				planta, semente, todas.size(), a.get_vertices().size(), b.get_vertices().size(),
				a.get_polygon_count(), b.get_polygon_count(),
				"IGUAL" if iguais else ("MESMA FORMA, OUTRA ORDEM" if mesma_forma else "DIFERENTE")])
			if not mesma_forma:
				falhas += 1
				# Quanto difere: cada vertice novo ate o antigo mais perto.
				var va := a.get_vertices()
				var longe := 0
				var maior := 0.0
				for q: Vector3 in b.get_vertices():
					var perto := INF
					for r: Vector3 in va:
						perto = minf(perto, q.distance_to(r))
					maior = maxf(maior, perto)
					if perto > 0.001:
						longe += 1
				var fa := _forma(a)
				var fb := _forma(b)
				var so_b := 0
				for x: String in fb:
					if not fa.has(x):
						so_b += 1
				print("[caminho]   vertices_deslocados=%d maior_deslocamento=%.3f m poligonos_so_no_novo=%d" % [
					longe, maior, so_b])
	print("[caminho] %s" % ("OK" if falhas == 0 else "FALHOU (%d)" % falhas))
	get_tree().quit(0 if falhas == 0 else 1)


func _assar(fonte: NavigationMeshSourceGeometryData3D) -> NavigationMesh:
	var malha := CasaViva.nova_malha_de_caminho()
	NavigationServer3D.bake_from_source_geometry_data(malha, fonte)
	return malha


## Os poligonos como texto, cada um comecando pelo menor canto e a lista ordenada:
## dois caminhos com a mesma forma dao o mesmo texto, em qualquer ordem.
func _forma(m: NavigationMesh) -> PackedStringArray:
	var v := m.get_vertices()
	var saida := PackedStringArray()
	for i in m.get_polygon_count():
		var cantos: Array[String] = []
		for k: int in m.get_polygon(i):
			cantos.append("%.5f,%.5f,%.5f" % [v[k].x, v[k].y, v[k].z])
		var menor := 0
		for k in cantos.size():
			if cantos[k] < cantos[menor]:
				menor = k
		var girado: Array[String] = []
		for k in cantos.size():
			girado.append(cantos[(menor + k) % cantos.size()])
		saida.append("|".join(PackedStringArray(girado)))
	saida.sort()
	return saida
