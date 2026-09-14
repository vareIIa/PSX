from pathlib import Path
p = Path(r"game/src/levels/abertura_estrada.gd")
t = p.read_text(encoding="utf-8")
old = '''	_hud.visible = true
	await Cinema.clarear(0.7)
	var falas := ["dentro_1", "dentro_2", "dentro_3", "dentro_4"]'''
new = '''	_hud.visible = true
	_hud.definir_local("ESTRADA VELHA")
	_hud.definir_hora("22:43")
	_hud.definir_vida(4, 10)
	_hud.definir_lanterna(true)
	await Cinema.clarear(0.7)
	var falas := ["dentro_1", "dentro_2", "dentro_3", "dentro_4"]'''
if old in t and "definir_local(\"ESTRADA VELHA\")" not in t.split("func _plano_dentro")[1][:400]:
    t = t.replace(old, new, 1)
    p.write_text(t, encoding="utf-8")
    print("plano_dentro hud labels ok")
else:
    print("plano_dentro hud already set or pattern changed")
