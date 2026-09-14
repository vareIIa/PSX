# -*- coding: utf-8 -*-
from pathlib import Path

path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
src = path.read_text(encoding="utf-8")

old = """\t# --- Part B: takes externos, corpo AINDA DEITADO -----------------------
\tawait Cinema.corte(0.14)
\t_jogador.mostrar_corpo(true)
\tif figura != null:
\t\tfigura.postura(Corpo.Postura.DEITADO_ACORDAR)

\t# praca_1 — high 3/4 overhead, corpo FG, igreja atras.
\tvar c1 := Vector3(onde.x - 1.8, onde.y + 8.2, onde.z + 5.2)
\tvar l1 := Vector3(igreja.x, onde.y + 2.0, igreja.z)
\tCinema.enquadrar(c1, l1, 56.0)
\tawait Cinema.clarear(0.35)
\tCinema.legenda(FALAS[\"praca_1\"], 3.8)
\tawait get_tree().create_timer(0.55).timeout
\tawait _capturar_plano(\"02_deitado_igreja\")
\tawait get_tree().create_timer(3.3).timeout

\t# praca_2 — lower 3/4 from SW; coreto a esquerda, igreja atras do corpo.
\tawait Cinema.corte(0.1)
\tvar c2 := Vector3(onde.x - 6.0, onde.y + 2.6, onde.z + 3.8)
\tvar l2 := Vector3(igreja.x, onde.y + 1.5, igreja.z)
\tCinema.enquadrar(c2, l2, 54.0)
\tawait Cinema.clarear(0.28)
\tCinema.legenda(FALAS[\"praca_2\"], 3.2)
\tawait get_tree().create_timer(0.5).timeout
\tawait _capturar_plano(\"praca_2\")
\tawait get_tree().create_timer(2.8).timeout

\t# praca_3 — perfil / lado do corpo, leitura da praca.
\tawait Cinema.corte(0.1)
\tvar c3 := Vector3(onde.x + 5.5, onde.y + 1.9, onde.z + 0.6)
\tvar l3 := Vector3(onde.x - 1.0, onde.y + 0.55, onde.z - 2.5)
\tCinema.mover(
\t\tc3, Vector3(c3.x - 0.6, c3.y - 0.15, c3.z - 0.8),
\t\tl3, Vector3(l3.x - 0.4, l3.y, l3.z - 1.2),
\t\t3.2, 58.0, 54.0)
\tawait Cinema.clarear(0.28)
\tCinema.legenda(FALAS[\"praca_3\"], 3.4)
\tawait get_tree().create_timer(0.5).timeout
\tawait _capturar_plano(\"praca_3\")
\tawait get_tree().create_timer(3.0).timeout

\t# praca_4 — closer face/torso deitado, igreja soft bg.
\tawait Cinema.corte(0.1)
\tvar c4 := Vector3(onde.x + 1.6, onde.y + 1.15, onde.z + 2.2)
\tvar l4 := Vector3(onde.x - 0.2, onde.y + 0.45, onde.z - 0.4)
\tCinema.enquadrar(c4, l4, 48.0)
\tawait Cinema.clarear(0.28)
\tCinema.legenda(FALAS[\"praca_4\"], 3.2)
\tawait get_tree().create_timer(0.5).timeout
\tawait _capturar_plano(\"praca_4\")
\tawait get_tree().create_timer(2.8).timeout

\t# praca_5 — wider establishing: corpo + igreja + lampiao.
\tawait Cinema.corte(0.1)
\tvar c5 := Vector3(onde.x - 7.5, onde.y + 4.8, onde.z + 7.0)
\tvar l5 := Vector3(igreja.x - 1.0, onde.y + 2.4, igreja.z)
\tCinema.enquadrar(c5, l5, 62.0)
\tawait Cinema.clarear(0.28)
\tCinema.legenda(FALAS[\"praca_5\"], 3.6)
\tawait get_tree().create_timer(0.5).timeout
\tawait _capturar_plano(\"praca_5\")
\tawait get_tree().create_timer(3.2).timeout
"""

new = """\t# --- Part B: takes externos, corpo AINDA DEITADO -----------------------
\t# Look no CORPO (nao no telhado da igreja): corpo FG, igreja so peeks atras.
\tawait Cinema.corte(0.14)
\t_jogador.mostrar_corpo(true)
\tif figura != null:
\t\t_deitar(figura, true)
\t\tfigura.postura(Corpo.Postura.DEITADO_ACORDAR)

\t# praca_1 — high 3/4 from SOUTH (z > onde.z), corpo domina FG, igreja peek.
\tvar c1 := Vector3(onde.x - 2.2, onde.y + 5.4, onde.z + 4.8)
\tvar l1 := Vector3(onde.x + 0.2, onde.y + 0.4, onde.z - 1.5)
\tCinema.enquadrar(c1, l1, 55.0)
\tawait Cinema.clarear(0.35)
\tCinema.legenda(FALAS[\"praca_1\"], 3.8)
\tawait get_tree().create_timer(0.55).timeout
\tawait _capturar_plano(\"02_deitado_igreja\")
\tawait get_tree().create_timer(3.3).timeout

\t# praca_2 — lower 3/4 from SW; look no corpo; coreto west pode aparecer esq.
\tawait Cinema.corte(0.1)
\tvar c2 := Vector3(onde.x - 5.5, onde.y + 2.8, onde.z + 4.2)
\tvar l2 := Vector3(onde.x, onde.y + 0.4, onde.z - 0.8)
\tCinema.enquadrar(c2, l2, 54.0)
\tawait Cinema.clarear(0.28)
\tCinema.legenda(FALAS[\"praca_2\"], 3.2)
\tawait get_tree().create_timer(0.5).timeout
\tawait _capturar_plano(\"praca_2\")
\tawait get_tree().create_timer(2.8).timeout

\t# praca_3 — perfil from east, look no torso deitado.
\tawait Cinema.corte(0.1)
\tvar c3 := Vector3(onde.x + 4.8, onde.y + 1.7, onde.z + 0.8)
\tvar l3 := Vector3(onde.x, onde.y + 0.45, onde.z - 0.3)
\tCinema.mover(
\t\tc3, Vector3(c3.x - 0.5, c3.y - 0.1, c3.z - 0.4),
\t\tl3, Vector3(l3.x - 0.2, l3.y, l3.z - 0.3),
\t\t3.2, 56.0, 52.0)
\tawait Cinema.clarear(0.28)
\tCinema.legenda(FALAS[\"praca_3\"], 3.4)
\tawait get_tree().create_timer(0.5).timeout
\tawait _capturar_plano(\"praca_3\")
\tawait get_tree().create_timer(3.0).timeout

\t# praca_4 — closer 3/4 no torso/cabeca deitado.
\tawait Cinema.corte(0.1)
\tvar c4 := Vector3(onde.x + 1.4, onde.y + 1.35, onde.z + 2.4)
\tvar l4 := Vector3(onde.x - 0.1, onde.y + 0.4, onde.z - 0.2)
\tCinema.enquadrar(c4, l4, 48.0)
\tawait Cinema.clarear(0.28)
\tCinema.legenda(FALAS[\"praca_4\"], 3.2)
\tawait get_tree().create_timer(0.5).timeout
\tawait _capturar_plano(\"praca_4\")
\tawait get_tree().create_timer(2.8).timeout

\t# praca_5 — wider establishing south: corpo + igreja + lampiao; look between.
\tawait Cinema.corte(0.1)
\tvar c5 := Vector3(onde.x - 2.8, onde.y + 5.2, onde.z + 9.0)
\tvar l5 := Vector3(271.0, onde.y + 1.2, -47.5)
\tCinema.enquadrar(c5, l5, 58.0)
\tawait Cinema.clarear(0.28)
\tCinema.legenda(FALAS[\"praca_5\"], 3.6)
\tawait get_tree().create_timer(0.5).timeout
\tawait _capturar_plano(\"praca_5\")
\tawait get_tree().create_timer(3.2).timeout
"""

if old not in src:
    # diagnose em-dash vs hyphen
    idx = src.find("Part B: takes externos")
    print("NOT FOUND. Part B idx:", idx)
    if idx >= 0:
        chunk = src[idx:idx+400]
        print(repr(chunk[:200]))
    raise SystemExit(1)

path.write_text(src.replace(old, new), encoding="utf-8")
print("OK patched")
# verify key lines
for i, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
    if "_deitar(figura, true)" in line or "var c1 :=" in line or "var l1 :=" in line or "var l5 :=" in line:
        if 760 <= i <= 830 or "_deitar" in line:
            print(f"{i}: {line.strip()}")
