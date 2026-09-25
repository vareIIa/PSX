## Sonda temporaria do cerco: quanto custa refazer um BracoVivo podre.
extends Node

func _ready() -> void:
	var b := BracoVivo.criar("Teste", true, Color("6c6f68"), Color("1c1a18"), true)
	MaosPodres.vestir(b)
	add_child(b)
	b.visible = true
	b.ombro = Vector3(0.2, 1.4, 0.0)
	b.polo = Vector3.DOWN
	b.pular(BracoVivo.pega(Vector3(0.3, 0.95, -0.45), Vector3(0.0, 0.0, -1.0), Vector3.UP, &"apoio_forca"))
	for i in 5:
		b.refazer()
	var t0 := Time.get_ticks_usec()
	for i in 40:
		b.ombro.y = 1.4 + 0.001 * i
		b.refazer()
	var t1 := Time.get_ticks_usec()
	print("[custo] BracoVivo podre refazer: %.2f ms" % ((t1 - t0) / 40000.0))
	var m := b.mesh as ArrayMesh
	print("[custo] triangulos: %d" % (m.surface_get_array_len(0) / 3 if m.surface_get_array_index_len(0) <= 0 else m.surface_get_array_index_len(0) / 3))
	# So a mao (MaoPosada.montar) sem o braco de cima.
	var t2 := Time.get_ticks_usec()
	for i in 40:
		var dados := PSXMesh.dados_vazios()
		MaoModelada.forma = MaosPodres.FORMA
		MaoPosada.montar(dados, Vector3(0.3, 0.95, -0.45), Vector3(0.0, 0.0, -1.0), Vector3.UP, MaoPosada.pose(&"apoio_forca"), true, Vector3(0.3, 1.2, -0.2), Color("6c6f68"), Color("1c1a18"), true)
		MaoModelada.forma = {}
	var t3 := Time.get_ticks_usec()
	print("[custo] so MaoPosada.montar: %.2f ms" % ((t3 - t2) / 40000.0))
	var t4 := Time.get_ticks_usec()
	for i in 40:
		var dados := PSXMesh.dados_vazios()
		MaoModelada.forma = MaosPodres.FORMA
		MaoPosada.montar(dados, Vector3(0.3, 0.95, -0.45), Vector3(0.0, 0.0, -1.0), Vector3.UP, MaoPosada.pose(&"apoio_forca"), true, Vector3(0.3, 1.2, -0.2), Color("6c6f68"), Color("1c1a18"), true)
		MaoModelada.forma = {}
		var _m := PSXMesh.dados_para_mesh(dados)
	var t5 := Time.get_ticks_usec()
	print("[custo] montar + dados_para_mesh: %.2f ms" % ((t5 - t4) / 40000.0))
	get_tree().quit(0)
