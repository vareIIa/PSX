from pathlib import Path
p = Path("game/src/world/estrada_builder.gd")
t = p.read_text(encoding="utf-8")
needle = "var semente: int = 20260908"
if "clima_id" not in t:
    if needle not in t:
        raise SystemExit("semente not found")
    t = t.replace(needle, needle + "\n## Clima ativo da cena (noite/amanhecer/dia/entardecer). Afeta olhos e props.\nvar clima_id: String = \"entardecer\"", 1)
    p.write_text(t, encoding="utf-8", newline="\n")
    print("added clima_id")
else:
    print("clima_id already present")
