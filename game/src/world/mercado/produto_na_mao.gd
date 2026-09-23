## O produto que o jogador tirou da prateleira e ainda nao pagou.
##
## Fica preso a camera, embaixo e a direita, como a mao de quem carrega uma
## lata pelo corredor. [Q] traz para perto do rosto e gira devagar: e o "girar
## e ler" do plano (4.4) — marca, preco e validade, que e o que um freguês de
## verdade confere antes de por na cesta.
##
## O estado mora no `EstoqueMercado` (e no save); este no so desenha. Por isso
## ele se reconstroi sozinho quando o que esta salvo e o que ele mostra
## divergem — carregar um jogo com a lata na mao traz a lata de volta a mao.
class_name ProdutoNaMao
extends Node3D

## Onde a mao fica, em coordenada da camera.
const REPOUSO := Vector3(0.21, -0.19, -0.46)
const LENDO := Vector3(0.0, -0.035, -0.33)
## Uma volta inteira a cada tantos segundos, lendo.
const VOLTA := 5.0

var sku: StringName = &""
var _malha: MultiMeshInstance3D
var _texto: Label
var _camada: CanvasLayer
var _lendo := false
var _giro := 0.0
var _chegada := 1.0
var _versao := -1


## A mao da camera atual, criada na primeira vez.
static func da_camera(arvore: SceneTree) -> ProdutoNaMao:
	var cam := arvore.root.get_viewport().get_camera_3d()
	if cam == null:
		return null
	var ja := cam.get_node_or_null(^"ProdutoNaMao") as ProdutoNaMao
	if ja != null:
		return ja
	var m := ProdutoNaMao.new()
	m.name = "ProdutoNaMao"
	cam.add_child(m)
	return m


func _ready() -> void:
	_malha = MultiMeshInstance3D.new()
	_malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Luz da rua e luz da loja: a lata na mao atravessa a porta junto.
	_malha.layers = 1 | InteriorNoMundo.CAMADA
	var mat := PrateleiraViva.material_produto().duplicate() as ShaderMaterial
	# Sem snap no que esta grudado na camera (skill psx-render): a um palmo do
	# olho o tremor de vertice vira estroboscopio, nao charme.
	mat.set_shader_parameter(&"use_snap", false)
	_malha.material_override = mat
	add_child(_malha)

	_camada = CanvasLayer.new()
	_camada.layer = 5
	add_child(_camada)
	_texto = Label.new()
	UiEstilo.aplicar(_texto, load(UiEstilo.FONTE_P) as Font)
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_texto.anchor_left = 1.0
	_texto.anchor_right = 1.0
	_texto.anchor_top = 1.0
	_texto.anchor_bottom = 1.0
	_texto.offset_left = -220.0
	_texto.offset_right = -UiEstilo.MARGEM
	_texto.offset_top = -80.0
	_texto.offset_bottom = -34.0
	_texto.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.8))
	_texto.add_theme_constant_override(&"shadow_offset_x", 1)
	_texto.add_theme_constant_override(&"shadow_offset_y", 1)
	_camada.add_child(_texto)
	_sincronizar()


## Mostra `id` chegando de `de` (posicao global), ou na mao direto.
func segurar(id: StringName, de: Vector3 = Vector3.INF) -> void:
	sku = id
	_lendo = false
	_montar()
	_chegada = 0.0 if de != Vector3.INF else 1.0
	if de != Vector3.INF:
		_malha.global_position = de
	_versao = EstoqueMercado.versao()


func soltar() -> void:
	sku = &""
	_lendo = false
	_montar()
	_versao = EstoqueMercado.versao()


## Onde a lata esta agora, para a animacao de devolver partir dali.
func ponto() -> Vector3:
	return _malha.global_position if _malha != null else global_position


func _montar() -> void:
	if sku == &"":
		_malha.multimesh = null
		_malha.visible = false
		_texto.text = ""
		return
	var p := CatalogoMercado.produto(sku)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = ProdutoMalhas.malha(int(p["forma"]))
	mm.instance_count = 1
	var md := CatalogoMercado.medida(sku)
	# A malha nasce com a base em y = 0; na mao, o centro e que fica no ponto.
	mm.set_instance_transform(0, Transform3D(Basis.from_scale(md), Vector3(0, -md.y * 0.5, 0)))
	var r := RotulosAtlas.celula(sku)
	mm.set_instance_custom_data(0, Color(r.position.x, r.position.y, r.size.x, r.size.y))
	_malha.multimesh = mm
	_malha.visible = true
	_atualizar_texto()


func _atualizar_texto() -> void:
	if sku == &"":
		_texto.text = ""
		return
	var p := CatalogoMercado.produto(sku)
	var linhas := PackedStringArray([String(p["nome"]),
		CatalogoMercado.reais(int(p["preco"]))])
	if _lendo:
		var val := CatalogoMercado.validade(sku, fposmod(float(hash(sku)) * 0.0001, 1.0))
		if not val.is_empty():
			linhas[1] += "  ·  val. " + val
		if int(p.get("idade", 0)) >= 18:
			linhas.append("Venda proibida a menores de 18 anos")
		linhas.append("[Q] guardar na mão")
	else:
		linhas.append("[Q] ler")
	_texto.text = "\n".join(linhas)


## O save pode trazer (ou levar) a lata sem passar por `segurar`.
func _sincronizar() -> void:
	_versao = EstoqueMercado.versao()
	var mao := EstoqueMercado.na_mao()
	var salvo := StringName(mao.get("sku", ""))
	if salvo != sku:
		sku = salvo
		_montar()


func _unhandled_input(evento: InputEvent) -> void:
	if sku == &"" or not evento.is_action_pressed("examinar"):
		return
	# Com a prancha ou um documento aberto o Q e deles: o jogo esta pausado ou
	# o mouse esta solto.
	if get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	_lendo = not _lendo
	_atualizar_texto()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _versao != EstoqueMercado.versao():
		_sincronizar()
	if sku == &"" or _malha == null:
		return
	var alvo := LENDO if _lendo else REPOUSO
	if _lendo:
		_giro += delta * TAU / VOLTA
	else:
		# Volta a mostrar a frente, sem dar a volta inteira de novo.
		_giro = lerp_angle(_giro, 0.0, minf(1.0, delta * 6.0))
	var giro_mao := Basis(Vector3.UP, _giro - (0.0 if _lendo else 0.35)) \
		* Basis(Vector3.RIGHT, 0.08 if _lendo else 0.18)
	var destino := Transform3D(giro_mao, alvo)
	if _chegada < 1.0:
		# Da prateleira ate a mao em pouco mais de um decimo de segundo,
		# saindo rapido e chegando devagar: e o braco que puxa.
		_chegada = minf(1.0, _chegada + delta / 0.16)
		var t := 1.0 - pow(1.0 - _chegada, 3.0)
		var de := _malha.transform
		_malha.transform = de.interpolate_with(destino, t)
	else:
		_malha.transform = _malha.transform.interpolate_with(destino, minf(1.0, delta * 12.0))
