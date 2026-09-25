## Quanto custa, na thread principal, cada parte de um chunk virar no.
##
##     godot --path game --resolution 1920x1080 res://tests/bancada_custo_chunk.tscn -- --pular-menu --estilo=moderno
##     ... -- --chunks=40       quantos chunks do trajeto (padrao 40)
##     ... -- --pedestres=12    quantos Pedestre montar a parte (padrao 12)
##     ... -- --coords=-7,-11;-3,-12   so estes chunks, com cada um detalhado:
##                              as superficies e os props mais caros dele
##
## Dirigindo a 70 km/h entram ~3 chunks por segundo, e o quadro em que um vira
## no durava 18-20 ms de mediana e ate 73 ms (24/09/2026). O `ChunkManager`
## faz tudo num quadro so (`_montar`), entao o `[engasgo]` nao diz QUEM.
##
## Aqui os mesmos passos de `_montar`, cronometrados um a um, nos chunks do
## trajeto da bancada de dirigir (avenida x = -160, z de 100 para -400):
##
##   dados     `ChunkBuilder.construir` (fora do cronometro: roda em thread)
##   malhas    `PSXMesh.dados_para_mesh` + MeshInstance3D, por superficie
##   colisao   StaticBody3D, mapa de alturas e caixas
##   oclusor   `ChunkManager._oclusor`
##   entrar    o chunk sem props entra na arvore
##   props     cada prop criado e posto na arvore UM A UM (o `_ready` dele
##             incluido), agrupado por tipo
##
## A raiz de teste fica a 2 km, fora de vista: o custo de desenho nao entra, so
## o de montar. Depois o `Pedestre` da multidao, que nasce do mesmo jeito.
## Imprime `[chunk] chave=valor`.
extends Node

var _chunks := 40
var _pedestres := 12
var _coords: Array[Vector2i] = []


## A TV com o `_ready` cronometrado funcao por funcao.
class TVMedida extends Televisao:
	var tempos := {}

	func _ready() -> void:
		var t := Time.get_ticks_usec()
		add_to_group(&"televisao")
		rotation.y = giro
		_montar_tela()
		tempos["tela"] = float(Time.get_ticks_usec() - t) / 1000.0
		t = Time.get_ticks_usec()
		_montar_luz()
		tempos["luz"] = float(Time.get_ticks_usec() - t) / 1000.0
		t = Time.get_ticks_usec()
		_montar_facho()
		tempos["facho"] = float(Time.get_ticks_usec() - t) / 1000.0
		t = Time.get_ticks_usec()
		_montar_chiado()
		tempos["chiado"] = float(Time.get_ticks_usec() - t) / 1000.0
		set_process(true)


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--chunks="):
			_chunks = arg.trim_prefix("--chunks=").to_int()
		elif arg.begins_with("--pedestres="):
			_pedestres = arg.trim_prefix("--pedestres=").to_int()
		elif arg.begins_with("--coords="):
			for par: String in arg.trim_prefix("--coords=").split(";"):
				var xz := par.split(",")
				_coords.append(Vector2i(xz[0].to_int(), xz[1].to_int()))
	var cidade: Node = (load("res://scenes/test/cidade.tscn") as PackedScene).instantiate()
	add_child(cidade)
	_rodar()


func _relatar(chave: String, valor: Variant) -> void:
	print("[chunk] %s=%s" % [chave, valor])


static func _contar(no: Node) -> int:
	var n := 1
	for f in no.get_children():
		n += _contar(f)
	return n


static func _us() -> int:
	return Time.get_ticks_usec()


func _rodar() -> void:
	var arvore := get_tree()
	while arvore.get_first_node_in_group(&"player") == null:
		await arvore.physics_frame
	# A cidade em volta do jogador assenta antes: o que se mede e a montagem, e
	# nao a disputa com a carga da largada.
	await arvore.create_timer(6.0).timeout
	var raiz := Node3D.new()
	raiz.name = "RaizDeTeste"
	raiz.position = Vector3(0.0, -500.0, 2000.0)
	add_child(raiz)

	# O trajeto da bancada de dirigir: a coluna de chunks da avenida e a vizinha.
	var coords: Array[Vector2i] = []
	var j := 3
	while coords.size() < _chunks:
		coords.append(Vector2i(-6, j))
		coords.append(Vector2i(-5, j))
		j -= 1
	coords.resize(_chunks)
	if not _coords.is_empty():
		coords = _coords

	var etapas := {"malhas": PackedFloat32Array(), "colisao": PackedFloat32Array(),
		"oclusor": PackedFloat32Array(), "entrar": PackedFloat32Array(),
		"props": PackedFloat32Array(), "total": PackedFloat32Array()}
	var por_tipo := {}
	var n_malhas := 0
	var n_formas := 0
	for coord: Vector2i in coords:
		var dados := ChunkBuilder.construir(coord.x, coord.y)
		await arvore.process_frame
		var t_total := _us()

		var t := _us()
		var no := Node3D.new()
		no.name = "teste_%d_%d" % [coord.x, coord.y]
		var superficies: Dictionary = dados["superficies"]
		var detalhe := PackedStringArray()
		for material: StringName in superficies:
			var d: Dictionary = superficies[material]
			if PSXMesh.dados_vazio(d):
				continue
			var ts := _us()
			var mi := MeshInstance3D.new()
			mi.mesh = PSXMesh.dados_para_mesh(d)
			var tm := _us()
			var base_mat := StringName(String(material).get_slice("@", 0))
			mi.material_override = ChunkManager._material(base_mat)
			no.add_child(mi)
			n_malhas += 1
			var ms := float(_us() - ts) / 1000.0
			if not _coords.is_empty() and ms > 0.5:
				detalhe.append("%s=%.1f(malha %.1f)" % [material, ms, float(tm - ts) / 1000.0])
		_somar(etapas, "malhas", t)
		if not _coords.is_empty():
			_relatar("superficies_caras(%d,%d)" % [coord.x, coord.y], " ".join(detalhe))

		t = _us()
		var corpo := StaticBody3D.new()
		for caixa: Dictionary in dados["colisao"]:
			var forma := CollisionShape3D.new()
			if caixa.has("altura"):
				var mapa := HeightMapShape3D.new()
				mapa.map_width = int(caixa["lado"])
				mapa.map_depth = int(caixa["lado"])
				mapa.map_data = caixa["altura"]
				forma.shape = mapa
				forma.position = caixa["pos"]
				forma.scale = Vector3.ONE * float(caixa.get("escala", 1.0))
			else:
				var box := BoxShape3D.new()
				box.size = caixa["tamanho"]
				forma.shape = box
				forma.position = caixa["pos"]
				if caixa.has("giro"):
					forma.rotation = caixa["giro"]
			corpo.add_child(forma)
			n_formas += 1
		no.add_child(corpo)
		_somar(etapas, "colisao", t)

		t = _us()
		var oclusor := ChunkManager._oclusor(dados["colisao"])
		if oclusor != null:
			no.add_child(oclusor)
		_somar(etapas, "oclusor", t)

		t = _us()
		no.position = Vector3(coord.x * 32.0, 0.0, coord.y * 32.0)
		raiz.add_child(no)
		_somar(etapas, "entrar", t)

		t = _us()
		ChunkManager._coord_do_prop = coord
		for prop: Dictionary in dados["props"]:
			var tipo := String(prop.get("tipo", "?"))
			var tp := _us()
			var criado: Node3D = ChunkManager._criar_prop(prop)
			if criado != null:
				no.add_child(criado)
			var ms := float(_us() - tp) / 1000.0
			if not _coords.is_empty() and ms > 0.5:
				_relatar("prop_caro(%d,%d)" % [coord.x, coord.y], "%s %.1f ms" % [tipo, ms])
			var serie: PackedFloat32Array = por_tipo.get(tipo, PackedFloat32Array())
			serie.append(ms)
			por_tipo[tipo] = serie
		_somar(etapas, "props", t)
		_somar(etapas, "total", t_total)
		if not _coords.is_empty():
			_relatar("chunk(%d,%d)" % [coord.x, coord.y], "total=%.1f malhas=%.1f colisao=%.1f oclusor=%.1f entrar=%.1f props=%.1f" % [
				etapas["total"][-1], etapas["malhas"][-1], etapas["colisao"][-1],
				etapas["oclusor"][-1], etapas["entrar"][-1], etapas["props"][-1]])
		# Liberar e o que a descarga faz (queue_free, no fim do quadro): aqui na
		# hora, cronometrado, depois de um quadro desenhado com ele.
		await arvore.process_frame
		var nos_do_chunk := _contar(no)
		var tl := _us()
		no.free()
		var ms_liberar := float(_us() - tl) / 1000.0
		var sl: PackedFloat32Array = etapas.get("liberar", PackedFloat32Array())
		sl.append(ms_liberar)
		etapas["liberar"] = sl
		if not _coords.is_empty():
			_relatar("liberar(%d,%d)" % [coord.x, coord.y], "%.1f ms, %d nos" % [ms_liberar, nos_do_chunk])
		await arvore.process_frame

	_relatar("chunks", "%d (malhas %d, formas de colisao %d)" % [coords.size(), n_malhas, n_formas])
	for k: String in ["total", "malhas", "colisao", "oclusor", "entrar", "props", "liberar"]:
		var s: PackedFloat32Array = etapas[k]
		_relatar("etapa." + k, _resumo(s))
	var linhas: Array[String] = []
	for tipo: String in por_tipo:
		var s: PackedFloat32Array = por_tipo[tipo]
		var soma := 0.0
		for x: float in s:
			soma += x
		linhas.append("%8.1f ms total  %-18s n=%-4d %s" % [soma, tipo, s.size(), _resumo(s)])
	linhas.sort()
	linhas.reverse()
	for l: String in linhas:
		print("[chunk] prop ", l)

	# O pedestre da multidao, que nasce enquanto se dirige.
	var ped := PackedFloat32Array()
	for i in _pedestres:
		var id := RegistroCivil.id_de_transeunte(1000 + i * 7919)
		var ficha := RegistroCivil.identidade(id)
		if ficha.is_empty():
			continue
		var tp := _us()
		var p := Pedestre.new()
		p.preparar(ficha, Vector4i(0, 0, 0, 0), Vector4i(0, 0, 1, 0))
		raiz.add_child(p)
		ped.append(float(_us() - tp) / 1000.0)
		await arvore.process_frame
		p.queue_free()
	_relatar("pedestre", _resumo(ped))

	# A TV original contra a replica do `_ready`, em sequencia, sem espera.
	var seq := PackedStringArray()
	for qual: String in ["tv", "tv", "replica", "replica", "tv", "tv_fora_da_arvore"]:
		var ts := _us()
		var novo: Node3D = TVMedida.new() if qual == "replica" else Televisao.new()
		if qual == "tv_fora_da_arvore":
			novo._ready()
		else:
			raiz.add_child(novo)
		seq.append("%s=%.2f" % [qual, float(_us() - ts) / 1000.0])
	_relatar("tv_sequencia", " ".join(seq))
	await arvore.process_frame
	# Cada variante como a PRIMEIRA coisa de um quadro novo.
	var por_quadro := PackedStringArray()
	for qual: String in ["replica", "tv", "tv", "replica", "tv_new_so", "tv"]:
		await arvore.process_frame
		await arvore.process_frame
		var ts := _us()
		var novo: Node3D = TVMedida.new() if qual == "replica" else Televisao.new()
		var tn := _us()
		if qual != "tv_new_so":
			raiz.add_child(novo)
		por_quadro.append("%s=new %.2f+add %.2f" % [qual, float(tn - ts) / 1000.0, float(_us() - tn) / 1000.0])
	_relatar("tv_por_quadro", " | ".join(por_quadro))
	# Hipotese: o SubViewport espera os envios de malha pendentes para a GPU.
	var envio := PackedStringArray()
	for caso: String in ["sem_malha", "malha_mesmo_quadro", "sem_malha", "malha_mesmo_quadro", "malha_quadro_anterior", "sem_malha", "so_subviewport_apos_malha"]:
		await arvore.process_frame
		await arvore.process_frame
		var malhas: Array[Node] = []
		if caso.begins_with("malha") or caso.begins_with("so_"):
			for k in 40:
				var mi := MeshInstance3D.new()
				mi.mesh = PSXMesh.cone(0.3 + k * 0.001, 1.7, 3.4, 16, 6, Color.WHITE, Color.WHITE)
				raiz.add_child(mi)
				malhas.append(mi)
			if caso == "malha_quadro_anterior":
				await arvore.process_frame
		var ts := _us()
		var n: Node
		if caso == "so_subviewport_apos_malha":
			var vp2 := SubViewport.new()
			vp2.size = Vector2i(320, 240)
			vp2.disable_3d = true
			raiz.add_child(vp2)
			var _tx := vp2.get_texture()
			n = vp2
		else:
			n = Televisao.new()
			raiz.add_child(n)
		envio.append("%s=%.2f" % [caso, float(_us() - ts) / 1000.0])
		await arvore.process_frame
		n.queue_free()
		for m: Node in malhas:
			m.queue_free()
	_relatar("tv_envio", " | ".join(envio))

	# A TV do bar, por partes: 19 ms por instancia medidos acima.
	var partes := {"tv_inteira": PackedFloat32Array(), "subviewport": PackedFloat32Array(),
		"partida_ps2": PackedFloat32Array(), "em_loop_tv_chiado": PackedFloat32Array(),
		"tocar_tv_chiado": PackedFloat32Array(), "em_loop_bar_estadio_loop": PackedFloat32Array(),
		"tocar_bar_estadio_loop": PackedFloat32Array(), "spot": PackedFloat32Array(),
		"facho": PackedFloat32Array()}
	for i in 4:
		var t := _us()
		var tv := Televisao.new()
		raiz.add_child(tv)
		_somar(partes, "tv_inteira", t)
		await arvore.process_frame
		tv.queue_free()
		var tn := _us()
		var tvm := TVMedida.new()
		var tn2 := _us()
		raiz.add_child(tvm)
		var tn3 := _us()
		tvm.tempos["new"] = float(tn2 - tn) / 1000.0
		tvm.tempos["add_child_total"] = float(tn3 - tn2) / 1000.0
		_relatar("tv_por_funcao", tvm.tempos)
		await arvore.process_frame
		tvm.queue_free()
		t = _us()
		var vp := SubViewport.new()
		vp.size = Vector2i(PartidaPS2.LARGURA, PartidaPS2.ALTURA)
		vp.disable_3d = true
		raiz.add_child(vp)
		_somar(partes, "subviewport", t)
		t = _us()
		var pt := PartidaPS2.new()
		vp.add_child(pt)
		_somar(partes, "partida_ps2", t)
		await arvore.process_frame
		vp.queue_free()
		for som: StringName in [&"tv_chiado", &"bar_estadio_loop"]:
			t = _us()
			var s := AudioDirector.em_loop(som)
			_somar(partes, "em_loop_" + String(som), t)
			t = _us()
			var pl := AudioStreamPlayer3D.new()
			pl.stream = s
			raiz.add_child(pl)
			pl.play()
			_somar(partes, "tocar_" + String(som), t)
			await arvore.process_frame
			pl.queue_free()
		t = _us()
		var luz := SpotLight3D.new()
		luz.spot_range = 7.4
		luz.light_volumetric_fog_energy = 2.2
		raiz.add_child(luz)
		_somar(partes, "spot", t)
		t = _us()
		var fa := MeshInstance3D.new()
		fa.mesh = PSXMesh.cone(0.34, 1.70, 3.40, 8, 3, Color(0.58, 0.78, 1.0, 0.78), Color(0.58, 0.78, 1.0, 0.0))
		raiz.add_child(fa)
		_somar(partes, "facho", t)
		await arvore.process_frame
		luz.queue_free()
		fa.queue_free()
	for k: String in partes:
		_relatar("parte." + k, _resumo(partes[k]))
	arvore.quit(0)


func _somar(etapas: Dictionary, k: String, t0: int) -> void:
	var s: PackedFloat32Array = etapas[k]
	s.append(float(_us() - t0) / 1000.0)
	etapas[k] = s


static func _resumo(s: PackedFloat32Array) -> String:
	if s.is_empty():
		return "-"
	var o := s.duplicate()
	o.sort()
	var soma := 0.0
	for x: float in o:
		soma += x
	return "media=%.2f mediana=%.2f p90=%.2f max=%.2f ms" % [
		soma / o.size(), o[o.size() / 2], o[int(o.size() * 0.9)], o[o.size() - 1]]
