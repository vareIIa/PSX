# -*- coding: utf-8 -*-
from pathlib import Path
import re

bp = Path("game/src/world/estrada_builder.gd")
b = bp.read_text(encoding="utf-8")
pat = r"func spawn_olhos_nevoa\(s_carro: float, frente: float = 28\.0\) -> void:.*?(?=\n\n## Garante|\nfunc garantir_props)"
m = re.search(pat, b, re.S)
if not m:
    raise SystemExit("olhos func miss")
new = (
    "func spawn_olhos_nevoa(s_carro: float, frente: float = 28.0) -> void:\n"
    "\t# Pass flora_04: REMOVE twin red dots (confundiam o facho / casa).\n"
    "\t# Beat de horror volta depois com silhueta clara, nao bolhao unshaded.\n"
    "\tvar velho := get_node_or_null(\"OlhosNevoa\")\n"
    "\tif velho != null:\n"
    "\t\tvelho.queue_free()\n"
    "\tvar _s := s_carro\n"
    "\tvar _f := frente\n\n\n"
)
b = b[: m.start()] + new + b[m.end() :]
old_h = "var s := s_carro + 6.4\n\tvar d_casa := KitEstrada.MEIA_PISTA + 0.85"
new_h = "var s := s_carro + 5.5\n\tvar d_casa := KitEstrada.MEIA_PISTA + 0.75"
if old_h not in b:
    raise SystemExit("house pos miss")
b = b.replace(old_h, new_h, 1)
bp.write_text(b, encoding="utf-8")
print("builder OK")

kp = Path("game/src/world/kit_estrada.gd")
k = kp.read_text(encoding="utf-8")
old_c = "var larg := rng.randf_range(3.0, 3.8)\n\tvar fund := rng.randf_range(2.3, 2.9)\n\tvar alt := rng.randf_range(2.05, 2.55)"
new_c = "var larg := rng.randf_range(3.4, 4.2)\n\tvar fund := rng.randf_range(2.5, 3.1)\n\tvar alt := rng.randf_range(2.2, 2.7)"
if old_c not in k:
    raise SystemExit("casa size miss")
k = k.replace(old_c, new_c, 1)
kp.write_text(k, encoding="utf-8")
print("kit OK")
