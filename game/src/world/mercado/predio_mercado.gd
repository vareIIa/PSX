## O predio da loja de conveniencia, do lado de fora: o que existe com o chunk.
##
## PLANO_MERCADO_AAA, F1. A loja deixou o teleporte. O que se ve da calcada — a
## vitrine, a porta de vidro, o portao de aco, o letreiro — e a FRENTE da mesma
## planta que o `InteriorNoMundo` monta atras dela quando o jogador chega perto
## (MercadoBuilder, `no_mundo`). Fachada e planta sao uma coisa so: o portao fica
## a 8,7 m da porta na calcada porque fica a 8,7 m dela no salao.
##
## O que mora aqui e nao na planta
## -------------------------------
##   casca        o anexo terreo dos fundos, a laje dele e o predio de cima
##   frente       pilares, vidro, montantes, portao e soleira — numa malha que
##                as duas luzes acendem (MalhaFronteira): vista da rua ela e
##                fachada, vista do caixa ela e a parede da loja
##   letreiro     marquise, testeira acesa, as tres cores
##   props        a porta automatica, o portao de enrolar, a luz que a vitrine
##                derrama na calcada e o no que monta a loja
##
## Tudo em coordenada de PLANTA e levado ao chunk pela transformada do lote
## (LoteNoMundo.planta_no_chunk): +Z entra na loja, a fachada fica em -PAREDE.
class_name PredioMercado
extends RefCounted

## A rampa de granito na frente da porta: largura ao longo da fachada e fundo.
## O piso da loja fica nove centimetros acima da calcada (KitFumaca.PISO_Y), e
## a entrada vence isso em rampa, e nao em degrau: a capsula do jogador, com 32
## cm de raio, bate na quina de um degrau de 9 cm a 49 graus — acima dos 45 em
## que o motor ainda chama de chao — e o degrau vira parede (medido: o teste
## que anda parou com a mao no vidro). Loja de rua tem rampa de acesso de
## qualquer jeito.
const DEGRAU := Vector2(2.6, 0.6)
## O maior salto de altura entre dois degraus da escada de colisao de uma rampa.
## A 3 cm o contato fica a 25 graus: chao, para o jogador e para o freguês.
const PASSO_RAMPA := 0.03

## Onde o predio de cima comeca, em Y de planta: 3,35 m acima do chao do chunk,
## a altura em que o bar tambem assenta o primeiro andar (KitBar.ALTURA_SALAO).
const PE_ANDAR := 3.35 - KitFumaca.PISO_Y
## Fundo do predio de cima, em Z de planta: a fileira (ChunkBuilder.PROF_PREDIO)
## medida da linha da face, que fica 6 cm atras da fachada.
const FUNDO_PREDIO := ChunkBuilder.PROF_PREDIO - (MercadoBuilder.PAREDE - ChunkBuilder.AVANCO_FACHADA)

## Marquise e testeira, em planta. A marquise protege a porta e a vitrine; a
## testeira pendura na borda dela, com o letreiro sobre a porta.
const MARQUISE_Y := Vector2(2.60, 2.70)
const MARQUISE_Z := -1.30
const TESTEIRA_Y := Vector2(2.46, 3.30)

## As tres cores da HIKARI. E o codigo visual da loja: na nevoa e a unica coisa
## legivel muito antes do letreiro.
const CORES_MARCA: Array[Color] = [Color("e27a26"), Color("3a8c54"), Color("c63a34")]


## Monta o predio. Devolve o numero de andares, como os outros predios da
## fileira. `porta` e a de `ChunkBuilder._porta_do_chunk`, com a transformada do
## lote em `planta`; `cx` e `cz` dizem de que chunk, para ler o passeio.
static func construir(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], rng: RandomNumberGenerator, face: Dictionary,
		quadra: Dictionary, porta: Dictionary, cx: int = 0, cz: int = 0) -> int:
	var em: Transform3D = porta["planta"]
	var g0 := em.basis.get_euler().y
	var passeio := _passeio(em, cx, cz)
	var direcao := int(face["direcao"])
	var normal := KitModular._normal(direcao)
	var giro_rua := atan2(normal.x, normal.z)

	# Dois andares no minimo: loja de conveniencia de bairro tem gente morando em
	# cima, e com um andar so o terreo seria o predio inteiro.
	var andares := maxi(2, int(quadra["andares"]) + rng.randi_range(-1, 1))
	var topo := float(andares) * KitModular.ALTURA_ANDAR - KitFumaca.PISO_Y
	var tinta: Color = Color(quadra["tinta"]).lerp(
		MalhaUrbana.TINTAS[rng.randi() % MalhaUrbana.TINTAS.size()], 0.22)
	var mat_fachada: StringName = quadra["fachada"]

	_casca(sup, colisao, em, g0, topo, tinta, rng)
	_fachada(sup, em, g0, andares, topo, tinta, mat_fachada, float(quadra["janela"]), rng)
	_letreiro(sup, em, g0)

	var frente: Dictionary = {}
	var frente_colisao: Array[Dictionary] = []
	_frente(frente, frente_colisao, tinta, mat_fachada, float(passeio["mais_baixo"]))
	_calcada(sup, colisao, em, g0, face, normal, passeio, frente, frente_colisao)
	props.append({
		"tipo": "malha_fronteira",
		"planta": em,
		"superficies": frente,
		"colisao": frente_colisao,
	})

	var ao_longo_de_z := absf(Vector3(face["eixo"]).z) > 0.5
	var lote := LoteNoMundo.lote(&"mercado")
	var meio_predio := em * Vector3(MercadoBuilder.LARGURA * 0.5, topo,
		(FUNDO_PREDIO - MercadoBuilder.PAREDE) * 0.5)
	var fundo := FUNDO_PREDIO + MercadoBuilder.PAREDE
	KitPredio.coroar(sup, quadra["coroamento"], meio_predio,
		Vector3(fundo, 0.0, lote.x) if ao_longo_de_z else Vector3(lote.x, 0.0, fundo),
		direcao, tinta, rng)

	var semente := int(porta["semente"])
	props.append({
		"tipo": "porta_automatica",
		"pos": em * Vector3(MercadoBuilder.CENTRO_PORTA, 0.0, MercadoBuilder.FOLHA_Z),
		"giro": giro_rua,
		"semente": semente,
	})
	props.append({
		"tipo": "portao_enrolar",
		# Na ladeira, a folha pousa na rampa que desce para a garagem.
		"pos": em * Vector3(MercadoBuilder.EIXO_PORTAO, base_do_portao(passeio),
			KitMercado.VIDRO_Z),
		"giro": giro_rua,
		"largura": KitMercado.LARGURA_PORTAO,
		"altura": KitMercado.ALTURA_PORTAO,
		"semente": semente,
	})
	_luzes(props, em, semente)
	props.append({
		"tipo": "interior_mundo",
		"planta": em,
		"interior": &"mercado",
		"semente": semente,
	})
	return andares


# --- casca ------------------------------------------------------------------

## O anexo terreo dos fundos, a laje dele, e o volume do predio de cima.
##
## O terreo inteiro e oco: o lado de dentro e da planta, e so aparece quando ela
## e montada. Por isso ele nao vira colisao — um bloco macico aqui seria tambem
## oclusor (ChunkManager), e apagaria a loja vista pela vitrine.
static func _casca(sup: Dictionary, colisao: Array[Dictionary], em: Transform3D,
		g0: float, topo: float, tinta: Color, rng: RandomNumberGenerator) -> void:
	var p := MercadoBuilder.PAREDE
	var larg := MercadoBuilder.LARGURA + p * 2.0
	var mx := MercadoBuilder.LARGURA * 0.5
	var fundo := MercadoBuilder.FUNDO
	var chao := -KitFumaca.PISO_Y
	var concreto := Color("a4a39b")

	# O anexo: da parede de tras do predio de cima ate o fundo do lote. So as tres
	# faces que dao para os quintais.
	var z0 := FUNDO_PREDIO
	var z1 := fundo + p
	KitModular.caixa_cor(sup, &"concreto_sujo",
		em * Vector3(mx, (chao + PE_ANDAR) * 0.5, (z0 + z1) * 0.5),
		Vector3(larg, PE_ANDAR - chao, z1 - z0), concreto, g0,
		PSXMesh.FACE_FRENTE | PSXMesh.FACE_DIR | PSXMesh.FACE_ESQ)
	# A laje, com platibanda nos tres lados de fora.
	KitModular.caixa_cor(sup, &"concreto",
		em * Vector3(mx, PE_ANDAR + 0.06, (z0 + z1) * 0.5),
		Vector3(larg, 0.12, z1 - z0), Color("8f8e88"), g0,
		PSXMesh.FACE_TOPO | PSXMesh.FACE_FRENTE | PSXMesh.FACE_DIR | PSXMesh.FACE_ESQ)
	var h := 0.45
	for lado: float in [-p + 0.075, MercadoBuilder.LARGURA + p - 0.075]:
		KitModular.caixa_cor(sup, &"concreto_sujo",
			em * Vector3(lado, PE_ANDAR + 0.12 + h * 0.5, (z0 + z1) * 0.5),
			Vector3(0.15, h, z1 - z0), concreto, g0)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		em * Vector3(mx, PE_ANDAR + 0.12 + h * 0.5, z1 - 0.075),
		Vector3(larg, h, 0.15), concreto, g0)

	# Na laje: a caixa d'agua azul e as duas condensadoras da camara fria, sobre
	# a parede das geladeiras. Sao elas que zumbem na calcada lateral (F5).
	var caixa_agua := em * Vector3(3.0, PE_ANDAR + 0.12, fundo - 2.2)
	for k in 2:
		KitModular.caixa_cor(sup, &"metal", caixa_agua + Vector3(0.0, 0.46, 0.0),
			Vector3(1.05, 0.92, 1.05), Color("3d6fa8"), g0 + float(k) * PI * 0.25)
	KitModular.caixa_cor(sup, &"metal", caixa_agua + Vector3(0.0, 0.97, 0.0),
		Vector3(0.9, 0.1, 0.9), Color("335f92"), g0 + PI * 0.125)
	for k in 2:
		var cond := em * Vector3(9.5 + float(k) * 3.2, PE_ANDAR + 0.12,
			MercadoBuilder.FUNDO_SALAO + 0.4)
		KitModular.caixa_cor(sup, &"metal", cond + Vector3(0.0, 0.38, 0.0),
			Vector3(1.1, 0.76, 0.5), Color("b8bbb6"), g0 + rng.randf_range(-0.04, 0.04))
		KitModular.caixa_cor(sup, &"metal", cond + Vector3(0.0, 0.765, 0.0),
			Vector3(0.62, 0.01, 0.38), Color("26282a"), g0, PSXMesh.FACE_TOPO)

	# O predio de cima: macico, como qualquer outro da fileira. Colisao e oclusor.
	var y0 := PE_ANDAR
	var centro := em * Vector3(mx, (y0 + topo) * 0.5, (FUNDO_PREDIO - p) * 0.5)
	var tamanho := Vector3(larg, topo - y0, FUNDO_PREDIO + p)
	KitModular.caixa_cor(sup, &"concreto_sujo", centro, tamanho, tinta, g0,
		PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE & ~PSXMesh.FACE_TRAS)
	KitModular.solido(colisao, centro, tamanho, g0)


# --- fachada ------------------------------------------------------------------

## A parede da rua acima do terreo, com as janelas dos andares de cima, e a
## parede de tras do predio, vista da laje.
static func _fachada(sup: Dictionary, em: Transform3D, g0: float, andares: int,
		topo: float, tinta: Color, material: StringName, prob_acesa: float,
		rng: RandomNumberGenerator) -> void:
	var p := MercadoBuilder.PAREDE
	var x0 := -p
	var x1 := MercadoBuilder.LARGURA + p
	var fora := g0 + PI
	var topo_portao := KitMercado.ALTURA_PORTAO + 0.32
	var topo_vidro := KitMercado.VIDRO_Y.y + 0.1
	# De cima do portao ao telhado, de ponta a ponta.
	KitModular.parede_livre(sup, material,
		em * Vector3((x0 + x1) * 0.5, (topo_portao + topo) * 0.5, -p),
		Vector2(x1 - x0, topo - topo_portao), fora, tinta)
	# A faixa entre o vidro e a altura do portao, sobre o salao. Quase toda atras
	# da testeira; aparece nas pontas.
	var sx0 := MercadoBuilder.DIVISA - 0.6
	KitModular.parede_livre(sup, material,
		em * Vector3((sx0 + x1) * 0.5, (topo_vidro + topo_portao) * 0.5, -p),
		Vector2(x1 - sx0, topo_portao - topo_vidro), fora, tinta)

	var larg := x1 - x0
	for andar in range(1, andares):
		var y := float(andar) * KitModular.ALTURA_ANDAR + 1.5 - KitFumaca.PISO_Y
		var nj := maxi(1, int(larg / 2.6))
		var passo := larg / float(nj)
		for j in nj:
			var x := x0 + passo * (float(j) + 0.5)
			var largura := 1.1 if (j % 2) == 0 else 0.85
			KitModular.parede_livre(sup,
				&"janela_acesa" if rng.randf() < prob_acesa else &"janela_apagada",
				em * Vector3(x, y, -p - 0.01), Vector2(largura, 1.3), fora)
			# Peitoril: a linha de sombra embaixo da janela que tira o vidro do
			# plano da parede.
			KitModular.caixa_cor(sup, &"concreto", em * Vector3(x, y - 0.69, -p - 0.04),
				Vector3(largura + 0.12, 0.06, 0.08), tinta.darkened(0.2), g0)
		# Janelinhas de tras, menores: banheiro, cozinha, area de servico.
		for j in 3:
			var x := MercadoBuilder.LARGURA * (0.2 + 0.3 * float(j))
			KitModular.parede_livre(sup,
				&"janela_acesa" if rng.randf() < prob_acesa * 0.6 else &"janela_apagada",
				em * Vector3(x, y + 0.2, FUNDO_PREDIO + 0.01), Vector2(0.7, 0.8), g0)


## Marquise, testeira acesa e letreiro.
##
## A testeira pendura na borda da marquise, 1,4 m a frente da vitrine: e ela que
## a nevoa deixa ver primeiro, uma faixa branca acesa com as tres cores embaixo.
## O letreiro fica sobre a porta, e nao no meio da fachada — quem le o nome ja
## esta olhando para onde entra.
static func _letreiro(sup: Dictionary, em: Transform3D, g0: float) -> void:
	var x0 := MercadoBuilder.DIVISA - 0.6
	var x1 := MercadoBuilder.LARGURA + MercadoBuilder.PAREDE
	var mx := (x0 + x1) * 0.5
	var fora := g0 + PI
	var p := MercadoBuilder.PAREDE
	var fundo_marquise := -p - MARQUISE_Z

	KitModular.caixa_cor(sup, &"metal",
		em * Vector3(mx, (MARQUISE_Y.x + MARQUISE_Y.y) * 0.5, (-p + MARQUISE_Z) * 0.5),
		Vector3(x1 - x0, MARQUISE_Y.y - MARQUISE_Y.x, fundo_marquise), Color("dfe0dc"), g0)
	# Luminarias embutidas por baixo: quadrados acesos que se veem do vidro e da
	# calcada. A luz de verdade e uma so (`_luzes`).
	for x: float in [6.6, 9.3, 12.7, 15.4]:
		KitModular.caixa_cor(sup, &"mercado_luz",
			em * Vector3(x, MARQUISE_Y.x - 0.004, (-p + MARQUISE_Z) * 0.5),
			Vector3(0.34, 0.01, 0.34), Color("f4f8f4"), g0)

	# Testeira: corpo escuro, faixa acesa, as tres cores embaixo e o letreiro.
	var zt := MARQUISE_Z - 0.1
	KitModular.caixa_cor(sup, &"metal",
		em * Vector3(mx, (TESTEIRA_Y.x + TESTEIRA_Y.y) * 0.5, zt),
		Vector3(x1 - x0 - 0.1, TESTEIRA_Y.y - TESTEIRA_Y.x, 0.2), KitMercado.ESTRUTURA_ESCURA, g0)
	var frente_z := zt - 0.101
	var faixa_y := Vector2(TESTEIRA_Y.x + 0.28, TESTEIRA_Y.y - 0.04)
	KitModular.placa(sup, &"mercado_luz",
		em * Vector3(mx, (faixa_y.x + faixa_y.y) * 0.5, frente_z),
		Vector2(x1 - x0 - 0.2, faixa_y.y - faixa_y.x), fora, Color("eef3f0"),
		KitMercado.SUBDIVISAO_PAINEL)
	# As tres cores acesas, como faixa de acrilico com luz atras: no `metal` o
	# laranja saia marrom, e a nevoa comia as tres antes do letreiro.
	for i in CORES_MARCA.size():
		KitModular.caixa_cor(sup, &"mercado_luz",
			em * Vector3(mx, TESTEIRA_Y.x + 0.05 + float(i) * 0.075, frente_z - 0.004),
			Vector3(x1 - x0 - 0.12, 0.07, 0.012), CORES_MARCA[i], g0)
	KitModular.placa(sup, &"mercado_letreiro",
		em * Vector3(MercadoBuilder.CENTRO_PORTA, (faixa_y.x + faixa_y.y) * 0.5,
			frente_z - 0.012),
		Vector2(2.05, 0.52), fora, Color.WHITE, KitMercado.SUBDIVISAO_PAINEL)
	# O mesmo letreiro, menor, na ponta da testeira que da para o portao: quem
	# vem pela calcada daquele lado le a loja antes de chegar na porta.
	for lado: float in [x0 + 0.06, x1 - 0.06]:
		KitModular.caixa_cor(sup, &"mercado_luz",
			em * Vector3(lado, (faixa_y.x + faixa_y.y) * 0.5, zt),
			Vector3(0.012, faixa_y.y - faixa_y.x, 0.16), Color("eef3f0"), g0)


## Onde fica o passeio em relacao ao piso da loja, em Y de planta.
##
## O lote assenta pela altura do chao na porta (ChunkBuilder._erguer_lote), e o
## patamar do relevo nivela o chunk da loja — quase sempre. Onde o no vizinho e
## de parque, ou de outro patamar, o chunk sai inclinado, e a calcada desce ao
## longo da fachada (medido: 61 cm em 17 m, com o portao abrindo para um passeio
## 20 cm ACIMA do piso da garagem). A frente se ajusta ao passeio que existe:
## cada boca tem a sua rampa, e o granito desce ate o ponto mais baixo.
##
## No plano, tudo e CALCADA_Y e nada muda.
static func _passeio(em: Transform3D, cx: int, cz: int) -> Dictionary:
	var base := Relevo.local(cx, cz, em * Vector3(MercadoBuilder.CENTRO_PORTA, 0.0,
		-MercadoBuilder.PAREDE))
	var no_ponto := func(x: float, z: float) -> float:
		return KitMercado.CALCADA_Y + Relevo.local(cx, cz, em * Vector3(x, 0.0, z)) - base
	var mais_baixo := KitMercado.CALCADA_Y
	var x := -MercadoBuilder.PAREDE
	while x <= MercadoBuilder.LARGURA + MercadoBuilder.PAREDE + 0.01:
		mais_baixo = minf(mais_baixo, float(no_ponto.call(x, -0.3)))
		x += 1.0
	return {
		"porta": float(no_ponto.call(MercadoBuilder.CENTRO_PORTA, -_da_face(DEGRAU.y))),
		"portao": float(no_ponto.call(MercadoBuilder.EIXO_PORTAO, -_da_face(0.7))),
		# Rente a fachada: e ai que o passeio encontra a soleira do portao.
		"portao_na_face": float(no_ponto.call(MercadoBuilder.EIXO_PORTAO,
			-_da_face(-ChunkBuilder.AVANCO_FACHADA))),
		"mais_baixo": mais_baixo - 0.04,
	}


## Onde a rampa do portao passa sob a folha, em Y de planta. A folha pousa ali.
static func base_do_portao(passeio: Dictionary) -> float:
	var alto := float(passeio["portao_na_face"])
	if alto <= 0.005:
		return 0.0
	var z0 := -_da_face(-ChunkBuilder.AVANCO_FACHADA)
	return lerpf(alto, 0.0, (KitMercado.VIDRO_Z - z0) / (RAMPA_DENTRO - z0))


## Ate onde, garagem adentro, desce a rampa do portao quando o passeio fica
## acima do piso.
const RAMPA_DENTRO := 1.3


## Materiais do chao da quadra: o que o relevo deforma para seguir o terreno.
const CHAO_DA_QUADRA: Array[StringName] = [&"terra", &"grama"]


## Afunda o chao da quadra que furaria o piso da loja.
##
## A loja e oca no terreo, e o piso dela assenta na altura da porta. O chao da
## quadra por baixo segue o relevo (Relevo.assentar): na ladeira, do lado de
## cima da rua, ele sobe acima do piso e aparece DENTRO da loja — terra e capim
## na frente do balcao (captura 05_caixa). O relevo ja rebaixa a colisao nessa
## pegada (ChunkBuilder.construir, `rebaixar`); isto faz o mesmo com o desenho.
##
## `piso` em coordenada do chunk. Chamado no fim da montagem, depois de todo
## assentamento: antes disso o relevo ainda mexeria nos vertices.
##
## Recorta, e nao so rebaixa. Rebaixar os vertices de dentro da pegada deixava
## de fora o triangulo que ATRAVESSA a parede: com um vertice alto do lado de
## fora do lote, ele subia em rampa por dentro da loja e aparecia no piso e na
## parede (sete lojas de 27 no morro, ate 1,38 m; tests/sonda_chao_mercado.gd).
## Agora todo triangulo que cruza a borda e partido na linha da pegada: a parte
## de dentro desce, a de fora fica onde o relevo a pos, e a emenda entre as duas
## cai debaixo da parede.
##
## A emenda e um degrau, e degrau sem parede e fresta para o limbo: com a loja
## vazia (casca a mais de PREAQUECER, ou a bancada_frestas, que nao monta
## interior), quem olha pela vitrine via o chao rebaixado e, na borda de tras,
## o vazio por baixo do relevo (pose 388, chunk (1,-1): 4000 px). Cada aresta
## da peca de dentro que corre na borda da pegada ganha uma parede de terra do
## relevo ate o rebaixo, virada para dentro do lote.
static func afundar_chao(sup: Dictionary, pegada: Rect2, piso: float) -> void:
	var teto := piso - 0.04
	for nome: StringName in CHAO_DA_QUADRA:
		if not sup.has(nome):
			continue
		var d: Dictionary = sup[nome]
		var vs: PackedVector3Array = d["v"]
		var idx: PackedInt32Array = d["i"]
		var novo_idx := PackedInt32Array()
		var mexeu := false
		for t in range(0, idx.size(), 3):
			var tri := [idx[t], idx[t + 1], idx[t + 2]]
			var caixa := Rect2(Vector2(vs[tri[0]].x, vs[tri[0]].z), Vector2.ZERO)
			var algum_alto := false
			for k: int in tri:
				caixa = caixa.expand(Vector2(vs[k].x, vs[k].z))
				algum_alto = algum_alto or vs[k].y > teto
			if not algum_alto or not caixa.intersects(pegada):
				novo_idx.append_array(PackedInt32Array(tri))
				continue
			mexeu = true
			for peca: Array in _recortar(d, tri, pegada):
				var dentro: bool = peca[0]
				var ids: PackedInt32Array = peca[1]
				if dentro:
					# Vertices proprios: os da emenda sao tambem da peca de fora, e
					# desce-los puxaria o chao do patio numa vala junto da parede.
					var altos := ids.duplicate()
					for k in ids.size():
						ids[k] = _vertice_entre(d, ids[k], ids[k], 0.0)
					vs = d["v"]
					for k in ids:
						if vs[k].y > teto:
							vs[k] = Vector3(vs[k].x, teto, vs[k].z)
					d["v"] = vs
					novo_idx.append_array(_parede_da_emenda(d, altos, ids, pegada))
					vs = d["v"]
				for k in range(1, ids.size() - 1):
					novo_idx.append_array(PackedInt32Array([ids[0], ids[k], ids[k + 1]]))
		# PackedArray e valor: sem devolver, a copia mudava sozinha.
		if mexeu:
			d["i"] = novo_idx


## A parede do degrau entre o relevo e o rebaixo, nas arestas da peca de dentro
## que correm na borda da pegada. `altos` sao os vertices da peca antes de
## descer (os da emenda, que a peca de fora tambem usa); `baixos`, as copias ja
## rebaixadas, na mesma ordem. Devolve os indices dos triangulos novos.
static func _parede_da_emenda(d: Dictionary, altos: PackedInt32Array,
		baixos: PackedInt32Array, r: Rect2) -> PackedInt32Array:
	const EPS := 0.001
	var saida := PackedInt32Array()
	var centro := r.get_center()
	var n := altos.size()
	for k in n:
		var vs: PackedVector3Array = d["v"]
		var a := altos[k]
		var b := altos[(k + 1) % n]
		var pa := vs[a]
		var pb := vs[b]
		var na_borda := (absf(pa.x - r.position.x) < EPS and absf(pb.x - r.position.x) < EPS) \
			or (absf(pa.x - r.end.x) < EPS and absf(pb.x - r.end.x) < EPS) \
			or (absf(pa.z - r.position.y) < EPS and absf(pb.z - r.position.y) < EPS) \
			or (absf(pa.z - r.end.y) < EPS and absf(pb.z - r.end.y) < EPS)
		if not na_borda:
			continue
		var ya := vs[baixos[k]].y
		var yb := vs[baixos[(k + 1) % n]].y
		if pa.y - ya < 0.005 and pb.y - yb < 0.005:
			continue
		# Normal horizontal para dentro do lote: a parede so e vista de la.
		var ao_longo := Vector3(pb.x - pa.x, 0.0, pb.z - pa.z)
		var dentro := Vector3(-ao_longo.z, 0.0, ao_longo.x).normalized()
		var meio := (pa + pb) * 0.5
		if dentro.dot(Vector3(centro.x - meio.x, 0.0, centro.y - meio.z)) < 0.0:
			dentro = -dentro
		var q := PackedInt32Array()
		for canto: int in [a, b, baixos[(k + 1) % n], baixos[k]]:
			q.append(_vertice_entre(d, canto, canto, 0.0))
		var ns: PackedVector3Array = d["n"]
		for id in q:
			ns[id] = dentro
		d["n"] = ns
		vs = d["v"]
		# O Godot desenha a face do lado OPOSTO ao produto vetorial.
		var cruz := (vs[q[1]] - vs[q[0]]).cross(vs[q[2]] - vs[q[0]])
		if cruz.dot(dentro) > 0.0:
			q = PackedInt32Array([q[1], q[0], q[3], q[2]])
		saida.append_array(PackedInt32Array([q[0], q[1], q[2], q[0], q[2], q[3]]))
	return saida


## Um vertice novo no meio de `a` e `b`, com todos os atributos interpolados.
static func _vertice_entre(d: Dictionary, a: int, b: int, t: float) -> int:
	var vs: PackedVector3Array = d["v"]
	var ns: PackedVector3Array = d["n"]
	var uv: PackedVector2Array = d["uv"]
	var cs: PackedColorArray = d["c"]
	vs.append(vs[a].lerp(vs[b], t))
	ns.append(ns[a].lerp(ns[b], t).normalized())
	uv.append(uv[a].lerp(uv[b], t))
	cs.append(cs[a].lerp(cs[b], t))
	d["v"] = vs
	d["n"] = ns
	d["uv"] = uv
	d["c"] = cs
	if d.has("uv2") and (d["uv2"] as PackedVector2Array).size() > 0:
		var u2: PackedVector2Array = d["uv2"]
		u2.append(u2[a].lerp(u2[b], t))
		d["uv2"] = u2
	return vs.size() - 1


## Parte um triangulo pela borda de `r` (plano XZ). Devolve pecas convexas,
## cada uma [dentro?, indices em ordem], com a mesma orientacao do original.
static func _recortar(d: Dictionary, tri: Array, r: Rect2) -> Array:
	var pecas: Array = []
	var poli := PackedInt32Array(tri)
	# Os quatro semiplanos: (eixo 0 = x, 2 = z; sinal; limite).
	var planos := [[0, 1.0, r.position.x], [0, -1.0, r.end.x],
		[2, 1.0, r.position.y], [2, -1.0, r.end.y]]
	for pl: Array in planos:
		var dentro := PackedInt32Array()
		var fora := PackedInt32Array()
		var n := poli.size()
		for k in n:
			var a := poli[k]
			var b := poli[(k + 1) % n]
			var va: Vector3 = (d["v"] as PackedVector3Array)[a]
			var vb: Vector3 = (d["v"] as PackedVector3Array)[b]
			var da := (va[pl[0]] - float(pl[2])) * float(pl[1])
			var db := (vb[pl[0]] - float(pl[2])) * float(pl[1])
			if da >= 0.0:
				dentro.append(a)
			else:
				fora.append(a)
			if (da >= 0.0) != (db >= 0.0):
				var m := _vertice_entre(d, a, b, da / (da - db))
				dentro.append(m)
				fora.append(m)
		if fora.size() >= 3:
			pecas.append([false, fora])
		poli = dentro
		if poli.size() < 3:
			return pecas
	pecas.append([true, poli])
	return pecas


## A distancia da face de dentro da parede ate `d` metros calcada afora.
static func _da_face(d: float) -> float:
	return MercadoBuilder.PAREDE + d


## A escada de colisao de uma rampa, em coordenada de planta: caixas de ate
## PASSO_RAMPA de altura entre uma e outra, de `z0` (altura `y0`) a `z1` (`y1`).
##
## Publica porque a malha de navegacao da loja precisa da MESMA rampa
## (MercadoBuilder._so_caminho): com um degrau desenhado para ela e uma escada
## para o corpo, o freguês achava caminho onde o jogador empacava.
static func degraus_da_rampa(x: float, largura: float, z0: float, y0: float,
		z1: float, y1: float) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var n := maxi(1, ceili(absf(y1 - y0) / PASSO_RAMPA))
	var dz := (z1 - z0) / float(n)
	var fundo := minf(y0, y1) - 0.12
	for k in n:
		var topo := lerpf(y0, y1, (float(k) + 0.5) / float(n))
		var za := z0 + dz * float(k)
		saida.append({
			"tamanho": Vector3(largura, topo - fundo, absf(dz)),
			"pos": Vector3(x, (topo + fundo) * 0.5, za + dz * 0.5),
		})
	return saida


## A rampa inteira: a laje inclinada que se ve e a escada que se pisa.
static func _rampa(sup: Dictionary, colisao: Array[Dictionary], em: Transform3D,
		g0: float, x: float, largura: float, z0: float, y0: float, z1: float,
		y1: float, material: StringName, cor: Color) -> void:
	var dz := z1 - z0
	var dy := y1 - y0
	var comprimento := sqrt(dz * dz + dy * dy)
	var grossura := 0.12
	# A laje inclinada, com a face de cima exatamente na linha da rampa.
	var inclinacao := Basis(Vector3.RIGHT, atan2(-dy, dz))
	var meio := Vector3(x, (y0 + y1) * 0.5, (z0 + z1) * 0.5) \
		+ inclinacao * Vector3(0.0, -grossura * 0.5, 0.0)
	KitModular.caixa_livre(sup, material, em * meio,
		Vector3(largura, grossura, comprimento + 0.01),
		Basis(Vector3.UP, g0) * inclinacao, cor)
	for c: Dictionary in degraus_da_rampa(x, largura, z0, y0, z1, y1):
		KitModular.solido(colisao, em * Vector3(c["pos"]), c["tamanho"], g0)


## A rampa da porta e a do portao.
##
## A do portao depende da ladeira. Com o passeio abaixo do piso (ou no plano),
## ela sobe do lado de fora, como a da porta. Com o passeio ACIMA do piso, o
## terreno e que chega mais alto na fachada, e uma rampa de fora teria de
## afundar nele: a colisao do relevo so e rebaixada dentro do lote, e ficava um
## degrau de 24 cm na soleira (medido — o teste parou ali). Entao ela desce por
## DENTRO da garagem, da altura do passeio na fachada ate o piso, e a folha do
## portao pousa nela. Nesse caso ela e vista dos dois lados, e mora na malha de
## fronteira, com as duas luzes.
static func _calcada(sup: Dictionary, colisao: Array[Dictionary], em: Transform3D,
		g0: float, face: Dictionary, normal: Vector3, passeio: Dictionary,
		frente: Dictionary, frente_colisao: Array[Dictionary]) -> void:
	var p := MercadoBuilder.PAREDE
	# A rampa de granito da porta: do passeio ao piso da loja, em seis palmos.
	# Larga, e a porta ganha um lugar para se esperar.
	_rampa(sup, colisao, em, g0, MercadoBuilder.CENTRO_PORTA, DEGRAU.x,
		-p - DEGRAU.y, float(passeio["porta"]), -p, 0.0, &"metal", Color("7a7c78"))

	var alto := float(passeio["portao_na_face"])
	if alto > 0.005:
		var z0 := -_da_face(-ChunkBuilder.AVANCO_FACHADA)
		_rampa(frente, frente_colisao, Transform3D.IDENTITY, 0.0,
			MercadoBuilder.EIXO_PORTAO, KitMercado.LARGURA_PORTAO - 0.02, z0, alto,
			RAMPA_DENTRO, 0.0, &"concreto", Color("8a8a84"))
	else:
		_rampa(sup, colisao, em, g0, MercadoBuilder.EIXO_PORTAO,
			KitMercado.LARGURA_PORTAO + 0.3, -p - 0.7, float(passeio["portao"]), -p, 0.0,
			&"concreto", Color("8a8a84"))
	# A guia rebaixada no meio-fio, em frente ao portao: e o que diz, da rua, que
	# ali entra carro.
	var na_face := em * Vector3(MercadoBuilder.EIXO_PORTAO, 0.0,
		-(p - ChunkBuilder.AVANCO_FACHADA))
	na_face.y = 0.0
	DetalheCalcada.guia_rebaixada(sup, na_face + normal * float(face.get("meio_fio", 2.2)),
		normal, KitMercado.LARGURA_PORTAO + 0.6)


# --- a frente -----------------------------------------------------------------

## O que e rua e loja ao mesmo tempo: pilares, vidro, montantes e o batente do
## portao. Em coordenada de planta, montado pela MalhaFronteira com as duas
## camadas de luz — o poste acende a face de fora, a calha acende a de dentro.
##
## Os pilares nao tem a face de dentro: ela e do reboco da planta
## (MercadoBuilder._frente), acesa e molhada como o resto da parede. Duas faces
## no mesmo plano brigariam pelo pixel.
static func _frente(sup: Dictionary, colisao: Array[Dictionary], tinta: Color,
		material: StringName, mais_baixo: float) -> void:
	var p := MercadoBuilder.PAREDE
	# O pe dos pilares e do peitoril: o ponto mais baixo do passeio da fachada.
	var cy := mais_baixo
	KitMercado.vitrine_loja(sup, colisao, Transform3D.IDENTITY,
		MercadoBuilder.VITRINE_X0, MercadoBuilder.VITRINE_X1,
		MercadoBuilder.PORTA_X0, MercadoBuilder.PORTA_X1, &"vitrine_loja",
		Color.WHITE, PI, true, cy)

	var vao := Vector2(MercadoBuilder.EIXO_PORTAO - KitMercado.LARGURA_PORTAO * 0.5,
		MercadoBuilder.EIXO_PORTAO + KitMercado.LARGURA_PORTAO * 0.5)
	var topo_portao := KitMercado.ALTURA_PORTAO + 0.32
	var topo_vidro := KitMercado.VIDRO_Y.y + 0.1
	var pilares: Array[Vector3] = [
		Vector3(-p, vao.x, topo_portao),
		Vector3(vao.y, MercadoBuilder.VITRINE_X0, topo_vidro),
		Vector3(MercadoBuilder.VITRINE_X1, MercadoBuilder.LARGURA + p, topo_vidro),
	]
	for pl: Vector3 in pilares:
		var centro := Vector3((pl.x + pl.y) * 0.5, (cy + pl.z) * 0.5, -p * 0.5)
		var tam := Vector3(pl.y - pl.x, pl.z - cy, p)
		KitModular.caixa_cor(sup, material, centro, tam, tinta, 0.0,
			PSXMesh.FACE_TODAS & ~PSXMesh.FACE_FRENTE & ~PSXMesh.FACE_BASE)
		colisao.append({"tamanho": tam, "pos": centro})
	# Acima do pilar do meio quem fecha e a faixa da fachada (`_fachada`), no
	# mesmo plano: um bloco aqui brigaria com ela pelo pixel.

	# A porta dos moradores de cima, no pilar do meio: aco pintado e o
	# interfone. Nao abre — e o que diz que o predio e de alguem alem da loja.
	var porta_x := (vao.y + MercadoBuilder.VITRINE_X0) * 0.5
	KitModular.placa(sup, &"porta", Vector3(porta_x, KitMercado.CALCADA_Y + 1.05, -p - 0.005),
		Vector2(0.78, 2.1), PI, Color("5d6a66"))
	KitModular.caixa_cor(sup, &"metal", Vector3(porta_x + 0.34, KitMercado.CALCADA_Y + 1.35, -p - 0.02),
		Vector3(0.1, 0.16, 0.03), Color("b0b2ac"), 0.0)

	# O batente do portao, sem colisao no vao: quem fecha e a folha que sobe.
	KitMercado.portao_garagem(sup, colisao,
		Vector3(MercadoBuilder.EIXO_PORTAO, 0.0, KitMercado.VIDRO_Z),
		KitMercado.LARGURA_PORTAO, 0.0, false, false)


# --- luz ----------------------------------------------------------------------

## A luz que a loja derrama na calcada, e a do portao.
##
## Da rua, e nao da loja: acende calcada, fachada e quem passa, e nao entra na
## camada de dentro (InteriorNoMundo.CAMADA). A de dentro e das calhas.
static func _luzes(props: Array[Dictionary], em: Transform3D, semente: int) -> void:
	var p := MercadoBuilder.PAREDE
	# Sob a marquise, em frente a porta. Facho curto, do tamanho da marquise: o
	# cone de poste atravessaria o passeio.
	props.append({
		"tipo": "lampada",
		"pos": em * Vector3(MercadoBuilder.CENTRO_PORTA, MARQUISE_Y.x - 0.12,
			(-p + MARQUISE_Z) * 0.5),
		"padrao": Lampada.Padrao.ESTAVEL,
		"semente": 61000 + semente % 9973,
		"cor": Color("eaf4ff"), "energia": 3.0, "alcance": 8.5, "facho": true,
		"raio_topo": 0.18, "raio_base": 1.5, "altura_facho": 2.5,
	})
	# Sodio sobre o portao. A diferenca de temperatura entre as duas luzes e o
	# que separa a entrada da loja da entrada de carga na mesma calcada.
	props.append({
		"tipo": "lampada",
		"pos": em * Vector3(MercadoBuilder.EIXO_PORTAO, KitMercado.ALTURA_PORTAO + 0.5,
			-p - 0.45),
		"padrao": Lampada.Padrao.SODIO_FALHANDO,
		"semente": 62000 + semente % 9973,
		"cor": Color("ffc887"), "energia": 2.1, "alcance": 6.5, "facho": false,
	})
