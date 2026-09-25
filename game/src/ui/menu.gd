## Menu de jogo (pos-boot CRT) e de opcoes.
##
## Depois da abertura CRT -> TV da Casa da Fumaca, o titulo e a cidade viva em
## preto-e-branco sob estatica de tubo — nao scrapbook. Opcoes, mapa e ficha
## continuam no vocabulario da prancha; ESC no jogo abre a prancha, nao isto.
##
## O menu de opcoes cumpre o que a Fase 2 prometeu: os tres niveis de nevoa e os
## quatro ajustes de pos-processamento, gravados em disco.
class_name Menu
extends CanvasLayer

const UI := "res://assets/ui/%s.png"
## Papel do rotulo RE7 (nao path de .fnt). Ver `_rotulo`.
enum TipoRotulo { TITLE, BODY, MICRO }
## Serif TTF da referencia CRT (tall/narrow via FontVariation).
const FONTE_SERIF_TITULO := "res://assets/fontes/serif_titulo.ttf"
const FONTE_SERIF_CORPO := "res://assets/fontes/serif_corpo.ttf"
## Alias P0 H: altura linha RE7 body (ex-psx_pequena 11). Compat run_tests.gd.
const FONTE_P_ALTURA := float(UiEstilo.RE7_SIZE_BODY)
const BOOT_PLATE := "res://assets/ui/ui_boot_plate.png"

const TELA := Vector2(480.0, 270.0)
const TINTA := Color("2a1f16")
const TINTA_FRACA := Color("5a4a38")
const DESTAQUE := Color("8a2f1f")
## Oxblood da referencia CRT. Facil de trocar se o titulo mudar de nome.
const TITULO_TEXTO := "SHIMOKAWA"
const TITULO_COR := Color("7a141c")

## Corpo, lugar e caixa do titulo da tela de abertura. Os TRES sao compartilhados
## entre o halo e a letra de propaganda: ver `_montar_boot`. Nao duplique estes
## valores — duas caixas quase iguais foi exatamente o defeito que batia o titulo.
## Largura e cor das duas marcas que emolduram o item escolhido. Ver
## `_placa_de_item`. Sao a unica coisa vermelha do menu que continua vermelha:
## o TEXTO do escolhido passou a ser o mais claro da lista, nao o mais escuro.
## As tres luminancias da lista do menu, em ordem obrigatoria:
##
##     ITEM_MORTO  <  ITEM_NORMAL  <  ITEM_ESCOLHIDO
##
## A ordem e o ponto, e ela ja esteve invertida. O item sob o cursor era pintado
## com TITULO_COR — vermelho escuro, luminancia perto de 0,1 — contra 0,9 dos
## outros: sobre a cidade noturna que corre atras do menu, o escolhido era a
## coisa MENOS visivel da tela. Ha um teste que trava esta ordem, porque o
## defeito nao aparece em revisao de codigo: ler `TITULO_COR if ativo` parece
## certo ate alguem comparar as duas luminancias.
const ITEM_MORTO := Color(0.42, 0.39, 0.36)
## A cor da nota que explica o item escolhido.
##
## Ela nasceu em `ITEM_MORTO`, pela ideia de que uma linha de apoio deve sumir
## perto da lista. Medido na captura: 15 niveis de contraste contra o fundo —
## mancha, e nao texto. A nota nao e enfeite de item apagado, e a RESPOSTA que
## faltava quando o jogador apertava E e a tela nao dizia nada; resposta ilegivel
## e o mesmo silencio com mais trabalho. Sobe para o valor dos itens vivos.
const NOTA_COR := Color(0.74, 0.72, 0.68)
const ITEM_NORMAL := Color(0.74, 0.72, 0.68)
const ITEM_ESCOLHIDO := Color(0.98, 0.96, 0.92)

## Geometria da lista de opcoes. Ver `_montar_opcoes`.
##
## `OPCOES_CREME_BASE` foi MEDIDO na captura, e nao lido do retangulo do papel:
## `ui_papel` tem moldura, e o creme onde da para escrever acaba dez pixels antes
## da borda da imagem. Medir o retangulo era o erro que cortava a ultima linha.
const OPCOES_Y0 := 58.0
const OPCOES_PASSO_MAX := 13.5
const OPCOES_CREME_BASE := 228.4
const MARCA_LARGURA := 2.0
const MARCA_COR := Color("9c1f28")

## As medidas de layout desta tela moram em `TituloLayout`.
##
## Nao por organizacao: por alcance. A regra de empilhamento precisa ser
## mensuravel por `tests/checar_hud.gd`, e o teste roda sem SceneTree e sem
## autoload — este arquivo fala com quatro deles e monta um SubViewport com a
## Estrada Velha inteira. Os apelidos abaixo existem para o resto do arquivo
## continuar legivel; o valor e um so, e mora la.
const BOOT_TITULO_CORPO := TituloLayout.TITULO_CORPO
const BOOT_TITULO_ONDE := TituloLayout.TITULO_ONDE_BOOT
const BOOT_TITULO_CAIXA := TituloLayout.TITULO_CAIXA
const TITULO_ONDE_MENU := TituloLayout.TITULO_ONDE_MENU

const PROMPT_BOOT := "APERTA START PARA JOGAR"
const RODAPE_BOOT := "(c) 2026 tequila (direitos)"
const SHADER_CRT := "res://shaders/crt_overlay.gdshader"
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

enum Painel { BOOT, TITULO, CARREGAR, OPCOES, MAPA, NOME, APARENCIA }

signal jogar(nome: String)
signal continuar()
signal sair()
signal boot_iniciar()

var painel: Painel = Painel.TITULO
var _selecionado: int = 0

var _raiz: Control
var _itens_titulo: Array[Label] = []
var _abas_titulo: Array[Control] = []
## As duas marcas vermelhas de cada item. Ficam separadas da placa porque a placa
## vale para os CINCO — ela e o fundo que torna a lista legivel sobre a cidade em
## movimento — e a marca vale para UM, que e o escolhido. Ver `_placa_de_item`.
var _marcas_titulo: Array[Control] = []
## O realce do item escolhido, um por linha. Ver `_placa_de_item`.
var _realces_titulo: Array[Control] = []
## O halo do titulo da tela de menu. Anda junto com a letra, sempre.
var _titulo_glow: Label
var _itens_opcoes: Array[Label] = []
## Os rotulos da esquerda. Eram anonimos — criados e esquecidos — e agora a
## pagina precisa reescreve-los a cada troca.
var _rotulos_opcoes: Array[Label] = []
var _titulo_opcoes: Label
var _no_titulo: Control
## A pagina dos tres espacos de save. Ver `_montar_carregar`.
var _no_carregar: Control
var _abas_espacos: Array[Control] = []
var _marcas_espacos: Array[Control] = []
var _realces_espacos: Array[Control] = []
var _itens_espacos: Array[Label] = []
var _nota_espacos: Label
## Painel RE7 de cards de save no titulo (substitui a lista legado ESPACOS).
var _save_panel: SaveCardsPanelRe7
var _audio_save_pushed: bool = false
## A linha que explica o item escolhido. Ver `_texto_da_nota`.
var _nota_titulo: Label
## O menu ja estava visivel quando o painel trocou. Decide se a entrada do
## titulo passa pela cortina preta ou nao.
var _menu_estava_na_tela: bool = false
var _no_opcoes: Control
var _no_mapa: Control
var _no_nome: FichaCadastro
var _criacao: CriacaoAparencia
var _nome_digitado: String = ""
var _mapa: Mapa
var _cabecalho: Label
var _escala: Label

## Fundo da abertura: veu escuro + letterbox, a cidade 3D aparece por tras.
var _fundo_veu: ColorRect
var _fundo_colagem: TextureRect
var _barra_topo: ColorRect
var _barra_base: ColorRect
var _fade_preto: ColorRect
var _titulo_rotulo: Label
var _subtitulo_rotulo: Label
var _dica_titulo: Label
var _tempo_titulo: float = 0.0
var _animando_titulo: bool = false

## Overlay CRT (boot cheio + menu B&W). Shader proprio, nao o post 3D.
var _crt: ColorRect
var _crt_mat: ShaderMaterial
var _no_boot: Control
var _boot_plate: TextureRect
var _boot_titulo: Label
var _boot_titulo_glow: Label
var _boot_prompt: Label
var _boot_rodape: Label
var _boot_pronto: bool = false
var _fonte_boot_titulo: Font
var _fonte_boot_corpo: Font
var _transicionando: bool = false
var _vinheta_ui: TextureRect
## Verdadeiro quando o nivel montou uma cena 3D viva atras do boot. Ver
## `usar_fundo_vivo`.
var _fundo_vivo: bool = false
## A Estrada Velha atras do boot e do titulo. Ver `_montar_fundo_mata`.
var _fundo_mata: TextureRect
## Relogio dos grilos. Eles nao sao um loop: `grilo.wav` tem 0,18 s e e uma
## cricrilada so, entao o que soa como mata e ele disparado em intervalo
## irregular — um loop de 0,18 s vira um bipe.
var _proximo_grilo: float = 0.0

## Escalas do mapa da pagina, em metros por pixel. A janela tem 300 px, entao
## isto cobre de 600 m, onde da para ler a fita de predios de cada quadra, a
## 2400 m, onde o que se le e o desenho das avenidas.
const ESCALAS: Array[float] = [2.0, 3.2, 5.0, 8.0]
var _escala_atual: int = 1

## Cada opcao e {rotulo, ler: Callable, aplicar: Callable(int passo)}
var _opcoes: Array[Dictionary] = []


func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	_definir_opcoes()
	_montar()
	# O menu OBEDECE o preset de imagem, e ate hoje era a unica tela que nao
	# obedecia. Ver `_dose_psx`: mudar ESTILO na lista de opcoes tem de mudar a
	# tela em que a lista esta aberta, senao o jogador ajusta imagem no escuro.
	Settings.changed.connect(_ao_mudar_imagem)
	# Cidade decide se abre o titulo (primeira vez) ou esconde (testes/captura).
	visible = false


## O preset de imagem mudou: resolucao do fundo e dose do tubo acompanham.
func _ao_mudar_imagem() -> void:
	_ajustar_resolucao_mata()
	if painel == Painel.BOOT:
		_aplicar_crt_boot()
	elif painel == Painel.TITULO:
		_aplicar_crt_menu()


# --- definicao das opcoes ---------------------------------------------------

## A folha de OPCOES tem DUAS paginas, e a medida foi quem decidiu isso.
##
## Ela tinha treze linhas numa folha cujo creme mede 185 px. Com a altura de
## linha real da fonte (13 px), o passo caia para 13,03 — tres centesimos de
## pixel de ar entre uma linha e a seguinte. O arquivo ja registrava duas
## tentativas de conserto pelo passo ("a decima terceira linha caiu 19 px fora do
## papel"; "VOLTAR entrou 2,6 px na moldura"), e as duas trataram o sintoma: a
## folha estava acima da capacidade desde que o som entrou nela.
##
## A saida nao e apertar mais, e tambem nao e duas colunas — medido, a coluna de
## valor sozinha precisa de 125 px para "> NEBLINA COM CHUVA", e duas delas nao
## cabem nos 384 px do papel. E paginar, que e exatamente o que o menu de sistema
## em jogo ja faz com as MESMAS listas (`menu_sistema.gd`, paginas IMAGEM e SOM).
## Reusar a decisao que ja existe e mais barato do que inventar a segunda.
##
## Com dez linhas na pagina de imagem, o passo sobe para 16 px: tres pixels de ar
## em vez de tres centesimos.
enum PaginaOpcoes { IMAGEM, SOM, HUD, HUD_EXIBICAO, HUD_PECAS, LEGENDAS }

var _opcoes_pagina: PaginaOpcoes = PaginaOpcoes.IMAGEM
var _opcoes_imagem: Array[Dictionary] = []
var _opcoes_som: Array[Dictionary] = []
## As tres paginas do HUD, as mesmas do menu de sistema em jogo (`HudConfig`).
var _opcoes_hud: Array[Dictionary] = []
var _opcoes_hud_exibicao: Array[Dictionary] = []
var _opcoes_hud_pecas: Array[Dictionary] = []
var _opcoes_legendas: Array[Dictionary] = []


func _definir_opcoes() -> void:
	# As listas vem de `OpcoesLista`, que o menu de sistema em jogo tambem le.
	# Duas copias divergiriam no primeiro ajuste, e o jogador veria um painel com
	# sete opcoes e outro com seis, os dois dizendo que sao as opcoes do jogo.
	_opcoes_imagem = OpcoesLista.video()
	_opcoes_imagem.append(_linha_de_pagina("SOM  >", PaginaOpcoes.SOM))
	_opcoes_imagem.append(_linha_de_voltar())

	_opcoes_som = OpcoesLista.audio()
	_opcoes_som.append(_linha_de_pagina("HUD  >", PaginaOpcoes.HUD))
	_opcoes_som.append(_linha_de_pagina("<  IMAGEM", PaginaOpcoes.IMAGEM))
	_opcoes_som.append(_linha_de_voltar())

	_opcoes_hud = OpcoesLista.hud()
	_opcoes_hud.append(_linha_de_pagina("EXIBICAO  >", PaginaOpcoes.HUD_EXIBICAO))
	_opcoes_hud.append(_linha_de_pagina("PECAS DO HUD  >", PaginaOpcoes.HUD_PECAS))
	_opcoes_hud.append(_linha_de_pagina("LEGENDAS  >", PaginaOpcoes.LEGENDAS))
	_opcoes_hud.append(_linha_de_pagina("<  SOM", PaginaOpcoes.SOM))
	_opcoes_hud.append(_linha_de_voltar())

	_opcoes_hud_exibicao = OpcoesLista.hud_exibicao()
	_opcoes_hud_exibicao.append(_linha_de_pagina("<  HUD", PaginaOpcoes.HUD))
	_opcoes_hud_exibicao.append(_linha_de_voltar())

	_opcoes_hud_pecas = OpcoesLista.hud_pecas()
	_opcoes_hud_pecas.append(_linha_de_pagina("<  HUD", PaginaOpcoes.HUD))
	_opcoes_hud_pecas.append(_linha_de_voltar())

	_opcoes_legendas = OpcoesLista.legendas()
	_opcoes_legendas.append(_linha_de_pagina("<  HUD", PaginaOpcoes.HUD))
	_opcoes_legendas.append(_linha_de_voltar())

	_opcoes = _opcoes_imagem


## A linha que troca de pagina. E uma linha da lista, e nao uma aba nova, porque
## a folha ja navega com W/S — uma aba pediria outra tecla para decorar.
func _linha_de_pagina(rotulo: String, alvo: PaginaOpcoes) -> Dictionary:
	return {
		"rotulo": rotulo,
		"ler": func() -> String: return "",
		"aplicar": func(_passo: int) -> void: _ir_para_pagina(alvo),
	}


func _linha_de_voltar() -> Dictionary:
	return {
		"rotulo": "VOLTAR",
		"ler": func() -> String: return "",
		"aplicar": func(_passo: int) -> void: mostrar(Painel.TITULO),
	}


## Abre a pagina de som direto. So a captura usa; o jogador chega por "SOM >".
func abrir_pagina_som() -> void:
	_ir_para_pagina(PaginaOpcoes.SOM)


## Abre a pagina do HUD direto. So a captura usa; o jogador chega por "HUD >".
func abrir_pagina_hud() -> void:
	_ir_para_pagina(PaginaOpcoes.HUD)


func _ir_para_pagina(qual: PaginaOpcoes) -> void:
	_opcoes_pagina = qual
	match qual:
		PaginaOpcoes.IMAGEM: _opcoes = _opcoes_imagem
		PaginaOpcoes.SOM: _opcoes = _opcoes_som
		PaginaOpcoes.HUD: _opcoes = _opcoes_hud
		PaginaOpcoes.HUD_EXIBICAO: _opcoes = _opcoes_hud_exibicao
		PaginaOpcoes.HUD_PECAS: _opcoes = _opcoes_hud_pecas
		PaginaOpcoes.LEGENDAS: _opcoes = _opcoes_legendas
	_selecionado = 0
	_dispor_opcoes()
	_atualizar()


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
		tipo: int = TipoRotulo.BODY, cor: Color = TINTA,
		alinhamento: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_color_override(&"font_color", cor)
	l.horizontal_alignment = alinhamento
	# Titulo/opcoes/mapa/dicas: RE7 por papel (CHECKLIST_TOKENS).
	match tipo:
		TipoRotulo.TITLE:
			UiEstilo.aplicar_re7_title(l)
		TipoRotulo.BODY:
			UiEstilo.aplicar_re7_body(l)
		TipoRotulo.MICRO:
			UiEstilo.aplicar_re7_micro(l)
		_:
			UiEstilo.aplicar_re7_body(l)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(l)
	l.position = pos
	l.size = tamanho
	return l


func _montar() -> void:
	_raiz = Control.new()
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	# Tamanho na mao, e SEM ancora.
	#
	# `CanvasLayer` nao e um Control: ela nao tem retangulo e nao propaga
	# nenhum. Ancorar em PRESET_FULL_RECT dentro dela ancora contra um pai de
	# tamanho zero, e o `_raiz` nasce zero por zero — junto com todo painel que
	# ancorar nele depois.
	#
	# O defeito que isso causa e traicoeiro porque METADE continua funcionando:
	# `draw_*` usa coordenada absoluta e nao liga para o tamanho do Control,
	# entao os paineis desenham perfeitos. Quem depende do retangulo e o MOUSE —
	# um Control de area zero nao recebe clique nenhum. E foi assim que a
	# carteira passou a existencia inteira com "[clique] abas/opcoes" escrito no
	# rodape e nenhum clique respondendo.
	#
	# A ancora saiu junto, e por isso o motor parou de avisar. `PRESET_FULL_RECT`
	# mais `size` e contradicao: o Godot imprime "Nodes with non-equal opposite
	# anchors will have their size overridden after _ready()" e devolve o
	# retangulo do pai — que aqui e zero. Quem manda e o `size`; a ancora so
	# enchia o log de toda execucao do jogo com um aviso verdadeiro.
	_raiz.size = TELA

	# Veu escuro semi-transparente: a cidade 3D (nevoa, chuva, postes) respira
	# atras. Colagem so entra nos paineis de papel, onde o texto precisa de mesa.
	_fundo_veu = ColorRect.new()
	_fundo_veu.color = Color(0.02, 0.03, 0.04, 0.28)
	_fundo_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_fundo_veu)
	_fundo_veu.position = Vector2.ZERO
	_fundo_veu.size = TELA

	_fundo_colagem = _imagem(_raiz, "ui_colagem", Vector2.ZERO, TELA)
	_fundo_colagem.modulate = Color(0.78, 0.75, 0.7)
	_fundo_colagem.visible = false

	_barra_topo = ColorRect.new()
	_barra_topo.color = Color(0.01, 0.01, 0.015, 0.92)
	_barra_topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_barra_topo)
	_barra_topo.position = Vector2.ZERO
	_barra_topo.size = Vector2(TELA.x, 28.0)

	_barra_base = ColorRect.new()
	_barra_base.color = Color(0.01, 0.01, 0.015, 0.92)
	_barra_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_barra_base)
	_barra_base.position = Vector2(0.0, TELA.y - 28.0)
	_barra_base.size = Vector2(TELA.x, 28.0)

	_montar_fundo_mata()
	_montar_crt()
	_montar_boot()
	_montar_titulo()
	_montar_carregar()
	_montar_opcoes()
	_montar_mapa()
	_montar_nome()
	_montar_aparencia()

	_vinheta_ui = _imagem(_raiz, "ui_vinheta", Vector2.ZERO, TELA)
	_vinheta_ui.visible = false

	_fade_preto = ColorRect.new()
	_fade_preto.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade_preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_fade_preto)
	_fade_preto.position = Vector2.ZERO
	_fade_preto.size = TELA
	_fade_preto.visible = false


## A mata de Minas atras do boot e do titulo.
##
## O que se ve
## -----------
## A Estrada Velha de verdade: serra escura no fundo, mata fechando dos dois
## lados, o asfalto sumindo na nevoa e o carro parado no acostamento. E a mesma
## cena que a ficha e a criacao de personagem usam de fundo — `CabineFundo
## Criacao` monta `EstradaBuilder`, `CarroCena` e `CeuEstrada` num mundo proprio
## — so que com a lente do menu em vez da lente da carteira.
##
## Por que nao e a cidade
## ----------------------
## Porque a cidade e o que vem DEPOIS. O menu abre no mesmo lugar em que a
## partida comeca: a estrada de mata a noite, que e o primeiro plano do jogo. O
## som ja dizia isso antes da imagem — `_ambiente_da_estrada` liga folhas e vento
## e abaixa o zumbido urbano desde sempre, e a tela mostrava outro lugar.
##
## Por que o menu tem a PROPRIA instancia da cena
## ----------------------------------------------
## Porque a da criacao de personagem nao serve emprestada, e isso custou tres
## capturas para ficar claro. Aquele `SubViewport` e filho do painel da carteira,
## e um `SubViewport` filho de um `Control` invisivel PARA de renderizar — o
## proprio `esconder()` deste arquivo ja documentava o mesmo comportamento no
## sentido contrario. Usar o dela exigia manter o painel da carteira visivel e
## transparente durante o titulo inteiro, com o mouse e o `_process` desligados
## na mao, e ainda trocar a lente dela de ida e de volta sem errar nenhum
## caminho de saida. Uma instancia propria custa uma montagem de estrada e nao
## tem nenhum desses fios.
const MATA_CENA := "res://scenes/player/cabine_fundo_criacao.tscn"
## Humor da noite forcado. Vazio deixa a cena sortear, que e o caso do jogo; a
## captura preenche para sair igual duas vezes.
var noite_forcada: StringName = &""

var _mata_vp: SubViewport
var _mata_cena: CabineFundoCriacao
## Onde a lente da estrada esta, de 0 (plano largo do boot) a 1 (junto do carro).
##
## O estado mora AQUI e nao na cena: `avancar_menu` e funcao pura da pose do
## carro, e quem sabe em que ponto do fluxo a tela esta e o menu. Sem esta
## variavel, todo `_aplicar_fundo` — que roda ao abrir qualquer painel — mandava
## a camera de volta para o plano largo e desfazia o travelling do START no
## primeiro quadro do titulo.
var _lente_titulo: float = 0.0
## Veu em gradiente sobre a mata. Ver `_montar_scrim`.
var _scrim: TextureRect


func _montar_fundo_mata() -> void:
	_fundo_mata = TextureRect.new()
	_fundo_mata.name = "FundoMata"
	_fundo_mata.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo_mata.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fundo_mata.stretch_mode = TextureRect.STRETCH_SCALE
	# Linear, e nao nearest: a textura vem de um SubViewport do mesmo tamanho da
	# tela, mas o alvo final e reescalonado pela janela, e nearest num
	# reescalonamento nao inteiro serrilha a linha do horizonte.
	_fundo_mata.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_raiz.add_child(_fundo_mata)
	_fundo_mata.position = Vector2.ZERO
	_fundo_mata.size = TELA
	_fundo_mata.visible = false

	_montar_scrim()


## Monta a cena da estrada, uma vez, na primeira vez que alguem pedir.
##
## Preguicosa de proposito. Ela monta `EstradaBuilder`, `CarroCena` e `CeuEstrada`
## — uma estrada inteira com mata e serra — e montar isso no `_ready` do menu
## cobraria o preco em TODA carga da cidade: nas partidas que entram direto pelo
## `--pular-menu`, em cada `--teste-*` e em cada captura automatizada, para uma
## cena que a maioria delas nunca mostra.
func _garantir_cena_mata() -> void:
	if _mata_vp != null or not ResourceLoader.exists(MATA_CENA):
		return
	var packed := load(MATA_CENA) as PackedScene
	if packed == null:
		return
	_mata_vp = SubViewport.new()
	_mata_vp.name = "FundoMataViewport"
	_mata_vp.size = _resolucao_do_fundo()
	_mata_vp.own_world_3d = true
	_mata_vp.transparent_bg = false
	_mata_vp.msaa_3d = Viewport.MSAA_DISABLED
	# Desligado ate alguem pedir: um SubViewport nao para de desenhar so porque
	# ninguem esta olhando, e este monta estrada, mata e serra.
	_mata_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# O menu pausa a arvore nos paineis de papel; a cena continua viva.
	_mata_vp.process_mode = Node.PROCESS_MODE_ALWAYS
	# Filho da CanvasLayer, e nao de um Control: assim a renderizacao dele nao
	# depende de nenhuma visibilidade de painel.
	add_child(_mata_vp)
	var cena := packed.instantiate()
	cena.process_mode = Node.PROCESS_MODE_ALWAYS
	_mata_cena = cena as CabineFundoCriacao
	if _mata_cena != null and noite_forcada != &"":
		# Antes de entrar na arvore: `_ready` da cena e quem sorteia, e sortear
		# por cima de uma escolha e o mesmo que ignorar a escolha.
		_mata_cena.noite_id = noite_forcada
	_mata_vp.add_child(cena)
	if _fundo_mata != null:
		_fundo_mata.texture = _mata_vp.get_texture()


## Veu em gradiente por cima da mata, escuro em cima e embaixo.
##
## Medido na captura do titulo: o fundo na faixa do texto tem mediana 20, ou
## seja quase preto, e so 3% dos pixels passam de 140 — o menu inteiro le bem.
## O problema e onde estao esses 3%: em cima, na copa clara e no pedaco de ceu,
## exatamente onde o titulo em oxblood pousa.
##
## Entao o veu nao e chapado. Chapado, ele apagaria a mata para resolver uma
## faixa: escurece o terco de cima e o de baixo, onde moram o titulo e a linha
## de teclas, e deixa o meio limpo, que e onde a estrada some na nevoa e onde a
## imagem tem o que mostrar.
func _montar_scrim() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.34, 0.72, 1.0])
	g.colors = PackedColorArray([
		Color(0.0, 0.0, 0.0, 0.62),
		Color(0.0, 0.0, 0.0, 0.0),
		Color(0.0, 0.0, 0.0, 0.0),
		Color(0.0, 0.0, 0.0, 0.55),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 4
	tex.height = int(TELA.y)
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)

	_scrim = TextureRect.new()
	_scrim.name = "ScrimMata"
	_scrim.texture = tex
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scrim.stretch_mode = TextureRect.STRETCH_SCALE
	_scrim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_raiz.add_child(_scrim)
	_scrim.position = Vector2.ZERO
	_scrim.size = TELA
	_scrim.visible = false


## Em que resolucao o fundo 3D do menu desenha.
##
## O achado
## --------
## Este `SubViewport` nasceu cravado em 480x270 — a caixa da INTERFACE, que e
## outra coisa. O jogo em MODERNO renderiza o 3D na resolucao da janela
## (`EstiloVisual._aplicar_resolucao` troca `content_scale_mode` justamente para
## isso), e o fundo do menu ficava de fora do acordo: numa janela de 1920x1080 a
## estrada era desenhada com 129.600 pixels e ampliada 4x com filtro linear. Era
## a unica tela do jogo que ignorava o preset escolhido, e era tambem a PRIMEIRA
## que o jogador ve — o menu abria pior do que o jogo que ele anuncia.
##
## Agora a caixa sai de `Settings.resolucao_3d`, que e o mesmo numero que a
## escada de RESOLUCAO 3D do painel de opcoes ajusta. PS1 STYLE continua em
## 480x270 porque e o que o preset PEDE, e nao porque ninguem escolheu.
##
## Custo: 1280x720 e 7,1x mais pixel que 480x270, num mundo proprio com estrada,
## mata e serra. Cabe porque a cena ja estava montada e so a superficie de
## render cresce — e porque ela so existe enquanto o menu esta aberto.
func _resolucao_do_fundo() -> Vector2i:
	var r := Settings.resolucao_3d
	if r.x < 2 or r.y < 2:
		return Vector2i(int(TELA.x), int(TELA.y))
	return r


## Redimensiona o fundo quando o jogador mexe na escada de resolucao com o menu
## aberto. Sem isto, o ajuste so apareceria na proxima vez que o jogo abrisse.
func _ajustar_resolucao_mata() -> void:
	if _mata_vp == null:
		return
	var alvo := _resolucao_do_fundo()
	if _mata_vp.size == alvo:
		return
	_mata_vp.size = alvo
	if _fundo_mata != null:
		# A textura do viewport e outra depois do redimensionamento; sem
		# reapontar, o `TextureRect` continua mostrando a antiga, congelada.
		_fundo_mata.texture = _mata_vp.get_texture()


## Quanto desta tela e "de epoca", de 0 (MODERNO) a 1 (PS1 STYLE).
##
## Por que nao e `Settings.estilo == PS1_STYLE`
## --------------------------------------------
## Porque o terceiro estado existe e e comum: basta o jogador mexer num
## deslizador para cair em PERSONALIZADO, e ai os dois testes de igualdade
## respondem "nao" e a tela teria de escolher um dos extremos no chute. Quem
## responde e a IMAGEM, nao o rotulo: dither, snap, UV afim e luz por vertice
## sao os quatro tracos que separam as duas familias, e a media deles diz onde a
## configuracao atual esta entre elas.
##
## Serve para dosar o vidro do tubo. Em MODERNO o CRT nao some — ele e a
## identidade da tela, e o proprio preset MODERNO ainda pede grao 0,02 e vinheta
## 0,18 — mas para de ser o assunto: medido na captura do boot, o grao de 0,66
## deixava a estrada com desvio de luminancia de fundo perto do de uma parede.
func _dose_psx() -> float:
	var votos := 0.0
	votos += 1.0 if Settings.dither else 0.0
	votos += 1.0 if Settings.snap else 0.0
	votos += 1.0 if Settings.affine else 0.0
	votos += 0.0 if Settings.luz_por_pixel else 1.0
	return votos / 4.0


## Ha cena de mata montada? Falso quer dizer que o menu vai deixar a cidade
## aparecer por tras, e quem monta a cidade precisa saber disso para enquadrar
## alguma coisa que preste.
func tem_fundo_mata() -> bool:
	# Responde pelo ARQUIVO, e nao pela instancia: quem pergunta e a cidade, no
	# mesmo quadro em que o menu abre, e a cena so e montada quando pedida.
	return ResourceLoader.exists(MATA_CENA)


## Liga a cena da estrada e mostra a textura dela no fundo.
func _ligar_fundo_mata(ligado: bool) -> void:
	if ligado:
		_garantir_cena_mata()
		_ajustar_resolucao_mata()
	if _fundo_mata == null or _mata_vp == null:
		return
	_mata_vp.render_target_update_mode = (SubViewport.UPDATE_ALWAYS
		if ligado else SubViewport.UPDATE_DISABLED)
	_fundo_mata.visible = ligado
	if _scrim != null:
		_scrim.visible = ligado
	if _mata_cena != null:
		if ligado:
			_mata_cena.enquadrar_menu(true)
			_mata_cena.avancar_menu(_lente_titulo)
		# Imagem e som saem JUNTOS. Desligar so o render deixava o chiado da
		# frequencia morta tocando atras do jogo inteiro — ver
		# `CabineFundoCriacao.silenciar`, que e onde o defeito esta descrito.
		_mata_cena.silenciar(not ligado)
	usar_fundo_vivo(ligado)


## Grilos. Disparados em intervalo irregular, e nao em loop.
func _grilos(delta: float) -> void:
	_proximo_grilo -= delta
	if _proximo_grilo > 0.0:
		return
	# Intervalo e afinacao sorteados: dois grilos identicos em cadencia fixa leem
	# como sinal de aparelho, e nao como mata.
	# A mata nao faz o mesmo barulho em toda noite. Na cerracao o grilo fica
	# esparso e abafado; na noite limpa ele toma conta. O ganho e o intervalo
	# saem do MESMO humor que decidiu a nevoa, senao a tela diz uma coisa e o
	# ouvido diz outra.
	var forca := 1.0
	if _mata_cena != null:
		forca = float(_mata_cena.noite()["grilo"])
	if forca <= 0.01:
		_proximo_grilo = 2.0
		return
	_proximo_grilo = randf_range(0.35, 1.6) / forca
	AudioDirector.tocar_ui(&"grilo",
		randf_range(-26.0, -19.0) - (1.0 - forca) * 8.0,
		randf_range(0.88, 1.14))


## Overlay CRT compartilhado. No BOOT e opaco; no TITULO vira veu B&W sobre a cidade.
func _montar_crt() -> void:
	# Copia o frame ja desenhado (cidade + post) para o CRT com scene_mix ler a rua.
	var bbc := BackBufferCopy.new()
	bbc.name = "CrtBackBuffer"
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_raiz.add_child(bbc)

	_crt = ColorRect.new()
	_crt.name = "CrtOverlay"
	_crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crt.position = Vector2.ZERO
	_crt.size = TELA
	var sh := load(SHADER_CRT) as Shader
	_crt_mat = ShaderMaterial.new()
	_crt_mat.shader = sh
	_crt.material = _crt_mat
	_raiz.add_child(_crt)
	_crt.visible = false
	_aplicar_crt_boot()


## O vidro do tubo no boot, nos dois extremos de estilo.
##
## Por que existem DOIS conjuntos e nao um
## ---------------------------------------
## Porque o boot era a unica tela do jogo com o pos cravado no codigo: quatro
## `set_shader_parameter` com numeros escolhidos quando o fundo era uma placa 2D
## parada, e que continuaram valendo depois que ele virou uma estrada em 3D.
## Medido na captura de 1920x1080: com grao 0,54 e vinheta 0,80 sobre a Estrada
## Velha, a serra, a mata e o asfalto somem dentro do ruido — a tela mostra
## chuvisco com um titulo em cima, em qualquer preset que o jogador escolha.
##
## Em PS1 STYLE isso e o efeito PEDIDO e ele fica intacto. Em MODERNO o tubo
## continua existindo — vinheta, scanline e um grao fino, na mesma ordem de
## grandeza dos 0,02 de grao e 0,18 de vinheta que o proprio preset MODERNO usa
## no jogo (ver `Settings.ESTILO_PRESETS`) — mas para de comer a imagem.
##
## `bw` fica fora da tabela: preto-e-branco e identidade da tela e nao dosagem
## de epoca. Ver `_aplicar_crt_menu`.
##
## Os dois ramos, medidos na grade NATIVA de cada um (16/09/2026)
## --------------------------------------------------------------
## Estrutura e o desvio da luminancia depois de reduzir a imagem a 240 px de
## largura — o grao vira media e o que sobra e forma. Ruido e o residuo sobre a
## versao borrada, na escala da propria captura.
##
##     tela              preset    nativo     estrutura   ruido
##     boot              MODERNO   1600x900      31,48      5,61
##     boot              PS1       480x270       27,41      8,39
##     titulo            MODERNO   1600x900      28,23      4,77
##     titulo            PS1       480x270       25,91      7,81
##     pico da travessia MODERNO   1600x900      49,83      6,57
##     pico da travessia PS1       480x270       46,09     12,02
##
## As doze capturas e o comando que as refaz estao em `captures/menu/`.
##
## E a relacao que os dois presets tem de ter: PS1 com 45% mais ruido e um pouco
## menos de forma, MODERNO com a estrada aparecendo atras do vidro. As duas
## colunas nao se comparam entre presets em pixel — em PS1 a JANELA INTEIRA
## renderiza em 480x270 (`content_scale_mode = VIEWPORT`), entao o ruido dele mora
## numa grade quatro vezes maior. Comparar numero de preset com numero de preset
## e o erro que a primeira rodada desta medicao cometeu.
##
## O pico da travessia NAO satura em nenhum dos dois: 0,12% dos pixels acima de
## 250 em MODERNO e 0,07% em PS1. A pergunta era legitima — o burst deixou de ser
## multiplicado pelo grao e passou a somar, e soma tem teto — e a resposta veio
## medida, nao estimada.
const CRT_BOOT_PS1 := {
	&"grain": 0.54, &"scanline": 0.44, &"vignette": 0.80,
	&"glow": 0.40, &"scene_mix": 0.92, &"soft_blur": 0.18,
}
const CRT_BOOT_MODERNO := {
	&"grain": 0.10, &"scanline": 0.14, &"vignette": 0.42,
	&"glow": 0.22, &"scene_mix": 1.0, &"soft_blur": 0.0,
}
## O mesmo par para a tela de titulo, onde o menu ja tem placa propria atras do
## texto e o veu nao precisa trabalhar pela legibilidade.
const CRT_TITULO_PS1 := {
	&"grain": 0.26, &"scanline": 0.30, &"vignette": 0.56,
	&"glow": 0.12, &"scene_mix": 0.9, &"soft_blur": 0.0,
}
const CRT_TITULO_MODERNO := {
	&"grain": 0.06, &"scanline": 0.10, &"vignette": 0.34,
	&"glow": 0.10, &"scene_mix": 1.0, &"soft_blur": 0.0,
}
## Opacidade do veu no titulo. Em MODERNO ele encosta menos na cena: o que
## escurece a faixa do texto e o scrim em gradiente, que e desenhado ANTES da
## copia do quadro e por isso nao apaga a estrada inteira para resolver uma faixa.
const CRT_TITULO_OPACIDADE_PS1 := 0.58
const CRT_TITULO_OPACIDADE_MODERNO := 0.34


## Interpola os dois conjuntos pela dose de epoca e escreve no material.
func _escrever_crt(moderno: Dictionary, ps1: Dictionary) -> void:
	var d := _dose_psx()
	for chave: StringName in ps1:
		_crt_mat.set_shader_parameter(chave,
			lerpf(float(moderno[chave]), float(ps1[chave]), d))


func _aplicar_crt_boot() -> void:
	if _crt_mat == null:
		return
	_crt_mat.set_shader_parameter(&"burst", 0.0)
	# O vidro volta a ser plano: nenhum caminho de saida pode deixar a tela com a
	# deformacao da travessia congelada.
	_crt_mat.set_shader_parameter(&"plunge", 0.0)
	_crt_mat.set_shader_parameter(&"opacity", 1.0)
	_crt_mat.set_shader_parameter(&"bw", lerpf(0.0, 0.22, _dose_psx()))
	if _fundo_vivo:
		# Estrada 3D atras: o veu afrouxa para ela aparecer, e o desfoque quase
		# some — desfocar uma cena com profundidade e jogar a profundidade fora.
		_escrever_crt(CRT_BOOT_MODERNO, CRT_BOOT_PS1)
		return
	# Rede: placa industrial desfocada, enquanto a estrada ainda monta.
	_crt_mat.set_shader_parameter(&"grain", 0.72)
	_crt_mat.set_shader_parameter(&"scanline", 0.52)
	_crt_mat.set_shader_parameter(&"vignette", 0.92)
	_crt_mat.set_shader_parameter(&"glow", 0.58)
	_crt_mat.set_shader_parameter(&"scene_mix", 0.62)
	_crt_mat.set_shader_parameter(&"soft_blur", 0.85)


## Veu do titulo. Afrouxado depois de medido.
##
## A tela de titulo tinha de mostrar "a cidade viva em preto-e-branco sob
## estatica de tubo", e mostrava um retangulo cinza. Metade da culpa era o
## enquadramento, que apontava para o lado de la da nevoa (ver
## `cidade.gd::_preparar_vista_titulo`). A outra metade era este veu.
##
## Medido pelo desvio padrao da luminancia do fundo, que e o quanto de ESTRUTURA
## ha na imagem — parede lisa tem desvio baixo, rua com meio-fio, poste e fachada
## tem alto:
##
##     rua sem menu nenhum ............ 56,7
##     titulo com o veu antigo ........ 43,1  (opacidade 0,82 / vinheta 0,72)
##
## Um quarto da cidade ficava no veu. O texto do menu e desenhado DEPOIS do CRT —
## `_aplicar_fundo` poe a camada de texto por cima dele — entao afrouxar aqui nao
## custa legibilidade nenhuma: so devolve rua ao fundo.
##
## `bw` continua em 1,0: preto-e-branco e identidade da tela, e nao veu.
func _aplicar_crt_menu() -> void:
	if _crt_mat == null:
		return
	_escrever_crt(CRT_TITULO_MODERNO, CRT_TITULO_PS1)
	_crt_mat.set_shader_parameter(&"bw", 1.0)
	_crt_mat.set_shader_parameter(&"burst", 0.0)
	_crt_mat.set_shader_parameter(&"plunge", 0.0)
	_crt_mat.set_shader_parameter(&"opacity", lerpf(
		CRT_TITULO_OPACIDADE_MODERNO, CRT_TITULO_OPACIDADE_PS1, _dose_psx()))


## O boot passa a mostrar a cena 3D em vez da placa parada.
##
## Por que isto existe
## -------------------
## O PRESS START era uma textura 2D parada (`ui_boot_plate.png`) desfocada por
## `soft_blur`. A tela inteira se movia em tres pixels de jitter no titulo e no
## pisca do prompt — nao havia paralaxe, nao havia distancia, nao havia nada
## atras do vidro.
##
## E a maquina para ter profundidade ja estava montada: o shader do CRT le a cena
## renderizada pelo uniform `scene_mix`, alimentado pelo `BackBufferCopy` de
## `_montar_crt`. Ela estava sendo alimentada com uma foto.
##
## Quando o nivel avisa que ha sala montada atras, a placa sai, o desfoque cai e
## o `scene_mix` sobe: o que aparece por tras da estatica passa a ser o comodo de
## verdade, com gente andando e a luz da TV piscando nas silhuetas. Profundidade
## nao e efeito novo — e ter assunto atras do vidro.
##
## A placa continua como rede: ela cobre o intervalo entre abrir o boot e o
## interior terminar de montar, que e justamente quando nao ha nada para mostrar.
func usar_fundo_vivo(vivo: bool) -> void:
	_fundo_vivo = vivo
	if _boot_plate != null:
		_boot_plate.visible = not vivo and painel == Painel.BOOT
	if painel == Painel.BOOT:
		_aplicar_crt_boot()


## Intensidade do burst de estatica (0..1).
##
## Sobrou sem chamador dentro do jogo desde que a travessia do tubo passou a ser
## dirigida por `_avancar_lente`, que escreve `burst` e `plunge` juntos — e os
## dois separados eram justamente o que fazia a estatica aparecer sem a
## deformacao. Continua publica porque e o unico jeito de uma cena externa pedir
## um chuvisco (a Abertura ja fez isso), e porque nao ha nada a ganhar em tirar.
func definir_estatica(burst: float, opacidade: float = -1.0) -> void:
	if _crt_mat == null:
		return
	_crt_mat.set_shader_parameter(&"burst", clampf(burst, 0.0, 1.0))
	if opacidade >= 0.0:
		_crt_mat.set_shader_parameter(&"opacity", clampf(opacidade, 0.0, 1.0))
	if _crt != null:
		_crt.visible = true


func iniciar_transicao_ui() -> void:
	_transicionando = true


func fim_transicao_ui() -> void:
	_transicionando = false


func esconder_boot_texto() -> void:
	if _no_boot != null:
		_no_boot.visible = false
	if _boot_plate != null:
		_boot_plate.visible = false
	_boot_pronto = false


## Tela CRT de boot: placa desfocada + serif oxblood + prompt PS2. Sem scrapbook.
func _montar_boot() -> void:
	_garantir_fontes_boot()
	_no_boot = Control.new()
	_no_boot.name = "Boot"
	_no_boot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_no_boot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_no_boot)

	# Placa industrial fora de foco — fica ATRAS do overlay CRT (scene_mix).
	_boot_plate = TextureRect.new()
	_boot_plate.name = "BootPlate"
	_boot_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boot_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_boot_plate.stretch_mode = TextureRect.STRETCH_SCALE
	_boot_plate.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if ResourceLoader.exists(BOOT_PLATE):
		_boot_plate.texture = load(BOOT_PLATE)
	_boot_plate.modulate = Color(0.78, 0.8, 0.84, 1.0)
	_no_boot.add_child(_boot_plate)
	_boot_plate.position = Vector2.ZERO
	_boot_plate.size = TELA

	var par := _fazer_titulo_serif(_no_boot, BOOT_TITULO_ONDE)
	_boot_titulo_glow = par[0]
	_boot_titulo = par[1]

	_boot_prompt = Label.new()
	_boot_prompt.text = PROMPT_BOOT
	_boot_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boot_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boot_prompt.add_theme_color_override(&"font_color", Color(0.9, 0.88, 0.84))
	_boot_prompt.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	_boot_prompt.add_theme_constant_override(&"outline_size", 3)
	if _fonte_boot_corpo != null:
		_boot_prompt.add_theme_font_override(&"font", _fonte_boot_corpo)
		_boot_prompt.add_theme_font_size_override(&"font_size", 14)
	else:
		_boot_prompt.add_theme_font_override(&"font", UiEstilo.fonte_re7(400))
		_boot_prompt.add_theme_font_size_override(&"font_size", UiEstilo.RE7_SIZE_BODY)
	_no_boot.add_child(_boot_prompt)
	_boot_prompt.position = Vector2(20.0, 178.0)
	_boot_prompt.size = Vector2(440.0, 18.0)

	_boot_rodape = Label.new()
	_boot_rodape.text = RODAPE_BOOT
	_boot_rodape.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boot_rodape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boot_rodape.add_theme_color_override(&"font_color", Color(0.72, 0.7, 0.66))
	_boot_rodape.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	_boot_rodape.add_theme_constant_override(&"outline_size", 2)
	if _fonte_boot_corpo != null:
		_boot_rodape.add_theme_font_override(&"font", _fonte_boot_corpo)
		_boot_rodape.add_theme_font_size_override(&"font_size", 11)
	else:
		UiEstilo.aplicar_re7_micro(_boot_rodape)
	_no_boot.add_child(_boot_rodape)
	_boot_rodape.position = Vector2(20.0, 246.0)
	_boot_rodape.size = Vector2(440.0, 14.0)
	_no_boot.visible = false


## O titulo do jogo — halo e letra —, nas duas telas que o mostram.
##
## Um construtor so, e nao dois
## ----------------------------
## Boot e titulo desenhavam SHIMOKAWA de dois jeitos diferentes: o boot em serif
## de 42 e o menu em bitmap de 18, em lugares diferentes da tela. Na
## transicao do START, isso aparecia como a marca do jogo trocando de fonte e de
## lugar num corte — o jogador nao le "a camera andou", le "mudou de tela". Agora
## e o MESMO rotulo com a MESMA fonte; o que muda entre as duas telas e a altura
## em que ele pousa, e a transicao leva um ao outro por tween.
##
## O halo e concentrico, e isto ja custou uma captura
## --------------------------------------------------
## Halo que nao e concentrico com a letra deixa de ser halo: as pontas escapam e
## o titulo le como impressao fora de registro. O arquivo ja dizia isso — e a
## construcao ja estava certa. Quem desalinhava era o JITTER: `_process` escrevia
## `(18, 70)` no halo e `(20, 74)` na letra, dois literais que sobreviveram ao
## conserto do construtor. Por isso a posicao agora sai daqui, de `_titulo_onde`,
## e nao de numero digitado no meio do movimento.
##
## O halo e o `outline_size`, nunca um corpo maior. Quem quiser engrossa-lo mexe
## no contorno; mexer no tamanho da fonte desalinha de novo.
func _fazer_titulo_serif(pai: Control, onde: Vector2) -> Array[Label]:
	_garantir_fontes_boot()
	var glow := Label.new()
	glow.text = TITULO_TEXTO
	glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.add_theme_color_override(&"font_color", Color(0.82, 0.8, 0.78, 0.22))
	glow.add_theme_color_override(&"font_outline_color", Color(0.9, 0.88, 0.85, 0.35))
	glow.add_theme_constant_override(&"outline_size", 14)

	var letra := Label.new()
	letra.text = TITULO_TEXTO
	letra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letra.add_theme_color_override(&"font_color", TITULO_COR)
	# Halo externo claro + contorno escuro interno (peso NERD GIRL HAUL).
	letra.add_theme_color_override(&"font_shadow_color", Color(0.75, 0.72, 0.7, 0.45))
	letra.add_theme_constant_override(&"shadow_offset_x", 0)
	letra.add_theme_constant_override(&"shadow_offset_y", 0)
	letra.add_theme_constant_override(&"shadow_outline_size", 10)
	letra.add_theme_color_override(&"font_outline_color", Color(0.04, 0.0, 0.0, 0.8))
	letra.add_theme_constant_override(&"outline_size", 4)

	for l: Label in [glow, letra]:
		if _fonte_boot_titulo != null:
			l.add_theme_font_override(&"font", _fonte_boot_titulo)
			l.add_theme_font_size_override(&"font_size", BOOT_TITULO_CORPO)
		pai.add_child(l)
		l.position = onde
		l.size = BOOT_TITULO_CAIXA
	return [glow, letra]


## Serif tall/narrow. Bitmap PSX nao chega no peso da referencia.
func _garantir_fontes_boot() -> void:
	if _fonte_boot_titulo == null and ResourceLoader.exists(FONTE_SERIF_TITULO):
		var base: Font = load(FONTE_SERIF_TITULO) as Font
		var fv := FontVariation.new()
		fv.base_font = base
		# Comprime X e estica Y — serif alto e estreito da ref.
		fv.variation_transform = Transform2D(Vector2(0.62, 0.0), Vector2(0.0, 1.38), Vector2.ZERO)
		_fonte_boot_titulo = fv
	if _fonte_boot_corpo == null and ResourceLoader.exists(FONTE_SERIF_CORPO):
		_fonte_boot_corpo = load(FONTE_SERIF_CORPO) as Font


## Menu de jogo apos a transicao: cidade B&W atras, tipografia CRT, sem fita/papel.
func _montar_titulo() -> void:
	_no_titulo = Control.new()
	_no_titulo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_no_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_no_titulo)

	# O MESMO titulo do boot, so que pousado no alto. Ver `_fazer_titulo_serif`.
	var par := _fazer_titulo_serif(_no_titulo, TITULO_ONDE_MENU)
	_titulo_glow = par[0]
	_titulo_rotulo = par[1]

	var caixa_sub := TituloLayout.subtitulo()
	_subtitulo_rotulo = _rotulo(_no_titulo, TituloLayout.SUBTITULO_TEXTO,
		caixa_sub.position, caixa_sub.size,
		TipoRotulo.MICRO, Color(0.72, 0.7, 0.66), HORIZONTAL_ALIGNMENT_CENTER)
	_subtitulo_rotulo.add_theme_color_override(&"font_outline_color",
		Color(0.0, 0.0, 0.0, 0.75))
	_subtitulo_rotulo.add_theme_constant_override(&"outline_size", 3)

	_montar_lista(_no_titulo, TituloLayout.ITENS, _abas_titulo, _marcas_titulo,
		_realces_titulo, _itens_titulo)

	# "Carregando shaders" no canto, enquanto o jogo compila o catalogo antes de
	# deixar jogar. Ver `AquecimentoDeShaders`.
	_no_titulo.add_child(PainelAquecimento.new(
		func(pai: Control, texto: String, pos: Vector2, tam: Vector2, alinhar: int) -> Label:
			return _rotulo(pai, texto, pos, tam, TipoRotulo.MICRO, NOTA_COR, alinhar),
		_atualizar))

	# A nota embaixo da lista. Nasce vazia e so fala quando ha o que dizer.
	var caixa_nota := TituloLayout.nota()
	_nota_titulo = _rotulo(_no_titulo, "", caixa_nota.position, caixa_nota.size,
		TipoRotulo.MICRO, NOTA_COR, HORIZONTAL_ALIGNMENT_CENTER)
	_nota_titulo.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_nota_titulo.add_theme_constant_override(&"outline_size", 3)

	var caixa_dica := TituloLayout.dica()
	_dica_titulo = _rotulo(_no_titulo, TituloLayout.DICA_TEXTO,
		caixa_dica.position, caixa_dica.size, TipoRotulo.MICRO,
		Color(0.78, 0.76, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	_dica_titulo.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_dica_titulo.add_theme_constant_override(&"outline_size", 4)


## A pagina CARREGAR do titulo: serif + SaveCardsPanelRe7.
##
## A lista legado (TituloLayout.ESPACOS / placas) saiu: o menu de sistema em jogo
## ja usa SaveCardsPanelRe7, e duas telas que fazem a mesma coisa com desenhos
## diferentes ensinam duas vezes. `_abas_espacos` / `_itens_espacos` / nota
## ficam vazios de proposito — guards em `_pintar_lista` e input evitam crash.
func _montar_carregar() -> void:
	_no_carregar = Control.new()
	_no_carregar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_no_carregar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_no_carregar)

	var par := _fazer_titulo_serif(_no_carregar, TITULO_ONDE_MENU)
	par[1].text = "CARREGAR"
	par[0].text = "CARREGAR"

	# SaveCardsPanelRe7 — mesma peca do menu_sistema (pos 130,31).
	# Lista legado TituloLayout.ESPACOS / placas / nota / dica: nao montar.
	_save_panel = SaveCardsPanelRe7.new()
	_save_panel.name = "SaveCardsPanelRe7"
	_save_panel.z_index = 20
	_save_panel.position = Vector2(130.0, 31.0)
	_no_carregar.add_child(_save_panel)
	_save_panel.pediu_carregar.connect(_on_title_save_carregar)
	_save_panel.pediu_voltar.connect(_on_title_save_voltar)

	_no_carregar.visible = false


func _on_title_save_carregar(espaco: int) -> void:
	if not SaveGame.existe(espaco):
		return
	if SaveGame.carregar(espaco):
		_pop_save_audio()
		esconder()
		continuar.emit()


func _on_title_save_voltar() -> void:
	_pop_save_audio()
	mostrar(Painel.TITULO)


func _push_save_audio() -> void:
	if _audio_save_pushed:
		return
	AudioDirector.on_menu_push(&"save")
	_audio_save_pushed = true


func _pop_save_audio() -> void:
	if not _audio_save_pushed:
		return
	AudioDirector.on_menu_pop()
	_audio_save_pushed = false


## A entrada da pagina de espacos: a mesma cascata do titulo, mais curta.
##
## Ela existe por um motivo mecanico antes de estetico: as placas nascem com
## `modulate.a = 0` porque quem as acende e a animacao de entrada — e a do titulo
## so conhece a lista do titulo. Sem esta, a pagina de saves abria com quatro
## retangulos invisiveis e o texto sobre a estrada, e a causa seria procurada na
## cor.
func _animar_entrada_espacos() -> void:
	if _itens_espacos.is_empty():
		return
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# Mesma regra da entrada do titulo: paralelo se declara uma vez.
	tw.set_parallel(true)
	for i in _abas_espacos.size():
		var atraso := float(i) * 0.05
		for no: CanvasItem in [_abas_espacos[i], _itens_espacos[i]]:
			no.modulate.a = 0.0
			tw.tween_property(no, "modulate:a", 1.0, 0.22).set_delay(atraso)
	if _nota_espacos != null:
		_nota_espacos.modulate.a = 0.0
		tw.tween_property(_nota_espacos, "modulate:a", 1.0, 0.22).set_delay(0.2)
	tw.finished.connect(_atualizar)


## Uma lista de itens com placa, marca e realce. Usada pelo titulo e pela pagina
## de espacos — uma construcao, duas telas.
func _montar_lista(pai: Control, entradas: Array, abas: Array[Control],
		marcas: Array[Control], realces: Array[Control], itens: Array[Label]) -> void:
	var largura := TituloLayout.largura_da_placa(UiEstilo.fonte_re7(400), entradas)
	var n := entradas.size()
	for i in n:
		var caixa := TituloLayout.texto(i, largura, n)
		abas.append(_placa_de_item(pai, TituloLayout.placa(i, largura, n),
			marcas, realces, i))
		var item := _rotulo(pai, entradas[i], caixa.position, caixa.size,
			TipoRotulo.BODY, ITEM_NORMAL, HORIZONTAL_ALIGNMENT_CENTER)
		item.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		item.add_theme_constant_override(&"outline_size", 4)
		itens.append(item)


## A placa que marca o item escolhido do menu.
##
## Ela ja existia, e nunca desenhou nada. Eram `TextureRect` sem textura: a
## animacao de entrada os deslizava e subia o alfa deles de 0 a 1, e `_atualizar`
## os zerava de volta — tres trechos de codigo cuidando de retangulos vazios.
## Nao havia erro nem aviso, porque um TextureRect sem textura e um no valido que
## simplesmente nao pinta pixel nenhum. Mesma familia do SSAO que passava no
## Compatibility sem desenhar.
##
## A placa importa por um motivo que nao e enfeite: o menu vive sobre a CIDADE
## em movimento, e texto claro sobre video escuro e ilegivel a metade dos
## quadros. Toda interface que se sobrepoe a imagem viva precisa de um fundo
## proprio; sem ele, a legibilidade do menu depende do que passa atras dele.
## A placa deixou de ser um retangulo chapado, e isto e o que mais muda a tela.
##
## Cinco `ColorRect` de alfa 0,58 empilhados com 4 px entre eles nao leem como
## cinco itens: leem como UM bloco cinza de 120 px sobre a imagem, com listras.
## E era o objeto mais pesado da tela — na captura de 1920x1080, o bloco cobria
## 28% do quadro e apagava exatamente a faixa em que o carro e a estrada estao.
##
## O que substitui e um gradiente horizontal: opaco no miolo, onde o texto mora,
## e transparente nas duas pontas. A borda dura some, a placa passa a ter forma
## propria e a imagem volta a atravessar os lados da lista. E o mesmo recurso do
## `_montar_scrim` — escurecer ONDE precisa, e nao a tela toda para resolver uma
## faixa.
##
## A placa continua existindo por um motivo que nao e enfeite, e ele nao mudou:
## o menu vive sobre imagem em movimento, e texto claro sobre video escuro e
## ilegivel em metade dos quadros. Toda interface sobreposta a imagem viva
## precisa de fundo proprio.
const PLACA_MIOLO := Color(0.02, 0.012, 0.016, 0.62)
## O realce do item escolhido. Nao mexe no alfa da PLACA: aquele pertence ao
## tween de entrada, e disputar a mesma propriedade com uma animacao e como o
## clarao de dano que se apagava sozinho — dois donos, um valor.
const PLACA_REALCE := Color(0.10, 0.055, 0.05, 0.55)


func _placa_de_item(pai: Control, onde: Rect2, marcas_lista: Array[Control],
		realces_lista: Array[Control], indice: int) -> Control:
	var aba := Control.new()
	# A placa RECEBE mouse, e e a unica coisa desta tela que recebe.
	#
	# O menu inteiro era teclado, e a tela seguinte — a carteira — tem clique e
	# hover desde que nasceu. Duas telas vizinhas com contratos de entrada
	# diferentes e o tipo de inconsistencia que o UI-BIBLE existe para impedir.
	#
	# A armadilha que `_montar` ja documenta vale aqui em cheio: `Control` de
	# area zero nao recebe clique nenhum. Estas placas tem tamanho de verdade —
	# 137 px por 22 — porque a largura sai do texto medido.
	aba.mouse_filter = Control.MOUSE_FILTER_STOP
	aba.modulate.a = 0.0
	pai.add_child(aba)
	aba.position = onde.position
	aba.size = onde.size
	aba.mouse_entered.connect(_ao_passar_mouse.bind(indice))
	aba.gui_input.connect(_ao_clicar_item.bind(indice))

	_faixa_gradiente(aba, PLACA_MIOLO)
	var realce := _faixa_gradiente(aba, PLACA_REALCE)
	realce.visible = false
	realces_lista.append(realce)

	# As duas marcas vermelhas nas pontas, e nao uma barra so a esquerda.
	#
	# O texto do item e CENTRALIZADO. Marca de um lado so puxa o olho para fora
	# do centro e faz a linha inteira parecer desalinhada com as outras quatro;
	# em par, elas emolduram e o centro continua sendo o centro.
	var marcas := Control.new()
	marcas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marcas.visible = false
	aba.add_child(marcas)
	for lado in [0.0, aba.size.x - MARCA_LARGURA]:
		var marca := ColorRect.new()
		marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marca.color = MARCA_COR
		marcas.add_child(marca)
		marca.position = Vector2(lado, 0.0)
		marca.size = Vector2(MARCA_LARGURA, aba.size.y)
	marcas_lista.append(marcas)
	return aba


## O mouse passou por cima de um item: ele vira o escolhido.
##
## Mover o cursor com o mouse e mover o cursor, e nao um segundo estado paralelo.
## Sem isto, clicar num item que o teclado nao escolheu acionaria um e destacaria
## outro — e a tela teria dois cursores discordando.
func _ao_passar_mouse(indice: int) -> void:
	if _transicionando or not _lista_tem_foco():
		return
	if _selecionado == indice:
		return
	_selecionado = indice
	AudioDirector.tocar_ui(&"clique", -18.0)
	_atualizar()


func _ao_clicar_item(evento: InputEvent, indice: int) -> void:
	if _transicionando or not _lista_tem_foco():
		return
	var botao := evento as InputEventMouseButton
	if botao == null or not botao.pressed or botao.button_index != MOUSE_BUTTON_LEFT:
		return
	_selecionado = indice
	_atualizar()
	_acionar()


## As placas de qual lista respondem agora.
func _lista_tem_foco() -> bool:
	# CARREGAR do titulo usa SaveCardsPanelRe7 — o painel e dono do foco.
	return painel == Painel.TITULO


## Um retangulo que desaparece nas pontas. Usado pela placa e pelo realce.
func _faixa_gradiente(pai: Control, cor: Color) -> TextureRect:
	var g := Gradient.new()
	# As duas paradas do meio sao onde o texto pode encostar; fora delas a tinta
	# cai a zero em 18% da largura de cada lado.
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.82, 1.0])
	g.colors = PackedColorArray([
		Color(cor.r, cor.g, cor.b, 0.0), cor, cor, Color(cor.r, cor.g, cor.b, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = int(pai.size.x)
	tex.height = 4
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(1.0, 0.0)

	var faixa := TextureRect.new()
	faixa.texture = tex
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faixa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	faixa.stretch_mode = TextureRect.STRETCH_SCALE
	faixa.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pai.add_child(faixa)
	faixa.position = Vector2.ZERO
	faixa.size = pai.size
	return faixa


## A unica coisa que o jogador escolhe sobre si mesmo.
##
## Tudo o mais da ficha — numero, data de nascimento, filiacao, endereco,
## profissao — e sorteado pelo registro, e a folha diz isso em voz alta. Nao e
## limitacao tecnica: e a premissa. O jogo inteiro depois disso e sobre consultar
## um cadastro que ja existia antes de voce chegar, e um personagem com ficha
## escolhida a dedo nao pertence a ele.
## A folha nao e montada com Labels em cima de um TextureRect: ela e um Control
## que se desenha inteiro, como a carteira da tela seguinte. Formulario e feito
## de coisa medida contra coisa medida — pente de caracteres alinhado com a
## margem, coluna de hachura que comeca depois do rotulo mais largo, carimbo
## torto por cima dos campos certos — e nada disso se posiciona a mao em quinze
## nos soltos sem sair do lugar no primeiro ajuste. Ver src/ui/ficha_cadastro.gd.
func _montar_nome() -> void:
	_no_nome = FichaCadastro.new()
	_no_nome.name = "Ficha"
	_raiz.add_child(_no_nome)
	# Clicar na linha de assinatura vale ENTER. A folha so avisa que o clique
	# aconteceu; o que assinar significa continua sendo assunto do menu.
	_no_nome.pediu_assinar.connect(_assinar)


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

	_imagem(_no_opcoes, "ui_papel", OpcoesLayout.PAPEL.position,
		OpcoesLayout.PAPEL.size, TextureRect.STRETCH_TILE).modulate = PAPEL
	_titulo_opcoes = _rotulo(_no_opcoes, "OPCOES",
		Vector2(OpcoesLayout.PAPEL.position.x, 30.0),
		Vector2(OpcoesLayout.PAPEL.size.x, 24.0),
		TipoRotulo.TITLE, TINTA, HORIZONTAL_ALIGNMENT_CENTER)

	# O passo, as duas colunas e o limite do creme vem de `OpcoesLayout`, que e
	# onde `tests/checar_hud.gd` alcanca. A conta continua sendo a mesma que esta
	# folha ja tinha aprendido a fazer depois de estourar duas vezes; o que mudou
	# e que agora ela e medida por fora, com as strings mais largas que o jogo
	# consegue produzir.
	# Os rotulos nascem para a pagina MAIS CHEIA e sao reaproveitados: trocar de
	# pagina reescreve texto e posicao, e nao destroi e reconstroi `Label`.
	# Reconstruir daria o mesmo desenho e um cintilar de um quadro em cada troca.
	var maximo := 0
	for pagina: Array[Dictionary] in [_opcoes_imagem, _opcoes_som, _opcoes_hud,
			_opcoes_hud_exibicao, _opcoes_hud_pecas, _opcoes_legendas]:
		maximo = maxi(maximo, pagina.size())
	for i in maximo:
		_rotulos_opcoes.append(_rotulo(_no_opcoes, "", Vector2.ZERO,
			Vector2.ZERO, TipoRotulo.MICRO, TINTA))
		_itens_opcoes.append(_rotulo(_no_opcoes, "", Vector2.ZERO,
			Vector2.ZERO, TipoRotulo.MICRO, TINTA_FRACA))
	_dispor_opcoes()

	var caixa_dica := OpcoesLayout.dica()
	_rotulo(_no_opcoes, OpcoesLayout.DICA_TEXTO, caixa_dica.position,
		caixa_dica.size, TipoRotulo.MICRO, Color(0.82, 0.76, 0.62),
		HORIZONTAL_ALIGNMENT_CENTER)


## Poe cada linha da pagina atual no lugar, e apaga o que sobra.
func _dispor_opcoes() -> void:
	var n := _opcoes.size()
	if not OpcoesLayout.cabe(n):
		push_warning("Menu: %d opcoes so cabem com passo de %.1f px, e a linha da "
			% [n, OpcoesLayout.passo(n)]
			+ "fonte tem %.0f px. A pagina precisa ser dividida." % OpcoesLayout.LINHA)
	for i in _rotulos_opcoes.size():
		var vivo := i < n
		_rotulos_opcoes[i].visible = vivo
		_itens_opcoes[i].visible = vivo
		if not vivo:
			continue
		var caixa_rot := OpcoesLayout.rotulo(i, n)
		var caixa_val := OpcoesLayout.valor(i, n)
		_rotulos_opcoes[i].text = String(_opcoes[i]["rotulo"])
		_rotulos_opcoes[i].position = caixa_rot.position
		_rotulos_opcoes[i].size = caixa_rot.size
		_itens_opcoes[i].position = caixa_val.position
		_itens_opcoes[i].size = caixa_val.size
	if _titulo_opcoes != null:
		_titulo_opcoes.text = "OPCOES  ·  " + String(["IMAGEM", "SOM", "HUD",
			"EXIBICAO DO HUD", "PECAS DO HUD", "LEGENDAS"][int(_opcoes_pagina)])


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
		TipoRotulo.TITLE, TINTA, HORIZONTAL_ALIGNMENT_CENTER)
	_cabecalho = _rotulo(_no_mapa, "", Vector2(20.0, 42.0), Vector2(440.0, 14.0),
		TipoRotulo.MICRO, TINTA_FRACA, HORIZONTAL_ALIGNMENT_CENTER)

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
		Vector2(MAPA_CAIXA.size.x * 0.6, 12.0), TipoRotulo.MICRO, TINTA_FRACA)
	_rotulo(_no_mapa, "[A/D] escala   [ESC] voltar",
		Vector2(MAPA_CAIXA.position.x, 236.0),
		Vector2(MAPA_CAIXA.size.x + 96.0, 12.0), TipoRotulo.MICRO, TINTA_FRACA,
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
			TipoRotulo.MICRO, TINTA)
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
			TipoRotulo.MICRO, TINTA)
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
	# A pagina do pause mostra a MESMA rota e os MESMOS alfinetes do cartao do
	# canto. Sao a mesma classe de mapa, e deixar uma das duas sem o tracado faria
	# o jogador ver dois mapas discordando sobre o caminho.
	_mapa.rota = Gps.rota_do_destino()
	_mapa.pinos = Gps.pinos_do_destino()
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
	# O aquecimento de shaders comeca com a abertura, para chegar ao titulo
	# adiantado. Chamar de novo nao faz nada.
	if qual == Painel.BOOT or qual == Painel.TITULO:
		AquecimentoDeShaders.iniciar(self)
	var vinha_titulo := visible and painel == Painel.TITULO
	var vinha_carregar := painel == Painel.CARREGAR
	# O menu ja estava na tela antes desta troca de painel? Ver a cortina preta
	# mais abaixo.
	_menu_estava_na_tela = visible
	painel = qual
	if vinha_carregar and qual != Painel.CARREGAR:
		_pop_save_audio()
	_selecionado = 0
	_boot_pronto = qual == Painel.BOOT
	if _no_boot != null:
		_no_boot.visible = qual == Painel.BOOT
	_no_titulo.visible = qual == Painel.TITULO
	_no_carregar.visible = qual == Painel.CARREGAR
	_no_opcoes.visible = qual == Painel.OPCOES
	_no_mapa.visible = qual == Painel.MAPA
	_no_nome.visible = qual == Painel.NOME
	_criacao.visible = qual == Painel.APARENCIA
	_criacao.set_process(qual == Painel.APARENCIA)
	_aplicar_fundo(qual)
	if qual == Painel.MAPA:
		_centrar_mapa()
	if qual == Painel.NOME:
		_nome_digitado = _nome_de_teste()
		if _no_nome != null:
			_no_nome.reiniciar()
		_atualizar_campo()
	if qual == Painel.APARENCIA:
		_criacao.abrir()
	if qual == Painel.CARREGAR:
		_push_save_audio()
		if _save_panel != null:
			_save_panel.refresh_from_savegame()
			_save_panel.call_deferred("foco_padrao")
		# Lista legado vazia: animacao de placas no-op.
		_animar_entrada_espacos()
	# Boot, titulo e a pagina de saves deixam o mundo vivo. Outros pausam.
	var vivo := qual == Painel.BOOT or qual == Painel.TITULO or qual == Painel.CARREGAR
	set_process(vivo)
	visible = true
	# Sessao.pausar: sozinho, a arvore para; em rede, so o jogador local.
	Sessao.pausar(not vivo)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_atualizar()
	if qual == Painel.TITULO and not vinha_titulo and not _transicionando:
		# A cortina preta e para quando o titulo aparece DO NADA. Voltar de uma
		# pagina interna — CARREGAR, OPCOES, MAPA — e andar dentro da mesma tela,
		# e fechar para preto no meio disso le como recomecar o jogo.
		#
		# O defeito apareceu no primeiro clique em VOLTAR: a captura do retorno
		# saiu com a tela preta e ZERO itens visiveis, e a causa nao era o clique
		# (que funcionou) — era a cortina de 0,85 s comecando de novo.
		_animar_entrada_titulo(not _menu_estava_na_tela)


## CRT no boot/titulo. Colagem nos paineis de papel. Letterbox some — identidade CRT.
func _aplicar_fundo(qual: Painel) -> void:
	var boot := qual == Painel.BOOT
	# A pagina de saves e a mesma tela do titulo, uma pagina adiante: mesmo fundo,
	# mesmo veu, mesma lente. So a lista muda.
	var titulo := qual == Painel.TITULO or qual == Painel.CARREGAR
	var vivo := boot or titulo
	if _fundo_veu != null:
		# No titulo o CRT ja escurece; veu leve so para ler texto. Mais fraco
		# desde que o fundo virou a mata: a serra ja e escura por conta propria e
		# o veu somava preto em cima de preto.
		_fundo_veu.visible = titulo
		_fundo_veu.color = Color(0.01, 0.01, 0.02, 0.14)
	# Ficha e aparencia sao a MESMA cena: o carro parado na Estrada Velha, com a
	# cabine 3D viva atras do papel. A colagem de recortes e a vinheta da prancha
	# nao entram em nenhuma das duas — a folha tem o proprio fundo, a propria
	# vinheta e a propria sombra, e a colagem por baixo so somava textura marrom
	# atras de texto marrom.
	var na_estrada := qual == Painel.NOME or qual == Painel.APARENCIA
	# A lente em repouso so tem DOIS valores, e o painel diz qual.
	#
	#     BOOT   -> 0,0, o plano largo. E onde o travelling comeca, sempre: uma
	#               segunda passagem pela tela nao pode abrir com a camera onde a
	#               primeira a deixou.
	#     TITULO -> 1,0, o plano do carro. E onde o travelling TERMINA, e o
	#               titulo tem de ser o mesmo tenha o jogador chegado nele pelo
	#               START ou por bandeira de captura.
	#
	# Sem esta regra havia duas telas de titulo: a do `--ver-menu` abria no plano
	# largo e a do START, no plano do carro. E uma transicao interrompida no meio
	# — save carregado, bandeira, encerramento — deixava a camera parada onde o
	# `await` foi abandonado, sem nada para devolve-la.
	#
	# Durante a propria transicao quem manda e o tween, e por isso a guarda de
	# `_transicionando`.
	if boot:
		_lente_titulo = 0.0
	elif titulo and not _transicionando:
		_lente_titulo = 1.0
	# Boot e titulo passam a abrir na mesma estrada de mata em que a partida
	# comeca. A cena e a mesma da ficha; muda a lente.
	_ligar_fundo_mata(vivo)
	if _fundo_colagem != null:
		_fundo_colagem.visible = not vivo and not na_estrada
	if _barra_topo != null:
		_barra_topo.visible = false
	if _barra_base != null:
		_barra_base.visible = false
	if _vinheta_ui != null:
		_vinheta_ui.visible = not vivo and not na_estrada
	if _criacao != null:
		_criacao.ativar_fundo(na_estrada)
		if _no_nome != null:
			_no_nome.fundo = _criacao.textura_cabine()
	# A mata soa em toda tela que a MOSTRA, e nao so nas duas de papel. Antes o
	# boot e o titulo rodavam com o zumbido urbano no ouvido enquanto a tela
	# mostrava outro lugar — e agora mostram a estrada.
	_ambiente_da_estrada(na_estrada or vivo)
	if _boot_plate != null:
		_boot_plate.visible = boot and not _fundo_vivo
	if _crt != null:
		_crt.visible = vivo
		if boot:
			_aplicar_crt_boot()
		elif titulo:
			_aplicar_crt_menu()
		var bbc := _raiz.get_node_or_null("CrtBackBuffer") as Node
		if boot and _no_boot != null:
			# Ordem: placa -> BackBufferCopy -> CRT -> texto do boot.
			if _boot_plate != null:
				if _boot_plate.get_parent() != _raiz:
					_boot_plate.get_parent().remove_child(_boot_plate)
					_raiz.add_child(_boot_plate)
				_raiz.move_child(_boot_plate, 0)
			if bbc != null:
				_raiz.move_child(bbc, 1 if _boot_plate != null else 0)
			_raiz.move_child(_crt, (bbc.get_index() + 1) if bbc != null else 1)
			_raiz.move_child(_no_boot, _crt.get_index() + 1)
		elif titulo and _no_titulo != null:
			if bbc != null:
				_raiz.move_child(bbc, maxi(0, _no_titulo.get_index() - 2))
			_raiz.move_child(_crt, maxi(0, _no_titulo.get_index() - 1))
		# Com a mata no fundo, a ordem passa a ser dita por extenso.
		#
		# A aritmetica de indice acima foi escrita quando o fundo do boot era uma
		# placa 2D que morava no indice 0. Ela empurrava o BackBufferCopy para o
		# indice 1 — ou seja, ANTES do fundo da mata — e entao duas coisas
		# quebravam de uma vez: o CRT lia um quadro que nao tinha a estrada, e o
		# proprio texto do boot ficava por baixo dela. A captura saiu com a
		# estrada bonita e sem uma letra na tela.
		#
		# Cinco camadas, nesta ordem, e sem conta nenhuma:
		#   mata -> veu -> copia do quadro -> CRT -> texto do painel
		if _fundo_mata != null and _fundo_mata.visible:
			_raiz.move_child(_fundo_mata, 0)
			var i := 1
			if _scrim != null and _scrim.visible:
				_raiz.move_child(_scrim, i)
				i += 1
			if bbc != null:
				_raiz.move_child(bbc, i)
				i += 1
			_raiz.move_child(_crt, i)
			i += 1
			var painel_no: Control = _no_boot if boot else _no_titulo
			if painel_no != null:
				_raiz.move_child(painel_no, i)


## O som do lugar onde a ficha e a carteira acontecem.
##
## As duas telas mostram um carro parado numa estrada de mata a noite, e o que
## se ouvia atras delas era a cidade: `zumbido_loop`, que e o ronco urbano que
## cidade.gd deixa no ar. Imagem de um lugar com o som de outro e o tipo de
## buraco que ninguem sabe nomear e todo mundo sente.
##
## Nao para o loop da cidade, ABAIXA — quem e dono dele e a cidade, e roubar o
## controle daria uma tela que volta do menu em silencio. A mata entra como
## camada propria, essa sim do menu, e sai junto.
##
## Sem motor: o carro esta parado com a chave na ignicao, mas motor roncando
## atras de um formulario le como som que escapou, e nao como ambiencia — o
## mesmo motivo de `CarroCena.com_som` estar desligado no fundo dessas telas.
func _ambiente_da_estrada(ligado: bool) -> void:
	AudioDirector.volume_ambiente(&"zumbido_loop", -60.0 if ligado else -26.0)
	AudioDirector.volume_ambiente(&"vento_loop", -15.0 if ligado else -20.0)
	if ligado:
		AudioDirector.ambiente(&"folhas_loop", -23.0)
	else:
		AudioDirector.parar_ambiente(&"folhas_loop")


## Fade do preto + entradas subindo em cascata. Curto: abertura, nao cutscene.
##
## `com_preto = false` e o caminho que vem do START. Ali a tela ja esta na
## imagem certa e o titulo ja esta no lugar certo — fechar para preto e reabrir
## apagaria o travelling que acabou de acontecer, e o titulo piscaria de alfa 0
## depois de dois segundos e meio visivel. Entao a cortina e o titulo ficam de
## fora e so a lista entra em cascata, que e a unica parte da tela que ainda nao
## tinha aparecido.
func _animar_entrada_titulo(com_preto: bool = true) -> void:
	_animando_titulo = true
	_tempo_titulo = 0.0
	if _fade_preto != null:
		_fade_preto.visible = com_preto
		_fade_preto.color.a = 1.0 if com_preto else 0.0
	if _titulo_rotulo != null and com_preto:
		_titulo_rotulo.modulate.a = 0.0
	if _titulo_glow != null and com_preto:
		_titulo_glow.modulate.a = 0.0
	if _subtitulo_rotulo != null:
		_subtitulo_rotulo.modulate.a = 0.0
	for i in _itens_titulo.size():
		_itens_titulo[i].modulate.a = 0.0
		_itens_titulo[i].position.y += 6.0
		if i < _abas_titulo.size():
			_abas_titulo[i].modulate.a = 0.0
			_abas_titulo[i].position.y += 6.0
	if _dica_titulo != null:
		_dica_titulo.modulate.a = 0.0
	if _barra_topo != null:
		_barra_topo.position.y = -28.0
	if _barra_base != null:
		_barra_base.position.y = TELA.y

	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# `set_parallel(true)` UMA vez, e nao `.parallel()` em cada linha.
	#
	# Isto e higiene, e nao conserto de defeito — vale dizer porque eu cheguei a
	# escrever o contrario aqui. A cadeia antiga dependia de o PRIMEIRO
	# `tween_property` nao ter `.parallel()`, e esse primeiro era condicional (a
	# cortina preta). Quando a cortina esta desligada — o caminho do START e o da
	# volta de uma pagina — a cadeia inteira passa a ser `parallel()` a partir de
	# nada. Medido com instrumentacao: o `Tween` roda assim mesmo. Mas a
	# construcao so era correta por acidente, e declarar o paralelo uma vez tira
	# a condicional do caminho.
	#
	# A tela vazia que me fez vir ate aqui nao era disto: era a captura saindo
	# oitenta milissegundos depois do clique, com meio segundo de cascata pela
	# frente. Ver `CaptureTool.ANTES_CLIQUE`.
	tw.set_parallel(true)
	if _fade_preto != null and com_preto:
		tw.tween_property(_fade_preto, "color:a", 0.0, 0.85)
	if _barra_topo != null:
		tw.tween_property(_barra_topo, "position:y", 0.0, 0.55)
	if _barra_base != null:
		tw.tween_property(_barra_base, "position:y", TELA.y - 28.0, 0.55)
	if _titulo_rotulo != null and com_preto:
		tw.tween_property(_titulo_rotulo, "modulate:a", 1.0, 0.5).set_delay(0.25)
	if _titulo_glow != null and com_preto:
		tw.tween_property(_titulo_glow, "modulate:a", 1.0, 0.5).set_delay(0.25)
	if _subtitulo_rotulo != null:
		tw.tween_property(_subtitulo_rotulo, "modulate:a", 1.0, 0.45).set_delay(0.4)
	for i in _itens_titulo.size():
		# Vindo do START a lista nao espera meio segundo: a espera do original
		# cobria o fade do preto, e sem preto ela vira tela parada.
		var atraso := (0.5 if com_preto else 0.12) + float(i) * 0.07
		var y_final := _itens_titulo[i].position.y - 6.0
		tw.tween_property(_itens_titulo[i], "modulate:a", 1.0, 0.28).set_delay(atraso)
		tw.tween_property(_itens_titulo[i], "position:y", y_final, 0.32).set_delay(atraso)
		if i < _abas_titulo.size():
			var y_aba := _abas_titulo[i].position.y - 6.0
			tw.tween_property(_abas_titulo[i], "modulate:a", 1.0, 0.28).set_delay(atraso)
			tw.tween_property(_abas_titulo[i], "position:y", y_aba, 0.32).set_delay(atraso)
	if _dica_titulo != null:
		tw.tween_property(_dica_titulo, "modulate:a", 1.0, 0.35).set_delay(
			0.9 if com_preto else 0.5)
	tw.finished.connect(func() -> void:
		_animando_titulo = false
		if _fade_preto != null:
			_fade_preto.visible = false
		# Sem isto o menu so assume o estado de selecao quando o jogador mexe no
		# cursor: a animacao deixa tudo como ela terminou, e ate a primeira tecla
		# o item escolhido nao esta marcado em lugar nenhum.
		_atualizar()
	)


func esconder() -> void:
	_pop_save_audio()
	visible = false
	_animando_titulo = false
	_transicionando = false
	_boot_pronto = false
	# O painel de aparencia sai junto, explicitamente. Ele tem um SubViewport 3D
	# que so para de renderizar quando o Control fica invisivel, e esconder a
	# CanvasLayer nao muda a visibilidade dos Controls dentro dela.
	if _criacao != null:
		_criacao.visible = false
		# A cabine nao segue mais a visibilidade da carteira (a ficha tambem a
		# usa), entao quem fecha o menu tem de apaga-la a mao — senao ela fica
		# montando estrada e nevoa atras do jogo pela partida inteira.
		_criacao.ativar_fundo(false)
	# A mata sai junto com o menu: quem entra no jogo esta na cidade de novo.
	_ligar_fundo_mata(false)
	_ambiente_da_estrada(false)
	if _fade_preto != null:
		_fade_preto.visible = false
	if _crt != null:
		_crt.visible = false
	Sessao.pausar(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _atualizar() -> void:
	# O escolhido e o mais CLARO da lista, e nao o mais escuro.
	#
	# Estava ao contrario: o item sob o cursor era pintado de 7a141c — vermelho
	# escuro, luminancia perto de 0,1 — enquanto os outros quatro ficavam em 0,9,
	# quase brancos. Sobre a cidade noturna que corre atras do menu, isso fazia
	# do item escolhido a coisa MENOS visivel da tela: a selecao apagava o item
	# em vez de destaca-lo, e o jogador tinha de deduzir onde estava pelo que
	# NAO conseguia ler. O vermelho da identidade nao se perdeu; ele mudou de
	# lugar, e agora emoldura a placa em vez de engolir a letra.
	_pintar_lista(Painel.TITULO, TituloLayout.ITENS, _itens_titulo, _abas_titulo,
		_marcas_titulo, _realces_titulo)
	if not _itens_espacos.is_empty():
		_pintar_lista(Painel.CARREGAR, TituloLayout.ESPACOS, _itens_espacos,
			_abas_espacos, _marcas_espacos, _realces_espacos)
	if _nota_titulo != null and painel == Painel.TITULO:
		_nota_titulo.text = _texto_da_nota()
	if _nota_espacos != null and painel == Painel.CARREGAR and not _itens_espacos.is_empty():
		_nota_espacos.text = _texto_da_nota()

	_pintar_opcoes()


## Pinta uma das duas listas de placa. A cor do item MORTO e a unica regra de
## estado aqui: ver `ITEM_MORTO` e a ordem obrigatoria de luminancias no topo.
func _pintar_lista(dono: Painel, entradas: Array, itens: Array[Label],
		abas: Array[Control], marcas: Array[Control], realces: Array[Control]) -> void:
	for i in itens.size():
		var ativo := painel == dono and i == _selecionado
		var vivo := _entrada_viva(dono, entradas, i)
		itens[i].add_theme_color_override(&"font_color",
			ITEM_ESCOLHIDO if ativo else (ITEM_NORMAL if vivo else ITEM_MORTO))
		# A placa fica em todas: ela e o fundo que torna a lista legivel sobre a
		# imagem que corre atras. Quem anda com o cursor e a marca. O alfa da
		# placa pertence ao tween de entrada e nao se mexe aqui.
		if i < abas.size():
			abas[i].scale = Vector2.ONE
		if i < marcas.size():
			marcas[i].visible = ativo
		if i < realces.size():
			realces[i].visible = ativo


## Aquela entrada pode ser acionada?
func _entrada_viva(dono: Painel, entradas: Array, i: int) -> bool:
	if dono == Painel.CARREGAR:
		if _itens_espacos.is_empty():
			return false
		return i >= SaveGame.ESPACOS or SaveGame.existe(i)
	return _item_vivo(String(entradas[i]))


## A linha embaixo da lista: o que o item escolhido quer dizer.
##
## Ela existe por uma falha de resposta, e nao por enfeite. CONTINUAR sem save
## ficava apagado e engolia a tecla: o jogador apertava E e a tela nao fazia
## nada — nem som, nem letra. Item que nao pode ser acionado tem de dizer por
## que, e item que carrega um jogo tem de dizer QUAL jogo.
func _texto_da_nota() -> String:
	if painel == Painel.CARREGAR:
		if _itens_espacos.is_empty():
			return ""
		if _selecionado >= SaveGame.ESPACOS:
			return "volta para o menu"
		if not SaveGame.existe(_selecionado):
			return "espaco livre"
		var r := SaveGame.resumo(_selecionado)
		var lugar := String(r.get("local", "")).to_upper()
		var quando := String(r.get("quando", ""))
		if lugar.is_empty():
			lugar = "EM ALGUM LUGAR"
		return "%s  ·  %s" % [lugar, quando.replace("T", " ")]
	if _selecionado >= TituloLayout.ITENS.size():
		return ""
	var qual := TituloLayout.ITENS[_selecionado]
	if qual in ["CONTINUAR", "CARREGAR", "NOVO JOGO"] and not AquecimentoDeShaders.pronto():
		return "carregando shaders..."
	if not _item_vivo(qual):
		return "nao ha jogo gravado"
	if qual == "CONTINUAR":
		var n := _ultimo_espaco()
		var lugar := String(SaveGame.resumo(n).get("local", "")).to_upper()
		return "espaco %d%s" % [n + 1, ("  ·  " + lugar) if not lugar.is_empty() else ""]
	return ""


func _pintar_opcoes() -> void:
	for i in _opcoes.size():
		var ativo := painel == Painel.OPCOES and i == _selecionado
		var ler: Callable = _opcoes[i]["ler"]
		var valor := str(ler.call())
		if OpcoesLista.eh_trilha(valor):
			valor = OpcoesLista.texto_trilha_visual(OpcoesLista.nivel_trilha(valor))
		_itens_opcoes[i].text = ("> " if ativo else "") + valor
		_itens_opcoes[i].add_theme_color_override(&"font_color",
			DESTAQUE if ativo else TINTA_FRACA)


func _unhandled_input(evento: InputEvent) -> void:
	if not visible or _transicionando:
		return

	if painel == Painel.BOOT:
		_input_boot(evento)
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

	# SaveCardsPanelRe7 e dono do foco em CARREGAR — nao dirigir lista legado.
	if painel == Painel.CARREGAR and _save_panel != null and _save_panel.visible:
		if evento.is_action_pressed("pausa"):
			mostrar(Painel.TITULO)
			get_viewport().set_input_as_handled()
		return

	# Quantos itens a tecla percorre: depende de QUAL lista esta na tela.
	var n := _opcoes.size()
	if painel == Painel.TITULO:
		n = _itens_titulo.size()
	elif painel == Painel.CARREGAR:
		n = _itens_espacos.size()
		if n == 0:
			return

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
	elif evento.is_action_pressed("pausa") and (painel == Painel.OPCOES
			or painel == Painel.CARREGAR):
		mostrar(Painel.TITULO)
	else:
		return
	get_viewport().set_input_as_handled()


## Start / Enter / E / espaco na tela CRT.
func _input_boot(evento: InputEvent) -> void:
	if not _boot_pronto:
		return
	var tecla := evento as InputEventKey
	var start := false
	if evento.is_action_pressed("interagir") or evento.is_action_pressed("ui_accept"):
		start = true
	elif tecla != null and tecla.pressed and not tecla.echo:
		if tecla.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			start = true
	elif evento is InputEventJoypadButton and evento.pressed:
		var j := evento as InputEventJoypadButton
		if j.button_index in [JOY_BUTTON_START, JOY_BUTTON_A]:
			start = true
	if not start:
		return
	_boot_pronto = false
	_transicionando = true
	get_viewport().set_input_as_handled()
	# A cidade solta o jogador e devolve o pos do estilo escolhido; a imagem
	# desta tela e desta cena continuam sendo assunto daqui.
	boot_iniciar.emit()
	_entrar_no_titulo()


## START apertado por codigo, para captura (`--ver-partida`).
##
## Passa pelo MESMO caminho da tecla, e nao por um atalho: uma captura que
## chama direto a animacao mede um caminho que o jogador nao percorre, e foi
## assim que a tela de boot passou meses sendo fotografada com a placa parada
## que o jogo nao mostrava mais.
func comecar_pelo_codigo() -> void:
	if painel != Painel.BOOT or _transicionando:
		return
	_boot_pronto = false
	_transicionando = true
	boot_iniciar.emit()
	_entrar_no_titulo()


## O START: a lente anda ate o carro, e o titulo abre nesse plano.
##
## O que havia aqui
## ----------------
## Um corte para OUTRO lugar. O START carregava a Casa da Fumaca atras do veu,
## sentava a camera diante de uma TV em estatica, varria a sala de um lado para
## o outro (−20°, +18°, 0°), empurrava ate o tubo e so entao abria o titulo. Era
## o desenho de uma versao em que o menu nascia dentro de uma televisao — e essa
## versao acabou quando boot e titulo passaram a abrir na Estrada Velha. O que
## sobrou foi um botao que troca de cenario duas vezes para voltar ao primeiro,
## com o chiado do tubo por cima e o jogador teleportado para dentro de um
## interior que ninguem chega a ver. Tres defeitos relatados, uma causa so.
##
## O que ha agora
## --------------
## O START anda PARA DENTRO da imagem que ja estava na tela: a mesma estrada, a
## mesma noite, a lente avancando do plano largo ate um passo do para-choque
## (`CabineFundoCriacao.avancar_menu`). Nada carrega, nada corta, nada chia.
##
## Tres coisas correm em paralelo, e e o paralelo que faz parecer um movimento
## so em vez de tres etapas: a lente avanca, o texto do boot apaga nos primeiros
## 0,3 s, e o vidro do tubo afrouxa da dose de boot para a de titulo.
##
## O tempo e as curvas moram em `TravessiaCurva` — `RefCounted` puro, que e onde
## `tests/checar_hud.gd` alcanca. Curva com degrau nao da erro: da uma tela que
## fica com o vidro empenado para sempre, ou uma camera parada no meio do
## caminho. Os dois defeitos sao mudos, e os dois sao aritmetica.
const T_APROXIMACAO := TravessiaCurva.DURACAO
const TRAVESSIA := TravessiaCurva.TRAVESSIA


func _entrar_no_titulo() -> void:
	_aplicar_crt_boot()
	# O som da travessia: o estalo do tubo e um punhado de chuva, os DOIS em
	# one-shot e os dois cortados junto.
	#
	# Nenhum loop entra aqui, e isso e regra e nao gosto. O chiado que o jogador
	# reportou vinha de dois loops que ninguem desligava — o `tv_chiado` da Casa
	# da Fumaca, que a transicao antiga carregava, e o radio na frequencia morta
	# do fundo do menu. O primeiro deixou de existir com a Casa; o segundo agora
	# cala com a imagem (`CabineFundoCriacao.silenciar`). O `parar_ui` fecha a
	# piscina depois do pico, para nao sobrar nem a cauda do one-shot.
	AudioDirector.tocar_ui(&"bzum", -4.0)
	AudioDirector.tocar_ui(&"estatica", -9.0)
	get_tree().create_timer(T_APROXIMACAO * TRAVESSIA).timeout.connect(
		func() -> void: AudioDirector.parar_ui())
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_method(_avancar_lente, 0.0, 1.0, T_APROXIMACAO)
	# O prompt e o rodape apagam: os dois falam do boot e nao da tela seguinte.
	for no: Control in [_boot_prompt, _boot_rodape]:
		if no != null:
			tw.parallel().tween_property(no, "modulate:a", 0.0, 0.3)
	# O titulo NAO apaga — ele sobe. E a mesma marca, na mesma fonte, indo para
	# o lugar que ela ocupa na tela de menu; quando a lente para, o rotulo do
	# painel de titulo ja esta exatamente embaixo dele e a troca nao tem quadro
	# visivel. Sem isto o START apagava SHIMOKAWA em serif de 42 e acendia
	# SHIMOKAWA em bitmap de 18 noutro lugar, que e uma troca de tela e nao um
	# movimento de camera.
	for no: Control in [_boot_titulo, _boot_titulo_glow]:
		if no != null:
			tw.parallel().tween_property(no, "position", TITULO_ONDE_MENU,
				T_APROXIMACAO)
	await tw.finished
	if painel != Painel.BOOT:
		# A tela mudou por fora durante os 2,4 s — bandeira de captura, save
		# carregado, encerramento. Retomar sem conferir e como um menu reabre
		# sozinho depois de fechado; o mesmo cuidado esta em `_assinar`.
		#
		# Mas sair calado deixaria a lente parada onde o `await` foi abandonado,
		# e o vidro com a deformacao do quadro em que a tela trocou. A saida
		# ASSENTA nos dois valores de repouso: plano largo se voltamos ao boot,
		# plano do carro para qualquer outra tela. Ver `_aplicar_fundo`.
		_transicionando = false
		_avancar_lente(0.0 if painel == Painel.BOOT else 1.0)
		if painel == Painel.TITULO:
			_aplicar_crt_menu()
		return
	esconder_boot_texto()
	# `mostrar` nao anima: `_transicionando` ainda e verdadeiro. Quem anima e a
	# linha seguinte, e ela entra SEM o veu preto — a tela ja esta na imagem
	# certa, e fechar para preto so para reabrir seria desfazer o travelling que
	# acabou de acontecer.
	mostrar(Painel.TITULO)
	_transicionando = false
	_animar_entrada_titulo(false)


## Um ponto do travelling: a lente, o vidro do tubo e a travessia, juntos.
##
## Um `t` so manda em tudo. Fazer o veu mudar num segundo tween, depois, le como
## duas transicoes emendadas — e foi assim que a versao antiga soava: burst,
## corte, burst de novo.
func _avancar_lente(t: float) -> void:
	_lente_titulo = t
	if _mata_cena != null and is_instance_valid(_mata_cena):
		_mata_cena.avancar_menu(t)
	if _crt_mat == null:
		return
	_crt_mat.set_shader_parameter(&"plunge", TravessiaCurva.plunge(t))
	_crt_mat.set_shader_parameter(&"burst", TravessiaCurva.burst(t))
	var veu := TravessiaCurva.veu(t)
	var d := _dose_psx()
	for chave: StringName in CRT_BOOT_PS1:
		var de := lerpf(float(CRT_BOOT_MODERNO[chave]), float(CRT_BOOT_PS1[chave]), d)
		var ate := lerpf(float(CRT_TITULO_MODERNO[chave]), float(CRT_TITULO_PS1[chave]), d)
		_crt_mat.set_shader_parameter(chave, lerpf(de, ate, veu))
	_crt_mat.set_shader_parameter(&"bw", lerpf(lerpf(0.0, 0.22, d), 1.0, veu))
	_crt_mat.set_shader_parameter(&"opacity", lerpf(1.0, lerpf(
		CRT_TITULO_OPACIDADE_MODERNO, CRT_TITULO_OPACIDADE_PS1, d), veu))


## Pisca do prompt CRT + respiracao do titulo. O cursor da ficha nao passa mais
## por aqui: a folha se anima sozinha, em `FichaCadastro._process`.
func _process(delta: float) -> void:
	if not visible:
		return
	_tempo_titulo += delta
	if painel == Painel.BOOT or painel == Painel.TITULO:
		_grilos(delta)
	if painel == Painel.BOOT and _boot_pronto:
		# Pisca classico PS2 + micro-jitter no titulo (tubo cansado).
		if _boot_prompt != null:
			var fase := fmod(_tempo_titulo, 1.15)
			_boot_prompt.modulate.a = 1.0 if fase < 0.72 else 0.15
		if _boot_titulo != null and _boot_titulo.visible:
			# Tremor de tubo cansado, nos DOIS rotulos com o MESMO deslocamento e
			# a partir da MESMA origem. Aqui moravam dois literais — (20,74) na
			# letra e (18,70) no halo — que desfaziam, a cada quadro, o
			# alinhamento que o construtor tinha acabado de montar: o halo saia
			# 2 px a esquerda e 4 px acima, e a captura mostrava o titulo batido,
			# como impressao fora de registro. Ver `_fazer_titulo_serif`.
			var jx := sin(_tempo_titulo * 23.0) * 0.45 + sin(_tempo_titulo * 7.1) * 0.2
			var jy := cos(_tempo_titulo * 19.0) * 0.35
			var tremor := BOOT_TITULO_ONDE + Vector2(jx, jy)
			_boot_titulo.position = tremor
			if _boot_titulo_glow != null:
				_boot_titulo_glow.position = tremor
		if _crt_mat != null:
			_crt_mat.set_shader_parameter(&"grain", 0.66 + 0.1 * sin(_tempo_titulo * 3.1))
		return
	if painel != Painel.TITULO:
		return
	if _titulo_rotulo != null and not _animando_titulo:
		var a := 0.92 + 0.08 * sin(_tempo_titulo * 0.7)
		_titulo_rotulo.modulate.a = a
	if _selecionado < _itens_titulo.size() and not _animando_titulo:
		var pulso := 0.88 + 0.12 * sin(_tempo_titulo * 2.4)
		_itens_titulo[_selecionado].modulate.a = pulso


## Nome pre-digitado por linha de comando, so para captura e verificacao:
## `--nome-teste=JOTA`. O pente de caracteres e a peca central desta tela e ele
## so mostra o que faz com o campo preenchido; sem isto, toda conferencia dele
## passava por alguem digitar a mao com o jogo aberto. Mesmo padrao do
## `--criacao-aba=` da tela seguinte.
func _nome_de_teste() -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--nome-teste="):
			return a.trim_prefix("--nome-teste=").to_upper().substr(0, MAX_NOME)
	return ""


func _atualizar_campo() -> void:
	if _no_nome != null:
		_no_nome.definir_nome(_nome_digitado)


## O limite sai do pente de caracteres da folha, e nao de um numero repetido
## aqui: se a ficha ganhar uma caixa, o teclado ganha uma letra junto.
const MAX_NOME := FichaCadastro.CAIXAS


func _digitar(evento: InputEvent) -> void:
	# Durante a batida do carimbo a folha nao aceita tecla. Sem esta guarda, um
	# segundo ENTER entra com `carimbar` ja recusando (a folha esta em queda),
	# e o `await` do segundo `_assinar` fica pendurado num sinal que so vai ser
	# emitido uma vez — a tela trava sem erro nenhum no log.
	if _no_nome != null and _no_nome.ocupada():
		get_viewport().set_input_as_handled()
		return
	var tecla := evento as InputEventKey
	if tecla != null and tecla.pressed and not tecla.echo:
		if tecla.keycode == KEY_BACKSPACE:
			_nome_digitado = _nome_digitado.substr(0,
				maxi(0, _nome_digitado.length() - 1))
			# Apagar soa mais grave que escrever: e a mesma amostra, e o ouvido
			# separa os dois gestos so pela altura.
			AudioDirector.tocar_ui(&"clique", -18.0, 0.82)
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
			# Afinacao sorteada em torno de um. Doze teclas seguidas com a MESMA
			# amostra na MESMA altura e o que faz o ouvido reconhecer o arquivo
			# em vez de ouvir alguem escrevendo — o mesmo motivo pelo qual os
			# passos do jogo ja sorteiam afinacao.
			AudioDirector.tocar_ui(&"clique", -20.0, randf_range(0.94, 1.09))
			_atualizar_campo()
			get_viewport().set_input_as_handled()
			return

	if evento.is_action_pressed("pausa"):
		mostrar(Painel.TITULO)
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("interagir"):
		_assinar()
		get_viewport().set_input_as_handled()


## Assinar: o carimbo bate na folha, e SO ENTAO a carteira aparece.
##
## Antes daqui era um corte seco — ENTER, a folha some, a carteira ja pronta —
## e nada entre as duas dizia o que tinha acontecido. Meio segundo de carimbo
## caindo em cima da assinatura transforma o corte em consequencia: a tela
## seguinte passa a ser o documento que ACABOU de ser emitido, e nao a proxima
## pagina de um menu.
##
## Nome vazio continua valido: o registro sorteia um. Obrigar a digitar so para
## poder comecar e pedagio, e o proprio painel ja disse que quase tudo e
## sorteado.
##
## A ficha nasce AQUI, e nao no fim: a tela seguinte mostra o retrato, o nome e
## o CPF da pessoa que o registro acabou de emitir, e precisa dela pronta.
func _assinar() -> void:
	if _no_nome != null and _no_nome.carimbar():
		await _no_nome.carimbou
		# Meio segundo e tempo suficiente para o painel ter mudado por fora —
		# `esconder` no encerramento, uma bandeira de captura, um clique que
		# chegou antes. Retomar depois de um `await` sem conferir onde a tela
		# esta e a forma classica de um menu abrir sozinho depois de fechado.
		if painel != Painel.NOME:
			return
	AudioDirector.tocar_ui(&"pegar", -8.0)
	RegistroCivil.criar_jogador(_nome_digitado.strip_edges())
	mostrar(Painel.APARENCIA)


func _ajustar(passo: int) -> void:
	var aplicar: Callable = _opcoes[_selecionado]["aplicar"]
	aplicar.call(passo)
	AudioDirector.tocar_ui(&"clique", -16.0)
	_atualizar()


## Acionar o item escolhido.
##
## Despacha por NOME e nao por indice, e isso e conserto e nao estilo. O `match
## _selecionado` com 0,1,2,3 embutia a ordem da lista em dois lugares — a lista e
## aqui — e no dia em que CARREGAR entrou entre CONTINUAR e NOVO JOGO, cada item
## passou a fazer o trabalho do vizinho de cima. Erro que nao da aviso nenhum:
## MAPA abriria OPCOES e SAIR fecharia o jogo a partir de OPCOES.
func _acionar() -> void:
	if painel == Painel.OPCOES:
		AudioDirector.tocar_ui(&"pegar", -10.0)
		_ajustar(1)
		return
	if painel == Painel.CARREGAR:
		# Painel RE7 emite pediu_carregar; lista legado so se ainda existir.
		if _save_panel != null and _itens_espacos.is_empty():
			return
		_acionar_espaco()
		return

	var qual := TituloLayout.ITENS[clampi(_selecionado, 0, TituloLayout.ITENS.size() - 1)]
	# Item apagado responde, e responde dizendo por que. Antes ele engolia a
	# tecla: o jogador apertava E em CONTINUAR sem save e a tela nao fazia nada,
	# nem som, nem letra. Silencio nao e resposta.
	if not _item_vivo(qual):
		AudioDirector.tocar_ui(&"clique", -20.0, 0.72)
		return
	AudioDirector.tocar_ui(&"pegar", -10.0)
	match qual:
		"CONTINUAR":
			if SaveGame.carregar(_ultimo_espaco()):
				esconder()
				continuar.emit()
		"CARREGAR":
			mostrar(Painel.CARREGAR)
		"NOVO JOGO":
			mostrar(Painel.NOME)
		"MAPA":
			mostrar(Painel.MAPA)
		"OPCOES":
			mostrar(Painel.OPCOES)
		_:
			sair.emit()
			get_tree().quit(0)


## O item pode ser acionado? Hoje so CONTINUAR e CARREGAR tem como estar mortos,
## e os dois pelo mesmo motivo: nao ha jogo gravado em espaco nenhum.
func _item_vivo(qual: String) -> bool:
	# Nada de jogar antes de os shaders compilarem: ver `AquecimentoDeShaders`.
	if qual in ["CONTINUAR", "CARREGAR", "NOVO JOGO"] and not AquecimentoDeShaders.pronto():
		return false
	if qual == "CONTINUAR" or qual == "CARREGAR":
		return _ultimo_espaco() >= 0
	return true


## O espaco de save mais recente, ou -1 se nao ha nenhum.
##
## CONTINUAR sempre carregou o espaco 0 e mais nada. Com tres espacos alcancaveis
## pela tela ao lado, continuar no 0 faria o botao mentir para quem gravou no 2:
## "continuar" e voltar para onde se estava, e nao para o primeiro arquivo.
func _ultimo_espaco() -> int:
	var melhor := -1
	var quando := ""
	for i in SaveGame.ESPACOS:
		if not SaveGame.existe(i):
			continue
		var q := String(SaveGame.resumo(i).get("quando", ""))
		# `quando` e `Time.get_datetime_string_from_system`, que ordena como
		# texto: 2026-09-16T00:14 é maior que 2026-09-15T23:59 por comparacao
		# direta, sem precisar converter para data.
		if melhor < 0 or q > quando:
			melhor = i
			quando = q
	return melhor


## Aciona um espaco da pagina CARREGAR.
func _acionar_espaco() -> void:
	var n := _selecionado
	if n >= SaveGame.ESPACOS:
		AudioDirector.tocar_ui(&"pegar", -10.0)
		mostrar(Painel.TITULO)
		return
	if not SaveGame.existe(n):
		AudioDirector.tocar_ui(&"clique", -20.0, 0.72)
		return
	AudioDirector.tocar_ui(&"pegar", -10.0)
	if SaveGame.carregar(n):
		esconder()
		continuar.emit()
