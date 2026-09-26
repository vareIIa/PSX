## Assa o rosto da `MultidaoEncapuzada` a partir da `CabecaDoPadre` de verdade:
## a criatura do padre principal, a cabeca "real" que todos os encapuzados de
## fundo ganharam.
##
##     $G --path game res://scenes/test/assar_rosto_multidao.tscn
##
## A multidao sao centenas de figuras num MultiMesh: nenhuma pode ter a cabeca
## de verdade (malha 4K, boca com morph, dois globos de olho). O que ela ganha e
## esta foto: a cabeca de frente, em projecao ortografica de RETRATO metros de
## lado, em quatro variacoes (`VARIACOES`) num atlas 2x2 de LADO_PX por foto.
## Cada variacao sai em duas passadas:
##
##   - a cor, so com luz ambiente branca: o albedo com a oclusao da propria
##     malha e das frestas, sem a luz de uma direcao (quem ilumina e a cena);
##   - a normal da tela (x para a direita da foto, y para cima, z para a lente),
##     por um material que refaz a queixada e os amassados do shader da pele e
##     escreve a normal como cor. Com ela a calota da multidao acende no farol
##     e no fogo como se fosse a malha.
##
## O shader da multidao espelha a foto por figura (e o x da normal junto).
##
## Saidas: assets/monstros/padre/multidao_rosto.png (RGBA, alfa fora da cabeca)
## e multidao_rosto_n.png (RG a normal, B o z, A a cobertura).
extends Node3D

## Lado do quadrado fotografado, em metros, e a altura do centro dele a partir
## da origem da cabeca: do alto do cranio (+0,116) ao queixo com a queixada
## caida (-0,14). Iguais a `MultidaoEncapuzada.ROSTO_LADO` e a distancia do
## `ROSTO_CENTRO` ao centro da cabeca dela.
const RETRATO := 0.28
const CENTRO_Y := -0.015
const CAMADA := 1 << 19
const LADO_PX := 1024
const SAIDA := "res://assets/monstros/padre/multidao_rosto.png"
const SAIDA_N := "res://assets/monstros/padre/multidao_rosto_n.png"
## As variacoes, na ordem do atlas (esquerda para a direita, de cima para
## baixo): [sorriso (a queixada), sangue da testa, dano da cara].
##   0 a boca no repouso (ja aberta, torta)
##   1 a queixada caida de todo
##   2 a testa aberta, o sangue escorrido ate o queixo
##   3 o nariz cedido e os talhos da primeira cabecada
const VARIACOES := [[0.0, 0.0, 0.0], [1.0, 0.0, 0.0], [0.35, 1.0, 0.0], [0.6, 0.7, 1.0]]

## A normal da tela como cor. A queixada e os amassados vem do shader da pele
## (`CabecaDoPadre.QUEIXADA` e `AMASSO`); a boca de dentro abre por morph (o
## motor aplica antes do vertex) e fica com `queixada` 0. O pos-processo leva a
## cor linear para sRGB: escrevendo o inverso, o PNG guarda n * 0,5 + 0,5.
const NORMAL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

#QUEIXADA
#AMASSO
uniform float queixada = 1.0;

void vertex() {
	float a = -abre * giro_max * UV.x * queixada;
	VERTEX = pivo + girar_x(VERTEX - pivo, a);
	NORMAL = girar_x(NORMAL, a);
	float e;
	VERTEX = amassar(VERTEX, e);
}

vec3 para_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void fragment() {
	ALBEDO = para_linear(normalize(NORMAL) * 0.5 + 0.5);
}
"""

var _vp: SubViewport
var _cab: CabecaDoPadre
var _shader_n: Shader


func _ready() -> void:
	var amb := Environment.new()
	amb.background_mode = Environment.BG_COLOR
	amb.background_color = Color(0, 0, 0, 0)
	amb.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	amb.ambient_light_color = Color.WHITE
	amb.ambient_light_energy = 1.0
	amb.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	amb.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	amb.ssao_enabled = true
	amb.ssao_radius = 0.05
	amb.ssao_intensity = 1.2
	var mundo := WorldEnvironment.new()
	mundo.environment = amb
	add_child(mundo)
	# Um SubViewport quadrado: a janela nao obedece --resolution quadrada.
	_vp = SubViewport.new()
	_vp.size = Vector2i(LADO_PX, LADO_PX)
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	if not CabecaDoPadre._carregar():
		push_error("[assar_rosto_multidao] a cabeca nao carrega")
		get_tree().quit(1)
		return
	_cab = CabecaDoPadre.new()
	_cab.name = "Cabeca"
	add_child(_cab)
	_cab._montar()
	for n: Node in _cab.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		# O ponto de longe do olho nao e da cara (a multidao tem o dela).
		mi.layers = 1 if String(mi.name).begins_with("Longe") else CAMADA
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = RETRATO
	cam.cull_mask = CAMADA
	cam.near = 0.01
	cam.environment = amb
	_vp.add_child(cam)
	# De frente: a cara olha -Z, a lente fica em -Z olhando para +Z.
	var centro := _cab.global_position + Vector3(0.0, CENTRO_Y, 0.0)
	cam.global_position = centro + Vector3(0.0, 0.0, -0.5)
	cam.look_at(centro, Vector3.UP)
	cam.make_current()
	_shader_n = Shader.new()
	_shader_n.code = NORMAL_SHADER.replace("#QUEIXADA", CabecaDoPadre.QUEIXADA) \
		.replace("#AMASSO", CabecaDoPadre.AMASSO)
	_assar()


func _assar() -> void:
	var cor := Image.create(LADO_PX * 2, LADO_PX * 2, false, Image.FORMAT_RGBA8)
	var nor := Image.create(LADO_PX * 2, LADO_PX * 2, false, Image.FORMAT_RGBA8)
	for i in VARIACOES.size():
		var v: Array = VARIACOES[i]
		_cab.por_sorriso(float(v[0]))
		_cab.por_sangue(float(v[1]))
		_cab.por_dano(float(v[2]))
		var onde := Vector2i((i % 2) * LADO_PX, floori(i / 2.0) * LADO_PX)
		var img := await _foto()
		cor.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), onde)
		var antes := _vestir_normal()
		img = await _foto()
		nor.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), onde)
		for mi: MeshInstance3D in antes:
			mi.material_override = antes[mi]
		# A conferencia: a normal no meio da testa tem de olhar para a lente.
		var testa := img.get_pixel(int(LADO_PX * 0.5), int(LADO_PX * 0.3))
		print("[assar_rosto_multidao] variacao %d %s: normal na testa %.2f %.2f %.2f a %.2f" % [
			i, str(v), testa.r * 2.0 - 1.0, testa.g * 2.0 - 1.0, testa.b * 2.0 - 1.0, testa.a])
	cor.save_png(ProjectSettings.globalize_path(SAIDA))
	nor.save_png(ProjectSettings.globalize_path(SAIDA_N))
	print("[assar_rosto_multidao] %s e %s %dx%d" % [SAIDA, SAIDA_N, cor.get_width(),
		cor.get_height()])
	get_tree().quit()


## Troca o material de cada malha da cabeca pelo da normal (com a mesma
## queixada e os mesmos amassados). Devolve {malha: material de antes}.
func _vestir_normal() -> Dictionary:
	var antes := {}
	var pele := _cab.get_node("Pele") as MeshInstance3D
	var mp := pele.material_override as ShaderMaterial
	for n: Node in _cab.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.layers != CAMADA:
			continue
		var m := ShaderMaterial.new()
		m.shader = _shader_n
		for p: StringName in [&"abre", &"pivo", &"giro_max", &"amassos", &"fundos", &"n_amassos"]:
			m.set_shader_parameter(p, mp.get_shader_parameter(p))
		# So a pele gira pela queixada (UV.x e o peso dela na malha da pele).
		m.set_shader_parameter(&"queixada", 1.0 if mi == pele else 0.0)
		if String(mi.name).begins_with("Olho"):
			m.set_shader_parameter(&"n_amassos", 0)
		antes[mi] = mi.material_override
		mi.material_override = m
	return antes


func _foto() -> Image:
	for _i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
