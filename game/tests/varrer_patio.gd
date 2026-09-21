## Por onde se ve o patio de um quarteirao.
##
##     godot --headless --path game --script res://tests/varrer_patio.gd -- \
##         --raio=12 [--detalhe]
##
## Por que existe
## -------------
## O predio da fileira e uma caixa de 8 m sem face de tras: da rua ninguem ve o
## avesso dela, desde que o anel de predios em volta da quadra feche. Onde o anel
## abre — uma sobra de fileira, o lote que o bar ou a casa da fumaca come, o fim
## de uma face curta — a rua da para o patio, e do patio se ve o lado de dentro
## de todas as casas da quadra: a fachada e um plano de uma face so, e a caixa
## nao tem fundo.
##
## Olhar isso de dentro do jogo nao da conta: a nevoa esconde, o pedestre empurra
## o jogador (`--ir-para` nao e regua) e a fresta so aparece num angulo. Aqui cada
## quarteirao EDIFICADO e montado inteiro, as caixas de colisao altas viram a
## planta dos predios, e o perimetro da quadra e percorrido a cada 25 cm um pouco
## para dentro da linha da fachada. Todo trecho sem predio em cima e uma boca
## aberta para o patio.
##
## Sai com codigo 1 se achar alguma boca maior que LIMITE.
extends SceneTree

const TAM := KitModular.CHUNK
## Altura minima de caixa de colisao para contar como parede de predio.
const ALTURA_PAREDE := 2.0
## Quanto para dentro da quadra a amostra anda. Menos que a profundidade de
## qualquer predio, mais que o avanco da fachada.
const PARA_DENTRO := 0.6
const PASSO := 0.25
## Boca tolerada, em metros. Uma porta de 1 m nao e buraco.
const LIMITE := 1.2

var _raio := 10
var _detalhe := false


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--raio="):
			_raio = int(a.trim_prefix("--raio="))
		elif a == "--detalhe":
			_detalhe = true
	_rodar.call_deferred()


func _rodar() -> void:
	var vistas := {}
	var quadras: Array[Dictionary] = []
	for cz in range(-_raio, _raio + 1):
		for cx in range(-_raio, _raio + 1):
			var q := MalhaUrbana.quadra_de(cx, cz)
			if vistas.has(q["id"]):
				continue
			vistas[q["id"]] = true
			if int(q["uso"]) != MalhaUrbana.Uso.EDIFICADO:
				continue
			quadras.append(q)

	# Controle positivo: a mesma regua, numa quadra de onde se tirou o maior
	# predio de proposito, TEM de achar a boca. Sem isto, "zero bocas" nao
	# distingue quadra fechada de regua cega.
	if not quadras.is_empty():
		var q0: Dictionary = quadras[0]
		var caixas0 := _caixas_da_quadra(q0)
		var maior := 0
		for k in caixas0.size():
			if caixas0[k].get_area() > caixas0[maior].get_area():
				maior = k
		caixas0.remove_at(maior)
		var achadas := _bocas(MalhaUrbana.retangulo_da_quadra(q0), caixas0)
		print("[patio] controle positivo: %d boca(s) com um predio a menos na quadra %s"
			% [achadas.size(), q0["id"]])
		if achadas.is_empty():
			push_error("varrer_patio: a regua nao viu o predio que foi tirado")
			quit(2)
			return

	var bocas_total := 0
	var metros_total := 0.0
	var perimetro_total := 0.0
	var quadras_abertas := 0
	for q: Dictionary in quadras:
		var caixas := _caixas_da_quadra(q)
		var r := MalhaUrbana.retangulo_da_quadra(q)
		var bocas := _bocas(r, caixas)
		perimetro_total += 2.0 * (r.size.x + r.size.y)
		if bocas.is_empty():
			continue
		quadras_abertas += 1
		for b: Dictionary in bocas:
			bocas_total += 1
			metros_total += float(b["largura"])
			if _detalhe:
				print("  quadra %s distrito %d  boca de %.1f m em %s (lado %s)"
					% [q["id"], int(q["distrito"]), float(b["largura"]),
					b["meio"], b["lado"]])

	print("[patio] %d quadras edificadas, %d abertas, %d bocas, %.0f m abertos de %.0f m de perimetro"
		% [quadras.size(), quadras_abertas, bocas_total, metros_total, perimetro_total])
	quit(1 if bocas_total > 0 else 0)


## As caixas altas de todos os chunks da quadra, em metros de mundo, como
## retangulos no chao.
func _caixas_da_quadra(q: Dictionary) -> Array[Rect2]:
	var saida: Array[Rect2] = []
	for cz in range(int(q["z0"]), int(q["z1"])):
		for cx in range(int(q["x0"]), int(q["x1"])):
			var dados := ChunkBuilder.construir(cx, cz)
			var origem := Vector3(cx * TAM, 0.0, cz * TAM)
			# O beco e boca DE PROPOSITO, com fundo: os muros de divisa e o de
			# fundo fecham o corredor (BecoBuilder). Conta como fechado.
			for b: Dictionary in BecoBuilder.becos(cx, cz):
				for face: Dictionary in ChunkBuilder.faces_de_rua(
						MalhaUrbana.bordas(cx, cz), ChunkBuilder.area_util(cx, cz)):
					if int(face["direcao"]) != int(b["direcao"]):
						continue
					var pa := FundosBuilder._ponto(face, float(b["de"]), 0.0) + origem
					var pb := FundosBuilder._ponto(face, float(b["ate"]),
						float(b["fundo"])) + origem
					saida.append(Rect2(minf(pa.x, pb.x), minf(pa.z, pb.z),
						absf(pb.x - pa.x), absf(pb.z - pa.z)))
			# A casa da fumaca monta a sala quando o jogador chega perto
			# (InteriorNoMundo): no chunk ela e so a casca, sem colisao no
			# terreo. O lote dela e fechado — fachada, laterais e fundo.
			for p: Dictionary in dados["props"]:
				if str(p.get("tipo", "")) != "interior_mundo":
					continue
				var planta: Transform3D = p["planta"]
				var a := planta * Vector3(0.0, 0.0, 0.0) + origem
				var b := planta * Vector3(KitFumaca.LOTE.x, 0.0, KitFumaca.LOTE.y) + origem
				saida.append(Rect2(minf(a.x, b.x), minf(a.z, b.z),
					absf(b.x - a.x), absf(b.z - a.z)).grow(0.3))
			for c: Dictionary in dados["colisao"]:
				if not c.has("tamanho"):
					continue
				var t: Vector3 = c["tamanho"]
				var p: Vector3 = Vector3(c["pos"]) + origem
				if t.y < ALTURA_PAREDE:
					continue
				# Caixa girada (muro de lote, casca da casa da fumaca): o
				# retangulo que a envolve basta, porque o que interessa e se
				# ha parede sobre a linha da fachada.
				var meia := Vector2(t.x, t.z) * 0.5
				if c.has("giro"):
					var g: Vector3 = c["giro"]
					var b := Basis.from_euler(g)
					var ex := (b.x * t.x * 0.5).abs() + (b.z * t.z * 0.5).abs()
					meia = Vector2(ex.x, ex.z)
				# So o que toca o chao: laje de bar suspensa nao fecha a rua.
				# Contra o chao DAQUI: com relevo, o predio da ladeira comeca
				# metros acima de zero e continua tocando o chao.
				if p.y - t.y * 0.5 - Relevo.altura(p.x, p.z) > 0.6:
					continue
				saida.append(Rect2(p.x - meia.x, p.z - meia.y, meia.x * 2.0, meia.y * 2.0))
	return saida


func _bocas(r: Rect2, caixas: Array[Rect2]) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var lados := {
		"x0": [Vector2(r.position.x + PARA_DENTRO, r.position.y), Vector2(0, 1), r.size.y],
		"x1": [Vector2(r.end.x - PARA_DENTRO, r.position.y), Vector2(0, 1), r.size.y],
		"z0": [Vector2(r.position.x, r.position.y + PARA_DENTRO), Vector2(1, 0), r.size.x],
		"z1": [Vector2(r.position.x, r.end.y - PARA_DENTRO), Vector2(1, 0), r.size.x],
	}
	for nome: String in lados:
		var inicio: Vector2 = lados[nome][0]
		var eixo: Vector2 = lados[nome][1]
		var comp: float = lados[nome][2]
		var aberta_desde := -1.0
		var t := PARA_DENTRO
		# Para dentro da quadra, a partir da linha de amostra.
		var centro := r.get_center()
		var dentro := (centro - inicio).project(Vector2(eixo.y, eixo.x)).normalized()
		while t <= comp - PARA_DENTRO:
			var p := inicio + eixo * t
			# Boca e passagem ate o patio: o ponto na linha da fachada E o ponto
			# atras da fileira tem de estar livres. O salao do bar e aberto na
			# frente por desenho, mas tem fundo — nao e boca.
			# Da linha da fachada ate alem do fundo do predio. Comecar na linha de
			# amostra deixava de fora a parede lateral do salao do bar, que fica
			# a 10 cm da fachada.
			var ini := p - dentro * (PARA_DENTRO - 0.05)
			var fim := p + dentro * (ChunkBuilder.PROF_PREDIO + 0.3 - PARA_DENTRO)
			var coberto := false
			for c: Rect2 in caixas:
				if _corta(c.grow(0.02), ini, fim):
					coberto = true
					break
			if not coberto and aberta_desde < 0.0:
				aberta_desde = t
			elif coberto and aberta_desde >= 0.0:
				_registrar(saida, nome, inicio, eixo, aberta_desde, t)
				aberta_desde = -1.0
			t += PASSO
		if aberta_desde >= 0.0:
			_registrar(saida, nome, inicio, eixo, aberta_desde, comp - PARA_DENTRO)
	return saida


## O segmento alinhado a um eixo (a -> b) encosta no retangulo?
func _corta(c: Rect2, a: Vector2, b: Vector2) -> bool:
	if is_equal_approx(a.x, b.x):
		return a.x >= c.position.x and a.x <= c.end.x \
			and maxf(a.y, b.y) >= c.position.y and minf(a.y, b.y) <= c.end.y
	return a.y >= c.position.y and a.y <= c.end.y \
		and maxf(a.x, b.x) >= c.position.x and minf(a.x, b.x) <= c.end.x


func _registrar(saida: Array[Dictionary], lado: String, inicio: Vector2,
		eixo: Vector2, de: float, ate: float) -> void:
	var largura := ate - de
	if largura <= LIMITE:
		return
	var meio := inicio + eixo * ((de + ate) * 0.5)
	saida.append({"lado": lado, "largura": largura, "meio": meio})
