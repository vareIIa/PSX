## O pe do motorista da IA (PLANO_TRANSITO_AAA, Passo 2): quanto acelerar ou
## frear agora. Funcoes puras; quem guarda estado e o `MotoristaIA`.
##
## O que havia antes
## -----------------
## Tres tetos de velocidade `sqrt(2 * 8 * distancia)` — sinal, obstaculo e via
## — e um pedal em degrau: 4,2 m/s2 para acelerar, 8 m/s2 para frear, trocados
## de um quadro para o outro. Medido na bancada: toda parada no sinal era uma
## freada de 0,82 g do comeco ao fim (o carro seguia a toda e freava no ultimo
## instante), e o carro de tras tratava o da frente como parado — seguia a
## 0,82 s de distancia a 40 km/h, onde gente segue a 1,5-2 s.
##
## O que ha agora
## --------------
##   seguir      IIDM (Treiber e Kesting, "Traffic Flow Dynamics", cap. 11): o
##               intervalo desejado, a distancia parada e a velocidade do da
##               frente entram na conta. O "I" corrige o IDM puro, que perto da
##               velocidade desejada deixava buraco de 30 m na fila
##   parar       freada de desaceleracao constante ate o ponto (`para_chegar`),
##               comecada quando a necessaria passa de `Pe.b_inicio`; antes
##               disso so tira o pe (`Pe.alivio`). No fim o motorista alivia o
##               freio (`assentar`), como quem para sem dar tranco
##   pe          o pedal tem curso: a aceleracao muda no maximo `Pe.j_*` por
##               segundo (`com_jerk`). Emergencia e excecao, e nao a regra
##
## Os numeros foram ajustados num prototipo (parada de 11 e de 14 m/s com pico de
## 1,4 m/s2 e o bico a 0,5 m da linha; fila a 1,67 s; onda de freada a 3 m/s2
## amortecendo de carro em carro; partida em cascata) e sao medidos de novo no
## jogo por tests/bancada_transito.gd.
class_name Longitudinal
extends RefCounted


## Os numeros do pe de um motorista. O Passo 5 os tira da ficha de cada um;
## aqui todos tem o do motorista medio, menos o tempo de reacao.
class Pe:
	## Aceleracao maxima e freada confortavel do IIDM, em m/s2.
	var a := 2.0
	var b := 2.2
	## Intervalo desejado atras do da frente, em segundos, e a distancia de
	## para-choque a para-choque parado, em metros.
	var t := 1.5
	var s0 := 2.0
	var delta := 4.0
	## Segundos entre o que o libera (verde, o da frente saindo) e o pe no
	## acelerador.
	var reacao := 0.65
	## Freada necessaria a partir da qual ele comeca a frear para um ponto, e a
	## partir da qual so tira o pe; e quanto o carro perde so tirando o pe.
	var b_inicio := 1.3
	var b_alivio := 0.5
	var alivio := 0.35
	## Onde o bico para: tanto antes da linha, com esta reserva para o alivio
	## final do freio.
	var margem := 0.4
	var reserva := 0.2
	## Curso do pedal, em m/s3: ganhar aceleracao, frear, soltar o freio, e o
	## de emergencia. E a freada que nada no dia a dia deve pedir.
	var j_sobe := 3.0
	var j_freio := 5.0
	var j_solta := 6.0
	var j_emergencia := 30.0
	var b_emergencia := 7.5


## O motorista medio, com o tempo de reacao sorteado pela semente: 0,5 a 0,8 s,
## que e o de quem esta atento ao sinal.
static func pe_de(semente: int) -> Pe:
	var pe := Pe.new()
	var h := float(absi(semente * 2246822519 + 13) % 1000) / 1000.0
	pe.reacao = 0.5 + 0.3 * h
	return pe


## Aceleracao na rua livre, rumo a `v0`. Acima dela o IIDM freia com ate `b`,
## em vez do quase nada do IDM puro.
static func livre(v: float, v0: float, pe: Pe) -> float:
	if v0 <= 0.01:
		return -pe.b
	if v <= v0:
		return pe.a * (1.0 - pow(v / v0, pe.delta))
	return -pe.b * (1.0 - pow(v0 / v, pe.a * pe.delta / pe.b))


## IIDM: a aceleracao atras de alguem a `gap` metros (para-choque a
## para-choque) andando a `v_lider` na mesma direcao. `gap` INF e rua livre.
static func iidm(v: float, v0: float, gap: float, v_lider: float, pe: Pe) -> float:
	var af := livre(v, v0, pe)
	if gap == INF:
		return af
	var dv := v - v_lider
	var desejado := pe.s0 + maxf(0.0, v * pe.t + v * dv / (2.0 * sqrt(pe.a * pe.b)))
	var z := desejado / maxf(gap, 0.01)
	var saida: float
	if v <= v0:
		if z >= 1.0:
			saida = pe.a * (1.0 - z * z)
		elif af < 1e-3:
			saida = af
		else:
			saida = af * (1.0 - pow(z, 2.0 * pe.a / af))
	elif z >= 1.0:
		saida = af + pe.a * (1.0 - z * z)
	else:
		saida = af
	return maxf(saida, -pe.b_emergencia)


## A aceleracao constante que leva de `v` a `v_alvo` em `d` metros. Negativa
## quando e preciso frear.
static func para_chegar(v: float, v_alvo: float, d: float) -> float:
	return (v_alvo * v_alvo - v * v) / (2.0 * maxf(d, 0.05))


## A freada constante que para em `d` metros contando o curso do pedal: a
## freada so chega nela depois de b / j_freio segundos, e nesse tempo o carro
## anda quase metade disso a toda. E o que decide o amarelo — a conta sem o
## curso prometia 3,3 m/s2 a 30 m e a parada saia com 4,3.
static func freada_para_parar(v: float, d: float, pe: Pe) -> float:
	var b := v * v / (2.0 * maxf(d, 0.1))
	for _i in 3:
		var curso := b / pe.j_freio
		b = v * v / (2.0 * maxf(d - v * curso * 0.5, 0.1))
	return b


## O alivio do fim da parada: abaixo de 1,5 m/s o freio vai saindo, e o carro
## para com 0,35 m/s2 em vez de com a freada inteira — sem o tranco para tras
## de quem segura o pedal ate o fim.
##
## A rampa parte da freada em curso (continua em 1,5 m/s) e desce em linha
## reta com a velocidade. Fixa, ela aliviava tanto uma parada de amarelo a
## 3,4 m/s2 quanto uma de 1,4: a forte gastava meio metro a mais que a reserva
## e o carro parava com o bico 0,47 m alem da linha (visto na cidade).
static func assentar(v: float, a_quero: float) -> float:
	if v >= 1.5:
		return a_quero
	var k := maxf(0.4, (-a_quero - 0.35) / 1.5)
	return maxf(a_quero, -(0.35 + k * v))


## Quanto tempo leva para andar `d` metros partindo a `v`, acelerando a `a` ate
## `v_max` e dali em diante constante (Passo 3: a janela de cada carro no
## cruzamento). Parado e sem acelerar, nunca chega: INF.
static func tempo_ate(d: float, v: float, a: float, v_max: float) -> float:
	if d <= 0.0:
		return 0.0
	if a <= 0.0 or v >= v_max:
		return d / v if v > 0.05 else INF
	var d_acc := (v_max * v_max - v * v) / (2.0 * a)
	if d <= d_acc:
		return (sqrt(v * v + 2.0 * a * d) - v) / a
	return (v_max - v) / a + (d - d_acc) / v_max


## Leva a aceleracao atual rumo a pedida, no curso do pedal.
static func com_jerk(a_atual: float, a_quero: float, dt: float, pe: Pe) -> float:
	var j: float
	if a_quero > a_atual:
		j = pe.j_sobe if a_atual >= 0.0 else pe.j_solta
	elif a_quero < -4.5:
		j = pe.j_emergencia
	else:
		j = pe.j_freio
	return move_toward(a_atual, a_quero, j * dt)
