from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")
old = "\tawait _plano_da_praca(pose)\n\tawait _plano_da_avenida(pose)"
new = """\tawait _plano_da_praca(pose)
\t# Captura AAA da praca: nao precisa do resto do roteiro.
\tif OS.get_cmdline_user_args().has(\"--ver-praca\"):
\t\tprint(\"[abertura] praca capturada - encerrando\")
\t\tawait get_tree().create_timer(0.35).timeout
\t\tget_tree().quit()
\t\treturn
\tawait _plano_da_avenida(pose)"""
new = new.replace('\\"', '"')
if old not in t:
    raise SystemExit("executar hook not found")
t = t.replace(old, new, 1)
p.write_text(t, encoding="utf-8")
print("early quit ok")
