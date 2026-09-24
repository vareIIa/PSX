## Base dos apps do iPhone do jogo desenhados no iOS 4: a barra de navegacao
## azul-acinzentada com o botao de voltar em seta, a tabela agrupada sobre o
## fundo listrado, as celulas brancas com a seta cinza, e a lista que rola com
## a tecla, a roda e o arrasto.
##
## Cada app diz quantas linhas tem a tela de agora (`linhas`), desenha cada uma
## e responde ao toque; a selecao, a rolagem e o voltar pela barra moram aqui.
class_name AppIos
extends AppCelular

const NAV := 17.0
const NAV_CIMA := Color("b8c5d6")
const NAV_BAIXO := Color("6e84a3")
const NAV_LINHA := Color("2d3f5a")
const BOTAO_NAV := Color("4f6a92")
const LISTRA_A := Color("c5ccd4")
const LISTRA_B := Color("cbd2d9")
const TINTA := Color("1a1d22")
const FRACA := Color("6d7683")
const AZUL_IOS := Color("385487")
const AZUL := Color("2a6fd6")
const DIVISA := Color("d0d4da")
const SELECIONADA := Color("0a6cf5")

## O app pediu para sair pela raiz (o botao de voltar da barra na primeira
## tela): o `Celular` volta para o inicio.
var quer_sair: bool = false
var sel: int = 0
var rol: float = 0.0
var rol_alvo: float = 0.0


func processar(delta: float) -> void:
	super.processar(delta)
	rol = lerpf(rol, rol_alvo, minf(1.0, delta * 14.0))


# --- barra e fundo --------------------------------------------------------------

## A barra de cima. Com `voltar` nao vazio, o botao em seta a esquerda.
func nav(titulo: String, voltar: String = "", direita: String = "") -> void:
	grad_v(Rect2(0.0, TOPO, L, NAV), NAV_CIMA, NAV_BAIXO)
	ret(Rect2(0.0, TOPO, L, 0.5), Color(1, 1, 1, 0.45))
	ret(Rect2(0.0, TOPO + NAV - 0.6, L, 0.6), NAV_LINHA)
	var nome := cortar(titulo, 7, L - 74.0, f_bold)
	t(Vector2(0.0, TOPO + 12.6), nome, 7, Color(0, 0, 0, 0.35), f_bold, L, HORIZONTAL_ALIGNMENT_CENTER)
	t(Vector2(0.0, TOPO + 12.0), nome, 7, Color.WHITE, f_bold, L, HORIZONTAL_ALIGNMENT_CENTER)
	if not voltar.is_empty():
		var rotulo := cortar(voltar, 5, 30.0, f_semi)
		var b := Rect2(4.0, TOPO + 3.5, maxf(22.0, w(rotulo, 5, f_semi) + 10.0), 10.0)
		var pts := PackedVector2Array([Vector2(b.position.x, b.position.y + b.size.y * 0.5),
			Vector2(b.position.x + 5.0, b.position.y), Vector2(b.end.x - 1.5, b.position.y),
			Vector2(b.end.x, b.position.y + 1.5), Vector2(b.end.x, b.end.y - 1.5),
			Vector2(b.end.x - 1.5, b.end.y), Vector2(b.position.x + 5.0, b.end.y)])
		v.draw_colored_polygon(pts, BOTAO_NAV.darkened(0.25) if sob_dedo(b.grow(3.0)) else BOTAO_NAV)
		pts.append(pts[0])
		v.draw_polyline(pts, Color(NAV_LINHA, 0.8), 0.5, true)
		t(Vector2(b.position.x + 4.0, b.position.y + 7.4), rotulo, 5, Color.WHITE, f_semi,
			b.size.x - 4.0, HORIZONTAL_ALIGNMENT_CENTER)
		alvo(b.grow(3.0), [&"nav_voltar"])
	if not direita.is_empty():
		var e := Rect2(L - 4.0 - maxf(22.0, w(direita, 5, f_semi) + 8.0), TOPO + 3.5,
			maxf(22.0, w(direita, 5, f_semi) + 8.0), 10.0)
		arred(e, 2.0, BOTAO_NAV.darkened(0.25) if sob_dedo(e.grow(3.0)) else BOTAO_NAV)
		arred(e, 2.0, Color(NAV_LINHA, 0.8), false, 0.5)
		t(Vector2(e.position.x, e.position.y + 7.4), direita, 5, Color.WHITE, f_semi, e.size.x,
			HORIZONTAL_ALIGNMENT_CENTER)
		alvo(e.grow(3.0), [&"nav_direita"])


## O fundo das tabelas agrupadas do iOS: listras verticais finas.
func fundo_listrado() -> void:
	ret(Rect2(0.0, 0.0, L, alto_tela), LISTRA_A)
	var x := 0.0
	while x < L:
		ret(Rect2(x, 0.0, 1.1, alto_tela), LISTRA_B)
		x += 2.6


## Uma celula de tabela agrupada: branca, com os cantos arredondados so na
## primeira e na ultima do grupo, a borda cinza e a divisa entre elas.
func celula(r: Rect2, primeira: bool, ultima: bool, marcada: bool) -> void:
	var raio := 4.0
	var pts := AppCelular.cantos(r, raio)
	if not primeira or not ultima:
		# Os cantos do meio do grupo sao retos: corta o arredondado de cima ou de
		# baixo trocando pelos vertices do retangulo.
		var reto := PackedVector2Array()
		for p: Vector2 in pts:
			var q := p
			if not primeira and p.y < r.position.y + raio:
				q.y = r.position.y
				q.x = r.position.x if p.x < r.get_center().x else r.end.x
			if not ultima and p.y > r.end.y - raio:
				q.y = r.end.y
				q.x = r.position.x if p.x < r.get_center().x else r.end.x
			reto.append(q)
		pts = reto
	v.draw_colored_polygon(pts, Color.WHITE)
	if marcada:
		var cores := PackedColorArray()
		for p: Vector2 in pts:
			cores.append(Color("058cf5").lerp(Color("015de6"), (p.y - r.position.y) / r.size.y))
		v.draw_polygon(pts, cores)
	var borda := pts.duplicate()
	borda.append(pts[0])
	v.draw_polyline(borda, Color("aab0b8"), 0.5, true)
	if not ultima:
		ret(Rect2(r.position.x, r.end.y - 0.3, r.size.x, 0.5), Color("d9dce1"))


## A seta cinza da direita da celula.
func seta(p: Vector2, cor: Color = Color("8e949c")) -> void:
	v.draw_polyline(PackedVector2Array([p + Vector2(-1.4, -2.4), p + Vector2(1.0, 0.0),
		p + Vector2(-1.4, 2.4)]), cor, 0.8, true)


## Uma linha de tabela agrupada com titulo, detalhe a direita e seta.
func linha_de_grupo(r: Rect2, i: int, n: int, titulo: String, detalhe: String = "",
		com_seta: bool = true, id: Variant = null, marcavel: bool = true) -> void:
	var marcada := marcavel and ((foco_visivel and sel == i) or sob_dedo(r))
	celula(r, i == 0, i == n - 1, marcada)
	var tinta := Color.WHITE if marcada else TINTA
	t(Vector2(r.position.x + 7.0, r.position.y + r.size.y * 0.5 + 2.4), cortar(titulo, 7,
		r.size.x - 50.0, f_bold), 7, tinta, f_bold)
	if not detalhe.is_empty():
		t(Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 2.4), cortar(detalhe, 6, 60.0), 6,
			Color.WHITE if marcada else AZUL_IOS, f_reg,
			r.size.x - (14.0 if com_seta else 7.0), HORIZONTAL_ALIGNMENT_RIGHT)
	if com_seta:
		seta(Vector2(r.end.x - 6.0, r.get_center().y), Color.WHITE if marcada else Color("8e949c"))
	if id != null:
		alvo(r, id)


# --- lista que rola ---------------------------------------------------------------

## Leva a rolagem ate a linha escolhida (y e altura dela no conteudo, sem a
## rolagem) caber na janela `alto` que a lista tem.
func seguir(y: float, h: float, alto: float, total: float) -> void:
	if y < rol_alvo:
		rol_alvo = y
	elif y + h > rol_alvo + alto:
		rol_alvo = y + h - alto
	rol_alvo = clampf(rol_alvo, 0.0, maxf(0.0, total - alto))


func arrastar(_desde: Vector2, delta: Vector2, _fim: bool) -> bool:
	rol_alvo = maxf(0.0, rol_alvo - delta.y)
	rol = rol_alvo
	return true


func rolar(passos: float) -> bool:
	rol_alvo = maxf(0.0, rol_alvo + passos * 18.0)
	return true


func tocar(id: Variant) -> bool:
	if id is Array and (id as Array).size() > 0 and (id as Array)[0] == &"nav_voltar":
		if not acao(&"voltar"):
			quer_sair = true
		return true
	return false


## Barra de progresso fina do iOS (armazenamento, bateria).
func barra_ios(r: Rect2, fracao: float, cor: Color) -> void:
	arred(r, r.size.y * 0.5, Color("c9ced6"))
	arred(Rect2(r.position, Vector2(maxf(r.size.y, r.size.x * clampf(fracao, 0.0, 1.0)), r.size.y)),
		r.size.y * 0.5, cor)
	arred(Rect2(r.position.x, r.position.y, r.size.x, r.size.y * 0.45), r.size.y * 0.3,
		Color(1, 1, 1, 0.25))
