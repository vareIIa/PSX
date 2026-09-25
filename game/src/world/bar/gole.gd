## O relogio de quem bebe no bar: o copo vai a boca, o gole, o golao de cabeca
## para tras e o brinde.
##
## Por que herda da Tragada
## ------------------------
## O `Corpo` ja sabe levar a mao aos labios por IK no ritmo de um relogio — a
## `Tragada` —, com a cabeca, a boca e o olho acompanhando, e ja sabe levar a
## mao para a frente e bater (o dedo na cinza). Beber e o mesmo gesto com outro
## tempo: um copo no lugar da blunt. Herdar e trocar so os envelopes deixa o
## `Corpo` e o `Convidado` intocados, e quem esta no bar ganha o gesto que a
## casa da fumaca levou meses para acertar.
##
## Os tres jeitos usam os estilos da Tragada, porque e por eles que o Corpo le:
##
##   GOLE    (CURTA)  leva, bebe um segundo, desce.
##   GOLAO   (FUNDA)  bebe longo de cabeca para tras e olho fechado, e solta o
##                    "ahh" de boca aberta.
##   BRINDE  (CINZA)  a mao leva o copo ao meio da mesa, bate uma vez e volta,
##                    e o gole vem logo depois.
##
## O brinde nao e sorteado: quem manda e a `VidaDoBar`, que brinda os dois de
## uma mesa no mesmo quadro (`brindar`) e leva a mao de cada um ao ponto de
## encontro pelo `Corpo.agarrar` (IK para um ponto do mundo). O `bate()` do
## cinzeiro nao serve: ele leva a mao 17 cm a frente do colo, e os copos paravam
## na altura do tampo, longe um do outro.
class_name Gole
extends Tragada

const GOLE := Tragada.Estilo.CURTA
const GOLAO := Tragada.Estilo.FUNDA
const BRINDE := Tragada.Estilo.CINZA

## Sobe, bebe, desce, engole, solta — em segundos, antes do sorteio de 15%.
const TEMPOS := {
	GOLE: [0.7, 1.0, 0.6, 0.0, 0.25],
	GOLAO: [0.85, 1.9, 0.7, 0.3, 0.55],
	BRINDE: [0.55, 0.75, 0.5, 0.0, 0.0],
}
## Espera entre um gole e o proximo, antes do ritmo da pessoa. Cerveja de bar e
## devagar: gole a cada seis segundos le como sede, nao como conversa.
const INTERVALO := Vector2(7.0, 19.0)
const CHANCE_GOLAO := 0.2
## Do fim do brinde ao gole: o copo sobe logo depois de bater.
const APOS_BRINDE := 0.12

## Quantos goles ja deu. A `VidaDoBar` le para saber quando o copo esvaziou.
var goles: int = 0

var _depois_do_brinde := false


func _escolher() -> void:
	var novo := GOLE
	if _depois_do_brinde:
		# Brindou: o gole seguinte e o de comemorar, mais longo.
		novo = GOLAO if _rng.randf() < 0.5 else GOLE
		_depois_do_brinde = false
	elif _rng.randf() < CHANCE_GOLAO:
		novo = GOLAO
	_usar(novo)
	_espera = _rng.randf_range(INTERVALO.x, INTERVALO.y) * _ritmo


func _usar(novo: Tragada.Estilo) -> void:
	estilo = novo
	_anterior = novo
	_dur = []
	for d: float in TEMPOS[novo]:
		_dur.append(d * _rng.randf_range(0.85, 1.15))


func _concluir() -> void:
	if estilo != BRINDE:
		goles += 1
		tragos = goles


## Brinda agora, do comeco. So quando a mao esta livre: no meio de um gole o
## brinde fica para o proximo pedido.
func brindar() -> bool:
	if ativo():
		return false
	_usar(BRINDE)
	_espera = APOS_BRINDE
	_depois_do_brinde = true
	_t = 0.0
	return true


## Quanto falta, a partir de agora, para os copos se encontrarem no brinde: a
## subida inteira e o fim do recuo da batida (`brinde`, 48% da fase).
func ate_bater() -> float:
	if estilo != BRINDE or _dur.size() < 2:
		return 0.0
	return maxf(0.0, float(_dur[0]) + float(_dur[1]) * 0.48 - _t)


# --- envelopes ----------------------------------------------------------------
# Nada de brasa, fumaca, tosse ou cinza: o copo nao acende.

func puxada() -> float:
	return 0.0


func baforada() -> float:
	return 0.0


func tosse() -> float:
	return 0.0


func cinza_caindo() -> bool:
	return false


func pelo_nariz() -> bool:
	return false


## O peito so mexe no golao: o tronco vai um tico para tras enquanto a cabeca
## tomba.
func peito() -> float:
	if estilo != GOLAO or fase() != Tragada.Fase.PUXA:
		return 0.0
	var p := progresso()
	return smoothstep(0.0, 0.3, p) * (1.0 - smoothstep(0.8, 1.0, p))


## O cinzeiro nao existe: o brinde vai pelo `brinde()`, lido pela VidaDoBar.
func bate() -> Vector2:
	return Vector2.ZERO


## Quanto a mao ja foi ao ponto do brinde, de 0 a 1. Na batida ela recua dois
## dedos e volta: e o tim-tim.
func brinde() -> float:
	if estilo != BRINDE:
		return 0.0
	var p := progresso()
	match fase():
		Tragada.Fase.SOBE:
			return smoothstep(0.0, 1.0, p)
		Tragada.Fase.PUXA:
			var k := clampf((p - 0.18) / 0.3, 0.0, 1.0)
			return 1.0 - 0.12 * sin(k * PI)
		Tragada.Fase.DESCE:
			return 1.0 - smoothstep(0.0, 1.0, p)
	return 0.0


## A cabeca tomba para tras enquanto bebe (inclina negativo sobe o queixo): um
## palmo no gole, quase o pescoco inteiro no golao. No brinde ela sobe um pouco,
## para o copo do outro.
func cabeca() -> Vector3:
	var p := progresso()
	var f := fase()
	if estilo == BRINDE:
		if f == Tragada.Fase.SOBE or f == Tragada.Fase.PUXA:
			return Vector3(-0.08 * (smoothstep(0.0, 1.0, p) if f == Tragada.Fase.SOBE else 1.0),
				0.0, 0.0)
		if f == Tragada.Fase.DESCE:
			return Vector3(-0.08 * (1.0 - p), 0.0, 0.0)
		return Vector3.ZERO
	var fundo := 0.42 if estilo == GOLAO else 0.2
	if f == Tragada.Fase.PUXA:
		return Vector3(-fundo * smoothstep(0.0, 0.35, p) * (1.0 - smoothstep(0.8, 1.0, p)),
			0.0, 0.0)
	if f == Tragada.Fase.PRENDE and estilo == GOLAO:
		# Engole: o queixo desce um dedo.
		return Vector3(0.06 * sin(p * PI), 0.0, 0.0)
	return Vector3.ZERO


## A boca: fechada no copo, o "ahh" depois do golao, e o "saude" do brinde.
func boca() -> StringName:
	var f := fase()
	if estilo == BRINDE:
		return &"ENTREABERTA" if f == Tragada.Fase.PUXA else &""
	if f == Tragada.Fase.PUXA:
		return &"CERRADA"
	if estilo == GOLAO and f == Tragada.Fase.SOLTA:
		return &"ABERTA" if progresso() < 0.6 else &"ENTREABERTA"
	return &""


func olhos() -> StringName:
	if fase() != Tragada.Fase.PUXA or estilo == BRINDE:
		return &""
	return &"FECHADO" if estilo == GOLAO else &"SEMICERRADO"
