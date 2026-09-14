# -*- coding: utf-8 -*-
from pathlib import Path
import re

p = Path("game/src/render/carroceria.gd")
t = p.read_text(encoding="utf-8")

new_fn = """## Fiat Marea PSX: grade em ripas, farol quadrado com pisca na quina, lanterna
## em blocos vermelho/laranja/branco, tres venezianas na coluna C e placa cinza.
##
## Laranja e branco da lanterna ficam no CORPO (malha nao-emissiva) para o
## swap de UV do freio/seta no Carro continuar mexendo so nas faces C_LANTERNA
## da malha de luzes — um vertice a mais com C_PISCA/C_RE la quebraria o delta.
static func _frente_e_tras_marea(dados: Dictionary, luzes: Dictionary, comp: float,
		larg: float, capo: float, _cor: Color) -> void:
	var zf := comp * 0.5 + 0.005
	var zt := -comp * 0.5 - 0.005
	var y := ASSOALHO + (capo - ASSOALHO) * 0.52

	# Grade larga em ripas horizontais (leitura de Marea a distancia).
	_face(dados, Vector2(larg * 0.72, 0.22),
		Transform3D(Basis(), Vector3(0.0, y + 0.04, zf)),
		Color(0.22, 0.22, 0.24), C_GRADE)
	for k in 4:
		var yy := y - 0.02 + float(k) * 0.055
		_face(dados, Vector2(larg * 0.68, 0.028),
			Transform3D(Basis(), Vector3(0.0, yy, zf + 0.004)),
			Color(0.16, 0.16, 0.18), C_GRADE)

	# Para-choques escuros + placa: frente branca, traseira cinza em branco.
	for z: float in [zf, zt]:
		var frente := z > 0.0
		var basis := Basis(Vector3.UP, 0.0 if frente else PI)
		_face(dados, Vector2(larg, 0.15),
			Transform3D(basis, Vector3(0.0, ASSOALHO + 0.10, z)),
			Color(0.42, 0.42, 0.44), C_PARACHOQUE)
		var cor_placa := Color.WHITE if frente else Color(0.48, 0.48, 0.50)
		_face(dados, Vector2(0.36, 0.12),
			Transform3D(basis,
				Vector3(0.0, ASSOALHO + 0.24, z + (0.006 if frente else -0.006))),
			cor_placa, C_PLACA)

	# Farois quadrados + pisca ambar na quina de fora (malha emissiva).
	var ox := larg * 0.36
	for s: float in [1.0, -1.0]:
		_face(luzes, Vector2(0.28, 0.16),
			Transform3D(Basis(), Vector3(s * ox, y + 0.10, zf + 0.008)),
			Color.WHITE, C_FAROL)
		_face(luzes, Vector2(0.09, 0.16),
			Transform3D(Basis(), Vector3(s * (ox + 0.17), y + 0.10, zf + 0.009)),
			Color(1.0, 0.70, 0.22), C_PISCA)

		# Lanterna: vermelho de fora (emissivo) | laranja/branco (corpo) | vermelho interno.
		var bx := s * ox
		_face(luzes, Vector2(0.14, 0.16),
			Transform3D(Basis(Vector3.UP, PI), Vector3(bx + s * 0.12, y + 0.10, zt - 0.008)),
			Color.WHITE, C_LANTERNA)
		_face(dados, Vector2(0.11, 0.08),
			Transform3D(Basis(Vector3.UP, PI), Vector3(bx, y + 0.14, zt - 0.006)),
			Color.WHITE, C_PISCA)
		_face(dados, Vector2(0.11, 0.07),
			Transform3D(Basis(Vector3.UP, PI), Vector3(bx, y + 0.05, zt - 0.006)),
			Color.WHITE, C_RE)
		_face(dados, Vector2(0.12, 0.16),
			Transform3D(Basis(Vector3.UP, PI), Vector3(bx - s * 0.12, y + 0.10, zt - 0.006)),
			Color.WHITE, C_LANTERNA)

	# Tres venezianas escuras na coluna C (atras da estufa).
	var cabine := float(MEDIDAS[Modelo.MAREA]["cabine"])
	var comp_cabine := comp * cabine
	var z0 := -comp * 0.06 - comp_cabine * 0.5
	var z_vent := z0 + 0.10
	var lc := larg - RECUO_CABINE
	for s: float in [1.0, -1.0]:
		for k in 3:
			var yy := capo + 0.10 + float(k) * 0.08
			_face(dados, Vector2(0.16, 0.035),
				Transform3D(Basis(Vector3.UP, s * PI * 0.5),
					Vector3(s * (lc * 0.5 + 0.008), yy, z_vent)),
				Color(0.14, 0.14, 0.15), C_GRADE)

	# Respiros no capo, perto do para-brisa (leitura de sedan 90s).
	for s: float in [1.0, -1.0]:
		_face(dados, Vector2(0.18, 0.06),
			Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
				Vector3(s * larg * 0.22, capo + 0.004, comp * 0.12)),
			Color(0.20, 0.20, 0.22), C_GRADE)


"""

pat = re.compile(
    r"(?:## Marea.*?\n)?static func _frente_e_tras_marea\(.*?(?=^## Fusca:)",
    re.M | re.S,
)
m = pat.search(t)
if not m:
    raise SystemExit("could not find marea stub to replace")
print("replacing", m.start(), "to", m.end(), "len", m.end()-m.start())
print("OLD HEAD:", repr(t[m.start():m.start()+80]))
t = t[:m.start()] + new_fn + t[m.end():]
p.write_text(t, encoding="utf-8")
t2 = p.read_text(encoding="utf-8")
assert "venezianas escuras" in t2
assert "WIP Renato" not in t2
assert "grade em ripas" in t2
print("OK")