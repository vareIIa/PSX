from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\kit_parque.gd")
t = p.read_text(encoding="utf-8")
old = 'var reboco := Color("ece6d6")'
new = 'var reboco := Color("f4eee0")'
# only first occurrence is inside igreja_matriz (casa uses d8d0c2)
if old not in t:
    raise SystemExit("reboco color missing")
t = t.replace(old, new, 1)
needle = """\t# Saia de weathering na base da fachada (mancha ancora o volume).
\tKitModular.caixa_cor(sup, &\"tijolo\",
\t\tcentro + frente * (fundura * 0.5 + 0.02) + Vector3(0.0, 0.45, 0.0),
\t\tVector3(largura * 0.98, 0.9, 0.16), mancha, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)"""
insert = needle + """
\t# Placa frontal mais clara: no denso o volume reboco puro lava; esta face
\t# empurrada 6 cm da nave sobra como branco colonial sem emissivo.
\tKitModular.caixa_cor(sup, &\"reboco\",
\t\tcentro + frente * (fundura * 0.5 + 0.06) + Vector3(0.0, parede_h * 0.52, 0.0),
\t\tVector3(largura * 0.92, parede_h * 0.88, 0.12), Color(\"fff8ea\"), giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)"""
if "fff8ea" not in t:
    if needle not in t:
        raise SystemExit("weathering block not found")
    t = t.replace(needle, insert, 1)
p.write_text(t, encoding="utf-8", newline="\n")
print("kit_parque brightened ok")
