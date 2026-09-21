## O que tem na calcada alem do piso: boca de lobo, tampa e a rampa da garagem.
##
## Por que existe
## -------------
## A calcada era um plano de ladrilho com uma face de meio-fio, igual de ponta a
## ponta da cidade. Calcada de verdade e cheia de coisa que ninguem desenhou de
## proposito: a boca de lobo engolindo a sarjeta a cada vinte e poucos metros, a
## tampa de ferro da companhia de agua, a da telefonica, e — a mais brasileira de
## todas — a rampa de concreto que o dono da casa jogou na sarjeta para o carro
## subir no portao. Custa poucos triangulos por faixa e e o que faz o chao
## parar de ler como tapete.
##
## Tudo e visual: nada aqui tem colisao. A boca de lobo e a tampa sao rentes ao
## piso e a rampa fica na faixa de estacionamento, onde carro de transito nao
## passa e pedestre so atravessa na faixa.
##
## Alturas: um centimetro e meio acima do plano de baixo, e nao meio. Encostados,
## os dois planos disputam o pixel a trinta metros e a peca pisca.
class_name DetalheCalcada
extends RefCounted

## Distancia entre bocas de lobo ao longo do meio-fio.
const PASSO_BOCA := 22.0
## Nenhum detalhe a menos disto da ponta da faixa: la e a esquina, a zebra e a
## rampa de pedestre.
const MARGEM_PONTA := 5.0
const ESCURO := Color(0.12, 0.12, 0.12)
const FERRO := Color(0.36, 0.35, 0.33)
const CIMENTO := Color(0.66, 0.65, 0.62)


## Bocas de lobo e tampas de uma faixa de calcada.
##
## `r` e o retangulo da faixa e `dir_meio_fio` a borda em que fica a rua, no
## esquema de `KitModular.calcada` (3 x min, 1 x max, 0 z min, 2 z max).
static func faixa(sup: Dictionary, r: Rect2, dir_meio_fio: int, semente: int) -> void:
	if not FundosBuilder.ativo:
		return
	var ao_longo_de_z := dir_meio_fio == 1 or dir_meio_fio == 3
	var comp := r.size.y if ao_longo_de_z else r.size.x
	var largura := r.size.x if ao_longo_de_z else r.size.y
	if comp < MARGEM_PONTA * 2.0 + 1.0 or largura < 1.2:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var h := KitModular.ALTURA_MEIO_FIO

	var t := MARGEM_PONTA + rng.randf_range(0.0, PASSO_BOCA * 0.5)
	while t < comp - MARGEM_PONTA:
		_boca_de_lobo(sup, r, dir_meio_fio, t, h)
		t += PASSO_BOCA * rng.randf_range(0.85, 1.15)

	# Tampa de ferro: agua, esgoto, telefone. Uma ou duas por faixa, no meio da
	# calcada, onde o cano passa.
	for k in rng.randi_range(0, 2):
		var tt := rng.randf_range(MARGEM_PONTA, comp - MARGEM_PONTA)
		var lado := rng.randf_range(0.35, 0.7) * largura
		var tam := 0.55 if rng.randf() < 0.6 else 0.42
		var p := _ponto(r, dir_meio_fio, tt, lado)
		KitModular.chao(sup, &"metal", Vector3(p.x - tam * 0.5, h + 0.015, p.z - tam * 0.5),
			Vector2(tam, tam), 8.0, FERRO.lerp(ESCURO, rng.randf() * 0.5))


## Ponto da faixa a `t` metros ao longo do meio-fio e `para_dentro` metros do
## meio-fio para a fachada.
static func _ponto(r: Rect2, dir: int, t: float, para_dentro: float) -> Vector3:
	match dir:
		3:
			return Vector3(r.position.x + para_dentro, 0.0, r.position.y + t)
		1:
			return Vector3(r.end.x - para_dentro, 0.0, r.position.y + t)
		0:
			return Vector3(r.position.x + t, 0.0, r.position.y + para_dentro)
		_:
			return Vector3(r.position.x + t, 0.0, r.end.y - para_dentro)


## Para onde a rua fica, a partir do meio-fio desta faixa.
static func _para_rua(dir: int) -> Vector3:
	match dir:
		3: return Vector3.LEFT
		1: return Vector3.RIGHT
		0: return Vector3.FORWARD
		_: return Vector3.BACK


static func _boca_de_lobo(sup: Dictionary, r: Rect2, dir: int, t: float, h: float) -> void:
	const LARG := 1.0
	var rua := _para_rua(dir)
	var ao_longo := Vector3(0.0, 0.0, 1.0) if dir == 1 or dir == 3 else Vector3(1.0, 0.0, 0.0)
	var meio_fio := _ponto(r, dir, t, 0.0)
	var giro := atan2(rua.x, rua.z)
	# A boca, rasgada na face do meio-fio.
	KitModular.placa(sup, &"metal", meio_fio + rua * 0.012 + Vector3(0.0, h * 0.45, 0.0),
		Vector2(LARG, h * 0.55), giro, ESCURO)
	# A grelha na sarjeta, rente ao asfalto.
	var g := meio_fio + rua * 0.2
	var tam := Vector2(LARG, 0.36) if absf(ao_longo.x) > 0.5 else Vector2(0.36, LARG)
	KitModular.chao(sup, &"metal", Vector3(g.x - tam.x * 0.5, 0.02, g.z - tam.y * 0.5),
		tam, 8.0, FERRO.darkened(0.25))
	# A tampa de concreto em cima, na calcada.
	var c := meio_fio - rua * 0.3
	var tc := Vector2(LARG + 0.2, 0.55) if absf(ao_longo.x) > 0.5 else Vector2(0.55, LARG + 0.2)
	KitModular.chao(sup, &"concreto", Vector3(c.x - tc.x * 0.5, h + 0.015, c.z - tc.y * 0.5),
		tc, 8.0, CIMENTO)


## A rampa de concreto que o dono da casa jogou na sarjeta em frente ao portao.
##
## `meio_fio` e o ponto do meio-fio em frente ao portao, `rua` para onde a rua
## fica. A cunha sobe da sarjeta ate a quina da calcada em 45 cm.
static func guia_rebaixada(sup: Dictionary, meio_fio: Vector3, rua: Vector3,
		largura: float) -> void:
	if not FundosBuilder.ativo:
		return
	const CORRIDA := 0.46
	var h := KitModular.ALTURA_MEIO_FIO
	var giro := atan2(rua.x, rua.z)
	var inclinacao := atan2(h, CORRIDA)
	var comp := sqrt(h * h + CORRIDA * CORRIDA)
	var base := Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, inclinacao)
	var centro := meio_fio + rua * (CORRIDA * 0.5) + Vector3(0.0, h * 0.5 - 0.02, 0.0)
	KitModular.caixa_livre(sup, &"concreto", centro,
		Vector3(largura, 0.05, comp + 0.02), base, CIMENTO.darkened(0.08), 8.0)
