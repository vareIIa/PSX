## Autoload. Fala roteirizada com escolha, para cena de missao.
##
## Por que nao e a Conversa nem o Dialogo
## --------------------------------------
## A Conversa puxa assunto de um desconhecido gerado pelo registro civil; o
## Dialogo e uma fila de falas sem escolha. Uma cena de missao precisa das duas
## coisas com texto escrito a mao, e precisa que a escolha volte para quem
## chamou (o roteiro) em vez de virar consequencia dentro da propria caixa.
##
## O visual e o mesmo papel colado do Dialogo. A lista de opcoes e a mesma
## gramatica da lista da Conversa (painel escuro, faixa ferrugem na escolhida),
## presa a direita, acima do papel.
##
## Uso, de dentro de uma funcao com await:
##
##     await Escolha.falar("BERG", ["Eu te vi na praca.", "No chao."], berg)
##     var r: StringName = await Escolha.perguntar("BERG", "Vai entrar ou nao?", [
##         {"chave": &"aceitar", "titulo": "Entrar no carro", "borboleta": &"m1_aceitou_carona_berg", "valor": true},
##         {"chave": &"recusar", "titulo": "Nao, valeu", "borboleta": &"m1_aceitou_carona_berg", "valor": false},
##     ], berg)
##
## Opcao: {chave: StringName, titulo: String, borboleta?: StringName, valor?: Variant}.
## Opcao com `borboleta` grava `Borboleta.marcar(borboleta, valor)` e mostra o
## olho. Sem `borboleta`, e so conversa.
##
## Funciona dentro e fora de cena cortada (autoload Cinema). Dentro, o papel
## sobe para cima da tarja de baixo e as tarjas proprias nao aparecem (ja ha as
## do cinema). Fora, trava o jogador e poe as tarjas finas, como o Dialogo.
##
## Duas falas seguidas nao piscam
## ------------------------------
## O roteiro escreve `falar`, `falar`, `perguntar` em sequencia, cada uma com o
## seu await. Se cada chamada fechasse a caixa no fim, o papel sumiria e
## voltaria entre uma e outra, duas vezes por conversa. Fechar espera um
## instante (`FECHA_DEPOIS`); se outra fala chega nesse meio tempo, o papel
## fica e so troca o nome e o texto.
extends CanvasLayer

const UI := "res://assets/ui/%s.png"
const FONTE_M := "res://assets/fontes/psx_media.fnt"
const FONTE_P := "res://assets/fontes/psx_pequena.fnt"

const TELA := Vector2(480.0, 270.0)
## O papel, fora de cena cortada: o mesmo lugar do Dialogo.
const PAINEL := Rect2(20.0, 198.0, 440.0, 56.0)
## Dentro da cena cortada a tarja de baixo come 33 px; o papel sobe para ficar
## inteiro acima dela, com 7 px de respiro.
const PAINEL_CINEMA := Rect2(20.0, 174.0, 440.0, 56.0)
const TARJA := 14.0
## Letras por segundo sem voz. O mesmo ritmo do Dialogo.
const VELOCIDADE := 44.0
const TINTA := Color("2a1f16")
const FECHA_DEPOIS := 0.18

## Lista: mesma medida da Conversa.
const MAX_OPCOES := 6
const PASSO_LINHA := 14.0
const LISTA_DIREITA := 458.0
const LISTA_LARGURA_MIN := 150.0
const LISTA_LARGURA_MAX := 260.0
const LISTA_CABECALHO := 17.0
const TAM_OPCAO := 9
const TAM_MICRO := 7
const COR_TITULO := UiEstilo.RE7_TEXT_TITLE
const COR_TEXTO := UiEstilo.RE7_TEXT_PRIMARY
const COR_FRACA := UiEstilo.RE7_TEXT_MUTED
const COR_ACENTO := UiEstilo.RE7_ACCENT
const COR_ACENTO_VIVO := UiEstilo.RE7_ACCENT_HOT
const COR_PAINEL := Color(0.047, 0.062, 0.066, 0.86)
const COR_BORDA := UiEstilo.RE7_PANEL_EDGE
const T_LISTA := 0.24

signal abriu()
signal fechou()
## Uma opcao foi escolhida. Emitido antes de `perguntar` retornar.
signal escolhido(chave: StringName)

## A linha da vez terminou e o jogador mandou seguir.
signal _seguiu()
## A linha da vez terminou de aparecer (a pergunta abre a lista sozinha).
signal _revelou()
signal _decidiu(chave: StringName)

var ativo: bool = false

var _raiz: Control
var _folha: Control
var _lista_ctl: Control
var _texto: Label
var _nome: Label
var _seta: Polygon2D
var _tarja_topo: ColorRect
var _tarja_base: ColorRect
var _f_opcao: Font
var _f_micro: Font

var _quem: Node3D
var _fala: Fala
var _revelado: float = 0.0
var _ultimo_bip: int = 0
var _piscar: float = 0.0
## Alguma chamada (`falar` ou `perguntar`) esta usando a caixa.
var _ocupado := false
var _fechar_em := -1.0
var _travou := false
var _escolhendo := false
var _opcoes: Array[Dictionary] = []
var _selecionado := 0
var _t_lista := 0.0
var _sel_y := -1.0
var _lista := Rect2()


func _ready() -> void:
	layer = 121
	process_mode = Node.PROCESS_MODE_ALWAYS
	_f_opcao = UiEstilo.fonte_re7(UiEstilo.RE7_WEIGHT_SEMIBOLD)
	var micro := FontVariation.new()
	micro.base_font = UiEstilo.fonte_re7(UiEstilo.RE7_WEIGHT_SEMIBOLD)
	micro.spacing_glyph = 1
	_f_micro = micro
	_montar()
	_raiz.visible = false
	set_process(false)


# --- API do roteiro -----------------------------------------------------------

## Mostra as linhas uma a uma, avancando na tecla de interagir. `quem`, quando
## dado, recebe `falar(true/false)` para mexer a boca e a cabeca, e a voz sai
## dele.
func falar(nome: String, linhas: Array[String], quem: Node3D = null) -> void:
	if linhas.is_empty():
		return
	await _esperar_vez()
	_entrar(nome, quem)
	for l: String in linhas:
		_mostrar_linha(l)
		await _seguiu
	_sair()


## Mostra a pergunta e a lista. Devolve a `chave` escolhida.
##
## A lista abre sozinha quando a pergunta termina de aparecer (ou na primeira
## tecla), e a pergunta continua no papel, para o jogador ver o que esta
## respondendo. Nao ha cancelar: escolha de missao tem de ter resposta.
func perguntar(nome: String, pergunta: String, opcoes: Array[Dictionary],
		quem: Node3D = null) -> StringName:
	if opcoes.is_empty():
		push_warning("Escolha.perguntar sem opcoes: %s" % pergunta)
		return &""
	await _esperar_vez()
	_entrar(nome, quem)
	if not pergunta.is_empty():
		_mostrar_linha(pergunta)
		if not _linha_completa():
			await _revelou
	_abrir_lista(opcoes)
	var chave: StringName = await _decidiu
	var o := _opcao(chave)
	if o.has("borboleta"):
		Borboleta.marcar(StringName(o["borboleta"]), o.get("valor", true))
	escolhido.emit(chave)
	_sair()
	return chave


## Publica: a verificacao automatizada avanca a fala sem simular tecla. O
## primeiro toque completa a linha, o segundo passa adiante.
func avancar() -> void:
	if not ativo or not _ocupado or _escolhendo:
		return
	if not _linha_completa():
		_completar_linha()
		return
	AudioDirector.tocar_ui(&"clique", -18.0)
	_seguiu.emit()


## Publica: escolhe por chave, sem navegar a lista. Falso se a lista nao esta
## aberta ou nao tem essa chave.
func escolher(chave: StringName) -> bool:
	if not _escolhendo:
		return false
	for i: int in _opcoes.size():
		if StringName(_opcoes[i]["chave"]) == chave:
			_selecionado = i
			_confirmar()
			return true
	return false


## Publica: as chaves da lista aberta agora, na ordem da tela.
func chaves() -> Array[StringName]:
	var saida: Array[StringName] = []
	for o: Dictionary in _opcoes:
		saida.append(StringName(o["chave"]))
	return saida


func escolhendo() -> bool:
	return _escolhendo


## O texto inteiro da linha no papel agora (sem marcas de gesto).
func texto() -> String:
	return _texto.text


func nome_na_fita() -> String:
	return _nome.text


# --- montagem -----------------------------------------------------------------

func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "Escolha"
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)

	_tarja_topo = _tarja(0.0)
	_tarja_base = _tarja(TELA.y - TARJA)

	# A folha inteira (papel, fitas, nome, texto, seta) e um no so, para subir
	# acima da tarja do cinema de uma vez.
	_folha = Control.new()
	_folha.name = "Folha"
	_folha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_folha)
	_folha.position = PAINEL.position
	_folha.size = PAINEL.size

	# Mesma sombra, papel ladrilhado e fitas do Dialogo: e a mesma caixa, com a
	# lista a mais. Ver os porques la.
	var sombra := ColorRect.new()
	sombra.color = Color(0.05, 0.04, 0.03, 0.5)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_folha.add_child(sombra)
	sombra.position = Vector2(2.0, 3.0)
	sombra.size = PAINEL.size

	var papel := TextureRect.new()
	papel.texture = _tex("ui_papel")
	papel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	papel.stretch_mode = TextureRect.STRETCH_TILE
	papel.modulate = Color(0.88, 0.83, 0.71)
	papel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_folha.add_child(papel)
	papel.position = Vector2.ZERO
	papel.size = PAINEL.size

	for lado: int in 2:
		var fita_canto := TextureRect.new()
		fita_canto.texture = _tex("ui_fita")
		fita_canto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fita_canto.stretch_mode = TextureRect.STRETCH_SCALE
		fita_canto.rotation = deg_to_rad(-7.0 if lado == 0 else 5.0)
		fita_canto.modulate = Color(1.0, 1.0, 1.0, 0.85)
		fita_canto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_folha.add_child(fita_canto)
		fita_canto.position = Vector2(180.0 if lado == 0 else 376.0, -6.0)
		fita_canto.size = Vector2(54.0, 15.0)

	var fita := TextureRect.new()
	fita.texture = _tex("ui_fita_marrom")
	fita.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fita.stretch_mode = TextureRect.STRETCH_SCALE
	fita.rotation = deg_to_rad(-1.5)
	fita.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_folha.add_child(fita)
	fita.position = Vector2(10.0, -10.0)
	fita.size = Vector2(150.0, 21.0)

	_nome = _rotulo(Rect2(16.0, -8.0, 142.0, 17.0), FONTE_P, Color(0.93, 0.9, 0.8))
	_nome.add_theme_color_override(&"font_outline_color", Color(0.08, 0.05, 0.03))
	_nome.add_theme_constant_override(&"outline_size", 3)

	_texto = _rotulo(Rect2(14.0, 13.0, PAINEL.size.x - 34.0, PAINEL.size.y - 20.0),
		FONTE_M, TINTA)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	_seta = Polygon2D.new()
	_seta.polygon = PackedVector2Array([Vector2(0, 0), Vector2(9, 0), Vector2(4.5, 6)])
	_seta.color = TINTA
	_folha.add_child(_seta)
	_seta.position = Vector2(PAINEL.size.x - 24.0, PAINEL.size.y - 14.0)

	# A lista e desenhada em vetor, como a da Conversa: a fonte RE7 rasteriza na
	# resolucao da janela e a lista continua legivel em 4K.
	_lista_ctl = Control.new()
	_lista_ctl.name = "Lista"
	_lista_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_lista_ctl)
	_lista_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lista_ctl.draw.connect(_desenhar_lista)


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
		push_warning("Escolha: textura ausente %s" % caminho)
		return null
	return load(caminho) as Texture2D


func _rotulo(r: Rect2, fonte: String, cor: Color) -> Label:
	var l := Label.new()
	l.add_theme_color_override(&"font_color", cor)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(fonte):
		l.add_theme_font_override(&"font", load(fonte) as Font)
	_folha.add_child(l)
	# Posicao e tamanho depois de entrar na arvore, como no Dialogo.
	l.position = r.position
	l.size = r.size
	return l


# --- abrir e fechar -----------------------------------------------------------

## Uma chamada por vez. Se o roteiro disparar duas sem await (erro dele), a
## segunda espera a primeira em vez de embaralhar as linhas.
func _esperar_vez() -> void:
	while _ocupado:
		await get_tree().process_frame


func _entrar(nome: String, quem: Node3D) -> void:
	_ocupado = true
	_fechar_em = -1.0
	_nome.text = nome
	_trocar_falante(quem)
	var no_cinema := _no_cinema()
	_folha.position = (PAINEL_CINEMA if no_cinema else PAINEL).position
	_tarja_topo.visible = not no_cinema
	_tarja_base.visible = not no_cinema
	if not no_cinema and not _travou:
		_travou = true
		_travar_jogador(true)
	if ativo:
		return
	ativo = true
	_raiz.visible = true
	set_process(true)
	_animar_entrada(no_cinema)
	abriu.emit()


func _no_cinema() -> bool:
	var cinema := get_node_or_null(^"/root/Cinema")
	return cinema != null and bool(cinema.get(&"ativa"))


func _trocar_falante(quem: Node3D) -> void:
	_calar_falante()
	_quem = quem if quem != null and is_instance_valid(quem) else null
	if _quem == null:
		return
	if _fala == null:
		_fala = Fala.new()
		_fala.name = "Fala"
		add_child(_fala)
	var ficha: Dictionary = {}
	var f: Variant = _quem.get(&"ficha")
	if f is Dictionary:
		ficha = f
	_fala.voz = _voz_de(_quem, ficha)
	var corpos: Array[Corpo] = []
	if _quem.has_method("corpo"):
		var c := _quem.call("corpo") as Corpo
		if c != null:
			corpos.append(c)
	_fala.corpos = corpos
	_fala.rosto = corpos[0].rosto if not corpos.is_empty() else null
	_fala.cadencia = float(Personalidade.de(int(ficha.get("personalidade", 0)))["cadencia"])
	_fala.personalidade = int(ficha.get("personalidade", 0))


## A voz de quem fala: a dele, se tiver, ou uma presa nele na altura da boca.
## O mesmo arranjo do Dialogo.
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


func _calar_falante() -> void:
	if _fala != null:
		_fala.pular()
	if _quem != null and is_instance_valid(_quem) and _quem.has_method("falar"):
		_quem.call("falar", false)


## Fim de uma chamada. O papel some um instante depois, se ninguem pedir de novo.
func _sair() -> void:
	_calar_falante()
	_escolhendo = false
	_opcoes = []
	_ocupado = false
	_fechar_em = FECHA_DEPOIS


func _fechar() -> void:
	if not ativo:
		return
	ativo = false
	_quem = null
	_raiz.visible = false
	set_process(false)
	if _travou:
		_travou = false
		_travar_jogador(false)
	fechou.emit()


func _travar_jogador(travado: bool) -> void:
	var jogador := get_tree().get_first_node_in_group(&"player")
	if jogador != null and jogador.has_method("travar"):
		jogador.call("travar", travado)


func _animar_entrada(no_cinema: bool) -> void:
	_raiz.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var t := create_tween().set_parallel(true)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_raiz, "modulate", Color.WHITE, 0.1)
	if not no_cinema:
		_tarja_topo.position.y = -TARJA
		_tarja_base.position.y = TELA.y
		t.tween_property(_tarja_topo, "position:y", 0.0, 0.16)
		t.tween_property(_tarja_base, "position:y", TELA.y - TARJA, 0.16)


# --- linhas -------------------------------------------------------------------

func _mostrar_linha(linha: String) -> void:
	_texto.text = Fala.sem_marcas(linha)
	_texto.visible_characters = 0
	_revelado = 0.0
	_ultimo_bip = 0
	_piscar = 0.0
	if _quem != null and is_instance_valid(_quem) and _fala != null:
		_fala.dizer(linha)
		if _quem.has_method("falar"):
			_quem.call("falar", true)
	if _texto.text.is_empty():
		_texto.visible_characters = -1


## O -1 e o "mostra tudo" do motor, e nao um indice. Ver o Dialogo.
func _linha_completa() -> bool:
	return _texto.visible_characters < 0 or _texto.visible_characters >= _texto.text.length()


func _completar_linha() -> void:
	_revelado = float(_texto.text.length())
	_texto.visible_characters = -1
	_calar_falante()
	_revelou.emit()


# --- lista --------------------------------------------------------------------

func _abrir_lista(opcoes: Array[Dictionary]) -> void:
	_opcoes = opcoes.slice(0, MAX_OPCOES)
	if opcoes.size() > MAX_OPCOES:
		push_warning("Escolha: %d opcoes, a lista mostra %d" % [opcoes.size(), MAX_OPCOES])
	_escolhendo = true
	_selecionado = 0
	_t_lista = 0.0
	_sel_y = -1.0
	_medir_lista()
	AudioDirector.tocar_open()


func _medir_lista() -> void:
	var maior := 0.0
	for o: Dictionary in _opcoes:
		maior = maxf(maior, _f_opcao.get_string_size(String(o.get("titulo", "")),
			HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_OPCAO).x)
	var largura := clampf(maior + 36.0, LISTA_LARGURA_MIN, LISTA_LARGURA_MAX)
	var alto := LISTA_CABECALHO + float(maxi(1, _opcoes.size())) * PASSO_LINHA + 5.0
	# A base fica presa logo acima do papel, do lado direito (o nome esta na
	# fita da esquerda).
	var base := _folha.position.y - 9.0
	_lista = Rect2(LISTA_DIREITA - largura, base - alto, largura, alto)


func _y_da_linha(i: int) -> float:
	return _lista.position.y + LISTA_CABECALHO + float(i) * PASSO_LINHA


func _opcao(chave: StringName) -> Dictionary:
	for o: Dictionary in _opcoes:
		if StringName(o["chave"]) == chave:
			return o
	return {}


func _confirmar() -> void:
	if not _escolhendo or _opcoes.is_empty():
		return
	var chave := StringName(_opcoes[_selecionado]["chave"])
	_escolhendo = false
	AudioDirector.tocar_confirm()
	_decidiu.emit(chave)


static func _suave(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


static func _alfa(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


func _desenhar_lista() -> void:
	if not _escolhendo or _opcoes.is_empty():
		return
	var t := _suave(_t_lista)
	var p := _lista
	p.position.x += (1.0 - t) * 12.0
	_lista_ctl.draw_rect(p, _alfa(COR_PAINEL, t), true)
	_lista_ctl.draw_rect(p, _alfa(COR_BORDA, t), false, 0.5)
	_lista_ctl.draw_string(_f_micro, p.position + Vector2(10.0, 11.0), "RESPONDER",
		HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_MICRO, _alfa(COR_FRACA, t))
	_lista_ctl.draw_line(Vector2(p.position.x + 8.0, p.position.y + 14.5),
		Vector2(p.end.x - 8.0, p.position.y + 14.5), _alfa(COR_BORDA, t * 0.8), 0.5, true)

	# Faixa ferrugem que some para a direita, com o fio vivo na borda: a mesma
	# marca de selecao da Conversa. Corre ate a linha nova em vez de pular.
	var sy := _sel_y if _sel_y >= 0.0 else _y_da_linha(_selecionado)
	var faixa := Rect2(p.position.x + 2.0, sy + 0.5, p.size.x - 4.0, PASSO_LINHA - 1.0)
	_lista_ctl.draw_polygon(PackedVector2Array([faixa.position,
		Vector2(faixa.end.x, faixa.position.y), faixa.end, Vector2(faixa.position.x, faixa.end.y)]),
		PackedColorArray([_alfa(COR_ACENTO, 0.9 * t), _alfa(COR_ACENTO, 0.05 * t),
		_alfa(COR_ACENTO, 0.05 * t), _alfa(COR_ACENTO, 0.9 * t)]))
	_lista_ctl.draw_rect(Rect2(faixa.position.x, faixa.position.y, 1.5, faixa.size.y),
		_alfa(COR_ACENTO_VIVO, t))

	for i: int in _opcoes.size():
		var ti := _suave(clampf(_t_lista * 1.7 - float(i) * 0.07, 0.0, 1.0))
		var sel := i == _selecionado
		var x := p.position.x + 9.0 + (1.0 - ti) * 10.0 + (2.0 if sel else 0.0)
		var yb := _y_da_linha(i) + 10.0
		# O numero da tecla, apagado: da para responder com 1, 2, 3 sem descer
		# a lista, como nos jogos de escolha de onde isto vem.
		_lista_ctl.draw_string(_f_micro, Vector2(x, yb - 0.5), str(i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_MICRO,
			_alfa(COR_ACENTO_VIVO if sel else COR_FRACA, ti))
		_lista_ctl.draw_string(_f_opcao, Vector2(x + 10.0, yb),
			String(_opcoes[i].get("titulo", "")), HORIZONTAL_ALIGNMENT_LEFT, -1,
			TAM_OPCAO, _alfa(COR_TITULO if sel else COR_TEXTO, ti))


# --- laco ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if _fechar_em >= 0.0:
		_fechar_em -= delta
		if _fechar_em < 0.0 and not _ocupado:
			_fechar()
			return

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
		if not com_voz and n - _ultimo_bip >= 3:
			_ultimo_bip = n
			AudioDirector.tocar_ui(&"clique", -28.0)
		if n >= total:
			_texto.visible_characters = -1
			if _quem != null and is_instance_valid(_quem) and _quem.has_method("falar"):
				_quem.call("falar", false)
			_revelou.emit()

	_piscar += delta
	_seta.visible = not _escolhendo and _ocupado and _linha_completa() \
		and fmod(_piscar, 0.9) < 0.55
	# Escolhendo, a pergunta fica no papel, esmaecida: e o que se esta
	# respondendo.
	_texto.modulate.a = 0.72 if _escolhendo else 1.0
	if _escolhendo:
		_t_lista = minf(1.0, _t_lista + delta / T_LISTA)
		var alvo := _y_da_linha(_selecionado)
		_sel_y = alvo if _sel_y < 0.0 else lerpf(_sel_y, alvo, 1.0 - exp(-delta * 24.0))
	_lista_ctl.queue_redraw()


func _input(evento: InputEvent) -> void:
	if not ativo or not _ocupado or get_tree().paused:
		return
	if _escolhendo:
		var n := _opcoes.size()
		if evento.is_action_pressed("mover_tras") or evento.is_action_pressed("ui_down"):
			_selecionado = posmod(_selecionado + 1, n)
			AudioDirector.tocar_nav()
			get_viewport().set_input_as_handled()
		elif evento.is_action_pressed("mover_frente") or evento.is_action_pressed("ui_up"):
			_selecionado = posmod(_selecionado - 1, n)
			AudioDirector.tocar_nav()
			get_viewport().set_input_as_handled()
		elif evento.is_action_pressed("interagir") or evento.is_action_pressed("ui_accept"):
			_confirmar()
			get_viewport().set_input_as_handled()
		elif evento is InputEventKey and evento.is_pressed() and not evento.is_echo():
			var k := (evento as InputEventKey).keycode
			if k >= KEY_1 and k < KEY_1 + n:
				_selecionado = int(k - KEY_1)
				_confirmar()
				get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("interagir") or evento.is_action_pressed("ui_accept"):
		avancar()
		get_viewport().set_input_as_handled()
