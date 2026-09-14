from pathlib import Path
ab = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = ab.read_text(encoding="utf-8")
# verify T1
print("T1:", "KitParque.Y_CALCAMENTO + DEITADO_ALTURA" in t)
# Force dark night fog at start of _plano_da_praca
needle = "func _plano_da_praca(pose: Dictionary) -> void:\n\tvar onde: Vector3 = pose[\"onde\"]\n\tvar figura := _jogador.figura()\n"
insert = """func _plano_da_praca(pose: Dictionary) -> void:\n\tvar onde: Vector3 = pose[\"onde\"]\n\tvar figura := _jogador.figura()\n\t# Noite da Matriz: sem wash do fog_denso (cinza claro). Luz = postes.\n\tvar fog := _cena.get_node_or_null(\"Ambiente\") as FogController\n\tif fog != null:\n\t\tfog.forcar(\"res://resources/fog/fog_praca_noite.tres\")\n"""
if "fog_praca_noite" not in t:
    if needle not in t:
        print("MISS plano needle")
    else:
        t = t.replace(needle, insert, 1)
        print("fog force OK")
else:
    print("fog already")
# Push praca_1 look deeper toward farther church
old_l1 = "\tvar l1 := Vector3(torso.x + 0.2, onde.y + 2.4, torso.z - 5.5)"
new_l1 = "\tvar l1 := Vector3(torso.x + 0.2, onde.y + 2.8, torso.z - 12.0)"
old_c1 = "\tvar c1 := Vector3(torso.x - 1.4, onde.y + 3.6, torso.z + 2.6)"
new_c1 = "\tvar c1 := Vector3(torso.x - 1.8, onde.y + 4.2, torso.z + 4.0)"
if old_l1 in t:
    t = t.replace(old_l1, new_l1, 1); print("l1 OK")
else:
    print("MISS l1")
if old_c1 in t:
    t = t.replace(old_c1, new_c1, 1); print("c1 OK")
else:
    print("MISS c1")
# praca_5 establishing - find and push look north if present
ab.write_text(t, encoding="utf-8")
print("written")
