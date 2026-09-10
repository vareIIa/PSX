## Autoload. O aparelho no bolso.
##
## O que ele e, na pratica
## -----------------------
## E a segunda metade do registro civil. A primeira e a carteira que o NPC tira
## do bolso e mostra; esta e a consulta: digitar um numero e receber a ficha de
## alguem que voce nem precisa ter encontrado. As duas juntas formam o laco que
## o pedido descreve — cruzar com uma pessoa, ver o documento dela, anotar o CPF,
## consultar em casa, achar a mae, o endereco e quem mais mora la.
##
## Por que a tela e desenhada, e nao montada com Label
## ---------------------------------------------------
## O aparelho tem sete telas diferentes (inicio, login, menu, consulta, ficha,
## vinculos, agenda) e todas cabem em 130 por 186 pixels. Montar cada uma
## com nos daria umas oitenta caixas de texto ligadas e escondidas, e mexer numa
## linha exigiria achar qual. Desenhando, cada tela e uma funcao de vinte linhas
## que le o estado e pinta. O mapa e a unica excecao, porque ele ja e um Control
## que sabe se desenhar, e duplicar isso seria pior. O GPS saiu daqui e virou
## `gps.gd`: deitado, o visor muda de proporcao e nenhuma medida deste arquivo
## vale mais.
##
## Sobre o teclado: o jogador digita o CPF nos numeros do teclado mesmo. Foi
## testado com teclado na tela e navegacao por setas, e digitar onze digitos com
## seta e um castigo — a fluidez que o pedido pede aqui quer dizer "deixa a
## pessoa digitar".
extends CanvasLayer

const UI := "res://assets/ui/%s.png"
const FONTE_P := "res://assets/fontes/psx_pequena.fnt"
const FONTE_MONO := "res://assets/fontes/psx_mono.fnt"

const TELA := Vector2(480.0, 270.0)
## Corpo do aparelho, no tamanho em que a textura foi desenhada.
const CORPO := Rect2(300.0, 9.0, 168.0, 252.0)
## Vao da tela dentro do corpo. Casa com o retangulo escuro de gerar_npc.py.
##
## Cento e quarenta e seis pixels de largura. A fonte pequena rende uns nove por
## caractere, entao a regra de ouro de todo texto deste arquivo e DEZESSEIS
## LETRAS POR LINHA. Passou disso, corta.
const VISOR := Rect2(311.0, 43.0, 146.0, 186.0)

const BARRA := 11.0
const TITULO := 13.0

# Paleta de aparelho de 1998: verde de LCD sobre fundo quase preto.
const FUNDO := Color("101a14")
const VERDE := Color("9fd8a0")
const VERDE_FRACO := Color("5c8a63")
const VERDE_FORTE := Color("d8f2c8")
const ALERTA := Color("d98a5c")
const CAIXA := Color("1c2c22")

const APPS: Array[Dictionary] = [
	{"id": &"portal", "nome": "PORTAL", "cor": Color("2f5d43")},
	{"id": &"contatos", "nome": "AGENDA", "cor": Color("3d4f66")},
	{"id": &"mapa", "nome": "GPS", "cor": Color("5b5230")},
	{"id": &"mensagens", "nome": "MENSAGENS", "cor": Color("4a3550")},
	{"id": &"telefone", "nome": "TELEFONE", "cor": Color("2f4a5d")},
	{"id": &"camera", "nome": "CAMERA", "cor": Color("5d3535")},
	{"id": &"galeria", "nome": "GALERIA", "cor": Color("46504a")},
	{"id": &"radio", "nome": "RADIO", "cor": Color("57452c")},
	{"id": &"config", "nome": "AJUSTES", "cor": Color("3a3f45")},
]

enum Tela { INICIO, PORTAL, AGENDA, SEM_SINAL, AJUSTES }
enum Portal { LOGIN, MENU, CONSULTA, FICHA, VINCULOS }

signal abriu()
signal fechou()

var ativo: bool = false
## Bateria, de 0 a 1. Cai devagar e nao faz nada: e mostrador, nao mecanica.
## Um segundo recurso para administrar, ao lado da pilha da lanterna, so tiraria
## o peso que a pilha tem.
var bateria: float = 0.87

var _raiz: Control
var _visor: Control
var _fonte: Font
var _mono: Font
var _icones: Dictionary[StringName, Texture2D] = {}

var _tela: Tela = Tela.INICIO
var _portal: Portal = Portal.LOGIN
var _selecionado: int = 0
var _logado: bool = false
var _digitado: String = ""
var _aviso: String = ""
var _ficha: Dictionary = {}
## Foto da ficha aberta, montada UMA vez quando a ficha abre.
##
## Nao pode ser criada dentro do desenho. Uma ImageTexture nascida no meio da
## passada de canvas nao tem os dados enviados a tempo e o motor desenha branco;
## como o visor se redesenha duas vezes por segundo, ela nascia branca sempre.
## Foi meia hora procurando erro de cor num retrato que estava certo.
var _foto: ImageTexture
var _vinculos: Array[Dictionary] = []
var _agenda: Array[int] = []
var _rolagem: int = 0
var _relogio: float = 0.0
var _piscar: float = 0.0


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fonte = load(FONTE_P) as Font
	_mono = load(FONTE_MONO) as Font
	for app: Dictionary in APPS:
		var caminho := UI % ("app_%s" % app["id"])
		if ResourceLoader.exists(caminho):
			_icones[app["id"]] = load(caminho)
	_montar()
	_raiz.visible = false
	set_process(false)


# --- montagem ---------------------------------------------------------------

func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "Celular"
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)

	var corpo := TextureRect.new()
	var caminho := UI % "fone_corpo"
	if ResourceLoader.exists(caminho):
		corpo.texture = load(caminho)
	corpo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	corpo.stretch_mode = TextureRect.STRETCH_SCALE
	corpo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	corpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(corpo)
	corpo.position = CORPO.position
	corpo.size = CORPO.size

	_visor = Control.new()
	_visor.name = "Visor"
	_visor.clip_contents = true
	_visor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_visor)
	_visor.position = VISOR.position
	_visor.size = VISOR.size
	_visor.draw.connect(_desenhar)


# --- abrir e fechar ---------------------------------------------------------

func abrir() -> void:
	# O aparelho deitado tem a mesma prioridade que o em pe: com os dois abertos,
	# o GPS (camada 129) desenharia por cima deste (128) e as duas telas
	# disputariam a mesma tecla. Quem vem do GPS chega aqui DEPOIS de ele se
	# fechar, entao a guarda nao atrapalha a volta para a grade de icones.
	if ativo or Gps.ativo:
		return
	ativo = true
	_tela = Tela.INICIO
	_aviso = ""
	_raiz.visible = true
	set_process(true)
	_travar_jogador(true)
	AudioDirector.tocar_ui(&"celular_abre", -8.0)
	_animar_entrada()
	_visor.queue_redraw()
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


## Sobe pela direita, como quem tira do bolso. Aparecer no lugar le como janela.
func _animar_entrada() -> void:
	_raiz.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var t := create_tween().set_parallel(true)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_raiz, "modulate", Color.WHITE, 0.12)
	_raiz.position = Vector2(14.0, 26.0)
	t.tween_property(_raiz, "position", Vector2.ZERO, 0.2)


func _process(delta: float) -> void:
	_relogio += delta
	_piscar += delta
	# Uma carga de aparelho da epoca durava dias; aqui ela dura umas duas horas
	# de jogo, so para o mostrador nao ser um enfeite congelado.
	bateria = maxf(0.0, bateria - delta / 7200.0)
	if fmod(_piscar, 0.5) < delta:
		_visor.queue_redraw()


# --- desenho ----------------------------------------------------------------

func _texto(pos: Vector2, texto: String, cor: Color = VERDE,
		fonte: Font = null, largura: float = -1.0,
		alinhamento: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f := fonte if fonte != null else _fonte
	if f == null:
		return
	_visor.draw_string(f, pos, texto, alinhamento, largura, 11, cor)


func _caixa(r: Rect2, cor: Color, preenchido: bool = true) -> void:
	_visor.draw_rect(r, cor, preenchido, 1.0 if not preenchido else -1.0)


func _desenhar() -> void:
	_visor.draw_rect(Rect2(Vector2.ZERO, VISOR.size), FUNDO)
	_desenhar_barra()

	match _tela:
		Tela.INICIO:
			_desenhar_inicio()
		Tela.PORTAL:
			_desenhar_portal()
		Tela.AGENDA:
			_desenhar_agenda()
		Tela.SEM_SINAL:
			_desenhar_sem_sinal()
		Tela.AJUSTES:
			_desenhar_ajustes()

	if _aviso != "":
		_caixa(Rect2(4.0, VISOR.size.y - 30.0, VISOR.size.x - 8.0, 15.0), CAIXA)
		_texto(Vector2(8.0, VISOR.size.y - 19.0), _aviso, ALERTA)

	# Linhas de varredura do LCD. Duas coisas de uma vez: dizem que aquilo e uma
	# tela dentro do mundo, e quebram o verde chapado que sem elas parece papel.
	for y in range(0, int(VISOR.size.y), 3):
		_visor.draw_rect(Rect2(0.0, float(y), VISOR.size.x, 1.0),
			Color(0.0, 0.0, 0.0, 0.16))


func _desenhar_barra() -> void:
	_caixa(Rect2(0.0, 0.0, VISOR.size.x, BARRA), CAIXA)
	_texto(Vector2(3.0, 8.0), "REDE", VERDE_FRACO)
	# A hora anda com a partida, a partir do fundo da madrugada. Relogio parado
	# num jogo que fala de tres dias sem dormir e uma mentira que se percebe.
	var minutos := 134 + int(_relogio / 6.0)
	_texto(Vector2(VISOR.size.x * 0.5 - 12.0, 8.0),
		"%02d:%02d" % [(minutos / 60) % 24, minutos % 60], VERDE)
	var largura := 12.0
	var x := VISOR.size.x - largura - 4.0
	_caixa(Rect2(x, 3.0, largura, 6.0), VERDE_FRACO, false)
	_caixa(Rect2(x + largura, 5.0, 1.5, 2.0), VERDE_FRACO)
	_caixa(Rect2(x + 1.0, 4.0, (largura - 2.0) * bateria, 4.0),
		VERDE if bateria > 0.2 else ALERTA)


func _desenhar_titulo(texto: String) -> void:
	_caixa(Rect2(0.0, BARRA, VISOR.size.x, TITULO), Color("26402f"))
	_texto(Vector2(4.0, BARRA + 10.0), texto, VERDE_FORTE)


func _desenhar_inicio() -> void:
	var app := APPS[_selecionado]
	_desenhar_titulo(String(app["nome"]).substr(0, 16))

	var lado := 42.0
	var vao := 5.0
	var x0 := (VISOR.size.x - (lado * 3.0 + vao * 2.0)) * 0.5
	var y0 := BARRA + TITULO + 8.0
	for i in APPS.size():
		var col := i % 3
		var lin := i / 3
		var r := Rect2(x0 + float(col) * (lado + vao),
			y0 + float(lin) * (lado + vao), lado, lado)
		_caixa(r, APPS[i]["cor"])
		if i == _selecionado:
			# A moldura pisca. Numa grade de nove icones sem cursor nao da para
			# saber onde se esta sem contar as casas.
			_caixa(r.grow(1.0), VERDE_FORTE if fmod(_piscar, 1.0) < 0.6 else VERDE, false)
		var icone: Texture2D = _icones.get(APPS[i]["id"])
		if icone != null:
			_visor.draw_texture_rect(icone,
				Rect2(r.position + Vector2(13.0, 13.0), Vector2(16.0, 16.0)), false)

	_texto(Vector2(4.0, VISOR.size.y - 14.0), "[WASD] MOVER", VERDE_FRACO)
	_texto(Vector2(4.0, VISOR.size.y - 3.0), "[E] ABRIR [C] SAI", VERDE_FRACO)


func _desenhar_sem_sinal() -> void:
	_desenhar_titulo(String(APPS[_selecionado]["nome"]).substr(0, 16))
	_texto(Vector2(8.0, 70.0), "SEM RESPOSTA", VERDE)
	_texto(Vector2(8.0, 82.0), "DO SERVIDOR.", VERDE)
	_texto(Vector2(8.0, 102.0), "A REDE CAIU NA", VERDE_FRACO)
	_texto(Vector2(8.0, 113.0), "TERCA E NAO", VERDE_FRACO)
	_texto(Vector2(8.0, 124.0), "VOLTOU.", VERDE_FRACO)
	_texto(Vector2(4.0, VISOR.size.y - 3.0), "[ESC] VOLTAR", VERDE_FRACO)


func _desenhar_ajustes() -> void:
	_desenhar_titulo("AJUSTES")
	var y := BARRA + TITULO + 14.0
	_texto(Vector2(6.0, y), "APARELHO", VERDE_FORTE)
	_texto(Vector2(6.0, y + 14.0), "BATERIA %d%%" % roundi(bateria * 100.0), VERDE)
	_texto(Vector2(6.0, y + 26.0), "REDE    FRACA", VERDE)
	_texto(Vector2(6.0, y + 38.0), "LINHA   ---", VERDE)
	_texto(Vector2(6.0, y + 58.0), "PORTADOR", VERDE_FORTE)
	var eu := RegistroCivil.jogador
	if eu.is_empty():
		_texto(Vector2(6.0, y + 72.0), "SEM PORTADOR", ALERTA)
	else:
		_texto(Vector2(6.0, y + 72.0), String(eu["nome"]).substr(0, 16), VERDE)
		_texto(Vector2(6.0, y + 84.0), String(eu["cpf"]), VERDE, _mono)
	_texto(Vector2(4.0, VISOR.size.y - 3.0), "[ESC] VOLTAR", VERDE_FRACO)


# --- portal -----------------------------------------------------------------

func _desenhar_portal() -> void:
	_desenhar_titulo("PORTAL")
	match _portal:
		Portal.LOGIN:
			_portal_login()
		Portal.MENU:
			_portal_menu()
		Portal.CONSULTA:
			_portal_consulta()
		Portal.FICHA:
			_portal_ficha()
		Portal.VINCULOS:
			_portal_vinculos()


func _campo_digitado(y: float, etiqueta: String) -> void:
	_texto(Vector2(6.0, y), etiqueta, VERDE_FRACO)
	_caixa(Rect2(4.0, y + 4.0, VISOR.size.x - 8.0, 15.0), CAIXA)
	var mostrado := _formatar_cpf(_digitado)
	if fmod(_piscar, 0.8) < 0.45 and _digitado.length() < 11:
		mostrado += "_"
	_texto(Vector2(8.0, y + 15.0), mostrado, VERDE_FORTE, _mono)


static func _formatar_cpf(digitos: String) -> String:
	var s := ""
	for i in digitos.length():
		if i == 3 or i == 6:
			s += "."
		elif i == 9:
			s += "-"
		s += digitos[i]
	return s


func _portal_login() -> void:
	var y := BARRA + TITULO + 10.0
	_texto(Vector2(6.0, y), "IDENTIFIQUE-SE", VERDE_FORTE)
	_texto(Vector2(6.0, y + 12.0), "DIGITE O CPF DO", VERDE_FRACO)
	_texto(Vector2(6.0, y + 23.0), "PORTADOR.", VERDE_FRACO)
	_campo_digitado(y + 40.0, "CPF")
	_texto(Vector2(6.0, y + 78.0), "0-9 DIGITAR", VERDE_FRACO)
	_texto(Vector2(6.0, y + 89.0), "BACKSP. APAGAR", VERDE_FRACO)
	_texto(Vector2(6.0, y + 100.0), "[E] ENTRAR", VERDE_FRACO)
	_texto(Vector2(4.0, VISOR.size.y - 3.0), "[ESC] VOLTAR", VERDE_FRACO)


const MENU_PORTAL: Array[String] = [
	"CONSULTA CPF", "MEUS DADOS", "MEUS LACOS", "SAIR",
]


func _portal_menu() -> void:
	var y := BARRA + TITULO + 12.0
	var eu := RegistroCivil.jogador
	_texto(Vector2(6.0, y), "CONECTADO COMO", VERDE_FRACO)
	_texto(Vector2(6.0, y + 12.0), String(eu.get("primeiro", "?")), VERDE_FORTE)
	for i in MENU_PORTAL.size():
		var linha_y := y + 34.0 + float(i) * 16.0
		if i == _selecionado:
			_caixa(Rect2(2.0, linha_y - 10.0, VISOR.size.x - 4.0, 14.0), CAIXA)
		_texto(Vector2(8.0, linha_y), ("> " if i == _selecionado else "  ")
			+ MENU_PORTAL[i], VERDE_FORTE if i == _selecionado else VERDE)
	_texto(Vector2(4.0, VISOR.size.y - 3.0), "[ESC] VOLTAR", VERDE_FRACO)


func _portal_consulta() -> void:
	var y := BARRA + TITULO + 10.0
	_texto(Vector2(6.0, y), "CONSULTA DE CPF", VERDE_FORTE)
	_campo_digitado(y + 20.0, "NUMERO")
	_texto(Vector2(6.0, y + 60.0), "[E] CONSULTAR", VERDE_FRACO)
	_texto(Vector2(6.0, y + 74.0), "O NUMERO SAI DA", VERDE_FRACO)
	_texto(Vector2(6.0, y + 85.0), "CARTEIRA DE QUEM", VERDE_FRACO)
	_texto(Vector2(6.0, y + 96.0), "VOCE ENCONTRAR.", VERDE_FRACO)
	_texto(Vector2(4.0, VISOR.size.y - 3.0), "[ESC] VOLTAR", VERDE_FRACO)


func _portal_ficha() -> void:
	if _ficha.is_empty():
		_texto(Vector2(6.0, 60.0), "REGISTRO VAZIO", ALERTA)
		return
	var y := BARRA + TITULO + 8.0
	var f := _ficha

	# A foto vem do mesmo atlas que veste a pessoa na rua. E o que faz o jogador
	# reconhecer na tela alguem com quem falou ha dois quarteiroes.
	#
	# Tingida de verde. A foto sai em cinza-azulado, que num visor de LCD verde
	# aparece como um retangulo branco brilhante e puxa o olho para o lugar
	# errado; multiplicada pelo verde do aparelho ela vira o que seria: uma foto
	# ruim mostrada num telefone ruim.
	#
	# E desenhada no TAMANHO NATIVO, 40x52. Reduzida para 26 px ela virava uma
	# mancha verde: a 40 px o rosto tem quatro pixels de olho e reduzir por 0,65
	# com filtro nearest joga fora dois deles. Uma foto em que nao da para
	# reconhecer a pessoa nao serve para nada aqui, porque reconhecer a pessoa e
	# o proposito inteiro da consulta.
	if _foto != null:
		_visor.draw_texture_rect(_foto, Rect2(4.0, y, float(Retrato.LARGURA),
			float(Retrato.ALTURA)), false)

	_texto(Vector2(48.0, y + 16.0), String(f["cpf"]), VERDE, _mono)
	var situacao := int(f["situacao"])
	_texto(Vector2(48.0, y + 32.0), RegistroCivil.nome_da_situacao(situacao),
		VERDE_FRACO if situacao == RegistroCivil.Situacao.REGULAR else ALERTA)
	# O nome ocupa a largura inteira, embaixo da foto. Ao lado dela sobravam 110
	# px, ou doze letras, e nome brasileiro tem mais que doze.
	_texto(Vector2(4.0, y + 60.0), String(f["nome"]).substr(0, 16), VERDE_FORTE)

	# Pares curtos numa linha; nome de mae e endereco em duas.
	#
	# O visor tem 146 px e a fonte rende nove por caractere: um par
	# "etiqueta valor" na mesma linha so cabe quando o valor tem menos de dez
	# letras. Empilhar e feio e legivel; alinhar e bonito e cortado no meio.
	#
	# O pai nao aparece aqui de proposito, e nao por falta de espaco na ficha: a
	# carteira em [D] mostra a filiacao inteira e [V] mostra a casa toda. Repetir
	# tudo na primeira tela custaria as duas linhas que faltavam para o endereco
	# nao bater na barra de teclas.
	var ly := y + 72.0
	_texto(Vector2(4.0, ly), "NASC", VERDE_FRACO)
	_texto(Vector2(40.0, ly), String(f["nascimento"]), VERDE, _mono)
	_texto(Vector2(114.0, ly), "M" if StringName(f["sexo"]) == &"M" else "F", VERDE)
	# A naturalidade nao entra aqui. Ela esta na carteira, em [D], e as duas
	# linhas que ela ocuparia sao as que faltavam para o endereco nao encostar na
	# barra de teclas. Numa tela de 146 por 186 essa e a natureza do trabalho.
	ly += 11.0
	_texto(Vector2(4.0, ly), "PROF", VERDE_FRACO)
	_texto(Vector2(40.0, ly), String(f["profissao"]).substr(0, 11), VERDE)

	for par: Array in [["MAE", String(f["mae"])],
			["ENDERECO", String(f["endereco"])]]:
		ly += 12.0
		_texto(Vector2(4.0, ly), String(par[0]), VERDE_FRACO)
		ly += 10.0
		_texto(Vector2(8.0, ly), String(par[1]).substr(0, 16), VERDE)

	_texto(Vector2(4.0, VISOR.size.y - 14.0), "[V] LACOS [D] DOC", VERDE_FRACO)
	_texto(Vector2(4.0, VISOR.size.y - 3.0), "[ESC] VOLTAR", VERDE_FRACO)


func _portal_vinculos() -> void:
	_texto(Vector2(6.0, BARRA + TITULO + 10.0), "MESMO ENDERECO", VERDE_FORTE)
	if _vinculos.is_empty():
		_texto(Vector2(6.0, 70.0), "NENHUM VINCULO", VERDE_FRACO)
		return
	var y := BARRA + TITULO + 24.0
	var cabem := 6
	_rolagem = clampi(_rolagem, 0, maxi(0, _vinculos.size() - cabem))
	_selecionado = clampi(_selecionado, 0, _vinculos.size() - 1)
	for i in range(_rolagem, mini(_vinculos.size(), _rolagem + cabem)):
		var v := _vinculos[i]
		var linha_y := y + float(i - _rolagem) * 24.0
		if i == _selecionado:
			_caixa(Rect2(2.0, linha_y - 9.0, VISOR.size.x - 4.0, 22.0), CAIXA)
		var morto := int(v["situacao"]) == RegistroCivil.Situacao.FALECIDO
		_texto(Vector2(6.0, linha_y), String(v["nome"]).substr(0, 16),
			ALERTA if morto else (VERDE_FORTE if i == _selecionado else VERDE))
		_texto(Vector2(6.0, linha_y + 10.0), "%s, %d ANOS"
			% [v["relacao"], int(v["idade"])], VERDE_FRACO)
	_texto(Vector2(4.0, VISOR.size.y - 3.0), "[E] ABRIR [ESC]", VERDE_FRACO)


# --- agenda -----------------------------------------------------------------

func _desenhar_agenda() -> void:
	_desenhar_titulo("AGENDA")
	if _agenda.is_empty():
		_texto(Vector2(6.0, 70.0), "VAZIA.", VERDE)
		_texto(Vector2(6.0, 88.0), "FALE COM ALGUEM", VERDE_FRACO)
		_texto(Vector2(6.0, 99.0), "NA RUA E O NOME", VERDE_FRACO)
		_texto(Vector2(6.0, 110.0), "APARECE AQUI.", VERDE_FRACO)
		_texto(Vector2(4.0, VISOR.size.y - 3.0), "[ESC] VOLTAR", VERDE_FRACO)
		return

	var cabem := 6
	_selecionado = clampi(_selecionado, 0, _agenda.size() - 1)
	_rolagem = clampi(_rolagem, maxi(0, _selecionado - cabem + 1),
		maxi(0, _agenda.size() - 1))
	_rolagem = mini(_rolagem, _selecionado)
	var y := BARRA + TITULO + 14.0
	for i in range(_rolagem, mini(_agenda.size(), _rolagem + cabem)):
		var f := RegistroCivil.identidade(_agenda[i])
		var linha_y := y + float(i - _rolagem) * 24.0
		if i == _selecionado:
			_caixa(Rect2(2.0, linha_y - 9.0, VISOR.size.x - 4.0, 22.0), CAIXA)
		var eu := _agenda[i] == RegistroCivil.id_do_jogador()
		_texto(Vector2(6.0, linha_y), String(f["nome"]).substr(0, 16),
			VERDE_FORTE if i == _selecionado else VERDE)
		_texto(Vector2(6.0, linha_y + 10.0),
			("VOCE" if eu else String(f["cpf"])), VERDE_FRACO, _mono)
	_texto(Vector2(4.0, VISOR.size.y - 3.0), "[E] VER  [ESC]", VERDE_FRACO)


# --- entrada ----------------------------------------------------------------

func _pode_abrir() -> bool:
	return not (Conversa.ativo or Dialogo.ativo or Documento.ativo
		or Gps.ativo or Terminal.ativo or get_tree().paused)


func _input(evento: InputEvent) -> void:
	if not ativo:
		if evento.is_action_pressed("celular") and _pode_abrir():
			abrir()
			get_viewport().set_input_as_handled()
		return
	if Documento.ativo:
		return

	if evento.is_action_pressed("celular"):
		fechar()
		get_viewport().set_input_as_handled()
		return

	var tecla := evento as InputEventKey
	if tecla != null and tecla.pressed and not tecla.echo:
		if _tecla_digitada(tecla):
			get_viewport().set_input_as_handled()
			_visor.queue_redraw()
			return

	if evento.is_action_pressed("pausa"):
		_voltar()
	elif evento.is_action_pressed("interagir") or evento.is_action_pressed("ui_accept"):
		_acionar()
	elif evento.is_action_pressed("mover_tras") or evento.is_action_pressed("ui_down"):
		_mover(1, 0)
	elif evento.is_action_pressed("mover_frente") or evento.is_action_pressed("ui_up"):
		_mover(-1, 0)
	elif evento.is_action_pressed("mover_dir") or evento.is_action_pressed("ui_right"):
		_mover(0, 1)
	elif evento.is_action_pressed("mover_esq") or evento.is_action_pressed("ui_left"):
		_mover(0, -1)
	else:
		return
	get_viewport().set_input_as_handled()
	_visor.queue_redraw()


## Digitos, apagar e os atalhos de uma letra so. Devolve true se consumiu.
func _tecla_digitada(tecla: InputEventKey) -> bool:
	var codigo := tecla.keycode
	var esperando_numero := _tela == Tela.PORTAL and (_portal == Portal.LOGIN
		or _portal == Portal.CONSULTA)

	if esperando_numero:
		if codigo >= KEY_0 and codigo <= KEY_9 and _digitado.length() < 11:
			_digitado += str(codigo - KEY_0)
			AudioDirector.tocar_ui(&"celular_tecla", -14.0)
			return true
		if codigo >= KEY_KP_0 and codigo <= KEY_KP_9 and _digitado.length() < 11:
			_digitado += str(codigo - KEY_KP_0)
			AudioDirector.tocar_ui(&"celular_tecla", -14.0)
			return true
		if codigo == KEY_BACKSPACE:
			_digitado = _digitado.substr(0, maxi(0, _digitado.length() - 1))
			AudioDirector.tocar_ui(&"celular_tecla", -18.0)
			return true
		if codigo == KEY_TAB and _portal == Portal.LOGIN:
			# Atalho para o proprio CPF. Existe porque digitar onze digitos toda
			# vez que se abre o portal e pedagio, nao jogo — o numero do jogador
			# ele ja tem no bolso.
			var eu := RegistroCivil.jogador
			if not eu.is_empty():
				_digitado = String(eu["cpf"]).replace(".", "").replace("-", "")
				AudioDirector.tocar_ui(&"celular_tecla", -10.0)
			return true

	if _tela == Tela.PORTAL and _portal == Portal.FICHA:
		if codigo == KEY_V:
			_vinculos = RegistroCivil.vinculos(int(_ficha["id"]))
			_selecionado = 0
			_rolagem = 0
			_portal = Portal.VINCULOS
			return true
		if codigo == KEY_D:
			Documento.abrir(_ficha)
			return true
	return false


func _mover(vertical: int, horizontal: int) -> void:
	AudioDirector.tocar_ui(&"clique", -24.0)
	if _tela == Tela.INICIO:
		var col := _selecionado % 3
		var lin := _selecionado / 3
		col = posmod(col + horizontal, 3)
		lin = posmod(lin + vertical, 3)
		_selecionado = lin * 3 + col
		return
	if _tela == Tela.AGENDA and not _agenda.is_empty():
		_selecionado = posmod(_selecionado + vertical, _agenda.size())
		return
	if _tela == Tela.PORTAL and _portal == Portal.MENU:
		_selecionado = posmod(_selecionado + vertical, MENU_PORTAL.size())
		return
	if _tela == Tela.PORTAL and _portal == Portal.VINCULOS and not _vinculos.is_empty():
		_selecionado = posmod(_selecionado + vertical, _vinculos.size())
		if _selecionado < _rolagem:
			_rolagem = _selecionado
		elif _selecionado >= _rolagem + 6:
			_rolagem = _selecionado - 5


func _voltar() -> void:
	_aviso = ""
	if _tela == Tela.PORTAL and _portal != Portal.LOGIN and _portal != Portal.MENU:
		_portal = Portal.MENU
		_selecionado = 0
		return
	if _tela != Tela.INICIO:
		_tela = Tela.INICIO
		_selecionado = 0
		return
	fechar()


func _acionar() -> void:
	_aviso = ""
	match _tela:
		Tela.INICIO:
			_abrir_app(StringName(APPS[_selecionado]["id"]))
		Tela.AGENDA:
			if not _agenda.is_empty():
				_mostrar_ficha(RegistroCivil.identidade(_agenda[_selecionado]))
		Tela.PORTAL:
			_acionar_portal()
		_:
			pass


func _abrir_app(id: StringName) -> void:
	AudioDirector.tocar_ui(&"celular_ok", -12.0)
	match id:
		&"portal":
			_tela = Tela.PORTAL
			_portal = Portal.MENU if _logado else Portal.LOGIN
			_digitado = ""
			_selecionado = 0
		&"contatos":
			_tela = Tela.AGENDA
			_agenda = RegistroCivil.conhecidos()
			_selecionado = 0
			_rolagem = 0
		&"mapa":
			# O GPS nao e uma tela deste arquivo: e o mesmo aparelho DEITADO, em
			# `gps.gd`, com um visor de outra proporcao. Sair dele volta para
			# esta grade, entao a troca le como virar o telefone na mao e nao
			# como trocar de menu.
			fechar()
			Gps.abrir(true)
		&"radio":
			# O unico aplicativo que mexe no mundo: liga o radio que o jogador
			# carrega. Um botao que faz uma coisa que ja existe vale mais que
			# tres telas que nao fazem nada.
			var jogador := get_tree().get_first_node_in_group(&"player")
			if jogador != null and jogador.get("radio") != null:
				(jogador.get("radio") as Node).call("alternar")
				_aviso = "RADIO OK"
			else:
				_aviso = "SEM RADIO"
		&"config":
			_tela = Tela.AJUSTES
		_:
			_tela = Tela.SEM_SINAL
			AudioDirector.tocar_ui(&"celular_erro", -12.0)


func _acionar_portal() -> void:
	match _portal:
		Portal.LOGIN:
			_tentar_login()
		Portal.MENU:
			_menu_portal()
		Portal.CONSULTA:
			_consultar()
		Portal.VINCULOS:
			if not _vinculos.is_empty():
				_mostrar_ficha(RegistroCivil.identidade(
					int(_vinculos[_selecionado]["id"])))
		_:
			pass


func _tentar_login() -> void:
	var id := RegistroCivil.id_de_cpf(_digitado)
	if id < 0:
		_aviso = "CPF INVALIDO"
		AudioDirector.tocar_ui(&"celular_erro", -10.0)
		return
	if id != RegistroCivil.id_do_jogador():
		# Entrar como outra pessoa seria o fim da graca: o portal existe para o
		# jogador precisar do CPF ALHEIO na mao para consultar, e nao para virar
		# a identidade de quem quiser.
		_aviso = "CPF DE OUTRO"
		AudioDirector.tocar_ui(&"celular_erro", -10.0)
		return
	_logado = true
	_portal = Portal.MENU
	_selecionado = 0
	_digitado = ""
	AudioDirector.tocar_ui(&"celular_ok", -8.0)


func _menu_portal() -> void:
	match _selecionado:
		0:
			_portal = Portal.CONSULTA
			_digitado = ""
		1:
			_mostrar_ficha(RegistroCivil.jogador)
		2:
			_vinculos = RegistroCivil.vinculos(RegistroCivil.id_do_jogador())
			_selecionado = 0
			_rolagem = 0
			_portal = Portal.VINCULOS
		_:
			_logado = false
			_portal = Portal.LOGIN
			_digitado = ""


func _consultar() -> void:
	var id := RegistroCivil.id_de_cpf(_digitado)
	if id < 0:
		# Numero inventado quase sempre cai aqui, e e para cair: a consulta so
		# devolve gente porque o CPF e o endereco da ficha, nao um sorteio.
		_aviso = "NAO ENCONTRADO"
		AudioDirector.tocar_ui(&"celular_erro", -10.0)
		return
	AudioDirector.tocar_ui(&"celular_ok", -10.0)
	_mostrar_ficha(RegistroCivil.identidade(id))


func _mostrar_ficha(f: Dictionary) -> void:
	if f.is_empty():
		_aviso = "NAO ENCONTRADO"
		return
	_ficha = f
	_foto = Retrato.gerar_textura_lcd(f.get("aparencia", {}), FUNDO, VERDE)
	_tela = Tela.PORTAL
	_portal = Portal.FICHA
	# Consultar alguem poe a pessoa na agenda. E o registro de quem voce foi
	# atras, que e uma trilha diferente da de quem voce encontrou na rua.
	RegistroCivil.conhecer(int(f["id"]))


## Publica: a verificacao automatizada abre uma ficha sem digitar.
func consultar_cpf(cpf: String) -> bool:
	var id := RegistroCivil.id_de_cpf(cpf)
	if id < 0:
		return false
	_logado = true
	_mostrar_ficha(RegistroCivil.identidade(id))
	_visor.queue_redraw()
	return true
