# -*- coding: utf-8 -*-
"""Fachada punch fog=denso + harden PRACA flor suppress."""
from pathlib import Path

kit = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\kit_parque.gd")
pb = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\parque_builder.gd")
t = kit.read_text(encoding="utf-8")

# --- color / mass punch for fog=denso @ ~10m / 480x270 ---
old_block = '''\tvar reboco := Color("efe6d4")
\tvar mancha := Color("a89878")
\tvar quoin_a := Color("5a4a34")
\tvar quoin_b := Color("2e261c")
\tvar telha := Color("7a4e32")
\t# Contraste porta/ombreira pensado p/ fog=denso @ 480x270: folha quase preta,
\t# marco quase branco — a unica leitura que sobra depois do wash.
\tvar porta := Color("020806")
\tvar ombreira := Color("fffff2")
\tvar trim := Color("080806")'''

new_block = '''\tvar reboco := Color("d8d0b8")
\tvar mancha := Color("8a7a5a")
\tvar quoin_a := Color("3a2e20")
\tvar quoin_b := Color("100c08")
\tvar telha := Color("6a3e24")
\t# Contraste porta/ombreira p/ fog=denso @ ~10m / 480x270 (Cine2 deitado):
\t# parede um pouco mais escura pra o marco branco sobrar; folha preta pura;
\t# cruz CLARA (nao metal escuro) — o escuro some no wash, o claro nao.
\tvar porta := Color("000000")
\tvar ombreira := Color("ffffff")
\tvar trim := Color("000000")
\tvar cruz_clara := Color("fffff8")'''

assert old_block in t, "color block missing"
t = t.replace(old_block, new_block, 1)

# Quoins: bolder, prouder, more blocks
t = t.replace("\tvar n_quoin := 7\n", "\tvar n_quoin := 8\n", 1)
old_quoin = '''\t\t\tKitModular.caixa_cor(sup, &"tijolo",
\t\t\t\tcentro + lado * (largura * 0.48 * sx) + frente * (fundura * 0.5 + 0.08)
\t\t\t\t\t+ Vector3(0.0, yk, 0.0),
\t\t\t\tVector3(0.82, alt_q, 0.55), cor_q, giro,
\t\t\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)'''
new_quoin = '''\t\t\tKitModular.caixa_cor(sup, &"tijolo",
\t\t\t\tcentro + lado * (largura * 0.48 * sx) + frente * (fundura * 0.5 + 0.14)
\t\t\t\t\t+ Vector3(0.0, yk, 0.0),
\t\t\t\tVector3(1.15, alt_q, 0.78), cor_q, giro,
\t\t\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)'''
assert old_quoin in t, "quoin geo missing"
t = t.replace(old_quoin, new_quoin, 1)

# Cross: larger + bright (survives fog wash)
old_cruz = '''\tvar cruz_c := centro + frente * (fundura * 0.12) + Vector3(0.0, parede_h + 1.95, 0.0)
\tKitModular.caixa_cor(sup, &"metal",
\t\tcruz_c, Vector3(0.28, 1.7, 0.28), trim, giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
\tKitModular.caixa_cor(sup, &"metal",
\t\tcruz_c + Vector3(0.0, 0.4, 0.0), Vector3(1.25, 0.26, 0.26), trim, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)'''
new_cruz = '''\tvar cruz_c := centro + frente * (fundura * 0.22) + Vector3(0.0, parede_h + 2.35, 0.0)
\t# Cruz clara e grossa: no denso o metal escuro vira nevoa; o branco sobra.
\tKitModular.caixa_cor(sup, &"concreto_sujo",
\t\tcruz_c, Vector3(0.42, 2.35, 0.42), cruz_clara, giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
\tKitModular.caixa_cor(sup, &"concreto_sujo",
\t\tcruz_c + Vector3(0.0, 0.55, 0.0), Vector3(1.85, 0.38, 0.38), cruz_clara, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\t# Contorno escuro atras (1 px de leitura no 480 quando o claro lava).
\tKitModular.caixa_cor(sup, &"metal",
\t\tcruz_c + frente * -0.08, Vector3(0.5, 2.5, 0.2), trim, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)'''
assert old_cruz in t, "cruz block missing"
t = t.replace(old_cruz, new_cruz, 1)

# Door + ombreira: thicker frame, larger black leaf, prouder depth, jambs
old_porta = '''\tvar porta_c := centro + frente * (fundura * 0.5 + 0.08) + Vector3(0.0, 1.55, 0.0)
\t# Ombreira / marco — profundo e claro p/ sobrar no denso.
\tKitModular.caixa_cor(sup, &"concreto_sujo",
\t\tporta_c + Vector3(0.0, 0.05, 0.0), Vector3(2.55, 3.65, 0.36), ombreira, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\t# Folha da porta (quase preta contra o marco).
\tKitModular.caixa_cor(sup, &"porta", porta_c, Vector3(2.05, 3.3, 0.16), porta, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\t# Arco: tres degraus acima da porta + chave.
\tKitModular.caixa_cor(sup, &"porta",
\t\tporta_c + Vector3(0.0, 1.55, 0.02), Vector3(1.75, 0.55, 0.12), porta, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\tKitModular.caixa_cor(sup, &"concreto_sujo",
\t\tporta_c + Vector3(0.0, 1.85, 0.04), Vector3(1.95, 0.35, 0.18), ombreira, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\tKitModular.caixa_cor(sup, &"concreto_sujo",
\t\tporta_c + Vector3(0.0, 2.12, 0.04), Vector3(1.45, 0.28, 0.18), ombreira, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\tKitModular.caixa_cor(sup, &"concreto_sujo",
\t\tporta_c + Vector3(0.0, 2.32, 0.04), Vector3(0.85, 0.22, 0.18), ombreira, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\t# Travessa / ferragem da porta (leitura de porta dupla).
\tKitModular.caixa_cor(sup, &"metal",
\t\tporta_c + Vector3(0.0, 0.0, 0.08), Vector3(0.08, 2.9, 0.06), trim, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)'''

new_porta = '''\tvar porta_c := centro + frente * (fundura * 0.5 + 0.14) + Vector3(0.0, 1.7, 0.0)
\t# Ombreira / marco — grosso, protruso e branco puro (borda que sobra no denso).
\tKitModular.caixa_cor(sup, &"concreto_sujo",
\t\tporta_c + Vector3(0.0, 0.08, 0.0), Vector3(3.25, 4.15, 0.58), ombreira, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\t# Jambas laterais extras (pilastras) — espessura em X que o 480 resolve.
\tfor sx: float in [-1.0, 1.0]:
\t\tKitModular.caixa_cor(sup, &"concreto_sujo",
\t\t\tporta_c + lado * (1.45 * sx) + Vector3(0.0, 0.05, 0.0),
\t\t\tVector3(0.55, 4.0, 0.72), ombreira, giro,
\t\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\t# Folha da porta (preta pura, grande o bastante p/ varios pixels no 480).
\tKitModular.caixa_cor(sup, &"porta", porta_c, Vector3(2.45, 3.7, 0.22), porta, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\t# Arco em degraus: ombreira clara + interior preto.
\tKitModular.caixa_cor(sup, &"porta",
\t\tporta_c + Vector3(0.0, 1.75, 0.02), Vector3(2.2, 0.7, 0.16), porta, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\tKitModular.caixa_cor(sup, &"concreto_sujo",
\t\tporta_c + Vector3(0.0, 2.05, 0.08), Vector3(2.55, 0.48, 0.32), ombreira, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\tKitModular.caixa_cor(sup, &"concreto_sujo",
\t\tporta_c + Vector3(0.0, 2.38, 0.08), Vector3(1.95, 0.38, 0.32), ombreira, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\tKitModular.caixa_cor(sup, &"concreto_sujo",
\t\tporta_c + Vector3(0.0, 2.65, 0.08), Vector3(1.2, 0.3, 0.32), ombreira, giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\t# Travessa / ferragem da porta (leitura de porta dupla).
\tKitModular.caixa_cor(sup, &"metal",
\t\tporta_c + Vector3(0.0, 0.0, 0.12), Vector3(0.12, 3.4, 0.08), Color("1a1a18"), giro,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)'''

assert old_porta in t, "porta block missing"
t = t.replace(old_porta, new_porta, 1)

# Window surrounds thicker/brighter
old_win = '''\t\tKitModular.caixa_cor(sup, &"concreto_sujo",
\t\t\tcentro + frente * (fundura * 0.5 + 0.06) + lado * (2.7 * sx)
\t\t\t\t+ Vector3(0.0, 4.3, 0.0),
\t\t\tVector3(1.15, 0.22, 0.12), ombreira, giro,
\t\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)'''
new_win = '''\t\tKitModular.caixa_cor(sup, &"concreto_sujo",
\t\t\tcentro + frente * (fundura * 0.5 + 0.1) + lado * (2.7 * sx)
\t\t\t\t+ Vector3(0.0, 4.35, 0.0),
\t\t\tVector3(1.45, 0.32, 0.22), ombreira, giro,
\t\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)'''
assert old_win in t, "window arch missing"
t = t.replace(old_win, new_win, 1)

# Darker window voids for contrast
t = t.replace(
    'Vector3(1.05, 1.25, 0.1), Color("2a2a28"), giro,',
    'Vector3(1.2, 1.4, 0.14), Color("000000"), giro,',
    1,
)
t = t.replace(
    'Vector3(0.7, 0.7, 0.1), Color("2a2a28"), giro,',
    'Vector3(0.9, 0.9, 0.14), Color("000000"), giro,',
    1,
)

kit.write_text(t, encoding="utf-8")
print("kit_parque igreja punch OK")
assert "cruz_clara" in t
assert "Vector3(3.25, 4.15, 0.58)" in t
assert "n_quoin := 8" in t

# --- parque_builder: harden flor suppress on PRACA ---
p = pb.read_text(encoding="utf-8")
# Early-return vegetacao on PRACA plaza (cobble, not garden). Keep perimeter trees
# only if density path already respects _zonas_proibidas — also skip flor atlas
# by not planting any moita. Extra guard at top of _vegetacao:
old_veg = '''static func _vegetacao(sup: Dictionary, colisao: Array[Dictionary],
\t\tplano: Dictionary, desloc: Vector2) -> void:
\tvar area: Rect2 = plano["area"]
\tvar sem := int(plano["semente"])
\tvar proibido := _zonas_proibidas(plano, 2.8)
\tvar densidade: float = DENSIDADE[int(plano["traco"])]'''
new_veg = '''static func _vegetacao(sup: Dictionary, colisao: Array[Dictionary],
\t\tplano: Dictionary, desloc: Vector2) -> void:
\t# Matriz = calcamento colonial: sem moita_de_flor / flor atlas no miolo.
\t# Arvores so na faixa periferica (zonas_proibidas ja cobre o pateo).
\tvar area: Rect2 = plano["area"]
\tvar sem := int(plano["semente"])
\tvar proibido := _zonas_proibidas(plano, 2.8)
\tvar densidade: float = DENSIDADE[int(plano["traco"])]
\tif int(plano["traco"]) == Traco.PRACA:
\t\tdensidade *= 0.35  # menos copa; zero flor (so arvore/arbusto/pinheiro abaixo)'''
assert old_veg in p, "vegetacao header missing"
p = p.replace(old_veg, new_veg, 1)

# Ensure _canteiros still early-returns (already does) — add assert comment only if present
assert "if int(plano[\"traco\"]) == Traco.PRACA:\n\t\treturn" in p
# Belt-and-suspenders: if any future caller hits moita on PRACA via lago path, fine.
# Also skip flor cells in DENSIDADE comment already.

pb.write_text(p, encoding="utf-8")
print("parque_builder flor harden OK")
print("done")
