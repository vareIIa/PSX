# -*- coding: utf-8 -*-
"""v7: hollow emissive frame (not solid panel) so black door reads."""
from pathlib import Path
kit = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\kit_parque.gd")
t = kit.read_text(encoding="utf-8")

old = """\t# Rim emissivo (kit trick do poste).
\tKitModular.caixa(sup, &\"janela_acesa\",
\t\tporta_c + frente * 0.38 + Vector3(0.0, 0.1, 0.0),
\t\tVector3(3.7, 4.6, 0.12), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
\tKitModular.caixa(sup, &\"janela_acesa\",
\t\tporta_c + frente * 0.38 + Vector3(0.0, 2.4, 0.0),
\t\tVector3(2.6, 0.5, 0.12), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
"""

new = """\t# Rim emissivo OCO (kit trick do poste) — faixa, nao painel cheio,
\t# senao o buraco preto da porta some atras do amarelo.
\tvar rim_z := porta_c + frente * 0.42
\tKitModular.caixa(sup, &\"janela_acesa\",
\t\trim_z + Vector3(0.0, 2.15, 0.0), Vector3(3.7, 0.28, 0.14), giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)  # lintel
\tKitModular.caixa(sup, &\"janela_acesa\",
\t\trim_z + Vector3(0.0, -1.9, 0.0), Vector3(3.7, 0.22, 0.14), giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)  # soleira
\tfor sx: float in [-1.0, 1.0]:
\t\tKitModular.caixa(sup, &\"janela_acesa\",
\t\t\trim_z + lado * (1.8 * sx) + Vector3(0.0, 0.1, 0.0),
\t\t\tVector3(0.28, 4.3, 0.14), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
"""

assert old in t, "rim block missing"
t = t.replace(old, new, 1)

# Also shrink cruz janela_acesa to stay, but make sure cruz clara still behind
# Cross emissive is already thin - OK

kit.write_text(t, encoding="utf-8")
print("v7 hollow rim OK")
assert "Rim emissivo OCO" in kit.read_text(encoding="utf-8")
