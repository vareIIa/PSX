from pathlib import Path
# Darken clay a touch so TP rear fill doesn't bleach to tan
p = Path(r"game\src\world\kit_estrada.gd")
t = p.read_text(encoding="utf-8")
t2 = t.replace(
"const COR_TRILHA := Color(1.12, 0.72, 0.52)\nconst COR_MEIO := Color(0.78, 0.36, 0.24)\nconst COR_BEIRA := Color(0.62, 0.28, 0.18)\nconst COR_FOLHICO := Color(0.48, 0.36, 0.22)",
"const COR_TRILHA := Color(0.98, 0.55, 0.38)\nconst COR_MEIO := Color(0.72, 0.30, 0.18)\nconst COR_BEIRA := Color(0.55, 0.24, 0.14)\nconst COR_FOLHICO := Color(0.42, 0.32, 0.18)",
)
# Near-car roadside brush: also plant denser band just outside MEIA_PISTA each step
if "const COR_TRILHA := Color(0.98" not in t2:
    print("color replace failed")
else:
    p.write_text(t2, encoding="utf-8"); print("clay darkened")
