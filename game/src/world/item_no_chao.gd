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
var _sumindo: bool = false


func _ready() -> void:
	super()
	add_to_group(&"item_no_chao")

	if _ja_foi_pego():
		queue_free()
		return

	_montar()
	_base_y = position.y
	# Em rede o item pode sumir porque OUTRO jogador o pegou.
	WorldState.mudou.connect(_ao_mudar_o_mundo)


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
	if Sessao.em_rede():
		_pedir(quem)
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
	_sumir()


## Em rede, pegar espera (plano 04 secao 4.1, classe 1): o som toca no quadro do
## [E], e o item so some quando o servidor confirma. Dois jogadores apertando no
## mesmo instante, um leva — e o outro ouve "Alguem pegou antes.". Quem credita a
## mochila e a `Sessao`, porque o chunk pode descarregar durante a espera e o
## item continua sendo de quem pediu.
func _pedir(quem: Node) -> void:
	if not Sessao.mundo_pronto():
		return
	if not Sessao.cabe_na_mochila(item_id, quantidade):
		# Em rede a quantidade e inteira ou nada: a chave do mundo e um booleano.
		AudioDirector.tocar_ui(&"clique", -8.0)
		return
	habilitado = false
	AudioDirector.tocar(&"pegar", global_position, -3.0)
	Sessao.pedir_item(chunk, indice, item_id, quantidade, _ao_responder.bind(quem))


func _ao_responder(ok: bool, _motivo: int, quem: Node) -> void:
	if not ok:
		if not _sumindo:
			habilitado = true
		return
	if is_instance_valid(quem):
		acionado.emit(quem)
	_sumir()


## Outro jogador pegou: some daqui sem entrar em mochila nenhuma desta maquina.
func _ao_mudar_o_mundo(coord: Vector2i, chave_mudada: StringName, valor: Variant) -> void:
	if not Sessao.em_rede() or _sumindo or coord != chunk or chave_mudada != chave():
		return
	if valor is bool and valor:
		_sumir()


## Sobe, cresce e apaga em 0,2 s. Sumir no mesmo quadro nao da retorno nenhum:
## o jogador aperta a tecla e a coisa some, sem saber se pegou ou se travou.
func _sumir() -> void:
	if _sumindo:
		return
	_sumindo = true
	habilitado = false
	set_process(false)
	if _sprite == null:
		queue_free()
		return
	var t := create_tween().set_parallel(true)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_sprite, "scale", Vector3(1.7, 1.7, 1.7), 0.2)
	t.tween_property(_sprite, "position:y", _sprite.position.y + 0.45, 0.2)
	# transparency e a propriedade de GeometryInstance3D; modulate so existe em
	# CanvasItem e nao faz nada num no 3D.
	t.tween_property(_sprite, "transparency", 1.0, 0.18)
	t.chain().tween_callback(queue_free)


func rotulo_atual() -> String:
	if quantidade > 1:
		return "%s  x%d" % [rotulo, quantidade]
	return rotulo
