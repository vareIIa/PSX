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
## largura da transversal mais a faixa de pedestre inteira (recuo de 0,25 e
## zebra de 1,5, ChunkBuilder.FAIXA_RECUO e FAIXA_PROFUNDIDADE), meio metro de
## asfalto e a espessura da linha. Com 1,6 a linha caia DENTRO da zebra, colada
## nas barras como um pente, e o carro parava com o bico em cima da faixa.
const FOLGA_RETENCAO := 2.5


# --- o que e dirigivel ------------------------------------------------------

## Viela nao entra. Tres metros de pista, sem poste, e um carro parado ali
## entala a unica passagem escura da cidade — que existe para o pedestre e para
## o clima, e nao para o transito. Continua atalho de gente, como foi decidido
## quando ela foi alargada.
static func dirigivel(v: int) -> bool:
	return v == MalhaUrbana.Via.RUA or v == MalhaUrbana.Via.AVENIDA


## O trecho da linha x = i entre os nos j e j + 1 e dirigivel? Rua ou avenida,
## e nao escadaria (Ladeira): no morro a rua que passa de 20% e degrau de pedra
## com frade na boca, e carro nao entra. Como `proxima_x` e `proxima_z` param no
## primeiro trecho nao dirigivel, a corrida inteira ate o proximo cruzamento sai
## das saidas — nao nasce beco sem retorno para a IA.
static func dirigivel_x(i: int, j: int) -> bool:
	return dirigivel(MalhaUrbana.via_x_em(i, j)) and not Ladeira.escadaria_x(i, j)


## O trecho da linha z = j entre os nos i e i + 1 e dirigivel? Ver `dirigivel_x`.
static func dirigivel_z(j: int, i: int) -> bool:
	return dirigivel(MalhaUrbana.via_z_em(j, i)) and not Ladeira.escadaria_z(j, i)


## Os quatro bracos do no (i, j), cada um dirigivel ou nao. A rua existe por
## trecho (MalhaUrbana.via_x_em): o braco norte e o trecho da linha x = i que
## sai do no para +Z, o sul para -Z, o leste e o trecho da linha z = j para +X e
## o oeste para -X.
static func braco_n(i: int, j: int) -> bool:
	return dirigivel_x(i, j)


static func braco_s(i: int, j: int) -> bool:
	return dirigivel_x(i, j - 1)


static func braco_l(i: int, j: int) -> bool:
	return dirigivel_z(j, i)


static func braco_o(i: int, j: int) -> bool:
	return dirigivel_z(j, i - 1)


## Cruzamento e o no onde uma via dirigivel encontra OUTRA: ao menos um braco em
## cada eixo. Inclui o entroncamento em T — o carro que chega pela rua que
## termina tem de virar, e quem passa pela de cima cruza com ele. Um no so com
## os dois bracos da mesma linha nao e cruzamento: e a rua passando reto por
## onde so uma viela encosta.
##
## Nem o no de dois bracos em eixos diferentes: e a rua dobrando a esquina onde
## a outra metade virou escadaria (Ladeira). Ali ninguem cruza com ninguem, e
## zebra, PARE e linha de retencao numa curva sao erro. O trecho ate ela fica
## sem transito da IA (vira beco para `proxima_x/z`); o jogador passa.
static func existe_cruzamento(i: int, j: int) -> bool:
	var n := braco_n(i, j)
	var s := braco_s(i, j)
	var l := braco_l(i, j)
	var o := braco_o(i, j)
	if not ((n or s) and (l or o)):
		return false
	return int(n) + int(s) + int(l) + int(o) >= 3


## Que eixo tem a preferencia no cruzamento SEM semaforo (Semaforo.tem_sinal).
##
## No entroncamento em T, a rua que segue reto: quem chega pela que termina
## para no PARE. No cruzamento de quatro bracos, a avenida — que la sempre tem
## semaforo, entao na pratica e rua com rua — e, entre duas ruas, um sorteio
## fixo por esquina: a rua preferencial muda de uma esquina para a outra, como
## em qualquer cidade pequena, e o motorista aprende pela placa.
static func preferencial(i: int, j: int) -> int:
	var passa_x := braco_n(i, j) and braco_s(i, j)
	var passa_z := braco_l(i, j) and braco_o(i, j)
	if passa_x and not passa_z:
		return 0
	if passa_z and not passa_x:
		return 1
	if MalhaUrbana.via_x(i) == MalhaUrbana.Via.AVENIDA:
		return 0
	if MalhaUrbana.via_z(j) == MalhaUrbana.Via.AVENIDA:
		return 1
	return MalhaUrbana._ruido(i, j, 881) % 2


## A classe de rolamento da linha: avenida se a linha e de avenida, rua se nao.
##
## Trecho dirigivel de linha que nao e de avenida e sempre RUA (a viela nao e
## dirigivel), entao a faixa do carro se resolve pela linha, sem saber o trecho.
static func classe_x(i: int) -> int:
	return MalhaUrbana.Via.AVENIDA if MalhaUrbana.via_x(i) == MalhaUrbana.Via.AVENIDA \
		else MalhaUrbana.Via.RUA


static func classe_z(j: int) -> int:
	return MalhaUrbana.Via.AVENIDA if MalhaUrbana.via_z(j) == MalhaUrbana.Via.AVENIDA \
		else MalhaUrbana.Via.RUA


## Meia largura da pista de cada eixo, ja resolvida.
static func meia_x(i: int) -> float:
	return MalhaUrbana.meia_pista(classe_x(i))


static func meia_z(j: int) -> float:
	return MalhaUrbana.meia_pista(classe_z(j))


## Meia largura do asfalto de cada linha NO no (i, j): o maior dos dois bracos,
## viela inclusive. A zebra e o semaforo ficam alem dela.
static func meia_asfalto_x_no(i: int, j: int) -> float:
	return maxf(MalhaUrbana.meia_asfalto(MalhaUrbana.via_x_em(i, j)),
		MalhaUrbana.meia_asfalto(MalhaUrbana.via_x_em(i, j - 1)))


static func meia_asfalto_z_no(i: int, j: int) -> float:
	return maxf(MalhaUrbana.meia_asfalto(MalhaUrbana.via_z_em(j, i)),
		MalhaUrbana.meia_asfalto(MalhaUrbana.via_z_em(j, i - 1)))


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
	return Vector3(x, Relevo.altura(x, z), z)


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

## Proximo cruzamento andando em X pela linha z = j, a partir do no i.
##
## Anda trecho a trecho enquanto a via existir, e para no primeiro no que for
## cruzamento. Devolve `i` quando o primeiro trecho ja nao e dirigivel: e o fim
## da rua, e quem chamou trata como beco.
static func proxima_x(i: int, j: int, sentido: int) -> int:
	var k := i
	for _passo in range(1, ALCANCE):
		var trecho_i := k if sentido > 0 else k - 1
		if not dirigivel_z(j, trecho_i):
			return i
		k += sentido
		if existe_cruzamento(k, j):
			return k
	return i


## Proximo cruzamento andando em Z pela linha x = i, a partir do no j.
static func proxima_z(j: int, i: int, sentido: int) -> int:
	var k := j
	for _passo in range(1, ALCANCE):
		var trecho_j := k if sentido > 0 else k - 1
		if not dirigivel_x(i, trecho_j):
			return j
		k += sentido
		if existe_cruzamento(i, k):
			return k
	return j


## O proximo cruzamento seguindo `t` a partir de (i, j). Devolve o proprio
## cruzamento quando a via acaba, e quem chamou trata como beco.
static func proximo_cruzamento(i: int, j: int, t: Vector4i) -> Vector2i:
	if t.z == 0:
		return Vector2i(i, proxima_z(j, i, t.w))
	return Vector2i(proxima_x(i, j, t.w), j)


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
		p.y = Relevo.altura(p.x, p.z)
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
	# O trecho em que o ponto esta, em cada eixo.
	var linha_j := floori(pos.z / TAM)
	var linha_i := floori(pos.x / TAM)
	for di in range(-1, 2):
		var i := i0 + di
		if not dirigivel_x(i, linha_j):
			continue
		if absf(pos.x - float(i) * TAM) <= meia_x(i):
			return true
	for dj in range(-1, 2):
		var j := j0 + dj
		if not dirigivel_z(j, linha_i):
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
