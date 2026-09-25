## Regua da fiacao de rua (RedeEletrica, KitRede).
##
##     godot --headless --path game res://tests/checar_fiacao.tscn -- [--raio=6] [--centro=0,0]
##
## Monta os chunks de verdade (ChunkBuilder.construir), faz colisao de triangulo
## com TODA a geometria que nao e cabo nem folha, e lanca um raio por segmento de
## cada fio. Mede duas vezes, contra os mesmos predios:
##
##   antes    a fiacao antiga, refeita aqui pela mesma conta dela: reta do topo
##            do poste deste chunk ao dos chunks +X e +Z, tres fios em parabola;
##   depois   o que o chunk desenhou de fato (a lista `fiacao` do construir).
##
## Um cabo "atravessa" quando algum raio dele bate em geometria longe das pontas
## (os primeiros e ultimos 60 cm sao do proprio poste, da cruzeta e da parede
## onde o ramal prende). A folha e medida a parte: la o criterio e a poda.
##
## Tambem mede a altura livre do fio sobre o chao, a folga dos postes novos para
## arvore, semaforo, sinal de pedestre, porta e boca de loja, e o custo em
## triangulos por chunk.
##
## Imprime `[fiacao] chave=valor`. Sai com codigo 1 se algum criterio falhar.
extends Node

const TAM := 32.0
const PONTA := 0.6
const CAMADA_PREDIO := 1
const CAMADA_FOLHA := 2

## Altura livre minima do fio sobre o chao (norma de rede urbana: 5,5 m sobre a
## pista para a media, 4,5 m para telefone; aqui o mais baixo e o telefone).
const LIVRE_VAO := 4.5
const LIVRE_RAMAL := 2.9

var _raio := 6
var _centro := Vector2i.ZERO
var _falhas := 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--raio="):
			_raio = int(arg.trim_prefix("--raio="))
		elif arg.begins_with("--chunk="):
			var q := arg.trim_prefix("--chunk=").split(",")
			_despejar(Vector2i(int(q[0]), int(q[1])))
		elif arg == "--serpentina":
			_serpentina()
		elif arg.begins_with("--centro="):
			var p := arg.trim_prefix("--centro=").split(",")
			_centro = Vector2i(int(p[0]), int(p[1]))
	KitModular.preparar()
	_rodar.call_deferred()


## Tudo que a rede poe num chunk, para achar o vao errado pelo nome.
func _despejar(c: Vector2i) -> void:
	var origem := Vector3(c.x * TAM, 0.0, c.y * TAM)
	var f := func(p: Dictionary) -> String:
		return "[%s e%d l%d k%d lado%d%s%s pe %s rua %s]" % [p["chunk"], p["eixo"], p["linha"],
			p["k"], p["lado"], " LUZ" if p["luz"] else "", " ESQ" if p["esquina"] else "",
			(Vector3(p["pe"]) - origem).snapped(Vector3(0.01, 0.01, 0.01)), p["rua"]]
	print("[fiacao] chunk %s bordas %s" % [c, MalhaUrbana.bordas(c.x, c.y)])
	for p: Dictionary in RedeEletrica.postes_do_chunk(c.x, c.y):
		print("[fiacao]   poste ", f.call(p))
	for v: Dictionary in RedeEletrica.vaos_do_chunk(c.x, c.y):
		print("[fiacao]   vao %s %s -> %s" % [v["tipo"], f.call(v["a"]), f.call(v["b"])])


## A rua em curva da encosta (SerpentinaBuilder) usa o poste solto de
## KitRede.poste_de_luz: monta os chunks da celula mais perto e conta.
func _serpentina() -> void:
	for r in 12:
		for ci in range(-r, r + 1):
			for cj in range(-r, r + 1):
				if maxi(absi(ci), absi(cj)) != r or not Serpentina.celula(ci, cj):
					continue
				var p := MalhaUrbana.PERIODO
				var lampadas := 0
				for dx in p:
					for dz in p:
						var d := ChunkBuilder.construir(ci * p + dx, cj * p + dz)
						for pr: Dictionary in d["props"]:
							if pr.get("tipo", "") == "lampada":
								lampadas += 1
				print("[fiacao] serpentina celula (%d, %d): %d lampadas em %d chunks" % [ci, cj,
					lampadas, p * p])
				return
	print("[fiacao] serpentina: nenhuma celula perto")


func _relatar(chave: String, valor: Variant) -> void:
	print("[fiacao] %s=%s" % [chave, valor])


func _criterio(nome: String, ok: bool, detalhe: String) -> void:
	print("[fiacao] %s %s  %s" % ["OK  " if ok else "FALHA", nome, detalhe])
	if not ok:
		_falhas += 1


static func _e_folha(mat: StringName) -> bool:
	var n := String(mat)
	for parte: String in ["vegetacao", "folha", "arbusto", "casca", "flor", "mato", "planta"]:
		if n.contains(parte):
			return true
	return false


func _rodar() -> void:
	var t0 := Time.get_ticks_msec()
	var depois: Array = []   # [PackedVector3Array mundo, Vector2i chunk]
	var tris_cabo: Array[int] = []
	var tris_cabo_longe: Array[int] = []
	var tris_total: Array[int] = []
	var construidos := {}
	for dx in range(-_raio, _raio + 1):
		for dz in range(-_raio, _raio + 1):
			var c := _centro + Vector2i(dx, dz)
			var d := ChunkBuilder.construir(c.x, c.y)
			construidos[c] = d
			var origem := Vector3(c.x * TAM, 0.0, c.y * TAM)
			_colisao(d["superficies"], origem)
			if absi(dx) < _raio and absi(dz) < _raio:
				for reg: Array in d.get("fiacao", []):
					var m := PackedVector3Array()
					for q: Vector3 in reg[0]:
						m.append(q + origem)
					depois.append([m, c, reg[1]])
				var sup: Dictionary = d["superficies"]
				# O vao tem dois niveis (KitRede.MAT_CABO_PERTO e _LONGE, nunca os dois
				# na tela); a peca reta fica no balde sem nivel e aparece sempre. De
				# perto se desenha reto + @perto, de longe reto + @longe.
				var t := {&"reto": 0, &"perto": 0, &"longe": 0}
				for mat: StringName in sup:
					if not String(mat).begins_with("cabo"):
						continue
					var balde := &"perto" if ChunkManager.e_perto(mat) 						else &"longe" if ChunkManager.e_longe(mat) else &"reto"
					t[balde] += PSXMesh.dados_triangulos(sup[mat])
				tris_cabo.append(t[&"reto"] + t[&"perto"])
				tris_cabo_longe.append(t[&"reto"] + t[&"longe"])
				tris_total.append(int(d["triangulos"]))
	_relatar("chunks", construidos.size())
	_relatar("montagem_ms", Time.get_ticks_msec() - t0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var antes := _fiacao_antiga()
	var r_antes := _medir(antes)
	var r_depois := _medir(depois)
	_relatar("antes_cabos", antes.size())
	_relatar("antes_atravessam_predio", r_antes["predio"])
	_relatar("antes_atravessam_folha", r_antes["folha"])
	_relatar("depois_cabos", depois.size())
	_relatar("depois_atravessam_predio", r_depois["predio"])
	_relatar("depois_atravessam_folha", r_depois["folha"])
	for ex: String in r_depois["exemplos"]:
		_relatar("exemplo", ex)

	_criterio("F1 nenhum cabo atravessa predio", int(r_depois["predio"]) == 0,
		"%d de %d (antes %d de %d)" % [r_depois["predio"], depois.size(), r_antes["predio"],
			antes.size()])
	# A poda em V abre a copa em volta do fio mais baixo; os de cima, acima da
	# copa, raramente encostam. Um resto de ponta de cartao passa: o limite e
	# um em cada cinquenta cabos.
	_criterio("F2 cabo dentro de copa (poda)", int(r_depois["folha"]) * 50 <= depois.size(),
		"%d de %d" % [r_depois["folha"], depois.size()])

	_altura_livre(depois)
	_folga_dos_postes(construidos)
	tris_cabo.sort()
	tris_total.sort()
	_relatar("tris_cabo_mediana", tris_cabo[tris_cabo.size() / 2])
	_relatar("tris_cabo_max", tris_cabo[-1])
	tris_cabo_longe.sort()
	_relatar("tris_cabo_longe_mediana", tris_cabo_longe[tris_cabo_longe.size() / 2])
	_relatar("tris_cabo_longe_max", tris_cabo_longe[-1])
	_relatar("tris_total_mediana", tris_total[tris_total.size() / 2])
	_relatar("tris_total_max", tris_total[-1])
	_relatar("tempo_ms", Time.get_ticks_msec() - t0)
	_relatar("falhas", _falhas)
	get_tree().quit(1 if _falhas > 0 else 0)


## Um corpo por material, com o nome guardado: o exemplo diz o que o fio furou.
func _colisao(sup: Dictionary, origem: Vector3) -> void:
	for mat: StringName in sup:
		# O cabo nao e obstaculo dele mesmo, em nenhum dos baldes.
		if String(mat).begins_with("cabo"):
			continue
		var d: Dictionary = sup[mat]
		var v: PackedVector3Array = d["v"]
		var idx: PackedInt32Array = d["i"]
		var faces := PackedVector3Array()
		for k in idx.size():
			faces.append(v[idx[k]])
		if faces.is_empty():
			continue
		var corpo := StaticBody3D.new()
		corpo.set_meta(&"mat", mat)
		corpo.collision_layer = CAMADA_FOLHA if _e_folha(mat) else CAMADA_PREDIO
		corpo.position = origem
		var forma := ConcavePolygonShape3D.new()
		forma.backface_collision = true
		forma.set_faces(faces)
		var cs := CollisionShape3D.new()
		cs.shape = forma
		corpo.add_child(cs)
		add_child(corpo)


## A fiacao de antes, pela conta dela (KitModular.fiacao a partir de
## ChunkBuilder._iluminacao do commit anterior).
func _fiacao_antiga() -> Array:
	var saida: Array = []
	for dx in range(-_raio + 1, _raio):
		for dz in range(-_raio + 1, _raio):
			var c := _centro + Vector2i(dx, dz)
			if not ChunkBuilder.tem_poste(c.x, c.y):
				continue
			var topo := ChunkBuilder.posicao_poste(c.x, c.y) + Vector3(0.0, 6.9, 0.0)
			for passo: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				if not ChunkBuilder.tem_poste(c.x + passo.x, c.y + passo.y):
					continue
				var viz := ChunkBuilder.posicao_poste(c.x + passo.x, c.y + passo.y) \
					+ Vector3(0.0, 6.9, 0.0)
				for nivel: float in [0.0, -0.35, -0.7]:
					var pts := PackedVector3Array()
					for s in 5:
						var t := float(s) / 4.0
						var p := (topo + Vector3(0.0, nivel, 0.0)).lerp(viz + Vector3(0.0, nivel, 0.0), t)
						p.y -= 0.9 * 4.0 * t * (1.0 - t)
						pts.append(p)
					saida.append([pts, c])
	return saida


## Quantos cabos batem em predio e em folha, longe das pontas.
func _medir(cabos: Array) -> Dictionary:
	var espaco := get_viewport().world_3d.direct_space_state
	var predio := 0
	var folha := 0
	var exemplos: Array[String] = []
	for item: Array in cabos:
		var pts: PackedVector3Array = item[0]
		var hit_p := _bate(espaco, pts, CAMADA_PREDIO)
		if not hit_p.is_empty():
			predio += 1
			if exemplos.size() < 40:
				exemplos.append("PREDIO %s" % _descrever(item, hit_p))
		var hit_f := _bate(espaco, pts, CAMADA_FOLHA)
		if not hit_f.is_empty():
			folha += 1
			if exemplos.size() < 40 and folha % 4 == 0:
				exemplos.append("FOLHA %s" % _descrever(item, hit_f))
	return {"predio": predio, "folha": folha, "exemplos": exemplos}


func _descrever(item: Array, hit: Dictionary) -> String:
	var pts: PackedVector3Array = item[0]
	var c: Vector2i = item[1]
	var origem := Vector3(c.x * TAM, 0.0, c.y * TAM)
	var n := hit.get("collider") as Node
	var mat := String(n.get_meta(&"mat", "?")) if n != null else "?"
	var chao := func(p: Vector3) -> float: return p.y - _chao(p)
	var pos: Vector3 = hit["position"]
	var tipo := String(item[2]) if item.size() > 2 else "antigo"
	return "%s chunk %s  %s -> %s  bate %s (h %.1f) em %s" % [tipo, c,
		(pts[0] - origem).snapped(Vector3(0.1, 0.1, 0.1)), (pts[-1] - origem).snapped(Vector3(0.1, 0.1, 0.1)),
		(pos - origem).snapped(Vector3(0.1, 0.1, 0.1)), chao.call(pos), mat]


func _bate(espaco: PhysicsDirectSpaceState3D, pts: PackedVector3Array, camada: int) -> Dictionary:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	if total < PONTA * 2.0 + 0.1:
		return {}
	var andado := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		var t0 := clampf((PONTA - andado) / seg, 0.0, 1.0)
		var t1 := clampf((total - PONTA - andado) / seg, 0.0, 1.0)
		andado += seg
		if t1 <= t0:
			continue
		var q := PhysicsRayQueryParameters3D.create(a.lerp(b, t0), a.lerp(b, t1), camada)
		q.hit_back_faces = true
		var r := espaco.intersect_ray(q)
		if not r.is_empty():
			return r
	return {}


## Altura do fio sobre o chao no meio do vao (o vao, e nao o ramal, que desce
## ate a parede de proposito).
func _altura_livre(cabos: Array) -> void:
	var pior_vao := 99.0
	var pior_ramal := 99.0
	var onde := ""
	for item: Array in cabos:
		var pts: PackedVector3Array = item[0]
		var comp := Vector2(pts[-1].x - pts[0].x, pts[-1].z - pts[0].z).length()
		var ramal: bool = item.size() > 2 and item[2] == &"ramal"
		for i in range(1, pts.size() - 1):
			var livre := pts[i].y - _chao(pts[i])
			if ramal:
				pior_ramal = minf(pior_ramal, livre)
			elif livre < pior_vao and comp > 8.0:
				pior_vao = livre
				onde = "%s (cabo %s -> %s, chunk %s)" % [pts[i].snapped(Vector3(0.1, 0.1, 0.1)),
					pts[0].snapped(Vector3(0.1, 0.1, 0.1)), pts[-1].snapped(Vector3(0.1, 0.1, 0.1)),
					item[1]]
	_criterio("F3 altura livre do vao", pior_vao >= LIVRE_VAO,
		"%.2f m (minimo %.1f) em %s" % [pior_vao, LIVRE_VAO, onde])
	_criterio("F4 altura livre do ramal", pior_ramal >= LIVRE_RAMAL,
		"%.2f m (minimo %.1f)" % [pior_ramal, LIVRE_RAMAL])


func _chao(p: Vector3) -> float:
	return KitModular.ALTURA_MEIO_FIO + Relevo.altura(p.x, p.z)


var _exemplos_de_poste := {}


## Um poste de cada tipo, com o lugar no mundo: sao as paradas da rota
## `fiacao` (resources/rotas/cidade.json).
func _exemplo_de_poste(p: Dictionary) -> void:
	var tipos: Array[String] = []
	if bool(p["esquina"]):
		tipos.append("esquina")
	if bool(p["mt"]) and not bool(p["esquina"]) and KitRede._sorteio(Vector3(p["pe"]), 71) % 5 == 0:
		tipos.append("trafo")
	var vaos := RedeEletrica.vaos_do_poste(p)
	if vaos.size() == 1:
		tipos.append("estai")
	for v: Dictionary in vaos:
		if v["tipo"] == &"travessia":
			tipos.append("travessia")
	if int(p["bt"]) == 1 and bool(p["mt"]):
		tipos.append("armacao_e_media")
	for t: String in tipos:
		if not _exemplos_de_poste.has(t):
			_exemplos_de_poste[t] = true
			print("[fiacao] poste_%s pe=%s rua=%s" % [t, (Vector3(p["pe"])).snapped(
				Vector3(0.1, 0.1, 0.1)), p["rua"]])


## Folga de cada poste para o que mora na calcada.
func _folga_dos_postes(construidos: Dictionary) -> void:
	var n_postes := 0
	var n_esquina := 0
	var n_rede := 0
	var conflitos: Array[String] = []
	for c: Vector2i in construidos:
		if absi(c.x - _centro.x) >= _raio or absi(c.y - _centro.y) >= _raio:
			continue
		var origem := Vector3(c.x * TAM, 0.0, c.y * TAM)
		var arv := ChunkBuilder.arvores(c.x, c.y)
		var porta := ChunkBuilder._porta_do_chunk(c.x, c.y, MalhaUrbana.quadra_de(c.x, c.y))
		var sinais: Array[Vector3] = []
		for dx in 2:
			for dz in 2:
				var no := Vector3((c.x + dx) * TAM, 0.0, (c.y + dz) * TAM)
				for s: Dictionary in ChunkBuilder.sinais_do_cruzamento(c.x + dx, c.y + dz):
					sinais.append(no + Vector3(s["pos"]) - origem)
					sinais.append(no + Vector3(s["ped_pos"]) - origem)
		var lojas: Array = (construidos[c] as Dictionary).get("lojas", [])
		for p: Dictionary in RedeEletrica.postes_do_chunk(c.x, c.y):
			n_postes += 1
			_exemplo_de_poste(p)
			if bool(p["esquina"]):
				n_esquina += 1
			elif not bool(p["luz"]):
				n_rede += 1
			var pe: Vector3 = Vector3(p["pe"]) - origem
			var perto := func(o: Vector3, raio: float) -> bool:
				return Vector2(o.x - pe.x, o.z - pe.z).length() < raio
			for o: Vector3 in arv:
				if perto.call(o, 1.0):
					conflitos.append("arvore %s %s" % [c, pe.snapped(Vector3(0.1, 0.1, 0.1))])
			for o: Vector3 in sinais:
				if perto.call(o, 0.6):
					conflitos.append("sinal %s %s" % [c, pe.snapped(Vector3(0.1, 0.1, 0.1))])
			if not porta.is_empty() and perto.call(Vector3(porta["pos"]), 1.5):
				conflitos.append("porta %s %s" % [c, pe.snapped(Vector3(0.1, 0.1, 0.1))])
			for l: Dictionary in lojas:
				var boca: Vector3 = l["boca"]
				var nrm: Vector3 = l["normal"]
				var lat := Vector3(nrm.z, 0.0, -nrm.x)
				var dd := pe - boca
				if absf(dd.dot(lat)) < float(l["largura"]) * 0.25 + 0.6 and dd.dot(nrm) > 0.0 \
						and dd.dot(nrm) < 4.5 and not bool(p["luz"]):
					conflitos.append("boca de loja %s %s" % [c, pe.snapped(Vector3(0.1, 0.1, 0.1))])
	_relatar("postes", n_postes)
	_relatar("postes_de_rede", n_rede)
	_relatar("postes_de_esquina", n_esquina)
	for k in mini(conflitos.size(), 12):
		_relatar("conflito", conflitos[k])
	_criterio("F5 poste sem conflito na calcada", conflitos.is_empty(),
		"%d conflitos" % conflitos.size())
