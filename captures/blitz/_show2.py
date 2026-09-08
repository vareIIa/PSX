from pathlib import Path
t = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\cidade.gd").read_text(encoding="utf-8")
i = t.find("func _olhar_blitz")
print("idx", i)
print(t[i:i+1800] if i>=0 else "MISSING")
