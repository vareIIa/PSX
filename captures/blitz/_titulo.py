from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\cidade.gd")
t = p.read_text(encoding="utf-8")
old = '''		if a in ["--pular-menu", "--ver-abertura"]:
			return false'''
new = '''		if a in ["--pular-menu", "--ver-abertura", "--olhar-blitz"]:
			return false'''
if old not in t:
    raise SystemExit("deve_abrir missing")
t = t.replace(old, new, 1)
p.write_text(t, encoding="utf-8")
print("titulo skip ok")
