from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")

# capture gate
if 'args.has("--ver-praca")' not in t:
    old = 'if not OS.get_cmdline_user_args().has("--ver-abertura"):\n\t\treturn'
    new = 'var args := OS.get_cmdline_user_args()\n\tif not (args.has("--ver-abertura") or args.has("--ver-praca")):\n\t\treturn'
    if old not in t:
        raise SystemExit("cap gate not found")
    t = t.replace(old, new, 1)
    print("cap gate ok")
else:
    print("cap gate already ok")

# quit gate — find by unique substring
marker = 'roteiro completo'
i = t.find(marker)
if i < 0:
    raise SystemExit("quit marker missing")
# find start of the if line
line_start = t.rfind('\n', 0, i) + 1
# find end of quit block (get_tree().quit())
q = t.find('get_tree().quit()', i)
if q < 0:
    raise SystemExit("quit call missing")
line_end = t.find('\n', q)
block = t[line_start:line_end]
print("OLD BLOCK:", repr(block))
new_block = (
    'if OS.get_cmdline_user_args().has("--ver-abertura") or OS.get_cmdline_user_args().has("--ver-praca"):\n'
    '\t\tprint("[abertura] roteiro completo - encerrando captura")\n'
    '\t\tawait get_tree().create_timer(0.4).timeout\n'
    '\t\tget_tree().quit()'
)
t = t[:line_start] + new_block + t[line_end:]
p.write_text(t, encoding="utf-8")
print("quit gate ok")
