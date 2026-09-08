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
	# Pitch acompanha o ponto (capturas de blitz). Mouse: pitch negativo olha
	# para baixo — atan2(d.y, horiz) ja sai no mesmo sinal.
	definir_pitch(atan2(d.y, maxf(horiz, 0.001)))"""
if "definir_pitch(atan2" in t:
    print("pitch already")
elif old not in t:
    raise SystemExit("olhar_para not found")
else:
    p.write_text(t.replace(old, new, 1), encoding="utf-8")
    print("pitch fixed")

cid = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\cidade.gd")
c = cid.read_text(encoding="utf-8")
i = c.find('"cima"')
print("cima:", repr(c[i:i+320]))
for cand in [
    "_camera_de_cima(alvo + Vector3(0.0, 0.0, 0.0), deg_to_rad(90.0), deg_to_rad(-55.0))",
    "_camera_de_cima(alvo, deg_to_rad(90.0), deg_to_rad(-55.0))",
]:
    if cand in c:
        c = c.replace(cand, "_camera_de_cima(Vector3(alvo.x, 32.0, alvo.z), deg_to_rad(90.0), deg_to_rad(-55.0))", 1)
        cid.write_text(c, encoding="utf-8")
        print("cima fixed from", cand[:40])
        break
else:
    if "32.0, alvo.z" in c:
        print("cima already sized")
    else:
        print("cima NOT fixed")

c = cid.read_text(encoding="utf-8")
print("quer_blitz", "_quer_blitz" in c or "quer_blitz" in c)
print("titulo", "--olhar-blitz" in c)
