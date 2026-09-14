from pathlib import Path
p = Path(r"game/src/world/estrada_builder.gd")
t = p.read_text(encoding="utf-8")
if "clima_id" not in t:
    t = t.replace("var semente: int = 20260908\n",
                  "var semente: int = 20260908\n## Clima ativo da cena (noite/amanhecer/dia/entardecer).\nvar clima_id: String = \"entardecer\"\n", 1)
    p.write_text(t, encoding="utf-8")
    print("estrada_builder clima_id added")
else:
    print("estrada_builder already has clima_id")
