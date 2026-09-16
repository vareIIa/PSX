## Quanto a agua da cabine custa. Criterio C11.
##
##     godot --path game --script res://tests/medir_orcamento_cabine.gd
##
## SEM --headless: chamada de desenho so existe com janela.
##
## O criterio
## ----------
##   +4 chamadas de desenho, no maximo, no plano de dentro
##   simulacao <= 0,3 ms de CPU por quadro
##   cabine do jogador <= 2.500 triangulos
##
## "+4" e em relacao a antes do plano: a placa de agua presa a lente, as duas
## placas das janelas e os dois limpadores — CINCO chamadas (secao 4.12 do
## PLANO_CHUVA_CABINE_AAA). Aqui o custo de agora e medido de verdade, ligando e
## desligando a agua na mesma cena, e comparado com esses cinco.
##
## O tempo de CPU e medido neste binario, que e o do editor: a exportacao roda
## GDScript mais depressa, entao o numero daqui e o PIOR caso, e nao o medio.
extends SceneTree

const TAMANHO := Vector2i(480, 270)
const DT := 1.0 / 60.0
const V60 := 16.67
const QUADROS_CPU := 600
const ANTES := 5
const MAX_A_MAIS := 4
const MAX_MS := 0.3
const MAX_TRIANGULOS := 2500

var _falhas := 0


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var vp := SubViewport.new()
	vp.size = TAMANHO
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.4, 0.42, 0.45)
	amb.environment = env
	vp.add_child(amb)

	var medidas := Carroceria.montar(Carroceria.Modelo.MAREA, CarroCena.TINTA,
		CarroCena.SEMENTE, true, false)
	var carro := Node3D.new()
	vp.add_child(carro)
	var lataria := MeshInstance3D.new()
	lataria.mesh = medidas["corpo"] as ArrayMesh
	lataria.material_override = load(Carroceria.MATERIAL) as ShaderMaterial
	carro.add_child(lataria)
	var cab := CarroCabine.new()
	carro.add_child(cab)
	cab.montar(medidas)
	var cam := Camera3D.new()
	cam.fov = 74.0
	cam.near = 0.02
	cam.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-4.0)), cab.olho())
	vp.add_child(cam)
	cam.make_current()

	for i in 8:
		await process_frame

	# --- CPU: chuva cheia, 60 km/h, e o TETO de corredoras ---
	# Na chuva de verdade ficam 3 a 6 gotas grandes vivas por vez; o criterio e
	# sobre o pior caso, entao o vidro e reabastecido ate o teto a cada quadro.
	var cor: AguaCorredoras = null
	for no: Node in cab.find_children("*", "AguaCorredoras", true, false):
		cor = no as AguaCorredoras
	var paineis := cab.paineis()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var tempos: Array[float] = []
	var pior_vivas := 0
	for q in QUADROS_CPU:
		while cor != null and cor.quantas() < AguaCorredoras.TOTAL:
			var i := rng.randi_range(0, paineis.size() - 1)
			var tam: Vector2 = paineis[i]["tam"]
			cor.semear(i, Vector2(rng.randf() * tam.x, rng.randf() * tam.y * 0.3),
				rng.randf_range(1.0, 2.0))
		var t0 := Time.get_ticks_usec()
		cab.atualizar_clima(1.0, Vector3(0.0, 0.0, -V60), Vector3.ZERO, DT)
		tempos.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		if cor != null:
			pior_vivas = maxi(pior_vivas, cor.quantas())
		await process_frame
	var corredoras := pior_vivas
	# Os primeiros 120 quadros aquecem o mapa e os caches do motor: fora.
	var cheios := tempos.slice(120)
	cheios.sort()
	var media := 0.0
	for x in cheios:
		media += x
	media /= float(cheios.size())
	var p95: float = cheios[int(cheios.size() * 0.95)]

	# --- chamadas de desenho: agua ligada e desligada ---
	var ligada := await _chamadas()
	var agua := _nos_da_agua(cab)
	for no: Node in agua:
		if no is SubViewport:
			(no as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
		elif no is Node3D:
			(no as Node3D).visible = false
	var desligada := await _chamadas()
	var custo := ligada - desligada

	# --- triangulos ---
	var partes := {}
	var total := 0
	for no: Node in cab.find_children("*", "GeometryInstance3D", true, false):
		var n := _triangulos(no as GeometryInstance3D)
		var chave := String(no.name)
		partes[chave] = int(partes.get(chave, 0)) + n
		total += n

	print("\n=== C11: orcamento da cabine (Marea, chuva cheia, 60 km/h) ===")
	var ok_dc := custo - ANTES <= MAX_A_MAIS
	var ok_ms := media <= MAX_MS
	var ok_tri := total <= MAX_TRIANGULOS
	for ok: bool in [ok_dc, ok_ms, ok_tri]:
		if not ok:
			_falhas += 1
	print("  chamadas de desenho: %d com agua, %d sem -> a agua custa %d (antes do plano: %d) -> %+d  (limite +%d)  %s"
		% [ligada, desligada, custo, ANTES, custo - ANTES, MAX_A_MAIS,
			"OK" if ok_dc else "FALHOU"])
	print("  CPU de atualizar_clima: media %.3f ms, p95 %.3f ms, com ate %d corredoras vivas  (limite %.1f ms)  %s"
		% [media, p95, corredoras, MAX_MS, "OK" if ok_ms else "FALHOU"])
	print("  triangulos da cabine: %d  (limite %d)  %s" % [total, MAX_TRIANGULOS,
		"OK" if ok_tri else "FALHOU"])
	var chaves: Array = partes.keys()
	chaves.sort_custom(func(a, b): return partes[a] > partes[b])
	for k in chaves:
		print("      %6d  %s" % [partes[k], k])
	if ligada <= 0:
		print("  (sem leitura de chamadas: o teste nao mediu nada)")
		_falhas += 1
	print("\n=== %s ===" % ("C11 OK" if _falhas == 0 else "FALHOU: %d item(ns)" % _falhas))
	quit(0 if _falhas == 0 else 1)


## Chamadas de desenho do quadro, depois de o quadro assentar.
func _chamadas() -> int:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	return RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)


## Tudo que e da agua: o vidro, as corredoras, os limpadores e o viewport do mapa.
func _nos_da_agua(cab: CarroCabine) -> Array[Node]:
	var out: Array[Node] = []
	for no: Node in cab.find_children("*", "", true, false):
		if no.name == "Vidros" or no is AguaCorredoras or no is Limpador \
				or no is SubViewport:
			out.append(no)
	return out


func _triangulos(gi: GeometryInstance3D) -> int:
	if gi is MeshInstance3D:
		return _da_malha((gi as MeshInstance3D).mesh)
	if gi is MultiMeshInstance3D:
		var mm := (gi as MultiMeshInstance3D).multimesh
		if mm == null:
			return 0
		return _da_malha(mm.mesh) * mm.instance_count
	return 0


func _da_malha(m: Mesh) -> int:
	if m == null:
		return 0
	var n := 0
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var idx = arr[Mesh.ARRAY_INDEX]
		if idx != null and not (idx as PackedInt32Array).is_empty():
			n += (idx as PackedInt32Array).size() / 3
		else:
			n += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n
