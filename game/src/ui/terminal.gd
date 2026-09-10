## Autoload. O computador do balcao da loja.
##
## O que ele e
## -----------
## A terceira porta para o mesmo registro civil. A primeira e a carteira que o
## NPC tira do bolso (`documento.gd`); a segunda e o portal do celular, que cabe
## em 130 por 186 pixels de LCD verde (`celular.gd`). Esta e a terceira, e a
## diferenca entre ela e as outras duas nao e o que ela mostra — e o TAMANHO da
## tela e o que isso muda.
##
## O celular e um aparelho no bolso, e por isso ele corta: nome em dezesseis
## letras, sem filiacao do pai, sem naturalidade, sem descricao fisica. Foram
## cortes de espaco, e cada um deles doeu. Aqui ha 480 por 270 inteiros, entao a
## ficha aparece como ela e, com foto grande o bastante para reconhecer a pessoa,
## a descricao fisica que o celular nunca coube e os vinculos na mesma tela.
##
## Isso da ao computador uma razao de existir que nao e "o celular num monitor
## maior": ele e o lugar onde a consulta e COMPLETA. Quem so tem o telefone
## consegue um nome e um endereco; quem chega no balcao da loja as tres da manha
## consegue a ficha toda. E o balcao esta dentro do unico lugar aceso do bairro,
## que ja era onde o jogo deixa salvar.
##
## Por que a tela e desenhada, e nao montada com Control
## -----------------------------------------------------
## Mesma razao do celular: sao quatro telas e cada uma e uma funcao de vinte
## linhas que le o estado e pinta. Montadas com nos seriam umas cem caixas de
## texto ligadas e escondidas, e mexer numa linha exigiria achar qual.
##
## Sobre a aparencia: e um desktop de 1998, com janela cinza, barra de titulo
## azul, abas e barra de tarefas. Nao e enfeite de epoca — e a leitura mais
## rapida possivel de "isto e um computador de trabalho e nao mais uma tela do
## jogo", que e a mesma aposta que o `documento.gd` faz ao fingir plastico.
extends CanvasLayer

const FONTE_P := "res://assets/fontes/psx_pequena.fnt"
const FONTE_M := "res://assets/fontes/psx_media.fnt"
const FONTE_MONO := "res://assets/fontes/psx_mono.fnt"

const TELA := Vector2(480.0, 270.0)

## Quanto cabe no campo de busca. Onze e um CPF; o resto e para nome.
const MAX_DIGITADO := 28

## Altura de uma linha de lista, em pixels.
##
## Vinte e quatro, e nao vinte e dois. Cada linha tem DUAS alturas de texto — o
## nome em cima e a idade embaixo — e a fonte pequena rende treze de altura de
## linha. Com vinte e dois, o nome da linha seguinte encostava na idade da
## anterior e a lista lia como um bloco de texto em vez de como uma lista.
const LINHA_LISTA := 24.0

## Quantas linhas cabem no corpo da janela.
const LINHAS_VISIVEIS := 5

## A janela do sistema. Nao ocupa a tela inteira de proposito: a faixa de mesa em
## volta e o que faz aquilo ler como uma janela dentro de um computador em vez de
## como mais uma tela cheia do jogo.
const JANELA := Rect2(22.0, 12.0, 436.0, 232.0)
const BARRA_TITULO := 17.0
const ABAS := 15.0
const BARRA_TAREFAS := 20.0

# Paleta de desktop de 1998 sobre a paleta do jogo.
const MESA := Color("2a5f59")
const MESA_ESCURA := Color("214b47")
const CHROME := Color("bcc0b8")
const CHROME_CLARO := Color("e4e8e0")
const CHROME_ESCURO := Color("74796f")
const TITULO_AZUL := Color("2f4f8c")
const TITULO_INATIVO := Color("6d7a90")
## O azul da ficha. E o mesmo tom de formulario de sistema publico da epoca, e e
## ele que separa o conteudo da moldura sem precisar de linha nenhuma.
const PAINEL := Color("6e9fd2")
const PAINEL_FUNDO := Color("4c7cae")
const CAMPO := Color("f0f3f4")
const TINTA := Color("18202c")
const TINTA_FRACA := Color("5a6672")
const TINTA_CLARA := Color("e9f0f6")
const ALERTA := Color("bb3b2c")
const OK_VERDE := Color("2e6b40")

enum Tela { BUSCA, RESULTADOS, FICHA, VINCULOS }

signal abriu()
signal fechou()

var ativo: bool = false

var _raiz: Control
var _quadro: Control
var _fonte: Font
var _media: Font
var _mono: Font

var _tela: Tela = Tela.BUSCA
var _digitado: String = ""
var _aviso: String = ""
var _ficha: Dictionary = {}
## Foto da ficha aberta, montada UMA vez quando a ficha abre.
##
## Nao pode nascer dentro do desenho: uma ImageTexture criada no meio da passada
## de canvas nao tem os dados enviados a tempo e o motor desenha branco. E a
## mesma pedra em que o visor do celular ja tropecou.
var _foto: ImageTexture
var _vinculos: Array[Dictionary] = []
## Ids que a ultima busca por nome devolveu.
var _resultados: Array[int] = []
## O que foi procurado, para a tela de resultados poder dizer o que nao achou.
var _procurado: String = ""
var _selecionado: int = 0
var _rolagem: int = 0
var _piscar: float = 0.0
var _relogio: float = 0.0


func _ready() -> void:
	layer = 129
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fonte = load(FONTE_P) as Font
	_media = load(FONTE_M) as Font
	_mono = load(FONTE_MONO) as Font
	_montar()
	_raiz.visible = false
	set_process(false)


func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "Terminal"
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)

	_quadro = Control.new()
	_quadro.name = "Quadro"
	_quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_quadro)
	_quadro.position = Vector2.ZERO
	_quadro.size = TELA
	_quadro.draw.connect(_desenhar)


# --- abrir e fechar ---------------------------------------------------------

func pode_abrir() -> bool:
	return not (ativo or Conversa.ativo or Dialogo.ativo or Documento.ativo
		or Celular.ativo or Gps.ativo or get_tree().paused)


func abrir() -> void:
	if not pode_abrir():
		return
	ativo = true
	_tela = Tela.BUSCA
	_digitado = ""
	_aviso = ""
	_raiz.visible = true
	set_process(true)
	_travar_jogador(true)
	AudioDirector.tocar_ui(&"celular_abre", -10.0)
	_animar_entrada()
	_quadro.queue_redraw()
	abriu.emit()


func fechar() -> void:
	if not ativo:
		return
	ativo = false
	_raiz.visible = false
	set_process(false)
	_travar_jogador(false)
	AudioDirector.tocar_ui(&"clique", -14.0)
	fechou.emit()


func _travar_jogador(preso: bool) -> void:
	var jogador := get_tree().get_first_node_in_group(&"player")
	if jogador != null and jogador.has_method("travar"):
		jogador.call("travar", preso)


## Cresce do centro, como janela de sistema abrindo. Aparecer pronta le como
## corte de camera; crescer le como programa que subiu.
func _animar_entrada() -> void:
	_raiz.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_raiz.pivot_offset = TELA * 0.5
	_raiz.scale = Vector2(0.92, 0.92)
	var t := create_tween().set_parallel(true)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_raiz, "modulate", Color.WHITE, 0.1)
	t.tween_property(_raiz, "scale", Vector2.ONE, 0.16)


func _process(delta: float) -> void:
	_piscar += delta
	_relogio += delta
	if fmod(_piscar, 0.5) < delta:
		_quadro.queue_redraw()


# --- desenho ----------------------------------------------------------------

func _texto(pos: Vector2, texto: String, cor: Color = TINTA,
		fonte: Font = null, tamanho: int = 11) -> void:
	var f := fonte if fonte != null else _fonte
	if f == null:
		return
	_quadro.draw_string(f, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		tamanho, cor)


func _caixa(r: Rect2, cor: Color) -> void:
	_quadro.draw_rect(r, cor)


## Moldura em relevo, do jeito que toda janela de 1998 tinha: clara em cima e a
## esquerda, escura embaixo e a direita. Duas linhas de um pixel, e sao elas que
## fazem o retangulo cinza virar botao.
func _relevo(r: Rect2, afundado: bool = false) -> void:
	var claro := CHROME_ESCURO if afundado else CHROME_CLARO
	var escuro := CHROME_CLARO if afundado else CHROME_ESCURO
	_caixa(Rect2(r.position, Vector2(r.size.x, 1.0)), claro)
	_caixa(Rect2(r.position, Vector2(1.0, r.size.y)), claro)
	_caixa(Rect2(r.position + Vector2(0.0, r.size.y - 1.0),
		Vector2(r.size.x, 1.0)), escuro)
	_caixa(Rect2(r.position + Vector2(r.size.x - 1.0, 0.0),
		Vector2(1.0, r.size.y)), escuro)


func _desenhar() -> void:
	_desenhar_mesa()

	_caixa(JANELA, CHROME)
	_relevo(JANELA)
	_desenhar_titulo()
	_desenhar_abas()

	var corpo := Rect2(JANELA.position + Vector2(6.0, BARRA_TITULO + ABAS + 3.0),
		Vector2(JANELA.size.x - 12.0,
			JANELA.size.y - BARRA_TITULO - ABAS - 22.0))
	_caixa(corpo, PAINEL_FUNDO)
	_relevo(corpo, true)
	var dentro := corpo.grow(-3.0)
	_caixa(dentro, PAINEL)

	match _tela:
		Tela.BUSCA:
			_desenhar_busca(dentro)
		Tela.RESULTADOS:
			_desenhar_resultados(dentro)
		Tela.FICHA:
			_desenhar_ficha(dentro)
		Tela.VINCULOS:
			_desenhar_vinculos(dentro)

	_desenhar_rodape()

	if _aviso != "":
		var r := Rect2(JANELA.position.x + 8.0,
			JANELA.position.y + JANELA.size.y - 17.0, JANELA.size.x - 16.0, 11.0)
		_caixa(r, Color("f0e0c8"))
		_texto(r.position + Vector2(4.0, 9.0), _aviso, ALERTA)

	# Varredura do tubo. Duas coisas de uma vez: dizem que aquilo e um monitor
	# dentro do mundo, e quebram o azul chapado que sem elas parece papel.
	for y in range(0, int(TELA.y), 3):
		_quadro.draw_rect(Rect2(0.0, float(y), TELA.x, 1.0),
			Color(0.0, 0.0, 0.0, 0.13))


## A mesa de trabalho por tras da janela, com o quadriculado de dither.
static func _quadriculado(x: int, y: int) -> bool:
	return (x + y) % 2 == 0


func _desenhar_mesa() -> void:
	_caixa(Rect2(Vector2.ZERO, TELA), MESA)
	# Trama de um pixel sim, um nao. E o papel de parede de sistema da epoca, e
	# custa uma faixa por linha em vez de um retangulo por pixel.
	for y in range(0, int(TELA.y), 2):
		_quadro.draw_rect(Rect2(0.0, float(y), TELA.x, 1.0), MESA_ESCURA)

	# Barra de tarefas.
	var barra := Rect2(0.0, TELA.y - BARRA_TAREFAS, TELA.x, BARRA_TAREFAS)
	_caixa(barra, CHROME)
	_relevo(barra)
	var iniciar := Rect2(4.0, TELA.y - BARRA_TAREFAS + 4.0, 60.0, 13.0)
	_caixa(iniciar, CHROME)
	_relevo(iniciar)
	_texto(iniciar.position + Vector2(6.0, 10.0), "INICIAR", TINTA)
	# Relogio. Anda com a partida, a partir do fundo da madrugada — o mesmo
	# relogio do celular, porque as duas telas estao no mesmo turno da noite.
	var minutos := 134 + int(_relogio / 6.0)
	var hora := Rect2(TELA.x - 52.0, TELA.y - BARRA_TAREFAS + 4.0, 46.0, 13.0)
	_caixa(hora, CHROME)
	_relevo(hora, true)
	_texto(hora.position + Vector2(6.0, 10.0),
		"%02d:%02d" % [(minutos / 60) % 24, minutos % 60], TINTA)


func _desenhar_titulo() -> void:
	var r := Rect2(JANELA.position + Vector2(3.0, 3.0),
		Vector2(JANELA.size.x - 6.0, BARRA_TITULO - 3.0))
	_caixa(r, TITULO_AZUL)
	_texto(r.position + Vector2(5.0, 11.0), "CADASTRO NACIONAL - CONSULTA",
		TINTA_CLARA)
	# Os tres botoes de janela. Nao fazem nada e nao devem fazer: sao o que faz o
	# retangulo azul ler como barra de titulo em dois pixels de altura util.
	for k in 3:
		var b := Rect2(r.position.x + r.size.x - 41.0 + float(k) * 13.0,
			r.position.y + 2.0, 11.0, 10.0)
		_caixa(b, ALERTA if k == 2 else CHROME)
		_relevo(b)


const NOMES_ABA: Array[String] = ["CONSULTA", "VINCULOS"]


func _desenhar_abas() -> void:
	var y := JANELA.position.y + BARRA_TITULO + 1.0
	var x := JANELA.position.x + 6.0
	for i in NOMES_ABA.size():
		var ativa := (i == 1) == (_tela == Tela.VINCULOS)
		var largura := 74.0
		var r := Rect2(x, y + (0.0 if ativa else 2.0), largura,
			ABAS - (0.0 if ativa else 2.0))
		_caixa(r, CHROME if ativa else CHROME_ESCURO)
		_relevo(r)
		_texto(r.position + Vector2(9.0, 11.0), NOMES_ABA[i],
			TINTA if ativa else CHROME_CLARO)
		x += largura + 3.0


func _desenhar_rodape() -> void:
	# A data. Sai do registro e nao de um texto solto: o ano manda na idade, na
	# validade do documento e no que a cidade inteira e, e duas datas diferentes
	# na mesma tela quebrariam a unica coisa que a ficha esta tentando afirmar.
	var d: Dictionary = RegistroCivil.DATA
	var texto := "HOJE, %02d/%02d/%04d" % [d["dia"], d["mes"], d["ano"]]
	_texto(Vector2(JANELA.position.x + JANELA.size.x - 96.0,
		JANELA.position.y + JANELA.size.y - 5.0), texto, TINTA_FRACA)
	var atalho := "[ESC] SAIR"
	match _tela:
		Tela.FICHA:
			atalho = "[V] VINCULOS  [D] DOCUMENTO  [ESC] VOLTAR"
		Tela.VINCULOS:
			atalho = "[W/S] MOVER  [ENTER] ABRIR  [ESC] VOLTAR"
		Tela.BUSCA:
			atalho = "[ENTER] CONSULTAR  [ESC] SAIR"
		Tela.RESULTADOS:
			atalho = "[W/S] MOVER  [ENTER] ABRIR  [ESC] VOLTAR"
	_texto(Vector2(JANELA.position.x + 7.0,
		JANELA.position.y + JANELA.size.y - 5.0),
		atalho, TINTA_FRACA)


# --- tela de busca ----------------------------------------------------------

func _desenhar_busca(r: Rect2) -> void:
	_texto(r.position + Vector2(10.0, 20.0), "CONSULTA POR CPF OU NOME",
		TINTA_CLARA, _media, 14)
	_texto(r.position + Vector2(10.0, 36.0),
		"DIGITE E TECLE ENTER.", TINTA_CLARA)

	var campo := Rect2(r.position + Vector2(10.0, 46.0), Vector2(r.size.x - 20.0, 22.0))
	_caixa(campo, CAMPO)
	_relevo(campo, true)
	# Numero sai pontuado, nome sai como foi escrito. E o unico aviso que o campo
	# da de que ele entendeu o que esta sendo procurado, e ele aparece enquanto se
	# digita, antes de apertar nada.
	var por_numero := _e_numero(_digitado)
	var mostrado := _formatar_cpf(_digitado) if por_numero else _digitado
	if fmod(_piscar, 0.8) < 0.45:
		mostrado += "_"
	_texto(campo.position + Vector2(8.0, 16.0),
		mostrado if _digitado != "" else "___.___.___-__  ou  NOME",
		TINTA if _digitado != "" else TINTA_FRACA,
		_mono if por_numero else _fonte, 12 if por_numero else 11)

	# Lupa desenhada a mao, do lado direito do campo. Tres caixas: e o unico
	# icone da tela e existe so para o campo nao ser um retangulo branco.
	var lx := campo.position.x + campo.size.x - 18.0
	var ly := campo.position.y + 6.0
	_caixa(Rect2(lx, ly, 9.0, 9.0), TINTA_FRACA)
	_caixa(Rect2(lx + 1.0, ly + 1.0, 7.0, 7.0), CAMPO)
	_caixa(Rect2(lx + 8.0, ly + 8.0, 4.0, 3.0), TINTA_FRACA)

	var y := r.position.y + 86.0
	for linha: Array in [
			["ENTER", "CONSULTAR"],
			["TAB", "PREENCHER COM O SEU PROPRIO CPF"],
			["BACKSPACE", "APAGAR"],
			["ESC", "FECHAR O TERMINAL"]]:
		_texto(Vector2(r.position.x + 14.0, y), String(linha[0]), TINTA)
		_texto(Vector2(r.position.x + 84.0, y), String(linha[1]), TINTA_CLARA)
		y += 13.0

	# As duas buscas nao alcancam a mesma coisa, e dizer isso aqui evita que o
	# jogador leia "NAO ENCONTRADO" como defeito. Ver RegistroCivil.buscar_por_nome.
	_texto(r.position + Vector2(14.0, r.size.y - 22.0),
		"NUMERO: ACHA QUALQUER PESSOA DO PAIS.", TINTA_FRACA)
	_texto(r.position + Vector2(14.0, r.size.y - 10.0),
		"NOME: ACHA QUEM JA PASSOU POR ESTE BALCAO.", TINTA_FRACA)


static func _formatar_cpf(digitos: String) -> String:
	var s := ""
	for i in digitos.length():
		if i == 3 or i == 6:
			s += "."
		elif i == 9:
			s += "-"
		s += digitos[i]
	return s


# --- resultados da busca por nome -------------------------------------------

## A lista que a busca por nome devolve.
##
## Existe porque nome nao e identificador: "MARIA SANTOS" pode ser tres pessoas
## no mesmo quarteirao, e escolher uma sozinho seria o terminal adivinhando. O
## CPF de cada linha esta a mostra justamente para o jogador poder desempatar.
func _desenhar_resultados(r: Rect2) -> void:
	_texto(r.position + Vector2(10.0, 20.0), "RESULTADOS", TINTA_CLARA, _media, 14)
	_texto(r.position + Vector2(10.0, 34.0),
		"%d PARA \"%s\"" % [_resultados.size(), _procurado.substr(0, 24)],
		TINTA_FRACA)

	if _resultados.is_empty():
		_texto(r.position + Vector2(12.0, 62.0), "NENHUM NOME NESTE CADASTRO.",
			TINTA_CLARA)
		_texto(r.position + Vector2(12.0, 80.0),
			"A BUSCA POR NOME SO ALCANCA QUEM JA", TINTA_FRACA)
		_texto(r.position + Vector2(12.0, 92.0),
			"PASSOU POR AQUI. PARA UM DESCONHECIDO,", TINTA_FRACA)
		_texto(r.position + Vector2(12.0, 104.0),
			"USE O CPF DA CARTEIRA DELE.", TINTA_FRACA)
		return

	_selecionado = clampi(_selecionado, 0, _resultados.size() - 1)
	_rolagem = clampi(_rolagem, maxi(0, _selecionado - LINHAS_VISIVEIS + 1),
		_selecionado)
	var y := r.position.y + 46.0
	for i in range(_rolagem, mini(_resultados.size(), _rolagem + LINHAS_VISIVEIS)):
		var f := RegistroCivil.identidade(_resultados[i])
		var linha := Rect2(r.position.x + 8.0, y, r.size.x - 16.0, LINHA_LISTA - 2.0)
		if i == _selecionado:
			_caixa(linha, PAINEL_FUNDO)
		var morto := int(f["situacao"]) == RegistroCivil.Situacao.FALECIDO
		# Nome e CPF na MESMA linha: sao os dois campos que identificam, e o olho
		# que compara duas MARIA SANTOS precisa dos dois lado a lado. Idade e
		# profissao descem para a linha de baixo, que e onde vai o que so serve
		# para desempatar depois.
		_texto(linha.position + Vector2(6.0, 10.0),
			String(f["nome"]).substr(0, 24), ALERTA if morto else TINTA_CLARA)
		_texto(linha.position + Vector2(linha.size.x - 92.0, 10.0),
			String(f["cpf"]), TINTA, _mono, 12)
		_texto(linha.position + Vector2(6.0, 20.0),
			"%d ANOS  %s" % [int(f["idade"]),
				String(f["profissao"]).substr(0, 18)], TINTA_FRACA)
		y += LINHA_LISTA

	if _resultados.size() > LINHAS_VISIVEIS:
		_texto(Vector2(r.position.x + r.size.x - 58.0, r.position.y + 34.0),
			"%d DE %d" % [_selecionado + 1, _resultados.size()], TINTA_FRACA)


# --- ficha ------------------------------------------------------------------

func _desenhar_ficha(r: Rect2) -> void:
	if _ficha.is_empty():
		_texto(r.position + Vector2(12.0, 30.0), "REGISTRO VAZIO", ALERTA, _media, 14)
		return
	var f := _ficha

	# A foto, no dobro do tamanho nativo. E a diferenca que este terminal tem
	# para o celular: la ela sai a 40x52 e o rosto tem quatro pixels de olho;
	# aqui ela sai a 80x104 e da para reconhecer a pessoa com quem se falou ha
	# dois quarteiroes, que e o proposito inteiro da consulta.
	var moldura := Rect2(r.position + Vector2(10.0, 12.0),
		Vector2(float(Retrato.LARGURA) * 2.0 + 6.0,
			float(Retrato.ALTURA) * 2.0 + 6.0))
	_caixa(moldura, CAMPO)
	_relevo(moldura, true)
	if _foto != null:
		_quadro.draw_texture_rect(_foto,
			Rect2(moldura.position + Vector2(3.0, 3.0),
				Vector2(float(Retrato.LARGURA) * 2.0, float(Retrato.ALTURA) * 2.0)),
			false)

	var x := moldura.position.x + moldura.size.x + 10.0
	var largura := r.position.x + r.size.x - x - 10.0

	_texto(Vector2(x, r.position.y + 24.0), String(f["nome"]).substr(0, 26),
		TINTA_CLARA, _media, 14)

	# Situacao cadastral, do lado do nome. E o que transforma uma consulta comum
	# num susto: procurar a avo de alguem e achar a ficha baixada.
	var situacao := int(f["situacao"])
	var viva := situacao == RegistroCivil.Situacao.REGULAR
	var etiqueta := Rect2(x, r.position.y + 29.0, 96.0, 12.0)
	_caixa(etiqueta, OK_VERDE if viva else ALERTA)
	_texto(etiqueta.position + Vector2(4.0, 9.0),
		RegistroCivil.nome_da_situacao(situacao).substr(0, 14), TINTA_CLARA)
	_texto(Vector2(x + 102.0, r.position.y + 38.0), String(f["cpf"]), TINTA_CLARA,
		_mono, 12)

	# O painel de descricao, que e o que o celular nunca coube. Sao os tracos que
	# permitem reconhecer a pessoa na rua sem ter o rosto na mao — e por isso a
	# lista sai da APARENCIA e nao de um texto guardado: e a mesma aparencia que
	# veste o corpo dela na esquina.
	var painel := Rect2(x, r.position.y + 46.0, largura, 54.0)
	_caixa(painel, PAINEL_FUNDO)
	_texto(painel.position + Vector2(5.0, 11.0), "DESCRICAO", TINTA_CLARA)
	var y := painel.position.y + 24.0
	for traco: String in _tracos(f):
		_texto(Vector2(painel.position.x + 10.0, y), "- " + traco, TINTA_CLARA)
		y += 11.0

	# Os campos de baixo, em duas colunas. Aqui cabem os que o celular cortou:
	# naturalidade e o nome do pai entram junto com o resto.
	#
	# `base` e relativo ao painel, nao absoluto. Somar `r.position` de novo
	# empurrava MAE/PAI para cima da barra de atalho. Tres linhas cabem
	# abaixo da foto; RG e idade ficam de fora porque a idade ja esta na
	# descricao e o RG, no documento que [D] abre.
	var base := 124.0
	var campos: Array[Array] = [
		["NASCIMENTO", String(f["nascimento"])],
		["PROFISSAO", String(f["profissao"]).substr(0, 22)],
		["MAE", String(f["mae"]).substr(0, 24)],
		["PAI", String(f["pai"]).substr(0, 24)],
		["NATURALIDADE", String(f["naturalidade"]).substr(0, 22)],
		["ENDERECO", String(f["endereco"]).substr(0, 26)],
	]
	for i in campos.size():
		var lado := i % 2
		var linha: int = i / 2
		var p := r.position + Vector2(12.0 + float(lado) * (r.size.x * 0.5 - 4.0),
			base + float(linha) * 12.0)
		_texto(p, "%s  %s" % [campos[i][0], campos[i][1]], TINTA)


## Os tracos fisicos que a ficha descreve, na ordem em que se reparam neles.
##
## Saem da aparencia sorteada, e nao de uma lista guardada. E isso que faz a
## descricao valer: "CALVO" no terminal quer dizer que o sujeito na esquina esta
## careca de verdade, porque as duas coisas leem a mesma chave.
static func _tracos(f: Dictionary) -> Array[String]:
	var a: Dictionary = f.get("aparencia", {})
	var saida: Array[String] = []
	if a.is_empty():
		saida.append("SEM DESCRICAO NO CADASTRO")
		return saida

	saida.append("ALTURA APROXIMADA %.2f M" % float(a.get("altura", 1.7)))
	if bool(a.get("calvo", false)):
		saida.append("CALVO")
	else:
		var comp := int(a.get("cabelo_comprimento", 0))
		saida.append(["CABELO CURTO", "CABELO MEDIO", "CABELO LONGO"][clampi(comp, 0, 2)])
	var gordura := float(a.get("gordura", 0.5))
	saida.append("PORTE MAGRO" if gordura < 0.34
		else ("PORTE FORTE" if gordura > 0.7 else "PORTE MEDIO"))
	if bool(a.get("chapeu", false)):
		saida.append("COSTUMA USAR CHAPEU")
	elif bool(a.get("casaco", false)):
		saida.append("COSTUMA USAR CASACO")
	return saida


# --- vinculos ---------------------------------------------------------------

func _desenhar_vinculos(r: Rect2) -> void:
	_texto(r.position + Vector2(10.0, 20.0), "MESMO ENDERECO", TINTA_CLARA,
		_media, 14)
	if _ficha.is_empty():
		_texto(r.position + Vector2(12.0, 44.0), "CONSULTE UM CPF PRIMEIRO.",
			TINTA_CLARA)
		return
	_texto(r.position + Vector2(10.0, 34.0),
		String(_ficha["endereco"]).substr(0, 46), TINTA_FRACA)

	if _vinculos.is_empty():
		_texto(r.position + Vector2(12.0, 60.0), "NENHUM VINCULO REGISTRADO.",
			TINTA_CLARA)
		return

	_selecionado = clampi(_selecionado, 0, _vinculos.size() - 1)
	_rolagem = clampi(_rolagem, maxi(0, _selecionado - LINHAS_VISIVEIS + 1),
		_selecionado)
	var y := r.position.y + 46.0
	for i in range(_rolagem, mini(_vinculos.size(), _rolagem + LINHAS_VISIVEIS)):
		var v := _vinculos[i]
		var linha := Rect2(r.position.x + 8.0, y, r.size.x - 16.0, LINHA_LISTA - 2.0)
		if i == _selecionado:
			_caixa(linha, PAINEL_FUNDO)
		var morto := int(v["situacao"]) == RegistroCivil.Situacao.FALECIDO
		_texto(linha.position + Vector2(6.0, 10.0),
			String(v["nome"]).substr(0, 24),
			ALERTA if morto else TINTA_CLARA)
		_texto(linha.position + Vector2(linha.size.x - 92.0, 10.0),
			String(v["cpf"]), TINTA, _mono, 12)
		_texto(linha.position + Vector2(6.0, 20.0),
			"%s, %d ANOS" % [v["relacao"], int(v["idade"])], TINTA_FRACA)
		y += LINHA_LISTA

	if _vinculos.size() > LINHAS_VISIVEIS:
		_texto(Vector2(r.position.x + r.size.x - 58.0, r.position.y + 34.0),
			"%d DE %d" % [_selecionado + 1, _vinculos.size()], TINTA_FRACA)


# --- entrada ----------------------------------------------------------------

func _input(evento: InputEvent) -> void:
	if not ativo or Documento.ativo:
		return

	var tecla := evento as InputEventKey
	if tecla != null and tecla.pressed and not tecla.echo:
		if _tecla_digitada(tecla):
			get_viewport().set_input_as_handled()
			_quadro.queue_redraw()
			return

	if evento.is_action_pressed("pausa"):
		_voltar()
	elif evento.is_action_pressed("interagir") or evento.is_action_pressed("ui_accept"):
		_acionar()
	elif evento.is_action_pressed("mover_tras") or evento.is_action_pressed("ui_down"):
		_mover(1)
	elif evento.is_action_pressed("mover_frente") or evento.is_action_pressed("ui_up"):
		_mover(-1)
	else:
		return
	get_viewport().set_input_as_handled()
	_quadro.queue_redraw()


## Digitos, apagar e os atalhos de uma letra so. Devolve true se consumiu.
func _tecla_digitada(tecla: InputEventKey) -> bool:
	var codigo := tecla.keycode

	if _tela == Tela.BUSCA:
		if codigo >= KEY_KP_0 and codigo <= KEY_KP_9 and _digitado.length() < MAX_DIGITADO:
			_digitado += str(codigo - KEY_KP_0)
			AudioDirector.tocar_ui(&"celular_tecla", -16.0)
			return true
		# Letra, digito e espaco entram pelo unicode e nao pelo keycode: e o
		# unico jeito de o campo aceitar um nome sem uma tabela de 26 casos.
		#
		# O corte em 32 exclui de uma vez Enter, Esc, Tab e Backspace, que sao
		# todos de codigo baixo — e por isso as teclas de comando continuam
		# chegando em `_input` mesmo com o campo aceitando texto.
		var c := tecla.unicode
		if c >= 32 and _digitado.length() < MAX_DIGITADO:
			var ch := String.chr(c).to_upper()
			if ch == " " or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
				_digitado += ch
				AudioDirector.tocar_ui(&"celular_tecla", -16.0)
				return true
		if codigo == KEY_BACKSPACE:
			_digitado = _digitado.substr(0, maxi(0, _digitado.length() - 1))
			AudioDirector.tocar_ui(&"celular_tecla", -20.0)
			return true
		if codigo == KEY_TAB:
			# Atalho para o proprio CPF. Digitar onze digitos toda vez que se
			# abre o terminal e pedagio, nao jogo — o numero do jogador ele ja
			# tem no bolso. E o mesmo atalho do portal do celular.
			var eu := RegistroCivil.jogador
			if not eu.is_empty():
				_digitado = String(eu["cpf"]).replace(".", "").replace("-", "")
				AudioDirector.tocar_ui(&"celular_tecla", -12.0)
			return true

	if _tela == Tela.FICHA and not _ficha.is_empty():
		if codigo == KEY_V:
			_abrir_vinculos()
			return true
		if codigo == KEY_D:
			Documento.abrir(_ficha)
			return true
	return false


func _mover(passo: int) -> void:
	var quantos := 0
	if _tela == Tela.VINCULOS:
		quantos = _vinculos.size()
	elif _tela == Tela.RESULTADOS:
		quantos = _resultados.size()
	if quantos == 0:
		return
	AudioDirector.tocar_ui(&"clique", -24.0)
	_selecionado = posmod(_selecionado + passo, quantos)


func _voltar() -> void:
	_aviso = ""
	match _tela:
		Tela.VINCULOS:
			_tela = Tela.FICHA
		Tela.RESULTADOS:
			_tela = Tela.BUSCA
			_selecionado = 0
		Tela.FICHA:
			# A ficha aberta a partir de uma lista volta PARA A LISTA. Voltar
			# para o campo de busca obrigaria a redigitar o nome para ver a
			# segunda das tres pessoas que ele achou.
			if not _resultados.is_empty():
				_tela = Tela.RESULTADOS
				return
			_tela = Tela.BUSCA
			_digitado = ""
		_:
			fechar()


func _acionar() -> void:
	_aviso = ""
	match _tela:
		Tela.BUSCA:
			_consultar()
		Tela.RESULTADOS:
			if not _resultados.is_empty():
				_mostrar_ficha(RegistroCivil.identidade(
					_resultados[_selecionado]))
		Tela.VINCULOS:
			if not _vinculos.is_empty():
				_mostrar_ficha(RegistroCivil.identidade(
					int(_vinculos[_selecionado]["id"])))
		_:
			_abrir_vinculos()


func _abrir_vinculos() -> void:
	if _ficha.is_empty():
		return
	_vinculos = RegistroCivil.vinculos(int(_ficha["id"]))
	_selecionado = 0
	_rolagem = 0
	_tela = Tela.VINCULOS
	AudioDirector.tocar_ui(&"celular_ok", -14.0)


## Que tipo de busca o texto digitado pede.
##
## Nao ha botao para escolher entre CPF e nome, e nao deve haver: o que foi
## digitado ja diz qual dos dois e. Um campo com dois modos e um seletor exige
## que o jogador acerte o modo antes de acertar o dado.
static func _e_numero(texto: String) -> bool:
	if texto == "":
		return true
	for i in texto.length():
		var c := texto.unicode_at(i)
		if not (c >= 48 and c <= 57) and c != 46 and c != 45:
			return false
	return true


func _consultar() -> void:
	if _digitado.strip_edges() == "":
		return
	if not _e_numero(_digitado):
		_consultar_nome()
		return

	var id := RegistroCivil.id_de_cpf(_digitado)
	if id < 0:
		# Numero inventado quase sempre cai aqui, e e para cair: o CPF e o
		# endereco da ficha, e nao um sorteio. Ver RegistroCivil.
		_aviso = "REGISTRO NAO ENCONTRADO PARA ESTE NUMERO."
		AudioDirector.tocar_ui(&"celular_erro", -10.0)
		return
	AudioDirector.tocar_ui(&"celular_ok", -10.0)
	_resultados.clear()
	_mostrar_ficha(RegistroCivil.identidade(id))


## Busca por nome. Um resultado abre direto; varios abrem a lista.
##
## Abrir direto quando so ha um nao e atalho de conveniencia: e o caso do balcao.
## O cliente largou a identidade, o leitor mandou o nome para ca, e parar numa
## lista de um item so para o jogador apertar Enter de novo seria cerimonia.
func _consultar_nome() -> void:
	_procurado = _digitado.strip_edges()
	_resultados = RegistroCivil.buscar_por_nome(_procurado)
	_selecionado = 0
	_rolagem = 0

	if _resultados.is_empty():
		_tela = Tela.RESULTADOS
		AudioDirector.tocar_ui(&"celular_erro", -10.0)
		return
	AudioDirector.tocar_ui(&"celular_ok", -10.0)
	if _resultados.size() == 1:
		_mostrar_ficha(RegistroCivil.identidade(_resultados[0]))
		return
	_tela = Tela.RESULTADOS


func _mostrar_ficha(f: Dictionary) -> void:
	if f.is_empty():
		_aviso = "REGISTRO NAO ENCONTRADO."
		return
	_ficha = f
	# Colorida, e nao tingida de verde: aqui nao ha visor de LCD para imitar.
	_foto = Retrato.gerar_textura(f.get("aparencia", {}))
	_tela = Tela.FICHA
	# Consultar alguem poe a pessoa na agenda do celular, igual ao portal. E o
	# registro de quem voce foi atras, e nao importa em que tela voce foi.
	RegistroCivil.conhecer(int(f["id"]))


## A ficha aberta agora, ou vazia. Publica para a verificacao automatizada poder
## conferir que o que o terminal mostra e a pessoa daquele CPF, e nao uma ficha
## bonita e vazia.
func ficha_aberta() -> Dictionary:
	return _ficha


## Se a foto da ficha aberta chegou a ser montada. E medida separada da ficha de
## proposito: o retrato ja nasceu branco uma vez por ter sido criado dentro da
## passada de canvas, e nada no console avisou.
func tem_foto() -> bool:
	return _foto != null


## Abre o terminal ja na ficha de alguem, sem passar pelo campo de busca.
##
## E por aqui que o leitor de codigo do balcao entra: o jogador passou a
## identidade do cliente no sensor, e o que ele espera ver ao olhar para o
## monitor e a pessoa — nao um campo vazio esperando que ele digite um numero que
## acabou de ler na carteira.
## Devolve FALSE quando nao deu para abrir.
##
## E a parte que faltava. `abrir` recusa em silencio quando ha telefone na mao,
## conversa em andamento ou o jogo esta pausado — o que e correto —, mas quem
## chamou daqui de fora ficava sem saber. No balcao isso travava o jogador: quem
## o travou para virar a camera contava com o terminal para destravar, e o
## terminal nunca chegava a abrir.
func abrir_com_ficha(f: Dictionary) -> bool:
	if f.is_empty():
		return false
	if not ativo:
		abrir()
		if not ativo:
			return false
	_resultados.clear()
	_digitado = ""
	_aviso = ""
	_mostrar_ficha(f)
	_quadro.queue_redraw()
	return true


## Digita `texto` no campo e consulta, como se alguem tivesse teclado.
##
## Publica para a captura automatizada e para a verificacao: as duas precisam
## chegar na tela de resultados, e nenhuma das duas tem dedos.
func buscar(texto: String) -> void:
	if not ativo:
		abrir()
	_digitado = texto.to_upper()
	_aviso = ""
	_consultar()
	_quadro.queue_redraw()


## Publica: a verificacao automatizada abre uma ficha sem digitar.
func consultar_cpf(cpf: String) -> bool:
	var id := RegistroCivil.id_de_cpf(cpf)
	if id < 0:
		return false
	_mostrar_ficha(RegistroCivil.identidade(id))
	_quadro.queue_redraw()
	return true
