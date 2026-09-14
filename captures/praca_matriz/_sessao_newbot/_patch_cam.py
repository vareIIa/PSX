from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")
# praca_1: pull look further toward church (more -Z) and higher so white facade fills mid frame
old = """\t# praca_1 - 3/4 SOUTH; corpo lower-third + portal+cruz acima do linteu (pos-punch).
\t# Cam puxada/olhar um pouco mais alto: cruz no plano do portal nao pode cortar na tarja.
\tvar c1 := Vector3(torso.x - 1.2, onde.y + 4.15, torso.z + 3.15)
\tvar l1 := Vector3(torso.x + 0.35, onde.y + 1.55, torso.z - 2.7)"""
new = """\t# praca_1 - 3/4 SOUTH; corpo lower-third + fachada branca (porta no muro, sem portal).
\t# Olhar mais fundo/-Z e mais alto: a igreja veio ~2 m pro pin; precisa caber torre+frontao.
\tvar c1 := Vector3(torso.x - 1.4, onde.y + 3.6, torso.z + 2.6)
\tvar l1 := Vector3(torso.x + 0.2, onde.y + 2.4, torso.z - 5.5)"""
if old not in t:
    raise SystemExit("praca_1 block missing")
t = t.replace(old, new, 1)
# praca_5 establishing similarly
old5 = """\t# praca_5 - establishing south mais largo; corpo lower-third + porta/torre peek.
\t# Look torso+N (eixo ~271,-51) sem absoluto que some o corpo no denso.
\tvar c5 := Vector3(torso.x - 1.5, onde.y + 4.8, torso.z + 4.0)
\tvar l5 := Vector3(torso.x + 0.5, onde.y + 1.2, torso.z - 3.5)"""
new5 = """\t# praca_5 - establishing south mais largo; corpo lower-third + fachada/torre.
\t# Look mais norte e alto pra ler nave+torre depois do nudge da igreja.
\tvar c5 := Vector3(torso.x - 1.8, onde.y + 4.4, torso.z + 3.4)
\tvar l5 := Vector3(torso.x + 0.3, onde.y + 2.2, torso.z - 6.0)"""
if old5 not in t:
    raise SystemExit("praca_5 block missing")
t = t.replace(old5, new5, 1)
p.write_text(t, encoding="utf-8", newline="\n")
print("abertura cams updated")
