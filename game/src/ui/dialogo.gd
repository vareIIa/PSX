## Autoload. Caixa de fala.
##
## Sem retrato, sem escolha, sem barra de nome flutuando: papel colado embaixo da
## tela com o nome numa fita, do mesmo vocabulario da prancha de inventario. A
## interface inteira do jogo finge ser objeto de papel, e abrir uma excecao aqui
## quebraria a unica regra visual que o jogo tem.
##
## Vai na camada 120, abaixo do pos-processamento em 150, entao a caixa recebe o
## mesmo grao, dither e aberracao que o 3D. Interface limpa por cima de imagem
## suja entrega na hora que sao duas camadas diferentes.
##
## Nao pausa a arvore, ao contrario da prancha. O morador continua respirando e
## acompanhando o jogador com a cabeca enquanto fala, e essa e a metade do
## trabalho que faz ele parecer vivo. O jogador e travado no lugar em vez disso.
extends CanvasLayer

const UI := "res://assets/ui/%s.png"
const FONTE_M := "res://assets/fontes/psx_media.fnt"
const FONTE_P := "res://assets/fontes/psx_pequena.fnt"

const TELA := Vector2(480.0, 270.0)
## Baixo e largo. Uma caixa alta come um terco da tela e esconde justamente a
## pessoa que esta falando, que e a unica coisa que a cena tem para mostrar.
const PAINEL := Rect2(20.0, 198.0, 440.0, 56.0)
const TARJA := 14.0

## Letras por segundo. Rapido o bastante para nao irritar quem le rapido, devagar
## o bastante para a fala ter ritmo de fala.
const VELOCIDADE := 44.0

const TINTA := Color("2a1f16")

signal abriu()
signal fechou()

var ativo: bool = false

var _raiz: Control
var _texto: Label
var _nome: Label
var _seta: Polygon2D
var _tarja_topo: ColorRect
var _tarja_base: ColorRect

var _linhas: Array = []
## Quem fala (o morador), para a voz sair dele e o corpo gesticular. Opcional:
## sem falante, a linha anda pelo relogio antigo, com o estalo de maquina.
var _quem: Node3D
var _fala: Fala
var _indice: int = 0
var _revelado: float = 0.0
var _ultimo_bip: int = 0
var _piscar: float = 0.0


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	_raiz.visible = false
	set_process(false)
	# Sair de um interior fecha a conversa. Sem isso, uma saida disparada por
	# outro caminho deixaria a caixa aberta e o jogador travado, conversando com
	# alguem que ja foi liberado da memoria junto com a casa.
	Interiores.saiu.connect(func() -> void: _fechar())


# --- montagem ---------------------------------------------------------------

func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "Dialogo"
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)

	_tarja_topo = _tarja(0.0)
	_tarja_base = _tarja(TELA.y - TARJA)

	# Sombra: uma faixa escura meio pixel abaixo do papel. E o que separa a folha
	# do fundo; sem ela o painel flutua como retangulo de interface.
	var sombra := ColorRect.new()
	sombra.color = Color(0.05, 0.04, 0.03, 0.5)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(sombra)
	sombra.position = PAINEL.position + Vector2(2.0, 3.0)
	sombra.size = PAINEL.size

	var papel := TextureRect.new()
	papel.texture = _tex("ui_papel")
	papel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Ladrilhado, nao esticado. A textura tem 128 px e o painel tem 440 de
	# largura por 56 de altura: esticar aumenta o grao 3,4 vezes na horizontal e
	# esmaga na vertical, e o papel vira um retangulo liso.
	papel.stretch_mode = TextureRect.STRETCH_TILE
	papel.modulate = Color(0.88, 0.83, 0.71)
	_raiz.add_child(papel)
	papel.position = PAINEL.position
	papel.size = PAINEL.size

	# Fita nos dois cantos de cima, torta, como a folha foi colada ali as pressas.
	# E o mesmo vocabulario da prancha: tudo no jogo e papel preso com fita.
	for lado in 2:
		var fita_canto := TextureRect.new()
		fita_canto.texture = _tex("ui_fita")
		fita_canto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fita_canto.stretch_mode = TextureRect.STRETCH_SCALE
		fita_canto.rotation = deg_to_rad(-7.0 if lado == 0 else 5.0)
		fita_canto.modulate = Color(1.0, 1.0, 1.0, 0.85)
		_raiz.add_child(fita_canto)
		fita_canto.position = Vector2(200.0 if lado == 0 else 396.0,
			PAINEL.position.y - 6.0)
		fita_canto.size = Vector2(54.0, 15.0)

	# Fita com o nome, saindo por cima da borda de cima do papel. E o mesmo
	# recurso da prancha: a peca que atravessa a borda amarra as duas.
	var fita := TextureRect.new()
	fita.texture = _tex("ui_fita_marrom")
	fita.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fita.stretch_mode = TextureRect.STRETCH_SCALE
	fita.rotation = deg_to_rad(-1.5)
	_raiz.add_child(fita)
	fita.position = Vector2(30.0, 188.0)
	fita.size = Vector2(150.0, 21.0)

	_nome = _rotulo("", Rect2(36.0, 190.0, 142.0, 17.0), FONTE_P,
		Color(0.93, 0.9, 0.8))
	_nome.add_theme_color_override(&"font_outline_color", Color(0.08, 0.05, 0.03))
	_nome.add_theme_constant_override(&"outline_size", 3)

	_texto = _rotulo("", Rect2(PAINEL.position.x + 14.0, PAINEL.position.y + 13.0,
		PAINEL.size.x - 34.0, PAINEL.size.y - 20.0), FONTE_M, TINTA)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	# Seta de continuar. Triangulo desenhado, nao glifo: a fonte e um bitmap
	# gerado e nao tem garantia de trazer o caractere.
	_seta = Polygon2D.new()
	_seta.polygon = PackedVector2Array([Vector2(0, 0), Vector2(9, 0), Vector2(4.5, 6)])
	_seta.color = TINTA
	_raiz.add_child(_seta)
	_seta.position = Vector2(PAINEL.end.x - 24.0, PAINEL.end.y - 14.0)


func _tarja(y: float) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0, 0, 0, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(c)
	c.position = Vector2(0.0, y)
	c.size = Vector2(TELA.x, TARJA)
	return c


func _tex(nome: String) -> Texture2D:
	var caminho := UI % nome
	if not ResourceLoader.exists(caminho):
		push_warning("Dialogo: textura ausente %s" % caminho)
		return null
	return load(caminho) as Texture2D


func _rotulo(texto: String, r: Rect2, fonte: String, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_color_override(&"font_color", cor)
	if ResourceLoader.exists(fonte):
		l.add_theme_font_override(&"font", load(fonte))
	_raiz.add_child(l)
	# Posicao e tamanho depois de entrar na arvore: definidos antes, sao
	# recalculados na entrada e o rotulo sai do lugar.
	l.position = r.position
	l.size = r.size
	return l


# --- abrir e fechar ---------------------------------------------------------

## Abre a caixa com uma fala. `linhas` sao mostradas uma por vez.
func abrir(nome: String, linhas: Array, quem: Node3D = null, ficha: Dictionary = {}) -> void:
	if ativo or linhas.is_empty():
		return
	ativo = true
	_quem = quem
	if quem != null:
		if _fala == null:
			_fala = Fala.new()
			_fala.name = "Fala"
			add_child(_fala)
		_fala.voz = _voz_de(quem, ficha)
		var corpos: Array[Corpo] = []
		if quem.has_method("corpo"):
			var c := quem.call("corpo") as Corpo
			if c != null:
				corpos.append(c)
		_fala.corpos = corpos
		_fala.rosto = corpos[0].rosto if not corpos.is_empty() else null
		_fala.cadencia = float(Personalidade.de(int(ficha.get("personalidade", 0)))["cadencia"])
	_linhas = linhas
	_indice = 0
	_nome.text = nome
	_raiz.visible = true
	set_process(true)
	_travar_jogador(true)
	_mostrar_linha()
	_animar_entrada()
	abriu.emit()


## A voz do morador: a dele, se tiver, ou uma presa nele na altura da boca.
static func _voz_de(quem: Node3D, ficha: Dictionary) -> Voz:
	if quem.has_method("voz_da_fala"):
		return quem.call("voz_da_fala") as Voz
	var v := quem.get_node_or_null(^"VozDaConversa") as Voz
	if v == null:
		v = Voz.new()
		v.name = "VozDaConversa"
		quem.add_child(v)
		v.configurar(ficha)
		v.position = Vector3(0.0, 1.58, 0.0)
	return v


func _fechar() -> void:
	if not ativo:
		return
	ativo = false
	if _fala != null:
		_fala.pular()
	_quem = null
	_raiz.visible = false
	set_process(false)
	_travar_jogador(false)
	AudioDirector.tocar_ui(&"clique", -12.0)
	fechou.emit()


## Trava o jogador no lugar em vez de pausar a arvore. Pausar congelaria o
## morador no meio da propria fala.
func _travar_jogador(travado: bool) -> void:
	var jogador := get_tree().get_first_node_in_group(&"player")
	if jogador != null and jogador.has_method("travar"):
		jogador.call("travar", travado)


func _animar_entrada() -> void:
	_raiz.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_tarja_topo.position.y = -TARJA
	_tarja_base.position.y = TELA.y
	var t := create_tween().set_parallel(true)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_raiz, "modulate", Color.WHITE, 0.1)
	t.tween_property(_tarja_topo, "position:y", 0.0, 0.16)
	t.tween_property(_tarja_base, "position:y", TELA.y - TARJA, 0.16)


func _mostrar_linha() -> void:
	_texto.text = Fala.sem_marcas(String(_linhas[_indice]))
	_texto.visible_characters = 0
	_revelado = 0.0
	_ultimo_bip = 0
	if _quem != null and is_instance_valid(_quem) and _fala != null:
		_fala.dizer(String(_linhas[_indice]))


## A linha ja apareceu inteira?
##
## O -1 e o valor do motor para "mostra tudo", e nao um indice: compara-lo com o
## tamanho do texto da sempre menor, e foi assim que a conversa travou na
## primeira fala sem nunca fechar.
func _linha_completa() -> bool:
	return _texto.visible_characters < 0 or _texto.visible_characters >= _texto.text.length()


## Publica: a verificacao automatizada avanca a conversa sem simular tecla.
func avancar() -> void:
	# Primeiro toque completa a linha, segundo passa adiante. Sem isso quem le
	# rapido fica esperando a maquina de escrever terminar.
	if not _linha_completa():
		_revelado = float(_texto.text.length())
		_texto.visible_characters = -1
		if _fala != null:
			_fala.pular()
		return
	_indice += 1
	if _indice >= _linhas.size():
		_fechar()
		return
	AudioDirector.tocar_ui(&"clique", -18.0)
	_mostrar_linha()


# --- laco -------------------------------------------------------------------

func _process(delta: float) -> void:
	var total := _texto.text.length()
	if _texto.visible_characters >= 0 and _texto.visible_characters < total:
		var com_voz := _quem != null and _fala != null
		if com_voz:
			# Com falante, o texto anda pela silaba da voz.
			_revelado = float(_fala.revelado()) if _fala.falando() else float(total)
		else:
			_revelado += VELOCIDADE * delta
		var n := mini(int(_revelado), total)
		_texto.visible_characters = n
		# Um estalo a cada tres letras, bem baixo, so sem voz: com voz o estalo
		# e ruido por cima dela. Uma por letra vira metralhadora.
		if not com_voz and n - _ultimo_bip >= 3:
			_ultimo_bip = n
			AudioDirector.tocar_ui(&"clique", -28.0)
		if n >= total:
			_texto.visible_characters = -1

	# A seta so pisca quando a linha terminou, porque e ai que ela quer dizer
	# alguma coisa. Piscando o tempo todo vira enfeite.
	var pronta := _linha_completa()
	_piscar += delta
	_seta.visible = pronta and fmod(_piscar, 0.9) < 0.55


func _input(evento: InputEvent) -> void:
	if not ativo:
		return
	# _input roda antes de _unhandled_input, entao a caixa pega a tecla antes de
	# o jogador tentar interagir com o proximo objeto atras do morador.
	if evento.is_action_pressed("interagir") or evento.is_action_pressed("ui_accept"):
		avancar()
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("pausa"):
		_fechar()
		get_viewport().set_input_as_handled()
