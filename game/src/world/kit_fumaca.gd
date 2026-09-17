## A frente da casa da fumaca, sobre a fachada do chunk.
##
## Por que isto existe
## -------------------
## A casa da fumaca e o destino da primeira missao do jogo, e ate agora a porta
## dela era IDENTICA a de qualquer casa: mesma folha, mesma macaneta, mesma
## verga. A captura do endereco real (chunk 3,-6) mostrou uma casa branca limpa
## de classe media, indistinguivel das duas vizinhas no mesmo quadro — e atras
## daquela porta tem oito pessoas, som alto, luz magenta e fumaca ate o teto.
## Nada vazava.
##
## O que faz um lugar ser reconhecivel de longe nao e detalhe, e SILHUETA e COR.
## A dezoito metros, com a nevoa fechando, o jogador nao le uma pichacao nem uma
## caixa de cerveja: ele le que aquela casa tem um telheiro na frente, um vao
## magenta acima da porta e duas brasas paradas na calcada. E so quando chega
## perto que o resto aparece.
##
## Por isso a ordem das pecas aqui e a ordem da distancia em que cada uma
## comeca a valer:
##
##   telheiro e grade   silhueta, 20 m
##   bandeira magenta   cor, 18 m
##   som atravessando   antes da imagem, 14 m
##   gente e brasa      12 m
##   fumaca da fresta   8 m
##   engradado e tag    5 m
##
## Vale para TODA casa da fumaca da cidade — sao 22 num raio de 24 chunks — e
## nao so para a da missao. O jogador tem de aprender a reconhecer o lugar; com
## uma casa marcada so, ele decora um endereco.
##
## Eixo local, igual ao do bar
## ---------------------------
## `base` e a DOBRADICA da porta, no plano da parede, na altura da calcada.
## A folha corre de x=0 a x=0,9 (ver Porta._montar), entao o centro do vao esta
## meia folha adiante. +X corre pela fachada, +Z aponta para a rua.
class_name KitFumaca
extends RefCounted

## Meia largura da folha: e onde fica o eixo da porta.
const MEIA_PORTA := 0.45
## Altura do vao da porta, de Porta._montar.
const ALTURA_PORTA := 2.05

## O telheiro sobre a porta.
## Mais alto e mais raso do que a primeira versao. Com 1,05 m de balanco a 2,52,
## o telheiro tapava a bandeira para quem olhava da calcada — ou seja, a peca
## que existe para dar silhueta estava comendo a peca que existe para dar cor.
const TELHEIRO_Y := 2.58
const TELHEIRO := Vector3(2.05, 0.10, 0.82)

## A bandeira — o vao de vidro acima da porta.
##
## Fica ENTRE a verga da porta (2,05) e o telheiro (2,47 na face de baixo), que
## e a unica faixa da fachada onde o gerador de janelas nao poe nada. Uma
## vidraca nova no meio da parede correria o risco de nascer em cima de uma
## janela sorteada, e duas janelas sobrepostas leem como erro, nao como casa.
const BANDEIRA_Y := 2.24
const BANDEIRA := Vector2(0.86, 0.34)

## O degrau. Baixo de proposito: o jogador sobe nele andando, sem pulo e sem
## travar, e a colisao de 9 cm passa por piso em qualquer `floor_max_angle`.
const DEGRAU_ALTURA := 0.09
const DEGRAU := Vector3(1.9, DEGRAU_ALTURA, 0.95)

## A grade. Dois trechos, um de cada lado, com o VAO DA PORTA aberto no meio.
##
## Fechada, ela bloquearia o raio de interacao e a casa da primeira missao do
## jogo viraria uma porta que nao abre. Aberta no eixo da folha, ela cumpre a
## silhueta e deixa o caminho livre — que e como um portao de casa fica quando
## tem gente entrando e saindo a noite toda.
const GRADE_ALTURA := 1.02
const GRADE_AFASTAMENTO := 1.02
const GRADE_VAO := 1.30
const GRADE_TRECHO := 1.45

const COR_METAL := Color("55585a")
const COR_CONCRETO := Color("9a968c")
const COR_TELHA := Color("6e5a4a")


## Monta a frente inteira. `props` recebe a luz e o som; `colisao` recebe o
## degrau, a grade e o engradado.
static func fachada(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float, semente: int) -> void:
	var b := Basis(Vector3.UP, giro)
	var eixo := base + b * Vector3(MEIA_PORTA, 0.0, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente

	_degrau(sup, colisao, eixo, b, giro)
	_telheiro(sup, eixo, b, giro)
	_bandeira(sup, eixo, b, giro)
	_fresta_da_porta(sup, eixo, b, giro)
	_grade(sup, colisao, eixo, b, giro)
	_engradado(sup, colisao, eixo, b, giro, rng)
	_tag(sup, eixo, b, giro, rng)
	_fumaca_da_fresta(sup, eixo, b)


# --- silhueta ---------------------------------------------------------------

static func _degrau(sup: Dictionary, colisao: Array[Dictionary], eixo: Vector3,
		b: Basis, giro: float) -> void:
	var onde := eixo + b * Vector3(0.0, DEGRAU_ALTURA * 0.5, DEGRAU.z * 0.5 - 0.04)
	KitModular.caixa_cor(sup, &"concreto", onde, DEGRAU, COR_CONCRETO, giro)
	colisao.append({"tamanho": DEGRAU, "pos": onde})


## Telheiro de duas aguas sobre a porta, em dois mãos-francesas.
##
## Nao e marquise de loja: e a telha ondulada que se poe sobre a porta para a
## chuva nao bater em quem esta destrancando. E o unico volume desta fachada que
## se ve de vinte metros, e e ele que faz a casa nao ser mais uma parede.
static func _telheiro(sup: Dictionary, eixo: Vector3, b: Basis,
		giro: float) -> void:
	var centro := eixo + b * Vector3(0.0, TELHEIRO_Y, TELHEIRO.z * 0.5 - 0.06)
	# Duas aguas: duas placas inclinadas encostadas na cumeeira. Uma so leria
	# como prateleira.
	for lado: float in [-1.0, 1.0]:
		var inclina := Basis(Vector3(cos(giro), 0.0, -sin(giro)), lado * 0.30)
		KitModular.caixa_livre(sup, &"metal_ondulado",
			centro + b * Vector3(0.0, 0.02, lado * TELHEIRO.z * 0.24),
			Vector3(TELHEIRO.x, 0.05, TELHEIRO.z * 0.54),
			inclina * b, COR_TELHA)
	# As duas maos-francesas, da parede ate a ponta.
	for lado: float in [-1.0, 1.0]:
		var pe := eixo + b * Vector3(lado * (TELHEIRO.x * 0.5 - 0.10),
			TELHEIRO_Y - 0.46, 0.06)
		KitModular.caixa_livre(sup, &"metal",
			pe + b * Vector3(0.0, 0.20, TELHEIRO.z * 0.36),
			Vector3(0.05, 0.05, 0.92),
			Basis(Vector3(cos(giro), 0.0, -sin(giro)), 0.46) * b, COR_METAL)


## A bandeira magenta. Vidro emissivo com caixilho fino em volta.
static func _bandeira(sup: Dictionary, eixo: Vector3, b: Basis,
		giro: float) -> void:
	var centro := eixo + b * Vector3(0.0, BANDEIRA_Y, 0.05)
	KitModular.parede_livre(sup, &"janela_fumaca", centro, BANDEIRA, giro)
	# Caixilho: quatro barras finas. Sem ele o retangulo aceso le como buraco
	# recortado na parede, que e o mesmo defeito que a TV da sala teve.
	for par: Array in [
			[Vector3(0.0, BANDEIRA.y * 0.5 + 0.03, 0.0), Vector3(BANDEIRA.x + 0.12, 0.05, 0.06)],
			[Vector3(0.0, -BANDEIRA.y * 0.5 - 0.03, 0.0), Vector3(BANDEIRA.x + 0.12, 0.05, 0.06)],
			[Vector3(BANDEIRA.x * 0.5 + 0.03, 0.0, 0.0), Vector3(0.05, BANDEIRA.y, 0.06)],
			[Vector3(-BANDEIRA.x * 0.5 - 0.03, 0.0, 0.0), Vector3(0.05, BANDEIRA.y, 0.06)]]:
		KitModular.caixa_cor(sup, &"metal", centro + b * (par[0] as Vector3),
			par[1] as Vector3, COR_METAL, giro)
	# Uma travessa no meio, na vertical: e o que faz a bandeira ler como
	# esquadria e nao como painel de luz.
	KitModular.caixa_cor(sup, &"metal", centro + b * Vector3(0.0, 0.0, 0.01),
		Vector3(0.04, BANDEIRA.y, 0.05), COR_METAL, giro)


## A nesga de luz embaixo da porta.
##
## Cinco centimetros de vidraca magenta rente ao degrau. E o detalhe mais barato
## desta fachada e o que mais diz que tem gente acordada la dentro: porta
## fechada com luz saindo por baixo e a imagem de casa cheia a noite. Custa dois
## triangulos e nenhuma luz — a emissao e do material.
static func _fresta_da_porta(sup: Dictionary, eixo: Vector3, b: Basis,
		giro: float) -> void:
	KitModular.parede_livre(sup, &"janela_fumaca",
		eixo + b * Vector3(0.0, 0.155, 0.055), Vector2(0.86, 0.05), giro)


## A grade baixa, em dois trechos com o vao da porta aberto no meio.
static func _grade(sup: Dictionary, colisao: Array[Dictionary], eixo: Vector3,
		b: Basis, giro: float) -> void:
	for lado: float in [-1.0, 1.0]:
		var meio_x := lado * (GRADE_VAO * 0.5 + GRADE_TRECHO * 0.5)
		var centro := eixo + b * Vector3(meio_x, GRADE_ALTURA * 0.5,
			GRADE_AFASTAMENTO)
		# Travessa de cima e de baixo.
		for y: float in [GRADE_ALTURA * 0.5 - 0.03, -GRADE_ALTURA * 0.5 + 0.14]:
			KitModular.caixa_cor(sup, &"metal", centro + b * Vector3(0.0, y, 0.0),
				Vector3(GRADE_TRECHO, 0.05, 0.05), COR_METAL, giro)
		# Barras verticais, a cada dezoito centimetros.
		var quantas := int(GRADE_TRECHO / 0.18)
		for k in quantas:
			var x := -GRADE_TRECHO * 0.5 + 0.09 + float(k) * 0.18
			KitModular.caixa_cor(sup, &"metal", centro + b * Vector3(x, 0.0, 0.0),
				Vector3(0.035, GRADE_ALTURA, 0.035), COR_METAL, giro)
		# Montante de ponta, mais grosso: e o batente do portao.
		var ponta := lado * (GRADE_VAO * 0.5 + 0.05)
		KitModular.caixa_cor(sup, &"metal",
			eixo + b * Vector3(ponta, GRADE_ALTURA * 0.5 + 0.06,
				GRADE_AFASTAMENTO),
			Vector3(0.08, GRADE_ALTURA + 0.12, 0.08), COR_METAL, giro)
		colisao.append({
			"tamanho": Vector3(GRADE_TRECHO, GRADE_ALTURA, 0.12),
			"pos": centro,
		})


# --- o que aparece de perto -------------------------------------------------

## Engradado de cerveja empilhado ao lado da porta.
##
## Diz festa sem dizer nada, e diz a HORA da festa: engradado cheio le como
## comeco de noite, vazio le como fim. Aqui sao tres, e o de cima esta torto.
##
## Vai em `metal` tingido de vermelho, e nao em `metal_enferrujado`. A diferenca
## nao e de aparencia — a essa escala as duas texturas sao a mesma sujeira — e
## sim de CHAMADA DE DESENHO: `metal` ja existe em todo chunk (semaforo, poste,
## grade), e `metal_enferrujado` nao existia neste. Superficie nova numa peca que
## se repete em 22 enderecos e superficie nova em 22 chunks.
static func _engradado(sup: Dictionary, colisao: Array[Dictionary],
		eixo: Vector3, b: Basis, giro: float,
		rng: RandomNumberGenerator) -> void:
	var canto := eixo + b * Vector3(-1.32, 0.0, 0.42)
	for k in 3:
		var torto := rng.randf_range(-0.18, 0.18)
		var desvio := Vector3(rng.randf_range(-0.04, 0.04), 0.0,
			rng.randf_range(-0.04, 0.04))
		KitModular.caixa_cor(sup, &"metal",
			canto + b * (desvio + Vector3(0.0, 0.13 + float(k) * 0.29, 0.0)),
			Vector3(0.44, 0.24, 0.44), Color("9a5340"), giro + torto)
	colisao.append({"tamanho": Vector3(0.5, 0.86, 0.5),
		"pos": canto + b * Vector3(0.0, 0.43, 0.0)})


## Pichacao na parede, ao lado da porta.
##
## Sao cinco riscos de caixa fina mais uma travessa, tingidos de escuro. Nao tem
## celula de atlas e nao vai ter: a trinta e dois pixels, com nevoa, uma tag
## desenhada e uma tag feita de risco dao a mesma mancha — e o risco nao custa
## textura nova.
##
## `concreto_sujo` pelo mesmo motivo do engradado: e um material que todo chunk
## ja carrega. Em `reboco` a tag ficava igual e trazia uma superficie a mais.
static func _tag(sup: Dictionary, eixo: Vector3, b: Basis, giro: float,
		rng: RandomNumberGenerator) -> void:
	var cor := Color("2a2230") if rng.randf() < 0.5 else Color("31201c")
	var origem := eixo + b * Vector3(1.62, 1.26, 0.03)
	var normal := Vector3(sin(giro), 0.0, cos(giro))
	# A travessa vem primeiro, e e ela que faz a coisa ler como escrita. Sem uma
	# linha amarrando os riscos, cinco barras verticais numa parede leem como
	# arranhao — foi o que a primeira captura mostrou.
	KitModular.caixa_livre(sup, &"concreto_sujo",
		origem + b * Vector3(0.0, -0.02, 0.0), Vector3(0.98, 0.075, 0.02),
		Basis(normal, -0.07) * b, cor)
	for k in 5:
		var alto := rng.randf_range(0.30, 0.54)
		var giro_risco := rng.randf_range(-0.42, 0.42)
		KitModular.caixa_livre(sup, &"concreto_sujo",
			origem + b * Vector3(float(k) * 0.21 - 0.42,
				rng.randf_range(-0.08, 0.12), 0.0),
			Vector3(0.095, alto, 0.02), Basis(normal, giro_risco) * b, cor)


## O fio de fumaca saindo pela fresta da porta.
##
## Duas placas cruzadas, como as do cinzeiro la dentro — ver
## CasaFumacaBuilder._coluna_de_fumaca, que e a mesma receita. Cruzadas porque
## uma so some quando o jogador contorna a calcada.
static func _fumaca_da_fresta(sup: Dictionary, eixo: Vector3, b: Basis) -> void:
	if not sup.has(&"fumaca_baseado"):
		sup[&"fumaca_baseado"] = PSXMesh.dados_vazios()
	var pe := eixo + b * Vector3(0.30, ALTURA_PORTA - 0.55, 0.16)
	for k in 2:
		var d := PSXMesh.placa_dados(Vector2(0.22, 0.80), 0.40,
			Color(1.0, 0.94, 0.86, 0.52))
		PSXMesh.acumular(sup[&"fumaca_baseado"], d,
			Transform3D(b * Basis(Vector3.UP, float(k) * PI * 0.5),
				pe + Vector3(0.0, 0.40, 0.0)))


# --- props ------------------------------------------------------------------

## Luz, som e a gente da calcada.
##
## Orcamento de luz: o teto e QUATRO Omni por chunk (skill psx-city) e o poste
## da rua ja gastou uma. Sobram tres, e elas vao em uma lampada magenta mais as
## duas brasas dos fumantes — que sao de 90 cm de alcance e existem justamente
## para a calcada ter dois pontos laranja parados no escuro.
##
## Por isso NAO ha uma segunda lampada aqui. A bandeira ja e emissao de
## material, que nao conta no teto.
static func props(props_saida: Array[Dictionary], base: Vector3, giro: float,
		semente: int) -> void:
	var b := Basis(Vector3.UP, giro)
	var eixo := base + b * Vector3(MEIA_PORTA, 0.0, 0.0)

	# A luz magenta que sai da bandeira e cai na calcada. E o sinal de longe:
	# numa rua de sodio amber, uma poca magenta no chao nao tem como ser outra
	# coisa.
	props_saida.append({
		"tipo": "lampada",
		# Baixa e a frente, e nao encostada na bandeira. Na primeira versao ela
		# ficava a 2,12 com energia 2,1 e pintava a parede inteira de rosa: a
		# vidraca magenta deixava de ter contraste contra o proprio reboco que
		# ela estava iluminando, e a peca que devia ser o sinal sumia dentro do
		# efeito dela mesma. Aqui a poca cai no DEGRAU e na calcada, que e onde
		# luz de dentro de casa cai de verdade, e a bandeira volta a ser a coisa
		# mais clara da fachada.
		# E a 1,15 m da parede, nao a 0,66. Perto demais, a Omni pegava a folha
		# da porta a sessenta centimetros e estourava ela em branco: a captura de
		# perto mostrava um retangulo claro onde devia haver madeira, e a
		# ombreira escura ao lado dele lia como uma barra preta no meio do vao.
		# Afastada, a mesma luz cai de raspao na folha e pousa no DEGRAU, que e
		# onde luz de dentro de casa pousa.
		"pos": eixo + b * Vector3(0.0, 0.95, 1.15),
		"padrao": Lampada.Padrao.ESTAVEL,
		"semente": semente + 311,
		"cor": Color("c060c8"),
		"energia": 1.2,
		"alcance": 4.2,
		"atenuacao": 1.8,
		"facho": false,
	})

	# O som atravessando a parede.
	#
	# Chega ANTES da imagem, e essa e a funcao. A 14 m, com a nevoa fechando, o
	# jogador ainda nao ve o telheiro nem a bandeira, e ja ouve a batida. O
	# filtro de atenuacao em 820 Hz e o que faz ela soar ABAFADA em vez de
	# tocada na calcada: o que atravessa alvenaria e o grave.
	props_saida.append({
		"tipo": "som_ambiente",
		"pos": eixo + b * Vector3(0.0, 1.30, -0.30),
		"som": &"funk_batida",
		"volume": -17.0,
		"alcance": 15.0,
		"corte_hz": 820.0,
		"pasta": "casa",
	})

	# Dois na calcada, fumando.
	#
	# Um encostado na parede e um de pe perto da grade. Os dois fumando: e o que
	# da nome a casa, e sao as duas unicas brasas da rua inteira. Nao ficam no
	# eixo da porta — quem chega tem de conseguir passar sem esbarrar em
	# ninguem, e gente plantada na frente de uma porta le como bloqueio.
	props_saida.append({
		"tipo": "convidado",
		"pos": eixo + b * Vector3(-0.92, 0.0, 0.30),
		"semente": semente + 407,
		"papel": Convidado.Papel.ENCOSTADO,
		"fuma": true,
		"chapado": true,
		"olhos": false,
		"foco": eixo + b * Vector3(2.4, 0.0, 3.0),
		"giro": giro + PI,
	})
	props_saida.append({
		"tipo": "convidado",
		"pos": eixo + b * Vector3(1.22, 0.0, 1.36),
		"semente": semente + 613,
		"papel": Convidado.Papel.LIVRE,
		"fuma": true,
		"chapado": true,
		"olhos": false,
		"foco": eixo + b * Vector3(-0.92, 0.0, 0.30),
		"giro": giro + PI * 0.7,
	})
