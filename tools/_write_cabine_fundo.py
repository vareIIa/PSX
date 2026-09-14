from pathlib import Path

GD = r"""## Fundo 3D da criacao: cabine FP (volante + pernas + painel) atras da carteira.
##
## Carteira instancia esta PackedScene num SubViewport full-tela. Nao tem HUD,
## LOCAL, HORA nem UI — so o look de piloto sentado no Marea.
##
## Reusa CarroCabine + Carroceria.MAREA com com_vidros_frente=false (mesmo
## caminho da Estrada Velha). Nao inventa segundo sistema de cabine.
class_name CabineFundoCriacao
extends Node3D

const TINTA := Color(0.90, 0.88, 0.80)
const SEMENTE := 4410
const MODELO := Carroceria.Modelo.MAREA
const FOV := 68.0
## Pitch leve para baixo: enquadra volante, painel e pernas (nao o horizonte).
const PITCH_OLHO := -0.38

## Micro-balanco da cabine (suspensao parada). Amplitude em radianos.
const ROCK_ARFAR := 0.008
const ROCK_ROLAR := 0.012
const ROCK_VEL := 0.55

var cabine: CarroCabine
var camera: Camera3D

var _medidas: Dictionary = {}
var _pivot: Node3D
var _t: float = 0.0


func _ready() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Balanco"
	add_child(_pivot)

	_medidas = Carroceria.montar(MODELO, TINTA, SEMENTE, false)
	_montar_lataria()
	_montar_cabine()
	_montar_pernas()
	_montar_luzes()
	_montar_ambiente()
	_montar_camera()


func _process(delta: float) -> void:
	_t += delta
	if _pivot == null:
		return
	# Cabine parada: so um rock miudo, sem chacoalho de estrada.
	_pivot.rotation.x = sin(_t * ROCK_VEL) * ROCK_ARFAR
	_pivot.rotation.z = cos(_t * ROCK_VEL * 0.83) * ROCK_ROLAR


func _montar_lataria() -> void:
	var corpo := MeshInstance3D.new()
	corpo.name = "Lataria"
	corpo.mesh = _medidas["corpo"] as ArrayMesh
	corpo.material_override = load(Carroceria.MATERIAL) as ShaderMaterial
	corpo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(corpo)

	var luzes := MeshInstance3D.new()
	luzes.name = "Luzes"
	luzes.mesh = _medidas["luzes"] as ArrayMesh
	luzes.material_override = load(Carroceria.MATERIAL_LUZ) as ShaderMaterial
	luzes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(luzes)


func _montar_cabine() -> void:
	cabine = CarroCabine.new()
	cabine.name = "Cabine"
	_pivot.add_child(cabine)
	cabine.montar(_medidas)


func _montar_pernas() -> void:
	## Pernas do piloto em caixas PSX: so o que a camera FP enxerga (coxa/joelho/
	## canela/pe), sentadas no banco do motorista. Sem Corpo inteiro — o retrato
	## da carteira ja e o personagem; aqui so ancora a imersao do assento.
	var raiz := Node3D.new()
	raiz.name = "PernasPiloto"
	_pivot.add_child(raiz)

	var olho := cabine.olho()
	var piso := olho.y - CarroCabine.OLHO_ALTURA
	var x := CarroCabine.LADO_MOTORISTA
	# Banco: um pouco atras do olho, sob o volante.
	var z_banco := olho.z + 0.22
	var y_coxa := piso + 0.28

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.16, 0.14)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mat_pe := StandardMaterial3D.new()
	mat_pe.albedo_color = Color(0.12, 0.10, 0.09)
	mat_pe.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for lado: float in [-1.0, 1.0]:
		var lx := x + lado * 0.11
		_caixa(raiz, "Coxa%s" % ("E" if lado < 0.0 else "D"),
			Vector3(lx, y_coxa, z_banco - 0.02),
			Vector3(0.12, 0.10, 0.38), mat)
		_caixa(raiz, "Joelho%s" % ("E" if lado < 0.0 else "D"),
			Vector3(lx, y_coxa - 0.02, z_banco - 0.22),
			Vector3(0.11, 0.11, 0.11), mat)
		_caixa(raiz, "Canela%s" % ("E" if lado < 0.0 else "D"),
			Vector3(lx, piso + 0.14, z_banco - 0.34),
			Vector3(0.09, 0.28, 0.09), mat)
		_caixa(raiz, "Pe%s" % ("E" if lado < 0.0 else "D"),
			Vector3(lx, piso + 0.03, z_banco - 0.48),
			Vector3(0.10, 0.06, 0.22), mat_pe)


func _caixa(pai: Node3D, nome: String, pos: Vector3, tam: Vector3,
		mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.position = pos
	var box := BoxMesh.new()
	box.size = tam
	mi.mesh = box
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)


func _montar_luzes() -> void:
	var fill := OmniLight3D.new()
	fill.name = "LuzCabine"
	fill.position = Vector3(-0.2, 1.15, -0.15)
	fill.omni_range = 2.6
	fill.light_energy = 0.72
	fill.light_color = Color(1.0, 0.92, 0.82)
	fill.shadow_enabled = false
	_pivot.add_child(fill)

	var dash := OmniLight3D.new()
	dash.name = "LuzPainel"
	dash.position = Vector3(CarroCabine.LADO_MOTORISTA, 1.05, -0.42)
	dash.omni_range = 1.4
	dash.light_energy = 0.35
	dash.light_color = Color(0.95, 0.75, 0.45)
	dash.shadow_enabled = false
	_pivot.add_child(dash)

	var sol := DirectionalLight3D.new()
	sol.name = "SolFraco"
	sol.rotation_degrees = Vector3(-42.0, 28.0, 0.0)
	sol.light_energy = 0.45
	sol.light_color = Color(0.85, 0.90, 1.0)
	sol.shadow_enabled = false
	add_child(sol)


func _montar_ambiente() -> void:
	var we := WorldEnvironment.new()
	we.name = "Ambiente"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	# Cinza-azulado frio do lado de fora do para-brisa (sem estrada).
	env.background_color = Color(0.22, 0.26, 0.28)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.34, 0.32)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	add_child(we)


func _montar_camera() -> void:
	camera = Camera3D.new()
	camera.name = "CameraFP"
	camera.current = true
	camera.fov = FOV
	camera.near = 0.06
	camera.far = 40.0
	# Trava no olho da cabine; pitch fixo (sem mouse / sem HUD).
	camera.position = cabine.olho()
	camera.rotation = Vector3(PITCH_OLHO, 0.0, 0.0)
	_pivot.add_child(camera)
"""

TSCN = """[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/cabine_fundo_criacao.gd" id="1_cabine"]

[node name="CabineFundoCriacao" type="Node3D"]
script = ExtResource("1_cabine")
"""

Path("game/src/ui/cabine_fundo_criacao.gd").write_text(GD, encoding="utf-8")
Path("game/scenes/player/cabine_fundo_criacao.tscn").write_text(TSCN, encoding="utf-8")
print("ok", Path("game/src/ui/cabine_fundo_criacao.gd").stat().st_size)
