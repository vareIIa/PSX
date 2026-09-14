from pathlib import Path
import re

# 1) builder: on-axis again, church on measured pack; pass y raised via KitParque call
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
"## Packing N-S p/ pin 270/-40 fog_denso. Centro mundo ~ (271, -50.25).",
"##   coreto = centro + (0, +4.0) -> ~ (271, -46.25) // ~6.3 m do pin",
"##   igreja = centro + (0, -4.5) -> ~ (271, -54.75) // fachada ~10.5 m",
"##   Igreja sobe 1.2 m no plinto (kit) p/ porta/quoins limparem o telhado do coreto.",
"##   giro 0 (+Z). Lateral/lanternas no centro geometrico.",
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
    raise SystemExit("proibido missing")
pb.write_bytes((text2[:m.start()] + new_mob + text2[m.end():]).encode("utf-8"))
print("builder on-axis restored")

# 2) kit: raise church on plinth + boost facade contrast
kp = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\kit_parque.gd")
kt = kp.read_text(encoding="utf-8")
nlk = "\r\n" if "\r\n" in kt else "\n"
# Insert plinth elevation at start of igreja_matriz body after color vars
marker = "\tvar largura := 11.0" + nlk + "\tvar fundura := 8.4" + nlk + "\tvar parede_h := 5.4" + nlk
if marker not in kt:
    raise SystemExit("igreja size marker missing")
elev = (
    "\tvar largura := 11.0" + nlk
    + "\tvar fundura := 8.4" + nlk
    + "\tvar parede_h := 5.4" + nlk
    + "\t# Plinto eleva a fachada acima do telhado do coreto no eixo Cine2." + nlk
    + "\tconst PLINTO := 1.35" + nlk
    + "\tKitModular.caixa_cor(sup, &\"concreto_sujo\"," + nlk
    + "\t\tcentro + Vector3(0.0, PLINTO * 0.5, 0.0)," + nlk
    + "\t\tVector3(largura + 1.2, PLINTO, fundura + 1.0), Color(\"6a6458\"), giro," + nlk
    + "\t\tPSXMesh.FACE_TODAS, 2.0)" + nlk
    + "\tcentro += Vector3(0.0, PLINTO, 0.0)" + nlk
)
if "const PLINTO" in kt:
    print("plinto already present")
else:
    kt = kt.replace(marker, elev, 1)
    kp.write_bytes(kt.encode("utf-8"))
    print("plinto + elev applied")
