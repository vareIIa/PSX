## Sala de teste da Fase 1. Reproduz o corredor de concreto da referencia.
##
## O criterio de aceite da fase esta aqui: se a captura desta cena colocada ao lado
## de PRINTS/1_uPwt5ZFRdmAcPbF_OlEXLA.webp nao bater em dither, queda de luz e
## distorcao de textura no chao, o contrato grafico nao fechou e nada mais comeca.
##
## A geometria e construida por codigo de proposito. PSXMesh garante a subdivisao
## de 2 m exigida pela UV afim por construcao, em vez de depender de alguem lembrar
## de subdividir na mao. O mesmo construtor vai servir o kit modular da Fase 3.
extends Node3D

const MAT_DIR := "res://resources/materials/"

# Corredor no eixo -Z. Medidas em metros, na grade de 2 m do kit modular.
const LARGURA := 4.0
const ALTURA := 3.0
const COMPRIMENTO := 16.0

## Luminaria unica, quente, como na referencia. ART-BIBLE secao 7 limita a 4 por
## chunk; aqui uma so ja da a queda de luz caracteristica.
const LUZ_COR := Color("ffd9a0")
const LUZ_ENERGIA := 2.1
const LUZ_ALCANCE := 15.0

@onready var _geometria: Node3D = $Geometria
@onready var _camera: Camera3D = $Camera3D

var _mats: Dictionary[StringName, ShaderMaterial] = {}
var _tris: int = 0


func _ready() -> void:
	_carregar_materiais()
	_aplicar_ab_de_debug()
	_construir()
	print("[sala_teste] %d triangulos" % _tris)


func _carregar_materiais() -> void:
	for nome: StringName in [&"concreto", &"piso", &"teto", &"tabua", &"porta", &"metal"]:
		var path := "%smat_%s.tres" % [MAT_DIR, nome]
		if not ResourceLoader.exists(path):
			push_error("sala_teste: material ausente em %s" % path)
			continue
		_mats[nome] = load(path) as ShaderMaterial


## Desliga snap e UV afim para comparacao A/B em captura automatizada.
## Existe para transformar "acho que o shader esta ativo" em diferenca medida.
##     godot --path game -- --psx-off --shot=liso.png
func _aplicar_ab_de_debug() -> void:
	if not OS.get_cmdline_user_args().has("--psx-off"):
		return
	for mat: ShaderMaterial in _mats.values():
		mat.set_shader_parameter(&"use_snap", false)
		mat.set_shader_parameter(&"use_affine", false)
	print("[sala_teste] A/B: snap e UV afim desligados")


func _construir() -> void:
	var meio_z := -COMPRIMENTO * 0.5

	# Piso e teto
	_superficie("Piso", Vector2(LARGURA, COMPRIMENTO), &"piso",
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.0, 0.0, meio_z)))
	_superficie("Teto", Vector2(LARGURA, COMPRIMENTO), &"teto",
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, ALTURA, meio_z)))

	# Paredes laterais
	_superficie("ParedeEsq", Vector2(COMPRIMENTO, ALTURA), &"concreto",
		Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-LARGURA * 0.5, ALTURA * 0.5, meio_z)))
	_superficie("ParedeDir", Vector2(COMPRIMENTO, ALTURA), &"concreto",
		Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(LARGURA * 0.5, ALTURA * 0.5, meio_z)))

	# Fundo do corredor
	_superficie("Fundo", Vector2(LARGURA, ALTURA), &"concreto",
		Transform3D(Basis(), Vector3(0.0, ALTURA * 0.5, -COMPRIMENTO)))

	# Vao na parede esquerda, escurecido, com as tabuas em X por cima.
	# E o elemento que da leitura de profundidade na referencia.
	_vao_tapado(Vector3(-LARGURA * 0.5 + 0.06, 1.05, -6.0))

	# Porta fechada na parede direita
	_superficie("Porta", Vector2(0.9, 2.1), &"porta",
		Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(LARGURA * 0.5 - 0.05, 1.05, -6.8)))

	_luminaria(Vector3(0.0, ALTURA - 0.12, -4.0))
	_luz_ambiente_fraca(Vector3(0.0, ALTURA - 0.7, 1.2))
	_colisao_corredor(meio_z)

	# Dentro do corredor. Fora dele o enquadramento pega o fundo do ambiente pelas
	# quinas e aparece uma moldura da cor do ceu, que denuncia o cenario aberto.
	# Deslocada do eixo, como na referencia: composicao simetrica le como demo.
	_camera.transform = Transform3D(Basis(), Vector3(0.9, 1.9, -1.1))
	_camera.look_at(Vector3(-0.55, 0.85, -9.0), Vector3.UP)
	_camera.fov = 64.0
	_camera.near = 0.08
	_camera.far = 120.0


## Cria um plano subdividido com o material dado.
func _superficie(nome: String, tamanho: Vector2, mat: StringName, xform: Transform3D) -> void:
	var mesh := PSXMesh.plane(tamanho)
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = mesh
	mi.material_override = _mats.get(mat)
	mi.transform = xform
	# ART-BIBLE secao 7 — o PS1 nao tinha sombra dinamica
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_geometria.add_child(mi)
	_tris += PSXMesh.triangle_count(mesh)


func _vao_tapado(pos: Vector3) -> void:
	# Fundo preto do vao. Sem luz atras: o vazio e o que assusta.
	var fundo := MeshInstance3D.new()
	fundo.name = "VaoFundo"
	var mesh := PSXMesh.plane(Vector2(1.0, 2.1))
	fundo.mesh = mesh
	var preto := ShaderMaterial.new()
	preto.shader = load("res://shaders/psx_surface.gdshader")
	preto.set_shader_parameter(&"tint", Color(0.02, 0.02, 0.025, 1.0))
	preto.set_shader_parameter(&"albedo_tex", load("res://assets/textures/concreto_parede.png"))
	fundo.material_override = preto
	fundo.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), pos)
	fundo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_geometria.add_child(fundo)
	_tris += PSXMesh.triangle_count(mesh)

	# Duas tabuas cruzadas em X sobre o vao
	for i in 2:
		var ang := deg_to_rad(28.0 if i == 0 else -28.0)
		var tabua := MeshInstance3D.new()
		tabua.name = "Tabua%d" % i
		var tm := PSXMesh.box(Vector3(2.3, 0.16, 0.05), 0.8)
		tabua.mesh = tm
		tabua.material_override = _mats.get(&"tabua")
		tabua.transform = Transform3D(
			Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.BACK, ang),
			pos + Vector3(0.09, -0.15 + i * 0.3, 0.0)
		)
		tabua.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_geometria.add_child(tabua)
		_tris += PSXMesh.triangle_count(tm)


func _luminaria(pos: Vector3) -> void:
	var corpo := MeshInstance3D.new()
	corpo.name = "LuminariaCorpo"
	var mesh := PSXMesh.box(Vector3(0.26, 0.14, 0.34), 1.0)
	corpo.mesh = mesh
	corpo.material_override = _mats.get(&"metal")
	corpo.position = pos
	corpo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_geometria.add_child(corpo)
	_tris += PSXMesh.triangle_count(mesh)

	var luz := OmniLight3D.new()
	luz.name = "Luminaria"
	# Longe do plano do teto, senao os vertices logo acima estouram.
	luz.position = pos - Vector3(0.0, 0.42, 0.0)
	luz.light_color = LUZ_COR
	luz.light_energy = LUZ_ENERGIA
	luz.omni_range = LUZ_ALCANCE
	luz.omni_attenuation = 0.95
	luz.shadow_enabled = false
	$Luzes.add_child(luz)


## Preenchimento fraco atras da camera. Nao tem corpo visivel: simula luz vindo
## de fora do enquadramento, que e o que impede o primeiro plano de virar breu.
func _luz_ambiente_fraca(pos: Vector3) -> void:
	var luz := OmniLight3D.new()
	luz.name = "Preenchimento"
	luz.position = pos
	luz.light_color = Color("c4b49a")
	luz.light_energy = 0.75
	luz.omni_range = 10.0
	luz.omni_attenuation = 1.1
	luz.shadow_enabled = false
	$Luzes.add_child(luz)


func _colisao_corredor(meio_z: float) -> void:
	var corpo := StaticBody3D.new()
	corpo.name = "Colisao"
	var caixas: Array[Array] = [
		[Vector3(LARGURA, 0.2, COMPRIMENTO), Vector3(0.0, -0.1, meio_z)],
		[Vector3(LARGURA, 0.2, COMPRIMENTO), Vector3(0.0, ALTURA + 0.1, meio_z)],
		[Vector3(0.2, ALTURA, COMPRIMENTO), Vector3(-LARGURA * 0.5 - 0.1, ALTURA * 0.5, meio_z)],
		[Vector3(0.2, ALTURA, COMPRIMENTO), Vector3(LARGURA * 0.5 + 0.1, ALTURA * 0.5, meio_z)],
		[Vector3(LARGURA, ALTURA, 0.2), Vector3(0.0, ALTURA * 0.5, -COMPRIMENTO - 0.1)],
	]
	for caixa: Array in caixas:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = caixa[0]
		shape.shape = box
		shape.position = caixa[1]
		corpo.add_child(shape)
	add_child(corpo)
