# -*- coding: utf-8 -*-
"""Pass 2b: farol no corpo (legivel sem emissivo) + teto cupula mais fechada + sujeira nos arcos."""
from pathlib import Path

path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\render\carroceria.gd")
text = path.read_text(encoding="utf-8")
vid_before = text[text.index("static func _vidros"): text.index("static func _frente_e_tras")]

# --- Replace floating thin roof side plates with thicker cupola sides ---
old_roof_side = """\tfor s: float in [1.0, -1.0]:
\t\tvar teto_basis := Basis(Vector3.FORWARD, s * 0.55) * Basis(Vector3.RIGHT, -PI * 0.5)
\t\t_face(dados, Vector2(teto_comp * 0.90, 0.16),
\t\t\tTransform3D(teto_basis, Vector3(s * lc * 0.42, teto - 0.04, z_mid)), cor, C_TETO)"""

new_roof_side = """\t# Laterais da cupula: placas quase verticais encostadas no teto (sem 'asa' solta).
\tfor s: float in [1.0, -1.0]:
\t\tvar basis_teto_lado := Basis(Vector3.UP, s * PI * 0.5) * Basis(Vector3.RIGHT, -0.35)
\t\t_face(dados, Vector2(teto_comp * 0.85, 0.22),
\t\t\tTransform3D(basis_teto_lado,
\t\t\t\tVector3(s * lc * 0.40, teto - 0.10, z_mid)), cor, C_TETO)"""

if old_roof_side not in text:
    raise SystemExit("roof side block missing")
text = text.replace(old_roof_side, new_roof_side, 1)

# --- Headlights: bright cores on BODY mesh + thicker ring (read without luzes) ---
old_farol = """\tvar ox := larg * 0.46
\tvar yf := y + 0.06
\tfor s: float in [1.0, -1.0]:
\t\t_caixa(dados, Vector3(0.22, 0.22, 0.10),
\t\t\tVector3(s * ox, yf, zf - 0.02), Color(0.16, 0.16, 0.18),
\t\t\tC_GRADE, C_GRADE, C_GRADE, false)
\t\t_face(dados, Vector2(0.30, 0.30),
\t\t\tTransform3D(Basis(), Vector3(s * ox, yf, zf + 0.012)),
\t\t\tColor(0.12, 0.12, 0.14), C_GRADE)
\t\t_face(dados, Vector2(0.24, 0.24),
\t\t\tTransform3D(Basis(Vector3.FORWARD, PI * 0.25),
\t\t\t\tVector3(s * ox, yf, zf + 0.014)),
\t\t\tColor(0.18, 0.18, 0.20), C_GRADE)
\t\t_face(dados, Vector2(0.20, 0.20),
\t\t\tTransform3D(Basis(Vector3.FORWARD, PI * 0.125),
\t\t\t\tVector3(s * ox, yf, zf + 0.016)),
\t\t\tColor(0.22, 0.22, 0.24), C_GRADE)
\t\t_face(luzes, Vector2(0.16, 0.16),
\t\t\tTransform3D(Basis(), Vector3(s * ox, yf, zf + 0.022)),
\t\t\tColor.WHITE, C_FAROL)
\t\t_face(luzes, Vector2(0.08, 0.08),
\t\t\tTransform3D(Basis(), Vector3(s * ox, yf, zf + 0.026)),
\t\t\tColor(0.95, 0.95, 0.85), C_FAROL)
\t\t_face(luzes, Vector2(0.10, 0.055),
\t\t\tTransform3D(Basis(), Vector3(s * ox, yf + 0.18, zf - 0.06)),
\t\t\tColor(1.0, 0.68, 0.16), C_PISCA)
\t\t_face(luzes, Vector2(0.11, 0.06),
\t\t\tTransform3D(Basis(Vector3.UP, PI), Vector3(s * ox, y + 0.18, zt - 0.012)),
\t\t\tColor(1.0, 0.50, 0.12), C_LANTERNA)
\t\t_face(luzes, Vector2(0.11, 0.08),
\t\t\tTransform3D(Basis(Vector3.UP, PI), Vector3(s * ox, y + 0.08, zt - 0.012)),
\t\t\tColor.WHITE, C_FREIO)"""

new_farol = """\t# Farol redondo PSX nos para-lamas: anel escuro + nucleo CLARO no corpo
\t# (legivel mesmo se MATERIAL_LUZ falhar na vitrine) + emissivo por cima.
\tvar ox := larg * 0.46
\tvar yf := y + 0.08
\tfor s: float in [1.0, -1.0]:
\t\t_caixa(dados, Vector3(0.26, 0.26, 0.14),
\t\t\tVector3(s * ox, yf, zf - 0.04), Color(0.55, 0.52, 0.46),
\t\t\tC_LATARIA_SUJA, C_GRADE, C_CAPO, false)
\t\t_face(dados, Vector2(0.32, 0.32),
\t\t\tTransform3D(Basis(), Vector3(s * ox, yf, zf + 0.014)),
\t\t\tColor(0.10, 0.10, 0.12), C_GRADE)
\t\t_face(dados, Vector2(0.26, 0.26),
\t\t\tTransform3D(Basis(Vector3.FORWARD, PI * 0.25),
\t\t\t\tVector3(s * ox, yf, zf + 0.016)),
\t\t\tColor(0.14, 0.14, 0.16), C_GRADE)
\t\t# Nucleo claro no CORPO — le como farol circular a 480p.
\t\t_face(dados, Vector2(0.20, 0.20),
\t\t\tTransform3D(Basis(), Vector3(s * ox, yf, zf + 0.020)),
\t\t\tColor(0.92, 0.90, 0.78), C_FAROL)
\t\t_face(dados, Vector2(0.14, 0.14),
\t\t\tTransform3D(Basis(Vector3.FORWARD, PI * 0.25),
\t\t\t\tVector3(s * ox, yf, zf + 0.022)),
\t\t\tColor(0.98, 0.96, 0.88), C_FAROL)
\t\t_face(luzes, Vector2(0.12, 0.12),
\t\t\tTransform3D(Basis(), Vector3(s * ox, yf, zf + 0.028)),
\t\t\tColor.WHITE, C_FAROL)
\t\t_face(luzes, Vector2(0.10, 0.055),
\t\t\tTransform3D(Basis(), Vector3(s * ox, yf + 0.20, zf - 0.08)),
\t\t\tColor(1.0, 0.68, 0.16), C_PISCA)
\t\t_face(luzes, Vector2(0.12, 0.07),
\t\t\tTransform3D(Basis(Vector3.UP, PI), Vector3(s * ox, y + 0.18, zt - 0.012)),
\t\t\tColor(1.0, 0.50, 0.12), C_LANTERNA)
\t\t_face(luzes, Vector2(0.12, 0.09),
\t\t\tTransform3D(Basis(Vector3.UP, PI), Vector3(s * ox, y + 0.08, zt - 0.012)),
\t\t\tColor.WHITE, C_FREIO)"""

if old_farol not in text:
    raise SystemExit("farol block missing")
text = text.replace(old_farol, new_farol, 1)

# --- Extra rust wrap on front of fenders (visible in 03_frente) ---
old_marker = "\t# Cabine alinhada ao _vidros (P0) — NAO alterar z0/recuo."
if old_marker not in text:
    # try ascii dash variant
    old_marker = "\t# Cabine alinhada ao _vidros (P0)"
    idx = text.find(old_marker)
    if idx < 0:
        raise SystemExit("cabin marker missing")
    # find full line
    end = text.find("\n", idx)
    old_marker = text[idx:end]

extra = """\t# Nose rusty wrap on fender fronts (ref_03 dirt weight).
\tfor s: float in [1.0, -1.0]:
\t\t_face(dados, Vector2(0.34, altura_casco * 0.40),
\t\t\tTransform3D(Basis(), Vector3(s * larg * 0.50, ASSOALHO + altura_casco * 0.28, comp * 0.48)),
\t\t\tferrugem, C_LATARIA_SUJA)
\t\t_face(dados, Vector2(0.28, altura_casco * 0.22),
\t\t\tTransform3D(Basis(), Vector3(s * larg * 0.48, ASSOALHO + altura_casco * 0.55, comp * 0.50)),
\t\t\tferrugem_clara, C_LATARIA_SUJA)

"""

if "Nose rusty wrap" not in text:
    text = text.replace(old_marker, extra + "\t" + old_marker.lstrip("\t"), 1)

vid_after = text[text.index("static func _vidros"): text.index("static func _frente_e_tras")]
assert vid_after == vid_before
assert "static func _frente_e_tras_marea" in text
path.write_text(text, encoding="utf-8")
print("pass2b ok", path.stat().st_size)
print("farol corpo", "Color(0.92, 0.90, 0.78)" in text)
print("nose rust", "Nose rusty wrap" in text)
