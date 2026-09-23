## Onde cada produto fica na loja. Dados puros; roda na thread.
##
## PLANO_MERCADO_AAA, 4.2. "Bem mapeado" quer dizer que TODA posicao de TODA
## prateleira responde "o que tem aqui, quanto custa, quantos restam", e que e
## a mesma resposta para o freguês, para o jogador, para a etiqueta e para a
## tarefa de repor. Essa resposta e esta tabela.
##
## Hierarquia
## ----------
##   face    um plano de prateleira que se olha de frente: um lado de ilha, uma
##           ponta, a parede, a geladeira, o expositor de cigarro, um degrau do
##           baleiro. Tem origem, eixo (para a direita de quem olha), normal
##           (para quem olha), comprimento e os niveis.
##   modulo  um metro de face, mais ou menos: e a unidade em que a loja pensa
##           a categoria ("este metro e cafe").
##   nivel   a altura de uma prateleira.
##   vaga    um produto num nivel: `frentes` colunas lado a lado, cada coluna
##           com ate `fundo` unidades uma atras da outra.
##
## A regra da loja de verdade
## --------------------------
## Pesado embaixo; o que nao cabe na altura livre nao entra; cerveja na
## geladeira do fundo e salgadinho na ponta de gondola que olha para ela; doce
## e chiclete no caixa; cigarro atras do balcao, onde so o atendente alcanca; o
## panetone de novembro na ponta que se ve da porta. Semente diferente, loja
## arrumada diferente — as regras ficam, a arrumacao muda.
##
## Coordenadas de PLANTA (as do MercadoBuilder).
class_name Planograma
extends RefCounted

const Onde := CatalogoMercado.Onde

enum Tipo { GONDOLA, GELADEIRA, CIGARRO, BALEIRO }

# --- os niveis (quem monta o movel le daqui) ---------------------------------

## Topo de cada prateleira da ilha, do chao para cima. O ultimo nivel vai ate
## a testeira. Com 33 cm livres embaixo o refrigerante de dois litros cabe so
## no chao e no alto — e o "pesado embaixo" sai da propria medida.
const NIVEIS_ILHA: Array[float] = [0.12, 0.47, 0.80, 1.10]
const NIVEIS_PAREDE: Array[float] = [0.12, 0.47, 0.80, 1.13, 1.46]
const NIVEIS_GELADEIRA: Array[float] = [0.12, 0.54, 0.96, 1.38]
## Profundidade util de uma prateleira, da beira ao fundo.
const PROF_ILHA := 0.40
const PROF_PAREDE := 0.44
const PROF_GELADEIRA := 0.58
## Quanto a cabeceira de uma ilha avanca alem do comprido dela: a prateleira da
## ponta mais a chapa que a separa das laterais.
const PONTA_ILHA := PROF_ILHA + 0.03
## Espessura da prateleira: o produto de cima nao pode encostar nela.
const CHAPA := 0.03
## O produto da frente fica este tanto atras da beira da prateleira.
const RECUO := 0.012
## Folga entre duas colunas, e entre o produto e a prateleira de cima.
const FOLGA := 0.006
const FOLGA_ALTURA := 0.015

## A geladeira: portas e quanto a caixa tem de fundo por dentro.
## Catorze portas de 74 cm: a de 1,3 m, aberta, varria a ponta da gondola.
const PORTAS_GELADEIRA := 14
const GELADEIRA_X0 := 6.6

## O expositor de cigarro atras do balcao (ver `KitMercado.expositor_cigarro`).
const CIGARRO_CENTRO := Vector3(MercadoBuilder.DIVISA + MercadoBuilder.MEIA + 0.1, 1.28, 3.2)
const CIGARRO_COMPRIMENTO := 2.4
const CIGARRO_FILEIRAS := 5
const CIGARRO_ALTO := 0.86
const CIGARRO_PROF := 0.2

## O baleiro, na frente da registradora (ver `KitMercado.expositor_balas`).
const BALEIRO_BASE := Vector3(MercadoBuilder.BALCAO_X + 0.12,
	KitMercado.ALTURA_BALCAO + 0.05, 4.35)


## As faces da loja, na ordem em que o jogador as encontra.
static func faces() -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var z0 := MercadoBuilder.ILHA_Z0
	var z1 := MercadoBuilder.ILHA_Z1
	var meia := KitMercado.PROF_GONDOLA * 0.5
	var ilha_cats := [
		# ilha 1, a do balcao: oeste olha o caixa, leste o corredor do meio
		[[&"biscoito", &"biscoito", &"biscoito", &"doce", &"doce"],
			[&"mercearia", &"mercearia", &"mercearia", &"mercearia", &"mercearia"]],
		# ilha 2, de frente para a porta
		[[&"matinal", &"matinal", &"matinal", &"mercearia", &"mercearia"],
			[&"higiene", &"higiene", &"higiene", &"higiene", &"higiene"]],
		# ilha 3
		[[&"limpeza", &"limpeza", &"limpeza", &"limpeza", &"limpeza"],
			[&"limpeza", &"higiene", &"farmacia", &"utilidade", &"limpeza"]],
	]
	# Pontas: a da porta vende o que a loja quer vender; a do fundo olha a
	# cerveja e vende o que se come com ela.
	var ponta_porta := [[&"agua_suco"], [&"padaria_festa"], [&"limpeza"]]
	var ponta_fundo := [[&"salgadinho"], [&"salgadinho"], [&"farmacia", &"utilidade"]]
	for i in MercadoBuilder.ILHAS.size():
		var x: float = MercadoBuilder.ILHAS[i]
		# Oeste: quem olha esta a -X, olhando +X; a direita dele e +Z. O eixo e
		# sempre UP x normal, e a origem e a ponta ESQUERDA de quem olha.
		saida.append(_face(Tipo.GONDOLA, Vector3(x - meia, 0.0, z0), Vector3(0, 0, 1),
			Vector3(-1, 0, 0), z1 - z0, NIVEIS_ILHA, KitMercado.ALTURA_GONDOLA,
			PROF_ILHA, Onde.PRATELEIRA, ilha_cats[i][0], "ilha %d oeste" % (i + 1)))
		saida.append(_face(Tipo.GONDOLA, Vector3(x + meia, 0.0, z1), Vector3(0, 0, -1),
			Vector3(1, 0, 0), z1 - z0, NIVEIS_ILHA, KitMercado.ALTURA_GONDOLA,
			PROF_ILHA, Onde.PRATELEIRA, ilha_cats[i][1], "ilha %d leste" % (i + 1)))
		saida.append(_face(Tipo.GONDOLA, Vector3(x + meia, 0.0, z0 - PONTA_ILHA), Vector3(-1, 0, 0),
			Vector3(0, 0, -1), meia * 2.0, NIVEIS_ILHA, KitMercado.ALTURA_GONDOLA,
			PROF_ILHA, Onde.PRATELEIRA, [ponta_porta[i]], "ilha %d ponta da porta" % (i + 1)))
		saida.append(_face(Tipo.GONDOLA, Vector3(x - meia, 0.0, z1 + PONTA_ILHA), Vector3(1, 0, 0),
			Vector3(0, 0, 1), meia * 2.0, NIVEIS_ILHA, KitMercado.ALTURA_GONDOLA,
			PROF_ILHA, Onde.PRATELEIRA, [ponta_fundo[i]], "ilha %d ponta do fundo" % (i + 1)))

	# Parede leste: bebida quente embaixo, pao no meio, destilado no alto.
	var pl := parede_leste()
	saida.append(_face(Tipo.GONDOLA, Vector3(pl.x, 0.0, pl.y),
		Vector3(0, 0, 1), Vector3(-1, 0, 0), pl.z, NIVEIS_PAREDE,
		KitMercado.ALTURA_GONDOLA_PAREDE, PROF_PAREDE, Onde.PRATELEIRA,
		[&"bebida_quente", &"bebida_quente", &"padaria", &"padaria", &"agua_suco",
			&"destilado", &"destilado"], "parede leste"))
	# Divisa: farmacia e utilidade, a um passo do caixa.
	var dv := parede_divisa()
	saida.append(_face(Tipo.GONDOLA, Vector3(dv.x, 0.0, dv.y + dv.z * 0.5),
		Vector3(0, 0, -1), Vector3(1, 0, 0), dv.z, NIVEIS_PAREDE,
		KitMercado.ALTURA_GONDOLA_PAREDE, PROF_PAREDE, Onde.PRATELEIRA,
		[&"farmacia", &"utilidade", &"higiene"], "divisa"))

	# Geladeira: laticinio no canto do caixa, refrigerante, agua e cerveja no fim.
	var comp := MercadoBuilder.LARGURA - GELADEIRA_X0
	var zg := MercadoBuilder.FUNDO_SALAO - MercadoBuilder.MEIA - 0.72
	saida.append(_face(Tipo.GELADEIRA, Vector3(MercadoBuilder.LARGURA, 0.0, zg + 0.02),
		Vector3(-1, 0, 0), Vector3(0, 0, -1), comp, NIVEIS_GELADEIRA, 2.0,
		PROF_GELADEIRA, Onde.GELADEIRA,
		[&"laticinio", &"laticinio", &"refrigerante", &"refrigerante", &"agua_suco",
			&"cerveja", &"cerveja", &"cerveja"], "geladeira"))

	# Cigarro: atras do balcao, cinco fileiras de maco.
	var cb := Basis(Vector3.UP, PI * 0.5)
	var niveis_cig: Array[float] = []
	var passo := (CIGARRO_ALTO - 0.08) / float(CIGARRO_FILEIRAS)
	for f in CIGARRO_FILEIRAS:
		niveis_cig.append(0.04 + passo * float(f))
	saida.append(_face(Tipo.CIGARRO,
		CIGARRO_CENTRO + cb * Vector3(-CIGARRO_COMPRIMENTO * 0.5, 0.0, CIGARRO_PROF * 0.5),
		cb * Vector3.RIGHT, cb * Vector3.BACK, CIGARRO_COMPRIMENTO, niveis_cig,
		CIGARRO_ALTO, CIGARRO_PROF - 0.02, Onde.BALCAO, [&"cigarro"], "cigarro"))
	# Baleiro: tres degraus, um por face.
	for degrau in 3:
		var y := 0.08 + float(degrau) * 0.07
		var z := 0.07 - float(degrau) * 0.07 + 0.04
		var nv: Array[float] = [0.0]
		saida.append(_face(Tipo.BALEIRO,
			BALEIRO_BASE + cb * Vector3(-0.225, y, z), cb * Vector3.RIGHT, cb * Vector3.BACK,
			0.45, nv, 0.14, 0.078, Onde.CAIXA,
			[[&"bala"], [&"doce", &"bala"], [&"doce"]][degrau], "baleiro %d" % degrau))
	for i in saida.size():
		saida[i]["id"] = i
	return saida


## A prateleira da parede leste: (x da face, z da ponta sul, comprimento).
static func parede_leste() -> Vector3:
	return Vector3(MercadoBuilder.LARGURA - 0.5, 1.6, 7.6)


## A da divisa: (x da face, z do centro, comprimento).
static func parede_divisa() -> Vector3:
	return Vector3(MercadoBuilder.DIVISA + MercadoBuilder.MEIA + 0.5, 8.9, 2.6)


static func _face(tipo: Tipo, origem: Vector3, eixo: Vector3, normal: Vector3,
		comprimento: float, niveis: Array[float], teto: float, prof: float,
		onde: Onde, cats: Array, nome: String) -> Dictionary:
	return {
		"tipo": tipo, "origem": origem, "eixo": eixo, "normal": normal,
		"comprimento": comprimento, "niveis": niveis, "teto": teto, "prof": prof,
		"onde": onde, "cats": cats, "nome": nome,
		# O jogador pega sozinho em tudo, menos no que fica atras do balcao.
		"alcance": onde != Onde.BALCAO,
	}


## Categorias que sao mais de uma. "bebida_quente" e o refrigerante e a agua
## fora da geladeira; "padaria_festa" e a ponta do panetone.
const GRUPOS := {
	&"bebida_quente": [&"refrigerante", &"agua_suco"],
	&"padaria_festa": [&"padaria"],
}


## A loja inteira arrumada. `{faces, vagas}`.
static func montar(semente: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([semente, "planograma"])
	var fs := faces()
	var vagas: Array[Dictionary] = []
	for f: Dictionary in fs:
		_preencher(f, vagas, rng)
	return {"faces": fs, "vagas": vagas}


static func _candidatos(cat: StringName, onde: int) -> Array[StringName]:
	var cats: Array = GRUPOS.get(cat, [cat])
	var saida: Array[StringName] = []
	for c: StringName in cats:
		for id: StringName in CatalogoMercado.da_categoria(c):
			if CatalogoMercado.cabe_em(id, onde):
				saida.append(id)
	return saida


## Volume em litros: o "pesado" da regra de altura.
static func _litros(id: StringName) -> float:
	var m := CatalogoMercado.medida(id)
	return m.x * m.y * m.z * 1000.0


static func _preencher(f: Dictionary, vagas: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	var cats: Array = f["cats"]
	var modulos := cats.size()
	var comp: float = f["comprimento"]
	var largura_modulo := comp / float(modulos)
	var niveis: Array[float] = f["niveis"]
	var tipo: int = f["tipo"]
	var usados: Dictionary = {}
	for m in modulos:
		var cat_mod: Variant = cats[m]
		var lista_cats: Array = cat_mod if cat_mod is Array else [cat_mod]
		var candidatos: Array[StringName] = []
		for c: StringName in lista_cats:
			candidatos.append_array(_candidatos(c, int(f["onde"])))
		if candidatos.is_empty():
			continue
		var x_ini := float(m) * largura_modulo
		for n in niveis.size():
			var y: float = niveis[n]
			var livre: float = (niveis[n + 1] - CHAPA if n + 1 < niveis.size()
				else float(f["teto"])) - y - FOLGA_ALTURA
			var cabem: Array[StringName] = []
			for id: StringName in candidatos:
				var md := CatalogoMercado.medida(id)
				if md.y <= livre and md.z <= float(f["prof"]):
					cabem.append(id)
			if cabem.is_empty():
				continue
			# Pesado embaixo, e o que ja apareceu neste modulo por ultimo.
			var nota := func(id: StringName) -> float:
				var peso := minf(_litros(id), 3.0) / 3.0
				var alto := float(n) / maxf(1.0, float(niveis.size() - 1))
				return rng.randf() * 0.6 + peso * alto * 1.2 \
					+ float(usados.get(id, 0)) * 0.8
			var notas: Dictionary = {}
			for id: StringName in cabem:
				notas[id] = nota.call(id)
			cabem.sort_custom(func(a: StringName, b: StringName) -> bool:
				return float(notas[a]) < float(notas[b]))
			var x := x_ini + 0.015
			var fim := x_ini + largura_modulo - 0.015
			var k := 0
			while k < cabem.size() * 2:
				var id: StringName = cabem[k % cabem.size()]
				k += 1
				var md := CatalogoMercado.medida(id)
				var passo := md.x + FOLGA
				if x + passo > fim:
					# O que sobrou nao cabe esse; tenta um mais estreito.
					continue
				var quer := rng.randf_range(0.16, 0.42)
				if tipo == Tipo.CIGARRO:
					quer = rng.randf_range(0.2, 0.36)
				elif tipo == Tipo.BALEIRO:
					quer = rng.randf_range(0.07, 0.14)
				var frentes := clampi(roundi(quer / passo), 1, 10)
				frentes = mini(frentes, int((fim - x) / passo))
				if frentes <= 0:
					continue
				var fundo := clampi(int((float(f["prof"]) - RECUO) / (md.z + FOLGA)), 1, 14)
				var colunas := PackedInt32Array()
				# Loja de madrugada: quase cheia, nunca perfeita. Uma coluna em
				# oito ja foi mexida, e uma vaga em trinta acabou.
				var acabou := rng.randf() < 0.035
				for c in frentes:
					var q := fundo
					if acabou:
						q = 0
					elif rng.randf() < 0.13:
						q = rng.randi_range(1, fundo)
					colunas.append(q)
				vagas.append({
					"face": int(f["id"]), "nivel": n, "x0": x, "sku": id,
					"frentes": frentes, "passo": passo, "fundo": fundo,
					"colunas": colunas,
				})
				usados[id] = int(usados.get(id, 0)) + 1
				x += passo * float(frentes) + 0.01


# --- geometria das vagas ------------------------------------------------------

## A base da unidade da FRENTE de uma coluna, em coordenada de planta.
static func base_da_coluna(f: Dictionary, v: Dictionary, coluna: int,
		atras: int = 0) -> Vector3:
	var md := CatalogoMercado.medida(v["sku"])
	var niveis: Array[float] = f["niveis"]
	var along := float(v["x0"]) + float(v["passo"]) * (float(coluna) + 0.5)
	var dentro := RECUO + md.z * 0.5 + float(atras) * (md.z + FOLGA)
	return Vector3(f["origem"]) + Vector3(f["eixo"]) * along \
		+ Vector3.UP * niveis[int(v["nivel"])] - Vector3(f["normal"]) * dentro


## A base que gira a malha unitaria (frente +Z) para olhar a normal da face.
static func base_de(f: Dictionary) -> Basis:
	var n: Vector3 = f["normal"]
	return Basis(Vector3(f["eixo"]), Vector3.UP, n)


## A etiqueta de uma vaga: centro e tamanho, pendurada na beira da prateleira.
static func etiqueta(f: Dictionary, v: Dictionary) -> Transform3D:
	var niveis: Array[float] = f["niveis"]
	var along := float(v["x0"]) + minf(0.045, float(v["passo"]) * float(v["frentes"]) * 0.5)
	var p := Vector3(f["origem"]) + Vector3(f["eixo"]) * along \
		+ Vector3.UP * (niveis[int(v["nivel"])] - 0.034) + Vector3(f["normal"]) * 0.004
	var b := base_de(f)
	return Transform3D(Basis(b.x * 0.068, b.y * 0.03, b.z), p)


## Ponto da face em coordenada propria: (ao longo, altura), a partir da origem.
static func na_face(f: Dictionary, p: Vector3) -> Vector2:
	var d := p - Vector3(f["origem"])
	return Vector2(d.dot(Vector3(f["eixo"])), d.y)


## A coluna sob um ponto da face, com aderencia.
##
## Nivel: a prateleira cujo vao contem a altura. Coluna: a mais proxima ao
## longo da face DENTRO daquele nivel, entre as que `aceita` deixa — e a lição
## da carteira do balcao: a mira gruda no produto, nao exige acertar o pixel.
## Devolve [indice da vaga, coluna], ou [-1, -1]. `aceita(vaga, coluna)`.
static func coluna_no_ponto(f: Dictionary, vagas_da_face: Array, vagas: Array,
		ponto: Vector2, aceita: Callable, alcance: float = 0.35) -> Vector2i:
	var niveis: Array[float] = f["niveis"]
	var nivel := -1
	for n in niveis.size():
		var topo: float = niveis[n + 1] - CHAPA if n + 1 < niveis.size() else float(f["teto"])
		if ponto.y >= niveis[n] - 0.05 and ponto.y < topo:
			nivel = n
	if nivel < 0:
		return Vector2i(-1, -1)
	var melhor := Vector2i(-1, -1)
	var menor := alcance
	for vi: int in vagas_da_face:
		var v: Dictionary = vagas[vi]
		if int(v["nivel"]) != nivel:
			continue
		for c in int(v["frentes"]):
			var centro := float(v["x0"]) + float(v["passo"]) * (float(c) + 0.5)
			var d := absf(centro - ponto.x)
			if d < menor and aceita.call(v, c):
				menor = d
				melhor = Vector2i(vi, c)
	return melhor
