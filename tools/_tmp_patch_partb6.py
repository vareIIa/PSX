# -*- coding: utf-8 -*-
from pathlib import Path
path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
src = path.read_text(encoding="utf-8")
old = """\t# Cleiton: igreja ~271,-54.75 fachada; look axis ~271,-51; coreto ~264,-46 W.
\tvar igreja := Vector3(271.0, onde.y + 3.5, -51.0)

\t# Lampiao quente a SW (esquerda do pin).
"""
new = """\t# Cleiton: igreja ~271,-54.75 fachada; look axis ~271,-51; coreto ~264,-46 W.
\t# (eixo igreja usado so como referencia — looks miram o torso, nao o telhado)

\t# Lampiao quente a SW (esquerda do pin).
"""
if old not in src:
    print("igreja block not found exactly — skip")
else:
    path.write_text(src.replace(old, new), encoding="utf-8")
    print("removed unused igreja var")
