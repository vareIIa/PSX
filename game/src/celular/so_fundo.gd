## O que o sistema do iPhone do jogo desenha por conta propria: o fundo de tela,
## a barra de status e a data por extenso.
##
## O fundo e desenhado e nao foto: tres fundos de tela escuros (a tela a um palmo
## do rosto, de noite, nao pode ser um papel claro — ela e a luz que pinta a mao),
## com o desfoque de lente do iOS feito de circulos em camadas.
class_name SoFundo
extends RefCounted

const NOMES := ["Gotas", "Noite", "Aurora"]
## A barra de status: altura e a cor do texto.
const BARRA := 10.0

## O dia 1 da partida e uma sexta-feira (`Relogio.PRIMEIRO_DIA_DA_SEMANA`): a
## sexta, 24 de setembro de 2010, a do iPhone 4 na mao de todo mundo.
const DIA_BASE := 24
const DIAS_DO_MES := 30
const SEMANA := ["segunda-feira", "terca-feira", "quarta-feira", "quinta-feira",
	"sexta-feira", "sabado", "domingo"]


static func desenhar(ci: CanvasItem, estilo: int, t: float, alto: float) -> void:
	var L := AppCelular.L
	var r := Rect2(0.0, 0.0, L, alto)
	match posmod(estilo, NOMES.size()):
		0:
			_degrade(ci, r, Color("0b2340"), Color("06101c"))
			_bokeh(ci, r, 17, Color(0.45, 0.75, 1.0), t, 0.0)
		1:
			_degrade(ci, r, Color("1b1238"), Color("050409"))
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in 70:
				var p := Vector2(rng.randf() * L, rng.randf() * alto * 0.75)
				var brilho := 0.35 + 0.45 * rng.randf() * (0.7 + 0.3 * sin(t * 1.7 + float(i)))
				ci.draw_circle(p, 0.18 + rng.randf() * 0.3, Color(1, 1, 1, brilho))
			for k in 6:
				ci.draw_circle(Vector2(L * 0.72, alto * 0.2), 5.0 + float(k) * 3.0,
					Color(0.8, 0.8, 1.0, 0.035))
			ci.draw_circle(Vector2(L * 0.72, alto * 0.2), 5.0, Color(0.95, 0.94, 0.88, 0.9))
		2:
			_degrade(ci, r, Color("031a17"), Color("040608"))
			for k in 5:
				var y := alto * (0.28 + 0.04 * float(k))
				var dy := 8.0 * sin(t * 0.3 + float(k))
				var cor := Color(0.2, 0.9, 0.6).lerp(Color(0.6, 0.3, 0.95), float(k) / 4.0)
				ci.draw_polygon(PackedVector2Array([Vector2(-5.0, y + 40.0 + dy), Vector2(L * 0.5, y + dy),
					Vector2(L + 5.0, y - 30.0 + dy), Vector2(L + 5.0, y - 10.0 + dy),
					Vector2(L * 0.5, y + 22.0 + dy), Vector2(-5.0, y + 62.0 + dy)]),
					PackedColorArray([Color(cor, 0.0), Color(cor, 0.16), Color(cor, 0.0),
						Color(cor, 0.0), Color(cor, 0.05), Color(cor, 0.0)]))


static func _degrade(ci: CanvasItem, r: Rect2, cima: Color, baixo: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
		Vector2(r.position.x, r.end.y)]), PackedColorArray([cima, cima, baixo, baixo]))


## Circulos fora de foco: cada um em quatro aneis de transparencia crescente,
## que e o que o olho le como luz desfocada.
static func _bokeh(ci: CanvasItem, r: Rect2, n: int, cor: Color, t: float, semente: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91 + int(semente)
	for i in n:
		var c := Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		c.y += sin(t * 0.25 + float(i)) * 2.0
		var raio := 3.0 + rng.randf() * 11.0
		var tom := cor.lerp(Color(0.6, 1.0, 0.9), rng.randf() * 0.5)
		var a := 0.04 + rng.randf() * 0.07
		for k in 4:
			ci.draw_circle(c, raio * (1.0 - float(k) * 0.12), Color(tom, a))


## "sexta-feira, 24 de setembro".
static func data_por_extenso() -> String:
	var dia := WorldState.relogio.dia if WorldState.relogio != null else 1
	var semana := posmod(Relogio.PRIMEIRO_DIA_DA_SEMANA + dia - 1, 7)
	var d := DIA_BASE + dia - 1
	var mes := "setembro"
	if d > DIAS_DO_MES:
		d -= DIAS_DO_MES
		mes = "outubro"
	return "%s, %d de %s" % [SEMANA[semana], d, mes]


static func hora() -> String:
	return WorldState.relogio.texto() if WorldState.relogio != null else "--:--"


## A barra de status: sinal e operadora a esquerda, hora no meio. Sem a pilha
## a direita: o aparelho do jogo nao tem bateria. `escura` e a do iOS 4 sobre o
## fundo de tela (preta transparente, texto branco); a clara e a cinza dos apps.
static func barra(ci: CanvasItem, f_semi: Font, f_bold: Font, escura: bool,
		largura: float = AppCelular.L) -> void:
	# Deitado (o Mapas) a barra corre pelo lado comprido do vidro.
	var L := largura
	var tinta := Color.WHITE if escura else Color("1c1f24")
	if escura:
		ci.draw_rect(Rect2(0.0, 0.0, L, BARRA), Color(0.0, 0.0, 0.0, 0.55))
	else:
		ci.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(L, 0.0), Vector2(L, BARRA),
			Vector2(0.0, BARRA)]), PackedColorArray([Color("d9dde3"), Color("d9dde3"),
			Color("a9b0ba"), Color("a9b0ba")]))
		ci.draw_line(Vector2(0.0, BARRA - 0.25), Vector2(L, BARRA - 0.25), Color("6f7782"), 0.5)
	for k in 5:
		var h := 1.4 + float(k) * 1.0
		ci.draw_rect(Rect2(3.0 + float(k) * 1.8, 7.4 - h, 1.2, h),
			Color(tinta, 1.0 if k < 3 else 0.3))
	ci.draw_string(f_semi, Vector2(13.5, 7.2), "REDE", HORIZONTAL_ALIGNMENT_LEFT, -1, 5,
		Color(tinta, 0.95))
	ci.draw_string(f_semi, Vector2(29.0, 7.2), "3G", HORIZONTAL_ALIGNMENT_LEFT, -1, 5,
		Color(tinta, 0.95))
	ci.draw_string(f_bold, Vector2(0.0, 7.6), hora(), HORIZONTAL_ALIGNMENT_CENTER, L, 6, tinta)
