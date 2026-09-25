## Pecas de parque, em dados brutos, no mesmo contrato do resto do kit.
##
## Vegetacao no estilo PS1
## -----------------------
## Arvore de PS1 nao e um modelo de arvore: e um tronco de caixa e um punhado de
## blocos de folha empilhados torto, com uma textura ruidosa por cima. O que da a
## leitura nao e a forma da folha, e a silhueta irregular contra a nevoa. Por isso
## nada aqui tem mais que meia duzia de volumes, e todos entram com `max_quad`
## folgado: uma copa de 2,5 m subdividida na grade padrao custa quatro vezes mais
## triangulos e a subdivisao nao aparece, porque a textura ja e ruido.
##
## Orcamento medido: 96 triangulos por arvore, 24 por arbusto. Dezoito arvores e
## uma duzia de arbustos por chunk cabem em 2200, que e um terco do teto.
##
## O vento
## -------
## Nada aqui e animado por script. O balanco vive no psx_surface.gdshader e le a
## rigidez do alfa do vertice: 0 nao sai do lugar, 1 balanca inteiro. Como as
## folhagens do chunk sao fundidas numa malha so, e a posicao de mundo que gera a
## fase, e duas arvores vizinhas entram fora de fase sozinhas.
class_name KitParque
extends RefCounted

## Subdivisao folgada da vegetacao. Ver o comentario de orcamento acima.
const QUAD_FOLHA := 4.0

## Faces de peca ENCOSTADA numa parede: todas menos a de tras, que fica colada
## no reboco e nunca aparece. Marco de porta, folha, peitoril, cunhal — sao
## dezenas por casa, e cada face que ninguem ve sao dois triangulos a menos num
## chunk que ja passa do teto. Vale so para peca girada com o `giro` da parede,
## em que o -Z local e a propria parede.
const SEM_COSTA := PSXMesh.FACE_TODAS & ~PSXMesh.FACE_TRAS

## Rigidez maxima da copa. Acima disto a arvore comeca a arrastar a base do
## tronco junto e le como gelatina, nao como galho.
const CEDE_COPA := 1.0
const CEDE_TRONCO := 0.14

const ALTURA_BANCO := 0.44
const ALTURA_CERCA := 0.95

## Empilhamento do chao do parque, em metros.
##
## Os planos do parque sao coplanares em espirito, e nao podem ser em numero. Com
## 5 mm entre eles — que era o valor da primeira versao — a 45 m de distancia a
## precisao do buffer de profundidade ja chega perto de 2 mm, os dois planos
## passam a disputar o mesmo pixel e o chao pisca a cada passo do jogador. Foi
## exatamente o defeito reportado na calcada da praca.
##
## Dois centimetros entre camadas resolve com folga em todo o alcance de desenho,
## e o degrau que sobra le como o que e: placa assentada sobre a terra.
##
## A ordem tambem importa e ja estava errada: a areia da quadra ficava em 0,03,
## treze centimetros ABAIXO da grama, e a quadra inteira nascia enterrada.
const Y_GRAMA := 0.16
const Y_TERRA := 0.18
const Y_AREIA := 0.20
const Y_CALCAMENTO := 0.22
## Terra do canteiro de praca: acima de todo piso, abaixo da borda do murete.
const Y_CANTEIRO := 0.28

## Verdes da copa. Todos rebaixados: folha noturna sob sodio nao e verde de dia,
## e um verde vivo aqui puxa mais o olho que a loja acesa do outro lado da rua.
const VERDES: Array[Color] = [
	Color("6f7d55"), Color("5d6b48"), Color("7a8459"), Color("55613f"),
	Color("68764e"), Color("7f8a62"),
]
## Copa de arvore morta ou de outono. Uma em cada seis, para o parque nao ser um
## tapete verde uniforme.
const SECOS: Array[Color] = [
	Color("8a7448"), Color("796138"), Color("6d5c3d"),
]


# --- vegetacao --------------------------------------------------------------

## Proporcoes da copa, em fracao do raio dela.
##
## A REGRA, e nao os numeros: o nucleo opaco tem de ser MENOR que o menor bloco
## externo. Quem desenha a silhueta e o recorte por alfa dos blocos de fora; um
## nucleo maior que eles vira ele proprio o contorno, e como e opaco, a arvore
## le como laje verde por mais irregulares que sejam os outros. Foi assim que as
## arvores do parque passaram meses parecendo caixas com o recorte ja
## implementado e funcionando.
const COPA_NUCLEO := 0.82
const COPA_BLOCO_MIN := 1.05
const COPA_BLOCO_MAX := 1.5

## Arvore de folha larga. `porte` de 0 a 1 escala altura e copa juntas.
##
## Devolve o raio da copa, que quem chama usa para nao encostar duas arvores.
static func arvore(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		porte: float, rng: RandomNumberGenerator, seca: bool = false) -> float:
	# A de esqueleto (PLANO_FLORA_AAA, V2) gasta o mesmo sorteio, devolve o
	# mesmo raio e a mesma colisao; `--arvore-caixa` volta esta aqui.
	if ArvoreEsqueleto.ativo:
		return ArvoreEsqueleto.de_parque(sup, colisao, base, porte, rng, seca)
	var altura := lerpf(4.6, 8.4, porte)
	var raio_copa := lerpf(1.5, 2.6, porte)
	var tronco := lerpf(0.28, 0.44, porte)

	var cor_casca := Color(1.0, 1.0, 1.0).lerp(Color("8a7a66"), rng.randf_range(0.2, 0.8))
	# Fuste curto e copa alta. Meio a meio deixava a copa espremida num metro e
	# meio de altura, e o que saia era uma laje de folha sobre um pau — o
	# defeito classico de arvore de caixa. Com 40% de fuste a copa tem tres a
	# cinco metros para se espalhar e a silhueta fecha.
	var altura_fuste := altura * 0.40

	# Fuste em duas secoes, a de cima mais fina e levemente torta. Um cilindro
	# reto le como poste; a quebra no meio e o que faz virar tronco.
	var giro := rng.randf_range(0.0, TAU)
	KitModular.caixa_flex(sup, &"casca",
		base + Vector3(0.0, altura_fuste * 0.28, 0.0),
		Vector3(tronco, altura_fuste * 0.56, tronco), cor_casca, giro,
		base.y, base.y + altura, 0.0, CEDE_TRONCO, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	var desvio := Vector3(rng.randf_range(-0.22, 0.22), 0.0, rng.randf_range(-0.22, 0.22))
	KitModular.caixa_flex(sup, &"casca",
		base + desvio * 0.5 + Vector3(0.0, altura_fuste * 0.78, 0.0),
		Vector3(tronco * 0.78, altura_fuste * 0.56, tronco * 0.78),
		cor_casca, giro + 0.6,
		base.y, base.y + altura, 0.0, CEDE_TRONCO, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	var topo_fuste := base + desvio + Vector3(0.0, altura_fuste, 0.0)
	var paleta := SECOS if seca else VERDES
	var cor_base := paleta[rng.randi() % paleta.size()]

	# Copa: seis a oito blocos em espiral em volta do eixo. O afunilamento e o que
	# faz a copa ter forma: sem ele os blocos ficam todos na mesma largura e o
	# conjunto le como caixote. Com ele o meio e largo, o topo e a base sao
	# estreitos, e a silhueta contra a nevoa vira uma copa.
	var vao_copa := altura - altura_fuste

	# Nucleo: um bloco cheio no meio da copa, antes dos outros. Sem ele os blocos
	# externos ficam soltos em volta do tronco e, vistos de perto sob a luz do
	# poste, leem como tabuas penduradas — foi exatamente o que a captura do
	# campo mostrou. O nucleo fecha o vazio e os outros viram o contorno dele.
	#
	# Ele precisa caber DENTRO dos blocos externos, e e aqui que a versao
	# anterior errava: o nucleo tinha 1,25 de raio_copa contra os 1,08 dos blocos
	# de fora. Sendo a maior peca da copa, o nucleo PASSOU A SER a silhueta — e
	# como ele e opaco, sem o recorte por alfa, a arvore lia como um retangulo de
	# folha por mais que os blocos externos tivessem contorno. A ampliacao a
	# 1280x720 mostrou as duas arvores do parque como lajes verdes.
	#
	# Escondido em 0,62, quem desenha o contorno passa a ser o recorte.
	KitModular.caixa_flex(sup, &"folhagem",
		topo_fuste + Vector3(0.0, vao_copa * 0.44, 0.0),
		Vector3(raio_copa * COPA_NUCLEO, vao_copa * 0.52, raio_copa * COPA_NUCLEO),
		cor_base, rng.randf_range(0.0, TAU),
		base.y, base.y + altura, CEDE_COPA * 0.5, CEDE_COPA * 0.9,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Mais blocos, e maiores que o nucleo. Sao eles que formam a copa agora.
	var n := rng.randi_range(9, 12)
	for i in n:
		var t := float(i) / float(n)
		var ang := t * TAU * 1.6 + rng.randf_range(-0.3, 0.3)
		var alto := lerpf(0.05, 0.95, t) + rng.randf_range(-0.08, 0.08)
		var afunila := clampf(1.0 - absf(alto - 0.44) * 1.35, 0.28, 1.0)
		# Distancia curta de proposito: os blocos tem de se atravessar. Copa e uma
		# massa unica com a borda irregular, nao um conjunto de pecas em orbita.
		# Espalhados um pouco mais e bem maiores. A copa e a UNIAO deles: com o
		# nucleo encolhido, um bloco estreito deixaria buraco entre um e outro.
		var dist := raio_copa * afunila * rng.randf_range(0.26, 0.62)
		var lado := raio_copa * afunila * rng.randf_range(COPA_BLOCO_MIN, COPA_BLOCO_MAX)
		var centro := topo_fuste + Vector3(cos(ang) * dist, vao_copa * alto,
			sin(ang) * dist)
		# Tom por bloco. Sem isso a copa e uma mancha chapada e o volume some.
		var cor := cor_base.lerp(Color.WHITE, rng.randf_range(-0.14, 0.16))
		cor.a = 1.0
		# Recorte por alfa nos blocos de fora. E o que tira a silhueta de caixa
		# da copa: o alfa da textura come o canto do bloco e o que resta contra o
		# ceu e contorno de folha. O nucleo continua opaco, entao a arvore nunca
		# fica vazada.
		KitModular.caixa_flex(sup, &"folhagem_recorte", centro,
			Vector3(lado, lado * rng.randf_range(0.72, 1.0), lado * rng.randf_range(0.85, 1.1)),
			cor, ang,
			base.y, base.y + altura, CEDE_COPA * 0.5, CEDE_COPA,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Um galho saindo de lado, so nas arvores grandes. E o detalhe que quebra a
	# silhueta de pirulito.
	if porte > 0.55:
		var ang_g := rng.randf_range(0.0, TAU)
		var eixo := Vector3(cos(ang_g), 0.0, sin(ang_g))
		var b := Basis(Vector3.UP, ang_g) * Basis(Vector3.FORWARD, 0.75)
		KitModular.caixa_flex_inclinada(sup, &"casca",
			topo_fuste + eixo * (raio_copa * 0.42) + Vector3(0.0, -0.35, 0.0),
			Vector3(0.16, raio_copa * 1.1, 0.16), cor_casca, b,
			base.y, base.y + altura, CEDE_TRONCO, CEDE_COPA * 0.7, QUAD_FOLHA)

	colisao.append({
		"tamanho": Vector3(tronco * 2.0, altura_fuste, tronco * 2.0),
		"pos": base + Vector3(0.0, altura_fuste * 0.5, 0.0),
	})
	return raio_copa


## Conifera. Silhueta oposta a da arvore larga, e e so por isso que ela existe:
## um parque com um tipo so de copa le como copiar e colar.
static func pinheiro(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		porte: float, rng: RandomNumberGenerator) -> float:
	# A tuia e a araucaria por esqueleto (rodada 3 do PLANO_FLORA_AAA), com o
	# mesmo sorteio gasto; `--arvore-caixa` volta as caixas.
	if ArvoreEsqueleto.ativo:
		return ArvoreEsqueleto.pinheiro_de_praca(sup, colisao, base, porte, rng)
	var altura := lerpf(5.0, 8.4, porte)
	var raio := lerpf(1.3, 2.1, porte)
	var tronco := 0.24

	KitModular.caixa_flex(sup, &"casca", base + Vector3(0.0, altura * 0.3, 0.0),
		Vector3(tronco, altura * 0.6, tronco), Color("8a7a66"),
		rng.randf_range(0.0, TAU),
		base.y, base.y + altura, 0.0, CEDE_TRONCO * 0.6,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	var cor := VERDES[rng.randi() % VERDES.size()].lerp(Color("3f4c33"), 0.35)
	cor.a = 1.0
	var camadas := 4
	for i in camadas:
		var t := float(i) / float(camadas - 1)
		var lado := raio * lerpf(1.0, 0.3, t) * 2.0
		var y := altura * lerpf(0.30, 0.98, t)
		# A saia de baixo e opaca e as de cima recortam. Assim a conifera fica
		# fechada na base, onde o tronco tem de sumir, e rendilhada no topo, onde
		# a silhueta encontra o ceu.
		KitModular.caixa_flex(sup,
			&"folhagem" if i == 0 else &"folhagem_recorte",
			base + Vector3(0.0, y, 0.0),
			Vector3(lado, altura * 0.2, lado),
			cor.lerp(Color.WHITE, t * 0.16), rng.randf_range(0.0, 0.8),
			base.y, base.y + altura,
			CEDE_COPA * 0.3, CEDE_COPA * 0.75,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	colisao.append({
		"tamanho": Vector3(0.7, altura * 0.6, 0.7),
		"pos": base + Vector3(0.0, altura * 0.3, 0.0),
	})
	return raio


## Palmeira-imperial: fuste liso e alto, palmito verde e a coroa de folhas.
##
## E a silhueta que as fotos 01, 03 e 05 poem atras da capela, e a que mais
## sobrevive de longe: nenhuma outra arvore da cidade tem doze metros de fuste
## sem galho. Contra a nevoa ela e um risco vertical com um tufo em cima, e isso
## continua legivel na distancia em que a copa larga ja virou mancha.
##
## Cada folha sao DOIS segmentos, o de dentro subindo e o de fora caindo. A dobra
## e o que faz folha de palmeira; um segmento reto so le como helice.
##
## O balanco e o do psx_surface, como o de toda a vegetacao: o fuste quase nao
## cede e a folha cede inteira. No segmento que cai a rigidez corre AO CONTRARIO
## da altura — a ponta fica mais baixa que a raiz, e e ela que tem de balancar.
static func palmeira(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		altura: float, rng: RandomNumberGenerator) -> void:
	# A imperial por esqueleto (PLANO_FLORA_AAA, V2): gasta o mesmo sorteio desta,
	# na mesma ordem, e a folha sai do rng proprio.
	if ArvoreEsqueleto.ativo:
		var r := RandomNumberGenerator.new()
		r.seed = hash([rng.state, roundi(base.x * 10.0), roundi(base.z * 10.0), 11])
		# casca, pe, tres secoes, verde, palmito, folha: oito.
		for k in 8:
			rng.randf()
		var n := rng.randi_range(9, 11)
		for k in n:
			for j in 5:
				rng.randf()
		var n_f := r.randi_range(13, 16)
		var folhas := PackedVector3Array()
		for k in n_f:
			var q := r.randf_range(-0.9, 0.35) if k % 3 != 0 else r.randf_range(0.4, 0.8)
			folhas.append(Vector3(TAU * float(k) / float(n_f) + r.randf_range(-0.2, 0.2), q,
				r.randf_range(-0.5, 0.5)))
		var descartavel: Array[Dictionary] = []
		ArvoreEsqueleto.palmeira(sup, descartavel, base, true, maxf(altura - 1.4, 3.0),
			r.randf_range(0.0, TAU), 0.0, folhas, r.randf_range(3.4, 4.2))
		colisao.append({"tamanho": Vector3(0.6, altura, 0.6),
			"pos": base + Vector3(0.0, altura * 0.5, 0.0)})
		return
	var casca := Color("c2bbab").lerp(Color("8f877a"), rng.randf_range(0.0, 0.45))
	var topo_y := base.y + altura
	# Pe dilatado. A imperial engrossa no chao, e sem isso o fuste le como poste
	# enfiado na grama.
	KitModular.caixa_flex(sup, &"casca", base + Vector3(0.0, 0.5, 0.0),
		Vector3(0.66, 1.0, 0.66), casca, rng.randf_range(0.0, TAU),
		base.y, topo_y, 0.0, CEDE_TRONCO, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	const SECOES := 3
	var trecho := (altura - 0.9) / float(SECOES)
	for i in SECOES:
		var t := float(i) / float(SECOES - 1)
		var grosso := lerpf(0.50, 0.36, t)
		KitModular.caixa_flex(sup, &"casca",
			base + Vector3(0.0, 0.9 + trecho * (float(i) + 0.5), 0.0),
			Vector3(grosso, trecho + 0.06, grosso), casca, rng.randf_range(0.0, TAU),
			base.y, topo_y, 0.0, CEDE_TRONCO, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Palmito: o cilindro verde liso entre o fuste e as folhas. E o que separa a
	# imperial do coqueiro, e a foto 03 mostra ele claro contra a copa.
	var verde := Color("67764a").lerp(Color("4d5a38"), rng.randf_range(0.0, 0.5))
	KitModular.caixa_flex(sup, &"folhagem", Vector3(base.x, topo_y + 0.7, base.z),
		Vector3(0.44, 1.4, 0.44), verde, rng.randf_range(0.0, TAU),
		base.y, topo_y + 1.4, 0.0, CEDE_TRONCO * 1.4,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	var coroa := Vector3(base.x, topo_y + 1.35, base.z)
	var folha := Color("58663d").lerp(Color("6f7a48"), rng.randf_range(0.0, 0.6))
	var n := rng.randi_range(9, 11)
	for k in n:
		var ang := TAU * float(k) / float(n) + rng.randf_range(-0.2, 0.2)
		var sobe := rng.randf_range(0.35, 0.8)
		var cai := rng.randf_range(-0.95, -0.45)
		var l1 := rng.randf_range(1.9, 2.4)
		var l2 := rng.randf_range(1.7, 2.2)
		var d1 := Vector3(cos(sobe) * sin(ang), sin(sobe), cos(sobe) * cos(ang))
		var d2 := Vector3(cos(cai) * sin(ang), sin(cai), cos(cai) * cos(ang))
		# A caixa nasce de pe (comprimento em Y). Tombar em X leva o Y para a
		# elevacao da folha; girar em Y leva para o rumo dela.
		var b1 := Basis(Vector3.UP, ang) * Basis(Vector3.RIGHT, PI * 0.5 - sobe)
		var b2 := Basis(Vector3.UP, ang) * Basis(Vector3.RIGHT, PI * 0.5 - cai)
		KitModular.caixa_flex_inclinada(sup, &"folhagem_recorte",
			coroa + d1 * (l1 * 0.5), Vector3(0.62, l1, 0.05), folha, b1,
			coroa.y, coroa.y + 1.8, 0.15, 0.6, QUAD_FOLHA)
		var joelho := coroa + d1 * l1
		KitModular.caixa_flex_inclinada(sup, &"folhagem_recorte",
			joelho + d2 * (l2 * 0.5), Vector3(0.52, l2, 0.05),
			folha.lerp(Color.WHITE, 0.06), b2,
			coroa.y - 0.8, coroa.y + 1.8, 1.0, 0.6, QUAD_FOLHA)
	colisao.append({"tamanho": Vector3(0.6, altura, 0.6),
		"pos": base + Vector3(0.0, altura * 0.5, 0.0)})


## Arbusto: dois ou tres blocos baixos. Preenche o chao entre as arvores, que e
## onde o parque costuma ficar vazio demais.
static func arbusto(sup: Dictionary, base: Vector3, raio: float,
		rng: RandomNumberGenerator) -> void:
	# Moita de cartao (PLANO_FLORA_AAA, etapa 3), mesmo sorteio desta.
	if ArvoreEsqueleto.ativo:
		ArvoreEsqueleto.arbusto_de_parque(sup, base, raio, rng)
		return
	var cor := VERDES[rng.randi() % VERDES.size()].lerp(Color("46512f"), 0.25)
	cor.a = 1.0
	for i in rng.randi_range(2, 3):
		var ang := rng.randf_range(0.0, TAU)
		var d := raio * rng.randf_range(0.0, 0.4)
		var lado := raio * rng.randf_range(0.75, 1.2)
		KitModular.caixa_flex(sup, &"arbusto",
			base + Vector3(cos(ang) * d, lado * 0.34, sin(ang) * d),
			Vector3(lado, lado * 0.68, lado * rng.randf_range(0.8, 1.1)),
			cor.lerp(Color.WHITE, float(i) * 0.07), ang,
			base.y, base.y + raio, 0.1, 0.55,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)


## Sebe continua entre dois pontos. Fecha o parque sem virar muro.
static func sebe(sup: Dictionary, colisao: Array[Dictionary],
		a: Vector3, b: Vector3, rng: RandomNumberGenerator) -> void:
	var delta := b - a
	var comp := delta.length()
	if comp < 0.6:
		return
	var dir := delta / comp
	var giro := atan2(dir.x, dir.z)
	var passo := 1.6
	var n := maxi(1, int(comp / passo))
	var trechos := PackedVector3Array()
	var semente := hash([rng.state, roundi(a.x * 10.0), roundi(a.z * 10.0)])
	for i in n:
		var t := (float(i) + 0.5) / float(n)
		var centro := a + dir * (comp * t)
		var alt := rng.randf_range(0.85, 1.12)
		var cor := VERDES[rng.randi() % VERDES.size()].lerp(Color("3d4a2c"), 0.3)
		cor.a = 1.0
		var larg := rng.randf_range(0.72, 0.95)
		KitModular.caixa_flex(sup, &"arbusto",
			centro + Vector3(0.0, alt * 0.5, 0.0),
			Vector3(larg, alt, comp / float(n) + 0.12),
			cor, giro, a.y, a.y + alt, 0.08, 0.42,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		trechos.append(Vector3(comp * t, alt, larg))
	if ArvoreEsqueleto.ativo:
		ArvoreEsqueleto.franja_de_sebe(sup, a, dir, trechos, semente)
	colisao.append({
		"tamanho": Vector3(absf(dir.x) * comp + 0.28, 1.0, absf(dir.z) * comp + 0.28),
		"pos": a + delta * 0.5 + Vector3(0.0, 0.5, 0.0),
	})


# --- piso -------------------------------------------------------------------

## Faixa de piso do parque, ja recortada pelo chunk que a desenha.
##
## O recorte e o que permite um parque de 160 m nascer de chunks montados em
## threads diferentes sem nenhum deles saber dos outros: cada um desenha a parte
## do retangulo que cai dentro dele.
static func piso(sup: Dictionary, material: StringName, retangulo: Rect2,
		altura: float, cor: Color = Color.WHITE) -> void:
	var corte := retangulo.intersection(Rect2(0.0, 0.0, KitModular.CHUNK, KitModular.CHUNK))
	if corte.size.x < 0.05 or corte.size.y < 0.05:
		return
	if not sup.has(material):
		sup[material] = PSXMesh.dados_vazios()
	var centro := Vector3(corte.position.x + corte.size.x * 0.5, altura,
		corte.position.y + corte.size.y * 0.5)
	PSXMesh.acumular_tingido(sup[material],
		PSXMesh.plane_dados(corte.size, PSXMesh.DEFAULT_UV_PER_M),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), centro), cor)


## Colisao do piso do parque, recortada pelo chunk. Topo em `altura`, igual
## a calcada (0,16 m), senao o jogador cai para o asfalto e nao sai do parque.
static func piso_solido(colisao: Array[Dictionary], retangulo: Rect2,
		altura: float) -> void:
	var corte := retangulo.intersection(Rect2(0.0, 0.0, KitModular.CHUNK, KitModular.CHUNK))
	if corte.size.x < 0.05 or corte.size.y < 0.05:
		return
	var esp := 0.24
	colisao.append({
		"tamanho": Vector3(corte.size.x, esp, corte.size.y),
		"pos": Vector3(corte.position.x + corte.size.x * 0.5, altura - esp * 0.5,
			corte.position.y + corte.size.y * 0.5),
	})


# --- mobiliario -------------------------------------------------------------

## Banco de praca: pes de concreto e reguas de madeira.
##
## Quem senta olha para +Z local, ou seja para onde `giro` leva o +Z: para
## virar o banco para um ponto, `giro = atan2(dx, dz)` do rumo ate ele. O encosto
## fica em -Z. Este comentario dizia o contrario, e foi seguido: bancos de costas
## para o caminho sao o erro classico aqui, e o comentario errado o produzia.
static func banco(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float, desgaste: float = 0.0) -> void:
	var madeira := Color("8a6a44").lerp(Color("5a4a38"), desgaste)
	var largura := 1.9

	for lado: float in [-1.0, 1.0]:
		var pe := centro + Vector3(cos(giro) * largura * 0.42 * lado, 0.0,
			-sin(giro) * largura * 0.42 * lado)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			pe + Vector3(0.0, ALTURA_BANCO * 0.5, 0.0),
			Vector3(0.12, ALTURA_BANCO, 0.52), Color("9a968c"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Assento em tres reguas com fresta entre elas. Uma chapa unica le como
	# banco de plastico de ponto de onibus, nao como banco de praca.
	for i in 3:
		var d := (float(i) - 1.0) * 0.17
		KitModular.caixa_cor(sup, &"tabua",
			centro + Vector3(sin(giro) * d, ALTURA_BANCO, cos(giro) * d),
			Vector3(largura, 0.06, 0.14), madeira, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Encosto inclinado para tras.
	for i in 2:
		var y := ALTURA_BANCO + 0.24 + float(i) * 0.18
		KitModular.caixa_cor(sup, &"tabua",
			centro + Vector3(sin(giro) * -0.2, y, cos(giro) * -0.2),
			Vector3(largura, 0.14, 0.06), madeira, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	KitModular.solido(colisao, centro + Vector3(0.0, 0.3, 0.0),
		Vector3(largura, 0.6, 0.55), giro)


## Poste baixo de parque, com globo em vez de braco. Devolve onde pendurar a luz.
static func poste_globo(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3) -> Vector3:
	const ALTURA := 3.6
	KitModular.caixa(sup, &"metal", base + Vector3(0.0, ALTURA * 0.5, 0.0),
		Vector3(0.14, ALTURA, 0.14), 0.0, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa(sup, &"metal", base + Vector3(0.0, 0.22, 0.0),
		Vector3(0.32, 0.44, 0.32), 0.0, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	var globo := base + Vector3(0.0, ALTURA + 0.22, 0.0)
	KitModular.caixa(sup, &"janela_acesa", globo, Vector3(0.46, 0.5, 0.46),
		PI * 0.25, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	colisao.append({"tamanho": Vector3(0.34, ALTURA, 0.34),
		"pos": base + Vector3(0.0, ALTURA * 0.5, 0.0)})
	return globo


## Lixeira de parque: cilindro aproximado por caixa girada, com aro no topo.
static func lixeira(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	KitModular.caixa_cor(sup, &"metal_enferrujado",
		base + Vector3(0.0, 0.34, 0.0), Vector3(0.46, 0.68, 0.46),
		Color("6d6a60"), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.70, 0.0),
		Vector3(0.52, 0.06, 0.52), Color("8c8880"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	colisao.append({"tamanho": Vector3(0.6, 0.72, 0.6),
		"pos": base + Vector3(0.0, 0.36, 0.0)})


## Gradil baixo entre dois pontos, com prumos. Fecha o parque da rua.
static func gradil(sup: Dictionary, colisao: Array[Dictionary],
		a: Vector3, b: Vector3) -> void:
	var delta := b - a
	var comp := delta.length()
	if comp < 0.4:
		return
	var dir := delta / comp
	var giro := atan2(dir.x, dir.z)
	var cor := Color("4a4e50")

	for altura: float in [0.35, ALTURA_CERCA - 0.06]:
		KitModular.caixa_cor(sup, &"metal", a + delta * 0.5 + Vector3(0.0, altura, 0.0),
			Vector3(0.05, 0.05, comp), cor, giro, PSXMesh.FACE_TODAS, 8.0)

	var n := maxi(2, int(comp / 1.4))
	for i in n + 1:
		var t := float(i) / float(n)
		KitModular.caixa_cor(sup, &"metal",
			a + delta * t + Vector3(0.0, ALTURA_CERCA * 0.5, 0.0),
			Vector3(0.06, ALTURA_CERCA, 0.06), cor, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# 12 cm de espessura. 20 cm por eixo (o antigo) comia o vao do portao
	# quando o trecho era curto, e o jogador nao saia da praca.
	var esp := 0.12
	colisao.append({
		"tamanho": Vector3(absf(dir.x) * comp + esp, ALTURA_CERCA,
			absf(dir.z) * comp + esp),
		"pos": a + delta * 0.5 + Vector3(0.0, ALTURA_CERCA * 0.5, 0.0),
	})


## Pilares do portao. O vao entre eles e o caminho; a placa fica NUM pilar,
## nunca no meio — placa no eixo era parede no unico lugar por onde se sai.
static func pilares_portao(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float, meia_vao: float) -> void:
	var lateral := Vector3(cos(giro), 0.0, -sin(giro))
	var pedra := Color("5c5a52")
	for lado: float in [-1.0, 1.0]:
		var p := centro + lateral * (meia_vao * lado)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			p + Vector3(0.0, 1.05, 0.0), Vector3(0.34, 2.1, 0.34), pedra, giro)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			p + Vector3(0.0, 2.16, 0.0), Vector3(0.46, 0.14, 0.46),
			Color("8a867c"), giro)
		KitModular.solido(colisao, p + Vector3(0.0, 1.05, 0.0),
			Vector3(0.34, 2.1, 0.34), giro)


# --- brinquedos e quadra ----------------------------------------------------

## Tinta de brinquedo de parquinho de bairro: velha, fosca, nunca aco novo.
##
## Os tons sao mais claros do que a tinta que se quer ver. Eles MULTIPLICAM a
## textura de metal, que ja e cinza medio, e a cidade e noturna: a primeira
## versao usava a cor final e o gira-gira saia preto, lendo como um buraco no
## meio da areia.
const AZUL_BRINQUEDO := Color("8fbcd6")
const VERMELHO_BRINQUEDO := Color("d4796a")
const AMARELO_BRINQUEDO := Color("e8c377")
const VERDE_BRINQUEDO := Color("9cc487")
const CANO := Color("c2beb4")

## Balanco de duas cadeiras.
##
## O quadro sao dois portais em A ligados por um travessao, e cada uma das tres
## linhas abaixo conserta um defeito que a captura do parquinho mostrou:
##
##   O travessao corre no EIXO DOS PORTAIS, `giro + PI/2`. Com `giro` ele nascia
##   atravessado de noventa graus, saindo de um portal para o vazio — era a
##   primeira coisa que se via ao chegar no parquinho e o motivo de o brinquedo
##   ler como quebrado.
##
##   A perna do A inclina PARA DENTRO, e por isso o sinal do angulo e negativo.
##   Com ele positivo o topo abria e os pes fechavam: um V equilibrado numa
##   ponta so, que e o oposto do que segura o balanco de pe.
##
##   A corrente prende nas PONTAS do assento, ao longo do travessao. Presa na
##   frente e atras, como estava, ela passava fora da tabua de 26 cm e o assento
##   aparecia solto entre dois fios.
##
## O balanco de leve nao e script: a corrente entra no material `corrente`, que
## verga com o vento do psx_surface, com rigidez 1 embaixo e 0 em cima — ela sai
## do travessao parada e chega no assento andando. Quem chama alinha o vao com o
## eixo dominante de VENTO_DIR, senao o assento vai de lado em vez de ir e voltar.
const BALANCO_ALTURA := 2.4
const BALANCO_VAO := 3.0
## Abertura da perna do A. Acima disto o portal come o vao do assento vizinho.
const BALANCO_INCLINA := 0.30

static func balanco(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float) -> void:
	# Ao longo do travessao e no sentido do balanco. Todo o resto sai destes dois.
	var eixo := Vector3(cos(giro), 0.0, -sin(giro))
	var frente := Vector3(sin(giro), 0.0, cos(giro))

	# A perna e mais comprida que a altura porque esta inclinada, e o pe abre
	# metade da projecao. Os dois numeros saem do mesmo angulo; sem isso o topo
	# do A nao encosta no travessao.
	var perna := BALANCO_ALTURA / cos(BALANCO_INCLINA)
	var abre := tan(BALANCO_INCLINA) * BALANCO_ALTURA * 0.5

	for lado: float in [-1.0, 1.0]:
		var px := centro + eixo * (BALANCO_VAO * 0.5 * lado)
		for inclina: float in [-1.0, 1.0]:
			var b := Basis(Vector3.UP, giro) \
				* Basis(Vector3.RIGHT, -BALANCO_INCLINA * inclina)
			KitModular.caixa_livre(sup, &"metal",
				px + Vector3(0.0, BALANCO_ALTURA * 0.5, 0.0) + frente * (abre * inclina),
				Vector3(0.1, perna, 0.1), b, CANO, QUAD_FOLHA)
		# Travessa da perna, a um terco da altura. E o que fecha o A: sem ela as
		# duas pernas leem como dois postes tortos que por acaso se encontram.
		var y_t := BALANCO_ALTURA * 0.34
		var vao_t := tan(BALANCO_INCLINA) * (BALANCO_ALTURA - y_t) * 2.0
		KitModular.caixa_cor(sup, &"metal", px + Vector3(0.0, y_t, 0.0),
			Vector3(0.07, 0.07, vao_t), CANO, giro, PSXMesh.FACE_TODAS, 8.0)

	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, BALANCO_ALTURA, 0.0),
		Vector3(0.11, 0.11, BALANCO_VAO + 0.3), CANO, giro + PI * 0.5,
		PSXMesh.FACE_TODAS, 8.0)

	var assento_y := 0.5
	for i in 2:
		var sob := centro + eixo * ((float(i) - 0.5) * BALANCO_VAO * 0.42)
		var cor_assento := VERMELHO_BRINQUEDO if i == 0 else AZUL_BRINQUEDO
		for corrente: float in [-0.19, 0.19]:
			KitModular.caixa_flex(sup, &"corrente",
				sob + eixo * corrente
					+ Vector3(0.0, (BALANCO_ALTURA + assento_y) * 0.5, 0.0),
				Vector3(0.035, BALANCO_ALTURA - assento_y, 0.035), Color("7c7a74"),
				giro, assento_y, BALANCO_ALTURA, 1.0, 0.0, PSXMesh.FACE_TODAS, 8.0)
		KitModular.caixa_flex(sup, &"corrente", sob + Vector3(0.0, assento_y, 0.0),
			Vector3(0.46, 0.07, 0.26), cor_assento, giro,
			assento_y, BALANCO_ALTURA, 1.0, 0.0, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# So os portais tem colisao. O assento anda, e uma caixa parada debaixo dele
	# seria uma parede invisivel no meio do vao.
	for lado: float in [-1.0, 1.0]:
		KitModular.solido(colisao,
			centro + eixo * (BALANCO_VAO * 0.5 * lado)
				+ Vector3(0.0, BALANCO_ALTURA * 0.5, 0.0),
			Vector3(0.24, BALANCO_ALTURA, abre * 2.0 + 0.2), giro)


## Escorregador: torre com guarda-corpo, rampa que encosta no chao e escada.
##
## A rampa antiga era solta no ar — comprimento chutado, topo furando a
## plataforma trinta centimetros acima dela e pe enterrado na areia. Aqui o
## comprimento SAI do angulo e da altura, entao ela comeca na borda da
## plataforma e termina no chao por construcao, em qualquer altura de torre.
const ESCORREGA_ALTO := 1.9
## Inclinacao da rampa. 35 graus: escorrega na leitura e ainda e piso andavel
## para o CharacterBody3D, que so trata como chao ate 45.
const ESCORREGA_ANG := 0.62
const ESCORREGA_LARGURA := 0.66

static func escorregador(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float) -> void:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var eixo := Vector3(cos(giro), 0.0, -sin(giro))
	var meia := 0.52

	# Torre: quatro pes e o piso.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"metal",
				centro + eixo * (meia * 0.86 * sx) + frente * (meia * 0.86 * sz)
					+ Vector3(0.0, ESCORREGA_ALTO * 0.5, 0.0),
				Vector3(0.09, ESCORREGA_ALTO, 0.09), CANO, giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, ESCORREGA_ALTO, 0.0),
		Vector3(meia * 2.0, 0.09, meia * 2.0), AZUL_BRINQUEDO, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Guarda-corpo nos dois lados e no fundo. E o que faz a torre ler como
	# brinquedo e nao como mesa alta.
	var y_guarda := ESCORREGA_ALTO + 0.52
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"metal",
			centro + eixo * (meia * sx) + Vector3(0.0, y_guarda, 0.0),
			Vector3(0.06, 0.06, meia * 2.0), CANO, giro, PSXMesh.FACE_TODAS, 8.0)
		for sz: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"metal",
				centro + eixo * (meia * sx) + frente * (meia * sz)
					+ Vector3(0.0, ESCORREGA_ALTO + 0.26, 0.0),
				Vector3(0.06, 0.52, 0.06), CANO, giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal",
		centro - frente * meia + Vector3(0.0, y_guarda, 0.0),
		Vector3(meia * 2.0, 0.06, 0.06), CANO, giro, PSXMesh.FACE_TODAS, 8.0)

	# A rampa. `comp` e a hipotenusa que fecha a altura com o angulo e `avanco` a
	# projecao dela no chao: saem do mesmo triangulo, e e por isso que ela encosta
	# nas duas pontas.
	var comp := ESCORREGA_ALTO / sin(ESCORREGA_ANG)
	var avanco := ESCORREGA_ALTO / tan(ESCORREGA_ANG)
	var base := Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, ESCORREGA_ANG - PI * 0.5)
	var meio_rampa := centro + frente * (meia + avanco * 0.5) \
		+ Vector3(0.0, ESCORREGA_ALTO * 0.5 + 0.06, 0.0)
	KitModular.caixa_livre(sup, &"metal", meio_rampa,
		Vector3(ESCORREGA_LARGURA, comp + 0.3, 0.08), base, Color("b9b5aa"),
		QUAD_FOLHA)
	# Borda dos dois lados. Sem ela a rampa e uma tabua inclinada; com ela vira
	# calha, que e a forma que se reconhece de longe.
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_livre(sup, &"metal",
			meio_rampa + eixo * (ESCORREGA_LARGURA * 0.5 * sx)
				+ Vector3(0.0, 0.09, 0.0),
			Vector3(0.08, comp + 0.3, 0.2), base, AMARELO_BRINQUEDO, QUAD_FOLHA)

	# Escada atras: dois montantes inclinados e os degraus entre eles.
	var recuo := 0.95
	var ang_escada := atan2(recuo, ESCORREGA_ALTO)
	var b_escada := Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, ang_escada)
	var comp_escada := sqrt(recuo * recuo + ESCORREGA_ALTO * ESCORREGA_ALTO)
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_livre(sup, &"metal",
			centro - frente * (meia + recuo * 0.5) + eixo * (meia * 0.8 * sx)
				+ Vector3(0.0, ESCORREGA_ALTO * 0.5, 0.0),
			Vector3(0.07, comp_escada, 0.07), b_escada, CANO, QUAD_FOLHA)
	var degraus := 4
	for i in degraus:
		var t := (float(i) + 0.6) / float(degraus)
		KitModular.caixa_cor(sup, &"metal",
			centro - frente * (meia + recuo * (1.0 - t))
				+ Vector3(0.0, ESCORREGA_ALTO * t, 0.0),
			Vector3(meia * 1.6, 0.06, 0.16), VERMELHO_BRINQUEDO, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Colisao: a torre em pe e a rampa inclinada de verdade. A rampa com caixa
	# reta viraria um degrau intransponivel na frente do brinquedo.
	KitModular.solido(colisao, centro + Vector3(0.0, ESCORREGA_ALTO * 0.5, 0.0),
		Vector3(meia * 2.0, ESCORREGA_ALTO, meia * 2.0), giro)
	colisao.append({
		"tamanho": Vector3(ESCORREGA_LARGURA + 0.16, 0.16, comp),
		"pos": meio_rampa,
		"giro": Vector3(-ESCORREGA_ANG * cos(giro), giro, ESCORREGA_ANG * sin(giro)),
	})


## Gangorra. Parada e torta: uma ponta no chao e a outra no alto e a pose em que
## gangorra de parquinho vazio passa a vida.
const GANGORRA_COMP := 3.2
const GANGORRA_PIVO := 0.52

static func gangorra(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float, cor: Color) -> void:
	var eixo := Vector3(cos(giro), 0.0, -sin(giro))
	var frente := Vector3(sin(giro), 0.0, cos(giro))

	KitModular.caixa_cor(sup, &"concreto_sujo",
		centro + Vector3(0.0, GANGORRA_PIVO * 0.5, 0.0),
		Vector3(0.5, GANGORRA_PIVO, 0.34), Color("9a968c"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	var ang := atan2(GANGORRA_PIVO * 0.8, GANGORRA_COMP * 0.5)
	var b := Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, -ang)
	KitModular.caixa_livre(sup, &"tabua",
		centro + Vector3(0.0, GANGORRA_PIVO + 0.06, 0.0),
		Vector3(0.3, 0.09, GANGORRA_COMP), b, cor, QUAD_FOLHA)

	# Assento e alca em cada ponta, na altura que a tabua tem ali.
	for lado: float in [-1.0, 1.0]:
		var dy := sin(ang) * GANGORRA_COMP * 0.42 * lado
		var p := centro + frente * (GANGORRA_COMP * 0.42 * lado) \
			+ Vector3(0.0, GANGORRA_PIVO + 0.1 + dy, 0.0)
		KitModular.caixa_cor(sup, &"tabua", p, Vector3(0.34, 0.07, 0.34), cor,
			giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
		var alca := p + frente * (0.36 * lado)
		KitModular.caixa_cor(sup, &"metal", alca + Vector3(0.0, 0.24, 0.0),
			Vector3(0.36, 0.05, 0.05), CANO, giro, PSXMesh.FACE_TODAS, 8.0)
		for sx: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"metal",
				alca + eixo * (0.16 * sx) + Vector3(0.0, 0.12, 0.0),
				Vector3(0.05, 0.24, 0.05), CANO, giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)

	KitModular.solido(colisao, centro + Vector3(0.0, GANGORRA_PIVO * 0.5, 0.0),
		Vector3(0.6, GANGORRA_PIVO, GANGORRA_COMP * 0.7), giro)


## Gira-gira: disco octogonal, mastro e quatro alcas.
##
## O octogono sai de duas caixas cruzadas a 45 graus, que e o truque de sempre —
## le como redondo, custa doze triangulos e nao pede malha propria.
static func gira_gira(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, raio: float) -> void:
	var altura := 0.42
	# O tampo e claro e as nervuras e que sao pintadas. Com o disco inteiro na
	# cor da tinta, visto de cima ele lia como um buraco escuro na areia — dois
	# metros e meio de mancha, a peca mais chamativa do parquinho pelo motivo
	# errado.
	for k in 2:
		KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, altura, 0.0),
			Vector3(raio * 2.0, 0.1, raio * 0.84), Color("c8c4b8"),
			PI * 0.5 * float(k), PSXMesh.FACE_TODAS, QUAD_FOLHA)
	for k in 2:
		KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, altura + 0.05, 0.0),
			Vector3(raio * 1.9, 0.04, 0.14), VERDE_BRINQUEDO,
			PI * 0.5 * float(k), PSXMesh.FACE_TODAS, 8.0)
	# Saia sob o disco, para ele nao ler como chapa flutuando.
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, altura * 0.5, 0.0),
		Vector3(raio * 1.1, altura, raio * 1.1), Color("6f6a63"), PI * 0.25,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal", centro + Vector3(0.0, 0.6, 0.0),
		Vector3(0.12, 1.2, 0.12), CANO, 0.0, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Quatro alcas, do alto do mastro para a borda do disco.
	for i in 4:
		var ang := TAU * float(i) / 4.0 + PI * 0.125
		var fora := Vector3(cos(ang), 0.0, sin(ang))
		var b := Basis(Vector3.UP, -ang + PI * 0.5) * Basis(Vector3.RIGHT, 0.85)
		KitModular.caixa_livre(sup, &"metal",
			centro + fora * (raio * 0.44) + Vector3(0.0, 0.8, 0.0),
			Vector3(0.06, raio * 1.15, 0.06), b, AMARELO_BRINQUEDO, QUAD_FOLHA)

	colisao.append({"tamanho": Vector3(raio * 1.8, 0.6, raio * 1.8),
		"pos": centro + Vector3(0.0, 0.3, 0.0)})


## Trepa-trepa: duas escadas de ponta e as barras por cima.
const TREPA_ALTO := 1.85
const TREPA_COMP := 3.0
const TREPA_LARG := 1.1

static func trepa_trepa(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float) -> void:
	var eixo := Vector3(cos(giro), 0.0, -sin(giro))
	var frente := Vector3(sin(giro), 0.0, cos(giro))

	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"metal",
				centro + eixo * (TREPA_LARG * 0.5 * sx)
					+ frente * (TREPA_COMP * 0.5 * sz)
					+ Vector3(0.0, TREPA_ALTO * 0.5, 0.0),
				Vector3(0.08, TREPA_ALTO, 0.08), AZUL_BRINQUEDO, giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
		# Longarina, de ponta a ponta.
		KitModular.caixa_cor(sup, &"metal",
			centro + eixo * (TREPA_LARG * 0.5 * sx) + Vector3(0.0, TREPA_ALTO, 0.0),
			Vector3(0.08, 0.08, TREPA_COMP), AZUL_BRINQUEDO, giro,
			PSXMesh.FACE_TODAS, 8.0)
		# Degraus da escada de ponta, que e por onde se sobe.
		for i in 3:
			KitModular.caixa_cor(sup, &"metal",
				centro + frente * (TREPA_COMP * 0.5 * sx)
					+ Vector3(0.0, TREPA_ALTO * (float(i) + 1.0) / 4.0, 0.0),
				Vector3(0.05, 0.05, TREPA_LARG), CANO, giro + PI * 0.5,
				PSXMesh.FACE_TODAS, 8.0)

	var barras := 5
	for i in barras:
		var t := (float(i) + 0.5) / float(barras)
		KitModular.caixa_cor(sup, &"metal",
			centro + frente * lerpf(-TREPA_COMP * 0.5, TREPA_COMP * 0.5, t)
				+ Vector3(0.0, TREPA_ALTO, 0.0),
			Vector3(0.05, 0.05, TREPA_LARG), CANO, giro + PI * 0.5,
			PSXMesh.FACE_TODAS, 8.0)

	for sz: float in [-1.0, 1.0]:
		KitModular.solido(colisao,
			centro + frente * (TREPA_COMP * 0.5 * sz)
				+ Vector3(0.0, TREPA_ALTO * 0.5, 0.0),
			Vector3(TREPA_LARG + 0.2, TREPA_ALTO, 0.2), giro)


## Bichinho de mola. O unico brinquedo que se mexe sozinho de perto: entra no
## material `corrente`, com o pe rigido e a cabeca solta, e ginga no mesmo vento
## que balanca a arvore atras dele. E o detalhe que diz que o parquinho esta
## vazio agora, e nao abandonado.
static func mola(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float, cor: Color) -> void:
	var assento := 0.62
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var topo := base.y + 1.0

	KitModular.caixa_cor(sup, &"concreto_sujo", base + Vector3(0.0, 0.05, 0.0),
		Vector3(0.44, 0.1, 0.44), Color("9a968c"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_flex(sup, &"corrente", base + Vector3(0.0, assento * 0.5, 0.0),
		Vector3(0.14, assento, 0.14), Color("6f6a63"), giro,
		base.y, topo, 0.0, 0.7, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Corpo, cabeca e alca, todos flexiveis a partir do pe: e o conjunto que
	# ginga, nao a mola sozinha.
	KitModular.caixa_flex(sup, &"corrente",
		base + Vector3(0.0, assento + 0.16, 0.0), Vector3(0.34, 0.3, 0.86), cor,
		giro, base.y, topo, 0.0, 0.9, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_flex(sup, &"corrente",
		base + frente * 0.34 + Vector3(0.0, assento + 0.44, 0.0),
		Vector3(0.26, 0.34, 0.26), cor, giro, base.y, topo, 0.0, 1.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_flex(sup, &"corrente",
		base + frente * 0.16 + Vector3(0.0, assento + 0.44, 0.0),
		Vector3(0.44, 0.05, 0.05), CANO, giro, base.y, topo, 0.0, 1.0,
		PSXMesh.FACE_TODAS, 8.0)

	KitModular.solido(colisao, base + Vector3(0.0, 0.45, 0.0),
		Vector3(0.5, 0.9, 0.9), giro)


## Caixa de areia com meio-fio em volta.
##
## O piso sai em ladrilhos de 2,5 m com tom e nivel proprios, e nao num plano so.
## E o mesmo tratamento do calcamento do caminho, pelo mesmo motivo: superficie
## grande, chapada e perfeitamente plana nao existe em parque nenhum, e a areia
## uniforme era a peca que mais denunciava o gerador. O tom sai do INDICE do
## ladrilho, entao dois chunks que desenham pedacos da mesma caixa concordam
## sobre ele sem falar um com o outro.
const LADRILHO_AREIA := 2.5
const DESNIVEL_AREIA := 0.008

static func caixa_de_areia(sup: Dictionary, retangulo: Rect2) -> void:
	var nx := maxi(1, int(round(retangulo.size.x / LADRILHO_AREIA)))
	var nz := maxi(1, int(round(retangulo.size.y / LADRILHO_AREIA)))
	var passo := Vector2(retangulo.size.x / float(nx), retangulo.size.y / float(nz))
	for j in nz:
		for i in nx:
			var p := retangulo.position + Vector2(passo.x * float(i), passo.y * float(j))
			# Sobreposicao, senao o degrau entre dois ladrilhos abre fresta e
			# aparece a grama por baixo.
			var r := Rect2(p - Vector2(0.05, 0.05), passo + Vector2(0.1, 0.1))
			var t := _tom(i, j)
			# O tom varia em BRILHO, nao em matiz. Sorteando os tres canais
			# separados, como estava, cada ladrilho puxava para um lado do
			# circulo de cor e a caixa de areia saia com remendos rosa e verdes.
			var tom := lerpf(0.9, 1.08, t)
			piso(sup, &"areia", r,
				Y_AREIA + lerpf(-DESNIVEL_AREIA, DESNIVEL_AREIA, _tom(i + 7, j + 3)),
				Color(tom, tom * 0.995, tom * 0.98))
	_meio_fio_em_volta(sup, retangulo)


## Meio-fio picado em pedacos de tres metros. Inteiro, ele sairia todo no chunk
## que contem o meio da aresta e sumiria junto com ele.
static func _meio_fio_em_volta(sup: Dictionary, retangulo: Rect2) -> void:
	var y := Y_AREIA + 0.09
	var arestas := [
		[retangulo.position, Vector2(retangulo.end.x, retangulo.position.y)],
		[Vector2(retangulo.position.x, retangulo.end.y), retangulo.end],
		[retangulo.position, Vector2(retangulo.position.x, retangulo.end.y)],
		[Vector2(retangulo.end.x, retangulo.position.y), retangulo.end],
	]
	for par: Array in arestas:
		var a: Vector2 = par[0]
		var b: Vector2 = par[1]
		var comp := (b - a).length()
		var horizontal := absf(b.x - a.x) > absf(b.y - a.y)
		var n := maxi(1, ceili(comp / 3.0))
		for i in n:
			var p0 := a.lerp(b, float(i) / float(n))
			var p1 := a.lerp(b, float(i + 1) / float(n))
			var meio := (p0 + p1) * 0.5
			if meio.x < 0.0 or meio.x >= KitModular.CHUNK:
				continue
			if meio.y < 0.0 or meio.y >= KitModular.CHUNK:
				continue
			var pedaco := comp / float(n)
			KitModular.caixa_cor(sup, &"meio_fio", Vector3(meio.x, y, meio.y),
				Vector3(pedaco if horizontal else 0.22, 0.18,
					0.22 if horizontal else pedaco),
				Color("a3a099"), 0.0, PSXMesh.FACE_TODAS, 8.0)


## Ruido puro do indice do ladrilho. Nao pode sair de RandomNumberGenerator pelo
## mesmo motivo de todo sorteio do parque: dois chunks desenham pedacos
## diferentes da mesma caixa e tem de concordar sobre o tom de cada ladrilho.
static func _tom(i: int, j: int) -> float:
	var h := (i * 73856093) ^ (j * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(absi(h) % 100003) / 100003.0


## Quadra de areia com meio-fio de concreto e duas traves.
##
## `com_traves` existe porque o parquinho usava esta mesma peca e ganhava DUAS
## TRAVES DE GOL em cima dos brinquedos: a caixa de areia das criancas com um
## campo de futebol desenhado por cima.
static func quadra_areia(sup: Dictionary, colisao: Array[Dictionary],
		retangulo: Rect2, giro_traves: bool, com_traves: bool = true) -> void:
	caixa_de_areia(sup, retangulo)
	if not com_traves:
		return

	var centro := retangulo.get_center()
	var eixo := retangulo.size.y if giro_traves else retangulo.size.x
	for lado: float in [-1.0, 1.0]:
		var p := Vector3(centro.x, 0.0, centro.y)
		if giro_traves:
			p.z += eixo * 0.46 * lado
		else:
			p.x += eixo * 0.46 * lado
		if p.x < -1.0 or p.x > KitModular.CHUNK + 1.0:
			continue
		if p.z < -1.0 or p.z > KitModular.CHUNK + 1.0:
			continue
		_trave(sup, colisao, p, 0.0 if giro_traves else PI * 0.5)


static func _trave(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	const ALTO := 2.0
	const VAO := 3.0
	var cor := Color("b6b2a8")
	var lateral := Vector3(cos(giro), 0.0, -sin(giro))
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"metal",
			base + lateral * (VAO * 0.5 * lado) + Vector3(0.0, ALTO * 0.5, 0.0),
			Vector3(0.1, ALTO, 0.1), cor, giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, ALTO, 0.0),
		Vector3(VAO + 0.1, 0.1, 0.1), cor, giro, PSXMesh.FACE_TODAS, 8.0)
	colisao.append({"tamanho": Vector3(VAO, ALTO, 0.3), "pos":
		base + Vector3(0.0, ALTO * 0.5, 0.0)})

## Chafariz de praca: tanque octogonal aproximado, agua parada e coluna central.
static func chafariz(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, raio: float) -> void:
	var cor := Color("a8a49a")
	# Oito paredes em volta. Octogono e o meio-termo do PS1 entre circulo e
	# quadrado: le como redondo e custa oito faces.
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var p := centro + Vector3(cos(ang), 0.0, sin(ang)) * raio
		KitModular.caixa_cor(sup, &"concreto_sujo", p + Vector3(0.0, 0.28, 0.0),
			Vector3(raio * 0.8, 0.56, 0.3), cor, -ang + PI * 0.5,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	piso(sup, &"agua", Rect2(centro.x - raio * 0.78, centro.z - raio * 0.78,
		raio * 1.56, raio * 1.56), 0.42, Color("6c7a80"))

	KitModular.caixa_cor(sup, &"concreto_sujo", centro + Vector3(0.0, 0.75, 0.0),
		Vector3(0.5, 1.5, 0.5), cor, PI * 0.25, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo", centro + Vector3(0.0, 1.55, 0.0),
		Vector3(1.1, 0.16, 1.1), cor, PI * 0.25, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	colisao.append({"tamanho": Vector3(raio * 2.0, 0.6, raio * 2.0),
		"pos": centro + Vector3(0.0, 0.3, 0.0)})


# --- telhados ---------------------------------------------------------------

## Celula das aguas de telhado, em metros.
##
## Nao e enfeite. Com `vertex_lighting` a luz so existe no vertice: uma agua de
## seis metros feita de dois triangulos e atravessada pelo facho do poste no
## meio e continua preta, porque nao ha vertice onde a luz bate. Um metro e meio
## poe vertice dentro do pocao de cada lampiao da praca.
const QUAD_TELHA := 1.5

## Telha de barro da praca, em duas faces. Sao constantes compartilhadas de
## proposito: igreja, coreto e casario sao o MESMO barro, e quando cada peca
## escolhia o proprio tom o coreto saia laranja vivo ao lado de um casario
## marrom escuro — tres telhados de tres cidades diferentes na mesma foto.
##
## A diferenca entre as duas faces e o que da a dobra. Sob luz de vertice quase
## rasante, duas aguas do mesmo tom leem como um plano so e a cumeeira some.
const TELHA_CLARA := Color("b06a3c")
const TELHA_ESCURA := Color("7a4224")

## Uma agua de telhado: quadrilatero plano, subdividido, virado para `olhar`.
##
## Os cantos vem no contorno: `a` e `b` no beiral, `c` sobre `b` e `d` sobre `a`
## na cumeeira. Degenerado e valido — com `c` e `d` no mesmo ponto a agua vira
## a face triangular de uma piramide, e o telhado do coreto e o da sineira usam
## exatamente esse caso.
##
## Quem chama diz so para onde a agua OLHA. A regra de que a face aparece do
## lado OPOSTO ao produto vetorial mora aqui dentro, e em lugar nenhum mais:
## ela ja derrubou o Fusca, os cinco carros de caixa e o chao inteiro da
## estrada, e o jeito de nao errar uma quarta vez e nao ter onde errar.
static func agua_de_telhado(sup: Dictionary, material: StringName,
		a: Vector3, b: Vector3, c: Vector3, d: Vector3, cor: Color,
		olhar: Vector3, uv_por_m: float = 0.5,
		max_quad: float = QUAD_TELHA) -> void:
	var k := (b - a).cross(d - a)
	if k.length_squared() < 1e-9:
		return
	var normal := k.normalized()
	if normal.dot(olhar) < 0.0:
		normal = -normal
	# `direto` guarda a decisao de giro; a regra e aplicada uma vez, nao por celula.
	var direto := k.dot(olhar) < 0.0

	var comp_beiral := maxf(a.distance_to(b), c.distance_to(d))
	var comp_queda := maxf(a.distance_to(d), b.distance_to(c))
	var nu := maxi(1, ceili(comp_beiral / max_quad))
	var nv := maxi(1, ceili(comp_queda / max_quad))

	var fonte := PSXMesh.dados_vazios()
	var fv: PackedVector3Array = fonte["v"]
	var fn: PackedVector3Array = fonte["n"]
	var fuv: PackedVector2Array = fonte["uv"]
	var fc: PackedColorArray = fonte["c"]
	var fi: PackedInt32Array = fonte["i"]
	for iv in nv + 1:
		var v := float(iv) / float(nv)
		for iu in nu + 1:
			var u := float(iu) / float(nu)
			fv.append(a.lerp(b, u).lerp(d.lerp(c, u), v))
			fn.append(normal)
			# UV ancorada em metro de mundo: a telha tem o mesmo tamanho na
			# igreja e na casinha, que e o que faz o casario ler como um conjunto.
			fuv.append(Vector2(u * comp_beiral * uv_por_m,
				(1.0 - v) * comp_queda * uv_por_m))
			fc.append(cor)
	for iv in nv:
		for iu in nu:
			var i0 := iv * (nu + 1) + iu
			var i1 := i0 + 1
			var i2 := i0 + nu + 1
			var i3 := i2 + 1
			if direto:
				fi.append_array([i0, i1, i3, i0, i3, i2])
			else:
				fi.append_array([i0, i3, i1, i0, i2, i3])
	fonte["v"] = fv
	fonte["n"] = fn
	fonte["uv"] = fuv
	fonte["c"] = fc
	fonte["i"] = fi
	if not sup.has(material):
		sup[material] = PSXMesh.dados_vazios()
	PSXMesh.acumular(sup[material], fonte, Transform3D.IDENTITY)


## Telhado de duas aguas. A cumeeira corre no Z local e as aguas caem para o X
## local; `giro` gira o conjunto. Devolve a altura do pico acima de `base.y`,
## que quem chama usa para pousar cruz, cumeeira ou frontao sem refazer a conta.
##
## `base` e o centro do vao no nivel do BEIRAL, nao no chao: a inclinacao e a
## unica coisa que a peca precisa saber, e amarra-la ao chao obrigaria toda
## chamada a somar a altura da parede de novo.
##
## As duas aguas ganham cores diferentes de proposito. A noite, sob luz de
## vertice quase rasante, duas aguas do mesmo tom leem como um plano so e a
## cumeeira some; meio tom de diferenca devolve a dobra sem custar geometria.
## `beiral_ponta` e separado do lateral porque a igreja precisa dele em zero: o
## frontao e a parede da fachada subindo ACIMA da telha, e um beiral avancando
## na ponta poe telha na frente do frontao e come justamente a silhueta
## triangular que as refs 01 e 02 mostram. No casario os dois sao iguais.
static func telhado_duas_aguas(sup: Dictionary, base: Vector3,
		largura: float, comprimento: float, altura: float, giro: float,
		cor: Color, cor_sombra: Color, beiral: float = 0.45,
		material: StringName = &"teto", beiral_ponta: float = -1.0) -> float:
	if beiral_ponta < 0.0:
		beiral_ponta = beiral
	var eixo := Basis(Vector3.UP, giro)
	var hx := largura * 0.5 + beiral
	var hz := comprimento * 0.5 + beiral_ponta
	for sx: float in [-1.0, 1.0]:
		var a := base + eixo * Vector3(hx * sx, 0.0, -hz * sx)
		var b := base + eixo * Vector3(hx * sx, 0.0, hz * sx)
		var c := base + eixo * Vector3(0.0, altura, hz * sx)
		var d := base + eixo * Vector3(0.0, altura, -hz * sx)
		var olhar := (eixo * Vector3(altura * sx, hx, 0.0)).normalized()
		agua_de_telhado(sup, material, a, b, c, d,
			cor if sx > 0.0 else cor_sombra, olhar)
	# Cumeeira: sem ela as duas aguas se encontram numa aresta de um pixel e o
	# dither serrilha a linha do topo a cada passo do jogador.
	KitModular.caixa_cor(sup, material, base + eixo * Vector3(0.0, altura, 0.0),
		Vector3(0.34, 0.2, comprimento + beiral_ponta * 2.0), cor_sombra, giro,
		PSXMesh.FACE_TODAS, QUAD_TELHA)
	# Forro do beiral. As aguas sao de face UNICA — `agua_de_telhado` orienta
	# cada uma para fora — e o beiral avanca meio metro alem da parede. Debaixo
	# desse balanco, portanto, nao existia superficie nenhuma: quem olhasse a
	# casa de baixo para cima, ou de tras com a lente abaixo da linha do beiral,
	# via o telhado pelo lado de dentro, que e o mesmo que nao ver telhado.
	#
	# Uma placa horizontal no nivel do beiral fecha o vao inteiro de uma vez, e
	# de quebra da espessura a borda: telha sem espessura le como papel recortado.
	KitModular.caixa_cor(sup, material, base + eixo * Vector3(0.0, -0.05, 0.0),
		Vector3(largura + beiral * 2.0, 0.1, comprimento + beiral_ponta * 2.0),
		cor_sombra.lerp(Color.BLACK, 0.45), giro, PSXMesh.FACE_TODAS, 2.0)
	return altura


## Oitao: o triangulo que fecha a ponta do telhado de duas aguas. Fica no plano
## da parede, nao na ponta do beiral — o beiral avanca por cima dele e e essa
## sombra que da profundidade a fachada.
static func oitao(sup: Dictionary, material: StringName, base: Vector3,
		largura: float, altura: float, giro: float, cor: Color,
		max_quad: float = QUAD_TELHA) -> void:
	var eixo := Basis(Vector3.UP, giro)
	var a := base + eixo * Vector3(-largura * 0.5, 0.0, 0.0)
	var b := base + eixo * Vector3(largura * 0.5, 0.0, 0.0)
	var pico := base + eixo * Vector3(0.0, altura, 0.0)
	agua_de_telhado(sup, material, a, b, pico, pico, cor,
		eixo * Vector3(0.0, 0.0, 1.0), 0.5, max_quad)


## Telhado piramidal de `lados` aguas sobre um poligono de raio `raio`.
## Serve a sineira (4) e ao coreto (8) com a mesma conta.
static func telhado_piramide(sup: Dictionary, material: StringName,
		base: Vector3, raio: float, altura: float, lados: int, giro: float,
		cor: Color, cor_sombra: Color) -> void:
	var apex := base + Vector3(0.0, altura, 0.0)
	for i in lados:
		var ang0 := TAU * float(i) / float(lados) + giro
		var ang1 := TAU * float(i + 1) / float(lados) + giro
		var p0 := base + Vector3(cos(ang0) * raio, 0.0, sin(ang0) * raio)
		var p1 := base + Vector3(cos(ang1) * raio, 0.0, sin(ang1) * raio)
		var meio := (ang0 + ang1) * 0.5
		# A agua olha para fora e para cima; a componente Y sobe com a altura.
		var olhar := Vector3(cos(meio) * altura, raio, sin(meio) * altura).normalized()
		agua_de_telhado(sup, material, p0, p1, apex, apex,
			cor if (i % 2) == 0 else cor_sombra, olhar)


## Coreto octogonal da praca: base de pedra, escada, oito pilares de madeira,
## guarda-corpo e telhado de telha.
##
## Hoje so o traco BOSQUE usa. A Praca da Matriz tirou o dela: quando o muro do
## adro avancou para +4,0 ele passou a cortar a plataforma do coreto ao meio, e a
## referencia da capela azul nao tem coreto nenhum — o marco dela e o cruzeiro.
##
## Telhado = 8 triangulos (apex -> beiral). Caixa inclinada lia V/borboleta
## no perfil; face sem espessura fecha a silhueta /\ das refs 01/03.
## A escada de pedra com peitoril faz a base ler como podium.
static func coreto(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, raio: float) -> void:
	var madeira := Color("5a4634")
	var pedra := Color("9a968c")
	var pedra_degrau := Color("b0aca2")
	var pedra_espelho := Color("7a766c")
	var telha := TELHA_CLARA
	var telha_escura := TELHA_ESCURA
	var y_piso := 0.58

	# Base octogonal aproximada: caixa girada 22.5 graus + anel de pedra.
	KitModular.caixa_cor(sup, &"concreto_sujo", centro + Vector3(0.0, y_piso * 0.5, 0.0),
		Vector3(raio * 2.05, y_piso, raio * 2.05), pedra, PI / 8.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	for i in 8:
		var ang := TAU * float(i) / 8.0 + PI / 8.0
		var p := centro + Vector3(cos(ang), 0.0, sin(ang)) * (raio * 0.95)
		KitModular.caixa_cor(sup, &"concreto_sujo", p + Vector3(0.0, y_piso * 0.5, 0.0),
			Vector3(raio * 0.72, y_piso, 0.28), pedra, -ang + PI * 0.5,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Escada no lado +Z (sul da praca, olhando a igreja ao norte).
	# Quatro degraus com espelho escuro + piso claro e peitoris laterais —
	# sem isso some na nevoa e vira bloco unico.
	var n_degraus := 4
	var larg_escada := 1.55
	for degrau in n_degraus:
		var t := float(degrau)
		var h_deg := y_piso / float(n_degraus)
		var y_topo := (t + 1.0) * h_deg
		var prof := 0.38
		var afast := raio + 0.12 + t * 0.36
		# Espelho (riser).
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + Vector3(0.0, y_topo - h_deg * 0.5, afast - prof * 0.15),
			Vector3(larg_escada - t * 0.08, h_deg, 0.1), pedra_espelho, 0.0,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		# Piso do degrau (tread).
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + Vector3(0.0, y_topo - 0.04, afast),
			Vector3(larg_escada - t * 0.08, 0.08, prof), pedra_degrau, 0.0,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Peitoris / cheeks da escada.
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + Vector3(sx * (larg_escada * 0.5 + 0.08), y_piso * 0.45,
				raio + 0.55),
			Vector3(0.18, y_piso * 0.9, 1.55), pedra, 0.0,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Oito pilares; guarda-corpo pula o vao sul (+Z) — portal pro eixo da igreja.
	var alt_pilar := 2.35
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var p := centro + Vector3(cos(ang), 0.0, sin(ang)) * (raio * 0.82)
		KitModular.caixa_cor(sup, &"tabua",
			p + Vector3(0.0, y_piso + alt_pilar * 0.5, 0.0),
			Vector3(0.16, alt_pilar, 0.16), madeira, ang,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		var ang2 := TAU * float(i + 1) / 8.0
		# Segmento que olha pro sul (escada / pin Cine2): sem grade.
		var mid_ang := ang + (ang2 - ang) * 0.5
		if sin(mid_ang) > 0.55:
			continue
		var a := centro + Vector3(cos(ang), 0.0, sin(ang)) * (raio * 0.82)
		var b := centro + Vector3(cos(ang2), 0.0, sin(ang2)) * (raio * 0.82)
		var meio := (a + b) * 0.5
		var comp := a.distance_to(b)
		var giro := atan2(b.x - a.x, b.z - a.z)
		# Corrimao e frechal; entre eles as ripas verticais das refs.
		KitModular.caixa_cor(sup, &"tabua",
			meio + Vector3(0.0, y_piso + 1.05, 0.0),
			Vector3(0.09, 0.1, comp), madeira, giro,
			PSXMesh.FACE_TODAS, 8.0)
		KitModular.caixa_cor(sup, &"tabua",
			meio + Vector3(0.0, y_piso + 0.18, 0.0),
			Vector3(0.08, 0.09, comp), madeira, giro,
			PSXMesh.FACE_TODAS, 8.0)
		# Ripa grossa e vao largo de proposito. Ripa de 5 cm a doze metros nao
		# chega a um pixel em 480x270: vira o mesmo chiado do dither e o gradil
		# inteiro cintila. Com 9 cm e vao igual, de longe le como massa cheia e
		# de perto — que e como a ref 03 ve o coreto, na lanterna — le como ripa.
		var n_ripa := maxi(2, int(comp / 0.30))
		for r in n_ripa:
			var t := (float(r) + 0.5) / float(n_ripa)
			KitModular.caixa_cor(sup, &"tabua",
				a.lerp(b, t) + Vector3(0.0, y_piso + 0.6, 0.0),
				Vector3(0.09, 0.82, 0.09), madeira.lerp(Color("3a2c1e"), 0.25),
				giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Telhado octogonal (ref 01/03): 8 aguas apex->beiral, SEM caixa inclinada.
	# Caixa_livre com espessura no perfil lia V/borboleta (aresta fina = vale).
	var y_beiral := y_piso + alt_pilar + 0.08
	var eave_r := raio * 1.28
	var roof_h := 3.25
	# Beiral + forro: volume sob a agua, fora da silhueta /\ .
	KitModular.caixa_cor(sup, &"teto", centro + Vector3(0.0, y_beiral + 0.02, 0.0),
		Vector3(eave_r * 2.12, 0.14, eave_r * 2.12), telha_escura, PI / 8.0,
		PSXMesh.FACE_TODAS, 1.35)
	KitModular.caixa_cor(sup, &"tabua", centro + Vector3(0.0, y_beiral - 0.08, 0.0),
		Vector3(raio * 1.7, 0.1, raio * 1.7), madeira, PI / 8.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Caibros aparentes sob a agua (ref 03: o coreto e visto POR BAIXO, de perto,
	# e sem eles o beiral e uma tampa lisa boiando sobre os pilares).
	for i in 16:
		var ang_c := TAU * float(i) / 16.0 + PI / 16.0
		var fora := Vector3(cos(ang_c), 0.0, sin(ang_c))
		KitModular.caixa_cor(sup, &"tabua",
			centro + fora * (eave_r * 0.62) + Vector3(0.0, y_beiral - 0.16, 0.0),
			Vector3(0.08, 0.1, eave_r * 1.2), madeira.lerp(Color("2e2418"), 0.35),
			ang_c + PI * 0.5, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	telhado_piramide(sup, &"teto",
		centro + Vector3(0.0, y_beiral, 0.0), eave_r, roof_h, 8, PI / 8.0,
		telha, telha_escura)
	# Pico curto — fecha a ponta sem engolir as aguas.
	KitModular.caixa_cor(sup, &"teto",
		centro + Vector3(0.0, y_beiral + roof_h - 0.05, 0.0),
		Vector3(0.35, 0.4, 0.35), telha, PI / 8.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Lanterna sob o teto (ref 03 — ponto amarelo no centro).
	KitModular.caixa_cor(sup, &"metal",
		centro + Vector3(0.0, y_beiral + 0.45, 0.0),
		Vector3(0.14, 0.22, 0.14), Color("e8c040"), 0.0,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	colisao.append({"tamanho": Vector3(raio * 2.1, y_piso + 0.2, raio * 2.1),
		"pos": centro + Vector3(0.0, y_piso * 0.5, 0.0)})


## Azul da capela. NAO e o azul da foto, e a diferenca e uma conta, nao gosto.
##
## Primeira tentativa: #6fc2e8, o azul da print clareado um passo. Medido na
## fachada, o cunhal saiu em H 39 graus — LARANJA — e o outro em H 143, verde.
## Azul nenhum.
##
## Quem desfaz nao e a textura: `reboco` mede (215, 210, 206), praticamente
## neutra. Quem desfaz e a LUZ. As duas lanternas da porta sao `ffc978`, ou
## seja (1,00 · 0,788 · 0,471) — o azul do facho vale menos da metade do
## vermelho. A conta do pixel final, por canal:
##
##   #6fc2e8 (0,435 · 0,761 · 0,910)
##     x reboco (0,843 · 0,823 · 0,806)
##     x luz    (1,000 · 0,788 · 0,471)
##     = (0,367 · 0,493 · 0,345)   ->  R MAIOR que B. Sai alaranjado.
##
## Para o pixel sair azul sob essa luz, a tinta precisa de B/R maior que o
## inverso do B/R da luz (2,12) vezes a razao que se quer ver. Para um azul
## honesto (B/R final ~1,9) a tinta precisa de B/R ~4,4 — e nao dos 2,09 do
## azul da foto.
##
##   #2f93cf (0,184 · 0,576 · 0,812), B/R = 4,40
##     x reboco x luz = (0,155 · 0,373 · 0,308)  ->  B/R 1,99, luma ~80
##
## Luma 80 contra os 146 da parede caiada: o azul fica MAIS ESCURO que o
## branco, que e o que a print mostra, e fica azul de verdade.
##
## E a mesma licao de sempre, rodando ao contrario: luz colorida nao vence
## albedo, e albedo tambem nao vence luz. Quem quiser cor tem de pagar nos dois.
const AZUL := Color("2f93cf")
## Recuo: almofada da porta, fundo do vao da sacada. Um tom abaixo do AZUL, e
## nao um cinza: painel rebaixado de porta pintada continua sendo a mesma tinta
## com menos luz batendo.
const AZUL_FUNDO := Color("22698f")
## Sotoposto — a face de baixo da laje da sacada e o miolo dos cachorros. E o
## unico azul escuro, e existe para a sacada ter uma sombra PROPRIA: sem ela a
## laje sai flutuando contra a parede, porque `vertex_lighting` nao sombreia
## saliencia de meio metro.
const AZUL_SOMBRA := Color("174a68")

## Madeira escura de caibro e cachorro. Mesma para a capela e para o casario:
## a cidade tem uma carpintaria so.
const MADEIRA_ESCURA := Color("3a2c1e")

## Balaustres por sacada.
##
## Sete, e nao nove. A conta: do pin do acordar a lente ve 18,3 m de largura no
## plano da fachada (FOV 70 a 13,1 m), ou seja 26 px por metro. Com sete, cada
## balaustre de 0,11 m da 2,9 px e o vao entre vizinhos da outros 2,9 — o olho
## conta ritmo. Com nove o vao cai para 2,1 px e o dither come a alternancia:
## a balaustrada vira uma barra azul lisa e o trabalho todo se perde.
##
## NAO copie esta cota para peca que fique alem de 15 m.
const BALAUSTRES := 7

## Largura da nave e altura do plinto. Constantes, e nao locais de
## `igreja_matriz`, porque `velas_da_igreja` precisa da MESMA conta para pousar a
## luz na frente de cada janela acesa.
const IGREJA_LARGURA := 12.4
const IGREJA_PLINTO := 0.55

## Altura da bandeira da porta: o painel fixo acima das folhas (foto 03).
const BANDEIRA_H := 0.75

## Janelas das laterais da nave: [lado (-1 oeste, +1 leste), posicao ao longo da
## nave a partir do centro, centro em y acima do plinto, altura do vao, acesa].
##
## Oeste: a sineira ocupa o fundo da parede (de -6,4 a -2,4), entao as duas
## janelas ficam na metade da frente. Leste: a sacristia cobre a parede de -5,2 a
## +2,2 ate uns 4,3 m, entao la uma janela e baixa na frente e a outra e ALTA,
## acima do telhado dela, com vao mais curto para nao encostar na cornija.
const JANELAS_LATERAIS: Array[Array] = [
	[-1.0, 2.6, 3.2, 2.0, true],
	[-1.0, -1.2, 3.2, 2.0, false],
	[1.0, 3.8, 3.2, 2.0, true],
	[1.0, -1.5, 5.35, 1.3, false],
]


## Onde acender a luz de cada janela lateral acesa: sessenta centimetros para
## fora da parede, na altura da vela. Mesma conta do desenho da janela.
static func velas_da_igreja(centro: Vector3, giro: float) -> Array[Vector3]:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	var saida: Array[Vector3] = []
	for jan: Array in JANELAS_LATERAIS:
		if not bool(jan[4]):
			continue
		var hv: float = jan[3]
		saida.append(centro + lado * (float(jan[0]) * (IGREJA_LARGURA * 0.5 + 0.6))
			+ frente * float(jan[1])
			+ Vector3(0.0, IGREJA_PLINTO + float(jan[2]) - hv * 0.2, 0.0))
	return saida


## Cunhal de quina em L: uma pilastra em cada uma das duas faces que se
## encontram no canto.
##
## `canto` e a quina no plano das duas paredes, na cota do pe. `na` e `nb` sao as
## normais para fora das duas faces. A peca da face `na` passa por cima do canto;
## a da face `nb` para no plano de `na` — assim nenhum par de faces coplanares
## divide o quadrado da quina, que era onde uma pilastra de duas caixas piscaria.
static func _cunhal_em_l(sup: Dictionary, canto: Vector3, na: Vector3,
		nb: Vector3, y0: float, altura: float, larg: float, esp_a: float,
		esp_b: float, cor: Color) -> void:
	var meio := Vector3(0.0, y0 + altura * 0.5, 0.0)
	KitModular.caixa_cor(sup, &"reboco",
		canto + meio + na * (esp_a * 0.5) + nb * ((esp_b - larg) * 0.5),
		Vector3(larg + esp_b, altura, esp_a), cor, atan2(na.x, na.z),
		SEM_COSTA, 2.0)
	KitModular.caixa_cor(sup, &"reboco",
		canto + meio + nb * (esp_b * 0.5) - na * (larg * 0.5),
		Vector3(larg, altura, esp_b), cor, atan2(nb.x, nb.z), SEM_COSTA, 2.0)


## Patamar e um degrau na frente de uma porta que fica no alto do embasamento.
##
## `base` e o pe da porta no plano da parede; `alto` e quanto o chao esta abaixo
## dele. O patamar para 1,5 cm abaixo da soleira para nao dividir plano com o
## plinto da nave onde os dois se encontram. A colisao e uma rampa, a mesma
## conta da escada da fachada: degrau de 27 cm o jogador nao sobe.
static func _degraus_de_porta(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float, largura: float, alto: float) -> void:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	const PATAMAR := 0.45
	const PISO := 0.34
	KitModular.caixa_cor(sup, &"concreto_sujo",
		base + frente * (PATAMAR * 0.5) + Vector3(0.0, -alto * 0.5 - 0.0075, 0.0),
		Vector3(largura, alto - 0.015, PATAMAR), Color("b0aca2"), giro,
		PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		base + frente * (PATAMAR + PISO * 0.5) + Vector3(0.0, -alto * 0.75, 0.0),
		Vector3(largura - 0.1, alto * 0.5, PISO), Color("a39f94"), giro,
		PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, QUAD_FOLHA)
	var corrida := PATAMAR + PISO
	var ang := atan2(alto, corrida)
	colisao.append({
		"tamanho": Vector3(largura, 0.22, sqrt(alto * alto + corrida * corrida)),
		"pos": base + frente * (corrida * 0.5) + Vector3(0.0, -alto * 0.5, 0.0),
		"giro": Vector3(ang * cos(giro), giro, -ang * sin(giro)),
	})


## Seteira: a fresta alta e estreita da torre, com moldura azul e peitoril.
## `plano` e o meio dela no plano da face, `giro` o da face.
static func _seteira(sup: Dictionary, plano: Vector3, giro: float) -> void:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	KitModular.caixa_cor(sup, &"janela_apagada", plano + frente * 0.02,
		Vector3(0.26, 0.95, 0.04), Color("07080a"), giro, SEM_COSTA, QUAD_FOLHA)
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"reboco", plano + lado * (sx * 0.175) + frente * 0.05,
			Vector3(0.09, 1.13, 0.10), AZUL, giro, SEM_COSTA, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"reboco", plano + frente * 0.05 + Vector3(0.0, 0.52, 0.0),
		Vector3(0.44, 0.09, 0.10), AZUL, giro, SEM_COSTA, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		plano + frente * 0.08 + Vector3(0.0, -0.52, 0.0),
		Vector3(0.52, 0.08, 0.16), Color("b2ae9e"), giro, PSXMesh.FACE_TODAS,
		QUAD_FOLHA)


## Capela colonial da Praca da Matriz: nave caiada com aplicacao AZUL, duas
## sacadas de balaustrada na fachada, telhado de duas aguas em telha, sineira
## recuada ao fundo e sacristia baixa a direita.
##
## Historico das versoes que nao funcionaram, para nao voltarem:
##
## 1. Portal freestanding +1,4 m a frente da nave, cruz no ar e rim
##    `janela_acesa` na ombreira. Na nevoa densa lia como retangulo luminoso
##    ("construcao na frente"), nao como capela.
## 2. Frontao em degraus — tres caixas empilhadas — e telhado de caixa chapada.
##    Lia como zigurate: a silhueta que chega a 480x270 e a do contorno, e um
##    contorno em escada nao e um contorno triangular.
## 3. Sineira de 17 m COLADA na fachada, a esquerda da porta. Era uma matriz de
##    cidade grande; a referencia e uma capela de arraial, e capela de arraial
##    nao tem torre na frente. A torre nao foi removida — foi para tras da nave,
##    que e onde ela fica de verdade nessa arquitetura. Ver o bloco da sineira.
##
## Aqui o frontao e UM triangulo e o telhado tem duas aguas de verdade, com o
## mesmo `PICO` nos dois: a aresta inclinada e funcao so da posicao, entao as
## duas superficies concordam sobre onde ela passa e nao abre fenda entre elas.
##
## O azul nao e enfeite: numa fachada caiada a 480x270 o branco nao tem onde
## desenhar contorno. Sao os cunhais, a cornija, a porta e as duas sacadas que
## dizem onde comeca e onde acaba cada coisa. Tire o azul e sobra um retangulo
## claro com um buraco preto no meio.
static func igreja_matriz(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float = 0.0) -> void:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	# Branco colonial com mancha quente; quoin de tijolo legivel, nao preto puro
	# (preto some no wash do fog=denso).
	var reboco := Color("fff6e6")
	var reboco_claro := Color("fff8ea")
	# Plinto e embasamentos: cinza de cimento CLARO, como o degrau da foto 01. O
	# 7a766c de antes, multiplicado pelo concreto, lia como uma faixa preta
	# cortando a capela do chao.
	var plinto_cor := Color("a39e92")
	var telha := TELHA_CLARA
	var telha_sombra := TELHA_ESCURA
	var trim := Color("2a241c")
	var largura := IGREJA_LARGURA
	var fundura := 12.0
	var parede_h := 7.0
	# Caimento do telhado e altura do frontao. Sao o MESMO numero de proposito:
	# o triangulo do frontao e a ponta da agua tem de descrever a mesma reta.
	# 2,2 e o teto, nao um gosto. A camera travada do pin ve ate ~10,25 m no
	# plano da fachada; com plinto 0,55 e parede 7,0 sobra isso para o
	# frontao mais a cruz. Frontao colonial e raso mesmo.
	var pico := 2.2
	var beiral := 0.55
	# Plinto baixo: eleva a soleira sem inventar uma plataforma luminosa.
	const PLINTO := IGREJA_PLINTO
	KitModular.caixa_cor(sup, &"concreto_sujo",
		centro + Vector3(0.0, PLINTO * 0.5, 0.0),
		Vector3(largura + 0.8, PLINTO, fundura + 0.8), plinto_cor, giro,
		PSXMesh.FACE_TODAS, 2.0)
	# Tres degraus curtos no eixo da porta — mesma linguagem do coreto, sem
	# portal solto na frente.
	var pedra_degrau := Color("b0aca2")
	var pedra_espelho := Color("7a766c")
	var n_degraus := 4
	var larg_escada := 3.6
	var h_deg := PLINTO / float(n_degraus)
	var prof := 0.38
	var soleira_afast := fundura * 0.5 + 0.08
	for degrau in n_degraus:
		var t := float(degrau)
		var y_topo := (t + 1.0) * h_deg
		var afast := soleira_afast + 0.1 + (float(n_degraus - 1) - t) * (prof * 0.95)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + frente * (afast - prof * 0.15) + Vector3(0.0, y_topo - h_deg * 0.5, 0.0),
			Vector3(larg_escada - t * 0.04, h_deg, 0.1), pedra_espelho, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + frente * afast + Vector3(0.0, y_topo - 0.04, 0.0),
			Vector3(larg_escada - t * 0.04, 0.08, prof), pedra_degrau, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	var escada_corrida := float(n_degraus) * prof * 0.95 + 0.15
	var escada_meio := soleira_afast + 0.1 + escada_corrida * 0.5
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + lado * (larg_escada * 0.5 + 0.1) * sx
				+ frente * escada_meio + Vector3(0.0, PLINTO * 0.42, 0.0),
			Vector3(0.18, PLINTO * 0.84, escada_corrida), Color("9a968c"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	var ang_esc := atan2(PLINTO, escada_corrida)
	var hip_esc := sqrt(PLINTO * PLINTO + escada_corrida * escada_corrida)
	colisao.append({
		"tamanho": Vector3(larg_escada + 0.2, 0.22, hip_esc),
		"pos": centro + frente * escada_meio + Vector3(0.0, PLINTO * 0.5, 0.0),
		"giro": Vector3(ang_esc * cos(giro), giro, -ang_esc * sin(giro)),
	})
	KitModular.solido(colisao, centro + Vector3(0.0, PLINTO * 0.5, 0.0),
		Vector3(largura + 0.8, PLINTO, fundura + 0.8), giro)
	centro += Vector3(0.0, PLINTO, 0.0)

	# Nave — volume branco que a nevoa ainda le como edificio.
	KitModular.caixa_cor(sup, &"reboco",
		centro + Vector3(0.0, parede_h * 0.5, 0.0),
		Vector3(largura, parede_h, fundura), reboco, giro,
		PSXMesh.FACE_TODAS, 2.5)
	# Sem saia de tijolo no pe da fachada. Ela existia para "ancorar o volume",
	# e na foto 01 quem ancora a capela e o degrau claro do plinto e a base azul
	# dos cunhais; a faixa de tijolo de 90 cm era mais uma mancha escura lida como
	# parede quebrada.
	# Placa frontal mais clara: no denso o volume reboco puro lava; esta face
	# empurrada da nave sobra como branco colonial sem emissivo.
	#
	# Ela e PARTIDA em tres — dois montantes e uma verga — e nao uma laje unica.
	# A laje unica passava por cima do vao da porta, e dai vinham os dois
	# defeitos reportados: a face dela e a face da folha da porta caiam no MESMO
	# plano, duas superficies olhando para fora na mesma profundidade brigavam
	# pelo pixel e a porta PISCAVA; e quando a placa ganhava o teste, aparecia
	# reboco claro no lugar da porta, que le como ver ATRAVES dela.
	const PLACA_E := 0.26
	var placa_y := parede_h * 0.52
	var placa_h := parede_h * 0.88
	var placa_meia := largura * 0.46
	var placa_z := fundura * 0.5 + PLACA_E * 0.5
	# Vao reservado para a porta. Os montantes param nele; a verga comeca
	# em cima dele. Todo mundo le a mesma borda a partir da MESMA conta, senao
	# os tres discordam sobre onde o vao esta e abre fresta.
	var vao_meia := 1.45
	var vao_topo := 4.0
	for sx: float in [-1.0, 1.0]:
		var mont := placa_meia - vao_meia
		KitModular.caixa_cor(sup, &"reboco",
			centro + frente * placa_z
				+ lado * ((vao_meia + placa_meia) * 0.5 * sx)
				+ Vector3(0.0, placa_y, 0.0),
			Vector3(mont, placa_h, PLACA_E), reboco_claro, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	var verga_base := maxf(vao_topo, placa_y - placa_h * 0.5)
	var verga_h := (placa_y + placa_h * 0.5) - verga_base
	if verga_h > 0.05:
		KitModular.caixa_cor(sup, &"reboco",
			centro + frente * placa_z
				+ Vector3(0.0, verga_base + verga_h * 0.5, 0.0),
			Vector3(vao_meia * 2.0, verga_h, PLACA_E), reboco_claro, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Reboco descascado: nenhum, nem na fachada nem nas laterais.
	#
	# Havia duas manchas de tijolo aparente na fachada e quatro em cada lateral.
	# A 480x270 um quadro de tijolo de meio metro numa parede branca nao le como
	# desgaste, le como BURACO — e foi exatamente assim que o pedido descreveu as
	# laterais. A foto e de capela cuidada: o desgaste dela e o escorrido sob os
	# peitoris, que fica.

	# --- cunhais azuis ------------------------------------------------------
	#
	# As pilastras largas das quinas, do plinto a cornija, com base e capitel
	# (foto 01), e DOBRANDO a quina: a pilastra da fachada continua na lateral.
	#
	# Antes a fachada tinha um plano azul so e a lateral levava quoins de tijolo
	# em xadrez. De perto o tijolo escuro na quina branca lia como uma fenda — um
	# dos "buracos nas laterais" do pedido. E era vocabulario errado: xadrez de
	# pedra e de matriz de cantaria; a capela da referencia e de taipa caiada.
	#
	# Na fachada o cunhal sai 30 cm, e nao 16: a placa clara da fachada avanca
	# 26, e o de 16 ficava metade DENTRO dela — so meio metro de azul aparecia.
	#
	# Tres quinas e nao quatro: a do fundo a oeste fica dentro da sineira.
	const CUNHAL_L := 0.90
	const CUNHAL_TOPO := 6.37
	var quinas: Array[Array] = [
		[frente * (fundura * 0.5) - lado * (largura * 0.5), frente, -lado],
		[frente * (fundura * 0.5) + lado * (largura * 0.5), frente, lado],
		[-frente * (fundura * 0.5) + lado * (largura * 0.5), -frente, lado],
	]
	for q: Array in quinas:
		var canto: Vector3 = centro + (q[0] as Vector3)
		var na: Vector3 = q[1]
		var nb: Vector3 = q[2]
		var esp := 0.30 if na.dot(frente) > 0.5 else 0.16
		_cunhal_em_l(sup, canto, na, nb, 0.0, CUNHAL_TOPO, CUNHAL_L, esp, 0.16, AZUL)
		# Base e capitel: o mesmo L, mais largo e mais saliente.
		_cunhal_em_l(sup, canto, na, nb, 0.0, 0.85, CUNHAL_L + 0.08, esp + 0.06,
			0.22, AZUL)
		_cunhal_em_l(sup, canto, na, nb, CUNHAL_TOPO - 0.30, 0.30, CUNHAL_L + 0.08,
			esp + 0.04, 0.20, AZUL)

	# --- cornija: a faixa azul que separa parede de telhado -----------------
	#
	# Duas bandas, e nao uma. A azul e a larga, que da a volta no edificio e
	# desenha a horizontal contra o ceu; a branca fina em cima e o remate que a
	# print mostra, e e ela que impede o azul de encostar na telha escura — azul
	# medio contra telha escura, a noite, viram a mesma mancha.
	#
	# As duas NAO se tocam: 6,37..6,79 e 6,79..7,01. Duas faixas coplanares
	# brigariam pelo pixel a cada passo do jogador.
	KitModular.caixa_cor(sup, &"reboco",
		centro + Vector3(0.0, parede_h - 0.42, 0.0),
		Vector3(largura + 0.40, 0.42, fundura + 0.40), AZUL, giro,
		PSXMesh.FACE_TODAS, 2.0)
	KitModular.caixa_cor(sup, &"reboco",
		centro + Vector3(0.0, parede_h - 0.10, 0.0),
		Vector3(largura + 0.52, 0.22, fundura + 0.52), reboco_claro, giro,
		PSXMesh.FACE_TODAS, 2.0)

	# --- telhado de duas aguas, cumeeira no eixo da nave ---------------------
	# A cumeeira corre da fachada para o fundo, entao a ponta que olha a praca e
	# o frontao. Beiral de ponta ZERO: a telha para no plano da fachada e quem
	# sobe acima dela e a alvenaria do frontao.
	var y_beiral := parede_h
	telhado_duas_aguas(sup, centro + Vector3(0.0, y_beiral, 0.0),
		largura, fundura, pico, giro, telha, telha_sombra, beiral,
		&"teto", 0.0)
	var hx := largura * 0.5 + beiral

	# Cachorros: as pontas de caibro aparecendo por baixo do beiral das duas
	# laterais. Sao o detalhe que a print 01 mostra e que mais separa "telhado
	# colonial" de "tampa de caixa" — a linha do beiral deixa de ser uma reta
	# limpa e passa a ter dente.
	#
	# Na FACHADA nao existem, e isso nao e esquecimento: `beiral_ponta` e zero
	# ali de proposito, porque o frontao e a parede subindo ACIMA da telha.
	var n_cach := int(floor((fundura - 1.2) / 1.2)) + 1
	for sx: float in [-1.0, 1.0]:
		for k in n_cach:
			var zc := -fundura * 0.5 + 0.6 + float(k) * 1.2
			KitModular.caixa_cor(sup, &"tabua",
				centro + lado * ((largura * 0.5 + 0.22) * sx) + frente * zc
					+ Vector3(0.0, y_beiral + 0.04, 0.0),
				Vector3(0.44, 0.16, 0.14), MADEIRA_ESCURA, giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Frontao: UM triangulo, na largura exata da agua, para dividirem a aresta.
	oitao(sup, &"reboco", centro + frente * (fundura * 0.5) + Vector3(0.0, y_beiral, 0.0),
		hx * 2.0, pico, giro, reboco_claro)
	oitao(sup, &"reboco", centro - frente * (fundura * 0.5) + Vector3(0.0, y_beiral, 0.0),
		hx * 2.0, pico, giro + PI, reboco)
	# Cornija rampante: as duas tabuas que acompanham o frontao. Alem de serem o
	# remate colonial das refs, cobrem a costura entre o triangulo de alvenaria
	# e a ponta da telha. AZUIS, para fechar o contorno com os cunhais: brancas
	# sobre frontao branco nao desenhavam aresta nenhuma.
	var comp_rampa := sqrt(hx * hx + pico * pico)
	for sx: float in [-1.0, 1.0]:
		var ang := atan2(pico, -hx * sx)
		var base_ramp := Basis(Vector3.UP, giro) * Basis(Vector3(0.0, 0.0, 1.0), ang)
		KitModular.caixa_livre(sup, &"reboco",
			centro + frente * (fundura * 0.5 + 0.1)
				+ lado * (hx * 0.5 * sx) + Vector3(0.0, y_beiral + pico * 0.5, 0.0),
			Vector3(comp_rampa, 0.26, 0.2), base_ramp, AZUL, 1.2)

	# Janela do frontao (print 01): vao pequeno de moldura azul no eixo, entre
	# as duas sacadas. Substitui o oculo girado a 45 graus, que e remate de
	# matriz grande — a capela da referencia tem um retangulo simples.
	var jf := centro + frente * (fundura * 0.5 + 0.10) + Vector3(0.0, y_beiral + 0.74, 0.0)
	KitModular.caixa_cor(sup, &"reboco", jf,
		Vector3(0.96, 1.12, 0.08), AZUL, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"janela_apagada", jf + frente * 0.05,
		Vector3(0.62, 0.78, 0.06), Color("0a0b0c"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		jf + frente * 0.06 + Vector3(0.0, -0.62, 0.0),
		Vector3(1.06, 0.12, 0.18), Color("b2ae9e"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Cruz no pico do frontao, TORTA. Sete graus e pouco para gritar e o
	# bastante para o olho reclamar: numa fachada onde tudo o mais e prumo e
	# nivel, a unica coisa fora de esquadro e a cruz. Nao inventa nada de
	# enredo, so recusa a leitura de "igreja em ordem".
	const CRUZ_TORTA := 0.12
	var cruz_alt := y_beiral + pico + 0.34
	var cruz_c := centro + frente * (fundura * 0.5) + Vector3(0.0, cruz_alt, 0.0)
	var cruz_b := Basis(Vector3.UP, giro) * Basis(Vector3(0.0, 0.0, 1.0), CRUZ_TORTA)
	KitModular.caixa_livre(sup, &"metal",
		cruz_c - cruz_b * Vector3(0.0, 0.52, 0.0),
		Vector3(0.34, 0.24, 0.34), cruz_b, Color("cfc7b2"), QUAD_FOLHA)
	KitModular.caixa_livre(sup, &"metal", cruz_c,
		Vector3(0.2, 0.9, 0.2), cruz_b, Color("2a2218"), QUAD_FOLHA)
	KitModular.caixa_livre(sup, &"metal",
		cruz_c + cruz_b * Vector3(0.0, 0.16, 0.0),
		Vector3(0.8, 0.2, 0.2), cruz_b, Color("2a2218"), QUAD_FOLHA)
	# Pinaculos nos ombros do frontao: os dois cubinhos que as capelas coloniais
	# tem onde a rampa encontra a cornija. Quebram o V do encontro.
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"reboco",
			centro + frente * (fundura * 0.5) + lado * (hx * 0.94 * sx)
				+ Vector3(0.0, y_beiral + 0.3, 0.0),
			Vector3(0.44, 0.7, 0.44), reboco_claro, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# --- fachada: porta ------------------------------------------------------
	#
	# TABELA DE PROFUNDIDADES, medida a partir de F = face frontal da nave.
	# Nenhuma face olhando para fora pode dividir plano com outra; e por dividir
	# que a porta piscava.
	#
	#   vao (preto e brasa)  F+0,00 .. F+0,05
	#   folhas               F+0,05 .. F+0,19
	#   almofadas            F+0,19 .. F+0,24
	#   placa clara          F+0,00 .. F+0,26   (partida, com vao para a porta)
	#   marco azul           F+0,00 .. F+0,34   (unica peca que avanca da placa)
	var porta_l := 2.9
	var porta_h := 4.0
	var porta_c := centro + frente * (fundura * 0.5 + 0.12) + Vector3(0.0, 2.0, 0.0)
	# O vao sai em DUAS placas coplanares e disjuntas, e nao numa so preta.
	#
	# A folha da direita abre para dentro; pela fresta se ve o miolo da capela, e
	# o miolo esta com vela acesa. A parte que a folha descobre e portanto a
	# unica que pode ser quente — pintar o vao inteiro de brasa faria a luz
	# atravessar a folha FECHADA da esquerda, que e madeira macica.
	#
	# Coplanares e disjuntas nao brigam por profundidade: elas nao se sobrepoem
	# em X, entao nao ha pixel disputado.
	KitModular.caixa_cor(sup, &"janela_apagada",
		porta_c - frente * 0.095 - lado * (porta_l * 0.19),
		Vector3(porta_l * 0.62, porta_h, 0.05),
		Color("050506"), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa(sup, &"janela_acesa",
		porta_c - frente * 0.095 + lado * (porta_l * 0.31),
		Vector3(porta_l * 0.38, porta_h * 0.94, 0.05),
		giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Porta dupla AZUL, ENTREABERTA. A folha da direita gira para dentro sobre a
	# ombreira; a da esquerda fica fechada. Uma igreja aberta as onze e quinze da
	# noite, com vela acesa, nao precisa de legenda nenhuma para incomodar.
	var folha_l := porta_l * 0.5
	const ABERTURA := 0.42
	for sx: float in [-1.0, 1.0]:
		var giro_folha := giro + (ABERTURA if sx > 0.0 else 0.0)
		# Dobradica na ombreira: o centro da folha e o eixo mais meia folha
		# girada, senao a porta abre atravessando a propria parede.
		var eixo := porta_c + lado * (folha_l * sx)
		var giro_l := Vector3(cos(giro_folha), 0.0, -sin(giro_folha))
		# A folha para em baixo da bandeira: 3,25 dos 4,0 do vao.
		var centro_folha := eixo - giro_l * (folha_l * 0.5 * sx) \
			- Vector3(0.0, BANDEIRA_H * 0.5, 0.0)
		# Material `reboco`, e nao `porta`.
		#
		# `porta.png` mede (135, 110, 78): B-R de -57, madeira escura e quente.
		# O AZUL multiplicado por ela e depois pela luz quente chegava em luma
		# 76 com H 131 — verde-acinzentado. A porta virava uma laje chapada sem
		# folha, sem almofada e sem a fresta da folha entreaberta, que e o
		# melhor detalhe da fachada inteira.
		#
		# A porta da print e madeira PINTADA, lisa. A 480x270, com 64 px/m, a
		# diferenca entre veio de madeira e reboco nao chega a existir; a
		# diferenca entre azul e cinza-esverdeado chega.
		KitModular.caixa_cor(sup, &"reboco", centro_folha,
			Vector3(folha_l, porta_h - BANDEIRA_H, 0.14), AZUL, giro_folha,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		# Almofadas: dois paineis rasos por folha, so para a porta nao ser um
		# retangulo liso quando a lanterna bate nela de perto.
		var frente_folha := Vector3(sin(giro_folha), 0.0, cos(giro_folha))
		for py: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"reboco",
				centro_folha + frente_folha * 0.09 + Vector3(0.0, 0.80 * py, 0.0),
				Vector3(folha_l * 0.66, 1.26, 0.05),
				AZUL_FUNDO, giro_folha,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"metal",
			centro_folha + frente_folha * 0.11
				- giro_l * (folha_l * 0.36 * sx) + Vector3(0.0, -0.1, 0.0),
			Vector3(0.12, 0.12, 0.12), Color("6b5a3a"), giro_folha,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Marco AZUL (ombreira e verga). Centro em F+0,17 com 0,34 de espessura:
	# encosta na face da nave e avanca 8 cm alem da placa, entao e a unica peca
	# do portal que sobressai — e por isso a que desenha a sombra do vao.
	#
	# Era cantaria escura em arco de degraus, que e o portal de matriz de pedra.
	# As fotos 03 e 05 mostram a moldura da porta pintada do mesmo azul da folha,
	# com uma cimalha reta por cima: a porta inteira e UMA peca azul na parede
	# branca, e e isso que ela precisa ser a treze metros.
	var marco_z := frente * 0.05
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"reboco",
			porta_c + marco_z + lado * (porta_l * 0.5 + 0.2) * sx,
			Vector3(0.38, porta_h + 0.3, 0.34), AZUL, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"reboco",
		porta_c + marco_z + Vector3(0.0, porta_h * 0.5 + 0.14, 0.0),
		Vector3(porta_l + 0.78, 0.36, 0.34), AZUL, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Cimalha: a pestana reta sobre a verga, mais larga e mais saliente. Ela e a
	# sombra de cima da porta, que a verga sozinha nao faz.
	KitModular.caixa_cor(sup, &"reboco",
		porta_c + frente * 0.12 + Vector3(0.0, porta_h * 0.5 + 0.40, 0.0),
		Vector3(porta_l + 1.10, 0.16, 0.46), AZUL, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Bandeira: o painel fixo no alto do vao, acima das folhas, com o relevo no
	# meio (foto 03). Ocupa os 0,75 m de cima da porta — por isso as folhas
	# param em 3,25 — e fica na profundidade delas, sem se sobrepor a nenhuma.
	var bandeira := porta_c + Vector3(0.0, porta_h * 0.5 - BANDEIRA_H * 0.5, 0.0)
	KitModular.caixa_cor(sup, &"reboco", bandeira,
		Vector3(porta_l, BANDEIRA_H, 0.14), AZUL, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"reboco", bandeira + frente * 0.08,
		Vector3(porta_l * 0.8, BANDEIRA_H * 0.62, 0.04), AZUL_FUNDO, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_livre(sup, &"reboco", bandeira + frente * 0.11,
		Vector3(0.32, 0.32, 0.04),
		Basis(Vector3.UP, giro) * Basis(Vector3(0.0, 0.0, 1.0), PI * 0.25),
		AZUL, QUAD_FOLHA)

	# --- as duas sacadas ----------------------------------------------------
	#
	# A assinatura da capela da referencia, e a peca que a versao anterior nao
	# tinha: ali eram duas janelas altas chapadas na parede, e duas janelas
	# chapadas numa fachada caiada leem como dois furos sem explicacao.
	#
	# A sacada resolve tres coisas de uma vez: poe SALIENCIA numa fachada que
	# era um plano so (e saliencia e a unica sombra que `vertex_lighting` da de
	# graca), poe o azul na altura em que o olho procura o segundo pavimento, e
	# poe RITMO — sete verticais contadas, que e a coisa mais barata que existe
	# para o olho parar num edificio.
	#
	# Alturas, em metros acima do plinto:
	#   3,70  laje         3,78 topo da laje
	#   3,84  guarda-mao inferior
	#   3,90  soleira da janela
	#   4,21  balaustres (centro)
	#   4,60  corrimao
	#   4,95  centro do vao          6,00 topo do vao
	#   6,24  topo da verga          6,37 base da cornija azul
	#
	# PROFUNDIDADE: a sacada inteira sai de F+0,26, e nao de F+0,03.
	#
	# Ela nasceu em F+0,03 e SUMIU — parede caiada lisa onde deviam estar duas
	# janelas. A culpada e a placa clara da fachada: os montantes dela ocupam
	# `lado` de 1,45 a 5,70 de cada lado, ou seja passam exatamente por cima do
	# eixo da sacada em 3,10, e vao de F+0,00 a F+0,26. Qualquer coisa desenhada
	# atras disso esta dentro de uma caixa opaca.
	#
	# O defeito e mais velho que a sacada: as duas janelas altas da versao
	# anterior estavam em F+0,05 e nunca apareceram em captura nenhuma. Ninguem
	# viu porque uma janela que falta numa parede branca nao denuncia nada — e
	# so parede.
	#
	# A saida e por a sacada NA FRENTE da placa em vez de recortar a placa em
	# volta dela. O vao passa a ser um rebaixo de 5 cm dentro da moldura em vez
	# de um furo na parede; a 13,1 m, com 26 px/m, os dois se desenham igual, e
	# quem da o relevo de verdade e a laje, que avanca 58 cm.
	const SACADA_Z := 0.26
	for sx: float in [-1.0, 1.0]:
		var eixo_s := lado * (3.10 * sx)
		var face_s := centro + eixo_s + frente * (fundura * 0.5 + SACADA_Z)

		# O vao e ESCURO, com uma vela pequena dentro. Nao o contrario.
		#
		# A primeira versao acendia o vao inteiro (1,30 x 2,10 de
		# `janela_acesa`). Medido: luma 154 contra 146 da parede caiada — a
		# janela ficava mais clara que a fachada, e duas placas claras de dois
		# metros de altura ACHATAM a sacada: a laje, as maos e os sete
		# balaustres viram silhueta preta recortada contra um retangulo
		# luminoso, e o relevo que a sacada existe para criar desaparece.
		#
		# Vao escuro com uma chama de 0,70 x 0,90 la dentro le como o que e:
		# tem alguem com vela na capela as onze e quinze. A luz fica pequena, o
		# balaustre volta a ter parede clara atras de onde contrastar, e a
		# fachada continua sendo a coisa mais clara do quadro.
		KitModular.caixa_cor(sup, &"janela_apagada",
			face_s + frente * 0.02 + Vector3(0.0, 4.95, 0.0),
			Vector3(1.30, 2.10, 0.06), Color("07080a"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		# A vela: baixa no vao, como chama pousada num genuflexorio, e nao
		# centrada como lampada de teto.
		KitModular.caixa(sup, &"janela_acesa",
			face_s + frente * 0.055 + Vector3(0.0, 4.55, 0.0),
			Vector3(0.70, 0.90, 0.03), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
		# Cruzeta escura na frente do vao: sem ela o buraco e um retangulo liso,
		# que le como nicho e nao como janela.
		KitModular.caixa_cor(sup, &"janela_apagada",
			face_s + frente * 0.07 + Vector3(0.0, 4.95, 0.0),
			Vector3(0.09, 2.04, 0.05), Color("1c1710"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"janela_apagada",
			face_s + frente * 0.07 + Vector3(0.0, 5.40, 0.0),
			Vector3(1.24, 0.09, 0.05), Color("1c1710"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

		# Moldura azul em QUATRO barras, e nao uma placa.
		#
		# Placa e o erro obvio: ela e opaca e cobriria o vao inteiro, e o vao e
		# a unica coisa que a moldura existe para emoldurar. Foi exatamente o
		# defeito que a placa da fachada teve, e esta escrito no bloco dela.
		for jx: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"reboco",
				face_s + frente * 0.05 + lado * (0.76 * jx)
					+ Vector3(0.0, 4.95, 0.0),
				Vector3(0.22, 2.54, 0.10), AZUL, giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"reboco",
			face_s + frente * 0.05 + Vector3(0.0, 6.22, 0.0),
			Vector3(1.74, 0.24, 0.10), AZUL, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			face_s + frente * 0.08 + Vector3(0.0, 3.82, 0.0),
			Vector3(1.86, 0.16, 0.20), Color("b2ae9e"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		# Escorrido sob o peitoril: a lingua escura que a agua deixa em anos.
		# So aqui, e nao na janela do frontao: e a unica que tem peitoril
		# saliente, e escorrido sem peitoril nao acontece.
		escorrido(sup, face_s + Vector3(0.0, 3.72, 0.0), frente, 1.1, 0.30,
			giro, reboco.lerp(Color("2e3228"), 0.5))

		# Laje da sacada, com as tres maos por baixo. A face de baixo leva
		# AZUL_SOMBRA: e a unica sombra propria da fachada inteira.
		KitModular.caixa_cor(sup, &"reboco",
			face_s + frente * 0.29 + Vector3(0.0, 3.70, 0.0),
			Vector3(2.00, 0.16, 0.58), reboco_claro, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"reboco",
			face_s + frente * 0.29 + Vector3(0.0, 3.60, 0.0),
			Vector3(1.94, 0.05, 0.52), AZUL_SOMBRA, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		for mx: float in [-0.72, 0.0, 0.72]:
			KitModular.caixa_cor(sup, &"reboco",
				face_s + frente * 0.21 + lado * mx + Vector3(0.0, 3.46, 0.0),
				Vector3(0.14, 0.30, 0.42), AZUL_SOMBRA, giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)

		# Balaustrada. Ver BALAUSTRES para a conta de por que sao sete.
		KitModular.caixa_cor(sup, &"reboco",
			face_s + frente * 0.48 + Vector3(0.0, 3.84, 0.0),
			Vector3(2.00, 0.12, 0.14), AZUL, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		for b in BALAUSTRES:
			var bx := lerpf(-0.87, 0.87, float(b) / float(BALAUSTRES - 1))
			KitModular.caixa_cor(sup, &"reboco",
				face_s + frente * 0.48 + lado * bx + Vector3(0.0, 4.21, 0.0),
				Vector3(0.11, 0.62, 0.11), AZUL, giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
		for px: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"reboco",
				face_s + frente * 0.48 + lado * (0.95 * px)
					+ Vector3(0.0, 4.21, 0.0),
				Vector3(0.17, 0.86, 0.17), AZUL, giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"reboco",
			face_s + frente * 0.48 + Vector3(0.0, 4.60, 0.0),
			Vector3(2.06, 0.15, 0.18), AZUL, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# --- janelas laterais ---------------------------------------------------
	#
	# A capela so tinha fachada: as laterais eram reboco liso. Na praca antiga
	# ninguem chegava do lado dela; com o adro gramado o jogador da a volta na
	# capela, e parede de doze metros sem vao nenhum le como caixa.
	#
	# Mesma linguagem das sacadas — moldura azul em quatro barras, vao escuro,
	# cruzeta — e a mesma tabela de profundidade: tudo na frente do descascado
	# (que vai ate F+0,075), para nada dividir plano com a mancha.
	for jan: Array in JANELAS_LATERAIS:
		var fora := lado * float(jan[0])
		var p := centro + fora * (largura * 0.5) + frente * float(jan[1]) \
			+ Vector3(0.0, float(jan[2]), 0.0)
		var hv: float = jan[3]
		KitModular.caixa_cor(sup, &"janela_apagada", p + fora * 0.07,
			Vector3(0.06, hv, 1.10), Color("07080a"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		if bool(jan[4]):
			# A vela, baixa no vao, como nas sacadas.
			KitModular.caixa(sup, &"janela_acesa",
				p + fora * 0.095 + Vector3(0.0, -hv * 0.2, 0.0),
				Vector3(0.03, hv * 0.4, 0.55), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"janela_apagada", p + fora * 0.10,
			Vector3(0.05, hv - 0.04, 0.08), Color("1c1710"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"janela_apagada",
			p + fora * 0.10 + Vector3(0.0, hv * 0.18, 0.0),
			Vector3(0.05, 0.08, 1.06), Color("1c1710"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		for jz: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"reboco", p + fora * 0.08 + frente * (0.66 * jz),
				Vector3(0.10, hv + 0.30, 0.22), AZUL, giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"reboco",
			p + fora * 0.08 + Vector3(0.0, hv * 0.5 + 0.11, 0.0),
			Vector3(0.10, 0.22, 1.54), AZUL, giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			p + fora * 0.11 + Vector3(0.0, -hv * 0.5 - 0.08, 0.0),
			Vector3(0.20, 0.13, 1.60), Color("b2ae9e"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# --- os fundos da nave ------------------------------------------------
	#
	# Eram uma parede lisa de doze metros com a cornija por cima. Com o adro
	# gramado o jogador da a volta na capela, e o fundo e a face que o campo santo
	# enxerga. Capela de verdade tem porta de servico atras — por onde entra o
	# sacristao com as flores — e a janelinha do oitao repete a da fachada.
	var fundo_p := centro - frente * (fundura * 0.5) + lado * 2.4
	porta_colonial(sup, fundo_p, giro + PI, 1.2, 2.5, AZUL, true, AZUL,
		false, false, false, false, false)
	_degraus_de_porta(sup, colisao, fundo_p, giro + PI, 1.8, PLINTO)
	var jt := centro - frente * (fundura * 0.5 + 0.10) + Vector3(0.0, y_beiral + 0.74, 0.0)
	KitModular.caixa_cor(sup, &"reboco", jt, Vector3(0.96, 1.12, 0.08), AZUL, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"janela_apagada", jt - frente * 0.05,
		Vector3(0.62, 0.78, 0.06), Color("0a0b0c"), giro, PSXMesh.FACE_TODAS,
		QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo", jt - frente * 0.06 + Vector3(0.0, -0.62, 0.0),
		Vector3(1.06, 0.12, 0.18), Color("b2ae9e"), giro, PSXMesh.FACE_TODAS,
		QUAD_FOLHA)

	# --- sacristia: volume baixo colado a direita ---------------------------
	# Sem ela a igreja e um prisma simetrico, e prisma simetrico le como caixa.
	# O anexo mais baixo de um lado so e o que da escala a nave nas refs.
	var sac_l := 5.0
	var sac_f := 7.4
	var sac_h := 4.0
	var sac := centro + lado * (largura * 0.5 + sac_l * 0.5 - 0.3) - frente * 1.5
	# A sacristia nasce no CHAO, e nao no topo do plinto da nave.
	#
	# O plinto so passa 40 cm da parede da nave, e a sacristia avanca 4,7 m alem
	# dela: pousada em 0,55 ela FLUTUAVA sobre a grama, e de lado dava para ver o
	# gramado por baixo da parede — o buraco de verdade que a volta de captura em
	# volta da capela achou. Agora o corpo desce ate o chao e um embasamento do
	# mesmo cinza do plinto o envolve, parando 3 cm abaixo do topo do plinto para
	# os dois nao dividirem plano onde se sobrepoem.
	KitModular.caixa_cor(sup, &"concreto_sujo",
		sac + Vector3(0.0, -PLINTO * 0.5 - 0.015, 0.0),
		Vector3(sac_l + 0.3, PLINTO - 0.03, sac_f + 0.3), plinto_cor, giro,
		PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, 2.0)
	KitModular.caixa_cor(sup, &"reboco", sac + Vector3(0.0, (sac_h - PLINTO) * 0.5, 0.0),
		Vector3(sac_l, sac_h + PLINTO, sac_f), reboco, giro, PSXMesh.FACE_TODAS, 2.5)
	KitModular.caixa_cor(sup, &"reboco",
		sac + Vector3(0.0, sac_h - 0.14, 0.0),
		Vector3(sac_l + 0.26, 0.28, sac_f + 0.26), AZUL, giro,
		PSXMesh.FACE_TODAS, 2.0)
	# Cunhais nas duas quinas de fora, a mesma pilastra da nave em ponto menor.
	for sz: float in [-1.0, 1.0]:
		var canto_s := sac + frente * (sac_f * 0.5 * sz) + lado * (sac_l * 0.5)
		_cunhal_em_l(sup, canto_s, frente * sz, lado, 0.0, sac_h - 0.28, 0.55,
			0.12, 0.12, AZUL)
		_cunhal_em_l(sup, canto_s, frente * sz, lado, 0.0, 0.7, 0.61, 0.16,
			0.16, AZUL)
	telhado_duas_aguas(sup, sac + Vector3(0.0, sac_h, 0.0),
		sac_l, sac_f, 1.15, giro, telha, telha_sombra, 0.42)
	for sz: float in [-1.0, 1.0]:
		oitao(sup, &"reboco",
			sac + frente * ((sac_f * 0.5) * sz) + Vector3(0.0, sac_h, 0.0),
			sac_l + 0.84, 1.15, giro + (0.0 if sz > 0.0 else PI), reboco_claro)
	# Porta e janela azuis, viradas para a praca. E o que faz a sacristia ler
	# como parte da mesma capela e nao como puxadinho: a foto poe a mesma tinta
	# nos vaos dos dois volumes. A bandeira e a janela ACESAS: e a casa do
	# sacristao, e ele esta acordado.
	var sac_face := sac + frente * (sac_f * 0.5)
	porta_colonial(sup, sac_face - lado * 1.15, giro, 1.10, 2.35, AZUL, true,
		AZUL, false, false, true, false, false)
	_degraus_de_porta(sup, colisao, sac_face - lado * 1.15, giro, 1.7, PLINTO)
	janela_colonial(sup, sac_face + lado * 1.25 + Vector3(0.0, 1.75, 0.0), giro,
		0.95, 1.15, AZUL, AZUL, Janela.ACESA, false, 5)
	KitModular.solido(colisao, sac + Vector3(0.0, (sac_h - PLINTO) * 0.5, 0.0),
		Vector3(sac_l, sac_h + PLINTO, sac_f), giro)

	# --- sineira, RECUADA para o canto traseiro oeste ------------------------
	#
	# Ela ficava colada na fachada, a esquerda da porta, e era o unico ponto em
	# que o conjunto contrariava a referencia: capela de arraial nao tem torre
	# na frente. Mas a torre nao podia simplesmente sair — e ela que espia por
	# cima da nevoa, e o TAKE 5 da abertura ("torre e cruz entram contra a
	# nevoa") depende disso.
	#
	# A saida e a disposicao que essa arquitetura usa de verdade: torre no
	# fundo, encostada na lateral da nave. Da praca a fachada fica igual a
	# print, e a torre aparece ATRAS do telhado — 17,0 menos os 9,75 do
	# conjunto nave+frontao deixam 7,25 m de campanario acima da cumeeira,
	# deslocados do eixo. A silhueta continua tendo duas alturas; o que some e
	# a leitura de matriz de cidade grande.
	#
	# Ela ENCOSTA na nave de proposito (1,4 m de sobreposicao em X): torre
	# tangente le como chamine solta no quintal.
	var torre := centro - frente * (fundura * 0.5 - 1.6) - lado * (largura * 0.5 + 0.6)
	# 17,0 por 4,0 de lado da 4,3:1. A versao anterior era 17,5 por 2,7 —
	# 6,5:1 — e nessa proporcao a sineira nao le como sineira, le como
	# chamine: de longe e uma coluna cinza sem largura para o campanario
	# aparecer.
	var torre_h := 17.0
	var torre_l := 4.0
	# No chao, pelo mesmo motivo da sacristia: 2,2 m da torre ficam fora do plinto
	# da nave, e pousada no topo dele ela flutuava 55 cm sobre a grama.
	KitModular.caixa_cor(sup, &"concreto_sujo",
		torre + Vector3(0.0, -PLINTO * 0.5 - 0.015, 0.0),
		Vector3(torre_l + 0.3, PLINTO - 0.03, torre_l + 0.3), plinto_cor, giro,
		PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, 2.0)
	KitModular.caixa_cor(sup, &"reboco",
		torre + Vector3(0.0, (torre_h - PLINTO) * 0.5, 0.0),
		Vector3(torre_l, torre_h + PLINTO, torre_l), reboco, giro,
		PSXMesh.FACE_TODAS, 2.5)
	# Face clara do lado da praca — ancora a silhueta no fog.
	KitModular.caixa_cor(sup, &"reboco",
		torre + frente * (torre_l * 0.5 + 0.04) + Vector3(0.0, 9.355, 0.0),
		Vector3(torre_l * 0.86, 12.91, 0.12), reboco_claro, giro,
		PSXMesh.FACE_TODAS, 2.5)
	# Cunhais AZUIS nas QUATRO quinas, em L. Eram dois, so na face da praca, e
	# de lado e por tras a torre era um prisma branco liso de 17 m — do adro
	# oeste e do campo santo, que e de onde mais se ve a torre, ela nao tinha
	# desenho nenhum. Eram quoins de tijolo antes disso; tijolo escuro sobre a
	# silhueta na nevoa apagava a largura e a torre lia como chamine.
	for k in 4:
		var na := Vector3(sin(giro + PI * 0.5 * float(k)), 0.0,
			cos(giro + PI * 0.5 * float(k)))
		var nb := Vector3(sin(giro + PI * 0.5 * float(k + 1)), 0.0,
			cos(giro + PI * 0.5 * float(k + 1)))
		_cunhal_em_l(sup, torre + (na + nb) * (torre_l * 0.5), na, nb, 0.0,
			torre_h - 0.44, 0.62, 0.16, 0.16, AZUL)
	# A porta da escada do sino, na face da praca, fora do eixo: o eixo cai
	# dentro da nave (a torre se sobrepoe 1,4 m a ela). E as seteiras que
	# iluminam a escada, na face da praca e na de oeste.
	var torre_frente := torre + frente * (torre_l * 0.5) - lado * 0.45
	porta_colonial(sup, torre_frente, giro, 0.95, 2.2, AZUL, true, AZUL,
		false, false, false, false, false)
	_degraus_de_porta(sup, colisao, torre_frente, giro, 1.45, PLINTO)
	for y_set: float in [5.2, 11.4]:
		_seteira(sup, torre + frente * (torre_l * 0.5 + 0.10) - lado * 0.7
			+ Vector3(0.0, y_set, 0.0), giro)
		_seteira(sup, torre - lado * (torre_l * 0.5) + Vector3(0.0, y_set, 0.0),
			giro - PI * 0.5)
	# Cordao a meia altura: sem ele a torre e um poste de 17 m sem escala.
	KitModular.caixa_cor(sup, &"reboco",
		torre + Vector3(0.0, torre_h * 0.52, 0.0),
		Vector3(torre_l + 0.3, 0.26, torre_l + 0.3), AZUL, giro,
		PSXMesh.FACE_TODAS, 2.0)

	# Campanario: vao em arco nas quatro faces, com sino dentro do que olha a
	# praca. O arco e feito em degraus, mesma linguagem do arco da porta.
	var y_sino := torre_h - 3.1
	for f in 4:
		var ang_f := giro + TAU * float(f) / 4.0
		var fora := Vector3(sin(ang_f), 0.0, cos(ang_f))
		var trans := Vector3(cos(ang_f), 0.0, -sin(ang_f))
		var boca := torre + fora * (torre_l * 0.5 + 0.03) + Vector3(0.0, y_sino, 0.0)
		KitModular.caixa_cor(sup, &"janela_apagada", boca,
			Vector3(1.75, 2.05, 0.1), Color("07080a"), ang_f,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"janela_apagada", boca + Vector3(0.0, 1.16, 0.0),
			Vector3(1.35, 0.32, 0.1), Color("07080a"), ang_f,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"janela_apagada", boca + Vector3(0.0, 1.44, 0.0),
			Vector3(0.78, 0.26, 0.1), Color("07080a"), ang_f,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		# Aduela AZUL em volta do vao: e o que faz o buraco ler como arco e nao
		# como borrao escuro na torre.
		for sx: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"reboco",
				boca + trans * (1.02 * sx) + Vector3(0.0, 0.1, 0.0),
				Vector3(0.34, 2.45, 0.16), AZUL, ang_f,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"reboco", boca + Vector3(0.0, 1.66, 0.0),
			Vector3(1.9, 0.3, 0.16), AZUL, ang_f,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"reboco", boca + Vector3(0.0, -1.18, 0.0),
			Vector3(2.1, 0.24, 0.22), reboco_claro, ang_f,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# O sino: massa escura pendurada no vao. Nao acende, nao toca por si — quem
	# toca e o prop de som da praca, na hora cheia.
	KitModular.caixa_cor(sup, &"metal",
		torre + Vector3(0.0, y_sino + 0.55, 0.0), Vector3(1.4, 0.12, 1.4),
		Color("2b2620"), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal",
		torre + Vector3(0.0, y_sino + 0.05, 0.0), Vector3(0.68, 0.82, 0.68),
		Color("4a3b22"), giro + PI * 0.25, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal",
		torre + Vector3(0.0, y_sino - 0.42, 0.0), Vector3(0.86, 0.14, 0.86),
		Color("3a2e1a"), giro + PI * 0.25, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Cornija do campanario e piramide de telha de verdade. A versao anterior
	# empilhava tres caixas cada vez menores: de perto lia como bolo, e de longe
	# — que e como a torre e vista, espiando por cima da nevoa — lia como borrao.
	KitModular.caixa_cor(sup, &"reboco",
		torre + Vector3(0.0, torre_h - 0.22, 0.0),
		Vector3(torre_l + 0.6, 0.44, torre_l + 0.6), reboco_claro, giro,
		PSXMesh.FACE_TODAS, 2.0)
	telhado_piramide(sup, &"teto", torre + Vector3(0.0, torre_h, 0.0),
		(torre_l + 0.6) * 0.72, 2.3, 4, giro + PI * 0.25, telha, telha_sombra)
	KitModular.caixa_cor(sup, &"metal",
		torre + Vector3(0.0, torre_h + 2.6, 0.0), Vector3(0.12, 0.8, 0.12),
		trim, giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal",
		torre + Vector3(0.0, torre_h + 2.8, 0.0), Vector3(0.52, 0.12, 0.12),
		trim, giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	colisao.append({"tamanho": Vector3(largura + 0.4, parede_h, fundura + 0.4),
		"pos": centro + Vector3(0.0, parede_h * 0.5, 0.0)})
	colisao.append({"tamanho": Vector3(torre_l + 0.4, torre_h + PLINTO, torre_l + 0.4),
		"pos": torre + Vector3(0.0, (torre_h - PLINTO) * 0.5, 0.0)})


## Caiacao dos muros do adro. Um passo abaixo do branco da capela: muro e parede
## sao a mesma tinta, mas o muro pega a chuva de cima e nunca e repintado junto.
const CAIACAO_MURO := Color("efe7d4")
## Rincheira: o capeamento de cimento no topo do muro. E a linha clara que
## desenha o muro contra a grama escura; sem ela ele some no chao.
##
## Vai no material `reboco`, e nao em `concreto_sujo`: a textura de concreto e
## escura, e este tom multiplicado por ela saiu MARROM na primeira captura — o
## capeamento do pilar lia como tampa de madeira.
const RINCHEIRA := Color("cfc8b6")
## Espessura do muro caiado.
const MURO_E := 0.36


## Muro caiado entre dois pontos, com gradil azul opcional por cima.
##
## E o muro da foto 05: alvenaria branca ate a cintura e grade de ferro pintada
## do MESMO azul da capela por cima. O da foto 01, na frente, e o mesmo sem a
## grade. Substitui o muro de pedra cinza do adro, que era vocabulario de matriz
## de cantaria — a capela da referencia e caiada, e o muro dela tambem.
##
## A saia escura no pe e o que prende o muro no chao: muro branco inteiro, a
## noite, sobre grama escura, flutua. E a licao da saia de mofo do casario.
##
## O gradil tem barra de 6 cm a cada 32 cm, e nao a grade fina da foto. A conta
## e a mesma dos balaustres: a 10 m sao 19 px por metro, e barra de 4 cm com vao
## de 20 vira um cinza liso que ainda cintila quando a camera anda.
static func muro_caiado(sup: Dictionary, colisao: Array[Dictionary],
		a: Vector3, b: Vector3, altura: float = 0.95,
		com_gradil: bool = false) -> void:
	var delta := b - a
	var comp := delta.length()
	if comp < 0.3:
		return
	var dir := delta / comp
	var giro := atan2(dir.x, dir.z)
	var meio := a + delta * 0.5
	KitModular.caixa_cor(sup, &"reboco", meio + Vector3(0.0, altura * 0.5, 0.0),
		Vector3(MURO_E, altura, comp), CAIACAO_MURO, giro,
		PSXMesh.FACE_TODAS, 2.0)
	# Dois centimetros mais grossa que o muro de cada lado, e um mais curta nas
	# pontas: a face dela fica NA FRENTE da face do muro, e nunca no mesmo plano.
	KitModular.caixa_cor(sup, &"reboco", meio + Vector3(0.0, 0.18, 0.0),
		Vector3(MURO_E + 0.04, 0.36, comp - 0.02),
		CAIACAO_MURO.lerp(Color("4a4a3c"), 0.55), giro, PSXMesh.FACE_TODAS, 2.0)
	KitModular.caixa_cor(sup, &"reboco",
		meio + Vector3(0.0, altura + 0.05, 0.0),
		Vector3(MURO_E + 0.12, 0.10, comp + 0.08), RINCHEIRA, giro,
		PSXMesh.FACE_TODAS, 2.0)
	var alto_total := altura + 0.10
	if com_gradil:
		const GRADE_H := 0.62
		var y0 := altura + 0.10
		for yb: float in [y0 + 0.05, y0 + GRADE_H]:
			KitModular.caixa_cor(sup, &"reboco", meio + Vector3(0.0, yb, 0.0),
				Vector3(0.06, 0.06, comp), AZUL, giro, PSXMesh.FACE_TODAS, 8.0)
		var n := maxi(1, int(comp / 0.32))
		for i in n + 1:
			var t := float(i) / float(n)
			# Montante a cada oito barras, mais grosso: e o ritmo que diz que a
			# grade e de ferro montado em quadros, e nao uma tela.
			var montante := i % 8 == 0
			var larg := 0.09 if montante else 0.06
			KitModular.caixa_cor(sup, &"reboco",
				a + delta * t + Vector3(0.0, y0 + GRADE_H * 0.5, 0.0),
				Vector3(larg, GRADE_H + (0.06 if montante else 0.0), larg), AZUL,
				giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
		alto_total += GRADE_H
	KitModular.solido(colisao, meio + Vector3(0.0, alto_total * 0.5, 0.0),
		Vector3(MURO_E, alto_total, comp), giro)


## Folha de portao de ferro, aberta, pintada de azul.
##
## `dobradica` e o pe do eixo, `giro_folha` e para onde a folha se estende a
## partir dele. Quadro, travessa do meio e quatro barras: e o minimo que le como
## portao, e nao como grade solta, quando a folha esta de lado para a camera.
static func _folha_portao(sup: Dictionary, colisao: Array[Dictionary],
		dobradica: Vector3, giro_folha: float, largura: float,
		altura: float) -> void:
	var ao_longo := Vector3(cos(giro_folha), 0.0, -sin(giro_folha))
	var meio := dobradica + ao_longo * (largura * 0.5)
	for u: float in [0.04, largura - 0.04]:
		KitModular.caixa_cor(sup, &"reboco",
			dobradica + ao_longo * u + Vector3(0.0, altura * 0.5 + 0.05, 0.0),
			Vector3(0.06, altura, 0.06), AZUL, giro_folha,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	for yb: float in [0.12, altura * 0.55, altura]:
		KitModular.caixa_cor(sup, &"reboco", meio + Vector3(0.0, yb, 0.0),
			Vector3(largura, 0.06, 0.05), AZUL, giro_folha,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	for k in 4:
		var u := largura * float(k + 1) / 5.0
		KitModular.caixa_cor(sup, &"reboco",
			dobradica + ao_longo * u + Vector3(0.0, altura * 0.5 + 0.06, 0.0),
			Vector3(0.045, altura - 0.1, 0.045), AZUL, giro_folha,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	colisao.append({"tamanho": Vector3(largura, altura, 0.08),
		"pos": meio + Vector3(0.0, altura * 0.5, 0.0),
		"giro": Vector3(0.0, giro_folha, 0.0)})


## Pilar de portao caiado, com friso azul, capeamento e pinaculo.
static func _pilar_caiado(sup: Dictionary, colisao: Array[Dictionary],
		p: Vector3, giro: float, lado_p: float, alto: float) -> void:
	KitModular.caixa_cor(sup, &"reboco", p + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(lado_p, alto, lado_p), CAIACAO_MURO, giro, PSXMesh.FACE_TODAS, 2.0)
	KitModular.caixa_cor(sup, &"reboco", p + Vector3(0.0, 0.18, 0.0),
		Vector3(lado_p + 0.04, 0.36, lado_p + 0.04),
		CAIACAO_MURO.lerp(Color("4a4a3c"), 0.55), giro, PSXMesh.FACE_TODAS, 2.0)
	# Friso azul logo abaixo do capeamento: o pilar e o unico vertical do muro, e
	# o azul nele e o que liga o portao a capela a vinte metros dali.
	KitModular.caixa_cor(sup, &"reboco", p + Vector3(0.0, alto - 0.14, 0.0),
		Vector3(lado_p + 0.04, 0.14, lado_p + 0.04), AZUL, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"reboco", p + Vector3(0.0, alto + 0.06, 0.0),
		Vector3(lado_p + 0.18, 0.12, lado_p + 0.18), RINCHEIRA, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"reboco", p + Vector3(0.0, alto + 0.30, 0.0),
		Vector3(lado_p * 0.5, lado_p * 0.5, lado_p * 0.5), CAIACAO_MURO,
		giro + PI * 0.25, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.solido(colisao, p + Vector3(0.0, alto * 0.5, 0.0),
		Vector3(lado_p, alto, lado_p), giro)


## Adro da capela: muro caiado na frente, portao de ferro azul ABERTO no eixo da
## porta, nicho de vela em cada pilar e a placa de pedra no muro (foto 01).
##
## Devolve o ponto de cada nicho, para quem chama acender a vela ali.
##
## O muro existe por tres razoes, nessa ordem, e as tres continuam de pe:
##
## 1. O take da revelacao (`praca_5`) nao tinha nada entre a lente e a fachada.
##    Um muro de 90 cm atravessando o terco inferior do quadro poe a igreja ATRAS
##    de alguma coisa, que e o comeco de estar longe.
## 2. Separa o chao da igreja — o gramado — do chao da praca, que e pedra.
## 3. Portao ABERTO num muro fechado e uma decisao: o jogo esta convidando a
##    entrar. As folhas ficam escancaradas para dentro, na grama.
static func adro_capela(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, largura: float, giro: float,
		meia_abertura: float = 1.7) -> Array[Vector3]:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	const ALTURA := 0.92
	const PILAR := 0.62
	const PILAR_H := 1.62
	var meia := largura * 0.5
	var nichos: Array[Vector3] = []

	# Os dois trechos de muro, do pilar ate a ponta. A ponta PARA meia espessura
	# antes de `meia`: la ela encontra o muro lateral, que e mais alto, e a face
	# de ponta fica escondida dentro dele em vez de dividir plano com ele.
	for sx: float in [-1.0, 1.0]:
		muro_caiado(sup, colisao,
			centro + lado * ((meia_abertura + PILAR * 0.5) * sx),
			centro + lado * ((meia - MURO_E * 0.5) * sx), ALTURA)

	for sx: float in [-1.0, 1.0]:
		var p := centro + lado * (meia_abertura * sx)
		_pilar_caiado(sup, colisao, p, giro, PILAR, PILAR_H)
		# Nicho de vela na face que olha a praca: rebaixo escuro, a chama e o
		# peitoril. E a vela que o viajante acende ao passar, e o unico ponto de
		# luz baixa entre o calcamento e a fachada.
		var boca := p + frente * (PILAR * 0.5 + 0.015) + Vector3(0.0, 1.02, 0.0)
		KitModular.caixa_cor(sup, &"janela_apagada", boca,
			Vector3(0.30, 0.40, 0.03), Color("0d0c0a"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa(sup, &"janela_acesa",
			boca + frente * 0.02 + Vector3(0.0, -0.08, 0.0),
			Vector3(0.10, 0.17, 0.02), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			boca + frente * 0.04 + Vector3(0.0, -0.22, 0.0),
			Vector3(0.38, 0.05, 0.10), RINCHEIRA, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		nichos.append(boca + frente * 0.35)

	# As duas folhas, escancaradas para DENTRO, a 75 graus. Fechadas elas
	# ficariam no plano do muro; abertas, na grama, uma de cada lado do caminho.
	var folha := meia_abertura - PILAR * 0.5 - 0.04
	var abre := deg_to_rad(75.0)
	_folha_portao(sup, colisao,
		centro - lado * (meia_abertura - PILAR * 0.5 - 0.02) - frente * 0.05,
		giro + abre, folha, 1.12)
	_folha_portao(sup, colisao,
		centro + lado * (meia_abertura - PILAR * 0.5 - 0.02) - frente * 0.05,
		giro + PI - abre, folha, 1.12)

	# A placa de pedra no muro, a direita do portao (foto 01). Ilegivel a
	# 480x270, e tem de ser: e uma placa, e o jogador vai querer chegar perto.
	var placa := centro + lado * (meia_abertura + 2.6) \
		+ frente * (MURO_E * 0.5) + Vector3(0.0, 0.60, 0.0)
	KitModular.caixa_cor(sup, &"concreto_sujo", placa + frente * 0.015,
		Vector3(0.76, 0.56, 0.03), RINCHEIRA, giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo", placa + frente * 0.04,
		Vector3(0.62, 0.44, 0.03), Color("24221e"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	for k in 3:
		KitModular.caixa_cor(sup, &"concreto_sujo",
			placa + frente * 0.058 + Vector3(0.0, 0.10 - float(k) * 0.09, 0.0),
			Vector3(0.44 - float(k % 2) * 0.12, 0.025, 0.01), Color("6d685c"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	return nichos


## Portao lateral do adro: dois pilares baixos e UMA folha azul aberta.
##
## E o portaozinho azul da foto 05, ao lado do anexo pequeno. Aberto pelo mesmo
## motivo do portao da frente: o adro tem saida para a rua do casario, e o
## jogador que contorna a capela tem de achar por onde sair.
static func portao_lateral(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float, meia: float) -> void:
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	const PILAR := 0.46
	for sx: float in [-1.0, 1.0]:
		_pilar_caiado(sup, colisao, centro + lado * (meia * sx), giro, PILAR, 1.30)
	_folha_portao(sup, colisao,
		centro - lado * (meia - PILAR * 0.5 - 0.02),
		giro + deg_to_rad(80.0), meia * 2.0 - PILAR - 0.06, 1.10)


## Cruz branca de madeira, fincada na grama (foto 05, a esquerda da fachada).
##
## Fina e alta, pintada de branco: e a cruz das almas, a que se planta no adro.
## Dois graus fora de prumo, porque madeira fincada em terra assenta torta.
static func cruz_branca(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, altura: float, giro: float) -> void:
	var eixo := Basis(Vector3.UP, giro) * Basis(Vector3(0.0, 0.0, 1.0), 0.035)
	var branco := Color("f2eee4")
	KitModular.caixa_cor(sup, &"concreto_sujo", base + Vector3(0.0, 0.08, 0.0),
		Vector3(0.46, 0.16, 0.46), Color("8e8a7c"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_livre(sup, &"tabua", base + eixo * Vector3(0.0, altura * 0.5, 0.0),
		Vector3(0.13, altura, 0.11), eixo, branco, QUAD_FOLHA)
	KitModular.caixa_livre(sup, &"tabua", base + eixo * Vector3(0.0, altura * 0.74, 0.0),
		Vector3(1.10, 0.13, 0.11), eixo, branco, QUAD_FOLHA)
	colisao.append({"tamanho": Vector3(0.3, altura, 0.3),
		"pos": base + Vector3(0.0, altura * 0.5, 0.0)})


## Toco de tora fincado: o frade de madeira da foto 01, em volta do cruzeiro.
## Duas caixas a 45 graus leem como roliço, e a tampa clara e o corte da serra.
static func toco(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		altura: float, giro: float) -> void:
	# Alfa 0: rigido. `casca` tem vento, e com o alfa 1 do caixa_cor o toco
	# inteiro deslizava 32 cm enquanto a tampa (tabua, sem vento) ficava parada.
	var casca := Color(Color("7d6a52"), 0.0)
	for k in 2:
		KitModular.caixa_cor(sup, &"casca", base + Vector3(0.0, altura * 0.5, 0.0),
			Vector3(0.28, altura, 0.28), casca, giro + PI * 0.25 * float(k),
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"tabua", base + Vector3(0.0, altura + 0.01, 0.0),
		Vector3(0.24, 0.03, 0.24), Color("b39c78"), giro + PI * 0.125,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	colisao.append({"tamanho": Vector3(0.3, altura, 0.3),
		"pos": base + Vector3(0.0, altura * 0.5, 0.0)})


## Cruz de pedra fincada, levemente fora de prumo. Peca de adro.
##
## Tres ou quatro delas de lado, nunca em fileira e nunca no eixo: fileira le
## como cemiterio, e cemiterio e outra cena. Tortas porque pedra fincada em
## terra batida ha cem anos nao fica reta, e porque o olho estranha antes de
## saber por que.
static func cruz_de_pedra(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, altura: float, giro: float, tombo: float) -> void:
	var pedra := Color("5e5a51")
	var eixo := Basis(Vector3.UP, giro) * Basis(Vector3(0.0, 0.0, 1.0), tombo)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		base + Vector3(0.0, 0.12, 0.0), Vector3(0.5, 0.24, 0.5),
		pedra.lerp(Color("3f3d36"), 0.4), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_livre(sup, &"concreto_sujo",
		base + eixo * Vector3(0.0, altura * 0.5 + 0.2, 0.0),
		Vector3(0.16, altura, 0.16), eixo, pedra, QUAD_FOLHA)
	KitModular.caixa_livre(sup, &"concreto_sujo",
		base + eixo * Vector3(0.0, altura * 0.78 + 0.2, 0.0),
		Vector3(0.62, 0.16, 0.16), eixo, pedra, QUAD_FOLHA)
	colisao.append({"tamanho": Vector3(0.5, altura, 0.5),
		"pos": base + Vector3(0.0, altura * 0.5, 0.0)})


## Uma barra reta inclinada no plano da cruz.
##
## Existe porque o cruzeiro tem onze pecas em diagonal e escrever a Basis em
## cada uma e onde nasce erro de sinal. `ang` e medido a partir da VERTICAL, e
## positivo inclina a ponta de cima para o lado de `lado` — a mesma convencao da
## rampa do frontao, para nao haver duas.
static func _barra(sup: Dictionary, centro: Vector3, comprimento: float,
		espessura: float, ang: float, giro: float, cor: Color) -> void:
	var eixo := Basis(Vector3.UP, giro) * Basis(Vector3(0.0, 0.0, 1.0), ang)
	KitModular.caixa_livre(sup, &"metal", centro,
		Vector3(espessura, comprimento, espessura), eixo, cor, QUAD_FOLHA)


## Chapa dos Instrumentos da Paixao: ferro chato pintado de cinza claro.
##
## E o que a foto 03 mostra, e e tambem o que sobrevive a noite: barras de 4 a 10
## cm contra o ceu preto so aparecem se forem CLARAS. A versao anterior usava um
## cinza-oliva escuro e, de perto, o cruzeiro virava um emaranhado de riscos
## pretos em que nenhum instrumento se lia.
const CRUZEIRO_METAL := Color("bdbab0")
const CRUZEIRO_METAL_FOSCO := Color("a3a097")
## Madeira do mastro e da travessa: castanho avermelhado de madeira de lei
## (amostrado na foto 03: 84,62,39 na sombra e mais claro no lado do sol). O
## marrom quase preto de antes sumia na nevoa e deixava os instrumentos boiando.
const CRUZEIRO_MADEIRA := Color("a06a44")
## Cal do pedestal: branco sujo, um passo abaixo do branco da capela, e o espelho
## dos degraus mais sujo que o chanfro — e onde respinga a chuva.
const CRUZEIRO_CAL := Color("e3d9c5")
const CRUZEIRO_CAL_SUJA := Color("c9bda8")
## A corda do acoite, a unica peca escura do conjunto.
const CRUZEIRO_CORDA := Color("3b3833")
## Tinta das letras do INRI.
const CRUZEIRO_LETRA := Color("2c2a26")

## Espessura minima de instrumento, em metros.
##
## Do pin do acordar ao cruzeiro sao 8,7 m, e a 480x270 com FOV 70 isso da 39
## px/m. 0,07 m e portanto 2,7 px: o piso do que ainda e uma barra em vez de
## ruido. Abaixo disso o instrumento some e sobra o mastro.
const CRUZEIRO_FINO := 0.07


## Uma chapa reta entre dois pontos do PLANO DA CRUZ.
##
## Os pontos sao (u, v): `u` ao longo da travessa (o `lado` do cruzeiro) e `v` a
## altura acima da base. `z` e o afastamento a frente do plano do mastro.
##
## Escrever cada peca pelas duas pontas, e nao por centro e angulo, e o que deixou
## COPIAR a foto: cada instrumento foi medido nela como dois pontos em relacao ao
## mastro e a travessa, e a conta do angulo mora aqui, uma vez so.
## `Basis(Z, a)` leva o +Y local para (-sin a, cos a), dai o `atan2(-du, dv)`.
static func _chapa(sup: Dictionary, base: Vector3, giro: float, de: Vector2,
		ate: Vector2, z: float, largura: float, espessura: float,
		cor: Color) -> void:
	var d := ate - de
	var comp := d.length()
	if comp < 0.001:
		return
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var meio := (de + ate) * 0.5
	var eixo := Basis(Vector3.UP, giro) * Basis(Vector3(0.0, 0.0, 1.0), atan2(-d.x, d.y))
	# `reboco`, e nao `metal`: a textura de metal e escura e o cinza claro saia
	# grafite na primeira captura. Chapa PINTADA e fosca, e fosco claro e o que o
	# reboco da.
	KitModular.caixa_livre(sup, &"reboco",
		base + lado * meio.x + Vector3(0.0, meio.y, 0.0) + frente * z,
		Vector3(largura, comp, espessura), eixo, cor, QUAD_FOLHA)


## Tronco de piramide de base quadrada: o chanfro de cada degrau do pedestal.
##
## Quatro aguas planas e nenhuma tampa. A de cima e coberta pelo degrau seguinte
## — por isso `meia_topo` tem de ser a meia aresta DELE, senao sobra uma fresta
## de 13 cm por onde se ve o miolo vazio — e a de baixo pousa no degrau anterior.
static func _chanfro(sup: Dictionary, base: Vector3, meia_base: float,
		meia_topo: float, altura: float, giro: float, cor: Color) -> void:
	for k in 4:
		var n := Vector3(sin(giro + PI * 0.5 * float(k)), 0.0, cos(giro + PI * 0.5 * float(k)))
		var t := Vector3(n.z, 0.0, -n.x)
		var topo := base + Vector3(0.0, altura, 0.0)
		agua_de_telhado(sup, &"reboco",
			base + n * meia_base - t * meia_base, base + n * meia_base + t * meia_base,
			topo + n * meia_topo + t * meia_topo, topo + n * meia_topo - t * meia_topo,
			cor, (n * altura + Vector3(0.0, meia_base - meia_topo, 0.0)).normalized(),
			0.5, 4.0)


## Cruzeiro da praca, copiado da foto 03 (`PRINTS/ref_igreja_azul/03_cruzeiro_hoje`,
## a vista de frente dele): mastro de madeira sobre pedestal caiado de tres
## degraus chanfrados, e os Instrumentos da Paixao em chapa cinza no plano da cruz.
##
## Da esquerda para a direita, como a foto mostra:
##   - o X de duas chapas na ponta esquerda da travessa;
##   - o MARTELO pendurado de cabeca para cima, logo dentro dele;
##   - a LANCA e a VARA da esponja, quase paralelas, subindo para a esquerda a
##     partir de um ponto do mastro 1,8 m abaixo da travessa;
##   - o U grande, centrado no mastro, pendurado da travessa;
##   - a COROA, argola no cruzamento;
##   - a ESCADA, do mesmo ponto de baixo, subindo para a direita alem da travessa;
##   - uma plaquinha pendurada a direita do U;
##   - a CORDA, escura, em laco da escada ate a ponta direita;
##   - o INRI no mastro, acima da travessa, e o GALO no topo.
##
## Proporcoes medidas na foto contra a largura do mastro (10 px) e a travessa
## (191 px): travessa de 2,9 m, mastro de 17 cm. A lanca, a vara e a escada
## convergem no MESMO ponto do mastro — e o V dessa convergencia, mais o U, que
## desenham a silhueta de longe; o resto e o que se ve chegando perto.
##
## Profundidades, para nada dividir plano com nada (a frente do eixo do mastro):
##   0,085  face do mastro e da travessa
##   0,11   INRI, plaquinha
##   0,13   U, X, martelo, coroa (0,14)
##   0,16   corda
##   0,20   lanca e escada          0,24  vara e esponja
##
## Continua caixa, e nao silhueta em textura, pelo motivo de sempre: o TAKE 1 da
## abertura gira a camera em volta dele a 8,7 m, e recorte plano vira folha de
## papel no instante em que a camera sai de frente.
static func cruzeiro(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float = 0.0) -> void:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var metal := CRUZEIRO_METAL
	var fosco := CRUZEIRO_METAL_FOSCO

	# --- pedestal caiado: tres degraus, os dois de baixo com chanfro ---------
	#
	# Era cantaria cinza em degraus retos com um dado alto: pedestal de matriz de
	# cidade. O da foto e alvenaria caiada, baixa, com o topo de cada degrau em
	# rampa — o chanfro e o que faz a agua escorrer, e e ele que da o perfil de
	# "bolo de noiva" que a foto tem.
	KitModular.caixa_cor(sup, &"reboco", base + Vector3(0.0, 0.08, 0.0),
		Vector3(2.0, 0.16, 2.0), CRUZEIRO_CAL_SUJA, giro,
		PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, 2.0)
	_chanfro(sup, base + Vector3(0.0, 0.16, 0.0), 1.0, 0.65, 0.13, giro, CRUZEIRO_CAL)
	KitModular.caixa_cor(sup, &"reboco", base + Vector3(0.0, 0.36, 0.0),
		Vector3(1.30, 0.14, 1.30), CRUZEIRO_CAL_SUJA.lerp(CRUZEIRO_CAL, 0.5), giro,
		PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, 2.0)
	_chanfro(sup, base + Vector3(0.0, 0.43, 0.0), 0.65, 0.37, 0.11, giro, CRUZEIRO_CAL)
	KitModular.caixa_cor(sup, &"reboco", base + Vector3(0.0, 0.72, 0.0),
		Vector3(0.74, 0.36, 0.74), CRUZEIRO_CAL, giro,
		PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, 2.0)
	var pe := 0.90

	# --- mastro e travessa ---------------------------------------------------
	const MASTRO_H := 5.50
	KitModular.caixa_cor(sup, &"tabua",
		base + Vector3(0.0, pe + MASTRO_H * 0.5, 0.0),
		Vector3(0.17, MASTRO_H, 0.17), CRUZEIRO_MADEIRA, giro,
		PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, 3.0)
	var t := pe + 4.10
	KitModular.caixa_cor(sup, &"tabua", base + Vector3(0.0, t, 0.0),
		Vector3(2.90, 0.17, 0.17), CRUZEIRO_MADEIRA, giro,
		PSXMesh.FACE_TODAS, 3.0)
	_galo(sup, base + Vector3(0.0, pe + MASTRO_H, 0.0), giro)

	# --- INRI ----------------------------------------------------------------
	# Chapa clara no mastro, 74 cm acima da travessa, com as quatro letras em
	# traco escuro. As letras retas so tem a face da frente: sao tinta, e tinta
	# nao tem lado.
	var inri := base + frente * 0.105 + Vector3(0.0, t + 0.74, 0.0)
	KitModular.caixa_cor(sup, &"reboco", inri, Vector3(0.46, 0.27, 0.04), metal,
		giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	var letra := inri + frente * 0.021
	for u: float in [-0.155, -0.080, -0.020, 0.035, 0.155]:
		KitModular.caixa_cor(sup, &"reboco", letra + lado * u,
			Vector3(0.032, 0.15, 0.004), CRUZEIRO_LETRA, giro,
			PSXMesh.FACE_FRENTE, QUAD_FOLHA)
	# Bojo do R: a barra de cima, a do meio e o fecho a direita.
	for v: float in [0.0605, 0.0]:
		KitModular.caixa_cor(sup, &"reboco", letra + lado * 0.063 + Vector3(0.0, v, 0.0),
			Vector3(0.056, 0.029, 0.004), CRUZEIRO_LETRA, giro,
			PSXMesh.FACE_FRENTE, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"reboco", letra + lado * 0.088 + Vector3(0.0, 0.03, 0.0),
		Vector3(0.029, 0.06, 0.004), CRUZEIRO_LETRA, giro,
		PSXMesh.FACE_FRENTE, QUAD_FOLHA)
	# As duas diagonais: a do N e a perna do R.
	var inri_uv := Vector2(0.0, t + 0.74)
	_chapa(sup, base, giro, inri_uv + Vector2(-0.080, 0.070),
		inri_uv + Vector2(-0.020, -0.070), 0.127, 0.03, 0.004, CRUZEIRO_LETRA)
	_chapa(sup, base, giro, inri_uv + Vector2(0.050, -0.005),
		inri_uv + Vector2(0.092, -0.075), 0.127, 0.03, 0.004, CRUZEIRO_LETRA)

	# --- a esquerda: o X e o martelo ----------------------------------------
	var x_c := Vector2(-1.30, t - 0.08)
	_chapa(sup, base, giro, x_c + Vector2(-0.19, -0.19), x_c + Vector2(0.19, 0.19),
		0.13, CRUZEIRO_FINO, 0.035, metal)
	_chapa(sup, base, giro, x_c + Vector2(-0.19, 0.19), x_c + Vector2(0.19, -0.19),
		0.13, CRUZEIRO_FINO, 0.035, fosco)
	# Martelo de cabeca para cima: o cabo desce da travessa, a cabeca fica
	# por cima dela — e o T que se ve na foto junto da ponta.
	_chapa(sup, base, giro, Vector2(-0.93, t + 0.09), Vector2(-0.93, t - 0.42),
		0.13, 0.05, 0.035, metal)
	_chapa(sup, base, giro, Vector2(-1.05, t + 0.12), Vector2(-0.81, t + 0.12),
		0.13, 0.08, 0.05, metal)

	# --- o V: lanca, vara e escada saindo do mesmo ponto do mastro ----------
	var v_pe := t - 1.80
	# A LANCA, com a folha da ponta em duas chapas cada vez mais estreitas.
	var lanca_de := Vector2(0.02, v_pe)
	var lanca_ate := Vector2(-0.86, t + 0.30)
	var lanca_dir := (lanca_ate - lanca_de).normalized()
	_chapa(sup, base, giro, lanca_de, lanca_ate, 0.20, 0.05, 0.035, metal)
	_chapa(sup, base, giro, lanca_ate - lanca_dir * 0.02, lanca_ate + lanca_dir * 0.13,
		0.20, 0.11, 0.03, metal)
	_chapa(sup, base, giro, lanca_ate + lanca_dir * 0.12, lanca_ate + lanca_dir * 0.22,
		0.20, 0.05, 0.03, metal)
	# A VARA, quase paralela, e a esponja na ponta: o unico volume gordo, que e
	# o que diz que aquela haste nao e uma segunda lanca.
	var vara_ate := Vector2(-0.66, t + 0.44)
	_chapa(sup, base, giro, Vector2(0.06, v_pe + 0.06), vara_ate, 0.24, 0.04, 0.03, fosco)
	KitModular.caixa_livre(sup, &"reboco",
		base + lado * vara_ate.x + Vector3(0.0, vara_ate.y + 0.05, 0.0) + frente * 0.24,
		Vector3(0.13, 0.11, 0.08),
		Basis(Vector3.UP, giro) * Basis(Vector3(0.0, 0.0, 1.0), PI * 0.25), fosco,
		QUAD_FOLHA)
	# A ESCADA: duas longarinas e oito degraus, perpendiculares a elas.
	var esc_de := Vector2(0.04, v_pe)
	var esc_ate := Vector2(1.16, t + 0.80)
	var esc_dir := (esc_ate - esc_de).normalized()
	var esc_n := Vector2(esc_dir.y, -esc_dir.x) * 0.11
	for sx: float in [-1.0, 1.0]:
		_chapa(sup, base, giro, esc_de + esc_n * sx, esc_ate + esc_n * sx,
			0.20, 0.05, 0.035, metal)
	var esc_comp := esc_de.distance_to(esc_ate)
	for k in 8:
		var c := esc_de + esc_dir * lerpf(0.22, esc_comp - 0.14, float(k) / 7.0)
		_chapa(sup, base, giro, c - esc_n, c + esc_n, 0.20, 0.045, 0.03, fosco)

	# --- o U, a coroa e a plaquinha ------------------------------------------
	var u_pts: Array[Vector2] = [
		Vector2(-0.47, t - 0.02), Vector2(-0.40, t - 0.50), Vector2(-0.31, t - 0.61),
		Vector2(0.27, t - 0.61), Vector2(0.37, t - 0.50), Vector2(0.49, t - 0.02),
	]
	for k in u_pts.size() - 1:
		_chapa(sup, base, giro, u_pts[k], u_pts[k + 1], 0.13, 0.10, 0.04, metal)
	for k in 6:
		var a0 := TAU * float(k) / 6.0
		var a1 := TAU * float(k + 1) / 6.0
		_chapa(sup, base, giro, Vector2(cos(a0), sin(a0)) * 0.13 + Vector2(0.0, t),
			Vector2(cos(a1), sin(a1)) * 0.13 + Vector2(0.0, t), 0.14, 0.04, 0.03, fosco)
	_chapa(sup, base, giro, Vector2(0.60, t - 0.15), Vector2(0.60, t - 0.39),
		0.11, 0.10, 0.03, fosco)

	# --- a corda: laco escuro da escada ate a ponta direita -----------------
	var corda: Array[Vector2] = [
		Vector2(0.97, t + 0.30), Vector2(1.06, t - 0.08), Vector2(1.17, t - 0.30),
		Vector2(1.32, t - 0.29), Vector2(1.43, t - 0.05),
	]
	for k in corda.size() - 1:
		_chapa(sup, base, giro, corda[k], corda[k + 1], 0.16, 0.035, 0.035,
			CRUZEIRO_CORDA)

	# Colisao: o pedestal e uma caixa, o mastro outra. Os instrumentos nao
	# colidem — estao a tres metros do chao e uma caixa em volta deles seria um
	# muro invisivel no meio do largo.
	colisao.append({"tamanho": Vector3(2.0, pe, 2.0),
		"pos": base + Vector3(0.0, pe * 0.5, 0.0), "giro": Vector3(0.0, giro, 0.0)})
	colisao.append({"tamanho": Vector3(0.4, MASTRO_H, 0.4),
		"pos": base + Vector3(0.0, pe + MASTRO_H * 0.5, 0.0),
		"giro": Vector3(0.0, giro, 0.0)})


## O galo de cata-vento do alto do cruzeiro, de perfil, olhando para `lado`.
##
## `topo` e o topo do mastro. Cada peca e [u ao longo de `lado`, altura, largura,
## altura da caixa, inclinacao no plano da cruz].
##
## Na v3 ele encolheu para 75% e ficou da chapa CLARA dos instrumentos. A foto
## 05 mostra um galo de cobre num outro cruzeiro; a 03, que e a deste, mostra no
## topo do mastro uma figura pequena de metal claro, do tamanho do INRI.
const GALO: Array[Array] = [
	[0.00, 0.17, 0.05, 0.34, 0.0],     # haste
	[-0.02, 0.46, 0.50, 0.24, 0.08],   # corpo
	[0.20, 0.64, 0.14, 0.30, -0.25],   # peito e pescoco
	[0.25, 0.80, 0.15, 0.13, 0.0],     # cabeca
	[0.23, 0.90, 0.12, 0.08, 0.0],     # crista
	[0.35, 0.79, 0.09, 0.05, 0.0],     # bico
	[0.29, 0.70, 0.05, 0.08, 0.0],     # barbela
	[-0.32, 0.64, 0.34, 0.10, -0.80],  # pena do rabo
	[-0.24, 0.76, 0.40, 0.09, -1.20],  # pena alta do rabo
]


static func _galo(sup: Dictionary, topo: Vector3, giro: float) -> void:
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	const ESCALA := 0.75
	for p: Array in GALO:
		KitModular.caixa_livre(sup, &"reboco",
			topo + (lado * float(p[0]) + Vector3(0.0, float(p[1]), 0.0)) * ESCALA,
			Vector3(maxf(0.05, float(p[2]) * ESCALA), maxf(0.05, float(p[3]) * ESCALA), 0.07),
			Basis(Vector3.UP, giro) * Basis(Vector3(0.0, 0.0, 1.0), float(p[4])),
			CRUZEIRO_METAL_FOSCO, QUAD_FOLHA)


## Guarda-corpo rustico de madeira: montantes e duas travessas horizontais.
##
## E a cerca da `03_cruzeiro_hoje.png` — a que separa o canteiro do calcamento
## sem fechar nada. Diferente do `gradil`, que e de ferro e serve a rua: este e
## de tora lascada, tem vao de sobra e existe para o olho saber onde o chao
## muda de material.
static func guarda_corpo_rustico(sup: Dictionary, colisao: Array[Dictionary],
		de: Vector3, ate: Vector3) -> void:
	var eixo := ate - de
	var comp := eixo.length()
	if comp < 0.6:
		return
	var giro := atan2(eixo.x, eixo.z)
	# Tora de eucalipto tratado, castanho AVERMELHADO — amostrado na foto 03
	# (67,37,27 na sombra). O marrom-oliva de antes lia como caibro serrado.
	var madeira := Color("6f3a22")
	var madeira_clara := Color("8a4a2b")
	const ALTURA := 0.86
	# Passo de 1,5 m, que e o da foto. O montante passa 6 cm da travessa de cima.
	var n := maxi(2, int(round(comp / 1.5)))
	for i in n + 1:
		var p := de.lerp(ate, float(i) / float(n))
		# Girado 45 graus em planta: o quadrado vira losango, a luz de vertice
		# pega duas faces com tons diferentes e o montante le como rolico.
		KitModular.caixa_cor(sup, &"tabua",
			p + Vector3(0.0, (ALTURA + 0.06) * 0.5, 0.0),
			Vector3(0.13, ALTURA + 0.06, 0.13), madeira, giro + PI * 0.25,
			PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, 3.0)
	var meio := de.lerp(ate, 0.5)
	# Tres travessas, e nao duas: e o ritmo da foto. Tambem giradas 45 graus no
	# proprio eixo, pelo mesmo motivo do montante.
	var rolico := Basis(Vector3.UP, giro) * Basis(Vector3(0.0, 0.0, 1.0), PI * 0.25)
	for alt: float in [0.26, 0.54, 0.82]:
		KitModular.caixa_livre(sup, &"tabua", meio + Vector3(0.0, alt, 0.0),
			Vector3(0.09, 0.09, comp + 0.08), rolico, madeira_clara, 3.0)
	colisao.append({"tamanho": Vector3(0.24, ALTURA, comp),
		"pos": meio + Vector3(0.0, ALTURA * 0.5, 0.0),
		"giro": Vector3(0.0, giro, 0.0)})


## Canteiro de praca: murete baixo de alvenaria com terra dentro e arbustos.
##
## A `03_cruzeiro_hoje.png` tem tres deles em volta do cruzeiro, e eles resolvem
## um problema que a praca tem de sobra: calcamento nu. Um retangulo de terra
## com murete de 22 cm quebra o piso sem construir nada, e o arbusto poe verde
## na altura da cintura, que e a altura em que a praca nao tem NADA hoje.
static func canteiro(sup: Dictionary, colisao: Array[Dictionary],
		retangulo: Rect2, semente: int) -> void:
	# Murete de 34 cm e terra a 28. A terra ficava em Y_TERRA (0,18), ABAIXO do
	# calcamento (0,22): canteiro pousado na pedra tinha a propria terra escondida
	# debaixo do ladrilho, e o que se via dentro do murete era mais pedra com
	# arbusto brotando dela. Agora a terra passa por cima de qualquer piso da
	# praca, inclusive a laje de placas do cruzeiro (0,25), e continua abaixo da
	# borda do murete — terra no nivel da borda le como tampa.
	const MURETE := 0.34
	const LARG := 0.25
	# Borda de pedra CLARA, no `reboco`: a da foto 03 e quartzito branco, e o
	# cinza escuro do `concreto_sujo` fazia o canteiro sumir no calcamento.
	var pedra := Color("d3ccbc")
	var r := retangulo
	piso(sup, &"terra", r.grow(-LARG), Y_CANTEIRO, Color(0.40, 0.34, 0.26))
	for eixo_x in [true, false]:
		for s: float in [0.0, 1.0]:
			var c: Vector3
			var t: Vector3
			if eixo_x:
				c = Vector3(r.get_center().x, MURETE * 0.5,
					lerpf(r.position.y + LARG * 0.5, r.end.y - LARG * 0.5, s))
				t = Vector3(r.size.x, MURETE, LARG)
			else:
				c = Vector3(lerpf(r.position.x + LARG * 0.5, r.end.x - LARG * 0.5, s),
					MURETE * 0.5, r.get_center().y)
				t = Vector3(LARG, MURETE, r.size.y - LARG * 2.0)
			KitModular.caixa_cor(sup, &"reboco", c, t,
				pedra.lerp(Color("a79f8e"), 0.3 * s), 0.0,
				PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, 2.0)
	colisao.append({"tamanho": Vector3(r.size.x, MURETE, r.size.y),
		"pos": Vector3(r.get_center().x, MURETE * 0.5, r.get_center().y)})
	# Arbustos espalhados por sorteio PURO do indice: dois chunks podem desenhar
	# pedacos do mesmo canteiro e tem de concordar sobre onde esta cada moita.
	var n := maxi(2, int(r.get_area() / 3.2))
	for i in n:
		var h := (semente * 2654435761) ^ (i * 40503) ^ 733
		h = (h ^ (h >> 13)) * 1274126177
		var u := float(absi(h ^ (h >> 16)) % 997) / 997.0
		var v := float(absi(h ^ (h >> 11)) % 991) / 991.0
		var p := Vector3(lerpf(r.position.x + 0.5, r.end.x - 0.5, u), Y_CANTEIRO,
			lerpf(r.position.y + 0.5, r.end.y - 0.5, v))
		if p.x < -1.0 or p.x > KitModular.CHUNK + 1.0:
			continue
		if p.z < -1.0 or p.z > KitModular.CHUNK + 1.0:
			continue
		# Gerador PROPRIO por moita, semeado pelo indice.  consome um
		# numero variavel de sorteios (dois ou tres blocos), e um fluxo
		# compartilhado faria o canteiro divergir entre dois chunks que
		# desenham pedacos dele. Ver a nota de determinismo do ParqueBuilder.
		var rng := RandomNumberGenerator.new()
		rng.seed = h
		# Uma em tres e agave, e nao moita: a foto 03 mostra rosetas de folha
		# pontuda entre os arbustos, e e a silhueta espetada que diz "canteiro de
		# praca" em vez de "sebe cortada". Flor vermelha na beira de algumas.
		if i % 3 == 0:
			agave(sup, p, lerpf(0.55, 0.8, v), u * TAU)
		else:
			arbusto(sup, p, lerpf(0.45, 0.78, u), rng)
		if i % 2 == 1:
			moita_de_flor(sup, p + Vector3(0.22, 0.0, 0.12), Vector2i(i % 4, 0),
				0.42, v * PI, Color(1.0, 0.82, 0.8))


## Agave: roseta de sete folhas pontudas saindo do chao, abertas para fora.
##
## Verde-acinzentado, e nao o verde da moita: e a cor da planta, e e o que a
## separa do arbusto ao lado quando as duas viram mancha na nevoa.
static func agave(sup: Dictionary, base: Vector3, altura: float, giro: float) -> void:
	var cor := Color("7d9178")
	for k in 7:
		var ang := giro + TAU * float(k) / 7.0
		# Folhas de fora mais deitadas, a do miolo quase em pe.
		var abre := lerpf(0.35, 0.95, float(k % 3) / 2.0)
		var comp := altura * lerpf(0.8, 1.1, float((k * 5) % 7) / 6.0)
		var eixo := Basis(Vector3.UP, ang) * Basis(Vector3.RIGHT, abre)
		KitModular.caixa_flex_inclinada(sup, &"arbusto",
			base + eixo * Vector3(0.0, comp * 0.5, 0.0),
			Vector3(0.11, comp, 0.03), cor.lerp(Color("5d6f55"), float(k % 2) * 0.5),
			eixo, base.y, base.y + altura, 0.2, 0.5, QUAD_FOLHA)


## Campo santo: o cemiterio murado atras da matriz.
##
## Nasceu de uma observacao que eu tinha deixado passar. Eu vinha ajustando a
## praca pelo quadro da cutscene, que olha a igreja de frente; mas a praca e
## espaco que o jogador ANDA, e a planta de cima mostrava o que a cutscene nunca
## enquadra — de calcamento nu, do fundo da igreja ate a rua, um vazio maior que
## a praca inteira. Cenario que so funciona de um angulo nao e cenario, e
## decoracao de palco.
##
## Cemiterio atras da igreja e a disposicao colonial correta (o campo santo da
## matriz), resolve o vazio com o assunto que a cena ja tem, e nao inventa
## enredo nenhum: uma igreja de 1800 tem mortos no quintal.
##
## Tres coisas sustentam a leitura a 480x270:
##   - o MURO, que fecha a silhueta e diz "outro recinto";
##   - as CRUZES em fileira torta, que sao verticais repetidas — o olho conta
##     antes de identificar;
##   - os tumulos de caixa, massas grandes que sobrevivem a minificacao quando
##     as cruzes ja viraram risco.
static func campo_santo(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, tamanho: Vector2, giro: float, semente: int) -> void:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	var pedra := Color("6a665c")
	var pedra_topo := Color("878175")
	const MURO_H := 1.45
	const MURO_E := 0.4
	var hx := tamanho.x * 0.5
	var hz := tamanho.y * 0.5
	# Portao no meio do lado que olha a igreja (frente).
	const MEIA_PORTA := 1.5

	for sz: float in [-1.0, 1.0]:
		# O lado da frente e o unico partido; o de tras e corrido.
		if sz > 0.0:
			for sx: float in [-1.0, 1.0]:
				var comp := hx - MEIA_PORTA
				if comp <= 0.2:
					continue
				KitModular.caixa_cor(sup, &"concreto_sujo",
					centro + frente * (hz * sz)
						+ lado * ((MEIA_PORTA + hx) * 0.5 * sx)
						+ Vector3(0.0, MURO_H * 0.5, 0.0),
					Vector3(comp, MURO_H, MURO_E), pedra, giro,
					PSXMesh.FACE_TODAS, 2.0)
				KitModular.caixa_cor(sup, &"concreto_sujo",
					centro + frente * (hz * sz)
						+ lado * ((MEIA_PORTA + hx) * 0.5 * sx)
						+ Vector3(0.0, MURO_H + 0.06, 0.0),
					Vector3(comp, 0.14, MURO_E + 0.14), pedra_topo, giro,
					PSXMesh.FACE_TODAS, 2.0)
		else:
			KitModular.caixa_cor(sup, &"concreto_sujo",
				centro + frente * (hz * sz) + Vector3(0.0, MURO_H * 0.5, 0.0),
				Vector3(tamanho.x, MURO_H, MURO_E), pedra, giro,
				PSXMesh.FACE_TODAS, 2.0)
			KitModular.caixa_cor(sup, &"concreto_sujo",
				centro + frente * (hz * sz) + Vector3(0.0, MURO_H + 0.06, 0.0),
				Vector3(tamanho.x, 0.14, MURO_E + 0.14), pedra_topo, giro,
				PSXMesh.FACE_TODAS, 2.0)
		KitModular.solido(colisao, centro + frente * (hz * sz)
			+ Vector3(0.0, MURO_H * 0.5, 0.0),
			Vector3(tamanho.x, MURO_H, MURO_E), giro)
	# Laterais corridas.
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + lado * (hx * sx) + Vector3(0.0, MURO_H * 0.5, 0.0),
			Vector3(MURO_E, MURO_H, tamanho.y), pedra, giro,
			PSXMesh.FACE_TODAS, 2.0)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			centro + lado * (hx * sx) + Vector3(0.0, MURO_H + 0.06, 0.0),
			Vector3(MURO_E + 0.14, 0.14, tamanho.y), pedra_topo, giro,
			PSXMesh.FACE_TODAS, 2.0)
		KitModular.solido(colisao, centro + lado * (hx * sx)
			+ Vector3(0.0, MURO_H * 0.5, 0.0),
			Vector3(MURO_E, MURO_H, tamanho.y), giro)
	# Pilares do portao.
	for sx: float in [-1.0, 1.0]:
		var p := centro + frente * hz + lado * (MEIA_PORTA * sx)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			p + Vector3(0.0, 1.0, 0.0), Vector3(0.6, 2.0, 0.6), pedra, giro,
			PSXMesh.FACE_TODAS, 2.0)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			p + Vector3(0.0, 2.1, 0.0), Vector3(0.74, 0.16, 0.74), pedra_topo,
			giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.solido(colisao, p + Vector3(0.0, 1.0, 0.0),
			Vector3(0.6, 2.0, 0.6), giro)

	# Cruzeiro: a cruz grande do meio, que todo campo santo tem. E o unico
	# elemento alto la dentro, e por isso e ele que aparece por cima do muro
	# quando o jogador ainda esta longe.
	cruz_de_pedra(sup, colisao, centro + frente * (hz * 0.15),
		2.5, giro + 0.1, 0.03)

	# Sepulturas em fileira torta. A grade e regular, o conteudo nao: cada celula
	# sorteia entre cruz, tumulo de caixa e nada. Fileira perfeitamente cheia le
	# como grade de cenario; buraco na fileira le como lugar que foi usado.
	var nx := maxi(2, int(tamanho.x / 2.6))
	var nz := maxi(2, int(tamanho.y / 2.8))
	for j in nz:
		for i in nx:
			var chave := semente + j * 97 + i * 31
			var t := _tom(chave, 13)
			if t < 0.24:
				continue
			var fx := (float(i) + 0.5) / float(nx) - 0.5
			var fz := (float(j) + 0.5) / float(nz) - 0.5
			# Folga de 1,6 m no muro e 2,4 m na boca do portao.
			if absf(fx) * tamanho.x > hx - 1.6 or absf(fz) * tamanho.y > hz - 1.6:
				continue
			if fz > 0.22 and absf(fx) * tamanho.x < 2.4:
				continue
			var p := centro + lado * (fx * tamanho.x + lerpf(-0.4, 0.4, _tom(chave, 17))) \
				+ frente * (fz * tamanho.y + lerpf(-0.35, 0.35, _tom(chave, 19)))
			if t < 0.62:
				cruz_de_pedra(sup, colisao, p,
					lerpf(0.7, 1.15, _tom(chave, 23)),
					giro + lerpf(-0.5, 0.5, _tom(chave, 29)),
					lerpf(-0.16, 0.16, _tom(chave, 31)))
			else:
				# Tumulo de caixa: massa grande, que e o que sobra da leitura
				# quando a cruz ja virou um risco de um pixel.
				var giro_t := giro + lerpf(-0.3, 0.3, _tom(chave, 37))
				KitModular.caixa_cor(sup, &"concreto_sujo",
					p + Vector3(0.0, 0.24, 0.0),
					Vector3(1.05, 0.48, 2.0),
					pedra.lerp(Color("4b4841"), _tom(chave, 41)), giro_t,
					PSXMesh.FACE_TODAS, 2.0)
				KitModular.caixa_cor(sup, &"concreto_sujo",
					p + Vector3(0.0, 0.52, 0.0),
					Vector3(1.18, 0.1, 2.12), pedra_topo, giro_t,
					PSXMesh.FACE_TODAS, 2.0)
				KitModular.solido(colisao, p + Vector3(0.0, 0.26, 0.0),
					Vector3(1.05, 0.52, 2.0), giro_t)


## Poste de praca estilo lanterna: mastro preto fino e cabeca quadrada acesa.
## Devolve o ponto da luz (centro da lanterna).
##
## `aceso` falso troca o vidro por `janela_apagada` escuro. Um poste declarado
## morto no prop de luz mas com o globo ainda em `janela_acesa` seria pior que o
## defeito que ele existe para criar: o anel de luz teria um buraco no chao e
## uma lanterna brilhando por cima dele.
static func poste_lanterna(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, aceso: bool = true) -> Vector3:
	const ALTURA := 4.2
	var ferro := Color("1c1c1c")
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, 0.18, 0.0),
		Vector3(0.38, 0.36, 0.38), ferro, 0.0, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, ALTURA * 0.5, 0.0),
		Vector3(0.11, ALTURA, 0.11), ferro, 0.0, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal", base + Vector3(0.0, ALTURA - 0.15, 0.0),
		Vector3(0.28, 0.08, 0.28), ferro, 0.0, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	var lanterna := base + Vector3(0.0, ALTURA + 0.28, 0.0)
	KitModular.caixa_cor(sup, &"metal", lanterna + Vector3(0.0, 0.22, 0.0),
		Vector3(0.42, 0.08, 0.42), ferro, 0.0, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	if aceso:
		KitModular.caixa(sup, &"janela_acesa", lanterna,
			Vector3(0.36, 0.42, 0.36), 0.0, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	else:
		KitModular.caixa_cor(sup, &"janela_apagada", lanterna,
			Vector3(0.36, 0.42, 0.36), Color("14161a"), 0.0,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal", lanterna + Vector3(0.0, 0.38, 0.0),
		Vector3(0.48, 0.1, 0.48), ferro, PI * 0.25, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	colisao.append({"tamanho": Vector3(0.4, ALTURA, 0.4),
		"pos": base + Vector3(0.0, ALTURA * 0.5, 0.0)})
	return lanterna


## Fundura e pe-direito do casario colonial. Uma agua so para todo o perimetro:
## as casas da praca sao um conjunto, e altura de beiral variando de modulo para
## modulo destroi a linha continua que as refs 01 e 02 mostram.
const CASA_FUNDURA := 5.6
const CASA_PE_DIREITO := 3.5
const CASA_PICO := 1.55
const CASA_BEIRAL := 0.55

## Caiacao do casario. Nenhuma e branca pura: no fog denso o branco puro lava e
## a fileira inteira vira um bloco leitoso sem junta entre as casas.
const CAIACOES: Array[Color] = [
	Color("f3ead6"), Color("e9dfc8"), Color("f6efdd"), Color("e2d8c0"),
	Color("efe4cc"), Color("e6dcc6"),
]

## Esquadria colonial: azul desbotado, verde-garrafa, marrom queimado. Sao as
## unicas cores saturadas do casario, e por isso sao elas que dizem onde e a
## porta a doze metros de distancia.
const ESQUADRIAS: Array[Color] = [
	Color("2b3a4a"), Color("24352c"), Color("3a2a20"), Color("2e3f52"),
	Color("2a2f24"),
]


## Reboco descascado: manchas de tijolo aparente numa parede caiada.
##
## `plano` e o ponto no PLANO DA PAREDE, `direita` e `frente` os eixos dela.
## Tudo em metros, tudo grande: a 480x270 uma mancha de 30 cm nao chega a tres
## pixels e vira o mesmo chiado do dither. Meio metro e o piso do que sobrevive,
## e por isso as faixas comecam em 0,55.
##
## Duas camadas de proposito. A mancha sozinha le como adesivo colado na parede;
## com uma borda um tom acima em volta, le como reboco que caiu e deixou a
## argamassa aparecendo na beirada — que e o que a ref 02 mostra na igreja.
static func descascado(sup: Dictionary, plano: Vector3, direita: Vector3,
		frente: Vector3, largura: float, altura: float, giro: float,
		semente: int, quantas: int, tijolo: Color,
		borda: Color = Color("8a7355")) -> void:
	for k in quantas:
		var w := lerpf(0.55, 1.35, _tom(semente + k * 53, 17))
		var hh := lerpf(0.4, 0.9, _tom(semente + k * 89, 19))
		# O CLAMP nao e zelo, e conserto. Antes o sorteio ia ate 0,42 da
		# largura e 0,86 da altura, contando que quem chamasse passasse a
		# extensao certa da parede. Na captura apareceram manchas soltas no
		# ar, uma metade dentro e metade fora de uma empena: quem chama erra,
		# e o jeito de nao errar e a funcao nao aceitar o erro. Aqui a mancha
		# inteira — os dois blocos e a borda — cabe dentro de `largura` x
		# `altura` por construcao, e nenhum chamador consegue empurra-la para
		# fora da parede.
		var meia_w := w * 0.5 + 0.12
		var lim_x := maxf(0.0, largura * 0.5 - meia_w)
		var topo := maxf(0.7, altura - hh * 1.5 - 0.2)
		var fx := lerpf(-lim_x, lim_x, _tom(semente + k * 131, 7))
		var fy := lerpf(0.55, topo, _tom(semente + k * 197, 11))
		var p := plano + direita * fx + Vector3(0.0, fy, 0.0)
		var cor_t := tijolo.lerp(Color("3e2c20"), _tom(semente + k, 23))
		# Dois blocos deslocados, e nao um. Um retangulo unico le como CARTAZ
		# colado na parede — foi exatamente assim que a primeira versao saiu na
		# captura. Dois em L quebram a silhueta, e e a silhueta que diz se
		# aquilo e reboco que caiu ou papel que alguem pregou.
		var w2 := w * lerpf(0.45, 0.75, _tom(semente + k * 71, 29))
		var h2 := hh * lerpf(0.5, 0.85, _tom(semente + k * 97, 31))
		var dx := (w - w2) * 0.5 * (1.0 if (k % 2) == 0 else -1.0)
		var dy := (hh + h2) * 0.5 * 0.82
		KitModular.caixa_cor(sup, &"reboco", p + frente * 0.02,
			Vector3(w + 0.16, hh + 0.14, 0.05), borda, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"reboco",
			p + direita * dx + Vector3(0.0, dy, 0.0) + frente * 0.02,
			Vector3(w2 + 0.14, h2 + 0.12, 0.05), borda, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"tijolo", p + frente * 0.05,
			Vector3(w, hh, 0.05), cor_t, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"tijolo",
			p + direita * dx + Vector3(0.0, dy, 0.0) + frente * 0.05,
			Vector3(w2, h2, 0.05), cor_t.lerp(Color("5c4030"), 0.35), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)


## Escorrido de agua: a lingua escura que desce de um peitoril ou de um vao.
##
## Numa fachada caiada e o desgaste mais barato que existe, e o que mais data o
## predio, porque so aparece onde a agua passa ha anos. Estreito e comprido:
## e a unica feicao fina que sobrevive a 480x270, porque o olho a le como
## direcao, nao como forma.
static func escorrido(sup: Dictionary, topo: Vector3, frente: Vector3,
		comprimento: float, largura: float, giro: float, cor: Color) -> void:
	KitModular.caixa_cor(sup, &"reboco",
		topo + frente * 0.03 + Vector3(0.0, -comprimento * 0.5, 0.0),
		Vector3(largura, comprimento, 0.05), cor, giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)


## Duas tabuas cruzadas pregadas num vao. Grossas de proposito: a 480x270 uma
## ripa de 6 cm a doze metros nao chega a um pixel, e o X — que e a leitura
## inteira da peca — vira dois riscos de dither.
##
## E CLARAS, nao escuras. A primeira versao usava marrom de madeira velha, que e
## o que a madeira e, e o X sumia: tabua escura sobre vao escuro nao tem
## contraste com nada, e so aparecia nas pontas que passavam da moldura. Madeira
## crua pregada por fora pega a luz do lampiao e le como barra clara contra
## preto — que e como a coisa se ve de verdade, e como Silent Hill desenha.
static func _tabuas_cruzadas(sup: Dictionary, centro: Vector3, giro: float,
		largura: float, altura: float,
		cor: Color = Color("a08d6b")) -> void:
	var comp := sqrt(largura * largura + altura * altura) * 0.98
	for sx: float in [-1.0, 1.0]:
		var ang := atan2(altura * sx, largura)
		var base := Basis(Vector3.UP, giro) * Basis(Vector3(0.0, 0.0, 1.0), ang)
		KitModular.caixa_livre(sup, &"tabua", centro,
			Vector3(comp, 0.28, 0.06), base, cor, 2.0)


## Caiacao de cor, uma casa em quatro: ocre, amarelo, rosa e verde-agua.
##
## E a casa alaranjada da foto 01, a esquerda do cruzeiro, e a paleta de todo
## arraial mineiro. Tons de TERRA de proposito: sob o lampiao `ffc978` eles
## aquecem e continuam lendo como parede. Parede azul-clara viraria cinza pela
## mesma conta escrita no AZUL da capela — o azul fica para a esquadria e para a
## barra, que e onde a propria capela o usa.
const CAIACOES_COR: Array[Color] = [
	Color("eab77c"), Color("eed69c"), Color("e8c1ae"), Color("d3dcc2"),
]

## Barra: a faixa pintada no pe da parede. Em Minas ela existe por razao de obra
## — esconde o respingo de barro da chuva — e virou a assinatura da casa. Uma em
## tres tem; as outras ficam com a saia de mofo.
const BARRAS: Array[Color] = [
	AZUL, Color("9c5a36"), Color("4f7a5a"), Color("7a6a4e"),
]

## Porta pintada. A tinta paga a luz quente pela mesma conta do AZUL: de dia
## estas cores gritariam; as onze e quinze da noite elas chegam no olho como
## porta de cor, e nao como mais um retangulo escuro.
const PORTAS_PINTADAS: Array[Color] = [
	AZUL, Color("3f7a58"), Color("9a3f2e"), Color("2f6f8f"),
]

## Topo da chamine. Setenta e cinco centimetros acima da cumeeira: chamine que
## nao passa da cumeeira nao puxa fumaca, e na silhueta some.
const CHAMINE_TOPO := CASA_PE_DIREITO + CASA_PICO + 0.75


## O que cada casa do casario sorteou, num lugar so.
##
## Publico porque TRES lugares precisam da mesma resposta: quem desenha a casa,
## quem poe fumaca na chamine dela e quem decide que ha morador naquela porta.
## Escrito em cada um, a fumaca sairia de telhado sem chamine.
##
## Cada chance e funcao pura da semente do modulo, pela nota de determinismo do
## ParqueBuilder: dois chunks desenham a mesma fileira e tem de concordar sobre
## qual casa tem alpendre.
##
## As proporcoes mudaram de proposito. O casario era 40% pregado e 14% aceso,
## uma cidade abandonada. A referencia e um arraial em uso — porta pintada,
## banco na calcada, vaso na soleira — e o pedido e de um lugar aconchegante. Um
## quarto das casas continua pregado: o bastante para o vazio aparecer, pouco
## para ele mandar na praca.
static func sorteio_da_casa(semente: int) -> Dictionary:
	var tapada := _tom(semente, 41) < 0.24
	var acesa := not tapada and _tom(semente, 43) < 0.30
	return {
		"tapada": tapada,
		"acesa": acesa,
		"barra": _tom(semente, 49) < 0.35,
		"moldura_azul": _tom(semente, 53) < 0.35,
		"porta_pintada": _tom(semente, 59) < 0.40,
		"alpendre": not tapada and _tom(semente, 67) < 0.20,
		"banco": not tapada and _tom(semente, 73) < 0.22,
		"vaso": not tapada and _tom(semente, 79) < 0.30,
		"chamine": _tom(semente, 83) < 0.33,
		"lampiao": acesa and _tom(semente, 89) < 0.55,
		"entreaberta": acesa and _tom(semente, 97) < 0.22,
	}


## A caiacao do modulo. Fora do sorteio porque o telhado tambem pergunta: o oitao
## da ponta da fileira e a parede da casa daquela ponta subindo, e tem de ter a
## mesma tinta. Antes cada um escolhia a sua, e a empena saia de outra cor.
static func caiacao_da_casa(semente: int) -> Color:
	if _tom(semente, 47) < 0.25:
		return CAIACOES_COR[absi(semente * 5 + 1) % CAIACOES_COR.size()]
	return CAIACOES[absi(semente * 7 + 3) % CAIACOES.size()]


## Onde fica a porta ao longo da fachada, em metros a partir do meio.
static func _porta_x(largura: float, semente: int) -> float:
	return lerpf(-largura * 0.22, largura * 0.22, float(absi(semente) % 5) / 4.0)


## A soleira do modulo: 55 cm na frente da porta, no chao.
##
## Publica porque o morador nasce e some aqui. Se a conta do morador e a da porta
## divergissem ele sumiria dentro da parede AO LADO do vao — perto o bastante
## para parecer certo, que e a classe de defeito que ninguem ve acontecer.
static func soleira_do_modulo(centro: Vector3, giro: float, largura: float,
		semente: int) -> Vector3:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	return centro + frente * (CASA_FUNDURA * 0.5 + 0.55) \
		+ lado * _porta_x(largura, semente)


## O lampiao de parede do modulo: onde ele fica, para quem quiser acender uma
## luz de verdade nele. A casa desenha a lanterna na mesma conta.
static func lampiao_do_modulo(centro: Vector3, giro: float, largura: float,
		semente: int) -> Vector3:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	return centro + frente * (CASA_FUNDURA * 0.5 + 0.30) \
		+ lado * _porta_x(largura, semente) + Vector3(0.0, 2.95, 0.0)


## Topo da chamine do modulo, ou Vector3.INF se ele nao tem.
static func chamine_de(centro: Vector3, giro: float, largura: float,
		semente: int) -> Vector3:
	if not bool(sorteio_da_casa(semente)["chamine"]):
		return Vector3.INF
	return _topo_da_chamine(centro, giro, largura, semente)


## Um metro atras da cumeeira, na agua de tras: e onde fica o fogao de lenha, na
## cozinha dos fundos, e de onde a chamine sai na casa de verdade.
static func _topo_da_chamine(centro: Vector3, giro: float, largura: float,
		semente: int) -> Vector3:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	var u := lerpf(-largura * 0.25, largura * 0.25, _tom(semente, 101))
	return centro - frente * 1.0 + lado * u + Vector3(0.0, CHAMINE_TOPO, 0.0)


## Altura da bandeira: o vidro com grade acima das folhas da porta.
const PORTA_BANDEIRA := 0.40
## Vao da porta do casario (folhas mais bandeira). A verga fica em 2,60, a MESMA
## altura da verga das janelas: a linha continua de vergas e o que faz uma
## fileira de casas ler como arquitetura e nao como caixas empilhadas.
const CASA_PORTA_L := 1.10
const CASA_PORTA_H := 2.45
## Vao da janela do casario e altura do centro dele.
const CASA_JANELA_L := 0.95
const CASA_JANELA_H := 1.25
const CASA_JANELA_Y := 1.85

## Estados de janela.
enum Janela { VIDRACA, ACESA, FECHADA, TAPADA }


## Porta colonial de duas folhas: marco, pestana, folhas almofadadas, bandeira
## com grade, ferragem e soleira.
##
## Era uma placa: marco de um bloco e folha de outro, chapados na parede, e de
## perto lia como adesivo. O que faz uma porta ler como porta, em ordem:
##   - PROFUNDIDADE: a folha fica 4 cm atras da face do marco e a pestana avanca
##     por cima dele. Sao duas sombras de graca, sem luz nenhuma;
##   - a BANDEIRA: o vidro com grade acima das folhas, que toda porta de casa
##     mineira tem, e que acesa diz "tem gente" sem abrir nada;
##   - as ALMOFADAS e a ferragem, que dao escala: porta sem macaneta nao tem
##     tamanho.
##
## `base` e o pe da porta no PLANO da parede. Tudo cresce para a frente e nada
## passa de 0,20 m dela — o lampiao pendura a 0,30.
##
## Entreaberta, a folha da DIREITA abriu para dentro e some atras do marco: o
## que se ve e a luz da sala no vao e a quina da folha junto da ombreira.
static func porta_colonial(sup: Dictionary, base: Vector3, giro: float,
		largura: float, altura: float, cor_folha: Color, pintada: bool,
		moldura: Color, entreaberta: bool = false, tapada: bool = false,
		luz: bool = false, soleira: bool = true, numero: bool = false) -> void:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	var up := Vector3.UP
	# Folha pintada vai no `reboco`: `porta.png` e madeira escura e quente, e
	# tinta nenhuma sobrevive a ela multiplicada pela luz do lampiao.
	var mat: StringName = &"reboco" if pintada else &"porta"
	var h_folha := altura - PORTA_BANDEIRA
	var escura := cor_folha.lerp(Color.BLACK, 0.24)
	# Vao: o fundo escuro, que so aparece na fresta e atras da grade.
	KitModular.caixa_cor(sup, &"janela_apagada", base + frente * 0.02 + up * (altura * 0.5),
		Vector3(largura, altura, 0.04), Color("060607"), giro, SEM_COSTA, QUAD_FOLHA)
	# Marco: ombreiras e verga com 14 cm de fundo, e a pestana por cima.
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"reboco",
			base + lado * (sx * (largura * 0.5 + 0.075)) + frente * 0.07
				+ up * ((altura + 0.15) * 0.5),
			Vector3(0.15, altura + 0.15, 0.14), moldura, giro, SEM_COSTA, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"reboco", base + frente * 0.07 + up * (altura + 0.075),
		Vector3(largura + 0.30, 0.15, 0.14), moldura, giro, SEM_COSTA, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"reboco", base + frente * 0.10 + up * (altura + 0.19),
		Vector3(largura + 0.50, 0.08, 0.20), moldura.lerp(Color.WHITE, 0.12), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Bandeira: travessa no plano da folha, vidro (aceso ou escuro) e tres
	# barras de ferro.
	var y_band := h_folha + 0.06 + (PORTA_BANDEIRA - 0.06) * 0.5
	KitModular.caixa_cor(sup, mat, base + frente * 0.07 + up * (h_folha + 0.03),
		Vector3(largura, 0.06, 0.06), cor_folha, giro, SEM_COSTA, QUAD_FOLHA)
	if luz:
		KitModular.caixa(sup, &"janela_acesa", base + frente * 0.05 + up * y_band,
			Vector3(largura - 0.02, PORTA_BANDEIRA - 0.08, 0.02), giro, SEM_COSTA,
			QUAD_FOLHA)
	for k in 3:
		KitModular.caixa_cor(sup, &"metal",
			base + lado * lerpf(-largura * 0.3, largura * 0.3, float(k) * 0.5)
				+ frente * 0.075 + up * y_band,
			Vector3(0.035, PORTA_BANDEIRA - 0.08, 0.035), Color("26231f"), giro,
			SEM_COSTA, QUAD_FOLHA)
	# As folhas.
	var fl := largura * 0.5
	for sx: float in [-1.0, 1.0]:
		var cx := base + lado * (sx * fl * 0.5)
		if entreaberta and sx > 0.0:
			KitModular.caixa(sup, &"janela_acesa", cx + frente * 0.05 + up * (h_folha * 0.5),
				Vector3(fl - 0.02, h_folha - 0.02, 0.02), giro, SEM_COSTA, QUAD_FOLHA)
			KitModular.caixa_cor(sup, mat,
				base + lado * (fl - 0.04) + frente * 0.07 + up * (h_folha * 0.5),
				Vector3(0.05, h_folha, 0.09), escura, giro, SEM_COSTA, QUAD_FOLHA)
			continue
		KitModular.caixa_cor(sup, mat, cx + frente * 0.07 + up * (h_folha * 0.5),
			Vector3(fl - 0.01, h_folha, 0.06), cor_folha, giro, SEM_COSTA, QUAD_FOLHA)
		# Almofadas: a alta em cima, a baixa embaixo, 2 cm salientes e um tom
		# abaixo — com luz de vertice, e o tom que desenha o painel.
		for a: Array in [[0.63, 0.48], [0.20, 0.25]]:
			KitModular.caixa_cor(sup, mat,
				cx + frente * 0.105 + up * (h_folha * float(a[0])),
				Vector3(fl - 0.16, h_folha * float(a[1]), 0.02), escura, giro,
				SEM_COSTA, QUAD_FOLHA)
		for hy: float in [0.16, 0.84]:
			KitModular.caixa_cor(sup, &"metal",
				base + lado * (sx * (fl - 0.035)) + frente * 0.101 + up * (h_folha * hy),
				Vector3(0.04, 0.12, 0.004), Color("1e1c19"), giro,
				PSXMesh.FACE_FRENTE, QUAD_FOLHA)
	# Espelho da fechadura e macaneta, na folha da esquerda, junto do encontro.
	KitModular.caixa_cor(sup, &"metal", base - lado * 0.05 + frente * 0.101 + up * 1.02,
		Vector3(0.05, 0.16, 0.004), Color("2a2620"), giro, PSXMesh.FACE_FRENTE,
		QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"metal", base - lado * 0.05 + frente * 0.125 + up * 0.98,
		Vector3(0.045, 0.045, 0.05), Color("8a7a52"), giro, SEM_COSTA, QUAD_FOLHA)
	if tapada:
		_tabuas_cruzadas(sup, base + frente * 0.17 + up * (h_folha * 0.5), giro,
			largura + 0.1, h_folha - 0.1)
	if soleira:
		KitModular.caixa_cor(sup, &"concreto_sujo", base + frente * 0.17 + up * 0.06,
			Vector3(largura + 0.40, 0.12, 0.34), Color("a8a496"), giro,
			PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE, QUAD_FOLHA)
	if numero:
		# O azulejo do numero, branco de filete azul, sobre a ombreira direita.
		var az := base + lado * (largura * 0.5 - 0.02) + frente * 0.012 \
			+ up * (altura + 0.42)
		KitModular.caixa_cor(sup, &"reboco", az, Vector3(0.20, 0.15, 0.024),
			Color("f4f1ea"), giro, SEM_COSTA, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"reboco", az + frente * 0.013,
			Vector3(0.11, 0.07, 0.002), AZUL_FUNDO, giro, PSXMesh.FACE_FRENTE,
			QUAD_FOLHA)


## Janela colonial de verga reta: marco, peitoril de pedra, pestana, vidraca de
## guilhotina em seis vidros e, quando aberta e ha parede dos lados, as duas
## folhas de madeira rebatidas contra o reboco.
##
## Era um retangulo de textura com uma barra no meio — uma foto de janela. O que
## a torna janela a 480x270, em ordem:
##   - o CAIXILHO claro em xadrez sobre o vao: e o desenho que o olho reconhece
##     antes de qualquer outro, e custa tres barras;
##   - as FOLHAS abertas na parede, na cor da porta: poem a cor da casa na altura
##     do olho e dobram a largura aparente do vao;
##   - a CORTINA na janela acesa, mais clara que a sala por tras dela — contra a
##     luz a renda brilha, e e isso que diz "sala" e nao "vitrine". A emissao do
##     `janela_acesa` e multiplicada pela cor do vertice, entao a sala sai num
##     ambar mais fundo e a cortina quase branca, sem material novo;
##   - peitoril e pestana, as duas sombras horizontais.
##
## `centro` e o meio do vao no plano da parede.
static func janela_colonial(sup: Dictionary, centro: Vector3, giro: float,
		largura: float, altura: float, moldura: Color, esquadria: Color,
		estado: int, folhas: bool, semente: int) -> void:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	var up := Vector3.UP
	var caixilho := Color("ebe5d6")
	if estado == Janela.ACESA:
		KitModular.caixa_cor(sup, &"janela_acesa", centro + frente * 0.015,
			Vector3(largura, altura, 0.03), Color(0.74, 0.58, 0.42), giro,
			SEM_COSTA, QUAD_FOLHA)
		var lado_c := 1.0 if (absi(semente) % 2) == 0 else -1.0
		KitModular.caixa_cor(sup, &"janela_acesa",
			centro + lado * (lado_c * largura * 0.30) + frente * 0.034,
			Vector3(largura * 0.40, altura * 0.96, 0.008), Color(1.0, 0.95, 0.86),
			giro, SEM_COSTA, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"janela_acesa",
			centro + frente * 0.035 + up * (altura * 0.5 - 0.09),
			Vector3(largura, 0.16, 0.008), Color(1.0, 0.95, 0.86), giro,
			SEM_COSTA, QUAD_FOLHA)
	else:
		KitModular.caixa_cor(sup, &"janela_apagada", centro + frente * 0.015,
			Vector3(largura, altura, 0.03), Color("0b0c0e"), giro, SEM_COSTA,
			QUAD_FOLHA)
		if estado == Janela.VIDRACA and _tom(semente, 131) < 0.55:
			# Cortina de casa escura: sem luz atras, a renda fica cinza-palha.
			KitModular.caixa_cor(sup, &"reboco",
				centro + lado * (largura * 0.31 * (1.0 if (absi(semente) % 2) == 1 else -1.0))
					+ frente * 0.034,
				Vector3(largura * 0.36, altura * 0.95, 0.008), Color("7d735f"), giro,
				SEM_COSTA, QUAD_FOLHA)
	if estado == Janela.FECHADA:
		# As duas folhas fechadas no vao, com a junta do meio e uma travessa.
		for sx: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"reboco",
				centro + lado * (sx * largura * 0.25) + frente * 0.055,
				Vector3(largura * 0.5 - 0.02, altura, 0.05), esquadria, giro,
				SEM_COSTA, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"reboco", centro + frente * 0.085,
			Vector3(largura - 0.06, 0.06, 0.012), esquadria.lerp(Color.BLACK, 0.3),
			giro, PSXMesh.FACE_FRENTE | PSXMesh.FACE_TOPO, QUAD_FOLHA)
	elif estado == Janela.TAPADA:
		_tabuas_cruzadas(sup, centro + frente * 0.16, giro, largura + 0.12, altura + 0.1)
	else:
		# Caixilho de guilhotina: montante no meio e duas travessas, a de cima
		# mais grossa — e o encontro das duas vidracas.
		KitModular.caixa_cor(sup, &"reboco", centro + frente * 0.055,
			Vector3(0.045, altura, 0.03), caixilho, giro, SEM_COSTA, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"reboco", centro + frente * 0.055 + up * (altura * 0.17),
			Vector3(largura, 0.06, 0.03), caixilho, giro, SEM_COSTA, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"reboco", centro + frente * 0.055 - up * (altura * 0.17),
			Vector3(largura, 0.035, 0.03), caixilho, giro, SEM_COSTA, QUAD_FOLHA)
		if folhas:
			# As folhas rebatidas na parede, cada uma com a sua almofada.
			for sx: float in [-1.0, 1.0]:
				var f := centro + lado * (sx * (largura * 0.75 + 0.14)) + frente * 0.02
				KitModular.caixa_cor(sup, &"reboco", f,
					Vector3(largura * 0.5 - 0.02, altura, 0.04), esquadria, giro,
					SEM_COSTA, QUAD_FOLHA)
				KitModular.caixa_cor(sup, &"reboco", f + frente * 0.025,
					Vector3(largura * 0.5 - 0.14, altura * 0.72, 0.01),
					esquadria.lerp(Color.BLACK, 0.22), giro, SEM_COSTA, QUAD_FOLHA)
	# Marco, peitoril e pestana.
	for sx: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"reboco",
			centro + lado * (sx * (largura * 0.5 + 0.065)) + frente * 0.06,
			Vector3(0.13, altura + 0.13, 0.12), moldura, giro, SEM_COSTA, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"reboco",
		centro + frente * 0.06 + up * (altura * 0.5 + 0.065),
		Vector3(largura + 0.26, 0.13, 0.12), moldura, giro, SEM_COSTA, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"reboco",
		centro + frente * 0.085 + up * (altura * 0.5 + 0.165),
		Vector3(largura + 0.40, 0.07, 0.17), moldura.lerp(Color.WHITE, 0.12), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		centro + frente * 0.11 - up * (altura * 0.5 + 0.045),
		Vector3(largura + 0.36, 0.09, 0.22), Color("b8b3a4"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)


## Jardineira de madeira pendurada sob o peitoril, com flor. Numa fileira de
## vaos iguais e a coisa mais barata que existe para uma casa ser DE ALGUEM.
static func jardineira(sup: Dictionary, centro: Vector3, giro: float,
		largura: float, altura: float, semente: int) -> void:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	var caixa := centro + frente * 0.13 - Vector3(0.0, altura * 0.5 + 0.18, 0.0)
	KitModular.caixa_cor(sup, &"tabua", caixa, Vector3(largura + 0.1, 0.18, 0.2),
		Color("6e4a30"), giro, SEM_COSTA, QUAD_FOLHA)
	for k in 2:
		var u := (float(k) - 0.5) * largura * 0.5
		moita_de_flor(sup, caixa + lado * u + Vector3(0.0, 0.09, 0.0),
			Vector2i(absi(semente + k) % 4, 0), 0.36, _tom(semente, 139 + k) * PI)


## Um modulo de casa colonial: parede caiada, barra ou saia de mofo, porta alta
## que da na calcada e janela de esquadria. Nao poe telhado — quem chama decide
## se a casa e isolada ou parte de uma fileira germinada, e o telhado corrido e a
## diferenca entre as duas.
##
## `faces_parede` deixa o chamador matar as paredes-meia. Nao e economia de
## triangulo: dois modulos encostados tem a parede lateral EXATAMENTE no mesmo
## plano, e duas faces coplanares brigam por profundidade e piscam a cada passo.
## Quem nao existe nao pisca.
##
## `forca` sobrepoe o sorteio — chave a chave, mais as cores `caiacao`,
## `esquadria`, `cor_barra` e `cor_porta`. E como o anexo da capela sai deste
## mesmo modulo com a tinta dela, e como a casa de um morador garante a porta
## entreaberta por onde ele entra.
static func _modulo_colonial(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float, largura: float, semente: int,
		faces_parede: int = PSXMesh.FACE_TODAS, forca: Dictionary = {}) -> void:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	var h := CASA_PE_DIREITO
	var f := CASA_FUNDURA
	var s := sorteio_da_casa(semente)
	s.merge(forca, true)
	var caiacao: Color = s.get("caiacao", caiacao_da_casa(semente))
	var esquadria: Color = s.get("esquadria",
		ESQUADRIAS[absi(semente * 13 + 5) % ESQUADRIAS.size()])
	var tapada := bool(s["tapada"])
	var acesa := bool(s["acesa"])
	var face := centro + frente * (f * 0.5)

	KitModular.caixa_cor(sup, &"reboco", centro + Vector3(0.0, h * 0.5, 0.0),
		Vector3(largura, h, f), caiacao, giro, faces_parede, 2.5)
	# O pe da parede: barra pintada numa casa em tres, saia de mofo nas outras.
	# As duas fazem o mesmo servico de cena — ancoram a casa no chao em vez de
	# deixa-la boiando sobre o paralelepipedo — e a barra diz que alguem cuida.
	var saia := caiacao.lerp(Color("4a4a3c"), 0.55)
	if bool(s["barra"]):
		var barra: Color = s.get("cor_barra",
			BARRAS[absi(semente * 11 + 7) % BARRAS.size()])
		saia = barra.lerp(Color("3a3a30"), 0.18)
	KitModular.caixa_cor(sup, &"reboco",
		face + Vector3(0.0, 0.45, 0.0),
		Vector3(largura * 0.99, 0.9, 0.08), saia,
		giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Friso sob o beiral: linha clara que separa parede de telha. Sem ela, a
	# noite, a parede caiada e a telha escura se encostam num degrade e o
	# beiral some.
	KitModular.caixa_cor(sup, &"reboco",
		face + Vector3(0.0, h - 0.18, 0.0),
		Vector3(largura * 0.99, 0.22, 0.14), caiacao.lerp(Color.WHITE, 0.35),
		giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	# Reboco caido so na casa PREGADA. Nas outras ele saiu: tijolo aparente em
	# quadro de meio metro, a 480x270, le como BURACO na parede — foi o que a
	# volta de captura em volta da praca mostrou em quase toda fachada. Casa com
	# gente e casa cuidada; o abandono fica para quem tem tabua na porta.
	if tapada:
		descascado(sup, face, lado, frente, largura, h, giro,
			semente * 3 + 11, 2, Color("6b4a33"))

	# --- os fundos --------------------------------------------------------
	#
	# Eram uma laje branca lisa. Ninguem projeta cena para o fundo da casa, mas
	# o jogador anda por tras dela, e la a fileira inteira virava um muro de
	# reboco novo sem uma marca. O fundo de casa colonial e o lado que ninguem
	# caia: mais mofo, mais tijolo a mostra, uma janelinha alta de servico e o
	# tubo de descida da agua.
	#
	# Duas manchas, e nao de tres a cinco: cada uma sao quatro caixas, e o fundo
	# e o lado menos visto da casa. Medido, os chunks da praca estavam em 13 e 21
	# mil triangulos contra um teto de 6 mil, e o descascado dos fundos era o
	# maior gasto que ninguem via.
	var fundo := centro - frente * (f * 0.5)
	var atras := -frente
	KitModular.caixa_cor(sup, &"reboco", fundo + Vector3(0.0, 0.55, 0.0),
		Vector3(largura * 0.99, 1.1, 0.08),
		caiacao.lerp(Color("3c4034"), 0.68), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
	if tapada:
		descascado(sup, fundo, lado, atras, largura, h, giro + PI,
			semente * 5 + 29, 2, Color("6b4a33"))
	# Janela alta de servico: vao escuro sem moldura clara. E o unico furo do
	# fundo, e e alto porque cozinha colonial tem janela no alto da parede.
	var jf := fundo + lado * lerpf(-largura * 0.24, largura * 0.24, _tom(semente, 61)) \
		+ Vector3(0.0, 2.35, 0.0)
	KitModular.caixa_cor(sup, &"janela_apagada", jf + atras * 0.05,
		Vector3(0.72, 0.62, 0.08), Color("15140f"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.caixa_cor(sup, &"concreto_sujo", jf + atras * 0.08 + Vector3(0.0, -0.36, 0.0),
		Vector3(0.86, 0.1, 0.2), Color("8e8a7c"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	escorrido(sup, jf + Vector3(0.0, -0.4, 0.0), atras, 1.5, 0.5, giro,
		caiacao.lerp(Color("2e3228"), 0.6))
	# Tubo de descida na quina, com a mancha que ele deixa no reboco.
	var quina := fundo + lado * (largura * (0.44 if (absi(semente) % 2) == 0 else -0.44))
	KitModular.caixa_cor(sup, &"metal", quina + atras * 0.1 + Vector3(0.0, h * 0.5, 0.0),
		Vector3(0.14, h, 0.14), Color("3b3a34"), giro,
		PSXMesh.FACE_TODAS, QUAD_FOLHA)
	escorrido(sup, quina + Vector3(0.0, 1.0, 0.0), atras, 1.0, 0.34, giro,
		caiacao.lerp(Color("2e3228"), 0.55))

	# --- a porta ----------------------------------------------------------
	#
	# Quem esta pregado e quem esta acordado. Uma fileira em que todo vao e igual
	# le como cenario; a variacao e o que faz o jogador ler CASA por casa. A
	# janela acesa nao custa luz nenhuma: `janela_acesa` tem emissao propria.
	# O desenho do vao mora em `porta_colonial` e `janela_colonial`.
	var porta_l := CASA_PORTA_L
	var porta_x := _porta_x(largura, semente)
	var moldura := AZUL if bool(s["moldura_azul"]) else caiacao.lerp(Color.WHITE, 0.45)
	if tapada:
		moldura = caiacao.lerp(Color("5a5448"), 0.35)
	var pintada := bool(s["porta_pintada"])
	var cor_porta := esquadria
	if pintada:
		cor_porta = s.get("cor_porta",
			PORTAS_PINTADAS[absi(semente * 17 + 3) % PORTAS_PINTADAS.size()])
	porta_colonial(sup, face + lado * porta_x, giro, porta_l, CASA_PORTA_H,
		cor_porta, pintada, moldura, bool(s["entreaberta"]), tapada, acesa,
		true, not tapada and _tom(semente, 113) < 0.7)

	# --- as janelas -------------------------------------------------------
	#
	# Folhas de madeira rebatidas so onde ha parede dos DOIS lados para elas:
	# rebatida por cima do marco da porta ou passando da quina, a folha denuncia
	# que e adesivo. Nos modulos de 4,2 a 6,2 m isso quase nunca sobra, e a
	# variedade vem do estado — vidraca com cortina, acesa, fechada nas folhas —
	# e da jardineira.
	var cor_folha := cor_porta if pintada else esquadria.lerp(Color("6b5a44"), 0.35)
	var alcance_folha := CASA_JANELA_L + 0.18
	for sx: float in [-1.0, 1.0]:
		var jx := porta_x + sx * (porta_l * 0.5 + 0.28 + largura * 0.16)
		if absf(jx) > largura * 0.5 - 0.75:
			continue
		var folgado := absf(jx - porta_x) - (porta_l * 0.5 + 0.15) >= alcance_folha 			and largura * 0.5 - 0.18 - absf(jx) >= alcance_folha
		var estado := Janela.VIDRACA
		if tapada:
			estado = Janela.TAPADA
		elif acesa and sx > 0.0:
			# So a janela da DIREITA acende. Duas acesas na mesma casa leem como
			# "casa habitada"; uma so le como comodo, e comodo tem alguem dentro.
			estado = Janela.ACESA
		elif _tom(semente + int(sx) * 5, 127) < 0.34:
			estado = Janela.FECHADA
		var sj := semente * 7 + int(sx) * 3
		janela_colonial(sup, face + lado * jx + Vector3(0.0, CASA_JANELA_Y, 0.0),
			giro, CASA_JANELA_L, CASA_JANELA_H, moldura, cor_folha, estado,
			folgado, sj)
		if estado != Janela.TAPADA and _tom(sj, 137) < 0.3:
			jardineira(sup, face + lado * jx + Vector3(0.0, CASA_JANELA_Y, 0.0),
				giro, CASA_JANELA_L, CASA_JANELA_H, sj)

	# --- o que faz a casa ser de alguem ------------------------------------
	#
	# Alpendre, lampiao, banco, vaso e chamine. Nenhum custa luz, e juntos sao a
	# diferenca entre fachada e casa: sao as coisas que alguem pos ali. O banco
	# vai do lado da porta que tem mais parede, e o vaso do outro.
	var lado_banco := 1.0 if porta_x < 0.0 else -1.0
	if bool(s["alpendre"]):
		# Telheiro de uma agua sobre dois esteios. Casario mineiro tem sombra
		# na frente da porta; fachada chapada de ponta a ponta nao tem.
		KitModular.caixa_livre(sup, &"teto",
			face + lado * porta_x + frente * 0.68 + Vector3(0.0, 3.12, 0.0),
			Vector3(2.3, 0.07, 1.42),
			Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, 0.22), TELHA_CLARA,
			QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"tabua",
			face + lado * porta_x + frente * 1.25 + Vector3(0.0, 2.94, 0.0),
			Vector3(2.2, 0.12, 0.12), MADEIRA_ESCURA, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		for px: float in [-1.02, 1.02]:
			var esteio := face + lado * (porta_x + px) + frente * 1.25
			KitModular.caixa_cor(sup, &"tabua", esteio + Vector3(0.0, 1.46, 0.0),
				Vector3(0.13, 2.92, 0.13), Color("5a4632"), giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
			KitModular.solido(colisao, esteio + Vector3(0.0, 1.46, 0.0),
				Vector3(0.14, 2.92, 0.14), giro)
	if bool(s["lampiao"]):
		# Lanterna de parede sobre a porta. So emissao — quem quiser que ela
		# ilumine de verdade pede `lampiao_do_modulo` e poe a luz la.
		var lamp := lampiao_do_modulo(centro, giro, largura, semente)
		KitModular.caixa_cor(sup, &"metal",
			face + lado * porta_x + frente * 0.16 + Vector3(0.0, 3.11, 0.0),
			Vector3(0.05, 0.05, 0.32), Color("1c1c1c"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa(sup, &"janela_acesa", lamp,
			Vector3(0.17, 0.24, 0.17), giro, PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"metal", lamp + Vector3(0.0, 0.15, 0.0),
			Vector3(0.23, 0.05, 0.23), Color("1c1c1c"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	if bool(s["banco"]):
		var bx := porta_x + lado_banco * (porta_l * 0.5 + 0.35 + 0.75)
		if absf(bx) + 0.8 < largura * 0.5 - 0.15:
			var banco_p := face + lado * bx + frente * 0.24
			KitModular.caixa_cor(sup, &"tabua", banco_p + Vector3(0.0, 0.44, 0.0),
				Vector3(1.5, 0.07, 0.34), Color("6b5539"), giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
			for px: float in [-0.6, 0.6]:
				KitModular.caixa_cor(sup, &"tabua",
					banco_p + lado * px + Vector3(0.0, 0.21, 0.0),
					Vector3(0.08, 0.42, 0.28), Color("54432e"), giro,
					PSXMesh.FACE_TODAS, QUAD_FOLHA)
			KitModular.solido(colisao, banco_p + Vector3(0.0, 0.24, 0.0),
				Vector3(1.5, 0.48, 0.36), giro)
	if bool(s["vaso"]):
		var vx := porta_x - lado_banco * (porta_l * 0.5 + 0.34)
		if absf(vx) < largura * 0.5 - 0.3:
			var vaso_p := face + lado * vx + frente * 0.30
			KitModular.caixa_cor(sup, &"tijolo", vaso_p + Vector3(0.0, 0.17, 0.0),
				Vector3(0.34, 0.34, 0.34), Color("b0643c"), giro,
				PSXMesh.FACE_TODAS, QUAD_FOLHA)
			moita_de_flor(sup, vaso_p + Vector3(0.0, 0.32, 0.0),
				Vector2i(int(_tom(semente, 107) * 4.0) % 4, 0), 0.58,
				_tom(semente, 109) * PI)
	if bool(s["chamine"]):
		var topo := _topo_da_chamine(centro, giro, largura, semente)
		var alto := CHAMINE_TOPO - h + 0.2
		KitModular.caixa_cor(sup, &"reboco", topo - Vector3(0.0, alto * 0.5, 0.0),
			Vector3(0.56, alto, 0.56), caiacao.lerp(Color("5a5448"), 0.25), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"concreto_sujo", topo + Vector3(0.0, 0.05, 0.0),
			Vector3(0.72, 0.1, 0.72), Color("3a3630"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
		KitModular.caixa_cor(sup, &"janela_apagada", topo + Vector3(0.0, 0.105, 0.0),
			Vector3(0.36, 0.02, 0.36), Color("0c0b0a"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)

	colisao.append({"tamanho": Vector3(largura, h, f),
		"pos": centro + Vector3(0.0, h * 0.5, 0.0), "giro": Vector3(0.0, giro, 0.0)})


## Cabana colonial isolada: um modulo com telhado proprio e os dois oitoes.
##
## E a peca das casas soltas alem das fileiras. Fora de esquadro elas dizem, sem
## uma linha de dialogo, que aqui a rua nao mandou em nada.
static func casa_colonial_baixa(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float, largura: float = 7.5,
		semente: int = 0) -> void:
	var s := semente if semente != 0 else int(centro.x * 7.0)
	_modulo_colonial(sup, colisao, centro, giro, largura, s)
	var cor := caiacao_da_casa(s)
	_telhado_de_casario(sup, centro, giro, largura, cor, cor)


## A tinta da capela, forcada sobre o modulo do casario. Ver `anexo_capela`.
const ANEXO_FORCA := {
	"caiacao": Color("fff6e6"), "esquadria": AZUL, "cor_barra": AZUL,
	"cor_porta": AZUL, "barra": true, "moldura_azul": true,
	"porta_pintada": true, "tapada": false, "acesa": true, "lampiao": true,
	"alpendre": false, "banco": false, "vaso": true, "chamine": false,
	"entreaberta": false,
}


## Anexo da capela: casa baixa branca com porta, janela e barra azuis.
##
## Sao as duas construcoes que as fotos poem ao lado da capela — a comprida a
## direita, na 03, e a pequena a esquerda com o portaozinho azul, na 05. Mesmo
## modulo do casario, com a tinta da capela forcada: o branco dela na parede e o
## AZUL dela em tudo que e esquadria. E a tinta que diz que as tres construcoes
## sao do mesmo dono.
static func anexo_capela(sup: Dictionary, colisao: Array[Dictionary],
		centro: Vector3, giro: float, largura: float, semente: int) -> void:
	_modulo_colonial(sup, colisao, centro, giro, largura, semente,
		PSXMesh.FACE_TODAS, ANEXO_FORCA)
	var branco: Color = ANEXO_FORCA["caiacao"]
	_telhado_de_casario(sup, centro, giro, largura, branco, branco)


## Os modulos de uma fileira: centro, largura, semente e onde cada um comeca.
##
## Publico porque o morador precisa da MESMA conta que desenha as casas: e daqui
## que sai a porta dele. Com a sequencia de larguras escrita em dois lugares, o
## morador sairia de uma parede.
##
## Modulos de 4,2 a 6,2 m — a largura de uma casa de porta e duas janelas. O
## ultimo absorve a sobra para a fileira fechar exatamente no `ate`.
static func modulos_da_fileira(de: Vector3, ate: Vector3, giro: float,
		semente: int) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var eixo := ate - de
	var comp := eixo.length()
	if comp < 3.0:
		return saida
	var dir := eixo / comp
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var larguras: Array[float] = []
	var somado := 0.0
	var k := 0
	while somado < comp - 0.01:
		var w := lerpf(4.2, 6.2, _tom(semente + k * 31, 71))
		if comp - somado - w < 3.4:
			w = comp - somado
		larguras.append(w)
		somado += w
		k += 1
	var andado := 0.0
	for i in larguras.size():
		var w: float = larguras[i]
		saida.append({
			"centro": de + dir * (andado + w * 0.5) - frente * (CASA_FUNDURA * 0.5),
			"largura": w,
			"semente": semente + i * 17,
			"inicio": andado,
		})
		andado += w
	return saida


## Fileira de casario colonial germinado: modulos encostados, telhado corrido.
##
## `de` e `ate` sao as pontas da linha de FACHADA, no chao; a casa cresce para
## tras. `giro` e a direcao para onde a fachada olha. `forcas` leva, por indice de
## modulo, o que `_modulo_colonial` aceita em `forca`.
##
## As casas coloniais em volta de uma praca sao germinadas — parede comum, sem
## vao — e por isso o telhado e UM so, da primeira a ultima.
##
## QUAL parede-meia some depende do sentido da fileira, e isso estava errado.
## A versao anterior tirava sempre a face -X do modulo seguinte e a +X do
## anterior, o que so e verdade quando `de -> ate` anda para +X local. Nas
## fileiras que andavam ao contrario — as de giro PI/2 subindo em Z e as de giro
## PI andando em X — o que sumia eram as duas paredes de PONTA, e a fileira ficava
## aberta nas extremidades: um buraco do chao ao beiral por onde se via o avesso
## das casas.
static func fileira_colonial(sup: Dictionary, colisao: Array[Dictionary],
		de: Vector3, ate: Vector3, giro: float, semente: int,
		forcas: Dictionary = {}) -> void:
	var modulos := modulos_da_fileira(de, ate, giro, semente)
	if modulos.is_empty():
		return
	var dir := (ate - de).normalized()
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	var giro_fila := atan2(dir.x, dir.z)
	# A fileira anda para +X local do modulo?
	var anda_mais := dir.dot(lado) > 0.0
	var face_anterior := PSXMesh.FACE_ESQ if anda_mais else PSXMesh.FACE_DIR
	var face_seguinte := PSXMesh.FACE_DIR if anda_mais else PSXMesh.FACE_ESQ

	for i in modulos.size():
		var m: Dictionary = modulos[i]
		var faces := PSXMesh.FACE_TODAS
		if i > 0:
			faces &= ~face_anterior
		if i < modulos.size() - 1:
			faces &= ~face_seguinte
		_modulo_colonial(sup, colisao, m["centro"], giro, float(m["largura"]),
			int(m["semente"]), faces, forcas.get(i, {}))
		# Pilastra da parede-meia: a linha vertical que conta onde acaba uma casa
		# e comeca a outra. Sem ela a fileira le como um galpao comprido.
		if i > 0:
			KitModular.caixa_cor(sup, &"reboco",
				de + dir * float(m["inicio"]) + frente * 0.06
					+ Vector3(0.0, CASA_PE_DIREITO * 0.5, 0.0),
				Vector3(0.3, CASA_PE_DIREITO, 0.12),
				caiacao_da_casa(int(m["semente"])).lerp(Color("6b6354"), 0.4),
				giro_fila + PI * 0.5, PSXMesh.FACE_TODAS, QUAD_FOLHA)

	# Cada oitao leva a tinta da casa da ponta dele.
	var primeira := caiacao_da_casa(int(modulos[0]["semente"]))
	var ultima := caiacao_da_casa(int(modulos[modulos.size() - 1]["semente"]))
	var meio := de.lerp(ate, 0.5) - frente * (CASA_FUNDURA * 0.5)
	_telhado_de_casario(sup, meio, giro, (ate - de).length(),
		primeira if anda_mais else ultima, ultima if anda_mais else primeira)


## Telhado do casario: duas aguas caindo para a rua, oitoes nas pontas, a tabica
## escura na linha do beiral e os cachorros por baixo dele.
##
## A cumeeira corre PARALELA a fachada — e o "duas aguas caindo para a rua" das
## refs. `telhado_duas_aguas` deixa a cumeeira no Z local e as aguas caindo no X
## local, entao a fileira entra girada de um quarto de volta.
##
## `caiacao` pinta o oitao da ponta -X local e `caiacao_mais` o da +X.
static func _telhado_de_casario(sup: Dictionary, centro: Vector3, giro: float,
		comprimento: float, caiacao: Color, caiacao_mais: Color) -> void:
	var telha := TELHA_CLARA
	var telha_sombra := TELHA_ESCURA
	var giro_cumeeira := giro + PI * 0.5
	var y_beiral := CASA_PE_DIREITO
	telhado_duas_aguas(sup, centro + Vector3(0.0, y_beiral, 0.0),
		CASA_FUNDURA, comprimento, CASA_PICO, giro_cumeeira,
		telha, telha_sombra, CASA_BEIRAL)
	# Oitoes no plano das paredes de ponta, sob o avanco do beiral.
	var ao_longo := Vector3(sin(giro_cumeeira), 0.0, cos(giro_cumeeira))
	for sx: float in [-1.0, 1.0]:
		oitao(sup, &"reboco",
			centro + ao_longo * (comprimento * 0.5 * sx) + Vector3(0.0, y_beiral, 0.0),
			CASA_FUNDURA, CASA_PICO,
			giro_cumeeira + (0.0 if sx > 0.0 else PI),
			caiacao_mais if sx > 0.0 else caiacao)
	# Tabica: a tabua escura que fecha a ponta da telha. E ela que desenha a
	# linha reta do beiral contra o ceu, e o beiral e metade da silhueta.
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	for sz: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"tabua",
			centro + frente * ((CASA_FUNDURA * 0.5 + CASA_BEIRAL) * sz)
				+ Vector3(0.0, y_beiral - 0.04, 0.0),
			Vector3(0.1, 0.2, comprimento + CASA_BEIRAL * 2.0),
			Color("32241a"), giro_cumeeira, PSXMesh.FACE_TODAS, QUAD_TELHA)
	# Cachorros sob o beiral da FRENTE: as pontas de caibro que a capela ja tem.
	# A linha do beiral deixa de ser uma reta limpa e ganha dente — e a
	# carpintaria da cidade e uma so. So na frente: o fundo nao paga o triangulo.
	var n := maxi(1, int(comprimento / 1.1))
	for k in n:
		var u := -comprimento * 0.5 + (float(k) + 0.5) * comprimento / float(n)
		KitModular.caixa_cor(sup, &"tabua",
			centro + ao_longo * u + frente * (CASA_FUNDURA * 0.5 + 0.26)
				+ Vector3(0.0, y_beiral - 0.06, 0.0),
			Vector3(0.11, 0.12, 0.46), MADEIRA_ESCURA, giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)


## Placa do parque na entrada. Nome proprio: sem ele o parque e "um parque", e
## com ele o jogador diz "o parque tal", que e o comeco de saber onde esta.
static func placa(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"metal",
			base + Vector3(cos(giro) * 0.62 * lado, 0.66, -sin(giro) * 0.62 * lado),
			Vector3(0.09, 1.32, 0.09), Color("59554e"), giro,
			PSXMesh.FACE_TODAS, QUAD_FOLHA)
	KitModular.placa(sup, &"placa_parque", base + Vector3(0.0, 1.5, 0.0),
		Vector2(1.5, 0.62), giro, Color.WHITE, 0.8)
	KitModular.placa(sup, &"placa_parque", base + Vector3(0.0, 1.5, 0.0),
		Vector2(1.5, 0.62), giro + PI, Color(0.8, 0.8, 0.8), 0.8)
	colisao.append({"tamanho": Vector3(1.5, 1.9, 0.3),
		"pos": base + Vector3(0.0, 0.95, 0.0)})


# --- lago -------------------------------------------------------------------

## Lamina d'agua, um pouco abaixo da grama. Ver Y_GRAMA acima: a agua tem de
## ficar ABAIXO da margem, senao a borda do plano flutua sobre o barranco.
const Y_AGUA := 0.05
## Fundo do lago. Um metro e oitenta: passa da cabeca do jogador (1,75), que e
## o que separa "nadar" de "andar com agua na cintura".
const FUNDO_LAGO := -1.80
## Largura do barranco, em metros. E a rampa por onde se entra e se sai.
const MARGEM_LAGO := 3.4


## Escava o lago dentro de `r` e enche.
##
## Por que o barranco e feito de quatro lajes inclinadas e nao de degraus
## ---------------------------------------------------------------------
## Degrau e o jeito obvio e esta errado aqui: CharacterBody3D nao sobe degrau
## sozinho, entao um lago em degraus e uma armadilha — o jogador entra e nao
## volta. Quatro rampas de vinte e oito graus, uma por lado, sao subida e
## descida ao mesmo tempo, e o buraco que sobra em cada canto nao prende
## ninguem porque ali ja se esta nadando.
##
## As lajes se atravessam nos cantos de proposito. Recortar o canto custaria
## quatro triangulos por quina para consertar uma interseccao que fica um metro
## e meio debaixo de agua turva.
static func lago(sup: Dictionary, colisao: Array[Dictionary], r: Rect2) -> void:
	var interno := r.grow(-MARGEM_LAGO)
	if interno.size.x < 2.0 or interno.size.y < 2.0:
		return

	piso(sup, &"terra", interno, FUNDO_LAGO, Color(0.46, 0.48, 0.42))

	var queda := Y_GRAMA - FUNDO_LAGO
	var ang := atan2(queda, MARGEM_LAGO)
	var comp := sqrt(queda * queda + MARGEM_LAGO * MARGEM_LAGO)
	var meio_y := (Y_GRAMA + FUNDO_LAGO) * 0.5
	# [centro, tamanho, giro] de cada barranco. Ver a nota sobre o sinal do
	# angulo no cabecalho: a ponta que desce e sempre a de dentro.
	var lajes := [
		[Vector3(r.get_center().x, meio_y, (r.position.y + interno.position.y) * 0.5),
			Vector3(r.size.x, 0.4, comp), Vector3(ang, 0.0, 0.0)],
		[Vector3(r.get_center().x, meio_y, (r.end.y + interno.end.y) * 0.5),
			Vector3(r.size.x, 0.4, comp), Vector3(-ang, 0.0, 0.0)],
		[Vector3((r.position.x + interno.position.x) * 0.5, meio_y, r.get_center().y),
			Vector3(comp, 0.4, r.size.y), Vector3(0.0, 0.0, -ang)],
		[Vector3((r.end.x + interno.end.x) * 0.5, meio_y, r.get_center().y),
			Vector3(comp, 0.4, r.size.y), Vector3(0.0, 0.0, ang)],
	]
	for laje: Array in lajes:
		var centro: Vector3 = laje[0]
		if centro.x < -8.0 or centro.x > KitModular.CHUNK + 8.0:
			continue
		if centro.z < -8.0 or centro.z > KitModular.CHUNK + 8.0:
			continue
		var giro: Vector3 = laje[2]
		var base := Basis.from_euler(giro)
		KitModular.caixa_livre(sup, &"areia", centro, laje[1], base,
			Color(0.58, 0.50, 0.40), 3.0)
		colisao.append({"tamanho": laje[1], "pos": centro, "giro": giro})

	# Fundo caminhavel. Sem isto, com o chao do chunk furado, o jogador caia
	# abaixo do mundo no meio do lago.
	piso(sup, &"terra", interno, FUNDO_LAGO, Color(0.32, 0.36, 0.30))
	piso_solido(colisao, interno, FUNDO_LAGO + 0.08)

	# A lamina por ultimo, e por cima de tudo. O quad grande cai na subdivisao
	# padrao de dois metros, que e a resolucao da onda do psx_agua.
	piso(sup, &"agua_lago", r, Y_AGUA)

	# Fita de espuma na margem, so nos dois lados longos. Nos quatro ela vira
	# moldura de piscina; em dois le como a agua batendo onde bate mais vento.
	var fita := 0.9
	piso(sup, &"espuma", Rect2(r.position.x, r.position.y, r.size.x, fita),
		Y_AGUA + 0.012)
	piso(sup, &"espuma", Rect2(r.position.x, r.end.y - fita, r.size.x, fita),
		Y_AGUA + 0.012)


## Nenufar boiando. Deitado, e por isso usa a celula de vista de cima.
static func nenufar(sup: Dictionary, onde: Vector3, tam: float, giro: float,
		com_flor: bool) -> void:
	# Alfa 0: a folha boia parada. `flor` tem vento, e com alfa 1 a vitoria-regia
	# inteira escorregava sobre a agua como um tapete.
	AtlasKit.deitado(sup, &"flor", onde, Vector2(tam, tam),
		Vector2i(1, 1) if com_flor else Vector2i(0, 1), giro,
		Color(0.92, 0.95, 0.88, 0.0))


## Um par de planos cruzados com uma celula do atlas de flores.
##
## Cruzados, e nao billboard: billboard num jogo de PS1 e anacronismo, e a 480
## de largura o giro do plano se ve como um estalo. Dois planos a noventa graus
## leem como volume de qualquer angulo e custam quatro triangulos.
static func moita_de_flor(sup: Dictionary, base: Vector3, celula: Vector2i,
		tam: float, giro: float, cor: Color = Color.WHITE) -> void:
	for k in 2:
		var t := Transform3D(Basis(Vector3.UP, giro + PI * 0.5 * float(k)),
			base + Vector3(0.0, tam * 0.5, 0.0))
		AtlasKit.folha_ao_vento(sup, &"flor", Vector2(tam, tam), t, celula, cor)


## Deque de madeira avancando sobre a agua. E de onde se ve o lago inteiro, e e
## de onde o jogador pula.
static func deque(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		comprimento: float, giro: float) -> void:
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var altura := Y_GRAMA + 0.28
	var n := maxi(2, int(comprimento / 0.42))
	for i in n:
		var t := (float(i) + 0.5) / float(n)
		var p := base + frente * (comprimento * t)
		if p.x < -1.0 or p.x > KitModular.CHUNK + 1.0:
			continue
		if p.z < -1.0 or p.z > KitModular.CHUNK + 1.0:
			continue
		var tom := 0.86 + fmod(float(i) * 0.37, 0.24)
		KitModular.caixa_cor(sup, &"tabua", p + Vector3(0.0, altura, 0.0),
			Vector3(1.7, 0.08, comprimento / float(n) - 0.05),
			Color("7a6449") * tom, giro, PSXMesh.FACE_TODAS, 8.0)
	# Estacas. Duas por par, a cada metro e meio.
	var pares := maxi(2, int(comprimento / 1.5))
	for i in pares + 1:
		var p := base + frente * (comprimento * float(i) / float(pares))
		for lado: float in [-1.0, 1.0]:
			var e := p + Vector3(cos(giro), 0.0, -sin(giro)) * (0.72 * lado)
			if e.x < -1.0 or e.x > KitModular.CHUNK + 1.0:
				continue
			if e.z < -1.0 or e.z > KitModular.CHUNK + 1.0:
				continue
			KitModular.caixa_cor(sup, &"tabua",
				e + Vector3(0.0, (altura + FUNDO_LAGO) * 0.5, 0.0),
				Vector3(0.14, altura - FUNDO_LAGO, 0.14), Color("5f4d38"), giro,
				PSXMesh.FACE_TODAS, 8.0)
	colisao.append({
		"tamanho": Vector3(absf(sin(giro)) * comprimento + 1.7 * absf(cos(giro)),
			0.3, absf(cos(giro)) * comprimento + 1.7 * absf(sin(giro))),
		"pos": base + frente * (comprimento * 0.5) + Vector3(0.0, altura - 0.1, 0.0),
	})
