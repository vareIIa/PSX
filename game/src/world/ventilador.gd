## Ventilador de parede da estufa.
##
## Existe por causa da planta, e nao do ar. A folhagem balanca porque o material
## tem vento — mas vento sem fonte visivel, dentro de um comodo fechado, le como
## defeito de shader. O ventilador e a EXPLICACAO daquele movimento: assim que o
## jogador ve a helice girando na parede, o balanco da plantacao inteira passa a
## fazer sentido.
##
## Duas rotacoes, e as duas importam:
##
##   helice    rapida e continua, no eixo do proprio ventilador
##   cabeca    lenta e de vai e vem, varrendo o comodo
##
## So a helice, o objeto vira enfeite girando parado. So a cabeca, vira camera de
## seguranca. As duas juntas sao a coisa que todo mundo ja viu num canto de sala.
class_name Ventilador
extends Node3D

const MATERIAL := "res://resources/materials/mat_estufa.tres"
const MATERIAL_GRADE := "res://resources/materials/mat_estufa_recorte.tres"

const C_CORPO := Vector2i(4, 5)
const C_GRADE := Vector2i(7, 5)
const C_PA := Vector2i(3, 5)

## Voltas por segundo da helice. Acima disso o snap de vertice do PSX faz a pa
## pular para tras — e o mesmo efeito de roda de carroca em filme, e aqui ele
## nao e charmoso, e le como travamento.
const GIRO_HELICE := 5.2

## Varredura da cabeca, em radianos para cada lado, e quanto tempo leva a ida.
const VARREDURA := 0.62
const PERIODO := 7.0

## Quanto o ventilador oscila. Fixo em 0 deixa a cabeca parada, para o exaustor
## de duto que usa a mesma classe e nao varre nada.
@export var oscila: bool = true
## Defasagem da varredura, para dois ventiladores no mesmo comodo nao andarem
## em espelho.
@export var fase: float = 0.0

var _cabeca: Node3D
var _helice: Node3D
var _t: float = 0.0


func _ready() -> void:
	_montar()
	set_process(true)


func _montar() -> void:
	var mat := load(MATERIAL) as Material
	var mat_grade := load(MATERIAL_GRADE) as Material

	# A haste. Fica no no de cima, e nao na cabeca: haste que varre junto com a
	# cabeca e um ventilador que balanca inteiro na parede.
	var haste := MeshInstance3D.new()
	haste.name = "Haste"
	haste.mesh = _malha_de_caixa(Vector3(0.07, 0.07, 0.18), C_CORPO)
	haste.material_override = mat
	haste.position = Vector3(0.0, 0.0, -0.14)
	haste.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(haste)

	_cabeca = Node3D.new()
	_cabeca.name = "Cabeca"
	add_child(_cabeca)

	var motor := MeshInstance3D.new()
	motor.name = "Motor"
	motor.mesh = _malha_de_caixa(Vector3(0.16, 0.16, 0.16), C_CORPO)
	motor.material_override = mat
	motor.position = Vector3(0.0, 0.0, -0.06)
	motor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cabeca.add_child(motor)

	_helice = Node3D.new()
	_helice.name = "Helice"
	_helice.position = Vector3(0.0, 0.0, 0.04)
	_cabeca.add_child(_helice)

	# Tres pas. Sao placas inclinadas e nao volumes: a pa de um ventilador tem um
	# milimetro de espessura, e a esta velocidade o que se ve e o borrao.
	var dados := PSXMesh.dados_vazios()
	for k in 3:
		var giro := TAU * float(k) / 3.0
		var d := PSXMesh.placa_dados(Vector2(0.10, 0.30), 100.0,
			Color(0.82, 0.84, 0.86, 1.0))
		AtlasKit.remapear(d, C_PA)
		PSXMesh.acumular(dados, d, Transform3D(
			Basis(Vector3.FORWARD, giro) * Basis(Vector3.UP, 0.5),
			Vector3(-sin(giro) * 0.14, cos(giro) * 0.14, 0.0)))
	var pas := MeshInstance3D.new()
	pas.name = "Pas"
	pas.mesh = PSXMesh.dados_para_mesh(dados)
	pas.material_override = mat
	pas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_helice.add_child(pas)

	# A grade na frente, recortada. E o que fecha o objeto: helice girando sem
	# grade le como turbina, e nao como ventilador de parede.
	var grade := MeshInstance3D.new()
	grade.name = "Grade"
	grade.mesh = _malha_de_celula(Vector2(0.40, 0.40), C_GRADE)
	grade.material_override = mat_grade
	grade.position = Vector3(0.0, 0.0, 0.09)
	grade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cabeca.add_child(grade)


## Uma caixa vestindo UMA celula do atlas.
##
## `PSXMesh.box` nao serve: ele mapeia UV por metro sobre a textura inteira, e
## num atlas isso veste a peca com um retalho arbitrario — o motor do ventilador
## sairia com um pedaco de folha estampado. Ver AtlasKit.
static func _malha_de_caixa(tamanho: Vector3, celula: Vector2i) -> ArrayMesh:
	var sup: Dictionary = {}
	AtlasKit.caixa(sup, &"m", Vector3.ZERO, tamanho, celula)
	return PSXMesh.dados_para_mesh(sup[&"m"])


static func _malha_de_celula(tamanho: Vector2, celula: Vector2i) -> ArrayMesh:
	var d := PSXMesh.placa_dados(tamanho, 100.0, Color.WHITE)
	AtlasKit.remapear(d, celula)
	return PSXMesh.dados_para_mesh(d)


func _process(delta: float) -> void:
	_t += delta
	_helice.rotation.z = fposmod(_t * GIRO_HELICE * TAU, TAU)
	if oscila:
		_cabeca.rotation.y = sin((_t + fase) * TAU / PERIODO) * VARREDURA
