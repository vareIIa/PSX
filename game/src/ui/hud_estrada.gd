## O HUD do plano de dentro do carro na Estrada Velha.
##
## O que a referencia pede
## -----------------------
## Canto superior esquerdo: icone de lanterna (quadrado com borda cinza) e barra
## de vida segmentada em vermelho. Canto inferior direito: LOCAL e HORA em fonte
## pixelada branca com contorno. Nada de SPEED/GEAR/minimapa — a print de
## referencia e horror/viagem, nao corrida.
##
## Por que nao entra no grupo `hud`
## --------------------------------
## Porque `Cinema.iniciar` esconde esse grupo inteiro. Este HUD so existe dentro
## da cena cortada (e, depois, enquanto se dirige na Estrada Velha). Quem manda
## na visibilidade e o roteiro / o nivel, nao o grupo.
##
## Agnostico a camera
## ------------------
## 1P e 3P usam o mesmo HUD. Nao olha modo de camera; so desenha o que lhe
## passam (local, hora, vida, lanterna).
##
## A moldura fica dentro das tarjas
## --------------------------------
## As tarjas de cinema comem 30 px em cima e 30 embaixo. A margem e medida a
## partir da tarja, e nao da tela.
class_name HudEstrada
extends CanvasLayer

const TELA := Vector2(480.0, 270.0)
const TARJA := 30.0
const MARGEM := 4.0

const FONTE := "res://assets/fontes/psx_mono.fnt"
const FONTE_P := "res://assets/fontes/psx_pequena.fnt"

const COR_TEXTO := Color(1.0, 1.0, 1.0, 1.0)
const COR_BORDA := Color(0.55, 0.55, 0.55, 1.0)
const COR_FUNDO := Color(0.08, 0.08, 0.09, 0.92)
const COR_VIDA := Color(0.55, 0.05, 0.05, 1.0)
const COR_VIDA_VAZIA := Color(0.06, 0.06, 0.07, 1.0)
const COR_LANTERNA := Color(0.35, 0.35, 0.38, 1.0)
const COR_FEIXE := Color(0.95, 0.88, 0.35, 1.0)
const COR_FEIXE_OFF := Color(0.25, 0.25, 0.22, 1.0)

## Lado do quadrado da lanterna, em px da resolucao interna.
const ICONE := 14.0
## Espaco entre o icone e a barra.
const GAP := 3.0
## Largura total da barra de vida (borda inclusa).
const BARRA_L := 78.0
const BARRA_A := 10.0
## Segmentos da barra — a print mostra dez, com quatro preenchidos.
const SEGMENTOS := 10

var local_nome: String = "ESTRADA VELHA"
var hora_texto: String = "22:43"
var vida: int = 4
var vida_max: int = SEGMENTOS
var lanterna_ligada: bool = true

var _raiz: Control
var _icone: Control
var _barra: Control
var _local: Label
var _hora: Label
var _segmentos: Array[ColorRect] = []


func _ready() -> void:
	layer = 100
	# Igual ao Cinema: uma cena cortada nao para de desenhar porque alguem
	# apertou pausa, e o HUD dela tambem nao.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	_atualizar_textos()
	_atualizar_vida()
	_icone.queue_redraw()


func definir_local(nome: String) -> void:
	local_nome = nome
	_atualizar_textos()


func definir_hora(texto: String) -> void:
	hora_texto = texto
	_atualizar_textos()


## Minutos desde meia-noite (0..1439). Formata HH:MM.
func definir_hora_minutos(minutos: int) -> void:
	var m := posmod(minutos, 24 * 60)
	definir_hora("%02d:%02d" % [m / 60, m % 60])


func definir_vida(atual: int, maximo: int = -1) -> void:
	if maximo > 0:
		vida_max = maximo
	vida = clampi(atual, 0, maxi(1, vida_max))
	_atualizar_vida()


func definir_lanterna(ligada: bool) -> void:
	lanterna_ligada = ligada
	if _icone != null:
		_icone.queue_redraw()


## Atualizacao por quadro. A assinatura guarda pos/rumo/kmh/marcha/falta para
## o caller da abertura nao quebrar; o look de referencia nao usa velocidade
## nem mapa — so reaplica LOCAL/HORA/vida/lanterna.
func mostrar(pos: Vector3, rumo: float, kmh: float = 0.0, marcha: int = 0,
		falta_km: float = 0.0) -> void:
	# Silencia unused-parameter: estes campos existem para o caller da cena.
	if pos.y > 1.0e20 or rumo > 1.0e20 or kmh > 1.0e20 or marcha > 1_000_000 \
			or falta_km > 1.0e20:
		pass
	_atualizar_textos()
	_atualizar_vida()


func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "HudEstrada"
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)

	var topo := Vector2(MARGEM, TARJA + MARGEM)

	_icone = Control.new()
	_icone.name = "Lanterna"
	_icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icone.draw.connect(_desenhar_lanterna)
	_raiz.add_child(_icone)
	_icone.position = topo
	_icone.size = Vector2(ICONE, ICONE)

	_barra = Control.new()
	_barra.name = "Vida"
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.draw.connect(_desenhar_borda_barra)
	_raiz.add_child(_barra)
	_barra.position = topo + Vector2(ICONE + GAP, (ICONE - BARRA_A) * 0.5)
	_barra.size = Vector2(BARRA_L, BARRA_A)

	_montar_segmentos()

	# Duas linhas, alinhadas a direita, dentro da tarja de baixo.
	var texto_l := 200.0
	var texto_a := 12.0
	var base_y := TELA.y - TARJA - MARGEM - texto_a * 2.0 - 1.0
	var base_x := TELA.x - MARGEM - texto_l
	_local = _texto(FONTE, HORIZONTAL_ALIGNMENT_RIGHT,
		Vector2(base_x, base_y), Vector2(texto_l, texto_a))
	_hora = _texto(FONTE, HORIZONTAL_ALIGNMENT_RIGHT,
		Vector2(base_x, base_y + texto_a + 1.0), Vector2(texto_l, texto_a))


func _montar_segmentos() -> void:
	_segmentos.clear()
	# Interior da barra: 1 px de borda em volta.
	var interno := Vector2(BARRA_L - 2.0, BARRA_A - 2.0)
	var gap_seg := 1.0
	var n := float(SEGMENTOS)
	var largura := (interno.x - gap_seg * (n - 1.0)) / n
	for i in SEGMENTOS:
		var s := ColorRect.new()
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.color = COR_VIDA_VAZIA
		_barra.add_child(s)
		s.position = Vector2(1.0 + float(i) * (largura + gap_seg), 1.0)
		s.size = Vector2(largura, interno.y)
		_segmentos.append(s)


func _desenhar_lanterna() -> void:
	# Fundo + borda do quadrado.
	_icone.draw_rect(Rect2(Vector2.ZERO, Vector2(ICONE, ICONE)), COR_FUNDO, true)
	_icone.draw_rect(Rect2(Vector2.ZERO, Vector2(ICONE, ICONE)), COR_BORDA, false, 1.0)

	# Icone pixelado diagonal (aponta para cima-direita), desenhado em celulas
	# de 1 px sobre uma grade 12x12 com 1 px de margem interna.
	var px := 1.0
	var ox := 2.0
	var oy := 2.0
	# Corpo da lanterna (cinza).
	var corpo: Array[Vector2i] = [
		Vector2i(2, 8), Vector2i(3, 7), Vector2i(4, 6), Vector2i(5, 5),
		Vector2i(3, 8), Vector2i(4, 7), Vector2i(5, 6), Vector2i(6, 5),
		Vector2i(4, 8), Vector2i(5, 7), Vector2i(6, 6),
		Vector2i(5, 8), Vector2i(6, 7),
		Vector2i(6, 8),
		# Cabeca / lente
		Vector2i(7, 4), Vector2i(8, 3), Vector2i(7, 5), Vector2i(8, 4),
		Vector2i(9, 3), Vector2i(8, 5), Vector2i(9, 4),
	]
	for c in corpo:
		_icone.draw_rect(Rect2(ox + float(c.x) * px, oy + float(c.y) * px, px, px),
			COR_LANTERNA, true)

	# Feixe: amarelo se ligada, cinza morto se desligada.
	var feixe_cor := COR_FEIXE if lanterna_ligada else COR_FEIXE_OFF
	var feixe: Array[Vector2i] = [
		Vector2i(9, 2), Vector2i(10, 1), Vector2i(10, 2), Vector2i(11, 1),
		Vector2i(10, 3), Vector2i(11, 2),
	]
	for c in feixe:
		_icone.draw_rect(Rect2(ox + float(c.x) * px, oy + float(c.y) * px, px, px),
			feixe_cor, true)


func _desenhar_borda_barra() -> void:
	_barra.draw_rect(Rect2(Vector2.ZERO, Vector2(BARRA_L, BARRA_A)), COR_FUNDO, true)
	_barra.draw_rect(Rect2(Vector2.ZERO, Vector2(BARRA_L, BARRA_A)), COR_BORDA, false, 1.0)


func _texto(fonte: String, alinhamento: int, onde: Vector2,
		tamanho: Vector2) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = alinhamento
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override(&"font_color", COR_TEXTO)
	# Contorno grosso: o HUD cai sobre estrada clara e mata escura no mesmo
	# quadro. Sem contorno o texto some numa das duas metades.
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override(&"outline_size", 4)
	if ResourceLoader.exists(fonte):
		l.add_theme_font_override(&"font", load(fonte))
	_raiz.add_child(l)
	l.position = onde
	l.size = tamanho
	return l


func _atualizar_textos() -> void:
	if _local == null or _hora == null:
		return
	_local.text = "LOCAL: %s" % local_nome
	_hora.text = "HORA: %s" % hora_texto


func _atualizar_vida() -> void:
	if _segmentos.is_empty():
		return
	var maximo := maxi(1, vida_max)
	# Quantos segmentos acesos: escala vida/vida_max para SEGMENTOS.
	var acesos := int(round(float(clampi(vida, 0, maximo)) / float(maximo) * float(SEGMENTOS)))
	acesos = clampi(acesos, 0, SEGMENTOS)
	for i in _segmentos.size():
		_segmentos[i].color = COR_VIDA if i < acesos else COR_VIDA_VAZIA
