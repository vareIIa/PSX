## A malha de rolamento: por onde um carro pode andar, em que faixa e para que
## lado.
##
## Mesma ideia de Rotas, do outro lado do meio-fio. Rotas le a grade de ruas de
## MalhaUrbana e devolve a linha de marcha do pedestre; Vias le a MESMA grade e
## devolve a linha do carro. Nenhuma das duas guarda nada: sao funcoes puras da
## coordenada, entao a cidade nao precisa ser assada, nao entra no save e o
## trecho a trezentos metros daqui responde igual sem existir.
##
## Convencao de eixo, que e a coisa mais facil de errar aqui
## ---------------------------------------------------------
## `MalhaUrbana.via_x(i)` e a via que CORRE SOBRE a linha x = i * 32. Ela corre,
## portanto, ao longo do eixo Z. O nome fala da linha, nao da direcao de quem
## anda nela. Por isso, neste arquivo:
##
##   eixo 0   o carro anda em Z, na via da linha x = i * 32   (via_x)
##   eixo 1   o carro anda em X, na via da linha z = j * 32   (via_z)
##
## Mao de direcao
## --------------
## Brasil, mao inglesa nao. Quem anda mantem a DIREITA. Com Y para cima e a
## direita valendo `frente x cima`:
##
##   andando para +Z  a direita e -X    -> a faixa fica em x = i*32 - meia/2
##   andando para +X  a direita e +Z    -> a faixa fica em z = j*32 + meia/2
##
## A troca de sinal entre os dois eixos nao e engano: e o que a regra da direita
## produz num sistema destro. Quem mexer nisto e inverter um dos dois vai ver os
## carros passando um dentro do outro nos cruzamentos, e so ali.
class_name Vias
extends RefCounted

const TAM := MalhaUrbana.TAM

## Ate onde procurar a proxima linha de rua dirigivel. Uma faixa sem secundaria
## da a quadra de 160 m, ou cinco chunks; o dobro e folga.
const ALCANCE := 12

## Meia largura de uma faixa, para o carro nao nascer colado no meio-fio.
const MEIA_FAIXA := 0.5

## Onde fica a linha de retencao, contada do centro do cruzamento. E a meia
## largura da transversal mais uma folga de para-choque.
const FOLGA_RETENCAO := 1.6


# --- o que e dirigivel ------------------------------------------------------

## Viela nao entra. Tres metros de pista, sem poste, e um carro parado ali
## entala a unica passagem escura da cidade — que existe para o pedestre e para
## o clima, e nao para o transito. Continua atalho de gente, como foi decidido
## quando ela foi alargada.
static func dirigivel(v: int) -> bool:
	return v == MalhaUrbana.Via.RUA or v == MalhaUrbana.Via.AVENIDA


static func existe_x(i: int) -> bool:
	return dirigivel(MalhaUrbana.via_x(i))


static func existe_z(j: int) -> bool:
	return dirigivel(MalhaUrbana.via_z(j))


static func existe_cruzamento(i: int, j: int) -> bool:
	return existe_x(i) and existe_z(j)


## Meia largura da pista de cada eixo, ja resolvida.
static func meia_x(i: int) -> float:
	return MalhaUrbana.meia_pista(MalhaUrbana.via_x(i))


static func meia_z(j: int) -> float:
	return MalhaUrbana.meia_pista(MalhaUrbana.via_z(j))


## Quantas faixas de rolamento a via tem por sentido. A avenida tem 4,5 m de
## meia pista e cabem duas; a rua tem 3,0 e cabe uma. Isto muda o transito mais
## do que parece: e na avenida que da para ultrapassar quem parou.
static func faixas(v: int) -> int:
	return 2 if v == MalhaUrbana.Via.AVENIDA else 1


# --- geometria da faixa -----------------------------------------------------

## Coordenada X da faixa de quem anda no eixo Z pela linha `i`.
##
## `sentido` e +1 para +Z e -1 para -Z. `faixa` e 0 para a de fora (a mais perto
## do meio-fio) e 1 para a de dentro, que so existe na avenida.
static func linha_x(i: int, sentido: int, faixa: int = 0) -> float:
	var meia := meia_x(i)
	var n := faixas(MalhaUrbana.via_x(i))
	var largura := meia / float(n)
	var f := clampi(faixa, 0, n - 1)
	# Do meio-fio para o meio da rua: a faixa 0 encosta na borda.
	var desloca := largura * (float(f) + 0.5)
	return float(i) * TAM - float(sentido) * (meia - desloca)


## Coordenada Z da faixa de quem anda no eixo X pela linha `j`.
static func linha_z(j: int, sentido: int, faixa: int = 0) -> float:
	var meia := meia_z(j)
	var n := faixas(MalhaUrbana.via_z(j))
	var largura := meia / float(n)
	var f := clampi(faixa, 0, n - 1)
	var desloca := largura * (float(f) + 0.5)
	return float(j) * TAM + float(sentido) * (meia - desloca)


## Vetor unitario da direcao de um trecho.
static func direcao(eixo: int, sentido: int) -> Vector3:
	return (Vector3(0.0, 0.0, float(sentido)) if eixo == 0
		else Vector3(float(sentido), 0.0, 0.0))


## O ponto por onde o carro passa ao cruzar (i, j) vindo do trecho `de` e
## seguindo no trecho `para`.
##
## E o cruzamento das duas linhas de faixa, e nao o centro do cruzamento. Por
## isso a curva sai fechada e do lado certo em vez de cortar a contramao: quem
## entra pela faixa da direita sai pela faixa da direita da outra rua, e o ponto
## de pivo e exatamente onde as duas se encontram.
##
## Seguindo reto, o trecho de chegada e o mesmo do de saida, e a formula devolve
## a faixa atual cruzando o eixo do cruzamento — que e o que se quer.
static func ponto_de_curva(i: int, j: int, de: Vector4i, para: Vector4i) -> Vector3:
	var x := float(i) * TAM
	var z := float(j) * TAM
	if de.z == 0:
		x = linha_x(i, de.w, de.x)
	elif para.z == 0:
		x = linha_x(i, para.w, para.x)
	if de.z == 1:
		z = linha_z(j, de.w, de.x)
	elif para.z == 1:
		z = linha_z(j, para.w, para.x)
	return Vector3(x, 0.0, z)


## Um trecho e `Vector4i(faixa, 0, eixo, sentido)`. O segundo campo fica livre
## de proposito: Vector4i e o tipo que o resto do projeto ja usa para no de
## grafo e trocar por Dictionary aqui custaria alocacao por quadro.
static func trecho(eixo: int, sentido: int, faixa: int = 0) -> Vector4i:
	return Vector4i(faixa, 0, eixo, sentido)


static func trecho_eixo(t: Vector4i) -> int:
	return t.z


static func trecho_sentido(t: Vector4i) -> int:
	return t.w


static func trecho_faixa(t: Vector4i) -> int:
	return t.x


# --- navegacao --------------------------------------------------------------

static func proxima_x(i: int, sentido: int) -> int:
	for passo in range(1, ALCANCE):
		var k := i + sentido * passo
		if existe_x(k):
			return k
	return i


static func proxima_z(j: int, sentido: int) -> int:
	for passo in range(1, ALCANCE):
		var k := j + sentido * passo
		if existe_z(k):
			return k
	return j


## O proximo cruzamento seguindo `t` a partir de (i, j). Devolve o proprio
## cruzamento quando a via acaba, e quem chamou trata como beco.
static func proximo_cruzamento(i: int, j: int, t: Vector4i) -> Vector2i:
	if t.z == 0:
		return Vector2i(i, proxima_z(j, t.w))
	return Vector2i(proxima_x(i, t.w), j)


## As saidas legais de um cruzamento para quem chegou pelo trecho `de`.
##
## Nao ha retorno: dar meia volta no meio do cruzamento e o movimento que faz
## um transito procedural parecer errado mais depressa que qualquer outro, e
## nenhum motorista faz isso numa rua vazia.
##
## A ordem e seguir reto, virar, virar — e quem escolhe pesa a primeira, senao
## os carros ficam girando na mesma quadra a noite inteira.
static func saidas(i: int, j: int, de: Vector4i) -> Array[Vector4i]:
	var saida: Array[Vector4i] = []
	var reto := proximo_cruzamento(i, j, de)
	if reto != Vector2i(i, j):
		saida.append(de)
	# Virar troca de eixo. A faixa vai para a de fora: entrar numa avenida pela
	# faixa de dentro exigiria mudar de faixa dentro do cruzamento.
	var outro_eixo := 1 - de.z
	for s: int in [1, -1]:
		var t := trecho(outro_eixo, s, 0)
		if proximo_cruzamento(i, j, t) != Vector2i(i, j):
			saida.append(t)
	# Na avenida, a faixa interna e saida legal em linha reta: um carro parado na
	# de fora nao precisa entupir a via inteira.
	if reto != Vector2i(i, j):
		var via := (MalhaUrbana.via_x(i) if de.z == 0 else MalhaUrbana.via_z(j))
		if faixas(via) > 1:
			var outra := 1 - clampi(de.x, 0, 1)
			saida.append(trecho(de.z, de.w, outra))
	return saida


## Cruzamento mais proximo de um ponto, e a linha de grade correspondente.
static func cruzamento_mais_proximo(pos: Vector3) -> Vector2i:
	var ci := roundi(pos.x / TAM)
	var cj := roundi(pos.z / TAM)
	var melhor := Vector2i(ci, cj)
	var melhor_d := INF
	for di in range(-3, 4):
		for dj in range(-3, 4):
			var i := ci + di
			var j := cj + dj
			if not existe_cruzamento(i, j):
				continue
			var d := Vector2(float(i) * TAM - pos.x, float(j) * TAM - pos.z).length()
			if d < melhor_d:
				melhor_d = d
				melhor = Vector2i(i, j)
	return melhor


## Trechos de rua perto do jogador, para o transito saber onde por um carro.
##
## Devolve pontos NO MEIO do quarteirao, e nao so nos cruzamentos: as ruas ficam
## a 32 m umas das outras e, esperando cruzamento, um carro so nasceria a cada
## trinta metros de caminhada. Mesma razao pela qual Rotas.trechos_perto existe
## para os pedestres.
const PASSO_AMOSTRA := 11.0

static func trechos_perto(centro: Vector3, minimo: float,
		maximo: float) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var alcance := ceili(maximo / TAM) + 1
	var ci := roundi(centro.x / TAM)
	var cj := roundi(centro.z / TAM)

	for di in range(-alcance, alcance + 1):
		for dj in range(-alcance, alcance + 1):
			var i := ci + di
			var j := cj + dj
			if not existe_cruzamento(i, j):
				continue
			for eixo: int in [0, 1]:
				for sentido: int in [1, -1]:
					var via := (MalhaUrbana.via_x(i) if eixo == 0 else MalhaUrbana.via_z(j))
					for f in faixas(via):
						var t := trecho(eixo, sentido, f)
						var ate := proximo_cruzamento(i, j, t)
						if ate == Vector2i(i, j):
							continue
						_amostrar(saida, centro, minimo, maximo, i, j, ate, t)
	return saida


static func _amostrar(saida: Array[Dictionary], centro: Vector3, minimo: float,
		maximo: float, i: int, j: int, ate: Vector2i, t: Vector4i) -> void:
	var a := ponto_de_curva(i, j, t, t)
	var b := ponto_de_curva(ate.x, ate.y, t, t)
	var comprimento := a.distance_to(b)
	if comprimento < 1.0:
		return
	var passos := maxi(1, int(comprimento / PASSO_AMOSTRA))
	for k in range(1, passos):
		var p := a.lerp(b, float(k) / float(passos))
		var d := Vector2(p.x - centro.x, p.z - centro.z).length()
		if d < minimo or d > maximo:
			continue
		saida.append({
			"ponto": p,
			"de": Vector2i(i, j),
			"para": ate,
			"trecho": t,
		})


# --- asfalto vs calcada -----------------------------------------------------

## O pe esta na pista (asfalto), e nao na calcada?
##
## Distancia ao eixo da via: dentro da meia_pista e asfalto; alem do meio-fio e
## calcada. Pedestre na calcada nao deve levar buzina de susto.
static func no_asfalto(pos: Vector3) -> bool:
	var i0 := roundi(pos.x / TAM)
	var j0 := roundi(pos.z / TAM)
	for di in range(-1, 2):
		var i := i0 + di
		if not existe_x(i):
			continue
		if absf(pos.x - float(i) * TAM) <= meia_x(i):
			return true
	for dj in range(-1, 2):
		var j := j0 + dj
		if not existe_z(j):
			continue
		if absf(pos.z - float(j) * TAM) <= meia_z(j):
			return true
	return false


# --- movimento do distrito --------------------------------------------------

## Quanto transito este cruzamento merece, de 0 a 1.
##
## Mesma curva de Rotas.movimento e pelo mesmo motivo: a cidade tem de mudar de
## carater quando o jogador anda. Comercio cheio, industrial parado de noite,
## baldio quase deserto. A avenida sempre pesa mais que a rua, porque e ela que
## o jogador ve de longe.
static func movimento(i: int, j: int) -> float:
	var d := MalhaUrbana.distrito_de(i, j)
	var base := 0.55
	match d:
		MalhaUrbana.Distrito.COMERCIAL:
			base = 1.0
		MalhaUrbana.Distrito.RESIDENCIAL:
			base = 0.62
		MalhaUrbana.Distrito.INDUSTRIAL:
			base = 0.45
		MalhaUrbana.Distrito.BALDIO:
			base = 0.22
	var avenida := (MalhaUrbana.via_x(i) == MalhaUrbana.Via.AVENIDA
		or MalhaUrbana.via_z(j) == MalhaUrbana.Via.AVENIDA)
	return clampf(base * (1.25 if avenida else 0.85), 0.0, 1.0)
