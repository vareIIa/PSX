## Onde nao chove: o volume da cabine, escrito na chuva a cada quadro.
##
## Por que isto existe
## -------------------
## A chuva e uma caixa de 22 m de lado que segue a camera, e no plano de dentro
## a camera esta DENTRO de um carro. A lataria so tapa o que esta atras dela: a
## gota que nasceu entre o olho e o para-brisa e desenhada na cara do motorista,
## atravessando o painel e caindo no colo dele. E o criterio C12 do
## PLANO_CHUVA_CABINE_AAA — "nenhum risco de chuva dentro da cabine".
##
## Por que um no a parte, e nao uma linha na `Chuva`
## ------------------------------------------------
## Porque quem sabe onde a cabine esta e a cabine, e quem desenha a chuva e a
## chuva, e as duas nao se conhecem: a chuva da Estrada Velha e da cidade e a
## mesma, e o carro que tem cabine hoje e o da cena e amanha e o do jogador.
## Este no fica pendurado na cabine, acha a chuva pelo grupo `chuva` e escreve no
## material dela. Nenhum dos dois precisa saber do outro — e quando a cabine sai
## da cena, o teto sai junto.
##
## O que se escreve
## ----------------
## Uma caixa no espaco do carro e ate seis planos (os vidros, com a normal para
## fora). Caixa E planos: o para-brisa e inclinado, e a caixa que vai do
## corta-fogo ao fundo engloba, na frente, uma cunha de ar que esta FORA do
## carro, em cima do capo — justamente onde o motorista mais ve a chuva. O plano
## do vidro corta essa cunha fora.
class_name TetoChuva
extends Node

const SHADER_CHUVA := "res://shaders/psx_chuva.gdshader"
const MAX_PLANOS := 6

## O no cujo espaco local e o do teto (a cabine).
var dono: Node3D
## `{"min": Vector3, "max": Vector3, "planos": PackedVector4Array}`.
var teto: Dictionary = {}

var _escritos: Array[ShaderMaterial] = []


func _process(_delta: float) -> void:
	if dono == null or not is_instance_valid(dono) or teto.is_empty():
		return
	var agora: Array[ShaderMaterial] = []
	for no: Node in get_tree().get_nodes_in_group(&"chuva"):
		var mat := _material_da_chuva(no)
		if mat != null:
			escrever(mat, dono.global_transform, teto)
			agora.append(mat)
	_escritos = agora


func _exit_tree() -> void:
	# A cabine saiu: a chuva volta a cair em todo lugar. Sem isto o ultimo
	# carro deixaria um buraco seco no meio da estrada.
	for mat: ShaderMaterial in _escritos:
		if is_instance_valid(mat):
			apagar(mat)
	_escritos.clear()


## O material de risco de um no do grupo `chuva`, ou null.
static func _material_da_chuva(no: Node) -> ShaderMaterial:
	var gi := no as GeometryInstance3D
	if gi == null:
		return null
	var mat := gi.material_override as ShaderMaterial
	if mat == null or mat.shader == null:
		return null
	if mat.shader.resource_path != SHADER_CHUVA:
		return null
	return mat


## Escreve o teto num material de chuva. `xform` e a transformada GLOBAL do dono.
static func escrever(mat: ShaderMaterial, xform: Transform3D, t: Dictionary) -> void:
	mat.set_shader_parameter(&"teto_ativo", true)
	mat.set_shader_parameter(&"teto_do_mundo", xform.affine_inverse())
	mat.set_shader_parameter(&"teto_min", t["min"])
	mat.set_shader_parameter(&"teto_max", t["max"])
	var planos: PackedVector4Array = t.get("planos", PackedVector4Array())
	if planos.size() > MAX_PLANOS:
		planos = planos.slice(0, MAX_PLANOS)
	mat.set_shader_parameter(&"teto_n_planos", planos.size())
	if not planos.is_empty():
		mat.set_shader_parameter(&"teto_planos", planos)


static func apagar(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter(&"teto_ativo", false)


## O plano de um vidro: normal para fora e a distancia dele a origem.
static func plano(normal: Vector3, ponto: Vector3) -> Vector4:
	var n := normal.normalized()
	return Vector4(n.x, n.y, n.z, n.dot(ponto))
