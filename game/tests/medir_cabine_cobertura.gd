## O que cada pixel da cabine mostra, visto do banco do motorista.
##
##     godot --headless --path game --script res://tests/medir_cabine_cobertura.gd -- --saida=DIR
##     ... -- --poses          varre 9 poses de cabeca (criterio C1), em meia resolucao
##
## Por que existe
## --------------
## "O buraco na lateral esquerda do interior do carro" e "agua escorrendo pelo
## vidro e pingando no carro". `medir_cabine.gd` responde se as placas laterais
## estao viradas para o olho; nao responde se elas COBREM o que o olho ve, nem
## onde a agua esta sendo desenhada. Esta sonda responde as duas.
##
## Um raio por pixel (480x270, FOV 74, pitch -4: o enquadramento de
## `AberturaEstrada._de_dentro`) sai do olho e cada pixel recebe uma classe:
##
##   cabine                   a primeira peca do interior que desenha para o olho
##   ve por parabrisa / vidro o raio sai do carro por um vidro de verdade
##   BURACO                   o raio sai pela CHAPA e nenhuma peca da cabine o
##                            pegou: a lataria e `cull_back`, entao o que aparece
##                            e o mundo de fora atravessando a porta
##   janela_cabine sobre X    o vidro da cabine esta num lugar em que a lataria
##                            nao tem vidro
##   PLACA DE AGUA sobre X    a placa de agua presa a lente esta a frente do
##                            opaco, e o raio NAO sai pelo para-brisa
##
## A lataria nao desenha por dentro. Por isso uma peca da cabine ALEM da chapa
## ainda aparece de dentro — e aparece tambem de FORA, o que e marcado a parte.
##
## Linha de base medida em 16/09/2026 (ver PLANO_CHUVA_CABINE_AAA.md):
## BURACO 15 a 43% do quadro conforme o modelo, e toda essa area debaixo da
## placa de agua.
##
## O erro "Identifier not found: Clima" no topo da saida e o autoload que nao
## existe em `--script`; as medidas saem mesmo assim.
extends SceneTree

const W := 480
const H := 270
const FOV := 74.0
const PITCH := -4.0

## Poses de cabeca do criterio C1: pitch x yaw, em graus.
const PITCHES := [-10.0, -4.0, 4.0]
const YAWS := [-35.0, 0.0, 35.0]

const L_CAB := 1
const L_JAN := 2
const L_PLACA := 4
const L_LAT := 8
const L_VID := 16

## Tolerancia da saida por vidro: o vidro da lataria e um recorte colado ate
## 1,2 cm por fora da chapa, e nao um buraco nela.
const FOLGA_VIDRO := 0.05

var _saida := ""
var _poses := false
var _nomes := {}
## Aberturas de vidro do modelo em medida. Ver `_saida_por_abertura`.
var _aberturas: Array = []


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			_saida = a.trim_prefix("--saida=")
		elif a == "--poses":
			_poses = true
	_rodar.call_deferred()


func _rodar() -> void:
	var modelos := {
		"MAREA": Carroceria.Modelo.MAREA, "SEDA": Carroceria.Modelo.SEDA,
		"HATCH": Carroceria.Modelo.HATCH, "PERUA": Carroceria.Modelo.PERUA,
		"PICAPE": Carroceria.Modelo.PICAPE, "FUSCA": Carroceria.Modelo.FUSCA,
	}
	var linhas: Array[String] = []
	for nome: String in modelos:
		linhas.append(await _medir(nome, modelos[nome]))
	print("\n=== resumo (%% do quadro%s) ===" % (", PIOR das 9 poses" if _poses else ""))
	print("modelo   buraco  agua_fora_parabrisa  janela_sobre_chapa  vidro_sem_janela  peca_alem_da_chapa")
	for l in linhas:
		print(l)
	quit(0)


func _medir(nome_modelo: String, modelo: int) -> String:
	var pai := Node3D.new()
	root.add_child(pai)
	var medidas := Carroceria.montar(modelo, CarroCena.TINTA, CarroCena.SEMENTE)
	_aberturas = medidas.get("aberturas", [])
	var cab := CarroCabine.new()
	pai.add_child(cab)
	cab.montar(medidas)
	var olho := cab.olho()

	# Cabine: por no, so os triangulos que desenham para o olho — todos, se o
	# shader do no e `cull_disabled` (vidro e placa de agua). Todos os raios
	# saem do olho, entao o lado que desenha nao depende do raio nem da pose.
	for mi: MeshInstance3D in _malhas(cab):
		var dupla := mi.name.begins_with("Janela") or mi.name == "AguaNoVidro"
		var camada := L_CAB
		if mi.name.begins_with("Janela"):
			camada = L_JAN
		elif mi.name == "AguaNoVidro":
			camada = L_PLACA
		var xf := _ate(mi, cab)
		var pts := PackedVector3Array()
		for t: Array in _tris(mi.mesh, null):
			var a: Vector3 = xf * t[0]
			var b: Vector3 = xf * t[1]
			var c: Vector3 = xf * t[2]
			var cruz := (b - a).cross(c - a)
			if cruz.length() < 1e-7:
				continue
			# O lado que desenha e o OPOSTO do produto vetorial. Ver a memoria
			# do projeto "giro de face aponta ao contrario".
			var desenha := -cruz.normalized()
			if dupla or desenha.dot(olho - (a + b + c) / 3.0) > 0.0:
				pts.append_array([a, b, c])
		var rotulo := String(mi.name)
		if mi.get_parent() != cab:
			rotulo = String(mi.get_parent().name) + "/" + rotulo
		_corpo(pai, pts, camada, rotulo)

	# Lataria, separada por celula do atlas. Todas as faces: a pergunta aqui e
	# por onde o raio SAI do carro, e nao o que desenha.
	var celulas := {
		"parabrisa": Carroceria.uv(Carroceria.C_PARABRISA).grow(1.0 / Carroceria.ATLAS),
		"vidro_lado": Carroceria.uv(Carroceria.C_VIDRO_LADO).grow(1.0 / Carroceria.ATLAS),
		"vidro_tras": Carroceria.uv(Carroceria.C_VIDRO_TRAS).grow(1.0 / Carroceria.ATLAS),
	}
	var por_cel := {"lataria": PackedVector3Array()}
	for k: String in celulas:
		por_cel[k] = PackedVector3Array()
	# Sem `as` aqui: array empacotado e VALOR, e o cast devolve uma copia — a
	# lataria inteira sumia da sonda e todo pixel virava "sai sem tocar em nada".
	for t: Array in _tris(medidas["corpo"] as ArrayMesh, celulas):
		por_cel[t[3]].append_array([t[0], t[1], t[2]])
	for k: String in por_cel:
		_corpo(pai, por_cel[k], L_LAT if k == "lataria" else L_VID, k)

	for i in 3:
		await physics_frame
	var espaco := pai.get_world_3d().direct_space_state

	print("\n=== %s  olho %s ===" % [nome_modelo, olho])
	var pior := {"buraco": 0.0, "agua_fora": 0.0, "janela_chapa": 0.0,
		"vidro_sem": 0.0, "alem": 0.0}
	if _poses:
		# Meia resolucao: 9 poses em resolucao cheia sao 20 minutos por modelo,
		# e o criterio C1 e area relativa, que meia resolucao ja da.
		for p: float in PITCHES:
			for y: float in YAWS:
				var r := _varrer(espaco, olho, p, y, W / 2, H / 2, "")
				for k: String in pior:
					pior[k] = maxf(pior[k], float(r[k]))
				print("  pitch %+5.1f yaw %+5.1f -> buraco %5.2f%%  agua fora %5.2f%%  janela sobre chapa %5.2f%%"
					% [p, y, r["buraco"], r["agua_fora"], r["janela_chapa"]])
	else:
		var destino := ""
		if _saida != "":
			destino = _saida.path_join("cobertura_%s.png" % nome_modelo.to_lower())
		var r := _varrer(espaco, olho, PITCH, 0.0, W, H, destino)
		for k: String in pior:
			pior[k] = float(r[k])
		var chaves: Array = (r["classes"] as Dictionary).keys()
		var classes: Dictionary = r["classes"]
		chaves.sort_custom(func(a, b): return classes[a] > classes[b])
		var total := float(W * H)
		for k in chaves:
			print("  %6.2f%%  %s" % [100.0 * float(classes[k]) / total, k])
		var buracos: Dictionary = r["buracos"]
		var bk: Array = buracos.keys()
		bk.sort_custom(func(a, b): return buracos[a] > buracos[b])
		print("  -- buraco por ponto de saida (lado, z do carro, y relativo ao olho):")
		for k in bk.slice(0, 10):
			print("     %5d px  %s" % [buracos[k], k])

	pai.queue_free()
	await process_frame
	return "%-8s %6.2f  %19.2f  %18.2f  %16.2f  %18.2f" % [nome_modelo,
		pior["buraco"], pior["agua_fora"], pior["janela_chapa"],
		pior["vidro_sem"], pior["alem"]]


## Uma pose: dispara os raios e devolve as porcentagens, as classes e os pontos
## de saida dos buracos. Com `destino`, grava o mapa em PNG.
func _varrer(espaco: PhysicsDirectSpaceState3D, olho: Vector3, pitch: float,
		yaw: float, larg: int, alt: int, destino: String) -> Dictionary:
	var base := Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, deg_to_rad(pitch))
	var th := tan(deg_to_rad(FOV) * 0.5)
	var asp := float(W) / float(H)
	var img := Image.create(larg, alt, false, Image.FORMAT_RGB8)
	var classes := {}
	var buracos := {}
	var soma := {"buraco": 0, "agua_fora": 0, "janela_chapa": 0, "vidro_sem": 0, "alem": 0}
	for py in alt:
		for px in larg:
			var d := base * Vector3((2.0 * (px + 0.5) / larg - 1.0) * th * asp,
				(1.0 - 2.0 * (py + 0.5) / alt) * th, -1.0).normalized()
			var fim := olho + d * 6.0
			var cabine := _raio(espaco, olho, fim, L_CAB)
			var janela := _raio(espaco, olho, fim, L_JAN)
			var placa := _raio(espaco, olho, fim, L_PLACA)
			var lat := _raio(espaco, olho, fim, L_LAT)
			var vid := _raio(espaco, olho, fim, L_VID)
			var d_cab := _dist(cabine, olho)
			var d_jan := _dist(janela, olho)
			var d_pla := _dist(placa, olho)
			var d_lat := _dist(lat, olho)
			var d_vid := _dist(vid, olho)

			var saida := "nada"
			var d_saida := INF
			if d_lat < INF:
				# Por onde o raio sai: o PONTO de saida esta dentro de alguma
				# abertura de vidro?
				#
				# Antes isto era medido pela distancia ate o vidro ao longo do
				# raio, e em angulo rasante a conta mentia: entre a chapa e o
				# vidro colado 1,2 cm por fora dela cabem 15 cm de caminho, e o
				# raio que saia pela JANELA era contado como buraco. Foi assim
				# que a sonda inventou 0,54% de buraco no Fusca depois de a
				# cabine ja estar fechada.
				saida = _saida_por_abertura(lat["position"])
				if saida == "":
					saida = "lataria"
				d_saida = d_lat
			elif d_vid < INF:
				saida = _nomes[vid["collider_id"]]
				d_saida = d_vid

			var classe := ""
			var cor := Color.BLACK
			var cab_vale := d_cab < INF and d_cab < d_jan \
				and (saida == "lataria" or saida == "nada" or d_cab < d_saida)
			if cab_vale:
				classe = "cabine:" + String(_nomes[cabine["collider_id"]])
				cor = Color(0.35, 0.35, 0.35)
				if classe.contains("Volante"):
					cor = Color(0.55, 0.40, 0.25)
				if d_cab > d_saida + 0.02:
					classe += " (ALEM da chapa)"
					soma["alem"] += 1
			elif d_jan < INF and d_jan < d_saida + FOLGA_VIDRO:
				if _e_janela(saida):
					classe = "janela_cabine sobre janela da lataria"
					cor = Color(0.2, 0.8, 0.8)
				else:
					classe = "janela_cabine sobre " + saida
					cor = Color(1.0, 0.55, 0.0)
					soma["janela_chapa"] += 1
			else:
				match saida:
					"parabrisa":
						classe = "ve por parabrisa"
						cor = Color(0.15, 0.25, 0.9)
					"vigia":
						classe = "ve por vigia"
						cor = Color(0.6, 0.3, 0.9)
					"lataria":
						classe = "BURACO (chapa vista por dentro)"
						cor = Color(1.0, 0.0, 0.0)
						soma["buraco"] += 1
						var pt: Vector3 = lat["position"]
						var lado := "esq" if pt.x < 0.0 else "dir"
						var chave := "%s z=%.1f y=%+.1f" % [lado,
							snappedf(pt.z, 0.1), snappedf(pt.y - olho.y, 0.1)]
						buracos[chave] = int(buracos.get(chave, 0)) + 1
					_:
						if _e_janela(saida):
							classe = "ve por %s SEM vidro da cabine" % saida
							cor = Color(0.5, 0.7, 1.0)
							soma["vidro_sem"] += 1
						else:
							classe = "sai sem tocar em nada"
							cor = Color(1.0, 0.0, 1.0)
			# A placa presa a lente desenha onde esta a frente do opaco.
			if d_pla < INF and d_pla < d_cab and saida != "parabrisa":
				classe = "PLACA DE AGUA sobre [" + classe + "]"
				soma["agua_fora"] += 1
				if (px + py) % 4 < 2:
					cor = Color(1.0, 1.0, 0.0)
			classes[classe] = int(classes.get(classe, 0)) + 1
			img.set_pixel(px, py, cor)

	if destino != "":
		img.save_png(destino)
	var total := float(larg * alt)
	return {
		"buraco": 100.0 * soma["buraco"] / total,
		"agua_fora": 100.0 * soma["agua_fora"] / total,
		"janela_chapa": 100.0 * soma["janela_chapa"] / total,
		"vidro_sem": 100.0 * soma["vidro_sem"] / total,
		"alem": 100.0 * soma["alem"] / total,
		"classes": classes,
		"buracos": buracos,
	}


## Esta saida e uma janela lateral?
func _e_janela(tipo: String) -> bool:
	return tipo in ["porta_frente", "porta_tras", "quebra_vento", "fixa_tras"]


## O tipo da abertura em que este ponto cai, ou "" se ele esta na chapa.
##
## A tolerancia de 6 cm cobre a colagem do vidro (1,2 cm por fora da chapa) e a
## espessura da moldura, sem alcançar a chapa vizinha.
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


## Triangulos da malha; com `celulas`, cada um leva no quarto campo a celula do
## atlas em que o centro da UV dele cai.
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
