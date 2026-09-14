# -*- coding: utf-8 -*-
from pathlib import Path

path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\render\carroceria.gd")
text = path.read_text(encoding="utf-8")

old_med = '\tModelo.FUSCA:  {"c": 3.90, "l": 1.52, "capo": 0.78, "teto": 1.52, "eixo": 2.22, "cabine": 0.46},'
new_med = '\tModelo.FUSCA:  {"c": 3.78, "l": 1.50, "capo": 0.74, "teto": 1.50, "eixo": 2.10, "cabine": 0.48},'
if old_med not in text:
    raise SystemExit("MEDIDAS line missing: " + repr([l for l in text.splitlines() if "Modelo.FUSCA" in l and "c" in l][:1]))
text = text.replace(old_med, new_med, 1)

new_block = r'''## Fusca: silhueta de besouro em caixas PSX (refs PRINTS/ref_fusca).
##
## Porta BAIXA entre para-lamas ALTOS (arco legivel de lado), capo/deck
## inclinados, teto em cupula. Cabine z0/recuo = _vidros (P0 face unica + tint).
## Sem _face_dois_lados no para-brisa. Sem mexer em Marea.
static func _lataria_fusca(dados: Dictionary, comp: float, larg: float, capo: float,
		teto: float, cabine: float, cor: Color) -> void:
	var suja := C_LATARIA_SUJA
	var ferrugem := Color(cor.r * 0.58, cor.g * 0.36, cor.b * 0.20)
	var ferrugem_clara := Color(cor.r * 0.74, cor.g * 0.52, cor.b * 0.32)
	var chrome := Color(0.78, 0.78, 0.80)
	var altura_casco := capo - ASSOALHO

	# Barriga baixa continua (assoalho ate meia porta) — nao preenche o arco.
	_caixa(dados, Vector3(larg * 0.86, altura_casco * 0.55, comp * 0.92),
		Vector3(0.0, ASSOALHO + altura_casco * 0.30, 0.0), cor,
		suja, C_TRASEIRA, C_CAPO, true)

	# Painel da porta (mais baixo que o topo dos para-lamas).
	_caixa(dados, Vector3(larg * 0.90, altura_casco * 0.42, comp * 0.34),
		Vector3(0.0, ASSOALHO + altura_casco * 0.68, 0.0), cor,
		suja, suja, C_CAPO, false)

	# Capo curto caindo (volume + placa).
	_caixa(dados, Vector3(larg * 0.72, altura_casco * 0.36, comp * 0.22),
		Vector3(0.0, ASSOALHO + altura_casco * 0.62, comp * 0.34), cor,
		suja, C_CAPO, C_CAPO, false)
	_face(dados, Vector2(larg * 0.70, comp * 0.20),
		Transform3D(Basis(Vector3.RIGHT, -0.58),
			Vector3(0.0, capo - 0.04, comp * 0.32)), cor, C_CAPO)

	# Deck do motor caindo para tras.
	_caixa(dados, Vector3(larg * 0.74, altura_casco * 0.40, comp * 0.24),
		Vector3(0.0, ASSOALHO + altura_casco * 0.66, -comp * 0.34), cor,
		suja, C_TRASEIRA, C_TRASEIRA, false)
	_face(dados, Vector2(larg * 0.72, comp * 0.20),
		Transform3D(Basis(Vector3.RIGHT, -2.45),
			Vector3(0.0, capo - 0.02, -comp * 0.32)), cor, C_TRASEIRA)

	# Para-lamas ALTOS (quase na linha do capo) e LARGOS — leitura de besouro.
	# Corpo creme no topo do arco; ferrugem so na base (como nas refs).
	var fl_top := ASSOALHO + altura_casco * 0.78
	for s: float in [1.0, -1.0]:
		var sx := s * (larg * 0.52)
		# --- dianteiro ---
		_caixa(dados, Vector3(0.38, altura_casco * 0.85, 0.50),
			Vector3(sx, ASSOALHO + altura_casco * 0.48, comp * 0.28), cor,
			suja, suja, C_CAPO, false)
		_caixa(dados, Vector3(0.30, altura_casco * 0.55, 0.34),
			Vector3(sx + s * 0.04, fl_top - 0.06, comp * 0.28), cor,
			suja, suja, C_CAPO, false)
		_caixa(dados, Vector3(0.34, altura_casco * 0.38, 0.40),
			Vector3(sx, ASSOALHO + altura_casco * 0.28, comp * 0.28), ferrugem,
			suja, suja, C_CAPO, false)
		# --- traseiro ---
		_caixa(dados, Vector3(0.40, altura_casco * 0.88, 0.54),
			Vector3(sx, ASSOALHO + altura_casco * 0.50, -comp * 0.28), cor,
			suja, suja, C_TRASEIRA, false)
		_caixa(dados, Vector3(0.32, altura_casco * 0.58, 0.36),
			Vector3(sx + s * 0.04, fl_top - 0.04, -comp * 0.28), cor,
			suja, suja, C_TRASEIRA, false)
		_caixa(dados, Vector3(0.36, altura_casco * 0.40, 0.44),
			Vector3(sx, ASSOALHO + altura_casco * 0.28, -comp * 0.28), ferrugem,
			suja, suja, C_TRASEIRA, false)
		# Soleira / running board.
		_face(dados, Vector2(comp * 0.32, 0.10),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.50), ASSOALHO + 0.05, 0.0)),
			ferrugem, C_SOLEIRA)
		# Friso cromado na porta (entre para-lamas).
		_face(dados, Vector2(comp * 0.30, 0.030),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.46), capo - 0.18, 0.0)),
			chrome, C_PARACHOQUE)
		# Mancha de ferrugem na porta.
		_face(dados, Vector2(0.36, 0.20),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.455), ASSOALHO + 0.32, 0.0)),
			ferrugem_clara, suja)

	# Cabine alinhada ao _vidros (P0).
	var comp_cabine := comp * cabine
	var z0 := -comp * 0.06 - comp_cabine * 0.5
	var z1 := z0 + comp_cabine
	var alt_cabine := teto - capo
	var recuo := alt_cabine * 0.55
	var lc := larg - RECUO_CABINE * 0.90
	var h := lc * 0.5
	var z_mid := (z0 + z1) * 0.5

	# Cupula: topo + duas placas inclinadas (frente/tras) encostadas.
	var teto_comp := maxf(0.20, comp_cabine - recuo * 1.90)
	_face(dados, Vector2(lc * 0.90, teto_comp),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
			Vector3(0.0, teto, z_mid)), cor, C_TETO)
	_face(dados, Vector2(lc * 0.86, recuo * 1.05),
		Transform3D(Basis(Vector3.RIGHT, -0.88),
			Vector3(0.0, teto - 0.04, z1 - recuo * 0.50)), cor, C_TETO)
	_face(dados, Vector2(lc * 0.86, recuo * 1.05),
		Transform3D(Basis(Vector3.RIGHT, -2.26),
			Vector3(0.0, teto - 0.04, z0 + recuo * 0.50)), cor, C_TETO)

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

	# Retrovisor.
	_caixa(dados, Vector3(0.06, 0.05, 0.10),
		Vector3(larg * 0.36, capo + alt_cabine * 0.38, z1 - 0.02),
		Color(0.34, 0.34, 0.36), C_PARACHOQUE, C_PARACHOQUE, C_PARACHOQUE, false)


## Frente/traseira do Fusca: farol redondo nos para-lamas, venezianas no deck,
## lanterna bipartida e overriders (refs).
static func _frente_e_tras_fusca(dados: Dictionary, luzes: Dictionary, comp: float,
		larg: float, capo: float, _cor: Color) -> void:
	var zf := comp * 0.5 + 0.005
	var zt := -comp * 0.5 - 0.005
	var y := ASSOALHO + (capo - ASSOALHO) * 0.52

	_face(dados, Vector2(larg * 0.24, 0.06),
		Transform3D(Basis(), Vector3(0.0, y - 0.08, zf)),
		Color(0.22, 0.22, 0.24), C_GRADE)

	for z: float in [zf, zt]:
		var frente := z > 0.0
		var basis := Basis(Vector3.UP, 0.0 if frente else PI)
		_face(dados, Vector2(larg * 0.92, 0.10),
			Transform3D(basis, Vector3(0.0, ASSOALHO + 0.10, z)),
			Color(0.62, 0.62, 0.64), C_PARACHOQUE)
		for s: float in [1.0, -1.0]:
			_face(dados, Vector2(0.048, 0.22),
				Transform3D(basis, Vector3(s * larg * 0.20, ASSOALHO + 0.17,
					z + (0.012 if frente else -0.012))),
				Color(0.70, 0.70, 0.72), C_PARACHOQUE)
		_face(dados, Vector2(0.22, 0.08),
			Transform3D(basis, Vector3(0.0, ASSOALHO + 0.22,
				z + (0.006 if frente else -0.006))),
			Color(0.80, 0.80, 0.82), C_PLACA)

	# Farol redondo: anel escuro + nucleo (nos para-lamas, nao na grade).
	var ox := larg * 0.42
	for s: float in [1.0, -1.0]:
		_face(dados, Vector2(0.28, 0.28),
			Transform3D(Basis(), Vector3(s * ox, y + 0.08, zf + 0.010)),
			Color(0.16, 0.16, 0.18), C_GRADE)
		_face(luzes, Vector2(0.20, 0.20),
			Transform3D(Basis(), Vector3(s * ox, y + 0.08, zf + 0.016)),
			Color.WHITE, C_FAROL)
		_face(luzes, Vector2(0.10, 0.055),
			Transform3D(Basis(), Vector3(s * ox, y + 0.26, zf - 0.04)),
			Color(1.0, 0.68, 0.16), C_PISCA)
		_face(luzes, Vector2(0.11, 0.06),
			Transform3D(Basis(Vector3.UP, PI), Vector3(s * ox, y + 0.18, zt - 0.012)),
			Color(1.0, 0.50, 0.12), C_LANTERNA)
		_face(luzes, Vector2(0.11, 0.08),
			Transform3D(Basis(Vector3.UP, PI), Vector3(s * ox, y + 0.08, zt - 0.012)),
			Color.WHITE, C_FREIO)

	# Venezianas no deck (largas + laterais baixas).
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

func_idx = text.find("static func _lataria_fusca")
start = text.rfind("## Fusca:", 0, func_idx)
end = text.index("## A cacamba da picape")
path.write_text(text[:start] + new_block + text[end:], encoding="utf-8")

final = path.read_text(encoding="utf-8")
vid = final[final.index("static func _vidros"): final.index("static func _frente_e_tras")]
assert vid.count("_face_dois_lados(") == 0
assert "Color(0.72, 0.80, 0.86)" in vid
assert "static func _frente_e_tras_marea" in final
print("ok", path.stat().st_size)
