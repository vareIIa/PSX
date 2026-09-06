## Prancha de inventario, reproduzindo a referencia em PRINTS.
##
## Nao e uma HUD com caixas: e uma mesa coberta de papel, com uma faixa de couro
## costurada onde os objetos ficam soltos, etiquetas presas por alfinete, um
## cartao de status carimbado e uma polaroid colada torta.
##
## A leitura de cada peca importa mais que o alinhamento. Na referencia nada esta
## reto: a fita do titulo esta torta, a polaroid esta torta, as abas dos botoes
## sao trapezios. Alinhar tudo faria a prancha voltar a parecer interface.
##
## Montada por codigo. Numa tela de 480x270 cada pixel conta, e calcular as
## posicoes e mais confiavel que arrastar no editor.
class_name PranchaInventario
extends CanvasLayer

const UI := "res://assets/ui/%s.png"
const FONTE_P := "res://assets/fontes/psx_pequena.fnt"
const FONTE_M := "res://assets/fontes/psx_media.fnt"
const FONTE_T := "res://assets/fontes/psx_titulo.fnt"

const TELA := Vector2(480.0, 270.0)
## Barra preta em cima e embaixo, como na referencia.
const TARJA := 12.0

const SLOTS := 8
## As pontas da faixa sao ocupadas pelos cantos de papel com seta.
const PONTA := 36.0
const FAIXA := Rect2(16.0, 40.0, 448.0, 62.0)
const ICONE := 34.0

const TINTA := Color("2a1f16")
const TINTA_FRACA := Color("5a4a38")

signal fechou()

var aberta: bool = false
var _selecionado: int = 0
var _examinando: bool = false

var _raiz: Control
var _icones: Array[TextureRect] = []
var _etiquetas: Array[TextureRect] = []
var _pinos: Array[TextureRect] = []
var _contagens: Array[Label] = []
var _selecao: NinePatchRect
var _titulo: Label
var _sublinhado: TextureRect
var _descricao: Label
var _estado: Label
var _aba_usar: TextureRect
var _aba_examinar: TextureRect


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	_raiz.visible = false
	Inventario.mudou.connect(_atualizar)


# --- utilitarios de montagem ------------------------------------------------

func _tex(nome: String) -> Texture2D:
	var caminho := UI % nome
	if not ResourceLoader.exists(caminho):
		push_error("PranchaInventario: textura ausente %s" % caminho)
		return null
	return load(caminho)


## TextureRect com tamanho explicito precisa de expand_mode, e o retangulo so
## sobrevive se for definido depois de entrar na arvore.
func _imagem(nome: String, r: Rect2, estica: int = TextureRect.STRETCH_SCALE,
		giro_graus: float = 0.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _tex(nome)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = estica
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(t)
	t.position = r.position
	t.size = r.size
	if giro_graus != 0.0:
		t.pivot_offset = r.size * 0.5
		t.rotation = deg_to_rad(giro_graus)
	return t


func _rotulo(texto: String, r: Rect2, fonte: String, cor: Color,
		alinhamento: int = HORIZONTAL_ALIGNMENT_LEFT, quebra: bool = false) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_color_override(&"font_color", cor)
	l.horizontal_alignment = alinhamento
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if ResourceLoader.exists(fonte):
		l.add_theme_font_override(&"font", load(fonte))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if quebra else TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(l)
	l.position = r.position
	l.size = r.size
	return l


func _tarja(y: float) -> void:
	var c := ColorRect.new()
	c.color = Color.BLACK
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(c)
	c.position = Vector2(0.0, y)
	c.size = Vector2(TELA.x, TARJA)


# --- montagem ---------------------------------------------------------------

func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "Prancha"
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	_imagem("ui_colagem", Rect2(Vector2.ZERO, TELA))

	_montar_titulo()
	_montar_faixa()
	_montar_painel()
	_montar_cartao()
	_montar_polaroid()
	_montar_abas()

	_imagem("ui_vinheta", Rect2(Vector2.ZERO, TELA))
	_tarja(0.0)
	_tarja(TELA.y - TARJA)


func _montar_titulo() -> void:
	_imagem("ui_fita", Rect2(178.0, 16.0, 124.0, 20.0), TextureRect.STRETCH_SCALE, -1.5)
	_rotulo("INVENTARIO", Rect2(160.0, 16.0, 160.0, 20.0), FONTE_T, TINTA,
		HORIZONTAL_ALIGNMENT_CENTER)


func _montar_faixa() -> void:
	_imagem("ui_faixa", FAIXA)

	var passo := (FAIXA.size.x - PONTA * 2.0) / float(SLOTS)

	for i in SLOTS:
		var cx := FAIXA.position.x + PONTA + passo * (float(i) + 0.5)
		var cy := FAIXA.position.y + FAIXA.size.y * 0.44

		var icone := TextureRect.new()
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_raiz.add_child(icone)
		icone.position = Vector2(cx - ICONE * 0.5, cy - ICONE * 0.5)
		icone.size = Vector2(ICONE, ICONE)
		_icones.append(icone)

		# Etiqueta de contagem presa por alfinete, cobrindo um pedaco do objeto.
		# Na referencia ela cobre mesmo, e isso e proposital: papel colado por
		# cima e o que faz a coisa parecer montada a mao.
		_etiquetas.append(_imagem("ui_recorte", Rect2(cx + 1.0, cy + 9.0, 20.0, 15.0),
			TextureRect.STRETCH_SCALE, float(i % 3) * 2.0 - 2.0))
		_pinos.append(_imagem("ui_alfinete", Rect2(cx + 6.0, cy + 3.0, 9.0, 9.0)))
		_contagens.append(_rotulo("", Rect2(cx + 1.0, cy + 9.0, 20.0, 15.0),
			FONTE_P, TINTA, HORIZONTAL_ALIGNMENT_CENTER))

	# Etiqueta com o indice do slot, discreta, sob a faixa. Sem ela nao da para
	# saber em que posicao da lista o jogador esta quando os oito estao cheios.
	_rotulo("1 / %d" % SLOTS, Rect2(FAIXA.position.x, FAIXA.end.y - 12.0,
		FAIXA.size.x, 12.0), FONTE_P, Color(0.9, 0.86, 0.74),
		HORIZONTAL_ALIGNMENT_CENTER).name = "Indice"

	# Moldura branca fina da selecao. NinePatch para esticar sem borrar a borda.
	_selecao = NinePatchRect.new()
	_selecao.texture = _tex("ui_selecao")
	_selecao.patch_margin_left = 4
	_selecao.patch_margin_right = 4
	_selecao.patch_margin_top = 4
	_selecao.patch_margin_bottom = 4
	_selecao.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_selecao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_selecao)
	_selecao.size = Vector2(ICONE + 10.0, ICONE + 10.0)


func _montar_painel() -> void:
	_imagem("ui_papel", Rect2(16.0, 110.0, 218.0, 116.0), TextureRect.STRETCH_TILE)

	_imagem("ui_fita", Rect2(66.0, 116.0, 118.0, 18.0), TextureRect.STRETCH_SCALE, 1.5)
	_titulo = _rotulo("", Rect2(36.0, 116.0, 178.0, 18.0), FONTE_M, TINTA,
		HORIZONTAL_ALIGNMENT_CENTER)
	_sublinhado = _imagem("ui_sublinhado", Rect2(70.0, 134.0, 110.0, 5.0))

	_descricao = _rotulo("", Rect2(28.0, 144.0, 194.0, 68.0), FONTE_M, TINTA_FRACA,
		HORIZONTAL_ALIGNMENT_CENTER, true)


func _montar_cartao() -> void:
	_imagem("ui_papel", Rect2(240.0, 112.0, 96.0, 108.0), TextureRect.STRETCH_TILE)
	_imagem("ui_selo", Rect2(246.0, 116.0, 34.0, 34.0))
	_imagem("ui_recorte", Rect2(286.0, 120.0, 26.0, 15.0), TextureRect.STRETCH_SCALE, 8.0)

	_rotulo("KAORI ITO", Rect2(240.0, 154.0, 96.0, 14.0), FONTE_M, TINTA,
		HORIZONTAL_ALIGNMENT_CENTER)
	_rotulo("STATUS:", Rect2(240.0, 170.0, 96.0, 12.0), FONTE_P, TINTA_FRACA,
		HORIZONTAL_ALIGNMENT_CENTER)

	# O estado e a informacao mais importante do cartao e a unica em cor. Vai na
	# fonte de titulo, com contorno fino: verde pequeno sobre fita marrom some.
	_imagem("ui_fita_marrom", Rect2(244.0, 186.0, 88.0, 26.0),
		TextureRect.STRETCH_SCALE, -2.0)
	_estado = _rotulo("BEM", Rect2(244.0, 186.0, 88.0, 26.0), FONTE_T,
		Color("a6f07a"), HORIZONTAL_ALIGNMENT_CENTER)
	_estado.add_theme_color_override(&"font_outline_color", Color(0.09, 0.06, 0.03))
	_estado.add_theme_constant_override(&"outline_size", 3)


func _montar_polaroid() -> void:
	# Colada torta, com fita na ponta de cima. Reta ela vira retrato de
	# documento; torta ela vira uma foto que alguem prendeu ali.
	_imagem("ui_retrato", Rect2(352.0, 122.0, 78.0, 72.0), TextureRect.STRETCH_SCALE, 4.0)
	_imagem("ui_polaroid", Rect2(346.0, 116.0, 90.0, 100.0), TextureRect.STRETCH_SCALE, 4.0)
	_imagem("ui_fita", Rect2(360.0, 108.0, 62.0, 17.0), TextureRect.STRETCH_SCALE, -6.0)


func _montar_abas() -> void:
	_aba_usar = _imagem("ui_aba", Rect2(22.0, 228.0, 92.0, 24.0),
		TextureRect.STRETCH_SCALE, -1.0)
	_rotulo("USAR", Rect2(22.0, 228.0, 92.0, 24.0), FONTE_M, TINTA,
		HORIZONTAL_ALIGNMENT_CENTER)
	_imagem("ui_sublinhado", Rect2(42.0, 243.0, 52.0, 5.0))

	_aba_examinar = _imagem("ui_aba", Rect2(124.0, 228.0, 108.0, 24.0),
		TextureRect.STRETCH_SCALE, 1.0)
	_rotulo("EXAMINAR", Rect2(124.0, 228.0, 108.0, 24.0), FONTE_M, TINTA,
		HORIZONTAL_ALIGNMENT_CENTER)
	_imagem("ui_sublinhado", Rect2(144.0, 243.0, 68.0, 5.0))

	var dica := _rotulo("[A/D] escolher    [TAB] fechar",
		Rect2(240.0, 218.0, 232.0, 13.0), FONTE_P, Color(0.94, 0.9, 0.8),
		HORIZONTAL_ALIGNMENT_RIGHT)
	dica.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.8))
	dica.add_theme_constant_override(&"outline_size", 4)


# --- abrir e fechar ---------------------------------------------------------

func alternar() -> void:
	if aberta:
		fechar()
	else:
		abrir()


func abrir() -> void:
	if aberta:
		return
	aberta = true
	_examinando = false
	_raiz.visible = true
	# Pausa a arvore, nao um "modo menu": inimigo andando enquanto o jogador le
	# a descricao de uma bandagem e injusto e ninguem espera isso.
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioDirector.tocar_ui(&"pegar", -10.0)
	_atualizar()
	_animar_entrada()


func fechar() -> void:
	if not aberta:
		return
	aberta = false
	_raiz.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	AudioDirector.tocar_ui(&"clique", -8.0)
	fechou.emit()


## A prancha entra caindo um pouco, como papel largado na mesa. Curta de
## proposito: mais que 0,15 s vira transicao de menu e o jogador passa a esperar
## a animacao acabar toda vez que abre a bolsa.
func _animar_entrada() -> void:
	_raiz.position = Vector2(0.0, -7.0)
	_raiz.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var t := create_tween().set_parallel(true)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_raiz, "position", Vector2.ZERO, 0.14)
	t.tween_property(_raiz, "modulate", Color.WHITE, 0.1)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("inventario"):
		alternar()
		get_viewport().set_input_as_handled()
		return
	if not aberta:
		return

	if evento.is_action_pressed("pausa"):
		fechar()
	elif evento.is_action_pressed("mover_dir"):
		_mover(1)
	elif evento.is_action_pressed("mover_esq"):
		_mover(-1)
	elif evento.is_action_pressed("interagir"):
		_usar()
	elif evento.is_action_pressed("examinar"):
		_examinar()
	get_viewport().set_input_as_handled()


func _mover(passo: int) -> void:
	_selecionado = posmod(_selecionado + passo, SLOTS)
	_examinando = false
	AudioDirector.tocar_ui(&"clique", -14.0)
	_atualizar()
	# A moldura desliza ate o objeto novo em vez de saltar. Dois quadros de
	# movimento ja bastam para o olho seguir para onde ela foi.
	_selecao.scale = Vector2(1.12, 1.12)
	create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK) \
		.tween_property(_selecao, "scale", Vector2.ONE, 0.12)


func _usar() -> void:
	_piscar(_aba_usar)
	if Inventario.usar(_selecionado):
		AudioDirector.tocar_ui(&"pegar", -6.0)
	else:
		AudioDirector.tocar_ui(&"clique", -12.0)


func _examinar() -> void:
	_piscar(_aba_examinar)
	_examinando = not _examinando
	AudioDirector.tocar_ui(&"clique", -10.0)
	_atualizar()


## Aba afunda e escurece por um instante. E o retorno de que o botao foi
## acionado, sem precisar de estado de foco navegavel.
func _piscar(aba: TextureRect) -> void:
	if aba == null:
		return
	var y := aba.position.y
	aba.position.y = y + 1.0
	aba.modulate = Color(0.76, 0.72, 0.66)
	var t := create_tween()
	t.tween_interval(0.07)
	t.tween_callback(func() -> void:
		aba.position.y = y
		aba.modulate = Color.WHITE)


func _atualizar() -> void:
	var passo := (FAIXA.size.x - PONTA * 2.0) / float(SLOTS)

	for i in SLOTS:
		var e: Dictionary = Inventario.espacos[i]
		if e.is_empty():
			_icones[i].texture = null
			_contagens[i].text = ""
			_etiquetas[i].visible = false
			_pinos[i].visible = false
			continue
		var item: Item = e["item"]
		_icones[i].texture = item.icone
		var qtd := int(e["qtd"])
		_contagens[i].text = str(qtd)
		_etiquetas[i].visible = qtd > 1
		_pinos[i].visible = qtd > 1

	var cx := FAIXA.position.x + PONTA + passo * (float(_selecionado) + 0.5)
	var cy := FAIXA.position.y + FAIXA.size.y * 0.44
	_selecao.pivot_offset = _selecao.size * 0.5
	_selecao.position = Vector2(cx - _selecao.size.x * 0.5, cy - _selecao.size.y * 0.5)

	var indice := _raiz.get_node_or_null("Indice") as Label
	if indice != null:
		indice.text = "%d / %d" % [_selecionado + 1, SLOTS]

	var sel: Dictionary = Inventario.espacos[_selecionado]
	if sel.is_empty():
		_titulo.text = ""
		_sublinhado.visible = false
		_descricao.text = "Nada aqui."
	else:
		var item: Item = sel["item"]
		_titulo.text = item.nome.to_upper()
		_sublinhado.visible = true
		# Examinar troca a nota pessoal pela ficha seca. Sao duas vozes: o
		# personagem primeiro, o inventario depois.
		_descricao.text = ("%s\nQuantidade: %d" % [item.rotulo_tipo(), int(sel["qtd"])]) \
			if _examinando else item.descricao

	_estado.text = Inventario.estado()
	_estado.add_theme_color_override(&"font_color", Inventario.cor_do_estado())
