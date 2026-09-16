## Os limpadores: a geometria, a cinematica e o MODO.
##
## Por que virou classe
## --------------------
## Na Fase 3 o limpador era meia duzia de constantes e um `_fase` dentro de
## `CarroCabine`, e a unica coisa que ele sabia dizer era o angulo. Faltava o
## que um limpador de verdade tem: ele nao gira sempre igual. Ele tem MODO, o
## modo segue a chuva, e o motorista mexe nele porque a chuva apertou. Enquanto
## isso era um `fase += delta / passada`, parar de chover deixava a palheta
## congelada no meio do vidro e comecar a chover a fazia arrancar do nada.
##
## Aqui existe o ciclo inteiro: o modo sobe e desce com histerese (senao ele
## troca de velocidade sozinho na borda do limiar, o que le como falha
## eletrica), o intermitente tem PAUSA que encurta conforme o vidro enche, e
## quando a chuva para ele ainda da mais uma passada e SO ENTAO estaciona. Nada
## disso e tecla: foi a decisao de 16/09 — limpador automatico.
##
## O que este no entrega ao mapa de agua
## -------------------------------------
## Nao o angulo: o SETOR varrido neste quadro, do angulo de antes ao de agora.
## E a diferenca que limpa, e nao a posicao. E por isso que o criterio C6
## (">= 90% dos texels que perdem agua estao dentro do setor varrido nesse
## quadro") e uma pergunta com resposta e nao uma esperanca — e por isso que na
## velocidade 2, com a palheta andando 15 graus por quadro, ela nao deixa
## listras de agua entre um quadro e o outro.
class_name Limpador
extends Node3D

enum Modo {DESLIGADO, INTERMITENTE, VELOCIDADE_1, VELOCIDADE_2}

## Segundos de uma passada (ida OU volta) em cada modo.
##
## Um limpador de verdade num aguaceiro faz uma passada a cada 0,7 s mais ou
## menos. Mais rapido vira ventilador; mais lento deixa o vidro cheio de agua
## tempo demais e o plano perde a estrada, que e a unica coisa que ele tem para
## mostrar.
const PASSADA := [0.70, 0.62, 0.62, 0.42]

## Chuva a partir da qual cada modo LIGA, e abaixo da qual ele desliga.
##
## As duas listas nao sao a mesma de proposito: com um limiar so, uma chuva
## oscilando em volta dele troca a velocidade do limpador varias vezes por
## segundo. A folga entre subir e descer e o que impede isso.
const LIGA := [0.0, 0.10, 0.42, 0.78]
const DESLIGA := [0.0, 0.05, 0.32, 0.66]

## Pausa do intermitente: vidro quase limpo e vidro quase cheio, em segundos.
const PAUSA := Vector2(6.0, 1.8)

## Quantas passadas a mais depois de a chuva parar. Duas: e o que seca o vidro,
## e e o gesto que diz que o limpador e de alguem e nao do cenario.
const PASSADAS_FINAIS := 2

## Curso em graus a partir do repouso, e o repouso em graus a partir da vertical
## do vidro. Negativo: a palheta dorme deitada para o lado do motorista.
##
## Estes cinco numeros (curso, repouso, os dois `U` e o `ALCANCE`) nao foram
## escolhidos a mao: com os anteriores — 78 graus, repouso -46, U 0,30/0,66 e
## alcance 0,92 — o leque cobria 49% do lado do motorista, e o criterio C7 pede
## 70%. Uma varredura do espaco deles, com a mesma conta de area que a sonda
## usa, deu este conjunto. O vinculo que fecha a busca e fisico: no alto do arco
## a ponta tem de parar POUCO antes da borda de cima do vidro, e nao passar dela
## — com alcance 1,00 o leque sobe para 74% e a palheta encosta na linha do
## teto, que nenhum limpador faz.
const CURSO := 110.0
const REPOUSO := -58.0

## Onde os dois pivos ficam, em fracao da largura do vidro, e quanto abaixo da
## borda de baixo dele, em metros.
##
## Tudo em fracao do VIDRO e nunca da largura do carro: o mesmo par de numeros
## serve ao Fusca e a perua, e a palheta cai no vidro nos dois.
const U_MOTORISTA := 0.24
const U_PASSAGEIRO := 0.68
const PIVO_ABAIXO := 0.035

## Raio de dentro da palheta e quanto do alcance ate a borda de cima ela cobre.
## Com 0,98 a ponta para 1,1 cm abaixo da borda no alto do arco.
const RAIO_MIN := 0.10
const ALCANCE := 0.98

## Quanto a palheta fica por FORA do vidro. Ela corre do lado de fora — e por
## isso que o motorista a ve atraves do proprio vidro.
const FORA := 0.014

## Grossura da palheta e meia largura dela em radianos, para o setor do mapa.
const GROSSURA := 0.017
const MEIA_PALHETA := 0.035

const C_BORRACHA := Vector2i(7, 0)

var modo: Modo = Modo.DESLIGADO

var _painel: Dictionary = {}
var _indice: int = -1
var _pivos: Array[Node3D] = []
## A orientacao de repouso de cada pivo: os eixos do PLANO do vidro.
##
## Guardada porque `Node3D.rotation = ...` nao gira o no: ele SUBSTITUI a base
## inteira pela de Euler, e com isso o referencial do vidro se perde no primeiro
## quadro. Era o que estava acontecendo — o shader desenhava o leque no lugar
## certo e a palheta ia para outro lugar, 38 cm fora do plano do vidro, o que so
## apareceu quando a sonda do C7 passou a medir a ponta pela barra e nao pelo
## angulo.
var _bases: Array[Basis] = []
var _pivo_a := Vector2.ZERO
var _pivo_b := Vector2.ZERO
var _raios := Vector2(RAIO_MIN, 0.5)
## Fase do ciclo: 0..1 ida, 1..2 volta.
var _fase: float = 0.0
var _pausa: float = 0.0
var _finais: int = 0
var _ang_antes: float = 0.0
var _ang_agora: float = 0.0
var _andou: bool = false


## Prepara os pivos no plano do para-brisa. `painel` vem de `VidroCabine`,
## `indice` e a posicao dele no mapa de agua.
##
## O que estava errado antes
## -------------------------
## A palheta nascia deitada ao longo de -Z e o pivo girava em Z, ou seja, EM
## TORNO DO PROPRIO COMPRIMENTO. Medido em 16/09/2026: a ponta ficava em
## (+/-0,30; 0,94; -1,355) no repouso, no meio e no fim do curso de 78 graus —
## cinco milimetros de deslocamento no curso inteiro, e a 48 cm do plano do
## vidro. O limpador nunca varreu nada. Aqui o eixo de giro E a normal do vidro.
func configurar(painel: Dictionary, indice: int, material: Material) -> void:
	_painel = painel
	_indice = indice
	for p: Node3D in _pivos:
		p.queue_free()
	_pivos.clear()
	_bases.clear()
	if painel.is_empty():
		return
	var origem: Vector3 = painel["origem"]
	var eu: Vector3 = painel["u"]
	var ev: Vector3 = painel["v"]
	var n: Vector3 = painel["normal"]
	var tam: Vector2 = painel["tam"]

	var v_pivo := tam.y + PIVO_ABAIXO
	_raios = Vector2(RAIO_MIN, v_pivo * ALCANCE)
	_pivo_a = Vector2(tam.x * U_MOTORISTA, v_pivo)
	_pivo_b = Vector2(tam.x * U_PASSAGEIRO, v_pivo)

	for m: Vector2 in [_pivo_a, _pivo_b]:
		var pivo := Node3D.new()
		pivo.name = "Palheta%d" % _pivos.size()
		var base := Basis(eu, -ev, eu.cross(-ev)).orthonormalized()
		pivo.transform = Transform3D(base,
			origem + eu * m.x + ev * m.y + n * FORA)
		add_child(pivo)
		_pivos.append(pivo)
		_bases.append(base)
		var mi := MeshInstance3D.new()
		mi.name = "Braco"
		mi.mesh = _braco()
		mi.material_override = material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivo.add_child(mi)
	_aplicar()


## Braco e borracha, ao longo do +Y local (que sobe o vidro).
func _braco() -> ArrayMesh:
	var sup := {}
	var meio := (_raios.x + _raios.y) * 0.5
	var comp := _raios.y - _raios.x
	AtlasKit.caixa(sup, &"painel", Vector3(0.0, meio, -0.006),
		Vector3(0.016, comp, 0.012), C_BORRACHA, Color(0.19, 0.19, 0.20))
	AtlasKit.caixa(sup, &"painel", Vector3(0.0, meio, 0.004),
		Vector3(GROSSURA, comp, 0.010), C_BORRACHA, Color(0.14, 0.14, 0.15))
	return PSXMesh.dados_para_mesh(sup[&"painel"])


## Um quadro. `chuva` de 0 a 1, `cobertura` e quanta agua ha no para-brisa.
func atualizar(chuva: float, cobertura: float, delta: float) -> void:
	_escolher_modo(chuva)
	_ang_antes = _ang_agora
	_andou = false
	if modo == Modo.DESLIGADO and _finais <= 0 and is_equal_approx(_fase, 0.0):
		_aplicar()
		return

	var passada: float = PASSADA[int(modo)]
	if modo == Modo.INTERMITENTE and is_zero_approx(_fase) and _finais <= 0:
		# A pausa encurta conforme o vidro enche: e assim que o intermitente
		# de um carro daquela idade se parece com alguem decidindo.
		if _pausa <= 0.0:
			_pausa = lerpf(PAUSA.x, PAUSA.y, clampf(cobertura, 0.0, 1.0))
		_pausa -= delta
		if _pausa > 0.0:
			_aplicar()
			return
		_pausa = 0.0

	var antes := _fase
	_fase = fmod(_fase + delta / maxf(passada, 0.05), 2.0)
	_andou = true
	if _fase < antes:
		# Fechou um ciclo: aqui e o unico lugar onde a palheta pode parar.
		if _finais > 0:
			_finais -= 1
		if modo == Modo.DESLIGADO and _finais <= 0:
			_fase = 0.0
			_andou = false
	_aplicar()


## Modo automatico com histerese. Sobe assim que a chuva passa do limiar, desce
## so quando ela cai bem abaixo dele.
func _escolher_modo(chuva: float) -> void:
	var alvo := int(modo)
	while alvo < 3 and chuva >= LIGA[alvo + 1]:
		alvo += 1
	while alvo > 0 and chuva < DESLIGA[alvo]:
		alvo -= 1
	if alvo == int(modo):
		return
	if alvo == int(Modo.DESLIGADO):
		# Parou de chover: nao congela no meio do vidro. Mais uma ou duas
		# passadas para secar, e so entao o repouso.
		_finais = PASSADAS_FINAIS
	else:
		_finais = 0
		_pausa = 0.0
	modo = alvo as Modo


func _aplicar() -> void:
	var k := 0.5 - 0.5 * cos(_fase * 0.5 * TAU)
	_ang_agora = deg_to_rad(REPOUSO) + deg_to_rad(CURSO) * k
	for i in _pivos.size():
		# Os dois varrem para o MESMO lado, como num carro de verdade: em
		# espelho eles se cruzariam no meio do vidro. O giro e em torno do Z do
		# pivo, que aqui E a normal do para-brisa.
		#
		# `basis = base * giro`, e nunca `rotation = ...`: o segundo joga fora a
		# orientacao do vidro. Ver `_bases`.
		_pivos[i].basis = _bases[i] * Basis(Vector3(0.0, 0.0, 1.0), _ang_agora)


## O setor varrido neste quadro, para o mapa de agua.
func setor() -> Dictionary:
	if _painel.is_empty() or _indice < 0:
		return {}
	return {
		"ativo": _andou,
		"painel": _indice,
		"pivo_a": _pivo_a,
		"pivo_b": _pivo_b,
		"raios": _raios,
		"ang_de": _ang_antes,
		"ang_ate": _ang_agora,
		"palheta": MEIA_PALHETA,
	}


## A ponta da palheta, em metros no plano do vidro. E o que a sonda do criterio
## C7 mede — ver a memoria do projeto "animacao se mede pela ponta".
func ponta(pivo: Vector2) -> Vector2:
	return pivo + Vector2(sin(_ang_agora), -cos(_ang_agora)) * _raios.y


func pivos() -> Array[Vector2]:
	return [_pivo_a, _pivo_b]


## O leque INTEIRO que as palhetas cobrem no curso todo, em metros do vidro.
##
## Nao e o setor de agora (`setor()`): e o desenho que anos de passada deixam
## na sujeira do vidro, e por isso nao depende de fase nem de modo.
func leque() -> Dictionary:
	if _painel.is_empty():
		return {}
	return {
		"pivo_a": _pivo_a,
		"pivo_b": _pivo_b,
		"raios": _raios,
		"angulos": Vector2(deg_to_rad(REPOUSO) - MEIA_PALHETA,
			deg_to_rad(REPOUSO + CURSO) + MEIA_PALHETA),
	}


func raios() -> Vector2:
	return _raios
