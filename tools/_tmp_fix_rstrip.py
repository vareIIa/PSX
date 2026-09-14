from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\ui\criacao.gd")
t = p.read_text(encoding="utf-8")
# Fix broken string: rstrip("/\") ate the quote
bad = 'var raiz_jogo := ProjectSettings.globalize_path("res://").rstrip("/\\")'
# actual file content may show as rstrip("/\") 
import re
t2, n = re.subn(
    r'var raiz_jogo := ProjectSettings\.globalize_path\("res://"\)\.rstrip\("/\\?"\)',
    'var raiz_jogo := ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\\\")',
    t,
    count=1,
)
if n == 0:
    # show around line
    lines = t.splitlines()
    for i in range(735, 742):
        print(i+1, repr(lines[i]))
    raise SystemExit('pattern not found')
p.write_text(t2, encoding='utf-8')
print('fixed rstrip', n)
# verify
lines = t2.splitlines()
print(736, lines[736])
print(737, lines[737])
