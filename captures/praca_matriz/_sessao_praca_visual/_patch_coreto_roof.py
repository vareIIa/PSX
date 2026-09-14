from pathlib import Path
path = Path(r"C:\Users\\Administrator\\Documents\\Codes\\Games\\PSX\game\src\world\kit_parque.gd")
text = path.read_text(encoding="utf-8")
start = text.index("\t# Telhado octogonal (ref 03):")
# fallback if comment changed
if "# Telhado octogonal" not in text[start:start+80]:
    start = text.index("\t# Telhado")
# find end: colisao.append of coreto, then blank lines before igreja comment
end = text.index("\tcolisao.append({\"tamanho\": Vector3(raio * 2.1, y_piso + 0.2, raio * 2.1),", start)
# include through the colisao block end (keep colisao as-is)
# Actually replace only roof section before colisao
roof = r'''	# Telhado octogonal (ref 03): 8 LAJES na inclinacao, face LARGA = telha.
	# Causa do V/borboleta: tentativas com size (largura, hip, espessura) deixavam
	# a espessura de perfil pro eixo — oito arestas finas = V. Aqui Y local e a
	# NORMAL do telhado (espessura), X = corda do beiral, Z = hipotenusa.
	# Face aparece do lado oposto ao cross: se nrm.y < 0, inverte.
	var y_beiral := y_piso + alt_pilar + 0.08
	var eave_r := raio * 1.22
	var roof_h := 3.6
	var apex := centro + Vector3(0.0, y_beiral + roof_h, 0.0)
	# Beiral / forro — volume sob a ponta.
	KitModular.caixa_cor(sup, &"teto", centro + Vector3(0.0, y_beiral, 0.0),
		Vector3(eave_r * 2.2, 0.16, eave_r * 2.2), telha_escura, PI / 8.0,
		PSXMesh.FACE_TODAS, 1.35)
	KitModular.caixa_cor(sup, &"tabua", centro + Vector3(0.0, y_beiral - 0.07, 0.0),
		Vector3(raio * 1.72, 0.1, raio * 1.72), madeira, PI / 8.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	for i in 8:
		var ang0 := TAU * float(i) / 8.0 + PI / 8.0
		var ang1 := TAU * float(i + 1) / 8.0 + PI / 8.0
		var p0 := Vector3(centro.x + cos(ang0) * eave_r, y_beiral, centro.z + sin(ang0) * eave_r)
		var p1 := Vector3(centro.x + cos(ang1) * eave_r, y_beiral, centro.z + sin(ang1) * eave_r)
		var mid_eave := (p0 + p1) * 0.5
		var mid := (mid_eave + apex) * 0.5
		var along := mid_eave - apex
		var edge := p1 - p0
		var hyp := along.length()
		var width := edge.length()
		if hyp < 0.05 or width < 0.05:
			continue
		var along_n := along / hyp
		var edge_n := edge / width
		var nrm := edge_n.cross(along_n)
		if nrm.length_squared() < 1e-6:
			continue
		nrm = nrm.normalized()
		if nrm.y < 0.0:
			nrm = -nrm
		# X=edge, Y=normal (espessura/telha), Z=along (beiral<-apex).
		var b_face := Basis(edge_n, nrm, along_n)
		var cor_face := telha if (i % 2) == 0 else telha_escura
		KitModular.caixa_livre(sup, &"teto", mid,
			Vector3(width * 0.98, 0.16, hyp * 0.98), b_face, cor_face, 1.1)
	# Pico / finial — ponta da silhueta sem engolir as faces.
	KitModular.caixa_cor(sup, &"teto",
		centro + Vector3(0.0, y_beiral + roof_h * 0.92, 0.0),
		Vector3(0.42, 0.55, 0.42), telha, PI / 8.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal",
		centro + Vector3(0.0, y_beiral + roof_h + 0.35, 0.0),
		Vector3(0.1, 0.55, 0.1), Color("3a3834"), 0.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

'''
# Also update the header comment that still says wrong thing
old_hdr = """## Coreto octogonal da praca: base de pedra, escada, oito pilares de madeira,
## guarda-corpo e telhado de telha. E o marco central da Praca da Matriz.
##
## Seis pilares liam como caramanchao generico; oito fecham o octogono que a
## referencia pede. O telhado e piramide pontuda de faces inclinadas (caixa_livre),
## nao caixas empilhadas — na nevoa a silhueta precisa ler como ponta, e as
## telhas precisam aparecer na face. A escada de pedra com peitoril e o que faz
## a base ler como podium e nao como caixa flutuando."""
new_hdr = """## Coreto octogonal da praca: base de pedra, escada, oito pilares de madeira,
## guarda-corpo e telhado de telha. E o marco central da Praca da Matriz.
##
## Seis pilares liam como caramanchao generico; oito fecham o octogono que a
## referencia pede. O telhado e 8 lajes (caixa_livre) com Y=normal da agua —
## size (corda, espessura, hip). Espessura no eixo errado lia V/borboleta.
## A escada de pedra com peitoril faz a base ler como podium."""
if old_hdr in text:
    text = text.replace(old_hdr, new_hdr, 1)
out = text[:start] + roof + text[end:]
path.write_text(out, encoding="utf-8", newline="\n")
# save fragment for the other bot
Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\captures\praca_matriz\_sessao_praca_visual\coreto_roof_PATCH.gd").write_text(roof, encoding="utf-8")
print("patched ok, roof chars", len(roof))
# sanity: no stepped pyramid loop
t2 = path.read_text(encoding="utf-8")
c0 = t2.index("static func coreto")
c1 = t2.index("static func igreja_matriz")
body = t2[c0:c1]
assert "nrm.y < 0.0" in body
assert "n_camadas" not in body
assert "Vector3(width * 0.98, 0.16, hyp * 0.98)" in body
print("sanity ok")
