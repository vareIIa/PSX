## Estoque de verdade: caixa, engradado e saco em tres dimensoes.
##
## Por que este arquivo existe
## ---------------------------
## `KitMercado.estante_estoque` monta a estrutura em caixa lisa e prega UMA
## imagem (`mercado_estoque`) na frente dela. No salao isso funciona: a gondola
## e vista de frente, a dois metros, e o produto e plano mesmo. No estoque nao
## funciona, e a captura `a09_garagem_estante.png` mostra por que — a estante
## aparece de TRES QUARTOS, e de tres quartos uma imagem pregada nao tem
## espessura: as caixas ficam todas no mesmo plano, com a mesma sombra, e a
## estante le como um cartaz de caixas encostado na parede. Foi exatamente o que
## o usuario descreveu: "uma pintura chapada de caixas".
##
## O conserto nao e uma textura melhor. E dar volume a carga:
##
## - Caixa de papelao com ABA: quatro retangulos dobrados para fora no topo. E
##   a aba que diz "aberta", e caixa aberta diz "alguem mexeu aqui".
## - Profundidade DESIGUAL: cada caixa entra um pouco mais ou menos na
##   prateleira. Fileira alinhada e o que mais denuncia geometria repetida.
## - Giro pequeno, de dois a oito graus. Caixa perfeitamente quadrada com a
##   estante nao existe em deposito nenhum.
## - Vaos: prateleira cheia le como parede. O vao e o que diz que a loja tira
##   coisa dali.
##
## Tudo sai de `RandomNumberGenerator` com semente fixa por estante, entao a
## mesma loja monta igual em todas as sessoes e em todos os jogadores da rede.
class_name KitEstoque
extends RefCounted

## Papelao: dois tons, porque caixa velha e caixa nova nao tem a mesma cor, e
## uma fileira de um tom so le como plastico.
const PAPELAO: Array[Color] = [Color("c9a878"), Color("bd9a68"), Color("d2b58c"),
	Color("b08f63")]
## A fita, mais clara que o papelao.
const FITA := Color("ddd6c4")
## Engradado de bebida e de hortifruti.
## Escuros de proposito, e MUITO: `mercado_plastico` tem albedo 238 e a lampada
## do deposito tem energia 2,4 a 3,1. A conta e albedo x tinta x luz, entao a
## tinta precisa valer um TERCO da cor pretendida para o engradado sair
## vermelho em vez de rosa. Com `b3322c` (vermelho de catalogo) ele saiu rosa;
## com `7d211c`, rosa-escuro. Estes valores foram medidos na captura a09/a20.
const ENGRADADO: Array[Color] = [Color("55130f"), Color("102f4c"), Color("2f3616"),
	Color("5e3a08")]
## Estrutura da estante: aco pintado de cinza de deposito. O marrom antigo
## (`8d6f57`) saiu creme na bancada e a estante lia como movel de plastico: o
## papelao e a carga tem de ser a parte clara do quadro, nao a prateleira.
const ACO := Color("3a3e42")
const ACO_ESCURO := Color("24282c")


# --- carga ------------------------------------------------------------------

## Caixa de papelao. `base` no centro da face de baixo.
##
## `aberta`: as quatro abas viradas para fora. `fita`: a tira colada no meio da
## tampa, que e o que faz a caixa fechada ler como fechada e nao como bloco.
static func caixa(sup: Dictionary, base: Vector3, tam: Vector3, giro: float,
		cor: Color, aberta: bool = false, fita: bool = true) -> void:
	var b := Basis(Vector3.UP, giro)
	var meio := base + b * Vector3(0.0, tam.y * 0.5, 0.0)
	KitModular.caixa_cor(sup, &"mercado_papelao", meio, tam, cor, giro)
	if aberta:
		# Abas: quatro placas dobradas para fora na borda de cima. O eixo da
		# dobra e `UP.cross(fora)`, e meia volta de radiano (0,9) e o que faz a
		# aba cair sem deitar no proprio papelao.
		for fora: Vector3 in [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT]:
			var em_z := absf(fora.z) > 0.5
			var largura := (tam.x if em_z else tam.z) - 0.012
			var borda := (tam.z if em_z else tam.x) * 0.5
			var ao_longo := Vector2(fora.x, fora.z)
			var atravessa := Vector2(-fora.z, fora.x)
			var contorno := PackedVector2Array()
			for canto: Vector2 in [Vector2(0.0, -0.5), Vector2(0.16, -0.5),
					Vector2(0.16, 0.5), Vector2(0.0, 0.5)]:
				contorno.append(ao_longo * canto.x + atravessa * (canto.y * largura))
			Peca.prisma(sup, &"mercado_papelao",
				Transform3D(b * Basis(Vector3.UP.cross(fora), 0.9),
					base + b * (fora * borda + Vector3(0.0, tam.y, 0.0))),
				contorno, -0.005, 0.0, cor.darkened(0.1))
	elif fita:
		KitModular.caixa_cor(sup, &"mercado_papelao",
			base + b * Vector3(0.0, tam.y + 0.002, 0.0),
			Vector3(0.07, 0.004, tam.z + 0.004), FITA, giro)


## Engradado de plastico vazado: parede com tres frestas escuras por lado, como
## a cesta do salao. Vazado le como engradado; fechado le como caixa pintada.
static func engradado(sup: Dictionary, base: Vector3, giro: float, cor: Color,
		altura: float = 0.28) -> void:
	var b := Basis(Vector3.UP, giro)
	var tam := Vector3(0.44, altura, 0.32)
	for lado in 4:
		var em_x := lado % 2 == 0
		var sinal := 1.0 if lado < 2 else -1.0
		var comp := tam.x if em_x else tam.z
		var desloca := Vector3(0.0, 0.0, sinal * tam.z * 0.5) if em_x \
			else Vector3(sinal * tam.x * 0.5, 0.0, 0.0)
		var espessura := Vector3(comp, altura, 0.018) if em_x \
			else Vector3(0.018, altura, comp)
		KitModular.caixa_cor(sup, &"mercado_plastico",
			base + b * (desloca + Vector3(0.0, altura * 0.5, 0.0)), espessura, cor, giro)
		for f in 2:
			var y := altura * (0.34 + float(f) * 0.3)
			var fresta := Vector3(comp * 0.72, altura * 0.14, 0.022) if em_x \
				else Vector3(0.022, altura * 0.14, comp * 0.72)
			KitModular.caixa_cor(sup, &"mercado_plastico",
				base + b * (desloca + Vector3(0.0, y, 0.0)), fresta,
				cor.darkened(0.55), giro)
	KitModular.caixa_cor(sup, &"mercado_plastico",
		base + b * Vector3(0.0, 0.012, 0.0), Vector3(tam.x, 0.024, tam.z),
		cor.darkened(0.15), giro)


## Saco de mercadoria: um torno amassado, mais largo embaixo, com a boca torcida.
static func saco(sup: Dictionary, base: Vector3, giro: float, cor: Color,
		altura: float = 0.4, largo: float = 1.0) -> void:
	var b := Basis(Vector3.UP, giro)
	Peca.torno(sup, &"mercado_papelao",
		Transform3D(b.scaled(Vector3(1.25 * largo, 1.0, 0.85 * largo)), base),
		PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(0.19, 0.0), Vector2(0.19, 0.0),
			Vector2(0.20, altura * 0.22), Vector2(0.185, altura * 0.62),
			Vector2(0.12, altura * 0.9), Vector2(0.05, altura),
			Vector2(0.05, altura), Vector2(0.06, altura + 0.03),
			Vector2(0.0, altura + 0.035),
		]), 10, cor)


# --- estante ----------------------------------------------------------------

## Estante de deposito VAZADA: montantes de cantoneira, travessas na frente e
## atras, e as prateleiras. Sem painel de fundo — e o vao entre as travessas
## que faz a estante ler como estante.
##
## Devolve a altura de cada prateleira, para quem for carregar ela.
static func estante(sup: Dictionary, colisao: Array[Dictionary], centro: Vector3,
		comprimento: float, giro: float, niveis: int = 4,
		altura: float = 2.1) -> PackedFloat32Array:
	var b := Basis(Vector3.UP, giro)
	var prof := 0.60
	var alturas := PackedFloat32Array()
	# Montantes: cantoneira em L, que e o perfil da estante de deposito de
	# verdade. Uma caixa quadrada no lugar dele le como pe de mesa.
	for lx: float in [-1.0, 1.0]:
		for lz: float in [-1.0, 1.0]:
			var p := Vector3(lx * (comprimento * 0.5 - 0.03), 0.0, lz * (prof * 0.5 - 0.03))
			var contorno := PackedVector2Array([
				Vector2(0.0, 0.0), Vector2(-lx * 0.05, 0.0),
				Vector2(-lx * 0.05, -lz * 0.014), Vector2(-lx * 0.014, -lz * 0.014),
				Vector2(-lx * 0.014, -lz * 0.05), Vector2(0.0, -lz * 0.05),
			])
			Peca.prisma(sup, &"mercado_chapa", Transform3D(b, centro + b * p),
				contorno, 0.0, altura, ACO)
	# Folga de meio metro acima da ultima prateleira: com as prateleiras
	# repartindo a altura inteira, a carga de cima passava por cima dos
	# montantes e a estante lia como pilha solta.
	for nivel in niveis:
		var y := 0.06 + float(nivel) * ((altura - 0.61) / float(niveis - 1))
		alturas.append(y)
		# Prateleira: chapa fina, um pouco menor que o vao.
		Peca.prisma(sup, &"mercado_chapa", Transform3D(b, centro + Vector3(0.0, 0.0, 0.0)),
			Peca.retangulo_redondo(Vector2(comprimento - 0.09, prof - 0.09), 0.01, 1),
			y - 0.022, y, ACO)
		# Travessas: a da frente mais alta que a prateleira, que e a aba que
		# segura a carga. E ela que aparece de tres quartos.
		for lz: float in [-1.0, 1.0]:
			Peca.prisma(sup, &"mercado_chapa",
				Transform3D(b, centro + b * Vector3(0.0, 0.0, lz * (prof * 0.5 - 0.02))),
				Peca.retangulo_redondo(Vector2(comprimento - 0.02, 0.028), 0.0, 1),
				y - 0.03, y + 0.035, ACO_ESCURO)
	KitModular.solido(colisao, centro + Vector3(0.0, altura * 0.5, 0.0),
		Vector3(comprimento, altura, prof), giro)
	return alturas


## A estante com a carga: para cada prateleira, uma fileira sorteada de caixas,
## engradados e sacos, com vao, giro e profundidade desiguais.
##
## `semente` fixa a loja: a mesma estante monta igual em toda sessao e em todo
## jogador da rede.
static func estante_carregada(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, comprimento: float, giro: float, semente: int,
		niveis: int = 4) -> void:
	var alturas := estante(sup, colisao, centro, comprimento, giro, niveis)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var b := Basis(Vector3.UP, giro)
	for nivel in alturas.size():
		var y: float = alturas[nivel]
		var vao := (alturas[nivel + 1] if nivel + 1 < alturas.size() else y + 0.55) - y - 0.06
		var x := -comprimento * 0.5 + 0.08
		# A prateleira de cima recebe carga leve; a de baixo, a pesada. E como o
		# deposito carrega de verdade, e da a leitura de peso ao movel.
		var pesado := nivel <= 1
		# Quem saiu nas duas ultimas posicoes. Sem esta memoria o sorteio
		# devolvia quatro sacos iguais em fila, que le como padrao repetido —
		# o mesmo defeito da imagem chapada, so em tres dimensoes.
		var ultimos := PackedInt32Array([-1, -1])
		while x < comprimento * 0.5 - 0.2:
			# O vao: uma em cada cinco posicoes fica vazia.
			if rng.randf() < 0.18:
				x += rng.randf_range(0.18, 0.34)
				continue
			var z := rng.randf_range(-0.06, 0.06)
			var torto := rng.randf_range(-0.14, 0.14)
			# 0 engradado, 1 saco, 2 caixa. Tres iguais em fila nao passam.
			var tipo := 0
			for tentativa in 4:
				var sorte := rng.randf()
				tipo = 0 if pesado and sorte < 0.34 else (1 if sorte < 0.52 else 2)
				if tipo != ultimos[0] or tipo != ultimos[1]:
					break
			ultimos[1] = ultimos[0]
			ultimos[0] = tipo
			if tipo == 0:
				var cor: Color = ENGRADADO[rng.randi() % ENGRADADO.size()]
				var pilha := 1 if vao < 0.62 else 2
				for k in pilha:
					engradado(sup, centro + b * Vector3(x + 0.22, y + float(k) * 0.29, z),
						giro + torto * 0.5, cor)
				x += 0.5
			elif tipo == 1:
				# O saco varia de tamanho: sacos do mesmo tamanho em fila leem
				# como copia colada mesmo com cores diferentes.
				var largo := rng.randf_range(0.82, 1.12)
				saco(sup, centro + b * Vector3(x + 0.2 * largo, y, z), giro + torto,
					PAPELAO[rng.randi() % PAPELAO.size()],
					minf(rng.randf_range(0.3, 0.44), vao - 0.1), largo)
				x += 0.42 * largo + rng.randf_range(0.0, 0.08)
			else:
				# Pilha de caixas: uma, duas ou tres, cada uma menor que a de
				# baixo, e a de cima as vezes aberta.
				var larg := rng.randf_range(0.26, 0.42)
				var altura_caixa := rng.randf_range(0.2, 0.3)
				var quantas := clampi(int(vao / (altura_caixa + 0.02)), 1, 3)
				var yy := y
				for k in quantas:
					var t := Vector3(larg * (1.0 - float(k) * 0.08), altura_caixa,
						rng.randf_range(0.26, 0.4))
					var aberta := k == quantas - 1 and rng.randf() < 0.28 \
						and vao - (yy - y) > altura_caixa + 0.16
					caixa(sup, centro + b * Vector3(x + larg * 0.5, yy, z + rng.randf_range(-0.03, 0.03)),
						t, giro + torto + rng.randf_range(-0.06, 0.06),
						PAPELAO[rng.randi() % PAPELAO.size()], aberta)
					yy += altura_caixa
					altura_caixa = maxf(0.16, altura_caixa - 0.03)
				x += larg + rng.randf_range(0.02, 0.1)


## Pilha solta no chao, sobre palete: a entrega que ainda nao subiu na estante.
static func pilha_no_chao(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float, semente: int, altura_max: float = 1.2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var b := Basis(Vector3.UP, giro)
	var y := 0.0
	var larg := 0.5
	while y < altura_max:
		var h := rng.randf_range(0.22, 0.32)
		caixa(sup, base + b * Vector3(rng.randf_range(-0.05, 0.05), y,
			rng.randf_range(-0.05, 0.05)),
			Vector3(larg, h, larg * rng.randf_range(0.7, 0.92)),
			giro + rng.randf_range(-0.12, 0.12),
			PAPELAO[rng.randi() % PAPELAO.size()], false, rng.randf() < 0.6)
		y += h
		larg = maxf(0.3, larg - rng.randf_range(0.02, 0.07))
	KitModular.solido(colisao, base + Vector3(0.0, y * 0.5, 0.0),
		Vector3(0.56, y, 0.5), giro)


# --- bancada ----------------------------------------------------------------

static func bancada_estante(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	estante_carregada(sup, colisao, Vector3.ZERO, 2.4, 0.0, 9137)


static func bancada_carga(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	caixa(sup, Vector3(-0.7, 0.0, 0.0), Vector3(0.4, 0.3, 0.34), 0.1,
		PAPELAO[0], true)
	caixa(sup, Vector3(-0.2, 0.0, 0.0), Vector3(0.36, 0.26, 0.3), -0.2, PAPELAO[1])
	engradado(sup, Vector3(0.3, 0.0, 0.0), 0.15, ENGRADADO[0])
	engradado(sup, Vector3(0.3, 0.29, 0.0), 0.05, ENGRADADO[1])
	saco(sup, Vector3(0.85, 0.0, 0.0), -0.3, PAPELAO[3])


## Palete carregado: estrado de madeira e uma pilha de caixas MISTURADAS.
##
## `KitMercado.palete` empilha cubos de 92 cm com a textura de papelao esticada
## por cima, e a captura da garagem mostrou o resultado: a impressao da textura
## cresce junto e a pilha le como tres caixotes de madeira pintada. Aqui cada
## camada leva duas ou tres caixas de tamanhos diferentes, o que quebra a
## silhueta e mantem a impressao no tamanho certo.
static func palete(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float, semente: int, camadas: int = 3) -> void:
	var b := Basis(Vector3.UP, giro)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	# Estrado: tres travessas e as tabuas por cima.
	for k in 3:
		KitModular.caixa_cor(sup, &"tabua",
			base + b * Vector3(0.0, 0.05, -0.44 + float(k) * 0.44),
			Vector3(1.14, 0.1, 0.12), Color("8a7452"), giro)
	KitModular.caixa_cor(sup, &"tabua", base + Vector3(0.0, 0.13, 0.0),
		Vector3(1.16, 0.06, 1.02), Color("9a8460"), giro)

	var y := 0.16
	for camada in camadas:
		var h := rng.randf_range(0.24, 0.34)
		# Duas caixas largas, ou tres estreitas: a camada nunca e uma so.
		var quantas := 2 if rng.randf() < 0.55 else 3
		var largura := (1.02 - 0.04 * float(quantas - 1)) / float(quantas)
		for k in quantas:
			var x := -0.51 + largura * (float(k) + 0.5) + 0.04 * float(k)
			caixa(sup, base + b * Vector3(x, y, rng.randf_range(-0.06, 0.06)),
				Vector3(largura - 0.02, h, rng.randf_range(0.6, 0.94)),
				giro + rng.randf_range(-0.09, 0.09),
				PAPELAO[rng.randi() % PAPELAO.size()],
				camada == camadas - 1 and rng.randf() < 0.3, rng.randf() < 0.7)
		y += h
	KitModular.solido(colisao, base + Vector3(0.0, y * 0.5, 0.0),
		Vector3(1.16, y, 1.04), giro)
