## O custo de redesenhar a marca de pneu (`RastroPneu._reconstruir`), sozinho.
##
##     godot --path game res://tests/bancada_rastro_pneu.tscn -- --medir
##
## Fases de 60 redesenhos, um por quadro, com 150 pedacos de marca e bafos de
## fumaca vivos:
##
##   solta         so o que o `RastroPneu` segura (antes de 24/09/2026 era
##                 nada: 37,5 ms por redesenho; com o cache dele, 0,12 ms)
##   segurando     os dois materiais seguros tambem por uma referencia de fora
##   solta_de_novo a primeira de novo, para a ordem nao decidir a medida
##
## Imprime `[rastro] fase=... mediana p95 pior` e em quantos redesenhos o
## material da marca ainda estava no cache do ResourceLoader antes da chamada.
## Com a marca viva, o `_reconstruir` roda 20 vezes por segundo: e o que sai
## daqui vezes 20 que o carro do jogador pagava por segundo dirigindo.
extends Node3D


func _ready() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.0, 4.0, 12.0)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	add_child(DirectionalLight3D.new())
	await get_tree().process_frame

	var r := RastroPneu.new()
	add_child(r)
	for k in 150:
		var a := k * 0.02
		r._marcar(Vector3(cos(a), 0.0, sin(a)) * 8.0,
			Vector3(cos(a + 0.02), 0.0, sin(a + 0.02)) * 8.0, Vector3.UP, 0.8)
	var so_uma := OS.get_cmdline_user_args().has("--so-solta")
	var fases: Array[String] = ["solta"]
	if not so_uma:
		fases.append_array(["segurando", "solta_de_novo"])
	for fase in fases:
		var seguros: Array[Material] = []
		if fase == "segurando":
			seguros = [load(RastroPneu.MAT_MARCA) as Material,
				load(RastroPneu.MAT_FUMACA) as Material]
		var tempos := PackedFloat32Array()
		var em_cache := 0
		for i in 60:
			await get_tree().process_frame
			if i % 8 == 0:
				for b in 3:
					r._bafejar(Vector3(b, 0.0, 0.0), Vector3.ZERO, 0.8)
			if ResourceLoader.has_cached(RastroPneu.MAT_MARCA):
				em_cache += 1
			var t := Time.get_ticks_usec()
			r._reconstruir()
			tempos.append(float(Time.get_ticks_usec() - t) / 1000.0)
		seguros.clear()
		tempos.sort()
		print("[rastro] fase=%s n=%d mediana=%.3f p95=%.3f pior=%.3f material_em_cache=%d/%d" % [
			fase, tempos.size(), tempos[tempos.size() / 2],
			tempos[int(tempos.size() * 0.95)], tempos[tempos.size() - 1], em_cache, tempos.size()])
	get_tree().quit(0)
