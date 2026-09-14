from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")
# drop unused meio_corpo
old = "\tvar igreja := Vector3(271.0, onde.y + 3.5, -51.0)\n\tvar meio_corpo := Vector3(onde.x, onde.y + 0.35, onde.z)\n"
new = "\tvar igreja := Vector3(271.0, onde.y + 3.5, -51.0)\n"
if old not in t:
    print("meio_corpo already gone or changed")
else:
    t = t.replace(old, new, 1)
    p.write_text(t, encoding="utf-8")
    print("removed meio_corpo")
plano = t.split("func _plano_da_praca")[1].split("func _linha_livre")[0]
print("levantar_call", "_levantar(figura" in plano)
print("montar_fp", "_montar_pernas_fp" in plano)
print("ceu", "01_acordar_ceu" in plano)
print("overhead", "02_deitado_igreja" in plano)
print("falas", "Ultima coisa que eu lembro" in t)
print("poste2", "Nao era pra eu ter pegado" in t)
print("dual02", 'begins_with("02_deitado")' in t)
print("av1", 'FALAS["avenida_1"], 3.8' in t)
print("av2", 'FALAS["avenida_2"], 3.8' in t)
print("p3", 'FALAS["poste_3"], 4.2' in t)
