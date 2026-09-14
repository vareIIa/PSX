from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\criacao.gd")
lines = p.read_text(encoding="utf-8").splitlines(True)
# find and replace the raiz_jogo line
for i, line in enumerate(lines):
    if "var raiz_jogo :=" in line and "globalize_path" in line:
        lines[i] = '\tvar raiz_jogo := ProjectSettings.globalize_path("res://").replace(String.chr(92), "/").rstrip("/")\n'
        print("replaced line", i+1)
        break
else:
    raise SystemExit("line not found")
p.write_text("".join(lines), encoding="utf-8")
print(repr(lines[i]))
