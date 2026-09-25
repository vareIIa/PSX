## O HUD da partida de sinuca: placar, efeito, forca, recado e a dica de teclas.
##
## Desenhado a mao em `_draw`, na gramatica do HudTema (texto claro com sombra,
## um acento so, painel fechado so para o que se le com calma). O resto do HUD
## de rua some enquanto se joga (JogoSinuca esconde o grupo `hud`), e este fica
## no lugar dele, na mesma camada.
class_name PainelSinuca
extends CanvasLayer

var nomes: Array[String] = ["VOCÊ", "ADVERSÁRIO"]
var vez := 0
var grupos: Array[int] = [-1, -1]
## Quais bolas (0 a 15) ainda estao na mesa.
var na_mesa: Array[bool] = []
var forca := 0.0
var mostrar_forca := false
var efeito := Vector2.ZERO
var mostrar_efeito := false
var dica := ""

var _tela: Control
var _titulo := ""
var _sub := ""
var _cor := HudTema.TEXTO
var _t := 0.0
var _dura := 0.0


func _ready() -> void:
	layer = HudTema.CAMADA + 2
	_tela = Control.new()
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tela)
	# Tamanho explicito: sob CanvasLayer o FULL_RECT sai 0x0 (ver HudAAA).
	_tela.position = Vector2.ZERO
	_tela.size = HudTema.TELA
	_tela.draw.connect(_desenhar)
	na_mesa.resize(16)
	na_mesa.fill(true)


func recado(titulo: String, sub: String = "", cor: Color = HudTema.TEXTO,
		dura: float = 2.8) -> void:
	_titulo = titulo
	_sub = sub
	_cor = cor
	_t = 0.0
	_dura = dura


func _process(delta: float) -> void:
	_t += delta
	_tela.queue_redraw()


func _desenhar() -> void:
	_placar()
	if mostrar_efeito:
		_efeito()
	if mostrar_forca:
		_forca()
	_recado()
	if not dica.is_empty():
		var f := HudTema.regular()
		var largura := HudTema.TELA.x - 2.0 * HudTema.MARGEM
		HudTema.texto(_tela, f, Vector2(HudTema.MARGEM, HudTema.TELA.y - 16.0), dica,
			HudTema.T_ROTULO, HudTema.TEXTO_FRACO, largura, HORIZONTAL_ALIGNMENT_CENTER)


# --- placar -------------------------------------------------------------------

func _placar() -> void:
	var r := Rect2(HudTema.TELA.x * 0.5 - 118.0, 7.0, 236.0, 30.0)
	HudTema.painel(_tela, r, 0.92)
	var meio := r.position.x + r.size.x * 0.5
	_tela.draw_line(Vector2(meio, r.position.y + 5.0), Vector2(meio, r.end.y - 5.0),
		HudTema.PAINEL_BORDA, 0.6, true)
	for lado in 2:
		var x0 := r.position.x + 8.0 if lado == 0 else meio + 8.0
		var largura := r.size.x * 0.5 - 16.0
		var da_vez := lado == vez
		var nome := nomes[lado]
		var f := HudTema.rotulo()
		var cor := HudTema.ACENTO if da_vez else HudTema.TEXTO
		HudTema.texto(_tela, f, Vector2(x0, r.position.y + 3.0),
			HudTema.encurtar(f, nome, HudTema.T_CORPO, largura - 10.0), HudTema.T_CORPO, cor)
		if da_vez:
			var y := r.position.y + 8.5
			var xs := x0 - 5.0
			HudTema.poligono(_tela, PackedVector2Array([Vector2(xs, y - 2.5),
				Vector2(xs + 3.0, y), Vector2(xs, y + 2.5)]), HudTema.ACENTO)
		var g := grupos[lado]
		var y_chips := r.position.y + 21.0
		if g < 0:
			HudTema.texto(_tela, HudTema.regular(), Vector2(x0, y_chips - 4.5), "mesa aberta",
				HudTema.T_MICRO, HudTema.TEXTO_APAGADO)
			continue
		for k in 7:
			var n := k + 1 if g == RegrasSinuca.LISAS else k + 9
			_chip(Vector2(x0 + 4.0 + float(k) * 9.2, y_chips), n, na_mesa[n])
		# A 8, depois das sete: e a que se mata por ultimo.
		_chip(Vector2(x0 + 4.0 + 7.0 * 9.2 + 4.0, y_chips), 8, na_mesa[8], 0.55)


## Bolinha do placar. A listrada leva um anel branco; a que ja caiu fica apagada.
func _chip(c: Vector2, n: int, viva: bool, alfa_extra: float = 1.0) -> void:
	var a := (1.0 if viva else 0.22) * alfa_extra
	var cor: Color = MesaSinuca.CORES[n if n <= 8 else n - 8]
	_tela.draw_circle(c, 3.6, HudTema.alfa(Color(0, 0, 0), 0.5 * a), true, -1.0, true)
	if n > 8:
		_tela.draw_circle(c, 3.2, HudTema.alfa(Color("f3efe4"), a), true, -1.0, true)
		_tela.draw_rect(Rect2(c.x - 3.2, c.y - 1.5, 6.4, 3.0), HudTema.alfa(cor, a))
	else:
		_tela.draw_circle(c, 3.2, HudTema.alfa(cor, a), true, -1.0, true)
	_tela.draw_circle(c, 1.2, HudTema.alfa(Color("f3efe4"), a * 0.9), true, -1.0, true)


# --- efeito e forca -------------------------------------------------------------

func _efeito() -> void:
	var c := Vector2(HudTema.MARGEM + 20.0, HudTema.TELA.y - 44.0)
	var raio := 14.0
	HudTema.texto(_tela, HudTema.rotulo(), Vector2(c.x - raio, c.y - raio - 11.0), "EFEITO",
		HudTema.T_MICRO, HudTema.TEXTO_FRACO)
	_tela.draw_circle(c + Vector2(0.4, 0.8), raio + 1.0, Color(0, 0, 0, 0.45), true, -1.0, true)
	_tela.draw_circle(c, raio, Color("efeae0"), true, -1.0, true)
	_tela.draw_arc(c, raio, 0.0, TAU, 40, Color(0, 0, 0, 0.35), 0.6, true)
	# O limite do taco: fora dele, o taco escorrega.
	_tela.draw_arc(c, raio * FisicaSinuca.EFEITO_MAX, 0.0, TAU, 32, Color(0, 0, 0, 0.18), 0.5, true)
	_tela.draw_line(c - Vector2(raio * 0.8, 0), c + Vector2(raio * 0.8, 0), Color(0, 0, 0, 0.12), 0.5)
	_tela.draw_line(c - Vector2(0, raio * 0.8), c + Vector2(0, raio * 0.8), Color(0, 0, 0, 0.12), 0.5)
	var p := c + Vector2(efeito.x, -efeito.y) * raio
	_tela.draw_circle(p, 2.4, HudTema.PERIGO, true, -1.0, true)


func _forca() -> void:
	var r := Rect2(HudTema.TELA.x - HudTema.MARGEM - 8.0, HudTema.TELA.y - 118.0, 7.0, 84.0)
	HudTema.texto(_tela, HudTema.rotulo(), Vector2(r.position.x - 14.0, r.position.y - 11.0),
		"FORÇA", HudTema.T_MICRO, HudTema.TEXTO_FRACO)
	HudTema.painel(_tela, r.grow(1.5), 0.9, 2.0)
	var h := r.size.y * clampf(forca, 0.0, 1.0)
	var cor := HudTema.OK.lerp(HudTema.ALERTA, clampf(forca * 1.6, 0.0, 1.0))
	if forca > 0.75:
		cor = HudTema.ALERTA.lerp(HudTema.PERIGO, (forca - 0.75) / 0.25)
	_tela.draw_rect(Rect2(r.position.x, r.end.y - h, r.size.x, h), cor)


# --- recado ---------------------------------------------------------------------

func _recado() -> void:
	if _titulo.is_empty() or _t > _dura:
		return
	var entra := clampf(_t / HudTema.T_ENTRA, 0.0, 1.0)
	var sai := clampf((_dura - _t) / HudTema.T_SAI, 0.0, 1.0)
	var a := minf(entra, sai)
	var ft := HudTema.negrito()
	var fs := HudTema.regular()
	var larg := maxf(HudTema.largura(ft, _titulo, HudTema.T_DESTAQUE),
		HudTema.largura(fs, _sub, HudTema.T_CORPO)) + 28.0
	var alto := 26.0 if _sub.is_empty() else 38.0
	var r := Rect2(HudTema.TELA.x * 0.5 - larg * 0.5, 64.0 - (1.0 - entra) * 4.0, larg, alto)
	HudTema.painel(_tela, r, a)
	HudTema.texto(_tela, ft, Vector2(r.position.x, r.position.y + 5.0), _titulo,
		HudTema.T_DESTAQUE, HudTema.alfa(_cor, a), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if not _sub.is_empty():
		HudTema.texto(_tela, fs, Vector2(r.position.x, r.position.y + 22.0), _sub,
			HudTema.T_CORPO, HudTema.alfa(HudTema.TEXTO_FRACO, a), r.size.x,
			HORIZONTAL_ALIGNMENT_CENTER)
