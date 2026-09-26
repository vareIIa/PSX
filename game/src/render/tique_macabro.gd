## Os tiques dos encapuzados: o pescoco que quebra, os bracos que torcem.
##
## Por que existe
## --------------
## Um encapuzado parado na estrada, olhando o carro, e so um homem de preto. O
## que assusta e o corpo que NAO se mexe como gente: a cabeca que estala de
## lado ate a orelha deitar no ombro e fica la, tremendo; que gira mais do que
## um pescoco gira; o braco que sobe duro e dobra o cotovelo para tras. Tudo de
## uma vez, rapido, em estalos — e entre um estalo e outro, um tremor fino que
## nunca para.
##
## Como funciona
## -------------
## O `Corpo` escreve a pose de sempre (andando, parado, curvado na janela) e
## este tique multiplica por cima, no espaco de cada osso: cabeca, os dois
## bracos, os dois antebracos e o tronco. Por isso quem usa chama `passo` DEPOIS
## de `Corpo.animar`, e forca o corpo a reescrever a pose inteira todo quadro
## (`dominado = false` derruba a assinatura): sem isso o cache da pose devolve o
## tique do quadro anterior como "base", e o angulo soma sem fim.
##
## Cada parte tem a sua fila: sorteia uma pose, estala ate ela em poucos quadros
## (com um repique que passa do ponto e volta — e o que le como "estalo", e nao
## como giro), segura, e sorteia outra. Um em cada tres estalos gagueja: para no
## meio por dois quadros e so depois termina. Por cima de tudo, o tremor e os
## micro-tiques, chutes pequenos que morrem em cinquenta milissegundos.
##
## Angulos em radianos, na convencao do `Corpo`: no osso, x positivo leva a
## cabeca (e o tronco) para CIMA e para TRAS, e o braco pendurado para a FRENTE;
## y e o giro; z tomba de lado (no braco esquerdo, z negativo abre para fora).
class_name TiqueMacabro
extends RefCounted

enum Modo {
	## Os de fundo: nada. Estalando todos, o tempo todo, era ruido e nao medo; o
	## corpo deles e do `AndarMacabro` (o andar, o olhar, e um estalo de osso so
	## nos eventos dele). O tique fica no meta `tique` de todo encapuzado, em
	## FUNDO, porque quem leva um deles para a janela troca o modo para JANELA e
	## dali em diante este tique volta a valer inteiro nele.
	FUNDO,
	## O padre na estrada: estalos maiores e mais espacados.
	PADRE,
	## O padre na janela: a cara nao pode sair do vidro, e a mao esta nele.
	JANELA,
}

## As poses da cabeca: [peso, x, y, z], com y e z espelhados ao acaso.
##   quebrada   a orelha no ombro, o pescoco partido
##   caida      o queixo no peito, mole
##   jogada     a cara para o ceu
##   coruja     girada alem do que um pescoco gira
##   invertida  quase de ponta-cabeca
##   encarando  reta, parada, olhando
const CABECA_POSES := [
	[0.28, 0.10, 0.18, 1.30],
	[0.13, -1.05, 0.25, 0.30],
	[0.10, 1.10, 0.15, 0.35],
	[0.17, 0.05, 2.10, 0.25],
	[0.07, 0.25, 0.35, 2.45],
	[0.25, 0.0, 0.0, 0.0],
]
## As poses de um braco: [peso, braco x, y, z, antebraco x, y]. Escritas para o
## braco DIREITO; o esquerdo espelha y e z.
##   solto          pendurado, quase parado
##   quebrado       jogado para tras, o cotovelo dobrado ao contrario
##   estendido      duro para a frente, para o carro, o cotovelo passando do reto
##   aranha         aberto de lado, o antebraco dobrado e torcido
##   torcido        girado em volta de si mesmo
##   deslocado      caido e torto, como fora do ombro
##   acima          erguido acima da cabeca, o cotovelo quebrado para tras
const BRACO_POSES := [
	[0.20, 0.05, 0.0, 0.0, 0.10, 0.0],
	[0.16, -0.55, 1.20, 0.15, -1.05, 0.0],
	[0.18, 1.45, 0.0, 0.10, -0.40, 0.60],
	[0.14, 0.30, 0.0, 1.25, 1.90, 2.20],
	[0.12, 0.20, 2.60, 0.30, -0.60, 0.0],
	[0.10, -0.15, 0.40, -0.25, 0.0, 0.0],
	[0.10, 2.60, 0.0, 0.30, -0.85, 0.0],
]
## O tronco: [peso, x, y, z]. Quase sempre reto; de vez em quando um tranco.
const TRONCO_POSES := [
	[0.55, 0.0, 0.0, 0.0],
	[0.18, -0.28, 0.0, 0.0],
	[0.12, 0.18, 0.0, 0.0],
	[0.15, 0.0, 0.38, 0.16],
]
## Quanto dura o estalo (s) e quanto a parte segura antes do proximo.
const ESTALO := Vector2(0.035, 0.075)
const SEGURA_CABECA := Vector2(0.12, 0.95)
const SEGURA_BRACO := Vector2(0.08, 0.75)
const SEGURA_TRONCO := Vector2(0.35, 1.6)
## A fracao dos estalos que gagueja no meio.
const GAGUEJA := 0.33
## O tremor fino (rad) e a forca dos micro-tiques.
const TREMOR_CABECA := 0.035
const TREMOR_BRACO := 0.025
const MICRO := Vector2(0.06, 0.20)
const MICRO_A_CADA := Vector2(0.07, 0.35)
## A partir de que angulo (rad) um estalo faz barulho de osso.
const ESTALO_AUDIVEL := 0.45

var modo: Modo = Modo.FUNDO
## 0 para, 1 inteiro. Tudo que o tique soma e multiplicado por isto.
var intensidade: float = 1.0

var _c: Corpo
var _rng := RandomNumberGenerator.new()
var _t: float = 0.0
var _fase: float = 0.0
## Uma parte: pose de onde saiu, para onde vai, o tempo do estalo e da espera,
## a fila de alvos (a gagueira) e o micro-tique que ainda esta morrendo.
var _partes: Dictionary = {}
var _cabeca_fixa := Vector3.INF
var _estalo_agora: float = 0.0


func _init(corpo: Corpo, semente: int, qual: Modo = Modo.FUNDO) -> void:
	_c = corpo
	_rng.seed = 90_001 + semente * 7919
	_fase = _rng.randf() * 100.0
	modo = qual
	for osso: int in [Corpo.Osso.CABECA, Corpo.Osso.BRACO_E, Corpo.Osso.BRACO_D,
			Corpo.Osso.TORSO]:
		_partes[osso] = {"de": [], "para": [], "t": 1.0, "dur": 0.05,
			"espera": _rng.randf_range(0.0, 0.6), "fila": [], "micro": Vector3.ZERO,
			"t_micro": _rng.randf_range(0.0, 0.3)}
	for osso: int in _partes:
		var zero := _zero(osso)
		_partes[osso]["de"] = zero
		_partes[osso]["para"] = zero


## Prende a cabeca numa pose (x, y, z) ate `soltar_cabeca`: o padre na janela
## deitando a cabeca devagar enquanto o sorriso abre. O tremor continua.
func fixar_cabeca(pose: Vector3, duracao: float) -> void:
	var p: Dictionary = _partes[Corpo.Osso.CABECA]
	p["de"] = _agora(Corpo.Osso.CABECA)
	p["para"] = [pose]
	p["t"] = 0.0
	p["dur"] = maxf(duracao, 0.01)
	p["fila"] = []
	p["lento"] = true
	_cabeca_fixa = pose


## Estala a cabeca agora para `pose`, sem esperar a vez dela: o golpe na
## estrada, o bote na janela. Devolve a forca do estalo, para o som.
func estalar_cabeca(pose: Vector3) -> float:
	var p: Dictionary = _partes[Corpo.Osso.CABECA]
	var de: Array = _agora(Corpo.Osso.CABECA)
	p["de"] = de
	p["para"] = [pose]
	p["t"] = 0.0
	p["dur"] = ESTALO.x
	p["fila"] = []
	p["lento"] = false
	p["espera"] = _rng.randf_range(0.45, 0.8)
	return clampf(((de[0] as Vector3) - pose).length() / 2.0, 0.4, 1.0)


func soltar_cabeca() -> void:
	_cabeca_fixa = Vector3.INF
	_partes[Corpo.Osso.CABECA]["lento"] = false
	_partes[Corpo.Osso.CABECA]["espera"] = 0.0


## Avanca e escreve o tique por cima da pose que o corpo acabou de escrever.
## Devolve a forca do maior estalo que comecou neste quadro (0 se nenhum), para
## quem chama tocar o osso.
func passo(delta: float) -> float:
	var esq := _c.esqueleto()
	if esq == null or intensidade <= 0.0 or modo == Modo.FUNDO:
		return 0.0
	_t += delta
	_estalo_agora = 0.0
	for osso: int in _partes:
		_avancar(osso, delta)
	var k := intensidade
	var tc := _tremor(TREMOR_CABECA, 0.0)
	_escrever(esq, Corpo.Osso.CABECA, (_agora(Corpo.Osso.CABECA)[0] as Vector3) * k + tc * k
		+ _partes[Corpo.Osso.CABECA]["micro"] * k)
	var tronco: Vector3 = _agora(Corpo.Osso.TORSO)[0]
	_escrever(esq, Corpo.Osso.TORSO, tronco * k + _partes[Corpo.Osso.TORSO]["micro"] * k * 0.4)
	for par: Array in [[Corpo.Osso.BRACO_E, Corpo.Osso.ANTEBRACO_E, 3.0],
			[Corpo.Osso.BRACO_D, Corpo.Osso.ANTEBRACO_D, 7.0]]:
		if modo == Modo.JANELA and par[0] == Corpo.Osso.BRACO_D:
			# A direita esta espalmada no vidro (`Corpo.agarrar`).
			continue
		var agora: Array = _agora(par[0])
		var tb := _tremor(TREMOR_BRACO, par[2])
		var micro: Vector3 = _partes[par[0]]["micro"]
		_escrever(esq, par[0], (agora[0] as Vector3) * k + tb * k + micro * k)
		_escrever(esq, par[1], (agora[1] as Vector3) * k + tb * k * 1.4)
	return _estalo_agora


func _avancar(osso: int, delta: float) -> void:
	var p: Dictionary = _partes[osso]
	# O micro-tique: um chute que morre depressa.
	p["micro"] = (p["micro"] as Vector3) * exp(-delta / 0.05)
	p["t_micro"] = float(p["t_micro"]) - delta
	if float(p["t_micro"]) <= 0.0:
		p["t_micro"] = _rng.randf_range(MICRO_A_CADA.x, MICRO_A_CADA.y)
		var forca := _rng.randf_range(MICRO.x, MICRO.y) * (1.0 if osso != Corpo.Osso.TORSO else 0.5)
		p["micro"] = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1),
			_rng.randf_range(-1, 1)).normalized() * forca
	if float(p["t"]) < 1.0:
		p["t"] = minf(1.0, float(p["t"]) + delta / float(p["dur"]))
		if float(p["t"]) >= 1.0 and not (p["fila"] as Array).is_empty():
			# A gagueira: parou no meio, e agora vai o resto.
			p["de"] = p["para"]
			p["para"] = (p["fila"] as Array).pop_front()
			p["t"] = 0.0
			p["dur"] = _rng.randf_range(ESTALO.x, ESTALO.y)
			p["espera_gago"] = _rng.randf_range(0.03, 0.08)
			p["t"] = -float(p["espera_gago"]) / float(p["dur"])
		return
	if bool(p.get("lento", false)):
		return
	p["espera"] = float(p["espera"]) - delta
	if float(p["espera"]) > 0.0:
		return
	# Novo estalo.
	var de: Array = _agora(osso)
	var para: Array = _sortear(osso)
	p["de"] = de
	p["t"] = 0.0
	p["dur"] = _rng.randf_range(ESTALO.x, ESTALO.y)
	p["fila"] = []
	if _rng.randf() < GAGUEJA:
		var meio: Array = []
		for i in para.size():
			meio.append((de[i] as Vector3).lerp(para[i], _rng.randf_range(0.3, 0.6)))
		p["para"] = meio
		p["fila"] = [para]
	else:
		p["para"] = para
	var segura := SEGURA_CABECA
	if osso == Corpo.Osso.TORSO:
		segura = SEGURA_TRONCO
	elif osso != Corpo.Osso.CABECA:
		segura = SEGURA_BRACO
	if modo == Modo.PADRE:
		segura *= 1.3
	# Espera curta e mais provavel que longa: o tique e nervoso.
	p["espera"] = lerpf(segura.x, segura.y, pow(_rng.randf(), 1.8))
	var giro := ((de[0] as Vector3) - (para[0] as Vector3)).length()
	if para.size() > 1:
		giro = maxf(giro, ((de[1] as Vector3) - (para[1] as Vector3)).length() * 0.8)
	if giro > ESTALO_AUDIVEL:
		var forca := clampf(giro / 2.0, 0.3, 1.0) * (1.0 if osso == Corpo.Osso.CABECA else 0.75)
		_estalo_agora = maxf(_estalo_agora, forca)


## A pose de agora de uma parte, com o repique do estalo: passa do ponto e volta.
func _agora(osso: int) -> Array:
	var p: Dictionary = _partes[osso]
	var de: Array = p["de"]
	var para: Array = p["para"]
	var t := clampf(float(p["t"]), 0.0, 1.0)
	var k: float
	if bool(p.get("lento", false)):
		k = smoothstep(0.0, 1.0, t)
	else:
		k = 1.0 - exp(-t * 6.0) * cos(t * 7.5)
		if t >= 1.0:
			k = 1.0
	var saida: Array = []
	for i in para.size():
		saida.append((de[mini(i, de.size() - 1)] as Vector3).lerp(para[i], k))
	return saida


func _sortear(osso: int) -> Array:
	match osso:
		Corpo.Osso.CABECA:
			if _cabeca_fixa != Vector3.INF:
				return [_cabeca_fixa]
			var pose := _escolher(CABECA_POSES)
			var v := Vector3(pose[1], pose[2] * _sinal(), pose[3] * _sinal())
			v *= _rng.randf_range(0.8, 1.15)
			if modo == Modo.JANELA:
				# A cara fica no vidro: tomba e cai, mas nao gira para longe.
				v = Vector3(clampf(v.x, -0.35, 0.35), clampf(v.y, -0.4, 0.4), clampf(v.z, -1.35, 1.35))
			elif modo == Modo.PADRE and absf(v.y) > 1.5:
				v.y *= 0.85
			return [v]
		Corpo.Osso.TORSO:
			var pose := _escolher(TRONCO_POSES)
			return [Vector3(pose[1], pose[2] * _sinal(), pose[3] * _sinal())]
		_:
			var pose := _escolher(BRACO_POSES)
			var espelho := -1.0 if osso == Corpo.Osso.BRACO_E else 1.0
			var torce := _sinal()
			var braco := Vector3(pose[1], pose[2] * espelho * torce, pose[3] * espelho)
			var ante := Vector3(pose[4], pose[5] * espelho * torce, 0.0)
			var escala := _rng.randf_range(0.8, 1.1)
			return [braco * escala, ante * escala]


func _zero(osso: int) -> Array:
	if osso == Corpo.Osso.BRACO_E or osso == Corpo.Osso.BRACO_D:
		return [Vector3.ZERO, Vector3.ZERO]
	return [Vector3.ZERO]


func _escolher(tabela: Array) -> Array:
	var total := 0.0
	for linha: Array in tabela:
		total += float(linha[0])
	var r := _rng.randf() * total
	for linha: Array in tabela:
		r -= float(linha[0])
		if r <= 0.0:
			return linha
	return tabela[tabela.size() - 1]


func _sinal() -> float:
	return 1.0 if _rng.randf() < 0.5 else -1.0


## Tremor de tres senos desencontrados, rapido: 19 a 47 Hz.
func _tremor(amp: float, desloca: float) -> Vector3:
	var t := _t + _fase + desloca
	return Vector3(sin(t * 41.0) + 0.5 * sin(t * 19.3 + 1.1),
		sin(t * 37.0 + 2.0) + 0.5 * sin(t * 23.7),
		sin(t * 47.0 + 4.0) + 0.5 * sin(t * 29.1 + 0.4)) * amp * 0.67


## Multiplica o tique por cima do que o corpo escreveu no osso.
func _escrever(esq: Skeleton3D, osso: int, euler: Vector3) -> void:
	var base := esq.get_bone_pose_rotation(osso)
	esq.set_bone_pose_rotation(osso, base * Basis.from_euler(euler).get_rotation_quaternion())
