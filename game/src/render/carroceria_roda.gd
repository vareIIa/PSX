## A roda do carro: pneu com perfil, aro com prato e o desenho de cada modelo
## (PLANO_CARROS_AAA, F3).
##
## A roda de antes era um prisma de oito lados com um disco cinza chapado na
## face. De lado ela lia como octogono, de tres quartos como lata, e o jogador
## resumiu: "roda feia e zero realismo". Roda e a peca que o olho mais cobra num
## carro, porque e a unica que gira: um poligono girando denuncia os lados.
##
## O que ha aqui
## -------------
##   pneu    um perfil de dez pontos varrido em volta do eixo: talao, flanco
##           abaulado, ombro redondo e banda de rodagem. A banda leva o sulco do
##           atlas; o flanco e borracha lisa.
##   aro     a aba que segura o talao e o prato que afunda ate a face, que e o
##           que da profundidade a roda vista de tres quartos.
##   face    o desenho do modelo, com FUROS de verdade: calota de plastico com
##           fendas, aro de aco com furos e porcas, liga de cinco raios no Marea,
##           e o aro pintado com o copo cromado no Fusca. Atras dos furos mora o
##           tambor de freio escuro.
##
## No PS1 STYLE a roda continua simples — doze lados, disco da calota do atlas
## — porque o orcamento de triangulos de la e outro e o desenho de 256 px ja
## conta a historia. Quem escolhe e `Carroceria`, pelo preset.
##
## Sem class_name pelo mesmo motivo dos outros modulos: ver Carroceria._modulo().
extends RefCounted

enum Tipo { CALOTA, ACO, LIGA, FUSCA }

## Perfil do pneu 175/70 R13: (raio, posicao no eixo), do talao de dentro ao de
## fora. O flanco abaulado passa um pouco da largura da banda, como pneu de
## verdade cheio; e o ombro que faz a roda ler redonda de frente.
const PNEU := [
	Vector2(0.186, -0.078), Vector2(0.232, -0.097), Vector2(0.276, -0.094),
	Vector2(0.295, -0.076), Vector2(0.300, -0.040), Vector2(0.300, 0.040),
	Vector2(0.295, 0.076), Vector2(0.276, 0.094), Vector2(0.232, 0.097),
	Vector2(0.186, 0.078),
]
## Os indices do perfil que sao banda de rodagem (levam o sulco do atlas).
const BANDA := [3, 4, 5]
const PNEU_PS1 := [
	Vector2(0.186, -0.080), Vector2(0.284, -0.092), Vector2(0.300, -0.050),
	Vector2(0.300, 0.050), Vector2(0.284, 0.092), Vector2(0.186, 0.080),
]

const LADOS := 30
const LADOS_PS1 := 12

## Borracha: a banda e o flanco multiplicam o texel do atlas do pneu (44 de
## 255); o flanco fica um pouco mais claro, que e a poeira seca que ele junta.
const BORRACHA := Color(1.0, 1.0, 1.0)
const FLANCO := Color(1.0, 0.98, 0.95)
const TAMBOR := Color(0.30, 0.28, 0.26)


## Uma roda inteira, centrada em `centro`. `direita` diz para que lado a face
## olha (+X ou -X). `detalhe` false e a roda de PS1.
static func montar(dados: Dictionary, centro: Vector3, direita: bool, tipo: int,
		cor_aro: Color, detalhe: bool) -> void:
	var sx := 1.0 if direita else -1.0
	if not detalhe:
		_pneu(dados, centro, sx, PNEU_PS1, LADOS_PS1, [2])
		_disco_ps1(dados, centro, sx)
		return
	_pneu(dados, centro, sx, PNEU, LADOS, BANDA)
	_aro(dados, centro, sx, tipo, cor_aro)


# --- pneu --------------------------------------------------------------------

## O perfil varrido em volta do eixo, com a normal de cada ponto do perfil: a
## banda e o flanco saem suaves e o ombro pega a luz inteiro.
static func _pneu(dados: Dictionary, centro: Vector3, sx: float, perfil: Array,
		lados: int, banda: Array) -> void:
	var cel := Carroceria.uv(Carroceria.C_PNEU)
	var v: PackedVector3Array = dados["v"]
	var n: PackedVector3Array = dados["n"]
	var u: PackedVector2Array = dados["uv"]
	var c: PackedColorArray = dados["c"]
	var i: PackedInt32Array = dados["i"]
	var borracha := Carroceria.marcar(BORRACHA, Carroceria.Classe.BORRACHA)
	var flanco := Carroceria.marcar(FLANCO, Carroceria.Classe.BORRACHA)
	# Normal no plano (raio, eixo) de cada ponto do perfil, pela media das duas
	# arestas vizinhas.
	var normais: Array[Vector2] = []
	for k in perfil.size():
		var a: Vector2 = perfil[maxi(k - 1, 0)]
		var b: Vector2 = perfil[mini(k + 1, perfil.size() - 1)]
		var d := b - a
		# O perfil anda de dentro (-eixo) para fora (+eixo) passando por cima:
		# a normal para fora e a tangente girada para o lado do raio.
		normais.append(Vector2(d.y, -d.x).normalized())
	for seg in perfil.size() - 1:
		var na_banda := seg in banda
		for k in lados:
			# Quatro vertices por quadrilatero, e nao anel compartilhado: o sulco
			# do atlas anda um quarto de celula por gomo e recomeca a cada quatro,
			# e UV compartilhada teria de voltar de 1 para 0 no meio de um gomo.
			var base := v.size()
			for canto in 4:
				var dk := 1 if canto == 1 or canto == 2 else 0
				var dm := 1 if canto >= 2 else 0
				var ang := TAU * float(k + dk) / float(lados)
				var radial := Vector3(0.0, sin(ang), cos(ang))
				var p: Vector2 = perfil[seg + dm]
				var pn: Vector2 = normais[seg + dm]
				v.append(centro + radial * p.x + Vector3(sx * p.y, 0.0, 0.0))
				n.append((radial * pn.x + Vector3(sx * pn.y, 0.0, 0.0)).normalized())
				if na_banda:
					var fu := (float(k % 4) + float(dk)) * 0.25
					u.append(cel.position + Vector2(fu, 0.15 + 0.7 * float(dm)) * cel.size)
					c.append(borracha)
				else:
					u.append(cel.position + Vector2(5.5 / 32.0, 0.5) * cel.size)
					c.append(flanco)
			_tri_fora(i, v, n, base, base + 1, base + 2)
			_tri_fora(i, v, n, base, base + 2, base + 3)
	# Devolve os arrays ANTES de qualquer outra escrita: Packed*Array e copia
	# por valor, e o disco abaixo le e grava `dados` por conta propria.
	dados["v"] = v
	dados["n"] = n
	dados["uv"] = u
	dados["c"] = c
	dados["i"] = i
	# O talao de dentro fechado por um disco escuro: por baixo do carro nao se
	# ve o oco da roda.
	var dentro: Vector2 = perfil[0]
	_disco(dados, centro + Vector3(sx * dentro.y, 0.0, 0.0), -sx, dentro.x,
		lados, Carroceria.marcar(TAMBOR * 0.4, Carroceria.Classe.FUNDO),
		Carroceria.C_FUNDO)


# --- aro e face ----------------------------------------------------------------

## Aba, prato e face. A face e uma grade polar (aneis x setores); cada celula e
## chapa ou furo conforme o desenho do tipo, e a borda entre chapa e furo ganha
## a espessura da chapa. Atras de tudo, o tambor.
static func _aro(dados: Dictionary, centro: Vector3, sx: float, tipo: int,
		cor_aro: Color) -> void:
	var d := _desenho(tipo, cor_aro)
	var aneis: Array = d["aneis"]          # [raio, profundidade] de fora p/ dentro
	var lados: int = d["lados"]
	var metal: Color = d["cor"]
	var borda: Color = d["borda"]
	var cel := Carroceria.C_PARACHOQUE

	# Aba e prato: do talao ate o primeiro anel da face.
	var talao: Vector2 = PNEU[PNEU.size() - 1]
	var aba := [
		Vector2(talao.x + 0.004, talao.y + 0.004),
		Vector2(talao.x - 0.006, talao.y + 0.008),
		Vector2(talao.x - 0.014, talao.y - 0.004),
		Vector2(float(aneis[0][0]) + 0.004, float(aneis[0][1]) + 0.002),
	]
	for k in aba.size() - 1:
		_anel(dados, centro, sx, aba[k], aba[k + 1], lados,
			borda if k < 2 else metal, cel)

	# A face, anel por anel.
	for r in aneis.size() - 1:
		var fora_r: Array = aneis[r]
		var dentro_r: Array = aneis[r + 1]
		for k in lados:
			if _furo(tipo, r, k, lados):
				_parede_furo(dados, centro, sx, tipo, r, k, lados, aneis, metal, cel)
				continue
			# O copo do Fusca e cromo; o aro em volta e pintado.
			var tinta_anel: Color = d["cromo"] if d.has("cromo") and r >= 3 else metal
			_setor(dados, centro, sx, k, lados,
				Vector2(fora_r[0], fora_r[1]), Vector2(dentro_r[0], dentro_r[1]),
				tinta_anel, cel)
	# O miolo: o ultimo anel fecha num ponto.
	var miolo: Array = aneis[aneis.size() - 1]
	if float(miolo[0]) > 0.001:
		_disco(dados, centro + Vector3(sx * float(miolo[1]), 0.0, 0.0), sx,
			float(miolo[0]), lados, d.get("cor_miolo", metal), cel)

	# Porcas.
	var porcas: int = d.get("porcas", 0)
	for k in porcas:
		var ang := TAU * (float(k) + 0.5) / float(porcas)
		var r_p: float = d.get("raio_porcas", 0.055)
		var prof: float = d.get("prof_porcas", 0.03)
		_porca(dados, centro + Vector3(sx * prof, sin(ang) * r_p, cos(ang) * r_p), sx)

	# O tambor atras dos furos: escuro, e um pouco de ferrugem na borda.
	_disco(dados, centro + Vector3(sx * float(d.get("tambor", 0.0)), 0.0, 0.0), sx,
		0.168, lados, Carroceria.marcar(TAMBOR, Carroceria.Classe.FUNDO),
		Carroceria.C_FUNDO)


## O desenho de cada tipo: aneis da face (raio, profundidade no eixo, de fora
## para dentro), cor, porcas e onde fica o tambor.
static func _desenho(tipo: int, cor_aro: Color) -> Dictionary:
	match tipo:
		Tipo.ACO:
			# Aro de aco estampado, pintado de grafite: face plana funda, seis
			# furos ovais de ventilacao, quatro porcas e a tampinha do cubo.
			var aco := Carroceria.marcar(cor_aro, Carroceria.Classe.PLASTICO)
			return {
				"lados": LADOS,
				"aneis": [[0.170, 0.030], [0.140, 0.028], [0.092, 0.028],
					[0.070, 0.036], [0.030, 0.040]],
				"cor": aco, "borda": aco,
				"cor_miolo": Carroceria.marcar(Color(0.70, 0.71, 0.73), Carroceria.Classe.CROMO),
				"porcas": 4, "raio_porcas": 0.052, "prof_porcas": 0.040,
				"tambor": 0.004,
			}
		Tipo.LIGA:
			# Liga de cinco raios, prato fundo: o raio sai do cubo e alarga ate
			# o aro, e entre eles se ve o freio.
			var liga := Carroceria.marcar(Color(0.62, 0.63, 0.65), Carroceria.Classe.CROMO)
			return {
				"lados": LADOS,
				"aneis": [[0.172, 0.020], [0.150, 0.026], [0.100, 0.040],
					[0.062, 0.050], [0.034, 0.054]],
				"cor": liga, "borda": liga,
				"cor_miolo": Carroceria.marcar(Color(0.16, 0.16, 0.17), Carroceria.Classe.PLASTICO),
				"porcas": 5, "raio_porcas": 0.048, "prof_porcas": 0.054,
				"tambor": -0.004,
			}
		Tipo.FUSCA:
			# Aro de aco pintado, com as fendas perto da borda, e o copo
			# cromado abaulado no meio — a cara do Fusca.
			var pintado := Carroceria.marcar(cor_aro, Carroceria.Classe.PLASTICO)
			var cromo := Carroceria.marcar(Color(0.80, 0.80, 0.82), Carroceria.Classe.CROMO)
			return {
				"lados": LADOS,
				"aneis": [[0.170, 0.026], [0.156, 0.026], [0.140, 0.026],
					[0.108, 0.030], [0.096, 0.052], [0.070, 0.070],
					[0.036, 0.080], [0.0, 0.082]],
				"cor": pintado, "borda": pintado,
				"cromo": cromo,
				"tambor": 0.004,
			}
		_:
			# Calota de plastico prateado, abaulada, com oito fendas no anel.
			# Plastico prateado, e nao cromo: calota de rua e pintada, e cromo
			# de espelho refletia o asfalto e a roda saia escura.
			var calota := Carroceria.marcar(Color(0.80, 0.81, 0.83), Carroceria.Classe.PLASTICO)
			var aro := Carroceria.marcar(Color(0.30, 0.30, 0.31), Carroceria.Classe.PLASTICO)
			return {
				"lados": LADOS,
				"aneis": [[0.172, 0.052], [0.150, 0.062], [0.104, 0.070],
					[0.070, 0.074], [0.034, 0.078], [0.0, 0.079]],
				"cor": calota, "borda": aro,
				"tambor": 0.010,
			}


## Esta celula da face e furo?
static func _furo(tipo: int, anel: int, setor: int, lados: int) -> bool:
	match tipo:
		Tipo.ACO:
			# Seis furos, cada um com dois setores, no anel do meio.
			return anel == 1 and (setor % 5) in [1, 2]
		Tipo.LIGA:
			# Cinco raios de dois setores; o resto do anel largo e vazado.
			return (anel == 1 or anel == 2) and (setor % 6) >= 2
		Tipo.FUSCA:
			# Oito fendas curtas perto da borda.
			return anel == 1 and setor % 4 == 1 and lados == LADOS
		_:
			# Calota: dez fendas no anel largo.
			return anel == 1 and setor % 3 == 1
	return false


## Um setor de chapa entre dois aneis.
static func _setor(dados: Dictionary, centro: Vector3, sx: float, k: int,
		lados: int, fora_r: Vector2, dentro_r: Vector2, cor: Color,
		cel: Vector2i) -> void:
	var a0 := TAU * float(k) / float(lados)
	var a1 := TAU * float(k + 1) / float(lados)
	var r0 := Vector3(0.0, sin(a0), cos(a0))
	var r1 := Vector3(0.0, sin(a1), cos(a1))
	var p0 := centro + r0 * fora_r.x + Vector3(sx * fora_r.y, 0.0, 0.0)
	var p1 := centro + r1 * fora_r.x + Vector3(sx * fora_r.y, 0.0, 0.0)
	var p2 := centro + r1 * dentro_r.x + Vector3(sx * dentro_r.y, 0.0, 0.0)
	var p3 := centro + r0 * dentro_r.x + Vector3(sx * dentro_r.y, 0.0, 0.0)
	var tom := _tom(cor, fora_r, dentro_r)
	CarroceriaVarrida.quad(dados, p0, p1, p2, p3, cel, tom, tom, tom, tom,
		Vector3(sx, 0.0, 0.0))


## A cor do anel pela inclinacao dele: o prato que desce para o furo fica mais
## escuro, e e isso que desenha a profundidade sem luz nenhuma no PS1.
static func _tom(cor: Color, fora_r: Vector2, dentro_r: Vector2) -> Color:
	var inclina := (dentro_r.y - fora_r.y) / maxf(0.001, fora_r.x - dentro_r.x)
	var f := clampf(1.0 - absf(inclina) * 0.35, 0.72, 1.0)
	return Color(cor.r * f, cor.g * f, cor.b * f, cor.a)


## As paredes de um furo: a chapa tem espessura, e a borda do furo pega luz.
static func _parede_furo(dados: Dictionary, centro: Vector3, sx: float,
		tipo: int, anel: int, k: int, lados: int, aneis: Array, cor: Color,
		cel: Vector2i) -> void:
	var fundo := 0.012
	var fora_r: Array = aneis[anel]
	var dentro_r: Array = aneis[anel + 1]
	var a0 := TAU * float(k) / float(lados)
	var a1 := TAU * float(k + 1) / float(lados)
	var escuro := Color(cor.r * 0.55, cor.g * 0.55, cor.b * 0.55, cor.a)
	# Borda de fora e de dentro do anel (arcos), se o vizinho for chapa.
	for lado in 2:
		var rr: Array = fora_r if lado == 0 else dentro_r
		var viz := anel - 1 if lado == 0 else anel + 1
		if viz >= 0 and viz < aneis.size() - 1 and _furo(tipo, viz, k, lados):
			continue
		var r := float(rr[0])
		var x := float(rr[1])
		var p0 := centro + Vector3(sx * x, sin(a0) * r, cos(a0) * r)
		var p1 := centro + Vector3(sx * x, sin(a1) * r, cos(a1) * r)
		var d := Vector3(-sx * fundo, 0.0, 0.0)
		var olha := Vector3(0.0, sin((a0 + a1) * 0.5), cos((a0 + a1) * 0.5))
		if lado == 0:
			olha = -olha
		CarroceriaVarrida.quad(dados, p0, p1, p1 + d, p0 + d, cel, cor, cor,
			escuro, escuro, olha)
	# Bordas radiais (lados do setor), se o setor vizinho for chapa.
	for lado in 2:
		var viz_k := (k - 1 + lados) % lados if lado == 0 else (k + 1) % lados
		if _furo(tipo, anel, viz_k, lados):
			continue
		var a := a0 if lado == 0 else a1
		var rad := Vector3(0.0, sin(a), cos(a))
		var p0 := centro + rad * float(fora_r[0]) + Vector3(sx * float(fora_r[1]), 0.0, 0.0)
		var p1 := centro + rad * float(dentro_r[0]) + Vector3(sx * float(dentro_r[1]), 0.0, 0.0)
		var d := Vector3(-sx * fundo, 0.0, 0.0)
		var tang := Vector3(0.0, cos(a), -sin(a))
		var olha := tang if lado == 0 else -tang
		CarroceriaVarrida.quad(dados, p0, p1, p1 + d, p0 + d, cel, cor, cor,
			escuro, escuro, olha)


## Um anel inclinado do perfil do aro (aba e prato).
static func _anel(dados: Dictionary, centro: Vector3, sx: float, a: Vector2,
		b: Vector2, lados: int, cor: Color, cel: Vector2i) -> void:
	for k in lados:
		var a0 := TAU * float(k) / float(lados)
		var a1 := TAU * float(k + 1) / float(lados)
		var r0 := Vector3(0.0, sin(a0), cos(a0))
		var r1 := Vector3(0.0, sin(a1), cos(a1))
		var p0 := centro + r0 * a.x + Vector3(sx * a.y, 0.0, 0.0)
		var p1 := centro + r1 * a.x + Vector3(sx * a.y, 0.0, 0.0)
		var p2 := centro + r1 * b.x + Vector3(sx * b.y, 0.0, 0.0)
		var p3 := centro + r0 * b.x + Vector3(sx * b.y, 0.0, 0.0)
		var meio := (r0 + r1).normalized()
		# Para fora do aro: a aba olha para o lado e um pouco para o raio.
		var olha := (Vector3(sx, 0.0, 0.0) + meio * signf(a.x - b.x) * 0.3).normalized()
		CarroceriaVarrida.quad(dados, p0, p1, p2, p3, cel, cor, cor, cor, cor, olha)


## Disco plano virado para `sx`.
static func _disco(dados: Dictionary, centro: Vector3, sx: float, raio: float,
		lados: int, cor: Color, celula: Vector2i) -> void:
	var giro := Basis(Vector3.UP, sx * PI * 0.5)
	CarroceriaVarrida.disco(dados, centro, giro, raio, celula, cor, lados)


## A porca: prisma de seis lados, com a ponta.
static func _porca(dados: Dictionary, base: Vector3, sx: float) -> void:
	var cromo := Carroceria.marcar(Color(0.72, 0.72, 0.74), Carroceria.Classe.CROMO)
	var r := 0.011
	var alto := 0.010
	var cel := Carroceria.C_PARACHOQUE
	for k in 6:
		var a0 := TAU * float(k) / 6.0
		var a1 := TAU * float(k + 1) / 6.0
		var p0 := base + Vector3(0.0, sin(a0) * r, cos(a0) * r)
		var p1 := base + Vector3(0.0, sin(a1) * r, cos(a1) * r)
		var d := Vector3(sx * alto, 0.0, 0.0)
		var olha := Vector3(0.0, sin((a0 + a1) * 0.5), cos((a0 + a1) * 0.5))
		CarroceriaVarrida.quad(dados, p0, p1, p1 + d, p0 + d, cel, cromo, cromo,
			cromo, cromo, olha)
	_disco(dados, base + Vector3(sx * alto, 0.0, 0.0), sx, r, 6, cromo, cel)


## A face da roda de PS1: o disco da calota desenhada no atlas.
static func _disco_ps1(dados: Dictionary, centro: Vector3, sx: float) -> void:
	var r_calota := Carroceria.uv(Carroceria.C_CALOTA)
	var v: PackedVector3Array = dados["v"]
	var n: PackedVector3Array = dados["n"]
	var u: PackedVector2Array = dados["uv"]
	var c: PackedColorArray = dados["c"]
	var i: PackedInt32Array = dados["i"]
	var x := 0.084
	var cor := Color(0.62, 0.62, 0.64)
	var base := v.size()
	v.append(centro + Vector3(sx * x, 0.0, 0.0))
	n.append(Vector3(sx, 0.0, 0.0))
	c.append(cor)
	u.append(r_calota.get_center())
	for k in LADOS_PS1 + 1:
		var a := TAU * float(k) / float(LADOS_PS1)
		v.append(centro + Vector3(sx * x, sin(a) * 0.19, cos(a) * 0.19))
		n.append(Vector3(sx, 0.0, 0.0))
		c.append(cor)
		u.append(r_calota.get_center() + Vector2(cos(a), sin(a)) * r_calota.size * 0.5)
	for k in LADOS_PS1:
		if sx > 0.0:
			i.append_array([base, base + 1 + k, base + 2 + k])
		else:
			i.append_array([base, base + 2 + k, base + 1 + k])
	dados["v"] = v
	dados["n"] = n
	dados["uv"] = u
	dados["c"] = c
	dados["i"] = i


## Um triangulo com o giro do projeto: a face aparece do lado OPOSTO ao produto
## vetorial (ver `CarroceriaVarrida.quad`). A normal media dos tres vertices diz
## qual lado e fora.
static func _tri_fora(i: PackedInt32Array, v: PackedVector3Array,
		n: PackedVector3Array, a: int, b: int, c: int) -> void:
	var cruz := (v[b] - v[a]).cross(v[c] - v[a])
	var media := n[a] + n[b] + n[c]
	if cruz.dot(media) > 0.0:
		i.append_array([a, c, b])
	else:
		i.append_array([a, b, c])
