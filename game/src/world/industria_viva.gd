## A rua de servico e de industria: galpao, oficina, deposito, armazem, fabrica.
##
## Por que existe
## -------------
## O distrito INDUSTRIAL inteiro saia pelo caminho antigo (KitModular.fachada): 177
## de 177 lotes no raio de 12 chunks da praca, quase um quarto da frente construida
## da cidade. Era uma caixa de laje de concreto escuro de 3 a 12 m, com porta de
## aco em adesivo a cada 4 m, janela chapada, medidor e caixa d'agua pretos, e — o
## pior — a porta de entrar do apartamento escondida 5 mm atras da parede (o D1 de
## volta, em 19 chunks). Ver o levantamento em PLANO_CASAS_AAA.md.
##
## A rua de servico de cidade do interior de Minas tem outra cara, lote a lote:
##   galpao    pe-direito de 6 a 9 m, portao de correr de chapa, cobertura em arco
##             com a platibanda curva, ou duas aguas com o oitao para a rua, ou
##             shed; o nome da firma pintado na parede, a barra escura no pe;
##   oficina   o vao de 3 a 4 m aberto (mecanica, serralheria, marcenaria,
##             borracharia, funilaria, tornearia, vidracaria, motos), a bancada e
##             o pneu la dentro, e a casa do dono em cima;
##   deposito  o patio murado na frente com o portao gradeado, as baias de areia e
##             brita, a pilha de tijolo e o cimento no pallet;
##   armazem   de cafe ou cerealista, sobrado de tijolo com portas em arco e a
##             sacaria empilhada;
##   fabrica   a portaria, a fita de vitros basculantes e o nome no alto.
##
## Como entra na cidade
## --------------------
## ChunkBuilder._fileira chama `planejar` quando nem a FachadaViva nem a
## ComercioVivo planejam o lote (fora do comercial e da quadra de casas);
## `fachada` no lugar de KitModular.fachada, `coroar` no lugar de
## KitPredio.coroar, e `patio` no lote recuado do deposito. O fundo e a lateral de
## esquina saem pela FundosVivos, que reconhece o plano pela chave "industria".
## `--sem-fachada-viva` volta ao caminho antigo.
##
## Tudo aqui semeia o proprio rng a partir do plano: a firma sai a mesma a cada
## visita, e o rng do chunk nao anda.
class_name IndustriaViva
extends RefCounted

const ANDAR := KitModular.ALTURA_ANDAR
## Celula do atlas letreiros_industria.png por oficio: a ordem de NOMES_INDUSTRIA
## em tools/gerar_letreiros.py.
const CELULAS := {
	&"serralheria": 0, &"marcenaria": 1, &"mecanica": 2, &"borracharia": 3,
	&"funilaria": 4, &"deposito": 5, &"cerealista": 6, &"cafe": 7, &"laticinio": 8,
	&"tornearia": 9, &"vidracaria": 10, &"madeireira": 11, &"motos": 12, &"doce": 13,
	&"transportadora": 14, &"ceramica": 15,
}
const OFICIOS := {
	&"oficina": [&"mecanica", &"serralheria", &"marcenaria", &"borracharia", &"funilaria",
		&"tornearia", &"vidracaria", &"motos"],
	&"galpao": [&"laticinio", &"transportadora", &"ceramica", &"madeireira", &"cerealista"],
	&"deposito": [&"deposito", &"madeireira"],
	&"armazem": [&"cafe", &"cerealista"],
	&"fabrica": [&"doce", &"ceramica", &"laticinio"],
}
## Tinta de galpao: cinza, creme, o azul e o verde desbotados, ocre, branco, rosado.
const TINTAS: Array[Color] = [Color("cfcbc0"), Color("e6dcc2"), Color("9fb2bf"),
	Color("a9bba0"), Color("d9b777"), Color("eeebe4"), Color("c8a58a")]
## A barra escura no pe do galpao pintado: esconde o respingo e o encosto.
const BARRAS: Array[Color] = [Color("4a5560"), Color("5a3a30"), Color("3f5a48"),
	Color("6a6258"), Color("2f3a4a")]
## Chapa do portao de correr e da porta de enrolar pintada.
const CHAPAS: Array[Color] = [Color("3f5a78"), Color("6a7a6a"), Color("8a3a2e"),
	Color("c8c4b8"), Color("2f3336"), Color("d8b040")]
## Cor do letreiro pintado (o fundo claro da celula tingido).
const LETREIROS: Array[Color] = [Color("f4ecd0"), Color("f2f0ea"), Color("f0d890"),
	Color("dfe8ef"), Color("e8d8c8")]
## Pneu: borracha quase preta.
const BORRACHA := Color("262626")


## Decide o lote antes da massa. Vazio fora do distrito industrial.
static func planejar(rng: RandomNumberGenerator, quadra: Dictionary, largura: float,
		andares: int, tinta: Color) -> Dictionary:
	if int(quadra["distrito"]) != MalhaUrbana.Distrito.INDUSTRIAL or bool(quadra["casa"]):
		return {}
	var p := {"industria": true}
	var pesos := {&"galpao": 0.32, &"oficina": 0.28, &"deposito": 0.12, &"armazem": 0.14,
		&"fabrica": 0.14}
	if largura < 6.5:
		pesos[&"galpao"] = 0.06
		pesos[&"deposito"] = 0.0
		pesos[&"fabrica"] = 0.04
	var tipo := FachadaViva._sortear_peso(rng, pesos)
	p["tipo"] = tipo
	var oficios: Array = OFICIOS[tipo]
	var oficio: StringName = oficios[rng.randi() % oficios.size()]
	p["oficio"] = oficio
	p["nome"] = int(CELULAS[oficio])
	match tipo:
		&"galpao":
			andares = 3 if largura >= 11.0 and rng.randf() < 0.3 else 2
		&"oficina":
			andares = 2 if rng.randf() < 0.45 else 1
		&"deposito":
			andares = 1
		&"armazem":
			andares = 2
		_:
			andares = clampi(andares, 2, 3)
	p["andares"] = andares
	p["estilo"] = &"industria"

	var sorte := rng.randf()
	var tijolo := (tipo == &"armazem" and sorte < 0.7) or (tipo == &"fabrica" and sorte < 0.5) \
		or (tipo == &"galpao" and sorte < 0.22)
	var concreto := not tijolo and tipo == &"galpao" and sorte > 0.82
	if tijolo:
		p["material"] = &"tijolo"
		p["cor"] = Color.WHITE
		p["mat_corpo"] = &"tijolo"
		p["cor_corpo"] = Color.WHITE
	elif concreto:
		p["material"] = &"concreto"
		p["cor"] = Color("d8d4cc")
		p["mat_corpo"] = &"concreto"
		p["cor_corpo"] = Color("cbc7bf")
	else:
		var cor: Color = TINTAS[rng.randi() % TINTAS.size()]
		if rng.randf() < 0.3:
			cor = cor.lerp(tinta, 0.3)
		p["material"] = &"reboco"
		p["cor"] = cor
		p["mat_corpo"] = &"reboco"
		p["cor_corpo"] = cor.darkened(0.06)
		if rng.randf() < 0.7:
			p["barra"] = BARRAS[rng.randi() % BARRAS.size()]
	p["cercadura"] = Color("ece6d8")
	# O andar de cima da oficina e a casa do dono: tem gente, flor e cortina.
	p["morador"] = &"familia" if tipo == &"oficina" else &"fechada"

	var cobertura: StringName = &"laje"
	match tipo:
		&"galpao":
			cobertura = FachadaViva._sortear_peso(rng, {&"arco": 0.36, &"oitao": 0.3,
				&"shed": 0.18, &"laje": 0.16})
		&"oficina":
			if andares == 2 and rng.randf() < 0.4:
				cobertura = &"oitao"
		&"deposito":
			cobertura = &"oitao" if rng.randf() < 0.6 else &"arco"
		&"armazem":
			cobertura = &"oitao" if rng.randf() < 0.55 else &"laje"
		_:
			cobertura = &"shed" if rng.randf() < 0.45 else &"laje"
	p["cobertura"] = cobertura
	# FundosVivos le "remate" para a agua do fundo: laje tem buzinote.
	p["remate"] = &"platibanda" if cobertura == &"laje" or cobertura == &"shed" \
		else &"industria"
	p["recuo"] = rng.randf_range(3.6, 5.0) if tipo == &"deposito" else 0.0
	p["letreiro"] = tipo != &"galpao" or rng.randf() < 0.75
	p["semente"] = rng.randi()
	return p


## A frente do lote. Mesmo contrato de ComercioVivo.fachada; nunca tem toldo.
## `plano["recuo_real"]` e o recuo que o lote tomou de fato (ChunkBuilder).
static func fachada(sup: Dictionary, centro: Vector3, largura: float, andares: int,
		direcao: int, plano: Dictionary, prob_acesa: float, porta_local: float,
		info: Dictionary = {}) -> bool:
	var ob := Obra.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(plano["semente"])
	var tipo: StringName = plano["tipo"]
	var oficio: StringName = plano["oficio"]
	var cor: Color = plano["cor"]
	var mat: StringName = plano["material"]
	var cobertura: StringName = plano["cobertura"]
	var altura := float(andares) * ANDAR
	var normal := KitModular._normal(direcao)
	var lateral := KitModular._lateral(direcao)
	var giro := atan2(normal.x, normal.z)
	var meia := largura * 0.5
	var margem := 0.45
	# Platibanda reta na laje e no shed; no arco e no oitao a parede para no
	# beiral e o timpano sobe em cima dela.
	var sobe := 1.0 if cobertura == &"laje" else (0.4 if cobertura == &"shed" else 0.0)
	var altura_parede := altura + sobe
	var de := -meia + margem
	var ate := meia - margem

	# --- terreo -----------------------------------------------------------------
	var slots: Array[Dictionary] = []
	var interativa := is_finite(porta_local)
	if interativa:
		slots.append({"tipo": &"porta", "x": porta_local, "w": FachadaViva.PORTA_INTERATIVA.x,
			"andar": 0})
	var h_portao := minf(4.2, altura - 1.6) if andares >= 2 else 2.7
	# Na ladeira a base do lote e o ponto alto da frente: portao de carro vai para
	# la, onde a calcada encontra o piso sem degrau (o resto do vao ganha rampa).
	var x_alto := 0.0
	var perfil: PackedFloat32Array = plano.get("perfil", PackedFloat32Array())
	if perfil.size() >= 2:
		var melhor := -INF
		for k in perfil.size():
			if perfil[k] > melhor:
				melhor = perfil[k]
				x_alto = (float(k) / float(perfil.size() - 1) - 0.5) * largura
	var inclinado := perfil.size() >= 2 and (perfil[0] < -0.15 or perfil[-1] < -0.15)
	match tipo:
		&"galpao", &"deposito":
			var w_p := minf(rng.randf_range(3.6, 4.6), largura - 2.4)
			FundosVivos._encaixar(slots, 0, &"portao", w_p, de, ate,
				x_alto if inclinado else rng.randf_range(-0.5, 0.5) * maxf(0.0, ate - w_p * 0.5))
			if not interativa:
				FundosVivos._encaixar(slots, 0, &"social", 0.9, de, ate,
					(ate if rng.randf() < 0.5 else de))
		&"oficina":
			var w_v := minf(rng.randf_range(3.0, 4.2), largura - 1.4)
			FundosVivos._encaixar(slots, 0, &"oficina", w_v, de, ate,
				x_alto if inclinado else rng.randf_range(-0.4, 0.4) * maxf(0.0, ate - w_v * 0.5))
			if not interativa:
				FundosVivos._encaixar(slots, 0, &"social" if andares >= 2 else &"basculante",
					0.9, de, ate, (ate if rng.randf() < 0.5 else de))
		&"armazem":
			var n := maxi(1, int((largura - 2.0 * margem + 0.8) / 2.5))
			for k in n:
				FundosVivos._encaixar(slots, 0, &"arco", 1.6, de, ate,
					de + (ate - de) * (float(k) + 0.5) / n)
		_:
			FundosVivos._encaixar(slots, 0, &"portaria", 1.3, de, ate,
				(ate - 0.65) if rng.randf() < 0.5 else (de + 0.65))
			for k in 3:
				FundosVivos._encaixar(slots, 0, &"basculante", rng.randf_range(1.6, 2.2), de, ate,
					rng.randf_range(de, ate))

	# --- vaos -------------------------------------------------------------------------
	var vaos: Array = []
	var estados: Array = []
	var casa := {}
	var chapa: Color = CHAPAS[rng.randi() % CHAPAS.size()]
	var y_portao_topo := 0.0
	for s: Dictionary in slots:
		var x: float = s["x"]
		var w: float = s["w"]
		var e := {"tipo": s["tipo"], "semente": rng.randi(), "chapa": chapa,
			"acesa": rng.randf() < 0.6, "oficio": oficio,
			"larg_max": FachadaViva._largura_comodo(x, meia)}
		var vao := {"tipo": s["tipo"], "indice": estados.size()}
		match s["tipo"]:
			&"porta":
				vao["rect"] = Rect2(x - w * 0.5, KitModular.ALTURA_MEIO_FIO, w,
					FachadaViva.PORTA_INTERATIVA.y + 0.05)
				vao["prof"] = 0.18
				info["porta"] = x
			&"portao":
				var r := rng.randf()
				e["estado"] = 0 if r < 0.4 else (1 if r < 0.75 else 2)
				# Sem casca atras de portao aberto (LojaViva): o sorteio acontece do
				# mesmo jeito, e o portao fica fechado. A oficina em que se entra e a
				# borracharia da rua comercial.
				if LojaViva.ativo:
					e["estado"] = 0
				vao["rect"] = Rect2(x - w * 0.5, 0.06, w, h_portao)
				vao["prof"] = 0.3
				vao["tampa"] = int(e["estado"]) == 0
				y_portao_topo = 0.06 + h_portao
				if not info.has("porta"):
					info["porta"] = x
			&"oficina":
				var r := rng.randf()
				e["estado"] = 2 if r < 0.55 else (1 if r < 0.75 else 0)
				# Sem casca atras de portao aberto (LojaViva): o sorteio acontece do
				# mesmo jeito, e o portao fica fechado. A oficina em que se entra e a
				# borracharia da rua comercial.
				if LojaViva.ativo:
					e["estado"] = 0
				vao["rect"] = Rect2(x - w * 0.5, 0.06, w, minf(2.9, h_portao))
				vao["prof"] = 0.3
				vao["tampa"] = int(e["estado"]) == 0
				y_portao_topo = 0.06 + minf(2.9, h_portao)
				if not info.has("porta"):
					info["porta"] = x
			&"social":
				vao["rect"] = Rect2(x - w * 0.5, KitModular.ALTURA_MEIO_FIO, w, 2.1)
				vao["prof"] = 0.18
			&"arco":
				e["aberta"] = rng.randf() < 0.6 and not LojaViva.ativo
				vao["rect"] = Rect2(x - w * 0.5, KitModular.ALTURA_MEIO_FIO, w, 3.0)
				vao["prof"] = 0.34
				vao["arco"] = 0.55
				vao["tampa"] = not bool(e["aberta"])
				y_portao_topo = KitModular.ALTURA_MEIO_FIO + 3.0
				if not info.has("porta"):
					info["porta"] = x
			&"portaria":
				vao["rect"] = Rect2(x - w * 0.5, KitModular.ALTURA_MEIO_FIO, w, 2.5)
				vao["prof"] = 0.24
				y_portao_topo = maxf(y_portao_topo, 2.66)
				if not info.has("porta"):
					info["porta"] = x
			_:
				e = FundosVivos._estado(&"deposito", rng, &"industria", &"fechada", 0, false, casa)
				e["tipo"] = &"janela"
				vao["rect"] = Rect2(x - w * 0.5, 1.4, w, 1.1)
				vao["prof"] = 0.2
				vao["tampa"] = true
		vaos.append(vao)
		estados.append(e)

	# --- andares de cima e a fita de vitros ------------------------------------------
	var tem_nome := bool(plano.get("letreiro", true))
	var janelas_cima: Array[Dictionary] = []
	match tipo:
		&"galpao":
			# Sem nome, ou no galpao alto, a fita de vitros corre acima do portao.
			if not tem_nome or andares >= 3:
				var y0 := y_portao_topo + (1.4 if tem_nome else 0.5)
				var n := maxi(1, int((largura - 1.2) / 2.2))
				for k in n:
					janelas_cima.append({"x": de + (ate - de) * (float(k) + 0.5) / n, "y": y0,
						"w": minf(1.8, (ate - de) / n - 0.4), "h": 0.9, "tipo": &"fita"})
		&"oficina":
			if andares >= 2:
				var n := maxi(1, int((largura - 1.0) / 2.6))
				for k in n:
					janelas_cima.append({"x": de + (ate - de) * (float(k) + 0.5) / n,
						"y": ANDAR + 1.25, "w": rng.randf_range(1.0, 1.3), "h": 1.1,
						"tipo": &"casa"})
		&"armazem":
			for s: Dictionary in slots:
				if s["tipo"] == &"arco":
					janelas_cima.append({"x": s["x"], "y": ANDAR + 0.95, "w": 1.1, "h": 1.7,
						"tipo": &"sobrado"})
		&"fabrica":
			for andar in range(1, andares):
				var n := maxi(1, int((largura - 1.0) / 2.8))
				for k in n:
					janelas_cima.append({"x": de + (ate - de) * (float(k) + 0.5) / n,
						"y": andar * ANDAR + 1.1, "w": minf(2.2, (ate - de) / n - 0.4), "h": 1.3,
						"tipo": &"fita"})
	for j: Dictionary in janelas_cima:
		var andar_j := int(float(j["y"]) / ANDAR)
		var e: Dictionary
		match j["tipo"]:
			&"casa":
				e = JanelaViva.sortear(rng, &"popular", &"familia", andar_j,
					rng.randf() < prob_acesa, casa)
				e["fundo_max"] = 3.0
			&"sobrado":
				e = JanelaViva.sortear(rng, &"ecletico", &"fechada", andar_j,
					rng.randf() < prob_acesa * 0.5, casa)
				if int(e["abertura"]) == JanelaViva.Abertura.ABERTA:
					e["abertura"] = JanelaViva.Abertura.ENTREABERTA
				e["afasta_folha"] = 0.035
			_:
				e = FundosVivos._estado(&"deposito", rng, &"industria", &"fechada", andar_j, false,
					casa)
				if rng.randf() < 0.5:
					e["vidro"] = &"janela_apagada"
		e["tipo"] = &"janela"
		e["larg_max"] = FachadaViva._largura_comodo(float(j["x"]), meia)
		vaos.append({"rect": Rect2(float(j["x"]) - float(j["w"]) * 0.5, j["y"], j["w"], j["h"]),
			"prof": 0.26 if j["tipo"] == &"sobrado" else 0.18,
			"arco": 0.35 if j["tipo"] == &"sobrado" else 0.0,
			"tampa": JanelaViva.precisa_tampa(e), "tipo": &"janela", "indice": estados.size()})
		estados.append(e)

	# --- a parede -------------------------------------------------------------------
	var faixas: Array = []
	if plano.has("barra"):
		faixas.append({"y0": 0.0, "y1": 1.1, "cor": plano["barra"]})
	elif mat == &"concreto":
		faixas.append({"y0": 0.0, "y1": 0.5, "cor": cor.darkened(0.15)})
	var quadros := ParedeVazada.erguer(sup, mat, centro, largura, altura_parede, direcao, cor,
		vaos, faixas, ParedeVazada.desgaste_de(plano))
	info["casa"] = casa
	info["faixas"] = faixas
	info["nome_loja"] = int(plano["nome"])

	for q: Dictionary in quadros:
		var e: Dictionary = estados[int(q["indice"])]
		var r: Rect2 = q["rect"]
		var desce := -FachadaViva.chao_em(plano, r.get_center().x, largura)
		match q["tipo"]:
			&"porta":
				FachadaViva._degrau(ob, q, giro, true)
			&"portao":
				_portao_de_correr(ob, q, e, quadros, meia, rng)
				_rampa(ob, q, desce + (r.position.y - KitModular.ALTURA_MEIO_FIO), giro)
			&"oficina":
				_vao_de_oficina(ob, q, e, rng)
				_rampa(ob, q, desce + (r.position.y - KitModular.ALTURA_MEIO_FIO), giro)
			&"social":
				var v := JanelaViva._vao(q)
				FundosVivos._porta_de_ferro(ob, v, v.prof - 0.045, rng)
				FachadaViva._degrau(ob, q, giro, false, -desce,
					FachadaViva._livre_para_escada(r, [], meia))
			&"arco":
				_porta_de_armazem(ob, q, e, quadros, rng)
				ComercioVivo._soleira(ob, q, desce, giro)
			&"portaria":
				ComercioVivo._portaria(ob, q, rng)
				FachadaViva._degrau(ob, q, giro, false, -desce,
					FachadaViva._livre_para_escada(r, [], meia))
			_:
				JanelaViva.preencher_em(ob, q, e, FachadaViva._espaco_dos_lados(q["rect"], quadros))

	# --- o que da cara de firma a parede ---------------------------------------------
	# Pilastra nas duas pontas: marca a divisa do lote, que no paredao antigo nao
	# existia (tres galpoes da mesma cor liam como um so).
	if tipo != &"oficina" or largura >= 7.0:
		var cor_pilar: Color = (plano["barra"] as Color).lightened(0.25) if plano.has("barra") \
			else cor.darkened(0.1)
		for lado: float in [-1.0, 1.0]:
			ob.caixa(mat if mat != &"tijolo" else &"reboco", centro
				+ lateral * (lado * (meia - 0.18)) + normal * 0.05
				+ Vector3(0.0, altura_parede * 0.5, 0.0), Vector3(0.36, altura_parede, 0.1),
				cor_pilar if mat != &"tijolo" else Color("e2dccd"), giro)
	# Chapim da platibanda e cinta no alto.
	if sobe > 0.0:
		ob.caixa(&"concreto", centro + Vector3(0.0, altura_parede + 0.03, 0.0) + normal * 0.03,
			Vector3(largura, 0.08, 0.16), Color("d8d4ca"), giro)
	ob.caixa(mat if mat != &"tijolo" else &"reboco", centro + Vector3(0.0, altura - 0.08, 0.0)
		+ normal * 0.05, Vector3(largura, 0.16, 0.1),
		cor.darkened(0.12) if mat != &"tijolo" else Color("e2dccd"), giro)
	# O timpano do arco ou o oitao, na frente: a silhueta do galpao.
	var origem := centro + lateral * (-meia) + Vector3(0.0, altura_parede, 0.0)
	if cobertura == &"arco":
		_timpano_arco(ob, mat, centro, lateral, normal, meia, altura, _flecha(largura) + 0.3, origem,
			cor, true)
	elif cobertura == &"oitao":
		if rng.randf() < 0.4 and tipo != &"oficina":
			_platibanda_escalonada(ob, mat, centro, lateral, normal, giro, largura, altura, cor)
		else:
			_timpano_oitao(ob, mat, centro, lateral, normal, meia, altura, origem, cor, true)
	# O nome da firma pintado na parede.
	if tem_nome:
		_letreiro(ob, plano, centro, lateral, normal, giro, largura, altura, altura_parede, sobe,
			y_portao_topo, cobertura, rng)
	_vida(ob, plano, centro, lateral, normal, giro, meia, slots, rng)
	ob.despejar(sup)
	return false


## A flecha do arco da cobertura para uma largura de lote.
static func _flecha(largura: float) -> float:
	return clampf(largura * 0.16, 0.8, 2.2)


## Pontos do arco de circulo de `meia` de meia-corda e `flecha` de altura, de
## -meia a +meia, em (x, y) com y = 0 nas pontas.
static func _arco(meia: float, flecha: float, segmentos: int) -> PackedVector2Array:
	var r := (meia * meia + flecha * flecha) / (2.0 * flecha)
	var th := asin(clampf(meia / r, -1.0, 1.0))
	var saida := PackedVector2Array()
	for k in segmentos + 1:
		var a := -th + 2.0 * th * float(k) / segmentos
		saida.append(Vector2(r * sin(a), r * cos(a) - (r - flecha)))
	return saida


## O timpano em arco no plano da fachada (ou do fundo): leque do meio da base ate
## a curva. Sai um centimetro a frente do plano e desce 5 cm atras da parede de
## baixo: a emenda com a fileira de cima da ParedeVazada nao abre fresta.
static func _timpano_arco(ob: Obra, mat: StringName, centro: Vector3, lateral: Vector3,
		normal: Vector3, meia: float, altura: float, flecha: float, origem: Vector3, cor: Color,
		com_chapim: bool) -> void:
	var frente := centro + normal * 0.01
	var pontos := PackedVector3Array([frente + Vector3(0.0, altura - 0.05, 0.0),
		frente + lateral * (-meia) + Vector3(0.0, altura - 0.05, 0.0)])
	var curva := _arco(meia, flecha, 12)
	for p: Vector2 in curva:
		pontos.append(frente + lateral * p.x + Vector3(0.0, altura + p.y, 0.0))
	pontos.append(frente + lateral * meia + Vector3(0.0, altura - 0.05, 0.0))
	ob.leque(mat, pontos, normal, lateral, origem, cor)
	if not com_chapim:
		return
	# O chapim acompanha a curva, gomo a gomo.
	for k in curva.size() - 1:
		var a := curva[k]
		var b := curva[k + 1]
		var meio := (a + b) * 0.5
		var inclina := atan2(b.y - a.y, b.x - a.x)
		var base := Basis(lateral, Vector3.UP, normal) * Basis(Vector3.BACK, inclina)
		ob.livre(&"concreto", centro + normal * 0.04 + lateral * meio.x
			+ Vector3(0.0, altura + meio.y + 0.04, 0.0), Vector3(a.distance_to(b) + 0.03, 0.08, 0.14),
			base, Color("d8d4ca"))


## O oitao das duas aguas, no plano da fachada ou do fundo.
static func _timpano_oitao(ob: Obra, mat: StringName, centro: Vector3, lateral: Vector3,
		normal: Vector3, meia: float, altura: float, origem: Vector3, cor: Color,
		com_beirada: bool) -> void:
	var frente := centro + normal * 0.01
	var cume := meia * 0.36
	ob.leque(mat, PackedVector3Array([frente + lateral * (-meia) + Vector3(0.0, altura - 0.05, 0.0),
		frente + lateral * meia + Vector3(0.0, altura - 0.05, 0.0),
		frente + Vector3(0.0, altura + cume, 0.0)]), normal, lateral, origem, cor)
	if not com_beirada:
		return
	# A beirada da telha que passa um palmo da empena, dos dois lados.
	var inclina := atan2(cume, meia)
	var comp := sqrt(meia * meia + cume * cume) + 0.25
	for lado: float in [-1.0, 1.0]:
		var base := Basis(lateral, Vector3.UP, normal) * Basis(Vector3.BACK, -lado * inclina)
		ob.livre(&"concreto", centro + normal * 0.06 + lateral * (lado * meia * 0.5)
			+ Vector3(0.0, altura + cume * 0.5 + 0.06, 0.0), Vector3(comp, 0.1, 0.14), base,
			Color("8a8680"))


## Platibanda escalonada: a frente sobe em tres degraus e esconde o telhado.
static func _platibanda_escalonada(ob: Obra, mat: StringName, centro: Vector3,
		lateral: Vector3, normal: Vector3, giro: float, largura: float, altura: float,
		cor: Color) -> void:
	var cume := largura * 0.5 * 0.36
	var passo := maxf(0.5, (cume + 0.4) / 3.0)
	var cor_mat := cor if mat != &"tijolo" else Color.WHITE
	for k in 3:
		var w := largura * (1.0 - float(k) / 3.0)
		var y0 := altura - 0.05 + passo * k
		ob.caixa(mat, centro - normal * 0.08 + Vector3(0.0, y0 + passo * 0.5, 0.0),
			Vector3(w, passo, 0.2), cor_mat, giro, PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE)
		ob.caixa(&"concreto", centro + normal * 0.03 + Vector3(0.0, y0 + passo + 0.03, 0.0),
			Vector3(w + 0.06, 0.07, 0.24), Color("d8d4ca"), giro)


## O nome da firma pintado direto na parede: no timpano do arco, acima do portao,
## ou na platibanda.
static func _letreiro(ob: Obra, plano: Dictionary, centro: Vector3, lateral: Vector3,
		normal: Vector3, giro: float, largura: float, altura: float, altura_parede: float,
		sobe: float, y_topo_vao: float, cobertura: StringName, rng: RandomNumberGenerator) -> void:
	var w := minf(largura * 0.7, 6.4)
	var h := w * 0.25
	var y := 0.0
	if cobertura == &"arco":
		h = minf(h, _flecha(largura) * 0.62)
		y = altura + 0.08 + h * 0.5
	elif sobe > 0.0 and altura_parede - y_topo_vao > 2.2:
		# Entre o portao e a platibanda.
		h = minf(h, 1.0)
		y = y_topo_vao + 0.3 + h * 0.5
	elif sobe > 0.0:
		h = minf(h, sobe - 0.2)
		y = altura + 0.1 + h * 0.5
	else:
		h = minf(h, maxf(0.4, altura - y_topo_vao - 0.5))
		y = y_topo_vao + 0.25 + h * 0.5
	w = h * 4.0
	if w > largura - 0.8:
		w = largura - 0.8
		h = w * 0.25
	var k := int(plano["nome"])
	var celula := Rect2(float(k % 2) * 0.5, float(k / 2) * 0.125, 0.5, 0.125)
	var fundo: Color = LETREIROS[rng.randi() % LETREIROS.size()]
	ob.cartao(&"letreiro_industria", Vector2(w, h), Transform3D(Basis(Vector3.UP, giro),
		centro + normal * 0.022 + Vector3(0.0, y, 0.0)), celula, fundo)


## O nome da firma pintado numa parede qualquer (a lateral de esquina, o muro):
## a celula `k` do atlas letreiros_industria.png.
static func nome_pintado(ob: Obra, centro: Vector3, tamanho: Vector2, giro: float, k: int,
		rng: RandomNumberGenerator) -> void:
	var celula := Rect2(float(k % 2) * 0.5, float(k / 2) * 0.125, 0.5, 0.125)
	ob.cartao(&"letreiro_industria", tamanho, Transform3D(Basis(Vector3.UP, giro), centro),
		celula, LETREIROS[rng.randi() % LETREIROS.size()])


## O que diz que a firma trabalha: medidor, luminaria sobre o portao, pneu,
## grade pronta e tabua encostadas na parede.
static func _vida(ob: Obra, plano: Dictionary, centro: Vector3, lateral: Vector3,
		normal: Vector3, giro: float, meia: float, slots: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	var oficio: StringName = plano["oficio"]
	var x_m := _x_parede(slots, meia, 0.5, rng)
	if is_finite(x_m):
		# Medidor da CEMIG com o conduite: claro, e nao a caixa preta do kit antigo.
		ob.caixa(&"metal_pintado", centro + lateral * x_m + Vector3(0.0, 1.55, 0.0) + normal * 0.08,
			Vector3(0.34, 0.46, 0.14), Color("b8bcb4"), giro)
		ob.caixa(JanelaViva._p(&"metal_pintado"), centro + lateral * x_m + Vector3(0.0, 1.62, 0.0)
			+ normal * 0.155, Vector3(0.18, 0.14, 0.01), Color("3a4a52"), giro)
		ob.caixa(&"metal_pintado", centro + lateral * x_m + Vector3(0.0, 0.7, 0.0) + normal * 0.04,
			Vector3(0.05, 1.2, 0.05), Color("9a9c96"), giro)
	for s: Dictionary in slots:
		if not (s["tipo"] in [&"portao", &"oficina", &"arco"]):
			continue
		var x: float = s["x"]
		var w: float = s["w"]
		if s["tipo"] != &"arco":
			# Luminaria de braco sobre o vao: a lampada de sodio da noite.
			var topo := 3.1 if s["tipo"] == &"oficina" else 4.5
			var lp := centro + lateral * x + Vector3(0.0, topo, 0.0) + normal * 0.4
			ob.caixa(JanelaViva._p(&"metal"), lp + normal * -0.2 + Vector3(0.0, 0.08, 0.0),
				Vector3(0.04, 0.04, 0.42), Color("3a3c3e"), giro)
			ob.caixa(&"metal_pintado", lp, Vector3(0.36, 0.1, 0.24), Color("5a5c5e"), giro)
			ob.caixa(JanelaViva._p(&"lampada"), lp + Vector3(0.0, -0.06, 0.0),
				Vector3(0.24, 0.03, 0.16), Color.WHITE, giro)
		if s["tipo"] != &"oficina":
			continue
		var lado := -1.0 if x > 0.0 else 1.0
		var junto := x + lado * (w * 0.5 + 0.55)
		if absf(junto) > meia - 0.4:
			continue
		var pe := centro + lateral * junto + normal * 0.45
		match oficio:
			&"borracharia", &"mecanica", &"motos", &"funilaria":
				# A torre de pneu, a de borracharia pintada de amarelo e branco.
				var n := rng.randi_range(3, 7 if oficio == &"borracharia" else 4)
				for k in n:
					var tinta := BORRACHA
					if oficio == &"borracharia" and k == n - 1:
						tinta = Color("e0c020")
					ob.cilindro(JanelaViva._p(&"metal_pintado"), pe + Vector3(0.0, k * 0.2, 0.0),
						0.3, 0.19, tinta, 12)
			&"serralheria", &"tornearia":
				# Grade pronta encostada na parede, esperando o cliente.
				var t := Transform3D(Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, -0.12),
					pe + Vector3(0.0, 0.95, -0.3))
				for k in 7:
					var tt := t.translated_local(Vector3(-0.6 + k * 0.2, 0.0, 0.0))
					ob.cartao(JanelaViva._p(&"metal"), Vector2(0.025, 1.8), tt, Rect2(0, 0, 1, 1),
						Color("2c2e30"))
				for y: float in [-0.8, 0.0, 0.8]:
					ob.cartao(JanelaViva._p(&"metal"), Vector2(1.3, 0.04),
						t.translated_local(Vector3(0.0, y, 0.0)), Rect2(0, 0, 1, 1), Color("2c2e30"))
			&"marcenaria":
				for k in 5:
					var t := Transform3D(Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, -0.2),
						pe + Vector3(0.0, 1.1, -0.3) + lateral * (k * 0.12 - 0.24))
					ob.cartao(JanelaViva._p(&"tabua"), Vector2(0.2, 2.2), t, Rect2(0, 0, 1, 1),
						Color("c8a878").darkened(rng.randf() * 0.3))


## Um x da fachada sem vao em [x - folga, x + folga].
static func _x_parede(slots: Array[Dictionary], meia: float, folga: float,
		rng: RandomNumberGenerator) -> float:
	return FundosVivos._x_livre(slots, rng, -meia + 0.6, meia - 0.6, folga, 0)


# --- vaos -----------------------------------------------------------------------------

## Portao de correr de chapa pintada: fechado dentro do vao, ou corrido para o
## lado na frente da parede, com o galpao aparecendo pelo vao.
static func _portao_de_correr(ob: Obra, q: Dictionary, e: Dictionary,
		quadros: Array[Dictionary], meia: float, rng: RandomNumberGenerator) -> void:
	var v := JanelaViva._vao(q)
	var estado: int = e["estado"]
	var chapa: Color = e["chapa"]
	var r: Rect2 = q["rect"]
	# Quanto de parede livre ha de cada lado para o portao correr.
	var livre := FachadaViva._espaco_dos_lados(r, quadros) * 2.0
	var esquerda := minf(livre.x, r.position.x + meia - 0.1)
	var direita := minf(livre.y, meia - r.end.x - 0.1)
	var lado := 1.0 if direita >= esquerda else -1.0
	var corre := 0.0
	if estado > 0:
		corre = minf(maxf(esquerda, direita), v.w * (0.5 if estado == 1 else 1.0))
		_galpao_dentro(ob, v, e, rng)
	var d := v.prof - 0.06 if corre < 0.05 else -0.07
	var u := lado * corre
	_folha_de_portao(ob, v, chapa, u, d)
	# O trilho de cima, do vao ate onde o portao corre.
	var comp := v.w + corre
	ob.caixa(&"metal", v.p(lado * corre * 0.5, v.h + 0.08, -0.07), Vector3(comp + 0.1, 0.1, 0.08),
		Color("4a4c4e"), v.giro)
	# Cadeado e ferrolho na folha fechada.
	if corre < 0.05:
		ob.caixa(JanelaViva._p(&"metal"), v.p(v.w * 0.42, 1.1, d - 0.03),
			Vector3(0.12, 0.05, 0.05), Color("8a8a80"), v.giro)


## A rampa de concreto do portao ate a calcada, quando a calcada fica abaixo do
## piso: cunha na largura do vao, 1,2 m para fora (na calcada, como a guia
## rebaixada de toda garagem). Sem rampa o portao abria para um degrau.
static func _rampa(ob: Obra, q: Dictionary, alto: float, giro: float) -> void:
	if alto < 0.04:
		return
	var v := JanelaViva._vao(q)
	const SAI := 1.2
	const ESP := 0.2
	var th := atan2(alto, SAI)
	var comp := sqrt(SAI * SAI + alto * alto)
	# O Z da caixa desce para a rua: +th em volta do eixo da fachada. A face de
	# cima vai do pe do vao (y = 0) ate a calcada (y = -alto, 1,2 m para fora).
	var base := v.base() * Basis(Vector3.RIGHT, th)
	var centro := v.p(0.0, -alto * 0.5 - ESP * 0.5 * cos(th), -SAI * 0.5 + ESP * 0.5 * sin(th))
	ob.livre(&"concreto", centro, Vector3(v.w + 0.2, ESP, comp), base, Color("b8b4aa"))


## A folha do portao de correr: chapa com frisos verticais e o requadro.
static func _folha_de_portao(ob: Obra, v: JanelaViva.Vao, chapa: Color, u: float,
		d: float) -> void:
	ob.caixa(&"metal_pintado", v.p(u, v.h * 0.5, d), Vector3(v.w - 0.02, v.h - 0.02, 0.04), chapa,
		v.giro)
	var n := int(v.w / 0.42)
	for k in range(1, n):
		ob.placa(&"metal_pintado", v.p(u - v.w * 0.5 + v.w * float(k) / n, v.h * 0.5, d - 0.022),
			Vector2(0.035, v.h - 0.2), v.giro, chapa.darkened(0.2))
	for y: float in [0.1, v.h * 0.5, v.h - 0.1]:
		ob.placa(&"metal_pintado", v.p(u, y, d - 0.024), Vector2(v.w - 0.1, 0.06), v.giro,
			chapa.darkened(0.12))


## O vao largo da oficina: aberto, meio fechado ou fechado pela porta de enrolar.
static func _vao_de_oficina(ob: Obra, q: Dictionary, e: Dictionary,
		rng: RandomNumberGenerator) -> void:
	var v := JanelaViva._vao(q)
	var estado: int = e["estado"]
	var d := v.prof - 0.06
	for lado: float in [-1.0, 1.0]:
		ob.caixa(&"metal", v.p(lado * (v.w * 0.5 - 0.04), v.h * 0.5, d - 0.02),
			Vector3(0.06, v.h, 0.08), Color("5a5c5e"), v.giro)
	if estado > 0:
		_oficina_dentro(ob, v, e, rng)
	var baixa := 0.0 if estado == 0 else (v.h * 0.55 if estado == 1 else v.h - 0.32)
	var alt := v.h - baixa
	ob.parede(&"metal_ondulado", v.p(0.0, baixa + alt * 0.5, d), Vector2(v.w - 0.06, alt), v.giro,
		Color.WHITE.lerp(e["chapa"], 0.35))
	ob.caixa(&"metal", v.p(0.0, baixa + 0.03, d - 0.02), Vector3(v.w - 0.06, 0.06, 0.05),
		Color("3a3c3e"), v.giro)


## Porta em arco do armazem: duas folhas de tabua escancaradas e a sacaria
## dentro, ou fechadas no vao.
static func _porta_de_armazem(ob: Obra, q: Dictionary, e: Dictionary,
		quadros: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	var v := JanelaViva._vao(q)
	var cor: Color = JanelaViva.ESQUADRIAS[rng.randi() % JanelaViva.ESQUADRIAS.size()]
	var h_folha := v.h - v.arco
	if bool(e["aberta"]):
		_armazem_dentro(ob, v, e, rng)
		JanelaViva._folhas(ob, v, cor, h_folha, PI - 0.1, false,
			FachadaViva._espaco_dos_lados(q["rect"], quadros), 0.0)
		# A bandeira do arco, de vidro, fica.
		ob.parede(&"janela_apagada", v.p(0.0, h_folha + v.arco * 0.5, v.prof - 0.05),
			Vector2(v.w + 0.04, v.arco + 0.04), v.giro)
	else:
		ob.caixa(&"tabua", v.p(0.0, h_folha * 0.5, v.prof - 0.06), Vector3(v.w - 0.02, h_folha, 0.05),
			cor, v.giro)
		ob.placa(&"tabua", v.p(0.0, h_folha * 0.5, v.prof - 0.09), Vector2(0.04, h_folha - 0.1),
			v.giro, cor.darkened(0.3))
		ob.parede(&"janela_apagada", v.p(0.0, h_folha + v.arco * 0.5, v.prof - 0.05),
			Vector2(v.w + 0.04, v.arco + 0.04), v.giro)


# --- o lado de dentro -----------------------------------------------------------------

## A casca de um salao atras do vao, virada para dentro, e a lampada.
## Devolve (d0, d1, y_teto, larg) para quem mobilia.
static func _casca(ob: Obra, v: JanelaViva.Vao, e: Dictionary, fundo: float, alto: float,
		larg: float, parede: Color, chao: Color) -> Vector4:
	var y_teto := minf(v.h + alto, v.h + 1.6)
	var d0 := v.prof
	var d1 := v.prof + fundo
	var meio_d := (d0 + d1) * 0.5
	# Galpao e oficina sao meia-luz, com a lampada acesa no meio: o `interior_aceso`
	# (a sala da janela) estourava o vao inteiro em branco visto da calcada.
	var casca: StringName = &"interior"
	JanelaViva._plano(ob, casca, v.p(0.0, y_teto * 0.5, d1), Vector2(larg, y_teto), v.nor, v.lat,
		parede)
	JanelaViva._plano(ob, casca, v.p(-larg * 0.5, y_teto * 0.5, meio_d), Vector2(fundo, y_teto),
		v.lat, -v.nor, parede.darkened(0.06))
	JanelaViva._plano(ob, casca, v.p(larg * 0.5, y_teto * 0.5, meio_d), Vector2(fundo, y_teto),
		-v.lat, v.nor, parede.darkened(0.06))
	JanelaViva._plano(ob, casca, v.p(0.0, 0.0, meio_d), Vector2(larg, fundo), Vector3.UP, v.lat, chao)
	JanelaViva._plano(ob, casca, v.p(0.0, y_teto, meio_d), Vector2(larg, fundo), Vector3.DOWN, v.lat,
		parede.darkened(0.2))
	ob.caixa(JanelaViva._p(&"lampada" if bool(e.get("acesa", false)) else &"metal_pintado"),
		v.p(0.0, y_teto - 0.06, meio_d), Vector3(1.2, 0.05, 0.08), Color.WHITE, v.giro)
	return Vector4(d0, d1, y_teto, larg)


## Dentro do galpao: pallet, tambor, pilha de caixa, e o que a firma guarda.
static func _galpao_dentro(ob: Obra, v: JanelaViva.Vao, e: Dictionary,
		rng: RandomNumberGenerator) -> void:
	var larg := minf(v.w + 3.0, float(e.get("larg_max", v.w + 3.0)))
	var c := _casca(ob, v, e, rng.randf_range(5.0, 6.5), 1.4, larg, Color("767168"),
		Color("55524c"))
	var d1 := c.y
	var m := JanelaViva._p(&"interior")
	var oficio: StringName = e.get("oficio", &"")
	for k in rng.randi_range(3, 5):
		var u := rng.randf_range(-larg * 0.5 + 0.8, larg * 0.5 - 0.8)
		var d := rng.randf_range(c.x + 1.2, d1 - 0.8)
		var pe := v.p(u, 0.0, d)
		match oficio:
			&"laticinio":
				# Latao de leite de aluminio, em fila.
				for j in 3:
					ob.cilindro(JanelaViva._p(&"metal_pintado"), pe + v.lat * (j * 0.42), 0.18, 0.6,
						Color("c8ccce"), 8)
			&"ceramica":
				ob.caixa(&"tijolo", pe + Vector3(0.0, 0.5, 0.0), Vector3(1.1, 1.0, 0.9),
					Color.WHITE, v.giro)
			&"madeireira":
				ob.caixa(m, pe + Vector3(0.0, 0.35, 0.0), Vector3(2.2, 0.7, 0.8), Color("b8946a"),
					v.giro)
			_:
				# Pallet com carga coberta de lona, ou caixa de papelao empilhada.
				ob.caixa(m, pe + Vector3(0.0, 0.07, 0.0), Vector3(1.2, 0.14, 1.0), Color("8a6a48"),
					v.giro)
				ob.caixa(m, pe + Vector3(0.0, 0.6, 0.0), Vector3(1.1, 0.92, 0.9),
					[Color("b89a70"), Color("5a6a7a"), Color("c8b48a")][rng.randi() % 3] as Color,
					v.giro)
	# Tambor num canto.
	ob.cilindro(JanelaViva._p(&"metal_pintado"), v.p(larg * 0.5 - 0.6, 0.0, d1 - 0.6), 0.29, 0.88,
		[Color("2f5a8a"), Color("8a2e26"), Color("3a5a3a")][rng.randi() % 3] as Color, 10)


## Dentro da oficina: bancada, painel de ferramenta, e o que o oficio tem.
static func _oficina_dentro(ob: Obra, v: JanelaViva.Vao, e: Dictionary,
		rng: RandomNumberGenerator) -> void:
	var larg := minf(v.w + 1.6, float(e.get("larg_max", v.w + 1.6)))
	var c := _casca(ob, v, e, rng.randf_range(3.6, 4.6), 0.7, larg, Color("6e685e"),
		Color("45423d"))
	var d1 := c.y
	var m := JanelaViva._p(&"interior_madeira")
	var cheio := JanelaViva._p(&"interior")
	# Bancada no fundo e o painel de ferramenta em cima dela.
	ob.caixa(m, v.p(0.0, 0.45, d1 - 0.35), Vector3(larg - 0.8, 0.9, 0.6), Color("6a4a30"), v.giro)
	ob.placa(cheio, v.p(0.0, 1.55, d1 - 0.01), Vector2(larg - 1.2, 0.9), v.giro, Color("b89a70"))
	for k in 8:
		ob.placa(cheio, v.p(-larg * 0.5 + 0.8 + k * (larg - 1.6) / 8.0, 1.5 + rng.randf_range(-0.2, 0.2),
			d1 - 0.02), Vector2(0.06, rng.randf_range(0.2, 0.4)), v.giro, Color("3a3c3e"))
	var oficio: StringName = e.get("oficio", &"")
	match oficio:
		&"marcenaria":
			ob.caixa(m, v.p(-larg * 0.25, 0.4, (c.x + d1) * 0.5), Vector3(1.4, 0.8, 0.8),
				Color("8a6a48"), v.giro)
			for k in 4:
				ob.caixa(m, v.p(larg * 0.3, 0.06 + k * 0.05, c.x + 1.2), Vector3(2.0, 0.04, 0.3),
					Color("c8a878"), v.giro)
		&"serralheria", &"tornearia", &"vidracaria":
			# Perfis e barras encostados na parede do lado.
			for k in 6:
				var t := Transform3D(v.base() * Basis(Vector3.FORWARD, 0.12),
					v.p(-larg * 0.5 + 0.15, 1.2, c.x + 0.6 + k * 0.28))
				ob.cartao(JanelaViva._p(&"metal"), Vector2(0.04, 2.3), t.rotated_local(Vector3.UP,
					PI * 0.5), Rect2(0, 0, 1, 1), Color("4a4c4e"))
		_:
			# Pneu empilhado e o macaco jacare.
			for k in rng.randi_range(3, 6):
				ob.cilindro(JanelaViva._p(&"metal_pintado"), v.p(larg * 0.5 - 0.5, k * 0.2, c.x + 1.0),
					0.3, 0.19, BORRACHA, 12)
			ob.caixa(cheio, v.p(-0.3, 0.1, c.x + 1.4), Vector3(0.3, 0.2, 0.9), Color("b83a2a"), v.giro)
	# Compressor vermelho num canto.
	ob.cilindro(JanelaViva._p(&"metal_pintado"), v.p(-larg * 0.5 + 0.45, 0.2, d1 - 0.5), 0.22, 0.5,
		Color("b83028"), 8)


## Dentro do armazem: sacaria de juta em pilha e a balanca.
static func _armazem_dentro(ob: Obra, v: JanelaViva.Vao, e: Dictionary,
		rng: RandomNumberGenerator) -> void:
	var larg := minf(v.w + 1.8, float(e.get("larg_max", v.w + 1.8)))
	var c := _casca(ob, v, e, rng.randf_range(3.5, 4.5), 0.8, larg, Color("d8ccb4"),
		Color("8a7a66"))
	var saco := JanelaViva._p(&"interior")
	for pilha in 3:
		var u := -larg * 0.5 + 0.55 + pilha * (larg - 1.1) * 0.5
		var d := c.y - 0.5 - rng.randf_range(0.0, 0.8)
		for k in rng.randi_range(3, 7):
			ob.caixa(saco, v.p(u + rng.randf_range(-0.04, 0.04), 0.14 + k * 0.26, d),
				Vector3(0.62, 0.26, 0.42), Color("c8b48a").darkened(rng.randf() * 0.18),
				v.giro + rng.randf_range(-0.08, 0.08))
	# Balanca de plataforma com o mostrador.
	ob.caixa(saco, v.p(0.2, 0.06, c.x + 1.0), Vector3(0.7, 0.12, 0.5), Color("5a5c5e"), v.giro)
	ob.caixa(saco, v.p(0.2, 0.7, c.x + 1.2), Vector3(0.05, 1.2, 0.05), Color("5a5c5e"), v.giro)
	ob.caixa(saco, v.p(0.2, 1.35, c.x + 1.2), Vector3(0.36, 0.36, 0.1), Color("e8e4d8"), v.giro)


# --- cobertura ------------------------------------------------------------------------

## O topo pela cobertura do plano: laje com platibanda, arco de chapa, duas aguas
## com o oitao para a rua, ou shed. `topo` e o meio do topo da massa, `tamanho`
## a planta dela (sem o avanco da fachada).
static func coroar(sup: Dictionary, plano: Dictionary, topo: Vector3, tamanho: Vector3,
		direcao: int, rng: RandomNumberGenerator) -> void:
	var ob := Obra.new()
	var r := RandomNumberGenerator.new()
	r.seed = int(plano["semente"]) * 131 + 7
	var normal := KitModular._normal(direcao)
	var lateral := KitModular._lateral(direcao)
	var larg := tamanho.x * absf(lateral.x) + tamanho.z * absf(lateral.z)
	var fundo := tamanho.x * absf(normal.x) + tamanho.z * absf(normal.z)
	var meia := larg * 0.5
	var frente := topo + normal * (fundo * 0.5)
	var tras := topo - normal * (fundo * 0.5)
	var cor: Color = plano["cor_corpo"]
	var mat: StringName = plano["mat_corpo"]
	var y := topo.y
	match plano["cobertura"]:
		&"arco":
			var flecha := _flecha(larg)
			var curva := _arco(meia, flecha, 12)
			var chapa := Color("c8ccce").darkened(r.randf_range(0.0, 0.3))
			for k in curva.size() - 1:
				var a := curva[k]
				var b := curva[k + 1]
				# Relativos a `frente` e `tras`, que ja estao na altura do topo.
				var pa := Vector3(0.0, a.y + 0.02, 0.0) + lateral * a.x
				var pb := Vector3(0.0, b.y + 0.02, 0.0) + lateral * b.x
				var n := (lateral * -(b.y - a.y) + Vector3.UP * (b.x - a.x)).normalized()
				if n.y < 0.0:
					n = -n
				# A onda da chapa curva corre de beiral a beiral, ao longo do arco: o
				# u da textura (as ondas estao ao longo dele) vai na tangente.
				var u := (lateral * (b.x - a.x) + Vector3.UP * (b.y - a.y)).normalized()
				ob.quadra(&"metal_ondulado", frente + pa, frente + pb, tras + pb, tras + pa, n, u,
					frente + lateral * (-meia), chapa)
			# O fundo do arco: o timpano de tras, sem chapim.
			_timpano_arco(ob, mat, tras - Vector3(0.0, y, 0.0), -lateral, -normal, meia, y, flecha,
				tras + lateral * meia, cor, false)
			_exaustores(ob, topo + Vector3(0.0, flecha + 0.02, 0.0), normal, fundo, r)
		&"oitao":
			var cume := meia * 0.36
			var telha := r.randf() < 0.45
			var tom := Color.WHITE.lerp(KitPredio.TELHA_VELHA[r.randi() % KitPredio.TELHA_VELHA.size()],
				r.randf_range(0.0, 0.7)) if telha else Color("c9c5ba").darkened(r.randf_range(0.0, 0.25))
			for lado: float in [-1.0, 1.0]:
				# Relativos a `frente` e `tras`, que ja estao na altura do topo.
				var beira := lateral * (lado * meia) + Vector3(0.0, 0.02, 0.0)
				var alto := Vector3(0.0, cume + 0.02, 0.0)
				var n := (lateral * (lado * cume) + Vector3.UP * meia).normalized()
				ob.quadra(&"telha" if telha else &"metal_ondulado", frente + normal * 0.2 + alto,
					frente + normal * 0.2 + beira, tras - normal * 0.2 + beira, tras - normal * 0.2 + alto,
					n, normal if telha else (beira - alto).normalized(), frente + alto, tom)
			# Cumeeira.
			ob.caixa(&"telha" if telha else &"metal", topo + Vector3(0.0, cume + 0.06, 0.0),
				Vector3(0.3, 0.1, fundo + 0.4) if absf(normal.z) > 0.5 else Vector3(fundo + 0.4, 0.1, 0.3),
				tom.darkened(0.1))
			# O oitao de tras.
			_timpano_oitao(ob, mat, tras - Vector3(0.0, y, 0.0), -lateral, -normal, meia, y,
				tras + lateral * meia, cor, false)
			if bool(plano.get("industria", false)) and plano["tipo"] == &"galpao" and r.randf() < 0.5:
				_lanternim(ob, topo + Vector3(0.0, cume, 0.0), normal, lateral, fundo, r)
			else:
				_exaustores(ob, topo + Vector3(0.0, cume * 0.6, 0.0), normal, fundo, r)
		&"shed":
			_shed(ob, topo, normal, lateral, meia, fundo, cor, mat, r)
			FachadaViva._platibanda(sup, topo, tamanho, cor, 0.4)
		_:
			FachadaViva._platibanda(sup, topo, tamanho, cor, 1.0)
			if r.randf() < 0.55:
				var p := topo - normal * fundo * 0.25 + lateral * (meia * 0.4 * (1.0 if r.randf() < 0.5 else -1.0)) \
					+ Vector3(0.0, 0.25, 0.0)
				KitModular.caixa_cor(sup, &"concreto", p, Vector3(1.6, 0.5, 1.6), Color("b8b2a6"), 0.0)
				FachadaViva._cilindro(sup, &"metal_pintado", p + Vector3(0.0, 0.25, 0.0), 0.75, 1.0,
					Color("3d74b5"))
				FachadaViva._cilindro(sup, &"metal_pintado", p + Vector3(0.0, 1.25, 0.0), 0.66, 0.08,
					Color("2f5f99"))
	ob.despejar(sup)


## Exaustor eolico: a turbina de chapa que gira no alto de todo galpao.
static func _exaustores(ob: Obra, cume: Vector3, normal: Vector3, fundo: float,
		rng: RandomNumberGenerator) -> void:
	for k in rng.randi_range(1, 3):
		var p := cume + normal * (fundo * (float(k) / 3.0 - 0.4))
		ob.cilindro(&"metal_pintado", p, 0.12, 0.25, Color("a8acae"), 8)
		ob.cilindro(&"metal_pintado", p + Vector3(0.0, 0.25, 0.0), 0.3, 0.32, Color("c8ccce"), 12)


## Lanternim: a cumeeira elevada com veneziana, que tira o calor do galpao.
static func _lanternim(ob: Obra, cume: Vector3, normal: Vector3, lateral: Vector3,
		fundo: float, rng: RandomNumberGenerator) -> void:
	var comp := fundo * 0.7
	var giro := atan2(normal.x, normal.z)
	ob.caixa(&"metal_ondulado", cume + Vector3(0.0, 0.3, 0.0), Vector3(1.0, 0.5, comp),
		Color("9a9ea0"), giro, PSXMesh.FACE_DIR | PSXMesh.FACE_ESQ | PSXMesh.FACE_FRENTE | PSXMesh.FACE_TRAS)
	for lado: float in [-1.0, 1.0]:
		ob.livre(&"metal_ondulado", cume + lateral * (lado * 0.32) + Vector3(0.0, 0.62, 0.0),
			Vector3(0.75, 0.03, comp + 0.2), Basis(Vector3.UP, giro) * Basis(Vector3.BACK, -lado * 0.35),
			Color("b8bcbe"))


## Shed: dentes de serra paralelos a rua, cada um com a fita de vidro virada para
## a frente e a agua caindo para o fundo. O perfil fecha nas duas laterais.
static func _shed(ob: Obra, topo: Vector3, normal: Vector3, lateral: Vector3, meia: float,
		fundo: float, cor: Color, mat: StringName, rng: RandomNumberGenerator) -> void:
	var n := maxi(2, int(fundo / 3.2))
	var passo := fundo / n
	const ALTO := 1.3
	var y := topo.y
	var frente := topo + normal * (fundo * 0.5)
	var chapa := Color("c9c5ba").darkened(rng.randf_range(0.0, 0.25))
	for k in n:
		var s0 := float(k) * passo
		var s1 := s0 + passo
		var a := frente - normal * s0
		var b := frente - normal * s1
		# A fita de vidro, virada para a rua.
		var g := a + Vector3(0.0, y - topo.y, 0.0)
		ob.plano(&"janela_apagada", Vector3(g.x, y + ALTO * 0.5, g.z) - normal * 0.02,
			Vector2(meia * 2.0, ALTO), normal, lateral)
		# Montantes da fita.
		var m := int(meia * 2.0 / 1.2)
		for j in range(1, m):
			ob.placa(&"metal", Vector3(g.x, y + ALTO * 0.5, g.z) + lateral * (-meia + j * meia * 2.0 / m),
				Vector2(0.05, ALTO), atan2(normal.x, normal.z), Color("4a4c4e"))
		# A agua do dente, da crista a frente ate o pe no fundo.
		var crista := Vector3(a.x, y + ALTO, a.z)
		var pe := Vector3(b.x, y + 0.02, b.z)
		var nn := (normal * ALTO + Vector3.UP * passo).normalized()
		ob.quadra(&"metal_ondulado", crista + lateral * (-meia), crista + lateral * meia,
			pe + lateral * meia, pe + lateral * (-meia), nn, (pe - crista).normalized(),
			crista + lateral * (-meia), chapa)
		# O perfil do dente nas duas laterais.
		for lado: float in [-1.0, 1.0]:
			var off := lateral * (lado * meia)
			ob.triangulo(mat, Vector3(a.x, y, a.z) + off, Vector3(b.x, y, b.z) + off, crista + off,
				lateral * lado, cor if mat != &"tijolo" else Color("d8d0c0"))


# --- patio do deposito ---------------------------------------------------------------

## O patio murado do deposito recuado: muro na linha da calcada com o portao
## gradeado (fechado: ve-se o patio pela grade, e ninguem entra), chao de
## concreto, baia de areia e brita, pilha de tijolo e o cimento no pallet.
## Como FundosBuilder.jardim, `frente_lote` e o meio do lote na linha da quadra.
static func patio(sup: Dictionary, colisao: Array[Dictionary], frente_lote: Vector3,
		larg: float, recuo: float, direcao: int, plano: Dictionary) -> void:
	var ob := Obra.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(plano["semente"]) * 977 + 3
	var normal := KitModular._normal(direcao)
	var lateral := KitModular._lateral(direcao)
	var giro := atan2(normal.x, normal.z)
	var h := KitModular.ALTURA_MEIO_FIO
	var meia := larg * 0.5
	const MURO := 2.4
	const ESP := 0.18
	# Chao do patio na altura da calcada.
	var a := frente_lote - lateral * meia - normal * ESP
	var b := frente_lote + lateral * meia - normal * recuo
	KitModular.chao(sup, &"concreto", Vector3(minf(a.x, b.x), h + 0.01, minf(a.z, b.z)),
		Vector2(absf(b.x - a.x), absf(b.z - a.z)), 4.0, Color(0.6, 0.59, 0.56))

	# O muro e o portao gradeado.
	var w_portao := minf(rng.randf_range(3.2, 4.2), larg - 1.6)
	var x_portao := rng.randf_range(-meia + 0.6 + w_portao * 0.5, meia - 0.6 - w_portao * 0.5)
	var linha := frente_lote - normal * (ESP * 0.5)
	var cor: Color = plano["cor"] if plano["material"] != &"tijolo" else Color("d8d0c0")
	var mat_muro: StringName = &"reboco" if plano["material"] != &"concreto" else &"concreto"
	for trecho: Vector2 in [Vector2(-meia, x_portao - w_portao * 0.5 - 0.15),
			Vector2(x_portao + w_portao * 0.5 + 0.15, meia)]:
		var comp := trecho.y - trecho.x
		if comp < 0.1:
			continue
		var meio := linha + lateral * ((trecho.x + trecho.y) * 0.5)
		ob.caixa(mat_muro, meio + Vector3(0.0, h + MURO * 0.5, 0.0), Vector3(comp, MURO, ESP), cor,
			giro, PSXMesh.FACE_TODAS & ~PSXMesh.FACE_BASE)
		if plano.has("barra"):
			ob.caixa(mat_muro, meio + Vector3(0.0, h + 0.55, 0.0) + normal * 0.005,
				Vector3(comp + 0.01, 1.1, ESP + 0.01), plano["barra"], giro,
				PSXMesh.FACE_FRENTE | PSXMesh.FACE_TRAS | PSXMesh.FACE_DIR | PSXMesh.FACE_ESQ)
		ob.caixa(&"concreto", meio + Vector3(0.0, h + MURO + 0.04, 0.0),
			Vector3(comp + 0.06, 0.08, ESP + 0.06), Color("d8d4ca"), giro)
		# Caco de vidro no chapim.
		for k in int(comp / 0.25):
			var t := Transform3D(Basis(Vector3.UP, giro + rng.randf_range(-0.6, 0.6)),
				meio + lateral * (-comp * 0.5 + 0.12 + k * 0.25) + Vector3(0.0, h + MURO + 0.13, 0.0))
			ob.cartao(JanelaViva._p(&"janela_apagada"), Vector2(0.06, 0.1), t, Rect2(0, 0, 1, 1),
				Color(0.7, 0.8, 0.75))
	# Pilares do portao e o portao de grade, fechado.
	for lado: float in [-1.0, 1.0]:
		ob.caixa(mat_muro, linha + lateral * (x_portao + lado * (w_portao * 0.5 + 0.08))
			+ Vector3(0.0, h + (MURO + 0.2) * 0.5, 0.0), Vector3(0.3, MURO + 0.2, 0.3),
			cor.darkened(0.08), giro)
	var ferro: Color = CHAPAS[rng.randi() % CHAPAS.size()].darkened(0.2)
	var centro_p := linha + lateral * x_portao + Vector3(0.0, h, 0.0)
	var n := int(w_portao / 0.12)
	for k in range(1, n):
		ob.placa(&"metal", centro_p + lateral * (-w_portao * 0.5 + w_portao * k / n)
			+ Vector3(0.0, 1.1, 0.0), Vector2(0.025, 2.1), giro, ferro)
		ob.placa(&"metal", centro_p + lateral * (-w_portao * 0.5 + w_portao * k / n)
			+ Vector3(0.0, 1.1, 0.0), Vector2(0.025, 2.1), giro + PI, ferro)
	for y: float in [0.1, 1.1, 2.12]:
		ob.caixa(&"metal", centro_p + Vector3(0.0, y, 0.0), Vector3(w_portao, 0.06, 0.05), ferro,
			giro)
	# O nome pintado no muro.
	var trecho_nome := maxf(x_portao + meia - w_portao * 0.5, meia - x_portao - w_portao * 0.5)
	if trecho_nome > 2.4:
		var x_n := (-meia + x_portao - w_portao * 0.5) * 0.5 if x_portao + meia - w_portao * 0.5 \
			> meia - x_portao - w_portao * 0.5 else (meia + x_portao + w_portao * 0.5) * 0.5
		var w_n := minf(trecho_nome - 0.5, 3.6)
		var k := int(plano["nome"])
		ob.cartao(&"letreiro_industria", Vector2(w_n, w_n * 0.25), Transform3D(
			Basis(Vector3.UP, giro), frente_lote + lateral * x_n + normal * 0.005
			+ Vector3(0.0, h + 1.65, 0.0)), Rect2(float(k % 2) * 0.5, float(k / 2) * 0.125, 0.5,
			0.125), LETREIROS[rng.randi() % LETREIROS.size()])
	colisao.append({"tamanho": Vector3(larg, MURO + h, ESP) if absf(normal.z) > 0.5
		else Vector3(ESP, MURO + h, larg), "pos": linha + Vector3(0.0, (MURO + h) * 0.5, 0.0)})

	# O que tem no patio.
	var fundo_util := recuo - ESP - 0.5
	var baias := rng.randi_range(1, 2)
	for k in baias:
		var u := -meia + 1.2 + k * 1.9
		if u > meia - 1.0:
			break
		var pe := frente_lote + lateral * u - normal * (recuo - 0.9) + Vector3(0.0, h, 0.0)
		# Baia de bloco com o monte de areia ou de brita.
		for lado: float in [-1.0, 1.0]:
			ob.caixa(&"concreto", pe + lateral * (lado * 0.85) + Vector3(0.0, 0.45, 0.0),
				Vector3(0.14, 0.9, 1.5), Color("b8b4aa"), giro)
		_monte(ob, pe, lateral, normal, 1.55, 1.3, rng.randf_range(0.7, 1.0),
			&"areia" if k == 0 else &"concreto",
			Color("d8b878") if k == 0 else Color("7a7874"))
	# Pilha de tijolo baiano e cimento no pallet.
	var u_t := meia - 1.0
	var pe_t := frente_lote + lateral * u_t - normal * minf(recuo - 0.8, fundo_util) + Vector3(0.0, h, 0.0)
	ob.caixa(&"tijolo", pe_t + Vector3(0.0, 0.45, 0.0), Vector3(1.1, 0.9, 0.9), Color.WHITE, giro)
	var pe_c := frente_lote + lateral * (u_t - 0.2) - normal * 1.1 + Vector3(0.0, h, 0.0)
	ob.caixa(&"tabua", pe_c + Vector3(0.0, 0.07, 0.0), Vector3(1.2, 0.14, 1.0), Color("8a6a48"), giro)
	for camada in 3:
		for k in 2:
			ob.caixa(JanelaViva._p(&"reboco"), pe_c + Basis(Vector3.UP, giro) * Vector3(-0.28 + k * 0.56,
				0.24 + camada * 0.18, 0.0), Vector3(0.52, 0.17, 0.9), Color("dcd8cc"), giro)
	ob.despejar(sup)


## Monte de areia ou brita dentro da baia: duas aguas e as duas pontas.
static func _monte(ob: Obra, pe: Vector3, lateral: Vector3, normal: Vector3, larg: float,
		fundo: float, alto: float, mat: StringName, cor: Color) -> void:
	var l := lateral * (larg * 0.5)
	var f := normal * (fundo * 0.5)
	var topo := pe + Vector3(0.0, alto, 0.0)
	for lado: float in [-1.0, 1.0]:
		var n := (normal * lado * alto + Vector3.UP * fundo * 0.5).normalized()
		ob.quadra(mat, topo - l * 0.7, topo + l * 0.7, pe + l + f * lado, pe - l + f * lado, n, lateral,
			pe, cor)
		var nl := (lateral * lado).normalized()
		ob.triangulo(mat, topo + l * 0.7 * lado, pe + l * lado + f, pe + l * lado - f, nl + Vector3.UP * 0.3,
			cor.darkened(0.06))
