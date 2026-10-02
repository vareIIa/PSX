## O papel com o telefone do Berg (Missao 1, C4B-03): sai da mao dele, cai
## girando e pousa deitado na calcada, legivel, e vira o item `bilhete_berg`.
##
## Por que nao e so um ItemNoChao
## ------------------------------
## O item no chao do jogo e um icone flutuando de frente para a camera, que e o
## que le na nevoa a dez metros. Este papel e filmado em close extremo (a camera
## acompanha a queda e para nele, "da para ler: BERG (35) 9 ••••-••••"), entao
## ele e uma folha de verdade deitada no chao, com a letra. O `ItemNoChao` vem
## junto, sem sprite, so para o [E] Pegar e para o WorldState lembrar que foi
## pego.
##
## A queda
## -------
## Sobe um tico no peteleco e desce devagar, balancando para os lados e girando,
## como papel cai: mais rapido no comeco, freado pelo ar no fim. Travada em
## quinze passos por segundo, como os corpos.
class_name BilheteNoAr
extends Node3D

const ITEM := &"bilhete_berg"
const TEXTO := "BERG\n(35) 9 ••••-••••"
## Folha de bloquinho dobrada ao meio: 11 x 7,5 cm.
const TAMANHO := Vector2(0.11, 0.075)
const COR_PAPEL := Color(0.86, 0.84, 0.77)
const COR_TINTA := Color(0.10, 0.13, 0.30)
## A chave no WorldState: um chunk que nao existe e o id do Berg no registro
## civil. O papel e um so no jogo inteiro.
const CHUNK := Vector2i(-77777, -77777)
const INDICE := 4100001
const DURACAO := 1.35
const SUBIDA := 0.28
const PASSOS := 15.0

## Pousou no chao e ja pode ser pego.
signal pousou()
## O jogador pegou (o item foi para o inventario).
signal pego(quem: Node)

var _de := Vector3.ZERO
var _para := Vector3.ZERO
var _t := 0.0
var _giro_final := 0.0
var _folha: MeshInstance3D
var _letra: Label3D
var _item: ItemNoChao
var _no_chao := false


## Comeca a queda de `de` (a mao) ate `para` (o chao). `giro` e o angulo em que
## a folha pousa: o texto fica de frente para quem esta do lado de `para`.
func lancar(de: Vector3, para: Vector3, giro: float) -> void:
	_de = de
	_para = para
	_giro_final = giro
	_t = 0.0
	_no_chao = false
	global_position = de
	set_process(true)


func no_chao() -> bool:
	return _no_chao


func item() -> ItemNoChao:
	return _item


func _ready() -> void:
	_folha = MeshInstance3D.new()
	_folha.name = "Folha"
	var quad := QuadMesh.new()
	quad.size = TAMANHO
	_folha.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/psx_surface.gdshader")
	mat.set_shader_parameter(&"tint", COR_PAPEL)
	mat.set_shader_parameter(&"use_snap", true)
	mat.set_shader_parameter(&"use_affine", false)
	# Um tico de brilho proprio: papel branco a noite e a coisa mais clara da
	# calcada, e a luz por vertice de um quadrado de 11 cm quase nao pega o
	# poste. Sem isto ele some no chao no close.
	mat.set_shader_parameter(&"emission_color", COR_PAPEL)
	mat.set_shader_parameter(&"emission_energy", 0.3)
	_folha.material_override = mat
	_folha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_folha)
	# A letra e um Label3D colado na folha: textura de fonte que o jogo ja tem,
	# sem imagem nova para importar, e nitida no close.
	_letra = Label3D.new()
	_letra.name = "Letra"
	_letra.text = TEXTO
	_letra.font_size = 22
	_letra.pixel_size = 0.0007
	_letra.outline_size = 0
	_letra.modulate = COR_TINTA
	_letra.double_sided = false
	_letra.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_letra.position = Vector3(0.0, 0.0, 0.0012)
	_letra.visibility_range_end = 12.0
	# Desenhada depois da folha: no mesmo plano, a ordem nao pode ficar com o
	# depth.
	_letra.render_priority = 1
	_folha.add_child(_letra)
	set_process(false)


func _process(delta: float) -> void:
	_t = minf(_t + delta, DURACAO)
	var tq := floorf(_t * PASSOS) / PASSOS
	var p := tq / DURACAO
	# Horizontal: rapido no peteleco, freado no fim.
	var h := 1.0 - pow(1.0 - p, 2.2)
	var pos := _de.lerp(_para, h)
	# Vertical: sobe SUBIDA e cai, mais devagar no fim (o ar segura a folha).
	var y0 := _de.y + SUBIDA * sin(minf(p * 2.2, 1.0) * PI * 0.5)
	var queda := smoothstep(0.25, 1.0, p)
	pos.y = lerpf(y0, _para.y, queda)
	# Balanco de folha: para os lados, cada vez menor.
	var balanco := sin(p * TAU * 2.5) * 0.07 * (1.0 - p)
	pos += Vector3(cos(_giro_final), 0.0, -sin(_giro_final)) * balanco
	global_position = pos + Vector3.UP * 0.003
	# Gira caindo e termina deitada (face para cima, texto legivel).
	var deita := smoothstep(0.55, 1.0, p)
	var rodopio := (1.0 - deita) * p * 9.0
	_folha.rotation = Vector3(lerpf(-0.6 + sin(p * 13.0) * 0.8, -PI * 0.5, deita),
		_giro_final + rodopio, 0.0)
	if _t >= DURACAO:
		set_process(false)
		_pousar()


func _pousar() -> void:
	_no_chao = true
	_folha.rotation = Vector3(-PI * 0.5, _giro_final, 0.0)
	global_position = _para + Vector3.UP * 0.003
	# Um papel novo e um papel ainda nao pego, mesmo que a missao seja refeita
	# na mesma partida.
	WorldState.definir(CHUNK, StringName("item_%d" % INDICE), false)
	_item = ItemNoChao.new()
	_item.name = "Item"
	_item.item_id = ITEM
	_item.chunk = CHUNK
	_item.indice = INDICE
	_item.sem_sprite = true
	_item.rotulo_proprio = "Pegar o papel"
	add_child(_item)
	_item.acionado.connect(_ao_pegar)
	AudioDirector.tocar(&"papel", global_position, -14.0)
	pousou.emit()


func _ao_pegar(quem: Node) -> void:
	_folha.visible = false
	pego.emit(quem)
	await get_tree().create_timer(0.3).timeout
	queue_free()
