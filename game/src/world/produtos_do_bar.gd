## Os produtos do bar, com a cara dos do mercado: lata, garrafa de 600, cachaca e
## maco de cigarro em 3D, cada um com o proprio rotulo do atlas.
##
## Por que existe
## -------------
## A cervejeira do bar era uma placa com a textura `bar_cervejeira` (garrafas
## desenhadas, e o dither por cima), e a prateleira atras do balcao eram cubinhos
## coloridos. O mercado ja resolve produto como COISA: uma malha por forma
## (`ProdutoMalhas`), o rotulo escolhido por instancia no atlas `rotulos`
## (`RotulosAtlas`) e uma `MultiMesh` por forma. Aqui se usa exatamente isso,
## sem estoque nem mao: produto de bar nao se tira da prateleira (ainda).
##
## Fronteira de thread
## -------------------
## O chunk e montado no WorkerThreadPool. A lista de itens (`fileira`) sai de la
## e so le `CatalogoMercado.PRODUTOS`, que e constante. `CatalogoMercado.produto`
## e `RotulosAtlas.celula` enchem indice estatico na primeira chamada, e isso so
## acontece aqui, no `_ready`, na thread principal.
class_name ProdutosDoBar
extends Node3D

## A partir daqui o produto nao se desenha: com 480x270 uma lata a 40 m e um
## pixel so, e sao centenas.
const ALCANCE := 40.0
## Folga entre duas unidades lado a lado na prateleira.
const FOLGA := 0.006

## [sku, base (chao da unidade, no meio), giro (a frente do rotulo olha +Z
## girado)], com a base RELATIVA ao `pos` do prop.
var itens: Array = []


static func criar(prop: Dictionary) -> ProdutosDoBar:
	var p := ProdutosDoBar.new()
	p.name = "ProdutosDoBar"
	p.position = prop.get("pos", Vector3.ZERO)
	p.itens = prop.get("itens", [])
	return p


## O prop pronto para o chunk, com os itens relativos a `referencia`.
##
## Relativos, e nao em coordenada do chunk: o lote do bar e ERGUIDO depois de
## montado (`Relevo.erguer`, a ladeira), e o relevo so move a chave `pos` de
## cada prop. Com a base absoluta dentro de `itens`, o bar do Seu Ze descia 26 m
## e as latas ficavam no ar, sobre o terreno — a cervejeira aparecia vazia.
static func prop(itens_no_chunk: Array, referencia: Vector3) -> Dictionary:
	var relativos: Array = []
	for item: Array in itens_no_chunk:
		relativos.append([item[0], Vector3(item[1]) - referencia, item[2]])
	return {"tipo": "produtos", "pos": referencia, "itens": relativos}


# --- dados, na thread do chunk --------------------------------------------------

## Largura (x) e altura (y) de um produto em metros, lendo so a tabela constante.
static func medida(sku: StringName) -> Vector3:
	for p: Dictionary in CatalogoMercado.PRODUTOS:
		if p["id"] == sku:
			return Vector3(p.get("cm", Vector3(8, 10, 5))) * 0.01
	return Vector3(0.08, 0.1, 0.05)


## Enche uma fileira de `de` ate `ate` (as duas pontas na base da prateleira),
## com a frente para `giro`. As marcas se revezam em grupos de `por_marca`
## frentes, como numa geladeira de verdade. Devolve quantas unidades pos.
##
## `recuo` > 0 poe uma segunda fileira atras da primeira, recuada tanto: e o que
## faz a prateleira ter fundo quando se olha de lado.
static func fileira(itens: Array, skus: Array, de: Vector3, ate: Vector3,
		giro: float, por_marca: int = 4, recuo: float = 0.0,
		semente: int = 0) -> int:
	if skus.is_empty():
		return 0
	var eixo := ate - de
	var comp := eixo.length()
	if comp < 0.01:
		return 0
	eixo /= comp
	var atras := Basis(Vector3.UP, giro) * Vector3(0.0, 0.0, -1.0)
	var postos := 0
	var andou := 0.0
	var marca := 0
	var na_marca := 0
	var larguras: Dictionary = {}
	while true:
		var sku: StringName = skus[(marca + semente) % skus.size()]
		if not larguras.has(sku):
			larguras[sku] = medida(sku).x
		var larg: float = larguras[sku]
		if andou + larg > comp:
			break
		var base := de + eixo * (andou + larg * 0.5)
		# Um grau ou dois de desalinho: fileira perfeita e maquete.
		var torto := (fposmod(float(postos * 7919 + semente) * 0.618, 1.0) - 0.5) * 0.08
		itens.append([sku, base, giro + torto])
		if recuo > 0.0:
			itens.append([sku, base + atras * recuo, giro - torto])
		postos += 1
		andou += larg + FOLGA
		na_marca += 1
		if na_marca >= por_marca:
			na_marca = 0
			marca += 1
	return postos


# --- no --------------------------------------------------------------------------

func _ready() -> void:
	var por_forma: Dictionary = {}
	for item: Array in itens:
		var forma := int(CatalogoMercado.produto(item[0]).get("forma", CatalogoMercado.Forma.CAIXA))
		if not por_forma.has(forma):
			por_forma[forma] = []
		(por_forma[forma] as Array).append(item)
	for forma: int in por_forma:
		var lista: Array = por_forma[forma]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = ProdutoMalhas.malha(forma)
		mm.instance_count = lista.size()
		for k in lista.size():
			var item: Array = lista[k]
			var md := CatalogoMercado.medida(item[0])
			var b := Basis(Vector3.UP, float(item[2]))
			mm.set_instance_transform(k,
				Transform3D(Basis(b.x * md.x, b.y * md.y, b.z * md.z), item[1]))
			var r := RotulosAtlas.celula(item[0])
			mm.set_instance_custom_data(k, Color(r.position.x, r.position.y,
				r.size.x, r.size.y))
		var mi := MultiMeshInstance3D.new()
		mi.name = "Forma%d" % forma
		mi.multimesh = mm
		mi.material_override = PrateleiraViva.material_produto()
		# Sombra de lata na prateleira e sub-pixel, e custa uma passada por forma.
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = ALCANCE
		add_child(mi)
