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
const FONTE_P := "res://assets/fontes/psx_pequena.fnt"
const FONTE_M := "res://assets/fontes/psx_media.fnt"
const FONTE_T := "res://assets/fontes/psx_titulo.fnt"
## Serif TTF da referencia CRT (tall/narrow via FontVariation).
const FONTE_SERIF_TITULO := "res://assets/fontes/serif_titulo.ttf"
const FONTE_SERIF_CORPO := "res://assets/fontes/serif_corpo.ttf"
const BOOT_PLATE := "res://assets/ui/ui_boot_plate.png"

const TELA := Vector2(480.0, 270.0)
const TINTA := Color("2a1f16")
const TINTA_FRACA := Color("5a4a38")
const DESTAQUE := Color("8a2f1f")
## Oxblood da referencia CRT. Facil de trocar se o titulo mudar de nome.
const TITULO_TEXTO := "SHIMOKAWA"
const TITULO_COR := Color("7a141c")
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

enum Painel { BOOT, TITULO, OPCOES, MAPA, NOME, APARENCIA }

signal jogar(nome: String)
signal continuar()
signal sair()
signal boot_iniciar()

var painel: Painel = Painel.TITULO
var _selecionado: int = 0

var _raiz: Control
var _itens_titulo: Array[Label] = []
var _abas_titulo: Array[TextureRect] = []
var _itens_opcoes: Array[Label] = []
var _no_titulo: Control
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
	# Cidade decide se abre o titulo (primeira vez) ou esconde (testes/captura).
	visible = false


# --- definicao das opcoes ---------------------------------------------------

func _definir_opcoes() -> void:
	# A lista vem de `OpcoesLista`, que o menu de sistema em jogo tambem le.
	# Duas copias divergiriam no primeiro ajuste, e o jogador veria um painel com
	# sete opcoes e outro com seis, os dois dizendo que sao as opcoes do jogo.
	_opcoes = OpcoesLista.video()
	# Som na MESMA folha, e nao num painel a parte. Sao quatro deslizadores: um
	# submenu para quatro linhas custa uma tela, uma tecla para entrar e outra
	# para sair, e nao esconde nada que precise ser escondido.
	_opcoes.append_array(OpcoesLista.audio())
	_opcoes.append({
		"rotulo": "VOLTAR",
		"ler": func() -> String: return "",
		"aplicar": func(_passo: int) -> void: mostrar(Painel.TITULO),
	})


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
	# Tamanho na mao, e nao so ancora.
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
	_mata_vp.size = Vector2i(int(TELA.x), int(TELA.y))
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
	if _fundo_mata == null or _mata_vp == null:
		return
	_mata_vp.render_target_update_mode = (SubViewport.UPDATE_ALWAYS
		if ligado else SubViewport.UPDATE_DISABLED)
	_fundo_mata.visible = ligado
	if _scrim != null:
		_scrim.visible = ligado
	if ligado and _mata_cena != null:
		_mata_cena.enquadrar_menu(true)
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


func _aplicar_crt_boot() -> void:
	if _crt_mat == null:
		return
	_crt_mat.set_shader_parameter(&"burst", 0.0)
	_crt_mat.set_shader_parameter(&"opacity", 1.0)
	_crt_mat.set_shader_parameter(&"bw", 0.22)
	if _fundo_vivo:
		# Sala 3D atras: o veu afrouxa para ela aparecer, e o desfoque quase some
		# — desfocar uma cena com profundidade e jogar a profundidade fora.
		_crt_mat.set_shader_parameter(&"grain", 0.54)
		_crt_mat.set_shader_parameter(&"scanline", 0.44)
		_crt_mat.set_shader_parameter(&"vignette", 0.80)
		_crt_mat.set_shader_parameter(&"glow", 0.40)
		_crt_mat.set_shader_parameter(&"scene_mix", 0.92)
		_crt_mat.set_shader_parameter(&"soft_blur", 0.18)
		return
	# Rede: placa industrial desfocada, enquanto o interior ainda monta.
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
	_crt_mat.set_shader_parameter(&"grain", 0.26)
	_crt_mat.set_shader_parameter(&"scanline", 0.30)
	_crt_mat.set_shader_parameter(&"vignette", 0.56)
	_crt_mat.set_shader_parameter(&"glow", 0.12)
	_crt_mat.set_shader_parameter(&"bw", 1.0)
	_crt_mat.set_shader_parameter(&"burst", 0.0)
	_crt_mat.set_shader_parameter(&"opacity", 0.58)
	_crt_mat.set_shader_parameter(&"scene_mix", 0.9)
	_crt_mat.set_shader_parameter(&"soft_blur", 0.0)


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


## Intensidade do burst de estatica (0..1). Usado na transicao do Start.
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

	# Glow suave atras do titulo (halo claro da referencia).
	_boot_titulo_glow = Label.new()
	_boot_titulo_glow.text = TITULO_TEXTO
	_boot_titulo_glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boot_titulo_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boot_titulo_glow.add_theme_color_override(&"font_color", Color(0.82, 0.8, 0.78, 0.22))
	_boot_titulo_glow.add_theme_color_override(&"font_outline_color", Color(0.9, 0.88, 0.85, 0.35))
	_boot_titulo_glow.add_theme_constant_override(&"outline_size", 14)
	if _fonte_boot_titulo != null:
		_boot_titulo_glow.add_theme_font_override(&"font", _fonte_boot_titulo)
		_boot_titulo_glow.add_theme_font_size_override(&"font_size", 44)
	_no_boot.add_child(_boot_titulo_glow)
	_boot_titulo_glow.position = Vector2(18.0, 70.0)
	_boot_titulo_glow.size = Vector2(444.0, 52.0)

	_boot_titulo = Label.new()
	_boot_titulo.text = TITULO_TEXTO
	_boot_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boot_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boot_titulo.add_theme_color_override(&"font_color", TITULO_COR)
	# Halo externo claro + contorno escuro interno (peso NERD GIRL HAUL).
	_boot_titulo.add_theme_color_override(&"font_shadow_color", Color(0.75, 0.72, 0.7, 0.45))
	_boot_titulo.add_theme_constant_override(&"shadow_offset_x", 0)
	_boot_titulo.add_theme_constant_override(&"shadow_offset_y", 0)
	_boot_titulo.add_theme_constant_override(&"shadow_outline_size", 10)
	_boot_titulo.add_theme_color_override(&"font_outline_color", Color(0.04, 0.0, 0.0, 0.8))
	_boot_titulo.add_theme_constant_override(&"outline_size", 4)
	if _fonte_boot_titulo != null:
		_boot_titulo.add_theme_font_override(&"font", _fonte_boot_titulo)
		_boot_titulo.add_theme_font_size_override(&"font_size", 42)
	_no_boot.add_child(_boot_titulo)
	_boot_titulo.position = Vector2(20.0, 74.0)
	_boot_titulo.size = Vector2(440.0, 48.0)

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
	elif ResourceLoader.exists(FONTE_M):
		_boot_prompt.add_theme_font_override(&"font", load(FONTE_M))
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
	elif ResourceLoader.exists(FONTE_P):
		_boot_rodape.add_theme_font_override(&"font", load(FONTE_P))
	_no_boot.add_child(_boot_rodape)
	_boot_rodape.position = Vector2(20.0, 246.0)
	_boot_rodape.size = Vector2(440.0, 14.0)
	_no_boot.visible = false


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

	_titulo_rotulo = _rotulo(_no_titulo, TITULO_TEXTO, Vector2(40.0, 28.0),
		Vector2(400.0, 30.0), FONTE_T, TITULO_COR, HORIZONTAL_ALIGNMENT_CENTER)
	_titulo_rotulo.add_theme_color_override(&"font_outline_color",
		Color(0.02, 0.0, 0.0, 0.85))
	_titulo_rotulo.add_theme_constant_override(&"outline_size", 5)

	_subtitulo_rotulo = _rotulo(_no_titulo, "suburbio · nevoa · madrugada",
		Vector2(40.0, 58.0), Vector2(400.0, 14.0), FONTE_P,
		Color(0.72, 0.7, 0.66), HORIZONTAL_ALIGNMENT_CENTER)
	_subtitulo_rotulo.add_theme_color_override(&"font_outline_color",
		Color(0.0, 0.0, 0.0, 0.75))
	_subtitulo_rotulo.add_theme_constant_override(&"outline_size", 3)

	var entradas := ["CONTINUAR", "NOVO JOGO", "MAPA", "OPCOES", "SAIR"]
	for i in entradas.size():
		var y := 96.0 + float(i) * 24.0
		var aba := TextureRect.new()
		aba.mouse_filter = Control.MOUSE_FILTER_IGNORE
		aba.modulate.a = 0.0
		_no_titulo.add_child(aba)
		aba.position = Vector2(140.0, y - 2.0)
		aba.size = Vector2(200.0, 20.0)
		_abas_titulo.append(aba)
		var item := _rotulo(_no_titulo, entradas[i], Vector2(90.0, y),
			Vector2(300.0, 18.0), FONTE_M, Color(0.88, 0.86, 0.8),
			HORIZONTAL_ALIGNMENT_CENTER)
		item.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		item.add_theme_constant_override(&"outline_size", 4)
		_itens_titulo.append(item)

	_dica_titulo = _rotulo(_no_titulo, "[W/S] mover    [E] escolher",
		Vector2(0.0, TELA.y - 22.0), Vector2(TELA.x, 14.0), FONTE_P,
		Color(0.78, 0.76, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	_dica_titulo.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_dica_titulo.add_theme_constant_override(&"outline_size", 4)


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

	_imagem(_no_opcoes, "ui_papel", Vector2(48.0, 30.0), Vector2(384.0, 200.0),
		TextureRect.STRETCH_TILE).modulate = PAPEL
	_rotulo(_no_opcoes, "OPCOES", Vector2(48.0, 40.0), Vector2(384.0, 24.0),
		FONTE_T, TINTA, HORIZONTAL_ALIGNMENT_CENTER)

	# Onze linhas dentro de uma folha que vai de y=30 a y=230.
	#
	# A conta, e nao o chute: comeco em 68 (logo abaixo do titulo), passo de 14, a
	# ultima linha nasce em 68 + 10*14 = 208 e a fonte tem 13 de altura, entao ela
	# acaba em 221 — nove pixels antes da borda. Com o passo de 20 que a lista
	# usava quando tinha sete opcoes, a ultima caia 46 px fora do papel; com 15,
	# caia 3 px fora, que a captura pegou e o olho quase nao.
	for i in _opcoes.size():
		var y := 68.0 + float(i) * 14.0
		_rotulo(_no_opcoes, _opcoes[i]["rotulo"], Vector2(74.0, y),
			Vector2(150.0, 14.0), FONTE_P, TINTA)
		_itens_opcoes.append(_rotulo(_no_opcoes, "", Vector2(228.0, y),
			Vector2(180.0, 14.0), FONTE_P, TINTA_FRACA))

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
	var vinha_titulo := visible and painel == Painel.TITULO
	painel = qual
	_selecionado = 0
	_boot_pronto = qual == Painel.BOOT
	if _no_boot != null:
		_no_boot.visible = qual == Painel.BOOT
	_no_titulo.visible = qual == Painel.TITULO
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
	# Boot e titulo deixam o mundo vivo. Outros paineis pausam.
	var vivo := qual == Painel.BOOT or qual == Painel.TITULO
	set_process(vivo)
	visible = true
	get_tree().paused = not vivo
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_atualizar()
	if qual == Painel.TITULO and not vinha_titulo and not _transicionando:
		_animar_entrada_titulo()


## CRT no boot/titulo. Colagem nos paineis de papel. Letterbox some — identidade CRT.
func _aplicar_fundo(qual: Painel) -> void:
	var boot := qual == Painel.BOOT
	var titulo := qual == Painel.TITULO
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
func _animar_entrada_titulo() -> void:
	_animando_titulo = true
	_tempo_titulo = 0.0
	if _fade_preto != null:
		_fade_preto.visible = true
		_fade_preto.color.a = 1.0
	if _titulo_rotulo != null:
		_titulo_rotulo.modulate.a = 0.0
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
	if _fade_preto != null:
		tw.tween_property(_fade_preto, "color:a", 0.0, 0.85)
	if _barra_topo != null:
		tw.parallel().tween_property(_barra_topo, "position:y", 0.0, 0.55)
	if _barra_base != null:
		tw.parallel().tween_property(_barra_base, "position:y", TELA.y - 28.0, 0.55)
	if _titulo_rotulo != null:
		tw.parallel().tween_property(_titulo_rotulo, "modulate:a", 1.0, 0.5).set_delay(0.25)
	if _subtitulo_rotulo != null:
		tw.parallel().tween_property(_subtitulo_rotulo, "modulate:a", 1.0, 0.45).set_delay(0.4)
	for i in _itens_titulo.size():
		var atraso := 0.5 + float(i) * 0.07
		var y_final := _itens_titulo[i].position.y - 6.0
		tw.parallel().tween_property(_itens_titulo[i], "modulate:a", 1.0, 0.28).set_delay(atraso)
		tw.parallel().tween_property(_itens_titulo[i], "position:y", y_final, 0.32).set_delay(atraso)
		if i < _abas_titulo.size():
			var y_aba := _abas_titulo[i].position.y - 6.0
			tw.parallel().tween_property(_abas_titulo[i], "modulate:a", 1.0, 0.28).set_delay(atraso)
			tw.parallel().tween_property(_abas_titulo[i], "position:y", y_aba, 0.32).set_delay(atraso)
	if _dica_titulo != null:
		tw.parallel().tween_property(_dica_titulo, "modulate:a", 1.0, 0.35).set_delay(0.9)
	tw.finished.connect(func() -> void:
		_animando_titulo = false
		if _fade_preto != null:
			_fade_preto.visible = false
	)


func esconder() -> void:
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
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _atualizar() -> void:
	var cor_ok := Color(0.9, 0.88, 0.82)
	var cor_morta := Color(0.45, 0.42, 0.38)
	for i in _itens_titulo.size():
		var ativo := painel == Painel.TITULO and i == _selecionado
		_itens_titulo[i].add_theme_color_override(&"font_color",
			TITULO_COR if ativo else cor_ok)
		if i < _abas_titulo.size():
			_abas_titulo[i].modulate.a = 0.0
			_abas_titulo[i].scale = Vector2.ONE
	if _itens_titulo.size() > 0:
		var cont_ativo := painel == Painel.TITULO and _selecionado == 0
		var tem_save := SaveGame.existe(0)
		_itens_titulo[0].add_theme_color_override(&"font_color",
			TITULO_COR if cont_ativo else (cor_ok if tem_save else cor_morta))

	for i in _opcoes.size():
		var ativo := painel == Painel.OPCOES and i == _selecionado
		var ler: Callable = _opcoes[i]["ler"]
		_itens_opcoes[i].text = ("> " if ativo else "") + str(ler.call())
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
	# Audio one-shot fica com cidade._transicao_tv_e_menu (evita Bzum duplo).
	definir_estatica(1.0, 1.0)
	if _boot_titulo != null:
		_boot_titulo.visible = false
	if _boot_prompt != null:
		_boot_prompt.visible = false
	if _boot_rodape != null:
		_boot_rodape.visible = false
	boot_iniciar.emit()
	get_viewport().set_input_as_handled()


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
			var jx := sin(_tempo_titulo * 23.0) * 0.45 + sin(_tempo_titulo * 7.1) * 0.2
			var jy := cos(_tempo_titulo * 19.0) * 0.35
			_boot_titulo.position = Vector2(20.0 + jx, 74.0 + jy)
			if _boot_titulo_glow != null:
				_boot_titulo_glow.position = Vector2(18.0 + jx, 70.0 + jy)
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
