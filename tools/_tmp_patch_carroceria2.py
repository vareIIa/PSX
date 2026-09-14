# -*- coding: utf-8 -*-
from pathlib import Path
path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\render\carroceria.gd")
text = path.read_text(encoding="utf-8")

# Side glass: add inward face after outward glass in _lataria
old_side = """\t\tvar desloca := fora * 0.006
\t\tPSXMesh.acumular(dados,
\t\t\t_quad_lateral(
\t\t\t\t_encolher(a, b, c, d, 0) + desloca,
\t\t\t\t_encolher(a, b, c, d, 1) + desloca,
\t\t\t\t_encolher(a, b, c, d, 2) + desloca,
\t\t\t\t_encolher(a, b, c, d, 3) + desloca,
\t\t\t\tC_VIDRO_LADO, VIDRO, fora),
\t\t\tTransform3D.IDENTITY)"""

new_side = """\t\tvar desloca := fora * 0.006
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
assert old_side in text, "side glass block not found"
text = text.replace(old_side, new_side, 1)

# _vidros: two-sided + VIDRO color
old_vidros = """\t# Para-brisa, inclinado para tras.
\tvar incl := atan2(recuo, alt)
\tvar xf := Transform3D(Basis(Vector3.RIGHT, -incl),
\t\tVector3(0.0, capo + alt * 0.5, z1 - recuo * 0.5 + 0.01))
\t_face(dados, Vector2(lv, sqrt(alt * alt + recuo * recuo)), xf,
\t\tColor(0.72, 0.80, 0.86), C_PARABRISA)

\t# Vigia, inclinado para a frente.
\tvar xf2 := Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -incl),
\t\tVector3(0.0, capo + alt * 0.5, z0 + recuo * 0.5 - 0.01))
\t_face(dados, Vector2(lv, sqrt(alt * alt + recuo * recuo)), xf2,
\t\tColor(0.62, 0.70, 0.76), C_VIDRO_TRAS)"""

new_vidros = """\t# Para-brisa, inclinado para tras. Dois lados: rua e cabine.
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
assert old_vidros in text, "_vidros block not found"
text = text.replace(old_vidros, new_vidros, 1)

# _frente_e_tras: specialize FUSCA
old_ft = """## Grade, para-choques, placa e as lampadas.
static func _frente_e_tras(dados: Dictionary, luzes: Dictionary, comp: float,
\t\tlarg: float, capo: float, _cor: Color, _modelo: Modelo) -> void:
\tvar zf := comp * 0.5 + 0.005
\tvar zt := -comp * 0.5 - 0.005
\tvar y := ASSOALHO + (capo - ASSOALHO) * 0.52

\t_face(dados, Vector2(larg * 0.78, 0.18),
\t\tTransform3D(Basis(), Vector3(0.0, y + 0.06, zf)), Color(0.30, 0.30, 0.32), C_GRADE)
\tfor z: float in [zf, zt]:
\t\tvar frente := z > 0.0
\t\t_face(dados, Vector2(larg, 0.16),
\t\t\tTransform3D(Basis(Vector3.UP, 0.0 if frente else PI),
\t\t\t\tVector3(0.0, ASSOALHO + 0.10, z)),
\t\t\tColor(0.52, 0.52, 0.54), C_PARACHOQUE)
\t\t_face(dados, Vector2(0.32, 0.11),
\t\t\tTransform3D(Basis(Vector3.UP, 0.0 if frente else PI),
\t\t\t\tVector3(0.0, ASSOALHO + 0.24, z + (0.006 if frente else -0.006))),
\t\t\tColor.WHITE, C_PLACA)

\t# Farois e lanternas, na malha emissiva. Dois de cada lado, encostados na
\t# quina — e a posicao que faz o par ler como par a distancia.
\tvar ox := larg * 0.34
\tfor s: float in [1.0, -1.0]:
\t\t_face(luzes, Vector2(0.26, 0.13),
\t\t\tTransform3D(Basis(), Vector3(s * ox, y + 0.10, zf + 0.006)),
\t\t\tColor.WHITE, C_FAROL)
\t\t_face(luzes, Vector2(0.24, 0.14),
\t\t\tTransform3D(Basis(Vector3.UP, PI), Vector3(s * ox, y + 0.10, zt - 0.006)),
\t\t\tColor.WHITE, C_LANTERNA)"""

new_ft = """## Grade, para-choques, placa e as lampadas.
static func _frente_e_tras(dados: Dictionary, luzes: Dictionary, comp: float,
\t\tlarg: float, capo: float, cor: Color, modelo: Modelo) -> void:
\tif modelo == Modelo.FUSCA:
\t\t_frente_e_tras_fusca(dados, luzes, comp, larg, capo, cor)
\t\treturn
\tvar zf := comp * 0.5 + 0.005
\tvar zt := -comp * 0.5 - 0.005
\tvar y := ASSOALHO + (capo - ASSOALHO) * 0.52

\t_face(dados, Vector2(larg * 0.78, 0.18),
\t\tTransform3D(Basis(), Vector3(0.0, y + 0.06, zf)), Color(0.30, 0.30, 0.32), C_GRADE)
\tfor z: float in [zf, zt]:
\t\tvar frente := z > 0.0
\t\t_face(dados, Vector2(larg, 0.16),
\t\t\tTransform3D(Basis(Vector3.UP, 0.0 if frente else PI),
\t\t\t\tVector3(0.0, ASSOALHO + 0.10, z)),
\t\t\tColor(0.52, 0.52, 0.54), C_PARACHOQUE)
\t\t_face(dados, Vector2(0.32, 0.11),
\t\t\tTransform3D(Basis(Vector3.UP, 0.0 if frente else PI),
\t\t\t\tVector3(0.0, ASSOALHO + 0.24, z + (0.006 if frente else -0.006))),
\t\t\tColor.WHITE, C_PLACA)

\t# Farois e lanternas, na malha emissiva. Dois de cada lado, encostados na
\t# quina — e a posicao que faz o par ler como par a distancia.
\tvar ox := larg * 0.34
\tfor s: float in [1.0, -1.0]:
\t\t_face(luzes, Vector2(0.26, 0.13),
\t\t\tTransform3D(Basis(), Vector3(s * ox, y + 0.10, zf + 0.006)),
\t\t\tColor.WHITE, C_FAROL)
\t\t_face(luzes, Vector2(0.24, 0.14),
\t\t\tTransform3D(Basis(Vector3.UP, PI), Vector3(s * ox, y + 0.10, zt - 0.006)),
\t\t\tColor.WHITE, C_LANTERNA)"""
assert old_ft in text, "_frente_e_tras not found"
text = text.replace(old_ft, new_ft, 1)

path.write_text(text, encoding="utf-8")
print("pass2 ok", path.stat().st_size)
