## Bancada do transito (PLANO_TRANSITO_AAA, Passos 1 e 2): o carro da IA de
## verdade, num chao plano, plantado a montante de um cruzamento conhecido, com a
## manobra imposta, e a trajetoria medida quadro a quadro.
##
##     godot --headless --fixed-fps 60 --path game --script res://tests/bancada_transito.gd -- --sem-relevo
##     ... -- --ia-antiga          a IA de antes, na mesma situacao (linha de base)
##     ... -- --so=rua_rua,av_av   so estes cenarios (os nomes abaixo, e custo)
##     ... -- --csv=DIR            grava a trajetoria de cada cenario
##     ... -- --fotos=DIR          COM janela (sem --headless): ruas pintadas
##                                 no chao e um quadro a cada 0,1 s por cenario,
##                                 em DIR/<cenario>/r_<t>.png, para o
##                                 tools/mosaico_rajada.py
##
## Por que bancada, e nao a rua
## ----------------------------
## Na cidade a curva que se mede depende de onde o jogador nasceu, de que
## esquina o sorteio escolheu e de quem mais passou (memoria: observacao livre
## nao vira criterio). Aqui o cruzamento e achado pela malha (`Vias`), o sinal e
## posto no verde, e o carro e o mesmo `Carro` do jogo — lataria, medidas e o
## motorista inteiro —, so que sozinho e num chao sem relevo. O que sai e sempre
## do mesmo experimento.
##
## Os cruzamentos
## --------------
##   rua_rua   rua com rua, chegando pela preferencial (sem PARE)
##   av_av     avenida com avenida (semaforo, posto no verde)
##   rua_av    chegando por rua, virando para a avenida
##   av_rua    chegando pela avenida, virando para a rua
##   pare      rua com rua pela secundaria: para no PARE e vira do zero
##
## O que se mede, e o criterio (secao 4 do plano)
## ----------------------------------------------
##   a_lat        pico de aceleracao lateral do centro do carro     <= 3,0 m/s2
##   guinada      maior salto da taxa de guinada entre dois quadros <= 0,3 rad/s
##   contramao    quanto um canto da lataria passa do eixo, fora do miolo  <= 0
##   calcada      quanto um canto sobe na calcada da esquina                <= 0
##   estac        (esquerda) quanto passa da borda da pista de saida        <= 0
##   reta         afastamento do centro da faixa andando reto        <= 0,15 m
##   seta         a seta acesa e a do lado da curva
##   freada       pico de desaceleracao na curva e no PARE          <= 3,0 m/s2
##
## O pe (Passo 2)
## --------------
##   parada    no vermelho, vindo a 11 (rua) e a 14 m/s (avenida): freada
##             <= 3,0 m/s2 e o bico entre a linha e 0,8 m antes dela
##   partida   fila de tres no vermelho, abre o verde: o 1o sai em 0,4-1,2 s, o
##             3o em ate 3,5 s, e pararam a >= 5 m de centro a centro
##   amarelo   acende com o bico a 20, 30, 36 e 45 m, a 14 m/s: passa (e cruza
##             antes do vermelho) quem precisaria de mais de 3,5 m/s2 contando o
##             curso do pedal; quem para, para com ate 3,5 e antes da linha
##   fila      (so a nova) seguindo um carro a 10,5 m/s numa reta: 1,2-2,0 s
##   onda      (so a nova) cinco carros, o 1o freia a 3 m/s2 ate parar: ninguem
##             encosta e nenhum seguidor passa de 4,5 m/s2
extends SceneTree

const PASSO := 1.0 / 60.0
const T_MAX := 30.0
const A_LAT_MAX := 3.0
const SALTO_MAX := 0.3
const RETA_MAX := 0.15
## Pior planejamento de um quarteirao, em ms: e o que o carro paga de uma vez,
## num quadro, ao ver a esquina seguinte.
const PLANEJAR_MAX_MS := 2.0
## Distancia minima do cruzamento anterior, para o carro chegar a toda.
const RECUO_MINIMO := 64.0

## O pe (Passo 2, secao 4 do plano).
## Freada do dia a dia (parada no vermelho, curva, PARE), em m/s2.
const FREADA_MAX := 3.0
## Onde o bico para: entre a linha e isto antes dela, em metros.
const PARADA_ANTES_MAX := 0.8
## Intervalo seguindo a 40 km/h, em segundos.
const INTERVALO_MIN := 1.2
const INTERVALO_MAX := 2.0
## Onda de freada: nenhum seguidor passa disto, em m/s2, e ninguem encosta.
const ONDA_MAX := 4.5
## Partida no verde: o primeiro sai nesta janela, o terceiro ate o teto (s).
const PARTIDA_1_MIN := 0.4
const PARTIDA_1_MAX := 1.2
const PARTIDA_3_MAX := 3.5
## Fila parada: centro a centro, no minimo (o mesmo do verificar_transito).
const FILA_CENTRO_MIN := 5.0
## A zebra vai ate `asf + ZEBRA_ATE` do centro (ChunkBuilder.FAIXA_RECUO +
## FAIXA_PROFUNDIDADE), e o bico parado fica pelo menos ZEBRA_FOLGA antes dela.
const ZEBRA_ATE := 1.75
const ZEBRA_FOLGA := 0.5

var _script_carro: GDScript
var _script_ia: GDScript
var _nova := false
var _so: Array[String] = []
var _csv := ""
var _fotos := ""
var _camera: Camera3D
var _pintura: Node3D
var _mundo: Node3D
var _registro: Node
var _passou := 0
var _total := 0
var _semente := 11


func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--so="):
			_so.assign(a.trim_prefix("--so=").split(","))
		elif a.begins_with("--csv="):
			_csv = a.trim_prefix("--csv=")
		elif a.begins_with("--fotos="):
			_fotos = a.trim_prefix("--fotos=")
	_rodar.call_deferred()


func _rodar() -> void:
	await process_frame
	_script_carro = load("res://src/world/carro.gd") as GDScript
	_script_ia = load("res://src/world/transito/motorista_ia.gd") as GDScript
	_nova = not bool(_script_ia.get("ia_antiga"))
	_registro = root.get_node(^"RegistroCivil")
	print("[bancada_transito] ia=%s relevo=%s" % ["nova" if _nova else "antiga",
		str(Relevo.ativo)])
	_mundo = Node3D.new()
	root.add_child(_mundo)
	var chao := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(4000.0, 1.0, 4000.0)
	forma.shape = caixa
	chao.add_child(forma)
	chao.position = Vector3(0.0, -0.5, 0.0)
	_mundo.add_child(chao)
	if _fotos != "":
		_camera = Camera3D.new()
		_camera.fov = 55.0
		_mundo.add_child(_camera)
		_camera.make_current()
		var sol := DirectionalLight3D.new()
		sol.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
		sol.light_energy = 1.2
		_mundo.add_child(sol)
		var amb := WorldEnvironment.new()
		amb.environment = Environment.new()
		amb.environment.background_mode = Environment.BG_COLOR
		amb.environment.background_color = Color(0.55, 0.6, 0.66)
		amb.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		amb.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
		amb.environment.ambient_light_energy = 0.8
		_mundo.add_child(amb)

	var rumo: Dictionary = _script_ia.get_script_constant_map()["Rumo"]
	var d: int = rumo["DIREITA"]
	var e: int = rumo["ESQUERDA"]
	var r: int = rumo["RETO"]
	var tr: int = rumo["TROCA"]
	var planos := [
		["rua_rua", [d, e, r]],
		["av_av", [d, e, r, tr]],
		["rua_av", [d, e]],
		["av_rua", [d, e]],
		["pare", [d, e]],
	]
	for p: Array in planos:
		var nome: String = p[0]
		if not _so.is_empty() and not _so.has(nome):
			continue
		var achado := _achar(nome)
		if achado.is_empty():
			print("[bancada_transito] %s: cruzamento nao achado" % nome)
			_conta(nome, "achado", false, "sem cruzamento desse tipo perto da origem")
			continue
		print("\n=== %s em %s, chegando no eixo %d sentido %d ===" % [nome,
			achado["ij"], achado["eixo"], achado["sentido"]])
		for m: int in p[1]:
			await _cenario(nome, achado, m, rumo.find_key(m))
		# A esquerda da avenida pela faixa de FORA: o motorista novo troca de
		# faixa antes; o antigo vira dali.
		if nome == "av_av":
			await _cenario(nome, achado, e, "ESQUERDA_DE_FORA", 0)
	# O pe (Passo 2).
	if _so.is_empty() or _so.has("parada"):
		await _c_parada("rua_av", "parada_rua")
		await _c_parada("av_av", "parada_avenida")
	if _so.is_empty() or _so.has("partida"):
		await _c_partida()
	if _so.is_empty() or _so.has("amarelo"):
		await _c_amarelo(20.0, true)
		await _c_amarelo(30.0, true)
		await _c_amarelo(36.0, false)
		await _c_amarelo(45.0, false)
	if _nova and (_so.is_empty() or _so.has("fila")):
		await _c_fila()
	if _nova and (_so.is_empty() or _so.has("onda")):
		await _c_onda()
	if _so.is_empty() or _so.has("custo"):
		await _custo_do_passo()
	# A curva de cada geometria de esquina: lado|chegada|saida|asfalto de
	# chegada|asfalto de saida|meia pista de saida -> (raio, fracao).
	for chave: String in Manobra._escolhas:
		print("[bancada_transito] curva %s -> %s" % [chave, Manobra._escolhas[chave]])
	if _nova:
		var diferentes := Manobra.conferir_tabela()
		for d_: String in diferentes:
			print("[bancada_transito] tabela_difere %s" % d_)
		_conta("curvas", "tabela", diferentes.is_empty(),
			"a TABELA da Manobra e o que a busca escolhe hoje (%d diferentes)" % diferentes.size())
		print("[bancada_transito] custo_busca_raio_ms=%.2f" % Manobra.custo_escolha_ms)
		var pior: float = _script_ia.get(&"pior_planejar_ms")
		var soma: float = _script_ia.get(&"soma_passo_ms")
		var n: int = _script_ia.get(&"passos")
		print("[bancada_transito] passo_medio_ms=%.4f em %d passos" % [soma / maxf(1.0, n), n])
		var lista: PackedFloat32Array = _script_ia.get(&"planejamentos")
		var ordem := Array(lista)
		print("[bancada_transito] planejamentos_ms (na ordem) = %s" % str(ordem.map(
			func(x: float) -> String: return "%.2f" % x)))
		_conta("custo", "planejar", pior <= PLANEJAR_MAX_MS,
			"pior planejamento de quarteirao %.2f ms (teto %.1f)" % [pior, PLANEJAR_MAX_MS])
		# O primeiro de cada carro (ao nascer ou ser plantado) pode achar a malha
		# fria; na rua ela ja foi consultada pelo povoamento. Informa.
		print("[bancada_transito] pior_planejamento_inicial_ms=%.2f" % float(
			_script_ia.get(&"pior_inicial_ms")))
	print("\n%d de %d criterios" % [_passou, _total])
	quit(0 if _passou == _total else 1)


# --- achar o cruzamento ------------------------------------------------------

## O cruzamento do tipo pedido mais perto da origem, com a chegada escolhida.
func _achar(tipo: String) -> Dictionary:
	var candidatos: Array[Vector2i] = []
	for i in range(-30, 31):
		for j in range(-30, 31):
			candidatos.append(Vector2i(i, j))
	candidatos.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.length_squared() < b.length_squared())
	var av := MalhaUrbana.Via.AVENIDA
	for ij: Vector2i in candidatos:
		if not Vias.existe_cruzamento(ij.x, ij.y):
			continue
		if not (Vias.braco_n(ij.x, ij.y) and Vias.braco_s(ij.x, ij.y)
				and Vias.braco_l(ij.x, ij.y) and Vias.braco_o(ij.x, ij.y)):
			continue
		var av_x := MalhaUrbana.via_x(ij.x) == av
		var av_z := MalhaUrbana.via_z(ij.y) == av
		for eixo in 2:
			var chega_av := av_x if eixo == 0 else av_z
			var cruza_av := av_z if eixo == 0 else av_x
			var ok := false
			match tipo:
				"rua_rua":
					ok = not chega_av and not cruza_av and eixo == Vias.preferencial(ij.x, ij.y)
				"pare":
					ok = not chega_av and not cruza_av and eixo != Vias.preferencial(ij.x, ij.y)
				"av_av":
					ok = chega_av and cruza_av
				"rua_av":
					ok = not chega_av and cruza_av
				"av_rua":
					ok = chega_av and not cruza_av
			if not ok:
				continue
			for sentido: int in [1, -1]:
				var ant := _anterior(ij, eixo, sentido)
				if ant == ij:
					continue
				var recuo := float(absi((ant - ij).x) + absi((ant - ij).y)) * Vias.TAM
				if recuo < (32.0 if tipo == "pare" else RECUO_MINIMO):
					continue
				# As tres saidas tem de levar a algum lugar.
				var outro := 1 - eixo
				var todas := Vias.proximo_cruzamento(ij.x, ij.y, Vias.trecho(eixo, sentido, 0)) != ij
				for s: int in [1, -1]:
					todas = todas and Vias.proximo_cruzamento(ij.x, ij.y,
						Vias.trecho(outro, s, 0)) != ij
				if not todas:
					continue
				return {"ij": ij, "eixo": eixo, "sentido": sentido, "de": ant,
					"recuo": recuo}
	return {}


static func _anterior(ij: Vector2i, eixo: int, sentido: int) -> Vector2i:
	if eixo == 0:
		return Vector2i(ij.x, Vias.proxima_z(ij.y, ij.x, -sentido))
	return Vector2i(Vias.proxima_x(ij.x, ij.y, -sentido), ij.y)


# --- um cenario --------------------------------------------------------------

func _cenario(nome: String, achado: Dictionary, manobra: int, rotulo: String,
		faixa_forcada := -1) -> void:
	var ij: Vector2i = achado["ij"]
	var eixo: int = achado["eixo"]
	var sentido: int = achado["sentido"]
	var de: Vector2i = achado["de"]
	var outro := 1 - eixo
	var faixas_ap := Vias.faixas(MalhaUrbana.via_x(ij.x) if eixo == 0 else MalhaUrbana.via_z(ij.y))
	var faixas_sai := Vias.faixas(MalhaUrbana.via_z(ij.y) if eixo == 0 else MalhaUrbana.via_x(ij.x))
	var s_dir := 0
	for s: int in [1, -1]:
		if Manobra.lado_da_curva(Vias.trecho(eixo, sentido, 0), Vias.trecho(outro, s, 0)) > 0:
			s_dir = s
	var rumo: Dictionary = _script_ia.get_script_constant_map()["Rumo"]
	var faixa := 0
	var para := Vias.trecho(eixo, sentido, 0)
	var lado_esperado := 0
	match rotulo:
		"DIREITA":
			para = Vias.trecho(outro, s_dir, 0)
			lado_esperado = 1
		"ESQUERDA", "ESQUERDA_DE_FORA":
			faixa = 1 if faixas_ap > 1 else 0
			para = Vias.trecho(outro, -s_dir, 1 if faixas_sai > 1 else 0)
			lado_esperado = -1
		"TROCA":
			para = Vias.trecho(eixo, sentido, 1)
	if faixa_forcada >= 0:
		faixa = faixa_forcada
	var t := Vias.trecho(eixo, sentido, faixa)
	var centro := Vector3(float(ij.x) * Vias.TAM, 0.0, float(ij.y) * Vias.TAM)
	var dir := Vias.direcao(eixo, sentido)
	var largada := minf(60.0, float(achado["recuo"]) - 8.0)
	var ponto := centro - dir * largada
	if eixo == 0:
		ponto.x = Vias.linha_x(ij.x, sentido, faixa)
	else:
		ponto.z = Vias.linha_z(ij.y, sentido, faixa)
	ponto.y = 0.05

	# O sinal no comeco do verde deste eixo, e parado: nada avanca o relogio
	# na bancada (o Transito nao roda).
	if Semaforo.tem_sinal(ij.x, ij.y):
		var alvo := (0.0 if eixo == 0 else Semaforo.CICLO * 0.5) + 0.2
		Semaforo._agora = fposmod(alvo - Semaforo.defasagem(ij.x, ij.y), Semaforo.CICLO)

	_semente += 17
	var ficha: Dictionary = _registro.call(&"identidade",
		_registro.call(&"id_de_transeunte", _semente))
	var c: Node3D = _script_carro.new()
	c.call(&"preparar", ficha, de, t, _semente)
	c.position = ponto
	_mundo.add_child(c)
	await physics_frame
	c.call(&"plantar", de, t, ponto)
	var ia: Variant = c.get(&"_ia")
	if ia != null:
		var lista: Array[int] = [manobra]
		(ia as RefCounted).call(&"forcar", lista)
	else:
		# IA antiga: a saida vai pelo plano da seta, que ela respeita.
		var velha := para
		if rotulo == "DIREITA" or rotulo.begins_with("ESQUERDA"):
			velha = Vias.trecho(para.z, para.w, 0)
		c.set(&"_saida_plana", velha)
		c.set(&"_tem_plano", true)

	var medidas: Dictionary = c.get(&"_medidas")
	var comp := float(medidas["comprimento"])
	var larg := float(medidas["largura"])
	var geo := Manobra.geometria(ij.x, ij.y, Vias.trecho(eixo, sentido, 0),
		Vias.trecho(para.z, para.w, 0))
	var lado := int(geo[0]) if para.z != eixo else 0
	var asf_ap := geo[3]
	var asf_sai := geo[4]
	var meia_sai := geo[5]
	var a2 := Vector2(dir.x, dir.z)
	var r_a := Vector2(-a2.y, a2.x)
	var b3 := Vias.direcao(para.z, para.w)
	var c2 := Vector2(centro.x, centro.z)
	var pasta_fotos := ""
	if _fotos != "":
		pasta_fotos = _fotos.path_join("%s_%s_%s" % [nome, rotulo.to_lower(),
			"nova" if _nova else "antiga"])
		DirAccess.make_dir_recursive_absolute(pasta_fotos)
		_pintar(c2, a2, r_a, asf_ap, asf_sai, geo[5],
			Vias.meia_x(ij.x) if eixo == 0 else Vias.meia_z(ij.y))
		# Alto, atras e a esquerda da chegada, olhando o miolo. No referencial
		# da chegada o ponto (x, z) do mundo e c2 - r_a * x + a2 * z.
		var cam2 := c2 - r_a * 7.0 + a2 * -11.0
		_camera.global_position = Vector3(cam2.x, 5.5, cam2.y)
		var olho := c2 - r_a * -3.0 + a2 * 1.0
		_camera.look_at(Vector3(olho.x, 0.0, olho.y), Vector3.UP)

	var serie: Array[String] = []
	var antes := Vector3.INF
	var g_antes := NAN
	var w_antes := NAN
	var a_lat := 0.0
	var salto := 0.0
	var contramao := -INF
	var calcada := -INF
	var estac := -INF
	var reta := 0.0
	var v_min_curva := INF
	var seta_vista := 0
	var desac := 0.0
	var v_antes := NAN
	var parado := 0.0
	var tt := 0.0
	var chegou := false
	while tt < T_MAX:
		await physics_frame
		tt += PASSO
		# O relogio do sinal so anda na esquina sem semaforo: o PARE conta a
		# espera por ele. Com semaforo ele fica parado no verde posto acima — o
		# cenario mede a curva, e nao o sinal.
		if not Semaforo.tem_sinal(ij.x, ij.y):
			Semaforo.avancar(PASSO)
		var p := c.global_position
		var f := -c.global_transform.basis.z
		var g := atan2(-f.x, -f.z)
		if antes != Vector3.INF:
			var v := Vector2(p.x - antes.x, p.z - antes.z).length() / PASSO
			if not is_nan(g_antes):
				var w := wrapf(g - g_antes, -PI, PI) / PASSO
				a_lat = maxf(a_lat, absf(v * w))
				if not is_nan(w_antes):
					salto = maxf(salto, absf(w - w_antes))
				w_antes = w
			if not is_nan(v_antes):
				desac = maxf(desac, (v_antes - v) / PASSO)
			v_antes = v
			parado = parado + PASSO if v < 0.1 else 0.0
			if absf(wrapf(g - Manobra.rumo_de(a2), -PI, PI)) > 0.1 and lado != 0:
				v_min_curva = minf(v_min_curva, v)
		antes = p
		g_antes = g
		var s := int(c.call(&"seta"))
		if s != 0 and seta_vista == 0:
			seta_vista = s
		# Cantos da lataria no referencial da chegada (+Z, mao em x < 0).
		var esq := Vector2(-cos(g), sin(g))
		var f2 := Vector2(f.x, f.z).normalized()
		for sf: float in [1.0, -1.0]:
			for sl: float in [1.0, -1.0]:
				var q := Vector2(p.x, p.z) + f2 * (sf * comp * 0.5) + esq * (sl * larg * 0.5) - c2
				var cx := -q.dot(r_a)
				var cz := q.dot(a2)
				var ax := absf(cx)
				var az := absf(cz)
				if ax > asf_ap and az > asf_sai:
					calcada = maxf(calcada, minf(ax - asf_ap, az - asf_sai))
				if cz < -asf_sai and ax <= asf_ap + 5.0:
					contramao = maxf(contramao, cx)
				if lado != 0 and ax > asf_ap:
					var lat := -cz if lado > 0 else cz
					contramao = maxf(contramao, -lat)
					if lado < 0:
						estac = maxf(estac, lat - meia_sai)
		if lado == 0:
			# Andando reto: afastamento do centro da faixa em que devia estar.
			var alvo_faixa := para.x if rotulo == "TROCA" else t.x
			var linha := (Vias.linha_x(ij.x, sentido, alvo_faixa) if eixo == 0
				else Vias.linha_z(ij.y, sentido, alvo_faixa))
			var lateral := absf((p.x if eixo == 0 else p.z) - linha)
			var ao_longo := (p - centro).dot(dir)
			# Na troca, o que se afirma e que ela acabou antes da zebra e que o
			# carro atravessa o cruzamento na faixa nova — e nao o que ele faz
			# depois, quando ja pode estar indo para a faixa da esquina seguinte.
			if rotulo != "TROCA" or (ao_longo > -asf_sai - 6.0 and ao_longo < asf_sai + 2.0):
				reta = maxf(reta, lateral)
		if _csv != "":
			serie.append("%.3f,%.3f,%.3f,%.4f,%d" % [tt, p.x, p.z, g, s])
		if pasta_fotos != "" and Engine.get_physics_frames() % 6 == 0 \
				and Vector2(p.x, p.z).distance_to(c2) < 34.0:
			await process_frame
			root.get_texture().get_image().save_png(pasta_fotos.path_join("r_%.2f.png" % tt))
		if (p - centro).dot(b3) > 25.0:
			chegou = true
			break
		if parado > 8.0:
			break

	var nome_c := "%s %s" % [nome, rotulo]
	_relatar(nome_c, "chegou", chegou)
	_relatar(nome_c, "tempo_s", "%.1f" % tt)
	_relatar(nome_c, "a_lat_pico", "%.2f" % a_lat)
	_relatar(nome_c, "salto_guinada", "%.3f" % salto)
	_relatar(nome_c, "desacel_pico", "%.2f" % desac)
	if lado != 0:
		_relatar(nome_c, "v_min_curva", "%.2f" % v_min_curva)
		_relatar(nome_c, "contramao_m", "%.2f" % contramao)
		_relatar(nome_c, "calcada_m", "%.2f" % calcada)
		if lado < 0:
			_relatar(nome_c, "estac_m", "%.2f" % estac)
		_relatar(nome_c, "seta", seta_vista)
	else:
		_relatar(nome_c, "reta_m", "%.3f" % reta)

	_conta(nome_c, "chegou", chegou, "atravessou o cruzamento em %.1f s" % tt)
	_conta(nome_c, "freada", desac <= FREADA_MAX,
		"pico de desaceleracao %.2f m/s2 (teto %.1f)" % [desac, FREADA_MAX])
	_conta(nome_c, "a_lat", a_lat <= A_LAT_MAX, "pico %.2f m/s2 (teto %.1f)" % [a_lat, A_LAT_MAX])
	_conta(nome_c, "guinada", salto <= SALTO_MAX, "salto %.3f rad/s (teto %.1f)" % [salto, SALTO_MAX])
	if lado != 0:
		_conta(nome_c, "contramao", contramao <= 0.0, "%+.2f m alem do eixo" % contramao)
		_conta(nome_c, "calcada", calcada <= 0.0, "%+.2f m na calcada" % calcada)
		if lado < 0:
			_conta(nome_c, "estac", estac <= 0.0, "%+.2f m alem da pista de saida" % estac)
		_conta(nome_c, "seta", seta_vista == lado_esperado,
			"seta %d, curva para %d" % [seta_vista, lado_esperado])
	else:
		_conta(nome_c, "reta", reta <= RETA_MAX, "%.3f m do centro da faixa (teto %.2f)" % [reta, RETA_MAX])

	if _csv != "":
		DirAccess.make_dir_recursive_absolute(_csv)
		var arq := FileAccess.open(_csv.path_join("%s_%s_%s.csv" % [nome, rotulo.to_lower(),
			"nova" if _nova else "antiga"]), FileAccess.WRITE)
		arq.store_line("# ij=%s eixo=%d sentido=%d comp=%.2f larg=%.2f" % [ij, eixo, sentido, comp, larg])
		arq.store_line("t,x,z,rumo,seta")
		for l in serie:
			arq.store_line(l)
		arq.close()
	c.queue_free()
	await physics_frame
	await physics_frame


# --- o pe (Passo 2) --------------------------------------------------------------

## Um carro da IA na faixa `faixa` de quem chega ao cruzamento de `achado`, a
## `dist` metros do centro, seguindo reto nele.
func _plantar_carro(achado: Dictionary, dist: float, faixa := 0) -> Node3D:
	var ij: Vector2i = achado["ij"]
	var t := Vias.trecho(achado["eixo"], achado["sentido"], faixa)
	var dir := Vias.direcao(t.z, t.w)
	var ponto := Vector3(float(ij.x) * Vias.TAM, 0.05, float(ij.y) * Vias.TAM) - dir * dist
	if t.z == 0:
		ponto.x = Vias.linha_x(ij.x, t.w, faixa)
	else:
		ponto.z = Vias.linha_z(ij.y, t.w, faixa)
	_semente += 17
	var ficha: Dictionary = _registro.call(&"identidade",
		_registro.call(&"id_de_transeunte", _semente))
	var c: Node3D = _script_carro.new()
	c.call(&"preparar", ficha, achado["de"], t, _semente)
	c.position = ponto
	_mundo.add_child(c)
	c.call(&"plantar", achado["de"], t, ponto)
	var ia: Variant = c.get(&"_ia")
	if ia != null:
		var reto: Array[int] = [int(_script_ia.get_script_constant_map()["Rumo"]["RETO"])]
		(ia as RefCounted).call(&"forcar", reto)
	else:
		c.set(&"_saida_plana", t)
		c.set(&"_tem_plano", true)
	return c


## Quanto falta para o bico chegar na linha de retencao PINTADA (positivo: antes
## dela). A regua e a pintura, e nao a conta do motorista: `ChunkBuilder._retencao`
## pinta de `asf + 2,22` a `asf + 2,50` nos bracos norte e leste e de
## `asf + 2,50` a `asf + 2,78` nos sul e oeste, e a borda que conta e a do lado
## de quem chega. (Ate o Passo 2 esta regua usava a meia PISTA da transversal,
## a mesma conta errada do carro, e aprovava o bico em cima da zebra.)
func _bico_ate_linha(c: Node3D, ij: Vector2i, eixo: int, sentido: int) -> float:
	return -_linha_pintada(ij, eixo, sentido) - _bico_ao_longo(c, ij, eixo, sentido)


## Quanto falta para o bico chegar na zebra (positivo: antes dela).
func _bico_ate_zebra(c: Node3D, ij: Vector2i, eixo: int, sentido: int) -> float:
	var asf := (Vias.meia_asfalto_z_no(ij.x, ij.y) if eixo == 0
		else Vias.meia_asfalto_x_no(ij.x, ij.y))
	return -(asf + ZEBRA_ATE) - _bico_ao_longo(c, ij, eixo, sentido)


static func _linha_pintada(ij: Vector2i, eixo: int, sentido: int) -> float:
	var asf := (Vias.meia_asfalto_z_no(ij.x, ij.y) if eixo == 0
		else Vias.meia_asfalto_x_no(ij.x, ij.y))
	return asf + Vias.FOLGA_RETENCAO + (0.28 if sentido > 0 else 0.0)


func _bico_ao_longo(c: Node3D, ij: Vector2i, eixo: int, sentido: int) -> float:
	var a := Vias.direcao(eixo, sentido)
	var comp := float((c.get(&"_medidas") as Dictionary)["comprimento"])
	var f := -c.global_transform.basis.z
	var bico := c.global_position + Vector3(f.x, 0.0, f.z).normalized() * comp * 0.5
	return (bico.x - float(ij.x) * Vias.TAM) * a.x + (bico.z - float(ij.y) * Vias.TAM) * a.z


## Poe o sinal de `ij` no comeco do verde, do amarelo ou do vermelho de quem
## anda no `eixo`. O relogio so anda se a bancada mandar.
func _luz(ij: Vector2i, eixo: int, qual: Semaforo.Luz) -> void:
	var meu := 0.0 if eixo == 0 else Semaforo.CICLO * 0.5
	var fase := meu + 0.05
	if qual == Semaforo.Luz.AMARELO:
		fase = meu + Semaforo.VERDE_S + 0.01
	elif qual == Semaforo.Luz.VERMELHO:
		fase = meu + Semaforo.CICLO * 0.5 + 0.3
	Semaforo._agora = fposmod(fase - Semaforo.defasagem(ij.x, ij.y), Semaforo.CICLO)


## Velocidade de cada carro pelo deslocamento de um passo (o que o olho ve).
class Regua:
	var antes := {}
	var v := {}
	var desac := {}

	func passo(carros: Array) -> void:
		for c: Node3D in carros:
			var p := c.global_position
			var id := c.get_instance_id()
			if antes.has(id):
				var q: Vector3 = antes[id]
				var vel := Vector2(p.x - q.x, p.z - q.z).length() / PASSO
				if v.has(id):
					desac[id] = maxf(float(desac.get(id, 0.0)), (float(v[id]) - vel) / PASSO)
				v[id] = vel
			antes[id] = p

	func vel(c: Node3D) -> float:
		return float(v.get(c.get_instance_id(), 0.0))

	func pico(c: Node3D) -> float:
		return float(desac.get(c.get_instance_id(), 0.0))

	func zerar_picos() -> void:
		desac.clear()


## Parada no vermelho: o carro chega a toda e para. Onde o bico para, e com que
## freada.
func _c_parada(tipo: String, rotulo: String) -> void:
	var achado := _achar(tipo)
	if achado.is_empty():
		_conta(rotulo, "achado", false, "sem cruzamento %s" % tipo)
		return
	var ij: Vector2i = achado["ij"]
	var eixo: int = achado["eixo"]
	var sentido: int = achado["sentido"]
	print("\n=== %s: %s em %s, no vermelho ===" % [rotulo, tipo, ij])
	_luz(ij, eixo, Semaforo.Luz.VERMELHO)
	var c := _plantar_carro(achado, minf(75.0, float(achado["recuo"]) - 8.0))
	var med := Regua.new()
	var v_ini := float(c.call(&"velocidade"))
	var comecou := INF
	var parado := 0.0
	var tt := 0.0
	var a_antes := NAN
	var jerk := 0.0
	var serie: Array[String] = []
	while tt < 30.0 and parado < 1.5:
		await physics_frame
		tt += PASSO
		med.passo([c])
		var v := med.vel(c)
		parado = parado + PASSO if v < 0.02 else 0.0
		if _csv != "":
			serie.append("%.3f,%.3f,%.3f" % [tt, _bico_ate_linha(c, ij, eixo, sentido), v])
		var ia: Variant = c.get(&"_ia")
		if ia != null:
			var a := float((ia as RefCounted).call(&"aceleracao"))
			# So andando: o degrau de quando o carro imobiliza (o alivio deixa
			# 0,35 m/s2) e inerente a parar, e nao diz nada do pedal.
			if not is_nan(a_antes) and v > 0.3:
				jerk = maxf(jerk, absf(a - a_antes) / PASSO)
			a_antes = a
			if comecou == INF and a < -0.5:
				comecou = _bico_ate_linha(c, ij, eixo, sentido)
	var antes := _bico_ate_linha(c, ij, eixo, sentido)
	var zebra := _bico_ate_zebra(c, ij, eixo, sentido)
	var pico := med.pico(c)
	if _csv != "":
		DirAccess.make_dir_recursive_absolute(_csv)
		var arq := FileAccess.open(_csv.path_join("%s_%s.csv" % [rotulo,
			"nova" if _nova else "antiga"]), FileAccess.WRITE)
		arq.store_line("t,bico_ate_linha,v")
		for l in serie:
			arq.store_line(l)
		arq.close()
	_relatar(rotulo, "v_inicial", "%.1f" % v_ini)
	_relatar(rotulo, "freada_pico", "%.2f" % pico)
	_relatar(rotulo, "comecou_a_frear_m", "%.1f" % comecou)
	_relatar(rotulo, "jerk_pico", "%.1f" % jerk)
	_relatar(rotulo, "bico_antes_da_linha_m", "%.2f" % antes)
	_conta(rotulo, "parou", parado >= 1.5, "parou no vermelho (%.1f s)" % tt)
	_conta(rotulo, "freada", pico <= FREADA_MAX,
		"pico %.2f m/s2 vindo de %.1f m/s (teto %.1f)" % [pico, v_ini, FREADA_MAX])
	_conta(rotulo, "onde", antes >= 0.0 and antes <= PARADA_ANTES_MAX,
		"bico %.2f m antes da linha pintada (entre 0 e %.1f)" % [antes, PARADA_ANTES_MAX])
	_relatar(rotulo, "bico_antes_da_zebra_m", "%.2f" % zebra)
	_conta(rotulo, "zebra", zebra >= ZEBRA_FOLGA,
		"bico %.2f m antes da zebra (minimo %.1f; negativo e em cima dela)" % [zebra, ZEBRA_FOLGA])
	c.queue_free()
	await physics_frame


## Fila de tres no vermelho; abre o verde. Quando cada um sai, e se pararam
## atras um do outro.
func _c_partida() -> void:
	var achado := _achar("rua_av")
	if achado.is_empty():
		_conta("partida", "achado", false, "sem cruzamento rua_av")
		return
	var ij: Vector2i = achado["ij"]
	var eixo: int = achado["eixo"]
	var sentido: int = achado["sentido"]
	print("\n=== partida: fila de tres em %s ===" % ij)
	_luz(ij, eixo, Semaforo.Luz.VERMELHO)
	var carros: Array = []
	for k in 3:
		carros.append(_plantar_carro(achado, 22.0 + 12.0 * float(k)))
	var med := Regua.new()
	var tt := 0.0
	var parados := 0.0
	while tt < 30.0 and parados < 1.0:
		await physics_frame
		tt += PASSO
		med.passo(carros)
		var todos := true
		for c: Node3D in carros:
			todos = todos and med.vel(c) < 0.02
		parados = parados + PASSO if todos else 0.0
	var dir := Vias.direcao(eixo, sentido)
	var centro_min := INF
	for k in range(1, 3):
		centro_min = minf(centro_min, ((carros[k - 1] as Node3D).global_position
			- (carros[k] as Node3D).global_position).dot(dir))
	var antes := _bico_ate_linha(carros[0], ij, eixo, sentido)
	_luz(ij, eixo, Semaforo.Luz.VERDE)
	var saiu: Array[float] = [-1.0, -1.0, -1.0]
	var tv := 0.0
	while tv < 12.0 and saiu[2] < 0.0:
		await physics_frame
		tv += PASSO
		med.passo(carros)
		for k in 3:
			if saiu[k] < 0.0 and med.vel(carros[k]) > 0.1:
				saiu[k] = tv
	_relatar("partida", "bico_do_primeiro_antes_da_linha_m", "%.2f" % antes)
	_relatar("partida", "fila_centro_min_m", "%.2f" % centro_min)
	_relatar("partida", "saidas_s", "%.2f, %.2f, %.2f" % [saiu[0], saiu[1], saiu[2]])
	_conta("partida", "fila", centro_min >= FILA_CENTRO_MIN,
		"parados a %.2f m de centro a centro (minimo %.1f)" % [centro_min, FILA_CENTRO_MIN])
	_conta("partida", "primeiro", saiu[0] >= PARTIDA_1_MIN and saiu[0] <= PARTIDA_1_MAX,
		"o primeiro saiu %.2f s depois do verde (entre %.1f e %.1f)" % [saiu[0],
			PARTIDA_1_MIN, PARTIDA_1_MAX])
	_conta("partida", "terceiro", saiu[2] >= 0.0 and saiu[2] <= PARTIDA_3_MAX,
		"o terceiro saiu %.2f s depois do verde (teto %.1f)" % [saiu[2], PARTIDA_3_MAX])
	for c: Node3D in carros:
		c.queue_free()
	await physics_frame


## O amarelo acende com o bico a `dist` metros da linha, a 14 m/s. Contando o
## curso do pedal (`Longitudinal.freada_para_parar`): a 20 m parar pediria mais
## de 5 m/s2 e a 30 m uns 4,1 — passa, e cruza antes do vermelho (3 s de
## amarelo). A 36 m pede uns 3,2, perto do teto de 3,5: para, e a freada real
## nao pode passar do teto nem o alivio do fim empurrar o bico alem da linha. A
## 45 m pede 2,4: para com folga.
func _c_amarelo(dist: float, deve_passar: bool) -> void:
	var rotulo := "amarelo_%dm" % int(dist)
	var achado := _achar("av_av")
	if achado.is_empty():
		_conta(rotulo, "achado", false, "sem cruzamento av_av")
		return
	var ij: Vector2i = achado["ij"]
	var eixo: int = achado["eixo"]
	var sentido: int = achado["sentido"]
	print("\n=== %s em %s ===" % [rotulo, ij])
	_luz(ij, eixo, Semaforo.Luz.VERDE)
	var c := _plantar_carro(achado, minf(70.0, float(achado["recuo"]) - 8.0))
	var med := Regua.new()
	var aceso := false
	var t_am := 0.0
	var cruzou := -1.0
	var parado := 0.0
	var tt := 0.0
	var v_no_amarelo := 0.0
	while tt < 25.0:
		await physics_frame
		tt += PASSO
		med.passo([c])
		var bico := _bico_ate_linha(c, ij, eixo, sentido)
		if not aceso and bico <= dist:
			_luz(ij, eixo, Semaforo.Luz.AMARELO)
			aceso = true
			v_no_amarelo = med.vel(c)
			med.zerar_picos()
		elif aceso:
			Semaforo._agora += PASSO
			t_am += PASSO
			if cruzou < 0.0 and bico < 0.0:
				cruzou = t_am
			parado = parado + PASSO if med.vel(c) < 0.02 else 0.0
			if parado > 1.5 or (cruzou >= 0.0 and t_am > cruzou + 2.0):
				break
	var pico := med.pico(c)
	var antes := _bico_ate_linha(c, ij, eixo, sentido)
	_relatar(rotulo, "v_no_amarelo", "%.1f" % v_no_amarelo)
	_relatar(rotulo, "cruzou_a_linha_s", "%.2f" % cruzou)
	_relatar(rotulo, "freada_pico", "%.2f" % pico)
	if deve_passar:
		_conta(rotulo, "passou", cruzou >= 0.0 and cruzou < Semaforo.AMARELO_S,
			"cruzou a linha %.2f s depois do amarelo (antes dos %.1f s do vermelho)" % [
				cruzou, Semaforo.AMARELO_S])
		_conta(rotulo, "sem_panico", pico <= 1.0,
			"freada depois do amarelo %.2f m/s2 (teto 1,0: nao freia para passar)" % pico)
	else:
		_conta(rotulo, "parou", cruzou < 0.0 and parado > 1.5 and antes >= 0.0,
			"parou com o bico %.2f m antes da linha" % antes)
		_conta(rotulo, "freada", pico <= 3.5,
			"freada %.2f m/s2 (teto 3,5, o de quem decide parar no amarelo)" % pico)
	c.queue_free()
	await physics_frame


## Um carro na reta de bancada (x = `x`, de z = -1400 a 1400), com o centro em
## z = `z`, na velocidade da via `v_via`.
func _carro_fixo(x: float, z: float, v_via: float) -> Node3D:
	_semente += 17
	var ficha: Dictionary = _registro.call(&"identidade",
		_registro.call(&"id_de_transeunte", _semente))
	var c: Node3D = _script_carro.new()
	c.call(&"preparar", ficha, Vector2i.ZERO, Vias.trecho(0, 1, 0), _semente)
	c.position = Vector3(x, 0.05, z)
	_mundo.add_child(c)
	(c.get(&"_ia") as RefCounted).call(&"caminho_de_bancada", Vector2(x, -1400.0),
		Vector2(x, 1400.0), v_via)
	c.set(&"_velocidade", v_via)
	return c


## Seguindo um carro mais lento numa reta: o intervalo de tempo em regime.
func _c_fila() -> void:
	print("\n=== fila: seguindo um carro a 10,5 m/s ===")
	var seguidor := _carro_fixo(1500.0, -1380.0, 11.0)
	var lider := _carro_fixo(1500.0, -1340.0, 10.5)
	var comp := float((seguidor.get(&"_medidas") as Dictionary)["comprimento"])
	var comp_l := float((lider.get(&"_medidas") as Dictionary)["comprimento"])
	var med := Regua.new()
	var soma := 0.0
	var n := 0
	var tt := 0.0
	while tt < 50.0:
		await physics_frame
		tt += PASSO
		med.passo([seguidor, lider])
		if tt > 40.0:
			var gap := lider.global_position.z - seguidor.global_position.z - (comp + comp_l) * 0.5
			var v := med.vel(seguidor)
			if v > 1.0:
				soma += gap / v
				n += 1
	var intervalo := soma / maxf(1.0, float(n))
	_relatar("fila", "v_seguidor", "%.2f" % med.vel(seguidor))
	_relatar("fila", "intervalo_s", "%.2f" % intervalo)
	_conta("fila", "intervalo", intervalo >= INTERVALO_MIN and intervalo <= INTERVALO_MAX,
		"segue a %.2f s do da frente (entre %.1f e %.1f)" % [intervalo, INTERVALO_MIN,
			INTERVALO_MAX])
	seguidor.queue_free()
	lider.queue_free()
	await physics_frame


## Cinco carros em fila a 11 m/s; o da frente freia a 3 m/s2 ate parar.
func _c_onda() -> void:
	print("\n=== onda: o primeiro de cinco freia a 3 m/s2 ===")
	var carros: Array = []
	for k in 5:
		carros.append(_carro_fixo(1700.0, -1100.0 - 23.0 * float(k), 11.0))
	var med := Regua.new()
	var tt := 0.0
	while tt < 15.0:
		await physics_frame
		tt += PASSO
		med.passo(carros)
	(carros[0].get(&"_ia") as RefCounted).set(&"roteiro_a", -3.0)
	med.zerar_picos()
	var menor := INF
	tt = 0.0
	# Ate todos pararem: dali a 2,4 s o criterio de contorno (que nao e deste
	# passo) mandaria os de tras ultrapassar o da frente parado sem motivo.
	var parados := 0.0
	while tt < 15.0 and parados < 0.5:
		await physics_frame
		tt += PASSO
		med.passo(carros)
		var todos := true
		for c: Node3D in carros:
			todos = todos and med.vel(c) < 0.05
		parados = parados + PASSO if todos else 0.0
		for k in range(1, 5):
			var a: Node3D = carros[k - 1]
			var b: Node3D = carros[k]
			var ca := float((a.get(&"_medidas") as Dictionary)["comprimento"])
			var cb := float((b.get(&"_medidas") as Dictionary)["comprimento"])
			# Quem ja esta contornando saiu da fila (o criterio de contorno manda
			# ultrapassar, 2,4 s depois, quem parou sem motivo — e o lider do
			# roteiro parou sem motivo). A distancia ao longo da rua deixa de ser
			# contato.
			if bool(b.call(&"contornando")):
				continue
			menor = minf(menor, a.global_position.z - b.global_position.z - (ca + cb) * 0.5)
	var picos: Array[String] = []
	var pior := 0.0
	for k in range(1, 5):
		picos.append("%.2f" % med.pico(carros[k]))
		pior = maxf(pior, med.pico(carros[k]))
	_relatar("onda", "picos_seguidores", ", ".join(picos))
	_relatar("onda", "menor_distancia_m", "%.2f" % menor)
	_conta("onda", "sem_contato", menor > 0.5,
		"a menor distancia entre para-choques foi %.2f m" % menor)
	_conta("onda", "freada", pior <= ONDA_MAX,
		"o seguidor que mais freou: %.2f m/s2 (teto %.1f)" % [pior, ONDA_MAX])
	for c: Node3D in carros:
		c.queue_free()
	await physics_frame


## Quanto custa UM passo de direcao da IA (a antiga ou a nova, conforme a
## bandeira), fora do resto do carro: um carro sem `_physics_process`, na faixa
## de uma rua, com `_dirigir_ia` chamado a mao 1200 vezes (20 s de rua, com
## curvas). E a mesma chamada que o `Carro` faz a cada passo de fisica.
func _custo_do_passo() -> void:
	var achado := _achar("rua_rua")
	if achado.is_empty():
		return
	var ij: Vector2i = achado["ij"]
	var t := Vias.trecho(achado["eixo"], achado["sentido"], 0)
	var dir := Vias.direcao(t.z, t.w)
	var ponto := Vector3(float(ij.x) * Vias.TAM, 0.05, float(ij.y) * Vias.TAM) - dir * 40.0
	if t.z == 0:
		ponto.x = Vias.linha_x(ij.x, t.w, 0)
	else:
		ponto.z = Vias.linha_z(ij.y, t.w, 0)
	_semente += 17
	var ficha: Dictionary = _registro.call(&"identidade",
		_registro.call(&"id_de_transeunte", _semente))
	var c: Node3D = _script_carro.new()
	c.call(&"preparar", ficha, achado["de"], t, _semente)
	c.position = ponto
	_mundo.add_child(c)
	await physics_frame
	c.call(&"plantar", achado["de"], t, ponto)
	c.set_physics_process(false)
	var soma := 0.0
	var pior := 0.0
	var n := 1200
	for k in n:
		var t0 := Time.get_ticks_usec()
		c.call(&"_dirigir_ia", PASSO)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		soma += ms
		pior = maxf(pior, ms)
		Semaforo.avancar(PASSO)
		if k % 60 == 0:
			await process_frame
	print("[bancada_transito] custo_passo_%s_medio_ms=%.4f pior_ms=%.3f andou_m=%.0f" % [
		"nova" if _nova else "antiga", soma / float(n), pior,
		c.global_position.distance_to(ponto)])
	c.queue_free()
	await physics_frame


## As duas ruas pintadas no chao plano, para as fotos: asfalto, borda da pista
## (a faixa de estacionamento fica fora dela) e o eixo tracejado de amarelo.
func _pintar(c2: Vector2, a2: Vector2, r_a: Vector2, asf_ap: float, asf_sai: float,
		meia_sai: float, meia_ap: float) -> void:
	if _pintura != null:
		_pintura.queue_free()
	_pintura = Node3D.new()
	_mundo.add_child(_pintura)
	var b2 := r_a  # a transversal corre de lado
	_faixa(c2, a2, 2.0 * asf_ap, 90.0, 0.004, Color(0.36, 0.36, 0.38))
	_faixa(c2, b2, 2.0 * asf_sai, 90.0, 0.005, Color(0.36, 0.36, 0.38))
	_faixa(c2, a2, 90.0, 90.0, 0.002, Color(0.78, 0.76, 0.72))
	for lado: float in [1.0, -1.0]:
		for k in 2:
			var s := 1.0 if k == 0 else -1.0
			# Borda da pista e eixo, so fora do miolo.
			var meio_a := c2 + a2 * s * (asf_sai + 22.5)
			_faixa(meio_a + r_a * lado * meia_ap, a2, 0.08, 45.0, 0.008, Color(0.85, 0.85, 0.85))
			var meio_b := c2 + b2 * s * (asf_ap + 22.5)
			_faixa(meio_b + a2 * lado * meia_sai, b2, 0.08, 45.0, 0.008, Color(0.85, 0.85, 0.85))
	for k in range(-22, 23):
		if absf(float(k) * 2.0) > asf_sai + 0.5:
			_faixa(c2 + a2 * float(k) * 2.0, a2, 0.12, 1.0, 0.009, Color(0.95, 0.8, 0.2))
		if absf(float(k) * 2.0) > asf_ap + 0.5:
			_faixa(c2 + b2 * float(k) * 2.0, b2, 0.12, 1.0, 0.009, Color(0.95, 0.8, 0.2))


func _faixa(centro: Vector2, ao_longo: Vector2, largura: float, comprimento: float,
		y: float, cor: Color) -> void:
	var m := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = Vector3(largura, 0.002, comprimento)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	caixa.material = mat
	m.mesh = caixa
	var frente := Vector3(ao_longo.x, 0.0, ao_longo.y)
	m.transform = Transform3D(Basis.looking_at(frente, Vector3.UP), Vector3(centro.x, y, centro.y))
	_pintura.add_child(m)


func _relatar(nome: String, chave: String, valor: Variant) -> void:
	print("[bancada_transito] %s %s=%s" % [nome, chave, str(valor)])


func _conta(nome: String, criterio: String, ok: bool, texto: String) -> void:
	_total += 1
	if ok:
		_passou += 1
	print("%s %s %s: %s" % ["[ok]" if ok else "[X ]", nome, criterio, texto])
