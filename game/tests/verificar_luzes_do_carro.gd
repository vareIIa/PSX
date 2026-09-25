## As luzes do carro montadas pelos dados de origem (`luzes_dados`) sao as
## mesmas que a leitura de volta da GPU dava (`surface_get_arrays`).
##
##     godot --path game --resolution 3840x2160 res://tests/verificar_luzes_do_carro.tscn -- --estilo=moderno
##
## Com janela: sem GPU a leitura de volta nao arredonda nada e o teste nao prova
## nada. Para cada modelo e 20 sementes (com e sem amassado de fabrica):
## posicao, UV e indice iguais bit a bit; cor ate 1/255 e normal ate o
## arredondamento da GPU; e os indices de farol, lanterna e pisca que o `Carro`
## tira deles, e os pontos de farol (`Carroceria.farois`), iguais.
## Imprime `[luzes] ...` e sai 1 se algo diferir.
extends Node


func _ready() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	(load("res://tests/aviso_de_bancada.gd") as GDScript).call(&"mostrar", self,
		"Luzes do carro: dados de origem x leitura da GPU (~10 s).")
	_rodar()


func _rodar() -> void:
	await get_tree().process_frame
	var falhas := 0
	var casos := 0
	var sem_dados := 0
	var pior_cor := 0.0
	var pior_normal := 0.0
	for modelo: int in Carroceria.Modelo.values():
		for n in 20:
			var semente := 1000 + n * 7919
			var amassados: Array = []
			if n % 2 == 1:
				var c := Carro.new()
				c.semente = semente
				c.modelo = modelo
				amassados = c.call(&"_amassados_de_fabrica")
				c.free()
			var tinta: Color = Carroceria.TINTAS[n % Carroceria.TINTAS.size()]
			var m := Carroceria.montar(modelo, tinta, semente, true, true, amassados)
			var origem: Dictionary = m.get("luzes_dados", {})
			if origem.is_empty():
				sem_dados += 1
				continue
			casos += 1
			var lida: Array = (m["luzes"] as ArrayMesh).surface_get_arrays(0)
			var nova: Array = Carro._arrays_das_luzes(origem)
			var ok := true
			for k: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]:
				if lida[k] != nova[k]:
					ok = false
					print("[luzes] DIFERE modelo=%d semente=%d array=%d" % [modelo, semente, k])
			var cl: PackedColorArray = lida[Mesh.ARRAY_COLOR]
			var cn: PackedColorArray = nova[Mesh.ARRAY_COLOR]
			if cl.size() != cn.size():
				ok = false
			else:
				for i in cl.size():
					var d := maxf(maxf(absf(cl[i].r - cn[i].r), absf(cl[i].g - cn[i].g)),
						maxf(absf(cl[i].b - cn[i].b), absf(cl[i].a - cn[i].a)))
					pior_cor = maxf(pior_cor, d)
			var nl: PackedVector3Array = lida[Mesh.ARRAY_NORMAL]
			var nn: PackedVector3Array = nova[Mesh.ARRAY_NORMAL]
			if nl.size() != nn.size():
				ok = false
			else:
				for i in nl.size():
					pior_normal = maxf(pior_normal, (nl[i] - nn[i]).length())
			if Carroceria.farois(lida, lida[Mesh.ARRAY_TEX_UV]) \
					!= Carroceria.farois(nova, nova[Mesh.ARRAY_TEX_UV]):
				ok = false
				print("[luzes] FAROIS DIFEREM modelo=%d semente=%d" % [modelo, semente])
			if not ok:
				falhas += 1
	if pior_cor > 1.0 / 255.0 + 0.0001 or pior_normal > 0.01:
		falhas += 1
	print("[luzes] casos=%d sem_luzes_dados=%d falhas=%d pior_cor=%.5f (1/255=%.5f) pior_normal=%.5f" % [
		casos, sem_dados, falhas, pior_cor, 1.0 / 255.0, pior_normal])
	print("[luzes] %s" % ("OK" if falhas == 0 and casos > 0 else "FALHOU"))
	get_tree().quit(0 if falhas == 0 and casos > 0 else 1)
