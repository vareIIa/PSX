from pathlib import Path
p = Path(r"game\src\levels\abertura_estrada.gd")
text = p.read_text(encoding="utf-8")
old = "\tawait Cinema.clarear(0.35)\n\tawait get_tree().create_timer(120.0).timeout"
new = "\tawait Cinema.clarear(0.35)\n\t# TEMP proof falas — revert after shot\n\tCinema.legenda(FALAS[\"dentro_1\"], 4.0)\n\tawait get_tree().create_timer(120.0).timeout"
if old not in text:
    raise SystemExit("anchor not found")
p.write_text(text.replace(old, new, 1), encoding="utf-8")
print("temp legenda injected")
