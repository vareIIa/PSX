# -*- coding: utf-8 -*-
from pathlib import Path
import re

p = Path("game/src/render/carroceria.gd")
t = p.read_text(encoding="utf-8")

old_med = '\tModelo.MAREA:  {"c": 4.39, "l": 1.74, "capo": 0.92, "teto": 1.44, "eixo": 2.59, "cabine": 0.48},'
new_med = '\tModelo.MAREA:  {"c": 4.39, "l": 1.74, "capo": 0.92, "teto": 1.44, "eixo": 2.54, "cabine": 0.48},'
if old_med not in t:
    raise SystemExit("MEDIDAS MAREA line not found")
t = t.replace(old_med, new_med, 1)

old_cor = """\tvar cor := TINTA_TAXI if modelo == Modelo.TAXI else tinta
\tif modelo == Modelo.FUSCA:
\t\tcor = TINTA_FUSCA
\t# Fusca das refs e sempre sujo; os outros continuam com a chance de 1 em 7.
\tvar suja := modelo == Modelo.FUSCA or (semente % 7) == 0"""
new_cor = """\tvar cor := TINTA_TAXI if modelo == Modelo.TAXI else tinta
\tif modelo == Modelo.FUSCA:
\t\tcor = TINTA_FUSCA
\telif modelo == Modelo.MAREA:
\t\t# Creme das refs; suja ainda depende da semente (1 em 7).
\t\tcor = Color(0.90, 0.88, 0.80)
\t# Fusca das refs e sempre sujo; os outros continuam com a chance de 1 em 7.
\tvar suja := modelo == Modelo.FUSCA or (semente % 7) == 0"""
if old_cor not in t:
    raise SystemExit("montar cor block not found")
t = t.replace(old_cor, new_cor, 1)

marea_fn = r'''
## Fiat Marea PSX: grade em ripas, farol quadrado com pisca na quina, lanterna
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


'''

# Insert MAREA early-return
old_early = """\tif modelo == Modelo.FUSCA:
\t\t_frente_e_tras_fusca(dados, luzes, comp, larg, capo, cor)
\t\treturn
"""
new_early = """\tif modelo == Modelo.FUSCA:
\t\t_frente_e_tras_fusca(dados, luzes, comp, larg, capo, cor)
\t\treturn
\tif modelo == Modelo.MAREA:
\t\t_frente_e_tras_marea(dados, luzes, comp, larg, capo, cor)
\t\treturn
"""
if old_early not in t:
    raise SystemExit("early return block not found")
t = t.replace(old_early, new_early, 1)

# Insert marea function before Fusca lataria
marker = "## Fusca: casco curto, para-lamas bulbous, teto abaulado e estepe visual."
if marker not in t:
    raise SystemExit("Fusca lataria marker not found")
if "_frente_e_tras_marea" not in t:
    t = t.replace(marker, marea_fn + marker, 1)

p.write_text(t, encoding="utf-8")
print("carroceria.gd OK")

# --- carro.gd spawn ---
p2 = Path("game/src/world/carro.gd")
t2 = p2.read_text(encoding="utf-8")
old_s = """static func _sortear_modelo(s: int) -> Carroceria.Modelo:
\t# O taxi e raro de proposito. Um em nove: frequente o bastante para o
\t# jogador reparar que existe, raro o bastante para ainda ser um evento.
\tvar h := absi(s * 2654435761) % 100
\tif h < 11:
\t\treturn Carroceria.Modelo.TAXI
\tif h < 32:
\t\treturn Carroceria.Modelo.HATCH
\tif h < 50:
\t\treturn Carroceria.Modelo.PERUA
\tif h < 66:
\t\treturn Carroceria.Modelo.PICAPE
\treturn Carroceria.Modelo.SEDA
"""
new_s = """static func _sortear_modelo(s: int) -> Carroceria.Modelo:
\t# Rua = Marea + Fusca (Jota), com taxi raro. Genericos fora do sorteio
\t# diario — continuam no enum/vitrine para blitz e testes.
\tvar h := absi(s * 2654435761) % 100
\tif h < 10:
\t\treturn Carroceria.Modelo.TAXI
\tif h < 38:
\t\treturn Carroceria.Modelo.FUSCA
\treturn Carroceria.Modelo.MAREA
"""
if old_s not in t2:
    raise SystemExit("sortear block not found")
p2.write_text(t2.replace(old_s, new_s, 1), encoding="utf-8")
print("carro.gd OK")

# --- carro_cena.gd ---
p3 = Path("game/src/world/carro_cena.gd")
t3 = p3.read_text(encoding="utf-8")
old_c = """## Hatch claro das refs de chase (nao o verde do corte cinematografico antigo).
const TINTA := Color(0.94, 0.94, 0.90)
const SEMENTE := 4407
const MODELO := Carroceria.Modelo.HATCH
"""
new_c = """## Marea creme sujo das refs de chase (Estrada Velha).
const TINTA := Color(0.90, 0.88, 0.80)
const SEMENTE := 4410
const MODELO := Carroceria.Modelo.MAREA
"""
if old_c not in t3:
    raise SystemExit("carro_cena consts not found")
t3 = t3.replace(old_c, new_c, 1)
t3 = t3.replace("## Pivo atras do hatch para a chase cam (3P).",
                "## Pivo atras do Marea para a chase cam (3P).")
t3 = t3.replace("# Fill externo fraco: hatch branco precisa ler na 3P a noite.",
                "# Fill externo fraco: Marea creme precisa ler na 3P a noite.")
p3.write_text(t3, encoding="utf-8")
print("carro_cena.gd OK")

# --- carros_teste.gd ---
p4 = Path("game/src/levels/carros_teste.gd")
t4 = p4.read_text(encoding="utf-8")
t4 = t4.replace("Monta os cinco modelos da Carroceria lado a lado",
                "Monta os sete modelos da Carroceria lado a lado")
old_m = """const MODELOS: Array[Carroceria.Modelo] = [
\tCarroceria.Modelo.SEDA, Carroceria.Modelo.HATCH, Carroceria.Modelo.PERUA,
\tCarroceria.Modelo.PICAPE, Carroceria.Modelo.TAXI,
]
"""
new_m = """const MODELOS: Array[Carroceria.Modelo] = [
\tCarroceria.Modelo.SEDA, Carroceria.Modelo.HATCH, Carroceria.Modelo.PERUA,
\tCarroceria.Modelo.PICAPE, Carroceria.Modelo.TAXI,
\tCarroceria.Modelo.MAREA, Carroceria.Modelo.FUSCA,
]
"""
if old_m not in t4:
    raise SystemExit("MODELOS array not found")
t4 = t4.replace(old_m, new_m, 1)
t4 = t4.replace("## -1 monta os cinco; 0..4 monta so aquele, e a camera chega perto.",
                "## -1 monta todos; 0..N monta so aquele, e a camera chega perto.")
# Prefer cream dirty seed for MAREA in vitrine
old_loop = """\t\tvar modelo: Carroceria.Modelo = MODELOS[k]
\t\tvar tinta: Color = Carroceria.TINTAS[k * 2 % Carroceria.TINTAS.size()]
\t\tvar d := Carroceria.montar(modelo, tinta, k * 13)
"""
new_loop = """\t\tvar modelo: Carroceria.Modelo = MODELOS[k]
\t\tvar tinta: Color = Carroceria.TINTAS[k * 2 % Carroceria.TINTAS.size()]
\t\tvar semente := k * 13
\t\tif modelo == Carroceria.Modelo.MAREA:
\t\t\ttinta = Color(0.90, 0.88, 0.80)
\t\t\tsemente = 4410
\t\tvar d := Carroceria.montar(modelo, tinta, semente)
"""
if old_loop not in t4:
    raise SystemExit("vitrine loop not found")
t4 = t4.replace(old_loop, new_loop, 1)
p4.write_text(t4, encoding="utf-8")
print("carros_teste.gd OK")
print("all patches done")
