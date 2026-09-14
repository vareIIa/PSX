# -*- coding: utf-8 -*-
from pathlib import Path
import re

# carro.gd — tune weights to ~10% taxi, ~28% fusca, ~62% marea
p2 = Path("game/src/world/carro.gd")
t2 = p2.read_text(encoding="utf-8")
m = re.search(r"static func _sortear_modelo\(s: int\) -> Carroceria\.Modelo:\n(?:.*\n)*?(\treturn Carroceria\.Modelo\.\w+\n)", t2)
if not m:
    raise SystemExit("sortear not found")
old = m.group(0)
print("OLD SORTEAR:\n", old)
new = """static func _sortear_modelo(s: int) -> Carroceria.Modelo:
\t# Rua = Marea + Fusca (Jota), com taxi raro. Genericos ficam no enum
\t# para blitz/vitrine, mas o transito urbano e dos dois.
\tvar h := absi(s * 2654435761) % 100
\tif h < 10:
\t\treturn Carroceria.Modelo.TAXI
\tif h < 38:
\t\treturn Carroceria.Modelo.FUSCA
\treturn Carroceria.Modelo.MAREA
"""
t2 = t2[:m.start()] + new + t2[m.end():]
p2.write_text(t2, encoding="utf-8")
print("carro.gd OK")

# carro_cena.gd
p3 = Path("game/src/world/carro_cena.gd")
t3 = p3.read_text(encoding="utf-8")
t3, n1 = re.subn(
    r"## Hatch claro das refs de chase \(nao o verde do corte cinematografico antigo\)\.\nconst TINTA := Color\([^)]+\)\nconst SEMENTE := \d+\nconst MODELO := Carroceria\.Modelo\.\w+\n",
    "## Marea creme sujo das refs de chase (Estrada Velha).\nconst TINTA := Color(0.90, 0.88, 0.80)\nconst SEMENTE := 4410\nconst MODELO := Carroceria.Modelo.MAREA\n",
    t3, count=1)
if n1 != 1:
    # try without the hatch comment
    t3, n1 = re.subn(
        r"const TINTA := Color\([^)]+\)\nconst SEMENTE := \d+\nconst MODELO := Carroceria\.Modelo\.\w+\n",
        "const TINTA := Color(0.90, 0.88, 0.80)\nconst SEMENTE := 4410\nconst MODELO := Carroceria.Modelo.MAREA\n",
        t3, count=1)
    if n1 != 1:
        raise SystemExit(f"carro_cena consts not patched n={n1}")
t3 = t3.replace("Pivo atras do hatch para a chase cam", "Pivo atras do Marea para a chase cam")
t3 = t3.replace("hatch branco precisa ler na 3P a noite", "Marea creme precisa ler na 3P a noite")
p3.write_text(t3, encoding="utf-8")
print("carro_cena.gd OK")

# carros_teste.gd — cream dirty for MAREA; MODELOS already has MAREA/FUSCA
p4 = Path("game/src/levels/carros_teste.gd")
t4 = p4.read_text(encoding="utf-8")
t4 = t4.replace("Monta os cinco modelos da Carroceria lado a lado",
                "Monta os sete modelos da Carroceria lado a lado")
t4 = t4.replace("## -1 monta os cinco; 0..4 monta so aquele, e a camera chega perto.",
                "## -1 monta todos; 0..N monta so aquele, e a camera chega perto.")
old_loop = """\t\tvar modelo: Carroceria.Modelo = MODELOS[k]
\t\tvar tinta: Color = Carroceria.TINTAS[k * 2 % Carroceria.TINTAS.size()]
\t\tvar d := Carroceria.montar(modelo, tinta, k * 13)
"""
new_loop = """\t\tvar modelo: Carroceria.Modelo = MODELOS[k]
\t\tvar tinta: Color = Carroceria.TINTAS[k * 2 % Carroceria.TINTAS.size()]
\t\tvar semente := k * 13
\t\tif modelo == Carroceria.Modelo.MAREA:
\t\t\ttinta = Color(0.90, 0.88, 0.80)
\t\t\tsemente = 4410
\t\tvar d := Carroceria.montar(modelo, tinta, semente)
"""
if old_loop not in t4:
    raise SystemExit("vitrine loop not found")
t4 = t4.replace(old_loop, new_loop, 1)
if "Carroceria.Modelo.MAREA" not in t4:
    raise SystemExit("MODELOS missing MAREA")
p4.write_text(t4, encoding="utf-8")
print("carros_teste.gd OK")

# Verify marea function body exists fully
tc = Path("game/src/render/carroceria.gd").read_text(encoding="utf-8")
assert "static func _frente_e_tras_marea" in tc
assert "tres venezianas" in tc.lower() or "venezianas escuras" in tc
print("marea body present")
