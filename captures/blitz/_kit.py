from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\kit_blitz.gd")
text = p.read_text(encoding="utf-8")
if "zebrado_acostamento" in text:
    print("already")
else:
    extra = '''

## Pintura zebrada do acostamento (barras amarelas procedurais).
static func zebrado_acostamento(comprimento: float, largura: float) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "ZebradoAcost"
	var dados := PSXMesh.dados_vazios()
	var n := maxi(3, int(comprimento / 1.6))
	for i in n:
		var z := -comprimento * 0.5 + 0.8 + float(i) * 1.6
		var barra := PSXMesh.box_dados(Vector3(largura, 0.03, 0.42), 0.8, 2.0,
			Color(0.82, 0.72, 0.18))
		PSXMesh.acumular(dados, barra,
			Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, z)))
	var mi := MeshInstance3D.new()
	mi.name = "Zebras"
	mi.mesh = PSXMesh.dados_para_mesh(dados)
	mi.material_override = load(MAT_FAIXA)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(mi)
	return raiz
'''
    text = text.rstrip() + "\n" + extra
    p.write_text(text + "\n", encoding="utf-8")
    print("kit_blitz zebrado added")
