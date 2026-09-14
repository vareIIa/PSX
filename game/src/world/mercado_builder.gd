## Loja de conveniencia. Mesmo contrato do CasaBuilder e do InteriorBuilder:
## dados puros, montados na thread enquanto a porta abre.
##
## O ponto da loja nao e ter mais movel que a casa, e ser o contrario dela em
## tudo que o jogador sente. A casa e quente, baixa, apertada e escura nos
## cantos. A loja e branca, alta, larga e sem uma sombra em lugar nenhum. Depois
## de vinte minutos de nevoa cinza e poste de sodio, entrar aqui e agressivo: a
## luz machuca, o piso brilha, tudo esta arrumado, e nao ha ninguem.
##
## Uma loja aberta as tres da manha sem uma pessoa dentro assusta mais que um
## porao, e assusta sem precisar de nada acontecer. E o unico comodo do jogo em
## que a luz e o problema.
##
##
## O lado de dentro da loja
## ------------------------
## O salao e metade do lugar. A outra metade e o BLOCO DE SERVICO, atras da
## parede do caixa: garagem, corredor, banheiro e copa dos funcionarios. Ele
## existe por uma razao que nao e "ter mais comodo".
##
## Uma loja de conveniencia so tem duas caras. A de fora, que e vitrine acesa e
## letreiro, e feita para atrair; e a de dentro, que e papelao, balde de mop e
## uma escala de turno pregada na cortica, e nao foi feita para ninguem ver. O
## salao sozinho conta so a primeira, e por isso ele le como cenario por mais
## bem montado que esteja. Atravessar UMA porta e cair na segunda e o que faz o
## jogador entender que aquele lugar e o emprego de alguem.
##
## Por isso a paleta vira de lado na travessia: branco chapado de um lado, verde
## de reparticao e concreto do outro. E a mesma virada que separa o palco da
## coxia, e ela nao custa mecanica nenhuma.
##
## Planta, em metros, origem no canto sul-oeste. A rua fica em z=0, e e para ela
## que dao TANTO a porta automatica do salao QUANTO o portao da garagem — sao
## duas bocas na mesma calcada, uma do lado da outra.
##
##   z=13.0 +----------+---+---------+--------------------------------------+
##          | BANHEIRO |   |  COPA   |          CAMARA FRIA (7 portas)      |
##          |          |   |         +--------------------------------------+
##    z=8.1 +--[porta]-+---+-[porta]-+  |         |         |         |     |
##          |        CORREDOR        |  | I L H A S   D E   P R A T E |  g  |
##    z=5.9 +--------[  vao  ]-------+  |         |         |         |  o  |
##          |                        |B |         |         |         |  n  |
##          |                        |A +---------+---------+---------+  d  |
##          |        GARAGEM         |L                                     |
##          |                        |C                                     |
##      z=0 +--------[PORTAO]--------+A0---[porta automatica]---[revistas]---+
##         x=0                     x=6.6                                 x=19.0
##
## O caixa fica encostado na parede que separa as duas metades (x=6,6), e a
## porta de servico se abre no fim dele — que e onde toda loja poe a porta dos
## fundos, e o que faz "atras do caixa" ser um lugar de verdade e nao uma seta.
class_name MercadoBuilder
extends RefCounted

# --- casca ------------------------------------------------------------------

## Largura total do conjunto: bloco de servico mais salao.
const LARGURA := 19.0
const FUNDO := 13.0

## Onde a parede que separa o salao do bloco de servico corre, em X.
const DIVISA := 6.6

## Pe direito de loja, mais alto que o de casa. E parte do desconforto: o comodo
## e grande demais para uma pessoa so.
const ALTURA := 2.9
## Forro rebaixado dos fundos. Vinte centimetros a menos que o salao, e sao eles
## que fazem o corredor apertar depois da largura do salao — a mesma diferenca
## que existe entre a loja e a copa de qualquer loja.
const ALTURA_SERVICO := 2.68
## A garagem e o comodo mais alto do conjunto, para caber o portao enrolado.
const ALTURA_GARAGEM := KitMercado.ALTURA_GARAGEM
const ALTURA_PORTA := 2.3

## Vao da porta automatica, na parede sul do salao.
const PORTA_X0 := 11.8
const PORTA_X1 := 13.8
const CENTRO_SALAO := (PORTA_X0 + PORTA_X1) * 0.5

## Onde o jogador aparece, e para onde olha. Entra de frente para o corredor
## central, com a camara fria acesa no fundo: e o quadro que a loja existe para
## dar, e o que puxa o jogador para dentro.
const ENTRADA := Vector3(CENTRO_SALAO, 0.0, 1.25)
const OLHAR := Vector3(CENTRO_SALAO, 1.55, 9.5)

const PAREDE := Color("e2e2dc")
const RODAPE := 0.12

## Onde ficam as tres ilhas de prateleira, em X, e ate onde elas correm em Z.
##
## Nenhuma delas fica sobre CENTRO_SALAO, e isso e a coisa mais importante desta
## linha. Quem entra pela porta automatica cai no eixo do salao, e o que ele tem
## de ver la no fim e a camara fria acesa — nao a lateral de uma gondola a tres
## metros do nariz. As duas primeiras ilhas abracam o eixo, entao o corredor
## central e literalmente central.
##
## A oeste da primeira sobra o vao da frente do caixa, que e onde a fila se
## forma e por onde todo mundo entra. Uma quarta ilha caberia ali em metros e
## fecharia justamente esse vao.
const ILHAS: Array[float] = [11.55, 14.05, 16.55]
const ILHA_Z0 := 4.4
const ILHA_Z1 := 10.4

# --- bloco de servico -------------------------------------------------------

## Garagem: da rua ate o corredor.
const GARAGEM_Z1 := 5.9
## Corredor: a faixa que liga tudo. Atravessa o bloco inteiro de leste a oeste.
const CORREDOR_Z0 := GARAGEM_Z1
const CORREDOR_Z1 := 8.1

## Banheiro e copa dividem o fundo do bloco, com a mesma largura util e a mesma
## folga em volta. Simetria de verdade, e nao "mais ou menos igual": as duas
## portas ficam a mesma distancia do eixo do portao, que passa em DIVISA/2.
const BANHEIRO_X1 := 3.1
const COPA_X0 := 3.5
const EIXO_SERVICO := DIVISA * 0.5

## Portas do fundo, centradas nos dois comodos.
const PORTA_BANHEIRO := 1.55
const PORTA_COPA := 5.05
const LARGURA_PORTA_INTERNA := 0.9

## Porta de servico, na parede do caixa. Fica no fim do balcao, que e onde toda
## loja poe a porta dos fundos.
const PORTA_SERVICO_Z := 6.6

## Vao aberto entre corredor e garagem. Nao leva folha de proposito: e o caminho
## que o funcionario faz vinte vezes por turno com as maos ocupadas.
const VAO_GARAGEM_X := EIXO_SERVICO
const VAO_GARAGEM_L := 1.4

## Balcao do caixa: encostado na divisa, correndo no eixo Z.
##
## A faixa entre ele e a parede do caixa e o lugar de trabalho de uma pessoa, e
## precisa ter largura de gente: com o balcao encostado demais na divisa sobrava
## menos de um metro e o atendente nao passava por tras da propria registradora.
## A medida de caminhabilidade do TesteMercado e quem pegou isso.
const BALCAO_X := 8.15
const BALCAO_Z := 3.9
const BALCAO_COMPRIMENTO := 4.4

## O sal da semente do CLIENTE, o que esta do lado de fora do balcao.
##
## Mora aqui em cima, sozinho, porque dois lugares diferentes precisam chegar na
## mesma pessoa a partir dele: `_gente`, que poe o corpo dela em pe no balcao, e
## `_atendimento`, que poe a carteira dela em cima do balcao. O registro civil e
## funcao pura da semente, entao os dois recebem a mesma ficha sem trocar uma
## palavra — desde que usem o mesmo numero. Escrito solto nos dois lugares, ele
## divergiria no primeiro ajuste e a carteira passaria a ser de um estranho.
const SAL_DO_CLIENTE := 733
const SAL_DO_ATENDENTE := 611

## A faixa de idade do cliente. Vale a mesma amarracao do sal.
const IDADE_CLIENTE := Vector2i(18, 26)


static func construir(semente: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente

	var sup: Dictionary = {}
	var props: Array[Dictionary] = []
	var colisao: Array[Dictionary] = []

	_casca(sup, colisao)
	_vitrine(sup)
	_gondolas(sup, colisao, rng)
	_frente(sup, colisao, props, rng, semente)
	_fundo(sup, colisao, props)
	_luzes(sup, props, rng)
	_servico(sup, colisao, props, rng)
	_mercadoria(props, rng)
	_gente(props, semente)

	var tris := 0
	for mat: StringName in sup:
		tris += PSXMesh.dados_triangulos(sup[mat])

	return {
		"superficies": sup, "props": props, "colisao": colisao,
		"triangulos": tris, "entrada": ENTRADA, "olhar": OLHAR,
		# A loja tem ambiente proprio: branco, chapado e sem sombra. E metade do
		# efeito do comodo, e nao daria para conseguir so com lampada.
		"ambiente": "res://resources/fog/fog_mercado.tres",
		"saida": {
			"pos": Vector3(CENTRO_SALAO, 1.0, 0.62),
			"tamanho": Vector3(2.4, 2.0, 1.1),
			# Porta automatica: as duas folhas correm para os lados. Porta de loja
			# que gira na dobradica entrega na hora que o lugar nao e uma loja.
			"deslizante": {
				"centro": Vector3(CENTRO_SALAO, 0.0, 0.06),
				"largura": (PORTA_X1 - PORTA_X0) * 0.5,
				"altura": 2.24,
				"giro": 0.0,
				"curso": (PORTA_X1 - PORTA_X0) * 0.46,
			},
		},
	}


# --- casca ------------------------------------------------------------------

## Parede reta com vaos, dada em coordenadas absolutas do plano.
##
## `vaos` sao pares (inicio, fim) medidos ao longo do segmento a partir de `a`,
## que e o que `KitModular.parede_com_vaos` espera. Este embrulho existe so para
## registrar a COLISAO dos trechos cheios junto: sem ele cada parede do bloco de
## servico precisaria ser escrita duas vezes, uma para ver e outra para esbarrar,
## e as duas divergiriam no primeiro ajuste de planta.
static func _parede(sup: Dictionary, colisao: Array[Dictionary],
		material: StringName, a: Vector2, b: Vector2, altura: float,
		vaos: Array = [], cor: Color = PAREDE, rodape: float = 0.0,
		solida: bool = true, altura_vao: float = ALTURA_PORTA) -> void:
	KitModular.parede_com_vaos(sup, material, a, b, altura, vaos,
		altura_vao, cor, rodape)
	if not solida:
		return

	var delta := b - a
	var comprimento := delta.length()
	if comprimento < 0.01:
		return
	var dir := delta / comprimento
	var giro := atan2(-dir.y, dir.x)
	var ordenados: Array = vaos.duplicate()
	ordenados.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)

	var cursor := 0.0
	for corte: Vector2 in ordenados:
		if corte.x > cursor:
			_trecho_solido(colisao, a, dir, cursor, corte.x, altura, giro)
		cursor = maxf(cursor, corte.y)
	if cursor < comprimento:
		_trecho_solido(colisao, a, dir, cursor, comprimento, altura, giro)


static func _trecho_solido(colisao: Array[Dictionary], a: Vector2, dir: Vector2,
		de: float, ate: float, altura: float, giro: float) -> void:
	var comp := ate - de
	if comp < 0.04:
		return
	var meio := a + dir * (de + comp * 0.5)
	KitModular.solido(colisao, Vector3(meio.x, altura * 0.5, meio.y),
		Vector3(comp, altura, 0.22), giro)


## Teto de um retangulo da planta, virado para baixo.
static func _teto(sup: Dictionary, material: StringName, canto: Vector2,
		tamanho: Vector2, altura: float, cor: Color = Color.WHITE) -> void:
	var dados := PSXMesh.plane_dados(tamanho)
	if not sup.has(material):
		sup[material] = PSXMesh.dados_vazios()
	PSXMesh.acumular_tingido(sup[material], dados,
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
			Vector3(canto.x + tamanho.x * 0.5, altura, canto.y + tamanho.y * 0.5)),
		cor)


static func _casca(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	# --- salao ---
	KitModular.chao(sup, &"mercado_piso", Vector3(DIVISA, 0.0, 0.0),
		Vector2(LARGURA - DIVISA, FUNDO))
	_teto(sup, &"mercado_teto", Vector2(DIVISA, 0.0),
		Vector2(LARGURA - DIVISA, FUNDO), ALTURA)

	# Perimetro anti horario visto de cima, para as normais olharem para dentro.
	# A parede sul do salao quase nao existe: e vidro, e entra em `_vitrine`.
	_parede(sup, colisao, &"reboco", Vector2(LARGURA, 0.0), Vector2(LARGURA, FUNDO),
		ALTURA, [], PAREDE, RODAPE)
	_parede(sup, colisao, &"reboco", Vector2(LARGURA, FUNDO), Vector2(DIVISA, FUNDO),
		ALTURA, [], PAREDE, RODAPE)
	# A divisa vista do salao. O vao e a porta de servico, atras do caixa.
	#
	# Ela sobe ate a altura da GARAGEM e nao ate a do salao: e a mesma parede dos
	# dois lados, e do lado de la o pe direito e maior. O forro do salao, em
	# ALTURA, tapa a sobra — que e mais barato que emendar dois trechos de altura
	# diferente e ver a emenda abrir no primeiro ajuste de planta.
	var z0 := FUNDO - (PORTA_SERVICO_Z + LARGURA_PORTA_INTERNA * 0.5)
	_parede(sup, colisao, &"reboco", Vector2(DIVISA, FUNDO), Vector2(DIVISA, 0.0),
		ALTURA_GARAGEM, [Vector2(z0, z0 + LARGURA_PORTA_INTERNA)], PAREDE, RODAPE)

	# --- bloco de servico: piso e forro de cada comodo ---
	KitModular.chao(sup, &"concreto", Vector3(0.0, 0.0, 0.0),
		Vector2(DIVISA, GARAGEM_Z1), PSXMesh.MAX_QUAD_M, KitMercado.PISO_SERVICO)
	_teto(sup, &"concreto", Vector2(0.0, 0.0), Vector2(DIVISA, GARAGEM_Z1),
		ALTURA_GARAGEM, Color("585a56"))

	KitModular.chao(sup, &"piso_ceramico", Vector3(0.0, 0.0, CORREDOR_Z0),
		Vector2(DIVISA, CORREDOR_Z1 - CORREDOR_Z0), PSXMesh.MAX_QUAD_M,
		Color("9a9c94"))
	_teto(sup, &"mercado_teto", Vector2(0.0, CORREDOR_Z0),
		Vector2(DIVISA, CORREDOR_Z1 - CORREDOR_Z0), ALTURA_SERVICO, Color("c0c2bc"))

	KitModular.chao(sup, &"piso_ceramico", Vector3(0.0, 0.0, CORREDOR_Z1),
		Vector2(BANHEIRO_X1, FUNDO - CORREDOR_Z1), PSXMesh.MAX_QUAD_M,
		Color("b6bcb6"))
	_teto(sup, &"mercado_teto", Vector2(0.0, CORREDOR_Z1),
		Vector2(BANHEIRO_X1, FUNDO - CORREDOR_Z1), ALTURA_SERVICO, Color("c8cac4"))

	KitModular.chao(sup, &"piso_ceramico", Vector3(COPA_X0, 0.0, CORREDOR_Z1),
		Vector2(DIVISA - COPA_X0, FUNDO - CORREDOR_Z1), PSXMesh.MAX_QUAD_M,
		Color("9a9c94"))
	_teto(sup, &"mercado_teto", Vector2(COPA_X0, CORREDOR_Z1),
		Vector2(DIVISA - COPA_X0, FUNDO - CORREDOR_Z1), ALTURA_SERVICO,
		Color("c0c2bc"))

	_paredes_servico(sup, colisao)

	# Piso e forro invisiveis, para o jogador nao cair nem subir. Cobrem o
	# conjunto inteiro de uma vez: sao dois blocos, e recorta-los por comodo nao
	# mudaria nada que o jogador sinta.
	colisao.append({"tamanho": Vector3(LARGURA, 0.3, FUNDO),
		"pos": Vector3(LARGURA * 0.5, -0.15, FUNDO * 0.5)})
	colisao.append({"tamanho": Vector3(LARGURA, 0.3, FUNDO),
		"pos": Vector3(LARGURA * 0.5, ALTURA_GARAGEM + 0.15, FUNDO * 0.5)})


## As paredes do bloco de servico.
##
## Cada comodo e percorrido no seu proprio sentido anti horario, entao a parede
## entre dois deles e construida DUAS vezes, uma de cada lado. Nao e desperdicio:
## e o que deixa o banheiro ser azulejo por dentro e verde de servico por fora
## sem nenhuma logica de "qual material ganha".
static func _paredes_servico(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	var verde := KitMercado.VERDE_SERVICO
	var vao_portao := Vector2(EIXO_SERVICO - KitMercado.LARGURA_PORTAO * 0.5,
		EIXO_SERVICO + KitMercado.LARGURA_PORTAO * 0.5)

	# --- garagem: z de 0 a GARAGEM_Z1 ---
	# Sul, com o vao do portao. Percorrida de leste para oeste para a normal
	# olhar para dentro da garagem.
	#
	# O vao dela e mais alto que o das portas de gente: a verga tem de comecar
	# ACIMA do topo do portao, senao a parede corta a folha ao meio. E o unico
	# lugar da planta onde a altura de vao padrao nao serve.
	_parede(sup, colisao, &"concreto_sujo", Vector2(DIVISA, 0.0), Vector2(0.0, 0.0),
		ALTURA_GARAGEM,
		[Vector2(DIVISA - vao_portao.y, DIVISA - vao_portao.x)], Color("8e918a"),
		0.0, true, KitMercado.ALTURA_PORTAO + 0.34)
	_parede(sup, colisao, &"concreto_sujo", Vector2(0.0, 0.0),
		Vector2(0.0, GARAGEM_Z1), ALTURA_GARAGEM, [], Color("8e918a"))
	# Norte da garagem, que e o sul do corredor: leva o vao aberto de passagem.
	var vao_g := Vector2(VAO_GARAGEM_X - VAO_GARAGEM_L * 0.5,
		VAO_GARAGEM_X + VAO_GARAGEM_L * 0.5)
	_parede(sup, colisao, &"concreto_sujo", Vector2(0.0, GARAGEM_Z1),
		Vector2(DIVISA, GARAGEM_Z1), ALTURA_GARAGEM, [vao_g], Color("8e918a"))

	# --- corredor ---
	_parede(sup, colisao, &"reboco", Vector2(DIVISA, CORREDOR_Z0),
		Vector2(0.0, CORREDOR_Z0), ALTURA_SERVICO,
		[Vector2(DIVISA - vao_g.y, DIVISA - vao_g.x)], verde, RODAPE, false)
	_parede(sup, colisao, &"reboco", Vector2(0.0, CORREDOR_Z0),
		Vector2(0.0, CORREDOR_Z1), ALTURA_SERVICO, [], verde, RODAPE)
	# Norte do corredor: as duas portas do fundo, uma para cada comodo.
	var meia := LARGURA_PORTA_INTERNA * 0.5
	_parede(sup, colisao, &"reboco", Vector2(0.0, CORREDOR_Z1),
		Vector2(DIVISA, CORREDOR_Z1), ALTURA_SERVICO,
		[Vector2(PORTA_BANHEIRO - meia, PORTA_BANHEIRO + meia),
		Vector2(PORTA_COPA - meia, PORTA_COPA + meia)], verde, RODAPE)
	# Leste do corredor: e a divisa, ja levantada em `_casca` com o vao da porta
	# de servico. Aqui entra so a face de dentro, em verde.
	var z0 := CORREDOR_Z1 - (PORTA_SERVICO_Z + meia)
	_parede(sup, colisao, &"reboco", Vector2(DIVISA, CORREDOR_Z1),
		Vector2(DIVISA, CORREDOR_Z0), ALTURA_SERVICO,
		[Vector2(z0, z0 + LARGURA_PORTA_INTERNA)], verde, RODAPE, false)

	# --- banheiro: azulejo ate o teto, que e o que todo banheiro de loja tem ---
	_parede(sup, colisao, &"mercado_azulejo", Vector2(BANHEIRO_X1, CORREDOR_Z1),
		Vector2(0.0, CORREDOR_Z1), ALTURA_SERVICO,
		[Vector2(BANHEIRO_X1 - PORTA_BANHEIRO - meia,
			BANHEIRO_X1 - PORTA_BANHEIRO + meia)], Color.WHITE, 0.0, false)
	_parede(sup, colisao, &"mercado_azulejo", Vector2(0.0, CORREDOR_Z1),
		Vector2(0.0, FUNDO), ALTURA_SERVICO, [], Color.WHITE)
	_parede(sup, colisao, &"mercado_azulejo", Vector2(0.0, FUNDO),
		Vector2(BANHEIRO_X1, FUNDO), ALTURA_SERVICO, [], Color.WHITE)
	_parede(sup, colisao, &"mercado_azulejo", Vector2(BANHEIRO_X1, FUNDO),
		Vector2(BANHEIRO_X1, CORREDOR_Z1), ALTURA_SERVICO, [], Color.WHITE)

	# --- copa ---
	_parede(sup, colisao, &"reboco", Vector2(DIVISA, CORREDOR_Z1),
		Vector2(COPA_X0, CORREDOR_Z1), ALTURA_SERVICO,
		[Vector2(DIVISA - PORTA_COPA - meia, DIVISA - PORTA_COPA + meia)],
		verde, RODAPE, false)
	_parede(sup, colisao, &"reboco", Vector2(COPA_X0, CORREDOR_Z1),
		Vector2(COPA_X0, FUNDO), ALTURA_SERVICO, [], verde, RODAPE)
	_parede(sup, colisao, &"reboco", Vector2(COPA_X0, FUNDO),
		Vector2(DIVISA, FUNDO), ALTURA_SERVICO, [], verde, RODAPE)
	_parede(sup, colisao, &"reboco", Vector2(DIVISA, FUNDO),
		Vector2(DIVISA, CORREDOR_Z1), ALTURA_SERVICO, [], verde, RODAPE, false)


## Fachada de vidro vista de dentro.
##
## O vidro e opaco de proposito, e nao por preguica: o interior vive dois mil
## metros acima da cidade, entao vidro transparente mostraria o vazio. Painel
## branco aceso e o que se ve mesmo, de dentro de uma loja iluminada olhando
## para uma rua com nevoa: a propria luz da loja volta do vidro e apaga o que ha
## do lado de fora.
static func _vitrine(sup: Dictionary) -> void:
	var faixas: Array[Vector2] = [Vector2(DIVISA + 0.3, PORTA_X0),
		Vector2(PORTA_X1, LARGURA - 0.3)]
	for faixa: Vector2 in faixas:
		var larg := faixa.y - faixa.x
		KitModular.placa(sup, &"mercado_vidro",
			Vector3((faixa.x + faixa.y) * 0.5, 1.24, 0.05),
			Vector2(larg, 2.36), 0.0, Color("dfeaee"),
			KitMercado.SUBDIVISAO_PAINEL)

		# Montantes de aluminio a cada 1,4 m. Sao eles que fazem o painel ler
		# como vitrine envidracada em vez de parede branca.
		var vaos := maxi(1, int(round(larg / 1.4)))
		for k in vaos + 1:
			KitModular.caixa_cor(sup, &"metal",
				Vector3(faixa.x + larg * (float(k) / float(vaos)), 1.24, 0.1),
				Vector3(0.07, 2.36, 0.12), KitMercado.ESTRUTURA)

	# Travessa sobre o vao da porta e faixa cega ate o teto.
	KitModular.caixa_cor(sup, &"metal", Vector3(CENTRO_SALAO, 2.34, 0.1),
		Vector3(PORTA_X1 - PORTA_X0 + 0.3, 0.14, 0.14), KitMercado.ESTRUTURA)
	KitModular.parede_livre(sup, &"reboco",
		Vector3((DIVISA + LARGURA) * 0.5, 2.66, 0.04),
		Vector2(LARGURA - DIVISA, 0.48), 0.0, PAREDE)
	# Peitoril baixo, que esconde o encontro do vidro com o piso.
	KitModular.caixa_cor(sup, &"metal",
		Vector3((DIVISA + LARGURA) * 0.5, 0.05, 0.12),
		Vector3(LARGURA - DIVISA, 0.1, 0.2), KitMercado.RODAPE_LOJA)


# --- corredores -------------------------------------------------------------

static func _gondolas(sup: Dictionary, colisao: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	var comprimento := ILHA_Z1 - ILHA_Z0
	var z := (ILHA_Z0 + ILHA_Z1) * 0.5

	# As tres ilhas correm no eixo Z, alinhadas com quem entra pela porta. E o
	# que da o corredor central com a camara fria acesa no fim.
	for i in ILHAS.size():
		KitMercado.gondola(sup, colisao, Vector3(ILHAS[i], 0.0, z),
			comprimento, PI * 0.5, i)

	# Parede leste: prateleira alta virada para dentro, quase de ponta a ponta.
	KitMercado.gondola_parede(sup, colisao, Vector3(LARGURA - 0.28, 0.0, 7.2),
		8.4, -PI * 0.5, rng.randi() % KitMercado.VARIANTES)
	# Divisa, ao norte da porta de servico.
	KitMercado.gondola_parede(sup, colisao, Vector3(DIVISA + 0.28, 0.0, 10.0),
		4.4, PI * 0.5, rng.randi() % KitMercado.VARIANTES)

	# Cartaz de corredor sobre cada boca de corredor.
	var cores: Array[Color] = [Color("e2a05a"), Color("7ec49a"), Color("d98a86")]
	for i in ILHAS.size():
		KitMercado.placa_corredor(sup, ALTURA, ILHAS[i], ILHA_Z0 - 0.5,
			0.0, cores[i])


# --- frente da loja ---------------------------------------------------------

static func _frente(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], rng: RandomNumberGenerator,
		semente: int) -> void:
	# Balcao encostado na divisa, virado para dentro. Fica do lado de quem entra
	# em que esta a porta de servico, que e como toda loja de conveniencia se
	# organiza: caixa e fundos na mesma parede, para o funcionario nao atravessar
	# o salao carregando caixa.
	KitMercado.balcao(sup, colisao, Vector3(BALCAO_X, 0.0, BALCAO_Z),
		BALCAO_COMPRIMENTO, PI * 0.5)

	var luz_quente := KitMercado.caixa_quente(sup, colisao,
		Vector3(BALCAO_X, KitMercado.ALTURA_BALCAO + 0.04, 2.4), PI * 0.5)
	props.append({
		"tipo": "lampada", "pos": luz_quente + Vector3(0.4, 0.0, 0.0),
		"padrao": Lampada.Padrao.ESTAVEL, "semente": rng.randi(),
		"cor": Color("ffcf8a"), "energia": 1.1, "alcance": 2.8, "facho": false,
	})

	# O computador do balcao. Fica na ponta norte, virado para quem esta do lado
	# de fora do caixa: e a mesma tela que o funcionario usa, e o jogador chega
	# nela por cima do balcao, como quem se debruca para ver o monitor de alguem.
	var alvo := KitMercado.computador(sup, colisao,
		Vector3(BALCAO_X, KitMercado.ALTURA_BALCAO + 0.05, BALCAO_Z + 1.5),
		PI * 0.5)
	props.append({
		"tipo": "computador",
		"pos": alvo,
		"tamanho": Vector3(0.9, 0.9, 0.8),
		"rotulo": "Consultar CPF ou nome",
	})

	_atendimento(sup, colisao, props, alvo, semente)

	KitMercado.maquina_cafe(sup, colisao, Vector3(DIVISA + 0.3, 0.0, 7.6),
		PI * 0.5)

	# Revistas encostadas no vidro, do outro lado de quem entra. E onde a loja de
	# verdade poe: quem le fica visivel da calcada.
	KitMercado.revisteiro(sup, colisao, Vector3(16.4, 0.0, 0.46), 3.6, 0.0)

	KitMercado.tapete_entrada(sup, Vector3(CENTRO_SALAO, 0.0, 1.1),
		Vector2(2.4, 1.4), 0.0)
	KitMercado.cestas(sup, colisao, Vector3(10.2, 0.0, 1.35), 0.2)
	KitMercado.lixeira(sup, colisao, Vector3(14.9, 0.0, 1.4), -0.15)

	# Telefone da loja. Loja de conveniencia acesa a noite e o lugar mais seguro
	# do bairro, entao e onde o jogo deixa salvar.
	props.append({
		"tipo": "save",
		"pos": Vector3(LARGURA - 0.55, KitModular.ALTURA_MEIO_FIO, 1.6),
		"giro": -PI * 0.5,
		"local": "Telefone da loja HIKARI",
	})


## A carteira que o cliente largou no balcao, e o leitor ao lado dela.
##
## Os tres objetos do atendimento ficam em linha sobre o tampo, na ordem em que
## o gesto acontece: a carteira do lado do cliente, o leitor no meio, o monitor
## do lado do atendente. Nao e arrumacao — e a instrucao. Um jogador que nunca
## viu isto antes le a sequencia inteira olhando para o balcao, sem uma palavra
## na tela, porque a ordem espacial e a ordem temporal.
##
## `monitor` chega pronto de quem montou o computador: e para onde a camera vira
## quando a leitura termina, e tem de ser a MESMA posicao que o prop do
## computador usa. Duas contas separadas para a mesma tela divergiriam no
## primeiro ajuste de altura do balcao, e a camera pararia olhando ao lado dele.
static func _atendimento(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], monitor: Vector3, semente: int) -> void:
	var tampo := KitMercado.ALTURA_BALCAO + 0.05

	# Do lado do cliente, torta. Ver KitMercado.identidade_no_balcao: os oito
	# graus sao o que separa "documento colocado" de "documento jogado".
	# Tudo do atendimento vive numa ilha so, na ponta norte do balcao: a
	# registradora ja estava ali, e o computador tambem. Espalhar carteira,
	# leitor e monitor por dois metros de tampo obrigaria o jogador a andar entre
	# tres pontos para atender uma pessoa — e num balcao de verdade a mao do
	# atendente alcanca os tres sem sair do lugar.
	var carteira := Vector3(BALCAO_X + 0.15, tampo, BALCAO_Z + 0.85)
	KitMercado.identidade_no_balcao(sup, carteira, PI * 0.5 + 0.14)

	var leitor := Vector3(BALCAO_X - 0.06, tampo - 0.02, BALCAO_Z + 1.16)
	var luz := KitMercado.leitor_codigo(sup, colisao, leitor, -PI * 0.5)

	props.append({
		"tipo": "atendimento",
		# A area de acionamento e bem maior que o cartao: doze centimetros de
		# documento a um metro e meio de distancia dao tres pixels de mira, e
		# obrigar o jogador a acertar tres pixels nao e dificuldade, e defeito.
		"pos": carteira + Vector3(0.0, 0.12, 0.0),
		"tamanho": Vector3(0.5, 0.4, 0.45),
		"leitor": leitor + Vector3(0.0, 0.16, 0.0),
		"tamanho_leitor": Vector3(0.5, 0.45, 0.45),
		"luz": luz,
		"monitor": monitor,
		# O MESMO par que `_gente` usa para o cliente. Ver SAL_DO_CLIENTE.
		"semente": semente + SAL_DO_CLIENTE,
		"idade_min": IDADE_CLIENTE.x,
		"idade_max": IDADE_CLIENTE.y,
	})


# --- fundo da loja ----------------------------------------------------------

static func _fundo(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary]) -> void:
	var luzes := KitMercado.geladeira_parede(sup, colisao,
		Vector3((DIVISA + LARGURA) * 0.5, 0.0, FUNDO - 0.36), 11.6, PI, 7)

	# Uma luz para cada tres portas, e nao uma por porta. Sete luzes so na camara
	# fria estourariam o limite de lampadas por objeto do renderizador de
	# compatibilidade e as ultimas seriam ignoradas na malha fundida — e como a
	# loja agora tem quatro comodos alem do salao, cada vaga conta.
	for k in range(1, luzes.size(), 4):
		props.append({
			"tipo": "lampada", "pos": luzes[k],
			"padrao": Lampada.Padrao.ESTAVEL, "semente": 8100 + k * 37,
			"cor": Color("cfe4ff"), "energia": 1.6, "alcance": 7.0,
			"facho": false,
		})


# --- luz --------------------------------------------------------------------

static func _luzes(sup: Dictionary, props: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	# Calhas correndo sobre os corredores. Sao quatro e nao uma, porque o que
	# define a loja e a luz sem direcao: com uma fonte so voltariam as sombras
	# longas que o comodo inteiro existe para nao ter.
	var linhas: Array[float] = [10.0, CENTRO_SALAO, 15.3, 17.8]
	for i in linhas.size():
		var pos := KitMercado.calha(sup, ALTURA, linhas[i], 7.0, 9.4, PI * 0.5)
		# A do fundo a leste falha. Uma so, e longe da porta: numa loja em que
		# tudo funciona, a unica coisa que nao funciona fica sendo o assunto.
		var padrao := Lampada.Padrao.ESTAVEL
		if i == linhas.size() - 1:
			padrao = Lampada.Padrao.FLUORESCENTE
		props.append({
			"tipo": "lampada", "pos": pos, "padrao": padrao,
			"semente": rng.randi(), "cor": Color("f4faf6"),
			"energia": 2.4, "alcance": 9.0, "facho": false,
		})

	# Calha sobre o balcao, correndo junto com ele.
	var frente := KitMercado.calha(sup, ALTURA, BALCAO_X - 0.4, BALCAO_Z + 0.6,
		7.0, PI * 0.5)
	props.append({
		"tipo": "lampada", "pos": frente, "padrao": Lampada.Padrao.ESTAVEL,
		"semente": rng.randi(), "cor": Color("f4faf6"),
		"energia": 2.2, "alcance": 8.0, "facho": false,
	})


# --- bloco de servico -------------------------------------------------------

## Garagem, corredor, banheiro e copa.
##
## Ordem de leitura do comodo, e nao de construcao: o jogador sai do caixa, cai
## no corredor, ve o portao da garagem a esquerda e as duas portas do fundo a
## frente. Tudo que ele precisa para decidir para onde ir cabe no primeiro
## quadro, e e por isso que o corredor atravessa o bloco inteiro em vez de virar
## uma esquina.
static func _servico(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	_garagem(sup, colisao, props, rng)
	_corredor(sup, colisao, props)
	_banheiro(sup, colisao, props)
	_copa(sup, colisao, props, rng)


static func _garagem(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	# O portao. O batente sai daqui; a folha e prop, porque ela sobe.
	KitMercado.portao_garagem(sup, colisao,
		Vector3(EIXO_SERVICO, 0.0, 0.1), KitMercado.LARGURA_PORTAO, 0.0)
	props.append({
		"tipo": "portao_garagem",
		"pos": Vector3(EIXO_SERVICO, 1.1, 1.05),
		"tamanho": Vector3(KitMercado.LARGURA_PORTAO, 2.2, 1.5),
		"centro": Vector3(EIXO_SERVICO, 0.0, 0.1),
		"largura": KitMercado.LARGURA_PORTAO,
		"giro": 0.0,
		"rotulo": "Abrir o portao",
		# Onde o jogador reaparece na rua, no referencial da fachada da loja:
		# ao lado do vao da porta automatica, na frente do portao desenhado no
		# chunk. Ver KitMercado.AFASTAMENTO_PORTAO — os dois numeros tem de sair
		# da mesma constante, senao o jogador sai por um portao e aparece na
		# frente de outro.
		"deslocamento": Vector3(Porta.FOLHA_LARGURA + KitMercado.AFASTAMENTO_PORTAO,
			0.0, 1.3),
	})

	# Estante de estoque na parede oeste, de ponta a ponta. E o fundo do quadro
	# para quem espia da porta do salao: se a garagem estivesse vazia ela leria
	# como sala inacabada em vez de deposito.
	KitMercado.estante_estoque(sup, colisao, Vector3(0.42, 0.0, 3.1), 4.4,
		PI * 0.5)

	# Paletes com a entrega da noite. Alturas diferentes de proposito: duas
	# pilhas iguais leem como copia colada.
	KitMercado.palete(sup, colisao, Vector3(2.0, 0.0, 4.5), 3, 0.12)
	KitMercado.palete(sup, colisao, Vector3(4.5, 0.0, 4.6), 2, -0.22)
	KitMercado.carrinho_carga(sup, colisao, Vector3(5.9, 0.0, 1.5), PI * 0.5)
	KitMercado.tambor(sup, colisao, Vector3(0.6, 0.0, 5.4), Color("7a5a3c"), 0.4)
	KitMercado.sacos_lixo(sup, colisao, Vector3(5.7, 0.0, 3.4), 3, 0.6)
	KitMercado.grade_ar(sup, Vector3(DIVISA - 0.06, 2.7, 2.6), Vector2(0.9, 0.6),
		-PI * 0.5)

	# Uma luminaria so, alta e crua. A garagem e o unico comodo do conjunto com
	# sombra de verdade, e e ela que faz a virada de clima valer: o salao nao tem
	# nenhuma.
	props.append({
		"tipo": "lampada", "pos": Vector3(EIXO_SERVICO, ALTURA_GARAGEM - 0.3, 3.0),
		"padrao": Lampada.Padrao.FLUORESCENTE, "semente": rng.randi(),
		"cor": Color("e8eee4"), "energia": 3.1, "alcance": 11.0, "facho": false,
	})
	KitMercado.calha(sup, ALTURA_GARAGEM, EIXO_SERVICO, 3.0, 2.4, 0.0)


static func _corredor(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary]) -> void:
	var meio := (CORREDOR_Z0 + CORREDOR_Z1) * 0.5

	# A porta de servico, do lado de dentro. E a mesma folha que o salao ve.
	KitMercado.batente(sup, Vector3(DIVISA - 0.02, 0.0, PORTA_SERVICO_Z),
		LARGURA_PORTA_INTERNA, ALTURA_PORTA, -PI * 0.5)
	props.append(_porta_batente(Vector3(DIVISA - 0.04, 1.05, PORTA_SERVICO_Z),
		Vector3(DIVISA - 0.04, 0.0, PORTA_SERVICO_Z - LARGURA_PORTA_INTERNA * 0.5),
		-PI * 0.5, "Porta de servico", Vector3(1.0, 2.1, 1.4)))

	# A maquina de refrigerante da equipe, no fundo do corredor. Vermelha, e a
	# unica cor saturada do bloco inteiro: num corredor todo verde ela e o marco
	# que diz ao jogador onde ele esta quando volta da garagem.
	var visor := KitMercado.maquina_refri(sup, colisao,
		Vector3(0.55, 0.0, meio), PI * 0.5)
	props.append({
		"tipo": "lampada", "pos": visor,
		"padrao": Lampada.Padrao.ESTAVEL, "semente": 4411,
		"cor": Color("ffd9a0"), "energia": 0.8, "alcance": 3.2, "facho": false,
	})

	# Quadro de avisos na parede do salao, ao lado da porta de servico.
	KitMercado.quadro_avisos(sup, Vector3(DIVISA - 0.08, 1.55, 8.1 - 1.0), 1.0,
		-PI * 0.5)

	KitMercado.balde_mop(sup, colisao, Vector3(2.1, 0.0, CORREDOR_Z0 + 0.5), 0.3)
	KitMercado.grade_ar(sup, Vector3(3.0, ALTURA_SERVICO - 0.3, CORREDOR_Z1 - 0.06),
		Vector2(0.7, 0.4), PI)

	# Placas de porta. Duas cores, e nao texto: a 480x270 o jogador le a cor
	# antes de qualquer letra, e sao so duas portas para distinguir.
	KitMercado.placa_porta(sup,
		Vector3(PORTA_BANHEIRO, ALTURA_PORTA + 0.18, CORREDOR_Z1 - 0.07), PI,
		Color("3f6ea8"))
	KitMercado.placa_porta(sup,
		Vector3(PORTA_COPA, ALTURA_PORTA + 0.18, CORREDOR_Z1 - 0.07), PI,
		Color("4a7a52"))

	props.append({
		"tipo": "lampada",
		"pos": Vector3(EIXO_SERVICO, ALTURA_SERVICO - 0.22, meio),
		"padrao": Lampada.Padrao.ESTAVEL, "semente": 4412,
		"cor": Color("eef4ea"), "energia": 2.5, "alcance": 8.5, "facho": false,
	})
	KitMercado.calha(sup, ALTURA_SERVICO, EIXO_SERVICO, meio, 4.4, 0.0)


static func _banheiro(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary]) -> void:
	KitMercado.batente(sup, Vector3(PORTA_BANHEIRO, 0.0, CORREDOR_Z1 + 0.02),
		LARGURA_PORTA_INTERNA, ALTURA_PORTA, 0.0)
	props.append(_porta_batente(
		Vector3(PORTA_BANHEIRO, 1.05, CORREDOR_Z1 + 0.04),
		Vector3(PORTA_BANHEIRO - LARGURA_PORTA_INTERNA * 0.5, 0.0,
			CORREDOR_Z1 + 0.04),
		0.0, "Banheiro", Vector3(1.3, 2.1, 1.1)))

	# Um box so, no fundo, com a divisoria que nao encosta no chao. E esse vao
	# embaixo que faz o comodo ler como banheiro publico e nao como sala pequena.
	# O comprimento e o de um box, nao o do comodo: 2,6 m comia o quadro inteiro
	# e a captura nascia do lado de dentro da chapa.
	KitMercado.divisoria_box(sup, colisao, Vector3(1.55, 0.0, 11.9), 1.5, PI * 0.5)
	KitMercado.vaso(sup, colisao, Vector3(0.85, 0.0, FUNDO - 0.45), PI)
	KitMercado.pia(sup, colisao, Vector3(2.75, 0.0, 9.5), -PI * 0.5)
	KitMercado.toalheiro(sup, Vector3(BANHEIRO_X1 - 0.09, 1.3, 10.7), -PI * 0.5)
	KitMercado.lixeira(sup, colisao, Vector3(2.7, 0.0, 10.6), 0.2)

	props.append({
		"tipo": "lampada",
		"pos": Vector3(1.5, ALTURA_SERVICO - 0.2, 10.4),
		# A do banheiro pisca. E o unico comodo do conjunto em que o jogador fica
		# de costas para a porta, e a luz instavel e o que transforma dez segundos
		# de nada em dez segundos de atencao.
		# ESTAVEL de proposito. Fluorescente que apaga no meio da captura
		# deixava o comodo preto, e o box ja faz o trabalho de deixar o
		# jogador de costas para a porta.
		"padrao": Lampada.Padrao.ESTAVEL, "semente": 4413,
		"cor": Color("eaf2f4"), "energia": 2.8, "alcance": 7.5, "facho": false,
	})
	KitMercado.calha(sup, ALTURA_SERVICO, 1.5, 10.4, 1.8, PI * 0.5)


static func _copa(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	KitMercado.batente(sup, Vector3(PORTA_COPA, 0.0, CORREDOR_Z1 + 0.02),
		LARGURA_PORTA_INTERNA, ALTURA_PORTA, 0.0)
	props.append(_porta_batente(
		Vector3(PORTA_COPA, 1.05, CORREDOR_Z1 + 0.04),
		Vector3(PORTA_COPA + LARGURA_PORTA_INTERNA * 0.5, 0.0, CORREDOR_Z1 + 0.04),
		0.0, "Copa", Vector3(1.3, 2.1, 1.1), -92.0))

	# A mesa encostada no fundo, com a cadeira meio puxada. Cadeira empurrada
	# certinha le como movel de catalogo; puxada le como alguem que levantou.
	KitMercado.mesa_trabalho(sup, colisao, Vector3(5.05, 0.0, FUNDO - 0.4), 2.0, PI)
	KitMercado.cadeira(sup, colisao, Vector3(4.9, 0.0, FUNDO - 1.25), 0.26)
	KitMercado.quadro_avisos(sup, Vector3(5.05, 1.62, FUNDO - 0.08), 1.3, PI)

	KitMercado.armario_vestiario(sup, colisao,
		Vector3(COPA_X0 + 0.24, 0.0, 10.2), 4, PI * 0.5)
	KitMercado.bancada_copa(sup, colisao, Vector3(DIVISA - 0.32, 0.0, 10.6), 2.2,
		-PI * 0.5)
	KitMercado.sacos_lixo(sup, colisao, Vector3(COPA_X0 + 0.5, 0.0, 8.8), 2, 1.1)
	KitMercado.grade_ar(sup, Vector3(4.2, ALTURA_SERVICO - 0.28, FUNDO - 0.06),
		Vector2(0.7, 0.4), PI)

	props.append({
		"tipo": "lampada",
		"pos": Vector3(5.05, ALTURA_SERVICO - 0.22, 10.8),
		"padrao": Lampada.Padrao.ESTAVEL, "semente": rng.randi(),
		"cor": Color("f2f0e2"), "energia": 3.2, "alcance": 9.0, "facho": false,
	})
	KitMercado.calha(sup, ALTURA_SERVICO, 5.05, 10.8, 2.6, PI * 0.5)


## Descricao de uma porta de folha que abre no lugar, sem levar a outro comodo.
##
## Nao e a `porta_interna` da casa da fumaca: aquela empilha o comodo atual e
## constroi outro. Aqui o bloco de servico inteiro e UMA planta so, entao a
## folha e cenario animado — e o jogador atravessa andando, sem cortina e sem
## carregamento. E o que faz os quatro comodos lerem como um lugar so.
static func _porta_batente(pos: Vector3, dobradica: Vector3, giro: float,
		rotulo: String, tamanho: Vector3, angulo: float = 92.0) -> Dictionary:
	return {
		"tipo": "porta_batente",
		"pos": pos,
		"dobradica": dobradica,
		"giro": giro,
		"angulo": angulo,
		"rotulo": rotulo,
		"tamanho": tamanho,
	}


# --- mercadoria -------------------------------------------------------------

## Itens que o jogador leva. Poucos e espalhados: loja cheia de item para pegar
## vira deposito, e o valor de achar bandagem numa prateleira e justamente ela
## ser a unica coisa util num lugar cheio de coisa inutil.
static func _mercadoria(props: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	var lista: Array[Dictionary] = [
		{"item": &"bandagem", "pos": Vector3(12.3, 1.14, 6.0), "qtd": 2},
		{"item": &"bateria", "pos": Vector3(14.8, 1.14, 8.4), "qtd": 1},
		{"item": &"remedio", "pos": Vector3(LARGURA - 0.75, 1.32, 8.0), "qtd": 1},
		# Uma no deposito. E o premio de ter atravessado a porta do caixa: quem
		# so anda pelo salao nunca acha, e quem anda ate a garagem acha sem que
		# ninguem tenha avisado que havia algo la.
		{"item": &"bandagem", "pos": Vector3(0.95, 1.15, 3.1), "qtd": 1},
	]
	if rng.randf() < 0.5:
		lista.append({"item": &"municao_9mm",
			"pos": Vector3(BALCAO_X, KitMercado.ALTURA_BALCAO + 0.24, 2.9),
			"qtd": rng.randi_range(4, 9)})

	for i in lista.size():
		var d: Dictionary = lista[i]
		props.append({
			"tipo": "item", "pos": d["pos"], "item": d["item"],
			"quantidade": d["qtd"], "indice": 10 + i,
		})


## Quem esta atras do balcao e quem esta na frente dele.
##
## Uma ressalva ao cabecalho deste arquivo
## ---------------------------------------
## O texto la em cima diz que a loja assusta porque "nao ha ninguem". Isso valia
## enquanto o mercado so aparecia no meio da noite, depois de vinte minutos de
## nevoa. Ele agora tambem aparece na abertura, e uma loja vazia ali nao conta a
## cidade — conta um cenario. Duas pessoas conversando no caixa e o que faz o
## jogador entender, em quatro segundos de plano, que esta cidade e habitada.
##
## O desconforto do comodo nao morre com isso: a luz continua branca e chapada,
## o pe direito continua alto demais e o piso continua brilhando. O que muda e
## que agora ha alguem para quem aquela luz esta acesa.
##
## Nao estao chapados e nao tem olho vermelho: os dois sao da casa da fumaca, e
## e a primeira vez que o Convidado e usado fora dela.
static func _gente(props: Array[Dictionary], semente: int) -> void:
	# O balcao corre ao longo de Z em BALCAO_X (ver `_frente`). Um de cada lado.
	var atendente := Vector3(BALCAO_X - 0.72, 0.0, BALCAO_Z + 1.3)
	# O cliente nasce na porta, pega na gondola e deixa no caixa — o ciclo do
	# Midnight Mart. A identidade ja esta no tampo; o produto chega COM ela.
	var cliente := Vector3(CENTRO_SALAO, 0.0, 1.55)
	var gondola := Vector3(ILHAS[0] + 0.92, 0.0, 6.4)
	var caixa := Vector3(BALCAO_X + 0.95, 0.0, BALCAO_Z + 0.95)
	props.append(_pessoa(semente, SAL_DO_ATENDENTE, atendente, caixa))
	var compra := _pessoa(semente, SAL_DO_CLIENTE, cliente, atendente)
	compra["rotina"] = &"compra"
	compra["pontos"] = [gondola, caixa]
	compra["pouso"] = Vector3(BALCAO_X + 0.32, KitMercado.ALTURA_BALCAO + 0.08,
		BALCAO_Z + 0.72)
	props.append(compra)


## Os dois ficam parados de frente um para o outro.
##
## `pontos` vai vazio de proposito. E a lista de onde a pessoa pode ir passear, e
## atendente que sai andando pela loja no meio de um plano de quatro segundos
## deixa de ser atendente. Sem pontos, o Convidado fica onde nasceu e so conversa.
static func _pessoa(semente: int, sal: int, onde: Vector3,
		encara: Vector3) -> Dictionary:
	return {
		"tipo": "convidado",
		"pos": onde,
		"semente": semente + sal,
		"papel": Convidado.Papel.LIVRE,
		"fuma": false,
		# Explicita, e nao herdada do padrao do Interiores: a carteira em cima do
		# balcao le a mesma faixa para chegar na mesma pessoa.
		"idade_min": IDADE_CLIENTE.x,
		"idade_max": IDADE_CLIENTE.y,
		"foco": encara,
		"pontos": [],
		"chapado": false,
		"olhos": false,
	}
