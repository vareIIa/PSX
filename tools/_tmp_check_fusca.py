from pathlib import Path
t = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\render\carroceria.gd").read_text(encoding="utf-8")
vid = t[t.index("static func _vidros"): t.index("static func _frente_e_tras")]
print(vid)
print("---MED---")
for l in t.splitlines():
    if "Modelo.FUSCA" in l or "TINTA_FUSCA" in l:
        print(l)
print("dois calls in vidros:", vid.count("_face_dois_lados("))
print("face calls in vidros:", vid.count("_face("))
