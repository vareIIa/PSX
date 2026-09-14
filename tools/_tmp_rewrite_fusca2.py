# -*- coding: utf-8 -*-
from pathlib import Path
path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\render\carroceria.gd")
text = path.read_text(encoding="utf-8")
start = text.index("## Fusca: casco curto")
end = text.index("## A cacamba da picape")

new_block = r'''## Fusca: mesma economia do sedan, proporcao de besouro.
##
## Em vez de empilhar caixas soltas (que leem como carro explodido a 480p),
## reusa o fluxo do _lataria com capo mais curto, teto em cupula, para-lamas
## discretos e C_LATARIA_SUJA sempre. Detalhe de frente/tras fica em
## _frente_e_tras_fusca.
static func _lataria_fusca(dados: Dictionary, comp: float, larg: float, capo: float,
		teto: float, cabine: float, cor: Color) -> void:
	var suja := C_LATARIA_SUJA
	var ferrugem := Color(cor.r * 0.68, cor.g * 0.46, cor.b * 0.28)
	var altura_casco := capo - ASSOALHO

	# Casco unico — base limpa que ja le como carro.
	_caixa(dados, Vector3(larg, altura_casco, comp),
		Vector3(0.0, ASSOALHO + altura_casco * 0.5, 0.0), cor,
		suja, C_TRASEIRA, C_CAPO, true)

	# Para-lamas: so um bulbo por canto, tingido de ferrugem, sem sobrar no ar.
	var fl_y := ASSOALHO + altura_casco * 0.40
	for s: float in [1.0, -1.0]:
		_caixa(dados, Vector3(0.22, altura_casco * 0.62, 0.48),
			Vector3(s * (larg * 0.5 - 0.02), fl_y, comp * 0.28), ferrugem,
			suja, suja, C_CAPO, false)
		_caixa(dados, Vector3(0.24, altura_casco * 0.64, 0.50),
			Vector3(s * (larg * 0.5 - 0.02), fl_y, -comp * 0.30), ferrugem,
			suja, suja, C_TRASEIRA, false)

	# Soleira enferrujada entre eixos.
	for s: float in [1.0, -1.0]:
		_face(dados, Vector2(comp * 0.38, 0.09),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.5 + 0.004), ASSOALHO + 0.05, 0.0)),
			ferrugem, C_SOLEIRA)

	# Cabine cupula: recuo forte (coluna A inclinada = leitura de Fusca).
	var comp_cabine := comp * cabine
	var z0 := -comp * 0.02 - comp_cabine * 0.5
	var z1 := z0 + comp_cabine
	var alt_cabine := teto - capo
	var recuo := alt_cabine * 0.78
	var lc := larg - RECUO_CABINE * 0.65
	var h := lc * 0.5

	# Teto em tres placas para fingir curva.
	var z_mid := (z0 + z1) * 0.5
	var teto_comp := maxf(0.20, comp_cabine - recuo * 1.7)
	_face(dados, Vector2(lc * 0.94, teto_comp),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
			Vector3(0.0, teto, z_mid)), cor, C_TETO)
	_face(dados, Vector2(lc * 0.90, recuo * 0.85),
		Transform3D(Basis(Vector3.RIGHT, -0.90),
			Vector3(0.0, teto - 0.04, z1 - recuo * 0.50)), cor, C_TETO)
	_face(dados, Vector2(lc * 0.90, recuo * 0.85),
		Transform3D(Basis(Vector3.RIGHT, -2.25),
			Vector3(0.0, teto - 0.04, z0 + recuo * 0.50)), cor, C_TETO)

	# Capo curto: placa inclinada sobre a frente do casco (colada, nao flutuando).
	_face(dados, Vector2(larg * 0.78, comp * 0.18),
		Transform3D(Basis(Vector3.RIGHT, -0.35),
			Vector3(0.0, capo - 0.01, comp * 0.36)), cor, C_CAPO)

	# Deck do motor atras, colado no casco.
	_face(dados, Vector2(larg * 0.78, comp * 0.16),
		Transform3D(Basis(Vector3.RIGHT, -2.85),
			Vector3(0.0, capo + 0.02, -comp * 0.36)), cor, C_TRASEIRA)

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

	# Mancha de ferrugem na porta.
	for s: float in [1.0, -1.0]:
		_face(dados, Vector2(0.50, 0.22),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.5 + 0.006), ASSOALHO + 0.30, 0.05)),
			ferrugem, suja)

	# Retrovisor.
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
path.write_text(text[:start] + new_block + text[end:], encoding="utf-8")
print("ok", path.stat().st_size)