extends Node
# Bancada: custo de montar um trecho da estrada (ms na thread, triangulos por balde, impostores).


func _ready() -> void:
	var eb := EstradaBuilder.new()
	var soma := {}
	var t_total := 0
	var n := 8
	for i in range(2, 2 + n):
		var t0 := Time.get_ticks_usec()
		var sup: Dictionary = eb._dados_do_trecho(i)
		t_total += Time.get_ticks_usec() - t0
		for k: StringName in sup:
			if String(k).begins_with("@"):
				if not sup[k] is Dictionary:
					continue
				var dd: Dictionary = sup[k]
				for nome: StringName in dd:
					soma["imp:" + String(nome)] = int(soma.get("imp:" + String(nome), 0)) + (dd[nome] as PackedFloat32Array).size() / 16
				continue
			soma[String(k)] = int(soma.get(String(k), 0)) + PSXMesh.dados_triangulos(sup[k])
	print("[custo] %.1f ms por trecho" % (t_total / 1000.0 / n))
	for k: String in soma:
		print("[custo] %s %d por trecho" % [k, int(soma[k]) / n])
	eb.free()
	get_tree().quit()
