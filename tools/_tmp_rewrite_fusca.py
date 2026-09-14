# -*- coding: utf-8 -*-
from pathlib import Path
path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\render\carroceria.gd")
text = path.read_text(encoding="utf-8")
start = text.index("## Fusca: casco curto")
end = text.index("## A cacamba da picape")

new_block = r'''## Fusca: casco curto, para-lamas bulbous, teto em cupula.
##
## Nao e o sedan encolhido — proporcao de besouro + silhueta propria. Sempre
## C_LATARIA_SUJA para casar com as refs sujas/enferrujadas.
static func _lataria_fusca(dados: Dictionary, comp: float, larg: float, capo: float,
		teto: float, cabine: float, cor: Color) -> void:
	var suja := C_LATARIA_SUJA
	var ferrugem := Color(cor.r * 0.70, cor.g * 0.48, cor.b * 0.30)
	var altura_casco := capo - ASSOALHO

	# Casco ovalado em tres caixas (frente baixa, meio, tras do motor).
	_caixa(dados, Vector3(larg * 0.86, altura_casco * 0.78, comp * 0.34),
		Vector3(0.0, ASSOALHO + altura_casco * 0.42, comp * 0.22), cor,
		suja, C_CAPO, C_CAPO, true)
	_caixa(dados, Vector3(larg * 0.90, altura_casco * 0.88, comp * 0.40),
		Vector3(0.0, ASSOALHO + altura_casco * 0.46, 0.0), cor,
		suja, C_TRASEIRA, C_CAPO, true)
	_caixa(dados, Vector3(larg * 0.86, altura_casco * 0.82, comp * 0.32),
		Vector3(0.0, ASSOALHO + altura_casco * 0.44, -comp * 0.24), cor,
		suja, C_TRASEIRA, C_TRASEIRA, true)

	# Capo curto arredondado (placa inclinada + caixa).
	var capo_z := comp * 0.42
	_caixa(dados, Vector3(larg * 0.72, altura_casco * 0.42, comp * 0.18),
		Vector3(0.0, ASSOALHO + altura_casco * 0.62, capo_z), cor,
		suja, C_CAPO, C_CAPO, false)
	_face(dados, Vector2(larg * 0.70, comp * 0.16),
		Transform3D(Basis(Vector3.RIGHT, -0.55),
			Vector3(0.0, capo - 0.02, capo_z - 0.02)), cor, C_CAPO)

	# Deck do motor (traseira alta com veneziana depois em _frente_e_tras_fusca).
	var motor_z := -comp * 0.40
	_caixa(dados, Vector3(larg * 0.74, altura_casco * 0.50, comp * 0.20),
		Vector3(0.0, ASSOALHO + altura_casco * 0.68, motor_z), cor,
		suja, C_TRASEIRA, C_TRASEIRA, false)
	_face(dados, Vector2(larg * 0.70, comp * 0.16),
		Transform3D(Basis(Vector3.RIGHT, -0.75),
			Vector3(0.0, capo + 0.04, motor_z + 0.04)), cor, C_TRASEIRA)

	# Para-lamas: bulbos que passam da bitola (leitura de Fusca a distancia).
	var fl_y := ASSOALHO + altura_casco * 0.38
	for s: float in [1.0, -1.0]:
		_caixa(dados, Vector3(0.34, altura_casco * 0.78, 0.62),
			Vector3(s * larg * 0.50, fl_y, comp * 0.26), ferrugem,
			suja, suja, C_CAPO, false)
		_caixa(dados, Vector3(0.36, altura_casco * 0.80, 0.66),
			Vector3(s * larg * 0.50, fl_y, -comp * 0.28), ferrugem,
			suja, suja, C_TRASEIRA, false)
		# Mancha de ferrugem na soleira.
		_face(dados, Vector2(comp * 0.38, 0.10),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.46), ASSOALHO + 0.05, 0.0)),
			ferrugem, C_SOLEIRA)

	# Cabine em cupula: laterais trapezoidais + teto em tres placas.
	var comp_cabine := comp * cabine
	var z0 := -comp * 0.04 - comp_cabine * 0.5
	var z1 := z0 + comp_cabine
	var alt_cabine := teto - capo
	var recuo := alt_cabine * 0.85
	var lc := larg - RECUO_CABINE * 0.55
	var h := lc * 0.5
	var z_mid := (z0 + z1) * 0.5

	_face(dados, Vector2(lc * 0.90, (comp_cabine - recuo * 1.6) * 0.55),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
			Vector3(0.0, teto, z_mid)), cor, C_TETO)
	_face(dados, Vector2(lc * 0.86, recuo * 1.05),
		Transform3D(Basis(Vector3.RIGHT, -0.95),
			Vector3(0.0, teto - 0.05, z1 - recuo * 0.45)), cor, C_TETO)
	_face(dados, Vector2(lc * 0.86, recuo * 1.05),
		Transform3D(Basis(Vector3.RIGHT, -2.20),
			Vector3(0.0, teto - 0.05, z0 + recuo * 0.45)), cor, C_TETO)

	for s: float in [1.0, -1.0]:
		var fora := Vector3(s, 0.0, 0.0)
		var a := Vector3(s * h, capo, z0)
		var b := Vector3(s * h, capo, z1)
		var c := Vector3(s * h * 0.92, teto, z1 - recuo)
		var d := Vector3(s * h * 0.92, teto, z0 + recuo)
		PSXMesh.acumular(dados,
			_quad_lateral(a, b, c, d, suja, cor, fora), Transform3D.IDENTITY)
		# Vidro maior (moldura menor) para ler janela de Fusca, dois lados.
		var desloca := fora * 0.01
		var ga := a.lerp((a + b + c + d) * 0.25, 0.10) + desloca
		var gb := b.lerp((a + b + c + d) * 0.25, 0.10) + desloca
		var gc := c.lerp((a + b + c + d) * 0.25, 0.10) + desloca
		var gd := d.lerp((a + b + c + d) * 0.25, 0.10) + desloca
		ga.y = lerpf(a.y, ((a + b + c + d) * 0.25).y, 0.22)
		gb.y = lerpf(b.y, ((a + b + c + d) * 0.25).y, 0.22)
		PSXMesh.acumular(dados,
			_quad_lateral(ga, gb, gc, gd, C_VIDRO_LADO, VIDRO, fora),
			Transform3D.IDENTITY)
		var di := fora * -0.006
		PSXMesh.acumular(dados,
			_quad_lateral(ga + di - desloca, gb + di - desloca, gc + di - desloca,
				gd + di - desloca, C_VIDRO_LADO, VIDRO, -fora),
			Transform3D.IDENTITY)

	# Retrovisor blocky.
	_caixa(dados, Vector3(0.07, 0.06, 0.11),
		Vector3(larg * 0.40, capo + alt_cabine * 0.40, z1 - 0.02),
		Color(0.34, 0.34, 0.36), C_PARACHOQUE, C_PARACHOQUE, C_PARACHOQUE, false)

	# Manchas extras de ferrugem no casco (vertex tint via faces).
	for s: float in [1.0, -1.0]:
		_face(dados, Vector2(0.55, 0.28),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.455), ASSOALHO + 0.28, -0.1)),
			ferrugem, suja)


## Frente/traseira do Fusca: farol redondo, sem grade larga, venezianas,
## lanterna bipartida e para-choque com overriders.
static func _frente_e_tras_fusca(dados: Dictionary, luzes: Dictionary, comp: float,
		larg: float, capo: float, _cor: Color) -> void:
	var zf := comp * 0.5 + 0.005
	var zt := -comp * 0.5 - 0.005
	var y := ASSOALHO + (capo - ASSOALHO) * 0.48

	_face(dados, Vector2(larg * 0.36, 0.09),
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
print("rewrote fusca block", path.stat().st_size)