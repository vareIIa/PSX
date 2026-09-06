## Gerador de parques. Preenche uma quadra inteira com um parque sorteado.
##
## Nao e um parque: e um gerador. A quadra escolhe um dos quatro tracos e a partir
## dai tudo — caminho, mobiliario, vegetacao, brinquedo — sai da semente da
## quadra. Dois parques do mesmo traco nao ficam iguais, e o mesmo parque fica
## igual em toda execucao.
##
## Como um parque de 160 m nasce de chunks montados em threads separadas
## -------------------------------------------------------------------
## Um parque ocupa a quadra toda, que pode ter 25 chunks. Os chunks sao montados
## em paralelo e nenhum sabe dos outros. A saida e cada chunk percorrer o parque
## INTEIRO, na mesma ordem, e desenhar so o que cai dentro dele. O custo e um laco
## de algumas centenas de iteracoes de aritmetica, que ao lado de gerar vertices
## nao aparece na conta.
##
## Isso impoe uma regra que e facil de quebrar sem perceber: NENHUM sorteio pode
## sair de um fluxo compartilhado. Se dois chunks vizinhos consomem quantidades
## diferentes do mesmo RandomNumberGenerator — e consomem, porque cada um pula as
## pecas que nao sao dele — as sequencias divergem e a mesma arvore nasce de dois
## tamanhos conforme quem a desenha. Por isso todo sorteio aqui e uma funcao pura
## do indice da peca: `_ale(semente, indice, canal)`. Peca que precisa de um fluxo
## proprio, como a arvore, ganha um gerador semeado pelo indice dela.
##
## Todas as coordenadas internas estao em metros da quadra, com origem no canto
## (x0, z0). `_mover` traduz para a coordenada local do chunk na hora de desenhar.
class_name ParqueBuilder
extends RefCounted

## Traco do parque. O que muda de verdade entre eles e o miolo e a densidade de
## arvore; o resto do vocabulario e o mesmo, que e o que faz os quatro lerem como
## parques da mesma cidade.
enum Traco { PRACA, PARQUINHO, BOSQUE, CAMPO }

const TAM := KitModular.CHUNK
const LARGURA_CAMINHO := 2.6
## Distancia entre arvores na grade de plantio, antes do sacolejo.
const CELULA := 5.5
const PASSO_BANCO := 9.0
const PASSO_POSTE := 14.0

## Densidade de arvore por traco. E o unico numero que separa um bosque de um
## campo de futebol, e ele sozinho ja muda a caminhada inteira.
const DENSIDADE := {
	Traco.PRACA: 0.30,
	Traco.PARQUINHO: 0.32,
	Traco.BOSQUE: 0.74,
	Traco.CAMPO: 0.17,
}

## Nome por traco, e nao um sorteio unico. "Praca Higashi" num campo de terra
## batida com duas traves de gol e um erro que o jogador percebe na hora — o nome
## e a primeira coisa que ele le na placa do portao, e ele espera que bata com o
## que esta atras dela.
const NOMES := {
	Traco.PRACA: ["PRACA HIGASHI", "PRACA DA ESTACAO", "PRACA DO CANAL"],
	Traco.PARQUINHO: ["PARQUE INFANTIL", "PARQUINHO SAKURA", "PARQUE DAS FLORES"],
	Traco.BOSQUE: ["BOSQUE NORTE", "BOSQUE DO MORRO", "MATA DA COLINA"],
	Traco.CAMPO: ["CAMPO MUNICIPAL", "CAMPO DO BAIRRO", "CAMPO DA VILA"],
}


## Monta o parque da quadra dentro do chunk (cx, cz).
##
## Escreve nos mesmos acumuladores do resto do chunk, entao a fusao por material
## e as caixas de colisao seguem valendo sem nenhum caso especial.
static func construir(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], quadra: Dictionary, cx: int, cz: int) -> void:
	var plano := planta(quadra)
	var desloc := Vector2(float(int(quadra["x0"]) - cx) * TAM,
		float(int(quadra["z0"]) - cz) * TAM)

	_chao(sup, plano, desloc)
	_caminhos(sup, plano, desloc)
	_perimetro(sup, colisao, plano, desloc)
	_miolo(sup, props, colisao, plano, desloc)
	_mobiliario(sup, props, colisao, plano, desloc)
	_vegetacao(sup, colisao, plano, desloc)

	# Um emissor de folhas por chunk de parque, no centro do pedaco que este
	# chunk desenha. Espalhar assim, em vez de um so no centro do parque, e o que
	# faz o som acompanhar a caminhada: num parque de 160 m uma fonte unica
	# sumiria antes de o jogador chegar na metade.
	props.append({
		"tipo": "folhagem",
		"pos": Vector3(TAM * 0.5, 2.6, TAM * 0.5),
		"semente": int(quadra["semente"]) + cx * 31 + cz * 17,
	})


## Descreve o parque da quadra, em metros com origem no canto da quadra.
##
## Publica porque o mapa tambem pergunta: e daqui que sai o nome que aparece no
## menu de pausa e o retangulo verde do minimapa.
static func planta(quadra: Dictionary) -> Dictionary:
	var x0 := int(quadra["x0"])
	var x1 := int(quadra["x1"])
	var z0 := int(quadra["z0"])
	var z1 := int(quadra["z1"])
	var h := int(quadra["semente"])

	# A area util comeca depois da calcada das ruas que cercam a quadra.
	var oeste := MalhaUrbana.recuo(MalhaUrbana.via_x(x0))
	var leste := float(x1 - x0) * TAM - MalhaUrbana.recuo(MalhaUrbana.via_x(x1))
	var norte := MalhaUrbana.recuo(MalhaUrbana.via_z(z0))
	var sul := float(z1 - z0) * TAM - MalhaUrbana.recuo(MalhaUrbana.via_z(z1))

	var area := Rect2(oeste, norte, leste - oeste, sul - norte)
	var tracos: Array[Traco] = [Traco.PRACA, Traco.PARQUINHO, Traco.BOSQUE, Traco.CAMPO]
	var traco: Traco = tracos[(h / 3) % tracos.size()]
	# Campo de bola precisa de campo. Numa quadra pequena vira quintal, entao a
	# quadra pequena cai para praca, que e o traco que funciona em qualquer area.
	if traco == Traco.CAMPO and minf(area.size.x, area.size.y) < 46.0:
		traco = Traco.PRACA

	return {
		"area": area,
		"traco": traco,
		"centro": area.get_center(),
		"nome": _nome_de(traco, h),
		"anel": minf(area.size.x, area.size.y) >= 62.0,
		"semente": h,
	}


# --- chao -------------------------------------------------------------------

static func _chao(sup: Dictionary, plano: Dictionary, desloc: Vector2) -> void:
	var area: Rect2 = plano["area"]
	var sem := int(plano["semente"])
	KitParque.piso(sup, &"grama", _mover(area, desloc), KitParque.Y_GRAMA)

	# Manchas de terra batida onde o capim morreu. Grama uniforme le como tapete
	# de feltro; e a irregularidade que faz o chao existir.
	var n := int(area.get_area() / 260.0)
	for i in n:
		var w := lerpf(2.5, 7.0, _ale(sem, i, 1))
		var d := lerpf(2.0, 5.5, _ale(sem, i, 2))
		var p := Vector2(
			lerpf(area.position.x, area.end.x - w, _ale(sem, i, 3)),
			lerpf(area.position.y, area.end.y - d, _ale(sem, i, 4)))
		KitParque.piso(sup, &"terra", _mover(Rect2(p, Vector2(w, d)), desloc),
			KitParque.Y_TERRA, Color(0.9, 0.86, 0.78))


## Calcamento em placas, uma por vez, com altura e tom proprios.
##
## O caminho era um retangulo unico e lia como adesivo colado na grama: superficie
## grande, perfeitamente plana e de tom unico nao existe em praca nenhuma. Placa a
## placa, com um centimetro de diferenca de nivel entre vizinhas, a luz do poste
## pega diferente em cada uma e o piso ganha assentamento.
##
## As placas se sobrepoem alguns centimetros de proposito: sem isso o degrau entre
## duas vizinhas abriria uma fresta e apareceria a grama por baixo.
const PLACA := 2.6
const SOBREPOSICAO := 0.07
const DESNIVEL := 0.014


static func _caminhos(sup: Dictionary, plano: Dictionary, desloc: Vector2) -> void:
	var sem := int(plano["semente"])
	var faixas := faixas_de_caminho(plano)
	for f in faixas.size():
		var faixa: Rect2 = faixas[f]
		var ao_longo_de_x := faixa.size.x >= faixa.size.y
		var comprimento: float = faixa.size.x if ao_longo_de_x else faixa.size.y
		var n := maxi(1, int(round(comprimento / PLACA)))
		var passo := comprimento / float(n)
		for i in n:
			var chave := f * 512 + i
			var t0 := float(i) * passo - SOBREPOSICAO
			var t1 := float(i + 1) * passo + SOBREPOSICAO
			var placa := Rect2(faixa.position.x + t0, faixa.position.y,
				t1 - t0, faixa.size.y)
			if not ao_longo_de_x:
				placa = Rect2(faixa.position.x, faixa.position.y + t0,
					faixa.size.x, t1 - t0)
			var alto := KitParque.Y_CALCAMENTO 				+ lerpf(-DESNIVEL, DESNIVEL, _ale(sem, chave, 51))
			var tom := lerpf(0.82, 1.06, _ale(sem, chave, 52))
			KitParque.piso(sup, &"pedra_parque", _mover(placa, desloc), alto,
				Color(tom, tom * 0.99, tom * 0.96))


## Os caminhos do parque, em retangulos. O minimapa desenha os mesmos, e e por
## isso que o mapa bate com o chao.
static func faixas_de_caminho(plano: Dictionary) -> Array[Rect2]:
	var area: Rect2 = plano["area"]
	var centro: Vector2 = plano["centro"]
	var meia := LARGURA_CAMINHO * 0.5
	var saida: Array[Rect2] = [
		Rect2(area.position.x, centro.y - meia, area.size.x, LARGURA_CAMINHO),
		Rect2(centro.x - meia, area.position.y, LARGURA_CAMINHO, area.size.y),
	]
	# Parque grande ganha o anel de caminhada por dentro do gradil. E o que
	# transforma um gramado com uma cruz em cima num parque que se percorre.
	if bool(plano["anel"]):
		var r := area.grow(-5.0)
		saida.append(Rect2(r.position.x, r.position.y, r.size.x, LARGURA_CAMINHO))
		saida.append(Rect2(r.position.x, r.end.y - LARGURA_CAMINHO, r.size.x, LARGURA_CAMINHO))
		saida.append(Rect2(r.position.x, r.position.y, LARGURA_CAMINHO, r.size.y))
		saida.append(Rect2(r.end.x - LARGURA_CAMINHO, r.position.y, LARGURA_CAMINHO, r.size.y))
	return saida


# --- bordas -----------------------------------------------------------------

## Gradil em volta do parque, com vao onde os caminhos saem para a rua.
##
## Os vaos importam mais que o gradil: sem eles o parque e um cercado que o
## jogador ve e nao entra, o que e pior do que nao ter parque.
static func _perimetro(sup: Dictionary, colisao: Array[Dictionary],
		plano: Dictionary, desloc: Vector2) -> void:
	var area: Rect2 = plano["area"]
	var centro: Vector2 = plano["centro"]
	var vao := LARGURA_CAMINHO * 1.6

	# Cada lado vira dois trechos, um de cada lado do portao.
	var lados: Array = [
		[Vector2(area.position.x, area.position.y), Vector2(area.end.x, area.position.y), centro.x, true],
		[Vector2(area.position.x, area.end.y), Vector2(area.end.x, area.end.y), centro.x, true],
		[Vector2(area.position.x, area.position.y), Vector2(area.position.x, area.end.y), centro.y, false],
		[Vector2(area.end.x, area.position.y), Vector2(area.end.x, area.end.y), centro.y, false],
	]
	for i in lados.size():
		var lado: Array = lados[i]
		var a: Vector2 = lado[0]
		var b: Vector2 = lado[1]
		var corte: float = lado[2]
		var horizontal: bool = lado[3]
		var p1 := Vector2(corte - vao * 0.5, a.y) if horizontal else Vector2(a.x, corte - vao * 0.5)
		var p2 := Vector2(corte + vao * 0.5, b.y) if horizontal else Vector2(b.x, corte + vao * 0.5)
		_cerca(sup, colisao, a, p1, desloc, int(plano["semente"]), i * 2)
		_cerca(sup, colisao, p2, b, desloc, int(plano["semente"]), i * 2 + 1)

	# Placa com o nome, num dos portoes.
	var portao := Vector2(centro.x, area.position.y - 0.8) + desloc
	if _neste_chunk(portao):
		KitParque.placa(sup, colisao,
			Vector3(portao.x, KitModular.ALTURA_MEIO_FIO, portao.y), 0.0)


## Um trecho de cerca, quebrado em pedacos de 6 m para o corte por chunk poder
## ser feito peca a peca. Uma cerca de 140 m inteira sairia toda no chunk que
## contem o meio dela.
static func _cerca(sup: Dictionary, colisao: Array[Dictionary],
		a: Vector2, b: Vector2, desloc: Vector2, semente: int, lado: int) -> void:
	var comp := (b - a).length()
	if comp < 0.5:
		return
	var n := maxi(1, ceili(comp / 6.0))
	for i in n:
		var p0 := a.lerp(b, float(i) / float(n)) + desloc
		var p1 := a.lerp(b, float(i + 1) / float(n)) + desloc
		if not _neste_chunk((p0 + p1) * 0.5):
			continue
		var y := KitModular.ALTURA_MEIO_FIO
		# Um pedaco em cinco vira sebe em vez de gradil. Alternar sozinho ja
		# muda a leitura da borda inteira, e a sebe ainda balanca com o vento.
		if _ale(semente, lado * 64 + i, 21) < 0.2:
			KitParque.sebe(sup, colisao, Vector3(p0.x, y, p0.y), Vector3(p1.x, y, p1.y),
				_gerador(semente, lado * 64 + i, 22))
		else:
			KitParque.gradil(sup, colisao, Vector3(p0.x, y, p0.y), Vector3(p1.x, y, p1.y))


# --- miolo ------------------------------------------------------------------

static func _miolo(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], plano: Dictionary, desloc: Vector2) -> void:
	var centro: Vector2 = Vector2(plano["centro"]) + desloc
	var area: Rect2 = plano["area"]

	match int(plano["traco"]):
		Traco.PRACA:
			if _neste_chunk(centro):
				KitParque.chafariz(sup, colisao, Vector3(centro.x, KitParque.Y_GRAMA, centro.y), 3.2)
				props.append({
					"tipo": "lampada",
					"pos": Vector3(centro.x, 3.2, centro.y),
					"padrao": Lampada.Padrao.ESTAVEL,
					"semente": int(plano["semente"]) + 11,
					"cor": Color("9fb6c4"), "energia": 2.1, "alcance": 9.0,
					"facho": false,
				})
		Traco.PARQUINHO:
			var caixa := _retangulo_central(plano, 13.0, 10.0)
			KitParque.quadra_areia(sup, colisao, _mover(caixa, desloc), false)
			var b := Vector2(caixa.position.x + 3.4, caixa.get_center().y) + desloc
			if _neste_chunk(b):
				KitParque.balanco(sup, colisao, Vector3(b.x, KitParque.Y_AREIA, b.y), PI * 0.5)
			var e := Vector2(caixa.end.x - 3.0, caixa.get_center().y) + desloc
			if _neste_chunk(e):
				KitParque.escorregador(sup, colisao, Vector3(e.x, KitParque.Y_AREIA, e.y), 0.0)
		Traco.BOSQUE:
			if _neste_chunk(centro):
				KitParque.coreto(sup, colisao, Vector3(centro.x, KitParque.Y_GRAMA, centro.y), 3.6)
		_:
			var campo := _retangulo_central(plano, minf(area.size.x - 8.0, 30.0),
				minf(area.size.y - 8.0, 20.0))
			KitParque.quadra_areia(sup, colisao, _mover(campo, desloc),
				campo.size.y > campo.size.x)


## Retangulo centrado na area do parque, limitado por ela.
static func _retangulo_central(plano: Dictionary, largura: float,
		fundura: float) -> Rect2:
	var area: Rect2 = plano["area"]
	var centro: Vector2 = plano["centro"]
	var w := minf(largura, area.size.x - 6.0)
	var d := minf(fundura, area.size.y - 6.0)
	return Rect2(centro.x - w * 0.5, centro.y - d * 0.5, w, d)


# --- mobiliario -------------------------------------------------------------

static func _mobiliario(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], plano: Dictionary, desloc: Vector2) -> void:
	var area: Rect2 = plano["area"]
	var centro: Vector2 = plano["centro"]
	var sem := int(plano["semente"])
	var proibido := _zonas_proibidas(plano, 0.0)

	# Bancos ao longo dos dois eixos do caminho em cruz, virados para ele. Banco
	# de costas para o caminho e o erro classico deste movel.
	var indice := 0
	for eixo in 2:
		var comprimento: float = area.size.x if eixo == 0 else area.size.y
		# maxi(1, ...) e defesa contra divisao por zero: o menor parque possivel
		# hoje da cinco bancos por eixo, mas uma mudanca no periodo da malha pode
		# encolher isso, e a divisao por zero aqui sairia como NaN na malha e
		# apareceria em outro arquivo qualquer.
		var n := maxi(1, int(comprimento / PASSO_BANCO))
		for i in n:
			indice += 1
			var t := (float(i) + 0.5) / float(n)
			var lado := 1.0 if i % 2 == 0 else -1.0
			var afast := LARGURA_CAMINHO * 0.5 + 0.95
			var p := Vector2.ZERO
			var giro := 0.0
			if eixo == 0:
				p = Vector2(lerpf(area.position.x, area.end.x, t), centro.y + afast * lado)
				giro = 0.0 if lado > 0.0 else PI
			else:
				p = Vector2(centro.x + afast * lado, lerpf(area.position.y, area.end.y, t))
				giro = PI * 0.5 if lado > 0.0 else -PI * 0.5
			if _dentro_de(proibido, p):
				continue
			var local := p + desloc
			if not _neste_chunk(local):
				continue
			KitParque.banco(sup, colisao,
				Vector3(local.x, KitModular.ALTURA_MEIO_FIO, local.y), giro,
				_ale(sem, indice, 31))
			# Uma lixeira a cada tres bancos. Mais que isso vira ferro-velho.
			if indice % 3 == 0:
				var lx := local + Vector2(cos(giro), -sin(giro)) * 1.5
				KitParque.lixeira(sup, colisao,
					Vector3(lx.x, KitModular.ALTURA_MEIO_FIO, lx.y), giro)

	# Postes ao longo dos caminhos. Sao a unica luz do parque, e e por isso que o
	# miolo escuro entre eles funciona: o jogador ve para onde o caminho vai e
	# nao ve o que tem ao lado dele.
	for eixo in 2:
		var comprimento: float = area.size.x if eixo == 0 else area.size.y
		var n := maxi(1, int(comprimento / PASSO_POSTE))
		for i in n:
			var t := (float(i) + 0.5) / float(n)
			var afast := LARGURA_CAMINHO * 0.5 + 0.5
			var p := Vector2(lerpf(area.position.x, area.end.x, t), centro.y + afast)
			if eixo == 1:
				p = Vector2(centro.x + afast, lerpf(area.position.y, area.end.y, t))
			var local := p + desloc
			if not _neste_chunk(local):
				continue
			var globo := KitParque.poste_globo(sup, colisao,
				Vector3(local.x, KitModular.ALTURA_MEIO_FIO, local.y))
			props.append({
				"tipo": "lampada",
				"pos": globo,
				"padrao": Lampada.Padrao.ESTAVEL,
				"semente": sem + i * 97 + eixo * 13,
				"cor": Color("ffd9a0"), "energia": 2.6, "alcance": 9.5,
				"facho": true,
			})


# --- vegetacao --------------------------------------------------------------

static func _vegetacao(sup: Dictionary, colisao: Array[Dictionary],
		plano: Dictionary, desloc: Vector2) -> void:
	var area: Rect2 = plano["area"]
	var sem := int(plano["semente"])
	var proibido := _zonas_proibidas(plano, 2.8)
	var densidade: float = DENSIDADE[int(plano["traco"])]
	var cols := maxi(1, int(area.size.x / CELULA))
	var linhas := maxi(1, int(area.size.y / CELULA))

	for lz in linhas:
		for lx in cols:
			var celula := lz * 512 + lx
			if _ale(sem, celula, 41) > densidade:
				continue
			var p := Vector2(
				area.position.x + (float(lx) + 0.5) * area.size.x / float(cols)
					+ lerpf(-1.7, 1.7, _ale(sem, celula, 42)),
				area.position.y + (float(lz) + 0.5) * area.size.y / float(linhas)
					+ lerpf(-1.7, 1.7, _ale(sem, celula, 43)))
			if _dentro_de(proibido, p):
				continue
			var local := p + desloc
			if not _neste_chunk(local):
				continue

			# So aqui nasce um gerador de fluxo, e ele e da celula: a arvore
			# consome uma quantidade de sorteios que depende do proprio porte, e
			# isso nao pode contaminar a peca seguinte.
			var rng := _gerador(sem, celula, 44)
			var base := Vector3(local.x, KitModular.ALTURA_MEIO_FIO, local.y)
			var tipo := _ale(sem, celula, 45)
			var porte := _ale(sem, celula, 46)
			if tipo < 0.16:
				KitParque.arbusto(sup, base, lerpf(0.9, 1.6, porte), rng)
			elif tipo < 0.34:
				KitParque.pinheiro(sup, colisao, base, porte, rng)
			else:
				KitParque.arvore(sup, colisao, base, porte, rng,
					_ale(sem, celula, 47) < 0.16)


# --- geometria de apoio -----------------------------------------------------

## Onde nao se constroi. `folga` e quanto o caminho empurra alem da propria
## largura, e ela muda com quem pergunta.
##
## Arvore precisa de folga grande: 2,8 m tira a copa de cima do caminho, de cima
## do banco e de cima do poste de uma vez. Mobiliario precisa de folga NENHUMA —
## o banco fica a 2,25 m do eixo do caminho, e com a folga da arvore ele caia
## dentro da propria zona proibida e nao era colocado nunca. O parque ficou tres
## capturas sem um banco por causa disso.
static func _zonas_proibidas(plano: Dictionary, folga: float) -> Array[Rect2]:
	var saida: Array[Rect2] = []
	if folga > 0.0:
		for faixa: Rect2 in faixas_de_caminho(plano):
			saida.append(faixa.grow(folga))
	saida.append(_retangulo_central(plano, 15.0, 13.0))
	if int(plano["traco"]) == Traco.CAMPO:
		var area: Rect2 = plano["area"]
		saida.append(_retangulo_central(plano, minf(area.size.x - 8.0, 30.0) + 3.0,
			minf(area.size.y - 8.0, 20.0) + 3.0))
	return saida


static func _dentro_de(zonas: Array[Rect2], p: Vector2) -> bool:
	for z: Rect2 in zonas:
		if z.has_point(p):
			return true
	return false


## O ponto, ja em coordenada local do chunk, cai dentro dele?
static func _neste_chunk(p: Vector2) -> bool:
	return p.x >= 0.0 and p.x < TAM and p.y >= 0.0 and p.y < TAM


static func _nome_de(traco: Traco, h: int) -> String:
	var lista: Array = NOMES[traco]
	return lista[(h / 7) % lista.size()]


static func _mover(r: Rect2, desloc: Vector2) -> Rect2:
	return Rect2(r.position + desloc, r.size)


## Sorteio puro: mesma entrada, mesmo numero, sem estado nenhum entre chamadas.
## E o que permite dois chunks concordarem sobre uma arvore que so um deles
## desenha. Ver a nota de determinismo no topo do arquivo.
static func _ale(semente: int, indice: int, canal: int) -> float:
	var h := (semente * 2654435761) ^ (indice * 40503) ^ (canal * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(absi(h) % 1000003) / 1000003.0


## Gerador de fluxo semeado por peca, para quem precisa de muitos sorteios.
static func _gerador(semente: int, indice: int, canal: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = (semente * 2654435761) ^ (indice * 40503) ^ (canal * 83492791)
	return r
