from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")
broken = '''\tif OS.get_cmdline_user_args().has("--ver-abertura"):
if OS.get_cmdline_user_args().has("--ver-abertura") or OS.get_cmdline_user_args().has("--ver-praca"):
\t\tprint("[abertura] roteiro completo - encerrando captura")
\t\tawait get_tree().create_timer(0.4).timeout
\t\tget_tree().quit()'''
fixed = '''\tif OS.get_cmdline_user_args().has("--ver-abertura") or OS.get_cmdline_user_args().has("--ver-praca"):
\t\tprint("[abertura] roteiro completo - encerrando captura")
\t\tawait get_tree().create_timer(0.4).timeout
\t\tget_tree().quit()'''
if broken not in t:
    raise SystemExit("broken block not found exactly")
t = t.replace(broken, fixed, 1)
p.write_text(t, encoding="utf-8")
print("fixed quit")
