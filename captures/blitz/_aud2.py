from pathlib import Path
c = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\cidade.gd").read_text(encoding="utf-8")
print("len", len(c), "lines", c.count("\n"))
print("olhar_blitz", "olhar_blitz" in c)
print("olhar-blitz", "olhar-blitz" in c)
i = c.find("func _olhar")
print("func _olhar idx", i)
# search for blitz in cidade
for line in c.splitlines():
    if "blitz" in line.lower() or "Blitz" in line:
        print(line[:120])
