## A prateleira do mercado montada pelo buffer calculado na thread
## (`PrateleiraViva._calcular_produtos`) grava no MultiMesh EXATAMENTE o que o
## jeito antigo gravava, unidade por unidade (`set_instance_custom_data` e
## `set_instance_transform`), nas unidades e nas etiquetas de preco.
##
##     godot --path game --resolution 3840x2160 res://tests/verificar_prateleira_buffer.tscn -- --estilo=moderno
##
## Com janela: o buffer lido de volta e o da GPU. O jeito antigo esta copiado
## aqui (`_antigo`). Tres lojas, e em cada uma um terco das colunas esvaziado
## (a unidade some com escala zero). Compara buffer por forma e o mapa `_inst`.
extends Node


func _ready() -> void:
	add_child(Camera3D.new())
	(load("res://tests/aviso_de_bancada.gd") as GDScript).call(&"mostrar", self,
		"Prateleira do mercado: buffer da thread x unidade por unidade (~10 s).")
	_rodar()


func _rodar() -> void:
	await get_tree().process_frame
	var falhas := 0
	var formas := 0
	for semente: int in [11, 222, 3333]:
		var dados := LoteNoMundo.planta_de(&"mercado", semente)
		for prop: Dictionary in dados["props"]:
			if String(prop.get("tipo", "")) != "prateleira_viva":
				continue
			var pv := PrateleiraViva.criar(prop)
			var n := 0
			for v: Dictionary in pv.vagas:
				var cols: PackedInt32Array = v["colunas"]
				for c in cols.size():
					n += 1
					if n % 3 == 0:
						cols[c] = 0
				v["colunas"] = cols
			var contagem := {}
			for v: Dictionary in pv.vagas:
				var forma := int(CatalogoMercado.produto(v["sku"])["forma"])
				contagem[forma] = int(contagem.get(forma, 0)) + int(v["frentes"])
			var antigo := _antigo(pv, contagem)
			var saida := {}
			PrateleiraViva._calcular_produtos(pv.vagas, pv.faces, pv.loja, contagem, saida)
			var novos: Dictionary = saida["buffers"]
			for forma: int in contagem:
				formas += 1
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.use_custom_data = true
				mm.mesh = ProdutoMalhas.malha(forma)
				mm.instance_count = int(contagem[forma])
				mm.buffer = novos[forma]
				var a: PackedFloat32Array = (antigo["mm"][forma] as MultiMesh).buffer
				var b: PackedFloat32Array = mm.buffer
				if a != b:
					falhas += 1
					var dif := 0
					for i in mini(a.size(), b.size()):
						if a[i] != b[i]:
							dif += 1
					print("[prateleira] DIFERE loja=%d forma=%d tamanhos=%d/%d valores_diferentes=%d" % [
						semente, forma, a.size(), b.size(), dif])
			var me := MultiMesh.new()
			me.transform_format = MultiMesh.TRANSFORM_3D
			me.use_custom_data = true
			me.mesh = ProdutoMalhas.malha(ProdutoMalhas.ETIQUETA)
			me.instance_count = pv.vagas.size()
			me.buffer = saida["etiquetas"]
			formas += 1
			if (antigo["etiquetas"] as MultiMesh).buffer != me.buffer:
				falhas += 1
				print("[prateleira] ETIQUETAS DIFEREM loja=%d" % semente)
			if antigo["inst"] != saida["inst"]:
				falhas += 1
				print("[prateleira] _inst DIFERE loja=%d" % semente)
			pv.free()
	print("[prateleira] formas=%d falhas=%d" % [formas, falhas])
	print("[prateleira] %s" % ("OK" if falhas == 0 and formas > 0 else "FALHOU"))
	get_tree().quit(0 if falhas == 0 and formas > 0 else 1)


## O `_montar_produtos` de antes, unidade por unidade.
func _antigo(pv: PrateleiraViva, contagem: Dictionary) -> Dictionary:
	var mms := {}
	var usado := {}
	var inst := {}
	for forma: int in contagem:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = ProdutoMalhas.malha(forma)
		mm.instance_count = int(contagem[forma])
		mms[forma] = mm
		usado[forma] = 0
	for vi in pv.vagas.size():
		var v: Dictionary = pv.vagas[vi]
		var forma := int(CatalogoMercado.produto(v["sku"])["forma"])
		var r := RotulosAtlas.celula(v["sku"])
		var custom := Color(r.position.x, r.position.y, r.size.x, r.size.y)
		var cols: PackedInt32Array = v["colunas"]
		for c in int(v["frentes"]):
			var k: int = usado[forma]
			usado[forma] = k + 1
			inst[Vector2i(vi, c)] = Vector2i(forma, k)
			var mm: MultiMesh = mms[forma]
			mm.set_instance_custom_data(k, custom)
			if cols[c] <= 0:
				mm.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			else:
				mm.set_instance_transform(k, pv.call(&"_transformada", vi, c, 0.0))
	var et := MultiMesh.new()
	et.transform_format = MultiMesh.TRANSFORM_3D
	et.use_custom_data = true
	et.mesh = ProdutoMalhas.malha(ProdutoMalhas.ETIQUETA)
	et.instance_count = pv.vagas.size()
	for vi in pv.vagas.size():
		var v: Dictionary = pv.vagas[vi]
		var f: Dictionary = pv.faces[int(v["face"])]
		et.set_instance_transform(vi, Planograma.etiqueta(f, v))
		var r := RotulosAtlas.etiqueta(v["sku"])
		et.set_instance_custom_data(vi, Color(r.position.x, r.position.y, r.size.x, r.size.y))
	return {"mm": mms, "inst": inst, "etiquetas": et}
