# -*- coding: utf-8 -*-
from pathlib import Path
import re

# mat_leito: vivid red + slight emission
lp = Path("game/resources/materials/mat_leito.tres")
lt = lp.read_text(encoding="utf-8")
lt = lt.replace(
    "shader_parameter/tint = Color(1.45, 0.72, 0.48, 1)",
    "shader_parameter/tint = Color(1.55, 0.52, 0.30, 1)",
)
lt = lt.replace(
    "shader_parameter/emission_color = Color(0, 0, 0, 1)",
    "shader_parameter/emission_color = Color(0.45, 0.10, 0.03, 1)",
)
lt = lt.replace(
    "shader_parameter/emission_energy = 0",
    "shader_parameter/emission_energy = 0.28",
)
lp.write_text(lt, encoding="utf-8")
print("mat_leito", "emission" in lt)

# kit palette punchier
kp = Path("game/src/world/kit_estrada.gd")
k = kp.read_text(encoding="utf-8")
k = k.replace(
    """const COR_TRILHA := Color(1.0, 0.48, 0.28)
const COR_MEIO := Color(0.78, 0.28, 0.14)
const COR_BEIRA := Color(0.62, 0.22, 0.11)
const COR_FOLHICO := Color(0.40, 0.28, 0.14)""",
    """const COR_TRILHA := Color(1.15, 0.42, 0.20)
const COR_MEIO := Color(0.85, 0.26, 0.12)
const COR_BEIRA := Color(0.68, 0.22, 0.10)
const COR_FOLHICO := Color(0.42, 0.28, 0.14)""",
)
kp.write_text(k, encoding="utf-8")
print("palette OK")

# builder canopy: raise into TOP of windshield, not center (was blacking chase)
bp = Path("game/src/world/estrada_builder.gd")
b = bp.read_text(encoding="utf-8")
old = """\t# Canopy/cipos ENTRANDO no para-brisa (y bem baixo, ref 04).
\tfor i in 14:
\t\tvar sc := s_carro + 0.8 + float(i) * 1.25
\t\tvar lado := 1.0 if i % 2 == 0 else -1.0
\t\tvar ancora := ponto_em(sc) + lado_em(sc) * (lado * rng.randf_range(2.2, 4.0))
\t\tancora.y += altura_lateral(4.0) + rng.randf_range(1.9, 3.2)
\t\tvar sobre := ponto_em(sc + rng.randf_range(-0.5, 0.5)) + lado_em(sc) * (lado * rng.randf_range(-1.6, 0.15))
\t\tsobre.y += rng.randf_range(1.15, 1.95)
\t\tKitEstrada.cipo(sup, ancora, sobre, rng)"""
new = """\t# Canopy no TOPO do para-brisa (ref 04). Y alto demais some; baixo demais
\t# tapa o facho/chase (tp_flora preto).
\tfor i in 12:
\t\tvar sc := s_carro + 1.5 + float(i) * 1.45
\t\tvar lado := 1.0 if i % 2 == 0 else -1.0
\t\tvar ancora := ponto_em(sc) + lado_em(sc) * (lado * rng.randf_range(2.8, 4.6))
\t\tancora.y += altura_lateral(4.0) + rng.randf_range(3.0, 4.6)
\t\tvar sobre := ponto_em(sc + rng.randf_range(-0.6, 0.6)) + lado_em(sc) * (lado * rng.randf_range(-1.3, 0.3))
\t\tsobre.y += rng.randf_range(2.15, 2.85)
\t\tKitEstrada.cipo(sup, ancora, sobre, rng)"""
if old not in b:
    raise SystemExit("canopy block missing")
b = b.replace(old, new, 1)

# also fix _detalhes cipo heights if too low
old2 = """\t\tancora.y += altura_lateral(4.0) + rng.randf_range(2.4, 4.6)
\t\tvar sobre := ponto_em(s + rng.randf_range(-1.2, 1.2)) + lado_em(s) * (lado * rng.randf_range(-1.2, 0.4))
\t\tsobre.y += rng.randf_range(1.55, 2.75)"""
new2 = """\t\tancora.y += altura_lateral(4.0) + rng.randf_range(3.0, 5.0)
\t\tvar sobre := ponto_em(s + rng.randf_range(-1.2, 1.2)) + lado_em(s) * (lado * rng.randf_range(-1.2, 0.4))
\t\tsobre.y += rng.randf_range(2.15, 3.0)"""
if old2 not in b:
    raise SystemExit("detalhes cipo missing")
b = b.replace(old2, new2, 1)
bp.write_text(b, encoding="utf-8")
print("builder canopy OK")

# kit cipo: hang from higher, drop into top third
k = kp.read_text(encoding="utf-8")
# soften queda so vines drape but don't fill
k2 = k.replace(
    "var queda := rng.randf_range(1.8, 3.6)",
    "var queda := rng.randf_range(1.4, 2.6)",
)
if k2 == k:
    print("WARN queda not found")
else:
    kp.write_text(k2, encoding="utf-8")
    print("cipo queda OK")
