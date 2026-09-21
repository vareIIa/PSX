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
## Menus RE7 (prancha/sistema): usar fonte_re7 / aplicar_re7_* — NUNCA .fnt pixel.
## HUD bitmap legado: continua com aplicar() + FONTE_*.
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
## Tipografia RE7 (SPEC_VISUAL_RE7 §3) — sans, NUNCA bitmap .fnt nesta superficie.
## SystemFont montado em fonte_re7(); tamanhos logicos 480×270.
const RE7_SIZE_DISPLAY := 18
const RE7_SIZE_TITLE := 14
const RE7_SIZE_BODY := 11
const RE7_SIZE_MICRO := 9
## SPEC_POLISH_TIPO_LAYOUT_RE7 — pad/ritmo (prancha/sistema).
const RE7_PAD_PANEL := 10
const RE7_PAD_MODAL := 12
const RE7_ROW := 16
const RE7_ROW_GAP := 2
## Slider RE7 (SPEC_VISUAL_RE7 §6 + POLISH_CONTROLES) — sem meter ASCII.
## Track H 6 (faixa 6–8 @480×270; Visual listava 4 — polish controles eleva hit).
const RE7_SLIDER_TRACK_W := 72.0
const RE7_SLIDER_TRACK_H := 6.0
const RE7_SLIDER_THUMB_W := 4.0
const RE7_SLIDER_THUMB_H := 8.0
const RE7_SLIDER_ROW_PAD := 4.0 ## respiro vertical extra dentro da row 16
## Cores: track = SLOT_EMPTY escuro; fill = ACCENT; thumb = TEXT_TITLE
const RE7_SLIDER_TRACK := Color(0.071, 0.094, 0.102, 0.85) ## ~#12181a
const RE7_SLIDER_FILL := Color("b85a42") ## = RE7_ACCENT
const RE7_SLIDER_THUMB := Color("e8e2d6") ## = RE7_TEXT_TITLE
const RE7_LINE_BODY := 14
const RE7_LINE_TITLE := 18
const RE7_LINE_DISPLAY := 22
const RE7_LINE_MICRO := 11
## SPEC_POLISH_TIPO_LAYOUT_RE7 §1 — safe area (menus RE7; legado HUD mantém MARGEM 7).
const RE7_SAFE := 8.0
const RE7_SAFE_HARD := 4.0
const RE7_MARGEM_MODAL := 24.0
const RE7_HIT_MIN := 32.0
## Tracking em 1/1000 em (polish §2). letter_spacing_re7() converte p/ px.
const RE7_TRACK_DISPLAY := 40
const RE7_TRACK_TITLE := 20
const RE7_TRACK_BODY := 0
const RE7_TRACK_MICRO := 40
const RE7_TRACK_VITAL := 60
const RE7_WEIGHT_REGULAR := 400
const RE7_WEIGHT_SEMIBOLD := 600
## Faixa inventário polish §3.1 (tokens p/ UI Dev; não editar prancha aqui).
const RE7_FAIXA_Y0 := 28.0
const RE7_FAIXA_Y1 := 60.0
const RE7_TITLE_BASELINE_Y := 20.0

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
## Overlay RE7 (mundo atras do menu). Acima de mapa/cartao, abaixo da prancha (110).
const CAMADA_RE7_OVERLAY := 108

# --- tinta ------------------------------------------------------------------
# Mesma paleta da prancha de inventario e do mapa. Com outra, cada pedaco de HUD
# viraria janela de um jogo diferente dentro deste.
const TINTA := Color("2a1f16")
const TINTA_FRACA := Color("6a5a44")
const TINTA_TITULO := Color("7a3a22")
const DESTAQUE := Color("8a2f1f")
# --- RE7 (SPEC_VISUAL_RE7 §2) — paleta fria-suja; Onda 1 consome no overlay -----
const RE7_BG_VOID := Color("0a0c0e")
const RE7_SCRIM := Color("070809")
const RE7_PANEL_BASE := Color(0.102, 0.133, 0.141, 0.84)
const RE7_PANEL_EDGE := Color(0.541, 0.604, 0.565, 0.35)
const RE7_TEXT_PRIMARY := Color("d6d2c8")
const RE7_TEXT_MUTED := Color("8a8680")
const RE7_TEXT_TITLE := Color("e8e2d6")
const RE7_ACCENT := Color("b85a42")
const RE7_ACCENT_HOT := Color("d46a48")
## Documento scrapbook (polish §2.3) — body no papel usa DOC_INK, nunca TEXT_MUTED.
const RE7_DOC_PAPER := Color(0.847, 0.816, 0.753, 0.92) ## #d8d0c0
const RE7_DOC_INK := Color("2a2420")
const RE7_DOC_MICRO := Color("4a443c")
const RE7_TAPE := Color(0.761, 0.627, 0.376, 0.9) ## #c2a060 @ 0.9
const RE7_SLOT_FOCUS := Color("c4a574")
## SPEC_VISUAL_RE7 / SPEC_GRID — células inventário grid (Onda 2).
const RE7_SLOT_EMPTY := Color(0x12 / 255.0, 0x18 / 255.0, 0x1a / 255.0, 0.65)
const RE7_SLOT_FILL := Color(0x24 / 255.0, 0x30 / 255.0, 0x33 / 255.0, 0.80)
## Onda 2 feature-flag. Default OFF até GO.
## Enable: set true here, or UIManager.abrir_inventario_grid(force=true) for captures (--ver-grid-re7).
## Grid LEAD: sync InventarioGridRE7.FLAG_RE7_GRID with this const at cutover.
const RE7_GRID := false
## Layout grid (SPEC_GRID_INVENTORY_RE7 §1 / Visual §5.1).
const RE7_GRID_SLOT := 28.0
const RE7_GRID_GAP := 4.0
const RE7_GRID_HIT := 32.0
const RE7_GRID_COLS := 8
const RE7_PANEL_ALPHA := 0.84
const RE7_VITAL_OK := Color("5cff9a")
const RE7_VITAL_WARN := Color("ffc857")
const RE7_VITAL_CRIT := Color("ff4a3a")
## Onda 3 — inspect / vitals (SPEC_INSPECT_VITALS_RE7 · Visual §5.3–5.4).
## Diegetic consome; SUPPORT só declara tokens (não edita inspect/vitals logic).
const RE7_INSPECT_SIZE := Vector2(140, 150)
const RE7_INSPECT_VOID := Color(0.04, 0.045, 0.05, 0.85)
const RE7_VITAL_LED := Vector2(6, 4)
const RE7_VITAL_LED_GAP := 2.0
const RE7_VITAL_LED_COUNT := 5
const RE7_VITAL_BAR := Vector2(48, 6)
const RE7_SIZE_VITAL := 10
const RE7_VITAL_OK_RATIO := 0.75
const RE7_VITAL_WARN_RATIO := 0.4
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

## Tempos de menu (pauzinhos / folha sistema). Spec: docs/specs/SPEC_MOTION_PAUZINHOS_RAIZ.md
## Nao misturar com T_ENTRADA/T_SAIDA do cartao HUD (UI-BIBLE §5).
const T_MENU_OPEN := 0.20
const T_MENU_CLOSE := 0.14
const T_MENU_PAGE := 0.16
const T_MENU_FOCUS := 0.08
const T_MENU_PRESS := 0.10

## Tempos RE7 overlay inventario (SPEC_MOTION_RE7). Nao misturar com T_MENU_*.
const T_RE7_OPEN := 0.22
const T_RE7_CLOSE := 0.14
const T_RE7_PANEL := 0.20 ## SPEC_MOTION_RE7 — painel/viewport inspect enter
## Focus row/panel RE7 (sine-out). Mesmo valor que T_MENU_FOCUS; const própria pra não misturar namespaces.
const T_RE7_FOCUS := 0.08
const T_RE7_GRID_STAGGER := 0.035 ## SPEC_MOTION_RE7 §4 / SPEC_GRID
## Onda 3 inspect orbit damp (SPEC_INSPECT half-life~0,18 · T_RE7_SPIN_DAMP 0,28–0,40).
const T_RE7_SPIN_DAMP := 0.34

# --- papel / espaco de menu -------------------------------------------------
const PAPEL := Color("e6dfc4")
const PAPEL_ABERTO := Color("f4e7cc")
## Respiro entre grupos de secao (acoes vs ajustes vs saida).
const GAP_SECAO := 6.0
## Hit minimo A11y para aba / linha clicavel.
const HIT_ABA_MIN := 32.0
const HIT_LINHA_MIN := 32.0  # A11Y_FOCUS_STACK / SPEC_A11Y_RE7 §5


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

## Sans RE7 — Segoe/Inter/Helvetica/Arial. Sem pixel .fnt (SPEC §3 / §8).
static func fonte_re7(peso: int = 400) -> Font:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Segoe UI", "Inter", "Helvetica Neue", "Arial"])
	sf.font_weight = peso
	sf.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return sf


static func letter_spacing_re7(tamanho: int, track_mille: int) -> int:
	if track_mille == 0:
		return 0
	return int(round(float(tamanho) * float(track_mille) / 1000.0))


static func aplicar_re7(rotulo: Label, tamanho: int = RE7_SIZE_BODY, peso: int = 400, track_mille: int = 0) -> void:
	rotulo.add_theme_font_override(&"font", fonte_re7(peso))
	rotulo.add_theme_font_size_override(&"font_size", tamanho)
	var ls := letter_spacing_re7(tamanho, track_mille)
	if ls != 0:
		rotulo.add_theme_constant_override(&"letter_spacing", ls)
	else:
		rotulo.remove_theme_constant_override(&"letter_spacing")


static func aplicar_re7_display(rotulo: Label) -> void:
	aplicar_re7(rotulo, RE7_SIZE_DISPLAY, RE7_WEIGHT_SEMIBOLD, RE7_TRACK_DISPLAY)


static func aplicar_re7_title(rotulo: Label) -> void:
	aplicar_re7(rotulo, RE7_SIZE_TITLE, RE7_WEIGHT_SEMIBOLD, RE7_TRACK_TITLE)


static func aplicar_re7_body(rotulo: Label) -> void:
	aplicar_re7(rotulo, RE7_SIZE_BODY, RE7_WEIGHT_REGULAR, RE7_TRACK_BODY)


static func aplicar_re7_micro(rotulo: Label) -> void:
	aplicar_re7(rotulo, RE7_SIZE_MICRO, RE7_WEIGHT_REGULAR, RE7_TRACK_MICRO)


static func aplicar_re7_vital(rotulo: Label) -> void:
	aplicar_re7(rotulo, RE7_SIZE_VITAL, RE7_WEIGHT_SEMIBOLD, RE7_TRACK_VITAL)


## StyleBoxFlat — paddings polish; UI Dev aplica, Theme Tokens só declara.
static func style_re7_panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = RE7_PANEL_BASE
	sb.border_color = RE7_PANEL_EDGE
	sb.set_border_width_all(1)
	sb.content_margin_left = float(RE7_PAD_MODAL)
	sb.content_margin_top = float(RE7_PAD_MODAL)
	sb.content_margin_right = float(RE7_PAD_MODAL)
	sb.content_margin_bottom = float(RE7_PAD_MODAL)
	return sb


static func style_re7_doc() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = RE7_DOC_PAPER
	sb.set_border_width_all(0)
	sb.content_margin_left = float(RE7_PAD_PANEL)
	sb.content_margin_top = float(RE7_PAD_PANEL)
	sb.content_margin_right = float(RE7_PAD_PANEL)
	sb.content_margin_bottom = 8.0
	return sb


static func style_re7_slot_empty() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = RE7_SLOT_EMPTY
	sb.set_border_width_all(0)
	sb.content_margin_left = 2.0
	sb.content_margin_top = 2.0
	sb.content_margin_right = 2.0
	sb.content_margin_bottom = 2.0
	return sb


static func style_re7_slot_fill() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = RE7_SLOT_FILL
	sb.set_border_width_all(0)
	sb.content_margin_left = 2.0
	sb.content_margin_top = 2.0
	sb.content_margin_right = 2.0
	sb.content_margin_bottom = 2.0
	return sb


static func style_re7_slot_focus() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = RE7_SLOT_FILL
	sb.border_color = RE7_SLOT_FOCUS
	sb.set_border_width_all(2)
	sb.content_margin_left = 2.0
	sb.content_margin_top = 2.0
	sb.content_margin_right = 2.0
	sb.content_margin_bottom = 2.0
	return sb

## Metricas RE7 com tamanho explicito (SystemFont nao tem fixed_size).
static func largura_tam(fonte: Font, texto: String, tamanho: int) -> float:
	return fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tamanho).x


static func altura_tam(fonte: Font, tamanho: int) -> float:
	return fonte.get_height(tamanho)


static func encurtar_tam(fonte: Font, texto: String, largura_max: float, tamanho: int) -> String:
	if largura_tam(fonte, texto, tamanho) <= largura_max:
		return texto
	var corte := texto
	while corte.length() > 1 and largura_tam(fonte, corte + "...", tamanho) > largura_max:
		corte = corte.substr(0, corte.length() - 1)
	return corte.strip_edges() + "..."

## HSlider / Progress — StyleBoxFlat track+fill (thumb fica Texture/Style separado no consumer).
static func style_re7_slider_track() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = RE7_SLIDER_TRACK
	sb.set_corner_radius_all(1)
	sb.content_margin_left = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_bottom = 0.0
	# altura visual via const RE7_SLIDER_TRACK_H no consumer (min_size / draw)
	return sb


static func style_re7_slider_fill() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = RE7_SLIDER_FILL
	sb.set_corner_radius_all(1)
	sb.content_margin_left = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_bottom = 0.0
	return sb


static func style_re7_slider_thumb() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = RE7_SLIDER_THUMB
	sb.set_corner_radius_all(1)
	sb.content_margin_left = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_bottom = 0.0
	return sb

