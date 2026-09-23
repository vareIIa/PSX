## O resto da casa no sistema novo: a parede de tras, a lateral da esquina, o
## puxadinho e o quintal.
##
## Por que existe
## -------------
## A frente da casa ja saia por tipologia e morador (FachadaViva, ComercioVivo),
## com vao de verdade (ParedeVazada) e janela viva (JanelaViva). O resto do
## predio tinha ficado no caminho antigo (FundosBuilder): a parede de tras era
## uma caixa fina de concreto sujo na tinta da quadra, com a porta da cozinha e
## as janelas coladas 3 cm para fora; a lateral da esquina levava a placa de
## janela antiga sobre o reboco; o puxadinho era uma caixa com adesivo. Do alto
## do morro, do beco e da viela, era isso que se via: uma cidade de paredoes
## cinza com janelinha pintada (PLANO_CASAS_AAA, D12).
##
## O fundo da casa mineira nao e a frente repetida:
##   - a porta da cozinha, de tabua ou de ferro com vidro canelado, um degrau
##     acima do cimentado, com o telhadinho em cima e o botijao do lado;
##   - a janela da cozinha ao lado dela (a pia fica embaixo), o vitro alto do
##     banheiro, o cobogo da area de servico;
##   - a parede que o dono nao pintou: tijolo aparente na casa popular, reboco
##     cru na moderna, e a mancha de umidade no pe de todas;
##   - o cano de descida e a calha, ou o buzinote da laje com o escorrido; o
##     condensador do ar na loja; a roupa no varal da janela do predio.
## A lateral da esquina, ao contrario, E fachada: a mesma parede, o mesmo barrado
## dobrando a quina, a mesma esquadria, o cunhal, e na loja a segunda porta de
## aco ou o nome pintado na parede cega.
##
## Como entra na cidade
## --------------------
## ChunkBuilder._fileira chama `fundo` e `lateral` no lugar de FundosBuilder.fundo
## e FundosBuilder.lateral_de_esquina quando o lote tem plano; a massa da esquina
## sai sem a face da lateral, que agora e a ParedeVazada. FundosBuilder._quintal
## chama `quintal` quando o lote tem plano. `--sem-fachada-viva` volta tudo ao
## caminho antigo.
##
## Nenhuma funcao daqui gasta o rng do chunk: cada uma semeia o seu a partir do
## plano, como a FachadaViva. A casa sai a mesma a cada visita.
class_name FundosVivos
extends RefCounted

const ANDAR := KitModular.ALTURA_ANDAR
## A soleira da porta da cozinha: um degrau acima do cimentado do quintal.
const SOLEIRA := 0.2
const PORTA := Vector2(0.82, 2.1)
## Peitoril (do pe do andar) e altura de cada vao do fundo. Toda verga fica na
## mesma linha, a 2,3 m, que e a da porta da cozinha: e assim que o pedreiro
## faz, e cada altura diferente de vao corta mais uma faixa na parede inteira
## (ParedeVazada), que era o grosso dos triangulos do fundo.
const VERGA := 2.3
const VAOS := {
	&"cozinha": Vector2(1.2, 1.1),
	&"banheiro": Vector2(1.7, 0.6),
	&"quarto": Vector2(1.2, 1.1),
	&"area": Vector2(1.2, 1.1),
	&"cobogo": Vector2(1.2, 1.1),
	&"deposito": Vector2(1.7, 0.6),
}
## Largura minima e maxima de cada vao do fundo.
const LARGURAS := {
	&"cozinha": Vector2(0.9, 1.3),
	&"banheiro": Vector2(0.55, 0.65),
	&"quarto": Vector2(1.0, 1.3),
	&"area": Vector2(1.1, 1.5),
	&"cobogo": Vector2(1.0, 1.6),
	&"deposito": Vector2(1.2, 1.9),
}
## Porta de ferro de cozinha: branco, azul, verde, vinho, bege e o preto.
const FERROS: Array[Color] = [Color("e6e4dc"), Color("3f5a78"), Color("5a6a4a"),
	Color("8a3a2e"), Color("b8b0a0"), Color("2f2f2f")]
## Botijao de 13 kg: cada distribuidora pinta o seu.
const BOTIJOES: Array[Color] = [Color("4f6f9a"), Color("b8b8b0"), Color("c05a2a"),
	Color("5a7a4a")]
## Engradado de garrafa no fundo da loja e do bar.
const ENGRADADOS: Array[Color] = [Color("c8322a"), Color("e0b020"), Color("2f7a3a"),
	Color("2a5a9a")]
## Pe-direito do puxadinho e do telheiro, no pe da parede de frente.
const ALTO_PUXADINHO := 2.6
## Quanto a meia-agua do puxadinho sobe da frente ate a parede da casa.
const CAIMENTO := 0.4


# --- parede de tras ------------------------------------------------------------

## A parede de tras do predio da fileira, com vao de verdade.
##
## `frente_lote` e o meio do lote na linha da quadra (como em `_fileira`); a
## parede fica PROF_PREDIO para dentro, virada para o quintal. `plano` e o da
## FachadaViva ou da ComercioVivo, e `info` o que a frente devolveu (a esquadria
## da casa em "casa", para a janela de tras ter a mesma cor). Devolve em
## info["porta_fundo"] o ponto da porta dos fundos no pe da parede, para o
## quintal nao por o puxadinho em cima dela.
##
## `xf` leva o espaco em que a casa e montada para o do chunk, quando ela e
## montada no espaco dela e girada depois (a casa solta da serpentina,
## SerpentinaBuilder._casa): o chao do quintal e medido no ponto certo.
static func fundo(sup: Dictionary, frente_lote: Vector3, larg: float, andares: int,
		direcao: int, plano: Dictionary, prob_acesa: float, info: Dictionary = {},
		cx: int = 0, cz: int = 0, dy: float = NAN, cego: bool = false,
		xf: Transform3D = Transform3D.IDENTITY) -> void:
	var ob := Obra.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(plano["semente"]) * 7919 + 101
	var tipo: StringName = plano.get("tipo", &"casa")
	var estilo: StringName = plano["estilo"]
	var morador: StringName = plano.get("morador", &"familia")
	var normal := KitModular._normal(direcao)
	var dir_tras := posmod(direcao + 2, 4)
	var fora := -normal
	var lateral := KitModular._lateral(dir_tras)
	var giro := atan2(fora.x, fora.z)
	var altura := float(andares) * ANDAR
	var base := frente_lote - normal * ChunkBuilder.PROF_PREDIO
	var meia := larg * 0.5
	var casa: Dictionary = info.get("casa", {})
	# O quintal, atras, segue o terreno; o lote sobe rigido pela frente. Sem medir
	# o chao aqui, 28% das portas de cozinha ficavam penduradas no ar sobre o
	# embasamento e 35% enterradas no quintal (levantamento dos fundos).
	var terreno := is_finite(dy)
	var chao := func(x: float) -> float:
		if not terreno:
			return 0.0
		return Relevo.local(cx, cz, xf * (base + lateral * x + fora * 0.45)) - dy
	# Parede de tras um pouco mais fina que a da frente.
	var prof := clampf(JanelaViva.profundidade(estilo) - 0.06, 0.12, 0.26)
	# O comodo da janela aberta de tras encontra o da frente no meio da casa: sem
	# teto, as duas caixas se cruzavam na casa recuada, que e mais rasa.
	var fundo_max := maxf(1.3, float(plano.get("fundura", ChunkBuilder.PROF_PREDIO)) * 0.5
		- prof - 0.15)

	# --- acabamento --------------------------------------------------------------
	var mat: StringName = plano.get("mat_corpo", &"reboco")
	var cor: Color = plano.get("cor_corpo", Color("d8d2c6"))
	var faixas: Array = []
	var sorte := rng.randf()
	var tijolo := estilo == &"popular" and sorte < 0.45
	if not tijolo and ((estilo == &"popular" and sorte < 0.72)
			or ((estilo == &"moderno" or estilo == &"predio") and sorte < 0.22)):
		# Reboco cru: o dono pintou a frente e o fundo ficou para depois.
		cor = Color("b4afa5").lerp(cor, 0.2)
	if morador == &"abandonada":
		cor = cor.lerp(Color("9d988e"), 0.4)
	if tijolo:
		mat = &"tijolo"
		cor = Color.WHITE
	else:
		if estilo == &"colonial":
			faixas.append({"y0": 0.0, "y1": 0.95, "cor": plano.get("barrado", cor.darkened(0.35))})
		else:
			# Umidade subindo do pe: o respingo da chuva no cimentado.
			faixas.append({"y0": 0.0, "y1": rng.randf_range(0.3, 0.55),
				"cor": cor.darkened(rng.randf_range(0.1, 0.17))})
		if bool(plano.get("tijolo_em_cima", false)) and andares >= 2:
			faixas.append({"y0": ANDAR, "y1": altura, "cor": Color.WHITE, "material": &"tijolo"})

	if cego:
		# Atras deste lote esta a casa da fileira perpendicular (15% dos fundos):
		# ninguem ve porta nem janela, e so a parede fecha a caixa.
		ParedeVazada.erguer(sup, mat, base, larg, altura, dir_tras, cor, [], faixas,
			ParedeVazada.desgaste_de(plano, &"fundo"))
		return

	# --- onde vai cada vao ---------------------------------------------------------
	var slots: Array[Dictionary] = []
	var margem := 0.3
	var de := -meia + margem
	var ate := meia - margem
	# Loja e predio: a porta de servico, e na loja as vezes a porta de aco do
	# deposito. O sobrado mora em cima da loja e tem cozinha no fundo.
	var industria := bool(plano.get("industria", false))
	var servico := industria or tipo == &"loja" or tipo == &"predio" \
		or (tipo == &"sobrado" and rng.randf() < 0.45)
	var x_porta := 0.0
	var w_porta := PORTA.x + (0.08 if estilo == &"colonial" else 0.0)
	var tipo_porta: StringName = &"porta"
	if servico and tipo != &"predio" and larg >= 4.2 and rng.randf() < 0.55:
		tipo_porta = &"porta_aco"
		w_porta = minf(rng.randf_range(1.8, 2.6), larg - 1.4)
	var livre := meia - margem - w_porta * 0.5
	if livre > 0.0:
		x_porta = rng.randf_range(-livre, livre) * 0.85
	slots.append({"tipo": tipo_porta, "x": x_porta, "w": w_porta, "andar": 0})
	# Do lado da porta que sobra mais parede.
	var lado := 1.0 if x_porta < 0.0 else -1.0
	var terreo: Array[StringName] = []
	if servico:
		terreo.append_array([&"deposito", &"banheiro"] as Array[StringName])
	else:
		terreo.append_array([&"cozinha", &"banheiro"] as Array[StringName])
		if rng.randf() < 0.35:
			terreo.append(&"cobogo")
		terreo.append(&"quarto")
	var x_banheiro := -lado * meia
	for t: StringName in terreo:
		var w := _largura(t, rng)
		var alvo := rng.randf_range(de, ate)
		if t == &"cozinha" or t == &"deposito":
			alvo = x_porta + lado * (w_porta * 0.5 + 0.45 + w * 0.5)
		elif t == &"banheiro":
			alvo = x_banheiro
		var x := _encaixar(slots, 0, t, w, de, ate, alvo)
		if t == &"banheiro" and is_finite(x):
			x_banheiro = x
	# Andares de cima: o banheiro em cima do de baixo (o encanamento desce junto).
	for andar in range(1, andares):
		var cima: Array[StringName] = []
		if industria:
			# Galpao nao tem andar: em cima do portao corre a fita de vitro alto.
			cima.append_array([&"deposito", &"deposito"] as Array[StringName])
		elif tipo == &"predio":
			cima.append_array([&"banheiro", &"area", &"cozinha"] as Array[StringName])
		elif tipo == &"sobrado" or tipo == &"loja":
			cima.append_array([&"banheiro", &"cozinha", &"quarto"] as Array[StringName])
		elif larg < 8.0:
			cima.append_array([&"banheiro", &"quarto"] as Array[StringName])
		else:
			cima.append_array([&"banheiro", &"quarto", &"quarto"] as Array[StringName])
		for t: StringName in cima:
			var w := _largura(t, rng)
			_encaixar(slots, andar, t, w, de, ate,
				x_banheiro if t == &"banheiro" else rng.randf_range(de, ate))

	# --- vaos e estados ------------------------------------------------------------
	var vaos: Array = []
	var estados: Array = []
	for s: Dictionary in slots:
		var x: float = s["x"]
		var w: float = s["w"]
		var andar: int = s["andar"]
		var t: StringName = s["tipo"]
		var y_andar := float(andar) * ANDAR
		var vao := {"tipo": t, "indice": estados.size(), "prof": prof}
		var e := {}
		var g: float = chao.call(x) if andar == 0 else 0.0
		# O terreo da loja de verdade (LojaViva) e o salao inteiro, ate a parede de
		# tras: sem porta de cozinha nem janela, que dariam no meio da prateleira.
		if andar == 0 and plano.has("loja_viva"):
			continue
		match t:
			&"porta":
				# Quintal mais alto que o piso: a soleira sobe com ele, ate o ponto
				# em que a porta nao cabe mais e o fundo fica so com a parede.
				if g > 0.9:
					continue
				vao["rect"] = Rect2(x - w * 0.5, maxf(SOLEIRA, g + 0.16), w, PORTA.y)
			&"porta_aco":
				if g > 0.7:
					continue
				vao["rect"] = Rect2(x - w * 0.5, maxf(0.06, g + 0.1), w, 2.35)
				vao["prof"] = 0.22
				e = {"tipo": &"enrolar", "estado": 0, "semente": rng.randi(), "acesa": false,
					"cor": ComercioVivo.CORES_LOJA[rng.randi() % ComercioVivo.CORES_LOJA.size()]}
			&"cobogo":
				var m: Vector2 = VAOS[t]
				var y_c := maxf(y_andar + m.x, g + 0.35)
				if y_c + m.y > y_andar + ANDAR - 0.15:
					continue
				vao["rect"] = Rect2(x - w * 0.5, y_c, w, m.y)
			_:
				var m: Vector2 = VAOS[t]
				# Peitoril sempre acima do chao do quintal: janela enterrada dava
				# para dentro da terra.
				var y_j := maxf(y_andar + m.x, g + 0.35)
				if y_j + m.y > y_andar + ANDAR - 0.15:
					continue
				e = _estado(t, rng, estilo, morador, andar, rng.randf() < prob_acesa * 0.85, casa)
				e["larg_max"] = FachadaViva._largura_comodo(x, meia)
				e["fundo_max"] = fundo_max
				if plano.has("loja_viva"):
					# Em cima da loja: o comodo nao desce abaixo do piso do andar.
					e["piso_em"] = y_andar
				vao["rect"] = Rect2(x - w * 0.5, y_j, w, m.y)
				vao["tampa"] = JanelaViva.precisa_tampa(e)
		vaos.append(vao)
		estados.append(e)
	var quadros := ParedeVazada.erguer(sup, mat, base, larg, altura, dir_tras, cor, vaos,
		faixas, ParedeVazada.desgaste_de(plano, &"fundo"))

	# --- o conteudo de cada vao -----------------------------------------------------
	for q: Dictionary in quadros:
		var e: Dictionary = estados[int(q["indice"])]
		match q["tipo"]:
			&"porta":
				_porta_cozinha(ob, q, estilo, servico, casa, rng)
				var chao_porta: float = chao.call((q["rect"] as Rect2).get_center().x)
				_degrau(ob, q, chao_porta)
				_telhadinho(ob, q, estilo, rng)
				if not servico and morador != &"abandonada" and rng.randf() < 0.55:
					_botijao(ob, q, rng, chao_porta)
				info["porta_fundo"] = (q["pe"] as Vector3) - Vector3(0.0, SOLEIRA, 0.0)
			&"porta_aco":
				ComercioVivo._loja(ob, q, e, rng)
				_degrau(ob, q, chao.call((q["rect"] as Rect2).get_center().x))
				info["porta_fundo"] = (q["pe"] as Vector3) - Vector3(0.0, 0.06, 0.0)
			&"cobogo":
				_cobogo(ob, q, Color("d8d2c6") if tijolo else cor.lightened(0.05))
			_:
				JanelaViva.preencher_em(ob, q, e,
					FachadaViva._espaco_dos_lados(q["rect"], quadros))
				if q["tipo"] == &"area" and rng.randf() < 0.75:
					_roupa_na_janela(ob, q, rng)

	# --- agua da chuva, ar-condicionado ------------------------------------------
	var remate: StringName = plano.get("remate", &"telhado")
	var cor_cano: Color = [Color("8b8d88"), Color("d8d6ce"), Color("6e6a62")][rng.randi() % 3]
	if remate == &"industria":
		# Arco, oitao e shed do galpao: a agua cai pelas laterais, e o fundo e
		# oitao ou timpano (IndustriaViva.coroar). Nada de calha nem buzinote aqui.
		pass
	elif remate == &"telhado":
		# Cano de descida numa ponta e a calha sob o beiral de tras, que sai meio
		# metro da parede (KitPredio.telhado), ou onde o TelhadoVivo pos a ponta.
		var ponta := (meia - 0.16) * (1.0 if rng.randf() < 0.5 else -1.0)
		var sai := 0.5
		var y_calha := altura + 0.07
		var beiral := TelhadoVivo.beiral_de_tras(plano)
		if not beiral.is_empty():
			# Pendurada por fora da testeira, logo abaixo da ponta da agua.
			sai = float(beiral["sai"]) + 0.07
			y_calha = float(beiral["y"]) - 0.02
		var h_cano := y_calha - 0.02
		ob.caixa(&"metal_pintado", base + lateral * ponta + fora * 0.06
			+ Vector3(0.0, h_cano * 0.5, 0.0), Vector3(0.08, h_cano, 0.08), cor_cano, giro)
		ob.caixa(&"metal_pintado", base + fora * sai + Vector3(0.0, y_calha, 0.0),
			Vector3(larg, 0.1, 0.12), cor_cano, giro)
		ob.caixa(&"metal_pintado", base + lateral * ponta + fora * (sai * 0.5 + 0.03)
			+ Vector3(0.0, y_calha - 0.01, 0.0), Vector3(0.08, 0.08, sai - 0.06), cor_cano, giro)
	else:
		# Laje e platibanda: o buzinote que fura a mureta, e o escorrido que ele
		# deixa na parede em todo fundo de casa de laje.
		var x_b := _x_livre(slots, rng, de + 0.3, ate - 0.3, 0.35, -1)
		if is_finite(x_b):
			ob.caixa(&"metal_pintado", base + lateral * x_b + fora * 0.18
				+ Vector3(0.0, altura + 0.1, 0.0), Vector3(0.1, 0.08, 0.36), Color("8b8d88"), giro)
			if not tijolo:
				var h_mancha := rng.randf_range(1.2, maxf(1.3, altura - 0.4))
				ob.plano(&"reboco", base + lateral * x_b + fora * 0.006
					+ Vector3(0.0, altura - h_mancha * 0.5, 0.0), Vector2(0.34, h_mancha), fora,
					lateral, cor.darkened(0.2))
	if servico or estilo == &"moderno" or tipo == &"predio":
		for andar in andares:
			if rng.randf() > (0.45 if servico else 0.25):
				continue
			# Folga do telhadinho da porta (0,35 m alem do vao) mais meio condensador.
			var x_ar := _x_livre(slots, rng, de + 0.45, ate - 0.45, 0.8, andar)
			if is_finite(x_ar):
				_condensador(ob, base + lateral * x_ar
					+ Vector3(0.0, float(andar) * ANDAR + 2.62, 0.0), lateral, fora, giro)
	ob.despejar(sup)


## Largura sorteada de um tipo de vao do fundo.
static func _largura(tipo: StringName, rng: RandomNumberGenerator) -> float:
	var l: Vector2 = LARGURAS.get(tipo, Vector2(1.0, 1.2))
	return rng.randf_range(l.x, l.y)


## Poe o vao no trecho livre do andar mais perto de `alvo`. Devolve o x usado,
## ou NAN se nao coube em lugar nenhum.
static func _encaixar(slots: Array[Dictionary], andar: int, tipo: StringName, w: float,
		de: float, ate: float, alvo: float) -> float:
	var do_andar: Array = []
	for s: Dictionary in slots:
		if int(s["andar"]) == andar:
			do_andar.append(s)
	var melhor := INF
	var x_melhor := NAN
	for tr: Vector2 in FachadaViva._livres(do_andar, de, ate, 0.3):
		if tr.y - tr.x < w:
			continue
		var x := clampf(alvo, tr.x + w * 0.5, tr.y - w * 0.5)
		if absf(x - alvo) < melhor:
			melhor = absf(x - alvo)
			x_melhor = x
	if is_finite(x_melhor):
		slots.append({"tipo": tipo, "x": x_melhor, "w": w, "andar": andar})
	return x_melhor


## Um x de parede sem vao em [x - folga, x + folga] no andar (-1: em todos).
static func _x_livre(slots: Array[Dictionary], rng: RandomNumberGenerator, de: float,
		ate: float, folga: float, andar: int) -> float:
	if ate <= de:
		return NAN
	for tentativa in 8:
		var x := rng.randf_range(de, ate)
		var ok := true
		for s: Dictionary in slots:
			if andar >= 0 and int(s["andar"]) != andar:
				continue
			if absf(float(s["x"]) - x) < float(s["w"]) * 0.5 + folga:
				ok = false
				break
		if ok:
			return x
	return NAN


## O estado de uma janela de fundo: quase ninguem cuida de flor ali, o banheiro e
## vitro canelado, a cozinha tem tempero no peitoril.
static func _estado(tipo: StringName, rng: RandomNumberGenerator, estilo: StringName,
		morador: StringName, andar: int, acesa: bool, casa: Dictionary) -> Dictionary:
	var e := JanelaViva.sortear(rng, estilo, morador, andar, acesa, casa)
	e["floreira"] = false
	e["samambaia"] = false
	e["vasos"] = 0
	match tipo:
		&"banheiro", &"deposito":
			e["modelo"] = &"basculante"
			e["vidro"] = &"vidro_canelado"
			e["peitoril_externo"] = false
			if tipo == &"banheiro":
				e["grade"] = 0
		&"cozinha", &"area":
			e["comodo"] = &"cozinha"
			if tipo == &"area":
				e["modelo"] = &"correr"
			elif estilo == &"popular" and rng.randf() < 0.5:
				e["modelo"] = &"basculante"
			if e["modelo"] != &"basculante" and rng.randf() < 0.4:
				# Tempero no peitoril: cebolinha e pimenta no vaso de barro.
				e["vasos"] = rng.randi_range(1, 3)
				e["flor"] = Vector2i(4, 0)
		_:
			e["comodo"] = &"quarto"
	if e["modelo"] == &"basculante":
		e["abertura"] = JanelaViva.Abertura.FECHADA
	return e


## A porta da cozinha, fechada no fundo do vao: de ferro com vidro canelado (a da
## casa dos anos 70 e a de servico da loja), de tabua, as vezes com a folha de
## cima aberta, ou a almofadada da frente.
static func _porta_cozinha(ob: Obra, q: Dictionary, estilo: StringName, servico: bool,
		casa: Dictionary, rng: RandomNumberGenerator) -> void:
	var v := JanelaViva._vao(q)
	var d := v.prof - 0.045
	var sorte := rng.randf()
	if servico or ((estilo == &"moderno" or estilo == &"popular" or estilo == &"predio")
			and sorte < 0.6):
		_porta_de_ferro(ob, v, d, rng)
	elif sorte < 0.85:
		_porta_de_tabua(ob, v, d, casa, rng)
	else:
		FachadaViva._porta(ob, q, estilo, {}, rng)


## Chapa embaixo, vidro canelado com grade de barra chata em cima.
static func _porta_de_ferro(ob: Obra, v: JanelaViva.Vao, d: float,
		rng: RandomNumberGenerator) -> void:
	var cor: Color = FERROS[rng.randi() % FERROS.size()]
	var h_chapa := v.h * 0.5
	var h_vidro := v.h - h_chapa
	ob.caixa(&"metal_pintado", v.p(0.0, h_chapa * 0.5, d),
		Vector3(v.w - 0.02, h_chapa, 0.035), cor, v.giro)
	for k in 3:
		ob.placa(&"metal_pintado", v.p(0.0, h_chapa * float(k + 1) / 4.0, d - 0.02),
			Vector2(v.w - 0.16, 0.03), v.giro, cor.darkened(0.18))
	ob.parede(&"vidro_canelado", v.p(0.0, h_chapa + h_vidro * 0.5, d + 0.01),
		Vector2(v.w - 0.04, h_vidro), v.giro)
	for lado: float in [-1.0, 1.0]:
		ob.caixa(&"metal_pintado", v.p(lado * (v.w * 0.5 - 0.03), v.h * 0.5, d - 0.012),
			Vector3(0.05, v.h, 0.05), cor, v.giro)
	for y: float in [v.h - 0.03, h_chapa]:
		ob.caixa(&"metal_pintado", v.p(0.0, y, d - 0.012), Vector3(v.w - 0.1, 0.05, 0.05),
			cor, v.giro)
	for k in range(1, 5):
		ob.placa(&"metal", v.p(-v.w * 0.5 + v.w * float(k) / 5.0, h_chapa + h_vidro * 0.5,
			d - 0.03), Vector2(0.018, h_vidro - 0.06), v.giro, cor.darkened(0.3))
	ob.caixa(JanelaViva._p(&"metal"), v.p(v.w * 0.34, 1.0, d - 0.045),
		Vector3(0.1, 0.03, 0.04), Color("c8c0a0"), v.giro)


## Porta de tabua pintada na cor da esquadria da casa. Uma em cada tres e a de
## duas folhas, com a de cima aberta: a cozinha escura e a cortininha de pano.
static func _porta_de_tabua(ob: Obra, v: JanelaViva.Vao, d: float, casa: Dictionary,
		rng: RandomNumberGenerator) -> void:
	var cor: Color = casa.get("esquadria",
		JanelaViva.ESQUADRIAS[rng.randi() % JanelaViva.ESQUADRIAS.size()])
	if rng.randf() < 0.35:
		# Tinta gasta: a porta de tras nunca e repintada junto com a da frente.
		cor = cor.lerp(Color("8a7a66"), 0.45)
	var holandesa := rng.randf() < 0.33
	var h_baixo := v.h * 0.5 if holandesa else v.h
	ob.caixa(&"tabua", v.p(0.0, h_baixo * 0.5, d), Vector3(v.w - 0.02, h_baixo, 0.045),
		cor, v.giro)
	for k in 4:
		ob.placa(JanelaViva._p(&"tabua"), v.p(-v.w * 0.3 + v.w * 0.2 * float(k),
			h_baixo * 0.5, d - 0.025), Vector2(0.02, h_baixo - 0.08), v.giro,
			cor.darkened(0.25))
	if holandesa:
		ob.caixa(&"tabua", v.p(0.0, h_baixo, d - 0.01), Vector3(v.w, 0.05, 0.07),
			cor.darkened(0.1), v.giro)
		if rng.randf() < 0.6:
			var pano: Color = JanelaViva.CORTINAS[rng.randi() % JanelaViva.CORTINAS.size()]
			var alt := v.h - h_baixo - 0.06
			ob.cartao(JanelaViva._p(&"cortina"), Vector2(v.w - 0.1, alt),
				Transform3D(v.base(), v.p(0.0, h_baixo + 0.03 + alt * 0.5, d + 0.03)),
				Rect2(0.0, 0.0, 0.6, 0.6), pano, 2)
	ob.caixa(JanelaViva._p(&"metal"), v.p(v.w * 0.34, 1.0, d - 0.04),
		Vector3(0.04, 0.12, 0.04), Color("2a2a2a"), v.giro)


## O degrau de cimento do quintal ate a soleira. Na ladeira o quintal desce
## debaixo do lote rigido, e o que liga a porta ao chao e uma escadinha de
## cimento de espelho 17 cm, a que toda casa de morro tem nos fundos.
static func _degrau(ob: Obra, q: Dictionary, chao: float = 0.0) -> void:
	var v := JanelaViva._vao(q)
	var queda := v.base_y - chao
	if queda < 0.34:
		ob.caixa(&"concreto", v.p(0.0, -maxf(queda, 0.06) * 0.5, -0.19),
			Vector3(v.w + 0.34, maxf(queda, 0.06), 0.38), Color("bdb7aa"), v.giro)
		return
	var n := clampi(int(ceil(queda / 0.17)), 2, 14)
	var espelho := queda / n
	var pedra := Color("bdb7aa")
	var fundo := -queda
	for k in n:
		# Cada degrau desce ate o chao do quintal: de lado, a escada e cheia.
		var topo := -espelho * k
		ob.caixa(&"concreto", v.p(0.0, (topo + fundo) * 0.5, -0.14 - k * 0.28),
			Vector3(v.w + 0.3, maxf(topo - fundo, 0.05), 0.28), pedra.darkened(0.015 * k),
			v.giro)
	if queda > 0.7:
		# Corrimao de cano de um lado so, como o da casa de morro.
		var lado := 1.0 if int(absf(v.giro) * 10.0) % 2 == 0 else -1.0
		var comp := n * 0.28
		ob.caixa(JanelaViva._p(&"metal"), v.p(lado * (v.w * 0.5 + 0.1), -queda * 0.5 + 0.95,
			-0.14 - comp * 0.5), Vector3(0.05, 0.05, comp), Color("8a8880"), v.giro)
		for k: int in [0, n - 1]:
			ob.caixa(JanelaViva._p(&"metal"), v.p(lado * (v.w * 0.5 + 0.1),
				-espelho * k + 0.45, -0.14 - k * 0.28), Vector3(0.05, 0.95, 0.05),
				Color("8a8880"), v.giro)


## O telhadinho sobre a porta dos fundos: telha de barro em duas maos-francesas,
## ou a laje de concreto de sempre.
static func _telhadinho(ob: Obra, q: Dictionary, estilo: StringName,
		rng: RandomNumberGenerator) -> void:
	var v := JanelaViva._vao(q)
	var larg := v.w + 0.7
	var y := v.h + 0.22
	if estilo == &"colonial" or rng.randf() < 0.35:
		const SAI := 0.8
		const INCLINA := 0.36
		var b := v.base() * Basis(Vector3.RIGHT, INCLINA)
		ob.livre(&"telha", v.p(0.0, y + 0.1, -SAI * 0.5), Vector3(larg, 0.05, SAI / cos(INCLINA)),
			b, Color.WHITE.lerp(Color("9a7a66"), rng.randf_range(0.0, 0.5)))
		var mao := v.base() * Basis(Vector3.RIGHT, -PI * 0.25)
		for lado: float in [-1.0, 1.0]:
			ob.livre(&"tabua", v.p(lado * (larg * 0.5 - 0.12), y - 0.22, -0.27),
				Vector3(0.06, 0.06, 0.72), mao, Color("5a4430"))
	else:
		ob.caixa(&"concreto", v.p(0.0, y, -0.3), Vector3(larg, 0.08, 0.6), Color("b8b4aa"),
			v.giro)


## Botijao de gas do lado da porta da cozinha, com a mangueira entrando na parede.
##
## `chao` e o quintal no pe da porta, relativo ao piso: o botijao pousa nele, ao
## lado da escadinha, e nao no ar na altura da soleira.
static func _botijao(ob: Obra, q: Dictionary, rng: RandomNumberGenerator,
		chao: float = 0.0) -> void:
	var v := JanelaViva._vao(q)
	var u := (-1.0 if rng.randf() < 0.5 else 1.0) * (v.w * 0.5 + 0.42)
	var pe := v.p(u, chao - v.base_y + 0.04, -0.3)
	var cor: Color = BOTIJOES[rng.randi() % BOTIJOES.size()]
	ob.cilindro(JanelaViva._p(&"metal_pintado"), pe, 0.18, 0.46, cor, 8)
	ob.cilindro(JanelaViva._p(&"metal_pintado"), pe + Vector3(0.0, 0.46, 0.0), 0.1, 0.1,
		cor.darkened(0.25), 6)
	ob.caixa(JanelaViva._p(&"metal"), v.p(u, chao - v.base_y + 0.62, -0.15),
		Vector3(0.025, 0.025, 0.3), Color("303030"), v.giro)


## Cobogo: a grade de blocos vazados que ventila a area de servico.
static func _cobogo(ob: Obra, q: Dictionary, cor: Color) -> void:
	var v := JanelaViva._vao(q)
	var nx := maxi(3, int(round(v.w / 0.2)))
	var ny := maxi(2, int(round(v.h / 0.2)))
	var fundo := v.prof - 0.012
	var faces := PSXMesh.FACE_TODAS & ~PSXMesh.FACE_TRAS
	for i in range(1, nx):
		ob.caixa(&"concreto", v.p(-v.w * 0.5 + v.w * float(i) / nx, v.h * 0.5, fundo * 0.5),
			Vector3(0.05, v.h, fundo), cor, v.giro, faces)
	# A fiada horizontal 5 mm mais funda: frente com frente no mesmo plano piscava.
	for j in range(1, ny):
		ob.caixa(&"concreto", v.p(0.0, v.h * float(j) / ny, fundo * 0.5 + 0.004),
			Vector3(v.w, 0.05, fundo - 0.008), cor, v.giro, faces)


## Condensador do ar-condicionado na mao-francesa, com o dreno descendo.
static func _condensador(ob: Obra, centro: Vector3, lateral: Vector3, fora: Vector3,
		giro: float) -> void:
	ob.caixa(&"metal_pintado", centro + fora * 0.2, Vector3(0.8, 0.54, 0.3),
		Color("e2e4e0"), giro)
	ob.placa(JanelaViva._p(&"metal"), centro + fora * 0.352 + lateral * 0.1,
		Vector2(0.44, 0.44), giro, Color("3c4042"))
	for lado: float in [-1.0, 1.0]:
		ob.caixa(&"metal", centro + lateral * (lado * 0.3) + fora * 0.2
			+ Vector3(0.0, -0.3, 0.0), Vector3(0.035, 0.035, 0.4), Color("6a6c6a"), giro)
	ob.caixa(JanelaViva._p(&"metal_pintado"), centro + lateral * 0.34 + fora * 0.06
		+ Vector3(0.0, -0.9, 0.0), Vector3(0.025, 1.2, 0.025), Color("e8e8e0"), giro)


## Varal de janela do predio: duas maos-francesas, tres fios e a roupa pendurada.
static func _roupa_na_janela(ob: Obra, q: Dictionary, rng: RandomNumberGenerator) -> void:
	var v := JanelaViva._vao(q)
	const SAI := 0.4
	var fio := Color("d8d8d0")
	for lado: float in [-1.0, 1.0]:
		ob.caixa(JanelaViva._p(&"metal"), v.p(lado * (v.w * 0.5 - 0.05), -0.12, -SAI * 0.5),
			Vector3(0.025, 0.025, SAI), fio, v.giro)
	for k in 3:
		ob.caixa(JanelaViva._p(&"metal"), v.p(0.0, -0.12, -0.1 - float(k) * 0.13),
			Vector3(v.w - 0.06, 0.012, 0.012), fio, v.giro)
	var n := rng.randi_range(2, 4)
	for k in n:
		var tam := Vector2(rng.randf_range(0.28, 0.5), rng.randf_range(0.35, 0.6))
		var u := -v.w * 0.5 + (float(k) + 0.5) * v.w / n
		var c: Color = FundosBuilder.ROUPAS[rng.randi() % FundosBuilder.ROUPAS.size()]
		ob.cartao(&"cortina", tam, Transform3D(v.base(),
			v.p(u, -0.12 - tam.y * 0.5, -0.1 - float(k % 3) * 0.13)),
			Rect2(0.0, 0.0, tam.x * 0.8, tam.y * 0.8), c, 2)


# --- lateral da esquina ------------------------------------------------------------

## A lateral do predio de esquina, a que da para a rua transversal, como
## fachada: mesma parede e mesmas faixas da frente (o barrado dobra a quina),
## janela da mesma esquadria, cunhal e friso. Na loja, a segunda porta de aco ou
## o nome pintado na parede cega.
##
## `t` e a posicao da lateral ao longo da face e `sentido` diz para onde ela
## olha (como FundosBuilder.lateral_de_esquina). A massa do lote tem de sair SEM
## essa face (ChunkBuilder._fileira): a parede e esta.
##
## A janela da lateral nunca abre inteira: o comodo dela cruzaria o da janela da
## frente perto da quina. Entreaberta ou fechada, ela tem a tampa escura atras.
static func lateral(sup: Dictionary, face: Dictionary, t: float, sentido: float,
		andares: int, plano: Dictionary, prob_acesa: float, info: Dictionary = {},
		cx: int = 0, cz: int = 0, dy: float = NAN) -> void:
	var ob := Obra.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(plano["semente"]) * 6271 + (1 if sentido > 0.0 else 2)
	var tipo: StringName = plano.get("tipo", &"casa")
	var estilo: StringName = plano["estilo"]
	var morador: StringName = plano.get("morador", &"familia")
	var ornada := (estilo == &"colonial" or estilo == &"ecletico") and tipo == &"casa"
	var eixo: Vector3 = face["eixo"]
	var fora := eixo * sentido
	var dir := FundosBuilder._direcao_de(fora)
	var normal_face := KitModular._normal(int(face["direcao"]))
	var prof := ChunkBuilder.PROF_PREDIO
	var avanco := ChunkBuilder.AVANCO_FACHADA
	var largura := prof + avanco
	var meia := largura * 0.5
	# A massa vai do plano da fachada (avanco a frente da linha da quadra) ate o
	# fundo: a parede cobre a face inteira, quina com quina.
	var s_meio := (prof - avanco) * 0.5
	var base := FundosBuilder._ponto(face, t, s_meio)
	var lat := KitModular._lateral(dir)
	var giro := atan2(fora.x, fora.z)
	# De que ponta da parede fica a rua da frente, em `lat`.
	var rua := signf(normal_face.dot(lat))
	var altura := float(andares) * ANDAR
	var cor: Color = plano["cor"]
	var cercadura: Color = plano.get("cercadura", cor)
	var casa: Dictionary = info.get("casa", {})
	var faixas: Array = info.get("faixas", [])
	var estilo_janela := estilo
	var med := FachadaViva._medidas(
		&"ecletico" if tipo == &"sobrado" else (&"moderno" if tipo != &"casa" else estilo), rng)
	var w_janela: float = med["w_janela"]
	var h_janela: float = med["h_janela"]
	var topo: float = med["topo"]
	if tipo == &"loja" or tipo == &"predio":
		# Como a ComercioVivo desenha os andares de cima.
		h_janela = 1.3
		topo = 2.4
		w_janela = rng.randf_range(1.2, 1.6)
	var prof_vao := JanelaViva.profundidade(estilo)
	var arco := 0.16 if bool(plano.get("arco", false)) else 0.0

	# A calcada da rua transversal sobe contra esta parede: 69 janelas de lateral
	# tinham o peitoril abaixo dela (levantamento da esquina).
	var terreno := is_finite(dy)
	var chao := func(s: float) -> float:
		if not terreno:
			return 0.0
		return Relevo.local(cx, cz, FundosBuilder._ponto(face, t, s) + fora * 0.7) - dy

	var vaos: Array = []
	var estados: Array = []
	var s_janelas: Array[float] = [prof * 0.27, prof * 0.7]
	var nome_na_parede := false
	for andar in andares:
		var y_andar := float(andar) * ANDAR
		for k in s_janelas.size():
			var x := rua * (s_meio - s_janelas[k])
			var g: float = chao.call(s_janelas[k])
			if andar == 0 and g > 1.6:
				# A calcada da transversal passou da altura do peitoril: dali para
				# baixo a lateral e embasamento, e quem abre vao nela e a F5.
				continue
			if andar == 0 and tipo != &"casa" and tipo != &"predio":
				if k == 0:
					if rng.randf() < 0.5 and absf(g) < 0.35:
						# A loja da esquina abre para as duas ruas. Baixa de proposito:
						# o nome em cima dela nao pode encostar no friso do andar.
						vaos.append({"rect": Rect2(x - 1.2, KitModular.ALTURA_MEIO_FIO, 2.4, 2.05),
							"prof": 0.24, "tipo": &"porta_aco", "indice": estados.size()})
						estados.append({"tipo": &"enrolar", "estado": 0, "acesa": false,
							"semente": int(info.get("nome_loja", rng.randi())),
							"cor": ComercioVivo.CORES_LOJA[
								rng.randi() % ComercioVivo.CORES_LOJA.size()]})
					else:
						# Parede cega do estoque, com o nome da loja pintado nela.
						nome_na_parede = true
					continue
				# O vitro alto do deposito, no fundo.
				var e_dep := _estado(&"deposito", rng, estilo_janela, morador, 0, false, casa)
				var m: Vector2 = VAOS[&"deposito"]
				vaos.append({"rect": Rect2(x - 0.75, maxf(m.x, g + 0.4), 1.5, m.y), "prof": 0.16,
					"tampa": true, "tipo": &"janela", "indice": estados.size()})
				estados.append(e_dep)
				continue
			if bool(plano.get("industria", false)) and tipo != &"oficina" and andar >= 1:
				# Galpao, deposito e armazem nao tem apartamento em cima: na lateral
				# corre o vitro alto, como na frente (IndustriaViva). So a oficina tem
				# a casa do dono no andar de cima.
				var e_v := _estado(&"deposito", rng, estilo_janela, morador, andar, false, casa)
				var m_v: Vector2 = VAOS[&"deposito"]
				vaos.append({"rect": Rect2(x - 0.9, y_andar + m_v.x, 1.8, m_v.y), "prof": 0.16,
					"tampa": true, "tipo": &"janela", "indice": estados.size()})
				estados.append(e_v)
				continue
			var y0 := y_andar + topo - h_janela
			if andar == 0:
				y0 = maxf(y0, g + 0.5)
				if y0 + h_janela > ANDAR - 0.15:
					continue
			var e := JanelaViva.sortear(rng, estilo_janela, morador, andar,
				rng.randf() < prob_acesa, casa)
			if int(e["abertura"]) == JanelaViva.Abertura.ABERTA:
				e["abertura"] = JanelaViva.Abertura.ENTREABERTA
			if ornada or tipo == &"sobrado":
				e["afasta_folha"] = 0.035
			vaos.append({"rect": Rect2(x - w_janela * 0.5, y0, w_janela, h_janela),
				"prof": prof_vao, "tampa": true, "tipo": &"janela", "arco": arco,
				"indice": estados.size()})
			estados.append(e)
	var quadros := ParedeVazada.erguer(sup, plano.get("material", &"reboco"), base, largura,
		altura, dir, cor, vaos, faixas, ParedeVazada.desgaste_de(plano, &"lateral"))

	for q: Dictionary in quadros:
		var e: Dictionary = estados[int(q["indice"])]
		if q["tipo"] == &"porta_aco":
			ComercioVivo._loja(ob, q, e, rng)
			# A placa e da loja (atlas de lojas); o galpao nao poe placa na porta
			# lateral. Sem loja na frente (LojaViva: o terreo comercial nao abre
			# loja de casca), a porta de aco e da garagem, e nao leva placa.
			if not bool(plano.get("marquise", false)) and not plano.has("industria") \
					and (info.has("nome_loja") or not LojaViva.ativo):
				ComercioVivo._placa(ob, q, e)
			continue
		JanelaViva.preencher_em(ob, q, e, FachadaViva._espaco_dos_lados(q["rect"], quadros))
		if ornada or tipo == &"sobrado":
			FachadaViva._cercadura(ob, q, cercadura, estilo == &"ecletico" or tipo == &"sobrado")

	if nome_na_parede and plano.has("industria"):
		# O nome da FIRMA, do atlas da rua de servico, e nao o de uma loja.
		var w_i := minf(largura * 0.55, 4.0)
		IndustriaViva.nome_pintado(ob, base + lat * (rua * (s_meio - prof * 0.27)) + fora * 0.012
			+ Vector3(0.0, 1.75, 0.0), Vector2(w_i, w_i * 0.25), giro, int(plano["nome"]), rng)
	elif nome_na_parede and (info.has("nome_loja") or not LojaViva.ativo):
		var w_nome := minf(largura * 0.5, 3.6)
		ComercioVivo._nome(ob, base + lat * (rua * (s_meio - prof * 0.27)) + fora * 0.012
			+ Vector3(0.0, 1.75, 0.0), Vector2(w_nome, w_nome * 0.25), giro,
			{"semente": int(info.get("nome_loja", rng.randi())),
				"cor": ComercioVivo.CORES_LOJA[rng.randi() % ComercioVivo.CORES_LOJA.size()]})
	if morador == &"abandonada" and andares >= 1:
		ob.placa(&"pichacao", base + lat * (rua * (s_meio - prof * 0.5)) + fora * 0.015
			+ Vector3(0.0, 1.1, 0.0), Vector2(1.6, 0.8), giro)

	# --- molduras que dobram a quina ------------------------------------------------
	# Cada moldura horizontal da frente continua pela lateral, e passa `sai` alem
	# da quina da rua: sem isso o friso da fachada acabava num degrau solto no ar.
	var sai_friso := 0.12 if tipo != &"casa" else 0.1
	var cor_friso := cercadura if (ornada or tipo == &"sobrado") else cor.darkened(0.12)
	for andar in range(1, andares):
		_moldura(ob, base, lat, fora, giro, rua, meia, float(andar) * ANDAR, sai_friso,
			sai_friso, cor_friso)
	if tipo == &"casa":
		if ornada or estilo == &"moderno":
			_moldura(ob, base, lat, fora, giro, rua, meia, altura - 0.12, 0.16, 0.12,
				cercadura if ornada else cor.darkened(0.1))
			_moldura(ob, base, lat, fora, giro, rua, meia, altura - 0.02, 0.08, 0.2,
				cercadura.darkened(0.05) if ornada else cor.darkened(0.15))
	else:
		_moldura(ob, base, lat, fora, giro, rua, meia, altura - 0.05, 0.14, 0.16,
			cercadura if tipo == &"sobrado" else cor.darkened(0.1))
	# Cunhal: a pilastra da quina, que encontra a da fachada.
	if ornada or tipo == &"sobrado":
		var h_c := altura
		if tipo == &"sobrado":
			h_c += 1.0 if plano.get("remate", &"") == &"platibanda" else 0.5
		const W_CUNHAL := 0.36
		ob.caixa(&"reboco", base + lat * (rua * (meia + 0.06 - W_CUNHAL * 0.5)) + fora * 0.03
			+ Vector3(0.0, h_c * 0.5, 0.0), Vector3(W_CUNHAL, h_c, 0.06), cercadura, giro)
	ob.despejar(sup)


## Moldura horizontal ao longo da lateral, de `alto` por `sai`, estendida `sai`
## alem da quina da rua e parando um centimetro antes da de tras (la ela ficaria
## no mesmo plano da parede de tras).
static func _moldura(ob: Obra, base: Vector3, lat: Vector3, fora: Vector3, giro: float,
		rua: float, meia: float, y: float, alto: float, sai: float, cor: Color) -> void:
	var comp := meia * 2.0 + sai - 0.01
	ob.caixa(&"reboco", base + lat * (rua * (sai + 0.01) * 0.5) + fora * (sai * 0.5)
		+ Vector3(0.0, y, 0.0), Vector3(comp, alto, sai), cor, giro)


# --- quintal -------------------------------------------------------------------------

## O quintal de um lote, no lugar de FundosBuilder._quintal quando o lote tem
## plano. [a, b] ao longo da face, `q` de fundura, `lote` o de `_fileira` (com
## "plano" e "porta_fundo").
##
## Primeiro o que encosta na parede de tras (puxadinho ou telheiro, fora da
## porta da cozinha), depois o tanque (debaixo do telheiro, quando ha), depois o
## resto: varal, churrasqueira, casinha de cachorro, mesa de plastico, vaso,
## horta, a mangueira.
static func quintal(sup: Dictionary, face: Dictionary, a: float, b: float, q: float,
		casa: bool, lote: Dictionary, rng: RandomNumberGenerator) -> void:
	var ob := Obra.new()
	var prof := ChunkBuilder.PROF_PREDIO
	var direcao := int(face["direcao"])
	var normal := KitModular._normal(direcao)
	var fora := -normal
	var giro_q := atan2(fora.x, fora.z)
	var giro_casa := giro_q + PI
	var w := b - a
	var plano: Dictionary = lote.get("plano", {})
	var morador: StringName = plano.get("morador", &"familia")

	# Cimentado junto da casa: o piso da area de servico. O resto e terra.
	var p0 := FundosBuilder._ponto(face, a, prof)
	var p1 := FundosBuilder._ponto(face, b, prof + minf(2.2, q * 0.5))
	KitModular.chao(sup, &"concreto", Vector3(minf(p0.x, p1.x), 0.04, minf(p0.z, p1.z)),
		Vector2(absf(p1.x - p0.x), absf(p1.z - p0.z)), 4.0, Color(0.62, 0.61, 0.58))

	# O que encosta na parede de tras nao pode tampar a porta da cozinha.
	var ocupado: Array[Vector2] = []
	if lote.has("porta_fundo"):
		var t_porta := (Vector3(lote["porta_fundo"]) - Vector3(face["canto"])).dot(
			Vector3(face["eixo"]))
		ocupado.append(Vector2(t_porta - 1.15, t_porta + 1.15))

	var sobra := q
	var coberto := Vector2(NAN, NAN)
	if casa and q >= 4.0 and w >= 4.0:
		var sorte := rng.randf()
		var fundura := minf(3.2, q - 1.4)
		var trecho := _trecho_livre(ocupado, a + 0.05, b - 0.05, 2.6)
		if sorte < 0.62 and trecho.y - trecho.x >= 2.6:
			var largura := minf(trecho.y - trecho.x, w * rng.randf_range(0.45, 0.75))
			var t0 := rng.randf_range(trecho.x, trecho.y - largura)
			if sorte < 0.4:
				_puxadinho(sup, ob, face, t0, t0 + largura, fundura, plano, rng)
				sobra = q - fundura
			else:
				_telheiro(ob, face, t0, t0 + largura, minf(fundura, 2.6), plano, rng)
				coberto = Vector2(t0, t0 + largura)
			ocupado.append(Vector2(t0 - 0.1, t0 + largura + 0.1))

	# Tanque de lavar, encostado na parede de tras: debaixo do telheiro, quando ha.
	var t_tanque := NAN
	if is_finite(coberto.x):
		t_tanque = coberto.x + 0.5
	else:
		var livre := _trecho_livre(ocupado, a + 0.4, b - 0.4, 0.8)
		if livre.y - livre.x >= 0.8:
			t_tanque = rng.randf_range(livre.x + 0.4, livre.y - 0.4)
	if is_finite(t_tanque):
		_tanque(ob, FundosBuilder._ponto(face, t_tanque, prof + 0.32), giro_casa)
		if casa and (is_finite(coberto.x) and rng.randf() < 0.75 or rng.randf() < 0.2):
			var t_maq := t_tanque + (0.72 if t_tanque + 0.72 < b - 0.4 else -0.72)
			_maquina_de_lavar(ob, FundosBuilder._ponto(face, t_maq, prof + 0.34), giro_casa)

	if casa:
		# Varal de fio entre dois pontaletes, com a roupa balancando.
		if sobra >= 2.0 and w >= 3.0 and rng.randf() < 0.6:
			_varal(sup, ob, face, a + 0.5, b - 0.5, prof + q - minf(1.2, sobra * 0.4), normal,
				rng)
		var fundo_q := prof + q
		if q >= 5.0 and w >= 4.0 and rng.randf() < 0.16:
			# Churrasqueira de tijolo contra o muro do fundo: a chamine passa do
			# muro e se ve da rua de tras.
			_churrasqueira(ob, FundosBuilder._ponto(face, a + w * rng.randf_range(0.25, 0.75),
				fundo_q - 0.5), giro_casa)
		if q >= 3.0 and rng.randf() < 0.18:
			var t_cao := a + 0.6 if rng.randf() < 0.5 else b - 0.6
			_casinha_de_cachorro(ob, FundosBuilder._ponto(face, t_cao, fundo_q - 0.55),
				giro_casa + rng.randf_range(-0.4, 0.4), rng)
		if rng.randf() < 0.12 and sobra >= 2.6:
			_mesa_de_plastico(ob, FundosBuilder._ponto(face, a + w * rng.randf_range(0.3, 0.7),
				prof + minf(sobra - 1.2, 2.4)), rng.randf() * TAU, rng)
		if morador == &"zelosa" or morador == &"idoso" or rng.randf() < 0.2:
			_vasos_no_muro(ob, face, a, b, fundo_q, giro_casa, rng)
		if q >= 5.0 and (morador == &"idoso" or morador == &"familia") and rng.randf() < 0.3:
			_horta(ob, FundosBuilder._ponto(face, a + w * rng.randf_range(0.3, 0.7),
				fundo_q - 1.3), giro_q, rng)
		# A mangueira que aparece por cima do telhado da casa terrea.
		if Vegetacao.ativo:
			_verde(sup, ob, face, a, b, q, fundo_q, rng)
		elif q >= 6.0 and w >= 5.0 and rng.randf() < 0.22:
			var arvore_rng := RandomNumberGenerator.new()
			arvore_rng.seed = rng.randi()
			var descartavel: Array[Dictionary] = []
			KitParque.arvore(sup, descartavel, FundosBuilder._ponto(face,
				a + w * rng.randf_range(0.35, 0.65), fundo_q - 2.2), rng.randf_range(0.0, 0.35),
				arvore_rng)
	else:
		# Fundo de comercio: tambor, engradado de garrafa, estrado.
		for k in rng.randi_range(1, 3):
			var t := a + rng.randf_range(0.6, maxf(0.7, w - 0.6))
			var s := prof + rng.randf_range(0.8, maxf(0.9, q - 0.6))
			ob.cilindro(JanelaViva._p(&"metal_enferrujado"), FundosBuilder._ponto(face, t, s), 0.29, 0.88,
				Color.WHITE.lerp(Color("5a6e7a"), rng.randf_range(0.0, 0.6)), 10)
		if rng.randf() < 0.6:
			_engradados(ob, FundosBuilder._ponto(face, a + w * rng.randf_range(0.2, 0.8),
				prof + minf(q - 0.6, rng.randf_range(1.0, 2.5))), giro_q + rng.randf_range(-0.3, 0.3),
				rng)
		ob.caixa(&"tabua", FundosBuilder._ponto(face, a + w * 0.5, prof + q - 0.9)
			+ Vector3(0.0, 0.07, 0.0), Vector3(1.2, 0.14, 1.0), Color(0.72, 0.62, 0.5),
			giro_q)
	ob.despejar(sup)


## O verde do quintal (Vegetacao): e o que faz a cidade vista do alto ser meio
## copa, como a de verdade. A arvore de fruta no fundo, que passa do telhado da
## casa terrea; no quintal estreito, o coqueiro; a touceira de bananeira no
## canto; e a primavera debrucada no muro do fundo, vista da rua de tras.
static func _verde(sup: Dictionary, ob: Obra, face: Dictionary, a: float, b: float,
		q: float, fundo_q: float, rng: RandomNumberGenerator) -> void:
	var w := b - a
	var planta_rng := RandomNumberGenerator.new()
	planta_rng.seed = rng.randi()
	var descartavel: Array[Dictionary] = []
	var t_arvore := NAN
	if q >= 4.5 and w >= 3.6 and planta_rng.randf() < 0.55:
		t_arvore = a + w * planta_rng.randf_range(0.3, 0.7)
		var pe := FundosBuilder._ponto(face, t_arvore, fundo_q - minf(2.2, q * 0.35))
		if w < 5.0 and planta_rng.randf() < 0.5:
			Vegetacao.palmeira(sup, descartavel, pe, false, planta_rng)
		else:
			Vegetacao.arvore(sup, descartavel, pe, Vegetacao.especie_de_quintal(planta_rng),
				planta_rng.randf_range(0.0, 0.6), planta_rng)
	if q >= 3.5 and planta_rng.randf() < 0.3:
		# Longe da arvore: a bananeira no canto oposto.
		var t := a + 1.0 if not is_finite(t_arvore) or t_arvore > a + w * 0.5 else b - 1.0
		Vegetacao.bananeira(sup, FundosBuilder._ponto(face, t, fundo_q - 1.0), planta_rng)
	if planta_rng.randf() < 0.22:
		var t := a + w * planta_rng.randf_range(0.2, 0.8)
		Vegetacao.arbusto(ob, FundosBuilder._ponto(face, t, fundo_q - 0.5)
			+ Vector3(0.0, 1.1, 0.0), planta_rng.randf_range(1.8, 2.6),
			Vegetacao.C_PRIMAVERA, planta_rng)


## O maior trecho de [de, ate] fora dos intervalos ocupados (e pelo menos `minimo`
## de comprido, se houver). Devolve Vector2(de, de) quando nao sobra nada.
static func _trecho_livre(ocupado: Array[Vector2], de: float, ate: float,
		minimo: float) -> Vector2:
	var cortes := ocupado.duplicate()
	cortes.sort()
	var melhor := Vector2(de, de)
	var cursor := de
	for c: Vector2 in cortes:
		if c.x > cursor and minf(c.x, ate) - cursor > melhor.y - melhor.x:
			melhor = Vector2(cursor, minf(c.x, ate))
		cursor = maxf(cursor, c.y)
	if ate - cursor > melhor.y - melhor.x:
		melhor = Vector2(cursor, ate)
	if melhor.y - melhor.x < minimo:
		return Vector2(de, de)
	return melhor


## A altura da parede e o caimento do que encosta na parede de tras (puxadinho,
## telheiro), para caber debaixo da ponta do beiral da casa: o telhado do
## TelhadoVivo sai 42 a 70 cm e desce com a agua, e na casa terrea a meia-agua de
## 3,05 m passava por cima dele. Como no puxado de verdade, ela entra por baixo.
## Na ladeira o quintal segue o chao e a casa e rigida: aqui so vale o plano.
static func _cabe_no_quintal(plano: Dictionary) -> Vector2:
	var alto := ALTO_PUXADINHO
	var cai := CAIMENTO
	var beiral := TelhadoVivo.beiral_de_tras(plano)
	if not beiral.is_empty():
		var teto := float(beiral["y"]) - 0.08
		if alto + 0.05 + cai > teto:
			alto = maxf(2.2, teto - 0.05 - cai)
			cai = maxf(0.12, teto - 0.05 - alto)
	return Vector2(alto, cai)


## Comodo de fundo de um pavimento, colado na parede de tras, com meia-agua caindo
## para o quintal. Tijolo aparente na casa popular (e em um terco das outras),
## porta e vitro de verdade na parede da frente.
static func _puxadinho(sup: Dictionary, ob: Obra, face: Dictionary, t0: float, t1: float,
		fundura: float, plano: Dictionary, rng: RandomNumberGenerator) -> void:
	var prof := ChunkBuilder.PROF_PREDIO
	var direcao := int(face["direcao"])
	var normal := KitModular._normal(direcao)
	var fora := -normal
	var dir_q := posmod(direcao + 2, 4)
	var giro := atan2(fora.x, fora.z)
	var lat := KitModular._lateral(dir_q)
	var larg := t1 - t0
	var estilo: StringName = plano.get("estilo", &"popular")
	var mat: StringName = &"reboco"
	var cor := Color("d9d2c2").lerp(Color("c8b8a0"), rng.randf())
	var sorte := rng.randf()
	if estilo == &"popular" or sorte < 0.3:
		mat = &"tijolo"
		cor = Color.WHITE
	elif sorte < 0.6:
		cor = (plano.get("cor_corpo", cor) as Color).lightened(0.04)
	var cabe := _cabe_no_quintal(plano)
	var alto := cabe.x
	var cai := cabe.y
	var meio := FundosBuilder._ponto(face, (t0 + t1) * 0.5, prof + fundura * 0.5)
	# As duas paredes do lado. A de tras e a parede da casa; a da frente, a
	# ParedeVazada com a porta e o vitro.
	ob.caixa(mat, meio + Vector3(0.0, alto * 0.5, 0.0), Vector3(larg, alto, fundura), cor,
		giro, PSXMesh.FACE_DIR | PSXMesh.FACE_ESQ)
	# O oitao de cada lado, do topo da parede ate a linha da meia-agua.
	for lado: float in [-1.0, 1.0]:
		var ponta := meio + lat * (lado * larg * 0.5)
		var perto := ponta - fora * (fundura * 0.5)
		var longe := ponta + fora * (fundura * 0.5)
		var n := lat * lado
		ob.triangulo(mat, perto + Vector3(0.0, alto, 0.0), longe + Vector3(0.0, alto, 0.0),
			perto + Vector3(0.0, alto + 0.05 + cai, 0.0), n, cor)
		ob.triangulo(mat, longe + Vector3(0.0, alto, 0.0), longe + Vector3(0.0, alto + 0.05, 0.0),
			perto + Vector3(0.0, alto + 0.05 + cai, 0.0), n, cor)

	# A parede da frente: porta num lado, vitro no outro.
	var frente := FundosBuilder._ponto(face, (t0 + t1) * 0.5, prof + fundura)
	var meia := larg * 0.5
	var lado_porta := -1.0 if rng.randf() < 0.5 else 1.0
	var x_porta := lado_porta * maxf(0.0, meia - 0.55)
	var vaos: Array = [{"rect": Rect2(x_porta - 0.38, 0.06, 0.76, 2.0), "prof": 0.14,
		"tipo": &"porta", "indice": 0}]
	var e := _estado(&"banheiro" if rng.randf() < 0.5 else &"cozinha", rng, estilo,
		plano.get("morador", &"familia"), 0, false, {})
	e["abertura"] = JanelaViva.Abertura.FECHADA
	e["vasos"] = 0
	if larg >= 2.4:
		var x_j := -lado_porta * maxf(0.0, meia - 0.7)
		vaos.append({"rect": Rect2(x_j - 0.45, 1.25, 0.9, 0.7), "prof": 0.14, "tampa": true,
			"tipo": &"janela", "indice": 1})
	var quadros := ParedeVazada.erguer(sup, mat, frente, larg, alto + 0.05, dir_q, cor, vaos)
	for q: Dictionary in quadros:
		if q["tipo"] == &"porta":
			var v := JanelaViva._vao(q)
			if rng.randf() < 0.5:
				_porta_de_tabua(ob, v, v.prof - 0.04, {}, rng)
			else:
				_porta_de_ferro(ob, v, v.prof - 0.04, rng)
		else:
			JanelaViva.preencher_em(ob, q, e)
	_meia_agua(ob, face, t0, t1, fundura, alto, rng, cai)


## Area de servico coberta: dois pilares na frente e a meia-agua. Debaixo, o
## tanque e a maquina de lavar (FundosVivos.quintal).
static func _telheiro(ob: Obra, face: Dictionary, t0: float, t1: float, fundura: float,
		plano: Dictionary, rng: RandomNumberGenerator) -> void:
	var prof := ChunkBuilder.PROF_PREDIO
	var direcao := int(face["direcao"])
	var fora := -KitModular._normal(direcao)
	var giro := atan2(fora.x, fora.z)
	var estilo: StringName = plano.get("estilo", &"popular")
	var cabe := _cabe_no_quintal(plano)
	var alto := cabe.x
	var s_pilar := prof + fundura - 0.14
	var tijolo := estilo == &"popular" or rng.randf() < 0.3
	for t: float in [t0 + 0.14, t1 - 0.14]:
		var p := FundosBuilder._ponto(face, t, s_pilar)
		if tijolo:
			ob.caixa(&"tijolo", p + Vector3(0.0, alto * 0.5, 0.0), Vector3(0.26, alto, 0.26),
				Color.WHITE, giro)
		else:
			ob.caixa(&"tabua", p + Vector3(0.0, alto * 0.5, 0.0), Vector3(0.12, alto, 0.12),
				Color("6a4a30"), giro)
	# A viga da frente, onde a telha apoia.
	ob.caixa(&"tabua", FundosBuilder._ponto(face, (t0 + t1) * 0.5, s_pilar)
		+ Vector3(0.0, alto - 0.06, 0.0), Vector3(t1 - t0, 0.12, 0.12), Color("5a4430"), giro)
	_meia_agua(ob, face, t0, t1, fundura, alto, rng, cabe.y)


## A meia-agua de fibrocimento ou de telha de barro, da parede da casa ate 35 cm
## alem da frente. A onda do fibrocimento corre morro abaixo: a textura tem o
## gomo ao longo de u, entao o u da chapa vai no sentido do caimento.
static func _meia_agua(ob: Obra, face: Dictionary, t0: float, t1: float, fundura: float,
		alto: float, rng: RandomNumberGenerator, caimento: float = CAIMENTO) -> void:
	var prof := ChunkBuilder.PROF_PREDIO
	var direcao := int(face["direcao"])
	var fora := -KitModular._normal(direcao)
	const SAI := 0.35
	var th := atan2(caimento, fundura)
	var comp_h := fundura + SAI + 0.02
	var s_centro := prof - 0.02 + comp_h * 0.5
	# Altura da face de baixo da chapa na metade do caminho.
	var y_centro := alto + 0.05 + caimento * (prof + fundura - s_centro) / fundura + 0.02
	var centro := FundosBuilder._ponto(face, (t0 + t1) * 0.5, s_centro) + Vector3(0.0, y_centro, 0.0)
	var larg := t1 - t0 + 0.2
	if rng.randf() < 0.65:
		var desce := (fora * cos(th) + Vector3.DOWN * sin(th)).normalized()
		var cima := (fora * sin(th) + Vector3.UP * cos(th)).normalized()
		var tom := Color("c9c5ba").darkened(rng.randf_range(0.0, 0.22))
		if rng.randf() < 0.3:
			# Limo: o fibrocimento velho esverdeia.
			tom = tom.lerp(Color("8f9a7a"), 0.35)
		ob.livre(&"metal_ondulado", centro, Vector3(comp_h / cos(th), 0.03, larg),
			Basis(desce, cima, desce.cross(cima)), tom)
	else:
		var giro := atan2(fora.x, fora.z)
		ob.livre(&"telha", centro, Vector3(larg, 0.06, comp_h / cos(th)),
			Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, th),
			Color.WHITE.lerp(Color("9a7a66"), rng.randf_range(0.0, 0.6)))


## Tanque de lavar roupa de cimento, com a torneira na parede.
static func _tanque(ob: Obra, pe: Vector3, giro: float) -> void:
	ob.caixa(&"concreto", pe + Vector3(0.0, 0.42, 0.0), Vector3(0.6, 0.84, 0.55),
		Color(0.78, 0.77, 0.74), giro)
	# A bacia funda em cima: a borda mais clara e o fundo escuro.
	ob.caixa(JanelaViva._p(&"concreto"), pe + Vector3(0.0, 0.845, 0.0),
		Vector3(0.5, 0.01, 0.42), Color(0.35, 0.35, 0.34), giro)
	var b := Basis(Vector3.UP, giro)
	ob.caixa(JanelaViva._p(&"metal"), pe + b * Vector3(0.0, 1.12, 0.3),
		Vector3(0.04, 0.04, 0.14), Color("c8c8c0"), giro)


## Maquina de lavar branca, com a tampa e o painel.
static func _maquina_de_lavar(ob: Obra, pe: Vector3, giro: float) -> void:
	ob.caixa(&"metal_pintado", pe + Vector3(0.0, 0.46, 0.0), Vector3(0.6, 0.92, 0.6),
		Color("eeeeea"), giro)
	var b := Basis(Vector3.UP, giro)
	ob.caixa(JanelaViva._p(&"metal_pintado"), pe + b * Vector3(0.0, 0.93, -0.04),
		Vector3(0.5, 0.02, 0.44), Color("d8dadc"), giro)
	ob.caixa(JanelaViva._p(&"metal_pintado"), pe + b * Vector3(0.0, 1.0, 0.24),
		Vector3(0.58, 0.14, 0.1), Color("c8ccd0"), giro)


## Varal de fio entre dois pontaletes, com a roupa pendurada e balancando.
static func _varal(sup: Dictionary, ob: Obra, face: Dictionary, ta: float, tb: float,
		s: float, normal: Vector3, rng: RandomNumberGenerator) -> void:
	for t: float in [ta, tb]:
		ob.caixa(&"metal", FundosBuilder._ponto(face, t, s) + Vector3(0.0, 0.95, 0.0),
			Vector3(0.06, 1.9, 0.06), Color("6e6a62"))
	KitModular.cabo(sup, FundosBuilder._ponto(face, ta, s) + Vector3(0.0, 1.8, 0.0),
		FundosBuilder._ponto(face, tb, s) + Vector3(0.0, 1.8, 0.0))
	var pecas := rng.randi_range(2, mini(6, int((tb - ta) / 0.8)))
	var giro := atan2(normal.x, normal.z)
	for k in pecas:
		var t := ta + (tb - ta) * (float(k) + 0.5) / float(pecas) + rng.randf_range(-0.15, 0.15)
		var tam := Vector2(rng.randf_range(0.45, 0.8), rng.randf_range(0.45, 0.85))
		var c: Color = FundosBuilder.ROUPAS[rng.randi() % FundosBuilder.ROUPAS.size()]
		var centro := FundosBuilder._ponto(face, t, s) + Vector3(0.0, 1.79 - tam.y * 0.5, 0.0)
		# Dupla face: a roupa e vista dos dois quintais. Presa em cima, solta embaixo.
		for lado: float in [0.0, PI]:
			ob.cartao(&"cortina", tam, Transform3D(Basis(Vector3.UP, giro + lado), centro),
				Rect2(0.0, 0.0, tam.x * 0.8, tam.y * 0.8), c, 2)


## Churrasqueira de tijolo: base, bancada, a boca escura, a coifa e a chamine.
static func _churrasqueira(ob: Obra, pe: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	ob.caixa(&"tijolo", pe + Vector3(0.0, 0.45, 0.0), Vector3(1.2, 0.9, 0.7), Color.WHITE, giro)
	ob.caixa(&"concreto", pe + Vector3(0.0, 0.93, 0.0), Vector3(1.3, 0.06, 0.78),
		Color("c8c2b6"), giro)
	ob.caixa(&"tijolo", pe + Vector3(0.0, 1.24, 0.0), Vector3(1.2, 0.56, 0.7), Color.WHITE, giro)
	ob.placa(&"janela_apagada", pe + b * Vector3(0.0, 1.2, 0.352), Vector2(0.9, 0.4), giro)
	ob.caixa(&"tijolo", pe + b * Vector3(0.0, 1.68, -0.05), Vector3(1.0, 0.32, 0.55),
		Color.WHITE.darkened(0.06), giro)
	ob.caixa(&"tijolo", pe + b * Vector3(0.0, 2.45, -0.1), Vector3(0.36, 1.25, 0.36),
		Color.WHITE.darkened(0.12), giro)
	ob.caixa(&"concreto", pe + b * Vector3(0.0, 3.1, -0.1), Vector3(0.46, 0.06, 0.46),
		Color("8a8680"), giro)


## Casinha de cachorro de tabua pintada, com o telhadinho de duas aguas.
static func _casinha_de_cachorro(ob: Obra, pe: Vector3, giro: float,
		rng: RandomNumberGenerator) -> void:
	var b := Basis(Vector3.UP, giro)
	var cor: Color = [Color("8a6a48"), Color("b8452e"), Color("3f6a8a"), Color("d8c8a0")][
		rng.randi() % 4]
	ob.caixa(JanelaViva._p(&"tabua"), pe + Vector3(0.0, 0.3, 0.0), Vector3(0.62, 0.6, 0.8),
		cor, giro)
	for lado: float in [-1.0, 1.0]:
		ob.livre(JanelaViva._p(&"tabua"), pe + b * Vector3(lado * 0.17, 0.72, 0.0),
			Vector3(0.4, 0.04, 0.9), b * Basis(Vector3.BACK, -lado * 0.62), cor.darkened(0.3))
	for z: float in [-0.4, 0.4]:
		ob.triangulo(JanelaViva._p(&"tabua"), pe + b * Vector3(-0.31, 0.6, z),
			pe + b * Vector3(0.31, 0.6, z), pe + b * Vector3(0.0, 0.83, z), b * Vector3(0, 0, signf(z)),
			cor)
	ob.placa(JanelaViva._p(&"janela_apagada"), pe + b * Vector3(0.0, 0.24, 0.402),
		Vector2(0.3, 0.36), giro)


## Mesa de plastico branca com duas a quatro cadeiras: o almoco de domingo.
static func _mesa_de_plastico(ob: Obra, centro: Vector3, giro: float,
		rng: RandomNumberGenerator) -> void:
	var branco := Color("eeeeea")
	var mat := JanelaViva._p(&"metal_pintado")
	var b := Basis(Vector3.UP, giro)
	ob.caixa(mat, centro + Vector3(0.0, 0.72, 0.0), Vector3(0.8, 0.04, 0.8), branco, giro)
	for dx: float in [-0.34, 0.34]:
		for dz: float in [-0.34, 0.34]:
			ob.caixa(mat, centro + b * Vector3(dx, 0.35, dz), Vector3(0.04, 0.7, 0.04), branco,
				giro)
	var n := rng.randi_range(2, 4)
	for k in n:
		var ang := giro + TAU * float(k) / n + rng.randf_range(-0.2, 0.2)
		var bc := Basis(Vector3.UP, ang)
		var p := centro + bc * Vector3(0.0, 0.0, 0.62)
		ob.caixa(mat, p + Vector3(0.0, 0.43, 0.0), Vector3(0.44, 0.04, 0.42), branco, ang)
		ob.livre(mat, p + bc * Vector3(0.0, 0.68, 0.22), Vector3(0.44, 0.44, 0.03),
			bc * Basis(Vector3.RIGHT, 0.15), branco)
		for dx: float in [-0.19, 0.19]:
			ob.placa(mat, p + bc * Vector3(dx, 0.21, 0.0), Vector2(0.03, 0.42), ang + PI * 0.5,
				branco)


## Vasos de barro e lata de planta encostados no muro do fundo.
static func _vasos_no_muro(ob: Obra, face: Dictionary, a: float, b: float, s_muro: float,
		giro: float, rng: RandomNumberGenerator) -> void:
	var n := rng.randi_range(3, 6)
	for k in n:
		var t := a + 0.4 + (b - a - 0.8) * rng.randf()
		var pe := FundosBuilder._ponto(face, t, s_muro - 0.28)
		var alto := rng.randf_range(0.25, 0.45)
		var lata := rng.randf() < 0.35
		ob.caixa(JanelaViva._p(&"metal" if lata else &"reboco"), pe + Vector3(0.0, alto * 0.5, 0.0),
			Vector3(0.28, alto, 0.28), Color("9a9a90") if lata else JanelaViva.TERRACOTA.darkened(
				rng.randf_range(0.0, 0.25)), giro)
		for f in 2:
			var tt := Transform3D(Basis(Vector3.UP, giro + f * PI * 0.5 + rng.randf()),
				pe + Vector3(0.0, alto + 0.3, 0.0))
			JanelaViva.folhagem(ob, Vector2(0.55, 0.6), tt, Color(0.6, 0.85, 0.5))


## Canteiro de horta: a terra fofa em leira e as mudas em fila.
static func _horta(ob: Obra, centro: Vector3, giro: float, rng: RandomNumberGenerator) -> void:
	var b := Basis(Vector3.UP, giro)
	ob.caixa(&"terra", centro + Vector3(0.0, 0.08, 0.0), Vector3(2.0, 0.16, 1.0),
		Color(0.45, 0.34, 0.26), giro)
	for fila in 3:
		for k in 5:
			var p := centro + b * Vector3(-0.8 + k * 0.4, 0.3, -0.3 + fila * 0.3)
			var tt := Transform3D(Basis(Vector3.UP, rng.randf() * PI), p)
			JanelaViva.folhagem(ob, Vector2(0.32, 0.3), tt, Color(0.55, 0.85, 0.4))


## Pilha de engradados de garrafa no fundo da loja.
static func _engradados(ob: Obra, pe: Vector3, giro: float, rng: RandomNumberGenerator) -> void:
	var b := Basis(Vector3.UP, giro)
	var colunas := rng.randi_range(1, 2)
	for c in colunas:
		var cor: Color = ENGRADADOS[rng.randi() % ENGRADADOS.size()]
		for k in rng.randi_range(2, 4):
			ob.caixa(JanelaViva._p(&"metal_pintado"), pe + b * Vector3(c * 0.52, 0.15 + k * 0.3, 0.0),
				Vector3(0.5, 0.29, 0.34), cor, giro)
