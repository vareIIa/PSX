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

## Distancia da boca do bar ate o centro da fileira de mesas da calcada.
##
## Unica fonte. O chunk desenha as mesas com este numero e a captura da rua mira
## o mesmo. Escrito em dois lugares, a mesa some da foto ou invade a rua no
## primeiro ajuste de toldo.
const AFASTAMENTO_MESA := 1.45
const MESAS_CALCADA := 4

const ALTURA_BALCAO := 1.08
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
		var px := lado * (meia - PILAR * 0.5)
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


## Letreiro aceso mais a faixa de chamada. Na nevoa e a mancha amarela de cima.
static func letreiro(sup: Dictionary, boca: Vector3, giro: float,
		largura: float, estilo: Dictionary = {}) -> void:
	var b := Basis(Vector3.UP, giro)
	var comp := clampf(largura - 3.4, 3.0, 6.4)
	var pos := _p(boca, b, 0.0, ALTURA_FACHADA + 0.58, -0.26)
	if estilo.has("nome"):
		# A placa pintada do bar (atlas `bares_nomes`, BarVivo.NOMES) na caixa de
		# chapa da cor da parede. A celula e 4:1: a placa fica nessa proporcao, no
		# meio da caixa, e nao esticada.
		KitModular.caixa_cor(sup, &"metal_pintado", pos, Vector3(comp, 0.95, 0.16),
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
			Vector3(comp, 0.95, 0.16), Color.WHITE, giro)
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



## Mesas, cadeiras e tralha da calcada, espalhadas na frente do bar.
##
## Deixam o meio livre: e por ali que se entra, e mesa atravessada na boca
## desmente o bar inteiro.
static func mesas_da_calcada(sup: Dictionary, colisao: Array[Dictionary],
		boca: Vector3, giro: float, largura: float, estilo: Dictionary = {}) -> void:
	var b := Basis(Vector3.UP, giro)
	var meia := largura * 0.5
	var plastico: Color = estilo.get("plastico", PLASTICO)
	var lugares: Array[float] = [
		-(meia - 1.2), -(meia - 2.7), meia - 2.7, meia - 1.2,
	]
	for i in lugares.size():
		var base := _p(boca, b, lugares[i], 0.0, -AFASTAMENTO_MESA)
		var torto := 0.12 if i % 2 == 0 else -0.08
		mesa(sup, colisao, base, giro + torto, i == 1)
		# Tres cadeiras: duas de frente uma para a outra e uma de costas para a
		# rua. Duas por mesa lia como cafe; tres e boteco.
		cadeira(sup, colisao, base + b * Vector3(0.5, 0.0, 0.06),
			giro + PI * 0.5, i % 2 == 0, plastico)
		cadeira(sup, colisao, base + b * Vector3(-0.5, 0.0, -0.06),
			giro - PI * 0.5, i % 2 == 1, plastico)
		cadeira(sup, colisao, base + b * Vector3(0.0, 0.0, -0.52), giro + PI,
			i % 3 == 0, plastico)
		var tampo := base + Vector3(0.0, ALTURA_MESA + 0.05, 0.0)
		copo(sup, tampo + b * Vector3(0.14, 0.0, -0.1), giro)
		if i % 2 == 0:
			garrafa(sup, tampo + b * Vector3(-0.12, 0.0, 0.08),
				Color("3f6f4a"), giro)
		else:
			cinzeiro(sup, tampo + b * Vector3(-0.1, 0.0, -0.08), giro)
		if i == 1 or i == 2:
			guarda_sol(sup, base, giro, estilo.get("toldo", &"bar_toldo"))

	# Tralha encostada nos pilares, fora do caminho de quem entra.
	engradados(sup, colisao, _p(boca, b, meia - 0.75, 0.0, -0.62), giro, 4)
	botijao(sup, colisao, _p(boca, b, -(meia - 0.72), 0.0, -0.6), giro)
	lixeira(sup, colisao, _p(boca, b, -(meia - 1.4), 0.0, -0.6), giro)


## Guarda-sol de mesa de calcada. Haste, copa e a aba caida.
static func guarda_sol(sup: Dictionary, base: Vector3, giro: float,
		tecido: StringName = &"bar_toldo") -> void:
	var b := Basis(Vector3.UP, giro)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 1.2, 0.0),
		Vector3(0.045, 2.3, 0.045), Color("6a6c68"), giro)
	KitModular.caixa_cor(sup, tecido, base + Vector3(0.0, 2.34, 0.0),
		Vector3(1.9, 0.05, 1.9), Color.WHITE, giro)
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, tecido,
			base + Vector3(0.0, 2.22, 0.0) + b * Vector3(lado * 0.95, 0.0, 0.0),
			Vector3(0.04, 0.2, 1.9), Color.WHITE, giro)
		KitModular.caixa_cor(sup, tecido,
			base + Vector3(0.0, 2.22, 0.0) + b * Vector3(0.0, 0.0, lado * 0.95),
			Vector3(1.9, 0.2, 0.04), Color.WHITE, giro)


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

	_casca_do_salao(sup, colisao, boca, b, giro, largura, fundo, estilo)

	var mesas := 0
	var cadeiras := 0

	# --- balcao em L, do lado direito de quem entra --------------------------
	var bx := meia - 1.05
	var comp := fundo - 3.0
	balcao(sup, colisao, _p(boca, b, bx, 0.0, 1.5 + comp * 0.5), comp,
		giro - PI * 0.5)
	prateleira_garrafas(sup, colisao, _p(boca, b, meia - 0.18, 0.0, 3.4),
		minf(3.4, fundo - 2.6), giro - PI * 0.5)
	cardapio(sup, _p(boca, b, meia - 0.06, 2.05, 5.4), giro - PI * 0.5)
	pia(sup, colisao, _p(boca, b, meia - 0.5, 0.0, 2.1), giro - PI * 0.5)
	fogao(sup, colisao, _p(boca, b, meia - 0.85, 0.0, fundo - 0.6), giro + PI)

	# Vitrine de salgado na ponta do balcao virada para a rua: e o primeiro
	# ponto aceso que quem passa na calcada ve dentro do bar.
	var tampo_y := ALTURA_BALCAO + 0.08
	vitrine_salgados(sup, _p(boca, b, bx, tampo_y, 1.85), giro - PI * 0.5)
	copo(sup, _p(boca, b, bx - 0.18, tampo_y, 3.3), giro)
	copo(sup, _p(boca, b, bx - 0.22, tampo_y, 3.5), giro)
	garrafa(sup, _p(boca, b, bx - 0.1, tampo_y, 3.0), Color("c45a2a"), giro)
	cinzeiro(sup, _p(boca, b, bx - 0.16, tampo_y, 4.2), giro)

	for i in 3:
		banqueta(sup, colisao, _p(boca, b, bx - 0.95, 0.0, 2.6 + 0.78 * float(i)),
			giro - PI * 0.5)
		cadeiras += 1

	# --- cervejeira e TV -----------------------------------------------------
	var luz_fria := cervejeira(sup, colisao,
		_p(boca, b, -meia + 2.4, 0.0, fundo - 0.36), 4.0, giro, 3)
	props.append({
		"tipo": "lampada", "pos": luz_fria,
		"padrao": Lampada.Padrao.ESTAVEL, "semente": semente + 811,
		"cor": LUZ_FRIA, "energia": 1.1, "alcance": 5.0, "facho": false,
	})

	var tela := _p(boca, b, -meia + 0.32, 2.0, 2.6)
	tv_gabinete(sup, colisao, tela, giro + PI * 0.5)
	props.append({"tipo": "televisao", "pos": tela + b * Vector3(0.08, 0.0, 0.0),
		"giro": giro + PI * 0.5})
	cartaz(sup, _p(boca, b, -meia + 0.06, 2.4, 4.4), giro + PI * 0.5)
	relogio(sup, _p(boca, b, -meia + 0.06, 2.45, 1.4), giro + PI * 0.5)
	placa_fiado(sup, _p(boca, b, meia - 0.06, 1.95, 1.5), giro - PI * 0.5)

	# --- sinuca, so quando o predio deu largura ------------------------------
	var sinuca_em := Vector3.ZERO
	if tem_sinuca:
		sinuca_em = _p(boca, b, -meia + 1.75, 0.0, fundo - 2.1)
		sinuca(sup, colisao, sinuca_em, giro + PI * 0.5)
		props.append({
			"tipo": "lampada", "pos": sinuca_em + Vector3(0.0, 2.0, 0.0),
			"padrao": Lampada.Padrao.ESTAVEL, "semente": semente + 933,
			"cor": Color("ffe0b8"), "energia": 1.0, "alcance": 3.6,
			"facho": false,
		})

	# --- mesas do salao ------------------------------------------------------
	# Ficam na metade esquerda da frente, que e a faixa que sobra entre a TV e
	# o balcao. Mesa no meio da boca fecharia a entrada.
	var postos: Array[Vector3] = [
		_p(boca, b, -meia + 1.15, 0.0, 1.45),
		_p(boca, b, -meia + 2.75, 0.0, 1.55),
		_p(boca, b, -meia + 1.30, 0.0, 3.35),
	]
	if not tem_sinuca:
		postos.append(_p(boca, b, -meia + 2.9, 0.0, 3.5))
	for i in postos.size():
		mesa(sup, colisao, postos[i], giro + 0.09 * float(i), i % 2 == 1)
		mesas += 1
		# A mesa da TV nao leva cadeira: quem assiste senta no chao de frente
		# para o tubo, e o assento nasceria dentro do corpo.
		if i != 2:
			cadeira(sup, colisao, postos[i] + b * Vector3(0.48, 0.0, 0.06),
				giro + PI * 0.5, i % 2 == 0, estilo.get("plastico", PLASTICO))
			cadeira(sup, colisao, postos[i] + b * Vector3(-0.48, 0.0, -0.04),
				giro - PI * 0.5, i % 2 == 1, estilo.get("plastico", PLASTICO))
			cadeiras += 2
		var t := postos[i] + Vector3(0.0, ALTURA_MESA + 0.04, 0.0)
		copo(sup, t + b * Vector3(0.14, 0.0, 0.1), giro)
		if i != 2:
			garrafa(sup, t + b * Vector3(-0.12, 0.0, -0.08),
				Color("3f6f4a") if i % 3 == 0 else Color("8a3a32"), giro)
		else:
			cinzeiro(sup, t + b * Vector3(-0.1, 0.0, 0.08), giro)

	# --- canto de servico ----------------------------------------------------
	caixa_plastico(sup, colisao, _p(boca, b, -meia + 0.5, 0.0, fundo - 1.1),
		giro - 0.3)
	vassoura(sup, _p(boca, b, -meia + 0.35, 0.0, fundo - 1.6), giro + 0.4)
	engradados(sup, colisao, _p(boca, b, meia - 0.55, 0.0, fundo - 1.4), giro, 3)

	_som_e_luz(sup, props, boca, b, largura, fundo, semente)
	_gente(props, boca, b, giro, meia, fundo, tem_sinuca, sinuca_em, semente)

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

	# Forro.
	KitModular.caixa_cor(sup, &"bar_teto",
		_p(boca, b, 0.0, ALTURA_SALAO + 0.05, centro_z),
		Vector3(largura, 0.1, fundo), Color("bfae92"), giro)

	# Parede do fundo e as duas laterais, com azulejo ate a altura do peito.
	var paredes: Array[Dictionary] = [
		{"c": _p(boca, b, 0.0, 0.0, fundo), "t": Vector3(largura, 0.0, ESPESSURA),
			"g": giro},
		{"c": _p(boca, b, -meia - ESPESSURA * 0.5, 0.0, centro_z),
			"t": Vector3(ESPESSURA, 0.0, fundo), "g": giro},
		{"c": _p(boca, b, meia + ESPESSURA * 0.5, 0.0, centro_z),
			"t": Vector3(ESPESSURA, 0.0, fundo), "g": giro},
	]
	for pa: Dictionary in paredes:
		var c: Vector3 = pa["c"]
		var t: Vector3 = pa["t"]
		KitModular.caixa_cor(sup, &"bar_parede",
			c + Vector3(0.0, ALTURA_SALAO * 0.5, 0.0),
			Vector3(t.x, ALTURA_SALAO, t.z), parede, pa["g"])
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


## Quem esta no bar. O atendente atras do balcao, um cliente na banqueta, dois
## na mesa da TV e, quando ha sinuca, mais dois em volta dela.
static func _gente(props: Array[Dictionary], boca: Vector3, b: Basis,
		giro: float, meia: float, fundo: float, tem_sinuca: bool,
		sinuca_em: Vector3, semente: int) -> void:
	var bx := meia - 1.05
	var cliente := _p(boca, b, bx - 0.95, 0.0, 3.38)
	var atendente := _p(boca, b, bx + 0.85, 0.0, 3.6)
	_convidado(props, atendente, semente + 211, Convidado.Papel.LIVRE, true,
		cliente + Vector3(0.0, 1.4, 0.0), 28, 62)
	_convidado(props, cliente, semente + 523, Convidado.Papel.LIVRE, false,
		atendente + Vector3(0.0, 1.4, 0.0), 22, 58)

	var tv := _p(boca, b, -meia + 0.5, 1.6, 2.6)
	_convidado(props, _p(boca, b, -meia + 1.1, 0.0, 3.0),
		semente + 307, Convidado.Papel.SENTADO, true, tv, 22, 58)
	_convidado(props, _p(boca, b, -meia + 1.7, 0.0, 3.05),
		semente + 419, Convidado.Papel.SENTADO, false, tv, 22, 58)

	if not tem_sinuca:
		return
	var pano := sinuca_em + Vector3(0.0, 0.9, 0.0)
	_convidado(props, _p(boca, b, -meia + 0.7, 0.0, fundo - 2.1),
		semente + 631, Convidado.Papel.LIVRE, false, pano, 22, 58)
	_convidado(props, _p(boca, b, -meia + 2.9, 0.0, fundo - 2.2),
		semente + 743, Convidado.Papel.LIVRE, true, pano, 22, 58)


static func _convidado(props: Array[Dictionary], onde: Vector3, semente: int,
		papel: int, fuma: bool, foco: Vector3, idade_min: int,
		idade_max: int) -> void:
	props.append({
		"tipo": "convidado", "pos": onde, "semente": semente, "papel": papel,
		"fuma": fuma, "idade_min": idade_min, "idade_max": idade_max,
		"foco": foco, "pontos": [], "chapado": false, "olhos": false,
	})


# --- moveis e miudezas ------------------------------------------------------------------

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
	# Peitoril do lado do cliente.
	KitModular.caixa_cor(sup, &"bar_formica",
		centro + b * Vector3(0.0, alto + 0.08, prof * 0.5 + 0.02),
		Vector3(comprimento + 0.04, 0.06, 0.06), Color("5a3c28"), giro)
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


## Vitrine de salgado em cima do balcao. Acesa por dentro, como a de verdade.
static func vitrine_salgados(sup: Dictionary, base: Vector3, giro: float) -> void:
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.03, 0.0),
		Vector3(0.62, 0.06, 0.44), METAL_ESCURO, giro)
	KitModular.caixa_cor(sup, &"bar_salgados", base + Vector3(0.0, 0.3, 0.0),
		Vector3(0.58, 0.46, 0.4), Color.WHITE, giro)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.55, 0.0),
		Vector3(0.64, 0.05, 0.46), METAL_ESCURO, giro)


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


## Mesa de sinuca. O movel que mais diz "bar de Minas" num salao so de mesas.
##
## Tabuleiro de feltro, borda de madeira, seis cacapas escuras e o taco
## encostado. Nao e jogavel: e cenario com colisao.
static func sinuca(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	const COMP := 2.24
	const LARG := 1.24
	const ALTO := 0.78
	KitModular.caixa_cor(sup, &"tabua",
		centro + Vector3(0.0, ALTO - 0.16, 0.0),
		Vector3(COMP + 0.16, 0.3, LARG + 0.16), Color("5a3a22"), giro)
	KitModular.caixa_cor(sup, &"bar_feltro",
		centro + Vector3(0.0, ALTO + 0.01, 0.0),
		Vector3(COMP, 0.04, LARG), Color.WHITE, giro)
	# Tabelas: quatro caixas em volta do pano.
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"tabua",
			centro + b * Vector3(lado * (COMP * 0.5 + 0.04), ALTO + 0.04, 0.0),
			Vector3(0.1, 0.1, LARG + 0.2), Color("6a4628"), giro)
		KitModular.caixa_cor(sup, &"tabua",
			centro + b * Vector3(0.0, ALTO + 0.04, lado * (LARG * 0.5 + 0.04)),
			Vector3(COMP + 0.2, 0.1, 0.1), Color("6a4628"), giro)
	# Pes.
	for lx: float in [-1.0, 1.0]:
		for lz: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"tabua",
				centro + b * Vector3(lx * (COMP * 0.5 - 0.18),
					(ALTO - 0.3) * 0.5, lz * (LARG * 0.5 - 0.16)),
				Vector3(0.14, ALTO - 0.3, 0.14), Color("4a3018"), giro)
	# Cacapas e bolas. Bola e um cubinho de 4 cm: a 480x270 ninguem ve aresta.
	for lx: float in [-1.0, 1.0]:
		for lz: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"metal",
				centro + b * Vector3(lx * (COMP * 0.5 - 0.06), ALTO + 0.02,
					lz * (LARG * 0.5 - 0.05)),
				Vector3(0.14, 0.06, 0.14), Color("1a1614"), giro)
	var cores: Array[Color] = [
		Color("e8e2d0"), Color("d8b032"), Color("c03830"), Color("2c5a9a"),
	]
	for k in cores.size():
		var ang := float(k) * 0.9
		KitModular.caixa_cor(sup, &"metal",
			centro + b * Vector3(0.35 + 0.13 * float(k % 4), ALTO + 0.05,
				0.1 * sin(ang)),
			Vector3(0.05, 0.05, 0.05), cores[k], giro)
	# Taco encostado na tabela.
	KitModular.caixa_livre(sup, &"tabua",
		centro + b * Vector3(-COMP * 0.5 - 0.3, 0.78, LARG * 0.5 + 0.1),
		Vector3(0.03, 1.42, 0.03),
		b * Basis(Vector3.FORWARD, 0.26), Color("b08a4c"))
	# Luminaria comprida em cima, so silhueta: a Lampada e prop da planta.
	KitModular.caixa_cor(sup, &"metal",
		centro + Vector3(0.0, 2.1, 0.0),
		Vector3(COMP * 0.8, 0.16, 0.26), Color("2c2e2c"), giro)
	_solido(colisao, centro + Vector3(0.0, ALTO * 0.5, 0.0),
		Vector3(COMP + 0.2, ALTO + 0.1, LARG + 0.2), giro)


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
		# Uma garrafa a cada 32 cm. A 16 cm eram 63 caixinhas so aqui, e de
		# dois metros de distancia elas leem como a mesma fileira.
		var n := maxi(5, int(comprimento / 0.32))
		for k in n:
			var dx := -comprimento * 0.5 + 0.12 + float(k) * (comprimento - 0.24) / float(n - 1)
			var alto := 0.22 if (k + nivel) % 3 != 0 else 0.30
			KitModular.caixa_cor(sup, &"metal",
				centro + b * Vector3(dx, y + alto * 0.5 + 0.02, 0.04),
				Vector3(0.07, alto, 0.07), cores[(k + nivel) % cores.size()], giro)
	_solido(colisao, centro + Vector3(0.0, 1.1, 0.0),
		Vector3(comprimento, 2.2, 0.32), giro)


## Pendente do teto: cupula de boteco, so silhueta. A luz e o prop Lampada.
## `onde` e o ponto da CUPULA; o fio sobe dali ate o forro.
static func pendente(sup: Dictionary, onde: Vector3) -> void:
	KitModular.caixa_cor(sup, &"metal", onde + Vector3(0.0, 0.17, 0.0),
		Vector3(0.04, 0.34, 0.04), METAL_ESCURO)
	KitModular.caixa_cor(sup, &"metal", onde,
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
