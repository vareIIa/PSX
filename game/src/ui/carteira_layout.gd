## A geometria da carteira de identidade da criacao de personagem.
##
## Por que isto saiu de `criacao.gd`
## ---------------------------------
## Pelo mesmo motivo de `TituloLayout` e de `CartaoLayout`: a regra precisa ser
## mensuravel sem abrir a tela. `criacao.gd` fala com `RegistroCivil`,
## `AudioDirector` e `Aparencia`, monta um `SubViewport` com retrato 3D e outro
## com a cabine do carro — nada disso existe num teste de nivel 2, e sem teste
## esta tela ja provou que se quebra em silencio.
##
## O defeito que motivou a separacao
## ---------------------------------
## A aba AGASALHO tem tres campos e a coluna so tinha espaco para dois. O
## resultado, medido na captura: o rotulo MODELO impresso dez pixels DENTRO do
## botao SEM, e a fileira de cores desenhada por cima da zona de leitura do
## rodape. As outras seis abas nao mostravam nada disso, entao olhar a tela so
## encontrava o defeito com a aba certa aberta na hora certa.
##
## A causa raiz nao era falta de espaco: era que o DESENHO e a ALTURA da linha
## eram numeros independentes. Cada widget era posicionado com um offset solto
## dentro do proprio ramo do `match`, e o passo da linha era 22, 26 ou 32
## escolhidos a mao. Aqui os dois saem da mesma tabela, e quem mudar o tamanho de
## um widget empurra a linha seguinte sem precisar lembrar de nada.
class_name CarteiraLayout
extends RefCounted

## Resolucao interna. ART-BIBLE secao 2.
const TELA := Vector2(480.0, 270.0)

# --- o documento ------------------------------------------------------------

## A carteira aberta, e TODO o resto do documento sai destes quatro numeros.
##
## Ela subiu e cresceu, e o motivo e aritmetico. Com 156 px de altura a partir de
## 100, a coluna de campos ia de 172 ate a zona de leitura, que comeca em 238:
## sessenta e seis pixels para tres campos que pedem oitenta e oito. Apertar as
## linhas ja tinha sido tentado — 22 px e menos do que os proprios widgets
## ocupam — entao o que sobrava era dar altura ao documento.
const DOC_X := 86.0
const DOC_Y := 78.0
const DOC_L := 308.0
const DOC_A := 178.0
const DOC := Rect2(DOC_X, DOC_Y, DOC_L, DOC_A)

## As duas paginas ocupam a altura do documento menos as margens. Era 144
## cravado, que e `DOC_A - 12` escrito de outro jeito — e que teria ficado para
## tras quando a carteira cresceu.
const PAGINA_ESQ := Rect2(DOC_X + 18.0, DOC_Y + 6.0, 112.0, DOC_A - 12.0)
const PAGINA_DIR := Rect2(DOC_X + 154.0, DOC_Y + 6.0, 136.0, DOC_A - 12.0)
## Janela do retrato, dentro da pagina da esquerda. Cresceu com o documento.
const RETRATO := Rect2(DOC_X + 20.0, DOC_Y + 44.0, 104.0, 104.0)

## Onde a primeira linha de campo comeca.
const LINHA_UM := DOC_Y + 66.0

## Onde a coluna de campos tem de acabar: o topo da zona de leitura do rodape.
##
## A zona e desenhada com a base em `DOC.end.y - 7` e a fonte tem 11 px de caixa,
## entao o que ela ocupa comeca uns treze pixels acima disso. Campo que passe
## daqui sai por cima do numero do documento — e foi assim que a fileira de cores
## do agasalho apareceu dentro da zona.
const CAMPOS_FUNDO := DOC_Y + DOC_A - 20.0

# --- a linha de um campo ----------------------------------------------------

## O rotulo do campo ocupa a primeira linha; o widget comeca depois dela.
const CAMPO_ROTULO := 10.0
## Respiro ate o campo seguinte.
const CAMPO_RESPIRO := 4.0
## Altura de cada widget, por tipo. Uma tabela, dois leitores: `criacao.gd`
## desenha a partir dela e `altura_da_linha` soma a partir dela.
const CAMPO_WIDGET := {
	"celula": 17.0,
	"lista": 15.0,
	"cor": 14.0,
	"faixa": 16.0,
}
## Widget de tipo desconhecido. Rede, nao regra.
const CAMPO_WIDGET_PADRAO := 16.0

## Abas de categoria. Cada uma diz quais campos de `Aparencia.AJUSTES` mostra.
##
## Mora aqui, e nao na tela, porque e ela que decide quanta coluna a tela precisa
## — e e isso que o teste mede. A aba mais cheia manda no tamanho do documento.
const ABAS: Array[Dictionary] = [
	{"nome": "ROSTO", "icone": "rosto", "campos": [&"rosto", &"pele"]},
	{"nome": "CABELO", "icone": "cabelo", "campos": [&"cabelo", &"cabelo_cor"]},
	{"nome": "ROUPA", "icone": "camisa", "campos": [&"camisa", &"camisa_cor"]},
	{"nome": "AGASALHO", "icone": "casaco",
		"campos": [&"casaco_usa", &"casaco_cel", &"casaco_cor"]},
	{"nome": "CALCA", "icone": "calca", "campos": [&"calca", &"calca_cor"]},
	{"nome": "CHAPEU", "icone": "chapeu", "campos": [&"chapeu_tipo"]},
	{"nome": "CORPO", "icone": "corpo", "campos": [&"altura", &"gordura"]},
]


## Quanto o widget deste tipo ocupa de altura.
static func altura_do_widget(tipo: String) -> float:
	return float(CAMPO_WIDGET.get(tipo, CAMPO_WIDGET_PADRAO))


## Quanto a linha inteira ocupa: rotulo + widget + respiro.
static func altura_da_linha(tipo: String) -> float:
	return CAMPO_ROTULO + altura_do_widget(tipo) + CAMPO_RESPIRO


## O tipo de cada campo de uma aba, na ordem. Le `Aparencia.AJUSTES`, que e uma
## tabela estatica — nenhum autoload entra nesta conta.
static func tipos_da_aba(indice: int) -> PackedStringArray:
	var tipos := PackedStringArray()
	for chave: StringName in ABAS[indice]["campos"]:
		for c: Dictionary in Aparencia.AJUSTES:
			if StringName(c["chave"]) == chave:
				tipos.append(String(c["tipo"]))
				break
	return tipos


## Quanto a aba inteira ocupa, de `LINHA_UM` ate o fim do ultimo campo.
static func altura_dos_campos(indice: int) -> float:
	var total := 0.0
	for tipo: String in tipos_da_aba(indice):
		total += altura_da_linha(tipo)
	return total


## Onde a linha do campo `indice` comeca, empilhando as alturas de quem veio
## antes. E a mesma acumulacao que o desenho faz, e tem de ser: quem pergunta
## tambem e o MOUSE. Se as duas discordarem, o desenho aparece num lugar e o
## clique acontece noutro — o pior defeito possivel numa tela clicavel, porque
## ele nao aparece em captura nenhuma.
static func topo_da_linha(indice_aba: int, indice_campo: int) -> float:
	var y := LINHA_UM
	var tipos := tipos_da_aba(indice_aba)
	for i in tipos.size():
		if i == indice_campo:
			break
		y += altura_da_linha(tipos[i])
	return y
