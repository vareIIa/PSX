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
##
## Item selecionado gira numa vitrine 3D (SubViewport + ItemModelo). O bonequinho
## da polaroid e um Corpo vivo que olha para o cursor enquanto a prancha esta
## aberta — o mesmo padrao de criacao.gd.
class_name PranchaInventario
extends CanvasLayer

const UI := "res://assets/ui/%s.png"

const TELA := Vector2(480.0, 270.0)
## Barra preta em cima e embaixo, como na referencia (~7 px em 480).
const TARJA := 8.0

const SLOTS := 8
## As pontas da faixa sao ocupadas pelos cantos de papel com seta.
const PONTA := 36.0
## Faixa sobe para a fita do titulo pousar em cima dela, como na print.
const FAIXA := Rect2(12.0, UiEstilo.RE7_FAIXA_Y0, 456.0, UiEstilo.RE7_FAIXA_Y1 - UiEstilo.RE7_FAIXA_Y0) ## SPEC 28–60
const ICONE := 28.0
const ICONE_VITRINE := 36.0

const TINTA := Color("2a1f16")
const TINTA_FRACA := Color("5a4a38")
const TINTA_USAR := Color("6a2a1c")

signal fechou()
## O jogador pediu para voltar ao titulo pelo menu de sistema.
signal pediu_titulo()
## O jogador escolheu um espaco de save para carregar.
signal pediu_carregar(espaco: int)

var aberta: bool = false
var _selecionado: int = 0
var _examinando: bool = false

var _raiz: Control
var _icones: Array[TextureRect] = []
var _sombras: Array[ColorRect] = []
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

## Vitrine 3D do item selecionado: SubViewport + mesh low-poly (ItemModelo).
var _vitrine: SubViewport
var _vitrine_root: Node3D
var _vitrine_item: Node3D
var _vitrine_view: TextureRect
var _vitrine_item_id: StringName = &""
var _giro: float = 0.0

## Polaroid viva: SubViewport + Corpo (mesmo padrao de criacao.gd).
var _retrato_vp: SubViewport
var _retrato_corpo: Corpo

## Menu de sistema (os tres pauzinhos). Ver src/ui/menu_sistema.gd.
var _sistema: MenuSistema

## Onda 3 wire: inspeção orbitável + vitals (no lugar de BEM / status polaroid).
var _inspect: Control = null
var _vitals: Control = null

## A11Y_FOCUS_STACK — hits ≥32 na faixa legado (cutover grid OFF).
var _hits_slot: Array[Control] = []
var _stick_gate: MenuStickGate = MenuStickGate.new()


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
		if _retrato_corpo != null:
			_retrato_corpo.queue_free()
			_retrato_corpo = null
		return
	var partes := String(ficha["nome"]).strip_edges().split(" ", false)
	_nome_jogador.text = partes[0] if partes.size() > 0 else ""
	# Junta o resto: nomes compostos brasileiros nao cabem em so 2 tokens.
	_sobrenome_jogador.text = " ".join(partes.slice(1)) if partes.size() > 1 else ""
	_refazer_retrato(ficha.get("aparencia", {}))


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


## Onda polish: aplicar_re7_display|title|body|micro|vital — zero psx_*.fnt.
## tamanho escolhe o papel tipografico (RE7_SIZE_*); tracking vem do helper.
func _rotulo(texto: String, r: Rect2, tamanho: int, cor: Color,
		alinhamento: int = HORIZONTAL_ALIGNMENT_LEFT, quebra: bool = false,
		pai: Control = null, _peso: int = 400) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_color_override(&"font_color", cor)
	l.horizontal_alignment = alinhamento
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if tamanho >= UiEstilo.RE7_SIZE_DISPLAY:
		UiEstilo.aplicar_re7_display(l)
	elif tamanho >= UiEstilo.RE7_SIZE_TITLE:
		UiEstilo.aplicar_re7_title(l)
	elif tamanho == UiEstilo.RE7_SIZE_VITAL:
		UiEstilo.aplicar_re7_vital(l)
	elif tamanho <= UiEstilo.RE7_SIZE_MICRO:
		UiEstilo.aplicar_re7_micro(l)
	else:
		UiEstilo.aplicar_re7_body(l)
	# line-height por papel (SPEC_POLISH / RE7_LINE_*)
	var lh := UiEstilo.RE7_LINE_BODY
	if tamanho >= UiEstilo.RE7_SIZE_DISPLAY:
		lh = UiEstilo.RE7_LINE_DISPLAY
	elif tamanho >= UiEstilo.RE7_SIZE_TITLE:
		lh = UiEstilo.RE7_LINE_TITLE
	elif tamanho <= UiEstilo.RE7_SIZE_MICRO:
		lh = UiEstilo.RE7_LINE_MICRO
	l.add_theme_constant_override(&"line_spacing", maxi(0, lh - tamanho))
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

	_montar_onda3_wire()

	# Menu de sistema por ULTIMO: ele desenha por cima da prancha inteira,
	# inclusive da vinheta e das tarjas, porque e uma folha pousada em cima da
	# mesa e nao uma parte dela.
	_sistema = MenuSistema.new()
	_sistema.name = "MenuSistema"
	_raiz.add_child(_sistema)
	_sistema.continuar.connect(fechar)
	_sistema.sair_para_titulo.connect(func() -> void:
		fechar()
		pediu_titulo.emit())
	_sistema.carregou.connect(func(espaco: int) -> void:
		fechar()
		pediu_carregar.emit(espaco))


## Na referencia o titulo nao esta escrito no fundo: esta escrito numa fita
## crepe colada em cima da faixa de couro. A palavra pertence a mesa.
func _montar_titulo() -> void:
	var pedacos := [
		Rect2(118.0, 10.0, 68.0, 22.0), Rect2(178.0, 8.0, 76.0, 24.0),
		Rect2(246.0, 11.0, 72.0, 21.0), Rect2(308.0, 9.0, 62.0, 22.0),
	]
	var giros := [-2.5, 1.2, -0.8, 2.0]
	for i in pedacos.size():
		_imagem("ui_fita", pedacos[i], TextureRect.STRETCH_SCALE, giros[i])
	_rotulo("INVENTÁRIO", Rect2(140.0, UiEstilo.RE7_TITLE_BASELINE_Y - 12.0, 200.0, 24.0), UiEstilo.RE7_SIZE_DISPLAY, TINTA,
		HORIZONTAL_ALIGNMENT_CENTER, false, null, 600)


func _montar_faixa() -> void:
	_imagem("ui_faixa", FAIXA)

	var passo := (FAIXA.size.x - PONTA * 2.0) / float(SLOTS)

	for i in SLOTS:
		var cx := FAIXA.position.x + PONTA + passo * (float(i) + 0.5)
		var cy := FAIXA.position.y + FAIXA.size.y * 0.5

		# Sombra dura sob o icone - sem ela o sprite some no couro escuro.
		var sombra := ColorRect.new()
		sombra.color = Color(0.05, 0.03, 0.02, 0.45)
		sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sombra.visible = false
		_raiz.add_child(sombra)
		sombra.position = Vector2(cx - ICONE * 0.5 + 2.0, cy - ICONE * 0.5 + 3.0)
		sombra.size = Vector2(ICONE - 2.0, ICONE - 2.0)
		_sombras.append(sombra)

		var icone := TextureRect.new()
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Leve boost de brilho: o couro engole saturacao.
		icone.modulate = Color(1.12, 1.08, 1.02)
		_raiz.add_child(icone)
		icone.position = Vector2(cx - ICONE * 0.5, cy - ICONE * 0.5)
		icone.size = Vector2(ICONE, ICONE)
		_icones.append(icone)

		# Hit ≥32×32 STOP (SPEC_A11Y_RE7 §5) — visual ICONE 28 fica centrado.
		var hit := Control.new()
		hit.name = "HitSlot%d" % i
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.focus_mode = Control.FOCUS_ALL
		hit.position = Vector2(cx - 16.0, cy - 16.0)
		hit.size = Vector2(32.0, 32.0)
		var idx_hit := i
		hit.mouse_entered.connect(func() -> void: _ao_slot_hover(idx_hit))
		hit.gui_input.connect(func(ev: InputEvent) -> void: _ao_slot_input(ev, idx_hit))
		_raiz.add_child(hit)
		_hits_slot.append(hit)

		# Etiqueta de contagem presa por alfinete. Na referencia quase todo
		# objeto leva um pedaco de papel, mesmo quando a quantidade e 1.
		_etiquetas.append(_imagem("ui_recorte", Rect2(cx + 6.0, cy + 14.0, 18.0, 14.0),
			TextureRect.STRETCH_SCALE, float(i % 3) * 2.0 - 2.0))
		_pinos.append(_imagem("ui_alfinete", Rect2(cx + 10.0, cy + 8.0, 9.0, 9.0)))
		_contagens.append(_rotulo("", Rect2(cx + 6.0, cy + 14.0, 18.0, 14.0),
			UiEstilo.RE7_SIZE_MICRO, TINTA, HORIZONTAL_ALIGNMENT_CENTER))

	# Moldura branca fina da selecao. NinePatch para esticar sem borrar a borda.
	_selecao = NinePatchRect.new()
	_selecao.texture = _tex("ui_selecao")
	_selecao.patch_margin_left = 5
	_selecao.patch_margin_right = 5
	_selecao.patch_margin_top = 5
	_selecao.patch_margin_bottom = 5
	_selecao.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_selecao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_selecao)
	_selecao.size = Vector2(ICONE_VITRINE + 12.0, ICONE_VITRINE + 12.0)
	_wire_slot_hits_neighbors()

	_montar_vitrine()


func _montar_painel() -> void:
	# Largura menor que o cartao de status (que cresceu para nomes longos).
	# SPEC_POLISH §3.2 IDENTIDADE — 156×118 @ (14,128); style_re7_doc + DOC_INK
	var origem := Vector2(float(UiEstilo.RE7_SAFE) + 6.0, 128.0)
	var tamanho := Vector2(156.0, 118.0)
	var g := _grupo(Rect2(origem, tamanho), -1.5)
	g.name = "PainelIdentidade"
	_sombra(Rect2(Vector2.ZERO, tamanho), 0.28, g)
	_imagem("ui_papel", Rect2(Vector2.ZERO, tamanho), TextureRect.STRETCH_TILE, 0.0, g)
	# StyleBox doc tokens (pad); textura scrapbook fica por cima visualmente
	var doc_sb := UiEstilo.style_re7_doc()
	var doc_bg := Panel.new()
	doc_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doc_bg.add_theme_stylebox_override(&"panel", doc_sb)
	g.add_child(doc_bg)
	doc_bg.position = Vector2.ZERO
	doc_bg.size = tamanho
	doc_bg.modulate = Color(1, 1, 1, 0.35)
	_imagem("ui_fita", Rect2(-4.0, -4.0, 40.0, 13.0), TextureRect.STRETCH_SCALE, -8.0, g)
	_imagem("ui_fita", Rect2(120.0, 102.0, 36.0, 12.0), TextureRect.STRETCH_SCALE, 7.0, g)

	var pad := float(UiEstilo.RE7_PAD_PANEL)
	_imagem("ui_fita", Rect2(pad + 10.0, pad, 116.0, 18.0), TextureRect.STRETCH_SCALE, 1.2, g)
	_titulo = _rotulo("", Rect2(pad, pad, 156.0 - pad * 2.0, float(UiEstilo.RE7_LINE_TITLE)), UiEstilo.RE7_SIZE_TITLE, UiEstilo.RE7_DOC_INK,
		HORIZONTAL_ALIGNMENT_CENTER, false, g, 500)
	_sublinhado = _imagem("ui_sublinhado", Rect2(pad + 18.0, pad + 18.0, 100.0, 5.0),
		TextureRect.STRETCH_SCALE, 0.0, g)

	# BODY no papel = DOC_INK (nunca muted #8a)
	_descricao = _rotulo("", Rect2(pad, pad + 26.0, 156.0 - pad * 2.0, 56.0), UiEstilo.RE7_SIZE_BODY, UiEstilo.RE7_DOC_INK,
		HORIZONTAL_ALIGNMENT_CENTER, true, g)


func _montar_cartao() -> void:
	# Mais largo: nomes brasileiros longos (LOURIVAL CAVALCANTE) precisam de
	# faixa horizontal — o cartao estreito (~104 px) cortava o sobrenome.
	var origem := Vector2(184.0, 128.0)
	var tamanho := Vector2(164.0, 114.0)
	var g := _grupo(Rect2(origem, tamanho), 1.5)
	g.name = "CartaoStatus"
	_sombra(Rect2(Vector2.ZERO, tamanho), 0.22, g)
	_imagem("ui_papel", Rect2(Vector2.ZERO, tamanho), TextureRect.STRETCH_TILE, 0.0, g)
	_imagem("ui_selo", Rect2(6.0, 4.0, 28.0, 28.0), TextureRect.STRETCH_SCALE, 0.0, g)
	_imagem("ui_recorte", Rect2(110.0, 8.0, 26.0, 15.0), TextureRect.STRETCH_SCALE, 8.0, g)

	# Faixa de fita sob o nome: da leitura de etiqueta, e sobra pixel lateral.
	_imagem("ui_fita", Rect2(4.0, 34.0, 156.0, 28.0), TextureRect.STRETCH_SCALE, -1.0, g)
	_nome_jogador = _rotulo("", Rect2(4.0, 32.0, 156.0, 12.0), UiEstilo.RE7_SIZE_BODY, TINTA,
		HORIZONTAL_ALIGNMENT_CENTER, false, g)
	# Sobrenome composto (ex.: NASCIMENTO TEIXEIRA): mais altura + wrap.
	_sobrenome_jogador = _rotulo("", Rect2(4.0, 42.0, 156.0, 20.0), UiEstilo.RE7_SIZE_BODY,
		TINTA, HORIZONTAL_ALIGNMENT_CENTER, true, g)
	_rotulo("STATUS:", Rect2(4.0, 64.0, 156.0, 12.0), UiEstilo.RE7_SIZE_MICRO, TINTA_FRACA,
		HORIZONTAL_ALIGNMENT_CENTER, false, g)

	# Estado verde sobre fita marrom - unica cor viva do cartao, como na print.
	_imagem("ui_fita_marrom", Rect2(16.0, 78.0, 132.0, 26.0),
		TextureRect.STRETCH_SCALE, -2.0, g)
	_estado = _rotulo("BEM", Rect2(16.0, 78.0, 132.0, 26.0), UiEstilo.RE7_SIZE_TITLE,
		Color("a6f07a"), HORIZONTAL_ALIGNMENT_CENTER, false, g, 600)
	_estado.add_theme_color_override(&"font_outline_color", Color(0.09, 0.06, 0.03))
	_estado.add_theme_constant_override(&"outline_size", 3)


## Colada torta, com fita em cima e embaixo. Reta ela vira retrato de documento;
## torta ela vira uma foto que alguem prendeu ali.
func _montar_polaroid() -> void:
	var origem := Vector2(366.0, 120.0)
	var tamanho := Vector2(100.0, 116.0)
	var g := _grupo(Rect2(origem, tamanho), 1.2)
	g.name = "Polaroid"

	# Fundo de madeira da polaroid fica atras; o Corpo vivo cobre o miolo.
	_imagem("ui_retrato", Rect2(8.0, 16.0, 78.0, 72.0), TextureRect.STRETCH_SCALE, 0.0, g)

	_montar_retrato_vivo()

	_foto = TextureRect.new()
	_foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_foto.stretch_mode = TextureRect.STRETCH_SCALE
	_foto.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foto.texture = _retrato_vp.get_texture()
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
	_aba_usar = _imagem("ui_aba", Rect2(20.0, 248.0, 62.0, 16.0),
		TextureRect.STRETCH_SCALE, -2.0)
	_lbl_usar = _rotulo("USAR", Rect2(20.0, 246.0, 62.0, 18.0), UiEstilo.RE7_SIZE_TITLE, TINTA_USAR,
		HORIZONTAL_ALIGNMENT_CENTER, false, null, 500)

	_aba_examinar = _imagem("ui_aba", Rect2(88.0, 248.0, 70.0, 16.0),
		TextureRect.STRETCH_SCALE, 1.5)
	_lbl_examinar = _rotulo("EXAMINAR", Rect2(88.0, 246.0, 70.0, 18.0), UiEstilo.RE7_SIZE_TITLE, TINTA,
		HORIZONTAL_ALIGNMENT_CENTER, false, null, 500)

	var dica := _rotulo("[A/D] item  [E][Q]  [W] sistema  [ESC] fechar",
		Rect2(168.0, 248.0, 300.0, 12.0), UiEstilo.RE7_SIZE_MICRO, Color(0.94, 0.9, 0.8),
		HORIZONTAL_ALIGNMENT_RIGHT)
	dica.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.8))
	dica.add_theme_constant_override(&"outline_size", 4)


# --- vitrine 3D do item selecionado ----------------------------------------

## SubViewport proprio (como em criacao.gd): o item selecionado gira de verdade
## num turntable, em vez de so receber uma moldura 2D.

func _montar_onda3_wire() -> void:
	## Wire Onda 3 (GO PO1): BEM/status → VitalsMonitor; EXAMINAR → ItemInspectViewport.
	## Preserva scrapbook, fonte_re7 e overlay. Sem cutover grid.
	if _estado != null:
		_estado.visible = false
	# Polaroid miolo (foto): vitals diegéticos no lugar do status/BEM.
	if _foto != null:
		_foto.visible = false
	var vitals_rect := Rect2(374.0, 136.0, 78.0, 72.0)
	_vitals = Re7Onda3Wire.mount_vitals(_raiz, vitals_rect)
	if _vitals != null:
		_vitals.z_index = 6
		_vitals.scale = Vector2(1.15, 1.15)
	# Inspect overlay (só no examine).
	var inspect_rect := Rect2(170.0, 55.0, 140.0, 150.0)
	_inspect = Re7Onda3Wire.mount_inspect(_raiz, inspect_rect)
	if _inspect != null:
		_inspect.visible = false
		_inspect.z_index = 25
		_inspect.mouse_filter = Control.MOUSE_FILTER_STOP


func _montar_vitrine() -> void:
	_vitrine = SubViewport.new()
	_vitrine.size = Vector2i(128, 128)
	_vitrine.own_world_3d = true
	_vitrine.transparent_bg = true
	_vitrine.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vitrine.msaa_3d = Viewport.MSAA_2X
	_vitrine.handle_input_locally = false
	add_child(_vitrine)

	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c8c0a8")
	env.ambient_light_energy = 0.95
	ambiente.environment = env
	_vitrine.add_child(ambiente)

	var luz := DirectionalLight3D.new()
	luz.light_energy = 1.7
	luz.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(38.0), 0.0)
	luz.shadow_enabled = false
	_vitrine.add_child(luz)

	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.4
	fill.light_color = Color("a8b8d0")
	fill.rotation = Vector3(deg_to_rad(-18.0), deg_to_rad(-55.0), 0.0)
	_vitrine.add_child(fill)

	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.near = 0.05
	camera.far = 20.0
	camera.position = Vector3(0.95, 0.75, 2.05)
	_vitrine.add_child(camera)
	camera.look_at(Vector3(0.0, 0.05, 0.0), Vector3.UP)
	camera.current = true

	_vitrine_root = Node3D.new()
	_giro = 0.6
	_vitrine_root.rotation.x = deg_to_rad(-18.0)
	_vitrine_root.rotation.y = _giro
	_vitrine.add_child(_vitrine_root)

	_vitrine_view = TextureRect.new()
	_vitrine_view.texture = _vitrine.get_texture()
	_vitrine_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vitrine_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_vitrine_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vitrine_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitrine_view.visible = false
	_raiz.add_child(_vitrine_view)
	_vitrine_view.size = Vector2(ICONE_VITRINE, ICONE_VITRINE)

	# Ordem: moldura atras da vitrine; etiquetas na frente.
	_selecao.z_index = 2
	_vitrine_view.z_index = 3


func _ligar_vitrine(ligada: bool) -> void:
	if _vitrine == null:
		return
	_vitrine.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if ligada else SubViewport.UPDATE_DISABLED)
	if _vitrine_view != null:
		_vitrine_view.visible = ligada


func _mostrar_vitrine(item_id: StringName, centro: Vector2) -> void:
	if item_id == &"":
		_ligar_vitrine(false)
		return
	if item_id != _vitrine_item_id:
		if _vitrine_item != null:
			_vitrine_root.remove_child(_vitrine_item)
			_vitrine_item.free()
			_vitrine_item = null
		_vitrine_item = ItemModelo.criar(item_id)
		_vitrine_root.add_child(_vitrine_item)
		_vitrine_item_id = item_id
		_giro = 0.6
	_vitrine_view.position = centro - Vector2(ICONE_VITRINE, ICONE_VITRINE) * 0.5
	_ligar_vitrine(true)


# --- polaroid viva / olhar pro cursor --------------------------------------

## Mesmo padrao de criacao.gd: mundo proprio, luz de estudio, camera de busto.
func _montar_retrato_vivo() -> void:
	_retrato_vp = SubViewport.new()
	_retrato_vp.size = Vector2i(78, 72)
	_retrato_vp.own_world_3d = true
	_retrato_vp.transparent_bg = false
	_retrato_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_retrato_vp.msaa_3d = Viewport.MSAA_DISABLED
	_retrato_vp.handle_input_locally = false
	add_child(_retrato_vp)

	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	# Madeira fria da polaroid — perto do ui_retrato, sem tapar o bonequinho.
	env.background_color = Color("5a5044")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9a9488")
	env.ambient_light_energy = 1.1
	ambiente.environment = env
	_retrato_vp.add_child(ambiente)

	var luz := DirectionalLight3D.new()
	luz.light_energy = 1.4
	luz.rotation = Vector3(deg_to_rad(-28.0), deg_to_rad(32.0), 0.0)
	luz.shadow_enabled = false
	_retrato_vp.add_child(luz)

	var camera := Camera3D.new()
	camera.fov = 28.0
	camera.near = 0.05
	camera.position = Vector3(0.0, 1.08, 2.55)
	_retrato_vp.add_child(camera)
	camera.look_at(Vector3(0.0, 1.02, 0.0), Vector3.UP)
	camera.current = true


func _refazer_retrato(aparencia: Dictionary) -> void:
	if _retrato_vp == null:
		return
	if _retrato_corpo != null:
		_retrato_corpo.queue_free()
		_retrato_corpo = null
	_retrato_corpo = Corpo.new()
	_retrato_vp.add_child(_retrato_corpo)
	_retrato_corpo.montar(aparencia)
	# Frente para a camera (+Z): o Corpo aponta -Z por padrao.
	_retrato_corpo.rotation.y = PI
	_retrato_corpo.animar(0.0, 0.016)


func _ligar_retrato(ligada: bool) -> void:
	if _retrato_vp == null:
		return
	_retrato_vp.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if ligada else SubViewport.UPDATE_DISABLED)


## Cabeca e torso seguem o cursor. Quantizado via Corpo.olhar_lateral — continuo
## demais leria como camera de vigilancia.
func _atualizar_olhar() -> void:
	if _retrato_corpo == null or _foto == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var centro := _foto.get_global_rect().get_center()
	var delta := mouse - centro
	var yaw := clampf(delta.x / 95.0, -1.0, 1.0)
	var pitch := clampf(-delta.y / 85.0, -0.55, 0.55)
	# olhar_lateral relativo ao frente; soma ao PI da polaroid.
	_retrato_corpo.olhar_lateral(-yaw * 0.95)
	_retrato_corpo.rotation.y = PI + yaw * 0.22
	_retrato_corpo.rotation.x = pitch * 0.28


# --- abrir e fechar ---------------------------------------------------------

## O menu de sistema desta prancha, para quem precisa aciona-lo de fora — hoje
## so a captura automatizada.
func menu_sistema() -> MenuSistema:
	return _sistema


func alternar() -> void:
	if aberta:
		fechar()
	else:
		abrir()


## SPEC_A11Y_RE7 §3 — default = hit do slot _selecionado (ou 0).
## Path legado (cutover InventarioGridRE7 OFF / PO1 lock).
func foco_padrao() -> void:
	if _stick_gate != null:
		_stick_gate.reset()
	var idx := clampi(_selecionado, 0, maxi(_hits_slot.size() - 1, 0))
	if idx < _hits_slot.size() and is_instance_valid(_hits_slot[idx]):
		_hits_slot[idx].grab_focus()
		return
	if _raiz == null or not is_instance_valid(_raiz):
		return
	var c := _primeiro_focusavel_prancha(_raiz)
	if c != null:
		c.grab_focus()


func _primeiro_focusavel_prancha(n: Node) -> Control:
	if n is MenuSistema:
		return null
	if n is Control:
		var ctl := n as Control
		if ctl.focus_mode != Control.FOCUS_NONE and ctl.is_visible_in_tree():
			return ctl
	for ch in n.get_children():
		var f := _primeiro_focusavel_prancha(ch)
		if f != null:
			return f
	return null


func _wire_slot_hits_neighbors() -> void:
	var n := _hits_slot.size()
	for i in n:
		var h := _hits_slot[i]
		var L: Control = _hits_slot[i - 1] if i > 0 else h
		var R: Control = _hits_slot[i + 1] if i < n - 1 else h
		h.focus_neighbor_left = h.get_path_to(L)
		h.focus_neighbor_right = h.get_path_to(R)
		h.focus_neighbor_top = h.get_path_to(h)
		h.focus_neighbor_bottom = h.get_path_to(h)


func _ao_slot_hover(idx: int) -> void:
	if not aberta:
		return
	if _sistema != null and _sistema.aberto:
		return
	if idx == _selecionado:
		return
	_selecionado = idx
	_examinando = false
	_atualizar()


func _ao_slot_input(evento: InputEvent, idx: int) -> void:
	if not aberta:
		return
	if _sistema != null and _sistema.aberto:
		return
	if evento is InputEventMouseButton:
		var mb := evento as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_selecionado = idx
			_examinando = false
			AudioDirector.tocar_nav(-18.0)
			_atualizar()
			if idx < _hits_slot.size() and is_instance_valid(_hits_slot[idx]):
				_hits_slot[idx].grab_focus()
			get_viewport().set_input_as_handled()


func abrir() -> void:
	if aberta:
		return
	aberta = true
	_examinando = false
	_raiz.visible = true
	# Pausa a arvore, nao um "modo menu": inimigo andando enquanto o jogador le
	# a descricao de uma bandagem e injusto e ninguem espera isso.
	get_tree().paused = true
	# Onda 1 RE7: overlay + pilha UIManager (pausa desta prancha; RE7_OVERLAY flag).
	UIManager.push_menu(self, false, &"inventario")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioDirector.tocar_confirm(-14.0)
	_giro = 0.0
	if _sistema != null:
		_sistema.mostrar_aba(true)
	_ligar_retrato(true)
	_atualizar()
	_animar_entrada()


func fechar() -> void:
	if not aberta:
		return
	aberta = false
	if _sistema != null:
		_sistema.fechar(false)
		_sistema.mostrar_aba(false)
	_ligar_vitrine(false)
	_ligar_retrato(false)
	if _inspect != null:
		_inspect.visible = false
		if _inspect.has_method("exit"):
			_inspect.call("exit")
	_examinando = false
	_raiz.visible = false
	# Onda 1 RE7: tira da pilha / desliga overlay (raiz nao e reparentada).
	UIManager.remove_menu(self)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# P0 D: sem clique/bipe no path RE7 (close silencioso; duck via UIManager.pop)
	fechou.emit()


## A prancha entra caindo um pouco, como papel largado na mesa. Curta de
## proposito: mais que 0,15 s vira transicao de menu e o jogador passa a esperar
## a animacao acabar toda vez que abre a bolsa.
func _animar_entrada() -> void:
	# Painel raiz: T_RE7_OPEN EXPO out + slide 6 px (SPEC_MOTION_RE7 §3).
	# Input nao espera — tween visual so.
	_raiz.position = Vector2(0.0, -6.0)
	_raiz.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var t := create_tween().set_parallel(true)
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	t.tween_property(_raiz, "position", Vector2.ZERO, UiEstilo.T_RE7_OPEN)
	t.tween_property(_raiz, "modulate", Color.WHITE, UiEstilo.T_RE7_OPEN)


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

	# O menu de sistema fica na frente: com ele aberto, a prancha nao recebe
	# nada. Ele responde se consumiu, e so o que sobrar continua sendo da bolsa.
	if _sistema != null and _sistema.tratar(evento):
		_atualizar()
		get_viewport().set_input_as_handled()
		return

	# Stick esquerdo menu: 1 passo (deadzone≥0.5). Right stick nao move inventário.
	if evento is InputEventJoypadMotion:
		var st: Vector2i = _stick_gate.poll()
		if st.x != 0:
			_mover(st.x)
		elif st.y < 0 and _sistema != null:
			_sistema.abrir()
		get_viewport().set_input_as_handled()
		return

	if evento.is_action_pressed("mover_dir"):
		_mover(1)
	elif evento.is_action_pressed("mover_esq"):
		_mover(-1)
	elif evento.is_action_pressed("interagir"):
		_usar()
	elif evento.is_action_pressed("examinar"):
		_examinar()
	elif evento.is_action_pressed("mover_frente"):
		# Subir sai da faixa de itens e chega nos pauzinhos do canto. Nao e tecla
		# nova para decorar: e a mesma direcao que ja move em tudo.
		_sistema.abrir()
	get_viewport().set_input_as_handled()


func _mover(passo: int) -> void:
	_selecionado = posmod(_selecionado + passo, SLOTS)
	_examinando = false
	AudioDirector.tocar_nav(-18.0)
	if _selecionado < _hits_slot.size() and is_instance_valid(_hits_slot[_selecionado]):
		if not _hits_slot[_selecionado].has_focus():
			_hits_slot[_selecionado].grab_focus()
	_atualizar()
	## P0 F: sem TRANS_BACK; scale ≤±4%; T_RE7_FOCUS sine-out
	_selecao.scale = Vector2(1.04, 1.04)
	create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE) \
		.tween_property(_selecao, "scale", Vector2.ONE, UiEstilo.T_RE7_FOCUS)


func _usar() -> void:
	_piscar(_aba_usar)
	if _lbl_usar != null:
		_lbl_usar.add_theme_color_override(&"font_color", Color("a05030"))
		create_tween().tween_callback(func() -> void:
			_lbl_usar.add_theme_color_override(&"font_color", TINTA_USAR))
	if Inventario.usar(_selecionado):
		AudioDirector.tocar_confirm(-14.0)
	else:
		AudioDirector.tocar_nav(-18.0)


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
	AudioDirector.tocar_confirm(-14.0)
	_sincronizar_inspect()
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



func _sincronizar_inspect() -> void:
	if _inspect == null:
		return
	if not _examinando:
		_inspect.visible = false
		if _inspect.has_method("exit"):
			_inspect.call("exit")
		return
	var sel: Dictionary = Inventario.espacos[_selecionado]
	if sel.is_empty():
		_inspect.visible = false
		if _inspect.has_method("exit"):
			_inspect.call("exit")
		return
	var item: Item = sel["item"]
	_ligar_vitrine(false)
	_inspect.visible = true
	if _inspect.has_method("enter"):
		_inspect.call("enter")
	if _inspect.has_method("set_item"):
		_inspect.call("set_item", item.id)


func _atualizar() -> void:
	var passo := (FAIXA.size.x - PONTA * 2.0) / float(SLOTS)

	for i in SLOTS:
		var e: Dictionary = Inventario.espacos[i]
		if e.is_empty():
			_icones[i].texture = null
			_icones[i].visible = true
			_sombras[i].visible = false
			_contagens[i].text = ""
			_etiquetas[i].visible = false
			_pinos[i].visible = false
			continue
		var item: Item = e["item"]
		_icones[i].texture = item.icone
		# O selecionado some do 2D: a vitrine 3D ocupa o lugar.
		_icones[i].visible = i != _selecionado
		_sombras[i].visible = i != _selecionado
		var qtd := int(e["qtd"])
		# Na referencia o pedaco de papel aparece em quase todo objeto.
		_etiquetas[i].visible = true
		_pinos[i].visible = true
		_contagens[i].text = str(qtd)
		_etiquetas[i].z_index = 4
		_pinos[i].z_index = 5
		_contagens[i].z_index = 5

	var cx := FAIXA.position.x + PONTA + passo * (float(_selecionado) + 0.5)
	var cy := FAIXA.position.y + FAIXA.size.y * 0.5
	_selecao.pivot_offset = _selecao.size * 0.5
	_selecao.position = Vector2(cx - _selecao.size.x * 0.5, cy - _selecao.size.y * 0.5)

	var sel: Dictionary = Inventario.espacos[_selecionado]
	if sel.is_empty():
		_ligar_vitrine(false)
		if _inspect != null and _inspect.visible:
			_inspect.visible = false
			if _inspect.has_method("exit"):
				_inspect.call("exit")
		_titulo.text = ""
		_sublinhado.visible = false
		_descricao.text = "Nada aqui."
	else:
		var item: Item = sel["item"]
		if _examinando:
			_ligar_vitrine(false)
			_sincronizar_inspect()
		else:
			if _inspect != null and _inspect.visible:
				_inspect.visible = false
				if _inspect.has_method("exit"):
					_inspect.call("exit")
			_mostrar_vitrine(item.id, Vector2(cx, cy))
		_titulo.text = item.nome.to_upper()
		_sublinhado.visible = true
		_descricao.text = ("%s\nQuantidade: %d" % [item.rotulo_tipo(), int(sel["qtd"])]) \
			if _examinando else item.descricao

	# Status: VitalsMonitor (Onda 3). Label BEM fica oculto.
	if _vitals != null and _vitals.has_method("refresh"):
		_vitals.call("refresh")
	elif _estado != null and _estado.visible:
		_estado.text = Inventario.estado()
		_estado.add_theme_color_override(&"font_color", Inventario.cor_do_estado())


func _process(delta: float) -> void:
	if not aberta:
		return
	if _vitrine_root != null and _vitrine_view != null and _vitrine_view.visible:
		# Turntable continuo: o item selecionado gira no eixo Y.
		_giro += delta * 2.4
		_vitrine_root.rotation.y = _giro
	if _retrato_corpo != null:
		_atualizar_olhar()
		_retrato_corpo.animar(0.0, delta)
