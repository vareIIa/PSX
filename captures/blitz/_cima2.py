from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\cidade.gd")
t = p.read_text(encoding="utf-8")
old = '''		"cima":
			# Camera propria de cima (nao depende do pitch do player).
			_camera_de_cima(alvo + Vector3(0.0, 0.0, 0.0), deg_to_rad(90.0), deg_to_rad(-55.0))
			print("[cidade] blitz modo=cima em %.1f,%.1f,%.1f" % [alvo.x, alvo.y, alvo.z])
			return'''
new = '''		"cima":
			# onde.y = tamanho ortografico (metros no quadro), nao altura.
			_camera_de_cima(Vector3(alvo.x, 32.0, alvo.z), deg_to_rad(90.0), deg_to_rad(-55.0))
			print("[cidade] blitz modo=cima em %.1f,%.1f,%.1f" % [alvo.x, alvo.y, alvo.z])
			return'''
if old not in t:
    raise SystemExit("cima block missing")
t = t.replace(old, new, 1)
p.write_text(t, encoding="utf-8")
print("fixed cima size")
