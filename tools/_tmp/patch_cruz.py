from pathlib import Path
kp = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\kit_parque.gd")
t = kp.read_text(encoding="utf-8")
old = """\tvar cruz_c := centro + frente * (fundura * 0.08) + Vector3(0.0, parede_h + 1.75, 0.0)
\tKitModular.caixa_cor(sup, &\"metal\",
\t\tcruz_c, Vector3(0.22, 1.45, 0.22), trim, giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
\tKitModular.caixa_cor(sup, &\"metal\",
\t\tcruz_c + Vector3(0.0, 0.35, 0.0), Vector3(1.0, 0.2, 0.2), trim, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
"""
new = """\tvar cruz_c := centro + frente * (fundura * 0.12) + Vector3(0.0, parede_h + 1.95, 0.0)
\tKitModular.caixa_cor(sup, &\"metal\",
\t\tcruz_c, Vector3(0.28, 1.7, 0.28), trim, giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
\tKitModular.caixa_cor(sup, &\"metal\",
\t\tcruz_c + Vector3(0.0, 0.4, 0.0), Vector3(1.25, 0.26, 0.26), trim, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
"""
nl = "\r\n" if "\r\n" in t else "\n"
old = old.replace("\n", nl)
new = new.replace("\n", nl)
if old not in t:
    raise SystemExit("cruz block not found")
kp.write_bytes(t.replace(old, new, 1).encode("utf-8"))
print("cross enlarged for distance")
