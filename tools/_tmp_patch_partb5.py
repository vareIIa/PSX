# -*- coding: utf-8 -*-
from pathlib import Path
path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
src = path.read_text(encoding="utf-8")
old = """\t# praca_5 — establishing south: corpo lower-third; look entre torso e eixo igreja.
\t# Absolute 271,-46 puxava a mira pro lampiao e o corpo sumia no denso.
\tawait Cinema.corte(0.1)
\tvar c5 := Vector3(torso.x - 2.2, onde.y + 5.2, torso.z + 4.8)
\tvar l5 := Vector3(torso.x + 0.6, onde.y + 0.85, torso.z - 2.8)
\tCinema.enquadrar(c5, l5, 56.0)
"""
new = """\t# praca_5 — wider establishing south (mesmo look-no-corpo do 02, mais alto/largo).
\t# Mira no torso + leve N pra igreja peek; lampiao/eixo igreja no mesmo frame.
\tawait Cinema.corte(0.1)
\tvar c5 := Vector3(torso.x - 1.8, onde.y + 5.8, torso.z + 3.6)
\tvar l5 := Vector3(torso.x + 0.25, onde.y + 0.55, torso.z - 1.6)
\tCinema.enquadrar(c5, l5, 58.0)
"""
if old not in src:
    print("NOT FOUND")
    raise SystemExit(1)
path.write_text(src.replace(old, new), encoding="utf-8")
print("OK")
