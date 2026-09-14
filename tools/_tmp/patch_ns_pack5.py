from pathlib import Path
import re

# --- parque_builder pack ---
pb = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\parque_builder.gd")
text = pb.read_text(encoding="utf-8")
nl = "\r\n" if "\r\n" in text else "\n"

def L(lines):
    return nl.join(lines) + nl

start = text.find("## Layout da Praca da Matriz:")
end = text.find("## Bancos e lanternas pretas")
new_fn = L([
"## Layout da Praca da Matriz: igreja ao norte, coreto no miolo, casas nas laterais.",
"##",
"## Packing N-S p/ pin 270/-40 fog_denso. Centro mundo medido ~ (271, -50.25).",
"##   coreto = centro + (0, +4.0) -> ~ (271, -46.25)  // ~6.3 m do pin (fora beiral/escada)",
"##   igreja = centro + (0, -4.5) -> ~ (271, -54.75)  // fachada sul ~10.5 m do pin",
"##   folga 8.5 m; giro 0 (+Z). Lateral/lanternas no centro geometrico.",
"##   coreto raio 3.4 + portal sul aberto (kit) p/ porta/quoins lerem no eixo.",
"static func _praca_matriz(sup: Dictionary, props: Array[Dictionary],",
"\t\tcolisao: Array[Dictionary], plano: Dictionary, desloc: Vector2) -> void:",
"\tvar centro_q: Vector2 = plano[\"centro\"]",
"\tvar sem := int(plano[\"semente\"])",
"\tvar y := KitParque.Y_CALCAMENTO",
"\tvar praca := Rect2(centro_q.x - 18.0, centro_q.y - 16.0, 36.0, 34.0)",
"",
"\tvar coreto_p := Vector2(centro_q.x, centro_q.y + 4.0) + desloc",
"\tif _neste_chunk(coreto_p):",
"\t\tKitParque.coreto(sup, colisao, Vector3(coreto_p.x, y, coreto_p.y), 3.4)",
"",
"\tvar igreja := Vector2(centro_q.x, centro_q.y - 4.5) + desloc",
"\tif _neste_chunk(igreja):",
"\t\tKitParque.igreja_matriz(sup, colisao,",
"\t\t\tVector3(igreja.x, y, igreja.y), 0.0)",
"",
"\tvar n_casas := 3",
"\tfor lado_s: float in [-1.0, 1.0]:",
"\t\tfor i in n_casas:",
"\t\t\tvar tt := (float(i) + 0.5) / float(n_casas)",
"\t\t\tvar x := praca.position.x + 3.6 if lado_s < 0.0 else praca.end.x - 3.6",
"\t\t\tvar z := lerpf(centro_q.y - 6.0, centro_q.y + 16.0, tt)",
"\t\t\tvar p := Vector2(x, z) + desloc",
"\t\t\tif not _neste_chunk(p):",
"\t\t\t\tcontinue",
"\t\t\tvar giro := PI * 0.5 if lado_s < 0.0 else -PI * 0.5",
"\t\t\tKitParque.casa_colonial_baixa(sup, colisao,",
"\t\t\t\tVector3(p.x, y, p.y), giro, lerpf(6.8, 8.0, _ale(sem, i, 101)))",
"",
""
])
text2 = text[:start] + new_fn + text[end:]
pat = re.compile(
    r"\t# Zona do coreto.*?\n\tvar proibido: Array\[Rect2\] = \[\n(?:\t\tRect2\([^\n]+\),\n){2}\t\]\r?\n",
    re.S,
)
new_mob = L([
"\t# Zona do coreto (+4) + igreja (-4.5) sem banco/poste em cima.",
"\tvar proibido: Array[Rect2] = [",
"\t\tRect2(centro.x - 5.5, centro.y + 4.0 - 5.5, 11.0, 11.0),",
"\t\tRect2(centro.x - 8.0, centro.y - 4.5 - 5.0, 16.0, 12.0),",
"\t]",
])
m = pat.search(text2)
if not m:
    raise SystemExit("proibido not found")
pb.write_bytes((text2[:m.start()] + new_mob + text2[m.end():]).encode("utf-8"))
print("builder OK")

# --- kit_parque: open south portal (skip railings facing +Z) ---
kp = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\kit_parque.gd")
kt = kp.read_text(encoding="utf-8")
# Find the railing loop and skip south-facing segment
old = """\t# Oito pilares e o guarda-corpo entre eles.
\tvar alt_pilar := 2.35
\tfor i in 8:
\t\tvar ang := TAU * float(i) / 8.0
\t\tvar p := centro + Vector3(cos(ang), 0.0, sin(ang)) * (raio * 0.82)
\t\tKitModular.caixa_cor(sup, &\"tabua\",
\t\t\tp + Vector3(0.0, y_piso + alt_pilar * 0.5, 0.0),
\t\t\tVector3(0.16, alt_pilar, 0.16), madeira, ang,
\t\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\t\tvar ang2 := TAU * float(i + 1) / 8.0
\t\tvar a := centro + Vector3(cos(ang), 0.0, sin(ang)) * (raio * 0.82)
\t\tvar b := centro + Vector3(cos(ang2), 0.0, sin(ang2)) * (raio * 0.82)
\t\tvar meio := (a + b) * 0.5
\t\tvar comp := a.distance_to(b)
\t\tvar giro := atan2(b.x - a.x, b.z - a.z)
\t\tKitModular.caixa_cor(sup, &\"tabua\",
\t\t\tmeio + Vector3(0.0, y_piso + 1.05, 0.0),
\t\t\tVector3(0.07, 0.08, comp), madeira, giro,
\t\t\tPSXMesh.FACE_TODAS, 8.0)
\t\tKitModular.caixa_cor(sup, &\"tabua\",
\t\t\tmeio + Vector3(0.0, y_piso + 0.55, 0.0),
\t\t\tVector3(0.05, 0.05, comp), madeira, giro,
\t\t\tPSXMesh.FACE_TODAS, 8.0)
"""
new = """\t# Oito pilares; guarda-corpo pula o vao sul (+Z) — portal pro eixo da igreja.
\tvar alt_pilar := 2.35
\tfor i in 8:
\t\tvar ang := TAU * float(i) / 8.0
\t\tvar p := centro + Vector3(cos(ang), 0.0, sin(ang)) * (raio * 0.82)
\t\tKitModular.caixa_cor(sup, &\"tabua\",
\t\t\tp + Vector3(0.0, y_piso + alt_pilar * 0.5, 0.0),
\t\t\tVector3(0.16, alt_pilar, 0.16), madeira, ang,
\t\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\t\tvar ang2 := TAU * float(i + 1) / 8.0
\t\t# Segmento que olha pro sul (escada / pin Cine2): sem grade.
\t\tvar mid_ang := ang + (ang2 - ang) * 0.5
\t\tif sin(mid_ang) > 0.55:
\t\t\tcontinue
\t\tvar a := centro + Vector3(cos(ang), 0.0, sin(ang)) * (raio * 0.82)
\t\tvar b := centro + Vector3(cos(ang2), 0.0, sin(ang2)) * (raio * 0.82)
\t\tvar meio := (a + b) * 0.5
\t\tvar comp := a.distance_to(b)
\t\tvar giro := atan2(b.x - a.x, b.z - a.z)
\t\tKitModular.caixa_cor(sup, &\"tabua\",
\t\t\tmeio + Vector3(0.0, y_piso + 1.05, 0.0),
\t\t\tVector3(0.07, 0.08, comp), madeira, giro,
\t\t\tPSXMesh.FACE_TODAS, 8.0)
\t\tKitModular.caixa_cor(sup, &\"tabua\",
\t\t\tmeio + Vector3(0.0, y_piso + 0.55, 0.0),
\t\t\tVector3(0.05, 0.05, comp), madeira, giro,
\t\t\tPSXMesh.FACE_TODAS, 8.0)
"""
nlk = "\r\n" if "\r\n" in kt else "\n"
old = old.replace("\n", nlk)
new = new.replace("\n", nlk)
if old not in kt:
    raise SystemExit("coreto railing block not found")
kp.write_bytes(kt.replace(old, new, 1).encode("utf-8"))
print("kit coreto south portal OK")
