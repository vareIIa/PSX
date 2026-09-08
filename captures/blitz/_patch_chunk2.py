from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\chunk_builder.gd")
text = p.read_text(encoding="utf-8")
if "static func _pintura_estacionamento" in text:
    print("def already exists")
else:
    fn = '''
## Zebrado do acostamento: barras amarelo-sujo no meio-fio (faixa de
## estacionamento). Marca o espaco da blitz sem subir na calcada.
static func _pintura_estacionamento(sup: Dictionary, bordas: Dictionary,
		px0: float, pz0: float, _tinta: Color) -> void:
	var amarelo := Color(0.78, 0.68, 0.22)
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
    text = text.replace("static func _faixa_pedestre", fn + "static func _faixa_pedestre", 1)
    p.write_text(text, encoding="utf-8")
    print("def inserted")
print("ok")
