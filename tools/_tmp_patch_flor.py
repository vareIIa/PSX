from pathlib import Path
p = Path(r"game/src/levels/abertura.gd")
text = p.read_text(encoding="utf-8")

helper = (
    "\n"
    "## Esconde MeshInstance3D \"flor\" do parque (atlas flor / moita) nos takes externos\n"
    "## — em 3/4 elevado leem como bastoes vermelhos de debug.\n"
    "func _set_flor_visivel(v: bool) -> void:\n"
    "\tif _cena == null:\n"
    "\t\treturn\n"
    "\tfor mi in _cena.find_children(\"flor\", \"MeshInstance3D\", true, false):\n"
    "\t\t(mi as MeshInstance3D).visible = v\n"
    "\n"
    "\n"
)

if "_set_flor_visivel" not in text:
    marker = "## Ha vista livre entre estes dois pontos?\nfunc _linha_livre"
    if marker not in text:
        raise SystemExit("marker for helper insert not found")
    text = text.replace(marker, helper + marker, 1)
    print("inserted helper")
else:
    print("helper already present")

part_b = "\t# --- Part B: takes externos, corpo AINDA DEITADO -----------------------\n"
if "_set_flor_visivel(false)" not in text:
    if part_b not in text:
        raise SystemExit("Part B marker not found")
    text = text.replace(part_b, part_b + "\t_set_flor_visivel(false)\n", 1)
    print("inserted flor false at Part B")
else:
    print("flor false already present")

cleanup = (
    "\tif figura != null:\n"
    "\t\t_deitar(figura, false)\n"
    "\t\tfigura.postura(Corpo.Postura.LIVRE)\n"
)
cleanup_new = (
    "\t_set_flor_visivel(true)\n"
    "\tif figura != null:\n"
    "\t\t_deitar(figura, false)\n"
    "\t\tfigura.postura(Corpo.Postura.LIVRE)\n"
)
anchor = (
    "\tawait _capturar_plano(\"praca_5\")\n"
    "\tawait get_tree().create_timer(3.2).timeout\n"
    "\n"
    "\tif _hud != null:\n"
    "\t\t_hud.visible = false\n"
    "\n"
    "\t# Proximos planos escondem/re-posam o corpo; desfaz o deitar SEM animacao\n"
    "\t# de levantar (nao e stand-up cinematografico).\n"
)
if "_set_flor_visivel(true)" not in text:
    idx = text.find(anchor)
    if idx < 0:
        raise SystemExit("cleanup anchor not found")
    rest_start = idx + len(anchor)
    rest = text[rest_start:]
    if not rest.startswith(cleanup):
        raise SystemExit("cleanup block not right after anchor:\n" + repr(rest[:200]))
    text = text[:rest_start] + cleanup_new + rest[len(cleanup):]
    print("inserted flor true at cleanup")
else:
    print("flor true already present")

p.write_text(text, encoding="utf-8")
print("OK wrote", p)
