## O HUD do plano de dentro do carro: velocidade, marcha e o cartao do mapa.
##
## O que a print de referencia tem e o que ela nao tem
## ---------------------------------------------------
## A referencia e um HUD de jogo de corrida: TIME, LAP, POS, SPEED, GEAR e o
## minimapa. Aqui nao ha corrida nenhuma — ninguem esta em quarto lugar de doze
## e nao ha volta para completar — entao tempo, volta e posicao saem. Ficam a
## velocidade e a marcha, que sao leitura de painel de carro e nao de prova, e
## o mapa.
##
## E o mapa muda de canto: vai para o alto da direita, que e onde o minimapa
## deste jogo mora desde sempre. Um jogo que poe o mapa num canto durante a
## abertura e noutro durante a partida ensina o jogador a procurar duas vezes.
##
## Por que nao entra no grupo `hud`
## --------------------------------
## Porque `Cinema.iniciar` esconde esse grupo inteiro, e com razao: o cartao de
## missao e o prompt de interacao nao tem o que fazer numa cena cortada. Este
## HUD e o oposto — ele so existe DENTRO da cena cortada, e some quando ela
## acaba. Quem manda nele e o roteiro, e nao o grupo.
##
## A moldura fica dentro das tarjas
## --------------------------------
## As tarjas de cinema comem 30 px em cima e 30 embaixo. Um HUD desenhado a 7 px
## da borda, que e a margem do minimapa da cidade, nasceria embaixo da tarja e
## seria invisivel. Aqui a margem e medida a partir da tarja, e nao da tela.
class_name HudEstrada
extends CanvasLayer

const TELA := Vector2(480.0, 270.0)
## Altura da tarja de cinema. Vem do `Cinema`, e nao ha razao para os dois
## numeros existirem em separado — se um mudar, o HUD sai do lugar.
const TARJA := 30.0
const MARGEM := 6.0

const LADO := 82.0
## Metros por pixel do cartao. A 1,9 ele cobre 156 m, o que da uns oito segundos
## de estrada a frente e outros tantos atras: o bastante para a curva que vem
## aparecer no mapa antes de aparecer no para-brisa, que e a unica coisa que um
## mapa de estrada precisa fazer.
const ESCALA := 1.9

const UI := "res://assets/ui/%s.png"
const FONTE := "res://assets/fontes/psx_mono.fnt"
const FONTE_P := "res://assets/fontes/psx_pequena.fnt"

const COR_TEXTO := Color(0.94, 0.92, 0.86)

var _raiz: Control
var _cartao: Cartao
var _velocidade: Label
var _marcha: Label
var _rotulo: Label


## O cartao do mapa. Desenha a estrada, e nao a cidade.
##
## Nao reusa o `Mapa` de propósito: aquele desenha quadra, avenida, predio e
## nevoa de exploracao a partir da `MalhaUrbana`, e aqui nao existe nenhuma
## dessas coisas — existe uma linha no meio do mato. Emprestar aquele desenho
## daria um cartao de cidade vazio com uma faixa por cima.
class Cartao extends Control:
	## Constantes proprias, e nao as da classe de fora: uma classe interna do
	## GDScript nao enxerga o escopo de quem a contem, e escrever
	## `HudEstrada.ESCALA` aqui dentro criaria uma referencia circular entre as
	## duas na hora de resolver o tipo.
	const PAPEL := "res://assets/ui/ui_papel.png"
	const NORTE := "res://assets/ui/icone_norte.png"
	const ESCALA := 1.9
	const MATA := Color("6d7c4e")
	const MATA_ESCURA := Color("59683f")
	const TERRA := Color("c9b48a")
	const TINTA := Color("2a1f16")
	const SETA := Color("9c3320")

	var centro := Vector3.ZERO
	var rumo: float = 0.0
	var metros_por_pixel: float = ESCALA

	var _papel: Texture2D
	var _norte: Texture2D
	var _ultimo := Vector3(1e9, 0.0, 0.0)

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists(PAPEL):
			_papel = load(PAPEL)
		if ResourceLoader.exists(NORTE):
			_norte = load(NORTE)

	## Move o cartao. So redesenha quando andou um pixel inteiro: a estrada tem
	## sessenta pontos e o cartao nao muda nada enquanto o carro nao percorre os
	## dois metros que valem um pixel.
	func apontar(pos: Vector3, novo_rumo: float) -> void:
		rumo = novo_rumo
		centro = pos
		if pos.distance_squared_to(_ultimo) < metros_por_pixel * metros_por_pixel:
			return
		_ultimo = pos
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), MATA)
		if _papel != null:
			draw_texture_rect(_papel, Rect2(Vector2.ZERO, size), true,
				Color(1.0, 1.0, 1.0, 0.30))
		# Manchas de mata mais fechada. Sem elas o fundo e um retangulo verde
		# chapado e o cartao le como cor de fundo esquecida, e nao como floresta.
		for k in 7:
			var f := float(k)
			var p := Vector2(
				fposmod(centro.x * 0.35 + f * 37.0, size.x),
				fposmod(centro.z * 0.35 + f * 23.0, size.y))
			draw_circle(p, 7.0 + fmod(f, 3.0) * 4.0, MATA_ESCURA)

		_desenhar_estrada()
		_desenhar_seta()

		draw_rect(Rect2(Vector2.ZERO, size), TINTA, false, 1.0)
		if _norte != null:
			var lado := 16.0 * 0.72
			draw_texture_rect(_norte, Rect2(
				Vector2(size.x - 9.0, 9.0) - Vector2(lado, lado) * 0.5,
				Vector2(lado, lado)), false)

	## A estrada, em duas passadas: o barranco escuro por baixo e a terra por
	## cima. Uma linha so, de uma cor so, nao se separa do fundo verde depois que
	## o grao e o dither passam por cima do cartao.
	func _desenhar_estrada() -> void:
		var alcance := size.length() * metros_por_pixel
		var s := _estaca()
		var pontos := PackedVector2Array()
		var passo := 4.0
		var d := -alcance
		while d <= alcance:
			pontos.append(_para_tela(EstradaBuilder.ponto_em(s + d)))
			d += passo
		if pontos.size() < 2:
			return
		draw_polyline(pontos, TINTA, 6.0)
		draw_polyline(pontos, TERRA, 3.5)

	## Onde o carro esta ao longo da estrada. O cartao recebe a POSICAO, e a
	## estrada e parametrizada por distancia percorrida: como o caminho anda em
	## -Z, a estaca e o proprio -Z do ponto. E exato enquanto a estrada nao
	## voltar para tras, que e uma coisa que ela nunca faz.
	func _estaca() -> float:
		return -centro.z

	func _desenhar_seta() -> void:
		var p := _para_tela(centro)
		var frente := Vector2(-sin(rumo), -cos(rumo))
		var lado := Vector2(frente.y, -frente.x)
		for passo: Array in [[6.7, TINTA], [5.0, SETA]]:
			var e: float = passo[0]
			draw_colored_polygon(PackedVector2Array([
				p + frente * e,
				p + lado * e * 0.62 - frente * e * 0.55,
				p - frente * e * 0.22,
				p - lado * e * 0.62 - frente * e * 0.55,
			]), passo[1])

	func _para_tela(mundo: Vector3) -> Vector2:
		return (Vector2(mundo.x - centro.x, mundo.z - centro.z)
			/ metros_por_pixel + size * 0.5)


func _ready() -> void:
	layer = 100
	# Igual ao Cinema: uma cena cortada nao para de desenhar porque alguem
	# apertou pausa, e o HUD dela tambem nao.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()


func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "HudEstrada"
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)

	var canto := Vector2(TELA.x - LADO - MARGEM, TARJA + MARGEM)

	var sombra := ColorRect.new()
	sombra.color = Color(0.05, 0.04, 0.03, 0.45)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(sombra)
	sombra.position = canto + Vector2(2.0, 2.0)
	sombra.size = Vector2(LADO, LADO)

	_cartao = Cartao.new()
	_raiz.add_child(_cartao)
	_cartao.position = canto
	_cartao.size = Vector2(LADO, LADO)

	var fita := TextureRect.new()
	var caminho := UI % "ui_fita"
	if ResourceLoader.exists(caminho):
		fita.texture = load(caminho)
	fita.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fita.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fita.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(fita)
	fita.position = canto + Vector2(LADO * 0.5 - 17.0, -5.0)
	fita.size = Vector2(34.0, 11.0)
	fita.pivot_offset = Vector2(17.0, 5.5)
	fita.rotation = deg_to_rad(-4.0)

	_rotulo = _texto(FONTE_P, HORIZONTAL_ALIGNMENT_RIGHT,
		canto + Vector2(0.0, LADO + 1.0), Vector2(LADO, 12.0))
	_rotulo.add_theme_color_override(&"font_color", Color(0.84, 0.79, 0.66))

	# Velocidade e marcha, no canto de baixo a direita, como na referencia. Duas
	# linhas, e nao uma: a marcha muda sozinha e o olho precisa achar o numero
	# no mesmo lugar todas as vezes.
	_velocidade = _texto(FONTE, HORIZONTAL_ALIGNMENT_RIGHT,
		Vector2(TELA.x - 200.0 - MARGEM, TELA.y - TARJA - 30.0),
		Vector2(200.0, 14.0))
	_marcha = _texto(FONTE, HORIZONTAL_ALIGNMENT_RIGHT,
		Vector2(TELA.x - 200.0 - MARGEM, TELA.y - TARJA - 16.0),
		Vector2(200.0, 14.0))


func _texto(fonte: String, alinhamento: int, onde: Vector2,
		tamanho: Vector2) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = alinhamento
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override(&"font_color", COR_TEXTO)
	# Contorno grosso, como o da legenda da cena cortada. O HUD cai sobre a
	# estrada clara e sobre a mata escura no mesmo quadro: sem contorno o texto
	# some numa das duas metades, qualquer que seja a cor dele.
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override(&"outline_size", 5)
	if ResourceLoader.exists(fonte):
		l.add_theme_font_override(&"font", load(fonte))
	_raiz.add_child(l)
	l.position = onde
	l.size = tamanho
	return l


## Atualiza os numeros e o cartao. Quem chama e o carro, todo quadro.
func mostrar(pos: Vector3, rumo: float, kmh: float, marcha: int,
		falta_km: float) -> void:
	_velocidade.text = "SPEED: %d KM/H" % roundi(kmh)
	_marcha.text = "GEAR: %d" % marcha
	_rotulo.text = "S.THOME %d km" % maxi(0, roundi(falta_km))
	_cartao.apontar(pos, rumo)
