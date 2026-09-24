## Radio FM: o controle do radio de pilha que o jogador carrega. Liga e desliga
## o mesmo `Radio` da tecla de radio, e o mostrador mostra o que ele capta — o
## chiado sobe quando a coisa esta perto.
class_name AppRadio
extends AppCelular

const FUNDO_CIMA := Color("3a2616")
const FUNDO_BAIXO := Color("120a05")
const AMBAR := Color("ffb24a")


func _radio() -> Radio:
	var j := Celular.get_tree().get_first_node_in_group(&"player")
	return j.get("radio") as Radio if j != null else null


func acao(nome: StringName) -> bool:
	if nome == &"ok":
		_alternar()
		return true
	return nome != &"voltar"


func tocar(id: Variant) -> bool:
	if id == &"liga":
		_alternar()
		return true
	return false


func _alternar() -> void:
	var r := _radio()
	if r == null:
		aviso("SEM RADIO", Color("e0892b"))
		AudioDirector.tocar_ui(&"celular_erro", -10.0)
		return
	if not r.disponivel():
		aviso("O RADIO NAO ESTA COM VOCE", Color("e0892b"))
		AudioDirector.tocar_ui(&"celular_erro", -10.0)
		return
	r.alternar()
	AudioDirector.tocar_ui(&"interruptor", -6.0)


func desenhar(visor: Control) -> void:
	v = visor
	grad_v(Rect2(0.0, 0.0, L, alto_tela), FUNDO_CIMA, FUNDO_BAIXO)
	var r := _radio()
	var ligado := r != null and r.ligado and r.disponivel()
	var sinal := r.intensidade if r != null and ligado else 0.0
	t(Vector2(0.0, TOPO + 18.0), "Radio FM", 9, Color(AMBAR, 0.9), f_bold, L, HORIZONTAL_ALIGNMENT_CENTER)
	# O mostrador: a escala de frequencia com o ponteiro tremendo no chiado.
	var m := Rect2(10.0, TOPO + 30.0, L - 20.0, 44.0)
	arred(m, 4.0, Color("1a0f07"))
	arred(m, 4.0, Color(AMBAR, 0.35), false, 0.6)
	grad_v(Rect2(m.position.x + 2.0, m.position.y + 2.0, m.size.x - 4.0, m.size.y * 0.4),
		Color(1, 0.8, 0.5, 0.1), Color(1, 0.8, 0.5, 0.0))
	for k in 21:
		var x := m.position.x + 8.0 + float(k) * (m.size.x - 16.0) / 20.0
		var alto := 6.0 if k % 5 == 0 else 3.0
		v.draw_line(Vector2(x, m.end.y - 16.0), Vector2(x, m.end.y - 16.0 - alto), Color(AMBAR, 0.6), 0.5)
		if k % 5 == 0:
			t(Vector2(x - 8.0, m.end.y - 6.0), str(88 + k), 4, Color(AMBAR, 0.6), f_semi, 16.0,
				HORIZONTAL_ALIGNMENT_CENTER)
	var ponteiro := 0.62 + (sin(piscar * 23.0) * 0.01 + sin(piscar * 7.0) * 0.006) * (1.0 + sinal * 6.0)
	var px := m.position.x + 8.0 + (m.size.x - 16.0) * ponteiro
	v.draw_line(Vector2(px, m.position.y + 5.0), Vector2(px, m.end.y - 8.0), Color("ff4a2a"), 0.9)
	t(Vector2(0.0, TOPO + 90.0), "100.4 MHz" if ligado else "---.- MHz", 12,
		AMBAR if ligado else Color(AMBAR, 0.3), f_bold, L, HORIZONTAL_ALIGNMENT_CENTER)
	# O medidor de sinal: barras que acendem com a intensidade.
	for k in 10:
		var acesa := ligado and float(k) / 10.0 < 0.1 + sinal * 0.9 + 0.05 * sin(piscar * 9.0 + float(k))
		ret(Rect2(L * 0.5 - 30.0 + float(k) * 6.2, TOPO + 106.0 - float(k) * 1.2, 4.5, 4.0 + float(k) * 1.2),
			Color(AMBAR, 0.95) if acesa else Color(AMBAR, 0.15))
	# O botao de ligar: redondo, de vidro.
	var c := Vector2(L * 0.5, TOPO + 150.0)
	var rr := 22.0
	var bot := Rect2(c - Vector2(rr, rr), Vector2(rr, rr) * 2.0)
	for k in 6:
		v.draw_circle(c, rr - float(k) * 0.6, Color(0, 0, 0, 0.08))
	v.draw_circle(c, rr - 3.0, Color("2a1a0e") if not sob_dedo(bot) else Color("3a2414"))
	v.draw_arc(c, rr - 3.0, 0.0, TAU, 40, Color(AMBAR, 0.9 if ligado else 0.3), 1.2, true)
	v.draw_arc(c, 8.0, -PI * 0.35, PI * 1.35, 24, AMBAR if ligado else Color(AMBAR, 0.4), 1.6, true)
	v.draw_line(c + Vector2(0.0, -11.0), c + Vector2(0.0, -3.0), AMBAR if ligado else Color(AMBAR, 0.4), 1.6)
	if foco_visivel:
		v.draw_arc(c, rr + 1.5, 0.0, TAU, 40, Color(1, 1, 1, 0.5), 0.6, true)
	alvo(bot, &"liga")
	t(Vector2(0.0, TOPO + 185.0), "LIGADO" if ligado else "DESLIGADO", 6,
		AMBAR if ligado else Color(AMBAR, 0.4), f_bold, L, HORIZONTAL_ALIGNMENT_CENTER)
	desenhar_aviso()
