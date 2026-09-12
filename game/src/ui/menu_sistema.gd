## Menu de sistema em jogo — os tres pauzinhos da prancha.
##
## O buraco que ele fecha
## ----------------------
## ESC e TAB abriam a prancha e mais nada, e `cidade.gd` dizia em comentario que
## o menu de titulo nao reabre no meio da partida. A consequencia era que seis
## ajustes de imagem, tres espacos de save e uma pagina de mapa existiam no
## codigo e nao tinham porta: o jogador so os alcancava antes de apertar NOVO
## JOGO. E volume nao existia em lugar nenhum, com cinco buses configurados.
##
## Como se abre
## ------------
## Com a prancha aberta, `[W]`. Nao e tecla nova: e subir, e o que esta acima da
## faixa de itens sao os pauzinhos do canto. Botar uma tecla dedicada para isto
## custaria uma linha no mapa de entrada e uma coisa a mais para o jogador
## decorar; subir ele ja sabe fazer.
##
## De onde vem a lista de ajustes
## ------------------------------
## De `OpcoesLista`, a mesma que o menu de titulo le. Reescrever a lista aqui
## daria certo hoje e erraria no primeiro ajuste — um painel com sete opcoes e o
## outro com seis, os dois dizendo que sao as opcoes do jogo.
##
## Desenhado, e nao montado com Label
## ----------------------------------
## Mesma escolha das telas de aparelho (GPS, ficha, terminal): uma lista com
## coluna de rotulo, coluna de valor e cursor e feita de coisa medida contra
## coisa medida, e quinze nos soltos saem do lugar no primeiro ajuste. E
## `draw_string` recebe o tamanho da fonte direto, que e o que aquelas telas
## sempre fizeram certo — ver UI-BIBLE secao 2.
class_name MenuSistema
extends Control

enum Pagina { RAIZ, VIDEO, AUDIO, CARREGAR }

signal continuar()
signal sair_para_titulo()
signal carregou(espaco: int)

## Folha centrada. Nao ocupa a tela toda: a prancha continua atras, e o jogador
## tem de ver que nao saiu dela.
##
## So a largura e o topo sao fixos. A ALTURA sai do conteudo, como a do cartao de
## missao — uma folha de altura fixa com quatro linhas dentro tem um palmo de
## papel em branco embaixo, e um papel com espaco sobrando le como tela que
## deveria ter mais coisa.
const FOLHA_X := 146.0
const FOLHA_Y := 44.0
const FOLHA_L := 188.0
const PAD := 12.0
## Vao entre duas linhas da lista.
const VAO := 2.0

## Pauzinhos no canto de cima da direita da prancha.
## Medido em `captures/ui/f4_pauzinhos.png`: no extremo (450, 13) o fundo da
## prancha tem luminancia 8, e a 27 px abaixo tem 26 — mais de tres vezes. O topo
## da tela e onde a vinheta do pos fecha junto com a tarja preta, e qualquer coisa
## ali nasce afogada. Seis pixels abaixo ja tiram a aba do pior ponto sem sair do
## canto de cima da direita, que e onde ela foi pedida.
const PAUZINHOS := Rect2(448.0, 19.0, 18.0, 14.0)

var pagina: Pagina = Pagina.RAIZ
## Painel aberto? O no continua VISIVEL com ele fechado, porque os pauzinhos do
## canto tem de aparecer o tempo todo em que a prancha esta na tela — e `_draw`
## nao roda em no invisivel. Esconder o painel e esconder o painel, nao o no.
var aberto: bool = false

var _sel: int = 0
var _fonte: Font
var _linha: float = 13.0
var _itens: Array[Dictionary] = []
## Camada propria da aba, ACIMA do pos-processamento. Ver `_montar_aba`.
var _camada_aba: CanvasLayer
var _aba: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Posicao e tamanho na mao, sem ancora: `set_anchors_preset` num pai que
	# ainda nao tem retangulo faz o Godot avisar que vai sobrescrever o tamanho
	# depois do `_ready` — e sobrescreve mesmo.
	position = Vector2.ZERO
	size = UiEstilo.TELA
	# Por cima de tudo que a prancha montou, sem depender da ordem em que os nos
	# entraram na arvore. A ordem existe e esta certa, mas ela e o resultado de
	# oito funcoes de montagem chamadas em sequencia — qualquer uma que ganhe um
	# no novo no fim empurraria esta folha para baixo dos icones de item, e o
	# painel ficaria com alfinete de inventario atravessado no meio do texto.
	z_index = 10
	_fonte = load(UiEstilo.FONTE_P) as Font
	_linha = UiEstilo.altura_da_linha(_fonte)
	# Redesenha quando a prancha aparece.
	#
	# `CanvasItem` desenha uma vez e guarda os comandos. Este no nasce dentro de
	# uma prancha que fica invisivel no mesmo `_ready`, entao o unico desenho que
	# ele chegou a fazer foi o do primeiro quadro — e era ELE que continuava na
	# tela depois, congelado, ignorando toda mudanca posterior. Passei tres
	# capturas achando que a aba estava escura demais quando na verdade eu estava
	# olhando um desenho velho.
	visibility_changed.connect(queue_redraw)
	_montar_aba()


## A aba dos tres pauzinhos mora numa camada ACIMA do pos-processamento.
##
## Ela e a unica peca desta frente que ganha essa excecao, e o UI-BIBLE exige
## justificativa escrita — aqui esta, medida.
##
## O canto de cima da direita e o ponto mais fechado da vinheta. Medido em
## `captures/ui/f4_pauzinhos.png`, um papel de luminancia 247 chega a tela com
## 10 a 19 ali; a arte da prancha em volta chega com 1 a 15. Nao e escolha de
## cor: o pos multiplica aquele canto por algo entre 0,05 e 0,15, e nenhum valor
## de origem sobrevive a isso. As duas saidas eram mudar a aba de lugar — mas o
## canto de cima da direita foi onde ela foi pedida, e logo abaixo comeca a faixa
## de itens — ou subir de camada, que e a excecao que `hud_estrada.gd` ja usa
## pelo mesmo motivo: icone de 2 px e barra fina nao sobrevivem ao grao.
##
## O PAINEL continua embaixo do pos, junto com o resto da prancha. So a aba sobe.
func _montar_aba() -> void:
	_camada_aba = CanvasLayer.new()
	_camada_aba.name = "AbaAcimaDoPos"
	_camada_aba.layer = UiEstilo.CAMADA_ACIMA_DO_POS
	_camada_aba.visible = false
	add_child(_camada_aba)

	_aba = Control.new()
	_aba.name = "Pauzinhos"
	_aba.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aba.position = Vector2.ZERO
	_aba.size = UiEstilo.TELA
	_aba.draw.connect(_desenhar_pauzinhos)
	_camada_aba.add_child(_aba)


## A aba aparece com a prancha, e nao com o painel: ela e o convite para abrir o
## painel, entao ela precisa existir justamente quando ele esta fechado.
func mostrar_aba(ligada: bool) -> void:
	if _camada_aba != null:
		_camada_aba.visible = ligada
	if _aba != null:
		_aba.queue_redraw()


# --- estado -----------------------------------------------------------------

func abrir() -> void:
	aberto = true
	if _aba != null:
		_aba.queue_redraw()
	_ir_para(Pagina.RAIZ)
	AudioDirector.tocar_ui(&"papel", -14.0)


func fechar() -> void:
	if not aberto:
		return
	aberto = false
	if _aba != null:
		_aba.queue_redraw()
	# Grava ao sair, e nao a cada deslizada: o jogador arrasta o volume dez vezes
	# procurando o ponto, e dez escritas em disco por causa disso e desperdicio.
	Settings.save_config()
	AudioDirector.tocar_ui(&"clique", -10.0)
	queue_redraw()


## So a captura automatizada usa: abre direto numa pagina, sem depender de
## tecla. Mesmo padrao de `--criacao-aba=` e `--ver-missao=`.
func abrir_em(qual: Pagina) -> void:
	abrir()
	_ir_para(qual)


func _ir_para(qual: Pagina) -> void:
	pagina = qual
	_sel = 0
	_itens = _montar_itens(qual)
	queue_redraw()


func _montar_itens(qual: Pagina) -> Array[Dictionary]:
	match qual:
		Pagina.VIDEO:
			var v := OpcoesLista.video()
			v.append(_voltar())
			return v
		Pagina.AUDIO:
			var a := OpcoesLista.audio()
			a.append(_voltar())
			return a
		Pagina.CARREGAR:
			return _espacos()
		_:
			return _raiz()


func _raiz() -> Array[Dictionary]:
	var tem_save := false
	for i in SaveGame.ESPACOS:
		tem_save = tem_save or SaveGame.existe(i)
	return [
		_acao("CONTINUAR", func() -> void:
			fechar()
			continuar.emit()),
		_acao("CARREGAR", func() -> void: _ir_para(Pagina.CARREGAR), tem_save),
		_acao("IMAGEM", func() -> void: _ir_para(Pagina.VIDEO)),
		_acao("SOM", func() -> void: _ir_para(Pagina.AUDIO)),
		_acao("SAIR PARA O TITULO", func() -> void:
			fechar()
			sair_para_titulo.emit()),
	]


## Um item por espaco de save, com o resumo que `SaveGame` ja sabia dar e que
## nunca teve tela. Espaco vazio aparece assim mesmo, e nao escondido: o jogador
## precisa ver que ha tres e que dois estao livres.
func _espacos() -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for i in SaveGame.ESPACOS:
		var n := i
		var existe := SaveGame.existe(n)
		var resumo := SaveGame.resumo(n) if existe else {}
		var rotulo := "ESPACO %d" % (n + 1)
		var valor := "VAZIO"
		if existe:
			valor = String(resumo.get("local", "")).to_upper()
			if valor.is_empty():
				valor = "GRAVADO"
		saida.append({
			"rotulo": rotulo,
			"ler": func() -> String: return valor,
			"acionar": func() -> void:
				if not existe:
					AudioDirector.tocar_ui(&"clique", -18.0)
					return
				fechar()
				carregou.emit(n),
			"vivo": existe,
		})
	saida.append(_voltar())
	return saida


func _acao(rotulo: String, quando: Callable, vivo: bool = true) -> Dictionary:
	return {
		"rotulo": rotulo,
		"ler": func() -> String: return "",
		"acionar": quando,
		"vivo": vivo,
	}


func _voltar() -> Dictionary:
	return _acao("VOLTAR", func() -> void:
		if pagina == Pagina.RAIZ:
			fechar()
		else:
			_ir_para(Pagina.RAIZ))


# --- entrada ----------------------------------------------------------------

## Devolve `true` quando consumiu o evento. Quem chama e a prancha: ela precisa
## saber se o evento ainda e dela.
func tratar(evento: InputEvent) -> bool:
	if not aberto:
		return false
	if evento.is_action_pressed("mover_frente") or evento.is_action_pressed("ui_up"):
		_andar(-1)
	elif evento.is_action_pressed("mover_tras") or evento.is_action_pressed("ui_down"):
		_andar(1)
	elif evento.is_action_pressed("mover_esq"):
		_ajustar(-1)
	elif evento.is_action_pressed("mover_dir"):
		_ajustar(1)
	elif evento.is_action_pressed("interagir") or evento.is_action_pressed("ui_accept"):
		_acionar()
	elif evento.is_action_pressed("examinar") or evento.is_action_pressed("pausa"):
		if pagina == Pagina.RAIZ:
			fechar()
		else:
			_ir_para(Pagina.RAIZ)
	else:
		return false
	return true


func _andar(passo: int) -> void:
	if _itens.is_empty():
		return
	_sel = posmod(_sel + passo, _itens.size())
	AudioDirector.tocar_ui(&"clique", -18.0)
	queue_redraw()


## A/D so mexem em quem tem valor para ajustar. Numa linha de acao eles nao
## fazem nada — e nao fazer nada e melhor que rolar a lista de lado, que e o que
## o jogador teria de desaprender depois.
func _ajustar(passo: int) -> void:
	if _sel >= _itens.size():
		return
	var item := _itens[_sel]
	if not item.has("aplicar"):
		return
	var aplicar: Callable = item["aplicar"]
	aplicar.call(passo)
	AudioDirector.tocar_ui(&"clique", -20.0)
	queue_redraw()


func _acionar() -> void:
	if _sel >= _itens.size():
		return
	var item := _itens[_sel]
	if item.has("acionar"):
		AudioDirector.tocar_ui(&"pegar", -14.0)
		var quando: Callable = item["acionar"]
		quando.call()
		queue_redraw()
		return
	# Linha de ajuste: E vale como "para a direita", para quem nao descobriu A/D.
	_ajustar(1)


# --- desenho ----------------------------------------------------------------

## Altura que a folha precisa ter para o que esta dentro dela.
func _altura() -> float:
	# titulo + regua + linhas + dica, mais o respiro de cima e o de baixo.
	return PAD + _linha + 4.0 + 1.0 + _linha + VAO 		+ float(_itens.size()) * (_linha + VAO) 		+ _linha + PAD - 4.0


func _folha() -> Rect2:
	return Rect2(FOLHA_X, FOLHA_Y, FOLHA_L, _altura())


func _draw() -> void:
	if not aberto:
		return
	var folha := _folha()
	# Veu sobre a prancha. Fraco: a bolsa continua legivel atras, e e ela que
	# diz ao jogador que ele nao saiu do inventario.
	draw_rect(Rect2(Vector2.ZERO, UiEstilo.TELA), Color(0.02, 0.02, 0.03, 0.55))

	draw_rect(Rect2(folha.position + Vector2(2.0, 2.0), folha.size),
		UiEstilo.PAPEL_SOMBRA)
	draw_rect(folha, Color("e6dfc4"))
	draw_rect(folha, UiEstilo.TINTA, false, UiEstilo.PAPEL_BORDA)

	var nomes: Array[String] = ["OPCOES", "IMAGEM", "SOM", "CARREGAR"]
	var titulo: String = nomes[int(pagina)]
	var y := folha.position.y + PAD + _linha
	_texto(titulo, Vector2(folha.position.x + PAD, y), UiEstilo.TINTA_TITULO)
	y += 4.0
	draw_rect(Rect2(folha.position.x + PAD, y, folha.size.x - PAD * 2.0, 1.0),
		UiEstilo.TINTA_FRACA)
	y += _linha + VAO

	for i in _itens.size():
		var item := _itens[i]
		var ativo := i == _sel
		var vivo := bool(item.get("vivo", true))
		var cor := UiEstilo.TINTA
		if ativo:
			cor = UiEstilo.DESTAQUE
		elif not vivo:
			cor = Color(0.55, 0.50, 0.42)
		if ativo:
			draw_rect(Rect2(folha.position.x + PAD - 4.0, y - _linha + 3.0,
				folha.size.x - PAD * 2.0 + 8.0, _linha), Color(0.0, 0.0, 0.0, 0.07))
			_texto(">", Vector2(folha.position.x + PAD - 7.0, y), cor)
		var rotulo := String(item["rotulo"])
		_texto(rotulo, Vector2(folha.position.x + PAD, y), cor)
		var ler: Callable = item["ler"]
		var valor := String(ler.call())
		if not valor.is_empty():
			# O valor e cortado no que SOBRA depois do rotulo, e nao na largura
			# da folha. Sem isto "ESPACO 1" e "TELEFONE DA RUA 5-3" se escreviam
			# um por cima do outro — a mesma colisao de duas colunas no mesmo
			# retangulo que derrubou o cartao de missao, agora aqui.
			var sobra := folha.size.x - PAD * 2.0 				- UiEstilo.largura(_fonte, rotulo) - 8.0
			valor = UiEstilo.encurtar(_fonte, valor, maxf(sobra, 12.0))
			var w := UiEstilo.largura(_fonte, valor)
			_texto(valor, Vector2(folha.end.x - PAD - w, y),
				cor if ativo else UiEstilo.TINTA_FRACA)
		y += _linha + VAO

	# A dica muda com a pagina: numa lista de acoes nao ha o que ajustar, e
	# oferecer [A/D] ali e prometer uma tecla que nao faz nada.
	var dica := "[W/S] mover   [E] escolher"
	if pagina == Pagina.VIDEO or pagina == Pagina.AUDIO:
		dica = "[A/D] ajustar   [Q] voltar"
	_texto(UiEstilo.encurtar(_fonte, dica, folha.size.x - PAD * 2.0),
		Vector2(folha.position.x + PAD, folha.end.y - PAD + 3.0),
		UiEstilo.TINTA_FRACA)



## Os tres pauzinhos ficam visiveis com a prancha aberta, mesmo com o painel
## fechado — e o que diz que ha um menu ali. Acesos quando ele esta aberto.
func _desenhar_pauzinhos() -> void:
	# Placa escura por baixo, barras claras por cima.
	#
	# A primeira versao pintava as barras em DESTAQUE quando o menu estava aberto
	# — e DESTAQUE e um oxblood escuro. No canto de cima da direita da prancha o
	# fundo tambem e escuro, entao o convite ficava invisivel exatamente onde ele
	# precisa ser visto. Cor nao resolve contraste sozinha; valor resolve.
	# Aba CLARA com barras escuras, e nao placa escura com barras claras.
	#
	# O canto de cima da direita e o ponto mais fechado da vinheta do pos: uma
	# placa escura ali vira preto sobre preto. Uma aba clara e escurecida pela
	# vinheta ate cinza medio, que ainda le. Medido em
	# `captures/ui/_zoom_pauzinhos.png`.
	#
	# E aba de papel com barras de tinta e o vocabulario da prancha inteira.
	if _aba == null:
		return
	var placa := Rect2(PAUZINHOS.position, PAUZINHOS.size).grow(4.0)
	_aba.draw_rect(Rect2(placa.position + Vector2(1.0, 1.0), placa.size),
		UiEstilo.PAPEL_SOMBRA)
	_aba.draw_rect(placa, Color("e6dfc4") if not aberto else Color("f4e7cc"))
	_aba.draw_rect(placa, UiEstilo.TINTA, false, 1.0)
	var cor := UiEstilo.DESTAQUE if aberto else UiEstilo.TINTA
	for i in 3:
		_aba.draw_rect(Rect2(PAUZINHOS.position.x,
			PAUZINHOS.position.y + float(i) * 5.0, PAUZINHOS.size.x, 3.0), cor)


func _texto(s: String, onde: Vector2, cor: Color) -> void:
	draw_string(_fonte, onde, s, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		UiEstilo.tamanho_nativo(_fonte), cor)
