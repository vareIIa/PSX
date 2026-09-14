# -*- coding: utf-8 -*-
from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")
# Spawn near south lamp ring (Cleiton: postes at centro ±5, +13)
old = "\torigem = Vector3(matriz.x - 2.5, origem.y, matriz.z + 10.0)"
new = "\t# Colado no anel sul de lampioes (~5 m a oeste, 13 m ao sul do coreto)."
new += "\n\torigem = Vector3(matriz.x - 5.0, origem.y, matriz.z + 13.0)"
if old not in t:
    raise SystemExit(f"spawn not found: {old!r}")
t = t.replace(old, new, 1)
old2 = """\t\tvar lado := frente_praca.cross(Vector3.UP).normalized()
\t\tcam_de = p_cabeca - frente_praca * 0.42 + lado * 0.18 + Vector3.UP * 0.16
\t\t# Mira ALEM dos pes, pro calcamento — bota no centro-baixo, praca atras.
\t\tolhar_de = p_pes + frente_praca * 1.4 + Vector3.UP * 0.06"""
new2 = """\t\t# Sem lateral exagerada: pernas no CENTRO-baixo como na ref 01.
\t\tcam_de = p_cabeca - frente_praca * 0.55 + Vector3.UP * 0.22
\t\t# Mira as botas (ponta das canelas), praca logo atras.
\t\tolhar_de = p_pes + frente_praca * 0.55 + Vector3.UP * 0.04"""
if old2 not in t:
    raise SystemExit("cam offset v5 missing")
t = t.replace(old2, new2, 1)
p.write_text(t, encoding="utf-8")
print("OK v6 lamp+center boots")
