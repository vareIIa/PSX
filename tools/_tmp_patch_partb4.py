# -*- coding: utf-8 -*-
from pathlib import Path
path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
src = path.read_text(encoding="utf-8")
old = """\t# praca_5 — establishing south: corpo lower-third + igreja/lamp no mesmo frame.
\t# Look entre torso e igreja (~271, y+1.0, -44); cam curta o bastante pro denso.
\tawait Cinema.corte(0.1)
\tvar c5 := Vector3(torso.x - 1.0, onde.y + 4.8, torso.z + 4.2)
\tvar l5 := Vector3(271.0, onde.y + 1.0, -44.0)
\tCinema.enquadrar(c5, l5, 54.0)
"""
new = """\t# praca_5 — establishing south: corpo lower-third; look entre torso e eixo igreja.
\t# Absolute 271,-46 puxava a mira pro lampiao e o corpo sumia no denso.
\tawait Cinema.corte(0.1)
\tvar c5 := Vector3(torso.x - 2.2, onde.y + 5.2, torso.z + 4.8)
\tvar l5 := Vector3(torso.x + 0.6, onde.y + 0.85, torso.z - 2.8)
\tCinema.enquadrar(c5, l5, 56.0)
"""
if old not in src:
    print("NOT FOUND")
    # show current praca_5
    i = src.find("praca_5")
    print(repr(src[i:i+400]))
    raise SystemExit(1)
path.write_text(src.replace(old, new), encoding="utf-8")
print("OK")
