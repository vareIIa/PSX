## Bancada da agua no vidro: a fisica da corredora, sem desenhar nada.
##
##     godot --headless --path game --script res://tests/bancada_agua_vidro.gd
##
## Por que uma bancada, e nao uma captura
## --------------------------------------
## O criterio C8 pede coisas que a cutscene nao consegue montar: freada de 0,6 g,
## 60 km/h constantes numa janela LATERAL, e a mesma gota comparada com e sem
## vento. Na estrada, tudo isso acontece ao mesmo tempo e nenhuma das perguntas
## tem resposta limpa — e a memoria do projeto "bancada offline para o que a rua
## nao deixa medir" ja custou uma vez: a quinta marcha pede 500 m de reta e o
## quarteirao tem 32.
##
## Aqui o vidro e o do Marea de verdade (`VidroCabine.referenciais`), e nao um
## plano inventado: a inclinacao do para-brisa e a que muda o sinal do vento, e
## um plano de mentira daria um teste que passa com a fisica errada.
##
## Cada caso e uma COMPARACAO, e nao um valor absoluto: "a gota termina mais
## alta com vento do que sem" vale mesmo se eu mexer nos coeficientes; "a gota
## termina em v = 0,21" nao vale nada no dia seguinte.
extends SceneTree

const DT := 1.0 / 60.0
## 60 km/h em m/s, e uma freada de 0,6 g.
const V60 := 16.67
const FREADA := 0.6 * 9.81
## O rastro tem de deitar pelo menos isto, em graus, a 60 km/h na lateral.
const MIN_DEITADA := 35.0

var _linhas: Array[String] = []
var _falhas := 0
var _casos := 0


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var medidas := Carroceria.montar(Carroceria.Modelo.MAREA, CarroCena.TINTA,
		CarroCena.SEMENTE)
	var paineis := VidroCabine.referenciais(medidas.get("aberturas", []))
	if paineis.is_empty():
		print("=== FALHOU: o Marea nao devolveu vidro nenhum ===")
		quit(1)
		return
	var i_frente := _achar(paineis, &"parabrisa")
	var i_lado := _achar(paineis, &"porta_frente")
	if i_frente < 0 or i_lado < 0:
		print("=== FALHOU: falta para-brisa (%d) ou janela lateral (%d) ==="
			% [i_frente, i_lado])
		quit(1)
		return
	var frente: Dictionary = paineis[i_frente]
	var lado: Dictionary = paineis[i_lado]
	print("para-brisa %.2f x %.2f m, normal %s" % [(frente["tam"] as Vector2).x,
		(frente["tam"] as Vector2).y, frente["normal"]])
	print("janela lateral %.2f x %.2f m, normal %s" % [(lado["tam"] as Vector2).x,
		(lado["tam"] as Vector2).y, lado["normal"]])

	_parada_desce(paineis, i_frente)
	_vento_sobe_e_abre(paineis, i_frente)
	_lateral_deita(paineis, i_lado)
	_freada_empurra(paineis, i_frente)
	_massa_nao_nasce(paineis, i_frente)
	_sem_nan(paineis, i_frente, i_lado)

	print("\n=== bancada da agua ===")
	for l in _linhas:
		print(l)
	if _casos == 0:
		print("\n=== FALHOU: nenhum caso rodou ===")
		quit(1)
		return
	if _falhas > 0:
		print("\n=== FALHOU: %d de %d casos ===" % [_falhas, _casos])
		quit(1)
		return
	print("\n=== C8 OK: %d casos ===" % _casos)
	quit(0)


## Parada, a gota desce e nao anda para o lado.
func _parada_desce(paineis: Array, i: int) -> void:
	var tam: Vector2 = paineis[i]["tam"]
	var p0 := Vector2(tam.x * 0.5, tam.y * 0.15)
	var fim := _correr(paineis, i, p0, 1.6, Vector3.ZERO, Vector3.ZERO, 1.0)
	if fim.is_empty():
		_reprovar("parada desce", "a gota sumiu antes do fim")
		return
	var d: Vector2 = fim["p"] - p0
	_checar("parada desce", d.y > 0.02,
		"desceu %.3f m e andou %.3f m de lado" % [d.y, absf(d.x)])


## A 60 km/h o ar vence o peso: a gota SOBE o para-brisa e abre para as bordas.
func _vento_sobe_e_abre(paineis: Array, i: int) -> void:
	var tam: Vector2 = paineis[i]["tam"]
	var vel := Vector3(0.0, 0.0, -V60)
	for s: float in [-1.0, 1.0]:
		var p0 := Vector2(tam.x * (0.5 + s * 0.18), tam.y * 0.55)
		var parada := _correr(paineis, i, p0, 1.6, Vector3.ZERO, Vector3.ZERO, 0.6)
		var soprada := _correr(paineis, i, p0, 1.6, vel, Vector3.ZERO, 0.6)
		if parada.is_empty() or soprada.is_empty():
			_reprovar("vento sobe (lado %+.0f)" % s, "a gota sumiu antes do fim")
			continue
		var pv: Vector2 = parada["p"]
		var sv: Vector2 = soprada["p"]
		var meio := tam.x * 0.5
		_checar("vento sobe (lado %+.0f)" % s, sv.y < pv.y - 0.02,
			"com vento v=%.3f, sem vento v=%.3f" % [sv.y, pv.y])
		_checar("vento abre (lado %+.0f)" % s,
			absf(sv.x - meio) > absf(pv.x - meio) + 0.005,
			"com vento |u-meio|=%.3f, sem vento %.3f"
				% [absf(sv.x - meio), absf(pv.x - meio)])


## Na janela lateral o rastro deita para tras com a velocidade.
func _lateral_deita(paineis: Array, i: int) -> void:
	var tam: Vector2 = paineis[i]["tam"]
	var p0 := Vector2(tam.x * 0.3, tam.y * 0.2)
	var parada := _correr(paineis, i, p0, 1.6, Vector3.ZERO, Vector3.ZERO, 0.45)
	var soprada := _correr(paineis, i, p0, 1.6, Vector3(0.0, 0.0, -V60),
		Vector3.ZERO, 0.45)
	if parada.is_empty() or soprada.is_empty():
		_reprovar("lateral deita", "a gota sumiu antes do fim")
		return
	# O angulo do rastro em relacao a vertical do vidro. `u` cresce para a
	# TRASEIRA na janela lateral (ver `VidroCabine`), entao deitar e u crescer.
	var a_parada := _deitada((parada["p"] as Vector2) - p0)
	var a_soprada := _deitada((soprada["p"] as Vector2) - p0)
	_checar("lateral em pe parada", a_parada < 8.0,
		"rastro a %.1f graus da vertical" % a_parada)
	_checar("lateral deita a 60", a_soprada >= MIN_DEITADA,
		"rastro a %.1f graus (limite %.0f)" % [a_soprada, MIN_DEITADA])


## Freada de 0,6 g empurra a agua para a base do para-brisa.
func _freada_empurra(paineis: Array, i: int) -> void:
	var tam: Vector2 = paineis[i]["tam"]
	var p0 := Vector2(tam.x * 0.5, tam.y * 0.45)
	var vel := Vector3(0.0, 0.0, -V60)
	# Freando, o carro anda para -Z e acelera para +Z. A pseudo-forca na agua e
	# o oposto: para a FRENTE, que no para-brisa inclinado e morro abaixo.
	var solto := _correr(paineis, i, p0, 1.6, vel, Vector3.ZERO, 0.6)
	var freado := _correr(paineis, i, p0, 1.6, vel, Vector3(0.0, 0.0, FREADA), 0.6)
	if solto.is_empty() or freado.is_empty():
		_reprovar("freada empurra", "a gota sumiu antes do fim")
		return
	_checar("freada empurra para a base",
		(freado["p"] as Vector2).y > (solto["p"] as Vector2).y + 0.01,
		"freando v=%.3f, solto v=%.3f" % [(freado["p"] as Vector2).y,
			(solto["p"] as Vector2).y])


## Sem agua em volta, massa nao nasce: parada ela fica, andando ela so perde.
func _massa_nao_nasce(paineis: Array, i: int) -> void:
	var tam: Vector2 = paineis[i]["tam"]
	var p0 := Vector2(tam.x * 0.5, tam.y * 0.2)
	var quieta := _correr(paineis, i, p0, 0.30, Vector3.ZERO, Vector3.ZERO, 2.0,
		0.0)
	if quieta.is_empty():
		_reprovar("massa parada", "a gota sumiu antes do fim")
	else:
		_checar("massa parada nao cresce sem agua",
			absf(float(quieta["massa"]) - 0.30) < 0.001,
			"massa %.4f (comecou em 0,3000)" % float(quieta["massa"]))
	var corrida := _correr(paineis, i, p0, 1.6, Vector3.ZERO, Vector3.ZERO, 0.8,
		0.0)
	if corrida.is_empty():
		_reprovar("massa andando", "a gota sumiu antes do fim")
		return
	_checar("massa andando so diminui sem agua", float(corrida["massa"]) < 1.6,
		"massa %.4f (comecou em 1,6000)" % float(corrida["massa"]))


## Vinte segundos de regime bruto, com o limpador no meio: nada vira NaN.
func _sem_nan(paineis: Array, ia: int, ib: int) -> void:
	var cor := AguaCorredoras.new()
	root.add_child(cor)
	var feito := AguaVidro.empacotar(paineis, AguaVidro.TAM_MODERNO)
	cor.montar(paineis, feito["rects"] if not feito.is_empty()
		else ([] as Array[Rect2]))
	var cob := PackedFloat32Array()
	cob.resize(paineis.size())
	cob.fill(1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var limpador := Limpador.new()
	root.add_child(limpador)
	limpador.configurar(paineis[ia], ia, null)
	var ruim := 0
	for q in int(20.0 / DT):
		var vel := Vector3(rng.randf_range(-4.0, 4.0), 0.0,
			rng.randf_range(-30.0, 2.0))
		var acel := Vector3(rng.randf_range(-8.0, 8.0), 0.0,
			rng.randf_range(-9.0, 9.0))
		limpador.atualizar(1.0, 1.0, DT)
		cor.passo(1.0, cob, vel, acel, limpador.setor(), DT)
		for g: Dictionary in cor.estado():
			var p: Vector2 = g["p"]
			var v: Vector2 = g["vel"]
			if not (is_finite(p.x) and is_finite(p.y) and is_finite(v.x)
					and is_finite(v.y) and is_finite(float(g["massa"]))):
				ruim += 1
	_checar("nenhum NaN em 20 s de regime bruto", ruim == 0,
		"%d gotas invalidas, %d vivas no fim" % [ruim, cor.quantas()])
	# E o teto de gotas tem de valer, senao o vetor de trilhas estoura em jogo.
	_checar("teto de corredoras respeitado",
		cor.quantas() <= AguaCorredoras.TOTAL,
		"%d gotas (teto %d)" % [cor.quantas(), AguaCorredoras.TOTAL])
	cor.queue_free()
	limpador.queue_free()


## Roda UMA gota e devolve o estado final dela, ou vazio se ela morreu.
func _correr(paineis: Array, i: int, p0: Vector2, massa: float,
		vel_local: Vector3, acel_local: Vector3, segundos: float,
		cobertura: float = 0.45) -> Dictionary:
	var cor := AguaCorredoras.new()
	root.add_child(cor)
	var feito := AguaVidro.empacotar(paineis, AguaVidro.TAM_MODERNO)
	cor.montar(paineis, feito["rects"] if not feito.is_empty()
		else ([] as Array[Rect2]))
	var cob := PackedFloat32Array()
	cob.resize(paineis.size())
	cob.fill(cobertura)
	cor.semear(i, p0, massa)
	# Chuva zero: aqui interessa ESTA gota, e nao as que nasceriam por cima dela.
	for q in int(segundos / DT):
		cor.passo(0.0, cob, vel_local, acel_local, {}, DT)
	var fim: Dictionary = {}
	for g: Dictionary in cor.estado():
		fim = g.duplicate()
	cor.queue_free()
	return fim


## Angulo do rastro em relacao a vertical do vidro, em graus.
func _deitada(d: Vector2) -> float:
	if d.length_squared() < 1e-8:
		return 0.0
	return rad_to_deg(absf(atan2(d.x, maxf(d.y, 1e-5))))


func _achar(paineis: Array, tipo: StringName) -> int:
	for i in paineis.size():
		if paineis[i]["tipo"] == tipo:
			return i
	return -1


func _checar(nome: String, passou: bool, detalhe: String) -> void:
	_casos += 1
	if not passou:
		_falhas += 1
	_linhas.append("  %-38s %s   %s" % [nome, "OK    " if passou else "FALHOU",
		detalhe])


func _reprovar(nome: String, detalhe: String) -> void:
	_casos += 1
	_falhas += 1
	_linhas.append("  %-38s FALHOU   %s" % [nome, detalhe])
