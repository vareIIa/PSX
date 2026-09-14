# -*- coding: utf-8 -*-
from pathlib import Path

path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\render\carroceria.gd")
text = path.read_text(encoding="utf-8")

# --- MEDIDAS: besouro mais curto / teto mais alto / eixo curto ---
old_med = '\tModelo.FUSCA:  {"c": 4.02, "l": 1.54, "capo": 0.84, "teto": 1.50, "eixo": 2.40, "cabine": 0.42},'
new_med = '\tModelo.FUSCA:  {"c": 3.90, "l": 1.52, "capo": 0.78, "teto": 1.52, "eixo": 2.22, "cabine": 0.46},'
if old_med not in text:
    raise SystemExit("MEDIDAS FUSCA line not found")
text = text.replace(old_med, new_med, 1)

# Slightly dirtier rusty off-white (closer to refs)
old_tint = "const TINTA_FUSCA := Color(0.78, 0.72, 0.62)"
new_tint = "const TINTA_FUSCA := Color(0.82, 0.76, 0.64)"
if old_tint not in text:
    raise SystemExit("TINTA_FUSCA not found")
text = text.replace(old_tint, new_tint, 1)

new_block = r'''## Fusca: silhueta de besouro em caixas PSX (refs PRINTS/ref_fusca).
##
## Casco curto + para-lamas facetados + teto em cupula + capo/deck inclinados.
## Cabine z0/recuo alinhados com _vidros para o para-brisa P0 (face unica + tint)
## assentar. Sem _face_dois_lados no para-brisa. Sem mexer em Marea.
static func _lataria_fusca(dados: Dictionary, comp: float, larg: float, capo: float,
		teto: float, cabine: float, cor: Color) -> void:
	var suja := C_LATARIA_SUJA
	var ferrugem := Color(cor.r * 0.62, cor.g * 0.40, cor.b * 0.24)
	var ferrugem_clara := Color(cor.r * 0.78, cor.g * 0.58, cor.b * 0.38)
	var chrome := Color(0.72, 0.72, 0.74)
	var altura_casco := capo - ASSOALHO

	# Casco em tres volumes: frente baixa, meio, traseira do motor — evita caixa
	# unica de sedan.
	_caixa(dados, Vector3(larg * 0.88, altura_casco * 0.82, comp * 0.30),
		Vector3(0.0, ASSOALHO + altura_casco * 0.44, comp * 0.26), cor,
		suja, C_CAPO, C_CAPO, true)
	_caixa(dados, Vector3(larg * 0.94, altura_casco * 0.95, comp * 0.42),
		Vector3(0.0, ASSOALHO + altura_casco * 0.50, 0.0), cor,
		suja, C_TRASEIRA, C_CAPO, true)
	_caixa(dados, Vector3(larg * 0.90, altura_casco * 0.88, comp * 0.30),
		Vector3(0.0, ASSOALHO + altura_casco * 0.48, -comp * 0.26), cor,
		suja, C_TRASEIRA, C_TRASEIRA, true)

	# Capo curto arredondado: caixa + placa inclinada colada no volume.
	_caixa(dados, Vector3(larg * 0.70, altura_casco * 0.38, comp * 0.16),
		Vector3(0.0, ASSOALHO + altura_casco * 0.70, comp * 0.38), cor,
		suja, C_CAPO, C_CAPO, false)
	_face(dados, Vector2(larg * 0.68, comp * 0.15),
		Transform3D(Basis(Vector3.RIGHT, -0.48),
			Vector3(0.0, capo - 0.01, comp * 0.36)), cor, C_CAPO)

	# Deck do motor (traseira alta caindo ate o para-choque).
	_caixa(dados, Vector3(larg * 0.72, altura_casco * 0.46, comp * 0.18),
		Vector3(0.0, ASSOALHO + altura_casco * 0.72, -comp * 0.36), cor,
		suja, C_TRASEIRA, C_TRASEIRA, false)
	_face(dados, Vector2(larg * 0.70, comp * 0.15),
		Transform3D(Basis(Vector3.RIGHT, -2.55),
			Vector3(0.0, capo + 0.02, -comp * 0.34)), cor, C_TRASEIRA)

	# Para-lamas facetados (3 caixas = arco bulbous a 480p, sem flutuacao).
	var fl_y := ASSOALHO + altura_casco * 0.40
	for s: float in [1.0, -1.0]:
		var sx := s * (larg * 0.50)
		# Frente: arco baixo / meio / alto.
		_caixa(dados, Vector3(0.28, altura_casco * 0.55, 0.34),
			Vector3(sx, fl_y - 0.04, comp * 0.30), ferrugem,
			suja, suja, C_CAPO, false)
		_caixa(dados, Vector3(0.32, altura_casco * 0.72, 0.28),
			Vector3(sx + s * 0.02, fl_y + 0.04, comp * 0.28), ferrugem_clara,
			suja, suja, C_CAPO, false)
		_caixa(dados, Vector3(0.24, altura_casco * 0.42, 0.22),
			Vector3(sx, fl_y + 0.10, comp * 0.22), ferrugem,
			suja, suja, C_CAPO, false)
		# Tras.
		_caixa(dados, Vector3(0.30, altura_casco * 0.58, 0.36),
			Vector3(sx, fl_y - 0.03, -comp * 0.30), ferrugem,
			suja, suja, C_TRASEIRA, false)
		_caixa(dados, Vector3(0.34, altura_casco * 0.76, 0.30),
			Vector3(sx + s * 0.02, fl_y + 0.05, -comp * 0.28), ferrugem_clara,
			suja, suja, C_TRASEIRA, false)
		_caixa(dados, Vector3(0.26, altura_casco * 0.44, 0.24),
			Vector3(sx, fl_y + 0.11, -comp * 0.22), ferrugem,
			suja, suja, C_TRASEIRA, false)
		# Soleira enferrujada (running board).
		_face(dados, Vector2(comp * 0.36, 0.09),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.48), ASSOALHO + 0.05, 0.0)),
			ferrugem, C_SOLEIRA)
		# Friso cromado (faixa fina horizontal — vibe PSX das refs).
		_face(dados, Vector2(comp * 0.40, 0.035),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.475), capo - 0.12, 0.0)),
			chrome, C_PARACHOQUE)

	# Cabine: z0/recuo iguais ao _vidros para o para-brisa P0 assentar.
	var comp_cabine := comp * cabine
	var z0 := -comp * 0.06 - comp_cabine * 0.5
	var z1 := z0 + comp_cabine
	var alt_cabine := teto - capo
	var recuo := alt_cabine * 0.55
	var lc := larg - RECUO_CABINE * 0.85
	var h := lc * 0.5
	var z_mid := (z0 + z1) * 0.5

	# Teto em cupula: tres placas (frente / topo / tras) coladas na cabine.
	var teto_comp := maxf(0.22, comp_cabine - recuo * 1.85)
	_face(dados, Vector2(lc * 0.92, teto_comp),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
			Vector3(0.0, teto, z_mid)), cor, C_TETO)
	_face(dados, Vector2(lc * 0.88, recuo * 0.95),
		Transform3D(Basis(Vector3.RIGHT, -0.92),
			Vector3(0.0, teto - 0.035, z1 - recuo * 0.48)), cor, C_TETO)
	_face(dados, Vector2(lc * 0.88, recuo * 0.95),
		Transform3D(Basis(Vector3.RIGHT, -2.22),
			Vector3(0.0, teto - 0.035, z0 + recuo * 0.48)), cor, C_TETO)

	for s: float in [1.0, -1.0]:
		var fora := Vector3(s, 0.0, 0.0)
		var a := Vector3(s * h, capo, z0)
		var b := Vector3(s * h, capo, z1)
		var c := Vector3(s * h * 0.94, teto, z1 - recuo)
		var d := Vector3(s * h * 0.94, teto, z0 + recuo)
		PSXMesh.acumular(dados,
			_quad_lateral(a, b, c, d, suja, cor, fora), Transform3D.IDENTITY)
		# Vidro lateral so para FORA (mesmo contrato P0 das laterais).
		var desloca := fora * 0.009
		PSXMesh.acumular(dados,
			_quad_lateral(
				_encolher(a, b, c, d, 0) + desloca,
				_encolher(a, b, c, d, 1) + desloca,
				_encolher(a, b, c, d, 2) + desloca,
				_encolher(a, b, c, d, 3) + desloca,
				C_VIDRO_LADO, VIDRO, fora), Transform3D.IDENTITY)

	# Manchas de ferrugem na porta / quina do para-lama.
	for s: float in [1.0, -1.0]:
		_face(dados, Vector2(0.42, 0.22),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.46), ASSOALHO + 0.30, -0.05)),
			ferrugem, suja)
		_face(dados, Vector2(0.28, 0.16),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.47), ASSOALHO + 0.36, comp * 0.18)),
			ferrugem_clara, suja)

	# Retrovisor angular.
	_caixa(dados, Vector3(0.06, 0.05, 0.10),
		Vector3(larg * 0.38, capo + alt_cabine * 0.40, z1 - 0.03),
		Color(0.34, 0.34, 0.36), C_PARACHOQUE, C_PARACHOQUE, C_PARACHOQUE, false)


## Frente/traseira do Fusca: farol redondo, venezianas no deck, lanterna
## bipartida e para-choque com overriders (refs traseira/frente).
static func _frente_e_tras_fusca(dados: Dictionary, luzes: Dictionary, comp: float,
		larg: float, capo: float, _cor: Color) -> void:
	var zf := comp * 0.5 + 0.005
	var zt := -comp * 0.5 - 0.005
	var y := ASSOALHO + (capo - ASSOALHO) * 0.50

	# Sem grade larga de sedan — so um bojo baixo sob o capo.
	_face(dados, Vector2(larg * 0.28, 0.07),
		Transform3D(Basis(), Vector3(0.0, y - 0.06, zf)),
		Color(0.24, 0.24, 0.26), C_GRADE)

	for z: float in [zf, zt]:
		var frente := z > 0.0
		var basis := Basis(Vector3.UP, 0.0 if frente else PI)
		_face(dados, Vector2(larg * 0.88, 0.10),
			Transform3D(basis, Vector3(0.0, ASSOALHO + 0.10, z)),
			Color(0.60, 0.60, 0.62), C_PARACHOQUE)
		# Overriders verticais (mais legiveis atras, presentes nas duas pontas).
		for s: float in [1.0, -1.0]:
			_face(dados, Vector2(0.050, 0.20),
				Transform3D(basis, Vector3(s * larg * 0.22, ASSOALHO + 0.16,
					z + (0.010 if frente else -0.010))),
				Color(0.66, 0.66, 0.68), C_PARACHOQUE)
		_face(dados, Vector2(0.24, 0.08),
			Transform3D(basis, Vector3(0.0, ASSOALHO + 0.22,
				z + (0.006 if frente else -0.006))),
			Color(0.78, 0.78, 0.80), C_PLACA)

	# Farol "redondo": quadrado + anel menor escuro (le circular a 480p).
	var ox := larg * 0.38
	for s: float in [1.0, -1.0]:
		_face(dados, Vector2(0.26, 0.26),
			Transform3D(Basis(), Vector3(s * ox, y + 0.12, zf + 0.008)),
			Color(0.18, 0.18, 0.20), C_GRADE)
		_face(luzes, Vector2(0.20, 0.20),
			Transform3D(Basis(), Vector3(s * ox, y + 0.12, zf + 0.014)),
			Color.WHITE, C_FAROL)
		# Pisca no topo do para-lama dianteiro.
		_face(luzes, Vector2(0.10, 0.055),
			Transform3D(Basis(), Vector3(s * ox, y + 0.28, zf - 0.02)),
			Color(1.0, 0.70, 0.18), C_PISCA)
		# Lanterna bipartida (ambar cima / vermelho baixo).
		_face(luzes, Vector2(0.12, 0.07),
			Transform3D(Basis(Vector3.UP, PI), Vector3(s * ox, y + 0.18, zt - 0.012)),
			Color(1.0, 0.55, 0.15), C_LANTERNA)
		_face(luzes, Vector2(0.12, 0.08),
			Transform3D(Basis(Vector3.UP, PI), Vector3(s * ox, y + 0.08, zt - 0.012)),
			Color.WHITE, C_FREIO)

	# Venezianas no deck traseiro (tres faixas largas + duas laterais baixas).
	for k in 3:
		var yy := capo + 0.02 + float(k) * 0.048
		_face(dados, Vector2(larg * 0.42, 0.032),
			Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, yy, zt + 0.16)),
			Color(0.14, 0.14, 0.16), C_GRADE)
	for s: float in [1.0, -1.0]:
		_face(dados, Vector2(larg * 0.14, 0.028),
			Transform3D(Basis(Vector3.UP, PI),
				Vector3(s * larg * 0.22, capo - 0.02, zt + 0.14)),
			Color(0.14, 0.14, 0.16), C_GRADE)

	# Escape + macaneta.
	_face(dados, Vector2(0.07, 0.045),
		Transform3D(Basis(Vector3.UP, PI), Vector3(-larg * 0.18, ASSOALHO + 0.05, zt - 0.02)),
		Color(0.24, 0.24, 0.25), C_PARACHOQUE)
	_face(dados, Vector2(0.09, 0.035),
		Transform3D(Basis(Vector3.UP, PI * 0.5),
			Vector3(larg * 0.46, capo - 0.10, 0.02)),
		Color(0.20, 0.20, 0.22), C_PARACHOQUE)


'''

func_idx = text.find("static func _lataria_fusca")
assert func_idx >= 0
start = text.rfind("## Fusca:", 0, func_idx)
assert start >= 0
end = text.index("## A cacamba da picape")
path.write_text(text[:start] + new_block + text[end:], encoding="utf-8")
print("ok size", path.stat().st_size)

# Sanity: P0 glass + Marea untouched
final = path.read_text(encoding="utf-8")
assert "Color(0.72, 0.80, 0.86)" in final
assert "_face_dois_lados" in final  # helper still exists
# Ensure _vidros still uses single _face for windshield
vid = final[final.index("static func _vidros"): final.index("static func _frente_e_tras")]
assert "_face_dois_lados" not in vid
assert "static func _frente_e_tras_marea" in final
assert "static func _lataria_fusca" in final
print("sanity ok")
