## Contrato de interface em codigo. O UI-BIBLE que o compilador le.
##
## Por que este arquivo existe
## ---------------------------
## Porque todo numero de HUD estava solto no arquivo que o usava. O cartao de
## missao espacava linha de 10 px para uma fonte cuja linha tem 13, e nao havia
## lugar onde conferir isso — a medida certa nao estava errada em algum lugar,
## ela nao estava em lugar nenhum.
##
## A regra do projeto (docs/PADROES-ENGENHARIA.md) e que todo numero de estetica
## vem de documento canonico. `docs/UI-BIBLE.md` e o documento; este arquivo e a
## mesma tabela onde o codigo consegue ler.
##
## O tamanho da fonte NAO e opcional
## ---------------------------------
## As quatro fontes do projeto sao bitmap (.fnt) com `fixed_size_scale_mode = 2`,
## que e escala livre. Um `Label` que recebe `font` e nao recebe `font_size` usa o
## padrao do tema, que e 16 — entao `psx_pequena`, desenhada para 11 px, era
## esticada 1,4545x; `psx_titulo`, desenhada para 18, era ENCOLHIDA para 16.
## Fonte de pixel em escala nao inteira e reamostrada: a grade do glifo deixa de
## bater com a grade da tela e o texto fica mole. Medido em
## `tests/medir_fonte.gd`:
##
##     psx_pequena  pedido 11 -> altura 13,0  "A CASA DA FUMACA" = 106 px
##     psx_pequena  pedido 16 -> altura 18,9  "A CASA DA FUMACA" = 155 px
##
## Os 49 px de diferenca sao a colisao que aparecia no cartao de missao. As telas
## desenhadas a mao (GPS, celular, ficha, terminal) nunca tiveram o problema
## porque passam o tamanho direto no `draw_string`; so as telas feitas de `Label`
## sofriam. Por isso `aplicar()` existe e por isso ninguem deve chamar
## `add_theme_font_override` sozinho.
class_name UiEstilo
extends RefCounted

# --- tela -------------------------------------------------------------------
## Resolucao interna. ART-BIBLE secao 2.
const TELA := Vector2(480.0, 270.0)
## Distancia minima de qualquer coisa de HUD ate a borda da tela. Abaixo disto o
## elemento entra no arredondamento da TV e no raio da vinheta do pos.
const MARGEM := 7.0
## Respiro interno de um cartao de papel, da borda ate o texto.
const PAD := 6.0
## Vao entre duas linhas parentes — o titulo e a regua que o sublinha.
const GAP := 2.0
## Vao entre dois blocos que dizem coisas diferentes: o objetivo e a dica de
## tecla, a dica e o rodape de distancia. Com o GAP pequeno entre os tres, eles
## leem como um paragrafo so e o cartao vira bloco de texto.
const GAP_BLOCO := 4.0

# --- fontes -----------------------------------------------------------------
const FONTE_P := "res://assets/fontes/psx_pequena.fnt"
const FONTE_M := "res://assets/fontes/psx_media.fnt"
const FONTE_T := "res://assets/fontes/psx_titulo.fnt"
const FONTE_MONO := "res://assets/fontes/psx_mono.fnt"

## Usado so quando a fonte nao declara tamanho proprio. Nenhuma fonte do projeto
## cai aqui; e rede, nao regra.
const TAMANHO_PADRAO := 16

# --- camadas ----------------------------------------------------------------
# A ordem importa mais que os numeros: o que esta ABAIXO de CAMADA_POS recebe
# grao, dither e vinheta como o resto da imagem, e o que esta acima nao recebe.
# `minimapa.gd` explica o porque: um mapa nitido por cima de uma cena suja
# denuncia na hora que e interface colada num jogo que finge ser de 1999.
#
# Mudar a camada de um elemento e mudanca de contrato visual, nao de gosto.
const CAMADA_MAPA := 100
const CAMADA_CARTAO := 101
const CAMADA_POS := 150
## So para o que precisa sobreviver ao pos inteiro (icone de 2 px, barra fina).
const CAMADA_ACIMA_DO_POS := 160
## Apagao da vida zero. Cobre a tela inteira, inclusive a interface. A
## justificativa escrita esta em `desmaio.gd` e na secao 3 do UI-BIBLE: e a
## unica coisa autorizada acima de 160.
const CAMADA_APAGAO := 200

# --- tinta ------------------------------------------------------------------
# Mesma paleta da prancha de inventario e do mapa. Com outra, cada pedaco de HUD
# viraria janela de um jogo diferente dentro deste.
const TINTA := Color("2a1f16")
const TINTA_FRACA := Color("6a5a44")
const TINTA_TITULO := Color("7a3a22")
const DESTAQUE := Color("8a2f1f")
const PAPEL_SOMBRA := Color(0.05, 0.04, 0.03, 0.45)

## Luz do papel. Multiplica a textura `ui_papel`, que sozinha nao se descola do
## fundo: medido na captura `captures/ui/f1_cartao_aberto.png`, o papel cru fica
## 153 de luminancia contra 124 da parede em nevoa densa — 29 niveis, 11% de
## contraste, e o cartao le como mancha e nao como objeto.
##
## O mesmo valor que `menu.gd` ja usa nas folhas de papel dele. Passa de 1,0 de
## proposito: e brilho somado, e nao tingimento.
const PAPEL_LUZ := Color(1.24, 1.19, 1.06)

## Contorno do papel, 1 px. Existe pelo mesmo motivo do contorno das quadras no
## minimapa (`mapa.gd`): num fundo claro, so o valor do preenchimento nao separa
## duas superficies — a BORDA separa. E e o que faz os dois cartoes dos cantos
## opostos lerem como irmaos.
const PAPEL_BORDA := 1.0

# --- tempos -----------------------------------------------------------------
## Entrada de cartao deslizando. Acima de 0,4 s o jogador espera a animacao.
const T_ENTRADA := 0.34
const T_SAIDA := 0.4
const T_ENCOLHER := 0.28
## Quanto um objetivo novo fica aberto antes de virar tira. Duas leituras.
const T_LEITURA := 12.0


# --- metrica ----------------------------------------------------------------

## Tamanho em que a fonte foi desenhada. Pedir outro reamostra o glifo.
static func tamanho_nativo(fonte: Font) -> int:
	var ff := fonte as FontFile
	if ff != null and ff.fixed_size > 0:
		return ff.fixed_size
	return TAMANHO_PADRAO


## Altura de uma linha, no tamanho nativo. E o passo da grade vertical: todo
## rotulo empilhado neste projeto anda de multiplo disto.
static func altura_da_linha(fonte: Font) -> float:
	return fonte.get_height(tamanho_nativo(fonte))


## Largura do texto, no tamanho nativo. A unica medida que vale — contar
## caractere por `xadvance` do .fnt erra, porque o espacamento do arquivo nao e
## aplicado do jeito que o TextServer aplica.
static func largura(fonte: Font, texto: String) -> float:
	return fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		tamanho_nativo(fonte)).x


## Prende a fonte E o tamanho no rotulo. Use sempre isto no lugar de
## `add_theme_font_override` sozinho; ver o cabecalho do arquivo.
static func aplicar(rotulo: Label, fonte: Font) -> void:
	rotulo.add_theme_font_override(&"font", fonte)
	rotulo.add_theme_font_size_override(&"font_size", tamanho_nativo(fonte))


## Quebra o texto em linhas que cabem na largura. Feito a mao, e nao pelo
## autowrap do `Label`, porque quem monta o cartao precisa saber a ALTURA antes
## de desenhar: `Label.get_line_count()` so responde depois do layout, e ate la o
## papel ja foi dimensionado errado.
static func quebrar(fonte: Font, texto: String, largura_max: float) -> PackedStringArray:
	var linhas := PackedStringArray()
	var limpo := texto.strip_edges()
	if limpo.is_empty():
		return linhas
	var atual := ""
	for palavra: String in limpo.split(" ", false):
		var tentativa := palavra if atual.is_empty() else atual + " " + palavra
		if atual.is_empty() or largura(fonte, tentativa) <= largura_max:
			atual = tentativa
			continue
		linhas.append(atual)
		atual = palavra
	if not atual.is_empty():
		linhas.append(atual)
	return linhas


## Corta o texto no que cabe e marca o corte. Reticencia em tres pontos, e nao no
## caractere unico: as fontes de bitmap do projeto nao tem o glifo U+2026 e ele
## sairia como caixa vazia.
static func encurtar(fonte: Font, texto: String, largura_max: float) -> String:
	if largura(fonte, texto) <= largura_max:
		return texto
	var corte := texto
	while corte.length() > 1 and largura(fonte, corte + "...") > largura_max:
		corte = corte.substr(0, corte.length() - 1)
	return corte.strip_edges() + "..."


## --- Vinheta -----------------------------------------------------------------
##
## Quanto o pos-processamento multiplica a cor de um pixel da tela.
##
## Por que isso mora no estilo e nao no shader
## -------------------------------------------
## Porque quem desenha interface precisa saber ANTES de desenhar. A vinheta de
## `post_psx.gdshader` nao e enfeite: no canto exato da tela ela multiplica por
## zero. Papel de luminancia 247 chega a 4. Nao existe cor que resolva; o que
## resolve e nao por nada legivel no canto.
##
## O menu de sistema aprendeu isso do jeito caro: tres capturas culpando cor
## antes de a medida nomear o culpado. Aqui a conta esta escrita uma vez, e
## `tests/checar_hud.gd` reprova layout que ponha texto onde a conta da pouco.
##
## A formula e copia literal da linha 81 do shader. Se o shader mudar, muda aqui.
const VINHETA_PADRAO := 0.45

## Piso aceitavel para texto de interface na camada 100 (abaixo do pos). Abaixo
## disso, ou o elemento anda para dentro, ou sobe para CAMADA_ACIMA_DO_POS com
## justificativa escrita no arquivo.
const VINHETA_MIN := 0.45


static func vinheta(p: Vector2, intensidade: float = VINHETA_PADRAO) -> float:
	if intensidade <= 0.0:
		return 1.0
	var off := Vector2(p.x / TELA.x - 0.5, p.y / TELA.y - 0.5)
	var d := off.length() * 1.35
	return smoothstep(0.95, 0.95 - intensidade, d)


## O pior canto de um retangulo. E o numero que vale para julgar legibilidade:
## o texto se perde pela quina, nao pelo centro.
static func vinheta_do_rect(r: Rect2, intensidade: float = VINHETA_PADRAO) -> float:
	var pior := 1.0
	for c: Vector2 in [r.position, r.position + Vector2(r.size.x, 0.0),
			r.position + Vector2(0.0, r.size.y), r.end]:
		pior = minf(pior, vinheta(c, intensidade))
	return pior
