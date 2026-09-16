## Onde a palheta do limpador passa, de verdade.
##
##     godot --headless --path game --script res://tests/medir_limpador.gd
##
## Por que existe
## --------------
## O criterio C7 do PLANO_CHUVA_CABINE_AAA: a ponta da palheta tem de ficar NO
## plano do vidro durante o curso inteiro. Medido em 16/09/2026, antes da Fase 4,
## a ponta ficava em (±0,30; 0,94; -1,355) no repouso, no meio e no fim do curso
## — parada, deitada no capo, 42 cm a frente da base do vidro. A palheta nasce ao
## longo de -Z e o pivo gira em Z, ou seja, em torno do proprio comprimento.
##
## Um angulo que muda nao prova movimento: o que prova e a PONTA. Ver a memoria
## do projeto "animacao se mede pela ponta".
extends SceneTree

## Passos de fase do limpador a medir, em fracao da passada.
const PASSOS := [0.0, 0.25, 0.5, 0.75, 1.0]


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	for modelo: int in [Carroceria.Modelo.MAREA, Carroceria.Modelo.FUSCA,
			Carroceria.Modelo.SEDA]:
		_medir(modelo)
	quit(0)


func _medir(modelo: int) -> void:
	var medidas := Carroceria.montar(modelo, CarroCena.TINTA, CarroCena.SEMENTE)
	var cab := CarroCabine.new()
	root.add_child(cab)
	cab.montar(medidas)
	var base: Vector2 = medidas["vidro_base"]
	var topo: Vector2 = medidas["vidro_topo"]
	print("\n=== modelo %d: vidro de (z %.2f, y %.2f) a (z %.2f, y %.2f) ===" % [
		modelo, base.x, base.y, topo.x, topo.y])

	var passada := CarroCabine.LIMPADOR_PASSADA.y
	var visitados: Array[Vector3] = []
	for k in PASSOS.size():
		# `limpar` anda a fase pelo delta; o primeiro passo entra no repouso.
		var delta := passada * (float(PASSOS[k]) - (0.0 if k == 0 else float(PASSOS[k - 1])))
		cab.limpar(1.0, 0.0, delta)
		for nome: String in ["LimpadorE", "LimpadorD"]:
			var p := cab.get_node_or_null(nome) as Node3D
			if p == null:
				continue
			var ponta: Vector3 = p.transform * Vector3(0.0, 0.004, -CarroCabine.LIMPADOR_COMP)
			var no_vidro := absf(ponta.z - cab.z_do_vidro(ponta.y))
			if nome == "LimpadorE":
				visitados.append(ponta)
			print("  fase %.2f  %s  giro %+6.1f  ponta (%.3f, %.3f, %.3f)  distancia ao plano do vidro %.3f m" % [
				float(PASSOS[k]), nome, p.rotation_degrees.z, ponta.x, ponta.y,
				ponta.z, no_vidro])

	var caminho := 0.0
	for i in range(1, visitados.size()):
		caminho += visitados[i].distance_to(visitados[i - 1])
	print("  -- a ponta esquerda percorreu %.3f m no curso inteiro (C7 pede um leque no vidro)" % caminho)
	cab.queue_free()
