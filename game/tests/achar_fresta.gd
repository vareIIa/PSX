## Qual PECA da casca deixou a fresta por onde o raio sai.
##
##     godot --headless --path game --script res://tests/achar_fresta.gd -- \
##         --modelo=PICAPE --pitch=-10 --yaw=0 --raios=4
##
## Por que existe
## -------------
## `medir_cabine_cobertura --poses` diz QUANTO vaza e em que ponto da chapa o
## raio sai. Nao diz por onde ele passou. Com so isso eu chutei duas vezes
## seguidas — a cantoneira e a junta em T da revelacao —, implementei as duas, e
## o numero nao se moveu um decimo: 0,42% a 2,37% antes e depois. Medida que nao
## muda acusa o palpite, nao o conserto.
##
## Aqui o raio que vaza e cruzado com CADA peca da casca, uma por uma, e sai
## impressa a distancia de aproximacao de cada uma. Duas pecas a poucos
## milimetros do raio: a fresta e entre elas, e a largura dela e a soma. Uma so:
## aquela peca acabou antes de encostar na vizinha.
##
## As faixas de indice de cada peca vem de `CabineCasca.marcas`, preenchida
## durante a montagem.
extends SceneTree

const W := 240
const H := 135
const FOV := 74.0

const L_CAB := 1
const L_JAN := 2
const L_LAT := 8
const L_VID := 16

## Quantos pontos por triangulo na medida de distancia. 15 (grade baricentrica
## de 4) pega borda, meio e vertice — a fresta e sempre de borda.
const SUB := 4

var _modelo := "PICAPE"
var _pitch := -10.0
var _yaw := 0.0
var _quantos := 3
var _nomes := {}
var _aberturas: Array = []


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--modelo="):
			_modelo = a.trim_prefix("--modelo=").to_upper()
		elif a.begins_with("--pitch="):
			_pitch = float(a.trim_prefix("--pitch="))
		elif a.begins_with("--yaw="):
			_yaw = float(a.trim_prefix("--yaw="))
		elif a.begins_with("--raios="):
			_quantos = int(a.trim_prefix("--raios="))
	_rodar.call_deferred()


func _rodar() -> void:
	var modelos := {
		"MAREA": Carroceria.Modelo.MAREA, "SEDA": Carroceria.Modelo.SEDA,
		"HATCH": Carroceria.Modelo.HATCH, "PERUA": Carroceria.Modelo.PERUA,
		"PICAPE": Carroceria.Modelo.PICAPE, "FUSCA": Carroceria.Modelo.FUSCA,
	}
	if not modelos.has(_modelo):
		push_error("modelo desconhecido: %s" % _modelo)
		quit(1)
		return
	var modelo: int = modelos[_modelo]

	var pai := Node3D.new()
	root.add_child(pai)
	var medidas := Carroceria.montar(modelo, CarroCena.TINTA, CarroCena.SEMENTE)
	_aberturas = medidas.get("aberturas", [])
	var cab := CarroCabine.new()
	pai.add_child(cab)
	cab.montar(medidas)
	var olho := cab.olho()

	# As pecas da casca, cada uma com os proprios triangulos, em espaco do
	# carro. Montadas a parte: na cabine de verdade elas viram uma malha so e o
	# nome de cada uma se perde.
	var pecas := _pecas_da_casca(medidas, cab, olho)

	for mi: MeshInstance3D in _malhas(cab):
		var e_vidro := mi.name == "Vidros" or mi.name.begins_with("Janela")
		var camada := L_JAN if e_vidro else L_CAB
		var xf := _ate(mi, cab)
		var pts := PackedVector3Array()
		for t: Array in _tris(mi.mesh, null):
			var a: Vector3 = xf * t[0]
			var b: Vector3 = xf * t[1]
			var c: Vector3 = xf * t[2]
			var cruz := (b - a).cross(c - a)
			if cruz.length() < 1e-7:
				continue
			if e_vidro or (-cruz.normalized()).dot(olho - (a + b + c) / 3.0) > 0.0:
				pts.append_array([a, b, c])
		_corpo(pai, pts, camada, String(mi.name))

	var celulas := {
		"parabrisa": Carroceria.uv(Carroceria.C_PARABRISA).grow(1.0 / Carroceria.ATLAS),
		"vidro_lado": Carroceria.uv(Carroceria.C_VIDRO_LADO).grow(1.0 / Carroceria.ATLAS),
		"vidro_tras": Carroceria.uv(Carroceria.C_VIDRO_TRAS).grow(1.0 / Carroceria.ATLAS),
	}
	var por_cel := {"lataria": PackedVector3Array()}
	for k: String in celulas:
		por_cel[k] = PackedVector3Array()
	for t: Array in _tris(medidas["corpo"] as ArrayMesh, celulas):
		por_cel[t[3]].append_array([t[0], t[1], t[2]])
	for k: String in por_cel:
		_corpo(pai, por_cel[k], L_LAT if k == "lataria" else L_VID, k)

	for i in 3:
		await physics_frame
	var espaco := pai.get_world_3d().direct_space_state

	print("\n=== %s  olho %s  pitch %+.1f yaw %+.1f ===" % [_modelo, olho, _pitch, _yaw])
	print("assoalho da casca em y = %.3f  (%.3f abaixo do olho)"
		% [CabineCasca.assoalho(medidas["perfil_cabine"]),
			olho.y - CabineCasca.assoalho(medidas["perfil_cabine"])])

	print("-- caixa de cada peca da casca (espaco do carro):")
	for nome: String in pecas:
		var tris: PackedVector3Array = pecas[nome]
		var caixa := AABB(tris[0], Vector3.ZERO)
		for p: Vector3 in tris:
			caixa = caixa.expand(p)
		print("   %-12s  x %+.3f..%+.3f  y %+.3f..%+.3f  z %+.3f..%+.3f  (%d tri)"
			% [nome, caixa.position.x, caixa.end.x, caixa.position.y,
				caixa.end.y, caixa.position.z, caixa.end.z, tris.size() / 3])

	var vazam := _vazamentos(espaco, olho)
	if vazam.is_empty():
		print("nenhum vazamento nesta pose.")
		quit(0)
		return
	# Agrupa por ponto de saida e ataca os maiores grupos: um raio por familia
	# de fresta, e nao tres raios da mesma.
	var grupos := {}
	for v: Dictionary in vazam:
		var p: Vector3 = v["saida"]
		var chave := "%s z=%.1f y=%+.1f" % ["esq" if p.x < 0.0 else "dir",
			snappedf(p.z, 0.1), snappedf(p.y - olho.y, 0.1)]
		if not grupos.has(chave):
			grupos[chave] = []
		(grupos[chave] as Array).append(v)
	var chaves: Array = grupos.keys()
	var maior := func(a, b) -> bool: return grupos[a].size() > grupos[b].size()
	chaves.sort_custom(maior)

	for k in chaves.slice(0, _quantos):
		var lista: Array = grupos[k]
		var v: Dictionary = lista[lista.size() / 2]
		print("\n--- %s  (%d px)  pixel %s" % [k, lista.size(), v["px"]])
		print("    raio: olho %s -> saida %s  (%.3f m)"
			% [olho, v["saida"], (v["saida"] as Vector3).distance_to(olho)])
		_nomear(pecas, olho, v["saida"])

	pai.queue_free()
	quit(0)


## Distancia de aproximacao entre o raio e cada peca, da mais perto para a mais
## longe. E o numero que nomeia a fresta.
func _nomear(pecas: Dictionary, olho: Vector3, saida: Vector3) -> void:
	var dir := (saida - olho).normalized()
	var comp := olho.distance_to(saida)
	var linhas: Array = []
	for nome: String in pecas:
		var tris: PackedVector3Array = pecas[nome]
		var melhor := INF
		var onde := Vector3.ZERO
		var t_melhor := 0.0
		for i in range(0, tris.size(), 3):
			for amostra: Vector3 in _amostras(tris[i], tris[i + 1], tris[i + 2]):
				var t := clampf((amostra - olho).dot(dir), 0.0, comp)
				var d := amostra.distance_to(olho + dir * t)
				if d < melhor:
					melhor = d
					onde = amostra
					t_melhor = t
		if melhor < INF:
			linhas.append([nome, melhor, onde, t_melhor])
	linhas.sort_custom(func(a, b): return a[1] < b[1])
	for l: Array in linhas.slice(0, 6):
		print("    %7.1f mm  %-12s em %s  (a %.2f m do olho)"
			% [float(l[1]) * 1000.0, l[0], l[2], l[3]])


## Pontos de um triangulo numa grade baricentrica.
func _amostras(a: Vector3, b: Vector3, c: Vector3) -> Array:
	var out: Array = []
	for i in SUB + 1:
		for j in SUB + 1 - i:
			var u := float(i) / float(SUB)
			var v := float(j) / float(SUB)
			out.append(a + (b - a) * u + (c - a) * v)
	return out


## Os raios que saem pela chapa, com o ponto de saida de cada um.
func _vazamentos(espaco: PhysicsDirectSpaceState3D, olho: Vector3) -> Array:
	var base := Basis(Vector3.UP, deg_to_rad(_yaw)) * Basis(Vector3.RIGHT, deg_to_rad(_pitch))
	var th := tan(deg_to_rad(FOV) * 0.5)
	var asp := float(W) / float(H)
	var out: Array = []
	for py in H:
		for px in W:
			var d := base * Vector3((2.0 * (px + 0.5) / W - 1.0) * th * asp,
				(1.0 - 2.0 * (py + 0.5) / H) * th, -1.0).normalized()
			var fim := olho + d * 6.0
			var lat := _raio(espaco, olho, fim, L_LAT)
			if lat.is_empty():
				continue
			var ponto: Vector3 = lat["position"]
			if _saida_por_abertura(ponto) != "":
				continue
			var d_lat := ponto.distance_to(olho)
			var cabine := _raio(espaco, olho, fim, L_CAB)
			if not cabine.is_empty() and _dist(cabine, olho) < d_lat:
				continue
			var janela := _raio(espaco, olho, fim, L_JAN)
			if not janela.is_empty() and _dist(janela, olho) < d_lat:
				continue
			out.append({"px": Vector2i(px, py), "saida": ponto})
	return out


## Cada peca da casca com os proprios triangulos, em espaco do carro.
func _pecas_da_casca(medidas: Dictionary, cab: CarroCabine, olho: Vector3) -> Dictionary:
	var info: Dictionary = medidas["perfil_cabine"]
	var ficha := CabineFicha.de(CarroCabine._modelo_de(medidas))
	var sup := {}
	CabineCasca.montar(sup, &"painel", info, ficha, olho)
	var dados: Dictionary = sup[&"painel"]
	var v: PackedVector3Array = dados["v"]
	var idx: PackedInt32Array = dados["i"]
	var out := {}
	for m: Array in CabineCasca.marcas:
		var pts := PackedVector3Array()
		for i in range(int(m[1]), int(m[2])):
			pts.append(v[idx[i]])
		if not pts.is_empty():
			out[String(m[0])] = pts
	return out


func _saida_por_abertura(p: Vector3) -> String:
	for a: Dictionary in _aberturas:
		var n: Vector3 = a["normal"]
		var c: Vector3 = a["centro"]
		if absf((p - c).dot(n)) > 0.06:
			continue
		var pts: PackedVector3Array = a["pontos"]
		var dentro := true
		var sinal := 0.0
		for i in 4:
			var q0 := pts[i]
			var q1 := pts[(i + 1) % 4]
			var lado := ((q1 - q0).cross(p - q0)).dot(n)
			if absf(lado) < 1e-6:
				continue
			if sinal == 0.0:
				sinal = signf(lado)
			elif signf(lado) != sinal:
				dentro = false
				break
		if dentro:
			return String(a["tipo"])
	return ""


func _raio(espaco: PhysicsDirectSpaceState3D, de: Vector3, ate: Vector3,
		mascara: int) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(de, ate, mascara)
	q.hit_back_faces = true
	return espaco.intersect_ray(q)


func _dist(r: Dictionary, o: Vector3) -> float:
	if r.is_empty():
		return INF
	return (r["position"] as Vector3).distance_to(o)


func _corpo(pai: Node3D, pts: PackedVector3Array, camada: int, rotulo: String) -> void:
	if pts.is_empty():
		return
	var sb := StaticBody3D.new()
	sb.collision_layer = camada
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := ConcavePolygonShape3D.new()
	sh.backface_collision = true
	sh.set_faces(pts)
	cs.shape = sh
	sb.add_child(cs)
	pai.add_child(sb)
	_nomes[sb.get_instance_id()] = rotulo


func _malhas(no: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for f: Node in no.get_children():
		if f is MeshInstance3D and (f as MeshInstance3D).mesh != null \
				and (f as MeshInstance3D).visible:
			out.append(f)
		out.append_array(_malhas(f))
	return out


func _ate(mi: Node3D, cab: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var no: Node = mi
	while no != null and no != cab:
		if no is Node3D:
			xf = (no as Node3D).transform * xf
		no = no.get_parent()
	return xf


func _tris(malha: Mesh, celulas) -> Array:
	var out: Array = []
	for s in malha.get_surface_count():
		var arr := malha.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var uv = arr[Mesh.ARRAY_TEX_UV]
		var idx = arr[Mesh.ARRAY_INDEX]
		var ii := PackedInt32Array()
		if idx == null or (idx as PackedInt32Array).is_empty():
			for i in v.size():
				ii.append(i)
		else:
			ii = idx
		for i in range(0, ii.size() - 2, 3):
			var t := [v[ii[i]], v[ii[i + 1]], v[ii[i + 2]]]
			if celulas != null:
				var tipo := "lataria"
				var m: Vector2 = (uv[ii[i]] + uv[ii[i + 1]] + uv[ii[i + 2]]) / 3.0
				for k: String in celulas:
					if (celulas[k] as Rect2).has_point(m):
						tipo = k
				t.append(tipo)
			out.append(t)
	return out
