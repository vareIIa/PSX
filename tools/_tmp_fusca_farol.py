from pathlib import Path
path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\render\carroceria.gd")
text = path.read_text(encoding="utf-8")

# Rounder headlight: add diamond overlay on top of ring+core
old = '''\t# Farol redondo: anel escuro + nucleo (nos para-lamas, nao na grade).
\tvar ox := larg * 0.42
\tfor s: float in [1.0, -1.0]:
\t\t_face(dados, Vector2(0.28, 0.28),
\t\t\tTransform3D(Basis(), Vector3(s * ox, y + 0.08, zf + 0.010)),
\t\t\tColor(0.16, 0.16, 0.18), C_GRADE)
\t\t_face(luzes, Vector2(0.20, 0.20),
\t\t\tTransform3D(Basis(), Vector3(s * ox, y + 0.08, zf + 0.016)),
\t\t\tColor.WHITE, C_FAROL)'''

new = '''\t# Farol "redondo" a 480p: anel + nucleo + losango (le circular).
\tvar ox := larg * 0.42
\tfor s: float in [1.0, -1.0]:
\t\t_face(dados, Vector2(0.30, 0.30),
\t\t\tTransform3D(Basis(), Vector3(s * ox, y + 0.10, zf + 0.010)),
\t\t\tColor(0.14, 0.14, 0.16), C_GRADE)
\t\t_face(dados, Vector2(0.22, 0.22),
\t\t\tTransform3D(Basis(Vector3.FORWARD, PI * 0.25),
\t\t\t\tVector3(s * ox, y + 0.10, zf + 0.012)),
\t\t\tColor(0.20, 0.20, 0.22), C_GRADE)
\t\t_face(luzes, Vector2(0.18, 0.18),
\t\t\tTransform3D(Basis(), Vector3(s * ox, y + 0.10, zf + 0.018)),
\t\t\tColor.WHITE, C_FAROL)'''

if old not in text:
    raise SystemExit("headlight block missing")
text = text.replace(old, new, 1)
path.write_text(text, encoding="utf-8")

# Sanity
final = path.read_text(encoding="utf-8")
assert "static func _frente_e_tras_marea" in final
vid = final[final.index("static func _vidros"): final.index("static func _frente_e_tras")]
assert vid.count("_face_dois_lados(") == 0
assert "Color(0.72, 0.80, 0.86)" in vid
assert "com_vidros_frente" in final
print("headlight+sanity ok")
