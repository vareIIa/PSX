## A travessia do tubo, como aritmetica pura.
##
## O menu inicial e uma televisao chiando, e apertar START ENTRA nela: o vidro
## empena, a imagem amplia a partir do centro, o fosforo estoura, e do outro lado
## a lente esta perto do carro e o veu do tubo ja afrouxou. Duas coisas correm
## nessa ordem dentro de um `t` unico de 0 a 1.
##
## Por que isto saiu de `menu.gd`
## ------------------------------
## Porque era a unica parte desta frente sem teste nenhum, e o
## `PLANO_MENU_AAA.md` registrou isso como divida na hora da entrega: *"a
## travessia e tempo + shader, e o que existe e uma flag de captura que congela
## num quadro escolhido a mao. Nada afirma que `plunge` volta a zero, que a lente
## termina em 1,0, ou que uma interrupcao no meio nao deixa a camera num ponto
## intermediario."*
##
## Curva com degrau nao da erro: da uma tela que fica com o vidro empenado para
## sempre, ou uma camera parada no meio do caminho. Os dois defeitos sao mudos, e
## os dois sao aritmetica — entao dao para provar sem abrir janela.
##
## Mesmo contrato de `CartaoLayout`, `TituloLayout` e `CarteiraLayout`:
## `RefCounted`, sem `Node`, sem autoload, tudo estatico.
class_name TravessiaCurva
extends RefCounted

## Quanto dura a travessia inteira, em segundos.
##
## Abaixo de 2 s o avanco vira solavanco — sao 2 m de deslocamento com 10 graus
## de fechamento de FOV junto; acima de 3 s o jogador que so queria jogar fica
## esperando uma camera andar.
const DURACAO := 2.4

## Onde acaba a travessia do vidro, em fracao de `DURACAO`.
##
##     0,00 a 0,42  o vidro. Empena, amplia, estoura e chove estatica.
##     0,35 a 1,00  do outro lado. O veu afrouxa e a lente termina de andar.
##
## As duas se sobrepoem de proposito entre 0,35 e 0,42: emenda seca entre dois
## movimentos le como dois cortes, que e exatamente o defeito da versao antiga.
const TRAVESSIA := 0.42
## Onde o veu comeca a afrouxar. Antes disso ele fica cheio — e o vidro que ainda
## esta na frente.
const VEU_COMECA := 0.35

# --- a lente ----------------------------------------------------------------
#
# Os dois enquadramentos do fundo do menu. `CabineFundoCriacao` aplica; aqui eles
# so existem como numeros, para o teste conseguir afirmar que a lente anda para
# UM lado e que ela nao termina dentro do carro.

## Plano largo: a serra escura, a mata dos dois lados e a estrada sumindo na
## nevoa, com o carro pequeno no acostamento.
const LARGO := {
	&"altura": 1.72, &"recuo": 7.2, &"pitch": -3.5, &"fov": 68.0, &"lado": 1.6,
}
## Fim do travelling: a lente parada a um passo do para-choque.
##
## A primeira tentativa foi recuo 3,4 com FOV 52 e a captura reprovou: o recuo e
## medido do CENTRO do carro, entao 3,4 m num sedan de 4,3 m deixa a lente a pouco
## mais de um metro da lataria — ela tomava a metade direita da tela, cortada pela
## borda. Plano de detalhe, e o titulo precisa de plano geral.
const PERTO := {
	&"altura": 1.62, &"recuo": 5.2, &"pitch": -4.2, &"fov": 58.0, &"lado": 2.1,
}

## Meio comprimento de um sedan da epoca. O recuo e medido do centro do carro,
## entao e daqui que sai a distancia real entre a lente e a traseira.
const MEIO_CARRO := 2.15


## O vidro, de 0 a 1 e de volta a 0.
##
## Meio seno dentro da janela da travessia: nasce e morre em zero, entao nao ha
## degrau em nenhuma das duas pontas. Um `plunge` que terminasse em 0,2 deixaria
## o jogo inteiro com a tela empenada e ninguem saberia por que.
static func plunge(t: float) -> float:
	return sin(PI * clampf(t / TRAVESSIA, 0.0, 1.0))


## A chuva de estatica. Mais curta que a deformacao: ela e o INSTANTE do vidro, e
## nao o caminho inteiro. Elevar ao cubo concentra o pico no meio da travessia.
##
## Para em 0,9 e nao em 1,0 porque o shader soma este valor a cena em vez de
## multiplicar — ver a nota sobre grao e burst em `crt_overlay.gdshader`. Medido
## nas capturas: no pico, 0,24% dos pixels passam de 250 em MODERNO e 0,08% em
## PS1 STYLE, ou seja a soma nao satura a tela em nenhum dos dois presets.
static func burst(t: float) -> float:
	return pow(plunge(t), 3.0) * 0.9


## O veu do tubo, de "dose de boot" (0) a "dose de titulo" (1).
##
## Comeca em `VEU_COMECA` e sobe com amortecimento nas duas pontas
## (`smoothstep`), para o afrouxamento nao comecar nem acabar com tranco.
static func veu(t: float) -> float:
	var v := clampf((t - VEU_COMECA) / (1.0 - VEU_COMECA), 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)


## Um valor do enquadramento no ponto `t` do travelling.
static func lente(chave: StringName, t: float) -> float:
	return lerpf(float(LARGO[chave]), float(PERTO[chave]), clampf(t, 0.0, 1.0))


## O enquadramento inteiro num ponto. Funcao pura: chamar duas vezes com o mesmo
## `t` da a mesma imagem, e por isso quem anima nao precisa guardar estado.
static func enquadramento(t: float) -> Dictionary:
	var d := {}
	for chave: StringName in LARGO:
		d[chave] = lente(chave, t)
	return d


## Quanto a lente cresce o carro no quadro, do inicio ao fim.
##
## E o produto de duas coisas: o deslocamento (7,2 / 5,2 = 1,38) e o fechamento
## da abertura (tan(34°) / tan(29°) = 1,22). Da 1,7x — movimento que se le sem
## hesitacao, com o carro inteiro dentro da moldura.
static func ganho_aparente() -> float:
	var por_distancia := float(LARGO[&"recuo"]) / float(PERTO[&"recuo"])
	var por_abertura := (tan(deg_to_rad(float(LARGO[&"fov"]) * 0.5))
		/ tan(deg_to_rad(float(PERTO[&"fov"]) * 0.5)))
	return por_distancia * por_abertura
