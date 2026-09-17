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
	var andares := _quadra(sup, props, colisao, cx, cz, bordas, quadra, limites, rng)
	_props(sup, props, colisao, cx, cz, bordas, quadra, limites, rng, andares)

	var tris := 0
	for mat: StringName in sup:
		tris += PSXMesh.dados_triangulos(sup[mat])

	return {
		"superficies": sup,
		"props": props,
		"colisao": colisao,
		"triangulos": tris,
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


static func posicao_poste(cx: int, cz: int) -> Vector3:
	return _poste_local(MalhaUrbana.bordas(cx, cz)) 		+ Vector3(cx * TAM, 0.0, cz * TAM)


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
			pos.y = KitModular.ALTURA_MEIO_FIO
			saida.append({
				"tipo": &"telefone",
				"pos": pos,
				# O aparelho fica de costas para a parede, olhando para a rua.
				"giro": atan2(normal.x, normal.z),
				"local": "Telefone da rua %d-%d" % [absi(cx), absi(cz)],
			})

	return saida


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
		if posmod(cx * 17 + cz * 23, 4) == 0:
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

	# A porta da loja acompanha a saliencia da fachada, senao a folha de vidro
	# abre trinta centimetros atras da vitrine.
	if planta == &"mercado":
		base += normal * KitMercado.SALIENCIA

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
		}
	return {}


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
	if px0 > 0.0:
		KitModular.rua(sup, Vector3.ZERO, Vector2(px0, TAM))
	if px1 > 0.0:
		KitModular.rua(sup, Vector3(TAM - px1, 0.0, 0.0), Vector2(px1, TAM))

	var larg_meio := TAM - px0 - px1
	if pz0 > 0.0 and larg_meio > 0.05:
		KitModular.rua(sup, Vector3(px0, 0.0, 0.0), Vector2(larg_meio, pz0),
			rng.randf() < 0.18)
	if pz1 > 0.0 and larg_meio > 0.05:
		KitModular.rua(sup, Vector3(px0, 0.0, TAM - pz1),
			Vector2(larg_meio, pz1), rng.randf() < 0.18)

	# Calcadas. As do eixo X vao de meio a meio em Z, deixando as pontas para a
	# pista transversal; as do eixo Z ficam so no vao entre elas.
	if lim.position.x > 0.0:
		_calcada(sup, colisao, Rect2(px0, pz0, lim.position.x - px0,
			TAM - pz1 - pz0), 3)
	if lim.end.x < TAM:
		_calcada(sup, colisao, Rect2(lim.end.x, pz0, TAM - px1 - lim.end.x,
			TAM - pz1 - pz0), 1)
	if lim.position.y > 0.0:
		_calcada(sup, colisao, Rect2(lim.position.x, pz0, lim.size.x,
			lim.position.y - pz0), 0)
	if lim.end.y < TAM:
		_calcada(sup, colisao, Rect2(lim.position.x, lim.end.y, lim.size.x,
			TAM - pz1 - lim.end.y), 2)

	_pintura(sup, bordas, px0, pz0, lim, cx, cz)
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
static func _calcada(sup: Dictionary, colisao: Array[Dictionary], r: Rect2,
		dir_meio_fio: int) -> void:
	if r.size.x < 0.05 or r.size.y < 0.05:
		return
	var h := KitModular.ALTURA_MEIO_FIO
	var comprimento := r.size.y if dir_meio_fio == 1 or dir_meio_fio == 3 else r.size.x
	KitModular.calcada(sup, Vector3(r.position.x, 0.0, r.position.y), r.size,
		dir_meio_fio, comprimento)
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
		# A esquina inteira e da travessia: zebra, semaforo e sinal de pedestre.
		# Copa em cima de qualquer um dos tres apaga o que existe para ser lido.
		if _na_esquina_do_cruzamento(cx, cz, base):
			continue
		saida.append(base)
	return saida


static func _arborizacao(sup: Dictionary, colisao: Array[Dictionary],
		cx: int, cz: int, _bordas: Dictionary, _lim: Rect2,
		rng: RandomNumberGenerator) -> void:
	for base: Vector3 in arvores(cx, cz):
		# Canteiro: um quadrado de terra em volta do tronco. Sem ele a arvore nasce
		# do concreto e o olho estranha antes de saber por que.
		#
		# Dois centimetros acima da calcada, e nao cinco milimetros: encostado, os
		# dois planos disputam o pixel a trinta metros e o canteiro pisca. E a
		# mesma conta de precisao de profundidade documentada em KitParque.
		KitModular.chao(sup, &"terra", base + Vector3(-0.6, 0.02, -0.6),
			Vector2(1.2, 1.2), 4.0, Color(0.55, 0.53, 0.48))
		KitParque.arvore(sup, colisao, base, rng.randf_range(0.05, 0.4), rng,
			rng.randf() < 0.12)


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
			var vx := vao_travessia(MalhaUrbana.meia_asfalto(MalhaUrbana.via_x(i)))
			var vz := vao_travessia(MalhaUrbana.meia_asfalto(MalhaUrbana.via_z(j)))
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
	var ax := MalhaUrbana.meia_asfalto(MalhaUrbana.via_x(cx))
	var az := MalhaUrbana.meia_asfalto(MalhaUrbana.via_z(cz))
	var meio := FAIXA_RECUO + FAIXA_PROFUNDIDADE * 0.5

	# N e S. Ficam depois do asfalto da via que corre em X e cruzam a via que
	# corre em Z: quem atravessa se move em X, ou seja, eixo de marcha 1.
	for sz: float in [1.0, -1.0]:
		saida.append({
			"centro": Vector3(0.0, 0.0, sz * (az + meio)),
			"eixo_marcha": 1,
			"meia_largura": ax,
			"meia_extensao": az,
		})
	# L e O. Cruzam a via que corre em X: quem atravessa se move em Z, eixo 0.
	for sx: float in [1.0, -1.0]:
		saida.append({
			"centro": Vector3(sx * (ax + meio), 0.0, 0.0),
			"eixo_marcha": 0,
			"meia_largura": az,
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
	var vx := MalhaUrbana.via_x(cx)
	var vz := MalhaUrbana.via_z(cz)
	var ox := _recuo_esquina(MalhaUrbana.meia_asfalto(vx), vx)
	var oz := _recuo_esquina(MalhaUrbana.meia_asfalto(vz), vz)
	var y := KitModular.ALTURA_MEIO_FIO

	for sx: float in [1.0, -1.0]:
		for sz: float in [1.0, -1.0]:
			var eixo := 1 if is_equal_approx(sx, sz) else 0
			var sentido: float = sx if eixo == 1 else sz
			var canto := Vector3(sx * ox, y, sz * oz)
			# Quem atravessa aqui se move no outro eixo, e sempre para longe da
			# propria esquina: quem espera em +Z atravessa para -Z.
			var marcha := 1 - eixo
			var ped_sentido: float = -sz if marcha == 0 else -sx
			saida.append({
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

	# Eixo tracejado, junto a fronteira: a outra metade e do chunk vizinho.
	if bordas["x0"] == MalhaUrbana.Via.AVENIDA:
		for i in 5:
			var z := 1.6 + float(i) * 6.4
			KitModular.chao(sup, &"marca_via", Vector3(0.0, 0.012, z),
				Vector2(0.16, 3.2), 6.0, tinta)
	if bordas["z0"] == MalhaUrbana.Via.AVENIDA:
		for i in 5:
			var x := 1.6 + float(i) * 6.4
			KitModular.chao(sup, &"marca_via", Vector3(x, 0.012, 0.0),
				Vector2(3.2, 0.16), 6.0, tinta)

	_pintura_estacionamento(sup, bordas, px0, pz0, cx, cz, tinta)

	# Faixa de pedestre: zebra nas quatro bocas do cruzamento, encostada na
	# caixa central. So o chunk dono da esquina (cx, cz) desenha, e desenha as
	# quatro — a mesma razao (e a mesma conta de distancia) do semaforo em
	# _semaforos. Ninguem mais pinta este cruzamento, entao nao ha barra
	# dobrada na costura.
	if Vias.existe_cruzamento(cx, cz):
		_faixa_pedestre(sup, cx, cz, tinta)

		# Linha de retencao nos dois acessos que usam a MEIA pista desta quina:
		# -Z na faixa x0 e +X na faixa z0. A distancia casa com
		# Vias.FOLGA_RETENCAO + meia da transversal, a conta que o carro usa
		# para frear.
		var folga := Vias.FOLGA_RETENCAO
		if px0 > 0.05 and pz0 > 0.05:
			var z_lin := pz0 + folga
			KitModular.chao(sup, &"marca_via",
				Vector3(0.08, 0.014, z_lin - 0.14),
				Vector2(maxf(0.4, px0 - 0.16), 0.28), 6.0, tinta)
			var x_lin := px0 + folga
			KitModular.chao(sup, &"marca_via",
				Vector3(x_lin - 0.14, 0.014, 0.08),
				Vector2(0.28, maxf(0.4, pz0 - 0.16)), 6.0, tinta)


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
		quadra: Dictionary, lim: Rect2, rng: RandomNumberGenerator) -> int:
	if lim.size.x < 2.0 or lim.size.y < 2.0:
		return 0

	match int(quadra["uso"]):
		MalhaUrbana.Uso.PARQUE:
			ParqueBuilder.construir(sup, props, colisao, quadra, cx, cz)
			return 0
		MalhaUrbana.Uso.BALDIO:
			return _baldio(sup, colisao, bordas, lim)

	# Chao do patio interno. Nunca e pisado, mas aparece pela fresta entre dois
	# predios e por cima do muro do terreno vizinho. `max_quad` folgado: e um
	# plano de 26 m que ninguem chega perto o suficiente para ver a UV afim.
	#
	# Escurecido a um terco. A textura de terra e clara, e patio de quarteirao
	# fechado nao recebe poste nenhum: no tom cheio, a fresta entre dois predios
	# virava uma faixa amarela acesa no meio da quadra.
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
		return _anexos(sup, colisao, quadra, lim, rng)

	var maior := 0
	for face: Dictionary in faces:
		maior = maxi(maior, _fileira(sup, props, colisao, rng, face, quadra, porta))
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

	if bordas["x0"] != MalhaUrbana.Via.NENHUMA:
		saida.append({"direcao": 3, "canto": Vector3(lim.position.x, 0.0, lim.position.y),
			"eixo": Vector3.BACK, "comprimento": lim.size.y})
		recorte_inicio = PROF_PREDIO
	elif bordas["x1"] != MalhaUrbana.Via.NENHUMA:
		saida.append({"direcao": 1, "canto": Vector3(lim.end.x, 0.0, lim.position.y),
			"eixo": Vector3.BACK, "comprimento": lim.size.y})
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
				"eixo": Vector3.RIGHT, "comprimento": comp_z})
		elif bordas["z1"] != MalhaUrbana.Via.NENHUMA:
			saida.append({"direcao": 0,
				"canto": Vector3(lim.position.x + recorte_inicio, 0.0, lim.end.y),
				"eixo": Vector3.RIGHT, "comprimento": comp_z})
	return saida


## Uma fileira de predios encostados, ao longo de uma face da quadra.
##
## Cada predio e um volume proprio com altura, cor e coroamento proprios, e e
## isso que faz a rua ler como quarteirao em vez de um paredao de 26 m. A cor e a
## do bloco: os predios de uma quadra sao parentes, e a diferenca aparece ao
## atravessar a rua e nao dentro da mesma calcada.
static func _fileira(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], rng: RandomNumberGenerator,
		face: Dictionary, quadra: Dictionary, porta: Dictionary = {}) -> int:
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
	var n := rng.randi_range(2, 3)
	var restante := comprimento
	var cursor := 0.0
	var maior := 0
	var base_andares := int(quadra["andares"])
	var tinta: Color = quadra["tinta"]

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
		maior = maxi(maior, _predio_do_bar(sup, props, colisao, rng, face,
			quadra, larg_bar))
		cursor = larg_bar
		restante -= larg_bar
		# A porta ja foi resolvida: nenhum trecho comum deve abrir vao por ela.
		porta_em = NAN
		n = maxi(1, n - 1)
		if restante < 6.0:
			return maior

	# So as faces que alguem chega a ver. A externa some atras da fachada, a
	# interna da para o patio fechado e a base fica enterrada.
	var faces := (PSXMesh.FACE_FRENTE | PSXMesh.FACE_TRAS | PSXMesh.FACE_TOPO) 		if ao_longo_de_z else (PSXMesh.FACE_DIR | PSXMesh.FACE_ESQ | PSXMesh.FACE_TOPO)

	for i in n:
		var larg := restante / float(n - i)
		if i < n - 1:
			larg = clampf(larg * rng.randf_range(0.7, 1.3), 6.0,
				restante - 6.0 * float(n - i - 1))
		larg = minf(larg, restante)
		if larg < 4.0:
			break

		# Um andar para cima ou para baixo em volta da altura da quadra. Mais que
		# isso e a quadra que perde a identidade; menos e um paredao.
		var andares := maxi(1, base_andares + rng.randi_range(-1, 1))
		var altura := andares * KitModular.ALTURA_ANDAR
		maior = maxi(maior, andares)
		# A tinta da quadra e o parentesco; 20% de outra tinta e o primo. Sem
		# isso a fileira e um paredao da mesma cor, mesmo com vaos diferentes.
		var tinta_local: Color = tinta.lerp(
			MalhaUrbana.TINTAS[rng.randi() % MalhaUrbana.TINTAS.size()], 0.22)

		var meio := cursor + larg * 0.5
		var centro := canto + eixo * meio - normal * (PROF_PREDIO * 0.5) 			+ Vector3(0.0, altura * 0.5, 0.0)
		var tamanho := Vector3(PROF_PREDIO, altura, larg) if ao_longo_de_z 			else Vector3(larg, altura, PROF_PREDIO)

		KitModular.caixa_cor(sup, &"concreto_sujo", centro, tamanho, tinta_local, 0.0, faces)
		colisao.append({"tamanho": tamanho, "pos": centro})

		var frente := canto + eixo * meio

		# A porta deste trecho, medida do centro dele. NAN quando a porta do
		# chunk esta em outro predio da mesma fileira.
		var porta_local := NAN
		if is_finite(porta_em) and porta_em >= cursor and porta_em < cursor + larg:
			porta_local = porta_em - meio

		# Quadra de casas ganha frente de casa. O terreo comercial nao e um
		# estilo alternativo: numa rua residencial ele produzia uma fileira de
		# portas de aco fechadas, e nenhuma delas era a porta de entrar.
		var tem_loja := false
		if bool(quadra["casa"]):
			tem_loja = KitFachada.residencia(sup, frente + normal * 0.06, larg,
				andares, direcao, quadra["fachada"], rng,
				float(quadra["janela"]), tinta_local, porta_local)
		else:
			var prob_loja := float(quadra["loja"])
			tem_loja = KitModular.fachada(sup, frente + normal * 0.06, larg,
				andares, direcao, quadra["fachada"], rng, prob_loja,
				float(quadra["janela"]), tinta_local, porta_local)

		if tem_loja and bool(quadra["toldo"]):
			KitPredio.toldo(sup, frente + normal * 0.1 + Vector3(0.0, 2.6, 0.0),
				larg * 0.72, direcao, int(quadra["semente"]) + i)

		if bool(quadra["sacada"]) and andares >= 2:
			for andar in range(1, andares):
				KitPredio.sacada(sup,
					frente + normal * 0.08 + Vector3(0.0, andar * KitModular.ALTURA_ANDAR, 0.0),
					larg * 0.55, direcao, tinta_local)

		KitPredio.coroar(sup, quadra["coroamento"],
			Vector3(centro.x, altura, centro.z),
			Vector3(tamanho.x, 0.0, tamanho.z), direcao, tinta_local, rng)

		cursor += larg
		restante -= larg

	return maior


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
static func _predio_do_bar(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], rng: RandomNumberGenerator,
		face: Dictionary, quadra: Dictionary, larg: float) -> int:
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

	var meio := larg * 0.5
	var frente: Vector3 = canto + eixo * meio
	var pe := KitBar.ALTURA_SALAO
	var alto := altura - pe

	var faces := (PSXMesh.FACE_FRENTE | PSXMesh.FACE_TRAS | PSXMesh.FACE_TOPO) \
		if ao_longo_de_z else (PSXMesh.FACE_DIR | PSXMesh.FACE_ESQ | PSXMesh.FACE_TOPO)
	var centro := frente - normal * (PROF_PREDIO * 0.5) \
		+ Vector3(0.0, pe + alto * 0.5, 0.0)
	var tamanho := Vector3(PROF_PREDIO, alto, larg) if ao_longo_de_z \
		else Vector3(larg, alto, PROF_PREDIO)
	KitModular.caixa_cor(sup, &"concreto_sujo", centro, tamanho, tinta_local,
		0.0, faces)
	colisao.append({"tamanho": tamanho, "pos": centro})

	# Fachada dos andares de cima. So dali para cima: no terreo a parede e a
	# ausencia dela.
	var plano := frente + normal * 0.06
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
	var semente := int(quadra["semente"]) + 8801
	KitBar.frente(sup, colisao, boca, giro, larg)
	KitBar.mesas_da_calcada(sup, colisao, boca, giro, larg)
	KitBar.salao(sup, colisao, props, boca, giro, larg, semente)

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
		_andares: int) -> void:
	_iluminacao(sup, props, cx, cz, bordas)

	for ponto: Dictionary in pontos_de_interesse(cx, cz):
		match ponto["tipo"]:
			&"porta":
				props.append({
					"tipo": "porta",
					"pos": ponto["pos"],
					"giro": ponto["giro"],
					"semente": ponto["semente"],
					"interior": ponto["interior"],
					"deslizante": ponto["deslizante"],
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
					KitFumaca.fachada(sup, colisao, Vector3(ponto["pos"]),
						float(ponto["giro"]), int(ponto["semente"]))
					KitFumaca.props(props, Vector3(ponto["pos"]),
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
		_maquina(sup, props, colisao, cx, cz, faces, quadra, rng)
	_semaforos(sup, props, cx, cz)


## Poste, lampada e fiacao. A fiacao so sai para vizinhos que tambem tem poste,
## senao o cabo termina no ar no meio da viela.
static func _iluminacao(sup: Dictionary, props: Array[Dictionary],
		cx: int, cz: int, _bordas: Dictionary) -> void:
	if not tem_poste(cx, cz):
		return
	var poste_mundo := posicao_poste(cx, cz)
	var local := poste_mundo - Vector3(cx * TAM, 0.0, cz * TAM)
	var dir_braco := Vector3(1.0, 0.0, 0.0) if local.x < TAM * 0.5 else Vector3(-1.0, 0.0, 0.0)

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
		var vizinho := posicao_poste(cx + passo.x, cz + passo.y) 			- Vector3(cx * TAM, 0.0, cz * TAM) + Vector3(0.0, 6.9, 0.0)
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
	for sinal: Dictionary in sinais_do_cruzamento(cx, cz):
		KitModular.semaforo(sup, sinal["pos"], sinal["giro"])
		props.append({
			"tipo": "semaforo",
			"pos": sinal["pos"],
			"cruzamento": Vector2i(cx, cz),
			"eixo": sinal["eixo"],
			"giro": sinal["giro"],
			"halo": sinal["halo"],
		})
		KitModular.sinal_pedestre(sup, sinal["ped_pos"], sinal["ped_giro"])
		props.append({
			"tipo": "sinal_pedestre",
			"pos": sinal["ped_pos"],
			"cruzamento": Vector2i(cx, cz),
			"eixo_conflito": sinal["ped_eixo_conflito"],
			"giro": sinal["ped_giro"],
		})


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
		pos.y = KitModular.ALTURA_MEIO_FIO + 0.55
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
	pos.y = 0.0
	props.append({
		"tipo": "inimigo",
		"pos": pos,
		"semente": rng.randi(),
	})


## Maquina de venda encostada na fachada.
static func _maquina(sup: Dictionary, props: Array[Dictionary],
		colisao: Array[Dictionary], cx: int, cz: int,
		faces: Array[Dictionary], quadra: Dictionary,
		rng: RandomNumberGenerator) -> void:
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
	base.y = KitModular.ALTURA_MEIO_FIO

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
