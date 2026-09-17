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
enum Traco { PRACA, PARQUINHO, BOSQUE, CAMPO, LAGO }

const TAM := KitModular.CHUNK
const LARGURA_CAMINHO := 2.6
## Distancia entre arvores na grade de plantio, antes do sacolejo.
const CELULA := 5.5
const PASSO_BANCO := 9.0
const PASSO_POSTE := 14.0

## Densidade de arvore por traco. E o unico numero que separa um bosque de um
## campo de futebol, e ele sozinho ja muda a caminhada inteira.
const DENSIDADE := {
	Traco.PRACA: 0.08,
	Traco.PARQUINHO: 0.32,
	Traco.BOSQUE: 0.74,
	Traco.CAMPO: 0.17,
	Traco.LAGO: 0.46,
}

## Nome por traco, e nao um sorteio unico. "Praca Higashi" num campo de terra
## batida com duas traves de gol e um erro que o jogador percebe na hora — o nome
## e a primeira coisa que ele le na placa do portao, e ele espera que bata com o
## que esta atras dela.
const NOMES := {
	Traco.PRACA: ["PRACA DA MATRIZ", "PRACA DA MATRIZ", "PRACA DA MATRIZ"],
	Traco.PARQUINHO: ["PARQUE INFANTIL", "PARQUINHO SAKURA", "PARQUE DAS FLORES"],
	Traco.BOSQUE: ["BOSQUE NORTE", "BOSQUE DO MORRO", "MATA DA COLINA"],
	Traco.CAMPO: ["CAMPO MUNICIPAL", "CAMPO DO BAIRRO", "CAMPO DA VILA"],
	Traco.LAGO: ["PARQUE DO LAGO", "LAGOA HIGASHI", "PARQUE DAS AGUAS"],
}

## O parquinho, em metros. A caixa de areia com os brinquedos dentro.
##
## `RECUO_MIOLO` e a faixa de grama entre o meio-fio da areia e o caminho que
## passa em volta — vale tanto para o parquinho quanto para o campo de bola. Ela
## existe por dois motivos: o banco de 1,9 m so cabe ali, e sem ela a pedra
## encosta no meio-fio e os dois pisos disputam o mesmo pixel.
const LARGURA_PARQUINHO := 20.0
const FUNDURA_PARQUINHO := 15.0
const RECUO_MIOLO := 2.4

## Area minima, em metros de lado, para caber um lago. Abaixo disso o espelho
## d'agua fica menor que os barrancos que o cercam e o que se ve e uma poca com
## moldura de areia.
const LADO_MINIMO_LAGO := 50.0


## Monta o parque da quadra dentro do chunk (cx, cz).
##
## Escreve nos mesmos acumuladores do resto do chunk, entao a fusao por material
## e as caixas de colisao seguem valendo sem nenhum caso especial.
static func construir(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], quadra: Dictionary, cx: int, cz: int) -> void:
	var plano := planta(quadra)
	var desloc := Vector2(float(int(quadra["x0"]) - cx) * TAM,
		float(int(quadra["z0"]) - cz) * TAM)

	_chao(sup, colisao, plano, desloc)
	_caminhos(sup, plano, desloc)
	_perimetro(sup, colisao, plano, desloc)
	_miolo(sup, props, colisao, plano, desloc)
	_mobiliario(sup, props, colisao, plano, desloc)
	_vegetacao(sup, colisao, plano, desloc)
	_canteiros(sup, plano, desloc)

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
	var tracos: Array[Traco] = [Traco.PRACA, Traco.PARQUINHO, Traco.BOSQUE,
		Traco.CAMPO, Traco.LAGO]
	var traco: Traco = tracos[(h / 3) % tracos.size()]
	# Quadra pequena nao comporta lago. Ver LADO_MINIMO_LAGO.
	if traco == Traco.LAGO and minf(area.size.x, area.size.y) < LADO_MINIMO_LAGO:
		traco = Traco.BOSQUE
	# Campo de bola precisa de campo. Numa quadra pequena vira quintal, entao a
	# quadra pequena cai para praca, que e o traco que funciona em qualquer area.
	if traco == Traco.CAMPO and minf(area.size.x, area.size.y) < 46.0:
		traco = Traco.PRACA

	return {
		"area": area,
		"traco": traco,
		"centro": area.get_center(),
		"nome": _nome_de(traco, h),
		# O parque do lago SEMPRE tem anel: e o caminho que contorna a agua, e sem
		# ele o jogador atravessa a grama porque nao ha por onde andar.
		"anel": minf(area.size.x, area.size.y) >= 62.0 or traco == Traco.LAGO,
		"semente": h,
	}


# --- chao -------------------------------------------------------------------

static func _chao(sup: Dictionary, colisao: Array[Dictionary],
		plano: Dictionary, desloc: Vector2) -> void:
	var area: Rect2 = plano["area"]
	var sem := int(plano["semente"])
	# A altura da colisao e a da calcada, nao a do visual. Visual pode ser
	# pedra a 22 cm; os pes ficam a 16, iguais ao meio-fio, e a saida e plana.
	var y_chao := KitModular.ALTURA_MEIO_FIO
	# Praca da Matriz: pedra irregular no miolo inteiro. Grama so na faixa
	# estreita atras das casas, senao a referencia vira parque com cruz de
	# caminho em vez da praca colonial.
	if int(plano["traco"]) == Traco.PRACA:
		_chao_praca_matriz(sup, plano, desloc)
		KitParque.piso_solido(colisao, _mover(area, desloc), y_chao)
		return
	# A grama sai em retalhos em volta do lago, e nao num plano so: o plano
	# inteiro passaria por baixo da agua e apareceria como um tapete verde no
	# fundo do lago, dois centimetros acima do barranco.
	for pedaco: Rect2 in _grama_de(plano):
		KitParque.piso(sup, &"grama", _mover(pedaco, desloc), KitParque.Y_GRAMA)
		KitParque.piso_solido(colisao, _mover(pedaco, desloc), y_chao)

	# Canteiros no lugar das manchas amarelas de terra. A terra clara lia como
	# areia de obra; o que o gramado pede e flor, nao um retangulo ocre.
	var n := int(area.get_area() / 280.0)
	var faixas := faixas_de_caminho(plano)
	var lago_r := lago_de(plano) if int(plano["traco"]) == Traco.LAGO else Rect2()
	for i in n:
		var w := lerpf(1.6, 2.8, _ale(sem, i, 1))
		var d := lerpf(1.4, 2.4, _ale(sem, i, 2))
		var p := Vector2(
			lerpf(area.position.x + 2.0, area.end.x - w - 2.0, _ale(sem, i, 3)),
			lerpf(area.position.y + 2.0, area.end.y - d - 2.0, _ale(sem, i, 4)))
		var cama := Rect2(p, Vector2(w, d))
		if lago_r.size.x > 0.0 and lago_r.grow(2.0).intersects(cama):
			continue
		if _sobre_calcamento(faixas, cama.get_center()):
			continue
		KitParque.piso(sup, &"terra", _mover(cama, desloc), KitParque.Y_TERRA,
			Color(0.42, 0.36, 0.28))
		_flores_no_canteiro(sup, cama, desloc, sem, i)


## A grama, ja descontado o buraco do lago. Quatro faixas em volta dele.
static func _grama_de(plano: Dictionary) -> Array[Rect2]:
	var area: Rect2 = plano["area"]
	if int(plano["traco"]) != Traco.LAGO:
		return [area]
	var l := lago_de(plano)
	return [
		Rect2(area.position.x, area.position.y, area.size.x, l.position.y - area.position.y),
		Rect2(area.position.x, l.end.y, area.size.x, area.end.y - l.end.y),
		Rect2(area.position.x, l.position.y, l.position.x - area.position.x, l.size.y),
		Rect2(l.end.x, l.position.y, area.end.x - l.end.x, l.size.y),
	]


## O retangulo do lago, em metros da quadra. Publico porque o mapa tambem
## pergunta: e daqui que sai a mancha azul do minimapa.
static func lago_de(plano: Dictionary) -> Rect2:
	var area: Rect2 = plano["area"]
	var sem := int(plano["semente"])
	# O lago nao e centrado. Centrado ele vira uma piscina olimpica no meio de
	# um jardim simetrico; deslocado, uma das margens fica larga e e la que cabem
	# o deque, os bancos e o canteiro.
	var w := area.size.x * lerpf(0.44, 0.56, _ale(sem, 0, 61))
	var d := area.size.y * lerpf(0.42, 0.54, _ale(sem, 0, 62))
	var cx := area.get_center().x + area.size.x * lerpf(-0.08, 0.08, _ale(sem, 0, 63))
	var cz := area.get_center().y + area.size.y * lerpf(-0.08, 0.08, _ale(sem, 0, 64))
	return Rect2(cx - w * 0.5, cz - d * 0.5, w, d)


## O retangulo da caixa de areia, em metros da quadra.
##
## Publico e unico porque TRES lugares precisam do mesmo retangulo e nao podem
## discordar: quem desenha a areia, quem desvia o caminho em volta dela e quem
## decide onde nao plantar. Com o retangulo reescrito em cada um, o caminho em
## cruz nascia por cima dos brinquedos — uma faixa de pedra de 2,6 m atravessando
## a areia de ponta a ponta, com o balanco montado em cima.
static func parquinho_de(plano: Dictionary) -> Rect2:
	return _retangulo_central(plano, LARGURA_PARQUINHO, FUNDURA_PARQUINHO)


## O campo de bola, em metros da quadra. Mesmo motivo de `parquinho_de`: o
## retangulo estava escrito em dois lugares — quem desenhava a areia e quem
## proibia plantar — e o caminho em cruz, que nao consultava nenhum dos dois,
## atravessava a quadra de ponta a ponta por cima da linha do meio.
static func campo_de(plano: Dictionary) -> Rect2:
	var area: Rect2 = plano["area"]
	return _retangulo_central(plano, minf(area.size.x - 8.0, 30.0),
		minf(area.size.y - 8.0, 20.0))


## O miolo que o caminho contorna em vez de atravessar, ja com a faixa de grama.
## Retangulo vazio quando o traco nao tem miolo intocavel — na praca o chafariz
## fica no cruzamento de proposito, que e o que faz a cruz ter um centro.
static func _miolo_cercado(plano: Dictionary) -> Rect2:
	match int(plano["traco"]):
		Traco.PARQUINHO:
			return parquinho_de(plano).grow(RECUO_MIOLO)
		Traco.CAMPO:
			return campo_de(plano).grow(RECUO_MIOLO)
	return Rect2()


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

## Tom da pedra do calcamento, multiplicado sobre a textura por cor de vertice.
##
## Era 0,78 a 1,06 — quase branco — e os dois chamadores usavam faixas
## diferentes para a MESMA pedra. Medido contra
## `PRINTS/ref_praca_matriz/01_acordar.png`: a razao fachada/chao da referencia
## e 5,6 e a nossa era 1,38, ou seja o chao chegava quase tao claro quanto a
## parede caiada e a praca noturna lia como dia.
##
## A conta que fixa o valor: `pedra_parque.png` tem luma media 105 e
## `reboco.png` tem 210. Com tom ~0,92 o albedo do chao ficava em 96 contra 204
## da parede — razao 2,1, quando cal sobre pedra molhada e mais perto de 5. O
## resto da diferenca vinha da luz, nao do albedo: omni a 4,5 m bate na
## horizontal com N.L ~1 e na parede de raspao.
const TOM_PEDRA_MIN := 0.30
const TOM_PEDRA_MAX := 0.46


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
			var tom := lerpf(TOM_PEDRA_MIN, TOM_PEDRA_MAX, _ale(sem, chave, 52))
			KitParque.piso(sup, &"pedra_parque", _mover(placa, desloc), alto,
				Color(tom, tom * 0.99, tom * 0.96))


## Os caminhos do parque, em retangulos. O minimapa desenha os mesmos, e e por
## isso que o mapa bate com o chao.
static func faixas_de_caminho(plano: Dictionary) -> Array[Rect2]:
	var area: Rect2 = plano["area"]
	var centro: Vector2 = plano["centro"]
	var meia := LARGURA_CAMINHO * 0.5
	var saida: Array[Rect2] = []
	var traco := int(plano["traco"])
	# Na Matriz o piso ja e pedra; as "faixas" existem so para bancos/postes
	# saberem o eixo e o anel — nao desenham segundo calcamento.
	if traco == Traco.PRACA:
		return _faixas_praca_matriz(plano)
	# A cruz atravessa o parque de ponta a ponta — e no parque do lago ela
	# atravessaria a agua, no parquinho a caixa de areia e no campo a quadra.
	# Nesses casos ela para antes e contorna: no lago pelo anel, nos outros por
	# um cerco em volta do miolo.
	var cercado := _miolo_cercado(plano)
	if cercado.size.x > 0.0:
		var fora := cercado.grow(LARGURA_CAMINHO)
		saida.append(Rect2(fora.position.x, fora.position.y,
			fora.size.x, LARGURA_CAMINHO))
		saida.append(Rect2(fora.position.x, fora.end.y - LARGURA_CAMINHO,
			fora.size.x, LARGURA_CAMINHO))
		saida.append(Rect2(fora.position.x, fora.position.y,
			LARGURA_CAMINHO, fora.size.y))
		saida.append(Rect2(fora.end.x - LARGURA_CAMINHO, fora.position.y,
			LARGURA_CAMINHO, fora.size.y))
		# Os quatro tocos, da borda do parque ate o cerco. Sao eles que fazem o
		# portao continuar levando a algum lugar.
		saida.append(Rect2(area.position.x, centro.y - meia,
			maxf(0.0, fora.position.x - area.position.x), LARGURA_CAMINHO))
		saida.append(Rect2(fora.end.x, centro.y - meia,
			maxf(0.0, area.end.x - fora.end.x), LARGURA_CAMINHO))
		saida.append(Rect2(centro.x - meia, area.position.y,
			LARGURA_CAMINHO, maxf(0.0, fora.position.y - area.position.y)))
		saida.append(Rect2(centro.x - meia, fora.end.y,
			LARGURA_CAMINHO, maxf(0.0, area.end.y - fora.end.y)))
	elif traco != Traco.LAGO:
		saida.append(Rect2(area.position.x, centro.y - meia, area.size.x, LARGURA_CAMINHO))
		saida.append(Rect2(centro.x - meia, area.position.y, LARGURA_CAMINHO, area.size.y))
	# Parque grande ganha o anel de caminhada por dentro do gradil. E o que
	# transforma um gramado com uma cruz em cima num parque que se percorre.
	if bool(plano["anel"]):
		var r := area.grow(-5.0)
		saida.append(Rect2(r.position.x, r.position.y, r.size.x, LARGURA_CAMINHO))
		saida.append(Rect2(r.position.x, r.end.y - LARGURA_CAMINHO, r.size.x, LARGURA_CAMINHO))
		saida.append(Rect2(r.position.x, r.position.y, LARGURA_CAMINHO, r.size.y))
		saida.append(Rect2(r.end.x - LARGURA_CAMINHO, r.position.y, LARGURA_CAMINHO, r.size.y))
	if traco == Traco.LAGO:
		# Toco de cada portao ate o anel. Sem ele o portao abre para grama e a
		# entrada do parque some.
		saida.append(Rect2(centro.x - meia, area.position.y, LARGURA_CAMINHO, 6.0))
		saida.append(Rect2(centro.x - meia, area.end.y - 6.0, LARGURA_CAMINHO, 6.0))
		saida.append(Rect2(area.position.x, centro.y - meia, 6.0, LARGURA_CAMINHO))
		saida.append(Rect2(area.end.x - 6.0, centro.y - meia, 6.0, LARGURA_CAMINHO))
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
		[Vector2(area.position.x, area.position.y), Vector2(area.end.x, area.position.y), centro.x, true, 0.0],
		[Vector2(area.position.x, area.end.y), Vector2(area.end.x, area.end.y), centro.x, true, PI],
		[Vector2(area.position.x, area.position.y), Vector2(area.position.x, area.end.y), centro.y, false, -PI * 0.5],
		[Vector2(area.end.x, area.position.y), Vector2(area.end.x, area.end.y), centro.y, false, PI * 0.5],
	]
	for i in lados.size():
		var lado: Array = lados[i]
		var a: Vector2 = lado[0]
		var b: Vector2 = lado[1]
		var corte: float = lado[2]
		var horizontal: bool = lado[3]
		var giro: float = lado[4]
		var p1 := Vector2(corte - vao * 0.5, a.y) if horizontal else Vector2(a.x, corte - vao * 0.5)
		var p2 := Vector2(corte + vao * 0.5, b.y) if horizontal else Vector2(b.x, corte + vao * 0.5)
		_cerca(sup, colisao, a, p1, desloc, int(plano["semente"]), i * 2)
		_cerca(sup, colisao, p2, b, desloc, int(plano["semente"]), i * 2 + 1)
		var meio := Vector2(corte, a.y) if horizontal else Vector2(a.x, corte)
		var local := meio + desloc
		if _neste_chunk(local):
			KitParque.pilares_portao(sup, colisao,
				Vector3(local.x, KitModular.ALTURA_MEIO_FIO, local.y),
				giro, vao * 0.5)

	# Placa ao LADO do portao sul, no pilar leste. No meio do vao ela era a
	# parede que prendia o jogador na hora de sair.
	var placa := Vector2(centro.x + vao * 0.5 + 0.9, area.position.y) + desloc
	if _neste_chunk(placa):
		KitParque.placa(sup, colisao,
			Vector3(placa.x, KitModular.ALTURA_MEIO_FIO, placa.y), 0.0)


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

	match int(plano["traco"]):
		Traco.PRACA:
			_praca_matriz(sup, props, colisao, plano, desloc)
		Traco.PARQUINHO:
			_parquinho(sup, colisao, plano, desloc)
		Traco.BOSQUE:
			if _neste_chunk(centro):
				KitParque.coreto(sup, colisao, Vector3(centro.x, KitParque.Y_GRAMA, centro.y), 3.6)
		Traco.LAGO:
			_lago(sup, props, colisao, plano, desloc)
		_:
			var campo := campo_de(plano)
			KitParque.quadra_areia(sup, colisao, _mover(campo, desloc),
				campo.size.y > campo.size.x)
			_bancos_em_volta(sup, colisao, plano, campo, desloc)


## Retangulo centrado na area do parque, limitado por ela.
static func _retangulo_central(plano: Dictionary, largura: float,
		fundura: float) -> Rect2:
	var area: Rect2 = plano["area"]
	var centro: Vector2 = plano["centro"]
	var w := minf(largura, area.size.x - 6.0)
	var d := minf(fundura, area.size.y - 6.0)
	return Rect2(centro.x - w * 0.5, centro.y - d * 0.5, w, d)


## O parquinho: a caixa de areia, os brinquedos e os bancos de quem olha.
##
## Cada peca sai de uma FRACAO do retangulo, e nao de metros contados a partir da
## borda. E o que faz o mesmo arranjo caber num parquinho de vinte metros e num
## de dezesseis sem nenhum brinquedo pisando no vizinho ou saindo da areia.
##
## O giro do balanco nao e escolha de composicao. O vento do psx_surface sopra
## numa direcao so — VENTO_DIR, dominante em X — e e ele que balanca a cadeira.
## Com o vao do balanco em Z a cadeira vai e volta na direcao certa; virada
## noventa graus ela andaria de lado, que le como defeito e nao como vento.
##
## O piso e a caixa de areia SEM traves: a peca era compartilhada com o campo de
## futebol e o parquinho nascia com duas traves de gol plantadas em cima dos
## brinquedos.
static func _parquinho(sup: Dictionary, colisao: Array[Dictionary],
		plano: Dictionary, desloc: Vector2) -> void:
	var pq := parquinho_de(plano)
	KitParque.caixa_de_areia(sup, _mover(pq, desloc))

	var y := KitParque.Y_AREIA
	var sem := int(plano["semente"])
	# Onde cada brinquedo fica, em fracao do retangulo. A ordem e a de leitura:
	# o que se ve da entrada norte primeiro.
	var balanco := _ponto(pq, 0.24, 0.68) + desloc
	if _neste_chunk(balanco):
		KitParque.balanco(sup, colisao, Vector3(balanco.x, y, balanco.y), PI * 0.5)
	var escorrega := _ponto(pq, 0.80, 0.74) + desloc
	if _neste_chunk(escorrega):
		# Virado para dentro: a rampa desce na direcao do meio da areia, e nao
		# para cima do meio-fio.
		KitParque.escorregador(sup, colisao,
			Vector3(escorrega.x, y, escorrega.y), -PI * 0.5)

	# Parquinho apertado fica so com os dois brinquedos grandes. Enfiar seis numa
	# caixa de doze metros e o que produz brinquedo dentro de brinquedo.
	if pq.size.x < 16.0 or pq.size.y < 12.0:
		return

	var trepa := _ponto(pq, 0.22, 0.20) + desloc
	if _neste_chunk(trepa):
		KitParque.trepa_trepa(sup, colisao, Vector3(trepa.x, y, trepa.y), 0.0)
	var gira := _ponto(pq, 0.80, 0.26) + desloc
	if _neste_chunk(gira):
		KitParque.gira_gira(sup, colisao, Vector3(gira.x, y, gira.y), 1.35)
	var gangorra := _ponto(pq, 0.46, 0.83) + desloc
	if _neste_chunk(gangorra):
		KitParque.gangorra(sup, colisao, Vector3(gangorra.x, y, gangorra.y),
			PI * 0.5, KitParque.VERDE_BRINQUEDO)

	# Dois bichinhos de mola, que sao os unicos que se mexem de perto.
	var cores := [KitParque.VERMELHO_BRINQUEDO, KitParque.AMARELO_BRINQUEDO]
	for i in 2:
		var m := _ponto(pq, 0.48 + float(i) * 0.09, 0.36 + float(i) * 0.12) + desloc
		if not _neste_chunk(m):
			continue
		KitParque.mola(sup, colisao, Vector3(m.x, y, m.y),
			_ale(sem, i, 91) * TAU, cores[i])

	_bancos_em_volta(sup, colisao, plano, pq, desloc)


## Bancos virados para o miolo, na faixa de grama entre o meio-fio e o caminho.
##
## Sao os unicos bancos do parquinho e do campo: os do caminho em cruz caem todos
## dentro da zona proibida do miolo e nunca sao colocados. Sem estes, os dois
## eram os unicos parques da cidade sem onde sentar — e um campo de bola sem
## banco de beira de campo nao existe.
static func _bancos_em_volta(sup: Dictionary, colisao: Array[Dictionary],
		plano: Dictionary, pq: Rect2, desloc: Vector2) -> void:
	var sem := int(plano["semente"])
	var meio := RECUO_MIOLO * 0.5
	var indice := 0
	# [z do banco, giro]. `giro` leva o -Z local: no lado norte quem senta olha
	# para +Z, que e para dentro da areia.
	var lados := [
		[pq.position.y - meio, PI],
		[pq.end.y + meio, 0.0],
	]
	for lado: Array in lados:
		for k in 2:
			indice += 1
			var p := Vector2(lerpf(pq.position.x, pq.end.x, 0.3 + 0.4 * float(k)),
				lado[0]) + desloc
			if not _neste_chunk(p):
				continue
			KitParque.banco(sup, colisao,
				Vector3(p.x, KitModular.ALTURA_MEIO_FIO, p.y), lado[1],
				_ale(sem, indice, 92))
			if indice % 3 != 0:
				continue
			var lx := p + Vector2(cos(float(lado[1])), -sin(float(lado[1]))) * 1.5
			KitParque.lixeira(sup, colisao,
				Vector3(lx.x, KitModular.ALTURA_MEIO_FIO, lx.y), float(lado[1]))


## Ponto dentro de um retangulo, em fracao dos dois lados.
static func _ponto(r: Rect2, fx: float, fz: float) -> Vector2:
	return Vector2(r.position.x + r.size.x * fx, r.position.y + r.size.y * fz)


# --- mobiliario -------------------------------------------------------------

static func _mobiliario(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], plano: Dictionary, desloc: Vector2) -> void:
	var area: Rect2 = plano["area"]
	var centro: Vector2 = plano["centro"]
	var sem := int(plano["semente"])
	var proibido := _zonas_proibidas(plano, 0.0)

	# Bancos ao longo dos dois eixos do caminho em cruz, virados para ele. Banco
	# de costas para o caminho e o erro classico deste movel.
	if int(plano["traco"]) == Traco.LAGO:
		_mobiliario_do_lago(sup, props, colisao, plano, desloc)
		return
	if int(plano["traco"]) == Traco.PRACA:
		_mobiliario_praca_matriz(sup, props, colisao, plano, desloc)
		return

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
			# O poste tambem respeita o miolo. Sem esta linha, com numero impar
			# de vaos o poste do meio caia exatamente no centro do parque: dentro
			# do tanque do chafariz na praca, dentro da caixa de areia no
			# parquinho.
			if _dentro_de(proibido, p):
				continue
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


## Bancos e postes do parque do lago: no anel, virados para a agua.
##
## Banco de praca virado para o gramado, num parque que tem um lago, e o erro
## que o jogador percebe antes de qualquer outro.
static func _mobiliario_do_lago(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], plano: Dictionary, desloc: Vector2) -> void:
	var area: Rect2 = plano["area"]
	var sem := int(plano["semente"])
	var anel := area.grow(-5.0)
	var dentro := LARGURA_CAMINHO + 0.9
	var lados := [
		[Vector2(anel.position.x, anel.position.y + dentro),
			Vector2(anel.end.x, anel.position.y + dentro), PI],
		[Vector2(anel.position.x, anel.end.y - dentro),
			Vector2(anel.end.x, anel.end.y - dentro), 0.0],
		[Vector2(anel.position.x + dentro, anel.position.y),
			Vector2(anel.position.x + dentro, anel.end.y), -PI * 0.5],
		[Vector2(anel.end.x - dentro, anel.position.y),
			Vector2(anel.end.x - dentro, anel.end.y), PI * 0.5],
	]
	var indice := 0
	for j in lados.size():
		var lado: Array = lados[j]
		var a: Vector2 = lado[0]
		var b: Vector2 = lado[1]
		var giro: float = lado[2]
		var comp := (b - a).length()
		var n := maxi(1, int(comp / PASSO_BANCO))
		for i in n:
			indice += 1
			var p := a.lerp(b, (float(i) + 0.5) / float(n))
			var local := p + desloc
			if _neste_chunk(local):
				KitParque.banco(sup, colisao,
					Vector3(local.x, KitModular.ALTURA_MEIO_FIO, local.y), giro,
					_ale(sem, indice, 31))
				if indice % 3 == 0:
					var lx := local + Vector2(cos(giro), -sin(giro)) * 1.5
					KitParque.lixeira(sup, colisao,
						Vector3(lx.x, KitModular.ALTURA_MEIO_FIO, lx.y), giro)
			if i % 2 != 0:
				continue
			# O poste vai do lado de fora do banco, sobre o caminho do anel.
			var pl := p - Vector2(sin(giro), cos(giro)) * 2.2 + desloc
			if not _neste_chunk(pl):
				continue
			var globo := KitParque.poste_globo(sup, colisao,
				Vector3(pl.x, KitModular.ALTURA_MEIO_FIO, pl.y))
			props.append({
				"tipo": "lampada", "pos": globo,
				"padrao": Lampada.Padrao.ESTAVEL,
				"semente": sem + indice * 97,
				"cor": Color("ffd9a0"), "energia": 2.6, "alcance": 9.5,
				"facho": true,
			})


# --- vegetacao --------------------------------------------------------------

static func _vegetacao(sup: Dictionary, colisao: Array[Dictionary],
		plano: Dictionary, desloc: Vector2) -> void:
	# Matriz = calcamento colonial: sem moita_de_flor / flor atlas no miolo.
	# Arvores so na faixa periferica (zonas_proibidas ja cobre o pateo).
	var area: Rect2 = plano["area"]
	var sem := int(plano["semente"])
	var proibido := _zonas_proibidas(plano, 2.8)
	var densidade: float = DENSIDADE[int(plano["traco"])]
	if int(plano["traco"]) == Traco.PRACA:
		densidade *= 0.35  # menos copa; zero flor (so arvore/arbusto/pinheiro abaixo)
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


## O lago: a escavacao, o que boia, o que cresce na margem e o volume que diz
## ao jogador que ele esta molhado.
##
## O volume sai UMA vez, do chunk que contem o centro do lago, e nao um por
## chunk: sao caixas que se sobrepoem, e o jogador dentro de duas delas nadaria
## com o dobro do empuxo.
static func _lago(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], plano: Dictionary, desloc: Vector2) -> void:
	var l := lago_de(plano)
	var sem := int(plano["semente"])
	KitParque.lago(sup, colisao, _mover(l, desloc))

	var centro := l.get_center() + desloc
	if _neste_chunk(centro):
		props.append({
			"tipo": "lago",
			"pos": Vector3(centro.x, KitParque.Y_AGUA, centro.y),
			"tamanho": Vector3(l.size.x, KitParque.Y_AGUA - KitParque.FUNDO_LAGO,
				l.size.y),
			"semente": sem,
		})

	# Nenufares, so na parte funda. Na rampa eles ficariam meio enterrados.
	var fundo := l.grow(-KitParque.MARGEM_LAGO - 0.6)
	for i in 26:
		var p := Vector2(
			lerpf(fundo.position.x, fundo.end.x, _ale(sem, i, 71)),
			lerpf(fundo.position.y, fundo.end.y, _ale(sem, i, 72))) + desloc
		if not _neste_chunk(p):
			continue
		KitParque.nenufar(sup, Vector3(p.x, KitParque.Y_AGUA + 0.02, p.y),
			lerpf(0.7, 1.5, _ale(sem, i, 73)), _ale(sem, i, 74) * TAU,
			_ale(sem, i, 75) < 0.3)

	# Junco na beirada, na agua rasa do barranco. E a planta que faz a margem
	# parar de ser uma linha reta entre a areia e a agua.
	for i in 90:
		var borda := _ale(sem, i, 76)
		var t := _ale(sem, i, 77)
		var recuo := lerpf(0.3, KitParque.MARGEM_LAGO * 0.7, _ale(sem, i, 78))
		var p := Vector2.ZERO
		match int(borda * 4.0) % 4:
			0:
				p = Vector2(lerpf(l.position.x, l.end.x, t), l.position.y + recuo)
			1:
				p = Vector2(lerpf(l.position.x, l.end.x, t), l.end.y - recuo)
			2:
				p = Vector2(l.position.x + recuo, lerpf(l.position.y, l.end.y, t))
			_:
				p = Vector2(l.end.x - recuo, lerpf(l.position.y, l.end.y, t))
		var local := p + desloc
		if not _neste_chunk(local):
			continue
		# A altura do barranco no ponto: a planta nasce no chao, nao na lamina.
		var y := lerpf(KitParque.FUNDO_LAGO, KitParque.Y_GRAMA,
			1.0 - clampf(recuo / KitParque.MARGEM_LAGO, 0.0, 1.0))
		KitParque.moita_de_flor(sup, Vector3(local.x, y, local.y),
			Vector2i(5, 0) if _ale(sem, i, 79) < 0.7 else Vector2i(4, 0),
			lerpf(1.1, 1.9, _ale(sem, i, 80)), _ale(sem, i, 81) * PI)

	# Um deque na margem larga, saindo para dentro da agua.
	var area: Rect2 = plano["area"]
	var oeste := l.position.x - area.position.x
	var leste := area.end.x - l.end.x
	var giro := PI * 0.5 if oeste > leste else -PI * 0.5
	var borda_x := l.position.x - 1.2 if oeste > leste else l.end.x + 1.2
	var base := Vector2(borda_x, l.get_center().y) + desloc
	KitParque.deque(sup, colisao,
		Vector3(base.x, 0.0, base.y), KitParque.MARGEM_LAGO + 4.0, giro)

	# Pedras na margem larga. Sem elas o barranco e uma rampa de areia e o
	# lago le como piscina.
	for i in 14:
		var t := _ale(sem, i, 88)
		var recuo := lerpf(0.4, KitParque.MARGEM_LAGO * 0.55, _ale(sem, i, 89))
		var borda := int(_ale(sem, i, 90) * 4.0) % 4
		var p := Vector2.ZERO
		match borda:
			0:
				p = Vector2(lerpf(l.position.x, l.end.x, t), l.position.y + recuo)
			1:
				p = Vector2(lerpf(l.position.x, l.end.x, t), l.end.y - recuo)
			2:
				p = Vector2(l.position.x + recuo, lerpf(l.position.y, l.end.y, t))
			_:
				p = Vector2(l.end.x - recuo, lerpf(l.position.y, l.end.y, t))
		var local := p + desloc
		if not _neste_chunk(local):
			continue
		var y := lerpf(KitParque.FUNDO_LAGO, KitParque.Y_GRAMA,
			1.0 - clampf(recuo / KitParque.MARGEM_LAGO, 0.0, 1.0))
		var tam := lerpf(0.35, 0.7, _ale(sem, i, 91))
		KitModular.caixa_cor(sup, &"concreto_sujo",
			Vector3(local.x, y + tam * 0.35, local.y),
			Vector3(tam, tam * 0.7, tam * 0.85), Color("6a6558"),
			_ale(sem, i, 92) * TAU)


## Canteiros de flor. Ficam colados no caminho, que e onde o jogador passa: um
## canteiro no meio do gramado e uma mancha de cor que ninguem chega perto.
const CELULAS_FLOR: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	Vector2i(6, 0), Vector2i(7, 0),
]

static func _canteiros(sup: Dictionary, plano: Dictionary, desloc: Vector2) -> void:
	# Matriz e pedra irregular, nao jardim: flor no calcamento denuncia o gerador.
	if int(plano["traco"]) == Traco.PRACA:
		return
	var sem := int(plano["semente"])
	var faixas := faixas_de_caminho(plano)
	# O canteiro acompanha UM caminho e ignorava todos os outros. Onde dois
	# caminhos se cruzam — e eles se cruzam no meio do parque, na entrada de cada
	# portao e nas quatro quinas do anel — a flor do primeiro nascia em cima da
	# pedra do segundo. Era isso que se via na captura: fileiras de flor plantadas
	# no meio do calcamento e dentro da caixa de areia.
	var proibido := _zonas_proibidas(plano, 0.0)
	for f in faixas.size():
		var faixa: Rect2 = faixas[f]
		var ao_longo_de_x := faixa.size.x >= faixa.size.y
		var comprimento: float = faixa.size.x if ao_longo_de_x else faixa.size.y
		# Uma moita a cada meio metro dos dois lados. Denso de proposito:
		# canteiro ralo le como mato, e o que se quer e a mancha de cor.
		var n := int(comprimento / 0.55)
		for i in n:
			var chave := f * 1024 + i
			# Trechos inteiros sem flor. Canteiro continuo de ponta a ponta vira
			# jardim frances, que nao e o que este parque e.
			if _ale(sem, chave / 24, 82) > 0.62:
				continue
			for lado: float in [-1.0, 1.0]:
				var t := (float(i) + 0.5) / float(n)
				# Meio metro de recuo minimo: a moita tem 35 cm de meio raio, e
				# com os 18 cm de antes metade dela ficava por cima da placa.
				var fora := lerpf(0.5, 1.15, _ale(sem, chave, 83))
				var p := Vector2.ZERO
				if ao_longo_de_x:
					p = Vector2(lerpf(faixa.position.x, faixa.end.x, t),
						faixa.get_center().y + (faixa.size.y * 0.5 + fora) * lado)
				else:
					p = Vector2(faixa.get_center().x + (faixa.size.x * 0.5 + fora) * lado,
						lerpf(faixa.position.y, faixa.end.y, t))
				if _dentro_de(proibido, p) or _sobre_calcamento(faixas, p):
					continue
				# Recuo da borda da quadra: sem isto a moita nasce na calcada da
				# rua, que e o que se via atravessando a guia.
				var area: Rect2 = plano["area"]
				if not area.grow(-1.15).has_point(p):
					continue
				var local := p + desloc
				if not _neste_chunk(local):
					continue
				var celula: Vector2i = CELULAS_FLOR[int(_ale(sem, chave / 24, 84)
					* float(CELULAS_FLOR.size())) % CELULAS_FLOR.size()]
				# O tom varia por moita. Sem isso o canteiro inteiro e uma cor
				# so e a repeticao da celula fica visivel.
				var tom := lerpf(0.82, 1.12, _ale(sem, chave, 85))
				KitParque.moita_de_flor(sup,
					Vector3(local.x, KitModular.ALTURA_MEIO_FIO, local.y),
					celula, lerpf(0.42, 0.7, _ale(sem, chave, 86)),
					_ale(sem, chave, 87) * PI, Color(tom, tom * 0.98, tom * 0.94))


## Flor sobre a cama de terra do canteiro. Poucas, densas: mancha de cor, nao
## tapete.
static func _flores_no_canteiro(sup: Dictionary, cama: Rect2, desloc: Vector2,
		sem: int, indice: int) -> void:
	var n := 5
	for k in n:
		var chave := indice * 16 + k
		var p := Vector2(
			lerpf(cama.position.x + 0.2, cama.end.x - 0.2, _ale(sem, chave, 93)),
			lerpf(cama.position.y + 0.2, cama.end.y - 0.2, _ale(sem, chave, 94)))
		var local := p + desloc
		if not _neste_chunk(local):
			continue
		var celula: Vector2i = CELULAS_FLOR[int(_ale(sem, chave, 95)
			* float(CELULAS_FLOR.size())) % CELULAS_FLOR.size()]
		var tom := lerpf(0.88, 1.12, _ale(sem, chave, 96))
		KitParque.moita_de_flor(sup,
			Vector3(local.x, KitParque.Y_TERRA, local.y),
			celula, lerpf(0.38, 0.62, _ale(sem, chave, 97)),
			_ale(sem, chave, 98) * PI, Color(tom, tom * 0.97, tom * 0.92))


# --- geometria de apoio -----------------------------------------------------


## Chao da Praca da Matriz: pedra irregular em ladrilhos, com desnivel leve.
## O terreiro da igreja, em metros da quadra. Publico porque DOIS lugares
## precisam do mesmo retangulo e nao podem discordar: quem pinta a grama e quem
## decide qual ladrilho de calcamento nao desenhar. Escrito duas vezes, a grama
## nasceria com uma borda e a pedra com outra, e entre elas abriria fresta.
static func terreiro_de(plano: Dictionary) -> Rect2:
	var centro: Vector2 = plano["centro"]
	var pl := planta_matriz(centro)
	var z1: float = centro.y + float(pl["adro_z"]) - 0.30
	# O fundo do terreiro vai ate a traseira da nave, e nao so ate a fachada: a
	# capela fica DENTRO do gramado, como na print 01, e nao pousada na borda
	# dele. `igreja` e o centro do volume e a nave tem 12,0 de fundura.
	var z0: float = (pl["igreja"] as Vector2).y - 7.4
	var meia: float = float(pl["adro_larg"]) * 0.5 - 0.30
	return Rect2(centro.x - meia, z0, meia * 2.0, z1 - z0)


static func _chao_praca_matriz(sup: Dictionary, plano: Dictionary, desloc: Vector2) -> void:
	var area: Rect2 = plano["area"]
	var sem := int(plano["semente"])
	# Grama atras do casario, contra o gradil. Sem ela a borda da praca era o
	# mesmo calcamento amarelo da rua e o teste da cidade nao achava `grama`.
	var nucleo := area.grow(-4.8)
	if nucleo.size.x > 8.0 and nucleo.size.y > 8.0:
		var faixas := [
			Rect2(area.position.x, area.position.y, area.size.x, nucleo.position.y - area.position.y),
			Rect2(area.position.x, nucleo.end.y, area.size.x, area.end.y - nucleo.end.y),
			Rect2(area.position.x, nucleo.position.y, nucleo.position.x - area.position.x, nucleo.size.y),
			Rect2(nucleo.end.x, nucleo.position.y, area.end.x - nucleo.end.x, nucleo.size.y),
		]
		for f: Rect2 in faixas:
			KitParque.piso(sup, &"grama", _mover(f, desloc), KitParque.Y_GRAMA)
	else:
		nucleo = area
	# O terreiro da igreja e GRAMA, e nao pedra.
	#
	# A print 01 mostra a capela plantada num gramado com um caminho de concreto
	# ate a porta - e nao no mesmo calcamento por onde se anda na praca. Alem de
	# ser a referencia, e o que finalmente da ao adro a razao numero 2 que o
	# comentario dele sempre prometeu: separar o chao da igreja do chao da
	# praca. Com pedra dos dois lados, o muro separava dois nadas.
	#
	# A grama vai por baixo (Y_GRAMA 0,16 contra Y_CALCAMENTO 0,22), entao ela
	# cobre o retangulo INTEIRO e quem some e o ladrilho: o que tiver o centro
	# dentro do terreiro nao e desenhado. A borda fica denteada na escala do
	# ladrilho, que e como calcamento encontra grama de verdade, e nao abre
	# fresta em lugar nenhum porque os ladrilhos de beirada continuam por cima.
	var terreiro := terreiro_de(plano)
	KitParque.piso(sup, &"grama", _mover(terreiro, desloc), KitParque.Y_GRAMA)

	var nx := maxi(1, int(round(nucleo.size.x / PLACA)))
	var nz := maxi(1, int(round(nucleo.size.y / PLACA)))
	var passo := Vector2(nucleo.size.x / float(nx), nucleo.size.y / float(nz))
	for j in nz:
		for i in nx:
			var p := nucleo.position + Vector2(passo.x * float(i), passo.y * float(j))
			var r := Rect2(p - Vector2(SOBREPOSICAO, SOBREPOSICAO),
				passo + Vector2(SOBREPOSICAO * 2.0, SOBREPOSICAO * 2.0))
			if terreiro.has_point(p + passo * 0.5):
				continue
			var chave := j * 512 + i
			var alto := KitParque.Y_CALCAMENTO + lerpf(-DESNIVEL, DESNIVEL, _ale(sem, chave, 51))
			var tom := lerpf(TOM_PEDRA_MIN, TOM_PEDRA_MAX, _ale(sem, chave, 52))
			KitParque.piso(sup, &"pedra_parque", _mover(r, desloc), alto,
				Color(tom, tom * 0.98, tom * 0.94))

	# Caminho de placas de concreto, do portao ate o primeiro degrau, no eixo da
	# porta. E o que a print 01 mostra cortando o gramado, e sem ele o jogador
	# atravessa a grama porque nao ha por onde andar - o mesmo motivo pelo qual
	# o parque do lago sempre tem anel.
	#
	# Placa a placa, com desnivel de um centimetro entre vizinhas, pelo mesmo
	# motivo do calcamento: superficie grande, chapada e perfeitamente plana nao
	# existe em lugar nenhum, e a luz do lampiao pega diferente em cada placa.
	var pl_m := planta_matriz(plano["centro"])
	var eixo_x: float = (plano["centro"] as Vector2).x
	var cam_z1: float = (plano["centro"] as Vector2).y + float(pl_m["adro_z"])
	var cam_z0: float = (pl_m["igreja"] as Vector2).y + 6.9
	const CAMINHO_L := 2.2
	const CAMINHO_P := 1.1
	var n_pl := maxi(1, int(round((cam_z1 - cam_z0) / CAMINHO_P)))
	var passo_pl := (cam_z1 - cam_z0) / float(n_pl)
	for i in n_pl:
		var z0_pl := cam_z0 + float(i) * passo_pl - SOBREPOSICAO
		var placa := Rect2(eixo_x - CAMINHO_L * 0.5, z0_pl,
			CAMINHO_L, passo_pl + SOBREPOSICAO * 2.0)
		var alto_pl := KitParque.Y_CALCAMENTO 			+ lerpf(-DESNIVEL, DESNIVEL, _ale(sem, i, 57))
		var tom_pl := lerpf(0.52, 0.68, _ale(sem, i, 58))
		KitParque.piso(sup, &"calcada", _mover(placa, desloc), alto_pl,
			Color(tom_pl, tom_pl * 0.99, tom_pl * 0.96))


## Eixos e anel da Matriz — usados por bancos/postes, nao por segundo piso.
static func _faixas_praca_matriz(plano: Dictionary) -> Array[Rect2]:
	var area: Rect2 = plano["area"]
	var centro: Vector2 = plano["centro"]
	var meia := LARGURA_CAMINHO * 0.5
	var saida: Array[Rect2] = []
	saida.append(Rect2(area.position.x, centro.y - meia, area.size.x, LARGURA_CAMINHO))
	saida.append(Rect2(centro.x - meia, area.position.y, LARGURA_CAMINHO, area.size.y))
	var r := area.grow(-6.0)
	saida.append(Rect2(r.position.x, r.position.y, r.size.x, LARGURA_CAMINHO))
	saida.append(Rect2(r.position.x, r.end.y - LARGURA_CAMINHO, r.size.x, LARGURA_CAMINHO))
	saida.append(Rect2(r.position.x, r.position.y, LARGURA_CAMINHO, r.size.y))
	saida.append(Rect2(r.end.x - LARGURA_CAMINHO, r.position.y, LARGURA_CAMINHO, r.size.y))
	return saida


## Planta da Praca da Matriz, num lugar so.
##
## Existe porque a versao anterior espalhava a mesma praca por dois metodos com
## numeros magicos independentes: `_praca_matriz` decidia onde ficavam as casas e
## `_mobiliario_praca_matriz` decidia onde ficavam os postes, sem os dois nunca
## se falarem. O resultado previsivel foi um poste nascendo DENTRO da parede de
## uma casa de aproximacao, e a unica razao de ninguem ter visto e que a nevoa
## comia aquele canto. Aqui a fachada e a posicao do poste saem da mesma conta:
## mexer numa fileira move os postes junto, de graca.
##
## Todas as coordenadas sao locais a quadra, em metros. +Z e o SUL — o lado do
## pin de onde o jogador acorda e olha para a igreja, ao norte.
static func planta_matriz(centro_q: Vector2) -> Dictionary:
	# Igreja recuada para o fundo. Ela cresceu, e o enquadramento do pin nao:
	# o teto do quadro em 270,-40 esta em ~9,3 m a 10,5 m de distancia, e sobe
	# proporcional a distancia. Recuar 3 m paga a nave mais alta sem cortar a
	# cruz. Ver o CHECKPOINT em captures/praca_matriz/aaa_detalhe.
	var igreja := centro_q + Vector2(0.0, -8.0)
	# Coreto: a OESTE do eixo (as refs poem ele ao lado, nao no meio) e agora
	# tambem ao SUL. Estava a 11 m do centro da igreja, com a borda do beiral a
	# 1,4 m da sineira — lia como anexo da igreja, nao como coreto de praca.
	# Agora sao 16,2 m e os dois volumes se leem separados.
	var coreto := centro_q + Vector2(-9.0, 5.5)

	# Quatro fileiras germinadas fechando a praca e o corredor de aproximacao,
	# mais duas ladeando a igreja ao norte — as "cabanas em volta da igreja".
	var fileiras: Array[Dictionary] = [
		{"de": Vector2(-17.0, -13.0), "ate": Vector2(-17.0, 9.0), "giro": PI * 0.5, "s": 101},
		{"de": Vector2(17.0, -13.0), "ate": Vector2(17.0, 9.0), "giro": -PI * 0.5, "s": 137},
		{"de": Vector2(-10.5, 9.0), "ate": Vector2(-10.5, 26.0), "giro": PI * 0.5, "s": 173},
		{"de": Vector2(10.5, 9.0), "ate": Vector2(10.5, 26.0), "giro": -PI * 0.5, "s": 211},
		{"de": Vector2(-19.0, -11.5), "ate": Vector2(-11.0, -11.5), "giro": 0.0, "s": 251},
		{"de": Vector2(12.0, -11.5), "ate": Vector2(20.0, -11.5), "giro": 0.0, "s": 293},
		# Seis fileiras novas, para o casario chegar na borda REAL da quadra.
		#
		# A praca tem 79,8 x 83,8 m uteis e o cenario composto ocupava 55 x 55:
		# o resto era calcamento nu, que de cima le como estacionamento. Estas
		# fecham o segundo anel - os flancos do campo santo ao norte, o fundo ao
		# sul e as duas pontas leste e oeste.
		#
		# Cada uma foi conferida contra o que ja estava no chao, porque casa
		# nasce PARA TRAS da linha de fachada (CASA_FUNDURA = 5,6) e e ai que a
		# colisao acontece sem ninguem ver: a de x = -24 ocupa de -29,6 a -24, e
		# por isso a arvore de (-27, -14) ficou fora da faixa z dela.
		{"de": Vector2(-24.0, -28.0), "ate": Vector2(-24.0, -18.0), "giro": PI * 0.5, "s": 331},
		{"de": Vector2(24.0, -28.0), "ate": Vector2(24.0, -18.0), "giro": -PI * 0.5, "s": 367},
		{"de": Vector2(-14.0, 31.0), "ate": Vector2(-5.0, 31.0), "giro": PI, "s": 401},
		{"de": Vector2(5.0, 31.0), "ate": Vector2(14.0, 31.0), "giro": PI, "s": 433},
		{"de": Vector2(-31.0, 4.0), "ate": Vector2(-31.0, 16.0), "giro": PI * 0.5, "s": 467},
		{"de": Vector2(31.0, 6.0), "ate": Vector2(31.0, 18.0), "giro": -PI * 0.5, "s": 503},
	]

	# Cabanas soltas alem das fileiras, vistas pelas frestas. Giro torto de
	# proposito: numa praca colonial tudo se alinha a rua, e a casa fora de
	# esquadro e a primeira coisa que diz que aqui alguma coisa nao esta certa.
	var soltas: Array[Dictionary] = [
		{"pos": Vector2(-24.0, 14.0), "giro": PI * 0.5 + 0.18, "larg": 6.4},
		{"pos": Vector2(23.5, 17.5), "giro": -PI * 0.5 - 0.13, "larg": 5.8},
		{"pos": Vector2(-27.0, -4.0), "giro": PI * 0.5 - 0.09, "larg": 6.0},
		{"pos": Vector2(26.5, 2.0), "giro": -PI * 0.5 + 0.15, "larg": 6.6},
		{"pos": Vector2(-22.0, -20.0), "giro": 0.12, "larg": 6.2},
		{"pos": Vector2(21.5, -19.0), "giro": -0.16, "larg": 5.6},
		# Seis cabanas novas, todas nos CANTOS da quadra - que era onde nao
		# havia nada e onde o jogador chega quando contorna a praca por tras.
		# Continuam fora de esquadro pelo mesmo motivo das outras: numa praca
		# colonial tudo se alinha a rua, e a casa torta e a primeira coisa que
		# diz que aqui a rua nao mandou em nada.
		{"pos": Vector2(-33.0, -30.0), "giro": PI * 0.5 + 0.22, "larg": 5.4},
		{"pos": Vector2(33.0, -31.0), "giro": -PI * 0.5 - 0.18, "larg": 6.0},
		{"pos": Vector2(-34.0, 8.0), "giro": PI * 0.5 - 0.14, "larg": 5.8},
		{"pos": Vector2(34.0, 12.0), "giro": -PI * 0.5 + 0.19, "larg": 6.2},
		{"pos": Vector2(-30.0, 33.0), "giro": 0.17, "larg": 5.6},
		{"pos": Vector2(30.0, 34.0), "giro": -0.21, "larg": 6.4},
	]

	# Postes no anel util e no eixo sul. Ficam a 3,5 m na frente da fachada da
	# fileira correspondente, e nao num raio inventado: e isso que garante que
	# nenhum deles volte a nascer dentro de uma parede.
	var postes: Array[Vector2] = [
		Vector2(-13.5, -9.0), Vector2(13.5, -9.0),
		Vector2(-13.5, 4.0), Vector2(13.5, 4.0),
		Vector2(-7.0, 12.5), Vector2(7.0, 12.5),
		Vector2(-7.0, 21.0), Vector2(7.0, 21.0),
	]

	# Adro: muro na frente da igreja, portao no eixo da porta.
	#
	# Estava em +1,4, colado nos degraus, e o terreiro que sobrava tinha 3,4 m
	# de fundo: faixa estreita demais para o gramado que a print 01 mostra na
	# frente da capela. Em +4,0 o terreiro passa a 5,6 m e vira adro de verdade.
	#
	# Os 2,6 m de avanco foram conferidos contra as DUAS cameras que nao sao
	# desta task, porque e para elas que o muro existe:
	#
	#   pin do acordar (z = -40): o muro fica a 7,1 m. Topo em 0,9 m, olho em
	#   1,62 - a linha de visao passa em 0,31 m no plano da fachada, e a porta
	#   comeca em 0,55. A porta continua inteira no quadro e o muro continua
	#   cruzando o terco inferior dele, que e a razao numero 1 de ele existir.
	#
	#   TAKE 5 da abertura (c5 ~ z -35): o muro fica a 12,1 m, ainda na frente
	#   da camera. A camada intermediaria da revelacao esta preservada.
	var adro_z := 4.0
	var adro_larg := 21.0
	# O CRUZEIRO, no lugar das tres cruzes de pedra soltas.
	#
	# Uma vertical forte vale mais que tres fracas, e e o que as tres prints
	# mostram: numa praca de arraial ha um cruzeiro, no singular, e ele e a
	# primeira coisa que se ve. As tres cruzinhas de um metro que estavam aqui
	# nao apareciam em captura nenhuma.
	#
	# A OESTE da capela, DENTRO do terreiro gramado. E a posicao da print 01: o
	# cruzeiro na grama, a esquerda, com a capela a direita.
	#
	# A primeira tentativa foi (-7,6 , +2,8), ja no calcamento ao sul do muro,
	# porque e assim que a print 03 mostra. Medido em captura: o cruzeiro nascia
	# a 3,04 m do centro do coreto, que tem 3,4 m de raio - ou seja DENTRO dele,
	# com a travessa saindo por baixo do beiral. Da praca os dois viravam um
	# amontoado so.
	#
	# Em (-8,2 , -1,2) a distancia ao coreto vai a 6,75 m, com 4,6 m de raio
	# somado: folga de 2,1 m e dois volumes que se leem separados. Em X o
	# pedestal fica entre -9,4 e -7,0, ou seja 0,4 m livre do plinto da capela
	# (que vai a -6,6) e 0,8 m livre da borda do terreiro (-10,2).
	#
	# As duas referencias ficam cada uma no seu chao, que e o que elas sao: a
	# print 01 e o TERREIRO (grama, cruzeiro, caminho) e a print 03 e a PRACA
	# (calcamento, canteiro, guarda-corpo). Ver `_praca_matriz`.
	var cruzeiro := Vector2(-8.2, -1.2)

	return {
		"igreja": igreja,
		"coreto": coreto,
		"coreto_raio": 3.4,
		"adro_z": adro_z,
		"adro_larg": adro_larg,
		"cruzeiro": cruzeiro,
		"fileiras": fileiras,
		"soltas": soltas,
		"postes": postes,
	}


## Layout da Praca da Matriz: igreja ao norte, coreto a OESTE e ao SUL do eixo,
## casario germinado fechando a praca, o corredor de aproximacao e os flancos da
## igreja. Tudo sai de `planta_matriz`.
##
## Cada peca e ancorada num ponto so, e o chunk que contem esse ponto desenha a
## peca INTEIRA, mesmo a parte que cai no vizinho. E a mesma regra do cruzamento:
## meia fileira desenhada de cada lado nao concorda sobre onde comeca o modulo, e
## a junta abre.
static func _praca_matriz(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], plano: Dictionary, desloc: Vector2) -> void:
	var centro_q: Vector2 = plano["centro"]
	var sem := int(plano["semente"])
	var y := KitParque.Y_CALCAMENTO
	var pl := planta_matriz(centro_q)

	var coreto_p: Vector2 = pl["coreto"] + desloc
	if _neste_chunk(coreto_p):
		KitParque.coreto(sup, colisao, Vector3(coreto_p.x, y, coreto_p.y),
			float(pl["coreto_raio"]))

	var igreja: Vector2 = pl["igreja"] + desloc
	if _neste_chunk(igreja):
		KitParque.igreja_matriz(sup, colisao,
			Vector3(igreja.x, y, igreja.y), 0.0)

	# Adro e cruzes saem do MESMO ponto de ancoragem da igreja, e nao de um
	# `_neste_chunk` proprio: o muro tem dezenove metros e atravessa fronteira de
	# chunk. Ancorado nele mesmo, metade sairia de um chunk e metade do vizinho,
	# e os dois nao concordariam sobre onde comeca o vao do portao.
	var adro_p := Vector2(centro_q.x, centro_q.y + float(pl["adro_z"])) + desloc
	if _neste_chunk(igreja):
		KitParque.adro(sup, colisao, Vector3(adro_p.x, y, adro_p.y),
			float(pl["adro_larg"]), 0.0)

	# O cruzeiro tem ancoragem PROPRIA, e nao a da igreja: ele fica 7,6 m a
	# oeste e 10,8 m ao sul dela, o que atravessa fronteira de chunk numa quadra
	# de 96 m. Ancorado na igreja, o chunk dono desenharia um cruzeiro fora dos
	# proprios limites e o chunk onde ele realmente esta nao desenharia nada.
	var cruz_p: Vector2 = centro_q + (pl["cruzeiro"] as Vector2) + desloc
	if _neste_chunk(cruz_p):
		KitParque.cruzeiro(sup, colisao, Vector3(cruz_p.x, y, cruz_p.y), 0.0)
		# Guarda-corpo rustico nos dois lados, sem fechar o quadrado.
		#
		# Cerca fechando os quatro lados viraria curral em volta da cruz, e as
		# duas prints mostram o contrario: da para chegar no pedestal e encostar
		# nele. Duas corridas paralelas marcam o recinto e deixam as pontas
		# abertas. Aqui elas correm no eixo NORTE-SUL, e nao leste-oeste: a
		# capela esta a 5 m a leste, e uma cerca atravessada nessa direcao
		# cortaria a passagem entre o cruzeiro e a porta.
		for sx: float in [-1.0, 1.0]:
			var a := cruz_p + Vector2(2.3 * sx, -2.6)
			var b := cruz_p + Vector2(2.3 * sx, 2.6)
			KitParque.guarda_corpo_rustico(sup, colisao,
				Vector3(a.x, y, a.y), Vector3(b.x, y, b.y))

	# --- gente na praca -----------------------------------------------------
	#
	# `Convidado` com `Papel.LIVRE` ja faz exatamente isto: circula por uma
	# lista de pontos, para, encosta em alguem, conversa e volta. E primo do
	# `Pedestre` e nao irmao - o Pedestre resolve grafo de calcada e rota pela
	# cidade, que numa praca de 80 m nao e o problema. O problema e as pessoas
	# nao andarem todas na mesma linha, e e o Convidado que resolve esse.
	#
	# Os pontos formam um anel largo pelo calcamento e SOBEM ate o portao do
	# adro: e o que faz a praca ler como caminho para a igreja em vez de patio.
	# Ninguem entra no terreiro - do portao para dentro e chao da capela.
	#
	# Quatro pessoas, e nao dez. O teto de `Multidao` e catorze para a cidade
	# INTEIRA; uma praca que come quatro ja e o lugar mais povoado do jogo as
	# onze e quinze da noite, e e para ser.
	var rota := rota_da_praca(centro_q, desloc)
	for k in 4:
		# Nasce EM CIMA de um ponto da rota, e nao num lugar inventado: ponto de
		# nascimento proprio e mais um numero que pode cair dentro de um murete.
		var p0: Vector3 = rota[k * 2]
		if not _neste_chunk(Vector2(p0.x, p0.z)):
			continue
		props.append({
			"tipo": "convidado",
			"pos": p0,
			"giro": TAU * float(k) / 4.0,
			"semente": sem + 401 + k * 137,
			"pontos": rota,
			"papel": Convidado.Papel.LIVRE,
			# Faixa larga de idade: uma praca de arraial a noite nao e so gente
			# de vinte anos, e o gerador de ficha ja sabe envelhecer o rosto.
			"idade_min": 19, "idade_max": 68,
		})

	# --- a praca em si: canteiros e cerca de madeira (print 03) ------------
	#
	# Sao os dois canteiros de terra com murete baixo e cerca de tora que a
	# `03_cruzeiro_hoje.png` mostra no calcamento, e existem por uma razao
	# medida antes de ser estetica: da vista de cima, do muro do adro ate a
	# fileira sul havia uma area continua de calcamento nu maior que a praca
	# ocupada. Piso liso de vinte metros nao e espaco, e vazio.
	#
	# Ficam AFASTADOS do eixo (9,5 m) e do pin do acordar. O pin esta em
	# (-0,9 , +11,1) e a camera do TAKE 5 em (-2,5 , +16,1): com os canteiros em
	# +12,0 e a 9,5 m de cada lado, nenhum dos dois planos ganha um murete
	# atravessado no meio do quadro.
	# O corredor entre as duas fileiras do sul e o unico vao livre aqui, e ele
	# tem 21 m: as fileiras de x = +-10,5 crescem para tras e ocupam de 10,5 a
	# 16,1. As duas primeiras posicoes tentadas (+-9,5 e +-13,0) cravavam o
	# murete DENTRO da parede da casa - a de 13,0 inteira, a de 9,5 por um
	# metro. Em +-8,0 o canteiro para a 2,5 m da fachada.
	#
	# Em z eles fogem dos lampioes de (+-7 , 12,5) e (+-7 , 21) e do banco que
	# cada um deles carrega 2,2 m adiante.
	const CANTEIROS_PRACA: Array[Vector2] = [
		Vector2(-8.0, 16.5), Vector2(8.0, 16.5),
		Vector2(-8.0, 26.5), Vector2(8.0, 26.5),
	]
	var area_q: Rect2 = plano["area"]
	for i in CANTEIROS_PRACA.size():
		var bc: Vector2 = centro_q + CANTEIROS_PRACA[i]
		if not area_q.has_point(bc):
			continue
		var bl := bc + desloc
		if not _neste_chunk(bl):
			continue
		KitParque.canteiro(sup, colisao,
			Rect2(bl.x - 2.0, bl.y - 1.5, 4.0, 3.0), sem + 811 + i * 53)
		# A cerca so do lado que olha o eixo: cercar os quatro lados de um
		# canteiro de 4 m gasta doze montantes para dizer a mesma coisa.
		var sx := signf(CANTEIROS_PRACA[i].x)
		KitParque.guarda_corpo_rustico(sup, colisao,
			Vector3(bl.x + 2.3 * sx, y, bl.y - 1.7),
			Vector3(bl.x + 2.3 * sx, y, bl.y + 1.7))

	# --- o que estava atras: campo santo e arvores -------------------------
	#
	# A praca vinha sendo ajustada pelo quadro da cutscene, que olha a igreja de
	# frente. Mas a planta de cima mostra o que aquele quadro nunca enquadra: do
	# fundo da igreja ate a rua havia calcamento nu por uma area maior que a
	# praca inteira, e o mesmo em volta. Cenario que so fecha de um angulo nao e
	# cenario, e decoracao de palco — e este e o hub do jogo, o jogador vai andar
	# por tras.
	#
	# O cemiterio e medido contra a `area` da quadra, e nao contra numeros
	# soltos: quadra pequena encolhe o campo santo em vez de joga-lo na rua.
	var area: Rect2 = plano["area"]
	var santo_c := Vector2(centro_q.x, centro_q.y - 25.0)
	var santo_t := Vector2(26.0, 15.0)
	var folga := 5.0
	santo_t.x = minf(santo_t.x, area.size.x - folga * 2.0)
	santo_t.y = minf(santo_t.y, (santo_c.y - area.position.y - folga) * 2.0)
	if santo_t.x >= 12.0 and santo_t.y >= 9.0:
		santo_c.y = maxf(santo_c.y, area.position.y + folga + santo_t.y * 0.5)
		var sl := santo_c + desloc
		if _neste_chunk(sl):
			KitParque.campo_santo(sup, colisao, Vector3(sl.x, y, sl.y),
				santo_t, 0.0, sem + 613)

	# Arvores grandes nas bordas do vazio. Nao e o espalhamento generico do
	# parque (`_vegetacao` ja entra em 0,35 na praca de proposito): sao poucas e
	# escolhidas, para dar silhueta contra a nevoa nos cantos que hoje sao chao
	# liso, sem encher o meio por onde se anda.
	const ARVORES: Array[Vector2] = [
		Vector2(-24.0, -34.0), Vector2(25.0, -33.0),
		Vector2(-27.0, -14.0), Vector2(27.5, -12.0),
		Vector2(-25.0, 22.0), Vector2(26.0, 24.0),
		Vector2(-16.0, 31.0), Vector2(17.0, 30.5),
	]
	for i in ARVORES.size():
		var ap: Vector2 = centro_q + ARVORES[i]
		if not area.has_point(ap):
			continue
		var al := ap + desloc
		if not _neste_chunk(al):
			continue
		KitParque.arvore(sup, colisao, Vector3(al.x, KitParque.Y_CALCAMENTO, al.y),
			lerpf(0.55, 1.0, _ale(sem, i, 211)), _gerador(sem, i, 212),
			_ale(sem, i, 213) < 0.4)

	for f: Dictionary in pl["fileiras"]:
		var de: Vector2 = centro_q + (f["de"] as Vector2) + desloc
		var ate: Vector2 = centro_q + (f["ate"] as Vector2) + desloc
		if not _neste_chunk((de + ate) * 0.5):
			continue
		KitParque.fileira_colonial(sup, colisao,
			Vector3(de.x, y, de.y), Vector3(ate.x, y, ate.y),
			float(f["giro"]), sem + int(f["s"]))

	for i in (pl["soltas"] as Array).size():
		var c: Dictionary = pl["soltas"][i]
		var p: Vector2 = centro_q + (c["pos"] as Vector2) + desloc
		if not _neste_chunk(p):
			continue
		var s_casa := sem + int(p.x * 3.0)
		var rota_casa := rota_da_praca(centro_q, desloc)
		KitParque.casa_colonial_baixa(sup, colisao, Vector3(p.x, y, p.y),
			float(c["giro"]), float(c["larg"]), s_casa)
		# Um morador a cada tres cabanas. Quatro pessoas ja circulam na praca e
		# o teto de `Multidao` e catorze para a cidade INTEIRA: uma praca com
		# uma duzia de gente as onze e quinze da noite nao le como povoado, le
		# como festa.
		if i % 3 != 0:
			continue
		# A soleira sai da MESMA conta que `_modulo_colonial` usa para desenhar
		# a porta, e nao de um palpite. Se as duas contas divergirem o morador
		# some dentro da parede ao lado da porta, e essa e a classe de defeito
		# que ninguem ve acontecer: ele desaparece perto o bastante do vao para
		# parecer certo.
		var gc := float(c["giro"])
		var lg := float(c["larg"])
		var fr := Vector2(sin(gc), cos(gc))
		var ld := Vector2(cos(gc), -sin(gc))
		var px := lerpf(-lg * 0.22, lg * 0.22, float(absi(s_casa) % 5) / 4.0)
		var soleira := p + ld * px + fr * (KitParque.CASA_FUNDURA * 0.5 + 0.55)
		props.append({
			"tipo": "morador",
			"pos": Vector3(soleira.x, KitModular.ALTURA_MEIO_FIO, soleira.y),
			"soleira": Vector3(soleira.x, KitModular.ALTURA_MEIO_FIO, soleira.y),
			"giro": gc,
			"giro_da_casa": gc,
			"semente": sem + 709 + i * 211,
			"pontos": rota_casa,
			"papel": Convidado.Papel.LIVRE,
			"idade_min": 24, "idade_max": 72,
		})


## Por onde a gente da praca anda, em coordenada LOCAL do chunk.
##
## Publica e unica porque DOIS chamadores precisam da mesma lista e nao podem
## discordar: quem semeia os andantes no calcamento e quem semeia os moradores
## na porta das cabanas. Com a lista escrita nos dois, o morador sairia de casa
## para um anel diferente do que os vizinhos usam, e a praca teria duas
## multidoes que nunca se cruzam.
##
## Os pontos formam um anel largo pelo calcamento e SOBEM ate o portao do adro:
## e o que faz a praca ler como caminho para a igreja em vez de patio. Ninguem
## entra no terreiro — do portao para dentro e chao da capela.
static func rota_da_praca(centro_q: Vector2, desloc: Vector2) -> Array[Vector3]:
	# O anel foge do PIN DO ACORDAR, que fica em (-0,9 , +11,1).
	#
	# A primeira versao passava a 4,7 m dele. As cameras da abertura ficam entre
	# 2,35 e 4,5 m do corpo caido: alguem parado a 4,7 m entra no quadro de
	# quase todos os takes, e um morador que atravessa a cena enquanto o
	# personagem esta desmaiado no chao nao e um detalhe pequeno - e uma
	# decisao de roteiro, e ela nao e desta task.
	#
	# Nenhum ponto fica a menos de 6,6 m do pin agora, e o mais proximo (0 ,
	# 4,6) esta ATRAS do muro do adro, ou seja fora do cone de todos os takes
	# que olham para o sul.
	const ANDANTES: Array[Vector2] = [
		Vector2(-7.0, 6.0), Vector2(7.0, 6.0),
		Vector2(-8.5, 17.0), Vector2(8.5, 17.0),
		Vector2(0.0, 24.0), Vector2(-5.0, 29.0), Vector2(5.0, 29.0),
		Vector2(0.0, 4.6),
	]
	var saida: Array[Vector3] = []
	for a: Vector2 in ANDANTES:
		var ap: Vector2 = centro_q + a + desloc
		saida.append(Vector3(ap.x, KitModular.ALTURA_MEIO_FIO, ap.y))
	return saida


## Bancos e lanternas pretas com pocoes amarelas — leitura obrigatoria das refs.
##
## Nem todo poste acende. Uma praca colonial as onze e quinze da noite com oito
## lampioes igualmente firmes le como cenario bem iluminado; com um morto e dois
## falhando, o anel de luz ganha um buraco e o jogador olha para o buraco. E a
## tensao mais barata que existe aqui: nao custa um triangulo, nao custa uma
## luz a mais, e ja estava pronta em `Lampada.Padrao`.
##
## O poste morto tambem apaga o globo. Lanterna escura com vidro brilhando seria
## pior que o defeito que ela conserta.
static func _mobiliario_praca_matriz(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], plano: Dictionary, desloc: Vector2) -> void:
	var centro: Vector2 = plano["centro"]
	var sem := int(plano["semente"])
	var pl := planta_matriz(centro)

	var indice := 0
	# Lanternas da porta: iluminam a ombreira da igreja no fog denso. Estas duas
	# nunca falham — sao elas que mantem a fachada legivel no plano do acordar.
	var igreja_p: Vector2 = pl["igreja"]
	for sx: float in [-1.0, 1.0]:
		var ld := igreja_p + Vector2(4.6 * sx, 8.4) + desloc
		if not _neste_chunk(ld):
			continue
		indice += 1
		var luz_p := KitParque.poste_lanterna(sup, colisao,
			Vector3(ld.x, KitModular.ALTURA_MEIO_FIO, ld.y))
		props.append({
			"tipo": "lampada",
			"pos": luz_p,
			"padrao": Lampada.Padrao.ESTAVEL,
			"semente": sem + indice * 97,
			# Omni sem facho: o cone no denso virava bloom branco e comia a fachada.
			"cor": Color("ffc978"), "energia": 6.0, "alcance": 10.0,
			"atenuacao": 1.8, "facho": false,
		})

	# --- a capela por dentro, vista de fora ---------------------------------
	#
	# Tres velas e um harmonio. Nenhuma das quatro coisas mostra o interior da
	# igreja, e e esse o ponto: o jogador ve luz saindo por vaos e ouve um som
	# que atravessa parede. O lugar fica habitado sem custar um comodo.
	#
	# A altura sai da propria geometria da capela e nao de numeros soltos: o
	# desenho comeca em Y_CALCAMENTO (0,22), o plinto sobe 0,55, e dai para cima
	# valem as cotas do bloco da fachada em `KitParque.igreja_matriz`.
	var piso_igreja := KitParque.Y_CALCAMENTO + 0.55
	# Vela do vao da porta, logo atras da folha entreaberta. E a mais forte das
	# tres: e ela que acende a ombreira e o degrau, e e por ela que a fresta da
	# porta vira a coisa mais quente do quadro.
	# 0,9 m A FRENTE da fachada, e nao dentro do vao.
	#
	# Ela nasceu em +5,7, ou seja trinta centimetros DENTRO da nave, que e uma
	# caixa solida. Como `Lampada` desliga sombra (o PS1 nao tinha sombra
	# dinamica, ART-BIBLE secao 7), a luz atravessa a parede sem ser barrada —
	# mas atravessa pelas COSTAS dos vertices da fachada, com N.L negativo, e
	# vertice virado para o outro lado nao recebe nada. A vela acendia o miolo
	# invisivel da nave e mais nada.
	#
	# Em +6,9 ela fica na frente da ombreira e dos degraus: o que se ve e luz
	# quente pousada na soleira, saindo pela folha entreaberta.
	var vao_p := igreja_p + Vector2(0.0, 6.9) + desloc
	if _neste_chunk(vao_p):
		indice += 1
		props.append({
			"tipo": "lampada",
			"pos": Vector3(vao_p.x, piso_igreja + 1.6, vao_p.y),
			"padrao": Lampada.Padrao.VELA,
			"semente": sem + indice * 97,
			# Sem facho, e isto nao e economia. Cone visivel dentro de um vao de
			# 2,9 m vira bolha branca e come a ombreira inteira - foi o defeito
			# que as duas lanternas da porta ja tiveram, e esta escrito nelas.
			"cor": Color("ffb46a"), "energia": 3.4, "alcance": 7.0,
			"atenuacao": 1.9, "facho": false,
		})
		# O harmonio. `som_ambiente` ja faz o certo: tocador 3D com atenuacao
		# quadratica e filtro por distancia. O corte em 900 Hz e o assunto -
		# alvenaria colonial de 60 cm deixa passar o grave e segura o agudo, e
		# sem o filtro o coro soa como se o instrumento estivesse no calcamento.
		#
		# 26 m de alcance: some antes da borda da praca e cresce conforme se
		# anda para a igreja, que e o que faz a musica ser um LUGAR e nao uma
		# trilha.
		props.append({
			"tipo": "som_ambiente",
			"pos": Vector3(vao_p.x, piso_igreja + 2.2, vao_p.y),
			"som": &"igreja_loop",
			"volume": -19.0,
			"alcance": 26.0,
			"corte_hz": 900.0,
		})
	# Velas das duas sacadas, atras do vao. Mais fracas que a da porta: sao o
	# segundo lugar de onde a luz sai, nao o primeiro.
	for sx: float in [-1.0, 1.0]:
		var sc := igreja_p + Vector2(3.10 * sx, 6.1) + desloc
		if not _neste_chunk(sc):
			continue
		indice += 1
		props.append({
			"tipo": "lampada",
			"pos": Vector3(sc.x, piso_igreja + 4.55, sc.y),
			"padrao": Lampada.Padrao.VELA,
			"semente": sem + indice * 97,
			"cor": Color("ffc07a"), "energia": 2.2, "alcance": 5.5,
			"atenuacao": 2.0, "facho": false,
		})

	var postes: Array = pl["postes"]
	for i in postes.size():
		var p0: Vector2 = centro + (postes[i] as Vector2)
		var local := p0 + desloc
		if not _neste_chunk(local):
			continue
		indice += 1
		# Sorteio fixo pelo indice, nao por RNG: dois chunks podem desenhar a
		# mesma praca e tem de concordar sobre qual lampiao esta morto.
		var padrao := Lampada.Padrao.ESTAVEL
		if i == 4:
			padrao = Lampada.Padrao.MORTA
		elif i == 1 or i == 6:
			padrao = Lampada.Padrao.SODIO_FALHANDO
		var aceso := padrao != Lampada.Padrao.MORTA
		var luz := KitParque.poste_lanterna(sup, colisao,
			Vector3(local.x, KitModular.ALTURA_MEIO_FIO, local.y), aceso)
		if aceso:
			props.append({
				"tipo": "lampada",
				"pos": luz,
				"padrao": padrao,
				"semente": sem + indice * 97,
				"cor": Color("ffc978"), "energia": 6.5, "alcance": 11.0,
				"atenuacao": 1.8, "facho": true,
			})
		# Banco perto do poste, virado para o centro.
		var para := (centro - p0).normalized()
		if para.length() < 0.1:
			continue
		var bl := p0 + para * 2.2 + desloc
		if not _neste_chunk(bl):
			continue
		KitParque.banco(sup, colisao,
			Vector3(bl.x, KitModular.ALTURA_MEIO_FIO, bl.y),
			atan2(para.x, para.y), _ale(sem, indice, 31))


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
	if int(plano["traco"]) == Traco.PRACA:
		var c_p: Vector2 = plano["centro"]
		# Praca util inteira sem arvore por cima de igreja/coreto/casas.
		saida.append(Rect2(c_p.x - 20.0, c_p.y - 18.0, 40.0, 38.0))
	if int(plano["traco"]) == Traco.PARQUINHO:
		# A areia, a faixa de grama do banco e o cerco de pedra em volta. Arvore
		# com o pe na caixa de areia e banco no meio dos brinquedos sao a mesma
		# falta: o parquinho e um lugar, e o resto do parque para na borda dele.
		saida.append(parquinho_de(plano).grow(RECUO_MIOLO + LARGURA_CAMINHO))
	if int(plano["traco"]) == Traco.LAGO:
		# O lago mais o barranco mais uma folga: arvore com o pe na agua le como
		# erro de geracao, e e exatamente o que era.
		saida.append(lago_de(plano).grow(1.5))
	if int(plano["traco"]) == Traco.CAMPO:
		saida.append(campo_de(plano).grow(RECUO_MIOLO + LARGURA_CAMINHO))
	return saida


## O ponto cai em cima de alguma placa de caminho? A folga cobre o meio raio da
## moita, entao a flor nasce ao LADO da pedra e nao com o pe nela.
static func _sobre_calcamento(faixas: Array[Rect2], p: Vector2) -> bool:
	for faixa: Rect2 in faixas:
		if faixa.size.x <= 0.0 or faixa.size.y <= 0.0:
			continue
		if faixa.grow(0.3).has_point(p):
			return true
	return false


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
