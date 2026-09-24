## O relogio de quem fuma: quando a mao vai a boca, quanto puxa, quanto prende
## e como solta.
##
## Por que isto saiu do Corpo
## --------------------------
## A tragada antiga era uma onda de quatro tempos (sobe, segura, desce, espera)
## igual para todo mundo, e o braco subia por dois angulos fixos no ombro e no
## cotovelo. Os angulos nunca levavam a mao ate a boca — paravam no peito — e
## nada acontecia depois: nem puxar, nem prender, nem soltar fumaca. Oito
## pessoas numa sala fazendo o mesmo meio-gesto em loop le como defeito, nao
## como festa.
##
## Aqui a tragada e uma SEQUENCIA com fases, e cada tragada sorteia um estilo:
##
##   CURTA     leva, puxa rapido, tira e ja solta para a frente.
##   FUNDA     puxa longo, prende de olho fechado com a cabeca subindo, e solta
##             para o teto uma coluna comprida.
##   DUPLA     puxa, afasta um dedo, puxa de novo; solta reto.
##   NARIZ     puxa, prende, e solta pelo nariz, de boca fechada, para baixo.
##   DE_LADO   solta virando o rosto para um lado — educacao de roda.
##   TOSSE     puxou demais: solta em quatro tossidas, curvado.
##   CINZA     nao leva a boca: afasta a mao e bate a cinza com o dedo.
##
## Cada pessoa tem o proprio peso para cada estilo (a semente vem da ficha), o
## proprio ritmo entre uma e outra, e comeca num ponto sorteado do ciclo: dois
## vizinhos de sofa nunca levam a mao a boca juntos.
##
## Quem le isto e o `Corpo` (a pose: braco por IK ate a boca, peito, cabeca,
## boca e olho) e a `Blunt` (brasa, cinza, fumaca da ponta e baforada). O Corpo
## avanca o relogio; ninguem mais escreve aqui.
class_name Tragada
extends RefCounted

enum Estilo { CURTA, FUNDA, DUPLA, NARIZ, DE_LADO, TOSSE, CINZA }
enum Fase { SOBE, PUXA, DESCE, PRENDE, SOLTA, ESPERA }

## Peso de cada estilo antes do tempero da pessoa. TOSSE e rara de proposito:
## tosse a cada tres tragadas vira piada; uma vez por noite e verdade. CINZA nao
## tem peso: ela e escolhida pela cinza acumulada, e nao pelo sorteio.
const PESOS: Array[float] = [1.0, 0.75, 0.55, 0.45, 0.65, 0.09, 0.0]

## Duracao de cada fase por estilo, em segundos: sobe, puxa, desce, prende,
## solta. Na CINZA, "sobe" e levar a mao para o lado, "puxa" e bater, "desce" e
## voltar.
const DURACOES := {
	Estilo.CURTA: [0.75, 0.95, 0.55, 0.15, 1.35],
	Estilo.FUNDA: [0.95, 2.1, 0.7, 1.7, 2.5],
	Estilo.DUPLA: [0.8, 2.3, 0.6, 0.6, 1.9],
	Estilo.NARIZ: [1.0, 1.35, 0.75, 0.9, 2.3],
	Estilo.DE_LADO: [0.8, 1.25, 0.6, 0.55, 1.9],
	Estilo.TOSSE: [0.9, 2.2, 0.45, 0.25, 2.8],
	Estilo.CINZA: [0.65, 1.0, 0.6, 0.0, 0.0],
}

## Espera entre uma tragada e a proxima, antes do ritmo da pessoa.
const ESPERA := Vector2(3.0, 8.5)
## Quanto cada tragada acrescenta de cinza (1 = cinza comprida, hora de bater)
## e quanto consome da blunt.
const CINZA_POR_TRAGO := 0.2
const QUEIMA_POR_TRAGO := 0.02
## A blunt nao some: queima ate o toco de pouco mais da metade e para ali.
const QUEIMA_MAX := 0.55
## Passos de pose por segundo durante a tragada. E a mesma grade de 15 Hz do
## resto do corpo (`Corpo.POSES_POR_CICLO`): o braco anda em degrau, como anda o
## resto do boneco.
const PASSOS := 15.0

var estilo: Estilo = Estilo.CURTA
## Comprimento da cinza, de 0 (acabou de bater) a 1.
var cinza: float = 0.0
## Quanto da blunt ja queimou, de 0 (inteira) a QUEIMA_MAX.
var consumido: float = 0.0
## Para que lado o DE_LADO vira o rosto (-1 esquerda, 1 direita).
var lado: float = 1.0
## Quantas tragadas ja deu. Quem desenha a cinza e a brasa le a mudanca.
var tragos: int = 0

var _rng := RandomNumberGenerator.new()
var _pesos: Array[float] = []
var _ritmo: float = 1.0
var _dur: Array = []
var _espera: float = 4.0
var _t: float = 0.0
var _anterior: int = -1


func _init(semente: int) -> void:
	_rng.seed = semente * 747796405 + 2891336453
	# O tempero da pessoa: cada uma tem os estilos dela.
	for p: float in PESOS:
		_pesos.append(p * _rng.randf_range(0.45, 1.7))
	_ritmo = _rng.randf_range(0.75, 1.35)
	consumido = _rng.randf_range(0.0, 0.3)
	cinza = _rng.randf_range(0.1, 0.6)
	_escolher()
	# Comeca num ponto qualquer do ciclo: ninguem na sala esta em fase.
	_t = _rng.randf_range(0.0, _fim(Fase.ESPERA))


# --- relogio ----------------------------------------------------------------

func passo(delta: float) -> void:
	_t += delta
	var total := _fim(Fase.ESPERA)
	if _t < total:
		return
	_t -= total
	_concluir()
	_escolher()


## Salta para o fim da parte da mao (quem comecou a andar nao anda com a mao na
## boca). Se ja puxou, ainda solta a fumaca — andar soltando fumaca e normal.
func interromper() -> void:
	match fase():
		Fase.SOBE:
			# Ainda nao puxou: nao ha o que soltar, vai direto para a espera.
			_t = _fim(Fase.SOLTA)
		Fase.PUXA, Fase.DESCE:
			_t = _fim(Fase.DESCE)


## Estende a espera: quem esta falando nao leva a mao a boca no meio da frase.
func adiar(delta: float) -> void:
	if fase() == Fase.ESPERA:
		_t = maxf(_fim(Fase.SOLTA), _t - delta)


## Forca um estilo agora, do comeco. Para a bancada fotografar cada um.
func forcar(novo: Estilo, t: float = 0.0) -> void:
	estilo = novo
	_dur = (DURACOES[estilo] as Array).duplicate()
	_espera = ESPERA.x
	_t = t


func tempo() -> float:
	return _t


func duracao_ativa() -> float:
	return _fim(Fase.SOLTA)


func _concluir() -> void:
	if estilo == Estilo.CINZA:
		cinza = 0.0
		return
	tragos += 1
	var forte := 1.4 if estilo == Estilo.FUNDA or estilo == Estilo.TOSSE else 1.0
	cinza = minf(1.0, cinza + CINZA_POR_TRAGO * forte)
	consumido = minf(QUEIMA_MAX, consumido + QUEIMA_POR_TRAGO * forte)


func _escolher() -> void:
	var novo := -1
	if cinza > 0.75 and _rng.randf() < 0.75:
		novo = Estilo.CINZA
	else:
		for tentativa in 2:
			novo = _sortear()
			# Repetir o mesmo estilo em seguida e o que mais le como loop.
			if novo != _anterior:
				break
	estilo = novo as Estilo
	_anterior = novo
	lado = -1.0 if _rng.randf() < 0.5 else 1.0
	_dur = []
	for d: float in DURACOES[estilo]:
		_dur.append(d * _rng.randf_range(0.85, 1.15))
	_espera = _rng.randf_range(ESPERA.x, ESPERA.y) * _ritmo
	if estilo == Estilo.CINZA:
		_espera *= 0.5


func _sortear() -> int:
	var soma := 0.0
	for p: float in _pesos:
		soma += p
	var x := _rng.randf() * soma
	for i in _pesos.size():
		x -= _pesos[i]
		if x <= 0.0:
			return i
	return Estilo.CURTA


func _dur_de(f: Fase) -> float:
	if f == Fase.ESPERA:
		return _espera
	return float(_dur[f])


## Instante em que a fase `f` termina, contado do comeco do ciclo.
func _fim(f: Fase) -> float:
	var t := 0.0
	for i in int(f) + 1:
		t += _dur_de(i as Fase)
	return t


func fase() -> Fase:
	for i in 6:
		if _t < _fim(i as Fase):
			return i as Fase
	return Fase.ESPERA


## Quanto da fase atual ja passou, de 0 a 1.
func progresso() -> float:
	var f := fase()
	var d := _dur_de(f)
	if d <= 0.0:
		return 1.0
	return clampf((_t - (_fim(f) - d)) / d, 0.0, 1.0)


func ativo() -> bool:
	return fase() != Fase.ESPERA


## Chave para a assinatura da pose: zero na espera (nada mexe, o esqueleto nao
## e reescrito) e um degrau novo a cada 1/15 s durante a tragada.
func chave() -> int:
	if not ativo():
		return 0
	return 1 + int(_t * PASSOS) + int(estilo) * 100003


# --- envelopes --------------------------------------------------------------

## Quanto a mao ja chegou na boca, de 0 a 1.
func alcance() -> float:
	if estilo == Estilo.CINZA:
		return 0.0
	var p := progresso()
	match fase():
		Fase.SOBE:
			return smoothstep(0.0, 1.0, p)
		Fase.PUXA:
			if estilo == Estilo.DUPLA:
				# Entre as duas puxadas a mao afasta dois dedos da boca.
				return 1.0 - 0.12 * sin(clampf((p - 0.4) / 0.2, 0.0, 1.0) * PI)
			return 1.0
		Fase.DESCE:
			return 1.0 - smoothstep(0.0, 1.0, p)
	return 0.0


## A forca da puxada agora, de 0 a 1. E o que acende a brasa.
func puxada() -> float:
	if fase() != Fase.PUXA or estilo == Estilo.CINZA:
		return 0.0
	var p := progresso()
	if estilo == Estilo.DUPLA:
		# Duas puxadas, com a mao afastada no meio.
		var a := smoothstep(0.0, 0.1, p) * (1.0 - smoothstep(0.32, 0.42, p))
		var b := smoothstep(0.58, 0.68, p) * (1.0 - smoothstep(0.9, 1.0, p))
		return maxf(a, b)
	return smoothstep(0.0, 0.15, p) * (1.0 - smoothstep(0.82, 1.0, p))


## Pulmao cheio, de 0 a 1: o peito sobe na puxada e desce na soltura.
func peito() -> float:
	if estilo == Estilo.CINZA:
		return 0.0
	var p := progresso()
	match fase():
		Fase.PUXA:
			return p
		Fase.DESCE, Fase.PRENDE:
			return 1.0
		Fase.SOLTA:
			return 1.0 - smoothstep(0.0, 0.9, p)
	return 0.0


## A forca da fumaca saindo agora, de 0 a 1.
func baforada() -> float:
	if estilo == Estilo.CINZA:
		return 0.0
	var f := fase()
	var p := progresso()
	if f == Fase.SOLTA:
		if estilo == Estilo.TOSSE:
			return tosse()
		var ataque := 0.08 if estilo == Estilo.CURTA else 0.14
		var cauda := 1.0 - smoothstep(0.3, 1.0, p)
		return smoothstep(0.0, ataque, p) * cauda
	# Quem puxa curto ja deixa escapar um fio antes de a mao descer toda.
	if f == Fase.DESCE and estilo == Estilo.CURTA:
		return smoothstep(0.6, 1.0, p) * 0.5
	return 0.0


## Tossida, de 0 a 1: quatro solavancos que perdem forca.
func tosse() -> float:
	if estilo != Estilo.TOSSE or fase() != Fase.SOLTA:
		return 0.0
	var p := progresso()
	var k := fmod(p * 4.0, 1.0)
	return exp(-k * 7.0) * (1.0 - p * 0.45) * smoothstep(0.0, 0.03, k)


## O dedo batendo a cinza: quanto a mao esta afastada (x) e o toque (y), de 0 a 1.
func bate() -> Vector2:
	if estilo != Estilo.CINZA:
		return Vector2.ZERO
	var p := progresso()
	match fase():
		Fase.SOBE:
			return Vector2(smoothstep(0.0, 1.0, p), 0.0)
		Fase.PUXA:
			var k := fmod(p * 3.0, 1.0)
			return Vector2(1.0, exp(-k * 9.0) * smoothstep(0.0, 0.05, k))
		Fase.DESCE:
			return Vector2(1.0 - smoothstep(0.0, 1.0, p), 0.0)
	return Vector2.ZERO


## A cinza cai no segundo toque.
func cinza_caindo() -> bool:
	return estilo == Estilo.CINZA and fase() == Fase.PUXA and progresso() > 0.34


## Pelo nariz: a fumaca sai do nariz, de boca fechada.
func pelo_nariz() -> bool:
	return estilo == Estilo.NARIZ


## Para onde a fumaca sai, no referencial da CABECA (-Z e a frente do rosto).
func direcao_baforada() -> Vector3:
	match estilo:
		Estilo.FUNDA:
			return Vector3(0.0, 0.85, -0.5).normalized()
		Estilo.NARIZ:
			return Vector3(0.0, -0.75, -0.62).normalized()
		Estilo.CURTA:
			return Vector3(0.0, -0.2, -1.0).normalized()
		Estilo.TOSSE:
			return Vector3(0.0, -0.35, -1.0).normalized()
	return Vector3(0.0, 0.08, -1.0).normalized()


## O que a cabeca faz por cima da pose: (inclina, giro, tombo), em radianos, na
## convencao de `Corpo._girar_cabeca` (inclina positivo olha para baixo).
func cabeca() -> Vector3:
	var p := progresso()
	var f := fase()
	match estilo:
		Estilo.FUNDA:
			if f == Fase.PRENDE:
				return Vector3(-0.30 * smoothstep(0.3, 1.0, p), 0.0, 0.0)
			if f == Fase.SOLTA:
				return Vector3(-0.30 - 0.12 * smoothstep(0.0, 0.3, p)
					+ 0.42 * smoothstep(0.6, 1.0, p), 0.0, 0.0)
		Estilo.DE_LADO:
			var giro := 0.0
			if f == Fase.PRENDE:
				giro = smoothstep(0.4, 1.0, p)
			elif f == Fase.SOLTA:
				giro = 1.0 - smoothstep(0.75, 1.0, p)
			return Vector3(0.0, lado * 0.62 * giro, 0.0)
		Estilo.NARIZ:
			if f == Fase.SOLTA:
				return Vector3(-0.12 * (1.0 - smoothstep(0.7, 1.0, p)), 0.0, 0.0)
		Estilo.TOSSE:
			if f == Fase.SOLTA:
				return Vector3(0.30 * tosse() + 0.12 * (1.0 - p), 0.0, 0.0)
	return Vector3.ZERO


## A boca durante a tragada: &"" e a boca da propria expressao (nao mexe).
func boca() -> StringName:
	if fase() == Fase.SOLTA and baforada() > 0.08:
		match estilo:
			Estilo.FUNDA, Estilo.DE_LADO:
				return &"REDONDA"
			Estilo.TOSSE:
				return &"ABERTA"
			Estilo.NARIZ:
				return &"CERRADA"
		return &"ENTREABERTA"
	if fase() == Fase.PRENDE:
		return &"CERRADA"
	return &""


## O olho durante a tragada: semicerrado puxando, fechado prendendo fundo.
func olhos() -> StringName:
	var f := fase()
	if f == Fase.PUXA and estilo != Estilo.CINZA:
		return &"SEMICERRADO"
	if f == Fase.PRENDE and estilo == Estilo.FUNDA:
		return &"FECHADO"
	if f == Fase.SOLTA and estilo == Estilo.TOSSE:
		return &"FECHADO"
	return &""


static func nome(e: Estilo) -> String:
	return String(Estilo.keys()[e]).to_lower()
