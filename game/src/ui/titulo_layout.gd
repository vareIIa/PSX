## O empilhamento da tela de titulo, como funcao pura.
##
## Por que isto saiu de `menu.gd`
## ------------------------------
## Porque o `PLANO_UI_AAA` deixou uma pendencia escrita na Fase 7: *"checar_hud.gd
## cobre o CartaoLayout e nao o menu de titulo. A lista passou de 7 para 11
## linhas e a ultima transbordou o papel em 3 px — a captura pegou, o teste nao
## pegaria."* Para o teste pegar, a regra precisa morar onde o teste alcanca.
##
## E `menu.gd` nao alcanca. Ele e uma `CanvasLayer` que fala com `Settings`,
## `AudioDirector`, `SaveGame` e `RegistroCivil` — quatro autoloads — e monta um
## `SubViewport` com estrada, mata e serra. Um teste de nivel 2 roda sem
## SceneTree e sem autoload nenhum; pedir a ele que instancie o menu para medir
## onde cai um retangulo e pedir que ele monte a Estrada Velha inteira.
##
## Mesmo contrato de `CartaoLayout` e `FaixaLayout`: `RefCounted`, sem `Node`,
## sem autoload, tudo estatico. Uma fonte, dois leitores — o menu desenha a
## partir daqui e o teste mede a partir daqui.
class_name TituloLayout
extends RefCounted

## Resolucao interna. ART-BIBLE secao 2.
const TELA := Vector2(480.0, 270.0)

# --- o titulo ---------------------------------------------------------------

## O nome do jogo e desenhado em serif de 42, e o MESMO rotulo aparece nas duas
## telas: no boot, no meio do quadro; no menu, pousado no alto. A transicao do
## START leva um ao outro por tween, e e por isso que os dois lugares moram lado
## a lado aqui — sao as duas pontas de um movimento, e nao dois layouts.
const TITULO_CORPO := 42
const TITULO_CAIXA := Vector2(440.0, 48.0)
const TITULO_ONDE_BOOT := Vector2(20.0, 74.0)
## Medido na captura de 1920x1080 (escala 4x): com 42 de corpo e o estica
## vertical de 1,38 da `FontVariation`, a letra ocupa cerca de 40 px a partir do
## topo da caixa. Em 20 ela deixa 16 px de respiro no alto e abre espaco para o
## subtitulo e cinco itens embaixo.
const TITULO_ONDE_MENU := Vector2(20.0, 20.0)

## O subtitulo desce a partir da CAIXA do titulo, e nao de um y absoluto. Mover o
## titulo move a linha de baixo junto — que e o unico jeito de as duas nao se
## afastarem no primeiro ajuste.
const SUBTITULO_DESCE := 52.0
const SUBTITULO_TEXTO := "suburbio · nevoa · madrugada"
const SUBTITULO_CAIXA := Vector2(400.0, 14.0)

# --- a lista ----------------------------------------------------------------

## Os itens do titulo, na ordem em que aparecem. O teste mede a partir DELA: uma
## lista reescrita no teste mediria um menu que nao existe.
##
## CARREGAR entrou em 16/09/2026. Havia TRES espacos de save com resumo pronto em
## `SaveGame.resumo()` e so o menu de sistema em jogo chegava neles — quem abria
## o jogo alcancava o espaco 0 e mais nada.
const ITENS: Array[String] = ["CONTINUAR", "CARREGAR", "NOVO JOGO", "MAPA",
	"OPCOES", "SAIR"]

## Os itens da pagina de espacos de save. O ultimo e a saida; os tres primeiros
## sao rotulos fixos, e o que varia (local, hora) vai na nota embaixo da lista.
const ESPACOS: Array[String] = ["ESPACO 1", "ESPACO 2", "ESPACO 3", "VOLTAR"]

## O empilhamento da lista sai do CONTEUDO, e nao de um `y` cravado.
##
## Isto mudou quando a lista passou de cinco itens para seis. Com passo fixo de
## 24 a partir de 96, o sexto item terminava em 234 e a nota que explica o item
## apagado nao tinha onde caber — a mesma classe de defeito que o papel de opcoes
## ja teve duas vezes, e que `menu.gd` conserta derivando o passo. A lista agora
## se aperta sozinha para caber entre o subtitulo e a nota; abaixo de `PASSO_MIN`
## os itens leem como um bloco unico, e ai o aviso e para dividir a tela, nao
## para apertar mais.
const TOPO_LISTA := 92.0
const ITEM_ALTURA := 18.0
const PASSO_MAX := 24.0
const PASSO_MIN := 20.0
## Respiro de cada lado do texto dentro da placa.
const ITEM_PAD := 26.0
## A placa e 2 px mais alta que o texto em cima e em baixo.
const PLACA_FOLGA := 2.0

## A linha de teclas do rodape.
const DICA_Y := TELA.y - 22.0
const DICA_ALTURA := 14.0
const DICA_TEXTO := "[W/S] mover   [E] escolher   [clique] tambem vale"

## A nota que explica o item escolhido: por que CONTINUAR esta apagado, o que ha
## num espaco de save. Mora entre a lista e a linha de teclas.
const NOTA_ALTURA := 13.0
const NOTA_RESPIRO := 4.0


## Onde a lista tem de acabar: logo acima da nota.
static func fundo_da_lista() -> float:
	return DICA_Y - NOTA_RESPIRO - NOTA_ALTURA


## O passo entre dois itens, para uma lista de `n`.
static func passo(n: int) -> float:
	if n <= 1:
		return PASSO_MAX
	var cabe := (fundo_da_lista() - TOPO_LISTA - ITEM_ALTURA) / float(n - 1)
	return clampf(cabe, PASSO_MIN, PASSO_MAX)


## Largura da placa: a do item mais largo, medida na fonte de verdade.
##
## Era 200 px cravados contra um texto que nunca foi medido. Dois problemas
## moram num numero desses: ele nao sabe que "CONTINUAR" e "SAIR" tem larguras
## diferentes, e nao sobrevive a uma entrada nova — no dia em que o menu ganhar
## "CARREGAR", a placa continua com 200 e o texto sai por fora ou nada num vao.
##
## `UiEstilo.largura` mede no motor, no tamanho nativo da fonte. UI-BIBLE secao
## 2: contar caractere por `xadvance` do `.fnt` erra, e essa conta manual ja
## custou o layout do cartao de missao.
static func largura_da_placa(fonte: Font, entradas: Array = ITENS) -> float:
	if fonte == null:
		return 200.0
	var maior := 0.0
	for texto: String in entradas:
		maior = maxf(maior, UiEstilo.largura(fonte, texto))
	return minf(TELA.x - 2.0 * UiEstilo.MARGEM, ceilf(maior) + 2.0 * ITEM_PAD)


## O retangulo da placa do item `i` numa lista de `n`, centrado na tela.
static func placa(i: int, largura: float, n: int = ITENS.size()) -> Rect2:
	var caixa := texto(i, largura, n)
	return Rect2(caixa.position.x, caixa.position.y - PLACA_FOLGA,
		largura, ITEM_ALTURA + PLACA_FOLGA * 2.0)


## A caixa do texto do item `i` — a mesma largura da placa, sem a folga.
static func texto(i: int, largura: float, n: int = ITENS.size()) -> Rect2:
	return Rect2((TELA.x - largura) * 0.5,
		TOPO_LISTA + float(i) * passo(n), largura, ITEM_ALTURA)


## A caixa da nota que explica o item escolhido.
##
## Ela para na area segura e nao na borda da tela. Rodape centralizado com caixa
## de tela cheia funciona ate a primeira string comprida, e ai a ponta do texto
## cai no raio da vinheta — onde o pos multiplica por quase zero (UI-BIBLE 3.1).
static func nota() -> Rect2:
	return Rect2(UiEstilo.MARGEM, fundo_da_lista() + NOTA_RESPIRO,
		TELA.x - 2.0 * UiEstilo.MARGEM, NOTA_ALTURA)


## A caixa do titulo na tela de menu.
static func titulo() -> Rect2:
	return Rect2(TITULO_ONDE_MENU, TITULO_CAIXA)


## A caixa do subtitulo, derivada da do titulo.
static func subtitulo() -> Rect2:
	return Rect2((TELA.x - SUBTITULO_CAIXA.x) * 0.5,
		TITULO_ONDE_MENU.y + SUBTITULO_DESCE, SUBTITULO_CAIXA.x, SUBTITULO_CAIXA.y)


## A caixa da linha de teclas. Mesma regra da nota.
static func dica() -> Rect2:
	return Rect2(UiEstilo.MARGEM, DICA_Y, TELA.x - 2.0 * UiEstilo.MARGEM, DICA_ALTURA)
