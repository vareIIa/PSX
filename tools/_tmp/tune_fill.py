from pathlib import Path
p = Path(r"game\src\world\carro_cena.gd")
t = p.read_text(encoding="utf-8")
t2 = t.replace("fill.light_energy = 0.55", "fill.light_energy = 0.35")
t2 = t2.replace("fill.light_color = Color(0.85, 0.88, 1.0)", "fill.light_color = Color(0.95, 0.75, 0.55)")
p.write_text(t2, encoding="utf-8")
print("fill warm/dim")
