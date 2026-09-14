# -*- coding: utf-8 -*-
from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")
old = """\t\tvar p_cabeca := _ponto_osso(figura, Corpo.Osso.CABECA)
\t\tvar p_pe_e := _ponto_osso(figura, Corpo.Osso.CANELA_E)
\t\tvar p_pe_d := _ponto_osso(figura, Corpo.Osso.CANELA_D)
\t\tvar p_pes := (p_pe_e + p_pe_d) * 0.5
\t\t# Um palmo atras/acima da cabeca pra nao nascer DENTRO do mesh.
\t\tcam_de = p_cabeca - frente_praca * 0.12 + Vector3.UP * 0.08
\t\t# Mira entre os pes, um pouco alem — calca+bota no terco baixo, praca atras.
\t\tolhar_de = p_pes + frente_praca * 0.35 + Vector3.UP * 0.02"""
new = """\t\tvar p_cabeca := _ponto_osso(figura, Corpo.Osso.CABECA)
\t\tvar p_pe_e := _ponto_osso(figura, Corpo.Osso.CANELA_E)
\t\tvar p_pe_d := _ponto_osso(figura, Corpo.Osso.CANELA_D)
\t\tvar p_pes := (p_pe_e + p_pe_d) * 0.5
\t\t# Mais atras da cabeca + leve lado: pernas em perspectiva no terco baixo
\t\t# (ref 01), nao um bloco colado na lente.
\t\tvar lado := frente_praca.cross(Vector3.UP).normalized()
\t\tcam_de = p_cabeca - frente_praca * 0.42 + lado * 0.18 + Vector3.UP * 0.16
\t\t# Mira ALEM dos pes, pro calcamento — bota no centro-baixo, praca atras.
\t\tolhar_de = p_pes + frente_praca * 1.4 + Vector3.UP * 0.06"""
if old not in t:
    raise SystemExit("bone cam offset block missing")
t = t.replace(old, new, 1)
# Also nudge spawn closer to south lamp ring: z+10, x-2 (near postes at centro±7, +8)
old_o = "\torigem = Vector3(matriz.x - 4.0, origem.y, matriz.z + 12.0)"
new_o = "\torigem = Vector3(matriz.x - 2.5, origem.y, matriz.z + 10.0)"
if old_o not in t:
    raise SystemExit("spawn offset missing")
t = t.replace(old_o, new_o, 1)
p.write_text(t, encoding="utf-8")
print("OK v5 perspective")
