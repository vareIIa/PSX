from pathlib import Path

pb = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\parque_builder.gd")
t = pb.read_text(encoding="utf-8")

old = """## Layout da Praca da Matriz: igreja ao norte, coreto no centro, casas nas laterais.
##
## A praca util e um retangulo APERTADO no miolo (~40x36 m). A quadra pode ter
## 90 m de fundo, mas fog_denso corta em 18 m — igreja na borda norte da quadra
## some na nevoa e a abertura da Cinematic 2 vira pedra cinza. Por isso igreja,
## coreto e casas cabem juntos no alcance da nevoa densa.
static func _praca_matriz(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], plano: Dictionary, desloc: Vector2) -> void:
	var centro_q: Vector2 = plano[\"centro\"]
	var centro: Vector2 = centro_q + desloc
	var sem := int(plano[\"semente\"])
	var y := KitParque.Y_CALCAMENTO
	# Praca util centrada: igreja 14 m ao norte do coreto, casas a 12 m das laterais.
	var praca := Rect2(centro_q.x - 18.0, centro_q.y - 16.0, 36.0, 34.0)

	var igreja := Vector2(centro_q.x, praca.position.y + 7.0) + desloc
	if _neste_chunk(igreja):
		KitParque.igreja_matriz(sup, colisao,
			Vector3(igreja.x, y, igreja.y), PI)

	if _neste_chunk(centro):
		KitParque.coreto(sup, colisao, Vector3(centro.x, y, centro.y), 3.8)

	var n_casas := 3
	for lado_s: float in [-1.0, 1.0]:
		for i in n_casas:
			var t := (float(i) + 0.5) / float(n_casas)
			var x := praca.position.x + 3.6 if lado_s < 0.0 else praca.end.x - 3.6
			var z := lerpf(praca.position.y + 10.0, praca.end.y - 3.0, t)
			var p := Vector2(x, z) + desloc
			if not _neste_chunk(p):
				continue
			var giro := PI * 0.5 if lado_s < 0.0 else -PI * 0.5
			KitParque.casa_colonial_baixa(sup, colisao,
				Vector3(p.x, y, p.y), giro, lerpf(6.8, 8.0, _ale(sem, i, 101)))
"""

new = """## Layout da Praca da Matriz: igreja ao norte, coreto no miolo, casas nas laterais.
##
## Packing N–S (Cine2 pin 270/-40, fog_denso ~18 m):
##   plano.centro ~= (272, -56)  — anel de lanternas / casas laterais ancorados aqui
##   coreto  = centro + (0, +5)  -> mundo ~ (272, -51)   // 11 m do pin
##   igreja  = centro + (0, -5)  -> mundo ~ (272, -61)   // centro 21 m; fachada ~16.8 m
##   fachada olha +Z (sul, giro 0) para o pin; fundura 8.4 -> face sul = z_igreja+4.2
## Lateral (X ±18, postes em ±7/±10) intacto — so aperta o eixo N–S.
static func _praca_matriz(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], plano: Dictionary, desloc: Vector2) -> void:
	var centro_q: Vector2 = plano[\"centro\"]
	var sem := int(plano[\"semente\"])
	var y := KitParque.Y_CALCAMENTO
	# Anel lateral ancorado no centro da quadra (nao mover E–W).
	var praca := Rect2(centro_q.x - 18.0, centro_q.y - 16.0, 36.0, 34.0)

	# Coreto 5 m ao sul do centro geometrico — libera espaco pra igreja entrar na nevoa.
	var coreto_p := Vector2(centro_q.x, centro_q.y + 5.0) + desloc
	if _neste_chunk(coreto_p):
		KitParque.coreto(sup, colisao, Vector3(coreto_p.x, y, coreto_p.y), 3.8)

	# Igreja 5 m ao norte do centro (~10 m do coreto). giro 0 = fachada para +Z (pin).
	var igreja := Vector2(centro_q.x, centro_q.y - 5.0) + desloc
	if _neste_chunk(igreja):
		KitParque.igreja_matriz(sup, colisao,
			Vector3(igreja.x, y, igreja.y), 0.0)

	var n_casas := 3
	for lado_s: float in [-1.0, 1.0]:
		for i in n_casas:
			var t := (float(i) + 0.5) / float(n_casas)
			var x := praca.position.x + 3.6 if lado_s < 0.0 else praca.end.x - 3.6
			# Casas acompanham o packing N–S apertado (coreto sul / igreja norte).
			var z := lerpf(centro_q.y - 8.0, centro_q.y + 14.0, t)
			var p := Vector2(x, z) + desloc
			if not _neste_chunk(p):
				continue
			var giro := PI * 0.5 if lado_s < 0.0 else -PI * 0.5
			KitParque.casa_colonial_baixa(sup, colisao,
				Vector3(p.x, y, p.y), giro, lerpf(6.8, 8.0, _ale(sem, i, 101)))
"""

if old not in t:
    raise SystemExit("OLD BLOCK NOT FOUND in parque_builder.gd")
pb.write_text(t.replace(old, new, 1), encoding="utf-8")
print("parque_builder.gd: _praca_matriz updated")

# Update mobiliario proibido zone for church (now closer to centro)
t2 = pb.read_text(encoding="utf-8")
old_mob = """\t# Zona do coreto + igreja sem banco/poste em cima.
\tvar proibido: Array[Rect2] = [
\t\tRect2(centro.x - 5.5, centro.y - 5.5, 11.0, 11.0),
\t\tRect2(centro.x - 8.0, praca.position.y, 16.0, 12.0),
\t]
"""
new_mob = """\t# Zona do coreto (sul) + igreja (norte) sem banco/poste em cima.
\tvar proibido: Array[Rect2] = [
\t\tRect2(centro.x - 5.5, centro.y + 5.0 - 5.5, 11.0, 11.0),
\t\tRect2(centro.x - 8.0, centro.y - 5.0 - 6.0, 16.0, 12.0),
\t]
"""
if old_mob not in t2:
    raise SystemExit("OLD MOB BLOCK NOT FOUND")
pb.write_text(t2.replace(old_mob, new_mob, 1), encoding="utf-8")
print("parque_builder.gd: mobiliario proibido updated")

# Raise coreto roof tip
kp = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\kit_parque.gd")
kt = kp.read_text(encoding="utf-8")
old_roof = """\t# Telhado: beiral + piramide pontuda de 8 faces inclinadas (telha legivel).
\t# Altura ~2.55 m sobre raio ~4 m — silhueta fecha em ponta (finial), bem
\t# mais aguda que as caixas empilhadas da versao anterior.
\tvar y_beiral := y_piso + alt_pilar + 0.08
\tvar eave_r := raio * 1.18
\tvar roof_h := 3.35
"""
new_roof = """\t# Telhado: beiral + piramide pontuda de 8 faces inclinadas (telha legivel).
\t# roof_h 4.2: ponta le de longe (pin Cine2) sem engolir o close debaixo do beiral.
\tvar y_beiral := y_piso + alt_pilar + 0.08
\tvar eave_r := raio * 1.18
\tvar roof_h := 4.2
"""
if old_roof not in kt:
    raise SystemExit("OLD ROOF BLOCK NOT FOUND")
kt = kt.replace(old_roof, new_roof, 1)
old_fin = """\t# Ponta / finial — silhueta aguda na nevoa.
\tKitModular.caixa_cor(sup, &\"teto\",
\t\tcentro + Vector3(0.0, y_beiral + roof_h * 0.82, 0.0),
\t\tVector3(0.55, roof_h * 0.28, 0.55), telha, PI / 8.0,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\tKitModular.caixa_cor(sup, &\"metal\",
\t\tcentro + Vector3(0.0, y_beiral + roof_h + 0.18, 0.0),
\t\tVector3(0.1, 0.42, 0.1), Color(\"3a3834\"), 0.0,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
"""
new_fin = """\t# Ponta / finial — silhueta aguda na nevoa (haste um pouco mais alta).
\tKitModular.caixa_cor(sup, &\"teto\",
\t\tcentro + Vector3(0.0, y_beiral + roof_h * 0.78, 0.0),
\t\tVector3(0.48, roof_h * 0.32, 0.48), telha, PI / 8.0,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
\tKitModular.caixa_cor(sup, &\"metal\",
\t\tcentro + Vector3(0.0, y_beiral + roof_h + 0.28, 0.0),
\t\tVector3(0.1, 0.55, 0.1), Color(\"3a3834\"), 0.0,
\t\tPSXMesh.FACE_TODAS, QUAD_FOLHA)
"""
if old_fin not in kt:
    raise SystemExit("OLD FINIAL BLOCK NOT FOUND")
kp.write_text(kt.replace(old_fin, new_fin, 1), encoding="utf-8")
print("kit_parque.gd: coreto roof raised")
