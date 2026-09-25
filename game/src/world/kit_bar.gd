## Pecas do Bar do Seu Ze. So dados, nada de no: roda na thread do chunk.
##
## Este bar NAO e um interior. Nao ha porta, nao ha acionamento e nao ha
## teleporte: o salao e o terreo vazado do proprio predio, construido no chunk,
## em coordenada de mundo, com a parede da frente simplesmente ausente. Quem
## anda na calcada ve o balcao, a cervejeira e a gente la dentro, e entra
## andando porque nao ha nada para atravessar — que e o que um bar de esquina e.
##
## O que isso custa, e por que vale: o salao inteiro entra no orcamento de
## triangulos do chunk (`verificar_cidade.py`), disputando com predio, calcada e
## transito, e nao no orcamento folgado de um interior que so existe quando o
## jogador esta dentro dele. Por isso cada peca aqui e caixa e placa, e a
## profundidade e a do predio (`ChunkBuilder.PROF_PREDIO`), nao a que se quisesse.
##
## A versao anterior era um interior em Interiores.DESLOCAMENTO com um recuo de
## 1,25 m fingindo de salao na calcada. Da rua lia como buraco preto, e entrar
## dependia de acionar uma area. Ver [[o vao do bar]] no PROMPT.
class_name KitBar
extends RefCounted

## Pe-direito do salao. Igual ao andar do resto da cidade: o predio continua
## em cima do bar, e o forro do terreo e o piso do primeiro andar.
const ALTURA_SALAO := KitModular.ALTURA_ANDAR
## Espessura do forro, e o topo da casca do salao (a boca e o zero): a massa do
## predio de cima comeca ai.
const FORRO := 0.1
const ALTURA_CASCA := ALTURA_SALAO + FORRO
## Espessura das paredes que sobraram (fundo e laterais).
const ESPESSURA := 0.2
## Largura do pilar de canto que segura a verga. Sem ele o terreo vazado le
## como predio flutuando, e nao como bar.
const PILAR := 0.5
## Altura livre da boca. Acima disso e a verga.
const ALTURA_BOCA := 2.55

## Largura que o bar PEDE ao quarteirao. `ChunkBuilder._fileira` tenta dar esta
## largura ao trecho de predio que recebe o bar; se a face nao tiver espaco, o
## salao se adapta ao que sobrou (minimo LARGURA_MINIMA).
const LARGURA_ALVO := 10.0
const LARGURA_MINIMA := 6.0
## Fundo do salao. Cabe dentro de ChunkBuilder.PROF_PREDIO com a parede do fundo.
const FUNDO_SALAO := 7.4
## A partir desta largura cabe mesa de sinuca no fundo esquerdo.
const LARGURA_COM_SINUCA := 9.0

## Ate onde sobe a fachada pintada acima da verga.
const ALTURA_FACHADA := 3.0
## O meio do letreiro, acima da fachada pintada, e a altura da caixa dele.
const LETREIRO_ACIMA := 0.58
const LETREIRO_ALTO := 0.95

## Distancia da boca do bar ate o centro da fileira de mesas da calcada.
##
## Unica fonte. O chunk desenha as mesas com este numero e a captura da rua mira
## o mesmo. Escrito em dois lugares, a mesa some da foto ou invade a rua no
## primeiro ajuste de toldo.
const AFASTAMENTO_MESA := 1.45
const MESAS_CALCADA := 4

const ALTURA_BALCAO := 1.08
## Do balcao a parede da direita. Atras dele ficam o corredor de quem atende, a
## pia e a prateleira; com 1,05 o atendente nascia dentro da prateleira.
const BALCAO_RECUO := 1.25
## Da linha do balcao ao centro da banqueta. O joelho de quem senta (a 0,42 m do
## quadril) para 4 cm antes da saia de azulejo.
const BANQUETA_DO_BALCAO := 0.78
## Meia largura do corredor livre no meio da boca, da calcada ate o fundo. Mesa
## do salao nao passa daqui (o teste caminha por este eixo).
const CORREDOR_DA_BOCA := 0.6
const ALTURA_MESA := 0.72
const LADO_MESA := 0.70
const ALTURA_ASSENTO := 0.44
## Ate onde a barra de azulejo sobe na parede. Acima disso e reboco amarelo.
const ALTURA_AZULEJO := 1.35

const AMARELO := Color("c8a43c")
const AMARELO_ESCURO := Color("8a7028")
const VERMELHO := Color("c4322e")
const FORMICA := Color("6e4a30")
const PLASTICO := Color("e2c64a")
const PLASTICO_BRANCO := Color("e6e0d4")
## O amarelo do jogo de mesa e cadeira monobloco (MoveisDoBar). Mais forte que
## PLASTICO: aquele multiplicava a textura amarela do `bar_plastico`, e na
## textura neutra do monobloco ele sai creme debaixo da nevoa.
const MONOBLOCO_AMARELO := Color("f2c21a")
const METAL_ESCURO := Color("3a3c3a")

## Cores das bandeirinhas de festa junina. Sao o que faz a frente ler como bar
## de esquina e nao como garagem aberta.
const BANDEIRINHAS: Array[Color] = [
	Color("d8483c"), Color("e6c23a"), Color("3f8f5a"),
	Color("3a6ea8"), Color("d87a2c"), Color("e0e0d4"),
]

const LUZ_QUENTE := Color("ffcf8a")
const LUZ_FRIA := Color("cfe4ff")

const SUBDIVISAO_PAINEL := 0.65


static func _solido(colisao: Array[Dictionary], centro: Vector3,
		tamanho: Vector3, giro: float = 0.0) -> void:
	KitModular.solido(colisao, centro, tamanho, giro)


## Coordenada local do bar para coordenada de mundo.
##
## `boca` e o meio da abertura, no chao; `b` ja e Basis(UP, giro) com +Z para a
## RUA. Local: x corre pela frente, y sobe, z entra no predio. O sinal de z e
## invertido aqui de proposito — escrever "z para dentro" em cada chamada e o
## tipo de troca de sinal que some numa revisao.
static func _p(boca: Vector3, b: Basis, x: float, y: float, z: float) -> Vector3:
	return boca + b * Vector3(x, y, -z)


# --- frente da rua ----------------------------------------------------------

## A frente do bar: dois pilares, a verga, o letreiro e o toldo. Entre os
## pilares nao ha NADA — e essa ausencia que e o bar.
##
## `boca` e o meio da abertura no nivel do piso, no plano da fachada do predio.
## `giro` aponta para a rua. `largura` e a do trecho de predio que o bar ocupou.
## `estilo` e o dos outros bares (BarVivo.estilo): cor da parede, do azulejo, o
## toldo e a placa. Vazio e o Bar do Seu Ze, como sempre foi.
static func frente(sup: Dictionary, colisao: Array[Dictionary],
		boca: Vector3, giro: float, largura: float, estilo: Dictionary = {}) -> void:
	var b := Basis(Vector3.UP, giro)
	var meia := largura * 0.5
	var parede: Color = estilo.get("parede", AMARELO)
	var azulejo: Color = estilo.get("azulejo", Color.WHITE)

	# Pilares de canto. Levam colisao: e neles que o jogador esbarra ao entrar
	# torto, e sao o unico solido que sobrou nesta face.
	for lado: float in [-1.0, 1.0]:
		# Um centimetro para dentro da divisa: no plano dela ja esta a parede
		# lateral do salao, e as duas faces piscavam na esquina.
		var px := lado * (meia - PILAR * 0.5 - 0.01)
		KitModular.caixa_cor(sup, &"bar_parede",
			_p(boca, b, px, ALTURA_SALAO * 0.5, 0.14),
			Vector3(PILAR, ALTURA_SALAO, 0.42), parede, giro)
		KitModular.caixa_cor(sup, &"bar_azulejo",
			_p(boca, b, px, ALTURA_AZULEJO * 0.5, 0.14),
			Vector3(PILAR + 0.04, ALTURA_AZULEJO, 0.46), azulejo, giro)
		_solido(colisao, _p(boca, b, px, ALTURA_SALAO * 0.5, 0.14),
			Vector3(PILAR, ALTURA_SALAO, 0.44), giro)

	# Verga sobre a boca. Fecha o quadro por cima e segura o toldo.
	var vao := largura - PILAR * 2.0
	var verga_h := ALTURA_SALAO - ALTURA_BOCA
	KitModular.caixa_cor(sup, &"bar_parede",
		_p(boca, b, 0.0, ALTURA_BOCA + verga_h * 0.5, 0.14),
		Vector3(vao, verga_h, 0.42), parede, giro)
	_solido(colisao, _p(boca, b, 0.0, ALTURA_BOCA + verga_h * 0.5, 0.14),
		Vector3(vao, verga_h, 0.44), giro)

	# Faixa pintada acima da verga, ate o fim da fachada do bar.
	var faixa_h := ALTURA_FACHADA - ALTURA_SALAO
	if faixa_h > 0.06:
		KitModular.placa(sup, &"bar_parede",
			_p(boca, b, 0.0, ALTURA_SALAO + faixa_h * 0.5, -0.05),
			Vector2(largura, faixa_h), giro, parede.lerp(Color.WHITE, 0.45) if not estilo.is_empty() \
				else Color.WHITE, SUBDIVISAO_PAINEL)

	toldo(sup, boca, giro, largura, estilo)
	letreiro(sup, boca, giro, largura, estilo)
	bandeirinhas(sup, boca, giro, largura)


## Toldo listrado correndo a frente inteira, como o da foto de referencia.
static func toldo(sup: Dictionary, boca: Vector3, giro: float,
		largura: float, estilo: Dictionary = {}) -> void:
	var b := Basis(Vector3.UP, giro)
	var y := ALTURA_SALAO - 0.06
	var tecido: StringName = estilo.get("toldo", &"bar_toldo")
	# Tecido, caido um palmo para a rua. A inclinacao e local, depois do giro.
	KitModular.caixa_livre(sup, tecido,
		_p(boca, b, 0.0, y - 0.04, -0.78),
		Vector3(largura - 0.3, 0.05, 1.6), b * Basis(Vector3.RIGHT, -0.18),
		Color.WHITE)
	# Babado vertical na ponta: e o que da a silhueta recortada de toldo.
	KitModular.caixa_cor(sup, tecido,
		_p(boca, b, 0.0, y - 0.46, -1.54),
		Vector3(largura - 0.3, 0.28, 0.04), Color.WHITE, giro)
	for lado: float in [-1.0, -0.34, 0.34, 1.0]:
		KitModular.caixa_cor(sup, &"metal",
			_p(boca, b, lado * (largura * 0.5 - 0.42), y - 0.24, -0.58),
			Vector3(0.05, 0.44, 1.2), METAL_ESCURO, giro)


## Onde o letreiro e a faixa de baixo ficam no plano da fachada: x a partir do
## meio da boca, y a partir do chao do lote (a boca fica no meio-fio). O predio de
## cima (ComercioVivo) nao poe janela atras da placa.
static func letreiro_na_fachada(largura: float) -> Rect2:
	var comp := _comprimento_do_letreiro(largura)
	var meio := KitModular.ALTURA_MEIO_FIO + ALTURA_FACHADA + LETREIRO_ACIMA
	var baixo := meio - 0.66 - 0.17
	return Rect2(-comp * 0.5, baixo, comp, meio + LETREIRO_ALTO * 0.5 - baixo)


static func _comprimento_do_letreiro(largura: float) -> float:
	return clampf(largura - 3.4, 3.0, 6.4)


## Letreiro aceso mais a faixa de chamada. Na nevoa e a mancha amarela de cima.
static func letreiro(sup: Dictionary, boca: Vector3, giro: float,
		largura: float, estilo: Dictionary = {}) -> void:
	var b := Basis(Vector3.UP, giro)
	var comp := _comprimento_do_letreiro(largura)
	var pos := _p(boca, b, 0.0, ALTURA_FACHADA + LETREIRO_ACIMA, -0.26)
	if estilo.has("nome"):
		# A placa pintada do bar (atlas `bares_nomes`, BarVivo.NOMES) na caixa de
		# chapa da cor da parede. A celula e 4:1: a placa fica nessa proporcao, no
		# meio da caixa, e nao esticada.
		KitModular.caixa_cor(sup, &"metal_pintado", pos, Vector3(comp, LETREIRO_ALTO, 0.16),
			(estilo["parede"] as Color).darkened(0.35), giro)
		var alto := 0.86
		var larg_placa := minf(comp - 0.12, alto * 4.0)
		var ob := Obra.new()
		ob.cartao(&"bar_nomes", Vector2(larg_placa, alto),
			Transform3D(b, pos + b * Vector3(0.0, 0.0, 0.085)),
			BarVivo.uv_do_nome(int(estilo["nome"])))
		ob.despejar(sup)
	else:
		KitModular.caixa_cor(sup, &"bar_letreiro", pos,
			Vector3(comp, LETREIRO_ALTO, 0.16), Color.WHITE, giro)
		KitModular.placa(sup, &"bar_letreiro",
			pos + b * Vector3(0.0, 0.0, 0.1), Vector2(comp - 0.1, 0.9), giro,
			Color.WHITE, SUBDIVISAO_PAINEL)
	# Faixa vermelha embaixo, com o que o bar vende. De longe e so uma barra
	# de cor; de perto e a unica coisa da frente que explica o lugar.
	KitModular.placa(sup, &"bar_faixa",
		pos + b * Vector3(0.0, -0.66, 0.1), Vector2(comp - 0.1, 0.34), giro,
		Color.WHITE, SUBDIVISAO_PAINEL)
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"metal",
			pos + b * Vector3(lado * (comp * 0.5 - 0.4), 0.0, -0.14),
			Vector3(0.06, 0.5, 0.34), METAL_ESCURO, giro)


## Varal de bandeirinhas na borda do toldo, com barriga no meio.
##
## Penduradas NA BORDA e nao acima dela: acima, o proprio toldo as escondia de
## quem olha da calcada, que e de onde este bar e visto.
static func bandeirinhas(sup: Dictionary, boca: Vector3, giro: float,
		largura: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var n := clampi(int(largura / 0.8), 8, 16)
	var meia := largura * 0.5 - 0.45
	var topo := ALTURA_SALAO - 0.56
	# Um fio so, reto, em vez de um pedaco por bandeira: doze caixinhas de
	# 2 cm que ninguem distingue de uma linha continua.
	KitModular.caixa_cor(sup, &"metal", _p(boca, b, 0.0, topo + 0.17, -1.5),
		Vector3(2.0 * meia, 0.02, 0.02), Color("2a2622"), giro)
	for i in n:
		var t := float(i) / float(n - 1)
		var queda := 0.2 * (1.0 - pow(2.0 * t - 1.0, 2.0))
		var p := _p(boca, b, lerpf(-meia, meia, t), topo - queda, -1.5)
		KitModular.caixa_cor(sup, &"bar_cadeira", p,
			Vector3(0.24, 0.3, 0.02), BANDEIRINHAS[i % BANDEIRINHAS.size()], giro)



## Mesas, cadeiras e tralha da calcada, na frente do bar.
##
## Mesas em fila, paralelas a fachada, a AFASTAMENTO_MESA da boca: duas de cada
## lado quando a frente da, uma quando nao. O meio fica livre — e por ali que
## se entra, e mesa atravessada na boca desmente o bar inteiro. Cadeira so nas
## laterais da mesa e do lado da fachada: a calcada tem 2,5 m (KitModular.
## CALCADA), e cadeira do lado da rua descia do meio-fio.
##
## `props` recebe quem esta sentado na calcada e os produtos do tampo (a garrafa
## de 600 com rotulo). Sem ele (chamador antigo) a mesa sai sem gente.
static func mesas_da_calcada(sup: Dictionary, colisao: Array[Dictionary],
		boca: Vector3, giro: float, largura: float, estilo: Dictionary = {},
		props: Array[Dictionary] = []) -> void:
	var b := Basis(Vector3.UP, giro)
	var meia := largura * 0.5
	var plastico: Color = estilo.get("plastico", PLASTICO)
	var lugares: Array[float] = [-(meia - 1.0), meia - 1.0]
	if meia - 2.8 >= 1.7:
		lugares = [-(meia - 1.0), -(meia - 2.8), meia - 2.8, meia - 1.0]
	var semente := _semente_da_boca(boca)
	var itens: Array = []
	var ocupada := 1 if lugares.size() > 2 else 0
	for i in lugares.size():
		var x: float = lugares[i]
		var externa := absf(x) > meia - 1.5
		# Lados em coordenada local do bar: +x, -x e, na mesa de fora, o lado da
		# fachada (z positivo e para dentro).
		var lados: Array[Vector2] = [Vector2(1.0, 0.0), Vector2(-1.0, 0.0)]
		if externa:
			lados.append(Vector2(0.0, 1.0))
		var assentos := _mesa_posta(sup, colisao, itens, boca, b,
			Vector2(x, -AFASTAMENTO_MESA), lados, i % 2 == 1, plastico, i % 2 == 0,
			semente + 131 * i, i == ocupada)
		if not externa:
			guarda_sol(sup, _p(boca, b, x, 0.0, -AFASTAMENTO_MESA), giro,
				estilo.get("toldo", &"bar_toldo"))
		if i == ocupada and assentos.size() >= 2:
			_sentar(props, assentos[0], semente + 3301, false, 22, 64)
			_sentar(props, assentos[1], semente + 3307, false, 20, 58)
			# Os dois da calcada bebem e brindam como os de dentro (VidaDoBar).
			props.append({"tipo": "vida_bar", "pos": boca, "semente": semente + 3313,
				"mesas": [[_assento_da_vida(assentos[0], boca),
					_assento_da_vida(assentos[1], boca)]]})
	if not itens.is_empty():
		props.append(ProdutosDoBar.prop(itens, boca))

	# Tralha encostada nos pilares, fora do caminho de quem entra.
	engradados(sup, colisao, _p(boca, b, meia - 0.75, 0.0, -0.62), giro, 4)
	botijao(sup, colisao, _p(boca, b, -(meia - 0.72), 0.0, -0.6), giro)
	lixeira(sup, colisao, _p(boca, b, -(meia - 1.4), 0.0, -0.6), giro)


## Guarda-sol de mesa de calcada, do pano do toldo (MoveisDoBar.guarda_sol):
## gomos listrados, babado, varetas e mastro. Meio gomo de giro em relacao a
## fachada, para a vareta nao cair alinhada com a mesa.
static func guarda_sol(sup: Dictionary, base: Vector3, giro: float,
		tecido: StringName = &"bar_toldo") -> void:
	MoveisDoBar.por(sup, MoveisDoBar.guarda_sol(tecido),
		Transform3D(Basis(Vector3.UP, giro + PI / float(MoveisDoBar.GOMOS)), base))


## Pilha de engradado de cerveja. Vazio, virado, como fica na porta do bar.
static func engradados(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float, andares: int = 3) -> void:
	const ALTO := 0.3
	for k in andares:
		var cor := Color("c03830") if k % 2 == 0 else Color("d8a022")
		KitModular.caixa_cor(sup, &"bar_cadeira",
			base + Vector3(0.0, ALTO * (float(k) + 0.5), 0.0),
			Vector3(0.42, ALTO - 0.02, 0.34), cor, giro + 0.06 * float(k))
	_solido(colisao, base + Vector3(0.0, ALTO * andares * 0.5, 0.0),
		Vector3(0.46, ALTO * andares, 0.38), giro)


## Botijao de gas encostado no pilar. Toda porta de boteco tem um.
static func botijao(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.32, 0.0),
		Vector3(0.34, 0.62, 0.34), Color("b8462e"), giro)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.68, 0.0),
		Vector3(0.16, 0.12, 0.16), Color("8a8c86"), giro)
	_solido(colisao, base + Vector3(0.0, 0.34, 0.0), Vector3(0.36, 0.68, 0.36), giro)


# --- o salao, dentro do chunk -----------------------------------------------

## O bar inteiro, em coordenada de mundo, dentro do terreo vazado do predio.
##
## Nao ha planta separada nem builder de interior: isto E o lugar. `boca` e o
## meio da abertura no chao, `giro` aponta para a rua, `largura` e a do trecho
## de predio. Devolve o numero de mesas e cadeiras postas, que e o que o teste
## confere sem ter de varrer a cena.
static func salao(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], boca: Vector3, giro: float, largura: float,
		semente: int, estilo: Dictionary = {}) -> Dictionary:
	var b := Basis(Vector3.UP, giro)
	var meia := largura * 0.5 - ESPESSURA
	var fundo := FUNDO_SALAO
	var tem_sinuca := largura >= LARGURA_COM_SINUCA
	var plastico: Color = estilo.get("plastico", PLASTICO)
	# Produto com rotulo (cervejeira, prateleira, a 600 no tampo): vira UM prop
	# `produtos` no fim, uma MultiMesh por forma para o bar inteiro.
	var itens: Array = []

	_casca_do_salao(sup, colisao, boca, b, giro, largura, fundo, estilo)

	var mesas := 0
	var cadeiras := 0

	# --- balcao, do lado direito de quem entra --------------------------------
	var bx := meia - BALCAO_RECUO
	var comp := fundo - 3.0
	var giro_balcao := giro - PI * 0.5
	balcao(sup, colisao, _p(boca, b, bx, 0.0, 1.5 + comp * 0.5), comp, giro_balcao)
	prateleira_garrafas(sup, colisao, itens, _p(boca, b, meia - 0.16, 0.0, 4.0),
		minf(2.6, fundo - 3.6), giro_balcao, semente)
	cardapio(sup, _p(boca, b, meia - 0.06, 2.05, 5.95), giro_balcao)
	pia(sup, colisao, _p(boca, b, meia - 0.5, 0.0, 2.1), giro_balcao)
	fogao(sup, colisao, _p(boca, b, meia - 0.85, 0.0, fundo - 0.6), giro + PI)

	# A estufa do mercado na ponta do balcao virada para a rua: o primeiro ponto
	# aceso que quem passa na calcada ve dentro do bar.
	var tampo_y := ALTURA_BALCAO + 0.05
	var estufa_em := _p(boca, b, bx, tampo_y, 1.95)
	MoveisDoBar.por(sup, MoveisDoBar.estufa(),
		Transform3D(Basis(Vector3.UP, giro_balcao), estufa_em))
	_solido(colisao, estufa_em + Vector3(0.0, MoveisDoBar.TAMANHO_ESTUFA.y * 0.5, 0.0),
		MoveisDoBar.TAMANHO_ESTUFA, giro_balcao)
	_por_copo(sup, _p(boca, b, bx - 0.12, tampo_y, 3.2), giro)
	_por_copo(sup, _p(boca, b, bx - 0.15, tampo_y, 3.47), giro + 1.0)
	itens.append([&"brahma_600", _p(boca, b, bx - 0.02, tampo_y, 3.33), giro_balcao])
	MoveisDoBar.por(sup, MoveisDoBar.cinzeiro(),
		Transform3D(Basis.IDENTITY, _p(boca, b, bx - 0.1, tampo_y, 4.45)))

	# Banquetas encostadas na formica.
	var banquetas: Array[Dictionary] = []
	for i in 3:
		var z := 2.95 + 0.82 * float(i)
		var p := _p(boca, b, bx - BANQUETA_DO_BALCAO, 0.0, z)
		MoveisDoBar.por(sup, MoveisDoBar.banqueta(),
			Transform3D(Basis(Vector3.UP, giro + 0.4 * float(i)), p))
		_solido(colisao, p + Vector3(0.0, MoveisDoBar.ALTURA_BANQUETA * 0.5, 0.0),
			Vector3(0.36, MoveisDoBar.ALTURA_BANQUETA, 0.36), giro)
		banquetas.append({"pos": p, "foco": _p(boca, b, bx, 1.2, z),
			"assento": MoveisDoBar.ALTURA_BANQUETA, "mesa": _p(boca, b, bx - 0.12, tampo_y, z)})
		cadeiras += 1

	# --- cervejeira no fundo, a esquerda do fogao -----------------------------
	var comp_cerv := minf(2.25, largura - 4.2)
	var luz_fria := cervejeira(sup, colisao, itens,
		_p(boca, b, meia - 1.55 - comp_cerv * 0.5, 0.0, fundo - 0.34), comp_cerv,
		giro, 3, semente)
	props.append({
		"tipo": "lampada", "pos": luz_fria,
		"padrao": Lampada.Padrao.ESTAVEL, "semente": semente + 811,
		"cor": LUZ_FRIA, "energia": 1.1, "alcance": 5.0, "facho": false,
	})

	# --- TV e parede da esquerda ------------------------------------------------
	var tela := _p(boca, b, -meia + 0.32, 2.05, 2.9)
	tv_gabinete(sup, colisao, tela, giro + PI * 0.5)
	props.append({"tipo": "televisao", "pos": tela + b * Vector3(0.08, 0.0, 0.0),
		"giro": giro + PI * 0.5})
	cartaz(sup, _p(boca, b, -meia + 0.06, 2.4, 4.6), giro + PI * 0.5)
	relogio(sup, _p(boca, b, -meia + 0.06, 2.45, 1.3), giro + PI * 0.5)
	placa_fiado(sup, _p(boca, b, meia - 0.06, 1.95, 1.5), giro - PI * 0.5)

	# --- sinuca, so quando o predio deu largura -------------------------------
	# No fundo esquerdo, comprida no sentido do salao, com 1,35 m de folga para
	# o taco na parede e no fundo. A Fase 2 (sinuca jogavel) conta com esta folga.
	var sinuca_local := Vector2(-meia + 2.07, fundo - 2.57)
	var sinuca_em := Vector3.ZERO
	if tem_sinuca:
		sinuca_em = _p(boca, b, sinuca_local.x, 0.0, sinuca_local.y)
		# A mesa desenhada (DesenhoSinuca) e a jogavel (JogoSinuca, [E] para jogar)
		# sao a mesma: medidas de MesaSinuca, comprimento no sentido do salao.
		DesenhoSinuca.por(sup, colisao, sinuca_em, giro + PI * 0.5)
		props.append({"tipo": "sinuca", "pos": sinuca_em, "giro": giro + PI * 0.5,
			"semente": semente + 977})
		# Os tacos da casa, na parede da esquerda, ao lado do pe da mesa.
		MoveisDoBar.por(sup, DesenhoSinuca.porta_tacos(), Transform3D(
			Basis(Vector3.UP, giro + PI * 0.5), _p(boca, b, -meia + 0.02, 0.0,
				sinuca_local.y + 1.35)))
		# A luz logo abaixo das cupulas da luminaria da mesa.
		props.append({
			"tipo": "lampada",
			"pos": sinuca_em + Vector3(0.0, MesaSinuca.ALTURA_PANO + 0.9, 0.0),
			"padrao": Lampada.Padrao.ESTAVEL, "semente": semente + 933,
			"cor": Color("ffe0b8"), "energia": 1.0, "alcance": 3.6,
			"facho": false,
		})

	# --- mesas do salao ---------------------------------------------------------
	# Em fila, alinhadas com a fachada, da parede da TV ate o meio da boca. O
	# meio fica livre: e o corredor da calcada ao balcao e a sinuca. Quatro
	# cadeiras por mesa, todas viradas PARA a mesa.
	# Sem ternario: ele nao tipa o array e a atribuicao quebra na thread.
	var fileiras: Array[float] = [1.6]
	if not tem_sinuca:
		fileiras.append(3.6)
	var postos: Array[Vector2] = []
	for z: float in fileiras:
		var x := -meia + 1.05
		var nesta := 0
		# Pelo menos uma por fileira; as outras so enquanto a cadeira da direita
		# nao invade o corredor.
		while nesta == 0 \
				or x + MoveisDoBar.AFASTAMENTO_CADEIRA + 0.27 <= -CORREDOR_DA_BOCA:
			postos.append(Vector2(x, z))
			nesta += 1
			x += 1.95
	var quatro: Array[Vector2] = [Vector2(1.0, 0.0), Vector2(-1.0, 0.0),
		Vector2(0.0, -1.0), Vector2(0.0, 1.0)]
	var assentos_do_salao: Array = []
	for i in postos.size():
		# A segunda mesa tem o lugar do fundo virado para a TV: e quem assiste o
		# jogo, de costas para o companheiro de mesa, como em todo bar.
		var virar: Dictionary = {}
		if i == 1:
			virar[3] = tela + b * Vector3(0.3, -0.3, 0.0)
		var assentos := _mesa_posta(sup, colisao, itens, boca, b, postos[i],
			quatro, i % 2 == 0, plastico, i % 2 == 1, semente + 57 * i, i < 2, virar)
		assentos_do_salao.append(assentos)
		mesas += 1
		cadeiras += assentos.size()

	# --- canto de servico ----------------------------------------------------
	caixa_plastico(sup, colisao, _p(boca, b, -meia + 0.4, 0.0, fundo - 0.45),
		giro - 0.3)
	vassoura(sup, _p(boca, b, -meia + 0.28, 0.0, fundo - 1.0), giro + 0.4)
	engradados(sup, colisao, _p(boca, b, meia - 0.55, 0.0, fundo - 1.4), giro, 3)

	_som_e_luz(sup, props, boca, b, largura, fundo, semente)
	var quem := _gente(props, boca, b, bx, banquetas, assentos_do_salao, tem_sinuca,
		sinuca_local, semente)
	props.append(_vida(boca, b, quem, bx, meia, tampo_y, tela + b * Vector3(0.08, 0.0, 0.0),
		semente))

	if not itens.is_empty():
		props.append(ProdutosDoBar.prop(itens, boca))

	# Os outros bares (BarVivo) nao sao ponto de interesse puro: o lote sai do
	# sorteio da fileira. Este prop os anuncia ao mapa e ao GPS (BaresDaCidade).
	if estilo.has("nome"):
		props.append({"tipo": "ponto_bar", "pos": boca, "giro": giro,
			"nome": String(estilo.get("titulo", "BAR"))})

	# Telefone de parede: o ponto de salvar do bar. Fica no pilar direito, perto
	# da boca, onde quem entra passa.
	props.append({
		"tipo": "save",
		"pos": _p(boca, b, meia - 0.3, 0.0, 0.55),
		"giro": giro - PI * 0.5,
		"local": "Telefone do " + String(estilo.get("titulo", "Bar do Seu Ze")),
	})

	return {"mesas": mesas, "cadeiras": cadeiras, "sinuca": tem_sinuca}


## Piso, forro, tres paredes e a barra de azulejo. A quarta parede e a rua.
static func _casca_do_salao(sup: Dictionary, colisao: Array[Dictionary],
		boca: Vector3, b: Basis, giro: float, largura: float,
		fundo: float, estilo: Dictionary = {}) -> void:
	var meia := largura * 0.5 - ESPESSURA
	var parede: Color = estilo.get("parede", AMARELO)
	var azulejo: Color = estilo.get("azulejo", Color.WHITE)
	var centro_z := fundo * 0.5

	# Piso no nivel da calcada: entrar no bar nao pode ter degrau, senao a
	# passagem vira um obstaculo e o lugar volta a ter uma soleira.
	KitModular.caixa_cor(sup, &"bar_piso",
		_p(boca, b, 0.0, -0.03, centro_z),
		Vector3(largura, 0.06, fundo), Color.WHITE, giro)
	# Faixa de ladrilho na boca: e o tapete que marca onde a rua vira bar.
	KitModular.caixa_cor(sup, &"bar_ladrilho",
		_p(boca, b, 0.0, 0.015, 0.7),
		Vector3(largura - PILAR * 2.0, 0.04, 1.4), Color.WHITE, giro)
	_solido(colisao, _p(boca, b, 0.0, -0.2, centro_z),
		Vector3(largura + 0.4, 0.4, fundo + 0.4), giro)

	# Forro, entre as paredes. Nenhuma face da casca fica no plano de outra: a
	# lateral do forro e do pilar na divisa coincidia com a da parede e com a da
	# massa do predio (que comeca em ALTURA_CASCA), e a faixa da esquina piscava
	# (tests/bancada_coplanar.gd).
	KitModular.caixa_cor(sup, &"bar_teto",
		_p(boca, b, 0.0, ALTURA_SALAO + FORRO * 0.5, centro_z),
		Vector3(meia * 2.0, FORRO, fundo), Color("bfae92"), giro)

	# Parede do fundo entre as duas laterais, e as laterais ate o fim do fundo,
	# com azulejo ate a altura do peito. Todas sobem ate o topo do forro.
	var paredes: Array[Dictionary] = [
		{"c": _p(boca, b, 0.0, 0.0, fundo), "t": Vector3(meia * 2.0, 0.0, ESPESSURA),
			"g": giro},
		{"c": _p(boca, b, -meia - ESPESSURA * 0.5, 0.0, (fundo + ESPESSURA * 0.5) * 0.5),
			"t": Vector3(ESPESSURA, 0.0, fundo + ESPESSURA * 0.5), "g": giro},
		{"c": _p(boca, b, meia + ESPESSURA * 0.5, 0.0, (fundo + ESPESSURA * 0.5) * 0.5),
			"t": Vector3(ESPESSURA, 0.0, fundo + ESPESSURA * 0.5), "g": giro},
	]
	for pa: Dictionary in paredes:
		var c: Vector3 = pa["c"]
		var t: Vector3 = pa["t"]
		KitModular.caixa_cor(sup, &"bar_parede",
			c + Vector3(0.0, ALTURA_CASCA * 0.5, 0.0),
			Vector3(t.x, ALTURA_CASCA, t.z), parede, pa["g"])
		_solido(colisao, c + Vector3(0.0, ALTURA_SALAO * 0.5, 0.0),
			Vector3(t.x, ALTURA_SALAO, t.z), pa["g"])

	# Azulejo, dois centimetros na frente do reboco. Parede de uma cor so lia
	# como galpao pintado; a divisao horizontal e o que mais diz "boteco".
	var y := ALTURA_AZULEJO * 0.5
	KitModular.placa(sup, &"bar_azulejo",
		_p(boca, b, 0.0, y, fundo - 0.13), Vector2(largura - 0.1, ALTURA_AZULEJO),
		giro, azulejo)
	KitModular.placa(sup, &"bar_azulejo",
		_p(boca, b, -meia + 0.03, y, fundo * 0.5),
		Vector2(fundo, ALTURA_AZULEJO), giro + PI * 0.5, azulejo)
	KitModular.placa(sup, &"bar_azulejo",
		_p(boca, b, meia - 0.03, y, fundo * 0.5),
		Vector2(fundo, ALTURA_AZULEJO), giro - PI * 0.5, azulejo)


## Pendentes, caixa de som e o radio do jogo. Tres luzes quentes: o chunk ja
## gasta uma no poste, e o orcamento da skill psx-city e quatro dinamicas.
static func _som_e_luz(sup: Dictionary, props: Array[Dictionary], boca: Vector3,
		b: Basis, largura: float, fundo: float, semente: int) -> void:
	var meia := largura * 0.5 - ESPESSURA
	# Tres pendentes, e a posicao de cada um e escolhida, nao espalhada: um
	# sobre a boca (e a luz que VAZA para a calcada e anuncia o bar na nevoa),
	# um sobre o balcao e um no fundo. O orcamento da skill psx-city e quatro
	# luzes dinamicas no chunk e o poste da rua ja gastou uma, entao o jeito de
	# clarear o salao e alcance, nao lampada a mais.
	var pontos: Array[Vector3] = [
		_p(boca, b, -meia * 0.35, ALTURA_SALAO - 0.3, 1.5),
		_p(boca, b, meia * 0.72, ALTURA_SALAO - 0.3, 4.2),
		_p(boca, b, -meia * 0.45, ALTURA_SALAO - 0.3, fundo - 1.7),
	]
	for i in pontos.size():
		var p: Vector3 = pontos[i]
		pendente(sup, p)
		props.append({
			"tipo": "lampada", "pos": p + Vector3(0.0, -0.14, 0.0),
			"padrao": Lampada.Padrao.ESTAVEL, "semente": semente + 101 * i,
			"cor": LUZ_QUENTE, "energia": 2.6, "alcance": 9.5, "facho": false,
		})

	for lado: float in [-1.0, 1.0]:
		caixa_de_som(sup, _p(boca, b, lado * (meia - 0.3), ALTURA_SALAO - 0.35, 0.5),
			0.0)
	# A partida sai daqui. Volume baixo: e o fundo do bar, nao a trilha, e
	# agora ela vaza para a calcada porque nao ha parede segurando.
	props.append({
		"tipo": "som_ambiente",
		"pos": _p(boca, b, 0.0, 1.9, 2.4),
		"som": &"bar_estadio_loop",
		"volume": -17.0,
		"alcance": 18.0,
	})


## Quem esta no bar: o atendente atras do balcao, um cliente na banqueta, dois
## numa mesa e um assistindo a TV, e, quando ha sinuca, dois jogando.
##
## Todo mundo que senta, senta NUMA CADEIRA que existe: o assento sai de
## `_mesa_posta` e da banqueta, com a altura do movel (`assento`), e a pessoa
## olha para onde a cadeira olha. Antes os clientes da TV eram `SENTADO` sem
## assento — pernas cruzadas no chao, entre as cadeiras — e o do balcao nascia
## em pe dentro da banqueta.
static func _gente(props: Array[Dictionary], boca: Vector3, b: Basis,
		bx: float, banquetas: Array[Dictionary], assentos_do_salao: Array,
		tem_sinuca: bool, sinuca_local: Vector2, semente: int) -> Dictionary:
	# Quem sentou onde, para a VidaDoBar: cada mesa e uma lista de assentos.
	var mesas: Array = []
	var balcao: Dictionary = banquetas[1]
	_sentar(props, balcao, semente + 523, false, 22, 58)
	var atendente: Vector3 = balcao["pos"] + b * Vector3(BANQUETA_DO_BALCAO + 0.6, 0.0, 0.0)
	_convidado(props, atendente, semente + 211, Convidado.Papel.LIVRE, true,
		Vector3(balcao["pos"]) + Vector3(0.0, 1.4, 0.0), 28, 62)
	# Quem atende: a conversa e a do balcao do bar (VendaDoBar) e o rotulo diz
	# a funcao. O sexo sai do registro, e por isso a funcao nao tem artigo.
	props[-1]["contexto"] = &"bar"
	props[-1]["funcao"] = "quem atende"
	props[-1]["profissao"] = "BALCONISTA"
	props[-1]["loja"] = {"bar": true}
	mesas.append([balcao])

	# Mesa da parede: os dois de frente um para o outro. Segunda mesa: quem
	# assiste o jogo, na cadeira virada para a TV.
	if assentos_do_salao.size() >= 1 and (assentos_do_salao[0] as Array).size() >= 2:
		var par: Array = assentos_do_salao[0]
		# Quem senta bebe (VidaDoBar): a mao e do copo. Quem fuma no bar e o da
		# sinuca, em pe.
		_sentar(props, par[0], semente + 307, false, 22, 64)
		_sentar(props, par[1], semente + 419, false, 20, 58)
		mesas.append([par[0], par[1]])
	if assentos_do_salao.size() >= 2 and (assentos_do_salao[1] as Array).size() >= 4:
		_sentar(props, (assentos_do_salao[1] as Array)[3], semente + 443, false, 30, 70)
		mesas.append([(assentos_do_salao[1] as Array)[3]])

	var saida := {"mesas": mesas, "balcao": balcao["pos"], "atendente": atendente}
	if not tem_sinuca:
		return saida
	# Os dois da sinuca, em pe: um na lateral e um na cabeceira do fundo, os dois
	# olhando o pano.
	var pano := _p(boca, b, sinuca_local.x, 0.9, sinuca_local.y)
	_convidado(props, _p(boca, b, sinuca_local.x + 1.15, 0.0, sinuca_local.y - 0.35),
		semente + 631, Convidado.Papel.LIVRE, false, pano, 22, 58)
	_convidado(props, _p(boca, b, sinuca_local.x + 0.25, 0.0, sinuca_local.y + 1.7),
		semente + 743, Convidado.Papel.LIVRE, true, pano, 22, 58)
	return saida


## O prop da VidaDoBar: quem bebe em cada mesa, quem atende e por onde anda, o
## tampo onde o pedido pousa, onde a mao busca cada coisa e a TV. Tudo relativo
## a boca (a ladeira so move a chave `pos` do prop).
##
## A ronda de quem atende fica no corredor entre o balcao e a prateleira, da
## ponta da pia (z 2,62) ate antes do engradado do fundo.
static func _vida(boca: Vector3, b: Basis, quem: Dictionary, bx: float, meia: float,
		tampo_y: float, tv: Vector3, semente: int) -> Dictionary:
	var x_trilho := bx + 0.6
	var rel := func(x: float, y: float, z: float) -> Vector3:
		return _p(boca, b, x, y, z) - boca
	var mesas: Array = []
	for mesa: Array in quem["mesas"]:
		var lista: Array = []
		for a: Dictionary in mesa:
			lista.append(_assento_da_vida(a, boca))
		mesas.append(lista)
	return {
		"tipo": "vida_bar", "pos": boca, "semente": semente + 1777,
		"mesas": mesas,
		"balcao": Vector3(quem["balcao"]) - boca,
		"atendente": Vector3(quem["atendente"]) - boca,
		"ronda": [rel.call(x_trilho, 0.0, 2.95), rel.call(x_trilho, 0.0, 3.9),
			rel.call(x_trilho, 0.0, 5.1)],
		"trilho": [rel.call(x_trilho, 0.0, 2.95), rel.call(x_trilho, 0.0, 5.3)],
		"tampo": [rel.call(bx - 0.16, tampo_y, 2.6), rel.call(bx - 0.16, tampo_y, 5.5)],
		"fontes": {
			&"prateleira": rel.call(meia - 0.36, 1.38, 4.0),
			&"estufa": rel.call(bx + 0.12, tampo_y + 0.3, 2.15),
			&"estufa_pe": rel.call(x_trilho, 0.0, 2.95),
		},
		"tv": tv - boca,
	}


## Um assento para a VidaDoBar, relativo a boca: onde a pessoa senta e o tampo
## na frente dela (INF: nenhum).
static func _assento_da_vida(a: Dictionary, boca: Vector3) -> Dictionary:
	var mesa: Vector3 = a.get("mesa", Vector3.INF)
	return {"pos": Vector3(a["pos"]) - boca,
		"mesa": mesa - boca if mesa != Vector3.INF else Vector3.INF}


## Alguem sentado num assento de `_mesa_posta` ou numa banqueta.
##
## Papel SENTADO (nao anda, nao circula) com `assento` > 0: o Convidado usa a
## postura de assento de verdade (Corpo.Postura.ASSENTO), e nao o sentar no chao.
static func _sentar(props: Array[Dictionary], assento: Dictionary, semente: int,
		fuma: bool, idade_min: int, idade_max: int) -> void:
	props.append({
		"tipo": "convidado", "pos": assento["pos"], "semente": semente,
		"papel": Convidado.Papel.SENTADO, "fuma": fuma,
		"idade_min": idade_min, "idade_max": idade_max,
		"foco": assento["foco"], "pontos": [], "chapado": false, "olhos": false,
		"assento": float(assento["assento"]),
	})


## Alguem em pe, que nao sai do lugar. Nasce virado para o `foco`: o Convidado
## LIVRE nao se vira sozinho ate a primeira espera acabar.
static func _convidado(props: Array[Dictionary], onde: Vector3, semente: int,
		papel: int, fuma: bool, foco: Vector3, idade_min: int,
		idade_max: int) -> void:
	var para := foco - onde
	props.append({
		"tipo": "convidado", "pos": onde, "semente": semente, "papel": papel,
		"fuma": fuma, "idade_min": idade_min, "idade_max": idade_max,
		"foco": foco, "pontos": [], "chapado": false, "olhos": false,
		# O Convidado olha para -Z (Convidado._encarar).
		"giro": atan2(-para.x, -para.z),
	})


## Uma mesa com as cadeiras viradas PARA ELA, e o que vai no tampo.
##
## `centro` e `lados` em coordenada local do bar (x pela frente, z para dentro);
## cada lado poe uma cadeira a MoveisDoBar.AFASTAMENTO_CADEIRA do centro, de
## frente para a mesa — ou para o ponto de `virar[indice do lado]`, quando ha.
## `arrumada`: sem o desalinho de cadeira largada (a de quem vai sentar tem de
## estar onde a pessoa senta). Devolve os assentos na ordem de `lados`.
static func _mesa_posta(sup: Dictionary, colisao: Array[Dictionary], itens: Array,
		boca: Vector3, b: Basis, centro: Vector2, lados: Array[Vector2],
		toalha: bool, plastico: Color, colorida: bool, semente: int,
		arrumada: bool = false, virar: Dictionary = {}) -> Array[Dictionary]:
	var giro := atan2(b.z.x, b.z.z)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var meio := _p(boca, b, centro.x, 0.0, centro.y)
	# Mesa e cadeiras do mesmo jogo: a cor da cerveja do bar ou a branca.
	var cor := plastico if colorida else PLASTICO_BRANCO
	if cor == PLASTICO:
		cor = MONOBLOCO_AMARELO
	MoveisDoBar.por(sup, MoveisDoBar.mesa(), Transform3D(b, meio), cor)
	var tampo := MoveisDoBar.ALTURA_MESA
	if toalha:
		MoveisDoBar.por(sup, MoveisDoBar.toalha(), Transform3D(b, meio))
		tampo += 0.006
	_solido(colisao, meio + Vector3(0.0, tampo * 0.5, 0.0),
		Vector3(MoveisDoBar.LADO_MESA, tampo, MoveisDoBar.LADO_MESA), giro)

	var assentos: Array[Dictionary] = []
	for k in lados.size():
		var l: Vector2 = lados[k]
		var p := _p(boca, b, centro.x + l.x * MoveisDoBar.AFASTAMENTO_CADEIRA, 0.0,
			centro.y + l.y * MoveisDoBar.AFASTAMENTO_CADEIRA)
		var foco: Vector3 = virar.get(k, meio + Vector3(0.0, 1.0, 0.0))
		var g := MoveisDoBar.giro_para(p, foco)
		if not arrumada and not virar.has(k):
			g += rng.randf_range(-0.16, 0.16)
			p += b * Vector3(rng.randf_range(-0.04, 0.04), 0.0, rng.randf_range(-0.04, 0.04))
		MoveisDoBar.por(sup, MoveisDoBar.cadeira(), Transform3D(Basis(Vector3.UP, g), p), cor)
		_solido(colisao, p + Vector3(0.0, 0.45, 0.0), Vector3(0.44, 0.9, 0.44), g)
		# O quadril um dedo para o lado do encosto (-Z local da cadeira).
		var quadril := p + Basis(Vector3.UP, g) * Vector3(0.0, 0.0, -MoveisDoBar.RECUO_QUADRIL)
		# `mesa`: o meio do tampo, onde a mao com o copo descansa (VidaDoBar).
		# Quem esta virado para outro lado (a TV) nao tem mesa na frente.
		assentos.append({"pos": quadril, "foco": foco,
			"assento": MoveisDoBar.ALTURA_ASSENTO,
			"mesa": Vector3.INF if virar.has(k) else meio + Vector3(0.0, tampo, 0.0)})

	# Tampo: copo americano, a 600 com rotulo e, as vezes, o cinzeiro.
	var yt := meio + Vector3(0.0, tampo, 0.0)
	_por_copo(sup, yt + b * Vector3(0.14, 0.0, 0.1), rng.randf() * TAU)
	if lados.size() > 2:
		_por_copo(sup, yt + b * Vector3(-0.16, 0.0, -0.09), rng.randf() * TAU)
	itens.append([&"brahma_600", yt + b * Vector3(-0.04, 0.0, 0.13),
		giro + rng.randf_range(-0.8, 0.8)])
	if rng.randf() < 0.6:
		MoveisDoBar.por(sup, MoveisDoBar.cinzeiro(),
			Transform3D(Basis.IDENTITY, yt + b * Vector3(0.15, 0.0, -0.15)))
	return assentos


static func _por_copo(sup: Dictionary, onde: Vector3, giro: float) -> void:
	MoveisDoBar.por(sup, MoveisDoBar.copo(), Transform3D(Basis(Vector3.UP, giro), onde))


## Semente estavel de um bar pela posicao da boca (a calcada nao recebe a do
## salao).
static func _semente_da_boca(boca: Vector3) -> int:
	return hash(Vector2i(roundi(boca.x * 10.0), roundi(boca.z * 10.0)))


# --- moveis e miudezas ------------------------------------------------------------------

## Cadeira monobloco. Quatro caixas, e nao oito.
##
## O bar mora no orcamento de triangulos do CHUNK, e cadeira e a peca mais
## repetida dele: dezesseis delas entre calcada e salao. Com pe e montante
## separados custavam 1776 tris sozinhas, quase um terco do chunk inteiro. Os
## pes viraram duas chapas e o encosto uma so — a 480x270 a silhueta e a mesma,
## e o que se ve e a cor do plastico.
##
## `plastico` e a cor da cadeira colorida (a de cerveja de cada bar, BarVivo);
## a outra e sempre a branca.
static func cadeira(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float, amarela: bool = true,
		plastico: Color = PLASTICO) -> void:
	var b := Basis(Vector3.UP, giro)
	var cor := plastico if amarela else PLASTICO_BRANCO
	KitModular.caixa_cor(sup, &"bar_cadeira",
		base + Vector3(0.0, ALTURA_ASSENTO, 0.0),
		Vector3(0.38, 0.05, 0.38), cor, giro)
	for lz: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"bar_cadeira",
			base + b * Vector3(0.0, ALTURA_ASSENTO * 0.5, lz * 0.14),
			Vector3(0.32, ALTURA_ASSENTO, 0.035), cor, giro)
	KitModular.caixa_cor(sup, &"bar_cadeira",
		base + b * Vector3(0.0, ALTURA_ASSENTO + 0.26, -0.17),
		Vector3(0.34, 0.46, 0.04), cor, giro)
	_solido(colisao, base + Vector3(0.0, 0.42, 0.0),
		Vector3(0.40, 0.84, 0.40), giro)


## Banqueta alta de balcao. Sem encosto, e a que fica encostada na formica.
static func banqueta(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	const ALTO := 0.72
	KitModular.caixa_cor(sup, &"tabua", base + Vector3(0.0, ALTO, 0.0),
		Vector3(0.32, 0.05, 0.32), Color("8a6234"), giro)
	for lx: float in [-1.0, 1.0]:
		for lz: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"metal",
				base + b * Vector3(lx * 0.12, ALTO * 0.5, lz * 0.12),
				Vector3(0.03, ALTO, 0.03), METAL_ESCURO, giro)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.22, 0.0),
		Vector3(0.3, 0.03, 0.3), METAL_ESCURO, giro)
	_solido(colisao, base + Vector3(0.0, ALTO * 0.5, 0.0),
		Vector3(0.34, ALTO, 0.34), giro)


## Balcao de formica. `giro` aponta a frente, o lado do cliente.
static func balcao(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, comprimento: float, giro: float,
		registradora: bool = true) -> void:
	var b := Basis(Vector3.UP, giro)
	var prof := 0.64
	var alto := ALTURA_BALCAO
	KitModular.caixa_cor(sup, &"bar_formica",
		centro + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(comprimento, alto, prof), FORMICA, giro)
	# Barra de azulejo na saia do balcao, do lado do cliente. E o detalhe que
	# faz a formica ler como balcao de bar e nao como caixote marrom.
	KitModular.caixa_cor(sup, &"bar_azulejo",
		centro + b * Vector3(0.0, 0.4, prof * 0.5 + 0.01),
		Vector3(comprimento - 0.04, 0.7, 0.03), Color.WHITE, giro)
	KitModular.caixa_cor(sup, &"bar_formica",
		centro + Vector3(0.0, alto + 0.025, 0.0),
		Vector3(comprimento + 0.08, 0.05, prof + 0.08), Color("8a5e3c"), giro)
	# Sem peitoril alto do lado do cliente: a ripa de 6 cm acima do tampo cortava
	# o antebraco de quem senta na banqueta com a mao na formica. A borda do tampo
	# (8 cm a mais que a saia) ja fecha a quina.
	if registradora:
		var reg := centro + b * Vector3(comprimento * 0.5 - 0.38, 0.0, -0.04)
		KitModular.caixa_cor(sup, &"metal",
			reg + Vector3(0.0, alto + 0.14, 0.0),
			Vector3(0.34, 0.18, 0.30), Color("4a4c4a"), giro)
		KitModular.caixa_cor(sup, &"metal",
			reg + b * Vector3(0.0, alto + 0.28, 0.12),
			Vector3(0.20, 0.10, 0.03), Color("9ad6a8"), giro)
	_solido(colisao, centro + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(comprimento, alto + 0.22, prof), giro)


## Cervejeira de bar, de portas de vidro: a camara acesa por dentro, grades e
## as latas e garrafas de 600 com rotulo de verdade (`ProdutosDoBar`, os mesmos
## produtos do mercado). Devolve a posicao da luz fria de dentro.
##
## A de antes era uma placa com a foto das garrafas (`bar_cervejeira`); com o
## dither por cima ela lia como papel de parede.
static func cervejeira(sup: Dictionary, colisao: Array[Dictionary], itens: Array,
		centro: Vector3, comprimento: float, giro: float, portas: int = 3,
		semente: int = 0) -> Vector3:
	var b := Basis(Vector3.UP, giro)
	var prof := 0.64
	var alto := 1.98
	var frente := prof * 0.5
	var base_h := 0.2
	var chapeu_h := 0.26
	var em := func(l: Vector3) -> Vector3:
		return centro + b * l
	var casco := Color("dcdad4")
	var escuro := Color("2e3032")

	# Casco: pe do compressor, chapeu vermelho, laterais e o fundo claro da
	# camara. O fundo claro e o que faz a cervejeira acender no bar escuro.
	KitModular.caixa_cor(sup, &"metal_pintado", em.call(Vector3(0.0, base_h * 0.5, 0.0)),
		Vector3(comprimento, base_h, prof), escuro, giro)
	KitModular.caixa_cor(sup, &"metal_pintado",
		em.call(Vector3(0.0, alto - chapeu_h * 0.5, 0.0)),
		Vector3(comprimento, chapeu_h, prof), Color("b02a25"), giro)
	KitModular.caixa_cor(sup, &"mercado_luz",
		em.call(Vector3(0.0, alto - chapeu_h * 0.5, frente + 0.012)),
		Vector3(comprimento - 0.16, chapeu_h * 0.42, 0.02), Color("fff0d0"), giro)
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"metal_pintado",
			em.call(Vector3(lado * (comprimento * 0.5 - 0.025), alto * 0.5, 0.0)),
			Vector3(0.05, alto, prof), casco, giro)
	var camara_h := alto - base_h - chapeu_h
	KitModular.caixa_cor(sup, &"mercado_chapa",
		em.call(Vector3(0.0, base_h + camara_h * 0.5, -frente + 0.03)),
		Vector3(comprimento - 0.1, camara_h, 0.04), Color("e6eef0"), giro)

	# Grades e o que vai nelas. Embaixo a 600, que e mais alta; em cima lata.
	var niveis: Array[float] = [0.22, 0.58, 0.86, 1.14, 1.42]
	var cerveja: Array = [&"brahma_lata", &"skol_lata", &"antarctica_lata",
		&"kaiser_lata", &"schin_lata", &"bohemia_lata"]
	var refri: Array = [&"coca_lata", &"guarana_lata", &"fanta_lata",
		&"sprite_lata", &"soda_lata", &"pepsi_lata"]
	var dentro := comprimento * 0.5 - 0.08
	for n in niveis.size():
		var y: float = niveis[n]
		KitModular.caixa_cor(sup, &"mercado_chapa",
			em.call(Vector3(0.0, y - 0.008, -0.02)),
			Vector3(comprimento - 0.1, 0.016, prof - 0.12), Color("aeb6ba"), giro)
		var skus: Array = [&"brahma_600"] if n == 0 else (cerveja if n <= 2 else refri)
		ProdutosDoBar.fileira(itens, skus, em.call(Vector3(-dentro, y, frente - 0.11)),
			em.call(Vector3(dentro, y, frente - 0.11)), giro, 4, 0.1, semente + 17 * n)

	# Portas: montante, travessa, vidro e puxador. O tubo de luz atras de cada
	# montante e o brilho de geladeira de bar.
	var larg := comprimento / float(portas)
	var vidro_h := camara_h - 0.06
	var meio_y := base_h + camara_h * 0.5
	for k in portas + 1:
		var dx := -comprimento * 0.5 + float(k) * larg
		dx = clampf(dx, -comprimento * 0.5 + 0.03, comprimento * 0.5 - 0.03)
		KitModular.caixa_cor(sup, &"metal_pintado", em.call(Vector3(dx, meio_y, frente)),
			Vector3(0.05, camara_h, 0.05), escuro, giro)
		KitModular.caixa_cor(sup, &"mercado_luz",
			em.call(Vector3(dx, meio_y, frente - 0.07)),
			Vector3(0.02, camara_h - 0.1, 0.02), Color("eef6ff"), giro)
	for y: float in [base_h + 0.02, alto - chapeu_h - 0.02]:
		KitModular.caixa_cor(sup, &"metal_pintado", em.call(Vector3(0.0, y, frente)),
			Vector3(comprimento, 0.04, 0.05), escuro, giro)
	for k in portas:
		var dx := -comprimento * 0.5 + (float(k) + 0.5) * larg
		KitModular.placa(sup, &"vitrine_loja", em.call(Vector3(dx, meio_y, frente + 0.012)),
			Vector2(larg - 0.05, vidro_h), giro, Color.WHITE)
		var lado_puxador := 1.0 if k % 2 == 0 else -1.0
		KitModular.caixa_cor(sup, &"metal_pintado",
			em.call(Vector3(dx + lado_puxador * (larg * 0.5 - 0.08), meio_y + 0.1, frente + 0.04)),
			Vector3(0.022, 0.42, 0.03), Color("c4c8ca"), giro)

	_solido(colisao, centro + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(comprimento, alto, prof), giro)
	return centro + b * Vector3(0.0, 1.2, 0.1)


## Fogao com chapa e coifa: e de onde sai o pastel e o torresmo.
static func fogao(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, 0.44, 0.0),
		Vector3(1.1, 0.88, 0.66), Color("8e9290"), giro)
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, 0.9, 0.0),
		Vector3(1.14, 0.05, 0.7), Color("3a3c3a"), giro)
	# Panela de oleo e a tampa. A cor quente na boca sugere fogo sem luz nova.
	KitModular.caixa_cor(sup, &"metal",
		centro + b * Vector3(-0.26, 1.02, 0.0),
		Vector3(0.36, 0.2, 0.36), Color("2a2c2a"), giro)
	KitModular.caixa_cor(sup, &"metal",
		centro + b * Vector3(0.28, 0.94, 0.0),
		Vector3(0.3, 0.03, 0.3), Color("c86a28"), giro)
	# Coifa de chapa, saindo da parede.
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, 1.92, 0.0),
		Vector3(1.24, 0.3, 0.8), Color("9a9e9c"), giro)
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, 2.4, 0.0),
		Vector3(0.34, 0.7, 0.34), Color("8a8e8c"), giro)
	_solido(colisao, centro + Vector3(0.0, 0.5, 0.0),
		Vector3(1.14, 1.0, 0.7), giro)


## Pia de inox no fundo do balcao, com o escorredor de copo.
static func pia(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, 0.44, 0.0),
		Vector3(1.0, 0.88, 0.6), Color("7a7e7c"), giro)
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, 0.92, 0.0),
		Vector3(1.04, 0.06, 0.64), Color("b6bab8"), giro)
	KitModular.caixa_cor(sup, &"metal",
		centro + b * Vector3(0.0, 1.14, -0.16),
		Vector3(0.03, 0.36, 0.03), Color("c2c6c4"), giro)
	for k in 3:
		KitModular.caixa_cor(sup, &"metal",
			centro + b * Vector3(-0.3 + 0.26 * float(k), 1.0, 0.14),
			Vector3(0.055, 0.1, 0.055), Color("b8d0c4"), giro)
	_solido(colisao, centro + Vector3(0.0, 0.48, 0.0),
		Vector3(1.04, 0.96, 0.64), giro)


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


## Prateleira atras do balcao: armario de madeira embaixo, tres prateleiras em
## cima, com cachaca, conhaque, vodca e a fileira de maco de cigarro, tudo com
## o rotulo do atlas do mercado (`ProdutosDoBar`). Os cubinhos coloridos de
## antes liam como brinquedo.
static func prateleira_garrafas(sup: Dictionary, colisao: Array[Dictionary],
		itens: Array, centro: Vector3, comprimento: float, giro: float,
		semente: int = 0) -> void:
	var b := Basis(Vector3.UP, giro)
	var madeira := Color("5a4030")
	var tampo := Color("6e4c34")
	var em := func(l: Vector3) -> Vector3:
		return centro + b * l
	# Fundo, laterais e o chapeu.
	KitModular.caixa_cor(sup, &"tabua", em.call(Vector3(0.0, 1.12, -0.13)),
		Vector3(comprimento, 2.24, 0.04), madeira, giro)
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"tabua",
			em.call(Vector3(lado * (comprimento * 0.5 - 0.02), 1.12, 0.0)),
			Vector3(0.04, 2.24, 0.3), madeira, giro)
	KitModular.caixa_cor(sup, &"tabua", em.call(Vector3(0.0, 2.26, 0.02)),
		Vector3(comprimento + 0.08, 0.06, 0.36), tampo, giro)
	# Armario de baixo, fechado, com o rodape escuro.
	KitModular.caixa_cor(sup, &"tabua", em.call(Vector3(0.0, 0.46, 0.0)),
		Vector3(comprimento - 0.04, 0.88, 0.3), Color("6a4a34"), giro)
	KitModular.caixa_cor(sup, &"tabua", em.call(Vector3(0.0, 0.05, 0.02)),
		Vector3(comprimento - 0.04, 0.1, 0.3), Color("3a2a1c"), giro)

	var niveis: Array[float] = [0.92, 1.32, 1.72]
	var cachaca: Array = [&"cachaca_51", &"velho_barreiro", &"catuaba"]
	var forte: Array = [&"dreher", &"orloff", &"velho_barreiro", &"cachaca_51"]
	var maco: Array = [&"hollywood", &"free", &"derby", &"marlboro", &"carlton",
		&"minister", &"charm"]
	var dentro := comprimento * 0.5 - 0.07
	for n in niveis.size():
		var y: float = niveis[n]
		KitModular.caixa_cor(sup, &"tabua", em.call(Vector3(0.0, y - 0.018, 0.0)),
			Vector3(comprimento - 0.04, 0.036, 0.3), tampo, giro)
		var skus: Array = maco if n == 0 else (cachaca if n == 1 else forte)
		ProdutosDoBar.fileira(itens, skus, em.call(Vector3(-dentro, y, 0.06)),
			em.call(Vector3(dentro, y, 0.06)), giro, 3 if n == 0 else 2,
			0.0 if n == 0 else 0.11, semente + 29 * n)
	_solido(colisao, centro + Vector3(0.0, 1.1, 0.0),
		Vector3(comprimento, 2.2, 0.32), giro)


## Pendente do teto: cupula de boteco, so silhueta. A luz e o prop Lampada.
## `onde` e o ponto da CUPULA; o fio sobe dali ate o forro.
static func pendente(sup: Dictionary, onde: Vector3) -> void:
	KitModular.caixa_cor(sup, &"metal", onde + Vector3(0.0, 0.26, 0.0),
		Vector3(0.012, 0.3, 0.012), METAL_ESCURO)
	MoveisDoBar.por(sup, MoveisDoBar.cupula(), Transform3D(Basis.IDENTITY, onde))


## Painel de parede com moldura de madeira. E a base do cartaz, do cardapio,
## da placa de fiado e do santo — o que muda e a textura.
static func painel(sup: Dictionary, material: StringName, centro: Vector3,
		tamanho: Vector2, giro: float, moldura: Color = Color("3a2a1c")) -> void:
	KitModular.placa(sup, material, centro, tamanho, giro, Color.WHITE,
		SUBDIVISAO_PAINEL)
	KitModular.caixa_cor(sup, &"tabua",
		centro + Basis(Vector3.UP, giro) * Vector3(0.0, 0.0, -0.02),
		Vector3(tamanho.x + 0.05, tamanho.y + 0.05, 0.03), moldura, giro)


## Cartaz de partida na parede. `giro` aponta a frente.
static func cartaz(sup: Dictionary, centro: Vector3, giro: float) -> void:
	painel(sup, &"bar_cartaz", centro, Vector2(0.72, 0.95), giro)


## Lousa de preco atras do balcao.
static func cardapio(sup: Dictionary, centro: Vector3, giro: float) -> void:
	painel(sup, &"bar_cardapio", centro, Vector2(0.9, 1.1), giro, Color("4a3420"))


## "FIADO SO AMANHA": a piada que toda parede de boteco tem.
static func placa_fiado(sup: Dictionary, centro: Vector3, giro: float) -> void:
	painel(sup, &"bar_placa", centro, Vector2(0.62, 0.32), giro, Color("6a4a2c"))


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
