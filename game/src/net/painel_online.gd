## A folha de sessao: hospedar, entrar, ver quem esta junto. Tecla F7.
##
## Isto e a porta de entrada PROVISORIA do multiplayer. O lugar certo e uma
## linha JOGAR ONLINE no titulo, com a folha de viagem do plano 10 — mas menu.gd
## e cidade.gd estao em edicao em outra frente agora, e mexer neles por baixo
## dela e como o working tree perde trabalho (memoria do projeto, sessoes
## paralelas). O painel vive inteiro dentro da Sessao e nao toca em nenhum dos
## dois. Plano 13, Fase 1: quando o menu estiver livre, a folha de viagem passa a
## chamar a mesma API (Sessao.hospedar / Sessao.entrar) e este painel vira so o
## atalho de quem ja esta andando na rua — o "Abrir para LAN".
##
## Sempre ligado, mesmo fechado: o feed de recados ("MARIA entrou", chat) no
## canto de cima so aparece em rede.
class_name PainelOnline
extends CanvasLayer

## Acima da HUD (100) e do minimapa, abaixo do menu de sistema (150).
const CAMADA := 140
const MARGEM := 7
const LARGURA := 300
const LINHAS_FEED := 5
const FEED_DURACAO := 7.0

var _raiz: Control
var _folha: PanelContainer
var _estado: Label
var _campo_endereco: LineEdit
var _campo_senha: LineEdit
var _botao_hospedar: Button
var _botao_entrar: Button
var _botao_sair: Button
var _lista_lan: VBoxContainer
var _lista_jogadores: Label
var _campo_chat: LineEdit
var _feed: Label
var _linhas_feed: Array[Dictionary] = []
var _fonte_p: Font
var _fonte_m: Font
var _aberto := false
var _mouse_antes: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _travado_antes := false


func _ready() -> void:
	layer = CAMADA
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fonte_p = load(UiEstilo.FONTE_P) as Font
	_fonte_m = load(UiEstilo.FONTE_M) as Font
	_montar()
	Sessao.modo_mudou.connect(func(_m: int) -> void: _atualizar())
	Sessao.lista_mudou.connect(_atualizar)
	Sessao.recado.connect(_ao_recado)
	Sessao.descoberta().lista_mudou.connect(_atualizar_lan)
	_folha.visible = false
	_atualizar()


func _input(evento: InputEvent) -> void:
	var tecla := evento as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	if tecla.physical_keycode == KEY_F7:
		if _aberto:
			fechar()
		else:
			abrir()
		get_viewport().set_input_as_handled()
	elif _aberto and tecla.physical_keycode == KEY_ESCAPE:
		fechar()
		get_viewport().set_input_as_handled()


func abrir() -> void:
	if _aberto:
		return
	_aberto = true
	_folha.visible = true
	_mouse_antes = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var p := Sessao.corpo_local() as Player
	if p != null:
		_travado_antes = p.travado
		p.travar(true)
	# Procurar servidor so enquanto a folha esta aberta: a porta de descoberta
	# e uma so por maquina, e segura-la o jogo inteiro tiraria ela de outro
	# processo aberto ao lado (dois jogos na mesma maquina, teste).
	if not Sessao.eh_servidor():
		Sessao.descoberta().escutar()
	_atualizar()
	_atualizar_lan()


func fechar() -> void:
	if not _aberto:
		return
	_aberto = false
	_folha.visible = false
	Input.mouse_mode = _mouse_antes
	var p := Sessao.corpo_local() as Player
	if p != null and not _travado_antes:
		p.travar(false)
	if not Sessao.eh_servidor():
		Sessao.descoberta().parar()


func aberto() -> bool:
	return _aberto


# --- montagem --------------------------------------------------------------------

func _montar() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	_feed = Label.new()
	UiEstilo.aplicar(_feed, _fonte_p)
	_feed.position = Vector2(MARGEM, MARGEM)
	_feed.size = Vector2(320, 80)
	_feed.add_theme_color_override("font_color", UiEstilo.PAPEL_ABERTO)
	_feed.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_feed.add_theme_constant_override("shadow_offset_x", 1)
	_feed.add_theme_constant_override("shadow_offset_y", 1)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_feed)

	_folha = PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = UiEstilo.PAPEL
	estilo.border_color = UiEstilo.TINTA_FRACA
	estilo.set_border_width_all(1)
	estilo.set_content_margin_all(MARGEM)
	_folha.add_theme_stylebox_override("panel", estilo)
	_folha.set_anchors_preset(Control.PRESET_CENTER)
	_folha.custom_minimum_size = Vector2(LARGURA, 0)
	_raiz.add_child(_folha)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	_folha.add_child(col)

	var titulo := _rotulo("SESSAO", _fonte_m, UiEstilo.TINTA_TITULO)
	col.add_child(titulo)
	_estado = _rotulo("", _fonte_p, UiEstilo.TINTA)
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_estado)
	col.add_child(HSeparator.new())

	var linha_end := HBoxContainer.new()
	linha_end.add_child(_rotulo("ENDERECO", _fonte_p, UiEstilo.TINTA_FRACA))
	_campo_endereco = _campo("127.0.0.1", 150)
	linha_end.add_child(_campo_endereco)
	col.add_child(linha_end)

	var linha_senha := HBoxContainer.new()
	linha_senha.add_child(_rotulo("SENHA   ", _fonte_p, UiEstilo.TINTA_FRACA))
	_campo_senha = _campo("", 150)
	_campo_senha.secret = true
	_campo_senha.placeholder_text = "(nenhuma)"
	linha_senha.add_child(_campo_senha)
	col.add_child(linha_senha)

	var botoes := HBoxContainer.new()
	botoes.add_theme_constant_override("separation", 6)
	_botao_hospedar = _botao("HOSPEDAR", _ao_hospedar)
	_botao_entrar = _botao("ENTRAR", _ao_entrar)
	_botao_sair = _botao("SAIR DA SESSAO", func() -> void: Sessao.sair("Voce saiu da sessao."))
	botoes.add_child(_botao_hospedar)
	botoes.add_child(_botao_entrar)
	botoes.add_child(_botao_sair)
	col.add_child(botoes)

	col.add_child(_rotulo("NA REDE", _fonte_p, UiEstilo.TINTA_FRACA))
	_lista_lan = VBoxContainer.new()
	col.add_child(_lista_lan)
	col.add_child(HSeparator.new())

	col.add_child(_rotulo("JUNTO", _fonte_p, UiEstilo.TINTA_FRACA))
	_lista_jogadores = _rotulo("", _fonte_p, UiEstilo.TINTA)
	col.add_child(_lista_jogadores)

	_campo_chat = _campo("", LARGURA - 2 * MARGEM)
	_campo_chat.placeholder_text = "falar (ENTER)"
	_campo_chat.max_length = ProtocoloRede.CHAT_MAX
	_campo_chat.text_submitted.connect(func(t: String) -> void:
		Sessao.falar(t)
		_campo_chat.clear())
	col.add_child(_campo_chat)

	col.add_child(_rotulo("[F7] fecha", _fonte_p, UiEstilo.TINTA_FRACA))


func _rotulo(texto: String, fonte: Font, cor: Color) -> Label:
	var l := Label.new()
	UiEstilo.aplicar(l, fonte)
	l.text = texto
	l.add_theme_color_override("font_color", cor)
	return l


func _campo(texto: String, largura: float) -> LineEdit:
	var c := LineEdit.new()
	c.text = texto
	c.custom_minimum_size = Vector2(largura, 0)
	c.add_theme_font_override("font", _fonte_p)
	c.add_theme_font_size_override("font_size", UiEstilo.tamanho_nativo(_fonte_p))
	c.add_theme_color_override("font_color", UiEstilo.TINTA)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = UiEstilo.PAPEL_ABERTO
	fundo.border_color = UiEstilo.TINTA_FRACA
	fundo.border_width_bottom = 1
	fundo.set_content_margin_all(2)
	c.add_theme_stylebox_override("normal", fundo)
	c.add_theme_stylebox_override("focus", fundo)
	return c


func _botao(texto: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.add_theme_font_override("font", _fonte_p)
	b.add_theme_font_size_override("font_size", UiEstilo.tamanho_nativo(_fonte_p))
	b.add_theme_color_override("font_color", UiEstilo.TINTA)
	b.add_theme_color_override("font_hover_color", UiEstilo.DESTAQUE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_color = UiEstilo.TINTA_FRACA
	normal.set_border_width_all(1)
	normal.set_content_margin_all(3)
	for estado: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(estado, normal)
	b.pressed.connect(acao)
	return b


# --- acoes ------------------------------------------------------------------------

func _ao_hospedar() -> void:
	Sessao.descoberta().parar()
	var alvo := Sessao.separar_endereco(_campo_endereco.text)
	Sessao.hospedar(int(alvo[1]), ProtocoloRede.MAX_JOGADORES_PADRAO, "", _campo_senha.text)


func _ao_entrar() -> void:
	Sessao.descoberta().parar()
	Sessao.entrar(_campo_endereco.text, -1, _campo_senha.text)


# --- desenho ------------------------------------------------------------------------

func _atualizar() -> void:
	if _estado == null:
		return
	var em_rede := Sessao.em_rede()
	_botao_hospedar.disabled = em_rede
	_botao_entrar.disabled = em_rede
	_botao_sair.disabled = not em_rede
	_campo_chat.editable = Sessao.modo == Sessao.Modo.CLIENTE or Sessao.eh_servidor()
	match Sessao.modo:
		Sessao.Modo.SOLO:
			_estado.text = "SOZINHO. Hospede para abrir este mundo, ou digite o endereco de alguem."
		Sessao.Modo.CONECTANDO:
			_estado.text = "LIGANDO..."
		Sessao.Modo.HOSPEDANDO:
			_estado.text = "HOSPEDANDO na porta %d  -  %s\nPasse aos amigos: %s" % [
				Sessao.config.porta, _contagem(), _enderecos()]
		Sessao.Modo.DEDICADO:
			_estado.text = "SERVIDOR DEDICADO  -  %s" % _contagem()
		Sessao.Modo.CLIENTE:
			_estado.text = "EM %s  -  %s" % [Sessao.nome_servidor, _contagem()]
	var linhas := PackedStringArray()
	for id: int in Sessao.jogadores:
		var j: Dictionary = Sessao.jogadores[id]
		var eu := " (VOCE)" if id == Sessao.meu_id else ""
		linhas.append("%s%s  %d ms" % [j["nome"], eu, int(j.get("ping", 0))])
	_lista_jogadores.text = "\n".join(linhas) if not linhas.is_empty() else "-"


func _contagem() -> String:
	var maximo := Sessao.config.max_jogadores if Sessao.config != null else 0
	return "%d/%d" % [Sessao.jogadores.size(), maximo] if maximo > 0 else "%d" % Sessao.jogadores.size()


## Os IPv4 desta maquina que um amigo consegue alcancar, Hamachi primeiro.
func _enderecos() -> String:
	var saida := PackedStringArray()
	for ip: String in IP.get_local_addresses():
		if ip.count(".") != 3 or ip.begins_with("127.") or ip.begins_with("169.254."):
			continue
		if ip.begins_with("25.") or ip.begins_with("26."):
			saida.insert(0, ip)
		else:
			saida.append(ip)
	return ", ".join(saida.slice(0, 3)) if not saida.is_empty() else "(sem rede)"


func _atualizar_lan() -> void:
	if _lista_lan == null:
		return
	for filho: Node in _lista_lan.get_children():
		filho.queue_free()
	var servidores := Sessao.descoberta().servidores
	if servidores.is_empty():
		_lista_lan.add_child(_rotulo("-", _fonte_p, UiEstilo.TINTA_FRACA))
		return
	# A assinatura daqui comeca a ser calculada na primeira lista (thread, ~80 ms);
	# ate ficar pronta, ninguem e marcado como "outra cidade".
	var minha_cidade := Sessao.assinatura_do_mundo()
	for chave: String in servidores:
		var s: Dictionary = servidores[chave]
		var texto := "%s  %d/%d  %s%s" % [s["nome"], s["n"], s["max"], chave,
			"  [SENHA]" if s["senha"] else ""]
		var entra: bool = s["compativel"]
		if not s["compativel"]:
			texto += "  (outra versao)"
		elif not minha_cidade.is_empty() and not String(s.get("cidade", "")).is_empty() \
				and String(s["cidade"]) != minha_cidade:
			texto += "  (outra cidade)"
			entra = false
		var b := _botao(texto, func() -> void: _campo_endereco.text = chave)
		b.disabled = not entra or Sessao.em_rede()
		_lista_lan.add_child(b)


func _ao_recado(texto: String) -> void:
	_linhas_feed.append({"texto": texto, "t": Time.get_ticks_msec() / 1000.0})
	while _linhas_feed.size() > LINHAS_FEED:
		_linhas_feed.pop_front()
	_desenhar_feed()


func _process(_delta: float) -> void:
	if _linhas_feed.is_empty():
		return
	var agora := Time.get_ticks_msec() / 1000.0
	var antes := _linhas_feed.size()
	_linhas_feed.assign(_linhas_feed.filter(func(l: Dictionary) -> bool:
		return agora - float(l["t"]) < FEED_DURACAO))
	if _linhas_feed.size() != antes:
		_desenhar_feed()


func _desenhar_feed() -> void:
	var linhas := PackedStringArray()
	for l: Dictionary in _linhas_feed:
		linhas.append(String(l["texto"]))
	_feed.text = "\n".join(linhas)
