from pathlib import Path
p = Path(r"game/src/world/carro_cena.gd")
t = p.read_text(encoding="utf-8")
if "_brasa" not in t:
    t = t.replace("var _luz_cabine: OmniLight3D\n", "var _luz_cabine: OmniLight3D\nvar _brasa: OmniLight3D\n", 1)
    old = '''	_luz_cabine.visible = false
	add_child(_luz_cabine)


func acender_farois(aceso: bool = true) -> void:
'''
    new = '''	_luz_cabine.visible = false
	add_child(_luz_cabine)

	_brasa = OmniLight3D.new()
	_brasa.name = "Brasa"
	_brasa.position = Vector3(0.0, 0.55, float(_medidas["comprimento"]) * 0.5)
	_brasa.omni_range = 3.2
	_brasa.light_energy = 0.7
	_brasa.light_color = Color(1.0, 0.22, 0.16)
	_brasa.shadow_enabled = false
	_brasa.visible = false
	add_child(_brasa)

	# Fill externo fraco: hatch branco precisa ler na 3P a noite.
	var fill := OmniLight3D.new()
	fill.name = "FillExterior"
	fill.position = Vector3(0.0, 1.4, 0.2)
	fill.omni_range = 4.0
	fill.light_energy = 0.35
	fill.light_color = Color(0.85, 0.88, 1.0)
	fill.shadow_enabled = false
	fill.visible = false
	add_child(fill)


func acender_farois(aceso: bool = true) -> void:
'''
    if old not in t: raise SystemExit("luz_cabine block missing")
    t = t.replace(old, new, 1)
    t = t.replace(
'''	if _luz_cabine != null:
		_luz_cabine.visible = aceso
''',
'''	if _luz_cabine != null:
		_luz_cabine.visible = aceso
	if _brasa != null:
		_brasa.visible = aceso
	var fill := get_node_or_null("FillExterior") as OmniLight3D
	if fill != null:
		fill.visible = aceso
''', 1)
    p.write_text(t, encoding="utf-8")
    print("brasa+fill ok")
else:
    print("brasa already")

# Chase framing closer / lower like ref 03
p2 = Path(r"game/src/levels/abertura_estrada.gd")
t2 = p2.read_text(encoding="utf-8")
t2 = t2.replace(
'''		Plano.CHASE:
			# 3a pessoa atras do hatch (ref 03): recuo baixo, farois na pista.
			var de_chase := carro - dir * 7.4 + Vector3.UP * 2.1 + lado * 0.35
			_enquadrar(de_chase, carro + dir * 6.0 + Vector3.UP * 0.7, 58.0)
''',
'''		Plano.CHASE:
			# 3a pessoa atras do hatch (ref 03): mais perto, menos alto.
			var de_chase := carro - dir * 6.2 + Vector3.UP * 1.55 + lado * 0.2
			_enquadrar(de_chase, carro + dir * 8.0 + Vector3.UP * 0.55, 56.0)
''', 1)
p2.write_text(t2, encoding="utf-8")
print("chase framing tuned")
