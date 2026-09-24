## Botoes de controle desenhados em vetor (item 2.8 do PLANO_HUD_AAA).
##
## Antes o botao era a LETRA dele numa tecla de teclado: "A" numa tecla clara
## lia como a tecla A, e "LB" como uma tecla chamada LB. Todo jogo atual desenha
## o botao do controle que o jogador tem na mao — botao de face redondo com a cor
## dele, ombro largo, gatilho de topo redondo, analogico com o anel.
##
## Duas familias, escolhidas pelo nome que o SDL da ao controle:
##
##     XBOX          A verde, B vermelho, X azul, Y amarelo; LB RB LT RT
##     PLAYSTATION   cruz, circulo, quadrado, triangulo; L1 R1 L2 R2
##
## Os nomes de ENTRADA sao sempre os do Xbox (posicao, como o Godot e o
## `Controle` nomeiam): A embaixo, B a direita, X a esquerda, Y em cima. Quem
## troca o desenho e esta classe, e ninguem mais precisa saber do DualSense.
##
## O desenho e escuro de proposito: a tecla de teclado e clara (`HudTema.tecla`),
## o botao e escuro com o simbolo colorido — as duas nunca se confundem na mesma
## dica, e o botao se parece com o botao de verdade.
class_name HudGlifos
extends RefCounted

const XBOX := 0
const PLAYSTATION := 1

const BOTOES := ["A", "B", "X", "Y", "LB", "RB", "LT", "RT", "L3", "R3", "LS", "RS",
	"SELECT", "START"]

const COR_XBOX := {"A": Color("74c850"), "B": Color("ec5d4e"), "X": Color("4a97e6"),
	"Y": Color("f2c434")}
## Cores do simbolo no controle de PS (cruz azul, circulo vermelho, quadrado
## rosa, triangulo verde), um pouco mais claras para ler sobre o fundo escuro.
const COR_PS := {"A": Color("93b6ff"), "B": Color("ff7474"), "X": Color("f094d8"),
	"Y": Color("4fd8b6")}
const NOME_PS := {"LB": "L1", "RB": "R1", "LT": "L2", "RT": "R2"}

const FUNDO := Color(0.07, 0.08, 0.09, 0.94)
const BORDA := Color(1.0, 1.0, 1.0, 0.24)
const VAO := 2.0

## Captura: `--hud-pad=ps` ou `--hud-pad=xbox` fixa a familia sem controle ligado.
static var forcar := -1


static func familia() -> int:
	if forcar >= 0:
		return forcar
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return XBOX
	return familia_do_nome(Input.get_joy_name(pads[0]))


## Puro, para o teste: o nome que o SDL reporta. "Wireless Controller" e o nome
## do DualShock 4 no Windows; "PS5 Controller" e "DualSense" o do 5.
static func familia_do_nome(nome: String) -> int:
	var n := nome.to_lower()
	for chave: String in ["playstation", "dualshock", "dualsense", "ps3", "ps4", "ps5",
			"sony", "wireless controller"]:
		if n.contains(chave):
			return PLAYSTATION
	return XBOX


## "LT RT" tambem vale: varios botoes na mesma dica, lado a lado.
static func eh_glifo(nome: String) -> bool:
	var partes := nome.split(" ", false)
	if partes.is_empty():
		return false
	for p: String in partes:
		if not BOTOES.has(p):
			return false
	return true


static func _alto(tam: int) -> float:
	return HudTema.altura(HudTema.semi(), tam) + 2.0


static func _largura_um(b: String, tam: int) -> float:
	var h := _alto(tam)
	match b:
		"LB", "RB":
			return roundf(h * 1.75)
		"LT", "RT":
			return roundf(h * 1.35)
		"SELECT", "START":
			return roundf(h * 1.5)
	return h


static func largura(nome: String, tam: int) -> float:
	var w := 0.0
	var partes := nome.split(" ", false)
	for i in partes.size():
		w += _largura_um(partes[i], tam) + (VAO if i > 0 else 0.0)
	return w


## Desenha e devolve a largura usada — o mesmo contrato de `HudTema.tecla`.
static func desenhar(ci: CanvasItem, p: Vector2, nome: String, tam: int, a: float = 1.0) -> float:
	var x := p.x
	var partes := nome.split(" ", false)
	for i in partes.size():
		if i > 0:
			x += VAO
		x += _um(ci, Vector2(x, p.y), partes[i], tam, a)
	return x - p.x


static func _um(ci: CanvasItem, p: Vector2, b: String, tam: int, a: float) -> float:
	var h := _alto(tam)
	var w := _largura_um(b, tam)
	var r := Rect2(p, Vector2(w, h))
	var c := r.get_center()
	var ps := familia() == PLAYSTATION
	match b:
		"A", "B", "X", "Y":
			var raio := h * 0.5
			_disco(ci, c, raio, a)
			var cor: Color = (COR_PS if ps else COR_XBOX)[b]
			if ps:
				_simbolo_ps(ci, c, raio * 0.46, b, HudTema.alfa(cor, a))
			else:
				_rotulo(ci, r, b, tam, HudTema.alfa(cor, a), 800)
		"LB", "RB", "LT", "RT":
			var gatilho := b.ends_with("T")
			var pts := _forma_ombro(r, gatilho, b.begins_with("L"))
			HudTema.poligono(ci, _deslocar(pts, Vector2(0.0, 0.8)), Color(0.0, 0.0, 0.0, 0.55 * a))
			HudTema.poligono(ci, pts, HudTema.alfa(FUNDO, a))
			var borda := pts.duplicate()
			borda.append(pts[0])
			ci.draw_polyline(borda, HudTema.alfa(BORDA, a), 0.5, true)
			_rotulo(ci, r, String(NOME_PS.get(b, b)) if ps else b, maxi(5, tam - 1),
				HudTema.alfa(HudTema.TEXTO, a), 700)
		"L3", "R3", "LS", "RS":
			var raio := h * 0.5
			_disco(ci, c, raio, a)
			# O anel concavo do topo do analogico.
			ci.draw_arc(c, raio * 0.64, 0.0, TAU, 24, HudTema.alfa(HudTema.TEXTO, 0.32 * a), 0.5, true)
			var rot := b.substr(0, 1) if b.ends_with("S") else b
			_rotulo(ci, r, rot, maxi(5, tam - (2 if rot.length() > 1 else 1)),
				HudTema.alfa(HudTema.TEXTO, a), 700)
		"SELECT", "START":
			var pts := HudTema.cantos(r.grow_individual(0.0, -1.0, 0.0, -1.0), h * 0.5 - 1.3)
			HudTema.poligono(ci, _deslocar(pts, Vector2(0.0, 0.8)), Color(0.0, 0.0, 0.0, 0.55 * a))
			HudTema.poligono(ci, pts, HudTema.alfa(FUNDO, a))
			var borda := pts.duplicate()
			borda.append(pts[0])
			ci.draw_polyline(borda, HudTema.alfa(BORDA, a), 0.5, true)
			_icone_meio(ci, c, h * 0.26, b == "START", ps, HudTema.alfa(HudTema.TEXTO, a))
	return w


static func _disco(ci: CanvasItem, c: Vector2, raio: float, a: float) -> void:
	ci.draw_circle(c + Vector2(0.0, 0.8), raio, Color(0.0, 0.0, 0.0, 0.55 * a), true, -1.0, true)
	ci.draw_circle(c, raio, HudTema.alfa(FUNDO, a), true, -1.0, true)
	ci.draw_arc(c, raio - 0.25, 0.0, TAU, 28, HudTema.alfa(BORDA, a), 0.5, true)


static func _rotulo(ci: CanvasItem, r: Rect2, t: String, tam: int, cor: Color, peso: int) -> void:
	var f := HudTema.fonte(peso, 0)
	var base := r.position.y + (r.size.y - f.get_height(tam)) * 0.5 + f.get_ascent(tam)
	ci.draw_string(f, Vector2(r.position.x, base), t, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, tam, cor)


## Cruz, circulo, quadrado, triangulo — em traco, como no controle.
static func _simbolo_ps(ci: CanvasItem, c: Vector2, s: float, b: String, cor: Color) -> void:
	var traco := maxf(0.55, s * 0.32)
	match b:
		"A":
			ci.draw_line(c + Vector2(-s, -s), c + Vector2(s, s), cor, traco, true)
			ci.draw_line(c + Vector2(-s, s), c + Vector2(s, -s), cor, traco, true)
		"B":
			ci.draw_arc(c, s * 1.02, 0.0, TAU, 24, cor, traco, true)
		"X":
			var q := s * 0.9
			ci.draw_polyline(PackedVector2Array([c + Vector2(-q, -q), c + Vector2(q, -q),
				c + Vector2(q, q), c + Vector2(-q, q), c + Vector2(-q, -q)]), cor, traco, true)
		"Y":
			var t := s * 1.15
			var o := c + Vector2(0.0, t * 0.12)
			ci.draw_polyline(PackedVector2Array([o + Vector2(0.0, -t), o + Vector2(t * 0.87, t * 0.5),
				o + Vector2(-t * 0.87, t * 0.5), o + Vector2(0.0, -t)]), cor, traco, true)


## Ombro: retangulo de cantos baixos com o canto de FORA arredondado, como o
## bumper visto de frente. Gatilho: topo inteiro redondo, base reta.
static func _forma_ombro(r: Rect2, gatilho: bool, esquerdo: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var baixo := 1.2
	var alto := r.size.y * (0.48 if gatilho else 0.42)
	var fora := alto
	var dentro := r.size.y * (0.48 if gatilho else 0.22)
	var r_esq := fora if esquerdo else dentro
	var r_dir := dentro if esquerdo else fora
	# Cantos: topo-dir, baixo-dir, baixo-esq, topo-esq (sentido horario).
	var arcos := [
		[Vector2(r.end.x - r_dir, r.position.y + r_dir), r_dir, -PI * 0.5],
		[Vector2(r.end.x - baixo, r.end.y - baixo), baixo, 0.0],
		[Vector2(r.position.x + baixo, r.end.y - baixo), baixo, PI * 0.5],
		[Vector2(r.position.x + r_esq, r.position.y + r_esq), r_esq, PI],
	]
	for arco: Array in arcos:
		for k in 5:
			var ang := float(arco[2]) + float(k) / 4.0 * PI * 0.5
			pts.append((arco[0] as Vector2) + Vector2(cos(ang), sin(ang)) * float(arco[1]))
	return pts


static func _deslocar(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var saida := PackedVector2Array()
	for q in pts:
		saida.append(q + d)
	return saida


## Icone do botao do meio: Menu (tres linhas) e View (duas janelas) no Xbox;
## Options (tres linhas) e Create (tres raios) no PS.
static func _icone_meio(ci: CanvasItem, c: Vector2, s: float, start: bool, ps: bool,
		cor: Color) -> void:
	var traco := maxf(0.5, s * 0.3)
	if start:
		for k in 3:
			var y := c.y + (float(k) - 1.0) * s * 0.7
			ci.draw_line(Vector2(c.x - s, y), Vector2(c.x + s, y), cor, traco, true)
	elif ps:
		for ang: float in [-0.5, 0.0, 0.5]:
			var d := Vector2(sin(ang), -cos(ang))
			ci.draw_line(c + d * s * 0.3, c + d * s * 1.1, cor, traco, true)
	else:
		var q := s * 0.62
		ci.draw_rect(Rect2(c + Vector2(-q * 1.5, -q * 1.1), Vector2(q * 1.7, q * 1.5)), cor, false, traco)
		ci.draw_rect(Rect2(c + Vector2(-q * 0.2, -q * 0.4), Vector2(q * 1.7, q * 1.5)), cor, false, traco)
