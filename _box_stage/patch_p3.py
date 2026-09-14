from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
text = p.read_text(encoding="utf-8")
old = '''\t# praca_3 — perfil leste afastado: le deitado sem close; praca/cidade a W.
\tawait Cinema.corte(0.1)
\tvar c3 := Vector3(torso.x + 8.5, onde.y + 3.6, torso.z + 4.0)
\tvar l3 := Vector3(torso.x - 1.5, onde.y + 1.4, torso.z - 3.5)
\tCinema.enquadrar(c3, l3, 58.0)
'''
new = '''\t# praca_3 — SE elevado (nao puro leste: 8,5 m leste caiu fora do streaming
\t# e deu frame preto). Ainda perfil/obliquo, corpo pequeno, eixo pra igreja.
\tawait Cinema.corte(0.1)
\tvar c3 := Vector3(torso.x + 5.5, onde.y + 3.8, torso.z + 6.0)
\tvar l3 := Vector3(torso.x - 0.4, onde.y + 1.6, torso.z - 7.0)
\tCinema.enquadrar(c3, l3, 58.0)
'''
if old not in text:
    raise SystemExit("block not found")
p.write_text(text.replace(old, new, 1), encoding="utf-8")
print("P3_FIXED")
