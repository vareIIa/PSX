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
		cor: Color = Color.WHITE, porta_local: float = NAN) -> bool:
	var altura := andares * KitModular.ALTURA_ANDAR
	var normal := KitModular._normal(direcao)
	var lateral := KitModular._lateral(direcao)
	var giro := atan2(normal.x, normal.z)

	KitModular.parede(sup, material, centro + Vector3(0.0, altura * 0.5, 0.0),
		Vector2(largura, altura), direcao, cor)

	var frente := centro + normal * 0.06

	_embasamento(sup, frente, largura, direcao, cor)
	_terreo(sup, frente, largura, direcao, giro, lateral, normal, rng,
		prob_janela_acesa, porta_local)
	_pingadeira(sup, frente, largura, giro, andares, cor)
	_andares(sup, frente, largura, direcao, giro, lateral, andares, rng,
		prob_janela_acesa)
	return false


## Faixa de material diferente rente ao chao, com uma pingadeira em cima. Sai a
## frente do resto da parede: encostada, os dois planos disputam o pixel e a
## faixa inteira pisca a vinte metros.
static func _embasamento(sup: Dictionary, frente: Vector3, largura: float,
		direcao: int, cor: Color) -> void:
	var normal := KitModular._normal(direcao)
	KitModular.parede(sup, &"tijolo",
		frente + normal * 0.02 + Vector3(0.0, EMBASAMENTO * 0.5, 0.0),
		Vector2(largura, EMBASAMENTO), direcao, cor.darkened(0.30))
	KitModular.caixa_cor(sup, &"concreto",
		frente + normal * 0.05 + Vector3(0.0, EMBASAMENTO, 0.0),
		Vector3(largura, 0.08, 0.14), PEDRA, atan2(normal.x, normal.z))


## O terreo, vao a vao. Cada vao vira porta, janela ou portao de garagem.
static func _terreo(sup: Dictionary, frente: Vector3, largura: float,
		direcao: int, giro: float, lateral: Vector3, normal: Vector3,
		rng: RandomNumberGenerator, prob_janela_acesa: float,
		porta_local: float) -> void:
	var vaos := maxi(1, int(round(largura / PASSO_VAO)))
	var passo := largura / float(vaos)

	# A garagem entra no maximo uma vez por trecho. E o unico lugar onde o metal
	# ondulado ainda faz sentido numa rua de casas.
	var garagem := -1
	if passo > 2.6 and rng.randf() < 0.45:
		garagem = rng.randi_range(0, vaos - 1)

	var tem_porta := is_finite(porta_local)
	for k in vaos:
		var deslocamento := (float(k) - float(vaos - 1) * 0.5) * passo
		var meio := frente + lateral * deslocamento

		# A porta manda no vao. Painel nenhum encosta na faixa dela, senao a
		# folha abre para dentro de uma janela — ou pior, some atras de um
		# portao de garagem, que foi o defeito que este arquivo veio corrigir.
		if tem_porta and absf(deslocamento - porta_local) < passo * 0.5 + MEIA_PORTA:
			continue

		if k == garagem:
			_garagem(sup, meio, passo, direcao, giro)
			continue

		_janela_terrea(sup, meio, passo, direcao, giro, lateral, normal, rng,
			prob_janela_acesa)

	if tem_porta:
		_entrada(sup, frente + lateral * porta_local, direcao, giro, lateral, normal)


## O vao da porta. A folha nao vem daqui: quem entra e a `Porta` interativa, que
## o chunk cria como prop. O que falta em volta dela e o que faz o buraco na
## parede parecer entrada de casa.
static func _entrada(sup: Dictionary, base: Vector3, direcao: int, giro: float,
		lateral: Vector3, normal: Vector3) -> void:
	var pe := Vector3(base.x, KitModular.ALTURA_MEIO_FIO, base.z)

	# Reentrancia: um painel mais claro no fundo do vao. E o que da profundidade
	# a porta numa fachada que e um plano so.
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
	KitModular.placa(sup, &"letreiro",
		pe + lateral * 0.98 + normal * 0.08 + Vector3(0.0, 1.78, 0.0),
		Vector2(0.26, 0.16), giro, Color("d8d2be"))
	KitModular.caixa_cor(sup, &"metal",
		pe + lateral * 0.98 + normal * 0.12 + Vector3(0.0, 1.22, 0.0),
		Vector3(0.24, 0.17, 0.13), Color("6a6257"), giro)

	# Marquise curta sobre a porta. Sombra na soleira, e a silhueta da fachada
	# deixa de ser uma linha reta.
	KitModular.caixa_cor(sup, &"concreto",
		pe + normal * 0.30 + Vector3(0.0, 2.40, 0.0),
		Vector3(2.0, 0.11, 0.66), Color("b9b2a2"), giro)


## Janela de casa: vidro, moldura, peitoril e grade. A grade nao e enfeite — e o
## que diferencia a janela de uma casa habitada de um vao de galpao.
static func _janela_terrea(sup: Dictionary, meio: Vector3, passo: float,
		direcao: int, giro: float, lateral: Vector3, normal: Vector3,
		rng: RandomNumberGenerator, prob_janela_acesa: float) -> void:
	var larg := minf(1.5, passo * 0.62)
	var alt := 1.15
	var y := 1.30

	var mat: StringName = &"janela_acesa" if rng.randf() < prob_janela_acesa \
		else &"janela_apagada"
	KitModular.parede(sup, mat, meio + normal * 0.01 + Vector3(0.0, y, 0.0),
		Vector2(larg, alt), direcao)

	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"concreto",
			meio + lateral * (lado * (larg * 0.5 + 0.06)) + normal * 0.04
				+ Vector3(0.0, y, 0.0),
			Vector3(0.11, alt + 0.18, 0.11), PEDRA, giro)
	KitModular.caixa_cor(sup, &"concreto",
		meio + normal * 0.04 + Vector3(0.0, y + alt * 0.5 + 0.06, 0.0),
		Vector3(larg + 0.22, 0.11, 0.11), PEDRA, giro)

	# Peitoril, mais grosso que a moldura e saindo mais: e a peca que pega a luz
	# do poste e desenha a sombra da janela na parede.
	KitModular.caixa_cor(sup, &"concreto",
		meio + normal * 0.11 + Vector3(0.0, y - alt * 0.5 - 0.05, 0.0),
		Vector3(larg + 0.32, 0.10, 0.28), PEDRA, giro)

	KitPredio.grade(sup, meio + Vector3(0.0, y, 0.0), Vector2(larg, alt), direcao)


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
		rng: RandomNumberGenerator, prob_janela_acesa: float) -> void:
	var n := maxi(1, int(largura / 2.8))
	var passo := largura / float(n)
	for andar in range(1, andares):
		var y := float(andar) * KitModular.ALTURA_ANDAR + 1.45
		for j in n:
			var meio := frente + lateral * ((float(j) - float(n - 1) * 0.5) * passo)
			KitModular.parede(sup,
				&"janela_acesa" if rng.randf() < prob_janela_acesa
					else &"janela_apagada",
				meio + Vector3(0.0, y, 0.0), Vector2(1.2, 1.25), direcao)
			KitModular.caixa_cor(sup, &"concreto",
				meio + Vector3(0.0, y - 0.70, 0.0),
				Vector3(1.5, 0.10, 0.23), PEDRA, giro)
