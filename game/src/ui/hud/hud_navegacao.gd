## A proxima manobra da rota do GPS: virar, seguir, chegar. Funcao pura.
##
## Por que isto nao mora em `Rota`
## -------------------------------
## Porque `Rota` responde "por onde", e esta conta responde "o que eu faco
## agora" — e muda a cada passo do jogador, enquanto a rota so muda quando ele
## sai do corredor (`Gps.manter_rota`). Quem pergunta e o HUD, meio segundo de
## cada vez; a rota ja vem simplificada (so os vertices onde a direcao muda),
## entao a manobra e o primeiro vertice a frente com angulo de verdade.
##
## Convencao do plano: x = mundo x, y = mundo z. Norte e -y. Com o y para baixo,
## produto vetorial positivo e giro no sentido horario: DIREITA.
class_name HudNavegacao
extends RefCounted

## Abaixo disto o vertice e ajuste de faixa, e nao esquina.
const ANGULO_MIN := deg_to_rad(25.0)
## Acima disto e meia-volta.
const ANGULO_RETORNO := deg_to_rad(150.0)
## A manobra mais longe que isto vira "siga": dizer "vire a direita em 800 m"
## e ruido; o jogador quer saber que e para seguir.
const LONGE := 320.0
## Quanto entrar na rua nova para perguntar o nome dela.
const DENTRO_DA_RUA := 12.0


## `{tipo, dist, ponto, depois}`. `tipo`: &"direita", &"esquerda", &"retorno",
## &"siga" ou &"chegada". `ponto` e onde a manobra acontece; `depois`, um ponto
## ja dentro da rua seguinte (para o nome dela). Vazio quando nao ha rota.
static func proxima(rota: PackedVector2Array, pos: Vector2) -> Dictionary:
	if rota.size() < 2:
		return {}
	# Segmento mais perto do jogador e onde ele esta nele.
	var k := 0
	var melhor := INF
	var proj := rota[0]
	for i in range(rota.size() - 1):
		var a := rota[i]
		var b := rota[i + 1]
		var ab := b - a
		var t := 0.0
		if ab.length_squared() > 0.0001:
			t = clampf((pos - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var q := a + ab * t
		var d := pos.distance_to(q)
		if d < melhor:
			melhor = d
			k = i
			proj = q
	var acc := proj.distance_to(rota[k + 1])
	for j in range(k + 1, rota.size() - 1):
		var d1 := rota[j] - rota[j - 1]
		var d2 := rota[j + 1] - rota[j]
		if d1.length_squared() < 0.0001 or d2.length_squared() < 0.0001:
			acc += d2.length()
			continue
		var ang := atan2(d1.x * d2.y - d1.y * d2.x, d1.dot(d2))
		if absf(ang) >= ANGULO_MIN:
			var tipo := &"direita" if ang > 0.0 else &"esquerda"
			if absf(ang) >= ANGULO_RETORNO:
				tipo = &"retorno"
			if acc > LONGE:
				tipo = &"siga"
			return {"tipo": tipo, "dist": acc, "ponto": rota[j],
				"depois": rota[j] + d2.normalized() * DENTRO_DA_RUA}
		acc += d2.length()
	return {"tipo": &"chegada", "dist": acc, "ponto": rota[rota.size() - 1],
		"depois": rota[rota.size() - 1]}


## O verbo da manobra, como o GPS de carro fala.
static func verbo(tipo: StringName) -> String:
	match tipo:
		&"direita":
			return "VIRE A DIREITA"
		&"esquerda":
			return "VIRE A ESQUERDA"
		&"retorno":
			return "FACA O RETORNO"
		&"chegada":
			return "DESTINO"
	return "SIGA EM FRENTE"


# --- chegada -------------------------------------------------------------------
#
# O GPS nao sabia que o jogador tinha chegado: a rota ficava na tela, colada no
# destino, ate alguem desmarcar a mao. Agora a chegada fecha a navegacao com um
# banner, como qualquer GPS de jogo.

## Raio de chegada, em metros. De carro e maior: o destino costuma ser a porta,
## e o carro para na rua, meia calcada e uma faixa longe dela.
const CHEGADA_A_PE := 10.0
const CHEGADA_DE_CARRO := 22.0
## Folga para armar: o destino so "chega" depois de o jogador ter estado fora do
## raio mais esta folga. Marcar a esquina onde ja se esta nao dispara nada.
const CHEGADA_FOLGA := 6.0


static func raio_de_chegada(dirigindo: bool) -> float:
	return CHEGADA_DE_CARRO if dirigindo else CHEGADA_A_PE


## Estado seguinte da vigia. `armada` vem do passo anterior. Devolve
## `{armada, chegou}`.
static func vigiar_chegada(destino: Vector2, pos: Vector2, dirigindo: bool, armada: bool) -> Dictionary:
	var d := destino.distance_to(pos)
	var raio := raio_de_chegada(dirigindo)
	if not armada:
		return {"armada": d > raio + CHEGADA_FOLGA, "chegou": false}
	if d <= raio:
		return {"armada": false, "chegou": true}
	return {"armada": true, "chegou": false}
