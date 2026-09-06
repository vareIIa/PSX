## Monta o conteudo de um chunk a partir da coordenada, de forma deterministica.
##
## Nao instancia nada e nao toca no servidor de renderizacao: devolve dados de
## superficie fundidos por material, mais listas de props e de colisao para a
## thread principal materializar. Todo o custo pesado, que e gerar e fundir
## vertices, fica fora da thread principal.
##
## Malha da cidade
## ---------------
## Chunks de 32 m. As ruas correm nas fronteiras de coordenada par, o que da
## quarteiroes de 64 m divididos em quatro chunks. Cada chunk tem exatamente uma
## fronteira de rua em cada eixo, e o miolo dos quatro chunks encosta no centro do
## quarteirao sem vao.
##
## O layout sai da coordenada, sem tabela e sem arquivo, entao a cidade e infinita
## e sempre igual: o chunk 12,7 tem o mesmo predio hoje e na proxima execucao.
class_name ChunkBuilder
extends RefCounted

const TAM := KitModular.CHUNK
const MEIA_RUA := KitModular.MEIA_RUA
const CALCADA := KitModular.CALCADA
const RECUO := KitModular.RECUO
const MIOLO := TAM - RECUO          ## 26.5 m de quadra por chunk
## Profundidade de um predio. O resto do quarteirao e patio fechado.
const PROF_PREDIO := 8.0

## Carater de uma regiao. Sortear predio a predio deixa a cidade homogenea: tudo
## fica igualmente variado, que e o mesmo que nada ser especial. Regiao inteira
## com carater proprio faz a caminhada ter trechos que se reconhecem.
enum Distrito { COMERCIAL, RESIDENCIAL, INDUSTRIAL, BALDIO }

## Lado de um distrito, em chunks. Quatro chunks dao 128 m, que e mais ou menos
## quanto se anda antes de querer que a paisagem mude.
const DISTRITO_EM_CHUNKS := 4

const PERFIS := {
	Distrito.COMERCIAL: {
		"fachadas": [&"azulejo", &"tijolo", &"concreto"],
		"andares": [3, 5], "loja": 0.7, "janela": 0.34,
		"maquina": 3, "muro": false,
	},
	Distrito.RESIDENCIAL: {
		"fachadas": [&"reboco", &"concreto", &"azulejo"],
		"andares": [2, 3], "loja": 0.18, "janela": 0.42,
		"maquina": 6, "muro": false,
	},
	Distrito.INDUSTRIAL: {
		"fachadas": [&"metal_ondulado", &"metal_enferrujado", &"concreto_sujo"],
		"andares": [2, 4], "loja": 0.05, "janela": 0.1,
		"maquina": 8, "muro": false,
	},
	Distrito.BALDIO: {
		"fachadas": [&"concreto_sujo"],
		"andares": [1, 2], "loja": 0.0, "janela": 0.05,
		"maquina": 99, "muro": true,
	},
}


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

	# Lado onde fica a rua em cada eixo. Coordenada par poe a rua no minimo.
	var lado_x := -1 if posmod(cx, 2) == 0 else 1
	var lado_z := -1 if posmod(cz, 2) == 0 else 1
	var perfil: Dictionary = PERFIS[distrito_de(cx, cz)]

	_solo(sup, colisao, lado_x, lado_z, rng)
	var andares := _quadra(sup, colisao, lado_x, lado_z, rng, perfil)
	_props(sup, props, colisao, cx, cz, lado_x, lado_z, rng, andares, perfil)

	var tris := 0
	for mat: StringName in sup:
		tris += PSXMesh.dados_triangulos(sup[mat])

	return {
		"superficies": sup,
		"props": props,
		"colisao": colisao,
		"triangulos": tris,
	}


## Distrito a que um chunk pertence. Deterministico, como todo o resto.
static func distrito_de(cx: int, cz: int) -> Distrito:
	var rx := floori(float(cx) / float(DISTRITO_EM_CHUNKS))
	var rz := floori(float(cz) / float(DISTRITO_EM_CHUNKS))
	var h := absi(hash(Vector2i(rx, rz)) ^ (rx * 83492791) ^ (rz * 29996224))
	# Baldio e mais raro que o resto: terreno vazio e pontuacao, nao paisagem.
	var t := h % 10
	if t < 4:
		return Distrito.COMERCIAL
	if t < 7:
		return Distrito.RESIDENCIAL
	if t < 9:
		return Distrito.INDUSTRIAL
	return Distrito.BALDIO


## Posicao do poste de um chunk, em coordenada de mundo.
##
## Publica e deterministica de proposito: o chunk vizinho precisa dela para
## desenhar o cabo que atravessa a fronteira, sem que os dois estejam carregados
## ao mesmo tempo.
static func posicao_poste(cx: int, cz: int) -> Vector3:
	var lado_x := -1 if posmod(cx, 2) == 0 else 1
	var lado_z := -1 if posmod(cz, 2) == 0 else 1
	var lx := (RECUO - 0.7) if lado_x < 0 else (TAM - RECUO + 0.7)
	var lz := (RECUO - 0.7) if lado_z < 0 else (TAM - RECUO + 0.7)
	return Vector3(cx * TAM + lx, KitModular.ALTURA_MEIO_FIO, cz * TAM + lz)


# --- solo -------------------------------------------------------------------

static func _solo(sup: Dictionary, colisao: Array[Dictionary],
		lado_x: int, lado_z: int, rng: RandomNumberGenerator) -> void:
	var x_rua := 0.0 if lado_x < 0 else TAM - MEIA_RUA
	var z_rua := 0.0 if lado_z < 0 else TAM - MEIA_RUA

	# Faixa de rua no eixo X, inteira. A do eixo Z pula o canto ja coberto.
	KitModular.rua(sup, Vector3(x_rua, 0.0, 0.0), Vector2(MEIA_RUA, TAM))
	var x0_z := MEIA_RUA if lado_x < 0 else 0.0
	KitModular.rua(sup, Vector3(x0_z, 0.0, z_rua), Vector2(TAM - MEIA_RUA, MEIA_RUA),
		rng.randf() < 0.18)

	# Calcada do eixo X, cobrindo tambem a esquina.
	var x_cal := MEIA_RUA if lado_x < 0 else TAM - RECUO
	var z0_cal := MEIA_RUA if lado_z < 0 else 0.0
	KitModular.calcada(sup, Vector3(x_cal, 0.0, z0_cal), Vector2(CALCADA, TAM - MEIA_RUA),
		3 if lado_x < 0 else 1, TAM - MEIA_RUA)

	# Calcada do eixo Z, comecando depois da faixa anterior.
	var z_cal := MEIA_RUA if lado_z < 0 else TAM - RECUO
	var x0_cz := RECUO if lado_x < 0 else 0.0
	KitModular.calcada(sup, Vector3(x0_cz, 0.0, z_cal), Vector2(MIOLO, CALCADA),
		0 if lado_z < 0 else 2, MIOLO)

	# A colisao tem que cobrir exatamente o que a calcada cobre. Antes ela pegava
	# a largura inteira do chunk, entao o jogador batia num degrau invisivel no
	# meio do asfalto e nao saia do lugar.
	colisao.append({
		"tamanho": Vector3(TAM, 0.4, TAM),
		"pos": Vector3(TAM * 0.5, -0.2, TAM * 0.5),
	})

	var h := KitModular.ALTURA_MEIO_FIO
	var comp_x := TAM - MEIA_RUA
	colisao.append({
		"tamanho": Vector3(CALCADA, h, comp_x),
		"pos": Vector3(x_cal + CALCADA * 0.5, h * 0.5, z0_cal + comp_x * 0.5),
	})
	colisao.append({
		"tamanho": Vector3(MIOLO, h, CALCADA),
		"pos": Vector3(x0_cz + MIOLO * 0.5, h * 0.5, z_cal + CALCADA * 0.5),
	})

	# Rampa na borda voltada para a rua, senao o meio-fio de 16 cm barra o
	# jogador: CharacterBody3D nao sobe degrau sozinho.
	_rampa(colisao, Vector3(x_cal + (0.0 if lado_x < 0 else CALCADA),
		0.0, z0_cal + comp_x * 0.5), comp_x, true, lado_x < 0)
	_rampa(colisao, Vector3(x0_cz + MIOLO * 0.5, 0.0,
		z_cal + (0.0 if lado_z < 0 else CALCADA)), MIOLO, false, lado_z < 0)


## Rampa curta no meio-fio. `ao_longo_de_z` diz em que eixo o meio-fio corre.
static func _rampa(colisao: Array[Dictionary], pos: Vector3, comprimento: float,
		ao_longo_de_z: bool, sobe_para_mais: bool) -> void:
	var h := KitModular.ALTURA_MEIO_FIO
	var corrida := 0.34
	var ang := atan2(h, corrida)

	var tamanho := Vector3(corrida * 2.0, 0.3, comprimento) if ao_longo_de_z 		else Vector3(comprimento, 0.3, corrida * 2.0)
	var giro := Vector3(0.0, 0.0, ang if sobe_para_mais else -ang) if ao_longo_de_z 		else Vector3(-ang if sobe_para_mais else ang, 0.0, 0.0)

	colisao.append({
		"tamanho": tamanho,
		"pos": pos + Vector3(0.0, h - 0.15, 0.0),
		"giro": giro,
	})


# --- quadra -----------------------------------------------------------------

static func _quadra(sup: Dictionary, colisao: Array[Dictionary],
		lado_x: int, lado_z: int, rng: RandomNumberGenerator,
		perfil: Dictionary) -> int:
	var x0 := RECUO if lado_x < 0 else 0.0
	var z0 := RECUO if lado_z < 0 else 0.0

	# Anel de predios voltado para as duas ruas do chunk. O miolo do quarteirao
	# fica vazio de proposito: e um patio fechado que o jogador nunca alcanca, e
	# gerar geometria ali seria pagar por algo que ninguem ve.
	#
	# O anel do eixo X pega a profundidade toda em z; o do eixo Z comeca depois
	# dele, entao os dois nunca se sobrepoem na esquina.
	var dir_x := 3 if lado_x < 0 else 1
	var x_face := x0 if lado_x < 0 else (x0 + MIOLO)
	var dir_z := 0 if lado_z < 0 else 2
	var z_face := z0 if lado_z < 0 else (z0 + MIOLO)
	var inicio_x := (x0 + PROF_PREDIO) if lado_x < 0 else x0

	# Terreno baldio: chao de terra e muro baixo no lugar do quarteirao. E a
	# pausa visual que faz o resto da cidade parecer densa.
	if perfil["muro"]:
		KitModular.chao(sup, &"terra", Vector3(x0, 0.02, z0), Vector2(MIOLO, MIOLO))
		KitModular.muro(sup, Vector3(x_face, 0.0, z0), MIOLO, dir_x)
		KitModular.muro(sup, Vector3(inicio_x, 0.0, z_face), MIOLO - PROF_PREDIO, dir_z)
		colisao.append({
			"tamanho": Vector3(MIOLO, 1.8, MIOLO),
			"pos": Vector3(x0 + MIOLO * 0.5, 0.9, z0 + MIOLO * 0.5),
		})
		return 1

	var maior := _anel(sup, colisao, rng, dir_x,
		Vector3(x_face, 0.0, z0), MIOLO, true, perfil)
	maior = maxi(maior, _anel(sup, colisao, rng, dir_z,
		Vector3(inicio_x, 0.0, z_face), MIOLO - PROF_PREDIO, false, perfil))

	return maior


## Uma fileira de predios encostados, ao longo de uma face da quadra.
##
## `canto` e o inicio da fileira sobre a face; `ao_longo_de_z` diz em que eixo ela
## corre. Cada predio e um volume proprio com altura propria, e e isso que faz a
## rua ler como quarteirao em vez de um paredao de 26 m.
static func _anel(sup: Dictionary, colisao: Array[Dictionary],
		rng: RandomNumberGenerator, direcao: int,
		canto: Vector3, comprimento: float, ao_longo_de_z: bool,
		perfil: Dictionary) -> int:
	var normal := KitModular._normal(direcao)
	var n := rng.randi_range(2, 3)
	var restante := comprimento
	var cursor := 0.0
	var maior := 0

	# So as faces que alguem chega a ver. A externa some atras da fachada, a
	# interna da para o patio fechado e a base fica enterrada.
	var faces := (PSXMesh.FACE_FRENTE | PSXMesh.FACE_TRAS | PSXMesh.FACE_TOPO) \
		if ao_longo_de_z else (PSXMesh.FACE_DIR | PSXMesh.FACE_ESQ | PSXMesh.FACE_TOPO)

	for i in n:
		var larg := restante / float(n - i)
		if i < n - 1:
			larg = clampf(larg * rng.randf_range(0.7, 1.3), 6.0,
				restante - 6.0 * float(n - i - 1))
		larg = minf(larg, restante)
		if larg < 4.0:
			break

		var faixa: Array = perfil["andares"]
		var andares := rng.randi_range(int(faixa[0]), int(faixa[1]))
		var altura := andares * KitModular.ALTURA_ANDAR
		maior = maxi(maior, andares)

		var meio := cursor + larg * 0.5
		var eixo := Vector3(0.0, 0.0, meio) if ao_longo_de_z else Vector3(meio, 0.0, 0.0)
		# O volume cresce para dentro da quadra, na direcao oposta a fachada.
		var centro := canto + eixo - normal * (PROF_PREDIO * 0.5) \
			+ Vector3(0.0, altura * 0.5, 0.0)
		var tamanho := Vector3(PROF_PREDIO, altura, larg) if ao_longo_de_z \
			else Vector3(larg, altura, PROF_PREDIO)

		KitModular.caixa(sup, &"concreto_sujo", centro, tamanho, 0.0, faces)
		colisao.append({"tamanho": tamanho, "pos": centro})

		var paleta: Array = perfil["fachadas"]
		KitModular.fachada(sup, canto + eixo + normal * 0.06, larg, andares,
			direcao, paleta[rng.randi() % paleta.size()], rng,
			float(perfil["loja"]), float(perfil["janela"]))

		cursor += larg
		restante -= larg

	return maior


# --- props ------------------------------------------------------------------

static func _props(sup: Dictionary, props: Array[Dictionary], colisao: Array[Dictionary],
		cx: int, cz: int, lado_x: int, lado_z: int,
		rng: RandomNumberGenerator, _andares: int, perfil: Dictionary) -> void:
	var poste_mundo := posicao_poste(cx, cz)
	var local := poste_mundo - Vector3(cx * TAM, 0.0, cz * TAM)
	var dir_braco := Vector3(-lado_x, 0.0, 0.0)

	KitModular.poste(sup, local, dir_braco)

	# Um poste em cada tres esta morrendo. O defeito so assusta quando e excecao.
	props.append({
		"tipo": "lampada",
		"pos": local + dir_braco * 1.4 + Vector3(0.0, 6.35, 0.0),
		"padrao": Lampada.Padrao.SODIO_FALHANDO if posmod(cx * 3 + cz, 3) == 1 \
			else Lampada.Padrao.ESTAVEL,
		"semente": 4001 + cx * 137 + cz * 911,
	})

	# Fiacao para os dois vizinhos seguintes. Cada chunk desenha so os cabos que
	# saem dele, entao nenhum vao e desenhado duas vezes.
	var topo := local + Vector3(0.0, 6.9, 0.0)
	for passo: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		var vizinho := posicao_poste(cx + passo.x, cz + passo.y) \
			- Vector3(cx * TAM, 0.0, cz * TAM) + Vector3(0.0, 6.9, 0.0)
		KitModular.fiacao(sup, topo, vizinho)

	# Telefone publico. Raro e sempre no mesmo lugar para a coordenada dada, para
	# o jogador conseguir memorizar onde ficam.
	if posmod(cx * 53 + cz * 59, 11) == 0:
		var sx := (RECUO - 1.1) if lado_x < 0 else (TAM - RECUO + 1.1)
		props.append({
			"tipo": "save",
			"pos": Vector3(sx, KitModular.ALTURA_MEIO_FIO, TAM * 0.5),
			"giro": (PI * 0.5) if lado_x < 0 else (-PI * 0.5),
			"local": "Telefone da rua %d-%d" % [absi(cx), absi(cz)],
		})

	# Itens largados na calcada. A tabela de raridade e o que faz municao valer:
	# bandagem e comum, bala nao, e arma quase nunca.
	var n_itens := 1 if posmod(cx * 13 + cz * 17, 2) == 0 else 0
	if posmod(cx * 29 + cz * 31, 7) == 0:
		n_itens += 1
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
		var ix := (RECUO - 0.9) if lado_x < 0 else (TAM - RECUO + 0.9)
		props.append({
			"tipo": "item",
			"pos": Vector3(ix, KitModular.ALTURA_MEIO_FIO + 0.55,
				rng.randf_range(4.0, TAM - 4.0)),
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

	# Porta de entrada de predio. Uma a cada tres chunks: se toda fachada tivesse
	# porta o jogador pararia de reparar nelas, e entrar num apartamento deixaria
	# de ser um evento.
	if not bool(perfil["muro"]) and posmod(cx * 5 + cz * 11, 3) == 0:
		var px0 := RECUO if lado_x < 0 else 0.0
		var pz0 := RECUO if lado_z < 0 else 0.0
		var dir_p := 3 if lado_x < 0 else 1
		var normal_p := KitModular._normal(dir_p)
		var base_p := Vector3(
			(px0 - 0.02) if lado_x < 0 else (px0 + MIOLO + 0.02),
			KitModular.ALTURA_MEIO_FIO,
			pz0 + rng.randf_range(5.0, MIOLO - 5.0))
		props.append({
			"tipo": "porta",
			"pos": base_p,
			# A folha abre para fora, entao gira para encarar a rua.
			"giro": atan2(normal_p.x, normal_p.z),
			"semente": 77000 + cx * 419 + cz * 787,
		})

	# Maquina de venda encostada na fachada, em um chunk a cada quatro.
	var passo_maquina := int(perfil["maquina"])
	if passo_maquina < 50 and posmod(cx * 7 + cz * 5, passo_maquina) == 0:
		var x0 := RECUO if lado_x < 0 else 0.0
		var z0 := RECUO if lado_z < 0 else 0.0
		var dir := 3 if lado_x < 0 else 1
		var base := Vector3(
			(x0 - 0.5) if lado_x < 0 else (x0 + MIOLO + 0.5),
			KitModular.ALTURA_MEIO_FIO,
			z0 + rng.randf_range(4.0, MIOLO - 4.0))
		KitModular.maquina_venda(sup, base, dir)
		colisao.append({"tamanho": Vector3(1.2, 1.9, 0.9), "pos": base + Vector3(0.0, 0.95, 0.0)})
		props.append({
			"tipo": "lampada",
			"pos": base + KitModular._normal(dir) * 0.9 + Vector3(0.0, 1.1, 0.0),
			"padrao": Lampada.Padrao.FLUORESCENTE,
			"semente": 9001 + cx * 331 + cz * 617,
			"cor": Color("eaf2ff"),
			"energia": 2.2,
			"alcance": 5.5,
			"facho": false,
		})
