## Autoload. O olho PSX que aparece quando uma escolha vai pesar no futuro.
##
## So a borda do olho, translucida, no canto de cima da imagem. Ele abre, olha
## para um lado, olha para o outro, pisca e some. E a unica interface do jogo
## que nao finge ser papel, de proposito: ela nao pertence ao mundo, pertence
## ao destino. Desenho e tempo vem do roteiro da Missao 1, secao 1.
##
## Por que e desenhado em linha e nao textura
## ------------------------------------------
## Uma textura de olho em 52x26 escalada pela janela vira borrao ou escada de
## pixel grosso dos dois jeitos errados. Desenhado em linha de 1 px na grade de
## 480x270, ele e da mesma familia da imagem 3D: os vertices caem em pixel
## inteiro, tremem um pixel de vez em quando como o vertex snapping do
## `psx_surface`, e a iris anda em degraus a 15 quadros por segundo, que e a
## cadencia das animacoes do jogo.
##
## Contrato (nao muda): `mostrar` toca a animacao inteira e emite `terminou` no
## fim; chamar de novo durante a animacao reinicia. O olho nunca bloqueia nada:
## a conversa continua atras dele.
extends CanvasLayer

signal terminou()

## Caixa do olho na resolucao interna, e onde ela fica: canto superior direito
## da area de imagem, 8 px abaixo da tarja de cima e 10 px da borda direita.
const TAMANHO := Vector2(52.0, 26.0)
const MARGEM_DIREITA := 10.0
const ABAIXO_DA_TARJA := 8.0
const TELA := Vector2(480.0, 270.0)
## A tarja da cena cortada (`Cinematica.TARJA`). Fora de cena nao ha tarja e o
## olho fica 8 px abaixo da borda.
const TARJA_CINEMA := 33.0
## O bege do texto de cena, com alfa 0,55.
const COR := Color("ebe3cc")
const ALFA := 0.55

## Linha do tempo (segundos). Ver o roteiro, secao 1.
const T_ABRE := 0.25
const T_ESQUERDA := 0.70
const T_DIREITA := 1.20
const T_CENTRO := 1.45
const T_PISCA := 1.60
const T_FIM := 1.90
## A piscada, quadro a quadro: meio, fechado, meio, aberto.
const PISCADA: Array[float] = [0.5, 0.0, 0.5, 1.0]
## A iris leva este tempo para correr de um lado ao outro; o resto da janela e
## o olho segurando o olhar.
const CORRIDA := 0.16
## Quadros por segundo da animacao. As poses dos personagens andam a 15.
const QPS := 15.0
## Quanto a iris corre para cada lado, em px.
const DESVIO_IRIS := 9.0
const RAIO_IRIS := 7.5
## Quantos pontos cada palpebra tem. Poucos de proposito: e o poligono de baixa
## contagem que faz a curva ler como PSX e nao como vetor de app.
const PONTOS_PALPEBRA := 9
const PONTOS_IRIS := 14
## Chance de um vertice pular um pixel a cada quadro da animacao.
const TREMOR := 0.14
## Som: a interferencia do radio, bem baixa e sem grave, so na abertura.
const SOM := &"interferencia"
const SOM_DB := -20.0
const CORTE_GRAVE_HZ := 700.0
const BUS_SOM := &"OlhoBorboleta"

var _tela: Control
var _t := -1.0
var _quadro := -1
var _abertura := 0.0
var _iris := 0.0
var _alfa := 0.0
var _origem := Vector2.ZERO
## Desvio de um pixel por vertice neste quadro: palpebra de cima, de baixo,
## iris.
var _sacudida: PackedVector2Array = PackedVector2Array()
var _som: AudioStreamPlayer
var _sorte := RandomNumberGenerator.new()


func _ready() -> void:
	# Acima do pos-processamento (150) nao: o olho recebe o mesmo grao e dither
	# do resto. Abaixo da Cinematica (145) tambem nao, porque aparece por cima
	# das tarjas.
	layer = 146
	# Sempre: o olho que congela no meio porque alguem abriu o menu deixaria o
	# `await terminou` do roteiro preso.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tela = Control.new()
	_tela.name = "Olho"
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tela)
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tela.draw.connect(_desenhar)
	_tela.visible = false
	_sacudida.resize(PONTOS_PALPEBRA * 2 + PONTOS_IRIS)
	set_process(false)
	Borboleta.marcou.connect(_ao_marcar)


func _ao_marcar(_chave: StringName, _valor: Variant, olho: bool) -> void:
	if olho:
		mostrar()


## Toca o olho: abre, olha esquerda, olha direita, volta, pisca, some.
func mostrar() -> void:
	_t = 0.0
	_quadro = -1
	_tela.visible = true
	set_process(true)
	_tocar_som()
	_atualizar(0.0)


## Se o olho esta na tela agora.
func mostrando() -> bool:
	return _t >= 0.0


func _process(delta: float) -> void:
	if _t < 0.0:
		set_process(false)
		return
	_t += delta
	if _t >= T_FIM:
		_t = -1.0
		_tela.visible = false
		set_process(false)
		_parar_som()
		terminou.emit()
		return
	_atualizar(_t)


## A pose do olho no tempo `t`, amostrada a 15 qps.
func _atualizar(t: float) -> void:
	var q := int(floor(t * QPS))
	if q == _quadro:
		return
	_quadro = q
	var tq := float(q) / QPS

	var cinema := get_node_or_null(^"/root/Cinema")
	var com_tarja := cinema != null and bool(cinema.get(&"ativa"))
	_origem = Vector2(TELA.x - MARGEM_DIREITA - TAMANHO.x,
		(TARJA_CINEMA if com_tarja else 0.0) + ABAIXO_DA_TARJA)

	_abertura = pose_abertura(tq)
	_iris = pose_iris(tq)
	_alfa = pose_alfa(tq)
	for i: int in _sacudida.size():
		var d := Vector2.ZERO
		if _sorte.randf() < TREMOR:
			d = Vector2(float(_sorte.randi_range(-1, 1)), float(_sorte.randi_range(-1, 1)))
		_sacudida[i] = d
	_tela.queue_redraw()
	if t > T_ABRE and _som != null and _som.playing:
		_parar_som()


## Quanto o olho esta aberto (0 fechado, 1 aberto) no tempo `t`.
static func pose_abertura(t: float) -> float:
	if t < T_ABRE:
		return clampf(t / T_ABRE, 0.0, 1.0)
	if t >= T_CENTRO and t < T_PISCA:
		# Piscada em quatro quadros: meio, fechado, meio, aberto.
		var k := int(floor((t - T_CENTRO) / (T_PISCA - T_CENTRO) * 4.0))
		return PISCADA[clampi(k, 0, PISCADA.size() - 1)]
	return 1.0


## Onde a iris esta, de -1 (esquerda) a 1 (direita).
static func pose_iris(t: float) -> float:
	if t < T_ABRE:
		return 0.0
	if t < T_ESQUERDA:
		return -_corrida((t - T_ABRE) / CORRIDA)
	if t < T_DIREITA:
		return lerpf(-1.0, 1.0, _corrida((t - T_ESQUERDA) / (CORRIDA * 1.5)))
	if t < T_CENTRO:
		return 1.0 - _corrida((t - T_DIREITA) / CORRIDA)
	return 0.0


static func pose_alfa(t: float) -> float:
	if t < T_ABRE:
		return ALFA * clampf(t / T_ABRE, 0.0, 1.0)
	if t < T_PISCA:
		return ALFA
	return ALFA * (1.0 - clampf((t - T_PISCA) / (T_FIM - T_PISCA), 0.0, 1.0))


static func _corrida(u: float) -> float:
	var x := clampf(u, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


# --- desenho ------------------------------------------------------------------

## Meia altura da palpebra de cima e de baixo na coluna `x` (-1 a 1).
static func _palpebra(x: float, abertura: float, de_cima: bool) -> float:
	var curva := maxf(0.0, 1.0 - x * x)
	var meia := TAMANHO.y * 0.5 - 1.0
	if de_cima:
		return -meia * abertura * pow(curva, 0.8)
	# A de baixo e mais rasa: olho de gente, nao amendoa simetrica.
	return meia * 0.72 * abertura * pow(curva, 1.1)


## Pixel inteiro mais meio: a linha de 1 px cai inteira numa coluna em vez de
## se dividir entre duas.
static func _px(p: Vector2) -> Vector2:
	return Vector2(floor(p.x) + 0.5, floor(p.y) + 0.5)


func _desenhar() -> void:
	if _t < 0.0 or _alfa <= 0.0:
		return
	var cor := Color(COR.r, COR.g, COR.b, _alfa)
	var centro := _origem + TAMANHO * 0.5
	var meia_l := TAMANHO.x * 0.5 - 1.0

	var cima := PackedVector2Array()
	var baixo := PackedVector2Array()
	for i: int in PONTOS_PALPEBRA:
		var x := lerpf(-1.0, 1.0, float(i) / float(PONTOS_PALPEBRA - 1))
		var px := centro.x + x * meia_l
		cima.append(_px(Vector2(px, centro.y + _palpebra(x, _abertura, true)) + _sacudida[i]))
		baixo.append(_px(Vector2(px, centro.y + _palpebra(x, _abertura, false))
			+ _sacudida[PONTOS_PALPEBRA + i]))
	_tela.draw_polyline(cima, cor, 1.0, false)
	_tela.draw_polyline(baixo, cor, 1.0, false)

	if _abertura <= 0.05:
		return
	# Iris: um anel, recortado pelas palpebras. Sem preenchimento, so os
	# trechos do anel que caem dentro do olho aberto. O pixel da iris anda em
	# degrau de 1 px.
	var c := Vector2(round(centro.x + _iris * DESVIO_IRIS), centro.y + 1.0)
	var trecho := PackedVector2Array()
	for i: int in PONTOS_IRIS + 1:
		var a := TAU * float(i) / float(PONTOS_IRIS)
		var p := c + Vector2(cos(a), sin(a)) * RAIO_IRIS
		var dentro := _dentro(p, centro, meia_l)
		if dentro:
			trecho.append(_px(p + _sacudida[PONTOS_PALPEBRA * 2 + (i % PONTOS_IRIS)]))
		if (not dentro or i == PONTOS_IRIS) and trecho.size() >= 2:
			_tela.draw_polyline(trecho, cor, 1.0, false)
		if not dentro:
			trecho = PackedVector2Array()
	# Pupila: um ponto de 2x2, se o olho estiver aberto o bastante para ela.
	if _dentro(c, centro, meia_l):
		_tela.draw_rect(Rect2(c - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), cor, true)


func _dentro(p: Vector2, centro: Vector2, meia_l: float) -> bool:
	var x := (p.x - centro.x) / meia_l
	if absf(x) >= 1.0:
		return false
	var y := p.y - centro.y
	return y > _palpebra(x, _abertura, true) + 0.5 and y < _palpebra(x, _abertura, false) - 0.5


# --- som ----------------------------------------------------------------------

func _tocar_som() -> void:
	if not AudioDirector.tem(SOM):
		return
	if _som == null:
		_garantir_bus()
		_som = AudioStreamPlayer.new()
		_som.name = "Som"
		_som.bus = BUS_SOM
		add_child(_som)
	_som.stream = AudioDirector.stream(SOM)
	_som.volume_db = SOM_DB
	_som.play()


func _parar_som() -> void:
	if _som == null or not _som.playing:
		return
	var t := create_tween()
	t.tween_property(_som, "volume_db", -60.0, 0.12)
	t.tween_callback(_som.stop)


## Bus proprio com corte de grave: a interferencia inteira tem um ronco que,
## somado a fala, parece defeito do audio e nao aviso.
func _garantir_bus() -> void:
	if AudioServer.get_bus_index(String(BUS_SOM)) >= 0:
		return
	var i := AudioServer.bus_count
	AudioServer.add_bus(i)
	AudioServer.set_bus_name(i, String(BUS_SOM))
	AudioServer.set_bus_send(i, &"Master")
	var corte := AudioEffectHighPassFilter.new()
	corte.cutoff_hz = CORTE_GRAVE_HZ
	AudioServer.add_bus_effect(i, corte)
