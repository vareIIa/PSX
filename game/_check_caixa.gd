## Garante que os cinco carros de caixa montam e que a roda nao nasceu por dentro.
extends SceneTree

func _init() -> void:
	var mod := load("res://src/render/carroceria_caixa.gd") as GDScript
	if mod == null or mod.get_script_method_list().is_empty():
		print("FALHA: carroceria_caixa.gd nao carregou")
		quit(1)
		return
	var modelos: Array[int] = [
		int(Carroceria.Modelo.SEDA), int(Carroceria.Modelo.HATCH),
		int(Carroceria.Modelo.PERUA), int(Carroceria.Modelo.PICAPE),
		int(Carroceria.Modelo.TAXI),
	]
	var falhou := false
	for modelo: int in modelos:
		var d: Dictionary = Carroceria.montar(modelo as Carroceria.Modelo,
			Color(0.82, 0.80, 0.76), 3)
		if d.get("corpo") == null or d.get("eixo_frente") == null:
			print("FALHA: modelo %d sem malha" % modelo)
			falhou = true
			continue
		var corpo: ArrayMesh = d["corpo"]
		var eixo: ArrayMesh = d["eixo_frente"]
		if corpo.get_surface_count() < 1 or eixo.get_surface_count() < 1:
			print("FALHA: modelo %d surface vazia" % modelo)
			falhou = true
			continue
		var vc: PackedVector3Array = corpo.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var ve: PackedVector3Array = eixo.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var ex := 0.0
		var nan_c := 0
		for p: Vector3 in vc:
			if not p.is_finite():
				nan_c += 1
		for p: Vector3 in ve:
			if not p.is_finite():
				nan_c += 1
			ex = maxf(ex, absf(p.x))
		if nan_c > 0:
			print("FALHA: modelo %d tem %d vertices NaN" % [modelo, nan_c])
			falhou = true
		var tris := int(d["triangulos"])
		var larg := float(d["largura"])
		var bitola := float(d["bitola"])
		print("[caixa] %d tris=%d larg=%.2f bitola=%.2f roda_x=%.2f"
			% [modelo, tris, larg, bitola, ex])
		if tris < 200:
			print("FALHA: modelo %d com %d tris" % [modelo, tris])
			falhou = true
		if ve.is_empty():
			print("FALHA: modelo %d sem vertices de roda" % modelo)
			falhou = true
		# A roda tem que nascer perto da meia-largura, nao enfiada no casco.
		if ex < larg * 0.32:
			print("FALHA: modelo %d roda enfiada (x=%.2f larg=%.2f)"
				% [modelo, ex, larg])
			falhou = true
	quit(1 if falhou else 0)
