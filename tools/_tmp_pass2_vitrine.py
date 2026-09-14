# -*- coding: utf-8 -*-
from pathlib import Path
import re

p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\carros_teste.gd")
t = p.read_text(encoding="utf-8")

old_mod = (
    "const MODELOS: Array[Carroceria.Modelo] = [\n"
    "\tCarroceria.Modelo.SEDA, Carroceria.Modelo.HATCH, Carroceria.Modelo.PERUA,\n"
    "\tCarroceria.Modelo.PICAPE, Carroceria.Modelo.TAXI,\n"
    "]"
)
new_mod = (
    "const MODELOS: Array[Carroceria.Modelo] = [\n"
    "\tCarroceria.Modelo.SEDA, Carroceria.Modelo.HATCH, Carroceria.Modelo.PERUA,\n"
    "\tCarroceria.Modelo.PICAPE, Carroceria.Modelo.TAXI,\n"
    "\tCarroceria.Modelo.MAREA, Carroceria.Modelo.FUSCA,\n"
    "]"
)
if "Modelo.FUSCA" not in t.split("MODELOS")[1].split("]")[0]:
    if old_mod not in t:
        raise SystemExit("MODELOS block missing")
    t = t.replace(old_mod, new_mod, 1)
else:
    print("MODELOS already has FUSCA")

if "TINTA_FUSCA" not in t:
    old_tint = (
        "\t\tvar tinta: Color = Carroceria.TINTAS[k * 2 % Carroceria.TINTAS.size()]\n"
        "\t\tvar d := Carroceria.montar(modelo, tinta, k * 13)"
    )
    new_tint = (
        "\t\tvar tinta: Color = Carroceria.TINTAS[k * 2 % Carroceria.TINTAS.size()]\n"
        "\t\tif modelo == Carroceria.Modelo.FUSCA:\n"
        "\t\t\ttinta = Carroceria.TINTA_FUSCA\n"
        "\t\tvar d := Carroceria.montar(modelo, tinta, k * 13)"
    )
    if old_tint not in t:
        raise SystemExit("tint block missing")
    t = t.replace(old_tint, new_tint, 1)

new_cam = '''func _posicionar_camera(vista: String, perto: float) -> void:
\t# Perto aproxima em XZ; altura nao esmaga (senao --so=N deixa a camera
\t# na altura do para-choque e o perfil vira um "traseira" achatado).
\tvar d := clampf(perto, 0.35, 1.0)
\tvar hy := maxf(1.0, 1.0 / sqrt(d))
\tmatch vista:
\t\t"tras":
\t\t\t_cam.position = Vector3(0.0, 2.6 * hy, -11.0 * d)
\t\t"cima":
\t\t\t_cam.position = Vector3(0.0, 12.0 * d, 0.01)
\t\t"lado":
\t\t\t_cam.position = Vector3(11.0 * d, 1.7 * hy, 0.0)
\t\t"frente_rua":
\t\t\t# Olha a FRETE real do carro (que aponta -Z).
\t\t\t_cam.position = Vector3(5.5 * d, 2.4 * hy, -10.0 * d)
\t\t"dentro":
\t\t\t_cam.position = Vector3(0.0, 1.15, 0.35)
\t\t_:
\t\t\tif perto >= 1.0:
\t\t\t\t_cam.position = Vector3(7.0, 5.2, 17.0)
\t\t\telse:
\t\t\t\t_cam.position = Vector3(6.5 * d, 2.8 * hy, 11.0 * d)
\t_cam.look_at(Vector3(0.0, 0.75, 0.0), Vector3.UP)
'''

m = re.search(
    r"func _posicionar_camera\(vista: String, perto: float\) -> void:\r?\n"
    r"(?:.*\r?\n)*?"
    r"\t_cam\.look_at\(Vector3\(0\.0, 0\.(?:7|75), 0\.0\), Vector3\.UP\)\r?\n",
    t,
)
if not m:
    raise SystemExit("camera function not found:\n" + repr(t[t.find("func _posicionar_camera"):]))
t = t[: m.start()] + new_cam + t[m.end() :]
p.write_text(t, encoding="utf-8")
print("carros_teste ok", p.stat().st_size)
print("FUSCA in MODELOS", "Modelo.FUSCA" in t[t.index("MODELOS"):t.index("MODELOS")+300])
print("hy present", "var hy" in t)
