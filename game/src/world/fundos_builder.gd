## Os fundos da quadra: a parede de tras de cada predio e o quintal atras dela.
##
## Por que existe
## -------------
## O predio da fileira era uma caixa de oito metros com a fachada na frente, as
## laterais e o topo — e sem a face de tras. Da rua ninguem ve o avesso, desde que
## o anel de predios feche. Onde ele abria (a fileira que nao nascia, a sobra de
## 2,8 m no fim da face, o lote que o bar ou a casa da fumaca comia), a rua dava
## para um terreiro vazio do tamanho da quadra, e dali se via o lado de dentro de
## todas as casas: a fachada e um plano de uma face so e a caixa nao tinha fundo.
## Era o "buraco no mapa" no fim da viela.
##
## Fechar as bocas conserta o sintoma. O que faz a cidade de interior e o que tem
## atras: a parede de tras com a janela do banheiro e a porta da cozinha, o muro
## de divisa entre um quintal e outro, o varal, o tanque, o puxadinho de telha e a
## mangueira que aparece por cima do telhado de uma casa terrea. Visto da viela,
## do beco ou do alto, a quadra tem miolo — e nao um buraco.
##
## Geometria
## ---------
## Tudo em coordenada LOCAL do chunk, como o resto do ChunkBuilder. Para cada face
## de rua, `t` corre ao longo da fachada (de `canto` na direcao de `eixo`) e `s`
## entra na quadra a partir da linha da fachada:
##
##   s = 0                   linha da fachada
##   s = PROF                parede de tras do predio
##   s = PROF + quintal      muro de fundo do quintal
##
## A profundidade do quintal e da QUADRA, e nao do chunk: os quatro ou nove chunks
## de um quarteirao desenham muros que se encontram na costura sem combinar nada.
##
## A esquina e de quem ja e dono dela no ChunkBuilder: a fileira do eixo X pega a
## profundidade toda em Z, e a do eixo Z comeca depois dela. O quintal segue a
## mesma regra — a faixa do eixo X fica com o quadrado da quina.
class_name FundosBuilder
extends RefCounted

const ALTURA_MURO := 2.2
const ESPESSURA_MURO := 0.14
## Quintal mais fundo que isto vira terreno baldio dentro do lote.
const QUINTAL_MAX := 9.0
## Abaixo disto o quintal nao tem onde por nada: fica so o muro.
const QUINTAL_MIN := 2.5
## Quad folgado: muro de fundo e parede de tras sao vistos de longe ou de cima.
const QUAD_FUNDO := 4.0
## Quanto o muro de quintal desce abaixo do chao (ver `_muro`).
const ENTERRADO := 1.0

## Chave de bancada: desligada, nenhum fundo, quintal, beco nem lateral de
## esquina e desenhado. Existe para medir quanto do chunk e desta camada — o
## teto de 6000 triangulos e do chunk inteiro, e "quem esta pesando" nao se
## responde de olho. O jogo nunca mexe nela.
static var ativo := true

const ROUPAS: Array[Color] = [
	Color("d8d4c8"), Color("b5463c"), Color("3f5f8a"), Color("d9b44a"),
	Color("6e8f5a"), Color("c7c2d6"), Color("8a4f6e"), Color("e8e2d2"),
]


## Profundidade do quintal desta quadra, em metros.
##
## Sai do lado MENOR da quadra: o que sobra depois dos dois predios opostos,
## dividido pelos dois quintais, menos um metro de folga para os muros de fundo
## nunca se cruzarem no meio. Em quadra de dois chunks sobra o quintal cheio.
static func profundidade_quintal(quadra: Dictionary) -> float:
	var r := MalhaUrbana.retangulo_da_quadra(quadra)
	var livre := minf(r.size.x, r.size.y) - 2.0 * ChunkBuilder.PROF_PREDIO
	return clampf(livre * 0.5 - 1.0, 0.0, QUINTAL_MAX)


## A face de tras da caixa do predio, no esquema de PSXMesh.
static func face_de_tras(direcao: int) -> int:
	match posmod(direcao, 4):
		0: return PSXMesh.FACE_TRAS
		1: return PSXMesh.FACE_ESQ
		2: return PSXMesh.FACE_FRENTE
		_: return PSXMesh.FACE_DIR


# --- parede de tras ---------------------------------------------------------

## O que se ve na parede de tras de um predio da fileira.
##
## `frente` e o meio da fachada no chao, como em `_fileira`. A parede de tras em
## si e a face da caixa da massa; aqui entram so as aberturas e o que se pendura
## nela. Janela menor e mais alta que a da frente — banheiro, cozinha, area de
## servico —, uma porta de cozinha no terreo e o cano de agua da chuva descendo
## do telhado.
static func fundo(sup: Dictionary, frente: Vector3, larg: float, andares: int,
		direcao: int, prob_acesa: float, rng: RandomNumberGenerator,
		tinta: Color = Color.WHITE) -> void:
	if not ativo:
		return
	var normal := KitModular._normal(direcao)
	var dir_tras := posmod(direcao + 2, 4)
	var fora := -normal
	var lateral := KitModular._lateral(dir_tras)
	var tras := frente - normal * ChunkBuilder.PROF_PREDIO + fora * 0.03
	var giro := atan2(fora.x, fora.z)

	# A parede de tras em si: a face que faltava na caixa da massa. Mesmo
	# material e mesma tinta das laterais, mas com quad de quatro metros — ela
	# e vista do alto, da viela e por cima do muro, nunca a um palmo do nariz, e
	# na grade de dois metros ela sozinha custava um quinto do chunk.
	var altura_massa := float(andares) * KitModular.ALTURA_ANDAR
	var fina := Vector3(larg, altura_massa, 0.02) if absf(normal.z) > 0.5 \
		else Vector3(0.02, altura_massa, larg)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		frente - normal * (ChunkBuilder.PROF_PREDIO - 0.01)
			+ Vector3(0.0, altura_massa * 0.5, 0.0),
		fina, tinta, 0.0, face_de_tras(direcao), QUAD_FUNDO)

	# Porta da cozinha. Primeiro, para as janelas do terreo saberem onde nao ir.
	var porta := rng.randf_range(-larg * 0.5 + 0.9, larg * 0.5 - 0.9) if larg > 2.4 else 0.0
	KitModular.parede(sup, &"porta",
		tras + Vector3(0.0, 1.05, 0.0) + lateral * porta, Vector2(0.86, 2.1), dir_tras)
	# Laje de concreto sobre a porta: e o que segura a chuva, e a sombra dela
	# e o que faz a porta ler como porta de 480x270.
	KitModular.caixa_cor(sup, &"concreto_sujo",
		tras + Vector3(0.0, 2.3, 0.0) + lateral * porta + fora * 0.3,
		Vector3(1.3, 0.08, 0.6), Color(0.7, 0.69, 0.66), giro,
		PSXMesh.FACE_TODAS, QUAD_FUNDO)

	var n := maxi(1, int(larg / 3.4))
	var passo := larg / float(n)
	for andar in andares:
		for k in n:
			var off := (float(k) - float(n - 1) * 0.5) * passo \
				+ rng.randf_range(-0.3, 0.3)
			if andar == 0 and absf(off - porta) < 1.3:
				continue
			var pequena := rng.randf() < 0.4
			var tam := Vector2(0.62, 0.5) if pequena else Vector2(1.0, 1.0)
			var y := float(andar) * KitModular.ALTURA_ANDAR \
				+ (1.95 if pequena else 1.55)
			var mat: StringName = &"janela_acesa" if rng.randf() < prob_acesa * 0.7 \
				else &"janela_apagada"
			KitModular.parede(sup, mat, tras + Vector3(0.0, y, 0.0) + lateral * off,
				tam, dir_tras)

	# Cano de descida do telhado, rente a ponta da parede.
	var altura := float(andares) * KitModular.ALTURA_ANDAR
	var ponta := lateral * (larg * 0.5 - 0.22) * (1.0 if rng.randf() < 0.5 else -1.0)
	KitModular.caixa_cor(sup, &"metal",
		tras + ponta + fora * 0.06 + Vector3(0.0, altura * 0.5, 0.0),
		Vector3(0.09, altura, 0.09), Color("8b8d88"), giro, PSXMesh.FACE_TODAS, 8.0)


## A lateral do predio de esquina, a que da para a rua transversal.
##
## A fileira do eixo X fica com a quina, entao a lateral do primeiro (ou do
## ultimo) predio dela e a parede que o pedestre ve inteira ao dobrar a esquina.
## Era a face cega da caixa: oito metros de concreto do chao ao telhado, na
## esquina — que e justamente onde se para. Casa de esquina tem janela dos dois
## lados, e o predio de esquina tambem.
##
## `t` e a posicao da lateral ao longo da face e `sentido` diz para onde ela olha
## (+1 no sentido do eixo da face, -1 contra).
static func lateral_de_esquina(sup: Dictionary, face: Dictionary, t: float,
		sentido: float, andares: int, prob_acesa: float, casa: bool,
		cor: Color, rng: RandomNumberGenerator) -> void:
	if not ativo:
		return
	var eixo: Vector3 = face["eixo"]
	var fora := eixo * sentido
	var dir := _direcao_de(fora)
	var prof := ChunkBuilder.PROF_PREDIO
	var pedra := Color("8d8577")
	for andar in andares:
		var y := float(andar) * KitModular.ALTURA_ANDAR + (1.3 if andar == 0 else 1.45)
		for s: float in [prof * 0.3, prof * 0.7]:
			# No terreo de comercio a lateral da esquina e cega de um lado: e onde
			# fica o estoque. Casa tem janela nos dois.
			if andar == 0 and not casa and s > prof * 0.5:
				continue
			var p := _ponto(face, t, s) + fora * 0.04 + Vector3(0.0, y, 0.0)
			var mat: StringName = &"janela_acesa" if rng.randf() < prob_acesa \
				else &"janela_apagada"
			KitModular.parede(sup, &"concreto", p - fora * 0.02,
				Vector2(1.32, 1.42), dir, pedra.darkened(0.1))
			KitModular.parede(sup, mat, p, Vector2(1.1, 1.2), dir)
			KitModular.caixa_cor(sup, &"concreto",
				p + fora * 0.06 + Vector3(0.0, -0.66, 0.0),
				Vector3(1.4, 0.09, 0.2) if absf(fora.z) > 0.5 else Vector3(0.2, 0.09, 1.4),
				pedra, 0.0, PSXMesh.FACE_TODAS, 8.0)
	# Pingadeira na lateral tambem, na altura de cada laje: sem ela a quina do
	# predio tem faixa de um lado e nao do outro.
	for andar in range(1, andares):
		var meio := _ponto(face, t, prof * 0.5) + fora * 0.05 \
			+ Vector3(0.0, float(andar) * KitModular.ALTURA_ANDAR, 0.0)
		KitModular.caixa_cor(sup, &"concreto", meio,
			Vector3(0.12, 0.12, prof) if absf(fora.x) > 0.5 else Vector3(prof, 0.12, 0.12),
			cor.darkened(0.18), 0.0, PSXMesh.FACE_TODAS, 4.0)


## O jardim da casa recuada: muro baixo na linha da calcada, portao de ferro,
## grama, o caminho de cimento ate a porta e uma moita.
##
## Casa de rua do interior nem sempre encosta na calcada. Uma em cada tres ou
## quatro recua uns tres metros e deixa na frente o jardinzinho murado — e e ele
## que quebra o paredao da fileira, visto da calcada, por cima do muro de um
## metro. `frente_lote` e o meio do lote na linha da fachada da quadra; a casa
## em si comeca `recuo` metros para dentro.
static func jardim(sup: Dictionary, colisao: Array[Dictionary], frente_lote: Vector3,
		larg: float, recuo: float, direcao: int, porta_em: float, cor: Color,
		rng: RandomNumberGenerator) -> void:
	if not ativo:
		return
	var normal := KitModular._normal(direcao)
	var lateral := KitModular._lateral(direcao)
	var giro := atan2(normal.x, normal.z)
	var h := KitModular.ALTURA_MEIO_FIO
	const MURO := 1.1
	const ESP := 0.15

	# Chao do jardim na altura da calcada: a casa inteira esta um degrau acima da
	# rua, e o jardim abaixo dela seria um buraco de 16 cm atras do muro.
	var a := frente_lote - lateral * (larg * 0.5) - normal * ESP
	var b := frente_lote + lateral * (larg * 0.5) - normal * recuo
	var r := Rect2(Vector2(minf(a.x, b.x), minf(a.z, b.z)),
		Vector2(absf(b.x - a.x), absf(b.z - a.z)))
	KitModular.chao(sup, &"grama", Vector3(r.position.x, h + 0.01, r.position.y),
		r.size, 4.0, Color(0.7, 0.76, 0.52).lerp(Color(0.62, 0.7, 0.46), rng.randf()))

	# Portao alinhado com a porta, quando ela existe; senao, num ponto qualquer.
	var gx := porta_em if is_finite(porta_em) \
		else rng.randf_range(-larg * 0.5 + 1.0, larg * 0.5 - 1.0)
	gx = clampf(gx, -larg * 0.5 + 0.9, larg * 0.5 - 0.9)
	# Caminho de cimento do portao ate a porta.
	var c0 := frente_lote + lateral * (gx - 0.45) - normal * ESP
	var c1 := frente_lote + lateral * (gx + 0.45) - normal * recuo
	KitModular.chao(sup, &"concreto",
		Vector3(minf(c0.x, c1.x), h + 0.03, minf(c0.z, c1.z)),
		Vector2(absf(c1.x - c0.x), absf(c1.z - c0.z)), 4.0, Color(0.7, 0.69, 0.66))

	# Muro baixo em dois trechos, dos dois lados do portao.
	var linha := frente_lote - normal * (ESP * 0.5)
	for trecho: Vector2 in [Vector2(-larg * 0.5, gx - 0.6), Vector2(gx + 0.6, larg * 0.5)]:
		var comp := trecho.y - trecho.x
		if comp < 0.1:
			continue
		var meio := linha + lateral * ((trecho.x + trecho.y) * 0.5)
		var tam := Vector3(comp, MURO, ESP) if absf(normal.z) > 0.5 \
			else Vector3(ESP, MURO, comp)
		KitModular.caixa_cor(sup, &"reboco", meio + Vector3(0.0, h + MURO * 0.5, 0.0),
			tam, cor, 0.0, PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, QUAD_FUNDO)
		KitModular.caixa_cor(sup, &"concreto", meio + Vector3(0.0, h + MURO + 0.04, 0.0),
			tam + Vector3(0.06 if absf(normal.x) > 0.5 else 0.0, -MURO + 0.08,
				0.06 if absf(normal.z) > 0.5 else 0.0),
			Color(0.72, 0.7, 0.66), 0.0, PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, 8.0)
	# O portao de ferro, fechado, e os dois pilares dele.
	KitModular.placa(sup, &"metal", linha + lateral * gx + normal * 0.02
		+ Vector3(0.0, h + 0.55, 0.0), Vector2(1.14, 1.05), giro, Color("3e4042"))
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"reboco",
			linha + lateral * (gx + lado * 0.63) + Vector3(0.0, h + 0.68, 0.0),
			Vector3(0.24, 1.36, 0.24), cor.darkened(0.1), 0.0,
			PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, 8.0)
	# O muro inteiro e colisao, portao incluso: ele esta fechado.
	var tam_col := Vector3(larg, MURO + h, ESP) if absf(normal.z) > 0.5 \
		else Vector3(ESP, MURO + h, larg)
	colisao.append({"tamanho": tam_col, "pos": linha + Vector3(0.0, (MURO + h) * 0.5, 0.0)})

	# Uma moita num canto do jardim, e as vezes uma arvoreta.
	var lado_moita := -1.0 if gx > 0.0 else 1.0
	KitParque.arbusto(sup, frente_lote + lateral * (lado_moita * larg * 0.3)
		- normal * (recuo * 0.5) + Vector3(0.0, h, 0.0), 0.5, rng)
	if recuo > 3.0 and rng.randf() < 0.25:
		var arvore_rng := RandomNumberGenerator.new()
		arvore_rng.seed = rng.randi()
		var descartavel: Array[Dictionary] = []
		KitParque.arvore(sup, descartavel, frente_lote + lateral * (lado_moita * larg * 0.3)
			- normal * (recuo * 0.55) + Vector3(0.0, h, 0.0), 0.0, arvore_rng)


## A direcao de `KitModular.parede` que olha para `v` (0 +Z, 1 +X, 2 -Z, 3 -X).
static func _direcao_de(v: Vector3) -> int:
	if absf(v.x) > absf(v.z):
		return 1 if v.x > 0.0 else 3
	return 0 if v.z > 0.0 else 2


# --- quintais ---------------------------------------------------------------

## Os quintais atras das fileiras deste chunk.
##
## `lotes` vem de `_fileira`: um por predio, com a face e o trecho [de, ate] que
## ele ocupa ao longo dela. Muro de divisa no comeco de cada lote, muro de fundo
## ao longo da faixa inteira, e o que tem dentro de cada quintal.
static func quintais(sup: Dictionary, colisao: Array[Dictionary],
		faces: Array[Dictionary], lotes: Array[Dictionary], quadra: Dictionary,
		lim: Rect2, rng: RandomNumberGenerator) -> void:
	if faces.is_empty() or not ativo:
		return
	var q := profundidade_quintal(quadra)
	if q < 1.0:
		return
	var prof := ChunkBuilder.PROF_PREDIO
	var tem := {"x0": false, "x1": false, "z0": false, "z1": false}
	for f: Dictionary in faces:
		match int(f["direcao"]):
			3: tem["x0"] = true
			1: tem["x1"] = true
			2: tem["z0"] = true
			0: tem["z1"] = true

	# A regiao atras dos predios, e o miolo alem dos quintais.
	var ix0 := lim.position.x + (prof if tem["x0"] else 0.0)
	var ix1 := lim.end.x - (prof if tem["x1"] else 0.0)
	var iz0 := lim.position.y + (prof if tem["z0"] else 0.0)
	var iz1 := lim.end.y - (prof if tem["z1"] else 0.0)
	if ix1 - ix0 < 1.0 or iz1 - iz0 < 1.0:
		return

	var residencial := bool(quadra["casa"])
	var mat_muro: StringName = &"reboco"
	var h := int(quadra["semente"])
	if residencial:
		mat_muro = &"tijolo" if (h / 7) % 3 == 0 else &"reboco"
	else:
		mat_muro = &"tijolo" if (h / 7) % 2 == 0 else &"concreto_sujo"
	var tinta_muro: Color = Color(quadra["tinta"]).lerp(Color("b8b2a6"), 0.35)

	for face: Dictionary in faces:
		var direcao := int(face["direcao"])
		var ao_longo_de_z := direcao == 1 or direcao == 3
		var canto: Vector3 = face["canto"]
		# Trecho da face em que ha quintal. A faixa do eixo X fica com a quina;
		# a do eixo Z comeca depois do quintal dela.
		var t_min: float
		var t_max: float
		if ao_longo_de_z:
			t_min = iz0 - canto.z
			t_max = iz1 - canto.z
		else:
			t_min = ix0 + (q if tem["x0"] else 0.0) - canto.x
			t_max = ix1 - (q if tem["x1"] else 0.0) - canto.x
		if t_max - t_min < 0.5:
			continue

		# A casa da fumaca tem sala de verdade atras da fachada, e ela e mais
		# funda que a fileira (KitFumaca.LOTE). Muro nenhum pode passar por
		# dentro dela: nem divisa nas duas pontas do lote, nem o de fundo, se a
		# casa chegar ate ele.
		var casas_fundas: Array[Vector2] = []
		# Beco que da numa vila (BecoBuilder._vila): entre ele e os dois lotes
		# vizinhos nao ha muro, e o quintal deles e o patio.
		var vilas: Array[Vector2] = []
		for lote: Dictionary in lotes:
			if lote["face"] == face and bool(lote.get("fumaca", false)):
				casas_fundas.append(Vector2(float(lote["de"]), float(lote["ate"])))
			if lote["face"] == face and bool(lote.get("vila", false)):
				vilas.append(Vector2(float(lote["de"]), float(lote["ate"])))

		# Muro de fundo, a todo o comprimento da faixa.
		var trechos: Array[Vector2] = [Vector2(t_min, t_max)]
		if KitFumaca.LOTE.y > prof + q - 0.2:
			for casa: Vector2 in casas_fundas:
				var novos: Array[Vector2] = []
				for tr: Vector2 in trechos:
					if casa.y <= tr.x or casa.x >= tr.y:
						novos.append(tr)
						continue
					if casa.x > tr.x:
						novos.append(Vector2(tr.x, casa.x))
					if casa.y < tr.y:
						novos.append(Vector2(casa.y, tr.y))
				trechos = novos
		for tr: Vector2 in trechos:
			_muro(sup, colisao, face, tr.x, tr.y, prof + q, prof + q,
				mat_muro, tinta_muro)

		for lote: Dictionary in lotes:
			if lote["face"] != face:
				continue
			var de := float(lote["de"])
			var ate := float(lote["ate"])
			var encosta_na_casa := false
			for casa: Vector2 in casas_fundas:
				if absf(de - casa.x) < 0.05 or absf(de - casa.y) < 0.05:
					encosta_na_casa = true
			var da_vila := false
			for v: Vector2 in vilas:
				if absf(de - v.x) < 0.05 or absf(de - v.y) < 0.05:
					encosta_na_casa = true
				if absf(ate - v.x) < 0.05 or absf(de - v.y) < 0.05:
					da_vila = true
			# Muro de divisa no comeco do lote. Na quina ocupada pelo predio da
			# outra fileira nao ha divisa: o fundo ali e a parede de tras dele.
			if de >= t_min - 0.01 and de < t_max - 0.01 and not encosta_na_casa \
					and (de > t_min + 0.05 or t_min < 0.05):
				_muro(sup, colisao, face, de, de, prof, prof + q, mat_muro, tinta_muro)
			var a := maxf(de, t_min)
			var b := minf(ate, t_max)
			if b - a < 2.4 or q < QUINTAL_MIN or bool(lote.get("fumaca", false)) \
					or bool(lote.get("beco", false)) or da_vila:
				continue
			_quintal(sup, face, a, b, q, bool(lote["casa"]), rng)

	_miolo(sup, colisao, Rect2(
		ix0 + (q if tem["x0"] else 0.0), iz0 + (q if tem["z0"] else 0.0),
		ix1 - ix0 - (q if tem["x0"] else 0.0) - (q if tem["x1"] else 0.0),
		iz1 - iz0 - (q if tem["z0"] else 0.0) - (q if tem["z1"] else 0.0)), rng)


## Ponto do chunk a partir de (t, s) da face.
static func _ponto(face: Dictionary, t: float, s: float) -> Vector3:
	var normal := KitModular._normal(int(face["direcao"]))
	return Vector3(face["canto"]) + Vector3(face["eixo"]) * t - normal * s


## Muro reto entre (t0, s0) e (t1, s1) — um dos dois eixos e constante.
static func _muro(sup: Dictionary, colisao: Array[Dictionary], face: Dictionary,
		t0: float, t1: float, s0: float, s1: float, material: StringName,
		cor: Color) -> void:
	var a := _ponto(face, t0, s0)
	var b := _ponto(face, t1, s1)
	var meio := (a + b) * 0.5
	var delta := (b - a).abs()
	var tamanho := Vector3(maxf(delta.x, ESPESSURA_MURO), ALTURA_MURO,
		maxf(delta.z, ESPESSURA_MURO))
	if tamanho.x < 0.2 and tamanho.z < 0.2:
		return
	# O muro desce um metro abaixo do chao. Na ladeira (Relevo) ele e deformado
	# com o terreno e o piso do beco e da vila sobe rigido: sem o metro enterrado,
	# o pe do muro ficava acima do piso do lado de cima e abria uma fresta.
	var visivel := tamanho + Vector3(0.0, ENTERRADO, 0.0)
	KitModular.caixa_cor(sup, material,
		meio + Vector3(0.0, (ALTURA_MURO - ENTERRADO) * 0.5, 0.0),
		visivel, cor, 0.0, PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, QUAD_FUNDO)
	# Chapim: a fiada de cima, mais larga e mais escura. Sem ela o muro termina
	# num corte limpo que nenhum muro de fundo de quintal tem.
	KitModular.caixa_cor(sup, &"concreto_sujo",
		meio + Vector3(0.0, ALTURA_MURO + 0.04, 0.0),
		tamanho + Vector3(0.08 if delta.x < 0.2 else 0.0, 0.08,
			0.08 if delta.z < 0.2 else 0.0),
		Color(0.55, 0.54, 0.51), 0.0, PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE,
		QUAD_FUNDO)
	colisao.append({"tamanho": tamanho, "pos": meio + Vector3(0.0, ALTURA_MURO * 0.5, 0.0)})


## O que tem dentro de um quintal. [a, b] ao longo da face, `q` de fundura.
static func _quintal(sup: Dictionary, face: Dictionary, a: float, b: float,
		q: float, casa: bool, rng: RandomNumberGenerator) -> void:
	var prof := ChunkBuilder.PROF_PREDIO
	var direcao := int(face["direcao"])
	var normal := KitModular._normal(direcao)
	var giro_fundo := atan2(-normal.x, -normal.z)
	var w := b - a

	# Cimentado junto da casa: o piso da area de servico. O resto e terra.
	var p0 := _ponto(face, a, prof)
	var p1 := _ponto(face, b, prof + minf(2.2, q * 0.5))
	var r := Rect2(Vector2(minf(p0.x, p1.x), minf(p0.z, p1.z)),
		Vector2(absf(p1.x - p0.x), absf(p1.z - p0.z)))
	KitModular.chao(sup, &"concreto", Vector3(r.position.x, 0.04, r.position.y),
		r.size, 4.0, Color(0.62, 0.61, 0.58))

	# Tanque de lavar, encostado na parede de tras.
	var t_tanque := a + rng.randf_range(0.7, maxf(0.8, w - 0.7))
	KitModular.caixa_cor(sup, &"concreto",
		_ponto(face, t_tanque, prof + 0.32) + Vector3(0.0, 0.45, 0.0),
		Vector3(0.6, 0.9, 0.55), Color(0.78, 0.77, 0.74), giro_fundo,
		PSXMesh.FACE_TODAS, 8.0)

	var sobra_fundo := q
	# Puxadinho: o comodo de fundo, de um pavimento, com meia-agua de telha.
	# E a coisa mais comum de quintal de casa brasileira e a que mais muda a
	# silhueta vista do alto.
	if casa and q >= 4.0 and w >= 4.0 and rng.randf() < 0.42:
		var fundura := minf(3.2, q - 1.4)
		var largura := w * rng.randf_range(0.45, 0.75)
		var t0 := a + rng.randf_range(0.0, w - largura)
		_puxadinho(sup, face, t0, t0 + largura, fundura, rng)
		sobra_fundo = q - fundura

	# Varal de fio entre dois pontaletes, com a roupa pendurada.
	if casa and sobra_fundo >= 2.0 and w >= 3.0 and rng.randf() < 0.6:
		var s := prof + q - minf(1.2, sobra_fundo * 0.4)
		var ta := a + 0.5
		var tb := b - 0.5
		for t: float in [ta, tb]:
			KitModular.caixa_cor(sup, &"metal",
				_ponto(face, t, s) + Vector3(0.0, 0.95, 0.0),
				Vector3(0.06, 1.9, 0.06), Color("6e6a62"), 0.0, PSXMesh.FACE_TODAS, 8.0)
		var fio_a := _ponto(face, ta, s) + Vector3(0.0, 1.8, 0.0)
		var fio_b := _ponto(face, tb, s) + Vector3(0.0, 1.8, 0.0)
		KitModular.cabo(sup, fio_a, fio_b)
		var pecas := rng.randi_range(2, mini(5, int(w / 1.1)))
		var giro_roupa := atan2(normal.x, normal.z)
		for k in pecas:
			var t := ta + (tb - ta) * (float(k) + 0.5) / float(pecas) \
				+ rng.randf_range(-0.15, 0.15)
			var tam := Vector2(rng.randf_range(0.45, 0.8), rng.randf_range(0.45, 0.85))
			var c := ROUPAS[rng.randi() % ROUPAS.size()]
			# Dupla face: a roupa e vista dos dois quintais.
			for lado: float in [0.0, PI]:
				KitModular.placa(sup, &"toldo",
					_ponto(face, t, s) + Vector3(0.0, 1.78 - tam.y * 0.5, 0.0),
					tam, giro_roupa + lado, c, 8.0)
	elif not casa and rng.randf() < 0.5:
		# Fundo de comercio: tambores e um estrado de madeira.
		for k in rng.randi_range(1, 3):
			var t := a + rng.randf_range(0.6, maxf(0.7, w - 0.6))
			var s := prof + rng.randf_range(0.8, maxf(0.9, q - 0.6))
			KitModular.caixa_cor(sup, &"metal_enferrujado",
				_ponto(face, t, s) + Vector3(0.0, 0.45, 0.0),
				Vector3(0.58, 0.9, 0.58), Color.WHITE.lerp(Color("5a6e7a"),
					rng.randf_range(0.0, 0.6)), rng.randf_range(0.0, PI),
				PSXMesh.FACE_TODAS, 8.0)
		KitModular.caixa_cor(sup, &"tabua",
			_ponto(face, a + w * 0.5, prof + q - 0.9) + Vector3(0.0, 0.07, 0.0),
			Vector3(1.2, 0.14, 1.0), Color(0.72, 0.62, 0.5), giro_fundo,
			PSXMesh.FACE_TODAS, 8.0)

	# Uma arvore de quintal de vez em quando: a mangueira que aparece por cima
	# do telhado da casa terrea e o sinal mais barato de que a quadra tem miolo.
	if casa and q >= 6.0 and w >= 5.0 and rng.randf() < 0.22:
		var base := _ponto(face, a + w * rng.randf_range(0.35, 0.65),
			prof + q - 2.2)
		var arvore_rng := RandomNumberGenerator.new()
		arvore_rng.seed = rng.randi()
		var descartavel: Array[Dictionary] = []
		KitParque.arvore(sup, descartavel, base, rng.randf_range(0.0, 0.35), arvore_rng)


## Comodo de fundo de um pavimento com meia-agua de telha caindo para o quintal.
static func _puxadinho(sup: Dictionary, face: Dictionary, t0: float, t1: float,
		fundura: float, rng: RandomNumberGenerator) -> void:
	var prof := ChunkBuilder.PROF_PREDIO
	var direcao := int(face["direcao"])
	var normal := KitModular._normal(direcao)
	const ALTO := 2.7
	var a := _ponto(face, t0, prof)
	var b := _ponto(face, t1, prof + fundura)
	var meio := (a + b) * 0.5
	var tam := (b - a).abs()
	var cor := Color("d9d2c2").lerp(Color("c8b8a0"), rng.randf())
	KitModular.caixa_cor(sup, &"reboco", meio + Vector3(0.0, ALTO * 0.5, 0.0),
		Vector3(tam.x, ALTO, tam.z), cor, 0.0,
		PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, QUAD_FUNDO)

	# Janela e porta viradas para o quintal.
	var dir_quintal := posmod(direcao + 2, 4)
	var fora := -normal
	var lateral := KitModular._lateral(dir_quintal)
	var face_quintal := _ponto(face, (t0 + t1) * 0.5, prof + fundura) + fora * 0.02
	KitModular.parede(sup, &"porta", face_quintal + Vector3(0.0, 1.0, 0.0)
		+ lateral * ((t1 - t0) * 0.25), Vector2(0.8, 2.0), dir_quintal)
	KitModular.parede(sup, &"janela_apagada", face_quintal + Vector3(0.0, 1.55, 0.0)
		- lateral * ((t1 - t0) * 0.22), Vector2(0.9, 0.8), dir_quintal)

	# Meia-agua: sobe encostada na parede de tras e cai para o quintal.
	var caimento := 0.35
	var comp := fundura + 0.45
	var inclinacao := atan2(caimento, comp)
	var giro := atan2(fora.x, fora.z)
	var centro := _ponto(face, (t0 + t1) * 0.5, prof + comp * 0.5) \
		+ Vector3(0.0, ALTO + 0.12 + caimento * 0.5, 0.0)
	var base := Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, inclinacao)
	KitModular.caixa_livre(sup, &"telha", centro,
		Vector3(absf(t1 - t0) + 0.3, 0.08, comp), base, Color.WHITE, QUAD_FUNDO)


## O miolo alem dos muros de fundo: terra, mato e, de vez em quando, uma arvore.
static func _miolo(sup: Dictionary, _colisao: Array[Dictionary], r: Rect2,
		rng: RandomNumberGenerator) -> void:
	if r.size.x < 6.0 or r.size.y < 6.0:
		return
	# Capim por cima da terra: miolo de quadra do interior e terreno sem dono.
	KitModular.chao(sup, &"grama", Vector3(r.position.x, 0.035, r.position.y),
		r.size, 8.0, Color(0.62, 0.62, 0.5))
	if rng.randf() < 0.5:
		var base := Vector3(rng.randf_range(r.position.x + 2.5, r.end.x - 2.5),
			0.0, rng.randf_range(r.position.y + 2.5, r.end.y - 2.5))
		var arvore_rng := RandomNumberGenerator.new()
		arvore_rng.seed = rng.randi()
		var descartavel: Array[Dictionary] = []
		KitParque.arvore(sup, descartavel, base, rng.randf_range(0.2, 0.6), arvore_rng)
