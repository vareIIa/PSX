## Ponto de save. Um telefone publico na calcada.
##
## Objeto do mundo, nao menu: a referencia do genero usa maquina de escrever,
## gravador, telefone. Um objeto fisico com lugar fixo faz o jogador memorizar
## onde ele fica, e essa memoria vira mapa mental.
##
## Fica aceso e zumbindo baixinho. Numa rua escura, ser a unica coisa iluminada
## e o que faz o jogador andar ate ele.
class_name PontoDeSave
extends Interativo

@export var espaco: int = 0
@export var nome_do_local: String = "Telefone publico"

var _luz: OmniLight3D
var _zumbido: AudioStreamPlayer3D


func _ready() -> void:
	super()
	add_to_group(&"ponto_de_save")
	rotulo = "Salvar"
	_montar()


func _montar() -> void:
	var corpo := MeshInstance3D.new()
	corpo.name = "Cabine"
	corpo.mesh = PSXMesh.box(Vector3(0.62, 1.35, 0.34), 1.2)
	corpo.material_override = load("res://resources/materials/mat_metal.tres")
	corpo.position = Vector3(0.0, 0.9, 0.0)
	corpo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(corpo)

	var painel := MeshInstance3D.new()
	painel.name = "Painel"
	painel.mesh = PSXMesh.plane(Vector2(0.48, 0.5))
	painel.material_override = load("res://resources/materials/mat_vitrine.tres")
	painel.position = Vector3(0.0, 1.22, 0.18)
	painel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(painel)

	var poste := MeshInstance3D.new()
	poste.mesh = PSXMesh.box(Vector3(0.12, 0.9, 0.12), 1.0)
	poste.material_override = load("res://resources/materials/mat_meio_fio.tres")
	poste.position = Vector3(0.0, 0.45, 0.0)
	poste.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(poste)

	_luz = OmniLight3D.new()
	_luz.light_color = Color("d8e8ff")
	_luz.light_energy = 1.4
	_luz.omni_range = 5.0
	_luz.shadow_enabled = false
	_luz.position = Vector3(0.0, 1.3, 0.4)
	add_child(_luz)

	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 2.0, 1.4)
	forma.shape = box
	forma.position = Vector3(0.0, 1.0, 0.0)
	add_child(forma)

	if AudioDirector.tem(&"zumbido_loop"):
		_zumbido = AudioStreamPlayer3D.new()
		_zumbido.stream = AudioDirector.stream(&"zumbido_loop")
		_zumbido.bus = &"Ambiente"
		_zumbido.volume_db = -22.0
		_zumbido.max_distance = 12.0
		_zumbido.position = Vector3(0.0, 1.2, 0.0)
		add_child(_zumbido)
		_zumbido.play()


func interagir(quem: Node) -> void:
	if not habilitado:
		return
	if SaveGame.salvar(espaco, nome_do_local):
		AudioDirector.tocar(&"pegar", global_position, -2.0)
	else:
		AudioDirector.tocar_ui(&"clique", -10.0)
	acionado.emit(quem)


func _exit_tree() -> void:
	if _zumbido != null:
		_zumbido.stop()
		_zumbido.stream = null
