## Lanterna: acende o flash de LED atras do aparelho, de verdade — uma luz de
## holofote que sai das costas do iPhone na mao e ilumina a rua na frente dele.
## Apaga ao guardar.
class_name AppLanterna
extends AppCelular


func acao(nome: StringName) -> bool:
	if nome == &"ok":
		Celular.lanterna(not Celular.lanterna_ligada())
		return true
	return nome != &"voltar"


func tocar(id: Variant) -> bool:
	if id == &"botao":
		Celular.lanterna(not Celular.lanterna_ligada())
		return true
	return false


func desenhar(visor: Control) -> void:
	v = visor
	var acesa := Celular.lanterna_ligada()
	grad_v(Rect2(0.0, 0.0, L, alto_tela), Color("23272d") if not acesa else Color("2b2a22"),
		Color("050607"))
	var c := Vector2(L * 0.5, alto_tela * 0.46)
	# O facho desenhado, so quando acesa.
	if acesa:
		for k in 8:
			v.draw_circle(c, 60.0 - float(k) * 6.0, Color(1.0, 0.95, 0.7, 0.03))
	# O botao grande de metal escovado com o simbolo de ligar.
	var r := 34.0
	for k in 10:
		v.draw_circle(c + Vector2(0.0, 1.5), r + 2.0 - float(k) * 0.2, Color(0, 0, 0, 0.04))
	var bot := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
	var pts := PackedVector2Array()
	var cores := PackedColorArray()
	for i in 48:
		var a := float(i) / 48.0 * TAU
		pts.append(c + Vector2(cos(a), sin(a)) * r)
		var luz := 0.5 + 0.5 * sin(a * 2.0 + 0.6)
		cores.append(Color("9aa0a8").lerp(Color("e7eaee"), luz).darkened(0.2 if sob_dedo(bot) else 0.0))
	v.draw_polygon(pts, cores)
	v.draw_arc(c, r, 0.0, TAU, 48, Color(0, 0, 0, 0.5), 0.8, true)
	v.draw_circle(c, r - 6.0, Color("2a2e34") if not acesa else Color("3a3a2c"))
	var cor := Color("ffd84a") if acesa else Color("6f757d")
	if acesa:
		for k in 5:
			v.draw_circle(c, 16.0 - float(k) * 2.0, Color(1.0, 0.85, 0.3, 0.06))
	v.draw_arc(c, 12.0, -PI * 0.32, PI * 1.32, 30, cor, 2.4, true)
	v.draw_line(c + Vector2(0.0, -16.0), c + Vector2(0.0, -4.0), cor, 2.4)
	if foco_visivel:
		v.draw_arc(c, r + 3.0, 0.0, TAU, 48, Color(1, 1, 1, 0.45), 0.7, true)
	alvo(bot, &"botao")
	t(Vector2(0.0, c.y + r + 18.0), "LIGADA" if acesa else "DESLIGADA", 8, cor, f_bold, L,
		HORIZONTAL_ALIGNMENT_CENTER)
	t(Vector2(0.0, c.y + r + 28.0), "Toque para %s" % ("apagar" if acesa else "acender"), 6,
		Color(1, 1, 1, 0.45), f_semi, L, HORIZONTAL_ALIGNMENT_CENTER)
