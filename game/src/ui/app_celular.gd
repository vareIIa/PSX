## Base dos aplicativos coloridos do celular: Trampo e iWeed.
##
## O aparelho e de 1998 e as telas de fabrica dele continuam no LCD verde. O que
## vem baixado e outra coisa: cada aplicativo pinta a propria tela inteira, com a
## cor e a letra da marca dele — vetor, que no modo MODERNO rasteriza na
## resolucao da janela e le nitido em 4K. E a piada do iWeed no tijolao, e e
## tambem a unica forma de caber uma agenda de entregas em 146 por 186.
##
## O celular chama `desenhar` com o visor, e repassa tecla e acao. Cada app so
## sabe desenhar a si mesmo e responder a navegacao; abrir, fechar e travar o
## jogador continuam sendo do celular.
class_name AppCelular
extends RefCounted

const L := 146.0
const A := 186.0
## Barra do aparelho (rede, hora, bateria), desenhada pelo celular por cima.
const TOPO := 11.0

var v: Control
var f_reg: Font
var f_semi: Font
var f_bold: Font
var piscar := 0.0
var _aviso := ""
var _aviso_cor := Color.WHITE
var _aviso_t := 0.0


func _init() -> void:
	f_reg = UiEstilo.fonte_re7(UiEstilo.RE7_WEIGHT_REGULAR)
	f_semi = UiEstilo.fonte_re7(UiEstilo.RE7_WEIGHT_SEMIBOLD)
	f_bold = UiEstilo.fonte_re7(700)


# --- ciclo ---------------------------------------------------------------------

func abrir() -> void:
	pass


func desenhar(_visor: Control) -> void:
	pass


## `nome`: cima, baixo, esq, dir, ok, voltar. Devolve false quando o app quer
## voltar para a grade de icones.
func acao(_nome: StringName) -> bool:
	return true


## Tecla crua (letras, digitos, apagar). Devolve true quando consumiu.
func tecla(_ev: InputEventKey) -> bool:
	return false


## Se o app esta com um campo de texto em foco. O celular deixa as letras virem
## para ca antes de tratar C (fechar) e E (usar).
func digitando() -> bool:
	return false


func processar(delta: float) -> void:
	piscar += delta
	_aviso_t = maxf(0.0, _aviso_t - delta)


func aviso(texto: String, cor: Color) -> void:
	_aviso = texto
	_aviso_cor = cor
	_aviso_t = 2.2


# --- kit de desenho --------------------------------------------------------------

func t(p: Vector2, texto: String, tam: int, cor: Color, fonte: Font = null,
		largura: float = -1.0, alin := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	v.draw_string(fonte if fonte != null else f_reg, p, texto, alin, largura, tam, cor)


func w(texto: String, tam: int, fonte: Font = null) -> float:
	return (fonte if fonte != null else f_reg).get_string_size(texto,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x


func cortar(texto: String, tam: int, largura: float, fonte: Font = null) -> String:
	var f := fonte if fonte != null else f_reg
	if f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x <= largura:
		return texto
	var s := texto
	while s.length() > 1 and f.get_string_size(s + "...", HORIZONTAL_ALIGNMENT_LEFT,
			-1, tam).x > largura:
		s = s.substr(0, s.length() - 1)
	return s.strip_edges() + "..."


func ret(r: Rect2, cor: Color) -> void:
	v.draw_rect(r, cor)


static func cantos(r: Rect2, raio: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	# Um fio abaixo da meia altura: com o raio exatamente na metade, os dois
	# cantos do mesmo lado caem no mesmo centro, o poligono ganha vertice
	# repetido e a triangulacao falha (a barra de satisfacao dos clientes).
	var rr := minf(raio, minf(r.size.x, r.size.y) * 0.5 - 0.02)
	if rr <= 0.05:
		return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y)])
	var cs := [Vector2(r.end.x - rr, r.position.y + rr), Vector2(r.end.x - rr, r.end.y - rr),
		Vector2(r.position.x + rr, r.end.y - rr), Vector2(r.position.x + rr, r.position.y + rr)]
	for k in 4:
		var a0 := -PI * 0.5 + float(k) * PI * 0.5
		for s in 5:
			var a := a0 + float(s) / 4.0 * PI * 0.5
			pts.append(cs[k] + Vector2(cos(a), sin(a)) * rr)
	return pts


func arred(r: Rect2, raio: float, cor: Color, cheio := true, largura := 0.5) -> void:
	var pts := cantos(r, raio)
	if cheio:
		v.draw_colored_polygon(pts, cor)
	else:
		pts.append(pts[0])
		v.draw_polyline(pts, cor, largura, true)


func grad_v(r: Rect2, cima: Color, baixo: Color) -> void:
	v.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
		Vector2(r.position.x, r.end.y)]), PackedColorArray([cima, cima, baixo, baixo]))


func grad_h(r: Rect2, esq: Color, dir: Color) -> void:
	v.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
		Vector2(r.position.x, r.end.y)]), PackedColorArray([esq, dir, dir, esq]))


## Cor estavel por pessoa, para o avatar de iniciais.
static func cor_de(id: int) -> Color:
	var h := float(posmod(id * 2654435761, 360)) / 360.0
	return Color.from_hsv(h, 0.45, 0.62)


## Circulo com as iniciais. Lista de pessoa sem retrato em cada linha: quarenta
## retratos por tela custariam quarenta texturas montadas a cada busca.
func avatar(c: Vector2, raio: float, nome: String, cor: Color) -> void:
	v.draw_circle(c, raio, cor)
	# So palavras que comecam com letra: "JOTA (FRANCISCA)" dava "J(".
	var partes: Array[String] = []
	for p: String in nome.strip_edges().split(" ", false):
		var letra := p.substr(0, 1).to_upper()
		if letra >= "A" and letra <= "Z":
			partes.append(p)
	var ini := ""
	if partes.size() > 0:
		ini += partes[0].substr(0, 1)
	if partes.size() > 1:
		ini += partes[partes.size() - 1].substr(0, 1)
	var tam := maxi(5, int(raio * 1.05))
	t(Vector2(c.x - raio, c.y + float(tam) * 0.36), ini.to_upper(), tam,
		Color(1, 1, 1, 0.95), f_semi, raio * 2.0, HORIZONTAL_ALIGNMENT_CENTER)


func estrelas(p: Vector2, valor: float, raio: float, cor: Color, apagada: Color) -> void:
	for k in 5:
		var c := p + Vector2(float(k) * raio * 2.3 + raio, 0.0)
		var pts := PackedVector2Array()
		for s in 10:
			var a := -PI * 0.5 + float(s) * PI / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * (raio if s % 2 == 0 else raio * 0.45))
		var cheia := clampf(valor - float(k), 0.0, 1.0)
		v.draw_colored_polygon(pts, apagada)
		if cheia >= 0.99:
			v.draw_colored_polygon(pts, cor)
		elif cheia >= 0.49:
			# Meia estrela: a metade esquerda do mesmo poligono.
			var meia := PackedVector2Array()
			for q in pts:
				meia.append(Vector2(minf(q.x, c.x), q.y))
			v.draw_colored_polygon(meia, cor)


## Etiqueta de canto redondo. Devolve a largura.
func chip(p: Vector2, texto: String, fundo: Color, cor: Color, tam := 6) -> float:
	var largura := w(texto, tam, f_semi) + 6.0
	arred(Rect2(p.x, p.y - float(tam) - 1.0, largura, float(tam) + 4.0), 2.0, fundo)
	t(Vector2(p.x + 3.0, p.y + 0.5), texto, tam, cor, f_semi)
	return largura


func barra(r: Rect2, fracao: float, fundo: Color, cor: Color) -> void:
	arred(r, r.size.y * 0.5, fundo)
	if fracao > 0.01:
		arred(Rect2(r.position, Vector2(maxf(r.size.y, r.size.x * clampf(fracao, 0.0, 1.0)),
			r.size.y)), r.size.y * 0.5, cor)


## Teclas no rodape, da direita para a esquerda: [["E", "ACEITAR"], ...].
func rodape(itens: Array, fundo: Color, cor: Color, fraca: Color) -> void:
	var y := A - 7.0
	# Faixa cheia sob as teclas e um degrade curto acima: o conteudo que rola
	# passa por baixo sem uma letra encostar na outra.
	grad_v(Rect2(0.0, A - 20.0, L, 6.0), Color(fundo, 0.0), fundo)
	ret(Rect2(0.0, A - 14.0, L, 14.0), fundo)
	var x := L - 4.0
	for i in range(itens.size() - 1, -1, -1):
		var item: Array = itens[i]
		var rotulo := String(item[1])
		var wr := w(rotulo, 6, f_semi)
		x -= wr
		t(Vector2(x, y + 2.2), rotulo, 6, fraca, f_semi)
		x -= 2.5
		var letra := String(item[0])
		var wl := maxf(8.0, w(letra, 6, f_semi) + 4.5)
		x -= wl
		var r := Rect2(x, y - 4.2, wl, 8.4)
		arred(r, 1.6, Color(cor, 0.1))
		arred(r, 1.6, Color(cor, 0.6), false, 0.45)
		t(Vector2(x, y + 2.2), letra, 6, cor, f_semi, wl, HORIZONTAL_ALIGNMENT_CENTER)
		x -= 6.0
		if x < 4.0:
			break


func desenhar_aviso() -> void:
	if _aviso_t <= 0.0:
		return
	var a := clampf(_aviso_t / 0.3, 0.0, 1.0)
	var largura := minf(L - 16.0, w(_aviso, 7, f_semi) + 16.0)
	var r := Rect2((L - largura) * 0.5, A - 40.0, largura, 15.0)
	arred(r, 7.5, Color(0.05, 0.06, 0.06, 0.92 * a))
	arred(r, 7.5, Color(_aviso_cor, 0.7 * a), false, 0.6)
	t(Vector2(r.position.x, r.position.y + 10.2), _aviso, 7, Color(_aviso_cor, a), f_semi,
		r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


## Barra de status do aparelho, na letra do app: rede, hora, bateria. A barra de
## fabrica e de pixel e cortava o topo das letras em cima da tela colorida.
func barra_status(visor: Control, fundo: Color, cor: Color, bateria: float) -> void:
	v = visor
	ret(Rect2(0.0, 0.0, L, TOPO), fundo)
	for k in 4:
		var h := 1.6 + float(k) * 1.2
		var cheia := k < 2
		ret(Rect2(5.0 + float(k) * 2.4, 8.0 - h, 1.6, h), Color(cor, 1.0 if cheia else 0.3))
	t(Vector2(17.0, 8.0), "REDE", 5, Color(cor, 0.75), f_semi)
	var hora := WorldState.relogio.texto() if WorldState.relogio != null else "--:--"
	t(Vector2(0.0, 8.3), hora, 7, cor, f_semi, L, HORIZONTAL_ALIGNMENT_CENTER)
	var r := Rect2(L - 18.0, 3.0, 11.0, 5.4)
	arred(r, 1.2, Color(cor, 0.8), false, 0.5)
	ret(Rect2(r.end.x + 0.4, 4.6, 1.0, 2.2), Color(cor, 0.8))
	ret(Rect2(r.position.x + 1.0, r.position.y + 1.0, (r.size.x - 2.0) * clampf(bateria, 0.0, 1.0),
		r.size.y - 2.0), Color(cor, 0.9))


# --- glifos ---------------------------------------------------------------------

## Folha de maconha de sete pontas. Estatica para o HUD usar tambem.
static func folha(ci: CanvasItem, c: Vector2, raio: float, cor: Color) -> void:
	var angulos := [0.0, -0.55, 0.55, -1.12, 1.12, -1.75, 1.75]
	var tamanhos := [1.0, 0.86, 0.86, 0.66, 0.66, 0.42, 0.42]
	for k in angulos.size():
		var a: float = angulos[k]
		var comp: float = raio * float(tamanhos[k])
		var dir := Vector2(sin(a), -cos(a))
		var lado := Vector2(-dir.y, dir.x)
		var base := c + Vector2(0.0, raio * 0.28)
		var larg := comp * 0.2
		ci.draw_colored_polygon(PackedVector2Array([base,
			base + dir * comp * 0.45 + lado * larg, base + dir * comp,
			base + dir * comp * 0.45 - lado * larg]), cor)
	ci.draw_line(c + Vector2(0.0, raio * 0.28), c + Vector2(0.0, raio * 0.95), cor,
		maxf(0.5, raio * 0.09), true)


static func maleta(ci: CanvasItem, c: Vector2, raio: float, cor: Color) -> void:
	var r := Rect2(c.x - raio, c.y - raio * 0.5, raio * 2.0, raio * 1.45)
	ci.draw_colored_polygon(cantos(r, raio * 0.22), cor)
	var alca := PackedVector2Array([Vector2(c.x - raio * 0.4, r.position.y),
		Vector2(c.x - raio * 0.4, r.position.y - raio * 0.38),
		Vector2(c.x + raio * 0.4, r.position.y - raio * 0.38),
		Vector2(c.x + raio * 0.4, r.position.y)])
	ci.draw_polyline(alca, cor, maxf(0.5, raio * 0.18), true)
