## A ficha do registro civil: a folha que o jogador preenche antes de existir.
##
## O que ela era, e por que nao servia
## -----------------------------------
## Um retangulo de papel com uma fita marrom em cima, o titulo escrito em creme
## POR CIMA da fita (texto claro sobre marrom sujo: a linha menos legivel da
## tela era justamente o nome dela), um rotulo, um sublinhado e tres frases
## soltas explicando que o resto vinha sorteado. Nada ali era uma ficha — era um
## aviso em cima de uma folha.
##
## O que ela e agora
## -----------------
## Um FORMULARIO, com as partes que um formulario tem: cabecalho de orgao,
## numero de modelo, campos numerados, pente de caracteres para o unico campo
## que se escreve, campos hachurados para os que o cartorio preenche, carimbo e
## protocolo. A explicacao que antes eram tres frases no vazio agora tem do que
## falar: o jogador VE os campos bloqueados e le uma nota curta ao lado deles.
##
## Legibilidade, que era a queixa
## ------------------------------
##   - o titulo virou tarja: papel sobre tinta, o contraste maximo que a paleta
##     tem, no lugar de creme sobre fita marrom;
##   - todo texto sai no corpo NATIVO da fonte de bitmap que o desenha (11, 14 e
##     18). Pedir onze pixels a uma fonte de quatorze reamostra o glifo e e o
##     que borrava metade dos rotulos do jogo;
##   - o nome digitado sai em caixas de vinte e seis pixels na fonte de titulo,
##     e nao numa linha pautada — em 480x270 uma letra por caixa e a diferenca
##     entre ler e adivinhar;
##   - o texto e desenhado RETO. So a folha e a sombra dela inclinam. Girar um
##     glifo de bitmap um grau e meio serrilha a haste inteira, e esta tela ja
##     tinha pagado esse preco.
class_name FichaCadastro
extends Control

const UI := "res://assets/ui/%s.png"
const FONTE_P := "res://assets/fontes/psx_pequena.fnt"
const FONTE_M := "res://assets/fontes/psx_media.fnt"
const FONTE_T := "res://assets/fontes/psx_titulo.fnt"
const FONTE_MONO := "res://assets/fontes/psx_mono.fnt"

const TELA := Vector2(480.0, 270.0)

## Quantas letras cabem no nome. E o pente de caracteres que manda: o campo tem
## doze caixas porque o nome tem doze letras, e nao o contrario.
const CAIXAS := 12

## A folha. Ocupa quase a tela toda de proposito — a queixa era "simples demais",
## e meia folha no meio de um fundo escuro e o que faz um painel parecer um
## aviso de sistema em vez de um documento na mao.
const FOLHA := Rect2(50.0, 22.0, 380.0, 222.0)
const MARGEM := 16.0
const INCLINACAO := -1.1

const PAPEL := Color("e9e3cf")
const PAPEL_FUNDO := Color("dcd5be")
## A segunda via, em papel azulado, aparecendo por baixo. Um formulario de
## cartorio nunca e uma folha so, e esse filete e o que diz isso sem texto.
const COPIA := Color("c8cdd2")
const TINTA := Color("241b12")
## Ja foi mais claro. Sobre papel amarelado, tinta fraca demais e o que fazia a
## nota de rodape sumir — e legibilidade era a queixa que abriu esta reforma.
const TINTA_FRACA := Color("57472f")
const RASURA := Color("8a2f1f")

## Quanto tempo o carimbo leva do alto ate o papel, e de que altura ele vem.
##
## Meio segundo e o teto: e um gesto de balcao, nao uma cutscene, e quem esta
## nesta tela quer chegar na proxima. Escala de partida em 2,6 porque abaixo
## disso o carimbo nao chega a sair do proprio lugar e o movimento le como um
## pulsar, e nao como uma coisa vindo de cima.
const CARIMBO_TEMPO := 0.52
const CARIMBO_ALTURA := 2.6
## Quanto o carimbo fica parado no papel antes de a tela virar.
const CARIMBO_POUSO := 0.16

signal carimbou()
## Clique na linha de assinatura. Quem decide o que assinar significa e o Menu.
signal pediu_assinar()

var _relogio: float = 0.0
var _nome: String = ""
## 0 = sem carimbo; sobe ate 1 durante a batida e fica.
var _carimbo: float = 0.0
var _carimbando: bool = false
var _bateu: bool = false
var _carimbo_de_teste: bool = false
var _pouso: float = 0.0

var _pequena: Font
var _media: Font
var _titulo: Font
var _mono: Font
var _brasao: Texture2D
var _papel: Texture2D
var _vinheta: Texture2D

## Textura viva da cabine, injetada pelo Menu.
##
## E o MESMO SubViewport que a criacao de personagem usa — nao um segundo mundo.
## As duas telas acontecem no mesmo lugar, no mesmo minuto: ele parou o carro na
## estrada para preencher a ficha e, na tela seguinte, confere a carteira que
## saiu dela. Repetir o fundo e o que costura as duas; montar um mundo proprio
## aqui custaria uma estrada inteira para dizer a mesma coisa pior.
var fundo: Texture2D


func _ready() -> void:
	# O Menu pausa a arvore neste painel; o cursor e o balanco tem de continuar.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Aceita mouse. A tela seguinte, a carteira, e clicavel inteira — abas,
	# celulas e o visto de aceite — e esta oferecia uma linha de assinatura com
	# um "X" de assine-aqui em cima dela que nao respondia a clique nenhum.
	# Duas telas seguidas com vocabularios de entrada diferentes ensinam ao
	# jogador uma regra que a proxima tela desmente.
	mouse_filter = Control.MOUSE_FILTER_STOP
	# `set_anchors_and_offsets_preset`, e nao `set_anchors_preset`.
	#
	# A versao sem offsets PRESERVA o retangulo que o Control tem na hora, e na
	# hora ele nao tem nenhum: nasce zero por zero e as offsets sao calculadas
	# para manter zero por zero. Depois o pai cresce, as ancoras acompanham, e
	# as offsets negativas anulam o crescimento — o Control fica com area zero
	# para sempre. Desenha certo (draw_* nao usa o retangulo) e nao recebe
	# clique nenhum.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pequena = _fonte(FONTE_P)
	_media = _fonte(FONTE_M)
	_titulo = _fonte(FONTE_T)
	_mono = _fonte(FONTE_MONO)
	_brasao = _textura("doc_brasao")
	_papel = _textura("ui_papel")
	_vinheta = _textura("ui_vinheta")
	_carimbo_de_teste = OS.get_cmdline_user_args().has("--ficha-carimbo")


func _process(delta: float) -> void:
	# `PROCESS_MODE_ALWAYS` roda mesmo com a arvore pausada E com o painel
	# escondido. Sem esta guarda a folha ficaria pedindo redesenho a sessenta
	# quadros por segundo pela partida inteira, atras do jogo.
	if not visible:
		return
	_relogio += delta
	_avancar_carimbo(delta)
	queue_redraw()


## Publica: bate o carimbo e avisa quando ele pousou.
##
## Devolve `false` se nao ha o que fazer — carimbo ja em queda ou ja batido.
## Quem chama espera pelo sinal `carimbou`, entao devolver `false` sem emitir
## sinal nenhum penduraria o menu para sempre: por isso o `_ocupada` do menu
## barra a segunda tecla antes de chegar aqui.
func carimbar() -> bool:
	if _carimbando or _bateu:
		return false
	_carimbando = true
	_carimbo = 0.0
	AudioDirector.tocar_ui(&"papel", -20.0, 1.15)
	return true


## Se a folha esta no meio de um gesto e nao deve aceitar tecla.
func ocupada() -> bool:
	return _carimbando


## Volta a folha ao estado de em branco.
##
## O menu chama toda vez que abre o painel. Voltar da carteira com ESC e
## encontrar a ficha ja carimbada diria que o registro esta feito — e a tela
## nao aceitaria mais nada, porque `carimbar` recusa uma folha ja batida.
func reiniciar() -> void:
	_carimbo = 0.0
	_carimbando = false
	_bateu = false
	if _carimbo_de_teste:
		# `--ficha-carimbo`: bate assim que a folha abre, para a queda poder ser
		# conferida por captura. O quadro escolhido em `--shot-frame` vira o
		# instante da batida — e o unico jeito de olhar uma animacao de meio
		# segundo sem alguem com o dedo no ENTER e o olho no monitor.
		carimbar()
	queue_redraw()


func _avancar_carimbo(delta: float) -> void:
	if not _carimbando:
		return
	if _carimbo < 1.0:
		_carimbo = minf(1.0, _carimbo + delta / CARIMBO_TEMPO)
		if _carimbo < 1.0:
			return
		_bateu = true
		# O estalo do interruptor puxado bem para baixo: borracha batendo em
		# papel apoiado em coxa nao tem agudo. Reaproveitar a amostra sai mais
		# barato que um WAV novo e, nesta afinacao, ninguem reconhece o
		# interruptor.
		AudioDirector.tocar_ui(&"interruptor", -4.0, 0.55)
		_pouso = CARIMBO_POUSO
		return
	# A pausa depois da batida. Sem ela o corte acontece no MESMO quadro em que
	# o carimbo pousa, e o jogador ouve o baque de uma coisa que nunca chegou a
	# ver parada — o gesto inteiro se perde no corte que ele deveria justificar.
	_pouso -= delta
	if _pouso > 0.0:
		return
	_carimbando = false
	carimbou.emit()


## O nome digitado ate agora. O Menu continua dono do teclado; esta tela so
## mostra o que ele juntou.
func definir_nome(txt: String) -> void:
	if txt == _nome:
		return
	_nome = txt
	queue_redraw()


# --- mouse ------------------------------------------------------------------

## Onde se clica para assinar: a linha do campo 05 e a folga em volta dela.
##
## Generosa de proposito. O alvo real e um risco de um pixel de espessura, e
## caçar um risco de um pixel com o mouse numa tela de 480x270 e um teste de
## pontaria, nao uma escolha.
func _area_assinatura() -> Rect2:
	var dir := FOLHA.end.x - MARGEM
	return Rect2(dir - 122.0, 198.0, 126.0, 46.0)


## Converte a coordenada local do Control para o espaco logico de 480x270.
##
## Com o esticamento de viewport o tamanho costuma ja ser TELA; a conta cobre o
## letterbox e a escala. Mesma funcao da carteira, pelo mesmo motivo.
func _para_tela(local: Vector2) -> Vector2:
	if size.x <= 1.0 or size.y <= 1.0:
		return local
	return Vector2(local.x * TELA.x / size.x, local.y * TELA.y / size.y)


func _gui_input(evento: InputEvent) -> void:
	if _carimbando or _bateu:
		return
	if evento is InputEventMouseMotion:
		var mm := evento as InputEventMouseMotion
		mouse_default_cursor_shape = (Control.CURSOR_POINTING_HAND
			if _area_assinatura().has_point(_para_tela(mm.position))
			else Control.CURSOR_ARROW)
		return
	var mb := evento as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _area_assinatura().has_point(_para_tela(mb.position)):
		accept_event()
		pediu_assinar.emit()


func _fonte(caminho: String) -> Font:
	return load(caminho) as Font if ResourceLoader.exists(caminho) else null


func _textura(nome: String) -> Texture2D:
	var c := UI % nome
	return load(c) as Texture2D if ResourceLoader.exists(c) else null


# --- desenho ----------------------------------------------------------------

func _draw() -> void:
	_desenhar_fundo()
	_desenhar_folha()
	_desenhar_cabecalho()
	_desenhar_campo_nome()
	_desenhar_campos_sorteados()
	_desenhar_nota()
	_desenhar_assinatura()
	_desenhar_carimbo()
	_desenhar_luz()
	_desenhar_rodape()


## A cabine atras, rebaixada.
##
## O fundo aqui e cenario, e cenario que disputa leitura com formulario perde a
## tela inteira: entra escurecido e com a vinheta por cima, para o papel ser a
## unica coisa clara do quadro. E assim que qualquer plano de alguem lendo um
## documento a noite e iluminado — a folha e a fonte, nao o ambiente.
func _desenhar_fundo() -> void:
	if fundo != null:
		draw_texture_rect(fundo, Rect2(Vector2.ZERO, TELA), false,
			Color(0.88, 0.88, 0.88, 1.0))
	else:
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.04, 0.045, 0.05))
	draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.02, 0.025, 0.03, 0.20))
	if _vinheta != null:
		draw_texture_rect(_vinheta, Rect2(Vector2.ZERO, TELA), false,
			Color(1.0, 1.0, 1.0, 0.75))


## O papel: sombra projetada, segunda via por baixo, folha, vinco e borda.
##
## E a unica parte da tela que entra torta. Coisa segurada na mao nao fica reta,
## e o jogo segue essa regra desde a prancha de inventario — mas o texto de cima
## dela fica reto, porque legibilidade ganha de gestualidade quando a tela pede
## para o jogador escrever.
func _desenhar_folha() -> void:
	_transformada_folha()
	var r := Rect2(-FOLHA.size * 0.5, FOLHA.size)

	# Sombra: baixa e deslocada para o lado oposto ao painel do carro, que e de
	# onde vem a luz quente que acende a folha.
	draw_rect(Rect2(r.position + Vector2(5.0, 7.0), r.size),
		Color(0.02, 0.03, 0.03, 0.45))
	# Segunda via, so a lasca que sobra por baixo.
	draw_rect(Rect2(r.position + Vector2(3.0, 4.0), r.size), COPIA.darkened(0.25))
	draw_rect(Rect2(r.position + Vector2(2.0, 3.0), r.size), COPIA)

	if _papel != null:
		draw_texture_rect(_papel, r, true, PAPEL)
	else:
		draw_rect(r, PAPEL)
	# Barra de sujeira nas duas pontas: papel de talao nao e branco na borda.
	draw_rect(Rect2(r.position, Vector2(r.size.x, 3.0)), PAPEL_FUNDO)
	draw_rect(Rect2(r.position.x, r.end.y - 3.0, r.size.x, 3.0), PAPEL_FUNDO)
	# Vinco de dobra: a folha veio dobrada em tres, como todo formulario de
	# guiche. Sao duas linhas de um pixel e elas fazem o papel ter passado.
	for t: float in [0.34, 0.68]:
		var x := r.position.x + r.size.x * t
		draw_line(Vector2(x, r.position.y + 2.0), Vector2(x, r.end.y - 2.0),
			Color(0.72, 0.68, 0.56, 0.30), 1.0)
		draw_line(Vector2(x + 1.0, r.position.y + 2.0), Vector2(x + 1.0, r.end.y - 2.0),
			Color(1.0, 0.99, 0.94, 0.22), 1.0)
	draw_rect(r, Color(0.55, 0.50, 0.40, 0.65), false, 1.0)
	# Filete de luz na aresta de cima: a folha tem espessura.
	draw_line(r.position, Vector2(r.end.x, r.position.y),
		Color(1.0, 0.99, 0.93, 0.55), 1.0)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Cabecalho de orgao: brasao, linha de republica, tarja e numero de modelo.
##
## A tarja e o conserto direto da queixa. O titulo era creme sobre a fita
## marrom, que e o pior contraste que esta paleta consegue produzir; agora e
## papel sobre tinta cheia, que e o melhor.
func _desenhar_cabecalho() -> void:
	var x := FOLHA.position.x + MARGEM
	var dir := FOLHA.end.x - MARGEM

	if _brasao != null:
		draw_texture_rect(_brasao, Rect2(x, 30.0, 18.0, 18.0), false,
			Color(0.30, 0.26, 0.20))
	_txt(_pequena, 11, Vector2(x + 24.0, 42.0), "REPUBLICA FEDERATIVA DO BRASIL",
		TINTA_FRACA)

	# O nome da tela vai na tarja, e a tarja e tinta cheia. A folha continua
	# sendo do registro civil — isso esta escrito logo abaixo — mas quem abre
	# esta tela precisa saber em uma olhada o que tem na mao, e o titulo era
	# justamente a linha mais ilegivel que ela tinha.
	var tarja := Rect2(x, 48.0, _largura(_media, 14, "FICHA DE CADASTRO") + 18.0,
		19.0)
	draw_rect(Rect2(tarja.position + Vector2(1.0, 2.0), tarja.size),
		Color(0.10, 0.09, 0.07, 0.25))
	draw_rect(tarja, TINTA)
	_txt(_media, 14, Vector2(tarja.position.x, 63.0), "FICHA DE CADASTRO",
		PAPEL, HORIZONTAL_ALIGNMENT_CENTER, tarja.size.x)
	_txt(_pequena, 11, Vector2(x, 80.0), "REGISTRO CIVIL DAS PESSOAS NATURAIS",
		TINTA_FRACA)

	# Bloco do modelo, encostado na direita. Caixa e nao texto solto: e o que
	# faz o canto parecer impresso pela grafica junto com o resto da folha.
	# Tres linhas: modelo, via e protocolo. O protocolo estava solto no rodape,
	# do lado direito, e era exatamente onde o campo da assinatura precisava
	# ficar — mas o lugar dele nunca foi o rodape: numero de protocolo e coisa
	# que a grafica imprime no cabecalho, junto do numero do modelo.
	var caixa := Rect2(dir - 98.0, 27.0, 98.0, 42.0)
	draw_rect(caixa, Color(0.86, 0.83, 0.71, 0.75))
	draw_rect(caixa, TINTA_FRACA, false, 1.0)
	_txt(_pequena, 11, Vector2(caixa.position.x, 39.0), "FORM. 3-B", TINTA,
		HORIZONTAL_ALIGNMENT_CENTER, caixa.size.x)
	_txt(_pequena, 11, Vector2(caixa.position.x, 52.0), "VIA UNICA", TINTA_FRACA,
		HORIZONTAL_ALIGNMENT_CENTER, caixa.size.x)
	_txt(_mono, 12, Vector2(caixa.position.x, 65.0), "03B-4410", TINTA_FRACA,
		HORIZONTAL_ALIGNMENT_CENTER, caixa.size.x)

	draw_line(Vector2(x, 87.0), Vector2(dir, 87.0), TINTA_FRACA, 1.0)


## O unico campo que o jogador preenche, e o unico que tem pente de caracteres.
##
## O pente resolve duas coisas de uma vez: uma letra por caixa e legivel num
## quadro de 480x270 onde uma linha corrida de fonte de titulo nao e, e as doze
## caixas dizem sozinhas quantas letras cabem — o limite deixa de ser uma regra
## invisivel que o jogador descobre batendo nela.
func _desenhar_campo_nome() -> void:
	var x := FOLHA.position.x + MARGEM
	_etiqueta("01", Vector2(x, 94.0))
	_txt(_pequena, 11, Vector2(x + 26.0, 105.0), "NOME DO DECLARANTE", TINTA)

	var largura := FOLHA.size.x - MARGEM * 2.0
	var passo := (largura + 3.0) / float(CAIXAS)
	var lado := passo - 3.0
	var letras := _nome.substr(0, CAIXAS)
	var cursor := letras.length() < CAIXAS and fmod(_relogio, 0.94) < 0.55

	for i in CAIXAS:
		var r := Rect2(x + float(i) * passo, 112.0, lado, 24.0)
		var atual := i == letras.length()
		draw_rect(r, Color(0.70, 0.67, 0.55, 0.60))
		# Fio escuro so no alto: a caixa afunda no papel em vez de flutuar.
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)),
			Color(0.52, 0.48, 0.38, 0.45))
		# So a base e cheia. Pente de formulario e uma serie de degraus, nao uma
		# grade fechada: com as quatro bordas em volta de cada letra o campo
		# vira tabuleiro e a palavra deixa de ser uma palavra.
		draw_rect(Rect2(r.position.x, r.end.y - 2.0, r.size.x, 2.0), TINTA_FRACA)
		draw_line(Vector2(r.position.x, r.end.y - 8.0),
			Vector2(r.position.x, r.end.y - 2.0), TINTA_FRACA, 1.0)
		draw_line(Vector2(r.end.x - 1.0, r.end.y - 8.0),
			Vector2(r.end.x - 1.0, r.end.y - 2.0), TINTA_FRACA, 1.0)
		if atual and cursor:
			draw_rect(Rect2(r.position.x, r.end.y - 2.0, r.size.x, 2.0), RASURA)
			draw_rect(r, Color(1.0, 0.98, 0.90, 0.30))
		if i < letras.length():
			_txt(_titulo, 18, Vector2(r.position.x, 132.0), letras.substr(i, 1),
				TINTA, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


## Os campos que o cartorio preenche, hachurados.
##
## Sao a premissa do jogo inteiro virada em desenho: a ficha do jogador ja
## existia antes de ele chegar, e o unico dado dela que lhe pertence e o nome.
## Antes isso era uma frase — "O RESTO DA FICHA E SORTEADO" — solta no meio do
## papel. Agora sao tres campos numerados, com rotulo, visivelmente trancados,
## e a frase virou uma nota de rodape explicando o que se esta vendo.
func _desenhar_campos_sorteados() -> void:
	var x := FOLHA.position.x + MARGEM
	var dir := FOLHA.end.x - MARGEM
	var rotulos := ["DATA DE NASCIMENTO", "NATURALIDADE / UF", "FILIACAO"]
	var numeros := ["02", "03", "04"]

	# A coluna da hachura comeca depois do rotulo MAIS LARGO, medido e nao
	# chutado: com um numero fixo, trocar uma palavra de rotulo faz o texto
	# entrar por baixo da hachura e ninguem nota ate a captura.
	var col := 0.0
	for r: String in rotulos:
		col = maxf(col, _largura(_pequena, 11, r))
	col = x + 26.0 + col + 14.0

	draw_line(Vector2(x, 144.0), Vector2(dir, 144.0), TINTA_FRACA, 1.0)
	for i in rotulos.size():
		var base := 156.0 + float(i) * 17.0
		_etiqueta(numeros[i], Vector2(x, base - 11.0))
		_txt(_pequena, 11, Vector2(x + 26.0, base), rotulos[i], TINTA_FRACA)
		_hachurar(Rect2(col, base - 11.0, dir - 46.0 - col, 13.0))


## Nota de rodape. Curta, em tres linhas, encostada na esquerda para o carimbo
## ter o canto direito inteiro — texto por baixo de carimbo e exatamente o tipo
## de coisa que esta tela existe para deixar de fazer.
func _desenhar_nota() -> void:
	var x := FOLHA.position.x + MARGEM
	var linhas := [
		"OS CAMPOS HACHURADOS SAO",
		"PREENCHIDOS PELO CARTORIO.",
		"CONFIRA NA SUA CARTEIRA.",
	]
	# Regua fina separando os campos da nota. Sem ela a primeira linha da nota
	# encostava no rotulo do campo 04 e os dois liam como um paragrafo so.
	draw_line(Vector2(x, 202.0), Vector2(x + 214.0, 202.0),
		Color(TINTA_FRACA.r, TINTA_FRACA.g, TINTA_FRACA.b, 0.45), 1.0)
	for i in linhas.size():
		_txt(_pequena, 11, Vector2(x, 214.0 + float(i) * 12.0), linhas[i],
			TINTA_FRACA)


## O carimbo, torto e por cima dos campos trancados.
##
## Ele e o unico elemento que pode entrar torto sem custo, porque nao carrega
## informacao que precise ser lida com precisao — e carimbo reto le como
## impresso, nao como carimbado. A palavra e SORTEADO, e ela cai justamente em
## cima dos tres campos que o cartorio sorteou: o carimbo diz o que aquilo e,
## no lugar onde aquilo esta.
func _desenhar_carimbo() -> void:
	# A folga vertical entre o pente do nome e o rotulo da assinatura e de 58
	# pixels, e um carimbo de 46 de altura girado doze graus ocupa 68: nao cabia,
	# e ele saia por cima de um dos dois. A 96 por 34 ele ocupa 53 e passa a
	# caber inteiro na faixa dos tres campos hachurados, que e o unico lugar da
	# folha onde carimbo nao encobre coisa que se le.
	_bater_carimbo(Vector2(344.0, 166.0), Vector2(96.0, 34.0), -12.0,
		"SORTEADO", "REG. CIVIL", 1.0, 0.78)


## Um carimbo de borracha: moldura dupla, duas linhas e tinta gasta.
##
## `escala` e o que permite ele CAIR. Em repouso vale um; na batida vem de bem
## longe e chega em um, e como a moldura, o texto e a tinta saem todos da mesma
## conta, o carimbo inteiro se aproxima junto em vez de crescer em pedacos.
func _bater_carimbo(centro: Vector2, tam: Vector2, graus: float, linha1: String,
		linha2: String, escala: float, forca: float) -> void:
	if forca <= 0.005:
		return
	draw_set_transform(centro, deg_to_rad(graus), Vector2.ONE * escala)
	var r := Rect2(-tam * 0.5, tam)
	var cor := Color(RASURA.r, RASURA.g, RASURA.b, 0.78 * forca)
	draw_rect(r, Color(RASURA.r, RASURA.g, RASURA.b, 0.07 * forca))
	draw_rect(r, cor, false, 2.0)
	draw_rect(r.grow(-4.0), Color(cor.r, cor.g, cor.b, cor.a * 0.5), false, 1.0)
	_txt(_media, 14, Vector2(r.position.x, -2.0), linha1, cor,
		HORIZONTAL_ALIGNMENT_CENTER, tam.x)
	_txt(_pequena, 11, Vector2(r.position.x, 14.0), linha2, cor,
		HORIZONTAL_ALIGNMENT_CENTER, tam.x)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## O campo 05: onde o declarante assina.
##
## Era o buraco de interacao da tela. A carteira, que vem logo depois, tem um
## alvo de aceite visivel — a caixa do visto, que acende e se clica. A ficha
## nao tinha nada: o unico jeito de saber que ENTER fechava a folha era ler a
## linha de teclas la embaixo. Agora ela tem o alvo que um formulario de papel
## sempre teve, que e a linha de assinatura com o "X" na frente.
##
## O X pisca enquanto a assinatura esta em branco e apaga quando ela existe:
## e a mesma gramatica do visto que pulsa na tela seguinte, e nao um segundo
## vocabulario para a mesma acao a dez segundos de distancia.
func _desenhar_assinatura() -> void:
	var dir := FOLHA.end.x - MARGEM
	# A coluna da assinatura comeca onde a nota acaba. A nota mais comprida tem
	# duzentos e vinte pixels; sobram cento e dezoito ate a margem, e e nessa
	# faixa que o campo 05 inteiro tem de caber.
	var esq := dir - 118.0
	# Rotulo alto, longe da linha. Nao e folga estetica: o carimbo de REGISTRADO
	# pousa nesta coluna, e com o rotulo na altura da palavra do carimbo os dois
	# jogos de letra se intercalavam caractere a caractere e nenhum dos dois lia.
	# Oito pixels de diferenca de linha de base resolvem sem mover o carimbo.
	_txt(_pequena, 11, Vector2(esq, 204.0), "05 ASSINATURA", TINTA_FRACA)

	# A linha da assinatura fica na MESMA altura da ultima linha da nota. Duas
	# reguas a dois pixels de distancia leem como desalinho; na mesma altura,
	# leem como as duas colunas de um formulario impresso junto.
	var linha_y := 238.0
	draw_line(Vector2(esq, linha_y), Vector2(dir, linha_y), TINTA, 1.0)

	var assinado := _nome.strip_edges() != ""
	if not assinado:
		# O X de "assine aqui". Pisca devagar: e convite, nao alarme.
		var pulso := 0.55 + 0.45 * sin(_relogio * 3.4)
		var c := Vector2(esq + 6.0, linha_y - 5.0)
		var cor := Color(RASURA.r, RASURA.g, RASURA.b, pulso)
		draw_line(c + Vector2(-4.0, -4.0), c + Vector2(4.0, 4.0), cor, 1.6)
		draw_line(c + Vector2(4.0, -4.0), c + Vector2(-4.0, 4.0), cor, 1.6)
		return

	_desenhar_rubrica(Rect2(esq + 4.0, linha_y - 24.0, dir - esq - 8.0, 24.0))
	# Recuado da margem: o carimbo e mais largo que a coluna da assinatura, e
	# quem manda no centro dele e a borda da folha, nao o meio do campo.
	_desenhar_registro(Vector2(dir - 64.0, linha_y - 20.0))


## O carimbo de REGISTRADO descendo em cima da assinatura.
##
## E o unico corte da sequencia que tinha um buraco de verdade: apertava ENTER
## e a folha sumia, a carteira aparecia pronta, e nada dizia o que tinha
## acontecido entre as duas. Faltava a batida — o gesto do balcao, o carimbo
## caindo em cima do que voce acabou de assinar. Meio segundo, e a tela seguinte
## deixa de ser um corte e passa a ser a consequencia.
##
## Ele cai EM CIMA da rubrica de proposito: e ali que o cartorio carimba, e o
## sentido da imagem e "isto aqui agora vale".
func _desenhar_registro(centro: Vector2) -> void:
	if _carimbo <= 0.0:
		return
	# Ease-out cubico: chega rapido e para seco. Linear le como zoom de menu.
	var t := clampf(_carimbo, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - t, 3.0)
	var escala := lerpf(CARIMBO_ALTURA, 1.0, e)
	# Passado o pouso, o quique: dois graus de sobra que voltam ao lugar.
	var quique := 0.0
	if t > 0.86:
		quique = sin((t - 0.86) / 0.14 * PI) * 2.4
	# A caixa nasce da PALAVRA, e nao de um numero escolhido a olho. "REGISTRADO"
	# na fonte media da cento e dez pixels: dentro de uma moldura de noventa e
	# oito, as duas ultimas letras saiam pela direita e, com a moldura ja
	# encostada na margem, saiam da folha junto. Medir a palavra e depois montar
	# a moldura em volta dela e o unico jeito de isso nao voltar a acontecer
	# quando a palavra mudar.
	var tam := Vector2(maxf(_largura(_media, 14, "REGISTRADO") + 14.0, 96.0), 30.0)
	_bater_carimbo(centro, tam, 9.0 + quique,
		"REGISTRADO", "03B-4410", escala, e)


## A rubrica: um risco de caneta derivado do proprio nome.
##
## Nao e o nome escrito de novo — ele ja esta em caixa alta no pente do campo
## 01, e repetir a mesma informacao com outra fonte nao acrescenta nada. E uma
## ASSINATURA, que numa folha de cartorio e justamente a parte que ninguem
## consegue ler: um traco continuo cuja altura em cada ponto sai do codigo da
## letra correspondente.
##
## Determinista de proposito. A mesma pessoa assina sempre igual, e uma rubrica
## sorteada por quadro seria ruido tremendo em cima do papel.
func _desenhar_rubrica(area: Rect2) -> void:
	var nome := _nome.strip_edges()
	if nome.is_empty():
		return
	var base := area.end.y
	# Assinatura ocupa o espaco que o nome pede, e nao a linha inteira. Um
	# rabisco que sempre termina exatamente na margem direita, com nome de tres
	# letras ou de doze, denuncia que e uma funcao desenhando e nao uma mao.
	var largura := area.size.x * clampf(0.30 + 0.085 * float(nome.length()),
		0.30, 1.0)
	# Numero de tracos, e nao numero de letras. A mao nao desenha um pico por
	# caractere: um nome de doze letras vira um rabisco com quase o mesmo tanto
	# de picos que um de sete, e o que muda entre eles e a LARGURA, nao a
	# densidade. Com um pico por letra, nome comprido virava um pente.
	var tracos := clampi(nome.length(), 3, 8) * 2

	# Larguras irregulares, sorteadas pelas letras. Passo constante e o que mais
	# denuncia funcao desenhando no lugar de mao: a serra sai perfeita.
	var vaos := PackedFloat32Array()
	var soma := 0.0
	for i in tracos:
		var l := nome.unicode_at(i % nome.length())
		var v := 0.55 + float((l * 17 + i * 7) % 100) / 100.0
		vaos.append(v)
		soma += v

	var pontos := PackedVector2Array()
	var andado := 0.0
	for i in tracos + 1:
		var letra := nome.unicode_at(i % nome.length())
		var alto := float((letra * 37 + i * 13) % 100) / 100.0
		var t := andado / soma
		var y := base
		if i <= 1:
			# A primeira letra e a maior. Vale para quase toda assinatura
			# humana, e e o que da comeco ao traco em vez de ele brotar do meio
			# da linha.
			y = base - area.size.y * (0.74 + 0.22 * alto)
		elif (letra * 7 + i * 5) % 3 == 0:
			# Descidas cruzam a pauta, e vem em MINORIA — uma a cada tres, e
			# nao uma sim uma nao. Alternancia estrita produz dente de serra;
			# o que faz o traco parecer escrito sao as corridas.
			y = base + area.size.y * (0.06 + 0.12 * alto)
		else:
			y = base - area.size.y * (0.18 + 0.62 * alto)
		# Uma subida geral da esquerda para a direita: quase toda assinatura
		# sobe um pouco ate o fim da linha.
		y -= area.size.y * 0.14 * t
		pontos.append(Vector2(area.position.x + largura * t, y))
		if i < tracos:
			andado += vaos[i]

	# Duas passadas: a de baixo, mais grossa e translucida, e a tinta
	# encharcando o papel — o que uma esferografica faz numa via de talao.
	draw_polyline(pontos, Color(0.10, 0.14, 0.34, 0.28), 2.8)
	draw_polyline(pontos, Color(0.09, 0.12, 0.30, 0.92), 1.0)

	# A perna final: o risco que volta por baixo de tudo e termina num gancho.
	var fim := pontos[pontos.size() - 1]
	var volta := Vector2(area.position.x + largura * 0.22, base + 4.0)
	draw_line(fim, volta, Color(0.09, 0.12, 0.30, 0.75), 1.0)
	draw_line(volta, volta + Vector2(-5.0, -4.0), Color(0.09, 0.12, 0.30, 0.75), 1.0)


## Protocolo impresso na folha e a linha de teclas, essa ja fora dela.
##
## A dica sai sobre uma tarja escura, e nao solta sobre o fundo: era ela que
## caia meio na folha e meio na cabine, com metade das letras claras sobre papel
## claro.
func _desenhar_rodape() -> void:
	var tarja := Rect2(0.0, 248.0, TELA.x, 18.0)
	draw_rect(tarja, Color(0.03, 0.035, 0.04, 0.72))
	_txt(_pequena, 11, Vector2(0.0, 261.0),
		"[LETRAS] escrever   [ENTER] assinar   [ESC] voltar",
		Color(0.90, 0.87, 0.78), HORIZONTAL_ALIGNMENT_CENTER, TELA.x)


## A luz que cai na folha, por cima de tudo o que ja foi impresso nela.
##
## Sem isto o papel e uma chapa de cor unica com texto em cima — legivel, e
## chapado. A folha esta dentro de um carro parado a noite, e nesse carro ha
## exatamente duas fontes: o mostrador do painel, quente e por BAIXO, e o
## para-brisa, frio e por cima. Um degrade frio no alto e um quente embaixo e o
## que basta para o papel ficar dentro da cena em vez de colado na frente dela.
##
## Por cima do texto, e nao por baixo: luz que ilumina o papel mas nao a tinta
## dele e o defeito classico de interface fingindo iluminacao.
##
## Fraco de proposito — nenhuma faixa passa de dezesseis por cento. Contraste de
## leitura foi a queixa que abriu esta tela, e nao se paga uma reforma dessas
## com um veu por cima do que acabou de ficar legivel.
func _desenhar_luz() -> void:
	_transformada_folha()
	var r := Rect2(-FOLHA.size * 0.5, FOLHA.size)

	var faixas := 14
	var alto := r.size.y / float(faixas)
	for i in faixas:
		var t := float(i) / float(faixas - 1)
		var faixa := Rect2(r.position.x, r.position.y + float(i) * alto,
			r.size.x, alto + 1.0)
		# Frio descendo do para-brisa, forte so no primeiro terco.
		var frio := clampf(1.0 - t * 2.4, 0.0, 1.0)
		if frio > 0.01:
			draw_rect(faixa, Color(0.16, 0.21, 0.30, 0.15 * frio))
		# Quente subindo do painel, so no ultimo terco.
		var quente := clampf((t - 0.58) * 2.6, 0.0, 1.0)
		if quente > 0.01:
			draw_rect(faixa, Color(1.0, 0.72, 0.34, 0.13 * quente))

	# O canto de cima a direita e o mais longe do painel: e la que a folha
	# apaga. Em cunhas encaixadas, e nao numa so: uma cunha unica desenha a
	# propria hipotenusa atravessada no papel, e o que se ve nao e sombra, e um
	# vinco em diagonal cortando o numero do formulario.
	for i in 5:
		var g := 46.0 + float(i) * 30.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(r.end.x - g * 1.6, r.position.y),
			Vector2(r.end.x, r.position.y),
			Vector2(r.end.x, r.position.y + g)]),
			Color(0.10, 0.11, 0.14, 0.030))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- pecas ------------------------------------------------------------------

## O balanco da folha, num lugar so.
##
## Papel, sombra e luz precisam do MESMO seno. Cada um com o proprio, eles
## divergem no primeiro ajuste e a luz desliza por cima do papel em vez de
## andar com ele — que e o tipo de defeito que nao aparece em captura parada.
func _transformada_folha() -> void:
	# Amplitude de carro parado. Ver a nota em `CriacaoAparencia._balanco_doc`:
	# folha grande gingando le como veiculo andando, mesmo com o veiculo quieto.
	var osc := Vector2(sin(_relogio * 0.58) * 0.38, cos(_relogio * 0.47) * 0.30)
	var ang := deg_to_rad(INCLINACAO + sin(_relogio * 0.52) * 0.14)
	draw_set_transform(FOLHA.position + osc + FOLHA.size * 0.5, ang, Vector2.ONE)

## A etiqueta numerada do campo: tinta cheia com o numero vazado.
func _etiqueta(numero: String, canto: Vector2) -> void:
	var r := Rect2(canto, Vector2(20.0, 14.0))
	draw_rect(r, TINTA)
	_txt(_pequena, 11, Vector2(r.position.x, r.end.y - 3.0), numero, PAPEL,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


## Hachura de quarenta e cinco graus dentro de um retangulo.
##
## As diagonais sao cortadas na conta, e nao desenhadas inteiras: `draw_line`
## nao respeita retangulo de recorte, e uma diagonal que passa do campo risca a
## folha ao lado.
func _hachurar(r: Rect2) -> void:
	draw_rect(r, Color(0.78, 0.75, 0.64, 0.60))
	var h := r.size.y
	var cor := Color(TINTA.r, TINTA.g, TINTA.b, 0.30)
	var a := r.position.x - h
	while a < r.end.x:
		var t0 := maxf(0.0, r.position.x - a)
		var t1 := minf(h, r.end.x - a)
		if t1 > t0:
			draw_line(Vector2(a + t0, r.position.y + t0),
				Vector2(a + t1, r.position.y + t1), cor, 1.0)
		a += 5.0
	draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.0), TINTA_FRACA)


func _txt(f: Font, tamanho: int, pos: Vector2, s: String, cor: Color,
		alinhamento: int = HORIZONTAL_ALIGNMENT_LEFT, largura: float = -1.0) -> void:
	if f == null:
		return
	draw_string(f, pos, s, alinhamento, largura, tamanho, cor)


func _largura(f: Font, tamanho: int, s: String) -> float:
	if f == null:
		return 0.0
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tamanho).x
