## Cambio na pista: a sequencia de marchas numa arrancada de verdade.
##
##     godot --headless --fixed-fps 60 --path game --script res://tests/bancada_cambio.gd
##     ... -- --modelo=SEDA,FUSCA     so estes modelos (padrao: todos)
##     ... -- --serie                 imprime a serie inteira, quadro a quadro
##
## O jogador reportou (22/09/2026): "se acelerar ele ja pula pra quarta". A
## bancada de `TesteCarro` mede o cambio sem chao (um corpo de uma dimensao), e
## la a sequencia sai certa. Aqui e o `Carro` inteiro, com roda, pneu e mola,
## num chao plano — o mesmo caminho do teclado, pelo `pilotar`.
##
## Para cada modelo e cada pe (100%, 60%, 35%), a partir do carro parado:
##
##   C1  as marchas entram UMA de cada vez, em ordem: 1, 2, 3...
##   C2  cada marcha fica engatada um tempo que se ouve (pelo menos 0,8 s
##       ate a penultima no pe no fundo)
##   C3  no pe no fundo a troca sobe perto do giro de potencia (pelo menos 80%
##       do `troca_sobe`), e no pe leve troca mais cedo que no fundo
##   C4  a primeira segura o carro ate uma velocidade de primeira (pelo menos
##       25 km/h no pe no fundo): e a queixa, medida
##   C5  o giro nunca cai abaixo da lenta depois de uma troca para cima
extends SceneTree

const PASSO := 1.0 / 60.0
const DURACAO := 22.0
const MODELOS := {
	"SEDA": 0, "HATCH": 1, "PERUA": 2, "PICAPE": 3, "TAXI": 4, "MAREA": 5,
	"FUSCA": 6,
}
const PES: Array[float] = [1.0, 0.6, 0.35]

var _script_carro: GDScript
var _modelos: Array[String] = []
var _serie := false
var _mundo: Node3D
var _passou := 0
var _total := 0


func _init() -> void:
	_modelos.assign(MODELOS.keys())
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--modelo="):
			_modelos.assign(a.trim_prefix("--modelo=").to_upper().split(","))
		elif a == "--serie":
			_serie = true
	_rodar.call_deferred()


func _rodar() -> void:
	await process_frame
	_script_carro = load("res://src/world/carro.gd") as GDScript
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
	for nome: String in _modelos:
		print("\n=== %s ===" % nome)
		await _alivio(nome)
		await _toques(nome)
		var pontos := {}
		for pe: float in PES:
			pontos[pe] = await _arrancada(nome, pe)
		# C3: pe leve troca mais cedo que o fundo (giro medio de troca).
		var fundo: float = pontos[1.0]
		var leve: float = pontos[0.35]
		if fundo > 0.0 and leve > 0.0:
			_conta(nome, "C3 leve<fundo", leve < fundo * 0.85,
				"troca media %.0f rpm no leve, %.0f no fundo" % [leve, fundo])
	print("\n%d de %d criterios" % [_passou, _total])
	quit(0 if _passou == _total else 1)


## Carro novo, ligado, parado e assentado no chao.
func _novo(nome: String) -> VehicleBody3D:
	var c: VehicleBody3D = _script_carro.new()
	c.set(&"modelo", MODELOS[nome])
	c.set(&"semente", 3)
	c.set(&"motorista", 0)
	_mundo.add_child(c)
	c.call(&"pousar", Vector3(0.0, 0.6, 0.0), 0.0)
	await physics_frame
	c.set(&"ligado", true)
	c.call(&"assumir", Node3D.new())
	c.call(&"pilotar", 0.0, 0.0, 0.0)
	var seco := float((c.get(&"_ficha") as Dictionary)["atrito"])
	for r: VehicleWheel3D in c.get(&"_rodas"):
		r.wheel_friction_slip = seco
	for _q in 180:
		await physics_frame
	return c


func _jogar_fora(c: VehicleBody3D) -> void:
	c.call(&"devolver")
	c.queue_free()
	await physics_frame
	await physics_frame


## Roda um roteiro de pedal: lista de [segundos, pe]. Devolve a serie de
## (t, v, marcha, giro) a cada quadro.
func _roteiro(c: VehicleBody3D, passos: Array) -> Array:
	var motor: Motor = c.get(&"_motor")
	var serie: Array = []
	var t := 0.0
	for p: Array in passos:
		var fim := t + float(p[0])
		while t < fim:
			c.call(&"pilotar", float(p[1]), 0.0, 0.0)
			await physics_frame
			t += PASSO
			serie.append([t, float(c.call(&"velocidade")), motor.marcha, motor.giro, float(p[1])])
	return serie


static func _sequencia(serie: Array) -> Array[int]:
	var seq: Array[int] = []
	for s: Array in serie:
		if seq.is_empty() or seq[-1] != int(s[2]):
			seq.append(int(s[2]))
	return seq


static func _texto(seq: Array[int]) -> String:
	return " ".join(seq.map(func(m: int) -> String: return str(m)))


## A queixa do jogador, montada: pe no fundo ate uns 40 km/h, tira o pe um
## segundo e meio, e volta a pisar.
##
##   A1  tirar o pe NAO sobe marcha em cascata (no maximo uma troca no alivio)
##   A2  pisar de novo devolve uma marcha que puxa: o giro volta para cima de
##       45% do corte em ate 1,2 s (reducao de kickdown, como um automatico)
func _alivio(nome: String) -> void:
	var c := await _novo(nome)
	var motor: Motor = c.get(&"_motor")
	var serie := await _roteiro(c, [[2.0, 1.0], [1.5, 0.0], [3.0, 1.0]])
	var seq := _sequencia(serie)
	var no_alivio: Array[int] = []
	var marcha_ao_soltar := 0
	var marcha_fim_alivio := 0
	var giro_repisada := 0.0
	var v_soltar := 0.0
	for s: Array in serie:
		var t := float(s[0])
		# A referencia e um quarto de segundo depois de soltar: o pedal tem
		# curso, e quem soltou no ponto de troca sobe ali por direito — nao e
		# cascata de alivio.
		if t <= 2.25:
			marcha_ao_soltar = int(s[2])
			v_soltar = float(s[1])
		elif t <= 3.5:
			marcha_fim_alivio = int(s[2])
		elif t <= 4.7:
			giro_repisada = maxf(giro_repisada, float(s[3]))
	var rotulo := "%s alivio" % nome
	print("%s: %s | soltou em %d a %.0f km/h, fim do alivio em %d, repisada ate %.0f rpm" % [
		rotulo, _texto(seq), marcha_ao_soltar, v_soltar * 3.6, marcha_fim_alivio, giro_repisada])
	_conta(rotulo, "A1 sem cascata", marcha_fim_alivio - marcha_ao_soltar <= 1,
		"%d -> %d so de tirar o pe" % [marcha_ao_soltar, marcha_fim_alivio])
	_conta(rotulo, "A2 repisada puxa", giro_repisada >= motor.giro_corte * 0.45,
		"giro ate %.0f rpm em 1,2 s (45%% do corte = %.0f)" % [giro_repisada, motor.giro_corte * 0.45])
	await _jogar_fora(c)


## Teclado de verdade: o pe vai e volta (0,35 s pisado, 0,25 s solto) por oito
## segundos, que e como se dirige na cidade com a tecla W.
##
##   T1  o cambio nao troca mais que uma vez por segundo, em media
##   T2  a marcha final nao passa da que o pe no fundo usaria nessa velocidade
func _toques(nome: String) -> void:
	var c := await _novo(nome)
	var passos: Array = []
	for _k in 14:
		passos.append([0.35, 1.0])
		passos.append([0.25, 0.0])
	var serie := await _roteiro(c, passos)
	var seq := _sequencia(serie)
	var trocas := seq.size() - 1
	var ultimo: Array = serie[-1]
	var v := float(ultimo[1])
	var motor: Motor = c.get(&"_motor")
	# A marcha que o pe no fundo teria nesta velocidade: a mais alta cujo giro
	# ainda fica acima do ponto de reducao no pe no fundo.
	var esperada := 1
	for m in range(1, motor.relacoes.size() + 1):
		var rpm := v / Motor.RAIO_PNEU * motor.relacoes[m - 1] * motor.diferencial * Motor.RPM_POR_RAD
		if rpm <= motor.troca_sobe:
			esperada = m
			break
	var rotulo := "%s toques" % nome
	print("%s: %s | %.0f km/h no fim, em %d (pe no fundo usaria %d)" % [
		rotulo, _texto(seq), v * 3.6, int(ultimo[2]), esperada])
	var tempo := float(ultimo[0])
	_conta(rotulo, "T1 calma", float(trocas) / tempo <= 1.0,
		"%d trocas em %.1f s" % [trocas, tempo])
	_conta(rotulo, "T2 marcha certa", int(ultimo[2]) <= esperada + 1,
		"terminou em %d, o fundo usaria %d" % [int(ultimo[2]), esperada])
	await _jogar_fora(c)


## Uma arrancada. Devolve o giro medio em que subiu de marcha.
func _arrancada(nome: String, pe: float) -> float:
	var c: VehicleBody3D = _script_carro.new()
	c.set(&"modelo", MODELOS[nome])
	c.set(&"semente", 3)
	c.set(&"motorista", 0)
	_mundo.add_child(c)
	c.call(&"pousar", Vector3(0.0, 0.6, 0.0), 0.0)
	await physics_frame
	c.set(&"ligado", true)
	c.call(&"assumir", Node3D.new())
	c.call(&"pilotar", 0.0, 0.0, 0.0)
	var seco := float((c.get(&"_ficha") as Dictionary)["atrito"])
	for r: VehicleWheel3D in c.get(&"_rodas"):
		r.wheel_friction_slip = seco
	for _q in 180:
		await physics_frame
	var motor: Motor = c.get(&"_motor")
	var ficha: Dictionary = c.get(&"_ficha")
	var troca_sobe := float(ficha["troca_sobe"])
	var lenta := motor.giro_lenta

	var marcha := motor.marcha
	var desde := 0.0
	var t := 0.0
	var seq: Array[int] = [marcha]
	var trocas: Array[String] = []
	var giros_troca: Array[float] = []
	var tempos: Array[float] = []
	var giro_antes := motor.giro
	var vel_antes := 0.0
	var pior_pos_troca := INF
	var vel_fim_primeira := 0.0
	var linhas: Array[String] = []
	while t < DURACAO:
		c.call(&"pilotar", pe, 0.0, 0.0)
		await physics_frame
		t += PASSO
		var v: float = c.call(&"velocidade")
		if _serie and fmod(t, 0.25) < PASSO:
			linhas.append("  t %5.2f  v %5.1f km/h  marcha %d  giro %4.0f  trocando %.2f" % [
				t, v * 3.6, motor.marcha, motor.giro, motor.trocando])
		if motor.marcha != marcha:
			if marcha == 1 and motor.marcha > 1:
				vel_fim_primeira = vel_antes
			trocas.append("%d->%d em %.2fs a %.0f km/h, %.0f rpm" % [marcha,
				motor.marcha, t, vel_antes * 3.6, giro_antes])
			if motor.marcha > marcha:
				giros_troca.append(giro_antes)
			tempos.append(t - desde)
			desde = t
			marcha = motor.marcha
			seq.append(marcha)
		elif trocas.size() > 0 and motor.trocando <= 0.0 and t - desde < 1.5:
			pior_pos_troca = minf(pior_pos_troca, motor.giro)
		giro_antes = motor.giro
		vel_antes = v

	var v_fim: float = c.call(&"velocidade")
	var rotulo := "%s pe %.0f%%" % [nome, pe * 100.0]
	print("%s: %s | final %.0f km/h em %d" % [rotulo, " ".join(seq.map(func(m: int) -> String: return str(m))),
		v_fim * 3.6, motor.marcha])
	for l: String in trocas:
		print("    " + l)
	for l: String in linhas:
		print(l)

	# C1: em ordem, de uma em uma.
	var em_ordem := true
	for k in range(1, seq.size()):
		if seq[k] != seq[k - 1] + 1:
			em_ordem = false
	_conta(rotulo, "C1 ordem", em_ordem, " ".join(seq.map(func(m: int) -> String: return str(m))))
	# C2: cada marcha fica pelo menos 0,8 s (menos a primeira troca, que conta da largada).
	if pe >= 1.0 and tempos.size() > 1:
		var menor := INF
		for k in range(0, tempos.size()):
			menor = minf(menor, tempos[k])
		_conta(rotulo, "C2 permanencia", menor >= 0.8, "menor permanencia %.2f s" % menor)
	# C3: no fundo troca perto do ponto de potencia.
	var media := 0.0
	for g: float in giros_troca:
		media += g / float(giros_troca.size())
	if pe >= 1.0 and not giros_troca.is_empty():
		_conta(rotulo, "C3 ponto", media >= troca_sobe * 0.8,
			"troca media %.0f rpm, ponto %.0f" % [media, troca_sobe])
	# C4: a primeira vai ate velocidade de primeira.
	if pe >= 1.0:
		_conta(rotulo, "C4 primeira", vel_fim_primeira * 3.6 >= 25.0,
			"primeira ate %.0f km/h" % (vel_fim_primeira * 3.6))
	# C5: giro depois de subir.
	if pior_pos_troca < INF:
		_conta(rotulo, "C5 lenta", pior_pos_troca >= lenta * 1.05,
			"menor giro depois de trocar %.0f (lenta %.0f)" % [pior_pos_troca, lenta])

	c.call(&"devolver")
	c.queue_free()
	await physics_frame
	await physics_frame
	return media


func _conta(nome: String, criterio: String, ok: bool, texto: String) -> void:
	_total += 1
	if ok:
		_passou += 1
	print("%s %s %s: %s" % ["[ok]" if ok else "[X ]", nome, criterio, texto])
