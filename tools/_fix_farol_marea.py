from pathlib import Path

cena = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\carro_cena.gd")
t = cena.read_text(encoding="utf-8")
old = "\t_farol.position = Vector3(0.0, 0.62, -comp * 0.5 + 0.1)\n\t_farol.rotation.x = deg_to_rad(-9.0)\n\t_farol.spot_range = 34.0\n\t_farol.spot_angle = 42.0\n\t_farol.spot_angle_attenuation = 0.85\n\t_farol.light_energy = 6.2"
new = "\t# Z negativo alem do nariz: Marea e mais longo; farol enterrado no casco\n\t# apaga o facho no FP/TP (proporcao WIP Renato).\n\t_farol.position = Vector3(0.0, 0.78, -comp * 0.5 - 0.45)\n\t_farol.rotation.x = deg_to_rad(-8.0)\n\t_farol.spot_range = 38.0\n\t_farol.spot_angle = 46.0\n\t_farol.spot_angle_attenuation = 0.8\n\t_farol.light_energy = 8.0"
assert old in t, "farol block missing"
cena.write_text(t.replace(old, new), encoding="utf-8")
print("carro_cena farol OK")

ab = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura_estrada.gd")
a = ab.read_text(encoding="utf-8")
old2 = "\tif _clima_id() == \"noite\":\n\t\t_estrada.spawn_olhos_nevoa(_carro.distancia, 24.0)\n\t\t_estrada.garantir_props_facho(_carro.distancia)"
new2 = "\tif _clima_id() == \"noite\":\n\t\t_ligar_farois_se_noite()\n\t\t_estrada.spawn_olhos_nevoa(_carro.distancia, 24.0)\n\t\t_estrada.garantir_props_facho(_carro.distancia)"
assert old2 in a, "segurar noite block missing"
ab.write_text(a.replace(old2, new2), encoding="utf-8")
print("abertura re-assert farois OK")
print("MODELO still MAREA", "Modelo.MAREA" in cena.read_text(encoding="utf-8"))
