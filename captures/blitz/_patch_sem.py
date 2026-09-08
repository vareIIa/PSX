from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\chunk_builder.gd")
text = p.read_text(encoding="utf-8")
old = """	var ox := _recuo_esquina(Vias.meia_x(cx), MalhaUrbana.via_x(cx))
	var oz := _recuo_esquina(Vias.meia_z(cz), MalhaUrbana.via_z(cz))
	var y := KitModular.ALTURA_MEIO_FIO"""
new = """	var ox := _recuo_esquina(MalhaUrbana.meia_asfalto(MalhaUrbana.via_x(cx)), MalhaUrbana.via_x(cx))
	var oz := _recuo_esquina(MalhaUrbana.meia_asfalto(MalhaUrbana.via_z(cz)), MalhaUrbana.via_z(cz))
	var y := KitModular.ALTURA_MEIO_FIO"""
# may appear once in _semaforos; perto already patched
count = text.count(old)
print("matches", count)
if count >= 1:
    text = text.replace(old, new)  # all remaining
    p.write_text(text, encoding="utf-8")
    print("patched semaforos/others")
else:
    # try find remaining Vias.meia
    import re
    for m in re.finditer(r'Vias\.meia_[xz].*', text):
        print("still:", m.group())
