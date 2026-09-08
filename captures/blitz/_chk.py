from pathlib import Path
t = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\cidade.gd").read_text(encoding="utf-8")
print("len", len(t))
print("olhar-blitz count", t.count("olhar-blitz"))
print("olhar_blitz count", t.count("olhar_blitz"))
i = t.find("quer_blitz")
print("quer", i)
print(t[i-100:i+200] if i>=0 else "")
# check if camera_de_cima still there
print("camera_de_cima", "func _camera_de_cima" in t)
