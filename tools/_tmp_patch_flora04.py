# -*- coding: utf-8 -*-
"""Patch KitEstrada + EstradaBuilder + mat_leito/mato + fog noite for flora_04 AAA."""
from pathlib import Path

ROOT = Path(".")

def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"FAIL {label}: old block not found")
    return text.replace(old, new, 1)

# --- kit_estrada.gd ---------------------------------------------------------
kit_path = ROOT / "game/src/world/kit_estrada.gd"
kit = kit_path.read_text(encoding="utf-8")

kit = replace_once(
    kit,
    """## Paleta de barro vermelho (ref 04): saturada no facho, escura fora.
const COR_TRILHA := Color(0.98, 0.55, 0.38)
const COR_MEIO := Color(0.72, 0.30, 0.18)
const COR_BEIRA := Color(0.55, 0.24, 0.14)
const COR_FOLHICO := Color(0.42, 0.32, 0.18)""",
    """## Paleta de barro vermelho (ref 04): saturada no facho, escura fora.
## Trilha NAO pode ser quase-branca: sob farol vira areia tan (fp_p0_vidro).
const COR_TRILHA := Color(0.88, 0.36, 0.20)
const COR_MEIO := Color(0.58, 0.20, 0.11)
const COR_BEIRA := Color(0.45, 0.16, 0.09)
const COR_FOLHICO := Color(0.32, 0.24, 0.12)""",
    "palette",
)

kit = replace_once(
    kit,
    """const SECAO: Array = [
	[-MEIA_PISTA, -2.05, C_FOLHICO, COR_FOLHICO],
	[-2.05, -TRILHA - MEIA_TRILHA, C_BARRO, COR_BEIRA],
	[-TRILHA - MEIA_TRILHA, -TRILHA + MEIA_TRILHA, C_BARRO, COR_TRILHA],
	[-TRILHA + MEIA_TRILHA, TRILHA - MEIA_TRILHA, C_CASCALHO, COR_MEIO],
	[TRILHA - MEIA_TRILHA, TRILHA + MEIA_TRILHA, C_BARRO, COR_TRILHA],
	[TRILHA + MEIA_TRILHA, 2.05, C_BARRO, COR_BEIRA],
	[2.05, MEIA_PISTA, C_FOLHICO, COR_FOLHICO],
]""",
    """const SECAO: Array = [
	[-MEIA_PISTA, -2.05, C_FOLHICO, COR_FOLHICO],
	[-2.05, -TRILHA - MEIA_TRILHA, C_BARRO, COR_BEIRA],
	[-TRILHA - MEIA_TRILHA, -TRILHA + MEIA_TRILHA, C_BARRO, COR_TRILHA],
	# Meio com C_POCA (mais escuro/vermelho) — C_CASCALHO cinza virava areia no facho.
	[-TRILHA + MEIA_TRILHA, TRILHA - MEIA_TRILHA, C_POCA, COR_MEIO],
	[TRILHA - MEIA_TRILHA, TRILHA + MEIA_TRILHA, C_BARRO, COR_TRILHA],
	[TRILHA + MEIA_TRILHA, 2.05, C_BARRO, COR_BEIRA],
	[2.05, MEIA_PISTA, C_FOLHICO, COR_FOLHICO],
]""",
    "secao",
)

kit = replace_once(
    kit,
    """	# Micro-relevo: onda longa + ripple curto + sulco nas trilhas (ref 04 / TP).
	var und0 := Vector3(0.0,
		0.055 * sin(p0.z * 1.35 + p0.x * 0.55)
		+ 0.028 * sin(p0.z * 4.2 + p0.x * 1.1)
		+ 0.012 * sin(p0.x * 3.8), 0.0)
	var und1 := Vector3(0.0,
		0.055 * sin(p1.z * 1.35 + p1.x * 0.55)
		+ 0.028 * sin(p1.z * 4.2 + p1.x * 1.1)
		+ 0.012 * sin(p1.x * 3.8), 0.0)
	for faixa: Array in SECAO:
		var e0: float = faixa[0]
		var e1: float = faixa[1]
		var celula: Vector2i = faixa[2]
		var cor: Color = faixa[3]
		var tom_faixa := tom * (1.06 if celula == C_BARRO else (0.96 if celula == C_CASCALHO else 1.0))
		# Trilha de pneu fica um pouco mais cava — leitura de relevo no facho e no TP.
		var sulco0 := Vector3.ZERO
		var sulco1 := Vector3.ZERO
		if celula == C_BARRO and absf((e0 + e1) * 0.5) > 0.6 and absf((e0 + e1) * 0.5) < 1.7:
			sulco0 = Vector3(0.0, -0.035, 0.0)
			sulco1 = Vector3(0.0, -0.035, 0.0)""",
    """	# Micro-relevo AAA (ref 04): onda + ripple + sulco fundo nas trilhas.
	var und0 := Vector3(0.0,
		0.085 * sin(p0.z * 1.35 + p0.x * 0.55)
		+ 0.045 * sin(p0.z * 4.2 + p0.x * 1.1)
		+ 0.022 * sin(p0.x * 3.8)
		+ 0.018 * sin(p0.z * 7.1 + p0.x * 2.4), 0.0)
	var und1 := Vector3(0.0,
		0.085 * sin(p1.z * 1.35 + p1.x * 0.55)
		+ 0.045 * sin(p1.z * 4.2 + p1.x * 1.1)
		+ 0.022 * sin(p1.x * 3.8)
		+ 0.018 * sin(p1.z * 7.1 + p1.x * 2.4), 0.0)
	for faixa: Array in SECAO:
		var e0: float = faixa[0]
		var e1: float = faixa[1]
		var celula: Vector2i = faixa[2]
		var cor: Color = faixa[3]
		var tom_faixa := tom * (1.08 if celula == C_BARRO else (0.92 if celula == C_POCA else 1.0))
		# Trilha de pneu cava — micro-relevo legivel no facho (ref 04).
		var sulco0 := Vector3.ZERO
		var sulco1 := Vector3.ZERO
		var e_mid := absf((e0 + e1) * 0.5)
		if celula == C_BARRO and e_mid > 0.6 and e_mid < 1.7:
			sulco0 = Vector3(0.0, -0.065, 0.0)
			sulco1 = Vector3(0.0, -0.065, 0.0)
		elif celula == C_POCA:
			sulco0 = Vector3(0.0, -0.028, 0.0)
			sulco1 = Vector3(0.0, -0.028, 0.0)""",
    "relief",
)

kit = replace_once(
    kit,
    """	quad(sup, M_LEITO, c - e - f, c + e - f, c + e + f, c - e + f,
		C_POCA, Color(0.55, 0.28, 0.18))""",
    """	quad(sup, M_LEITO, c - e - f, c + e - f, c + e + f, c - e + f,
		C_POCA, Color(0.42, 0.16, 0.10))""",
    "poca",
)

kit = replace_once(
    kit,
    """static func beira(sup: Dictionary, p: Vector3, lado: Vector3,
		rng: RandomNumberGenerator, quantos: int = 7) -> void:""",
    """static func beira(sup: Dictionary, p: Vector3, lado: Vector3,
		rng: RandomNumberGenerator, quantos: int = 14) -> void:""",
    "beira_default",
)

kit = replace_once(
    kit,
    """		var d := rng.randf_range(MEIA_PISTA - 0.7, MEIA_PISTA + 3.2)
		var onde := p + lado * (d * s) + lado.cross(Vector3.UP).normalized() * rng.randf_range(-0.55, 0.55)
		var celula: Vector2i = CELULAS[rng.randi() % CELULAS.size()]
		var tam := rng.randf_range(0.65, 1.55)""",
    """		var d := rng.randf_range(MEIA_PISTA - 0.85, MEIA_PISTA + 3.8)
		var onde := p + lado * (d * s) + lado.cross(Vector3.UP).normalized() * rng.randf_range(-0.7, 0.7)
		var celula: Vector2i = CELULAS[rng.randi() % CELULAS.size()]
		var tam := rng.randf_range(0.75, 1.85)""",
    "beira_spread",
)

kit = replace_once(
    kit,
    """	# Cordão principal (galho fino) — um pouco mais grosso pra silhueta no para-brisa.
	KitModular.caixa_cor(sup, M_CASCA, meio,
		Vector3(0.09, 0.09, comp * 0.95), Color("3d3228"), giro,
		PSXMesh.FACE_TODAS, 6.0)
	# Folhas/cipós pendurados densos — entram no topo do windshield (ref 04).
	for k in rng.randi_range(6, 9):
		var t := rng.randf_range(0.08, 0.95)
		var p := ancora.lerp(sobre_pista, t)
		var queda := rng.randf_range(1.3, 3.0)
		tufo(sup, p - Vector3(0.0, queda * 0.42, 0.0),
			C_GALHO_SECO if rng.randf() < 0.35 else C_FOLHA_LARGA,
			queda * 0.62, rng.randf_range(0.0, TAU), cor)
		if rng.randf() < 0.55:
			tufo(sup, p - Vector3(rng.randf_range(-0.35, 0.35), queda * 0.55, rng.randf_range(-0.25, 0.25)),
				C_SAMAMBAIA if rng.randf() < 0.5 else C_MOITA_BAIXA,
				queda * 0.4, rng.randf_range(0.0, TAU), cor.lerp(Color(0.35, 0.42, 0.22), 0.3))""",
    """	# Cordao principal — silhueta no para-brisa.
	KitModular.caixa_cor(sup, M_CASCA, meio,
		Vector3(0.11, 0.11, comp * 0.95), Color("3d3228"), giro,
		PSXMesh.FACE_TODAS, 6.0)
	# Folhas/cipos densos — caem BAIXO no windshield (ref 04 canopy).
	for k in rng.randi_range(8, 12):
		var t := rng.randf_range(0.05, 0.98)
		var p := ancora.lerp(sobre_pista, t)
		var queda := rng.randf_range(1.8, 3.6)
		tufo(sup, p - Vector3(0.0, queda * 0.48, 0.0),
			C_GALHO_SECO if rng.randf() < 0.30 else C_FOLHA_LARGA,
			queda * 0.72, rng.randf_range(0.0, TAU), cor)
		if rng.randf() < 0.7:
			tufo(sup, p - Vector3(rng.randf_range(-0.45, 0.45), queda * 0.62, rng.randf_range(-0.3, 0.3)),
				C_SAMAMBAIA if rng.randf() < 0.5 else C_MOITA_BAIXA,
				queda * 0.48, rng.randf_range(0.0, TAU), cor.lerp(Color(0.35, 0.42, 0.22), 0.3))""",
    "cipo",
)

# casa_beira — bigger / brighter for facho readability
kit = replace_once(
    kit,
    """static func casa_beira(sup: Dictionary, base: Vector3, giro: float,
		rng: RandomNumberGenerator) -> void:
	var larg := rng.randf_range(2.6, 3.4)
	var fund := rng.randf_range(2.1, 2.7)
	var alt := rng.randf_range(1.85, 2.35)
	# Madeira gasta clara — precisa pegar o facho (ref 04 casinha).
	var parede := Color(0.96, 0.92, 0.82).lerp(Color(0.84, 0.78, 0.66), rng.randf() * 0.35)
	var telha := Color(0.58, 0.30, 0.18).lerp(Color(0.40, 0.20, 0.12), rng.randf())
	var pedra := Color(0.48, 0.44, 0.38).lerp(Color(0.36, 0.40, 0.30), 0.35)
	# Base de alvenaria / pedra (ref 04) — eleva e ancora a casinha.
	var h_base := 0.42""",
    """static func casa_beira(sup: Dictionary, base: Vector3, giro: float,
		rng: RandomNumberGenerator) -> void:
	var larg := rng.randf_range(3.0, 3.8)
	var fund := rng.randf_range(2.3, 2.9)
	var alt := rng.randf_range(2.05, 2.55)
	# Madeira gasta CLARA — precisa pegar o facho (ref 04 casinha).
	var parede := Color(1.0, 0.96, 0.88).lerp(Color(0.90, 0.84, 0.72), rng.randf() * 0.25)
	var telha := Color(0.62, 0.32, 0.18).lerp(Color(0.42, 0.22, 0.12), rng.randf())
	var pedra := Color(0.55, 0.50, 0.42).lerp(Color(0.40, 0.44, 0.34), 0.3)
	# Base de alvenaria / pedra (ref 04) — eleva e ancora a casinha.
	var h_base := 0.52""",
    "casa",
)

kit_path.write_text(kit, encoding="utf-8")
print("kit_estrada.gd OK")

# --- estrada_builder.gd -----------------------------------------------------
b_path = ROOT / "game/src/world/estrada_builder.gd"
b = b_path.read_text(encoding="utf-8")
Path("_box_stage/estrada_builder.gd.bak").write_text(b, encoding="utf-8")

b = replace_once(
    b,
    """		KitEstrada.beira(sup, pa, la, rng, 12)""",
    """		KitEstrada.beira(sup, pa, la, rng, 18)""",
    "builder_beira",
)

b = replace_once(
    b,
    """	for _i in 48:""",
    """	for _i in 64:""",
    "builder_trees",
)

b = replace_once(
    b,
    """	# A parede do fundo: massa de folha a partir de vinte metros, os dois lados.
	for _i in 20:""",
    """	# A parede do fundo: massa de folha a partir de vinte metros, os dois lados.
	for _i in 28:""",
    "builder_massa",
)

b = replace_once(
    b,
    """	# Cipós / galhos pendurados cruzando a pista — densidade da ref 04.
	var n_cipo := 5 if ancora_captura else (3 if rng.randf() < 0.75 else 1)
	for _i in n_cipo:
		var s := s0 + rng.randf_range(0.5, TRECHO - 0.5)
		var lado := 1.0 if rng.randf() < 0.5 else -1.0
		var ancora := ponto_em(s) + lado_em(s) * (lado * rng.randf_range(3.0, 5.5))
		ancora.y += altura_lateral(4.0) + rng.randf_range(2.8, 5.2)
		var sobre := ponto_em(s + rng.randf_range(-1.2, 1.2)) + lado_em(s) * (lado * rng.randf_range(-1.0, 0.6))
		sobre.y += rng.randf_range(1.9, 3.4)
		KitEstrada.cipo(sup, ancora, sobre, rng)""",
    """	# Cipos / galhos pendurados cruzando a pista — densidade da ref 04.
	var n_cipo := 8 if ancora_captura else (5 if rng.randf() < 0.8 else 2)
	for _i in n_cipo:
		var s := s0 + rng.randf_range(0.5, TRECHO - 0.5)
		var lado := 1.0 if rng.randf() < 0.5 else -1.0
		var ancora := ponto_em(s) + lado_em(s) * (lado * rng.randf_range(2.8, 5.2))
		ancora.y += altura_lateral(4.0) + rng.randf_range(2.4, 4.6)
		var sobre := ponto_em(s + rng.randf_range(-1.2, 1.2)) + lado_em(s) * (lado * rng.randf_range(-1.2, 0.4))
		sobre.y += rng.randf_range(1.55, 2.75)
		KitEstrada.cipo(sup, ancora, sobre, rng)""",
    "builder_cipo",
)

# Replace spawn_olhos entirely — subtle or nearly invisible
old_olhos = """## Olhos vermelhos na nevoa a frente do carro (beat de horror da ref 04).
## Chamado pela AberturaEstrada na captura / noite.
func spawn_olhos_nevoa(s_carro: float, frente: float = 28.0) -> void:
	var velho := get_node_or_null(\"OlhosNevoa\")
	if velho != null:
		velho.queue_free()
	var raiz := Node3D.new()
	raiz.name = \"OlhosNevoa\"
	# Um pouco mais perto + levemente a direita da pista: legivel no FP e
	# ainda um ponto vermelho no TP atras do carro.
	var s := s_carro + maxf(18.0, frente * 0.85)
	var p := ponto_em(s) + lado_em(s) * 0.25
	var dir := direcao_em(s)
	p += Vector3(0.0, 1.25, 0.0)
	raiz.position = p
	add_child(raiz)
	for sx: float in [-0.2, 0.2]:
		# Sem OmniLight forte: bloom do emission ja basta e Omni alto
		# virava bolhao vermelho no FP (lavava a casinha do facho).
		var mi := MeshInstance3D.new()
		var esfera := SphereMesh.new()
		esfera.radius = 0.09
		esfera.height = 0.18
		esfera.radial_segments = 6
		esfera.rings = 3
		mi.mesh = esfera
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.08, 0.02)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.04, 0.0)
		mat.emission_energy_multiplier = 3.8
		mi.material_override = mat
		mi.position = Vector3(sx, 0.0, 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(mi)
	# Face o carro (olhos olhando de frente).
	raiz.basis = Basis.looking_at(-dir, Vector3.UP)"""

new_olhos = """## Olhos vermelhos SUTIS no fundo da nevoa (ref 04).
## Bolhao vermelho confunde o facho — longe + minúsculo + emission baixa.
func spawn_olhos_nevoa(s_carro: float, frente: float = 28.0) -> void:
	var velho := get_node_or_null(\"OlhosNevoa\")
	if velho != null:
		velho.queue_free()
	var raiz := Node3D.new()
	raiz.name = \"OlhosNevoa\"
	# Fundo da nevoa (~38 m): dois pontos, nao bolhas. Fora do cone util do facho.
	var s := s_carro + maxf(36.0, frente * 1.45)
	var p := ponto_em(s) + lado_em(s) * 0.15
	var dir := direcao_em(s)
	p += Vector3(0.0, 1.35, 0.0)
	raiz.position = p
	add_child(raiz)
	for sx: float in [-0.11, 0.11]:
		var mi := MeshInstance3D.new()
		var esfera := SphereMesh.new()
		esfera.radius = 0.035
		esfera.height = 0.07
		esfera.radial_segments = 5
		esfera.rings = 2
		mi.mesh = esfera
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.55, 0.04, 0.02)
		mat.emission_enabled = true
		mat.emission = Color(0.7, 0.05, 0.0)
		mat.emission_energy_multiplier = 1.15
		mi.material_override = mat
		mi.position = Vector3(sx, 0.0, 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(mi)
	raiz.basis = Basis.looking_at(-dir, Vector3.UP)"""

b = replace_once(b, old_olhos, new_olhos, "olhos")

# garantir_props_facho — house closer / denser canopy
old_props = """	# Casa DENTRO do cone: ~7–9 m a frente, rente a beira direita.
	var s := s_carro + 9.5
	var d_casa := KitEstrada.MEIA_PISTA + 1.25
	var base := ponto_em(s) + lado_em(s) * d_casa
	base.y += altura_lateral(d_casa)
	# Fachada olhando a pista (nao o mato).
	var giro := atan2(direcao_em(s).x, direcao_em(s).z) + PI * 0.5
	KitEstrada.casa_beira(sup, base, giro, rng)
	# Cerca a direita, entre o carro e a casa — no facho.
	var d_c := KitEstrada.MEIA_PISTA + 0.85
	var a := ponto_em(s - 3.5) + lado_em(s - 3.5) * d_c
	var b := ponto_em(s + 7.0) + lado_em(s + 7.0) * d_c
	a.y += altura_lateral(d_c)
	b.y += altura_lateral(d_c)
	KitEstrada.cerca(sup, a, b, rng)
	# Segundo tramo curto colado na casa (ref 04: cerca + casinha).
	var a2 := ponto_em(s - 0.5) + lado_em(s - 0.5) * (d_casa - 0.35)
	var b2 := ponto_em(s + 4.5) + lado_em(s + 4.5) * (d_casa - 0.35)
	a2.y += altura_lateral(d_casa - 0.35)
	b2.y += altura_lateral(d_casa - 0.35)
	KitEstrada.cerca(sup, a2, b2, rng)
	# Muro baixo a esquerda (contraste no facho esquerdo).
	var d_m := -(KitEstrada.MEIA_PISTA + 0.85)
	var m0 := ponto_em(s - 2.0) + lado_em(s - 2.0) * d_m
	var m1 := ponto_em(s + 6.0) + lado_em(s + 6.0) * d_m
	m0.y += altura_lateral(absf(d_m))
	m1.y += altura_lateral(absf(d_m))
	KitEstrada.muro_baixo(sup, m0, m1, rng)
	# Cipós baixos cruzando o para-brisa (y ~2.0–2.8 no eixo).
	for i in 6:
		var sc := s_carro + 2.5 + float(i) * 2.2
		var lado := 1.0 if i % 2 == 0 else -1.0
		var ancora := ponto_em(sc) + lado_em(sc) * (lado * rng.randf_range(3.2, 4.8))
		ancora.y += altura_lateral(4.0) + rng.randf_range(2.6, 4.2)
		var sobre := ponto_em(sc + rng.randf_range(-0.8, 0.8)) + lado_em(sc) * (lado * rng.randf_range(-1.2, 0.4))
		sobre.y += rng.randf_range(1.85, 2.85)
		KitEstrada.cipo(sup, ancora, sobre, rng)
	# Brush densificado na beira — mesma densidade FP/TP no cone.
	for i in 18:"""

new_props = """	# Casa EXPLICITA no cone direito: ~7 m a frente, rente a beira (ref 04).
	var s := s_carro + 7.2
	var d_casa := KitEstrada.MEIA_PISTA + 0.95
	var base := ponto_em(s) + lado_em(s) * d_casa
	base.y += altura_lateral(d_casa)
	# Fachada olhando a pista (nao o mato).
	var giro := atan2(direcao_em(s).x, direcao_em(s).z) + PI * 0.5
	KitEstrada.casa_beira(sup, base, giro, rng)
	# Cerca a direita, entre o carro e a casa — no facho.
	var d_c := KitEstrada.MEIA_PISTA + 0.7
	var a := ponto_em(s - 4.0) + lado_em(s - 4.0) * d_c
	var b := ponto_em(s + 6.5) + lado_em(s + 6.5) * d_c
	a.y += altura_lateral(d_c)
	b.y += altura_lateral(d_c)
	KitEstrada.cerca(sup, a, b, rng)
	# Segundo tramo curto colado na casa (ref 04: cerca + casinha).
	var a2 := ponto_em(s - 1.0) + lado_em(s - 1.0) * (d_casa - 0.25)
	var b2 := ponto_em(s + 5.0) + lado_em(s + 5.0) * (d_casa - 0.25)
	a2.y += altura_lateral(d_casa - 0.25)
	b2.y += altura_lateral(d_casa - 0.25)
	KitEstrada.cerca(sup, a2, b2, rng)
	# Muro baixo a esquerda (contraste no facho esquerdo).
	var d_m := -(KitEstrada.MEIA_PISTA + 0.75)
	var m0 := ponto_em(s - 2.0) + lado_em(s - 2.0) * d_m
	var m1 := ponto_em(s + 6.0) + lado_em(s + 6.0) * d_m
	m0.y += altura_lateral(absf(d_m))
	m1.y += altura_lateral(absf(d_m))
	KitEstrada.muro_baixo(sup, m0, m1, rng)
	# Canopy/cipos ENTRANDO no para-brisa (y baixo no eixo, ref 04).
	for i in 10:
		var sc := s_carro + 1.2 + float(i) * 1.55
		var lado := 1.0 if i % 2 == 0 else -1.0
		var ancora := ponto_em(sc) + lado_em(sc) * (lado * rng.randf_range(2.6, 4.4))
		ancora.y += altura_lateral(4.0) + rng.randf_range(2.2, 3.8)
		var sobre := ponto_em(sc + rng.randf_range(-0.6, 0.6)) + lado_em(sc) * (lado * rng.randf_range(-1.4, 0.2))
		sobre.y += rng.randf_range(1.45, 2.35)
		KitEstrada.cipo(sup, ancora, sobre, rng)
	# Brush densificado na beira — parede de mato no cone.
	for i in 28:"""

b = replace_once(b, old_props, new_props, "props_facho")

b = replace_once(
    b,
    """		var sb := s_carro + rng.randf_range(2.0, 14.0)
		var lado := 1.0 if rng.randf() < 0.58 else -1.0
		var d := rng.randf_range(KitEstrada.MEIA_PISTA - 0.35, KitEstrada.MEIA_PISTA + 1.8)
		var pp := ponto_em(sb) + lado_em(sb) * (d * lado)
		pp.y += altura_lateral(d)
		KitEstrada.tufo(sup, pp,
			[KitEstrada.C_CAPIM, KitEstrada.C_SAMAMBAIA, KitEstrada.C_MOITA_BAIXA,
				KitEstrada.C_FOLHA_LARGA, KitEstrada.C_GALHO_SECO][rng.randi() % 5],
			rng.randf_range(0.8, 1.6), rng.randf_range(0.0, TAU),
			Color(0.82, 0.88, 0.68))""",
    """		var sb := s_carro + rng.randf_range(1.5, 12.0)
		var lado := 1.0 if rng.randf() < 0.58 else -1.0
		var d := rng.randf_range(KitEstrada.MEIA_PISTA - 0.45, KitEstrada.MEIA_PISTA + 2.4)
		var pp := ponto_em(sb) + lado_em(sb) * (d * lado)
		pp.y += altura_lateral(d)
		KitEstrada.tufo(sup, pp,
			[KitEstrada.C_CAPIM, KitEstrada.C_SAMAMBAIA, KitEstrada.C_MOITA_BAIXA,
				KitEstrada.C_FOLHA_LARGA, KitEstrada.C_GALHO_SECO][rng.randi() % 5],
			rng.randf_range(0.95, 1.9), rng.randf_range(0.0, TAU),
			Color(0.78, 0.86, 0.62))""",
    "brush",
)

b_path.write_text(b, encoding="utf-8")
print("estrada_builder.gd OK")

# --- materials --------------------------------------------------------------
leito = (ROOT / "game/resources/materials/mat_leito.tres").read_text(encoding="utf-8")
leito2 = leito.replace(
    "shader_parameter/tint = Color(1, 1, 1, 1)",
    "shader_parameter/tint = Color(1.28, 0.58, 0.38, 1)",
)
if leito2 == leito:
    raise SystemExit("FAIL mat_leito tint")
(ROOT / "game/resources/materials/mat_leito.tres").write_text(leito2, encoding="utf-8")
print("mat_leito OK")

mato = (ROOT / "game/resources/materials/mat_mato.tres").read_text(encoding="utf-8")
mato2 = mato.replace(
    "shader_parameter/tint = Color(1, 1, 1, 1)",
    "shader_parameter/tint = Color(0.72, 0.86, 0.58, 1)",
)
if mato2 == mato:
    raise SystemExit("FAIL mat_mato tint")
(ROOT / "game/resources/materials/mat_mato.tres").write_text(mato2, encoding="utf-8")
print("mat_mato OK")

# --- fog noite --------------------------------------------------------------
fog = (ROOT / "game/resources/fog/fog_estrada_noite.tres").read_text(encoding="utf-8")
fog2 = fog.replace("fog_begin = 10.0", "fog_begin = 14.0")
fog2 = fog2.replace("fog_end = 48.0", "fog_end = 54.0")
fog2 = fog2.replace("facho_forca = 1.15", "facho_forca = 1.35")
fog2 = fog2.replace("ambient_energy = 0.32", "ambient_energy = 0.38")
if fog2 == fog:
    raise SystemExit("FAIL fog noite")
(ROOT / "game/resources/fog/fog_estrada_noite.tres").write_text(fog2, encoding="utf-8")
print("fog_noite OK")
print("ALL PATCHES APPLIED")
