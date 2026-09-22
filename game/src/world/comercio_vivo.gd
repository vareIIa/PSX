## O predio da rua comercial de Minas: sobrado com loja embaixo, loja de
## marquise, predio baixo de apartamento.
##
## Por que existe
## -------------
## A rua comercial (44% dos chunks edificados) saia de KitModular.fachada: um
## paredao de concreto com vitrine chapada, "janela" de azulejo no terreo,
## letreiro salmao aceso sem letra e janelas de cima sem moldura. Era o lugar mais
## generico da cidade (PLANO_CASAS_AAA.md).
##
## Tres tipos, cada lote de um dono:
##   sobrado  a loja no terreo (porta de enrolar, vitrine, ou o armazem de duas
##            folhas de madeira abertas) e a moradia em cima: janela ecletica,
##            balcao de ferro, platibanda com frontao.
##   loja     um ou dois pavimentos modernos: terreo de azulejo, marquise com a
##            testeira pintada de cada loja, vitrine de aluminio.
##   predio   tres a cinco andares de apartamento: portaria, janela de correr,
##            balcao com planta e roupa, ar-condicionado.
## A porta de enrolar tem tres estados — fechada, meio aberta com a loja
## aparecendo por baixo, e aberta —, e a loja aberta tem prateleira, balcao e
## luz.
##
## Entra por ChunkBuilder._fileira nas quadras do distrito comercial, no lugar
## de KitModular.fachada; `--sem-fachada-viva` volta ao caminho antigo.
class_name ComercioVivo
extends RefCounted

const ANDAR := KitModular.ALTURA_ANDAR
## Topo dos vaos do terreo da loja.
const TOPO_LOJA := 2.8
## Cores de loja: a testeira da marquise, a placa, o portao.
const CORES_LOJA: Array[Color] = [
	Color("c8452e"), Color("2f6a9a"), Color("3f8a4a"), Color("e0b030"), Color("8a3a6a"),
	Color("e8e4dc"), Color("d2692a"), Color("2a4a6a"),
]


## Decide o predio antes da massa. Vazio para quadra que nao e do distrito
## comercial (galpao e baldio seguem no caminho antigo).
static func planejar(rng: RandomNumberGenerator, quadra: Dictionary, largura: float,
		andares: int, tinta: Color) -> Dictionary:
	if int(quadra["distrito"]) != MalhaUrbana.Distrito.COMERCIAL:
		return {}
	var p := {}
	var tipo: StringName
	if andares >= 3:
		tipo = &"predio" if rng.randf() < 0.65 else &"sobrado"
	else:
		tipo = &"sobrado" if rng.randf() < 0.6 else &"loja"
	if tipo == &"sobrado":
		andares = mini(andares, 3)
	p["tipo"] = tipo
	p["andares"] = andares
	p["estilo"] = {&"sobrado": &"ecletico", &"loja": &"moderno", &"predio": &"predio"}[tipo]
	var paleta: Array = FachadaViva.PAREDES[&"ecletico" if tipo == &"sobrado" else &"moderno"]
	var cor: Color = paleta[rng.randi() % paleta.size()]
	if rng.randf() < 0.25:
		cor = cor.lerp(tinta, 0.4)
	p["cor"] = cor
	p["material"] = &"reboco"
	p["mat_corpo"] = &"reboco"
	p["cor_corpo"] = cor.darkened(0.07)
	p["cercadura"] = FachadaViva.CERCADURAS[rng.randi() % FachadaViva.CERCADURAS.size()]
	p["morador"] = [&"zelosa", &"familia", &"idoso", &"jovem", &"fechada"][rng.randi() % 5]
	p["marquise"] = tipo != &"sobrado" and rng.randf() < 0.65
	p["azulejo_terreo"] = tipo != &"sobrado" and rng.randf() < 0.45
	p["cor_azulejo"] = [Color("f2f2ee"), Color("b7c9d9"), Color("c9b69a"),
		Color("9ab8a0")][rng.randi() % 4]
	p["frontao"] = tipo == &"sobrado" and rng.randf() < 0.45
	p["remate"] = &"platibanda" if tipo != &"loja" else &"platibanda_baixa"
	p["semente"] = rng.randi()
	return p


## A frente do predio. Mesmo contrato de KitModular.fachada: devolve se o terreo
## e loja (para o toldo), e `porta_local` e o centro da folha da porta de entrar.
static func fachada(sup: Dictionary, centro: Vector3, largura: float, andares: int,
		direcao: int, plano: Dictionary, prob_acesa: float, porta_local: float,
		info: Dictionary = {}) -> bool:
	var ob := Obra.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(plano["semente"])
	var tipo: StringName = plano["tipo"]
	var estilo: StringName = plano["estilo"]
	var cor: Color = plano["cor"]
	var altura := andares * ANDAR
	var normal := KitModular._normal(direcao)
	var lateral := KitModular._lateral(direcao)
	var giro := atan2(normal.x, normal.z)
	var meia := largura * 0.5
	var margem := 0.35
	var prof_janela := JanelaViva.profundidade(estilo)
	# O comodo de cima vai ate o meio do predio (FundosVivos.fundo vem do outro lado).
	var fundo_max := maxf(1.3, float(plano.get("fundura", ChunkBuilder.PROF_PREDIO)) * 0.5
		- prof_janela - 0.15)

	# --- terreo: porta de entrar, portaria e lojas ----------------------------
	var slots: Array[Dictionary] = []
	var interativa := is_finite(porta_local)
	if interativa:
		slots.append({"tipo": &"porta", "x": porta_local, "w": FachadaViva.PORTA_INTERATIVA.x})
	elif tipo == &"predio" and rng.randf() < 0.75:
		# A portaria do predio: porta de vidro com grade, numa ponta.
		var x_port := (meia - margem - 0.7) * (-1.0 if rng.randf() < 0.5 else 1.0)
		slots.append({"tipo": &"portaria", "x": x_port, "w": 1.3})
	for trecho: Vector2 in FachadaViva._livres(slots.duplicate(), -meia + margem,
			meia - margem, 0.35):
		var comp := trecho.y - trecho.x
		if comp < 2.2:
			continue
		var w_alvo := rng.randf_range(2.6, 3.4)
		var n := maxi(1, int(floor((comp + 0.35) / (w_alvo + 0.35))))
		var w := minf((comp - 0.35 * (n - 1)) / n, 3.6)
		for k in n:
			var x := trecho.x + w * 0.5 + k * (w + 0.35) \
				+ (comp - (n * w + (n - 1) * 0.35)) * 0.5
			var sorte := rng.randf()
			var loja: StringName = &"enrolar"
			if sorte < 0.3:
				loja = &"vitrine"
			elif sorte < 0.45 and tipo == &"sobrado":
				loja = &"armazem"
			# Na ponta baixa da ladeira a calcada desceu mais de 75 cm: ali ninguem
			# abre loja, e a fachada fica cega sobre o embasamento.
			if -FachadaViva.chao_em(plano, x, largura) > 0.75:
				continue
			slots.append({"tipo": loja, "x": x, "w": w})
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["x"] < b["x"])

	var vaos: Array = []
	var estados: Array = []
	for s: Dictionary in slots:
		var x: float = s["x"]
		var w: float = s["w"]
		var y0 := KitModular.ALTURA_MEIO_FIO
		var h := TOPO_LOJA - y0
		var e := {"tipo": s["tipo"], "cor": CORES_LOJA[rng.randi() % CORES_LOJA.size()],
			"semente": rng.randi(), "acesa": rng.randf() < 0.7}
		# O salao da loja da ponta nao passa da divisa do lote: 60 cm alem do vao
		# de cada lado ele saia 25 cm pela parede da esquina.
		e["larg_max"] = FachadaViva._largura_comodo(x, meia)
		match s["tipo"]:
			&"porta":
				h = FachadaViva.PORTA_INTERATIVA.y + 0.05
			&"portaria":
				h = 2.5
			&"enrolar":
				var r := rng.randf()
				e["estado"] = 0 if r < 0.35 else (1 if r < 0.62 else 2)
		# A loja aberta monta o salao; fechada tem a tampa escura atras da porta.
		var aberta: bool = s["tipo"] == &"armazem" or s["tipo"] == &"vitrine" \
			or (s["tipo"] == &"enrolar" and int(e["estado"]) > 0)
		vaos.append({"rect": Rect2(x - w * 0.5, y0, w, h), "prof": 0.3 if aberta else 0.24,
			"tampa": not aberta, "indice": estados.size()})
		estados.append(e)
	# Andares de cima: janelas no passo do estilo, ou sobre as lojas no sobrado.
	var casa := {}
	var med := FachadaViva._medidas(&"ecletico" if tipo == &"sobrado" else &"moderno", rng)
	var xs_cima: Array[float] = []
	var w_cima: float = med["w_janela"]
	if tipo == &"predio":
		w_cima = rng.randf_range(1.3, 1.7)
	var n_cima := maxi(1, int(floor((largura - 2.0 * margem + 0.6) / (w_cima + 1.1))))
	for k in n_cima:
		xs_cima.append(-meia + margem + (largura - 2.0 * margem) * (float(k) + 0.5) / n_cima)
	for andar in range(1, andares):
		var base_y := andar * ANDAR
		for x: float in xs_cima:
			var balcao := (tipo == &"sobrado" and rng.randf() < 0.45) \
				or (tipo == &"predio" and rng.randf() < 0.35)
			var e := JanelaViva.sortear(rng, estilo, plano["morador"], andar,
				rng.randf() < prob_acesa, casa)
			e["larg_max"] = FachadaViva._largura_comodo(x, meia)
			e["fundo_max"] = fundo_max
			if tipo == &"sobrado":
				e["afasta_folha"] = 0.035
			var h: float = med["h_janela"] if tipo == &"sobrado" else 1.3
			var topo: float = med["topo"] if tipo == &"sobrado" else 2.4
			var y0 := base_y + topo - h
			if balcao:
				y0 = base_y + 0.1
				h = topo - 0.1
				e["floreira"] = false
				e["vasos"] = 0
				e["grade"] = 0
			e["tipo"] = &"janela"
			e["balcao"] = balcao
			e["ar"] = tipo != &"sobrado" and not balcao and rng.randf() < 0.3
			vaos.append({"rect": Rect2(x - w_cima * 0.5, y0, w_cima, h), "prof": prof_janela,
				"tampa": JanelaViva.precisa_tampa(e), "arco": 0.3 if tipo == &"sobrado" \
					and bool(plano.get("frontao", false)) else 0.0, "indice": estados.size()})
			estados.append(e)

	# --- parede --------------------------------------------------------------
	var faixas: Array = []
	if bool(plano["azulejo_terreo"]):
		faixas.append({"y0": 0.0, "y1": ANDAR, "cor": plano["cor_azulejo"],
			"material": &"azulejo"})
	var sobe := 1.0 if plano["remate"] == &"platibanda" else 0.5
	var quadros := ParedeVazada.erguer(sup, plano["material"], centro, largura, altura + sobe,
		direcao, cor, vaos, faixas)

	var tem_loja := false
	for q: Dictionary in quadros:
		var e: Dictionary = estados[int(q["indice"])]
		match e["tipo"]:
			&"porta":
				FachadaViva._degrau(ob, q, giro, true)
			&"portaria":
				_portaria(ob, q, rng)
				var alto_p := -FachadaViva.chao_em(plano, (q["rect"] as Rect2).get_center().x,
					largura)
				if alto_p > 0.04:
					FachadaViva.escada(ob, JanelaViva._vao(q), alto_p, (q["rect"] as Rect2).size.x
						+ 0.3, FachadaViva._livre_para_escada(q["rect"], [], meia), giro)
			&"enrolar", &"vitrine", &"armazem":
				tem_loja = true
				_loja(ob, q, e, rng)
				_soleira(ob, q, -FachadaViva.chao_em(plano, (q["rect"] as Rect2).get_center().x,
					largura), giro)
				if not bool(plano["marquise"]):
					_placa(ob, q, e)
			_:
				JanelaViva.preencher_em(ob, q, e, FachadaViva._espaco_dos_lados(q["rect"], quadros))
				if bool(e.get("balcao", false)):
					FachadaViva._balcao(ob, q, rng)
				if bool(e.get("ar", false)):
					var v := JanelaViva._vao(q)
					ob.caixa(&"metal_pintado", v.p(0.0, -0.3, -0.2),
						Vector3(0.75, 0.32, 0.4), Color("e4e6e2"), giro)
					ob.caixa(JanelaViva._p(&"metal"), v.p(0.0, -0.3, -0.405),
						Vector3(0.6, 0.18, 0.01), Color("4a5054"), giro)
				if tipo == &"sobrado":
					FachadaViva._cercadura(ob, q, plano["cercadura"], true)

	# --- ornamento -------------------------------------------------------------
	var cercadura: Color = plano["cercadura"]
	for andar in range(1, andares):
		ob.caixa(&"reboco", centro + Vector3(0.0, andar * ANDAR, 0.0)
			+ normal * 0.06, Vector3(largura, 0.12, 0.12),
			cercadura if tipo == &"sobrado" else cor.darkened(0.12), giro)
	# Cimalha e chapim da platibanda.
	ob.caixa(&"reboco", centro + Vector3(0.0, altura - 0.05, 0.0)
		+ normal * 0.08, Vector3(largura, 0.14, 0.16),
		cercadura if tipo == &"sobrado" else cor.darkened(0.1), giro)
	ob.caixa(&"concreto", centro + Vector3(0.0, altura + sobe, 0.0)
		+ normal * 0.03, Vector3(largura, 0.08, 0.14), Color("e2ddd2"), giro)
	if tipo == &"sobrado":
		for lado: float in [-1.0, 1.0]:
			ob.caixa(&"reboco", centro + lateral * (lado * (meia - 0.15))
				+ Vector3(0.0, (altura + sobe) * 0.5, 0.0) + normal * 0.03,
				Vector3(0.28, altura + sobe, 0.06), cercadura, giro)
		if bool(plano["frontao"]):
			FachadaViva._frontao(ob, centro, largura, altura, lateral, normal, giro, cor,
				cercadura, rng)
	if bool(plano["marquise"]):
		_marquise(ob, centro, largura, lateral, normal, giro, quadros, estados)
	# Medidor e fio na ponta da fachada, como toda loja tem.
	ob.caixa(&"metal_pintado", centro + lateral * (meia - 0.25)
		+ Vector3(0.0, 1.55, 0.0) + normal * 0.08, Vector3(0.3, 0.44, 0.14), Color("b8bcb4"),
		giro)
	info["tipo"] = tipo
	# A lateral da esquina e o fundo (FundosVivos) repetem esquadria, faixas e o
	# nome da primeira loja.
	info["casa"] = casa
	info["faixas"] = faixas
	for e: Dictionary in estados:
		if e["tipo"] in [&"enrolar", &"vitrine", &"armazem"]:
			info["nome_loja"] = e["semente"]
			break
	ob.despejar(sup)
	# Com marquise nao vai toldo por cima.
	return tem_loja and not bool(plano["marquise"])


## O topo pelo plano: a platibanda ja subiu na fachada; atras dela a mureta nos
## outros tres lados, e no predio a caixa d'agua.
static func coroar(sup: Dictionary, plano: Dictionary, topo: Vector3, tamanho: Vector3,
		direcao: int, rng: RandomNumberGenerator) -> void:
	var cor: Color = plano["cor_corpo"]
	var alto := 1.0 if plano["remate"] == &"platibanda" else 0.5
	FachadaViva._platibanda(sup, topo, tamanho, cor, alto)
	if plano["tipo"] == &"predio" or rng.randf() < 0.3:
		var normal := KitModular._normal(direcao)
		var p := topo - normal * minf(tamanho.x, tamanho.z) * 0.2 + Vector3(0.0, 0.25, 0.0)
		KitModular.caixa_cor(sup, &"concreto", p, Vector3(1.6, 0.5, 1.6), Color("b8b2a6"), 0.0)
		FachadaViva._cilindro(sup, &"metal_pintado", p + Vector3(0.0, 0.25, 0.0), 0.75, 1.0,
			Color("3d74b5"))
		FachadaViva._cilindro(sup, &"metal_pintado", p + Vector3(0.0, 1.25, 0.0), 0.66, 0.08,
			Color("2f5f99"))


# --- loja --------------------------------------------------------------------

## O vao da loja, pelo tipo: porta de enrolar (fechada, meio aberta, aberta),
## vitrine de aluminio com porta de vidro, ou armazem de duas folhas.
static func _loja(ob: Obra, q: Dictionary, e: Dictionary, rng: RandomNumberGenerator) -> void:
	var v := JanelaViva._vao(q)
	var d := v.prof - 0.06
	match e["tipo"]:
		&"enrolar":
			var estado: int = e["estado"]
			# As guias da porta, dos dois lados.
			for lado: float in [-1.0, 1.0]:
				ob.caixa(&"metal", v.p(lado * (v.w * 0.5 - 0.04), v.h * 0.5,
					d - 0.02), Vector3(0.06, v.h, 0.08), Color("5a5c5e"), v.giro)
			if estado > 0:
				_salao(ob, v, e, rng)
			# A folha de aco: inteira, pela metade, ou enrolada so na caixa em cima.
			var baixa := 0.0 if estado == 0 else (v.h * 0.48 if estado == 1 else v.h - 0.35)
			var alt := v.h - baixa
			ob.parede(&"metal_ondulado", v.p(0.0, baixa + alt * 0.5, d),
				Vector2(v.w - 0.06, alt), v.giro)
			ob.caixa(&"metal", v.p(0.0, baixa + 0.03, d - 0.02),
				Vector3(v.w - 0.06, 0.06, 0.05), Color("3a3c3e"), v.giro)
		&"vitrine":
			_salao(ob, v, e, rng)
			# Caixilho de aluminio: vidro fixo e a porta de vidro numa ponta.
			var porta_w := 0.95
			var lado := -1.0 if rng.randf() < 0.5 else 1.0
			var x_porta := lado * (v.w * 0.5 - porta_w * 0.5)
			var x_vidro := -lado * porta_w * 0.5
			var w_vidro := v.w - porta_w
			var alu := Color("c9ccce") if rng.randf() < 0.6 else Color("3a3a3a")
			ob.parede(&"vitrine", v.p(x_vidro, 0.4 + (v.h - 0.4) * 0.5, d),
				Vector2(w_vidro, v.h - 0.4), v.giro)
			ob.caixa(&"metal_pintado", v.p(x_vidro, 0.2, d),
				Vector3(w_vidro, 0.4, 0.06), alu.darkened(0.2), v.giro)
			for x: float in [-v.w * 0.5 + 0.03, v.w * 0.5 - 0.03, x_porta - lado * porta_w * 0.5]:
				ob.caixa(&"metal_pintado", v.p(x, v.h * 0.5, d - 0.01),
					Vector3(0.05, v.h, 0.07), alu, v.giro)
			ob.caixa(&"metal_pintado", v.p(0.0, v.h - 0.03, d - 0.01),
				Vector3(v.w, 0.06, 0.07), alu, v.giro)
			# A porta de vidro aberta para dentro, encostada.
			var t := Transform3D(v.base() * Basis(Vector3.UP, lado * 1.3),
				v.p(x_porta + lado * porta_w * 0.5, 1.05, d + 0.02))
			t.origin -= t.basis.x * (lado * porta_w * 0.5)
			ob.cartao(&"vitrine", Vector2(porta_w - 0.06, 2.1), t)
		_:
			_salao(ob, v, e, rng)
			# Armazem: duas folhas de madeira escancaradas contra a parede.
			var cor_folha := JanelaViva.ESQUADRIAS[rng.randi() % JanelaViva.ESQUADRIAS.size()]
			JanelaViva._folhas(ob, v, cor_folha, v.h - 0.02, PI - 0.1, false,
				Vector2(0.5, 0.5), 0.0)


## O salao atras da loja aberta: casca acesa, prateleiras cheias na parede do
## fundo e dos lados, o balcao, e a lampada tubular.
static func _salao(ob: Obra, v: JanelaViva.Vao, e: Dictionary,
		rng: RandomNumberGenerator) -> void:
	var larg := minf(v.w + 1.2, float(e.get("larg_max", v.w + 1.2)))
	var fundo := rng.randf_range(3.0, 4.2)
	var y_teto := v.h + 0.3
	var d0 := v.prof
	var d1 := v.prof + fundo
	var meio_d := (d0 + d1) * 0.5
	var casca: StringName = &"interior_aceso" if bool(e["acesa"]) else &"interior"
	var parede := [Color("f2efe6"), Color("e8e2cc"), Color("dfe8e4"), Color("f0e2c8")][
		rng.randi() % 4] as Color
	JanelaViva._plano(ob, casca, v.p(0.0, y_teto * 0.5, d1), Vector2(larg, y_teto), v.nor,
		v.lat, parede)
	JanelaViva._plano(ob, casca, v.p(-larg * 0.5, y_teto * 0.5, meio_d),
		Vector2(fundo, y_teto), v.lat, -v.nor, parede.darkened(0.05))
	JanelaViva._plano(ob, casca, v.p(larg * 0.5, y_teto * 0.5, meio_d),
		Vector2(fundo, y_teto), -v.lat, v.nor, parede.darkened(0.05))
	JanelaViva._plano(ob, casca, v.p(0.0, 0.0, meio_d), Vector2(larg, fundo), Vector3.UP,
		v.lat, Color("c8c0b0"))
	JanelaViva._plano(ob, casca, v.p(0.0, y_teto, meio_d), Vector2(larg, fundo),
		Vector3.DOWN, v.lat, Color("f4f2ec"))
	# Prateleira do fundo: quatro tabuas, e os produtos em fila de cores.
	var madeira := JanelaViva._p(&"interior_madeira")
	var cheio := JanelaViva._p(&"interior")
	var larg_prat := larg - 0.4
	for k in 4:
		var y := 0.35 + k * 0.5
		ob.caixa(madeira, v.p(0.0, y, d1 - 0.22), Vector3(larg_prat, 0.03, 0.4),
			Color("8a6a48"), v.giro)
		# Produto em placa, de frente: da rua ninguem ve o lado da caixa de
		# sabao, e a caixa inteira custava doze triangulos por produto.
		var n := int(larg_prat / 0.24)
		for m in n:
			if rng.randf() < 0.18:
				continue
			var alto := rng.randf_range(0.14, 0.34)
			var cor := Color.from_hsv(rng.randf(), rng.randf_range(0.3, 0.8), rng.randf_range(0.55, 0.95))
			ob.placa(cheio, v.p(-larg_prat * 0.5 + (m + 0.5) * larg_prat / n,
				y + 0.015 + alto * 0.5, d1 - 0.14), Vector2(0.19, alto), v.giro, cor)
	# Balcao perto da porta, de um lado.
	var lado := -1.0 if rng.randf() < 0.5 else 1.0
	ob.caixa(madeira, v.p(lado * (larg * 0.5 - 0.35), 0.5, meio_d),
		Vector3(0.6, 1.0, fundo * 0.55), Color("6a4a30"), v.giro)
	ob.caixa(cheio, v.p(lado * (larg * 0.5 - 0.35), 1.02, meio_d),
		Vector3(0.66, 0.04, fundo * 0.55 + 0.06), Color("d8d0bc"), v.giro)
	# Lampada tubular no teto, acesa ou nao.
	ob.caixa(JanelaViva._p(&"lampada" if bool(e["acesa"]) else &"metal_pintado"),
		v.p(0.0, y_teto - 0.06, meio_d), Vector3(1.2, 0.05, 0.08), Color.WHITE, v.giro)


## Os degraus de pedra da boca da loja ate a calcada, na largura inteira do vao:
## na ladeira o lote assenta no ponto alto da frente, e a loja da ponta baixa fica
## ate 75 cm acima da calcada (a mais alta que isso nao sai).
static func _soleira(ob: Obra, q: Dictionary, alto: float, giro: float) -> void:
	if alto < 0.04:
		return
	var v := JanelaViva._vao(q)
	var n := clampi(int(ceil(alto / 0.19)), 1, 4)
	var espelho := alto / float(n)
	for k in n:
		var topo := -espelho * float(k)
		ob.caixa(&"concreto", v.p(0.0, (topo - alto) * 0.5, -0.27 * (float(k) + 0.5)),
			Vector3(v.w + 0.1, maxf(topo + alto, 0.04), 0.27), Color("c9c2b2").darkened(0.02 * k),
			giro)


## A placa pintada da loja sobre o vao, quando nao ha marquise: moldura na cor
## da loja e o nome (atlas de tools/gerar_letreiros.py) no campo claro.
static func _placa(ob: Obra, q: Dictionary, e: Dictionary) -> void:
	var v := JanelaViva._vao(q)
	var cor: Color = e["cor"]
	var campo := Vector2(minf(v.w * 0.86, 2.4), 0.48)
	ob.caixa(&"metal_pintado", v.p(0.0, v.h + 0.4, -0.04), Vector3(campo.x + 0.14, 0.62, 0.05),
		cor, v.giro)
	_nome(ob, v.p(0.0, v.h + 0.4, -0.066), campo, v.giro, e)


## O nome da loja: uma celula do atlas de letreiros, no fundo claro da cor dela.
static func _nome(ob: Obra, centro: Vector3, tamanho: Vector2, giro: float,
		e: Dictionary) -> void:
	var k := int(e["semente"]) % 16
	var celula := Rect2(float(k % 2) * 0.5, float(k / 2) * 0.125, 0.5, 0.125)
	var fundo: Color = (e["cor"] as Color).lerp(Color("f6f2e6"), 0.72)
	ob.cartao(&"letreiro_nome", tamanho, Transform3D(Basis(Vector3.UP, giro), centro),
		celula, fundo)


## Porta de vidro da portaria do predio, com grade e o numero em cima.
static func _portaria(ob: Obra, q: Dictionary, rng: RandomNumberGenerator) -> void:
	var v := JanelaViva._vao(q)
	var d := v.prof - 0.06
	ob.parede(&"janela_apagada", v.p(0.0, v.h * 0.5, d + 0.02),
		Vector2(v.w, v.h), v.giro)
	var ferro := Color("2c2e30") if rng.randf() < 0.6 else Color("e6e6e2")
	var n := int(v.w / 0.12)
	for k in range(1, n):
		ob.placa(&"metal", v.p(-v.w * 0.5 + v.w * k / n, v.h * 0.5, d - 0.02),
			Vector2(0.02, v.h), v.giro, ferro)
	ob.caixa(&"metal", v.p(0.0, v.h * 0.35, d - 0.02),
		Vector3(v.w, 0.04, 0.03), ferro, v.giro)
	ob.placa(&"azulejo", v.p(0.0, v.h + 0.22, -0.012), Vector2(0.5, 0.2), v.giro,
		Color("dfe8f0"))


## Marquise de concreto sobre a calcada, com a testeira de cada loja pintada da
## cor dela bem em cima do vao.
static func _marquise(ob: Obra, centro: Vector3, largura: float, lateral: Vector3,
		normal: Vector3, giro: float, quadros: Array[Dictionary], estados: Array) -> void:
	const SAI := 1.25
	var y := 3.0
	ob.caixa(&"concreto", centro + normal * (SAI * 0.5) + Vector3(0.0, y, 0.0),
		Vector3(largura, 0.14, SAI), Color("e4e0d6"), giro)
	for q: Dictionary in quadros:
		var e: Dictionary = estados[int(q["indice"])]
		if not (e["tipo"] in [&"enrolar", &"vitrine", &"armazem"]):
			continue
		var r: Rect2 = q["rect"]
		var x := r.get_center().x
		var cor: Color = e["cor"]
		ob.caixa(&"metal_pintado", centro + lateral * x + normal * (SAI + 0.03)
			+ Vector3(0.0, y + 0.2, 0.0), Vector3(r.size.x, 0.62, 0.06), cor, giro)
		_nome(ob, centro + lateral * x + normal * (SAI + 0.062) + Vector3(0.0, y + 0.2, 0.0),
			Vector2(minf(r.size.x - 0.16, 2.3), 0.46), giro, e)
