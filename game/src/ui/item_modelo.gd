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
	&"terra", &"semente_maconha", &"regador", &"maconha",
]


static func criar(id: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = String(id)
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


# --- os quatro do cultivo ---------------------------------------------------
#
# Sao insumos, e insumo tem um problema proprio de icone: terra, semente e erva
# sao todos marrom-esverdeados e todos granulados, e a onze pixels de altura
# viram a mesma mancha. O que os separa aqui e a SILHUETA do recipiente, e nao
# o conteudo: saco de boca aberta, caixinha rasa, lata com bico, pote alto.

static func _terra(pai: Node3D) -> void:
	# Saco de boca aberta, com a dobra de cima e a terra transbordando. A boca
	# aberta e a silhueta inteira: saco fechado e um retangulo escuro.
	_caixa(pai, Vector3(0.62, 0.78, 0.42), Vector3(0.0, -0.08, 0.0), Color("2e2c2a"))
	_caixa(pai, Vector3(0.66, 0.10, 0.46), Vector3(0.0, 0.32, 0.0), Color("1e1c1c"),
		Vector3(0.0, 0.0, deg_to_rad(3.0)))
	# A tarja impressa, que e a unica coisa clara do modelo e o que fixa a
	# leitura de "saco de loja" em vez de "saco de lixo".
	_caixa(pai, Vector3(0.64, 0.20, 0.02), Vector3(0.0, -0.10, 0.22), Color("cec8ba"))
	_caixa(pai, Vector3(0.50, 0.12, 0.02), Vector3(0.0, -0.10, 0.24), Color("4a7038"))
	for i in 3:
		_esfera(pai, 0.09 - float(i) * 0.01,
			Vector3(-0.14 + float(i) * 0.14, 0.36, -0.02 + float(i) * 0.05),
			Color("40342a"), 6)


static func _semente(pai: Node3D) -> void:
	# Caixinha rasa aberta, com tres sementes dentro. Rasa de proposito: e o que
	# a separa do saco, que e alto.
	_caixa(pai, Vector3(0.86, 0.26, 0.60), Vector3(0.0, -0.18, 0.0), Color("8e7050"))
	_caixa(pai, Vector3(0.78, 0.06, 0.52), Vector3(0.0, -0.06, 0.0), Color("5a4630"))
	# A tampa aberta para tras, com a dobradica. Sem ela a caixa fechada vira
	# um tijolo de madeira.
	_caixa(pai, Vector3(0.86, 0.04, 0.58), Vector3(0.0, 0.10, -0.42), Color("9a7c58"),
		Vector3(deg_to_rad(-62.0), 0.0, 0.0))
	for i in 3:
		_esfera(pai, 0.10, Vector3(-0.22 + float(i) * 0.22, 0.0,
			0.06 - float(i) * 0.08), Color("6a5438"), 8)
		_esfera(pai, 0.045, Vector3(-0.20 + float(i) * 0.22, 0.06,
			0.10 - float(i) * 0.08), Color("b8a078"), 6)


static func _regador(pai: Node3D) -> void:
	# Corpo, bico e alca. As tres pecas juntas sao a silhueta mais reconhecivel
	# das quatro, e por isso o regador e o unico que nao precisa de cor propria.
	_cilindro(pai, 0.34, 0.40, 0.72, Vector3(-0.08, -0.06, 0.0), Color("3e6a4c"),
		Vector3.ZERO, 12, 0.2)
	_cilindro(pai, 0.09, 0.07, 0.62, Vector3(0.34, 0.16, 0.0), Color("3e6a4c"),
		Vector3(0.0, 0.0, deg_to_rad(-52.0)), 8, 0.2)
	# O crivo, cinza: e a ponta que diz que sai agua, e nao leite.
	_cilindro(pai, 0.17, 0.11, 0.10, Vector3(0.56, 0.40, 0.0), Color("9aa09c"),
		Vector3(0.0, 0.0, deg_to_rad(-52.0)), 10, 0.5)
	_caixa(pai, Vector3(0.06, 0.30, 0.06), Vector3(-0.30, 0.36, 0.0), Color("2e5238"),
		Vector3(0.0, 0.0, deg_to_rad(22.0)))
	_caixa(pai, Vector3(0.34, 0.06, 0.06), Vector3(-0.16, 0.48, 0.0), Color("2e5238"))
	_cilindro(pai, 0.36, 0.36, 0.06, Vector3(-0.08, 0.32, 0.0), Color("2e5238"),
		Vector3.ZERO, 12, 0.2)


static func _maconha(pai: Node3D) -> void:
	# Pote de vidro alto com a tampa de metal, e a cabeca dentro. O pote e o
	# recipiente do jogo inteiro — e o mesmo que enche na prateleira da estufa —
	# e ter o icone igual a prateleira e o que liga as duas coisas sem texto.
	# O conteudo E o corpo do pote, e nao uma coisa dentro de outra.
	#
	# A primeira versao tinha vidro por fora e as cabecas dentro, que e o certo
	# no mundo e errado no icone: o bake sai a onze pixels uteis, o vidro e
	# opaco no material padrao e o pote inteiro virou um cilindro branco liso.
	# Quem olha um pote a essa distancia ve a COR do que tem dentro, entao o
	# verde ocupa o corpo e o vidro fica reduzido ao aro e a tampa.
	_cilindro(pai, 0.33, 0.33, 0.74, Vector3(0.0, -0.12, 0.0), Color("46703a"),
		Vector3.ZERO, 12)
	# As cabecas encostadas no vidro, saindo da massa: sem elas o verde vira
	# um pote de tinta.
	for i in 3:
		_esfera(pai, 0.15, Vector3(-0.16 + float(i) * 0.16, -0.30 + float(i) * 0.22,
			0.20), Color("5c8a46"), 8)
	_esfera(pai, 0.06, Vector3(0.06, -0.02, 0.30), Color("a86a34"), 6)
	_esfera(pai, 0.05, Vector3(-0.14, -0.26, 0.28), Color("a86a34"), 6)
	# O aro de vidro acima da linha do conteudo, e a tampa de metal.
	_cilindro(pai, 0.36, 0.36, 0.20, Vector3(0.0, 0.34, 0.0), Color("cad8ce"),
		Vector3.ZERO, 12, 0.2)
	_cilindro(pai, 0.38, 0.38, 0.14, Vector3(0.0, 0.50, 0.0), Color("8e948e"),
		Vector3.ZERO, 12, 0.5)
