from pathlib import Path
t = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\cidade.gd").read_text(encoding="utf-8")
i = t.find('"cima"')
print(repr(t[i:i+400]))
