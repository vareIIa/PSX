## Bancada do som do motor: o mixer do `MotorSom` com o banco por fisica.
##
##     godot --headless --path game --script res://tests/bancada_motor_som.gd
##     godot --path game --resolution 400x300 --script res://tests/bancada_motor_som.gd
##
## A primeira forma mede a LOGICA: afinacao, pesos, volumes e custo, lendo os
## tocadores. A segunda faz isso e mais a SAIDA: um `AudioEffectCapture` no
## Master grava o que iria para a caixa numa varredura de giro em tempo real
## (sem `--headless`: o driver mudo nao devolve amostra nenhuma — ver
## `tests/bancada_audio.gd`).
##
## O que se afirma, por arquitetura (i4, i3, boxer)
## ------------------------------------------------
## Varredura da lenta ao corte e de volta, primeiro em carga, depois em retencao,
## 60 quadros por segundo:
##
##   afinacao   todo tocador do banco em giro * caracter / referencia, e o
##              produto afinacao * referencia IGUAL em todos — e o que mantem os
##              pulsos de pontos vizinhos no mesmo passo durante o cruzamento.
##   estica     o quanto a camada audivel mais esticada foge da propria
##              referencia (fora o caracter do carro). Dentro da grade, no
##              maximo a razao entre dois pontos vizinhos.
##   potencia   raiz da soma dos quadrados dos pesos das camadas: 0 dB em todo
##              quadro, em qualquer ponto de cruzamento.
##   linear     soma simples dos pesos, em carga constante: entre 0 e +3 dB.
##   nivel      o nivel RMS previsto da mistura (peso de cada camada vezes o RMS
##              do proprio arquivo, somados em potencia). Nao pode dar degrau:
##              o maior salto entre dois quadros vizinhos tem de ficar abaixo de
##              0,5 dB.
##   NaN        nenhum volume ou afinacao nao-finito.
##   vozes      quantos tocadores em laco rodam no carro do jogador.
##   custo      microssegundos de `atualizar` por quadro.
##
## E mais: o laco de cada amostra (PCM, fim do laco antes da amostra de guarda),
## o carro de rua (uma voz so), e a troca de arquitetura com o motor rodando.
extends SceneTree

const QUADRO := 1.0 / 60.0
## Duracao de cada perna da varredura, em quadros.
const PERNA := 180

var _passou := 0
var _total := 0
var _classe: GDScript
var _captura: AudioEffectCapture
var _com_saida := false


func _init() -> void:
	_rodar()


func _rodar() -> void:
	await process_frame
	# Carregado aqui, e nao por `class_name`: em `--script` o script de entrada e
	# compilado antes dos autoloads existirem, e o `MotorSom` fala com o
	# `AudioDirector` pelo nome.
	_classe = load("res://src/systems/motor_som.gd") as GDScript
	_com_saida = DisplayServer.get_name() != "headless"
	root.audio_listener_enable_3d = true
	for nome: StringName in [&"Master", &"SFX"]:
		var i := AudioServer.get_bus_index(nome)
		if i >= 0:
			AudioServer.set_bus_volume_db(i, 0.0)
			AudioServer.set_bus_mute(i, false)
	if _com_saida:
		_captura = AudioEffectCapture.new()
		_captura.buffer_length = 2.0
		AudioServer.add_bus_effect(0, _captura)
	var ouvinte := Camera3D.new()
	ouvinte.position = Vector3(0.0, 1.2, 0.0)
	root.add_child(ouvinte)
	ouvinte.current = true
	await process_frame

	print("\n=== bancada do som do motor ===")
	print("driver %s, %.0f Hz, saida %s\n" % [AudioServer.get_driver_name(),
		AudioServer.get_mix_rate(), "capturada" if _com_saida else "nao (headless: so a logica)"])
	for arq: StringName in [&"i4", &"i3", &"boxer"]:
		await _bancar(arq)
	await _rua()
	await _trocar_com_motor_rodando()
	print("\n%d de %d criterios" % [_passou, _total])
	quit(0 if _passou == _total else 1)


func _conta(nome: String, ok: bool, texto: String) -> void:
	_total += 1
	if ok:
		_passou += 1
	print("%s %s: %s" % ["[ok]" if ok else "[X ]", nome, texto])


## Um motor no mundo, a 3 m do ouvinte, ja caracterizado e ligado.
func _motor(arq: StringName, detalhar: bool, corte: float) -> Node3D:
	var m: Node3D = _classe.new()
	m.position = Vector3(0.0, 1.0, -3.0)
	root.add_child(m)
	m.call(&"caracterizar", 4242, corte)
	m.call(&"definir_arquitetura", arq)
	if detalhar:
		m.call(&"detalhar")
	return m


static func _corte_de(arq: StringName) -> float:
	match arq:
		&"boxer":
			return 4700.0
		&"i3":
			return 6900.0
	return 6500.0


func _bancar(arq: StringName) -> void:
	var corte := _corte_de(arq)
	var lenta := clampf(corte * 0.135, 600.0, 1000.0)
	var m := _motor(arq, true, corte)
	# Dois quadros parado antes de tocar: com o Doppler ligado o motor de audio
	# mede a velocidade do no entre quadros, e o salto do nascimento entra como
	# velocidade absurda (ver `tests/bancada_audio.gd`).
	await process_frame
	await process_frame
	m.call(&"atualizar", lenta, 0.0, 0.0, true, false, 0.0, QUADRO)
	await process_frame

	var carater: float = m.call(&"carater")
	var refs: PackedFloat32Array = m.call(&"referencias")
	var banco: Array = m.call(&"tocadores_do_banco")
	var rms := _rms_do_banco(banco)
	print("--- %s: %d pontos (%s rpm), caracter %.3f, lenta %.0f, corte %.0f"
		% [arq, refs.size(), ", ".join(Array(refs).map(func(r: float) -> String: return str(int(r)))),
			carater, lenta, corte])

	# O laco de cada amostra.
	var lacos_ok := true
	var detalhe := ""
	for p: AudioStreamPlayer3D in banco:
		var w := p.stream as AudioStreamWAV
		if w == null:
			lacos_ok = false
			detalhe = "%s sem stream" % p.name
			break
		var n := roundi(w.get_length() * float(w.mix_rate))
		if w.format != AudioStreamWAV.FORMAT_16_BITS or w.mix_rate != 32000 \
				or w.loop_mode != AudioStreamWAV.LOOP_FORWARD or w.loop_end != n - 1:
			lacos_ok = false
			detalhe = "%s: formato %d, %d Hz, laco %d..%d de %d" % [p.name, w.format,
				w.mix_rate, w.loop_begin, w.loop_end, n]
			break
	_conta("%s laco" % arq, lacos_ok, detalhe if not lacos_ok
		else "%d amostras PCM 16 bits a 32 kHz, laco ate a amostra de guarda" % banco.size())

	var d0: Dictionary = m.call(&"diagnostico")
	_conta("%s vozes" % arq, int(d0["vozes"]) == banco.size() + 4,
		"%d tocadores em laco rodando (%d do banco + pneu, cantada, vento, cambio) e 1 de eventos"
			% [int(d0["vozes"]), banco.size()])

	var cargas: Array[float] = [1.0, 0.0]
	for carga: float in cargas:
		var r := await _varrer(m, refs, rms, carater, lenta, corte, carga)
		var nome := "%s %s" % [arq, "carga" if carga > 0.5 else "retencao"]
		_conta(nome + " afinacao", r["afin_erro"] < 1e-4 and r["passo_erro"] < 1e-5,
			"erro relativo maximo %s contra giro*caracter/ref; produto afinacao*ref igual em todos (%s)"
				% [String.num_scientific(r["afin_erro"]), String.num_scientific(r["passo_erro"])])
		_conta(nome + " estica", r["estica"] <= r["estica_max"] + 1e-3,
			"camada audivel mais esticada %.3fx (limite da grade %.3fx), fora a lenta abaixo do 1o ponto"
				% [r["estica"], r["estica_max"]])
		_conta(nome + " potencia", absf(r["pot_min"]) < 0.05 and absf(r["pot_max"]) < 0.05,
			"soma em potencia de %+.3f a %+.3f dB" % [r["pot_min"], r["pot_max"]])
		_conta(nome + " linear", r["lin_min"] >= -0.01 and r["lin_max"] <= 3.02,
			"soma linear de %+.2f a %+.2f dB" % [r["lin_min"], r["lin_max"]])
		_conta(nome + " nivel", r["nivel_salto"] < 0.5,
			"nivel previsto de %.1f a %.1f dB RMS, maior salto entre quadros %.3f dB"
				% [r["nivel_min"], r["nivel_max"], r["nivel_salto"]])
		_conta(nome + " NaN", r["nan"] == 0, "%d valores nao-finitos" % r["nan"])
		print("      custo de atualizar: media %.1f us, maximo %.1f us por quadro (%d quadros)"
			% [r["custo_medio"], r["custo_max"], r["quadros"]])
		if _com_saida:
			print("      saida: RMS de %.1f a %.1f dBFS, maior salto em 100 ms %.2f dB (%s)"
				% [r["saida_min"], r["saida_max"], r["saida_salto"], r["saida_nota"]])

	if _com_saida:
		await _medir_altura(m, arq, refs, carater)

	# Carga variando com giro parado: a soma em potencia tambem fica em 0 dB.
	var pot := []
	for k in 61:
		m.call(&"atualizar", 3000.0, float(k) / 60.0, 15.0, true, false, 0.0, QUADRO)
		var d: Dictionary = m.call(&"diagnostico")
		pot.append(linear_to_db(float(d["soma_potencia"])))
	_conta("%s cruzamento de carga" % arq, absf(pot.min()) < 0.05 and absf(pot.max()) < 0.05,
		"a 3000 rpm, carga de 0 a 1: soma em potencia de %+.3f a %+.3f dB" % [pot.min(), pot.max()])

	# O assobio do cambio anda com a marcha, e nao com o giro so: mesmo giro, mais
	# velocidade (marcha mais longa) = assobio mais agudo.
	m.call(&"atualizar", 3000.0, 0.5, 8.0, true, false, 0.0, 1.0)
	var curta: float = (m.call(&"diagnostico") as Dictionary)["cambio_afinacao"]
	m.call(&"atualizar", 3000.0, 0.5, 30.0, true, false, 0.0, 1.0)
	var longa: float = (m.call(&"diagnostico") as Dictionary)["cambio_afinacao"]
	_conta("%s cambio" % arq, longa > curta * 1.5,
		"3000 rpm a 8 m/s assobia em %.0f Hz; a 30 m/s (marcha longa), %.0f Hz"
			% [curta * 1000.0, longa * 1000.0])

	m.call(&"desligar")
	var dd: Dictionary = m.call(&"diagnostico")
	_conta("%s desligar" % arq, int(dd["vozes"]) == 0, "%d vozes depois de desligar" % int(dd["vozes"]))
	m.queue_free()
	await process_frame


## RMS de cada arquivo do banco, lido do proprio stream (PCM 16 bits).
static func _rms_do_banco(banco: Array) -> PackedFloat32Array:
	var saida := PackedFloat32Array()
	for p: AudioStreamPlayer3D in banco:
		var w := p.stream as AudioStreamWAV
		if w == null or w.format != AudioStreamWAV.FORMAT_16_BITS:
			saida.append(0.0)
			continue
		var dados := w.data
		var n := dados.size() / 2
		var soma := 0.0
		for i in range(0, n, 3):
			var v := float(dados.decode_s16(i * 2)) / 32768.0
			soma += v * v
		saida.append(sqrt(soma / float(maxi(1, (n + 2) / 3))))
	return saida


## Da lenta ao corte e de volta, numa carga, lendo tudo a cada quadro.
func _varrer(m: Node3D, refs: PackedFloat32Array, rms: PackedFloat32Array, carater: float,
		lenta: float, corte: float, carga: float) -> Dictionary:
	var r := {
		"afin_erro": 0.0, "passo_erro": 0.0, "estica": 1.0, "estica_max": 1.0,
		"pot_min": 99.0, "pot_max": -99.0, "lin_min": 99.0, "lin_max": -99.0,
		"nivel_min": 99.0, "nivel_max": -99.0, "nivel_salto": 0.0, "nan": 0,
		"custo_medio": 0.0, "custo_max": 0.0, "quadros": 0,
		"saida_min": 99.0, "saida_max": -99.0, "saida_salto": 0.0, "saida_nota": "",
	}
	for k in range(1, refs.size()):
		r["estica_max"] = maxf(r["estica_max"], refs[k] / refs[k - 1])
	var banco: Array = m.call(&"tocadores_do_banco")
	var nivel_antes := NAN
	var custo := 0.0
	# Assenta a carga suavizada antes de medir, para a varredura ser a carga pedida.
	for _i in 60:
		m.call(&"atualizar", lenta, carga, 10.0, true, false, 0.0, QUADRO)
	if _com_saida:
		_captura.clear_buffer()
	var saida := PackedFloat32Array()
	var quadros := PERNA * 2
	var inicio := Time.get_ticks_usec()
	for q in quadros:
		if _com_saida:
			# Tempo real: em `--script` os quadros correm soltos (centenas por
			# segundo), e a varredura de 6 s passava em 1,4 s de audio.
			while Time.get_ticks_usec() < inicio + int(float(q) * QUADRO * 1e6):
				await process_frame
		var f := float(q) / float(PERNA)
		var giro := lenta * pow(corte / lenta, f if f <= 1.0 else 2.0 - f)
		var t0 := Time.get_ticks_usec()
		m.call(&"atualizar", giro, carga, 10.0 + giro / 300.0, true, false, 0.0, QUADRO)
		var dt := float(Time.get_ticks_usec() - t0)
		custo += dt
		r["custo_max"] = maxf(r["custo_max"], dt)
		var d: Dictionary = m.call(&"diagnostico")
		var efetivo := giro * carater
		var produto0 := 0.0
		var pot := 0.0
		var nivel := 0.0
		for i in banco.size():
			var p: AudioStreamPlayer3D = banco[i]
			var ref := refs[i / 2]
			if not (is_finite(p.pitch_scale) and is_finite(p.volume_db)):
				r["nan"] += 1
				continue
			r["afin_erro"] = maxf(r["afin_erro"], absf(p.pitch_scale - efetivo / ref) / (efetivo / ref))
			var produto := p.pitch_scale * ref
			if i == 0:
				produto0 = produto
			r["passo_erro"] = maxf(r["passo_erro"], absf(produto / produto0 - 1.0))
			if p.volume_db > -59.0:
				var g := db_to_linear(p.volume_db - MotorSomDb.base(m))
				pot += g * g
				nivel += g * g * rms[i] * rms[i]
				var e := p.pitch_scale / carater
				var dentro := giro >= refs[0] and giro <= refs[refs.size() - 1]
				if dentro:
					r["estica"] = maxf(r["estica"], maxf(e, 1.0 / e))
		var pot_db := 10.0 * log(maxf(pot, 1e-12)) / log(10.0)
		r["pot_min"] = minf(r["pot_min"], pot_db)
		r["pot_max"] = maxf(r["pot_max"], pot_db)
		var lin_db := linear_to_db(maxf(float(d["soma_linear"]), 1e-6))
		r["lin_min"] = minf(r["lin_min"], lin_db)
		r["lin_max"] = maxf(r["lin_max"], lin_db)
		var nivel_db := 10.0 * log(maxf(nivel, 1e-12)) / log(10.0)
		r["nivel_min"] = minf(r["nivel_min"], nivel_db)
		r["nivel_max"] = maxf(r["nivel_max"], nivel_db)
		if not is_nan(nivel_antes):
			r["nivel_salto"] = maxf(r["nivel_salto"], absf(nivel_db - nivel_antes))
		nivel_antes = nivel_db
		if _com_saida:
			_recolher(saida)
	r["custo_medio"] = custo / float(quadros)
	r["quadros"] = quadros
	if _com_saida:
		_medir_saida(saida, r)
	return r


func _recolher(saida: PackedFloat32Array) -> void:
	var n := _captura.get_frames_available()
	if n <= 0:
		return
	for fr: Vector2 in _captura.get_buffer(n):
		saida.append((fr.x + fr.y) * 0.5)


## RMS da saida em janelas de 100 ms; o maior salto entre janelas vizinhas,
## suavizado em tres janelas (a propria marcha lenta pulsa mais devagar que
## 100 ms e nao e degrau de mistura).
func _medir_saida(saida: PackedFloat32Array, r: Dictionary) -> void:
	var taxa := AudioServer.get_mix_rate()
	var jan := int(taxa * 0.1)
	var niveis: Array[float] = []
	var i := 0
	while i + jan <= saida.size():
		var soma := 0.0
		for k in range(i, i + jan):
			soma += saida[k] * saida[k]
		niveis.append(10.0 * log(maxf(soma / float(jan), 1e-12)) / log(10.0))
		i += jan
	if niveis.size() < 5:
		r["saida_nota"] = "so %d janelas capturadas" % niveis.size()
		return
	var suave: Array[float] = []
	for k in range(1, niveis.size() - 1):
		suave.append((niveis[k - 1] + niveis[k] + niveis[k + 1]) / 3.0)
	for k in suave.size():
		r["saida_min"] = minf(r["saida_min"], suave[k])
		r["saida_max"] = maxf(r["saida_max"], suave[k])
		if k > 0:
			r["saida_salto"] = maxf(r["saida_salto"], absf(suave[k] - suave[k - 1]))
	r["saida_nota"] = "%d janelas" % niveis.size()


## A altura na SAIDA, no meio de um cruzamento e em cima de um ponto da grade.
##
## E a prova do passo comum. No meio geometrico entre dois pontos as duas
## amostras tocam com o mesmo peso; se os pulsos delas estivessem fora de passo,
## a saida teria o dobro de pulsos (altura dobrada) ou repetiria mal. Em cima de
## um ponto so uma amostra toca, e a repeticao dela e a regua.
func _medir_altura(m: Node3D, arq: StringName, refs: PackedFloat32Array, carater: float) -> void:
	var k := refs.size() / 2
	var meio := sqrt(refs[k - 1] * refs[k])
	var cilindros := 3.0 if arq == &"i3" else 4.0
	var medidas := {}
	for giro: float in [meio, refs[k]]:
		for _i in 30:
			m.call(&"atualizar", giro, 1.0, 10.0, true, false, 0.0, QUADRO)
			await process_frame
		_captura.clear_buffer()
		var saida := PackedFloat32Array()
		var ate := Time.get_ticks_usec() + 700000
		while Time.get_ticks_usec() < ate:
			m.call(&"atualizar", giro, 1.0, 10.0, true, false, 0.0, QUADRO)
			await process_frame
			_recolher(saida)
		var f_exp := giro * carater / 60.0 * cilindros / 2.0
		medidas[giro] = _yin(saida, AudioServer.get_mix_rate(), f_exp)
		medidas[giro].append(f_exp)
	var cruz: Array = medidas[meio]
	var ponto: Array = medidas[refs[k]]
	var erro := absf(float(cruz[0]) / float(cruz[2]) - 1.0)
	_conta("%s passo comum" % arq, erro < 0.03 and float(cruz[1]) < maxf(0.35, float(ponto[1]) * 2.0),
		"no meio de %d e %d rpm (%.0f): %.1f Hz medidos, %.1f da explosao, repeticao %.2f; em cima de %d rpm: %.1f Hz, repeticao %.2f (0 = perfeita)"
			% [int(refs[k - 1]), int(refs[k]), meio, cruz[0], cruz[2], cruz[1], int(refs[k]), ponto[0], ponto[1]])


## YIN no sinal decimado por 8: (Hz, repeticao) na janela de 0,5 a 1,5 vez o
## intervalo de explosao esperado. Repeticao e a diferenca normalizada
## acumulada no minimo: 0 e um sinal que se repete perfeito.
static func _yin(x: PackedFloat32Array, taxa: float, f_esperada: float) -> Array:
	var dec := PackedFloat32Array()
	var k := 0
	while k + 8 <= x.size():
		var soma := 0.0
		for j in 8:
			soma += x[k + j]
		dec.append(soma / 8.0)
		k += 8
	var fs := taxa / 8.0
	var t0 := fs / f_esperada
	var t_max := int(t0 * 1.5) + 2
	var janela := dec.size() - t_max - 1
	if janela < 200:
		return [0.0, 1.0]
	var d := PackedFloat32Array()
	d.resize(t_max + 1)
	for tau in range(1, t_max + 1):
		var soma := 0.0
		for j in janela:
			var e := dec[j] - dec[j + tau]
			soma += e * e
		d[tau] = soma
	var cmnd := PackedFloat32Array()
	cmnd.resize(t_max + 1)
	cmnd[0] = 1.0
	var acum := 0.0
	for tau in range(1, t_max + 1):
		acum += d[tau]
		cmnd[tau] = d[tau] * float(tau) / maxf(acum, 1e-20)
	var melhor := int(t0 * 0.5)
	for tau in range(int(t0 * 0.5), mini(t_max, int(t0 * 1.5)) + 1):
		if cmnd[tau] < cmnd[melhor]:
			melhor = tau
	var fino := float(melhor)
	if melhor > 1 and melhor < t_max:
		var y0 := cmnd[melhor - 1]
		var y1 := cmnd[melhor]
		var y2 := cmnd[melhor + 1]
		var den := y0 - 2.0 * y1 + y2
		if absf(den) > 1e-12:
			fino += 0.5 * (y0 - y2) / den
	return [fs / fino, cmnd[melhor]]


## O carro de rua: uma voz, afinada por giro * caracter / ponto da rua.
func _rua() -> void:
	print("--- carro de rua")
	var m := _motor(&"i4", false, 6500.0)
	await process_frame
	await process_frame
	var carater: float = m.call(&"carater")
	var erro := 0.0
	var custo := 0.0
	for q in 120:
		var giro := lerpf(880.0, 2150.0, float(q) / 119.0)
		var t0 := Time.get_ticks_usec()
		m.call(&"atualizar", giro, 0.4, 8.0, true, false, 0.0, QUADRO)
		custo += float(Time.get_ticks_usec() - t0)
		var rua := m.get_node(^"Rua") as AudioStreamPlayer3D
		erro = maxf(erro, absf(rua.pitch_scale - giro * carater / 1500.0))
	var d: Dictionary = m.call(&"diagnostico")
	_conta("rua vozes", int(d["vozes"]) == 1 and int(d["tocando"]) == 1,
		"%d voz em laco, %d camada audivel" % [int(d["vozes"]), int(d["tocando"])])
	_conta("rua afinacao", erro < 1e-4, "erro maximo %s contra giro*caracter/1500"
		% String.num_scientific(erro))
	var rua := m.get_node(^"Rua") as AudioStreamPlayer3D
	var w := rua.stream as AudioStreamWAV
	_conta("rua amostra", w != null and w.loop_end == roundi(w.get_length() * w.mix_rate) - 1,
		"motor_i4_1500_on em laco ate a guarda")
	print("      custo de atualizar: media %.1f us por quadro" % (custo / 120.0))
	m.queue_free()
	await process_frame


## Trocar de arquitetura com o motor rodando refaz o banco e continua tocando.
func _trocar_com_motor_rodando() -> void:
	print("--- troca de arquitetura com o motor rodando")
	var m := _motor(&"i4", true, 6500.0)
	await process_frame
	await process_frame
	m.call(&"atualizar", 2000.0, 0.5, 10.0, true, false, 0.0, QUADRO)
	var antes: int = (m.call(&"diagnostico") as Dictionary)["vozes"]
	m.call(&"definir_arquitetura", &"boxer")
	m.call(&"atualizar", 2000.0, 0.5, 10.0, true, false, 0.0, QUADRO)
	var d: Dictionary = m.call(&"diagnostico")
	var refs: PackedFloat32Array = m.call(&"referencias")
	_conta("troca", String(d["arquitetura"]) == "boxer" and int(d["vozes"]) == refs.size() * 2 + 4
			and int(d["tocando"]) >= 3,
		"i4 com %d vozes -> boxer com %d vozes, %d camadas audiveis" % [antes, int(d["vozes"]),
			int(d["tocando"])])
	m.queue_free()
	await process_frame


## O volume que o `MotorSom` soma a todo tocador do banco antes do peso: o nivel
## da mistura e o do escapamento deste carro. Lido do proprio no, para a bancada
## nao repetir a constante.
class MotorSomDb:
	static func base(m: Node3D) -> float:
		var constantes := (m.get_script() as Script).get_script_constant_map()
		return float(constantes["DB_MOTOR"]) + float(m.get(&"_volume"))
