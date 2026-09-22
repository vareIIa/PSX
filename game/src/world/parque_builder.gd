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
	# Parque no alto do morro: o terraco do mirante (MiranteBuilder).
	MiranteBuilder.construir(sup, props, colisao, quadra, plano, desloc)

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
	# Por trecho: so a avenida e linha inteira (ver MalhaUrbana).
	var oeste := MalhaUrbana.recuo(MalhaUrbana.via_x_em(x0, z0))
	var leste := float(x1 - x0) * TAM - MalhaUrbana.recuo(MalhaUrbana.via_x_em(x1, z0))
	var norte := MalhaUrbana.recuo(MalhaUrbana.via_z_em(z0, x0))
	var sul := float(z1 - z0) * TAM - MalhaUrbana.recuo(MalhaUrbana.via_z_em(z1, x0))

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

	var plano := {
		"area": area,
		"traco": traco,
		"centro": area.get_center(),
		"nome": _nome_de(traco, h),
		# O parque do lago SEMPRE tem anel: e o caminho que contorna a agua, e sem
		# ele o jogador atravessa a grama porque nao ha por onde andar.
		"anel": minf(area.size.x, area.size.y) >= 62.0 or traco == Traco.LAGO,
		"semente": h,
	}
	# Parque no alto do morro com vista: o terraco do mirante e o nome dele
	# (MiranteBuilder). Vazio nos outros.
	plano["terraco"] = MiranteBuilder.terraco(quadra, plano)
	if not (plano["terraco"] as Dictionary).is_empty():
		plano["nome"] = MiranteBuilder.nome(quadra)
	return plano


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
		_cerca_com_terraco(sup, colisao, a, p1, desloc, plano, i * 2)
		_cerca_com_terraco(sup, colisao, p2, b, desloc, plano, i * 2 + 1)
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


## O trecho de cerca de `a` a `b`, aberto onde o peitoril do mirante toma o
## lugar dele (MiranteBuilder). O terraco fica inteiro numa meia borda, entre o
## canto e o portao, entao ele cabe dentro de um trecho so.
static func _cerca_com_terraco(sup: Dictionary, colisao: Array[Dictionary],
		a: Vector2, b: Vector2, desloc: Vector2, plano: Dictionary, lado: int) -> void:
	var sem := int(plano["semente"])
	var t: Dictionary = plano.get("terraco", {})
	if not t.is_empty():
		var ta: Vector2 = t["a"]
		var tb: Vector2 = t["b"]
		var eixo := (b - a).normalized()
		var normal := Vector2(-eixo.y, eixo.x)
		var na_linha := absf((ta - a).dot(normal)) < 0.01 and absf((tb - a).dot(normal)) < 0.01
		var s0 := minf((ta - a).dot(eixo), (tb - a).dot(eixo))
		var s1 := maxf((ta - a).dot(eixo), (tb - a).dot(eixo))
		if na_linha and s0 >= -0.01 and s1 <= (b - a).length() + 0.01:
			_cerca(sup, colisao, a, a + eixo * s0, desloc, sem, lado)
			_cerca(sup, colisao, a + eixo * s1, b, desloc, sem, lado + 16)
			return
	_cerca(sup, colisao, a, b, desloc, sem, lado)


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
	# A Matriz planta a mao. O espalhamento por celula nao sabe onde fica o
	# casario, e a planta antiga so protegia o miolo (40 x 38 m): as fileiras da
	# borda ficavam fora da zona proibida e arvore podia nascer dentro de casa.
	# Cada arvore e palmeira da praca tem lugar escrito em `planta_matriz`.
	if int(plano["traco"]) == Traco.PRACA:
		return
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


## Chao da Praca da Matriz: gramado na quadra inteira, e pedra so onde se anda.
##
## Inverteu. A praca era calcamento de ponta a ponta com um retalho de grama na
## frente da capela; as fotos da capela azul mostram o contrario — gramado
## extenso, e pedra no largo do cruzeiro, nas ruas do casario e no caminho da
## porta. Foi o pedido, com essas palavras.
##
## A grama cobre a quadra INTEIRA por baixo (Y_GRAMA 0,16) e a pedra vem por cima
## (Y_CALCAMENTO 0,22). Nao ha recorte, e sem recorte nao ha fresta. Foi o recorte
## que abriu buraco na versao anterior: o ladrilho com o centro dentro do terreiro
## nao era desenhado, metade dele ficava FORA da grama, e ali nao sobrava chao
## nenhum. Da vista de cima o buraco aparecia azul — era o ceu, visto pelo chao.
static func _chao_praca_matriz(sup: Dictionary, plano: Dictionary, desloc: Vector2) -> void:
	var area: Rect2 = plano["area"]
	var centro: Vector2 = plano["centro"]
	var sem := int(plano["semente"])
	KitParque.piso(sup, &"grama", _mover(area, desloc), KitParque.Y_GRAMA)

	var pl := planta_matriz(centro)
	var plataforma := Rect2((pl["plataforma"] as Rect2).position + centro,
		(pl["plataforma"] as Rect2).size)
	var pisos := pisos_da_matriz(plano)
	for f in pisos.size():
		_ladrilhar(sup, pisos[f], desloc, sem, f, plataforma)

	# A laje de placas do cruzeiro (foto 01): concreto claro em placa de 1,1 m, com
	# junta, 4 cm acima do ladrilho. O desnivel e o que separa as duas pedras sem
	# uma borda desenhada. As camadas, de baixo para cima, com um centimetro de
	# folga entre cada uma — menos que isso e briga de pixel a vinte metros:
	#   ladrilho 0,206 .. 0,234   junta 0,245   laje 0,254 .. 0,266   terra 0,28
	const LAJE := 1.1
	var lx := maxi(1, int(round(plataforma.size.x / LAJE)))
	var lz := maxi(1, int(round(plataforma.size.y / LAJE)))
	var lp := Vector2(plataforma.size.x / float(lx), plataforma.size.y / float(lz))
	for j in lz:
		for i in lx:
			var p := plataforma.position + Vector2(lp.x * float(i), lp.y * float(j))
			var placa := Rect2(p + Vector2(0.02, 0.02), lp - Vector2(0.04, 0.04))
			var chave := j * 64 + i
			var alto := KitParque.Y_CALCAMENTO + LAJE_ALTO \
				+ lerpf(-0.006, 0.006, _ale(sem, chave, 55))
			var tom := lerpf(0.52, 0.66, _ale(sem, chave, 56))
			KitParque.piso(sup, &"calcada", _mover(placa, desloc), alto,
				Color(tom, tom * 0.99, tom * 0.95))
	# A junta: por baixo das placas, um tom abaixo, no nivel do ladrilho alto.
	KitParque.piso(sup, &"calcada", _mover(plataforma, desloc),
		KitParque.Y_CALCAMENTO + 0.025, Color(0.30, 0.29, 0.27))

	# Caminho de placas de concreto do portao ate o primeiro degrau, no eixo da
	# porta (fotos 03 e 05). Vai ate o LARGO, e nao so ate o muro: parando no
	# muro sobrava uma tira de grama de 30 cm atravessada no vao do portao.
	var eixo_x: float = centro.x
	var cam_z1: float = centro.y + float(pl["adro_z"]) + 0.3
	var cam_z0: float = (pl["igreja"] as Vector2).y + 6.9
	const CAMINHO_L := 2.2
	const CAMINHO_P := 1.1
	var n_pl := maxi(1, int(round((cam_z1 - cam_z0) / CAMINHO_P)))
	var passo_pl := (cam_z1 - cam_z0) / float(n_pl)
	for i in n_pl:
		var z0_pl := cam_z0 + float(i) * passo_pl - SOBREPOSICAO
		var placa := Rect2(eixo_x - CAMINHO_L * 0.5, z0_pl,
			CAMINHO_L, passo_pl + SOBREPOSICAO * 2.0)
		var alto_pl := KitParque.Y_CALCAMENTO \
			+ lerpf(-DESNIVEL, DESNIVEL, _ale(sem, i, 57))
		var tom_pl := lerpf(0.52, 0.68, _ale(sem, i, 58))
		KitParque.piso(sup, &"calcada", _mover(placa, desloc), alto_pl,
			Color(tom_pl, tom_pl * 0.99, tom_pl * 0.96))


## Ladrilha um retangulo de pedra, placa a placa, com tom e desnivel proprios.
##
## `pular` e a laje do cruzeiro: placa inteira debaixo dela nao aparece e nao
## precisa ser desenhada. So a INTEIRA — a de beirada fica, porque e ela que
## fecha o chao na borda da laje.
static func _ladrilhar(sup: Dictionary, r: Rect2, desloc: Vector2, sem: int,
		faixa: int, pular: Rect2) -> void:
	var nx := maxi(1, int(round(r.size.x / PLACA)))
	var nz := maxi(1, int(round(r.size.y / PLACA)))
	var passo := Vector2(r.size.x / float(nx), r.size.y / float(nz))
	for j in nz:
		for i in nx:
			var p := r.position + Vector2(passo.x * float(i), passo.y * float(j))
			var placa := Rect2(p - Vector2(SOBREPOSICAO, SOBREPOSICAO),
				passo + Vector2(SOBREPOSICAO * 2.0, SOBREPOSICAO * 2.0))
			if pular.encloses(placa):
				continue
			var chave := faixa * 4096 + j * 64 + i
			var alto := KitParque.Y_CALCAMENTO \
				+ lerpf(-DESNIVEL, DESNIVEL, _ale(sem, chave, 51))
			var tom := lerpf(TOM_PEDRA_MIN, TOM_PEDRA_MAX, _ale(sem, chave, 52))
			KitParque.piso(sup, &"pedra_parque", _mover(placa, desloc), alto,
				Color(tom, tom * 0.98, tom * 0.94))


## Onde a Matriz tem pedra, em metros da quadra, ja cortado pela area dela.
##
## Publico e unico porque dois lugares desenham a mesma coisa: o chao e o mapa
## (que pede `faixas_de_caminho`). Os retangulos NAO se sobrepoem — dois
## ladrilhos coplanares de faixas diferentes brigariam pelo pixel — e se tocam
## de borda, entao nao ha grama entre eles.
const PISOS_MATRIZ: Array[Rect2] = [
	Rect2(-20.0, 4.3, 40.0, 10.7),    # o largo do cruzeiro, do muro ate z 15
	Rect2(-12.0, 15.0, 24.0, 12.0),   # a faixa sul do largo
	Rect2(-5.0, 31.0, 10.0, 11.0),    # a entrada do portao sul, entre as fileiras
	Rect2(-29.0, -41.9, 4.0, 72.9),   # rua do casario oeste
	Rect2(25.0, -41.9, 4.0, 72.9),    # rua do casario leste
	Rect2(-25.0, 27.0, 50.0, 4.0),    # rua do casario sul
	Rect2(-25.0, -41.9, 50.0, 4.7),   # rua de tras do campo santo
	Rect2(-25.0, 4.3, 5.0, 5.4),      # o largo saindo para a rua oeste
	Rect2(20.0, 4.3, 5.0, 5.4),       # e para a leste
	Rect2(-25.0, -4.2, 4.82, 2.4),    # portao lateral oeste do adro ate a rua
	Rect2(20.18, -4.2, 4.82, 2.4),    # portao lateral leste
	Rect2(-39.9, -1.3, 10.9, 2.6),    # portao oeste do gradil ate a rua
	Rect2(29.0, -1.3, 10.9, 2.6),     # portao leste do gradil
]


static func pisos_da_matriz(plano: Dictionary) -> Array[Rect2]:
	var area: Rect2 = plano["area"]
	var centro: Vector2 = plano["centro"]
	var saida: Array[Rect2] = []
	for r: Rect2 in PISOS_MATRIZ:
		var q := Rect2(r.position + centro, r.size).intersection(area)
		if q.size.x > 0.3 and q.size.y > 0.3:
			saida.append(q)
	return saida


## Os caminhos da Matriz, para o mapa: sao os proprios pisos de pedra. O mapa
## desenha o que o chao tem, e e por isso que ele bate com o chao.
static func _faixas_praca_matriz(plano: Dictionary) -> Array[Rect2]:
	return pisos_da_matriz(plano)


## Planta da Praca da Matriz, num lugar so.
##
## Existe porque a versao anterior espalhava a mesma praca por dois metodos com
## numeros magicos independentes, e o resultado previsivel foi um poste nascendo
## DENTRO da parede de uma casa. Aqui a fachada e o poste saem da mesma conta.
##
## Todas as coordenadas sao locais a quadra, em metros, a partir do centro. +Z e
## o SUL — o lado do pin de onde o jogador acorda e olha para a igreja, ao norte.
##
## Versao 2: a capela no meio de um gramado
## -----------------------------------------
## A primeira planta punha tudo em 55 x 55 m e deixava a borda de calcamento nu:
## fileiras de casas em x = +-10,5 e +-17, a trinta passos da capela, e um
## terreiro de grama de 20 x 19 m espremido entre elas. O largo que se via da
## porta da igreja tinha 21 m de largura. As fotos da capela azul mostram o
## contrario: gramado aberto em volta dela, muro baixo, e as casas LONGE.
##
## A quadra nao cresceu. A malha de ruas e da cidade, e a sessao que cuida dela
## ancorou esta quadra de proposito (o pin do acordar e a camera da abertura
## estao cravados em coordenada de mundo). O que cresceu foi a praca DENTRO dela:
## o casario foi para a borda, de frente para dentro, com uma rua de pedra de 4 m
## na frente, e o miolo inteiro virou gramado. O vao livre entre as fachadas de
## um lado e do outro passou de 21 m para 58 m.
##
##   z -42 .. -37    rua de tras do campo santo
##   z -37 .. -21    campo santo (x +-13), cabanas soltas nas quinas
##   z -19 ..  +4    o ADRO: gramado murado, capela, anexos, palmeiras
##   z  +4 .. +27    o LARGO: pedra, o cruzeiro na laje dele, bancos
##   z +27 .. +31    rua de pedra do casario sul
##   x +-25 .. +-29  ruas de pedra do casario oeste e leste
##   x +-29 .. +-35  o casario, de frente para a praca
##
## O coreto saiu. Quando o muro do adro avancou para +4,0 ele passou a cortar a
## plataforma do coreto ao meio — o defeito que o usuario viu, "atravessando
## paredes" — e a referencia nao tem coreto: o marco dela e o cruzeiro.
static func planta_matriz(centro_q: Vector2) -> Dictionary:
	# Igreja recuada para o fundo. A massa e a posicao estao aferidas contra o
	# enquadramento do pin (o teto do quadro em 270,-40 esta em ~10,25 m no plano
	# da fachada) e contra o CHECKPOINT de captures/praca_matriz/aaa_detalhe.
	var igreja := centro_q + Vector2(0.0, -8.0)

	# O casario da borda. Oeste e leste de frente para dentro, em tres trechos com
	# beco entre eles; o beco do meio (z -1,5 .. 2,5) cai no portao oeste do
	# gradil. O sul abre no eixo para o portao sul.
	#
	# Casa nasce PARA TRAS da linha de fachada (CASA_FUNDURA = 5,6): as de oeste
	# ocupam de -29 a -34,6, e sobram 5,3 m de quintal ate o gradil da quadra.
	var fileiras: Array[Dictionary] = [
		{"de": Vector2(-29.0, -36.5), "ate": Vector2(-29.0, -20.0), "giro": PI * 0.5, "s": 331},
		{"de": Vector2(-29.0, -16.0), "ate": Vector2(-29.0, -1.5), "giro": PI * 0.5, "s": 367},
		{"de": Vector2(-29.0, 2.5), "ate": Vector2(-29.0, 26.0), "giro": PI * 0.5, "s": 401},
		{"de": Vector2(29.0, -36.5), "ate": Vector2(29.0, -20.0), "giro": -PI * 0.5, "s": 433},
		{"de": Vector2(29.0, -16.0), "ate": Vector2(29.0, -1.5), "giro": -PI * 0.5, "s": 467},
		{"de": Vector2(29.0, 2.5), "ate": Vector2(29.0, 26.0), "giro": -PI * 0.5, "s": 503},
		{"de": Vector2(-27.0, 31.0), "ate": Vector2(-17.0, 31.0), "giro": PI, "s": 101},
		{"de": Vector2(-15.0, 31.0), "ate": Vector2(-5.0, 31.0), "giro": PI, "s": 137},
		{"de": Vector2(5.0, 31.0), "ate": Vector2(15.0, 31.0), "giro": PI, "s": 173},
		{"de": Vector2(17.0, 31.0), "ate": Vector2(27.0, 31.0), "giro": PI, "s": 211},
	]

	# Fileiras com morador na casa do MEIO: sul-oeste de dentro, sul-leste de
	# dentro e o trecho sul do leste.
	#
	# Escolhidas pela linha reta da porta ate cada ponto de `rota_da_praca`,
	# porque o Convidado anda em linha reta. Da porta de uma casa do oeste o
	# caminho ate o largo passava por dentro do canteiro do cruzeiro.
	var moradores: Array[int] = [7, 8, 5]

	# Cabanas soltas, fora de esquadro de proposito: numa praca colonial tudo se
	# alinha a rua, e a casa torta e a primeira coisa que diz que aqui a rua nao
	# mandou em nada. Duas nas quinas de tras do campo santo, olhando as ruas, e
	# duas nas quinas do sul, atras das fileiras.
	var soltas: Array[Dictionary] = [
		{"pos": Vector2(-19.5, -30.0), "giro": -PI * 0.5 + 0.12, "larg": 6.0},
		{"pos": Vector2(19.5, -30.0), "giro": PI * 0.5 - 0.14, "larg": 6.4},
		{"pos": Vector2(-33.5, 36.0), "giro": PI * 0.5 + 0.18, "larg": 5.4},
		{"pos": Vector2(33.5, 36.0), "giro": -PI * 0.5 - 0.16, "larg": 5.8},
	]

	# Os dois anexos da capela (fotos 03 e 05), de frente para o sul. O grande
	# fica a 1,1 m da sacristia e 0,3 m do muro leste, o pequeno a 3,5 m do muro
	# oeste, ao lado do portaozinho azul — que e onde a foto 05 o mostra.
	var anexos: Array[Dictionary] = [
		{"pos": Vector2(-14.0, -4.0), "giro": 0.0, "larg": 5.0, "s": 601},
		{"pos": Vector2(15.5, -10.0), "giro": 0.0, "larg": 7.0, "s": 619},
	]

	# Palmeiras-imperiais: tres atras da capela, como nas tres fotos, e uma em
	# cada faixa de grama de fora do muro. [x, z, altura do fuste].
	var palmeiras: Array[Vector3] = [
		Vector3(-12.5, -16.5, 13.5), Vector3(12.0, -17.0, 12.0),
		Vector3(-2.5, -18.8, 14.5), Vector3(-22.8, -14.5, 11.0),
		Vector3(22.8, 11.0, 12.5),
	]

	# Arvores de copa larga, poucas e escolhidas: nas quinas, nas faixas de fora
	# do muro e nos quintais. Cada uma conferida contra a casa, o muro e a rua
	# mais proximos — nenhuma passa de 2 m de algum deles.
	var arvores: Array[Vector2] = [
		Vector2(-16.0, -24.0), Vector2(16.0, -24.5),
		Vector2(-23.0, 19.0), Vector2(23.0, -9.0),
		Vector2(-37.5, -8.0), Vector2(37.5, 10.0),
		Vector2(-37.5, 17.0), Vector2(37.5, -24.0),
		Vector2(-34.5, -39.5), Vector2(34.5, -39.5),
		Vector2(-10.0, 39.3), Vector2(10.0, 39.3),
	]

	# Moitas no gramado do adro: ao lado do caminho (foto 03, em primeiro plano),
	# nos cantos do muro e junto dos anexos.
	var arbustos: Array[Vector2] = [
		Vector2(-2.7, 2.9), Vector2(2.7, 2.9),
		Vector2(-18.4, 1.6), Vector2(18.4, 1.8),
		Vector2(-17.8, -12.0), Vector2(17.6, -15.5),
		Vector2(7.6, -0.9), Vector2(-7.8, -0.6),
	]

	# Postes de lanterna. O de indice 4, perto do pin, e o MORTO — o mesmo papel
	# do (-7 , 12,5) antigo: a luz em volta do corpo na abertura foi afinada com
	# um lampiao apagado ali, e trocar isso muda a cena de outra sessao.
	var postes: Array[Vector2] = [
		Vector2(13.5, 6.0), Vector2(-16.0, 7.0), Vector2(7.0, 12.5),
		Vector2(12.5, 21.5), Vector2(-8.5, 14.5), Vector2(-12.5, 21.5),
		Vector2(-25.4, -12.0), Vector2(25.4, 16.0),
	]

	# Bancos com lugar escrito, e nao "a 2,2 m do poste virado para o centro":
	# aquela regra plantava banco no meio do caminho de quem anda pelo largo. Dois
	# encostados no muro do adro olhando a praca, dois na faixa sul olhando a
	# capela, e dois DENTRO do adro, na grama, virados para ela.
	# Quem senta olha para onde `giro` leva o +Z local — `atan2(x, z)` do rumo
	# do olhar —, e o encosto fica do lado oposto. O comentario de
	# `KitParque.banco` dizia -Z, o codigo sempre fez +Z, e a primeira versao
	# desta lista seguiu o comentario: os bancos do muro olhavam para o muro.
	var bancos: Array[Dictionary] = [
		{"pos": Vector2(5.5, 5.1), "giro": 0.0},
		{"pos": Vector2(10.5, 5.1), "giro": 0.0},
		{"pos": Vector2(11.2, 22.5), "giro": PI},
		{"pos": Vector2(-11.2, 22.5), "giro": PI},
		{"pos": Vector2(-12.0, 1.9), "giro": 2.261},
		{"pos": Vector2(12.5, 0.8), "giro": -2.184},
	]

	# O CRUZEIRO, fora do muro, no largo, a oeste do eixo — onde a foto 01 o
	# mostra: sobre a laje de placas, com o canteiro cercado ao lado e a capela ao
	# fundo, a direita.
	#
	# A posicao foi medida contra as cameras da abertura, que nao sao desta task:
	#   TAKE 3 (lente a 1,10 m, olhando nordeste): o cruzeiro e tudo que e dele
	#   ficam a oeste de x = -5,5, fora do quadro.
	#   TAKE 5 (a revelacao, de (-2,5 , 16,1)): o mastro entra a 31 graus do
	#   centro, com o braco esquerdo dentro do quadro por 0,5 grau — e a
	#   composicao da foto 02, o cruzeiro grande na esquerda e a capela atras.
	# Pedestal de z 5,4 a 7,8: 1,2 m livres ate a face do muro.
	var cruzeiro := Vector2(-7.0, 6.6)

	return {
		"igreja": igreja,
		# Muro do adro: frente em +4,0, 40 m de largura, fundo em -19,0, e um
		# portao lateral de cada lado em z -3,0.
		"adro_z": 4.0,
		"adro_larg": 40.0,
		"adro_fundo": -19.0,
		"portao_lateral_z": -3.0,
		"cruzeiro": cruzeiro,
		# A laje de placas debaixo do cruzeiro e do canteiro dele.
		"plataforma": Rect2(-13.4, 4.5, 8.8, 6.6),
		"canteiro_cruzeiro": Rect2(-12.8, 5.0, 3.2, 5.2),
		"tocos": [Vector2(-12.2, 11.4), Vector2(-10.8, 11.6), Vector2(-9.4, 11.4)],
		"cruz_branca": Vector2(-9.5, 0.6),
		"santo_z": -29.0,
		"fileiras": fileiras,
		"moradores": moradores,
		"soltas": soltas,
		"anexos": anexos,
		"palmeiras": palmeiras,
		"arvores": arvores,
		"arbustos": arbustos,
		"postes": postes,
		"bancos": bancos,
	}


## Quanto a laje de placas do cruzeiro fica acima do ladrilho. Ver o chao.
const LAJE_ALTO := 0.04


## Layout da Praca da Matriz. Tudo sai de `planta_matriz`.
##
## Cada peca e ancorada num ponto so, e o chunk que contem esse ponto desenha a
## peca INTEIRA, mesmo a parte que cai no vizinho. E a mesma regra do cruzamento:
## meia fileira desenhada de cada lado nao concorda sobre onde comeca o modulo, e
## a junta abre.
static func _praca_matriz(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], plano: Dictionary, desloc: Vector2) -> void:
	var centro_q: Vector2 = plano["centro"]
	var sem := int(plano["semente"])
	var area: Rect2 = plano["area"]
	var y := KitParque.Y_CALCAMENTO
	var yg := KitParque.Y_GRAMA
	var pl := planta_matriz(centro_q)

	# --- a capela e o muro da frente ----------------------------------------
	var igreja: Vector2 = pl["igreja"] + desloc
	if _neste_chunk(igreja):
		KitParque.igreja_matriz(sup, colisao, Vector3(igreja.x, y, igreja.y), 0.0)
		# O muro da frente sai do MESMO ponto de ancoragem da igreja, e nao de um
		# `_neste_chunk` proprio: ele tem quarenta metros e atravessa fronteira de
		# chunk, e os dois lados do portao tem de concordar sobre onde o vao esta.
		var adro_p := Vector2(centro_q.x, centro_q.y + float(pl["adro_z"])) + desloc
		var nichos := KitParque.adro_capela(sup, colisao,
			Vector3(adro_p.x, y, adro_p.y), float(pl["adro_larg"]), 0.0)
		# A vela de cada nicho do portao. Fraca e curta: e a luz que se ve do pin
		# entre a pedra e a porta, e nao pode acender a praca.
		for k in nichos.size():
			props.append({
				"tipo": "lampada",
				"pos": nichos[k],
				"padrao": Lampada.Padrao.VELA,
				"semente": sem + 877 + k * 31,
				"cor": Color("ffb46a"), "energia": 1.4, "alcance": 3.6,
				"atenuacao": 2.0, "facho": false,
			})

	# --- os muros laterais do adro, com o gradil azul (foto 05) --------------
	#
	# Cada muro com ancora propria, no meio dele: sao 23 m cada, e desenhados pelo
	# chunk da igreja eles empilhariam dois gradis de cem barras no chunk que ja e
	# o mais caro da cidade. As pontas saem so da planta, entao os dois lados do
	# portao lateral concordam sem se falar.
	#
	# O muro lateral COMECA na face da frente do muro do adro (z 4,18) e e mais
	# alto que ele: a ponta do muro da frente fica escondida dentro dele, e a
	# quina fecha sem duas faces no mesmo plano.
	var z_frente: float = centro_q.y + float(pl["adro_z"]) + KitParque.MURO_E * 0.5
	var z_fundo: float = centro_q.y + float(pl["adro_fundo"])
	var z_portao: float = centro_q.y + float(pl["portao_lateral_z"])
	const MEIA_PORTAO := 0.9
	for sx: float in [-1.0, 1.0]:
		var x: float = centro_q.x + float(pl["adro_larg"]) * 0.5 * sx
		var meio_muro := Vector2(x, (z_frente + z_fundo) * 0.5) + desloc
		if not _neste_chunk(meio_muro):
			continue
		var xl := x + desloc.x
		KitParque.muro_caiado(sup, colisao,
			Vector3(xl, yg, z_frente + desloc.y),
			Vector3(xl, yg, z_portao + MEIA_PORTAO + 0.23 + desloc.y), 1.05, true)
		KitParque.muro_caiado(sup, colisao,
			Vector3(xl, yg, z_portao - MEIA_PORTAO - 0.23 + desloc.y),
			Vector3(xl, yg, z_fundo + desloc.y), 1.05, true)
		# O portao abre para DENTRO do adro nos dois lados: giro -PI/2 no oeste e
		# +PI/2 no leste poe o `frente` dele para fora e a folha na grama.
		KitParque.portao_lateral(sup, colisao,
			Vector3(xl, yg, z_portao + desloc.y), PI * 0.5 * sx, MEIA_PORTAO)

	# --- anexos, palmeiras, a cruz branca e as moitas do adro -----------------
	for i in (pl["anexos"] as Array).size():
		var an: Dictionary = pl["anexos"][i]
		var ap: Vector2 = centro_q + (an["pos"] as Vector2) + desloc
		if not _neste_chunk(ap):
			continue
		var ac := Vector3(ap.x, y, ap.y)
		var ag := float(an["giro"])
		var al := float(an["larg"])
		var aseed := sem + int(an["s"])
		KitParque.anexo_capela(sup, colisao, ac, ag, al, aseed)
		# O lampiao da porta do anexo acende de verdade. E a luz mais baixa e mais
		# quente do adro, e e o que diz que alguem mora ali — o sacristao.
		props.append({
			"tipo": "lampada",
			"pos": KitParque.lampiao_do_modulo(ac, ag, al, aseed)
				+ Vector3(sin(ag), 0.0, cos(ag)) * 0.25,
			"padrao": Lampada.Padrao.ESTAVEL,
			"semente": sem + 911 + i * 37,
			"cor": Color("ffc27a"), "energia": 2.4, "alcance": 6.0,
			"atenuacao": 1.9, "facho": false,
		})

	for i in (pl["palmeiras"] as Array).size():
		var pv: Vector3 = pl["palmeiras"][i]
		var pp: Vector2 = centro_q + Vector2(pv.x, pv.y) + desloc
		if not _neste_chunk(pp):
			continue
		KitParque.palmeira(sup, colisao, Vector3(pp.x, yg, pp.y), pv.z,
			_gerador(sem, i, 231))

	var cb: Vector2 = centro_q + (pl["cruz_branca"] as Vector2) + desloc
	if _neste_chunk(cb):
		KitParque.cruz_branca(sup, colisao, Vector3(cb.x, yg, cb.y), 3.4, 0.08)

	for i in (pl["arbustos"] as Array).size():
		var bp: Vector2 = centro_q + (pl["arbustos"][i] as Vector2) + desloc
		if not _neste_chunk(bp):
			continue
		KitParque.arbusto(sup, Vector3(bp.x, yg, bp.y),
			lerpf(0.7, 1.1, _ale(sem, i, 241)), _gerador(sem, i, 242))

	# --- o cruzeiro no largo ---------------------------------------------------
	#
	# Ancoragem PROPRIA: ele fica a 7 m do eixo e 14 m ao sul da igreja, e nesta
	# quadra isso cai em outro chunk.
	var cruz_p: Vector2 = centro_q + (pl["cruzeiro"] as Vector2) + desloc
	if _neste_chunk(cruz_p):
		KitParque.cruzeiro(sup, colisao,
			Vector3(cruz_p.x, y + LAJE_ALTO, cruz_p.y), 0.0)
		# O canteiro cercado ao lado dele (foto 01): murete, terra, arbusto, e o
		# guarda-corpo de tora nos dois lados que dao para o cruzeiro — em L, sem
		# fechar o quadrado, porque as duas fotos mostram o pedestal acessivel.
		var ct: Rect2 = pl["canteiro_cruzeiro"]
		var cr := Rect2(ct.position + centro_q + desloc, ct.size)
		KitParque.canteiro(sup, colisao, cr, sem + 811)
		KitParque.guarda_corpo_rustico(sup, colisao,
			Vector3(cr.end.x + 0.3, y, cr.position.y),
			Vector3(cr.end.x + 0.3, y, cr.end.y))
		KitParque.guarda_corpo_rustico(sup, colisao,
			Vector3(cr.position.x, y, cr.end.y + 0.3),
			Vector3(cr.end.x + 0.3, y, cr.end.y + 0.3))
		for k in (pl["tocos"] as Array).size():
			var tp: Vector2 = centro_q + (pl["tocos"][k] as Vector2) + desloc
			KitParque.toco(sup, colisao, Vector3(tp.x, y, tp.y),
				lerpf(0.55, 0.8, _ale(sem, k, 251)), _ale(sem, k, 252) * PI)

	# --- gente na praca -------------------------------------------------------
	#
	# `Convidado` com `Papel.LIVRE` circula por uma lista de pontos, para, encosta
	# em alguem, conversa e volta. Quatro pessoas, e nao dez: o teto de
	# `Multidao` e catorze para a cidade INTEIRA.
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
			"idade_min": 19, "idade_max": 68,
		})

	# --- o campo santo, atras da capela ---------------------------------------
	#
	# Recuou de -25 para -29: o adro agora vai ate -19, e a palmeira de tras da
	# capela precisa de chao entre a nave e o muro do cemiterio.
	var santo_c := Vector2(centro_q.x, centro_q.y + float(pl["santo_z"]))
	var santo_t := Vector2(26.0, 15.0)
	var folga := 5.0
	santo_t.x = minf(santo_t.x, area.size.x - folga * 2.0)
	santo_t.y = minf(santo_t.y, (santo_c.y - area.position.y - folga) * 2.0)
	if santo_t.x >= 12.0 and santo_t.y >= 9.0:
		santo_c.y = maxf(santo_c.y, area.position.y + folga + santo_t.y * 0.5)
		var sl := santo_c + desloc
		if _neste_chunk(sl):
			KitParque.campo_santo(sup, colisao, Vector3(sl.x, yg, sl.y),
				santo_t, 0.0, sem + 613)

	for i in (pl["arvores"] as Array).size():
		var ap: Vector2 = centro_q + (pl["arvores"][i] as Vector2)
		if not area.has_point(ap):
			continue
		var al := ap + desloc
		if not _neste_chunk(al):
			continue
		KitParque.arvore(sup, colisao, Vector3(al.x, yg, al.y),
			lerpf(0.55, 1.0, _ale(sem, i, 211)), _gerador(sem, i, 212),
			_ale(sem, i, 213) < 0.3)

	# --- o casario ------------------------------------------------------------
	var moradores: Array = pl["moradores"]
	for fi in (pl["fileiras"] as Array).size():
		var f: Dictionary = pl["fileiras"][fi]
		var de: Vector2 = centro_q + (f["de"] as Vector2) + desloc
		var ate: Vector2 = centro_q + (f["ate"] as Vector2) + desloc
		if not _neste_chunk((de + ate) * 0.5):
			continue
		var de3 := Vector3(de.x, y, de.y)
		var ate3 := Vector3(ate.x, y, ate.y)
		var gf := float(f["giro"])
		var sf := sem + int(f["s"])
		var modulos := KitParque.modulos_da_fileira(de3, ate3, gf, sf)
		# A casa do morador tem a porta entreaberta com luz dentro: e por ela que
		# ele some, e o jogador que o viu entrar volta e acha a porta como ele
		# deixou. O resto do sorteio fica como esta.
		var forcas := {}
		var meio := int(modulos.size() / 2.0)
		if moradores.has(fi) and not modulos.is_empty():
			forcas[meio] = {"tapada": false, "acesa": true, "entreaberta": true,
				"alpendre": false}
		KitParque.fileira_colonial(sup, colisao, de3, ate3, gf, sf, forcas)
		for m: Dictionary in modulos:
			_fumaca_da_chamine(props, m["centro"], gf, float(m["largura"]),
				int(m["semente"]))
		if not moradores.has(fi) or modulos.is_empty():
			continue
		var mm: Dictionary = modulos[meio]
		var soleira := KitParque.soleira_do_modulo(mm["centro"], gf,
			float(mm["largura"]), int(mm["semente"]))
		soleira.y = KitModular.ALTURA_MEIO_FIO
		props.append({
			"tipo": "morador",
			"pos": soleira,
			"soleira": soleira,
			"giro": gf,
			"giro_da_casa": gf,
			"semente": sem + 709 + fi * 211,
			"pontos": rota,
			"papel": Convidado.Papel.LIVRE,
			"idade_min": 24, "idade_max": 72,
		})

	for i in (pl["soltas"] as Array).size():
		var c: Dictionary = pl["soltas"][i]
		var p: Vector2 = centro_q + (c["pos"] as Vector2) + desloc
		if not _neste_chunk(p):
			continue
		var s_casa := sem + int(p.x * 3.0)
		var cc := Vector3(p.x, y, p.y)
		KitParque.casa_colonial_baixa(sup, colisao, cc, float(c["giro"]),
			float(c["larg"]), s_casa)
		_fumaca_da_chamine(props, cc, float(c["giro"]), float(c["larg"]), s_casa)


## Fumaca na chamine, so de casa acesa: fogao aceso as onze da noite e casa com
## gente. Casa apagada com fumaca subindo seria outra historia, e nao e esta.
##
## `NUVEM` e o tufo largo e lento da `FumacaParticulas`; doze particulas por
## chamine, e poucas chamines passam no filtro (um terco tem chamine, tres em
## dez estao acesas).
static func _fumaca_da_chamine(props: Array[Dictionary], centro: Vector3,
		giro: float, largura: float, semente: int) -> void:
	if not bool(KitParque.sorteio_da_casa(semente)["acesa"]):
		return
	var topo := KitParque.chamine_de(centro, giro, largura, semente)
	if topo == Vector3.INF:
		return
	props.append({"tipo": "fumaca", "pos": topo + Vector3(0.0, 0.15, 0.0),
		"fumaca": FumacaParticulas.Tipo.NUVEM})


## Por onde a gente da praca anda, em coordenada LOCAL do chunk.
##
## Publica e unica porque DOIS chamadores precisam da mesma lista: quem semeia os
## andantes e quem semeia os moradores na porta das casas. Com a lista escrita
## nos dois, o morador sairia de casa para um anel que os vizinhos nao usam.
##
## O Convidado vai de um ponto a OUTRO QUALQUER da lista em linha reta. Entao a
## regra nao e "cada ponto num lugar livre", e sim "cada SEGMENTO entre dois
## pontos livre" — e cada um destes foi conferido contra o cruzeiro e o canteiro
## dele (tudo a oeste de x = -4,6), os postes, e os bancos, que agora tem lugar
## escrito e ficam fora dos cruzamentos. Ninguem entra no adro: do portao para
## dentro e chao da capela.
##
## Nenhum ponto fica a menos de 6,5 m do PIN DO ACORDAR, em (-0,9 , +11,1): as
## cameras da abertura ficam entre 2,35 e 5 m do corpo caido, e alguem parado
## ali entra no quadro de quase todos os takes. Isso e decisao de roteiro, e
## nao e desta task.
static func rota_da_praca(centro_q: Vector2, desloc: Vector2) -> Array[Vector3]:
	const ANDANTES: Array[Vector2] = [
		Vector2(0.0, 4.6), Vector2(9.0, 8.0), Vector2(16.0, 13.0),
		Vector2(3.0, 17.0), Vector2(-2.0, 25.0), Vector2(8.0, 27.0),
		Vector2(-9.0, 25.0), Vector2(20.0, 14.0),
	]
	var saida: Array[Vector3] = []
	for a: Vector2 in ANDANTES:
		var ap: Vector2 = centro_q + a + desloc
		saida.append(Vector3(ap.x, KitModular.ALTURA_MEIO_FIO, ap.y))
	return saida


## Luzes, bancos e o sino da Praca da Matriz.
##
## Nem todo poste acende. Uma praca colonial as onze e quinze da noite com oito
## lampioes igualmente firmes le como cenario bem iluminado; com um morto e dois
## falhando, o anel de luz ganha um buraco e o jogador olha para o buraco. E a
## tensao mais barata que existe aqui, e ja estava pronta em `Lampada.Padrao`.
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
	# Velas e um harmonio. Nenhuma das coisas mostra o interior da igreja, e e
	# esse o ponto: o jogador ve luz saindo por vaos e ouve um som que atravessa
	# parede. O lugar fica habitado sem custar um comodo.
	var piso_igreja := KitParque.Y_CALCAMENTO + KitParque.IGREJA_PLINTO
	# Vela do vao da porta, 0,9 m A FRENTE da fachada. Dentro da nave ela acendia
	# as costas dos vertices da fachada (N.L negativo) e mais nada.
	var vao_p := igreja_p + Vector2(0.0, 6.9) + desloc
	if _neste_chunk(vao_p):
		indice += 1
		props.append({
			"tipo": "lampada",
			"pos": Vector3(vao_p.x, piso_igreja + 1.6, vao_p.y),
			"padrao": Lampada.Padrao.VELA,
			"semente": sem + indice * 97,
			"cor": Color("ffb46a"), "energia": 3.4, "alcance": 7.0,
			"atenuacao": 1.9, "facho": false,
		})
		# O harmonio. Alvenaria colonial de 60 cm deixa passar o grave e segura o
		# agudo; sem o corte em 900 Hz o coro soa como se estivesse no calcamento.
		props.append({
			"tipo": "som_ambiente",
			"pos": Vector3(vao_p.x, piso_igreja + 2.2, vao_p.y),
			"som": &"igreja_loop",
			"volume": -19.0,
			"alcance": 26.0,
			"corte_hz": 900.0,
		})
	# Velas das duas sacadas, atras do vao.
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
	# Velas das janelas laterais acesas. E a luz que o jogador ve do gramado
	# quando da a volta na capela: um retangulo quente na parede e um halo na
	# grama embaixo dele.
	var base_igreja := Vector3(igreja_p.x + desloc.x, KitParque.Y_CALCAMENTO,
		igreja_p.y + desloc.y)
	for v: Vector3 in KitParque.velas_da_igreja(base_igreja, 0.0):
		if not _neste_chunk(Vector2(v.x, v.z)):
			continue
		indice += 1
		props.append({
			"tipo": "lampada",
			"pos": v,
			"padrao": Lampada.Padrao.VELA,
			"semente": sem + indice * 97,
			"cor": Color("ffc07a"), "energia": 1.8, "alcance": 5.0,
			"atenuacao": 2.0, "facho": false,
		})

	# O sino da sineira, que toca a hora cheia. Mora no vao do campanario: a
	# torre esta a 6,8 m a oeste e 4,4 m atras do centro da nave, e o sino a 13,9
	# m acima do plinto (ver `igreja_matriz`).
	var sino := igreja_p + Vector2(-6.8, -4.4) + desloc
	if _neste_chunk(sino):
		props.append({
			"tipo": "sino",
			"pos": Vector3(sino.x, piso_igreja + 13.9, sino.y),
			"som": &"sino_igreja",
		})

	var postes: Array = pl["postes"]
	for i in postes.size():
		var local: Vector2 = centro + (postes[i] as Vector2) + desloc
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

	var bancos: Array = pl["bancos"]
	for i in bancos.size():
		var b: Dictionary = bancos[i]
		var bl: Vector2 = centro + (b["pos"] as Vector2) + desloc
		if not _neste_chunk(bl):
			continue
		KitParque.banco(sup, colisao,
			Vector3(bl.x, KitModular.ALTURA_MEIO_FIO, bl.y), float(b["giro"]),
			_ale(sem, i, 31))


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
	# O terraco do mirante e uma folga: nada de copa por cima do peitoril nem
	# banco de costas para a vista na frente dele.
	var terraco: Dictionary = plano.get("terraco", {})
	if not terraco.is_empty():
		saida.append((terraco["rect"] as Rect2).grow(folga + 0.8))
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
