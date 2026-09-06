## Prancha de inventario. Cortica, recorte de papel, fita e alfinete.
##
## Nao e uma HUD com caixas: e um objeto do mundo do personagem, que e o que a
## referencia faz. A diferenca importa porque a prancha e onde o jogador para,
## respira e decide, e um painel de sistema quebraria esse momento.
##
## Montada por codigo, nao por cena. Numa tela de 480x270 cada pixel de posicao
## conta, e calcular o espacamento e mais confiavel que arrastar no editor.
class_name PranchaInventario
extends CanvasLayer

const UI := "res://assets/ui/%s.png"
const FONTE_P := "res://assets/fontes/psx_pequena.fnt"
const FONTE_M := "res://assets/fontes/psx_media.fnt"
const FONTE_T := "res://assets/fontes/psx_titulo.fnt"

const TELA := Vector2(480.0, 270.0)
const SLOTS := 8
const SLOT := 44.0
const FAIXA_Y := 24.0

const TINTA := Color("2a1f16")
const TINTA_FRACA := Color("5a4a38")
const PAPEL_CLARO := Color("efe7d2")

signal fechou()

var aberta: bool = false
var _selecionado: int = 0

var _raiz: Control
var _molduras: Array[TextureRect] = []
var _etiquetas: Array[TextureRect] = []
var _icones: Array[TextureRect] = []
var _contagens: Array[Label] = []
var _titulo: Label
var _descricao: Label
var _estado: Label
var _dica: Label


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	_raiz.visible = false
	Inventario.mudou.connect(_atualizar)


func _tex(nome: String) -> Texture2D:
	var caminho := UI % nome
	if not ResourceLoader.exists(caminho):
		push_error("PranchaInventario: textura ausente %s" % caminho)
		return null
	return load(caminho)


func _fonte(caminho: String) -> Font:
	return load(caminho) if ResourceLoader.exists(caminho) else null


func _rotulo(texto: String, pos: Vector2, tamanho: Vector2, fonte: String,
		cor: Color, alinhamento: int = HORIZONTAL_ALIGNMENT_LEFT,
		quebra: bool = true) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_color_override(&"font_color", cor)
	l.horizontal_alignment = alinhamento
	var f := _fonte(fonte)
	if f != null:
		l.add_theme_font_override(&"font", f)
	# Nome curto nao quebra: "KAORI ITO" virando duas linhas empurra o resto da
	# ficha e o "ITO" some no recorte.
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if quebra else TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(l)
	l.position = pos
	l.size = tamanho
	return l


## TextureRect com tamanho explicito precisa de expand_mode: sem ele o no
## desenha no tamanho da textura e ignora o layout. Foi o que fez oito etiquetas
## de 22 px virarem uma faixa clara atravessando a prancha inteira.
func _imagem(nome: String, pos: Vector2, tamanho: Vector2,
		estica: int = TextureRect.STRETCH_SCALE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _tex(nome)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = estica
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Tamanho depois de entrar na arvore: Control recalcula o retangulo na
	# entrada, e o que foi definido antes e simplesmente descartado.
	_raiz.add_child(t)
	t.position = pos
	t.size = tamanho
	t.custom_minimum_size = tamanho
	return t


func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "Prancha"
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	# Fundo de cortica, repetido. Esticar uma textura de 128 px para 480 borra
	# o grao e a cortica vira papel de parede.
	_imagem("ui_cortica", Vector2.ZERO, TELA, TextureRect.STRETCH_TILE)

	_montar_faixa()
	_montar_painel()
	_montar_ficha()

	_dica = _rotulo("[TAB] fechar    [A/D] mover    [E] usar",
		Vector2(0.0, TELA.y - 20.0), Vector2(TELA.x, 16.0), FONTE_P,
		Color(0.82, 0.76, 0.62), HORIZONTAL_ALIGNMENT_CENTER)

	_imagem("ui_vinheta", Vector2.ZERO, TELA)


## Faixa de feltro com os slots, presos por alfinete.
func _montar_faixa() -> void:
	var vao := (TELA.x - 28.0 - SLOTS * SLOT) / float(SLOTS + 1)

	_imagem("ui_feltro", Vector2(14.0, FAIXA_Y - 6.0),
		Vector2(TELA.x - 28.0, SLOT + 12.0), TextureRect.STRETCH_TILE)

	for i in SLOTS:
		var x := 14.0 + vao + float(i) * (SLOT + vao)

		var icone := TextureRect.new()
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_raiz.add_child(icone)
		icone.position = Vector2(x + 5.0, FAIXA_Y + 5.0)
		icone.size = Vector2(SLOT - 10.0, SLOT - 10.0)
		_icones.append(icone)

		# Moldura de selecao. Um recorte de papel por cima em vez de um retangulo
		# desenhado: a prancha inteira e feita de coisa colada.
		var moldura := _imagem("ui_alfinete",
			Vector2(x + SLOT * 0.5 - 8.0, FAIXA_Y - 13.0), Vector2(16.0, 16.0))
		moldura.visible = false
		_molduras.append(moldura)

		# Etiqueta de contagem presa no canto do slot, como na referencia.
		var etiqueta := _imagem("ui_recorte",
			Vector2(x + SLOT - 20.0, FAIXA_Y + SLOT - 6.0), Vector2(22.0, 13.0))
		_etiquetas.append(etiqueta)

		var contagem := _rotulo("", Vector2(x + SLOT - 20.0, FAIXA_Y + SLOT - 7.0),
			Vector2(22.0, 13.0), FONTE_P, TINTA, HORIZONTAL_ALIGNMENT_CENTER, false)
		_contagens.append(contagem)


## Recorte de papel com nome e descricao do item selecionado.
func _montar_painel() -> void:
	_imagem("ui_papel", Vector2(18.0, 98.0), Vector2(250.0, 122.0),
		TextureRect.STRETCH_TILE)
	var fita := _imagem("ui_fita", Vector2(26.0, 90.0), Vector2(64.0, 18.0))
	fita.pivot_offset = Vector2(32.0, 9.0)
	fita.rotation = deg_to_rad(-4.0)

	_titulo = _rotulo("", Vector2(32.0, 106.0), Vector2(224.0, 26.0), FONTE_T, TINTA)
	_descricao = _rotulo("", Vector2(32.0, 138.0), Vector2(224.0, 78.0), FONTE_M, TINTA_FRACA)


## Ficha do personagem: polaroid e estado, como na referencia.
func _montar_ficha() -> void:
	_imagem("ui_papel", Vector2(286.0, 98.0), Vector2(176.0, 122.0),
		TextureRect.STRETCH_TILE)

	# Polaroid a esquerda, texto a direita. Antes o nome caia por cima da foto.
	_imagem("ui_retrato", Vector2(298.0, 110.0), Vector2(68.0, 62.0))
	_imagem("ui_polaroid", Vector2(294.0, 106.0), Vector2(76.0, 86.0))

	var fita2 := _imagem("ui_fita", Vector2(294.0, 100.0), Vector2(50.0, 15.0))
	fita2.pivot_offset = Vector2(25.0, 7.0)
	fita2.rotation = deg_to_rad(6.0)

	_rotulo("KAORI ITO", Vector2(376.0, 110.0), Vector2(84.0, 16.0), FONTE_P,
		TINTA, HORIZONTAL_ALIGNMENT_LEFT, false)
	_rotulo("ESTADO", Vector2(376.0, 140.0), Vector2(84.0, 14.0), FONTE_P,
		TINTA_FRACA, HORIZONTAL_ALIGNMENT_LEFT, false)
	_estado = _rotulo("BEM", Vector2(376.0, 156.0), Vector2(84.0, 20.0), FONTE_M,
		TINTA, HORIZONTAL_ALIGNMENT_LEFT, false)


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
	_raiz.visible = true
	# Pausa a arvore, nao um "modo menu": inimigo andando enquanto o jogador le
	# a descricao de uma bandagem e injusto e ninguem espera isso.
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioDirector.tocar_ui(&"pegar", -10.0)
	_atualizar()


func fechar() -> void:
	if not aberta:
		return
	aberta = false
	_raiz.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	AudioDirector.tocar_ui(&"clique", -8.0)
	fechou.emit()


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
		if Inventario.usar(_selecionado):
			AudioDirector.tocar_ui(&"pegar", -6.0)
		else:
			AudioDirector.tocar_ui(&"clique", -12.0)
	get_viewport().set_input_as_handled()


func _mover(passo: int) -> void:
	_selecionado = posmod(_selecionado + passo, SLOTS)
	AudioDirector.tocar_ui(&"clique", -14.0)
	_atualizar()


func _atualizar() -> void:
	for i in SLOTS:
		var e: Dictionary = Inventario.espacos[i]
		_molduras[i].visible = i == _selecionado
		if e.is_empty():
			_icones[i].texture = null
			_contagens[i].text = ""
			_etiquetas[i].visible = false
			continue
		var item: Item = e["item"]
		_icones[i].texture = item.icone
		var qtd := int(e["qtd"])
		_contagens[i].text = str(qtd) if qtd > 1 else ""
		_etiquetas[i].visible = qtd > 1

	var sel: Dictionary = Inventario.espacos[_selecionado]
	if sel.is_empty():
		_titulo.text = ""
		_descricao.text = "Nada aqui."
	else:
		var item: Item = sel["item"]
		_titulo.text = item.nome.to_upper()
		_descricao.text = item.descricao

	_estado.text = Inventario.estado()
	_estado.add_theme_color_override(&"font_color", Inventario.cor_do_estado())
