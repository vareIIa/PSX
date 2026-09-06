## Suite de assercoes do contrato PSX. Nivel 2 de validacao.
##
##     godot --headless --path game --script res://tests/run_tests.gd
##
## Sai com codigo 1 na primeira falha acumulada, para servir de portao em CI.
## Testar configuracao de projeto parece burocracia ate alguem trocar o
## renderizador sem querer e o look inteiro mudar sem ninguem notar por tres dias.
extends SceneTree

const FOG_DIR := "res://resources/fog/"
const MAT_DIR := "res://resources/materials/"
const TEX_DIR := "res://assets/textures/"

# ART-BIBLE secoes 2, 4 e 6
const RES_INTERNA := Vector2i(480, 270)
const MAX_QUAD_M := 2.0
const MAX_TEXTURA_PX := 256

var _falhas: PackedStringArray = []
var _total: int = 0


func _initialize() -> void:
	print("\n=== contrato PSX ===\n")

	_config_do_projeto()
	_presets_de_nevoa()
	_shaders()
	_materiais()
	_texturas()
	_subdivisao_de_malha()

	print("")
	if _falhas.is_empty():
		print("OK — %d assercoes" % _total)
		quit(0)
		return

	print("FALHOU — %d de %d assercoes" % [_falhas.size(), _total])
	for f: String in _falhas:
		print("  x %s" % f)
	quit(1)


func _check(cond: bool, msg: String) -> void:
	_total += 1
	if not cond:
		_falhas.append(msg)


func _secao(nome: String) -> void:
	print("-- %s" % nome)


# --- testes -----------------------------------------------------------------

func _config_do_projeto() -> void:
	_secao("configuracao do projeto")

	var metodo := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	_check(metodo == "gl_compatibility",
		"renderizador e '%s', deveria ser gl_compatibility (ART-BIBLE 7)" % metodo)

	var w := int(ProjectSettings.get_setting("display/window/size/viewport_width", 0))
	var h := int(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
	_check(Vector2i(w, h) == RES_INTERNA,
		"resolucao interna %dx%d, deveria ser %dx%d (ART-BIBLE 2)"
			% [w, h, RES_INTERNA.x, RES_INTERNA.y])

	var filtro := int(ProjectSettings.get_setting(
		"rendering/textures/canvas_textures/default_texture_filter", -1))
	_check(filtro == 0,
		"filtro de textura de canvas e %d, deveria ser 0 (nearest). Linear borra o dither" % filtro)

	for chave: String in [
		"rendering/anti_aliasing/quality/msaa_3d",
		"rendering/anti_aliasing/quality/screen_space_aa",
	]:
		_check(int(ProjectSettings.get_setting(chave, -1)) == 0,
			"%s deveria ser 0: serrilhado faz parte do alvo" % chave)


func _presets_de_nevoa() -> void:
	_secao("presets de nevoa")

	var ids: Array = load("res://src/systems/settings.gd").FOG_PRESET_IDS
	_check(not ids.is_empty(), "Settings.FOG_PRESET_IDS esta vazio")

	# Varre o disco em vez da lista do menu: preset de override, como o de
	# interior, tambem tem que obedecer o contrato mesmo sem aparecer nas opcoes.
	var dir := DirAccess.open(FOG_DIR)
	if dir == null:
		_check(false, "pasta de presets ausente: %s" % FOG_DIR)
		return
	var no_disco := PackedStringArray()
	for arquivo: String in dir.get_files():
		if arquivo.ends_with(".tres"):
			no_disco.append(arquivo.trim_prefix("fog_").trim_suffix(".tres"))

	for id: StringName in ids:
		_check(String(id) in no_disco, "preset do menu sem arquivo: fog_%s.tres" % id)

	for nome: String in no_disco:
		var path := "%sfog_%s.tres" % [FOG_DIR, nome]
		var id := StringName(nome)
		var preset: FogPreset = load(path)
		_check(preset != null, "%s nao carregou como FogPreset" % path)
		if preset == null:
			continue

		_check(preset.id == id, "%s tem id '%s', esperado '%s'" % [path, preset.id, id])

		for erro: String in preset.validate():
			_check(false, erro)


func _shaders() -> void:
	_secao("shaders")
	for path: String in ["res://shaders/psx_surface.gdshader", "res://shaders/post_psx.gdshader"]:
		_check(ResourceLoader.exists(path), "shader ausente: %s" % path)

	var fonte := FileAccess.get_file_as_string("res://shaders/psx_surface.gdshader")
	_check(fonte.contains("vertex_lighting"),
		"psx_surface sem render_mode vertex_lighting: o Godot cai em per-pixel e o look moderniza")
	_check(fonte.contains("POSITION = clip"),
		"psx_surface nao escreve POSITION: sem isso nao ha vertex snap")

	var pos := FileAccess.get_file_as_string("res://shaders/post_psx.gdshader")
	_check(pos.contains("filter_nearest"),
		"post_psx sem filter_nearest no screen_tex: o dither borra no upscale")


func _materiais() -> void:
	_secao("materiais")
	var dir := DirAccess.open(MAT_DIR)
	_check(dir != null, "pasta de materiais ausente: %s" % MAT_DIR)
	if dir == null:
		return

	var achou := 0
	for arquivo: String in dir.get_files():
		if not arquivo.ends_with(".tres"):
			continue
		achou += 1
		var mat: ShaderMaterial = load(MAT_DIR + arquivo)
		_check(mat != null, "%s nao carregou como ShaderMaterial" % arquivo)
		if mat == null:
			continue
		_check(mat.shader != null and mat.shader.resource_path.contains("psx_surface"),
			"%s nao usa psx_surface.gdshader" % arquivo)
		_check(mat.get_shader_parameter(&"albedo_tex") != null,
			"%s sem textura em albedo_tex" % arquivo)

	_check(achou > 0, "nenhum material encontrado em %s" % MAT_DIR)


func _texturas() -> void:
	_secao("texturas")
	var dir := DirAccess.open(TEX_DIR)
	if dir == null:
		_check(false, "pasta de texturas ausente: %s" % TEX_DIR)
		return

	for arquivo: String in dir.get_files():
		if not arquivo.ends_with(".png"):
			continue

		var tex: Texture2D = load(TEX_DIR + arquivo)
		if tex == null:
			_check(false, "%s nao carregou" % arquivo)
			continue

		_check(tex.get_width() <= MAX_TEXTURA_PX and tex.get_height() <= MAX_TEXTURA_PX,
			"%s tem %dx%d, teto e %d px (ART-BIBLE 6)"
				% [arquivo, tex.get_width(), tex.get_height(), MAX_TEXTURA_PX])

		# O preset de importacao e onde o contrato de textura mora de verdade.
		var cfg := ConfigFile.new()
		if cfg.load(TEX_DIR + arquivo + ".import") != OK:
			_check(false, "%s sem arquivo .import" % arquivo)
			continue
		_check(not bool(cfg.get_value("params", "mipmaps/generate", true)),
			"%s com mipmap: em distancia a textura vira borrao e o dither some" % arquivo)
		_check(int(cfg.get_value("params", "compress/mode", -1)) == 0,
			"%s nao esta em lossless: a compressao destroi a paleta" % arquivo)
		_check(int(cfg.get_value("params", "detect_3d/compress_to", -1)) == 0,
			"%s com detect_3d ligado: o Godot recomprime sozinho ao ver uso em 3D" % arquivo)


func _subdivisao_de_malha() -> void:
	_secao("subdivisao de malha")

	# A UV afim distorce proporcionalmente ao tamanho do poligono. PSXMesh existe
	# para garantir o teto de 2 m por construcao; este teste prova que garante.
	var mesh := PSXMesh.plane(Vector2(12.0, 7.0))
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	_check(not idx.is_empty(), "PSXMesh.plane devolveu malha sem indices")

	var maior := 0.0
	for i in range(0, idx.size(), 3):
		for par: Array in [[0, 1], [1, 2], [2, 0]]:
			var a := verts[idx[i + par[0]]]
			var b := verts[idx[i + par[1]]]
			maior = maxf(maior, a.distance_to(b))

	# A diagonal de um quad de 2 m mede 2*sqrt(2) = 2.83
	var teto := MAX_QUAD_M * sqrt(2.0) + 0.01
	_check(maior <= teto,
		"maior aresta de PSXMesh.plane e %.2f m, teto e %.2f m (ART-BIBLE 4)" % [maior, teto])

	_check(PSXMesh.triangle_count(mesh) == 6 * 4 * 2,
		"contagem de triangulos inesperada: %d" % PSXMesh.triangle_count(mesh))
