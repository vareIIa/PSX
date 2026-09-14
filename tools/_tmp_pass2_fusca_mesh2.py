# -*- coding: utf-8 -*-
from pathlib import Path

path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\render\carroceria.gd")
text = path.read_text(encoding="utf-8")
vid_before = text[text.index("static func _vidros"): text.index("static func _frente_e_tras")]

# Ensure medidas/tint
old_med = '\tModelo.FUSCA:  {"c": 3.78, "l": 1.50, "capo": 0.74, "teto": 1.50, "eixo": 2.10, "cabine": 0.48},'
new_med = '\tModelo.FUSCA:  {"c": 3.70, "l": 1.52, "capo": 0.72, "teto": 1.52, "eixo": 2.05, "cabine": 0.50},'
if old_med in text:
    text = text.replace(old_med, new_med, 1)
old_tint = "const TINTA_FUSCA := Color(0.82, 0.76, 0.64)"
new_tint = "const TINTA_FUSCA := Color(0.78, 0.72, 0.58)"
if old_tint in text:
    text = text.replace(old_tint, new_tint, 1)

new_lataria = r'''## Fusca: silhueta de besouro em caixas PSX (refs PRINTS/ref_fusca).
##
## PASS 2 — prioriza LEITURA LATERAL (ref_01): teto em cupula continua,
## para-lamas bulbous altos com vale na porta, capo curto, deck do motor.
## Sujeira densa em baixo / arcos (nao creme limpo). Cabine z0/recuo = _vidros.
## Sem mexer em _vidros nem Marea.
static func _lataria_fusca(dados: Dictionary, comp: float, larg: float, capo: float,
		teto: float, cabine: float, cor: Color) -> void:
	var suja := C_LATARIA_SUJA
	var ferrugem := Color(cor.r * 0.48, cor.g * 0.28, cor.b * 0.14)
	var ferrugem_clara := Color(cor.r * 0.62, cor.g * 0.42, cor.b * 0.24)
	var ferrugem_escura := Color(cor.r * 0.36, cor.g * 0.20, cor.b * 0.10)
	var chrome := Color(0.74, 0.74, 0.76)
	var altura_casco := capo - ASSOALHO

	# Barriga baixa continua — atlas SUJA (peso de terra/ferrugem nas refs).
	_caixa(dados, Vector3(larg * 0.84, altura_casco * 0.48, comp * 0.90),
		Vector3(0.0, ASSOALHO + altura_casco * 0.26, 0.0), ferrugem_clara,
		suja, suja, suja, true)

	# Faixa media da porta (CREME) — mais BAIXA que o topo dos para-lamas.
	_caixa(dados, Vector3(larg * 0.88, altura_casco * 0.36, comp * 0.30),
		Vector3(0.0, ASSOALHO + altura_casco * 0.62, 0.0), cor,
		suja, suja, C_CAPO, false)

	# Capo CURTO caindo (volume estreito + placa inclinada).
	_caixa(dados, Vector3(larg * 0.62, altura_casco * 0.30, comp * 0.18),
		Vector3(0.0, ASSOALHO + altura_casco * 0.58, comp * 0.36), cor,
		suja, C_CAPO, C_CAPO, false)
	_face(dados, Vector2(larg * 0.60, comp * 0.22),
		Transform3D(Basis(Vector3.RIGHT, -0.72),
			Vector3(0.0, capo - 0.06, comp * 0.34)), cor, C_CAPO)
	# Crista central do capo (ref_03).
	_face(dados, Vector2(0.10, comp * 0.18),
		Transform3D(Basis(Vector3.RIGHT, -0.72),
			Vector3(0.0, capo - 0.02, comp * 0.33)),
		Color(cor.r * 0.92, cor.g * 0.90, cor.b * 0.86), C_CAPO)

	# Deck do motor — continua a curva do teto para tras.
	_caixa(dados, Vector3(larg * 0.66, altura_casco * 0.34, comp * 0.20),
		Vector3(0.0, ASSOALHO + altura_casco * 0.60, -comp * 0.36), cor,
		suja, C_TRASEIRA, C_TRASEIRA, false)
	_face(dados, Vector2(larg * 0.64, comp * 0.22),
		Transform3D(Basis(Vector3.RIGHT, -2.35),
			Vector3(0.0, capo - 0.04, -comp * 0.34)), cor, C_TRASEIRA)

	# Para-lamas BULBOUS: base enferrujada densa + corpo creme alto + ombro.
	var fl_top := ASSOALHO + altura_casco * 0.92
	for s: float in [1.0, -1.0]:
		var sx := s * (larg * 0.54)
		# dianteiro
		_caixa(dados, Vector3(0.44, altura_casco * 0.92, 0.56),
			Vector3(sx, ASSOALHO + altura_casco * 0.50, comp * 0.30), cor,
			suja, suja, C_CAPO, false)
		_caixa(dados, Vector3(0.34, altura_casco * 0.48, 0.38),
			Vector3(sx + s * 0.06, fl_top - 0.10, comp * 0.30), cor,
			suja, suja, C_CAPO, false)
		_caixa(dados, Vector3(0.40, altura_casco * 0.46, 0.48),
			Vector3(sx, ASSOALHO + altura_casco * 0.26, comp * 0.30), ferrugem,
			suja, suja, suja, false)
		_caixa(dados, Vector3(0.36, altura_casco * 0.22, 0.42),
			Vector3(sx, ASSOALHO + altura_casco * 0.12, comp * 0.30), ferrugem_escura,
			suja, suja, suja, false)
		# traseiro
		_caixa(dados, Vector3(0.46, altura_casco * 0.96, 0.60),
			Vector3(sx, ASSOALHO + altura_casco * 0.52, -comp * 0.30), cor,
			suja, suja, C_TRASEIRA, false)
		_caixa(dados, Vector3(0.36, altura_casco * 0.50, 0.40),
			Vector3(sx + s * 0.06, fl_top - 0.08, -comp * 0.30), cor,
			suja, suja, C_TRASEIRA, false)
		_caixa(dados, Vector3(0.42, altura_casco * 0.48, 0.52),
			Vector3(sx, ASSOALHO + altura_casco * 0.26, -comp * 0.30), ferrugem,
			suja, suja, suja, false)
		_caixa(dados, Vector3(0.38, altura_casco * 0.22, 0.46),
			Vector3(sx, ASSOALHO + altura_casco * 0.12, -comp * 0.30), ferrugem_escura,
			suja, suja, suja, false)
		_face(dados, Vector2(comp * 0.34, 0.12),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.50), ASSOALHO + 0.05, 0.0)),
			ferrugem_escura, C_SOLEIRA)
		_face(dados, Vector2(comp * 0.28, 0.028),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.45), capo - 0.22, 0.0)),
			chrome, C_PARACHOQUE)
		_face(dados, Vector2(0.40, 0.24),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.445), ASSOALHO + 0.28, 0.0)),
			ferrugem, suja)
		_face(dados, Vector2(0.28, 0.16),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.448), ASSOALHO + 0.48, comp * 0.06)),
			ferrugem_clara, suja)

	# Arco lateral facetado = semicirculo PSX legivel de lado.
	for s: float in [1.0, -1.0]:
		var sx2 := s * (larg * 0.56 + 0.01)
		var basis_lado := Basis(Vector3.UP, s * PI * 0.5)
		for z_arco: float in [comp * 0.30, -comp * 0.30]:
			_face(dados, Vector2(0.40, altura_casco * 0.42),
				Transform3D(basis_lado, Vector3(sx2, ASSOALHO + altura_casco * 0.30, z_arco)),
				ferrugem, suja)
			_face(dados, Vector2(0.38, altura_casco * 0.36),
				Transform3D(basis_lado, Vector3(sx2, ASSOALHO + altura_casco * 0.58, z_arco)),
				cor, suja)
			_face(dados, Vector2(0.32, altura_casco * 0.30),
				Transform3D(basis_lado * Basis(Vector3.RIGHT, -0.62),
					Vector3(sx2 + s * 0.03, ASSOALHO + altura_casco * 0.82, z_arco)),
				cor, suja)
			_face(dados, Vector2(0.30, 0.20),
				Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
					Vector3(s * (larg * 0.54), ASSOALHO + altura_casco * 0.98, z_arco)),
				cor, C_CAPO)
			var ang_edge := -0.35 if z_arco > 0.0 else 0.35
			var z_edge := z_arco + (0.22 if z_arco > 0.0 else -0.22)
			_face(dados, Vector2(0.26, altura_casco * 0.55),
				Transform3D(basis_lado * Basis(Vector3.UP, s * ang_edge),
					Vector3(sx2 - s * 0.02, ASSOALHO + altura_casco * 0.50, z_edge)),
				cor, suja)

	# Cabine alinhada ao _vidros (P0) — NAO alterar z0/recuo.
	var comp_cabine := comp * cabine
	var z0 := -comp * 0.06 - comp_cabine * 0.5
	var z1 := z0 + comp_cabine
	var alt_cabine := teto - capo
	var recuo := alt_cabine * 0.55
	var lc := larg - RECUO_CABINE * 0.90
	var h := lc * 0.5
	var z_mid := (z0 + z1) * 0.5

	var teto_comp := maxf(0.22, comp_cabine - recuo * 1.70)
	_face(dados, Vector2(lc * 0.88, teto_comp),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
			Vector3(0.0, teto, z_mid)), cor, C_TETO)
	_face(dados, Vector2(lc * 0.84, recuo * 1.15),
		Transform3D(Basis(Vector3.RIGHT, -0.95),
			Vector3(0.0, teto - 0.02, z1 - recuo * 0.42)), cor, C_TETO)
	_face(dados, Vector2(lc * 0.84, recuo * 1.20),
		Transform3D(Basis(Vector3.RIGHT, -2.20),
			Vector3(0.0, teto - 0.02, z0 + recuo * 0.42)), cor, C_TETO)
	for s: float in [1.0, -1.0]:
		var teto_basis := Basis(Vector3.FORWARD, s * 0.55) * Basis(Vector3.RIGHT, -PI * 0.5)
		_face(dados, Vector2(teto_comp * 0.90, 0.16),
			Transform3D(teto_basis, Vector3(s * lc * 0.42, teto - 0.04, z_mid)), cor, C_TETO)

	for s: float in [1.0, -1.0]:
		var fora := Vector3(s, 0.0, 0.0)
		var a := Vector3(s * h, capo, z0)
		var b := Vector3(s * h, capo, z1)
		var c := Vector3(s * h * 0.93, teto, z1 - recuo)
		var d := Vector3(s * h * 0.93, teto, z0 + recuo)
		PSXMesh.acumular(dados,
			_quad_lateral(a, b, c, d, suja, cor, fora), Transform3D.IDENTITY)
		var desloca := fora * 0.009
		PSXMesh.acumular(dados,
			_quad_lateral(
				_encolher(a, b, c, d, 0) + desloca,
				_encolher(a, b, c, d, 1) + desloca,
				_encolher(a, b, c, d, 2) + desloca,
				_encolher(a, b, c, d, 3) + desloca,
				C_VIDRO_LADO, VIDRO, fora), Transform3D.IDENTITY)

	_caixa(dados, Vector3(0.06, 0.05, 0.10),
		Vector3(larg * 0.36, capo + alt_cabine * 0.38, z1 - 0.02),
		Color(0.34, 0.34, 0.36), C_PARACHOQUE, C_PARACHOQUE, C_PARACHOQUE, false)


'''

new_frente = r'''## Frente/traseira do Fusca: farol redondo nos para-lamas, venezianas no deck,
## lanterna bipartida e overriders (refs). PASS 2 — farol 3D legivel + para-choque.
static func _frente_e_tras_fusca(dados: Dictionary, luzes: Dictionary, comp: float,
		larg: float, capo: float, _cor: Color) -> void:
	var zf := comp * 0.5 + 0.005
	var zt := -comp * 0.5 - 0.005
	var y := ASSOALHO + (capo - ASSOALHO) * 0.55
	var ferrugem := Color(0.42, 0.26, 0.14)

	_face(dados, Vector2(larg * 0.28, 0.08),
		Transform3D(Basis(), Vector3(0.0, y - 0.10, zf)),
		Color(0.18, 0.18, 0.20), C_GRADE)

	for z: float in [zf, zt]:
		var frente := z > 0.0
		var basis := Basis(Vector3.UP, 0.0 if frente else PI)
		_face(dados, Vector2(larg * 0.50, 0.09),
			Transform3D(basis, Vector3(0.0, ASSOALHO + 0.10, z)),
			Color(0.60, 0.60, 0.62), C_PARACHOQUE)
		for s: float in [1.0, -1.0]:
			var yaw := s * 0.28
			var z_off := 0.04 if frente else -0.04
			_face(dados, Vector2(larg * 0.22, 0.085),
				Transform3D(basis * Basis(Vector3.UP, yaw),
					Vector3(s * larg * 0.34, ASSOALHO + 0.11, z + z_off)),
				Color(0.58, 0.58, 0.60), C_PARACHOQUE)
			var z_ov := 0.014 if frente else -0.014
			_face(dados, Vector2(0.050, 0.22),
				Transform3D(basis, Vector3(s * larg * 0.18, ASSOALHO + 0.18, z + z_ov)),
				Color(0.70, 0.70, 0.72), C_PARACHOQUE)
			var z_fe := 0.02 if frente else -0.02
			_face(dados, Vector2(0.16, 0.10),
				Transform3D(basis, Vector3(s * larg * 0.38, ASSOALHO + 0.06, z + z_fe)),
				ferrugem, C_LATARIA_SUJA)
		var z_pl := 0.006 if frente else -0.006
		_face(dados, Vector2(0.22, 0.08),
			Transform3D(basis, Vector3(0.0, ASSOALHO + 0.22, z + z_pl)),
			Color(0.80, 0.80, 0.82), C_PLACA)

	var ox := larg * 0.46
	var yf := y + 0.06
	for s: float in [1.0, -1.0]:
		_caixa(dados, Vector3(0.22, 0.22, 0.10),
			Vector3(s * ox, yf, zf - 0.02), Color(0.16, 0.16, 0.18),
			C_GRADE, C_GRADE, C_GRADE, false)
		_face(dados, Vector2(0.30, 0.30),
			Transform3D(Basis(), Vector3(s * ox, yf, zf + 0.012)),
			Color(0.12, 0.12, 0.14), C_GRADE)
		_face(dados, Vector2(0.24, 0.24),
			Transform3D(Basis(Vector3.FORWARD, PI * 0.25),
				Vector3(s * ox, yf, zf + 0.014)),
			Color(0.18, 0.18, 0.20), C_GRADE)
		_face(dados, Vector2(0.20, 0.20),
			Transform3D(Basis(Vector3.FORWARD, PI * 0.125),
				Vector3(s * ox, yf, zf + 0.016)),
			Color(0.22, 0.22, 0.24), C_GRADE)
		_face(luzes, Vector2(0.16, 0.16),
			Transform3D(Basis(), Vector3(s * ox, yf, zf + 0.022)),
			Color.WHITE, C_FAROL)
		_face(luzes, Vector2(0.08, 0.08),
			Transform3D(Basis(), Vector3(s * ox, yf, zf + 0.026)),
			Color(0.95, 0.95, 0.85), C_FAROL)
		_face(luzes, Vector2(0.10, 0.055),
			Transform3D(Basis(), Vector3(s * ox, yf + 0.18, zf - 0.06)),
			Color(1.0, 0.68, 0.16), C_PISCA)
		_face(luzes, Vector2(0.11, 0.06),
			Transform3D(Basis(Vector3.UP, PI), Vector3(s * ox, y + 0.18, zt - 0.012)),
			Color(1.0, 0.50, 0.12), C_LANTERNA)
		_face(luzes, Vector2(0.11, 0.08),
			Transform3D(Basis(Vector3.UP, PI), Vector3(s * ox, y + 0.08, zt - 0.012)),
			Color.WHITE, C_FREIO)

	for k in 3:
		var yy := capo - 0.02 + float(k) * 0.045
		_face(dados, Vector2(larg * 0.46, 0.030),
			Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, yy, zt + 0.18)),
			Color(0.12, 0.12, 0.14), C_GRADE)
	for s: float in [1.0, -1.0]:
		_face(dados, Vector2(larg * 0.15, 0.026),
			Transform3D(Basis(Vector3.UP, PI),
				Vector3(s * larg * 0.24, capo - 0.06, zt + 0.16)),
			Color(0.12, 0.12, 0.14), C_GRADE)

	_face(dados, Vector2(0.07, 0.045),
		Transform3D(Basis(Vector3.UP, PI), Vector3(-larg * 0.16, ASSOALHO + 0.05, zt - 0.02)),
		Color(0.24, 0.24, 0.25), C_PARACHOQUE)
	_face(dados, Vector2(0.09, 0.035),
		Transform3D(Basis(Vector3.UP, PI * 0.5),
			Vector3(larg * 0.45, capo - 0.12, 0.02)),
		Color(0.20, 0.20, 0.22), C_PARACHOQUE)


'''

def replace_named_func(src: str, func_name: str, new_block: str) -> str:
    needle = f"static func {func_name}("
    idx = src.index(needle)
    # Walk back over contiguous ## comment lines
    line_start = src.rfind("\n", 0, idx) + 1
    start = line_start
    while start > 0:
        prev = src.rfind("\n", 0, start - 1) + 1
        line = src[prev:start]
        if line.startswith("##"):
            start = prev
        else:
            break
    # End = next top-level static func AFTER this one
    next_idx = src.index("\nstatic func ", idx + len(needle))
    end = next_idx + 1  # keep leading newline of next func out; include up to before it
    # Trim trailing ## comments that belong to the next function
    body = src[start:end]
    lines = body.splitlines(keepends=True)
    while lines and (lines[-1].startswith("##") or lines[-1].strip() == ""):
        # Don't strip the final newline-only if it's the separator — keep one blank
        if lines[-1].startswith("##"):
            lines.pop()
        else:
            break
    # Ensure new_block ends with blank line
    if not new_block.endswith("\n\n"):
        if new_block.endswith("\n"):
            new_block += "\n"
        else:
            new_block += "\n\n"
    return src[:start] + new_block + src[end:]

text = replace_named_func(text, "_lataria_fusca", new_lataria)
text = replace_named_func(text, "_frente_e_tras_fusca", new_frente)

vid_after = text[text.index("static func _vidros"): text.index("static func _frente_e_tras")]
assert vid_after == vid_before, "_vidros changed!"
assert "static func _frente_e_tras_marea" in text
assert "ferrugem_escura" in text
assert "_caixa(dados, Vector3(0.22, 0.22, 0.10)" in text
assert text.count("static func _lataria_fusca") == 1
assert text.count("static func _frente_e_tras_fusca") == 1

path.write_text(text, encoding="utf-8")
print("OK size", path.stat().st_size)
# show start of body
a = text.index("static func _lataria_fusca")
print(text[a:a+400])
