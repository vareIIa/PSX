## Janela piscando: duas superficies no MESMO plano, uma por cima da outra.
##
##     godot --headless --path game res://tests/bancada_coplanar.tscn
##     ... -- --raio=6              chunks de -6 a 6 em volta de --centro (padrao 0,0)
##     ... -- --centro=-9,9
##     ... -- --coords=-9,9;-2,-2   so estes chunks, com cada par listado
##     ... -- --folga=0.004         distancia entre planos que ainda conta (m)
##
## Por que existe
## -------------
## O usuario viu as janelas do predio do bar piscando (24/09/2026): em
## `_predio_do_bar` a janela era um quad no plano exato da fachada. O
## depth buffer sorteia a cada quadro qual das duas aparece, e com a camera
## andando isso vira pisca-pisca. Foto parada nao prova nada (o sorteio sai
## igual num quadro so), e procurar no olho acha um predio de cada vez.
##
## Aqui cada chunk sai de `ChunkBuilder.construir`, como o jogo monta, e todo
## triangulo e comparado com os do mesmo plano: mesma normal (ate ~0,8 grau) e
## a distancia entre os planos abaixo de `folga`. Os dois triangulos projetados
## no plano sao recortados um pelo outro (Sutherland-Hodgman); area em comum
## acima de 1 cm2 e um par que pisca.
##
## Saida: `[coplanar] chunk=cx,cz pares=N area=m2 bar=0|1` por chunk, os pares
## de material mais frequentes e, com `--coords`, cada par com a posicao no
## mundo. Termina com `[coplanar] total ...`.
extends Node

const AREA_MIN := 0.0001
const COS_MAX := 0.9999
const Q_NORMAL := 100.0

var _folga := 0.004
var _coords: Array[Vector2i] = []
var _detalhe := false
## Triangulos do chunk corrente, na ordem das faces do corpo de raio.
var _tris: Array = []
var _corpo: StaticBody3D
## Normal de cada face do corpo (o chunk e os oito vizinhos, nesta ordem).
var _normais := PackedVector3Array()
## Face do corpo que e comodo de janela (diorama): so se ve pela janela.
var _diorama := PackedByteArray()
var _cache := {}
## Espaco livre minimo na frente da sobreposicao para alguem a ver: o fundo do
## movel a 1 cm da parede nao aparece.
const FOLGA_DE_VISTA := 0.25
var _depurar := 0
var _caixas := false
var _filtro := ""
## `--peca=#cor`: em que chunks a peca aparece, e com quanta area visivel.
var _peca := ""


func _ready() -> void:
	var raio := 6
	var centro := Vector2i.ZERO
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--raio="):
			raio = arg.trim_prefix("--raio=").to_int()
		elif arg.begins_with("--centro="):
			var p := arg.trim_prefix("--centro=").split(",")
			centro = Vector2i(p[0].to_int(), p[1].to_int())
		elif arg.begins_with("--coords="):
			for par: String in arg.trim_prefix("--coords=").split(";"):
				var p := par.split(",")
				_coords.append(Vector2i(p[0].to_int(), p[1].to_int()))
			_detalhe = true
		elif arg == "--depurar":
			_depurar = 6
		elif arg.begins_with("--peca="):
			_peca = arg.trim_prefix("--peca=")
		elif arg == "--caixas":
			_caixas = true
		elif arg.begins_with("--filtro="):
			_filtro = arg.trim_prefix("--filtro=")
		elif arg.begins_with("--folga="):
			_folga = arg.trim_prefix("--folga=").to_float()
	if _coords.is_empty():
		for cz in range(centro.y - raio, centro.y + raio + 1):
			for cx in range(centro.x - raio, centro.x + raio + 1):
				_coords.append(Vector2i(cx, cz))
	_rodar.call_deferred()


func _rodar() -> void:
	var total_pares := 0
	var total_area := 0.0
	var vis_pares := 0
	var vis_area := 0.0
	var vis_por_par := {}
	var vis_por_par_area := {}
	var vis_por_peca := {}
	var chunks_com := 0
	var por_par := {}
	var por_par_area := {}
	var bar_pares := 0
	var t0 := Time.get_ticks_msec()
	for c: Vector2i in _coords:
		var dados := _dados(c)
		var tem_bar := false
		for p: Dictionary in dados["props"]:
			if String(p.get("tipo", "")) in ["ponto_bar", "sinuca"]:
				tem_bar = true
		var achados := _pares(dados["superficies"])
		await _montar_corpo(c)
		var area := 0.0
		var area_vis := 0.0
		var n_vis := 0
		for a: Dictionary in achados:
			a["visivel"] = _visivel(a)
			if a["visivel"]:
				n_vis += 1
				area_vis += float(a["area"])
				var cv: String = a["par"]
				vis_por_par[cv] = int(vis_por_par.get(cv, 0)) + 1
				vis_por_par_area[cv] = float(vis_por_par_area.get(cv, 0.0)) + float(a["area"])
				for pc: String in a["pecas"]:
					vis_por_peca[pc] = float(vis_por_peca.get(pc, 0.0)) + float(a["area"])
			area += float(a["area"])
			var chave: String = a["par"]
			por_par[chave] = int(por_par.get(chave, 0)) + 1
			por_par_area[chave] = float(por_par_area.get(chave, 0.0)) + float(a["area"])
		if not achados.is_empty():
			chunks_com += 1
		if tem_bar:
			bar_pares += achados.size()
		total_pares += achados.size()
		total_area += area
		vis_pares += n_vis
		vis_area += area_vis
		if not _peca.is_empty():
			var na := 0.0
			var exemplo := ""
			for a: Dictionary in achados:
				if bool(a["visivel"]) and String(a["caixas"]).contains(_peca):
					na += float(a["area"])
					if exemplo.is_empty():
						exemplo = String(a["caixas"])
			if na > 0.0:
				print("[coplanar] peca_no_chunk %d,%d area=%.2f %s" % [c.x, c.y, na, exemplo])
		print("[coplanar] chunk=%d,%d pares=%d area=%.2f visiveis=%d area_visivel=%.2f bar=%d"
			% [c.x, c.y, achados.size(), area, n_vis, area_vis, 1 if tem_bar else 0])
		if _detalhe:
			achados.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
				return float(x["area"]) > float(y["area"]))
			achados = achados.filter(func(x: Dictionary) -> bool:
				return bool(x["visivel"]) and (_filtro.is_empty()
					or (String(x["par"]) + " " + String(x["caixas"])).contains(_filtro)))
			for a: Dictionary in achados.slice(0, 40):
				var w: Vector3 = Vector3(a["onde"]) + Vector3(c.x * KitModular.CHUNK, 0.0,
					c.y * KitModular.CHUNK)
				print("[coplanar]   %s area=%.3f dist=%.4f mundo=(%.2f, %.2f, %.2f) normal=%s"
					% [a["par"], a["area"], a["dist"], w.x, w.y, w.z, a["normal"]])
				if _caixas:
					print("[coplanar]      local ", a["caixas"])
	var chaves := por_par.keys()
	chaves.sort_custom(func(x: String, y: String) -> bool:
		return float(por_par_area[x]) > float(por_par_area[y]))
	for k: String in chaves.slice(0, 25):
		print("[coplanar] par %s n=%d area=%.2f" % [k, por_par[k], por_par_area[k]])
	var pecas := vis_por_peca.keys()
	pecas.sort_custom(func(x: String, y: String) -> bool:
		return float(vis_por_peca[x]) > float(vis_por_peca[y]))
	for k: String in pecas.slice(0, 40):
		print("[coplanar] peca %s area=%.2f" % [k, vis_por_peca[k]])
	var vis := vis_por_par.keys()
	vis.sort_custom(func(x: String, y: String) -> bool:
		return float(vis_por_par_area[x]) > float(vis_por_par_area[y]))
	for k: String in vis.slice(0, 30):
		print("[coplanar] visivel %s n=%d area=%.2f" % [k, vis_por_par[k], vis_por_par_area[k]])
	print("[coplanar] total chunks=%d com_pares=%d pares=%d area=%.2f visiveis=%d area_visivel=%.2f pares_em_chunk_de_bar=%d ms=%d"
		% [_coords.size(), chunks_com, total_pares, total_area, vis_pares, vis_area, bar_pares,
			Time.get_ticks_msec() - t0])
	get_tree().quit()


## Todos os pares de triangulos coplanares que se sobrepoem, entre todas as
## superficies do chunk.
func _pares(sup: Dictionary) -> Array[Dictionary]:
	var tris: Array = []
	_tris = tris
	var baldes := {}
	for mat: StringName in sup:
		var d: Dictionary = sup[mat]
		var v: PackedVector3Array = d["v"]
		var idx: PackedInt32Array = d.get("i", PackedInt32Array())
		var cores: PackedColorArray = d.get("c", PackedColorArray())
		var n := idx.size() if not idx.is_empty() else v.size()
		var k := 0
		while k + 2 < n:
			var a: Vector3
			var b: Vector3
			var cc: Vector3
			var i0 := k if idx.is_empty() else idx[k]
			if idx.is_empty():
				a = v[k]; b = v[k + 1]; cc = v[k + 2]
			else:
				a = v[idx[k]]; b = v[idx[k + 1]]; cc = v[idx[k + 2]]
			k += 3
			# A frente no Godot e a do sentido HORARIO: a normal de mao direita
			# aponta para o verso.
			var nn := (cc - a).cross(b - a)
			var dobro := nn.length()
			if dobro < 0.0002:
				continue
			nn /= dobro
			var dist := nn.dot(a)
			var t := tris.size()
			tris.append([String(mat), a, b, cc, nn, dist,
				cores[i0].to_html(false) if i0 < cores.size() else "-"])
			var q := Vector3i(roundi(nn.x * Q_NORMAL), roundi(nn.y * Q_NORMAL),
				roundi(nn.z * Q_NORMAL))
			var chave := Vector4i(q.x, q.y, q.z, floori(dist / maxf(_folga, 0.001)))
			if not baldes.has(chave):
				baldes[chave] = PackedInt32Array()
			var lista: PackedInt32Array = baldes[chave]
			lista.append(t)
			baldes[chave] = lista
	var achados: Array[Dictionary] = []
	for chave: Vector4i in baldes:
		var aqui: PackedInt32Array = baldes[chave]
		# O balde do lado (d + 1) tambem: dois planos a 1 mm podem cair em baldes
		# vizinhos. O -1 ja e visitado pelo outro balde.
		var viz: PackedInt32Array = baldes.get(Vector4i(chave.x, chave.y, chave.z, chave.w + 1),
			PackedInt32Array())
		for i in aqui.size():
			var ti: Array = tris[aqui[i]]
			for j in range(i + 1, aqui.size() + viz.size()):
				var tj: Array = tris[aqui[j]] if j < aqui.size() else tris[viz[j - aqui.size()]]
				var r := _sobrepoe(ti, tj)
				if not r.is_empty():
					achados.append(r)
	return achados


func _sobrepoe(ti: Array, tj: Array) -> Dictionary:
	var ni: Vector3 = ti[4]
	var nj: Vector3 = tj[4]
	if ni.dot(nj) < COS_MAX:
		return {}
	var dist := absf(float(ti[5]) - float(tj[5]))
	if dist > _folga:
		return {}
	# Caixa no plano antes do recorte: a grande maioria dos pares do balde sao
	# pecas vizinhas da mesma parede.
	var u := ni.cross(Vector3.UP if absf(ni.y) < 0.9 else Vector3.RIGHT).normalized()
	var w := ni.cross(u)
	var pa := _proj(ti, u, w)
	var pb := _proj(tj, u, w)
	var ra := Rect2(pa[0], Vector2.ZERO).expand(pa[1]).expand(pa[2])
	var rb := Rect2(pb[0], Vector2.ZERO).expand(pb[1]).expand(pb[2])
	if ra.end.x - 0.002 < rb.position.x or rb.end.x - 0.002 < ra.position.x \
			or ra.end.y - 0.002 < rb.position.y or rb.end.y - 0.002 < ra.position.y:
		return {}
	var recorte := _recortar(pa, pb)
	var area := _area(recorte)
	if area < AREA_MIN:
		return {}
	var meio2 := Vector2.ZERO
	for q: Vector2 in recorte:
		meio2 += q
	meio2 /= float(recorte.size())
	var mi: String = ti[0]
	var mj: String = tj[0]
	var par := (mi + " x " + mj) if mi <= mj else (mj + " x " + mi)
	return {"par": par, "area": area, "dist": dist,
		"onde": (Vector3(ti[1]) + Vector3(ti[2]) + Vector3(ti[3])) / 3.0,
		"normal": "(%.2f,%.2f,%.2f)" % [ni.x, ni.y, ni.z],
		"centro": u * meio2.x + w * meio2.y + ni * maxf(float(ti[5]), float(tj[5])),
		"n": ni, "u": u, "w": w,
		"caixas": "%s %s | %s %s" % [mi, _caixa(ti), mj, _caixa(tj)],
		"pecas": [mi + "#" + String(ti[6]), mj + "#" + String(tj[6])]}


func _caixa(t: Array) -> String:
	var a := AABB(Vector3(t[1]), Vector3.ZERO).expand(Vector3(t[2])).expand(Vector3(t[3]))
	return "[%.2f..%.2f, %.2f..%.2f, %.2f..%.2f] #%s" % [a.position.x, a.end.x, a.position.y,
		a.end.y, a.position.z, a.end.z, t[6]]


func _proj(t: Array, u: Vector3, w: Vector3) -> PackedVector2Array:
	var p := PackedVector2Array()
	for k in [1, 2, 3]:
		var v: Vector3 = t[k]
		p.append(Vector2(v.dot(u), v.dot(w)))
	if (p[1] - p[0]).cross(p[2] - p[0]) < 0.0:
		p.reverse()
	return p


## Sutherland-Hodgman: o triangulo `a` recortado pelas tres arestas de `b`
## (os dois em sentido anti-horario).
func _recortar(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	var saida := a
	for e in 3:
		var p0 := b[e]
		var p1 := b[(e + 1) % 3]
		var aresta := p1 - p0
		var entrada := saida
		saida = PackedVector2Array()
		if entrada.is_empty():
			break
		for k in entrada.size():
			var cur := entrada[k]
			var ant := entrada[(k + entrada.size() - 1) % entrada.size()]
			var dentro_cur := aresta.cross(cur - p0) >= 0.0
			var dentro_ant := aresta.cross(ant - p0) >= 0.0
			if dentro_cur:
				if not dentro_ant:
					saida.append(_cruza(ant, cur, p0, p1))
				saida.append(cur)
			elif dentro_ant:
				saida.append(_cruza(ant, cur, p0, p1))
	return saida


func _cruza(a: Vector2, b: Vector2, p0: Vector2, p1: Vector2) -> Vector2:
	var r := b - a
	var s := p1 - p0
	var den := r.cross(s)
	if absf(den) < 1e-12:
		return a
	var t := (p0 - a).cross(s) / den
	return a + r * t


func _area(p: PackedVector2Array) -> float:
	if p.size() < 3:
		return 0.0
	var s := 0.0
	for k in p.size():
		s += p[k].cross(p[(k + 1) % p.size()])
	return absf(s) * 0.5


## O chunk inteiro num corpo de triangulos, para o raio da visibilidade. A ordem
## das faces e a de `_tris`: o `face_index` do acerto aponta a normal de verdade.
func _montar_corpo(c: Vector2i) -> void:
	if _corpo != null:
		_corpo.queue_free()
	var faces := PackedVector3Array()
	_normais = PackedVector3Array()
	_diorama = PackedByteArray()
	faces.resize(_tris.size() * 3)
	_normais.resize(_tris.size())
	_diorama.resize(_tris.size())
	for i in _tris.size():
		var t: Array = _tris[i]
		faces[i * 3] = t[1]
		faces[i * 3 + 1] = t[2]
		faces[i * 3 + 2] = t[3]
		_normais[i] = t[4]
		_diorama[i] = 1 if String(t[0]).begins_with("interior") else 0
	# Os vizinhos, no espaco local deste chunk: a lateral na divisa do chunk da
	# para a massa do predio do lado.
	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				continue
			var viz := Vector2i(c.x + dx, c.y + dz)
			var off := Vector3(dx * KitModular.CHUNK, 0.0, dz * KitModular.CHUNK)
			var sup: Dictionary = _dados(viz)["superficies"]
			for mat: StringName in sup:
				var d: Dictionary = sup[mat]
				var v: PackedVector3Array = d["v"]
				var idx: PackedInt32Array = d.get("i", PackedInt32Array())
				var n := idx.size() if not idx.is_empty() else v.size()
				var k := 0
				while k + 2 < n:
					var a: Vector3 = v[k] if idx.is_empty() else v[idx[k]]
					var b: Vector3 = v[k + 1] if idx.is_empty() else v[idx[k + 1]]
					var cc: Vector3 = v[k + 2] if idx.is_empty() else v[idx[k + 2]]
					k += 3
					var nn := (cc - a).cross(b - a)
					if nn.length() < 0.0002:
						continue
					faces.append(a + off)
					faces.append(b + off)
					faces.append(cc + off)
					_normais.append(nn.normalized())
					_diorama.append(1 if String(mat).begins_with("interior") else 0)
	var forma := ConcavePolygonShape3D.new()
	forma.backface_collision = true
	forma.set_faces(faces)
	var col := CollisionShape3D.new()
	col.shape = forma
	_corpo = StaticBody3D.new()
	_corpo.add_child(col)
	add_child(_corpo)
	await get_tree().physics_frame
	await get_tree().physics_frame


## A sobreposicao aparece? Raios saem dela para a frente: o de frente e quatro a
## 40 graus. Um raio e "livre" se escapa ou se a primeira coisa que acerta e a
## FRENTE de uma face (ha espaco aberto ali: a rua, o salao, o comodo). Se acerta
## o VERSO, a sobreposicao esta dentro de um volume fechado (a massa do predio,
## a caixa do movel) e ninguem a ve.
func _visivel(a: Dictionary) -> bool:
	var n: Vector3 = a["n"]
	var u: Vector3 = a["u"]
	var w: Vector3 = a["w"]
	var origem: Vector3 = Vector3(a["centro"]) + n * 0.006
	var espaco := get_viewport().world_3d.direct_space_state
	var livres := 0
	var de_frente := false
	var dirs: Array[Vector3] = [n]
	for t: Vector3 in [u, -u, w, -w]:
		dirs.append((n * cos(deg_to_rad(40.0)) + t * sin(deg_to_rad(40.0))).normalized())
	for k in dirs.size():
		var d: Vector3 = dirs[k]
		var q := PhysicsRayQueryParameters3D.create(origem, origem + d * 60.0)
		q.hit_back_faces = true
		q.hit_from_inside = true
		var r := espaco.intersect_ray(q)
		if _depurar > 0 and k == 0:
			_depurar -= 1
			print("[coplanar] raio par=%s n=%s r=%s" % [a["par"], n, r])
		var livre := r.is_empty()
		if not livre:
			var fi := int(r.get("face_index", -1))
			var frente := Vector3(r["normal"]).dot(d) < 0.0
			if fi >= 0 and fi < _normais.size():
				frente = _normais[fi].dot(d) < 0.0
				# O comodo atras da janela e diorama: quem acerta nele esta atras
				# da fachada, onde ninguem fica.
				if _diorama[fi] == 1 and not String(a["par"]).contains("interior"):
					frente = false
			livre = frente and origem.distance_to(Vector3(r["position"])) > FOLGA_DE_VISTA
		if livre:
			livres += 1
			if k == 0:
				de_frente = true
	return de_frente or livres >= 3


func _dados(c: Vector2i) -> Dictionary:
	if not _cache.has(c):
		_cache[c] = ChunkBuilder.construir(c.x, c.y)
		# So o que o raio e a regua usam: o resto do chunk sai da memoria.
		_cache[c] = {"superficies": _cache[c]["superficies"], "props": _cache[c]["props"]}
	return _cache[c]
