from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")
bad = '''\tawait _capturar_plano("01_acordar_chao")
\tif OS.get_cmdline_user_args().has("--ver-praca"):
\t\tawait get_tree().create_timer(120.0).timeout
\t\treturn
\tawait get_tree().create_timer(ACORDA_ANTES).timeout'''
good = '''\tawait _capturar_plano("01_acordar_chao")
\tawait get_tree().create_timer(ACORDA_ANTES).timeout'''
if bad not in t:
    raise SystemExit("120s hold not found")
t = t.replace(bad, good, 1)
p.write_text(t, encoding="utf-8")
print("removed 120s hold")
