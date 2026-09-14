# -*- coding: utf-8 -*-
from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")
# After Cinema.mover in _plano_da_praca, boost/reposition apoio as warm lamp near legs
needle = """\tCinema.mover(
\t\tcam_de, cam_ate,
\t\tolhar_de, olhar_ate,
\t\tACORDA_DURACAO, ACORDA_FOV.x, ACORDA_FOV.y)

\tif _hud != null:"""
insert = """\tCinema.mover(
\t\tcam_de, cam_ate,
\t\tolhar_de, olhar_ate,
\t\tACORDA_DURACAO, ACORDA_FOV.x, ACORDA_FOV.y)

\t# Ref 01: lampiao quente a esquerda iluminando pernas/chao. Reusa o apoio.
\tif _apoio != null and is_instance_valid(_apoio):
\t\tvar lado_luz := frente_praca.cross(Vector3.UP).normalized()
\t\t_apoio.global_position = onde - lado_luz * 2.8 + Vector3.UP * 3.4 + frente_praca * 0.5
\t\t_apoio.light_color = Color(\"ffb45a\")
\t\t_apoio.light_energy = 5.5
\t\t_apoio.omni_range = 9.0

\tif _hud != null:"""
if needle not in t:
    raise SystemExit("mover+hud needle missing")
t = t.replace(needle, insert, 1)
p.write_text(t, encoding="utf-8")
print("OK v7 warm apoio")
