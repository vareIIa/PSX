static func coreto(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, raio: float) -> void:
	var madeira := Color("5a4634")
	var pedra := Color("9a968c")
	var pedra_degrau := Color("b0aca2")
	var pedra_espelho := Color("7a766c")
	var telha := Color("c87840")
	var telha_escura := Color("a85830")
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
	# Quatro degraus com espelho escuro + piso claro e peitoris laterais â€”
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

	# Oito pilares; guarda-corpo pula o vao sul (+Z) â€” portal pro eixo da igreja.
	var alt_pilar := 2.35
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var p := centro + Vector3(cos(ang), 0.0, sin(ang)) * (raio * 0.82)
		KitModular.caixa_cor(sup, &"tabua",
			p + Vector3(0.0, y_piso + alt_pilar * 0.5, 0.0),
			Vector3(0.16, alt_pilar, 0.16), madeira, ang,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		var ang2 := TAU * float(i + 1) / 8.0
		# Segmento que olha pro sul (escada / pin Cine2): sem grade.
		var mid_ang := ang + (ang2 - ang) * 0.5
		if sin(mid_ang) > 0.55:
			continue
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

	# Telhado octogonal (ref 03): SO piramide em degraus de telha + finial.
	# Faces caixa_livre (mesmo com pitch corrigido) ainda liam V/borboleta
	# de perfil no eixo/praca_5 â€” o nucleo escalonado le pico sem ambiguidade.
	var y_beiral := y_piso + alt_pilar + 0.08
	var eave_r := raio * 1.25
	var roof_h := 4.4
	KitModular.caixa_cor(sup, &"teto", centro + Vector3(0.0, y_beiral, 0.0),
		Vector3(eave_r * 2.3, 0.2, eave_r * 2.3), telha_escura, PI / 8.0,
		PSXMesh.FACE_TODAS, 1.35)
	KitModular.caixa_cor(sup, &"tabua", centro + Vector3(0.0, y_beiral - 0.08, 0.0),
		Vector3(raio * 1.7, 0.1, raio * 1.7), madeira, PI / 8.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	var n_camadas := 7
	for c in n_camadas:
		var t := float(c) / float(maxi(1, n_camadas - 1))
		# Afunila forte: base larga -> ponta â€” silhueta /\, nunca V.
		var lado := eave_r * 2.05 * lerpf(1.0, 0.08, t * t)
		var y := y_beiral + 0.25 + roof_h * t
		var cor_c := telha if (c % 2) == 0 else telha_escura
		var giro_c := PI / 8.0 if (c % 2) == 0 else 0.0
		KitModular.caixa_cor(sup, &"teto",
			centro + Vector3(0.0, y, 0.0),
			Vector3(lado, 0.72, lado), cor_c, giro_c,
			PSXMesh.FACE_TODAS, 1.2)
	# Ponta unica (pico).
	KitModular.caixa_cor(sup, &"teto",
		centro + Vector3(0.0, y_beiral + roof_h + 0.55, 0.0),
		Vector3(0.55, 0.7, 0.55), telha, PI / 8.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal",
		centro + Vector3(0.0, y_beiral + roof_h + 1.15, 0.0),
		Vector3(0.1, 0.6, 0.1), Color("3a3834"), 0.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	colisao.append({"tamanho": Vector3(raio * 2.1, y_piso + 0.2, raio * 2.1),
		"pos": centro + Vector3(0.0, y_piso * 0.5, 0.0)})


## Igreja colonial da Praca da Matriz: nave branca manchada, torre a esquerda,
## porta ESCURA no muro da fachada, cruz pequena no frontao.
##
## A versao anterior botava portal freestanding +1,4 m a frente da nave, cruz
## punch mid-air e rim `janela_acesa` na ombreira. Na nevoa densa isso lia como
## retangulo luminoso ("construcao na frente"), nao como a capela branca das
## refs `PRINTS/ref_praca_matriz`. Aqui a porta fica no plano da parede e a
## cruz mora no pico do frontao â€” silhueta que sobrevive a 480x270.
