# -*- coding: utf-8 -*-
from pathlib import Path

path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
src = path.read_text(encoding="utf-8")

old = """\t# --- Part B: takes externos, corpo AINDA DEITADO -----------------------
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

new = """\t# --- Part B: takes externos, corpo AINDA DEITADO -----------------------
\t# Look no TORSO (meio), nao no telhado da igreja. Cams CURTAS: denso come
\t# tudo alem de ~4 m — corpo precisa dominar FG; igreja so peeks quando da.
\tawait Cinema.corte(0.14)
\t_jogador.mostrar_corpo(true)
\tif figura != null:
\t\t_deitar(figura, true)
\t\tfigura.postura(Corpo.Postura.DEITADO_ACORDAR)

\tvar meio: Vector3 = pose[\"meio\"]
\tvar torso := Vector3(meio.x, onde.y + 0.38, meio.z)

\t# praca_1 — high 3/4 from SOUTH, perto; corpo FG; look levemente N (igreja peek).
\tvar c1 := Vector3(torso.x - 1.4, onde.y + 4.6, torso.z + 2.8)
\tvar l1 := Vector3(torso.x + 0.15, onde.y + 0.42, torso.z - 0.8)
\tCinema.enquadrar(c1, l1, 52.0)
\tawait Cinema.clarear(0.35)
\tCinema.legenda(FALAS[\"praca_1\"], 3.8)
\tawait get_tree().create_timer(0.55).timeout
\tawait _capturar_plano(\"02_deitado_igreja\")
\tawait get_tree().create_timer(3.3).timeout

\t# praca_2 — lower 3/4 from SW, perto; look no torso; coreto west a esq.
\tawait Cinema.corte(0.1)
\tvar c2 := Vector3(torso.x - 3.2, onde.y + 3.0, torso.z + 2.4)
\tvar l2 := Vector3(torso.x, onde.y + 0.4, torso.z)
\tCinema.enquadrar(c2, l2, 52.0)
\tawait Cinema.clarear(0.28)
\tCinema.legenda(FALAS[\"praca_2\"], 3.2)
\tawait get_tree().create_timer(0.5).timeout
\tawait _capturar_plano(\"praca_2\")
\tawait get_tree().create_timer(2.8).timeout

\t# praca_3 — perfil from east, look no torso (elevado o bastante pra ler deitado).
\tawait Cinema.corte(0.1)
\tvar c3 := Vector3(torso.x + 3.0, onde.y + 2.4, torso.z + 0.4)
\tvar l3 := Vector3(torso.x, onde.y + 0.42, torso.z)
\tCinema.enquadrar(c3, l3, 50.0)
\tawait Cinema.clarear(0.28)
\tCinema.legenda(FALAS[\"praca_3\"], 3.4)
\tawait get_tree().create_timer(0.5).timeout
\tawait _capturar_plano(\"praca_3\")
\tawait get_tree().create_timer(3.0).timeout

\t# praca_4 — closer 3/4 no torso/cabeca deitado.
\tawait Cinema.corte(0.1)
\tvar c4 := Vector3(torso.x + 0.9, onde.y + 1.55, torso.z + 1.7)
\tvar l4 := Vector3(torso.x, onde.y + 0.42, torso.z - 0.15)
\tCinema.enquadrar(c4, l4, 46.0)
\tawait Cinema.clarear(0.28)
\tCinema.legenda(FALAS[\"praca_4\"], 3.2)
\tawait get_tree().create_timer(0.5).timeout
\tawait _capturar_plano(\"praca_4\")
\tawait get_tree().create_timer(2.8).timeout

\t# praca_5 — establishing south mais perto: corpo lower-third + eixo igreja.
\t# Look entre corpo e igreja (~271, y+1.2, -46); cam nao pode ir longe demais
\t# senao denso apaga o corpo.
\tawait Cinema.corte(0.1)
\tvar c5 := Vector3(torso.x - 1.2, onde.y + 5.0, torso.z + 5.5)
\tvar l5 := Vector3(271.0, onde.y + 1.15, -46.0)
\tCinema.enquadrar(c5, l5, 56.0)
\tawait Cinema.clarear(0.28)
\tCinema.legenda(FALAS[\"praca_5\"], 3.6)
\tawait get_tree().create_timer(0.5).timeout
\tawait _capturar_plano(\"praca_5\")
\tawait get_tree().create_timer(3.2).timeout
"""

if old not in src:
    print("NOT FOUND")
    raise SystemExit(1)
path.write_text(src.replace(old, new), encoding="utf-8")
print("OK pass2")
