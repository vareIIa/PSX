from pathlib import Path
pb = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\parque_builder.gd")
text = pb.read_text(encoding="utf-8")
nl = "\r\n" if "\r\n" in text else "\n"
start = text.find("## Layout da Praca da Matriz:")
end = text.find("## Bancos e lanternas pretas")
if start < 0 or end < 0:
    raise SystemExit(f"markers missing start={start} end={end}")

def L(lines):
    return nl.join(lines) + nl

new_fn = L([
"## Layout da Praca da Matriz: igreja ao norte, coreto no centro, casas nas laterais.",
"##",
"## Packing N-S (Cine2 pin 270/-40, fog_denso ~18 m). Centro de quadra ~= (272, -48):",
"##   coreto  = centro           -> ~ (272, -48)   // ~8 m do pin (NAO empurrar pro sul)",
"##   igreja  = centro + (0,-7)  -> ~ (272, -55)   // ~15 m do pin; fachada sul ~11 m",
"##   fachada giro 0 (+Z/sul) pro pin; fundura 8.4 -> face = z_igreja+4.2",
"##   (antes: igreja em centro-9 com giro PI = traseira; silhueta na nevoa)",
"## Lateral (X +/-18, anel de lanternas em +/-7/+/-10) intacto.",
"static func _praca_matriz(sup: Dictionary, props: Array[Dictionary],",
"\t\tcolisao: Array[Dictionary], plano: Dictionary, desloc: Vector2) -> void:",
"\tvar centro_q: Vector2 = plano[\"centro\"]",
"\tvar centro: Vector2 = centro_q + desloc",
"\tvar sem := int(plano[\"semente\"])",
"\tvar y := KitParque.Y_CALCAMENTO",
"\tvar praca := Rect2(centro_q.x - 18.0, centro_q.y - 16.0, 36.0, 34.0)",
"",
"\t# Coreto no miolo geometrico — pin Cine2 fica ao sul, fora do raio.",
"\tif _neste_chunk(centro):",
"\t\tKitParque.coreto(sup, colisao, Vector3(centro.x, y, centro.y), 3.8)",
"",
"\t# Igreja 7 m ao norte do coreto (antes ~9 m). giro 0 = porta/quoins/cruz pro pin.",
"\tvar igreja := Vector2(centro_q.x, centro_q.y - 7.0) + desloc",
"\tif _neste_chunk(igreja):",
"\t\tKitParque.igreja_matriz(sup, colisao,",
"\t\t\tVector3(igreja.x, y, igreja.y), 0.0)",
"",
"\tvar n_casas := 3",
"\tfor lado_s: float in [-1.0, 1.0]:",
"\t\tfor i in n_casas:",
"\t\t\tvar tt := (float(i) + 0.5) / float(n_casas)",
"\t\t\tvar x := praca.position.x + 3.6 if lado_s < 0.0 else praca.end.x - 3.6",
"\t\t\tvar z := lerpf(praca.position.y + 10.0, praca.end.y - 3.0, tt)",
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
old_mob = L([
"\t# Zona do coreto (sul) + igreja (norte) sem banco/poste em cima.",
"\tvar proibido: Array[Rect2] = [",
"\t\tRect2(centro.x - 5.5, centro.y + 5.0 - 5.5, 11.0, 11.0),",
"\t\tRect2(centro.x - 8.0, centro.y - 5.0 - 6.0, 16.0, 12.0),",
"\t]",
])
new_mob = L([
"\t# Zona do coreto + igreja sem banco/poste em cima.",
"\tvar proibido: Array[Rect2] = [",
"\t\tRect2(centro.x - 5.5, centro.y - 5.5, 11.0, 11.0),",
"\t\tRect2(centro.x - 8.0, centro.y - 7.0 - 5.0, 16.0, 12.0),",
"\t]",
])
if old_mob not in text2:
    raise SystemExit("mobiliario block not found after fn replace")
text2 = text2.replace(old_mob, new_mob, 1)
pb.write_bytes(text2.encode("utf-8"))
v = pb.read_text(encoding="utf-8")
assert "centro_q.y - 7.0" in v
assert "centro_q.y + 5.0" not in v
assert "centro.y + 5.0 - 5.5" not in v
print("OK: coreto@centro, igreja centro-7, giro 0, proibido fixed")
