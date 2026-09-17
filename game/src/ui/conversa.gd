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
## Por isso as duas caixas convivem em vez de uma substituir a outra.
##
## O vocabulario visual e o mesmo do resto do jogo: papel colado, fita com o nome
## em cima, nada alinhado direito. A lista de assuntos e uma segunda folha presa
## acima da primeira.
extends CanvasLayer

const UI := "res://assets/ui/%s.png"
const FONTE_M := "res://assets/fontes/psx_media.fnt"
const FONTE_P := "res://assets/fontes/psx_pequena.fnt"

const TELA := Vector2(480.0, 270.0)
const PAINEL := Rect2(20.0, 198.0, 440.0, 56.0)
## Folha dos assuntos. Duzentos e quarenta e seis de largura porque o titulo mais
## comprido tem vinte e quatro letras e a fonte pequena rende nove por letra: com
## os 222 da primeira versao, "VOCE PRECISA DE AJUDA?" saia pela borda direita do
## papel.
const LISTA := Rect2(214.0, 84.0, 246.0, 104.0)
const TARJA := 14.0

## Quantas linhas a folha de assuntos aguenta, e de quanto em quanto elas vao.
##
## Eram SEIS, e seis nao bastava. A conta na rua fecha em cinco — nevoa, bairro,
## assunto proprio, encerrar, identidade —, mas dentro da casa da fumaca entra
## "o que ta rolando aqui" e dentro da estufa entra a plantacao, e agora entra
## "contratar servicos" em toda conversa da cidade. Sete opcoes numa folha de
## seis linhas nao avisam nada: a setima simplesmente nao e desenhada, e a
## setima era VER IDENTIDADE — a opcao que o jogo inteiro ensina a procurar.
##
## Oito cabe com folga e a folha cresce PARA CIMA conforme a lista, com a base
## presa logo acima da caixa de fala. Crescer para baixo entraria por cima dela.
const MAX_OPCOES := 8
const PASSO_LINHA := 15.0

## Letras por segundo, igual a caixa do morador: duas velocidades de digitacao
## no mesmo jogo leem como dois jogos.
const VELOCIDADE := 44.0

const TINTA := Color("2a1f16")
const TINTA_FRACA := Color("6d5c46")
const TINTA_VISTA := Color("8d7f6a")

enum Fase { FALANDO, ESCOLHENDO, ENCERRANDO }

signal abriu()
signal fechou()

var ativo: bool = false

var _raiz: Control
var _texto: Label
var _nome: Label
var _seta: Polygon2D
var _folha_lista: Control
var _itens: Array[Label] = []
var _tarja_topo: ColorRect
var _tarja_base: ColorRect

var _quem: Node3D
var _ficha: Dictionary = {}
var _linhas: Array[String] = []
var _indice: int = 0
var _revelado: float = 0.0
var _piscar: float = 0.0
var _fase: Fase = Fase.FALANDO
var _opcoes: Array[Dictionary] = []
var _selecionado: int = 0

## Em que aba a lista esta. Vazio e a lista de assuntos; `servicos` e a aba de
## contratacao, que e a mesma folha com outro conteudo.
##
## Uma aba e nao uma tela nova: a folha ja esta na mao do jogador, ja tem a
## navegacao dele e ja tem o lugar dela na imagem. Abrir uma segunda janela por
## cima seria uma interface a mais para uma lista de uma linha.
var _aba: StringName = &""
var _folha_sombra: Control
var _folha_papel: Control
var _fitas: Array[Control] = []
## De onde a conversa foi aberta. Muda a lista de assuntos: ao volante existe
## uma opcao que na calcada nao faria sentido nenhum.
var _contexto: StringName = &"rua"
## O carro em que a pessoa esta, quando a conversa e ao volante.
var _veiculo: Node3D


func _ready() -> void:
	layer = 122
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	_raiz.visible = false
	set_process(false)
	Interiores.saiu.connect(func() -> void: _fechar())


# --- montagem ---------------------------------------------------------------

func _tex(nome: String) -> Texture2D:
	var caminho := UI % nome
	return load(caminho) as Texture2D if ResourceLoader.exists(caminho) else null


func _papel(pai: Control, r: Rect2, tom: Color) -> Array[Control]:
	var sombra := ColorRect.new()
	sombra.color = Color(0.05, 0.04, 0.03, 0.5)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(sombra)
	sombra.position = r.position + Vector2(2.0, 3.0)
	sombra.size = r.size

	var folha := TextureRect.new()
	folha.texture = _tex("ui_papel")
	folha.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Ladrilhado, nao esticado: a textura tem 128 px e esticar aumenta o grao.
	folha.stretch_mode = TextureRect.STRETCH_TILE
	folha.modulate = tom
	folha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(folha)
	folha.position = r.position
	folha.size = r.size
	return [sombra, folha]


func _rotulo(pai: Control, texto: String, r: Rect2, fonte: String,
		cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_color_override(&"font_color", cor)
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(fonte):
		l.add_theme_font_override(&"font", load(fonte))
	pai.add_child(l)
	l.position = r.position
	l.size = r.size
	return l


func _tarja(y: float) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0, 0, 0, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(c)
	c.position = Vector2(0.0, y)
	c.size = Vector2(TELA.x, TARJA)
	return c


func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "Conversa"
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)

	_tarja_topo = _tarja(0.0)
	_tarja_base = _tarja(TELA.y - TARJA)

	_papel(_raiz, PAINEL, Color(0.88, 0.83, 0.71))

	# Fita com o nome, saindo por cima da borda do papel. Mesmo recurso da
	# prancha e da caixa do morador: a peca que atravessa a borda amarra as duas.
	var fita := TextureRect.new()
	fita.texture = _tex("ui_fita_marrom")
	fita.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fita.stretch_mode = TextureRect.STRETCH_SCALE
	fita.rotation = deg_to_rad(-1.5)
	fita.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(fita)
	fita.position = Vector2(30.0, 188.0)
	fita.size = Vector2(178.0, 21.0)

	_nome = _rotulo(_raiz, "", Rect2(36.0, 190.0, 168.0, 17.0), FONTE_P,
		Color(0.93, 0.9, 0.8))
	_nome.add_theme_color_override(&"font_outline_color", Color(0.08, 0.05, 0.03))
	_nome.add_theme_constant_override(&"outline_size", 3)

	_texto = _rotulo(_raiz, "", Rect2(PAINEL.position.x + 14.0,
		PAINEL.position.y + 13.0, PAINEL.size.x - 34.0, PAINEL.size.y - 20.0),
		FONTE_M, TINTA)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_seta = Polygon2D.new()
	_seta.polygon = PackedVector2Array([Vector2(0, 0), Vector2(9, 0), Vector2(4.5, 6)])
	_seta.color = TINTA
	_raiz.add_child(_seta)
	_seta.position = Vector2(PAINEL.end.x - 24.0, PAINEL.end.y - 14.0)

	_montar_lista()


func _montar_lista() -> void:
	_folha_lista = Control.new()
	_folha_lista.name = "Assuntos"
	_folha_lista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_folha_lista)
	_folha_lista.set_anchors_preset(Control.PRESET_FULL_RECT)

	var pecas := _papel(_folha_lista, LISTA, Color(0.9, 0.86, 0.75))
	_folha_sombra = pecas[0]
	_folha_papel = pecas[1]

	# Duas fitas tortas nos cantos de cima, como a folha foi presa ali as pressas.
	for lado in 2:
		var fita := TextureRect.new()
		fita.texture = _tex("ui_fita")
		fita.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fita.stretch_mode = TextureRect.STRETCH_SCALE
		fita.rotation = deg_to_rad(-8.0 if lado == 0 else 6.0)
		fita.modulate = Color(1.0, 1.0, 1.0, 0.85)
		fita.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_folha_lista.add_child(fita)
		fita.position = Vector2(LISTA.position.x - 6.0 if lado == 0
			else LISTA.end.x - 40.0, LISTA.position.y - 5.0)
		fita.size = Vector2(46.0, 13.0)
		_fitas.append(fita)

	for i in MAX_OPCOES:
		var l := _rotulo(_folha_lista, "", Rect2(LISTA.position.x + 14.0,
			LISTA.position.y + 7.0 + float(i) * PASSO_LINHA,
			LISTA.size.x - 22.0, 14.0), FONTE_P, TINTA)
		_itens.append(l)

	_folha_lista.visible = false


# --- abrir e fechar ---------------------------------------------------------

## `quem` e o Pedestre. Guardado para a voz sair da boca dele e para a multidao
## saber que aquela pessoa nao pode ser recolhida no meio da conversa.
func abrir(quem: Node3D, ficha: Dictionary,
		contexto: StringName = &"rua") -> void:
	# O contexto decide QUE assuntos aparecem na lista, e nao como eles soam.
	# `rua` e o padrao, `volante` ja existia para quem esta dentro de um carro, e
	# `casa` acrescenta o assunto do lugar. Ver FalasNpc.opcoes.
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
	ativo = true
	_quem = quem
	_ficha = ficha
	_nome.text = FalasNpc.rotulo(ficha)
	_raiz.visible = true
	set_process(true)
	_travar_jogador(true)
	_fase = Fase.FALANDO
	_dizer([FalasNpc.saudacao(ficha)])
	_animar_entrada()
	abriu.emit()


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
	_raiz.visible = false
	_folha_lista.visible = false
	set_process(false)
	_travar_jogador(false)
	_quem = null
	_veiculo = null
	_contexto = &"rua"
	AudioDirector.tocar_ui(&"clique", -12.0)
	fechou.emit()


func _travar_jogador(preso: bool) -> void:
	var jogador := get_tree().get_first_node_in_group(&"player")
	if jogador != null and jogador.has_method("travar"):
		jogador.call("travar", preso)


func _animar_entrada() -> void:
	_raiz.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_tarja_topo.position.y = -TARJA
	_tarja_base.position.y = TELA.y
	var t := create_tween().set_parallel(true)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_raiz, "modulate", Color.WHITE, 0.1)
	t.tween_property(_tarja_topo, "position:y", 0.0, 0.16)
	t.tween_property(_tarja_base, "position:y", TELA.y - TARJA, 0.16)


# --- falas ------------------------------------------------------------------

func _dizer(linhas: Array[String]) -> void:
	_linhas = linhas
	_indice = 0
	_folha_lista.visible = false
	_mostrar_linha()


func _mostrar_linha() -> void:
	_texto.text = _linhas[_indice]
	_texto.visible_characters = 0
	_revelado = 0.0
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
	_opcoes = Profissoes.opcoes(int(_ficha["id"])) if _aba == &"servicos" 		else FalasNpc.opcoes(_ficha, _contexto)
	if _opcoes.size() > MAX_OPCOES:
		# Nao ha rolagem, e nao vai haver: uma lista de conversa que rola e uma
		# lista que esconde coisa. Se um dia passar de oito, o lugar de resolver
		# e o conteudo — tirando um assunto ou abrindo uma aba, como a de
		# servicos —, e nao a caixa. O aviso existe para isso aparecer no
		# console de quem acrescentou o nono em vez de sumir na tela.
		push_warning("Conversa: %d opcoes, a folha mostra %d"
			% [_opcoes.size(), MAX_OPCOES])
	_selecionado = clampi(_selecionado, 0, maxi(0, _opcoes.size() - 1))
	_texto.text = ""
	_texto.visible_characters = -1
	_ajustar_folha(mini(_opcoes.size(), MAX_OPCOES))
	_folha_lista.visible = true
	_atualizar_lista()


## A folha cresce com a lista, com a base presa.
##
## Uma folha de tamanho fixo com cinco linhas escritas tem um palmo de papel em
## branco embaixo, e papel em branco numa caixa de dialogo le como erro de
## layout. Aqui ela e do tamanho do que tem escrito nela — que e tambem como
## seria um pedaco de papel de verdade pregado na parede.
func _ajustar_folha(linhas: int) -> void:
	var alto: float = 14.0 + float(maxi(1, linhas)) * PASSO_LINHA
	var topo: float = LISTA.end.y - alto
	var r := Rect2(LISTA.position.x, topo, LISTA.size.x, alto)
	if _folha_papel != null:
		_folha_papel.position = r.position
		_folha_papel.size = r.size
	if _folha_sombra != null:
		_folha_sombra.position = r.position + Vector2(2.0, 3.0)
		_folha_sombra.size = r.size
	for k in _fitas.size():
		_fitas[k].position = Vector2(
			r.position.x - 6.0 if k == 0 else r.end.x - 40.0, topo - 5.0)
	for i in _itens.size():
		_itens[i].position = Vector2(r.position.x + 14.0,
			topo + 7.0 + float(i) * PASSO_LINHA)


func _atualizar_lista() -> void:
	for i in _itens.size():
		var visivel := i < _opcoes.size()
		_itens[i].visible = visivel
		if not visivel:
			continue
		var opcao := _opcoes[i]
		var marca := ">" if i == _selecionado else " "
		_itens[i].text = "%s %s" % [marca, opcao["titulo"]]
		# Assunto ja puxado sai desbotado. E a unica memoria visivel que a
		# conversa tem, e sem ela o jogador repete os quatro toda vez.
		_itens[i].add_theme_color_override(&"font_color",
			TINTA if i == _selecionado else (
				TINTA_VISTA if bool(opcao["visto"]) else TINTA_FRACA))


## Publica: a verificacao escolhe um assunto por chave, sem navegar a lista.
func escolher(chave: StringName) -> bool:
	for i in _opcoes.size():
		if StringName(_opcoes[i]["chave"]) == chave:
			_selecionado = i
			_acionar()
			return true
	return false


func _acionar() -> void:
	if _opcoes.is_empty():
		return
	var opcao := _opcoes[_selecionado]
	var chave := StringName(opcao["chave"])
	AudioDirector.tocar_ui(&"clique", -10.0)

	# A aba de servicos. Trocar de aba nao gasta fala nenhuma: a pessoa nao diz
	# "claro, deixa eu ver o que sei fazer" — a folha simplesmente vira, que e o
	# que uma folha faz.
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

	if chave == &"sair":
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


func _abrir_documento_depois() -> void:
	await get_tree().create_timer(1.1).timeout
	if ativo and not Documento.ativo:
		Documento.abrir(_ficha)


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
	_seta.visible = (_fase != Fase.ESCOLHENDO and _linha_completa()
		and fmod(_piscar, 0.9) < 0.55)


func _input(evento: InputEvent) -> void:
	if not ativo or Documento.ativo:
		return

	if _fase == Fase.ESCOLHENDO:
		if evento.is_action_pressed("mover_tras") or evento.is_action_pressed("ui_down"):
			_selecionado = posmod(_selecionado + 1, _opcoes.size())
			AudioDirector.tocar_ui(&"clique", -22.0)
			_atualizar_lista()
			get_viewport().set_input_as_handled()
		elif evento.is_action_pressed("mover_frente") or evento.is_action_pressed("ui_up"):
			_selecionado = posmod(_selecionado - 1, _opcoes.size())
			AudioDirector.tocar_ui(&"clique", -22.0)
			_atualizar_lista()
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
