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
## Periodo do pisca-pisca (aceso metade do ciclo).
const PISCA_PERIODO := 0.44

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

## Quanto do atrito seco sobra com a pista molhada.
##
## O jogo tem chuva desde sempre — `FogPreset.tem_chuva` — e o pneu a ignorava:
## chovendo ou nao, `wheel_friction_slip` era o mesmo numero. Com 72% o carro
## ainda anda, mas a picape de tracao traseira sai de lado na arrancada e o
## Fusca precisa de mais rua para parar, que e exatamente o que chuva faz.
const MOLHADO := 0.72

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
var _luzes: MeshInstance3D
var _eixo_frente: Node3D
## Os dois pinos de roda da dianteira. Cada um no lugar da sua roda, para o
## esterco girar em torno do proprio pino e nao do centro do carro.
var _pinos_frente: Array[Node3D] = []
var _eixo_tras: Node3D
var _rodas: Array[VehicleWheel3D] = []
var _farol: SpotLight3D
## Um cone por farol. Ver `_montar_fachos`.
var _fachos: Array[MeshInstance3D] = []
var _brasa: OmniLight3D
var _motorista_corpo: Corpo
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
	_medidas = Carroceria.montar(modelo, tinta, semente)

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
	_corpo_malha.mesh = _medidas["corpo"]
	_corpo_malha.material_override = load(Carroceria.MATERIAL) as ShaderMaterial
	_corpo_malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_corpo_malha)

	_luzes = MeshInstance3D.new()
	_luzes.name = "Luzes"
	_luzes.mesh = _medidas["luzes"]
	_luzes.material_override = (load(Carroceria.MATERIAL_LUZ)
		as ShaderMaterial).duplicate() as ShaderMaterial
	_luzes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_luzes)


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
		roda.suspension_stiffness = float(_ficha["rigidez"])
		roda.suspension_travel = float(_ficha["curso"])
		roda.damping_compression = 0.62
		roda.damping_relaxation = 0.72
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
## E o mesmo Corpo do pedestre, afundado no banco ate a linha da cintura. Nao ha
## pose sentada: as pernas ficam abaixo do assoalho, fora de vista, e o que se
## ve pelo para-brisa e tronco, ombro e cabeca — que e tudo que se ve de um
## motorista de verdade a essa distancia.
func _montar_motorista() -> void:
	if _motorista_corpo != null or ficha.is_empty():
		return
	_motorista_corpo = Corpo.new()
	_motorista_corpo.name = "Motorista"
	add_child(_motorista_corpo)
	_motorista_corpo.montar(ficha.get("aparencia", {}))
	# Volante a esquerda: com a frente em -Z e Y para cima, a direita do carro e
	# +X, entao o banco do motorista fica em -X.
	_motorista_corpo.position = Vector3(
		-float(_medidas["largura"]) * 0.24, -0.36,
		-float(_medidas["comprimento"]) * 0.04)


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
	get_parent().add_child(p)
	# Do lado do motorista, meio metro para fora, ja fora da lataria.
	p.global_position = global_position - global_transform.basis.x * (
		float(_medidas["largura"]) * 0.5 + 0.55) + Vector3.UP * 0.1
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
	_congelar(false)
	linear_velocity = -global_transform.basis.z * _velocidade
	_piloto_ligado = false
	_piloto = Vector3.ZERO
	_freio_mao = false
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


func devolver() -> void:
	CabineDoJogador.desmontar(_cabine_jogador)
	_cabine_jogador = null
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
	var perdeu := (_vel_anterior - linear_velocity).length()
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
	# Pancada em cheio afoga o motor. Precisa dar a partida de novo, e esse
	# meio segundo de silencio depois do estrondo e o que separa "bati" de
	# "encostei" melhor do que qualquer numero na tela.
	if forca > 0.75 and ligado:
		ligado = false
		_motor.desligar()
		_som.desligar()


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
	_som.atualizar(Motor.giro_aparente(_velocidade, modelo),
		clampf(absf(_velocidade) / 12.0, 0.15, 0.8),
		_velocidade, acesa, false, 0.0, delta)


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
	# Carro capotado nao tem motor rodando. Nao e so realismo de bomba de oleo:
	# um carro de pernas para o ar acelerando e roncando e a coisa mais absurda
	# que esta fisica consegue produzir, e o silencio subito e o que diz ao
	# jogador que a brincadeira acabou e que ele precisa sair dali.
	if ligado and capotado():
		ligado = false
		_motor.desligar()
		_som.desligar()
	var c := _comandos()
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
			brake = _freio * _motor.travao
		else:
			engine_force = -forca
			brake = 0.0
	else:
		# Motor desligado nao e ponto morto: o carro anda por inercia e para.
		engine_force = 0.0
		brake = _freio * maxf(_motor.travao, 0.12)

	_esterco(c.z, delta)
	_freiar_com_a_mao()
	_arrastar(delta)


## O volante.
##
## O curso fecha com a velocidade — sem isso, a 90 km/h um toque na tecla joga o
## carro de lado — e volta ao centro mais depressa do que sai dele, porque
## soltar a tecla tem de parecer soltar o volante.
func _esterco(lado: float, delta: float) -> void:
	var limite := lerpf(ESTERCO_MAX, ESTERCO_MIN,
		clampf(absf(_velocidade) / VEL_ESTERCO_FECHADO, 0.0, 1.0))
	var alvo := -lado * limite
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
	global_transform = Transform3D(Basis(Vector3.UP, _giro), nova)


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
		return INF
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
