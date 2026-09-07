## Menu de titulo e de opcoes, na mesma linguagem da prancha de inventario.
##
## Um menu de sistema com caixas cinzentas depois de uma prancha de cortica
## quebraria o tom logo na primeira tela. Tudo aqui e papel sobre cortica, com a
## mesma fonte bitmap do resto.
##
## O menu de opcoes cumpre o que a Fase 2 prometeu: os tres niveis de nevoa e os
## quatro ajustes de pos-processamento, gravados em disco.
class_name Menu
extends CanvasLayer

const UI := "res://assets/ui/%s.png"
const FONTE_P := "res://assets/fontes/psx_pequena.fnt"
const FONTE_M := "res://assets/fontes/psx_media.fnt"
const FONTE_T := "res://assets/fontes/psx_titulo.fnt"

const TELA := Vector2(480.0, 270.0)
const TINTA := Color("2a1f16")
const TINTA_FRACA := Color("5a4a38")
const DESTAQUE := Color("8a2f1f")
## Valor do papel de todas as folhas do menu. Uma constante e nao um numero solto
## em quatro lugares: com valores diferentes, trocar de painel muda o tom da tela
## e le como bug de iluminacao.
const PAPEL := Color(1.24, 1.19, 1.06)

## Janela do mapa dentro da pagina. O resto da largura e legenda.
const MAPA_CAIXA := Rect2(32.0, 60.0, 306.0, 172.0)
const PREDIO_COR := Color("6d6047")
const PATIO_COR := Color("bdb49a")
const PARQUE_COR := Color("77855a")
const BALDIO_COR := Color("a89a7e")

enum Painel { TITULO, OPCOES, MAPA, NOME, APARENCIA }

signal jogar(nome: String)
signal continuar()
signal sair()

var painel: Painel = Painel.TITULO
var _selecionado: int = 0

var _raiz: Control
var _itens_titulo: Array[Label] = []
var _abas_titulo: Array[TextureRect] = []
var _itens_opcoes: Array[Label] = []
var _no_titulo: Control
var _no_opcoes: Control
var _no_mapa: Control
var _no_nome: Control
var _criacao: CriacaoAparencia
var _campo_nome: Label
var _nome_digitado: String = ""
var _piscar_cursor: float = 0.0
var _mapa: Mapa
var _cabecalho: Label
var _escala: Label

## Escalas do mapa da pagina, em metros por pixel. A janela tem 300 px, entao
## isto cobre de 600 m, onde da para ler a fita de predios de cada quadra, a
## 2400 m, onde o que se le e o desenho das avenidas.
const ESCALAS: Array[float] = [2.0, 3.2, 5.0, 8.0]
var _escala_atual: int = 1

## Cada opcao e {rotulo, ler: Callable, aplicar: Callable(int passo)}
var _opcoes: Array[Dictionary] = []


func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	_definir_opcoes()
	_montar()
	mostrar(Painel.TITULO)


# --- definicao das opcoes ---------------------------------------------------

func _definir_opcoes() -> void:
	_opcoes = [
		{
			"rotulo": "NEVOA",
			"ler": func() -> String: return Settings.fog_preset().display_name.to_upper(),
			"aplicar": func(passo: int) -> void:
				var ids := Settings.FOG_PRESET_IDS
				var i := ids.find(Settings.fog_preset_id)
				Settings.set_fog_preset(ids[posmod(i + passo, ids.size())]),
		},
		_slider("GRAO", &"grain", 0.0, 0.2, 0.02),
		_slider("ABERRACAO", &"chromatic", 0.0, 2.0, 0.2),
		_slider("SCANLINE", &"scanline", 0.0, 0.5, 0.04),
		_slider("VINHETA", &"vignette", 0.0, 1.0, 0.1),
		{
			"rotulo": "DITHER",
			"ler": func() -> String: return "LIGADO" if Settings.dither else "DESLIGADO",
			"aplicar": func(_passo: int) -> void:
				Settings.set_post(&"dither", not Settings.dither),
		},
		{
			"rotulo": "VOLTAR",
			"ler": func() -> String: return "",
			"aplicar": func(_passo: int) -> void: mostrar(Painel.TITULO),
		},
	]


## Opcao numerica com passo fixo. Barra em blocos em vez de porcentagem: numa
## tela de 480x270 dez blocos leem mais rapido que "0.14".
func _slider(rotulo: String, chave: StringName, minimo: float, maximo: float,
		passo: float) -> Dictionary:
	return {
		"rotulo": rotulo,
		"ler": func() -> String:
			var v: float = Settings.get(String(chave))
			var n := int(round((v - minimo) / (maximo - minimo) * 10.0))
			return "[%s%s]" % ["#".repeat(n), ".".repeat(10 - n)],
		"aplicar": func(p: int) -> void:
			var v: float = Settings.get(String(chave))
			Settings.set_post(chave, clampf(v + float(p) * passo, minimo, maximo)),
	}


# --- montagem ---------------------------------------------------------------

func _imagem(pai: Control, nome: String, pos: Vector2, tamanho: Vector2,
		estica: int = TextureRect.STRETCH_SCALE) -> TextureRect:
	var t := TextureRect.new()
	var caminho := UI % nome
	if ResourceLoader.exists(caminho):
		t.texture = load(caminho)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = estica
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(t)
	t.position = pos
	t.size = tamanho
	return t


func _rotulo(pai: Control, texto: String, pos: Vector2, tamanho: Vector2,
		fonte: String, cor: Color,
		alinhamento: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_color_override(&"font_color", cor)
	l.horizontal_alignment = alinhamento
	if ResourceLoader.exists(fonte):
		l.add_theme_font_override(&"font", load(fonte))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(l)
	l.position = pos
	l.size = tamanho
	return l


func _montar() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	# O MESMO fundo da prancha de inventario, e nao cortica lisa. A referencia do
	# jogo e uma mesa coberta de papel, e o menu de titulo e a primeira tela que
	# alguem ve: abrir num fundo de outro vocabulario e prometer um jogo e
	# entregar outro tres segundos depois.
	# Escurecido um degrau. O fundo tem de ficar ABAIXO do papel que vai por cima
	# dele, senao a folha das entradas nao recorta e a lista some no meio da
	# colagem — foi o primeiro resultado, com os dois no mesmo valor.
	_imagem(_raiz, "ui_colagem", Vector2.ZERO, TELA).modulate = Color(0.78, 0.75, 0.7)

	_montar_titulo()
	_montar_opcoes()
	_montar_mapa()
	_montar_nome()
	_montar_aparencia()

	_imagem(_raiz, "ui_vinheta", Vector2.ZERO, TELA)


## Titulo e entradas na linguagem da prancha: fita crepe colada em fileira atras
## do titulo, e cada entrada numa aba de papel com o texto sublinhado — que e
## exatamente o tratamento dos botoes USAR e EXAMINAR do inventario.
##
## Nada esta reto. As fitas tem angulos diferentes e as abas tambem; alinhar
## tudo devolveria a tela para o territorio de menu de sistema, que e o que a
## prancha inteira existe para evitar.
func _montar_titulo() -> void:
	_no_titulo = Control.new()
	_no_titulo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_no_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_no_titulo)

	var pedacos: Array[Rect2] = [
		Rect2(104.0, 30.0, 76.0, 24.0), Rect2(172.0, 26.0, 80.0, 25.0),
		Rect2(244.0, 30.0, 78.0, 24.0), Rect2(312.0, 27.0, 68.0, 24.0),
	]
	var giros: Array[float] = [-3.0, 1.5, -1.5, 2.5]
	for i in pedacos.size():
		var fita := _imagem(_no_titulo, "ui_fita", pedacos[i].position,
			pedacos[i].size)
		fita.pivot_offset = pedacos[i].size * 0.5
		fita.rotation = deg_to_rad(giros[i])
		fita.modulate = Color(1.06, 1.02, 0.94)

	_rotulo(_no_titulo, "NEVOA E DITHER", Vector2(90.0, 28.0), Vector2(300.0, 26.0),
		FONTE_T, TINTA, HORIZONTAL_ALIGNMENT_CENTER)
	var fita_sub := _imagem(_no_titulo, "ui_fita", Vector2(150.0, 54.0),
		Vector2(180.0, 18.0))
	fita_sub.pivot_offset = Vector2(90.0, 9.0)
	fita_sub.rotation = deg_to_rad(0.8)
	fita_sub.modulate = Color(1.02, 0.99, 0.92)
	_rotulo(_no_titulo, "suburbio japones, madrugada", Vector2(90.0, 56.0),
		Vector2(300.0, 16.0), FONTE_P, TINTA_FRACA, HORIZONTAL_ALIGNMENT_CENTER)

	# Uma folha grande atras das entradas. E o que a referencia faz: o texto nunca
	# fica direto sobre a mesa, fica sempre sobre papel. Sem ela, a colagem do
	# fundo passa por tras das letras e a lista some no meio dos recortes.
	var folha := Rect2(146.0, 76.0, 188.0, 162.0)
	var sombra := ColorRect.new()
	sombra.color = Color(0.16, 0.11, 0.06, 0.34)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_no_titulo.add_child(sombra)
	sombra.position = folha.position + Vector2(3.0, 4.0)
	sombra.size = folha.size
	_imagem(_no_titulo, "ui_papel", folha.position, folha.size,
		TextureRect.STRETCH_TILE).modulate = PAPEL
	for canto in 4:
		var fita_canto := _imagem(_no_titulo, "ui_fita",
			Vector2(folha.position.x - 12.0 if canto % 2 == 0 else folha.end.x - 34.0,
				folha.position.y - 6.0 if canto < 2 else folha.end.y - 10.0),
			Vector2(46.0, 15.0))
		fita_canto.pivot_offset = Vector2(23.0, 7.0)
		fita_canto.rotation = deg_to_rad([-14.0, 12.0, 9.0, -11.0][canto])
		fita_canto.modulate = Color(1.0, 1.0, 1.0, 0.9)

	var entradas := ["CONTINUAR", "NOVO JOGO", "MAPA", "OPCOES", "SAIR"]
	for i in entradas.size():
		var y := 86.0 + float(i) * 29.0
		var aba := _imagem(_no_titulo, "ui_aba", Vector2(162.0, y - 4.0),
			Vector2(156.0, 26.0))
		aba.pivot_offset = Vector2(80.0, 13.0)
		aba.rotation = deg_to_rad([-1.2, 0.8, -0.6, 1.4, -1.0][i])
		_abas_titulo.append(aba)
		_itens_titulo.append(_rotulo(_no_titulo, entradas[i], Vector2(160.0, y),
			Vector2(160.0, 18.0), FONTE_M, TINTA, HORIZONTAL_ALIGNMENT_CENTER))
		# Sublinhado a caneta, como nos botoes da prancha. E o que faz a palavra
		# ler como escrita a mao numa etiqueta, e nao como item de lista.
		var largura := 12.0 + float(entradas[i].length()) * 8.0
		_imagem(_no_titulo, "ui_sublinhado", Vector2(240.0 - largura * 0.5, y + 15.0),
			Vector2(largura, 5.0))

	var dica := _rotulo(_no_titulo, "[W/S] mover    [E] escolher",
		Vector2(0.0, TELA.y - 24.0), Vector2(TELA.x, 16.0), FONTE_P,
		Color(0.93, 0.89, 0.79), HORIZONTAL_ALIGNMENT_CENTER)
	dica.add_theme_color_override(&"font_outline_color", Color(0.08, 0.05, 0.03))
	dica.add_theme_constant_override(&"outline_size", 4)


## A unica coisa que o jogador escolhe sobre si mesmo.
##
## Tudo o mais da ficha — numero, data de nascimento, filiacao, endereco,
## profissao — e sorteado pelo registro, e a folha diz isso em voz alta. Nao e
## limitacao tecnica: e a premissa. O jogo inteiro depois disso e sobre consultar
## um cadastro que ja existia antes de voce chegar, e um personagem com ficha
## escolhida a dedo nao pertence a ele.
func _montar_nome() -> void:
	_no_nome = Control.new()
	_no_nome.set_anchors_preset(Control.PRESET_FULL_RECT)
	_no_nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_no_nome)

	_imagem(_no_nome, "ui_papel", Vector2(76.0, 52.0), Vector2(328.0, 160.0),
		TextureRect.STRETCH_TILE).modulate = PAPEL
	var fita := _imagem(_no_nome, "ui_fita_marrom", Vector2(146.0, 44.0),
		Vector2(188.0, 20.0))
	fita.pivot_offset = Vector2(94.0, 10.0)
	fita.rotation = deg_to_rad(-2.0)
	_rotulo(_no_nome, "FICHA DE CADASTRO", Vector2(146.0, 46.0),
		Vector2(188.0, 18.0), FONTE_P, Color(0.93, 0.9, 0.8),
		HORIZONTAL_ALIGNMENT_CENTER)

	_rotulo(_no_nome, "NOME DO DECLARANTE", Vector2(100.0, 82.0),
		Vector2(280.0, 14.0), FONTE_P, TINTA_FRACA)

	# Linha pautada com o nome em cima, como num formulario preenchido a mao.
	_campo_nome = _rotulo(_no_nome, "", Vector2(104.0, 96.0), Vector2(272.0, 26.0),
		FONTE_T, TINTA)
	_imagem(_no_nome, "ui_sublinhado", Vector2(100.0, 122.0), Vector2(280.0, 5.0))

	# Quatro linhas curtas com quatorze pixels entre elas. Em tres linhas longas
	# com doze, como estava, a fonte de onze pixels encostava uma na outra e o
	# paragrafo virava uma mancha.
	# Tres linhas curtas com dezesseis pixels entre elas. A fonte pequena rende
	# uns nove pixels por caractere, entao trinta e poucos caracteres ja passam
	# da folha; a primeira versao tinha quarenta e o texto saia pelo lado.
	var explicacao := [
		"O RESTO DA FICHA E SORTEADO",
		"PELO REGISTRO CIVIL.",
		"CONFIRA NA SUA CARTEIRA.",
	]
	for i in explicacao.size():
		_rotulo(_no_nome, explicacao[i], Vector2(100.0, 140.0 + float(i) * 16.0),
			Vector2(280.0, 15.0), FONTE_P, TINTA_FRACA)

	_rotulo(_no_nome, "[LETRAS] escrever  [ENTER] assinar  [ESC] voltar",
		Vector2(0.0, 194.0), Vector2(TELA.x, 14.0), FONTE_P, TINTA_FRACA,
		HORIZONTAL_ALIGNMENT_CENTER)


## A tela de sinais particulares vem depois do nome e antes do jogo. Ela e um
## Control proprio porque desenha um retrato 3D ao vivo; ver src/ui/criacao.gd.
func _montar_aparencia() -> void:
	_criacao = CriacaoAparencia.new()
	_criacao.name = "Criacao"
	_raiz.add_child(_criacao)
	_criacao.confirmou.connect(_comecar_partida)
	_criacao.voltou.connect(func() -> void: mostrar(Painel.NOME))
	_criacao.visible = false


## Fecha o menu e comeca. O nome ja foi gravado no registro na assinatura; aqui
## so restam a aparencia, que a propria tela grava, e sair do menu.
func _comecar_partida() -> void:
	esconder()
	jogar.emit(_nome_digitado.strip_edges())


func _montar_opcoes() -> void:
	_no_opcoes = Control.new()
	_no_opcoes.set_anchors_preset(Control.PRESET_FULL_RECT)
	_no_opcoes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_no_opcoes)

	_imagem(_no_opcoes, "ui_papel", Vector2(48.0, 30.0), Vector2(384.0, 200.0),
		TextureRect.STRETCH_TILE).modulate = PAPEL
	_rotulo(_no_opcoes, "OPCOES", Vector2(48.0, 40.0), Vector2(384.0, 24.0),
		FONTE_T, TINTA, HORIZONTAL_ALIGNMENT_CENTER)

	for i in _opcoes.size():
		var y := 76.0 + float(i) * 20.0
		_rotulo(_no_opcoes, _opcoes[i]["rotulo"], Vector2(74.0, y),
			Vector2(150.0, 18.0), FONTE_M, TINTA)
		_itens_opcoes.append(_rotulo(_no_opcoes, "", Vector2(228.0, y),
			Vector2(180.0, 18.0), FONTE_M, TINTA_FRACA))

	_rotulo(_no_opcoes, "[W/S] mover    [A/D] ajustar    [ESC] voltar",
		Vector2(0.0, TELA.y - 22.0), Vector2(TELA.x, 16.0), FONTE_P,
		Color(0.82, 0.76, 0.62), HORIZONTAL_ALIGNMENT_CENTER)


# --- pagina do mapa ---------------------------------------------------------

## Mapa do menu de pausa. Uma pagina de papel com a cidade desenhada, legenda dos
## icones e escala.
##
## E o mesmo desenho do minimapa, na mesma classe: o cartao do canto e esta
## pagina sao dois recortes do Mapa, com escala e estilo diferentes. Duas
## implementacoes divergiriam no primeiro ajuste, e o jogador veria a loja num
## lugar no canto da tela e noutro no menu.
func _montar_mapa() -> void:
	_no_mapa = Control.new()
	_no_mapa.set_anchors_preset(Control.PRESET_FULL_RECT)
	_no_mapa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_no_mapa)

	_imagem(_no_mapa, "ui_papel", Vector2(20.0, 14.0), Vector2(440.0, 242.0),
		TextureRect.STRETCH_TILE).modulate = PAPEL
	_rotulo(_no_mapa, "MAPA DA CIDADE", Vector2(20.0, 20.0), Vector2(440.0, 22.0),
		FONTE_T, TINTA, HORIZONTAL_ALIGNMENT_CENTER)
	_cabecalho = _rotulo(_no_mapa, "", Vector2(20.0, 42.0), Vector2(440.0, 14.0),
		FONTE_P, TINTA_FRACA, HORIZONTAL_ALIGNMENT_CENTER)

	# Sombra e moldura da janela do mapa. A pagina inteira e papel; sem a moldura
	# o mapa nao le como um desenho colado nela, le como o fundo.
	var sombra := ColorRect.new()
	sombra.color = Color(0.16, 0.11, 0.07, 0.35)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_no_mapa.add_child(sombra)
	sombra.position = MAPA_CAIXA.position + Vector2(2.0, 2.0)
	sombra.size = MAPA_CAIXA.size

	_mapa = Mapa.new()
	_mapa.estilo = Mapa.Estilo.PAGINA
	_mapa.metros_por_pixel = ESCALAS[_escala_atual]
	_no_mapa.add_child(_mapa)
	_mapa.position = MAPA_CAIXA.position
	_mapa.size = MAPA_CAIXA.size

	_montar_legenda()

	# Escala e ajuda na mesma linha, uma em cada ponta. Em duas linhas elas
	# encostavam uma na outra na base da pagina.
	_escala = _rotulo(_no_mapa, "", Vector2(MAPA_CAIXA.position.x, 236.0),
		Vector2(MAPA_CAIXA.size.x * 0.6, 12.0), FONTE_P, TINTA_FRACA)
	_rotulo(_no_mapa, "[A/D] escala   [ESC] voltar",
		Vector2(MAPA_CAIXA.position.x, 236.0),
		Vector2(MAPA_CAIXA.size.x + 96.0, 12.0), FONTE_P, TINTA_FRACA,
		HORIZONTAL_ALIGNMENT_RIGHT)


## Legenda. Sem ela o mapa e um borrao bege com manchas: a fita escura em volta
## da quadra so vira "predio" depois que alguem diz que e.
func _montar_legenda() -> void:
	var x := MAPA_CAIXA.end.x + 10.0
	var y := MAPA_CAIXA.position.y + 2.0

	for par: Array in [[PREDIO_COR, "PREDIOS"], [PATIO_COR, "PATIO"],
			[PARQUE_COR, "PARQUE"], [BALDIO_COR, "TERRENO"]]:
		var amostra := ColorRect.new()
		amostra.color = par[0]
		amostra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_no_mapa.add_child(amostra)
		amostra.position = Vector2(x, y + 3.0)
		amostra.size = Vector2(9.0, 8.0)
		_rotulo(_no_mapa, par[1], Vector2(x + 14.0, y), Vector2(84.0, 12.0),
			FONTE_P, TINTA)
		y += 15.0

	y += 7.0
	for par: Array in [["mercado", "MERCADO"], ["casa", "CASA"],
			["casa_verde", "CASA DA FUMACA"], ["predio", "ENTRADA"],
			["parque", "PARQUE"], ["telefone", "TELEFONE"]]:
		var ic := TextureRect.new()
		var caminho := "res://assets/ui/icone_%s.png" % par[0]
		if ResourceLoader.exists(caminho):
			ic.texture = load(caminho)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_no_mapa.add_child(ic)
		ic.position = Vector2(x - 1.0, y)
		ic.size = Vector2(12.0, 12.0)
		_rotulo(_no_mapa, par[1], Vector2(x + 14.0, y), Vector2(84.0, 12.0),
			FONTE_P, TINTA)
		y += 16.0


## Centra o mapa no jogador e refaz cabecalho e escala.
func _centrar_mapa() -> void:
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	var pos := Vector3.ZERO
	var rumo := 0.0
	if jogador != null:
		pos = jogador.global_position
		rumo = jogador.rotation.y
	_mapa.metros_por_pixel = ESCALAS[_escala_atual]
	_mapa.centro = pos
	_mapa.rumo = rumo
	_mapa.forcar_redesenho()

	_cabecalho.text = "%s    QUADRA %d-%d" % [_mapa.onde_estou(),
		floori(pos.x / Mapa.TAM), floori(pos.z / Mapa.TAM)]
	# Barra de escala em metros redondos. Um mapa sem escala nao diz se a proxima
	# avenida esta a cem metros ou a mil.
	var largura_m := MAPA_CAIXA.size.x * ESCALAS[_escala_atual]
	_escala.text = "LARGURA %d m   VISTO %d" % [int(largura_m),
		WorldState.chunks_visitados()]


## So a captura usa: numa foto o jogador nunca andou, e o mapa sairia coberto
## pela vela do que nao foi visitado.
func revelar_mapa() -> void:
	_mapa.revelar_tudo = true
	_mapa.forcar_redesenho()


func _navegar_mapa(evento: InputEvent) -> void:
	if evento.is_action_pressed("mover_dir"):
		_escala_atual = mini(_escala_atual + 1, ESCALAS.size() - 1)
	elif evento.is_action_pressed("mover_esq"):
		_escala_atual = maxi(_escala_atual - 1, 0)
	elif evento.is_action_pressed("pausa") or evento.is_action_pressed("interagir"):
		mostrar(Painel.TITULO)
		get_viewport().set_input_as_handled()
		return
	else:
		return
	AudioDirector.tocar_ui(&"clique", -16.0)
	_centrar_mapa()
	get_viewport().set_input_as_handled()


# --- estado -----------------------------------------------------------------

func mostrar(qual: Painel) -> void:
	painel = qual
	_selecionado = 0
	_no_titulo.visible = qual == Painel.TITULO
	_no_opcoes.visible = qual == Painel.OPCOES
	_no_mapa.visible = qual == Painel.MAPA
	_no_nome.visible = qual == Painel.NOME
	_criacao.visible = qual == Painel.APARENCIA
	_criacao.set_process(qual == Painel.APARENCIA)
	if qual == Painel.MAPA:
		_centrar_mapa()
	if qual == Painel.NOME:
		_nome_digitado = ""
		_atualizar_campo()
	if qual == Painel.APARENCIA:
		_criacao.abrir()
	set_process(qual == Painel.NOME)
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_atualizar()


func esconder() -> void:
	visible = false
	# O painel de aparencia sai junto, explicitamente. Ele tem um SubViewport 3D
	# que so para de renderizar quando o Control fica invisivel, e esconder a
	# CanvasLayer nao muda a visibilidade dos Controls dentro dela.
	if _criacao != null:
		_criacao.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _atualizar() -> void:
	for i in _itens_titulo.size():
		var ativo := painel == Painel.TITULO and i == _selecionado
		_itens_titulo[i].add_theme_color_override(&"font_color",
			DESTAQUE if ativo else TINTA)
		# A aba selecionada afunda um pixel e escurece, igual a aba USAR da
		# prancha quando e acionada. E o unico retorno de foco que o vocabulario
		# de papel aceita: moldura de selecao aqui seria interface de sistema.
		if i < _abas_titulo.size():
			_abas_titulo[i].modulate = (Color(1.02, 0.98, 0.92) if ativo
				else Color(0.88, 0.85, 0.79))
			_abas_titulo[i].scale = Vector2(1.04, 1.04) if ativo else Vector2.ONE
	if _itens_titulo.size() > 0:
		_itens_titulo[0].add_theme_color_override(&"font_color",
			DESTAQUE if painel == Painel.TITULO and _selecionado == 0 else
			(TINTA if SaveGame.existe(0) else TINTA_FRACA))

	for i in _opcoes.size():
		var ativo := painel == Painel.OPCOES and i == _selecionado
		var ler: Callable = _opcoes[i]["ler"]
		_itens_opcoes[i].text = ("> " if ativo else "") + str(ler.call())
		_itens_opcoes[i].add_theme_color_override(&"font_color",
			DESTAQUE if ativo else TINTA_FRACA)


func _unhandled_input(evento: InputEvent) -> void:
	if not visible:
		return

	if painel == Painel.MAPA:
		_navegar_mapa(evento)
		return

	if painel == Painel.NOME:
		_digitar(evento)
		return

	if painel == Painel.APARENCIA:
		_criacao.navegar(evento)
		get_viewport().set_input_as_handled()
		return

	var n := _itens_titulo.size() if painel == Painel.TITULO else _opcoes.size()

	if evento.is_action_pressed("mover_tras"):
		_selecionado = posmod(_selecionado + 1, n)
		AudioDirector.tocar_ui(&"clique", -14.0)
		_atualizar()
	elif evento.is_action_pressed("mover_frente"):
		_selecionado = posmod(_selecionado - 1, n)
		AudioDirector.tocar_ui(&"clique", -14.0)
		_atualizar()
	elif painel == Painel.OPCOES and evento.is_action_pressed("mover_dir"):
		_ajustar(1)
	elif painel == Painel.OPCOES and evento.is_action_pressed("mover_esq"):
		_ajustar(-1)
	elif evento.is_action_pressed("interagir"):
		_acionar()
	elif evento.is_action_pressed("pausa") and painel == Painel.OPCOES:
		mostrar(Painel.TITULO)
	else:
		return
	get_viewport().set_input_as_handled()


## Cursor piscando na linha. Sem ele o campo vazio nao parece esperar nada.
func _process(delta: float) -> void:
	_piscar_cursor += delta
	_atualizar_campo()


func _atualizar_campo() -> void:
	var cursor := "_" if fmod(_piscar_cursor, 0.9) < 0.5 else " "
	_campo_nome.text = _nome_digitado + (cursor if _nome_digitado.length() < 12 else "")


const MAX_NOME := 12


func _digitar(evento: InputEvent) -> void:
	var tecla := evento as InputEventKey
	if tecla != null and tecla.pressed and not tecla.echo:
		if tecla.keycode == KEY_BACKSPACE:
			_nome_digitado = _nome_digitado.substr(0,
				maxi(0, _nome_digitado.length() - 1))
			AudioDirector.tocar_ui(&"clique", -18.0)
			_atualizar_campo()
			get_viewport().set_input_as_handled()
			return
		if tecla.keycode == KEY_ENTER or tecla.keycode == KEY_KP_ENTER:
			_assinar()
			get_viewport().set_input_as_handled()
			return
		# So letras e espaco. Numero e sinal no nome de uma ficha de cadastro
		# quebrariam o unico campo que o jogador escreve.
		var letra := tecla.keycode
		var e_letra := letra >= KEY_A and letra <= KEY_Z
		if (e_letra or letra == KEY_SPACE) and _nome_digitado.length() < MAX_NOME:
			_nome_digitado += " " if letra == KEY_SPACE else char(letra)
			AudioDirector.tocar_ui(&"clique", -20.0)
			_atualizar_campo()
			get_viewport().set_input_as_handled()
			return

	if evento.is_action_pressed("pausa"):
		mostrar(Painel.TITULO)
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("interagir"):
		_assinar()
		get_viewport().set_input_as_handled()


func _assinar() -> void:
	# Nome vazio e valido: o registro sorteia um. Obrigar a digitar so para poder
	# comecar e pedagio, e o proprio painel ja disse que quase tudo e sorteado.
	#
	# A ficha nasce AQUI, e nao no fim: a tela seguinte mostra o retrato, o nome
	# e o CPF da pessoa que o registro acabou de emitir, e precisa dela pronta.
	AudioDirector.tocar_ui(&"pegar", -8.0)
	RegistroCivil.criar_jogador(_nome_digitado.strip_edges())
	mostrar(Painel.APARENCIA)


func _ajustar(passo: int) -> void:
	var aplicar: Callable = _opcoes[_selecionado]["aplicar"]
	aplicar.call(passo)
	AudioDirector.tocar_ui(&"clique", -16.0)
	_atualizar()


func _acionar() -> void:
	AudioDirector.tocar_ui(&"pegar", -10.0)
	if painel == Painel.OPCOES:
		_ajustar(1)
		return

	match _selecionado:
		0:
			if SaveGame.existe(0) and SaveGame.carregar(0):
				esconder()
				continuar.emit()
		1:
			mostrar(Painel.NOME)
		2:
			mostrar(Painel.MAPA)
		3:
			mostrar(Painel.OPCOES)
		_:
			sair.emit()
			get_tree().quit(0)
