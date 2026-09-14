# -*- coding: utf-8 -*-
from pathlib import Path
import re

fp = Path("game/resources/fog/fog_estrada_noite.tres")
f = fp.read_text(encoding="utf-8")
f2 = f.replace("fog_begin = 14.0", "fog_begin = 16.0")
f2 = f2.replace("ambient_energy = 0.38", "ambient_energy = 0.55")
f2 = f2.replace("facho_forca = 1.35", "facho_forca = 1.55")
f2 = f2.replace("ambient_color = Color(0.09, 0.10, 0.125, 1)", "ambient_color = Color(0.12, 0.11, 0.12, 1)")
if f2 == f:
    raise SystemExit("fog no change")
fp.write_text(f2, encoding="utf-8")
print("fog OK")

kp = Path("game/src/world/kit_estrada.gd")
k = kp.read_text(encoding="utf-8")
pat = r"\t\tvar alt := rng.randf_range\(1\.15, 1\.4\).*?PSXMesh\.FACE_TODAS, 6\.0\)"
m = re.search(pat, k, re.S)
if not m:
    raise SystemExit("cerca block miss")
new = """\t\tvar alt := rng.randf_range(1.25, 1.55)
\t\t# Mourao GROSSO claro — precisa ler no facho (ref 04).
\t\tKitModular.caixa_cor(sup, M_TABUA, p + Vector3(0.0, alt * 0.5, 0.0),
\t\t\tVector3(0.22, alt, 0.22), Color(\"9a8060\").lerp(Color(\"7a6548\"), rng.randf() * 0.35),
\t\t\tgiro + rng.randf_range(-0.12, 0.12), PSXMesh.FACE_TODAS, 4.0)
\t# Travessas de madeira + fio: silhueta de cerca, nao so fio fino.
\tfor y: float in [0.42, 0.72, 1.05, 1.28]:
\t\tvar meio := a + delta * 0.5 + Vector3(0.0, y, 0.0)
\t\tvar esp := 0.09 if y < 1.15 else 0.045
\t\tvar mat := M_TABUA if y < 1.15 else M_METAL
\t\tvar cor := Color(\"8a7050\") if y < 1.15 else Color(0.42, 0.40, 0.36)
\t\tKitModular.caixa_cor(sup, mat, meio,
\t\t\tVector3(esp, esp, comp), cor, giro, PSXMesh.FACE_TODAS, 6.0)"""
k = k[: m.start()] + new + k[m.end() :]
kp.write_text(k, encoding="utf-8")
print("cerca OK")
