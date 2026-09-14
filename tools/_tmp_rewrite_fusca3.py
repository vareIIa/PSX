# -*- coding: utf-8 -*-
from pathlib import Path
path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\render\carroceria.gd")
text = path.read_text(encoding="utf-8")
start = text.index("## Fusca: mesma economia do sedan")
# fallback if previous title still present
if start < 0 or "## Fusca: mesma economia" not in text:
    start = text.index("## Fusca:")
end = text.index("## A cacamba da picape")

new_block = r'''## Fusca: _lataria generica com proporcao de besouro + sujeira + para-lamas.
##
## Sem placas inclinadas soltas (elas flutuavam na captura). A leitura de Fusca
## vem de MEDIDAS curtas, recuo forte da coluna A, C_LATARIA_SUJA, para-lamas e
## _frente_e_tras_fusca (farol redondo, veneziana, overrider).
static func _lataria_fusca(dados: Dictionary, comp: float, larg: float, capo: float,
		teto: float, cabine: float, cor: Color) -> void:
	var suja := C_LATARIA_SUJA
	var ferrugem := Color(cor.r * 0.68, cor.g * 0.46, cor.b * 0.28)
	var altura_casco := capo - ASSOALHO

	_caixa(dados, Vector3(larg, altura_casco, comp),
		Vector3(0.0, ASSOALHO + altura_casco * 0.5, 0.0), cor,
		suja, C_TRASEIRA, C_CAPO, true)

	# Para-lamas baixos, encostados no casco.
	var fl_y := ASSOALHO + altura_casco * 0.38
	for s: float in [1.0, -1.0]:
		_caixa(dados, Vector3(0.18, altura_casco * 0.55, 0.42),
			Vector3(s * (larg * 0.5 - 0.01), fl_y, comp * 0.30), ferrugem,
			suja, suja, C_CAPO, false)
		_caixa(dados, Vector3(0.20, altura_casco * 0.58, 0.44),
			Vector3(s * (larg * 0.5 - 0.01), fl_y, -comp * 0.32), ferrugem,
			suja, suja, C_TRASEIRA, false)
		_face(dados, Vector2(comp * 0.36, 0.08),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.5 + 0.004), ASSOALHO + 0.05, 0.0)),
			ferrugem, C_SOLEIRA)

	var comp_cabine := comp * cabine
	var z0 := -comp * 0.02 - comp_cabine * 0.5
	var z1 := z0 + comp_cabine
	var alt_cabine := teto - capo
	var recuo := alt_cabine * 0.72
	var lc := larg - RECUO_CABINE * 0.70
	var h := lc * 0.5

	# Teto unico (igual sedan) — evita placa inclinada flutuando.
	_face(dados, Vector2(lc, maxf(0.25, comp_cabine - recuo * 2.0)),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
			Vector3(0.0, teto, (z0 + z1) * 0.5)), cor, C_TETO)

	for s: float in [1.0, -1.0]:
		var fora := Vector3(s, 0.0, 0.0)
		var a := Vector3(s * h, capo, z0)
		var b := Vector3(s * h, capo, z1)
		var c := Vector3(s * h, teto, z1 - recuo)
		var d := Vector3(s * h, teto, z0 + recuo)
		PSXMesh.acumular(dados,
			_quad_lateral(a, b, c, d, suja, cor, fora), Transform3D.IDENTITY)
		var desloca := fora * 0.008
		PSXMesh.acumular(dados,
			_quad_lateral(
				_encolher(a, b, c, d, 0) + desloca,
				_encolher(a, b, c, d, 1) + desloca,
				_encolher(a, b, c, d, 2) + desloca,
				_encolher(a, b, c, d, 3) + desloca,
				C_VIDRO_LADO, VIDRO, fora), Transform3D.IDENTITY)
		var desloca_in := fora * -0.005
		PSXMesh.acumular(dados,
			_quad_lateral(
				_encolher(a, b, c, d, 0) + desloca_in,
				_encolher(a, b, c, d, 1) + desloca_in,
				_encolher(a, b, c, d, 2) + desloca_in,
				_encolher(a, b, c, d, 3) + desloca_in,
				C_VIDRO_LADO, VIDRO, -fora), Transform3D.IDENTITY)

	for s: float in [1.0, -1.0]:
		_face(dados, Vector2(0.48, 0.20),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.5 + 0.006), ASSOALHO + 0.28, 0.0)),
			ferrugem, suja)

	_caixa(dados, Vector3(0.06, 0.05, 0.10),
		Vector3(larg * 0.38, capo + alt_cabine * 0.42, z1 - 0.04),
		Color(0.32, 0.32, 0.34), C_PARACHOQUE, C_PARACHOQUE, C_PARACHOQUE, false)


## Frente/traseira do Fusca: farol "redondo", sem grade larga, venezianas,
## lanterna bipartida e para-choque com overriders.
static func _frente_e_tras_fusca(dados: Dictionary, luzes: Dictionary, comp: float,
		larg: float, capo: float, _cor: Color) -> void:
	var zf := comp * 0.5 + 0.005
	var zt := -comp * 0.5 - 0.005
	var y := ASSOALHO + (capo - ASSOALHO) * 0.48

	_face(dados, Vector2(larg * 0.34, 0.08),
		Transform3D(Basis(), Vector3(0.0, y - 0.04, zf)),
		Color(0.26, 0.26, 0.28), C_GRADE)

	for z: float in [zf, zt]:
		var frente := z > 0.0
		var basis := Basis(Vector3.UP, 0.0 if frente else PI)
		_face(dados, Vector2(larg * 0.90, 0.11),
			Transform3D(basis, Vector3(0.0, ASSOALHO + 0.10, z)),
			Color(0.58, 0.58, 0.60), C_PARACHOQUE)
		for s: float in [1.0, -1.0]:
			_face(dados, Vector2(0.055, 0.18),
				Transform3D(basis, Vector3(s * larg * 0.26, ASSOALHO + 0.15,
					z + (0.009 if frente else -0.009))),
				Color(0.62, 0.62, 0.64), C_PARACHOQUE)
		_face(dados, Vector2(0.26, 0.09),
			Transform3D(basis, Vector3(0.0, ASSOALHO + 0.21,
				z + (0.006 if frente else -0.006))),
			Color.WHITE, C_PLACA)

	var ox := larg * 0.40
	for s: float in [1.0, -1.0]:
		_face(luzes, Vector2(0.22, 0.22),
			Transform3D(Basis(), Vector3(s * ox, y + 0.14, zf + 0.012)),
			Color.WHITE, C_FAROL)
		_face(luzes, Vector2(0.11, 0.06),
			Transform3D(Basis(), Vector3(s * ox, y + 0.28, zf - 0.01)),
			Color(1.0, 0.72, 0.20), C_PISCA)
		_face(luzes, Vector2(0.15, 0.07),
			Transform3D(Basis(Vector3.UP, PI), Vector3(s * ox, y + 0.15, zt - 0.012)),
			Color.WHITE, C_LANTERNA)
		_face(luzes, Vector2(0.15, 0.07),
			Transform3D(Basis(Vector3.UP, PI), Vector3(s * ox, y + 0.06, zt - 0.012)),
			Color.WHITE, C_FREIO)

	for k in 4:
		var yy := capo + 0.04 + float(k) * 0.055
		_face(dados, Vector2(larg * 0.34, 0.035),
			Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, yy, zt + 0.14)),
			Color(0.16, 0.16, 0.18), C_GRADE)

	_face(dados, Vector2(0.07, 0.045),
		Transform3D(Basis(Vector3.UP, PI), Vector3(-larg * 0.20, ASSOALHO + 0.05, zt - 0.02)),
		Color(0.24, 0.24, 0.25), C_PARACHOQUE)
	_face(dados, Vector2(0.09, 0.035),
		Transform3D(Basis(Vector3.UP, PI * 0.5),
			Vector3(larg * 0.46, capo - 0.10, 0.02)),
		Color(0.20, 0.20, 0.22), C_PARACHOQUE)


'''
# Find start more robustly
idx = text.find("## Fusca:")
assert idx >= 0, "Fusca block missing"
# Prefer the static func start to avoid partial comment mismatch
func_idx = text.find("static func _lataria_fusca")
assert func_idx >= 0
# Walk back to the ## Fusca comment immediately above
start = text.rfind("## Fusca:", 0, func_idx)
assert start >= 0
end = text.index("## A cacamba da picape")
path.write_text(text[:start] + new_block + text[end:], encoding="utf-8")
print("rewrote", path.stat().st_size)