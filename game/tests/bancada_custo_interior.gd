## Quanto custa, no fio principal, montar a sala de um `InteriorNoMundo`.
##
##     godot --path game --resolution 3840x2160 res://tests/bancada_custo_interior.tscn -- --estilo=moderno
##
## Dirigindo, o `_process` do InteriorNoMundo chegou a 47,8 ms num quadro
## (bancada_fps_dirigir --faixas-proc, 24/09/2026). Aqui cada planta (casa da
## fumaca e mercado, tres sementes) e montada longe do jogador, pelo mesmo
## caminho do jogo, e cada pedaco e cronometrado: cada superficie da sala
## (`PSXMesh.dados_para_mesh`), cada etapa da montagem (malhas, colisao,
## estufa, CasaViva) e cada prop da fila (`_nascer_um`, um por quadro como no
## jogo). Imprime `[interior] ...` em ms.
extends Node


func _ready() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.0, 1.6, 8.0)
	(load("res://tests/aviso_de_bancada.gd") as GDScript).call(&"mostrar", self, "Custo de montar a casa da fumaca e o mercado (~15 s).")
	_rodar()


func _relatar(chave: String, valor: Variant) -> void:
	print("[interior] %s %s" % [chave, valor])


func _rodar() -> void:
	var arvore := get_tree()
	await arvore.process_frame
	# O mesmo aquecimento do titulo: sem ele o primeiro de cada coisa mede a
	# carga fria do disco, que no jogo ja aconteceu no menu.
	AquecimentoDeShaders.iniciar(self)
	while not AquecimentoDeShaders.pronto():
		await arvore.process_frame
	for planta: StringName in [&"casa_fumaca", &"mercado"]:
		for semente: int in [11, 222, 3333]:
			var t0 := Time.get_ticks_usec()
			var dados := LoteNoMundo.planta_de(planta, semente)
			var t_planta := (Time.get_ticks_usec() - t0) / 1000.0
			# As superficies uma a uma, como `_montar_malhas` as faz.
			var sup: Dictionary = dados["superficies"]
			var lista: Array = []
			var soma := 0.0
			for material: StringName in sup:
				var d: Dictionary = sup[material]
				if PSXMesh.dados_vazio(d):
					continue
				var ta := Time.get_ticks_usec()
				var m := PSXMesh.dados_para_mesh(d)
				var ms := (Time.get_ticks_usec() - ta) / 1000.0
				soma += ms
				lista.append([ms, "%s(%dv)" % [material, (d.get("v", PackedVector3Array()) as PackedVector3Array).size()]])
				m = null
			lista.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
			var caras := PackedStringArray()
			for par: Array in lista.slice(0, 6):
				caras.append("%s=%.2f" % [par[1], par[0]])
			_relatar("%s/%d" % [planta, semente], "planta_thread=%.1f superficies=%d soma_malhas=%.1f caras: %s" % [
				t_planta, lista.size(), soma, " ".join(caras)])

			# O caminho do jogo: um InteriorNoMundo longe do jogador (sem jogador
			# na cena ele nunca se reavalia), com os dados entregues a mao.
			var casa := InteriorNoMundo.new()
			casa.planta = planta
			casa.semente = semente
			add_child(casa)
			# A fila anda por aqui, cronometrada, e nao pelo `_process` dela.
			casa.set_process(false)
			casa.position = Vector3(0.0, 0.0, -6.0)
			casa.set(&"_dados", dados)
			var tm := Time.get_ticks_usec()
			var etapas := _montar_malhas_cronometrado(casa)
			_relatar("%s/%d" % [planta, semente], "montar_malhas=%.1f | %s" % [
				(Time.get_ticks_usec() - tm) / 1000.0, etapas])
			# A prateleira do mercado por dentro: `criar` e cada passo do `_ready`,
			# fora da arvore (as chamadas ao RenderingServer sao as mesmas).
			for prop: Dictionary in dados["props"]:
				if String(prop.get("tipo", "")) != "prateleira_viva":
					continue
				var tc := Time.get_ticks_usec()
				var pv := PrateleiraViva.criar(prop)
				var partes := PackedStringArray(["criar=%.2f" % ((Time.get_ticks_usec() - tc) / 1000.0)])
				tc = Time.get_ticks_usec()
				EstoqueMercado.aplicar(pv.loja, pv.vagas)
				partes.append("estoque=%.2f" % ((Time.get_ticks_usec() - tc) / 1000.0))
				var fs: Array = pv.get(&"_por_face")
				fs.resize(pv.faces.size())
				for i in pv.faces.size():
					fs[i] = []
				for i in pv.vagas.size():
					(fs[int(pv.vagas[i]["face"])] as Array).append(i)
				for passo: String in ["_montar_produtos", "_montar_etiquetas", "_montar_destaque"]:
					tc = Time.get_ticks_usec()
					pv.call(StringName(passo))
					partes.append("%s=%.2f" % [passo, (Time.get_ticks_usec() - tc) / 1000.0])
				# A conta das unidades anda numa thread; aqui a espera por ela no
				# fio principal (no jogo ela chega sozinha, quadros depois).
				tc = Time.get_ticks_usec()
				pv.call(&"_garantir_produtos")
				partes.append("thread_e_subir=%.2f" % ((Time.get_ticks_usec() - tc) / 1000.0))
				var instancias := 0
				for mm: MultiMesh in (pv.get(&"_mm") as Dictionary).values():
					instancias += mm.instance_count
				_relatar("%s/%d prateleira" % [planta, semente], "vagas=%d instancias=%d faces=%d | %s" % [
					pv.vagas.size(), instancias, pv.faces.size(), " ".join(partes)])
				pv.free()
			var props := PackedStringArray()
			var pior := 0.0
			var total := 0.0
			var fila: Array = casa.get(&"_fila")
			var n := fila.size()
			for i in n:
				fila = casa.get(&"_fila")
				if fila.is_empty():
					break
				var prop: Dictionary = (fila[0] as Dictionary)["prop"]
				var tp := Time.get_ticks_usec()
				casa.call(&"_nascer_um")
				var ms := (Time.get_ticks_usec() - tp) / 1000.0
				total += ms
				pior = maxf(pior, ms)
				if ms > 1.0:
					props.append("%s=%.1f" % [prop.get("tipo", "?"), ms])
				await arvore.process_frame
			_relatar("%s/%d" % [planta, semente], "props=%d total=%.1f pior=%.1f acima_1ms: %s" % [
				n, total, pior, " ".join(props)])
			casa.free()
			await arvore.process_frame
	arvore.quit(0)


## A montagem da sala etapa por etapa (`InteriorNoMundo._planejar_montagem`),
## cada uma no relogio: a maior etapa e o que um quadro paga no jogo, e a soma
## e o que antes ia num quadro so.
func _montar_malhas_cronometrado(casa: InteriorNoMundo) -> String:
	casa.call(&"_planejar_montagem")
	var etapas: Array = casa.get(&"_etapas")
	var tempos: Array = []
	var soma := 0.0
	while not etapas.is_empty():
		var etapa: Array = etapas.pop_front()
		var t0 := Time.get_ticks_usec()
		(etapa[1] as Callable).call()
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		soma += ms
		tempos.append([ms, String(etapa[0])])
	tempos.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var partes := PackedStringArray()
	for par: Array in tempos.slice(0, 6):
		partes.append("%s=%.2f" % [par[1], par[0]])
	return "etapas=%d soma=%.1f maior: %s" % [tempos.size(), soma, " ".join(partes)]
