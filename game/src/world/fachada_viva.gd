## A casa de rua de Minas, por tipologia, com morador.
##
## Por que existe
## -------------
## A fileira residencial saia de uma receita so (KitFachada): caixa escura, um
## plano de fachada claro na frente, janela de vidro colada 11 cm a frente da
## parede no mesmo passo de 3 m, e quatro "estilos" que so trocavam o rodape.
## Lia como galeria de lojas. Ver o levantamento em PLANO_CASAS_AAA.md.
##
## Rua de cidade do interior mineiro e uma fileira de EPOCAS diferentes, cada
## casa de um dono:
##
##   colonial  porta-e-janela caiada, barrado pintado, cunhal e cercadura de
##             pedra ou branco, vao fundo (parede de 32 cm), folha de madeira
##             azul/verde/sangue-de-boi, telha com cachorrada no beiral.
##   ecletico  platibanda com frontao e compoteira, pilastra, janela alta em arco
##             com sobreverga, cor pastel e cercadura branca, sacada de ferro.
##   moderno   anos 60-70: janela larga de correr, faixa de azulejo ou pastilha,
##             garagem, laje com beiral, medidor na parede.
##   popular   autoconstrucao: reboco cru ou pintura desbotada, andar de cima de
##             tijolo aparente, vergalhao de espera na laje, caixa d'agua azul,
##             vitro basculante e grade.
##
## E o MORADOR que da vida: zelosa (flor em toda janela, janela aberta, trepadeira
## na porta), idoso (folha entreaberta, vaso de espada-de-sao-jorge), familia,
## jovem, fechada (tudo trancado) e abandonada (pichacao, mato no pe da parede,
## cor lavada).
##
## Como entra na cidade
## --------------------
## ChunkBuilder._fileira chama `planejar` antes de erguer a massa (o plano decide
## andares, cor e material do CORPO da casa, que antes era concreto escuro),
## `residencia` no lugar de KitFachada.residencia e `coroar` no lugar de
## KitPredio.coroar. `--sem-fachada-viva` volta ao caminho antigo.
##
## A parede e ParedeVazada (vao de verdade, sem fresta) e cada janela e
## JanelaViva. Miudeza vai no balde "@perto" (ChunkManager.ALCANCE_PERTO).
class_name FachadaViva
extends RefCounted

static var ativo := not OS.get_cmdline_user_args().has("--sem-fachada-viva")

const ANDAR := KitModular.ALTURA_ANDAR
## Soleira da porta: um degrau acima da calcada.
const SOLEIRA := KitModular.ALTURA_MEIO_FIO + 0.15
## Folha da porta interativa (Porta): 0,9 m da dobradica para `lateral`.
const PORTA_INTERATIVA := Vector2(0.98, 2.1)

## Paredes por estilo. Cal, creme e o amarelo colonial; pastel no ecletico;
## claro no moderno; reboco cru e pintura lavada na autoconstrucao.
const PAREDES := {
	&"colonial": [Color("f4f0e6"), Color("f0e4c4"), Color("ecd9a0"), Color("e4ebee"),
		Color("f1dcd2"), Color("ece4d0")],
	&"ecletico": [Color("d8e8d8"), Color("f0d4d0"), Color("f1e3aa"), Color("dfd8ec"),
		Color("d0e2ea"), Color("f2d9b6")],
	&"moderno": [Color("f2f0ea"), Color("dcdad2"), Color("e8ddc8"), Color("d2e2d4"),
		Color("f2e7c9"), Color("d7dde6")],
	&"popular": [Color("cbc6be"), Color("d9c9aa"), Color("e2d09f"), Color("cfc2b2"),
		Color("b9c4cb"), Color("d8b8a8")],
}
const BARRADOS: Array[Color] = [Color("5d7190"), Color("7b3530"), Color("6d6c64"),
	Color("b08a3a"), Color("45704e"), Color("8a7a6a")]
const CERCADURAS: Array[Color] = [Color("f7f5ee"), Color("d2c9b6"), Color("ebe6da")]
const MADEIRA_ESCURA := Color("4a3424")


## Decide a casa antes da massa: estilo, morador, cor, material do corpo,
## andares e remate. `quadra` e o dicionario de MalhaUrbana.quadra_de.
static func planejar(rng: RandomNumberGenerator, quadra: Dictionary, largura: float,
		andares: int, tinta: Color) -> Dictionary:
	var p := {}
	# Estilo: colonial e ecletico pedem casa baixa; tres andares ou mais e
	# predio moderno ou popular.
	var pesos := {&"colonial": 0.3, &"ecletico": 0.16, &"moderno": 0.26, &"popular": 0.28}
	if andares >= 3:
		pesos = {&"colonial": 0.0, &"ecletico": 0.12, &"moderno": 0.5, &"popular": 0.38}
	if largura < 4.6:
		pesos[&"moderno"] = 0.1
	var estilo := _sortear_peso(rng, pesos)
	p["estilo"] = estilo
	if estilo == &"colonial":
		andares = mini(andares, 2)
	p["andares"] = andares
	p["morador"] = _sortear_peso(rng, {&"zelosa": 0.24, &"familia": 0.24, &"idoso": 0.18,
		&"jovem": 0.12, &"fechada": 0.13, &"abandonada": 0.09})
	var paleta: Array = PAREDES[estilo]
	var cor: Color = paleta[rng.randi() % paleta.size()]
	# Um quinto das casas guarda a tinta da quadra: e o parentesco da rua.
	if rng.randf() < 0.2:
		cor = cor.lerp(tinta, 0.35)
	if p["morador"] == &"abandonada":
		cor = cor.lerp(Color("a9a49a"), 0.45)
	p["cor"] = cor
	p["material"] = &"reboco"
	p["barrado"] = BARRADOS[rng.randi() % BARRADOS.size()]
	p["cercadura"] = CERCADURAS[rng.randi() % CERCADURAS.size()]
	# O corpo da casa na cor da fachada, um tom abaixo: a lateral que aparece no
	# degrau da ladeira e na esquina deixa de ser concreto chumbo.
	p["mat_corpo"] = &"reboco"
	p["cor_corpo"] = cor.darkened(0.07)
	p["arco"] = (estilo == &"colonial" and rng.randf() < 0.45) \
		or (estilo == &"ecletico" and rng.randf() < 0.7)
	p["tijolo_em_cima"] = estilo == &"popular" and andares >= 2 and rng.randf() < 0.55
	p["garagem"] = (estilo == &"moderno" or estilo == &"popular") and largura >= 6.0 \
		and rng.randf() < 0.5
	match estilo:
		&"colonial":
			p["remate"] = &"telhado"
		&"ecletico":
			p["remate"] = &"platibanda"
		&"moderno":
			p["remate"] = &"telhado" if rng.randf() < 0.5 else &"beiral"
		_:
			p["remate"] = &"laje"
	p["semente"] = rng.randi()
	return p


static func _sortear_peso(rng: RandomNumberGenerator, pesos: Dictionary) -> StringName:
	var total := 0.0
	for k: StringName in pesos:
		total += float(pesos[k])
	var r := rng.randf() * total
	for k: StringName in pesos:
		r -= float(pesos[k])
		if r <= 0.0:
			return k
	return pesos.keys()[0]


## A frente da casa. `centro` e o pe do plano da fachada no meio da largura.
## `porta_local` e o centro da folha da porta interativa (ja na coordenada de
## `lateral`), NAN sem ela. Mesmo contrato de KitFachada.residencia para
## `garagens` e `info` ("porta" = onde fica a porta desta casa).
static func residencia(sup: Dictionary, centro: Vector3, largura: float, andares: int,
		direcao: int, plano: Dictionary, prob_acesa: float, porta_local: float,
		vao_real: bool, garagens: Array, info: Dictionary) -> void:
	var ob := Obra.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(plano["semente"])
	var estilo: StringName = plano["estilo"]
	var morador: StringName = plano["morador"]
	var cor: Color = plano["cor"]
	var altura := andares * ANDAR
	var normal := KitModular._normal(direcao)
	var lateral := KitModular._lateral(direcao)
	var giro := atan2(normal.x, normal.z)
	var prof := JanelaViva.profundidade(estilo)
	# O comodo da janela aberta vai ate o meio da casa, e nao alem: o de tras
	# (FundosVivos.fundo) vem do outro lado, e na casa recuada, mais rasa, os
	# dois se cruzavam.
	var fundo_max := maxf(1.3, float(plano.get("fundura", ChunkBuilder.PROF_PREDIO)) * 0.5 - prof - 0.15)
	var meia := largura * 0.5
	var ornada := estilo == &"colonial" or estilo == &"ecletico"
	var margem := 0.46 if ornada else 0.28
	var arco: bool = plano["arco"]

	# --- terreo: porta, garagem e janelas ------------------------------------
	var med := _medidas(estilo, rng)
	var slots: Array[Dictionary] = []
	var interativa := is_finite(porta_local)
	var x_porta: float
	var w_porta: float
	if interativa:
		x_porta = porta_local
		w_porta = PORTA_INTERATIVA.x
	else:
		w_porta = med["w_porta"]
		var livre := meia - margem - w_porta * 0.5
		x_porta = rng.randf_range(-livre, livre) if livre > 0.0 else 0.0
		# Colonial de porta-e-janela: a porta num dos tercos, nunca colada.
		if estilo == &"colonial" and largura > 5.0:
			x_porta = clampf(x_porta, -livre * 0.8, livre * 0.8)
	slots.append({"tipo": &"porta", "x": x_porta, "w": w_porta})
	if bool(plano["garagem"]):
		var w_gar := 2.5
		var lado := 1.0 if x_porta < 0.0 else -1.0
		var x_gar := lado * (meia - margem - w_gar * 0.5)
		# Na ladeira o portao so sai onde a calcada encontra o piso da casa: a guia
		# rebaixada e a rampa ficam na calcada, e 43% dos portoes ficavam mais de
		# 30 cm acima ou abaixo dela (levantamento da ladeira).
		if absf(chao_em(plano, x_gar, largura)) <= 0.2 \
				and absf(x_gar - x_porta) > (w_gar + w_porta) * 0.5 + 0.4:
			slots.append({"tipo": &"garagem", "x": x_gar, "w": w_gar})
	var ocupados := slots.duplicate()
	for trecho: Vector2 in _livres(ocupados, -meia + margem, meia - margem, 0.4):
		var comp := trecho.y - trecho.x
		var ww: float = med["w_janela"]
		if comp < ww:
			continue
		var n := maxi(1, int(floor(comp / float(med["baia"]))))
		for k in n:
			slots.append({"tipo": &"janela",
				"x": trecho.x + (float(k) + 0.5) * comp / n, "w": ww})
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["x"] < b["x"])

	# --- vaos de todos os andares ---------------------------------------------
	var casa := {}
	var vaos: Array = []
	var estados: Array = []
	var topo_vao: float = med["topo"]
	for s: Dictionary in slots:
		var x: float = s["x"]
		var w: float = s["w"]
		match s["tipo"]:
			&"porta":
				var y0 := KitModular.ALTURA_MEIO_FIO if interativa else SOLEIRA
				var h := PORTA_INTERATIVA.y + 0.05 if interativa else topo_vao - SOLEIRA
				vaos.append({"rect": Rect2(x - w * 0.5, y0, w, h), "prof": maxf(prof, 0.16),
					"tampa": not vao_real, "tipo": &"porta", "interativa": interativa,
					"arco": 0.0 if interativa or not arco else 0.16})
				estados.append({})
			&"garagem":
				vaos.append({"rect": Rect2(x - w * 0.5, KitModular.ALTURA_MEIO_FIO, w, 2.2),
					"prof": 0.22, "tipo": &"garagem"})
				estados.append({})
			_:
				var e := JanelaViva.sortear(rng, estilo, morador, 0, rng.randf() < prob_acesa, casa)
				if ornada:
					e["afasta_folha"] = 0.035
				e["larg_max"] = _largura_comodo(x, meia)
				e["fundo_max"] = fundo_max
				vaos.append({"rect": Rect2(x - w * 0.5, topo_vao - float(med["h_janela"]), w,
					med["h_janela"]), "prof": prof, "tampa": JanelaViva.precisa_tampa(e),
					"tipo": &"janela", "arco": 0.16 if arco else 0.0})
				estados.append(e)
	# Andares de cima: uma janela sobre cada vao do terreo, alinhada. No
	# ecletico e no colonial de sobrado, parte vira porta-janela com balcao.
	for andar in range(1, andares):
		var base_y := andar * ANDAR
		for s: Dictionary in slots:
			var x: float = s["x"]
			var w := minf(float(s["w"]), float(med["w_janela"]) * (1.3 if s["tipo"] == &"garagem" else 1.0))
			var balcao := ornada and rng.randf() < 0.4
			var e := JanelaViva.sortear(rng, estilo, morador, andar, rng.randf() < prob_acesa, casa)
			if ornada:
				e["afasta_folha"] = 0.035
			e["larg_max"] = _largura_comodo(x, meia)
			e["fundo_max"] = fundo_max
			var h: float = med["h_janela"]
			var y0 := base_y + (float(med["topo"]) - h)
			if balcao:
				y0 = base_y + 0.1
				h = float(med["topo"]) - 0.1
				e["floreira"] = false
				e["vasos"] = 0
				e["grade"] = 0
			vaos.append({"rect": Rect2(x - w * 0.5, y0, w, h), "prof": prof,
				"tampa": JanelaViva.precisa_tampa(e), "tipo": &"janela", "balcao": balcao,
				"arco": 0.16 if arco else 0.0})
			estados.append(e)

	# --- a parede, com as faixas do estilo -------------------------------------
	var faixas: Array = []
	if estilo == &"colonial" or (estilo == &"ecletico" and rng.randf() < 0.6):
		faixas.append({"y0": 0.0, "y1": 0.95, "cor": plano["barrado"]})
	elif estilo == &"moderno" and rng.randf() < 0.55:
		faixas.append({"y0": 0.0, "y1": 1.05, "cor": [Color("f2f2ee"), Color("b7c9d9"),
			Color("c9b69a")][rng.randi() % 3], "material": &"azulejo"})
	elif estilo == &"popular" or morador == &"abandonada":
		# Umidade subindo do pe da parede: a faixa de meio metro mais escura.
		faixas.append({"y0": 0.0, "y1": 0.45, "cor": cor.darkened(0.16)})
	if bool(plano["tijolo_em_cima"]):
		faixas.append({"y0": ANDAR, "y1": altura, "cor": Color.WHITE, "material": &"tijolo"})
	# A lateral da esquina e o fundo (FundosVivos) repetem a esquadria e as faixas.
	info["casa"] = casa
	info["faixas"] = faixas
	for k in vaos.size():
		vaos[k]["indice"] = k
	# Na ecletica a fachada sobe mais um metro: a platibanda e a propria parede
	# da frente, e o frontao assenta nela (a mureta do KitPredio fica atras).
	var altura_parede := altura + (1.0 if estilo == &"ecletico" else 0.0)
	var quadros := ParedeVazada.erguer(sup, plano["material"], centro, largura, altura_parede,
		direcao, cor, vaos, faixas)

	# --- o conteudo de cada vao ------------------------------------------------
	var cercadura: Color = plano["cercadura"]
	for q: Dictionary in quadros:
		var k: int = q["indice"]
		var r: Rect2 = q["rect"]
		match q["tipo"]:
			&"porta":
				if not bool(q.get("interativa", false)):
					_porta(ob, q, estilo, plano, rng)
					info["porta"] = r.get_center().x
				else:
					info["porta"] = r.get_center().x
				_degrau(ob, q, giro, interativa, chao_em(plano, r.get_center().x, largura),
					_livre_para_escada(r, slots, meia))
			&"garagem":
				_garagem(ob, q, estilo, rng)
				garagens.append(r.get_center().x)
			_:
				JanelaViva.preencher_em(ob, q, estados[k], _espaco_dos_lados(r, quadros))
				if bool(q.get("balcao", false)):
					_balcao(ob, q, rng)
		if ornada:
			_cercadura(ob, q, cercadura, estilo == &"ecletico")

	# --- ornamento da fachada ---------------------------------------------------
	var frente := centro
	if ornada:
		for lado: float in [-1.0, 1.0]:
			ob.caixa(&"reboco", frente + lateral * (lado * (meia - 0.16))
				+ Vector3(0.0, altura * 0.5, 0.0) + normal * 0.03,
				Vector3(0.3, altura, 0.06), cercadura, giro)
	for andar in range(1, andares):
		# Friso entre os andares: a pingadeira que quebra o paredao.
		ob.caixa(&"reboco", frente + Vector3(0.0, andar * ANDAR, 0.0)
			+ normal * 0.05, Vector3(largura, 0.1, 0.1),
			cercadura if ornada else cor.darkened(0.12), giro)
	if ornada or estilo == &"moderno":
		# Cimalha: o remate da fachada sob o telhado ou a platibanda.
		ob.caixa(&"reboco", frente + Vector3(0.0, altura - 0.12, 0.0)
			+ normal * 0.06, Vector3(largura, 0.16, 0.12),
			cercadura if ornada else cor.darkened(0.1), giro)
		ob.caixa(&"reboco", frente + Vector3(0.0, altura - 0.02, 0.0)
			+ normal * 0.1, Vector3(largura, 0.08, 0.2),
			cercadura.darkened(0.05) if ornada else cor.darkened(0.15), giro)
	if plano["remate"] == &"telhado" and estilo == &"colonial":
		_cachorrada(ob, frente, largura, altura, lateral, normal, giro)
	if estilo == &"ecletico":
		# Chapim da platibanda e o frontao em cima dela.
		ob.caixa(&"reboco", frente + Vector3(0.0, altura + 1.0, 0.0)
			+ normal * 0.04, Vector3(largura, 0.1, 0.16), cercadura, giro)
		_frontao(ob, frente, largura, altura, lateral, normal, giro, cor, cercadura, rng)

	# --- vida na porta e na parede -----------------------------------------------
	var x_da_porta := float(info.get("porta", x_porta))
	_vida(ob, frente, largura, altura, lateral, normal, giro, x_da_porta, estilo,
		morador, cor, rng, slots)
	ob.despejar(sup)


## Medidas do vao pelo estilo: largura e altura da janela, topo alinhado de
## porta e janela no terreo, e o passo entre janelas.
static func _medidas(estilo: StringName, rng: RandomNumberGenerator) -> Dictionary:
	match estilo:
		&"colonial":
			return {"w_janela": 1.0, "h_janela": 1.75, "topo": 2.85, "w_porta": 1.2,
				"baia": rng.randf_range(1.9, 2.3)}
		&"ecletico":
			return {"w_janela": 1.0, "h_janela": 1.9, "topo": 2.9, "w_porta": 1.25,
				"baia": rng.randf_range(2.0, 2.4)}
		&"moderno":
			return {"w_janela": rng.randf_range(1.5, 2.0), "h_janela": 1.25, "topo": 2.4,
				"w_porta": 0.95, "baia": rng.randf_range(2.6, 3.2)}
		_:
			return {"w_janela": rng.randf_range(1.0, 1.3), "h_janela": 1.1, "topo": 2.35,
				"w_porta": 0.9, "baia": rng.randf_range(2.3, 3.0)}


## Trechos livres de [de, ate] fora dos vaos ja ocupados, com `folga` de parede.
static func _livres(ocupados: Array, de: float, ate: float, folga: float) -> Array[Vector2]:
	var fechados: Array[Vector2] = []
	for s: Dictionary in ocupados:
		fechados.append(Vector2(float(s["x"]) - float(s["w"]) * 0.5 - folga,
			float(s["x"]) + float(s["w"]) * 0.5 + folga))
	fechados.sort()
	var saida: Array[Vector2] = []
	var cursor := de
	for f: Vector2 in fechados:
		if f.x > cursor:
			saida.append(Vector2(cursor, minf(f.x, ate)))
		cursor = maxf(cursor, f.y)
	if ate > cursor:
		saida.append(Vector2(cursor, ate))
	return saida


## O comodo atras da janela aberta nao passa da divisa do lote.
static func _largura_comodo(x: float, meia: float) -> float:
	return maxf(1.2, 2.0 * (meia - absf(x)) - 0.2)


## Quanto de parede sobra de cada lado do vao ate o vizinho no mesmo andar, para
## a folha aberta nao deitar em cima da outra janela.
static func _espaco_dos_lados(r: Rect2, quadros: Array[Dictionary]) -> Vector2:
	var esquerda := 9.0
	var direita := 9.0
	for q: Dictionary in quadros:
		var o: Rect2 = q["rect"]
		if o == r or o.end.y < r.position.y or o.position.y > r.end.y:
			continue
		if o.end.x <= r.position.x:
			esquerda = minf(esquerda, r.position.x - o.end.x)
		elif o.position.x >= r.end.x:
			direita = minf(direita, o.position.x - r.end.x)
	# A folha da vizinha tambem abre: cada uma fica com metade do espaco.
	return Vector2(esquerda * 0.5, direita * 0.5)


# --- portas ----------------------------------------------------------------------

## Porta desenhada (a casa que nao e a porta de entrar do chunk): duas folhas
## almofadadas com bandeira na colonial e na ecletica, tabua na popular,
## madeira lisa com visor na moderna. Fechada, no fundo do vao.
static func _porta(ob: Obra, q: Dictionary, estilo: StringName, plano: Dictionary,
		rng: RandomNumberGenerator) -> void:
	var v := JanelaViva._vao(q)
	var d := v.prof - 0.06
	var ornada := estilo == &"colonial" or estilo == &"ecletico"
	var cor_folha: Color = JanelaViva.ESQUADRIAS[rng.randi() % JanelaViva.ESQUADRIAS.size()] \
		if ornada else [Color("6b4a30"), Color("8a6a48"), Color("5a4a3a"), Color("c9ccce"),
			Color("3f4f5a")][rng.randi() % 5] as Color
	var h_folha := v.h - v.arco
	if ornada:
		# Bandeira de vidro em cima: a porta alta da casa antiga.
		var h_band := 0.45
		h_folha -= h_band
		ob.parede(&"janela_apagada",
			v.p(0.0, h_folha + h_band * 0.5 + v.arco * 0.5, d + 0.01),
			Vector2(v.w + 0.04, h_band + v.arco + 0.04), v.giro)
		ob.caixa(&"tabua", v.p(0.0, h_folha + 0.03, d - 0.01),
			Vector3(v.w, 0.07, 0.07), cor_folha, v.giro)
		for lado: float in [-1.0, 1.0]:
			var u := lado * v.w * 0.25
			ob.caixa(&"tabua", v.p(u, h_folha * 0.5, d),
				Vector3(v.w * 0.5 - 0.01, h_folha, 0.05), cor_folha, v.giro)
			# Almofadas: tres paineis em relevo em cada folha.
			for k in 3:
				var hp := h_folha * (0.22 if k < 2 else 0.3)
				var yp: float = h_folha * ([0.18, 0.46, 0.8][k] as float)
				ob.caixa(JanelaViva._p(&"tabua"), v.p(u, yp, d - 0.03),
					Vector3(v.w * 0.5 - 0.16, hp, 0.02), cor_folha.darkened(0.12), v.giro)
	else:
		ob.caixa(&"tabua", v.p(0.0, h_folha * 0.5, d),
			Vector3(v.w - 0.02, h_folha, 0.05), cor_folha, v.giro)
		if estilo == &"moderno":
			# Visor de vidro canelado no alto da folha.
			ob.parede(&"janela_apagada", v.p(0.0, h_folha * 0.72, d - 0.03),
				Vector2(v.w * 0.3, h_folha * 0.3), v.giro)
		else:
			# Tabua: frisos verticais.
			for k in 4:
				ob.placa(JanelaViva._p(&"tabua"),
					v.p(-v.w * 0.3 + v.w * 0.2 * k, h_folha * 0.5, d - 0.028),
					Vector2(0.02, h_folha - 0.1), v.giro, cor_folha.darkened(0.25))
	# Macaneta.
	ob.caixa(JanelaViva._p(&"metal_pintado"), v.p(v.w * 0.32, 1.0 - SOLEIRA + KitModular.ALTURA_MEIO_FIO, d - 0.05),
		Vector3(0.04, 0.12, 0.05), Color("c8a860"), v.giro)


## O chao da calcada no ponto `x` da fachada, relativo a base do lote. O
## ChunkBuilder passa em plano["perfil"] nove amostras de ponta a ponta; no chunk
## plano nao ha perfil e o chao e zero.
static func chao_em(plano: Dictionary, x: float, largura: float) -> float:
	var perfil: PackedFloat32Array = plano.get("perfil", PackedFloat32Array())
	if perfil.size() < 2 or largura <= 0.0:
		return 0.0
	var t := clampf((x / largura + 0.5) * float(perfil.size() - 1), 0.0,
		float(perfil.size() - 1))
	var i := mini(int(t), perfil.size() - 2)
	return lerpf(perfil[i], perfil[i + 1], t - float(i))


## Quanto de fachada livre ha de cada lado do vao da porta, no pe da parede, ate a
## ponta do lote ou a garagem: e por ali que a escada de encosto corre.
static func _livre_para_escada(r: Rect2, slots: Array, meia: float) -> Vector2:
	var esquerda := r.position.x + meia - 0.1
	var direita := meia - r.end.x - 0.1
	for s: Dictionary in slots:
		if s["tipo"] != &"garagem":
			continue
		var x: float = s["x"]
		var w: float = s["w"]
		if x < r.position.x:
			esquerda = minf(esquerda, r.position.x - (x + w * 0.5) - 0.1)
		else:
			direita = minf(direita, (x - w * 0.5) - r.end.x - 0.1)
	return Vector2(maxf(esquerda, 0.0), maxf(direita, 0.0))


## Degrau de pedra na frente da porta: a soleira sobe da calcada.
##
## Na ladeira o lote assenta no ponto ALTO da frente (ChunkBuilder._altura_do_lote)
## e a calcada, na porta, fica `chao` abaixo da base. Um degrau ate 22 cm; ate tres
## de frente para a rua; mais que isso a escada corre encostada na fachada, para o
## lado com parede livre, com o patamar na porta. E a escada de encosto de toda
## casa de morro, e ela nao entra na faixa da calcada por onde o pedestre anda (a
## 84 cm da parede, Rotas).
static func _degrau(ob: Obra, q: Dictionary, giro: float, interativa: bool,
		chao: float = 0.0, livre: Vector2 = Vector2(9.0, 9.0)) -> void:
	var v := JanelaViva._vao(q)
	var alto := v.base_y - (chao + KitModular.ALTURA_MEIO_FIO)
	var pedra := Color("cfc8b8")
	if interativa or alto < 0.03:
		# A porta de entrar nasce na calcada: o degrau e so a soleira de pedra.
		ob.caixa(&"concreto", v.p(0.0, 0.015, -0.12),
			Vector3(v.w + 0.24, 0.03, 0.26), pedra, giro)
		return
	if alto <= 0.22:
		ob.caixa(&"concreto", v.p(0.0, -alto * 0.5, -0.2),
			Vector3(v.w + 0.3, alto, 0.4), pedra, giro)
		return
	escada(ob, v, alto, v.w + 0.3, livre, giro)


## Escada de pedra do pe do vao `v` ate a calcada, `alto` abaixo. De frente ate
## tres degraus; mais que isso, patamar na porta e o lance encostado na parede.
## Publica: a portaria da ComercioVivo e a porta social da IndustriaViva usam.
static func escada(ob: Obra, v: JanelaViva.Vao, alto: float, larg: float,
		livre: Vector2, giro: float) -> void:
	var pedra := Color("cfc8b8")
	var n := clampi(int(ceil(alto / 0.18)), 2, 16)
	var espelho := alto / float(n)
	const PISADA := 0.26
	const FUNDO := 0.75
	var lado := 1.0 if livre.y >= livre.x else -1.0
	var cabe := maxf(livre.x, livre.y) >= float(n - 1) * PISADA + 0.1
	if n <= 3 or not cabe:
		for k in n:
			# Cada degrau desce ate a calcada: de lado a escada e cheia.
			var topo := -espelho * float(k)
			ob.caixa(&"concreto", v.p(0.0, (topo - alto) * 0.5, -PISADA * (float(k) + 0.5)),
				Vector3(larg, maxf(topo + alto, 0.04), PISADA), pedra.darkened(0.02 * k), giro)
		return
	# Patamar na frente da porta, com a altura da soleira.
	ob.caixa(&"concreto", v.p(0.0, -alto * 0.5, -FUNDO * 0.5), Vector3(larg, alto, FUNDO),
		pedra, giro)
	for k in range(1, n):
		var topo := -espelho * float(k)
		var u := lado * (larg * 0.5 + PISADA * (float(k) - 0.5))
		ob.caixa(&"concreto", v.p(u, (topo - alto) * 0.5, -FUNDO * 0.5),
			Vector3(PISADA, maxf(topo + alto, 0.04), FUNDO), pedra.darkened(0.015 * k), giro)
	if alto < 0.6:
		return
	# Guarda-corpo de cano na borda de fora do lance, a 90 cm dos degraus.
	var ferro := Color("3a3c3e")
	var comp := float(n - 1) * PISADA
	var inclina := atan2(alto - espelho, comp)
	var meio := v.p(lado * (larg * 0.5 + comp * 0.5), (-espelho - alto + espelho) * 0.5 + 0.9,
		-FUNDO + 0.04)
	var base := v.base() * Basis(Vector3.BACK, -lado * inclina)
	ob.livre(JanelaViva._p(&"metal"), meio, Vector3(comp / cos(inclina) + 0.05, 0.04, 0.04), base,
		ferro)
	for k: int in [1, n - 1]:
		ob.caixa(JanelaViva._p(&"metal"), v.p(lado * (larg * 0.5 + PISADA * (float(k) - 0.5)),
			-espelho * float(k) + 0.45, -FUNDO + 0.04), Vector3(0.04, 0.9, 0.04), ferro, giro)


## Portao de garagem: chapa pintada com frisos, no fundo do vao.
static func _garagem(ob: Obra, q: Dictionary, estilo: StringName,
		rng: RandomNumberGenerator) -> void:
	var v := JanelaViva._vao(q)
	var d := v.prof - 0.05
	var cor := [Color("e8e6e0"), Color("5a6a4a"), Color("7a4a3a"), Color("3f5a78"),
		Color("b8b0a0")][rng.randi() % 5] as Color
	if estilo == &"popular" and rng.randf() < 0.5:
		# Portao de enrolar, o de sempre.
		ob.parede(&"metal_ondulado", v.p(0.0, v.h * 0.5, d),
			Vector2(v.w + 0.04, v.h + 0.04), v.giro)
		return
	ob.caixa(&"metal_pintado", v.p(0.0, v.h * 0.5, d),
		Vector3(v.w - 0.02, v.h - 0.02, 0.04), cor, v.giro)
	var frisos := int(v.h / 0.22)
	for k in range(1, frisos):
		ob.placa(&"metal_pintado", v.p(0.0, v.h * k / frisos, d - 0.025),
			Vector2(v.w - 0.1, 0.03), v.giro, cor.darkened(0.2))


# --- ornamento -------------------------------------------------------------------

## Cercadura: a moldura saliente em volta do vao, na cor de pedra ou branca. Na
## ecletica, com sobreverga (o chapeu mais largo em cima).
static func _cercadura(ob: Obra, q: Dictionary, cor: Color, sobreverga: bool) -> void:
	var v := JanelaViva._vao(q)
	var t := 0.13
	var sai := 0.03
	for lado: float in [-1.0, 1.0]:
		ob.caixa(&"reboco", v.p(lado * (v.w * 0.5 + t * 0.5), v.h * 0.5 + t * 0.5,
			-sai * 0.5), Vector3(t, v.h + t, sai), cor, v.giro)
	ob.caixa(&"reboco", v.p(0.0, v.h + t * 0.5, -sai * 0.5),
		Vector3(v.w + t * 2.0, t, sai), cor, v.giro)
	if sobreverga:
		ob.caixa(&"reboco", v.p(0.0, v.h + t + 0.06, -0.06),
			Vector3(v.w + t * 2.0 + 0.2, 0.08, 0.12), cor, v.giro)
		ob.caixa(&"reboco", v.p(0.0, v.h + t + 0.14, -0.035),
			Vector3(v.w + t * 2.0 + 0.1, 0.08, 0.07), cor.darkened(0.04), v.giro)


## Cachorrada: as pontas de caibro de madeira aparecendo sob o beiral.
static func _cachorrada(ob: Obra, frente: Vector3, largura: float, altura: float,
		lateral: Vector3, normal: Vector3, giro: float) -> void:
	var n := int(largura / 0.42)
	for k in n:
		var u := -largura * 0.5 + (float(k) + 0.5) * largura / n
		ob.caixa(JanelaViva._p(&"tabua"),
			frente + lateral * u + Vector3(0.0, altura + 0.02, 0.0) + normal * 0.26,
			Vector3(0.07, 0.1, 0.5), MADEIRA_ESCURA, giro)


## Frontao da platibanda ecletica: o triangulo no meio, com uma compoteira em
## cada ponta.
static func _frontao(ob: Obra, frente: Vector3, largura: float, altura: float,
		lateral: Vector3, normal: Vector3, giro: float, cor: Color, cercadura: Color,
		rng: RandomNumberGenerator) -> void:
	var larg := minf(largura * 0.5, 3.2)
	var alto := rng.randf_range(0.55, 0.8)
	var base_y := altura + 1.0
	var origem := frente + normal * 0.02 + Vector3(0.0, base_y, 0.0)
	ob.triangulo(&"reboco", origem - lateral * (larg * 0.5), origem + lateral * (larg * 0.5),
		origem + Vector3(0.0, alto, 0.0), normal, cor)
	# A cornija do frontao, as duas aguas em caixa fina.
	var inclina := atan2(alto, larg * 0.5)
	var comp := sqrt(alto * alto + larg * larg * 0.25) + 0.12
	for lado: float in [-1.0, 1.0]:
		var meio := origem + lateral * (lado * larg * 0.25) + Vector3(0.0, alto * 0.5, 0.0) \
			+ normal * 0.05
		var base := Basis(lateral, Vector3.UP, normal) * Basis(Vector3.BACK, -lado * inclina)
		ob.livre(&"reboco", meio, Vector3(comp, 0.1, 0.12), base, cercadura)
	# A platibanda corre a fachada inteira: uma faixa de reboco de 1 m sobre a
	# cimalha, com as compoteiras em cima das pilastras.
	for lado: float in [-1.0, 1.0]:
		var p := frente + lateral * (lado * (largura * 0.5 - 0.16)) + normal * 0.05 \
			+ Vector3(0.0, base_y, 0.0)
		ob.caixa(&"reboco", p + Vector3(0.0, 0.08, 0.0),
			Vector3(0.26, 0.16, 0.26), cercadura, giro)
		ob.caixa(&"reboco", p + Vector3(0.0, 0.3, 0.0),
			Vector3(0.16, 0.28, 0.16), cercadura.darkened(0.06), giro)


## Balcao de ferro na porta-janela do andar de cima: laje fina saindo 45 cm e
## guarda-corpo de barras.
static func _balcao(ob: Obra, q: Dictionary, rng: RandomNumberGenerator) -> void:
	var v := JanelaViva._vao(q)
	var larg := v.w + 0.4
	var sai := 0.45
	ob.caixa(&"concreto", v.p(0.0, -0.05, -sai * 0.5),
		Vector3(larg, 0.1, sai), Color("d6cfbe"), v.giro)
	var ferro := Color("2a2c2e")
	var alto := 0.95
	# Corrimao e as tres faces do guarda-corpo.
	ob.caixa(&"metal", v.p(0.0, alto, -sai + 0.02), Vector3(larg, 0.035, 0.035),
		ferro, v.giro)
	var n := int(larg / 0.11)
	for k in n:
		var u := -larg * 0.5 + (float(k) + 0.5) * larg / n
		ob.placa(&"metal", v.p(u, alto * 0.5, -sai + 0.02), Vector2(0.018, alto),
			v.giro, ferro)
	for lado: float in [-1.0, 1.0]:
		ob.caixa(&"metal", v.p(lado * larg * 0.5, alto, -sai * 0.5),
			Vector3(0.035, 0.035, sai), ferro, v.giro)
		for k in 3:
			var d := -sai * (float(k) + 0.5) / 3.0
			ob.caixa(&"metal", v.p(lado * larg * 0.5, alto * 0.5, d),
				Vector3(0.018, alto, 0.018), ferro, v.giro)
	# Voluta no meio: o arabesco que todo balcao mineiro tem.
	var t := Transform3D(Basis(v.lat, Vector3.UP, v.nor) * Basis(Vector3.BACK, PI * 0.25),
		v.p(0.0, alto * 0.55, -sai + 0.012))
	for arco in 2:
		var tt := t.rotated_local(Vector3.BACK, PI * 0.5 * arco)
		ob.cartao(&"metal", Vector2(0.3, 0.025), tt, Rect2(0, 0, 1, 1), ferro)
	# Vaso no canto do balcao, as vezes.
	if rng.randf() < 0.5:
		ob.caixa(JanelaViva._p(&"reboco"), v.p(larg * 0.38, 0.1, -sai * 0.5),
			Vector3(0.2, 0.2, 0.2), JanelaViva.TERRACOTA, v.giro)
		var t2 := Transform3D(Basis(Vector3.UP, rng.randf() * PI), v.p(larg * 0.38, 0.45, -sai * 0.5))
		JanelaViva.folhagem(ob, Vector2(0.5, 0.5), t2, Color(0.8, 1.0, 0.75))


# --- vida ------------------------------------------------------------------------

## O que diz que alguem mora ali: numero, luminaria, medidor, caixa de correio,
## vaso na porta, trepadeira; pichacao e mato na abandonada.
static func _vida(ob: Obra, frente: Vector3, largura: float, altura: float,
		lateral: Vector3, normal: Vector3, giro: float, x_porta: float, estilo: StringName,
		morador: StringName, cor: Color, rng: RandomNumberGenerator, slots: Array[Dictionary]) -> void:
	var meia := largura * 0.5
	# De que lado da porta sobra parede para as miudezas.
	var lado := 1.0 if x_porta < 0.0 else -1.0
	var junto := x_porta + lado * 0.85
	var pe := frente + Vector3(0.0, KitModular.ALTURA_MEIO_FIO, 0.0)
	var livre_junto := _parede_livre(slots, junto, 0.3)
	if livre_junto:
		# Numero da casa, de azulejo.
		ob.placa(&"azulejo", frente + lateral * junto + Vector3(0.0, 1.95, 0.0)
			+ normal * 0.012, Vector2(0.22, 0.15), giro, Color("dfe8f0"))
		if estilo == &"colonial" or estilo == &"ecletico":
			# Lampiao de parede ao lado da porta.
			var lp := frente + lateral * junto + Vector3(0.0, 2.45, 0.0) + normal * 0.16
			ob.caixa(JanelaViva._p(&"metal"), lp + Vector3(0.0, 0.14, -0.08),
				Vector3(0.03, 0.03, 0.2), Color("222222"), giro)
			ob.caixa(JanelaViva._p(&"metal"), lp, Vector3(0.18, 0.26, 0.18),
				Color("2a2a2a"), giro)
			ob.caixa(JanelaViva._p(&"lampada"), lp, Vector3(0.12, 0.18, 0.12),
				Color.WHITE, giro)
		else:
			# Medidor da CEMIG com o conduite descendo, e a caixa de correio.
			ob.caixa(&"metal_pintado", frente + lateral * junto
				+ Vector3(0.0, 1.55, 0.0) + normal * 0.08, Vector3(0.34, 0.46, 0.14),
				Color("b8bcb4"), giro)
			ob.caixa(JanelaViva._p(&"metal_pintado"), frente + lateral * junto
				+ Vector3(0.0, 1.62, 0.0) + normal * 0.155, Vector3(0.18, 0.14, 0.01),
				Color("3a4a52"), giro)
			ob.caixa(&"metal_pintado", frente + lateral * junto
				+ Vector3(0.0, 0.7, 0.0) + normal * 0.04, Vector3(0.05, 1.2, 0.05),
				Color("9a9c96"), giro)
			if rng.randf() < 0.6:
				ob.caixa(JanelaViva._p(&"metal_pintado"),
					frente + lateral * (junto + lado * 0.45) + Vector3(0.0, 1.2, 0.0) + normal * 0.06,
					Vector3(0.3, 0.22, 0.1), [Color("c8452e"), Color("e8e4dc"), Color("3a6a8a")][rng.randi() % 3],
					giro)

	match morador:
		&"zelosa", &"idoso":
			# Vaso de espada-de-sao-jorge na soleira, e a trepadeira da zelosa.
			var n := rng.randi_range(1, 2)
			for k in n:
				var u := x_porta + (-lado if k == 0 else lado) * rng.randf_range(0.8, 1.1)
				if absf(u) > meia - 0.3:
					continue
				var vaso := pe + lateral * u + normal * 0.28
				ob.caixa(JanelaViva._p(&"reboco"), vaso + Vector3(0.0, 0.14, 0.0),
					Vector3(0.28, 0.28, 0.28), JanelaViva.TERRACOTA.darkened(rng.randf() * 0.2), giro)
				for f in 3:
					var t := Transform3D(Basis(Vector3.UP, giro + f * PI / 3.0),
						vaso + Vector3(0.0, 0.28 + 0.35, 0.0))
					ob.cartao(JanelaViva._p(&"folhagem_recorte"), Vector2(0.35, 0.7), t,
						Carroceria.uv(Vector2i(0, 0)), Color(0.65, 0.9, 0.55), 1)
			if morador == &"zelosa" and rng.randf() < 0.35:
				_trepadeira(ob, frente, lateral, normal, giro, x_porta, rng)
		&"abandonada":
			# Pichacao e mato no pe da parede.
			var u := rng.randf_range(-meia + 1.0, meia - 1.0)
			if _parede_livre(slots, u, 0.8):
				ob.placa(&"pichacao", frente + lateral * u + Vector3(0.0, 1.2, 0.0)
					+ normal * 0.015, Vector2(1.5, 0.75), giro)
			for k in int(largura / 0.8):
				var t := Transform3D(Basis(Vector3.UP, rng.randf() * PI),
					pe + lateral * rng.randf_range(-meia + 0.2, meia - 0.2) + normal * 0.08
					+ Vector3(0.0, 0.18, 0.0))
				ob.cartao(JanelaViva._p(&"flor"), Vector2(0.4, 0.36), t, Carroceria.uv(Vector2i(4, 0)), Color(0.9, 1.0, 0.8), 1)


## Parede sem vao em [x - folga, x + folga] no terreo.
static func _parede_livre(slots: Array[Dictionary], x: float, folga: float) -> bool:
	for s: Dictionary in slots:
		if absf(float(s["x"]) - x) < float(s["w"]) * 0.5 + folga:
			return false
	return true


## Buganvilia subindo do lado da porta e passando por cima dela: a massa de folha
## com a flor magenta que toda rua de Minas tem em alguma casa.
static func _trepadeira(ob: Obra, frente: Vector3, lateral: Vector3, normal: Vector3,
		giro: float, x_porta: float, rng: RandomNumberGenerator) -> void:
	var lado := -1.0 if rng.randf() < 0.5 else 1.0
	var x_tronco := x_porta + lado * 0.8
	# O tronco sobe da calcada rente a parede.
	ob.caixa(JanelaViva._p(&"tabua"), frente + lateral * x_tronco
		+ Vector3(0.0, 1.45, 0.0) + normal * 0.06, Vector3(0.06, 2.6, 0.06), Color("5a4430"), giro)
	# A copa: placas de folha deitadas quase na parede, em cima da porta, e a
	# flor magenta espalhada na frente delas.
	var base_folha := Basis(lateral, Vector3.UP, normal)
	for k in 16:
		var u := x_tronco - lado * rng.randf_range(-0.3, 1.5)
		var y := rng.randf_range(2.3, 3.05)
		var t := Transform3D(base_folha * Basis(Vector3.RIGHT, rng.randf_range(-0.5, -0.15))
			* Basis(Vector3.BACK, rng.randf_range(-0.6, 0.6)),
			frente + lateral * u + Vector3(0.0, y, 0.0) + normal * rng.randf_range(0.08, 0.2))
		JanelaViva.folhagem(ob, Vector2(0.5, 0.4), t, Color(0.5, 0.74, 0.42))
	for k in 16:
		var u := x_tronco - lado * rng.randf_range(-0.3, 1.5)
		var y := rng.randf_range(2.3, 3.0)
		var t := Transform3D(base_folha * Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.2)),
			frente + lateral * u + Vector3(0.0, y, 0.0) + normal * rng.randf_range(0.2, 0.3))
		ob.cartao(JanelaViva._p(&"flor"), Vector2(0.24, 0.15), t, Carroceria.uv(Vector2i(7, 0)), Color(1.0, 0.3, 0.72), 1)


# --- remate ------------------------------------------------------------------------

## O topo da casa pelo plano: telhado (com a cachorrada ja na fachada),
## platibanda alta da ecletica, beiral de laje, ou a laje da autoconstrucao com
## vergalhao de espera e a caixa d'agua azul de fibra.
static func coroar(sup: Dictionary, plano: Dictionary, topo: Vector3, tamanho: Vector3,
		direcao: int, rng: RandomNumberGenerator) -> void:
	var cor: Color = plano["cor_corpo"]
	match plano["remate"]:
		&"telhado":
			KitPredio.telhado(sup, topo, tamanho, direcao, cor, rng)
		&"platibanda":
			_platibanda(sup, topo, tamanho, cor, 1.0)
		&"beiral":
			_beiral(sup, topo, tamanho, direcao, cor)
		_:
			_platibanda(sup, topo, tamanho, cor, 0.3)
			_laje_popular(sup, topo, tamanho, direcao, rng)


## Mureta em volta da laje, no reboco e na cor da casa, com chapim claro. A do
## KitPredio e concreto sujo escurecido: em cima de casa pintada virava uma
## tarja cinza correndo a rua inteira.
static func _platibanda(sup: Dictionary, topo: Vector3, tamanho: Vector3, cor: Color,
		altura: float) -> void:
	const ESPESSURA := 0.18
	var y := topo.y + altura * 0.5
	var mx := tamanho.x * 0.5 - ESPESSURA * 0.5
	var mz := tamanho.z * 0.5 - ESPESSURA * 0.5
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"reboco", Vector3(topo.x + mx * lado, y, topo.z),
			Vector3(ESPESSURA, altura, tamanho.z), cor, 0.0)
		KitModular.caixa_cor(sup, &"reboco", Vector3(topo.x, y, topo.z + mz * lado),
			Vector3(tamanho.x - ESPESSURA * 2.0, altura, ESPESSURA), cor, 0.0)
	# Chapim: a pedra clara no topo, saindo 2 cm de cada lado.
	var chapim := cor.lerp(Color("ece8de"), 0.6)
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"concreto", Vector3(topo.x + mx * lado, topo.y + altura + 0.03,
			topo.z), Vector3(ESPESSURA + 0.04, 0.06, tamanho.z + 0.04), chapim, 0.0)
		KitModular.caixa_cor(sup, &"concreto", Vector3(topo.x, topo.y + altura + 0.03,
			topo.z + mz * lado), Vector3(tamanho.x - ESPESSURA * 2.0, 0.06, ESPESSURA + 0.04),
			chapim, 0.0)


## Beiral de laje fino da casa moderna: a laje que sai meio metro na frente,
## rebocada em baixo e pintada de branco na testeira.
static func _beiral(sup: Dictionary, topo: Vector3, tamanho: Vector3, direcao: int,
		cor: Color) -> void:
	const AVANCO := 0.6
	var normal := KitModular._normal(direcao)
	var planta := Vector3(tamanho.x, 0.0, tamanho.z) + normal.abs() * AVANCO
	KitModular.caixa_cor(sup, &"reboco", topo + normal * (AVANCO * 0.5) + Vector3(0.0, 0.07, 0.0),
		Vector3(planta.x, 0.14, planta.z), Color("f1efe8"), 0.0)
	KitModular.caixa_cor(sup, &"reboco", topo + Vector3(0.0, 0.3, 0.0),
		Vector3(tamanho.x, 0.3, tamanho.z), cor, 0.0)


## Vergalhao de espera nas quinas e a caixa d'agua azul de 1000 L.
static func _laje_popular(sup: Dictionary, topo: Vector3, tamanho: Vector3, direcao: int,
		rng: RandomNumberGenerator) -> void:
	var normal := KitModular._normal(direcao)
	var meio := Vector3(tamanho.x, 0.0, tamanho.z) * 0.5
	for dx: float in [-1.0, 1.0]:
		for dz: float in [-1.0, 1.0]:
			var quina := topo + Vector3(dx * (meio.x - 0.15), 0.0, dz * (meio.z - 0.15))
			for k in 4:
				var off := Vector3((k % 2) * 0.1 - 0.05, 0.0, (k / 2) * 0.1 - 0.05)
				KitModular.caixa_cor(sup, JanelaViva._p(&"metal"),
					quina + off + Vector3(0.0, 0.35, 0.0), Vector3(0.016, 0.7, 0.016),
					Color("5a3a2a"), 0.0)
	if rng.randf() < 0.85:
		# Na metade de tras da laje, que e onde ela fica.
		var p := topo - normal * minf(meio.x, meio.z) * 0.4 + Vector3(0.0, 0.25, 0.0)
		KitModular.caixa_cor(sup, &"concreto", p, Vector3(1.5, 0.5, 1.5), Color("b8b2a6"), 0.0)
		_cilindro(sup, &"metal_pintado", p + Vector3(0.0, 0.25, 0.0), 0.7, 0.9,
			Color("3d74b5"))
		_cilindro(sup, &"metal_pintado", p + Vector3(0.0, 1.15, 0.0), 0.62, 0.08,
			Color("2f5f99"))


## Prisma de 10 lados com tampa, de pe em `base`.
static func _cilindro(sup: Dictionary, material: StringName, base: Vector3, raio: float,
		alto: float, cor: Color) -> void:
	const LADOS := 10
	var d := PSXMesh.dados_vazios()
	var v: PackedVector3Array = d["v"]
	var n: PackedVector3Array = d["n"]
	var uv: PackedVector2Array = d["uv"]
	var uv2: PackedVector2Array = d["uv2"]
	var c: PackedColorArray = d["c"]
	var idx: PackedInt32Array = d["i"]
	for k in LADOS:
		var a0 := TAU * k / LADOS
		var a1 := TAU * (k + 1) / LADOS
		var p0 := Vector3(cos(a0) * raio, 0.0, sin(a0) * raio)
		var p1 := Vector3(cos(a1) * raio, 0.0, sin(a1) * raio)
		var fora := Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))
		var i0 := v.size()
		for p: Vector3 in [p0, p1, p1 + Vector3(0, alto, 0), p0 + Vector3(0, alto, 0)]:
			v.append(base + p)
			n.append(fora)
			uv.append(Vector2(p.x, p.y))
			uv2.append(Vector2.ZERO)
			c.append(cor)
		# Visivel do lado oposto ao produto vetorial.
		var prod := (v[i0 + 1] - v[i0]).cross(v[i0 + 2] - v[i0])
		if prod.dot(fora) > 0.0:
			idx.append_array([i0, i0 + 2, i0 + 1, i0, i0 + 3, i0 + 2])
		else:
			idx.append_array([i0, i0 + 1, i0 + 2, i0, i0 + 2, i0 + 3])
	# Tampa em leque.
	var centro := v.size()
	v.append(base + Vector3(0, alto, 0))
	n.append(Vector3.UP)
	uv.append(Vector2.ZERO)
	uv2.append(Vector2.ZERO)
	c.append(cor.darkened(0.05))
	for k in LADOS:
		var a0 := TAU * k / LADOS
		var a1 := TAU * (k + 1) / LADOS
		var i0 := v.size()
		v.append(base + Vector3(cos(a0) * raio, alto, sin(a0) * raio))
		v.append(base + Vector3(cos(a1) * raio, alto, sin(a1) * raio))
		for m in 2:
			n.append(Vector3.UP)
			uv.append(Vector2.ZERO)
			uv2.append(Vector2.ZERO)
			c.append(cor.darkened(0.05))
		var prod := (v[i0] - v[centro]).cross(v[i0 + 1] - v[centro])
		if prod.dot(Vector3.UP) > 0.0:
			idx.append_array([centro, i0 + 1, i0])
		else:
			idx.append_array([centro, i0, i0 + 1])
	d["v"] = v
	d["n"] = n
	d["uv"] = uv
	d["uv2"] = uv2
	d["c"] = c
	d["i"] = idx
	KitModular.por(sup, material, d, Transform3D.IDENTITY)
