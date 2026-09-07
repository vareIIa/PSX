## Movel para interior de casa. So dados, nada de no: roda na thread junto com o
## resto da construcao do interior.
##
## Tudo aqui e caixa. Nao e limitacao de ferramenta, e o metodo do PS1: um sofa
## de verdade daquela epoca tinha umas dez caixas e o resto era desenhado na
## textura. A leitura vem da silhueta e da cor, nao da malha, e numa tela de
## 480x270 com nevoa por cima o poligono a mais nao aparece.
##
## A regra que segura a cena de pe: movel encostado na parede, chao livre no
## meio. Sala com movel espalhado le como loja de moveis; sala com o vazio no
## centro le como casa onde alguem mora.
class_name KitCasa
extends RefCounted

# --- paleta -----------------------------------------------------------------
# Cores de casa japonesa dos anos 90, tudo dessaturado. Cor viva num interior de
# horror puxa o olho para o movel, e o olho tem que ir para os cantos.
const MADEIRA := Color("8a6b4a")
const MADEIRA_ESCURA := Color("5d452f")
const TECIDO := Color("7a6a58")
const TECIDO_CLARO := Color("9b8a72")
const METAL_FRIO := Color("aab0b4")
const ESMALTE := Color("d8d4c8")
const TAPETE := Color("8f4a3c")

## Lombadas de livro. Sete cores bastam: a estante e lida de longe.
const LOMBADAS: Array[Color] = [
	Color("6b4a3a"), Color("3f5a4a"), Color("7a6c3a"), Color("4a4f6b"),
	Color("6b3a3a"), Color("55503f"), Color("38505c"),
]


## Registra colisao de um movel. Movel sem colisao e o erro que faz o jogador
## atravessar o sofa e perder a fe no comodo inteiro.
##
## O giro entra no calculo porque a forma de colisao nao guarda rotacao: sem ele
## a estante virada de lado deixava um bloco invisivel atravessado na sala.
static func _solido(colisao: Array[Dictionary], centro: Vector3,
		tamanho: Vector3, giro: float = 0.0) -> void:
	KitModular.solido(colisao, centro, tamanho, giro)


# --- sala -------------------------------------------------------------------

## Sofa de tres lugares. `giro` gira em torno de Y; a 0 o encosto fica em -Z e
## quem senta olha para +Z.
static func sofa(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float = 0.0, cor: Color = TECIDO) -> void:
	var b := Basis(Vector3.UP, giro)
	var larg := 1.95
	var prof := 0.82

	# Assento um pouco acima do chao: sofa apoiado direto no piso vira bloco.
	_peca(sup, &"reboco", centro, Vector3(larg, 0.34, prof), cor, b,
		Vector3(0.0, 0.30, 0.0))
	# Pes escuros so na frente. Atras ninguem ve, e sao duas caixas a menos.
	for lado: float in [-1.0, 1.0]:
		_peca(sup, &"tabua", centro, Vector3(0.09, 0.13, 0.09), MADEIRA_ESCURA, b,
			Vector3(lado * (larg * 0.5 - 0.12), 0.065, prof * 0.5 - 0.1))

	# Encosto inclinado. E o unico angulo nao reto do movel, e e ele que tira o
	# sofa da cara de caixote.
	_peca(sup, &"reboco", centro, Vector3(larg, 0.66, 0.20), cor, b,
		Vector3(0.0, 0.62, -prof * 0.5 + 0.06), PSXMesh.FACE_TODAS, -0.10)

	for lado: float in [-1.0, 1.0]:
		_peca(sup, &"reboco", centro, Vector3(0.20, 0.32, prof), cor, b,
			Vector3(lado * (larg * 0.5 - 0.1), 0.60, 0.0))

	# Almofadas, uma torta. Todas alinhadas leem como catalogo.
	for k in 3:
		var dx := (float(k) - 1.0) * 0.58
		_peca(sup, &"reboco", centro, Vector3(0.52, 0.12, prof - 0.14),
			TECIDO_CLARO if k == 1 else cor, b, Vector3(dx, 0.53, 0.02),
			PSXMesh.FACE_TODAS, 0.13 if k == 2 else 0.0, Vector3.UP)

	_solido(colisao, centro + b * Vector3(0.0, 0.45, 0.0), Vector3(larg, 0.9, prof), giro)


## Poltrona. Mesmo vocabulario do sofa, um lugar so.
static func poltrona(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float = 0.0, cor: Color = TECIDO) -> void:
	var b := Basis(Vector3.UP, giro)
	_peca(sup, &"reboco", centro, Vector3(0.78, 0.34, 0.78), cor, b,
		Vector3(0.0, 0.30, 0.0))
	_peca(sup, &"reboco", centro, Vector3(0.78, 0.60, 0.18), cor, b,
		Vector3(0.0, 0.60, -0.30), PSXMesh.FACE_TODAS, -0.12)
	for lado: float in [-1.0, 1.0]:
		_peca(sup, &"reboco", centro, Vector3(0.16, 0.30, 0.78), cor, b,
			Vector3(lado * 0.31, 0.58, 0.0))
	_peca(sup, &"reboco", centro, Vector3(0.5, 0.11, 0.62), TECIDO_CLARO, b,
		Vector3(0.0, 0.52, 0.03))
	_solido(colisao, centro + b * Vector3(0.0, 0.45, 0.0), Vector3(0.82, 0.9, 0.82), giro)


## Mesa de centro baixa, com o que ficou em cima dela.
##
## Os objetos soltos sao o ponto: mesa limpa le como cenario, mesa com uma xicara
## e uma revista largada le como alguem que levantou faz cinco minutos.
static func mesa_centro(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float = 0.0) -> void:
	var b := Basis(Vector3.UP, giro)
	var larg := 1.05
	var prof := 0.58
	var h := 0.40

	_peca(sup, &"tabua", centro, Vector3(larg, 0.05, prof), MADEIRA, b,
		Vector3(0.0, h, 0.0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_peca(sup, &"tabua", centro, Vector3(0.06, h, 0.06), MADEIRA_ESCURA, b,
				Vector3(sx * (larg * 0.5 - 0.08), h * 0.5, sz * (prof * 0.5 - 0.08)))
	# Travessa baixa, com uma revista largada em cima.
	_peca(sup, &"tabua", centro, Vector3(larg - 0.2, 0.03, prof - 0.2),
		MADEIRA_ESCURA, b, Vector3(0.0, 0.13, 0.0))
	_peca(sup, &"tabua", centro, Vector3(0.22, 0.02, 0.3), Color("bfb49c"), b,
		Vector3(-0.2, 0.155, 0.0), PSXMesh.FACE_TODAS, 0.4, Vector3.UP)

	# Xicara e cinzeiro.
	_peca(sup, &"reboco", centro, Vector3(0.08, 0.09, 0.08), ESMALTE, b,
		Vector3(0.28, h + 0.07, 0.08))
	_peca(sup, &"metal", centro, Vector3(0.14, 0.03, 0.14), METAL_FRIO, b,
		Vector3(0.05, h + 0.04, -0.14))

	_solido(colisao, centro + b * Vector3(0.0, h * 0.5, 0.0), Vector3(larg, h + 0.05, prof), giro)


## Televisao de tubo sobre rack. A tela e o unico emissivo forte da sala, e e por
## isso que ela ancora a composicao: o olho vai nela antes de qualquer coisa.
static func televisao(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float = 0.0, ligada: bool = true) -> void:
	var b := Basis(Vector3.UP, giro)

	_peca(sup, &"tabua", centro, Vector3(1.15, 0.06, 0.5), MADEIRA, b,
		Vector3(0.0, 0.46, 0.0))
	_peca(sup, &"tabua", centro, Vector3(1.15, 0.04, 0.46), MADEIRA_ESCURA, b,
		Vector3(0.0, 0.22, 0.0))
	for lado: float in [-1.0, 1.0]:
		_peca(sup, &"tabua", centro, Vector3(0.05, 0.46, 0.46), MADEIRA_ESCURA, b,
			Vector3(lado * 0.55, 0.23, 0.0))
	# Fita de video na prateleira de baixo.
	_peca(sup, &"tabua", centro, Vector3(0.19, 0.03, 0.11), Color("2e2a26"), b,
		Vector3(-0.3, 0.26, 0.06))

	# Corpo do aparelho, mais fundo que largo, como tubo de verdade.
	_peca(sup, &"metal", centro, Vector3(0.66, 0.54, 0.56), Color("6f6a62"), b,
		Vector3(0.0, 0.76, 0.0))
	# Moldura escura antes do vidro: e ela que faz a tela parecer afundada no
	# gabinete em vez de colada por fora.
	_peca(sup, &"metal", centro, Vector3(0.56, 0.44, 0.02), Color("1a1815"), b,
		Vector3(0.0, 0.78, 0.285))
	_peca(sup, &"janela_acesa" if ligada else &"vitrine", centro,
		Vector3(0.48, 0.36, 0.01),
		Color("9fb6c4") if ligada else Color("2b2f31"), b,
		Vector3(0.0, 0.78, 0.295))
	_peca(sup, &"metal", centro, Vector3(0.06, 0.06, 0.01), Color("47423b"), b,
		Vector3(0.26, 0.60, 0.29))
	# Antena em V, inclinada em torno do eixo da frente.
	for lado: float in [-1.0, 1.0]:
		_peca(sup, &"metal", centro, Vector3(0.012, 0.42, 0.012), METAL_FRIO, b,
			Vector3(lado * 0.12, 1.22, -0.1), PSXMesh.FACE_TODAS,
			lado * 0.5, Vector3.FORWARD)

	_solido(colisao, centro + b * Vector3(0.0, 0.5, 0.0), Vector3(1.15, 1.0, 0.5), giro)


## Estante com livros. Os livros sao o detalhe mais barato e mais rentavel do
## comodo: uma fileira de lombadas de altura irregular le como colecao de alguem.
static func estante(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float = 0.0, semente: int = 0) -> void:
	var b := Basis(Vector3.UP, giro)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var larg := 1.0
	var alt := 1.85
	var prof := 0.32

	# Caixa aberta: fundo, laterais e topo.
	_peca(sup, &"tabua", centro, Vector3(larg, alt, 0.03), MADEIRA_ESCURA, b,
		Vector3(0.0, alt * 0.5, -prof * 0.5))
	for lado: float in [-1.0, 1.0]:
		_peca(sup, &"tabua", centro, Vector3(0.04, alt, prof), MADEIRA, b,
			Vector3(lado * larg * 0.5, alt * 0.5, 0.0))
	_peca(sup, &"tabua", centro, Vector3(larg, 0.04, prof), MADEIRA, b,
		Vector3(0.0, alt, 0.0))

	var alturas: Array[float] = [0.32, 0.72, 1.12, 1.5]
	for prateleira in alturas.size():
		var y: float = alturas[prateleira]
		_peca(sup, &"tabua", centro, Vector3(larg - 0.06, 0.03, prof), MADEIRA, b,
			Vector3(0.0, y, 0.0))

		# Livros encostados a esquerda, com vao no fim. Prateleira cheia ate a
		# borda le como textura repetida.
		var x := -larg * 0.5 + 0.06
		var limite := rng.randf_range(0.45, 0.92) * (larg - 0.12)
		while x < -larg * 0.5 + 0.06 + limite:
			var esp := rng.randf_range(0.025, 0.055)
			var altura_livro := rng.randf_range(0.2, 0.3)
			_peca(sup, &"tabua", centro, Vector3(esp, altura_livro, prof - 0.09),
				LOMBADAS[rng.randi() % LOMBADAS.size()], b,
				Vector3(x + esp * 0.5, y + 0.015 + altura_livro * 0.5, 0.02))
			x += esp + 0.004

		# Um livro caido por cima da fileira, numa prateleira so.
		if prateleira == 1:
			_peca(sup, &"tabua", centro, Vector3(0.16, 0.03, 0.21), LOMBADAS[2], b,
				Vector3(0.2, y + 0.035, 0.0), PSXMesh.FACE_TODAS, 0.25, Vector3.UP)

	_solido(colisao, centro + b * Vector3(0.0, alt * 0.5, 0.0), Vector3(larg, alt, prof), giro)


## Tapete, em duas camadas: o pano e a barra de acabamento em volta.
##
## As alturas nao sao decorativas, sao o conserto de um piscar. A primeira
## versao punha o pano a 8 mm do piso e a barra a 6 mm, e as duas caixas com a
## BASE em y=0, no mesmo plano do chao. Com o snap de vertice do contrato PSX
## essa folga desaparece na projecao, e o tapete inteiro piscava contra o piso
## conforme a camera andava — o mesmo defeito ja documentado no canteiro das
## arvores, onde a regra saiu: dois centimetros, nao cinco milimetros.
##
## Aqui a barra sobe para 2 cm e o pano para 3,4 cm, e nenhuma das duas encosta
## no piso: as bases ficam em 1,4 cm e 2,6 cm.
static func tapete(sup: Dictionary, centro: Vector3, tamanho: Vector2,
		giro: float = 0.0, cor: Color = TAPETE) -> void:
	# Sem face de baixo: ela fica abaixo do proprio tapete, ninguem a ve, e e
	# justamente ela que chegava perto demais do piso.
	const SEM_BASE := PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE
	KitModular.caixa_cor(sup, &"reboco", centro + Vector3(0.0, 0.030, 0.0),
		Vector3(tamanho.x, 0.008, tamanho.y), cor, giro, SEM_BASE)
	KitModular.caixa_cor(sup, &"reboco", centro + Vector3(0.0, 0.018, 0.0),
		Vector3(tamanho.x + 0.1, 0.008, tamanho.y + 0.1), cor.darkened(0.35),
		giro, SEM_BASE)


## Abajur de chao. Devolve a posicao da lampada, que quem chama registra como
## prop: luz e no, e no nao pode ser criado na thread.
static func abajur(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float = 0.0) -> Vector3:
	var b := Basis(Vector3.UP, giro)
	_peca(sup, &"metal", base, Vector3(0.26, 0.03, 0.26), Color("4a453c"), b,
		Vector3(0.0, 0.015, 0.0))
	_peca(sup, &"metal", base, Vector3(0.03, 1.28, 0.03), Color("55503f"), b,
		Vector3(0.0, 0.64, 0.0))
	# Cupula sem tampa embaixo, para a luz nao parecer sair de um bloco fechado.
	_peca(sup, &"reboco", base, Vector3(0.32, 0.26, 0.32), Color("d6c49a"), b,
		Vector3(0.0, 1.4, 0.0), PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE)
	_solido(colisao, base + Vector3(0.0, 0.7, 0.0), Vector3(0.3, 1.4, 0.3))
	return base + Vector3(0.0, 1.32, 0.0)


## Cupula pendurada no teto. Devolve a posicao da lampada.
##
## Existe porque luz sem luminaria e o defeito mais comum de interior montado por
## codigo: o comodo fica iluminado e o teto vazio, e o olho percebe que a luz vem
## de lugar nenhum antes de saber dizer por que.
static func luminaria_teto(sup: Dictionary, teto: float, x: float, z: float) -> Vector3:
	var base := Vector3(x, 0.0, z)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, teto - 0.14, 0.0),
		Vector3(0.025, 0.28, 0.025), Color("3a352c"))
	KitModular.caixa_cor(sup, &"reboco", base + Vector3(0.0, teto - 0.38, 0.0),
		Vector3(0.42, 0.20, 0.42), Color("e0cfa4"), 0.0,
		PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE)
	# A lampada dentro da cupula. Sem ela, quem passa por baixo olha para cima e
	# ve um buraco: a face de baixo foi removida e as de dentro sao descartadas
	# por cull_back, entao a cupula fica vazada justamente no angulo em que o
	# jogador mais olha para ela.
	KitModular.caixa_cor(sup, &"janela_acesa", base + Vector3(0.0, teto - 0.40, 0.0),
		Vector3(0.11, 0.13, 0.11), Color("fff0cc"))
	return base + Vector3(0.0, teto - 0.44, 0.0)


## Calha fluorescente rente ao teto, para a cozinha.
static func calha_teto(sup: Dictionary, teto: float, x: float, z: float,
		comprimento: float = 1.1) -> Vector3:
	var base := Vector3(x, teto - 0.06, z)
	KitModular.caixa_cor(sup, &"metal", base, Vector3(comprimento, 0.09, 0.18),
		Color("c8ccc6"))
	KitModular.caixa_cor(sup, &"janela_acesa", base + Vector3(0.0, -0.05, 0.0),
		Vector3(comprimento - 0.08, 0.02, 0.13), Color("e8f0ea"))
	return base + Vector3(0.0, -0.1, 0.0)


## Quadro na parede. `giro` segue KitModular.parede_livre.
static func quadro(sup: Dictionary, centro: Vector3, tamanho: Vector2,
		giro: float, cor: Color = Color("6a6152")) -> void:
	KitModular.parede_livre(sup, &"tabua", centro, tamanho + Vector2(0.07, 0.07),
		giro, MADEIRA_ESCURA)
	# A arte entra a frente da moldura, senao as duas faces coincidem e brigam.
	# Tres centimetros e nao um: com o snap de vertice, um centimetro a dois
	# metros de distancia ja nao separa os dois planos e o quadro cintila.
	var frente := Vector3(sin(giro), 0.0, cos(giro)) * 0.030
	KitModular.parede_livre(sup, &"terra", centro + frente, tamanho, giro, cor)


## Relogio de parede. Ponteiros parados numa hora qualquer: relogio sem ponteiro
## le como prato pendurado.
static func relogio(sup: Dictionary, centro: Vector3, giro: float) -> void:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	KitModular.parede_livre(sup, &"reboco", centro, Vector2(0.3, 0.3), giro,
		Color("d8d2c0"))
	# Ponteiros bem a frente do mostrador. Seis milimetros era o menor
	# afastamento do arquivo inteiro, e o relogio piscava de qualquer distancia.
	KitModular.parede_livre(sup, &"tabua", centro + frente * 0.022,
		Vector2(0.02, 0.11), giro, Color("22201c"))
	KitModular.parede_livre(sup, &"tabua", centro + frente * 0.030,
		Vector2(0.08, 0.02), giro, Color("22201c"))


## Cortina de janela, em painel duplo com dobras.
##
## Cada dobra e uma caixa fina de largura levemente diferente. E o truque de
## sempre: a silhueta irregular faz o pano ler como pano, e a malha continua
## sendo caixa.
static func cortina(sup: Dictionary, centro: Vector3, largura: float,
		altura: float, giro: float, cor: Color = Color("9a8f78")) -> void:
	var lateral := Vector3(cos(giro), 0.0, -sin(giro))
	var painel := largura * 0.34
	for lado: float in [-1.0, 1.0]:
		var base_x := lado * (largura * 0.5 - painel * 0.5)
		for dobra in 4:
			var t := (float(dobra) - 1.5) * (painel / 4.0)
			var tom := cor.darkened(0.10 if dobra % 2 == 0 else 0.0)
			KitModular.caixa_cor(sup, &"reboco", centro + lateral * (base_x + t),
				Vector3(painel / 4.0 + 0.012, altura, 0.05), tom, giro)
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, altura * 0.5 + 0.05, 0.0),
		Vector3(largura + 0.16, 0.03, 0.03), METAL_FRIO, giro)


## Vaso com planta. As folhas sao quads cruzados com recorte por alpha, que e
## exatamente como o PS1 fazia vegetacao.
static func vaso_planta(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, escala: float = 1.0) -> void:
	KitModular.caixa_cor(sup, &"terra", base + Vector3(0.0, 0.16 * escala, 0.0),
		Vector3(0.26, 0.32, 0.26) * escala, Color("7a5340"))
	KitModular.caixa_cor(sup, &"terra", base + Vector3(0.0, 0.33 * escala, 0.0),
		Vector3(0.22, 0.03, 0.22) * escala, Color("2e2419"))
	for k in 3:
		KitModular.parede_livre(sup, &"tabua",
			base + Vector3(0.0, 0.67 * escala, 0.0),
			Vector2(0.44, 0.62) * escala, float(k) * PI / 3.0, Color("47603f"))
	_solido(colisao, base + Vector3(0.0, 0.2 * escala, 0.0),
		Vector3(0.3, 0.4, 0.3) * escala)


# --- cozinha ----------------------------------------------------------------

## Bancada corrida com portas e pia. `comprimento` corre no eixo local X.
static func bancada(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, comprimento: float, giro: float = 0.0,
		com_pia: bool = true) -> void:
	var b := Basis(Vector3.UP, giro)
	var prof := 0.6
	var h := 0.88

	_peca(sup, &"tabua", centro, Vector3(comprimento, 0.06, prof), Color("cfc6b0"), b,
		Vector3(0.0, h, 0.0))
	_peca(sup, &"tabua", centro, Vector3(comprimento, h - 0.14, prof - 0.06), MADEIRA, b,
		Vector3(0.0, (h - 0.14) * 0.5 + 0.08, 0.0))
	# Rodape recuado, o vao onde o pe entra. Sem ele o armario parece bloco
	# apoiado no chao.
	_peca(sup, &"tabua", centro, Vector3(comprimento, 0.08, prof - 0.2), Color("3b332a"), b,
		Vector3(0.0, 0.04, -0.06))

	var portas := maxi(1, int(comprimento / 0.55))
	for k in portas:
		var x := -comprimento * 0.5 + (float(k) + 0.5) * (comprimento / float(portas))
		_peca(sup, &"tabua", centro,
			Vector3(comprimento / float(portas) - 0.03, h - 0.24, 0.02),
			MADEIRA_ESCURA, b, Vector3(x, h * 0.5 + 0.02, prof * 0.5 - 0.02))
		_peca(sup, &"metal", centro, Vector3(0.03, 0.09, 0.02), METAL_FRIO, b,
			Vector3(x + 0.16, h * 0.5 + 0.02, prof * 0.5 - 0.03))

	if com_pia:
		_peca(sup, &"metal", centro, Vector3(0.46, 0.02, 0.36), METAL_FRIO, b,
			Vector3(comprimento * 0.5 - 0.4, h + 0.031, 0.0))
		_peca(sup, &"metal", centro, Vector3(0.03, 0.26, 0.03), METAL_FRIO, b,
			Vector3(comprimento * 0.5 - 0.4, h + 0.16, -0.2))
		_peca(sup, &"metal", centro, Vector3(0.03, 0.03, 0.16), METAL_FRIO, b,
			Vector3(comprimento * 0.5 - 0.4, h + 0.28, -0.13))

	_solido(colisao, centro + b * Vector3(0.0, h * 0.5, 0.0), Vector3(comprimento, h, prof), giro)


static func geladeira(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float = 0.0) -> void:
	var b := Basis(Vector3.UP, giro)
	var t := Vector3(0.62, 1.62, 0.62)
	_peca(sup, &"metal", base, t, ESMALTE, b, Vector3(0.0, t.y * 0.5, 0.0))
	# Fresta entre freezer e geladeira, e os dois puxadores.
	_peca(sup, &"metal", base, Vector3(t.x, 0.015, 0.01), Color("8d8880"), b,
		Vector3(0.0, 1.18, t.z * 0.5))
	for y: float in [0.95, 1.36]:
		_peca(sup, &"metal", base, Vector3(0.03, 0.22, 0.04), METAL_FRIO, b,
			Vector3(t.x * 0.5 - 0.09, y, t.z * 0.5 + 0.02))
	_solido(colisao, base + b * Vector3(0.0, t.y * 0.5, 0.0), t, giro)


static func mesa_jantar(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float = 0.0) -> void:
	var b := Basis(Vector3.UP, giro)
	var larg := 1.15
	var prof := 0.75
	var h := 0.73
	_peca(sup, &"tabua", centro, Vector3(larg, 0.05, prof), MADEIRA, b,
		Vector3(0.0, h, 0.0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_peca(sup, &"tabua", centro, Vector3(0.07, h, 0.07), MADEIRA_ESCURA, b,
				Vector3(sx * (larg * 0.5 - 0.09), h * 0.5, sz * (prof * 0.5 - 0.09)))
	_solido(colisao, centro + b * Vector3(0.0, h * 0.5, 0.0), Vector3(larg, h, prof), giro)


static func cadeira(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float = 0.0) -> void:
	var b := Basis(Vector3.UP, giro)
	_peca(sup, &"tabua", centro, Vector3(0.42, 0.04, 0.42), MADEIRA, b,
		Vector3(0.0, 0.45, 0.0))
	_peca(sup, &"tabua", centro, Vector3(0.4, 0.5, 0.04), MADEIRA, b,
		Vector3(0.0, 0.72, -0.19))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_peca(sup, &"tabua", centro, Vector3(0.045, 0.45, 0.045), MADEIRA_ESCURA, b,
				Vector3(sx * 0.17, 0.225, sz * 0.17))
	_solido(colisao, centro + b * Vector3(0.0, 0.35, 0.0), Vector3(0.44, 0.7, 0.44), giro)


# --- interno ----------------------------------------------------------------

## Coloca uma caixa tingida em coordenada local do movel.
##
## `deslocamento` e sempre medido no eixo do movel, e `inclinacao` gira so a
## peca, em torno de `eixo`. Sao coisas separadas de proposito: o encosto do sofa
## deita para tras mas continua posicionado pelo eixo do sofa, e usar a base
## inclinada para as duas coisas jogaria o encosto para fora do movel.
static func _peca(sup: Dictionary, material: StringName, ancora: Vector3,
		tamanho: Vector3, cor: Color, base: Basis, deslocamento: Vector3,
		faces: int = PSXMesh.FACE_TODAS,
		inclinacao: float = 0.0, eixo: Vector3 = Vector3.RIGHT) -> void:
	if not sup.has(material):
		sup[material] = PSXMesh.dados_vazios()
	var orientacao := base if is_zero_approx(inclinacao) else base * Basis(eixo, inclinacao)
	PSXMesh.acumular_tingido(sup[material],
		PSXMesh.box_dados(tamanho, 0.8, PSXMesh.MAX_QUAD_M, Color.WHITE, faces),
		Transform3D(orientacao, ancora + base * deslocamento), cor)
