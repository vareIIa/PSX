## Bancada da planta do Horizonte: quanto custa e se ela descreve a cidade.
##
##     godot --headless --path game res://tests/bancada_horizonte.tscn -- --saida=DIR
##     ... -- --centro=-5,-3     chunk do meio do quadrado (padrao: avenida x = -160)
##     ... -- --lado=5           chunks por lado
##
## Para cada chunk do quadrado mede `ChunkBuilder.construir` e a leitura da
## planta separados, e salva duas imagens vistas de cima (norte para cima, um
## pixel da imagem por ponto de 2 m): a cor do topo e a altura do topo menos a
## do chao (predio claro, rua preta). Imprime `[horizonte] chave=valor`.
##
##     ... -- --malha            uma celula de cada nivel (0 a 6) em volta do
##                               centro: tempo da grade e da malha, vertices,
##                               triangulos e as imagens da grade de cada uma
##     ... -- --paleta           constroi ~600 chunks espalhados e compara a
##                               planta exata com a aproximada (cobertura de
##                               predio, altura); grava a distribuicao real das
##                               cores de parede e telhado por distrito em
##                               resources/horizonte/paleta_aproximada.json
extends Node

var _saida := ""
var _centro := Vector2i(-5, -3)
var _lado := 5
## `--aproximada`: a planta de longe (HorizonteDados.aproximar), sem construir.
var _aproximada := false
var _malha := false
var _paleta := false


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
		elif arg.begins_with("--centro="):
			var p := arg.trim_prefix("--centro=").split(",")
			_centro = Vector2i(int(p[0]), int(p[1]))
		elif arg == "--aproximada":
			_aproximada = true
		elif arg == "--malha":
			_malha = true
		elif arg == "--paleta":
			_paleta = true
		elif arg.begins_with("--lado="):
			_lado = int(arg.trim_prefix("--lado="))
	await get_tree().process_frame
	HorizonteDados.preparar()
	if _malha:
		_medir_malhas()
		get_tree().quit(0)
		return
	if _paleta:
		_calibrar_paleta()
		get_tree().quit(0)
		return
	var t_construir := PackedFloat32Array()
	var t_planta := PackedFloat32Array()
	var n := _lado * HorizonteDados.LADO
	var cor := Image.create(n, n, false, Image.FORMAT_RGB8)
	var alt := Image.create(n, n, false, Image.FORMAT_RGB8)
	var predio := 0
	var copa := 0
	var parede := 0
	var meio := _lado / 2
	for j in _lado:
		for i in _lado:
			var c := _centro + Vector2i(i - meio, j - meio)
			var t0 := Time.get_ticks_usec()
			var dados := {} if _aproximada else ChunkBuilder.construir(c.x, c.y)
			var t1 := Time.get_ticks_usec()
			var planta := HorizonteDados.aproximar(c.x, c.y, HorizonteDados.LADO) if _aproximada 				else HorizonteDados.planta_de(dados["superficies"], c.x, c.y)
			var t2 := Time.get_ticks_usec()
			t_construir.append((t1 - t0) / 1000.0)
			t_planta.append((t2 - t1) / 1000.0)
			for pz in HorizonteDados.LADO:
				for px in HorizonteDados.LADO:
					var x := i * HorizonteDados.LADO + px
					var y := j * HorizonteDados.LADO + pz
					cor.set_pixel(x, y, HorizonteDados.cor_topo_de(planta, pz * HorizonteDados.LADO + px).linear_to_srgb())
					var dh := HorizonteDados.topo_de(planta, pz * HorizonteDados.LADO + px) \
						- HorizonteDados.chao_de(planta, pz * HorizonteDados.LADO + px)
					alt.set_pixel(x, y, Color.from_hsv(0.0, 0.0, clampf(dh / 20.0, 0.0, 1.0)))
					var cls := HorizonteDados.classe_de(planta, pz * HorizonteDados.LADO + px)
					if cls & 0x7F == HorizonteDados.Classe.PREDIO:
						predio += 1
					elif cls & 0x7F == HorizonteDados.Classe.COPA:
						copa += 1
					if cls & HorizonteDados.TEM_PAREDE:
						parede += 1
	t_construir.sort()
	t_planta.sort()
	var k := t_planta.size()
	print("[horizonte] chunks=%d construir_ms mediana=%.1f pior=%.1f | planta_ms mediana=%.1f pior=%.1f" % [
		k, t_construir[k / 2], t_construir[k - 1], t_planta[k / 2], t_planta[k - 1]])
	var total := k * HorizonteDados.LADO * HorizonteDados.LADO
	print("[horizonte] pontos=%d predio=%.0f%% copa=%.0f%% com_parede=%.0f%% bytes_por_chunk=%d" % [
		total, 100.0 * predio / total, 100.0 * copa / total, 100.0 * parede / total,
		HorizonteDados.TOTAL])
	if not _saida.is_empty():
		cor.resize(n * 4, n * 4, Image.INTERPOLATE_NEAREST)
		alt.resize(n * 4, n * 4, Image.INTERPOLATE_NEAREST)
		var sufixo := "_aprox" if _aproximada else ""
		cor.save_png(_saida.path_join("planta_cor%s.png" % sufixo))
		alt.save_png(_saida.path_join("planta_altura%s.png" % sufixo))
		print("[horizonte] imagens=%s" % _saida)
	get_tree().quit(0)


## Uma celula por nivel, a que contem o centro: a grade (plantas exatas no
## nivel 0 e 1, construidas aqui) e a malha, como o fio de malhas faz.
func _medir_malhas() -> void:
	var hz := Horizonte.new(0.0)
	for nivel in 7:
		var n := Horizonte._lado_chunks(nivel)
		var k := Vector3i(nivel, floori(float(_centro.x) / n), floori(float(_centro.y) / n))
		var t_exatas := 0.0
		if nivel < Horizonte.NIVEL_EXATO:
			var t0 := Time.get_ticks_usec()
			for j in n:
				for i in n:
					var c := Vector2i(k.y * n + i, k.z * n + j)
					hz._plantas[c] = HorizonteDados.amostrar(c.x, c.y)
			t_exatas = (Time.get_ticks_usec() - t0) / 1000.0
		var t1 := Time.get_ticks_usec()
		var g: Array = hz._grade(k)
		var t2 := Time.get_ticks_usec()
		var malha := HorizonteMalha.montar(g[0], Horizonte._passo(nivel), g[1], g[2],
			Horizonte.RECUO if nivel >= Horizonte.NIVEL_MEDIA else 0.0)
		var t3 := Time.get_ticks_usec()
		var verts := 0 if malha == null else malha.surface_get_array_len(0)
		var tris := 0 if malha == null else malha.surface_get_array_index_len(0) / 3
		print("[horizonte] nivel=%d chunks=%d passo_m=%.0f exatas_ms=%.0f grade_ms=%.1f malha_ms=%.1f vertices=%d triangulos=%d lampadas=%d formato=%d" % [
			nivel, n * n, Horizonte._passo(nivel), t_exatas, (t2 - t1) / 1000.0,
			(t3 - t2) / 1000.0, verts, tris, (g[1] as PackedVector3Array).size(),
			0 if malha == null else malha.surface_get_format(0)])
		if not _saida.is_empty():
			_imagens_da_grade(g[0], "nivel%d" % nivel)
	hz.free()


func _imagens_da_grade(grade: PackedByteArray, nome: String) -> void:
	var l := HorizonteMalha.G
	var cor := Image.create(l, l, false, Image.FORMAT_RGB8)
	var alt := Image.create(l, l, false, Image.FORMAT_RGB8)
	for pz in l:
		for px in l:
			var p := pz * l + px
			cor.set_pixel(px, pz, HorizonteDados.cor_topo_de(grade, p).linear_to_srgb())
			var h := clampf((HorizonteDados.topo_de(grade, p) - HorizonteDados.chao_de(grade, p)) / 20.0, 0.0, 1.0)
			alt.set_pixel(px, pz, Color(h, h, h))
	cor.resize(l * 4, l * 4, Image.INTERPOLATE_NEAREST)
	alt.resize(l * 4, l * 4, Image.INTERPOLATE_NEAREST)
	cor.save_png(_saida.path_join("grade_cor_%s.png" % nome))
	alt.save_png(_saida.path_join("grade_altura_%s.png" % nome))


## Por distrito: as cores de parede e telhado das plantas exatas (sorteadas, na
## frequencia em que aparecem) e a cobertura e a altura dos predios, exata e
## aproximada, para a aproximada ser a mesma cidade de longe.
func _calibrar_paleta() -> void:
	const PASSO := 5
	const RAIO := 60
	const AMOSTRAS := 48
	var dados := {}
	var t0 := Time.get_ticks_msec()
	for cz in range(-RAIO, RAIO + 1, PASSO):
		for cx in range(-RAIO, RAIO + 1, PASSO):
			var q := MalhaUrbana.quadra_de(cx, cz)
			if int(q["uso"]) != MalhaUrbana.Uso.EDIFICADO:
				continue
			var d := int(q["distrito"])
			if not dados.has(d):
				dados[d] = {"paredes": [], "telhados": [],
					"chunks": 0, "exata_px": 0, "exata_h": 0.0, "aprox_px": 0, "aprox_h": 0.0,
					"andares": 0.0}
			var e: Dictionary = dados[d]
			var exata := HorizonteDados.amostrar(cx, cz)
			var aprox := HorizonteDados.aproximar(cx, cz, HorizonteDados.LADO)
			e["chunks"] += 1
			e["andares"] += float(q["andares"])
			for p in HorizonteDados.LADO * HorizonteDados.LADO:
				var cls := HorizonteDados.classe_de(exata, p)
				var h := HorizonteDados.topo_de(exata, p) - HorizonteDados.chao_de(exata, p)
				if cls & 0x7F == HorizonteDados.Classe.PREDIO and h >= HorizonteMalha.BLOCO_MIN:
					e["exata_px"] += 1
					e["exata_h"] += h
					(e["telhados"] as Array).append(HorizonteDados.cor_topo_de(exata, p))
					if cls & HorizonteDados.TEM_PAREDE:
						(e["paredes"] as Array).append(HorizonteDados.cor_parede_de(exata, p))
				var ca := HorizonteDados.classe_de(aprox, p)
				var ha := HorizonteDados.topo_de(aprox, p) - HorizonteDados.chao_de(aprox, p)
				if ca & 0x7F == HorizonteDados.Classe.PREDIO and ha >= HorizonteMalha.BLOCO_MIN:
					e["aprox_px"] += 1
					e["aprox_h"] += ha
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260925
	var saida := {}
	for d: int in dados:
		var e: Dictionary = dados[d]
		var n := float(e["chunks"]) * HorizonteDados.LADO * HorizonteDados.LADO
		print("[horizonte] paleta distrito=%d chunks=%d andares=%.1f cobertura exata=%.2f aprox=%.2f | altura exata=%.1f aprox=%.1f | paredes=%d telhados=%d" % [
			d, e["chunks"], float(e["andares"]) / e["chunks"],
			e["exata_px"] / n, e["aprox_px"] / n,
			float(e["exata_h"]) / maxi(1, e["exata_px"]), float(e["aprox_h"]) / maxi(1, e["aprox_px"]),
			(e["paredes"] as Array).size(), (e["telhados"] as Array).size()])
		var paredes := []
		var telhados := []
		for lista_e_saida: Array in [[e["paredes"], paredes], [e["telhados"], telhados]]:
			var lista: Array = lista_e_saida[0]
			var destino: Array = lista_e_saida[1]
			for i in mini(AMOSTRAS, lista.size()):
				var c: Color = (lista[rng.randi_range(0, lista.size() - 1)] as Color).linear_to_srgb()
				destino.append([snappedf(c.r, 0.001), snappedf(c.g, 0.001), snappedf(c.b, 0.001)])
		saida[str(d)] = {
			"paredes": paredes, "telhados": telhados,
			"cobertura": snappedf(float(e["exata_px"]) / n, 0.001),
			"altura_media": snappedf(float(e["exata_h"]) / maxi(1, e["exata_px"]), 0.01),
			"andares_medio": snappedf(float(e["andares"]) / e["chunks"], 0.01),
		}
	var f := FileAccess.open("res://resources/horizonte/paleta_aproximada.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(saida))
	f.close()
	print("[horizonte] paleta gravada em %.0f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
