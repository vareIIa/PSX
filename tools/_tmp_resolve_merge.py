from pathlib import Path
import re
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\cidade.gd")
t = p.read_text(encoding="utf-8")
# Show first conflict exact
m = re.search(r"<<<<<<< HEAD\n.*?>>>>>>> feat/blitz-aaa\n", t, re.S)
print("FOUND1", bool(m))
if m:
    print(repr(m.group(0)[:500]))
