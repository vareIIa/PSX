## O beco: a passagem estreita entre duas casas que entra ate o fundo do lote.
##
## Por que existe
## -------------
## A viela da malha e uma RUA estreita — quatro metros de via de ponta a ponta,
## com calcada dos dois lados. O que a cidade do interior tem alem dela, e o que
## faltava, e o beco: o vao de tres metros entre duas casas, cimentado, com o
## portao de ferro aberto para dentro, o varal atravessado la em cima, a porta de
## servico das casas do lado, o saco de lixo e a pichacao — e que termina no muro
## do fundo. E onde o jogador entra sem ter para onde ir, e e por isso que ele
## assusta.
##
## Antes dos fundos (FundosBuilder) isto seria exatamente o defeito que se
## consertou: um vao na fileira que dava para o patio, e do patio para o avesso
## de todas as casas. Agora o vao tem fim — os dois muros de divisa do lote e o
## muro de fundo fecham o corredor —, e as laterais sao a parede de verdade dos
## predios vizinhos. Beco e boca de proposito, com fundo.
##
## Sem lampada nenhuma. A viela ja e o unico lugar escuro de uma cidade
## iluminada a sodio; o beco e o mais escuro dela, com uma janela acesa de vez
## em quando como unica luz.
##
## Posicao
## -------
## `becos(cx, cz)` e funcao pura da coordenada, sem o rng do chunk: o mapa, o
## teste e a fileira precisam concordar sobre onde o beco cai. A fileira corta o
## trecho do beco antes de repartir a face em lotes, e o registra como lote
## `beco` para o quintal nao por varal e tanque dentro dele.
class_name BecoBuilder
extends RefCounted

const LARGURA_MIN := 2.6
const LARGURA_MAX := 3.2
## Face minima para ter beco: um lote de cada lado dele, e folga da esquina.
const FACE_MINIMA := 18.0
## Distancia minima do beco ate a ponta da face.
const MARGEM := 5.0
## Quintal minimo: menos que isto o beco seria um nicho, nao um corredor.
const QUINTAL_MINIMO := 4.0
const ALTURA_VARAL := 3.1
## Chance de o beco terminar numa vila, e o quintal minimo para caber a casinha.
const CHANCE_VILA := 0.55
const QUINTAL_VILA := 6.0

## Chance de uma face ter beco, por distrito. Rua de casas tem mais; galpao
## quase nunca — beco de galpao e patio de carga, outra coisa.
const CHANCE := {
	MalhaUrbana.Distrito.RESIDENCIAL: 0.34,
	MalhaUrbana.Distrito.COMERCIAL: 0.24,
	MalhaUrbana.Distrito.INDUSTRIAL: 0.12,
}


## Os becos do chunk, um por face no maximo. Cada um e
## {direcao, de, ate, fundo}: `de` e `ate` ao longo da face (mesma medida de
## `ChunkBuilder.faces_de_rua`), `fundo` a profundidade ate o muro do fundo.
static func becos(cx: int, cz: int) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var quadra := MalhaUrbana.quadra_de(cx, cz)
	if int(quadra["uso"]) != MalhaUrbana.Uso.EDIFICADO:
		return saida
	var chance := float(CHANCE.get(int(quadra["distrito"]), 0.0))
	if chance <= 0.0:
		return saida
	var q := FundosBuilder.profundidade_quintal(quadra)
	if q < QUINTAL_MINIMO:
		return saida
	# A face da porta de entrada fica sem beco: o vao dela, o do bar e o lote da
	# casa da fumaca ja reorganizam a fileira, e um beco na mesma face poderia
	# cair em cima de qualquer um dos tres.
	var porta := ChunkBuilder._porta_do_chunk(cx, cz, quadra)
	var faces := ChunkBuilder.faces_de_rua(MalhaUrbana.bordas(cx, cz),
		ChunkBuilder.area_util(cx, cz))
	for face: Dictionary in faces:
		var direcao := int(face["direcao"])
		var comp := float(face["comprimento"])
		if comp < FACE_MINIMA:
			continue
		if not porta.is_empty() and int(porta["direcao"]) == direcao:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = MalhaUrbana._ruido(cx * 4 + direcao, cz, 6151)
		if rng.randf() >= chance:
			continue
		var larg := rng.randf_range(LARGURA_MIN, LARGURA_MAX)
		var de := rng.randf_range(MARGEM, comp - MARGEM - larg)
		saida.append({
			"direcao": direcao,
			"de": de,
			"ate": de + larg,
			"fundo": ChunkBuilder.PROF_PREDIO + q,
			# Mais da metade dos becos da numa vila: os quintais dos dois lotes
			# vizinhos viram patio, com uma casinha de cada lado (`_vila`).
			"vila": rng.randf() < CHANCE_VILA and q >= QUINTAL_VILA,
		})
	return saida


## O beco desta face, ou vazio.
static func da_face(becos_do_chunk: Array[Dictionary], face: Dictionary) -> Dictionary:
	for b: Dictionary in becos_do_chunk:
		if int(b["direcao"]) == int(face["direcao"]):
			return b
	return {}


## Monta o chao, o portao e o que tem dentro de cada beco do chunk.
static func construir(sup: Dictionary, colisao: Array[Dictionary],
		faces: Array[Dictionary], becos_do_chunk: Array[Dictionary],
		rng: RandomNumberGenerator, lotes: Array[Dictionary] = []) -> void:
	if not FundosBuilder.ativo:
		return
	for b: Dictionary in becos_do_chunk:
		for face: Dictionary in faces:
			if int(face["direcao"]) == int(b["direcao"]):
				_um(sup, colisao, face, float(b["de"]), float(b["ate"]),
					float(b["fundo"]), rng)
				if bool(b.get("vila", false)):
					_vila(sup, colisao, face, b, lotes, rng)
				break


## Os dois lotes encostados no beco, pela ordem [esquerda, direita]. Vazio no
## lado em que nao ha lote (nao acontece com a MARGEM de hoje, mas o lote da
## ponta da face pode ser estreito demais para casinha).
static func vizinhos(face: Dictionary, b: Dictionary,
		lotes: Array[Dictionary]) -> Array[Dictionary]:
	var esq: Dictionary = {}
	var dir: Dictionary = {}
	for lote: Dictionary in lotes:
		if lote["face"] != face or bool(lote.get("beco", false)):
			continue
		if absf(float(lote["ate"]) - float(b["de"])) < 0.05:
			esq = lote
		elif absf(float(lote["de"]) - float(b["ate"])) < 0.05:
			dir = lote
	return [esq, dir]


## A vila: o patio cimentado atras das casas da frente, e uma casinha de cada
## lado virada para o beco.
##
## Os quintais dos dois lotes vizinhos deixam de ser quintal (FundosBuilder nao
## poe varal nem muro de divisa entre eles e o beco) e viram o patio. Os muros
## de divisa de FORA e o muro de fundo continuam la: a vila e fechada, e quem
## entra pelo beco chega num lugar com gente morando, e nao num buraco.
static func _vila(sup: Dictionary, colisao: Array[Dictionary], face: Dictionary,
		b: Dictionary, lotes: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	var prof := ChunkBuilder.PROF_PREDIO
	var fundo := float(b["fundo"])
	var h := KitModular.ALTURA_MEIO_FIO
	var eixo: Vector3 = face["eixo"]
	var lados := vizinhos(face, b, lotes)
	for k in 2:
		var lote: Dictionary = lados[k]
		if lote.is_empty():
			continue
		var t0 := float(lote["de"])
		var t1 := float(lote["ate"])
		# Patio: o quintal do lote vizinho, cimentado na altura do beco, com
		# chao de colisao (sem ele, 16 cm de degrau para baixo e nao se volta).
		var a := FundosBuilder._ponto(face, t0, prof)
		var c := FundosBuilder._ponto(face, t1, fundo)
		var r := Rect2(Vector2(minf(a.x, c.x), minf(a.z, c.z)),
			Vector2(absf(c.x - a.x), absf(c.z - a.z)))
		KitModular.chao(sup, &"concreto", Vector3(r.position.x, h, r.position.y),
			r.size, 4.0, Color(0.58, 0.57, 0.54))
		colisao.append({
			"tamanho": Vector3(r.size.x, h, r.size.y),
			"pos": Vector3(r.get_center().x, h * 0.5, r.get_center().y),
		})
		var largura_lote := t1 - t0
		if largura_lote < 4.5:
			continue
		# A casinha encosta no muro de divisa de fora e olha para o beco.
		var larg := minf(largura_lote - 1.4, 4.6)
		var ct0 := t0 + 0.15 if k == 0 else t1 - 0.15 - larg
		var s0 := prof + 0.6
		var s1 := fundo - 0.5
		if s1 - s0 < 3.0:
			continue
		var olha := eixo * (1.0 if k == 0 else -1.0)
		_casinha(sup, colisao, face, ct0, ct0 + larg, s0, s1, olha, rng)


## Casinha de vila: um comodo, porta e janela para o patio, meia-agua de telha.
static func _casinha(sup: Dictionary, colisao: Array[Dictionary], face: Dictionary,
		t0: float, t1: float, s0: float, s1: float, olha: Vector3,
		rng: RandomNumberGenerator) -> void:
	const ALTO := 2.8
	var h := KitModular.ALTURA_MEIO_FIO
	var a := FundosBuilder._ponto(face, t0, s0)
	var c := FundosBuilder._ponto(face, t1, s1)
	var meio := (a + c) * 0.5
	var tam := (c - a).abs()
	var cor := MalhaUrbana.CORES_CASA[rng.randi() % MalhaUrbana.CORES_CASA.size()]
	KitModular.caixa_cor(sup, &"reboco", meio + Vector3(0.0, h + ALTO * 0.5, 0.0),
		Vector3(tam.x, ALTO, tam.z), cor, 0.0,
		PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, FundosBuilder.QUAD_FUNDO)
	colisao.append({"tamanho": Vector3(tam.x, ALTO, tam.z),
		"pos": meio + Vector3(0.0, h + ALTO * 0.5, 0.0)})
	# Porta e janela na face que da para o patio.
	var dir := FundosBuilder._direcao_de(olha)
	var meia := (tam.x if absf(olha.x) > 0.5 else tam.z) * 0.5
	var frente := meio + olha * (meia + 0.02)
	var ao_longo := Vector3(absf(olha.z), 0.0, absf(olha.x))
	var comp := tam.z if absf(olha.x) > 0.5 else tam.x
	KitModular.parede(sup, &"porta", frente + ao_longo * (comp * 0.22)
		+ Vector3(0.0, h + 1.0, 0.0), Vector2(0.82, 2.0), dir,
		Color("6a4a34").lerp(Color("4f5a4a"), rng.randf()))
	KitModular.parede(sup,
		&"janela_acesa" if rng.randf() < 0.55 else &"janela_apagada",
		frente - ao_longo * (comp * 0.2) + Vector3(0.0, h + 1.5, 0.0),
		Vector2(0.9, 0.85), dir)
	# Meia-agua caindo para o patio, com beiral sobre a porta.
	var giro := atan2(olha.x, olha.z)
	var avanco := 0.5
	var fundura := meia * 2.0 + avanco
	var inclinacao := atan2(0.45, fundura)
	var centro := meio + olha * (avanco * 0.5) + Vector3(0.0, h + ALTO + 0.12 + 0.22, 0.0)
	var base := Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, inclinacao)
	KitModular.caixa_livre(sup, &"telha", centro, Vector3(comp + 0.3, 0.08, fundura + 0.1),
		base, Color.WHITE.lerp(KitPredio.TELHA_VELHA[rng.randi() % KitPredio.TELHA_VELHA.size()],
			rng.randf_range(0.1, 0.6)), FundosBuilder.QUAD_FUNDO)
	# Vaso de planta e um banquinho na porta: a vila e onde se senta na rua.
	KitModular.caixa_cor(sup, &"concreto",
		frente + olha * 0.35 + ao_longo * (comp * 0.42) + Vector3(0.0, h + 0.2, 0.0),
		Vector3(0.35, 0.4, 0.35), Color(0.62, 0.42, 0.32), 0.0, PSXMesh.FACE_TODAS, 8.0)
	KitParque.arbusto(sup, frente + olha * 0.35 + ao_longo * (comp * 0.42)
		+ Vector3(0.0, h + 0.4, 0.0), 0.3, rng)


static func _um(sup: Dictionary, colisao: Array[Dictionary], face: Dictionary,
		de: float, ate: float, fundo: float, rng: RandomNumberGenerator) -> void:
	var direcao := int(face["direcao"])
	var normal := KitModular._normal(direcao)
	var eixo: Vector3 = face["eixo"]
	var h := KitModular.ALTURA_MEIO_FIO
	var larg := ate - de
	var meio_t := (de + ate) * 0.5

	# Chao cimentado na altura da calcada. Rente ao asfalto ele seria um degrau
	# de dezesseis centimetros para baixo na entrada, e o CharacterBody3D desce
	# mas nao sobe: quem entrasse no beco nao saia.
	var a := FundosBuilder._ponto(face, de, 0.0)
	var c := FundosBuilder._ponto(face, ate, fundo)
	var r := Rect2(Vector2(minf(a.x, c.x), minf(a.z, c.z)),
		Vector2(absf(c.x - a.x), absf(c.z - a.z)))
	KitModular.chao(sup, &"concreto", Vector3(r.position.x, h, r.position.y),
		r.size, 4.0, Color(0.56, 0.55, 0.52))
	colisao.append({
		"tamanho": Vector3(r.size.x, h, r.size.y),
		"pos": Vector3(r.get_center().x, h * 0.5, r.get_center().y),
	})
	# Canaleta no meio, a agua do beco inteiro correndo para a rua.
	var ca := FundosBuilder._ponto(face, meio_t - 0.12, 0.0)
	var cc := FundosBuilder._ponto(face, meio_t + 0.12, fundo)
	KitModular.chao(sup, &"metal_enferrujado",
		Vector3(minf(ca.x, cc.x), h + 0.01, minf(ca.z, cc.z)),
		Vector2(absf(cc.x - ca.x), absf(cc.z - ca.z)), 8.0, Color(0.35, 0.33, 0.3))

	# Portao de ferro aberto, encostado na parede da esquerda. Aberto para
	# DENTRO, que e como fica o portao de beco que ninguem mais tranca.
	var giro_parede := atan2(eixo.x, eixo.z)
	var folha := minf(larg - 0.4, 1.4)
	KitModular.placa(sup, &"metal_ondulado",
		FundosBuilder._ponto(face, de + 0.06, 0.25 + folha * 0.5) + Vector3(0.0, h + 1.0, 0.0),
		Vector2(folha, 2.0), giro_parede, Color(0.42, 0.4, 0.37))
	KitModular.caixa_cor(sup, &"metal",
		FundosBuilder._ponto(face, de + 0.06, 0.2) + Vector3(0.0, h + 1.05, 0.0),
		Vector3(0.07, 2.1, 0.07), Color("3e4042"))
	# Verga sobre a entrada: o beco comeca num vao, e nao num corte da fileira.
	KitModular.caixa_cor(sup, &"concreto_sujo",
		FundosBuilder._ponto(face, meio_t, 0.05) + Vector3(0.0, 2.55, 0.0),
		Vector3(larg, 0.28, 0.3) if absf(eixo.x) > 0.5 else Vector3(0.3, 0.28, larg),
		Color(0.62, 0.6, 0.56))

	# Varal atravessado de parede a parede, la em cima. So entre as paredes dos
	# predios: alem deles os muros de divisa tem dois metros e o fio ficaria no ar.
	for s: float in [ChunkBuilder.PROF_PREDIO * 0.3, ChunkBuilder.PROF_PREDIO * 0.78]:
		if rng.randf() < 0.3:
			continue
		var p0 := FundosBuilder._ponto(face, de + 0.05, s) + Vector3(0.0, ALTURA_VARAL, 0.0)
		var p1 := FundosBuilder._ponto(face, ate - 0.05, s) + Vector3(0.0, ALTURA_VARAL, 0.0)
		KitModular.cabo(sup, p0, p1)
		var pecas := rng.randi_range(1, 3)
		for k in pecas:
			var t := de + larg * (float(k) + 0.5) / float(pecas)
			var tam := Vector2(rng.randf_range(0.45, 0.75), rng.randf_range(0.5, 0.9))
			var cor := FundosBuilder.ROUPAS[rng.randi() % FundosBuilder.ROUPAS.size()]
			for lado: float in [0.0, PI]:
				KitModular.placa(sup, &"toldo",
					FundosBuilder._ponto(face, t, s)
						+ Vector3(0.0, ALTURA_VARAL - 0.03 - tam.y * 0.5, 0.0),
					tam, atan2(normal.x, normal.z) + lado, cor, 8.0)

	# As duas paredes do beco sao as laterais dos predios vizinhos. Porta de
	# servico, janelinha de banheiro e pichacao sao o que as tira de "caixa".
	for lado: float in [1.0, -1.0]:
		# `lado` 1: parede em `de`, olhando para +eixo; -1: parede em `ate`.
		var t_parede := de + 0.02 if lado > 0.0 else ate - 0.02
		var giro := atan2(eixo.x * lado, eixo.z * lado)
		if rng.randf() < 0.55:
			var s_porta := rng.randf_range(2.0, ChunkBuilder.PROF_PREDIO - 1.5)
			KitModular.placa(sup, &"porta",
				FundosBuilder._ponto(face, t_parede, s_porta) + Vector3(0.0, h + 1.02, 0.0),
				Vector2(0.84, 2.04), giro, Color(0.8, 0.76, 0.7))
		if rng.randf() < 0.6:
			var s_jan := rng.randf_range(1.5, ChunkBuilder.PROF_PREDIO - 1.0)
			KitModular.placa(sup,
				&"janela_acesa" if rng.randf() < 0.35 else &"janela_apagada",
				FundosBuilder._ponto(face, t_parede, s_jan) + Vector3(0.0, 2.05, 0.0),
				Vector2(0.55, 0.45), giro)
		if rng.randf() < 0.45:
			var s_pich := rng.randf_range(1.2, ChunkBuilder.PROF_PREDIO - 2.0)
			KitModular.placa(sup, &"pichacao",
				FundosBuilder._ponto(face, t_parede, s_pich) + Vector3(0.0, 1.25, 0.0),
				Vector2(2.2, 1.1), giro)

	# Saco de lixo e tambor perto da entrada.
	for k in rng.randi_range(1, 3):
		var t := de + rng.randf_range(0.35, larg - 0.35)
		var s := rng.randf_range(0.6, 2.4)
		var tam := Vector3(rng.randf_range(0.4, 0.6), rng.randf_range(0.35, 0.55),
			rng.randf_range(0.35, 0.5))
		# `metal` tingido de quase preto le como saco plastico; `espuma` ignorava
		# a tinta e o saco saia cinza-claro, como um bloco de isopor.
		KitModular.caixa_cor(sup, &"metal",
			FundosBuilder._ponto(face, t, s) + Vector3(0.0, h + tam.y * 0.5, 0.0),
			tam, Color(0.16, 0.18, 0.16).lerp(Color(0.1, 0.1, 0.12), rng.randf()),
			rng.randf_range(0.0, PI), PSXMesh.FACE_TODAS, 8.0)
	if rng.randf() < 0.5:
		KitModular.caixa_cor(sup, &"metal_enferrujado",
			FundosBuilder._ponto(face, ate - 0.45, fundo - 1.0) + Vector3(0.0, h + 0.45, 0.0),
			Vector3(0.58, 0.9, 0.58), Color(0.7, 0.66, 0.6), 0.0, PSXMesh.FACE_TODAS, 8.0)

	# Porta velha no muro do fundo: o beco acaba, mas alguem passa por ali.
	KitModular.placa(sup, &"tabua",
		FundosBuilder._ponto(face, meio_t, fundo - 0.1) + Vector3(0.0, 1.0, 0.0),
		Vector2(0.9, 1.9), atan2(normal.x, normal.z), Color(0.55, 0.45, 0.34))
