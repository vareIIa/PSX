## O "carregando shaders" do menu (PLANO_DESEMPENHO_E_HORIZONTE, Fase 2).
##
## Por que
## -------
## A cidade e sorteada, mas o catalogo nao: 166 materiais de chunk, 34 shaders e
## algumas dezenas de props que montam o proprio material (convidado, TV,
## sinuca, fumaca...). Tudo o que o jogador ainda nao tinha visto compilava NA
## HORA em que aparecia pela primeira vez: quadros de 50 a 70 ms dirigindo,
## iguais em toda execucao nova (24/09/2026, `tests/bancada_fps_dirigir.gd
## --duas-voltas`). Aqui cada peca do catalogo e desenhada uma vez, antes de
## jogar, e a `ReservaDeShaders` segura o que compilou ate o fim da sessao.
##
## Como
## ----
##   catalogo   `ChunkBuilder.construir` em thread para os chunks em volta da
##              praca: toda superficie (material x formato de malha) e ate
##              `EXEMPLOS` de cada tipo de prop, pela mesma `_criar_prop` do jogo.
##   desenho    um SubViewport com as MESMAS opcoes da janela (TAA, MSAA, escala,
##              atlas de sombra) e o MESMO mundo — ambiente, sol, nevoa e
##              desfoque sao os do jogo —, com a camera num canto 900 m abaixo da
##              cidade. A pipeline que ele pede e a que a tela principal pediria.
##   liberar    cada peca fica `QUADROS_VISTOS` quadros na tela e sai. So fica o
##              que a reserva segurou.
##   interiores as salas da rua (`LoteNoMundo.PLANTAS`: casa da fumaca e
##              mercado) montadas em thread: as superficies delas e da estufa, os
##              props pela `Interiores.criar_prop` do jogo, e as faces das caixas
##              do caminho (`CasaViva.faces_da_caixa`). Sem isto a primeira
##              visita custava 108 ms num convidado, 75 na festa e 47 na fumaca
##              (tests/bancada_custo_interior.gd, 24/09/2026).
##
## Enquanto `pronto()` e falso, o titulo apaga CONTINUAR, CARREGAR e NOVO JOGO e
## mostra a barra (`PainelAquecimento`). Sem RenderingDevice (PS1 STYLE, servidor)
## nao ha o que aquecer: `pronto()` ja nasce verdadeiro.
class_name AquecimentoDeShaders
extends Node

signal terminou

## Chunks em volta da origem varridos para montar o catalogo (11 x 11).
const RAIO := 5
## Tempo de montagem de pecas por quadro, em microssegundos: o menu continua
## respondendo enquanto aquece.
const ORCAMENTO_US := 12000
## Quadros desenhados com a peca na vista antes de ela sair.
const QUADROS_VISTOS := 4
const ONDE := Vector3(0.0, -900.0, 0.0)
## Prop que nao entra: som, registro no GPS, rotina do bar, inimigo, interior
## montado por distancia e luneta (tocam algo ou tomam a camera).
const FORA: Array[String] = ["ponto_bar", "som_ambiente", "sino", "vida_bar",
	"inimigo", "interior_mundo", "luneta"]
## Semente das salas aquecidas. O catalogo delas nao muda com a semente; so a
## arrumacao.
const SEMENTE_SALA := 1
## Exemplos por tipo. Gente varia de roupa, cabelo e cigarro, e cada combinacao
## pode gerar material proprio.
const EXEMPLOS := {"convidado": 16, "morador": 8}
const EXEMPLOS_PADRAO := 2
## Teto da espera final pelas pipelines que ainda compilam em segundo plano.
const ESPERA_MAX_S := 6.0

static var _instancia: AquecimentoDeShaders
static var _pronto := false

## De 0 a 1, para a barra.
var fracao := 0.0
## Uma linha do que foi feito, para bancada e log.
var relatorio := ""

var _vp: SubViewport
var _raiz: Node3D
var _mutex := Mutex.new()
var _brutos := {}
var _plantas := {}


## Comeca o aquecimento, uma vez por sessao. Chamar de novo nao faz nada.
static func iniciar(de: Node) -> void:
	if _pronto or _instancia != null:
		return
	if RenderingServer.get_rendering_device() == null or DisplayServer.get_name() == "headless":
		_pronto = true
		return
	_instancia = AquecimentoDeShaders.new()
	_instancia.name = "AquecimentoDeShaders"
	de.get_tree().root.add_child.call_deferred(_instancia)


## Ja da para jogar? Verdadeiro tambem quando o aquecimento nunca comecou
## (`--pular-menu`, teste, servidor): so o titulo espera por ele.
static func pronto() -> bool:
	return _pronto or _instancia == null


static func instancia() -> AquecimentoDeShaders:
	return _instancia


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rodar()


func _rodar() -> void:
	var t0 := Time.get_ticks_usec()
	var p0 := _pipelines()
	_montar_vista()

	# 1. O catalogo, em thread.
	var coords: Array[Vector2i] = []
	for dz in range(-RAIO, RAIO + 1):
		for dx in range(-RAIO, RAIO + 1):
			coords.append(Vector2i(dx, dz))
	var id := WorkerThreadPool.add_group_task(_construir.bind(coords), coords.size(),
		-1, false, "aquecimento de shaders")
	var id_plantas := WorkerThreadPool.add_task(_construir_plantas, false,
		"aquecimento de shaders: interiores")
	while not WorkerThreadPool.is_group_task_completed(id) \
			or not WorkerThreadPool.is_task_completed(id_plantas):
		fracao = 0.35 * float(WorkerThreadPool.get_group_processed_element_count(id)) \
			/ coords.size()
		await get_tree().process_frame
	WorkerThreadPool.wait_for_group_task_completion(id)
	WorkerThreadPool.wait_for_task_completion(id_plantas)
	var t_catalogo := Time.get_ticks_usec()

	var superficies := {}
	var props: Array = []
	var por_tipo := {}
	for i in coords.size():
		var d: Dictionary = _brutos.get(i, {})
		if d.is_empty():
			continue
		var sup: Dictionary = d["superficies"]
		for mat: StringName in sup:
			var s: Dictionary = sup[mat]
			if PSXMesh.dados_vazio(s):
				continue
			var base := StringName(String(mat).get_slice("@", 0))
			var uv2: PackedVector2Array = s.get("uv2", PackedVector2Array())
			var com_uv2 := not uv2.is_empty() and uv2.size() == (s["v"] as PackedVector3Array).size()
			var chave := "%s|%s" % [base, com_uv2]
			if not superficies.has(chave):
				superficies[chave] = [base, com_uv2]
		for p: Dictionary in d["props"]:
			var tipo := String(p.get("tipo", ""))
			if tipo.is_empty() or FORA.has(tipo):
				continue
			var n := int(por_tipo.get(tipo, 0))
			if n >= int(EXEMPLOS.get(tipo, EXEMPLOS_PADRAO)):
				continue
			por_tipo[tipo] = n + 1
			props.append([coords[i], p])
	_brutos.clear()
	# As salas: superficies com o material de interior, props pela porta do
	# interior, e as caixas do caminho.
	var caixas: Array = []
	for planta: StringName in _plantas:
		var dp: Dictionary = _plantas[planta]
		var partes: Array[Dictionary] = [dp]
		if dp.has("estufa"):
			partes.append(dp["estufa"]["dados"])
		for parte: Dictionary in partes:
			var sup: Dictionary = parte["superficies"]
			for mat: StringName in sup:
				var s: Dictionary = sup[mat]
				if PSXMesh.dados_vazio(s):
					continue
				var uv2: PackedVector2Array = s.get("uv2", PackedVector2Array())
				var com_uv2 := not uv2.is_empty() and uv2.size() == (s["v"] as PackedVector3Array).size()
				var chave := "interior|%s|%s" % [mat, com_uv2]
				if not superficies.has(chave):
					superficies[chave] = [mat, com_uv2, true]
			for p: Dictionary in parte["props"]:
				var tipo := String(p.get("tipo", ""))
				if tipo.is_empty() or FORA.has(tipo):
					continue
				var chave_tipo := "sala:" + tipo
				var n := int(por_tipo.get(chave_tipo, 0))
				if n >= int(EXEMPLOS.get(tipo, EXEMPLOS_PADRAO)):
					continue
				por_tipo[chave_tipo] = n + 1
				props.append([null, p])
		caixas.append_array(dp["colisao"])
		caixas.append_array(dp.get("so_caminho", []))
	_plantas.clear()
	# Todo material de chunk do projeto, nos dois formatos, e nao so os que o
	# trecho varrido tinha: o bar e o mercado do outro lado da cidade tem os
	# deles. Sao 166 arquivos; o quadrado custa quase nada.
	for arq in DirAccess.get_files_at("res://resources/materials"):
		var nome := arq.trim_suffix(".remap")
		if nome.begins_with("mat_") and nome.ends_with(".tres"):
			var base := StringName(nome.trim_prefix("mat_").trim_suffix(".tres"))
			for com_uv2 in [false, true]:
				var chave := "%s|%s" % [base, com_uv2]
				if not superficies.has(chave):
					superficies[chave] = [base, com_uv2]

	# 2. Toda superficie, num lote so: pecas pequenas, baratas de montar.
	var total := superficies.size() + props.size()
	var feitas := 0
	var quadrado := _quadrado(false)
	var quadrado_uv2 := _quadrado(true)
	var k := 0
	var inicio := Time.get_ticks_usec()
	var lote: Array[Node] = []
	for chave: String in superficies:
		var base: StringName = superficies[chave][0]
		var mi := MeshInstance3D.new()
		mi.mesh = quadrado_uv2 if bool(superficies[chave][1]) else quadrado
		if (superficies[chave] as Array).size() > 2:
			# Superficie de sala: o material e a sombra sao os do interior.
			mi.material_override = Interiores.material(base)
			mi.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				if Interiores.projeta(base)
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		else:
			mi.material_override = ChunkManager._material(base)
			mi.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if ChunkManager.SEM_SOMBRA.has(base)
				else GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		mi.position = Vector3(-6.0 + (k % 24) * 0.5, 0.3 + (k / 24) * 0.5, 0.0)
		_raiz.add_child(mi)
		lote.append(mi)
		k += 1
		feitas += 1
		if Time.get_ticks_usec() - inicio > ORCAMENTO_US:
			fracao = 0.35 + 0.6 * float(feitas) / maxf(total, 1)
			await get_tree().process_frame
			inicio = Time.get_ticks_usec()
	for _q in QUADROS_VISTOS:
		await get_tree().process_frame
	for no in lote:
		no.queue_free()

	# 3. Os props, pela mesma porta do jogo, em vagas na frente da camera. Cada
	# um sai depois de QUADROS_VISTOS quadros, e a vaga volta para a fila.
	var vivos: Array = []
	var vaga := 0
	inicio = Time.get_ticks_usec()
	for par: Array in props:
		var no: Node3D
		if par[0] == null:
			# Prop de sala: nasce pela porta do interior.
			no = Interiores.criar_prop(par[1] as Dictionary)
		else:
			ChunkManager._coord_do_prop = par[0]
			no = ChunkManager._criar_prop(par[1] as Dictionary)
		if no != null:
			no.position = Vector3(-10.5 + (vaga % 8) * 3.0, 0.0, 2.5 + (vaga / 8 % 2) * 3.0)
			no.rotation = Vector3.ZERO
			_raiz.add_child(no)
			vivos.append([no, Engine.get_process_frames()])
			vaga = (vaga + 1) % 16
		feitas += 1
		if Time.get_ticks_usec() - inicio > ORCAMENTO_US or vivos.size() >= 16:
			fracao = 0.35 + 0.6 * float(feitas) / maxf(total, 1)
			await get_tree().process_frame
			inicio = Time.get_ticks_usec()
			vivos = _liberar_vistos(vivos)
	while not vivos.is_empty():
		await get_tree().process_frame
		vivos = _liberar_vistos(vivos)

	# As faces das caixas do caminho das salas, guardadas por tamanho: a fonte
	# do caminho da primeira visita sai quase de graca (CasaViva.faces_da_caixa).
	for c: Dictionary in caixas:
		CasaViva.faces_da_caixa(c["tamanho"])
		if Time.get_ticks_usec() - inicio > ORCAMENTO_US:
			await get_tree().process_frame
			inicio = Time.get_ticks_usec()

	# 4. As pipelines que o motor compila em segundo plano: espera o contador
	# parar de subir.
	var parado := 0
	var ultimo := _pipelines()
	var espera := 0.0
	while parado < 10 and espera < ESPERA_MAX_S:
		await get_tree().process_frame
		espera += get_process_delta_time()
		var agora := _pipelines()
		parado = parado + 1 if agora == ultimo else 0
		ultimo = agora
		fracao = minf(0.99, fracao + 0.005)

	relatorio = "%d superficies, %d props (%s), %d pipelines, catalogo %.1f s, total %.1f s, reserva %d" % [
		superficies.size(), props.size(), " ".join(PackedStringArray(por_tipo.keys())),
		_pipelines() - p0, float(t_catalogo - t0) / 1e6,
		float(Time.get_ticks_usec() - t0) / 1e6, ReservaDeShaders.presos()]
	print("[aquecimento] ", relatorio)
	fracao = 1.0
	_pronto = true
	_instancia = null
	_vp.queue_free()
	terminou.emit()
	queue_free()


## As salas da rua, numa thread (e o que `InteriorNoMundo` faz na dele).
func _construir_plantas() -> void:
	for planta: StringName in LoteNoMundo.PLANTAS:
		var d := LoteNoMundo.planta_de(planta, SEMENTE_SALA)
		_mutex.lock()
		_plantas[planta] = d
		_mutex.unlock()


## Roda nas threads do grupo. Nao toca em no nem em recurso.
func _construir(i: int, coords: Array[Vector2i]) -> void:
	var d := ChunkBuilder.construir(coords[i].x, coords[i].y)
	_mutex.lock()
	_brutos[i] = d
	_mutex.unlock()


func _liberar_vistos(vivos: Array) -> Array:
	var restam: Array = []
	var agora := Engine.get_process_frames()
	for par: Array in vivos:
		if agora - int(par[1]) >= QUADROS_VISTOS:
			if is_instance_valid(par[0]):
				(par[0] as Node).queue_free()
		else:
			restam.append(par)
	return restam


## A vista do aquecimento: as opcoes da janela, o mundo da janela.
func _montar_vista() -> void:
	var jan := get_tree().root
	_vp = SubViewport.new()
	_vp.name = "Vista"
	_vp.size = Vector2i(960, 540)
	_vp.own_world_3d = false
	_vp.world_3d = jan.find_world_3d()
	_vp.msaa_3d = jan.msaa_3d
	_vp.screen_space_aa = jan.screen_space_aa
	_vp.use_taa = jan.use_taa
	_vp.use_debanding = jan.use_debanding
	_vp.scaling_3d_mode = jan.scaling_3d_mode
	_vp.scaling_3d_scale = jan.scaling_3d_scale
	_vp.positional_shadow_atlas_size = jan.positional_shadow_atlas_size
	_vp.positional_shadow_atlas_16_bits = jan.positional_shadow_atlas_16_bits
	_vp.use_occlusion_culling = jan.use_occlusion_culling
	_vp.mesh_lod_threshold = jan.mesh_lod_threshold
	_vp.use_hdr_2d = jan.use_hdr_2d
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_raiz = Node3D.new()
	_raiz.name = "Vitrine"
	_raiz.position = ONDE
	_vp.add_child(_raiz)
	var cam := Camera3D.new()
	cam.fov = 100.0
	cam.far = 200.0
	_vp.add_child(cam)
	cam.position = ONDE + Vector3(0.0, 3.0, 12.0)
	cam.look_at(ONDE + Vector3(0.0, 2.0, 0.0))
	cam.current = true


## Um quadrado no formato de malha de chunk (`PSXMesh.dados_para_mesh`), com ou
## sem a segunda UV: sao os dois formatos que as superficies da cidade tem.
static func _quadrado(com_uv2: bool) -> ArrayMesh:
	var d := PSXMesh.plane_dados(Vector2(0.4, 0.4))
	var uv2 := PackedVector2Array()
	if com_uv2:
		for v: Vector3 in (d["v"] as PackedVector3Array):
			uv2.append(Vector2(v.x, v.y))
	d["uv2"] = uv2
	return PSXMesh.dados_para_mesh(d)


static func _pipelines() -> int:
	var total := 0
	for info: int in [RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS,
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH,
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE,
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW,
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION]:
		total += RenderingServer.get_rendering_info(info)
	return total
