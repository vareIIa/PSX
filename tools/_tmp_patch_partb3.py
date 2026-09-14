# -*- coding: utf-8 -*-
from pathlib import Path
path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
src = path.read_text(encoding="utf-8")
old = """\t# praca_5 — establishing south mais perto: corpo lower-third + eixo igreja.
\t# Look entre corpo e igreja (~271, y+1.2, -46); cam nao pode ir longe demais
\t# senao denso apaga o corpo.
\tawait Cinema.corte(0.1)
\tvar c5 := Vector3(torso.x - 1.2, onde.y + 5.0, torso.z + 5.5)
\tvar l5 := Vector3(271.0, onde.y + 1.15, -46.0)
\tCinema.enquadrar(c5, l5, 56.0)
"""
new = """\t# praca_5 — establishing south: corpo lower-third + igreja/lamp no mesmo frame.
\t# Look entre torso e igreja (~271, y+1.0, -44); cam curta o bastante pro denso.
\tawait Cinema.corte(0.1)
\tvar c5 := Vector3(torso.x - 1.0, onde.y + 4.8, torso.z + 4.2)
\tvar l5 := Vector3(271.0, onde.y + 1.0, -44.0)
\tCinema.enquadrar(c5, l5, 54.0)
"""
if old not in src:
    print("NOT FOUND")
    raise SystemExit(1)
path.write_text(src.replace(old, new), encoding="utf-8")
print("OK praca_5")
