static func coreto(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, raio: float) -> void:
	KitModular.caixa_cor(sup, &"concreto_sujo", centro + Vector3(0.0, 0.22, 0.0),
		Vector3(raio * 2.0, 0.44, raio * 2.0), Color("aba79c"), PI * 0.125,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	for i in 6:
		var ang := TAU * float(i) / 6.0
		KitModular.caixa_cor(sup, &"tabua",
			centro + Vector3(cos(ang), 0.0, sin(ang)) * (raio * 0.86)
				+ Vector3(0.0, 1.6, 0.0),
			Vector3(0.18, 2.3, 0.18), Color("6d5a44"), ang,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	KitModular.caixa_cor(sup, &"metal_enferrujado", centro + Vector3(0.0, 2.9, 0.0),
		Vector3(raio * 2.3, 0.18, raio * 2.3), Color("6a5f52"), PI * 0.125,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal_enferrujado", centro + Vector3(0.0, 3.25, 0.0),
		Vector3(raio * 1.3, 0.5, raio * 1.3), Color("6a5f52"), PI * 0.125,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	colisao.append({"tamanho": Vector3(raio * 2.0, 0.5, raio * 2.0),
		"pos": centro + Vector3(0.0, 0.25, 0.0)})


## Placa do parque na entrada. Nome proprio: sem ele o parque e "um parque", e
## com ele o jogador diz "o parque tal", que e o comeco de saber onde esta.