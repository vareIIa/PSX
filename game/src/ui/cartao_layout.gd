## Onde cada coisa do cartao de missao fica. Funcao pura, sem Node e sem cena.
##
## Por que o layout mora fora do HUD
## --------------------------------
## Pelo mesmo motivo de `MalhaUrbana` decidir onde passa rua sem gerar um
## vertice: assim tres lugares que nunca se falam consultam a MESMA resposta — o
## HUD que desenha, a verificacao automatizada que mede, e quem um dia for
## desenhar este cartao noutro lugar.
##
## A alternativa era o que existia: o empilhamento escrito no meio do `_ready` do
## `CanvasLayer`, onde so da para conferir abrindo o jogo e olhando. E olhar nao
## encontra colisao de 3 px que so aparece com titulo comprido — foi assim que o
## cartao passou a vida com o titulo escrevendo por cima da distancia.
##
## Nada aqui toca autoload. `tests/checar_hud.gd` mede este arquivo em
## milissegundos, sem montar cidade, sem carregar chunk e sem abrir janela.
class_name CartaoLayout
extends RefCounted

## Largura do papel. O minimapa do outro canto tem 82; 186 e o que sobra para
## uma linha de objetivo caber sem quebrar na maioria das etapas.
const LARGURA := 186.0
## Largura util, de dentro das duas margens do papel.
const UTIL := LARGURA - UiEstilo.PAD * 2.0

## Coluna da direita da primeira linha, onde mora "1/2". Reservada: e o que
## impede o titulo de crescer por cima dela.
const COL_ETAPA := 26.0
## Vao entre a coluna do titulo e a da etapa. Sem ele as duas se encostam e leem
## como uma palavra so.
const COL_VAO := 6.0
## Largura do titulo, ja descontada a coluna reservada da etapa.
const COL_TITULO := UTIL - COL_ETAPA - COL_VAO

## Lado da bussola do rodape. Quadrada, do tamanho de uma linha de texto.
const BUSSOLA := 11.0
## Vao entre a bussola e o numero da distancia.
const BUSSOLA_VAO := 4.0

## Teto de linhas. Acima disto o cartao viraria paragrafo no canto da tela: o
## texto e encurtado e o resto continua no GPS, que e onde cabe.
const MAX_LINHAS_OBJETIVO := 3
const MAX_LINHAS_DICA := 2


## Resolve o cartao inteiro.
##
## `dados` aceita as chaves `titulo`, `etapa`, `objetivo`, `dica` e `distancia`,
## todas String e todas opcionais. Campo vazio nao vira caixa vazia: ele nao vira
## caixa nenhuma, e o que vem depois sobe. Um retangulo de altura zero passaria
## em qualquer teste de colisao e ainda assim deixaria um buraco no papel.
##
## Devolve `{"papel": Rect2, "caixas": Array[Dictionary]}`, onde cada caixa e
## `{"nome": String, "linhas": PackedStringArray, "rect": Rect2, "alinhamento": int}`.
## O retangulo e relativo ao canto de cima da esquerda do papel.
static func montar(fonte: Font, dados: Dictionary, com_dica: bool) -> Dictionary:
	var linha := UiEstilo.altura_da_linha(fonte)
	var caixas: Array[Dictionary] = []
	# O papel comeca com meia entrelinha de respiro em vez de PAD cheio: a fonte
	# de bitmap ja carrega um pixel de folga acima do maiusculo.
	var y := UiEstilo.PAD - 2.0

	var titulo := UiEstilo.encurtar(fonte,
		String(dados.get("titulo", "")).to_upper(), COL_TITULO)
	var etapa := String(dados.get("etapa", ""))
	if not titulo.is_empty() or not etapa.is_empty():
		if not titulo.is_empty():
			caixas.append(_caixa("titulo", [titulo],
				Rect2(UiEstilo.PAD, y, COL_TITULO, linha)))
		if not etapa.is_empty():
			caixas.append(_caixa("etapa", [etapa],
				Rect2(UiEstilo.PAD + COL_TITULO + COL_VAO, y, COL_ETAPA, linha),
				HORIZONTAL_ALIGNMENT_RIGHT))
		y += linha + 1.0
		# Regua fina sob o cabecalho, como o sublinhado da prancha. Separa o que
		# a missao E do que ela PEDE — sem ela as duas primeiras linhas leem como
		# um paragrafo so, que e metade da queixa de "cartao seco".
		caixas.append(_caixa("regua", [], Rect2(UiEstilo.PAD, y, UTIL, 1.0)))
		y += 1.0 + UiEstilo.GAP

	var objetivo := _dobrar(fonte, String(dados.get("objetivo", "")), UTIL,
		MAX_LINHAS_OBJETIVO)
	if objetivo.size() > 0:
		caixas.append(_caixa("objetivo", objetivo,
			Rect2(UiEstilo.PAD, y, UTIL, float(objetivo.size()) * linha)))
		y += float(objetivo.size()) * linha + UiEstilo.GAP_BLOCO

	if com_dica:
		var dica := _dobrar(fonte, String(dados.get("dica", "")), UTIL,
			MAX_LINHAS_DICA)
		if dica.size() > 0:
			caixas.append(_caixa("dica", dica,
				Rect2(UiEstilo.PAD, y, UTIL, float(dica.size()) * linha)))
			y += float(dica.size()) * linha + UiEstilo.GAP_BLOCO

	# Rodape: bussola a esquerda, distancia a direita, em colunas separadas. A
	# distancia troca de largura a cada passo do jogador ("9 M" vira "1.2 KM"),
	# e foi por dividir retangulo com o titulo que ela escrevia por cima dele.
	var distancia := String(dados.get("distancia", ""))
	if not distancia.is_empty():
		caixas.append(_caixa("bussola", [],
			Rect2(UiEstilo.PAD, y + (linha - BUSSOLA) * 0.5, BUSSOLA, BUSSOLA)))
		caixas.append(_caixa("distancia", [distancia],
			Rect2(UiEstilo.PAD + BUSSOLA + BUSSOLA_VAO, y,
				UTIL - BUSSOLA - BUSSOLA_VAO, linha),
			HORIZONTAL_ALIGNMENT_RIGHT))
		y += linha

	return {
		"papel": Rect2(0.0, 0.0, LARGURA, y + UiEstilo.PAD - 2.0),
		"caixas": caixas,
	}


static func _caixa(nome: String, linhas: Array, r: Rect2,
		alinhamento: int = HORIZONTAL_ALIGNMENT_LEFT) -> Dictionary:
	var p := PackedStringArray()
	for l: String in linhas:
		p.append(l)
	return {"nome": nome, "linhas": p, "rect": r, "alinhamento": alinhamento}


## Quebra o texto e corta no teto de linhas, marcando o corte.
static func _dobrar(fonte: Font, texto: String, largura: float,
		max_linhas: int) -> PackedStringArray:
	var linhas := UiEstilo.quebrar(fonte, texto, largura)
	if linhas.size() <= max_linhas:
		return linhas
	var cortado := PackedStringArray()
	for i in max_linhas:
		cortado.append(linhas[i])
	# A ultima linha que cabe leva a reticencia. O texto inteiro continua no GPS.
	cortado[max_linhas - 1] = UiEstilo.encurtar(fonte,
		String(cortado[max_linhas - 1]) + " ...", largura)
	return cortado
