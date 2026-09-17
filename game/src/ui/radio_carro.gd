## Autoload. O radio do carro e a roleta que o troca.
##
## Duas coisas no mesmo lugar porque sao a mesma coisa: a roleta nao e uma tela
## que consulta o radio, e o radio visto de frente. Separar daria dois autoloads
## conversando por sinal para nada.
##
## Pronto para receber MP3 sem tocar em codigo
## -------------------------------------------
## Cada estacao e uma PASTA. Quem quiser por musica larga os arquivos em
##
##     user://radio/<pasta>/qualquer_nome.mp3        (no jogo instalado)
##     res://assets/audio/radio/<pasta>/*.mp3        (dentro do projeto)
##
## e a estacao passa a tocar. Nada aqui e recompilado, nenhuma lista precisa ser
## editada, e uma estacao sem arquivo nenhum nao quebra: ela toca a estatica de
## fora do ar, que ja existe no banco de audio e que — numa cidade com nevoa e
## um radio de mao que capta interferencia — e conteudo, e nao falta dele.
##
## A ordem de leitura e a de cima para baixo: o que o jogador largou em user://
## ganha do que veio no pacote, entao da para substituir a trilha sem mexer no
## jogo.
extends CanvasLayer

const FONTE_P := "res://assets/fontes/psx_pequena.fnt"
const FONTE_MONO := "res://assets/fontes/psx_mono.fnt"

const DIR_USUARIO := "user://radio/"
const DIR_PACOTE := "res://assets/audio/radio/"

## Raio da roleta e do miolo, em pixels da tela interna de 480x270.
const RAIO := 86.0
const MIOLO := 34.0

## As estacoes. Trocar de ordem muda a posicao na roleta, e nada mais.
##
## Sao emissoras de cidade grande dos anos noventa, que e a epoca que o jogo
## desenha: AM de noticia, FM romantica, gospel, rock nacional, samba — e uma
## frequencia que nao devia estar no dial.
const ESTACOES: Array[Dictionary] = [
	{"id": &"cidade", "nome": "RADIO CIDADE", "dial": "AM 780",
		"genero": "NOTICIA", "cor": Color(0.86, 0.74, 0.42), "pasta": "cidade"},
	{"id": &"tupa", "nome": "TUPA FM", "dial": "FM 92,7",
		"genero": "ROMANTICA", "cor": Color(0.88, 0.44, 0.58), "pasta": "tupa"},
	{"id": &"onda", "nome": "ONDA NEGRA", "dial": "FM 101,3",
		"genero": "SOUL", "cor": Color(0.62, 0.42, 0.86), "pasta": "onda"},
	{"id": &"capela", "nome": "RADIO CAPELA", "dial": "AM 1130",
		"genero": "GOSPEL", "cor": Color(0.78, 0.82, 0.90), "pasta": "capela"},
	{"id": &"estacao105", "nome": "ESTACAO 105", "dial": "FM 105,1",
		"genero": "ROCK", "cor": Color(0.86, 0.36, 0.26), "pasta": "estacao105"},
	{"id": &"esquina", "nome": "SAMBA DA ESQUINA", "dial": "FM 88,5",
		"genero": "SAMBA", "cor": Color(0.52, 0.78, 0.48), "pasta": "esquina"},
	{"id": &"industrial", "nome": "PARQUE INDUSTRIAL", "dial": "FM 97,9",
		"genero": "ELETRONICA", "cor": Color(0.44, 0.72, 0.84), "pasta": "industrial"},
	# A ultima nao tem pasta e nunca vai ter. E o lugar do dial onde nao ha
	# emissora nenhuma e ainda assim ha alguma coisa — e o unico item da roleta
	# que pertence ao jogo de horror e nao ao carro.
	{"id": &"morta", "nome": "FREQUENCIA MORTA", "dial": "AM ---",
		"genero": "SEM SINAL", "cor": Color(0.42, 0.44, 0.44), "pasta": ""},
]

## Estacao desligada.
const DESLIGADO := -1

signal estacao_mudou(indice: int)

var _fonte: Font
var _mono: Font
var _tela: Control

var _estacao: int = DESLIGADO
var _selecao: int = 0
var _aberta: bool = false
var _tocador: AudioStreamPlayer
var _estatica: AudioStreamPlayer
var _fila: Array[String] = []
var _proxima: int = 0
var _abertura: float = 0.0


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fonte = load(FONTE_P) as Font
	_mono = load(FONTE_MONO) as Font

	_tocador = AudioStreamPlayer.new()
	_tocador.name = "Tocador"
	_tocador.bus = &"Music"
	_tocador.volume_db = -9.0
	_tocador.finished.connect(_proxima_faixa)
	add_child(_tocador)

	_estatica = AudioStreamPlayer.new()
	_estatica.name = "Estatica"
	_estatica.bus = &"Music"
	_estatica.volume_db = -22.0
	# O arquivo de estatica tem dois segundos e nao e marcado como loop no
	# importador, porque quem mais o usa e o radio de mao, que da chiados
	# curtos. Aqui ele precisa nao acabar: uma frequencia vazia que fica muda
	# depois de dois segundos le como bug, e nao como frequencia vazia.
	# Quem repete e o servidor de audio: ver AudioDirector.em_loop.
	_estatica.stream = AudioDirector.em_loop(&"estatica")
	add_child(_estatica)

	_tela = Control.new()
	_tela.name = "Roleta"
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tela.draw.connect(_desenhar)
	add_child(_tela)
	_tela.visible = false
	set_process(false)
	preparar_pastas()


# --- a roleta ---------------------------------------------------------------

func abrir() -> void:
	if _aberta:
		return
	_aberta = true
	_abertura = 0.0
	_selecao = _estacao
	_tela.visible = true
	set_process(true)
	_tela.queue_redraw()


## Fecha e aplica. A escolha so vale ao soltar a tecla, como na roleta de arma
## do GTA: enquanto esta aberta o jogador esta escolhendo, e trocar de faixa a
## cada passo do dedo faria a roleta gaguejar a musica inteira.
func fechar(aplicar: bool = true) -> void:
	if not _aberta:
		return
	_aberta = false
	_tela.visible = false
	set_process(false)
	if aplicar:
		sintonizar(_selecao)


func aberta() -> bool:
	return _aberta


func girar(passo: int) -> void:
	if not _aberta:
		return
	# A roleta inclui o "desligado" como uma posicao a mais, no fim.
	var total := ESTACOES.size() + 1
	_selecao = posmod(_selecao + passo, total)
	if _selecao == ESTACOES.size():
		_selecao = DESLIGADO if passo > 0 else ESTACOES.size() - 1
	if _selecao < DESLIGADO:
		_selecao = ESTACOES.size() - 1
	AudioDirector.tocar_ui(&"bipe_curto", -18.0)
	_tela.queue_redraw()


## Aponta a roleta pelo mouse. O angulo do ponteiro em relacao ao centro da tela
## escolhe o setor, que e o gesto do GTA: o jogador nao clica, ele aponta.
## Distancia minima do gesto para valer como escolha de estacao. Abaixo dela o
## jogador esta apontando para o MIOLO, que e o desligado — abrir a roleta e nao
## mexer o mouse tem de significar alguma coisa, e a coisa mais util que pode
## significar e "desliga isso".
const GESTO_MINIMO := 14.0

func apontar(direcao: Vector2) -> void:
	if not _aberta:
		return
	var novo := DESLIGADO
	if direcao.length() >= GESTO_MINIMO:
		var ang := fposmod(atan2(direcao.x, -direcao.y), TAU)
		var n := ESTACOES.size()
		novo = int(round(ang / TAU * float(n))) % n
	if novo != _selecao:
		_selecao = novo
		AudioDirector.tocar_ui(&"bipe_curto", -18.0)
		_tela.queue_redraw()


func _process(delta: float) -> void:
	_abertura = minf(1.0, _abertura + delta * 7.0)
	_tela.queue_redraw()


# --- sintonia ---------------------------------------------------------------

func estacao() -> int:
	return _estacao


func nome_da_estacao() -> String:
	if _estacao == DESLIGADO:
		return "DESLIGADO"
	return String(ESTACOES[_estacao]["nome"])


## Ha estacao sintonizada?
##
## Existe para quem precisa DECIDIR e nao so escrever: comparar
## `nome_da_estacao() == "DESLIGADO"` funciona e amarra o comportamento a um
## rotulo de tela, que e a primeira coisa que muda quando alguem traduz o jogo.
func sintonizada() -> bool:
	return _estacao != DESLIGADO


func sintonizar(indice: int) -> void:
	if indice == _estacao:
		return
	_estacao = indice
	_tocador.stop()
	_estatica.stop()
	_fila.clear()
	_proxima = 0
	AudioDirector.tocar_ui(&"radio_click", -12.0)

	if _estacao == DESLIGADO:
		estacao_mudou.emit(_estacao)
		return

	_fila = _faixas_de(String(ESTACOES[_estacao]["pasta"]))
	if _fila.is_empty():
		_fora_do_ar()
	else:
		_fila.shuffle()
		_proxima_faixa()
	estacao_mudou.emit(_estacao)


## Estacao sem arquivo nenhum. Nao e erro nem silencio: e o chiado de quem
## sintonizou uma frequencia vazia, que a cidade ja tem gravado.
func _fora_do_ar() -> void:
	if _estatica.stream == null:
		return
	_estatica.volume_db = -24.0 if _estacao != ESTACOES.size() - 1 else -17.0
	_estatica.play()


func _proxima_faixa() -> void:
	if _estacao == DESLIGADO or _fila.is_empty():
		return
	var caminho := _fila[_proxima % _fila.size()]
	_proxima += 1
	var s := _carregar(caminho)
	if s == null:
		return
	_tocador.stream = s
	_tocador.play()


## Os arquivos de uma estacao, em ordem de prioridade.
static func _faixas_de(pasta: String) -> Array[String]:
	var saida: Array[String] = []
	if pasta.is_empty():
		return saida
	for base: String in [DIR_USUARIO + pasta, DIR_PACOTE + pasta]:
		var dir := DirAccess.open(base)
		if dir == null:
			continue
		for nome: String in dir.get_files():
			# `.import` aparece na listagem do projeto exportado; o arquivo real
			# e o nome sem ele.
			var limpo := nome.trim_suffix(".import")
			var ext := limpo.get_extension().to_lower()
			if ext != "mp3" and ext != "ogg" and ext != "wav":
				continue
			var completo := base.path_join(limpo)
			if not saida.has(completo):
				saida.append(completo)
	return saida


## Carrega um arquivo de audio de qualquer um dos dois lugares.
##
## `res://` passa pelo importador do motor e sai como recurso; `user://` nao
## existia quando o jogo foi exportado e precisa ser lido como bytes. Sao dois
## caminhos porque sao dois mundos, e nao por gosto.
static func _carregar(caminho: String) -> AudioStream:
	if caminho.begins_with("res://"):
		if ResourceLoader.exists(caminho):
			return load(caminho) as AudioStream
		return null
	if not FileAccess.file_exists(caminho):
		return null
	var bytes := FileAccess.get_file_as_bytes(caminho)
	if bytes.is_empty():
		return null
	match caminho.get_extension().to_lower():
		"mp3":
			return AudioStreamMP3.load_from_buffer(bytes)
		"ogg":
			return AudioStreamOggVorbis.load_from_buffer(bytes)
		_:
			return null


## Cria as pastas vazias na primeira execucao, para quem for por musica achar
## onde. Uma pasta que existe e um convite; uma que nao existe e um obstaculo.
func preparar_pastas() -> void:
	DirAccess.make_dir_recursive_absolute(DIR_USUARIO)
	for e: Dictionary in ESTACOES:
		var pasta := String(e["pasta"])
		if not pasta.is_empty():
			DirAccess.make_dir_recursive_absolute(DIR_USUARIO + pasta)


# --- desenho ----------------------------------------------------------------

func _desenhar() -> void:
	var tela := _tela.get_viewport_rect().size
	var centro := tela * 0.5
	var t := _abertura

	# Escurece o mundo atras. Nao e menu: e uma roleta por cima do que esta
	# acontecendo, e o carro continua andando enquanto ela esta aberta.
	_tela.draw_rect(Rect2(Vector2.ZERO, tela), Color(0.0, 0.0, 0.0, 0.42 * t))

	var n := ESTACOES.size()
	for k in n:
		var ang := TAU * float(k) / float(n) - PI * 0.5
		var raio := RAIO * (0.4 + 0.6 * t)
		var p := centro + Vector2(cos(ang), sin(ang)) * raio
		var e: Dictionary = ESTACOES[k]
		var escolhida := k == _selecao
		var cor: Color = e["cor"]

		var caixa := Rect2(p - Vector2(31, 17), Vector2(62, 34))
		_tela.draw_rect(caixa, Color(0.06, 0.06, 0.07, 0.85 * t))
		_tela.draw_rect(caixa, cor if escolhida else cor.darkened(0.55),
			false, 1.0)
		_logo(k, p - Vector2(0, 6), cor if escolhida else cor.darkened(0.45), t)
		# Embaixo da logo vai o dial, e nao o nome. Nome inteiro nao cabe em
		# sessenta pixels, e quem procura uma estacao procura o numero.
		_texto(String(e["dial"]), p + Vector2(0, 13), cor if escolhida
			else cor.darkened(0.4), _mono, true)

	# Miolo: o que esta selecionado agora, por extenso.
	_tela.draw_circle(centro, MIOLO * t, Color(0.05, 0.05, 0.06, 0.9 * t))
	if _selecao == DESLIGADO:
		_texto("DESLIGADO", centro - Vector2(0, 4), Color(0.7, 0.7, 0.7), _fonte, true)
	else:
		var e: Dictionary = ESTACOES[_selecao]
		_texto(String(e["nome"]), centro - Vector2(0, 8), e["cor"], _fonte, true)
		_texto(String(e["genero"]), centro + Vector2(0, 4),
			(e["cor"] as Color).darkened(0.35), _mono, true)
		if String(e["pasta"]).is_empty() or _faixas_de(String(e["pasta"])).is_empty():
			_texto("SEM SINAL", centro + Vector2(0, 15),
				Color(0.55, 0.5, 0.45), _mono, true)


## A marca de cada emissora, desenhada em primitivas.
##
## Nao ha arquivo de logo, e nao vai haver. Sao oito marcas de dezoito pixels
## numa tela de 480x270: uma folha de sprites para isso seria uma textura, um
## import e uma celula por estacao para desenhar o que quatro linhas de vetor
## desenham — e que fica nitida em qualquer escala de janela, o que a textura
## nao ficaria.
##
## Cada marca e uma ideia, e nao um enfeite: torre para a AM de noticia, coracao
## para a romantica, onda para a soul, cruz para a gospel, raio para o rock,
## cavaquinho para o samba, engrenagem para a industrial, e a estatica para a
## frequencia que nao devia existir.
func _logo(indice: int, centro: Vector2, cor: Color, t: float) -> void:
	var r := 9.0 * t
	if r < 1.0:
		return
	match indice:
		0:  # torre de transmissao
			_tela.draw_line(centro + Vector2(-r * 0.5, r), centro + Vector2(0, -r), cor, 1.0)
			_tela.draw_line(centro + Vector2(r * 0.5, r), centro + Vector2(0, -r), cor, 1.0)
			_tela.draw_line(centro + Vector2(-r * 0.3, r * 0.2),
				centro + Vector2(r * 0.3, r * 0.2), cor, 1.0)
			for k in 2:
				var a := r * (0.5 + float(k) * 0.4)
				_tela.draw_arc(centro + Vector2(0, -r), a, -PI * 0.85, -PI * 0.15,
					8, cor, 1.0)
		1:  # coracao
			for lado: float in [-1.0, 1.0]:
				_tela.draw_arc(centro + Vector2(lado * r * 0.4, -r * 0.25),
					r * 0.42, PI, TAU, 8, cor, 1.0)
			_tela.draw_line(centro + Vector2(-r * 0.82, -r * 0.2),
				centro + Vector2(0, r * 0.85), cor, 1.0)
			_tela.draw_line(centro + Vector2(r * 0.82, -r * 0.2),
				centro + Vector2(0, r * 0.85), cor, 1.0)
		2:  # onda sonora
			var ant := centro + Vector2(-r, 0)
			for k in range(1, 13):
				var x := -r + 2.0 * r * float(k) / 12.0
				var y := sin(float(k) * 0.9) * r * 0.62
				var pt := centro + Vector2(x, y)
				_tela.draw_line(ant, pt, cor, 1.0)
				ant = pt
		3:  # cruz
			_tela.draw_line(centro + Vector2(0, -r), centro + Vector2(0, r), cor, 1.0)
			_tela.draw_line(centro + Vector2(-r * 0.55, -r * 0.25),
				centro + Vector2(r * 0.55, -r * 0.25), cor, 1.0)
		4:  # raio
			_tela.draw_polyline(PackedVector2Array([
				centro + Vector2(r * 0.35, -r),
				centro + Vector2(-r * 0.35, r * 0.05),
				centro + Vector2(r * 0.1, r * 0.05),
				centro + Vector2(-r * 0.35, r)]), cor, 1.0)
		5:  # cavaquinho
			_tela.draw_arc(centro + Vector2(0, r * 0.3), r * 0.62, 0.0, TAU, 12, cor, 1.0)
			_tela.draw_line(centro + Vector2(0, -r * 0.3), centro + Vector2(0, -r), cor, 1.0)
			_tela.draw_line(centro + Vector2(-r * 0.3, -r),
				centro + Vector2(r * 0.3, -r), cor, 1.0)
		6:  # engrenagem
			_tela.draw_arc(centro, r * 0.55, 0.0, TAU, 12, cor, 1.0)
			for k in 6:
				var a := TAU * float(k) / 6.0
				var d := Vector2(cos(a), sin(a))
				_tela.draw_line(centro + d * r * 0.55, centro + d * r, cor, 1.0)
		_:  # estatica: a marca de quem nao tem marca
			for k in 5:
				var y := -r + 2.0 * r * float(k) / 4.0
				var largura := r * (0.4 + 0.6 * float((k * 7) % 3) * 0.5)
				_tela.draw_line(centro + Vector2(-largura, y),
					centro + Vector2(largura, y), cor, 1.0)


func _texto(txt: String, onde: Vector2, cor: Color, fonte: Font,
		centrado: bool = false) -> void:
	if fonte == null:
		return
	var largura := fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var p := onde - (Vector2(largura * 0.5, 0.0) if centrado else Vector2.ZERO)
	_tela.draw_string(fonte, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, cor)
