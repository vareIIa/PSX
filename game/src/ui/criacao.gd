## Criacao de personagem: a propria carteira, aberta nas maos.
##
## A forma e o assunto
## -------------------
## Isto nao e um menu de opcoes com um boneco do lado. E o documento do jogador,
## aberto e segurado por ele — as maos aparecem embaixo, com a manga da camisa
## que ele acabou de escolher e a cor de pele que ele acabou de escolher. A
## pagina da esquerda tem a foto; a da direita tem os campos.
##
## Isso resolve de uma vez uma coisa que um menu nao resolve: o jogo inteiro
## depois desta tela e sobre documento — o NPC mostra o dele, o portal do celular
## consulta pelo CPF, a carteira fica no inventario. Comecar a partida montando a
## propria carteira poe o jogador dentro dessa gramatica antes da primeira rua.
##
## O que se escolhe, e o que nao
## -----------------------------
## Rosto, pele, cabelo, roupa, calca, chapeu, altura e porte. Numero, data de
## nascimento e naturalidade estao impressos na mesma pagina e nao se mexem:
## sairam do registro civil quando a ficha foi emitida. Ver os dois lado a lado e
## o que diz isso sem uma linha de texto explicando.
##
## O retrato e 3D de verdade: um SubViewport com mundo proprio e o MESMO Corpo
## que anda na calcada, montado pela mesma funcao. Trocar de camisa aqui e trocar
## a malha que vai andar na rua daqui a dez segundos, e por isso o retrato nao
## tem como mentir.
class_name CriacaoAparencia
extends Control

const UI := "res://assets/ui/%s.png"
const FONTE_MONO := "res://assets/fontes/psx_mono.fnt"
const ATLAS := "res://assets/textures/npc_atlas.png"
const ATLAS_HD := "res://assets/textures_hd/npc_atlas.png"

const TELA := Vector2(480.0, 270.0)

## A carteira aberta, e TODO o resto do documento sai destes quatro numeros.
##
## Antes daqui cada peca trazia a propria coordenada absoluta: as duas paginas,
## o retrato, a primeira linha de campo, a fileira de abas, o visto e a altura
## da pega das maos. Sete lugares para o mesmo valor. Descer a carteira trinta
## pixels significava achar os sete, e o que ficasse para tras so aparecia em
## captura — o visto flutuando fora do papel, a aba na altura errada. Ja
## aconteceu, e o comentario de `LINHA_UM` ja avisava que ia acontecer de novo.
##
## Agora move-se `DOC_Y` e a carteira inteira desce junto.
const DOC_X := CarteiraLayout.DOC_X
const DOC_Y := CarteiraLayout.DOC_Y
const DOC_L := CarteiraLayout.DOC_L
const DOC_A := CarteiraLayout.DOC_A
const DOC := CarteiraLayout.DOC

## A carteira fica RETA.
##
## Ela entrava com 1,4 grau de inclinacao, pela regra da casa de que coisa
## segurada na mao nao fica reta — a mesma da prancha de inventario. Numa
## prancha de madeira aquilo le como peso; num documento de 308 por 156 numa
## tela de 480 por 270, com texto miudo e um retrato retangular dentro, le como
## imagem torta. O papel continua respirando: `_angulo_doc` mantem um balanco de
## um sexto de grau, que e movimento sem ser tortura de linha reta.
const INCLINACAO := 0.0
const PAGINA_ESQ := CarteiraLayout.PAGINA_ESQ
const PAGINA_DIR := CarteiraLayout.PAGINA_DIR
const RETRATO := CarteiraLayout.RETRATO

const TINTA := Color("22301f")
const TINTA_FRACA := Color("5c6b52")
const PAPEL := Color("ebe6d4")
const VINCO := Color("c4bba8")
const DESTAQUE := Color("8a2f1f")
## Capa azul do passaporte (print02) — filete sob o papel.
const CAPA := Color("2c4570")
const CELULA_SEL := Color("f4f1e6")

## Abas de categoria. Cada uma diz quais campos de Aparencia.AJUSTES mostra.
## As abas moram em `CarteiraLayout`: e a aba mais cheia que decide a altura
## do documento, e quem mede isso e o teste.
const ABAS := CarteiraLayout.ABAS


## Primeira linha navegavel: a fileira de abas. Depois vem um campo por linha, e
## por ultimo o visto de aceite.
const LINHA_ABAS := 0

## Onde a primeira linha de campo comeca, em pixels de tela.
##
## E uma constante e nao um numero solto porque a carteira encolheu uma vez e
## vai encolher de novo: com a altura escrita em cada funcao, mudar a folha
## significa cacar o mesmo numero em quatro lugares e descobrir na captura o que
## ficou para tras. A altura de cada linha vem de `_altura_do_campo`.
const LINHA_UM := CarteiraLayout.LINHA_UM
const CAMPO_ROTULO := CarteiraLayout.CAMPO_ROTULO
const CAMPO_RESPIRO := CarteiraLayout.CAMPO_RESPIRO
const CAMPO_WIDGET := CarteiraLayout.CAMPO_WIDGET
const CAMPOS_FUNDO := CarteiraLayout.CAMPOS_FUNDO

signal confirmou()
signal voltou()

var _ajustes: Dictionary = {}
var _aba: int = 0
var _linha: int = 0
var _relogio: float = 0.0

## O retrato 3D, com camera de zoom e giro. Ver `RetratoEstudio`.
var _estudio: RetratoEstudio
## Arrastando o retrato para girar a pessoa.
var _girando: bool = false
## Clarao curto no retrato a cada troca: a foto "bateu" de novo.
var _clarao: float = 0.0
## Pagina visivel de cada campo de celula com mais de oito opcoes.
var _pagina: Dictionary = {}
var _hover_retrato: bool = false
var _atlas: Texture2D
var _fonte: Font
var _fonte_media: Font
var _mono: Font
var _guilhoche: Texture2D
var _brasao: Texture2D
var _vinheta: Texture2D
var _arrastando_chave: StringName = &""
var _arrastando_campo: Dictionary = {}
const BOTAO_VOLTAR := Rect2(64.0, 252.0, 110.0, 15.0)
const BOTAO_CONFIRMAR := Rect2(306.0, 252.0, 110.0, 15.0)
## Fundo de cabine atras da carteira: PackedScene 3D (preferido) ou PNG.
const CABINE_CENA := "res://scenes/player/cabine_fundo_criacao.tscn"
var _cabine: Texture2D
var _cabine_viewport: SubViewport
var _hover_aba: int = -1
var _hover_celula: int = -99
## Em qual campo da aba o mouse esta. A celula sozinha nao dizia: o indice 3
## da cor e o indice 3 do rosto acendiam juntos.
var _hover_campo: int = -1
var _hover_visto: bool = false

# --- animacao da tela --------------------------------------------------------
#
# A tela era um quadro parado que trocava de conteudo por corte seco. Documento
# de verdade chega nas maos, vira a folha, recebe carimbo. Cada um desses gestos
# e um numero de 0 a 1 aqui, e o `_process` so anda com eles.

## Quanto a carteira ja subiu ate as maos. 0 e fora do quadro, embaixo.
var _abertura: float = 1.0
## Descendo para fora do quadro, a caminho da tela anterior. -1 e parado.
var _saida: float = -1.0
## O relogio da emissao: foto, carimbo, pausa, carteira baixando. -1 e parado.
var _emissao: float = -1.0
## Tranco do carimbo batendo, que some sozinho.
var _tremor: float = 0.0
## Folha virando na troca de aba. 1 e virada.
var _virada: float = 1.0
var _virada_dir: int = 1
## Ha quanto tempo os campos da aba estao na folha. Eles entram um a um.
var _revela: float = 10.0
## Largura e altura de cada aba de indice, andando ate o alvo.
var _larg_abas: Array[float] = []
var _alt_abas: Array[float] = []
## Modelo trocado: [direcao, quando]. O nome novo entra deslizando dela.
var _desliza: Dictionary = {}
## Escolha feita: quando. O anel em volta da selecao pulsa uma vez.
var _pop: Dictionary = {}
## Onde o cursor do deslizador esta desenhado, correndo atras do valor.
var _faixa_vista: Dictionary = {}
## [campo, codigo, quando]: o botao apertado afunda por um instante.
var _apertado: Array = []
var _apertou_visto: float = -1.0
## Qual botao da barra de baixo esta sob o mouse. -1 e nenhum.
var _hover_barra: int = -1
## Onde a carteira esta agora: a pagina inteira anda com isto.
var _xf: Transform2D = Transform2D.IDENTITY
## O ponteiro, em coordenada de tela logica. A pessoa do retrato olha para ele.
var _mouse_tela: Vector2 = Vector2(-1.0, -1.0)
var _digital: Texture2D

const TEMPO_ABERTURA := 0.75
const TEMPO_SAIDA := 0.32
const TEMPO_VIRADA := 0.34
## A emissao em tempos: a foto bate, o carimbo cai, pousa, a carteira desce.
const EMISSAO_CARIMBO := 0.40
const EMISSAO_POUSO := 0.80
const EMISSAO_DESCE := 1.55
const EMISSAO_FIM := 1.95


func _ready() -> void:
	# Menu pausa a arvore nos paineis de papel; este Control precisa continuar
	# recebendo mouse e _process (balanco + hover) mesmo assim.
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	# `set_anchors_and_offsets_preset`, e nao `set_anchors_preset`.
	#
	# A versao sem offsets PRESERVA o retangulo que o Control tem na hora, e na
	# hora ele nao tem nenhum: nasce zero por zero e as offsets sao calculadas
	# para manter zero por zero. Depois o pai cresce, as ancoras acompanham, e
	# as offsets negativas anulam o crescimento — o Control fica com area zero
	# para sempre. Desenha certo (draw_* nao le o retangulo) e nao recebe clique
	# nenhum: era esta linha que deixava "[clique] abas/opcoes" mentindo no
	# rodape desta tela.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_carregar_cabine()
	_atlas = load(ATLAS) as Texture2D
	_fonte = UiEstilo.fonte_re7(400)
	_fonte_media = UiEstilo.fonte_re7(600)
	_mono = load(FONTE_MONO) as Font
	if ResourceLoader.exists(UI % "doc_guilhoche"):
		_guilhoche = load(UI % "doc_guilhoche") as Texture2D
	if ResourceLoader.exists(UI % "doc_brasao"):
		_brasao = load(UI % "doc_brasao") as Texture2D
	if ResourceLoader.exists(UI % "ui_vinheta"):
		_vinheta = load(UI % "ui_vinheta") as Texture2D
	if ResourceLoader.exists(UI % "doc_digital"):
		_digital = load(UI % "doc_digital") as Texture2D
	# Desligado enquanto a tela nao esta aberta: um SubViewport nao para de
	# renderizar so porque o Control que desenha a textura dele esta escondido.
	# Quem liga e desliga e a visibilidade, em `_notification`.
	_estudio = RetratoEstudio.new(Vector2i(int(RETRATO.size.x), int(RETRATO.size.y)))
	add_child(_estudio)


# --- retrato 3D -------------------------------------------------------------

## Refaz o corpo do retrato. A cada mudanca: o Corpo remonta em pouco mais de um
## milissegundo, e um retrato que so atualizasse ao confirmar seria adivinhar em
## vez de escolher.
##
## `reacao` e o gesto que a pessoa faz ao se ver com a peca nova (ver
## `ReacaoCorpo`). O clarao e o obturador: a foto bateu de novo.
func _refazer_corpo(reacao: int = 0) -> void:
	_estudio.vestir(aparencia_atual(), reacao)
	if reacao != 0:
		_clarao = 1.0


## Quanto a tela desenha acima do 480x270, e o que muda com isso.
##
## No MODERNO a janela esta em `canvas_items`: o 2D escala em vetor e o 3D vai
## na resolucao da janela. As duas SubViewports desta tela (a foto e a cabine)
## nao sabiam disso e ficavam em 104 e 480 px esticados. Aqui elas acompanham a
## janela, e as texturas 2D (papel, brasao, digital, miniaturas) passam a filtro
## linear. No PS1 STYLE, `viewport`: fator um e filtro ponto, como sempre.
const TETO_NITIDEZ_RETRATO := 6
const TETO_NITIDEZ_CABINE := 4
var _atlas_hd: Texture2D


func _fator_de_tela() -> int:
	var janela := get_window()
	if janela == null or janela.content_scale_mode != Window.CONTENT_SCALE_MODE_CANVAS_ITEMS:
		return 1
	return maxi(1, int(roundf(float(janela.size.y) / TELA.y)))


func _aplicar_nitidez() -> void:
	var fator := _fator_de_tela()
	_estudio.nitidez(mini(fator, TETO_NITIDEZ_RETRATO))
	if _cabine_viewport != null:
		var f_cab := mini(fator, TETO_NITIDEZ_CABINE)
		_cabine_viewport.size = Vector2i(int(TELA.x) * f_cab, int(TELA.y) * f_cab)
		_cabine_viewport.msaa_3d = (Viewport.MSAA_2X if f_cab > 1
			else Viewport.MSAA_DISABLED)
	texture_filter = (CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if fator > 1
		else CanvasItem.TEXTURE_FILTER_NEAREST)
	if fator > 1 and _atlas_hd == null and ResourceLoader.exists(ATLAS_HD):
		_atlas_hd = load(ATLAS_HD) as Texture2D


## O atlas das miniaturas: o HD quando a tela e nitida, o de 256 no PS1.
func _atlas_das_miniaturas() -> Array:
	if _atlas_hd != null and _fator_de_tela() > 1:
		return [_atlas_hd, 4.0]
	return [_atlas, 1.0]


## Publica: o estudio do retrato, para a verificacao ler zoom e corpo.
func estudio() -> RetratoEstudio:
	return _estudio


## Publica: a verificacao le a aparencia montada sem abrir a tela.
func aparencia_atual() -> Dictionary:
	var ficha := RegistroCivil.jogador
	if ficha.is_empty():
		return Aparencia.de_ficha({"id": 7, "sexo": &"M", "idade": 31})
	return Aparencia.com_ajustes(Aparencia.de_ficha(ficha), _ajustes)


# --- abertura ---------------------------------------------------------------

func abrir() -> void:
	var ja_escolheu := RegistroCivil.jogador.has("ajustes")
	_ajustes = _ajustes_completos(RegistroCivil.ajustes_do_jogador())
	# Primeira vez: o rosto sorteado vem na versao de estudio, que e a mesma
	# cara (mesma coluna) desenhada com palpebra, iris e labio, e sem os oculos
	# e a barba que o sorteio poe sem perguntar. A da cidade continua a uma
	# pagina de distancia.
	if not ja_escolheu and int(_ajustes.get(&"rosto", 0)) < Aparencia.VARIANTES:
		_ajustes[&"rosto"] = int(_ajustes[&"rosto"]) + Aparencia.VARIANTES
	_aba = 0
	_linha = LINHA_ABAS
	_pagina.clear()
	_estudio.de_frente()
	# A carteira comeca fora do quadro e sobe ate as maos; os campos entram
	# depois que ela assenta.
	_abertura = 0.0
	_saida = -1.0
	_emissao = -1.0
	_virada = 1.0
	_revela = -0.45
	_tremor = 0.0
	_pop.clear()
	_desliza.clear()
	_faixa_vista.clear()
	_larg_abas.clear()
	AudioDirector.tocar_ui(&"papel", -14.0)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--criacao-aba="):
			ir_para_aba(a.trim_prefix("--criacao-aba="))
		elif a.begins_with("--criacao-ajuste="):
			# Captura de um corpo especifico: `--criacao-ajuste=gordura:1`. So
			# campos de numero; o resto se escolhe pela tela.
			var par := a.trim_prefix("--criacao-ajuste=").split(":")
			if par.size() == 2 and par[1].is_valid_float():
				_ajustes[StringName(par[0])] = float(par[1])
	_estudio.focar(float(ABAS[_aba].get("zoom", 0.4)))
	_aplicar_nitidez()
	_refazer_corpo()
	# A ficha pode nascer depois de a tela abrir — e o que acontece no caminho de
	# captura, e podia acontecer em qualquer ordem de inicializacao.
	if not RegistroCivil.jogador_mudou.is_connected(_ao_trocar_ficha):
		RegistroCivil.jogador_mudou.connect(_ao_trocar_ficha)
	queue_redraw()


## Liga o retrato so enquanto a carteira esta aberta.
##
## A cabine NAO entra aqui: ela vive mais que esta tela. A ficha de cadastro, que
## vem imediatamente antes, desenha o mesmo fundo — as duas telas sao o mesmo
## carro parado no mesmo minuto — entao quem liga e desliga a cabine e o Menu,
## por `ativar_fundo`, e nao a visibilidade deste Control.
func _notification(o_que: int) -> void:
	if o_que != NOTIFICATION_VISIBILITY_CHANGED:
		return
	if _estudio != null:
		_estudio.ligar(is_visible_in_tree())


## A cabine viva, para quem mais precisar dela desenhar.
##
## Um SubViewport de mundo proprio custa uma estrada, um carro e um ceu; dois
## deles para mostrar a mesma coisa em duas telas seguidas seria pagar duas
## vezes por um plano so — e as duas versoes divergiriam no primeiro ajuste.
func textura_cabine() -> Texture2D:
	if _cabine_viewport != null:
		return _cabine_viewport.get_texture()
	return _cabine


## Liga ou desliga a renderizacao da cabine.
##
## Um SubViewport nao para de desenhar so porque ninguem esta olhando: ele e um
## alvo proprio e continuaria montando estrada, carro e nevoa a sessenta quadros
## por segundo pela partida inteira.
func ativar_fundo(ligado: bool) -> void:
	if _cabine_viewport == null:
		return
	_cabine_viewport.render_target_update_mode = (SubViewport.UPDATE_ALWAYS
		if ligado else SubViewport.UPDATE_DISABLED)


func _ao_trocar_ficha() -> void:
	if not visible or not _ajustes.is_empty():
		return
	_ajustes = _ajustes_completos(RegistroCivil.ajustes_do_jogador())
	_refazer_corpo()
	queue_redraw()


## Os ajustes com TODOS os campos da tela, e nao so os que o save guardou.
##
## Um save de antes dos modelos de peca tem `casaco_usa` e nao tem
## `casaco_estilo`; aberto direto, a aba AGASALHO mostraria NENHUM com a pessoa
## de jaqueta no retrato. Passar pela aparencia montada e voltar traduz o velho
## para o novo, e o que o jogador ve e o que ele esta vestindo.
static func _ajustes_completos(ajustes: Dictionary) -> Dictionary:
	var ficha := RegistroCivil.jogador
	if ficha.is_empty():
		return ajustes
	return Aparencia.ajustes_de(Aparencia.com_ajustes(Aparencia.de_ficha(ficha),
		ajustes))


func _process(delta: float) -> void:
	_relogio += delta
	_congelar_quadro()
	_clarao = maxf(0.0, _clarao - delta * 5.0)
	_tremor = maxf(0.0, _tremor - delta * 5.0)
	if _abertura < 1.0:
		_abertura = minf(1.0, _abertura + delta / TEMPO_ABERTURA)
	if _virada < 1.0:
		_virada = minf(1.0, _virada + delta / TEMPO_VIRADA)
	_revela += delta
	_animar_abas(delta)
	_animar_faixas(delta)
	if _saida >= 0.0:
		_saida += delta / TEMPO_SAIDA
		if _saida >= 1.0:
			_saida = -1.0
			voltou.emit()
	if _emissao >= 0.0:
		_avancar_emissao(delta)
	if _estudio != null:
		_estudio.processar(delta)
		_estudio.olhar_para(_olhar_do_cursor())
	queue_redraw()


## `--criacao-quadro=GESTO:T`: segura um gesto num instante, para a captura.
##
## Os gestos desta tela duram um terco de segundo; a ferramenta de captura
## fotografa um quadro so, e o meio de uma virada de folha nunca cai nele. Com a
## bandeira o relogio do gesto fica preso em T. GESTO e `abertura`, `virada` ou
## `emissao`. Mesmo padrao de `--criacao-aba=`.
func _congelar_quadro() -> void:
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--criacao-quadro="):
			continue
		var partes := a.trim_prefix("--criacao-quadro=").split(":")
		if partes.size() != 2:
			return
		var t := partes[1].to_float()
		match partes[0]:
			"abertura":
				_abertura = t
				_revela = -0.45 + t * TEMPO_ABERTURA
			"virada":
				if _virada >= 1.0 and _virada_dir == 1:
					_virada_dir = 1
				_virada = t
				_revela = -0.12 + t * TEMPO_VIRADA
			"emissao":
				if _emissao < 0.0:
					confirmar()
				_emissao = t
				_tremor = 1.0 if absf(t - EMISSAO_POUSO) < 0.05 else 0.0


## A tela esta no meio de um gesto e nao aceita entrada: subindo, descendo ou
## emitindo. Clique no meio do carimbo nao pode trocar a camisa de quem ja foi
## fotografado.
func _ocupada() -> bool:
	return _abertura < 1.0 or _saida >= 0.0 or _emissao >= 0.0


## Para onde a pessoa do retrato vira a cabeca: o cursor, visto do retrato.
## -1 e 1 sao as bordas da tela. Sem mouse, olha para a frente.
func _olhar_do_cursor() -> float:
	if _mouse_tela.x < 0.0 or _girando:
		return 0.0
	var centro := RETRATO.get_center().x
	return clampf((_mouse_tela.x - centro) / 180.0, -1.0, 1.0)


func _animar_abas(delta: float) -> void:
	var n := ABAS.size()
	if _larg_abas.size() != n:
		_larg_abas.resize(n)
		_alt_abas.resize(n)
		for i in n:
			_larg_abas[i] = _alvo_largura_aba(i)
			_alt_abas[i] = _alvo_altura_aba(i)
		return
	var k := 1.0 - exp(-16.0 * delta)
	for i in n:
		_larg_abas[i] = lerpf(_larg_abas[i], _alvo_largura_aba(i), k)
		_alt_abas[i] = lerpf(_alt_abas[i], _alvo_altura_aba(i), k)


## A aba aberta mede o proprio nome: com largura fixa, "AGASALHO" e
## "ACESSORIO" passavam da borda e o fim da palavra caia na aba vizinha.
func _alvo_largura_aba(i: int) -> float:
	var ativa := maxf(56.0, _largura_do_texto(String(ABAS[_aba]["nome"])) + 26.0)
	return ativa if i == _aba else CarteiraLayout.largura_aba_fechada(ABAS.size(), ativa)


func _alvo_altura_aba(i: int) -> float:
	if i == _aba:
		return CarteiraLayout.ABA_ALTURA_ATIVA
	return CarteiraLayout.ABA_ALTURA + (2.0 if i == _hover_aba else 0.0)


## O cursor do deslizador corre atras do valor em vez de pular: arrastar e
## teclar ficam com o mesmo peso de coisa fisica.
func _animar_faixas(delta: float) -> void:
	var k := 1.0 - exp(-20.0 * delta)
	for campo: Dictionary in Aparencia.AJUSTES:
		if String(campo["tipo"]) != "faixa":
			continue
		var chave: StringName = campo["chave"]
		var alvo := _t_da_faixa(campo)
		_faixa_vista[chave] = lerpf(float(_faixa_vista.get(chave, alvo)), alvo, k)


func _t_da_faixa(campo: Dictionary) -> float:
	var minimo := float(campo["minimo"])
	var maximo := float(campo["maximo"])
	var valor := float(_ajustes.get(campo["chave"], minimo))
	return clampf((valor - minimo) / maxf(0.001, maximo - minimo), 0.0, 1.0)


# --- desenho ----------------------------------------------------------------

func _texto(pos: Vector2, txt: String, cor: Color = TINTA, fonte: Font = null,
		alinhamento: int = HORIZONTAL_ALIGNMENT_LEFT, largura: float = -1.0) -> void:
	var f := fonte if fonte != null else _fonte
	if f != null:
		draw_string(f, pos, txt, alinhamento, largura, UiEstilo.RE7_SIZE_BODY, cor)


func _draw() -> void:
	# Cabine / interior atras da carteira. Preferencia: SubViewport 3D vivo
	# (sem HUD/LOCAL/HORA). Fallback: PNG estatico + mascara do canto.
	if _cabine_viewport != null:
		# Modulate NEUTRO, e essa e a terceira e ultima parada de um numero que ja
		# foi 1,35 e depois 1,10.
		#
		# Ele existia para compensar um fundo escuro demais, e cada vez que o
		# fundo era consertado o compensador sobrava. Agora o que chega aqui e a
		# Estrada Velha com a nevoa da propria estrada e a cabine acesa por uma
		# lampada de teto: ja esta exposta como a cena que vem no corte seguinte,
		# e qualquer ganho aqui e uma segunda exposicao por cima da primeira —
		# que aparece primeiro nos pretos, levantando-os, e e exatamente a
		# diferenca que separava esta tela do plano DENTRO da cena.
		draw_texture_rect(_cabine_viewport.get_texture(), Rect2(Vector2.ZERO, TELA),
			false, Color(1.0, 1.0, 1.0, 1.0))
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.01, 0.02, 0.03, 0.02))
		# Mesma vinheta da ficha, que e a tela imediatamente anterior. Duas telas
		# seguidas no mesmo carro nao podem ter cantos fotografados por regras
		# diferentes: a troca de painel passa a ler como troca de camera.
		if _vinheta != null:
			draw_texture_rect(_vinheta, Rect2(Vector2.ZERO, TELA), false,
				Color(1.0, 1.0, 1.0, 0.62))
	elif _cabine != null:
		draw_texture_rect(_cabine, Rect2(Vector2.ZERO, TELA), false)
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.02, 0.03, 0.02, 0.22))
		# Esconde LOCAL:/HORA: bakeados no PNG da cabine (canto inf-dir).
		draw_rect(Rect2(275.0, 205.0, 205.0, 55.0), Color(0.02, 0.03, 0.02, 0.98))
	else:
		draw_rect(Rect2(Vector2.ZERO, TELA), Color(0.03, 0.04, 0.03, 0.42))

	# `--so-fundo`: desenha a cabine e para.
	#
	# Bandeira de captura, e permanente por merecimento. Toda pergunta sobre a
	# CENA desta tela — o volante esta no lugar? a lampada acende o forro? o
	# carro andou? — precisa olhar o fundo sem o documento em cima, e ate agora
	# isso vinha sendo feito com remendo temporario que era esquecido no arquivo
	# na metade das vezes. Mesmo padrao de `--nome-teste=` e `--criacao-aba=`.
	if OS.get_cmdline_user_args().has("--so-fundo"):
		return

	# A ordem das camadas E o efeito de segurar. A mao inteira entra ANTES do
	# papel, e o papel come tudo o que passa por tras dele; depois das paginas
	# volta so o polegar, na margem lateral, que e a unica parte da mao que fica
	# na frente de um documento que alguem esta segurando. Ver `_desenhar_maos`.
	#
	# As abas fechadas vao ANTES do papel pelo mesmo motivo: sao folhas de
	# indice presas atras das paginas, e o papel come a base delas. A aba aberta
	# vem depois, por cima da borda, emendada na pagina que ela abriu.
	_xf = Transform2D(0.0, _desloc_doc())
	draw_set_transform_matrix(_xf)
	_desenhar_abas_indice(false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_desenhar_maos()
	_desenhar_papel()
	draw_set_transform_matrix(_xf)
	_desenhar_pagina_esquerda()
	_desenhar_pagina_direita()
	_desenhar_zona()
	_desenhar_virada()
	_desenhar_abas_indice(true)
	_desenhar_nome_da_aba()
	_desenhar_carimbo_de_emissao()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_desenhar_sombra_das_maos()
	_desenhar_polegares()
	_desenhar_barra()


## Onde a carteira esta em relacao ao lugar dela nas maos: subindo na abertura,
## descendo na saida e na emissao, tremendo no carimbo.
func _desloc_doc() -> Vector2:
	var y := (1.0 - _volta_suave(clampf(_abertura, 0.0, 1.0))) * 175.0
	if _saida >= 0.0:
		y += pow(clampf(_saida, 0.0, 1.0), 2.0) * 190.0
	if _emissao >= EMISSAO_DESCE:
		var t := clampf((_emissao - EMISSAO_DESCE) / (EMISSAO_FIM - EMISSAO_DESCE),
			0.0, 1.0)
		y += t * t * 190.0
	var tranco := Vector2.ZERO
	if _tremor > 0.0:
		tranco = Vector2(sin(_relogio * 83.0), cos(_relogio * 71.0)) * 2.2 * _tremor
	return Vector2(0.0, roundf(y)) + tranco


## Sobe passando um pouco do ponto e assenta: e o peso de uma coisa trazida
## pela mao, e nao de um painel deslizando num trilho.
static func _volta_suave(x: float) -> float:
	var c1 := 1.25
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


## O micro-balanco do documento, num lugar so.
##
## Papel, polegares e maos tem de andar JUNTOS. Se cada um recalcular o proprio
## seno, eles divergem no primeiro ajuste e o polegar descola da borda que esta
## segurando — defeito que nao aparece em captura parada e que ninguem deixa de
## ver em movimento.
##
## Amplitude de carro PARADO, e ja foi o triplo disso.
##
## O fundo desta tela e um carro encostado no acostamento, medido e conferido:
## a mata atras da janela nao anda um pixel. Mesmo assim a tela lia como carro
## em movimento, e a culpa era daqui — o documento ocupa tres quartos do quadro,
## e um documento gingando tres quartos de quadro E o balanco de quem esta
## andando. Mao parada tambem treme, so que em fracao de pixel e devagar.
func _balanco_doc() -> Vector2:
	return Vector2(sin(_relogio * 0.66) * 0.40, cos(_relogio * 0.54) * 0.32) \
		+ _desloc_doc()


func _angulo_doc() -> float:
	return INCLINACAO + sin(_relogio * 0.60) * 0.16


## O papel entra torto. Coisa segurada na mao nao fica reta, e o jogo inteiro
## segue essa regra desde a prancha de inventario.
func _desenhar_papel() -> void:
	draw_set_transform(DOC.position + _balanco_doc() + DOC.size * 0.5,
		deg_to_rad(_angulo_doc()), Vector2.ONE)
	var local := Rect2(-DOC.size * 0.5, DOC.size)
	# Capa azul do passaporte (print02): filete mais largo, como capa dura.
	draw_rect(Rect2(local.position + Vector2(-5.0, 3.0),
		Vector2(local.size.x + 10.0, local.size.y + 9.0)), CAPA)
	draw_rect(Rect2(local.position + Vector2(-4.0, 4.0),
		Vector2(local.size.x + 8.0, local.size.y + 7.0)), CAPA.lightened(0.08))
	# Sombra so na borda: com o papel translucido, uma mancha do tamanho da folha
	# apareceria atraves dela.
	draw_rect(Rect2(local.position.x + 3.0, local.end.y, local.size.x, 5.0),
		Color(0.02, 0.03, 0.02, 0.45))
	draw_rect(Rect2(local.end.x, local.position.y + 5.0, 3.0, local.size.y),
		Color(0.02, 0.03, 0.02, 0.45))
	# A espessura: as folhas de baixo aparecendo na borda, em tres degraus.
	# E o que faz a carteira ser um caderno e nao um cartao.
	for k in 3:
		var d := 3.0 - float(k)
		draw_rect(Rect2(local.position + Vector2(d * 0.6, d), local.size),
			PAPEL.darkened(0.12 + 0.06 * d))
	# O papel 2D entra TRANSLUCIDO, por cima da folha 3D.
	#
	# A folha e um quad de verdade dentro da cabine, acesa pela luz de teto (ver
	# `CabineFundoCriacao.pedir_folha`). Opaca por cima dela, a camada 2D
	# apagava a iluminacao inteira; ausente, a tinta escura ficava sobre papel de
	# quarenta e nove de 255 e a carteira parava de ser legivel — que e a queixa
	# que abriu esta tela.
	#
	# Meio a meio: a leitura fica garantida pela camada pintada e o que a lampada
	# faz no papel atravessa. Acender e apagar a luz do teto muda a carteira.
	if _guilhoche != null:
		draw_texture_rect(_guilhoche, local, true, PAPEL)
	else:
		draw_rect(local, PAPEL)
	_desenhar_seguranca(local)
	draw_rect(local.grow(-3.0), Color(0.92, 0.89, 0.80, 0.28), false, 1.0)
	draw_rect(local.grow(-6.0), Color(CAPA.r, CAPA.g, CAPA.b, 0.22), false, 1.0)
	draw_rect(local, TINTA_FRACA, false, 1.0)
	# Vinco do meio: e o que faz duas paginas em vez de um cartaz.
	draw_rect(Rect2(-1.0, local.position.y + 6.0, 2.0, local.size.y - 12.0), VINCO)
	# A curva da folha entrando na dobra: sombra que some em dezesseis pixels
	# de cada lado. Sem ela as duas paginas sao um plano so.
	var sombra := Color(0.22, 0.19, 0.12, 0.16)
	var nada := Color(sombra.r, sombra.g, sombra.b, 0.0)
	for lado: float in [-1.0, 1.0]:
		draw_polygon(PackedVector2Array([
			Vector2(0.0, local.position.y + 1.0), Vector2(lado * 16.0, local.position.y + 1.0),
			Vector2(lado * 16.0, local.end.y - 1.0), Vector2(0.0, local.end.y - 1.0)]),
			PackedColorArray([sombra, nada, nada, sombra]))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Os elementos de seguranca do documento: guilhoche em onda e a faixa do
## holograma.
##
## O que havia aqui era uma grade de oito por cinco atravessando a carteira
## inteira. Grade grossa e regular nao le como papel-moeda nem como documento:
## le como PLANILHA, e era ela que fazia o cartao parecer um painel de menu com
## texto em cima.
##
## O que um documento tem no lugar disso e guilhoche — a onda fina e continua
## que a impressora de seguranca desenha e que ninguem consegue reproduzir numa
## copiadora. Aqui sao senos de periodos incomensuraveis, num alfa tao baixo que
## de longe le como textura de papel e de perto le como impressao.
##
## E a FAIXA: a banda diagonal translucida do holograma. E o unico elemento que
## diz "documento oficial" sozinho, sem texto nenhum, e e o que amarra as duas
## paginas numa peca so em vez de duas colunas lado a lado.
func _desenhar_seguranca(local: Rect2) -> void:
	var linha := Color(CAPA.r, CAPA.g, CAPA.b, 0.10)
	var passo := 7.0
	var y := local.position.y + 10.0
	while y < local.end.y - 8.0:
		var pontos := PackedVector2Array()
		var x := local.position.x + 6.0
		while x < local.end.x - 6.0:
			# Dois senos em razao irracional: um so repete o desenho a cada
			# volta e a onda vira listra.
			var ondulado := sin(x * 0.11 + y * 0.05) * 1.7 + sin(x * 0.043) * 1.1
			pontos.append(Vector2(x, y + ondulado))
			x += 6.0
		if pontos.size() > 1:
			draw_polyline(pontos, linha, 1.0)
		y += passo

	# A faixa do holograma, atravessando de baixo a esquerda para cima a
	# direita. Duas bandas paralelas com uma aresta clara entre elas: e o que da
	# a impressao de pelicula, e nao de mancha.
	var largura := local.size.x
	var altura := local.size.y
	for k in 2:
		var desloc := -largura * 0.10 + float(k) * largura * 0.16
		var esp := 34.0 - float(k) * 12.0
		var faixa := PackedVector2Array([
			Vector2(local.position.x + desloc, local.end.y),
			Vector2(local.position.x + desloc + esp, local.end.y),
			Vector2(local.position.x + desloc + esp + altura * 0.55,
				local.position.y),
			Vector2(local.position.x + desloc + altura * 0.55, local.position.y),
		])
		# So o preenchimento, sem aresta desenhada. Uma linha clara na beirada
		# da faixa nao le como pelicula: le como RISCO no papel, e a carteira
		# passa a parecer arranhada em vez de holografada.
		draw_colored_polygon(faixa, Color(0.72, 0.86, 0.80, 0.06))


## Onde a mao encosta na carteira, em altura de tela.
##
## Perto do canto de baixo. Com o olho virado para o colo, o documento e o que
## esta em cima e as maos vem de BAIXO — que e a unica coisa que a versao
## anterior nao tinha: ela punha as maos nas laterais, na altura do meio da
## folha, que e onde a mao fica quando alguem segura um papel na frente do
## rosto. Nao e essa a pose.
const PEGA_Y := DOC_Y + 146.0

## Meio caminho entre a borda do papel e a beirada da tela, para cada lado.
const MAO_LARGURA := 46.0


## As maos que seguram a carteira, em quatro formas por mao.
##
## Solucao simples, e a simplicidade e a decisao
## ----------------------------------------------
## As versoes anteriores tinham antebraco, punho, dorso, monte do polegar, quatro
## dedos com contorno individual, vinco entre eles e unha: doze formas por mao,
## dentro de uma faixa de quarenta e seis pixels. Nesse tamanho, doze formas nao
## somam uma mao — elas viram uma mancha com riscos dentro, e cada rodada de
## detalhe piorava, porque o problema nunca foi falta de detalhe.
##
## O que le a esta distancia e SILHUETA e VALOR. Entao sao quatro formas: a
## manga, o dorso arredondado com tres reentrancias que sugerem os nos, o
## polegar por cima do papel e a sombra que a mao joga nele. Nada de dedo
## individual, nada de unha, nada de vinco.
##
## A ordem continua sendo o truque: manga e dorso ANTES do papel — o papel come
## o que passa por tras — e so o polegar depois, porque polegar e a unica parte
## da mao que fica na frente de um documento que alguem segura.
func _desenhar_maos() -> void:
	var a := aparencia_atual()
	var pele := Aparencia.pele_na_tela(a)
	var manga: Color = (a["casaco_cor"] if bool(a.get("casaco", false))
		else a["camisa_cor"])
	# Exposicao de cabine noturna: a carne base sai escurecida e quem devolve a
	# forma e a aresta virada para o papel, que e o refletor do quadro.
	var carne := pele.darkened(0.40)
	var funda := pele.darkened(0.70)
	var aresta := pele.lightened(0.08)
	var tecido := manga.darkened(0.58)
	var osc := _balanco_doc()

	for lado: float in [-1.0, 1.0]:
		var bx := (DOC.position.x if lado < 0.0 else DOC.end.x) + osc.x
		# A direita pega um pouco mais embaixo: duas maos na mesma altura leem
		# como decalque espelhado.
		var py := PEGA_Y + osc.y + (0.0 if lado < 0.0 else 5.0)
		var cx := bx + lado * 6.0

		# 1. Manga, subindo do rodape da tela.
		_poly4(
			Vector2(cx - lado * MAO_LARGURA * 0.34, py + 26.0),
			Vector2(cx + lado * MAO_LARGURA * 0.46, py + 30.0),
			Vector2(cx + lado * MAO_LARGURA * 0.66, TELA.y + 12.0),
			Vector2(cx - lado * MAO_LARGURA * 0.44, TELA.y + 12.0),
			tecido)
		draw_line(Vector2(cx - lado * MAO_LARGURA * 0.34, py + 26.0),
			Vector2(cx - lado * MAO_LARGURA * 0.44, TELA.y + 12.0),
			manga.darkened(0.30), 1.5)

		# 2. Dorso: uma forma so, com o alto arredondado.
		var dorso := PackedVector2Array([
			Vector2(cx - lado * MAO_LARGURA * 0.40, py - 6.0),
			Vector2(cx - lado * MAO_LARGURA * 0.24, py - 14.0),
			Vector2(cx + lado * MAO_LARGURA * 0.22, py - 15.0),
			Vector2(cx + lado * MAO_LARGURA * 0.44, py - 7.0),
			Vector2(cx + lado * MAO_LARGURA * 0.50, py + 18.0),
			Vector2(cx + lado * MAO_LARGURA * 0.40, py + 29.0),
			Vector2(cx - lado * MAO_LARGURA * 0.34, py + 27.0),
		])
		draw_colored_polygon(dorso, carne)
		draw_polyline(dorso, funda, 1.0)
		draw_line(dorso[6], dorso[0], funda, 1.0)

		# 3. Tres reentrancias no alto: os nos dos dedos que entram atras do
		#    papel. Tres riscos curtos fazem o que quatro dedos desenhados nao
		#    faziam, porque aqui o que falta e separacao, nao anatomia.
		for k in 3:
			var t := 0.26 + float(k) * 0.24
			var nx := cx + lado * MAO_LARGURA * (t - 0.36)
			draw_line(Vector2(nx, py - 13.0), Vector2(nx, py - 3.0), funda, 1.4)
		# Aresta acesa na beirada virada para o documento.
		draw_line(dorso[3], dorso[4], aresta, 1.5)


## Os polegares, por cima do papel. Um por mao, dois segmentos, sem unha.
##
## Chamado por `_draw` DEPOIS das paginas, e nao de dentro de `_desenhar_maos`:
## sendo desenhado junto com o resto da mao ele saia antes do papel e sumia
## atras dele, e a mao voltava a ler como mao ATRAS da carteira.
func _desenhar_polegares() -> void:
	var a := aparencia_atual()
	var pele := Aparencia.pele_na_tela(a)
	var funda := pele.darkened(0.70)
	var osc := _balanco_doc()
	var meia := pele.darkened(0.16)
	for lado: float in [-1.0, 1.0]:
		var bx := (DOC.position.x if lado < 0.0 else DOC.end.x) + osc.x
		var py := PEGA_Y + osc.y + (0.0 if lado < 0.0 else 5.0)
		var cx := bx + lado * 6.0
		# Nasce no dorso, atravessa a borda e sobe pela margem do papel.
		var base := Vector2(cx + lado * 4.0, py - 6.0)
		var ponta := Vector2(bx - lado * 20.0, py - 30.0)
		var meio := base.lerp(ponta, 0.5) + Vector2(-lado * 3.0, 0.0)
		var perp := (ponta - base).normalized()
		perp = Vector2(-perp.y, perp.x)
		# Sombra do polegar no papel, dois pixels para dentro.
		_poly4(base + perp * 7.0 + Vector2(2.0, 2.0),
			base - perp * 7.0 + Vector2(2.0, 2.0),
			ponta - perp * 4.0 + Vector2(2.0, 2.0),
			ponta + perp * 4.0 + Vector2(2.0, 2.0),
			Color(0.08, 0.09, 0.07, 0.24))
		_poly4(base + perp * 7.0, base - perp * 7.0,
			meio - perp * 6.0, meio + perp * 6.0, meia)
		_poly4(meio + perp * 6.0, meio - perp * 6.0,
			ponta - perp * 4.0, ponta + perp * 4.0, pele)
		draw_line(base + perp * 7.0, ponta + perp * 4.0, funda, 1.0)
		draw_line(base - perp * 7.0, ponta - perp * 4.0, funda, 1.0)


## A sombra que as maos jogam NO papel, desenhada depois dele.
##
## Sem ela o papel fica flutuando na frente das maos em vez de estar apoiado
## nelas. Duas faixas encostadas no canto de baixo custam quase nada.
func _desenhar_sombra_das_maos() -> void:
	var osc := _balanco_doc()
	for lado: float in [-1.0, 1.0]:
		var bx := (DOC.position.x if lado < 0.0 else DOC.end.x) + osc.x
		var py := PEGA_Y + osc.y + (0.0 if lado < 0.0 else 5.0)
		for k in 3:
			var larg := 16.0 - float(k) * 5.0
			var x := bx if lado < 0.0 else bx - larg
			draw_rect(Rect2(x, py - 30.0, larg, DOC.end.y - py + 34.0),
				Color(0.06, 0.05, 0.04, 0.09))


## Quad convexo como dois triangulos. Evita "Invalid polygon data, triangulation
## failed" do draw_colored_polygon em quads com winding/ordem ambigua.
func _poly4(a: Vector2, b: Vector2, c: Vector2, d: Vector2, cor: Color) -> void:
	# Descarta degenerados (area ~0) antes de pedir triangulacao ao motor.
	if absf((b - a).cross(c - a)) < 0.35 and absf((c - a).cross(d - a)) < 0.35:
		return
	draw_colored_polygon(PackedVector2Array([a, b, c]), cor)
	draw_colored_polygon(PackedVector2Array([a, c, d]), cor)


func _desenhar_pagina_esquerda() -> void:
	# Cabecalho na cor da capa, com o texto em papel. E o primeiro sinal de
	# documento oficial que o olho pega, antes de ler qualquer palavra: a faixa
	# colorida de cima de toda carteira e todo passaporte.
	# Vai ate perto da dobra: com a largura da pagina, "REP. FED. DO BRASIL"
	# passava da faixa.
	var cab := Rect2(PAGINA_ESQ.position.x - 4.0, DOC_Y + 5.0,
		DOC.position.x + DOC.size.x * 0.5 - 5.0 - (PAGINA_ESQ.position.x - 4.0), 35.0)
	draw_rect(cab, CAPA)
	for k in 3:
		var pts := PackedVector2Array()
		var y0 := cab.position.y + 8.0 + float(k) * 9.0
		var x := cab.position.x
		while x <= cab.end.x:
			pts.append(Vector2(x, y0 + sin(x * 0.21 + float(k)) * 2.0))
			x += 4.0
		draw_polyline(pts, Color(0.85, 0.90, 0.95, 0.10), 1.0)
	draw_rect(Rect2(cab.position.x, cab.end.y - 1.0, cab.size.x, 1.0),
		Color(0.93, 0.86, 0.62, 0.55))
	if _brasao != null:
		draw_texture_rect(_brasao, Rect2(cab.position.x + 4.0, DOC_Y + 9.0, 15.0, 15.0),
			false)
	var claro := Color(0.95, 0.93, 0.86)
	_texto(Vector2(cab.position.x + 22.0, DOC_Y + 16.0), "REP. FED. DO BRASIL",
		Color(claro.r, claro.g, claro.b, 0.80), _fonte)
	_texto(Vector2(cab.position.x + 22.0, DOC_Y + 26.0), "CARTEIRA DE",
		Color(claro.r, claro.g, claro.b, 0.70))
	_texto(Vector2(cab.position.x + 22.0, DOC_Y + 37.0), "IDENTIDADE", claro, _fonte_media)

	draw_rect(RETRATO.grow(2.0), TINTA)
	_desenhar_fundo_de_estudio()
	if _estudio != null:
		draw_texture_rect(_estudio.textura(), RETRATO, false)
	# O holograma passa por cima da foto de tempos em tempos.
	CarteiraArte.brilho(self, RETRATO, fmod(_relogio + 1.5, 5.5) / 1.4)
	# O obturador: meio clarao que some em dois decimos de segundo.
	if _clarao > 0.0:
		draw_rect(RETRATO, Color(1.0, 0.98, 0.92, 0.35 * _clarao * _clarao))
	_desenhar_controles_do_retrato()
	# Cantoneiras do retrato 3x4 (passaporte).
	var c := RETRATO
	var k2 := 7.0
	var ck := Color(CAPA.r, CAPA.g, CAPA.b, 0.75)
	draw_line(c.position, c.position + Vector2(k2, 0.0), ck, 1.5)
	draw_line(c.position, c.position + Vector2(0.0, k2), ck, 1.5)
	draw_line(Vector2(c.end.x, c.position.y), Vector2(c.end.x - k2, c.position.y), ck, 1.5)
	draw_line(Vector2(c.end.x, c.position.y), Vector2(c.end.x, c.position.y + k2), ck, 1.5)
	draw_line(Vector2(c.position.x, c.end.y), Vector2(c.position.x + k2, c.end.y), ck, 1.5)
	draw_line(Vector2(c.position.x, c.end.y), Vector2(c.position.x, c.end.y - k2), ck, 1.5)
	draw_line(c.end, c.end - Vector2(k2, 0.0), ck, 1.5)
	draw_line(c.end, c.end - Vector2(0.0, k2), ck, 1.5)
	# O selo em tinta mordendo o canto da foto: carimbo de orgao emissor, que e
	# o que impede de trocar a foto de uma carteira sem deixar rastro.
	CarteiraArte.selo(self, RETRATO.position + Vector2(3.0, 4.0), 11.0,
		Color(CAPA.r, CAPA.g, CAPA.b, 0.50))

	var ficha := RegistroCivil.jogador
	if ficha.is_empty():
		return
	# Assinatura do titular, em caneta azul, e a digital ao lado.
	var y_ass := RETRATO.end.y + 9.0
	CarteiraArte.assinatura(self, Vector2(RETRATO.position.x + 4.0, y_ass), 66.0,
		String(ficha["nome"]), Color(0.14, 0.25, 0.55, 0.85))
	draw_rect(Rect2(RETRATO.position.x, y_ass + 2.0, 78.0, 1.0),
		Color(TINTA_FRACA.r, TINTA_FRACA.g, TINTA_FRACA.b, 0.45))
	if _digital != null:
		draw_texture_rect(_digital, Rect2(RETRATO.end.x - 13.0, RETRATO.end.y + 2.0,
			12.0, 12.0), false, Color(1.0, 1.0, 1.0, 0.55))
	# Numero do registro em microtexto vertical, na margem: documento tem
	# numero escrito onde nao se procura.
	draw_set_transform_matrix(_xf * Transform2D(-PI * 0.5,
		Vector2(DOC.position.x + 14.0, DOC_Y + 112.0)))
	_texto(Vector2.ZERO, "RG %s" % String(ficha.get("rg", "")),
		Color(TINTA_FRACA.r, TINTA_FRACA.g, TINTA_FRACA.b, 0.75), _fonte)
	draw_set_transform_matrix(_xf)


## O fundo da foto, pintado em 2D atras do 3D transparente.
##
## Era uma cor chapada, e a 104 px chapado le como caixa de cor e nao como
## parede de estudio. O que faz um fundo de retrato ler como estudio e o
## degrade de cima para baixo e o halo claro atras da cabeca — os dois, e so os
## dois, porque o resto e ruido numa janela deste tamanho.
const FUNDO_ALTO := Color("5b6671")
const FUNDO_BAIXO := Color("363d45")
const FUNDO_HALO := Color(0.80, 0.84, 0.86, 0.045)


func _desenhar_fundo_de_estudio() -> void:
	var r := RETRATO
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y),
		r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([FUNDO_ALTO, FUNDO_ALTO, FUNDO_BAIXO, FUNDO_BAIXO]))
	# O halo acompanha a cabeca: alto no rosto, e desce um pouco quando a camera
	# abre para o corpo inteiro e a cabeca sobe no quadro.
	var z := _estudio.zoom() if _estudio != null else 0.4
	var centro := r.position + Vector2(r.size.x * 0.5, r.size.y * lerpf(0.42, 0.30, z))
	# Oito aneis finos, e nao quatro grossos: com quatro, os degraus liam como
	# alvo de tiro.
	for k in 8:
		var raio := r.size.x * (0.16 + float(k) * 0.05)
		draw_circle(centro, raio, FUNDO_HALO)


## O trilho de zoom e as setas de giro, por cima da foto.
##
## Discretos de proposito: meio transparentes enquanto o mouse nao esta na foto,
## inteiros quando esta. Controle que fica gritando por cima do retrato vira
## parte do retrato.
func _desenhar_controles_do_retrato() -> void:
	if _estudio == null:
		return
	var alfa := 0.95 if _hover_retrato or _girando else 0.42
	var tinta := Color(0.94, 0.92, 0.84, alfa)
	var sombra := Color(0.05, 0.06, 0.07, alfa * 0.55)

	# Trilho vertical: em cima e o rosto, embaixo o corpo inteiro.
	var trilho := _rect_trilho()
	var x := trilho.get_center().x
	draw_line(Vector2(x + 1.0, trilho.position.y + 1.0),
		Vector2(x + 1.0, trilho.end.y + 1.0), sombra, 1.0)
	draw_line(Vector2(x, trilho.position.y), Vector2(x, trilho.end.y), tinta, 1.0)
	for marca: float in [0.0, 0.5, 1.0]:
		var y := trilho.position.y + trilho.size.y * marca
		draw_line(Vector2(x - 2.0, y), Vector2(x + 2.0, y), tinta, 1.0)
	var yz := trilho.position.y + trilho.size.y * _estudio.zoom()
	draw_rect(Rect2(x - 3.0, yz - 2.0, 7.0, 5.0), sombra)
	draw_rect(Rect2(x - 3.0, yz - 3.0, 6.0, 5.0), DESTAQUE.lightened(0.25) if
		_hover_retrato else tinta)

	# Mais e menos nas pontas do trilho.
	var mais := _rect_zoom(-1)
	var menos := _rect_zoom(1)
	for r: Rect2 in [mais, menos]:
		draw_rect(r, Color(0.08, 0.09, 0.10, alfa * 0.55))
	var cm := mais.get_center()
	draw_line(cm + Vector2(-2.0, 0.0), cm + Vector2(2.0, 0.0), tinta, 1.0)
	draw_line(cm + Vector2(0.0, -2.0), cm + Vector2(0.0, 2.0), tinta, 1.0)
	var cn := menos.get_center()
	draw_line(cn + Vector2(-2.0, 0.0), cn + Vector2(2.0, 0.0), tinta, 1.0)

	# Setas de giro no canto de baixo, a esquerda.
	for lado: int in [-1, 1]:
		var b := _rect_girar(lado)
		draw_rect(b, Color(0.08, 0.09, 0.10, alfa * 0.55))
		var cb := b.get_center()
		var s := float(lado)
		draw_colored_polygon(PackedVector2Array([
			cb + Vector2(2.0 * s, 0.0), cb + Vector2(-1.5 * s, -2.5),
			cb + Vector2(-1.5 * s, 2.5)]), tinta)


func _rect_trilho() -> Rect2:
	return Rect2(RETRATO.end.x - 9.0, RETRATO.position.y + 16.0, 6.0,
		RETRATO.size.y - 32.0)


## -1 e o botao de aproximar (em cima), 1 o de afastar (embaixo).
func _rect_zoom(qual: int) -> Rect2:
	var t := _rect_trilho()
	var y := t.position.y - 12.0 if qual < 0 else t.end.y + 3.0
	return Rect2(t.position.x - 2.0, y, 9.0, 9.0)


func _rect_girar(lado: int) -> Rect2:
	var x := RETRATO.position.x + 4.0 + (0.0 if lado < 0 else 12.0)
	return Rect2(x, RETRATO.end.y - 13.0, 10.0, 9.0)


func _desenhar_pagina_direita() -> void:
	var x := PAGINA_DIR.position.x
	var ficha := RegistroCivil.jogador

	# Os campos impressos. Sao justamente os que NAO se escolhem.
	if not ficha.is_empty():
		# A etiqueta miuda em cima e o valor embaixo, como no RG do inventario.
		# Lado a lado, "NOME" e o nome se encostavam: a fonte pequena rende nove
		# pixels por caractere e quatro letras ja tomam trinta e seis.
		var larg_nome := _rect_visto().position.x - 6.0 - x
		_texto(Vector2(x, DOC_Y + 12.0), "NOME", TINTA_FRACA)
		# A UF subiu para a linha do rotulo, alinhada a direita. Na pagina larga
		# ela cabia depois do CPF; com cento e trinta e seis pixels de coluna o
		# numero sozinho ja come tudo, e os dois se encostavam.
		_texto(Vector2(x, DOC_Y + 12.0), String(ficha["uf"]), TINTA_FRACA, _fonte,
			HORIZONTAL_ALIGNMENT_RIGHT, larg_nome)
		_texto(Vector2(x, DOC_Y + 24.0),
			_nome_na_pagina(String(ficha["nome"]), larg_nome), TINTA)
		_texto(Vector2(x, DOC_Y + 35.0), "CPF", TINTA_FRACA)
		_texto(Vector2(x + 26.0, DOC_Y + 35.0), String(ficha["cpf"]), TINTA, _mono)

	draw_rect(Rect2(x, DOC_Y + 40.0, PAGINA_DIR.size.x - 6.0, 1.0), VINCO)
	# Nascimento e naturalidade: a linha que as abas liberaram. Estao impressas
	# e nao se mexem, e e ver as duas ao lado dos campos que se mexem que diz,
	# sem texto nenhum, o que e escolha e o que e registro.
	if not ficha.is_empty():
		var nasc := String(ficha.get("nascimento", ""))
		var rotulo := _largura_do_texto("NASC") + 3.0
		_texto(Vector2(x, DOC_Y + 49.0), "NASC", TINTA_FRACA)
		_texto(Vector2(x + rotulo, DOC_Y + 49.0), nasc, TINTA)
		var inicio := x + rotulo + _largura_do_texto(nasc) + 6.0
		var largura := PAGINA_DIR.end.x - 6.0 - inicio
		# So a cidade: a UF ja esta impressa na linha do nome. Cidade comprida
		# abrevia com ponto, como na via impressa.
		var cidade := String(ficha.get("naturalidade", "")).split(" - ")[0]
		var nat := cidade
		while cidade.length() > 3 and _largura_do_texto(nat) > largura:
			cidade = cidade.substr(0, cidade.length() - 1).strip_edges()
			nat = cidade + "."

		_texto(Vector2(inicio, DOC_Y + 49.0), nat, TINTA, _fonte,
			HORIZONTAL_ALIGNMENT_RIGHT, largura)
	draw_rect(Rect2(x, DOC_Y + 52.0, PAGINA_DIR.size.x - 6.0, 1.0),
		Color(VINCO.r, VINCO.g, VINCO.b, 0.7))
	_desenhar_campos()
	_desenhar_visto()


## As abas de indice presas no alto da carteira.
##
## `na_frente` escolhe a passada: as fechadas sao desenhadas ANTES do papel, que
## come a base delas; a aberta DEPOIS, emendada na pagina por uma faixa da mesma
## cor. Cada categoria tem a sua cor, apagada de documento: e pela cor, antes do
## icone, que o olho acha a aba certa na segunda vez.
const COR_ABA: Array[Color] = [
	Color("9a5a4a"), Color("6e5438"), Color("3f6b66"), Color("5d6a3c"),
	Color("3d4f73"), Color("8a4e2c"), Color("8c7a3a"), Color("4f6358"),
]


func _desenhar_abas_indice(na_frente: bool) -> void:
	for i in ABAS.size():
		var ativa := i == _aba
		if ativa != na_frente:
			continue
		var r := _rect_aba(i)
		var cor: Color = COR_ABA[i % COR_ABA.size()]
		var hover := i == _hover_aba
		var fundo := cor if ativa else (cor.darkened(0.08) if hover else cor.darkened(0.30))
		var forma := PackedVector2Array([
			Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.position.y + 3.0),
			Vector2(r.position.x + 3.0, r.position.y), Vector2(r.end.x - 3.0, r.position.y),
			Vector2(r.end.x, r.position.y + 3.0), Vector2(r.end.x, r.end.y)])
		if ativa or hover:
			var sombra := PackedVector2Array()
			for p: Vector2 in forma:
				sombra.append(p + Vector2(1.0, 1.0))
			draw_colored_polygon(sombra, Color(0.03, 0.03, 0.02, 0.40))
		draw_colored_polygon(forma, fundo)
		draw_line(Vector2(r.position.x + 3.0, r.position.y + 1.0),
			Vector2(r.end.x - 3.0, r.position.y + 1.0), fundo.lightened(0.35), 1.0)
		var contorno := forma.duplicate()
		draw_polyline(contorno, fundo.darkened(0.45), 1.0)
		var tinta := Color(0.96, 0.93, 0.85) if ativa or hover else Color(0.86, 0.83, 0.75,
			0.80)
		if ativa:
			# A aba aberta mostra o nome. E ela que diz em que folha se esta.
			_icone_da_aba(String(ABAS[i]["icone"]),
				Vector2(r.position.x + 10.0, r.position.y + 9.0), tinta)
			_texto(Vector2(r.position.x + 18.0, r.position.y + 13.0),
				String(ABAS[i]["nome"]), tinta, _fonte)
			# A faixa da cor da aba correndo no alto da pagina que ela abriu.
			draw_rect(Rect2(PAGINA_DIR.position.x - 6.0, DOC_Y + 1.0,
				PAGINA_DIR.size.x + 10.0, 2.0), cor)
			draw_rect(Rect2(r.position.x + 1.0, r.end.y - 2.0, r.size.x - 2.0, 4.0), fundo)
			if _linha == LINHA_ABAS:
				var foco := CarteiraArte.chanfro(r.grow(1.0), 2.0)
				foco.append(foco[0])
				draw_polyline(foco, Color(0.98, 0.88, 0.55, 0.6 + 0.4 * sin(_relogio * 5.0)),
					1.0)
		else:
			_icone_da_aba(String(ABAS[i]["icone"]),
				Vector2(r.get_center().x, r.position.y + 8.0), tinta)


## A folha virando na troca de aba.
##
## Uma folha em branco gira em torno da dobra: a sombra dela cresce enquanto
## ela fica de pe e a ponta sobe um pouco na direcao de quem segura. A folha
## nova esta por baixo, e os campos dela entram um a um quando a folha passa.
## Para tras, a folha vem da esquerda e some ao pousar.
func _desenhar_virada() -> void:
	if _virada >= 1.0:
		return
	var p := _virada * _virada * (3.0 - 2.0 * _virada)
	var th := p * PI if _virada_dir > 0 else (1.0 - p) * PI
	var dobra := DOC.position.x + DOC.size.x * 0.5
	var largura := DOC.size.x * 0.5 - 3.0
	var topo := DOC.position.y + 3.0
	var base := DOC.end.y - 3.0
	var ponta := dobra + largura * cos(th)
	var ergue := sin(th) * 8.0
	var alfa := 1.0
	if _virada_dir < 0 and p > 0.75:
		alfa = 1.0 - (p - 0.75) / 0.25
	# A sombra que a folha em pe joga na pagina de baixo.
	var lado := signf(ponta - dobra)
	var sombra_x := dobra + lado * minf(absf(ponta - dobra) + 10.0 * sin(th), largura)
	draw_colored_polygon(PackedVector2Array([Vector2(dobra, topo), Vector2(sombra_x, topo),
		Vector2(sombra_x, base), Vector2(dobra, base)]),
		Color(0.08, 0.07, 0.05, 0.18 * sin(th) * alfa))
	var costas := cos(th) < 0.0
	# O verso so um pouco mais escuro que a frente: cinza, a folha lia como
	# painel de plastico passando por cima da foto.
	var cor := PAPEL.darkened(0.03 + 0.11 * sin(th) + (0.04 if costas else 0.0))
	cor.a = alfa
	var folha := PackedVector2Array([Vector2(dobra, topo), Vector2(ponta, topo - ergue),
		Vector2(ponta, base + ergue), Vector2(dobra, base)])
	if absf(ponta - dobra) < 1.0:
		return
	draw_colored_polygon(folha, cor)
	# Linhas de texto fingidas na folha: em branco ela le como papel qualquer.
	# No verso elas aparecem mais fracas, como impressao vista contra a luz.
	var forca_linhas := 0.12 if costas else 0.22
	if true:
		for k in 7:
			var t := float(k) / 6.0
			var y := lerpf(topo + 14.0, base - 18.0, t)
			var sob := ergue * (y - (topo + base) * 0.5) / ((base - topo) * 0.5)
			draw_line(Vector2(dobra + (ponta - dobra) * 0.12, y),
				Vector2(dobra + (ponta - dobra) * (0.55 + 0.3 * fmod(t * 7.3, 1.0)), y + sob),
				Color(TINTA_FRACA.r, TINTA_FRACA.g, TINTA_FRACA.b, forca_linhas * alfa), 1.0)
	draw_line(Vector2(ponta, topo - ergue), Vector2(ponta, base + ergue),
		Color(1.0, 1.0, 0.96, 0.6 * alfa), 1.0)


## O carimbo de EMITIDA, caindo sobre a foto no fim da criacao.
func _desenhar_carimbo_de_emissao() -> void:
	if _emissao < EMISSAO_CARIMBO:
		return
	var t := clampf((_emissao - EMISSAO_CARIMBO) / (EMISSAO_POUSO - EMISSAO_CARIMBO),
		0.0, 1.0)
	var escala := lerpf(2.6, 1.0, t * t)
	var forca := clampf(t * 1.6, 0.0, 1.0)
	CarteiraArte.carimbo(self, _xf, Vector2(RETRATO.end.x + 2.0, RETRATO.end.y - 16.0),
		Vector2(90.0, 30.0), -12.0, "EMITIDA", "REG. CIVIL", _fonte_media, _fonte,
		DESTAQUE, escala, forca)


## A barra de baixo: teclas desenhadas como teclas, e as duas acoes que se
## clicam — voltar e emitir — como botoes de verdade.
const BARRA_Y := 257.0
const BARRA_ITENS: Array = [
	[["ESC"], "VOLTAR", &"voltar"],
	[["W", "S"], "CAMPO", &""],
	[["A", "D"], "ESCOLHER", &""],
	[["Z", "X"], "GIRAR", &""],
	[["+", "-"], "ZOOM", &""],
	[["E"], "EMITIR", &"emitir"],
]


## A geometria da barra: onde cada item comeca e quanto ocupa. O desenho e o
## clique leem daqui.
func _itens_da_barra() -> Array:
	var saida: Array = []
	var total := 0.0
	for item: Array in BARRA_ITENS:
		var larg := 0.0
		for g: String in item[0]:
			larg += _largura_tecla(g) + 2.0
		larg += 3.0 + _largura_do_texto(String(item[1]))
		saida.append(larg)
		total += larg
	var vao := 10.0
	total += vao * float(BARRA_ITENS.size() - 1)
	var x := roundf((TELA.x - total) * 0.5)
	var rects: Array = []
	for i in BARRA_ITENS.size():
		rects.append(Rect2(x - 3.0, BARRA_Y - 1.0, float(saida[i]) + 6.0, 13.0))
		x += float(saida[i]) + vao
	return rects


func _largura_tecla(glifo: String) -> float:
	if _fonte == null:
		return 11.0
	return maxf(11.0, _fonte.get_string_size(glifo, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		UiEstilo.RE7_SIZE_BODY).x + 6.0)


func _desenhar_barra() -> void:
	draw_rect(Rect2(0.0, BARRA_Y - 3.0, TELA.x, TELA.y - BARRA_Y + 3.0),
		Color(0.03, 0.035, 0.04, 0.80))
	draw_rect(Rect2(0.0, BARRA_Y - 3.0, TELA.x, 1.0), Color(0.93, 0.86, 0.62, 0.18))
	var rects := _itens_da_barra()
	for i in BARRA_ITENS.size():
		var item: Array = BARRA_ITENS[i]
		var r: Rect2 = rects[i]
		var acao: StringName = item[2]
		var hover := i == _hover_barra and acao != &""
		var emitir := acao == &"emitir"
		if hover:
			CarteiraArte.botao(self, r, Color(0.22, 0.20, 0.16, 0.95),
				Color(0.93, 0.86, 0.62, 0.7), 1.0)
		var x := r.position.x + 3.0
		for g: String in item[0]:
			x += CarteiraArte.tecla(self, Vector2(x, BARRA_Y), g, _fonte,
				UiEstilo.RE7_SIZE_BODY, false, emitir) + 2.0
		var cor := Color(0.98, 0.90, 0.66) if emitir else (Color(0.97, 0.95, 0.88) if hover
			else Color(0.80, 0.77, 0.69))
		_texto(Vector2(x + 1.0, BARRA_Y + 9.0), String(item[1]), cor)


## O nome do titular na largura que a pagina realmente tem.
##
## O corte era `substr(0, 22)`, e vinte e dois caracteres desta fonte dao quase
## duzentos pixels — cinquenta a mais do que existe entre a margem e a caixa do
## visto. "JOTA FERNANDES RODRIGUES" entrava por baixo do tique de aceite.
## Contar caractere so funciona em fonte monoespacada, e esta nao e.
##
## E documento nao corta nome no meio: ABREVIA. Primeiro os nomes do meio viram
## inicial, depois some o meio inteiro, e so em ultimo caso, quando nem "NOME
## SOBRENOME" cabe, e que se trunca — que e a mesma ordem que um cartorio segue
## para caber uma linha numa via impressa.
func _nome_na_pagina(nome: String, largura: float) -> String:
	if _largura_do_texto(nome) <= largura:
		return nome
	var partes := nome.split(" ", false)
	if partes.size() > 2:
		var iniciais: PackedStringArray = []
		for i in range(1, partes.size() - 1):
			iniciais.append(partes[i].substr(0, 1) + ".")
		var abreviado := "%s %s %s" % [partes[0], " ".join(iniciais), partes[-1]]
		if _largura_do_texto(abreviado) <= largura:
			return abreviado
	if partes.size() > 1:
		var so_pontas := "%s %s" % [partes[0], partes[-1]]
		if _largura_do_texto(so_pontas) <= largura:
			return so_pontas
	var corte := nome
	while corte.length() > 1 and _largura_do_texto(corte) > largura:
		corte = corte.substr(0, corte.length() - 1)
	return corte


func _largura_do_texto(s: String) -> float:
	if _fonte == null:
		return 0.0
	return _fonte.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiEstilo.RE7_SIZE_BODY).x


## Os icones sao desenhados com primitivas, e nao lidos de arquivo. Sao seis
## silhuetas de doze pixels: um PNG para cada custaria seis arquivos e um passo
## de pipeline para o que cabe em quatro linhas.
func _icone_da_aba(qual: String, centro: Vector2, cor: Color) -> void:
	match qual:
		"rosto":
			draw_rect(Rect2(centro.x - 5.0, centro.y - 6.0, 10.0, 12.0), cor, false, 1.0)
			draw_rect(Rect2(centro.x - 3.0, centro.y - 2.0, 2.0, 2.0), cor)
			draw_rect(Rect2(centro.x + 1.0, centro.y - 2.0, 2.0, 2.0), cor)
			draw_rect(Rect2(centro.x - 2.0, centro.y + 3.0, 4.0, 1.0), cor)
		"cabelo":
			draw_rect(Rect2(centro.x - 5.0, centro.y - 1.0, 10.0, 7.0), cor, false, 1.0)
			draw_rect(Rect2(centro.x - 6.0, centro.y - 6.0, 12.0, 5.0), cor)
		"camisa":
			draw_colored_polygon(PackedVector2Array([
				centro + Vector2(-6.0, -5.0), centro + Vector2(-2.0, -5.0),
				centro + Vector2(0.0, -3.0), centro + Vector2(2.0, -5.0),
				centro + Vector2(6.0, -5.0), centro + Vector2(6.0, 0.0),
				centro + Vector2(4.0, 0.0), centro + Vector2(4.0, 6.0),
				centro + Vector2(-4.0, 6.0), centro + Vector2(-4.0, 0.0),
				centro + Vector2(-6.0, 0.0)]), cor)
		"casaco":
			# Casaco aberto: dois panos com lapela e a fresta no meio. Sem a
			# fresta o icone vira o mesmo bloco da camisa e as duas abas ficam
			# indistinguiveis em doze pixels.
			draw_colored_polygon(PackedVector2Array([
				centro + Vector2(-6.0, -5.0), centro + Vector2(-1.0, -5.0),
				centro + Vector2(-1.0, 6.0), centro + Vector2(-6.0, 6.0)]), cor)
			draw_colored_polygon(PackedVector2Array([
				centro + Vector2(6.0, -5.0), centro + Vector2(1.0, -5.0),
				centro + Vector2(1.0, 6.0), centro + Vector2(6.0, 6.0)]), cor)
			draw_line(centro + Vector2(-4.0, -5.0), centro + Vector2(-1.0, 0.0),
				CELULA_SEL, 1.0)
			draw_line(centro + Vector2(4.0, -5.0), centro + Vector2(1.0, 0.0),
				CELULA_SEL, 1.0)
		"calca":
			draw_rect(Rect2(centro.x - 5.0, centro.y - 6.0, 10.0, 4.0), cor)
			draw_rect(Rect2(centro.x - 5.0, centro.y - 2.0, 4.0, 8.0), cor)
			draw_rect(Rect2(centro.x + 1.0, centro.y - 2.0, 4.0, 8.0), cor)
		"sapato":
			# Bota de perfil: cano, peito do pe e o solado mais largo.
			draw_rect(Rect2(centro.x - 4.0, centro.y - 6.0, 4.0, 7.0), cor)
			draw_colored_polygon(PackedVector2Array([
				centro + Vector2(-4.0, 1.0), centro + Vector2(0.0, 1.0),
				centro + Vector2(5.0, 3.0), centro + Vector2(6.0, 5.0),
				centro + Vector2(-4.0, 5.0)]), cor)
			draw_rect(Rect2(centro.x - 5.0, centro.y + 5.0, 12.0, 2.0), cor)
		"chapeu":
			draw_rect(Rect2(centro.x - 7.0, centro.y + 1.0, 14.0, 2.0), cor)
			draw_colored_polygon(PackedVector2Array([
				centro + Vector2(-4.0, 1.0), centro + Vector2(-3.0, -5.0),
				centro + Vector2(3.0, -5.0), centro + Vector2(4.0, 1.0)]), cor)
		_:
			draw_rect(Rect2(centro.x - 2.0, centro.y - 6.0, 4.0, 4.0), cor)
			draw_rect(Rect2(centro.x - 4.0, centro.y - 1.0, 8.0, 4.0), cor)
			draw_rect(Rect2(centro.x - 3.0, centro.y + 3.0, 2.0, 4.0), cor)
			draw_rect(Rect2(centro.x + 1.0, centro.y + 3.0, 2.0, 4.0), cor)


## Publica: os campos da aba aberta. A navegacao e a verificacao leem daqui.
func campos_da_aba() -> Array:
	return ABAS[_aba]["campos"]


func _desenhar_campos() -> void:
	var x := PAGINA_DIR.position.x
	var y := LINHA_UM
	for i in campos_da_aba().size():
		var campo := _campo(campos_da_aba()[i])
		var ativo := _linha == i + 1
		var alto := _altura_do_campo(campo)
		# Os campos entram um a um, da direita, quando a folha abre ou vira.
		var entra := clampf((_revela - 0.06 * float(i)) / 0.20, 0.0, 1.0)
		if entra <= 0.0:
			y += alto
			continue
		var e := 1.0 - pow(1.0 - entra, 3.0)
		draw_set_transform_matrix(_xf * Transform2D(0.0, Vector2((1.0 - e) * 14.0, 0.0)))
		if ativo:
			draw_rect(Rect2(x - 3.0, y - 3.0, PAGINA_DIR.size.x - 2.0, alto - 2.0),
				Color(0.86, 0.84, 0.74, 0.72))
			# Filete na margem, na cor da aba: o campo ativo se le de longe.
			draw_rect(Rect2(x - 3.0, y - 3.0, 2.0, alto - 2.0),
				COR_ABA[_aba % COR_ABA.size()])
		_texto(Vector2(x, y + 8.0), String(campo["rotulo"]),
			DESTAQUE if ativo else TINTA_FRACA)
		var contagem := _contagem(campo)
		if contagem != "":
			_texto(Vector2(x, y + 8.0), contagem, TINTA_FRACA, _fonte,
				HORIZONTAL_ALIGNMENT_RIGHT, PAGINA_DIR.size.x - 8.0)
		_desenhar_escolha(campo, Vector2(x, y + CAMPO_ROTULO), ativo, i)
		if entra < 1.0:
			draw_rect(Rect2(x - 4.0, y - 3.0, PAGINA_DIR.size.x, alto),
				Color(PAPEL.r, PAPEL.g, PAPEL.b, (1.0 - e) * 0.9))
		draw_set_transform_matrix(_xf)
		y += alto

## "3/6" ao lado do rotulo: quantos modelos existem e em qual se esta. E o que
## diz que ha mais para ver do outro lado da seta.
func _contagem(campo: Dictionary) -> String:
	var chave: StringName = campo["chave"]
	match String(campo["tipo"]):
		"estilo":
			var itens: Array = campo["itens"]
			return "%d/%d" % [posmod(int(_ajustes.get(chave, 0)), itens.size()) + 1,
				itens.size()]
		"celula":
			var quantos := int(campo["quantos"])
			if quantos > POR_PAGINA:
				return "PAG %d/%d" % [_pagina_de(campo) + 1,
					ceili(float(quantos) / float(POR_PAGINA))]
	return ""


## Quanto a linha deste campo ocupa. A conta mora em `CarteiraLayout`.
func _altura_do_campo(campo: Dictionary) -> float:
	return CarteiraLayout.altura_da_linha(String(campo["tipo"]))


static func _campo(chave: StringName) -> Dictionary:
	for c: Dictionary in Aparencia.AJUSTES:
		if StringName(c["chave"]) == chave:
			return c
	return Aparencia.AJUSTES[0]


# --- geometria dos widgets --------------------------------------------------

## Codigos das partes clicaveis que nao sao um item: as setas e o miolo.
const SETA_ANTES := -1
const SETA_DEPOIS := -2
const MIOLO := -3
## Quantas celulas cabem numa pagina. Mais que isso e a celula fica menor que o
## desenho dentro dela.
const POR_PAGINA := 8
const LARGURA_SETA := 13.0


func _largura_widget() -> float:
	return PAGINA_DIR.size.x - 12.0


## As partes clicaveis de um campo, cada uma `[Rect2, codigo]`.
##
## Desenho e mouse leem DAQUI. Eram duas contas paralelas — o desenho num ramo
## do `match`, o clique noutro — e o comentario de `_origem_campo` ja dizia qual
## e o pior defeito de tela clicavel: desenhar num lugar e clicar noutro. Com
## setas, paginas e modelos entrando, sao quatro widgets com geometria propria;
## numa tabela so eles nao tem como discordar.
func _alvos(campo: Dictionary, em: Vector2) -> Array:
	var tipo := String(campo["tipo"])
	var largura := _largura_widget()
	var alto := float(CAMPO_WIDGET.get(tipo, 16.0))
	var saida: Array = []
	match tipo:
		"faixa":
			saida.append([Rect2(em.x, em.y, largura - 46.0, alto), 0])
		"estilo":
			saida.append([Rect2(em.x, em.y, LARGURA_SETA, alto), SETA_ANTES])
			saida.append([Rect2(em.x + LARGURA_SETA + 1.0, em.y,
				largura - 2.0 * LARGURA_SETA - 2.0, alto), MIOLO])
			saida.append([Rect2(em.x + largura - LARGURA_SETA, em.y, LARGURA_SETA,
				alto), SETA_DEPOIS])
		"lista":
			var itens: Array = campo["itens"]
			var passo := largura / float(itens.size())
			for k in itens.size():
				saida.append([Rect2(em.x + float(k) * passo, em.y, passo - 2.0, alto), k])
		"cor":
			var cores := Aparencia.paleta(String(campo["paleta"]))
			var passo := largura / float(maxi(1, cores.size()))
			for k in cores.size():
				saida.append([Rect2(em.x + float(k) * passo, em.y + 1.0,
					maxf(4.0, passo - 1.0), alto - 2.0), k])
		_:
			var quantos := int(campo["quantos"])
			if quantos <= POR_PAGINA:
				var passo := largura / float(quantos)
				for k in quantos:
					saida.append([Rect2(em.x + float(k) * passo, em.y, passo - 2.0,
						alto), k])
			else:
				var seta := 8.0
				saida.append([Rect2(em.x, em.y, seta - 1.0, alto), SETA_ANTES])
				saida.append([Rect2(em.x + largura - seta + 1.0, em.y, seta - 1.0,
					alto), SETA_DEPOIS])
				var miolo := largura - 2.0 * seta
				var passo := miolo / float(POR_PAGINA)
				var pagina := _pagina_de(campo)
				for k in POR_PAGINA:
					var item := pagina * POR_PAGINA + k
					if item >= quantos:
						break
					saida.append([Rect2(em.x + seta + float(k) * passo, em.y,
						passo - 2.0, alto), item])
	return saida


## A pagina que um campo de celulas mostra: a escolhida pelas setas, ou a do
## item selecionado.
func _pagina_de(campo: Dictionary) -> int:
	var chave: StringName = campo["chave"]
	if _pagina.has(chave):
		return int(_pagina[chave])
	return int(_ajustes.get(chave, 0)) / POR_PAGINA


func _desenhar_escolha(campo: Dictionary, em: Vector2, ativo: bool,
		indice_campo: int) -> void:
	var chave: StringName = campo["chave"]
	var tipo := String(campo["tipo"])
	var alvos := _alvos(campo, em)
	var sob_mouse := indice_campo == _hover_campo

	if tipo == "faixa":
		_desenhar_faixa(campo, alvos[0][0], ativo, sob_mouse)
		return

	if tipo == "estilo":
		_desenhar_estilo(campo, alvos, ativo, sob_mouse, indice_campo)
		return

	if tipo == "lista":
		var itens: Array = campo["itens"]
		var indice := posmod(int(_ajustes.get(chave, 0)), itens.size())
		for alvo: Array in alvos:
			var r: Rect2 = alvo[0]
			var k: int = alvo[1]
			var sel := k == indice
			var face := CarteiraArte.botao(self, r, Color(0.93, 0.91, 0.82) if sel
				else Color(0.80, 0.78, 0.68), DESTAQUE if sel else TINTA_FRACA,
				_altura_do_botao(indice_campo, k, sob_mouse and k == _hover_celula))
			_texto(Vector2(face.position.x, face.position.y + 11.0),
				String(itens[k]).substr(0, 4), TINTA, _fonte,
				HORIZONTAL_ALIGNMENT_CENTER, face.size.x)
		return

	if tipo == "cor":
		var cores := Aparencia.paleta(String(campo["paleta"]))
		var atual: Color = _ajustes.get(chave, cores[0])
		var sel_r := Rect2()
		for alvo: Array in alvos:
			var r: Rect2 = alvo[0]
			var k: int = alvo[1]
			var sel := cores[k].is_equal_approx(atual)
			var hov := sob_mouse and k == _hover_celula
			# Pastilha de tinta: a cor e o botao, com luz em cima e sombra
			# embaixo, e a selecionada fica levantada.
			var face := CarteiraArte.botao(self, r, cores[k], cores[k].darkened(0.45),
				2.0 if (sel or hov) else _altura_do_botao(indice_campo, k, false))
			if sel:
				sel_r = face
		if sel_r.size.x > 0.0:
			draw_rect(sel_r.grow(1.5), CELULA_SEL, false, 2.0)
			draw_rect(sel_r.grow(2.5), DESTAQUE if ativo else TINTA, false, 1.0)
			_desenhar_pop(chave, sel_r)
		return

	# Celula do atlas: mostra o desenho de verdade, e nao um numero.
	var quantos := int(campo["quantos"])
	var atual_i := posmod(int(_ajustes.get(chave, 0)), quantos)
	for alvo: Array in alvos:
		var r: Rect2 = alvo[0]
		var k: int = alvo[1]
		var hov := sob_mouse and k == _hover_celula
		if k < 0:
			_desenhar_seta(r, k, hov, _altura_do_botao(indice_campo, k, hov))
			continue
		var sel := k == atual_i
		var face := CarteiraArte.botao(self, r, Color(0.86, 0.84, 0.75) if sel
			else Color(0.78, 0.76, 0.66), DESTAQUE if sel else TINTA_FRACA,
			2.0 if sel else _altura_do_botao(indice_campo, k, hov))
		var fonte_atlas := _atlas_das_miniaturas()
		if fonte_atlas[0] != null:
			var esc: float = fonte_atlas[1]
			var lado := float(Aparencia.CELULA) * esc
			draw_texture_rect_region(fonte_atlas[0], face.grow(-1.0), Rect2(
				float(k % Aparencia.VARIANTES) * lado,
				float(_linha_do_atlas(chave, k)) * lado, lado, lado).grow(-esc * 0.5))
		if sel:
			draw_rect(face.grow(1.0), CELULA_SEL, false, 2.0)
			draw_rect(face.grow(2.0), DESTAQUE if ativo else TINTA, false, 1.0)
			_desenhar_pop(chave, face)
		elif hov:
			draw_rect(face.grow(1.0), DESTAQUE, false, 1.0)

## Seta de widget: caixinha com triangulo. `anterior` pelo codigo.
func _desenhar_seta(r: Rect2, codigo: int, hover: bool, altura: float = 1.0) -> void:
	var face := CarteiraArte.botao(self, r, Color(0.93, 0.90, 0.80) if hover
		else Color(0.82, 0.80, 0.70), DESTAQUE if hover else TINTA_FRACA, altura)
	var c := face.get_center()
	var s := -1.0 if codigo == SETA_ANTES else 1.0
	var cor := DESTAQUE if hover else TINTA
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(2.5 * s, 0.0), c + Vector2(-2.0 * s, -3.5),
		c + Vector2(-2.0 * s, 3.5)]), cor)


## Quanto um botao esta levantado: 0 apertado, 2 sob o mouse, 1 em repouso.
func _altura_do_botao(indice_campo: int, codigo: int, hover: bool) -> float:
	if _apertado.size() == 3 and int(_apertado[0]) == indice_campo \
			and int(_apertado[1]) == codigo and _relogio - float(_apertado[2]) < 0.12:
		return 0.0
	return 2.0 if hover else 1.0


## O anel que pulsa uma vez em volta do que acabou de ser escolhido.
func _desenhar_pop(chave: StringName, r: Rect2) -> void:
	if not _pop.has(chave):
		return
	var t := (_relogio - float(_pop[chave])) / 0.30
	if t >= 1.0:
		return
	var e := 1.0 - pow(1.0 - t, 2.0)
	draw_rect(r.grow(2.0 + 5.0 * e), Color(DESTAQUE.r, DESTAQUE.g, DESTAQUE.b,
		0.85 * (1.0 - t)), false, 1.0)

## O seletor de modelo: seta, nome, seta, e as pintas de posicao embaixo.
func _desenhar_estilo(campo: Dictionary, alvos: Array, ativo: bool,
		sob_mouse: bool, indice_campo: int) -> void:
	var chave: StringName = campo["chave"]
	var itens: Array = campo["itens"]
	var indice := posmod(int(_ajustes.get(chave, 0)), itens.size())
	for alvo: Array in alvos:
		var r: Rect2 = alvo[0]
		var k: int = alvo[1]
		var hov := sob_mouse and k == _hover_celula
		if k != MIOLO:
			_desenhar_seta(r, k, hov, _altura_do_botao(indice_campo, k, hov))
			continue
		var face := CarteiraArte.botao(self, r, Color(0.97, 0.95, 0.87) if hov
			else Color(0.93, 0.91, 0.82), DESTAQUE if (ativo or hov) else TINTA_FRACA,
			_altura_do_botao(indice_campo, k, hov))
		# O nome novo entra deslizando do lado da seta que foi apertada.
		var desl := 0.0
		var alfa := 1.0
		if _desliza.has(chave):
			var d: Array = _desliza[chave]
			var t := clampf((_relogio - float(d[1])) / 0.18, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - t, 3.0)
			desl = float(d[0]) * 16.0 * (1.0 - e)
			alfa = e
		_texto(Vector2(face.position.x + desl, face.position.y + 10.0),
			String(itens[indice]), Color(TINTA.r, TINTA.g, TINTA.b, alfa), _fonte,
			HORIZONTAL_ALIGNMENT_CENTER, face.size.x)
		# Uma pinta por modelo, a atual na cor da aba.
		var n := itens.size()
		var passo := minf(5.0, (face.size.x - 8.0) / float(n))
		var x0 := face.get_center().x - passo * float(n - 1) * 0.5
		for p in n:
			draw_rect(Rect2(x0 + float(p) * passo - 1.0, face.end.y - 3.0, 2.0, 1.0),
				DESTAQUE if p == indice else Color(TINTA_FRACA.r, TINTA_FRACA.g,
					TINTA_FRACA.b, 0.55))
		if _pop.has(chave):
			var tp := (_relogio - float(_pop[chave])) / 0.25
			if tp < 1.0:
				draw_rect(face, Color(1.0, 0.97, 0.85, 0.35 * (1.0 - tp)))

## O deslizador: trilho fundo, preenchimento, marcas de quarto e o cursor.
##
## Era uma barra chapada com um retangulo em cima. O que faz um deslizador ler
## como peca de controle, e nao como grafico de barras, e o TRILHO afundado
## (sombra em cima, luz embaixo), as marcas que dizem onde fica o meio e um
## cursor com pega. Tudo em pixel inteiro, que e onde a tela de 480 vive.
func _desenhar_faixa(campo: Dictionary, area: Rect2, ativo: bool,
		sob_mouse: bool) -> void:
	var chave: StringName = campo["chave"]
	var minimo := float(campo["minimo"])
	var valor := float(_ajustes.get(chave, minimo))
	var t := float(_faixa_vista.get(chave, _t_da_faixa(campo)))
	var quente := ativo or sob_mouse or _arrastando_chave == chave
	var trilho := Rect2(area.position.x + 3.0, area.position.y + 6.0,
		area.size.x - 6.0, 5.0)
	draw_colored_polygon(CarteiraArte.chanfro(trilho, 1.0), Color(0.60, 0.60, 0.51))
	draw_rect(Rect2(trilho.position.x + 1.0, trilho.position.y, trilho.size.x - 2.0, 1.0),
		Color(0.28, 0.28, 0.22, 0.70))
	draw_rect(Rect2(trilho.position.x + 1.0, trilho.end.y - 1.0, trilho.size.x - 2.0, 1.0),
		Color(1.0, 1.0, 0.95, 0.45))
	var cheio := trilho.size.x * t
	if cheio > 1.0:
		var base: Color = COR_ABA[_aba % COR_ABA.size()] if quente else TINTA_FRACA
		var a := trilho.position + Vector2(1.0, 1.0)
		draw_polygon(PackedVector2Array([a, a + Vector2(cheio - 1.0, 0.0),
			a + Vector2(cheio - 1.0, 3.0), a + Vector2(0.0, 3.0)]),
			PackedColorArray([base.darkened(0.25), base.lightened(0.18),
				base.lightened(0.18), base.darkened(0.25)]))
	for q: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var xq := roundf(trilho.position.x + trilho.size.x * q)
		var alto_marca := 3.0 if q == 0.5 else 2.0
		draw_rect(Rect2(xq, trilho.end.y + 1.0, 1.0, alto_marca),
			Color(TINTA_FRACA.r, TINTA_FRACA.g, TINTA_FRACA.b, 0.7))
	var xc := roundf(trilho.position.x + cheio)
	var cursor := Rect2(xc - 3.0, area.position.y + 2.0, 7.0, 12.0)
	var face := CarteiraArte.botao(self, cursor, Color(0.97, 0.95, 0.88),
		DESTAQUE if quente else TINTA, 2.0 if quente else 1.0)
	for g: float in [-1.0, 1.0]:
		draw_rect(Rect2(roundf(face.get_center().x) + g - 0.5, face.position.y + 4.0,
			1.0, 4.0), TINTA_FRACA)
	_texto(Vector2(area.end.x + 4.0, area.position.y + 12.0),
		_texto_da_faixa(chave, valor, _t_da_faixa(campo)), DESTAQUE if quente else TINTA)

static func _texto_da_faixa(chave: StringName, valor: float, t: float) -> String:
	match chave:
		&"altura":
			return "%.2f m" % valor
		&"ombro":
			if t < 0.3:
				return "ESTREITO"
			if t < 0.7:
				return "MEDIO"
			return "LARGO"
	return _nome_do_porte(t)


## A linha do atlas de um item. Rosto 8 a 15 mora na linha de estudio.
func _linha_do_atlas(chave: StringName, item: int = 0) -> int:
	match chave:
		&"rosto":
			var ficha := RegistroCivil.jogador
			var feminino := StringName(ficha.get("sexo", &"M")) == &"F"
			if item >= Aparencia.VARIANTES:
				return (Aparencia.LINHA_ESTUDIO_F if feminino
					else Aparencia.LINHA_ESTUDIO_M)
			return Aparencia.LINHA_ROSTO_F if feminino else Aparencia.LINHA_ROSTO_M
		&"cabelo":
			return Aparencia.LINHA_CABELO
		&"calca":
			return Aparencia.LINHA_CALCA
		&"casaco_cel":
			return Aparencia.LINHA_CASACO
		_:
			return Aparencia.LINHA_CAMISA


## O visto de aceite, no canto de cima da pagina — o mesmo lugar da referencia.
func _desenhar_visto() -> void:
	var pronto := _linha == campos_da_aba().size() + 1
	var caixa := _rect_visto()
	var fill := Color(0.94, 0.92, 0.84)
	if pronto:
		var pulso := 0.04 + 0.04 * sin(_relogio * 3.2)
		fill = Color(0.96, 0.90 + pulso, 0.78)
	var apertado := _apertou_visto >= 0.0 and _relogio - _apertou_visto < 0.14
	var altura := 0.0 if apertado else (2.0 if (_hover_visto or pronto) else 1.0)
	var face := CarteiraArte.botao(self, caixa, fill,
		DESTAQUE if pronto or _hover_visto else TINTA_FRACA, altura)
	var c := face.get_center()
	var cor := DESTAQUE if pronto or _hover_visto else TINTA
	draw_line(c + Vector2(-6.0, 0.0), c + Vector2(-1.0, 5.0), cor, 2.4)
	draw_line(c + Vector2(-1.0, 5.0), c + Vector2(7.0, -6.0), cor, 2.4)
	if pronto or _hover_visto:
		# Balao ao lado, por cima do nome: no alto a faixa e das abas.
		var larg := _largura_do_texto("EMITIR") + 8.0
		var balao := Rect2(caixa.position.x - larg - 3.0, caixa.position.y + 4.0, larg, 12.0)
		draw_rect(Rect2(balao.position + Vector2(1.0, 1.0), balao.size),
			Color(0.05, 0.05, 0.04, 0.35))
		draw_rect(balao, DESTAQUE)
		_texto(Vector2(balao.position.x, balao.position.y + 9.0), "EMITIR",
			Color(0.97, 0.94, 0.86), _fonte, HORIZONTAL_ALIGNMENT_CENTER, balao.size.x)

## Zona de leitura no rodape, como no RG do inventario.
func _desenhar_zona() -> void:
	var ficha := RegistroCivil.jogador
	if ficha.is_empty():
		return
	var numero := String(ficha["cpf"]).replace(".", "").replace("-", "")
	var zona := "IDBRA%s<<%s" % [numero,
		String(ficha["sobrenome"]).replace(" ", "<")]
	# Recuada e encurtada porque os polegares moram nas duas margens laterais:
	# comecando na antiga folga de dez pixels, a zona passava por baixo do
	# polegar esquerdo e as tres primeiras letras sumiam.
	_texto(Vector2(DOC.position.x + 34.0, DOC.end.y - 7.0), zona.substr(0, 30),
		TINTA_FRACA, _mono)


static func _nome_do_porte(t: float) -> String:
	if t < 0.2:
		return "MAGRO"
	if t < 0.4:
		return "SECO"
	if t < 0.62:
		return "MEDIO"
	if t < 0.82:
		return "FORTE"
	return "GORDO"


# --- entrada ----------------------------------------------------------------

## Publica: a verificacao mexe nos campos sem simular tecla.
func mudar(passo: int) -> void:
	if _linha == LINHA_ABAS:
		_trocar_aba(posmod(_aba + passo, ABAS.size()))
		return
	var indice := _linha - 1
	if indice >= campos_da_aba().size():
		return
	_passo_no_campo(_campo(campos_da_aba()[indice]), passo)


## Anda `passo` itens num campo, qualquer que seja o tipo.
func _passo_no_campo(campo: Dictionary, passo: int) -> void:
	var chave: StringName = campo["chave"]
	match String(campo["tipo"]):
		"faixa":
			var minimo := float(campo["minimo"])
			var maximo := float(campo["maximo"])
			var atual := float(_ajustes.get(chave, minimo))
			# Vinte passos de ponta a ponta: menos e grosseiro, mais vira uma
			# viagem de teclado ate o outro extremo.
			_ajustes[chave] = clampf(atual + float(passo) * (maximo - minimo) / 20.0,
				minimo, maximo)
		"lista", "estilo":
			var itens: Array = campo["itens"]
			_ajustes[chave] = posmod(int(_ajustes.get(chave, 0)) + passo, itens.size())
			_desliza[chave] = [signi(passo), _relogio]
		"cor":
			var cores := Aparencia.paleta(String(campo["paleta"]))
			var atual_cor: Color = _ajustes.get(chave, cores[0])
			var i := 0
			for k in cores.size():
				if cores[k].is_equal_approx(atual_cor):
					i = k
					break
			_ajustes[chave] = cores[posmod(i + passo, cores.size())]
		_:
			var quantos := int(campo["quantos"])
			var novo := posmod(int(_ajustes.get(chave, 0)) + passo, quantos)
			_ajustes[chave] = novo
			# A pagina segue a selecao pelo teclado.
			_pagina.erase(chave)
	_apos_mudanca(chave)

## Depois de qualquer troca: som, corpo novo e o gesto da peca que mudou.
func _apos_mudanca(chave: StringName) -> void:
	AudioDirector.tocar_ui(&"clique", -18.0)
	_pop[chave] = _relogio
	_refazer_corpo(ReacaoCorpo.do_campo(chave))
	queue_redraw()

## Troca de aba, e o retrato vai para o enquadramento dela.
func _trocar_aba(nova: int) -> void:
	if nova != _aba:
		# A folha vira para o lado que se anda: para a frente vira da direita
		# para a esquerda, como num livro.
		_virada_dir = 1 if nova > _aba else -1
		_virada = 0.0
		_revela = -0.12
		AudioDirector.tocar_ui(&"papel", -16.0, randf_range(0.95, 1.08))
	_aba = nova
	_estudio.focar(float(ABAS[_aba].get("zoom", 0.4)))
	AudioDirector.tocar_ui(&"clique", -22.0)
	queue_redraw()

## Publica: escolhe a aba pelo nome, para a verificacao nao depender da ordem.
func ir_para_aba(nome: String) -> bool:
	for i in ABAS.size():
		if String(ABAS[i]["nome"]) == nome:
			_aba = i
			_linha = 1
			if _estudio != null:
				_estudio.focar(float(ABAS[_aba].get("zoom", 0.4)))
			queue_redraw()
			return true
	return false


func confirmar() -> void:
	if _emissao >= 0.0:
		return
	# A foto bate, a pessoa aprova, o carimbo cai. O registro e gravado JA:
	# o que vem depois e cerimonia, e um fechamento de janela no meio dela nao
	# pode perder a aparencia escolhida.
	RegistroCivil.ajustar_jogador(_ajustes)
	_emissao = 0.0
	_clarao = 1.0
	_apertou_visto = _relogio
	_estudio.aprovar()
	AudioDirector.tocar_ui(&"pegar", -8.0)


func _avancar_emissao(delta: float) -> void:
	var antes := _emissao
	_emissao += delta
	if antes < EMISSAO_POUSO and _emissao >= EMISSAO_POUSO:
		_tremor = 1.0
		# O mesmo baque do carimbo da ficha: interruptor puxado bem para baixo.
		AudioDirector.tocar_ui(&"interruptor", -4.0, 0.55)
	if antes < EMISSAO_DESCE and _emissao >= EMISSAO_DESCE:
		AudioDirector.tocar_ui(&"papel", -12.0, 0.9)
	if _emissao >= EMISSAO_FIM:
		_emissao = -1.0
		# Fica embaixo: sem isto a carteira voltaria para as maos no quadro
		# entre o fim da descida e o menu fechar.
		_abertura = 0.0
		confirmou.emit()


## Voltar: a carteira desce, e so ENTAO a tela anterior aparece.
func _sair() -> void:
	if _saida >= 0.0 or _emissao >= 0.0:
		return
	_saida = 0.0
	AudioDirector.tocar_ui(&"papel", -14.0, 0.85)

## Passo de zoom por tecla e por clique no mais/menos, e de giro por tecla.
const PASSO_ZOOM := 0.18
const PASSO_ZOOM_RODA := 0.10
const PASSO_GIRO := 0.40


func navegar(evento: InputEvent) -> void:
	if _ocupada():
		return
	var total := campos_da_aba().size() + 2
	var tecla := evento as InputEventKey
	var tecla_nova := tecla != null and tecla.pressed and not tecla.echo
	if evento.is_action_pressed("mover_tras") or evento.is_action_pressed("ui_down"):
		_linha = posmod(_linha + 1, total)
		AudioDirector.tocar_ui(&"clique", -24.0)
	elif evento.is_action_pressed("mover_frente") or evento.is_action_pressed("ui_up"):
		_linha = posmod(_linha - 1, total)
		AudioDirector.tocar_ui(&"clique", -24.0)
	elif evento.is_action_pressed("mover_dir") or evento.is_action_pressed("ui_right"):
		mudar(1)
	elif evento.is_action_pressed("mover_esq") or evento.is_action_pressed("ui_left"):
		mudar(-1)
	elif evento.is_action_pressed("seta_esquerda", true):
		_estudio.girar(-PASSO_GIRO)
	elif evento.is_action_pressed("seta_direita", true):
		_estudio.girar(PASSO_GIRO)
	elif tecla_nova and tecla.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD, KEY_PAGEUP]:
		_estudio.aproximar(-PASSO_ZOOM)
	elif tecla_nova and tecla.keycode in [KEY_MINUS, KEY_KP_SUBTRACT, KEY_PAGEDOWN]:
		_estudio.aproximar(PASSO_ZOOM)
	elif evento.is_action_pressed("interagir") or evento.is_action_pressed("ui_accept"):
		if _linha == campos_da_aba().size() + 1:
			confirmar()
		else:
			mudar(1)
	elif evento.is_action_pressed("pausa"):
		_sair()
	else:
		return
	queue_redraw()

func _desenhar_nome_da_aba() -> void:
	# A aba aberta ja escreve o proprio nome; o balao e para as fechadas.
	if _hover_aba < 0 or _hover_aba == _aba or _fonte == null:
		return
	var nome := String(ABAS[_hover_aba]["nome"])
	var largura := _largura_do_texto(nome) + 8.0
	var r := _rect_aba(_hover_aba)
	var x := clampf(r.get_center().x - largura * 0.5, DOC.position.x + 2.0,
		DOC.end.x - largura - 2.0)
	var balao := Rect2(x, r.end.y + 3.0, largura, 12.0)
	draw_rect(Rect2(balao.position + Vector2(1.0, 1.0), balao.size),
		Color(0.05, 0.05, 0.04, 0.35))
	draw_rect(balao, COR_ABA[_hover_aba % COR_ABA.size()].darkened(0.35))
	_texto(Vector2(balao.position.x, balao.position.y + 9.0), nome,
		Color(0.96, 0.93, 0.85), _fonte, HORIZONTAL_ALIGNMENT_CENTER, balao.size.x)


# --- mouse / hit-areas ------------------------------------------------------

## Converte coordenada local do Control para o espaco logico 480x270 (TELA).
## Com stretch viewport o size costuma ja ser TELA; a conta cobre letterbox/escala.
func _para_tela(local: Vector2) -> Vector2:
	var s := size
	if s.x <= 1.0 or s.y <= 1.0:
		return local
	return Vector2(local.x * TELA.x / s.x, local.y * TELA.y / s.y)


## A largura da aba sai da CONTAGEM de abas, e nao de um numero fixo.
##
## A fileira ganhou a setima aba (agasalho) e as seis de antes tinham largura
## escrita a mao: a nova entrava por fora da pagina. Dividir a coluna pelo
## tamanho de ABAS faz a fileira caber sozinha na proxima que entrar.
func _rect_aba(i: int) -> Rect2:
	if _larg_abas.size() != ABAS.size():
		_animar_abas(0.0)
	var x := CarteiraLayout.ABA_INICIO
	for j in i:
		x += _larg_abas[j] + CarteiraLayout.ABA_VAO
	var alto := _alt_abas[i]
	return Rect2(x, DOC_Y + 2.0 - alto, _larg_abas[i], alto)

func _rect_visto() -> Rect2:
	return Rect2(PAGINA_DIR.end.x - 24.0, DOC_Y + 8.0, 20.0, 20.0)


## Onde a linha de um campo comeca, empilhando as alturas de quem veio antes.
##
## E a MESMA acumulacao de `_desenhar_campos`, e tem de ser: esta funcao e a que
## o mouse consulta. Se as duas discordarem, o desenho aparece num lugar e o
## clique acontece noutro — que e o pior defeito possivel numa tela clicavel,
## porque ele nao aparece em captura nenhuma.
func _origem_campo(indice_campo: int) -> Vector2:
	var y := LINHA_UM
	for i in campos_da_aba().size():
		if i == indice_campo:
			break
		y += _altura_do_campo(_campo(campos_da_aba()[i]))
	return Vector2(PAGINA_DIR.position.x, y + CAMPO_ROTULO)


func _carregar_cabine() -> void:
	# Preferencia: PackedScene 3D (piloto FP). Fallback: PNG estatico.
	# Menu pausa a arvore em APARENCIA — SubViewport + cena em ALWAYS para o
	# micro-idle da cabine continuar (ver CabineFundoCriacao._process).
	if ResourceLoader.exists(CABINE_CENA):
		var packed := load(CABINE_CENA) as PackedScene
		if packed != null:
			_cabine_viewport = SubViewport.new()
			_cabine_viewport.name = "CabineFundo"
			_cabine_viewport.size = Vector2i(int(TELA.x), int(TELA.y))
			_cabine_viewport.own_world_3d = true
			_cabine_viewport.transparent_bg = false
			_cabine_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			_cabine_viewport.msaa_3d = Viewport.MSAA_DISABLED
			_cabine_viewport.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(_cabine_viewport)
			var cena := packed.instantiate()
			cena.process_mode = Node.PROCESS_MODE_ALWAYS
			_cabine_viewport.add_child(cena)

			print("[criacao] cabine live: %s" % CABINE_CENA)
			return

	# Interim Texture2D (+ mascara LOCAL/HORA no _draw).
	if ResourceLoader.exists(UI % "criacao_cabine"):
		_cabine = load(UI % "criacao_cabine") as Texture2D
		if _cabine != null:
			print("[criacao] cabine fallback PNG (asset)")
			return

	var candidatos: PackedStringArray = [
		"C:/Users/Administrator/Documents/Codes/Games/PSX/game/assets/ui/criacao_cabine.png",
		"C:/Users/Administrator/Documents/Codes/Games/PSX/captures/estrada_velha/cabine/fp_cabine_flag.png",
		"C:/Users/Administrator/Documents/Codes/Games/PSX/captures/estrada_velha/cabine/fp_01.png",
	]
	var raiz := ProjectSettings.globalize_path("res://")
	candidatos.append(raiz + "assets/ui/criacao_cabine.png")
	candidatos.append(raiz + "../captures/estrada_velha/cabine/fp_cabine_flag.png")
	for caminho: String in candidatos:
		var limpo := caminho.replace("\\", "/")
		while limpo.contains("/../"):
			# resolve um nivel: foo/bar/../x -> foo/x
			var i := limpo.find("/../")
			var esq := limpo.substr(0, i)
			var barra := esq.rfind("/")
			if barra < 0:
				break
			limpo = esq.substr(0, barra) + limpo.substr(i + 3)
		if not FileAccess.file_exists(limpo):
			continue
		var img := Image.new()
		if img.load(limpo) != OK:
			continue
		_cabine = ImageTexture.create_from_image(img)
		return


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouse:
		_mouse_tela = _para_tela((evento as InputEventMouse).position)
	if _ocupada():
		return
	if evento is InputEventMouseButton:
		var mb := evento as InputEventMouseButton
		var pos := _para_tela(mb.position)
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP
				or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var passo := 1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1
			if _rodar_em(pos, passo):
				accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if _clicar_em(pos):
					accept_event()
			else:
				if _arrastando_chave != &"" or _girando:
					_arrastando_chave = &""
					_arrastando_campo = {}
					_girando = false
					accept_event()
		return
	if evento is InputEventMouseMotion:
		var mm := evento as InputEventMouseMotion
		var pos := _para_tela(mm.position)
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if _arrastando_chave != &"":
				_arrastar_faixa(pos)
				accept_event()
			elif _girando:
				# Meio grau por pixel de tela logica: atravessar a foto inteira
				# da quase uma volta.
				_estudio.girar(_para_tela(mm.relative).x * 0.055)
				accept_event()
		_atualizar_hover(pos)

## A roda do mouse: na foto e zoom; num campo, anda um item ou um passo.
func _rodar_em(pos: Vector2, passo: int) -> bool:
	if RETRATO.has_point(pos):
		_estudio.aproximar(-PASSO_ZOOM_RODA * float(passo))
		return true
	for i in campos_da_aba().size():
		var campo := _campo(campos_da_aba()[i])
		var em := _origem_campo(i)
		var linha := Rect2(PAGINA_DIR.position.x - 3.0, em.y - CAMPO_ROTULO - 3.0,
			PAGINA_DIR.size.x, _altura_do_campo(campo))
		if linha.has_point(pos):
			_linha = i + 1
			_passo_no_campo(campo, passo)
			return true
	return false


func _atualizar_hover(pos: Vector2) -> void:
	var aba_antes := _hover_aba
	var cel_antes := _hover_celula
	var campo_antes := _hover_campo
	var visto_antes := _hover_visto
	var retrato_antes := _hover_retrato
	_hover_aba = -1
	_hover_celula = -99
	_hover_campo = -1
	_hover_visto = _rect_visto().has_point(pos)
	_hover_retrato = RETRATO.grow(2.0).has_point(pos)
	var barra_antes := _hover_barra
	_hover_barra = -1
	var barra := _itens_da_barra()
	for i in BARRA_ITENS.size():
		if (barra[i] as Rect2).has_point(pos) and StringName(BARRA_ITENS[i][2]) != &"":
			_hover_barra = i
	if barra_antes != _hover_barra:
		queue_redraw()
	for i in ABAS.size():
		if _rect_aba(i).has_point(pos):
			_hover_aba = i
			break
	if _hover_aba < 0 and not _hover_visto:
		for i in campos_da_aba().size():
			var campo := _campo(campos_da_aba()[i])
			for alvo: Array in _alvos(campo, _origem_campo(i)):
				if (alvo[0] as Rect2).has_point(pos):
					_hover_campo = i
					_hover_celula = alvo[1]
					break
			if _hover_campo >= 0:
				break
	if (aba_antes != _hover_aba or cel_antes != _hover_celula
			or campo_antes != _hover_campo or visto_antes != _hover_visto
			or retrato_antes != _hover_retrato):
		queue_redraw()
	var clicavel := _hover_aba >= 0 or _hover_campo >= 0 or _hover_visto \
		or _hover_barra >= 0
	if _hover_retrato:
		mouse_default_cursor_shape = (Control.CURSOR_DRAG if _girando
			else Control.CURSOR_POINTING_HAND if _no_controle_do_retrato(pos)
			else Control.CURSOR_MOVE)
	else:
		mouse_default_cursor_shape = (Control.CURSOR_POINTING_HAND if clicavel
			else Control.CURSOR_ARROW)


func _no_controle_do_retrato(pos: Vector2) -> bool:
	return (_rect_trilho().grow(2.0).has_point(pos) or _rect_zoom(-1).has_point(pos)
		or _rect_zoom(1).has_point(pos) or _rect_girar(-1).has_point(pos)
		or _rect_girar(1).has_point(pos))


func _clicar_em(pos: Vector2) -> bool:
	var barra := _itens_da_barra()
	for i in BARRA_ITENS.size():
		if (barra[i] as Rect2).has_point(pos):
			match StringName(BARRA_ITENS[i][2]):
				&"voltar":
					_sair()
					return true
				&"emitir":
					confirmar()
					return true
	if _rect_visto().has_point(pos):
		_linha = campos_da_aba().size() + 1
		AudioDirector.tocar_ui(&"clique", -16.0)
		queue_redraw()
		confirmar()
		return true
	for i in ABAS.size():
		if _rect_aba(i).has_point(pos):
			_linha = LINHA_ABAS
			_trocar_aba(i)
			return true
	if _clicar_no_retrato(pos):
		return true
	for i in campos_da_aba().size():
		var campo := _campo(campos_da_aba()[i])
		if _aplicar_clique_campo(campo, _origem_campo(i), pos, i):
			return true
	return false

## Mais, menos, o trilho, as setas de giro — e no resto da foto, arrastar gira.
func _clicar_no_retrato(pos: Vector2) -> bool:
	if _rect_zoom(-1).has_point(pos):
		_estudio.aproximar(-PASSO_ZOOM)
	elif _rect_zoom(1).has_point(pos):
		_estudio.aproximar(PASSO_ZOOM)
	elif _rect_trilho().grow(2.0).has_point(pos):
		var t := _rect_trilho()
		_estudio.focar(clampf((pos.y - t.position.y) / t.size.y, 0.0, 1.0))
	elif _rect_girar(-1).has_point(pos):
		_estudio.girar(-PI * 0.25)
	elif _rect_girar(1).has_point(pos):
		_estudio.girar(PI * 0.25)
	elif RETRATO.has_point(pos):
		_girando = true
		mouse_default_cursor_shape = Control.CURSOR_DRAG
		return true
	else:
		return false
	AudioDirector.tocar_ui(&"clique", -22.0)
	queue_redraw()
	return true


func _aplicar_clique_campo(campo: Dictionary, em: Vector2, pos: Vector2,
		indice_linha: int) -> bool:
	var chave: StringName = campo["chave"]
	var tipo := String(campo["tipo"])
	var codigo := -99
	for alvo: Array in _alvos(campo, em):
		if (alvo[0] as Rect2).has_point(pos):
			codigo = alvo[1]
			break
	if codigo == -99:
		return false
	_linha = indice_linha + 1
	_apertado = [indice_linha, codigo, _relogio]
	match tipo:
		"faixa":
			_arrastando_chave = chave
			_arrastando_campo = campo
			_arrastar_faixa(pos)
			AudioDirector.tocar_ui(&"clique", -18.0)
			return true
		"estilo":
			_passo_no_campo(campo, -1 if codigo == SETA_ANTES else 1)
			return true
		"lista":
			_ajustes[chave] = codigo
		"cor":
			var cores := Aparencia.paleta(String(campo["paleta"]))
			_ajustes[chave] = cores[codigo]
		_:
			if codigo < 0:
				# Seta de pagina: muda o que se ve, nao o que se escolheu.
				var paginas := ceili(float(int(campo["quantos"])) / float(POR_PAGINA))
				_pagina[chave] = posmod(_pagina_de(campo)
					+ (-1 if codigo == SETA_ANTES else 1), paginas)
				AudioDirector.tocar_ui(&"clique", -22.0)
				queue_redraw()
				return true
			_ajustes[chave] = codigo
	_apos_mudanca(chave)
	return true


func _arrastar_faixa(pos: Vector2) -> void:
	if _arrastando_chave == &"" or _arrastando_campo.is_empty():
		return
	var campo := _arrastando_campo
	var chave: StringName = _arrastando_chave
	var minimo := float(campo["minimo"])
	var maximo := float(campo["maximo"])
	var em := Vector2(PAGINA_DIR.position.x, DOC_Y + 30.0)
	for i in campos_da_aba().size():
		if campos_da_aba()[i] == chave:
			em = _origem_campo(i)
			break
	# O trilho desenhado, e nao a area inteira: a ponta do trilho e o minimo.
	var area: Rect2 = _alvos(campo, em)[0][0]
	var inicio := area.position.x + 3.0
	var largura := area.size.x - 6.0
	var t := clampf((pos.x - inicio) / maxf(1.0, largura), 0.0, 1.0)
	_ajustes[chave] = lerpf(minimo, maximo, t)
	_refazer_corpo(ReacaoCorpo.do_campo(chave))
	queue_redraw()
