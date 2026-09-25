## A mao que segura o iPhone do jogo, de perto, e o gesto de tirar do bolso e
## guardar quadro a quadro: o rig anda com passo fixo (1/30 s) comandado daqui,
## e cada quadro sai numa rajada `r_<tempo>.png` (para `tools/mosaico_rajada.py`).
##
##     godot --path game --resolution 1920x1080 res://tests/bancada_mao_celular.tscn -- --saida=<DIR ABSOLUTO> [--so=perto|puxar|guardar|balanco|mapa]
##
## Fotos: `10_leitura` (o quadro inteiro), `11_zoom_*` (da lente do jogador com
## FOV fechado: os dedos na lateral esquerda, o polegar na direita, o calcanhar
## da mao), `20_de_perto` (seis cameras em volta do aparelho) e as rajadas
## `puxar/` e `guardar/`. `--so=mapa`: a rajada `mapa/` do aparelho deitando
## perto da lente, `40_mapa_de_perto` e o tempo de GPU da tela deitada.
extends Node

const PASSO := 1.0 / 30.0
const BancadaJogo := preload("res://tests/bancada_celular_jogo.gd")

var SP := ""
var _so := ""
var jogador: Node3D


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			SP = a.trim_prefix("--saida=").path_join("")
		elif a.begins_with("--so="):
			_so = a.trim_prefix("--so=")
	_rodar()


func _quer(etapa: String) -> bool:
	return _so.is_empty() or _so == etapa


func _caixa(pai: Node3D, tam: Vector3, centro: Vector3, cor: Color) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.8
	mi.material_override = mat
	pai.add_child(mi)
	mi.position = centro
	var corpo := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = tam
	col.shape = forma
	corpo.add_child(col)
	mi.add_child(corpo)


func _montar_mundo() -> void:
	var mundo := Node3D.new()
	mundo.name = "Mundo"
	add_child(mundo)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0d1118")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3a4a66")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	amb.environment = env
	mundo.add_child(amb)
	_caixa(mundo, Vector3(20.0, 0.2, 20.0), Vector3(0.0, -0.1, 0.0), Color("3a3833"))
	_caixa(mundo, Vector3(6.0, 3.0, 0.3), Vector3(0.0, 1.5, -3.5), Color("6b5a4a"))
	_caixa(mundo, Vector3(0.8, 1.0, 0.8), Vector3(1.4, 0.5, -2.2), Color("2f4a6b"))
	var lua := DirectionalLight3D.new()
	lua.light_color = Color(0.7, 0.78, 0.95)
	lua.light_energy = 0.35
	lua.shadow_enabled = true
	mundo.add_child(lua)
	lua.rotation = Vector3(-0.8, 0.6, 0.0)
	var poste := OmniLight3D.new()
	poste.light_color = Color(1.0, 0.78, 0.5)
	poste.light_energy = 2.0
	poste.omni_range = 7.0
	mundo.add_child(poste)
	poste.position = Vector3(-1.8, 2.8, -1.5)


func _passar(segundos: float) -> void:
	var fim := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < fim:
		await get_tree().process_frame


func _foto(nome: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SP + nome + ".png")
	print("[foto] ", nome)


## Anda o rig `quadros` passos de 1/30 s e salva cada quadro em `pasta`.
func _rajada(rig: CelularNaMao, pasta: String, quadros: int) -> void:
	DirAccess.make_dir_recursive_absolute(SP + pasta)
	rig.set_process(false)
	var t := 0.0
	for i in quadros:
		if not rig.visible:
			break
		rig.call(&"_process", PASSO)
		t += PASSO
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(960, 540, Image.INTERPOLATE_BILINEAR)
		img.save_png(SP + pasta.path_join("r_%.3f.png" % t))
	if rig.visible:
		rig.set_process(true)
	print("[rajada] ", pasta, " ", roundi(t / PASSO), " quadros")


## Acha a mao que aperta o botao de inicio (`--resolver-botao`). So o polegar
## nao alcanca (para 1 cm a direita e acima dele, no limite das juntas): a mao
## inteira escorrega pela lateral, os dedos descendo `desce` metros, como quem
## ajeita o aparelho para chegar no botao. Para cada descida, a pegada com o
## polegar encostando e apertando, e quanto o caminho da pegada do jogo ate ela
## entra no aparelho.
func _resolver_botao() -> void:
	var meia := IphoneDeJogo.TAMANHO * 0.5
	var aj := AjusteDaMao.new(meia, IphoneDeJogo.RAIO_CANTO, true)
	var y0: Array[float] = BancadaJogo.dedos_y.duplicate()
	var jogo := {"o": CelularNaMao.PEGADA_O, "d": CelularNaMao.PEGADA_D,
		"dorso": CelularNaMao.PEGADA_DORSO, "pose": CelularNaMao.PEGADA_POSE}
	for desce: float in [0.006, 0.010, 0.014, 0.018]:
		BancadaJogo.dedos_y = [y0[0] - desce, y0[1] - desce, y0[2] - desce]
		var metas: Array = []
		for m: Dictionary in BancadaJogo.metas_do_jogo():
			if int(m.get("dedo", -1)) != 4:
				metas.append(m)
		for nome: String in ["encosta", "aperta"]:
			var z := meia.z + (0.0016 if nome == "encosta" else 0.0004)
			aj.metas = metas + [{"tipo": &"polpa", "dedo": 4, "p": Vector3(0.0, IphoneDeJogo.Y_BOTAO, z),
				"n": Vector3(0.0, 0.0, 1.0), "peso": 1.2, "peso_n": 0.4},
				{"tipo": &"encosta", "dedo": 4, "falange": 0, "t": 0.55, "peso": 0.5}]
			var melhor := {}
			var nota := INF
			for pol: Array in [[40, 62, -90, 55, 18], [45, 80, -120, 20, 20], [30, 60, -80, 40, 30],
					[50, 70, -100, 45, 35]]:
				var chute := jogo.duplicate()
				chute["o"] = CelularNaMao.PEGADA_O - Vector3(0.0, desce, 0.0)
				chute["pose"] = {"dedos": CelularNaMao.PEGADA_POSE["dedos"], "polegar": pol}
				var p := aj.resolver(chute, 260)
				var med := aj.medir(p)
				var e0 := MaoDoCelular.esqueleto(p["o"], p["d"], p["dorso"], p["pose"], true)
				var c4: Vector3 = MaoDoCelular.polpa(e0, 4)["p"]
				var erro := c4.distance_to(Vector3(0.0, IphoneDeJogo.Y_BOTAO, z)) * 1000.0
				var custo := float(med["custo"]) + float(med["dentro"]) * 60.0
				if custo < nota:
					nota = custo
					melhor = p
					melhor["_erro"] = erro
					melhor["_med"] = med
			var med0: Dictionary = melhor["_med"]
			print("[botao] desce %.0f mm %s: erro do polegar %.1f mm, dentro %d, pior %.2f mm, custo %.1f" % [
				desce * 1000.0, nome, melhor["_erro"], med0["dentro"], med0["pior_mm"], med0["custo"]])
			print("[botao]   O := Vector3(%.4f, %.4f, %.4f)  D := Vector3(%.4f, %.4f, %.4f)  DORSO := Vector3(%.4f, %.4f, %.4f)" % [
				melhor["o"].x, melhor["o"].y, melhor["o"].z, melhor["d"].x, melhor["d"].y, melhor["d"].z,
				melhor["dorso"].x, melhor["dorso"].y, melhor["dorso"].z])
			print("[botao]   POSE := %s" % JSON.stringify(melhor["pose"]))
			if nome == "encosta":
				# O caminho da pegada do jogo ate esta, pela mistura que o braco usa.
				aj.metas = []
				var dentro := 0
				var pior := 0.0
				for i in 11:
					var k := float(i) / 10.0
					var mis := BracoDoCelular._misturar(BracoDoCelular.pega(jogo["o"], jogo["d"], jogo["dorso"],
						jogo["pose"]), BracoDoCelular.pega(melhor["o"], melhor["d"], melhor["dorso"],
						melhor["pose"]), k)
					var med := aj.medir(mis)
					dentro += int(med["dentro"])
					pior = minf(pior, float(med["pior_mm"]))
				print("[botao]   caminho: esferas dentro %d em 11 passos, pior %.2f mm" % [dentro, pior])
	BancadaJogo.dedos_y = y0


## Acha a mao que aperta o liga/desliga no topo (`--resolver-trava`), com o
## polegar ou com o indicador, a mao inteira livre e os outros dedos subindo
## `sobe` metros pela lateral. Imprime o erro da polpa, o quanto a palma andou
## e a pegada.
func _resolver_trava() -> void:
	var meia := IphoneDeJogo.TAMANHO * 0.5
	var aj := AjusteDaMao.new(meia, IphoneDeJogo.RAIO_CANTO, true)
	var y0: Array[float] = BancadaJogo.dedos_y.duplicate()
	var alvo := Vector3(IphoneDeJogo.LIGA_X, meia.y + 0.0014, 0.0)
	for dedo: int in [4, 0]:
		for sobe: float in [0.0, 0.008, 0.016, 0.024]:
			BancadaJogo.dedos_y = [y0[0] + sobe, y0[1] + sobe, y0[2] + sobe]
			var metas: Array = []
			for m: Dictionary in BancadaJogo.metas_do_jogo():
				var d := int(m.get("dedo", -1))
				if d == dedo:
					continue
				if dedo == 0 and d == 4 and m["tipo"] == &"polpa":
					# O polegar sobe junto com a mao pela lateral.
					var m2 := m.duplicate()
					m2["p"] = (m["p"] as Vector3) + Vector3(0.0, sobe, 0.0)
					metas.append(m2)
					continue
				metas.append(m)
			metas.append({"tipo": &"polpa", "dedo": dedo, "p": alvo, "n": Vector3(0.0, 1.0, 0.0),
				"peso": 1.2, "peso_n": 0.4})
			aj.metas = metas
			var melhor := {}
			var nota := INF
			var chutes_pol := [[40, 30, -60, 20, 20], [30, 10, -40, 10, 10], [50, 20, -80, 30, 30]]
			for i in 3:
				var chute := {"o": CelularNaMao.PEGADA_O + Vector3(0.0, sobe, 0.0), "d": CelularNaMao.PEGADA_D,
					"dorso": CelularNaMao.PEGADA_DORSO,
					"pose": {"dedos": CelularNaMao.PEGADA_POSE["dedos"], "polegar": chutes_pol[i]
						if dedo == 4 else CelularNaMao.PEGADA_POSE["polegar"]}}
				var pp := aj.resolver(chute, 260)
				var med := aj.medir(pp)
				var custo := float(med["custo"]) + float(med["dentro"]) * 60.0
				if custo < nota:
					nota = custo
					melhor = pp
					melhor["_med"] = med
			var e0 := MaoDoCelular.esqueleto(melhor["o"], melhor["d"], melhor["dorso"], melhor["pose"], true)
			var c: Vector3 = MaoDoCelular.polpa(e0, dedo)["p"]
			var med0: Dictionary = melhor["_med"]
			print("[trava] %s sobe %.0f mm: erro %.1f mm, palma andou %.1f mm, dentro %d pior %.2f mm custo %.1f" % [
				"polegar" if dedo == 4 else "indicador", sobe * 1000.0, c.distance_to(alvo) * 1000.0,
				(melhor["o"] as Vector3).distance_to(CelularNaMao.PEGADA_O) * 1000.0, med0["dentro"],
				med0["pior_mm"], med0["custo"]])
			print("[trava]   O := Vector3(%.4f, %.4f, %.4f)  D := Vector3(%.4f, %.4f, %.4f)  DORSO := Vector3(%.4f, %.4f, %.4f)" % [
				melhor["o"].x, melhor["o"].y, melhor["o"].z, melhor["d"].x, melhor["d"].y, melhor["d"].z,
				melhor["dorso"].x, melhor["dorso"].y, melhor["dorso"].z])
			print("[trava]   POSE := %s" % JSON.stringify(melhor["pose"]))
	BancadaJogo.dedos_y = y0


## O caminho da pegada do jogo ate a de travar (`--caminho-trava`), pelo
## `CelularNaMao.pegada_da_trava` (o mesmo do jogo): procura numa grade o
## indicador fora do aparelho, o quanto o minimo dobra e o quanto o medio e o
## anelar afrouxam, para nada entrar no aparelho e o indicador passar rente.
func _caminho_trava() -> void:
	var meia := IphoneDeJogo.TAMANHO * 0.5
	var aj := AjusteDaMao.new(meia, IphoneDeJogo.RAIO_CANTO, true)
	var base := minf(float(aj.medir(CelularNaMao.pegada_da_trava(0.0))["pior_mm"]),
		float(aj.medir(CelularNaMao.pegada_da_trava(1.0))["pior_mm"]))
	print("[caminho-trava] base (pegadas paradas): pior %.2f mm" % base)
	var ergue: Array = CelularNaMao.INDICADOR_ERGUIDO
	var resultados := []
	for minimo: Array in [[-10.0, 15.0, 0.0], [-20.0, 30.0, 0.0], [-10.0, 30.0, 15.0], [-20.0, 45.0, 15.0],
			[-30.0, 30.0, 0.0]]:
		for dr: float in [0.0, 10.0, 20.0]:
			for dp: float in [-15.0, 0.0, 15.0, 30.0]:
				for dg: float in [-20.0, 0.0, 20.0]:
					for di: float in [0.0, 20.0, 40.0]:
						var pol := [dr, dp, dg, 0.0, di]
						var pior := 0.0
						for i in 19:
							var k := float(i + 1) / 20.0
							var p := CelularNaMao.pegada_da_trava(k, ergue, minimo, CelularNaMao.SOLTA_TRAVA, pol)
							pior = minf(pior, float(aj.medir(p)["pior_mm"]))
						var nota := maxf(0.0, base - pior) * 10.0 + (absf(dr) + absf(dp) + absf(dg) + absf(di)) * 0.01
						resultados.append([nota, [minimo, pol], pior])
	resultados.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for r: Array in resultados.slice(0, 8):
		print("[caminho-trava] nota %.2f %s: pior %.2f mm" % [r[0], r[1], r[2]])


## Quem entra no aparelho no caminho da trava (`--diagnostico-trava`): a pior
## esfera de cada parte da mao (dedos, polegar, membrana, palma) em cada passo
## do `CelularNaMao.pegada_da_trava`.
func _diagnostico_trava() -> void:
	var meia := IphoneDeJogo.TAMANHO * 0.5
	var aj := AjusteDaMao.new(meia, IphoneDeJogo.RAIO_CANTO, true)
	var nomes := ["indicador", "medio", "anelar", "minimo", "polegar", "membrana", "palma"]
	var linha := ""
	var pior_geral := 0.0
	for i in 21:
		var k := float(i) / 20.0
		var p := CelularNaMao.pegada_da_trava(k)
		var e := MaoDoCelular.esqueleto(p["o"], p["d"], p["dorso"], p["pose"], true)
		var esferas: Array = aj._esferas(e, false)
		var pior := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		for n in esferas.size():
			var parte := n / 5 if n < 20 else (4 if n < 27 else (5 if n < 30 else 6))
			var esf: Array = esferas[n]
			var sd := AjusteDaMao.distancia(esf[0], meia, IphoneDeJogo.RAIO_CANTO) - float(esf[1])
			pior[parte] = minf(pior[parte], sd * 1000.0)
		var p_k := 0.0
		var quem := "-"
		for q in 7:
			if pior[q] < p_k:
				p_k = pior[q]
				quem = nomes[q]
		pior_geral = minf(pior_geral, p_k)
		linha += " %.2f:%s%.1f" % [k, quem, p_k]
	print("[diag-trava] pior %.2f |%s" % [pior_geral, linha])


## O caminho da pegada do jogo ate a do botao (`--caminho-botao`): procura numa
## grade a pose do polegar no meio do caminho (misturada por sin(pi k)) que nao
## entra no aparelho e passa RENTE a ele. A primeira, aberta para fora
## ([70, 10, 0, 0, 0]), nao entrava, mas o polegar saia espetado para o lado e
## na volta lia como um joinha.
func _caminho_botao() -> void:
	var meia := IphoneDeJogo.TAMANHO * 0.5
	var aj := AjusteDaMao.new(meia, IphoneDeJogo.RAIO_CANTO, true)
	var jogo := BracoDoCelular.pega(CelularNaMao.PEGADA_O, CelularNaMao.PEGADA_D,
		CelularNaMao.PEGADA_DORSO, CelularNaMao.PEGADA_POSE)
	var botao := BracoDoCelular.pega(CelularNaMao.BOTAO_O, CelularNaMao.BOTAO_D,
		CelularNaMao.BOTAO_DORSO, CelularNaMao.BOTAO_POSE)
	# A linha de base: a pior entrada das duas pegadas paradas.
	var base := minf(float(aj.medir(jogo)["pior_mm"]), float(aj.medir(botao)["pior_mm"]))
	print("[caminho] base (pegadas paradas): pior %.2f mm" % base)
	var resultados := []
	for rad: float in [20.0, 35.0, 50.0, 65.0]:
		for pal: float in [20.0, 40.0, 60.0, 80.0]:
			for gir: float in [-110.0, -80.0, -50.0, -20.0]:
				for mcp: float in [0.0, 20.0, 40.0]:
					for ip: float in [0.0, 20.0, 40.0]:
						var ergue := [rad, pal, gir, mcp, ip]
						var pior := 0.0
						var longe := 0.0
						for i in 9:
							var k := float(i + 1) / 10.0
							var mis := BracoDoCelular._misturar(jogo, botao, k)
							var pose: Dictionary = mis["pose"]
							var pol: Array = []
							for j in 5:
								pol.append(lerpf(float(pose["polegar"][j]), float(ergue[j]), sin(PI * k)))
							mis["pose"] = {"dedos": pose["dedos"], "polegar": pol}
							pior = minf(pior, float(aj.medir(mis)["pior_mm"]))
							var e0 := MaoDoCelular.esqueleto(mis["o"], mis["d"], mis["dorso"], mis["pose"], true)
							var c4: Vector3 = MaoDoCelular.polpa(e0, 4)["centro"]
							longe = maxf(longe, AjusteDaMao.distancia(c4, meia, IphoneDeJogo.RAIO_CANTO))
						var nota := maxf(0.0, base - pior) * 10.0 + maxf(0.0, longe * 1000.0 - 14.0)
						resultados.append([nota, ergue, pior, longe * 1000.0])
	resultados.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for r: Array in resultados.slice(0, 12):
		print("[caminho] nota %.2f ergue %s: pior %.2f mm, polpa ate %.1f mm do aparelho" % [r[0], r[1], r[2], r[3]])


func _rodar() -> void:
	await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--resolver-trava"):
		_resolver_trava()
		get_tree().quit(0)
		return
	if OS.get_cmdline_user_args().has("--diagnostico-trava"):
		_diagnostico_trava()
		get_tree().quit(0)
		return
	if OS.get_cmdline_user_args().has("--caminho-trava"):
		_caminho_trava()
		get_tree().quit(0)
		return
	if OS.get_cmdline_user_args().has("--caminho-botao"):
		_caminho_botao()
		get_tree().quit(0)
		return
	if OS.get_cmdline_user_args().has("--resolver-botao"):
		_resolver_botao()
		get_tree().quit(0)
		return
	DirAccess.make_dir_recursive_absolute(SP)
	if OS.get_cmdline_user_args().has("--sem-aquecer"):
		Celular.aquecer_ao_nascer = false
	_montar_mundo()
	jogador = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Node3D
	add_child(jogador)
	jogador.global_position = Vector3(0.0, 0.05, 0.0)
	await _passar(0.8)

	if OS.get_cmdline_user_args().has("--medir-engasgo"):
		# O pior quadro da primeira subida (ms), com ou sem o aquecimento.
		Celular.abrir()
		var antes := Time.get_ticks_usec()
		var pior := 0.0
		var lentos := 0
		for i in 45:
			await get_tree().process_frame
			var agora := Time.get_ticks_usec()
			var ms := float(agora - antes) / 1000.0
			antes = agora
			if ms > pior:
				print("[engasgo]   quadro %d: %.1f ms" % [i, ms])
			pior = maxf(pior, ms)
			if ms > 33.0:
				lentos += 1
		print("[engasgo] %s: pior quadro %.1f ms, %d quadros acima de 33 ms" % [
			"sem aquecer" if not Celular.aquecer_ao_nascer else "aquecido", pior, lentos])
		get_tree().quit(0)
		return
	Celular.abrir()
	var rig := Celular.get("_rig") as CelularNaMao
	if _quer("puxar"):
		await _rajada(rig, "puxar", 36)
	# A primeira subida compila o shader da pele: o relogio anda e o gesto nao.
	while not rig.erguido():
		await get_tree().process_frame
	await _passar(1.0)
	await _foto("10_leitura")

	if _quer("perto"):
		await _zoom(rig)
		await _de_perto(rig)

	if _quer("balanco"):
		await _balanco(rig)

	if _so == "mapa":
		await _mapa(rig)
		get_tree().quit(0)
		return

	if _quer("guardar"):
		# Destrava antes: guardar tem de travar de novo (a regra de antes deixava
		# destravado por 25 s).
		Celular.call("_acionar")
		await _passar(0.9)
		print("[bancada] destravado: modo %s (1 = inicio)" % Celular.get("_modo"))
		Celular.fechar()
		await _rajada(rig, "guardar", 30)
		# Guardar trava: tirar de novo volta na trava, com o polegar acordando.
		await _passar(0.4)
		print("[bancada] reabrindo: modo %s" % Celular.get("_modo"))
		Celular.abrir()
		print("[bancada] reaberto: modo %s (0 = trava)" % Celular.get("_modo"))
		await _rajada(rig, "reabrir", 30)
	get_tree().quit(0)


## O Mapas: o aparelho deita nas duas maos e vem para junto da lente, a lente
## fecha (`CelularNaMao.LEITURA_DEITADO`, `FOV_DEITADO`) e a textura da tela
## cresce (`Celular._aplicar_escala`). A rajada anda o `Celular` e o rig no mesmo
## passo; depois, o tempo de GPU da tela e do quadro com a textura deitada e com
## a de em pe (a de antes), para saber quanto a nitidez custa.
func _mapa(rig: CelularNaMao) -> void:
	Celular.call("_acionar")
	await _passar(0.9)
	Celular.call("_lancar_sem_zoom", &"mapas")
	DirAccess.make_dir_recursive_absolute(SP + "mapa")
	rig.set_process(false)
	Celular.set_process(false)
	var t := 0.0
	var cam := get_viewport().get_camera_3d()
	for i in 24:
		Celular.call(&"_process", PASSO)
		rig.call(&"_process", PASSO)
		t += PASSO
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(960, 540, Image.INTERPOLATE_BILINEAR)
		img.save_png(SP + "mapa".path_join("r_%.3f.png" % t))
		if i % 3 == 0:
			print("[mapa] %.2f s: giro %.2f, fov %.1f, fone z %.3f, textura %s" % [t, rig.giro,
				cam.fov, rig.fone.position.z, Celular.get("_vp").size])
	Celular.set_process(true)
	rig.set_process(true)
	await _passar(0.5)
	await _foto("40_mapa_de_perto")
	# O raio do mouse (o ALT) com o aparelho deitado e a lente fechada, e quanto
	# do quadro a tela ocupa.
	var pior := 0.0
	for uv: Vector2 in [Vector2(0.5, 0.5), Vector2(0.1, 0.1), Vector2(0.9, 0.12), Vector2(0.15, 0.9),
			Vector2(0.88, 0.85)]:
		pior = maxf(pior, rig.uv_da_tela(rig.na_tela(uv)).distance_to(uv))
	var caixa := Rect2(rig.na_tela(Vector2(0.5, 0.5)), Vector2.ZERO)
	for uv: Vector2 in [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0)]:
		caixa = caixa.expand(rig.na_tela(uv))
	var quadro_px := get_viewport().get_visible_rect().size
	print("[mapa] raio do mouse: pior erro %.4f; a tela ocupa %.0f%% da largura e %.0f%% da altura" % [
		pior, caixa.size.x / quadro_px.x * 100.0, caixa.size.y / quadro_px.y * 100.0])
	var vp := Celular.get("_vp") as SubViewport
	var raiz := Celular.get("_raiz") as Control
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var deitada := vp.size
	var escala := raiz.scale
	for caso: String in ["deitada", "em pe", "deitada"]:
		if caso == "em pe":
			vp.size = Vector2i(146 * 7, 219 * 7)
			raiz.scale = Vector2(7.0, 7.0)
		else:
			vp.size = deitada
			raiz.scale = escala
		await _passar(0.4)
		var tela := 0.0
		var quadro := 0.0
		for i in 90:
			await get_tree().process_frame
			tela += RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid())
			quadro += RenderingServer.viewport_get_measured_render_time_gpu(
				get_viewport().get_viewport_rid())
		print("[mapa] textura %s (%s): tela %.3f ms, quadro %.3f ms de GPU" % [vp.size, caso,
			tela / 90.0, quadro / 90.0])


## O mouse movendo a cabeca com o aparelho na mao (`CelularNaMao.olhar`), a 30
## quadros por segundo: olhar devagar, sacudir de um lado para o outro e parar.
## E o ALT: as dicas com o mouse solto e de volta a camera.
func _balanco(rig: CelularNaMao) -> void:
	DirAccess.make_dir_recursive_absolute(SP + "balanco")
	rig.set_process(false)
	var t := 0.0
	for i in 60:
		var dx := 0.0
		if i < 12:
			dx = 4.0
		elif i < 40:
			dx = 70.0 * sin(TAU * 2.2 * float(i - 12) * PASSO)
		rig.olhar(Vector2(dx, 0.0))
		rig.call(&"_process", PASSO)
		t += PASSO
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(960, 540, Image.INTERPOLATE_BILINEAR)
		img.save_png(SP + "balanco".path_join("r_%.3f.png" % t))
		var bal: Vector2 = rig.get("_bal")
		if i % 4 == 0:
			print("[balanco] %.2f s: mouse %.0f px, atraso (%.1f, %.1f) graus" % [t, dx,
				rad_to_deg(bal.x), rad_to_deg(bal.y)])
	rig.set_process(true)
	await _passar(0.5)
	await _foto("30_camera_dica")
	var alt := InputEventKey.new()
	alt.keycode = KEY_ALT
	alt.pressed = true
	Input.parse_input_event(alt)
	await _passar(0.3)
	print("[balanco] ALT: mouse_livre=%s" % Celular.get("mouse_livre"))
	await _foto("31_mouse_dica")
	Input.parse_input_event(alt)
	await _passar(0.3)
	print("[balanco] ALT de novo: mouse_livre=%s" % Celular.get("mouse_livre"))


## Da lente do jogador, com o FOV fechado em cima de cada parte da mao: o mesmo
## angulo do jogo, com quatro vezes mais pixel.
func _zoom(rig: CelularNaMao) -> void:
	var cam_jogo := get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.near = 0.005
	cam.fov = 9.0
	add_child(cam)
	var xf := rig.fone.global_transform
	var meia := IphoneDeJogo.TAMANHO * 0.5
	var alvos := {
		"11_zoom_dedos": Vector3(-meia.x - 0.004, 0.004, 0.0),
		"12_zoom_polegar": Vector3(meia.x + 0.004, 0.0, 0.0),
		"13_zoom_calcanhar": Vector3(meia.x * 0.5, -meia.y - 0.01, 0.0),
	}
	for nome: String in alvos:
		cam.global_position = cam_jogo.global_position
		cam.look_at(xf * (alvos[nome] as Vector3), cam_jogo.global_transform.basis.y)
		cam.current = true
		await _foto(nome)
	cam_jogo.current = true
	cam.queue_free()


## Seis cameras em volta do aparelho: a lateral dos dedos, as costas, o pe, a
## lateral do polegar, o topo e a frente.
func _de_perto(rig: CelularNaMao) -> void:
	var cam_jogo := get_viewport().get_camera_3d()
	var fora := Camera3D.new()
	fora.near = 0.005
	fora.fov = 38.0
	add_child(fora)
	var n := 0
	for de: Vector3 in [Vector3(-0.14, 0.02, 0.05), Vector3(-0.06, -0.02, -0.14), Vector3(0.0, -0.14, 0.05),
			Vector3(0.13, -0.02, 0.06), Vector3(0.02, 0.14, 0.04), Vector3(0.0, 0.0, 0.16)]:
		var xf := rig.fone.global_transform
		fora.global_position = xf * de
		fora.look_at(xf * Vector3(0.0, -0.01, 0.0), xf.basis.y)
		fora.current = true
		await _foto("2%d_de_perto" % n)
		n += 1
	cam_jogo.current = true
	fora.queue_free()
