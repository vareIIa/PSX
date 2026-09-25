## Assa os impostores da mata de fundo da estrada (MataDaEstrada).
##
## A mata de 30 a 210 m da pista era feita de caixas de folha (tres empilhadas
## por "copa"): do plano aereo a floresta era uma cidade de predios verdes, e do
## chao as copas longe eram quadradas. Impostor e a solucao dos jogos grandes
## para floresta de fundo: a arvore de VERDADE (a mesma ArvoreEsqueleto da
## beira) fotografada de varios angulos num atlas, e la longe um quadrado so
## que olha para a camera e mostra a foto do angulo certo, com a normal de
## cada pixel para a luz do jogo acender como acende a copa de perto.
##
## Quadros: AZIMUTES em volta x ELEVACOES de 0 a 75 graus (o carro ve a mata
## de lado; o plano aereo, de 10 a 50 graus para baixo). Cada quadro sai em
## QUADRO px, duas passadas (cor e normal), em PNG solto na pasta `--saida`;
## `tools/montar_impostores.py` reduz pela metade (super-amostragem), limpa a
## borda do alfa e monta os atlas em `assets/impostores/`.
##
##   godot --path game res://tests/assar_impostores.tscn -- --saida=DIR [--so=nome,nome]
##
## Precisa de janela (o headless nao desenha).
extends Node

const QUADRO := 1024
const AZIMUTES := 6
const ELEVACOES: Array[float] = [0.0, 25.0, 50.0, 75.0]

## A arvore do dossel da MataDaEstrada (a mesma de perto) em quatro portes e
## sementes: o fundo tem de ser a mesma floresta que a beira.
const VARIANTES: Array[Dictionary] = [
	{"nome": "dossel_a", "dossel": true, "porte": 0.95, "semente": 101},
	{"nome": "dossel_b", "dossel": true, "porte": 0.7, "semente": 202},
	{"nome": "dossel_c", "dossel": true, "porte": 0.45, "semente": 303},
	{"nome": "dossel_d", "dossel": true, "porte": 0.8, "semente": 404},
	{"nome": "arvoreta_a", "dossel": true, "jovem": true, "porte": 0.4, "semente": 505},
	{"nome": "arvoreta_b", "dossel": true, "jovem": true, "porte": 0.9, "semente": 606},
]

var _vp: SubViewport
var _cam: Camera3D
var _raiz: Node3D
var _saida := ""


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
	if _saida.is_empty():
		push_error("assar_impostores: falta --saida=DIR")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_saida)
	var so := PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--so="):
			so = arg.trim_prefix("--so=").split(",")
	ArvoreEsqueleto.variedade = false
	_montar_palco()
	var meta := {"quadro": QUADRO, "azimutes": AZIMUTES, "elevacoes": ELEVACOES, "variantes": []}
	for v: Dictionary in VARIANTES:
		if not so.is_empty() and not so.has(String(v["nome"])):
			continue
		var info := await _assar(v)
		(meta["variantes"] as Array).append(info)
		print("[impostor] %s raio %.2f centro %s" % [v["nome"], info["raio"], str(info["centro"])])
	var f := FileAccess.open(_saida.path_join("meta.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	print("[impostor] pronto")
	get_tree().quit()


func _montar_palco() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(QUADRO, QUADRO)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.fog_enabled = false
	env.glow_enabled = false
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_vp.add_child(_cam)
	_cam.current = true
	_raiz = Node3D.new()
	_vp.add_child(_raiz)


func _assar(v: Dictionary) -> Dictionary:
	for c in _raiz.get_children():
		c.queue_free()
	await get_tree().process_frame
	var sup: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(v["semente"])
	if v.get("dossel", false):
		MataDaEstrada.arvore_do_dossel(sup, Vector3.ZERO, float(v["porte"]), rng,
			v.get("jovem", false))
	elif v.get("conifera", false):
		ArvoreEsqueleto.de_conifera(sup, Vector3.ZERO, float(v["porte"]), rng, 0.2)
	else:
		var col: Array[Dictionary] = []
		ArvoreEsqueleto.arvore(sup, col, Vector3.ZERO, v["especie"], float(v["porte"]), rng)
	# A esfera que contem a arvore: o mesmo quadro (centro e escala) em todos os
	# angulos, que e o que deixa o jogo misturar dois quadros vizinhos.
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var pares: Array = []
	for chave: StringName in sup:
		var d: Dictionary = sup[chave]
		if PSXMesh.dados_vazio(d):
			continue
		for p: Vector3 in d["v"]:
			lo = lo.min(p)
			hi = hi.max(p)
		var mats := _materiais(chave)
		if mats.is_empty():
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = PSXMesh.dados_para_mesh(d)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_raiz.add_child(mi)
		pares.append([mi, mats])
	var centro := (lo + hi) * 0.5
	var raio := 0.0
	for chave: StringName in sup:
		var d: Dictionary = sup[chave]
		if PSXMesh.dados_vazio(d):
			continue
		for p: Vector3 in d["v"]:
			raio = maxf(raio, p.distance_to(centro))
	raio *= 1.02
	_cam.size = raio * 2.0
	_cam.near = 0.05
	_cam.far = raio * 4.0 + 10.0
	var nome := String(v["nome"])
	for modo in 2:
		for par: Array in pares:
			(par[0] as MeshInstance3D).material_override = (par[1] as Array)[modo]
		for fila in ELEVACOES.size():
			for coluna in AZIMUTES:
				var az := TAU * float(coluna) / float(AZIMUTES)
				var el := deg_to_rad(ELEVACOES[fila])
				var dir := Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el))
				_cam.position = centro + dir * (raio * 2.0 + 5.0)
				var cima := Vector3.UP if el < 1.4 else Vector3.FORWARD
				_cam.look_at(centro, cima)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var img := _vp.get_texture().get_image()
				img.save_png(_saida.path_join("%s_%s_%d_%d.png" % [nome,
					"cor" if modo == 0 else "nrm", fila, coluna]))
	return {"nome": nome, "raio": raio, "centro": [centro.x, centro.y, centro.z],
		"altura": hi.y - lo.y, "base_y": lo.y}


## As duas passadas (cor e normal) do material do jogo `chave` ("vegetacao",
## "casca@perto"...): a mesma textura HD, tinta e recorte que o jogo usa.
func _materiais(chave: StringName) -> Array:
	var nome := String(chave).get_slice("@", 0)
	var caminho := "res://resources/materials/mat_%s.tres" % nome
	if not ResourceLoader.exists(caminho):
		push_warning("assar_impostores: sem material " + caminho)
		return []
	var jogo := load(caminho) as ShaderMaterial
	var tex := jogo.get_shader_parameter(&"albedo_tex") as Texture2D
	var base := tex.resource_path.get_file().get_basename() if tex != null else nome
	if TexturasHD.tem(StringName(base)):
		tex = load(TexturasHD._achar(StringName(base), "")) as Texture2D
	var folha := Vegetacao.MATERIAIS_FOLHA.has(StringName(nome))
	var saida: Array = []
	for modo in 2:
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/impostor_assar.gdshader")
		m.set_shader_parameter(&"textura", tex)
		m.set_shader_parameter(&"tint", jogo.get_shader_parameter(&"tint"))
		var tile: Variant = jogo.get_shader_parameter(&"uv_tile")
		m.set_shader_parameter(&"uv_tile", tile if tile != null else Vector2.ONE)
		var corte: Variant = jogo.get_shader_parameter(&"alpha_cutoff")
		m.set_shader_parameter(&"corte", float(corte) if corte != null else 0.0)
		m.set_shader_parameter(&"fade_perfil", 1.0 if nome == "vegetacao" else 0.0)
		m.set_shader_parameter(&"ao_vertice", 0.7 if folha else 1.0)
		m.set_shader_parameter(&"modo", modo)
		saida.append(m)
	return saida
