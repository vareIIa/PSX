from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\player\player.gd")
t = p.read_text(encoding="utf-8")
old = """func olhar_para(ponto: Vector3) -> void:
	var d := ponto - global_position
	d.y = 0.0
	if d.length_squared() < 0.001:
		return
	rotation.y = atan2(-d.x, -d.z)
	_pitch = 0.0
	_pivo.rotation.x = 0.0"""
new = """func olhar_para(ponto: Vector3) -> void:
	var d := ponto - global_position
	var horiz := Vector2(d.x, d.z).length()
	if horiz < 0.001 and absf(d.y) < 0.001:
		return
	if horiz >= 0.001:
		rotation.y = atan2(-d.x, -d.z)
	# Pitch acompanha o ponto (capturas de blitz / de cima). Mouse: pitch
	# negativo olha para baixo — atan2(d.y, horiz) ja sai no mesmo sinal.
	definir_pitch(atan2(d.y, maxf(horiz, 0.001)))"""
if old not in t:
    raise SystemExit("olhar_para missing")
t = t.replace(old, new, 1)
p.write_text(t, encoding="utf-8")
print("olhar_para pitch ok")
