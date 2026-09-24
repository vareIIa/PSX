## Monta o conteudo de um chunk a partir da coordenada, de forma deterministica.
##
## Nao instancia nada e nao toca no servidor de renderizacao: devolve dados de
## superficie fundidos por material, mais listas de props e de colisao para a
## thread principal materializar. Todo o custo pesado, que e gerar e fundir
## vertices, fica fora da thread principal.
##
## Onde fica cada decisao
## ----------------------
##   MalhaUrbana    onde passa rua, onde termina a quadra, o que a quadra e
##   ChunkBuilder   como isso vira chao, massa de predio e props
##   ParqueBuilder  o que preenche a quadra quando ela e parque
##
## A separacao existe por causa do mapa. O minimapa desenha um bairro inteiro de
## 400 m sem montar um triangulo, porque pergunta a MalhaUrbana em vez de pedir o
## chunk. Se a malha morasse aqui, abrir o mapa custaria segundos.
##
## Chunks de 32 m. As ruas nao estao mais em toda fronteira par: a malha e
## irregular por construcao, com avenida a cada 160 m e uma secundaria sorteada
## entre elas. Um chunk pode ter rua nos dois eixos, num so, ou em nenhum — este
## ultimo e miolo de quadra grande, onde o jogador nunca pisa.
class_name ChunkBuilder
extends RefCounted

const TAM := KitModular.CHUNK
## Profundidade de um predio. O resto do quarteirao e patio fechado.
const PROF_PREDIO := 8.0
## Quanto a fachada fica a frente da massa do predio. A parede desenhada sobre
## ela (vitrine, janela) ganha mais 6 cm por cima disso, e o que evita z-fight.
const AVANCO_FACHADA := 0.06
## Face minima para caber uma porta de entrada.
const FACE_MINIMA := 12.0


## Resultado de um chunk. Campos:
##   superficies  Dictionary[StringName, Dictionary]  geometria fundida
##   props        Array[Dictionary]                   lampadas e afins
##   colisao      Array[Dictionary]                   caixas estaticas
##   triangulos   int
static func construir(cx: int, cz: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	# Semente derivada da coordenada. Numeros primos grandes evitam que chunks
	# em diagonal caiam na mesma sequencia.
	rng.seed = hash(Vector2i(cx, cz)) ^ (cx * 73856093) ^ (cz * 19349663)

	var sup: Dictionary = {}
	var props: Array[Dictionary] = []
	var colisao: Array[Dictionary] = []

	var bordas := MalhaUrbana.bordas(cx, cz)
	var quadra := MalhaUrbana.quadra_de(cx, cz)
	var limites := area_util(cx, cz)

	_solo(sup, colisao, cx, cz, bordas, limites, rng)
	# Frestas pro limbo entre as pecas do chao (Costura): junta em T na borda do
	# cruzamento e da calcada, e saia na borda do chunk. Ainda no plano, antes
	# do relevo: o assentar leva os vertices novos junto com os outros.
	Costura.costurar(sup, TAM)
	# Ladeira (Relevo). Chunk no plano segue o caminho antigo, intocado. No
	# inclinado o chao acompanha o terreno vertice a vertice, e as caixas de
	# laje dao lugar a um mapa de alturas — montado no fim, porque o salao do bar
	# e a casa da fumaca abrem buraco nele.
	var inclinado := not Relevo.plano(cx, cz)
	if inclinado:
		Relevo.assentar(sup, {}, colisao, 0, props, 0, cx, cz)
		_escadarias(sup, colisao, cx, cz, bordas)
	var lotes: Array[Dictionary] = []
	var andares := _quadra(sup, props, colisao, cx, cz, bordas, quadra, limites, rng,
		lotes)
	# A grama do parque entra depois da costura do `_solo` e encosta na calcada
	# em junta em T: no PS1 a fresta pisca limbo (Costura.soldar, sem saia).
	if int(quadra["uso"]) == MalhaUrbana.Uso.PARQUE:
		Costura.soldar(sup, [&"grama", &"calcada"])
	_props(sup, props, colisao, cx, cz, bordas, quadra, limites, rng, andares, lotes)
	var serpentina := bool(quadra.get("serpentina", false))
	if serpentina:
		# A rua em curva da celula de encosta, as casas dela e o pasto
		# (SerpentinaBuilder), com altura absoluta: depois de tudo assentado.
		SerpentinaBuilder.construir(sup, colisao, props, cx, cz, quadra,
			faces_de_rua(bordas, limites).is_empty())
	if inclinado:
		var rebaixar: Array[Rect2] = []
		for l: Dictionary in lotes:
			if l.has("piso"):
				rebaixar.append(l["piso"])
		colisao.append(Relevo.mapa_de_colisao(cx, cz, bordas, limites,
			int(quadra["uso"]) == MalhaUrbana.Uso.PARQUE, rebaixar,
			SerpentinaBuilder.caminho_local(cx, cz) if serpentina else PackedVector2Array()))
	# Chunk plano (so com `--sem-relevo`) fica com o chao de caixas, e a pista da
	# serpentina, cinco centimetros acima da laje, e so desenho: pisa-se na laje.

	var tris := 0
	for mat: StringName in sup:
		tris += PSXMesh.dados_triangulos(sup[mat])
	# A loja de conveniencia e oca no terreo: o chao da quadra, que seguiu o
	# relevo, desce para baixo do piso dela (PredioMercado.afundar_chao).
	for l: Dictionary in lotes:
		if l.has("piso_y"):
			PredioMercado.afundar_chao(sup, l["piso"], float(l["piso_y"]))
		# O mesmo para a casa, a loja e o galpao do sistema novo: na ladeira o chao da
		# quadra, que segue o relevo, passava por dentro do lote rigido e aparecia no
		# comodo da janela aberta e no salao da loja (metade dos lotes tinha algum
		# canto mais de 30 cm acima do piso). Chave propria, e nao "piso": essa tambem
		# rebaixa a colisao e vira pegada para o muro do quintal.
		if l.has("rebaixo_y"):
			# RebaixoDoLote, e nao o afundar_chao da loja: aquele deixava junta em T
			# no vizinho do lado de baixo do morro, e o PS1 piscava o limbo ali.
			RebaixoDoLote.afundar(sup, l["rebaixo"], float(l["rebaixo_y"]),
				RebaixoDoLote.MATERIAIS, bool(l.get("rebaixo_emenda", true)))

	# As lojas de verdade do chunk (LojaViva): o teste de loja e o mapa leem daqui,
	# sem varrer a cena. `boca` e local do chunk, no plano da fachada, no chao
	# antes da ladeira (a altura do piso e a dos props).
	var lojas: Array[Dictionary] = []
	for l: Dictionary in lotes:
		if l.has("loja"):
			lojas.append({"id": l["loja"], "ramo": l["loja_ramo"], "boca": l["loja_boca"],
				"normal": l["loja_normal"], "largura": float(l["ate"]) - float(l["de"])})

	return {
		"superficies": sup,
		"props": props,
		"colisao": colisao,
		"triangulos": tris,
		"lojas": lojas,
	}


## Retangulo do chunk, em coordenada local, onde a quadra pode ocupar.
##
## Publica porque tres lugares precisam concordar sobre ela: o chao, que desenha
## a calcada ate essa borda; a fileira de predios, que comeca nela; e o mapa, que
## pinta o miolo da quadra.
static func area_util(cx: int, cz: int) -> Rect2:
	var b := MalhaUrbana.bordas(cx, cz)
	var quadra := MalhaUrbana.quadra_de(cx, cz)
	# O recuo extra da quadra vira calcada mais larga, e nao um vazio: e assim
	# que quadra recuada continua tendo por onde andar. Parque nao recua — o
	# gradil dele ja e o limite, e recuar so afastaria o parque da rua.
	var extra := float(quadra["recuo_extra"]) 		if int(quadra["uso"]) == MalhaUrbana.Uso.EDIFICADO else 0.0

	var x0 := MalhaUrbana.recuo(b["x0"])
	var x1 := MalhaUrbana.recuo(b["x1"])
	var z0 := MalhaUrbana.recuo(b["z0"])
	var z1 := MalhaUrbana.recuo(b["z1"])
	if x0 > 0.0:
		x0 += extra
	if x1 > 0.0:
		x1 += extra
	if z0 > 0.0:
		z0 += extra
	if z1 > 0.0:
		z1 += extra
	return Rect2(x0, z0, TAM - x0 - x1, TAM - z0 - z1)


## O chunk tem poste de iluminacao, e onde.
##
## Publica e deterministica de proposito: o chunk vizinho precisa da posicao para
## desenhar o cabo que atravessa a fronteira, sem que os dois estejam carregados
## ao mesmo tempo.
##
## Viela nao ganha poste. E o unico lugar escuro de uma cidade iluminada a sodio,
## e essa e a razao de ela existir.
static func tem_poste(cx: int, cz: int) -> bool:
	var b := MalhaUrbana.bordas(cx, cz)
	for chave: String in b:
		var v: MalhaUrbana.Via = b[chave]
		if v == MalhaUrbana.Via.RUA or v == MalhaUrbana.Via.AVENIDA:
			return true
	return false


## O pe do poste no mundo, ja no chao do morro (Relevo).
static func posicao_poste(cx: int, cz: int) -> Vector3:
	var p := _poste_local(MalhaUrbana.bordas(cx, cz)) + Vector3(cx * TAM, 0.0, cz * TAM)
	p.y += Relevo.altura(p.x, p.z)
	return p


## Posicao do poste em coordenada local. Separada porque o chao precisa dela sem
## conhecer a coordenada do chunk, para nao plantar arvore em cima do poste.
static func _poste_local(b: Dictionary) -> Vector3:
	var x := 10.0
	var z := 12.0
	# meia_asfalto, e nao meia_pista: o meio-fio de verdade fica depois da
	# faixa de estacionamento/acostamento, nao na borda da pista de rolamento.
	# Com meia_pista o poste nascia dentro do acostamento, no meio da rua.
	var em_x := false
	var em_z := false
	if _iluminada(b["x0"]):
		x = MalhaUrbana.meia_asfalto(b["x0"]) + 0.8
		em_x = true
	elif _iluminada(b["x1"]):
		x = TAM - MalhaUrbana.meia_asfalto(b["x1"]) - 0.8
		em_x = true
	if _iluminada(b["z0"]):
		z = MalhaUrbana.meia_asfalto(b["z0"]) + 0.8
		em_z = true
	elif _iluminada(b["z1"]):
		z = TAM - MalhaUrbana.meia_asfalto(b["z1"]) - 0.8
		em_z = true
	# Com as duas bordas iluminadas as duas contas acima batem na MESMA quina, e
	# a quina ja e do cruzamento: o poste nascia em cima do semaforo e dentro da
	# faixa de pedestre. Encostado no meio de uma das vias ele ilumina a mesma
	# calcada sem disputar espaco com nada.
	if em_x and em_z:
		z = TAM * 0.5
	return Vector3(x, KitModular.ALTURA_MEIO_FIO, z)


static func _iluminada(v: MalhaUrbana.Via) -> bool:
	return v == MalhaUrbana.Via.RUA or v == MalhaUrbana.Via.AVENIDA


# --- pontos de interesse ----------------------------------------------------

## Tudo que o mapa precisa saber do chunk, sem montar um triangulo.
##
## Esta funcao e a fonte unica: `_props` chama a mesma coisa para POR a porta no
## mundo. Se o mapa tivesse a copia dele da regra, os dois divergiriam no
## primeiro ajuste e o icone da loja pousaria numa parede.
##
## Posicoes em coordenada LOCAL do chunk, igual aos props.
static func pontos_de_interesse(cx: int, cz: int) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var quadra := MalhaUrbana.quadra_de(cx, cz)
	var uso := int(quadra["uso"])

	if uso == MalhaUrbana.Uso.PARQUE:
		# So o chunk que contem o centro da quadra anuncia o parque, senao o
		# mapa ganharia vinte e cinco icones em cima do mesmo gramado.
		var centro := MalhaUrbana.centro_da_quadra(quadra)
		var local := centro - Vector3(cx * TAM, 0.0, cz * TAM)
		if local.x >= 0.0 and local.x < TAM and local.z >= 0.0 and local.z < TAM:
			saida.append({
				"tipo": &"parque",
				"pos": local,
				"nome": ParqueBuilder.planta(quadra)["nome"],
			})

	var porta := _porta_do_chunk(cx, cz, quadra)
	if not porta.is_empty():
		saida.append(porta)

	# Telefone publico. Raro e sempre no mesmo lugar para a coordenada dada, para
	# o jogador conseguir memorizar onde ficam.
	if posmod(cx * 53 + cz * 59, 11) == 0 and tem_poste(cx, cz):
		var face := _face_de_rua(cx, cz)
		if not face.is_empty():
			var direcao: int = face["direcao"]
			var normal := KitModular._normal(direcao)
			var pos: Vector3 = Vector3(face["a"]).lerp(Vector3(face["b"]), 0.5) 				+ normal * 1.1
			# Na frente da loja de conveniencia o meio da face pode cair diante do
			# portao da garagem. O orelhao vai para a frente da vitrine, entre a
			# porta e a quina: e onde ele fica em toda loja de bairro.
			if not porta.is_empty() and porta.get("interior", &"") == &"mercado" \
					and bool(porta.get("mundo", false)):
				var em: Transform3D = porta["planta"]
				pos = em * Vector3(14.6, 0.0, -MercadoBuilder.PAREDE) + normal * 1.05
			pos.y = KitModular.ALTURA_MEIO_FIO
			saida.append({
				"tipo": &"telefone",
				"pos": pos,
				# O aparelho fica de costas para a parede, olhando para a rua.
				"giro": atan2(normal.x, normal.z),
				# Pelo nome da rua em que ele esta, e nao pelo indice do chunk.
				"local": "Telefone da %s" % _rua_ou_quadra(pos + Vector3(cx * TAM,
					0.0, cz * TAM), cx, cz),
			})

	# Na ladeira (Relevo) o ponto fica no chao de onde esta. Aqui, e nao em
	# `_props`: o mapa e o mundo leem a mesma posicao, e a porta anunciada cai
	# na porta que existe. O lote dela subiu pela mesma altura (`_fileira`).
	for p: Dictionary in saida:
		var chao := Relevo.local(cx, cz, p["pos"])
		p["pos"] = Vector3(p["pos"]) + Vector3(0.0, chao, 0.0)
		if p.has("base_kit"):
			p["base_kit"] = Vector3(p["base_kit"]) + Vector3(0.0, chao, 0.0)
	return saida


## O nome da rua mais perto, ou o indice da quadra onde nao ha rua.
static func _rua_ou_quadra(mundo: Vector3, cx: int, cz: int) -> String:
	var rua := NomesDeRua.rua_perto(mundo)
	return rua if not rua.is_empty() else "quadra %d-%d" % [absi(cx), absi(cz)]


## A porta de entrada do chunk, se houver. Dicionario vazio quando nao ha.
##
## Uma a cada tres chunks: se toda fachada tivesse porta o jogador pararia de
## reparar nelas, e entrar num apartamento deixaria de ser um evento.
static func _porta_do_chunk(cx: int, cz: int, quadra: Dictionary) -> Dictionary:
	if int(quadra["uso"]) != MalhaUrbana.Uso.EDIFICADO:
		return {}
	if posmod(cx * 5 + cz * 11, 3) != 0:
		return {}

	var face := _face_de_rua(cx, cz)
	if face.is_empty():
		return {}

	# Que lugar tem atras desta porta. Amarrar a planta ao distrito e o que faz
	# cada lugar ser um lugar e nao um sorteio: quem anda por uma rua residencial
	# aprende que ali da para entrar em casa, e quem procura uma loja aprende a
	# procurar no comercio.
	#
	# A loja de conveniencia e rara dentro do proprio comercio, uma porta em cada
	# quatro. Uma em cada esquina deixaria de ser um destino.
	var planta: StringName = &"apartamento"
	if bool(quadra["casa"]):
		# Uma casa em cada cinco e a casa da fumaca. Rara pelo mesmo motivo da
		# loja: o lugar so tem peso enquanto for um achado. Numa esquina sim e
		# na outra tambem, deixa de ser a casa e vira o padrao da cidade.
		planta = &"casa_fumaca" if posmod(cx * 31 + cz * 13, 5) == 0 else &"casa"
	elif bool(quadra["conveniencia"]):
		# A loja EXISTE atras da vitrine (PLANO_MERCADO_AAA, F1), e por isso so
		# nasce onde o lote dela cabe inteiro — 17,5 m de frente, 16,5 de fundo.
		# Onde nao cabe, a porta e de outra coisa, e nunca teleportada. Uma em tres
		# e nao uma em quatro: compensa as esquinas que perderam a loja.
		if posmod(cx * 17 + cz * 23, 3) == 0 \
				and not _lote_do_mercado(cx, cz, face, quadra).is_empty():
			planta = &"mercado"
		elif posmod(cx * 41 + cz * 19, 6) == 0:
			# Uma porta de bar a cada seis comerciais que nao forem mercado.
			# elif garante que nunca cai na mesma fachada da HIKARI.
			planta = &"bar"

	# Sorteio proprio, e nao o fluxo do chunk: a posicao da porta precisa ser
	# calculavel pelo mapa sem montar o chunk inteiro, e um fluxo compartilhado
	# mudaria de valor a cada prop novo acrescentado antes dela.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77000 + cx * 419 + cz * 787
	var t := rng.randf_range(0.28, 0.72)

	var direcao: int = face["direcao"]
	var normal := KitModular._normal(direcao)
	var base: Vector3 = Vector3(face["a"]).lerp(Vector3(face["b"]), t)
	base += normal * 0.02
	base.y = KitModular.ALTURA_MEIO_FIO

	# A folha abre para fora, entao gira para encarar a rua.
	var giro := atan2(normal.x, normal.z)

	# A casa da fumaca EXISTE atras da porta.
	#
	# Ela ocupa um lote proprio na fileira (KitFumaca.lote_na_face), e a porta
	# deixa de ser sorteada: e a do vao da sala, calculavel pelo mapa sem montar
	# o chunk — o mesmo acordo do bar. Quando o lote nao cabe na face, a porta
	# continua sendo a de fachada, teleportada.
	if planta == &"casa_fumaca":
		var lote := KitFumaca.lote_na_face(face, MalhaUrbana.bordas(cx, cz))
		if not lote.is_empty():
			var em_planta := KitFumaca.planta_no_chunk(face, float(lote["inicio"]))
			return {
				"tipo": &"porta",
				"pos": KitFumaca.dobradica(em_planta),
				"giro": giro,
				"semente": 77000 + cx * 419 + cz * 787,
				"interior": planta,
				"deslizante": false,
				"direcao": direcao,
				"mundo": true,
				# Casa com gente: bate-se, e o dono abre (CasaViva).
				"espera_dono": true,
				"lote_inicio": float(lote["inicio"]),
				"planta": em_planta,
				"base_kit": KitFumaca.base_da_fachada(em_planta),
			}

	# A loja de conveniencia tambem existe atras da porta, e a porta e a do vao
	# da vitrine: o mesmo acordo da casa da fumaca. Quem monta o predio e
	# PredioMercado, a partir de `planta`; o mapa acha a porta sem montar nada.
	if planta == &"mercado":
		var lote_m := _lote_do_mercado(cx, cz, face, quadra)
		var em := LoteNoMundo.planta_no_chunk(&"mercado", face, float(lote_m["inicio"]))
		var vao := em * LoteNoMundo.centro_do_vao(&"mercado")
		vao.y = KitModular.ALTURA_MEIO_FIO
		return {
			"tipo": &"porta",
			"pos": vao,
			"giro": giro,
			"semente": 77000 + cx * 419 + cz * 787,
			"interior": planta,
			"deslizante": true,
			"direcao": direcao,
			"mundo": true,
			"lote_inicio": float(lote_m["inicio"]),
			"planta": em,
		}

	# O bar NAO e uma porta, e por isso nao sorteia posicao.
	#
	# Ele e o terreo vazado do primeiro trecho de predio da face, e o unico jeito
	# de o mapa apontar para a boca certa sem construir o chunk e calcular o
	# mesmo numero que `_predio_do_bar` vai usar: meia largura do trecho, medida
	# do canto da face. `face["a"]` ja vem recuado MARGEM do canto, entao o
	# deslocamento desconta esse recuo.
	if planta == &"bar":
		var comp_face := Vector3(face["a"]).distance_to(Vector3(face["b"])) + 8.0
		var eixo := (Vector3(face["b"]) - Vector3(face["a"])).normalized()
		base = Vector3(face["a"]) + eixo * (largura_do_bar(comp_face) * 0.5 - 4.0)
		base += normal * 0.02
		base.y = KitModular.ALTURA_MEIO_FIO
		return {
			"tipo": &"bar",
			"pos": base,
			"giro": giro,
			"semente": 88000 + cx * 419 + cz * 787,
			"interior": &"bar",
			"direcao": direcao,
		}

	return {
		"tipo": &"porta",
		"pos": base,
		"giro": giro,
		"semente": 77000 + cx * 419 + cz * 787,
		"interior": planta,
		"deslizante": planta == &"mercado",
		"direcao": direcao,
	}


## A face onde a porta de entrada cabe, com os dois extremos ja recuados.
##
## Sai de `faces_de_rua`, e nao de uma regra propria: a porta tem de nascer sobre
## uma fachada que existe. Com uma segunda copia da regra, a porta de esquina
## caia na lateral cega do predio da fileira do outro eixo.
static func _face_de_rua(cx: int, cz: int) -> Dictionary:
	const MARGEM := 4.0
	var faces := faces_de_rua(MalhaUrbana.bordas(cx, cz), area_util(cx, cz))
	for face: Dictionary in faces:
		var comp := float(face["comprimento"])
		if comp < FACE_MINIMA:
			continue
		var eixo: Vector3 = face["eixo"]
		var canto: Vector3 = face["canto"]
		return {
			"direcao": face["direcao"],
			"a": canto + eixo * MARGEM,
			"b": canto + eixo * (comp - MARGEM),
			# A face inteira, sem o recuo: e nela que o lote da casa da fumaca
			# se mede, e na mesma conta que `_fileira` faz.
			"canto": canto,
			"eixo": eixo,
			"comprimento": comp,
		}
	return {}


## Onde o lote da loja de conveniencia cai na face da porta. Vazio quando nao
## cabe — de frente, na esquina, ou de fundo (LoteNoMundo.lote_na_face).
##
## Sem rng, pelo mesmo motivo da porta: o mapa, o relevo e o beco perguntam isto
## sem montar o chunk. Na celula de serpentina nao ha loja: a rua dela corta a
## fileira pelo meio e o miolo e pasto.
static func _lote_do_mercado(cx: int, cz: int, face: Dictionary,
		quadra: Dictionary) -> Dictionary:
	if face.is_empty() or bool(quadra.get("serpentina", false)):
		return {}
	var lim := area_util(cx, cz)
	var fundo := lim.size.x if absf(Vector3(face["eixo"]).z) > 0.5 else lim.size.y
	return LoteNoMundo.lote_na_face(&"mercado", face, MalhaUrbana.bordas(cx, cz), fundo)


# --- solo -------------------------------------------------------------------

static func _solo(sup: Dictionary, colisao: Array[Dictionary], cx: int, cz: int,
		bordas: Dictionary, lim: Rect2, rng: RandomNumberGenerator) -> void:
	# Asfalto = rolamento + estacionamento. Faixas de carro continuam em
	# meia_pista; o acostamento fica na faixa externa ate o meio-fio.
	var px0 := MalhaUrbana.meia_asfalto(bordas["x0"])
	var px1 := MalhaUrbana.meia_asfalto(bordas["x1"])
	var pz0 := MalhaUrbana.meia_asfalto(bordas["z0"])
	var pz1 := MalhaUrbana.meia_asfalto(bordas["z1"])

	# A faixa do eixo X pega o comprimento todo do chunk, inclusive as esquinas;
	# a do eixo Z comeca depois dela. E assim que o cruzamento sai asfaltado uma
	# vez so, sem dois planos disputando o mesmo pixel.
	#
	# Cada trecho tem o proprio revestimento (MalhaUrbana.revestimento_x): rua
	# de pedra em bairro de casas, asfalto na avenida e no centro. A faixa do
	# eixo X e cortada em tres — quina, miolo, quina — porque a quina e do
	# cruzamento: se qualquer uma das duas ruas e de asfalto, ela e de asfalto.
	# Sem isso a rua asfaltada passava por um remendo de pedra em todo lugar onde
	# uma rua de pedra desembocava nela.
	var rev_z0 := MalhaUrbana.revestimento_z(cz, cx)
	var rev_z1 := MalhaUrbana.revestimento_z(cz + 1, cx)
	# Trecho que virou escadaria (Ladeira): o miolo nao tem pista, so os dois
	# patamares; os degraus entram depois do chao assentado (`_escadarias`).
	var escada := Ladeira.bordas_em_escada(cx, cz)
	if px0 > 0.0:
		if escada["x0"]:
			_faixa_x_em_escada(sup, 0.0, px0, pz0, pz1, MalhaUrbana.revestimento_x(cx, cz),
				_quina(cx, cz, cx), _quina(cx, cz + 1, cx), EscadariaBuilder.extensao_x(cx, cz))
		else:
			_faixa_x(sup, 0.0, px0, pz0, pz1, MalhaUrbana.revestimento_x(cx, cz),
				_quina(cx, cz, cx), _quina(cx, cz + 1, cx))
	if px1 > 0.0:
		if escada["x1"]:
			_faixa_x_em_escada(sup, TAM - px1, px1, pz0, pz1,
				MalhaUrbana.revestimento_x(cx + 1, cz), _quina(cx + 1, cz, cx),
				_quina(cx + 1, cz + 1, cx), EscadariaBuilder.extensao_x(cx + 1, cz))
		else:
			_faixa_x(sup, TAM - px1, px1, pz0, pz1,
				MalhaUrbana.revestimento_x(cx + 1, cz),
				_quina(cx + 1, cz, cx), _quina(cx + 1, cz + 1, cx))

	var larg_meio := TAM - px0 - px1
	if pz0 > 0.0 and larg_meio > 0.05:
		# O sorteio do remendo sai sempre, com escada ou sem: o rng do chunk nao
		# pode andar diferente (a maquina e o predio sorteiam depois).
		var remendo := rng.randf() < 0.18
		if escada["z0"]:
			_faixa_z_em_escada(sup, px0, TAM - px1, 0.0, pz0, rev_z0,
				EscadariaBuilder.extensao_z(cz, cx))
		else:
			KitModular.rua(sup, Vector3(px0, 0.0, 0.0), Vector2(larg_meio, pz0),
				remendo, rev_z0)
	if pz1 > 0.0 and larg_meio > 0.05:
		var remendo := rng.randf() < 0.18
		if escada["z1"]:
			_faixa_z_em_escada(sup, px0, TAM - px1, TAM - pz1, pz1, rev_z1,
				EscadariaBuilder.extensao_z(cz + 1, cx))
		else:
			KitModular.rua(sup, Vector3(px0, 0.0, TAM - pz1),
				Vector2(larg_meio, pz1), remendo, rev_z1)

	# Calcadas. As do eixo X vao de meio a meio em Z, deixando as pontas para a
	# pista transversal; as do eixo Z ficam so no vao entre elas.
	var mat_calcada := material_da_calcada(MalhaUrbana.quadra_de(cx, cz))
	if lim.position.x > 0.0:
		_calcada(sup, colisao, Rect2(px0, pz0, lim.position.x - px0,
			TAM - pz1 - pz0), 3, mat_calcada, MalhaUrbana._ruido(cx, cz, 313), escada)
	if lim.end.x < TAM:
		_calcada(sup, colisao, Rect2(lim.end.x, pz0, TAM - px1 - lim.end.x,
			TAM - pz1 - pz0), 1, mat_calcada, MalhaUrbana._ruido(cx, cz, 311), escada)
	if lim.position.y > 0.0:
		_calcada(sup, colisao, Rect2(lim.position.x, pz0, lim.size.x,
			lim.position.y - pz0), 0, mat_calcada, MalhaUrbana._ruido(cx, cz, 310), escada)
	if lim.end.y < TAM:
		_calcada(sup, colisao, Rect2(lim.position.x, lim.end.y, lim.size.x,
			TAM - pz1 - lim.end.y), 2, mat_calcada, MalhaUrbana._ruido(cx, cz, 312), escada)

	# Escada nao tem faixa pintada nem vaga de estacionamento.
	var bordas_tinta := bordas.duplicate()
	for lado: String in escada:
		if escada[lado]:
			bordas_tinta[lado] = MalhaUrbana.Via.NENHUMA
	_pintura(sup, bordas_tinta, px0, pz0, lim, cx, cz)
	_arborizacao(sup, colisao, cx, cz, bordas, lim, rng)

	# Chao do asfalto. No parque o miolo NAO entra: o jogador andava nesta
	# caixa a y=0, dezesseis centimetros ABAIXO da grama, e na saida batia na
	# calcada por baixo — preso no chao. O piso do parque e colisao propria
	# em ParqueBuilder, na mesma altura da calcada.
	var parque := int(MalhaUrbana.quadra_de(cx, cz)["uso"]) == MalhaUrbana.Uso.PARQUE
	if parque:
		_chao_asfalto(colisao, px0, px1, pz0, pz1)
	else:
		colisao.append({
			"tamanho": Vector3(TAM, 0.4, TAM),
			"pos": Vector3(TAM * 0.5, -0.2, TAM * 0.5),
		})


## O revestimento do miolo do cruzamento (i, j), visto da coluna de chunks
## `coluna` (a da faixa do eixo Z que encosta nele).
##
## O cruzamento e da rua que ATRAVESSA: no entroncamento em T, a que segue reto
## continua com o proprio piso e a que termina encosta nela — rua de asfalto que
## desemboca numa de pedra nao asfalta um quadrado no meio da pedra. No
## cruzamento de quatro bracos, o asfalto ganha: e a rua mais nova.
static func _quina(i: int, j: int, coluna: int) -> StringName:
	var passa_x := MalhaUrbana.via_x_em(i, j) != MalhaUrbana.Via.NENHUMA \
		and MalhaUrbana.via_x_em(i, j - 1) != MalhaUrbana.Via.NENHUMA
	var passa_z := MalhaUrbana.via_z_em(j, i) != MalhaUrbana.Via.NENHUMA \
		and MalhaUrbana.via_z_em(j, i - 1) != MalhaUrbana.Via.NENHUMA
	# O trecho de cada linha que encosta no miolo pelo lado desta faixa.
	var rev_x := MalhaUrbana.revestimento_x(i, j if MalhaUrbana.via_x_em(i, j)
		!= MalhaUrbana.Via.NENHUMA else j - 1)
	var rev_z := MalhaUrbana.revestimento_z(j, coluna)
	if MalhaUrbana.via_z_em(j, coluna) == MalhaUrbana.Via.NENHUMA:
		rev_z = MalhaUrbana.revestimento_z(j, i if coluna < i else i - 1)
	if passa_x and not passa_z:
		return rev_x
	if passa_z and not passa_x:
		return rev_z
	return rev_x if rev_x == rev_z else &"asfalto"


## Faixa de pista do eixo X, de x0 a x0 + largura, cortada em quina, miolo e
## quina. A quina e do cruzamento (ver `_quina`).
## A faixa do eixo X num trecho que e escadaria: as duas quinas do cruzamento e
## os dois patamares, e nada no miolo — ali vao os degraus (EscadariaBuilder).
static func _faixa_x_em_escada(sup: Dictionary, x0: float, largura: float, pz0: float,
		pz1: float, rev_x: StringName, quina0: StringName, quina1: StringName,
		extensao: Vector2) -> void:
	if pz0 > 0.05:
		KitModular.rua(sup, Vector3(x0, 0.0, 0.0), Vector2(largura, pz0), false, quina0)
	if extensao.x - pz0 > 0.05:
		KitModular.rua(sup, Vector3(x0, 0.0, pz0), Vector2(largura, extensao.x - pz0),
			false, rev_x)
	var fim := TAM - pz1
	if fim - extensao.y > 0.05:
		KitModular.rua(sup, Vector3(x0, 0.0, extensao.y), Vector2(largura, fim - extensao.y),
			false, rev_x)
	if pz1 > 0.05:
		KitModular.rua(sup, Vector3(x0, 0.0, fim), Vector2(largura, pz1), false, quina1)


## A faixa do eixo Z (de x_de a x_ate, largura em z a partir de z0) num trecho que
## e escadaria: so os dois patamares.
static func _faixa_z_em_escada(sup: Dictionary, x_de: float, x_ate: float, z0: float,
		largura: float, rev: StringName, extensao: Vector2) -> void:
	if extensao.x - x_de > 0.05:
		KitModular.rua(sup, Vector3(x_de, 0.0, z0), Vector2(extensao.x - x_de, largura),
			false, rev)
	if x_ate - extensao.y > 0.05:
		KitModular.rua(sup, Vector3(extensao.y, 0.0, z0), Vector2(x_ate - extensao.y, largura),
			false, rev)


## Os degraus das bordas deste chunk que sao escadaria. Depois do chao ja
## assentado no morro: o degrau sai com a altura absoluta (Relevo), e deformar
## de novo o levaria duas vezes para cima. O corrimao e do chunk do lado + da
## rua (bordas x0 e z0), para nao sair duas vezes.
static func _escadarias(sup: Dictionary, colisao: Array[Dictionary], cx: int, cz: int,
		bordas: Dictionary) -> void:
	var escada := Ladeira.bordas_em_escada(cx, cz)
	var px0 := MalhaUrbana.meia_asfalto(bordas["x0"])
	var px1 := MalhaUrbana.meia_asfalto(bordas["x1"])
	var pz0 := MalhaUrbana.meia_asfalto(bordas["z0"])
	var pz1 := MalhaUrbana.meia_asfalto(bordas["z1"])
	if escada["x0"] and px0 > 0.05:
		EscadariaBuilder.construir(sup, colisao, cx, cz, true, Vector2(0.0, px0), 0.0,
			EscadariaBuilder.extensao_x(cx, cz), true)
	if escada["x1"] and px1 > 0.05:
		EscadariaBuilder.construir(sup, colisao, cx, cz, true, Vector2(TAM - px1, TAM), TAM,
			EscadariaBuilder.extensao_x(cx + 1, cz), false)
	if escada["z0"] and pz0 > 0.05:
		EscadariaBuilder.construir(sup, colisao, cx, cz, false, Vector2(0.0, pz0), 0.0,
			EscadariaBuilder.extensao_z(cz, cx), true)
	if escada["z1"] and pz1 > 0.05:
		EscadariaBuilder.construir(sup, colisao, cx, cz, false, Vector2(TAM - pz1, TAM), TAM,
			EscadariaBuilder.extensao_z(cz + 1, cx), false)


static func _faixa_x(sup: Dictionary, x0: float, largura: float, pz0: float,
		pz1: float, rev_x: StringName, quina0: StringName, quina1: StringName) -> void:
	if quina0 == rev_x and quina1 == rev_x:
		KitModular.rua(sup, Vector3(x0, 0.0, 0.0), Vector2(largura, TAM), false, rev_x)
		return
	if pz0 > 0.05:
		KitModular.rua(sup, Vector3(x0, 0.0, 0.0), Vector2(largura, pz0), false, quina0)
	var fim := TAM - pz1
	if fim - pz0 > 0.05:
		KitModular.rua(sup, Vector3(x0, 0.0, pz0), Vector2(largura, fim - pz0), false,
			rev_x)
	if pz1 > 0.05:
		KitModular.rua(sup, Vector3(x0, 0.0, fim), Vector2(largura, pz1), false, quina1)


## Quanto a face do meio-fio da borda `lado` desce abaixo da pista.
static func _saia(escada: Dictionary, lado: String) -> float:
	return EscadariaBuilder.SAIA if bool(escada.get(lado, false)) else KitModular.SAIA_MEIO_FIO


## O piso da calcada da quadra.
##
## Calcada no Brasil e de quem e dono do lote: cada quarteirao tem a sua, e ela
## muda ao atravessar a rua. Uma so textura na cidade inteira era um tapete. Rua
## de casas vai quase sempre de mosaico de pedra (a calcada de cidade pequena);
## comercio divide entre os dois; galpao fica no ladrilho gasto. O parque fica
## como estava: a calcada da Praca da Matriz e cenario de cutscene.
##
## So pisos que estao em ChunkManager.SEM_SOMBRA: chao que projeta sombra sobre
## si mesmo sai listrado.
static func material_da_calcada(quadra: Dictionary) -> StringName:
	var h := int(quadra["semente"]) / 97
	match int(quadra["uso"]):
		MalhaUrbana.Uso.PARQUE, MalhaUrbana.Uso.BALDIO:
			return &"calcada"
	match int(quadra["distrito"]):
		MalhaUrbana.Distrito.RESIDENCIAL:
			return [&"calcada_ladrilho", &"calcada_ladrilho", &"calcada"][h % 3]
		MalhaUrbana.Distrito.COMERCIAL:
			return [&"calcada_ladrilho", &"calcada"][h % 2]
	return &"calcada"


## Faixas de asfalto, so elas. Serve ao chunk de parque, que nao pode herdar a
## laje de 32 m: ela tapava o lago e enterrava o jogador no gramado.
static func _chao_asfalto(colisao: Array[Dictionary], px0: float, px1: float,
		pz0: float, pz1: float) -> void:
	if px0 > 0.05:
		colisao.append({
			"tamanho": Vector3(px0, 0.4, TAM),
			"pos": Vector3(px0 * 0.5, -0.2, TAM * 0.5),
		})
	if px1 > 0.05:
		colisao.append({
			"tamanho": Vector3(px1, 0.4, TAM),
			"pos": Vector3(TAM - px1 * 0.5, -0.2, TAM * 0.5),
		})
	var meio := TAM - px0 - px1
	if meio > 0.05 and pz0 > 0.05:
		colisao.append({
			"tamanho": Vector3(meio, 0.4, pz0),
			"pos": Vector3(px0 + meio * 0.5, -0.2, pz0 * 0.5),
		})
	if meio > 0.05 and pz1 > 0.05:
		colisao.append({
			"tamanho": Vector3(meio, 0.4, pz1),
			"pos": Vector3(px0 + meio * 0.5, -0.2, TAM - pz1 * 0.5),
		})


## Uma faixa de calcada com o meio-fio virado para `dir_meio_fio` e a rampa que
## permite subir nela.
##
## `escada` e o Ladeira.bordas_em_escada do chunk: ao lado de degrau o meio-fio
## desce mais (EscadariaBuilder.SAIA), senao abre cunha no pe de cada espelho.
static func _calcada(sup: Dictionary, colisao: Array[Dictionary], r: Rect2,
		dir_meio_fio: int, material: StringName = &"calcada", semente: int = 0,
		escada: Dictionary = {}) -> void:
	if r.size.x < 0.05 or r.size.y < 0.05:
		return
	# Boca de lobo e tampa de ferro (DetalheCalcada).
	DetalheCalcada.faixa(sup, r, dir_meio_fio, semente)
	var h := KitModular.ALTURA_MEIO_FIO
	var comprimento := r.size.y if dir_meio_fio == 1 or dir_meio_fio == 3 else r.size.x
	var borda_da_face: String = ["z0", "x1", "z1", "x0"][dir_meio_fio]
	KitModular.calcada(sup, Vector3(r.position.x, 0.0, r.position.y), r.size,
		dir_meio_fio, comprimento, material, _saia(escada, borda_da_face))
	# A borda de DENTRO, a que da para o lote. Com predio ela fica atras da
	# fachada; no baldio, no jardim e no vao entre casas o chao do lote esta 16 cm
	# abaixo, e sem esta face quem olhava do lote via por baixo da laje, direto
	# no limbo. Olha para o lote: da rua ela e descartada pelo cull_back.
	var dentro := Vector3(r.get_center().x, (h - KitModular.SAIA_MEIO_FIO) * 0.5,
		r.get_center().y)
	var olha_lote: int = [0, 3, 2, 1][dir_meio_fio]
	match dir_meio_fio:
		3: dentro.x = r.end.x
		1: dentro.x = r.position.x
		0: dentro.z = r.end.y
		_: dentro.z = r.position.y
	KitModular.parede(sup, &"meio_fio", dentro,
		Vector2(comprimento, h + KitModular.SAIA_MEIO_FIO), olha_lote)
	# E uma face virada para a RUA, com o piso da calcada, 2 cm para dentro do
	# lote. So aparece por fresta: a grama do parque e o piso do lote no nivel da
	# calcada (0,16) encostam nela com outra grade de vertices (junta em T que a
	# Costura nao alcanca, porque vem depois), e quem vinha da rua via o limbo
	# por baixo da laje. Na mesma aresta ela cairia na propria fresta; recuada,
	# o raio que passa pela fresta desce e bate nela.
	var tapa := dentro - KitModular._normal((olha_lote + 2) % 4) * 0.02
	KitModular.parede(sup, material, tapa,
		Vector2(comprimento, h + KitModular.SAIA_MEIO_FIO), (olha_lote + 2) % 4)
	# Fundo debaixo da laje, 5 cm abaixo da rua e 5 cm alem de cada borda. Com a
	# camera no plano do meio-fio a borda da calcada e a do asfalto caem na mesma
	# linha da tela e sobrava um pixel de limbo entre elas; agora o que aparece
	# e concreto. Do lado da rua ele entra 40 cm sob o asfalto: com o snap do
	# PS1 a 480x270, a 30 m um pixel e 13 cm de mundo, e 5 cm nao seguravam.
	# Quad de 4 m: e escondido, so precisa acompanhar o morro.
	var fundo := r.grow(0.05)
	match dir_meio_fio:
		3: fundo = fundo.grow_individual(0.35, 0.0, 0.0, 0.0)
		1: fundo = fundo.grow_individual(0.0, 0.0, 0.35, 0.0)
		0: fundo = fundo.grow_individual(0.0, 0.35, 0.0, 0.0)
		_: fundo = fundo.grow_individual(0.0, 0.0, 0.0, 0.35)
	KitModular.chao(sup, &"meio_fio", Vector3(fundo.position.x, -0.05, fundo.position.y),
		fundo.size, 4.0)

	# As pontas da faixa do eixo X. Ela para onde comeca a pista transversal, e
	# a ponta ficava sem face: um rasgo de 16 cm na altura da rua, da largura da
	# calcada, abrindo para o vao debaixo da laje, onde nao ha chao nenhum. Era o
	# buraco pro limbo na quina de todo cruzamento. Onde a ponta encosta na
	# calcada do chunk vizinho a face fica escondida sob a laje dele, e fecha
	# tambem o degrau quando as duas calcadas nao tem a mesma largura.
	if dir_meio_fio == 1 or dir_meio_fio == 3:
		# [z da ponta, para onde a face olha no esquema de `parede`, rua em -z?]
		for ponta: Array in [[r.position.y, 2, true, "z0"], [r.end.y, 0, false, "z1"]]:
			# Com a mesma saia da face comprida (KitModular.SAIA_MEIO_FIO), ou a
			# da escada quando a pista transversal e degrau.
			var saia := _saia(escada, String(ponta[3]))
			KitModular.parede(sup, &"meio_fio",
				Vector3(r.get_center().x, (h - saia) * 0.5, float(ponta[0])),
				Vector2(r.size.x, h + saia), int(ponta[1]))
			# E a mesma rampa do meio-fio comprido: a faixa de pedestre chega
			# nesta ponta, e sem ela quem atravessa bate num degrau de 16 cm.
			_rampa(colisao, Vector3(r.get_center().x, 0.0, float(ponta[0])),
				r.size.x, false, bool(ponta[2]))
	colisao.append({
		"tamanho": Vector3(r.size.x, h, r.size.y),
		"pos": Vector3(r.get_center().x, h * 0.5, r.get_center().y),
	})

	# Rampa curta no meio-fio, senao o degrau de 16 cm barra o jogador:
	# CharacterBody3D nao sobe degrau sozinho.
	var borda := Vector3(r.get_center().x, 0.0, r.get_center().y)
	match dir_meio_fio:
		3:
			borda.x = r.position.x
		1:
			borda.x = r.end.x
		0:
			borda.z = r.position.y
		_:
			borda.z = r.end.y
	_rampa(colisao, borda, comprimento, dir_meio_fio == 1 or dir_meio_fio == 3,
		dir_meio_fio == 3 or dir_meio_fio == 0)


## A rampa do meio-fio, deitada do lado da RUA e terminando rente ao topo da
## calcada.
##
## A versao anterior centrava a caixa inclinada NA quina, entao a metade de
## dentro continuava subindo por cima da calcada e parava treze centimetros
## acima dela — um degrau invisivel correndo o meio-fio inteiro. Descer da
## calcada para a rua andando era impossivel: o corpo batia nesse beico e
## CharacterBody3D nao sobe degrau sozinho. Subir funcionava, que e por isso que
## o defeito passou tanto tempo em pe.
##
## Agora a face de cima da caixa e construida a partir dos dois pontos que ela
## precisa ligar — o asfalto e a quina — e a caixa e afundada pela propria
## normal, de modo que nada dela aparece acima do plano da calcada.
static func _rampa(colisao: Array[Dictionary], pos: Vector3, comprimento: float,
		ao_longo_de_z: bool, sobe_para_mais: bool) -> void:
	var h := KitModular.ALTURA_MEIO_FIO
	var corrida := 0.34
	var ang := atan2(h, corrida)
	var hipotenusa := sqrt(h * h + corrida * corrida)
	var espessura := 0.3

	# Para que lado fica a calcada, no eixo em que a rampa sobe. A rua e o outro.
	var lado := 1.0 if sobe_para_mais else -1.0

	var tamanho := (Vector3(hipotenusa, espessura, comprimento) if ao_longo_de_z
		else Vector3(comprimento, espessura, hipotenusa))
	var giro := (Vector3(0.0, 0.0, ang if sobe_para_mais else -ang) if ao_longo_de_z
		else Vector3(-ang if sobe_para_mais else ang, 0.0, 0.0))

	# Meio do trecho inclinado: meia corrida rua adentro, meia altura acima do
	# asfalto. E o ponto por onde a face de cima tem de passar.
	var meio := pos + (Vector3(-lado * corrida * 0.5, h * 0.5, 0.0) if ao_longo_de_z
		else Vector3(0.0, h * 0.5, -lado * corrida * 0.5))

	colisao.append({
		"tamanho": tamanho,
		"pos": meio - Basis.from_euler(giro).y * (espessura * 0.5),
		"giro": giro,
	})


## Arvore de calcada, so na avenida.
##
## Duas razoes para ser so na avenida. A primeira e largura: a calcada de rua tem
## 2,5 m e uma arvore no meio dela vira obstaculo; a de avenida tem 3 m e sobra
## passagem. A segunda e hierarquia — a avenida ja e mais larga e tem eixo
## pintado, e a fileira de arvores termina de separa-la da rua comum vista de
## dentro, que e onde o jogador esta.
##
## Porte pequeno de proposito: a copa cresce ate onde a fachada comeca e nao um
## centimetro alem. Com a arvore do parque, de oito metros, o quarteirao inteiro
## sumia atras de folha.
## Onde nascem as arvores deste chunk, ja filtradas.
##
## Publica e sem sorteio nenhum: o rng do chunk decide porte e tipo, nunca
## lugar. A suite de testes afirma em cima desta lista que nenhuma arvore cai
## dentro de uma travessia — foi a unica forma de impedir que a fileira da
## avenida voltasse para cima da faixa de pedestre na proxima vez que alguem
## mexer na largura da rua.
static func arvores(cx: int, cz: int) -> Array[Vector3]:
	var bordas := MalhaUrbana.bordas(cx, cz)
	var lim := area_util(cx, cz)
	const PASSO := 11.0
	# Perto do meio-fio, mas com folga da linha de marcha (Rotas.recuo_de_marcha).
	# A calcada da avenida encolheu de 3,0 para 2,5 m quando a faixa de
	# estacionamento nasceu (MalhaUrbana.largura_calcada) e o afastamento da
	# linha de marcha encolheu junto — de 1,86 para 1,55 m de recuo_de_marcha.
	# Com a arvore ainda a 1,05 m sobrava so meio metro entre o tronco e a linha,
	# menos que o raio do pedestre (0,26) mais o do tronco (~0,3): o ombro
	# encostava toda vez, e nao so nas franjas como o comentario de Rotas prevê.
	# A 0,85 m sobra 0,70 m de novo, a mesma folga proporcional de antes.
	const DA_GUIA := 0.85
	var y := KitModular.ALTURA_MEIO_FIO
	var poste := _poste_local(bordas)
	# A porta tem prioridade sobre a arvore. Uma copa de dois metros plantada na
	# frente de uma loja apaga o letreiro, e o letreiro visto de longe na nevoa e
	# a razao de a loja existir.
	var porta := _porta_do_chunk(cx, cz, MalhaUrbana.quadra_de(cx, cz))
	var canteiros: Array[Vector3] = []
	var saida: Array[Vector3] = []

	if bordas["x0"] == MalhaUrbana.Via.AVENIDA:
		var x := MalhaUrbana.meia_asfalto(bordas["x0"]) + DA_GUIA
		for i in int(TAM / PASSO):
			canteiros.append(Vector3(x, y, 4.0 + float(i) * PASSO))
	if bordas["x1"] == MalhaUrbana.Via.AVENIDA:
		var x := TAM - MalhaUrbana.meia_asfalto(bordas["x1"]) - DA_GUIA
		for i in int(TAM / PASSO):
			canteiros.append(Vector3(x, y, 9.0 + float(i) * PASSO))
	if bordas["z0"] == MalhaUrbana.Via.AVENIDA:
		var z := MalhaUrbana.meia_asfalto(bordas["z0"]) + DA_GUIA
		for i in int(TAM / PASSO):
			canteiros.append(Vector3(lim.position.x + 4.0 + float(i) * PASSO, y, z))
	if bordas["z1"] == MalhaUrbana.Via.AVENIDA:
		var z := TAM - MalhaUrbana.meia_asfalto(bordas["z1"]) - DA_GUIA
		for i in int(TAM / PASSO):
			canteiros.append(Vector3(lim.position.x + 9.0 + float(i) * PASSO, y, z))

	# Rua de casas tambem tem arvore — o oiti podado na beira da calcada e a cara
	# da rua de cidade do interior. So na calcada de RUA de quadra residencial:
	# a viela nao tem largura e o comercio precisa do letreiro a vista.
	var quadra := MalhaUrbana.quadra_de(cx, cz)
	if int(quadra["uso"]) == MalhaUrbana.Uso.EDIFICADO \
			and int(quadra["distrito"]) == MalhaUrbana.Distrito.RESIDENCIAL:
		var d := MalhaUrbana.meia_asfalto(MalhaUrbana.Via.RUA) + DA_GUIA_RUA
		for i in int(TAM / PASSO_RUA):
			var ao_longo := 6.0 + float(i) * PASSO_RUA
			if bordas["x0"] == MalhaUrbana.Via.RUA:
				canteiros.append(Vector3(d, y, ao_longo))
			if bordas["x1"] == MalhaUrbana.Via.RUA:
				canteiros.append(Vector3(TAM - d, y, ao_longo + 3.0))
			if bordas["z0"] == MalhaUrbana.Via.RUA:
				canteiros.append(Vector3(ao_longo + 3.0, y, d))
			if bordas["z1"] == MalhaUrbana.Via.RUA:
				canteiros.append(Vector3(ao_longo, y, TAM - d))

	for base: Vector3 in canteiros:
		if base.x < 0.5 or base.x > TAM - 0.5 or base.z < 0.5 or base.z > TAM - 0.5:
			continue
		# O poste tem prioridade sobre a arvore: luz de rua e leitura de espaco,
		# folha e enfeite. Arvore em cima do poste apagaria a rua.
		if Vector2(base.x - poste.x, base.z - poste.z).length() < 3.0:
			continue
		if not porta.is_empty():
			var p: Vector3 = porta["pos"]
			if Vector2(base.x - p.x, base.z - p.z).length() < 4.2:
				continue
			# A loja de conveniencia tem uma segunda boca: o portao da garagem,
			# com a guia rebaixada na frente. Arvore ali fecha a entrada de carga.
			if porta.get("interior", &"") == &"mercado" and bool(porta.get("mundo", false)):
				var em: Transform3D = porta["planta"]
				var g := em * Vector3(MercadoBuilder.EIXO_PORTAO, 0.0, 0.0)
				var n := KitModular._normal(int(porta["direcao"]))
				var ao_longo := Vector2(base.x - g.x, base.z - g.z)
				var fora := Vector2(n.x, n.z)
				if absf(ao_longo.dot(Vector2(-fora.y, fora.x))) < 2.8 \
						and absf(ao_longo.dot(fora)) < 6.0:
					continue
		# A esquina inteira e da travessia: zebra, semaforo e sinal de pedestre.
		# Copa em cima de qualquer um dos tres apaga o que existe para ser lido.
		if _na_esquina_do_cruzamento(cx, cz, base):
			continue
		saida.append(base)
	return saida


static func _arborizacao(sup: Dictionary, colisao: Array[Dictionary],
		cx: int, cz: int, bordas: Dictionary, _lim: Rect2,
		rng: RandomNumberGenerator) -> void:
	for base: Vector3 in arvores(cx, cz):
		# Canteiro: um quadrado de terra em volta do tronco. Sem ele a arvore nasce
		# do concreto e o olho estranha antes de saber por que.
		#
		# Dois centimetros acima da calcada, e nao cinco milimetros: encostado, os
		# dois planos disputam o pixel a trinta metros e o canteiro pisca. E a
		# mesma conta de precisao de profundidade documentada em KitParque.
		if _arvore_de_rua(bordas, base):
			# Na calcada de 2,2 m da rua o canteiro e menor e o tronco tem colisao
			# fina: a de 60 cm da arvore do parque encostaria na linha de marcha
			# (Rotas.recuo_de_marcha) e o pedestre esbarraria em toda arvore.
			KitModular.chao(sup, &"terra", base + Vector3(-0.4, 0.02, -0.4),
				Vector2(0.8, 0.8), 4.0, Color(0.55, 0.53, 0.48))
			var descartavel: Array[Dictionary] = []
			var porte := rng.randf_range(0.0, 0.22)
			var seca := rng.randf() < 0.08
			if Vegetacao.ativo:
				# Copa de cartao (Vegetacao): o oiti podado, e um ipe de vez em quando.
				Vegetacao.arvore(sup, descartavel, base, _especie_de_rua(cx, cz, base, false),
					porte, rng)
			else:
				KitParque.arvore(sup, descartavel, base, porte, rng, seca)
			colisao.append({"tamanho": Vector3(0.28, 3.0, 0.28),
				"pos": base + Vector3(0.0, 1.5, 0.0)})
			continue
		KitModular.chao(sup, &"terra", base + Vector3(-0.6, 0.02, -0.6),
			Vector2(1.2, 1.2), 4.0, Color(0.55, 0.53, 0.48))
		var porte_av := rng.randf_range(0.05, 0.4)
		var seca_av := rng.randf() < 0.12
		if Vegetacao.ativo:
			var especie := _especie_de_rua(cx, cz, base, true)
			if especie == &"palmeira":
				Vegetacao.palmeira(sup, colisao, base, true, rng)
			else:
				Vegetacao.arvore(sup, colisao, base, especie, porte_av, rng)
		else:
			KitParque.arvore(sup, colisao, base, porte_av, rng, seca_av)


## A especie da arvore de calcada (Vegetacao). Sorteio pela posicao no MUNDO e
## pela quadra, e nao pelo rng do chunk: a fileira da avenida sai da mesma
## especie de ponta a ponta do quarteirao (a prefeitura planta em lote), e o
## ipe florido e o que quebra a fileira.
static func _especie_de_rua(cx: int, cz: int, base: Vector3, avenida: bool) -> StringName:
	var q := MalhaUrbana.quadra_de(cx, cz)
	var lote := int(q["semente"]) % 97
	var aqui := MalhaUrbana._ruido(cx * 32 + int(base.x), cz * 32 + int(base.z), 7717) % 100
	if avenida:
		if lote < 22:
			return &"palmeira"
		if aqui < 16:
			return &"ipe_amarelo" if lote % 2 == 0 else &"ipe_rosa"
		return &"sibipiruna" if lote < 70 else &"oiti"
	if aqui < 12:
		return &"ipe_amarelo" if aqui % 2 == 0 else &"ipe_rosa"
	return &"oiti"


## Distancia da arvore de rua ate o meio-fio, e o passo entre duas.
const DA_GUIA_RUA := 0.38
const PASSO_RUA := 12.0


## A arvore esta na fileira da calcada de uma RUA (e nao na da avenida)?
static func _arvore_de_rua(bordas: Dictionary, base: Vector3) -> bool:
	var d := MalhaUrbana.meia_asfalto(MalhaUrbana.Via.RUA) + DA_GUIA_RUA
	for par: Array in [["x0", base.x], ["x1", TAM - base.x], ["z0", base.z],
			["z1", TAM - base.z]]:
		if bordas[par[0]] == MalhaUrbana.Via.RUA and absf(float(par[1]) - d) < 0.05:
			return true
	return false


## Folga extra em volta da caixa da travessia, para o tronco nao encostar nela.
const FOLGA_ESQUINA := 0.4

## A base cai dentro da esquina de algum cruzamento que toca este chunk?
##
## Cobre a CAIXA INTEIRA da travessia (asfalto + recuo + zebra, ver
## vao_travessia), e nao um raio em volta do poste. O raio de 3,2 m que estava
## aqui nao alcancava: a zebra do braco L/O corre ao longo da via ate a meia
## largura do asfalto — 6,7 m na avenida —, entao a arvore plantada a 4 m da
## esquina caia dentro dela sem chegar perto de poste nenhum. Foi assim que a
## fileira de arvore da avenida nasceu em cima da faixa de pedestre.
##
## Testa os QUATRO cantos do chunk, e nao so (cx, cz): o chunk vizinho e dono do
## cruzamento da outra ponta, mas a calcada que sobe nela e desta quadra.
static func _na_esquina_do_cruzamento(cx: int, cz: int, base: Vector3) -> bool:
	for dx in 2:
		for dz in 2:
			var i := cx + dx
			var j := cz + dz
			if not Vias.existe_cruzamento(i, j):
				continue
			var vx := vao_travessia(Vias.meia_asfalto_x_no(i, j))
			var vz := vao_travessia(Vias.meia_asfalto_z_no(i, j))
			# Centro do cruzamento em coordenada local a este chunk.
			var cx_local := float(dx) * TAM
			var cz_local := float(dz) * TAM
			if absf(base.x - cx_local) <= vx + FOLGA_ESQUINA 					and absf(base.z - cz_local) <= vz + FOLGA_ESQUINA:
				return true
	return false


## Distancia do centro do cruzamento ate o poste da esquina: encostado no
## meio-fio, do lado de dentro da calcada.
static func _recuo_esquina(meia: float, via: int) -> float:
	return meia + minf(0.95, MalhaUrbana.largura_calcada(via) * 0.4)


# --- geometria do cruzamento ------------------------------------------------
#
# Tudo o que fica na esquina — zebra, semaforo de carro, sinal de pedestre e o
# desvio da arborizacao — sai das funcoes puras abaixo, em coordenada LOCAL ao
# chunk dono, com a origem no centro do cruzamento (cx, cz).
#
# Estao juntas e sao publicas por um motivo caro: enquanto cada uma dessas
# quatro coisas fazia a propria conta, elas sairam do lugar uma a uma. A zebra
# nasceu com os eixos trocados, a fileira de arvore da avenida foi plantada
# dentro dela, e o poste de luz ficou no acostamento quando a faixa de
# estacionamento empurrou o meio-fio. Agora quem pinta, quem planta e quem testa
# leem a MESMA funcao, e divergir deixou de ser possivel.

## Recuo da zebra a partir da borda do asfalto, e a profundidade dela.
const FAIXA_RECUO := 0.25
const FAIXA_PROFUNDIDADE := 1.5
const FAIXA_BARRA := 0.5
const FAIXA_VAO := 0.45


## Meia largura do bloco que a travessia ocupa num eixo: asfalto, recuo e zebra.
## Nada de calcada — arvore, banco, maquina — pode nascer dentro dele.
static func vao_travessia(meia_asfalto: float) -> float:
	return meia_asfalto + FAIXA_RECUO + FAIXA_PROFUNDIDADE


## As quatro travessias de um cruzamento.
##
## `eixo_marcha` usa a convencao de Vias, a mesma do carro: 0 e quem se move em
## Z, 1 e quem se move em X. Aqui vale para o PEDESTRE. A risca e sempre
## comprida no eixo do carro que ela cruza e fina no eixo da marcha — e isso que
## faz a zebra ler como escada em vez de trilho.
##
## `meia_largura` e metade do comprimento da barra (a meia largura do asfalto
## que ela atravessa); `meia_extensao` e metade do lado ao longo do qual as
## barras se repetem.
static func travessias(cx: int, cz: int) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	if not Vias.existe_cruzamento(cx, cz):
		return saida
	# Meia largura de cada linha NO cruzamento, a maior dos dois bracos: a zebra
	# fica alem do asfalto transversal inteiro.
	var ax := Vias.meia_asfalto_x_no(cx, cz)
	var az := Vias.meia_asfalto_z_no(cx, cz)
	var meio := FAIXA_RECUO + FAIXA_PROFUNDIDADE * 0.5

	# N e S. Ficam depois do asfalto da via que corre em X e cruzam a via que
	# corre em Z: quem atravessa se move em X, ou seja, eixo de marcha 1. So
	# existe a do braco que existe — no lado fechado de um T a calcada e corrida
	# e uma zebra ali seria pintura sobre o passeio.
	for sz: float in [1.0, -1.0]:
		var braco := Vias.braco_n(cx, cz) if sz > 0.0 else Vias.braco_s(cx, cz)
		if not braco:
			continue
		saida.append({
			"centro": Vector3(0.0, 0.0, sz * (az + meio)),
			"eixo_marcha": 1,
			"meia_largura": MalhaUrbana.meia_asfalto(
				MalhaUrbana.via_x_em(cx, cz if sz > 0.0 else cz - 1)),
			"meia_extensao": az,
		})
	# L e O. Cruzam a via que corre em X: quem atravessa se move em Z, eixo 0.
	for sx: float in [1.0, -1.0]:
		var braco := Vias.braco_l(cx, cz) if sx > 0.0 else Vias.braco_o(cx, cz)
		if not braco:
			continue
		saida.append({
			"centro": Vector3(sx * (ax + meio), 0.0, 0.0),
			"eixo_marcha": 0,
			"meia_largura": MalhaUrbana.meia_asfalto(
				MalhaUrbana.via_z_em(cz, cx if sx > 0.0 else cx - 1)),
			"meia_extensao": ax,
		})
	return saida


## Para onde uma cabeca de sinal tem de olhar.
##
## `eixo` e o de quem LE o sinal (0 se move em Z, 1 se move em X) e `sentido` e
## para que lado essa pessoa vai. A cabeca encara quem vem, entao o normal dela
## e o oposto do movimento. Um valor so, usado pelo semaforo de carro, pelo
## sinal de pedestre e pela assercao dos dois.
static func giro_de_face(eixo: int, sentido: float) -> float:
	# frente = (sin(giro), 0, cos(giro)); queremos frente oposta ao movimento.
	if eixo == 0:
		return PI if sentido > 0.0 else 0.0
	return -PI * 0.5 if sentido > 0.0 else PI * 0.5


## Os quatro postes de um cruzamento: semaforo de carro e sinal de pedestre em
## cada esquina.
##
## A esquina de cada aproximacao nao e escolhida a dedo, e a regra do lado de la
## a direita: o motorista le o sinal DEPOIS da faixa, do lado da mao dele. Com a
## direita valendo `frente x cima` num sistema destro, quem vai para +Z tem a
## direita em -X e quem vai para +X tem a direita em +Z (a mesma troca de sinal
## documentada em Vias). Disso sai, sem tabela:
##
##   esquina com sx == -sz   serve quem se move em Z (eixo 0), sentido = sz
##   esquina com sx ==  sz   serve quem se move em X (eixo 1), sentido = sx
##
## O sinal de pedestre da esquina serve a travessia que conflita com o MESMO
## eixo do semaforo dela — quem atravessa se move no outro eixo. Como cada
## esquina toca duas travessias e ha quatro esquinas para quatro travessias, o
## arranjo sai em cata-vento: cada travessia ganha exatamente um sinal.
static func sinais_do_cruzamento(cx: int, cz: int) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	if not Vias.existe_cruzamento(cx, cz):
		return saida
	var y := KitModular.ALTURA_MEIO_FIO

	for sx: float in [1.0, -1.0]:
		for sz: float in [1.0, -1.0]:
			var eixo := 1 if is_equal_approx(sx, sz) else 0
			var sentido: float = sx if eixo == 1 else sz
			# No entroncamento em T nem toda esquina tem o que sinalizar. O
			# semaforo serve quem CHEGA pelo braco do lado oposto ao sentido
			# dele; o sinal de pedestre serve a travessia do braco do lado da
			# esquina. Sem nenhum dos dois, a esquina fica sem poste.
			var aproxima: bool
			var travessia: bool
			if eixo == 0:
				aproxima = Vias.braco_s(cx, cz) if sz > 0.0 else Vias.braco_n(cx, cz)
				travessia = Vias.braco_n(cx, cz) if sz > 0.0 else Vias.braco_s(cx, cz)
			else:
				aproxima = Vias.braco_o(cx, cz) if sx > 0.0 else Vias.braco_l(cx, cz)
				travessia = Vias.braco_l(cx, cz) if sx > 0.0 else Vias.braco_o(cx, cz)
			if not aproxima and not travessia:
				continue
			# O recuo da esquina sai das vias DESTE canto. No lado fechado do T a
			# via daquele lado nao existe, e o poste fica onde a quina estaria,
			# na calcada corrida em frente a rua que termina.
			var vx := MalhaUrbana.via_x_em(cx, cz if sz > 0.0 else cz - 1)
			if vx == MalhaUrbana.Via.NENHUMA:
				vx = MalhaUrbana.via_x_em(cx, cz - 1 if sz > 0.0 else cz)
			var vz := MalhaUrbana.via_z_em(cz, cx if sx > 0.0 else cx - 1)
			if vz == MalhaUrbana.Via.NENHUMA:
				vz = MalhaUrbana.via_z_em(cz, cx - 1 if sx > 0.0 else cx)
			var ox := _recuo_esquina(MalhaUrbana.meia_asfalto(vx), vx)
			var oz := _recuo_esquina(MalhaUrbana.meia_asfalto(vz), vz)
			var canto := Vector3(sx * ox, y, sz * oz)
			# Quem atravessa aqui se move no outro eixo, e sempre para longe da
			# propria esquina: quem espera em +Z atravessa para -Z.
			var marcha := 1 - eixo
			var ped_sentido: float = -sz if marcha == 0 else -sx
			saida.append({
				"com_semaforo": aproxima,
				"com_pedestre": travessia,
				"pos": canto,
				"eixo": eixo,
				"sentido": sentido,
				"giro": giro_de_face(eixo, sentido),
				# So duas das quatro cabecas ganham Omni de halo — uma por eixo,
				# ja que as duas do mesmo eixo mostram a cor igual — para nao
				# estourar o teto de quatro luzes por chunk da skill psx-city.
				"halo": sz > 0.0,
				"ped_pos": canto - Vector3(sx * 0.5, 0.0, sz * 0.5),
				"ped_eixo_conflito": eixo,
				"ped_marcha": marcha,
				"ped_sentido": ped_sentido,
				# A cara do sinal encara quem esta atravessando na direcao dele,
				# pela mesma regra do semaforo de carro.
				"ped_giro": giro_de_face(marcha, ped_sentido),
			})
	return saida


## Pintura do asfalto: eixo tracejado da avenida e faixa de pedestre no
## cruzamento.
##
## Custa quarenta triangulos e e o que faz a avenida parar de ser uma rua larga.
## Sem eixo pintado, largura sozinha nao comunica hierarquia nenhuma.
static func _pintura(sup: Dictionary, bordas: Dictionary, px0: float, pz0: float,
		_lim: Rect2, cx: int, cz: int) -> void:
	# Tinta branca gasta, a mesma para faixa, eixo e retencao. A textura
	# asfalto_faixa era asfalto liso: toda marca de via sumia na pista.
	var tinta := Color(0.82, 0.82, 0.79)

	# Eixo tracejado, junto a fronteira: a outra metade e do chunk vizinho. O
	# traco nao entra no cruzamento: acaba na linha de retencao, cortado ali. O
	# primeiro comecava no centro da esquina e cruzava a zebra.
	if bordas["x0"] == MalhaUrbana.Via.AVENIDA:
		var de := _fim_do_eixo(cx, cz, Vias.meia_asfalto_z_no(cx, cz))
		var ate := TAM - _fim_do_eixo(cx, cz + 1, Vias.meia_asfalto_z_no(cx, cz + 1))
		for i in 5:
			var a := maxf(float(i) * 6.4, de)
			var b := minf(float(i) * 6.4 + 3.2, ate)
			if b - a > 0.8:
				KitModular.chao(sup, &"marca_via", Vector3(0.0, 0.012, (a + b) * 0.5),
					Vector2(0.16, b - a), 6.0, tinta)
	if bordas["z0"] == MalhaUrbana.Via.AVENIDA:
		var de := _fim_do_eixo(cx, cz, Vias.meia_asfalto_x_no(cx, cz))
		var ate := TAM - _fim_do_eixo(cx + 1, cz, Vias.meia_asfalto_x_no(cx + 1, cz))
		for i in 5:
			var a := maxf(float(i) * 6.4, de)
			var b := minf(float(i) * 6.4 + 3.2, ate)
			if b - a > 0.8:
				KitModular.chao(sup, &"marca_via", Vector3((a + b) * 0.5, 0.012, 0.0),
					Vector2(b - a, 0.16), 6.0, tinta)

	_pintura_estacionamento(sup, bordas, px0, pz0, cx, cz, tinta)

	# Faixa de pedestre: zebra nas quatro bocas do cruzamento, encostada na
	# caixa central. So o chunk dono da esquina (cx, cz) desenha, e desenha as
	# quatro — a mesma razao (e a mesma conta de distancia) do semaforo em
	# _semaforos. Ninguem mais pinta este cruzamento, entao nao ha barra
	# dobrada na costura.
	if Vias.existe_cruzamento(cx, cz):
		_faixa_pedestre(sup, cx, cz, tinta)

		_retencao(sup, cx, cz, tinta)


## Ate onde o eixo pintado chega, contado do no (i, j): a linha de retencao,
## se ali ha cruzamento; senao, o proprio no.
static func _fim_do_eixo(i: int, j: int, meia_transversal: float) -> float:
	if not Vias.existe_cruzamento(i, j):
		return 0.0
	return meia_transversal + Vias.FOLGA_RETENCAO


## Linha de retencao em cada aproximacao do cruzamento (cx, cz).
##
## Desenhada inteira pelo chunk dono, como a zebra: a versao anterior pintava so
## as duas da quina (+, +), e a de +X caia na meia pista de quem SAI do
## cruzamento — mao de direcao e a de Vias: quem anda para -X usa z < 0. Com o
## entroncamento em T, cada braco que existe ganha a sua, e o que nao existe
## nao ganha nada. A distancia casa com Vias.FOLGA_RETENCAO + meia da
## transversal, a conta que o carro usa para frear; a folga passa da zebra
## (vao_travessia), e a linha fica atras dela, nunca em cima.
static func _retencao(sup: Dictionary, cx: int, cz: int, tinta: Color) -> void:
	var folga := Vias.FOLGA_RETENCAO
	var y := 0.014
	var ax := Vias.meia_asfalto_x_no(cx, cz)
	var az := Vias.meia_asfalto_z_no(cx, cz)
	# Quem desce o braco norte anda para -Z e tem a direita em +X.
	if Vias.braco_n(cx, cz):
		var a := MalhaUrbana.meia_asfalto(MalhaUrbana.via_x_em(cx, cz))
		KitModular.chao(sup, &"marca_via", Vector3(0.08, y, az + folga - 0.14),
			Vector2(maxf(0.4, a - 0.16), 0.28), 6.0, tinta)
	# Quem sobe o braco sul anda para +Z, direita em -X.
	if Vias.braco_s(cx, cz):
		var a := MalhaUrbana.meia_asfalto(MalhaUrbana.via_x_em(cx, cz - 1))
		KitModular.chao(sup, &"marca_via",
			Vector3(-maxf(0.4, a - 0.16) - 0.08, y, -(az + folga) - 0.14),
			Vector2(maxf(0.4, a - 0.16), 0.28), 6.0, tinta)
	# Quem vem pelo leste anda para -X, direita em -Z.
	if Vias.braco_l(cx, cz):
		var a := MalhaUrbana.meia_asfalto(MalhaUrbana.via_z_em(cz, cx))
		KitModular.chao(sup, &"marca_via",
			Vector3(ax + folga - 0.14, y, -maxf(0.4, a - 0.16) - 0.08),
			Vector2(0.28, maxf(0.4, a - 0.16)), 6.0, tinta)
	# Quem vem pelo oeste anda para +X, direita em +Z.
	if Vias.braco_o(cx, cz):
		var a := MalhaUrbana.meia_asfalto(MalhaUrbana.via_z_em(cz, cx - 1))
		KitModular.chao(sup, &"marca_via",
			Vector3(-(ax + folga) - 0.14, y, 0.08),
			Vector2(0.28, maxf(0.4, a - 0.16)), 6.0, tinta)


## Zebrado do acostamento: barras amarelo-sujo no meio-fio (faixa de
## estacionamento). Marca o espaco da blitz sem subir na calcada.
##
## Nao pinta perto de um cruzamento sinalizado: a faixa de estacionamento e a
## faixa de pedestre moram na MESMA tira de asfalto (entre a pista e o
## meio-fio), e sem essa exclusao a zebra amarela do acostamento atravessava a
## zebra branca da travessia e a linha de retencao. `cx`/`cz` sao deste chunk;
## cada borda tem dois cantos, e cada canto pode ou nao ser um cruzamento.
static func _pintura_estacionamento(sup: Dictionary, bordas: Dictionary,
		px0: float, pz0: float, cx: int, cz: int, _tinta: Color) -> void:
	var amarelo := Color(0.78, 0.68, 0.22)
	_zebrar_faixa(sup, bordas["x0"], px0, true, true, amarelo,
		not Vias.existe_cruzamento(cx, cz), not Vias.existe_cruzamento(cx, cz + 1))
	_zebrar_faixa(sup, bordas["x1"], px0, true, false, amarelo,
		not Vias.existe_cruzamento(cx + 1, cz), not Vias.existe_cruzamento(cx + 1, cz + 1))
	_zebrar_faixa(sup, bordas["z0"], pz0, false, true, amarelo,
		not Vias.existe_cruzamento(cx, cz), not Vias.existe_cruzamento(cx + 1, cz))
	_zebrar_faixa(sup, bordas["z1"], pz0, false, false, amarelo,
		not Vias.existe_cruzamento(cx, cz + 1), not Vias.existe_cruzamento(cx + 1, cz + 1))


## `no_zero`: borda em coordenada 0 do chunk; senao, borda em TAM. `livre_perto`
## e `livre_longe` liberam as barras perto de cada uma das duas pontas da
## borda (coordenada 0 e coordenada TAM ao longo dela); false pula as barras a
## menos de FOLGA_CRUZAMENTO daquela ponta.
const FOLGA_CRUZAMENTO := 9.5

static func _zebrar_faixa(sup: Dictionary, via: int, meia_asf: float,
		eixo_ao_longo_z: bool, no_zero: bool, cor: Color,
		livre_perto: bool = true, livre_longe: bool = true) -> void:
	var est := MalhaUrbana.largura_estacionamento(via)
	if est < 0.4 or meia_asf < 0.4:
		return
	var pista := MalhaUrbana.meia_pista(via)
	var y := 0.013
	var origem_trans := (pista if no_zero else MalhaUrbana.TAM - meia_asf)
	for i in 10:
		var ao_longo := 1.4 + float(i) * 3.0
		if ao_longo > MalhaUrbana.TAM - 1.4:
			break
		if not livre_perto and ao_longo < FOLGA_CRUZAMENTO:
			continue
		if not livre_longe and ao_longo > MalhaUrbana.TAM - FOLGA_CRUZAMENTO:
			continue
		if eixo_ao_longo_z:
			KitModular.chao(sup, &"marca_via",
				Vector3(origem_trans, y, ao_longo),
				Vector2(est, 0.38), 6.0, cor)
		else:
			KitModular.chao(sup, &"marca_via",
				Vector3(ao_longo, y, origem_trans),
				Vector2(0.38, est), 6.0, cor)


## As quatro zebras de um cruzamento, a partir de `travessias`.
##
## Cada risca e COMPRIDA NA DIREcao DA VIA QUE ELA CRUZA e fina na direcao em
## que o pedestre anda — a "escada": olhando de cima, uma faixa de pedestre e um
## conjunto de barras deitadas ATRAVESSANDO a pista, e nao barras compridas no
## sentido da travessia. A primeira versao saiu com os eixos trocados: a risca
## se esticava pela avenida inteira e cruzava a fileira de arvore, que so existe
## porque fica longe do cruzamento.
##
## A barra pega as duas metades da pista, porque e o chunk dono que desenha o
## cruzamento inteiro (ver sinais_do_cruzamento). FAIXA_PROFUNDIDADE fica curta
## (1,5 m): cabe folgado na menor calcada possivel (a da rua comum, 2,2 m) sem
## encostar na fachada — cruzamento so existe onde as duas vias sao RUA ou
## AVENIDA, nunca viela.
static func _faixa_pedestre(sup: Dictionary, cx: int, cz: int,
		tinta: Color) -> void:
	var y := 0.014
	var passo := FAIXA_BARRA + FAIXA_VAO
	for t: Dictionary in travessias(cx, cz):
		var centro: Vector3 = t["centro"]
		var meia: float = t["meia_largura"]
		var n := maxi(3, int(meia * 2.0 / passo))
		var d := meia * 2.0 / float(n)
		for k in n:
			var u := -meia + (float(k) + 0.5) * d
			if int(t["eixo_marcha"]) == 1:
				# Pedestre anda em X: barras se repetem em X, compridas em Z.
				KitModular.chao(sup, &"marca_via",
					Vector3(u - FAIXA_BARRA * 0.5, y,
						centro.z - FAIXA_PROFUNDIDADE * 0.5),
					Vector2(FAIXA_BARRA, FAIXA_PROFUNDIDADE), 6.0, tinta)
			else:
				# Pedestre anda em Z: barras se repetem em Z, compridas em X.
				KitModular.chao(sup, &"marca_via",
					Vector3(centro.x - FAIXA_PROFUNDIDADE * 0.5, y,
						u - FAIXA_BARRA * 0.5),
					Vector2(FAIXA_PROFUNDIDADE, FAIXA_BARRA), 6.0, tinta)


# --- quadra -----------------------------------------------------------------

## Preenche a area util do chunk. Devolve o maior numero de andares construido,
## que os props usam para saber a que altura pendurar coisa.
static func _quadra(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], cx: int, cz: int, bordas: Dictionary,
		quadra: Dictionary, lim: Rect2, rng: RandomNumberGenerator,
		lotes_saida: Array[Dictionary] = []) -> int:
	if lim.size.x < 2.0 or lim.size.y < 2.0:
		return 0

	# Com ladeira, o que acompanha o chao (patio, quintal, beco, baldio) e
	# assentado vertice a vertice; o predio da fileira sobe rigido, lote a lote,
	# dentro de `_fileira`.
	var inclinado := not Relevo.plano(cx, cz)
	var m0 := Relevo.marcar(sup)
	var c0 := colisao.size()
	var p0 := props.size()

	match int(quadra["uso"]):
		MalhaUrbana.Uso.PARQUE:
			ParqueBuilder.construir(sup, props, colisao, quadra, cx, cz)
			# Parque e patamar (Relevo._nivel_do_parque): o chunk inteiro esta
			# no mesmo nivel, e o que o ParqueBuilder montou plano sobe junto.
			# A Praca da Matriz fica em zero e nem passa por aqui.
			if inclinado:
				Relevo.erguer(sup, m0, colisao, c0, props, p0,
					Relevo.local(cx, cz, Vector3(TAM * 0.5, 0.0, TAM * 0.5)))
			return 0
		MalhaUrbana.Uso.BALDIO:
			var alto := _baldio(sup, colisao, bordas, lim)
			# Capim, entulho, arvoreta e a obra parada: sem isto o baldio era
			# um plano de terra liso do tamanho da quadra (BaldioBuilder).
			BaldioBuilder.construir(sup, colisao, faces_de_rua(bordas, lim), quadra,
				lim, cx, cz, rng)
			if inclinado:
				Relevo.assentar(sup, m0, colisao, c0, props, p0, cx, cz)
			return alto

	# Chao do patio interno. Nunca e pisado, mas aparece pela fresta entre dois
	# predios e por cima do muro do terreno vizinho. `max_quad` folgado: e um
	# plano de 26 m que ninguem chega perto o suficiente para ver a UV afim.
	#
	# Escurecido a um terco. A textura de terra e clara, e patio de quarteirao
	# fechado nao recebe poste nenhum: no tom cheio, a fresta entre dois predios
	# virava uma faixa amarela acesa no meio da quadra.
	var serpentina := bool(quadra.get("serpentina", false))
	if serpentina:
		# Celula de encosta (Serpentina): o miolo e pasto, e se anda por ele.
		KitModular.chao(sup, &"grama", Vector3(lim.position.x, 0.02, lim.position.y),
			lim.size, 8.0, SerpentinaBuilder.COR_PASTO)
	else:
		KitModular.chao(sup, &"terra", Vector3(lim.position.x, 0.02, lim.position.y),
			lim.size, 8.0, Color(0.34, 0.34, 0.32))

	# A porta de entrada do chunk, para a fachada saber onde NAO por painel. Sem
	# isto o terreo cobria a propria porta em que o jogador tem de entrar, e a
	# unica pista de que ali dava para entrar era o rotulo aparecendo do nada.
	var porta := _porta_do_chunk(cx, cz, quadra)

	var faces := faces_de_rua(bordas, lim)
	if faces.is_empty():
		# Miolo de quadra grande. Galpao baixo, so para nao ser um buraco quando
		# a fresta entre dois predios deixa ver ate aqui.
		# No miolo da encosta nao ha galpao: e a serpentina, montada depois do
		# chao assentado (construir).
		# O miolo vivo (edicula, galpao, galinheiro, pomar: MioloVivo) sai depois
		# do chao assentado, rigido e com altura absoluta. As caixas de `_anexos`
		# ficam para `--sem-fachada-viva` e `--sem-telhado-vivo`.
		var vivo := FachadaViva.ativo and TelhadoVivo.ativo and not serpentina
		var baixo := 0 if serpentina or vivo else _anexos(sup, colisao, quadra, lim, rng)
		if inclinado:
			Relevo.assentar(sup, m0, colisao, c0, props, p0, cx, cz)
		if vivo:
			baixo = MioloVivo.construir(sup, colisao, quadra, lim, cx, cz)
		return baixo
	if inclinado:
		Relevo.assentar(sup, m0, colisao, c0, props, p0, cx, cz)

	var maior := 0
	var lotes: Array[Dictionary] = []
	var becos := BecoBuilder.becos(cx, cz)
	for face: Dictionary in faces:
		# A entrada da serpentina abre a fileira como um beco, e toma o lugar
		# do beco que a face teria.
		var vao := SerpentinaBuilder.vao_na_face(cx, cz, face) if serpentina else {}
		var beco := BecoBuilder.da_face(becos, face)
		if not vao.is_empty():
			if not beco.is_empty():
				becos.erase(beco)
			beco = vao
		maior = maxi(maior, _fileira(sup, props, colisao, rng, face, quadra, porta,
			lotes, beco, cx, cz, faces))
	# A lateral que fica a vista por cima do vizinho mais baixo (EmpenaViva), depois
	# de todas as fileiras e antes do quintal, que assenta no chao.
	if FachadaViva.ativo:
		EmpenaViva.construir(sup, faces, lotes, cx, cz)
	# O que fica atras da fileira: muro de divisa, quintal, miolo. Ver
	# FundosBuilder — e o que a viela mostrava como buraco.
	var m1 := Relevo.marcar(sup)
	var c1 := colisao.size()
	var p1 := props.size()
	FundosBuilder.quintais(sup, colisao, faces, lotes, quadra, lim, rng)
	BecoBuilder.construir(sup, colisao, faces, becos, rng, lotes)
	if inclinado:
		Relevo.assentar(sup, m1, colisao, c1, props, p1, cx, cz)
	lotes_saida.append_array(lotes)
	return maior


## As faces da area util que dao para uma rua, como retas orientadas e ja
## descontada a esquina.
##
## O desconto e o detalhe que decide se a quadra fecha. A fileira do eixo X pega
## a profundidade toda em Z; a do eixo Z tem de comecar depois do volume dela,
## senao os dois se sobrepoem na esquina e o predio da esquina fica com duas
## fachadas dentro uma da outra. De que LADO descontar depende de a rua do eixo X
## estar no minimo ou no maximo — descontar sempre do inicio deixava um vao de
## oito metros num dos dois casos.
##
## Publica porque o mapa desenha a massa dos predios a partir destas mesmas
## faces, e uma segunda copia da regra divergiria no primeiro ajuste.
static func faces_de_rua(bordas: Dictionary, lim: Rect2) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var recorte_inicio := 0.0
	var recorte_fim := 0.0

	# `meio_fio`: da linha da fachada ate a quina da calcada, que e onde a rampa
	# de garagem (DetalheCalcada.guia_rebaixada) encosta.
	if bordas["x0"] != MalhaUrbana.Via.NENHUMA:
		saida.append({"direcao": 3, "canto": Vector3(lim.position.x, 0.0, lim.position.y),
			"eixo": Vector3.BACK, "comprimento": lim.size.y,
			"meio_fio": lim.position.x - MalhaUrbana.meia_asfalto(bordas["x0"])})
		recorte_inicio = PROF_PREDIO
	elif bordas["x1"] != MalhaUrbana.Via.NENHUMA:
		saida.append({"direcao": 1, "canto": Vector3(lim.end.x, 0.0, lim.position.y),
			"eixo": Vector3.BACK, "comprimento": lim.size.y,
			"meio_fio": TAM - MalhaUrbana.meia_asfalto(bordas["x1"]) - lim.end.x})
		recorte_fim = PROF_PREDIO

	# A direcao e para onde a FACHADA olha, e nao onde a rua esta. Rua no minimo
	# de Z quer dizer fachada olhando para -Z, que e a direcao 2; rua no maximo,
	# fachada para +Z, direcao 0. As duas estavam trocadas.
	#
	# O sintoma nao era o obvio. A massa do predio e posicionada meia
	# profundidade CONTRA a normal, entao com a normal invertida ela nascia oito
	# metros para dentro da rua — e como a fileira so desenha as faces laterais e
	# o topo, quase nao se via nada: o que se via era a calcada intransitavel do
	# outro lado, com a colisao de um predio invisivel em cima dela. Um terco da
	# linha de marcha da cidade estava assim.
	var comp_z := lim.size.x - recorte_inicio - recorte_fim
	if comp_z > 4.0:
		if bordas["z0"] != MalhaUrbana.Via.NENHUMA:
			saida.append({"direcao": 2,
				"canto": Vector3(lim.position.x + recorte_inicio, 0.0, lim.position.y),
				"eixo": Vector3.RIGHT, "comprimento": comp_z,
				"meio_fio": lim.position.y - MalhaUrbana.meia_asfalto(bordas["z0"])})
		elif bordas["z1"] != MalhaUrbana.Via.NENHUMA:
			saida.append({"direcao": 0,
				"canto": Vector3(lim.position.x + recorte_inicio, 0.0, lim.end.y),
				"eixo": Vector3.RIGHT, "comprimento": comp_z,
				"meio_fio": TAM - MalhaUrbana.meia_asfalto(bordas["z1"]) - lim.end.y})
	return saida


## Uma fileira de predios encostados, ao longo de uma face da quadra.
##
## Cada predio e um volume proprio com altura, cor e coroamento proprios, e e
## isso que faz a rua ler como quarteirao em vez de um paredao de 26 m. A cor e a
## do bloco: os predios de uma quadra sao parentes, e a diferenca aparece ao
## atravessar a rua e nao dentro da mesma calcada.
static func _fileira(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], rng: RandomNumberGenerator,
		face: Dictionary, quadra: Dictionary, porta: Dictionary = {},
		lotes: Array[Dictionary] = [], beco: Dictionary = {}, cx: int = 0,
		cz: int = 0, faces_da_quadra: Array[Dictionary] = []) -> int:
	var direcao: int = face["direcao"]
	var normal := KitModular._normal(direcao)
	var eixo: Vector3 = face["eixo"]
	var canto: Vector3 = face["canto"]
	var comprimento: float = face["comprimento"]
	if comprimento < 5.0:
		return 0

	# Onde a porta cai ao longo DESTA face. `_porta_do_chunk` e `faces_de_rua`
	# leem a mesma lista de faces, entao projetar a posicao da porta no eixo da
	# face devolve a mesma distancia que gerou a porta — nao ha segunda copia da
	# regra para divergir.
	var porta_em := NAN
	if not porta.is_empty() and int(porta["direcao"]) == direcao:
		porta_em = (Vector3(porta["pos"]) - canto).dot(eixo)

	var ao_longo_de_z := absf(eixo.z) > 0.5
	# As duas pontas desta face em que a fileira PERPENDICULAR fica logo atras do
	# lote: ali o fundo nao aparece para ninguem, e sai so a parede (15% dos
	# fundos, medidos no levantamento).
	var tapado_no_inicio := false
	var tapado_no_fim := false
	if ao_longo_de_z:
		for f: Dictionary in faces_da_quadra:
			if int(f["direcao"]) == 2:
				tapado_no_inicio = true
			elif int(f["direcao"]) == 0:
				tapado_no_fim = true
	var maior := 0
	var base_andares := int(quadra["andares"])
	var tinta: Color = quadra["tinta"]
	# O trecho da face ainda sem predio. O bar e a casa da fumaca comem uma ponta
	# dele; a fileira comum reparte o resto INTEIRO, sem sobra (ver `repartir`).
	var livre_de := 0.0
	var livre_ate := comprimento
	# Ladeira: cada lote sobe rigido pela altura do chao na porta dele (ou no
	# meio da fachada), com embasamento de pedra por baixo. Ver `_erguer_lote`.
	var inclinado := not Relevo.plano(cx, cz)

	# O bar come o PRIMEIRO trecho da face, e nao um sorteado no meio dela.
	#
	# Isso nao e estetica, e sincronia: `_porta_do_chunk` precisa anunciar a
	# posicao do bar para o mapa sem construir o chunk, e a largura dos outros
	# trechos sai de `rng`. Fixando o bar no comeco da face, os dois lados
	# calculam o mesmo numero a partir so do comprimento da face, e o icone do
	# mapa cai exatamente na boca do salao. De quebra, o comeco da face e junto
	# da esquina, que e onde bar de bairro fica mesmo.
	if not porta.is_empty() and is_finite(porta_em) 			and porta.get("interior", &"") == &"bar":
		var larg_bar := largura_do_bar(comprimento)
		var m_bar := Relevo.marcar(sup)
		var c_bar := colisao.size()
		var p_bar := props.size()
		maior = maxi(maior, _predio_do_bar(sup, props, colisao, rng, face,
			quadra, larg_bar))
		lotes.append({"face": face, "de": 0.0, "ate": larg_bar, "casa": false, "bar": true,
			"piso": _retangulo_do_lote(face, 0.0, larg_bar, PROF_PREDIO)})
		if inclinado:
			_erguer_lote(sup, colisao, props, m_bar, c_bar, p_bar, cx, cz,
				canto + eixo * (larg_bar * 0.5), normal, larg_bar, PROF_PREDIO,
				canto + eixo * (larg_bar * 0.5))
		livre_de = larg_bar
		# A porta ja foi resolvida: nenhum trecho comum deve abrir vao por ela.
		porta_em = NAN

	# A casa da fumaca come um lote da face, no comeco ou no fim dela (ver
	# KitFumaca.lote_na_face). Os outros trechos dividem o que sobra.
	if not porta.is_empty() and bool(porta.get("mundo", false)) 			and int(porta["direcao"]) == direcao:
		var m_fum := Relevo.marcar(sup)
		var c_fum := colisao.size()
		var p_fum := props.size()
		# A loja de conveniencia tambem: o lote e as medidas sao da planta
		# (LoteNoMundo), e o predio dela e PredioMercado.
		var planta_lote := StringName(porta["interior"])
		var tam_lote := LoteNoMundo.lote(planta_lote)
		if planta_lote == &"mercado":
			maior = maxi(maior, PredioMercado.construir(sup, props, colisao, rng, face,
				quadra, porta, cx, cz))
		else:
			maior = maxi(maior, _predio_da_fumaca(sup, props, colisao, rng, face,
				quadra, porta))
		var inicio_lote := float(porta["lote_inicio"])
		lotes.append({"face": face, "de": inicio_lote,
			"ate": inicio_lote + tam_lote.x, "casa": planta_lote != &"mercado",
			"fumaca": planta_lote == &"casa_fumaca",
			# Fundo proprio: o lote entra no patio alem da fileira, e o quintal, o
			# muro e o miolo contornam ele (FundosBuilder.quintais).
			"fundo": tam_lote.y,
			"piso": _retangulo_do_lote(face, inicio_lote, inicio_lote + tam_lote.x,
				LoteNoMundo.fundo_da_pegada(planta_lote))})
		# A frente dela (KitFumaca.fachada) sai em `_props`, pela mesma altura:
		# a do chao na dobradica da porta.
		var dy_lote := 0.0
		if inclinado:
			dy_lote = _erguer_lote(sup, colisao, props, m_fum, c_fum, p_fum, cx, cz,
				canto + eixo * (inicio_lote + tam_lote.x * 0.5), normal,
				tam_lote.x, tam_lote.y, Vector3(porta["pos"]))
		# O vao da escada do porao da casa da fumaca (LoteNoMundo.pegada_do_porao).
		lotes[-1].merge(LoteNoMundo.pegada_do_porao(planta_lote, porta["planta"], dy_lote))
		if planta_lote == &"mercado":
			# O piso da loja, para o chao da quadra nao furar ele (construir).
			lotes[-1]["piso_y"] = KitFumaca.PISO_Y + dy_lote
		if inicio_lote < 0.5:
			livre_de = maxf(livre_de, tam_lote.x)
		else:
			livre_ate = minf(livre_ate, inicio_lote)
		porta_em = NAN

	# As faces que alguem chega a ver. A externa some atras da fachada e a base
	# fica enterrada. A de tras sai em FundosBuilder.fundo, com quad folgado:
	# era a que faltava, e por ela o patio mostrava o avesso das casas.
	var faces := (PSXMesh.FACE_FRENTE | PSXMesh.FACE_TRAS | PSXMesh.FACE_TOPO) \
		if ao_longo_de_z else (PSXMesh.FACE_DIR | PSXMesh.FACE_ESQ | PSXMesh.FACE_TOPO)

	# O beco (BecoBuilder) corta o trecho livre em dois, e cada lado se reparte
	# sozinho. Ele entra na lista de lotes para o quintal saber que ali nao ha
	# casa — e nao por varal e tanque no meio do corredor.
	var trechos: Array[Vector2] = [Vector2(livre_de, livre_ate)]
	if not beco.is_empty():
		var b0 := float(beco["de"])
		var b1 := float(beco["ate"])
		trechos = [Vector2(livre_de, b0), Vector2(b1, livre_ate)]
		lotes.append({"face": face, "de": b0, "ate": b1, "casa": false, "beco": true,
			"vila": bool(beco.get("vila", false)),
			"serpentina": bool(beco.get("serpentina", false))})
	var pecas: Array[Vector2] = []
	for tr: Vector2 in trechos:
		var inicio := tr.x
		for larg_peca: float in repartir(tr.y - tr.x, _lote_alvo(quadra), rng):
			pecas.append(Vector2(inicio, larg_peca))
			inicio += larg_peca

	for i in pecas.size():
		var cursor := pecas[i].x
		var larg := pecas[i].y
		var m_lote := Relevo.marcar(sup)
		var c_lote := colisao.size()
		var p_lote := props.size()

		# Um andar para cima ou para baixo em volta da altura da quadra. Mais que
		# isso e a quadra que perde a identidade; menos e um paredao.
		var andares := maxi(1, base_andares + rng.randi_range(-1, 1))
		var altura := andares * KitModular.ALTURA_ANDAR
		maior = maxi(maior, andares)
		# A tinta da quadra e o parentesco; 20% de outra tinta e o primo. Sem
		# isso a fileira e um paredao da mesma cor, mesmo com vaos diferentes.
		var tinta_local: Color = tinta.lerp(
			MalhaUrbana.TINTAS[rng.randi() % MalhaUrbana.TINTAS.size()], 0.22)
		# Rua de casas do interior e colorida CASA A CASA: cada dono pintou a sua
		# de uma cor, e a fileira e amarelo, azul, rosa, creme. O reboco claro
		# aguenta a tinta sem virar mancha; azulejo e concreto ficam na tinta da
		# quadra, que e quase branca.
		var mat_fachada: StringName = quadra["fachada"]
		if bool(quadra["casa"]) and rng.randf() < 0.7:
			mat_fachada = &"reboco"
			tinta_local = MalhaUrbana.CORES_CASA[rng.randi() % MalhaUrbana.CORES_CASA.size()]

		var meio := cursor + larg * 0.5

		# A porta deste trecho, medida do centro dele. NAN quando a porta do
		# chunk esta em outro predio da mesma fileira.
		var porta_local := NAN
		if is_finite(porta_em) and porta_em >= cursor and porta_em < cursor + larg:
			# Centro da FOLHA na coordenada da fachada (KitModular._lateral), e
			# nao a dobradica medida no eixo da face: nas faces +X e -Z o eixo
			# corre ao contrario do lateral, e o quadro da porta saia espelhado
			# a ate 7,5 m da folha. A folha vai 0,9 m da dobradica (Porta).
			porta_local = (Vector3(porta["pos"]) - (canto + eixo * meio)).dot(
				KitModular._lateral(direcao)) + 0.45

		# Casa recuada com jardim na frente (FundosBuilder.jardim). Nunca a da
		# porta interativa — a folha nasce na linha da quadra — nem a de esquina,
		# cuja lateral e a fachada da rua transversal. A casa fica mais rasa em
		# vez de avancar sobre o quintal: o fundo continua em PROF_PREDIO e os
		# muros de tras nao mudam.
		var esq_inicio := ao_longo_de_z and cursor < 0.01 and canto.z > 0.01
		var esq_fim := ao_longo_de_z and cursor + larg > comprimento - 0.01 \
			and canto.z + comprimento < TAM - 0.01
		var esquina := esq_inicio or esq_fim

		# Os outros bares da cidade (BarVivo): o primeiro lote comercial que cabe o
		# salao vira bar de verdade, o mesmo do Seu Ze com outro nome e outra cor.
		# Um por chunk; nunca na esquina (a lateral e fachada) nem no lote da porta.
		if BarVivo.tem_bar(cx, cz, quadra, porta) and not esquina \
				and not is_finite(porta_local) and larg >= KitBar.LARGURA_MINIMA + 0.5 \
				and not lotes.any(func(l: Dictionary) -> bool: return bool(l.get("bar", false))):
			var estilo := BarVivo.estilo(cx, cz)
			var larg_bar := minf(larg, KitBar.LARGURA_ALVO + 1.0)
			maior = maxi(maior, _predio_do_bar(sup, props, colisao, rng, face, quadra,
				larg_bar, cursor, estilo))
			lotes.append({"face": face, "de": cursor, "ate": cursor + larg, "casa": false,
				"bar": true, "piso": _retangulo_do_lote(face, cursor, cursor + larg,
					PROF_PREDIO)})
			if larg_bar < larg - 0.05:
				# O que sobrou do lote fica com uma empena de alvenaria ate o vizinho:
				# o salao do bar nao e mais largo que o do Seu Ze.
				var resto := larg - larg_bar
				var c_resto := canto + eixo * (cursor + larg_bar + resto * 0.5) \
					- normal * (PROF_PREDIO * 0.5) + Vector3(0.0, KitModular.ALTURA_ANDAR, 0.0)
				var t_resto := Vector3(PROF_PREDIO, KitModular.ALTURA_ANDAR * 2.0, resto) \
					if ao_longo_de_z else Vector3(resto, KitModular.ALTURA_ANDAR * 2.0, PROF_PREDIO)
				_massa(sup, c_resto, t_resto, normal, tinta_local, faces)
				colisao.append({"tamanho": t_resto, "pos": c_resto})
				# A frente da sobra. `faces` e da fileira: sem a face da rua (ali ha
				# sempre fachada), e a sobra ficava um vao aberto para o quintal
				# (varrer_patio, 2,3 m no Bar do Chicao). Parede de reboco com a
				# janela do andar de cima: a casinha estreita colada no bar.
				var frente_resto := canto + eixo * (cursor + larg_bar + resto * 0.5) \
					+ normal * AVANCO_FACHADA
				KitModular.parede(sup, &"reboco", frente_resto + Vector3(0.0, KitModular.ALTURA_ANDAR, 0.0),
					Vector2(resto, KitModular.ALTURA_ANDAR * 2.0), direcao, tinta_local)
				if resto >= 1.4:
					KitModular.parede(sup, &"janela_acesa" if rng.randf() < float(quadra["janela"])
						else &"janela_apagada", frente_resto + normal * 0.02
						+ Vector3(0.0, KitModular.ALTURA_ANDAR + 1.5, 0.0),
						Vector2(minf(0.9, resto - 0.5), 1.2), direcao)
			# Na ladeira o lote inteiro (salao e sobra) sobe junto, pela altura do
			# chao na boca do bar: a sobra emitida depois ficava em y = 0, 26 m
			# acima do chao do Bar do Chicao, e o vao dela abria o quintal.
			if inclinado:
				_erguer_lote(sup, colisao, props, m_lote, c_lote, p_lote, cx, cz,
					canto + eixo * (cursor + larg * 0.5), normal, larg, PROF_PREDIO,
					canto + eixo * (cursor + larg_bar * 0.5))
			continue

		# Esquina chanfrada (EsquinaBuilder): a venda, o bar, o armazem da quina,
		# com a porta na diagonal. Nunca no lote da porta interativa — a folha
		# nasce na linha da quadra, e ali agora e calcada. Nem na ladeira: o
		# triangulo de calcada e a diagonal sairiam rigidos sobre chao inclinado.
		# O teste vem depois do sorteio, para o chunk inclinado gastar o mesmo rng.
		if esquina and not is_finite(porta_local) and larg >= 7.0 and andares <= 3 \
				and rng.randf() < 0.45 and not inclinado:
			var na_largada := cursor < 0.01 and canto.z > 0.01
			EsquinaBuilder.construir(sup, colisao, face, cursor, larg, na_largada,
				rng.randf_range(2.4, 3.2), andares, quadra, tinta_local, mat_fachada, rng)
			FundosBuilder.fundo(sup, canto + eixo * meio, larg, andares, direcao,
				float(quadra["janela"]), rng, tinta_local)
			lotes.append({"face": face, "de": cursor, "ate": cursor + larg,
				"casa": bool(quadra["casa"])})
			continue
		var recuo := 0.0
		if bool(quadra["casa"]) and not is_finite(porta_local) and not esquina \
				and larg >= 5.5 and rng.randf() < 0.3:
			recuo = rng.randf_range(2.6, 3.6)
		# Casa de rua de Minas (FachadaViva): o plano decide antes da massa o
		# estilo, o morador, a cor e o material do corpo, e os andares.
		# Na rua comercial, ComercioVivo (sobrado, loja de marquise, predio).
		var plano := {}
		if FachadaViva.ativo and bool(quadra["casa"]):
			plano = FachadaViva.planejar(rng, quadra, larg, andares, tinta_local)
		elif FachadaViva.ativo:
			plano = ComercioVivo.planejar(rng, quadra, larg, andares, tinta_local)
			# Fora do comercial e da quadra de casas, a rua de servico
			# (IndustriaViva): galpao, oficina, deposito, armazem, fabrica. Era o
			# distrito industrial inteiro no kit antigo.
			if plano.is_empty():
				plano = IndustriaViva.planejar(rng, quadra, larg, andares, tinta_local)
		# A loja de verdade do chunk (LojaViva): o primeiro lote comercial que cabe
		# o salao. Um por chunk; nunca na esquina (a lateral e fachada), nem no
		# lote da porta, nem onde a calcada desce ao longo da frente (o piso da
		# loja fica rente a ela na boca).
		var loja_viva := {}
		if plano.has("tipo") and not plano.has("industria") and not esquina \
				and not is_finite(porta_local) and larg >= LojaViva.LARGURA_MINIMA \
				and LojaViva.tem_loja(cx, cz, quadra, porta) \
				and not lotes.any(func(l: Dictionary) -> bool: return l.has("loja")) \
				and _frente_plana(cx, cz, canto + eixo * meio, KitModular._lateral(direcao),
					larg, inclinado) \
				and _boca_livre(cx, cz, canto + eixo * meio, KitModular._lateral(direcao),
					normal, LojaViva.plano(cx, cz, larg)):
			loja_viva = LojaViva.plano(cx, cz, larg)
			plano["loja_viva"] = loja_viva
			# Dois andares no minimo: o terreo e a loja, e em cima mora alguem.
			plano["andares"] = maxi(2, int(plano["andares"]))
		if not plano.is_empty():
			andares = int(plano["andares"])
			altura = andares * KitModular.ALTURA_ANDAR
			# O deposito tem patio de manobra na frente, como a casa tem jardim.
			var recuo_plano := float(plano.get("recuo", 0.0))
			if recuo_plano > 0.0 and not is_finite(porta_local) and not esquina:
				recuo = recuo_plano
			plano["recuo_real"] = recuo
		var fundura := PROF_PREDIO - recuo
		if not plano.is_empty():
			# O comodo atras da janela aberta para no meio da casa: o de tras vem do
			# outro lado (FundosVivos.fundo).
			plano["fundura"] = fundura
			# Os lados da casa (no sinal de KitModular._lateral) que dao para a rua
			# transversal: ali o telhado vira agua em vez de empena (TelhadoVivo).
			var sinal := signf(eixo.dot(KitModular._lateral(direcao)))
			plano["quinas"] = ([-sinal] if esq_inicio else []) + ([sinal] if esq_fim else [])
		# Na loja o terreo e o salao (KitLoja): a massa comeca no primeiro andar.
		var pe := KitModular.ALTURA_ANDAR if not loja_viva.is_empty() else 0.0
		var centro := canto + eixo * meio - normal * (recuo + fundura * 0.5) \
			+ Vector3(0.0, pe + (altura - pe) * 0.5, 0.0)
		var tamanho := Vector3(fundura, altura - pe, larg) if ao_longo_de_z \
			else Vector3(larg, altura - pe, fundura)

		# Na esquina do sistema novo a lateral vira fachada (FundosVivos.lateral),
		# com vao de verdade: a massa sai sem essa face, senao ela ficaria dentro da
		# ParedeVazada.
		var faces_lote := faces
		if not plano.is_empty():
			if esq_inicio:
				faces_lote &= ~PSXMesh.FACE_TRAS
			if esq_fim:
				faces_lote &= ~PSXMesh.FACE_FRENTE
		_massa(sup, centro, tamanho, normal, plano.get("cor_corpo", tinta_local), faces_lote,
			plano.get("mat_corpo", &"concreto_sujo"))
		colisao.append({"tamanho": tamanho, "pos": centro})

		var frente_lote := canto + eixo * meio
		var frente := frente_lote - normal * recuo

		# Ladeira: a base do lote sai antes de qualquer peca, e vai no ponto ALTO da
		# frente. Enterrar a fachada le como erro de mundo (o peitoril pousa na
		# grama, e pela janela aberta o chao da quadra atravessa o comodo); o que a
		# cidade de morro tem de verdade e o degrau na porta, que e pequeno.
		# `perfil` e o chao ao longo da fachada, relativo a base: a porta ganha a
		# escada e a garagem so sai onde a guia rebaixada encontra o portao.
		var lateral_lote := KitModular._lateral(direcao)
		var cantos_extras: Array[Vector3] = []
		if esq_inicio:
			cantos_extras.append(canto + eixo * cursor - normal * fundura)
		if esq_fim:
			cantos_extras.append(canto + eixo * (cursor + larg) - normal * fundura)
		var dy_lote := 0.0
		var perfil := PackedFloat32Array()
		if inclinado:
			dy_lote = _altura_do_lote(cx, cz, frente, lateral_lote, larg,
				Vector3(porta["pos"]) if is_finite(porta_local) else frente,
				is_finite(porta_local) or not loja_viva.is_empty(), cantos_extras)
			for k in 9:
				perfil.append(Relevo.local(cx, cz,
					frente + lateral_lote * ((float(k) / 8.0 - 0.5) * larg)) - dy_lote)
		if not plano.is_empty():
			plano["perfil"] = perfil

		# Quadra de casas ganha frente de casa. O terreo comercial nao e um
		# estilo alternativo: numa rua residencial ele produzia uma fileira de
		# portas de aco fechadas, e nenhuma delas era a porta de entrar.
		var tem_loja := false
		# Onde fica a porta do lote, do meio da fachada: e a altura do chao ali
		# que o lote toma na ladeira, para a soleira ficar rente a calcada.
		# A lateral de esquina e o fundo leem de `info_frente` a esquadria, as faixas
		# e o nome da loja, para a casa ser a mesma dos quatro lados (FundosVivos).
		var info_frente := {}
		var porta_do_lote := 0.0
		# O jardim e a guia rebaixada acompanham o chao, e nao o lote.
		var m_chao := Relevo.marcar(sup)
		var c_chao := colisao.size()
		if bool(quadra["casa"]):
			var garagens: Array = []
			if not plano.is_empty():
				FachadaViva.residencia(sup, frente + normal * AVANCO_FACHADA, larg, andares,
					direcao, plano, float(quadra["janela"]), porta_local, false, garagens,
					info_frente)
			else:
				tem_loja = KitFachada.residencia(sup, frente + normal * AVANCO_FACHADA, larg,
					andares, direcao, mat_fachada, rng,
					float(quadra["janela"]), tinta_local, porta_local, false, garagens,
					info_frente)
			if is_finite(float(info_frente.get("porta", NAN))):
				porta_do_lote = float(info_frente["porta"])
			m_chao = Relevo.marcar(sup)
			c_chao = colisao.size()
			if recuo > 0.0:
				FundosBuilder.jardim(sup, colisao, frente_lote, larg, recuo, direcao,
					float(info_frente.get("porta", NAN)), tinta_local, rng)
			else:
				# A rampa de concreto na sarjeta em frente a cada portao de garagem.
				# Casa recuada nao ganha: entre o portao e a rua ha o jardim murado.
				var lateral_casa := KitModular._lateral(direcao)
				for g: float in garagens:
					DetalheCalcada.guia_rebaixada(sup,
						frente + lateral_casa * g + normal * float(face.get("meio_fio", 2.2)),
						normal, 2.5)
		if recuo > 0.0 and plano.has("industria"):
			# O patio murado do deposito, com o portao gradeado na linha da calcada.
			IndustriaViva.patio(sup, colisao, frente_lote, larg, recuo, direcao, plano)
		var m_chao_fim := Relevo.marcar(sup)
		var c_chao_fim := colisao.size()
		if not bool(quadra["casa"]):
			var prob_loja := float(quadra["loja"])
			if plano.has("industria"):
				tem_loja = IndustriaViva.fachada(sup, frente + normal * AVANCO_FACHADA, larg,
					andares, direcao, plano, float(quadra["janela"]), porta_local, info_frente)
			elif not plano.is_empty():
				tem_loja = ComercioVivo.fachada(sup, frente + normal * AVANCO_FACHADA, larg,
					andares, direcao, plano, float(quadra["janela"]), porta_local, info_frente)
				if not loja_viva.is_empty():
					KitLoja.salao(sup, colisao, props, frente, KitModular._lateral(direcao),
						normal, larg, loja_viva)
			else:
				tem_loja = KitModular.fachada(sup, frente + normal * AVANCO_FACHADA, larg,
					andares, direcao, quadra["fachada"], rng, prob_loja,
					float(quadra["janela"]), tinta_local, porta_local)
			if is_finite(float(info_frente.get("porta", NAN))):
				porta_do_lote = float(info_frente["porta"])

		# Predio de esquina: a lateral que da para a rua transversal ganha janela.
		# So a fileira do eixo X tem esquina — ela fica com a quina (faces_de_rua),
		# e a ponta dela so e esquina onde a area util nao encosta na borda do chunk.
		for ponta: Vector2 in [Vector2(cursor, -1.0) if esq_inicio else Vector2.ZERO,
				Vector2(cursor + larg, 1.0) if esq_fim else Vector2.ZERO]:
			if ponta.y == 0.0:
				continue
			if plano.is_empty():
				FundosBuilder.lateral_de_esquina(sup, face, ponta.x, ponta.y, andares,
					float(quadra["janela"]), bool(quadra["casa"]), tinta_local, rng)
			else:
				# A lateral da esquina e fachada: a mesma parede, as mesmas faixas e a
				# mesma esquadria da frente (FundosVivos.lateral).
				FundosVivos.lateral(sup, face, ponta.x, ponta.y, andares, plano,
					float(quadra["janela"]), info_frente, cx, cz,
					dy_lote if inclinado else NAN)

		if tem_loja and bool(quadra["toldo"]):
			KitPredio.toldo(sup, frente + normal * 0.1 + Vector3(0.0, 2.6, 0.0),
				larg * 0.72, direcao, int(quadra["semente"]) + i)

		# A casa da FachadaViva traz balcao e remate proprios.
		if bool(quadra["sacada"]) and andares >= 2 and plano.is_empty():
			for andar in range(1, andares):
				KitPredio.sacada(sup,
					frente + normal * 0.08 + Vector3(0.0, andar * KitModular.ALTURA_ANDAR, 0.0),
					larg * 0.55, direcao, tinta_local)

		if plano.has("industria"):
			IndustriaViva.coroar(sup, plano, Vector3(centro.x, altura, centro.z),
				Vector3(tamanho.x, 0.0, tamanho.z), direcao, rng)
		elif plano.has("tipo"):
			ComercioVivo.coroar(sup, plano, Vector3(centro.x, altura, centro.z),
				Vector3(tamanho.x, 0.0, tamanho.z), direcao, rng)
		elif not plano.is_empty():
			FachadaViva.coroar(sup, plano, Vector3(centro.x, altura, centro.z),
				Vector3(tamanho.x, 0.0, tamanho.z), direcao, rng)
		else:
			KitPredio.coroar(sup, quadra["coroamento"],
				Vector3(centro.x, altura, centro.z),
				Vector3(tamanho.x, 0.0, tamanho.z), direcao, tinta_local, rng)

		if plano.is_empty():
			FundosBuilder.fundo(sup, frente_lote, larg, andares, direcao,
				float(quadra["janela"]), rng, tinta_local)
		else:
			# O fundo no sistema novo: vao de verdade, corpo no reboco da casa, e a
			# porta da cozinha pela altura do quintal (FundosVivos.fundo).
			var cego := (tapado_no_inicio and cursor + larg <= PROF_PREDIO + 0.05) \
				or (tapado_no_fim and cursor >= comprimento - PROF_PREDIO - 0.05)
			FundosVivos.fundo(sup, frente_lote, larg, andares, direcao, plano,
				float(quadra["janela"]), info_frente, cx, cz, dy_lote if inclinado else NAN,
				cego)
		var lote := {"face": face, "de": cursor, "ate": cursor + larg,
			"casa": bool(quadra["casa"])}
		if not loja_viva.is_empty():
			lote["loja"] = loja_viva["id"]
			lote["loja_ramo"] = int(loja_viva["ramo"])
			lote["loja_boca"] = frente_lote + normal * AVANCO_FACHADA
			lote["loja_normal"] = normal
		if not plano.is_empty():
			lote["plano"] = plano
			# A base do lote na ladeira: a empena entre vizinhos (EmpenaViva) sai com
			# altura absoluta.
			lote["dy"] = dy_lote
			if info_frente.has("porta_fundo"):
				lote["porta_fundo"] = info_frente["porta_fundo"]
			if inclinado:
				# A planta da casa (sem o jardim da recuada), 5 cm para dentro das
				# paredes: o chao da quadra desce abaixo do piso ali (construir).
				var r0 := FundosBuilder._ponto(face, cursor + 0.05, recuo + 0.05)
				var r1 := FundosBuilder._ponto(face, cursor + larg - 0.05, PROF_PREDIO - 0.05)
				lote["rebaixo"] = Rect2(Vector2(minf(r0.x, r1.x), minf(r0.z, r1.z)),
					Vector2(absf(r1.x - r0.x), absf(r1.z - r0.z)))
				lote["rebaixo_y"] = dy_lote - 0.05
		lotes.append(lote)
		if inclinado:
			# A porta de entrar e a do prop, que `_props` ergue pela altura do
			# chao no ponto dela: o lote dela toma a mesma altura.
			var soleira := Vector3(porta["pos"]) if is_finite(porta_local) \
				else frente_lote + KitModular._lateral(direcao) * porta_do_lote
			var dy := _erguer_lote(sup, colisao, props, m_lote, c_lote, p_lote, cx, cz,
				frente, normal, larg, fundura, soleira, dy_lote)
			Relevo.reassentar(sup, m_chao, m_chao_fim, colisao, c_chao, c_chao_fim,
				cx, cz, dy)

	return maior


## Um lote da fileira na ladeira: tudo o que ele emitiu desde a marca sobe
## rigido pela altura do chao na `soleira`, e por baixo entra o embasamento de
## pedra — so onde ele aparece, isto e, onde o chao sob o lote desce abaixo da
## soleira. Devolve a altura usada.
static func _erguer_lote(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], marca: Dictionary, c0: int, p0: int, cx: int,
		cz: int, frente: Vector3, normal: Vector3, larg: float, fundo: float,
		soleira: Vector3, dy_forcado: float = NAN) -> float:
	var dy := dy_forcado if is_finite(dy_forcado) else Relevo.local(cx, cz, soleira)
	var lateral := Vector3(absf(normal.z), 0.0, absf(normal.x))
	var mais_baixo := dy
	for canto: Vector2 in [Vector2(-0.5, 0.0), Vector2(0.5, 0.0), Vector2(-0.5, 1.0),
			Vector2(0.5, 1.0)]:
		mais_baixo = minf(mais_baixo, Relevo.local(cx, cz,
			frente + lateral * (canto.x * larg) - normal * (canto.y * fundo)))
	if dy - mais_baixo > 0.01:
		# Fundo o bastante para o canto mais baixo do lote, com folga: na encosta
		# forte o chao sob o fundo da casa fica metros abaixo da soleira.
		Relevo.embasamento(sup, frente, normal, larg, fundo, AVANCO_FACHADA,
			maxf(Relevo.EMBASAMENTO, dy - mais_baixo + 0.8), colisao)
		_capa_do_embasamento(sup, frente, normal, lateral, larg, fundo)
		_porao(sup, cx, cz, frente, normal, larg, fundo, dy)
	Relevo.erguer(sup, marca, colisao, c0, props, p0, dy)
	return dy


## A capa de pedra do embasamento: o anel de cima dele, fora das paredes.
##
## O embasamento (Relevo.embasamento) e uma caixa sem face de cima, 10 cm a frente
## da fachada e 3 cm alem das outras paredes, com o topo 16 cm acima do pe delas.
## Olhando de cima, rente a quina, o raio passava por cima da borda da pedra e por
## baixo do pe da parede, e dava no vazio dentro da caixa (bancada_quinas, chunk
## -1,-2). A face de cima inteira nao serve: ela cairia dentro do comodo da janela
## aberta e colada no piso do salao da loja. So o anel, e ele entra 2 cm por baixo
## das paredes.
static func _capa_do_embasamento(sup: Dictionary, frente: Vector3, normal: Vector3,
		lateral: Vector3, larg: float, fundo: float) -> void:
	var h := KitModular.ALTURA_MEIO_FIO
	var sai := AVANCO_FACHADA + 0.1
	var meia := larg * 0.5 + 0.03
	# (s0, s1, t0, t1): s para dentro a partir da linha da quadra, t ao longo.
	var faixas: Array[Vector4] = [
		Vector4(-sai, 0.02, -meia, meia),
		Vector4(fundo - 0.02, fundo + 0.03, -meia, meia),
		Vector4(-sai, fundo + 0.03, -meia, -meia + 0.05),
		Vector4(-sai, fundo + 0.03, meia - 0.05, meia),
	]
	for f: Vector4 in faixas:
		var a := frente - normal * f.x + lateral * f.z
		var b := frente - normal * f.y + lateral * f.w
		KitModular.chao(sup, &"pedra_parque", Vector3(minf(a.x, b.x), h, minf(a.z, b.z)),
			Vector2(absf(b.x - a.x), absf(b.z - a.z)), 4.0, Relevo.COR_EMBASAMENTO)


## Se a calcada corre plana o bastante ao longo da frente do lote para a loja:
## o piso dela fica rente a calcada na boca, e as pontas nao podem enterrar nem
## flutuar mais que LojaViva.DESNIVEL_MAXIMO.
static func _frente_plana(cx: int, cz: int, frente: Vector3, lateral: Vector3, larg: float,
		inclinado: bool) -> bool:
	if not inclinado:
		return true
	var alturas: Array[float] = []
	for k in 5:
		alturas.append(Relevo.local(cx, cz, frente + lateral * ((float(k) / 4.0 - 0.5) * larg)))
	return alturas.max() - alturas.min() <= LojaViva.DESNIVEL_MAXIMO


## Se a calcada na frente da boca da loja esta livre de arvore e de poste. A
## arvore de rua e plantada antes dos lotes (`arvores`, pura), entao quem desvia
## e a loja: com o tronco no meio da porta, a casa de racao abria para uma
## arvore.
static func _boca_livre(cx: int, cz: int, frente: Vector3, lateral: Vector3,
		normal: Vector3, plano: Dictionary) -> bool:
	var meia := float(plano["boca"]) * 0.5 + 0.9
	var obstaculos := arvores(cx, cz)
	obstaculos.append(_poste_local(MalhaUrbana.bordas(cx, cz)))
	for p: Vector3 in obstaculos:
		var d := p - frente
		if absf(d.dot(lateral)) < meia and d.dot(normal) > -0.5 and d.dot(normal) < 4.5:
			return false
	return true


## A altura em que o lote assenta na ladeira.
##
## No lote da porta interativa e o chao na folha: o no de `Porta` nasce por ali
## (`pontos_de_interesse`) e o vao da fachada tem de cair em cima dele. Nos
## outros e o ponto ALTO da frente — os dois cantos dela, mais o canto de tras
## da lateral quando ela e fachada de esquina.
##
## Enterrar a fachada le como erro de mundo: a maquineta some no barranco, o
## peitoril pousa na grama e, com a janela aberta, o chao da quadra atravessa o
## comodo. O que a cidade de morro tem de verdade e o degrau na porta, e ele e
## pequeno: mediana de 15 cm, p90 de 58 cm (levantamento da ladeira, ver
## PLANO_CASAS_AAA.md).
static func _altura_do_lote(cx: int, cz: int, frente: Vector3, lateral: Vector3,
		larg: float, soleira: Vector3, interativa: bool,
		extras: Array[Vector3]) -> float:
	if interativa:
		return Relevo.local(cx, cz, soleira)
	var dy := Relevo.local(cx, cz, frente - lateral * (larg * 0.5))
	dy = maxf(dy, Relevo.local(cx, cz, frente + lateral * (larg * 0.5)))
	for ponto: Vector3 in extras:
		dy = maxf(dy, Relevo.local(cx, cz, ponto))
	return dy


## Quanto o chao atras da casa desce abaixo da soleira para o embasamento
## virar porao (`_porao`).
const PORAO_MINIMO := 2.4


## O porao da casa de encosta: quando o chao atras dela desce mais que um andar
## abaixo da soleira, o embasamento de pedra deixa de ser rodape e vira o andar
## de baixo — a porta da cozinha no nivel do quintal e as janelinhas do porao,
## que e como a casa pendurada no morro se ve do lado de baixo. Emitido antes de
## `erguer`, no espaco do lote (a soleira em y = 0).
static func _porao(sup: Dictionary, cx: int, cz: int, frente: Vector3, normal: Vector3,
		larg: float, fundo: float, dy: float) -> void:
	var tras := frente - normal * (fundo + 0.06)
	var chao_tras := Relevo.local(cx, cz, tras) - dy
	if chao_tras > -PORAO_MINIMO:
		return
	var dir_tras := FundosBuilder._direcao_de(-normal)
	var lateral := KitModular._lateral(dir_tras)
	var n := maxi(1, int(larg / 3.0))
	var passo := larg / float(n)
	for k in n:
		var off := (float(k) - float(n - 1) * 0.5) * passo
		var no_chao := Relevo.local(cx, cz, tras + lateral * off) - dy
		if k == n / 2:
			# A porta da cozinha, rente ao quintal.
			KitModular.parede(sup, &"porta", tras + lateral * off
				+ Vector3(0.0, no_chao + 1.05, 0.0), Vector2(0.9, 2.1), dir_tras)
		elif -no_chao > 1.6:
			KitModular.parede(sup, &"janela_apagada", tras + lateral * off
				+ Vector3(0.0, no_chao + 1.5, 0.0), Vector2(0.9, 0.7), dir_tras)
	# A porta dos fundos da casa (FundosBuilder.fundo) fica na altura da
	# soleira: com o porao embaixo ela dava para o vazio. A varanda de fundos e
	# o que a casa de morro poe ali.
	KitPredio.sacada(sup, frente - normal * (fundo + 0.08), larg * 0.8, dir_tras,
		Color(0.72, 0.7, 0.66))


## O retangulo de chao de um lote, de `de` a `ate` ao longo da face e `fundo`
## metros para dentro, em coordenada local.
static func _retangulo_do_lote(face: Dictionary, de: float, ate: float,
		fundo: float) -> Rect2:
	var a := FundosBuilder._ponto(face, de, 0.0)
	var b := FundosBuilder._ponto(face, ate, fundo)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.z, b.z)),
		Vector2(absf(b.x - a.x), absf(b.z - a.z)))


## Lote minimo de uma fileira. Menos que isto nao cabe porta e janela lado a
## lado, e a casa vira um corredor de fachada.
const LOTE_MINIMO := 4.5


## Larguras dos predios de uma face, somando EXATAMENTE `comprimento`.
##
## A versao anterior sorteava dois ou tres trechos com `clampf(x, 6, sobra)` —
## e quando a face era curta a sobra ficava menor que seis: o clamp com minimo
## acima do maximo devolvia a sobra, o laco via menos de quatro metros e parava.
## Numa face de 14,8 m isso apagava a fileira INTEIRA uma vez em cada tres, e
## nas outras deixava 2,8 m sem predio no fim da face. Eram as bocas por onde a
## rua dava para o patio: 23 de 31 quarteiroes tinham pelo menos uma.
##
## Aqui o numero de lotes sai do comprimento e da largura alvo, cada um varia
## vinte por cento em volta da media, e o ultimo fecha a conta. Nao sobra nada.
static func repartir(comprimento: float, alvo: float,
		rng: RandomNumberGenerator) -> PackedFloat32Array:
	var saida := PackedFloat32Array()
	if comprimento < 0.5:
		return saida
	var n := maxi(1, roundi(comprimento / alvo))
	while n > 1 and comprimento / float(n) < LOTE_MINIMO * 1.25:
		n -= 1
	var pesos := PackedFloat32Array()
	var soma := 0.0
	for i in n:
		var p := rng.randf_range(0.8, 1.2)
		pesos.append(p)
		soma += p
	var usado := 0.0
	for i in n:
		var larg := comprimento * pesos[i] / soma if i < n - 1 \
			else comprimento - usado
		saida.append(larg)
		usado += larg
	return saida


## Largura tipica de lote da quadra. Casa de rua do interior tem frente estreita
## — sete, oito metros —; comercio um pouco mais; galpao industrial pede frente
## larga. Tres lotes de dez metros numa rua residencial liam como predio.
static func _lote_alvo(quadra: Dictionary) -> float:
	if bool(quadra["casa"]):
		return 7.5
	match int(quadra["distrito"]):
		MalhaUrbana.Distrito.INDUSTRIAL:
			return 12.0
		_:
			return 9.0


## A massa de um predio da fileira, desenhada ate o plano da fachada.
##
## A caixa vinha so com as laterais e o topo, comecando na linha da quadra, e a
## fachada 6 cm a frente dela. Na ponta da fileira sobrava uma fresta vertical do
## chao ao telhado entre a borda da fachada e a lateral, e por ela se via o patio
## pelo avesso da caixa — o "buraco pro limbo" na quina de todo predio de
## esquina. A lateral agora vai ate a fachada. A colisao continua na linha da
## quadra: seis centimetros nao mudam o andar, e mexer nela mexeria na linha de
## marcha.
static func _massa(sup: Dictionary, centro: Vector3, tamanho: Vector3,
		normal: Vector3, tinta: Color, faces: int,
		material: StringName = &"concreto_sujo") -> void:
	var fundo := tamanho + normal.abs() * AVANCO_FACHADA
	KitModular.caixa_cor(sup, material,
		centro + normal * (AVANCO_FACHADA * 0.5), fundo, tinta, 0.0, faces)


## O lote da casa da fumaca: casca, fachada com o vao de verdade e o no que
## monta a sala quando o jogador chega perto (InteriorNoMundo).
static func _predio_da_fumaca(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], rng: RandomNumberGenerator,
		face: Dictionary, quadra: Dictionary, porta: Dictionary) -> int:
	var direcao: int = face["direcao"]
	var normal := KitModular._normal(direcao)
	var lateral := KitModular._lateral(direcao)
	var eixo: Vector3 = face["eixo"]
	var canto: Vector3 = face["canto"]
	var em_planta: Transform3D = porta["planta"]
	var larg := KitFumaca.LOTE.x

	# Casa de um ou dois pavimentos: a da fumaca nao e predio de esquina.
	var andares := clampi(int(quadra["andares"]) + rng.randi_range(-1, 0), 1, 2)
	var altura := andares * KitModular.ALTURA_ANDAR
	var tinta_local: Color = Color(quadra["tinta"]).lerp(
		MalhaUrbana.TINTAS[rng.randi() % MalhaUrbana.TINTAS.size()], 0.22)

	KitFumaca.casca(sup, colisao, em_planta, altura, tinta_local)

	var frente := canto + eixo * (float(porta["lote_inicio"]) + larg * 0.5)
	var vao := em_planta * KitFumaca.centro_do_vao()
	var porta_local := (vao - frente).dot(lateral)
	KitFachada.residencia(sup, frente + normal * AVANCO_FACHADA, larg, andares, direcao,
		quadra["fachada"], rng, float(quadra["janela"]), tinta_local, porta_local,
		true)
	var fundo := KitFumaca.LOTE.y
	var ao_longo_de_z := absf(eixo.z) > 0.5
	KitPredio.coroar(sup, quadra["coroamento"],
		frente - normal * (fundo * 0.5) + Vector3(0.0, altura, 0.0),
		Vector3(fundo, 0.0, larg) if ao_longo_de_z else Vector3(larg, 0.0, fundo),
		direcao, tinta_local, rng)

	props.append({
		"tipo": "interior_mundo",
		"planta": em_planta,
		"interior": porta["interior"],
		"semente": porta["semente"],
	})
	return andares


## Largura do trecho de predio que o bar ocupa numa face de dado comprimento.
##
## Publica e sem rng de proposito: `_porta_do_chunk` chama isto para anunciar a
## boca do bar no mapa sem construir o chunk, e `_predio_do_bar` chama para
## construir. Uma conta so, dois chamadores, nenhum jeito de divergirem.
static func largura_do_bar(comprimento: float) -> float:
	return clampf(KitBar.LARGURA_ALVO, KitBar.LARGURA_MINIMA, comprimento)


## Um trecho de predio com o TERREO VAZADO: o Bar do Seu Ze.
##
## A diferenca para `_fileira` e uma so, e e toda a diferenca: o volume solido
## comeca em KitBar.ALTURA_SALAO em vez de comecar no chao. Abaixo disso nao ha
## caixa nem colisao de quarteirao — ha o salao, com tres paredes e a frente
## aberta para a rua. Nao existe porta, area de acionamento nem interior a
## carregar: quem anda da calcada para dentro ja esta no bar.
##
## `cursor` e onde o trecho comeca na face (o Seu Ze fica no comeco dela) e
## `estilo` o dos outros bares da cidade (BarVivo); vazio e o Seu Ze.
static func _predio_do_bar(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], rng: RandomNumberGenerator,
		face: Dictionary, quadra: Dictionary, larg: float, cursor: float = 0.0,
		estilo: Dictionary = {}) -> int:
	var direcao: int = face["direcao"]
	var normal := KitModular._normal(direcao)
	var lateral := KitModular._lateral(direcao)
	var eixo: Vector3 = face["eixo"]
	var canto: Vector3 = face["canto"]
	var ao_longo_de_z := absf(eixo.z) > 0.5

	# Dois andares no minimo. Com um so, o terreo vazado seria o predio inteiro
	# e o bar liria como galpao sem frente; o que faz a foto de referencia
	# funcionar e ter casa em cima do bar.
	var andares := maxi(2, int(quadra["andares"]) + rng.randi_range(-1, 1))
	var altura := andares * KitModular.ALTURA_ANDAR
	var tinta_local: Color = Color(quadra["tinta"]).lerp(
		MalhaUrbana.TINTAS[rng.randi() % MalhaUrbana.TINTAS.size()], 0.22)

	var meio := cursor + larg * 0.5
	var frente: Vector3 = canto + eixo * meio
	var pe := KitBar.ALTURA_SALAO
	var alto := altura - pe

	var faces := ((PSXMesh.FACE_FRENTE | PSXMesh.FACE_TRAS | PSXMesh.FACE_TOPO) \
		if ao_longo_de_z else (PSXMesh.FACE_DIR | PSXMesh.FACE_ESQ | PSXMesh.FACE_TOPO)) \
		| FundosBuilder.face_de_tras(direcao)
	var centro := frente - normal * (PROF_PREDIO * 0.5) \
		+ Vector3(0.0, pe + alto * 0.5, 0.0)
	var tamanho := Vector3(PROF_PREDIO, alto, larg) if ao_longo_de_z \
		else Vector3(larg, alto, PROF_PREDIO)
	_massa(sup, centro, tamanho, normal, tinta_local, faces)
	colisao.append({"tamanho": tamanho, "pos": centro})

	# Fachada dos andares de cima. So dali para cima: no terreo a parede e a
	# ausencia dela.
	var plano := frente + normal * AVANCO_FACHADA
	KitModular.parede(sup, quadra["fachada"],
		plano + Vector3(0.0, pe + alto * 0.5, 0.0), Vector2(larg, alto),
		direcao, tinta_local)
	var prob_acesa := float(quadra["janela"])
	for andar in range(1, andares):
		var y := andar * KitModular.ALTURA_ANDAR + 1.5
		var nj := maxi(1, int(larg / 2.6))
		var passo := larg / float(nj)
		for j in nj:
			var off := (float(j) - float(nj - 1) * 0.5) * passo
			KitModular.parede(sup,
				&"janela_acesa" if rng.randf() < prob_acesa else &"janela_apagada",
				plano + Vector3(0.0, y, 0.0) + lateral * off,
				Vector2(1.1 if (j % 2) == 0 else 0.85, 1.3), direcao)
	KitPredio.coroar(sup, quadra["coroamento"],
		Vector3(centro.x, altura, centro.z),
		Vector3(tamanho.x, 0.0, tamanho.z), direcao, tinta_local, rng)

	# O bar. `boca` no nivel da calcada: entrar nao pode ter degrau, senao a
	# passagem vira obstaculo e o lugar volta a ter soleira.
	var giro := atan2(normal.x, normal.z)
	var boca := frente
	boca.y = KitModular.ALTURA_MEIO_FIO
	var semente := int(quadra["semente"]) + 8801 + int(cursor * 131.0)
	KitBar.frente(sup, colisao, boca, giro, larg, estilo)
	KitBar.mesas_da_calcada(sup, colisao, boca, giro, larg, estilo)
	KitBar.salao(sup, colisao, props, boca, giro, larg, semente, estilo)

	# Lampada do toldo, sobre a calcada. A do salao ja saiu de KitBar.salao; o
	# orcamento da skill psx-city e quatro dinamicas no chunk, e o poste da rua
	# ja gastou uma.
	props.append({
		"tipo": "lampada",
		"pos": boca + normal * 1.1 + Vector3(0.0, KitBar.ALTURA_SALAO - 0.35, 0.0),
		"padrao": Lampada.Padrao.ESTAVEL,
		"semente": semente + 17,
		"cor": Color("ffcf8a"), "energia": 2.2, "alcance": 6.5, "facho": false,
	})
	return andares


## Terreno baldio: chao de terra e muro baixo no lugar do quarteirao. E a pausa
## visual que faz o resto da cidade parecer densa.
static func _baldio(sup: Dictionary, colisao: Array[Dictionary],
		bordas: Dictionary, lim: Rect2) -> int:
	# Baldio recebe luz de rua pelas frestas do muro, entao nao vai tao escuro
	# quanto o patio fechado.
	KitModular.chao(sup, &"terra", Vector3(lim.position.x, 0.02, lim.position.y),
		lim.size, 4.0, Color(0.62, 0.61, 0.58))
	for face: Dictionary in faces_de_rua(bordas, lim):
		var comp := float(face["comprimento"])
		var meio: Vector3 = Vector3(face["canto"]) + Vector3(face["eixo"]) * (comp * 0.5)
		KitModular.parede(sup, &"concreto_sujo", meio + Vector3(0.0, 0.9, 0.0),
			Vector2(comp, 1.8), int(face["direcao"]))
	colisao.append({
		"tamanho": Vector3(lim.size.x, 1.8, lim.size.y),
		"pos": Vector3(lim.get_center().x, 0.9, lim.get_center().y),
	})
	return 1


## Galpoes do miolo de quadra grande. Nunca sao alcancados; existem para a
## fresta entre dois predios nao mostrar o nada.
static func _anexos(sup: Dictionary, colisao: Array[Dictionary],
		quadra: Dictionary, lim: Rect2, rng: RandomNumberGenerator) -> int:
	var tinta: Color = quadra["tinta"]
	for i in rng.randi_range(2, 4):
		var w := rng.randf_range(6.0, 13.0)
		var d := rng.randf_range(5.0, 11.0)
		var p := Vector2(
			rng.randf_range(lim.position.x, maxf(lim.position.x, lim.end.x - w)),
			rng.randf_range(lim.position.y, maxf(lim.position.y, lim.end.y - d)))
		var alt := rng.randf_range(3.0, 6.5)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			Vector3(p.x + w * 0.5, alt * 0.5, p.y + d * 0.5), Vector3(w, alt, d),
			tinta.lerp(Color("8b8880"), 0.3), 0.0,
			PSXMesh.FACE_TODAS, 8.0)
		colisao.append({"tamanho": Vector3(w, alt, d),
			"pos": Vector3(p.x + w * 0.5, alt * 0.5, p.y + d * 0.5)})
	return 2


# --- props ------------------------------------------------------------------

static func _props(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], cx: int, cz: int, bordas: Dictionary,
		quadra: Dictionary, lim: Rect2, rng: RandomNumberGenerator,
		_andares: int, lotes: Array[Dictionary] = []) -> void:
	_iluminacao(sup, props, cx, cz, bordas)

	# Na ladeira os pontos ja chegam no chao (ver `pontos_de_interesse`), e a
	# frente de loja ou da casa da fumaca desenhada a partir deles tambem.
	for ponto: Dictionary in pontos_de_interesse(cx, cz):
		match ponto["tipo"]:
			&"porta":
				# A loja que existe na rua ja montou a propria frente, com a
				# porta automatica, em `_fileira` (PredioMercado).
				if ponto["interior"] == &"mercado" and bool(ponto.get("mundo", false)):
					continue
				props.append({
					"tipo": "porta",
					"pos": ponto["pos"],
					"giro": ponto["giro"],
					"semente": ponto["semente"],
					"interior": ponto["interior"],
					"deslizante": ponto["deslizante"],
					"mundo": ponto.get("mundo", false),
					"espera_dono": ponto.get("espera_dono", false),
				})
				if ponto["interior"] == &"mercado":
					var normal := KitModular._normal(int(ponto["direcao"]))
					_fachada_de_loja(sup, props, colisao,
						Vector3(ponto["pos"]) - normal * KitMercado.SALIENCIA,
						float(ponto["giro"]), cx, cz)
				elif ponto["interior"] == &"casa_fumaca":
					# A frente da casa da fumaca. Vale para TODA casa da fumaca da
					# cidade, e nao so para a da primeira missao: o jogador tem de
					# aprender a reconhecer o lugar, e com uma casa marcada so ele
					# decora um endereco. Ver KitFumaca.
					var mundo := bool(ponto.get("mundo", false))
					var base: Vector3 = ponto.get("base_kit", ponto["pos"])
					KitFumaca.fachada(sup, colisao, base,
						float(ponto["giro"]), int(ponto["semente"]), mundo)
					KitFumaca.props(props, base,
						float(ponto["giro"]), int(ponto["semente"]))
			&"telefone":
				props.append({
					"tipo": "save",
					"pos": ponto["pos"],
					"giro": ponto["giro"],
					"local": ponto["local"],
				})

	var faces := faces_de_rua(bordas, lim)
	_soltos(props, cx, cz, faces, rng)
	if int(quadra["uso"]) == MalhaUrbana.Uso.EDIFICADO:
		_maquina(sup, props, colisao, cx, cz, faces, quadra, rng, lotes)
	_semaforos(sup, props, cx, cz)
	NomesDeRua.placas(sup, props, cx, cz)


## Poste, lampada e fiacao. A fiacao so sai para vizinhos que tambem tem poste,
## senao o cabo termina no ar no meio da viela.
static func _iluminacao(sup: Dictionary, props: Array[Dictionary],
		cx: int, cz: int, _bordas: Dictionary) -> void:
	if not tem_poste(cx, cz):
		return
	var poste_mundo := posicao_poste(cx, cz)
	var local := poste_mundo - Vector3(cx * TAM, 0.0, cz * TAM)
	var dir_braco := Vector3(1.0, 0.0, 0.0) if local.x < TAM * 0.5 else Vector3(-1.0, 0.0, 0.0)
	# `posicao_poste` ja vem no chao do morro: o poste sobe pelo pe dele, e o
	# cabo vai de topo a topo, o do vizinho pela altura do chao de la.

	KitModular.poste(sup, local, dir_braco)

	# Um poste em cada tres esta morrendo. O defeito so assusta quando e excecao.
	props.append({
		"tipo": "lampada",
		"pos": local + dir_braco * 1.4 + Vector3(0.0, 6.35, 0.0),
		"padrao": Lampada.Padrao.SODIO_FALHANDO if posmod(cx * 3 + cz, 3) == 1 			else Lampada.Padrao.ESTAVEL,
		"semente": 4001 + cx * 137 + cz * 911,
	})

	# Fiacao para os dois vizinhos seguintes. Cada chunk desenha so os cabos que
	# saem dele, entao nenhum vao e desenhado duas vezes.
	var topo := local + Vector3(0.0, 6.9, 0.0)
	for passo: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not tem_poste(cx + passo.x, cz + passo.y):
			continue
		var no_vizinho := posicao_poste(cx + passo.x, cz + passo.y)
		var vizinho := no_vizinho - Vector3(cx * TAM, 0.0, cz * TAM) \
			+ Vector3(0.0, 6.9, 0.0)
		KitModular.fiacao(sup, topo, vizinho)


## Os quatro semaforos e os quatro sinais de pedestre do cruzamento desta quina.
##
## Cada chunk monta so o cruzamento da PROPRIA quina de origem, (cx, cz). Como
## todo cruzamento e a origem de exatamente um chunk, cada um e montado uma vez
## e nenhum e montado duas — sem precisar que os vizinhos estejam carregados.
##
## Uma esquina de verdade em cada canto, e nao dois postes colados num so.
## Mastro, cabeca e lentes apagadas entram na malha do chunk (custo zero de
## desenho); so a lente acesa e um no. As quatro esquinas saem deste chunk,
## inclusive as de coordenada local negativa: a peca so some quando o chunk
## dono descarrega, e isso pede o jogador a tres chunks (~96 m) — a nevoa fecha
## antes de 45. E a mesma conta de distancia de que Semaforo.estado() ja
## depende.
##
##   canto    eixo do semaforo   halo   giro     pedestre cruza    conflita com
##   NE +x+z   1 (carro em X)     sim    PI/2     a via do eixo Z   eixo 1
##   NW -x+z   0 (carro em Z)     sim    0        a via do eixo X   eixo 0
##   SE +x-z   0                  nao    0        a via do eixo X   eixo 0
##   SW -x-z   1                  nao    PI/2     a via do eixo Z   eixo 1
static func _semaforos(sup: Dictionary, props: Array[Dictionary],
		cx: int, cz: int) -> void:
	# Sem semaforo (so a avenida tem, ver Semaforo.tem_sinal): placa de PARE onde
	# estaria o semaforo de cada aproximacao da rua que NAO e a preferencial
	# (Vias.preferencial). E a placa que o carro obedece em Carro._teto_do_pare.
	var com_sinal := Semaforo.tem_sinal(cx, cz)
	var pref := Vias.preferencial(cx, cz)
	for sinal: Dictionary in sinais_do_cruzamento(cx, cz):
		# Cada mastro no chao da propria esquina (Relevo): as quatro esquinas de
		# um cruzamento na ladeira nao estao na mesma altura.
		var pos: Vector3 = sinal["pos"]
		pos.y += Relevo.local(cx, cz, pos)
		var ped_pos: Vector3 = sinal["ped_pos"]
		ped_pos.y += Relevo.local(cx, cz, ped_pos)
		if not com_sinal:
			if bool(sinal["com_semaforo"]) and int(sinal["eixo"]) != pref:
				# O semaforo e lido DEPOIS do cruzamento; a placa de PARE fica
				# ANTES dele, na mesma mao: e o mesmo canto espelhado no eixo em
				# que o carro anda.
				var onde: Vector3 = sinal["pos"]
				if int(sinal["eixo"]) == 0:
					onde.z = -onde.z
				else:
					onde.x = -onde.x
				onde.y += Relevo.local(cx, cz, onde)
				_placa_pare(sup, onde, float(sinal["giro"]))
			continue
		if bool(sinal["com_semaforo"]):
			KitModular.semaforo(sup, pos, sinal["giro"])
			props.append({
				"tipo": "semaforo",
				"pos": pos,
				"cruzamento": Vector2i(cx, cz),
				"eixo": sinal["eixo"],
				"giro": sinal["giro"],
				"halo": sinal["halo"],
			})
		if not bool(sinal["com_pedestre"]):
			continue
		KitModular.sinal_pedestre(sup, ped_pos, sinal["ped_giro"])
		props.append({
			"tipo": "sinal_pedestre",
			"pos": ped_pos,
			"cruzamento": Vector2i(cx, cz),
			"eixo_conflito": sinal["ped_eixo_conflito"],
			"giro": sinal["ped_giro"],
		})


## Placa de PARE: octogono vermelho com borda branca num poste, virada para
## quem chega. `giro` e o da cabeca do semaforo daquela aproximacao — encara o
## carro que vem (giro_de_face).
static func _placa_pare(sup: Dictionary, base: Vector3, giro: float) -> void:
	const ALTURA := 2.25
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var lado := Vector3(cos(giro), 0.0, -sin(giro))
	KitModular.caixa(sup, &"metal", base + Vector3(0.0, ALTURA * 0.5, 0.0),
		Vector3(0.07, ALTURA, 0.07), giro)
	var centro := base + Vector3(0.0, ALTURA - 0.05, 0.0)
	for camada: Array in [[0.34, Color(0.92, 0.92, 0.9), -0.012],
			[0.3, Color(0.72, 0.08, 0.06), 0.0]]:
		var r := float(camada[0])
		var cantos: Array[Vector2] = []
		for k in 8:
			var a := PI / 8.0 + float(k) * PI / 4.0
			cantos.append(Vector2(r * cos(a), r * sin(a)))
		KitPredio._poligono_vertical(sup, &"metal", centro + frente * (0.05 + float(camada[2])),
			lado, frente, cantos, camada[1])
	# O verso, cinza de chapa.
	var verso: Array[Vector2] = []
	for k in 8:
		var a := PI / 8.0 + float(k) * PI / 4.0
		verso.append(Vector2(0.34 * cos(a), 0.34 * sin(a)))
	KitPredio._poligono_vertical(sup, &"metal", centro + frente * 0.028, lado, -frente,
		verso, Color(0.5, 0.5, 0.48))


## Itens largados na calcada e inimigo solto.
static func _soltos(props: Array[Dictionary], cx: int, cz: int,
		faces: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	# A tabela de raridade e o que faz municao valer: bandagem e comum, bala nao,
	# e arma quase nunca.
	var n_itens := 1 if posmod(cx * 13 + cz * 17, 2) == 0 else 0
	if posmod(cx * 29 + cz * 31, 7) == 0:
		n_itens += 1
	if faces.is_empty():
		n_itens = 0
	for k in n_itens:
		var lista: Array[StringName] = [
			&"bandagem", &"bandagem", &"bateria", &"municao_9mm",
			&"bandagem", &"bilhete", &"remedio", &"municao_9mm",
		]
		var escolhido := lista[rng.randi() % lista.size()]
		var qtd := 1
		if escolhido == &"municao_9mm":
			qtd = rng.randi_range(3, 8)
		# Sobre a calcada, encostado na parede: item no meio da rua nao le como
		# largado, le como colocado por um designer.
		var face: Dictionary = faces[k % faces.size()]
		var comp := float(face["comprimento"])
		var pos: Vector3 = Vector3(face["canto"]) 			+ Vector3(face["eixo"]) * rng.randf_range(2.5, maxf(3.0, comp - 2.5)) 			+ KitModular._normal(int(face["direcao"])) * 0.9
		pos.y = KitModular.ALTURA_MEIO_FIO + 0.55 + Relevo.local(cx, cz, pos)
		props.append({
			"tipo": "item",
			"pos": pos,
			"item": escolhido,
			"quantidade": qtd,
			"indice": k,
		})

	_inimigo_solto(props, cx, cz, faces, rng)


## Inimigo raro, e so onde a rua esvazia.
##
## No centro comercial ele competiria com pedestre e viraria figurante; no
## baldio e no industrial a calcada ja e o palco. A praca da abertura e parque,
## e por isso PARQUE fica de fora: nascer um bicho no primeiro quadro da
## cutscene e o oposto de ameaca.
##
## `posmod(..., 5) == 0` e um a cada cinco desses chunks. `checar_ameaca.gd`
## conta para o numero nao crescer em silencio.
##
## DESLIGADO (INIMIGO_NA_RUA). Solto na calcada, sem nada que o anuncie, ele lia
## como resto de teste: uma figura sem cabeca que surgia sempre no mesmo lugar e
## batia ate matar. A classe `Inimigo`, o radio e o desmaio continuam; ele volta
## quando tiver contexto (uma missao, um lugar que o jogador aprende a temer). O
## sorteio continua gastando o rng do chunk, para a maquina de venda que vem
## depois nao mudar de lugar.
const INIMIGO_NA_RUA := false


static func _inimigo_solto(props: Array[Dictionary], cx: int, cz: int,
		faces: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	if faces.is_empty():
		return
	# Os primeiros 96 m em volta da origem sao a abertura. Sem este corte o
	# sorteio pode plantar um inimigo no quadro em que o jogador acorda.
	if maxi(absi(cx), absi(cz)) < 3:
		return
	var quadra := MalhaUrbana.quadra_de(cx, cz)
	var distrito: int = int(quadra["distrito"])
	if distrito != MalhaUrbana.Distrito.BALDIO \
			and distrito != MalhaUrbana.Distrito.INDUSTRIAL:
		return
	if posmod(cx * 47 + cz * 53, 5) != 0:
		return
	var face: Dictionary = faces[rng.randi() % faces.size()]
	var comp := float(face["comprimento"])
	var pos: Vector3 = Vector3(face["canto"]) \
			+ Vector3(face["eixo"]) * rng.randf_range(3.0, maxf(4.0, comp - 3.0)) \
			+ KitModular._normal(int(face["direcao"])) * 1.6
	pos.y = Relevo.local(cx, cz, pos)
	var semente := rng.randi()
	if not INIMIGO_NA_RUA:
		return
	props.append({
		"tipo": "inimigo",
		"pos": pos,
		"semente": semente,
	})


## Maquina de venda encostada na fachada.
static func _maquina(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], cx: int, cz: int,
		faces: Array[Dictionary], quadra: Dictionary,
		rng: RandomNumberGenerator, lotes: Array[Dictionary] = []) -> void:
	var passo := int(quadra["maquina"])
	if passo >= 50 or posmod(cx * 7 + cz * 5, passo) != 0:
		return
	if faces.is_empty():
		return

	var face: Dictionary = faces[0]
	var direcao: int = face["direcao"]
	var normal := KitModular._normal(direcao)
	var eixo: Vector3 = face["eixo"]
	# "Encostada" de verdade, e nao 0,5 m solta: a calcada de rua encolheu para
	# 2,2 m quando a faixa de estacionamento nasceu (MalhaUrbana.largura_calcada)
	# e uma maquina flutuando na frente da fachada tomava metade dela, empurrando
	# a linha de marcha para cima da propria maquina.
	var base: Vector3 = Vector3(face["canto"]) 		+ eixo * rng.randf_range(4.0, maxf(4.5, float(face["comprimento"]) - 4.0)) 		+ normal * 0.32
	# Na frente da loja de conveniencia nao: a maquina taparia a porta, o
	# portao ou a vitrine. O sorteio acima acontece do mesmo jeito, para o resto
	# do chunk nao mudar.
	var porta := _porta_do_chunk(cx, cz, quadra)
	if porta.get("interior", &"") == &"mercado" and bool(porta.get("mundo", false)) \
			and int(porta["direcao"]) == direcao:
		var t := (base - Vector3(face["canto"])).dot(eixo)
		var de := float(porta["lote_inicio"])
		if t > de - 1.0 and t < de + LoteNoMundo.lote(&"mercado").x + 1.0:
			return
	# Nem na boca de bar (o Seu Ze e os da BarVivo): a maquina fechava a entrada
	# do salao, e o teste de caminhada do bar parava nela na calcada.
	var t_maq := (base - Vector3(face["canto"])).dot(eixo)
	for lote: Dictionary in lotes:
		if (bool(lote.get("bar", false)) or lote.has("loja")) and lote["face"] == face \
				and t_maq > float(lote["de"]) - 1.0 and t_maq < float(lote["ate"]) + 1.0:
			return
	base.y = KitModular.ALTURA_MEIO_FIO + Relevo.local(cx, cz, base)

	KitModular.maquina_venda(sup, base, direcao)
	colisao.append({"tamanho": Vector3(1.2, 1.9, 0.7),
		"pos": base + Vector3(0.0, 0.95, 0.0)})
	props.append({
		"tipo": "lampada",
		"pos": base + normal * 0.9 + Vector3(0.0, 1.1, 0.0),
		"padrao": Lampada.Padrao.FLUORESCENTE,
		"semente": 9001 + cx * 331 + cz * 617,
		"cor": Color("eaf2ff"),
		"energia": 2.2,
		"alcance": 5.5,
		"facho": false,
	})


## Frente de loja de conveniencia sobre a fachada do predio.
##
## Desenhada por cima do terreo que a quadra ja montou, alguns centimetros a
## frente. Existe para a loja ser reconhecivel da rua: na nevoa o jogador ve a
## mancha branca e a faixa de tres cores muito antes de ler o letreiro, e e isso
## que faz ele atravessar para ver o que e.
static func _fachada_de_loja(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], base: Vector3, giro: float,
		cx: int, cz: int) -> void:
	# O prop da porta guarda a batente esquerda do vao; o centro da loja fica uma
	# largura de folha adiante, no eixo local X da porta.
	var lateral := Vector3(cos(giro), 0.0, -sin(giro))
	var vao := Porta.FOLHA_LARGURA * 2.0
	var centro := base + lateral * Porta.FOLHA_LARGURA

	KitMercado.fachada_loja(sup, centro, 6.4, giro, vao)
	_portao_da_loja(sup, props, colisao, centro, giro, cx, cz)

	# A luz que a vitrine joga na calcada. E o que faz a loja existir no mundo em
	# vez de so na fachada: sem ela a frente brilha e o chao continua escuro.
	var normal := Vector3(sin(giro), 0.0, cos(giro))
	props.append({
		"tipo": "lampada",
		"pos": centro + normal * 1.1 + Vector3(0.0, 2.85, 0.0),
		"padrao": Lampada.Padrao.ESTAVEL,
		"semente": 61000 + cx * 191 + cz * 337,
		"cor": Color("eaf4ff"), "energia": 3.4, "alcance": 9.0, "facho": true,
	})


## O portao da garagem da loja, na calcada, ao lado da porta automatica.
##
## E a outra boca do mesmo lugar. Por dentro ele da na garagem, e sair por ele
## devolve o jogador aqui — ver Interiores.sair e KitMercado.AFASTAMENTO_PORTAO,
## que e a UNICA fonte da distancia entre os dois vaos. Se este desenho e aquele
## deslocamento saissem de numeros diferentes, o jogador atravessaria um portao
## e apareceria na frente de outro, e nada no console diria nada.
##
## Fechado, e sem prop de acionamento: da rua ele nao abre. Uma loja em que se
## entra pela garagem nao precisaria da porta da frente, e a porta da frente e a
## melhor coisa que a fachada tem.
##
## O que ele acrescenta a rua nao e uma entrada, e uma LEITURA: um comercio com
## vitrine acesa e, do lado, um portao de aco encardido com o rodape enferrujado
## conta que aquele lugar recebe caminhao de madrugada. A vitrine sozinha conta
## so a metade que a loja quer mostrar.
static func _portao_da_loja(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], centro: Vector3, giro: float,
		cx: int, cz: int) -> void:
	var lateral := Vector3(cos(giro), 0.0, -sin(giro))
	var normal := Vector3(sin(giro), 0.0, cos(giro))
	# Recuado em relacao a vitrine, e adiantado em relacao a parede.
	#
	# `centro` chega aqui NO PLANO DA PAREDE, e nao no da vitrine: quem projeta a
	# frente de loja sobre a calcada e o proprio KitMercado.fachada_loja, que soma
	# SALIENCIA por dentro. Somar meia saliencia aqui poe o portao a 17 cm da
	# parede — atras do vidro, que esta a 32, e ainda assim na frente do tijolo.
	#
	# Subtrair, que foi a primeira versao, enterrava o portao 13 cm DENTRO do
	# predio. Ele continuava existindo na malha, no lugar certo da calcada e com
	# a luz de sodio acesa em cima; so nao dava para ve-lo, porque a parede
	# estava na frente. Nenhum dos 46 numeros do criterio de aceite mexia — todos
	# mediam o eixo lateral, e o erro estava no outro.
	var base := (centro + lateral * KitMercado.AFASTAMENTO_PORTAO
		+ normal * KitMercado.SALIENCIA * 0.5)

	KitMercado.portao_garagem(sup, colisao, base, KitMercado.LARGURA_PORTAO,
		giro, true)

	# Pilar entre a vitrine e o portao. Sem ele os dois volumes se encostam e a
	# fachada le como uma coisa so de dez metros; com ele sao duas bocas do mesmo
	# predio, que e o que sao.
	var meio := (centro + lateral * (KitMercado.AFASTAMENTO_PORTAO * 0.5)
		+ normal * KitMercado.SALIENCIA * 0.5)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		meio + Vector3(0.0, 1.55, 0.0), Vector3(0.5, 3.1, 0.34),
		Color("8a8d86"), giro)

	# Numero de entrega pintado na parede, do lado do portao. E o detalhe que
	# diz que aquele vao tem uso, e custa duas caixas.
	KitModular.caixa_cor(sup, &"metal",
		base + lateral * (KitMercado.LARGURA_PORTAO * 0.5 + 0.42)
			+ normal * 0.06 + Vector3(0.0, 1.9, 0.0),
		Vector3(0.34, 0.24, 0.03), Color("d8d4c4"), giro)

	# Luminaria de servico sobre o portao. Sodio, e nao a branca fria da vitrine:
	# e a luz do lado de tras do comercio, e a diferenca de temperatura entre as
	# duas e o que separa a entrada da loja da entrada de carga na mesma calcada.
	props.append({
		"tipo": "lampada",
		"pos": base + normal * 0.5 + Vector3(0.0, 3.05, 0.0),
		"padrao": Lampada.Padrao.SODIO_FALHANDO,
		"semente": 62000 + cx * 211 + cz * 379,
		"cor": Color("ffc887"), "energia": 2.1, "alcance": 6.5, "facho": true,
	})
