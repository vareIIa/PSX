## Tokens e primitivas de desenho do HUD de jogo. O UI-BIBLE secao 6.8 em codigo.
##
## Por que o HUD saiu do papel
## ---------------------------
## Porque o resto da interface ja tinha saido. Pause, inventario, conversa e o
## cartao do iWeed falam a gramatica RE7 (painel frio e sujo, sans, ferrugem de
## destaque) desde a Onda 1b; o HUD de rua era a ultima peca ainda em bitmap de
## 11 px sobre papel bege. Na mesma tela o jogador via dois jogos: o do menu e o
## da faixa do rodape.
##
## E porque o MODERNO desenha a interface em `canvas_items`: tudo o que e vetor
## aqui (texto, anel do radar, seta) rasteriza na resolucao da JANELA, com as
## mesmas coordenadas de 480x270 que o resto do projeto usa. Bitmap de 11 px nao
## ganha nada com isso; `SystemFont` ganha tudo.
##
## A gramatica, em quatro regras
## -----------------------------
## 1. Texto primeiro, caixa depois. Informacao de relance (lugar, hora, objetivo)
##    e texto claro com sombra, sobre degradê que some — nao cartao fechado. Caixa
##    fechada so para o que se LE com calma (toast, banner).
## 2. Um acento so. Ferrugem (`ACENTO`) e objetivo, destino e alerta. Se tudo e
##    laranja, nada e.
## 3. Maiuscula espaçada so em rotulo curto (TITULO, BAIRRO). Frase vai em caixa
##    normal: maiuscula em frase comprida le como grito e custa 30% de largura.
## 4. Todo numero sai daqui. Widget que escolhe cor ou tamanho sozinho vira outro
##    jogo dentro deste — foi exatamente o problema do papel com a faixa.
class_name HudTema
extends RefCounted

# --- tela e margens -----------------------------------------------------------
const TELA := Vector2(480.0, 270.0)
## Margem do HUD. Maior que a do papel (7): acima do pos nao ha vinheta para
## fugir, mas ha TV com overscan e monitor ultrawide com cantos curvos.
const MARGEM := 10.0

## Camada. Acima do pos (160) e nao abaixo, como o papel morava.
##
## Mudanca de contrato visual, e escrita aqui como o UI-BIBLE secao 3 exige: o
## papel ficava na 100 para receber grao e vinheta e "parecer 1999". Pagava com
## o canto — a vinheta multiplica o canto por zero, e o radar e o objetivo MORAM
## em canto. O HUD vetorial nao finge ser impresso: ele e a camada de leitura do
## jogo, como em qualquer jogo AAA, e ler e o trabalho dele. O mundo continua
## sujo por baixo.
const CAMADA := 160

# --- cor ------------------------------------------------------------------------
const TEXTO := Color("ece6da")
## Secundario. 0,72 de alfa sumia no PS1 (7 px a 480x270 sobre neblina clara).
const TEXTO_FRACO := Color(0.86, 0.84, 0.80, 0.88)
const TEXTO_APAGADO := Color(0.84, 0.82, 0.78, 0.42)
const ACENTO := Color("e0764f")
const ACENTO_ESCURO := Color("9c4a30")
const OK := Color("7fd6a0")
const ALERTA := Color("ffc15e")
const PERIGO := Color("ff5a44")
const AMIGO := Color("6f9bff")
## Sombra do texto. Alfa alto e deslocamento de meio pixel logico: em 1080p isso
## da 2 px, o bastante para o branco ler sobre nevoa clara sem virar contorno.
const SOMBRA := Color(0.0, 0.0, 0.0, 0.72)
const SOMBRA_DESVIO := Vector2(0.5, 0.6)
const PAINEL := Color(0.035, 0.045, 0.05, 0.78)
const PAINEL_BORDA := Color(1.0, 1.0, 1.0, 0.10)
## Degradê de leitura atras de texto solto. So escurece o bastante para a nevoa
## densa (luminancia ~190) nao comer o branco.
const VEU := Color(0.0, 0.0, 0.0, 0.46)

# --- tipografia ---------------------------------------------------------------
## Tamanhos em pixel LOGICO (480x270). No MODERNO a 1080p cada um vale 4x.
const T_MICRO := 6
const T_ROTULO := 7
const T_CORPO := 8
const T_TITULO := 10
const T_DESTAQUE := 13
const T_BANNER := 20

## Espacamento extra de glifo para rotulo em maiuscula, em pixel logico.
const TRACK_ROTULO := 1

# --- tempos -------------------------------------------------------------------
const T_ENTRA := 0.26
const T_SAI := 0.32
## Quanto o objetivo fica aberto com a dica antes de recolher. Mesmo valor do
## cartao antigo (duas leituras tranquilas).
const T_LEITURA := 12.0

static var _fontes: Dictionary = {}


# --- tokens que dependem das opcoes de acessibilidade ---------------------------
#
# O resto da paleta e constante; estes quatro mudam com Opcoes > HUD (contraste
# alto e cor de destaque). As pecas leem por funcao, e nunca a constante direto.

static func acento() -> Color:
	return HudConfig.cor_destaque()


static func fraco() -> Color:
	return TEXTO if HudConfig.alto_contraste() else TEXTO_FRACO


static func veu() -> Color:
	return Color(0.0, 0.0, 0.0, 0.74) if HudConfig.alto_contraste() else VEU


static func painel_cor() -> Color:
	return Color(0.02, 0.025, 0.03, 0.95) if HudConfig.alto_contraste() else PAINEL


## Fonte sans do projeto, com cache. `SystemFont` novo por chamada custaria um
## `TextServer` resolvendo familia a cada quadro.
static func fonte(peso: int = 400, espaco: int = 0) -> Font:
	var chave := "%d:%d" % [peso, espaco]
	if _fontes.has(chave):
		return _fontes[chave]
	var base := UiEstilo.fonte_re7(peso)
	var f: Font = base
	if espaco != 0:
		var v := FontVariation.new()
		v.base_font = base
		v.spacing_glyph = espaco
		f = v
	_fontes[chave] = f
	return f


static func regular() -> Font:
	return fonte(400)


static func semi() -> Font:
	return fonte(600)


static func rotulo() -> Font:
	return fonte(600, TRACK_ROTULO)


static func negrito() -> Font:
	return fonte(700)


static func largura(f: Font, texto: String, tam: int) -> float:
	return f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tam).x


static func encurtar(f: Font, texto: String, tam: int, largura_max: float) -> String:
	if largura(f, texto, tam) <= largura_max:
		return texto
	var corte := texto
	while corte.length() > 1 and largura(f, corte + "...", tam) > largura_max:
		corte = corte.substr(0, corte.length() - 1)
	return corte.strip_edges() + "..."


static func quebrar(f: Font, texto: String, tam: int, largura_max: float) -> PackedStringArray:
	var linhas := PackedStringArray()
	var atual := ""
	for palavra: String in texto.strip_edges().split(" ", false):
		var tenta := palavra if atual.is_empty() else atual + " " + palavra
		if atual.is_empty() or largura(f, tenta, tam) <= largura_max:
			atual = tenta
			continue
		linhas.append(atual)
		atual = palavra
	if not atual.is_empty():
		linhas.append(atual)
	return linhas


static func alfa(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


# --- primitivas -----------------------------------------------------------------

## Texto com sombra. `p` e o canto de cima da esquerda da CAIXA, e nao a linha de
## base: quem empilha pensa em caixa, e a conversa para base mora so aqui.
static func texto(ci: CanvasItem, f: Font, p: Vector2, t: String, tam: int, cor: Color,
		largura_caixa: float = -1.0, alin := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if t.is_empty() or cor.a <= 0.0:
		return
	var base := p + Vector2(0.0, f.get_ascent(tam))
	ci.draw_string(f, base + SOMBRA_DESVIO, t, alin, largura_caixa, tam,
		alfa(SOMBRA, cor.a))
	ci.draw_string(f, base, t, alin, largura_caixa, tam, cor)


static func altura(f: Font, tam: int) -> float:
	return f.get_height(tam)


## Retangulo de canto arredondado como poligono.
static func cantos(r: Rect2, raio: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	# Raio igual a meia altura duplica vertice e a triangulacao falha em silencio
	# ("Invalid polygon data"). Um fio a menos resolve.
	raio = minf(raio, minf(r.size.x, r.size.y) * 0.5 - 0.01)
	if raio <= 0.0:
		return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y)])
	var cs := [Vector2(r.end.x - raio, r.position.y + raio),
		Vector2(r.end.x - raio, r.end.y - raio),
		Vector2(r.position.x + raio, r.end.y - raio),
		Vector2(r.position.x + raio, r.position.y + raio)]
	for k in 4:
		var a0 := -PI * 0.5 + float(k) * PI * 0.5
		for s in 5:
			var a := a0 + float(s) / 4.0 * PI * 0.5
			pts.append(cs[k] + Vector2(cos(a), sin(a)) * raio)
	return pts


## Poligono cheio com a borda suavizada. `draw_colored_polygon` nao tem
## antialiasing: em 4K a quina do losango serrilhava. Uma polilinha fina com AA
## por cima da borda resolve sem shader.
static func poligono(ci: CanvasItem, pts: PackedVector2Array, cor: Color) -> void:
	ci.draw_colored_polygon(pts, cor)
	var fechado := pts.duplicate()
	fechado.append(pts[0])
	ci.draw_polyline(fechado, cor, 0.3, true)


## Sombra suave embaixo de um painel: tres camadas crescendo e sumindo, um
## pouco para baixo. E o que tira o painel de "adesivo" e o poe NA frente da
## cena, sem blur de tela.
static func sombra(ci: CanvasItem, r: Rect2, a: float = 1.0, raio: float = 2.5) -> void:
	for k in 3:
		var g := 0.8 + float(k) * 0.9
		var rr := Rect2(r.position + Vector2(0.0, 0.9), r.size).grow(g)
		ci.draw_colored_polygon(cantos(rr, raio + g), Color(0.0, 0.0, 0.0, (0.13 - 0.035 * k) * a))


static func painel(ci: CanvasItem, r: Rect2, a: float = 1.0, raio: float = 2.5) -> void:
	sombra(ci, r, a, raio)
	var pts := cantos(r, raio)
	ci.draw_colored_polygon(pts, alfa(painel_cor(), a))
	pts.append(pts[0])
	ci.draw_polyline(pts, alfa(PAINEL_BORDA, a), 0.5, true)


## Degradê de leitura atras de texto solto: cheio no lado da borda da tela,
## zero no outro, e com as beiradas de cima e de baixo esfumadas. Sem o esfumado
## o veu vira um retangulo cinza de quina dura — lido como caixa, que e
## exatamente o que ele existe para nao ser.
##
## `cheio`: largura, a partir da borda cheia, em que o veu ainda nao comecou a
## sumir. Sem ela o degrade corre por baixo do texto e a ponta da frase — a
## tecla da dica, o "1/3" — pousa sem fundo na nevoa clara. Com ela o fundo
## cobre o conteudo inteiro e so esfuma DEPOIS dele. `pena` e o esfumado de
## cima e de baixo; quem chama deixa margem igual a ela em volta do texto.
static func veu_horizontal(ci: CanvasItem, r: Rect2, da_esquerda: bool, a: float = 1.0,
		cheio: float = 0.0, pena: float = -1.0) -> void:
	if pena < 0.0:
		pena = minf(8.0, r.size.y * 0.35)
	var ys := [r.position.y, r.position.y + pena, r.end.y - pena, r.end.y]
	var alfas := [0.0, 1.0, 1.0, 0.0]
	var sinal := 1.0 if da_esquerda else -1.0
	var x0 := r.position.x if da_esquerda else r.end.x
	var x_fim := r.end.x if da_esquerda else r.position.x
	cheio = clampf(cheio, 0.0, r.size.x - 1.0)
	# Colunas: borda, fim do trecho cheio (a 85%: o plato nao le como caixa), ponta.
	var xs := [x0, x0 + sinal * cheio, x_fim]
	var forca := [1.0, 0.85 if cheio > 0.0 else 1.0, 0.0]
	for c in 2:
		if absf(float(xs[c + 1]) - float(xs[c])) < 0.01:
			continue
		for i in 3:
			var ca0 := alfa(veu(), a * float(alfas[i]) * float(forca[c]))
			var ca1 := alfa(veu(), a * float(alfas[i + 1]) * float(forca[c]))
			var cb0 := alfa(veu(), a * float(alfas[i]) * float(forca[c + 1]))
			var cb1 := alfa(veu(), a * float(alfas[i + 1]) * float(forca[c + 1]))
			ci.draw_polygon(PackedVector2Array([Vector2(xs[c], ys[i]), Vector2(xs[c + 1], ys[i]),
					Vector2(xs[c + 1], ys[i + 1]), Vector2(xs[c], ys[i + 1])]),
				PackedColorArray([ca0, cb0, cb1, ca1]))


## Barra fina com trilho. `valor` 0..1.
static func barra(ci: CanvasItem, r: Rect2, valor: float, cor: Color, a: float = 1.0) -> void:
	ci.draw_rect(r, alfa(Color(0.0, 0.0, 0.0, 0.55), a))
	var cheia := Rect2(r.position, Vector2(r.size.x * clampf(valor, 0.0, 1.0), r.size.y))
	if cheia.size.x > 0.05:
		ci.draw_rect(cheia, alfa(cor, a))


## Tecla desenhada: caixa clara com a letra escura. E o glifo de "aperte isto"
## de qualquer jogo atual; "[E]" em texto le como log de terminal.
##
## Devolve a largura usada, para quem empilha a acao ao lado.
static func tecla(ci: CanvasItem, p: Vector2, nome: String, tam: int = T_ROTULO,
		a: float = 1.0) -> float:
	if nome.begins_with(HudLayout.MARCA_PAD):
		return HudGlifos.desenhar(ci, p, nome.substr(1), tam, a)
	var f := semi()
	var alto := altura(f, tam) + 2.0
	var w := maxf(alto, largura(f, nome, tam) + 5.0)
	var r := Rect2(p, Vector2(w, alto))
	var pts := cantos(r, 1.8)
	poligono(ci, cantos(Rect2(r.position + Vector2(0.0, 0.8), r.size), 1.8),
		alfa(Color(0.0, 0.0, 0.0, 0.6), a))
	poligono(ci, pts, alfa(TEXTO, a))
	ci.draw_string(f, Vector2(r.position.x, r.position.y + 1.0 + f.get_ascent(tam)),
		nome, HORIZONTAL_ALIGNMENT_CENTER, w, tam, alfa(Color("15181a"), a))
	return w


static func largura_tecla(nome: String, tam: int = T_ROTULO) -> float:
	if nome.begins_with(HudLayout.MARCA_PAD):
		return HudGlifos.largura(nome.substr(1), tam)
	var f := semi()
	return maxf(altura(f, tam) + 2.0, largura(f, nome, tam) + 5.0)


## Losango de objetivo. A mesma marca no radar, na bussola e no rastreador: o
## jogador aprende uma forma so para "e para la".
static func losango(ci: CanvasItem, c: Vector2, r: float, cor: Color, a: float = 1.0) -> void:
	var pts := PackedVector2Array([c + Vector2(0.0, -r), c + Vector2(r, 0.0),
		c + Vector2(0.0, r), c + Vector2(-r, 0.0)])
	var fora := PackedVector2Array([c + Vector2(0.0, -r - 1.0), c + Vector2(r + 1.0, 0.0),
		c + Vector2(0.0, r + 1.0), c + Vector2(-r - 1.0, 0.0)])
	poligono(ci, fora, alfa(Color(0.0, 0.0, 0.0, 0.7), a))
	poligono(ci, pts, alfa(cor, a))


## Suaviza a entrada: 0..1 -> 0..1 com saida cubica.
static func saida_cubica(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


## Distancia como o jogador fala.
static func distancia(metros: float) -> String:
	# Acima de 100 m arredonda de 5 em 5: o numero que muda a cada passo puxa o
	# olho para o canto sem dizer nada novo.
	if metros < 100.0:
		return "%d m" % roundi(metros)
	if metros < 1000.0:
		return "%d m" % (roundi(metros / 5.0) * 5)
	return "%.1f km" % (metros / 1000.0)


## Blip vetorial: disco escuro, aro fino e o simbolo claro dentro. Nitido em 4K,
## ao contrario do icone de papel de 16 px que o cartao usava.
static func blip(ci: CanvasItem, centro: Vector2, icone: StringName, s: float = 1.0) -> void:
	# Desenhado em volta da origem e levado ao lugar pela transformacao: a mesma
	# forma serve ao radar (s 1) e ao mapa da pausa (maior).
	ci.draw_set_transform(centro, 0.0, Vector2(s, s))
	var c := Vector2.ZERO
	var r := 3.3
	var claro := Color("e6e1d6")
	var cor := claro
	match icone:
		&"casa_verde", &"parque":
			cor = OK
		&"mercado", &"bar":
			cor = Color("ffd27a")
	ci.draw_circle(c, r + 0.6, Color(0.0, 0.0, 0.0, 0.82), true, -1.0, true)
	ci.draw_arc(c, r, 0.0, TAU, 20, alfa(cor, 0.9), 0.45, true)
	match icone:
		&"casa", &"casa_verde":
			poligono(ci, PackedVector2Array([c + Vector2(0.0, -1.9),
				c + Vector2(1.7, -0.3), c + Vector2(1.2, -0.3), c + Vector2(1.2, 1.6),
				c + Vector2(-1.2, 1.6), c + Vector2(-1.2, -0.3), c + Vector2(-1.7, -0.3)]), cor)
		&"mercado":
			poligono(ci, PackedVector2Array([c + Vector2(-1.4, -0.6),
				c + Vector2(1.4, -0.6), c + Vector2(1.1, 1.7), c + Vector2(-1.1, 1.7)]), cor)
			ci.draw_arc(c + Vector2(0.0, -0.7), 0.8, PI, TAU, 8, cor, 0.4, true)
		&"bar":
			poligono(ci, PackedVector2Array([c + Vector2(-1.5, -1.5),
				c + Vector2(1.5, -1.5), c + Vector2(0.0, 0.2)]), cor)
			ci.draw_line(c + Vector2(0.0, 0.2), c + Vector2(0.0, 1.6), cor, 0.4, true)
			ci.draw_line(c + Vector2(-0.8, 1.6), c + Vector2(0.8, 1.6), cor, 0.4, true)
		&"telefone":
			ci.draw_rect(Rect2(c + Vector2(-0.9, -1.7), Vector2(1.8, 3.4)), cor, false, 0.4)
			ci.draw_circle(c + Vector2(0.0, 0.3), 0.45, cor, true, -1.0, true)
		&"parque":
			ci.draw_circle(c + Vector2(0.0, -0.5), 1.3, cor, true, -1.0, true)
			ci.draw_line(c + Vector2(0.0, 0.6), c + Vector2(0.0, 1.8), cor, 0.5, true)
		_:
			ci.draw_circle(c, 0.9, cor, true, -1.0, true)
	ci.draw_set_transform(Vector2.ZERO)
