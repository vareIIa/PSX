## Bar do Ze. Mesmo contrato do MercadoBuilder: dados puros, montados na thread.
##
## Salao unico, pe-direito 3 m. A rua fica em z=0, e o vao e a unica boca —
## entrar e sair pelo mesmo lugar, sem folha correndo. Porta de enrolar recolhida
## no tambor; o bar "e" a rua.
##
##   z=7  +----------------[cervejeira]-----------+[L do balcao]-+
##        |     TV                                |  atendente   |
##        |     mesas      salao                  |  cliente     |
##        |                                       +--------------+
##   z=0  +--------[  vao aberto 2,4 m  ]------------------------+
##       x=0            x=5                                      x=10
class_name BarBuilder
extends RefCounted

const LARGURA := 10.0
const FUNDO := 7.0
const ALTURA := 3.0
const ALTURA_PORTA := 2.45
const RODAPE := 0.10

const PORTA_X0 := 3.8
const PORTA_X1 := 6.2
const CENTRO := (PORTA_X0 + PORTA_X1) * 0.5

const ENTRADA := Vector3(CENTRO, 0.0, 1.15)
const OLHAR := Vector3(CENTRO, 1.50, 5.4)

const PAREDE := Color("c8a43c")

const SAL_ATENDENTE := 211
const SAL_MESA_A := 307
const SAL_MESA_B := 419
const SAL_MESA_C := 523
const IDADE := Vector2i(22, 58)

const MESAS_DENTRO: Array[Vector3] = [
	Vector3(2.45, 0.0, 2.05),
	Vector3(2.50, 0.0, 3.85),
	Vector3(6.35, 0.0, 2.10),
]

const LUZ_QUENTE := Color("ffcf8a")
const LUZ_FRIA := Color("cfe4ff")


static func construir(semente: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente

	var sup: Dictionary = {}
	var props: Array[Dictionary] = []
	var colisao: Array[Dictionary] = []

	_casca(sup, colisao)
	_vao(sup, colisao)
	_salao(sup, colisao, props, semente)
	_luzes(sup, props, rng)

	var tris := 0
	for mat: StringName in sup:
		tris += PSXMesh.dados_triangulos(sup[mat])

	return {
		"superficies": sup, "props": props, "colisao": colisao,
		"triangulos": tris, "entrada": ENTRADA, "olhar": OLHAR,
		"ambiente": "res://resources/fog/fog_bar.tres",
		"mesas": MESAS_DENTRO.size(),
		"cadeiras": 4,
		# Sem deslizante e sem dobradica: o vao e aberto. Interiores._saida
		# cai no ramo que so aciona sair().
		"saida": {
			"pos": Vector3(CENTRO, 1.0, 0.55),
			"tamanho": Vector3(2.6, 2.0, 1.15),
		},
	}


# --- casca ------------------------------------------------------------------

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


static func _teto(sup: Dictionary, material: StringName, canto: Vector2,
		tamanho: Vector2, altura: float, cor: Color = Color.WHITE) -> void:
	# Quad menor que o padrao: o salao e pequeno e o jogador chega perto.
	var dados := PSXMesh.plane_dados(tamanho, PSXMesh.DEFAULT_UV_PER_M, 0.5)
	if not sup.has(material):
		sup[material] = PSXMesh.dados_vazios()
	PSXMesh.acumular_tingido(sup[material], dados,
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
			Vector3(canto.x + tamanho.x * 0.5, altura, canto.y + tamanho.y * 0.5)),
		cor)


static func _casca(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	KitModular.chao(sup, &"bar_piso", Vector3(0.0, 0.0, 0.0),
		Vector2(LARGURA, FUNDO), 0.5)
	# Faixa de ladrilho na soleira. E o que marca a entrada sem degrau.
	KitModular.chao(sup, &"bar_ladrilho", Vector3(PORTA_X0 - 0.3, 0.008, 0.0),
		Vector2(PORTA_X1 - PORTA_X0 + 0.6, 1.35), 0.45)
	_teto(sup, &"bar_teto", Vector2(0.0, 0.0), Vector2(LARGURA, FUNDO), ALTURA)

	# Perimetro anti-horario, normais para dentro. Sul tem o vao.
	_parede(sup, colisao, &"bar_parede", Vector2(LARGURA, 0.0), Vector2(LARGURA, FUNDO),
		ALTURA, [], PAREDE, RODAPE)
	_parede(sup, colisao, &"bar_parede", Vector2(LARGURA, FUNDO), Vector2(0.0, FUNDO),
		ALTURA, [], PAREDE, RODAPE)
	_parede(sup, colisao, &"bar_parede", Vector2(0.0, FUNDO), Vector2(0.0, 0.0),
		ALTURA, [], PAREDE, RODAPE)
	_parede(sup, colisao, &"bar_parede", Vector2(0.0, 0.0), Vector2(LARGURA, 0.0),
		ALTURA, [Vector2(PORTA_X0, PORTA_X1)], PAREDE, RODAPE, true, ALTURA_PORTA)

	colisao.append({"tamanho": Vector3(LARGURA, 0.3, FUNDO),
		"pos": Vector3(LARGURA * 0.5, -0.15, FUNDO * 0.5)})
	colisao.append({"tamanho": Vector3(LARGURA, 0.3, FUNDO),
		"pos": Vector3(LARGURA * 0.5, ALTURA + 0.15, FUNDO * 0.5)})


## Vao da rua visto de dentro: tambor, ombreiras e o painel preto.
##
## O painel e opaco de proposito. O interior vive em y=2000; vidro ou buraco
## mostraria o vazio. Preto le como noite na calcada.
static func _vao(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	var vao := PORTA_X1 - PORTA_X0
	# Painel do vao, um palmo para fora da parede. Colisao nele: atras nao ha
	# cidade. O acionamento de saida e Area3D na frente.
	KitModular.placa(sup, &"bar_vao",
		Vector3(CENTRO, ALTURA_PORTA * 0.5, -0.04),
		Vector2(vao - 0.06, ALTURA_PORTA), PI, Color.WHITE, 0.65)
	KitModular.solido(colisao, Vector3(CENTRO, ALTURA_PORTA * 0.5, -0.05),
		Vector3(vao, ALTURA_PORTA, 0.08))

	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"metal",
			Vector3(CENTRO + lado * (vao * 0.5 + 0.08), ALTURA_PORTA * 0.5, 0.06),
			Vector3(0.16, ALTURA_PORTA + 0.12, 0.18), KitBar.METAL_ESCURO)
	# Tambor com a folha enrolada.
	KitModular.caixa_cor(sup, &"metal",
		Vector3(CENTRO, ALTURA_PORTA + 0.12, 0.08),
		Vector3(vao + 0.28, 0.20, 0.24), Color("6a6c68"))
	KitModular.caixa_cor(sup, &"metal",
		Vector3(CENTRO, ALTURA_PORTA + 0.12, 0.04),
		Vector3(vao + 0.08, 0.14, 0.18), KitBar.METAL_ESCURO)


# --- salao ------------------------------------------------------------------

static func _salao(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], semente: int) -> void:
	_mesas(sup, colisao)
	_balcao(sup, colisao, props, semente)
	_cervejeira(sup, colisao, props)
	_tv(sup, colisao, props)
	_som(sup, props)
	_canto(sup, colisao)
	_gente(props, semente)

	# Telefone na parede leste, perto da entrada. Lugar para salvar, sem
	# copiar o computador de CPF do mercado.
	props.append({
		"tipo": "save",
		"pos": Vector3(LARGURA - 0.45, KitModular.ALTURA_MEIO_FIO, 1.45),
		"giro": -PI * 0.5,
		"local": "Telefone do Bar do Ze",
	})


static func _mesas(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	for i in MESAS_DENTRO.size():
		var p: Vector3 = MESAS_DENTRO[i]
		KitBar.mesa(sup, colisao, p, 0.05 * float(i), i != 1)
		# A mesa da TV nao leva cadeira: quem assiste senta no chao de
		# frente para o tubo, e a cadeira nasceria dentro do corpo.
		if i != 1:
			KitBar.cadeira(sup, colisao, p + Vector3(0.46, 0.0, 0.06),
				PI * 0.5, i % 2 == 0)
			KitBar.cadeira(sup, colisao, p + Vector3(-0.46, 0.0, -0.04),
				-PI * 0.5, i % 2 == 1)
		var tampo := p + Vector3(0.0, KitBar.ALTURA_MESA + 0.04, 0.0)
		KitBar.copo(sup, tampo + Vector3(0.14, 0.0, 0.10))
		if i != 1:
			KitBar.garrafa(sup, tampo + Vector3(-0.12, 0.0, -0.08),
				Color("3f6f4a") if i == 0 else Color("8a3a32"))
		else:
			KitBar.cinzeiro(sup, tampo + Vector3(-0.10, 0.0, 0.08))


static func _balcao(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], semente: int) -> void:
	# L: braco longo no eixo Z, virado para o salao (-X).
	KitBar.balcao(sup, colisao, Vector3(7.55, 0.0, 4.55), 3.1, -PI * 0.5)
	# Braco curto no fundo, virado para o salao (-Z).
	KitBar.balcao(sup, colisao, Vector3(8.70, 0.0, 6.28), 1.7, PI)
	# Prateleira de garrafas atras do atendente. Sem ela o L e um bloco de
	# formica e o fundo do quadro le como parede vazia.
	KitBar.prateleira_garrafas(sup, colisao, Vector3(9.72, 0.0, 4.6), 2.6, -PI * 0.5)
	# Tampo: copos e garrafa do lado do cliente. Sem isso o balcao e uma laje.
	var tampo := Vector3(7.55, KitBar.ALTURA_BALCAO + 0.08, 4.2)
	KitBar.copo(sup, tampo + Vector3(0.18, 0.0, 0.4), -PI * 0.5)
	KitBar.copo(sup, tampo + Vector3(0.22, 0.0, 0.55), -PI * 0.5)
	KitBar.garrafa(sup, tampo + Vector3(0.10, 0.0, 0.15), Color("c45a2a"), -PI * 0.5)
	KitBar.cinzeiro(sup, tampo + Vector3(0.16, 0.0, -0.3), -PI * 0.5)

	var cliente := Vector3(6.90, 0.0, 5.15)
	props.append({
		"tipo": "convidado",
		"pos": Vector3(8.32, 0.0, 4.70),
		"semente": semente + SAL_ATENDENTE,
		"papel": Convidado.Papel.LIVRE,
		"fuma": true,
		"idade_min": 28,
		"idade_max": 62,
		"foco": cliente + Vector3(0.0, 1.4, 0.0),
		"pontos": [],
		"chapado": false,
		"olhos": false,
	})
	props.append({
		"tipo": "convidado",
		"pos": cliente,
		"semente": semente + SAL_MESA_C,
		"papel": Convidado.Papel.LIVRE,
		"fuma": false,
		"idade_min": IDADE.x,
		"idade_max": IDADE.y,
		"foco": Vector3(8.32, 1.4, 4.70),
		"pontos": [],
		"chapado": false,
		"olhos": false,
	})


static func _cervejeira(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary]) -> void:
	var luz := KitBar.cervejeira(sup, colisao,
		Vector3(3.55, 0.0, FUNDO - 0.34), 4.4, PI, 3)
	props.append({
		"tipo": "lampada", "pos": luz,
		"padrao": Lampada.Padrao.ESTAVEL, "semente": 8811,
		"cor": LUZ_FRIA, "energia": 1.25, "alcance": 5.0, "facho": false,
	})


static func _tv(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary]) -> void:
	# Parede oeste, 1,9 m do chao. giro PI/2: o +Z local aponta para +X, o salao.
	var tela := Vector3(0.58, 1.90, 3.35)
	KitBar.tv_gabinete(sup, colisao, tela, PI * 0.5)
	props.append({
		"tipo": "televisao",
		"pos": tela + Vector3(0.08, 0.0, 0.0),
		"giro": PI * 0.5,
	})
	KitBar.cabo(sup, tela + Vector3(0.05, -0.28, 0.0),
		tela + Vector3(0.18, -0.38, 0.22))
	# Cartaz da partida, acima da TV. E o que diz "aqui tem jogo" de longe.
	KitBar.cartaz(sup, Vector3(0.08, 2.55, 4.55), PI * 0.5)
	KitBar.relogio(sup, Vector3(0.08, 2.45, 2.15), PI * 0.5)


static func _som(sup: Dictionary, props: Array[Dictionary]) -> void:
	var cantos: Array[Vector3] = [
		Vector3(0.28, ALTURA - 0.28, 0.35),
		Vector3(LARGURA - 0.28, ALTURA - 0.28, 0.35),
		Vector3(0.28, ALTURA - 0.28, FUNDO - 0.35),
		Vector3(LARGURA - 0.28, ALTURA - 0.28, FUNDO - 0.35),
	]
	var giros: Array[float] = [PI * 0.5, -PI * 0.5, PI * 0.5, -PI * 0.5]
	for i in cantos.size():
		KitBar.caixa_de_som(sup, cantos[i], giros[i])
	# A partida sai daqui. Volume baixo: e o fundo do bar, nao a trilha.
	props.append({
		"tipo": "som_ambiente",
		"pos": Vector3(0.7, 1.9, 3.35),
		"som": &"bar_estadio_loop",
		"volume": -16.0,
		"alcance": 14.0,
	})


static func _canto(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	KitBar.lixeira(sup, colisao, Vector3(0.42, 0.0, FUNDO - 0.55), 0.2)
	KitBar.caixa_plastico(sup, colisao, Vector3(0.48, 0.0, FUNDO - 1.05), -0.3)
	KitBar.vassoura(sup, Vector3(0.32, 0.0, FUNDO - 1.45), 0.4)


static func _gente(props: Array[Dictionary], semente: int) -> void:
	# Dois na mesa da TV, de frente para o jogo. SENTADO e no chao — as
	# cadeiras ficam ao lado, nao embaixo, para o colisor nao nascer dentro
	# do assento. O cliente do balcao ja entrou em `_balcao`.
	var tv := Vector3(0.7, 1.55, 3.35)
	var onde: Array[Vector3] = [
		Vector3(2.20, 0.0, 3.05),
		Vector3(2.55, 0.0, 3.08),
	]
	var sais: Array[int] = [SAL_MESA_A, SAL_MESA_B]
	for i in onde.size():
		props.append({
			"tipo": "convidado",
			"pos": onde[i],
			"semente": semente + sais[i],
			"papel": Convidado.Papel.SENTADO,
			"fuma": i == 0,
			"idade_min": IDADE.x,
			"idade_max": IDADE.y,
			"foco": tv,
			"pontos": [],
			"chapado": false,
			"olhos": false,
		})


static func _luzes(sup: Dictionary, props: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	# Quatro quentes no teto. A quinta e a fria da cervejeira, ja registrada.
	# A sexta e a Omni da Televisao. Teto do compatibility: 16 por objeto;
	# o criterio de aceite pede <= 8 no comodo.
	var pontos: Array[Vector3] = [
		Vector3(CENTRO, ALTURA - 0.28, 1.7),
		Vector3(3.2, ALTURA - 0.28, 3.4),
		Vector3(6.2, ALTURA - 0.28, 3.2),
		Vector3(7.2, ALTURA - 0.28, 4.7),
	]
	for i in pontos.size():
		var p: Vector3 = pontos[i]
		KitBar.pendente(sup, ALTURA, p.x, p.z)
		props.append({
			"tipo": "lampada", "pos": p + Vector3(0.0, -0.12, 0.0),
			"padrao": Lampada.Padrao.ESTAVEL, "semente": rng.randi(),
			"cor": LUZ_QUENTE,
			"energia": 2.3 if i == 3 else 2.0,
			"alcance": 7.5, "facho": false,
		})
