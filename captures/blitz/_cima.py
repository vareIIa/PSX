from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\cidade.gd")
t = p.read_text(encoding="utf-8")
old = '''		"cima":
			cam = alvo + Vector3(0.0, 22.0, 0.0) + b * Vector3(2.0, 0.0, 2.0)
			olhar = alvo
		"desvio":'''
new = '''		"cima":
			# Camera propria de cima (nao depende do pitch do player).
			_camera_de_cima(alvo + Vector3(0.0, 0.0, 0.0), deg_to_rad(90.0), deg_to_rad(-55.0))
			print("[cidade] blitz modo=cima em %.1f,%.1f,%.1f" % [alvo.x, alvo.y, alvo.z])
			return
		"desvio":'''
if old not in t:
    raise SystemExit("cima match missing")
t = t.replace(old, new, 1)
# Fix _camera_de_cima call - check signature. Earlier: _camera_de_cima(Vector3(x,y,z), inclinacao, giro)
# from --de-cima=x,z,y parsing: Vector3(float(p[0]), float(p[2]), float(p[1]))
# So onde is position with y as height in the Vector3.y component.
# Read function
i = t.find("func _camera_de_cima")
print(t[i:i+350])
p.write_text(t, encoding="utf-8")
print("cima mode uses camera_de_cima")
