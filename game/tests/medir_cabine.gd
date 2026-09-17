## Mede o que o motorista enxerga da propria cabine, triangulo por triangulo.
##
##     godot --headless --path game --script res://tests/medir_cabine.gd
##
## Por que existe
## --------------
## "A lateral esquerda do carro continua invisivel quando estamos dentro dele."
## O `PLANO_ESTRADA_AAA` ja dava esse defeito como consertado — caixilho, coluna
## B e painel atras do ombro foram acrescentados. Se o jogador ainda ve um buraco,
## ou as pecas estao viradas para o lado errado (a memoria do projeto registra que
## a face aparece do lado OPOSTO ao produto vetorial, e isso ja derrubou o Fusca e
## os cinco carros de caixa), ou elas existem e nao cobrem o que o olho ve.
##
## Olhar a captura nao separa as duas hipoteses. Esta conta separa: para cada
## triangulo das laterais, o olho esta do lado em que ele se desenha?
extends SceneTree


func _initialize() -> void:
	print("\n=== cabine vista do banco do motorista ===\n")
	var medidas := Carroceria.montar(CarroCena.MODELO, CarroCena.TINTA, CarroCena.SEMENTE)
	var cab := CarroCabine.new()
	root.add_child(cab)
	cab.montar(medidas)
	var olho := cab.olho()
	var meia := float(medidas["largura"]) * 0.5
	print("-- olho em %s, meia largura %.2f, teto %.2f" % [olho, meia, float(medidas["altura"])])

	var faixas := {
		"lateral ESQUERDA": func(c: Vector3) -> bool: return c.x < -meia * 0.6,
		"lateral DIREITA": func(c: Vector3) -> bool: return c.x > meia * 0.6,
	}
	for nome: String in faixas:
		var filtro: Callable = faixas[nome]
		var vistos := 0
		var costas := 0
		var area_vista := 0.0
		var area_costas := 0.0
		var alturas := Vector2(INF, -INF)
		for mi: MeshInstance3D in _malhas(cab):
			var xf := _ate_cabine(mi, cab)
			for tri: Array in _triangulos(mi.mesh):
				var a: Vector3 = xf * tri[0]
				var b: Vector3 = xf * tri[1]
				var c: Vector3 = xf * tri[2]
				var centro := (a + b + c) / 3.0
				if not filtro.call(centro):
					continue
				var cruz := (b - a).cross(c - a)
				var area := cruz.length() * 0.5
				if area < 1e-6:
					continue
				# O lado que desenha e o OPOSTO do produto vetorial (Godot:
				# frente em sentido horario visto da camera).
				var desenha := -cruz.normalized()
				if desenha.dot(olho - centro) > 0.0:
					vistos += 1
					area_vista += area
					alturas.x = minf(alturas.x, minf(a.y, minf(b.y, c.y)))
					alturas.y = maxf(alturas.y, maxf(a.y, maxf(b.y, c.y)))
				else:
					costas += 1
					area_costas += area
		print("-- %s: %d triangulos voltados para o olho (%.3f m2), %d de costas (%.3f m2); visiveis de y=%.2f a %.2f"
			% [nome, vistos, area_vista, costas, area_costas, alturas.x, alturas.y])
		_placas(cab, filtro, olho, nome)
	quit(0)


## So as PLACAS laterais: triangulos com normal quase em X. Uma caixa sempre tem
## metade das faces de costas para qualquer ponto; uma placa, nao — placa de
## costas e placa invisivel.
func _placas(cab: Node3D, filtro: Callable, olho: Vector3, nome: String) -> void:
	var grupos := {}
	for mi: MeshInstance3D in _malhas(cab):
		var xf := _ate_cabine(mi, cab)
		for tri: Array in _triangulos(mi.mesh):
			var a: Vector3 = xf * tri[0]
			var b: Vector3 = xf * tri[1]
			var c: Vector3 = xf * tri[2]
			var centro := (a + b + c) / 3.0
			if not filtro.call(centro):
				continue
			var cruz := (b - a).cross(c - a)
			if cruz.length() < 2e-6:
				continue
			var desenha := -cruz.normalized()
			if absf(desenha.x) < 0.9:
				continue
			var ve := desenha.dot(olho - centro) > 0.0
			var chave := "%s x=%.2f desenha para %s" % ["VISTA " if ve else "COSTAS", snappedf(centro.x, 0.05), "+X" if desenha.x > 0 else "-X"]
			if not grupos.has(chave):
				grupos[chave] = [0.0, INF, -INF, INF, -INF]
			var g: Array = grupos[chave]
			g[0] += cruz.length() * 0.5
			g[1] = minf(g[1], minf(a.y, minf(b.y, c.y)))
			g[2] = maxf(g[2], maxf(a.y, maxf(b.y, c.y)))
			g[3] = minf(g[3], minf(a.z, minf(b.z, c.z)))
			g[4] = maxf(g[4], maxf(a.z, maxf(b.z, c.z)))
	for chave: String in grupos:
		var g: Array = grupos[chave]
		print("     %s  %-40s area %.3f  y %.2f..%.2f  z %.2f..%.2f" % [nome.substr(8), chave, g[0], g[1], g[2], g[3], g[4]])


func _malhas(no: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for filho: Node in no.get_children():
		if filho is MeshInstance3D and (filho as MeshInstance3D).mesh != null:
			out.append(filho)
		out.append_array(_malhas(filho))
	return out


func _ate_cabine(mi: Node3D, cab: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var no: Node = mi
	while no != null and no != cab:
		if no is Node3D:
			xf = (no as Node3D).transform * xf
		no = no.get_parent()
	return xf


func _triangulos(malha: Mesh) -> Array:
	var out: Array = []
	for s in malha.get_surface_count():
		var arr := malha.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx = arr[Mesh.ARRAY_INDEX]
		if idx == null or (idx as PackedInt32Array).is_empty():
			for i in range(0, v.size() - 2, 3):
				out.append([v[i], v[i + 1], v[i + 2]])
		else:
			var ii: PackedInt32Array = idx
			for i in range(0, ii.size() - 2, 3):
				out.append([v[ii[i]], v[ii[i + 1]], v[ii[i + 2]]])
	return out
