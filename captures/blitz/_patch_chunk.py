from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\chunk_builder.gd")
text = p.read_text(encoding="utf-8")

# Replace meia_pista for asphalt widths in _solo
old_solo = """static func _solo(sup: Dictionary, colisao: Array[Dictionary], cx: int, cz: int,
		bordas: Dictionary, lim: Rect2, rng: RandomNumberGenerator) -> void:
	var px0 := MalhaUrbana.meia_pista(bordas["x0"])
	var px1 := MalhaUrbana.meia_pista(bordas["x1"])
	var pz0 := MalhaUrbana.meia_pista(bordas["z0"])
	var pz1 := MalhaUrbana.meia_pista(bordas["z1"])"""
new_solo = """static func _solo(sup: Dictionary, colisao: Array[Dictionary], cx: int, cz: int,
		bordas: Dictionary, lim: Rect2, rng: RandomNumberGenerator) -> void:
	# Asfalto = rolamento + estacionamento. Faixas de carro continuam em
	# meia_pista; o acostamento fica na faixa externa ate o meio-fio.
	var px0 := MalhaUrbana.meia_asfalto(bordas["x0"])
	var px1 := MalhaUrbana.meia_asfalto(bordas["x1"])
	var pz0 := MalhaUrbana.meia_asfalto(bordas["z0"])
	var pz1 := MalhaUrbana.meia_asfalto(bordas["z1"])"""
if old_solo not in text:
    raise SystemExit("_solo header missing")
text = text.replace(old_solo, new_solo, 1)
print("_solo ok")

# Trees: plant on sidewalk after asphalt edge
text2 = text.replace(
    'var x := MalhaUrbana.meia_pista(bordas["x0"]) + DA_GUIA',
    'var x := MalhaUrbana.meia_asfalto(bordas["x0"]) + DA_GUIA')
text2 = text2.replace(
    'var x := TAM - MalhaUrbana.meia_pista(bordas["x1"]) - DA_GUIA',
    'var x := TAM - MalhaUrbana.meia_asfalto(bordas["x1"]) - DA_GUIA')
text2 = text2.replace(
    'var z := MalhaUrbana.meia_pista(bordas["z0"]) + DA_GUIA',
    'var z := MalhaUrbana.meia_asfalto(bordas["z0"]) + DA_GUIA')
text2 = text2.replace(
    'var z := TAM - MalhaUrbana.meia_pista(bordas["z1"]) - DA_GUIA',
    'var z := TAM - MalhaUrbana.meia_asfalto(bordas["z1"]) - DA_GUIA')
if text2 == text:
    raise SystemExit("arborizacao replacements failed")
text = text2
print("arborizacao ok")

# _recuo_esquina: meia param is already passed; callers use Vias.meia_x which is meia_pista.
# Update callers to pass meia_asfalto so posts sit at real curb.
old_perto = """	var ox := _recuo_esquina(Vias.meia_x(cx), MalhaUrbana.via_x(cx))
	var oz := _recuo_esquina(Vias.meia_z(cz), MalhaUrbana.via_z(cz))"""
new_perto = """	var ox := _recuo_esquina(MalhaUrbana.meia_asfalto(MalhaUrbana.via_x(cx)), MalhaUrbana.via_x(cx))
	var oz := _recuo_esquina(MalhaUrbana.meia_asfalto(MalhaUrbana.via_z(cz)), MalhaUrbana.via_z(cz))"""
if old_perto not in text:
    raise SystemExit("perto_de_semaforo missing")
text = text.replace(old_perto, new_perto, 1)
print("perto ok")

# Add parking zebra paint at end of _pintura before the function ends
# Find the retencao block end and add estacionamento paint
anchor = """			KitModular.chao(sup, &\"marca_via\",
				Vector3(x_lin - 0.14, 0.014, 0.08),
				Vector2(0.28, maxf(0.4, pz0 - 0.16)), 6.0, tinta)
"""
# Also paint parking regardless of cruzamento - add after _pintura function start area
# Better: append call at end of _pintura
needle = """			KitModular.chao(sup, &\"marca_via\",
				Vector3(x_lin - 0.14, 0.014, 0.08),
				Vector2(0.28, maxf(0.4, pz0 - 0.16)), 6.0, tinta)


## As quatro faixas de zebra"""
# The blank lines might vary - search differently
idx = text.find("## As quatro faixas de zebra")
if idx < 0:
    raise SystemExit("zebra func missing")
# Insert parking paint call before that function, at end of _pintura
# Find last part of _pintura - the retencao closing
insert_at = text.rfind("\n\n\n", 0, idx)
# Actually look for end of _pintura - the function before _faixa_pedestre
faixa_idx = text.find("static func _faixa_pedestre")
pintura_end = text.rfind("\n", 0, faixa_idx)
# Insert before _faixa_pedestre a call - no, inject into _pintura body
# Find "if Vias.existe_cruzamento" block end - simpler to add after eixo paint

marker2 = """	if bordas[\"z0\"] == MalhaUrbana.Via.AVENIDA:
		for i in 5:
			var x := 1.6 + float(i) * 6.4
			KitModular.chao(sup, &\"marca_via\", Vector3(x, 0.012, 0.0),
				Vector2(3.2, 0.16), 6.0, tinta)

	# Faixa de pedestre:"""
repl2 = """	if bordas[\"z0\"] == MalhaUrbana.Via.AVENIDA:
		for i in 5:
			var x := 1.6 + float(i) * 6.4
			KitModular.chao(sup, &\"marca_via\", Vector3(x, 0.012, 0.0),
				Vector2(3.2, 0.16), 6.0, tinta)

	_pintura_estacionamento(sup, bordas, px0, pz0, tinta)

	# Faixa de pedestre:"""
if marker2 not in text:
    raise SystemExit("pintura axis marker missing")
text = text.replace(marker2, repl2, 1)
print("pintura call ok")

# Add the new function before _faixa_pedestre
fn = '''
## Zebrado do acostamento: barras diagonais amarelo-sujo no meio-fio.
## Marca o espaco onde a blitz encosta a viatura sem subir na calcada.
static func _pintura_estacionamento(sup: Dictionary, bordas: Dictionary,
		px0: float, pz0: float, tinta: Color) -> void:
	var amarelo := Color(0.78, 0.68, 0.22)
	_zebrar_borda(sup, bordas["x0"], true, true, px0, amarelo)
	_zebrar_borda(sup, bordas["x1"], true, false, px0, amarelo)
	_zebrar_borda(sup, bordas["z0"], false, true, pz0, amarelo)
	_zebrar_borda(sup, bordas["z1"], false, false, pz0, amarelo)


static func _zebrar_borda(sup: Dictionary, via: int, eixo_x: bool, no_zero: bool,
		meia_asf: float, cor: Color) -> void:
	var est := MalhaUrbana.largura_estacionamento(via)
	if est < 0.4 or meia_asf < 0.4:
		return
	var pista := MalhaUrbana.meia_pista(via)
	var y := 0.013
	# Barras a cada 1,4 m ao longo da via, cobrindo so a faixa de estacionamento.
	for i in 10:
		var t := 1.2 + float(i) * 3.0
		if t > MalhaUrbana.TAM - 1.2:
			break
		if eixo_x:
			var x0 := (0.0 if no_zero else MalhaUrbana.TAM - meia_asf) + pista
			if not no_zero:
				x0 = MalhaUrbana.TAM - meia_asf
				# estacionamento fica na borda externa: de (TAM-meia_asf) ate (TAM-pista)
				x0 = MalhaUrbana.TAM - meia_asf
			var x := (pista if no_zero else MalhaUrbana.TAM - meia_asf)
			var larg := est
			KitModular.chao(sup, &"marca_via", Vector3(x, y, t),
				Vector2(larg, 0.35), 6.0, cor)
		else:
			var z := (pista if no_zero else MalhaUrbana.TAM - meia_asf)
			KitModular.chao(sup, &"marca_via", Vector3(t, y, z),
				Vector2(0.35, est), 6.0, cor)


'''
# Fix the zebra function - the x1/z1 logic was messy. Rewrite cleaner.
fn = '''
## Zebrado do acostamento: barras amarelo-sujo no meio-fio (faixa de
## estacionamento). Marca o espaco da blitz sem subir na calcada.
static func _pintura_estacionamento(sup: Dictionary, bordas: Dictionary,
		px0: float, pz0: float, _tinta: Color) -> void:
	var amarelo := Color(0.78, 0.68, 0.22)
	# x0: asfalto em x=[0, px0]; estacionamento na borda externa (perto do meio-fio).
	_zebrar_faixa(sup, bordas["x0"], px0, true, true, amarelo)
	_zebrar_faixa(sup, bordas["x1"], px0, true, false, amarelo)
	_zebrar_faixa(sup, bordas["z0"], pz0, false, true, amarelo)
	_zebrar_faixa(sup, bordas["z1"], pz0, false, false, amarelo)


## `no_zero`: borda em coordenada 0 do chunk; senao, borda em TAM.
static func _zebrar_faixa(sup: Dictionary, via: int, meia_asf: float,
		eixo_ao_longo_z: bool, no_zero: bool, cor: Color) -> void:
	var est := MalhaUrbana.largura_estacionamento(via)
	if est < 0.4 or meia_asf < 0.4:
		return
	var pista := MalhaUrbana.meia_pista(via)
	var y := 0.013
	# Origem da faixa de estacionamento (do centro da via para o meio-fio).
	var origem_trans := (pista if no_zero else MalhaUrbana.TAM - meia_asf)
	for i in 10:
		var ao_longo := 1.4 + float(i) * 3.0
		if ao_longo > MalhaUrbana.TAM - 1.4:
			break
		if eixo_ao_longo_z:
			KitModular.chao(sup, &"marca_via",
				Vector3(origem_trans, y, ao_longo),
				Vector2(est, 0.38), 6.0, cor)
		else:
			KitModular.chao(sup, &"marca_via",
				Vector3(ao_longo, y, origem_trans),
				Vector2(0.38, est), 6.0, cor)


'''
if "_pintura_estacionamento" not in text:
    text = text.replace("static func _faixa_pedestre", fn + "static func _faixa_pedestre", 1)
    print("fn inserted")
else:
    print("fn already there")

p.write_text(text, encoding="utf-8")
print("DONE chunk_builder")
