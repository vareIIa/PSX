# -*- coding: utf-8 -*-
from pathlib import Path
path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\render\carroceria.gd")
text = path.read_text(encoding="utf-8")
marker = "## A cacamba da picape: tres paredes baixas em cima do casco."
assert marker in text
assert "_lataria_fusca" not in text
print("ready to insert")
