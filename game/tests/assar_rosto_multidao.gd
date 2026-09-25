## Assa o rosto da `MultidaoEncapuzada` a partir do `RostoEnfaixado` de verdade.
##
##     $G --path game res://scenes/test/assar_rosto_multidao.tscn
##
## A multidao sao 440 figuras num MultiMesh: nenhuma pode ter a cabeca de faixas
## (malha, olho, dentes, pontas). O que ela ganha e esta foto: a cabeca enfaixada
## da variante 0 (olho aberto em +x), de frente, em projecao ortografica de
## RETRATO metros de lado, so com luz ambiente branca — sai o albedo com a
## oclusao das frestas, sem a luz de uma direcao (quem ilumina e a cena). O
## shader da multidao espelha a foto por figura.
##
## Saida: assets/monstros/romeiro/rosto_multidao.png (RGBA, alfa fora da cabeca).
extends Node3D

## Lado do quadrado fotografado, em metros, centrado no centro da cabeca. Igual
## a `MultidaoEncapuzada.ROSTO_LADO`.
const RETRATO := 0.26
const CAMADA := 1 << 19
const LADO_PX := 1024
const SAIDA := "res://assets/monstros/romeiro/rosto_multidao.png"


func _ready() -> void:
	var mundo := WorldEnvironment.new()
	var amb := Environment.new()
	amb.background_mode = Environment.BG_COLOR
	amb.background_color = Color(0, 0, 0, 0)
	amb.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	amb.ambient_light_color = Color.WHITE
	amb.ambient_light_energy = 1.0
	amb.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	amb.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	amb.ssao_enabled = true
	amb.ssao_radius = 0.6
	amb.ssao_intensity = 1.5
	mundo.environment = amb
	add_child(mundo)
	# Um SubViewport quadrado: a janela nao obedece --resolution quadrada.
	var vp := SubViewport.new()
	vp.size = Vector2i(LADO_PX, LADO_PX)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var c := Corpo.new()
	c.name = "Romeiro"
	add_child(c)
	var ombro := AberturaEstrada.OMBRO_ENCAPUZADO
	c.montar(AberturaEstrada._aparencia_de_encapuzado(0, 1.82, ombro, false))
	MonstroDaEstrada.vestir(c, 0, ombro / 0.42, false)
	for _i in 30:
		c.animar(0.0, 0.05)
	var rosto := c.get_meta(&"rosto") as RostoEnfaixado
	if rosto == null:
		push_error("[assar_rosto_multidao] sem rosto")
		get_tree().quit(1)
		return
	rosto.por_olhos(0.0, 1.0)
	for n: Node in rosto.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.layers = CAMADA if mi.name != "PontasSoltas" else 1
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = RETRATO
	cam.cull_mask = CAMADA
	cam.near = 0.01
	cam.environment = amb
	vp.add_child(cam)
	for _i in 4:
		await get_tree().process_frame
	var xf := rosto.global_transform
	cam.global_position = xf.origin + xf.basis.orthonormalized() * Vector3(0.0, 0.0, -0.5)
	cam.look_at(xf.origin, xf.basis.orthonormalized().y)
	cam.make_current()
	for _i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(ProjectSettings.globalize_path(SAIDA))
	print("[assar_rosto_multidao] %s %dx%d" % [SAIDA, img.get_width(), img.get_height()])
	get_tree().quit()
