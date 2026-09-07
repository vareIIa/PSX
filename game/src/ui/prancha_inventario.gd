## Prancha de inventario / menu de pausa (ESC), reproduzindo a referencia em PRINTS.
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
##
## PAUSE/ESC e TAB abrem e fecham a mesma prancha. Nao ha menu de titulo no
## caminho de pausa - a bolsa e a pausa.
class_name PranchaInventario
extends CanvasLayer

const UI := "res://assets/ui/%s.png"
const FONTE_P := "res://assets/fontes/psx_pequena.fnt"
const FONTE_M := "res://assets/fontes/psx_media.fnt"
const FONTE_T := "res://assets/fontes/psx_titulo.fnt"

const TELA := Vector2(480.0, 270.0)
## Barra preta em cima e embaixo, como na referencia (~7 px em 480).
const TARJA := 8.0

const SLOTS := 8
## As pontas da faixa sao ocupadas pelos cantos de papel com seta.
const PONTA := 36.0
## Faixa sobe para a fita do titulo pousar em cima dela, como na print.
const FAIXA := Rect2(12.0, 32.0, 456.0, 60.0)
const ICONE := 34.0

const TINTA := Color("2a1f16")
const TINTA_FRACA := Color("5a4a38")
const TINTA_USAR := Color("6a2a1c")

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
var _lbl_usar: Label
var _lbl_examinar: Label
var _nome_jogador: Label
var _sobrenome_jogador: Label
var _foto: TextureRect


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	_raiz.visible = false
	Inventario.mudou.connect(_atualizar)
	RegistroCivil.jogador_mudou.connect(_atualizar_portador)
	_atualizar_portador()


## Nome e foto do dono da prancha. Chamado quando a ficha troca - partida nova
## ou save carregado.
func _atualizar_portador() -> void:
	var ficha := RegistroCivil.jogador
	if ficha.is_empty():
		_nome_jogador.text = ""
		_sobrenome_jogador.text = ""
		_foto.texture = null
		return
	var partes := String(ficha["nome"]).split(" ")
	_nome_jogador.text = partes[0]
	_sobrenome_jogador.text = partes[1] if partes.size() > 1 else ""
	_foto.texture = Retrato.gerar_textura(ficha.get("aparencia", {}))


# --- utilitarios de montagem ------------------------------------------------

func _tex(nome: String) -> Texture2D:
	var caminho := UI % nome
	if not ResourceLoader.exists(caminho):
		push_error("PranchaInventario: textura ausente %s" % caminho)
		return null
	return load(caminho)


func _grupo(r: Rect2, giro_graus: float = 0.0) -> Control:
	var g := Control.new()
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(g)
	g.position = r.position
	g.size = r.size
	if giro_graus != 0.0:
		g.pivot_offset = r.size * 0.5
		g.rotation = deg_to_rad(giro_graus)
	return g


## TextureRect com tamanho explicito precisa de expand_mode, e o retangulo so
## sobrevive se for definido depois de entrar na arvore.
func _imagem(nome: String, r: Rect2, estica: int = TextureRect.STRETCH_SCALE,
		giro_graus: float = 0.0, pai: Control = null) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _tex(nome)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = estica
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(pai if pai != null else _raiz).add_child(t)
	t.position = r.position
	t.size = r.size
	if giro_graus != 0.0:
		t.pivot_offset = r.size * 0.5
		t.rotation = deg_to_rad(giro_graus)
	return t


func _sombra(r: Rect2, alfa: float = 0.28, pai: Control = null) -> void:
	var c := ColorRect.new()
	c.color = Color(0.12, 0.08, 0.04, alfa)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(pai if pai != null else _raiz).add_child(c)
	c.position = r.position + Vector2(2.0, 3.0)
	c.size = r.size


func _rotulo(texto: String, r: Rect2, fonte: String, cor: Color,
		alinhamento: int = HORIZONTAL_ALIGNMENT_LEFT, quebra: bool = false,
		pai: Control = null) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_color_override(&"font_color", cor)
	l.horizontal_alignment = alinhamento
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if ResourceLoader.exists(fonte):
		l.add_theme_font_override(&"font", load(fonte))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if quebra else TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(pai if pai != null else _raiz).add_child(l)
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

	_montar_faixa()
	_montar_titulo()
	_montar_painel()
	_montar_cartao()
	_montar_polaroid()
	_montar_abas()

	# Vinheta fraca. Ela e a segunda de duas - o pos-processamento em 150 aplica
	# a propria por cima de tudo - e duas em forca cheia fecham as bordas da
	# prancha a ponto de o papel da referencia virar uma mesa marrom escura.
	_imagem("ui_vinheta", Rect2(Vector2.ZERO, TELA)).modulate = Color(1, 1, 1, 0.28)
	_tarja(0.0)
	_tarja(TELA.y - TARJA)


## Na referencia o titulo nao esta escrito no fundo: esta escrito numa fita
## crepe colada em cima da faixa de couro. A palavra pertence a mesa.
func _montar_titulo() -> void:
	var pedacos := [
		Rect2(118.0, 22.0, 68.0, 22.0), Rect2(178.0, 19.0, 76.0, 24.0),
		Rect2(246.0, 23.0, 72.0, 21.0), Rect2(308.0, 20.0, 62.0, 22.0),
	]
	var giros := [-2.5, 1.2, -0.8, 2.0]
	for i in pedacos.size():
		_imagem("ui_fita", pedacos[i], TextureRect.STRETCH_SCALE, giros[i])
	_rotulo("INVENTÁRIO", Rect2(140.0, 22.0, 200.0, 22.0), FONTE_T, TINTA,
		HORIZONTAL_ALIGNMENT_CENTER)


func _montar_faixa() -> void:
	_imagem("ui_faixa", FAIXA)

	var passo := (FAIXA.size.x - PONTA * 2.0) / float(SLOTS)

	for i in SLOTS:
		var cx := FAIXA.position.x + PONTA + passo * (float(i) + 0.5)
		var cy := FAIXA.position.y + FAIXA.size.y * 0.42

		var icone := TextureRect.new()
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_raiz.add_child(icone)
		icone.position = Vector2(cx - ICONE * 0.5, cy - ICONE * 0.5)
		icone.size = Vector2(ICONE, ICONE)
		_icones.append(icone)

		# Etiqueta de contagem presa por alfinete. Na referencia quase todo
		# objeto leva um pedaco de papel, mesmo quando a quantidade e 1.
		_etiquetas.append(_imagem("ui_recorte", Rect2(cx + 2.0, cy + 10.0, 18.0, 14.0),
			TextureRect.STRETCH_SCALE, float(i % 3) * 2.0 - 2.0))
		_pinos.append(_imagem("ui_alfinete", Rect2(cx + 6.0, cy + 4.0, 9.0, 9.0)))
		_contagens.append(_rotulo("", Rect2(cx + 2.0, cy + 10.0, 18.0, 14.0),
			FONTE_P, TINTA, HORIZONTAL_ALIGNMENT_CENTER))

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
	# Papel da nota + texto giram juntos - senao o rotulo fica reto sobre papel
	# torto e a peca volta a parecer HUD.
	var origem := Vector2(14.0, 102.0)
	var tamanho := Vector2(222.0, 120.0)
	var g := _grupo(Rect2(origem, tamanho), -2.0)
	_sombra(Rect2(Vector2.ZERO, tamanho), 0.28, g)
	_imagem("ui_papel", Rect2(Vector2.ZERO, tamanho), TextureRect.STRETCH_TILE, 0.0, g)
	# Cantos de fita prendendo o papel na mesa, como na referencia.
	_imagem("ui_fita", Rect2(-4.0, -4.0, 40.0, 13.0), TextureRect.STRETCH_SCALE, -8.0, g)
	_imagem("ui_fita", Rect2(188.0, 104.0, 36.0, 12.0), TextureRect.STRETCH_SCALE, 7.0, g)

	_imagem("ui_fita", Rect2(48.0, 8.0, 126.0, 18.0), TextureRect.STRETCH_SCALE, 1.2, g)
	_titulo = _rotulo("", Rect2(22.0, 8.0, 178.0, 18.0), FONTE_M, TINTA,
		HORIZONTAL_ALIGNMENT_CENTER, false, g)
	_sublinhado = _imagem("ui_sublinhado", Rect2(56.0, 26.0, 110.0, 5.0),
		TextureRect.STRETCH_SCALE, 0.0, g)

	# Fonte pequena: a media corta a descricao longa no meio da altura do papel.
	_descricao = _rotulo("", Rect2(12.0, 34.0, 198.0, 78.0), FONTE_P, TINTA_FRACA,
		HORIZONTAL_ALIGNMENT_CENTER, true, g)


func _montar_cartao() -> void:
	var origem := Vector2(240.0, 104.0)
	var tamanho := Vector2(100.0, 112.0)
	var g := _grupo(Rect2(origem, tamanho), 1.5)
	_sombra(Rect2(Vector2.ZERO, tamanho), 0.22, g)
	_imagem("ui_papel", Rect2(Vector2.ZERO, tamanho), TextureRect.STRETCH_TILE, 0.0, g)
	_imagem("ui_selo", Rect2(6.0, 4.0, 28.0, 28.0), TextureRect.STRETCH_SCALE, 0.0, g)
	_imagem("ui_recorte", Rect2(48.0, 8.0, 26.0, 15.0), TextureRect.STRETCH_SCALE, 8.0, g)

	# Nome do registro civil em duas linhas - nome brasileiro nao cabe em uma.
	_nome_jogador = _rotulo("", Rect2(-2.0, 36.0, 104.0, 12.0), FONTE_P, TINTA,
		HORIZONTAL_ALIGNMENT_CENTER, false, g)
	_sobrenome_jogador = _rotulo("", Rect2(-2.0, 47.0, 104.0, 12.0), FONTE_P,
		TINTA, HORIZONTAL_ALIGNMENT_CENTER, false, g)
	_rotulo("STATUS:", Rect2(2.0, 62.0, 96.0, 12.0), FONTE_P, TINTA_FRACA,
		HORIZONTAL_ALIGNMENT_CENTER, false, g)

	# Estado verde sobre fita marrom - unica cor viva do cartao, como na print.
	_imagem("ui_fita_marrom", Rect2(6.0, 78.0, 88.0, 26.0),
		TextureRect.STRETCH_SCALE, -2.0, g)
	_estado = _rotulo("BEM", Rect2(6.0, 78.0, 88.0, 26.0), FONTE_T,
		Color("a6f07a"), HORIZONTAL_ALIGNMENT_CENTER, false, g)
	_estado.add_theme_color_override(&"font_outline_color", Color(0.09, 0.06, 0.03))
	_estado.add_theme_constant_override(&"outline_size", 3)


## Colada torta, com fita em cima e embaixo. Reta ela vira retrato de documento;
## torta ela vira uma foto que alguem prendeu ali.
func _montar_polaroid() -> void:
	var origem := Vector2(344.0, 100.0)
	var tamanho := Vector2(100.0, 118.0)
	var g := _grupo(Rect2(origem, tamanho), 4.0)

	_imagem("ui_retrato", Rect2(8.0, 16.0, 78.0, 72.0), TextureRect.STRETCH_SCALE, 0.0, g)

	_foto = TextureRect.new()
	_foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_foto.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.add_child(_foto)
	_foto.position = Vector2(8.0, 16.0)
	_foto.size = Vector2(78.0, 72.0)

	_imagem("ui_polaroid", Rect2(2.0, 10.0, 90.0, 100.0), TextureRect.STRETCH_SCALE, 0.0, g)
	# Duas fitas, como na referencia: uma em cima e outra embaixo.
	_imagem("ui_fita", Rect2(16.0, 2.0, 62.0, 17.0), TextureRect.STRETCH_SCALE, -6.0, g)
	_imagem("ui_fita", Rect2(10.0, 98.0, 56.0, 15.0), TextureRect.STRETCH_SCALE, 8.0, g)


func _montar_abas() -> void:
	# Abas de papelao por baixo do papel da descricao, encostando nele.
	# Sem sublinhado: na referencia o texto sozinho marca o botao.
	_aba_usar = _imagem("ui_aba", Rect2(20.0, 220.0, 96.0, 28.0),
		TextureRect.STRETCH_SCALE, -2.0)
	_lbl_usar = _rotulo("USAR", Rect2(20.0, 220.0, 96.0, 28.0), FONTE_M, TINTA_USAR,
		HORIZONTAL_ALIGNMENT_CENTER)

	_aba_examinar = _imagem("ui_aba", Rect2(122.0, 222.0, 112.0, 28.0),
		TextureRect.STRETCH_SCALE, 1.5)
	_lbl_examinar = _rotulo("EXAMINAR", Rect2(122.0, 222.0, 112.0, 28.0), FONTE_M, TINTA,
		HORIZONTAL_ALIGNMENT_CENTER)

	var dica := _rotulo("[A/D] escolher  [E]/Q]  [ESC] fechar",
		Rect2(248.0, 242.0, 220.0, 14.0), FONTE_P, Color(0.94, 0.9, 0.8),
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


func _menu_sistema_visivel() -> bool:
	# Menu de titulo (layer 130) aberto: ESC e dele, nao da prancha.
	var pai := get_parent()
	if pai == null:
		return false
	for n: Node in pai.get_children():
		if n is Menu and (n as Menu).visible:
			return true
	return false


func _unhandled_input(evento: InputEvent) -> void:
	# ESC/PAUSE e TAB abrem e fecham a mesma prancha. A pausa do jogo E a bolsa.
	if evento.is_action_pressed("inventario") or evento.is_action_pressed("pausa"):
		if not aberta and _menu_sistema_visivel():
			return
		alternar()
		get_viewport().set_input_as_handled()
		return
	if not aberta:
		return

	if evento.is_action_pressed("mover_dir"):
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
	_selecao.scale = Vector2(1.12, 1.12)
	create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK) \
		.tween_property(_selecao, "scale", Vector2.ONE, 0.12)


func _usar() -> void:
	_piscar(_aba_usar)
	if _lbl_usar != null:
		_lbl_usar.add_theme_color_override(&"font_color", Color("a05030"))
		create_tween().tween_callback(func() -> void:
			_lbl_usar.add_theme_color_override(&"font_color", TINTA_USAR))
	if Inventario.usar(_selecionado):
		AudioDirector.tocar_ui(&"pegar", -6.0)
	else:
		AudioDirector.tocar_ui(&"clique", -12.0)


func _examinar() -> void:
	_piscar(_aba_examinar)
	# A carteira e o unico item que nao se examina por texto. Ler "sou eu, o
	# nome, o numero" seria descrever um documento que o jogo consegue MOSTRAR.
	var e: Dictionary = Inventario.espacos[_selecionado]
	if not e.is_empty() and (e["item"] as Item).id == &"identidade":
		if not RegistroCivil.jogador.is_empty():
			Documento.abrir(RegistroCivil.jogador)
			return
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
		# Na referencia o pedaco de papel aparece em quase todo objeto.
		_etiquetas[i].visible = true
		_pinos[i].visible = true
		_contagens[i].text = str(qtd)

	var cx := FAIXA.position.x + PONTA + passo * (float(_selecionado) + 0.5)
	var cy := FAIXA.position.y + FAIXA.size.y * 0.42
	_selecao.pivot_offset = _selecao.size * 0.5
	_selecao.position = Vector2(cx - _selecao.size.x * 0.5, cy - _selecao.size.y * 0.5)

	var sel: Dictionary = Inventario.espacos[_selecionado]
	if sel.is_empty():
		_titulo.text = ""
		_sublinhado.visible = false
		_descricao.text = "Nada aqui."
	else:
		var item: Item = sel["item"]
		_titulo.text = item.nome.to_upper()
		_sublinhado.visible = true
		_descricao.text = ("%s\nQuantidade: %d" % [item.rotulo_tipo(), int(sel["qtd"])]) \
			if _examinando else item.descricao

	_estado.text = Inventario.estado()
	_estado.add_theme_color_override(&"font_color", Inventario.cor_do_estado())
