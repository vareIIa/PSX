# -*- coding: utf-8 -*-
from pathlib import Path

ab = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
co = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\render\corpo.gd")
t = ab.read_text(encoding="utf-8")

old = """\t\tcam_de = p_cabeca - frente_praca * 0.50 + Vector3.UP * 0.20
\t\t# Mira as botas; praca (coreto/igreja) logo alem.
\t\tolhar_de = p_pes + frente_praca * 0.70 + Vector3.UP * 0.05"""
new = """\t\t# Mais atras/alto: ve o comprimento da calca ate a bota (nao colado no cubo).
\t\tcam_de = p_cabeca - frente_praca * 0.75 + Vector3.UP * 0.28
\t\t# Mira o CHAO entre as botas, horizontal — evita olhar pra cima no teto do coreto.
\t\tolhar_de = Vector3(p_pes.x, onde.y + 0.06, p_pes.z) + frente_praca * 0.90"""
if old not in t:
    raise SystemExit("cam tweak missing")
t = t.replace(old, new, 1)

# look-at less aggressive (coreto mid not through church under roof)
old2 = """\tvar alvo_look := Vector3(272.0, 0.0, -66.0)"""
new2 = """\tvar alvo_look := Vector3(272.0, 0.0, -52.0)"""
if old2 not in t:
    raise SystemExit("alvo_look missing")
t = t.replace(old2, new2, 1)

# olhar_ate also lower
old3 = """\tvar olhar_ate := onde + frente_praca * ACORDA_OLHAR_LONGE + Vector3.UP * ACORDA_OLHAR_ALTURA.y"""
new3 = """\tvar olhar_ate := onde + frente_praca * ACORDA_OLHAR_LONGE + Vector3.UP * 1.05"""
if old3 not in t:
    raise SystemExit("olhar_ate missing")
t = t.replace(old3, new3, 1)

ab.write_text(t, encoding="utf-8")
print("abertura cam OK")

c = co.read_text(encoding="utf-8")
oldp = """func _pose_deitado_acordar() -> void:
\t_girar(Osso.COXA_E, -0.55, 0.0, 0.08)
\t_girar(Osso.CANELA_E, 0.95)
\t_girar(Osso.COXA_D, -0.48, 0.0, -0.08)
\t_girar(Osso.CANELA_D, 0.88)
\t_girar(Osso.TORSO, 0.12)
\t_girar(Osso.BRACO_E, 0.25, 0.0, 0.35)
\t_girar(Osso.ANTEBRACO_E, 0.40)
\t_girar(Osso.BRACO_D, 0.25, 0.0, -0.35)
\t_girar(Osso.ANTEBRACO_D, 0.40)"""
newp = """func _pose_deitado_acordar() -> void:
\t# Joelhos bem dobrados: coxa+canela+bota separam no FP (ref 01).
\t_girar(Osso.COXA_E, -0.95, 0.0, 0.12)
\t_girar(Osso.CANELA_E, 1.45)
\t_girar(Osso.COXA_D, -0.85, 0.0, -0.12)
\t_girar(Osso.CANELA_D, 1.35)
\t_girar(Osso.TORSO, 0.18)
\t_girar(Osso.BRACO_E, 0.35, 0.0, 0.45)
\t_girar(Osso.ANTEBRACO_E, 0.55)
\t_girar(Osso.BRACO_D, 0.35, 0.0, -0.45)
\t_girar(Osso.ANTEBRACO_D, 0.55)"""
if oldp not in c:
    raise SystemExit("pose fn missing")
c = c.replace(oldp, newp, 1)
co.write_text(c, encoding="utf-8")
print("corpo knees OK")
