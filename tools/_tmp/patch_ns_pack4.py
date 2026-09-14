from pathlib import Path
import re
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
"##   coreto = centro + (0, +5.5) -> ~ (271, -44.75)  // ~4.8 m do pin (fora do raio 3.8)",
"##   igreja = centro + (0, -3.0) -> ~ (271, -53.25)  // fachada sul ~9.0 m do pin",
"##   folga centros 8.5 m; fachada giro 0 (+Z). Lateral/lanternas no centro geometrico.",
"static func _praca_matriz(sup: Dictionary, props: Array[Dictionary],",
"\t\tcolisao: Array[Dictionary], plano: Dictionary, desloc: Vector2) -> void:",
"\tvar centro_q: Vector2 = plano[\"centro\"]",
"\tvar sem := int(plano[\"semente\"])",
"\tvar y := KitParque.Y_CALCAMENTO",
"\tvar praca := Rect2(centro_q.x - 18.0, centro_q.y - 16.0, 36.0, 34.0)",
"",
"\tvar coreto_p := Vector2(centro_q.x, centro_q.y + 5.5) + desloc",
"\tif _neste_chunk(coreto_p):",
"\t\tKitParque.coreto(sup, colisao, Vector3(coreto_p.x, y, coreto_p.y), 3.8)",
"",
"\tvar igreja := Vector2(centro_q.x, centro_q.y - 3.0) + desloc",
"\tif _neste_chunk(igreja):",
"\t\tKitParque.igreja_matriz(sup, colisao,",
"\t\t\tVector3(igreja.x, y, igreja.y), 0.0)",
"\tprint(\"[praca_matriz] centro_q=\", centro_q, \" coreto=\", coreto_p, \" igreja=\", igreja)",
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
"\t# Zona do coreto (+5.5) + igreja (-3.0) sem banco/poste em cima.",
"\tvar proibido: Array[Rect2] = [",
"\t\tRect2(centro.x - 5.5, centro.y + 5.5 - 5.5, 11.0, 11.0),",
"\t\tRect2(centro.x - 8.0, centro.y - 3.0 - 5.0, 16.0, 12.0),",
"\t]",
])
m = pat.search(text2)
if not m:
    raise SystemExit("proibido not found")
text2 = text2[:m.start()] + new_mob + text2[m.end():]
pb.write_bytes(text2.encode("utf-8"))
print("OK aggressive pack +5.5 / -3.0")
