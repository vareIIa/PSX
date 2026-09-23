## O motor do carro, como maquina e nao como numero.
##
## Por que isto deixou de ser uma constante
## ----------------------------------------
## Antes o carro do jogador tinha UMA forca de motor: `engine_force = 240 *
## acelerador`. Isso nao e um motor, e uma mola. Tres coisas que todo mundo
## reconhece num carro somem com essa conta:
##
##   a marcha nao significa nada   a forca e a mesma na primeira e na quinta,
##                                 entao o carro acelera igual a 10 e a 100 km/h
##   nao ha rotacao                o giro nao existe como grandeza, so como um
##                                 numero derivado da velocidade para o som
##   nao ha corte                  sem giro nao ha limite de giro, e sem limite
##                                 nao ha o tranco que o ouvido reconhece
##
## Aqui existe rotacao de verdade. O giro sai da velocidade da roda pela relacao
## da marcha, a forca sai de uma CURVA de torque naquele giro, e a forca na roda
## e o torque multiplicado pela mesma relacao. E o que faz a primeira empurrar e
## a quinta so segurar, que e a diferenca inteira entre dirigir e deslizar.
##
## Por que nao e um Node
## ---------------------
## Porque e funcao pura de estado, e por isso da para testar sem montar cidade,
## sem fisica e sem janela. O carro alimenta com acelerador e velocidade de roda
## e le giro, marcha e forca. Quem desenha o painel le daqui tambem, entao o
## ponteiro nunca discorda do que a roda esta fazendo.
class_name Motor
extends RefCounted

# --- o que vem da ficha do carro --------------------------------------------
#
# Estes eram `const`. Deixaram de ser porque todo carro da cidade usava os
# MESMOS, e ai o Fusca acelerava como o Marea. Os valores abaixo sao os do sedan
# de referencia e valem enquanto ninguem chamar `configurar` — ver
# `src/world/ficha_tecnica.gd`.

var relacoes: Array[float] = FichaTecnica.RELACOES_PADRAO.duplicate()
var diferencial: float = 4.06
var torque_pico: float = FichaTecnica.TORQUE_REF

## Marcha lenta. Abaixo disto o motor morreria, e a embreagem patina para
## impedir — que e o que se ouve quando um carro sai do sinal.
var giro_lenta: float = 820.0
## Onde o corte de giro entra. O motor para de dar faisca aqui e volta um
## instante depois; repetindo, e o "ta-ta-ta" de quem segurou o pe no fundo.
var giro_corte: float = 6500.0
## Fim do mostrador, e onde a zona vermelha comeca. O painel le os dois daqui,
## entao o conta-giros de um Fusca marca ate 5000 e o de um Marea ate 7500.
var giro_fundo: float = 7000.0
var giro_vermelho: float = 5900.0
## Giro em que o cambio sobe com o pe no fundo. Abaixo do corte de proposito: um
## automatico bem ajustado troca ANTES de bater no limitador.
var troca_sobe: float = 6050.0

## Marcha a re. Mais curta que a primeira, como em todo cambio real.
const RELACAO_RE := 3.18
## Perda entre virabrequim e pneu. 8% e o que uma transmissao come.
const EFICIENCIA := 0.92

## Com pe leve ele troca cedo, como um automatico anda na cidade. E uma FRACAO
## do corte, e nao um numero absoluto: num motor que gira ate 4700 trocar a 2900
## seria trocar quase no fim da faixa.
##
## 0,33 e baixo de proposito, e o numero veio de uma medida. Com 0,45 a perua e o
## taxi NUNCA engatavam a quinta: a marcha de cima so entra quando o giro na de
## baixo chega ao ponto, e nos dois o ponto caia acima da velocidade que eles
## alcancam. Uma quinta que nunca entra e uma relacao morta na tabela, e o carro
## anda a vida inteira em quarta a giro alto.
const TROCA_LEVE_DO_CORTE := 0.33

## Quao depressa o ponto de troca sobe com o pedal.
##
## Nao e reta. Pedal e uma grandeza que o pe usa quase todo na primeira metade:
## 45% de acelerador nao e "meia pressa", e andar na cidade. Com interpolacao
## reta, 45% ja pedia troca a giro alto e o carro cruzava rosnando. O expoente
## empurra a curva para baixo onde o pe mora.
const CURVA_DO_PEDAL := 1.8
## Giro abaixo do qual ele reduz, tambem como fracao do corte. A folga entre
## subir e descer e o que impede o cambio de oscilar na mesma ladeira.
const TROCA_DESCE_DO_CORTE := 0.24

## O cambio le a VONTADE do motorista, e nao o pedal deste quadro.
##
## O jogador reportou (22/09/2026): "se acelerar ele ja pula pra quarta". A
## `tests/bancada_cambio.gd` montou a queixa: com o W tocado como se dirige na
## cidade (0,35 s pisado, 0,25 s solto), o sedan terminava em QUARTA a 47 km/h,
## onde o pe no fundo usaria a primeira. O cambio lia o pedal cru, e cada soltura
## de um quarto de segundo baixava o ponto de troca para 33% do corte: o giro
## estava acima, ele subia uma marcha, e na soltura seguinte subia outra. Tirar o
## pe de vez fazia o mesmo em cascata — 1, 2, 3 em um segundo e meio —, e pisar
## de novo nao reduzia nada: o giro voltava a 2000 rpm, sem forca, porque a unica
## reducao era a de giro quase morto.
##
## Um automatico de verdade guarda a intencao: ela sobe junto com o pe e desce
## devagar quando ele sai. E essa memoria que decide o ponto de troca. Subir e
## quase instantaneo (pisar e pedir forca agora); descer leva pouco mais de um
## segundo do fundo ao zero, entao a soltura curta do teclado nao muda a marcha
## e a soltura longa — a do motorista que tirou o pe para seguir devagar — muda.
const VONTADE_SOBE := 6.0
const VONTADE_DESCE := 0.6
## Com o pe fora, o cambio SEGURA a marcha: e o freio motor para a curva e a
## marcha certa na saida dela. So sobe quando a vontade ja caiu abaixo disto —
## o motorista que tirou o pe e seguiu devagar — ou para nao passar do corte.
const VONTADE_SEGURA := 0.15
## A reducao e o espelho da subida: o ponto de descer e esta fracao do ponto de
## subir da vontade de agora, e nunca abaixo de `TROCA_DESCE_DO_CORTE`. Com o pe
## no fundo o sedan reduz abaixo de uns 3000 rpm — kickdown —; com o pe leve,
## so perto da lenta, como antes.
const DESCE_DO_PONTO := 0.5
## A marcha de baixo so e escolhida se o giro nela ficar abaixo desta fracao do
## ponto de subir. Sem esta folga ela reduzia e subia de novo no quadro seguinte.
const FOLGA_REDUCAO := 0.92
## Espera depois de uma reducao por kickdown. Mais curta que a de troca comum:
## o motorista pisou, e o automatico que demora meio segundo para reagir e o que
## se sente como carro "morto".
const ESPERA_KICKDOWN := 0.3
## Depois de subir, a reducao por kickdown fica travada este tempo — so a de
## giro morrendo passa. Com o pedal tendo curso (`Carro.PEDAL_SOBE`), o W tocado
## fazia o cambio cacar 1-2-1-2: subia no meio da soltura, e a pisada seguinte
## ja era kickdown. A picape trocou nove vezes em oito segundos e meio.
const TRAVA_REDUCAO := 1.2
## O pe esta SAINDO quando o pedal fica esta fracao abaixo da vontade. Nessa
## hora o cambio nao sobe: quem esta aliviando para a curva nao quer marcha
## mais longa, quer a mesma, e quem so tocou a tecla vai pisar de novo.
const ALIVIANDO := 0.25

## Embreagem aberta na troca. E o silencio de forca que o ouvido le como troca.
const TEMPO_TROCA := 0.26
## Quanto a faisca fica cortada de cada vez no limitador.
const TEMPO_CORTE := 0.07
## Tempo minimo entre duas trocas. Sem isto, uma ladeira com o pe oscilando faz
## o cambio subir e descer dez vezes por segundo.
const ESPERA_TROCA := 0.55

## Quao depressa o giro cai com a embreagem ABERTA — entre duas marchas, e com o
## motor desligado —, em rpm por segundo.
##
## Nao existe a constante irma de subida livre, e a ausencia dela e a correcao:
## este cambio nao tem ponto morto. O motor so sobe de giro atrelado a roda ou
## patinando a embreagem contra ela, nunca solto no ar.
const QUEDA_LIVRE := 4200.0

## Quanto a embreagem deixa o motor girar acima da roda na arrancada. E o
## conversor de torque do automatico: sem isto o carro sai do sinal na marcha
## lenta e nao tem forca nenhuma para sair. Fracao do corte, pelo mesmo motivo
## de `TROCA_LEVE_DO_CORTE`.
const PATINA_DO_CORTE := 0.38
## Acima desta velocidade a embreagem ja travou e o giro e o da roda.
const VEL_EMBREAGEM := 7.0

## Freio motor, em Nm, com o pe fora do acelerador. Cresce com o giro: e por
## isso que tirar o pe a 5000 rpm segura o carro e a 1200 rpm nao segura nada.
## Proporcional ao torque do motor — um 1.0 nao segura como um 2.0.
const FREIO_MOTOR_DO_TORQUE := 0.25

## Raio do pneu sob carga. Sai da Carroceria para o painel, o som e a fisica
## concordarem sobre quanto o carro anda por volta de roda.
const RAIO_PNEU := Carroceria.RAIO_RODA

## Converte rad/s em rpm.
const RPM_POR_RAD := 60.0 / TAU


var giro: float = giro_lenta
## 0 e a re; 1 a 5 sao as marchas para a frente.
var marcha: int = 1
var re: bool = false
var ligado: bool = false
## Embreagem aberta: nao ha forca chegando na roda.
var trocando: float = 0.0
## Faisca cortada pelo limitador.
var cortando: float = 0.0

## Contadores de diagnostico. Existem para o teste automatizado poder afirmar
## que a troca e o corte ACONTECERAM, e nao so que poderiam acontecer.
var trocas: int = 0
var cortes: int = 0
var giro_maximo: float = 0.0

## Quanto pe ha no acelerador DEPOIS de resolver o sentido: na re quem acelera e
## a tecla de tras. O som e o painel leem isto, e nao a tecla crua.
var pedal: float = 0.0
## E quanto ha no freio, pelo mesmo motivo. O carro aplica; o motor so resolve
## qual das duas teclas e qual.
var travao: float = 0.0
## A memoria do pe que o cambio usa para escolher a marcha. Ver `VONTADE_SOBE`.
var vontade: float = 0.0

var _espera: float = 0.0
var _trava_reducao: float = 0.0


## Recebe a ficha do carro. Sem isto o motor e o sedan de referencia.
func configurar(ficha: Dictionary) -> void:
	relacoes = (ficha["relacoes"] as Array).duplicate() as Array[float]
	diferencial = float(ficha["diferencial"])
	torque_pico = float(ficha["torque"])
	giro_corte = float(ficha["giro_corte"])
	giro_fundo = float(ficha["giro_fundo"])
	giro_vermelho = float(ficha["giro_vermelho"])
	troca_sobe = float(ficha["troca_sobe"])
	# A marcha lenta acompanha o motor: um que gira ate 4700 nao fica em 820 de
	# lenta proporcionalmente ao mesmo que um que gira ate 7000.
	giro_lenta = clampf(giro_corte * 0.135, 600.0, 1000.0)
	marcha = 1
	giro = giro_lenta


func desligar() -> void:
	ligado = false
	giro = 0.0
	marcha = 1
	vontade = 0.0
	re = false
	trocando = 0.0
	cortando = 0.0


func ligar() -> void:
	ligado = true
	giro = giro_lenta
	marcha = 1
	vontade = 0.0


## Um passo da maquina.
##
## `acelerador` e `freio` sao 0..1. `vel_roda` e a velocidade do carro em m/s,
## COM sinal: negativo andando de re. Devolve a forca a aplicar em cada roda de
## tracao, em Newtons — `VehicleBody3D` aplica `engine_force` por roda, entao
## quem chama nao divide de novo.
func passo(acelerador: float, freio: float, vel_roda: float, delta: float) -> float:
	if not ligado:
		giro = maxf(0.0, giro - QUEDA_LIVRE * delta)
		trocando = 0.0
		cortando = 0.0
		pedal = 0.0
		travao = clampf(freio, 0.0, 1.0)
		return 0.0

	_espera = maxf(0.0, _espera - delta)
	_trava_reducao = maxf(0.0, _trava_reducao - delta)
	trocando = maxf(0.0, trocando - delta)
	cortando = maxf(0.0, cortando - delta)

	_escolher_sentido(acelerador, freio, vel_roda)
	# Na re os dois pedais trocam de papel: quem faz o carro andar e a tecla de
	# tras, e a de frente passa a ser o freio. Resolver isso aqui e nao no carro
	# e o que impede a regra de existir em dois lugares com sinais diferentes.
	pedal = clampf(freio if re else acelerador, 0.0, 1.0)
	travao = clampf(acelerador if re else freio, 0.0, 1.0)

	if pedal > vontade:
		vontade = minf(pedal, vontade + VONTADE_SOBE * delta)
	else:
		vontade = maxf(pedal, vontade - VONTADE_DESCE * delta)

	_atualizar_giro(pedal, vel_roda, delta)
	if trocando <= 0.0:
		_talvez_trocar(pedal, vel_roda)

	giro_maximo = maxf(giro_maximo, giro)

	return _forca(pedal, vel_roda)


## Ha quanto o motor esta com a faisca cortada AGORA — limitador ou troca.
## O som le isto para dar o tranco; o painel le para apagar a luz de troca.
func cortado() -> bool:
	return cortando > 0.0 or trocando > 0.0


## Onde o ponteiro do conta-giros fica, de 0 a 1.
func giro_normalizado() -> float:
	return clampf(giro / giro_fundo, 0.0, 1.0)


## Carga: quanto o motor esta trabalhando, de 0 a 1.
##
## E o pedal ja resolvido pelo sentido, zerado enquanto a faisca esta cortada —
## porque durante a troca o pe continua no fundo e o motor nao esta puxando
## nada, e um som que ignora isso perde exatamente o buraco que faz a troca
## soar como troca.
func carga() -> float:
	if not ligado or cortado():
		return 0.0
	return pedal


## A marcha como o painel escreve: "R" para a re, o numero para o resto.
func rotulo_marcha() -> String:
	return "R" if re else str(marcha)


# --- internos ---------------------------------------------------------------

## Para a frente ou para tras.
##
## E o automatico de todo jogo de carro sem alavanca: quem esta quase parado e
## segura o freio engata a re; quem acelera volta para a frente. A regra fica
## aqui, e nao no carro, porque a re e uma relacao do cambio como as outras.
func _escolher_sentido(acelerador: float, freio: float, vel_roda: float) -> void:
	if freio > 0.1 and vel_roda < 0.6 and not re:
		re = true
		marcha = 1
	elif acelerador > 0.1 and vel_roda > -0.4 and re:
		re = false
		marcha = 1


## O giro sai da roda quando a embreagem esta fechada, e da inercia do motor
## quando ela esta aberta.
func _atualizar_giro(acelerador: float, vel_roda: float, delta: float) -> void:
	var v := absf(vel_roda)

	if trocando > 0.0:
		# Embreagem ABERTA, e so aqui. O giro cai para o que a marcha nova vai
		# pedir — e essa queda que se ouve como troca.
		#
		# Ela nao sobe: um motor com a embreagem aberta e o pe no fundo subiria
		# ate o limitador, e num cambio automatico isso nao acontece porque a
		# troca dura um quarto de segundo. Fazer o giro subir aqui punia quem
		# acelera com um corte a cada marcha.
		giro = move_toward(giro, maxf(giro_lenta, _giro_da_roda(v, marcha)),
			QUEDA_LIVRE * delta)
	else:
		# Embreagem fechada — inclusive com o carro parado. O carro esta SEMPRE
		# engatado: nao ha ponto morto neste cambio, e tratar "parado" como
		# embreagem aberta foi o defeito que travou o carro no lugar. Com o pe no
		# fundo e a roda a zero, o motor subia livre ate o limitador, o limitador
		# cortava a faisca, o torque ia a zero — e o carro nunca saia do sinal.
		# A medida acusou 25 cortes de giro, uma marcha e seis metros e meio em
		# seis segundos de pe no fundo.
		#
		# O que existe parado e a embreagem PATINANDO, que e o conversor de
		# torque de qualquer automatico: o motor gira acima da roda, entrega
		# torque, e os dois se igualam conforme o carro ganha velocidade.
		var acoplado := _giro_da_roda(v, marcha)
		var patina := lerpf(giro_lenta, giro_corte * PATINA_DO_CORTE,
			clampf(acelerador, 0.0, 1.0))
		var t := clampf(v / VEL_EMBREAGEM, 0.0, 1.0)
		giro = maxf(acoplado, lerpf(patina, acoplado, t))
		giro = maxf(giro, giro_lenta)

	if giro >= giro_corte:
		giro = giro_corte
		if cortando <= 0.0:
			cortando = TEMPO_CORTE
			cortes += 1


## Giro que uma marcha entrega a uma velocidade. Tambem serve para o cambio
## perguntar "e se eu subisse?" sem trocar.
func _giro_da_roda(v: float, qual: int) -> float:
	var rel := RELACAO_RE if re else relacoes[clampi(qual - 1, 0, relacoes.size() - 1)]
	return absf(v) / RAIO_PNEU * rel * diferencial * RPM_POR_RAD


## O cambio automatico.
##
## Sobe quando o giro passa do ponto de troca — que depende do pe, porque um
## automatico com pe leve troca cedo e com pe no fundo segura ate o fim da faixa
## — e desce quando cai abaixo de `TROCA_DESCE_DO_CORTE`. Os dois pontos sao
## FRACOES do corte deste motor, e nao numeros absolutos: trocar a 2900 rpm e
## tarde num motor que gira ate 7000 e quase o limitador num que gira ate 4700.
##
## Nao ha troca na re, que tem uma marcha so.
func _talvez_trocar(acelerador: float, vel_roda: float) -> void:
	# Carro parado volta para a primeira, sem embreagem aberta e sem esperar a
	# folga entre trocas: um automatico faz isso ao encostar no sinal, e a
	# reducao com o carro parado nao tem tranco nenhum para se ouvir.
	#
	# Sem esta linha o carro sai do sinal na marcha em que parou. Medido: o teste
	# punha o carro na faixa em segunda e a arrancada inteira corria em segunda,
	# com 44% da forca que a primeira daria — 0 a 38 km/h em dois segundos em vez
	# de 0 a 50 em um e meio.
	if absf(vel_roda) < 1.0 and marcha > 1 and not re:
		marcha = 1
		return
	if re or _espera > 0.0:
		return
	var ponto := ponto_de_subir(vontade)
	var desce := ponto_de_descer(vontade)
	# Pe fora e vontade ainda alta: segura a marcha — nao sobe. So o corte passa
	# por cima. Reduzir continua valendo: freando para a curva, o automatico
	# desce junto e sai dela na marcha que puxa.
	var aliviando := acelerador < 0.05 or acelerador < vontade - ALIVIANDO
	var segurando := aliviando and vontade > VONTADE_SEGURA and giro < troca_sobe
	if marcha < relacoes.size() and not segurando:
		# Duas razoes para subir, e a segunda nao e enfeite.
		#
		# A primeira e a obvia: o giro chegou no ponto de troca.
		#
		# A segunda e o CRUZAMENTO — o ponto em que a marcha de cima ja empurra
		# mais que a de baixo, porque o motor caiu para uma parte melhor da
		# curva. Sem ela, uma marcha cujo ponto de troca fica acima da
		# velocidade final daquela marcha nunca sai: o carro sobe de giro
		# assintoticamente, chega a 6050 no papel e nunca na pratica. Era o caso
		# da quinta aqui — o ponto de troca da quarta cai em 48,3 m/s e o carro
		# termina em 48, entao a quinta nao existia.
		var agora := torque(giro) * relacoes[marcha - 1]
		var acima := _forca_relativa(vel_roda, marcha + 1)
		if giro > ponto or (acelerador > 0.35 and acima > agora):
			# So sobe se a marcha de cima nao cair abaixo do ponto de descer —
			# senao ela reduziria no quadro seguinte — nem da lenta.
			var giro_acima := _giro_da_roda(vel_roda, marcha + 1)
			if giro_acima > maxf(giro_lenta * 1.1, desce * 1.05):
				_engatar(marcha + 1)
				# So trava quem subiu com o pe embaixo. Subir no alivio longo e
				# cruzeiro, e a pisada seguinte tem de reduzir na hora.
				if acelerador > 0.3:
					_trava_reducao = TRAVA_REDUCAO
				return
	var morrendo := giro < giro_corte * TROCA_DESCE_DO_CORTE
	if marcha > 1 and giro < desce and (_trava_reducao <= 0.0 or morrendo):
		var alvo := _marcha_para_reduzir(vel_roda, ponto, desce)
		if alvo < marcha:
			_engatar(alvo)
			# Kickdown: o pe pediu forca, e a proxima decisao nao pode demorar
			# o mesmo que uma troca de cruzeiro.
			if acelerador > 0.6:
				_espera = ESPERA_KICKDOWN


## Ponto de subir para uma vontade: 33% do corte com o pe leve, `troca_sobe`
## no fundo, com a curva do pedal no meio.
func ponto_de_subir(v: float) -> float:
	return lerpf(giro_corte * TROCA_LEVE_DO_CORTE, troca_sobe,
		pow(clampf(v, 0.0, 1.0), CURVA_DO_PEDAL))


func ponto_de_descer(v: float) -> float:
	return maxf(giro_corte * TROCA_DESCE_DO_CORTE, ponto_de_subir(v) * DESCE_DO_PONTO)


## Para que marcha reduzir.
##
## Com o pe no fundo, a que empurra MAIS entre as que cabem abaixo do ponto de
## subir — pode pular uma, como o kickdown de qualquer automatico: de quarta a
## 47 km/h o sedan vai direto para a segunda. Com o pe parcial, so a de baixo.
func _marcha_para_reduzir(vel_roda: float, ponto: float, desce: float) -> int:
	if vontade < 0.8:
		var abaixo := marcha - 1
		if _giro_da_roda(vel_roda, abaixo) < ponto * FOLGA_REDUCAO:
			return abaixo
		return marcha
	var melhor := marcha
	var melhor_forca := torque(giro) * relacoes[marcha - 1]
	for m in range(marcha - 1, 0, -1):
		var rpm := _giro_da_roda(vel_roda, m)
		if rpm >= ponto * FOLGA_REDUCAO:
			break
		var f := torque(rpm) * relacoes[m - 1]
		if f > melhor_forca and rpm > desce:
			melhor = m
			melhor_forca = f
	# Nenhuma cabe acima do ponto de descer (o carro esta devagar demais para
	# qualquer uma puxar la): a de baixo, que e o que um automatico faz.
	if melhor == marcha and _giro_da_roda(vel_roda, marcha - 1) < ponto * FOLGA_REDUCAO:
		melhor = marcha - 1
	return melhor


## Forca na roda que uma marcha daria nesta velocidade, a menos das constantes
## que sao iguais em todas elas. Serve so para comparar duas marchas entre si.
func _forca_relativa(v: float, qual: int) -> float:
	if qual < 1 or qual > relacoes.size():
		return -1.0
	var rpm := _giro_da_roda(v, qual)
	if rpm > giro_corte:
		return -1.0
	return torque(rpm) * relacoes[qual - 1]


func _engatar(qual: int) -> void:
	marcha = clampi(qual, 1, relacoes.size())
	trocando = TEMPO_TROCA
	_espera = ESPERA_TROCA
	trocas += 1


## Forca em cada roda de tracao.
##
## Com o pe fora e a embreagem fechada isto e NEGATIVO: e o freio motor, que e o
## que segura o carro na descida e o que faz soltar o acelerador significar
## alguma coisa. Sem ele o carro navega por vinte segundos, que era o defeito
## que a constante solta tapava com um `brake` fixo.
func _forca(acelerador: float, vel_roda: float) -> float:
	if trocando > 0.0 or cortando > 0.0:
		return 0.0
	var a := clampf(acelerador, 0.0, 1.0)
	var rel := RELACAO_RE if re else relacoes[clampi(marcha - 1, 0, relacoes.size() - 1)]
	var nm := torque(giro) * a - torque_pico * FREIO_MOTOR_DO_TORQUE * (1.0 - a) * clampf(
		giro / (giro_corte * 0.46), 0.0, 1.4)
	# Com o carro praticamente parado o freio motor nao existe: ele viraria uma
	# forca para tras empurrando o carro parado no sinal.
	if absf(vel_roda) < 0.5 and a < 0.05:
		nm = 0.0
	var forca := nm * rel * diferencial * EFICIENCIA / RAIO_PNEU
	# Godot aplica `engine_force` em CADA roda de tracao; a Carroceria usa duas.
	forca *= 0.5
	return -forca if re else forca


## Torque no virabrequim, em Nm, neste giro.
##
## Delega a `FichaTecnica`, que estica a curva de referencia pelo pico e pelo
## corte deste motor. Esticar o eixo do giro e o que faz o Fusca ter forca em
## 2300 rpm e o Marea em 3400 — sem isso todo motor da cidade teria a mesma
## faixa boa e a diferenca entre eles seria so de volume.
func torque(rpm: float) -> float:
	return FichaTecnica.torque(rpm, torque_pico, giro_corte)


## Giro plausivel para um carro que NAO usa este motor.
##
## Os carros da IA sao cinematicos: eles nao tem forca, nao tem embreagem e nao
## tem curva. Mas eles fazem barulho, e um barulho de motor sem giro e um ruido
## de afinacao aleatoria. Esta funcao devolve o giro que aquela velocidade daria
## no cambio DAQUELE modelo, para que o Fusca que passa soe como um Fusca — ele
## tem quatro marchas e gira ate 4700, e nao cinco ate 6500.
##
## Devolve um FLOAT e nao um dicionario, e a diferenca importa: isto roda uma vez
## por carro por quadro de fisica. Com seis carros na rua, o dicionario antigo
## eram trezentas e sessenta alocacoes por segundo para carregar um numero que o
## chamador usava e dois que ele jogava fora.
##
## `acelerando` sobe o ponto de troca: o carro que sai do sinal troca a meia
## faixa, e nao a um terco dela. Com o ponto de cruzeiro na arrancada, todo
## carro da rua saia do semaforo arrastado, trocando marcha a 2100 rpm.
const TROCA_APARENTE_ACELERANDO := 0.52


static func giro_aparente(v: float, modelo: Carroceria.Modelo,
		acelerando: bool = false) -> float:
	var ficha := FichaTecnica.de(modelo)
	var rel_lista: Array = ficha["relacoes"]
	var dif: float = ficha["diferencial"]
	var teto: float = float(ficha["giro_corte"]) * (TROCA_APARENTE_ACELERANDO
		if acelerando else TROCA_LEVE_DO_CORTE)
	var passo := absf(v) / RAIO_PNEU * dif * RPM_POR_RAD
	var rel := float(rel_lista[0])
	for k in rel_lista.size():
		rel = float(rel_lista[k])
		if passo * rel < teto:
			break
	return maxf(820.0, passo * rel)
