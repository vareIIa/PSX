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
	Traco.PRACA: 0.30,
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
	Traco.PRACA: ["PRACA HIGASHI", "PRACA DA ESTACAO", "PRACA DO CANAL"],
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

	_chao(sup, plano, desloc)
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

static func _chao(sup: Dictionary, plano: Dictionary, desloc: Vector2) -> void:
	var area: Rect2 = plano["area"]
	var sem := int(plano["semente"])
	# A grama sai em retalhos em volta do lago, e nao num plano so: o plano
	# inteiro passaria por baixo da agua e apareceria como um tapete verde no
	# fundo do lago, dois centimetros acima do barranco.
	for pedaco: Rect2 in _grama_de(plano):
		KitParque.piso(sup, &"grama", _mover(pedaco, desloc), KitParque.Y_GRAMA)

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
	var saida: Array[Rect2] = []
	var traco := int(plano["traco"])
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


## Canteiros de flor. Ficam colados no caminho, que e onde o jogador passa: um
## canteiro no meio do gramado e uma mancha de cor que ninguem chega perto.
const CELULAS_FLOR: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	Vector2i(6, 0), Vector2i(7, 0),
]

static func _canteiros(sup: Dictionary, plano: Dictionary, desloc: Vector2) -> void:
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
