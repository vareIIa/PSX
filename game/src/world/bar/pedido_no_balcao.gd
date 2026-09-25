## O que o atendente pousou na formica: a 600 com o copo, a dose, o pires. [E]
## pega e poe na mochila.
##
## Nao e o `ItemNoChao`: aquele e o sprite que flutua na rua e se lembra de ter
## sido pego (WorldState). Isto e objeto de verdade, com o rotulo do mercado na
## garrafa, e existe so enquanto o bar esta carregado — foi pago, e o bar e
## honesto, mas quem sai sem pegar deixa na mesa.
class_name PedidoNoBalcao
extends Interativo

const MATERIAIS := "res://resources/materials/mat_%s.tres"
## Area de pegar: um palmo em volta do que esta no tampo.
const AREA := Vector3(0.3, 0.34, 0.3)

var item_id: StringName = &""

## [dados do molde, ArrayMesh] ja montados. A chave e o PROPRIO dicionario de
## dados (`is_same`): o molde e cache da MoveisDoBar, e o mesmo pedido devolve o
## mesmo dicionario. A chave antiga era o hash dos vertices, que ignorava cor e
## UV e podia dar a um molde a malha de outro de mesma forma.
static var _malhas: Array = []


static func novo(id: StringName) -> PedidoNoBalcao:
	var p := PedidoNoBalcao.new()
	p.name = "Pedido_%s" % id
	p.item_id = id
	return p


func _ready() -> void:
	super()
	add_to_group(&"pedido_no_balcao")
	var def := Inventario.definicao(item_id)
	rotulo = "Pegar %s" % (def.nome.to_lower() if def != null else String(item_id))
	_montar()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = AREA
	forma.shape = caixa
	forma.position = Vector3(0.0, AREA.y * 0.5, 0.0)
	add_child(forma)


func _montar() -> void:
	match item_id:
		&"cerveja":
			_produto(&"brahma_600", Vector3(-0.05, 0.0, 0.0), 0.4)
			var copo := montar(MoveisDoBar.copo())
			copo.position = Vector3(0.07, 0.0, 0.03)
			add_child(copo)
		&"guarana":
			_produto(&"guarana_lata", Vector3.ZERO, -0.3)
		&"pinga":
			add_child(montar(MoveisDoBar.dose()))
		&"coxinha", &"torresmo":
			add_child(montar(MoveisDoBar.pires(item_id)))


## Um produto do catalogo do mercado, com o rotulo do atlas: o mesmo no dos
## produtos do bar, com uma instancia so.
func _produto(sku: StringName, onde: Vector3, giro: float) -> void:
	add_child(ProdutosDoBar.criar({"pos": Vector3.ZERO, "itens": [[sku, onde, giro]]}))


func interagir(quem: Node) -> void:
	if not habilitado:
		return
	# `adicionar` devolve a SOBRA: sem lugar na mochila, fica no balcao.
	if Inventario.adicionar(item_id) > 0:
		return
	habilitado = false
	AudioDirector.tocar(&"pega_vidro" if item_id != &"coxinha" and item_id != &"torresmo"
		else &"pegar", global_position, -6.0)
	acionado.emit(quem)
	queue_free()


## Um molde (material -> dados) virado no: um MeshInstance por material, a
## malha feita uma vez por molde. Nome com `@perto` e o do balde do chunk; aqui
## vale o material de nome puro.
static func montar(molde: Dictionary) -> Node3D:
	var no := Node3D.new()
	for mat: StringName in molde:
		# O molde e cache da MoveisDoBar: os mesmos dados, a mesma malha.
		var dados: Dictionary = molde[mat]
		var mesh: ArrayMesh = null
		for par: Array in _malhas:
			if is_same(par[0], dados):
				mesh = par[1]
				break
		if mesh == null:
			mesh = PSXMesh.dados_para_mesh(dados)
			_malhas.append([dados, mesh])
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = load(MATERIAIS % String(mat).get_slice("@", 0)) as Material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		no.add_child(mi)
	return no
