# -*- coding: utf-8 -*-
from pathlib import Path
root = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX")

def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"FAIL {label}")
    return text.replace(old, new, 1)

# ---- mat_leito ----
lp = root / "game/resources/materials/mat_leito.tres"
lt = lp.read_text(encoding="utf-8")
lt2 = lt.replace(
    "shader_parameter/tint = Color(1.55, 0.52, 0.30, 1)",
    "shader_parameter/tint = Color(1.35, 0.78, 0.48, 1)",
)
lt2 = lt2.replace(
    "shader_parameter/emission_color = Color(0.45, 0.10, 0.03, 1)",
    "shader_parameter/emission_color = Color(0.62, 0.22, 0.08, 1)",
)
lt2 = lt2.replace(
    "shader_parameter/emission_energy = 0.28",
    "shader_parameter/emission_energy = 0.62",
)
lt2 = lt2.replace("shader_parameter/use_affine = true", "shader_parameter/use_affine = false")
if lt2 == lt:
    raise SystemExit("FAIL mat_leito no change")
lp.write_text(lt2, encoding="utf-8")
print("mat_leito OK")

kp = root / "game/src/world/kit_estrada.gd"
k = kp.read_text(encoding="utf-8")

k = replace_once(
    k,
    "const COR_TRILHA := Color(1.15, 0.42, 0.20)\n"
    "const COR_MEIO := Color(0.85, 0.26, 0.12)\n"
    "const COR_BEIRA := Color(0.68, 0.22, 0.10)\n"
    "const COR_FOLHICO := Color(0.42, 0.28, 0.14)",
    "const COR_TRILHA := Color(1.35, 0.62, 0.34)\n"
    "const COR_MEIO := Color(1.05, 0.42, 0.22)\n"
    "const COR_BEIRA := Color(0.88, 0.38, 0.20)\n"
    "const COR_FOLHICO := Color(0.62, 0.40, 0.22)",
    "palette",
)

old_relief = """\tvar und0 := Vector3(0.0,
\t\t0.085 * sin(p0.z * 1.35 + p0.x * 0.55)
\t\t+ 0.045 * sin(p0.z * 4.2 + p0.x * 1.1)
\t\t+ 0.022 * sin(p0.x * 3.8)
\t\t+ 0.018 * sin(p0.z * 7.1 + p0.x * 2.4), 0.0)
\tvar und1 := Vector3(0.0,
\t\t0.085 * sin(p1.z * 1.35 + p1.x * 0.55)
\t\t+ 0.045 * sin(p1.z * 4.2 + p1.x * 1.1)
\t\t+ 0.022 * sin(p1.x * 3.8)
\t\t+ 0.018 * sin(p1.z * 7.1 + p1.x * 2.4), 0.0)
\tfor faixa: Array in SECAO:
\t\tvar e0: float = faixa[0]
\t\tvar e1: float = faixa[1]
\t\tvar celula: Vector2i = faixa[2]
\t\tvar cor: Color = faixa[3]
\t\tvar tom_faixa := tom * (1.08 if celula == C_BARRO else (0.92 if celula == C_POCA else 1.0))
\t\t# Trilha de pneu cava"""

# find exact comment continuation - read from file
idx = k.find("var und0 := Vector3(0.0,")
idx2 = k.find("celula, Color(cor.r * tom_faixa, cor.g * tom_faixa, cor.b * tom_faixa))")
if idx < 0 or idx2 < 0:
    raise SystemExit(f"FAIL relief anchors {idx} {idx2}")
idx2 = idx2 + len("celula, Color(cor.r * tom_faixa, cor.g * tom_faixa, cor.b * tom_faixa))")
# back up to start of und0 block - find prior comment line
block_start = k.rfind("\tvar und0", 0, idx + 5)
new_relief = """\t# P0: relevo forte + bias Y para o leito NAO sumir sob capo/z-fight.
\tvar lift := Vector3(0.0, 0.045, 0.0)
\tvar und0 := Vector3(0.0,
\t\t0.11 * sin(p0.z * 1.35 + p0.x * 0.55)
\t\t+ 0.06 * sin(p0.z * 4.2 + p0.x * 1.1)
\t\t+ 0.03 * sin(p0.x * 3.8)
\t\t+ 0.025 * sin(p0.z * 7.1 + p0.x * 2.4), 0.0)
\tvar und1 := Vector3(0.0,
\t\t0.11 * sin(p1.z * 1.35 + p1.x * 0.55)
\t\t+ 0.06 * sin(p1.z * 4.2 + p1.x * 1.1)
\t\t+ 0.03 * sin(p1.x * 3.8)
\t\t+ 0.025 * sin(p1.z * 7.1 + p1.x * 2.4), 0.0)
\tfor faixa: Array in SECAO:
\t\tvar e0: float = faixa[0]
\t\tvar e1: float = faixa[1]
\t\tvar celula: Vector2i = faixa[2]
\t\tvar cor: Color = faixa[3]
\t\t# Nao esmagar G/B — albedo preto era a causa do chao invisivel no FP.
\t\tvar tom_faixa := tom * (1.12 if celula == C_BARRO else (1.0 if celula == C_POCA else 1.05))
\t\tvar sulco0 := Vector3.ZERO
\t\tvar sulco1 := Vector3.ZERO
\t\tvar e_mid := absf((e0 + e1) * 0.5)
\t\tif celula == C_BARRO and e_mid > 0.6 and e_mid < 1.7:
\t\t\tsulco0 = Vector3(0.0, -0.09, 0.0)
\t\t\tsulco1 = Vector3(0.0, -0.09, 0.0)
\t\telif celula == C_POCA:
\t\t\tsulco0 = Vector3(0.0, -0.04, 0.0)
\t\t\tsulco1 = Vector3(0.0, -0.04, 0.0)
\t\tquad(sup, M_LEITO,
\t\t\tp0 + lado0 * e0 + und0 + sulco0 + lift, p0 + lado0 * e1 + und0 * 0.7 + sulco0 + lift,
\t\t\tp1 + lado1 * e1 + und1 * 0.7 + sulco1 + lift, p1 + lado1 * e0 + und1 + sulco1 + lift,
\t\t\tcelula, Color(cor.r * tom_faixa, cor.g * tom_faixa, cor.b * tom_faixa))"""
# include from und0 through quad end - but old block may have comment before und0
# Use from first und0 of leito function
leito_fn = k.find("static func leito")
und0_in_leito = k.find("\tvar und0 := Vector3(0.0,", leito_fn)
quad_end = k.find("celula, Color(cor.r * tom_faixa, cor.g * tom_faixa, cor.b * tom_faixa))", und0_in_leito)
quad_end = k.find("\n", quad_end) 
k = k[:und0_in_leito] + new_relief + k[quad_end:]
print("relief OK")

k = replace_once(
    k,
    "\t\tvar d := rng.randf_range(MEIA_PISTA - 0.85, MEIA_PISTA + 3.8)\n"
    "\t\tvar onde := p + lado * (d * s) + lado.cross(Vector3.UP).normalized() * rng.randf_range(-0.7, 0.7)\n"
    "\t\tvar celula: Vector2i = CELULAS[rng.randi() % CELULAS.size()]\n"
    "\t\tvar tam := rng.randf_range(0.75, 1.85)",
    "\t\t# P0: NUNCA plantar no leito — corredor visual (ref 04).\n"
    "\t\tvar d := rng.randf_range(MEIA_PISTA + 0.55, MEIA_PISTA + 4.2)\n"
    "\t\tvar onde := p + lado * (d * s) + lado.cross(Vector3.UP).normalized() * rng.randf_range(-0.55, 0.55)\n"
    "\t\tvar celula: Vector2i = CELULAS[rng.randi() % CELULAS.size()]\n"
    "\t\tvar tam := rng.randf_range(0.55, 1.35)",
    "beira",
)

k = replace_once(
    k,
    "\trng: RandomNumberGenerator, quantos: int = 14) -> void:",
    "\trng: RandomNumberGenerator, quantos: int = 8) -> void:",
    "beira_default",
)

# cipo body
cipo_start = k.find("\t# Cordao principal")
if cipo_start < 0:
    cipo_start = k.find("static func cipo")
    cipo_start = k.find("KitModular.caixa_cor(sup, M_CASCA, meio,", cipo_start)
else:
    pass
cipo_fn = k.find("static func cipo")
cipo_body_start = k.find("\t# Cordao", cipo_fn)
if cipo_body_start < 0:
    cipo_body_start = k.find("\tKitModular.caixa_cor(sup, M_CASCA, meio,", cipo_fn)
casa_fn = k.find("static func casa_beira")
if cipo_body_start < 0 or casa_fn < 0:
    raise SystemExit(f"FAIL cipo anchors {cipo_body_start} {casa_fn}")
# end before blank lines + doc of casa
cipo_end = k.rfind("\n\n", cipo_body_start, casa_fn)
new_cipo = """\t# Cordao fino — NAO massa preta no para-brisa (P0 corredor).
\tKitModular.caixa_cor(sup, M_CASCA, meio,
\t\tVector3(0.055, 0.055, comp * 0.95), Color(\"2a2218\"), giro,
\t\tPSXMesh.FACE_TODAS, 6.0)
\t# Fios/cipos como FIOS distintos (GALHO_SECO), nao blobs de moita.
\tfor k in rng.randi_range(5, 8):
\t\tvar t := rng.randf_range(0.08, 0.95)
\t\tvar p := ancora.lerp(sobre_pista, t)
\t\tvar queda := rng.randf_range(1.6, 2.8)
\t\tKitModular.caixa_cor(sup, M_CASCA,
\t\t\tp - Vector3(0.0, queda * 0.5, 0.0),
\t\t\tVector3(0.035, queda, 0.035), Color(\"2e281c\"),
\t\t\trng.randf_range(-0.2, 0.2), PSXMesh.FACE_TODAS, 5.0)
\t\ttufo(sup, p - Vector3(0.0, queda * 0.75, 0.0),
\t\t\tC_GALHO_SECO if rng.randf() < 0.65 else C_CAPIM_SECO,
\t\t\tqueda * 0.35, rng.randf_range(0.0, TAU), cor)
\t\tif rng.randf() < 0.35:
\t\t\ttufo(sup, p - Vector3(rng.randf_range(-0.2, 0.2), queda * 0.55, rng.randf_range(-0.15, 0.15)),
\t\t\t\tC_SAMAMBAIA, queda * 0.28, rng.randf_range(0.0, TAU),
\t\t\t\tcor.lerp(Color(0.35, 0.42, 0.22), 0.3))
"""
k = k[:cipo_body_start] + new_cipo + k[cipo_end:]
print("cipo OK")

# casa sizes + roof
k = replace_once(
    k,
    "\tvar larg := rng.randf_range(3.4, 4.2)\n"
    "\tvar fund := rng.randf_range(2.5, 3.1)\n"
    "\tvar alt := rng.randf_range(2.2, 2.7)",
    "\tvar larg := rng.randf_range(3.6, 4.4)\n"
    "\tvar fund := rng.randf_range(2.6, 3.2)\n"
    "\tvar alt := rng.randf_range(2.35, 2.85)",
    "casa_size",
)
k = replace_once(
    k,
    "\tvar h_base := 0.52",
    "\tvar h_base := 0.58",
    "casa_base",
)

# insert plank detail + stronger gable after corpo caixa
old_telhado = """\t# Telhado em V raso.
\tKitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, corpo_y + alt + 0.38, 0.0),
\t\tVector3(larg + 0.4, 0.58, fund + 0.3), telha, giro,
\t\tPSXMesh.FACE_TODAS, 3.0)
\t# Cumeeira escura — silhueta no facho.
\tKitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, corpo_y + alt + 0.7, 0.0),
\t\tVector3(larg * 0.2, 0.18, fund + 0.15), Color(0.32, 0.22, 0.14), giro,
\t\tPSXMesh.FACE_TODAS, 4.0)"""
new_telhado = """\t# Tabuas horizontais — leitura de madeira gasta no facho.
\tfor yi in 4:
\t\tvar yy := corpo_y + 0.35 + float(yi) * (alt * 0.22)
\t\tKitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, yy, fund * 0.5 + 0.02),
\t\t\tVector3(larg * 0.96, 0.06, 0.05),
\t\t\tparede.lerp(Color(0.55, 0.42, 0.28), 0.35 + float(yi) * 0.08), giro,
\t\t\tPSXMesh.FACE_TODAS, 5.0)
\t# Telhado gable alto — silhueta de oratorio (ref 04).
\tvar h_telha := 0.85
\tKitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, corpo_y + alt + h_telha * 0.45, 0.0),
\t\tVector3(larg + 0.55, h_telha, fund + 0.35), telha, giro,
\t\tPSXMesh.FACE_TODAS, 3.0)
\tKitModular.caixa_cor(sup, M_TABUA, base + Vector3(0.0, corpo_y + alt + h_telha + 0.12, 0.0),
\t\tVector3(larg * 0.18, 0.22, fund + 0.2), Color(0.28, 0.18, 0.12), giro,
\t\tPSXMesh.FACE_TODAS, 4.0)"""
# tolerate dash variants in comment
if old_telhado not in k:
    # try without special dash
    import re
    m = re.search(r"\t# Telhado em V raso\.\n.*?FACE_TODAS, 4\.0\)", k, re.S)
    if not m:
        raise SystemExit("FAIL telhado")
    k = k[: m.start()] + new_telhado + k[m.end() :]
else:
    k = k.replace(old_telhado, new_telhado, 1)
print("casa OK")

kp.write_text(k, encoding="utf-8")
print("kit written", len(k))
