from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")
old = 'if not OS.get_cmdline_user_args().has("--ver-abertura"):\n\t\treturn'
new = 'var args := OS.get_cmdline_user_args()\n\tif not (args.has("--ver-abertura") or args.has("--ver-praca")):\n\t\treturn'
if old not in t:
    raise SystemExit("cap gate not found")
t = t.replace(old, new, 1)
# Also quit after full script when --ver-praca
old_q = 'if OS.get_cmdline_user_args().has("--ver-abertura"):\n\t\tprint("[abertura] roteiro completo - encerrando captura")'
new_q = 'if OS.get_cmdline_user_args().has("--ver-abertura") or OS.get_cmdline_user_args().has("--ver-praca"):\n\t\tprint("[abertura] roteiro completo - encerrando captura")'
if old_q not in t:
    raise SystemExit("quit gate not found")
t = t.replace(old_q, new_q, 1)
p.write_text(t, encoding="utf-8")
print("OK ver-praca gates")
