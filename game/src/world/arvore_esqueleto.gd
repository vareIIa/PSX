## A arvore de copa por ESQUELETO (PLANO_FLORA_AAA, etapa 2).
##
## A de antes (Vegetacao.arvore) era um poste de duas caixas, dois a quatro
## galhos de caixa e uma bola de cartoes em espiral. De longe passava; de perto
## era um pirulito: tronco quadrado, a copa sem nada dentro, e os cartoes
## boiando em volta de um centro que nenhum galho alcancava.
##
## Aqui a arvore cresce como arvore:
##
##   tronco    tubo de sete lados que afina, com a sapopema (o pe alargado em
##             lobos, que a mangueira velha e a sibipiruna tem) enterrada um
##             palmo no chao, e um pouco torto
##   pernadas  os galhos-mestres que abrem do alto do fuste, cada um uma curva
##             que sobe e sai, no angulo da especie (a sibipiruna abre em
##             guarda-chuva, o ipe em vaso, a jaqueira sobe com um lider)
##   ramos     dois ou tres por pernada, indo ate a borda da copa
##   cachos    os cartoes de folha nascem na PONTA dos ramos, virados para fora,
##             e so o que falta para fechar a silhueta vem da espiral de antes
##
## Por que o mesmo sorteio
## -----------------------
## Quem planta passa o rng do chunk, e tudo o que vem depois da arvore (a
## maquina de venda, o banco, o poste) sai do mesmo rng. Um sorteio a mais ou a
## menos aqui muda a rua inteira (memoria "rng do chunk arrasta o resto": a
## maquina de venda ja tapou a porta do Seu Ze assim). Por isso esta arvore GASTA
## do rng de quem planta exatamente as mesmas chamadas, na mesma ordem, que a de
## antes gastava — e o porte, o giro e a inclinacao saem delas, iguais —, e
## desenha o resto com um rng proprio semeado pelo estado dele, que so se le.
##
## O vento segue a mesma regra da copa (alfa da cor de vertice = rigidez): a
## ponta de cada ramo tem a rigidez do cartao que ela segura, e o cacho anda com
## o galho em vez de flutuar ao lado dele.
class_name ArvoreEsqueleto
extends RefCounted

const CASCA := KitEstrada.M_CASCA
## O ramo fino vai no balde `@perto` do ChunkManager (cortado a 40 m): de longe
## ele esta dentro da copa, e custava 300 triangulos por arvore que ninguem via.
## So na cidade: o EstradaBuilder monta a malha dele sem conhecer o `@perto`.
const CASCA_PERTO := &"casca@perto"

const LADOS_TRONCO := 7
const LADOS_PERNADA := 5
const LADOS_RAMO := 4

## Arquitetura por especie.
##   pernadas   quantos galhos-mestres
##   abertura   angulo deles com a vertical (rad), minimo e maximo
##   ramos      ramos por pernada
##   cacho      cartoes por ponta de ramo
##   lider      o tronco continua copa acima (fracao da altura da copa)
##   sapopema   quanto o pe alarga
##   torto      quanto o tronco e as pernadas entortam
##   fechada    1 = copa fechada (o oiti podado da calcada, a mangueira): a
##              espiral cobre a copa toda por cima dos cachos; 0 = copa aberta
##              (ipe, sibipiruna), so cacho, e o ceu aparece entre eles
const FORMAS := {
	&"mangueira": {"pernadas": Vector2i(4, 6), "abertura": Vector2(0.6, 1.05),
		"ramos": Vector2i(2, 3), "cacho": 4, "lider": 0.0, "sapopema": 0.45, "torto": 0.22, "fechada": 1.0},
	&"oiti": {"pernadas": Vector2i(4, 6), "abertura": Vector2(0.55, 1.0),
		"ramos": Vector2i(2, 3), "cacho": 4, "lider": 0.0, "sapopema": 0.25, "torto": 0.18, "fechada": 1.0},
	&"abacateiro": {"pernadas": Vector2i(3, 5), "abertura": Vector2(0.35, 0.75),
		"ramos": Vector2i(2, 3), "cacho": 4, "lider": 0.45, "sapopema": 0.2, "torto": 0.15, "fechada": 0.6},
	&"jaqueira": {"pernadas": Vector2i(4, 6), "abertura": Vector2(0.7, 1.15),
		"ramos": Vector2i(2, 3), "cacho": 4, "lider": 0.6, "sapopema": 0.5, "torto": 0.1, "fechada": 1.0},
	&"ipe_amarelo": {"pernadas": Vector2i(3, 4), "abertura": Vector2(0.35, 0.7),
		"ramos": Vector2i(2, 3), "cacho": 3, "lider": 0.0, "sapopema": 0.15, "torto": 0.3, "fechada": 0.0},
	&"ipe_rosa": {"pernadas": Vector2i(3, 4), "abertura": Vector2(0.35, 0.7),
		"ramos": Vector2i(2, 3), "cacho": 3, "lider": 0.0, "sapopema": 0.15, "torto": 0.3, "fechada": 0.0},
	&"embauba": {"pernadas": Vector2i(3, 5), "abertura": Vector2(1.15, 1.4),
		"ramos": Vector2i(1, 2), "cacho": 3, "lider": 0.5, "sapopema": 0.1, "torto": 0.12, "fechada": 0.0},
	&"quaresmeira": {"pernadas": Vector2i(4, 6), "abertura": Vector2(0.5, 0.95),
		"ramos": Vector2i(2, 3), "cacho": 3, "lider": 0.0, "sapopema": 0.1, "torto": 0.25, "fechada": 0.4},
	&"angico": {"pernadas": Vector2i(3, 5), "abertura": Vector2(0.6, 1.1),
		"ramos": Vector2i(2, 3), "cacho": 3, "lider": 0.0, "sapopema": 0.35, "torto": 0.25, "fechada": 0.6},
	&"sibipiruna": {"pernadas": Vector2i(3, 5), "abertura": Vector2(0.75, 1.2),
		"ramos": Vector2i(3, 4), "cacho": 3, "lider": 0.0, "sapopema": 0.4, "torto": 0.2, "fechada": 0.25},
	# Rodada 2: a variedade da calcada e do quintal (ESPECIES_CIDADE).
	&"reseda": {"pernadas": Vector2i(4, 6), "abertura": Vector2(0.3, 0.6),
		"ramos": Vector2i(2, 3), "cacho": 3, "lider": 0.0, "sapopema": 0.05, "torto": 0.35, "fechada": 0.2},
	&"pata_de_vaca": {"pernadas": Vector2i(3, 5), "abertura": Vector2(0.55, 1.0),
		"ramos": Vector2i(2, 3), "cacho": 3, "lider": 0.0, "sapopema": 0.1, "torto": 0.3, "fechada": 0.35},
	&"ficus": {"pernadas": Vector2i(5, 7), "abertura": Vector2(0.5, 0.95),
		"ramos": Vector2i(2, 3), "cacho": 4, "lider": 0.0, "sapopema": 0.35, "torto": 0.12, "fechada": 1.0},
	&"jabuticabeira": {"pernadas": Vector2i(5, 7), "abertura": Vector2(0.45, 0.85),
		"ramos": Vector2i(2, 3), "cacho": 4, "lider": 0.0, "sapopema": 0.0, "torto": 0.25, "fechada": 1.0},
	&"goiabeira": {"pernadas": Vector2i(3, 5), "abertura": Vector2(0.6, 1.1),
		"ramos": Vector2i(2, 3), "cacho": 3, "lider": 0.0, "sapopema": 0.05, "torto": 0.45, "fechada": 0.6},
}

## Especies da mata de beira de estrada (etapa 5), no mesmo formato de
## `Vegetacao.ESPECIES`, mais `tinta` (multiplica a celula) e `casca`.
##   embauba      a pioneira da beira de estrada de Minas: tronco claro e fino,
##                poucos galhos em candelabro e a folha palmada prateada por baixo
##   quaresmeira  o roxo da serra em marco: a celula do ipe rosa puxada para o
##                violeta pela tinta
##   angico       a arvore de dossel da mata: fuste longo, copa miuda e larga
const ESPECIES_MATA := {
	&"embauba": {"alto": Vector2(8.0, 14.0), "fuste": 0.62, "copa": Vector2(0.34, 0.16),
		"cartoes": 12, "celula": Vegetacao.C_CLARO, "cartao": 1.15, "tronco": 0.26,
		"tinta": Color(0.8, 0.9, 0.84), "casca": Color("b4ada0")},
	&"quaresmeira": {"alto": Vector2(5.0, 8.0), "fuste": 0.35, "copa": Vector2(0.42, 0.32),
		"cartoes": 18, "celula": Vegetacao.C_IPE_ROSA, "cartao": 0.85, "tronco": 0.24,
		"tinta": Color(0.7, 0.55, 1.0), "casca": Color("7a6e62")},
	&"angico": {"alto": Vector2(10.0, 16.0), "fuste": 0.55, "copa": Vector2(0.34, 0.2),
		"cartoes": 22, "celula": Vegetacao.C_MIUDO, "cartao": 1.0, "tronco": 0.42,
		"tinta": Color(0.92, 0.96, 0.9), "casca": Color("5e5244")},
}

## Especies da CIDADE que a Vegetacao nao tinha (rodada 2). A rua de casas tinha
## oiti em nove de cada dez arvores (ChunkBuilder._especie_de_rua); rua de Minas
## mistura o oiti com o resedá podado, a pata-de-vaca, o ficus e a quaresmeira. E
## o quintal ganha as duas frutas que faltavam: a jabuticabeira (fuste curto, copa
## miuda e fechada, casca clara que descasca) e a goiabeira (torta, casca lisa
## avermelhada). `mat` = o material das celulas (o atlas `plantas`).
##   reseda        4-6 m, vaso aberto, flor lilas de dezembro a marco
##   pata_de_vaca  a Bauhinia de calcada: flor rosa de junho a setembro
##   ficus         o de calcada podado em bola, folha miuda escura
const ESPECIES_CIDADE := {
	&"reseda": {"alto": Vector2(4.0, 6.5), "fuste": 0.3, "copa": Vector2(0.36, 0.3),
		"cartoes": 16, "celula": Vegetacao.C_IPE_ROSA, "cartao": 0.8, "tronco": 0.2,
		"tinta": Color(0.86, 0.72, 1.0), "casca": Color("a89a86")},
	&"pata_de_vaca": {"alto": Vector2(5.0, 8.0), "fuste": 0.35, "copa": Vector2(0.4, 0.3),
		"cartoes": 18, "celula": Vegetacao.C_IPE_ROSA, "cartao": 0.85, "tronco": 0.26,
		"tinta": Color(1.0, 0.9, 0.96), "casca": Color("8a8070")},
	&"ficus": {"alto": Vector2(5.0, 7.5), "fuste": 0.3, "copa": Vector2(0.44, 0.36),
		"cartoes": 22, "celula": Vegetacao.C_MIUDO, "cartao": 0.95, "tronco": 0.34,
		"tinta": Color(0.78, 0.88, 0.76), "casca": Color("8c8478")},
	&"jabuticabeira": {"alto": Vector2(4.0, 7.0), "fuste": 0.14, "copa": Vector2(0.5, 0.42),
		"cartoes": 26, "celula": Vector2i(1, 2), "cartao": 0.9, "tronco": 0.3,
		"casca": Color("c2ad92"), "mat": &"plantas"},
	&"goiabeira": {"alto": Vector2(4.0, 6.5), "fuste": 0.3, "copa": Vector2(0.46, 0.34),
		"cartoes": 20, "celula": Vector2i(2, 2), "cartao": 0.9, "tronco": 0.24,
		"casca": Color("a47a5c"), "mat": &"plantas"},
}

## A mistura da calcada onde o ChunkBuilder pede "oiti", e a do quintal onde ele
## pede mangueira, abacateiro ou jaqueira. Sai do rng proprio da arvore: o de
## quem planta e a arvore de antes nao ficam sabendo.
const VARIA_OITI: Array[StringName] = [&"oiti", &"oiti", &"oiti", &"oiti", &"oiti",
	&"reseda", &"reseda", &"pata_de_vaca", &"pata_de_vaca", &"ficus", &"quaresmeira"]
const VARIA_QUINTAL: Array[StringName] = [&"jabuticabeira", &"jabuticabeira", &"goiabeira"]

## A mata de beira: mais angico (o dossel), embauba na borda, quaresmeira aqui
## e ali, mangueira e sibipiruna que escaparam de quintal.
const MATA: Array[StringName] = [&"angico", &"angico", &"angico", &"embauba", &"embauba",
	&"quaresmeira", &"sibipiruna", &"mangueira"]

## `--arvore-caixa` volta a arvore de antes (A/B na bancada e na cidade).
static var ativo := not OS.get_cmdline_user_args().has("--arvore-caixa")
## `--sem-variedade` planta so a especie pedida (A/B da rodada 2).
static var variedade := not OS.get_cmdline_user_args().has("--sem-variedade")


static func arvore(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		especie: StringName, porte: float, rng: RandomNumberGenerator,
		poda: PackedVector3Array = PackedVector3Array()) -> float:
	# O tamanho vem da especie; a CONTAGEM de sorteios, da arvore de antes, que
	# so conhecia as da Vegetacao (e caia no oiti para as outras).
	var e: Dictionary = _especie(especie)
	var e_velho: Dictionary = Vegetacao.ESPECIES.get(especie, Vegetacao.ESPECIES[&"oiti"])
	# O rng proprio, semeado pelo estado de quem planta ANTES de qualquer gasto
	# (ler o estado nao sorteia) e pelo lugar.
	var r := RandomNumberGenerator.new()
	r.seed = hash([rng.state, roundi(base.x * 10.0), roundi(base.z * 10.0)])

	# --- os sorteios da arvore de antes, na ordem dela ---------------------
	var alto_v: Vector2 = e["alto"]
	var altura := lerpf(alto_v.x, alto_v.y, clampf(porte, 0.0, 1.0))
	var copa_v: Vector2 = e["copa"]
	var raio := Vector3(copa_v.x, copa_v.y, copa_v.x) * altura \
		* Vector3(rng.randf_range(0.88, 1.12), rng.randf_range(0.9, 1.1), rng.randf_range(0.88, 1.12))
	var giro := rng.randf_range(0.0, TAU)
	var inclina := rng.randf_range(-0.06, 0.06)
	var n_antigos := rng.randi_range(2, 4)
	for k in n_antigos:
		rng.randf_range(-0.4, 0.4)
		rng.randf_range(0.85, 1.0)
		rng.randf_range(-0.2, 0.3)
	var tinta := Color.WHITE.lerp(Color(0.86, 0.94, 0.8), rng.randf_range(0.0, 0.6))
	for k in 3:
		rng.randf_range(0.0, 0.5)
	for k in int(float(e_velho["cartoes"]) * 1.5):
		rng.randf_range(-0.3, 0.3)
		rng.randf_range(0.62, 0.82)
		rng.randf()
		rng.randf_range(0.85, 1.2)
		rng.randf()
	# ----------------------------------------------------------------------
	# A variedade (rodada 2). O raio devolvido e a colisao continuam os da especie
	# pedida: quem planta espaca por eles, e o pedestre contorna esta colisao.
	var outra := _variedade(especie, r)
	if outra != especie:
		var e2: Dictionary = _especie(outra)
		var alto2: Vector2 = e2["alto"]
		var altura2 := lerpf(alto2.x, alto2.y, clampf(porte, 0.0, 1.0))
		var copa2: Vector2 = e2["copa"]
		var raio2 := Vector3(copa2.x, copa2.y, copa2.x) * altura2 * (raio / (Vector3(copa_v.x,
			copa_v.y, copa_v.x) * altura))
		_construir(sup, colisao, base, outra, porte, r, altura2, raio2, giro, inclina, tinta,
			0.03, false, true, poda)
		var grossura := float(e["tronco"]) * lerpf(0.7, 1.15, porte)
		var fuste := altura * float(e["fuste"])
		colisao.append({"tamanho": Vector3(grossura, fuste, grossura),
			"pos": base + Vector3(0.0, fuste * 0.5, 0.0)})
		return maxf(raio.x, raio.z)
	_construir(sup, colisao, base, especie, porte, r, altura, raio, giro, inclina, tinta,
		0.04 if String(especie).begins_with("ipe") else 0.03, true, true, poda)
	return maxf(raio.x, raio.z)


## A especie que de fato cresce onde pediram `especie` (ver VARIA_OITI). So o
## oiti e as frutas grandes de quintal variam; o resto e o que pediram.
static func _variedade(especie: StringName, r: RandomNumberGenerator) -> StringName:
	if not variedade:
		return especie
	match especie:
		&"oiti":
			return VARIA_OITI[r.randi() % VARIA_OITI.size()]
		&"mangueira", &"abacateiro", &"jaqueira":
			if r.randf() < 0.3:
				return VARIA_QUINTAL[r.randi() % VARIA_QUINTAL.size()]
	return especie


## A arvore do PARQUE e da praca (KitParque.arvore), que era de caixa. Mesma
## regra do sorteio: gasta do rng de quem planta o que a de caixa gastava, e
## devolve o MESMO raio de copa e a mesma colisao — o parque espaca uma arvore
## da outra por esse raio, e o caminho do pedestre contorna essa colisao.
## A especie sai do rng proprio, da mistura de praca de cidade mineira.
static func de_parque(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		porte: float, rng: RandomNumberGenerator, seca: bool) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = hash([rng.state, roundi(base.x * 10.0), roundi(base.z * 10.0), 7])
	# --- os sorteios da arvore de caixa, na ordem dela ---------------------
	var altura_velha := lerpf(4.6, 8.4, porte)
	var raio_copa := lerpf(1.5, 2.6, porte)
	var tronco_velho := lerpf(0.28, 0.44, porte)
	rng.randf_range(0.2, 0.8)
	rng.randf_range(0.0, TAU)
	rng.randf_range(-0.22, 0.22)
	rng.randf_range(-0.22, 0.22)
	rng.randi()
	rng.randf_range(0.0, TAU)
	var n := rng.randi_range(9, 12)
	for i in n:
		for k in 7:
			rng.randf()
	if porte > 0.55:
		rng.randf_range(0.0, TAU)
	# ----------------------------------------------------------------------
	var especie: StringName = PRACA[r.randi() % PRACA.size()]
	var e: Dictionary = Vegetacao.ESPECIES[especie]
	# O porte da especie que da a altura da arvore de antes (a praca foi
	# desenhada em volta dela).
	var alto_v: Vector2 = e["alto"]
	var porte_v := clampf(inverse_lerp(alto_v.x, alto_v.y, altura_velha * r.randf_range(1.0, 1.25)), 0.0, 1.0)
	var altura := lerpf(alto_v.x, alto_v.y, porte_v)
	var copa_v: Vector2 = e["copa"]
	var raio := Vector3(copa_v.x, copa_v.y, copa_v.x) * altura 		* Vector3(r.randf_range(0.88, 1.12), r.randf_range(0.9, 1.1), r.randf_range(0.88, 1.12))
	var tinta := Color.WHITE.lerp(Color(0.86, 0.94, 0.8), r.randf_range(0.0, 0.6))
	_construir(sup, colisao, base, especie, porte_v, r, altura, raio, r.randf_range(0.0, TAU),
		r.randf_range(-0.06, 0.06), tinta, 0.35 if seca else (0.04 if String(especie).begins_with("ipe") else 0.03),
		false)
	colisao.append({
		"tamanho": Vector3(tronco_velho * 2.0, altura_velha * 0.4, tronco_velho * 2.0),
		"pos": base + Vector3(0.0, altura_velha * 0.2, 0.0),
	})
	_chao_da_copa(sup, base, especie, maxf(raio.x, raio.z), r)
	return raio_copa


## O chao embaixo da copa, na praca e no parque: o tapete de trombeta caida do
## ipe (amarelo ou rosa, a imagem de agosto em Minas) e a folha seca da
## mangueira e da jaqueira. Cartoes deitados no material `flor` (sem vento:
## alfa 0), em celulas que so o atlas HD tem — no PS1 elas sao vazias.
##
## So aqui, e nao na arvore da calcada: la o cartao passaria do meio-fio e
## boiaria 16 cm sobre o asfalto.
static func _chao_da_copa(sup: Dictionary, base: Vector3, especie: StringName, raio: float,
		r: RandomNumberGenerator) -> void:
	var celula := Vector2i(4, 1)
	var n := 0
	match especie:
		&"ipe_amarelo":
			celula = Vector2i(2, 1)
			n = 13
		&"ipe_rosa":
			celula = Vector2i(3, 1)
			n = 13
		_:
			n = 3 if r.randf() < 0.5 else 0
	# Sem florada, sem tapete de flor; na seca, mais folha no chao.
	if celula != Vector2i(4, 1) and not Estacao.florindo(especie):
		celula = Vector2i(4, 1)
		n = 3
	if celula == Vector2i(4, 1):
		n += roundi(2.0 * Estacao.seca())
	for k in n:
		var a := r.randf() * TAU
		# Muitos cartoes pequenos: poucos e grandes liam como tapete oval de
		# borda certa no gramado.
		var d := raio * 0.9 * sqrt(r.randf())
		var tam := r.randf_range(0.8, 1.6)
		var onde := base + Vector3(cos(a) * d, 0.012 + 0.002 * float(k), sin(a) * d)
		AtlasKit.deitado(sup, &"flor", onde, Vector2(tam, tam), celula, r.randf() * TAU,
			Color(0.82, 0.82, 0.82, 0.0))


static func _de_flor(especie: StringName) -> bool:
	return String(especie).begins_with("ipe") or especie in [&"quaresmeira", &"reseda",
		&"pata_de_vaca"]


static func _especie(especie: StringName) -> Dictionary:
	if ESPECIES_MATA.has(especie):
		return ESPECIES_MATA[especie]
	if ESPECIES_CIDADE.has(especie):
		return ESPECIES_CIDADE[especie]
	return Vegetacao.ESPECIES.get(especie, Vegetacao.ESPECIES[&"oiti"])


## A arvore de folha larga da mata da estrada (KitEstrada.arvore), que era de
## caixa. Mesmo sorteio gasto, mesmo raio devolvido (a estrada espaca a mata por
## ele e empurra para fora do corredor quem invadiria a pista).
static func de_mata(sup: Dictionary, base: Vector3, porte: float,
		rng: RandomNumberGenerator, seca: bool) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = hash([rng.state, roundi(base.x * 10.0), roundi(base.z * 10.0), 17])
	# --- os sorteios da arvore de caixa da estrada, na ordem dela ----------
	var raio_velho := lerpf(1.8, 3.0, porte)
	var altura_velha := lerpf(8.5, 15.0, porte)
	rng.randf_range(0.0, TAU)
	rng.randf_range(-0.05, 0.05)
	rng.randi()
	rng.randf_range(0.0, TAU)
	var n := rng.randi_range(4, 6)
	for i in n:
		for k in 7:
			rng.randf()
	# ----------------------------------------------------------------------
	var especie: StringName = MATA[r.randi() % MATA.size()]
	var e := _especie(especie)
	var alto_v: Vector2 = e["alto"]
	var porte_v := clampf(inverse_lerp(alto_v.x, alto_v.y, altura_velha), 0.0, 1.0)
	var altura := lerpf(alto_v.x, alto_v.y, porte_v)
	var copa_v: Vector2 = e["copa"]
	var raio := Vector3(copa_v.x, copa_v.y, copa_v.x) * altura 		* Vector3(r.randf_range(0.88, 1.12), r.randf_range(0.9, 1.1), r.randf_range(0.88, 1.12))
	var tinta := Color.WHITE.lerp(Color(0.86, 0.94, 0.8), r.randf_range(0.0, 0.6))
	var nada: Array[Dictionary] = []
	_construir(sup, nada, base, especie, porte_v, r, altura, raio, r.randf_range(0.0, TAU),
		r.randf_range(-0.05, 0.05), tinta, 0.4 if seca else 0.04, false, false)
	return raio_velho


## Especies de praca e parque: o que se planta em praca de cidade mineira.
const PRACA: Array[StringName] = [&"sibipiruna", &"sibipiruna", &"oiti", &"ipe_amarelo",
	&"ipe_rosa", &"mangueira", &"oiti", &"jaqueira"]


static func _construir(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		especie: StringName, porte: float, r: RandomNumberGenerator, altura: float,
		raio: Vector3, giro: float, inclina: float, tinta: Color, seca: float,
		com_colisao: bool, ramo_perto: bool = true,
		poda: PackedVector3Array = PackedVector3Array()) -> void:
	var e: Dictionary = _especie(especie)
	# Fora da florada (Estacao), a arvore de flor e arvore de folha: o ipe de
	# fevereiro e verde, e a quaresmeira de agosto tambem.
	if _de_flor(especie) and not Estacao.florindo(especie):
		e = e.duplicate()
		e["celula"] = Vegetacao.C_CLARO if especie == &"pata_de_vaca" else Vegetacao.C_MIUDO
		e["tinta"] = Color.WHITE
		# O resedá perde a folha na seca: galho e pouca folha.
		if especie == &"reseda":
			seca += 0.4 * Estacao.seca()
	# Na seca a copa tem mais folha amarela, que e a que vai cair.
	seca += 0.06 * Estacao.seca()
	tinta = tinta * Color(e.get("tinta", Color.WHITE))
	var f: Dictionary = FORMAS.get(especie, FORMAS[&"oiti"])
	var fuste := altura * float(e["fuste"])
	var grossura := float(e["tronco"]) * lerpf(0.7, 1.15, porte)
	var tom: Color = e.get("casca", Vegetacao.CASCAS.get(especie, KitEstrada.CASCA_TOM))
	var y_topo := base.y + altura
	var desvio := Vector3(sin(giro) * inclina, 0.0, cos(giro) * inclina) * fuste
	var centro := base + desvio + Vector3(0.0, fuste + raio.y * 0.92, 0.0)
	var ob := Obra.new()
	var casca := ob.malha(CASCA)
	var rigidez := func(p: Vector3, s: float) -> float:
		# Tronco: preso no chao. Ramo: vai da rigidez do alto do fuste ate a do
		# cartao na mesma altura, pela fracao `s` do caminho (0 no tronco).
		var t := clampf((p.y - base.y) / maxf(y_topo - base.y, 0.1), 0.0, 1.0)
		var tronco := KitEstrada.CEDE_TRONCO * t * t
		var cartao := KitEstrada.CEDE_COPA * lerpf(0.35, 1.0, t * t)
		return lerpf(tronco, cartao, s * s)

	# --- tronco ---------------------------------------------------------
	var r0 := grossura * 0.6
	var torto := float(f["torto"])
	var lider := float(f["lider"])
	var alto_tronco := fuste + raio.y * 1.6 * lider
	var curva_t := Vector3(r.randf_range(-1.0, 1.0), 0.0, r.randf_range(-1.0, 1.0)) * torto * 0.35
	var espinha := PackedVector3Array()
	var raios := PackedFloat32Array()
	var cedes := PackedFloat32Array()
	# O pe: anel enterrado, e aneis juntos embaixo para a sapopema.
	var alturas := [-0.35, 0.0, 0.18, 0.45, 0.9]
	var n_meio := 5
	for k in n_meio:
		alturas.append(0.9 + (alto_tronco - 0.9) * float(k + 1) / float(n_meio))
	for h: float in alturas:
		var s := clampf(h / maxf(alto_tronco, 0.1), 0.0, 1.0)
		var p := base + desvio * (h / maxf(fuste, 0.1)) + curva_t * sin(s * PI) * fuste \
			+ Vector3(0.0, h, 0.0)
		espinha.append(p)
		# Afina ate o fuste e, com lider, afina mais ate a ponta.
		var afina := lerpf(1.0, 0.72, clampf(h / maxf(fuste, 0.1), 0.0, 1.0))
		if h > fuste:
			afina *= lerpf(1.0, 0.35, (h - fuste) / maxf(alto_tronco - fuste, 0.1))
		raios.append(r0 * afina)
		cedes.append(rigidez.call(p, 0.0))
	_tubo(casca, espinha, raios, cedes, LADOS_TRONCO, tom, float(f["sapopema"]) * r0,
		r.randf_range(0.0, TAU), base.y, raio.y + fuste)

	# --- pernadas e ramos ------------------------------------------------
	var pontas: Array[Vector3] = []
	var r_medio_copa := (raio.x + raio.y + raio.z) / 3.0
	# A poda cortou algum galho? Ai a folhagem de fechamento so fica onde ainda
	# ha galho para segurar (ver _folhagem).
	var podada := false
	var n_pernadas := r.randi_range(f["pernadas"].x, f["pernadas"].y)
	var abertura: Vector2 = f["abertura"]
	for k in n_pernadas:
		var az := giro + TAU * float(k) / float(n_pernadas) + r.randf_range(-0.35, 0.35)
		var fi := r.randf_range(abertura.x, abertura.y)
		var rumo := Vector3(sin(fi) * cos(az), cos(fi), sin(fi) * sin(az))
		# Onde sai: no alto do fuste, ou ao longo do lider.
		var sai_h := fuste * r.randf_range(0.82, 1.0)
		if lider > 0.0:
			sai_h = lerpf(fuste * 0.85, alto_tronco * 0.85, float(k) / float(maxi(n_pernadas - 1, 1)))
		var de := _no_tronco(espinha, alturas, sai_h, base)
		var r_de := _raio_no_tronco(raios, alturas, sai_h) * r.randf_range(0.55, 0.72)
		# Ate onde vai: dentro do elipsoide da copa, no rumo sorteado.
		var ate := centro + Vector3(rumo.x * raio.x, (rumo.y - 0.25) * raio.y, rumo.z * raio.z) * 0.62
		var pernada := _curva(de, ate, Vector3.UP * de.distance_to(ate) * 0.35
			+ Vector3(r.randf_range(-1, 1), 0.0, r.randf_range(-1, 1)) * torto * 0.6, 6)
		var rp := PackedFloat32Array()
		var cp := PackedFloat32Array()
		for i in pernada.size():
			var s := float(i) / float(pernada.size() - 1)
			rp.append(lerpf(r_de, r_de * 0.4, s))
			cp.append(rigidez.call(pernada[i], s * 0.6))
		# Poda em V na pernada tambem: o galho-mestre que chega no fio e serrado
		# antes dele, e o que nascia dali para a frente nao existe.
		var corte := pernada.size()
		if not poda.is_empty():
			for i in pernada.size():
				if PodaEmV.podado(pernada[i], poda, r_de):
					corte = i
					break
		if corte >= 2:
			_tubo(casca, pernada.slice(0, corte), rp.slice(0, corte), cp.slice(0, corte),
				LADOS_PERNADA, tom * 0.94, 0.0, 0.0, base.y, raio.y + fuste)
		if corte == pernada.size():
			pontas.append(ate)
		else:
			podada = true
			# A arvore mutilada da calcada rebrota em tufo na ponta do galho
			# serrado: o toco vira ponta e ganha o cacho dele (os cartoes que
			# cairem no V vao para o descarte). Sem isto a arvore embaixo da
			# virada de esquina ficava um Y pelado, lido como arvore morta.
			if corte >= 2:
				var toco := pernada[corte - 1]
				var tufo := toco + PodaEmV.para_fora_do_fio(toco, poda) * r_medio_copa * 0.35 					+ Vector3(0.0, -0.2, 0.0)
				pontas.append(tufo)
				# O broto que sai do toco e segura o tufo.
				var broto := _curva(toco, tufo, Vector3.UP * toco.distance_to(tufo) * 0.3, 3)
				var rb := PackedFloat32Array()
				var cb := PackedFloat32Array()
				for i in broto.size():
					var sb := float(i) / float(broto.size() - 1)
					rb.append(lerpf(rp[corte - 1] * 0.6, 0.02, sb))
					cb.append(rigidez.call(broto[i], lerpf(0.6, 1.0, sb)))
				_tubo(ob.malha(CASCA_PERTO) if ramo_perto else casca, broto, rb, cb, LADOS_RAMO,
					tom * 0.9, 0.0, 0.0, base.y, raio.y + fuste)
		var n_ramos := r.randi_range(f["ramos"].x, f["ramos"].y)
		for j in n_ramos:
			var s0 := r.randf_range(0.45, 0.9)
			var i0 := clampi(roundi(s0 * float(pernada.size() - 1)), 1, pernada.size() - 1)
			var p0 := pernada[i0]
			var lado := (rumo.cross(Vector3.UP) if absf(rumo.y) < 0.95 else Vector3.RIGHT).normalized()
			var gira := Basis(rumo, r.randf_range(0.0, TAU))
			var dir := (rumo + gira * lado * r.randf_range(0.6, 1.1) + Vector3.UP * 0.25).normalized()
			# O primeiro ramo de cada pernada sobe para o alto da copa: sem ele o
			# topo so tinha cartao da espiral, boiando sem galho (visto de baixo,
			# pratos soltos no ceu).
			if j == 0:
				dir = (rumo * 0.45 + Vector3.UP).normalized()
			var ponta := centro + Vector3(dir.x * raio.x, (dir.y - 0.1) * raio.y, dir.z * raio.z) \
				* r.randf_range(0.72, 0.9)
			var ramo := _curva(p0, ponta, Vector3.UP * p0.distance_to(ponta) * 0.2, 4)
			var rr := PackedFloat32Array()
			var cr := PackedFloat32Array()
			for i in ramo.size():
				var s := float(i) / float(ramo.size() - 1)
				rr.append(lerpf(rp[i0] * 0.75, 0.025, s))
				cr.append(rigidez.call(ramo[i], lerpf(0.6, 1.0, s)))
			# Poda em V (PodaEmV.podado): o ramo que chega no fio foi cortado, e o
			# cacho da ponta dele junto.
			if i0 >= corte or (not poda.is_empty() and _ramo_no_fio(ramo, poda)):
				podada = true
				continue
			_tubo(ob.malha(CASCA_PERTO) if ramo_perto else casca, ramo, rr, cr, LADOS_RAMO,
				tom * 0.9, 0.0, 0.0, base.y,
				raio.y + fuste)
			pontas.append(ponta)
			pontas.append(ramo[ramo.size() / 2])

	if com_colisao:
		colisao.append({"tamanho": Vector3(grossura, fuste, grossura),
			"pos": base + Vector3(0.0, fuste * 0.5, 0.0)})

	# --- folhas --------------------------------------------------------------
	_folhagem(ob, r, e, f, centro, raio, pontas, tinta, base.y, y_topo, seca, poda, podada)
	ob.despejar(sup)


static func _perto_de_ponta(q: Vector3, pontas: Array[Vector3], raio: float) -> bool:
	for p: Vector3 in pontas:
		if p.distance_to(q) < raio:
			return true
	return false


## O ramo passa perto do fio em algum ponto? (poda em V, PodaEmV.podado)
static func _ramo_no_fio(ramo: PackedVector3Array, poda: PackedVector3Array) -> bool:
	for q: Vector3 in ramo:
		if PodaEmV.podado(q, poda, 0.1):
			return true
	return false


## Os cartoes: um cacho em cada ponta de ramo, o miolo escuro, e a espiral de
## antes so para fechar a silhueta onde nenhum ramo chegou.
static func _folhagem(ob: Obra, r: RandomNumberGenerator, e: Dictionary, f: Dictionary,
		centro: Vector3, raio: Vector3, pontas: Array[Vector3], tinta: Color, y_base: float,
		y_topo: float, seca: float, poda: PackedVector3Array = PackedVector3Array(),
		podada: bool = false) -> void:
	var m := ob.malha(e.get("mat", Vegetacao.MAT))
	var mv := ob.malha(Vegetacao.MAT)
	# O cartao podado ainda gasta o sorteio (vai para o descarte): a copa podada e
	# a MESMA copa sem o V, e nao outra arvore.
	var descarte := ParedeVazada.Malha.new()
	var celula: Vector2i = e["celula"]
	var r_medio := (raio.x + raio.y + raio.z) / 3.0
	var tam := float(e["cartao"]) * 0.7
	# Miolo: tres cartoes escuros cruzados, menores que os de antes — agora ha
	# galho dentro da copa, e ele deve aparecer por entre as folhas.
	# Na copa aberta (ipe, sibipiruna) o miolo aparece pelo vao como uma mancha
	# preta boiando ao lado da copa: la ele nao entra.
	var fechada_m := float(f.get("fechada", 0.5))
	for k in 3:
		var giro_m := PI / 3.0 * float(k) + r.randf_range(0.0, 0.5)
		if fechada_m < 0.5:
			continue
		# O miolo escuro no meio do V da poda seria uma placa preta no vao.
		if podada and PodaEmV.podado(centro, poda, maxf(raio.x, raio.z) * 0.6):
			continue
		var b := Basis(Vector3.UP, giro_m)
		Vegetacao._cartao(mv, centro + Vector3(0.0, raio.y * 0.1, 0.0), b,
			Vector2(raio.x, raio.y) * 1.05 * fechada_m, Vegetacao.C_SOMBRA, centro, raio, tinta,
			y_base, y_topo, 0.88)
	# O cacho e um VOLUME de cartoes menores cruzados, e nao um prato: cartao
	# grande tangente a copa lia de perto como uma casca de pratos chapados
	# (rodada 2, `mangueira_perto`). Uma vez e meia mais cartoes a 0,72 do lado
	# cobre a mesma area com o triplo de silhuetas.
	var n_cacho := int(f["cacho"]) + 1 - roundi(float(f.get("fechada", 0.5)) * 2.0)
	n_cacho = maxi(2, roundi(float(n_cacho) * 1.5))
	var torto_c := lerpf(0.85, 0.5, float(f.get("fechada", 0.5)))
	for p: Vector3 in pontas:
		for k in n_cacho:
			var q := p + Vector3(r.randf_range(-1, 1), r.randf_range(-0.6, 1), r.randf_range(-1, 1)) \
				* r_medio * 0.2
			# Puxado um pouco para dentro: a ponta do ramo fica NO cacho, e nao
			# um cartao solto na ponta de um palito.
			q = q.lerp(centro, 0.08)
			# Dentro do elipsoide da copa: o cartao solto alem dela, visto do alto,
			# era uma bandeira saindo da arvore (foto `quintais` da rodada 2).
			var rel := (q - centro) / Vector3(maxf(raio.x, 0.1), maxf(raio.y, 0.1), maxf(raio.z, 0.1))
			if rel.length() > 0.88:
				q = centro + (q - centro) * (0.88 / rel.length())
			var lado_c := r_medio * tam * 0.72 * r.randf_range(0.75, 1.05)
			var corta := not poda.is_empty() and PodaEmV.podado(q, poda, lado_c * 0.7)
			_cartao_de_fora(descarte if corta else m, r, q, centro, raio, lado_c,
				celula, tinta, y_base, y_topo, seca, torto_c, descarte if corta else mv)
	# O fecho: espiral de Fibonacci, so onde nao ha ponta perto.
	var n := int(float(e["cartoes"]) * 1.2)
	var ouro := PI * (3.0 - sqrt(5.0))
	var fechada := float(f.get("fechada", 0.5))
	var perto := r_medio * 0.42 * (1.0 - fechada)
	for k in n:
		var yy := 1.0 - (float(k) + 0.5) / float(n) * 1.75
		var rr := sqrt(maxf(0.0, 1.0 - yy * yy))
		var th := ouro * float(k) + r.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(th) * rr, yy, sin(th) * rr)
		var q := centro + dir * raio * r.randf_range(0.66, 0.84 + 0.06 * fechada)
		var coberto := false
		for p: Vector3 in pontas:
			if p.distance_to(q) < perto:
				coberto = true
				break
		if coberto:
			continue
		var lado_e := r_medio * tam * r.randf_range(0.85, 1.15)
		var corta := not poda.is_empty() and PodaEmV.podado(q, poda, lado_e * 0.7)
		# Na copa podada o fechamento que ficou longe de todo galho restante
		# boiava no ar: o galho que o segurava foi serrado.
		if podada and not corta and not _perto_de_ponta(q, pontas, r_medio * 0.6):
			corta = true
		_cartao_de_fora(descarte if corta else m, r, q, centro, raio, lado_e,
			celula, tinta, y_base, y_topo, seca, torto_c, descarte if corta else mv)


## Cartao virado para fora da copa, torto (um cacho de verdade nao encara o
## centro), girado em torno da propria normal.
static func _cartao_de_fora(m: ParedeVazada.Malha, r: RandomNumberGenerator, q: Vector3,
		centro: Vector3, raio: Vector3, lado: float, celula: Vector2i, tinta: Color,
		y_base: float, y_topo: float, seca: float, torto: float = 0.8,
		m_seca: ParedeVazada.Malha = null) -> void:
	var rel := (q - centro) / Vector3(maxf(raio.x, 0.1), maxf(raio.y, 0.1), maxf(raio.z, 0.1))
	var fora := (rel.normalized() + Vector3(0.0, 0.12, 0.0)).normalized()
	# Torto de verdade (ate ~50 graus): os cartoes do cacho se cruzam, e a copa
	# ganha profundidade em vez de uma casca de cartoes tangentes.
	# Na copa fechada (oiti, mangueira) menos: ela e uma bola densa, e cartao
	# muito torto abria vao nela.
	fora = (fora + Vector3(r.randf_range(-1, 1), r.randf_range(-0.7, 0.7), r.randf_range(-1, 1))
		* torto).normalized()
	var b := Basis(Quaternion(Vector3.BACK, fora)) * Basis(Vector3.BACK, r.randf() * TAU)
	var cel := celula
	if r.randf() < seca:
		cel = Vegetacao.C_SECO if celula != Vegetacao.C_IPE_AMARELO and celula != Vegetacao.C_IPE_ROSA \
			else Vegetacao.C_MIUDO
		# A folha seca e do atlas da vegetacao, mesmo na copa do atlas `plantas`.
		if m_seca != null:
			m = m_seca
	Vegetacao._cartao(m, q, b, Vector2(lado, lado), cel, centro, raio, tinta, y_base, y_topo, 1.0)


# --- geometria ------------------------------------------------------------------

## Curva de Bezier quadratica de `de` a `ate`, com o ponto de controle no meio
## puxado por `puxa`.
static func _curva(de: Vector3, ate: Vector3, puxa: Vector3, pontos: int) -> PackedVector3Array:
	var c := (de + ate) * 0.5 + puxa
	var out := PackedVector3Array()
	for i in pontos:
		var t := float(i) / float(pontos - 1)
		out.append(de.lerp(c, t).lerp(c.lerp(ate, t), t))
	return out


static func _no_tronco(espinha: PackedVector3Array, alturas: Array, h: float, base: Vector3) -> Vector3:
	for i in range(1, alturas.size()):
		if float(alturas[i]) >= h:
			var t := (h - float(alturas[i - 1])) / maxf(float(alturas[i]) - float(alturas[i - 1]), 0.001)
			return espinha[i - 1].lerp(espinha[i], t)
	return espinha[espinha.size() - 1]


static func _raio_no_tronco(raios: PackedFloat32Array, alturas: Array, h: float) -> float:
	for i in range(1, alturas.size()):
		if float(alturas[i]) >= h:
			var t := (h - float(alturas[i - 1])) / maxf(float(alturas[i]) - float(alturas[i - 1]), 0.001)
			return lerpf(raios[i - 1], raios[i], t)
	return raios[raios.size() - 1]


## Tubo pela espinha, um anel por ponto, perpendicular a tangente e sem torcer
## (transporte paralelo). UV em metros: a casca repete como na caixa de antes.
## `sapopema` alarga o pe em tres lobos que somem ate 0,9 m de altura.
static func _tubo(m: ParedeVazada.Malha, pts: PackedVector3Array, raios: PackedFloat32Array,
		cedes: PackedFloat32Array, lados: int, tom: Color, sapopema: float, fase: float,
		y_chao: float, alto: float) -> void:
	var n := pts.size()
	if n < 2:
		return
	var t0 := (pts[1] - pts[0]).normalized()
	var ref := Vector3.RIGHT if absf(t0.x) < 0.9 else Vector3.FORWARD
	ref = (ref - t0 * ref.dot(t0)).normalized()
	var volta := TAU * raios[0]
	var v_acum := 0.0
	var aneis: Array[PackedInt32Array] = []
	var dirs: Array[PackedVector3Array] = []
	for i in n:
		var tg := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		ref = (ref - tg * ref.dot(tg)).normalized()
		var bi := tg.cross(ref)
		if i > 0:
			v_acum += pts[i].distance_to(pts[i - 1])
		var h := pts[i].y - y_chao
		# Sombra: o pe mais escuro (terra, umidade), o alto sob a copa tambem.
		var ao := clampf(0.62 + 0.38 * smoothstep(0.0, 1.6, h), 0.0, 1.0) \
			* lerpf(1.0, 0.8, smoothstep(alto * 0.35, alto * 0.7, h))
		var anel := PackedInt32Array()
		var ds := PackedVector3Array()
		for k in lados + 1:
			var th := TAU * float(k) / float(lados)
			var d := ref * cos(th) + bi * sin(th)
			var raio := raios[i]
			if sapopema > 0.0 and h < 0.9:
				var lobo := pow(maxf(0.0, cos(3.0 * th + fase)), 2.0)
				var some := pow(1.0 - clampf(maxf(h, 0.0) / 0.9, 0.0, 1.0), 2.0)
				raio += sapopema * some * (0.45 + 0.55 * lobo)
			var cor := Color(tom.r * ao, tom.g * ao, tom.b * ao, cedes[i])
			anel.append(m.vertice(pts[i] + d * raio, d,
				Vector2(float(k) / float(lados) * volta, v_acum), Vector2.ZERO, cor))
			ds.append(d)
		aneis.append(anel)
		dirs.append(ds)
	for i in n - 1:
		for k in lados:
			var nrm := (dirs[i][k] + dirs[i][k + 1] + dirs[i + 1][k] + dirs[i + 1][k + 1]).normalized()
			m.quad(aneis[i][k], aneis[i][k + 1], aneis[i + 1][k + 1], aneis[i + 1][k], nrm)
	# Tampa da ponta: um leque, para o galho cortado nao mostrar o oco.
	var ult := aneis[n - 1]
	var tg_fim := (pts[n - 1] - pts[n - 2]).normalized()
	var centro := m.vertice(pts[n - 1] + tg_fim * raios[n - 1] * 0.3, tg_fim, Vector2.ZERO,
		Vector2.ZERO, Color(tom.r * 0.8, tom.g * 0.8, tom.b * 0.8, cedes[n - 1]))
	for k in lados:
		m.tri(ult[k], ult[k + 1], centro, tg_fim)


# --- palmeira -------------------------------------------------------------------

## A palmeira por esqueleto: estipe roliço (a imperial com a barriga no pe e o
## palmito verde liso; o coqueiro torto), e cada folha como DUAS tiras que
## arqueiam e caem, cruzadas em V ao longo da raque.
##
## A folha de antes era um cartao deitado, face para cima. Da rua ele fica de
## perfil, o recorte de perfil do shader de folha o apaga, e a imperial da praca
## virava um espanador de quatro folhas. Folha de palmeira de verdade tem os
## foliolos em V: de qualquer lado uma das metades aparece.
##
## `folhas` traz, por folha, (rumo, queda, giro) — os sorteios de quem chama,
## na ordem de quem chama.
static func palmeira(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		imperial: bool, altura: float, giro: float, curva: float, folhas: PackedVector3Array,
		comp: float, poda: PackedVector3Array = PackedVector3Array()) -> void:
	var y_topo := base.y + altura + 2.0
	var dir := Vector3(cos(giro), 0.0, sin(giro))
	var grosso := 0.42 if imperial else 0.3
	var tom := Color.WHITE if imperial else Color("b0a290")
	var ob := Obra.new()
	var casca := ob.malha(&"casca_palmeira" if imperial else CASCA)
	var cede_topo := KitEstrada.CEDE_TRONCO + 0.25
	var espinha := PackedVector3Array()
	var raios := PackedFloat32Array()
	var cedes := PackedFloat32Array()
	var passos := 9
	for k in passos + 1:
		var t := float(k) / float(passos)
		var h := altura * t - (0.3 if k == 0 else 0.0)
		espinha.append(base + Vector3(0.0, h, 0.0) + dir * curva * t * t)
		# A imperial engrossa no pe (a barriga) e afina reto; o coqueiro afina pouco.
		var g := grosso * 0.5
		if imperial:
			g *= 1.0 + 0.35 * pow(1.0 - clampf(t * 4.0, 0.0, 1.0), 2.0) - 0.22 * t
		else:
			g *= 1.0 + 0.2 * pow(1.0 - clampf(t * 5.0, 0.0, 1.0), 2.0) - 0.2 * t
		raios.append(g)
		cedes.append(cede_topo * t * t)
	_tubo(casca, espinha, raios, cedes, 9, tom, 0.0, 0.0, base.y, altura)
	var topo := espinha[passos]
	if imperial:
		# O palmito: o verde liso entre o estipe cinza e a folha.
		var verde := ob.malha(&"folhagem")
		var p2 := PackedVector3Array([topo - Vector3(0.0, 0.05, 0.0), topo + Vector3(0.0, 0.9, 0.0),
			topo + Vector3(0.0, 1.8, 0.0)])
		var r2 := PackedFloat32Array([raios[passos] * 1.02, raios[passos] * 1.05, raios[passos] * 0.8])
		var c2 := PackedFloat32Array([cede_topo, cede_topo * 1.1, cede_topo * 1.2])
		_tubo(verde, p2, r2, c2, 9, Color(0.55, 0.72, 0.42), 0.0, 0.0, base.y, altura + 2.0)
		topo += Vector3(0.0, 1.8, 0.0)
	colisao.append({"tamanho": Vector3(grosso, altura, grosso),
		"pos": base + Vector3(0.0, altura * 0.5, 0.0)})
	var m := ob.malha(Vegetacao.MAT)
	var coroa := topo + Vector3(0.0, -comp * 0.1, 0.0)
	for fo: Vector3 in folhas:
		var fora := Vector3(cos(fo.x), 0.0, sin(fo.x))
		var queda := fo.y
		var eixo := (fora * cos(queda) + Vector3(0.0, sin(queda), 0.0)).normalized()
		# A folha nova (para cima) arqueia pouco; a velha, caida, arqueia muito.
		var arco := lerpf(0.55, 0.2, clampf((queda + 0.9) / 1.7, 0.0, 1.0))
		# A folha que desce ate o fio e cortada rente (PodaEmV.podado): a
		# palmeira embaixo da rede fica com a saia aparada do lado da rua.
		if not poda.is_empty():
			var no_fio := false
			for s: float in [0.35, 0.7, 1.0]:
				var q := topo + eixo * comp * s * 0.92 + Vector3(0.0, -arco * comp * s * s, 0.0)
				if PodaEmV.podado(q, poda, comp * 0.25):
					no_fio = true
					break
			if no_fio:
				continue
		for lado_v in [-1.0, 1.0]:
			_fronde(m, topo, eixo, comp, fo.z + lado_v * 0.6, arco, Vegetacao.C_PALMA, coroa,
				base.y, y_topo, cede_topo)
	ob.despejar(sup)


## Uma tira de folha de palmeira: sai de `de` no rumo `eixo`, cai pelo `arco`,
## com a largura girada `rolo` em torno da raque. A celula e desenhada com a
## raque ao longo do x da imagem, da base (esquerda) a ponta (direita).
static func _fronde(m: ParedeVazada.Malha, de: Vector3, eixo: Vector3, comp: float,
		rolo: float, arco: float, celula: Vector2i, coroa: Vector3, y_base: float,
		y_topo: float, cede_base: float) -> void:
	var uv := Vegetacao.uv_de(celula)
	var horizontal := eixo.cross(Vector3.UP)
	if horizontal.length_squared() < 0.0001:
		horizontal = Vector3.RIGHT
	var largura := horizontal.normalized().rotated(eixo, rolo) * comp * 0.5
	const SEG := 4
	var ids_a: Array[int] = []
	var ids_b: Array[int] = []
	var pontos: Array[Vector3] = []
	for i in SEG + 1:
		var s := float(i) / float(SEG)
		# A queda da folha dobra o rumo dela para baixo ao longo do comprimento.
		pontos.append(de + eixo * comp * s * 0.92 + Vector3(0.0, -arco * comp * s * s, 0.0))
	for i in SEG + 1:
		var p := pontos[i]
		var s := float(i) / float(SEG)
		var normal := ((p - coroa).normalized() + Vector3(0.0, 0.45, 0.0)).normalized()
		var cede := lerpf(cede_base, KitEstrada.CEDE_COPA, s * s)
		var luz := lerpf(0.72, 0.95, s)
		var cor := Color(luz, luz, luz, cede)
		var u := uv.position.x + uv.size.x * (0.06 + 0.9 * s)
		ids_a.append(m.vertice(p + largura, normal, Vector2(u, uv.position.y), Vector2.ZERO, cor))
		ids_b.append(m.vertice(p - largura, normal, Vector2(u, uv.end.y), Vector2.ZERO, cor))
	for i in SEG:
		var face := (pontos[i + 1] - pontos[i]).cross(largura).normalized()
		m.quad(ids_a[i], ids_a[i + 1], ids_b[i + 1], ids_b[i], face)
		m.quad(ids_a[i], ids_a[i + 1], ids_b[i + 1], ids_b[i], -face)


# --- arbusto e cerca viva (etapa 3) ----------------------------------------------

## O arbusto do parque (KitParque.arbusto), que eram dois ou tres blocos: agora a
## moita de cartao da Vegetacao, com o mesmo sorteio gasto do rng de quem planta.
## Quase toda de folha; uma em cinco e primavera florida, uma em dez e canteiro
## de flor miuda.
static func arbusto_de_parque(sup: Dictionary, base: Vector3, raio: float,
		rng: RandomNumberGenerator) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([rng.state, roundi(base.x * 10.0), roundi(base.z * 10.0), 13])
	rng.randi()
	var n := rng.randi_range(2, 3)
	for i in n:
		for k in 4:
			rng.randf()
	var cel := Vegetacao.C_ARBUSTO
	var s := r.randf()
	if s < 0.2:
		cel = Vegetacao.C_PRIMAVERA
	elif s < 0.3:
		cel = Vegetacao.C_FLOR
	var ob := Obra.new()
	Vegetacao.arbusto(ob, base, raio * r.randf_range(1.0, 1.25), cel, r)
	ob.despejar(sup)


## A franja da cerca viva: cartoes de ramo soltos ao longo das duas quinas de
## cima. A caixa podada continua (cerca viva de verdade e podada reta), mas a
## quina viva quebra a aresta de regua contra o ceu, que e o que a denunciava
## como caixa verde.
static func franja_de_sebe(sup: Dictionary, a: Vector3, dir: Vector3, trechos: PackedVector3Array,
		semente: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = semente
	var ob := Obra.new()
	var m := ob.malha(Vegetacao.MAT)
	var lado := Vector3(dir.z, 0.0, -dir.x)
	for t: Vector3 in trechos:
		# t = (distancia ao longo, altura, largura) de cada bloco.
		var passo := 0.45
		var n := maxi(1, int(1.6 / passo))
		for k in n:
			var ao_longo := t.x + (float(k) + r.randf_range(0.2, 0.8)) * passo - 0.8
			for s: float in [-1.0, 1.0]:
				var p := a + dir * ao_longo + lado * s * (t.z * 0.5 - 0.02) \
					+ Vector3(0.0, t.y - r.randf_range(0.02, 0.1), 0.0)
				var fora := (lado * s + Vector3(0.0, r.randf_range(0.6, 1.1), 0.0)).normalized()
				var b := Basis(Quaternion(Vector3.BACK, fora)) * Basis(Vector3.BACK, r.randf() * TAU)
				var centro := a + dir * ao_longo + Vector3(0.0, t.y * 0.5, 0.0)
				Vegetacao._cartao(m, p, b, Vector2.ONE * r.randf_range(0.42, 0.6), Vegetacao.C_ARBUSTO,
					centro, Vector3(t.z, t.y, t.z), Color(0.9, 0.95, 0.85), a.y, a.y + t.y * 2.0, 1.0)
	ob.despejar(sup)


# --- conifera da estrada (etapa 5) ----------------------------------------------

## A conifera da mata da estrada (KitEstrada.conifera), que era cinco caixas
## empilhadas — de longe, na nevoa, pagodes verdes. Agora tronco reto que afina
## ate a ponta e andares de galho caido, cada andar mais curto (o cone), com
## cartao de folha miuda escura na ponta e ao longo de cada galho.
##
## `saia` e o da de caixa: onde o primeiro andar comeca, em fracao da altura. A
## estrada abaixa a saia na beira da pista (a arvore de beira pega luz de lado e
## guarda o galho de baixo), e isso continua valendo: e o que fecha o vao entre
## o capim e a copa.
static func de_conifera(sup: Dictionary, base: Vector3, porte: float,
		rng: RandomNumberGenerator, saia: float) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = hash([rng.state, roundi(base.x * 10.0), roundi(base.z * 10.0), 19])
	# --- os sorteios da conifera de caixa, na ordem dela -------------------
	var altura := lerpf(9.0, 16.0, porte)
	var raio_velho := lerpf(1.5, 2.4, porte)
	var tronco := lerpf(0.26, 0.40, porte)
	rng.randf_range(0.0, TAU)
	rng.randi()
	for i in 5:
		rng.randf_range(0.86, 1.1)
		rng.randf_range(0.0, 0.9)
	# ----------------------------------------------------------------------
	var ob := Obra.new()
	var casca := ob.malha(CASCA)
	var folha := ob.malha(Vegetacao.MAT)
	var y_topo := base.y + altura
	var tom := Color("5a4c40")
	var tinta := Color(0.62, 0.74, 0.66).lerp(Color(0.7, 0.8, 0.62), r.randf())
	var rig := func(p: Vector3, s: float) -> float:
		var t := clampf((p.y - base.y) / altura, 0.0, 1.0)
		return lerpf(KitEstrada.CEDE_TRONCO * t * t, KitEstrada.CEDE_COPA * lerpf(0.25, 0.8, t * t), s * s)
	# Tronco inteiro, afinando ate um dedo na ponta.
	var espinha := PackedVector3Array()
	var raios := PackedFloat32Array()
	var cedes := PackedFloat32Array()
	var torto := Vector3(r.randf_range(-1, 1), 0.0, r.randf_range(-1, 1)) * 0.12
	for k in 9:
		var t := float(k) / 8.0
		var p := base + Vector3(0.0, altura * t - (0.3 if k == 0 else 0.0), 0.0) + torto * sin(t * PI) * altura * 0.1
		espinha.append(p)
		raios.append(tronco * 0.5 * lerpf(1.0, 0.08, t))
		cedes.append(rig.call(p, 0.0))
	_tubo(casca, espinha, raios, cedes, 6, tom, tronco * 0.2, r.randf() * TAU, base.y, altura)
	var centro := base + Vector3(0.0, altura * 0.55, 0.0)
	var raio_cone := Vector3(raio_velho, altura * 0.5, raio_velho)
	# Andares de galho.
	var y0 := altura * clampf(saia, 0.05, 0.6)
	var andares := 9
	for a in andares:
		var t := float(a) / float(andares - 1)
		var h := lerpf(y0, altura * 0.93, t)
		var alcance := raio_velho * 1.05 * pow(1.0 - t * 0.88, 0.9)
		var n := 6 if t < 0.7 else 4
		var fase := r.randf() * TAU
		for g in n:
			var az := fase + TAU * float(g) / float(n) + r.randf_range(-0.25, 0.25)
			var fora := Vector3(cos(az), 0.0, sin(az))
			var de := base + Vector3(0.0, h, 0.0) + torto * sin(h / altura * PI) * altura * 0.1
			var cai := r.randf_range(0.15, 0.45) * alcance
			var ate := de + fora * alcance + Vector3(0.0, -cai, 0.0)
			var galho := _curva(de, ate, Vector3(0.0, cai * 0.6, 0.0), 3)
			var rg := PackedFloat32Array([raios[mini(roundi(h / altura * 8.0), 8)] * 0.35, 0.03, 0.012])
			var cg := PackedFloat32Array()
			for p in galho:
				cg.append(rig.call(p, 0.5))
			cg[0] = rig.call(galho[0], 0.0)
			_tubo(casca, galho, rg, cg, 3, tom * 0.9, 0.0, 0.0, base.y, altura)
			# Folha: na ponta e no meio do galho, virada para fora e para baixo.
			for s: float in [0.55, 1.0]:
				var p := galho[0].lerp(galho[2], s) if s < 1.0 else galho[2]
				var dir := (fora + Vector3(0.0, r.randf_range(-0.4, 0.25), 0.0)).normalized()
				var b := Basis(Quaternion(Vector3.BACK, dir)) * Basis(Vector3.BACK, r.randf() * TAU)
				var lado := alcance * r.randf_range(0.8, 1.1) * (1.0 if s == 1.0 else 0.85) + 0.7
				Vegetacao._cartao(folha, p, b, Vector2(lado, lado * 0.8), Vegetacao.C_MIUDO,
					centro, raio_cone, tinta, base.y, y_topo, 0.92)
	# Miolo escuro em cruz: o cone fechado nao mostra ceu pelo meio.
	for k in 2:
		var b := Basis(Vector3.UP, PI * 0.5 * float(k) + r.randf() * 0.5)
		var altura_m := altura - y0
		Vegetacao._cartao(folha, base + Vector3(0.0, y0 + altura_m * 0.42, 0.0), b,
			Vector2(raio_velho * 1.5, altura_m * 0.85), Vegetacao.C_SOMBRA, centro, raio_cone, tinta,
			base.y, y_topo, 0.8)
	ob.despejar(sup)
	return raio_velho
