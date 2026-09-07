## O papelzinho no canto que diz o que fazer agora.
##
## Por que e papel, e nao texto solto na tela
## ------------------------------------------
## Porque tudo que e interface neste jogo e papel: o inventario e uma prancha de
## recortes, o mapa do pause e uma pagina, o cartao do canto tem fita adesiva na
## quina. Um retangulo preto translucido com texto branco — que e o que a maioria
## dos jogos poe aqui — seria a unica coisa da tela que veio de outra decada.
##
## Entao o objetivo e um pedaco de papel colado no canto de cima da esquerda, do
## lado oposto ao minimapa, com fita na quina. Custa uma textura que ja existe.
##
## Por que ele some sozinho
## ------------------------
## Porque objetivo lido vira ruido. O cartao aparece quando a etapa muda, fica
## na tela o tempo de ser lido duas vezes e depois encolhe para uma tira so com
## a linha do objetivo — a dica de tecla sai. Quem esqueceu abre o GPS, que e
## onde o alfinete verde continua.
class_name HudMissao
extends CanvasLayer

const TELA := Vector2(480.0, 270.0)
const UI := "res://assets/ui/%s.png"
const FONTE_P := "res://assets/fontes/psx_pequena.fnt"

## Canto de cima da esquerda. O minimapa mora na direita, e as duas coisas nao
## podem disputar o mesmo olho.
const MARGEM := Vector2(7.0, 7.0)
const LARGURA := 186.0

## Alturas do cartao aberto e da tira. A diferenca e a linha da dica de tecla,
## que so existe enquanto a etapa e nova.
const ALTURA_ABERTO := 46.0
const ALTURA_TIRA := 30.0

## Quanto tempo o cartao fica aberto antes de encolher. Doze segundos sao duas
## leituras tranquilas de uma linha de sete palavras.
const ESPERA := 12.0

const TINTA := Color("2a1f16")
const TINTA_FRACA := Color("6a5a44")
const TINTA_TITULO := Color("7a3a22")

var _raiz: Control
var _papel: TextureRect
var _fita: TextureRect
var _titulo: Label
var _objetivo: Label
var _dica: Label
var _distancia: Label
var _encolher: SceneTreeTimer
var _alvo: Node3D


func _ready() -> void:
	layer = 101
	# Mesmo grupo do minimapa: cena cortada esconde os dois de uma vez.
	add_to_group(&"hud")
	_montar()
	Missoes.iniciou.connect(_ao_mudar)
	Missoes.avancou.connect(_ao_mudar)
	Missoes.concluiu.connect(_ao_concluir)
	Interiores.entrou.connect(_ao_entrar_em_comodo)
	Interiores.saiu.connect(_ao_sair_de_comodo)
	_raiz.visible = false
	set_process(false)


func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "CartaoMissao"
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Sombra dois pixels abaixo e a direita, como a do cartao do minimapa. E o
	# que descola o papel do fundo sem precisar de moldura grossa.
	var sombra := ColorRect.new()
	sombra.color = Color(0.05, 0.04, 0.03, 0.45)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(sombra)
	sombra.position = MARGEM + Vector2(2.0, 2.0)
	sombra.size = Vector2(LARGURA, ALTURA_ABERTO)

	_papel = TextureRect.new()
	_papel.name = "Papel"
	var caminho := UI % "ui_papel"
	if ResourceLoader.exists(caminho):
		_papel.texture = load(caminho)
	_papel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_papel.stretch_mode = TextureRect.STRETCH_SCALE
	_papel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_papel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_papel)
	_papel.position = MARGEM
	_papel.size = Vector2(LARGURA, ALTURA_ABERTO)
	# A sombra acompanha o papel quando ele encolhe.
	_papel.item_rect_changed.connect(func() -> void:
		sombra.size = _papel.size)

	_fita = TextureRect.new()
	_fita.name = "Fita"
	var fita_tex := UI % "ui_fita"
	if ResourceLoader.exists(fita_tex):
		_fita.texture = load(fita_tex)
	_fita.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fita.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fita.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_fita)
	_fita.position = MARGEM + Vector2(-6.0, -4.0)
	_fita.size = Vector2(34.0, 11.0)
	_fita.pivot_offset = Vector2(17.0, 5.5)
	# Torta para o lado contrario da fita do minimapa. Duas fitas com a mesma
	# inclinacao nos dois cantos leem como moldura, e nao como colagem.
	_fita.rotation = deg_to_rad(6.0)

	_titulo = _rotulo(Vector2(6.0, 3.0), LARGURA - 12.0, TINTA_TITULO)
	_objetivo = _rotulo(Vector2(6.0, 13.0), LARGURA - 12.0, TINTA)
	_objetivo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objetivo.size.y = 20.0
	_dica = _rotulo(Vector2(6.0, 33.0), LARGURA - 12.0, TINTA_FRACA)
	_distancia = _rotulo(Vector2(6.0, 3.0), LARGURA - 12.0, TINTA_FRACA)
	_distancia.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _rotulo(onde: Vector2, largura: float, cor: Color) -> Label:
	var l := Label.new()
	l.add_theme_color_override(&"font_color", cor)
	if ResourceLoader.exists(FONTE_P):
		l.add_theme_font_override(&"font", load(FONTE_P))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(l)
	# Posicao e tamanho depois de entrar na arvore: definidos antes, sao
	# recalculados na entrada e o rotulo sai do lugar.
	l.position = MARGEM + onde
	l.size = Vector2(largura, 10.0)
	return l


# --- estado -----------------------------------------------------------------

func _ao_mudar(missao: Dictionary) -> void:
	var etapa := Missoes.etapa_atual()
	if etapa.is_empty():
		return
	_titulo.text = String(missao["titulo"])
	_objetivo.text = String(etapa.get("texto", ""))
	_dica.text = String(etapa.get("dica", ""))
	_abrir()


## O cartao entra encostado na borda e desliza para dentro.
##
## Entrar deslizando e nao piscando: o objetivo muda no meio da rua, com o
## jogador andando, e uma coisa que aparece do nada no canto do olho le como
## falha de desenho. Vindo de fora da tela, le como alguem colando um papel.
func _abrir() -> void:
	_raiz.visible = true
	set_process(true)
	_papel.size.y = ALTURA_ABERTO
	_dica.visible = not _dica.text.is_empty()
	AudioDirector.tocar_ui(&"papel", -16.0)

	_raiz.position.x = -LARGURA - MARGEM.x
	_raiz.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_raiz, "position:x", 0.0, 0.34)
	t.tween_property(_raiz, "modulate:a", 1.0, 0.2)

	if _encolher != null and is_instance_valid(_encolher):
		# Etapa nova antes de a anterior encolher: o relogio velho nao pode
		# encolher o cartao novo dois segundos depois de ele abrir.
		_encolher.timeout.disconnect(_ao_encolher)
	_encolher = get_tree().create_timer(ESPERA)
	_encolher.timeout.connect(_ao_encolher)


func _ao_encolher() -> void:
	if not _raiz.visible:
		return
	_dica.visible = false
	var t := create_tween()
	t.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(_papel, "size:y", ALTURA_TIRA, 0.28)


func _ao_concluir(_missao: Dictionary) -> void:
	_titulo.text = ""
	_objetivo.text = "OBJETIVO CUMPRIDO"
	_dica.text = ""
	_dica.visible = false
	_distancia.text = ""
	_papel.size.y = ALTURA_TIRA
	var t := create_tween()
	t.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	t.tween_interval(2.4)
	t.tween_property(_raiz, "modulate:a", 0.0, 0.4)
	t.tween_callback(func() -> void:
		_raiz.visible = false
		set_process(false))


## Dentro de casa o cartao sai da tela, como o minimapa. La ele nao teria o que
## dizer: a distancia ate um endereco de rua nao existe a dois mil metros de
## altura, dentro de um comodo sem coordenada.
func _ao_entrar_em_comodo() -> void:
	_raiz.visible = false


func _ao_sair_de_comodo() -> void:
	_raiz.visible = not Missoes.atual.is_empty()


# --- distancia --------------------------------------------------------------

func _process(_delta: float) -> void:
	if not _raiz.visible or Missoes.atual.is_empty():
		return
	var alvo := Missoes.posicao_do_alvo()
	if alvo == Vector3.INF:
		_distancia.text = ""
		return
	if _alvo == null or not is_instance_valid(_alvo):
		_alvo = get_tree().get_first_node_in_group(&"player") as Node3D
		if _alvo == null:
			return
	var pos := _alvo.global_position
	var d := Vector2(alvo.x - pos.x, alvo.z - pos.z).length()
	_distancia.text = "%d M" % roundi(d) if d < 1000.0 else "%.1f KM" % (d / 1000.0)
