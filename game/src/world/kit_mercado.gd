## Movel de loja de conveniencia. So dados, nada de no: roda na thread junto com
## o resto da construcao do interior.
##
## A diferenca em relacao ao KitCasa nao e de tecnica, e de metodo. Movel de casa
## e caixa tingida, porque cada peca tem forma propria. Loja e o contrario: a
## gondola e uma caixa lisa, e quem faz a loja parecer cheia e a imagem pregada
## na frente dela. Modelar produto por produto custaria mil triangulos por
## gondola e, a 480x270 com dither por cima, nao ficaria melhor.
##
## Por isso quase tudo aqui usa KitModular.placa: a UV vai de 0 a 1 e a imagem
## cobre o painel inteiro uma vez so, sem repetir e sem cortar.
class_name KitMercado
extends RefCounted

# --- medidas padrao ---------------------------------------------------------
const ALTURA_GONDOLA := 1.52
const ALTURA_GONDOLA_PAREDE := 1.95
const PROF_GONDOLA := 0.86
const ALTURA_BALCAO := 0.98

## Aco pintado, o material de toda estrutura de loja.
const ESTRUTURA := Color("c4c6c2")
const ESTRUTURA_ESCURA := Color("6e716e")
const RODAPE_LOJA := Color("4a4d4c")

## Quantas variantes de prateleira existem. Alternar entre elas evita a fileira
## de gondolas identicas, que e o que denuncia geometria repetida.
const VARIANTES := 3

## Distancia entre o painel de imagem e a estrutura em que ele e pregado.
##
## Tres centimetros e muito para um adesivo e pouco para virar degrau, e existe
## por causa da profundidade: com meio centimetro as duas superficies caem no
## mesmo valor de profundidade a poucos metros de distancia e passam a piscar
## uma na frente da outra a cada passo do jogador.
const FOLGA_PAINEL := 0.03

## Quanto a frente da loja se projeta da fachada do predio.
##
## Loja de conveniencia de verdade avanca sobre a calcada, e aqui isso resolve
## dois problemas de uma vez: fica parecida com a referencia e para de brigar
## com a parede do predio, que estava aparecendo atraves do vidro.
const SALIENCIA := 0.3

## Subdivisao dos paineis de imagem, em metros.
##
## Menor que o padrao do projeto de proposito. A UV afim empena a textura dentro
## de cada quad, e a prateleira e o caso pior possivel: a imagem e feita de
## linhas horizontais, que sao justamente o que o empeno denuncia. Com dois
## quads num painel de tres metros e meio as fileiras saem tortas.
const SUBDIVISAO_PAINEL := 0.65


static func _solido(colisao: Array[Dictionary], centro: Vector3,
		tamanho: Vector3, giro: float = 0.0) -> void:
	KitModular.solido(colisao, centro, tamanho, giro)


static func _prateleira(variante: int) -> StringName:
	return StringName("mercado_prateleira_%d" % (posmod(variante, VARIANTES)))


# --- gondolas ---------------------------------------------------------------

## Ilha de prateleira, cheia dos dois lados. `comprimento` corre no eixo local X
## e `giro` gira em torno de Y.
static func gondola(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, comprimento: float, giro: float, variante: int) -> void:
	var b := Basis(Vector3.UP, giro)
	var meia := PROF_GONDOLA * 0.5

	# Corpo. So as faces que aparecem: as duas frentes ficam cobertas pelas
	# placas de produto e o fundo nunca e visto.
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, ALTURA_GONDOLA * 0.5, 0.0),
		Vector3(comprimento, ALTURA_GONDOLA, PROF_GONDOLA), ESTRUTURA, giro)
	# Rodape recuado e escuro, o vao onde entra o pe de quem para na frente.
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, 0.055, 0.0),
		Vector3(comprimento + 0.04, 0.11, PROF_GONDOLA - 0.1), RODAPE_LOJA, giro)

	# As duas frentes de produto, uma para cada lado.
	for lado: float in [1.0, -1.0]:
		KitModular.placa(sup, _prateleira(variante if lado > 0.0 else variante + 1),
			centro + b * Vector3(0.0, 0.86, lado * (meia + FOLGA_PAINEL)),
			Vector2(comprimento - 0.06, 1.28), giro + (0.0 if lado > 0.0 else PI),
			Color.WHITE, SUBDIVISAO_PAINEL)

	# Pontas. Numa loja de verdade sao o melhor espaco de exposicao, e aqui sao
	# tambem o que o jogador ve de frente ao entrar no corredor: sem produto
	# ficavam duas lajes escuras ocupando o meio do quadro.
	for ponta: float in [1.0, -1.0]:
		KitModular.placa(sup, _prateleira(variante + 2),
			centro + b * Vector3(ponta * (comprimento * 0.5 + FOLGA_PAINEL), 0.86, 0.0),
			Vector2(PROF_GONDOLA - 0.08, 1.28),
			giro + (PI * 0.5 if ponta > 0.0 else -PI * 0.5),
			Color.WHITE, SUBDIVISAO_PAINEL)

	# Testeira: a faixa clara no topo, onde a loja pendura o cartaz do corredor.
	KitModular.caixa_cor(sup, &"metal",
		centro + Vector3(0.0, ALTURA_GONDOLA + 0.045, 0.0),
		Vector3(comprimento + 0.05, 0.09, PROF_GONDOLA + 0.04), ESTRUTURA_ESCURA, giro)

	_solido(colisao, centro + Vector3(0.0, ALTURA_GONDOLA * 0.5, 0.0),
		Vector3(comprimento, ALTURA_GONDOLA, PROF_GONDOLA), giro)


## Prateleira encostada na parede: mais alta, cheia so de um lado.
## A frente olha para +Z local.
static func gondola_parede(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, comprimento: float, giro: float, variante: int) -> void:
	var b := Basis(Vector3.UP, giro)
	var prof := 0.5

	KitModular.caixa_cor(sup, &"metal",
		centro + Vector3(0.0, ALTURA_GONDOLA_PAREDE * 0.5, 0.0),
		Vector3(comprimento, ALTURA_GONDOLA_PAREDE, prof), ESTRUTURA, giro)
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, 0.055, 0.0),
		Vector3(comprimento + 0.04, 0.11, prof - 0.08), RODAPE_LOJA, giro)

	# Duas placas empilhadas: uma imagem so esticada em 1,75 m deixaria o
	# produto com o dobro da altura real e a prateleira perde a escala.
	for nivel in 2:
		KitModular.placa(sup, _prateleira(variante + nivel),
			centro + b * Vector3(0.0, 0.52 + float(nivel) * 0.86, prof * 0.5 + FOLGA_PAINEL),
			Vector2(comprimento - 0.06, 0.84), giro, Color.WHITE, SUBDIVISAO_PAINEL)

	KitModular.caixa_cor(sup, &"metal",
		centro + Vector3(0.0, ALTURA_GONDOLA_PAREDE + 0.045, 0.0),
		Vector3(comprimento + 0.05, 0.09, prof + 0.04), ESTRUTURA_ESCURA, giro)

	_solido(colisao, centro + Vector3(0.0, ALTURA_GONDOLA_PAREDE * 0.5, 0.0),
		Vector3(comprimento, ALTURA_GONDOLA_PAREDE, prof), giro)


# --- camara fria ------------------------------------------------------------

## Parede de geladeira com portas de vidro. Devolve as posicoes das luzes de
## dentro, que quem chama registra como props.
##
## E a parede do fundo de toda loja de conveniencia, e a unica coisa da cena que
## brilha sozinha em branco frio. Faz o fundo da loja puxar o olho, que e o que
## leva o jogador a atravessar o corredor inteiro.
static func geladeira_parede(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, comprimento: float, giro: float,
		portas: int) -> Array[Vector3]:
	var b := Basis(Vector3.UP, giro)
	var prof := 0.72
	var alto := 2.1
	var luzes: Array[Vector3] = []

	# Caixa da camara, escura: e o contorno que faz as portas lerem como vidro
	# recortado em vez de painel colado na parede.
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(comprimento, alto, prof), ESTRUTURA_ESCURA, giro)

	var largura_porta := comprimento / float(portas)
	for k in portas:
		var dx := -comprimento * 0.5 + (float(k) + 0.5) * largura_porta
		KitModular.placa(sup, &"mercado_geladeira",
			centro + b * Vector3(dx, 1.02, prof * 0.5 + FOLGA_PAINEL),
			Vector2(largura_porta - 0.05, 1.84), giro, Color.WHITE, SUBDIVISAO_PAINEL)
		luzes.append(centro + b * Vector3(dx, 1.3, prof * 0.5 - 0.3))

	# Testeira iluminada em cima, onde vai o nome da secao.
	KitModular.caixa_cor(sup, &"mercado_vidro",
		centro + b * Vector3(0.0, alto - 0.12, prof * 0.5 + FOLGA_PAINEL),
		Vector3(comprimento - 0.06, 0.2, 0.03), Color("dbe8ee"), giro)

	_solido(colisao, centro + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(comprimento, alto, prof), giro)
	return luzes


# --- caixa e balcao ---------------------------------------------------------

## Balcao do caixa, com registradora e vitrine quente.
##
## `giro` aponta a frente do balcao, o lado onde o cliente para.
static func balcao(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, comprimento: float, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var prof := 0.68

	KitModular.caixa_cor(sup, &"metal",
		centro + Vector3(0.0, ALTURA_BALCAO * 0.5, 0.0),
		Vector3(comprimento, ALTURA_BALCAO, prof), Color("b9bcb8"), giro)
	# Tampo em tom quente, o unico da loja: e ele que marca onde fica o atendente.
	KitModular.caixa_cor(sup, &"tabua",
		centro + Vector3(0.0, ALTURA_BALCAO + 0.02, 0.0),
		Vector3(comprimento + 0.08, 0.05, prof + 0.08), Color("8f7a5c"), giro)
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, 0.055, 0.0),
		Vector3(comprimento + 0.02, 0.11, prof - 0.1), RODAPE_LOJA, giro)

	# Registradora: corpo, gaveta e visor virado para o cliente.
	var reg := centro + b * Vector3(comprimento * 0.5 - 0.42, 0.0, -0.02)
	KitModular.caixa_cor(sup, &"metal", reg + Vector3(0.0, ALTURA_BALCAO + 0.14, 0.0),
		Vector3(0.36, 0.19, 0.34), Color("4f5250"), giro)
	KitModular.caixa_cor(sup, &"mercado_vidro",
		reg + b * Vector3(0.0, ALTURA_BALCAO + 0.30, 0.13),
		Vector3(0.22, 0.13, 0.03), Color("9fd6c0"), giro)

	# Bandeja de moeda e o pote de canudo, os dois detalhes que sempre existem.
	KitModular.caixa_cor(sup, &"metal",
		centro + b * Vector3(comprimento * 0.5 - 0.86, ALTURA_BALCAO + 0.06, 0.1),
		Vector3(0.2, 0.03, 0.14), Color("6a6d6a"), giro)
	KitModular.caixa_cor(sup, &"metal",
		centro + b * Vector3(-comprimento * 0.5 + 0.3, ALTURA_BALCAO + 0.13, 0.0),
		Vector3(0.1, 0.17, 0.1), Color("c8ccc4"), giro)

	_solido(colisao, centro + Vector3(0.0, ALTURA_BALCAO * 0.5, 0.0),
		Vector3(comprimento, ALTURA_BALCAO + 0.2, prof), giro)


## Vitrine quente do balcao, onde ficam os salgados. Devolve a posicao da luz.
##
## E a unica luz quente da loja. Existe para o balcao nao virar mais um bloco
## branco: uma fonte alaranjada num canto de sala toda branca marca o lugar.
static func caixa_quente(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float) -> Vector3:
	var b := Basis(Vector3.UP, giro)
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, 0.06, 0.0),
		Vector3(0.62, 0.12, 0.44), Color("8e918e"), giro)
	KitModular.caixa_cor(sup, &"mercado_vidro", centro + Vector3(0.0, 0.32, 0.0),
		Vector3(0.58, 0.4, 0.4), Color("f0d8a8"), giro)
	# Duas bandejas com produto dentro do vidro.
	for k in 2:
		KitModular.caixa_cor(sup, &"tabua",
			centro + b * Vector3(0.0, 0.2 + float(k) * 0.16, 0.0),
			Vector3(0.5, 0.06, 0.32), Color("c9a25e"), giro)
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, 0.54, 0.0),
		Vector3(0.62, 0.06, 0.44), Color("8e918e"), giro)
	_solido(colisao, centro + Vector3(0.0, 0.3, 0.0), Vector3(0.66, 0.6, 0.48))
	return centro + Vector3(0.0, 0.36, 0.0)


## Maquina de cafe, ao lado do balcao.
static func maquina_cafe(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.42, 0.0),
		Vector3(0.5, 0.84, 0.5), Color("54575a"), giro)
	KitModular.caixa_cor(sup, &"mercado_vidro", base + b * Vector3(0.0, 0.62, 0.26),
		Vector3(0.3, 0.2, 0.03), Color("c8dcd4"), giro)
	KitModular.caixa_cor(sup, &"metal", base + b * Vector3(0.0, 0.3, 0.2),
		Vector3(0.24, 0.22, 0.12), Color("2e3032"), giro)
	_solido(colisao, base + Vector3(0.0, 0.42, 0.0), Vector3(0.52, 0.84, 0.52))


# --- vitrine e revistas -----------------------------------------------------

## Revisteiro inclinado sob a janela da frente.
##
## Fica de proposito encostado no vidro: e onde a loja de verdade poe as
## revistas, para quem passa na rua ver gente em pe la dentro. Aqui nao ha
## ninguem em pe, e e justamente essa a graca.
static func revisteiro(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, comprimento: float, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, 0.26, 0.0),
		Vector3(comprimento, 0.52, 0.42), ESTRUTURA, giro)

	# Tres niveis inclinados, cada um com a capa aparecendo.
	for nivel in 3:
		var y := 0.56 + float(nivel) * 0.32
		var z := -0.04 - float(nivel) * 0.09
		KitModular.caixa_cor(sup, &"metal", centro + b * Vector3(0.0, y, z),
			Vector3(comprimento, 0.03, 0.3), ESTRUTURA_ESCURA, giro)
		KitModular.placa(sup, _prateleira(nivel + 1),
			centro + b * Vector3(0.0, y + 0.14, z + 0.07),
			Vector2(comprimento - 0.06, 0.28), giro, Color(1.0, 1.0, 1.0))

	_solido(colisao, centro + Vector3(0.0, 0.55, 0.0),
		Vector3(comprimento, 1.1, 0.5), giro)


## Pilha de cestas de compra, junto da entrada.
static func cestas(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	for k in 5:
		# Cada cesta entra um pouco dentro da de baixo e sai um pouco de lado.
		KitModular.caixa_cor(sup, &"metal",
			base + Vector3(0.0, 0.09 + float(k) * 0.085, 0.0),
			Vector3(0.38, 0.16, 0.28),
			Color("9a3f38") if k % 2 == 0 else Color("8c3a33"),
			giro + float(k) * 0.035)
	_solido(colisao, base + Vector3(0.0, 0.25, 0.0), Vector3(0.42, 0.5, 0.32))


## Lixeira de tampa basculante.
static func lixeira(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.35, 0.0),
		Vector3(0.42, 0.7, 0.36), Color("7d807c"), giro)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.73, 0.0),
		Vector3(0.46, 0.06, 0.4), Color("54575a"), giro)
	_solido(colisao, base + Vector3(0.0, 0.35, 0.0), Vector3(0.44, 0.7, 0.38))


## Tapete de entrada. Escuro contra o piso quase branco, entao marca a soleira
## sem precisar de degrau.
static func tapete_entrada(sup: Dictionary, centro: Vector3,
		tamanho: Vector2, giro: float) -> void:
	KitModular.caixa_cor(sup, &"reboco", centro + Vector3(0.0, 0.008, 0.0),
		Vector3(tamanho.x, 0.016, tamanho.y), Color("53565a"), giro)


# --- iluminacao -------------------------------------------------------------

## Calha fluorescente dupla. Devolve a posicao da lampada.
##
## A luz da loja e o personagem principal do comodo: branca, chapada e sem
## sombra, o oposto de tudo que existe la fora. Por isso sao varias calhas em
## linha e nao uma lampada central.
static func calha(sup: Dictionary, teto: float, x: float, z: float,
		comprimento: float, giro: float = 0.0) -> Vector3:
	var centro := Vector3(x, teto - 0.07, z)
	KitModular.caixa_cor(sup, &"metal", centro,
		Vector3(comprimento, 0.1, 0.3), Color("e4e8e4"), giro)
	# Os dois tubos, lado a lado.
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"mercado_vidro",
			centro + Basis(Vector3.UP, giro) * Vector3(0.0, -0.055, lado * 0.07),
			Vector3(comprimento - 0.12, 0.03, 0.09), Color("f2f8f4"), giro)
	return centro + Vector3(0.0, -0.12, 0.0)


## Cartaz de corredor pendurado no teto, virado para os dois lados.
##
## Nao leva o nome da loja. Dentro da loja o nome ja e sabido, e repeti-lo em
## cada corredor faz o cenario parecer montado com as pecas que havia em vez de
## com as pecas certas.
static func placa_corredor(sup: Dictionary, teto: float, x: float, z: float,
		giro: float, cor: Color) -> void:
	for lado in 2:
		KitModular.placa(sup, &"mercado_secao",
			Vector3(x, teto - 0.42, z), Vector2(1.1, 0.28),
			giro + (0.0 if lado == 0 else PI), cor)
	KitModular.caixa_cor(sup, &"metal", Vector3(x, teto - 0.16, z),
		Vector3(0.02, 0.3, 0.02), ESTRUTURA_ESCURA)


# --- fachada ----------------------------------------------------------------

## Frente da loja vista da rua: vidro aceso, faixa de tres cores e o letreiro.
##
## `centro` fica na base, no meio da largura, e `giro` gira a frente para a rua.
## Existe para a loja ser reconhecivel de longe: na nevoa o jogador ve a mancha
## branca e as tres cores muito antes de ler qualquer coisa, e e isso que faz
## ele atravessar a rua para ver o que e.
static func fachada_loja(sup: Dictionary, centro: Vector3, largura: float,
		giro: float, vao: float = 1.8) -> void:
	var b := Basis(Vector3.UP, giro)
	var frente := b * Vector3(0.0, 0.0, 1.0)
	var alto := 2.62

	# A frente inteira avanca SALIENCIA sobre a calcada. Colada na fachada, o
	# vidro e a parede do predio caiam na mesma profundidade e a parede aparecia
	# atraves do vidro conforme o jogador andava.
	var plano := centro + frente * SALIENCIA

	# Laterais que fecham o volume. Sem elas da para ver por dentro da saliencia
	# pela quina, e a loja vira um painel solto na frente do predio.
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"metal",
			centro + frente * (SALIENCIA * 0.5) + b * Vector3(lado * largura * 0.5, alto * 0.5, 0.0),
			Vector3(0.12, alto, SALIENCIA), ESTRUTURA_ESCURA, giro)

	# Vidro do terreo em duas faixas: o vao do meio e da porta e nao pode receber
	# painel, senao a folha abre atras de uma parede.
	var sobra := (largura - vao) * 0.5
	for lado: float in [-1.0, 1.0]:
		if sobra < 0.3:
			continue
		KitModular.placa(sup, &"mercado_vidro",
			plano + b * Vector3(lado * (vao * 0.5 + sobra * 0.5), 1.24, 0.0),
			Vector2(sobra, 2.4), giro, Color("e6f2f4"), SUBDIVISAO_PAINEL)

		# Montantes de aluminio, que quebram o vidro em vaos.
		var montantes := maxi(1, int(round(sobra / 1.3)))
		for k in montantes + 1:
			var dx := lado * (vao * 0.5) + lado * sobra * (float(k) / float(montantes))
			KitModular.caixa_cor(sup, &"metal",
				plano + frente * 0.05 + b * Vector3(dx, 1.24, 0.0),
				Vector3(0.09, 2.4, 0.1), ESTRUTURA, giro)

	# Travessa sobre o vidro, fechando o topo do volume.
	KitModular.caixa_cor(sup, &"metal",
		centro + frente * (SALIENCIA * 0.5) + Vector3(0.0, alto - 0.07, 0.0),
		Vector3(largura + 0.12, 0.14, SALIENCIA + 0.06), ESTRUTURA, giro)

	# Faixa de tres cores acima do vidro. E o codigo visual da loja, e a essa
	# altura ja e a unica coisa legivel na nevoa.
	var cores: Array[Color] = [Color("e27a26"), Color("3a8c54"), Color("c63a34")]
	for i in cores.size():
		KitModular.caixa_cor(sup, &"metal",
			plano + frente * 0.02 + Vector3(0.0, alto + 0.11 + float(i) * 0.14, 0.0),
			Vector3(largura + 0.16, 0.14, 0.1), cores[i], giro)

	# Letreiro aceso, acima da faixa.
	KitModular.placa(sup, &"mercado_letreiro",
		plano + frente * 0.08 + Vector3(0.0, 3.62, 0.0),
		Vector2(minf(largura * 0.72, 3.4), 0.86), giro, Color.WHITE, SUBDIVISAO_PAINEL)

	# Marquise, projetada alem do letreiro.
	KitModular.caixa_cor(sup, &"metal",
		centro + frente * (SALIENCIA + 0.24) + Vector3(0.0, 3.1, 0.0),
		Vector3(largura + 0.24, 0.1, 0.76), ESTRUTURA_ESCURA, giro)
