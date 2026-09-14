# -*- coding: utf-8 -*-
from pathlib import Path
path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\render\carroceria.gd")
text = path.read_text(encoding="utf-8")

# 1) Fix _vidros: single-sided OUT only (FP sees through via cull_back)
old_vidros = """\t# Para-brisa, inclinado para tras. Dois lados: rua e cabine.
\tvar incl := atan2(recuo, alt)
\tvar xf := Transform3D(Basis(Vector3.RIGHT, -incl),
\t\tVector3(0.0, capo + alt * 0.5, z1 - recuo * 0.5 + 0.01))
\t_face_dois_lados(dados, Vector2(lv, sqrt(alt * alt + recuo * recuo)), xf,
\t\tVIDRO, C_PARABRISA)

\t# Vigia, inclinado para a frente. Mesma celula + VIDRO dos dois lados.
\tvar xf2 := Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -incl),
\t\tVector3(0.0, capo + alt * 0.5, z0 + recuo * 0.5 - 0.01))
\t_face_dois_lados(dados, Vector2(lv, sqrt(alt * alt + recuo * recuo)), xf2,
\t\tVIDRO, C_VIDRO_TRAS)"""

new_vidros = """\t# Para-brisa, UMA face para FORA. Com cull_back do psx_surface, a cabine FP
\t# ve o verso cullado e enxerga a rua (transparente). Face interna opaca era o
\t# P0: para-brisa preto solido na Estrada Velha. Nao voltar _face_dois_lados
\t# aqui sem alfa de verdade no material.
\tvar incl := atan2(recuo, alt)
\tvar xf := Transform3D(Basis(Vector3.RIGHT, -incl),
\t\tVector3(0.0, capo + alt * 0.5, z1 - recuo * 0.5 + 0.01))
\t_face(dados, Vector2(lv, sqrt(alt * alt + recuo * recuo)), xf,
\t\tColor(0.55, 0.62, 0.70), C_PARABRISA)

\t# Vigia: mesma regra — so face externa.
\tvar xf2 := Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -incl),
\t\tVector3(0.0, capo + alt * 0.5, z0 + recuo * 0.5 - 0.01))
\t_face(dados, Vector2(lv, sqrt(alt * alt + recuo * recuo)), xf2,
\t\tColor(0.48, 0.55, 0.62), C_VIDRO_TRAS)"""

if old_vidros not in text:
    # try looser match
    raise SystemExit("vidros block not found:\n" + text[text.find("static func _vidros"):text.find("static func _vidros")+800])
text = text.replace(old_vidros, new_vidros, 1)

# 2) Remove inward side-glass from generic _lataria
old_side = """\t\tvar desloca := fora * 0.006
\t\tPSXMesh.acumular(dados,
\t\t\t_quad_lateral(
\t\t\t\t_encolher(a, b, c, d, 0) + desloca,
\t\t\t\t_encolher(a, b, c, d, 1) + desloca,
\t\t\t\t_encolher(a, b, c, d, 2) + desloca,
\t\t\t\t_encolher(a, b, c, d, 3) + desloca,
\t\t\t\tC_VIDRO_LADO, VIDRO, fora),
\t\t\tTransform3D.IDENTITY)
\t\t# Verso do vidro lateral: mesma celula, normal para dentro. Sem isto a
\t\t# cabine olhando para fora (e o bug das refs) come o vidro com cull_back.
\t\tvar desloca_in := fora * -0.004
\t\tPSXMesh.acumular(dados,
\t\t\t_quad_lateral(
\t\t\t\t_encolher(a, b, c, d, 0) + desloca_in,
\t\t\t\t_encolher(a, b, c, d, 1) + desloca_in,
\t\t\t\t_encolher(a, b, c, d, 2) + desloca_in,
\t\t\t\t_encolher(a, b, c, d, 3) + desloca_in,
\t\t\t\tC_VIDRO_LADO, VIDRO, -fora),
\t\t\tTransform3D.IDENTITY)"""

new_side = """\t\tvar desloca := fora * 0.006
\t\t# So face externa. Face interna opaca bloquearia a cabine FP / vista lateral.
\t\tPSXMesh.acumular(dados,
\t\t\t_quad_lateral(
\t\t\t\t_encolher(a, b, c, d, 0) + desloca,
\t\t\t\t_encolher(a, b, c, d, 1) + desloca,
\t\t\t\t_encolher(a, b, c, d, 2) + desloca,
\t\t\t\t_encolher(a, b, c, d, 3) + desloca,
\t\t\t\tC_VIDRO_LADO, VIDRO, fora),
\t\t\tTransform3D.IDENTITY)"""

if old_side not in text:
    raise SystemExit("lataria side glass block not found")
text = text.replace(old_side, new_side, 1)

# 3) Remove inward side-glass from _lataria_fusca if present
old_fusca_side = """\t\tvar desloca := fora * 0.008
\t\tPSXMesh.acumular(dados,
\t\t\t_quad_lateral(
\t\t\t\t_encolher(a, b, c, d, 0) + desloca,
\t\t\t\t_encolher(a, b, c, d, 1) + desloca,
\t\t\t\t_encolher(a, b, c, d, 2) + desloca,
\t\t\t\t_encolher(a, b, c, d, 3) + desloca,
\t\t\t\tC_VIDRO_LADO, VIDRO, fora), Transform3D.IDENTITY)
\t\tvar desloca_in := fora * -0.005
\t\tPSXMesh.acumular(dados,
\t\t\t_quad_lateral(
\t\t\t\t_encolher(a, b, c, d, 0) + desloca_in,
\t\t\t\t_encolher(a, b, c, d, 1) + desloca_in,
\t\t\t\t_encolher(a, b, c, d, 2) + desloca_in,
\t\t\t\t_encolher(a, b, c, d, 3) + desloca_in,
\t\t\t\tC_VIDRO_LADO, VIDRO, -fora), Transform3D.IDENTITY)"""

new_fusca_side = """\t\tvar desloca := fora * 0.008
\t\tPSXMesh.acumular(dados,
\t\t\t_quad_lateral(
\t\t\t\t_encolher(a, b, c, d, 0) + desloca,
\t\t\t\t_encolher(a, b, c, d, 1) + desloca,
\t\t\t\t_encolher(a, b, c, d, 2) + desloca,
\t\t\t\t_encolher(a, b, c, d, 3) + desloca,
\t\t\t\tC_VIDRO_LADO, VIDRO, fora), Transform3D.IDENTITY)"""

if old_fusca_side in text:
    text = text.replace(old_fusca_side, new_fusca_side, 1)
    print("fusca side fixed")
else:
    print("fusca side pattern missing (ok if already clean)")

# Update _face_dois_lados comment to warn about FP
old_helper = """## Placa com verso. O psx_surface usa cull_back; vidro de uma face some quando a
## camera esta do outro lado (cabine olhando para fora, ou rua olhando o verso
## de um para-brisa invertido). Marea e Fusca herdam o mesmo caminho — sem
## material novo, sem celula nova: C_PARABRISA / C_VIDRO_* + VIDRO dos dois lados.
static func _face_dois_lados"""

# encoding may vary on dash
import re
text2, n = re.subn(
    r"## Placa com verso\..*?static func _face_dois_lados",
    """## Placa com verso. CUIDADO: em vidro OPaco isso preenche o verso e a cabine
## FP ve preto solido (P0 Estrada Velha). So usar com alfa de verdade, ou em
## pecas que a camera de dentro nunca encara. Para-brisa/vigia usam _face unica.
static func _face_dois_lados""",
    text,
    count=1,
    flags=re.S,
)
if n != 1:
    print("helper comment warn: replace count", n)
else:
    text = text2
    print("helper comment updated")

path.write_text(text, encoding="utf-8")
print("P0 glass fix written")