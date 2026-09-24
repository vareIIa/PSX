## O som do motor.
##
## De onde vem o som
## -----------------
## De um banco de amostras montadas como motor de verdade por
## `tools/gerar_motor.py`: trem de pulsos de escape na frequencia de explosao,
## coletor, abafador, admissao, tucho, correia — um arquivo por ponto de rotacao
## e por carga (`motor_<arquitetura>_<rpm>_<on|off>`). Tres arquiteturas, porque
## um Fusca nao e um sedan com outro volume: quatro em linha (`i4`), tres em
## linha (`i3`) e o boxer a ar (`boxer`). Ver `definir_arquitetura`.
##
## O banco anterior era de tres loops de soma de senoides, e soava como orgao:
## ordens fixas, fase fixa, cada ciclo identico ao anterior. Motor de verdade e
## um trem IRREGULAR de pulsos passando por tubos, e e essa irregularidade — mais
## a mudanca de timbre com giro e com carga — que o ouvido chama de motor.
##
## Como a mistura anda
## -------------------
## Cada amostra tem um tocador, e todos tocam o tempo todo; os que nao servem
## ficam em -60 dB. Trocar o stream de um tocador reinicia a amostra e estala, e
## parar e religar perde o passo (ver abaixo).
##
##   giro    os dois pontos da grade em volta do giro atual cruzam em potencia
##           constante (cos/sen), em log de giro — a grade e geometrica.
##   carga   em cada ponto, a camada `on` (pe no fundo) e a `off` (retencao)
##           cruzam pela carga suavizada, tambem em potencia constante.
##   volume  a curva de volume ja esta DENTRO das amostras (o gerador normaliza a
##           grade inteira junto, e nao arquivo por arquivo). Aqui so entram o
##           peso do cruzamento, o nivel da mistura e o caracter do carro.
##
## Por que TODO tocador e afinado todo quadro, inclusive os mudos
## --------------------------------------------------------------
## Cada amostra tem um numero inteiro de ciclos de motor e comeca no mesmo angulo
## de virabrequim. Com afinacao giro/ref, todas andam no mesmo passo de ciclo — e
## se partiram juntas, os pulsos de escape de dois pontos vizinhos caem no mesmo
## instante durante o cruzamento. Sem isso a metade do cruzamento soa como dois
## motores, um meio pulso atras do outro. Um tocador mudo que parasse de
## acompanhar o giro sairia de passo e entraria defasado quando fosse a vez dele.
##
## O que isto mede no motor
## ------------------------
## Quem manda e o `Motor`, e nao a velocidade. A rotacao e a mesma que gera a
## forca na roda, entao o som nunca discorda do que o carro esta fazendo — e a
## troca de marcha e o corte de giro aparecem no ouvido porque aconteceram na
## maquina, e nao porque um cronometro os imitou.
##
## Carro da IA nao paga isto
## -------------------------
## Seis carros de rua com vinte vozes cada sao cento e vinte vozes para um
## transito que passa a trinta metros dentro da nevoa. O carro da IA fica com UMA
## camada: a amostra em carga do ponto da grade no meio da faixa em que o
## transito anda (ver `RUA`). `detalhado` decide, e quem liga e o Carro quando o
## jogador assume o volante.
class_name MotorSom
extends Node3D

# --- o banco ----------------------------------------------------------------

## Rotacao de referencia de cada amostra, por arquitetura. E a grade de
## `tools/gerar_motor.py` (`ARQUITETURAS[...].grade`) e o numero no nome do
## arquivo; o gerador acerta cada amostra para um numero inteiro de ciclos e o
## desvio do nominal e da ordem de 1e-5, 0,02 cent de afinacao.
const GRADES := {
	&"i4": [800.0, 1100.0, 1500.0, 2050.0, 2800.0, 3800.0, 5200.0, 7000.0],
	&"i3": [900.0, 1200.0, 1600.0, 2200.0, 2900.0, 3900.0, 5200.0, 7000.0],
	&"boxer": [650.0, 900.0, 1250.0, 1700.0, 2350.0, 3350.0, 4700.0],
}
const ARQ_PADRAO := &"i4"

## A amostra do carro de rua e quanto ela sobe para o transito continuar no
## volume que tinha.
##
## O ponto (x) e o da grade mais perto do meio geometrico da faixa em que o
## transito anda: `Motor.giro_aparente` troca de marcha a um terco do corte, entao
## um sedan de rua vai de ~880 a ~2150 rpm, meio em ~1370 — o ponto de 1500. O
## Fusca vai de ~630 a ~1550, meio em ~990 — o de 900.
##
## O ganho (y) e medido, e nao gosto: sonoridade ponderada K (a do gerador) do
## loop antigo `motor_loop`, -12,0 dB, contra a da amostra escolhida: -22,2
## (i4 1500 on), -21,3 (i3 1600 on), -24,1 (boxer 900 on). A diferenca e o que
## deixa o transito no volume em que as outras frentes o equilibraram.
const RUA := {
	&"i4": Vector2(1500.0, 10.2),
	&"i3": Vector2(1600.0, 9.3),
	&"boxer": Vector2(900.0, 12.1),
}

## Nivel do banco no carro do jogador.
##
## Medido contra a mistura antiga em dez estados de giro e carga (marcha lenta,
## cidade, pe no fundo; ver o relatorio da troca): o banco novo ficou 1,9 dB
## abaixo, em mediana. Um decibel e nao dois porque o pulso de verdade tem fator
## de crista ~10 dB e a soma de senoides tinha ~5: no mesmo volume medio, o
## novo ja bate mais forte.
const DB_MOTOR := 1.0
## Volume do carro de rua, em carga baixa e alta. E o `DB_MEDIO` antigo; a
## diferenca de amostra vai por `RUA`.
const DB_RUA := Vector2(-19.0, -8.0)
## Velocidade de referencia do rolamento do pneu, em m/s.
const REF_PNEU := 20.0

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

## O assobio do cambio.
##
## `motor_cambio` e um tom de 1000 Hz. O que assobia e o par de engrenagens
## engrenado, na frequencia de engrenamento: rotacao do primario vezes dentes do
## pinhao. Num cambio de eixos paralelos a distancia entre eixos e fixa, entao a
## soma de dentes de cada par e quase constante (~56) e o pinhao de uma relacao r
## tem 56/(1+r) dentes: a primeira (3,45) engrena com ~13 dentes e assobia grave;
## a quinta (0,76), com ~32, assobia agudo. A 3000 rpm: 630 Hz e 1590 Hz.
const REF_CAMBIO := 1000.0
const DENTES_PAR := 56.0
## Diferencial de referencia para separar a marcha da relacao total. O som so
## recebe giro e velocidade: giro/rotacao da roda E a relacao total (marcha
## vezes diferencial), e a marcha sai dividindo pelo diferencial tipico da
## ficha (3,79 a 4,38). O erro de ate 8% move o assobio uns 2%, que ninguem ouve.
const DIFERENCIAL_TIPICO := 4.06
## Volume do assobio, parado e em velocidade. Baixo de proposito: e um fio por
## baixo do motor, que o ouvido acha quando procura e nao nota quando nao procura.
const DB_CAMBIO := Vector2(-46.0, -33.0)
const VEL_CAMBIO := Vector2(2.0, 30.0)

## Quao depressa o volume persegue o alvo. O giro ja e suave por vir da fisica;
## o que precisa de amortecimento e a CARGA, que salta de 0 a 1 num quadro
## quando o pe desce.
const SUAVIDADE := 12.0
## O corte e a unica coisa que NAO se suaviza: o buraco tem de ser seco.
const SUAVIDADE_CORTE := 60.0

## Alcance. Um motor de carro de rua nao se ouve a quarenta metros numa cidade
## com vento e chuva; a trinta ja esta no limite.
const ALCANCE := 34.0

## Afinacao que um tocador do banco pode receber. Larga de proposito: o tocador
## mudo de 650 rpm continua acompanhando um motor a 7000 (ver o cabecalho), e o
## que importa e ele estar no passo quando voltar a soar. Nenhum giro da ficha
## sai desta faixa (0,08 a 12,3 no pior caso).
const AFINACAO_BANCO := Vector2(0.05, 16.0)

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

var _arq: StringName = ARQ_PADRAO
var _refs := PackedFloat32Array()
## Dois tocadores por ponto da grade: [2k] em carga, [2k+1] em retencao.
var _banco: Array[AudioStreamPlayer3D] = []
var _rua: AudioStreamPlayer3D
var _pneu: AudioStreamPlayer3D
var _canta: AudioStreamPlayer3D
var _vento: AudioStreamPlayer3D
var _cambio: AudioStreamPlayer3D
var _extra: AudioStreamPlayer3D

var _ligado: bool = false
var _carga: float = 0.0
var _corte: float = 0.0
var _giro: float = 0.0
var _escorrega: float = 0.0
## Relacao total (giro do motor / giro da roda), suavizada. Ver `_assobiar`.
var _relacao: float = 0.0
## Carga do quadro anterior: o estouro do escapamento e uma BORDA de descida
## do pedal, e nao um estado.
var _carga_anterior: float = 0.0
var _desde_alivio: float = 9.0
## Corte de giro do motor que este som acompanha, para o limiar de estouro
## ser o mesmo pedaco de faixa em qualquer carro.
var _ref_corte: float = 6500.0

## O que a ultima mistura decidiu, para o diagnostico: o ponto de baixo da
## grade, a fracao ate o de cima, e a soma dos pesos lineares e em potencia.
var _ponto: int = 0
var _entre: float = 0.0
var _soma_linear: float = 0.0
var _soma_potencia: float = 0.0


func _ready() -> void:
	_refs = _grade(_arq)
	_rua = _tocador("Rua", ALCANCE)
	_extra = _tocador("Eventos", 30.0)
	_extra.unit_size = 4.0
	_extra.volume_db = -10.0


## A arquitetura de motor de um modelo de carro.
##
## Mora aqui, e nao na `FichaTecnica`, porque so o som pergunta: a fisica do
## carro nao sabe quantos cilindros tem, sabe o torque e o giro.
static func arquitetura_de(modelo: Carroceria.Modelo) -> StringName:
	match modelo:
		Carroceria.Modelo.FUSCA:
			return &"boxer"
		Carroceria.Modelo.HATCH:
			return &"i3"
	return ARQ_PADRAO


## Escolhe o banco deste motor: `&"i4"`, `&"i3"` ou `&"boxer"`. Desconhecido vira
## quatro em linha. Pode ser chamado a qualquer momento — com o motor rodando, o
## banco troca na hora.
func definir_arquitetura(tipo: StringName) -> void:
	var novo := tipo
	if not GRADES.has(tipo):
		push_warning("MotorSom: arquitetura '%s' desconhecida, usando %s" % [tipo, ARQ_PADRAO])
		novo = ARQ_PADRAO
	if novo == _arq:
		return
	_arq = novo
	_refs = _grade(_arq)
	if detalhado:
		_montar_banco()
	if _ligado:
		_acender()


func arquitetura() -> StringName:
	return _arq


## As camadas caras nascem so quando alguem senta ao volante. Ate la o no e o
## mesmo carro de rua de antes, com um tocador.
func detalhar() -> void:
	if detalhado:
		return
	detalhado = true
	_montar_banco()
	_pneu = _tocador("Pneu", 26.0)
	_canta = _tocador("Canta", 40.0)
	# O vento e de dentro do carro, e nao do mundo: quem o ouve e quem esta
	# sentado. Alcance curto para nao vazar para a calcada.
	_vento = _tocador("Vento", 9.0)
	_cambio = _tocador("Cambio", 20.0)
	if _ligado:
		_acender()


func _montar_banco() -> void:
	for p: AudioStreamPlayer3D in _banco:
		p.stop()
		# `free`, e nao `queue_free`: o banco novo nasce no mesmo quadro com os
		# mesmos nomes quando a grade coincide, e um irmao homonimo ainda vivo e
		# renomeado em silencio.
		p.free()
	_banco.clear()
	for ref: float in _refs:
		for carga: String in ["on", "off"]:
			_banco.append(_tocador("Motor_%d_%s" % [int(ref), carga], ALCANCE))


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
	# dois desenhos e um engasgo de carga vira um guincho. Todos os tocadores do
	# banco estao no mesmo ponto, entao o Doppler e o mesmo para todos e nao tira
	# ninguem de passo.
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


static func _grade(arq: StringName) -> PackedFloat32Array:
	var lista: Array = GRADES.get(arq, GRADES[ARQ_PADRAO])
	return PackedFloat32Array(lista)


# --- ignicao ----------------------------------------------------------------

func partir() -> void:
	_ligado = true
	_tocar(&"motor_partida", -8.0)
	_acender()


func desligar() -> void:
	_ligado = false
	for p: AudioStreamPlayer3D in _continuos():
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


## Todo tocador que toca em laco (tudo menos os eventos).
func _continuos() -> Array[AudioStreamPlayer3D]:
	var lista: Array[AudioStreamPlayer3D] = []
	lista.append_array(_banco)
	for p: AudioStreamPlayer3D in [_rua, _pneu, _canta, _vento, _cambio]:
		if p != null:
			lista.append(p)
	return lista


func _acender() -> void:
	if not detalhado:
		_por_loop(_rua, _nome_rua(), true)
		return
	if _rua != null:
		_rua.stop()
		_rua.volume_db = -60.0
	_acender_banco()
	_por_loop(_pneu, &"pneu_loop", false)
	_por_loop(_canta, &"pneu_canta", false)
	_por_loop(_vento, &"vento_carro", false)
	_por_loop(_cambio, &"motor_cambio", true)


## Liga o banco inteiro, junto, e ja no passo.
##
## Se todos ja estao tocando, nao mexe: religar reiniciaria as amostras com o
## motor soando, e cada reinicio e um estalo. Se falta algum, param TODOS e
## partem juntos — um que partisse sozinho comecaria no angulo zero com os
## outros no meio do ciclo.
##
## A afinacao vai ANTES do `play`. O tocador 3D so comeca no proximo passo de
## fisica, com a afinacao que tiver entao, e um quadro inteiro a 1,0 poe o
## tocador de 800 rpm e o de 7000 quase um ciclo inteiro fora de passo.
func _acender_banco() -> void:
	if _banco.is_empty():
		return
	var todos := true
	for p: AudioStreamPlayer3D in _banco:
		todos = todos and p.playing
	if todos:
		return
	for p: AudioStreamPlayer3D in _banco:
		p.stop()
		p.volume_db = -60.0
	for k in _refs.size():
		for c in 2:
			var nome := StringName("motor_%s_%d_%s" % [_arq, int(_refs[k]), "on" if c == 0 else "off"])
			_banco[k * 2 + c].stream = _laco(nome, true)
	_afinar_banco(_giro_efetivo())
	for p: AudioStreamPlayer3D in _banco:
		if p.stream != null:
			p.play()


func _nome_rua() -> StringName:
	var ponto: Vector2 = RUA.get(_arq, RUA[ARQ_PADRAO])
	return StringName("motor_%s_%d_on" % [_arq, int(ponto.x)])


## Um laco que nao reinicia se ja estiver tocando o mesmo som.
func _por_loop(p: AudioStreamPlayer3D, nome: StringName, com_guarda: bool) -> void:
	if p == null:
		return
	if p.playing and p.get_meta(&"laco", &"") == nome:
		return
	var s := _laco(nome, com_guarda)
	if s == null:
		return
	p.stream = s
	p.set_meta(&"laco", nome)
	p.play()


## Copia em laco de um som do banco, com o fim do laco no lugar certo.
##
## Por que nao so `AudioDirector.em_loop`: ele poe o fim do laco em
## `data.size() / 2`, que e o numero de amostras em PCM de 16 bits e NAO e em
## QOA, o formato padrao de importacao do projeto. Medido em 22/09/2026 com
## captura no Master: o `pneu_loop` (QOA, 22050 amostras) tocado por `em_loop`
## repete a cada 0,203 s — correlacao 0,983 nesse atraso e -0,004 no de 1 s —,
## ou seja, so os primeiros 4476 bytes/2 do arquivo, com um estalo a cada volta.
## Aqui o fim sai do comprimento em segundos, que vale para qualquer formato.
##
## `com_guarda`: os arquivos do banco novo tem uma amostra a mais no fim, copia
## da primeira, que o reamostrador le quando interpola a ultima amostra do laco
## (ver `gravar_banco` no gerador). O laco para uma antes dela.
func _laco(nome: StringName, com_guarda: bool) -> AudioStream:
	var s := AudioDirector.em_loop(nome)
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		var amostras := roundi(w.get_length() * float(w.mix_rate))
		w.loop_end = maxi(1, amostras - (1 if com_guarda else 0))
	return s


# --- quadro a quadro --------------------------------------------------------

## Chamado todo quadro pelo carro.
##
## `giro` e `carga` vem do `Motor`; `velocidade` e do carro; `cortado` e o
## instante em que a faisca esta desligada, seja pelo limitador, seja pela
## embreagem aberta na troca; `escorrega` e quanto o pneu esta deslizando, de 0
## a 1, medido nas rodas de verdade.
func atualizar(giro: float, carga: float, velocidade: float, ligado: bool,
		cortado: bool, escorrega: float, delta: float) -> void:
	# O giro antes da partida: `partir` liga o banco ja afinado nele.
	_giro = giro
	if ligado != _ligado:
		if ligado:
			partir()
		else:
			desligar()
	if not _ligado:
		return

	var passo := minf(1.0, SUAVIDADE * delta)
	_carga = lerpf(_carga, clampf(carga, 0.0, 1.0), passo)
	_desde_alivio += delta
	_corte = lerpf(_corte, 1.0 if cortado else 0.0,
		minf(1.0, SUAVIDADE_CORTE * delta))

	var abafa := DB_CORTE * _corte

	if not detalhado:
		# Carro de rua: uma camada, afinada pelo giro. Nao canta pneu — o carro
		# da IA e cinematico, nao tem roda que escorregue, e um chiado sem causa
		# e pior que o silencio.
		_tocar_rua(abafa)
		return

	_misturar(abafa)
	_rolar(velocidade)
	_cantar(velocidade, escorrega, delta)
	_ventar(velocidade)
	_assobiar(velocidade, delta)
	_aliviar(carga)


func _giro_efetivo() -> float:
	var g := _giro if _giro > 1.0 else (_refs[0] if not _refs.is_empty() else 800.0)
	return g * _carater


## Afina o banco inteiro no mesmo giro: afinacao = giro / referencia, e o
## caracter do carro por cima. Todos, sempre — ver o cabecalho.
func _afinar_banco(efetivo: float) -> void:
	for k in _refs.size():
		var a := clampf(efetivo / _refs[k], AFINACAO_BANCO.x, AFINACAO_BANCO.y)
		_banco[k * 2].pitch_scale = a
		_banco[k * 2 + 1].pitch_scale = a


## O cruzamento: dois pontos vizinhos pelo giro, duas camadas pela carga.
##
## Os dois cruzamentos sao em potencia constante — cos e sen, cuja soma dos
## quadrados e 1 —, e nao em amplitude: amostras diferentes somam em potencia, e
## um cruzamento linear cava 3 dB no meio. Dentro de cada amostra o volume ja e o
## daquele giro e daquela carga; a soma dos pesos em potencia fica em 1 (0 dB) em
## qualquer ponto da grade, e o volume do motor anda so pela curva do banco.
func _misturar(abafa: float) -> void:
	var n := _refs.size()
	if n < 2 or _banco.size() != n * 2:
		return
	_afinar_banco(_giro_efetivo())
	var i := 0
	var t := 0.0
	if _giro >= _refs[n - 1]:
		i = n - 2
		t = 1.0
	elif _giro > _refs[0]:
		while i < n - 2 and _giro >= _refs[i + 1]:
			i += 1
		t = clampf(log(_giro / _refs[i]) / log(_refs[i + 1] / _refs[i]), 0.0, 1.0)
	var pesos_giro := Vector2(cos(t * PI * 0.5), sin(t * PI * 0.5))
	var pesos_carga := Vector2(sin(_carga * PI * 0.5), cos(_carga * PI * 0.5))
	var soma := 0.0
	var potencia := 0.0
	for k in n:
		var w_giro := 0.0
		if k == i:
			w_giro = pesos_giro.x
		elif k == i + 1:
			w_giro = pesos_giro.y
		for c in 2:
			var p := _banco[k * 2 + c]
			var w := w_giro * (pesos_carga.x if c == 0 else pesos_carga.y)
			if w < 0.001:
				p.volume_db = -60.0
				continue
			soma += w
			potencia += w * w
			p.volume_db = DB_MOTOR + _volume + abafa + linear_to_db(w)
	_ponto = i
	_entre = t
	_soma_linear = soma
	_soma_potencia = potencia


## O carro de rua: uma amostra, afinada pelo giro, volume pela carga.
func _tocar_rua(abafa: float) -> void:
	if _rua == null:
		return
	var ponto: Vector2 = RUA.get(_arq, RUA[ARQ_PADRAO])
	_rua.pitch_scale = clampf(_giro * _carater / ponto.x, 0.3, 3.0)
	_rua.volume_db = lerpf(DB_RUA.x, DB_RUA.y, _carga) + ponto.y + abafa + _volume


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


## O assobio do cambio.
##
## A marcha sai da razao entre giro e velocidade, sem perguntar ao cambio: giro
## do motor dividido pelo giro da roda E a relacao total engatada. Com a
## embreagem patinando na arrancada essa conta mente para cima (motor girando
## acima da roda), e e por isso que o assobio so existe acima de `VEL_CAMBIO.x`
## e comeca baixo — e a relacao e suavizada, para a troca de marcha deslizar em
## vez de pular.
##
## Mais alto nas marchas curtas (pinhao pequeno, dente mais carregado) e na re,
## que tem dentes retos e e o assobio que todo mundo conhece.
func _assobiar(velocidade: float, delta: float) -> void:
	if _cambio == null:
		return
	var v := absf(velocidade)
	if v < VEL_CAMBIO.x or _giro < 100.0:
		_cambio.volume_db = -60.0
		return
	var roda := v / Carroceria.RAIO_RODA * 60.0 / TAU
	var total := clampf(_giro / maxf(roda, 1.0), 2.0, 20.0)
	_relacao = total if _relacao <= 0.0 else lerpf(_relacao, total, minf(1.0, 6.0 * delta))
	var marcha := _relacao / DIFERENCIAL_TIPICO
	var hz := _giro / 60.0 * DENTES_PAR / (1.0 + marcha)
	_cambio.pitch_scale = clampf(hz / REF_CAMBIO, 0.2, 4.0)
	var t := clampf((v - VEL_CAMBIO.x) / (VEL_CAMBIO.y - VEL_CAMBIO.x), 0.0, 1.0)
	var db := lerpf(DB_CAMBIO.x, DB_CAMBIO.y, sqrt(t))
	db += clampf((marcha - 1.2) * 2.5, -3.0, 6.0)
	if velocidade < -0.5:
		db += 6.0
	# Embreagem aberta: o dente para de carregar e o assobio cai junto com o
	# motor.
	db += DB_CORTE * 0.5 * _corte
	_cambio.volume_db = db


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


## O que esta soando AGORA.
##
## Existe para o teste automatizado poder afirmar que o motor faz barulho, e nao
## so que os arquivos de som estao no disco. Um tocador com o stream certo, o
## volume certo e `playing` falso e o modo de falha silencioso desta classe: nada
## reclama, nada aparece no relatorio, e o carro anda mudo.
##
##   tocando       camadas de motor audiveis (acima de -59 dB) mais o pneu
##   vozes         tocadores em laco rodando, audiveis ou nao — e o custo
##   db_max        volume da camada de motor mais alta
##   afinacao      afinacao dessa camada
##   soma_potencia raiz da soma dos quadrados dos pesos do cruzamento: 1,0 em
##                 qualquer giro e carga, se o cruzamento esta certo
func diagnostico() -> Dictionary:
	var tocando := 0
	var vozes := 0
	var db := -99.0
	var afinacao := 0.0
	var motor: Array[AudioStreamPlayer3D] = []
	motor.append_array(_banco)
	if not detalhado and _rua != null:
		motor.append(_rua)
	for p: AudioStreamPlayer3D in motor:
		if not p.playing or p.volume_db <= -59.0:
			continue
		tocando += 1
		if p.volume_db > db:
			db = p.volume_db
			afinacao = p.pitch_scale
	if _pneu != null and _pneu.playing:
		tocando += 1
	for p: AudioStreamPlayer3D in _continuos():
		if p.playing:
			vozes += 1
	return {
		"detalhado": detalhado,
		"arquitetura": _arq,
		"tocando": tocando,
		"vozes": vozes,
		"db_max": db,
		"afinacao": afinacao,
		"giro": _giro,
		"carga": _carga,
		"ponto": _ponto,
		"entre": _entre,
		"soma_linear": _soma_linear,
		"soma_potencia": sqrt(_soma_potencia),
		"cambio_db": _cambio.volume_db if _cambio != null else -99.0,
		"cambio_afinacao": _cambio.pitch_scale if _cambio != null else 0.0,
		"canta_db": _canta.volume_db if _canta != null else -99.0,
		"vento_db": _vento.volume_db if _vento != null else -99.0,
		"escorrega": _escorrega,
	}


## Os tocadores do banco, para a bancada ler afinacao e volume de cada um.
func tocadores_do_banco() -> Array[AudioStreamPlayer3D]:
	return _banco.duplicate()


## As referencias da grade em uso.
func referencias() -> PackedFloat32Array:
	return _refs


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
	AudioDirector.registrar(nome, db, "motor")
