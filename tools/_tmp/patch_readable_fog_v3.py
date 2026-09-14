# -*- coding: utf-8 -*-
"""v3: taller brighter coreto tip + stronger church silhouette; nudge church 1.5m south into fog."""
from pathlib import Path

kit = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\kit_parque.gd")
pb = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\parque_builder.gd")

t = kit.read_text(encoding="utf-8")

# Taller pointed roof + brighter tiles
assert "var roof_h := 2.55" in t
t = t.replace("var roof_h := 2.55", "var roof_h := 3.35")
t = t.replace('var telha := Color("a8683c")', 'var telha := Color("c87840")', 1)  # coreto only first
# Actually that might hit igreja too if same line - coreto has a8683c, igreja has 7a4e32
t = t.replace('var telha_escura := Color("8a4e2c")', 'var telha_escura := Color("a85830")')

# Stronger church colors
t = t.replace('var reboco := Color("e2d8c6")', 'var reboco := Color("efe6d4")')
t = t.replace('var porta := Color("1e3a28")', 'var porta := Color("0a1810")')
t = t.replace('var ombreira := Color("c8b89a")', 'var ombreira := Color("f0e4c8")')
t = t.replace('var trim := Color("2a2824")', 'var trim := Color("10100e")')
t = t.replace('var quoin_a := Color("8a7a62")', 'var quoin_a := Color("6a5a42")')
t = t.replace('var quoin_b := Color("6e5e4a")', 'var quoin_b := Color("4a3e30")')

# Bigger cross
t = t.replace(
    'cruz_c, Vector3(0.16, 1.15, 0.16), trim, giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)',
    'cruz_c, Vector3(0.22, 1.45, 0.22), trim, giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)',
)
t = t.replace(
    'cruz_c + Vector3(0.0, 0.28, 0.0), Vector3(0.78, 0.14, 0.14), trim, giro,',
    'cruz_c + Vector3(0.0, 0.35, 0.0), Vector3(1.0, 0.2, 0.2), trim, giro,',
)

# Larger door opening contrast
t = t.replace(
    'porta_c + Vector3(0.0, 0.05, 0.0), Vector3(2.15, 3.35, 0.22), ombreira, giro,',
    'porta_c + Vector3(0.0, 0.05, 0.0), Vector3(2.45, 3.55, 0.28), ombreira, giro,',
)
t = t.replace(
    'KitModular.caixa_cor(sup, &"porta", porta_c, Vector3(1.75, 3.05, 0.12), porta, giro,',
    'KitModular.caixa_cor(sup, &"porta", porta_c, Vector3(2.0, 3.25, 0.14), porta, giro,',
)

kit.write_text(t, encoding="utf-8")
print("kit OK")

# Nudge church 1.5m south so wake-up (~+8m) sees it inside fog_denso 18m
p = pb.read_text(encoding="utf-8")
old = "var igreja := Vector2(centro_q.x, praca.position.y + 5.5) + desloc"
new = "var igreja := Vector2(centro_q.x, praca.position.y + 7.0) + desloc"
assert old in p, "igreja line missing"
# footprint unchanged; only church center +1.5m toward coreto (still north of coreto)
p = p.replace(old, new, 1)
pb.write_text(p, encoding="utf-8")
print("parque_builder church nudge +1.5m south OK")
print("done")
