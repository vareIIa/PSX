## O som do motor.
##
## O que mudou e por que
## ---------------------
## A versao anterior tinha UM loop e uma afinacao, e derivava a rotacao da
## velocidade dentro da marcha. Funcionava como ideia e falhava como som, por
## dois motivos que so aparecem com o carro andando:
##
##   a amostra ia longe demais   um loop de 46 Hz esticado da lenta ao corte
##                               cobre de 0,6x a 4,7x. Em cima vira assobio, em
##                               baixo vira lama, e no meio nao soa como nada.
##   o timbre nao mudava         motor de quatro cilindros e desigual e cavernoso
##                               embaixo e vira parede rasgada em cima. Afinacao
##                               nao produz essa mudanca, e e ELA que o ouvido usa
##                               para saber que o carro esta acelerando.
##
## Agora sao tres amostras, uma por faixa de rotacao, cruzadas em rotacao — cada
## uma so esticada na propria vizinhanca. Por cima delas anda o pneu, que e o que
## domina o ouvido acima dos 80 km/h e sem o qual acelerar so deixa o motor
## agudo: o carro parece rapido e nao SOA rapido.
##
## Quem manda aqui e o `Motor`, e nao a velocidade. A rotacao e a mesma que gera
## a forca na roda, entao o som nunca discorda do que o carro esta fazendo — e a
## troca de marcha e o corte de giro aparecem no ouvido porque aconteceram na
## maquina, e nao porque um cronometro os imitou.
##
## Carro da IA nao paga isto
## -------------------------
## Seis carros de rua com cinco tocadores cada sao trinta vozes para um transito
## que passa a trinta metros dentro da nevoa. O carro da IA fica com uma camada
## so, que e o que ele tinha antes. `detalhado` decide, e quem liga e o Carro
## quando o jogador assume o volante.
class_name MotorSom
extends Node3D

## Rotacao em que cada amostra foi gravada. Sai de `tools/gerar_motor.py`:
## rpm = frequencia de explosao * 30, para um quatro cilindros de quatro tempos.
const REF_BAIXO := 1200.0
const REF_MEDIO := 3240.0
const REF_ALTO := 5640.0
## Velocidade de referencia do rolamento do pneu, em m/s.
const REF_PNEU := 20.0

## Onde uma camada entra e onde sai, em rpm. As janelas se sobrepoem de proposito
## — sem sobreposicao a troca de amostra e um degrau audivel, que e pior que o
## defeito que as tres amostras vieram consertar.
const BAIXO_FIM := Vector2(1600.0, 2200.0)
const MEDIO_INI := Vector2(1600.0, 2200.0)
const MEDIO_FIM := Vector2(4200.0, 5000.0)
const ALTO_INI := Vector2(4200.0, 5000.0)

## Volume de cada camada em silencio e em carga total.
const DB_BAIXO := Vector2(-17.0, -11.0)
const DB_MEDIO := Vector2(-19.0, -8.0)
const DB_ALTO := Vector2(-26.0, -6.0)
const DB_PNEU := Vector2(-30.0, -13.0)
## Quanto o motor emudece enquanto a faisca esta cortada. E o buraco que se ouve
## como troca de marcha e como limitador.
const DB_CORTE := -13.0

## Volume do vento na lataria, do limiar ao teto.
const DB_VENTO := Vector2(-34.0, -11.0)
## Onde o vento comeca a existir e onde ele ja e tudo, em m/s. 8 m/s sao 29 km/h
## — abaixo disso e silencio de rua; 42 m/s sao 150 km/h, onde o vento ja
## abafa o motor num carro de rua com borracha de porta velha.
const VEL_VENTO := Vector2(8.0, 42.0)

## Volume da cantada de pneu, do limiar ao escorregao total.
const DB_CANTA := Vector2(-26.0, -7.0)
## Escorregamento a partir do qual o pneu comeca a cantar, de 0 a 1.
##
## Nao e zero: pneu SEMPRE escorrega um pouco — e assim que ele transmite forca —
## e um limiar em zero faria o carro chiar parado no sinal.
##
## 0,14 saiu de medida, e nao de gosto. Numa arrancada a pe no fundo em linha
## reta o escorregao medido e 0,00; numa curva com o volante no batente, 0,61;
## puxando o freio de mao a 36 km/h, 0,25. O limiar precisa passar por cima do
## primeiro e pegar o terceiro com folga.
const CANTA_LIMIAR := 0.14
## Abaixo desta velocidade nao ha cantada. Roda patinando com o carro parado
## chia na vida real, mas no jogo isso viraria um chiado constante em todo
## semaforo, e o som que importa e o da curva.
const VEL_CANTA_MUDA := 3.0

## Velocidade em que o pneu ja esta no volume cheio.
const VEL_PNEU_CHEIO := 30.0
## Abaixo disto o pneu nao faz som nenhum: um carro a passo nao chia.
const VEL_PNEU_MUDO := 1.6

## Quao depressa o volume persegue o alvo. O giro ja e suave por vir da fisica;
## o que precisa de amortecimento e a CARGA, que salta de 0 a 1 num quadro
## quando o pe desce.
const SUAVIDADE := 12.0
## O corte e a unica coisa que NAO se suaviza: o buraco tem de ser seco.
const SUAVIDADE_CORTE := 60.0

## Alcance. Um motor de carro de rua nao se ouve a quarenta metros numa cidade
## com vento e chuva; a trinta ja esta no limite.
const ALCANCE := 34.0

## Caracter deste motor, em multiplicador de afinacao.
##
## Todo carro da cidade tocava o MESMO som, no mesmo tom e no mesmo volume. Com
## seis carros na rua isso se ouve na hora: passam seis clones. Motor de rua
## varia — cilindrada, escapamento furado, vela velha — e a variacao mais
## audivel de todas e a ALTURA: um 1.0 de tres cilindros ronca fino e um 2.0
## ronca grosso na mesma velocidade.
##
## Sai da semente do carro, como ja saia a buzina (`Carro._buzinar`). Mesma
## semente, mesmo carro, mesmo som — o taxi que passou tem de soar igual quando
## passar de novo.
var _carater: float = 1.0
## E quanto este escapamento e mais alto ou mais surdo que o padrao, em dB.
var _volume: float = 0.0

var detalhado: bool = false

var _baixo: AudioStreamPlayer3D
var _medio: AudioStreamPlayer3D
var _alto: AudioStreamPlayer3D
var _pneu: AudioStreamPlayer3D
var _canta: AudioStreamPlayer3D
var _vento: AudioStreamPlayer3D
var _extra: AudioStreamPlayer3D

var _ligado: bool = false
var _carga: float = 0.0
var _corte: float = 0.0
var _giro: float = 0.0
var _escorrega: float = 0.0
## Carga do quadro anterior: o estouro do escapamento e uma BORDA de descida
## do pedal, e nao um estado.
var _carga_anterior: float = 0.0
var _desde_alivio: float = 9.0
## Corte de giro do motor que este som acompanha, para o limiar de estouro
## ser o mesmo pedaco de faixa em qualquer carro.
var _ref_corte: float = 6500.0


func _ready() -> void:
	_medio = _tocador("Medio", ALCANCE)
	_extra = _tocador("Eventos", 30.0)
	_extra.unit_size = 4.0
	_extra.volume_db = -10.0


## As camadas caras nascem so quando alguem senta ao volante. Ate la o no e o
## mesmo carro de rua de antes, com um tocador.
func detalhar() -> void:
	if detalhado:
		return
	detalhado = true
	_baixo = _tocador("Baixo", ALCANCE)
	_alto = _tocador("Alto", ALCANCE)
	_pneu = _tocador("Pneu", 26.0)
	_canta = _tocador("Canta", 40.0)
	# O vento e de dentro do carro, e nao do mundo: quem o ouve e quem esta
	# sentado. Alcance curto para nao vazar para a calcada.
	_vento = _tocador("Vento", 9.0)
	if _ligado:
		_acender()


func _tocador(nome: String, alcance: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = nome
	p.bus = &"SFX"
	p.max_distance = alcance
	p.unit_size = 5.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	# Efeito Doppler, atrelado ao passo de FISICA.
	#
	# E a assinatura sonora de "um carro passou", e ela nao existia. So funciona
	# com a camera tambem rastreando — ver `scenes/player/player.tscn` — e so no
	# passo de fisica: no passo de quadro, a velocidade sai da diferenca entre
	# dois desenhos e um engasgo de carga vira um guincho.
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	p.volume_db = -60.0
	add_child(p)
	return p


## Da a este motor o caracter dele. Chamado pelo carro, com a semente do carro.
##
## Os dois numeros saem de fatias diferentes do mesmo hash: tirar os dois do
## resto da mesma divisao amarraria "motor fino" a "motor alto", e a cidade teria
## dois tipos de carro em vez de uma faixa continua.
func caracterizar(semente: int, corte: float = 6500.0) -> void:
	_ref_corte = maxf(1000.0, corte)
	var h := absi(semente * 2654435761)
	_carater = lerpf(0.88, 1.14, float(h % 97) / 96.0)
	_volume = lerpf(-2.5, 2.0, float((h / 97) % 61) / 60.0)


## Afinacao relativa deste motor. Para o teste poder afirmar que a rua tem
## motores diferentes, e nao seis copias do mesmo.
func carater() -> float:
	return _carater


# --- ignicao ----------------------------------------------------------------

func partir() -> void:
	_ligado = true
	_tocar(&"motor_partida", -8.0)
	_acender()


func desligar() -> void:
	_ligado = false
	for p: AudioStreamPlayer3D in [_baixo, _medio, _alto, _pneu, _canta, _vento]:
		if p == null:
			continue
		p.stop()
		# Zera o volume tambem, e nao so para o tocador. Um tocador parado guarda
		# o ultimo volume que teve, e quem perguntar o estado do som ouve a
		# resposta de antes: o relatorio acusou "carro parado fazendo vento a
		# -30 dB" num carro que estava mudo havia meio minuto.
		p.volume_db = -60.0


## Volta a tocar sem repetir a partida. E o que o carro chama quando o jogador
## assume um motor que ja estava rodando.
func acordar() -> void:
	if _ligado:
		_acender()


func _acender() -> void:
	_por_loop(_medio, &"motor_medio" if detalhado else &"motor_loop")
	if not detalhado:
		return
	_por_loop(_baixo, &"motor_baixo")
	_por_loop(_alto, &"motor_alto")
	_por_loop(_pneu, &"pneu_loop")
	_por_loop(_canta, &"pneu_canta")
	_por_loop(_vento, &"vento_carro")


func _por_loop(p: AudioStreamPlayer3D, nome: StringName) -> void:
	if p == null:
		return
	var s := AudioDirector.em_loop(nome)
	if s == null:
		return
	p.stream = s
	if not p.playing:
		p.play()


# --- quadro a quadro --------------------------------------------------------

## Chamado todo quadro pelo carro.
##
## `giro` e `carga` vem do `Motor`; `velocidade` e do carro; `cortado` e o
## instante em que a faisca esta desligada, seja pelo limitador, seja pela
## embreagem aberta na troca; `escorrega` e quanto o pneu esta deslizando, de 0
## a 1, medido nas rodas de verdade.
func atualizar(giro: float, carga: float, velocidade: float, ligado: bool,
		cortado: bool, escorrega: float, delta: float) -> void:
	if ligado != _ligado:
		if ligado:
			partir()
		else:
			desligar()
	if not _ligado:
		return

	_giro = giro
	var passo := minf(1.0, SUAVIDADE * delta)
	_carga = lerpf(_carga, clampf(carga, 0.0, 1.0), passo)
	_desde_alivio += delta
	_corte = lerpf(_corte, 1.0 if cortado else 0.0,
		minf(1.0, SUAVIDADE_CORTE * delta))

	var abafa := DB_CORTE * _corte

	if not detalhado:
		# Carro de rua: uma camada, afinada pelo giro como sempre foi. Nao canta
		# pneu — o carro da IA e cinematico, nao tem roda que escorregue, e um
		# chiado sem causa e pior que o silencio.
		_camada(_medio, REF_MEDIO, 1.0, DB_MEDIO, abafa)
		return

	# As tres janelas somam 1 em qualquer rotacao, entao o volume total nao
	# balanca quando a mistura anda de uma amostra para a outra.
	var p_baixo := 1.0 - _rampa(giro, BAIXO_FIM)
	var p_alto := _rampa(giro, ALTO_INI)
	var p_medio := maxf(0.0, _rampa(giro, MEDIO_INI) - _rampa(giro, MEDIO_FIM))
	var soma := maxf(0.001, p_baixo + p_medio + p_alto)

	_camada(_baixo, REF_BAIXO, p_baixo / soma, DB_BAIXO, abafa)
	_camada(_medio, REF_MEDIO, p_medio / soma, DB_MEDIO, abafa)
	# A camada aguda so existe em carga. Girando alto com o pe fora, um motor
	# de rua nao ruge: ele assobia baixo e freia. Sem esta linha, descer uma
	# ladeira em segunda soa como uma arrancada.
	_camada(_alto, REF_ALTO, (p_alto / soma) * lerpf(0.25, 1.0, _carga),
		DB_ALTO, abafa)
	_rolar(velocidade)
	_cantar(velocidade, escorrega, delta)
	_ventar(velocidade)
	_aliviar(carga)


## Uma camada: afinacao pela rotacao, volume pela mistura e pela carga.
##
## O volume vai a -60 dB e o tocador continua tocando. Parar e religar por
## quadro custaria mais que deixar rodando e daria um estalo em cada troca de
## faixa.
func _camada(p: AudioStreamPlayer3D, referencia: float, peso: float,
		faixa_db: Vector2, abafa: float) -> void:
	if p == null:
		return
	if peso <= 0.002:
		p.volume_db = -60.0
		return
	p.pitch_scale = clampf(_giro / referencia * _carater, 0.45, 2.2)
	var db := lerpf(faixa_db.x, faixa_db.y, _carga) + abafa + _volume
	# Peso em amplitude, e nao em decibeis: cruzar duas amostras somando dB
	# cava um buraco no meio da transicao, porque dB e logaritmo.
	p.volume_db = db + linear_to_db(clampf(peso, 0.0, 1.0))


## O pneu no asfalto. Sobe com a velocidade e nao com a rotacao: e o unico som
## do carro que continua igual com a embreagem aberta.
func _rolar(velocidade: float) -> void:
	if _pneu == null:
		return
	var v := absf(velocidade)
	if v < VEL_PNEU_MUDO:
		_pneu.volume_db = -60.0
		return
	var t := clampf((v - VEL_PNEU_MUDO) / (VEL_PNEU_CHEIO - VEL_PNEU_MUDO), 0.0, 1.0)
	_pneu.pitch_scale = clampf(0.72 + v / REF_PNEU * 0.42, 0.6, 1.9)
	_pneu.volume_db = lerpf(DB_PNEU.x, DB_PNEU.y, t)


## A cantada de pneu.
##
## Sem ela nao ha limite audivel: o carro gruda ate nao grudar mais, e o jogador
## descobre que passou do ponto quando ja esta de lado. Som de derrapagem e a
## unica coisa que avisa ANTES — e por isso todo jogo de carro tem, inclusive os
## que nao simulam nada.
##
## O escorregamento vem da roda, e nao do volante: derrapar de frente (o carro
## segue reto com a roda virada) e derrapar de traseira sao coisas diferentes, e
## as duas tem de cantar. `VehicleWheel3D.get_skidinfo` sabe; o teclado nao.
func _cantar(velocidade: float, escorrega: float, delta: float) -> void:
	if _canta == null:
		return
	var alvo := 0.0
	if absf(velocidade) > VEL_CANTA_MUDA and escorrega > CANTA_LIMIAR:
		alvo = clampf((escorrega - CANTA_LIMIAR) / (1.0 - CANTA_LIMIAR), 0.0, 1.0)
	# Sobe depressa e desce devagar: a borracha para de gritar antes de parar de
	# escorregar, e um volume que acompanha o escorregao quadro a quadro pica.
	var passo := 24.0 if alvo > _escorrega else 5.0
	_escorrega = lerpf(_escorrega, alvo, minf(1.0, passo * delta))
	if _escorrega < 0.02:
		_canta.volume_db = -60.0
		return
	# Raiz, e nao reta. Escorregao e uma grandeza cuja PONTA baixa e a que
	# importa: o comeco do deslize e o aviso, e com interpolacao reta um
	# escorregao de 0,25 saia a -25 dB, tao baixo quanto o silencio. A raiz
	# levanta o inicio da curva e deixa o topo onde estava.
	_canta.volume_db = lerpf(DB_CANTA.x, DB_CANTA.y, sqrt(_escorrega))
	# Escorregao forte canta mais agudo, como pneu de verdade.
	_canta.pitch_scale = lerpf(0.88, 1.16, _escorrega)


## O ar na lataria.
##
## Sem ele, acelerar so deixava o motor agudo — o carro parecia rapido no
## velocimetro e nao SOAVA rapido no ouvido. O vento e a unica camada que nao
## depende de rotacao nenhuma: ele so sabe a velocidade, e por isso continua
## igual com a embreagem aberta, com o motor morto e descendo a ladeira em ponto
## morto. E o que da peso a velocidade quando o motor cala.
func _ventar(velocidade: float) -> void:
	if _vento == null:
		return
	var v := absf(velocidade)
	if v < VEL_VENTO.x:
		_vento.volume_db = -60.0
		return
	var t := clampf((v - VEL_VENTO.x) / (VEL_VENTO.y - VEL_VENTO.x), 0.0, 1.0)
	_vento.volume_db = lerpf(DB_VENTO.x, DB_VENTO.y, t)
	_vento.pitch_scale = lerpf(0.82, 1.24, t)


## O estouro do escapamento quando o pe sai.
##
## So vale tirando o pe DE CIMA, e so com o motor girando: aliviar em marcha
## lenta nao estoura nada, e um pop a cada toque no acelerador parado viraria
## pipoca. O limiar de giro e fracao do corte, para um Fusca de 4700 estourar
## nos mesmos 60% de faixa que um Marea de 7000.
func _aliviar(carga: float) -> void:
	var girando := _giro > _ref_corte * 0.55
	if _carga_anterior > 0.5 and carga < 0.12 and girando and _desde_alivio > 0.7:
		_desde_alivio = 0.0
		_extra.pitch_scale = 1.0
		_tocar(&"motor_alivio", -17.0)
	_carga_anterior = carga


## Rampa de 0 a 1 entre `janela.x` e `janela.y`.
static func _rampa(x: float, janela: Vector2) -> float:
	return clampf((x - janela.x) / maxf(1.0, janela.y - janela.x), 0.0, 1.0)


## O que esta soando AGORA.
##
## Existe para o teste automatizado poder afirmar que o motor faz barulho, e nao
## so que os arquivos de som estao no disco. Um tocador com o stream certo, o
## volume certo e `playing` falso e o modo de falha silencioso desta classe: nada
## reclama, nada aparece no relatorio, e o carro anda mudo.
func diagnostico() -> Dictionary:
	var tocando := 0
	var db := -99.0
	var afinacao := 0.0
	for p: AudioStreamPlayer3D in [_baixo, _medio, _alto, _pneu]:
		if p == null or not p.playing:
			continue
		tocando += 1
		if p.volume_db > db:
			db = p.volume_db
			afinacao = p.pitch_scale
	return {
		"detalhado": detalhado,
		"tocando": tocando,
		"db_max": db,
		"afinacao": afinacao,
		"carga": _carga,
		"canta_db": _canta.volume_db if _canta != null else -99.0,
		"vento_db": _vento.volume_db if _vento != null else -99.0,
		"escorrega": _escorrega,
	}


# --- eventos ----------------------------------------------------------------

## A batida do cambio engatando.
func trocou() -> void:
	_extra.pitch_scale = 1.0
	_tocar(&"motor_marcha", -15.0)


## A faisca cortando. E o "ta" do limitador e o tranco da troca; o buraco de
## volume que acompanha vem de `atualizar`, e os dois juntos e que fazem o corte.
func cortou() -> void:
	_extra.pitch_scale = 1.0
	_tocar(&"motor_corte", -13.0)


## A batida. Volume e afinacao pela forca: encostao e um toc, batida de verdade
## e um estrondo mais grave, porque chapa grande cedendo soa mais grave que
## chapa pouco amassada.
func bateu(forca: float) -> void:
	_tocar(&"batida_carro", lerpf(-22.0, -3.0, forca))
	_extra.pitch_scale = lerpf(1.25, 0.82, forca)


func _tocar(nome: StringName, db: float) -> void:
	var s := AudioDirector.stream(nome)
	if s == null:
		return
	_extra.stream = s
	_extra.volume_db = db
	_extra.play()
