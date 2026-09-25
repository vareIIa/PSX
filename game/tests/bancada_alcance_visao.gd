## Ate onde se enxerga na cidade: foto no eixo da avenida e foto do alto.
##
##     godot --path game --resolution 1920x1080 res://tests/bancada_alcance_visao.tscn -- --pular-menu --estilo=moderno --fog=neblina --saida=DIR
##     ... -- --sem-corte        desliga o corte de desenho por distancia (so o
##                               que ja esta carregado; nao carrega mais nada)
##     ... -- --sem-volume       desliga a nevoa volumetrica depois do preset
##     ... -- --rotulo=NOME      prefixo das fotos (padrao: o id do preset)
##     ... -- --i=N --z0=Z       outra linha de chunk (x = N * 32) e outro z
##     ... -- --horizonte=M      (ChunkManager) o anel distante ate M metros; a
##                               foto espera ele ficar ocioso (ate 200 s)
##
## Separa "sumiu por nevoa" de "sumiu por corte" de "nao existe": a mesma foto
## com e sem o corte (memoria: corte de desenho mede ate o centro), e a conta do
## que esta carregado. Tira duas fotos:
##
##   rua     1,2 m do chao, no eixo da avenida, olhando o comprimento dela: e o
##           que o jogador ve dirigindo.
##   alto    40 m acima do mesmo ponto, olhando o horizonte: e o que um mirante,
##           uma ladeira ou um predio mostram — onde a cidade tem de continuar.
##
## Imprime `[alcance] chave=valor`.
extends Node

var _saida := ""
var _sem_corte := false
var _sem_volume := false
var _rotulo := ""
var _i := -5
var _z0 := 100.0
## `--alto=M`: altura da foto de cima (m acima do chao).
var _alto := 40.0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
		elif arg == "--sem-corte":
			_sem_corte = true
		elif arg == "--sem-volume":
			_sem_volume = true
		elif arg.begins_with("--rotulo="):
			_rotulo = arg.trim_prefix("--rotulo=")
		elif arg.begins_with("--z0="):
			_z0 = arg.trim_prefix("--z0=").to_float()
		elif arg.begins_with("--i="):
			_i = arg.trim_prefix("--i=").to_int()
		elif arg.begins_with("--alto="):
			_alto = arg.trim_prefix("--alto=").to_float()
	var cidade: Node = (load("res://scenes/test/cidade.tscn") as PackedScene).instantiate()
	add_child(cidade)
	_rodar()


func _relatar(chave: String, valor: Variant) -> void:
	print("[alcance] %s=%s" % [chave, valor])


func _rodar() -> void:
	var arvore := get_tree()
	var jogador: Node3D = null
	while jogador == null:
		await arvore.physics_frame
		jogador = arvore.get_first_node_in_group(&"player") as Node3D
	var fog := arvore.get_first_node_in_group(&"fog_controller") as FogController
	var p := fog.preset_atual()
	if _rotulo.is_empty():
		_rotulo = String(p.id)

	# No eixo da avenida, no canteiro: nada de carro na frente da lente.
	var x := _i * MalhaUrbana.TAM
	var chao := Relevo.altura(x, _z0)
	jogador.global_position = Vector3(x, chao + 0.2, _z0)
	jogador.rotation.y = 0.0
	if jogador.has_method("travar"):
		jogador.call("travar", true)
	Transito.ativo = false
	Transito.limpar()

	var espera := 0.0
	var estavel := 0.0
	var antes := -1
	while espera < 30.0 and estavel < 2.0:
		await arvore.process_frame
		espera += get_process_delta_time()
		var n := ChunkManager.chunks_carregados()
		var ocioso: bool = ChunkManager._em_voo.is_empty() and ChunkManager._prontos.is_empty() 			and ChunkManager._montando.is_empty()
		estavel = estavel + get_process_delta_time() if (n == antes and ocioso) else 0.0
		antes = n
	var hz := ChunkManager.horizonte
	if hz != null:
		var t_hz := 0.0
		while t_hz < 480.0 and not (hz.ativo() and hz.ocioso()):
			await arvore.process_frame
			t_hz += get_process_delta_time()
		_relatar("horizonte", "espera=%.0fs ativo=%s celulas=%d triangulos=%d vertices=%d malhas=%d plantas_exatas=%d celulas_do_disco=%d" % [
			t_hz, hz.ativo(), hz.celulas(), hz.medida_triangulos, hz.medida_vertices,
			hz.medida_malhas, hz.medida_plantas_exatas, hz.medida_celulas_do_disco])
		var ms := hz.medida_malha_ms.duplicate()
		ms.sort()
		if not ms.is_empty():
			_relatar("horizonte.malha_ms", "n=%d mediana=%.1f p95=%.1f pior=%.1f" % [
				ms.size(), ms[ms.size() / 2], ms[mini(ms.size() - 1, ms.size() * 95 / 100)],
				ms[ms.size() - 1]])
	var mb := 1.0 / (1024.0 * 1024.0)
	_relatar("memoria", "video_mb=%.0f buffers_mb=%.0f texturas_mb=%.0f" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) * mb,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) * mb,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) * mb])
	if _sem_corte:
		ChunkManager.alcance_infinito = true
		for c: Vector2i in ChunkManager._carregados:
			ChunkManager._aplicar_alcance(ChunkManager._carregados[c])
	if _sem_volume:
		fog.environment.volumetric_fog_enabled = false

	_relatar("preset", "%s fog=%s begin=%.0f end=%.0f stream=%.0f alcance_render=%.0f corte=%s volume=%s" % [
		p.id, p.fog_enabled, p.fog_begin, p.fog_end, p.stream_radius,
		ChunkManager._alcance_render, not _sem_corte, fog.environment.volumetric_fog_enabled])
	_relatar("carregados", "%d chunks, raio de carga %d (borda do carregado a %.0f-%.0f m)" % [
		ChunkManager.chunks_carregados(), ChunkManager._raio_carga,
		ChunkManager._raio_carga * MalhaUrbana.TAM, (ChunkManager._raio_carga + 1) * MalhaUrbana.TAM])

	# A camera propria, e nao a do jogador: a do jogador tem cabeca, balanco e
	# braco de terceira pessoa. A lente e a mesma para os presets todos.
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 4000.0
	add_child(cam)
	cam.current = true
	cam.global_position = Vector3(x + 1.5, chao + 1.2, _z0)
	cam.look_at(cam.global_position + Vector3(0, 0, -100), Vector3.UP)
	await arvore.create_timer(2.5).timeout
	await _foto("rua")
	_relatar("rua.mais_longe_m", "%.0f" % _mais_longe(cam))

	cam.global_position = Vector3(x + 1.5, chao + _alto, _z0 + 30.0)
	cam.look_at(cam.global_position + Vector3(0, -8, -100), Vector3.UP)
	await arvore.create_timer(2.5).timeout
	await _foto("alto")
	_relatar("alto.mais_longe_m", "%.0f" % _mais_longe(cam))
	arvore.quit(0)


## A distancia do ponto de chao mais longe que um raio do centro e das
## laterais da imagem acerta. E o que EXISTE (colisao), e nao o que se ve.
func _mais_longe(cam: Camera3D) -> float:
	var espaco := cam.get_world_3d().direct_space_state
	var maior := 0.0
	var tam := get_viewport().get_visible_rect().size
	for fx: float in [0.1, 0.3, 0.5, 0.7, 0.9]:
		for fy: float in [0.35, 0.45, 0.5, 0.55]:
			var px := Vector2(tam.x * fx, tam.y * fy)
			var de := cam.project_ray_origin(px)
			var para := de + cam.project_ray_normal(px) * 3000.0
			var r := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(de, para))
			if not r.is_empty():
				maior = maxf(maior, de.distance_to(r["position"]))
	return maior


func _foto(nome: String) -> void:
	if _saida.is_empty():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_saida)
	var arq := _saida.path_join("%s_%s.png" % [_rotulo, nome])
	img.save_png(arq)
	_relatar("foto", arq)
