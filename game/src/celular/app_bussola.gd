## Bussola: para onde o jogador esta olhando, lido do corpo dele. Norte e -Z, a
## mesma convencao do mapa e do HUD (`HudBussola`).
##
## O mostrador gira com uma mola, como a agulha de verdade, e passa um nada do
## ponto antes de assentar.
class_name AppBussola
extends AppCelular

const PONTOS := ["N", "NE", "L", "SE", "S", "SO", "O", "NO"]

var _giro: float = 0.0
var _giro_v: float = 0.0


func _rumo() -> float:
	var j := Celular.get_tree().get_first_node_in_group(&"player") as Node3D
	if j == null:
		return 0.0
	# Graus a partir do norte, no sentido horario.
	var f := -j.global_transform.basis.z
	return fposmod(rad_to_deg(atan2(f.x, -f.z)), 360.0)


func processar(delta: float) -> void:
	super.processar(delta)
	var alvo_g := _rumo()
	var diferenca := wrapf(alvo_g - _giro, -180.0, 180.0)
	_giro_v += (diferenca * 60.0 - _giro_v * 9.0) * delta
	_giro = fposmod(_giro + _giro_v * delta, 360.0)


func acao(nome: StringName) -> bool:
	return nome != &"voltar"


func desenhar(visor: Control) -> void:
	v = visor
	grad_v(Rect2(0.0, 0.0, L, alto_tela), Color("1c1f24"), Color("050607"))
	var rumo := _giro
	var ponto := String(PONTOS[int(roundf(rumo / 45.0)) % 8])
	t(Vector2(0.0, TOPO + 26.0), "%d° %s" % [roundi(rumo) % 360, ponto], 16, Color.WHITE, f_reg, L,
		HORIZONTAL_ALIGNMENT_CENTER)
	var c := Vector2(L * 0.5, alto_tela * 0.56)
	var r := 58.0
	v.draw_circle(c, r + 3.0, Color("2c3036"))
	v.draw_circle(c, r, Color("0b0c0e"))
	# O mostrador gira ao contrario do rumo: o N aponta para o norte de verdade.
	var giro := -deg_to_rad(rumo)
	for k in 72:
		var a := giro + float(k) * TAU / 72.0 - PI * 0.5
		var longo := k % 6 == 0
		var dir := Vector2(cos(a), sin(a))
		v.draw_line(c + dir * (r - (7.0 if longo else 3.5)), c + dir * (r - 1.0),
			Color(1, 1, 1, 0.9 if longo else 0.45), 0.9 if longo else 0.5, true)
	for k in 8:
		var a := giro + float(k) * TAU / 8.0 - PI * 0.5
		var p := c + Vector2(cos(a), sin(a)) * (r - 15.0)
		var tam := 10 if k % 2 == 0 else 6
		var cor := Color("ff3b30") if k == 0 else Color.WHITE
		t(Vector2(p.x - 10.0, p.y + float(tam) * 0.36), PONTOS[k], tam, cor, f_semi if k % 2 == 0 else f_reg,
			20.0, HORIZONTAL_ALIGNMENT_CENTER)
	# A marca fixa do rumo, em cima.
	v.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -r - 1.0), c + Vector2(-3.0, -r - 7.0),
		c + Vector2(3.0, -r - 7.0)]), Color.WHITE)
	v.draw_line(c + Vector2(-6.0, 0.0), c + Vector2(6.0, 0.0), Color(1, 1, 1, 0.3), 0.5)
	v.draw_line(c + Vector2(0.0, -6.0), c + Vector2(0.0, 6.0), Color(1, 1, 1, 0.3), 0.5)
