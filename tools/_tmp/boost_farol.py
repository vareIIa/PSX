from pathlib import Path
p = Path(r"game\src\world\carro_cena.gd")
t = p.read_text(encoding="utf-8")
reps = [
("_farol.spot_range = 28.0", "_farol.spot_range = 34.0"),
("_farol.spot_angle = 36.0", "_farol.spot_angle = 42.0"),
("_farol.light_energy = 4.4", "_farol.light_energy = 6.2"),
("_farol.light_color = Color(1.0, 0.93, 0.8)", "_farol.light_color = Color(1.0, 0.88, 0.68)"),
("PSXMesh.cone(0.10, 2.6, 10.0, 8, 3,", "PSXMesh.cone(0.12, 3.2, 12.0, 8, 3,"),
]
n = 0
for a,b in reps:
    if a in t:
        t = t.replace(a,b); n += 1
    else:
        print("miss", a)
p.write_text(t, encoding="utf-8")
print("replaced", n)
