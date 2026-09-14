# -*- coding: utf-8 -*-
from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")

old_mat = """\tvar mat := StandardMaterial3D.new()
\tmat.albedo_color = cor
\tmat.roughness = 0.92
\tmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
\tmi.material_override = mat
"""
new_mat = """\tvar mat := StandardMaterial3D.new()
\tmat.albedo_color = cor
\tmat.roughness = 0.92
\tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
\tmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
\tmi.material_override = mat
"""
if old_mat not in t:
    raise SystemExit("mat block missing")
t = t.replace(old_mat, new_mat)

# Replace leg boxes by locating markers
mark_a = "Pernas ESTICADAS no -Z"
mark_b = "func _plano_da_praca"
ia = t.find(mark_a)
if ia < 0:
    raise SystemExit("legs mark missing: " + repr(mark_a))
start = t.rfind("\t# Espaco da camera", 0, ia)
if start < 0:
    start = t.rfind("\n", 0, ia) + 1
ib = t.find(mark_b, ia)
# back up over blank lines before func
while ib > 0 and t[ib-1] in "\n\t ":
    ib -= 1
ib = t.find("\n", ib)  # no — ib is at 'f' of func
ib = t.find(mark_b, ia)

new_legs = """\t# Espaco da camera: -Z frente, Y cima. Esticadas no -Z (ref 01).
\t# Y menos negativo = dentro da letterbox (barra preta come o fundo do FOV).
\tvar calca := Color(\"3d4654\")
\tvar bota := Color(\"1c1512\")
\t# coxa / canela / bota - esquerda
\t_caixa_fp(_pernas_fp, Vector3(0.16, 0.12, 0.50), Vector3(-0.12, -0.10, -0.48), calca)
\t_caixa_fp(_pernas_fp, Vector3(0.14, 0.11, 0.44), Vector3(-0.12, -0.16, -0.96), calca)
\t_caixa_fp(_pernas_fp, Vector3(0.15, 0.09, 0.28), Vector3(-0.12, -0.20, -1.32), bota)
\t# direita
\t_caixa_fp(_pernas_fp, Vector3(0.16, 0.12, 0.50), Vector3(0.12, -0.10, -0.48), calca)
\t_caixa_fp(_pernas_fp, Vector3(0.14, 0.11, 0.44), Vector3(0.12, -0.16, -0.96), calca)
\t_caixa_fp(_pernas_fp, Vector3(0.15, 0.09, 0.28), Vector3(0.12, -0.20, -1.32), bota)


"""
t = t[:start] + new_legs + t[ib:]

# Drop early montar call (keep hide body)
needle_montar = "\t_montar_pernas_fp(Cinema.assumir())\n"
# only remove the one right after mostrar_corpo(false)
anchor = "_jogador.mostrar_corpo(false)\n"
pos = t.find(anchor)
if pos < 0:
    raise SystemExit("mostrar_corpo missing")
pos2 = t.find(needle_montar, pos)
if pos2 < 0 or pos2 > pos + 80:
    raise SystemExit("early montar not next to hide")
t = t[:pos2] + t[pos2 + len(needle_montar):]

needle = 'await Cinema.clarear(2.2)\n\tCinema.legenda(FALAS["acorda"], 2.2)\n\tawait _capturar_plano("01_acordar_chao")'
repl = 'await Cinema.clarear(2.2)\n\t_montar_pernas_fp(Cinema.assumir())\n\tCinema.legenda(FALAS["acorda"], 2.2)\n\tawait _capturar_plano("01_acordar_chao")'
if needle not in t:
    raise SystemExit("flow needle missing")
t = t.replace(needle, repl, 1)

p.write_text(t, encoding="utf-8", newline="\n")
print("OK visibility+remount")
