## Silhueta exata do Fusca, tirada da malha e nao de pixel.
##
## Medir a lateral por captura sempre erra: o pneu escuro cai fora de um limiar
## de brilho, o fundo com vinheta da ref cai dentro de uma mascara por cor, e a
## perspectiva da vitrine levanta o para-lama do lado de ca. Aqui o numero sai
## do vertice, entao so sobra o erro da REF — que e o que se quer medir.
extends SceneTree

const FATIAS := 21

func _init() -> void:
	# Carrega o modulo ANTES de medir. Carroceria resolve fusca/marea com load()
	# em runtime, entao erro de parse neles NAO aparece em `--headless --quit`:
	# o projeto sobe limpo e o carro sai pela metade. Ja aconteceu duas vezes.
	for caminho: String in ["res://src/render/carroceria_fusca.gd",
			"res://src/render/carroceria_marea.gd",
			"res://src/render/carroceria_caixa.gd"]:
		if not ResourceLoader.exists(caminho):
			continue
		# Script com erro de parse ainda devolve objeto em load(); o que fica
		# vazio e a lista de metodos. E por ela que se sabe que ele quebrou.
		var m := load(caminho) as GDScript
		if m == null or m.get_script_method_list().is_empty():
			push_error("modulo nao carregou: " + caminho)
			print("FALHA: %s nao carregou" % caminho)
			quit(1)
			return
	var d := Carroceria.montar(Carroceria.Modelo.FUSCA,
		Carroceria.TINTA_FUSCA, 3)
	var malha: ArrayMesh = d["corpo"]
	var v: PackedVector3Array = malha.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var zmin := INF
	var zmax := -INF
	var ymax := -INF
	for p in v:
		zmin = minf(zmin, p.z)
		zmax = maxf(zmax, p.z)
		ymax = maxf(ymax, p.y)
	# Amostra por TRAVESSIA DE ARESTA, nao por vertice. Vertice e esparso: entre
	# duas estacoes do perfil nao ha nenhum, e binar por proximidade fazia a
	# curva serrilhar 40 pontos percentuais de uma fatia para a outra.
	var idx: PackedInt32Array = malha.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	var alturas: Array[float] = []
	for k in FATIAS:
		alturas.append(-INF)
	for k in FATIAS:
		var z: float = zmin + (zmax - zmin) * float(k) / float(FATIAS - 1)
		var t := 0
		while t < idx.size():
			for e in 3:
				var a: Vector3 = v[idx[t + e]]
				var b: Vector3 = v[idx[t + (e + 1) % 3]]
				if (a.z - z) * (b.z - z) > 0.0:
					continue
				if is_equal_approx(a.z, b.z):
					alturas[k] = maxf(alturas[k], maxf(a.y, b.y))
					continue
				var f: float = (z - a.z) / (b.z - a.z)
				alturas[k] = maxf(alturas[k], lerpf(a.y, b.y, f))
			t += 3
	print("comp %.3f  altura %.3f" % [zmax - zmin, ymax])
	var linha := PackedStringArray()
	for k in FATIAS:
		linha.append("%.4f" % (alturas[FATIAS - 1 - k] / ymax))
	print("PERFIL_FRACAO " + ",".join(linha))
	quit()
