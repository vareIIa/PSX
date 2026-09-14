# -*- coding: utf-8 -*-
"""Patch kit_parque.gd: sharper coreto pyramid + clearer stairs; stronger church facade."""
from pathlib import Path

path = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\kit_parque.gd")
text = path.read_text(encoding="utf-8")

coreto_new = r'''## Coreto octogonal da praca: base de pedra, escada, oito pilares de madeira,
## guarda-corpo e telhado de telha. E o marco central da Praca da Matriz.
##
## Seis pilares liam como caramanchao generico; oito fecham o octogono que a
## referencia pede. O telhado e piramide pontuda de faces inclinadas (caixa_livre),
## nao caixas empilhadas — na nevoa a silhueta precisa ler como ponta, e as
## telhas precisam aparecer na face. A escada de pedra com peitoril e o que faz
## a base ler como podium e nao como caixa flutuando.
static func coreto(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, raio: float) -> void:
	var madeira := Color("5a4634")
	var pedra := Color("9a968c")
	var pedra_degrau := Color("b0aca2")
	var pedra_espelho := Color("7a766c")
	var telha := Color("a8683c")
	var telha_escura := Color("8a4e2c")
	var y_piso := 0.58

	# Base octogonal aproximada: caixa girada 22.5 graus + anel de pedra.
	KitModular.caixa_cor(sup, &"concreto_sujo", centro + Vector3(0.0, y_piso * 0.5, 0.0),
		Vector3(raio * 2.05, y_piso, raio * 2.05), pedra, PI / 8.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	for i in 8:
		var ang := TAU * float(i) / 8.0 + PI / 8.0
		var p := centro + Vector3(cos(ang), 0.0, sin(ang)) * (raio * 0.95)
		KitModular.caixa_cor(sup, &"concreto_sujo", p + Vector3(0.0, y_piso * 0.5, 0.0),
			Vector3(raio * 0.72, y_piso, 0.28), pedra, -ang + PI * 0.5,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Escada no lado +Z (sul da praca, olhando a igreja ao norte).
	# Quatro degraus com espelho escuro + piso claro e peitoris laterais —
	# sem isso some na nevoa e vira bloco unico.
	var n_degraus := 4
	var larg_escada := 1.55
	for degrau in n_degraus:
		var t := float(degrau)
		var h_deg := y_piso / float(n_degraus)
		var y_topo := (t + 1.0) * h_deg
		var prof := 0.38
		var afast := raio + 0.12 + t * 0.36
		# Espelho (riser).
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + Vector3(0.0, y_topo - h_deg * 0.5, afast - prof * 0.15),
			Vector3(larg_escada - t * 0.08, h_deg, 0.1), pedra_espelho, 0.0,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		# Piso do degrau (tread).
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + Vector3(0.0, y_topo - 0.04, afast),
			Vector3(larg_escada - t * 0.08, 0.08, prof), pedra_degrau, 0.0,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Peitoris / cheeks da escada.
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + Vector3(sx * (larg_escada * 0.5 + 0.08), y_piso * 0.45,
				raio + 0.55),
			Vector3(0.18, y_piso * 0.9, 1.55), pedra, 0.0,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Oito pilares e o guarda-corpo entre eles.
	var alt_pilar := 2.35
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var p := centro + Vector3(cos(ang), 0.0, sin(ang)) * (raio * 0.82)
		KitModular.caixa_cor(sup, &"tabua",
			p + Vector3(0.0, y_piso + alt_pilar * 0.5, 0.0),
			Vector3(0.16, alt_pilar, 0.16), madeira, ang,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		var ang2 := TAU * float(i + 1) / 8.0
		var a := centro + Vector3(cos(ang), 0.0, sin(ang)) * (raio * 0.82)
		var b := centro + Vector3(cos(ang2), 0.0, sin(ang2)) * (raio * 0.82)
		var meio := (a + b) * 0.5
		var comp := a.distance_to(b)
		var giro := atan2(b.x - a.x, b.z - a.z)
		KitModular.caixa_cor(sup, &"tabua",
			meio + Vector3(0.0, y_piso + 1.05, 0.0),
			Vector3(0.07, 0.08, comp), madeira, giro,
			PSXMesh.FACE_TODAS, 8.0)
		KitModular.caixa_cor(sup, &"tabua",
			meio + Vector3(0.0, y_piso + 0.55, 0.0),
			Vector3(0.05, 0.05, comp), madeira, giro,
			PSXMesh.FACE_TODAS, 8.0)

	# Telhado: beiral + piramide pontuda de 8 faces inclinadas (telha legivel).
	# Altura ~2.55 m sobre raio ~4 m — silhueta fecha em ponta (finial), bem
	# mais aguda que as caixas empilhadas da versao anterior.
	var y_beiral := y_piso + alt_pilar + 0.08
	var eave_r := raio * 1.18
	var roof_h := 2.55
	KitModular.caixa_cor(sup, &"teto", centro + Vector3(0.0, y_beiral, 0.0),
		Vector3(eave_r * 2.15, 0.14, eave_r * 2.15), telha_escura, PI / 8.0,
		PSXMesh.FACE_TODAS, 1.4)
	# Forro sob o beiral (leitura de volume oco).
	KitModular.caixa_cor(sup, &"tabua", centro + Vector3(0.0, y_beiral - 0.06, 0.0),
		Vector3(raio * 1.7, 0.08, raio * 1.7), madeira, PI / 8.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	var pitch := atan2(roof_h, eave_r)
	var hyp := sqrt(eave_r * eave_r + roof_h * roof_h)
	for i in 8:
		var ang := TAU * float(i) / 8.0 + PI / 8.0
		var face_w := 2.0 * eave_r * tan(PI / 8.0)
		# Centro da face a meia hipotenusa (media entre beiral e apex).
		var mid_r := eave_r * 0.48
		var mid_y := y_beiral + roof_h * 0.48
		var pos := centro + Vector3(cos(ang) * mid_r, mid_y, sin(ang) * mid_r)
		# Yaw: face olha pra fora; pitch: sobe ate a ponta.
		var b_face := Basis(Vector3.UP, -ang + PI * 0.5) * Basis(Vector3.RIGHT, pitch)
		# Largura media (afunila no apex) — 0.68 do cordao do beiral.
		var cor_face := telha if (i % 2) == 0 else telha_escura
		KitModular.caixa_livre(sup, &"teto", pos,
			Vector3(face_w * 0.68, hyp * 0.98, 0.11), b_face, cor_face, 1.15)
	# Ponta / finial — silhueta aguda na nevoa.
	KitModular.caixa_cor(sup, &"teto",
		centro + Vector3(0.0, y_beiral + roof_h * 0.82, 0.0),
		Vector3(0.55, roof_h * 0.28, 0.55), telha, PI / 8.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal",
		centro + Vector3(0.0, y_beiral + roof_h + 0.18, 0.0),
		Vector3(0.1, 0.42, 0.1), Color("3a3834"), 0.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	colisao.append({"tamanho": Vector3(raio * 2.1, y_piso + 0.2, raio * 2.1),
		"pos": centro + Vector3(0.0, y_piso * 0.5, 0.0)})


'''

igreja_new = r'''## Igreja colonial da Praca da Matriz: nave, torre sineira, cruz e porta em arco.
##
## `giro` aponta a fachada (0 = olha para +Z). A torre fica a esquerda da
## fachada, que e o lado que as refs mostram. Quoins em bloco, porta com
## ombreira/arco e cruz grossa — tudo pensado pra sobrar na nevoa densa.
static func igreja_matriz(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float = 0.0) -> void:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	var reboco := Color("e2d8c6")
	var mancha := Color("a89878")
	var quoin_a := Color("8a7a62")
	var quoin_b := Color("6e5e4a")
	var telha := Color("7a4e32")
	var porta := Color("1e3a28")
	var ombreira := Color("c8b89a")
	var trim := Color("2a2824")
	var largura := 11.0
	var fundura := 8.4
	var parede_h := 5.4

	# Nave.
	KitModular.caixa_cor(sup, &"reboco",
		centro + Vector3(0.0, parede_h * 0.5, 0.0),
		Vector3(largura, parede_h, fundura), reboco, giro,
		PSXMesh.FACE_TODAS, 2.5)
	# Saia de weathering na base — mancha que ancora o volume na nevoa.
	KitModular.caixa_cor(sup, &"tijolo",
		centro + frente * (fundura * 0.48) + Vector3(0.0, 0.55, 0.0),
		Vector3(largura * 0.98, 1.1, 0.2), mancha, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Quoins em blocos alternados na fachada (cantos +Z da nave).
	var n_quoin := 7
	for sx: float in [-1.0, 1.0]:
		for k in n_quoin:
			var yk := 0.35 + float(k) * (parede_h * 0.88 / float(n_quoin))
			var cor_q := quoin_a if (k % 2) == 0 else quoin_b
			var alt_q := parede_h * 0.88 / float(n_quoin) - 0.04
			KitModular.caixa_cor(sup, &"tijolo",
				centro + lado * (largura * 0.48 * sx) + frente * (fundura * 0.5 + 0.06)
					+ Vector3(0.0, yk, 0.0),
				Vector3(0.55, alt_q, 0.38), cor_q, giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
		# Quoin tambem no canto traseiro (silhueta lateral).
		KitModular.caixa_cor(sup, &"tijolo",
			centro + lado * (largura * 0.48 * sx) + frente * (fundura * -0.48)
				+ Vector3(0.0, parede_h * 0.45, 0.0),
			Vector3(0.42, parede_h * 0.9, 0.42), mancha, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Frontao e cruz (cruz grossa, projetada pra frente — le na nevoa).
	KitModular.caixa_cor(sup, &"reboco",
		centro + frente * (fundura * 0.02) + Vector3(0.0, parede_h + 0.55, 0.0),
		Vector3(largura * 0.92, 1.1, 0.55), reboco, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"teto",
		centro + Vector3(0.0, parede_h + 0.35, 0.0),
		Vector3(largura + 0.6, 0.35, fundura + 0.6), telha, giro,
		PSXMesh.FACE_TODAS, 2.0)
	var cruz_c := centro + frente * (fundura * 0.08) + Vector3(0.0, parede_h + 1.75, 0.0)
	KitModular.caixa_cor(sup, &"metal",
		cruz_c, Vector3(0.16, 1.15, 0.16), trim, giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal",
		cruz_c + Vector3(0.0, 0.28, 0.0), Vector3(0.78, 0.14, 0.14), trim, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Porta em arco: ombreira clara + folha escura + arco em degraus.
	var porta_c := centro + frente * (fundura * 0.5 + 0.05) + Vector3(0.0, 1.55, 0.0)
	# Ombreira / marco.
	KitModular.caixa_cor(sup, &"concreto_sujo",
		porta_c + Vector3(0.0, 0.05, 0.0), Vector3(2.15, 3.35, 0.22), ombreira, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Folha da porta (mais escura que o marco).
	KitModular.caixa_cor(sup, &"porta", porta_c, Vector3(1.75, 3.05, 0.12), porta, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Arco: tres degraus acima da porta + chave.
	KitModular.caixa_cor(sup, &"porta",
		porta_c + Vector3(0.0, 1.55, 0.02), Vector3(1.75, 0.55, 0.12), porta, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		porta_c + Vector3(0.0, 1.85, 0.04), Vector3(1.95, 0.35, 0.18), ombreira, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		porta_c + Vector3(0.0, 2.12, 0.04), Vector3(1.45, 0.28, 0.18), ombreira, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		porta_c + Vector3(0.0, 2.32, 0.04), Vector3(0.85, 0.22, 0.18), ombreira, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Travessa / ferragem da porta (leitura de porta dupla).
	KitModular.caixa_cor(sup, &"metal",
		porta_c + Vector3(0.0, 0.0, 0.08), Vector3(0.08, 2.9, 0.06), trim, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"janela_apagada",
			centro + frente * (fundura * 0.5 + 0.05) + lado * (2.7 * sx)
				+ Vector3(0.0, 3.6, 0.0),
			Vector3(1.05, 1.25, 0.1), Color("2a2a28"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		# Arco simples sobre cada janela.
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + frente * (fundura * 0.5 + 0.06) + lado * (2.7 * sx)
				+ Vector3(0.0, 4.3, 0.0),
			Vector3(1.15, 0.22, 0.12), ombreira, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"janela_apagada",
		centro + frente * (fundura * 0.5 + 0.05) + Vector3(0.0, 5.05, 0.0),
		Vector3(0.7, 0.7, 0.1), Color("2a2a28"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Torre sineira a esquerda da fachada.
	var torre := centro + lado * (largura * 0.42 + 1.3) - frente * 0.4
	var torre_h := 8.2
	KitModular.caixa_cor(sup, &"reboco", torre + Vector3(0.0, torre_h * 0.5, 0.0),
		Vector3(3.2, torre_h, 3.2), reboco, giro, PSXMesh.FACE_TODAS, 2.5)
	# Quoins da torre (frente).
	for sx: float in [-1.0, 1.0]:
		for k in 6:
			var yk := 0.4 + float(k) * 1.15
			var cor_q := quoin_a if (k % 2) == 0 else quoin_b
			KitModular.caixa_cor(sup, &"tijolo",
				torre + lado * (1.5 * sx) + frente * 1.62 + Vector3(0.0, yk, 0.0),
				Vector3(0.4, 1.0, 0.28), cor_q, giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Vao do sino.
	KitModular.caixa_cor(sup, &"metal",
		torre + frente * 1.62 + Vector3(0.0, 6.55, 0.0),
		Vector3(1.7, 1.7, 0.14), Color("121210"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal",
		torre + Vector3(0.0, 6.5, 0.0), Vector3(0.7, 0.7, 0.7),
		Color("5a5648"), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"teto", torre + Vector3(0.0, torre_h + 0.35, 0.0),
		Vector3(3.7, 0.7, 3.7), telha, giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal",
		torre + Vector3(0.0, torre_h + 0.95, 0.0), Vector3(0.08, 0.55, 0.08),
		trim, giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	colisao.append({"tamanho": Vector3(largura + 0.4, parede_h, fundura + 0.4),
		"pos": centro + Vector3(0.0, parede_h * 0.5, 0.0)})
	colisao.append({"tamanho": Vector3(3.4, torre_h, 3.4),
		"pos": torre + Vector3(0.0, torre_h * 0.5, 0.0)})


'''

start = text.find("## Coreto octogonal da praca:")
if start < 0:
    start = text.find("## Coreto:")
end = text.find("## Poste de praca estilo lanterna:")
assert start >= 0 and end > start, (start, end)
new_text = text[:start] + coreto_new + igreja_new + text[end:]
path.write_text(new_text, encoding="utf-8")
print("OK patched", path)
print("new size", len(new_text.splitlines()), "lines")
assert "roof_h := 2.55" in new_text
assert "n_quoin := 7" in new_text
assert 'caixa_livre(sup, &"teto"' in new_text
print("sanity OK")
