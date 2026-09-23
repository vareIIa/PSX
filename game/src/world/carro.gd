## Um carro. O mesmo no serve para o transito e para o jogador.
##
## Por que nao sao duas classes
## ----------------------------
## Roubar um carro e a acao central do pedido, e todo desenho em que o carro da
## IA e um objeto e o carro dirigivel e outro paga a troca exatamente na hora em
## que o jogador esta olhando de perto: o modelo pisca, a inercia zera, a cor
## muda um tom porque o sorteio rodou de novo. Aqui nao ha troca. O carro e
## sempre um VehicleBody3D com as mesmas rodas e a mesma lataria; o que muda e
## quem esta ao volante.
##
##   IA        `freeze` ligado em modo cinematico. A posicao vem da faixa de
##             rolamento, entao o carro nao capota, nao entala em meio-fio e nao
##             deriva ao longo de dez minutos de simulacao. Ele ainda empurra
##             pedestre e ainda e solido para o jogador.
##   JOGADOR   `freeze` desligado. Dai em diante e fisica de verdade: forca no
##             eixo, esterco nas dianteiras, peso transferindo na freada.
##
## A troca e uma linha e nao tem costura, porque o corpo rigido ja estava ali
## parado no lugar certo com a velocidade certa.
##
## Por que a IA nao usa a fisica
## -----------------------------
## Porque nao ha ganho e ha risco. Um transito de seis corpos rigidos com
## suspensao e atrito de pneu diverge: dois carros se tocam num cruzamento, um
## sobe no outro, e vinte minutos depois ha um carro de pe em cima de um poste a
## duzentos metros de distancia, onde ninguem ve o defeito nascer. A faixa e uma
## reta conhecida; segui-la e mais barato e nao tem cauda.
class_name Carro
extends VehicleBody3D

enum Motorista { NINGUEM, IA, JOGADOR }

## Velocidade de cruzeiro da IA, em m/s. 11 m/s sao 40 km/h — velocidade de rua
## estreita a noite, e o bastante para o carro passar por um pedestre parado com
## a sensacao de perigo que o pedido descreve.
const VEL_CRUZEIRO := 11.0
const VEL_AVENIDA := 14.0
## Aceleracao e frenagem da IA, em m/s^2.
const ACELERA := 4.2
const FREIA := 8.0
## Segura na rampa: abaixo desta velocidade, sem pedal nenhum, o carro do
## jogador freia com esta fracao do freio (ver `_dirigir_jogador`). Metade do
## freio segura 30% de rampa com folga.
const SEGURA_RAMPA_VEL := 0.6
const SEGURA_RAMPA := 0.5

## Quao perto do ponto de destino conta como chegou.
const CHEGOU := 2.4
## Quanto o carro olha a frente para decidir se freia.
const OLHAR_A_FRENTE := 9.0
## Meia largura do corredor em que um obstaculo a frente conta como obstaculo.
const CORREDOR := 1.5

## Folga de seguranca em volta da linha de retencao, em metros.
const RETENCAO := 5.0
## A partir de quantos metros ALEM da linha o carro conta como ja estando
## dentro do cruzamento, e entao atravessa aconteca o que acontecer com a luz.
## Meio metro: menos que isso e o carro em cima da propria linha.
const DENTRO_DO_CRUZAMENTO := 0.5
## Folga de para-choque ao encostar atras de alguem, em metros.
##
## E o que separa "fila" de "engavetamento visual": sem ela o carro de tras
## encosta o bico na traseira do da frente e os dois poligonos se tocam.
const FOLGA_FILA := 1.5

## Contornar quem parou na frente.
##
## Sem isto a rua tranca de vez. Basta o jogador estacionar no meio da pista —
## e isso e uma coisa que o jogo INCENTIVA, porque todo carro e tomavel — para
## que todos os carros daquela faixa parem atras dele e fiquem ali enquanto o
## bairro estiver carregado. Quem passa de carro ve uma fila de quatro carros
## parados atras de um Fusca vazio, buzinando, para sempre.
##
## O que um motorista faz e sair pela esquerda, que e por onde se ultrapassa em
## mao brasileira — pelo lado do meio-fio ha calcada, poste e pedestre.
## Quanto tempo preso atras de algo PARADO antes de contornar, em segundos.
const ESPERA_CONTORNO := 2.4
## Quanto a mira sai da faixa durante o contorno, em metros. Duas vezes a meia
## largura de um carro, com folga: menos que isso raspa a lataria parada.
const CONTORNO_LATERAL := 2.1
## Quanto o contorno dura, em segundos. Tempo de passar por um carro parado a
## velocidade de manobra e voltar para a faixa.
const TEMPO_CONTORNO := 4.0
## Velocidade maxima durante um contorno, em m/s. Ultrapassagem de rua estreita
## e devagar; a 40 km/h ela vira um desvio de jogo de corrida.
const VEL_CONTORNO := 5.0
## Antecipar escolha de curva antes de passar do pivo (meia avenida ~3.4 m).
const ANTECIPAR_CURVA := 8.5
## Segundos de seta antes do pivo. Distancia = velocidade * isto.
const PISCA_S := 1.5
## Periodo do pisca-pisca (aceso metade do ciclo): 1,5 Hz, que sao 90
## piscadas por minuto.
##
## Era 0,44 s (2,27 Hz), fora da faixa de 60 a 120 por minuto que a norma de
## instalacao de iluminacao (ONU R48) pede — e rapido o bastante para ler como
## lampada queimada, que e exatamente o que uma seta rapida denuncia no carro de
## verdade (PLANO_AAA_4K, A22).
const PISCA_PERIODO := 0.667
## Quanto o pisca da frente brilha quando nao esta piscando: lanterna.
const PISCA_APAGADO := 0.3
## Esterco (em radianos de roda) que conta como "fez a curva" para a seta
## desligar sozinha, e o quanto o volante tem de voltar para ela apagar. Troca de
## faixa na avenida nao chega a 0,2 — e nao deve desligar a seta, como num carro
## de verdade.
const PISCA_CURVA := 0.2
const PISCA_RETO := 0.05

## O carro do jogador NAO tem mais uma constante de potencia.
##
## A forca vem da curva de torque do `Motor` multiplicada pela relacao da marcha
## — ver `src/systems/motor.gd`. O que sobrou aqui e o que e do chassi e nao do
## motor: freio, volante e arrasto.
##
## A constante antiga valia 240 N e nunca foi exercitada, porque nao havia como
## entrar num carro: `VehicleBody3D` aplica `engine_force` em cada roda de
## tracao, entao 240 davam 480 N num corpo de 980 kg — meio metro por segundo ao
## quadrado, ou trinta segundos para chegar aos 50 km/h. O carro compilava,
## dirigia no papel e, no chao, nao saia do lugar.
## Freio de servico. Nao e Newton: `VehicleBody3D` usa `brake` como teto de
## IMPULSO por roda, e a conversao so sai medindo. Medido num veiculo minimo de
## 980 kg vindo de 14 m/s num chao plano:
##
##     brake  54 -> para em  7,0 m   (13,9 m/s2, 1,42 g)
##     brake 150 -> para em  2,8 m   (34,7 m/s2, absurdo)
##
## 1,42 g e mais do que qualquer pneu de rua segura, e o carro ficava grudento —
## freada de jogo de arcade, nao de sedan de 98. 32 da cerca de 8,3 m/s2, que sao
## 0,85 g: forte, com peso na frente, e ainda dentro do que a borracha faz.
const FREIO_MAX := 32.0
var _freio: float = FREIO_MAX
## Freio de mao, como multiplo do freio de servico. Trava so o eixo traseiro, e
## por isso solta o rabo em vez de parar o carro — que e para o que ele serve num
## jogo e num estacionamento. Multiplo e nao numero fixo: num Fusca, 110 seria
## tres vezes o freio de pedal dele.
const FREIO_MAO_DO_FREIO := 3.4

const ESTERCO_MAX := 0.52
## Quanto o esterco fecha com a velocidade. Sem isso, a 90 km/h um toque no A
## joga o carro de lado.
const ESTERCO_MIN := 0.16
const VEL_ESTERCO_FECHADO := 22.0
## Quanto o volante gira por segundo, em curso de esterco. Ir ao batente em
## 0,2 s e o compromisso do teclado: mais devagar e o desvio de meio-fio nao
## acontece a tempo, mais rapido e cada toque vira um solavanco.
const VEL_VOLANTE := 2.6
## E quanto ele volta ao centro sozinho. Sempre mais rapido que o giro, porque a
## roda de um carro real se auto-alinha e soltar a tecla tem de parecer soltar o
## volante, e nao segura-lo torto.
const VEL_VOLANTE_CENTRO := 5.2

## Arrasto do ar padrao: 0,5 * densidade * Cd * area frontal, ja multiplicado,
## em N por (m/s)^2. E o que da teto de velocidade ao carro — sem ele a quinta
## marcha acelera para sempre e o sedan cansado passa dos 300 km/h.
##
## Cada modelo tem o seu, porque uma picape e um armario contra o vento e um
## Marea nao e. O valor aqui e o do sedan e vale enquanto a ficha nao chegar.
const ARRASTO := 0.45
var _arrasto: float = ARRASTO
## Resistencia de rolamento, como fracao do peso. 1,5% e pneu de rua em asfalto.
const ROLAMENTO := 0.015

## O curso do pedal, em fracao por segundo (PLANO_CARROS_AAA, F10).
##
## A tecla e digital: zero ou tudo, num quadro. Um motor de 135 Nm em primeira
## recebendo o torque inteiro de uma vez da um tranco que nenhum pe faz — o
## carro sai do sinal aos solavancos e a traseira do Fusca escorrega a cada
## toque. Um pe de verdade leva uns dois decimos de segundo para afundar o
## acelerador e um pouco menos para afundar o freio; soltar e mais rapido que
## pisar. Vale para o teclado e para o piloto dos testes, que exercitam o mesmo
## caminho.
const PEDAL_SOBE := 5.0
const PEDAL_DESCE := 9.0
const FREIO_SOBE := 8.0
const FREIO_DESCE := 12.0

## Quanto do atrito seco sobra com a pista molhada.
##
## O jogo tem chuva desde sempre — `FogPreset.tem_chuva` — e o pneu a ignorava:
## chovendo ou nao, `wheel_friction_slip` era o mesmo numero. Com 72% o carro
## ainda anda, mas a picape de tracao traseira sai de lado na arrancada e o
## Fusca precisa de mais rua para parar, que e exatamente o que chuva faz.
const MOLHADO := 0.72

## Suspensao, freio de mao e rolagem (18/09/2026).
##
## O jogador reportou: "a suspensao do carro e bem ruim, ele fica pulando de um
## lado pro outro", e pediu direcao mais realista e deriva no freio de mao. A
## `tests/bancada_dirigir.gd` mediu o sedan antes de qualquer ajuste: 2,6 g de
## curva a 60 km/h (pneu de cola, ver `FichaTecnica`), 13,5 graus de rolagem
## no slalom, e a carroceria solta de lado cruzando o nivel cinco vezes em 3,4
## s — amortecimento de 0,10 do critico. O freio de mao girava o carro 45 graus
## e o PARAVA: a roda travada do Godot segura de lado quase o mesmo que a solta.
##
## Os tres numeros abaixo sao o conserto, e cada um responde a um desses.

## Amortecedor, como fracao de raiz(rigidez). No `VehicleBody3D` a forca de cada
## roda e massa * (rigidez * x - amortecedor * v), e a razao de amortecimento do
## sobe-e-desce sai proporcional a amortecedor / raiz(rigidez). Escrito assim, os
## sete carros amortecem na mesma proporcao por mais que a mola de cada um mude —
## com o numero fixo de antes (0,62), o Fusca de mola mole balancava mais que o
## Marea de mola dura. Retorno mais firme que compressao, como em amortecedor de
## verdade: o buraco entra macio e a carroceria nao volta quicando.
const AMORTECE_COMPRESSAO := 0.40
const AMORTECE_RETORNO := 0.56

## Barra estabilizadora, como fracao da mola: a forca em cada roda de um eixo e
## `ESTABILIZADORA * massa * rigidez` vezes a diferenca de compressao entre ela e
## a do outro lado. Soma rigidez so a ROLAGEM — o sobe-e-desce dos dois lados
## juntos nao a torce —, que e exatamente o modo que balancava: com o centro de
## massa baixo da ficha a inercia de rolagem e grande para as molas, e a
## carroceria ia e voltava devagar, como barco.
const ESTABILIZADORA := 0.35
## E o amortecimento da torcao dela, na unidade do amortecedor (vezes
## raiz(rigidez)). A barra sozinha sobe a frequencia da rolagem mas nao a
## amortece, e o Fusca de mola mole continuava cruzando o nivel quatro vezes.
## Numa curva constante a torcao nao muda e este termo e zero: ele age so no
## vai-e-vem, e nao tira nem poe carga no pneu.
const AMORTECE_ROLAGEM := 0.5

## A deriva: depois que o freio de mao solta a traseira, ela desliza com o
## atrito de deslizamento da borracha, abaixo do de pico, ate o carro voltar a
## apontar para onde vai.
##
## No `VehicleBody3D` a roda que passou do limite volta a agarrar com o mesmo
## atrito de antes, e a traseira que o freio de mao soltou voltava ao lugar
## sozinha: a deriva durava meio segundo com o motorista contra-esterçando.
##
## E um MODO, que so o freio de mao liga, e nao uma queda que segue o
## escorregamento. A primeira versao seguia, e a bancada mostrou por que nao: na
## curva comum no limite a traseira escorrega um pouco, o atrito caia, ela
## escorregava mais — e o sedan RODAVA sozinho depois de soltar o volante, sem
## freio de mao nenhum. Direcao normal tem de ser estavel; deriva e escolha.
##
## 0,85 e nao os 0,75 de um pneu de livro: a bancada dirige como o jogador, de
## teclado (volante em -1, 0 ou +1), e com 0,75 tres dos seis carros rodavam de
## vez com o contra-esterco no batente. Com 0,85 nenhum roda e a deriva se
## segura por 1,9 a 3,1 s dos 4 medidos.
const ATRITO_DESLIZANDO := 0.85
## Abaixo deste angulo entre o nariz e a velocidade, em graus, o carro voltou a
## andar para onde aponta e a deriva acabou.
const DERIVA_FIM := 5.0

## Freio de mao: quanto da aderencia a roda traseira travada guarda, e em quanto
## tempo ela volta a agarrar depois de solta.
##
## Pneu travado desliza na direcao em que o carro anda: quase nao segura de lado,
## e e isso que faz o rabo sair. No `VehicleBody3D` a roda com freio segura de
## lado quase o mesmo que a solta, entao a traseira travada precisa de menos
## aderencia escrita. E a volta nao e instantanea: a roda travada precisa voltar a
## girar antes de agarrar, e sem essa rampa soltar o freio de mao no meio da
## deriva endireitava o carro num tranco.
const ADERENCIA_TRAVADA := 0.40
const VOLTA_ADERENCIA := 0.45

## Bater tem consequencia.
##
## Ate aqui nao tinha nenhuma: o carro encostava numa fachada e PARAVA, em
## silencio, sem tranco e sem marca. A medida automatizada esbarrou nisso a
## rodada inteira sem que nada no jogo dissesse que havia batido — e se o teste
## nao percebe, o jogador percebe menos ainda, porque para ele o carro so "para
## de andar" sem motivo visivel.
##
## Velocidade de fechamento minima para contar como batida, em m/s. Abaixo disso
## e encostar: meio-fio, outro carro no engarrafamento, parede de garagem.
const BATIDA_MINIMA := 2.2
## Acima disto a batida e total — som no volume cheio e tranco maximo.
const BATIDA_FORTE := 11.0
## Tempo minimo entre duas batidas contadas. Sem ele, um carro prensado contra
## um muro dispara o som a cada quadro de contato.
const BATIDA_ESPERA := 0.45

## Buzina: quanto tempo parado atras de alguem antes de reclamar.
const PACIENCIA := 2.6
const PACIENCIA_XINGO := 6.5

## Material do facho geometrico (mesmo da lampada de rua).
const MAT_CONE := "res://resources/materials/mat_cone_luz.tres"

## Quantos graus o farol aponta para baixo. A LUZ e o FACHO usam o mesmo numero:
## sao a mesma coisa vista de dois jeitos, e valores diferentes poem o cone de ar
## aceso ao lado da mancha que ele deveria estar explicando.
##
## Eram nove graus, e nove graus e o angulo errado por um motivo geometrico.
## O farol nasce a 62 cm do chao; a 9 graus o eixo dele fura o asfalto a 3,9 m da
## frente do carro, e os cinco metros restantes de um cone de nove ficam
## ENTERRADOS na rua. O que aparecia na tela nao era luz no ar: era a parede de
## baixo do tronco de cone raspando a superficie, uma lamina cinza deitada sobre
## a pista, com a borda reta que o jogador viu e chamou de feia.
##
## Tres graus e meio poe o encontro a 10 m, que e onde um farol baixo de verdade
## encosta na estrada. O cone passa a viver no ar, que e onde ele tem sentido.
const FAROL_INCLINACAO := -3.5

## Comprimento do cone de ar aceso, em metros.
##
## Nove metros passava DO JOGADOR quando ele estava na frente do carro: a camera
## entrava dentro do tubo e via a parede de dentro ocupando a tela inteira. Seis
## e meio e o alcance em que o ar aceso ainda e visivel na chuva sem que o cone
## vire um cobertor por cima de quem esta na calcada.
## Quanto o farol empurra para dentro da nevoa volumetrica no MODERNO.
## Mesmo numero da `Lampada`, e pelo mesmo motivo: e a mesma nevoa, e o valor
## foi escolhido na captura de perto, onde o excesso lava o quadro.
const VOLUME_MODERNO := 8.0

const FACHO_COMPRIMENTO := 6.5

## A que distancia um pedestre se assusta com o carro passando, e a que
## velocidade minima isso conta como quase-atropelamento.
const RAIO_SUSTO := 3.2
const VEL_SUSTO := 5.0

## A carroceria do carro da IA sobre molas (PLANO_CARROS_AAA, F10).
##
## O carro da rua e cinematico: a posicao e escrita a cada passo, e a lataria
## andava presa ao chao como um carrinho de trilho — freava de 50 a 0 sem
## mergulhar o bico, fazia a esquina sem deitar e parava sem aquele balanco de
## volta que todo carro de verdade tem. O jogador pediu que as melhorias do
## carro da cena de abertura, que ganhou molas (`CarroCena._molas`), chegassem
## aos carros da cidade.
##
## A mesma mola-amortecedor de segunda ordem, uma por grau de liberdade:
## subir, arfar e rolar. O alvo do arfar vem da aceleracao para a frente (freio
## afunda o bico, arrancada senta a traseira), o do rolar da aceleracao de
## lado (velocidade vezes a taxa de giro). As rodas ficam no chao; so a
## lataria, o interior, as luzes e o motorista balancam — e a diferenca entre
## os dois e o curso da suspensao aparecendo na boca da caixa de roda.
##
## Frequencias e amortecimento sao os do `CarroCena`, e pelo mesmo motivo.
const MOLA_FREQ := Vector3(1.35, 1.55, 1.7)
const MOLA_AMORTECE := 0.42
## Radianos de arfar por m/s2 de aceleracao: a freada da IA (8 m/s2) afunda o
## bico 1,8 grau, a arrancada (4,2 m/s2) levanta 0,9.
const ARFAR_POR_ACEL := 0.0039
## Radianos de rolar por m/s2 de aceleracao lateral, com teto: cinematico faz
## curva que pneu nenhum faria, e sem teto a esquina fechada deitava o carro.
const ROLAR_POR_ACEL := 0.0122
const ROLAR_MAX := 0.07
## Altura do centro do giro da carroceria, acima do chao: o carro arfa em volta
## do centro de massa, e nao do asfalto.
const MOLA_PIVO := 0.45

## A que distancia da camera o carro troca para a versao de longe
## (PLANO_CARROS_AAA, F9), e a folga da troca. De perto sao 7 a 8 mil
## triangulos por carro (4,6 mil so de roda); de longe, uns 1,4 mil. A 28 m, na
## nevoa da cidade, o vinco de porta e o furo da calota ja sao menos que um
## pixel. A folga evita que o carro pisque parado bem na borda.
const LOD_DISTANCIA := 28.0
const LOD_FOLGA := 2.0
## O interior some antes: atras do vidro, a vinte e poucos metros, ninguem ve
## banco.
const LOD_INTERIOR := 22.0

## Dano (PLANO_CARROS_AAA, F8). A partir desta forca de batida (0 a 1) o vidro
## mais perto trinca: e a pancada que ja afoga o motor pela metade.
const TRINCA_FORCA := 0.45
## Um carro da rua em cada tantos nasce com amassado de fabrica — a porta que
## alguem abriu no poste, o para-choque do estacionamento —, e ate quantos.
const AMASSADO_DE_FABRICA_EM := 5
const AMASSADOS_DE_FABRICA_MAX := 2

signal motorista_saiu(quem: Node3D)
## Bateu em alguma coisa. `forca` vai de 0 a 1. Quem escuta e o jogador, que
## sacode a camera — a lataria nao amassa, mas o pescoco de quem esta dentro
## sente, e e esse o sinal que faltava.
signal bateu(forca: float)


## Area de acionamento. Existe so para responder a tecla; a decisao fica no
## Carro, que e quem sabe se ha alguem dentro.
class Gatilho extends Interativo:
	var dono: Carro

	func rotulo_atual() -> String:
		if dono == null or Conversa.ativo:
			return ""
		return dono.rotulo_de_acao()

	func interagir(quem: Node) -> void:
		if dono != null:
			dono.acionar(quem)


var modelo: Carroceria.Modelo = Carroceria.Modelo.SEDA
var semente: int = 0
## Ficha do motorista, quando ha um. Vem do RegistroCivil como a de qualquer
## pedestre — e por isso da para tirar o sujeito do carro e conferir o RG dele.
var ficha: Dictionary = {}
var motorista: Motorista = Motorista.NINGUEM
var ligado: bool = false

## Estado de navegacao da IA.
var cruzamento := Vector2i.ZERO
var destino := Vector2i.ZERO
var trecho := Vector4i.ZERO

var _medidas: Dictionary = {}

## A cabine de dentro, so enquanto o JOGADOR dirige. Ver `CabineDoJogador`.
var _cabine_jogador: CabineDoJogador
var _corpo_malha: MeshInstance3D
## Bancos, painel e volante vistos pelo vidro. Some quando a cabine do jogador
## entra, que tem os dela.
var _interior: MeshInstance3D
var _luzes: MeshInstance3D
var _eixo_frente: Node3D
## Os dois pinos de roda da dianteira. Cada um no lugar da sua roda, para o
## esterco girar em torno do proprio pino e nao do centro do carro.
var _pinos_frente: Array[Node3D] = []
var _eixo_tras: Node3D
var _rodas: Array[VehicleWheel3D] = []
## Altura local de cada roda com a mola toda estendida. A roda de fisica sobe e
## desce com a suspensao, e a compressao e a distancia dela ate aqui — o
## `VehicleWheel3D` do 4.7 nao expoe o comprimento da mola.
var _y_estendida: PackedFloat32Array = []
## Quanto da aderencia seca a traseira tem agora, de `ADERENCIA_TRAVADA` a 1.
var _aderencia_tras := 1.0
## A barra deste carro. Variavel, e nao so a constante, para a bancada poder
## medir o carro com e sem ela sem editar o arquivo.
var _estabilizadora := ESTABILIZADORA
## A diferenca de compressao de cada eixo no passo anterior, para a velocidade
## de torcao da barra. NAN no primeiro passo: um carro que ficou parado numa
## rua inclinada tem diferenca, e compara-la com zero daria um tranco.
var _torcao := PackedFloat32Array([NAN, NAN])
## A deriva que o freio de mao comecou ainda dura. Ver `ATRITO_DESLIZANDO`.
var _derivando := false
var _farol: SpotLight3D
## Um cone por farol. Ver `_montar_fachos`.
var _fachos: Array[MeshInstance3D] = []
var _brasa: OmniLight3D
var _motorista_corpo: Corpo
## O amassado deste carro ja leu a malha (carro da rua, na primeira batida).
var _amassado_pronto := false
## A trinca do vidro: centro no espaco do carro e forca. Ver `_trincar`.
var _trinca := Vector4.ZERO
## A lataria de longe. Ver `LOD_DISTANCIA`.
var _corpo_longe: MeshInstance3D
## Onde os dois pedais estao agora. Ver `PEDAL_SOBE`.
var _pe_acel: float = 0.0
## Velocidade do quadro anterior, para a carga do som do carro da rua.
var _vel_som_antes: float = 0.0
var _pe_freio: float = 0.0
## Estado das molas da carroceria da IA: (subida, arfar, rolar) e velocidades.
var _mola := Vector3.ZERO
var _v_mola := Vector3.ZERO
var _mola_vel_antes := NAN
var _mola_giro_antes := 0.0
## A transformada de cada peca pendurada na mola, sem mola nenhuma.
var _mola_base: Dictionary = {}
## A borracha no chao e a fumaca no ar. So existe no carro que o jogador
## assumiu: o carro da IA e cinematico, a roda dele nunca desliza e um rastro
## que nasce de `get_skidinfo()` num corpo congelado seria rastro de nada.
var _rastro: RastroPneu
## O leque de agua da roda de tras. Nasce junto com o rastro porque acompanha as
## mesmas rodas e depende do mesmo momento do ciclo de vida.
var _spray: SprayRoda
var _gatilho: Gatilho
## A maquina. Nasce junto com o carro porque o carro da IA tambem precisa de uma
## rotacao para fazer barulho — ele so nao usa a forca que ela devolve.
var _motor := Motor.new()
## O que este MODELO tem de diferente dos outros seis. Ver
## `src/world/ficha_tecnica.gd`.
var _ficha: Dictionary = {}
var _freio_mao: bool = false
## Velocidade do quadro anterior, para medir o quanto a batida tirou.
var _vel_anterior := Vector3.ZERO
var _desde_batida: float = 999.0
## As batidas que marcaram a chapa, e o maior deslocamento da ultima.
var _amassado := Amassado.new()
var _ultimo_amassado: float = 0.0
var _custo_amassado_ms: float = 0.0
var _atraso_amassado_ms: float = 0.0
## Posicao de nascimento dos vertices das luzes, guardada na primeira batida.
var _luz_originais := PackedVector3Array()
## Comando injetado no lugar do teclado. Existe para o teste automatizado
## PILOTAR de verdade: um teste que chama `assumir` e mede `engine_force`
## aprova um carro que nunca andou. Ver `src/levels/teste_carro.gd`.
var _piloto: Vector3 = Vector3.ZERO
var _piloto_ligado: bool = false
## Contadores do quadro anterior, para o som saber que a troca ACONTECEU em vez
## de perguntar todo quadro se ela esta acontecendo.
var _trocas_vistas: int = 0
var _cortes_vistos: int = 0
var _som: MotorSom
var _buzina: AudioStreamPlayer3D
var _voz: Voz

var _alvo := Vector3.ZERO
## Ha rota? Nao da para perguntar isso ao _alvo: Vector3.ZERO e a origem do
## mundo, que e uma esquina como qualquer outra, e o carro que passasse por ela
## recalcularia a rota a cada quadro.
var _tem_rota: bool = false
## Verdadeiro enquanto o alvo e a QUINA dentro do cruzamento, e nao o cruzamento
## seguinte. Ver _escolher_destino.
var _curvando: bool = false
var _velocidade: float = 0.0
var _giro: float = 0.0
var _parado: float = 0.0
var _desde_buzina: float = 0.0
var _freando: bool = false
var _re: bool = false
var _vivo: float = 0.0
## Cruzamento cujo sinal ainda manda neste carro (sobrevive ao retarget de destino).
var _aproxima := Vector2i.ZERO
## O que ha na frente, medido uma vez por quadro. Duas variaveis e nao um
## Dicionario devolvido: isto roda para os seis carros da rua a cada quadro, e
## um Dicionario por carro por quadro sao 360 alocacoes por segundo para
## carregar dois valores.
var _obst_dist: float = INF
var _obst_quem: Node = null
## PARE da esquina sem semaforo (Semaforo.tem_sinal): desde quando esta parado
## na linha, e de que cruzamento ja foi liberado. Ver `_teto_do_pare`.
var _pare_desde: float = -1.0
var _pare_liberado := Vector2i(2147483647, 0)
## Contorno em andamento: quanto tempo falta, para que lado, e de quem.
var _contorno: float = 0.0
var _contorno_lado: float = 0.0
var _contornado: Node = null
## Por que este carro nao esta andando mais rapido. Escrito todo quadro pela IA
## e lido pelo teste — ver `motivo_da_parada`.
var _motivo: StringName = &"livre"
## Rolagem visual das rodas, separada do esterco para nao corromper Euler.
var _rolo_frente: float = 0.0
var _rolo_tras: float = 0.0

## Seta: -1 esquerda, +1 direita (+X), 0 apagada.
var _pisca_lado: int = 0
var _pisca_tempo: float = 0.0
## A seta do jogador ja viu o volante virar para o lado dela. E o que deixa o
## desligamento automatico esperar a curva acontecer, em vez de apagar a seta no
## mesmo quadro em que ela acendeu com o volante reto.
var _pisca_virou: bool = false
## Vertices do pisca DIANTEIRO de cada lado, e as cores de nascimento das luzes.
var _luz_f_esq: Array[int] = []
var _luz_f_dir: Array[int] = []
var _luz_cor_base := PackedColorArray()
## Saida escolhida antecipadamente para a seta nao divergir do sorteio.
var _saida_plana := Vector4i.ZERO
var _tem_plano: bool = false

## Cache da malha de lanternas para trocar celula UV (freio / re / seta).
var _luz_arrays: Array = []
var _luz_uv_base: PackedVector2Array = PackedVector2Array()
var _luz_i_esq: Array[int] = []
var _luz_i_dir: Array[int] = []
var _luz_chave: int = -1


func preparar(nova_ficha: Dictionary, de: Vector2i, t: Vector4i,
		nova_semente: int) -> void:
	ficha = nova_ficha
	cruzamento = de
	trecho = t
	semente = nova_semente
	modelo = _sortear_modelo(nova_semente)
	motorista = Motorista.IA if not nova_ficha.is_empty() else Motorista.NINGUEM


static func _sortear_modelo(s: int) -> Carroceria.Modelo:
	# Marea continua o padrao da rua. Fusca e o segundo reconhecimento. Os
	# genericos voltaram depois de ganharem casco varrido: sem isso a fila era
	# caixa chanfrada ao lado de dois carros de verdade.
	var h := absi(s * 2654435761) % 100
	if h < 8:
		return Carroceria.Modelo.TAXI
	if h < 26:
		return Carroceria.Modelo.FUSCA
	if h < 38:
		return Carroceria.Modelo.SEDA
	if h < 48:
		return Carroceria.Modelo.HATCH
	if h < 54:
		return Carroceria.Modelo.PERUA
	if h < 58:
		return Carroceria.Modelo.PICAPE
	return Carroceria.Modelo.MAREA


func _ready() -> void:
	add_to_group(&"carro")
	collision_layer = 1
	collision_mask = 1

	var tinta: Color = Carroceria.TINTAS[absi(semente * 7919) % Carroceria.TINTAS.size()]
	_medidas = Carroceria.montar(modelo, tinta, semente, true, true,
		_amassados_de_fabrica())

	_ficha = FichaTecnica.de(modelo)
	_motor.configurar(_ficha)
	_arrasto = float(_ficha["arrasto"])
	_freio = float(_ficha["freio"])

	mass = float(_ficha["massa"])
	# Centro de massa no assoalho. Um carro cujo centro esta na altura do banco
	# capota na primeira curva forte, e essa e a falha mais visivel que fisica
	# de veiculo produz.
	#
	# A posicao vem da ficha porque ela e o caracter do carro: no Fusca o peso
	# mora ATRAS, o que solta o rabo na curva; na picape vazia ele mora na
	# frente, o que deixa o eixo de tracao leve.
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = _ficha["centro_massa"]
	continuous_cd = true
	# Um arrasto so, e escrito.
	#
	# O mundo tem `default_linear_damp` de 0,1 por segundo, que e uma queda
	# PROPORCIONAL a velocidade — nao e aerodinamica, e um amortecedor generico
	# para caixas que nao devem deslizar para sempre. Num carro a 24 m/s ele
	# cobra 2352 N, contra os 259 N do arrasto do ar naquela velocidade. O
	# resultado, medido: com 2626 N de tracao o carro empacava aos 22 m/s e a
	# segunda marcha nunca chegava ao ponto de troca, entao o cambio de cinco
	# marchas so mostrava duas e o carro tinha 81 km/h de velocidade final.
	#
	# Aqui ele e substituido por zero, e quem freia o carro passa a ser
	# `_arrastar`, que e quadratico como ar de verdade e esta escrito neste
	# arquivo com as constantes a vista. O angular fica como esta: aquele segura
	# o carro de girar sozinho e nao compete com nada.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	# Quatro contatos bastam quando o monitor liga: o que interessa e que houve
	# batida, e nao quantas quinas encostaram. Quem LIGA e `assumir` — os seis
	# carros da rua sao cinematicos, nao batem em nada e nao precisam pagar o
	# rastreamento de contato a cada passo de fisica.
	max_contacts_reported = 4

	_montar_visual()
	_montar_colisao()
	_montar_rodas()
	_montar_spray()
	# O cache das luzes vem ANTES da montagem delas, e a ordem nao e gosto:
	# `_montar_fachos` descobre onde ficam os farois lendo os vertices da
	# superficie de luzes, e esse vetor e justamente o que `_cachear_luzes`
	# guarda. Na ordem inversa a leitura devolvia vazio, o carro caia no cone
	# unico do meio, e o defeito sobrevivia sem um erro sequer.
	_cachear_luzes()
	# As batidas de fabrica ja vieram na lataria; o amassado passa a conhece-las
	# para a proxima somar em cima, e o farol e a lanterna acompanham.
	var de_fabrica: Array = _medidas.get("batidas", [])
	if not de_fabrica.is_empty():
		_amassado.batidas.assign(de_fabrica)
		_amassar_luzes()
	_montar_luzes()
	_montar_som()
	_montar_gatilho()
	if motorista == Motorista.IA:
		_montar_motorista()

	_congelar(motorista != Motorista.JOGADOR)
	_iniciar_rota()
	_alinhar_na_faixa()
	if motorista == Motorista.IA:
		_velocidade = _teto_de_velocidade()


# --- montagem ---------------------------------------------------------------

func _montar_visual() -> void:
	_corpo_malha = MeshInstance3D.new()
	_corpo_malha.name = "Lataria"
	# Sem material_override: a malha traz lataria e vidro em superficies com
	# material proprio, e o override pintaria o vidro de lataria opaca.
	_corpo_malha.mesh = _medidas["corpo"]
	_corpo_malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_corpo_malha)

	_interior = MeshInstance3D.new()
	_interior.name = "Interior"
	_interior.mesh = _medidas["interior"]
	_interior.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_interior)

	var longe: Dictionary = _medidas.get("longe", {})
	if not longe.is_empty():
		_perto(_corpo_malha, LOD_DISTANCIA)
		_perto(_interior, LOD_INTERIOR)
		_corpo_longe = MeshInstance3D.new()
		_corpo_longe.name = "LatariaDeLonge"
		_corpo_longe.mesh = longe["corpo"]
		_longe(_corpo_longe)
		add_child(_corpo_longe)

	# Pintura metalica pela semente (F7). Taxi e Fusca ficam de fora: amarelo
	# de frota e bege cansado nunca sairam metalicos.
	var metal := 0.0
	var de_frota := modelo == Carroceria.Modelo.TAXI or modelo == Carroceria.Modelo.FUSCA
	if not de_frota and Carroceria.metalica(semente, _medidas["cor"]):
		metal = 1.0
	_corpo_malha.set_instance_shader_parameter(&"metalico", metal)
	if _corpo_longe != null:
		_corpo_longe.set_instance_shader_parameter(&"metalico", metal)

	_luzes = MeshInstance3D.new()
	_luzes.name = "Luzes"
	_luzes.mesh = _medidas["luzes"]
	_luzes.material_override = (load(Carroceria.MATERIAL_LUZ)
		as ShaderMaterial).duplicate() as ShaderMaterial
	_luzes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_luzes)


## Uma malha que so aparece de perto. Ver `LOD_DISTANCIA`.
static func _perto(mi: GeometryInstance3D, ate: float) -> void:
	mi.visibility_range_end = ate
	mi.visibility_range_end_margin = LOD_FOLGA
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


## O carro do jogador fica sempre na versao de perto: e so ela que o amassado
## deforma, e a de longe voltaria lisa quando ele se afastasse do carro batido.
func _desligar_lod() -> void:
	if _corpo_longe == null:
		return
	_corpo_longe.visible = false
	_corpo_malha.visibility_range_end = 0.0
	var eixos: Array = []
	eixos.append_array(_pinos_frente)
	if _eixo_tras != null:
		eixos.append(_eixo_tras)
	for eixo: Variant in eixos:
		for filho: Node in (eixo as Node).get_children():
			var mi := filho as MeshInstance3D
			if mi == null:
				continue
			if String(mi.name).ends_with("DeLonge"):
				mi.visible = false
			else:
				mi.visibility_range_end = 0.0


## Uma malha que so aparece de longe.
static func _longe(mi: GeometryInstance3D) -> void:
	mi.visibility_range_begin = LOD_DISTANCIA
	mi.visibility_range_begin_margin = LOD_FOLGA
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _montar_colisao() -> void:
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(float(_medidas["largura"]),
		float(_medidas["altura"]) - Carroceria.ASSOALHO,
		float(_medidas["comprimento"]))
	forma.shape = caixa
	forma.position = Vector3(0.0,
		Carroceria.ASSOALHO + (float(_medidas["altura"]) - Carroceria.ASSOALHO) * 0.5, 0.0)
	add_child(forma)


## As quatro rodas de fisica, e os dois eixos visuais em cima delas.
##
## A malha nao e filha da VehicleWheel3D. A roda de fisica sobe e desce com a
## suspensao e, com a malha pendurada nela, cada roda vira uma chamada de
## desenho. Aqui o eixo inteiro e uma malha so, colocada na media das duas
## rodas: perde-se o curso independente da suspensao, que a 480x270 e uma
## diferenca de menos de um pixel, e ganha-se metade das chamadas do carro.
## O leque de agua nasce com o carro, e nao quando o jogador assume o volante.
##
## Diferente da marca de pneu, que so o motorista tem motivo para olhar: o spray
## e detalhe de AMBIENTE. Um carro da IA passando e levantando agua e o que diz
## ao jogador que a rua esta molhada sem ele precisar olhar para baixo — e ele ve
## isso da calcada, sem nunca entrar num carro.
##
## Custa quase nada porque nasce desligado: sem chuva no chao, sem velocidade ou
## fora do estilo MODERNO, os emissores ficam parados.
func _montar_spray() -> void:
	if _spray != null:
		return
	_spray = SprayRoda.new()
	_spray.name = "Spray"
	add_child(_spray)
	_spray.acompanhar(self, _rodas)


func _montar_rodas() -> void:
	var eixo: float = _medidas["entre_eixos"] * 0.5
	var bitola: float = _medidas["bitola"] * 0.5
	for k in 4:
		var frente := k < 2
		var roda := VehicleWheel3D.new()
		roda.name = "Roda%d" % k
		# Frente visual e fisica em -Z: a lataria ja veio com a meia volta.
		roda.position = Vector3(bitola if k % 2 == 0 else -bitola,
			Carroceria.RAIO_RODA, -eixo if frente else eixo)
		roda.wheel_radius = Carroceria.RAIO_RODA
		roda.wheel_rest_length = 0.16
		var rigidez := float(_ficha["rigidez"])
		roda.suspension_stiffness = rigidez
		roda.suspension_travel = float(_ficha["curso"])
		roda.damping_compression = AMORTECE_COMPRESSAO * sqrt(rigidez)
		roda.damping_relaxation = AMORTECE_RETORNO * sqrt(rigidez)
		_y_estendida.append(roda.position.y - roda.wheel_rest_length)
		roda.wheel_friction_slip = _atrito_agora()
		roda.use_as_steering = frente
		# De onde vem a forca. A maioria dos carros de rua e de tracao dianteira,
		# que perdoa mais; o Fusca tem motor atras e a picape e traseira de
		# fabrica, e nos dois o eixo que empurra e o que sai primeiro. E a
		# diferenca mais sentida entre dirigir um e outro.
		var move: bool = (frente
			if int(_ficha["tracao"]) == FichaTecnica.Tracao.DIANTEIRA
			else not frente)
		roda.use_as_traction = move
		add_child(roda)
		_rodas.append(roda)

	# A DIANTEIRA e partida em duas, e so ela.
	#
	# O eixo inteiro num no so vale para ROLAR: rolar e girar em X, e o eixo
	# gira em X sem sair do lugar. Estercar nao. O no fica no centro do carro,
	# entao um giro em Y ali leva as duas rodas num ARCO em volta do centro em
	# vez de girar cada uma no proprio pino: a vinte graus de esterco a roda de
	# fora anda vinte e dois centimetros para tras e a de dentro vinte e dois
	# para a frente, saindo de baixo do para-lama e aparecendo debaixo do bico.
	#
	# Custa UMA chamada de desenho a mais por carro, e so na dianteira — a
	# traseira nao esterca e continua inteira. E o preco certo: o defeito
	# aparece em toda camera baixa da cidade, e a economia que o eixo unico
	# defendia (ver o cabecalho de `_montar_rodas`) era sobre o curso da
	# suspensao, que e outra coisa e continua valendo.
	_eixo_frente = Node3D.new()
	_eixo_frente.name = "EixoFrente"
	_eixo_frente.position = Vector3(0.0, Carroceria.RAIO_RODA, -eixo)
	add_child(_eixo_frente)
	var meia_bitola := float(_medidas.get("bitola", 1.42)) * 0.5
	_pinos_frente.clear()
	for lado: float in [-1.0, 1.0]:
		var pino := Node3D.new()
		pino.name = "RodaFrente%s" % ("E" if lado < 0.0 else "D")
		pino.position = Vector3(lado * meia_bitola, 0.0, 0.0)
		_eixo_frente.add_child(pino)
		var mr := MeshInstance3D.new()
		mr.mesh = (_medidas["roda_dir"] if lado > 0.0 else _medidas["roda_esq"])
		mr.material_override = load(Carroceria.MATERIAL) as ShaderMaterial
		mr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pino.add_child(mr)
		_pinos_frente.append(pino)
		var longe: Dictionary = _medidas.get("longe", {})
		if not longe.is_empty():
			_perto(mr, LOD_DISTANCIA)
			var ml := MeshInstance3D.new()
			ml.name = "RodaDeLonge"
			ml.mesh = longe["roda_dir"] if lado > 0.0 else longe["roda_esq"]
			ml.material_override = mr.material_override
			_longe(ml)
			pino.add_child(ml)

	# A mancha de contato. Mesma razao da Estrada Velha: nenhuma malha do carro
	# projeta sombra (custo), entao sem ela o carro fica recortado e colado sobre
	# o asfalto em qualquer plano rente ao chao. Ela e oclusao de ambiente do
	# proprio casco, e nao projecao de sol — por isso vale de dia, de noite e na
	# chuva, sem depender de haver uma direcional para justificar.
	var sombra := SombraContato.new()
	sombra.name = "SombraContato"
	sombra.position = Vector3(0.0, 0.05, 0.0)
	add_child(sombra)
	sombra.ajustar(float(_medidas["comprimento"]), float(_medidas["largura"]))

	_eixo_tras = Node3D.new()
	_eixo_tras.name = "EixoTras"
	_eixo_tras.position = Vector3(0.0, Carroceria.RAIO_RODA, eixo)
	add_child(_eixo_tras)
	var mt := MeshInstance3D.new()
	mt.mesh = _medidas["eixo_tras"]
	mt.material_override = load(Carroceria.MATERIAL) as ShaderMaterial
	mt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_eixo_tras.add_child(mt)
	var longe_t: Dictionary = _medidas.get("longe", {})
	if not longe_t.is_empty():
		_perto(mt, LOD_DISTANCIA)
		var ml := MeshInstance3D.new()
		ml.name = "EixoDeLonge"
		ml.mesh = longe_t["eixo_tras"]
		ml.material_override = mt.material_override
		_longe(ml)
		_eixo_tras.add_child(ml)


## Um farol so, largo, e nao dois.
##
## Dois SpotLight3D por carro com seis carros na rua sao doze luzes dinamicas
## contra um orcamento que a cidade ja usa quase inteiro com os postes. Um cone
## largo a partir do meio do capo da o mesmo desenho no asfalto — a coisa que o
## jogador realmente ve — pela metade do preco.
func _montar_luzes() -> void:
	_farol = SpotLight3D.new()
	_farol.name = "Farol"
	# A frente do carro e -Z, e SpotLight3D ja aponta para -Z sem giro nenhum.
	_farol.position = Vector3(0.0, 0.62, -float(_medidas["comprimento"]) * 0.5 + 0.1)
	_farol.rotation.x = deg_to_rad(FAROL_INCLINACAO)
	_farol.spot_range = 26.0
	_farol.spot_angle = 34.0
	_farol.spot_angle_attenuation = 0.9
	_farol.light_energy = 3.2
	_farol.light_color = Color(1.0, 0.95, 0.86)
	_farol.shadow_enabled = false
	add_child(_farol)

	_montar_fachos()

	# A brasa vermelha atras. Nao ilumina nada: existe para o carro da frente
	# ter presenca na nevoa quando o jogador vem atras dele.
	_brasa = OmniLight3D.new()
	_brasa.name = "Brasa"
	_brasa.position = Vector3(0.0, 0.55, float(_medidas["comprimento"]) * 0.5)
	_brasa.omni_range = 3.0
	_brasa.light_energy = 0.55
	_brasa.light_color = Color(1.0, 0.22, 0.16)
	_brasa.shadow_enabled = false
	add_child(_brasa)


func _montar_som() -> void:
	_som = MotorSom.new()
	_som.name = "Motor"
	add_child(_som)
	# Cada carro com o motor dele. Mesma semente da lataria e da buzina,
	# entao o carro que passou soa igual quando passar de novo.
	_som.caracterizar(semente, _motor.giro_corte)
	# Quatro em linha, tres cilindros no hatch 1.0, boxer a ar no Fusca: cada
	# um tem o proprio banco de amostras (PLANO_CARROS_AAA, F12).
	_som.definir_arquitetura(MotorSom.arquitetura_de(modelo))

	_buzina = AudioStreamPlayer3D.new()
	_buzina.name = "Buzina"
	_buzina.bus = &"SFX"
	_buzina.max_distance = 60.0
	_buzina.unit_size = 8.0
	_buzina.volume_db = -6.0
	# Buzina de carro passando SOBE e desce de tom. E o exemplo de livro do
	# efeito Doppler e o unico som do transito em que ele e obvio.
	_buzina.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	add_child(_buzina)

	# A voz do motorista sai de dentro do carro, abafada pela distancia curta.
	# E a mesma voz do pedestre: quem esta dirigindo e uma pessoa do registro.
	_voz = Voz.new()
	_voz.name = "Voz"
	_voz.max_distance = 11.0
	add_child(_voz)
	if not ficha.is_empty():
		_voz.configurar(ficha)


func _montar_gatilho() -> void:
	_gatilho = Gatilho.new()
	_gatilho.name = "Gatilho"
	_gatilho.dono = self
	add_child(_gatilho)
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(float(_medidas["largura"]) + 1.0, 2.0,
		float(_medidas["comprimento"]) + 0.6)
	forma.shape = caixa
	forma.position = Vector3(0.0, 0.9, 0.0)
	_gatilho.add_child(forma)


## O rastro de pneu, montado na primeira vez que alguem assume o volante.
##
## Tarde, e nao no `_ready`, porque ele so serve a quem dirige — e sao seis
## carros na rua para um ao volante. Uma vez montado ele NAO e desmontado ao
## descer: as marcas continuam no chao desbotando, e quem as apaga e o tempo.
func _montar_rastro() -> void:
	if _rastro != null:
		return
	_rastro = RastroPneu.new()
	_rastro.name = "Rastro"
	add_child(_rastro)
	_rastro.acompanhar(self, _rodas)


## O motorista visivel atras do vidro.
##
## E o mesmo Corpo do pedestre, sentado ao volante no banco do interior. Antes
## ele ficava de pe afundado 36 cm, com a canela atravessando o assoalho — com o
## vidro opaco ninguem via o resto, mas a perna aparecia debaixo do carro.
func _montar_motorista() -> void:
	if _motorista_corpo != null or ficha.is_empty():
		return
	_motorista_corpo = Corpo.new()
	_motorista_corpo.name = "Motorista"
	add_child(_motorista_corpo)
	_motorista_corpo.montar(ficha.get("aparencia", {}))
	sentar(_motorista_corpo, _medidas)


## A articulacao do quadril fica acima da almofada: e a espessura da coxa.
const QUADRIL_SOBRE_BANCO := 0.07


## Poe um Corpo sentado ao volante, no banco que `Carroceria.montar` desenhou.
##
## Volante a esquerda: com a frente em -Z, o banco do motorista fica em -X.
static func sentar(gente: Corpo, medidas: Dictionary) -> void:
	var banco: Vector3 = medidas.get("banco_motorista",
		Vector3(-float(medidas["largura"]) * 0.24, 0.46,
			-float(medidas["comprimento"]) * 0.04))
	gente.altura_assento = 0.30
	gente.postura(Corpo.Postura.DIRIGINDO)
	# O Corpo so escreve a pose quando e animado, e ninguem anima o motorista:
	# sem esta chamada ele continuava de pe, com a cabeca furando o teto.
	gente.animar(0.0, 0.0)
	# A pose poe o quadril em `altura_assento + 0.05` acima da origem do Corpo.
	gente.position = Vector3(banco.x,
		banco.y - gente.altura_assento - 0.05 + QUADRIL_SOBRE_BANCO, banco.z)
	gente.set_meta(&"lugar_no_banco", gente.position)
	afastar_da_porta(gente, medidas, medidas.get("batidas", []))


## O motorista sai do caminho da porta amassada (PLANO_CARROS_AAA, F8).
##
## O banco e o forro amassam junto com a chapa (`Amassado` desloca inteiro ate
## 25 cm de profundidade), mas o `Corpo` e um boneco articulado e nao deforma:
## com a porta do motorista afundada, a canela dele atravessava a lataria e
## aparecia como uma mancha cinza na soleira. Isolado por camada: sem o
## motorista a mancha sumia, sem o interior nao. Aqui o boneco inteiro anda para
## dentro o quanto o amassado anda na altura da perna, do lado da porta.
static func afastar_da_porta(gente: Corpo, medidas: Dictionary, batidas: Array) -> void:
	var base: Vector3 = gente.get_meta(&"lugar_no_banco", gente.position)
	gente.set_meta(&"lugar_no_banco", base)
	if batidas.is_empty():
		gente.position = base
		return
	var campo := Amassado.new()
	campo.batidas.assign(batidas)
	var banco: Vector3 = medidas.get("banco_motorista", base)
	var porta := signf(banco.x) if absf(banco.x) > 0.01 else -1.0
	var maior := 0.0
	for dz: float in [-0.55, -0.35, -0.15, 0.05]:
		for y: float in [0.35, 0.5, 0.65]:
			var p := Vector3(banco.x + porta * 0.24, y, banco.z + dz)
			var d := campo.deslocamento(p)
			# So o que empurra para DENTRO do carro conta.
			var para_dentro := -d.x * porta
			maior = maxf(maior, para_dentro)
	gente.position = base - Vector3(porta * maior, 0.0, 0.0)


func _tirar_motorista() -> void:
	if _motorista_corpo != null:
		_motorista_corpo.queue_free()
		_motorista_corpo = null


# --- quem dirige ------------------------------------------------------------

## Congela o corpo para a IA (ou o descongela para o jogador).
##
## STATIC, e nao KINEMATIC — medido em 16/09/2026
## ----------------------------------------------
## Um `VehicleBody3D` congelado como CINEMATICO e PARADO fica com as velocidades
## do servidor de fisica NaN no segundo passo: o atrito lateral da roda divide
## pela massa inversa do corpo, que congelado e zero, e com o carro parado a
## velocidade relativa tambem e zero. Nada aparece — o no continua com a
## transformada certa —, so avisos de `Vector3 cannot be normalized` aos
## milhares. Quando o jogador toma um desses carros parados no semaforo, o NaN
## entra na integracao e o carro explode: a cidade descarrega, o velocimetro
## marca -9223372036854775808 e a janela trava. Zerar as velocidades na tomada
## NAO basta: as rodas ficam podres.
##
## `tests/spike_roda_sobre_congelado.gd` isola isso sem nada do jogo: parado e
## cinematico vira NaN; parado e STATIC fica finito, e tomado tambem; andando,
## os dois modos ficam finitos; e um carro dinamico batendo num STATIC para no
## mesmo ponto que batendo num cinematico.
func _congelar(sim: bool) -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = sim


## Prega o corpo onde ele esta, no no E no servidor de fisica.
##
## Congelar um corpo que estava SIMULANDO o devolve para a transformada que o
## servidor guarda, e ela pode nao ser a que o no mostra. Medido: ao descer do
## carro, a lataria saltava 21 m no quadro seguinte, de volta ao ponto em que o
## carro tinha NASCIDO — o jogador ficava plantado na rua vendo o carro que
## acabara de estacionar aparecer no fim da quadra. Em partida normal isso
## acontecia toda vez que alguem estacionava e descia, sem erro nenhum no log: o
## carro simplesmente estava noutro lugar.
##
## So vale na DEVOLUCAO, e nao em todo congelamento. No nascimento o carro e
## congelado antes de o transito lhe dar posicao, e pregar ali o prenderia na
## origem do mundo — foi o que a primeira tentativa deste conserto fez, e a
## medida acusou o carro inteiro parado em zero.
func _pregar_onde_esta() -> void:
	var onde := global_transform
	var corpo := get_rid()
	PhysicsServer3D.body_set_state(corpo,
		PhysicsServer3D.BODY_STATE_TRANSFORM, onde)
	PhysicsServer3D.body_set_state(corpo,
		PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(corpo,
		PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	global_transform = onde


## O rotulo do gatilho, agora com as teclas dentro.
##
## Ele devolvia "Abordar motorista" sem tecla nenhuma, e carro vazio devolvia
## VAZIO — porque a faixa colava "[E]  " em tudo e o prompt saia ensinando a
## tecla errada: "[E]  Entrar no carro  [F]". O carro vazio preferia nao dizer
## nada a dizer errado.
##
## A faixa parou de colar: `Cidade._mostrar_prompt` so acrescenta o "[E]" quando
## o rotulo nao traz tecla propria. Entao aqui cabe a frase inteira, e ela e a
## mesma que o jogador ve ao chegar perto sem estar olhando para a lataria —
## ver `Player._prompt_de_veiculo`. Duas fontes, um texto.
func rotulo_de_acao() -> String:
	if motorista == Motorista.IA:
		return "Tirar o motorista  [F]     Falar com ele  [E]"
	if motorista == Motorista.NINGUEM:
		return "Entrar no carro  [F]"
	return ""


func acionar(quem: Node) -> void:
	if motorista == Motorista.IA:
		_abordar(quem)


## Investigacao, nao assalto. O jogador nao arromba nada: ele se identifica, e o
## motorista sai. Por isso a acao passa pela Conversa e nao por um botao — a
## ficha do sujeito fica na tela, e ele continua existindo na cidade depois.
func _abordar(quem: Node) -> void:
	if Conversa.ativo or ficha.is_empty():
		return
	Conversa.abrir_veicular(self, quem)


## O motorista desce e vira pedestre de verdade. Nao e um boneco descartado: sai
## do registro com o mesmo id, entao da para segui-lo, falar com ele de novo e
## consultar o CPF dele no celular depois.
func expulsar_motorista() -> void:
	if motorista != Motorista.IA:
		return
	var quem := ficha
	motorista = Motorista.NINGUEM
	ligado = false
	_tirar_motorista()
	_velocidade = 0.0

	var p := Pedestre.new()
	p.name = "ex_motorista_%d" % int(quem.get("id", 0))
	var no := Rotas.no_mais_proximo(global_position)
	var vizinhos := Rotas.vizinhos(no)
	p.preparar(quem, no, vizinhos[0] if not vizinhos.is_empty() else no)
	# Do lado do motorista, meio metro para fora, ja fora da lataria.
	#
	# A posicao vai ANTES de entrar na arvore. Na ordem inversa o corpo nasce na
	# origem do pai e so depois e levado para o lado do carro — e, com o carro
	# em cima dessa origem, a fisica resolve a sobreposicao arremessando o carro
	# que o jogador acabou de tomar: medido, 69 m/s de lado, batida de forca 1,
	# motor afogado e lataria amassada. (tests/bancada_batida.gd)
	var onde := global_position - global_transform.basis.x * (
		float(_medidas["largura"]) * 0.5 + 0.55) + Vector3.UP * 0.1
	var pai := get_parent()
	p.position = (pai as Node3D).to_local(onde) if pai is Node3D else onde
	pai.add_child(p)
	# Entra na contabilidade da multidao. Sem isto ele fica na rua para sempre:
	# ninguem o recolhe quando o jogador vai embora, porque ninguem sabe que ele
	# existe.
	Multidao.adotar(p)
	ficha = {}
	motorista_saiu.emit(p)


## O jogador assume. Nada e recriado: o corpo rigido ja esta aqui, com a
## velocidade que tinha, e so deixa de ser cinematico.
##
## Havendo motorista, ele desce ANTES — e desce como pessoa, com o mesmo id do
## registro, e nao como boneco apagado. Ver `expulsar_motorista`.
func assumir(_quem: Node) -> void:
	if motorista == Motorista.IA:
		# A inercia atravessa a troca. Sem esta linha, tomar um carro em
		# movimento o para no lugar, e o corte de velocidade e a costura que o
		# cabecalho deste arquivo existe para nao ter.
		var v := _velocidade
		expulsar_motorista()
		_velocidade = v
		# Um carro que estava andando estava com o motor ligado. Fazer o jogador
		# dar a partida num carro que ele acabou de tomar em movimento seria
		# desligar o motor no momento exato em que ele assume o volante.
		ligado = true
	motorista = Motorista.JOGADOR
	_soltar_mola()
	_desligar_lod()
	_congelar(false)
	linear_velocity = -global_transform.basis.z * _velocidade
	_piloto_ligado = false
	_piloto = Vector3.ZERO
	_freio_mao = false
	_pe_acel = 0.0
	_pe_freio = 0.0
	_aderencia_tras = 1.0
	_derivando = false
	_torcao = PackedFloat32Array([NAN, NAN])
	# Bater precisa ser NOTADO, e so a partir daqui ha quem note.
	contact_monitor = true
	_montar_rastro()
	# A partir daqui o motor e do jogador: camadas de som completas, rotacao de
	# verdade e curva de torque. O carro da IA nao paga nada disso.
	_som.detalhar()
	_som.acordar()
	if ligado:
		_motor.ligar()
	# A cabine, a agua do vidro e a vista de dentro: so o carro do jogador paga.
	CabineDoJogador.desmontar(_cabine_jogador)
	_cabine_jogador = CabineDoJogador.montar(self, _medidas, _quem)
	if _interior != null:
		_interior.visible = false
	# A lataria e lida uma vez, aqui, e nao na hora da batida: ler malha de
	# volta do servidor de renderizacao trava o quadro. So o carro do jogador
	# paga, porque so ele sente batida.
	var lataria: Array[MeshInstance3D] = [_corpo_malha]
	_amassado.preparar(self, lataria)
	if not _amassado.amassou.is_connected(_ao_amassar):
		_amassado.amassou.connect(_ao_amassar)
	# Cabine nova, lataria velha: as batidas de antes entram de novo nela, senao
	# o forro da porta volta liso dentro de uma porta amassada.
	_amassado.reaplicar(self, _pecas_da_cabine())


func devolver() -> void:
	_pisca_lado = 0
	CabineDoJogador.desmontar(_cabine_jogador)
	_cabine_jogador = null
	if _interior != null:
		_interior.visible = true
	motorista = Motorista.NINGUEM
	_congelar(true)
	_pregar_onde_esta()
	_velocidade = 0.0
	ligado = false
	_freio_mao = false
	_piloto_ligado = false
	engine_force = 0.0
	steering = 0.0
	_motor.desligar()
	_som.desligar()
	contact_monitor = false


func alternar_ignicao() -> void:
	ligado = not ligado
	if ligado:
		_motor.ligar()
		_som.partir()
	else:
		_motor.desligar()
		_som.desligar()


## Onde o jogador aparece ao sair. Do lado do motorista e, se ali houver parede,
## do outro lado — sair para dentro de um muro empurra o corpo para dentro do
## predio, e a recuperacao de penetracao o cospe no telhado.
func ponto_de_saida() -> Vector3:
	# Os lados sao os do CARRO, mas achatados no plano do mundo.
	#
	# Com o carro de rodas para cima, o eixo X local aponta para o outro lado e o
	# Y local aponta para o chao: a conta antiga cuspia o jogador para dentro do
	# asfalto, e a rede de seguranca — "global_position + UP * 1,2" — o punha
	# DEBAIXO da lataria virada. Descer de um carro capotado nao pode ser um beco
	# sem saida, e era: a unica saida era fechar o jogo.
	var meia := float(_medidas["largura"]) * 0.5 + 0.7
	var eixo := global_transform.basis.x
	eixo.y = 0.0
	if eixo.length() < 0.1:
		# Carro de lado: o X local virou vertical. Usa o rumo da frente girado.
		eixo = Vector3(-global_transform.basis.z.z, 0.0, global_transform.basis.z.x)
	if eixo.length() < 0.1:
		eixo = Vector3.RIGHT
	var lado := eixo.normalized() * meia

	var espaco := get_world_3d().direct_space_state
	var olho := global_position + Vector3.UP * 0.9
	for tentativa: Vector3 in [-lado, lado]:
		var consulta := PhysicsRayQueryParameters3D.create(
			olho, olho + tentativa, 1)
		consulta.exclude = [get_rid()]
		if espaco.intersect_ray(consulta).is_empty():
			return global_position + tentativa
	# Nada livre dos dois lados: sobe. A altura sai da lataria, e nao de um 1,2
	# fixo, senao um carro capotado — que e mais alto do que largo — engole o
	# jogador.
	return global_position + Vector3.UP * (float(_medidas["altura"]) + 0.4)


func assento() -> Vector3:
	return global_position - global_transform.basis.x * (
		float(_medidas["largura"]) * 0.22) + Vector3.UP * 0.5


## O carro esta de rodas para cima (ou de lado)?
##
## 0,25 de produto escalar sao uns 75 graus fora do prumo: dai em diante nao ha
## roda tocando o chao e o carro nao volta sozinho.
func capotado() -> bool:
	return global_transform.basis.y.dot(Vector3.UP) < 0.25


func velocidade() -> float:
	return _velocidade


func marcha() -> int:
	return _motor.marcha


## O que o painel escreve no lugar da marcha: "R" na re, o numero no resto.
func rotulo_marcha() -> String:
	return _motor.rotulo_marcha()


func giro() -> float:
	return _motor.giro


## Onde o ponteiro do conta-giros para, de 0 a 1.
func giro_normalizado() -> float:
	return _motor.giro_normalizado()


## Onde a zona vermelha do conta-giros comeca, de 0 a 1.
##
## Sai do motor DESTE carro: um Fusca corta em 4700 e um Marea em 7000, e um
## mostrador que desenha a mesma zona vermelha nos dois esta mentindo sobre o
## carro em que o jogador esta sentado.
func vermelho_normalizado() -> float:
	return clampf(_motor.giro_vermelho / maxf(1.0, _motor.giro_fundo), 0.0, 1.0)


## Fundo de escala do conta-giros, em rpm. O painel escreve os riscos com isto.
func giro_de_fundo() -> float:
	return _motor.giro_fundo


func de_re() -> bool:
	return _motor.re


func freio_de_mao() -> bool:
	return _freio_mao


## O motor esta com a faisca cortada — limitador ou troca. E o que acende a luz
## de troca no painel.
func cortando() -> bool:
	return _motor.cortado()


# --- piloto automatico -------------------------------------------------------

## Assume os comandos no lugar do teclado.
##
## Existe para o teste automatizado, e o desenho e deliberado: ele injeta no
## MESMO ponto em que o teclado entra, e nao no `engine_force`. Um teste que
## escreve forca direto no corpo rigido aprova um carro cujo acelerador nao esta
## ligado em nada — e era exatamente esse o estado deste arquivo.
##
## `acelera` e `freia` sao 0..1; `esterco` e -1 (esquerda) a +1 (direita).
func pilotar(acelera: float, freia: float, esterco: float) -> void:
	_piloto_ligado = true
	_piloto = Vector3(clampf(acelera, 0.0, 1.0), clampf(freia, 0.0, 1.0),
		clampf(esterco, -1.0, 1.0))


## Devolve o carro ao teclado.
func soltar_piloto() -> void:
	_piloto_ligado = false
	_piloto = Vector3.ZERO


## Quantas vezes o cambio trocou desde que o carro nasceu.
## Poe o carro parado num lugar, apontando para um rumo, sem deixar resto.
##
## Escrever `global_transform` num corpo rigido solto nao basta: o servidor de
## fisica ja tem um estado para aquele corpo neste passo, e a velocidade
## anterior sobrevive ao teleporte. Foi o que aconteceu na medida de arrancada —
## o carro era posto na faixa "parado" e aparecia a 15 m/s meio segundo depois,
## ainda na marcha em que estava. Por isso o estado vai pelo servidor, e nao so
## pelo no.
##
## `rumo` e o angulo em torno de Y que poe a FRENTE do carro (-Z) na direcao
## desejada.
func pousar(onde: Vector3, rumo: float, tombo: float = 0.0) -> void:
	# `tombo` gira o carro em torno do proprio eixo comprido. Serve para POR o
	# carro capotado de proposito — sem isso nao ha como medir o que acontece
	# quando ele vira, e virar e o unico estado do carro em que o jogador podia
	# ficar preso.
	var t := Transform3D(Basis(Vector3.UP, rumo) * Basis(Vector3.BACK, tombo),
		onde)
	global_transform = t
	var corpo := get_rid()
	PhysicsServer3D.body_set_state(corpo,
		PhysicsServer3D.BODY_STATE_TRANSFORM, t)
	PhysicsServer3D.body_set_state(corpo,
		PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(corpo,
		PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_velocidade = 0.0
	_giro = rumo
	engine_force = 0.0
	steering = 0.0
	if ligado:
		_motor.ligar()


## Poe este carro da IA numa faixa, apontando por ela, e refaz a rota do zero.
##
## Existe para o teste automatizado do transito. Sem ele nao ha como MONTAR a
## situacao que produz o defeito — um carro chegando por tras de outro que
## parou na pista, ou um carro entrando numa aproximacao de cruzamento no
## vermelho —, e a alternativa e esperar o transito produzi-la sozinho, que nao
## acontece em toda execucao. Um teste que so mede o que o acaso ofereceu e um
## teste que passa verde no dia em que o acaso nao oferece.
##
## Ver `src/levels/teste_transito.gd`.
func plantar(de: Vector2i, t: Vector4i, onde: Vector3) -> void:
	cruzamento = de
	trecho = t
	_tem_rota = false
	_curvando = false
	_tem_plano = false
	_aproxima = Vector2i.ZERO
	_contorno = 0.0
	_contornado = null
	_parado = 0.0
	global_position = onde
	_iniciar_rota()
	_alinhar_na_faixa()
	_velocidade = _teto_de_velocidade()


## A que distancia esta o que ha na frente, em metros. INF quando nao ha nada.
## O teste do transito le para separar "parou atras de alguem" de "parou no
## sinal" e de "parou por nada".
func obstaculo_a_frente() -> float:
	return _obst_dist


## Por que este carro nao esta a toda. Ver `_motivo`.
func motivo_da_parada() -> StringName:
	return _motivo


## Esta contornando alguma coisa agora?
func contornando() -> bool:
	return _contorno > 0.0


## O que o motor esta tocando agora. Ver `MotorSom.diagnostico`.
func som_diagnostico() -> Dictionary:
	return _som.diagnostico() if _som != null else {}


## Quantos fachos de farol este carro tem acesos.
##
## Fecha a ultima folga da medida de farol: a bancada prova que a carroceria
## declara dois farois, isto prova que o carro MONTOU os dois cones. Entre uma
## coisa e outra ha uma ordem de inicializacao que ja errou uma vez.
func fachos_acesos() -> int:
	var n := 0
	for f: MeshInstance3D in _fachos:
		if f.visible:
			n += 1
	return n


## Atrito que as rodas estao usando agora. O teste le para conferir que a chuva
## chegou ate elas.
func atrito_das_rodas() -> float:
	return _rodas[0].wheel_friction_slip if not _rodas.is_empty() else 0.0


## Puxa ou solta o freio de mao de fora do teclado, para o piloto automatico.
func puxar_freio_de_mao(sim: bool) -> void:
	_freio_mao = sim and ligado


## Quanto o pneu esta escorregando agora, de 0 a 1.
##
## `VehicleWheel3D.get_skidinfo()` devolve 1 com a roda agarrada e cai para 0
## quando ela desliza. A media aqui e a do PIOR eixo, e nao a das quatro: numa
## derrapagem de traseira as duas da frente continuam agarradas, e a media das
## quatro diluiria justo o que se quer ouvir.
func escorregamento() -> float:
	if _rodas.size() < 4:
		return 0.0
	# Sem alocar lista de pares: isto roda todo quadro de fisica do carro que o
	# jogador esta dirigindo, e uma lista literal nova por quadro e lixo que o
	# coletor vai buscar no pior momento — durante a carga de um chunk.
	var pior := 0.0
	for eixo in 2:
		var soma := 0.0
		var n := 0
		for lado in 2:
			var r := _rodas[eixo * 2 + lado]
			if not r.is_in_contact():
				continue
			soma += 1.0 - clampf(r.get_skidinfo(), 0.0, 1.0)
			n += 1
		if n > 0:
			pior = maxf(pior, soma / float(n))
	return pior


## O maior escorregamento de UMA roda, de 0 a 1.
##
## Diferente de `escorregamento()`, que e a media do pior eixo. Os dois numeros
## existem porque duas coisas diferentes perguntam: o SOM quer saber o quanto o
## carro esta escorregando como um todo — media —, e a MARCA de pneu e por
## roda, porque so a roda que deslizou deixa borracha. Ajustar o limiar da
## marca pela media derruba o rastro justo na manobra em que uma roda so
## desliza, que e toda derrapagem de traseira.
func escorrega_por_roda() -> float:
	var pior := 0.0
	for r: VehicleWheel3D in _rodas:
		if r.is_in_contact():
			pior = maxf(pior, 1.0 - clampf(r.get_skidinfo(), 0.0, 1.0))
	return pior


## Quantas das quatro rodas estao tocando o chao.
##
## Um `VehicleBody3D` com a roda no ar nao acelera, por maior que seja a forca —
## e esse e o modo de falha que parece motor fraco e nao e. O teste le isto para
## saber de qual dos dois esta falando.
func rodas_no_chao() -> int:
	var n := 0
	for r: VehicleWheel3D in _rodas:
		if r.is_in_contact():
			n += 1
	return n


## Quantos pedacos de marca de pneu este carro ja deixou no asfalto.
func marcas_de_pneu() -> int:
	return _rastro.marcas() if _rastro != null else 0


## Quantos bafos de fumaca de pneu ja sairam.
func bafos_de_pneu() -> int:
	return _rastro.bafos() if _rastro != null else 0


## O que o rastro tem montado. Ver `RastroPneu.diagnostico`.
func rastro_diagnostico() -> Dictionary:
	return _rastro.diagnostico() if _rastro != null else {}


## O meio do rastro de pneu deste carro, em coordenada de mundo.
func centro_do_rastro() -> Vector3:
	return _rastro.centro_das_marcas() if _rastro != null else global_position


## Altura em que o pedaco mais novo de marca foi assentado, em Y de mundo. O
## teste compara com o asfalto para provar que a marca ficou no CHAO.
func altura_da_marca() -> float:
	return _rastro.altura_da_ultima() if _rastro != null else NAN


func trocas_de_marcha() -> int:
	return _motor.trocas


## Quantas vezes o limitador cortou.
func cortes_de_giro() -> int:
	return _motor.cortes


## Maior rotacao que este motor ja viu.
func giro_maximo_visto() -> float:
	return _motor.giro_maximo


# --- ciclo ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_vivo += delta
	_desde_buzina += delta
	match motorista:
		Motorista.JOGADOR:
			_dirigir_jogador(delta)
		Motorista.IA:
			_dirigir_ia(delta)
		_:
			_velocidade = lerpf(_velocidade, 0.0, minf(1.0, 3.0 * delta))
	_sentir_batida(delta)
	if _rastro != null:
		_rastro.passo(delta, motorista == Motorista.JOGADOR)
	_girar_rodas(delta)
	_atualizar_luzes()
	_soar(delta)
	_assustar_quem_esta_perto()


## Bateu?
##
## A medida e a QUEDA de velocidade num quadro, e nao o sinal de contato. Contato
## existe o tempo todo — as quatro rodas tocam o chao — e um carro encostando num
## meio-fio a 2 km/h tambem gera contato. O que separa batida de encosto e
## quanta velocidade o carro perdeu de um quadro para o outro: 11 m/s viram zero
## num quadro so quando se bate numa parede.
##
## So vale para quem esta ao volante. O carro da IA e cinematico, nao perde
## velocidade por colisao, e um estrondo vindo do transito sem nada acontecendo
## seria ruido puro.
func _sentir_batida(delta: float) -> void:
	_desde_batida += delta
	if motorista != Motorista.JOGADOR:
		_vel_anterior = linear_velocity
		return
	var perda := _vel_anterior - linear_velocity
	var perdeu := perda.length()
	_vel_anterior = linear_velocity
	if perdeu < BATIDA_MINIMA or _desde_batida < BATIDA_ESPERA:
		return
	if get_contact_count() <= 0:
		return
	_desde_batida = 0.0
	var forca := clampf((perdeu - BATIDA_MINIMA)
		/ (BATIDA_FORTE - BATIDA_MINIMA), 0.0, 1.0)
	_som.bateu(forca)
	bateu.emit(forca)
	_amassar(perda, forca)
	# O carro em que se bateu tambem amassa (PLANO_CARROS_AAA, F8). Antes so o
	# do jogador marcava: o sedan da rua saia liso de uma batida que afundou o
	# para-choque de quem bateu nele.
	for outro: Node in get_colliding_bodies():
		if outro != self and outro is Carro:
			(outro as Carro).levar_batida(global_position, forca)
	# Pancada em cheio afoga o motor. Precisa dar a partida de novo, e esse
	# meio segundo de silencio depois do estrondo e o que separa "bati" de
	# "encostei" melhor do que qualquer numero na tela.
	if forca > 0.75 and ligado:
		ligado = false
		_motor.desligar()
		_som.desligar()


## A chapa amassa do lado que bateu. Ver `Amassado`.
##
## O lado sai da velocidade PERDIDA, e nao de um ponto de contato: o carro que
## andava para a frente e parou de golpe perdeu velocidade para a frente, entao
## bateu com a frente. E a mesma conta que ja decide se houve batida, e dispensa
## pedir ao servidor de fisica a lista de contatos no quadro certo.
##
## A altura e a do para-choque (35% da lataria): e o para-choque que encosta na
## parede, no poste e no carro da frente. A componente vertical e descartada —
## cair de uma lombada perde velocidade para baixo, e o fundo do carro nao se
## ve.
func _amassar(perda: Vector3, forca: float) -> void:
	if _corpo_malha == null or _corpo_malha.mesh == null:
		return
	var dir := global_transform.basis.inverse() * perda
	var horizontal := Vector3(dir.x, 0.0, dir.z)
	if horizontal.length() < 0.3 * dir.length() or horizontal.length_squared() < 1e-6:
		return
	_amassar_para(horizontal.normalized(), forca)


## Amassa a chapa do lado `dir` (espaco do carro, no plano do chao), e trinca o
## vidro daquele lado se a pancada foi forte.
func _amassar_para(dir: Vector3, forca: float) -> void:
	var caixa := _corpo_malha.mesh.get_aabb()
	var meio := caixa.get_center()
	meio.y = caixa.position.y + caixa.size.y * 0.35
	var meia := caixa.size * 0.5
	var t := INF
	if absf(dir.x) > 1e-4:
		t = minf(t, meia.x / absf(dir.x))
	if absf(dir.z) > 1e-4:
		t = minf(t, meia.z / absf(dir.z))
	var ponto := meio + dir * t
	# So enfileira: a conta roda numa thread e volta por `_ao_amassar`.
	_amassado.bater(ponto, -dir, forca)
	if forca >= TRINCA_FORCA:
		_trincar(ponto, forca)


## Os amassados de fabrica deste carro: [direcao no plano do chao, forca]. So o
## carro da rua os tem — o da bancada e o do jogador nascem lisos, e e com eles
## que as medidas de amassado sao feitas. Pela semente: o mesmo carro volta com
## a mesma porta afundada.
func _amassados_de_fabrica() -> Array:
	var out: Array = []
	if motorista != Motorista.IA:
		return out
	var h := absi(semente * 2246822519 + 7)
	if h % AMASSADO_DE_FABRICA_EM != 0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = h
	var n := 1 + rng.randi() % AMASSADOS_DE_FABRICA_MAX
	for k in n:
		var a := rng.randf() * TAU
		out.append([Vector3(sin(a), 0.0, cos(a)), rng.randf_range(0.20, 0.38)])
	return out


## Levou uma pancada de outro carro, vinda de `de_onde` (mundo). Ver `F8` no
## PLANO_CARROS_AAA. So o carro da rua: o do jogador ja amassa pelo proprio
## `_sentir_batida`.
func levar_batida(de_onde: Vector3, forca: float) -> void:
	if motorista == Motorista.JOGADOR or _corpo_malha == null:
		return
	var dir := global_transform.basis.inverse() * (de_onde - global_position)
	dir.y = 0.0
	if dir.length_squared() < 1e-6:
		return
	# A malha do carro da rua so e lida na primeira batida: ler malha de volta
	# do servidor custa, e a maioria dos carros nunca leva uma.
	if not _amassado_pronto:
		_amassado_pronto = true
		var alvos: Array[MeshInstance3D] = [_corpo_malha]
		if _corpo_longe != null:
			alvos.append(_corpo_longe)
		# O banco a cinco centimetros da porta amassa junto, senao atravessa.
		if _interior != null:
			alvos.append(_interior)
		_amassado.preparar(self, alvos)
		if not _amassado.amassou.is_connected(_ao_amassar):
			_amassado.amassou.connect(_ao_amassar)
	_amassar_para(dir.normalized(), forca)


## A trinca no vidro mais perto da pancada (F8).
##
## Uma so por carro, a mais forte: vidro de carro trinca uma vez e fica
## trincado. O desenho e do `psx_carro_vidro` (MODERNO), lido de um parametro
## por instancia; no PS1 o vidro e opaco e nao trinca.
func _trincar(ponto: Vector3, forca: float) -> void:
	var forca_trinca := clampf((forca - TRINCA_FORCA) / (1.0 - TRINCA_FORCA), 0.25, 1.0)
	if forca_trinca <= _trinca.w:
		return
	var melhor := INF
	var alvo := Vector3.ZERO
	for a: Dictionary in _medidas.get("aberturas", []):
		var c: Vector3 = a["centro"]
		var d := c.distance_to(ponto)
		if d < melhor:
			melhor = d
			alvo = c
	if melhor == INF:
		return
	# O ponto da trinca anda do meio do vidro para o lado da pancada.
	var centro := alvo.lerp(Vector3(ponto.x, alvo.y, ponto.z), 0.25)
	_trinca = Vector4(centro.x, centro.y, centro.z, forca_trinca)
	_corpo_malha.set_instance_shader_parameter(&"trinca", _trinca)
	if _corpo_longe != null:
		_corpo_longe.set_instance_shader_parameter(&"trinca", _trinca)


## Chega quando a malha amassada ja esta na tela.
func _ao_amassar(maior: float) -> void:
	_ultimo_amassado = maior
	_custo_amassado_ms = _amassado.custo_principal_ms
	_atraso_amassado_ms = _amassado.atraso_ms
	_amassar_luzes()
	# O motorista da rua sai do caminho da porta que acabou de afundar. A mola
	# guarda a posicao de base dele; ela anda junto.
	if _motorista_corpo != null and is_instance_valid(_motorista_corpo):
		var antes := _motorista_corpo.position
		var mola_antes: Transform3D = _mola_base.get(_motorista_corpo, Transform3D.IDENTITY)
		if _mola_base.has(_motorista_corpo):
			_motorista_corpo.position = mola_antes.origin
		afastar_da_porta(_motorista_corpo, _medidas, _amassado.batidas)
		if _mola_base.has(_motorista_corpo):
			mola_antes.origin = _motorista_corpo.position
			_mola_base[_motorista_corpo] = mola_antes
			_motorista_corpo.position = antes
			_aplicar_mola()


## As pecas da cabine do jogador, se houver cabine.
func _pecas_da_cabine() -> Array[MeshInstance3D]:
	var pecas: Array[MeshInstance3D] = []
	if _cabine_jogador != null and is_instance_valid(_cabine_jogador):
		for no: Node in _cabine_jogador.find_children("*", "MeshInstance3D", true, false):
			pecas.append(no as MeshInstance3D)
	return pecas


## O farol e a lanterna amassam junto, mas por aqui e nao pela thread.
##
## `_aplicar_atlas_lanternas` remonta a malha de luzes a partir de `_luz_arrays`,
## trocando a celula do atlas por INDICE de vertice. Dividir essa malha
## quebraria a conta, e amassar a malha por fora seria desfeito na primeira
## pisada no freio. Entao o amassado entra direto em `_luz_arrays`, a partir das
## posicoes de nascimento, e a chave zerada obriga a remontagem no proximo
## quadro — o farol acompanha o para-choque em vez de boiar na frente dele.
func _amassar_luzes() -> void:
	if _luz_arrays.is_empty() or _luzes == null:
		return
	var v: PackedVector3Array = (_luz_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	if _luz_originais.is_empty():
		_luz_originais = v.duplicate()
	_amassado.deslocar(v, _luz_originais,
		global_transform.affine_inverse() * _luzes.global_transform)
	_luz_arrays[Mesh.ARRAY_VERTEX] = v
	_luz_chave = -1


func amassado() -> Amassado:
	return _amassado


func ultimo_amassado() -> float:
	return _ultimo_amassado


## Quanto a ultima rodada de amassado custou no quadro principal, e quanto
## levou da pancada ate a tela, em milissegundos.
func custo_amassado_ms() -> float:
	return _custo_amassado_ms


func atraso_amassado_ms() -> float:
	return _atraso_amassado_ms


## O som, e os dois eventos que so existem no instante em que acontecem.
##
## Troca e corte sao BORDAS, e nao estados: perguntar todo quadro "esta
## cortando?" e tocar quando sim daria sessenta batidas por segundo. Por isso o
## que dispara e o contador do motor ter subido desde o quadro anterior.
func _soar(delta: float) -> void:
	var acesa := ligado or motorista == Motorista.IA
	if motorista == Motorista.JOGADOR:
		if _motor.trocas > _trocas_vistas:
			_som.trocou()
		if _motor.cortes > _cortes_vistos:
			_som.cortou()
		_trocas_vistas = _motor.trocas
		_cortes_vistos = _motor.cortes
		_som.atualizar(_motor.giro, _motor.carga(), _velocidade, acesa,
			_motor.cortado(), escorregamento(), delta)
		return
	# Carro da rua: nao ha maquina rodando, mas ha velocidade. A rotacao
	# aparente e a que aquela velocidade daria no mesmo cambio, para o carro que
	# passa soar como carro que passa e nao como afinacao sorteada.
	#
	# A carga sai do que a velocidade esta fazendo: saindo do sinal o motor
	# puxa, em cruzeiro ele so segura, freando ele quase cala. Antes era uma
	# rampa da velocidade, e o carro que freava soava igual ao que acelerava.
	var dv := (_velocidade - _vel_som_antes) / maxf(delta, 1e-4)
	_vel_som_antes = _velocidade
	var acelerando := dv > 0.6
	var carga := 0.85 if acelerando else (0.08 if dv < -0.6 else 0.28)
	_som.atualizar(Motor.giro_aparente(_velocidade, modelo, acelerando),
		carga, _velocidade, acesa, false, 0.0, delta)


# --- direcao do jogador -----------------------------------------------------

## Os comandos deste quadro: acelerador, freio e volante.
##
## Vem do teclado, ou do piloto automatico quando o teste esta dirigindo. E o
## unico lugar em que os dois caminhos se encontram, de proposito: o que o teste
## exercita tem de ser o mesmo que a mao do jogador exercita.
func _comandos() -> Vector3:
	if _piloto_ligado:
		return _piloto
	return Vector3(
		Input.get_action_strength(&"mover_frente"),
		Input.get_action_strength(&"mover_tras"),
		Input.get_action_strength(&"mover_dir")
			- Input.get_action_strength(&"mover_esq"))


func _dirigir_jogador(delta: float) -> void:
	_velocidade = linear_velocity.dot(-global_transform.basis.z)
	_seta_do_jogador(delta)
	# Carro capotado nao tem motor rodando. Nao e so realismo de bomba de oleo:
	# um carro de pernas para o ar acelerando e roncando e a coisa mais absurda
	# que esta fisica consegue produzir, e o silencio subito e o que diz ao
	# jogador que a brincadeira acabou e que ele precisa sair dali.
	if ligado and capotado():
		ligado = false
		_motor.desligar()
		_som.desligar()
	var c := _comandos()
	_pe_acel = _pisar(_pe_acel, c.x, PEDAL_SOBE, PEDAL_DESCE, delta)
	_pe_freio = _pisar(_pe_freio, c.y, FREIO_SOBE, FREIO_DESCE, delta)
	c.x = _pe_acel
	c.y = _pe_freio
	# Com o piloto automatico dirigindo, quem manda no freio de mao e ele — ver
	# `puxar_freio_de_mao`. Ler o teclado aqui apagaria o comando do teste no
	# quadro seguinte ao que ele o deu.
	if not _piloto_ligado:
		_freio_mao = Input.is_action_pressed(&"correr") and ligado

	var forca := _motor.passo(c.x, c.y, _velocidade, delta)
	_re = _motor.re
	_freando = _motor.travao > 0.1 and absf(_velocidade) > 0.3

	if ligado:
		# O sinal e invertido, e nao e descuido.
		#
		# `VehicleBody3D` empurra o corpo para +Z com `engine_force` positivo —
		# medido, nao suposto: um veiculo minimo num chao plano com forca +1500
		# andou 3,26 m em +Z em um segundo e meio. A frente DESTE carro e -Z, que
		# e a convencao de toda a Carroceria, das rodas, do farol e da mira da IA
		# (`atan2(-para.x, -para.z)`). Sem a inversao o carro acelera de re com o
		# modelo apontando para a frente, e foi o que a primeira pilotagem
		# mediu: velocidade de -14,4 m/s com forca de tracao positiva.
		#
		# Inverte-se aqui, e nao no `Motor`: la a forca e fisica, e positivo
		# significa para a frente. Quem sabe para que lado "a frente" aponta e o
		# carro, porque e ele que tem a lataria.
		#
		# Com o pe no freio a tracao vai a ZERO, e isso tambem e medido: no
		# `VehicleBody3D` uma roda com `engine_force` nao nulo aplica um atrito
		# de rolamento no lugar do freio, e o freio quase desaparece. O mesmo
		# corpo de 980 kg vindo de 14 m/s parou em 7,0 m com tracao zerada e em
		# 12,8 m com apenas -50 N de tracao residual. No jogo o residuo era o
		# freio motor, umas oito vezes maior, e a freada media saiu em 38 m.
		#
		# Nao se perde nada: freio motor e freio de pedal nunca sao usados ao
		# mesmo tempo por ninguem.
		if _motor.travao > 0.02:
			engine_force = 0.0
			brake = _freio_na_pista() * _motor.travao
		elif c.x < 0.05 and c.y < 0.05 and absf(_velocidade) < SEGURA_RAMPA_VEL:
			# Parado e sem pe em pedal nenhum: segura na rampa. Na ladeira do
			# morro (Relevo) o carro sem isto descia de re sozinho — tracao zero,
			# freio zero e rolamento zero no VehicleBody3D. Soltou o pe do
			# acelerador em movimento, ele ainda roda livre; so o carro quase
			# parado e travado, que e o que o freio de estacionamento de quem
			# para na subida faz.
			engine_force = 0.0
			brake = _freio_na_pista() * SEGURA_RAMPA
		else:
			engine_force = -forca
			brake = 0.0
	else:
		# Motor desligado nao e ponto morto: o carro anda por inercia e para.
		engine_force = 0.0
		brake = _freio_na_pista() * maxf(_motor.travao, 0.12)

	_esterco(c.z, delta)
	_freiar_com_a_mao()
	_aderir_traseira(delta)
	_estabilizar(delta)
	_arrastar(delta)


## Um pedal andando para onde o pe manda, com curso. Ver `PEDAL_SOBE`.
static func _pisar(agora: float, quero: float, sobe: float, desce: float,
		delta: float) -> float:
	var taxa := sobe if quero > agora else desce
	return move_toward(agora, quero, taxa * delta)


## O volante.
##
## O curso fecha com a velocidade — sem isso, a 90 km/h um toque na tecla joga o
## carro de lado — e volta ao centro mais depressa do que sai dele, porque
## soltar a tecla tem de parecer soltar o volante.
## A seta do jogador: relogio e desligamento automatico.
##
## Ate aqui so o carro da IA piscava — `_atualizar_pisca` mora dentro de
## `_dirigir_ia` —, e o jogador nao tinha tecla nem lampada. A seta desliga
## sozinha quando o volante volta ao centro DEPOIS de ter virado para o lado
## dela, como a came de retorno da coluna de direcao.
func _seta_do_jogador(delta: float) -> void:
	_pisca_tempo += delta
	if _pisca_lado == 0:
		_pisca_virou = false
		return
	# `steering` fica negativo virando para a direita (ver `_esterco`).
	var para_o_lado := -steering * float(_pisca_lado)
	if para_o_lado > PISCA_CURVA:
		_pisca_virou = true
	elif _pisca_virou and absf(steering) < PISCA_RETO:
		_pisca_lado = 0
		_pisca_virou = false


func _unhandled_input(evento: InputEvent) -> void:
	if motorista != Motorista.JOGADOR:
		return
	if evento.is_action_pressed(&"seta_esquerda"):
		ligar_seta(-1)
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed(&"seta_direita"):
		ligar_seta(1)
		get_viewport().set_input_as_handled()


## Liga a seta de um lado; o mesmo lado de novo desliga. -1 esquerda, 1 direita.
func ligar_seta(lado: int) -> void:
	if lado == 0 or _pisca_lado == lado:
		_pisca_lado = 0
	else:
		_pisca_lado = signi(lado)
		# Acende ja no toque: a primeira metade do ciclo e a acesa.
		_pisca_tempo = 0.0
	_pisca_virou = false


## -1 esquerda, 0 nenhuma, 1 direita.
func seta() -> int:
	return _pisca_lado


## A lampada da seta esta acesa AGORA (na metade acesa do ciclo)?
func seta_acesa() -> bool:
	return _pisca_lado != 0 and fposmod(_pisca_tempo, PISCA_PERIODO) < PISCA_PERIODO * 0.5


## Cor atual do pisca da frente de um lado, para quem precisa conferir.
func cor_pisca_frente(lado: int) -> Color:
	var lista := _luz_f_dir if lado > 0 else _luz_f_esq
	var cores = _luz_arrays[Mesh.ARRAY_COLOR] if not _luz_arrays.is_empty() else null
	if lista.is_empty() or cores == null:
		return Color.BLACK
	return (cores as PackedColorArray)[lista[0]]


func _esterco(lado: float, delta: float) -> void:
	var limite := lerpf(ESTERCO_MAX, ESTERCO_MIN,
		clampf(absf(_velocidade) / VEL_ESTERCO_FECHADO, 0.0, 1.0))
	var alvo := -lado * limite
	# Contra-esterco na deriva vai alem do limite de velocidade, ate o angulo
	# em que o carro escorrega e mais um pouco. O limite existe para o toque de
	# tecla a 90 km/h nao jogar o carro de lado; na deriva ele fazia o
	# contrario, prendendo as rodas em 17 graus a 50 km/h com o carro 20 graus
	# atravessado, e segurar a deriva era impossivel.
	if _derivando:
		var beta := escorregamento_do_rumo()
		if signf(alvo) == signf(beta):
			alvo = signf(alvo) * minf(ESTERCO_MAX, maxf(limite, absf(beta) + 0.1)) * absf(lado)
	var passo := VEL_VOLANTE if absf(alvo) > absf(steering) else VEL_VOLANTE_CENTRO
	steering = move_toward(steering, alvo, delta * passo)


## Freio de mao: so as duas traseiras, e SOMANDO ao freio de pedal.
##
## Trava as quatro e o carro so para, o que o freio normal ja faz melhor. O
## sentido de existir e travar o eixo de tras: o rabo perde aderencia e o carro
## gira em torno da frente, que e a unica manobra de carro que ninguem consegue
## fazer sem uma tecla dedicada.
##
## O "somando" custou uma medida. A primeira versao escrevia
## `FREIO_MAO if _freio_mao else 0.0` nas traseiras, e o `else 0.0` desligava o
## freio traseiro de SERVICO o tempo todo: `brake` no corpo escreve nas quatro
## rodas, e esta funcao apagava duas logo depois. O carro freiava so com a
## frente, e o relatorio acusou 3,95 m/s2 num carro projetado para 8,3 — metade,
## que e exatamente a conta de metade das rodas.
func _freiar_com_a_mao() -> void:
	if not _freio_mao or _rodas.size() < 4:
		return
	for k in range(2, _rodas.size()):
		# Zerar a tracao DAQUELA roda nao e detalhe, e a condicao para o freio
		# existir. No `VehicleBody3D`, roda com `engine_force` nao nulo aplica
		# atrito de rolamento no lugar do freio — ja custou uma medida no freio
		# de pedal, e aqui custou outra: puxar o freio de mao acelerando, que e
		# exatamente a manobra, nao fazia NADA. O escorregao medido ficava em
		# 0,20, abaixo do limiar de cantada, e o pneu nunca gritava.
		#
		# Fisicamente tambem e o certo: roda travada nao transmite tracao.
		_rodas[k].engine_force = 0.0
		_rodas[k].brake = maxf(brake, _freio * FREIO_MAO_DO_FREIO)


## O freio de servico na pista de agora: na chuva ele para menos.
##
## `brake` no `VehicleBody3D` e teto de impulso, e o pneu nunca o limita — na
## conta do Godot o atrito para a frente vale o dobro do de lado, e nenhum freio
## desta ficha chega perto. Medido em 18/09/2026: o sedan parava de 80 km/h nos
## mesmos 30,1 m com a pista seca e molhada. Aqui o freio cai na mesma
## proporcao do atrito, que e o que o pneu faria se o motor o deixasse limitar.
func _freio_na_pista() -> float:
	if _rodas.is_empty():
		return _freio
	var seco := float(_ficha.get("atrito", 0.9))
	return _freio * clampf(_rodas[0].wheel_friction_slip / maxf(seco, 0.01), 0.0, 1.0)


## A aderencia da traseira: cai de uma vez quando o freio de mao trava a roda,
## fica no atrito de deslizamento enquanto a deriva dura, e volta em rampa
## quando o carro se alinha. Ver `ADERENCIA_TRAVADA` e `ATRITO_DESLIZANDO`.
##
## Parado nao conta: o freio de mao segurando o carro na ladeira nao e roda
## deslizando, e o pneu parado tem a aderencia inteira.
func _aderir_traseira(delta: float) -> void:
	if _rodas.size() < 4:
		return
	var travada := _freio_mao and absf(_velocidade) > 1.0
	var beta := absf(rad_to_deg(escorregamento_do_rumo()))
	if travada:
		_derivando = true
	elif _derivando and (beta < DERIVA_FIM or linear_velocity.length() < 2.0):
		_derivando = false
	var alvo := 1.0
	if travada:
		alvo = ADERENCIA_TRAVADA
	elif _derivando:
		alvo = ATRITO_DESLIZANDO
	if alvo < _aderencia_tras:
		_aderencia_tras = alvo
	else:
		_aderencia_tras = move_toward(_aderencia_tras, alvo,
			delta * (1.0 - ADERENCIA_TRAVADA) / VOLTA_ADERENCIA)
	var seco := _rodas[0].wheel_friction_slip
	for k in range(2, _rodas.size()):
		_rodas[k].wheel_friction_slip = seco * _aderencia_tras


## O angulo entre o nariz e a velocidade, em radianos, no plano do chao.
## Positivo: o carro vai para a ESQUERDA de onde aponta. Zero abaixo de 2 m/s,
## onde a direcao da velocidade e ruido.
func escorregamento_do_rumo() -> float:
	var v := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if v.length() < 2.0:
		return 0.0
	var f := -global_transform.basis.z
	f = Vector3(f.x, 0.0, f.z).normalized()
	return atan2(f.cross(v).y, f.dot(v))


## A deriva esta ligada? Ver `ATRITO_DESLIZANDO`.
func derivando() -> bool:
	return _derivando


## A barra estabilizadora, eixo por eixo. Ver `ESTABILIZADORA`.
##
## Roda no ar fica de fora, como numa barra de verdade que so torce com as duas
## pontas apoiadas: empurrar a carroceria no lado da roda solta a jogaria de
## volta ao chao com mais forca do que a mola faria.
func _estabilizar(delta: float) -> void:
	if _rodas.size() < 4 or _y_estendida.size() < 4:
		return
	var rigidez := float(_ficha["rigidez"])
	var k := _estabilizadora * mass * rigidez
	var c := AMORTECE_ROLAGEM * mass * sqrt(rigidez)
	var cima := global_transform.basis.y
	for eixo in 2:
		var a := _rodas[eixo * 2]
		var b := _rodas[eixo * 2 + 1]
		var diferenca := (a.position.y - _y_estendida[eixo * 2]) \
			- (b.position.y - _y_estendida[eixo * 2 + 1])
		var torcendo := 0.0
		if not is_nan(_torcao[eixo]):
			torcendo = (diferenca - _torcao[eixo]) / maxf(delta, 0.0001)
		_torcao[eixo] = diferenca
		if not a.is_in_contact() or not b.is_in_contact():
			continue
		var f := cima * (k * diferenca + c * torcendo)
		apply_force(f, a.global_position - global_position)
		apply_force(-f, b.global_position - global_position)


## Arrasto do ar e resistencia de rolamento.
##
## Sao o que dao TETO ao carro. A suspensao do Godot nao tem nenhum dos dois: um
## `VehicleBody3D` com a quinta marcha engatada e o pe no fundo acelera ate a
## precisao do float acabar. Com estes dois o sedan para de ganhar velocidade
## por volta dos 175 km/h, que e onde um carro assim para.
func _arrastar(delta: float) -> void:
	var v := linear_velocity
	var rapidez := v.length()
	if rapidez < 0.05:
		return
	var forca := _arrasto * rapidez * rapidez + ROLAMENTO * mass * 9.8
	# Teto: o arrasto nunca pode tirar mais velocidade do que o carro tem neste
	# quadro. Sem o teto, um quadro longo — o primeiro depois de carregar um
	# chunk — empurra o carro para TRAS, e o defeito aparece como um tranco que
	# ninguem reproduz de proposito.
	forca = minf(forca, rapidez * mass / maxf(delta, 0.0001))
	apply_central_force(-v.normalized() * forca)


# --- direcao da IA ----------------------------------------------------------

func _dirigir_ia(delta: float) -> void:
	if not _tem_rota:
		_iniciar_rota()

	_atualizar_aproximacao()
	_atualizar_pisca(delta)

	_medir_obstaculo()
	var teto_sinal := _teto_do_sinal()
	# "O sinal esta me segurando" continua existindo como SIM ou NAO, porque o
	# avanco de rota precisa de uma borda: retargetar no vermelho faz o destino
	# pular 125 m e o freio soltar. O que deixou de ser booleano e a VELOCIDADE.
	var sinal := teto_sinal < INF
	var para_alvo := _mira_ia() - global_position
	para_alvo.y = 0.0

	# Avancar rota: nao retarget com sinal vermelho (senao destino pula ~125 m e
	# o freio solta). Antecipa so UMA vez por cruzamento (destino == _aproxima).
	if _curvando:
		if para_alvo.length() < CHEGOU:
			_escolher_destino()
			para_alvo = _mira_ia() - global_position
			para_alvo.y = 0.0
	elif not sinal:
		var d_centro := _dist_ao_centro(destino)
		var chegar := para_alvo.length() < CHEGOU
		# Antecipar curva/reto enquanto ainda nao consumimos este cruzamento.
		var antecipar := (destino == _aproxima and d_centro < ANTECIPAR_CURVA
			and d_centro > 0.8)
		if chegar or antecipar:
			_escolher_destino()
			para_alvo = _mira_ia() - global_position
			para_alvo.y = 0.0

	var teto := _teto_de_velocidade()
	# Guardado antes de a blitz mexer nele: e como o diagnostico distingue
	# "nada me segura" de "a blitz baixou o teto da via". Sem a distincao, um
	# carro parado num funil de blitz se reportava com motivo `via`, que e a
	# unica resposta que nao ajuda ninguem.
	var teto_via := teto
	var blitz := Blitz.efeito(self)
	if int(blitz.get("faixa", -1)) >= 0 and trecho.z == int(blitz.get("eixo", trecho.z)):
		trecho = Vias.trecho(trecho.z, trecho.w, int(blitz["faixa"]))
	if not blitz.is_empty():
		teto = minf(teto, float(blitz.get("teto", teto)))
		if blitz.has("mira"):
			para_alvo = (blitz["mira"] as Vector3) - global_position
			para_alvo.y = 0.0
		# Avisa a blitz quando este carro (selecionado) esta parado no funil.
		if bool(blitz.get("parar", false)) and _velocidade < 0.5:
			var bnode: Blitz = blitz.get("blitz")
			if bnode == null:
				# efeito() nao devolve blitz — pega via manager
				var info := BlitzManager.consulta(global_position, trecho, semente)
				bnode = info.get("blitz")
			if bnode != null:
				bnode.tentar_iniciar_inspecao(self, true)
		# Motorista a pe: esconde o corpo do motorista do carro se houver.
		if bool(blitz.get("ocultar_motorista", false)):
			_ocultar_motorista_visual(true)
		else:
			_ocultar_motorista_visual(false)
	_talvez_contornar(delta, sinal)
	var obstaculo := _obst_dist < INF
	# A velocidade alvo e o MENOR de tres tetos, e nao um "pare" booleano.
	#
	# Antes era: se ha sinal ou obstaculo, alvo = 0. Isso nao diz ONDE parar, e o
	# carro parava onde a desaceleracao o deixasse — 1,6 m do centro do
	# cruzamento, ou seja, atravessado no meio dele, tres metros alem da linha
	# de retencao. A rua transversal abria o verde para um carro entalado na
	# esquina e travava atras dele, que e exatamente o defeito relatado.
	#
	# Com teto por distancia, sqrt(2*a*d), o carro chega na linha com
	# velocidade zero e nem um centimetro adiante — e, se o verde abrir no meio
	# da aproximacao, ele nem chega a frear, porque o teto volta a ser o da via.
	var teto_obst := _teto_do_obstaculo()
	var alvo_vel := minf(teto, minf(teto_sinal, teto_obst))
	if _contorno > 0.0:
		alvo_vel = minf(alvo_vel, VEL_CONTORNO)
	if not blitz.is_empty() and float(blitz.get("teto", 1.0)) <= 0.05:
		alvo_vel = 0.0
	# Quem ganhou o teto. Um carro parado e um sintoma com quatro causas — sinal,
	# fila, blitz e via — e sem saber qual delas mandou, "carro travado no meio
	# da quadra" e uma frase sem conserto associado.
	_motivo = &"livre"
	if not blitz.is_empty() and teto < teto_via:
		_motivo = &"blitz"
	elif alvo_vel >= teto:
		_motivo = &"via"
	elif teto_obst <= teto_sinal:
		_motivo = &"fila"
	else:
		_motivo = &"sinal"
	# Em estacionamento da blitz: nao gira no lugar — so avanca se mira a frente.
	var fase_b := int(blitz.get("fase", -1))
	if fase_b == Blitz.Fase.ESTACIONANDO and para_alvo.length() > 0.2:
		# Limita esterco para nao orbitar o ponto do acostamento.
		pass

	if alvo_vel > _velocidade:
		_velocidade = minf(alvo_vel, _velocidade + ACELERA * delta)
		_parado = 0.0
	else:
		_velocidade = maxf(alvo_vel, _velocidade - FREIA * delta)
	_freando = alvo_vel < _velocidade - 0.5

	if _velocidade < 0.4:
		_parado += delta
		_reclamar(obstaculo and not sinal)
	else:
		_parado = 0.0

	# Rumo. Mira na faixa a frente (termo lateral) ou no pivo da curva.
	# Parado na blitz: nao gira atras de uma mira lateral (spinning).
	var blitz_parado := (not blitz.is_empty() and float(blitz.get("teto", 1.0)) <= 0.05
		and _velocidade < 0.45)
	if para_alvo.length() > 0.05 and not blitz_parado:
		var quero := atan2(-para_alvo.x, -para_alvo.z)
		var taxa := 2.3
		# Desvio limpo: vira mais devagar para nao oscilar no funil.
		if not blitz.is_empty() and not bool(blitz.get("parar", false)):
			taxa = 1.4
		_giro = _aproximar_angulo(_giro, quero, taxa * delta)

	var frente := Vector3(-sin(_giro), 0.0, -cos(_giro))
	var nova := global_position + frente * _velocidade * delta
	nova.y = _altura_do_chao(nova)
	global_transform = Transform3D(_base_na_ladeira(nova, frente), nova)
	_balancar(delta)


## Um passo das molas da carroceria da IA. Ver `MOLA_FREQ`.
func _balancar(delta: float) -> void:
	if delta <= 0.0:
		return
	if is_nan(_mola_vel_antes):
		_mola_vel_antes = _velocidade
		_mola_giro_antes = _giro
	var acel := (_velocidade - _mola_vel_antes) / delta
	var taxa := wrapf(_giro - _mola_giro_antes, -PI, PI) / delta
	_mola_vel_antes = _velocidade
	_mola_giro_antes = _giro
	var alvo := Vector3(0.0, acel * ARFAR_POR_ACEL,
		clampf(_velocidade * taxa * ROLAR_POR_ACEL, -ROLAR_MAX, ROLAR_MAX))
	# Passo limitado: num engasgo de carga a mola daria um salto de integracao
	# em vez de um balanco.
	var dt := minf(delta, 1.0 / 30.0)
	for k in 3:
		var w := TAU * MOLA_FREQ[k]
		_v_mola[k] += (w * w * (alvo[k] - _mola[k]) - 2.0 * MOLA_AMORTECE * w * _v_mola[k]) * dt
		_mola[k] += _v_mola[k] * dt
	_aplicar_mola()


## Poe a carroceria na posicao da mola. As pecas sao as de fora e as de dentro;
## rodas, colisao e som ficam no chassi.
func _aplicar_mola() -> void:
	var pivo := Vector3(0.0, MOLA_PIVO, 0.0)
	var giro := Basis(Vector3.RIGHT, _mola.y) * Basis(Vector3.FORWARD, _mola.z)
	var mola := Transform3D(Basis(), pivo + Vector3(0.0, _mola.x, 0.0)) \
		* Transform3D(giro, Vector3.ZERO) * Transform3D(Basis(), -pivo)
	var pecas: Array = [_corpo_malha, _corpo_longe, _interior, _luzes, _farol,
		_brasa, _motorista_corpo]
	pecas.append_array(_fachos)
	for no: Variant in pecas:
		if no == null or not is_instance_valid(no):
			continue
		var peca := no as Node3D
		if not _mola_base.has(peca):
			_mola_base[peca] = peca.transform
		peca.transform = mola * (_mola_base[peca] as Transform3D)


## Volta a carroceria ao chassi e esquece as molas. Quem assume o volante tem
## suspensao de verdade (`VehicleBody3D`), e as duas nao podem somar.
func _soltar_mola() -> void:
	_mola = Vector3.ZERO
	_v_mola = Vector3.ZERO
	_mola_vel_antes = NAN
	# Chave sem tipo: o motorista pode ter sido liberado, e laco tipado com
	# instancia liberada para com erro.
	for peca: Variant in _mola_base.keys():
		if is_instance_valid(peca):
			(peca as Node3D).transform = _mola_base[peca]
	_mola_base.clear()


## Velocidade permitida aqui. A avenida corre; a rua nao.


## Some / mostra malha do motorista (quando desce na blitz). Sem mesh dedicada
## de motorista, apaga a cabine/vidro se existir; senao e no-op visual.
func _ocultar_motorista_visual(esconder: bool) -> void:
	# Critico: esconder o Corpo do banco. So apagar Cabine deixava o motorista
	# em pe clipando pelo teto enquanto o a-pe conversava fora (bug E).
	if _motorista_corpo != null and is_instance_valid(_motorista_corpo):
		_motorista_corpo.visible = not esconder
	var cab := get_node_or_null("Cabine")
	if cab != null:
		cab.visible = not esconder


func _teto_de_velocidade() -> float:
	var v := (MalhaUrbana.via_x(cruzamento.x) if trecho.z == 0
		else MalhaUrbana.via_z(cruzamento.y))
	return VEL_AVENIDA if v == MalhaUrbana.Via.AVENIDA else VEL_CRUZEIRO


static func _aproximar_angulo(de: float, para: float, passo: float) -> float:
	var d := wrapf(para - de, -PI, PI)
	return de + clampf(d, -passo, passo)


## O rumo, com a arfagem da ladeira (Relevo): o carro que sobe a rua olha para
## cima. So o declive do terreno na direcao do rumo, e nao o do chao sob cada
## roda — o carro do transito nao tem suspensao, e o quebra-molas nao existe.
func _base_na_ladeira(onde: Vector3, frente: Vector3) -> Basis:
	var base := Basis(Vector3.UP, _giro)
	var subida := Relevo.altura(onde.x + frente.x * 1.5, onde.z + frente.z * 1.5) \
		- Relevo.altura(onde.x - frente.x * 1.5, onde.z - frente.z * 1.5)
	if absf(subida) < 0.001:
		return base
	return base * Basis(Vector3.RIGHT, atan2(subida, 3.0))


func _altura_do_chao(onde: Vector3) -> float:
	var espaco := get_world_3d().direct_space_state
	var de := onde + Vector3.UP * 2.0
	var ate := onde + Vector3.DOWN * 2.0
	var excluir: Array[RID] = [get_rid()]
	# Teto de outro carro nao e chao: ignora Carro/Pedestre/player e tenta de novo.
	for _i in 4:
		var consulta := PhysicsRayQueryParameters3D.create(de, ate, 1)
		consulta.exclude = excluir
		var achado := espaco.intersect_ray(consulta)
		if achado.is_empty():
			return global_position.y
		var col: Object = achado.get("collider")
		if col is Carro or col is Pedestre or (col is Node
				and (col as Node).is_in_group(&"player")):
			if col is CollisionObject3D:
				excluir.append((col as CollisionObject3D).get_rid())
			continue
		return (achado["position"] as Vector3).y
	return global_position.y


## A rota inicial: o carro nasceu no meio de um quarteirao e ja tem faixa.
func _iniciar_rota() -> void:
	destino = Vias.proximo_cruzamento(cruzamento.x, cruzamento.y, trecho)
	_alvo = Vias.ponto_de_curva(destino.x, destino.y, trecho, trecho)
	_aproxima = destino
	_curvando = false
	_tem_rota = true
	_tem_plano = false
	_pisca_lado = 0


## O proximo ponto de mira. Chamada quando o carro chega no anterior.
##
## Sao dois tempos, e nao um. Ao chegar num cruzamento o carro escolhe a saida e
## mira na QUINA — o cruzamento das duas linhas de faixa dentro do cruzamento —
## e so depois de passar por ela e que mira no cruzamento seguinte. Sem esses
## dois tempos a curva e uma diagonal: o carro corta do meio de uma rua para o
## meio da outra, passando por cima da contramao e da calcada da esquina.
##
## Seguindo reto os dois tempos colapsam num so, e o metodo sai pelo caminho
## curto.
func _escolher_destino() -> void:
	if _curvando:
		# Ja passou pela quina. Daqui em diante e reta ate o proximo cruzamento.
		_curvando = false
		_pisca_lado = 0
		cruzamento = destino
		destino = Vias.proximo_cruzamento(cruzamento.x, cruzamento.y, trecho)
		_alvo = Vias.ponto_de_curva(destino.x, destino.y, trecho, trecho)
		# So obedece o sinal novo depois de limpar o cruzamento atual.
		return

	var cruz_atual := destino
	cruzamento = cruz_atual
	var anterior := trecho
	var saidas := Vias.saidas(cruzamento.x, cruzamento.y, anterior)
	if saidas.is_empty():
		# Fim de linha: a unica saida legal e voltar por onde veio. Acontece na
		# beira de uma faixa sem secundaria, e e raro.
		trecho = Vias.trecho(anterior.z, -anterior.w, anterior.x)
		_iniciar_rota()
		return

	# Pesa seguir reto. Sem isso o carro vira em toda esquina e o transito da a
	# impressao de que todo mundo esta perdido — que e o defeito mais visivel de
	# trafego procedural, e o mais facil de evitar.
	# Se a seta ja travou a saida (~1.5 s antes), respeita o plano.
	var escolha: Vector4i
	if _tem_plano and saidas.has(_saida_plana):
		escolha = _saida_plana
	else:
		escolha = saidas[0]
		if saidas.size() > 1 and randf() > 0.62:
			escolha = saidas[1 + randi() % (saidas.size() - 1)]
	_tem_plano = false

	trecho = escolha
	if escolha.z == anterior.z and escolha.w == anterior.w:
		# Reto (mesma direcao; pode ter mudado so a faixa na avenida).
		_pisca_lado = 0
		destino = Vias.proximo_cruzamento(cruzamento.x, cruzamento.y, trecho)
		_alvo = Vias.ponto_de_curva(destino.x, destino.y, trecho, trecho)
		# _aproxima continua no cruzamento que ainda estamos atravessando.
		return
	_curvando = true
	_pisca_lado = _lado_da_curva(anterior, escolha)
	_alvo = Vias.ponto_de_curva(cruzamento.x, cruzamento.y, anterior, escolha)
	# Se o pivo ja ficou para tras (decisao tarde), mira a frente na faixa de saida.
	var para_pivo := _alvo - global_position
	para_pivo.y = 0.0
	var dir_ant := Vias.direcao(anterior.z, anterior.w)
	if para_pivo.dot(dir_ant) < 1.0:
		var dir_sai := Vias.direcao(escolha.z, escolha.w)
		_alvo = global_position + dir_sai * 6.0
		if escolha.z == 0:
			_alvo.x = Vias.linha_x(cruzamento.x, escolha.w, escolha.x)
		else:
			_alvo.z = Vias.linha_z(cruzamento.y, escolha.w, escolha.x)


func _alinhar_na_faixa() -> void:
	var frente := Vias.direcao(trecho.z, trecho.w)
	_giro = atan2(-frente.x, -frente.z)
	global_rotation = Vector3(0.0, _giro, 0.0)


## Distancia horizontal ao centro de grade (i, j).
func _dist_ao_centro(ij: Vector2i) -> float:
	var centro := Vector3(float(ij.x) * Vias.TAM, global_position.y,
		float(ij.y) * Vias.TAM)
	return Vector2(centro.x - global_position.x, centro.z - global_position.z).length()


## Quando o carro passa do centro de _aproxima, passa a obedecer o destino novo.
func _atualizar_aproximacao() -> void:
	if _aproxima == Vector2i.ZERO:
		_aproxima = destino
		return
	if _aproxima == destino and not _curvando:
		return
	var centro := Vector3(float(_aproxima.x) * Vias.TAM, global_position.y,
		float(_aproxima.y) * Vias.TAM)
	var para := centro - global_position
	para.y = 0.0
	var frente := Vector3(-sin(_giro), 0.0, -cos(_giro))
	# Passou do centro e ainda perto o bastante para ser este cruzamento.
	if para.dot(frente) < 0.0 and para.length() < Vias.TAM * 0.5:
		_aproxima = destino


## Ponto de mira da IA: na curva o pivo; na reta, um ponto a frente NA FAIXA
## (corrige erro lateral residual que empurraria o carro para a calcada).
func _mira_ia() -> Vector3:
	if _curvando:
		return _alvo
	var dir := Vias.direcao(trecho.z, trecho.w)
	var olhada := 8.0
	var ate := _alvo - global_position
	ate.y = 0.0
	var dist := ate.length()
	var mira: Vector3
	if dist < olhada:
		mira = _alvo
	else:
		mira = global_position + dir * olhada
	# Trava a coordenada transversal na linha da faixa.
	# Eixo 0 (anda em Z): a via e a linha x = i; i e o mesmo em cruzamento e destino.
	if trecho.z == 0:
		mira.x = Vias.linha_x(cruzamento.x, trecho.w, trecho.x)
	else:
		mira.z = Vias.linha_z(cruzamento.y, trecho.w, trecho.x)
	# Contornando: a mira sai da faixa, e e por isso que o carro sai. O desvio
	# entra DEPOIS da trava transversal, senao a trava o apagaria — ela e
	# escrita absoluta, e nao somada.
	if _contorno > 0.0:
		mira += dir.cross(Vector3.UP) * (CONTORNO_LATERAL * _contorno_lado)
	return mira


# --- seta -------------------------------------------------------------------

## Lado da curva: +1 direita do carro (+X), -1 esquerda. 0 se nao e curva.
func _lado_da_curva(de: Vector4i, para: Vector4i) -> int:
	var a := Vias.direcao(de.z, de.w)
	var b := Vias.direcao(para.z, para.w)
	var cruz := a.cross(b).y
	if absf(cruz) < 0.05:
		return 0
	# Sistema destro, Y pra cima: cross.y > 0 vira a direita (mao brasileira).
	return 1 if cruz > 0.0 else -1


## Trava a proxima saida cedo o bastante para a seta piscar ~PISCA_S antes do pivo.
func _travar_saida() -> void:
	var saidas := Vias.saidas(destino.x, destino.y, trecho)
	if saidas.is_empty():
		return
	var escolha: Vector4i = saidas[0]
	if saidas.size() > 1 and randf() > 0.62:
		escolha = saidas[1 + randi() % (saidas.size() - 1)]
	_saida_plana = escolha
	_tem_plano = true
	if escolha.z != trecho.z or escolha.w != trecho.w:
		_pisca_lado = _lado_da_curva(trecho, escolha)
	else:
		_pisca_lado = 0


func _atualizar_pisca(delta: float) -> void:
	_pisca_tempo += delta
	if _curvando:
		return
	if not _tem_rota or _aproxima == Vector2i.ZERO:
		return
	# So planeja seta para o cruzamento que ainda vamos atravessar.
	if destino != _aproxima:
		return
	var d := _dist_ao_centro(destino)
	var alcance := maxf(_teto_de_velocidade() * PISCA_S, ANTECIPAR_CURVA + 4.0)
	if not _tem_plano and d < alcance and d > 1.0:
		_travar_saida()


# --- o que faz o carro parar ------------------------------------------------

## A velocidade que o sinal do proximo cruzamento ainda permite, em m/s.
##
## Era um SIM ou NAO, e o "sim" mandava parar JA — `alvo_vel = 0` no instante em
## que o carro entrava numa zona de uns nove metros. Nao havia, em lugar nenhum
## do arquivo, uma conta de onde ele iria PARAR. Fazendo a conta por fora:
##
##     rua      entra na zona a 9,16 m do centro a 11 m/s, freia a 8 m/s2,
##              anda 7,56 m e para a 1,60 m do CENTRO — 3,00 m ALEM da linha
##     avenida  entra a 13,85 m a 14 m/s, para tambem a 1,60 m — 4,50 m alem
##
## Ou seja: todo carro da cidade parava DENTRO do cruzamento, atravessado na
## frente de quem tinha verde, e ficava ali o vermelho inteiro. Os dois defeitos
## relatados — "param no lugar errado" e "carros se travando" — sao esse.
##
## Agora a conta e a de um motorista. Dada a distancia que falta ate a LINHA de
## retencao, a maior velocidade com que ainda da para encostar nela e
## sqrt(2*a*d). O carro chega suave, para em cima da linha, e se o verde abrir
## no meio da aproximacao o teto volta a ser o da via sem ele ter freado.
##
## Passou da linha? Nao freia mais, aconteca o que acontecer com a luz. E a
## regra de nao trancar o cruzamento: quem entrou tem de sair. Sem ela, fechar
## o amarelo em cima de um carro que ja cruzou a linha o prende no meio da
## esquina, que e o mesmo defeito por outra porta.
func _teto_do_sinal() -> float:
	var ij := _aproxima if _aproxima != Vector2i.ZERO else destino
	if not Semaforo.tem_sinal(ij.x, ij.y):
		return _teto_do_pare(ij)
	var centro := Vector3(float(ij.x) * Vias.TAM, global_position.y,
		float(ij.y) * Vias.TAM)
	var para_centro := centro - global_position
	para_centro.y = 0.0
	# Centro atras da frente: ja atravessou, o sinal nao e mais com ele.
	var frente := Vector3(-sin(_giro), 0.0, -cos(_giro))
	if para_centro.dot(frente) < 0.0:
		return INF

	var eixo_sinal := trecho.z
	# Durante a curva o trecho ja virou: o sinal que importa e o do eixo de chegada.
	if _curvando:
		eixo_sinal = 1 - trecho.z
	var luz := Semaforo.estado(ij.x, ij.y, eixo_sinal, Semaforo.agora())
	if luz == Semaforo.Luz.VERDE:
		return INF

	# A linha e onde o BICO tem de parar, e a conta e a partir do centro do
	# carro — entao ela leva meio comprimento. Sem isso o carro encostava com o
	# centro na linha e o bico meio metro dentro do cruzamento, que e pouco e e
	# visivel: o para-choque aparece na faixa de quem esta atravessando.
	var linha := (meia_cruz_do(ij) + Vias.FOLGA_RETENCAO
		+ float(_medidas["comprimento"]) * 0.5)
	var falta := para_centro.length() - linha
	var freio := (_velocidade * _velocidade) / (2.0 * FREIA)

	# Ja dentro do cruzamento: sai, parado ou nao. Trancar o cruzamento e pior
	# do que atravessar o vermelho — e a regra que impede o engavetamento que
	# esta rodada foi consertar.
	if falta < -DENTRO_DO_CRUZAMENTO:
		return INF
	if falta <= 0.0:
		# Em cima da linha. Quem esta ANDANDO ja entrou e tem de sair; quem
		# esta parado NAO entrou, e liberar ele aqui e manda-lo atravessar o
		# vermelho a partir do ponto morto.
		#
		# Este era o defeito do primeiro conserto, e a medida o pegou inteiro: o
		# carro chegava na linha bonito — 12,2 m a 11,1 m/s, 8,6 a 8,1, 6,2 a
		# 5,2, 5,0 a 2,7 — parava exatamente em 4,6 m, e no quadro seguinte
		# arrancava com a luz ainda vermelha, porque "falta <= 0" o declarava
		# comprometido.
		return INF if absf(_velocidade) > 1.0 else 0.0
	# Longe demais para este sinal importar. A borda existe para o avanco de
	# rota, que precisa de um SIM ou NAO — ver `_dirigir_ia`; para a velocidade
	# ela nao muda nada, porque a essa distancia o teto da conta ja e maior que
	# o da via.
	if falta > freio + RETENCAO:
		return INF
	# No amarelo, quem nao consegue parar antes da linha passa.
	if luz == Semaforo.Luz.AMARELO and falta < freio:
		return INF
	return sqrt(2.0 * FREIA * falta)


## O PARE da esquina sem semaforo.
##
## Quem chega pela rua preferencial (Vias.preferencial) segue. Quem chega pela
## outra para com o bico na linha de retencao — a mesma do semaforo —, espera
## um instante parado e so entra quando a esquina esta livre: ninguem dentro
## dela e ninguem chegando perto pela preferencial. Liberado, nao para de novo
## no mesmo cruzamento ate passar dele.
##
## Sem isto, tirar o semaforo das ruas de bairro faria dois carros entrarem ao
## mesmo tempo no cruzamento — os raios de `_medir_obstaculo` olham so para a
## frente, e o carro que vem de lado nao esta na frente de ninguem ate a batida.
func _teto_do_pare(ij: Vector2i) -> float:
	# A liberacao vale para UM cruzamento: mudou o destino, ela ja passou.
	if _pare_liberado != ij:
		_pare_liberado = Vector2i(2147483647, 0)
	if not Vias.existe_cruzamento(ij.x, ij.y):
		return INF
	var eixo_chegada := 1 - trecho.z if _curvando else trecho.z
	if eixo_chegada == Vias.preferencial(ij.x, ij.y) or _pare_liberado == ij:
		return INF
	var centro := Vector3(float(ij.x) * Vias.TAM, global_position.y,
		float(ij.y) * Vias.TAM)
	var para_centro := centro - global_position
	para_centro.y = 0.0
	var frente := Vector3(-sin(_giro), 0.0, -cos(_giro))
	if para_centro.dot(frente) < 0.0:
		return INF
	var falta := para_centro.length() - linha_de_retencao(ij)
	if falta < -DENTRO_DO_CRUZAMENTO:
		return INF
	var freio := (_velocidade * _velocidade) / (2.0 * FREIA)
	if falta > freio + RETENCAO:
		_pare_desde = -1.0
		return INF
	if falta <= 0.6 and absf(_velocidade) < 0.5:
		var agora := Semaforo.agora()
		if _pare_desde < 0.0:
			_pare_desde = agora
		if agora - _pare_desde >= ESPERA_PARE and _esquina_livre(ij):
			_pare_liberado = ij
			_pare_desde = -1.0
			return INF
		return 0.0
	return sqrt(2.0 * FREIA * maxf(0.0, falta))


## Segundos parado na linha do PARE antes de olhar se da para entrar.
const ESPERA_PARE := 0.7
## Quem esta a menos disto do centro do cruzamento, vindo pela preferencial,
## tem a vez.
const PARE_OLHA := 16.0


## Ninguem dentro do cruzamento e ninguem chegando pela preferencial.
func _esquina_livre(ij: Vector2i) -> bool:
	var centro := Vector2(float(ij.x) * Vias.TAM, float(ij.y) * Vias.TAM)
	var caixa := Vias.meia_asfalto_x_no(ij.x, ij.y) + Vias.meia_asfalto_z_no(ij.x, ij.y)
	var pref := Vias.preferencial(ij.x, ij.y)
	for no: Node in get_tree().get_nodes_in_group(&"carro"):
		if no == self or not (no is Node3D):
			continue
		var outro := no as Node3D
		var p := Vector2(outro.global_position.x, outro.global_position.z)
		var d := p.distance_to(centro)
		if d < caixa * 0.75:
			return false
		if d > PARE_OLHA:
			continue
		# Chegando pela preferencial: esta na PISTA dela (e nao na faixa de
		# estacionamento, onde um carro parado seguraria o PARE para sempre) e
		# anda na direcao do centro.
		var no_eixo := absf(p.x - centro.x) < Vias.meia_x(ij.x) if pref == 0 \
			else absf(p.y - centro.y) < Vias.meia_z(ij.y)
		if not no_eixo:
			continue
		var frente_outro := -outro.global_transform.basis.z
		var para := centro - p
		if Vector2(frente_outro.x, frente_outro.z).dot(para) > 0.0:
			return false
	return true


## Meia largura da pista transversal deste cruzamento.
func meia_cruz_do(ij: Vector2i) -> float:
	return Vias.meia_z(ij.y) if trecho.z == 0 else Vias.meia_x(ij.x)


## Onde o bico deste carro tem de parar, contado do centro do cruzamento.
## O teste le para saber se ele parou antes ou depois. Ver `_teto_do_sinal`.
func linha_de_retencao(ij: Vector2i) -> float:
	return (meia_cruz_do(ij) + Vias.FOLGA_RETENCAO
		+ float(_medidas["comprimento"]) * 0.5)


## O que ha na frente, e a que distancia.
##
## Era um SIM ou NAO e virou distancia pelo mesmo motivo do sinal: "ha alguem
## na frente" nao diz com que velocidade se pode chegar perto dele. Com o
## booleano, o carro que enxergava outro nove metros adiante ia a zero de uma
## vez — freada cheia num obstaculo que estava a nove metros andando a 40 —, e
## o de tras enxergava a freada e fazia o mesmo. E a receita do engarrafamento
## fantasma: uma fila inteira parando e saindo sem que nada esteja bloqueando
## a rua.
##
## Tres raios em leque, e nao uma varredura de forma: custam um terco e erram
## so o obstaculo mais estreito que meio metro atravessado na faixa, que na
## pratica e um poste — e poste nao fica no meio da rua.
##
## O alcance sai da distancia de freio deste carro nesta velocidade, e nao de
## um numero fixo escalado: olhar menos do que se precisa para parar e a
## definicao de dirigir rapido demais para a vista.
func _medir_obstaculo() -> void:
	_obst_dist = INF
	_obst_quem = null
	var espaco := get_world_3d().direct_space_state
	var frente := Vector3(-sin(_giro), 0.0, -cos(_giro))
	var direita := frente.cross(Vector3.UP)
	var origem := global_position + Vector3.UP * 0.6 + frente * (
		float(_medidas["comprimento"]) * 0.5 + 0.1)
	var alcance := clampf(
		(_velocidade * _velocidade) / (2.0 * FREIA) + FOLGA_FILA + 2.0, 3.5, 18.0)
	for lado: float in [0.0, CORREDOR * 0.7, -CORREDOR * 0.7]:
		var de := origem + direita * lado
		var consulta := PhysicsRayQueryParameters3D.create(de, de + frente * alcance, 1)
		consulta.exclude = [get_rid()]
		var achado := espaco.intersect_ray(consulta)
		if achado.is_empty():
			continue
		# Tipado a mao: Dictionary.get devolve Variant e o projeto trata
		# declaracao sem tipo como erro. Object aceita null, que e o que vem
		# quando o raio pegou algo sem no.
		var col: Object = achado.get("collider")
		# Predio nao conta: se um raio pegou parede, o carro esta fazendo curva e
		# a parede sai do caminho sozinha. Contam pessoa e carro.
		if not (col is Carro or col is Pedestre or (col is Node
				and (col as Node).is_in_group(&"player"))):
			continue
		# Quem estamos contornando nao conta enquanto o contorno dura. Continuar
		# a enxerga-lo seria o proprio motivo de nao sair do lugar: o desvio
		# existe justamente porque aquele carro NAO vai andar.
		if col == _contornado and _contorno > 0.0:
			continue
		var d := de.distance_to(achado["position"] as Vector3)
		if d < _obst_dist:
			_obst_dist = d
			_obst_quem = col as Node


## A velocidade que o obstaculo a frente permite, em m/s.
func _teto_do_obstaculo() -> float:
	if _obst_dist == INF:
		return INF
	return sqrt(2.0 * FREIA * maxf(0.0, _obst_dist - FOLGA_FILA))


## Preso atras de alguem que nao vai sair dali? Contorna.
##
## Ver `ESPERA_CONTORNO`. So vale para coisa PARADA e so fora do sinal: fila
## que anda se segue, e ultrapassar no vermelho poe o carro dentro do
## cruzamento, que e o defeito que o resto desta rodada foi consertar.
func _talvez_contornar(delta: float, sinal: bool) -> void:
	if _contorno > 0.0:
		_contorno -= delta
		if _contorno <= 0.0:
			_contornado = null
			_contorno_lado = 0.0
		return
	if _parado < ESPERA_CONTORNO or sinal:
		return
	var outro := _obst_quem as Carro
	if outro == null or not is_instance_valid(outro):
		return
	if absf(outro.velocidade()) > 0.5:
		return
	# Fila nao se ultrapassa. So se contorna quem nao esta ESPERANDO nada: o
	# carro sem motorista que o jogador estacionou na pista, ou um que parou
	# por motivo nenhum.
	#
	# Sem esta condicao o conserto vira outro defeito, e a medida pegou ele: o
	# segundo carro da fila do semaforo esperava os 2,4 s atras do primeiro —
	# que estava parado no vermelho, legitimamente — e saia por cima dele. O
	# proprio carro de tras nao ve a luz, porque a 15 m da linha e parado o
	# sinal ainda nem entrou no alcance dele; quem sabe por que aquela fila
	# existe e o carro da frente.
	if outro.motorista == Motorista.IA:
		var razao := outro.motivo_da_parada()
		if razao == &"sinal" or razao == &"fila":
			return
	_contorno = TEMPO_CONTORNO
	_contornado = outro
	# Pela esquerda. Do lado do meio-fio ha calcada, poste e quem esta andando
	# nela; do lado de dentro ha, no pior caso, a contramao — que e por onde se
	# ultrapassa desde que existe rua de mao dupla.
	_contorno_lado = -1.0


# --- buzina e xingamento ----------------------------------------------------

## Buzina de quem esta preso, e nao de quem esta parado no sinal.
##
## A diferenca importa: uma cidade em que todo carro buzina no vermelho vira
## piada em trinta segundos. Aqui so reclama quem esta atras de alguem que nao
## anda — que e quando uma pessoa de verdade buzina.
func _reclamar(preso: bool) -> void:
	if not preso or ficha.is_empty():
		return
	if _parado > PACIENCIA and _desde_buzina > 3.4:
		_desde_buzina = 0.0
		_buzinar(_parado > PACIENCIA_XINGO)
	if _parado > PACIENCIA_XINGO and not _voz.playing:
		# Xingar e falar sem palavra, como toda voz deste jogo. O que identifica
		# o xingamento e a cadencia curta e a altura subindo, nao o conteudo.
		_voz.dizer(FalasNpc.xingamento(ficha))


func _buzinar(longa: bool) -> void:
	var nome := &"buzina_longa" if longa else &"buzina_curta"
	if not AudioDirector.tem(nome):
		return
	_buzina.stream = AudioDirector.stream(nome)
	_buzina.pitch_scale = 0.88 + float(absi(semente) % 40) / 100.0
	_buzina.play()


func buzinar() -> void:
	_buzinar(false)


# --- pedestres ---------------------------------------------------------------

## Quem passa perto demais leva um susto.
##
## A consulta so roda acima da velocidade de susto, porque um carro em fila
## andando a dois metros por segundo nao assusta ninguem — e assustar todo mundo
## que esta na calcada transformaria a rua num festival de gente pulando.
func _assustar_quem_esta_perto() -> void:
	if absf(_velocidade) < VEL_SUSTO:
		return
	if Engine.get_physics_frames() % 6 != 0:
		return
	for p: Node in get_tree().get_nodes_in_group(&"pedestre"):
		var ped := p as Pedestre
		if ped == null or not is_instance_valid(ped):
			continue
		var d := ped.global_position.distance_to(global_position)
		if d > RAIO_SUSTO:
			continue
		# So quem esta no asfalto: pedestre na calcada nao e "quase atropelado".
		if not Vias.no_asfalto(ped.global_position):
			continue
		ped.assustar(global_position, clampf(absf(_velocidade) / 14.0, 0.4, 1.0))
		# A buzina do susto e da IA. O carro do jogador nao buzina sozinho: a
		# buzina e uma coisa que ELE aperta, e um carro que toca a propria buzina
		# a cada pedestre que passa e um carro com defeito, nao com personagem.
		if motorista == Motorista.IA and _desde_buzina > 1.2:
			_desde_buzina = 0.0
			_buzinar(false)


# --- aparencia --------------------------------------------------------------

func _girar_rodas(delta: float) -> void:
	var giro := _velocidade / Carroceria.RAIO_RODA * delta
	_rolo_frente = wrapf(_rolo_frente - giro, -PI, PI)
	_rolo_tras = wrapf(_rolo_tras - giro, -PI, PI)
	var ang := 0.0
	if motorista == Motorista.JOGADOR:
		ang = steering
	elif motorista == Motorista.IA:
		# Esterco visual = desvio entre rumo e mira.
		var para := _mira_ia() - global_position
		para.y = 0.0
		if para.length() > 0.1:
			var quero := atan2(-para.x, -para.z)
			ang = clampf(wrapf(quero - _giro, -PI, PI), -ESTERCO_MAX, ESTERCO_MAX)
	# Basis composta: yaw do esterco * pitch da rolagem. Evita corromper Euler
	# ao escrever rotation.y depois de rotate_x.
	var pose := Basis(Vector3.UP, ang) * Basis(Vector3.RIGHT, _rolo_frente)
	for pino: Node3D in _pinos_frente:
		if is_instance_valid(pino):
			pino.transform.basis = pose
	if _eixo_tras != null:
		_eixo_tras.transform.basis = Basis(Vector3.RIGHT, _rolo_tras)


## Um facho por farol, no lugar do farol.
##
## Havia UM cone, e ele nascia em x = 0 — no meio do bico. O `SpotLight3D`
## ilumina o asfalto e some na nevoa; quem desenha o farol para quem esta na
## calcada e o cone. Com um cone so, todo carro da cidade vinha vindo com uma
## luz no meio da frente, como moto. Foi o que o jogador viu e relatou.
##
## As posicoes saem da MALHA, e nao de uma tabela por modelo. Os sete modelos
## poem o farol em lugares diferentes — o Fusca sobre o para-lama, a 62 graus do
## arco; o Marea na quina do capo; os genericos a 32% da meia largura — e uma
## tabela aqui seria uma segunda verdade sobre a mesma coisa, que envelhece na
## primeira carroceria nova. Aqui o carro pergunta a propria lataria: quais
## vertices da superficie de luzes estao na frente (-Z) e usam a celula do farol
## no atlas. A media de cada lado e o centro daquele farol.
func _montar_fachos() -> void:
	var onde := Carroceria.farois(_luz_arrays, _luz_uv_base)
	if onde.is_empty():
		# Carroceria sem farol emissivo reconhecivel: um cone no meio, como
		# antes. Nao e o certo, mas e melhor que um carro cego na nevoa.
		onde = [_farol.position]
	var cor_f := Color(1.0, 0.95, 0.86, 0.55)
	# Cone mais estreito que o antigo, porque agora sao dois. Somados, os dois
	# cobrem a mesma largura de estrada que o unico cobria.
	var raio_fim := 1.55 if onde.size() > 1 else 2.4
	for k in onde.size():
		var f := MeshInstance3D.new()
		f.name = "Facho%d" % k
		f.mesh = PSXMesh.cone(0.09, raio_fim, FACHO_COMPRIMENTO, 8, 3,
			cor_f, Color(cor_f.r, cor_f.g, cor_f.b, 0.0))
		if ResourceLoader.exists(MAT_CONE):
			f.material_override = load(MAT_CONE)
		else:
			push_error("Carro: material do facho ausente em %s" % MAT_CONE)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.sorting_offset = -1.0
		f.position = onde[k]
		# Malha do cone cresce em -Y; +90 graus em X poe a ponta em -Z, que e a
		# frente. -90 apontaria para a traseira.
		f.rotation.x = PI * 0.5 + deg_to_rad(FAROL_INCLINACAO)
		add_child(f)
		_fachos.append(f)
	if not Settings.changed.is_connected(_ao_mudar_clima):
		Settings.changed.connect(_ao_mudar_clima)
	_ao_mudar_clima()


func _cachear_luzes() -> void:
	if _luzes == null or _luzes.mesh == null:
		return
	var mesh := _luzes.mesh as ArrayMesh
	if mesh == null or mesh.get_surface_count() < 1:
		return
	_luz_arrays = mesh.surface_get_arrays(0)
	_luz_uv_base = (_luz_arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).duplicate()
	_luz_i_esq.clear()
	_luz_i_dir.clear()
	# Depois da meia volta da carroceria, lanterna traseira fica em +Z; farol em -Z.
	var verts: PackedVector3Array = _luz_arrays[Mesh.ARRAY_VERTEX]
	_luz_f_esq.clear()
	_luz_f_dir.clear()
	var cores = _luz_arrays[Mesh.ARRAY_COLOR]
	_luz_cor_base = (cores as PackedColorArray).duplicate() if cores != null \
		else PackedColorArray()
	# O pisca da frente e achado pela CELULA do atlas, e nao pela posicao: nos
	# cinco modelos ele fica colado no farol, e so a celula ambar o separa dele.
	var celula_pisca := Carroceria.uv(Carroceria.C_PISCA).grow(0.001)
	for k in verts.size():
		if verts[k].z < -0.05 and celula_pisca.has_point(_luz_uv_base[k]):
			if verts[k].x >= 0.0:
				_luz_f_dir.append(k)
			else:
				_luz_f_esq.append(k)
	for k in verts.size():
		if verts[k].z <= 0.05:
			continue
		if verts[k].x >= 0.0:
			_luz_i_dir.append(k)
		else:
			_luz_i_esq.append(k)


func _atualizar_luzes() -> void:
	var acesa := ligado or motorista == Motorista.IA
	if _farol != null:
		_farol.visible = acesa
	for f: MeshInstance3D in _fachos:
		f.visible = acesa
		f.set_instance_shader_parameter(&"piscar", 1.0 if acesa else 0.0)
	if _brasa != null:
		_brasa.visible = acesa
		_brasa.light_energy = 1.5 if _freando else 0.55
	var mat := _luzes.material_override as ShaderMaterial
	if mat != null:
		var energia := 0.08
		if acesa:
			energia = 3.4 if (_freando or _re) else 2.4
			if _pisca_lado != 0:
				energia = maxf(energia, 2.8)
		mat.set_shader_parameter("emission_energy", energia)
	_aplicar_atlas_lanternas()


## Troca a celula do atlas nas lanternas traseiras: freio, re e seta amarela.
## Sem draw call extra - mesma malha, so UV.
func _aplicar_atlas_lanternas() -> void:
	if _luz_uv_base.is_empty() or _luzes == null:
		return
	var celula := Carroceria.C_LANTERNA
	if _re:
		celula = Carroceria.C_RE
	elif _freando:
		celula = Carroceria.C_FREIO
	var pisca_aceso := (_pisca_lado != 0
		and fposmod(_pisca_tempo, PISCA_PERIODO) < PISCA_PERIODO * 0.5)
	var chave := (int(celula.x) | (int(celula.y) << 4)
		| ((_pisca_lado & 3) << 8) | ((1 if pisca_aceso else 0) << 10))
	if chave == _luz_chave:
		return
	_luz_chave = chave
	var uvs := _luz_uv_base.duplicate()
	var base := Carroceria.uv(Carroceria.C_LANTERNA).position
	var delta := Carroceria.uv(celula).position - base
	var delta_pisca := Carroceria.uv(Carroceria.C_PISCA).position - base
	for k in _luz_i_esq:
		uvs[k] = _luz_uv_base[k] + (
			delta_pisca if (pisca_aceso and _pisca_lado < 0) else delta)
	for k in _luz_i_dir:
		uvs[k] = _luz_uv_base[k] + (
			delta_pisca if (pisca_aceso and _pisca_lado > 0) else delta)
	_luz_arrays[Mesh.ARRAY_TEX_UV] = uvs
	# Pisca da frente: brasa de lanterna quando parado, ambar cheio quando pisca.
	# E o comportamento do Fusca, do Opala e do Chevette, em que a mesma lente
	# ambar era lanterna e seta. A cor do vertice multiplica albedo e emissao no
	# `psx_surface`, entao o apagado e so o ambar mais fraco.
	if _luz_cor_base.size() == uvs.size():
		var cores := _luz_cor_base.duplicate()
		for k in _luz_f_esq:
			cores[k] = _luz_cor_base[k] * (1.0 if (pisca_aceso and _pisca_lado < 0)
				else PISCA_APAGADO)
		for k in _luz_f_dir:
			cores[k] = _luz_cor_base[k] * (1.0 if (pisca_aceso and _pisca_lado > 0)
				else PISCA_APAGADO)
		_luz_arrays[Mesh.ARRAY_COLOR] = cores
	var mesh := _luzes.mesh as ArrayMesh
	if mesh == null:
		return
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _luz_arrays)


## Atrito do pneu AGORA: o do modelo, reduzido se a pista estiver molhada.
func _atrito_agora() -> float:
	var seco := float(_ficha.get("atrito", 3.4))
	return seco * (MOLHADO if Settings.fog_preset().tem_chuva else 1.0)


## Reaplica nas quatro rodas. Chamado quando o clima muda no meio da partida —
## comecar a chover com o jogador a 100 km/h tem de ser sentido no volante, e nao
## so visto no para-brisa.
func _aplicar_atrito() -> void:
	var a := _atrito_agora()
	for r: VehicleWheel3D in _rodas:
		r.wheel_friction_slip = a


## O clima mudou: o facho e o pneu respondem juntos.
func _ao_mudar_clima() -> void:
	_aplicar_facho_nevoa()
	_aplicar_atrito()
	_aplicar_sombra()


## A lataria projeta sombra no MODERNO (PLANO_CARROS_AAA, F5).
##
## Nenhuma malha do carro projetava sombra, por custo: o carro ficava colado no
## asfalto pela mancha de contato e nada mais. No PS1 continua assim — a mancha
## e o que o preset paga. No MODERNO o sol e o poste desenham o carro no chao,
## e e a sombra que diz a que altura a lataria esta. So a lataria: roda e
## interior ficam dentro da sombra dela.
func _aplicar_sombra() -> void:
	if _corpo_malha == null:
		return
	var sombra := (GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if Settings.luz_por_pixel else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_corpo_malha.cast_shadow = sombra
	if _corpo_longe != null:
		_corpo_longe.cast_shadow = sombra


## Intensidade do facho acompanha a nevoa — sem nevoa o cone quase some,
## com nevoa densa ele e o desenho do farol na rua.
##
## No MODERNO o cone de malha nao e desenhado, pelo mesmo motivo da `Lampada`:
## o Forward+ ja faz o facho em nevoa volumetrica, e o cone somado por cima dele
## e uma segunda camada de ar aceso, com silhueta reta, que apaga o que esta
## atras. O farol passa a empurrar luz para dentro da nevoa de verdade.
func _aplicar_facho_nevoa() -> void:
	var moderno: bool = Settings.luz_por_pixel
	if _farol != null:
		_farol.light_volumetric_fog_energy = VOLUME_MODERNO if moderno else 1.0
	var forca := Settings.fog_preset().facho_forca
	for f: MeshInstance3D in _fachos:
		f.visible = not moderno
		if not moderno and f.material_override != null:
			f.material_override.set_shader_parameter(&"intensidade", forca)


func triangulos() -> int:
	return int(_medidas.get("triangulos", 0))
