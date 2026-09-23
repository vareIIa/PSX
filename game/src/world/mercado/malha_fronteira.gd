## A malha que fica na fronteira entre a rua e uma casa que existe na rua.
##
## Por que nao e malha do chunk
## ----------------------------
## Luz de dentro so acende a camada de dentro (InteriorNoMundo.CAMADA), e luz de
## rua nao acende a de dentro: e o que impede a lampada do caixa de pintar a
## calcada e o poste de pintar o piso da loja. Mas a vitrine, os montantes e os
## pilares sao vistos dos dois lados. Na malha fundida do chunk eles ficam so na
## camada da rua, e o caixa, olhando para a porta, ve a moldura inteira preta
## contra o salao aceso.
##
## Aqui eles ficam num no proprio, nas DUAS camadas: o poste acende a face de
## fora, a calha acende a de dentro. Custa uma malha por material a mais no
## chunk, e so no chunk que tem a loja.
##
## Montada em coordenada de planta, com a transformada do lote: a mesma que o
## `InteriorNoMundo` usa, entao frente e sala nao tem como se desencontrar. Na
## ladeira o Relevo ergue a transformada junto com o resto do lote.
class_name MalhaFronteira
extends Node3D

var superficies: Dictionary = {}
var colisao: Array = []
## Quem entrega o material pelo nome. O do ChunkManager, que e o dono da
## biblioteca de materiais da rua.
var material_de: Callable


func _ready() -> void:
	var camadas := 1 | InteriorNoMundo.CAMADA
	for nome: StringName in superficies:
		var d: Dictionary = superficies[nome]
		if PSXMesh.dados_vazio(d):
			continue
		var mi := MeshInstance3D.new()
		mi.name = String(nome)
		mi.mesh = PSXMesh.dados_para_mesh(d)
		mi.material_override = material_de.call(nome)
		mi.layers = camadas
		mi.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if Interiores.projeta(nome) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		add_child(mi)

	if colisao.is_empty():
		return
	var corpo := StaticBody3D.new()
	corpo.name = "Colisao"
	for caixa: Dictionary in colisao:
		var forma := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = caixa["tamanho"]
		forma.shape = box
		forma.position = caixa["pos"]
		corpo.add_child(forma)
	add_child(corpo)
