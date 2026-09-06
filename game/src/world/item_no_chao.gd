## Item largado no mundo, pronto para ser pego.
##
## Aparece como sprite chapado flutuando, nao como modelo. Era assim que o PS1
## fazia por falta de polígono, e funciona melhor do que parece: o objeto lê à
## distância, na névoa, e não some contra o cenário como um modelo pequeno some.
##
## Pegar registra no WorldState. Sem isso o item volta assim que o chunk
## descarrega e recarrega, e o jogador aprende a farmar a mesma esquina.
class_name ItemNoChao
extends Interativo

const ALTURA_FLUTUACAO := 0.06
const VELOCIDADE_FLUTUACAO := 1.7
const TAMANHO := 0.38

@export var item_id: StringName = &""
@export var quantidade: int = 1

## Coordenada do chunk e indice dentro dele. Formam a chave no WorldState.
@export var chunk := Vector2i.ZERO
@export var indice: int = 0

var _sprite: MeshInstance3D
var _base_y: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	super()
	add_to_group(&"item_no_chao")

	if _ja_foi_pego():
		queue_free()
		return

	_montar()
	_base_y = position.y


func chave() -> StringName:
	return StringName("item_%d" % indice)


func _ja_foi_pego() -> bool:
	return bool(WorldState.obter(chunk, chave(), false))


func _montar() -> void:
	var def := Inventario.definicao(item_id)
	if def == null:
		push_warning("ItemNoChao: item desconhecido '%s'" % item_id)
		queue_free()
		return

	rotulo = def.nome

	_sprite = MeshInstance3D.new()
	_sprite.name = "Sprite"
	var quad := QuadMesh.new()
	quad.size = Vector2(TAMANHO, TAMANHO)
	_sprite.mesh = quad

	# Material proprio por item: o icone muda, o shader nao. alpha_cutoff faz o
	# recorte duro do PS1, sem borda suave.
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/psx_surface.gdshader")
	mat.set_shader_parameter(&"albedo_tex", def.icone)
	mat.set_shader_parameter(&"alpha_cutoff", 0.4)
	mat.set_shader_parameter(&"use_snap", true)
	mat.set_shader_parameter(&"use_affine", false)
	mat.set_shader_parameter(&"emission_color", Color(1.0, 0.94, 0.82))
	mat.set_shader_parameter(&"emission_energy", 0.7)
	_sprite.material_override = mat
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sprite)

	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 0.9, 0.7)
	forma.shape = box
	add_child(forma)


func _process(delta: float) -> void:
	if _sprite == null:
		return
	_t += delta
	position.y = _base_y + sin(_t * VELOCIDADE_FLUTUACAO) * ALTURA_FLUTUACAO
	# Encara a camera so no eixo Y. Billboard completo deita o sprite quando o
	# jogador olha de cima e entrega que e um plano.
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var d := camera.global_position - global_position
		_sprite.rotation.y = atan2(d.x, d.z)


func interagir(quem: Node) -> void:
	if not habilitado:
		return
	var sobra := Inventario.adicionar(item_id, quantidade)
	if sobra >= quantidade:
		# Bolsa cheia: o item fica onde esta. Sumir com ele seria roubo.
		AudioDirector.tocar_ui(&"clique", -8.0)
		return

	AudioDirector.tocar(&"pegar", global_position, -3.0)
	acionado.emit(quem)

	if sobra > 0:
		quantidade = sobra
		return

	WorldState.definir(chunk, chave(), true)
	queue_free()


func rotulo_atual() -> String:
	if quantidade > 1:
		return "%s  x%d" % [rotulo, quantidade]
	return rotulo
