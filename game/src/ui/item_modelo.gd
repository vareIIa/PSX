## Monta um modelo 3D low-poly por item de inventario.
##
## Usado em dois lugares que precisam ser a mesma familia visual:
##   1. Vitrine 3D do item selecionado na prancha (gira de verdade).
##   2. Bake dos icones PNG (tools/bake_icones via Godot).
##
## Volumes de primitivas (caixa/cilindro/esfera/prisma), sem textura flat —
## a legibilidade vem do volume iluminado, como nos itens da print.
class_name ItemModelo
extends RefCounted

const IDS: Array[StringName] = [
	&"bandagem", &"remedio", &"pistola", &"municao_9mm", &"lanterna",
	&"bateria", &"radio", &"chave_apartamento", &"pe_de_cabra",
	&"bilhete", &"identidade",
	&"terra", &"semente_maconha", &"regador", &"maconha", &"super_maconha",
	&"erva_morcega", &"erva_bonsai", &"erva_saca_rolha", &"erva_girafa",
	&"erva_pompom", &"erva_chorona", &"erva_gambazona", &"erva_vagalume",
	&"carregador",
]

## Item colhido de cada andar da estufa -> variedade (Variedades.DADOS).
const DA_VARIEDADE := {
	&"erva_morcega": &"morcega", &"erva_bonsai": &"bonsai",
	&"erva_saca_rolha": &"saca_rolha", &"erva_girafa": &"girafa",
	&"erva_pompom": &"pompom", &"erva_chorona": &"chorona",
	&"erva_gambazona": &"gambazona", &"erva_vagalume": &"vagalume",
}


static func criar(id: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = String(id)
	if DA_VARIEDADE.has(id):
		_variedade(root, DA_VARIEDADE[id])
		return root
	match id:
		&"bandagem":
			_bandagem(root)
		&"remedio":
			_remedio(root)
		&"pistola":
			_pistola(root)
		&"municao_9mm":
			_municao(root)
		&"lanterna":
			_lanterna(root)
		&"bateria":
			_bateria(root)
		&"radio":
			_radio(root)
		&"chave_apartamento":
			_chave(root)
		&"pe_de_cabra":
			_pe_de_cabra(root)
		&"bilhete":
			_bilhete(root)
		&"identidade":
			_identidade(root)
		&"terra":
			_terra(root)
		&"semente_maconha":
			_semente(root)
		&"regador":
			_regador(root)
		&"maconha":
			_maconha(root)
		&"super_maconha":
			_maconha(root, true)
		&"carregador":
			_carregador(root)
		_:
			_caixa(root, Vector3(0.6, 0.6, 0.6), Vector3.ZERO, Color("888888"))
	return root


static func _mat(cor: Color, metalico: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = clampf(0.92 - metalico * 0.55, 0.25, 0.95)
	m.metallic = metalico
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return m


static func _caixa(
	pai: Node3D, tamanho: Vector3, pos: Vector3, cor: Color,
	rot := Vector3.ZERO, metalico: float = 0.0
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = tamanho
	mi.mesh = mesh
	mi.material_override = _mat(cor, metalico)
	mi.position = pos
	mi.rotation = rot
	pai.add_child(mi)
	return mi


static func _cilindro(
	pai: Node3D, raio_topo: float, raio_base: float, altura: float,
	pos: Vector3, cor: Color, rot := Vector3.ZERO, lados: int = 12,
	metalico: float = 0.0
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = raio_topo
	mesh.bottom_radius = raio_base
	mesh.height = altura
	mesh.radial_segments = lados
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = _mat(cor, metalico)
	mi.position = pos
	mi.rotation = rot
	pai.add_child(mi)
	return mi


static func _esfera(
	pai: Node3D, raio: float, pos: Vector3, cor: Color, aneis: int = 8
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = raio
	mesh.height = raio * 2.0
	mesh.radial_segments = aneis
	mesh.rings = maxi(4, aneis / 2)
	mi.mesh = mesh
	mi.material_override = _mat(cor)
	mi.position = pos
	pai.add_child(mi)
	return mi


# --- modelos ---------------------------------------------------------------

static func _bandagem(pai: Node3D) -> void:
	# Rolo deitado (eixo X): cilindro oco legivel como na print.
	var tilt := Vector3(0.0, deg_to_rad(25.0), deg_to_rad(90.0))
	_cilindro(pai, 0.52, 0.52, 0.78, Vector3(0.0, 0.0, 0.0), Color("efe6d4"), tilt, 16)
	_cilindro(pai, 0.38, 0.38, 0.80, Vector3(0.0, 0.0, 0.0), Color("d2c6b0"), tilt, 14)
	_cilindro(pai, 0.24, 0.24, 0.82, Vector3(0.0, 0.0, 0.0), Color("9a8c74"), tilt, 12)
	_cilindro(pai, 0.12, 0.12, 0.84, Vector3(0.0, 0.0, 0.0), Color("3a3228"), tilt, 10)
	for i in 4:
		var x := -0.28 + float(i) * 0.18
		_cilindro(pai, 0.535, 0.535, 0.05, Vector3(x, 0.0, 0.0), Color("c8bca8"), tilt, 16)
	_caixa(pai, Vector3(0.55, 0.08, 0.30), Vector3(-0.15, -0.42, 0.35), Color("f4ebe0"),
		Vector3(deg_to_rad(8.0), deg_to_rad(18.0), deg_to_rad(-6.0)))
	_caixa(pai, Vector3(0.18, 0.03, 0.03), Vector3(-0.22, -0.40, 0.42), Color("c62828"))
	_caixa(pai, Vector3(0.03, 0.03, 0.16), Vector3(-0.22, -0.40, 0.42), Color("c62828"))



static func _remedio(pai: Node3D) -> void:
	# Frasco vermelho com tampa e cruz branca (pilula/garrafa).
	_cilindro(pai, 0.38, 0.42, 0.85, Vector3(0.0, -0.05, 0.0), Color("c62828"), Vector3.ZERO, 14)
	_cilindro(pai, 0.28, 0.30, 0.18, Vector3(0.0, 0.48, 0.0), Color("e8dfc8"), Vector3.ZERO, 12)
	_caixa(pai, Vector3(0.14, 0.42, 0.06), Vector3(0.0, -0.02, 0.40), Color("f5f0e6"))
	_caixa(pai, Vector3(0.42, 0.14, 0.06), Vector3(0.0, -0.02, 0.40), Color("f5f0e6"))
	_caixa(pai, Vector3(0.55, 0.22, 0.02), Vector3(0.0, 0.18, 0.41), Color("f0d040"))


static func _pistola(pai: Node3D) -> void:
	# Semi-auto escura: proporcao de pistola de inventario (nao SMG).
	var metal := Color("2e322c")
	var slide := Color("4a4e46")
	_caixa(pai, Vector3(1.05, 0.26, 0.28), Vector3(0.08, 0.22, 0.0), metal, Vector3.ZERO, 0.6)
	_caixa(pai, Vector3(0.92, 0.08, 0.24), Vector3(0.02, 0.36, 0.0), slide, Vector3.ZERO, 0.45)
	_caixa(pai, Vector3(0.18, 0.16, 0.16), Vector3(0.58, 0.22, 0.0), Color("1a1c18"), Vector3.ZERO, 0.65)
	_caixa(pai, Vector3(0.30, 0.58, 0.24), Vector3(-0.18, -0.18, 0.0), Color("242620"),
		Vector3(0.0, 0.0, deg_to_rad(14.0)), 0.4)
	for i in 5:
		_caixa(pai, Vector3(0.22, 0.02, 0.22), Vector3(-0.16, -0.05 - float(i) * 0.08, 0.02),
			Color("1a1c18"), Vector3(0.0, 0.0, deg_to_rad(14.0)))
	_caixa(pai, Vector3(0.30, 0.05, 0.05), Vector3(0.12, 0.02, 0.0), metal, Vector3.ZERO, 0.55)
	_caixa(pai, Vector3(0.05, 0.20, 0.05), Vector3(0.24, -0.06, 0.0), metal, Vector3.ZERO, 0.55)
	_caixa(pai, Vector3(0.04, 0.14, 0.04), Vector3(0.10, 0.02, 0.0), Color("121410"))
	_caixa(pai, Vector3(0.07, 0.12, 0.05), Vector3(-0.38, 0.44, 0.0), Color("1a1c18"))
	_caixa(pai, Vector3(0.07, 0.10, 0.05), Vector3(0.42, 0.42, 0.0), Color("1a1c18"))


static func _municao(pai: Node3D) -> void:
	# Caixa aberta: corpo preto, tampa vermelha erguida, estojos dourados.
	_caixa(pai, Vector3(1.00, 0.38, 0.70), Vector3(0.0, -0.12, 0.0), Color("1c1c20"))
	_caixa(pai, Vector3(1.00, 0.08, 0.70), Vector3(0.0, 0.10, 0.0), Color("b02020"))
	# Tampa semi-aberta
	_caixa(pai, Vector3(1.00, 0.06, 0.55), Vector3(0.0, 0.28, -0.10), Color("c62828"),
		Vector3(deg_to_rad(-55.0), 0.0, 0.0))
	_caixa(pai, Vector3(0.55, 0.03, 0.03), Vector3(0.0, 0.12, 0.36), Color("f0e8d0"))
	var ouro := Color("e8c050")
	for i in 4:
		var x := -0.33 + float(i) * 0.22
		_cilindro(pai, 0.06, 0.06, 0.42, Vector3(x, 0.02, 0.08), ouro,
			Vector3(deg_to_rad(78.0), 0.0, 0.0), 8, 0.7)
		_cilindro(pai, 0.045, 0.055, 0.07, Vector3(x, 0.08, 0.28), Color("a88830"),
			Vector3(deg_to_rad(78.0), 0.0, 0.0), 8, 0.5)


static func _lanterna(pai: Node3D) -> void:
	_cilindro(pai, 0.22, 0.22, 0.85, Vector3(-0.15, 0.0, 0.0), Color("3a3834"),
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 12, 0.25)
	_cilindro(pai, 0.34, 0.26, 0.28, Vector3(0.42, 0.0, 0.0), Color("f0e6b0"),
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 12)
	_cilindro(pai, 0.18, 0.18, 0.08, Vector3(0.58, 0.0, 0.0), Color("fff8d0"),
		Vector3(0.0, 0.0, deg_to_rad(90.0)), 10)
	_caixa(pai, Vector3(0.18, 0.12, 0.10), Vector3(-0.20, 0.18, 0.0), Color("a8a090"))


static func _bateria(pai: Node3D) -> void:
	_cilindro(pai, 0.32, 0.32, 0.95, Vector3(0.0, -0.05, 0.0), Color("1e4a82"), Vector3.ZERO, 14)
	_cilindro(pai, 0.22, 0.22, 0.12, Vector3(0.0, 0.48, 0.0), Color("e8dfc0"), Vector3.ZERO, 10, 0.4)
	_caixa(pai, Vector3(0.55, 0.22, 0.02), Vector3(0.0, 0.18, 0.32), Color("f0c828"))
	_caixa(pai, Vector3(0.06, 0.14, 0.03), Vector3(0.0, 0.18, 0.34), Color("1a1a16"))
	_caixa(pai, Vector3(0.14, 0.06, 0.03), Vector3(0.0, 0.18, 0.34), Color("1a1a16"))
	for i in 3:
		_caixa(pai, Vector3(0.50, 0.04, 0.02), Vector3(0.0, -0.15 - float(i) * 0.14, 0.32), Color("0e1e30"))


## O carregador de parede do iPhone: o cubo branco de 5 W, os dois pinos
## redondos da tomada brasileira, a porta USB, e o fio de 30 pinos enrolado do
## lado, com o plugue na ponta.
static func _carregador(pai: Node3D) -> void:
	var branco := Color("f2f2ef")
	_caixa(pai, Vector3(0.46, 0.46, 0.46), Vector3(-0.18, 0.0, 0.0), branco)
	_caixa(pai, Vector3(0.20, 0.07, 0.02), Vector3(-0.18, 0.04, 0.235), Color("2b2b2b"))
	_caixa(pai, Vector3(0.16, 0.03, 0.022), Vector3(-0.18, 0.055, 0.236), Color("c9c9c4"), Vector3.ZERO, 0.6)
	for sx: float in [-1.0, 1.0]:
		_cilindro(pai, 0.03, 0.03, 0.22, Vector3(-0.18 + sx * 0.09, 0.0, -0.33), Color("c8c8c2"),
			Vector3(deg_to_rad(90.0), 0.0, 0.0), 10, 0.8)
	# O fio enrolado: tres voltas de gomos, e o plugue de 30 pinos.
	var voltas := 3
	var gomos := 14
	for v in voltas:
		var r := 0.30 - float(v) * 0.02
		for i in gomos:
			var a := TAU * float(i) / float(gomos)
			var b := TAU * float(i + 1) / float(gomos)
			var pa := Vector3(0.30 + cos(a) * r, sin(a) * r * 0.9, -0.05 + float(v) * 0.05)
			var pb := Vector3(0.30 + cos(b) * r, sin(b) * r * 0.9, -0.05 + float(v) * 0.05)
			var meio := (pa + pb) * 0.5
			var mi := _cilindro(pai, 0.028, 0.028, pa.distance_to(pb) * 1.08, meio, branco)
			mi.look_at_from_position(meio, pb, Vector3.FORWARD if absf((pb - pa).normalized().y) > 0.9 else Vector3.UP)
			mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	_caixa(pai, Vector3(0.20, 0.06, 0.13), Vector3(0.30, -0.36, 0.04), branco)
	_caixa(pai, Vector3(0.17, 0.03, 0.05), Vector3(0.30, -0.36, 0.13), Color("b8b8b2"), Vector3.ZERO, 0.8)


static func _radio(pai: Node3D) -> void:
	_caixa(pai, Vector3(0.85, 0.55, 0.35), Vector3(0.0, -0.05, 0.0), Color("35322e"), Vector3.ZERO, 0.2)
	_caixa(pai, Vector3(0.38, 0.28, 0.04), Vector3(-0.16, 0.02, 0.18), Color("141210"))
	for i in 5:
		_caixa(pai, Vector3(0.03, 0.24, 0.02), Vector3(-0.30 + float(i) * 0.07, 0.02, 0.20), Color("7a7268"))
	_cilindro(pai, 0.10, 0.10, 0.08, Vector3(0.26, 0.02, 0.20), Color("d4a83a"),
		Vector3(deg_to_rad(90.0), 0.0, 0.0), 10, 0.45)
	_caixa(pai, Vector3(0.04, 0.55, 0.04), Vector3(0.34, 0.40, -0.05), Color("c8c0b0"),
		Vector3(deg_to_rad(8.0), 0.0, deg_to_rad(12.0)), 0.5)
	_esfera(pai, 0.05, Vector3(0.40, 0.68, -0.02), Color("d4a83a"))


static func _chave(pai: Node3D) -> void:
	var ouro := Color("d4a83a")
	_cilindro(pai, 0.28, 0.28, 0.10, Vector3(-0.35, 0.0, 0.0), ouro,
		Vector3(deg_to_rad(90.0), 0.0, 0.0), 12, 0.7)
	_cilindro(pai, 0.14, 0.14, 0.12, Vector3(-0.35, 0.0, 0.0), Color("1a1410"),
		Vector3(deg_to_rad(90.0), 0.0, 0.0), 10)
	_caixa(pai, Vector3(0.85, 0.10, 0.10), Vector3(0.20, 0.0, 0.0), ouro, Vector3.ZERO, 0.7)
	_caixa(pai, Vector3(0.12, 0.28, 0.08), Vector3(0.52, -0.12, 0.0), ouro, Vector3.ZERO, 0.7)
	_caixa(pai, Vector3(0.10, 0.18, 0.08), Vector3(0.32, -0.08, 0.0), ouro, Vector3.ZERO, 0.7)


static func _pe_de_cabra(pai: Node3D) -> void:
	var ferrugem := Color("a05034")
	var escuro := Color("6a3020")
	# Haste diagonal
	_caixa(pai, Vector3(0.14, 1.35, 0.14), Vector3(0.0, 0.0, 0.0), ferrugem,
		Vector3(0.0, 0.0, deg_to_rad(-35.0)), 0.55)
	# Gancho
	_caixa(pai, Vector3(0.14, 0.14, 0.42), Vector3(0.42, 0.48, 0.05), ferrugem,
		Vector3(deg_to_rad(10.0), deg_to_rad(20.0), deg_to_rad(-20.0)), 0.55)
	_caixa(pai, Vector3(0.12, 0.28, 0.12), Vector3(0.55, 0.32, 0.18), escuro,
		Vector3(deg_to_rad(15.0), 0.0, deg_to_rad(-10.0)), 0.5)
	# Pe achatado
	_caixa(pai, Vector3(0.28, 0.08, 0.18), Vector3(-0.48, -0.52, 0.0), ferrugem,
		Vector3(0.0, 0.0, deg_to_rad(-35.0)), 0.55)


static func _bilhete(pai: Node3D) -> void:
	_caixa(pai, Vector3(0.72, 0.95, 0.04), Vector3(0.0, 0.0, 0.0), Color("f0e6c8"),
		Vector3(deg_to_rad(4.0), deg_to_rad(-8.0), deg_to_rad(6.0)))
	_caixa(pai, Vector3(0.40, 0.04, 0.02), Vector3(-0.05, 0.28, 0.03), Color("a02824"),
		Vector3(deg_to_rad(4.0), deg_to_rad(-8.0), deg_to_rad(6.0)))
	for i in 4:
		_caixa(pai, Vector3(0.50, 0.02, 0.015), Vector3(0.02, 0.10 - float(i) * 0.14, 0.03),
			Color("5a4838"), Vector3(deg_to_rad(4.0), deg_to_rad(-8.0), deg_to_rad(6.0)))
	# Canto dog-ear
	_caixa(pai, Vector3(0.16, 0.16, 0.03), Vector3(0.28, 0.38, 0.03), Color("d8ceb0"),
		Vector3(deg_to_rad(50.0), deg_to_rad(-8.0), deg_to_rad(6.0)))


static func _identidade(pai: Node3D) -> void:
	_caixa(pai, Vector3(1.05, 0.68, 0.06), Vector3(0.0, 0.0, 0.0), Color("d6e0c8"))
	_caixa(pai, Vector3(1.05, 0.16, 0.02), Vector3(0.0, 0.26, 0.04), Color("2a623a"))
	_caixa(pai, Vector3(0.28, 0.34, 0.02), Vector3(-0.28, -0.06, 0.04), Color("6e7c84"))
	_esfera(pai, 0.08, Vector3(-0.28, 0.02, 0.06), Color("d8b89a"))
	_caixa(pai, Vector3(0.22, 0.12, 0.02), Vector3(-0.28, -0.16, 0.05), Color("3a4650"))
	for i in 4:
		_caixa(pai, Vector3(0.38 - float(i) * 0.02, 0.03, 0.015),
			Vector3(0.22, 0.08 - float(i) * 0.10, 0.04), Color("3e4e3a"))


# --- os cinco do cultivo ----------------------------------------------------
#
# Sao insumos, e insumo tem um problema proprio de icone: terra, semente e erva
# sao todos marrom-esverdeados e todos granulados, e no icone pequeno viram a
# mesma mancha. O que os separa continua sendo a SILHUETA do recipiente — saco
# de boca aberta, envelope de aba em pe, lata com bico, pote alto de tampa — e
# por isso as proporcoes da versao de caixas ficaram.
#
# O resto nao ficou. Estes cinco saem da familia de primitivas do arquivo porque
# sao os que o jogador EXAMINA de perto (a inspecao da pausa gira o pote na
# mao), e o pote de caixas examinado era um cilindro branco. Aqui a geometria e
# montada vertice a vertice (solido de revolucao, tubo varrido, cacho de
# calices), e os impressos vem de um atlas (tools/gerar_rotulos_cultivo.py).
#
# Reflexo sem sonda: as tres telas que mostram item (vitrine, bake, inspecao)
# tem fundo de cor chapada e nenhuma ReflectionProbe, e metal ou vidro sob
# reflexo de fundo preto sai preto. Os materiais daqui desenham o proprio
# "estudio" refletido (ceu claro em cima, uma janela a direita) pela normal em
# espaco de vista, como um matcap: le igual nas tres telas sem mexer em nenhuma.

## Atlas dos impressos. As regioes em pixel sao o contrato com o gerador.
const ROTULOS := "res://assets/itens_cultivo/rotulos.png"
const ATLAS := 1024.0
## O atlas tem duas folhas de 1024: a de cima e a do cultivo, a de baixo os oito
## rotulos das variedades (REG_VAR).
const ATLAS_ALTO := 2048.0
const REG_POTE := Rect2(0, 0, 512, 256)
const REG_POTE_SUPER := Rect2(512, 0, 512, 256)
const REG_SACO := Rect2(0, 256, 1024, 384)
const REG_ENV_FRENTE := Rect2(0, 640, 288, 384)
const REG_ENV_VERSO := Rect2(288, 640, 288, 384)
const REG_CRIVO := Rect2(576, 640, 192, 192)
const REG_TERRA := Rect2(768, 640, 256, 256)
const REG_KRAFT := Rect2(576, 832, 192, 192)

## Meia largura e meia profundidade do saco de terra.
const SACO_W := 0.31
const SACO_D := 0.19
## Onde o bico do regador passa, de onde sai do corpo ate o crivo.
const BICO := [
	Vector3(0.10, -0.36, 0.0), Vector3(0.22, -0.27, 0.0), Vector3(0.36, -0.10, 0.0),
	Vector3(0.49, 0.09, 0.0), Vector3(0.60, 0.27, 0.0),
]

## Malhas e shaders montados uma vez por execucao. O pote cheio tem 23 cabecas
## (cinco variantes de ~550 triangulos); montar isso toda vez que a prancha troca
## de item seria um engasgo por clique. As malhas sao imutaveis depois de prontas,
## e por isso podem ser divididas entre a vitrine, a inspecao e o bake.
static var _cache: Dictionary = {}


## Malha montada a mao. Existe no lugar do SurfaceTool por um motivo so: aqui
## cada triangulo se orienta pela normal dos proprios vertices. O giro de face
## deste motor ja derrubou modelo inteiro (a face aparece do lado OPOSTO ao
## produto vetorial), e assim nenhuma peca depende de eu acertar a ordem dos
## indices.
class Malha:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var cor := PackedColorArray()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()

	func ponto(p: Vector3, nor: Vector3, c: Color = Color.WHITE,
			t: Vector2 = Vector2.ZERO) -> int:
		v.append(p)
		n.append(nor.normalized())
		cor.append(c)
		uv.append(t)
		return v.size() - 1

	func tri(a: int, b: int, c: int) -> void:
		var face := (v[b] - v[a]).cross(v[c] - v[a])
		if face.length_squared() < 1e-16:
			return
		if face.dot(n[a] + n[b] + n[c]) > 0.0:
			idx.append_array(PackedInt32Array([a, c, b]))
		else:
			idx.append_array(PackedInt32Array([a, b, c]))

	func quad(a: int, b: int, c: int, d: int) -> void:
		tri(a, b, c)
		tri(a, c, d)

	func malha() -> ArrayMesh:
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = cor
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return am


# --- shaders ------------------------------------------------------------------

## Material geral: tinta, papel, plastico e metal. `COLOR.a` abaixo de 1 e
## metal aparecendo por baixo da tinta (o desgaste do regador).
const SH_ESTUDIO := """
shader_type spatial;
render_mode %s, specular_schlick_ggx;

uniform sampler2D textura : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform vec4 cor : source_color = vec4(1.0);
uniform vec4 cor_verso : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool usa_verso = false;
uniform bool usa_cor_vertice = false;
uniform float metal : hint_range(0.0, 1.0) = 0.0;
uniform float reflexo : hint_range(0.0, 2.0) = 0.3;
uniform float rugosidade : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	vec3 base = cor.rgb * texture(textura, UV).rgb;
	float metal_v = metal;
	if (usa_cor_vertice) {
		base *= pow(COLOR.rgb, vec3(2.2));
		metal_v = max(metal_v, 1.0 - COLOR.a);
	}
	if (usa_verso && !FRONT_FACING) {
		base = cor_verso.rgb;
	}
	vec3 n = normalize(NORMAL);
	vec3 r = reflect(-VIEW, n);
	float fres = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 4.0);
	float nitidez = 1.0 - rugosidade;
	// O estudio refletido: chao escuro, ceu claro e uma janela a direita, que
	// alarga e apaga conforme a superficie fica aspera.
	float ceu = smoothstep(-0.3, 0.9, r.y);
	float borda = 0.03 + 0.2 * rugosidade;
	float janela = smoothstep(0.30 - borda, 0.30 + borda, r.x)
		* (1.0 - smoothstep(0.62 - borda, 0.62 + borda, r.x))
		* smoothstep(-0.15, 0.3, r.y);
	vec3 estudio = mix(vec3(0.03, 0.03, 0.035), vec3(0.40, 0.42, 0.46), ceu)
		+ vec3(1.0, 0.97, 0.9) * janela * (0.3 + 1.5 * nitidez);
	vec3 f0 = mix(vec3(0.04), base, metal_v);
	vec3 espec = estudio * mix(f0, vec3(1.0), fres * (1.0 - metal_v) * nitidez);
	ALBEDO = base * (1.0 - metal_v * 0.85);
	ROUGHNESS = rugosidade;
	METALLIC = 0.0;
	EMISSION = espec * reflexo;
}
"""

## Vidro do pote: quase nada no meio, borda de Fresnel, e duas faixas de janela
## refletida. Sem as faixas o vidro some; sem a borda, o pote vira um monte de
## erva flutuando.
const SH_VIDRO := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform vec4 tinta : source_color = vec4(0.80, 0.92, 0.86, 1.0);
uniform float alfa_centro : hint_range(0.0, 1.0) = 0.05;
uniform float alfa_borda : hint_range(0.0, 1.0) = 0.62;

void fragment() {
	vec3 n = normalize(NORMAL);
	float fres = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 3.0);
	vec3 r = reflect(-VIEW, n);
	float larga = smoothstep(0.26, 0.34, r.x) * (1.0 - smoothstep(0.50, 0.60, r.x));
	float fina = smoothstep(-0.66, -0.62, r.x) * (1.0 - smoothstep(-0.57, -0.53, r.x));
	float ceu = smoothstep(0.82, 0.97, r.y);
	float brilho = clamp(larga * 0.85 + fina * 0.55 + ceu * 0.7, 0.0, 1.0);
	ALBEDO = tinta.rgb * 0.08;
	ROUGHNESS = 0.06;
	SPECULAR = 0.6;
	EMISSION = vec3(0.95, 0.97, 1.0) * brilho * 0.9 + tinta.rgb * fres * 0.30;
	ALPHA = clamp(mix(alfa_centro, alfa_borda, fres) + brilho * 0.55, 0.0, 1.0);
}
"""

## Erva. A cor de vertice nao e cor: r = tom (escuro..claro), g = tipo (0 calice,
## 0,5 folha, 1 pistilo), b = oclusao, a = quanto de tricoma. A paleta vem do
## material, e e isso que faz a Super ser o mesmo cacho com outra luz.
##
## O tricoma e um ponto claro por celula de 1/35 da cabeca. Quando a celula fica
## menor que o pixel (a vitrine desenha o pote a 128 px) o ponto vira media, e
## nao ruido: senao a erva cintila girando.
const SH_ERVA := """
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform vec4 calice_escuro : source_color;
uniform vec4 calice_claro : source_color;
uniform vec4 folha : source_color;
uniform vec4 pistilo_a : source_color;
uniform vec4 pistilo_b : source_color;
uniform vec4 geada : source_color = vec4(0.9, 0.93, 0.86, 1.0);
uniform float escala_ponto = 35.0;
uniform float escala_calice = 7.0;
// Luz propria (a Vagalume): acende pistilo, tricoma e o topo de cada calice.
// Em zero, a erva e a de sempre.
uniform vec4 luz : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float luz_forca = 0.0;

varying vec3 p_obj;
varying vec3 n_obj;

void vertex() {
	p_obj = VERTEX;
	n_obj = NORMAL;
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.11, 0.17, 0.23));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

vec3 hash33(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)),
		dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

// Celula de Worley: distancia ao centro do calice mais perto (xyz) e o vetor
// do centro ate o ponto (w..): e com ele que cada celula vira um domo.
vec4 celula(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float melhor = 8.0;
	vec3 vet = vec3(0.0);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 r = g + hash33(i + g) - f;
				float d = dot(r, r);
				if (d < melhor) {
					melhor = d;
					vet = r;
				}
			}
		}
	}
	return vec4(sqrt(melhor), -vet);
}

void fragment() {
	float tom = COLOR.r;
	float tipo = COLOR.g;
	float ao = COLOR.b;
	float gd = COLOR.a;
	float e_folha = step(0.3, tipo) * (1.0 - step(0.7, tipo));
	float e_pistilo = step(0.7, tipo);
	// Calice por pixel: a malha da cabeca tem 320 triangulos e so aguenta o
	// calombo grande; o calice miudo, o vinco escuro entre eles e o brilho de
	// cada domo saem daqui. Fica fora do pistilo, da folha e do miolo do pote.
	float e_calice = (1.0 - e_folha) * (1.0 - e_pistilo) * smoothstep(0.3, 0.4, ao);
	vec4 cel = celula(p_obj * escala_calice);
	float domo = 1.0 - smoothstep(0.2, 0.72, cel.x);
	vec3 n0 = normalize(n_obj);
	vec3 lado = cel.yzw - n0 * dot(cel.yzw, n0);
	vec3 n_b = normalize(n0 + lado * 1.6 * e_calice);
	vec3 n_v = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(n_b, 0.0)).xyz);
	NORMAL = normalize(mix(NORMAL, n_v, e_calice));
	ao *= mix(1.0, mix(0.5, 1.0, domo), e_calice);
	gd *= mix(1.0, mix(0.35, 1.0, domo), e_calice);
	vec3 c = mix(calice_escuro.rgb, calice_claro.rgb, clamp(tom + 0.12 * (domo - 0.5) * e_calice, 0.0, 1.0));
	c = mix(c, folha.rgb * (0.6 + 0.7 * tom), e_folha);
	c = mix(c, mix(pistilo_a.rgb, pistilo_b.rgb, tom), e_pistilo);
	float h = hash3(floor(p_obj * escala_ponto));
	float px = length(fwidth(p_obj)) * escala_ponto;
	float nitido = 1.0 - smoothstep(0.6, 1.6, px);
	float ponto = step(1.0 - 0.45 * gd, h) * nitido * (1.0 - e_pistilo);
	// A geada de fundo vale sempre, e o ponto so onde ele cabe no pixel.
	float media = gd * 0.3 * (1.0 - e_pistilo);
	c = mix(c, geada.rgb, clamp(ponto * 0.55 + media, 0.0, 1.0));
	c *= ao;
	vec3 n = normalize(NORMAL);
	float fres = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = c;
	ROUGHNESS = mix(0.8, 0.45, gd);
	SPECULAR = 0.5;
	EMISSION = geada.rgb * ao * (ponto * (0.2 + 0.5 * fres) + gd * fres * 0.08);
	EMISSION += luz.rgb * luz_forca * (e_pistilo * 1.6
		+ e_calice * ao * (0.1 * domo + 1.4 * ponto + 0.07 * gd));
}
"""


static func _shader(chave: String, codigo: String) -> Shader:
	if not _cache.has(chave):
		var sh := Shader.new()
		sh.code = codigo
		_cache[chave] = sh
	return _cache[chave] as Shader


## `verso` com alfa > 0 liga as duas faces, e a de tras sai nessa cor (o lado de
## dentro do papel do envelope).
static func _mat_estudio(tex: Texture2D, cor: Color, reflexo: float, rug: float,
		metal: float = 0.0, cor_vertice: bool = false,
		verso: Color = Color(0, 0, 0, 0)) -> ShaderMaterial:
	var dupla := verso.a > 0.0
	var m := ShaderMaterial.new()
	m.shader = _shader("sh_estudio_%s" % dupla,
		SH_ESTUDIO % ("cull_disabled" if dupla else "cull_back"))
	if tex != null:
		m.set_shader_parameter(&"textura", tex)
	m.set_shader_parameter(&"cor", cor)
	m.set_shader_parameter(&"reflexo", reflexo)
	m.set_shader_parameter(&"rugosidade", rug)
	m.set_shader_parameter(&"metal", metal)
	m.set_shader_parameter(&"usa_cor_vertice", cor_vertice)
	m.set_shader_parameter(&"usa_verso", dupla)
	m.set_shader_parameter(&"cor_verso", verso)
	return m


static func _mat_vidro() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("sh_vidro", SH_VIDRO)
	return m


static func _mat_erva(roxa: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("sh_erva", SH_ERVA)
	if roxa:
		# A do andar 10: calice roxo-escuro, folha quase preta, geada mais
		# branca. O pistilo continua laranja — e o que diz "e erva" antes de
		# dizer "e roxa".
		m.set_shader_parameter(&"calice_escuro", Color("2a1436"))
		m.set_shader_parameter(&"calice_claro", Color("9a66c4"))
		m.set_shader_parameter(&"folha", Color("3a3048"))
		m.set_shader_parameter(&"pistilo_a", Color("c8602e"))
		m.set_shader_parameter(&"pistilo_b", Color("f0a456"))
		m.set_shader_parameter(&"geada", Color("f2eaf6"))
	else:
		m.set_shader_parameter(&"calice_escuro", Color("2a461b"))
		m.set_shader_parameter(&"calice_claro", Color("9cc25a"))
		m.set_shader_parameter(&"folha", Color("3a5a26"))
		m.set_shader_parameter(&"pistilo_a", Color("b8551f"))
		m.set_shader_parameter(&"pistilo_b", Color("e39a44"))
		m.set_shader_parameter(&"geada", Color("e8eedc"))
	return m


static func _rotulos() -> Texture2D:
	if not _cache.has("rotulos"):
		_cache["rotulos"] = load(ROTULOS) if ResourceLoader.exists(ROTULOS) else null
	return _cache["rotulos"] as Texture2D


# --- ferramentas de malha -----------------------------------------------------

static func _em_cache(chave: String, montar: Callable) -> ArrayMesh:
	if not _cache.has(chave):
		var m: Malha = montar.call()
		_cache[chave] = m.malha()
	return _cache[chave] as ArrayMesh


static func _instancia(pai: Node3D, mesh: Mesh, mat: Material,
		xf: Transform3D = Transform3D.IDENTITY, sombra: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	if not sombra:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	return mi


## Ponto do atlas: `t` de 0 a 1 dentro da regiao, com 3 px de margem para o
## mipmap nao puxar a regiao vizinha.
static func _uv(reg: Rect2, t: Vector2) -> Vector2:
	var margem := Vector2(3.0, 3.0)
	return (reg.position + margem
		+ t.clamp(Vector2.ZERO, Vector2.ONE) * (reg.size - margem * 2.0)) / Vector2(ATLAS, ATLAS_ALTO)


static func _sgnpow(x: float, e: float) -> float:
	return signf(x) * pow(absf(x), e)


## Ruido barato e deterministico (soma de senos torcidos), de -1 a 1.
static func _ruido(p: Vector3) -> float:
	return (sin(p.x * 1.7 + sin(p.y * 2.3 + p.z * 1.1) * 1.3) * 0.5
		+ sin(p.y * 3.1 + sin(p.z * 2.9 + p.x * 0.7) * 1.1) * 0.3
		+ sin(p.z * 5.3 + sin(p.x * 4.1 + p.y * 1.9)) * 0.2)


## Base com o eixo Y em `eixo_y`.
static func _base_de(eixo_y: Vector3) -> Basis:
	var y := eixo_y.normalized()
	var ref: Vector3 = Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.BACK
	var z := ref.cross(y).normalized()
	var x := y.cross(z).normalized()
	return Basis(x, y, z)


## Catmull-Rom pelos pontos de controle, `passos` por trecho.
static func _curva(ctrl: PackedVector3Array, passos: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := ctrl.size()
	for i in n - 1:
		var p0 := ctrl[maxi(i - 1, 0)]
		var p1 := ctrl[i]
		var p2 := ctrl[i + 1]
		var p3 := ctrl[mini(i + 2, n - 1)]
		for s in passos:
			var t := float(s) / float(passos)
			out.append(0.5 * ((2.0 * p1) + (p2 - p0) * t
				+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	out.append(ctrl[n - 1])
	return out


static func _icosfera(sub: int) -> Array:
	var chave := "ico_%d" % sub
	if _cache.has(chave):
		return _cache[chave] as Array
	var t := (1.0 + sqrt(5.0)) * 0.5
	var vs: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	for i in vs.size():
		vs[i] = vs[i].normalized()
	var fs := PackedInt32Array([0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11,
		1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8, 3, 9, 4, 3, 4, 2, 3, 2, 6,
		3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1])
	for _s in sub:
		var meio: Dictionary = {}
		var novo := PackedInt32Array()
		for f in range(0, fs.size(), 3):
			var tri := [fs[f], fs[f + 1], fs[f + 2]]
			var m3: Array[int] = []
			for k in 3:
				var a: int = tri[k]
				var b: int = tri[(k + 1) % 3]
				var chave_m := mini(a, b) * 100000 + maxi(a, b)
				if not meio.has(chave_m):
					vs.append(((vs[a] + vs[b]) * 0.5).normalized())
					meio[chave_m] = vs.size() - 1
				m3.append(meio[chave_m] as int)
			novo.append_array(PackedInt32Array([tri[0], m3[0], m3[2], tri[1], m3[1], m3[0],
				tri[2], m3[2], m3[1], m3[0], m3[1], m3[2]]))
		fs = novo
	var r := [PackedVector3Array(vs), fs]
	_cache[chave] = r
	return r


## Esfera deformada. `forma` leva o ponto da esfera unitaria ao ponto local;
## `pinta(q, p, n)` recebe o ponto da esfera, o final e a normal. A normal sai
## das faces JA deformadas, e nao da esfera: gota pontuda com normal de bola
## brilha no lugar errado.
static func _bolha(m: Malha, xf: Transform3D, sub: int, forma: Callable,
		pinta: Callable) -> void:
	var ico := _icosfera(sub)
	var base: PackedVector3Array = ico[0]
	var fs: PackedInt32Array = ico[1]
	var pos := PackedVector3Array()
	pos.resize(base.size())
	for i in base.size():
		var q: Vector3 = forma.call(base[i])
		pos[i] = xf * q
	var nor := PackedVector3Array()
	nor.resize(base.size())
	for f in range(0, fs.size(), 3):
		var a := fs[f]
		var b := fs[f + 1]
		var c := fs[f + 2]
		var fn := (pos[b] - pos[a]).cross(pos[c] - pos[a])
		if fn.dot(xf.basis * (base[a] + base[b] + base[c])) < 0.0:
			fn = -fn
		nor[a] += fn
		nor[b] += fn
		nor[c] += fn
	var ini := m.v.size()
	for i in base.size():
		var nn := nor[i].normalized()
		var c: Color = pinta.call(base[i], pos[i], nn)
		m.ponto(pos[i], nn, c)
	for f in range(0, fs.size(), 3):
		m.tri(ini + fs[f], ini + fs[f + 1], ini + fs[f + 2])


## Solido de revolucao em torno de Y. `perfil` (raio, altura) vai de baixo para
## cima e de fora para dentro, como se desenha o corte de um pote; a normal sai a
## direita do sentido do perfil, que nessa convencao e "para fora". Ponto
## repetido vira quina viva. `serrilha` = (amplitude, dentes, y0, y1) enruga o
## raio entre y0 e y1 (a tampa de rosca).
static func _revolver(m: Malha, perfil: PackedVector2Array, lados: int, xf: Transform3D,
		pinta: Callable, uv_de: Callable = Callable(),
		serrilha: Vector4 = Vector4.ZERO) -> void:
	var np := perfil.size()
	var seg: Array[Vector2] = []
	for i in np - 1:
		var t := perfil[i + 1] - perfil[i]
		seg.append(Vector2(t.y, -t.x).normalized() if t.length() > 1e-6 else Vector2.ZERO)
	var comp := PackedFloat32Array([0.0])
	for i in np - 1:
		comp.append(comp[i] + perfil[i].distance_to(perfil[i + 1]))
	var total := maxf(comp[np - 1], 1e-6)
	var base := m.v.size()
	for i in np:
		var ant: Vector2 = seg[i - 1] if i > 0 else Vector2.ZERO
		var pro: Vector2 = seg[i] if i < np - 1 else Vector2.ZERO
		var n2 := (ant + pro).normalized()
		var p := perfil[i]
		var fv := comp[i] / total
		for k in lados + 1:
			var a := TAU * float(k) / float(lados)
			var ca := cos(a)
			var sa := sin(a)
			var r := p.x
			var inclina := 0.0
			if serrilha.x > 0.0 and p.y >= serrilha.z and p.y <= serrilha.w:
				r *= 1.0 + serrilha.x * (0.5 + 0.5 * cos(serrilha.y * a))
				inclina = serrilha.x * 0.5 * serrilha.y * sin(serrilha.y * a)
			var pos := Vector3(r * ca, p.y, r * sa)
			var nor := Vector3(n2.x * ca, n2.y, n2.x * sa) + Vector3(-sa, 0.0, ca) * n2.x * inclina
			var fu := float(k) / float(lados)
			var t: Vector2 = uv_de.call(fu, fv, pos) if uv_de.is_valid() else Vector2(fu, fv)
			var c: Color = pinta.call(pos, nor, fu, fv) if pinta.is_valid() else Color.WHITE
			m.ponto(xf * pos, (xf.basis * nor).normalized(), c, t)
	for i in np - 1:
		if perfil[i].distance_to(perfil[i + 1]) < 1e-6:
			continue
		for k in lados:
			var a0 := base + i * (lados + 1) + k
			m.quad(a0, a0 + 1, a0 + lados + 2, a0 + lados + 1)


## Tubo varrido pelos pontos. `raio(s)` e `pinta(s)` recebem s de 0 a 1 ao longo
## do tubo. `achatar` < 1 faz fita (a alca do regador). O referencial e levado de
## ponto a ponto por transporte paralelo, e nao pelo "cima" do mundo: com o
## "cima" fixo a alca torce onde passa na vertical.
static func _tubo(m: Malha, pts: PackedVector3Array, raio: Callable, lados: int,
		pinta: Callable, achatar: float = 1.0, fechado: bool = false,
		tampas: bool = true) -> void:
	var np := pts.size()
	var tang := PackedVector3Array()
	for i in np:
		var a: Vector3 = pts[(i - 1 + np) % np] if fechado else pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[(i + 1) % np] if fechado else pts[mini(i + 1, np - 1)]
		tang.append((b - a).normalized())
	var nrm := tang[0].cross(Vector3.UP)
	if nrm.length() < 0.05:
		nrm = tang[0].cross(Vector3.RIGHT)
	nrm = nrm.normalized()
	var base := m.v.size()
	var aneis := np + (1 if fechado else 0)
	for i in aneis:
		var ii := i % np
		var t := tang[ii]
		if fechado:
			nrm = t.cross(Vector3.UP).normalized()
		elif i > 0:
			var t0 := tang[i - 1]
			var eixo := t0.cross(t)
			if eixo.length() > 1e-6:
				nrm = nrm.rotated(eixo.normalized(), t0.angle_to(t))
			nrm = (nrm - t * nrm.dot(t)).normalized()
		var bin := t.cross(nrm)
		var s := float(i) / float(aneis - 1)
		var r: float = raio.call(s)
		var c: Color = pinta.call(s)
		for k in lados + 1:
			var a := TAU * float(k) / float(lados)
			var off := nrm * cos(a) * r + bin * sin(a) * r * achatar
			var nor := nrm * cos(a) * achatar + bin * sin(a)
			m.ponto(pts[ii] + off, nor, c, Vector2(float(k) / float(lados), s))
	for i in aneis - 1:
		for k in lados:
			var a0 := base + i * (lados + 1) + k
			m.quad(a0, a0 + 1, a0 + lados + 2, a0 + lados + 1)
	if tampas and not fechado:
		for ponta in 2:
			var anel := 0 if ponta == 0 else aneis - 1
			var nor: Vector3 = -tang[0] if ponta == 0 else tang[np - 1]
			var primeiro := base + anel * (lados + 1)
			var onde: Vector3 = pts[0] if ponta == 0 else pts[np - 1]
			var centro := m.ponto(onde, nor, m.cor[primeiro])
			var ini := m.v.size()
			for k in lados:
				m.ponto(m.v[primeiro + k], nor, m.cor[primeiro + k])
			for k in lados:
				m.tri(centro, ini + k, ini + (k + 1) % lados)


## Superficie em grade: `pos[i][j]` e a linha i, coluna j. A normal sai da
## diferenca dos vizinhos e vira para o lado de `fora.call(p)`; linha colapsada
## num ponto (fundo do saco, ponta do grao) fica com a normal de `fora`. Com
## `emenda`, a ultima coluna repete a primeira (volta fechada com costura de uv).
static func _grade(m: Malha, pos: Array[PackedVector3Array], uvs: Array[PackedVector2Array],
		cores: Array[PackedColorArray], fora: Callable, emenda: bool) -> void:
	var linhas := pos.size()
	var cols := pos[0].size()
	var base := m.v.size()
	for i in linhas:
		var il := maxi(i - 1, 0)
		var ir := mini(i + 1, linhas - 1)
		for j in cols:
			var jl := j - 1
			var jr := j + 1
			if emenda:
				if jl < 0:
					jl = cols - 2
				if jr > cols - 1:
					jr = 1
			else:
				jl = maxi(jl, 0)
				jr = mini(jr, cols - 1)
			var p: Vector3 = pos[i][j]
			var du: Vector3 = pos[i][jr] - pos[i][jl]
			var dv: Vector3 = pos[ir][j] - pos[il][j]
			var nor := du.cross(dv)
			var ref: Vector3 = fora.call(p)
			if nor.length_squared() < 1e-12:
				nor = ref
			elif nor.dot(ref) < 0.0:
				nor = -nor
			m.ponto(p, nor, cores[i][j], uvs[i][j])
	for i in linhas - 1:
		for j in cols - 1:
			var a := base + i * cols + j
			m.quad(a, a + 1, a + cols + 1, a + cols)


# --- terra ----------------------------------------------------------------------

## Contorno do saco na altura dada: retangulo de canto redondo (superelipse de
## grau 5), com u = 0 no canto esquerdo visto de frente e 0,25 no meio da frente.
## u e fracao do PERIMETRO, e nao angulo: pelo angulo a superelipse corre no meio
## da face e se amontoa nos cantos, e o "TERRA VEGETAL" saia com o V do tamanho
## de tres letras.
static func _saco_contorno(u: float, sw: float, sd: float) -> Vector3:
	var a := _angulo_saco(u)
	return Vector3(-SACO_W * sw * _sgnpow(cos(a), 0.4), 0.0, SACO_D * sd * _sgnpow(sin(a), 0.4))


static func _angulo_saco(u: float) -> float:
	var amostras := 1440
	if not _cache.has("saco_perimetro"):
		var acum := PackedFloat32Array([0.0])
		var ant := Vector2(-SACO_W, 0.0)
		for i in range(1, amostras + 1):
			var a := TAU * float(i) / float(amostras)
			var p := Vector2(-SACO_W * _sgnpow(cos(a), 0.4), SACO_D * _sgnpow(sin(a), 0.4))
			acum.append(acum[i - 1] + p.distance_to(ant))
			ant = p
		var total := acum[amostras]
		for i in acum.size():
			acum[i] /= total
		_cache["saco_perimetro"] = acum
	var tab: PackedFloat32Array = _cache["saco_perimetro"]
	var alvo := clampf(u, 0.0, 1.0)
	var i := clampi(tab.bsearch(alvo), 1, amostras)
	var f := (alvo - tab[i - 1]) / maxf(tab[i] - tab[i - 1], 1e-9)
	return TAU * (float(i - 1) + clampf(f, 0.0, 1.0)) / float(amostras)


## Largura e profundidade relativas do saco na altura v (0 fundo, 1 boca). A
## terra pesa embaixo e estufa o meio; a boca junta.
static func _saco_escala(v: float) -> Vector2:
	var sw := 1.0 + 0.045 * sin(PI * pow(v, 0.7)) - 0.05 * smoothstep(0.82, 1.0, v)
	var sd := 1.0 + 0.12 * sin(PI * pow(v, 0.6)) - 0.16 * smoothstep(0.78, 1.0, v)
	return Vector2(sw, sd)


static func _altura_terra(p: Vector3, s: float) -> float:
	return (0.282 + 0.07 * (1.0 - s * s)
		+ 0.012 * _ruido(Vector3(p.x * 22.0, 1.3, p.z * 22.0))
		+ 0.005 * _ruido(Vector3(p.x * 61.0, 0.2, p.z * 57.0)))


static func _montar_saco() -> Malha:
	var m := Malha.new()
	var na := 72
	# (altura, escala da largura, escala da profundidade, v da textura). As
	# quatro primeiras sao o fundo: o saco em pe assenta numa sanfona chata.
	var linhas: Array[Vector4] = [
		Vector4(-0.55, 0.0, 0.0, 0.0), Vector4(-0.55, 0.8, 0.66, 0.0),
		Vector4(-0.543, 0.93, 0.86, 0.0), Vector4(-0.527, 0.978, 0.95, 0.0),
	]
	var nv := 24
	for i in nv + 1:
		var v := float(i) / float(nv)
		var e := _saco_escala(v)
		linhas.append(Vector4(-0.515 + v * 0.815, e.x, e.y, v))
	var pos: Array[PackedVector3Array] = []
	var uvs: Array[PackedVector2Array] = []
	var cores: Array[PackedColorArray] = []
	for l in linhas:
		var lp := PackedVector3Array()
		var lu := PackedVector2Array()
		var lc := PackedColorArray()
		var v := l.w
		for j in na + 1:
			var u := float(j) / float(na)
			var p := _saco_contorno(u, l.y, l.z)
			p.y = l.x
			# Amassado: calombo largo em todo o saco, vinco horizontal perto da
			# boca (onde o plastico foi enrolado) e vinco diagonal nos cantos.
			var canto := pow(absf(sin(2.0 * TAU * u)), 6.0)
			var amassa := (0.007 * _ruido(Vector3(u * 14.0, v * 9.0, 3.0))
				+ 0.011 * smoothstep(0.72, 1.0, v) * sin(v * 95.0 + 3.0 * sin(u * TAU * 3.0))
				+ 0.006 * canto * sin(v * 34.0 + u * 44.0))
			amassa *= smoothstep(-0.535, -0.45, l.x)
			var radial := Vector3(p.x / SACO_W, 0.0, p.z / SACO_D)
			if radial.length() > 1e-4:
				p += radial.normalized() * amassa
			lp.append(p)
			lu.append(_uv(REG_SACO, Vector2(u, 1.0 - v)))
			lc.append(Color.WHITE)
		pos.append(lp)
		uvs.append(lu)
		cores.append(lc)
	var fora := func(p: Vector3) -> Vector3:
		return Vector3.DOWN if p.y < -0.545 else Vector3(p.x, 0.0, p.z)
	_grade(m, pos, uvs, cores, fora, true)
	return m


## Terra na boca do saco, com o rolo do plastico virado para fora em volta.
static func _montar_boca() -> Malha:
	var m := Malha.new()
	var na := 72
	var ns := 10
	var boca := _saco_escala(1.0)
	var pos: Array[PackedVector3Array] = []
	var uvs: Array[PackedVector2Array] = []
	var cores: Array[PackedColorArray] = []
	for i in ns + 1:
		var s := float(i) / float(ns)
		var lp := PackedVector3Array()
		var lu := PackedVector2Array()
		var lc := PackedColorArray()
		for j in na + 1:
			var u := float(j) / float(na)
			var p := _saco_contorno(u, boca.x * s * 0.995, boca.y * s * 0.995)
			p.y = _altura_terra(p, s)
			lp.append(p)
			lu.append(_uv(REG_TERRA, Vector2(0.5 + p.x / 0.66, 0.5 + p.z / 0.42)))
			lc.append(Color.WHITE)
		pos.append(lp)
		uvs.append(lu)
		cores.append(lc)
	var cima := func(_p: Vector3) -> Vector3: return Vector3.UP
	_grade(m, pos, uvs, cores, cima, true)
	return m


static func _montar_rolo_e_graos() -> Malha:
	var m := Malha.new()
	var boca := _saco_escala(1.0)
	# O rolo: o plastico dobrado para fora na boca, mostrando o avesso escuro.
	var anel := PackedVector3Array()
	var na := 72
	for j in na:
		var u := float(j) / float(na)
		var p := _saco_contorno(u, boca.x, boca.y)
		var radial := Vector3(p.x / SACO_W, 0.0, p.z / SACO_D).normalized()
		anel.append(p + radial * 0.012 + Vector3(0.0, 0.304, 0.0))
	var raio_rolo := func(_s: float) -> float: return 0.022
	var cor_rolo := func(_s: float) -> Color: return Color("2b2a26")
	_tubo(m, anel, raio_rolo, 8, cor_rolo, 1.0, true, false)
	# Perlita, torrao e lasca de casca por cima da terra. A perlita e o que diz
	# "substrato" e nao "lama": sem os pontos brancos a boca e uma mancha marrom.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in 46:
		var s := sqrt(rng.randf()) * 0.9
		var u := rng.randf()
		var p := _saco_contorno(u, boca.x * s, boca.y * s)
		p.y = _altura_terra(p, s)
		var tipo := 0 if i < 30 else (1 if i < 40 else 2)
		var tam := rng.randf_range(0.011, 0.02)
		var escala := Vector3(tam, tam * 0.8, tam)
		var cor_g := Color("ebe8de")
		var sub := 0
		if tipo == 1:
			# Torrao chato e fosco: redondo e liso ele le como feijao.
			tam = rng.randf_range(0.018, 0.03)
			escala = Vector3(tam, tam * 0.45, tam * 0.85)
			cor_g = Color("4a3526")
			sub = 1
		elif tipo == 2:
			escala = Vector3(0.035, 0.008, 0.012)
			cor_g = Color("7a5230")
		var b := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		var xf := Transform3D(b * Basis.from_scale(escala), p - Vector3(0.0, escala.y * 0.35, 0.0))
		var semente := float(i)
		var forma := func(q: Vector3) -> Vector3:
			return q * (1.0 + 0.25 * _ruido(q * 2.5 + Vector3(semente, 0.0, 0.0)))
		var pinta := func(_q: Vector3, _p: Vector3, _n: Vector3) -> Color: return cor_g
		_bolha(m, xf, sub, forma, pinta)
	return m


static func _terra(pai: Node3D) -> void:
	# Saco de boca aberta, com a dobra enrolada e a terra aparecendo. A boca
	# aberta e a silhueta inteira: saco fechado e um retangulo.
	var tex := _rotulos()
	_instancia(pai, _em_cache("terra_saco", func() -> Malha: return _montar_saco()),
		_mat_estudio(tex, Color.WHITE, 0.55, 0.32))
	_instancia(pai, _em_cache("terra_boca", func() -> Malha: return _montar_boca()),
		_mat_estudio(tex, Color.WHITE, 0.05, 0.95))
	_instancia(pai, _em_cache("terra_rolo", func() -> Malha: return _montar_rolo_e_graos()),
		_mat_estudio(null, Color.WHITE, 0.18, 0.75, 0.0, true))


# --- semente --------------------------------------------------------------------

## Grao de cannabis: ovoide com uma ponta mais fina, a quilha em volta (onde as
## duas metades se encontram) e o rajado escuro de "tigre" que o nome do item
## promete ("malhada").
static func _montar_grao(variante: int) -> Malha:
	var m := Malha.new()
	var lat := 12
	var lon := 16
	var sv := float(variante) * 5.3
	var pos: Array[PackedVector3Array] = []
	var uvs: Array[PackedVector2Array] = []
	var cores: Array[PackedColorArray] = []
	for i in lat + 1:
		var t := PI * float(i) / float(lat)
		var ao_longo := -cos(t) * 0.5
		var perfil := pow(sin(t), 0.85) * (1.0 + 0.16 * cos(t))
		var lp := PackedVector3Array()
		var lu := PackedVector2Array()
		var lc := PackedColorArray()
		for k in lon + 1:
			var phi := TAU * float(k) / float(lon)
			var quilha := exp(-pow(sin(phi), 2.0) * 22.0)
			var p := Vector3(ao_longo, sin(phi) * 0.30 * perfil,
				cos(phi) * 0.36 * perfil * (1.0 + 0.1 * quilha))
			lp.append(p)
			lu.append(Vector2(float(k) / float(lon), float(i) / float(lat)))
			var rajado := smoothstep(0.0, 0.35,
				_ruido(Vector3(ao_longo * 9.0 + sv, phi * 1.6, sv * 0.3)))
			var c := Color("ab9674").lerp(Color("2a1d14"), rajado * 0.92)
			# A ponta de onde o grao se soltou e clara, e a quilha e mais escura.
			c = c.lerp(Color("cdb88e"), smoothstep(0.36, 0.5, -ao_longo) * 0.8)
			c = c.lerp(Color("2e2218"), quilha * 0.35)
			lc.append(c)
		pos.append(lp)
		uvs.append(lu)
		cores.append(lc)
	var fora := func(p: Vector3) -> Vector3: return p
	_grade(m, pos, uvs, cores, fora, true)
	return m


static func _malha_grao(variante: int) -> ArrayMesh:
	return _em_cache("grao_%d" % variante, func() -> Malha: return _montar_grao(variante))


## Envelope de papel pardo: frente mais baixa que o verso (e a boca), verso com a
## aba aberta em pe. As duas faces sao grade estufada — papel com semente dentro
## nao e chapa.
static func _montar_envelope() -> Malha:
	var m := Malha.new()
	var larg := 0.23
	var alt := 0.31
	var topo_frente := 0.25
	var cols := 14
	var linhas := 18
	for face in 2:
		var pos: Array[PackedVector3Array] = []
		var uvs: Array[PackedVector2Array] = []
		var cores: Array[PackedColorArray] = []
		var topo := topo_frente if face == 0 else alt
		for i in linhas + 1:
			var y := lerpf(-alt, topo, float(i) / float(linhas))
			var sy := (y + alt) / (2.0 * alt)
			var lp := PackedVector3Array()
			var lu := PackedVector2Array()
			var lc := PackedColorArray()
			for j in cols + 1:
				var x := lerpf(-larg, larg, float(j) / float(cols))
				var sx := x / larg
				var lado := 1.0 - pow(absf(sx), 5.0)
				var fundo := smoothstep(0.0, 0.16, sy)
				var enruga := 0.0025 * _ruido(Vector3(x * 34.0, y * 30.0, float(face) * 7.0))
				var z := 0.0
				if face == 0:
					z = 0.042 * lado * fundo + 0.02 * pow(sy, 3.0) * (1.0 - pow(absf(sx), 3.0)) + enruga
				else:
					z = -0.03 * lado * fundo - enruga
				lp.append(Vector3(x, y, z))
				var tx := (x + larg) / (2.0 * larg)
				var ty := (alt - y) / (2.0 * alt)
				if face == 0:
					lu.append(_uv(REG_ENV_FRENTE, Vector2(tx, ty)))
				else:
					lu.append(_uv(REG_ENV_VERSO, Vector2(1.0 - tx, ty)))
				lc.append(Color.WHITE)
			pos.append(lp)
			uvs.append(lu)
			cores.append(lc)
		_papel(m, pos, uvs, Vector3(0.0, 0.0, 1.0 if face == 0 else -1.0))
	# A aba: sai do topo do verso, inclinada 35 graus para tras, estreitando.
	var pos_a: Array[PackedVector3Array] = []
	var uvs_a: Array[PackedVector2Array] = []
	var cores_a: Array[PackedColorArray] = []
	var inclina := deg_to_rad(35.0)
	for i in 7:
		var s := float(i) / 6.0
		var lp := PackedVector3Array()
		var lu := PackedVector2Array()
		var lc := PackedColorArray()
		for j in cols + 1:
			var tx := float(j) / float(cols)
			var x := lerpf(-larg, larg, tx) * (1.0 - 0.32 * s * s)
			lp.append(Vector3(x, alt + 0.13 * s * cos(inclina), -0.13 * s * sin(inclina)
				+ 0.004 * sin(tx * PI) * s))
			lu.append(_uv(REG_KRAFT, Vector2(tx, s)))
			lc.append(Color.WHITE)
		pos_a.append(lp)
		uvs_a.append(lu)
		cores_a.append(lc)
	_papel(m, pos_a, uvs_a, Vector3(0.0, sin(inclina), cos(inclina)))
	return m


## Folha de papel com as duas faces: a de fora com o impresso, a de dentro kraft
## liso e mais escuro (o avesso que aparece pela boca do envelope). Duas grades de
## verdade, e nao cull_disabled: com uma face so, a aba vista por tras saia preta.
static func _papel(m: Malha, pos: Array[PackedVector3Array], uvs: Array[PackedVector2Array],
		fora: Vector3) -> void:
	var cores: Array[PackedColorArray] = []
	var pos_d: Array[PackedVector3Array] = []
	var uvs_d: Array[PackedVector2Array] = []
	var cores_d: Array[PackedColorArray] = []
	var linhas := pos.size()
	for i in linhas:
		var c := PackedColorArray()
		var pd := PackedVector3Array()
		var ud := PackedVector2Array()
		var cd := PackedColorArray()
		var cols := pos[i].size()
		for j in cols:
			c.append(Color.WHITE)
			pd.append(pos[i][j] - fora * 0.0025)
			ud.append(_uv(REG_KRAFT, Vector2(float(j) / float(cols - 1), float(i) / float(linhas - 1))))
			cd.append(Color(0.62, 0.56, 0.5))
		cores.append(c)
		pos_d.append(pd)
		uvs_d.append(ud)
		cores_d.append(cd)
	var f_fora := func(_p: Vector3) -> Vector3: return fora
	var f_dentro := func(_p: Vector3) -> Vector3: return -fora
	_grade(m, pos, uvs, cores, f_fora, false)
	_grade(m, pos_d, uvs_d, cores_d, f_dentro, false)


static func _semente(pai: Node3D) -> void:
	# Envelope de papel pardo em pe, de aba aberta, com grao na boca e um monte
	# derramado na frente. O grao e grande de proposito (quase 9 cm num envelope
	# de 60): no tamanho real ele some, e o icone sem grao le como bilhete.
	var env := Node3D.new()
	env.name = "Envelope"
	env.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-14.0), deg_to_rad(-8.0), 0.0))
		* Basis.from_scale(Vector3.ONE * 1.12), Vector3(-0.03, 0.0, -0.06))
	pai.add_child(env)
	_instancia(env, _em_cache("envelope", func() -> Malha: return _montar_envelope()),
		_mat_estudio(_rotulos(), Color.WHITE, 0.12, 0.8, 0.0, true))
	var mat_grao := _mat_estudio(null, Color.WHITE, 0.28, 0.45, 0.0, true)
	var tam := 0.085
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# Os da boca sao filhos do envelope (e herdam a escala dele); os do monte, nao.
	# Tres na boca, entre a frente e o verso.
	for i in 3:
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU,
			deg_to_rad(70.0) + rng.randf_range(-0.4, 0.4)))
		_instancia(env, _malha_grao(i % 3), mat_grao,
			Transform3D(b * Basis.from_scale(Vector3.ONE * tam),
				Vector3(-0.07 + float(i) * 0.07, 0.262 + rng.randf_range(-0.01, 0.012), 0.014)))
	# O monte derramado. Duas camadas: cinco no chao, dois por cima.
	# Encostado no pe do envelope: afastado, de lado ele lia como outro objeto.
	var chao := -0.36
	var monte := [
		Vector3(-0.12, 0.0, 0.08), Vector3(-0.02, 0.0, 0.11), Vector3(0.08, 0.0, 0.07),
		Vector3(0.17, 0.0, 0.12), Vector3(0.04, 0.0, 0.19), Vector3(-0.09, 0.0, 0.17),
		Vector3(-0.01, 1.0, 0.12), Vector3(0.08, 1.0, 0.13),
	]
	for i in monte.size():
		var q: Vector3 = monte[i]
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * TAU,
			rng.randf_range(-0.25, 0.25)))
		var y := chao + tam * 0.35 + q.y * tam * 0.5
		_instancia(pai, _malha_grao(i % 3), mat_grao,
			Transform3D(b * Basis.from_scale(Vector3.ONE * tam * 1.12), Vector3(q.x, y, q.z)))


# --- regador --------------------------------------------------------------------

## Tinta verde de esmalte, com o metal aparecendo onde a mao e o chao gastam:
## os frisos, o pe, o labio da boca.
static func _cor_regador(p: Vector3, forte: float) -> Color:
	var gasto := _ruido(p * 38.0) * 0.5 + 0.5
	var verde := Color("2c6440").lerp(Color("3d7a4e"), clampf((p.y + 0.5) * 0.6, 0.0, 1.0))
	verde = verde.darkened(0.08 * (1.0 - gasto))
	# Abaixo de 0,3 nao gasta nada: o ruido tem veio vertical, e desgaste solto
	# no corpo virava listra de cima a baixo.
	if forte >= 0.3 and gasto > 1.15 - 0.6 * forte:
		return Color(Color("8e918a"), 0.0)
	return verde


static func _montar_regador() -> Malha:
	var m := Malha.new()
	var centro := Transform3D(Basis.IDENTITY, Vector3(-0.13, 0.0, 0.0))
	# Os pontos colados antes e depois de cada friso (a 8 mm) existem so para a
	# cor: sem eles o metal gasto do friso se esticava pela face inteira ate o
	# proximo ponto, e o corpo saia listrado de cinza.
	var perfil := PackedVector2Array([
		Vector2(0.0, -0.49), Vector2(0.25, -0.49), Vector2(0.262, -0.486),
		Vector2(0.27, -0.476), Vector2(0.276, -0.466), Vector2(0.28, -0.456),
		Vector2(0.276, -0.446), Vector2(0.27, -0.43), Vector2(0.27, -0.422),
		Vector2(0.27, -0.308), Vector2(0.27, -0.30),
		Vector2(0.276, -0.292), Vector2(0.276, -0.278), Vector2(0.27, -0.27),
		Vector2(0.27, -0.262), Vector2(0.27, -0.028),
		Vector2(0.27, -0.02), Vector2(0.276, -0.012), Vector2(0.276, 0.002),
		Vector2(0.27, 0.01), Vector2(0.27, 0.018), Vector2(0.27, 0.10), Vector2(0.264, 0.13),
		Vector2(0.245, 0.16), Vector2(0.20, 0.19), Vector2(0.15, 0.203),
		Vector2(0.126, 0.21), Vector2(0.123, 0.238), Vector2(0.122, 0.25), Vector2(0.13, 0.262),
		Vector2(0.126, 0.273), Vector2(0.114, 0.268), Vector2(0.108, 0.25),
		Vector2(0.108, 0.17), Vector2(0.108, 0.17), Vector2(0.0, 0.17),
	])
	var pinta_corpo := func(p: Vector3, _n: Vector3, _u: float, _v: float) -> Color:
		if p.y > 0.165 and p.y < 0.2 and Vector2(p.x, p.z).length() < 0.112:
			# A agua la no fundo da boca, escura e parada.
			return Color("121c1c")
		var friso := 0.0
		for faixa: Vector2 in [Vector2(-0.49, -0.44), Vector2(-0.296, -0.268),
				Vector2(-0.016, 0.012), Vector2(0.245, 0.28)]:
			if p.y >= faixa.x and p.y <= faixa.y:
				friso = 1.0
		return _cor_regador(p, 0.1 + 0.9 * friso)
	_revolver(m, perfil, 48, centro, pinta_corpo)
	# Bico: sai de dentro do corpo, engrossa na raiz como a solda.
	var bico := _curva(PackedVector3Array(BICO), 6)
	var raio_bico := func(s: float) -> float:
		return lerpf(0.055, 0.028, s) + 0.025 * maxf(0.0, 1.0 - s / 0.12)
	var cor_bico := func(s: float) -> Color: return _cor_regador(Vector3(s * 3.0, 0.2, 0.0), 0.1)
	_tubo(m, bico, raio_bico, 14, cor_bico)
	# Escora entre o bico e o corpo.
	var raio_escora := func(_s: float) -> float: return 0.011
	var cor_escora := func(_s: float) -> Color: return _cor_regador(Vector3(1.0, 0.0, 0.3), 0.1)
	_tubo(m, PackedVector3Array([Vector3(0.34, -0.125, 0.0), Vector3(0.24, -0.08, 0.0),
		Vector3(0.12, -0.05, 0.0)]), raio_escora, 6, cor_escora)
	# Alca comprida, de fita: nasce no domo, passa por cima e desce pelas costas.
	var alca := _curva(PackedVector3Array([
		Vector3(0.0, 0.17, 0.0), Vector3(0.0, 0.38, 0.0), Vector3(-0.12, 0.49, 0.0),
		Vector3(-0.31, 0.47, 0.0), Vector3(-0.45, 0.3, 0.0), Vector3(-0.47, 0.08, 0.0),
		Vector3(-0.43, -0.13, 0.0), Vector3(-0.385, -0.21, 0.0),
	]), 6)
	var raio_alca := func(_s: float) -> float: return 0.03
	var cor_alca := func(s: float) -> Color:
		# Pega da mao, no alto das costas, gasta ate o metal em partes.
		var pega := smoothstep(0.25, 0.35, s) * (1.0 - smoothstep(0.5, 0.6, s))
		return _cor_regador(Vector3(s * 7.0, 0.4, 1.0), 0.15 + 0.5 * pega)
	_tubo(m, alca, raio_alca, 10, cor_alca, 0.42)
	# Plaquinhas de rebite nas pontas da alca.
	var igual := func(q: Vector3) -> Vector3: return q
	for ponta: Vector3 in [Vector3(-0.005, 0.18, 0.0), Vector3(-0.39, -0.2, 0.0)]:
		var cor_rebite := func(_q: Vector3, _p: Vector3, _n: Vector3) -> Color:
			return _cor_regador(ponta * 9.0, 0.3)
		_bolha(m, Transform3D(Basis.from_scale(Vector3(0.03, 0.03, 0.04)), ponta), 1,
			igual, cor_rebite)
	return m


static func _xf_crivo() -> Transform3D:
	var bico := _curva(PackedVector3Array(BICO), 6)
	var n := bico.size()
	var d := (bico[n - 1] - bico[n - 2]).normalized()
	return Transform3D(_base_de(d), bico[n - 1] - d * 0.01)


static func _montar_crivo() -> Malha:
	var m := Malha.new()
	_revolver(m, PackedVector2Array([
		Vector2(0.026, -0.03), Vector2(0.032, 0.0), Vector2(0.046, 0.025),
		Vector2(0.072, 0.055), Vector2(0.086, 0.068), Vector2(0.091, 0.078),
		Vector2(0.089, 0.087), Vector2(0.084, 0.089),
	]), 32, Transform3D.IDENTITY, Callable())
	return m


## Face furada do crivo: disco com a textura dos furos.
static func _montar_crivo_face() -> Malha:
	var m := Malha.new()
	var centro := m.ponto(Vector3(0.0, 0.0885, 0.0), Vector3.UP, Color.WHITE,
		_uv(REG_CRIVO, Vector2(0.5, 0.5)))
	var lados := 32
	var ini := m.v.size()
	for k in lados:
		var a := TAU * float(k) / float(lados)
		var p := Vector3(cos(a) * 0.085, 0.0885, sin(a) * 0.085)
		m.ponto(p, Vector3.UP, Color.WHITE,
			_uv(REG_CRIVO, Vector2(0.5 + cos(a) * 0.47, 0.5 + sin(a) * 0.47)))
	for k in lados:
		m.tri(centro, ini + k, ini + (k + 1) % lados)
	return m


static func _regador(pai: Node3D) -> void:
	# Corpo, bico e alca. As tres pecas juntas sao a silhueta mais reconhecivel
	# das cinco; o verde de esmalte e o crivo de latao so confirmam. Um pouco
	# menor e puxado para a esquerda: o bico comprido saia do quadro da inspecao.
	var lata := Node3D.new()
	lata.name = "Regador"
	lata.transform = Transform3D(Basis.from_scale(Vector3.ONE * 0.9), Vector3(-0.05, 0.0, 0.0))
	pai.add_child(lata)
	_instancia(lata, _em_cache("regador", func() -> Malha: return _montar_regador()),
		_mat_estudio(null, Color.WHITE, 0.9, 0.26, 0.0, true))
	var xf := _xf_crivo()
	_instancia(lata, _em_cache("crivo", func() -> Malha: return _montar_crivo()),
		_mat_estudio(null, Color("c9a15a"), 1.0, 0.3, 1.0), xf)
	_instancia(lata, _em_cache("crivo_face", func() -> Malha: return _montar_crivo_face()),
		_mat_estudio(_rotulos(), Color.WHITE, 0.7, 0.35, 0.6), xf)


# --- maconha ---------------------------------------------------------------------

static func _folhinha(m: Malha, raiz: Vector3, dir: Vector3, lado: Vector3, comp: float,
		larg: float, tom: float, passos: int = 6) -> void:
	var nor := dir.cross(lado).normalized()
	for face in 2:
		var sinal := 1.0 if face == 0 else -1.0
		var ini := m.v.size()
		for i in passos + 1:
			var s := float(i) / float(passos)
			var c0 := raiz + dir * comp * s + nor * comp * 0.3 * s * s
			var w := larg * pow(sin(PI * minf(s * 1.05, 1.0)), 0.7) * (1.0 + 0.35 * float(i % 2))
			var c := Color(tom, 0.5, 0.85, 0.8)
			m.ponto(c0 - lado * w + nor * 0.003 * sinal, nor * sinal, c)
			m.ponto(c0 + nor * (0.012 * sin(PI * s) + 0.003 * sinal), nor * sinal, c)
			m.ponto(c0 + lado * w + nor * 0.003 * sinal, nor * sinal, c)
		for i in passos:
			var a := ini + i * 3
			m.quad(a, a + 1, a + 4, a + 3)
			m.quad(a + 1, a + 2, a + 5, a + 4)


## Cabeca unitaria (comprimento 1 no eixo Y) numa malha so: uma esfera de 320
## triangulos esticada e afinada para a ponta, com 16 calombos (os calices), duas
## folhinhas de acucar rentes e 10 pistilos.
##
## Era um miolo com 24 calices soltos, cada um uma esfera de 80 triangulos: 2,7
## mil por cabeca e 95 mil no pote, pesado demais para um item de interface. O
## calombo no lugar do calice solto guarda o que lia — cacho encavalado, vinco
## escuro entre calices, ponta geada — por um oitavo do custo. O vinco agora e
## pintado (oclusao pela altura do calombo) em vez de sair da sombra entre
## esferas.
static func _montar_cabeca(variante: int) -> Malha:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9100 + variante * 131
	var m := Malha.new()
	var tom_base := rng.randf_range(0.35, 0.6)
	var sv := float(variante) * 3.7
	var n_lobo := 16
	var lobos: Array[Vector3] = []
	var tons := PackedFloat32Array()
	var geadas := PackedFloat32Array()
	var ferrugens: Array[bool] = []
	for i in n_lobo:
		# Espiral de Fibonacci na esfera, tremida: calombos espalhados por igual,
		# sem fileira.
		var y := 1.0 - 2.0 * (float(i) + 0.5) / float(n_lobo)
		var r := sqrt(1.0 - y * y)
		var a := float(i) * 2.39996 + rng.randf_range(-0.3, 0.3)
		lobos.append(Vector3(cos(a) * r, y + rng.randf_range(-0.08, 0.08), sin(a) * r).normalized())
		tons.append(clampf(tom_base + rng.randf_range(-0.25, 0.35), 0.0, 1.0))
		geadas.append(rng.randf_range(0.45, 1.0))
		ferrugens.append(rng.randf() < 0.3)
	var forma := func(q: Vector3) -> Vector3:
		var alto := _calombo(q, lobos).x
		var p := q * (1.0 + 0.28 * alto + 0.04 * _ruido(q * 7.0 + Vector3(sv, 0.0, 0.0)))
		var afina := 1.0 - 0.38 * maxf(p.y, 0.0)
		return Vector3(p.x * 0.34 * afina, p.y * 0.5, p.z * 0.34 * afina)
	var pinta := func(q: Vector3, _p: Vector3, _n: Vector3) -> Color:
		var c := _calombo(q, lobos)
		var k := int(c.y)
		var alto := c.x
		# Ponta ferrugem: e o pistilo seco rente, e e o que poe laranja na
		# cabeca quando o fio solto e fino demais para o pixel.
		var tipo := 1.0 if ferrugens[k] and alto > 0.88 else 0.0
		return Color(clampf(tons[k] + 0.15 * alto, 0.0, 1.0), tipo, 0.4 + 0.6 * alto,
			clampf(geadas[k] * (0.35 + 0.65 * alto), 0.0, 1.0))
	_bolha(m, Transform3D.IDENTITY, 2, forma, pinta)
	for i in 2:
		var k := rng.randi_range(0, n_lobo - 1)
		var raiz: Vector3 = (forma.call(lobos[k]) as Vector3) * 0.85
		var fora := Vector3(raiz.x, 0.0, raiz.z).normalized()
		var dir := (fora * 0.5 + Vector3.UP).normalized()
		var lado := dir.cross(fora).normalized()
		_folhinha(m, raiz, dir, lado, rng.randf_range(0.18, 0.26), rng.randf_range(0.035, 0.05),
			rng.randf_range(0.2, 0.6), 3)
	for i in 10:
		var k := rng.randi_range(0, n_lobo - 1)
		var p: Vector3 = forma.call(lobos[k])
		var dir: Vector3 = (Vector3(p.x, p.y * 0.5, p.z).normalized() + Vector3(rng.randf_range(-0.6, 0.6),
			rng.randf_range(-0.2, 0.6), rng.randf_range(-0.6, 0.6))).normalized()
		var pts := PackedVector3Array([p - dir * 0.03])
		var passo := rng.randf_range(0.04, 0.055)
		for s in 3:
			p += dir * passo
			dir = (dir + Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.9, 0.3),
				rng.randf_range(-0.9, 0.9))).normalized()
			pts.append(p)
		var tom := rng.randf()
		var grosso := rng.randf_range(0.009, 0.013)
		var raio_p := func(s: float) -> float: return grosso * (1.0 - s * 0.6)
		var cor_p := func(_s: float) -> Color: return Color(tom, 1.0, 1.0, 0.0)
		_tubo(m, pts, raio_p, 3, cor_p, 1.0, false, false)
	return m


## Altura (0 no vinco, 1 no topo) e indice do calombo mais perto do ponto q da
## esfera unitaria.
static func _calombo(q: Vector3, lobos: Array[Vector3], raio: float = 0.62) -> Vector2:
	var melhor := -2.0
	var k := 0
	for i in lobos.size():
		var d := q.dot(lobos[i])
		if d > melhor:
			melhor = d
			k = i
	var ang := acos(clampf(melhor, -1.0, 1.0))
	return Vector2(pow(1.0 - clampf(ang / raio, 0.0, 1.0), 0.7), float(k))


static func _malha_cabeca(variante: int) -> ArrayMesh:
	return _em_cache("cabeca_%d" % variante, func() -> Malha: return _montar_cabeca(variante))


static func _montar_vidro() -> Malha:
	var m := Malha.new()
	# Parede de vidro de verdade: o perfil desce por fora, contorna o labio e
	# sobe por dentro, e o fundo e grosso. Com cull_back o que aparece e a face
	# de fora da frente e a de dentro do fundo — as duas que o olho espera.
	_revolver(m, PackedVector2Array([
		Vector2(0.0, -0.50), Vector2(0.24, -0.50), Vector2(0.285, -0.49),
		Vector2(0.30, -0.465), Vector2(0.302, -0.40), Vector2(0.302, 0.18),
		Vector2(0.296, 0.225), Vector2(0.278, 0.262), Vector2(0.258, 0.285),
		Vector2(0.255, 0.30), Vector2(0.255, 0.37), Vector2(0.245, 0.38),
		Vector2(0.232, 0.372), Vector2(0.232, 0.30), Vector2(0.24, 0.28),
		Vector2(0.264, 0.255), Vector2(0.28, 0.22), Vector2(0.285, 0.18),
		Vector2(0.285, -0.44), Vector2(0.27, -0.462), Vector2(0.22, -0.47),
		Vector2(0.0, -0.47),
	]), 48, Transform3D.IDENTITY, Callable())
	return m


static func _montar_tampa() -> Malha:
	var m := Malha.new()
	# De baixo para cima: o disco de dentro (para o fundo da tampa nao ficar
	# vazado visto pelo vidro), o rebordo enrolado, a lateral serrilhada e o
	# tampo com o anel prensado.
	_revolver(m, PackedVector2Array([
		Vector2(0.0, 0.30), Vector2(0.255, 0.30), Vector2(0.255, 0.30),
		Vector2(0.258, 0.292), Vector2(0.272, 0.287), Vector2(0.282, 0.295),
		Vector2(0.283, 0.304), Vector2(0.279, 0.312), Vector2(0.279, 0.312),
		Vector2(0.279, 0.40), Vector2(0.276, 0.418), Vector2(0.266, 0.428),
		Vector2(0.25, 0.432), Vector2(0.232, 0.432), Vector2(0.226, 0.426),
		Vector2(0.20, 0.426), Vector2(0.194, 0.431), Vector2(0.10, 0.435),
		Vector2(0.0, 0.436),
	]), 72, Transform3D.IDENTITY, Callable(), Callable(), Vector4(0.014, 18.0, 0.314, 0.398))
	return m


## Rotulo colado no vidro, na frente (+Z) e no terco de baixo, para a erva
## aparecer por cima e pelos lados.
static func _montar_rotulo_pote(reg: Rect2, r: float = 0.3045, y0: float = -0.35,
		y1: float = -0.09) -> Malha:
	var m := Malha.new()
	# Largura do arco = o dobro da altura: o rotulo do atlas e 2:1.
	var meia := (y1 - y0) / r
	var cols := 28
	var base := m.v.size()
	for j in cols + 1:
		var s := float(j) / float(cols)
		var a := PI * 0.5 + meia - s * 2.0 * meia
		var nor := Vector3(cos(a), 0.0, sin(a))
		for i in 2:
			var y := y1 if i == 0 else y0
			m.ponto(nor * r + Vector3(0.0, y, 0.0), nor, Color.WHITE, _uv(reg, Vector2(s, float(i))))
	for j in cols:
		var a0 := base + j * 2
		m.quad(a0, a0 + 2, a0 + 3, a0 + 1)
	return m


static func _montar_miolo() -> Malha:
	var m := Malha.new()
	# Miolo escuro e calombento: e erva no fundo do pote, na sombra das cabecas da
	# frente. Liso e claro ele aparecia entre elas como uma bola verde.
	var forma := func(q: Vector3) -> Vector3:
		return q * (1.0 + 0.12 * _ruido(q * 4.0) + 0.08 * _ruido(q * 11.0 + Vector3(2.0, 0.0, 0.0)))
	var cor := func(_q: Vector3, _p: Vector3, _n: Vector3) -> Color: return Color(0.15, 0.0, 0.28, 0.0)
	_bolha(m, Transform3D(Basis.from_scale(Vector3(0.2, 0.32, 0.2)), Vector3(0.0, -0.15, 0.0)), 1,
		forma, cor)
	return m


## A Super e o mesmo pote, roxo: e a luz do andar 10 que ficou na erva.
static func _maconha(pai: Node3D, roxa: bool = false) -> void:
	# Pote de vidro com tampa de rosca e rotulo, CHEIO de cabeca. O pote e o
	# recipiente do jogo inteiro — o mesmo que enche na prateleira da estufa.
	#
	# A primeira versao tinha o vidro opaco e virou um cilindro branco liso; a
	# segunda trocou o vidro pela cor da erva. Aqui o vidro e vidro (quase nada
	# no meio, borda e janela refletida), e o que da a cor de longe e a propria
	# erva encostada nele: sao as cabecas da camada de fora que enchem o pote,
	# com um miolo escuro atras para nao haver buraco entre elas.
	var mat_erva := _mat_erva(roxa)
	_instancia(pai, _em_cache("pote_miolo", func() -> Malha: return _montar_miolo()), mat_erva)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	# Orcamento (~18 mil triangulos no pote): quatro aneis de cinco cabecas
	# grandes deitadas em volta do vidro, e tres por cima. So a camada de fora
	# aparece pelo vidro; o miolo escuro tapa o vao entre elas.
	var camadas := [-0.37, -0.22, -0.07, 0.08, 0.165]
	for c in camadas.size():
		var y: float = camadas[c]
		var topo := c == camadas.size() - 1
		var qtd := 3 if topo else 5
		var fase := rng.randf() * TAU
		for k in qtd:
			var a := fase + TAU * float(k) / float(qtd) + rng.randf_range(-0.15, 0.15)
			var esc := rng.randf_range(0.19, 0.22) if not topo else rng.randf_range(0.16, 0.19)
			# A face de fora da cabeca encosta no vidro (raio de dentro 0,285).
			var raio := 0.285 - esc * 0.42
			var eixo := Vector3(-sin(a), rng.randf_range(-0.9, 0.9), cos(a)).normalized()
			if topo:
				raio *= rng.randf_range(0.25, 0.8)
				eixo = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.3, 1.0),
					rng.randf_range(-1.0, 1.0)).normalized()
			var pos := Vector3(cos(a) * raio, y + rng.randf_range(-0.02, 0.02), sin(a) * raio)
			var b := _base_de(eixo).rotated(eixo, rng.randf() * TAU)
			_instancia(pai, _malha_cabeca(rng.randi_range(0, 4)), mat_erva,
				Transform3D(b * Basis.from_scale(Vector3.ONE * esc), pos))
	var reg := REG_POTE_SUPER if roxa else REG_POTE
	_instancia(pai, _em_cache("rotulo_%s" % roxa,
			func() -> Malha: return _montar_rotulo_pote(reg)),
		_mat_estudio(_rotulos(), Color.WHITE, 0.45 if roxa else 0.3, 0.4))
	# Tampa: aluminio no pote comum, latao no da Super.
	_instancia(pai, _em_cache("pote_tampa", func() -> Malha: return _montar_tampa()),
		_mat_estudio(null, Color("d6b25c") if roxa else Color("c8c6bf"), 1.0, 0.28, 1.0))
	_instancia(pai, _em_cache("pote_vidro", func() -> Malha: return _montar_vidro()),
		_mat_vidro(), Transform3D.IDENTITY, false)


# --- variedades da estufa ---------------------------------------------------------
#
# Um item por andar do poco (Variedades.DADOS). Sao o mesmo pote da Maconha — o
# recipiente do jogo inteiro — com tres coisas trocadas, na ordem em que o olho
# as acha num icone de 64 px: a SILHUETA (a Morcega de cabeca para baixo, a
# Girafa num pote comprido, a Gambazona com a tampa levantada pela cabeca, a
# Bonsai nem pote e), a COR da erva e da tampa, e so entao o rotulo. Rotulo e
# para perto: no icone ele vira duas manchas de cor.
#
# A cabeca de cada variedade e a mesma receita da `_montar_cabeca` (esfera de
# 320 triangulos com calombos, folhinhas e pistilos), com a forma mexida por
# FORMAS: esticada, redonda, torcida em mola, dobrada para baixo.

## Regiao de cada rotulo na folha de baixo do atlas (tools/gerar_rotulos_cultivo.py,
## REG_VAR). Mesma ordem dos andares.
const REG_VAR := {
	&"morcega": Rect2(0, 1024, 512, 256), &"bonsai": Rect2(512, 1024, 512, 256),
	&"saca_rolha": Rect2(0, 1280, 512, 256), &"girafa": Rect2(512, 1280, 512, 256),
	&"pompom": Rect2(0, 1536, 512, 256), &"chorona": Rect2(512, 1536, 512, 256),
	&"gambazona": Rect2(0, 1792, 512, 256), &"vagalume": Rect2(512, 1792, 512, 256),
}

## A forma da cabeca. `lobos` calices grandes de altura `alto`; `esc` e a
## proporcao (x, comprimento, z); `afina` estreita para a ponta; `curva` dobra a
## ponta para o lado; `cai` puxa o pistilo para a ponta (a Chorona pendura a
## cabeca de ponta para baixo, e o fio escorre). A Saca-Rolha nao sai daqui: e
## um tubo em helice (`_montar_mola`).
const FORMAS := {
	&"morcega": {"lobos": 18, "alto": 0.3, "esc": Vector3(0.34, 0.56, 0.34), "afina": 0.45,
		"folhas": 3, "pistilos": 9, "variantes": 3},
	&"bonsai": {"lobos": 26, "alto": 0.2, "ruido": 0.012, "esc": Vector3(0.42, 0.44, 0.42),
		"afina": 0.62, "folhas": 0, "pistilos": 14, "variantes": 2},
	&"saca_rolha": {"pistilos": 7, "variantes": 3},
	&"girafa": {"lobos": 20, "alto": 0.24, "esc": Vector3(0.19, 0.95, 0.19), "afina": 0.3,
		"folhas": 2, "pistilos": 10, "variantes": 3},
	&"pompom": {"lobos": 26, "alto": 0.14, "ruido": 0.015, "esc": Vector3(0.44, 0.44, 0.44),
		"afina": 0.0, "folhas": 0, "pistilos": 14, "pist_passo": 0.6, "variantes": 3},
	&"chorona": {"lobos": 18, "alto": 0.26, "esc": Vector3(0.3, 0.62, 0.3), "afina": 0.5,
		"curva": 0.9, "cai": 1.2, "folhas": 2, "pistilos": 12, "pist_passo": 1.3, "variantes": 3},
	&"gambazona": {"lobos": 24, "alto": 0.36, "esc": Vector3(0.42, 0.56, 0.42), "afina": 0.3,
		"folhas": 3, "pistilos": 18, "variantes": 3},
	&"vagalume": {"lobos": 18, "alto": 0.3, "esc": Vector3(0.34, 0.5, 0.34), "afina": 0.4,
		"folhas": 2, "pistilos": 11, "variantes": 3},
}

## Paleta da erva de cada variedade: calice escuro e claro, folha, pistilo (dois
## tons), geada; `luz` acende (a Vagalume).
const PALETAS := {
	&"morcega": ["1a0e22", "6e4690", "261c30", "a82a44", "e0587a", "e2d4ee"],
	&"bonsai": ["2c4a1a", "a4c858", "3a5a22", "c8661f", "f2a444", "eef2dc"],
	&"saca_rolha": ["123e38", "5cc6a6", "1c584a", "e0902e", "f8c45a", "dcf6ec"],
	&"girafa": ["625a14", "f4e46a", "6e6a22", "a8501a", "de8e38", "f8f4d4"],
	&"pompom": ["7c3a5c", "ffb8d8", "6e7e3a", "ff4a96", "ffd2e6", "fff2f8"],
	&"chorona": ["142e48", "64aac8", "204658", "9ccaf0", "e4f2ff", "e2eefa"],
	&"gambazona": ["365a0c", "c2ec40", "466a14", "ee8a1c", "ffc844", "f2fad4"],
	&"vagalume": ["0c0816", "34285a", "16121f", "2ee6cc", "b0fff2", "3c5a78"],
}

## Tampa de cada pote: cor do metal anodizado.
const TAMPAS := {
	&"morcega": Color("4a3862"), &"saca_rolha": Color("2e9e90"), &"girafa": Color("d9a431"),
	&"pompom": Color("ec7eaa"), &"chorona": Color("4f6fc4"), &"gambazona": Color("98c62c"),
	&"vagalume": Color("1c1f2a"),
}


static func _montar_broto(v: StringName, variante: int) -> Malha:
	var f: Dictionary = FORMAS[v]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7300 + variante * 131 + FORMAS.keys().find(v) * 977
	var m := Malha.new()
	var tom_base := rng.randf_range(0.35, 0.6)
	var sv := float(variante) * 3.7
	var n_lobo: int = f.get("lobos", 16)
	var alto_lobo: float = f.get("alto", 0.28)
	var raio_lobo := 0.62 * sqrt(16.0 / float(n_lobo))
	var esc: Vector3 = f.get("esc", Vector3(0.34, 0.5, 0.34))
	var afina_k: float = f.get("afina", 0.38)
	var curva: float = f.get("curva", 0.0)
	var ruido_k: float = f.get("ruido", 0.04)
	var cai: float = f.get("cai", 0.0)
	var lobos: Array[Vector3] = []
	var tons := PackedFloat32Array()
	var geadas := PackedFloat32Array()
	var ferrugens: Array[bool] = []
	for i in n_lobo:
		var y := 1.0 - 2.0 * (float(i) + 0.5) / float(n_lobo)
		var r := sqrt(1.0 - y * y)
		var a := float(i) * 2.39996 + rng.randf_range(-0.3, 0.3)
		lobos.append(Vector3(cos(a) * r, y + rng.randf_range(-0.08, 0.08), sin(a) * r).normalized())
		tons.append(clampf(tom_base + rng.randf_range(-0.25, 0.35), 0.0, 1.0))
		geadas.append(rng.randf_range(0.45, 1.0))
		ferrugens.append(rng.randf() < 0.3)
	var forma := func(q: Vector3) -> Vector3:
		var alto := _calombo(q, lobos, raio_lobo).x
		var p := q * (1.0 + alto_lobo * alto + ruido_k * _ruido(q * 7.0 + Vector3(sv, 0.0, 0.0)))
		var afina := 1.0 - afina_k * maxf(p.y, 0.0)
		var o := Vector3(p.x * esc.x * afina, p.y * esc.y, p.z * esc.z * afina)
		if curva != 0.0:
			var s := maxf(o.y + esc.y * 0.2, 0.0)
			o.x += curva * s * s
		return o
	var pinta := func(q: Vector3, _p: Vector3, _n: Vector3) -> Color:
		var c := _calombo(q, lobos, raio_lobo)
		var k := int(c.y)
		var alto := c.x
		var tipo := 1.0 if ferrugens[k] and alto > 0.88 else 0.0
		return Color(clampf(tons[k] + 0.15 * alto, 0.0, 1.0), tipo, 0.4 + 0.6 * alto,
			clampf(geadas[k] * (0.35 + 0.65 * alto), 0.0, 1.0))
	_bolha(m, Transform3D.IDENTITY, 2, forma, pinta)
	for i in int(f.get("folhas", 2)):
		var k := rng.randi_range(0, n_lobo - 1)
		var raiz: Vector3 = (forma.call(lobos[k]) as Vector3) * 0.85
		var fora := Vector3(raiz.x, 0.0, raiz.z).normalized()
		var dir := (fora * 0.5 + Vector3.UP).normalized()
		var lado := dir.cross(fora).normalized()
		_folhinha(m, raiz, dir, lado, rng.randf_range(0.18, 0.26), rng.randf_range(0.035, 0.05),
			rng.randf_range(0.2, 0.6), 3)
	var passo_k: float = f.get("pist_passo", 1.0)
	for i in int(f.get("pistilos", 10)):
		var k := rng.randi_range(0, n_lobo - 1)
		var p: Vector3 = forma.call(lobos[k])
		var dir: Vector3 = (Vector3(p.x, p.y * 0.5, p.z).normalized() + Vector3(rng.randf_range(-0.6, 0.6),
			rng.randf_range(-0.2, 0.6), rng.randf_range(-0.6, 0.6))).normalized()
		var pts := PackedVector3Array([p - dir * 0.03])
		var passo := rng.randf_range(0.04, 0.055) * passo_k
		for s in 3:
			p += dir * passo
			dir = (dir + Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.9, 0.3) + cai,
				rng.randf_range(-0.9, 0.9))).normalized()
			pts.append(p)
		var tom := rng.randf()
		var grosso := rng.randf_range(0.009, 0.013)
		var raio_p := func(s: float) -> float: return grosso * (1.0 - s * 0.6)
		var cor_p := func(_s: float) -> Color: return Color(tom, 1.0, 1.0, 0.0)
		_tubo(m, pts, raio_p, 3, cor_p, 1.0, false, false)
	return m


static func _malha_broto(v: StringName, variante: int) -> ArrayMesh:
	var n: int = FORMAS[v].get("variantes", 3)
	var k := variante % n
	if v == &"saca_rolha":
		return _em_cache("broto_mola_%d" % k, func() -> Malha: return _montar_mola(k))
	return _em_cache("broto_%s_%d" % [v, k], func() -> Malha: return _montar_broto(v, k))


## Cabeca da Saca-Rolha: um cordao de calices enrolado em helice, de pe. A
## esfera torcida (a receita das outras) virava cacos a 320 triangulos; o tubo
## le como mola ate no icone, e o calice miudo sai do shader como em toda erva.
## Comprimento 1 em Y, de -0,5 a 0,5.
static func _montar_mola(variante: int) -> Malha:
	var m := Malha.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 8800 + variante * 71
	var fase := rng.randf() * TAU
	var voltas := rng.randf_range(1.6, 1.9)
	var raio_h := 0.19
	var n := 40
	var pts := PackedVector3Array()
	for i in n:
		var t := float(i) / float(n - 1)
		var a := fase + t * voltas * TAU
		# A helice fecha para a ponta, como o saca-rolha de verdade.
		var rh := raio_h * (1.0 - 0.45 * t)
		pts.append(Vector3(cos(a) * rh, t - 0.5, sin(a) * rh))
	var sv := float(variante) * 2.3
	var calombo := func(s: float) -> float: return 0.5 + 0.5 * sin(s * 44.0 + sv)
	var raio := func(s: float) -> float:
		var bojo := pow(sin(PI * clampf(s * 1.15, 0.0, 1.0)), 0.6)
		return (0.045 + 0.11 * bojo) * (1.0 + 0.22 * (calombo.call(s) as float))
	var tom_base := rng.randf_range(0.35, 0.55)
	var pinta := func(s: float) -> Color:
		var c: float = calombo.call(s)
		return Color(clampf(tom_base + 0.3 * c, 0.0, 1.0), 0.0, 0.45 + 0.55 * c, 0.35 + 0.6 * c)
	_tubo(m, pts, raio, 8, pinta)
	for i in int(FORMAS[&"saca_rolha"].get("pistilos", 7)):
		var s := rng.randf_range(0.1, 0.9)
		var j := int(s * float(n - 1))
		var centro := pts[j]
		var fora := Vector3(centro.x, 0.0, centro.z).normalized()
		var p := centro + fora * (raio.call(s) as float) * 0.9
		var dir := (fora + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.2, 0.6),
			rng.randf_range(-0.5, 0.5))).normalized()
		var fio := PackedVector3Array([p - dir * 0.02])
		for k in 3:
			p += dir * rng.randf_range(0.04, 0.055)
			dir = (dir + Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.9, 0.3),
				rng.randf_range(-0.9, 0.9))).normalized()
			fio.append(p)
		var tom := rng.randf()
		var grosso := rng.randf_range(0.009, 0.013)
		var raio_p := func(u: float) -> float: return grosso * (1.0 - u * 0.6)
		var cor_p := func(_u: float) -> Color: return Color(tom, 1.0, 1.0, 0.0)
		_tubo(m, fio, raio_p, 3, cor_p, 1.0, false, false)
	return m


static func _mat_erva_de(v: StringName) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("sh_erva", SH_ERVA)
	var p: Array = PALETAS[v]
	var nomes := [&"calice_escuro", &"calice_claro", &"folha", &"pistilo_a", &"pistilo_b", &"geada"]
	for i in nomes.size():
		m.set_shader_parameter(nomes[i], Color(String(p[i])))
	if v == &"vagalume":
		m.set_shader_parameter(&"luz", Color("36f0dc"))
		m.set_shader_parameter(&"luz_forca", 1.3)
	return m


## Uma cabeca: `eixo` e para onde a ponta aponta, `giro` a volta em torno dele.
static func _cabeca_em(pai: Node3D, v: StringName, variante: int, mat: Material, pos: Vector3,
		eixo: Vector3, esc: float, giro: float, achata: Vector3 = Vector3.ONE) -> void:
	var b := _base_de(eixo).rotated(eixo.normalized(), giro)
	_instancia(pai, _malha_broto(v, variante), mat,
		Transform3D(b * Basis.from_scale(achata * esc), pos))


## Aneis de cabecas encostadas no vidro, como no pote da Maconha: `camadas` e
## a altura de cada anel, o ultimo e o de cima (tres cabecas, mais para o meio).
## `eixo_de(a, topo, rng)` escolhe a direcao da ponta de cada uma.
static func _aneis(pai: Node3D, v: StringName, mat: Material, rng: RandomNumberGenerator,
		camadas: Array, por_anel: int, esc_faixa: Vector2, meia_larg: float, raio_vidro: float,
		eixo_de: Callable) -> void:
	for c in camadas.size():
		var y: float = camadas[c]
		var topo := c == camadas.size() - 1
		var qtd := 3 if topo else por_anel
		var fase := rng.randf() * TAU
		for k in qtd:
			var a := fase + TAU * float(k) / float(qtd) + rng.randf_range(-0.15, 0.15)
			var esc := rng.randf_range(esc_faixa.x, esc_faixa.y) * (0.88 if topo else 1.0)
			var raio := raio_vidro - esc * meia_larg
			if topo:
				raio *= rng.randf_range(0.25, 0.8)
			var pos := Vector3(cos(a) * raio, y + rng.randf_range(-0.02, 0.02), sin(a) * raio)
			var eixo: Vector3 = eixo_de.call(a, topo, rng)
			_cabeca_em(pai, v, rng.randi_range(0, 5), mat, pos, eixo, esc, rng.randf() * TAU)


static func _miolo(pai: Node3D, mat: Material, xf: Transform3D = Transform3D.IDENTITY) -> void:
	_instancia(pai, _em_cache("pote_miolo", func() -> Malha: return _montar_miolo()), mat, xf)


## Vidro, tampa e rotulo. `xf` leva o pote inteiro (a Girafa estica, a Morcega
## vira); o rotulo vai a parte, por `xf_rotulo`, porque nunca vira de ponta-cabeca.
static func _casco(pai: Node3D, v: StringName, xf: Transform3D, xf_tampa: Transform3D,
		rotulo_pai: Node3D, xf_rotulo: Transform3D, raio_rotulo: float = 0.3045,
		y_rotulo: Vector2 = Vector2(-0.35, -0.09)) -> void:
	var reg: Rect2 = REG_VAR[v]
	_instancia(rotulo_pai, _em_cache("rotulo_var_%s" % v,
			func() -> Malha: return _montar_rotulo_pote(reg, raio_rotulo, y_rotulo.x, y_rotulo.y)),
		_mat_estudio(_rotulos(), Color.WHITE, 0.35, 0.4), xf_rotulo)
	var cor: Color = TAMPAS.get(v, Color("c8c6bf"))
	_instancia(pai, _em_cache("pote_tampa", func() -> Malha: return _montar_tampa()),
		_mat_estudio(null, cor, 1.0, 0.3, 1.0), xf_tampa)
	_instancia(pai, _em_cache("pote_vidro", func() -> Malha: return _montar_vidro()),
		_mat_vidro(), xf, false)


static func _variedade(pai: Node3D, v: StringName) -> void:
	match v:
		&"morcega":
			_pote_morcega(pai)
		&"bonsai":
			_bonsai(pai)
		&"saca_rolha":
			_pote_saca_rolha(pai)
		&"girafa":
			_pote_girafa(pai)
		&"pompom":
			_pote_pompom(pai)
		&"chorona":
			_pote_chorona(pai)
		&"gambazona":
			_pote_gambazona(pai)
		&"vagalume":
			_pote_vagalume(pai)


## Eixo das cabecas da Maconha: deitadas em volta do vidro, as de cima soltas.
static func _eixo_deitado(a: float, topo: bool, rng: RandomNumberGenerator) -> Vector3:
	if topo:
		return Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.3, 1.0),
			rng.randf_range(-1.0, 1.0)).normalized()
	return Vector3(-sin(a), rng.randf_range(-0.9, 0.9), cos(a)).normalized()


## A do andar da secagem: o pote pendurado de cabeca para baixo, apoiado na
## tampa. O rotulo e colado do lado certo, para ler.
static func _pote_morcega(pai: Node3D) -> void:
	var v := &"morcega"
	var virado := Node3D.new()
	virado.rotation = Vector3(0.0, 0.0, PI)
	virado.position = Vector3(0.0, -0.04, 0.0)
	pai.add_child(virado)
	var mat := _mat_erva_de(v)
	_miolo(virado, mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5101
	# Dentro do pote virado a ponta das cabecas aponta para o "chao" dele, que
	# agora e o teto: no mundo, elas pendem.
	var eixo := func(a: float, topo: bool, r: RandomNumberGenerator) -> Vector3:
		if topo:
			return Vector3(r.randf_range(-0.4, 0.4), 1.0, r.randf_range(-0.4, 0.4)).normalized()
		return Vector3(-sin(a) * 0.6, r.randf_range(0.4, 1.0), cos(a) * 0.6).normalized()
	_aneis(virado, v, mat, rng, [-0.37, -0.22, -0.07, 0.08, 0.165], 5, Vector2(0.19, 0.22),
		0.46, 0.285, eixo)
	_casco(virado, v, Transform3D.IDENTITY, Transform3D.IDENTITY, pai,
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.24, 0.0)))


## A do andar 4: as cabecas sobem em espiral pelo vidro, deitadas na diagonal,
## e cada uma e torcida em mola.
static func _pote_saca_rolha(pai: Node3D) -> void:
	var v := &"saca_rolha"
	var mat := _mat_erva_de(v)
	_miolo(pai, mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5404
	# Dois andares de molas em pe encostadas no vidro, e tres soltas por cima.
	for camada in 2:
		var y := -0.3 + float(camada) * 0.27
		var fase := rng.randf() * TAU
		for k in 5:
			var a := fase + TAU * float(k) / 5.0 + rng.randf_range(-0.12, 0.12)
			var esc := rng.randf_range(0.28, 0.31)
			var raio := 0.285 - esc * 0.35
			var eixo := Vector3(-sin(a) * 0.25 + rng.randf_range(-0.15, 0.15), 1.0,
				cos(a) * 0.25 + rng.randf_range(-0.15, 0.15)).normalized()
			_cabeca_em(pai, v, k + camada, mat, Vector3(cos(a) * raio, y, sin(a) * raio), eixo, esc,
				rng.randf() * TAU)
	for k in 3:
		var a := TAU * float(k) / 3.0 + 0.4
		_cabeca_em(pai, v, k, mat, Vector3(cos(a) * 0.1, 0.19, sin(a) * 0.1),
			Vector3(cos(a) * 0.5, 1.0, sin(a) * 0.5), 0.24, rng.randf() * TAU)
	_casco(pai, v, Transform3D.IDENTITY, Transform3D.IDENTITY, pai, Transform3D.IDENTITY)


## A do andar 5: pote comprido e fino, e as cabecas em pe, compridas e amarelas.
static func _pote_girafa(pai: Node3D) -> void:
	var v := &"girafa"
	var mat := _mat_erva_de(v)
	# O pote comprido nao cabe no quadro do icone no tamanho dos outros: vai
	# inteiro um pouco menor, e o que conta e a proporcao.
	var corpo := Node3D.new()
	corpo.scale = Vector3.ONE * 0.88
	pai.add_child(corpo)
	pai = corpo
	var alto := 1.25
	var largo := 0.8
	var sobe := 0.05
	_miolo(pai, mat, Transform3D(Basis.from_scale(Vector3(0.55, alto, 0.55)), Vector3(0.0, sobe, 0.0)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5505
	var dentro := 0.285 * largo
	for camada in 3:
		var y := -0.37 + float(camada) * 0.28
		var qtd := 6
		var fase := rng.randf() * TAU
		for k in qtd:
			var a := fase + TAU * float(k) / float(qtd) + rng.randf_range(-0.12, 0.12)
			var esc := rng.randf_range(0.135, 0.15)
			var raio := dentro - esc * 0.3
			var eixo := Vector3(cos(a) * 0.12 + rng.randf_range(-0.12, 0.12), 1.0,
				sin(a) * 0.12 + rng.randf_range(-0.12, 0.12)).normalized()
			_cabeca_em(pai, v, k + camada, mat, Vector3(cos(a) * raio, y + rng.randf_range(-0.03, 0.03),
				sin(a) * raio), eixo, esc, rng.randf() * TAU)
		for k in 2:
			var a := fase + PI * float(k) + 0.9
			_cabeca_em(pai, v, camada + k, mat, Vector3(cos(a) * 0.07, y + 0.08, sin(a) * 0.07),
				Vector3(cos(a) * 0.15, 1.0, sin(a) * 0.15), 0.14, rng.randf() * TAU)
	var xf := Transform3D(Basis.from_scale(Vector3(largo, alto, largo)), Vector3(0.0, sobe, 0.0))
	# A tampa nao estica: so afina, e sobe ate a boca do vidro esticado.
	var xf_tampa := Transform3D(Basis.from_scale(Vector3(largo, 1.0, largo)),
		Vector3(0.0, 0.30 * alto + sobe - 0.30, 0.0))
	_casco(pai, v, xf, xf_tampa, pai, Transform3D(Basis.IDENTITY, Vector3(0.0, sobe, 0.0)),
		0.3045 * largo + 0.0005, Vector2(-0.38, -0.17))


## A do andar 6: bolas perfeitas, cor-de-rosa.
static func _pote_pompom(pai: Node3D) -> void:
	var v := &"pompom"
	var mat := _mat_erva_de(v)
	_miolo(pai, mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5606
	var eixo := func(_a: float, _topo: bool, r: RandomNumberGenerator) -> Vector3:
		return Vector3(r.randf_range(-1.0, 1.0), r.randf_range(-1.0, 1.0), r.randf_range(-1.0, 1.0))
	_aneis(pai, v, mat, rng, [-0.35, -0.16, 0.03, 0.17], 5, Vector2(0.2, 0.215), 0.52, 0.285, eixo)
	_casco(pai, v, Transform3D.IDENTITY, Transform3D.IDENTITY, pai, Transform3D.IDENTITY)


## A do andar 7: cabecas de ponta para baixo e dobradas, como salgueiro.
static func _pote_chorona(pai: Node3D) -> void:
	var v := &"chorona"
	var mat := _mat_erva_de(v)
	_miolo(pai, mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5707
	var eixo := func(a: float, topo: bool, r: RandomNumberGenerator) -> Vector3:
		if topo:
			return Vector3(r.randf_range(-0.5, 0.5), -1.0, r.randf_range(-0.5, 0.5)).normalized()
		return Vector3(-sin(a) * 0.5 + r.randf_range(-0.15, 0.15), -1.0,
			cos(a) * 0.5 + r.randf_range(-0.15, 0.15)).normalized()
	_aneis(pai, v, mat, rng, [-0.25, -0.04, 0.15], 5, Vector2(0.23, 0.25), 0.44, 0.285, eixo)
	_casco(pai, v, Transform3D.IDENTITY, Transform3D.IDENTITY, pai, Transform3D.IDENTITY)


## A do andar do cheiro: poucas cabecas enormes, a de cima nao cabe e levanta a
## tampa, e o cheiro sai pela fresta.
static func _pote_gambazona(pai: Node3D) -> void:
	var v := &"gambazona"
	var mat := _mat_erva_de(v)
	# Tudo um pouco abaixo: a tampa levantada e o bafo sobem alem do pote comum,
	# e o icone corta o que passa do quadro.
	var corpo := Node3D.new()
	corpo.position = Vector3(0.0, -0.07, 0.0)
	pai.add_child(corpo)
	pai = corpo
	_miolo(pai, mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5808
	for k in 3:
		var a := TAU * float(k) / 3.0 + 0.3
		var eixo := Vector3(-sin(a), rng.randf_range(-0.5, 0.5), cos(a)).normalized()
		_cabeca_em(pai, v, k, mat, Vector3(cos(a) * 0.11, -0.25, sin(a) * 0.11), eixo, 0.27,
			rng.randf() * TAU)
	for k in 3:
		var a := TAU * float(k) / 3.0 + 1.2
		var eixo := Vector3(-sin(a), rng.randf_range(-0.4, 0.4), cos(a)).normalized()
		_cabeca_em(pai, v, k + 1, mat, Vector3(cos(a) * 0.1, 0.03, sin(a) * 0.1), eixo, 0.27,
			rng.randf() * TAU)
	# A que nao cabe: em pe, saindo pela boca.
	_cabeca_em(pai, v, 0, mat, Vector3(0.0, 0.3, 0.0), Vector3(0.1, 1.0, 0.05), 0.27, 0.8)
	var xf_tampa := Transform3D(Basis.from_euler(Vector3(0.0, 0.0, -0.4)), Vector3(-0.1, 0.21, 0.0))
	_casco(pai, v, Transform3D.IDENTITY, xf_tampa, pai, Transform3D.IDENTITY)
	# O cheiro: tres fios de fedor de desenho animado saindo pela fresta. Bafo
	# de verdade (bola translucida) lia como pedra verde flutuando.
	var fedor := StandardMaterial3D.new()
	fedor.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fedor.albedo_color = Color("b6e83a")
	_instancia(pai, _em_cache("fedor", func() -> Malha: return _montar_fedor()), fedor,
		Transform3D.IDENTITY, false)


static func _montar_fedor() -> Malha:
	var m := Malha.new()
	for k in 3:
		var z := -0.07 + float(k) * 0.08
		var x0 := -0.2 - float(k % 2) * 0.05
		var pts := PackedVector3Array()
		for i in 14:
			var t := float(i) / 13.0
			pts.append(Vector3(x0 - t * 0.14 + sin(t * 9.0 + float(k)) * 0.03, 0.43 + t * 0.2, z))
		var raio := func(s: float) -> float: return 0.012 * (1.0 - 0.5 * s)
		var cor := func(_s: float) -> Color: return Color.WHITE
		_tubo(m, pts, raio, 5, cor)
	return m


## A do andar apagado: erva quase preta que acende, tampa preta e vagalumes
## soltos no vidro.
static func _pote_vagalume(pai: Node3D) -> void:
	var v := &"vagalume"
	var mat := _mat_erva_de(v)
	_miolo(pai, mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5909
	_aneis(pai, v, mat, rng, [-0.37, -0.22, -0.07, 0.08, 0.165], 5, Vector2(0.19, 0.22), 0.46,
		0.285, _eixo_deitado)
	var pisca := StandardMaterial3D.new()
	pisca.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pisca.albedo_color = Color("b8fff4")
	var bola := SphereMesh.new()
	bola.radius = 1.0
	bola.height = 2.0
	bola.radial_segments = 6
	bola.rings = 3
	for i in 9:
		var a := rng.randf() * TAU
		var y := rng.randf_range(-0.36, 0.2)
		var r := rng.randf_range(0.26, 0.283)
		_instancia(pai, bola, pisca, Transform3D(Basis.from_scale(Vector3.ONE * rng.randf_range(0.016, 0.024)),
			Vector3(cos(a) * r, y, sin(a) * r)), false)
	_casco(pai, v, Transform3D.IDENTITY, Transform3D.IDENTITY, pai, Transform3D.IDENTITY)


# --- bonsai ------------------------------------------------------------------------

## A do andar 3 nao vem em pote: e a propria arvorezinha, na bandeja rasa de
## ceramica, sobre musgo, com uma cabeca so e perfeita no lugar da copa e a
## plaquinha do rotulo espetada na frente.
static func _bonsai(pai: Node3D) -> void:
	var v := &"bonsai"
	var mat := _mat_erva_de(v)
	var oval := Transform3D(Basis.from_scale(Vector3(1.4, 1.0, 1.0)), Vector3.ZERO)
	_instancia(pai, _em_cache("bonsai_bandeja", func() -> Malha: return _montar_bandeja()),
		_mat_estudio(null, Color("8c3b24"), 0.9, 0.3), oval)
	var vertice := _mat_estudio(null, Color.WHITE, 0.12, 0.85, 0.0, true)
	_instancia(pai, _em_cache("bonsai_musgo", func() -> Malha: return _montar_musgo()), vertice)
	_instancia(pai, _em_cache("bonsai_tronco", func() -> Malha: return _montar_tronco()),
		_mat_estudio(null, Color.WHITE, 0.2, 0.7, 0.0, true))
	# A copa: uma cabeca grande e perfeita, e duas nuvenzinhas nas pontas dos
	# galhos, chatas como copa de bonsai.
	_cabeca_em(pai, v, 0, mat, Vector3(-0.01, 0.22, 0.0), Vector3(0.05, 1.0, 0.0), 0.36, 0.3)
	_cabeca_em(pai, v, 1, mat, Vector3(0.25, 0.04, 0.05), Vector3(0.3, 1.0, 0.0), 0.2, 1.1,
		Vector3(1.25, 0.6, 1.25))
	_cabeca_em(pai, v, 1, mat, Vector3(-0.23, 0.1, -0.04), Vector3(-0.3, 1.0, 0.0), 0.17, 2.3,
		Vector3(1.25, 0.6, 1.25))
	# Plaquinha com o rotulo, espetada no musgo a frente e a direita.
	var placa := Transform3D(Basis.from_euler(Vector3(-0.3, -0.35, 0.05)), Vector3(0.2, -0.2, 0.26))
	_instancia(pai, _em_cache("bonsai_placa", func() -> Malha: return _montar_placa(REG_VAR[v], 0.34, 0.17)),
		_mat_estudio(_rotulos(), Color.WHITE, 0.3, 0.45), placa)
	_instancia(pai, _em_cache("bonsai_placa_fundo", func() -> Malha: return _montar_placa_fundo(0.34, 0.17)),
		_mat_estudio(null, Color("6a4a2e"), 0.2, 0.7), placa)


## Bandeja oval rasa (o oval vem da escala em x): pe, parede que abre, borda
## redonda e o fundo de dentro, que o musgo cobre.
static func _montar_bandeja() -> Malha:
	var m := Malha.new()
	_revolver(m, PackedVector2Array([
		Vector2(0.0, -0.42), Vector2(0.22, -0.42), Vector2(0.23, -0.415), Vector2(0.232, -0.395),
		Vector2(0.232, -0.395), Vector2(0.25, -0.392), Vector2(0.28, -0.37), Vector2(0.305, -0.3),
		Vector2(0.312, -0.27), Vector2(0.308, -0.258), Vector2(0.296, -0.256), Vector2(0.288, -0.266),
		Vector2(0.282, -0.29), Vector2(0.0, -0.29),
	]), 40, Transform3D.IDENTITY, Callable())
	return m


static func _montar_musgo() -> Malha:
	var m := Malha.new()
	var forma := func(q: Vector3) -> Vector3:
		var bossa := 0.5 + 0.5 * _ruido(q * 5.0 + Vector3(1.3, 0.0, 0.7))
		var alto := maxf(q.y, 0.0) * (0.75 + 0.5 * bossa) + minf(q.y, 0.0)
		return Vector3(q.x * 0.405, alto * 0.075, q.z * 0.29) * (1.0 + 0.03 * _ruido(q * 23.0))
	var pinta := func(q: Vector3, p: Vector3, _n: Vector3) -> Color:
		var r := _ruido(q * 9.0 + Vector3(0.0, 2.0, 0.0))
		var c := Color("4d6e22").lerp(Color("8fb23c"), smoothstep(-0.2, 0.7, r))
		# Terra aparecendo onde o musgo afina, e ponta clara no alto das bossas.
		c = c.lerp(Color("4a3424"), smoothstep(0.55, 0.85, -r) * 0.8)
		c = c.lerp(Color("b8cf66"), smoothstep(0.045, 0.07, p.y + 0.29) * 0.4)
		return c
	_bolha(m, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.285, 0.0)), 3, forma, pinta)
	# Tres pedrinhas.
	var cinza := func(_q: Vector3, p: Vector3, _n: Vector3) -> Color:
		return Color("8a8680").lerp(Color("c9c4b8"), smoothstep(-0.26, -0.22, p.y))
	for pedra: Array in [[Vector3(-0.28, -0.25, 0.12), 0.035], [Vector3(-0.22, -0.255, 0.18), 0.024],
			[Vector3(0.33, -0.255, -0.08), 0.03]]:
		var s: float = pedra[1]
		var achata := func(q: Vector3) -> Vector3:
			return Vector3(q.x, q.y * 0.6, q.z * 0.85) * (1.0 + 0.1 * _ruido(q * 3.0))
		_bolha(m, Transform3D(Basis.from_scale(Vector3.ONE * s), pedra[0] as Vector3), 1, achata, cinza)
	return m


## Tronco torto de raiz aberta e dois galhos, em cor de vertice (casca).
static func _montar_tronco() -> Malha:
	var m := Malha.new()
	var casca := func(s: float) -> Color:
		return Color("4a3322").lerp(Color("7a5a3e"), 0.5 + 0.5 * sin(s * 17.0))
	var tronco := _curva(PackedVector3Array([
		Vector3(0.03, -0.3, 0.0), Vector3(-0.05, -0.19, 0.02), Vector3(0.05, -0.07, -0.02),
		Vector3(-0.03, 0.05, 0.01), Vector3(-0.01, 0.16, 0.0),
	]), 5)
	var r_tronco := func(s: float) -> float: return 0.052 * (1.0 - 0.55 * s) + 0.05 * pow(1.0 - s, 6.0)
	_tubo(m, tronco, r_tronco, 9, casca)
	var galho_d := _curva(PackedVector3Array([
		Vector3(0.04, -0.06, -0.01), Vector3(0.13, -0.02, 0.02), Vector3(0.23, 0.02, 0.05),
	]), 4)
	var r_galho := func(s: float) -> float: return 0.026 * (1.0 - 0.6 * s)
	_tubo(m, galho_d, r_galho, 6, casca)
	var galho_e := _curva(PackedVector3Array([
		Vector3(-0.03, 0.03, 0.01), Vector3(-0.12, 0.07, -0.01), Vector3(-0.21, 0.08, -0.04),
	]), 4)
	_tubo(m, galho_e, r_galho, 6, casca)
	# Raizes abertas por cima do musgo.
	for a: float in [0.4, 2.3, 4.2]:
		var raiz := PackedVector3Array([Vector3(0.03, -0.25, 0.0),
			Vector3(0.03 + cos(a) * 0.07, -0.275, sin(a) * 0.07),
			Vector3(0.03 + cos(a) * 0.13, -0.285, sin(a) * 0.12)])
		var r_raiz := func(s: float) -> float: return 0.024 * (1.0 - 0.8 * s)
		_tubo(m, raiz, r_raiz, 5, casca)
	return m


## Retangulo com o rotulo, face +Z.
static func _montar_placa(reg: Rect2, w: float, h: float) -> Malha:
	var m := Malha.new()
	var a := m.ponto(Vector3(-w * 0.5, h, 0.006), Vector3.BACK, Color.WHITE, _uv(reg, Vector2(0, 0)))
	var b := m.ponto(Vector3(w * 0.5, h, 0.006), Vector3.BACK, Color.WHITE, _uv(reg, Vector2(1, 0)))
	var c := m.ponto(Vector3(w * 0.5, 0.0, 0.006), Vector3.BACK, Color.WHITE, _uv(reg, Vector2(1, 1)))
	var d := m.ponto(Vector3(-w * 0.5, 0.0, 0.006), Vector3.BACK, Color.WHITE, _uv(reg, Vector2(0, 1)))
	m.quad(a, b, c, d)
	return m


## A tabuinha por tras do rotulo, e a estaca que a segura no musgo.
static func _montar_placa_fundo(w: float, h: float) -> Malha:
	var m := Malha.new()
	var perfil := func(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> void:
		var cantos := [Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0),
			Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1)]
		var faces := [[0, 1, 2, 3, Vector3.FORWARD], [5, 4, 7, 6, Vector3.BACK], [4, 0, 3, 7, Vector3.LEFT],
			[1, 5, 6, 2, Vector3.RIGHT], [3, 2, 6, 7, Vector3.UP], [4, 5, 1, 0, Vector3.DOWN]]
		for fc: Array in faces:
			var nor: Vector3 = fc[4]
			var i0 := m.ponto(cantos[fc[0]], nor)
			var i1 := m.ponto(cantos[fc[1]], nor)
			var i2 := m.ponto(cantos[fc[2]], nor)
			var i3 := m.ponto(cantos[fc[3]], nor)
			m.quad(i0, i1, i2, i3)
	perfil.call(-w * 0.5 - 0.012, w * 0.5 + 0.012, -0.012, h + 0.012, -0.012, 0.005)
	perfil.call(-0.012, 0.012, -0.12, 0.0, -0.01, 0.0)
	return m
