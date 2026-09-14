from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\parque_builder.gd")
t = p.read_text(encoding="utf-8")
if t.startswith("\ufeff"):
    t = t[1:]
old_comment = """## Layout da Praca da Matriz: igreja ao norte, coreto a OESTE do eixo, casas laterais.
##
## Packing N-S p/ pin 270/-40 fog_denso. Centro mundo ~ (271, -50.25).
##   coreto = centro + (-7.0, +4.0) -> ~ (264, -46.25) // fora do eixo sul->igreja
##   igreja = centro + (0, -1.5) -> ~ (271, -51.75) // fachada ~7.5 m + portal +1.4 m
##   giro 0 (+Z, fachada sul pro pin). Lateral/lanternas no centro geometrico.
##   Coreto a oeste = a esquerda do wake-up FP (refs: ao lado, nao no meio)."""
new_comment = """## Layout da Praca da Matriz: igreja ao norte, coreto a OESTE do eixo, casas laterais.
##
## Packing N-S p/ pin 270/-40 fog_denso. Centro mundo ~ (271, -50.25).
##   coreto = centro + (-7.0, +4.0) -> ~ (264, -46.25) // fora do eixo sul->igreja
##   igreja = centro + (0, +0.8) -> ~ (271, -49.45) // fachada flush ~6 m do pin
##   (antes -1.5 + portal +1.4; sem portal a porta ficava a ~8 m e sumia no denso)
##   giro 0 (+Z, fachada sul pro pin). Lateral/lanternas no centro geometrico.
##   Coreto a oeste = a esquerda do wake-up FP (refs: ao lado, nao no meio)."""
if old_comment not in t:
    raise SystemExit("comment block not found")
t = t.replace(old_comment, new_comment)
a = "var igreja := Vector2(centro_q.x, centro_q.y - 1.5) + desloc"
b = "var igreja := Vector2(centro_q.x, centro_q.y + 0.8) + desloc"
if a not in t:
    raise SystemExit("igreja line missing")
t = t.replace(a, b, 1)
a2 = "Rect2(centro.x - 8.0, centro.y - 1.5 - 6.0, 16.0, 14.0),"
b2 = "Rect2(centro.x - 8.0, centro.y + 0.8 - 6.0, 16.0, 14.0),"
if a2 not in t:
    raise SystemExit("proibido missing")
t = t.replace(a2, b2, 1)
a3 = "var pd := Vector2(centro.x + 3.4 * sx, centro.y - 1.5 + 5.8)"
b3 = "var pd := Vector2(centro.x + 3.4 * sx, centro.y + 0.8 + 4.2)"
if a3 not in t:
    raise SystemExit("lantern line missing")
t = t.replace(a3, b3, 1)
old_e = '"cor": Color("ffe8b0"), "energia": 8.5, "alcance": 12.0,'
new_e = '"cor": Color("ffe8b0"), "energia": 10.5, "alcance": 14.0,'
if old_e not in t:
    raise SystemExit("energia line missing")
t = t.replace(old_e, new_e, 1)
p.write_text(t, encoding="utf-8", newline="\n")
print("parque_builder patched ok")
