## A folha de OPCOES: onde cada linha de ajuste cai dentro do papel.
##
## Por que ela entra na regua agora
## --------------------------------
## Porque era a quarta tela do menu e a unica que ainda nao tinha sido medida.
## O `PLANO_MENU_AAA.md` registrou isso como divida na entrega anterior: *"a tela
## de OPCOES nao foi tocada. Ela continua no vocabulario de papel, com 11 linhas
## e o passo derivado a mao, e nao passou pela regua nova."*
##
## O passo JA era derivado do espaco disponivel — isso `menu.gd` tinha acertado
## depois de estourar a folha duas vezes. O que faltava era o resto do contrato:
## as duas colunas nunca foram medidas contra o texto que cabe nelas, e ninguem
## sabia se "NEBLINA COM CHUVA" ou "PERSONALIZADO" saiam por fora da coluna de
## valor. Agora as medidas moram aqui e `tests/checar_hud.gd` mede.
##
## Mesmo contrato de `CartaoLayout`, `TituloLayout` e `CarteiraLayout`.
class_name OpcoesLayout
extends RefCounted

const TELA := Vector2(480.0, 270.0)

## O papel, e o creme onde da para escrever dentro dele.
##
## `CREME_BASE` foi MEDIDO na captura e nao lido do retangulo: `ui_papel` tem
## moldura, e o creme acaba dez pixels antes da borda da imagem. Medir o
## retangulo era o erro que cortava a ultima linha.
const PAPEL := Rect2(48.0, 22.0, 384.0, 216.0)
const CREME_TOPO := 43.1
const CREME_BASE := 228.4

## Onde a primeira linha comeca e o maior passo aceitavel.
##
## O teto era 13,5 — meio pixel de ar sobre uma linha de 13. Ele nao foi
## escolhido: foi o que sobrou quando treze linhas tinham de caber numa folha que
## comporta dez. Com a lista paginada, o passo volta a ser uma decisao de leitura
## e nao um resto de divisao: 16 px da tres pixels de ar entre linhas, que e o
## mesmo respiro que o cartao de missao usa entre blocos (UI-BIBLE secao 2).
const Y0 := 58.0
const PASSO_MAX := 16.0
## Altura da LINHA da `psx_pequena`, que e 13 — e nao 11.
##
## Aqui morava o defeito que sobreviveu a dois consertos. O `fixed_size` da fonte
## e 11, e era esse numero que a conta do passo reservava para a ultima linha;
## a ALTURA DE LINHA medida no motor e 13 (`tests/medir_fonte.gd`). Dois pixels
## de diferenca vezes a ultima linha e exatamente o "VOLTAR entrou 2,6 px na
## moldura" que o arquivo ja tinha registrado — e que foi corrigido mexendo no
## passo em vez de na reserva, o que apenas adiou.
##
## `checar_hud.gd` compara esta constante com a altura real da fonte, para as
## duas nunca mais divergirem em silencio.
const LINHA := 13.0
## Um pixel de respiro entre a ultima linha e a moldura. Sem ele o limite bate
## exato, e "exato" em ponto flutuante e uma reprovacao aleatoria.
const RESPIRO := 1.0

## As duas colunas: rotulo a esquerda, valor a direita.
##
## Elas nao se tocam por 4 px. Medido: o rotulo mais largo da lista e
## "RESOLUCAO 3D" e o valor mais largo e "NEBLINA COM CHUVA" — os dois cabem,
## mas com folga pequena o bastante para valer uma assercao em vez de confianca.
const ROTULO_X := 74.0
const ROTULO_L := 150.0
const VALOR_X := 228.0
const VALOR_L := 180.0

## O rodape de teclas da folha.
const DICA_Y := TELA.y - 22.0
const DICA_ALTURA := 16.0
const DICA_TEXTO := "[W/S] mover    [A/D] ajustar    [ESC] voltar"


## O passo entre duas linhas, para uma lista de `n`.
##
## Sai do espaco que sobra, e nao de um numero cravado: duas vezes seguidas a
## lista estourou a folha e duas vezes o conserto foi um passo novo no codigo,
## que envelhece na proxima linha que alguem adicionar. Derivando, a lista aperta
## as anteriores em vez de cair para fora.
static func passo(n: int) -> float:
	var linhas := maxf(1.0, float(n - 1))
	return minf(PASSO_MAX, (CREME_BASE - LINHA - RESPIRO - Y0) / linhas)


## Cabe sem apertar mais do que a propria fonte?
##
## Abaixo da altura da linha o texto passa a se sobrepor, e ai a saida nao e
## apertar: e duas colunas, ou rolagem. O aviso existe para essa decisao ser
## tomada por alguem, e nao acontecer sozinha.
static func cabe(n: int) -> bool:
	return passo(n) >= LINHA + 1.0


## A caixa do rotulo da linha `i`.
static func rotulo(i: int, n: int) -> Rect2:
	return Rect2(ROTULO_X, Y0 + float(i) * passo(n), ROTULO_L, 14.0)


## A caixa do valor da linha `i`.
static func valor(i: int, n: int) -> Rect2:
	return Rect2(VALOR_X, Y0 + float(i) * passo(n), VALOR_L, 14.0)


## A caixa da linha de teclas.
static func dica() -> Rect2:
	return Rect2(UiEstilo.MARGEM, DICA_Y, TELA.x - 2.0 * UiEstilo.MARGEM, DICA_ALTURA)
