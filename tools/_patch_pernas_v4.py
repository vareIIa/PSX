# -*- coding: utf-8 -*-
from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")
old = (
	"\tvar calca := Color(\"3d4654\")\n"
	"\tvar bota := Color(\"1c1512\")\n"
	"\t# coxa / canela / bota - esquerda\n"
	"\t_caixa_fp(_pernas_fp, Vector3(0.16, 0.12, 0.50), Vector3(-0.12, -0.10, -0.48), calca)\n"
	"\t_caixa_fp(_pernas_fp, Vector3(0.14, 0.11, 0.44), Vector3(-0.12, -0.16, -0.96), calca)\n"
	"\t_caixa_fp(_pernas_fp, Vector3(0.15, 0.09, 0.28), Vector3(-0.12, -0.20, -1.32), bota)\n"
	"\t# direita\n"
	"\t_caixa_fp(_pernas_fp, Vector3(0.16, 0.12, 0.50), Vector3(0.12, -0.10, -0.48), calca)\n"
	"\t_caixa_fp(_pernas_fp, Vector3(0.14, 0.11, 0.44), Vector3(0.12, -0.16, -0.96), calca)\n"
	"\t_caixa_fp(_pernas_fp, Vector3(0.15, 0.09, 0.28), Vector3(0.12, -0.20, -1.32), bota)\n"
)
new = (
	"\tvar calca := Color(\"3d4654\")\n"
	"\tvar bota := Color(\"0e0a08\")\n"
	"\t# coxa (larga) / canela (afina) / cano + bico da bota\n"
	"\t_caixa_fp(_pernas_fp, Vector3(0.15, 0.13, 0.46), Vector3(-0.11, -0.09, -0.46), calca)\n"
	"\t_caixa_fp(_pernas_fp, Vector3(0.12, 0.11, 0.40), Vector3(-0.11, -0.15, -0.92), calca)\n"
	"\t_caixa_fp(_pernas_fp, Vector3(0.13, 0.10, 0.16), Vector3(-0.11, -0.18, -1.22), bota)\n"
	"\t_caixa_fp(_pernas_fp, Vector3(0.14, 0.07, 0.14), Vector3(-0.11, -0.21, -1.38), bota)\n"
	"\t_caixa_fp(_pernas_fp, Vector3(0.15, 0.13, 0.46), Vector3(0.11, -0.09, -0.46), calca)\n"
	"\t_caixa_fp(_pernas_fp, Vector3(0.12, 0.11, 0.40), Vector3(0.11, -0.15, -0.92), calca)\n"
	"\t_caixa_fp(_pernas_fp, Vector3(0.13, 0.10, 0.16), Vector3(0.11, -0.18, -1.22), bota)\n"
	"\t_caixa_fp(_pernas_fp, Vector3(0.14, 0.07, 0.14), Vector3(0.11, -0.21, -1.38), bota)\n"
)
if old not in t:
    raise SystemExit("legs block missing")
t = t.replace(old, new)
t = t.replace("var alvo_look := Vector3(272.0, 0.0, -66.0)", "var alvo_look := Vector3(272.0, 0.0, -58.0)")
t = t.replace(
    "var olhar_de := Vector3(onde.x, onde.y + 0.10, onde.z) + frente_praca * 2.8",
    "var olhar_de := Vector3(onde.x, onde.y + 0.04, onde.z) + frente_praca * 2.2",
)
p.write_text(t, encoding="utf-8", newline="\n")
print("OK boots+look")
