## Mede a placa da multidao em par, no mesmo processo: a `MultidaoEncapuzada`
## de agora contra a de antes (o script antigo, lido de um arquivo) e contra
## nenhuma, em blocos alternados, com as figuras espalhadas como na estrada
## (`MULTIDAO` na faixa da pista e `MULTIDAO_RODA` em volta de onde o carro
## para), nevoa, o farol com sombra e o fogo.
##
##     $G --path game --resolution 3840x2160 res://scenes/test/medir_multidao.tscn -- \
##        [--antiga=CAMINHO/multidao_encapuzada.gd] [--blocos=4] [--quadros=90]
##
## Por que no mesmo processo: a maquina tem duas placas e outras sessoes rodam
## Godot ao mesmo tempo, e a rodada da cena inteira varia mais que o custo da
## multidao. Aqui A, B e nada se alternam a cada `--quadros` quadros; a disputa
## pesa igual nos tres.
##
## Imprime `[medir_multidao] vista modo media p10 p50 p90 (ms de placa)`.
extends Node3D

const ALTURA_LENTE := 1.15
## A estrada: a multidao da pista vai de DE a ATE metros ao longo dela (a partir
## do alvo) e ate LONGE de lado; o alvo fica a LADO_ALVO da linha da pista.
const DE := -52.0
const ATE := 98.0
const PERTO := 3.6
const LONGE := 48.0
const LADO_ALVO := 5.6
const NA_PISTA := 440
const NA_RODA := 160
const TMP_ANTIGA := "res://tests/_tmpm_multidao_antiga.gd"

var _cam: Camera3D
var _nova: MultidaoEncapuzada
var _antiga: Node3D
## Variantes da de agora, para achar onde o custo mora: so a gente da pista (a
## mesma conta de figuras da antiga) e a de agora sem sombra.
var _nova_440: MultidaoEncapuzada
var _nova_sem_sombra: MultidaoEncapuzada
var _nova_sem_dedo: MultidaoEncapuzada
var _variantes := false
var _blocos := 4
var _quadros := 90
var _t := 0.0


func _ready() -> void:
	var caminho := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--antiga="):
			caminho = a.trim_prefix("--antiga=")
		elif a.begins_with("--blocos="):
			_blocos = int(a.trim_prefix("--blocos="))
		elif a.begins_with("--quadros="):
			_quadros = int(a.trim_prefix("--quadros="))
		elif a == "--variantes":
			_variantes = true
	_palco()
	var figs := _figuras()
	var us := Time.get_ticks_usec()
	_nova = MultidaoEncapuzada.criar(figs)
	print("[medir_multidao] criar a primeira: %.1f ms" % ((Time.get_ticks_usec() - us) / 1000.0))
	add_child(_nova)
	_nova.mirar(Vector3.ZERO)
	_nova.aparecer(true)
	if _variantes:
		_nova_440 = MultidaoEncapuzada.criar(figs.slice(0, NA_PISTA))
		us = Time.get_ticks_usec()
		_nova_sem_sombra = MultidaoEncapuzada.criar(figs)
		print("[medir_multidao] criar de novo (600): %.1f ms" % ((Time.get_ticks_usec() - us) / 1000.0))
		_nova_sem_dedo = MultidaoEncapuzada.criar(figs)
		for m: MultidaoEncapuzada in [_nova_440, _nova_sem_sombra, _nova_sem_dedo]:
			add_child(m)
			m.mirar(Vector3.ZERO)
			m.aparecer(true)
		# O material e um por multidao: zerar o alcance do dedo so nesta.
		_nova_sem_dedo._mats[0].set_shader_parameter(&"dedo_some", 0.0)
		for n: Node in _nova_sem_sombra.get_children():
			if n is GeometryInstance3D:
				(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A de antes com a gente de antes: so a da pista (a roda e nova).
	if not caminho.is_empty():
		_antiga = _carregar_antiga(caminho, figs.slice(0, NA_PISTA))
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	print("[medir_multidao] figuras=%d placa=%s antiga=%s" % [figs.size(),
		RenderingServer.get_video_adapter_name(), "sim" if _antiga != null else "nao"])
	_rodar()


func _process(delta: float) -> void:
	_t += delta
	_nova.passo(delta)
	if _variantes:
		_nova_440.passo(delta)
		_nova_sem_sombra.passo(delta)
		_nova_sem_dedo.passo(delta)
	if _antiga != null:
		_antiga.call(&"andar", _t)
		_antiga.call(&"mirar", Vector3.ZERO)


## O script antigo, sem o class_name (o de agora ja tem o nome), gravado num
## arquivo temporario do projeto e apagado no fim.
func _carregar_antiga(caminho: String, figs: Array) -> Node3D:
	var fonte := FileAccess.get_file_as_string(caminho)
	if fonte.is_empty():
		push_error("[medir_multidao] nao li %s" % caminho)
		return null
	fonte = fonte.replace("class_name MultidaoEncapuzada", "") \
		.replace("-> MultidaoEncapuzada:", "-> Node3D:") \
		.replace("var m := MultidaoEncapuzada.new()", "var m = load(\"%s\").new()" % TMP_ANTIGA)
	for f: Dictionary in figs:
		f["pisca"] = randf() < 0.33
	var arq := FileAccess.open(TMP_ANTIGA, FileAccess.WRITE)
	arq.store_string(fonte)
	arq.close()
	var g := load(TMP_ANTIGA) as GDScript
	if g == null:
		return null
	var m := g.call(&"criar", figs) as Node3D
	add_child(m)
	m.call(&"aparecer", true)
	return m


func _figuras() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6660
	var lista: Array = []
	var ocupado := {}
	var tentativas := 0
	# A pista corre em z (s cresce para -z), a linha dela em x = -LADO_ALVO.
	while lista.size() < NA_PISTA and tentativas < NA_PISTA * 8:
		tentativas += 1
		var s := rng.randf_range(DE, ATE)
		var lado := -1.0 if rng.randf() < 0.5 else 1.0
		var d := lado * lerpf(PERTO, LONGE, pow(rng.randf(), 1.5))
		var p := Vector3(-LADO_ALVO + d, 0.0, -s)
		if Vector2(p.x, p.z).length() < 10.0:
			continue
		if _ocupar(ocupado, p):
			lista.append(_fig(rng, p, 0.16, 0.42))
	tentativas = 0
	var n := 0
	while n < NA_RODA and tentativas < NA_RODA * 12:
		tentativas += 1
		var ang := rng.randf() * TAU
		var r := lerpf(10.0, 25.0, pow(rng.randf(), 1.4))
		var p := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		if _ocupar(ocupado, p):
			lista.append(_fig(rng, p, 0.14, 0.36))
			n += 1
	return lista


func _ocupar(ocupado: Dictionary, p: Vector3) -> bool:
	var c := Vector2i(floori(p.x / 1.3), floori(p.z / 1.3))
	if ocupado.has(c):
		return false
	ocupado[c] = true
	return true


func _fig(rng: RandomNumberGenerator, p: Vector3, v0: float, v1: float) -> Dictionary:
	return {"pos": p, "olha": Vector3.ZERO, "altura": rng.randf_range(1.72, 2.08),
		"rapidez": rng.randf_range(v0, v1),
		"curvado": 0.0 if rng.randf() < 0.6 else rng.randf_range(0.2, 0.85)}


func _palco() -> void:
	var amb := Environment.new()
	amb.background_mode = Environment.BG_COLOR
	amb.background_color = Color(0.010, 0.012, 0.016)
	amb.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	amb.ambient_light_color = Color(0.10, 0.11, 0.14)
	amb.ambient_light_energy = 0.08
	amb.tonemap_mode = Environment.TONE_MAPPER_AGX
	amb.ssao_enabled = true
	amb.fog_enabled = true
	amb.fog_light_color = Color(0.09, 0.10, 0.12)
	amb.fog_density = 0.035
	var mundo := WorldEnvironment.new()
	mundo.environment = amb
	add_child(mundo)
	var chao := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(300, 300)
	chao.mesh = plano
	chao.material_override = StandardMaterial3D.new()
	add_child(chao)
	for lado: float in [-1.0, 1.0]:
		var f := SpotLight3D.new()
		f.spot_range = 60.0
		f.spot_angle = 24.0
		f.light_energy = 14.0
		f.shadow_enabled = lado > 0.0
		add_child(f)
		f.position = Vector3(lado * 0.65, 0.75, -1.9)
		f.look_at(Vector3(lado * 1.0, 0.5, -14.0), Vector3.UP)
	var fogo := OmniLight3D.new()
	fogo.light_color = Color(1.0, 0.45, 0.15)
	fogo.omni_range = 12.0
	fogo.light_energy = 3.2
	add_child(fogo)
	fogo.position = Vector3(1.6, 0.9, -2.2)
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.near = 0.05
	_cam.far = 400.0
	add_child(_cam)
	_cam.make_current()


func _mostrar(modo: String) -> void:
	_nova.visible = modo == "nova"
	if _variantes:
		_nova_440.visible = modo == "nova_440"
		_nova_sem_sombra.visible = modo == "nova_sem_sombra"
		_nova_sem_dedo.visible = modo == "nova_sem_dedo"
	if _antiga != null:
		_antiga.visible = modo == "antiga"


func _rodar() -> void:
	var modos: Array[String] = ["nada", "nova"]
	if _antiga != null:
		modos = ["nada", "antiga", "nova"]
	if _variantes:
		modos.append_array(["nova_440", "nova_sem_sombra", "nova_sem_dedo"])
	var vistas := {"frente": Vector3(0.0, 1.0, -12.0), "pista": Vector3(-8.0, 1.0, -10.0),
		"atras": Vector3(0.0, 1.0, 12.0)}
	var medidas := {}
	var rid := get_viewport().get_viewport_rid()
	for _i in 60:
		await get_tree().process_frame
	for b in _blocos:
		for vista: String in vistas:
			_cam.position = Vector3(0.0, ALTURA_LENTE, 0.0)
			_cam.look_at(vistas[vista], Vector3.UP)
			# A ordem troca a cada bloco: nenhum modo fica sempre depois do outro.
			var ordem := modos.duplicate()
			if b % 2 == 1:
				ordem.reverse()
			for modo: String in ordem:
				_mostrar(modo)
				var chave := "%s %s" % [vista, modo]
				if not medidas.has(chave):
					# Array, e nao Packed: o Packed e copiado ao sair do dicionario.
					medidas[chave] = []
				for q in _quadros:
					await get_tree().process_frame
					# O tempo de placa chega uns quadros atrasado: fora os 12 primeiros.
					if q >= 12:
						(medidas[chave] as Array).append(
							RenderingServer.viewport_get_measured_render_time_gpu(rid))
	for vista: String in vistas:
		for modo: String in modos:
			var o: Array = medidas.get("%s %s" % [vista, modo], [])
			if o.is_empty():
				continue
			o.sort()
			var soma := 0.0
			for x: float in o:
				soma += x
			print("[medir_multidao] %-7s %-15s media %6.2f  p10 %6.2f  p50 %6.2f  p90 %6.2f  (n=%d)" % [
				vista, modo, soma / o.size(), o[int(o.size() * 0.1)], o[int(o.size() * 0.5)],
				o[int(o.size() * 0.9)], o.size()])
	if _antiga != null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_ANTIGA))
	get_tree().quit()
