## As pecas de desenho da carteira: botao com relevo, tecla, carimbo, selo,
## assinatura e o brilho do holograma.
##
## Moram fora de `criacao.gd` porque sao OBJETOS, e nao a tela: um botao de
## papelao com chanfro e o mesmo em qualquer campo, um carimbo e o mesmo quando
## cai na foto e quando cai no rodape. Com a conta espalhada nos ramos de cada
## widget, o relevo de um botao ficava diferente do relevo do vizinho — e e
## essa diferenca pequena que faz uma tela ler como montada por partes.
##
## Tudo e estatico e desenha num `CanvasItem` que chega por parametro, no
## espaco que ele estiver usando (inclusive com `draw_set_transform`).
class_name CarteiraArte
extends RefCounted


## Poligono de um retangulo com os cantos cortados em `c` pixels.
static func chanfro(r: Rect2, c: float) -> PackedVector2Array:
	var a := r.position
	var b := r.end
	return PackedVector2Array([
		Vector2(a.x + c, a.y), Vector2(b.x - c, a.y), Vector2(b.x, a.y + c),
		Vector2(b.x, b.y - c), Vector2(b.x - c, b.y), Vector2(a.x + c, b.y),
		Vector2(a.x, b.y - c), Vector2(a.x, a.y + c),
	])


## Botao de cartao: chanfro de um pixel, luz em cima, sombra embaixo, sombra
## projetada quando esta levantado.
##
## `altura` e o relevo: 1 em repouso, 2 sob o mouse (o botao sobe um pixel e a
## sombra alonga), 0 apertado (afunda e perde a sombra). E o mesmo gesto do
## botao de verdade, e e o que faz o clique ser sentido e nao so visto.
static func botao(ci: CanvasItem, r: Rect2, fundo: Color, borda: Color,
		altura: float = 1.0) -> Rect2:
	var sobe := clampf(altura - 1.0, -1.0, 1.0)
	var face := Rect2(r.position - Vector2(0.0, sobe), r.size)
	if altura > 0.0:
		ci.draw_colored_polygon(chanfro(Rect2(r.position + Vector2(1.0, 1.0 + altura * 0.5),
			r.size), 1.0), Color(0.05, 0.05, 0.03, 0.22 + 0.10 * altura))
	ci.draw_colored_polygon(chanfro(face, 1.0), fundo)
	ci.draw_rect(Rect2(face.position.x + 1.0, face.position.y, face.size.x - 2.0, 1.0),
		Color(1.0, 1.0, 0.97, 0.45))
	ci.draw_rect(Rect2(face.position.x + 1.0, face.end.y - 1.0, face.size.x - 2.0, 1.0),
		Color(0.0, 0.0, 0.0, 0.18))
	var contorno := chanfro(face, 1.0)
	contorno.append(contorno[0])
	ci.draw_polyline(contorno, borda, 1.0)
	return face


## Tecla de teclado com o glifo. Devolve a largura, para quem monta a fileira.
static func tecla(ci: CanvasItem, pos: Vector2, glifo: String, fonte: Font,
		tamanho: int, apertada: bool = false, destaque: bool = false) -> float:
	var larg := maxf(11.0, fonte.get_string_size(glifo, HORIZONTAL_ALIGNMENT_LEFT,
		-1.0, tamanho).x + 6.0) if fonte != null else 11.0
	var alto := 10.0
	var fundo := Color(0.86, 0.83, 0.74) if not destaque else Color(0.93, 0.80, 0.62)
	var desce := 1.0 if apertada else 0.0
	# A base escura embaixo e a espessura da tecla. Apertada, a face desce ate
	# ela.
	ci.draw_colored_polygon(chanfro(Rect2(pos + Vector2(0.0, 2.0), Vector2(larg, alto)),
		1.0), Color(0.16, 0.15, 0.12, 0.95))
	var face := Rect2(pos + Vector2(0.0, desce), Vector2(larg, alto))
	ci.draw_colored_polygon(chanfro(face, 1.0), fundo)
	ci.draw_rect(Rect2(face.position.x + 1.0, face.position.y, larg - 2.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.55))
	if fonte != null:
		ci.draw_string(fonte, Vector2(face.position.x, face.position.y + 8.0), glifo,
			HORIZONTAL_ALIGNMENT_CENTER, larg, tamanho, Color(0.13, 0.12, 0.10))
	return larg


## Carimbo de borracha: moldura dupla, duas linhas e tinta gasta.
##
## `escala` e o que o deixa CAIR: em repouso vale um; na batida vem de longe.
## Moldura, texto e tinta saem da mesma conta, entao o carimbo inteiro chega
## junto. Mesma receita do carimbo da ficha de cadastro, que e a tela anterior.
static func carimbo(ci: CanvasItem, base: Transform2D, centro: Vector2, tam: Vector2,
		graus: float, linha1: String, linha2: String, fonte1: Font, fonte2: Font,
		cor: Color, escala: float, forca: float) -> void:
	if forca <= 0.005:
		return
	ci.draw_set_transform_matrix(base * Transform2D(deg_to_rad(graus),
		Vector2.ONE * escala, 0.0, centro))
	var r := Rect2(-tam * 0.5, tam)
	var tinta := Color(cor.r, cor.g, cor.b, 0.80 * forca)
	ci.draw_rect(r, Color(cor.r, cor.g, cor.b, 0.08 * forca))
	ci.draw_rect(r, tinta, false, 2.0)
	ci.draw_rect(r.grow(-3.0), Color(tinta.r, tinta.g, tinta.b, tinta.a * 0.55), false, 1.0)
	if fonte1 != null:
		ci.draw_string(fonte1, Vector2(r.position.x, -1.0), linha1,
			HORIZONTAL_ALIGNMENT_CENTER, tam.x, UiEstilo.RE7_SIZE_TITLE, tinta)
	if fonte2 != null:
		ci.draw_string(fonte2, Vector2(r.position.x, r.end.y - 4.0), linha2,
			HORIZONTAL_ALIGNMENT_CENTER, tam.x, UiEstilo.RE7_SIZE_BODY, tinta)
	# Falhas de tinta: carimbo de borracha nunca pega por igual. Pontos de papel
	# sobre a moldura, sempre nos mesmos lugares.
	for k in 9:
		var x := r.position.x + fmod(float(k) * 37.3, r.size.x)
		var y := r.position.y + (0.0 if k % 2 == 0 else r.size.y - 1.0)
		ci.draw_rect(Rect2(x, y, 2.0, 1.0), Color(0.92, 0.90, 0.82, 0.8 * forca))
	ci.draw_set_transform_matrix(base)


## Selo redondo em tinta, meio por cima da foto: dois aneis, a estrela no meio e
## a marca de repeticao em volta. E o que diz "documento oficial" sem texto.
static func selo(ci: CanvasItem, centro: Vector2, raio: float, cor: Color) -> void:
	ci.draw_arc(centro, raio, 0.0, TAU, 28, cor, 1.0)
	ci.draw_arc(centro, raio - 3.0, 0.0, TAU, 24, Color(cor.r, cor.g, cor.b, cor.a * 0.7),
		1.0)
	for k in 16:
		var a := float(k) / 16.0 * TAU
		var p := centro + Vector2(cos(a), sin(a)) * (raio - 1.5)
		ci.draw_rect(Rect2(p - Vector2(0.5, 0.5), Vector2(1.0, 1.0)), cor)
	var estrela := PackedVector2Array()
	for k in 10:
		var a := -PI * 0.5 + float(k) / 10.0 * TAU
		var rr := (raio - 6.0) * (1.0 if k % 2 == 0 else 0.45)
		estrela.append(centro + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(estrela, Color(cor.r, cor.g, cor.b, cor.a * 0.8))


## A assinatura do titular: um rabisco que sai do NOME, sempre o mesmo para o
## mesmo nome. Cada letra vira uma lacada de altura e largura proprias; o
## primeiro nome vem maior, como quem assina com a inicial caprichada.
static func assinatura(ci: CanvasItem, origem: Vector2, largura: float, nome: String,
		cor: Color) -> void:
	var limpo := nome.strip_edges().to_upper()
	if limpo.is_empty():
		return
	var pontos := PackedVector2Array()
	var n := mini(limpo.length(), 14)
	var passo := largura / float(n + 1)
	var x := origem.x
	pontos.append(origem + Vector2(0.0, 1.0))
	for i in n:
		var c := limpo.unicode_at(i)
		var alto := 2.0 + float(c % 5) * (1.4 if i == 0 else 0.8)
		var torce := float((c * 7) % 3) - 1.0
		if limpo[i] == " ":
			x += passo * 0.6
			pontos.append(Vector2(x, origem.y + 1.0))
			continue
		pontos.append(Vector2(x + passo * 0.3, origem.y - alto))
		pontos.append(Vector2(x + passo * 0.6 + torce, origem.y + 1.5))
		pontos.append(Vector2(x + passo * 0.8, origem.y - alto * 0.4))
		x += passo
	# O traco final que sublinha, puxado para tras.
	pontos.append(Vector2(x + 4.0, origem.y + 2.0))
	pontos.append(Vector2(origem.x + largura * 0.35, origem.y + 3.0))
	ci.draw_polyline(pontos, cor, 1.0)


## O brilho do holograma passando por cima de um retangulo: uma faixa diagonal
## clara que atravessa de tempos em tempos. `fase` de 0 a 1 e a travessia; fora
## disso nao desenha nada. Recortado no retangulo, para nao vazar da foto.
static func brilho(ci: CanvasItem, r: Rect2, fase: float, forca: float = 1.0) -> void:
	if fase <= 0.0 or fase >= 1.0:
		return
	var largura := r.size.x * 0.22
	var x := lerpf(r.position.x - r.size.y - largura, r.end.x + largura, fase)
	var faixa := PackedVector2Array([
		Vector2(x, r.end.y), Vector2(x + largura, r.end.y),
		Vector2(x + largura + r.size.y * 0.8, r.position.y),
		Vector2(x + r.size.y * 0.8, r.position.y)])
	var caixa := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
		Vector2(r.position.x, r.end.y)])
	var pedacos := Geometry2D.intersect_polygons(faixa, caixa)
	var a := sin(fase * PI) * 0.16 * forca
	for p: PackedVector2Array in pedacos:
		if p.size() >= 3:
			ci.draw_colored_polygon(p, Color(0.86, 0.96, 1.0, a))
