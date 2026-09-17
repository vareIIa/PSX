## As pocas de agua da Estrada Velha, e quem sabe dizer onde elas estao.
##
## Por que a `Pocas` da cidade nao serve
## -------------------------------------
## Ela responde a pergunta "esta celula da grade cai sobre asfalto?" perguntando
## a `MalhaUrbana`, e poe o decal em `y = 0,02`. Nenhuma das duas coisas existe
## aqui: a estrada nao passa pelo ChunkManager, nao tem grade nenhuma, e o chao
## dela e uma FUNCAO de `s` montada quatro mil metros acima da cidade. Apontar a
## Pocas para ca daria vinte decais no asfalto da cidade, debaixo do mundo.
##
## O que as duas dividem e a APARENCIA — a mancha e a rugosidade saem de
## `Pocas.textura_albedo()` e `Pocas.textura_orm()`, para nao existirem duas
## aguas com dois brilhos no mesmo jogo.
##
## A poca e uma FUNCAO, como a estrada
## -----------------------------------
## `poca_da_celula(i)` responde "ha poca aqui, e onde" sem que nada esteja
## montado, do mesmo jeito que `EstradaBuilder.ponto_em` responde onde a estrada
## esta. Isso importa porque DOIS interessados fazem essa pergunta e eles nao
## podem discordar: este no, que materializa o decal, e o `SprayEstrada`, que
## precisa saber se a roda entrou numa para jogar agua. Com uma lista guardada,
## o carro espirraria onde nao ha poca no quadro seguinte a um descarregamento.
##
## Dentro da TRILHA, sempre
## ------------------------
## Agua de estrada de terra nao empoca no meio: empoca no sulco que o pneu
## cavou, que e o ponto mais fundo do perfil (`KitEstrada.sulco`). E por isso que
## o carro passa por cima delas sem desviar — ele anda justamente onde elas
## estao. Poca sorteada no leito inteiro ficaria metade fora da trilha, e o carro
## passaria ao lado da agua a cena toda.
class_name PocasEstrada
extends Node3D

## Comprimento da celula ao longo da estrada, em metros. Uma poca por celula, no
## maximo. Sete metros dao uma poca a cada dois segundos e meio a 68 km/h — ritmo
## de estrada castigada, sem virar um rosario de espelhos.
const PASSO_S := 7.0
## Fracao das celulas que tem poca.
const CHANCE := 0.62
## Meio comprimento e meia largura da poca, em metros. Ela e COMPRIDA: agua
## parada num sulco toma a forma do sulco, e um disco redondo no meio da trilha
## le como mancha de tinta.
const MEIA_LARGURA := Vector2(0.34, 0.52)
const MEIO_COMPRIMENTO := Vector2(0.9, 2.4)
## Ate onde as pocas sao materializadas, em metros a frente e atras do alvo.
const ADIANTE := 70.0
const ATRAS := 22.0
## Decais no pool.
const MAX := 22
## Abaixo deste molhado nao ha poca nenhuma: a agua empoca DEPOIS de a superficie
## encharcar, nao junto. Mesma regra da `Pocas`.
const LIMIAR := 0.35
## Altura da caixa do decal. So precisa cobrir o sulco e a coroa da pista.
const ALTURA_CAIXA := 0.55
## Passo da reavaliacao, em segundos.
const PASSO := 0.25

## Onde o carro esta na estrada, em metros. Quem monta a cena escreve isto.
var distancia: float = 0.0

## Onde a roda PASSA, medido do eixo da estrada. E onde a agua junta.
##
## Nao e `KitEstrada.TRILHA` (±1,10), e a diferenca nao e detalhe: aquele e o
## centro do sulco DESENHADO, e o sulco desenhado tem 2,20 m entre os dois
## centros enquanto o Marea tem 1,42 m de bitola. Poca no centro do sulco
## esquerdo cobre de -1,60 a -0,60 e a roda esquerda do carro passa em -0,55:
## ela erraria a agua por cinco centimetros, a cena inteira, e o pedido desta
## cena e justamente o carro passando POR CIMA da poca.
##
## O fundo chato do sulco vai de 0,58 a 1,62 m do eixo (ver `KitEstrada.sulco`),
## entao os dois caminhos de roda caem dentro dele de qualquer jeito — a agua
## continua no ponto mais fundo do perfil. So o CENTRO dela muda.
##
## O padrao e o do Marea desta cena; quem monta escreve os numeros do carro que
## for usar, e o `SprayEstrada` le desta mesma lista, para os dois nunca
## discordarem sobre onde ha agua.
var trilhas := PackedFloat32Array([-0.55, 0.87])

var _pool: Array[Decal] = []
var _relogio: float = PASSO


func _ready() -> void:
	for i in MAX:
		var d := Decal.new()
		d.texture_albedo = Pocas.textura_albedo()
		d.texture_orm = Pocas.textura_orm()
		# Os mesmos numeros da poca da cidade: a agua ESCURECE o que esta
		# embaixo e deixa aparecer, em vez de cobrir com pigmento.
		d.albedo_mix = 0.62
		d.upper_fade = 0.5
		d.lower_fade = 0.35
		d.distance_fade_enabled = true
		d.distance_fade_begin = 44.0
		d.distance_fade_length = 20.0
		d.visible = false
		add_child(d)
		_pool.append(d)


## A poca desta celula: (s, deslocamento lateral, meia largura, meio
## comprimento). Meia largura 0 significa "nao ha poca aqui".
##
## Sem estado guardado: e a mesma resposta em toda execucao e em toda
## maquina, que e o que permite o decal e o espirro da roda concordarem sobre a
## mesma agua sem trocarem uma palavra.
func poca_da_celula(i: int) -> Vector4:
	var h := _hash(i)
	if _frac(h) > CHANCE:
		return Vector4.ZERO
	if trilhas.is_empty():
		return Vector4.ZERO
	var s := (float(i) + 0.5 + (_frac(h * 7.13) - 0.5) * 0.7) * PASSO_S
	# Uma trilha ou a outra, nunca as duas: agua junta na que esta mais funda, e
	# as duas trilhas de uma estrada nunca estao igualmente cavadas.
	var t := int(_frac(h * 3.71) * float(trilhas.size())) % trilhas.size()
	var e := trilhas[t] + (_frac(h * 5.29) - 0.5) * 0.30
	var meia_l := lerpf(MEIA_LARGURA.x, MEIA_LARGURA.y, _frac(h * 11.37))
	var meio_c := lerpf(MEIO_COMPRIMENTO.x, MEIO_COMPRIMENTO.y, _frac(h * 13.71))
	return Vector4(s, e, meia_l, meio_c)


## A roda que esta em (`s`, `e`) esta dentro de uma poca? Devolve o quanto, de 0
## a 1, para o espirro ter forca em vez de ser um interruptor.
##
## As celulas vizinhas entram na conta porque a poca e comprida — ate 4,8 m — e
## uma celula tem 7: uma poca que nasce no fim da celula invade a seguinte, e
## perguntar so a celula da roda perderia metade da agua que ela atravessa.
func mergulho(s: float, e: float) -> float:
	var melhor := 0.0
	var i := floori(s / PASSO_S)
	for k in [i - 1, i, i + 1]:
		var p := poca_da_celula(k)
		if p.z <= 0.0:
			continue
		var ds := absf(s - p.x) / p.w
		var de := absf(e - p.y) / p.z
		if ds >= 1.0 or de >= 1.0:
			continue
		# Mais forte no meio da poca do que na beira dela: a roda entra, levanta
		# a agua toda no centro e sai. Sem esta rampa o espirro liga e desliga em
		# degrau, e degrau em particula le como falha de emissao.
		melhor = maxf(melhor, (1.0 - ds * ds) * (1.0 - de * de))
	return melhor


## Altura da superficie do leito em (`s`, `e`), em coordenada local da estrada.
##
## A mesma conta de `EstradaBuilder`, e ela precisa ser a mesma: a poca pousada
## no eixo cru fica ate quinze centimetros no ar, porque a trilha e justamente o
## ponto mais fundo do perfil. `ondulacao` e lida no EIXO, como em `leito` — lida
## no ponto deslocado ela devolve outro numero e a lamina desencosta de novo.
static func altura_do_leito(s: float, e: float) -> float:
	var eixo := EstradaBuilder.ponto_em(s)
	return eixo.y + KitEstrada.altura_da_pista(eixo, e)


func _process(delta: float) -> void:
	_relogio += delta
	if _relogio < PASSO:
		return
	_relogio = 0.0
	_reavaliar()


func _reavaliar() -> void:
	# Decal nao desenha fora do Forward+, e no PS1 STYLE a superficie nem tem
	# specular para a poca conversar. Nos dois casos, sumir e mais honesto do que
	# desenhar algo que ninguem ve. Mesma regra da `Pocas`.
	var forca := Clima.molhado_visivel() if Settings.luz_por_pixel else 0.0
	if forca < LIMIAR:
		for d: Decal in _pool:
			d.visible = false
		return

	var escala := 0.66 + 0.34 * inverse_lerp(LIMIAR, 1.0, forca)
	var i0 := floori((distancia - ATRAS) / PASSO_S)
	var i1 := ceili((distancia + ADIANTE) / PASSO_S)
	var usados := 0
	for i in range(i0, i1 + 1):
		if usados >= MAX:
			break
		var p := poca_da_celula(i)
		if p.z <= 0.0:
			continue
		var d := _pool[usados]
		usados += 1
		var centro := EstradaBuilder.ponto_em(p.x)
		var lado := EstradaBuilder.lado_em(p.x)
		var pos := centro + lado * p.y
		# `ponto_em` ja devolve o `y` do relevo; a altura do leito soma a
		# ondulacao e o sulco por cima dele, entao o `y` do ponto sai da conta
		# para nao entrar duas vezes.
		pos.y = altura_do_leito(p.x, p.y)
		d.position = pos
		var dir := EstradaBuilder.direcao_em(p.x)
		d.rotation = Vector3(0.0, atan2(dir.x, dir.z), 0.0)
		d.size = Vector3(p.z * 2.0 * escala, ALTURA_CAIXA, p.w * 2.0 * escala)
		d.modulate = Color(1.0, 1.0, 1.0, clampf(forca * 1.15, 0.0, 1.0))
		d.visible = true

	for k in range(usados, MAX):
		_pool[k].visible = false


static func _hash(a: int) -> float:
	var n := a * 374761393 + 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return float(absi(n ^ (n >> 16)) % 1000003) / 1000003.0


static func _frac(v: float) -> float:
	return v - floorf(v)
