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
	if _iluminada(b["x0"]):
		x = MalhaUrbana.meia_pista(b["x0"]) + 0.8
	elif _iluminada(b["x1"]):
		x = TAM - MalhaUrbana.meia_pista(b["x1"]) - 0.8
	if _iluminada(b["z0"]):
		z = MalhaUrbana.meia_pista(b["z0"]) + 0.8
	elif _iluminada(b["z1"]):
		z = TAM - MalhaUrbana.meia_pista(b["z1"]) - 0.8
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
	elif bool(quadra["conveniencia"]) and posmod(cx * 17 + cz * 23, 4) == 0:
		planta = &"mercado"

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
	var px0 := MalhaUrbana.meia_pista(bordas["x0"])
	var px1 := MalhaUrbana.meia_pista(bordas["x1"])
	var pz0 := MalhaUrbana.meia_pista(bordas["z0"])
	var pz1 := MalhaUrbana.meia_pista(bordas["z1"])

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

	# A colisao tem que cobrir exatamente o que a calcada cobre. Antes ela pegava
	# a largura inteira do chunk, entao o jogador batia num degrau invisivel no
	# meio do asfalto e nao saia do lugar.
	colisao.append({
		"tamanho": Vector3(TAM, 0.4, TAM),
		"pos": Vector3(TAM * 0.5, -0.2, TAM * 0.5),
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
static func _arborizacao(sup: Dictionary, colisao: Array[Dictionary],
		cx: int, cz: int, bordas: Dictionary, lim: Rect2,
		rng: RandomNumberGenerator) -> void:
	const PASSO := 11.0
	const DA_GUIA := 1.05
	var y := KitModular.ALTURA_MEIO_FIO
	var poste := _poste_local(bordas)
	# A porta tem prioridade sobre a arvore. Uma copa de dois metros plantada na
	# frente de uma loja apaga o letreiro, e o letreiro visto de longe na nevoa e
	# a razao de a loja existir.
	var porta := _porta_do_chunk(cx, cz, MalhaUrbana.quadra_de(cx, cz))
	var canteiros: Array[Vector3] = []

	if bordas["x0"] == MalhaUrbana.Via.AVENIDA:
		var x := MalhaUrbana.meia_pista(bordas["x0"]) + DA_GUIA
		for i in int(TAM / PASSO):
			canteiros.append(Vector3(x, y, 4.0 + float(i) * PASSO))
	if bordas["x1"] == MalhaUrbana.Via.AVENIDA:
		var x := TAM - MalhaUrbana.meia_pista(bordas["x1"]) - DA_GUIA
		for i in int(TAM / PASSO):
			canteiros.append(Vector3(x, y, 9.0 + float(i) * PASSO))
	if bordas["z0"] == MalhaUrbana.Via.AVENIDA:
		var z := MalhaUrbana.meia_pista(bordas["z0"]) + DA_GUIA
		for i in int(TAM / PASSO):
			canteiros.append(Vector3(lim.position.x + 4.0 + float(i) * PASSO, y, z))
	if bordas["z1"] == MalhaUrbana.Via.AVENIDA:
		var z := TAM - MalhaUrbana.meia_pista(bordas["z1"]) - DA_GUIA
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
		# Semaforo precisa ser lido a noite: copa tapando a cabeca apaga a lente.
		if _perto_de_semaforo(cx, cz, base):
			continue
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


## A base cairia sob a copa do semaforo da quina deste chunk?
static func _perto_de_semaforo(cx: int, cz: int, base: Vector3) -> bool:
	if not Vias.existe_cruzamento(cx, cz):
		return false
	var meia_x := Vias.meia_x(cx)
	var meia_z := Vias.meia_z(cz)
	var calc_x := MalhaUrbana.largura_calcada(MalhaUrbana.via_x(cx))
	var calc_z := MalhaUrbana.largura_calcada(MalhaUrbana.via_z(cz))
	var sx := meia_x + minf(0.9, calc_x * 0.45)
	var sz := meia_z + minf(0.9, calc_z * 0.45)
	# Dois postes na mesma quina (ver _semaforos); raio cobre os dois.
	if Vector2(base.x - sx, base.z - (sz + 1.1)).length() < 4.2:
		return true
	if Vector2(base.x - (sx + 1.1), base.z - sz).length() < 4.2:
		return true
	return false


## Pintura do asfalto: eixo tracejado da avenida e faixa de pedestre no
## cruzamento.
##
## Custa quarenta triangulos e e o que faz a avenida parar de ser uma rua larga.
## Sem eixo pintado, largura sozinha nao comunica hierarquia nenhuma.
static func _pintura(sup: Dictionary, bordas: Dictionary, px0: float, pz0: float,
		lim: Rect2, cx: int, cz: int) -> void:
	# Eixo tracejado, junto a fronteira: a outra metade e do chunk vizinho.
	if bordas["x0"] == MalhaUrbana.Via.AVENIDA:
		for i in 5:
			var z := 1.6 + float(i) * 6.4
			KitModular.chao(sup, &"asfalto_faixa", Vector3(0.0, 0.012, z),
				Vector2(0.16, 3.2))
	if bordas["z0"] == MalhaUrbana.Via.AVENIDA:
		for i in 5:
			var x := 1.6 + float(i) * 6.4
			KitModular.chao(sup, &"asfalto_faixa", Vector3(x, 0.012, 0.0),
				Vector2(3.2, 0.16))

	# Faixa de pedestre atravessando a pista, logo depois da esquina.
	if bordas["x0"] != MalhaUrbana.Via.NENHUMA and lim.position.y > 0.0:
		for i in 5:
			var z := lim.position.y + 0.5 + float(i) * 0.42
			KitModular.chao(sup, &"asfalto_faixa", Vector3(0.0, 0.013, z),
				Vector2(px0, 0.26))
	if bordas["z0"] != MalhaUrbana.Via.NENHUMA and lim.position.x > 0.0:
		for i in 5:
			var x := lim.position.x + 0.5 + float(i) * 0.42
			KitModular.chao(sup, &"asfalto_faixa", Vector3(x, 0.013, 0.0),
				Vector2(0.26, pz0))

	# Linha de retencao nos acessos ao cruzamento sinalizado desta quina.
	# Cada chunk pinta so as aproximacoes que usam a MEIA pista dele: -Z na
	# faixa x0 e +X na faixa z0. A distancia casa com Vias.FOLGA_RETENCAO +
	# meia da transversal, a mesma conta que o carro usa para frear.
	if Vias.existe_cruzamento(cx, cz):
		var folga := Vias.FOLGA_RETENCAO
		if px0 > 0.05 and pz0 > 0.05:
			var z_lin := pz0 + folga
			KitModular.chao(sup, &"asfalto_faixa",
				Vector3(0.08, 0.014, z_lin - 0.14),
				Vector2(maxf(0.4, px0 - 0.16), 0.28))
			var x_lin := px0 + folga
			KitModular.chao(sup, &"asfalto_faixa",
				Vector3(x_lin - 0.14, 0.014, 0.08),
				Vector2(0.28, maxf(0.4, pz0 - 0.16)))


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
		maior = maxi(maior, _fileira(sup, colisao, rng, face, quadra, porta))
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
static func _fileira(sup: Dictionary, colisao: Array[Dictionary],
		rng: RandomNumberGenerator, face: Dictionary, quadra: Dictionary,
		porta: Dictionary = {}) -> int:
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

		var meio := cursor + larg * 0.5
		var centro := canto + eixo * meio - normal * (PROF_PREDIO * 0.5) 			+ Vector3(0.0, altura * 0.5, 0.0)
		var tamanho := Vector3(PROF_PREDIO, altura, larg) if ao_longo_de_z 			else Vector3(larg, altura, PROF_PREDIO)

		KitModular.caixa_cor(sup, &"concreto_sujo", centro, tamanho, tinta, 0.0, faces)
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
				float(quadra["janela"]), tinta, porta_local)
		else:
			tem_loja = KitModular.fachada(sup, frente + normal * 0.06, larg,
				andares, direcao, quadra["fachada"], rng, float(quadra["loja"]),
				float(quadra["janela"]), tinta, porta_local)

		if tem_loja and bool(quadra["toldo"]):
			KitPredio.toldo(sup, frente + normal * 0.1 + Vector3(0.0, 2.6, 0.0),
				larg * 0.72, direcao, int(quadra["semente"]) + i)

		if bool(quadra["sacada"]) and andares >= 2:
			for andar in range(1, andares):
				KitPredio.sacada(sup,
					frente + normal * 0.08 + Vector3(0.0, andar * KitModular.ALTURA_ANDAR, 0.0),
					larg * 0.55, direcao, tinta)

		KitPredio.coroar(sup, quadra["coroamento"],
			Vector3(centro.x, altura, centro.z),
			Vector3(tamanho.x, 0.0, tamanho.z), direcao, tinta, rng)

		cursor += larg
		restante -= larg

	return maior


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
					_fachada_de_loja(sup, props,
						Vector3(ponto["pos"]) - normal * KitMercado.SALIENCIA,
						float(ponto["giro"]), cx, cz)
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


## Os dois semaforos do cruzamento que este chunk possui.
##
## Cada chunk monta so o cruzamento da PROPRIA quina de origem, (cx, cz). Como
## todo cruzamento e a origem de exatamente um chunk, cada um e montado uma vez
## e nenhum e montado duas — sem precisar que os vizinhos estejam carregados.
##
## Sao dois postes e nao quatro. O poste do eixo 0 fica na quina de quem vem
## andando em +Z, e o do eixo 1 na quina de quem vem em +X; a cabeca tem lente
## dos dois lados, entao quem vem no sentido contrario le o mesmo sinal do outro
## lado da rua. Quatro postes seriam mais fieis e custariam o dobro de tudo.
static func _semaforos(sup: Dictionary, props: Array[Dictionary],
		cx: int, cz: int) -> void:
	if not Vias.existe_cruzamento(cx, cz):
		return
	var meia_x := Vias.meia_x(cx)
	var meia_z := Vias.meia_z(cz)
	var calcada_x := MalhaUrbana.largura_calcada(MalhaUrbana.via_x(cx))
	var calcada_z := MalhaUrbana.largura_calcada(MalhaUrbana.via_z(cz))
	# Encostado no meio-fio, do lado de dentro da calcada. Mais para fora entra
	# na faixa de rolamento; mais para dentro some atras da fachada.
	var recuo_x := meia_x + minf(0.9, calcada_x * 0.45)
	var recuo_z := meia_z + minf(0.9, calcada_z * 0.45)
	var y := KitModular.ALTURA_MEIO_FIO

	# Os dois postes ficam na MESMA quina, a do lado +X +Z, afastados um do outro
	# ao longo das suas ruas.
	#
	# Poderiam ficar em quinas opostas, que seria mais fiel. Nao ficam porque a
	# quina oposta tem coordenada local negativa — ou seja, esta na area do chunk
	# VIZINHO. O poste continuaria sendo desenhado por este chunk, e bastaria o
	# jogador atravessar a fronteira para o chunk dono descarregar e o semaforo
	# sumir debaixo do nariz dele, parado na esquina. Uma peca so pode ser
	# construida dentro do proprio chunk.
	#
	# A perda de fidelidade e nenhuma na pratica: a cabeca tem lente dos dois
	# lados, entao quem vem de qualquer sentido le a mesma cor.
	for item: Array in [[Vector3(recuo_x, y, recuo_z + 1.1), 0, 0.0],
			[Vector3(recuo_x + 1.1, y, recuo_z), 1, PI * 0.5]]:
		var onde: Vector3 = item[0]
		KitModular.semaforo(sup, onde, float(item[2]))
		props.append({
			"tipo": "semaforo",
			"pos": onde,
			"cruzamento": Vector2i(cx, cz),
			"eixo": int(item[1]),
			"giro": float(item[2]),
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

	# Inimigo. Raro, e nunca no chunk de origem: comecar cercado nao e tensao,
	# e emboscada.
	if absi(cx) + absi(cz) > 1 and posmod(cx * 37 + cz * 41, 9) == 0:
		props.append({
			"tipo": "inimigo",
			"pos": Vector3(TAM * 0.5, 0.2, TAM * 0.5),
			"semente": 55000 + cx * 233 + cz * 577,
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
	var base: Vector3 = Vector3(face["canto"]) 		+ eixo * rng.randf_range(4.0, maxf(4.5, float(face["comprimento"]) - 4.0)) 		+ normal * 0.5
	base.y = KitModular.ALTURA_MEIO_FIO

	KitModular.maquina_venda(sup, base, direcao)
	colisao.append({"tamanho": Vector3(1.2, 1.9, 0.9),
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
		base: Vector3, giro: float, cx: int, cz: int) -> void:
	# O prop da porta guarda a batente esquerda do vao; o centro da loja fica uma
	# largura de folha adiante, no eixo local X da porta.
	var lateral := Vector3(cos(giro), 0.0, -sin(giro))
	var vao := Porta.FOLHA_LARGURA * 2.0
	var centro := base + lateral * Porta.FOLHA_LARGURA

	KitMercado.fachada_loja(sup, centro, 6.4, giro, vao)

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
