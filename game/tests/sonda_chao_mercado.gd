## O chao da quadra furando o piso e as paredes da loja, loja por loja.
##
##     godot --headless --path game --script res://tests/sonda_chao_mercado.gd
##
## Com os morros, a loja assenta na ladeira e o chao da quadra (que segue o
## relevo) passa por baixo dela. O `PredioMercado.afundar_chao` rebaixa o que
## esta dentro da pegada; esta sonda confere, triangulo por triangulo, que nada
## de chao ficou acima do piso dentro da loja. Amostra cada triangulo numa grade
## baricentrica (a quina de um triangulo grande pode estar dentro sem nenhum
## vertice dentro — era esse o defeito).
##
## Sai com codigo 1 se algum triangulo passa de 1 cm acima do piso.
extends SceneTree

## Superficies que sao chao da quadra, e nao da loja.
const CHAO: Array[StringName] = [&"terra", &"grama", &"calcada", &"asfalto",
	&"barro", &"mato", &"paralelepipedo", &"cascalho", &"leito"]
const LIMITE := 0.01


func _initialize() -> void:
	process_frame.connect(_rodar, CONNECT_ONE_SHOT)


func _rodar() -> void:
	var CB: GDScript = load("res://src/world/chunk_builder.gd")
	var MB: GDScript = load("res://src/world/mercado_builder.gd")
	var lojas := 0
	var furadas := 0
	var pior := 0.0
	var por_sup: Dictionary = {}
	for cx in range(-12, 13):
		for cz in range(-12, 13):
			var tem := false
			for ponto: Dictionary in CB.pontos_de_interesse(cx, cz):
				if ponto.get("interior", &"") == &"mercado" and bool(ponto.get("mundo", false)):
					tem = true
			if not tem:
				continue
			var dados: Dictionary = CB.construir(cx, cz)
			var planta := Transform3D()
			var achou := false
			for prop: Dictionary in dados["props"]:
				if prop.get("tipo", "") == "interior_mundo" and prop.get("interior", &"") == &"mercado":
					planta = prop["planta"]
					achou = true
			if not achou:
				continue
			lojas += 1
			var inv := planta.affine_inverse()
			var sup: Dictionary = dados["superficies"]
			var furou := 0.0
			for nome: StringName in sup:
				if not CHAO.has(nome):
					continue
				var d: Dictionary = sup[nome]
				var vs: PackedVector3Array = d["v"]
				var idx: PackedInt32Array = d["i"]
				for t in range(0, idx.size(), 3):
					var a := inv * vs[idx[t]]
					var b := inv * vs[idx[t + 1]]
					var c := inv * vs[idx[t + 2]]
					for i in 7:
						for j in 7 - i:
							var u := float(i) / 6.0
							var v := float(j) / 6.0
							var p := a + (b - a) * u + (c - a) * v
							if p.x > 0.02 and p.x < MB.LARGURA - 0.02 and p.z > 0.02 \
									and p.z < MB.FUNDO - 0.02 and p.y > LIMITE and p.y < 3.0:
								furou = maxf(furou, p.y)
								por_sup[nome] = maxf(float(por_sup.get(nome, 0.0)), p.y)
			if furou > 0.0:
				furadas += 1
				print("loja (%d,%d): chao %.2f m acima do piso" % [cx, cz, furou])
			pior = maxf(pior, furou)
	print("lojas=%d" % lojas)
	print("lojas_furadas=%d" % furadas)
	print("pior_m=%.2f" % pior)
	print("por_superficie=%s" % por_sup)
	quit(1 if furadas > 0 else 0)
