from pathlib import Path
pb = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\parque_builder.gd")
t = pb.read_text(encoding="utf-8")
reps = [
("##   igreja = centro + (0, +0.8) -> ~ (271, -49.45) // fachada flush ~6 m do pin",
 "##   igreja = centro + (0, -5.0) -> ~ (271, -55.25) // fundo como refs 01-02 (~15 m do pin)"),
("##   (antes -1.5 + portal +1.4; sem portal a porta ficava a ~8 m e sumia no denso)",
 "##   (antes +0.8 colava no wake; -5.0 afasta. Fog curto ainda come a torre — peeks.)"),
("\tvar coreto_p := Vector2(centro_q.x - 7.0, centro_q.y + 4.0) + desloc",
 "\tvar coreto_p := Vector2(centro_q.x - 8.5, centro_q.y + 2.0) + desloc"),
("\tvar igreja := Vector2(centro_q.x, centro_q.y + 0.8) + desloc",
 "\tvar igreja := Vector2(centro_q.x, centro_q.y - 5.0) + desloc"),
("\tvar n_casas := 3",
 "\tvar n_casas := 4"),
("\t\t\tvar x := praca.position.x + 3.6 if lado_s < 0.0 else praca.end.x - 3.6",
 "\t\t\tvar x := praca.position.x + 2.8 if lado_s < 0.0 else praca.end.x - 2.8"),
("\t\t\tvar z := lerpf(centro_q.y - 6.0, centro_q.y + 16.0, tt)",
 "\t\t\tvar z := lerpf(centro_q.y - 8.0, centro_q.y + 14.0, tt)"),
("\t# Zona do coreto (oeste -7, +4) + igreja (-4.5) sem banco/poste em cima.",
 "\t# Zona do coreto (oeste -8.5, +2) + igreja (-5.0) sem banco/poste em cima."),
("\t\tRect2(centro.x - 7.0 - 5.5, centro.y + 4.0 - 5.5, 11.0, 11.0),",
 "\t\tRect2(centro.x - 8.5 - 5.5, centro.y + 2.0 - 5.5, 11.0, 11.0),"),
("\t\tRect2(centro.x - 8.0, centro.y + 0.8 - 6.0, 16.0, 14.0),",
 "\t\tRect2(centro.x - 8.0, centro.y - 5.0 - 6.0, 16.0, 14.0),"),
("\t\tvar pd := Vector2(centro.x + 3.4 * sx, centro.y + 0.8 + 4.2)",
 "\t\tvar pd := Vector2(centro.x + 3.4 * sx, centro.y - 5.0 + 4.2)"),
('"cor": Color("ffe0a8"), "energia": 6.5, "alcance": 11.0,',
 '"cor": Color("ffe0a8"), "energia": 8.0, "alcance": 12.0,'),
('"cor": Color("ffe0a0"), "energia": 7.2, "alcance": 16.0,',
 '"cor": Color("ffe0a0"), "energia": 9.0, "alcance": 14.0,'),
]
n = 0
for a, b in reps:
    if a not in t:
        print("MISS:", a[:70])
    else:
        t = t.replace(a, b, 1)
        n += 1
        print("OK", n)
pb.write_text(t, encoding="utf-8")
print("done", n)
