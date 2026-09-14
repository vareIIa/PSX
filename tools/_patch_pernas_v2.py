# -*- coding: utf-8 -*-
from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")

old_montar = """func _montar_pernas_fp(cam: Camera3D) -> void:
\t_limpar_pernas_fp()
\tif cam == null:
\t\treturn
\t_pernas_fp = Node3D.new()
\t_pernas_fp.name = \"PernasFPAcordar\"
\tcam.add_child(_pernas_fp)
\t# Espaco da camera: -Z frente, Y cima. Terco baixo do frame (ref 01).
\tvar calca := Color(\"2a3340\")
\tvar bota := Color(\"1a1410\")
\t_caixa_fp(_pernas_fp, Vector3(0.13, 0.38, 0.16), Vector3(-0.11, -0.32, -0.55), calca)
\t_caixa_fp(_pernas_fp, Vector3(0.11, 0.34, 0.14), Vector3(-0.11, -0.48, -0.88), calca)
\t_caixa_fp(_pernas_fp, Vector3(0.12, 0.08, 0.26), Vector3(-0.11, -0.62, -1.12), bota)
\t_caixa_fp(_pernas_fp, Vector3(0.13, 0.38, 0.16), Vector3(0.11, -0.32, -0.55), calca)
\t_caixa_fp(_pernas_fp, Vector3(0.11, 0.34, 0.14), Vector3(0.11, -0.48, -0.88), calca)
\t_caixa_fp(_pernas_fp, Vector3(0.12, 0.08, 0.26), Vector3(0.11, -0.62, -1.12), bota)
"""

new_montar = """func _montar_pernas_fp(cam: Camera3D) -> void:
\t_limpar_pernas_fp()
\tif cam == null:
\t\treturn
\t_pernas_fp = Node3D.new()
\t_pernas_fp.name = \"PernasFPAcordar\"
\tcam.add_child(_pernas_fp)
\t# Espaco da camera: -Z frente, Y cima. Pernas ESTICADAS no -Z (ref 01),
\t# nao caixas altas no Y (isso lia como cubo/massa).
\tvar calca := Color(\"2a3340\")
\tvar bota := Color(\"1a1410\")
\t# coxa / canela / bota — esquerda
\t_caixa_fp(_pernas_fp, Vector3(0.14, 0.09, 0.46), Vector3(-0.10, -0.26, -0.52), calca)
\t_caixa_fp(_pernas_fp, Vector3(0.12, 0.08, 0.40), Vector3(-0.10, -0.34, -0.98), calca)
\t_caixa_fp(_pernas_fp, Vector3(0.13, 0.07, 0.24), Vector3(-0.10, -0.40, -1.30), bota)
\t# direita
\t_caixa_fp(_pernas_fp, Vector3(0.14, 0.09, 0.46), Vector3(0.10, -0.26, -0.52), calca)
\t_caixa_fp(_pernas_fp, Vector3(0.12, 0.08, 0.40), Vector3(0.10, -0.34, -0.98), calca)
\t_caixa_fp(_pernas_fp, Vector3(0.13, 0.07, 0.24), Vector3(0.10, -0.40, -1.30), bota)
"""

if old_montar not in t:
    raise SystemExit("montar block missing")
t = t.replace(old_montar, new_montar)

i = t.find("var alvo_look := Vector3(272.0, 0.0, -52.0)")
if i < 0:
    raise SystemExit("alvo_look missing")
j = t.find("var t0 := Time.get_ticks_msec()", i)
if j < 0:
    raise SystemExit("t0 missing")

new_cam = """\tvar alvo_look := Vector3(272.0, 0.0, -66.0)
\tvar frente_praca := Vector3(alvo_look.x - onde.x, 0.0, alvo_look.z - onde.z)
\tif frente_praca.length_squared() < 0.01:
\t\tfrente_praca = Vector3(0.0, 0.0, -1.0)
\tfrente_praca = frente_praca.normalized()

\t# Pin-world (nao osso): corpo escondido + props na cam. Olhar rasteiro
\t# pra norte evita enxergar o soffit do coreto (falha da PNG anterior).
\tvar cam_de := Vector3(onde.x, onde.y + 0.22, onde.z)
\tvar olhar_de := Vector3(onde.x, onde.y + 0.10, onde.z) + frente_praca * 2.8
\tvar cam_ate := Vector3(onde.x, onde.y + ACORDA_ALTURA.y, onde.z)
\tvar olhar_ate := Vector3(onde.x, onde.y + 1.15, onde.z) + frente_praca * ACORDA_OLHAR_LONGE

"""
t = t[:i] + new_cam + t[j:]
p.write_text(t, encoding="utf-8", newline="\n")
print("OK patched pernas+cam")
