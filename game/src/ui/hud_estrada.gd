## HUD compartilhado de LOCAL / HORA / vida / lanterna.
##
## Por que o arquivo ainda se chama `hud_estrada.gd`
## ------------------------------------------------
## Nasceu na Estrada Velha, mas a mesma peca serve a Praça da Matriz (e
## qualquer outro lugar). O `class_name` continua `HudEstrada` para nao quebrar
## a class DB / .uid do Godot; a API e generica — as cenas so mudam os valores:
##
##     hud.definir_local("ESTRADA VELHA")   # ou "PRAÇA DA MATRIZ"
##     hud.definir_hora("22:43")            # ou "23:15"
##     hud.definir_vida(4, 10)
##     hud.definir_lanterna(true)
##
## Look da referencia
## ------------------
## Canto superior esquerdo (dentro da tarja): icone de lanterna em quadrado com
## borda cinza + barra de vida segmentada em vermelho. Canto inferior direito:
## duas linhas pixeladas brancas com contorno — LOCAL e HORA. Sem SPEED/GEAR/
## minimapa: a print e horror/viagem, nao corrida.
##
## Agnostico a camera
## ------------------
## 1P e 3P usam o mesmo HUD. Quem manda na visibilidade e o nivel / o roteiro.
##
## Por que nao entra no grupo `hud`
## --------------------------------
## `Cinema.iniciar` esconde esse grupo. Este HUD existe DENTRO da cena cortada
## (e depois, enquanto se dirige / anda no lugar). O roteiro controla.
class_name HudEstrada
extends CanvasLayer

const TELA := Vector2(480.0, 270.0)
const TARJA := 30.0
const MARGEM := 4.0

const FONTE := "res://assets/fontes/psx_mono.fnt"

const COR_TEXTO := Color(1.0, 1.0, 1.0, 1.0)
const COR_BORDA := Color(1.0, 1.0, 1.0, 1.0)
const COR_FUNDO := Color(0.0, 0.0, 0.0, 1.0)
const COR_VIDA := Color(1.0, 0.18, 0.12, 1.0)
const COR_VIDA_VAZIA := Color(0.02, 0.02, 0.025, 1.0)
const COR_LANTERNA := Color(1.0, 1.0, 1.0, 1.0)
const COR_FEIXE := Color(1.0, 1.0, 0.40, 1.0)
const COR_FEIXE_OFF := Color(0.40, 0.40, 0.36, 1.0)

const ICONE := 16.0
const GAP := 3.0
const BARRA_L := 84.0
const BARRA_A := 12.0
const SEGMENTOS := 10

## Defaults batem com a print da Estrada Velha; Praça sobrescreve na montagem.
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
	# Acima do PSXPost (layer 150): vinheta/scanline/quantize esmagavam o
	# canto TL (lanterna + vida). Texto LOCAL/HORA ja tinha contorno; o icone
	# 2px nao. Fica por cima do grao, legivel.
	layer = 160
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
	definir_hora("%02d:%02d" % [int(m / 60), m % 60])


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
## o caller da estrada nao quebrar; o look de referencia nao usa velocidade
## nem mapa — so reaplica LOCAL/HORA/vida/lanterna.
func mostrar(_pos: Vector3, _rumo: float, _kmh: float = 0.0, _marcha: int = 0,
		_falta_km: float = 0.0) -> void:
	_atualizar_textos()
	_atualizar_vida()


func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "HudLocal"
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

	var texto_l := 220.0
	var texto_a := 12.0
	var base_y := TELA.y - TARJA - MARGEM - texto_a * 2.0 - 1.0
	var base_x := TELA.x - MARGEM - texto_l
	_local = _texto(FONTE, HORIZONTAL_ALIGNMENT_RIGHT,
		Vector2(base_x, base_y), Vector2(texto_l, texto_a))
	_hora = _texto(FONTE, HORIZONTAL_ALIGNMENT_RIGHT,
		Vector2(base_x, base_y + texto_a + 1.0), Vector2(texto_l, texto_a))


func _montar_segmentos() -> void:
	# Segmentos desenhados em _desenhar_borda_barra (nao ColorRect):
	# 1px sob CRT some; draw_rect cheio + contorno branco sobrevive ao grao.
	_segmentos.clear()



func _desenhar_lanterna() -> void:
	# Icone grosso (blocos 2px): 1px some sob CRT/grao; branco puro + borda
	# clara le contra a noite.
	_icone.draw_rect(Rect2(Vector2.ZERO, Vector2(ICONE, ICONE)), COR_FUNDO, true)
	_icone.draw_rect(Rect2(Vector2.ZERO, Vector2(ICONE, ICONE)), COR_BORDA, false, 2.0)

	var px := 2.0
	var ox := 2.0
	var oy := 2.0
	var corpo: Array[Vector2i] = [
		Vector2i(1, 5), Vector2i(2, 4), Vector2i(3, 3),
		Vector2i(1, 4), Vector2i(2, 3),
		Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 3),
		Vector2i(2, 5), Vector2i(3, 4),
	]
	for c in corpo:
		_icone.draw_rect(Rect2(ox + float(c.x) * px, oy + float(c.y) * px, px, px),
			COR_LANTERNA, true)

	var feixe_cor := COR_FEIXE if lanterna_ligada else COR_FEIXE_OFF
	var feixe: Array[Vector2i] = [
		Vector2i(5, 1), Vector2i(5, 2), Vector2i(6, 1), Vector2i(6, 0),
	]
	for c in feixe:
		_icone.draw_rect(Rect2(ox + float(c.x) * px, oy + float(c.y) * px, px, px),
			feixe_cor, true)



func _desenhar_borda_barra() -> void:
	_barra.draw_rect(Rect2(Vector2.ZERO, Vector2(BARRA_L, BARRA_A)), COR_FUNDO, true)
	_barra.draw_rect(Rect2(Vector2.ZERO, Vector2(BARRA_L, BARRA_A)), COR_BORDA, false, 2.0)

	var interno := Vector2(BARRA_L - 4.0, BARRA_A - 4.0)
	var gap_seg := 4.0
	var nseg := float(SEGMENTOS)
	var largura := (interno.x - gap_seg * (nseg - 1.0)) / nseg
	var maximo := maxi(1, vida_max)
	var acesos := int(round(float(clampi(vida, 0, maximo)) / float(maximo) * float(SEGMENTOS)))
	acesos = clampi(acesos, 0, SEGMENTOS)
	for i in SEGMENTOS:
		var x := 2.0 + float(i) * (largura + gap_seg)
		var r := Rect2(x, 2.0, largura, interno.y)
		if i < acesos:
			_barra.draw_rect(r, COR_VIDA, true)
		else:
			_barra.draw_rect(r, COR_VIDA_VAZIA, true)



func _texto(fonte: String, alinhamento: int, onde: Vector2,
		tamanho: Vector2) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = alinhamento
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override(&"font_color", COR_TEXTO)
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
	if _barra != null:
		_barra.queue_redraw()
