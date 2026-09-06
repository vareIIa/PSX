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
## Planta, em metros, origem no canto sul-oeste:
##
##   z=9.0 +---------------------------------------+
##         |          CAMARA FRIA (6 portas)       |
##   z=8.3 +---------------------------------------+
##         | g |    |  g  |    |  g  |    |  g  | g |
##         | o |    |  o  |    |  o  |    |  o  | o |
##   z=3.4 | n |    |  n  |    |  n  |    |  n  | n |
##         +---+    +-----+    +-----+    +-----+   |
##         |BALCAO|                                 |
##   z=0   +------[porta automatica]--[revistas]----+
##        x=0                                     x=11
class_name MercadoBuilder
extends RefCounted

const LARGURA := 11.0
const FUNDO := 9.0
## Pe direito de loja, mais alto que o de casa. E parte do desconforto: o comodo
## e grande demais para uma pessoa so.
const ALTURA := 2.9
const ALTURA_PORTA := 2.3

## Vao da porta automatica, na parede sul.
const PORTA_X0 := 4.6
const PORTA_X1 := 6.4

## Onde o jogador aparece, e para onde olha. Entra de frente para o corredor
## central, com a camara fria acesa no fundo: e o quadro que a loja existe para
## dar, e o que puxa o jogador para dentro.
const ENTRADA := Vector3(5.5, 0.0, 1.15)
const OLHAR := Vector3(5.5, 1.55, 7.0)

const PAREDE := Color("e2e2dc")
const RODAPE := 0.12

## Onde ficam as tres ilhas de prateleira, em X.
const ILHAS: Array[float] = [3.6, 5.8, 8.0]
const ILHA_Z0 := 3.4
const ILHA_Z1 := 6.9


static func construir(semente: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente

	var sup: Dictionary = {}
	var props: Array[Dictionary] = []
	var colisao: Array[Dictionary] = []

	_casca(sup, colisao)
	_vitrine(sup)
	_gondolas(sup, colisao, rng)
	_frente(sup, colisao, props, rng)
	_fundo(sup, colisao, props)
	_luzes(sup, props, rng)
	_mercadoria(props, rng)

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
			"pos": Vector3(5.5, 1.0, 0.62),
			"tamanho": Vector3(2.2, 2.0, 1.1),
			# Porta automatica: as duas folhas correm para os lados. Porta de loja
			# que gira na dobradica entrega na hora que o lugar nao e uma loja.
			"deslizante": {
				"centro": Vector3(5.5, 0.0, 0.06),
				"largura": (PORTA_X1 - PORTA_X0) * 0.5,
				"altura": 2.24,
				"giro": 0.0,
				"curso": (PORTA_X1 - PORTA_X0) * 0.46,
			},
		},
	}


# --- casca ------------------------------------------------------------------

static func _casca(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	KitModular.chao(sup, &"mercado_piso", Vector3.ZERO, Vector2(LARGURA, FUNDO))

	var teto := PSXMesh.plane_dados(Vector2(LARGURA, FUNDO))
	KitModular.por(sup, &"mercado_teto", teto,
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
			Vector3(LARGURA * 0.5, ALTURA, FUNDO * 0.5)))

	# Perimetro anti horario visto de cima, para as normais olharem para dentro.
	# A parede sul quase nao existe: e vidro, e entra em _vitrine.
	KitModular.parede_com_vaos(sup, &"reboco", Vector2(LARGURA, 0.0),
		Vector2(LARGURA, FUNDO), ALTURA, [], ALTURA_PORTA, PAREDE, RODAPE)
	KitModular.parede_com_vaos(sup, &"reboco", Vector2(LARGURA, FUNDO),
		Vector2(0.0, FUNDO), ALTURA, [], ALTURA_PORTA, PAREDE, RODAPE)
	KitModular.parede_com_vaos(sup, &"reboco", Vector2(0.0, FUNDO),
		Vector2(0.0, 0.0), ALTURA, [], ALTURA_PORTA, PAREDE, RODAPE)

	var e := 0.25
	colisao.append({"tamanho": Vector3(LARGURA, 0.3, FUNDO),
		"pos": Vector3(LARGURA * 0.5, -0.15, FUNDO * 0.5)})
	colisao.append({"tamanho": Vector3(LARGURA, 0.3, FUNDO),
		"pos": Vector3(LARGURA * 0.5, ALTURA + 0.15, FUNDO * 0.5)})
	colisao.append({"tamanho": Vector3(LARGURA + e, ALTURA, e),
		"pos": Vector3(LARGURA * 0.5, ALTURA * 0.5, -e * 0.5)})
	colisao.append({"tamanho": Vector3(LARGURA + e, ALTURA, e),
		"pos": Vector3(LARGURA * 0.5, ALTURA * 0.5, FUNDO + e * 0.5)})
	colisao.append({"tamanho": Vector3(e, ALTURA, FUNDO + e),
		"pos": Vector3(-e * 0.5, ALTURA * 0.5, FUNDO * 0.5)})
	colisao.append({"tamanho": Vector3(e, ALTURA, FUNDO + e),
		"pos": Vector3(LARGURA + e * 0.5, ALTURA * 0.5, FUNDO * 0.5)})


## Fachada de vidro vista de dentro.
##
## O vidro e opaco de proposito, e nao por preguica: o interior vive dois mil
## metros acima da cidade, entao vidro transparente mostraria o vazio. Painel
## branco aceso e o que se ve mesmo, de dentro de uma loja iluminada olhando
## para uma rua com nevoa: a propria luz da loja volta do vidro e apaga o que ha
## do lado de fora.
static func _vitrine(sup: Dictionary) -> void:
	var faixas: Array[Vector2] = [Vector2(0.3, PORTA_X0), Vector2(PORTA_X1, LARGURA - 0.3)]
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
	KitModular.caixa_cor(sup, &"metal", Vector3(5.5, 2.34, 0.1),
		Vector3(PORTA_X1 - PORTA_X0 + 0.3, 0.14, 0.14), KitMercado.ESTRUTURA)
	KitModular.parede_livre(sup, &"reboco", Vector3(LARGURA * 0.5, 2.66, 0.04),
		Vector2(LARGURA, 0.48), 0.0, PAREDE)
	# Peitoril baixo, que esconde o encontro do vidro com o piso.
	KitModular.caixa_cor(sup, &"metal", Vector3(LARGURA * 0.5, 0.05, 0.12),
		Vector3(LARGURA, 0.1, 0.2), KitMercado.RODAPE_LOJA)


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

	# Parede leste: prateleira alta virada para dentro.
	KitMercado.gondola_parede(sup, colisao, Vector3(LARGURA - 0.28, 0.0, 4.8),
		5.4, -PI * 0.5, rng.randi() % KitMercado.VARIANTES)
	# Parede oeste, ao norte do balcao.
	KitMercado.gondola_parede(sup, colisao, Vector3(0.28, 0.0, 5.7),
		3.6, PI * 0.5, rng.randi() % KitMercado.VARIANTES)

	# Cartaz de corredor sobre cada boca de corredor.
	var cores: Array[Color] = [Color("e2a05a"), Color("7ec49a"), Color("d98a86")]
	for i in ILHAS.size():
		KitMercado.placa_corredor(sup, ALTURA, ILHAS[i], ILHA_Z0 - 0.5,
			0.0, cores[i])


# --- frente da loja ---------------------------------------------------------

static func _frente(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	# Balcao no lado oeste, virado para dentro. Fica logo a esquerda de quem
	# entra, que e onde toda loja de conveniencia poe o caixa.
	KitMercado.balcao(sup, colisao, Vector3(1.35, 0.0, 2.2), 2.4, PI * 0.5)
	KitMercado.gondola_parede(sup, colisao, Vector3(0.28, 0.0, 2.2), 2.6,
		PI * 0.5, 2)

	var luz_quente := KitMercado.caixa_quente(sup, colisao,
		Vector3(1.35, KitMercado.ALTURA_BALCAO + 0.04, 1.45), PI * 0.5)
	props.append({
		"tipo": "lampada", "pos": luz_quente + Vector3(0.4, 0.0, 0.0),
		"padrao": Lampada.Padrao.ESTAVEL, "semente": rng.randi(),
		"cor": Color("ffcf8a"), "energia": 1.1, "alcance": 2.8, "facho": false,
	})

	KitMercado.maquina_cafe(sup, colisao, Vector3(0.62, 0.0, 3.95), PI * 0.5)

	# Revistas encostadas no vidro, a direita de quem entra. E onde a loja de
	# verdade poe: quem le fica visivel da calcada. Aqui nao ha ninguem lendo.
	KitMercado.revisteiro(sup, colisao, Vector3(8.7, 0.0, 0.46), 3.4, 0.0)

	KitMercado.tapete_entrada(sup, Vector3(5.5, 0.0, 1.0), Vector2(2.2, 1.3), 0.0)
	KitMercado.cestas(sup, colisao, Vector3(3.9, 0.0, 1.15), 0.2)
	KitMercado.lixeira(sup, colisao, Vector3(7.15, 0.0, 1.2), -0.15)

	# Telefone da loja. Loja de conveniencia acesa a noite e o lugar mais seguro
	# do bairro, entao e onde o jogo deixa salvar.
	props.append({
		"tipo": "save",
		"pos": Vector3(LARGURA - 0.55, KitModular.ALTURA_MEIO_FIO, 1.3),
		"giro": -PI * 0.5,
		"local": "Telefone da loja HIKARI",
	})


# --- fundo da loja ----------------------------------------------------------

static func _fundo(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary]) -> void:
	var luzes := KitMercado.geladeira_parede(sup, colisao,
		Vector3(LARGURA * 0.5, 0.0, FUNDO - 0.36), 9.8, PI, 6)

	# Uma luz para cada duas portas. Seis luzes so na camara fria estourariam o
	# limite de lampadas por objeto do renderizador de compatibilidade, e as
	# ultimas seriam simplesmente ignoradas na malha fundida.
	for k in range(0, luzes.size(), 3):
		props.append({
			"tipo": "lampada", "pos": luzes[k],
			"padrao": Lampada.Padrao.ESTAVEL, "semente": 8100 + k * 37,
			"cor": Color("cfe4ff"), "energia": 1.6, "alcance": 6.0,
			"facho": false,
		})


# --- luz --------------------------------------------------------------------

static func _luzes(sup: Dictionary, props: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	# Calhas correndo sobre os corredores. Sao quatro e nao uma, porque o que
	# define a loja e a luz sem direcao: com uma fonte so voltariam as sombras
	# longas que o comodo inteiro existe para nao ter.
	var linhas: Array[float] = [2.5, 4.7, 6.9, 9.2]
	for i in linhas.size():
		var pos := KitMercado.calha(sup, ALTURA, linhas[i], 5.0, 6.6, PI * 0.5)
		# A do fundo a leste falha. Uma so, e longe da porta: numa loja em que
		# tudo funciona, a unica coisa que nao funciona fica sendo o assunto.
		var padrao := Lampada.Padrao.ESTAVEL
		if i == linhas.size() - 1:
			padrao = Lampada.Padrao.FLUORESCENTE
		props.append({
			"tipo": "lampada", "pos": pos, "padrao": padrao,
			"semente": rng.randi(), "cor": Color("f4faf6"),
			"energia": 2.4, "alcance": 8.5, "facho": false,
		})

	# Calha atravessada sobre a entrada e o balcao.
	var frente := KitMercado.calha(sup, ALTURA, 3.4, 1.5, 6.2, 0.0)
	props.append({
		"tipo": "lampada", "pos": frente, "padrao": Lampada.Padrao.ESTAVEL,
		"semente": rng.randi(), "cor": Color("f4faf6"),
		"energia": 2.2, "alcance": 8.0, "facho": false,
	})


# --- mercadoria -------------------------------------------------------------

## Itens que o jogador leva. Poucos e espalhados: loja cheia de item para pegar
## vira deposito, e o valor de achar bandagem numa prateleira e justamente ela
## ser a unica coisa util num lugar cheio de coisa inutil.
static func _mercadoria(props: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	var lista: Array[Dictionary] = [
		{"item": &"bandagem", "pos": Vector3(4.35, 1.14, 4.6), "qtd": 2},
		{"item": &"bateria", "pos": Vector3(7.25, 1.14, 6.2), "qtd": 1},
		{"item": &"remedio", "pos": Vector3(LARGURA - 0.75, 1.32, 5.6), "qtd": 1},
	]
	if rng.randf() < 0.5:
		lista.append({"item": &"municao_9mm",
			"pos": Vector3(1.35, KitMercado.ALTURA_BALCAO + 0.24, 2.9),
			"qtd": rng.randi_range(4, 9)})

	for i in lista.size():
		var d: Dictionary = lista[i]
		props.append({
			"tipo": "item", "pos": d["pos"], "item": d["item"],
			"quantidade": d["qtd"], "indice": 10 + i,
		})
