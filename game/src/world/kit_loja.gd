## O salao das lojas de verdade (LojaViva). So dados, nada de no: roda na thread
## do chunk, como KitBar.
##
## A loja e o terreo vazado do proprio predio, em coordenada de mundo: a fachada
## (ComercioVivo) abre UMA boca — porta de aco toda enrolada, ou vitrine com a
## porta de vidro aberta — e atras dela esta o salao inteiro, na largura do lote
## e na fundura do predio. Entra-se andando, sem acionar nada.
##
## O que enche o salao e o que a placa diz. Quatro plantas (LojaViva.Planta) e,
## dentro delas, o ramo escolhe as celulas de produto de cada prateleira, o
## balcao de vidro, o piso, a cor e o equipamento proprio: estufa e chapa na
## lanchonete, balcao frigorifico e varal de linguica no acougue, guiche de
## vidro na loterica, relogio de parede na relojoaria, cadeira e espelho no
## salao, pneu empilhado e compressor na borracharia.
##
## Custo: tudo e caixa e cartao. A frente de cada prateleira e UM cartao
## recortado do atlas loja_produtos (tools/gerar_lojas.py), e nao um produto por
## caixa — a mesma troca que a cadeira do bar fez, pelo mesmo orcamento de chunk.
class_name KitLoja
extends RefCounted

## Espessura das paredes do lado e do fundo.
const ESPESSURA := 0.15
## Piso da loja: rente a calcada, que e o topo do meio-fio.
const PISO := KitModular.ALTURA_MEIO_FIO
## Forro, logo abaixo da laje do primeiro andar.
const FORRO := KitModular.ALTURA_ANDAR - 0.06
## Onde o salao comeca (atras da parede da frente) e onde acaba (a parede de
## tras fica dentro de PROF_PREDIO, sem encostar no plano da fachada dos fundos).
const Z_FRENTE := 0.3
const Z_FUNDO := ChunkBuilder.PROF_PREDIO - 0.24
## Fundura da prateleira de parede e altura das tabuas (a partir do piso).
const PRATELEIRA := 0.42
const TABUAS: Array[float] = [0.12, 0.56, 1.0, 1.44, 1.88]
const ALTO_PRODUTO := 0.36
const ALTURA_BALCAO := 1.0

const MADEIRA := Color("8a6440")
const MADEIRA_ESCURA := Color("5a3e28")
const METAL_CINZA := Color("9aa0a2")
const FORMICA := Color("e8e2d2")
## O vidro da loja de conveniencia (psx_vitrine): transparente de perto,
## aceso e opaco de longe. O `vitrine` e azulejo pintado de loja, para casca.
const VIDRO := &"vitrine_loja"
const ESPELHO := Color("cfdade")


## O quadro da loja: origem no meio da frente do lote, no pe da parede; `lat`
## corre pela fachada (o mesmo `lateral` da ComercioVivo), `nor` aponta a rua.
class Q extends RefCounted:
	var o: Vector3
	var lat: Vector3
	var nor: Vector3
	var giro: float
	var w: float
	var ob: Obra
	var col: Array[Dictionary]

	## `x` pela fachada, `y` do pe da parede para cima, `z` da fachada para dentro.
	func p(x: float, y: float, z: float) -> Vector3:
		return o + lat * x + Vector3(0.0, y, 0.0) - nor * z

	## Caixa pelo centro, tamanho em (fachada, altura, fundura).
	func caixa(mat: StringName, x: float, y: float, z: float, t: Vector3,
			cor: Color = Color.WHITE) -> void:
		ob.caixa(mat, p(x, y, z), t, cor, giro)

	func solido(x: float, y: float, z: float, t: Vector3) -> void:
		KitModular.solido(col, p(x, y, z), t, giro)

	## Cartao virado para `n` (vetor de mundo), sem espelhar: o eixo u e UP x n.
	func cartao(mat: StringName, centro: Vector3, n: Vector3, tam: Vector2,
			uv: Rect2, cor: Color = Color.WHITE) -> void:
		var bx := Vector3.UP.cross(n).normalized()
		ob.cartao(mat, tam, Transform3D(Basis(bx, Vector3.UP, n), centro), uv, cor)


## A loja inteira. `frente` e o meio da frente do lote no pe da parede (a
## fachada fica AVANCO_FACHADA a frente dela), `larg` a largura do lote.
## Devolve o censo que o teste confere: prateleiras, equipe, clientes.
static func salao(sup: Dictionary, colisao: Array[Dictionary], props: Array[Dictionary],
		frente: Vector3, lat: Vector3, nor: Vector3, larg: float,
		plano: Dictionary) -> Dictionary:
	var q := Q.new()
	q.o = frente
	q.lat = lat
	q.nor = nor
	q.giro = atan2(nor.x, nor.z)
	q.w = larg - ESPESSURA * 2.0
	q.ob = Obra.new()
	q.col = colisao
	var k := int(plano["ramo"])
	var r: Dictionary = LojaViva.RAMOS[k]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(plano["semente"])
	var censo := {"prateleiras": 0, "equipe": 0, "clientes": 0, "ramo": r["id"]}

	_casca(q, larg, plano, r)
	var gente := {"equipe": [] as Array[Dictionary], "clientes": [] as Array[Dictionary]}
	match int(r["planta"]):
		LojaViva.Planta.BALCAO:
			_planta_balcao(q, r, plano, rng, censo, gente)
		LojaViva.Planta.LIVRE:
			_planta_livre(q, r, plano, rng, censo, gente)
		LojaViva.Planta.BELEZA:
			_planta_beleza(q, r, plano, rng, censo, gente)
		_:
			_planta_oficina(q, r, plano, rng, censo, gente)
	_luz(q, props, r, plano)
	_calcada(q, r, plano, rng)
	_pessoas(q, props, r, plano, rng, gente, censo)
	q.ob.despejar(sup)
	return censo


# --- casca ----------------------------------------------------------------------

## Piso, forro, paredes (a de dentro da frente tambem: o plano da fachada so e
## visto da rua) e a barra de azulejo. Toda parede tem colisao.
static func _casca(q: Q, larg: float, plano: Dictionary, r: Dictionary) -> void:
	var meia := q.w * 0.5
	var parede: Color = plano["parede"]
	var azulejo: Color = r["azulejo"]
	var fundo := Z_FUNDO
	var zc := (fundo - 0.06) * 0.5
	var alto := KitModular.ALTURA_ANDAR
	# Piso: da fachada ate o fundo, na largura toda do lote.
	q.caixa(r["piso"], 0.0, PISO - 0.05, zc, Vector3(larg, 0.1, fundo + 0.06),
		Color("d8d2c6") if r["piso"] == &"concreto" else Color.WHITE)
	q.solido(0.0, PISO - 0.25, zc, Vector3(larg + 0.2, 0.5, fundo + 0.3))
	# Forro de gesso e a laje por cima.
	q.caixa(&"bar_teto", 0.0, FORRO + 0.03, zc, Vector3(larg, 0.06, fundo + 0.06),
		Color("f2eee4"))
	# Paredes do lado e do fundo.
	for lado: float in [-1.0, 1.0]:
		var x := lado * (meia + ESPESSURA * 0.5)
		q.caixa(&"reboco", x, alto * 0.5, zc, Vector3(ESPESSURA, alto, fundo + 0.06), parede)
		q.solido(x, alto * 0.5, zc, Vector3(ESPESSURA, alto, fundo + 0.06))
	q.caixa(&"reboco", 0.0, alto * 0.5, fundo + ESPESSURA * 0.5,
		Vector3(larg, alto, ESPESSURA), parede.darkened(0.04))
	q.solido(0.0, alto * 0.5, fundo + ESPESSURA * 0.5, Vector3(larg, alto, ESPESSURA))
	# A parede da frente por dentro, dos dois lados da boca e em cima dela. Dois
	# centimetros longe do batente, que e da ParedeVazada.
	var boca: float = plano["boca"]
	var topo := ComercioVivo.TOPO_LOJA
	var pedaco := meia + ESPESSURA - boca * 0.5 - 0.02
	if pedaco > 0.02:
		for lado: float in [-1.0, 1.0]:
			var x := lado * (boca * 0.5 + 0.02 + pedaco * 0.5)
			q.caixa(&"reboco", x, alto * 0.5, 0.17, Vector3(pedaco, alto, 0.26), parede)
			q.solido(x, alto * 0.5, 0.12, Vector3(pedaco, alto, 0.36))
	q.caixa(&"reboco", 0.0, (topo + 0.02 + alto) * 0.5, 0.17,
		Vector3(boca + 0.04, alto - topo - 0.02, 0.26), parede)
	# O vidro fixo da vitrine (ComercioVivo._loja o desenha): so a porta de
	# vidro, numa ponta, deixa passar.
	if r["fachada"] == &"vitrine":
		var lado_p: float = plano["lado_porta"]
		var porta_w: float = plano["porta_w"]
		q.solido(-lado_p * porta_w * 0.5, PISO + 1.3, 0.2, Vector3(boca - porta_w, 2.6, 0.16))
	# Azulejo: barra ate o peito, ou a parede inteira (acougue).
	var h_az := FORRO - PISO - 0.1 if bool(r.get("azulejo_inteiro", false)) else 1.2
	var y_az := PISO + h_az * 0.5
	q.ob.placa(&"bar_azulejo", q.p(0.0, y_az, fundo - 0.012), Vector2(q.w, h_az), q.giro, azulejo)
	for lado: float in [-1.0, 1.0]:
		var n := q.lat * -lado
		q.ob.plano(&"bar_azulejo", q.p(lado * (meia - 0.012), y_az, (Z_FRENTE + fundo) * 0.5),
			Vector2(fundo - Z_FRENTE, h_az), n, q.nor * lado, azulejo, true)
	# Rodateto escuro e a faixa do rodape: o que fecha a caixa no olho.
	q.caixa(&"metal_pintado", 0.0, FORRO - 0.03, fundo - 0.02, Vector3(q.w, 0.05, 0.04),
		parede.darkened(0.25))


# --- plantas ----------------------------------------------------------------------

## Balcao atravessado. Na frente dele, o povo; atras, quem atende e a parede
## cheia do que se vende.
static func _planta_balcao(q: Q, r: Dictionary, plano: Dictionary,
		rng: RandomNumberGenerator, censo: Dictionary, gente: Dictionary) -> void:
	var meia := q.w * 0.5
	var z_bal := 4.35
	var passagem := 0.85
	var lado_passagem: float = -float(plano["lado_porta"])
	# O balcao vai da parede ate a passagem de quem atende.
	var x0 := -meia + passagem if lado_passagem < 0.0 else -meia
	var x1 := meia if lado_passagem < 0.0 else meia - passagem
	var guiche := bool(r.get("guiche", false))
	var frigo := bool(r.get("frigorifico", false))
	var vitrine: Array = r.get("vitrine", [])
	_balcao(q, x0, x1, z_bal, vitrine, frigo, guiche, rng)
	# A portinhola da passagem: meia porta de madeira, aberta contra o balcao.
	# Encostada na ponta do balcao, do lado de dentro: a passagem fica livre.
	var x_folha := (x0 - 0.04) if lado_passagem < 0.0 else (x1 + 0.04)
	q.caixa(&"interior_madeira", x_folha, 0.5 + PISO, z_bal + 0.66, Vector3(0.04, 0.9, 0.7),
		MADEIRA)
	# A parede de tras, cheia.
	var fundo: Array = r["fundo"]
	_prateleira_fundo(q, -meia + 0.05, meia - 0.05, Z_FUNDO, fundo, rng)
	censo["prateleiras"] = int(censo["prateleiras"]) + 1
	# Equipamento proprio, entre o balcao e a parede de tras.
	var z_eq := Z_FUNDO - PRATELEIRA - 0.75
	if frigo:
		_acougue(q, meia, z_eq)
	if bool(r.get("chapa", false)):
		_chapa(q, -lado_passagem * (meia - 0.9), Z_FUNDO - PRATELEIRA - 0.4)
	if bool(r.get("xerox", false)):
		_xerox(q, lado_passagem * (meia - 0.55), z_bal + 1.25)
	if bool(r.get("relogios", false)):
		_relogios(q, meia, rng)
	if bool(r.get("espelho", false)):
		_espelho_de_balcao(q, (x0 + x1) * 0.5 + 0.5, z_bal)
	# Os lados da frente: prateleira nas duas paredes, ou numa so quando o salao e
	# estreito — o corredor do cliente e de 1,6 m no minimo.
	var lados: Array = r["lados"]
	var z0 := Z_FRENTE + 0.45
	var z1 := z_bal - 0.9
	var dois := q.w - 2.0 * PRATELEIRA >= 3.2
	for lado: float in ([-1.0, 1.0] if dois else [float(plano["lado_porta"])]):
		_prateleira_lado(q, lado, z0, z1, lados, rng, 4)
		censo["prateleiras"] = int(censo["prateleiras"]) + 1
	# A bancada de preencher o jogo, na loterica, encostada no vidro da frente.
	if guiche:
		q.caixa(&"bar_formica", 0.0, PISO + 0.95, Z_FRENTE + 0.35, Vector3(1.6, 0.05, 0.4), FORMICA)
		q.caixa(&"metal", 0.0, PISO + 0.46, Z_FRENTE + 0.35, Vector3(0.08, 0.92, 0.08), METAL_CINZA)
		q.solido(0.0, PISO + 0.48, Z_FRENTE + 0.35, Vector3(1.6, 0.96, 0.4))
		q.cartao(&"loja_produtos", q.p(0.0, PISO + 0.99, Z_FRENTE + 0.35), Vector3.UP,
			Vector2(1.4, 0.3), LojaViva.uv_produto(LojaViva.P.LOTERIA))
	# Banquetas de balcao na lanchonete: quem come fica de frente para o chapeiro.
	var assentos: Array[Vector3] = []
	if bool(r.get("banquetas", false)):
		var n := int((x1 - x0 - 0.4) / 0.75)
		for i in mini(n, 4):
			var x := x0 + 0.5 + i * 0.75
			_banqueta(q, x, z_bal - 0.62)
			assentos.append(Vector3(x, 0.72, z_bal - 0.62))
	# Caixa registradora na ponta do balcao junto da passagem.
	var x_caixa := (x0 + 0.45) if lado_passagem < 0.0 else (x1 - 0.45)
	_registradora(q, x_caixa, z_bal)
	_cartaz(q, r, meia, z1 - 0.5)
	# Gente. Equipe atras do balcao; clientes na frente dele e nas prateleiras.
	var equipe: Array = r["equipe"]
	for i in equipe.size():
		var t := (float(i) + 0.5) / float(equipe.size())
		var x := lerpf(x0 + 0.4, x1 - 0.4, t)
		if frigo and i == 0:
			x = lerpf(x0, x1, 0.35)
		(gente["equipe"] as Array[Dictionary]).append({"pos": Vector3(x, 0.0, z_bal + 0.85),
			"foco": Vector3(x * 0.4, 1.5, 1.6)})
	var z_fila := z_bal - (1.2 if not assentos.is_empty() else 0.75)
	var pontos: Array[Vector3] = [
		Vector3(lerpf(x0, x1, 0.3), 0.0, z_fila),
		Vector3(lerpf(x0, x1, 0.7), 0.0, z_fila),
		Vector3(-meia + PRATELEIRA + 0.5, 0.0, (z0 + z1) * 0.5),
		Vector3(meia - PRATELEIRA - 0.5, 0.0, (z0 + z1) * 0.5),
		Vector3(0.0, 0.0, Z_FRENTE + 1.1),
	]
	gente["pontos"] = pontos
	gente["assentos"] = assentos
	gente["foco_cliente"] = Vector3(0.0, 1.3, z_bal + 1.0)


## Prateleira nas paredes, ilha no meio e o caixa na entrada.
static func _planta_livre(q: Q, r: Dictionary, plano: Dictionary,
		rng: RandomNumberGenerator, censo: Dictionary, gente: Dictionary) -> void:
	var meia := q.w * 0.5
	var lado_caixa: float = -float(plano["lado_porta"])
	# O caixa: balcao curto ao longo da parede, perto da boca, com quem atende
	# entre ele e a parede.
	var x_bal := lado_caixa * (meia - 1.05)
	var z_bal0 := Z_FRENTE + 0.55
	var z_bal1 := Z_FRENTE + 2.0
	q.caixa(&"interior_madeira", x_bal, PISO + ALTURA_BALCAO * 0.5, (z_bal0 + z_bal1) * 0.5,
		Vector3(0.6, ALTURA_BALCAO, z_bal1 - z_bal0), MADEIRA_ESCURA)
	q.caixa(&"bar_formica", x_bal, PISO + ALTURA_BALCAO + 0.02, (z_bal0 + z_bal1) * 0.5,
		Vector3(0.7, 0.04, z_bal1 - z_bal0 + 0.08), FORMICA)
	q.solido(x_bal, PISO + ALTURA_BALCAO * 0.5, (z_bal0 + z_bal1) * 0.5,
		Vector3(0.62, ALTURA_BALCAO, z_bal1 - z_bal0))
	_registradora_lado(q, x_bal, z_bal0 + 0.4, lado_caixa)
	# Balanca de prato na mercearia e na racao.
	if r["id"] in [&"mercearia", &"racao"]:
		_balanca(q, x_bal, z_bal1 - 0.4)
	# Paredes: o fundo inteiro, e os lados depois do caixa.
	_prateleira_fundo(q, -meia + 0.05, meia - 0.05, Z_FUNDO, r["fundo"], rng)
	censo["prateleiras"] = int(censo["prateleiras"]) + 1
	for lado: float in [-1.0, 1.0]:
		var z0 := (z_bal1 + 0.5) if lado == lado_caixa else Z_FRENTE + 0.5
		_prateleira_lado(q, lado, z0, Z_FUNDO - PRATELEIRA - 0.1, r["lados"], rng, 4)
		censo["prateleiras"] = int(censo["prateleiras"]) + 1
	# O meio: ilha de gondola, pilha de saco, ou o banco de provar sapato.
	var livre := q.w - 2.0 * PRATELEIRA
	var z_meio0 := Z_FRENTE + 2.5
	var z_meio1 := Z_FUNDO - PRATELEIRA - 1.2
	var pontos: Array[Vector3] = []
	var assentos: Array[Vector3] = []
	var corredor := minf(1.0, (livre - 0.9) * 0.5)
	if r.has("ilha") and livre >= 2.9:
		_ilha(q, 0.0, z_meio0, z_meio1, r["ilha"], rng)
		censo["prateleiras"] = int(censo["prateleiras"]) + 1
	if r.has("pilhas"):
		_pilhas(q, r, plano, rng, meia)
	if bool(r.get("banco", false)):
		# O banco de provar, no meio, com o pezinho inclinado de quem prova.
		q.caixa(&"bar_formica", 0.0, PISO + 0.22, (z_meio0 + z_meio1) * 0.5,
			Vector3(0.45, 0.44, 1.6), Color("7a2a24"))
		q.solido(0.0, PISO + 0.22, (z_meio0 + z_meio1) * 0.5, Vector3(0.45, 0.44, 1.6))
		q.caixa(&"interior_madeira", 0.55, PISO + 0.12, (z_meio0 + z_meio1) * 0.5,
			Vector3(0.3, 0.24, 0.4), MADEIRA)
		assentos.append(Vector3(0.0, 0.46, (z_meio0 + z_meio1) * 0.5 - 0.4))
	var x_corr := 0.45 + corredor * 0.5 + 0.05
	for lado: float in [-1.0, 1.0]:
		pontos.append(Vector3(lado * x_corr, 0.0, z_meio0 + 0.2))
		pontos.append(Vector3(lado * x_corr, 0.0, z_meio1 - 0.5))
	pontos.append(Vector3(x_bal - lado_caixa * 0.9, 0.0, (z_bal0 + z_bal1) * 0.5))
	pontos.append(Vector3(0.0, 0.0, Z_FRENTE + 1.2))
	_cartaz(q, r, meia, Z_FRENTE + 2.6)
	var equipe: Array = r["equipe"]
	var postos: Array[Dictionary] = [{"pos": Vector3(lado_caixa * (meia - 0.4), 0.0,
		(z_bal0 + z_bal1) * 0.5), "foco": Vector3(0.0, 1.5, Z_FRENTE + 1.0)}]
	if equipe.size() > 1:
		# O segundo repoe prateleira no fundo.
		postos.append({"pos": Vector3(-lado_caixa * x_corr, 0.0, Z_FUNDO - PRATELEIRA - 0.35),
			"foco": Vector3(-lado_caixa * x_corr, 1.2, Z_FUNDO)})
	gente["equipe"] = postos
	gente["pontos"] = pontos
	gente["assentos"] = assentos
	gente["foco_cliente"] = Vector3(-lado_caixa * meia, 1.3, (z_meio0 + z_meio1) * 0.5)


## Salao de beleza: as estacoes numa parede, a espera na outra, o lavatorio no
## fundo.
static func _planta_beleza(q: Q, r: Dictionary, plano: Dictionary,
		rng: RandomNumberGenerator, censo: Dictionary, gente: Dictionary) -> void:
	var meia := q.w * 0.5
	var lado: float = float(plano["lado_porta"])
	var estacoes: Array[float] = [1.9, 3.5, 5.1]
	var assentos: Array[Vector3] = []
	var postos: Array[Dictionary] = []
	for i in estacoes.size():
		var z := estacoes[i]
		var xp := lado * (meia - 0.05)
		# Espelho na parede e a bancadinha embaixo dele.
		q.ob.plano(&"metal_pintado", q.p(xp - lado * 0.045, PISO + 1.45, z), Vector2(0.9, 0.9),
			q.lat * -lado, q.nor * lado, ESPELHO, false)
		q.caixa(&"metal_pintado", xp - lado * 0.02, PISO + 1.45, z, Vector3(0.03, 1.0, 1.0),
			Color("f0ece4"))
		q.caixa(&"bar_formica", xp - lado * 0.2, PISO + 0.88, z, Vector3(0.4, 0.05, 0.9), FORMICA)
		q.solido(xp - lado * 0.2, PISO + 0.45, z, Vector3(0.4, 0.9, 0.9))
		q.cartao(&"loja_produtos", q.p(xp - lado * 0.12, PISO + 0.9 + 0.12, z), q.lat * -lado,
			Vector2(0.8, 0.24), LojaViva.uv_produto(LojaViva.P.COSMETICOS))
		# A cadeira de cabeleireiro: pe cromado, assento e encosto de courino.
		var xc := xp - lado * 1.0
		var cor_cadeira := Color("2a2626") if i % 2 == 0 else Color("8a2a3a")
		q.ob.cilindro(&"metal", q.p(xc, 0.0, z), 0.22, PISO + 0.08, METAL_CINZA)
		q.caixa(&"metal", xc, PISO + 0.26, z, Vector3(0.08, 0.3, 0.08), METAL_CINZA)
		q.caixa(&"fumaca_courino", xc, PISO + 0.45, z, Vector3(0.5, 0.1, 0.5), cor_cadeira)
		q.caixa(&"fumaca_courino", xc - lado * 0.27, PISO + 0.8, z, Vector3(0.08, 0.7, 0.5),
			cor_cadeira)
		if i != 0:
			q.solido(xc, PISO + 0.4, z, Vector3(0.55, 0.8, 0.55))
		else:
			assentos.append(Vector3(xc, 0.5, z))
			postos.append({"pos": Vector3(xc + lado * 0.1, 0.0, z + 0.55),
				"foco": Vector3(xc, 1.2, z)})
	# O lavatorio de costas para o fundo.
	var xl := lado * (meia - 1.0)
	q.caixa(&"mercado_louca", xl, PISO + 0.85, Z_FUNDO - 0.35, Vector3(0.6, 0.2, 0.45), Color.WHITE)
	q.caixa(&"bar_formica", xl, PISO + 0.4, Z_FUNDO - 0.35, Vector3(0.6, 0.8, 0.4), FORMICA)
	q.solido(xl, PISO + 0.45, Z_FUNDO - 0.35, Vector3(0.6, 0.9, 0.45))
	# A espera: sofa de dois lugares e a mesinha de revista, na outra parede.
	var xs := -lado * (meia - 0.35)
	q.caixa(&"fumaca_courino", xs, PISO + 0.22, 2.2, Vector3(0.6, 0.44, 1.5), Color("5a4a6a"))
	q.caixa(&"fumaca_courino", xs - lado * 0.25, PISO + 0.62, 2.2, Vector3(0.12, 0.5, 1.5),
		Color("4a3a5a"))
	# Colisao do encosto e da metade de tras: a da frente e de quem espera.
	q.solido(xs - lado * 0.25, PISO + 0.45, 2.2, Vector3(0.12, 0.9, 1.5))
	q.solido(xs, PISO + 0.22, 2.6, Vector3(0.6, 0.44, 0.7))
	assentos.append(Vector3(xs + lado * 0.05, 0.47, 1.8))
	q.caixa(&"interior_madeira", xs + lado * 0.1, PISO + 0.22, 3.4, Vector3(0.5, 0.44, 0.5), MADEIRA)
	q.solido(xs + lado * 0.1, PISO + 0.22, 3.4, Vector3(0.5, 0.44, 0.5))
	q.cartao(&"loja_produtos", q.p(xs + lado * 0.1, PISO + 0.45, 3.4), Vector3.UP,
		Vector2(0.44, 0.22), LojaViva.uv_produto(LojaViva.P.REVISTAS))
	# A mesinha da manicure no fundo, do lado da espera.
	var xm := -lado * (meia - 0.9)
	q.caixa(&"bar_formica", xm, PISO + 0.7, Z_FUNDO - 1.6, Vector3(0.7, 0.04, 0.5), FORMICA)
	q.caixa(&"metal", xm, PISO + 0.35, Z_FUNDO - 1.6, Vector3(0.06, 0.7, 0.06), METAL_CINZA)
	q.solido(xm, PISO + 0.36, Z_FUNDO - 1.6, Vector3(0.7, 0.72, 0.5))
	q.cartao(&"loja_produtos", q.p(xm, PISO + 0.73, Z_FUNDO - 1.6), Vector3.UP,
		Vector2(0.6, 0.18), LojaViva.uv_produto(LojaViva.P.COSMETICOS))
	postos.append({"pos": Vector3(xm, 0.0, Z_FUNDO - 1.05), "foco": Vector3(xm, 0.8, Z_FUNDO - 1.6)})
	# A prateleira do fundo para antes do lavatorio.
	var xf0 := (-meia + 0.05) if lado > 0.0 else (-meia + 1.6)
	var xf1 := (meia - 1.6) if lado > 0.0 else (meia - 0.05)
	_prateleira_fundo(q, xf0, xf1, Z_FUNDO, r["fundo"], rng)
	censo["prateleiras"] = int(censo["prateleiras"]) + 1
	_cartaz(q, r, meia, 4.2, -lado)
	gente["equipe"] = postos
	gente["assentos"] = assentos
	gente["pontos"] = [Vector3(0.0, 0.0, 1.4), Vector3(0.0, 0.0, 3.6)] as Array[Vector3]
	gente["foco_cliente"] = Vector3(lado * meia, 1.4, 1.9)


## Borracharia: chao livre, pneu empilhado, compressor e a bancada.
static func _planta_oficina(q: Q, r: Dictionary, plano: Dictionary,
		rng: RandomNumberGenerator, censo: Dictionary, gente: Dictionary) -> void:
	var meia := q.w * 0.5
	var lado: float = float(plano["lado_porta"])
	_prateleira_fundo(q, -meia + 0.05, meia - 0.05, Z_FUNDO, r["fundo"], rng)
	censo["prateleiras"] = int(censo["prateleiras"]) + 1
	# Pilhas de pneu ao longo de uma parede.
	for i in 4:
		var z := 1.3 + i * 1.05
		var n := rng.randi_range(3, 6)
		var x := -lado * (meia - 0.42)
		for j in n:
			q.ob.cilindro(&"fumaca_pneu", q.p(x + rng.randf_range(-0.04, 0.04), PISO + j * 0.2,
				z + rng.randf_range(-0.04, 0.04)), 0.34, 0.2, Color("2a2a2c"), 8)
		q.solido(x, PISO + n * 0.1, z, Vector3(0.7, n * 0.2, 0.7))
	# Painel de ferramentas na outra parede, a bancada com morsa embaixo dele.
	var xb := lado * (meia - 0.35)
	q.cartao(&"loja_produtos", q.p(lado * (meia - 0.02), PISO + 1.6, 3.2), q.lat * -lado,
		Vector2(2.2, 1.1), LojaViva.uv_produto(LojaViva.P.FERRAMENTAS))
	q.caixa(&"interior_madeira", xb, PISO + 0.85, 3.2, Vector3(0.6, 0.08, 2.2), MADEIRA_ESCURA)
	for dz: float in [-1.0, 1.0]:
		q.caixa(&"metal", xb, PISO + 0.42, 3.2 + dz * 1.0, Vector3(0.5, 0.84, 0.06), Color("4a4c4e"))
	q.solido(xb, PISO + 0.45, 3.2, Vector3(0.6, 0.9, 2.2))
	q.caixa(&"metal_pintado", xb, PISO + 1.0, 2.6, Vector3(0.2, 0.2, 0.3), Color("3a5a8a"))
	# Compressor: o tanque deitado e o motor em cima.
	var xc := lado * (meia - 0.5)
	var basis := Basis(q.lat, Vector3.UP, q.nor) * Basis(Vector3(0, 0, 1), PI * 0.5)
	q.ob.livre(&"metal_pintado", q.p(xc, PISO + 0.35, 5.4), Vector3(0.5, 0.9, 0.5), basis,
		Color("b83a2a"))
	q.caixa(&"metal", xc, PISO + 0.72, 5.4, Vector3(0.3, 0.24, 0.3), Color("3a3c3e"))
	q.solido(xc, PISO + 0.42, 5.4, Vector3(0.6, 0.84, 0.95))
	# Um pneu no chao, deitado no meio, e o macaco jacare.
	q.ob.cilindro(&"fumaca_pneu", q.p(0.3, PISO, 2.6), 0.33, 0.2, Color("2a2a2c"), 8)
	q.caixa(&"metal_pintado", -0.4, PISO + 0.1, 4.1, Vector3(0.3, 0.16, 0.8), Color("c8a030"))
	_cartaz(q, r, meia, 5.2, lado)
	gente["equipe"] = [
		{"pos": Vector3(xb - lado * 0.55, 0.0, 3.2), "foco": Vector3(xb, 1.0, 3.2)},
		{"pos": Vector3(0.6, 0.0, 2.2), "foco": Vector3(0.3, 0.2, 2.6)},
	] as Array[Dictionary]
	gente["pontos"] = [Vector3(0.0, 0.0, 1.2), Vector3(0.0, 0.0, 3.4)] as Array[Vector3]
	gente["assentos"] = [] as Array[Vector3]
	gente["foco_cliente"] = Vector3(0.3, 0.3, 2.6)


# --- moveis -------------------------------------------------------------------------

## Prateleira de parede de tras: montantes, tabuas, o fundo de madeira e UM
## cartao de produto por tabua (a fileira inteira recortada).
static func _prateleira_fundo(q: Q, x0: float, x1: float, z_parede: float, celulas: Array,
		rng: RandomNumberGenerator) -> void:
	var comp := x1 - x0
	if comp < 0.6:
		return
	var xm := (x0 + x1) * 0.5
	var zc := z_parede - PRATELEIRA * 0.5
	var alto := TABUAS[-1] + ALTO_PRODUTO + 0.12
	q.caixa(&"interior_madeira", xm, PISO + alto * 0.5, z_parede - 0.02, Vector3(comp, alto, 0.03),
		MADEIRA_ESCURA)
	var n_mod := maxi(1, int(round(comp / 1.2)))
	for m in n_mod + 1:
		var x := x0 + comp * float(m) / float(n_mod)
		q.caixa(&"interior_madeira", clampf(x, x0 + 0.02, x1 - 0.02), PISO + alto * 0.5, zc,
			Vector3(0.04, alto, PRATELEIRA), MADEIRA)
	for i in TABUAS.size():
		var y := PISO + TABUAS[i]
		q.caixa(&"interior_madeira", xm, y, zc, Vector3(comp, 0.03, PRATELEIRA), MADEIRA)
		var cel: int = celulas[(i + rng.randi() % 2) % celulas.size()] if i > 0 \
			else celulas[0]
		for m in n_mod:
			var xa := x0 + comp * (float(m) + 0.5) / float(n_mod)
			q.cartao(&"loja_produtos", q.p(xa, y + 0.015 + ALTO_PRODUTO * 0.5, zc + 0.02), q.nor,
				Vector2(comp / float(n_mod) - 0.06, ALTO_PRODUTO), LojaViva.uv_produto(cel))
	q.solido(xm, PISO + alto * 0.5, zc, Vector3(comp, alto, PRATELEIRA))


## Prateleira na parede do lado `lado` (-1 ou +1 em x), de z0 a z1.
static func _prateleira_lado(q: Q, lado: float, z0: float, z1: float, celulas: Array,
		rng: RandomNumberGenerator, niveis: int = 5) -> void:
	var comp := z1 - z0
	if comp < 0.6:
		return
	var meia := q.w * 0.5
	var xc := lado * (meia - PRATELEIRA * 0.5)
	var zm := (z0 + z1) * 0.5
	var n := q.lat * -lado
	var alto := TABUAS[niveis - 1] + ALTO_PRODUTO + 0.12
	q.caixa(&"interior_madeira", lado * (meia - 0.02), PISO + alto * 0.5, zm,
		Vector3(0.03, alto, comp), MADEIRA_ESCURA)
	var n_mod := maxi(1, int(round(comp / 1.2)))
	for m in n_mod + 1:
		var z := z0 + comp * float(m) / float(n_mod)
		q.caixa(&"interior_madeira", xc, PISO + alto * 0.5, clampf(z, z0 + 0.02, z1 - 0.02),
			Vector3(PRATELEIRA, alto, 0.04), MADEIRA)
	for i in niveis:
		var y := PISO + TABUAS[i]
		q.caixa(&"interior_madeira", xc, y, zm, Vector3(PRATELEIRA, 0.03, comp), MADEIRA)
		var cel: int = celulas[(i + rng.randi() % 3) % celulas.size()]
		for m in n_mod:
			var za := z0 + comp * (float(m) + 0.5) / float(n_mod)
			q.cartao(&"loja_produtos", q.p(xc - lado * 0.02, y + 0.015 + ALTO_PRODUTO * 0.5, za),
				n, Vector2(comp / float(n_mod) - 0.06, ALTO_PRODUTO), LojaViva.uv_produto(cel))
	q.solido(xc, PISO + alto * 0.5, zm, Vector3(PRATELEIRA, alto, comp))


## Gondola de ilha, dos dois lados, ao longo de z.
static func _ilha(q: Q, x: float, z0: float, z1: float, celulas: Array,
		rng: RandomNumberGenerator) -> void:
	var comp := z1 - z0
	if comp < 0.8:
		return
	var zm := (z0 + z1) * 0.5
	var alto := 1.45
	q.caixa(&"metal_pintado", x, PISO + alto * 0.5, zm, Vector3(0.06, alto, comp), Color("e4e2dc"))
	q.caixa(&"metal_pintado", x, PISO + 0.06, zm, Vector3(0.9, 0.12, comp), Color("5a5c5e"))
	q.caixa(&"metal_pintado", x, PISO + alto + 0.03, zm, Vector3(0.9, 0.06, comp),
		Color("c8452e"))
	for i in 3:
		var y := PISO + 0.14 + i * 0.44
		q.caixa(&"metal_pintado", x, y, zm, Vector3(0.9, 0.025, comp), Color("d8d6d0"))
		for s: float in [-1.0, 1.0]:
			var cel: int = celulas[(i + rng.randi() % 2) % celulas.size()]
			q.cartao(&"loja_produtos", q.p(x + s * 0.34, y + 0.2, zm), q.lat * s,
				Vector2(comp - 0.08, 0.36), LojaViva.uv_produto(cel))
	q.solido(x, PISO + alto * 0.5, zm, Vector3(0.9, alto, comp))
	# A ponta de gondola, virada para a porta: a oferta da semana, que e o que o
	# cliente ve primeiro ao entrar.
	q.caixa(&"metal_pintado", x, PISO + alto * 0.5, z0 - 0.02, Vector3(0.9, alto, 0.04),
		Color("e4e2dc"))
	for i in 3:
		var y := PISO + 0.14 + i * 0.44
		q.cartao(&"loja_produtos", q.p(x, y + 0.2, z0 - 0.05), q.nor, Vector2(0.84, 0.36),
			LojaViva.uv_produto(celulas[(i + 1) % celulas.size()]))
	q.cartao(&"loja_cartazes", q.p(x, PISO + alto + 0.3, z0 - 0.05), q.nor, Vector2(0.5, 0.5),
		LojaViva.uv_cartaz(6))


## Balcao atravessado. `vitrine`: o tampo e de vidro, com o produto la dentro e
## a luz fria; `frigo` e o balcao refrigerado branco do acougue; `guiche` sobe
## o vidro ate o forro com as duas janelinhas da loterica.
static func _balcao(q: Q, x0: float, x1: float, z: float, vitrine: Array, frigo: bool,
		guiche: bool, rng: RandomNumberGenerator) -> void:
	var comp := x1 - x0
	var xm := (x0 + x1) * 0.5
	var fundo := 0.62
	var corpo := Color("f2f2ee") if frigo else (MADEIRA_ESCURA if not guiche else Color("d8d4c8"))
	var mat_corpo: StringName = &"mercado_inox" if frigo else &"interior_madeira"
	var h_corpo := 0.62 if not vitrine.is_empty() else ALTURA_BALCAO
	q.caixa(mat_corpo, xm, PISO + h_corpo * 0.5, z, Vector3(comp, h_corpo, fundo), corpo)
	# Rodape escuro: o balcao pousa no piso em vez de flutuar.
	q.caixa(&"metal_pintado", xm, PISO + 0.05, z - fundo * 0.5 - 0.005, Vector3(comp, 0.1, 0.01),
		Color("2a2a2a"))
	if not vitrine.is_empty():
		# A caixa de vidro: vidro na frente e em cima, produto no fundo iluminado.
		var y0 := PISO + h_corpo
		var hv := ALTURA_BALCAO + 0.1 - h_corpo
		q.caixa(&"metal_pintado", xm, y0 + 0.01, z, Vector3(comp, 0.02, fundo), Color("f4f4f0"))
		var n_mod := maxi(1, int(round(comp / 1.1)))
		for m in n_mod:
			var xa := x0 + comp * (float(m) + 0.5) / float(n_mod)
			var cel: int = vitrine[(m + rng.randi() % 2) % vitrine.size()]
			q.cartao(&"loja_produtos", q.p(xa, y0 + 0.02 + 0.11, z + 0.05), q.nor,
				Vector2(comp / float(n_mod) - 0.05, 0.22), LojaViva.uv_produto(cel))
			q.cartao(&"loja_produtos", q.p(xa, y0 + 0.03, z), Vector3.UP,
				Vector2(comp / float(n_mod) - 0.05, fundo - 0.1), LojaViva.uv_produto(cel))
		q.ob.plano(VIDRO, q.p(xm, y0 + hv * 0.5, z - fundo * 0.5), Vector2(comp, hv), q.nor,
			q.lat, Color(0.9, 0.96, 1.0), false)
		q.ob.plano(VIDRO, q.p(xm, y0 + hv, z), Vector2(comp, fundo), Vector3.UP, q.lat,
			Color(0.9, 0.96, 1.0), false)
		for x: float in [x0 + 0.015, x1 - 0.015]:
			q.caixa(&"metal", x, y0 + hv * 0.5, z, Vector3(0.03, hv, fundo), METAL_CINZA)
		# O tubo de luz dentro da vitrine.
		q.caixa(&"lampada", xm, y0 + hv - 0.03, z + fundo * 0.3, Vector3(comp - 0.2, 0.025, 0.03))
	else:
		q.caixa(&"bar_formica", xm, PISO + ALTURA_BALCAO + 0.02, z,
			Vector3(comp + 0.04, 0.04, fundo + 0.06), FORMICA)
	q.solido(xm, PISO + 0.55, z, Vector3(comp, 1.1, fundo))
	if guiche:
		# Vidro ate o forro, com as janelinhas.
		var y_vidro := PISO + ALTURA_BALCAO + 0.04
		var hv2 := FORRO - y_vidro
		var n := 2
		for i in n:
			var xa := x0 + comp * (float(i) + 0.5) / float(n)
			q.ob.plano(VIDRO, q.p(xa, y_vidro + 0.3 + (hv2 - 0.3) * 0.5, z + 0.05),
				Vector2(comp / float(n) - 0.08, hv2 - 0.3), q.nor, q.lat, Color.WHITE, false)
			q.caixa(&"metal", xa, y_vidro + 0.3, z + 0.05, Vector3(comp / float(n), 0.04, 0.05),
				METAL_CINZA)
		for i in n + 1:
			var xa := x0 + comp * float(i) / float(n)
			q.caixa(&"metal", clampf(xa, x0 + 0.03, x1 - 0.03), y_vidro + hv2 * 0.5, z + 0.05,
				Vector3(0.06, hv2, 0.06), METAL_CINZA)
		q.solido(xm, y_vidro + hv2 * 0.5, z + 0.05, Vector3(comp, hv2, 0.06))


static func _registradora(q: Q, x: float, z: float) -> void:
	var y := PISO + ALTURA_BALCAO + 0.1
	q.caixa(&"metal_pintado", x, y + 0.08, z + 0.05, Vector3(0.36, 0.16, 0.34), Color("3a3c40"))
	q.caixa(&"metal_pintado", x, y + 0.24, z + 0.12, Vector3(0.3, 0.12, 0.04), Color("2a2c30"))
	q.caixa(&"painel_luz", x, y + 0.25, z + 0.1, Vector3(0.2, 0.05, 0.01), Color("8af0a0"))


static func _registradora_lado(q: Q, x: float, z: float, lado: float) -> void:
	var y := PISO + ALTURA_BALCAO + 0.04
	q.caixa(&"metal_pintado", x, y + 0.08, z, Vector3(0.34, 0.16, 0.36), Color("3a3c40"))
	q.caixa(&"metal_pintado", x + lado * 0.1, y + 0.24, z, Vector3(0.04, 0.12, 0.3), Color("2a2c30"))


static func _balanca(q: Q, x: float, z: float) -> void:
	var y := PISO + ALTURA_BALCAO + 0.04
	q.caixa(&"metal_pintado", x, y + 0.05, z, Vector3(0.3, 0.1, 0.3), Color("d83a2a"))
	q.caixa(&"metal", x, y + 0.13, z, Vector3(0.34, 0.02, 0.34), METAL_CINZA)
	q.caixa(&"metal_pintado", x, y + 0.26, z + 0.12, Vector3(0.24, 0.22, 0.06), Color("e8e4dc"))


static func _banqueta(q: Q, x: float, z: float) -> void:
	q.caixa(&"fumaca_courino", x, PISO + 0.7, z, Vector3(0.34, 0.06, 0.34), Color("a8322a"))
	q.caixa(&"metal", x, PISO + 0.35, z, Vector3(0.05, 0.7, 0.05), METAL_CINZA)
	q.ob.cilindro(&"metal", q.p(x, PISO, z), 0.16, 0.03, METAL_CINZA, 8)
	# Sem colisao: o cliente da lanchonete nasce sentado nela, e a capsula dele
	# dentro de uma caixa solida o empurraria para fora.


## Estufa e chapa da lanchonete, na bancada do fundo.
static func _chapa(q: Q, x: float, z: float) -> void:
	q.caixa(&"mercado_inox", x, PISO + 0.45, z, Vector3(1.4, 0.9, 0.6), Color("d8dcdc"))
	q.caixa(&"metal", x - 0.3, PISO + 0.93, z, Vector3(0.7, 0.04, 0.5), Color("2a2a2a"))
	q.caixa(&"mercado_inox", x + 0.45, PISO + 1.05, z, Vector3(0.45, 0.28, 0.4), Color("e4e8e8"))
	q.cartao(&"loja_produtos", q.p(x + 0.45, PISO + 1.05, z - 0.21), q.nor, Vector2(0.42, 0.22),
		LojaViva.uv_produto(LojaViva.P.SALGADOS))
	q.solido(x, PISO + 0.5, z, Vector3(1.4, 1.0, 0.6))
	# A coifa sobre a chapa.
	q.caixa(&"mercado_inox", x - 0.3, FORRO - 0.3, z, Vector3(0.9, 0.3, 0.6), Color("c8cccc"))


## O acougue: o cepo, o gancho com a linguica e o moedor.
static func _acougue(q: Q, meia: float, z: float) -> void:
	q.caixa(&"interior_madeira", -meia * 0.4, PISO + 0.42, z, Vector3(0.6, 0.84, 0.6), Color("b89060"))
	q.solido(-meia * 0.4, PISO + 0.42, z, Vector3(0.6, 0.84, 0.6))
	q.caixa(&"mercado_inox", meia * 0.45, PISO + 0.5, z, Vector3(1.0, 1.0, 0.55), Color("dcdcd8"))
	q.caixa(&"metal", meia * 0.45 + 0.2, PISO + 1.15, z, Vector3(0.2, 0.3, 0.2), METAL_CINZA)
	q.solido(meia * 0.45, PISO + 0.5, z, Vector3(1.0, 1.0, 0.55))
	# O trilho de gancho, alto, correndo a parede de tras.
	q.caixa(&"metal", 0.0, PISO + 2.25, Z_FUNDO - PRATELEIRA - 0.2, Vector3(q.w - 1.0, 0.04, 0.04),
		METAL_CINZA)
	q.cartao(&"loja_produtos", q.p(0.0, PISO + 1.9, Z_FUNDO - PRATELEIRA - 0.22), q.nor,
		Vector2(minf(2.4, q.w - 1.2), 0.7), LojaViva.uv_produto(LojaViva.P.LINGUICA))


static func _xerox(q: Q, x: float, z: float) -> void:
	q.caixa(&"metal_pintado", x, PISO + 0.5, z, Vector3(0.7, 1.0, 0.6), Color("d8d8d0"))
	q.caixa(&"metal_pintado", x, PISO + 1.03, z, Vector3(0.66, 0.06, 0.56), Color("3a3c40"))
	q.caixa(&"painel_luz", x + 0.2, PISO + 0.95, z - 0.31, Vector3(0.14, 0.05, 0.01), Color("80e0a0"))
	q.solido(x, PISO + 0.5, z, Vector3(0.7, 1.0, 0.6))


## Relogio de parede nas duas paredes: o que a relojoaria tem para ser vista
## da porta.
static func _relogios(q: Q, meia: float, rng: RandomNumberGenerator) -> void:
	for lado: float in [-1.0, 1.0]:
		for i in 3:
			var z := 1.2 + i * 0.85
			var y := PISO + 2.2 + rng.randf_range(-0.1, 0.12)
			var n := q.lat * -lado
			var r := rng.randf_range(0.14, 0.22)
			var caixa := [Color("6a4028"), Color("c8a040"), Color("2a2a2a")][rng.randi() % 3] as Color
			q.caixa(&"interior_madeira", lado * (meia - 0.03), y, z, Vector3(0.04, r * 2.0, r * 2.0),
				caixa)
			q.cartao(&"loja_produtos", q.p(lado * (meia - 0.06), y, z), n, Vector2(r * 1.7, r * 1.7),
				Rect2(0.25 + 0.01, 0.625 + 0.02, 0.05, 0.1))


static func _espelho_de_balcao(q: Q, x: float, z: float) -> void:
	var y := PISO + ALTURA_BALCAO + 0.1
	q.caixa(&"metal_pintado", x, y + 0.02, z - 0.1, Vector3(0.22, 0.04, 0.16), Color("2a2a2a"))
	q.ob.plano(&"metal_pintado", q.p(x, y + 0.22, z - 0.12), Vector2(0.26, 0.36), q.nor, q.lat,
		ESPELHO, false)


## Pilhas de saco (racao, cimento) no meio do salao, com o rotulo na frente.
static func _pilhas(q: Q, r: Dictionary, _plano: Dictionary, rng: RandomNumberGenerator,
		meia: float) -> void:
	var cel := LojaViva.P.RACAO if r["id"] == &"racao" else LojaViva.P.CIMENTO
	var cor: Color = r["pilhas"]
	var zs: Array[float] = [Z_FUNDO - PRATELEIRA - 1.0]
	for z: float in zs:
		for s: float in [-1.0, 1.0]:
			var x := s * minf(meia - PRATELEIRA - 0.75, 1.2)
			var h := rng.randf_range(0.7, 1.2)
			q.caixa(&"interior", x, PISO + h * 0.5, z, Vector3(1.1, h, 0.7), cor.darkened(0.15))
			q.cartao(&"loja_produtos", q.p(x, PISO + h * 0.5, z - 0.36), q.nor, Vector2(1.08, h),
				LojaViva.uv_produto(cel))
			q.solido(x, PISO + h * 0.5, z, Vector3(1.1, h, 0.7))


## O cartaz do ramo na parede do lado, acima da prateleira.
static func _cartaz(q: Q, r: Dictionary, meia: float, z: float, lado: float = 1.0) -> void:
	var n := q.lat * -lado
	q.cartao(&"loja_cartazes", q.p(lado * (meia - 0.015), PISO + 2.45, z), n, Vector2(0.5, 0.5),
		LojaViva.uv_cartaz(int(r["cartaz"])))
	# O calendario da santa, do outro lado, que toda loja de Minas tem.
	q.cartao(&"loja_cartazes", q.p(-lado * (meia - 0.015), PISO + 2.45, z + 0.6), q.lat * lado,
		Vector2(0.38, 0.38), LojaViva.uv_cartaz(14))


# --- luz, calcada e gente -----------------------------------------------------------

## Duas calhas de lampada tubular no forro (acesas: e o que se ve da rua) e duas
## luzes dinamicas. O orcamento da skill psx-city e quatro no chunk; o poste ja
## gastou uma, e no chunk da loja nao ha bar.
static func _luz(q: Q, props: Array[Dictionary], r: Dictionary, plano: Dictionary) -> void:
	var cor: Color = r["luz"]
	for z: float in [1.8, 4.9]:
		for s: float in ([-1.0, 1.0] if q.w > 5.0 else [0.0]):
			var x := s * q.w * 0.22
			q.caixa(&"metal_pintado", x, FORRO - 0.03, z, Vector3(0.22, 0.05, 1.3), Color("e8e8e4"))
			q.caixa(&"lampada", x, FORRO - 0.06, z, Vector3(0.08, 0.03, 1.2))
		props.append({
			"tipo": "lampada", "pos": q.p(0.0, FORRO - 0.25, z),
			"padrao": Lampada.Padrao.ESTAVEL, "semente": int(plano["semente"]) + int(z * 10.0),
			"cor": cor, "energia": 2.0, "alcance": 7.5, "facho": false,
		})
	# Ventilador de teto nas lojas quentes.
	if r["id"] in [&"padaria", &"lanchonete", &"mercearia", &"bazar", &"armarinho", &"racao"]:
		var zc := 3.3
		q.caixa(&"metal", 0.0, FORRO - 0.2, zc, Vector3(0.04, 0.3, 0.04), METAL_CINZA)
		q.caixa(&"metal_pintado", 0.0, FORRO - 0.36, zc, Vector3(0.2, 0.08, 0.2), Color("e8e4dc"))
		for i in 3:
			var a := float(i) * TAU / 3.0 + 0.4
			var d := Vector3(cos(a), 0.0, sin(a)) * 0.42
			# A pa corre no raio: o eixo comprido dela e a direcao do centro para ela.
			var raio := q.p(d.x, 0.0, zc + d.z) - q.p(0.0, 0.0, zc)
			q.ob.livre(&"interior_madeira", q.p(d.x, FORRO - 0.37, zc + d.z), Vector3(0.12, 0.015, 0.7),
				Basis(Vector3.UP, atan2(raio.x, raio.z)), MADEIRA)


## O que a loja poe na calcada, ao lado da boca, sem fechar a passagem.
static func _calcada(q: Q, r: Dictionary, plano: Dictionary, rng: RandomNumberGenerator) -> void:
	var boca: float = plano["boca"]
	var x := (boca * 0.5 + 0.55) * (1.0 if rng.randf() < 0.5 else -1.0)
	if absf(x) > q.w * 0.5 + ESPESSURA - 0.3:
		return
	var z := -0.45
	match r["id"]:
		&"racao", &"construcao":
			var cel := LojaViva.P.RACAO if r["id"] == &"racao" else LojaViva.P.CIMENTO
			q.caixa(&"interior", x, PISO + 0.35, z, Vector3(0.7, 0.7, 0.5), Color("8a6a4a"))
			q.cartao(&"loja_produtos", q.p(x, PISO + 0.35, z - 0.26), q.nor, Vector2(0.7, 0.7),
				LojaViva.uv_produto(cel))
			q.solido(x, PISO + 0.35, z, Vector3(0.7, 0.7, 0.5))
		&"bazar", &"mercearia":
			q.caixa(&"interior_madeira", x, PISO + 0.3, z, Vector3(0.7, 0.6, 0.45), MADEIRA)
			q.cartao(&"loja_produtos", q.p(x, PISO + 0.62, z), Vector3.UP, Vector2(0.66, 0.42),
				LojaViva.uv_produto(LojaViva.P.BALAIOS if r["id"] == &"bazar" else LojaViva.P.POTES))
			q.solido(x, PISO + 0.3, z, Vector3(0.7, 0.6, 0.45))
		&"borracharia":
			for j in 4:
				q.ob.cilindro(&"fumaca_pneu", q.p(x, PISO + j * 0.2, z), 0.33, 0.2, Color("2a2a2c"), 8)
			q.solido(x, PISO + 0.4, z, Vector3(0.66, 0.8, 0.66))
		&"lanchonete", &"padaria":
			# O cavalete de giz com o preco do dia.
			var b := Basis(q.lat, Vector3.UP, q.nor) * Basis(Vector3.RIGHT, -0.18)
			q.ob.livre(&"interior_madeira", q.p(x, PISO + 0.5, z), Vector3(0.55, 0.95, 0.03), b,
				MADEIRA_ESCURA)
			q.ob.cartao(&"loja_cartazes", Vector2(0.46, 0.46), Transform3D(b,
				q.p(x, PISO + 0.6, z) + q.nor * 0.03), LojaViva.uv_cartaz(int(r["cartaz"])))
			q.solido(x, PISO + 0.5, z, Vector3(0.55, 1.0, 0.4))


## Equipe e clientes. Quem trabalha fica no posto, olhando o salao, e a conversa
## com ele e a do balcao (VendaDaLoja.opcoes). Cliente anda entre as prateleiras,
## ou fica sentado onde a loja tem assento.
static func _pessoas(q: Q, props: Array[Dictionary], r: Dictionary, plano: Dictionary,
		rng: RandomNumberGenerator, gente: Dictionary, censo: Dictionary) -> void:
	var semente := int(plano["semente"])
	var equipe: Array = r["equipe"]
	var profs: Array = r["profissoes"]
	var postos: Array[Dictionary] = gente["equipe"]
	var loja := {"ramo": int(plano["ramo"]), "titulo": r["titulo"]}
	for i in mini(equipe.size(), postos.size()):
		var pos: Vector3 = postos[i]["pos"]
		var foco: Vector3 = postos[i]["foco"]
		props.append({
			"tipo": "convidado", "pos": q.p(pos.x, PISO, pos.z), "semente": semente + 31 * i,
			"papel": Convidado.Papel.LIVRE, "fuma": false, "idade_min": 20, "idade_max": 58,
			"foco": q.p(foco.x, foco.y, foco.z), "pontos": [] as Array[Vector3],
			"contexto": &"loja", "loja": loja, "funcao": equipe[i],
			"profissao": profs[i % profs.size()],
		})
		censo["equipe"] = int(censo["equipe"]) + 1
	var faixa: Vector2i = r["clientes"]
	var n := rng.randi_range(faixa.x, faixa.y)
	var pontos: Array[Vector3] = gente.get("pontos", [] as Array[Vector3])
	var assentos: Array[Vector3] = gente.get("assentos", [] as Array[Vector3])
	var foco_c: Vector3 = gente.get("foco_cliente", Vector3(0.0, 1.3, 3.0))
	# Os pontos vao para o chunk em coordenada LOCAL do chunk, como a `pos`.
	var rota: Array[Vector3] = []
	for p: Vector3 in pontos:
		rota.append(q.p(p.x, PISO, p.z))
	for i in n:
		var prop := {
			"tipo": "convidado", "semente": semente + 509 + 97 * i,
			"papel": Convidado.Papel.LIVRE, "fuma": false, "idade_min": 16, "idade_max": 78,
			"foco": q.p(foco_c.x, foco_c.y, foco_c.z),
		}
		if i < assentos.size():
			var a: Vector3 = assentos[i]
			prop["pos"] = q.p(a.x, PISO, a.z)
			prop["assento"] = a.y
			prop["pontos"] = [] as Array[Vector3]
		elif not rota.is_empty():
			prop["pos"] = rota[(i * 2 + 1) % rota.size()]
			prop["pontos"] = rota
		else:
			continue
		props.append(prop)
		censo["clientes"] = int(censo["clientes"]) + 1
