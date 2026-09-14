## Pecas do Bar do Ze. So dados, nada de no: roda na thread com a planta.
##
## A fachada e o contrario da loja HIKARI. La e vidro branco e faixa tricolor.
## Aqui e parede amarela, vao PRETO (porta de enrolar recolhida) e mesa de
## plastico na calcada. Na nevoa essas tres manchas tem de ler antes do nome.
class_name KitBar
extends RefCounted

## Quanto a frente avanca sobre a calcada. Menos que KitMercado.SALIENCIA:
## bar nao e vitrine, e um toldo e um vao.
const SALIENCIA := 0.2

const LARGURA_VAO := 2.4
const ALTURA_VAO := 2.45
const LARGURA_FACHADA := 7.2
const ALTURA_FACHADA := 2.72
## Fundo do vao, medido a partir do plano amarelo, na direcao da rua.
## Tem de ficar atras das mesas (AFASTAMENTO_MESA) e na frente do predio oco.
const PROFUNDIDADE_VAO := 0.88

## Distancia do eixo do vao ate o centro da fileira de mesas na calcada.
##
## Unica fonte. ChunkBuilder desenha as mesas com este numero; a captura da
## rua mira o mesmo. Escrito em dois lugares, a mesa some da foto ou invade
## a rua no primeiro ajuste de toldo.
const AFASTAMENTO_MESA := 1.55
const ESPACAMENTO_MESAS := 1.4
const MESAS_CALCADA := 3

const ALTURA_BALCAO := 1.08
const ALTURA_MESA := 0.72
const LADO_MESA := 0.70
const ALTURA_ASSENTO := 0.44

const AMARELO := Color("c8a43c")
const AMARELO_ESCURO := Color("8a7028")
const VERMELHO := Color("c4322e")
const FORMICA := Color("6e4a30")
const PLASTICO := Color("e2c64a")
const PLASTICO_BRANCO := Color("e6e0d4")
const METAL_ESCURO := Color("3a3c3a")
const VAO_COR := Color("0e0c0a")

const SUBDIVISAO_PAINEL := 0.65


static func _solido(colisao: Array[Dictionary], centro: Vector3,
		tamanho: Vector3, giro: float = 0.0) -> void:
	KitModular.solido(colisao, centro, tamanho, giro)


# --- fachada da rua ---------------------------------------------------------

## Frente do bar vista da calcada: parede amarela, vao preto, toldo, letreiro.
##
## `centro` e a base no meio do vao, `giro` aponta para a rua. O vao NAO leva
## folha: a porta de enrolar fica no tambor, recolhida. Colisao nas ombreiras
## e no painel do vao (o interior vive dois mil metros acima; o buraco e
## desenho, nao passagem).
static func fachada(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var frente := b * Vector3(0.0, 0.0, 1.0)
	var plano := centro + frente * SALIENCIA
	var vao := LARGURA_VAO
	var sobra := (LARGURA_FACHADA - vao) * 0.5
	var alto := ALTURA_FACHADA

	# Laterais do volume, senao da para ver por dentro da saliencia.
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"bar_parede",
			centro + frente * (SALIENCIA * 0.5)
				+ b * Vector3(lado * LARGURA_FACHADA * 0.5, alto * 0.5, 0.0),
			Vector3(0.14, alto, SALIENCIA), AMARELO_ESCURO, giro)

	# Paredes amarelas dos dois lados do vao.
	for lado: float in [-1.0, 1.0]:
		if sobra < 0.3:
			continue
		KitModular.placa(sup, &"bar_parede",
			plano + b * Vector3(lado * (vao * 0.5 + sobra * 0.5), alto * 0.5, 0.0),
			Vector2(sobra, alto), giro, Color.WHITE, SUBDIVISAO_PAINEL)

	# Ombreiras. Colisao nelas, nao no vao de gente — o acionamento e Area3D.
	for lado: float in [-1.0, 1.0]:
		var ombreira := plano + b * Vector3(lado * (vao * 0.5 + 0.09),
			ALTURA_VAO * 0.5, 0.04)
		KitModular.caixa_cor(sup, &"metal", ombreira,
			Vector3(0.18, ALTURA_VAO + 0.16, 0.22), METAL_ESCURO, giro)
		_solido(colisao, ombreira, Vector3(0.18, ALTURA_VAO + 0.16, 0.22), giro)

	# O vao e um TUNEL, nao um tapume. Paredes laterais + piso de ladrilho +
	# fundo preto. Sem as laterais, a placa preta cola nas mesas e le como
	# porta de enrolar fechada.
	var meia := PROFUNDIDADE_VAO * 0.5
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"bar_parede",
			plano + frente * meia + b * Vector3(lado * (vao * 0.5 + 0.03),
				ALTURA_VAO * 0.5, 0.0),
			Vector3(0.08, ALTURA_VAO, PROFUNDIDADE_VAO), AMARELO_ESCURO, giro)
	KitModular.caixa_cor(sup, &"bar_ladrilho",
		plano + frente * meia + Vector3(0.0, 0.03, 0.0),
		Vector3(vao, 0.05, PROFUNDIDADE_VAO), Color.WHITE, giro)
	KitModular.placa(sup, &"bar_vao",
		plano + frente * PROFUNDIDADE_VAO + Vector3(0.0, ALTURA_VAO * 0.5, 0.0),
		Vector2(vao + 0.4, ALTURA_VAO + 0.1), giro, Color.WHITE, 0.7)
	# Vazamento quente no linteo: lampada de dentro, o bar esta aberto.
	KitModular.caixa_cor(sup, &"bar_letreiro",
		plano + frente * (meia * 0.4) + Vector3(0.0, ALTURA_VAO - 0.04, 0.0),
		Vector3(vao - 0.2, 0.05, 0.08), Color("ffcf8a"), giro)
	_solido(colisao, plano + frente * PROFUNDIDADE_VAO
			+ Vector3(0.0, ALTURA_VAO * 0.5, 0.0),
		Vector3(vao + 0.16, ALTURA_VAO, 0.12), giro)
	# Lampada no vao, so silhueta. A Omni e prop do chunk.
	KitModular.caixa_cor(sup, &"metal",
		plano + frente * 0.42 + Vector3(0.0, ALTURA_VAO - 0.22, 0.0),
		Vector3(0.16, 0.08, 0.16), Color("c8a050"), giro)

	# Tambor da porta de enrolar, com a folha recolhida (so silhueta).
	KitModular.caixa_cor(sup, &"metal",
		plano + Vector3(0.0, ALTURA_VAO + 0.14, 0.0) + frente * 0.02,
		Vector3(vao + 0.28, 0.22, 0.28), Color("6a6c68"), giro)
	KitModular.caixa_cor(sup, &"metal",
		plano + Vector3(0.0, ALTURA_VAO + 0.14, 0.0),
		Vector3(vao + 0.08, 0.16, 0.22), METAL_ESCURO, giro)

	# Faixa amarela acima do tambor ate o toldo.
	var faixa_h := alto - (ALTURA_VAO + 0.28)
	if faixa_h > 0.08:
		KitModular.placa(sup, &"bar_parede",
			plano + Vector3(0.0, ALTURA_VAO + 0.28 + faixa_h * 0.5, 0.0),
			Vector2(LARGURA_FACHADA, faixa_h), giro, Color.WHITE, SUBDIVISAO_PAINEL)

	toldo(sup, centro, giro)
	letreiro(sup, centro, giro)


## Toldo listrado sobre o vao, projetado na calcada.
static func toldo(sup: Dictionary, centro: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var frente := b * Vector3(0.0, 0.0, 1.0)
	var y := ALTURA_FACHADA - 0.06
	# Tecido, inclinado um palmo para a rua. A inclinacao e local, depois do giro.
	var base := b * Basis(Vector3.RIGHT, -0.18)
	KitModular.caixa_livre(sup, &"bar_toldo",
		centro + frente * (SALIENCIA + 0.55) + Vector3(0.0, y - 0.04, 0.0),
		Vector3(LARGURA_VAO + 1.6, 0.05, 1.15), base, Color.WHITE)
	# Bracos.
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"metal",
			centro + frente * (SALIENCIA + 0.4)
				+ b * Vector3(lado * (LARGURA_VAO * 0.5 + 0.55), y - 0.18, 0.0),
			Vector3(0.05, 0.36, 0.85), METAL_ESCURO, giro)


## Letreiro aceso. Na nevoa e a mancha amarela de cima.
static func letreiro(sup: Dictionary, centro: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var frente := b * Vector3(0.0, 0.0, 1.0)
	# Logo acima do toldo, projetado da parede: na nevoa e a mancha amarela.
	var pos := centro + frente * (SALIENCIA + 0.22) + Vector3(0.0, 3.02, 0.0)
	KitModular.caixa_cor(sup, &"bar_letreiro",
		pos, Vector3(4.2, 0.84, 0.14), Color.WHITE, giro)
	KitModular.placa(sup, &"bar_letreiro",
		pos + frente * 0.09, Vector2(4.1, 0.80), giro, Color.WHITE,
		SUBDIVISAO_PAINEL)


## Mesas e cadeiras da calcada. Entram no CHUNK, nao no interior: da rua o
## bar nao existe sem elas.
static func mesas_da_calcada(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var frente := b * Vector3(0.0, 0.0, 1.0)
	var lateral := b * Vector3(1.0, 0.0, 0.0)
	var n := MESAS_CALCADA
	for i in n:
		var t := 0.0 if n == 1 else (float(i) / float(n - 1) - 0.5) * 2.0
		var base := (centro + frente * AFASTAMENTO_MESA
			+ lateral * (t * ESPACAMENTO_MESAS))
		base.y = centro.y
		mesa(sup, colisao, base, giro + (0.08 if i == 1 else 0.0), false)
		# Duas cadeiras por mesa, viradas uma para a outra.
		cadeira(sup, colisao, base + lateral * 0.48 + frente * -0.08,
			giro + PI * 0.5, i % 2 == 0)
		cadeira(sup, colisao, base + lateral * -0.48 + frente * 0.06,
			giro - PI * 0.5, i % 2 == 1)
		if i == 1:
			# Haste de guarda-sol. Mesa de calcada brasileira quase sempre tem.
			KitModular.caixa_cor(sup, &"metal",
				base + Vector3(0.0, 1.15, 0.0),
				Vector3(0.04, 2.2, 0.04), Color("6a6c68"), giro)
			KitModular.caixa_cor(sup, &"bar_toldo",
				base + Vector3(0.0, 2.28, 0.0),
				Vector3(1.35, 0.04, 1.35), Color.WHITE, giro)
		if i == 0:
			caixa_plastico(sup, colisao, base + lateral * 0.95 + frente * 0.15, giro)


# --- salao ------------------------------------------------------------------

## Mesa plastica quadrada. `toalha` poe xadrez em cima: dentro do salao uma
## mesa crua e outra vestida e o que evita a fila de clones.
static func mesa(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float, toalha: bool = false) -> void:
	var lado := LADO_MESA
	KitModular.caixa_cor(sup, &"bar_mesa",
		base + Vector3(0.0, ALTURA_MESA, 0.0),
		Vector3(lado, 0.05, lado), PLASTICO_BRANCO, giro)
	# Pe central. Mesa de boteco quase nunca tem quatro pes a mostra.
	KitModular.caixa_cor(sup, &"metal",
		base + Vector3(0.0, ALTURA_MESA * 0.5, 0.0),
		Vector3(0.09, ALTURA_MESA - 0.04, 0.09), METAL_ESCURO, giro)
	KitModular.caixa_cor(sup, &"metal",
		base + Vector3(0.0, 0.03, 0.0),
		Vector3(0.34, 0.05, 0.34), METAL_ESCURO, giro)
	if toalha:
		KitModular.caixa_cor(sup, &"bar_xadrez",
			base + Vector3(0.0, ALTURA_MESA + 0.03, 0.0),
			Vector3(lado - 0.02, 0.012, lado - 0.02), Color.WHITE, giro)
	_solido(colisao, base + Vector3(0.0, ALTURA_MESA * 0.5, 0.0),
		Vector3(lado, ALTURA_MESA + 0.06, lado), giro)


## Cadeira monobloco. Encosto vazado: dois montantes e uma trave, sem chapa.
static func cadeira(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float, amarela: bool = true) -> void:
	var b := Basis(Vector3.UP, giro)
	var cor := PLASTICO if amarela else PLASTICO_BRANCO
	KitModular.caixa_cor(sup, &"bar_cadeira",
		base + Vector3(0.0, ALTURA_ASSENTO, 0.0),
		Vector3(0.38, 0.05, 0.38), cor, giro)
	# Quatro pes.
	for lx: float in [-1.0, 1.0]:
		for lz: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"bar_cadeira",
				base + b * Vector3(lx * 0.14, ALTURA_ASSENTO * 0.5, lz * 0.14),
				Vector3(0.035, ALTURA_ASSENTO, 0.035), cor, giro)
	# Encosto vazado.
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"bar_cadeira",
			base + b * Vector3(lado * 0.14, ALTURA_ASSENTO + 0.22, -0.17),
			Vector3(0.04, 0.40, 0.04), cor, giro)
	KitModular.caixa_cor(sup, &"bar_cadeira",
		base + b * Vector3(0.0, ALTURA_ASSENTO + 0.40, -0.17),
		Vector3(0.32, 0.05, 0.04), cor, giro)
	_solido(colisao, base + Vector3(0.0, 0.42, 0.0),
		Vector3(0.40, 0.84, 0.40), giro)


## Balcao de formica. `giro` aponta a frente, o lado do cliente.
static func balcao(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, comprimento: float, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var prof := 0.64
	var alto := ALTURA_BALCAO
	KitModular.caixa_cor(sup, &"bar_formica",
		centro + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(comprimento, alto, prof), FORMICA, giro)
	KitModular.caixa_cor(sup, &"bar_formica",
		centro + Vector3(0.0, alto + 0.025, 0.0),
		Vector3(comprimento + 0.08, 0.05, prof + 0.08), Color("8a5e3c"), giro)
	# Peitoril do lado do cliente.
	KitModular.caixa_cor(sup, &"bar_formica",
		centro + b * Vector3(0.0, alto + 0.08, prof * 0.5 + 0.02),
		Vector3(comprimento + 0.04, 0.06, 0.06), Color("5a3c28"), giro)
	# Registradora numa ponta.
	var reg := centro + b * Vector3(comprimento * 0.5 - 0.38, 0.0, -0.04)
	KitModular.caixa_cor(sup, &"metal",
		reg + Vector3(0.0, alto + 0.14, 0.0),
		Vector3(0.34, 0.18, 0.30), Color("4a4c4a"), giro)
	KitModular.caixa_cor(sup, &"metal",
		reg + b * Vector3(0.0, alto + 0.28, 0.12),
		Vector3(0.20, 0.10, 0.03), Color("9ad6a8"), giro)
	_solido(colisao, centro + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(comprimento, alto + 0.22, prof), giro)


## Cervejeira de porta de vidro. Devolve a posicao da luz fria de dentro.
static func cervejeira(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, comprimento: float, giro: float,
		portas: int = 3) -> Vector3:
	var b := Basis(Vector3.UP, giro)
	var prof := 0.62
	var alto := 1.85
	KitModular.caixa_cor(sup, &"metal",
		centro + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(comprimento, alto, prof), METAL_ESCURO, giro)
	var larg := comprimento / float(portas)
	for k in portas:
		var dx := -comprimento * 0.5 + (float(k) + 0.5) * larg
		KitModular.placa(sup, &"bar_cervejeira",
			centro + b * Vector3(dx, 0.95, prof * 0.5 + 0.03),
			Vector2(larg - 0.06, 1.62), giro, Color.WHITE, SUBDIVISAO_PAINEL)
	KitModular.caixa_cor(sup, &"metal",
		centro + b * Vector3(0.0, alto - 0.08, prof * 0.5 + 0.03),
		Vector3(comprimento - 0.06, 0.12, 0.03), Color("d0e4ee"), giro)
	_solido(colisao, centro + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(comprimento, alto, prof), giro)
	return centro + b * Vector3(0.0, 1.2, 0.1)


## Gabinete da TV de tubo, na parede. A imagem e o prop Televisao.
static func tv_gabinete(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	KitModular.caixa_cor(sup, &"metal",
		centro + b * Vector3(0.0, 0.0, -0.22),
		Vector3(0.78, 0.64, 0.50), Color("2c2e32"), giro)
	# Moldura preta em volta do tubo.
	KitModular.caixa_cor(sup, &"metal",
		centro + b * Vector3(0.0, 0.0, 0.04),
		Vector3(0.70, 0.54, 0.04), Color("141618"), giro)
	# Prateleira que segura.
	KitModular.caixa_cor(sup, &"metal",
		centro + b * Vector3(0.0, -0.36, -0.1),
		Vector3(0.84, 0.05, 0.36), METAL_ESCURO, giro)
	_solido(colisao, centro + b * Vector3(0.0, -0.05, -0.18),
		Vector3(0.82, 0.72, 0.52), giro)


## Caixa de som preta, cubo na parede ou no teto.
static func caixa_de_som(sup: Dictionary, centro: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	KitModular.caixa_cor(sup, &"metal", centro,
		Vector3(0.28, 0.22, 0.22), Color("1a1c1c"), giro)
	KitModular.caixa_cor(sup, &"metal",
		centro + b * Vector3(0.0, 0.0, 0.12),
		Vector3(0.20, 0.16, 0.03), Color("2e3030"), giro)


## Lixeira de bar, tampa basculante.
static func lixeira(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.32, 0.0),
		Vector3(0.34, 0.64, 0.30), Color("3a5a3c"), giro)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.66, 0.0),
		Vector3(0.38, 0.05, 0.34), METAL_ESCURO, giro)
	_solido(colisao, base + Vector3(0.0, 0.32, 0.0), Vector3(0.36, 0.64, 0.32))


## Caixote de plastico no chao.
static func caixa_plastico(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	KitModular.caixa_cor(sup, &"bar_cadeira", base + Vector3(0.0, 0.16, 0.0),
		Vector3(0.42, 0.32, 0.32), Color("d8a022"), giro)
	_solido(colisao, base + Vector3(0.0, 0.16, 0.0), Vector3(0.44, 0.32, 0.34), giro)


## Vassoura encostada: cabo e cerdas, duas caixas.
static func vassoura(sup: Dictionary, base: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var inclin := Basis(Vector3.RIGHT, 0.12) * b
	KitModular.caixa_livre(sup, &"tabua",
		base + Vector3(0.0, 0.7, 0.0), Vector3(0.03, 1.28, 0.03),
		inclin, Color("8a6a3c"))
	KitModular.caixa_livre(sup, &"tabua",
		base + Vector3(0.0, 0.08, 0.04), Vector3(0.18, 0.12, 0.05),
		inclin, Color("c8b44a"))


## Prateleira atras do balcao, com garrafas. Cores inventadas, sem marca.
static func prateleira_garrafas(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, comprimento: float, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var cores: Array[Color] = [
		Color("c45a2a"), Color("d8c05a"), Color("3f6f4a"),
		Color("8a3a32"), Color("d8d4c8"), Color("5a6a8a"),
	]
	KitModular.caixa_cor(sup, &"tabua",
		centro + Vector3(0.0, 1.15, 0.0),
		Vector3(comprimento, 2.2, 0.28), Color("5a4030"), giro)
	for nivel in 3:
		var y := 0.55 + float(nivel) * 0.55
		KitModular.caixa_cor(sup, &"tabua",
			centro + b * Vector3(0.0, y, 0.08),
			Vector3(comprimento - 0.06, 0.04, 0.22), Color("6a4a34"), giro)
		var n := maxi(6, int(comprimento / 0.16))
		for k in n:
			var dx := -comprimento * 0.5 + 0.12 + float(k) * (comprimento - 0.24) / float(n - 1)
			var alto := 0.22 if (k + nivel) % 3 != 0 else 0.30
			KitModular.caixa_cor(sup, &"metal",
				centro + b * Vector3(dx, y + alto * 0.5 + 0.02, 0.04),
				Vector3(0.07, alto, 0.07), cores[(k + nivel) % cores.size()], giro)
	_solido(colisao, centro + Vector3(0.0, 1.1, 0.0),
		Vector3(comprimento, 2.2, 0.32), giro)


## Pendente do teto: culinaria de boteco, so silhueta. A luz e o prop Lampada.
static func pendente(sup: Dictionary, teto: float, x: float, z: float) -> void:
	KitModular.caixa_cor(sup, &"metal", Vector3(x, teto - 0.18, z),
		Vector3(0.04, 0.28, 0.04), METAL_ESCURO)
	KitModular.caixa_cor(sup, &"metal", Vector3(x, teto - 0.36, z),
		Vector3(0.22, 0.10, 0.22), Color("c8a050"))


## Copo americano. Tres caixas, a silhueta que todo tampo de boteco tem.
static func copo(sup: Dictionary, base: Vector3, giro: float = 0.0) -> void:
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.05, 0.0),
		Vector3(0.055, 0.10, 0.055), Color("b8d0c4"), giro)


## Garrafa de pe. Cor inventada, sem rotulo de marca.
static func garrafa(sup: Dictionary, base: Vector3, cor: Color,
		giro: float = 0.0) -> void:
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.11, 0.0),
		Vector3(0.06, 0.22, 0.06), cor, giro)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.24, 0.0),
		Vector3(0.03, 0.08, 0.03), cor, giro)


## Cinzeiro no tampo.
static func cinzeiro(sup: Dictionary, base: Vector3, giro: float = 0.0) -> void:
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.015, 0.0),
		Vector3(0.12, 0.03, 0.12), Color("8a8c86"), giro)


## Cartaz de partida na parede. `giro` aponta a frente.
static func cartaz(sup: Dictionary, centro: Vector3, giro: float) -> void:
	KitModular.placa(sup, &"bar_cartaz", centro, Vector2(0.72, 0.95), giro,
		Color.WHITE, SUBDIVISAO_PAINEL)
	KitModular.caixa_cor(sup, &"tabua",
		centro + Basis(Vector3.UP, giro) * Vector3(0.0, 0.0, -0.02),
		Vector3(0.76, 0.99, 0.03), Color("3a2a1c"), giro)


## Relogio de parede, so silhueta.
static func relogio(sup: Dictionary, centro: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	KitModular.caixa_cor(sup, &"metal", centro,
		Vector3(0.28, 0.28, 0.05), Color("d8d0c4"), giro)
	KitModular.caixa_cor(sup, &"metal",
		centro + b * Vector3(0.0, 0.0, 0.03),
		Vector3(0.04, 0.08, 0.02), Color("2a2c2a"), giro)


## Cabo em L: desce e corre no chao/prateleira. Dois eixos, sem giro composto.
static func cabo(sup: Dictionary, de: Vector3, ate: Vector3) -> void:
	var joelho := Vector3(de.x, ate.y, de.z)
	KitModular.caixa_cor(sup, &"metal",
		Vector3(de.x, (de.y + ate.y) * 0.5, de.z),
		Vector3(0.02, absf(de.y - ate.y) + 0.02, 0.02), Color("1a1c1c"))
	KitModular.caixa_cor(sup, &"metal",
		(joelho + ate) * 0.5,
		Vector3(absf(ate.x - joelho.x) + 0.02, 0.02, absf(ate.z - joelho.z) + 0.02),
		Color("1a1c1c"))
