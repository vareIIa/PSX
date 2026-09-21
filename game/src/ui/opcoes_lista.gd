## As opcoes ajustaveis do jogo, num lugar so.
##
## Por que nao mora no menu de titulo
## ----------------------------------
## Porque ela passou a ter dois donos. A lista nasceu dentro de `menu.gd`, que
## era o unico lugar de onde dava para mexer em nevoa, grao, scanline, vinheta e
## dither — e "o unico lugar" era o problema: o jogador so alcancava esses seis
## ajustes ANTES de apertar NOVO JOGO, e nunca mais.
##
## Com o menu de sistema em jogo, dois paineis oferecem os mesmos ajustes. Copiar
## a lista para o segundo daria certo no dia em que fosse escrita e erraria no
## primeiro ajuste — um painel com sete opcoes e o outro com seis, os dois
## dizendo que sao as opcoes do jogo. Mesma armadilha que `mapa.gd` documenta
## para o desenho do mapa, e a mesma saida: uma fonte, dois leitores.
##
## Cada entrada e `{rotulo, ler: Callable() -> String, aplicar: Callable(passo: int)}`.
## `passo` e -1 ou +1: a lista nao sabe de tecla, so de direcao.
class_name OpcoesLista
extends RefCounted


## Escada de resolucao interna do 3D, do PS1 puro ao nitido.
##
## Para em 1280x720 de proposito. Acima disso o dither de 15 bits vira textura de
## fundo em vez de padrao visivel, e o snap de vertice fica pequeno demais para
## ser lido como tremor — os dois tracos que sustentam o preset PS1 STYLE
## morreriam justamente na configuracao mais cara.
const RESOLUCOES: Array[Vector2i] = [
	Vector2i(480, 270),
	Vector2i(640, 360),
	Vector2i(960, 540),
	Vector2i(1280, 720),
]


## Os ajustes de imagem. Mesma ordem em que sempre apareceram, com ESTILO na
## frente — ele e o controle mestre e muda todos os de baixo de uma vez.
static func video() -> Array[Dictionary]:
	return [
		{
			"rotulo": "ESTILO",
			"ler": func() -> String: return Settings.estilo_rotulo(),
			"aplicar": func(passo: int) -> void:
				var lista := Settings.ESTILOS_OFERECIDOS
				var i := lista.find(Settings.estilo)
				# PERSONALIZADO nao esta na lista: o jogador cai nele mexendo
				# num ajuste solto. Sem este desvio, a seta nao faria nada e o
				# unico caminho de volta a um preset seria desfazer a mao o que
				# foi mexido.
				if i < 0:
					Settings.aplicar_estilo(lista[0] if passo > 0 else lista[lista.size() - 1])
					return
				Settings.aplicar_estilo(lista[posmod(i + passo, lista.size())]),
		},
		{
			"rotulo": "RESOLUCAO 3D",
			"ler": func() -> String:
				var r := Settings.resolucao_3d
				return "%d x %d" % [r.x, r.y],
			"aplicar": func(passo: int) -> void:
				var i := RESOLUCOES.find(Settings.resolucao_3d)
				if i < 0:
					i = 0
				Settings.set_post(&"resolucao_3d",
					RESOLUCOES[clampi(i + passo, 0, RESOLUCOES.size() - 1)]),
		},
		{
			"rotulo": "NEVOA",
			"ler": func() -> String: return Settings.fog_preset().display_name.to_upper(),
			"aplicar": func(passo: int) -> void:
				var ids := Settings.FOG_PRESET_IDS
				var i := ids.find(Settings.fog_preset_id)
				Settings.set_fog_preset(ids[posmod(i + passo, ids.size())]),
		},
		barra("GRAO", &"grain", 0.0, 0.2, 0.02),
		barra("ABERRACAO", &"chromatic", 0.0, 2.0, 0.2),
		barra("SCANLINE", &"scanline", 0.0, 0.5, 0.04),
		barra("VINHETA", &"vignette", 0.0, 1.0, 0.1),
		{
			"rotulo": "DITHER",
			"ler": func() -> String: return "LIGADO" if Settings.dither else "DESLIGADO",
			"aplicar": func(_passo: int) -> void:
				Settings.set_post(&"dither", not Settings.dither),
		},
	]


## Um deslizador por bus. A lista sai de `Settings.BUSES`, e nao escrita a mao:
## acrescentar um bus la nao pode exigir lembrar de vir aqui.
static func audio() -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for bus: StringName in Settings.BUSES:
		var b := bus
		saida.append({
			"rotulo": String(Settings.BUS_ROTULO.get(b, String(b))).to_upper(),
			"ler": func() -> String: return trilha(Settings.get_volume(b)),
			"aplicar": func(passo: int) -> void:
				Settings.set_volume(b, Settings.get_volume(b) + float(passo) * 0.1),
		})
	return saida


## Opcao numerica com passo fixo.
static func barra(rotulo: String, chave: StringName, minimo: float, maximo: float,
		passo: float) -> Dictionary:
	return {
		"rotulo": rotulo,
		"ler": func() -> String:
			var v: float = Settings.get(String(chave))
			return trilha((v - minimo) / (maximo - minimo)),
		"aplicar": func(p: int) -> void:
			var v: float = Settings.get(String(chave))
			Settings.set_post(chave, clampf(v + float(p) * passo, minimo, maximo)),
	}


## Trilha RE7 (0..10): marcador interno para consumidores desenharem a pele.
## Nao meter ASCII hash-barras — menu_sistema desenha via desenhar_trilha; Labels
## de titulo usam texto_trilha_visual (█/░).
const MARCA_TRILHA := "⟦T⟧"


static func trilha(fracao: float) -> String:
	var n := clampi(int(round(fracao * 10.0)), 0, 10)
	return "%s%d" % [MARCA_TRILHA, n]


static func eh_trilha(texto: String) -> bool:
	return texto.begins_with(MARCA_TRILHA)


static func nivel_trilha(texto: String) -> int:
	if not eh_trilha(texto):
		return 0
	return clampi(int(texto.substr(MARCA_TRILHA.length())), 0, 10)


## Fallback para Label (menu titulo): unicode, nunca # / .
static func texto_trilha_visual(nivel: int) -> String:
	var n := clampi(nivel, 0, 10)
	return "%s%s" % ["█".repeat(n), "░".repeat(10 - n)]


## Pele RE7 no CanvasItem. Consome RE7_SLIDER_* + style_re7_slider_*.
static func desenhar_trilha(ci: CanvasItem, canto: Vector2, nivel: int) -> void:
	var n := clampi(nivel, 0, 10)
	var tw := UiEstilo.RE7_SLIDER_TRACK_W
	var th := UiEstilo.RE7_SLIDER_TRACK_H
	var fw := UiEstilo.RE7_SLIDER_THUMB_W
	var fh := UiEstilo.RE7_SLIDER_THUMB_H
	var track := Rect2(canto, Vector2(tw, th))
	ci.draw_style_box(UiEstilo.style_re7_slider_track(), track)
	var fill_w := tw * float(n) / 10.0
	if fill_w > 0.5:
		ci.draw_style_box(UiEstilo.style_re7_slider_fill(),
			Rect2(canto, Vector2(fill_w, th)))
	var tx := clampf(canto.x + fill_w - fw * 0.5, canto.x, canto.x + tw - fw)
	var ty := canto.y + (th - fh) * 0.5
	ci.draw_style_box(UiEstilo.style_re7_slider_thumb(),
		Rect2(Vector2(tx, ty), Vector2(fw, fh)))
