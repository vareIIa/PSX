## A poda em V da arvore embaixo da rede eletrica: o que a concessionaria corta.
##
## Conta pura, sem dependencia de nenhuma outra classe do mundo, de proposito.
## Quem desenha a arvore (ArvoreEsqueleto) e leve e e usado por meio jogo; se a
## conta morasse em KitRede, a arvore passaria a arrastar RedeEletrica,
## ChunkBuilder e Lampada, e no `--script` (sem autoload) a malha urbana inteira
## deixava de compilar — medido: a checar_rota caiu de 142 para 117 assercoes.
##
## `poda` sao pares de pontos (segmentos) do fio mais baixo de cada vao, em
## coordenada local do chunk e na altura do chao plano (KitRede.faixas_de_poda).
class_name PodaEmV
extends RefCounted

## O V e estreito: abre o corredor dos fios e deixa as duas metades da copa,
## que e a arvore podada de calcada. Aberto a 0,6 m por metro ele engolia a copa
## inteira, e a arvore embaixo do fio virava tronco pelado.
const BASE := 1.1
const ABERTURA := 0.3
## Abaixo do fio a poda so tira o que chega a menos de 90 cm dele. Descendo
## 1,4 m, a zona pegava o pe de toda pernada da arvore plantada embaixo da
## linha, e ela virava um Y pelado.
const ABAIXO := 0.9


## O ponto `q` cai na parte da copa que e cortada? `folga` e o meio tamanho da
## peca (o cartao nao e um ponto).
static func podado(q: Vector3, poda: PackedVector3Array, folga: float = 0.0) -> bool:
	for s in range(0, poda.size() - 1, 2):
		var a := poda[s]
		var b := poda[s + 1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var l2 := ab.length_squared()
		var t := 0.0
		if l2 > 1e-6:
			t = clampf(Vector2(q.x - a.x, q.z - a.z).dot(ab) / l2, 0.0, 1.0)
		var c := a.lerp(b, t)
		var acima := q.y - c.y
		if acima < -ABAIXO - folga:
			continue
		var lat := Vector2(q.x - c.x, q.z - c.z).length()
		if lat < BASE + folga + maxf(acima, 0.0) * ABERTURA:
			return true
	return false


## Direcao horizontal do fio mais perto ate `q` (zero sem fio). A rebrota do
## galho serrado sai para ESTE lado: para dentro do V ela seria podada de novo.
static func para_fora_do_fio(q: Vector3, poda: PackedVector3Array) -> Vector3:
	var melhor := INF
	var saida := Vector3.ZERO
	for s in range(0, poda.size() - 1, 2):
		var a := poda[s]
		var b := poda[s + 1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var l2 := ab.length_squared()
		var t := 0.0
		if l2 > 1e-6:
			t = clampf(Vector2(q.x - a.x, q.z - a.z).dot(ab) / l2, 0.0, 1.0)
		var c := a.lerp(b, t)
		var d := Vector2(q.x - c.x, q.z - c.z)
		if d.length() < melhor:
			melhor = d.length()
			saida = Vector3(d.x, 0.0, d.y).normalized() if d.length() > 1e-4 \
				else Vector3(-ab.y, 0.0, ab.x).normalized()
	return saida
