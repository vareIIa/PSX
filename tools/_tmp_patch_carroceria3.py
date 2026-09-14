# -*- coding: utf-8 -*-
from pathlib import Path
path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\render\carroceria.gd")
text = path.read_text(encoding="utf-8")

marker = "## A cacamba da picape: tres paredes baixas em cima do casco."
assert marker in text, "cacamba marker missing"

fusca_funcs = r'''## Fusca: casco curto, para-lamas bulbous, teto abaulado e estepe visual.
##
## Nao e o sedan encolhido — as medidas ja sao de besouro, e aqui a silhueta
## ganha o capô curto, o motor atras e os para-lamas que leem "Fusca" a trinta
## metros na nevoa. Sempre usa C_LATARIA_SUJA (refs sujas/enferrujadas).
static func _lataria_fusca(dados: Dictionary, comp: float, larg: float, capo: float,
		teto: float, cabine: float, cor: Color) -> void:
	var celula_lado := C_LATARIA_SUJA
	var altura_casco := capo - ASSOALHO
	var ferrugem := cor * Color(0.72, 0.55, 0.38)

	# Casco principal, um pouco mais baixo nas pontas via caixa unica.
	_caixa(dados, Vector3(larg * 0.92, altura_casco * 0.92, comp * 0.88),
		Vector3(0.0, ASSOALHO + altura_casco * 0.46, 0.0), cor,
		celula_lado, C_TRASEIRA, C_CAPO, true)

	# Capô curto e arredondado (frente +Z antes da meia volta).
	var capo_comp := comp * 0.22
	_caixa(dados, Vector3(larg * 0.78, altura_casco * 0.55, capo_comp),
		Vector3(0.0, ASSOALHO + altura_casco * 0.55, comp * 0.5 - capo_comp * 0.55),
		cor, celula_lado, C_CAPO, C_CAPO, false)

	# Deck do motor atras — mais alto que o capô, com celula de traseira.
	var motor_comp := comp * 0.24
	_caixa(dados, Vector3(larg * 0.80, altura_casco * 0.62, motor_comp),
		Vector3(0.0, ASSOALHO + altura_casco * 0.58, -comp * 0.5 + motor_comp * 0.55),
		cor, celula_lado, C_TRASEIRA, C_TRASEIRA, false)

	# Para-lamas bulbous nos quatro cantos.
	var fl_x := larg * 0.52
	var fl_y := ASSOALHO + altura_casco * 0.42
	var fl_z_f := comp * 0.28
	var fl_z_t := -comp * 0.30
	for s: float in [1.0, -1.0]:
		_caixa(dados, Vector3(0.28, altura_casco * 0.70, 0.55),
			Vector3(s * fl_x, fl_y, fl_z_f), ferrugem,
			celula_lado, celula_lado, C_CAPO, false)
		_caixa(dados, Vector3(0.30, altura_casco * 0.72, 0.58),
			Vector3(s * fl_x, fl_y, fl_z_t), ferrugem,
			celula_lado, celula_lado, C_TRASEIRA, false)

	# Estribo / soleira entre os eixos — faixa enferrujada.
	for s: float in [1.0, -1.0]:
		_face(dados, Vector2(comp * 0.36, 0.08),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.48), ASSOALHO + 0.04, 0.0)),
			ferrugem * 0.85, C_SOLEIRA)

	# Cabine abaulada: teto em tres placas (frente, meio, tras) + laterais.
	var comp_cabine := comp * cabine
	var z0 := -comp * 0.02 - comp_cabine * 0.5
	var z1 := z0 + comp_cabine
	var alt_cabine := teto - capo
	var recuo := alt_cabine * 0.70
	var lc := larg - RECUO_CABINE * 0.70
	var h := lc * 0.5

	# Teto em tres faixas para ler curva PSX.
	var z_mid := (z0 + z1) * 0.5
	_face(dados, Vector2(lc * 0.92, (comp_cabine - recuo * 2.0) * 0.38),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
			Vector3(0.0, teto, z_mid)), cor, C_TETO)
	_face(dados, Vector2(lc * 0.88, recuo * 0.9),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.42),
			Vector3(0.0, teto - 0.03, z1 - recuo * 0.55)), cor, C_TETO)
	_face(dados, Vector2(lc * 0.88, recuo * 0.9),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.58),
			Vector3(0.0, teto - 0.03, z0 + recuo * 0.55)), cor, C_TETO)

	for s: float in [1.0, -1.0]:
		var fora := Vector3(s, 0.0, 0.0)
		var a := Vector3(s * h, capo, z0)
		var b := Vector3(s * h, capo, z1)
		var c := Vector3(s * h, teto, z1 - recuo)
		var d := Vector3(s * h, teto, z0 + recuo)
		PSXMesh.acumular(dados,
			_quad_lateral(a, b, c, d, celula_lado, cor, fora),
			Transform3D.IDENTITY)
		var desloca := fora * 0.006
		PSXMesh.acumular(dados,
			_quad_lateral(
				_encolher(a, b, c, d, 0) + desloca,
				_encolher(a, b, c, d, 1) + desloca,
				_encolher(a, b, c, d, 2) + desloca,
				_encolher(a, b, c, d, 3) + desloca,
				C_VIDRO_LADO, VIDRO, fora),
			Transform3D.IDENTITY)
		var desloca_in := fora * -0.004
		PSXMesh.acumular(dados,
			_quad_lateral(
				_encolher(a, b, c, d, 0) + desloca_in,
				_encolher(a, b, c, d, 1) + desloca_in,
				_encolher(a, b, c, d, 2) + desloca_in,
				_encolher(a, b, c, d, 3) + desloca_in,
				C_VIDRO_LADO, VIDRO, -fora),
			Transform3D.IDENTITY)

	# Retrovisor blocky no pilar A esquerdo (lado +X antes da meia volta = dir).
	_caixa(dados, Vector3(0.08, 0.07, 0.12),
		Vector3(larg * 0.42, capo + alt_cabine * 0.45, z1 - 0.05),
		Color(0.35, 0.35, 0.38), C_PARACHOQUE, C_PARACHOQUE, C_PARACHOQUE, false)


## Frente/traseira do Fusca: farol redondo (placa), sem grade larga, venezianas
## no capô do motor, lanterna bipartida e para-choque com overriders.
static func _frente_e_tras_fusca(dados: Dictionary, luzes: Dictionary, comp: float,
		larg: float, capo: float, cor: Color) -> void:
	var zf := comp * 0.5 + 0.005
	var zt := -comp * 0.5 - 0.005
	var y := ASSOALHO + (capo - ASSOALHO) * 0.48

	# Sem grade de sedan — so um painel baixo no capô.
	_face(dados, Vector2(larg * 0.42, 0.10),
		Transform3D(Basis(), Vector3(0.0, y - 0.02, zf)),
		Color(0.28, 0.28, 0.30), C_GRADE)

	# Para-choques finos + overriders verticais (refs).
	for z: float in [zf, zt]:
		var frente := z > 0.0
		var basis := Basis(Vector3.UP, 0.0 if frente else PI)
		_face(dados, Vector2(larg * 0.92, 0.12),
			Transform3D(basis, Vector3(0.0, ASSOALHO + 0.10, z)),
			Color(0.58, 0.58, 0.60), C_PARACHOQUE)
		for s: float in [1.0, -1.0]:
			_face(dados, Vector2(0.06, 0.20),
				Transform3D(basis, Vector3(s * larg * 0.28, ASSOALHO + 0.16, z + (0.008 if frente else -0.008))),
				Color(0.62, 0.62, 0.64), C_PARACHOQUE)
		_face(dados, Vector2(0.28, 0.10),
			Transform3D(basis, Vector3(0.0, ASSOALHO + 0.22, z + (0.006 if frente else -0.006))),
			Color.WHITE, C_PLACA)

	# Farois "redondos" — placas quadradas nas quinas do para-lama.
	var ox := larg * 0.38
	for s: float in [1.0, -1.0]:
		_face(luzes, Vector2(0.20, 0.20),
			Transform3D(Basis(), Vector3(s * ox, y + 0.12, zf + 0.01)),
			Color.WHITE, C_FAROL)
		# Pisca âmbar no topo do para-lama.
		_face(luzes, Vector2(0.10, 0.06),
			Transform3D(Basis(), Vector3(s * ox, y + 0.26, zf - 0.02)),
			Color(1.0, 0.72, 0.20), C_PISCA)
		# Lanterna bipartida (laranja/vermelho via celulas).
		_face(luzes, Vector2(0.16, 0.08),
			Transform3D(Basis(Vector3.UP, PI), Vector3(s * ox, y + 0.16, zt - 0.01)),
			Color.WHITE, C_LANTERNA)
		_face(luzes, Vector2(0.16, 0.07),
			Transform3D(Basis(Vector3.UP, PI), Vector3(s * ox, y + 0.06, zt - 0.01)),
			Color.WHITE, C_FREIO)

	# Venezianas do motor (traseira): faixas escuras na celula de grade.
	for k in 3:
		var yy := capo + 0.06 + float(k) * 0.07
		_face(dados, Vector2(larg * 0.36, 0.04),
			Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, yy, zt + 0.12)),
			Color(0.18, 0.18, 0.20), C_GRADE)

	# Escape simples.
	_face(dados, Vector2(0.08, 0.05),
		Transform3D(Basis(Vector3.UP, PI), Vector3(-larg * 0.22, ASSOALHO + 0.05, zt - 0.02)),
		Color(0.25, 0.25, 0.26), C_PARACHOQUE)

	# Maçaneta (textura lateral ja traz, mas um bloco ajuda a leitura).
	_face(dados, Vector2(0.10, 0.04),
		Transform3D(Basis(Vector3.UP, PI * 0.5),
			Vector3(larg * 0.47, capo - 0.08, 0.05)),
		Color(0.22, 0.22, 0.24), C_PARACHOQUE)


'''

text = text.replace(marker, fusca_funcs + marker, 1)
path.write_text(text, encoding="utf-8")
print("pass3 ok", path.stat().st_size)
