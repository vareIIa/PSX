from pathlib import Path
ab = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = ab.read_text(encoding="utf-8")
old = 'fog.forcar("res://resources/fog/fog_praca_noite.tres")'
new = 'fog.forcar("res://resources/fog/fog_noite_nublada.tres")'
# also use group fallback
old_block = """\tvar fog := _cena.get_node_or_null(\"Ambiente\") as FogController\n\tif fog != null:\n\t\tfog.forcar(\"res://resources/fog/fog_noite_nublada.tres\")\n"""
# replace path first
if old in t:
    t = t.replace(old, new)
    print("path -> noite_nublada")
elif new in t:
    print("already noite_nublada")
else:
    print("MISS forcar line")
# strengthen lookup
old2 = """\tvar fog := _cena.get_node_or_null(\"Ambiente\") as FogController\n\tif fog != null:\n\t\tfog.forcar(\"res://resources/fog/fog_noite_nublada.tres\")\n"""
new2 = """\tvar fog := _cena.get_node_or_null(\"Ambiente\") as FogController\n\tif fog == null:\n\t\tfog = _cena.get_tree().get_first_node_in_group(&\"fog_controller\") as FogController\n\tif fog != null:\n\t\tfog.forcar(\"res://resources/fog/fog_noite_nublada.tres\")\n\t\tprint(\"[abertura] fog Matriz -> noite_nublada\")\n"""
if old2 in t:
    t = t.replace(old2, new2)
    print("lookup strengthened")
else:
    print("MISS block", "noite_nublada" in t)
ab.write_text(t, encoding="utf-8")
