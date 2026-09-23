## Autoload. Conversa com escolha de assunto.
##
## Por que nao e o Dialogo
## -----------------------
## O Dialogo do morador e uma fila de falas sem escolha, e o comentario dele
## explica por que: escolha pede consequencia, e consequencia que nao existe e
## pior que nao ter escolha. Isso continua verdade para o morador — ele tem cinco
## assuntos e uma historia.
##
## Aqui e outro problema. O pedestre e um desconhecido numa cidade infinita: o
## que da valor a ele nao e a historia dele, e o fato de o jogador poder PUXAR
## assunto e descobrir que aquela pessoa tem mae, profissao, endereco e um CPF
## que funciona no aplicativo do celular. A escolha aqui nao muda o mundo — muda
## o que voce sabe sobre quem esta na sua frente, e isso e consequencia
## suficiente.
##
## Por que a tela e desenhada em vetor
## -----------------------------------
## A primeira versao era papel colado com fonte de pixel: uma fita com o nome e
## uma folha de assuntos pregada por cima. Em 480x270 lia bem; em 4K a janela
## multiplica o 2D por oito e a folha virava um bloco de texto duro sem hierarquia
## nenhuma — nome, fala e lista todos do mesmo peso.
##
## Agora e a mesma gramatica dos menus RE7 da prancha: fonte vetorial (que no
## modo MODERNO rasteriza na resolucao da JANELA, nao da base), painel escuro
## translucido, acento ferrugem. Quem fala tem rosto (o mesmo retrato que o
## portal e o terminal mostram), nome e o que a pessoa E — profissao e idade
## quando ja foi identificada, "nao identificado" quando nao. A lista fica a
## direita, na altura dos olhos, e a fala continua embaixo, esmaecida, enquanto
## o jogador escolhe: responder sem ver a pergunta e a coisa mais "menu de jogo"
## que uma conversa pode fazer.
##
## Tudo continua em coordenadas de 480x270 — o `canvas_items` faz o resto.
extends CanvasLayer

const TELA := Vector2(480.0, 270.0)
## Tarja de cinema. Entra junto com a conversa e diz "o mundo parou para ouvir".
const TARJA := 16.0

## Quantas linhas a lista aguenta.
##
## Eram oito na folha de papel, e oito ja estavam cheias na estufa. A lista nova
## fica no meio da altura da tela, entre a tarja de cima e o bloco de quem fala,
## e ali cabem dez com o cabecalho. Acima disso o lugar de resolver continua
## sendo o conteudo — uma aba, como a de servicos —, e nao rolagem: lista de
## conversa que rola e lista que esconde coisa.
const MAX_OPCOES := 10
const PASSO_LINHA := 14.0

## A lista cresce PARA CIMA a partir desta base, presa acima do bloco de quem
## fala. A largura segue o titulo mais comprido, entre os dois limites.
const LISTA_DIREITA := 458.0
const LISTA_BASE := 177.0
const LISTA_LARGURA_MIN := 150.0
const LISTA_LARGURA_MAX := 232.0
const LISTA_CABECALHO := 17.0

## Retrato: 40x52 do atlas mais dois pixels de moldura de cada lado. Escala 1,
## filtro nearest — a mesma foto do portal, reconhecivel pelo mesmo motivo.
const RETRATO := Rect2(28.0, 183.0, 44.0, 56.0)
const NOME_X := 86.0
const NOME_Y := 193.0
const TEXTO := Rect2(86.0, 210.0, 362.0, 42.0)

## Letras por segundo, igual a caixa do morador: duas velocidades de digitacao
## no mesmo jogo leem como dois jogos.
const VELOCIDADE := 44.0

const TAM_NOME := 13
const TAM_SUB := 7
const TAM_CORPO := 10
const TAM_OPCAO := 9
const TAM_MICRO := 7

const COR_TITULO := UiEstilo.RE7_TEXT_TITLE
const COR_TEXTO := UiEstilo.RE7_TEXT_PRIMARY
const COR_FRACA := UiEstilo.RE7_TEXT_MUTED
const COR_ACENTO := UiEstilo.RE7_ACCENT
const COR_ACENTO_VIVO := UiEstilo.RE7_ACCENT_HOT
const COR_PAINEL := Color(0.047, 0.062, 0.066, 0.8)
const COR_BORDA := UiEstilo.RE7_PANEL_EDGE
## A folha da planta e o pacote da entrega saem em verde: e o unico lugar da
## lista onde a cor diz de que assunto se trata antes do texto.
const COR_VERDE := Color("8fcf6e")

## Tempos. Entrada abaixo de 0,4 s (UI-BIBLE §5): acima disso o jogador espera.
const T_ENTRADA := 0.3
const T_LISTA := 0.24
const T_LINHA := 0.16
const T_SAIDA := 0.14

enum Fase { FALANDO, ESCOLHENDO, ENCERRANDO }

signal abriu()
signal fechou()

var ativo: bool = false

var _raiz: Control
var _tela: Control
var _retrato: Control
var _texto: Label
var _f_nome: Font
var _f_corpo: Font
var _f_opcao: Font
var _f_micro: Font

var _quem: Node3D
var _ficha: Dictionary = {}
## O retrato e um busto 3D vivo, num SubViewport proprio: o mesmo Corpo que anda
## na rua, com quepe, oculos, casaco e a boca mexendo enquanto a pessoa fala. O
## retrato 2D do registro nao desenha chapeu — o policial da blitz aparecia de
## cabelo e sem farda. Renderizado a 80x104 e desenhado em nearest: pixel de PSX.
var _retrato_vp: SubViewport
var _retrato_cam: Camera3D
var _retrato_corpo: Corpo
var _nome_mostrado := ""
var _sub_mostrado := ""
var _linhas: Array[String] = []
var _indice: int = 0
var _revelado: float = 0.0
var _piscar: float = 0.0
var _fase: Fase = Fase.FALANDO
var _opcoes: Array[Dictionary] = []
var _selecionado: int = 0

## Em que aba a lista esta. Vazio e a lista de assuntos; `servicos` e a aba de
## contratacao, que e a mesma lista com outro conteudo.
var _aba: StringName = &""
## De onde a conversa foi aberta. Muda a lista de assuntos: ao volante existe
## uma opcao que na calcada nao faria sentido nenhum.
var _contexto: StringName = &"rua"
## O carro em que a pessoa esta, quando a conversa e ao volante.
var _veiculo: Node3D

var _t_entrada := 0.0
var _t_lista := 0.0
var _t_linha := 1.0
var _sel_y := -1.0
var _lista := Rect2()
var _saida: Tween
## O HUD do jogo que estava a vista quando a conversa abriu. O minimapa aparecia
## atraves da lista de assuntos e a tira de lugar por cima da tarja de baixo;
## some tudo, como numa cena cortada, e volta exatamente o que estava.
var _hud_escondido: Array[Node] = []


func _ready() -> void:
	layer = 122
	process_mode = Node.PROCESS_MODE_ALWAYS
	_f_nome = _fonte(UiEstilo.RE7_WEIGHT_SEMIBOLD, 1)
	_f_corpo = _fonte(UiEstilo.RE7_WEIGHT_REGULAR, 0)
	_f_opcao = _fonte(UiEstilo.RE7_WEIGHT_SEMIBOLD, 0)
	_f_micro = _fonte(UiEstilo.RE7_WEIGHT_SEMIBOLD, 1)
	_montar()
	_raiz.visible = false
	set_process(false)
	Interiores.saiu.connect(func() -> void: _fechar())


# --- montagem ---------------------------------------------------------------

## Sans RE7 com espacamento opcional entre letras. Nome e cabecalho em caixa alta
## pedem ar entre as letras; o corpo da fala, nao.
func _fonte(peso: int, espaco: int) -> Font:
	var base := UiEstilo.fonte_re7(peso)
	if espaco == 0:
		return base
	var v := FontVariation.new()
	v.base_font = base
	v.spacing_glyph = espaco
	return v


func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "Conversa"
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)

	_tela = Control.new()
	_tela.name = "Tela"
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_tela)
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tela.draw.connect(_desenhar)

	# O retrato e um no proprio por causa do filtro: nearest para a foto nao
	# borrar, sem arrastar junto a fonte vetorial do resto da tela.
	_retrato = Control.new()
	_retrato.name = "Retrato"
	_retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_raiz.add_child(_retrato)
	_retrato.position = RETRATO.position
	_retrato.size = RETRATO.size
	_retrato.pivot_offset = RETRATO.size * 0.5
	# Torta de proposito, como a foto colada na prancha: e a mesma familia.
	_retrato.rotation = deg_to_rad(-2.5)
	_retrato.draw.connect(_desenhar_retrato)
	_montar_busto()

	_texto = Label.new()
	_texto.name = "Fala"
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texto.add_theme_font_override(&"font", _f_corpo)
	_texto.add_theme_font_size_override(&"font_size", TAM_CORPO)
	_texto.add_theme_color_override(&"font_color", COR_TEXTO)
	_texto.add_theme_constant_override(&"line_spacing", 1)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_raiz.add_child(_texto)
	_texto.position = TEXTO.position
	_texto.size = TEXTO.size


# --- abrir e fechar ---------------------------------------------------------

## `quem` e o Pedestre. Guardado para a voz sair da boca dele e para a multidao
## saber que aquela pessoa nao pode ser recolhida no meio da conversa.
func abrir(quem: Node3D, ficha: Dictionary,
		contexto: StringName = &"rua") -> void:
	# O contexto decide QUE assuntos aparecem na lista, e nao como eles soam.
	# `rua` e o padrao, `volante` ja existia para quem esta dentro de um carro, e
	# `casa` acrescenta o assunto do lugar. Ver FalasNpc.opcoes.
	if ativo:
		return
	_contexto = contexto
	_veiculo = null
	_abrir(quem, ficha)


## Conversa com quem esta ao volante. O interlocutor e o CARRO, e nao o corpo do
## motorista: e o carro que sabe quem esta dentro dele e e ele que precisa saber
## que a conversa acabou.
func abrir_veicular(veiculo: Node3D, _quem_falou: Node) -> void:
	if ativo or veiculo == null:
		return
	# `Object.get` devolve Variant, e atribuir null a uma Dictionary tipada e
	# erro de execucao. Por isso passa por uma variavel solta antes.
	var bruto: Variant = veiculo.get("ficha")
	if not (bruto is Dictionary):
		return
	var ficha: Dictionary = bruto
	if ficha.is_empty():
		return
	_contexto = &"volante"
	_veiculo = veiculo
	_abrir(veiculo, ficha)


func _abrir(quem: Node3D, ficha: Dictionary) -> void:
	_aba = &""
	if ativo or ficha.is_empty():
		return
	if _saida != null and _saida.is_valid():
		_saida.kill()
	ativo = true
	_quem = quem
	_ficha = ficha
	_montar_corpo_do_busto(ficha.get("aparencia", {}))
	_atualizar_cabecalho()
	_raiz.visible = true
	_raiz.modulate = Color.WHITE
	set_process(true)
	_travar_jogador(true)
	_esconder_hud(true)
	_fase = Fase.FALANDO
	_selecionado = 0
	_sel_y = -1.0
	_t_entrada = 0.0
	_dizer([FalasNpc.saudacao(ficha)])
	abriu.emit()


## Nome e subtitulo de quem fala. Refeito depois de cada resposta: perguntar
## "quem e voce?" troca MULHER pelo nome na hora, e o subtitulo passa de "nao
## identificado" para profissao e idade — e o momento em que a pessoa deixa de
## ser figurante, e a tela tem de mostrar isso.
func _atualizar_cabecalho() -> void:
	_nome_mostrado = FalasNpc.rotulo(_ficha)
	_sub_mostrado = _subtitulo(_ficha)


func _subtitulo(ficha: Dictionary) -> String:
	if _contexto == &"blitz":
		return "POLICIA MILITAR  ·  BLITZ"
	var partes := PackedStringArray()
	if _contexto == &"volante":
		partes.append("AO VOLANTE")
	var id := int(ficha["id"])
	var cargos := Profissoes.titulos(id)
	if not cargos.is_empty():
		partes.append(" / ".join(cargos))
	elif FalasNpc.identificado(ficha):
		partes.append("%s  ·  %d ANOS" % [String(ficha["profissao"]),
			int(ficha["idade"])])
	else:
		partes.append("NAO IDENTIFICADO")
	return "  ·  ".join(partes)


## Fecha de fora, sem passar pela escolha do jogador.
##
## Existe para a verificacao automatizada: a cidade continua jogando enquanto o
## teste mede, e uma caixa de fala aberta tranca o jogador — o que e certo no
## jogo e ruido na medida. Ver `TesteCarro._pegar_carro`.
func fechar_a_forca() -> void:
	_fechar()


func quem() -> Node3D:
	return _quem


func _fechar() -> void:
	if not ativo:
		return
	ativo = false
	_travar_jogador(false)
	_esconder_hud(false)
	if _retrato_corpo != null:
		_retrato_corpo.falar(false)
	_quem = null
	_veiculo = null
	_contexto = &"rua"
	AudioDirector.tocar_ui(&"clique", -12.0)
	# Some em 0,14 s em vez de piscar para fora. `ativo` ja e falso aqui: quem
	# pergunta se a conversa acabou recebe a resposta na hora, so o desenho
	# demora.
	_saida = create_tween()
	_saida.tween_property(_raiz, "modulate:a", 0.0, T_SAIDA)
	_saida.tween_callback(func() -> void:
		if not ativo:
			_raiz.visible = false
			set_process(false)
			if _retrato_vp != null:
				_retrato_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED)
	fechou.emit()


func _esconder_hud(esconder: bool) -> void:
	if not esconder:
		for no in _hud_escondido:
			if is_instance_valid(no):
				no.set(&"visible", true)
		_hud_escondido.clear()
		return
	_hud_escondido.clear()
	for no: Node in get_tree().get_nodes_in_group(&"hud"):
		if bool(no.get(&"visible")):
			no.set(&"visible", false)
			_hud_escondido.append(no)


func _travar_jogador(preso: bool) -> void:
	var jogador := get_tree().get_first_node_in_group(&"player")
	if jogador != null and jogador.has_method("travar"):
		jogador.call("travar", preso)


# --- falas ------------------------------------------------------------------

func _dizer(linhas: Array[String]) -> void:
	_linhas = linhas
	_indice = 0
	_t_lista = 0.0
	_mostrar_linha()


func _mostrar_linha() -> void:
	_texto.text = _linhas[_indice]
	_texto.visible_characters = 0
	_revelado = 0.0
	_t_linha = 0.0
	# A voz sai da boca do NPC, em 3D, e nao de um tocador de interface: e a
	# posicao que faz o murmurio pertencer aquela pessoa.
	#
	# is_instance_valid e obrigatorio, e nao zelo: carregar um save no meio de uma
	# conversa libera o pedestre junto com o resto do mundo, e chamar metodo em no
	# liberado derruba o jogo na fala seguinte.
	if is_instance_valid(_quem) and _quem.has_method("dizer"):
		_quem.call("dizer", _linhas[_indice])


func _linha_completa() -> bool:
	return (_texto.visible_characters < 0
		or _texto.visible_characters >= _texto.text.length())


## Publica: a verificacao automatizada avanca a conversa sem simular tecla.
func avancar() -> void:
	if not _linha_completa():
		_revelado = float(_texto.text.length())
		_texto.visible_characters = -1
		return
	_indice += 1
	if _indice < _linhas.size():
		AudioDirector.tocar_ui(&"clique", -18.0)
		_mostrar_linha()
		return

	if _fase == Fase.ENCERRANDO:
		_fechar()
		return
	_abrir_lista()


func _abrir_lista() -> void:
	_fase = Fase.ESCOLHENDO
	_atualizar_cabecalho()
	_opcoes = Profissoes.opcoes(int(_ficha["id"])) if _aba == &"servicos" \
		else FalasNpc.opcoes(_ficha, _contexto)
	if _opcoes.size() > MAX_OPCOES:
		# O aviso existe para aparecer no console de quem acrescentou a opcao
		# a mais, em vez de ela sumir da tela sem ninguem notar.
		push_warning("Conversa: %d opcoes, a lista mostra %d"
			% [_opcoes.size(), MAX_OPCOES])
	_selecionado = clampi(_selecionado, 0, maxi(0, _opcoes.size() - 1))
	_texto.visible_characters = -1
	_medir_lista()
	_t_lista = 0.0


## A lista e do tamanho do que tem escrito nela: largura pelo titulo mais
## comprido, altura pelo numero de linhas, base presa.
func _medir_lista() -> void:
	var maior := 0.0
	for o: Dictionary in _opcoes:
		maior = maxf(maior, _f_opcao.get_string_size(String(o["titulo"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_OPCAO).x)
	var largura := clampf(maior + 44.0, LISTA_LARGURA_MIN, LISTA_LARGURA_MAX)
	var n := mini(_opcoes.size(), MAX_OPCOES)
	var alto := LISTA_CABECALHO + float(maxi(1, n)) * PASSO_LINHA + 5.0
	_lista = Rect2(LISTA_DIREITA - largura, LISTA_BASE - alto, largura, alto)


func _y_da_linha(i: int) -> float:
	return _lista.position.y + LISTA_CABECALHO + float(i) * PASSO_LINHA


## Publica: a verificacao escolhe um assunto por chave, sem navegar a lista.
func escolher(chave: StringName) -> bool:
	for i in _opcoes.size():
		if StringName(_opcoes[i]["chave"]) == chave:
			_selecionado = i
			_acionar()
			return true
	return false


## Publica: as chaves da lista aberta agora, na ordem em que aparecem.
func chaves() -> Array[StringName]:
	var saida: Array[StringName] = []
	for o: Dictionary in _opcoes:
		saida.append(StringName(o["chave"]))
	return saida


func _acionar() -> void:
	if _opcoes.is_empty():
		return
	var opcao := _opcoes[_selecionado]
	var chave := StringName(opcao["chave"])
	AudioDirector.tocar_ui(&"clique", -10.0)

	# A aba de servicos. Trocar de aba nao gasta fala nenhuma: a pessoa nao diz
	# "claro, deixa eu ver o que sei fazer" — a lista simplesmente vira.
	if chave == &"servicos":
		_aba = &"servicos"
		_selecionado = 0
		_abrir_lista()
		return
	if chave == &"voltar":
		_aba = &""
		_selecionado = 0
		_abrir_lista()
		return
	var texto := String(chave)
	if texto.begins_with("contratar_") or texto.begins_with("demitir_"):
		# Fecha o trato e volta para a lista de assuntos: quem acabou de
		# contratar alguem tem mais o que perguntar a ela.
		_aba = &""
		_selecionado = 0
		_fase = Fase.FALANDO
		_dizer(Profissoes.responder(_ficha, chave))
		return

	# Na blitz, qualquer escolha encerra: depois de abrir a mochila (ou correr)
	# nao ha mais assunto com o policial.
	if chave == &"sair" or String(chave).begins_with("blitz_"):
		_fase = Fase.ENCERRANDO
		_dizer(FalasNpc.responder(_ficha, chave))
		return

	# Pedir o carro encerra a conversa: o sujeito responde, desce e a partir dai
	# nao ha mais com quem falar dali de dentro.
	if chave == &"descer":
		_fase = Fase.ENCERRANDO
		_dizer(FalasNpc.responder(_ficha, chave))
		if _veiculo != null and _veiculo.has_method("expulsar_motorista"):
			_veiculo.call_deferred("expulsar_motorista")
		return

	_fase = Fase.FALANDO
	_dizer(FalasNpc.responder(_ficha, chave))

	if chave == &"documento":
		# A carteira sai do bolso depois da fala, nao antes: a frase e o gesto de
		# entregar, e mostrar o documento primeiro tira o sentido dela.
		if not Documento.fechou.is_connected(_ao_fechar_documento):
			Documento.fechou.connect(_ao_fechar_documento, CONNECT_ONE_SHOT)
		_abrir_documento_depois()
	elif chave == &"trabalho":
		# Mesmo gesto do documento, com o celular: a pessoa fala e mostra o
		# perfil dela no aplicativo. Fechar o aparelho devolve a lista.
		if not Celular.fechou.is_connected(_ao_fechar_documento):
			Celular.fechou.connect(_ao_fechar_documento, CONNECT_ONE_SHOT)
		_abrir_perfil_depois()


func _abrir_documento_depois() -> void:
	await get_tree().create_timer(1.1).timeout
	if ativo and not Documento.ativo:
		Documento.abrir(_ficha)


func _abrir_perfil_depois() -> void:
	await get_tree().create_timer(1.0).timeout
	if ativo and not Celular.ativo:
		Celular.abrir_perfil(_ficha)


func _ao_fechar_documento() -> void:
	if ativo:
		_abrir_lista()


# --- laco -------------------------------------------------------------------

func _process(delta: float) -> void:
	var total := _texto.text.length()
	if _texto.visible_characters >= 0 and _texto.visible_characters < total:
		_revelado += VELOCIDADE * delta
		var n := mini(int(_revelado), total)
		_texto.visible_characters = n
		if n >= total:
			_texto.visible_characters = -1

	_piscar += delta
	_t_entrada = minf(1.0, _t_entrada + delta / T_ENTRADA)
	_t_linha = minf(1.0, _t_linha + delta / T_LINHA)
	if _fase == Fase.ESCOLHENDO:
		_t_lista = minf(1.0, _t_lista + delta / T_LISTA)
		var alvo := _y_da_linha(_selecionado)
		_sel_y = alvo if _sel_y < 0.0 else lerpf(_sel_y, alvo, 1.0 - exp(-delta * 24.0))

	var e := _suave(_t_entrada)
	var dy := (1.0 - e) * 8.0
	_retrato.position.y = RETRATO.position.y + dy
	_retrato.modulate.a = e
	_texto.position.y = TEXTO.position.y + dy
	# Escolhendo, a ultima fala fica embaixo, esmaecida: e a pergunta que o
	# jogador esta respondendo.
	var dim := 0.68 if _fase == Fase.ESCOLHENDO else 1.0
	_texto.modulate.a = e * dim * lerpf(0.35, 1.0, _suave(_t_linha))
	_tela.queue_redraw()
	_retrato.queue_redraw()
	if _retrato_corpo != null:
		# A boca anda enquanto a fala esta sendo digitada.
		_retrato_corpo.falar(_fase != Fase.ESCOLHENDO and not _linha_completa())
		_retrato_corpo.animar(0.0, delta)


func _montar_busto() -> void:
	_retrato_vp = SubViewport.new()
	_retrato_vp.size = Vector2i(80, 104)
	_retrato_vp.own_world_3d = true
	_retrato_vp.transparent_bg = false
	_retrato_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_retrato_vp.msaa_3d = Viewport.MSAA_DISABLED
	_retrato_vp.handle_input_locally = false
	add_child(_retrato_vp)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Retrato.FUNDO
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9aa0a6")
	env.ambient_light_energy = 1.05
	ambiente.environment = env
	_retrato_vp.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	luz.light_energy = 1.35
	luz.rotation = Vector3(deg_to_rad(-24.0), deg_to_rad(28.0), 0.0)
	_retrato_vp.add_child(luz)
	var recorte := DirectionalLight3D.new()
	recorte.light_energy = 0.5
	recorte.light_color = Color("ffd9a8")
	recorte.rotation = Vector3(deg_to_rad(-10.0), deg_to_rad(-150.0), 0.0)
	_retrato_vp.add_child(recorte)
	_retrato_cam = Camera3D.new()
	_retrato_cam.fov = 22.0
	_retrato_cam.near = 0.05
	_retrato_vp.add_child(_retrato_cam)
	_retrato_cam.current = true


func _montar_corpo_do_busto(aparencia: Dictionary) -> void:
	if _retrato_corpo != null:
		_retrato_corpo.queue_free()
		_retrato_corpo = null
	_retrato_corpo = Corpo.new()
	_retrato_vp.add_child(_retrato_corpo)
	_retrato_corpo.montar(aparencia)
	_retrato_corpo.rotation.y = PI + 0.25
	_retrato_corpo.animar(0.0, 0.016)
	# Enquadrado pela boca de quem esta na foto, com folga para chapeu.
	var boca := _retrato_corpo.altura_da_boca()
	_retrato_cam.position = Vector3(0.0, boca + 0.06, 1.75)
	_retrato_cam.look_at(Vector3(0.0, boca - 0.02, 0.0), Vector3.UP)
	_retrato_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS


static func _suave(t: float) -> float:
	var u := 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - u * u * u


# --- desenho ----------------------------------------------------------------

static func _alfa(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


func _gradiente_v(r: Rect2, cima: Color, baixo: Color) -> void:
	_tela.draw_polygon(PackedVector2Array([r.position,
		Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([cima, cima, baixo, baixo]))


func _gradiente_h(r: Rect2, esq: Color, dir: Color) -> void:
	_tela.draw_polygon(PackedVector2Array([r.position,
		Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([esq, dir, dir, esq]))


## Contorno de retangulo de cantos redondos. `draw_rect` nao arredonda e o
## StyleBox so aceita borda em pixel inteiro da base — oito pixels em 4K.
static func _cantos(r: Rect2, raio: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cs := [Vector2(r.end.x - raio, r.position.y + raio),
		Vector2(r.end.x - raio, r.end.y - raio),
		Vector2(r.position.x + raio, r.end.y - raio),
		Vector2(r.position.x + raio, r.position.y + raio)]
	for k in 4:
		var a0 := -PI * 0.5 + float(k) * PI * 0.5
		for s in 5:
			var a := a0 + float(s) / 4.0 * PI * 0.5
			pts.append(cs[k] + Vector2(cos(a), sin(a)) * raio)
	return pts


func _arredondado(r: Rect2, raio: float, cor: Color, cheio: bool,
		largura: float = 0.6) -> void:
	var pts := _cantos(r, raio)
	if cheio:
		_tela.draw_colored_polygon(pts, cor)
	else:
		pts.append(pts[0])
		_tela.draw_polyline(pts, cor, largura, true)


func _desenhar() -> void:
	var e := _suave(_t_entrada)
	# Veu embaixo, em duas faixas para o degrade nao marcar linha.
	_gradiente_v(Rect2(0.0, 128.0, TELA.x, 72.0), Color(0, 0, 0, 0.0),
		Color(0, 0, 0, 0.5 * e))
	_gradiente_v(Rect2(0.0, 200.0, TELA.x, TELA.y - 200.0),
		Color(0, 0, 0, 0.5 * e), Color(0, 0, 0, 0.86 * e))
	var tarja := TARJA * e
	_tela.draw_rect(Rect2(0.0, 0.0, TELA.x, tarja), Color.BLACK)
	_tela.draw_rect(Rect2(0.0, TELA.y - tarja, TELA.x, tarja), Color.BLACK)

	_desenhar_quem(e)
	_desenhar_teclas(e)
	if _fase == Fase.ESCOLHENDO:
		_desenhar_lista()
	elif _linha_completa() and _t_entrada >= 1.0:
		# Seta de continuar, pulsando no fim da fala.
		var a := 0.45 + 0.55 * (0.5 + 0.5 * sin(_piscar * 5.0))
		# Logo depois do fim da fala quando ela cabe numa linha; no canto da
		# caixa quando quebra. A mil pixels do texto ninguem liga a seta a ele.
		var tam_fala := _f_corpo.get_multiline_string_size(_texto.text,
			HORIZONTAL_ALIGNMENT_LEFT, TEXTO.size.x, TAM_CORPO)
		var uma_linha := tam_fala.y <= _f_corpo.get_height(TAM_CORPO) * 1.5
		var p := Vector2(TEXTO.end.x - 2.0, TEXTO.end.y - 5.0 + sin(_piscar * 5.0))
		if uma_linha:
			p = Vector2(TEXTO.position.x + tam_fala.x + 8.0,
				TEXTO.position.y + 6.0 + sin(_piscar * 5.0))
		_tela.draw_colored_polygon(PackedVector2Array([p + Vector2(-3.0, -2.0),
			p + Vector2(3.0, -2.0), p + Vector2(0.0, 1.8)]),
			_alfa(COR_ACENTO_VIVO, a))


func _desenhar_quem(e: float) -> void:
	var dy := (1.0 - e) * 8.0
	var y := NOME_Y + dy
	_tela.draw_string(_f_nome, Vector2(NOME_X, y), _nome_mostrado,
		HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_NOME, _alfa(COR_TITULO, e))
	var largura := _f_nome.get_string_size(_nome_mostrado,
		HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_NOME).x
	# Regua sob o nome, sumindo para a direita. E a unica linha da tela que
	# separa QUEM fala do QUE fala.
	_gradiente_h(Rect2(NOME_X, y + 3.0, maxf(largura, 80.0) + 36.0, 0.6),
		_alfa(COR_ACENTO_VIVO, e * 0.9), Color(COR_ACENTO_VIVO, 0.0))
	_tela.draw_string(_f_micro, Vector2(NOME_X, y + 12.0), _sub_mostrado,
		HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_SUB, _alfa(COR_ACENTO_VIVO, e))


func _desenhar_retrato() -> void:
	var r := Rect2(Vector2.ZERO, RETRATO.size)
	_retrato.draw_rect(Rect2(r.position + Vector2(1.5, 2.0), r.size),
		Color(0.0, 0.0, 0.0, 0.5))
	_retrato.draw_rect(r, Color("e2dccd"))
	var foto := r.grow(-2.0)
	if _retrato_vp != null:
		_retrato.draw_texture_rect(_retrato_vp.get_texture(), foto, false)
	else:
		_retrato.draw_rect(foto, Retrato.FUNDO)


## Teclas na tarja de baixo, alinhadas a direita. Tecla desenhada como tecla —
## caixa de canto redondo com a letra dentro — le mais rapido que "[E]".
func _desenhar_teclas(e: float) -> void:
	var itens: Array = [["W", "S", "ESCOLHER"], ["E", "", "CONFIRMAR"],
		["ESC", "", "SAIR"]] if _fase == Fase.ESCOLHENDO \
		else [["E", "", "CONTINUAR"], ["ESC", "", "SAIR"]]
	var cy := TELA.y - TARJA * e + TARJA * 0.5
	var x := LISTA_DIREITA
	for i in range(itens.size() - 1, -1, -1):
		var item: Array = itens[i]
		var rotulo := String(item[2])
		var w := _f_micro.get_string_size(rotulo, HORIZONTAL_ALIGNMENT_LEFT, -1,
			TAM_MICRO).x
		x -= w
		_tela.draw_string(_f_micro, Vector2(x, cy + 2.5), rotulo,
			HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_MICRO, _alfa(COR_TEXTO, e * 0.85))
		x -= 4.0
		for k in [1, 0]:
			var letra := String(item[k])
			if letra.is_empty():
				continue
			x -= _tecla(Vector2(x, cy), letra, e) + 2.0
		x -= 8.0


## Desenha uma tecla terminando em `direita` e devolve a largura dela.
func _tecla(direita: Vector2, letra: String, e: float) -> float:
	var w := maxf(10.0, _f_micro.get_string_size(letra, HORIZONTAL_ALIGNMENT_LEFT,
		-1, TAM_MICRO).x + 6.0)
	var r := Rect2(direita.x - w, direita.y - 5.0, w, 10.0)
	_arredondado(r, 1.8, Color(1.0, 1.0, 1.0, 0.07 * e), true)
	_arredondado(r, 1.8, _alfa(COR_TEXTO, 0.7 * e), false, 0.55)
	_tela.draw_string(_f_micro, Vector2(r.position.x, direita.y + 2.5), letra,
		HORIZONTAL_ALIGNMENT_CENTER, w, TAM_MICRO, _alfa(COR_TITULO, e))
	return w


func _desenhar_lista() -> void:
	var t := _suave(_t_lista)
	var desl := (1.0 - t) * 12.0
	var p := _lista
	p.position.x += desl
	_arredondado(p, 3.0, _alfa(COR_PAINEL, t), true)
	_arredondado(p, 3.0, _alfa(COR_BORDA, t), false, 0.5)

	var cab := "SERVICOS" if _aba == &"servicos" \
		else ("ABORDAGEM" if _contexto == &"blitz" else "ASSUNTOS")
	_tela.draw_string(_f_micro, p.position + Vector2(10.0, 11.0), cab,
		HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_MICRO, _alfa(COR_FRACA, t))
	# Quantos assuntos ainda nao foram puxados. E o empurrao que a lista
	# desbotada da de um jeito que da para ler de relance.
	var novos := 0
	for o: Dictionary in _opcoes:
		if not bool(o["visto"]) and _conta_como_assunto(StringName(o["chave"])):
			novos += 1
	if novos > 0 and _aba == &"":
		_tela.draw_string(_f_micro, Vector2(p.end.x - 10.0 - 60.0, p.position.y + 11.0),
			"%d NOVO%s" % [novos, "S" if novos > 1 else ""], HORIZONTAL_ALIGNMENT_RIGHT,
			60.0, TAM_MICRO, _alfa(COR_ACENTO_VIVO, t))
	_tela.draw_line(Vector2(p.position.x + 8.0, p.position.y + 14.5),
		Vector2(p.end.x - 8.0, p.position.y + 14.5), _alfa(COR_BORDA, t * 0.8), 0.5, true)

	var n := mini(_opcoes.size(), MAX_OPCOES)
	if n == 0:
		return
	# Destaque da linha escolhida: faixa ferrugem que some para a direita, com
	# o fio vivo na borda. Corre ate a linha nova em vez de pular.
	var sy := _sel_y if _sel_y >= 0.0 else _y_da_linha(_selecionado)
	_gradiente_h(Rect2(p.position.x + 2.0, sy + 0.5, p.size.x - 4.0, PASSO_LINHA - 1.0),
		_alfa(COR_ACENTO, 0.9 * t), _alfa(COR_ACENTO, 0.05 * t))
	_tela.draw_rect(Rect2(p.position.x + 2.0, sy + 0.5, 1.5, PASSO_LINHA - 1.0),
		_alfa(COR_ACENTO_VIVO, t))

	for i in n:
		var o := _opcoes[i]
		var ti := _suave(clampf(_t_lista * 1.7 - float(i) * 0.07, 0.0, 1.0))
		var sel := i == _selecionado
		var visto := bool(o["visto"])
		var chave := StringName(o["chave"])
		var x := p.position.x + 9.0 + (1.0 - ti) * 10.0 + (2.0 if sel else 0.0)
		var yb := _y_da_linha(i) + 10.0
		var cor := COR_TITULO if sel else (COR_FRACA if visto else COR_TEXTO)
		var cor_icone := cor
		if not sel and (chave == &"entregar" or chave == &"plantio" or chave == &"super"):
			cor_icone = COR_VERDE
		_icone(_tipo_icone(chave), Vector2(x + 3.5, yb - 3.3), _alfa(cor_icone, ti))
		_tela.draw_string(_f_opcao, Vector2(x + 12.0, yb), String(o["titulo"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, TAM_OPCAO, _alfa(cor, ti))
		# Marca a direita: ponto ferrugem no que e novo, visto no que ja foi.
		var mx := p.end.x - 9.0
		if not _conta_como_assunto(chave):
			continue
		if visto:
			_tela.draw_polyline(PackedVector2Array([Vector2(mx - 3.0, yb - 3.0),
				Vector2(mx - 1.5, yb - 1.4), Vector2(mx + 1.5, yb - 5.0)]),
				_alfa(COR_FRACA, ti * 0.9), 0.7, true)
		else:
			_tela.draw_circle(Vector2(mx, yb - 3.3), 1.3, _alfa(COR_ACENTO_VIVO, ti))


## Encerrar, voltar e identidade nao sao "assunto": nao ganham ponto de novo.
static func _conta_como_assunto(chave: StringName) -> bool:
	return not (chave == &"sair" or chave == &"voltar" or chave == &"documento"
		or chave == &"descer" or String(chave).begins_with("contratar_")
		or String(chave).begins_with("demitir_") or String(chave).begins_with("blitz_"))


static func _tipo_icone(chave: StringName) -> StringName:
	match chave:
		&"documento":
			return &"doc"
		&"sair":
			return &"sair"
		&"trabalho":
			return &"maleta"
		&"servicos":
			return &"pessoa"
		&"voltar":
			return &"voltar"
		&"descer":
			return &"carro"
		&"blitz_colaborar":
			return &"pacote"
		&"blitz_cafe":
			return &"mais"
		&"blitz_correr":
			return &"sair"
		&"entregar":
			return &"pacote"
		&"plantio", &"super":
			return &"folha"
	var s := String(chave)
	if s.begins_with("contratar_"):
		return &"mais"
	if s.begins_with("demitir_"):
		return &"menos"
	return &"fala"


## Glifos de 7x7 em traco. Um icone por tipo de opcao: a mao acha "identidade"
## e "encerrar" pela forma antes de ler.
func _icone(tipo: StringName, c: Vector2, cor: Color) -> void:
	var l := 0.7
	match tipo:
		&"fala":
			_tela.draw_polyline(PackedVector2Array([c + Vector2(-3.5, -2.8),
				c + Vector2(3.5, -2.8), c + Vector2(3.5, 1.6), c + Vector2(-0.5, 1.6),
				c + Vector2(-2.5, 3.4), c + Vector2(-2.2, 1.6), c + Vector2(-3.5, 1.6),
				c + Vector2(-3.5, -2.8)]), cor, l, true)
		&"maleta":
			_tela.draw_polyline(PackedVector2Array([c + Vector2(-3.5, -1.6),
				c + Vector2(3.5, -1.6), c + Vector2(3.5, 3.0), c + Vector2(-3.5, 3.0),
				c + Vector2(-3.5, -1.6)]), cor, l, true)
			_tela.draw_polyline(PackedVector2Array([c + Vector2(-1.4, -1.6),
				c + Vector2(-1.4, -3.0), c + Vector2(1.4, -3.0), c + Vector2(1.4, -1.6)]),
				cor, l, true)
			_tela.draw_line(c + Vector2(-3.5, 0.6), c + Vector2(3.5, 0.6), cor, l * 0.8, true)
		&"doc":
			_tela.draw_polyline(PackedVector2Array([c + Vector2(-3.6, -2.6),
				c + Vector2(3.6, -2.6), c + Vector2(3.6, 2.6), c + Vector2(-3.6, 2.6),
				c + Vector2(-3.6, -2.6)]), cor, l, true)
			_tela.draw_rect(Rect2(c + Vector2(-2.6, -1.5), Vector2(2.2, 2.8)), cor)
			_tela.draw_line(c + Vector2(0.6, -0.9), c + Vector2(2.6, -0.9), cor, l * 0.8, true)
			_tela.draw_line(c + Vector2(0.6, 0.9), c + Vector2(2.6, 0.9), cor, l * 0.8, true)
		&"sair":
			_tela.draw_polyline(PackedVector2Array([c + Vector2(0.5, -3.2),
				c + Vector2(-3.0, -3.2), c + Vector2(-3.0, 3.2), c + Vector2(0.5, 3.2)]),
				cor, l, true)
			_tela.draw_line(c + Vector2(-1.2, 0.0), c + Vector2(3.6, 0.0), cor, l, true)
			_tela.draw_polyline(PackedVector2Array([c + Vector2(1.8, -1.8),
				c + Vector2(3.6, 0.0), c + Vector2(1.8, 1.8)]), cor, l, true)
		&"pessoa":
			_tela.draw_arc(c + Vector2(0.0, -1.6), 1.5, 0.0, TAU, 14, cor, l, true)
			_tela.draw_arc(c + Vector2(0.0, 3.4), 3.0, PI, TAU, 12, cor, l, true)
		&"voltar":
			_tela.draw_line(c + Vector2(-3.4, 0.0), c + Vector2(3.4, 0.0), cor, l, true)
			_tela.draw_polyline(PackedVector2Array([c + Vector2(-1.4, -2.2),
				c + Vector2(-3.4, 0.0), c + Vector2(-1.4, 2.2)]), cor, l, true)
		&"carro":
			_tela.draw_polyline(PackedVector2Array([c + Vector2(-3.6, 1.4),
				c + Vector2(-3.6, -0.4), c + Vector2(-2.0, -0.6), c + Vector2(-1.0, -2.4),
				c + Vector2(1.8, -2.4), c + Vector2(2.8, -0.6), c + Vector2(3.6, -0.4),
				c + Vector2(3.6, 1.4), c + Vector2(-3.6, 1.4)]), cor, l, true)
			_tela.draw_circle(c + Vector2(-2.0, 1.8), 0.9, cor)
			_tela.draw_circle(c + Vector2(2.0, 1.8), 0.9, cor)
		&"pacote":
			_tela.draw_polyline(PackedVector2Array([c + Vector2(-3.2, -2.0),
				c + Vector2(3.2, -2.0), c + Vector2(3.2, 3.0), c + Vector2(-3.2, 3.0),
				c + Vector2(-3.2, -2.0), c + Vector2(-2.0, -3.4), c + Vector2(2.0, -3.4),
				c + Vector2(3.2, -2.0)]), cor, l, true)
			_tela.draw_line(c + Vector2(0.0, -2.0), c + Vector2(0.0, 3.0), cor, l * 0.8, true)
		&"folha":
			var pts := PackedVector2Array()
			for k in 9:
				var u := float(k) / 8.0
				pts.append(c + Vector2(-3.0 + 6.0 * u, 3.0 - 6.0 * u)
					+ Vector2(1.0, 1.0).normalized() * sin(u * PI) * 1.9)
			for k in range(8, -1, -1):
				var u := float(k) / 8.0
				pts.append(c + Vector2(-3.0 + 6.0 * u, 3.0 - 6.0 * u)
					- Vector2(1.0, 1.0).normalized() * sin(u * PI) * 1.9)
			_tela.draw_polyline(pts, cor, l, true)
			_tela.draw_line(c + Vector2(-3.4, 3.4), c + Vector2(1.2, -1.2), cor, l * 0.8, true)
		&"mais", &"menos":
			_tela.draw_arc(c, 3.2, 0.0, TAU, 18, cor, l, true)
			_tela.draw_line(c + Vector2(-1.6, 0.0), c + Vector2(1.6, 0.0), cor, l, true)
			if tipo == &"mais":
				_tela.draw_line(c + Vector2(0.0, -1.6), c + Vector2(0.0, 1.6), cor, l, true)


# --- entrada ----------------------------------------------------------------

func _input(evento: InputEvent) -> void:
	if not ativo or Documento.ativo or Celular.ativo:
		return

	if _fase == Fase.ESCOLHENDO:
		if _opcoes.is_empty():
			return
		if evento.is_action_pressed("mover_tras") or evento.is_action_pressed("ui_down"):
			_selecionado = posmod(_selecionado + 1, mini(_opcoes.size(), MAX_OPCOES))
			AudioDirector.tocar_ui(&"clique", -22.0)
			get_viewport().set_input_as_handled()
		elif evento.is_action_pressed("mover_frente") or evento.is_action_pressed("ui_up"):
			_selecionado = posmod(_selecionado - 1, mini(_opcoes.size(), MAX_OPCOES))
			AudioDirector.tocar_ui(&"clique", -22.0)
			get_viewport().set_input_as_handled()
		elif (evento.is_action_pressed("interagir")
				or evento.is_action_pressed("ui_accept")):
			_acionar()
			get_viewport().set_input_as_handled()
		elif evento.is_action_pressed("pausa"):
			_fechar()
			get_viewport().set_input_as_handled()
		return

	if evento.is_action_pressed("interagir") or evento.is_action_pressed("ui_accept"):
		avancar()
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("pausa"):
		_fechar()
		get_viewport().set_input_as_handled()
