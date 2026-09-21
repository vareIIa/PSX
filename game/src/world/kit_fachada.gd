## Fachada de quadra residencial: a frente de uma casa, e nao de uma loja.
##
## Existe porque `KitModular.fachada` so sabia fazer terreo comercial. Sem loja
## sorteada ela caia no `metal_ondulado`, e o resultado numa rua de casas era uma
## fileira de portas de aco fechadas repetida a cada tres metros — inclusive POR
## CIMA da porta em que o jogador tinha de entrar. A captura da rua residencial
## nao mostrava uma casa: mostrava um deposito.
##
## O que faz uma parede ler como casa, em ordem de importancia:
##
##   1. A porta ser uma porta. Vao recuado, batente, degrau e numero.
##   2. Janela na altura do olho, com peitoril e grade. Fachada cega e galpao.
##   3. Embasamento. A faixa de material diferente rente ao chao e o que
##      distingue casa de caixa: toda casa de rua tem uma, porque e ali que a
##      chuva bate e e ali que a parede descasca.
##   4. Pingadeira entre um andar e outro. Uma sombra horizontal a cada tres
##      metros quebra o paredao sem custar volume.
##
## Nada aqui e volume novo: sao placas rente a parede que a quadra ja levantou.
class_name KitFachada
extends RefCounted

## Largura de um vao de fachada. Casa de rua tem janela a cada tres metros mais
## ou menos; menos que isso vira grade de escritorio.
const PASSO_VAO := 3.0

## Altura do embasamento.
const EMBASAMENTO := 0.55

## Meia largura reservada para a porta, contando batente e marquise. Nenhum
## painel de fachada encosta dentro desta faixa.
const MEIA_PORTA := 1.05

const CINZA_BATENTE := Color("4a443a")
const PEDRA := Color("8d8577")


## Frente de uma casa. `porta_local` e a distancia da porta de entrada ao centro
## do trecho, medida ao longo da fachada; NAN quando este trecho nao tem porta.
##
## Devolve sempre false: casa nao tem vitrine. O retorno existe so para a
## assinatura bater com `KitModular.fachada`, que quem monta a quadra usa para
## decidir o toldo.
static func residencia(sup: Dictionary, centro: Vector3, largura: float,
		andares: int, direcao: int, material: StringName,
		rng: RandomNumberGenerator, prob_janela_acesa: float = 0.32,
		cor: Color = Color.WHITE, porta_local: float = NAN,
		vao_real: bool = false, garagens: Array = [], info: Dictionary = {}) -> bool:
	var altura := andares * KitModular.ALTURA_ANDAR
	var normal := KitModular._normal(direcao)
	var lateral := KitModular._lateral(direcao)
	var giro := atan2(normal.x, normal.z)

	# `vao_real`: atras da porta existe a casa (InteriorNoMundo). A fachada vira
	# tres pecas em volta do vao, em vez de um plano inteiro com um painel
	# pintado no lugar da entrada — era o "abre a porta e aparece parede".
	var vazada := vao_real and is_finite(porta_local)
	if vazada:
		_plano_vazado(sup, material, centro, largura, 0.0, altura, direcao,
			lateral, porta_local, cor)
	else:
		KitModular.parede(sup, material, centro + Vector3(0.0, altura * 0.5, 0.0),
			Vector2(largura, altura), direcao, cor)

	var frente := centro + normal * 0.06
	# Estilo da casa, nao da quadra. A tinta ja e compartilhada pelo quarteirao;
	# o que muda de uma porta para a outra e azulejo no rodape, veneziana,
	# ar-condicionado. Sem isso a rua residencial e uma fileira do mesmo vao.
	var estilo := rng.randi_range(0, 3)

	_embasamento(sup, frente, largura, direcao, cor, estilo,
		porta_local if vazada else NAN)
	_terreo(sup, frente, largura, direcao, giro, lateral, normal, rng,
		prob_janela_acesa, porta_local, estilo, vazada, garagens, info)
	_pingadeira(sup, frente, largura, giro, andares, cor)
	_andares(sup, frente, largura, direcao, giro, lateral, andares, rng,
		prob_janela_acesa, estilo)
	return false


## Faixa de material diferente rente ao chao, com uma pingadeira em cima. Sai a
## frente do resto da parede: encostada, os dois planos disputam o pixel e a
## faixa inteira pisca a vinte metros.
static func _embasamento(sup: Dictionary, frente: Vector3, largura: float,
		direcao: int, cor: Color, estilo: int = 0, vao: float = NAN) -> void:
	var normal := KitModular._normal(direcao)
	var lateral := KitModular._lateral(direcao)
	# 1 = azulejo de rodape, o acabamento de casa de cidade pequena. Tijolo
	# continua sendo o padrao; os dois no mesmo quarteirao ja quebram a fileira.
	var mat: StringName = &"azulejo" if estilo == 1 else &"tijolo"
	var alto := EMBASAMENTO * (1.55 if estilo == 1 else 1.0)
	var tinta := Color.WHITE if estilo == 1 else cor.darkened(0.30)
	# Com vao de verdade a faixa para dos dois lados dele: inteira, ela
	# atravessava a porta aberta como uma soleira de meio metro.
	for trecho: Vector2 in _trechos(largura, vao):
		var meio := (trecho.x + trecho.y) * 0.5
		var larg := trecho.y - trecho.x
		KitModular.parede(sup, mat,
			frente + normal * 0.02 + lateral * meio + Vector3(0.0, alto * 0.5, 0.0),
			Vector2(larg, alto), direcao, tinta)
		KitModular.caixa_cor(sup, &"concreto",
			frente + normal * 0.05 + lateral * meio + Vector3(0.0, alto, 0.0),
			Vector3(larg, 0.08, 0.14), PEDRA, atan2(normal.x, normal.z))


## Meia largura do vao de verdade: a folha de 1,10 m mais o encaixe no batente.
const MEIO_VAO_REAL := 0.59
## Altura do vao de verdade, da calcada a verga.
const ALTURA_VAO_REAL := 2.14


## Os trechos de uma faixa horizontal de `largura` que nao cruzam o vao. Sem
## vao, a faixa inteira.
static func _trechos(largura: float, vao: float) -> Array[Vector2]:
	var meia := largura * 0.5
	if not is_finite(vao):
		return [Vector2(-meia, meia)]
	var saida: Array[Vector2] = []
	if vao - MEIO_VAO_REAL > -meia + 0.02:
		saida.append(Vector2(-meia, vao - MEIO_VAO_REAL))
	if vao + MEIO_VAO_REAL < meia - 0.02:
		saida.append(Vector2(vao + MEIO_VAO_REAL, meia))
	return saida


## Um plano de fachada de `y0` a `y1` com o vao da porta aberto: os trechos dos
## lados, na altura inteira, e a verga por cima do vao.
static func _plano_vazado(sup: Dictionary, material: StringName, centro: Vector3,
		largura: float, y0: float, y1: float, direcao: int, lateral: Vector3,
		vao: float, cor: Color) -> void:
	for trecho: Vector2 in _trechos(largura, vao):
		KitModular.parede(sup, material,
			centro + lateral * ((trecho.x + trecho.y) * 0.5)
				+ Vector3(0.0, (y0 + y1) * 0.5, 0.0),
			Vector2(trecho.y - trecho.x, y1 - y0), direcao, cor)
	var pe := KitModular.ALTURA_MEIO_FIO + ALTURA_VAO_REAL
	KitModular.parede(sup, material,
		centro + lateral * vao + Vector3(0.0, (pe + y1) * 0.5, 0.0),
		Vector2(MEIO_VAO_REAL * 2.0, y1 - pe), direcao, cor)


## O terreo, vao a vao. Cada vao vira porta, janela ou portao de garagem.
static func _terreo(sup: Dictionary, frente: Vector3, largura: float,
		direcao: int, giro: float, lateral: Vector3, normal: Vector3,
		rng: RandomNumberGenerator, prob_janela_acesa: float,
		porta_local: float, estilo: int = 0, vao_real: bool = false,
		garagens: Array = [], info: Dictionary = {}) -> void:
	var vaos := maxi(1, int(round(largura / PASSO_VAO)))
	var passo := largura / float(vaos)

	# A garagem entra no maximo uma vez por trecho. E o unico lugar onde o metal
	# ondulado ainda faz sentido numa rua de casas.
	var garagem := -1
	if passo > 2.6 and rng.randf() < 0.45:
		garagem = rng.randi_range(0, vaos - 1)

	var tem_porta := is_finite(porta_local)
	# Casa sem a porta de entrar do chunk tambem tem porta. Antes so a casa da
	# porta interativa tinha entrada: todas as outras eram parede com janela e
	# portao de garagem, e a rua de casas era uma fileira sem porta nenhuma.
	# Esta e de madeira, fechada, e nao abre — mas e porta.
	var falsa := -1
	if not tem_porta:
		falsa = rng.randi_range(0, vaos - 1)
		if falsa == garagem:
			falsa = (falsa + 1) % vaos if vaos > 1 else -1
	for k in vaos:
		var deslocamento := (float(k) - float(vaos - 1) * 0.5) * passo
		var meio := frente + lateral * deslocamento

		# A porta manda no vao. Painel nenhum encosta na faixa dela, senao a
		# folha abre para dentro de uma janela — ou pior, some atras de um
		# portao de garagem, que foi o defeito que este arquivo veio corrigir.
		if tem_porta and absf(deslocamento - porta_local) < passo * 0.5 + MEIA_PORTA:
			continue

		if k == falsa:
			_porta_fechada(sup, meio, direcao, giro, lateral, normal, rng)
			info["porta"] = deslocamento
			continue

		if k == garagem:
			_garagem(sup, meio, passo, direcao, giro)
			# Quem monta a quadra poe a rampa na sarjeta em frente a ele
			# (DetalheCalcada.guia_rebaixada): daqui nao se sabe onde fica o
			# meio-fio.
			garagens.append(deslocamento)
			continue

		_janela_terrea(sup, meio, passo, direcao, giro, lateral, normal, rng,
			prob_janela_acesa, estilo)

	if tem_porta:
		_entrada(sup, frente + lateral * porta_local, direcao, giro, lateral, normal,
			vao_real)


## O vao da porta. A folha nao vem daqui: quem entra e a `Porta` interativa, que
## o chunk cria como prop. O que falta em volta dela e o que faz o buraco na
## parede parecer entrada de casa.
static func _entrada(sup: Dictionary, base: Vector3, direcao: int, giro: float,
		lateral: Vector3, normal: Vector3, vao_real: bool = false) -> void:
	var pe := Vector3(base.x, KitModular.ALTURA_MEIO_FIO, base.z)

	# Reentrancia: um painel mais claro no fundo do vao. E o que da profundidade
	# a porta numa fachada que e um plano so.
	#
	# Nao quando o vao e de verdade: este painel e EXATAMENTE a parede cinza que
	# aparecia quando a porta abria. Atras dela agora ha a casa.
	if not vao_real:
		KitModular.parede(sup, &"reboco", pe + normal * 0.01 + Vector3(0.0, 1.10, 0.0),
			Vector2(1.55, 2.24), direcao, Color("9a9184"))

	# Batente em tres pecas.
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"tabua",
			pe + lateral * (lado * 0.66) + normal * 0.06 + Vector3(0.0, 1.05, 0.0),
			Vector3(0.14, 2.14, 0.14), CINZA_BATENTE, giro)
	KitModular.caixa_cor(sup, &"tabua",
		pe + normal * 0.06 + Vector3(0.0, 2.19, 0.0),
		Vector3(1.46, 0.14, 0.14), CINZA_BATENTE, giro)

	# Degrau. Porta que nasce rente a calcada le como porta de container.
	KitModular.caixa_cor(sup, &"concreto",
		Vector3(base.x, KitModular.ALTURA_MEIO_FIO * 0.5, base.z) + normal * 0.36,
		Vector3(1.7, KitModular.ALTURA_MEIO_FIO, 0.72), PEDRA, giro)

	# Numero da casa e caixa de correio: os dois objetos que dizem "alguem mora
	# aqui" sem custar mais um triangulo de arquitetura.
	# Azulejo, e nao `letreiro`: o numero da casa e ceramica, e o material de
	# letreiro de loja emite a 2,2 — no MODERNO a placa estourava num retangulo
	# rosa ao lado da porta.
	KitModular.placa(sup, &"azulejo",
		pe + lateral * 0.98 + normal * 0.08 + Vector3(0.0, 1.78, 0.0),
		Vector2(0.26, 0.16), giro, Color("d8d2be"))
	# Marquise curta sobre a porta. Sombra na soleira, e a silhueta da fachada
	# deixa de ser uma linha reta.
	KitModular.caixa_cor(sup, &"concreto",
		pe + normal * 0.30 + Vector3(0.0, 2.40, 0.0),
		Vector3(2.0, 0.11, 0.66), Color("b9b2a2"), giro)


## Porta de madeira fechada, com batente, degrau e numero. A casa que nao e a
## porta interativa do chunk ainda precisa de uma entrada que se leia da rua.
static func _porta_fechada(sup: Dictionary, meio: Vector3, direcao: int, giro: float,
		lateral: Vector3, normal: Vector3, rng: RandomNumberGenerator) -> void:
	var pe := Vector3(meio.x, KitModular.ALTURA_MEIO_FIO, meio.z)
	const MADEIRAS: Array[Color] = [Color("7a5a3a"), Color("5e4630"), Color("8a6a48"),
		Color("4f5a4a"), Color("6a3f30")]
	KitModular.parede(sup, &"porta", pe + normal * 0.05 + Vector3(0.0, 1.05, 0.0),
		Vector2(0.95, 2.1), direcao, MADEIRAS[rng.randi() % MADEIRAS.size()])
	for lado: float in [-1.0, 1.0]:
		KitModular.placa(sup, &"tabua",
			pe + lateral * (lado * 0.55) + normal * 0.07 + Vector3(0.0, 1.07, 0.0),
			Vector2(0.12, 2.18), giro, CINZA_BATENTE)
	KitModular.placa(sup, &"tabua", pe + normal * 0.07 + Vector3(0.0, 2.17, 0.0),
		Vector2(1.22, 0.12), giro, CINZA_BATENTE)
	# Degrau ACIMA da calcada, e nao rente a ela: rente, o topo dele e o piso
	# disputam o mesmo plano e o degrau some.
	KitModular.caixa_cor(sup, &"concreto",
		Vector3(meio.x, KitModular.ALTURA_MEIO_FIO * 1.5, meio.z) + normal * 0.3,
		Vector3(1.3, KitModular.ALTURA_MEIO_FIO, 0.55), PEDRA, giro)
	KitModular.placa(sup, &"azulejo",
		pe + lateral * 0.8 + normal * 0.08 + Vector3(0.0, 1.72, 0.0),
		Vector2(0.22, 0.14), giro, Color("d8d2be"))


## Janela de casa: vidro, moldura, peitoril e grade. A grade nao e enfeite — e o
## que diferencia a janela de uma casa habitada de um vao de galpao.
static func _janela_terrea(sup: Dictionary, meio: Vector3, passo: float,
		direcao: int, giro: float, lateral: Vector3, normal: Vector3,
		rng: RandomNumberGenerator, prob_janela_acesa: float,
		estilo: int = 0) -> void:
	var larg := minf(1.5 if estilo != 2 else 1.25, passo * 0.62)
	var alt := 1.15 if estilo != 2 else 1.28
	var y := 1.30

	var mat: StringName = &"janela_acesa" if rng.randf() < prob_janela_acesa \
		else &"janela_apagada"
	# O vidro vai A FRENTE da moldura, e nao atras: a moldura e uma placa opaca
	# maior que a janela, entao na ordem inversa ela simplesmente tapa o vidro.
	KitModular.parede(sup, mat, meio + normal * 0.055 + Vector3(0.0, y, 0.0),
		Vector2(larg, alt), direcao)

	# Moldura em PLACA, e nao em caixa. A caixa custa doze triangulos por peca e
	# a moldura tem tres: trinta e seis triangulos por janela, vezes nove vaos no
	# pior chunk, foi metade do que estourou o teto de 6000 do criterio da
	# cidade. Do angulo em que a rua e vista a placa da a mesma linha clara.
	KitModular.parede(sup, &"concreto", meio + normal * 0.02 + Vector3(0.0, y, 0.0),
		Vector2(larg + 0.22, alt + 0.20), direcao, PEDRA.darkened(0.10))

	# O peitoril continua sendo caixa: e a unica peca da janela que tem volume
	# de verdade contra a luz do poste, e uma placa no lugar dela apaga a sombra
	# que a janela desenha na parede.
	KitModular.caixa_cor(sup, &"concreto",
		meio + normal * 0.11 + Vector3(0.0, y - alt * 0.5 - 0.05, 0.0),
		Vector3(larg + 0.32, 0.10, 0.28), PEDRA, giro)

	_grade(sup, meio + Vector3(0.0, y, 0.0), Vector2(larg, alt), giro, lateral,
		normal)
	if estilo == 2:
		KitPredio.veneziana(sup, meio + Vector3(0.0, y, 0.0), Vector2(larg, alt),
			giro, lateral, normal)


## Grade de janela em placas verticais.
##
## `KitPredio.grade` faz barra a cada 28 cm com uma CAIXA por barra: numa janela
## de 1,5 m sao cinco caixas, sessenta triangulos, so de grade. Aqui a barra e
## uma placa de dois triangulos e o espacamento e maior, entao a grade inteira
## custa oito. A 480x270 com dither por cima, a barra chata e a barra com volume
## dao o mesmo pixel — o que se le e o ritmo vertical, e nao a espessura.
static func _grade(sup: Dictionary, centro: Vector3, tamanho: Vector2,
		giro: float, lateral: Vector3, normal: Vector3) -> void:
	var n := maxi(3, int(tamanho.x / 0.42))
	for i in n:
		var t := (float(i) + 0.5) / float(n) - 0.5
		KitModular.placa(sup, &"metal",
			centro + normal * 0.07 + lateral * (t * tamanho.x),
			Vector2(0.04, tamanho.y), giro, Color("3e4042"))


## Portao de garagem. Continua sendo metal ondulado — o material nunca foi o
## erro; o erro era ele ser a fachada inteira.
static func _garagem(sup: Dictionary, meio: Vector3, passo: float,
		direcao: int, giro: float) -> void:
	var larg := minf(2.4, passo * 0.86)
	KitModular.parede(sup, &"metal_ondulado",
		meio + Vector3(0.0, 1.12, 0.0), Vector2(larg, 2.05), direcao)
	# Verga de concreto em cima: portao rente ao reboco le como remendo.
	KitModular.caixa_cor(sup, &"concreto",
		meio + Vector3(0.0, 2.24, 0.0), Vector3(larg + 0.26, 0.16, 0.17),
		PEDRA, giro)


## Faixa horizontal separando um pavimento do outro.
static func _pingadeira(sup: Dictionary, frente: Vector3, largura: float,
		giro: float, andares: int, cor: Color) -> void:
	for andar in range(1, andares):
		KitModular.caixa_cor(sup, &"concreto",
			frente + Vector3(0.0, float(andar) * KitModular.ALTURA_ANDAR, 0.0),
			Vector3(largura, 0.13, 0.19), cor.darkened(0.18), giro)


## Janelas dos andares de cima, com peitoril. Mesma janela do terreo sem grade:
## ladrao nao sobe tres metros, e grade em todo andar le como presidio.
static func _andares(sup: Dictionary, frente: Vector3, largura: float,
		direcao: int, giro: float, lateral: Vector3, andares: int,
		rng: RandomNumberGenerator, prob_janela_acesa: float,
		estilo: int = 0) -> void:
	var n := maxi(1, int(largura / 2.8))
	var passo := largura / float(n)
	var ar_ja := false
	for andar in range(1, andares):
		var y := float(andar) * KitModular.ALTURA_ANDAR + 1.45
		for j in n:
			var meio := frente + lateral * ((float(j) - float(n - 1) * 0.5) * passo)
			var larg_j := 1.05 if estilo == 2 else 1.2
			KitModular.parede(sup,
				&"janela_acesa" if rng.randf() < prob_janela_acesa
					else &"janela_apagada",
				meio + Vector3(0.0, y, 0.0), Vector2(larg_j, 1.25), direcao)
			# Placa, e nao caixa: sao ate nove peitoris por trecho contando os
			# andares, e ninguem olha para o peitoril do terceiro andar de baixo.
			# O do terreo continua sendo caixa, que e o que o pedestre ve.
			KitModular.parede(sup, &"concreto",
				meio + Vector3(0.0, y - 0.70, 0.0),
				Vector2(1.5, 0.12), direcao, PEDRA)
			if estilo == 2:
				var normal := KitModular._normal(direcao)
				KitPredio.veneziana(sup, meio + Vector3(0.0, y, 0.0),
					Vector2(larg_j, 1.25), giro, lateral, normal)
			# Um ar por predio. Dois na mesma fachada leem como padrao, nao como
			# aparelho que alguem instalou.
			if not ar_ja and (estilo == 3 or rng.randf() < 0.28):
				var normal_ar := KitModular._normal(direcao)
				KitPredio.ar_condicionado(sup,
					meio + normal_ar * 0.22 + Vector3(0.0, y - 0.95, 0.0), giro)
				ar_ja = true
