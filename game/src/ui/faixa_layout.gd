## Onde cada coisa da faixa de estado fica. Funcao pura, sem Node e sem cena.
##
## Mesmo contrato de `CartaoLayout`: quem desenha, quem mede e quem um dia for
## desenhar isto noutro lugar consultam a MESMA resposta.
##
## Por que a faixa fica no rodape, centrada, e nao num canto
## --------------------------------------------------------
## Porque foi medido. A vinheta de `post_psx.gdshader` multiplica a cor por
## `smoothstep(0.95, 0.95 - 0.45, |uv - 0.5| * 1.35)`. Nos quatro cantos exatos
## da tela isso da ZERO, e a 7 px do canto — a margem que o resto da interface
## usa — da 0,019. Papel de luminancia 247 chega a 4. O canto, na camada 100, e
## um lugar onde nao existe cor legivel.
##
## Isso nao e teoria: o menu de sistema perdeu tres capturas culpando cor antes
## de a medida nomear o culpado, e so ficou visivel ao subir para a camada 160.
## Subir de camada resolve e cobra: `minimapa.gd:3` explica por que interface
## nitida por cima de cena suja denuncia na hora que e camada moderna colada num
## jogo que finge ser de 1999. O cartao de missao e o minimapa pagam esse preco
## ficando na 100/101 e aceitando que a propria quina do papel escurece.
##
## A faixa nao tem quina sobrando para perder. Entao ela anda para dentro: no
## meio do rodape o fator e 0,777, e ate `LARGURA_MAX` de largura nenhum canto
## do texto cai abaixo de `UiEstilo.VINHETA_MIN`. `tests/checar_hud.gd` mede isso
## em todos os casos, inclusive nos piores nomes de distrito.
class_name FaixaLayout
extends RefCounted

## Largura maxima do papel.
##
## Sai da conta, nao do gosto: com o papel centrado, o canto inferior do texto
## fica em y = 261. A 264 de largura o canto cai em x = 108, onde a vinheta da
## 0,45 — exatamente o piso. Um pixel mais largo e o texto comeca a apagar.
const LARGURA_MAX := 264.0

## Altura do papel: uma linha de `psx_pequena` (13) mais 1 px de folga em cima e
## em baixo. Duas linhas nao cabem sem empurrar o canto inferior para fora do
## piso de vinheta.
const PAD_Y := 1.0

## Lado do icone da lanterna. 9 e impar de proposito: o feixe sai do centro.
const ICONE := 9.0

## Barra de vida. 40x5 le como barra e nao come a linha inteira.
const BARRA := Vector2(40.0, 5.0)

## Espaco entre o grupo de estado (lanterna, vida) e o grupo de texto
## (lugar, hora). E onde entra a regua vertical.
const REGUA := 1.0

## Vao entre o papel da faixa e o papel do prompt. Dois papeis colados leem como
## um so, e o prompt tem de ler como coisa que aparece e some.
const VAO_PROMPT := 3.0


## `dados` aceita:
##   lugar: String          nome do distrito ou do comodo
##   hora: String           "HH:MM"
##   vida: float            0..1; so entra em cena se `com_vida`
##   com_vida: bool
##   com_lanterna: bool
##   lanterna: bool         ligada ou nao (muda cor, nao muda layout)
##
## Devolve `{papel: Rect2, caixas: Array[Dictionary]}`. Cada caixa e
## `{nome, rect, texto, alinhamento}` — `texto` vazio quer dizer desenho, nao
## escrita (icone, barra, regua).
static func montar(fonte: Font, dados: Dictionary) -> Dictionary:
	var linha := UiEstilo.altura_da_linha(fonte)
	var altura := linha + PAD_Y * 2.0

	var com_lanterna := bool(dados.get("com_lanterna", false))
	var com_vida := bool(dados.get("com_vida", false))
	var hora := String(dados.get("hora", ""))
	var lugar := String(dados.get("lugar", ""))

	# 1. Largura fixa do lado esquerdo (estado) e do canto direito (hora).
	var estado := 0.0
	if com_lanterna:
		estado += ICONE
	if com_vida:
		estado += (UiEstilo.GAP if estado > 0.0 else 0.0) + BARRA.x
	if estado > 0.0:
		estado += UiEstilo.GAP_BLOCO + REGUA + UiEstilo.GAP_BLOCO

	var w_hora := UiEstilo.largura(fonte, hora)
	if not hora.is_empty():
		w_hora += UiEstilo.GAP_BLOCO

	# 2. O lugar recebe o que sobrar, e encolhe se nao couber. E o unico texto de
	#    tamanho imprevisivel aqui: "PRAÇA DA MATRIZ" e "VILA SANTO ANTONIO DO
	#    MONTE" cabem na mesma faixa porque o segundo vira reticencias.
	var sobra := LARGURA_MAX - UiEstilo.PAD * 2.0 - estado - w_hora
	var lugar_cortado := UiEstilo.encurtar(fonte, lugar, maxf(0.0, sobra))
	var w_lugar := UiEstilo.largura(fonte, lugar_cortado)

	var util := estado + w_lugar + w_hora
	var largura := minf(LARGURA_MAX, util + UiEstilo.PAD * 2.0)

	var papel := Rect2(
		roundf((UiEstilo.TELA.x - largura) * 0.5),
		UiEstilo.TELA.y - UiEstilo.MARGEM - altura,
		largura, altura)

	# 3. Empilhamento da esquerda para a direita. Cada caixa comeca onde a
	#    anterior acabou; nenhuma posicao e escrita duas vezes.
	var caixas: Array[Dictionary] = []
	var x := papel.position.x + UiEstilo.PAD
	var meio := papel.position.y + altura * 0.5

	if com_lanterna:
		caixas.append(_caixa("lanterna", Rect2(x, meio - ICONE * 0.5, ICONE, ICONE)))
		x += ICONE
	if com_vida:
		if com_lanterna:
			x += UiEstilo.GAP
		caixas.append(_caixa("vida", Rect2(x, meio - BARRA.y * 0.5, BARRA.x, BARRA.y)))
		x += BARRA.x
	if estado > 0.0:
		x += UiEstilo.GAP_BLOCO
		caixas.append(_caixa("regua",
			Rect2(x, papel.position.y + 2.0, REGUA, altura - 4.0)))
		x += REGUA + UiEstilo.GAP_BLOCO

	caixas.append(_caixa("lugar",
		Rect2(x, papel.position.y + PAD_Y, w_lugar, linha), lugar_cortado))
	x += w_lugar

	if not hora.is_empty():
		x += UiEstilo.GAP_BLOCO
		caixas.append(_caixa("hora",
			Rect2(x, papel.position.y + PAD_Y, w_hora - UiEstilo.GAP_BLOCO, linha),
			hora, HORIZONTAL_ALIGNMENT_RIGHT))

	return {"papel": papel, "caixas": caixas}


static func _caixa(nome: String, r: Rect2, texto: String = "",
		alinhamento: int = HORIZONTAL_ALIGNMENT_LEFT) -> Dictionary:
	return {
		"nome": nome,
		"rect": r,
		"texto": texto,
		"alinhamento": alinhamento,
	}


## O aviso de "[E] alguma coisa", logo acima da faixa.
##
## Por que ele subiu
## -----------------
## Porque estava em y 236..254, e a faixa ocupa 248..263: as duas pecas nasceram
## em anos diferentes mirando o mesmo rodape e ninguem tinha medido. O mesmo tipo
## de colisao que o cartao de missao tinha com a distancia.
##
## Devolve papel vazio quando nao ha texto — prompt permanente vira ruido, e o
## jogador para de ler.
static func prompt(fonte: Font, texto: String) -> Dictionary:
	if texto.is_empty():
		return {"papel": Rect2(), "texto": Rect2()}
	var linha := UiEstilo.altura_da_linha(fonte)
	var altura := linha + PAD_Y * 2.0
	var cortado := UiEstilo.encurtar(fonte, texto,
		LARGURA_MAX - UiEstilo.PAD * 2.0)
	var w := UiEstilo.largura(fonte, cortado)
	var largura := w + UiEstilo.PAD * 2.0
	# A faixa fica sempre embaixo; o prompt encosta o proprio rodape no topo dela.
	var base := UiEstilo.TELA.y - UiEstilo.MARGEM - (linha + PAD_Y * 2.0) - VAO_PROMPT
	var papel := Rect2(roundf((UiEstilo.TELA.x - largura) * 0.5), base - altura,
		largura, altura)
	return {
		"papel": papel,
		"texto": Rect2(papel.position + Vector2(UiEstilo.PAD, PAD_Y), Vector2(w, linha)),
		"cortado": cortado,
	}
