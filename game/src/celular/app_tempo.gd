## Tempo: o que o ceu esta fazendo agora na rua do jogador, lido do proprio mundo
## — a chuva do `Clima`, a neblina do preset em vigor e a hora do relogio. A
## temperatura cai com a madrugada.
class_name AppTempo
extends AppCelular


func acao(nome: StringName) -> bool:
	return nome != &"voltar"


## Graus: 19 as 15h, 11 na virada da madrugada.
static func _temperatura(minuto: int) -> int:
	var h := float(minuto) / 60.0
	return roundi(15.0 + 4.0 * cos((h - 15.0) / 24.0 * TAU))


func _condicao() -> Dictionary:
	var chuva := float(Clima.chuva) if Clima != null else 0.0
	var nevoa := String(Settings.fog_preset_id)
	if chuva > 0.5:
		return {"nome": "Chuva forte", "icone": &"chuva"}
	if chuva > 0.05:
		return {"nome": "Garoa", "icone": &"chuva"}
	if nevoa.contains("denso") or nevoa.contains("neblina"):
		return {"nome": "Neblina", "icone": &"nevoa"}
	var noite := WorldState.relogio != null and WorldState.relogio.e_noite()
	return {"nome": "Ceu limpo", "icone": &"lua" if noite else &"sol"}


func desenhar(visor: Control) -> void:
	v = visor
	var noite := WorldState.relogio != null and WorldState.relogio.e_noite()
	grad_v(Rect2(0.0, 0.0, L, alto_tela), Color("233a6b") if noite else Color("4aa3f0"),
		Color("0b1426") if noite else Color("1f5fb8"))
	var minuto := WorldState.relogio.minutos() if WorldState.relogio != null else 0
	var cond := _condicao()
	t(Vector2(0.0, TOPO + 18.0), "Sua regiao", 8, Color.WHITE, f_bold, L, HORIZONTAL_ALIGNMENT_CENTER)
	t(Vector2(0.0, TOPO + 27.0), String(cond["nome"]), 6, Color(1, 1, 1, 0.8), f_semi, L,
		HORIZONTAL_ALIGNMENT_CENTER)
	_icone(StringName(cond["icone"]), Vector2(L * 0.5, TOPO + 58.0), 20.0)
	t(Vector2(0.0, TOPO + 108.0), "%d°" % _temperatura(minuto), 36, Color.WHITE, f_reg, L,
		HORIZONTAL_ALIGNMENT_CENTER)
	# A previsao das proximas horas: uma coluna por hora.
	var y := TOPO + 124.0
	arred(Rect2(6.0, y, L - 12.0, 50.0), 5.0, Color(0, 0, 0, 0.18))
	for k in 5:
		var m := posmod(minuto + (k + 1) * 60, 24 * 60)
		var x := 6.0 + (L - 12.0) / 5.0 * (float(k) + 0.5)
		t(Vector2(x - 12.0, y + 10.0), "%02dh" % (m / 60), 5, Color(1, 1, 1, 0.8), f_semi, 24.0,
			HORIZONTAL_ALIGNMENT_CENTER)
		_icone(StringName(cond["icone"]) if k < 2 else (&"lua" if (m / 60) >= 18 or (m / 60) < 6 else &"sol"),
			Vector2(x, y + 24.0), 6.0)
		t(Vector2(x - 12.0, y + 43.0), "%d°" % _temperatura(m), 7, Color.WHITE, f_semi, 24.0,
			HORIZONTAL_ALIGNMENT_CENTER)
	t(Vector2(0.0, alto_tela - 8.0), "Atualizado as " + SoFundo.hora(), 5, Color(1, 1, 1, 0.5), f_semi, L,
		HORIZONTAL_ALIGNMENT_CENTER)


func _icone(qual: StringName, c: Vector2, s: float) -> void:
	match qual:
		&"sol":
			v.draw_circle(c, s * 0.5, Color("ffd84a"))
			for k in 8:
				var a := float(k) * TAU / 8.0 + piscar * 0.2
				v.draw_line(c + Vector2(cos(a), sin(a)) * s * 0.65, c + Vector2(cos(a), sin(a)) * s * 0.9,
					Color("ffd84a"), maxf(0.6, s * 0.08), true)
		&"lua":
			v.draw_circle(c, s * 0.5, Color("f1efe2"))
			v.draw_circle(c + Vector2(s * 0.22, -s * 0.12), s * 0.42, Color(0.1, 0.14, 0.26, 0.9))
		&"nevoa":
			for k in 4:
				v.draw_line(c + Vector2(-s * 0.8, s * (-0.45 + 0.3 * k)), c + Vector2(s * 0.8, s * (-0.45 + 0.3 * k)),
					Color(1, 1, 1, 0.75 - 0.12 * k), maxf(0.6, s * 0.12), true)
		&"chuva":
			v.draw_circle(c + Vector2(-s * 0.25, -s * 0.15), s * 0.35, Color("dfe6ef"))
			v.draw_circle(c + Vector2(s * 0.2, -s * 0.25), s * 0.42, Color("dfe6ef"))
			v.draw_rect(Rect2(c.x - s * 0.55, c.y - s * 0.15, s * 1.1, s * 0.3), Color("dfe6ef"))
			for k in 4:
				var x := c.x - s * 0.4 + float(k) * s * 0.27
				var q := fmod(piscar * 1.5 + float(k) * 0.3, 1.0)
				v.draw_line(Vector2(x, c.y + s * (0.25 + q * 0.5)), Vector2(x - s * 0.08, c.y + s * (0.45 + q * 0.5)),
					Color("8fc6ff"), maxf(0.5, s * 0.07), true)
