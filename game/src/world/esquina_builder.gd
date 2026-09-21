## O predio de esquina chanfrada: a quina cortada a 45 graus, com a porta na
## diagonal.
##
## Por que existe
## -------------
## Toda quina de quarteirao era um canto vivo de caixa. A esquina de cidade do
## interior e, uma vez em duas ou tres, CHANFRADA — o armazem, a venda, o bar da
## esquina, com a porta de enrolar na diagonal olhando para as duas ruas ao mesmo
## tempo e a platibanda acompanhando o corte. E o marco que o morador usa para
## ensinar caminho ("vira na venda do Seu Tonico"), e o que mais quebra a cara
## de tabuleiro da cidade vista do cruzamento.
##
## Geometria
## ---------
## Em (u, s): `u` anda ao longo da face a partir da QUINA (para dentro do lote),
## `s` entra na quadra a partir da linha da fachada. O chanfro tira o triangulo
## u + s < c:
##
##     A   u em [c, larg], s em [0, PROF]     o corpo principal
##     B   u em [0, c],    s em [c, PROF]     o pedaco atras do chanfro
##     o triangulo de tras da diagonal fecha com uma tampa no alto e uma caixa
##     de colisao girada; o da frente vira calcada, com piso e colisao.
##
## So a fileira do eixo X tem esquina (ChunkBuilder.faces_de_rua), e so a ponta
## que encosta em rua transversal.
class_name EsquinaBuilder
extends RefCounted

const PLATIBANDA := 0.8
const ESP_PLAT := 0.2
const LETREIROS: Array[Color] = [
	Color("c45a3a"), Color("3a6e54"), Color("3f5a8a"), Color("b8962e"), Color("7a3f5a"),
]


## Monta o predio chanfrado do lote que comeca em `cursor` e tem `larg` metros.
## `na_largada`: a quina e a do comeco da face (t = cursor); senao, a do fim.
static func construir(sup: Dictionary, colisao: Array[Dictionary], face: Dictionary,
		cursor: float, larg: float, na_largada: bool, chanfro: float, andares: int,
		quadra: Dictionary, tinta: Color, mat_fachada: StringName,
		rng: RandomNumberGenerator) -> void:
	var prof := ChunkBuilder.PROF_PREDIO
	var c := chanfro
	var altura := float(andares) * KitModular.ALTURA_ANDAR
	var h := KitModular.ALTURA_MEIO_FIO
	var direcao := int(face["direcao"])
	var normal := KitModular._normal(direcao)
	var eixo: Vector3 = face["eixo"]
	var dir_u := eixo if na_largada else -eixo
	var t_quina := cursor if na_largada else cursor + larg

	# Ponto do lote a partir da quina.
	var p := func(u: float, s: float) -> Vector3:
		return FundosBuilder._ponto(face, t_quina + (u if na_largada else -u), s)

	# --- corpo A e B -------------------------------------------------------
	var faces_a := PSXMesh.FACE_TOPO | _face_para(dir_u)
	var centro_a: Vector3 = p.call((c + larg) * 0.5, prof * 0.5) + Vector3(0.0, altura * 0.5, 0.0)
	var tam_a := _tamanho(eixo, larg - c, prof, altura)
	KitModular.caixa_cor(sup, &"concreto_sujo", centro_a, tam_a, tinta, 0.0, faces_a)
	colisao.append({"tamanho": tam_a, "pos": centro_a})

	var faces_b := PSXMesh.FACE_TOPO | _face_para(-dir_u)
	var centro_b: Vector3 = p.call(c * 0.5, (c + prof) * 0.5) + Vector3(0.0, altura * 0.5, 0.0)
	var tam_b := _tamanho(eixo, c, prof - c, altura)
	KitModular.caixa_cor(sup, &"concreto_sujo", centro_b, tam_b, tinta, 0.0, faces_b)
	colisao.append({"tamanho": tam_b, "pos": centro_b})

	# --- a diagonal ---------------------------------------------------------
	var d0: Vector3 = p.call(c, 0.0)
	var d1: Vector3 = p.call(0.0, c)
	var meio_diag := (d0 + d1) * 0.5
	var fora := (normal - dir_u).normalized()
	var giro := atan2(fora.x, fora.z)
	var comp_diag := c * sqrt(2.0)
	KitModular.parede_livre(sup, mat_fachada, meio_diag + fora * 0.02
		+ Vector3(0.0, altura * 0.5, 0.0), Vector2(comp_diag, altura), giro, tinta)
	# Tampa do triangulo de tras da diagonal, e a caixa de colisao que o enche.
	_triangulo(sup, &"concreto_sujo", [d0, d1, p.call(c, c)], altura, tinta.darkened(0.1))
	colisao.append({
		"tamanho": Vector3(comp_diag, altura, c / sqrt(2.0)),
		"pos": meio_diag - fora * (c / sqrt(2.0) * 0.5) + Vector3(0.0, altura * 0.5, 0.0),
		"giro": Vector3(0.0, giro, 0.0),
	})
	# O triangulo da frente vira calcada: piso na altura dela e colisao, senao a
	# quina e um degrau de 16 cm para dentro do vazio.
	var mat_calcada := ChunkBuilder.material_da_calcada(quadra)
	_triangulo(sup, mat_calcada, [p.call(0.0, 0.0), d0, d1], h + 0.001, Color.WHITE)
	colisao.append({
		"tamanho": Vector3(comp_diag, h, c / sqrt(2.0)),
		"pos": meio_diag + fora * (c / sqrt(2.0) * 0.5) + Vector3(0.0, h * 0.5, 0.0),
		"giro": Vector3(0.0, giro, 0.0),
	})

	# A porta da venda na diagonal: porta de enrolar aberta pela metade, com o
	# escuro da loja atras, marquise e letreiro deitado.
	var cor_letreiro := LETREIROS[rng.randi() % LETREIROS.size()]
	KitModular.parede_livre(sup, &"metal_ondulado", meio_diag + fora * 0.04
		+ Vector3(0.0, h + 1.75, 0.0), Vector2(minf(1.9, comp_diag - 0.9), 0.9), giro)
	KitModular.parede_livre(sup, &"janela_acesa" if rng.randf() < 0.6 else &"janela_apagada",
		meio_diag + fora * 0.035 + Vector3(0.0, h + 0.65, 0.0),
		Vector2(minf(1.9, comp_diag - 0.9), 1.3), giro)
	KitModular.caixa_cor(sup, &"concreto", meio_diag + fora * 0.35
		+ Vector3(0.0, 2.65, 0.0), Vector3(comp_diag + 0.3, 0.1, 0.7),
		Color("b9b2a2"), giro)
	KitModular.caixa_cor(sup, &"metal", meio_diag + fora * 0.1
		+ Vector3(0.0, 3.0, 0.0), Vector3(minf(comp_diag, 3.2), 0.45, 0.1),
		cor_letreiro, giro)
	for andar in range(1, andares):
		KitModular.parede_livre(sup,
			&"janela_acesa" if rng.randf() < float(quadra["janela"]) else &"janela_apagada",
			meio_diag + fora * 0.04 + Vector3(0.0, float(andar) * KitModular.ALTURA_ANDAR
				+ 1.45, 0.0), Vector2(1.0, 1.25), giro)
		KitModular.caixa_cor(sup, &"concreto", meio_diag + fora * 0.06
			+ Vector3(0.0, float(andar) * KitModular.ALTURA_ANDAR, 0.0),
			Vector3(comp_diag, 0.12, 0.16), tinta.darkened(0.18), giro)

	# --- fachadas das duas ruas --------------------------------------------
	var frente_a: Vector3 = p.call((c + larg) * 0.5, 0.0)
	if bool(quadra["casa"]):
		KitFachada.residencia(sup, frente_a + normal * ChunkBuilder.AVANCO_FACHADA,
			larg - c, andares, direcao, mat_fachada, rng, float(quadra["janela"]),
			tinta)
	else:
		KitModular.fachada(sup, frente_a + normal * ChunkBuilder.AVANCO_FACHADA,
			larg - c, andares, direcao, mat_fachada, rng, float(quadra["loja"]),
			float(quadra["janela"]), tinta)
	# A lateral da rua transversal, so no corpo B.
	var lado := -dir_u
	var dir_lado := FundosBuilder._direcao_de(lado)
	for andar in andares:
		var y := float(andar) * KitModular.ALTURA_ANDAR + (1.3 if andar == 0 else 1.45)
		var s_jan := (c + prof) * 0.5
		var pj: Vector3 = p.call(0.0, s_jan) + lado * 0.04 + Vector3(0.0, y, 0.0)
		KitModular.parede(sup, &"concreto", pj - lado * 0.02, Vector2(1.32, 1.42),
			dir_lado, Color("8d8577").darkened(0.1))
		KitModular.parede(sup,
			&"janela_acesa" if rng.randf() < float(quadra["janela"]) else &"janela_apagada",
			pj, Vector2(1.1, 1.2), dir_lado)

	# --- platibanda acompanhando o corte ------------------------------------
	var escura := tinta.lerp(Color("8e8a80"), 0.35)
	var y_plat := altura + PLATIBANDA * 0.5
	_mureta(sup, p.call(c, 0.0), p.call(larg, 0.0), y_plat, escura)
	_mureta(sup, d0, d1, y_plat, escura)
	_mureta(sup, p.call(0.0, c), p.call(0.0, prof), y_plat, escura)
	_mureta(sup, p.call(0.0, prof), p.call(larg, prof), y_plat, escura)
	_mureta(sup, p.call(larg, 0.0), p.call(larg, prof), y_plat, escura)


## A face de caixa que olha para `v`.
static func _face_para(v: Vector3) -> int:
	if absf(v.x) > absf(v.z):
		return PSXMesh.FACE_DIR if v.x > 0.0 else PSXMesh.FACE_ESQ
	return PSXMesh.FACE_FRENTE if v.z > 0.0 else PSXMesh.FACE_TRAS


## Tamanho de caixa com `ao_longo` metros no eixo da face e `fundo` metros
## para dentro da quadra.
static func _tamanho(eixo: Vector3, ao_longo: float, fundo: float, alto: float) -> Vector3:
	if absf(eixo.z) > 0.5:
		return Vector3(fundo, alto, ao_longo)
	return Vector3(ao_longo, alto, fundo)


## Mureta de platibanda entre dois pontos no chao, na altura `y`.
static func _mureta(sup: Dictionary, a: Vector3, b: Vector3, y: float, cor: Color) -> void:
	var delta := b - a
	var comp := Vector2(delta.x, delta.z).length()
	if comp < 0.05:
		return
	var giro := atan2(delta.x, delta.z)
	var meio := (a + b) * 0.5
	KitModular.caixa_cor(sup, &"concreto_sujo", Vector3(meio.x, y, meio.z),
		Vector3(ESP_PLAT, PLATIBANDA, comp + ESP_PLAT), cor, giro,
		PSXMesh.FACE_TODAS, 4.0)


## Triangulo horizontal virado para cima, na altura `y`.
static func _triangulo(sup: Dictionary, material: StringName, cantos: Array,
		y: float, cor: Color) -> void:
	var d := PSXMesh.dados_vazios()
	var v: PackedVector3Array = d["v"]
	var n: PackedVector3Array = d["n"]
	var uv: PackedVector2Array = d["uv"]
	var uv2: PackedVector2Array = d["uv2"]
	var cs: PackedColorArray = d["c"]
	var idx: PackedInt32Array = d["i"]
	for q: Vector3 in cantos:
		v.append(Vector3(q.x, y, q.z))
		n.append(Vector3.UP)
		uv.append(Vector2(q.x, q.z) * PSXMesh.DEFAULT_UV_PER_M)
		uv2.append(Vector2.ZERO)
		cs.append(cor)
	# A face aparece do lado OPOSTO ao produto vetorial (PSXMesh.placa_dados).
	var produto := (v[1] - v[0]).cross(v[2] - v[0])
	if produto.y > 0.0:
		idx.append_array([0, 2, 1])
	else:
		idx.append_array([0, 1, 2])
	d["v"] = v
	d["n"] = n
	d["uv"] = uv
	d["uv2"] = uv2
	d["c"] = cs
	d["i"] = idx
	KitModular.por(sup, material, d, Transform3D.IDENTITY)
