## A casa da fumaca: casa de gente de vinte anos com a festa rolando.
##
## Mesmo contrato do CasaBuilder e do MercadoBuilder — dados puros, sem no
## nenhum, montado na thread. Desde o PLANO_CASA_FUMACA_V2 a casa EXISTE na rua
## (InteriorNoMundo): abre-se a porta da calcada e a sala esta ali, sem teleporte.
##
## Por que a casa cresceu de novo
## ------------------------------
## A v1 era UMA sala de 9,8 x 8,2 m, e a captura mostrou o que isso da: um
## retangulo bege com moveis encostados nas paredes, que le como salao de festa
## alugado. Casa e sequencia de comodos. O "vasto" que o jogador sente nao vem
## de metro quadrado, vem de ENXERGAR um comodo atras do outro: da porta da rua se
## ve a sala, o balcao da cozinha americana, a cozinha acesa de luz fria no fundo
## e a boca escura do corredor. Sao 11,6 x 15,5 m — o corpo da fileira mais
## metade do patio (`tests/lote_fumaca.gd` mede 20 m livres atras de toda casa
## da fumaca da cidade, e a face mais curta tem 20,2 m).
##
## Por que a luz e assim
## ---------------------
## Toda luz tem FONTE VISIVEL: a TV, a fita de LED atras dela, a luminaria de
## chao com a cupula acesa, o pisca-pisca na parede do som, os pendentes do
## balcao, a calha fluorescente da cozinha, a lampada nua do corredor, a luz
## negra do estudio. Cada comodo tem uma temperatura — sala quente e colorida,
## cozinha fria, estudio roxo — e e o contraste entre elas, visto de um comodo
## para o outro, que faz a casa ter profundidade. Nenhuma luz de preenchimento
## solta no ar.
##
## Planta, em metros, origem no canto de dentro da parede da rua (z = 0):
##
##   z=15.5 +---------------------------+[fundos]+---------------------+
##          | pia  fogao    galao  gelad|  corr  |  vaso     chuveiro   |
##          |                            |  edor  |    BANHEIRO         |
##          |      [mesa + cadeiras]     |        +------[porta]--------+ z=12.2
##          |          COZINHA           |  lamp. |  colchao            |
##          |                            |  nua   |   ESTUDIO (luz negra)|
##   z=7.4  +--  [vao largo]  [balcao]  -+[passa]-+--[mesa MPC]---------+
##          |  estante                 luminaria  |           caixa     |
##          |  CDs      (pista)          [sofa] [mesa] [rack+TV] <- LED |
##          |  som + LPs                [tapete]  pufe      caixa       |
##          |  cortina                        poltrona     ventilador   |
##   z=0    +----[PORTA]-----------------------------------------------+
##         x=0                                                     x=11.6
class_name CasaFumacaBuilder
extends RefCounted

const ALTURA := 2.7
const ALTURA_PORTA := 2.05
const RODAPE := 0.10

const LARGURA := 11.6
const FUNDO := 15.5

## Onde o jogador aparece no comodo teleportado (so sobra para quem chama
## `Interiores.entrar` direto, como as capturas).
const ENTRADA := Vector3(2.2, 0.0, 0.9)
const OLHAR := Vector3(8.0, 1.15, 3.7)

## Linhas das divisorias.
const Z_SALA := 7.4
const X_COZINHA := 6.8
const X_QUARTOS := 8.0
const Z_BANHEIRO := 12.2
const PAREDE_INTERNA := 0.12

## O centro da imagem da TV. O tubo esta na parede leste e olha para oeste.
const TV := Vector3(LARGURA - 0.68, 0.93, 3.7)
const GIRO_TV := -PI * 0.5
## Onde o PS2 fica de pe, em cima do rack.
const CONSOLE := Vector3(LARGURA - 0.50, 0.5475, 4.55)

## Vao da porta da rua, ao longo de x na parede z = 0. KitFumaca monta a
## fachada e a porta em volta dele.
const VAO_ENTRADA := Vector2(1.65, 2.75)
## Vao da porta dos fundos, ao longo de x na parede z = FUNDO, no fim do
## corredor. Da para o quintal — a estufa.
const VAO_FUNDOS := Vector2(X_COZINHA + 0.1, X_QUARTOS - 0.1)
## Onde a estufa devolve o jogador, e para onde ele olha.
const FUNDOS_VOLTA := Vector3((X_COZINHA + X_QUARTOS) * 0.5, 0.0, FUNDO - 1.2)
const FUNDOS_OLHAR := Vector3((X_COZINHA + X_QUARTOS) * 0.5, 1.5, FUNDO - 5.0)

## A janela da cozinha, na parede oeste (x = 0).
const JANELA_Z := 13.3
const JANELA_Y := 1.55
const JANELA := Vector2(1.02, 1.0)

## O atlas antigo so para o PS2, o controle e o cabo — as tres coisas que ele
## desenhava bem.
const MAT: StringName = &"casa"
const C_CABO := Vector2i(5, 1)
const C_PS2_FRENTE := Vector2i(4, 2)
const C_PS2_LADO := Vector2i(5, 2)
const C_PS2_TOPO := Vector2i(6, 2)
const C_CONTROLE := Vector2i(7, 2)

## Tons medios e quentes, e nao o branco de apartamento: sob o olho eletronico
## do MODERNO, parede clara nivela a sala inteira e a luz some nela.
const CORES_PAREDE: Array[Color] = [
	Color("b09c86"),
	Color("a4a48e"),
	Color("b8998a"),
]
const COR_TETO := Color(0.66, 0.64, 0.61)
## A parede da TV, pintada de petroleo: a fita de LED so aparece numa parede
## escura, e e a parede que a pessoa escolheu pintar.
const COR_DESTAQUE := Color(0.17, 0.27, 0.31)
## O estudio, roxo quase preto: a luz negra precisa de escuro para existir.
const COR_ESTUDIO := Color(0.20, 0.17, 0.25)


static func construir(semente: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente

	var sup: Dictionary = {}
	var props: Array[Dictionary] = []
	var colisao: Array[Dictionary] = []
	var cor: Color = CORES_PAREDE[rng.randi() % CORES_PAREDE.size()]

	_casca(sup, colisao, cor)
	_divisorias(sup, colisao, cor)
	_pinturas(sup)
	_sala(sup, colisao, props, rng)
	_canto_do_som(sup, colisao, props, rng)
	_cozinha(sup, colisao, props, rng)
	_corredor(sup, props, semente)
	_estudio(sup, colisao, props, rng)
	_banheiro(sup, colisao, props)
	_fumaca(sup, props)
	_assentos(props)
	_o_que_da_para_pegar(props)
	_gente(props, semente)

	var tris := 0
	for mat: StringName in sup:
		tris += PSXMesh.dados_triangulos(sup[mat])

	return {
		"superficies": sup, "props": props, "colisao": colisao,
		"triangulos": tris, "entrada": ENTRADA, "olhar": OLHAR,
		"ambiente": "res://resources/fog/fog_fumaca.tres",
		"usos": _usos(),
		# Onde o dono espera quando abre a porta: do lado oposto a folha, fora
		# do caminho de quem entra.
		"porta_dentro": Vector3(1.15, 0.0, 1.0),
		"saida": {
			"pos": Vector3(2.2, 1.0, 0.45),
			"tamanho": Vector3(1.3, 2.0, 0.9),
			"dobradica": Vector3(1.65, 0.0, 0.06),
			"giro": 0.0,
			"angulo": 92.0,
		},
	}


# --- casca e paredes ----------------------------------------------------------

static func _casca(sup: Dictionary, colisao: Array[Dictionary], cor: Color) -> void:
	# Piso: taco na sala, no corredor e no estudio; ceramica na cozinha e no
	# banheiro. A troca de piso na soleira e o que diz "outro comodo" antes da
	# parede dizer.
	var madeira := Color(0.92, 0.86, 0.80)
	var ceramica := Color(0.95, 0.93, 0.90)
	KitModular.chao(sup, &"piso", Vector3.ZERO, Vector2(LARGURA, Z_SALA), PSXMesh.MAX_QUAD_M, madeira)
	KitModular.chao(sup, &"piso_ceramico", Vector3(0.0, 0.0, Z_SALA),
		Vector2(X_COZINHA, FUNDO - Z_SALA), PSXMesh.MAX_QUAD_M, ceramica)
	KitModular.chao(sup, &"piso", Vector3(X_COZINHA, 0.0, Z_SALA),
		Vector2(LARGURA - X_COZINHA, Z_BANHEIRO - Z_SALA), PSXMesh.MAX_QUAD_M, madeira)
	KitModular.chao(sup, &"piso", Vector3(X_COZINHA, 0.0, Z_BANHEIRO),
		Vector2(X_QUARTOS - X_COZINHA, FUNDO - Z_BANHEIRO), PSXMesh.MAX_QUAD_M, madeira)
	KitModular.chao(sup, &"piso_ceramico", Vector3(X_QUARTOS, 0.0, Z_BANHEIRO),
		Vector2(LARGURA - X_QUARTOS, FUNDO - Z_BANHEIRO), PSXMesh.MAX_QUAD_M, Color(0.82, 0.86, 0.88))

	if not sup.has(&"teto"):
		sup[&"teto"] = PSXMesh.dados_vazios()
	PSXMesh.acumular_tingido(sup[&"teto"], PSXMesh.plane_dados(Vector2(LARGURA, FUNDO)),
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
			Vector3(LARGURA * 0.5, ALTURA, FUNDO * 0.5)), COR_TETO)

	var mat: StringName = &"reboco"
	KitModular.parede_com_vaos(sup, mat, Vector2(0.0, 0.0), Vector2(LARGURA, 0.0),
		ALTURA, [VAO_ENTRADA], ALTURA_PORTA, cor, RODAPE)
	KitModular.parede_com_vaos(sup, mat, Vector2(LARGURA, 0.0),
		Vector2(LARGURA, FUNDO), ALTURA, [], ALTURA_PORTA, cor, RODAPE)
	# A parede do fundo corre de x = LARGURA para x = 0, entao o vao e medido
	# a partir da ponta leste.
	KitModular.parede_com_vaos(sup, mat, Vector2(LARGURA, FUNDO), Vector2(0.0, FUNDO),
		ALTURA, [Vector2(LARGURA - VAO_FUNDOS.y, LARGURA - VAO_FUNDOS.x)],
		ALTURA_PORTA, cor, RODAPE)
	KitModular.parede_com_vaos(sup, mat, Vector2(0.0, FUNDO), Vector2(0.0, 0.0),
		ALTURA, [], ALTURA_PORTA, cor, RODAPE)

	# Colisao do piso e das quatro paredes, com os dois vaos abertos.
	colisao.append({"tamanho": Vector3(LARGURA, 0.4, FUNDO),
		"pos": Vector3(LARGURA * 0.5, -0.2, FUNDO * 0.5)})
	_parede_com_vao_colisao(colisao, 0.0, -0.15, VAO_ENTRADA)
	_parede_com_vao_colisao(colisao, 0.0, FUNDO + 0.15, VAO_FUNDOS)
	colisao.append({"tamanho": Vector3(0.3, ALTURA, FUNDO),
		"pos": Vector3(-0.15, ALTURA * 0.5, FUNDO * 0.5)})
	colisao.append({"tamanho": Vector3(0.3, ALTURA, FUNDO),
		"pos": Vector3(LARGURA + 0.15, ALTURA * 0.5, FUNDO * 0.5)})


## Tres caixas de colisao para uma parede em x com um vao de porta: os dois
## trechos cheios e a verga.
static func _parede_com_vao_colisao(colisao: Array[Dictionary], _x: float,
		z: float, vao: Vector2) -> void:
	var verga := ALTURA - ALTURA_PORTA
	colisao.append({"tamanho": Vector3(vao.x, ALTURA, 0.3),
		"pos": Vector3(vao.x * 0.5, ALTURA * 0.5, z)})
	colisao.append({"tamanho": Vector3(LARGURA - vao.y, ALTURA, 0.3),
		"pos": Vector3((vao.y + LARGURA) * 0.5, ALTURA * 0.5, z)})
	colisao.append({"tamanho": Vector3(vao.y - vao.x, verga, 0.3),
		"pos": Vector3((vao.x + vao.y) * 0.5, ALTURA_PORTA + verga * 0.5, z)})


## Divisoria de alvenaria entre dois pontos alinhados a um eixo, com vaos.
##
## Caixa cheia, e nao duas faces: o vao de porta de casa mostra a espessura da
## parede, e sem ela a porta le como recorte num papel. Cada vao ganha verga e
## batente de madeira. `vaos` e em metros a partir de `a`, com a altura do vao
## no terceiro valor (Vector3: inicio, fim, altura).
static func _divisoria(sup: Dictionary, colisao: Array[Dictionary], a: Vector2,
		b: Vector2, vaos: Array[Vector3], cor: Color) -> void:
	var em_x := absf(b.x - a.x) > absf(b.y - a.y)
	var comp := a.distance_to(b)
	var dir := (b - a) / comp
	var e := PAREDE_INTERNA
	var cursor := 0.0
	var trechos: Array[Vector2] = []
	for v: Vector3 in vaos:
		trechos.append(Vector2(cursor, v.x))
		cursor = v.y
	trechos.append(Vector2(cursor, comp))
	for t: Vector2 in trechos:
		if t.y - t.x < 0.01:
			continue
		_bloco(sup, colisao, a, dir, em_x, t, 0.0, ALTURA, e, cor)
	for v: Vector3 in vaos:
		_bloco(sup, colisao, a, dir, em_x, Vector2(v.x, v.y), v.z, ALTURA, e, cor)
		if v.z < ALTURA_PORTA + 0.3:
			_batente(sup, a, dir, em_x, v)


static func _bloco(sup: Dictionary, colisao: Array[Dictionary], a: Vector2,
		dir: Vector2, em_x: bool, t: Vector2, y0: float, y1: float, e: float,
		cor: Color) -> void:
	var meio := a + dir * ((t.x + t.y) * 0.5)
	var comp := t.y - t.x
	var tam := Vector3(comp, y1 - y0, e) if em_x else Vector3(e, y1 - y0, comp)
	var centro := Vector3(meio.x, (y0 + y1) * 0.5, meio.y)
	KitModular.caixa_cor(sup, &"reboco", centro, tam, cor)
	colisao.append({"tamanho": tam, "pos": centro})
	if y0 < 0.01:
		# Rodape dos dois lados.
		var rod := Vector3(comp, RODAPE, e + 0.024) if em_x else Vector3(e + 0.024, RODAPE, comp)
		KitModular.caixa_cor(sup, KitMovel.MDF, Vector3(meio.x, RODAPE * 0.5, meio.y),
			rod, Color(0.30, 0.24, 0.20))


static func _batente(sup: Dictionary, a: Vector2, dir: Vector2, em_x: bool,
		v: Vector3) -> void:
	var cor := Color(0.42, 0.33, 0.26)
	var fundo := PAREDE_INTERNA + 0.04
	for s: float in [v.x, v.y]:
		var p := a + dir * s
		var tam := Vector3(0.06, v.z, fundo) if em_x else Vector3(fundo, v.z, 0.06)
		KitModular.caixa_cor(sup, KitMovel.MDF, Vector3(p.x, v.z * 0.5, p.y), tam, cor)
	var m := a + dir * ((v.x + v.y) * 0.5)
	var larg := v.y - v.x + 0.12
	var tam_v := Vector3(larg, 0.06, fundo) if em_x else Vector3(fundo, 0.06, larg)
	KitModular.caixa_cor(sup, KitMovel.MDF, Vector3(m.x, v.z + 0.03, m.y), tam_v, cor)


## Demaos de tinta por cima do reboco: a parede da TV e as quatro do estudio.
## Uma placa a 4 mm da parede, e nao outra cor na divisoria, porque a divisoria
## e uma caixa so com a mesma cor nas duas faces.
static func _pinturas(sup: Dictionary) -> void:
	var d := 0.004
	var e := PAREDE_INTERNA * 0.5 + d
	_demao(sup, Vector3(LARGURA - d, ALTURA * 0.5, (Z_SALA - e) * 0.5),
		Vector3(0.004, ALTURA, Z_SALA - e), COR_DESTAQUE)
	var x0 := X_QUARTOS + e
	var z0 := Z_SALA + e
	var z1 := Z_BANHEIRO - e
	_demao(sup, Vector3(LARGURA - d, ALTURA * 0.5, (z0 + z1) * 0.5),
		Vector3(0.004, ALTURA, z1 - z0), COR_ESTUDIO)
	_demao(sup, Vector3((x0 + LARGURA) * 0.5, ALTURA * 0.5, z0),
		Vector3(LARGURA - x0, ALTURA, 0.004), COR_ESTUDIO)
	_demao(sup, Vector3((x0 + LARGURA) * 0.5, ALTURA * 0.5, z1),
		Vector3(LARGURA - x0, ALTURA, 0.004), COR_ESTUDIO)
	# A parede do corredor tem a porta: dois trechos e a verga.
	var porta := Vector2(Z_SALA + 0.5, Z_SALA + 1.46)
	_demao(sup, Vector3(x0, ALTURA * 0.5, (z0 + porta.x - 0.03) * 0.5),
		Vector3(0.004, ALTURA, porta.x - 0.03 - z0), COR_ESTUDIO)
	_demao(sup, Vector3(x0, ALTURA * 0.5, (porta.y + 0.03 + z1) * 0.5),
		Vector3(0.004, ALTURA, z1 - porta.y - 0.03), COR_ESTUDIO)
	var verga := ALTURA_PORTA + 0.11
	_demao(sup, Vector3(x0, (verga + ALTURA) * 0.5, (porta.x + porta.y) * 0.5),
		Vector3(0.004, ALTURA - verga, porta.y - porta.x), COR_ESTUDIO)


static func _demao(sup: Dictionary, centro: Vector3, tam: Vector3, cor: Color) -> void:
	KitModular.caixa_cor(sup, &"reboco", centro, tam, cor)


static func _divisorias(sup: Dictionary, colisao: Array[Dictionary], cor: Color) -> void:
	# Sala | fundos. O vao largo da cozinha (0,8 a 3,4) e o balcao (3,4 a 6,1)
	# ficam abertos ate a sanca de 2,30 m: da sala se ve a cozinha inteira.
	var sanca := 2.30
	_divisoria(sup, colisao, Vector2(0.0, Z_SALA), Vector2(X_COZINHA + 0.06, Z_SALA), [
		Vector3(0.8, 3.4, sanca), Vector3(3.4, 6.1, sanca)], cor)
	_divisoria(sup, colisao, Vector2(X_COZINHA + 0.06, Z_SALA), Vector2(LARGURA, Z_SALA), [
		Vector3(0.0, 1.08, ALTURA_PORTA + 0.05)], cor)
	# Cozinha | corredor.
	_divisoria(sup, colisao, Vector2(X_COZINHA, Z_SALA + 0.06), Vector2(X_COZINHA, FUNDO), [], cor)
	# Corredor | estudio e banheiro, com as duas portas.
	_divisoria(sup, colisao, Vector2(X_QUARTOS, Z_SALA + 0.06), Vector2(X_QUARTOS, FUNDO), [
		Vector3(0.5, 1.46, ALTURA_PORTA + 0.05), Vector3(5.55, 6.51, ALTURA_PORTA + 0.05)], cor)
	# Estudio | banheiro.
	_divisoria(sup, colisao, Vector2(X_QUARTOS + 0.06, Z_BANHEIRO), Vector2(LARGURA, Z_BANHEIRO), [], cor)


# --- sala -------------------------------------------------------------------

static func _sala(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	var leste := GIRO_TV
	# Rack, TV e as caixas.
	KitMovel.rack(sup, colisao, Vector3(LARGURA - 0.42, 0.0, TV.z), leste, 1.9)
	KitMovel.tv_tubo(sup, colisao, TV, leste)
	props.append({"tipo": "televisao", "pos": TV, "giro": leste, "ps2": true})
	KitMovel.caixa_torre(sup, colisao, Vector3(LARGURA - 0.30, 0.0, TV.z - 1.35), leste)
	KitMovel.caixa_torre(sup, colisao, Vector3(LARGURA - 0.30, 0.0, TV.z + 1.35), leste)

	# A fita de LED colada atras da TV. E a luz que mais diz quem mora aqui.
	# A fita fica ESCONDIDA atras do sino do tubo — o que se ve e o halo dela na
	# parede. Maior que a TV, ela virava uma moldura de neon flutuando.
	var x := LARGURA - 0.05
	props.append({
		"tipo": "festa", "pos": Vector3.ZERO, "modo": LuzDeFesta.Modo.FITA,
		"caminho": PackedVector3Array([
			Vector3(x, 0.78, TV.z - 0.2), Vector3(x, 1.12, TV.z - 0.2),
			Vector3(x, 1.12, TV.z + 0.2), Vector3(x, 0.78, TV.z + 0.2)]),
		"cor": Color(0.85, 0.2, 1.0), "energia": 2.2, "alcance": 2.3,
		"fora": Vector3.LEFT,
	})

	_console(sup, props, rng)

	# Sofa de frente para a TV, mesa de centro, tapete, pufe e poltrona.
	var sofa := Vector3(7.25, 0.0, TV.z)
	KitMovel.tapete(sup, Vector3(8.55, 0.0, TV.z), Vector2(3.1, 2.7), 0.0, Color(0.62, 0.20, 0.18))
	KitMovel.sofa(sup, colisao, sofa, PI * 0.5, Color(0.55, 0.36, 0.24), 2.2)
	KitMovel.manta(sup, sofa, PI * 0.5, 0.55, Color(0.95, 0.80, 0.15))
	KitMovel.mesa_centro(sup, colisao, Vector3(8.75, 0.0, TV.z), PI * 0.5)
	KitMovel.pufe(sup, Vector3(8.45, 0.0, 5.25), Color(0.20, 0.22, 0.24))
	var poltrona := Vector3(9.55, 0.0, 6.35)
	KitMovel.poltrona(sup, colisao, poltrona, atan2(8.4 - poltrona.x, TV.z - poltrona.z),
		Color(0.28, 0.42, 0.52))

	# O que esta em cima da mesa: cinzeiro, isqueiro, latinha, as caixinhas
	# abertas e o controle.
	var tampo := Vector3(8.75, 0.435, TV.z)
	_cinzeiro(sup, props, tampo + Vector3(0.1, 0.0, -0.3))
	KitMovel.cx(sup, KitMovel.PLASTICO, tampo, Basis(), Vector3(0.22, 0.06, 0.22),
		Vector3(0.065, 0.12, 0.065), Color(0.75, 0.1, 0.1))
	KitMovel.cx(sup, KitMovel.PLASTICO, tampo, Basis(), Vector3(0.18, 0.012, -0.05),
		Vector3(0.025, 0.024, 0.075), Color(0.2, 0.5, 0.9), Basis(Vector3.UP, 0.7))
	KitMovel.pilha_ps2(sup, tampo + Vector3(-0.12, 0.0, -0.05), 0.3, [0, 4], rng)
	KitMovel.pilha_ps2(sup, Vector3(9.05, 0.0, 5.75), 1.2, [CapasAtlas.PRIMEIRO_PIRATA,
		CapasAtlas.PRIMEIRO_PIRATA + 1, 7, 21], rng)

	# Luminaria de chao atras do braco do sofa.
	var lum := KitMovel.luminaria_chao(sup, Vector3(6.7, 0.0, TV.z + 1.45),
		Color(0.95, 0.86, 0.70))
	props.append(_lampada(lum, Color("ffb46b"), 1.5, 5.2, 7741, 1.7))

	# Ventilador de pe no canto, virado para o sofa.
	props.append({"tipo": "ventilador", "pos": Vector3(LARGURA - 0.6, 0.0, 6.7),
		"giro": atan2(7.5 - (LARGURA - 0.6), TV.z - 6.7), "oscila": true, "fase": 0.4})

	# A parede do fundo da sala, atras do sofa, com a galeria de capas. Quatro
	# quadros em alturas diferentes: colecao de alguem, e nao exposicao.
	var parede_z := Z_SALA - PAREDE_INTERNA * 0.5
	var galeria: Array[Array] = [
		[Vector3(8.75, 1.62, parede_z), 0.62, 0, 0.0],
		[Vector3(9.65, 1.78, parede_z), 0.46, 13, 0.03],
		[Vector3(9.60, 1.26, parede_z), 0.30, 5, -0.02],
		[Vector3(10.45, 1.58, parede_z), 0.52, 10, 0.0],
		[Vector3(11.10, 1.30, parede_z), 0.34, 3, 0.02],
	]
	for q: Array in galeria:
		KitMovel.quadro(sup, q[0], PI, q[1], q[2], q[3])

	# Parede da rua, por dentro: dois quadros e a janela de cortina fechada, com
	# a luz do poste vazando por cima.
	KitMovel.quadro(sup, Vector3(3.7, 1.58, 0.0), 0.0, 0.5, 1, 0.0)
	KitMovel.quadro(sup, Vector3(4.45, 1.70, 0.0), 0.0, 0.42, 14, -0.03)
	KitMovel.cortina(sup, Vector3(6.4, 1.45, 0.0), 0.0, 1.5, 1.55, Color(0.55, 0.16, 0.18))
	props.append(_lampada(Vector3(6.4, 2.3, 0.35), Color("ff9a48"), 0.35, 2.4, 7742))

	# Tapete da porta, tenis largados, skate encostado.
	KitMovel.tapete(sup, Vector3(2.2, 0.0, 0.45), Vector2(0.9, 0.5), 0.0, Color(0.25, 0.22, 0.2))
	for k in 3:
		var p := Vector3(0.45 + k * 0.32, 0.0, 0.35 + (k % 2) * 0.12)
		var g := rng.randf_range(-0.6, 0.6)
		var c := Color.from_hsv(rng.randf(), 0.25, rng.randf_range(0.3, 0.95))
		for s: float in [-0.06, 0.06]:
			KitMovel.cx(sup, KitMovel.PLASTICO, p, Basis(Vector3.UP, g),
				Vector3(s, 0.045, 0.0), Vector3(0.10, 0.09, 0.28), c)
	KitMovel.cx(sup, KitMovel.MDF, Vector3(3.2, 0.0, 0.08), Basis(),
		Vector3(0.0, 0.40, 0.0), Vector3(0.21, 0.80, 0.012), Color(0.15, 0.15, 0.15),
		Basis(Vector3.RIGHT, 0.2))


## O PS2 de pe no rack, as pilhas de caixinha, os dois controles e os cabos
## ate quem esta jogando.
static func _console(sup: Dictionary, props: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	var giro := GIRO_TV
	AtlasKit.caixa(sup, MAT, CONSOLE + Vector3(0.0, 0.011, 0.0),
		Vector3(0.115, 0.022, 0.165), C_PS2_TOPO, Color.WHITE, giro)
	var meio := CONSOLE + Vector3(0.0, 0.172, 0.0)
	AtlasKit.caixa(sup, MAT, meio, Vector3(0.078, 0.301, 0.182),
		C_PS2_LADO, Color.WHITE, giro + PI, C_PS2_FRENTE, C_PS2_TOPO)
	props.append(_lampada(meio + Vector3(-0.12, 0.10, 0.0), Color("5ab4ff"), 0.35, 0.8, 7735))

	# Pilhas no rack: jogo original de um lado, CD-R do camelo do outro.
	KitMovel.pilha_ps2(sup, Vector3(LARGURA - 0.45, 0.5475, TV.z - 0.72), giro,
		[2, 1, 0, 3, 9], rng)
	KitMovel.pilha_ps2(sup, Vector3(LARGURA - 0.38, 0.5475, CONSOLE.z + 0.2), giro,
		[CapasAtlas.PRIMEIRO_PIRATA + 2, CapasAtlas.PRIMEIRO_PIRATA + 3, 12], rng)
	# Duas de pe, encostadas na caixa de som, de capa para a sala.
	for k in 2:
		var b := Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, -0.12)
		KitMovel.caixinha_ps2(sup, Transform3D(b, Vector3(LARGURA - 0.66 - k * 0.02,
			0.095, TV.z + 1.05 + k * 0.16)), [8, 13][k])

	# O controle livre, na mesa de centro, com o fio ate o console: e o que o
	# jogador pega (ControlePS2). Os outros dois estao na mao de quem joga.
	var livre := Vector3(8.55, 0.435, TV.z + 0.25)
	_controle(sup, livre, 1.35)
	_cabo(sup, CONSOLE + Vector3(-0.05, 0.02, -0.05), Vector3(LARGURA - 0.72, 0.03, 4.3))
	_cabo(sup, Vector3(LARGURA - 0.72, 0.03, 4.3), Vector3(9.1, 0.03, 4.35))
	_cabo(sup, Vector3(9.1, 0.03, 4.35), livre + Vector3(0.06, 0.0, 0.0))
	_cabo(sup, CONSOLE + Vector3(-0.05, 0.02, 0.05), Vector3(LARGURA - 0.75, 0.03, 4.8))
	_cabo(sup, Vector3(LARGURA - 0.75, 0.03, 4.8), Vector3(8.35, 0.03, 5.6))
	_cabo(sup, CONSOLE + Vector3(-0.05, 0.02, -0.08), Vector3(LARGURA - 0.8, 0.03, 2.4))
	_cabo(sup, Vector3(LARGURA - 0.8, 0.03, 2.4), Vector3(9.35, 0.03, 2.3))
	props.append({
		"tipo": "controle_ps2",
		"pos": livre + Vector3(0.0, 0.05, 0.0),
		"onde": Vector3(7.95, 0.0, TV.z),
		"olhar": TV + Vector3(0.0, -0.02, 0.0),
		"olho": 0.92,
	})
	_cabo(sup, CONSOLE + Vector3(0.0, 0.06, -0.08), TV + Vector3(0.3, -0.25, 0.0))


static func _controle(sup: Dictionary, onde: Vector3, giro: float) -> void:
	AtlasKit.caixa(sup, MAT, onde + Vector3(0.0, 0.014, 0.0),
		Vector3(0.105, 0.028, 0.052), C_CONTROLE, Color.WHITE, giro)
	var b := Basis(Vector3.UP, giro)
	for lado: float in [-1.0, 1.0]:
		AtlasKit.caixa(sup, MAT, onde + b * Vector3(lado * 0.055, 0.013, 0.030),
			Vector3(0.034, 0.026, 0.070), C_CONTROLE, Color(0.88, 0.88, 0.9), giro)


static func _cabo(sup: Dictionary, de: Vector3, para: Vector3) -> void:
	AtlasKit.tubo(sup, MAT, de, para, 0.012, C_CABO, Color(0.25, 0.25, 0.27))


## Cinzeiro de vidro com bituca, e o fio de fumaca subindo dele.
static func _cinzeiro(sup: Dictionary, props: Array[Dictionary], onde: Vector3) -> void:
	KitMovel.cx(sup, KitMovel.PLASTICO, onde, Basis(), Vector3(0.0, 0.015, 0.0),
		Vector3(0.12, 0.03, 0.12), Color(0.35, 0.42, 0.40))
	for k in 3:
		KitMovel.cx(sup, KitMovel.PLASTICO, onde, Basis(Vector3.UP, k * 1.9),
			Vector3(0.02 * k - 0.02, 0.035, 0.01), Vector3(0.045, 0.012, 0.012),
			Color(0.95, 0.85, 0.65))
	props.append({"tipo": "fumaca", "pos": onde + Vector3(0.0, 0.05, 0.0),
		"fumaca": FumacaParticulas.Tipo.CINZEIRO})


static func _lampada(pos: Vector3, cor: Color, energia: float, alcance: float,
		semente: int, atenuacao: float = 1.1) -> Dictionary:
	return {
		"tipo": "lampada", "pos": pos, "padrao": Lampada.Padrao.ESTAVEL,
		"semente": semente, "cor": cor, "energia": energia, "alcance": alcance,
		"atenuacao": atenuacao,
	}


# --- o canto do som, na parede oeste ----------------------------------------

static func _canto_do_som(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	var oeste := PI * 0.5
	var som := Vector3(0.24, 0.0, 2.75)
	KitMovel.som(sup, colisao, som, oeste)
	KitMovel.caixa_torre(sup, colisao, Vector3(0.18, 0.0, 1.75), oeste)
	KitMovel.caixa_torre(sup, colisao, Vector3(0.18, 0.0, 3.75), oeste)
	KitMovel.estante_cds(sup, colisao, Vector3(0.12, 0.0, 4.75), oeste, rng)
	KitMovel.caixote_lp(sup, Vector3(0.55, 0.0, 1.05), oeste + 0.15, 11, rng)
	KitMovel.caixote_lp(sup, Vector3(0.98, 0.0, 1.10), oeste - 0.1, 6, rng)

	props.append({
		"tipo": "som_ambiente",
		"pos": som + Vector3(0.2, 0.9, 0.0),
		"som": &"funk_batida",
		"volume": -12.0,
		"alcance": 18.0,
		"pasta": "casa",
	})

	# Mesinha com abajur ao lado da estante.
	var mesinha := Vector3(0.28, 0.0, 5.75)
	KitMovel.cx(sup, KitMovel.MDF, mesinha, Basis(), Vector3(0.0, 0.25, 0.0),
		Vector3(0.40, 0.50, 0.40), KitMovel.MDF_ESCURO)
	colisao.append({"tamanho": Vector3(0.4, 0.5, 0.4), "pos": mesinha + Vector3(0.0, 0.25, 0.0)})
	var ab := KitMovel.abajur(sup, mesinha + Vector3(0.0, 0.5, 0.0), Color(0.92, 0.55, 0.30))
	props.append(_lampada(ab, Color("ffa860"), 0.9, 3.8, 7743, 1.8))

	# Capas coladas na parede acima do som, e o pisca-pisca correndo por cima de
	# tudo — pendurado em tres pregos, com barriga entre eles.
	var cartazes: Array[Array] = [
		[Vector3(0.0, 1.62, 2.2), 0.58, 16, 0.04],
		[Vector3(0.0, 1.70, 3.0), 0.50, 7, -0.03],
		[Vector3(0.0, 1.42, 3.62), 0.36, 23, 0.05],
		[Vector3(0.0, 1.66, 6.55), 0.70, 12, -0.02],
	]
	for c: Array in cartazes:
		KitMovel.cartaz(sup, c[0], oeste, c[1], c[2], c[3])
	var pisca := PackedVector3Array()
	for k in 13:
		var z := 0.5 + k * 0.53
		var barriga := sin(fposmod(float(k) / 4.0, 1.0) * PI) * 0.16
		pisca.append(Vector3(0.05, 2.42 - barriga, z))
	props.append({
		"tipo": "festa", "pos": Vector3.ZERO, "modo": LuzDeFesta.Modo.PISCA,
		"caminho": pisca, "cor": Color(1.0, 0.70, 0.36), "energia": 0.75, "alcance": 4.5,
		"fora": Vector3.RIGHT,
	})


# --- cozinha ----------------------------------------------------------------

static func _cozinha(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	var sul := PI
	var fundo := FUNDO - 0.31
	# Azulejo decorado na parede da pia, do tampo ate 1,62 m.
	KitModular.caixa_cor(sup, KitMovel.AZULEJO, Vector3(X_COZINHA * 0.5 - 0.03, 1.22, FUNDO - 0.006),
		Vector3(X_COZINHA - 0.06, 0.8, 0.012), Color.WHITE)

	KitMovel.pia_cozinha(sup, colisao, Vector3(1.95, 0.0, fundo), sul, 2.5)
	KitBar.fogao(sup, colisao, Vector3(3.62, 0.0, FUNDO - 0.34), sul)
	KitMovel.geladeira(sup, colisao, Vector3(X_COZINHA - 0.45, 0.0, FUNDO - 0.42), sul, rng)
	KitMovel.filtro_de_barro(sup, Vector3(2.85, 0.86, FUNDO - 0.34))
	KitMovel.galao(sup, Vector3(4.5, 0.0, FUNDO - 0.3))
	KitBar.lixeira(sup, colisao, Vector3(0.3, 0.0, 12.3), 0.0)

	# Mesa com toalha xadrez, cadeiras de plastico, a caixa de pizza e as
	# garrafas.
	var mesa := Vector3(2.7, 0.0, 11.0)
	KitMovel.mesa_cozinha(sup, colisao, mesa, 0.0, Color(0.72, 0.18, 0.16))
	KitBar.cadeira(sup, colisao, mesa + Vector3(0.0, 0.0, -0.72), 0.0, false)
	KitBar.cadeira(sup, colisao, mesa + Vector3(0.0, 0.0, 0.72), PI, false)
	KitBar.cadeira(sup, colisao, mesa + Vector3(-0.92, 0.0, 0.05), PI * 0.5, true)
	var tampo := mesa + Vector3(0.0, 0.762, 0.0)
	KitMovel.cx(sup, KitMovel.PLASTICO, tampo, Basis(Vector3.UP, 0.2), Vector3(-0.2, 0.025, 0.05),
		Vector3(0.40, 0.05, 0.40), Color(0.78, 0.62, 0.40))
	for k in 5:
		var p := Vector3(0.25 + rng.randf_range(-0.12, 0.3), 0.12, rng.randf_range(-0.28, 0.28))
		var verde := k % 2 == 0
		KitMovel.cx(sup, KitMovel.PLASTICO, tampo, Basis(), p, Vector3(0.07, 0.24, 0.07),
			Color(0.15, 0.35, 0.18) if verde else Color(0.35, 0.18, 0.08))
	_cinzeiro(sup, props, tampo + Vector3(-0.35, 0.0, -0.25))

	# Balcao da cozinha americana, com banquetas do lado da sala e os
	# pendentes em cima.
	var balcao := Vector3(4.75, 0.0, Z_SALA)
	KitMovel.balcao(sup, colisao, balcao, 0.0, 2.64)
	for x: float in [4.05, 5.35]:
		KitBar.banqueta(sup, colisao, Vector3(x, 0.0, Z_SALA - 0.42), 0.0)
		var luz := KitMovel.pendente(sup, Vector3(x, ALTURA, Z_SALA + 0.1), 0.72,
			Color(0.12, 0.12, 0.12))
		if x < 5.0:
			props.append(_lampada(luz + Vector3(0.65, 0.0, 0.0), Color("ffbf7a"), 1.2, 4.0, 7744, 1.6))
	var tampo_b := balcao + Vector3(0.0, 1.08, 0.12)
	_cinzeiro(sup, props, tampo_b + Vector3(0.7, 0.0, 0.0))
	for k in 3:
		KitMovel.cx(sup, KitMovel.PLASTICO, tampo_b, Basis(), Vector3(-0.8 + k * 0.17, 0.10, 0.02),
			Vector3(0.065, 0.20, 0.065), Color(0.12, 0.30, 0.15))

	# Calha fluorescente. A cozinha e o unico comodo de luz fria, e e ela que,
	# vista da sala por cima do balcao, poe profundidade na casa.
	var calha := KitMovel.calha(sup, Vector3(2.7, ALTURA, 11.0), 0.0)
	props.append(_lampada(calha, Color("dcefff"), 1.45, 6.2, 7745, 1.25))

	# A janela da parede oeste: basculante com o laranja do poste la fora.
	var meio := Vector3(0.02, JANELA_Y, JANELA_Z)
	KitModular.parede_livre(sup, &"janela_acesa", meio, JANELA, PI * 0.5,
		Color(0.62, 0.40, 0.22))
	for par: Array in [
			[Vector3(0.0, JANELA.y * 0.5 + 0.04, 0.0), Vector3(0.08, 0.07, JANELA.x + 0.14)],
			[Vector3(0.0, -JANELA.y * 0.5 - 0.05, 0.0), Vector3(0.14, 0.08, JANELA.x + 0.14)],
			[Vector3(0.0, 0.0, JANELA.x * 0.5 + 0.04), Vector3(0.08, JANELA.y, 0.07)],
			[Vector3(0.0, 0.0, -JANELA.x * 0.5 - 0.04), Vector3(0.08, JANELA.y, 0.07)],
			[Vector3(0.0, 0.0, 0.0), Vector3(0.06, 0.04, JANELA.x)]]:
		KitModular.caixa_cor(sup, KitMovel.METAL, meio + (par[0] as Vector3),
			par[1] as Vector3, Color(0.85, 0.85, 0.82))


# --- corredor e porta dos fundos -------------------------------------------

static func _corredor(sup: Dictionary, props: Array[Dictionary], semente: int) -> void:
	var meio_x := (X_COZINHA + X_QUARTOS) * 0.5
	var luz := KitMovel.bocal(sup, Vector3(meio_x, ALTURA, 11.2), 0.32, Color(1.0, 0.8, 0.5))
	props.append(_lampada(luz, Color("ffc27a"), 0.7, 3.6, 7746))
	# Capas no corredor, nas duas paredes.
	KitMovel.cartaz(sup, Vector3(X_COZINHA + PAREDE_INTERNA * 0.5, 1.6, 9.8),
		PI * 0.5, 0.5, 17, 0.03)
	KitMovel.cartaz(sup, Vector3(X_COZINHA + PAREDE_INTERNA * 0.5, 1.55, 12.4),
		PI * 0.5, 0.44, 25, -0.04)
	KitMovel.quadro(sup, Vector3(X_QUARTOS - PAREDE_INTERNA * 0.5, 1.62, 11.0),
		-PI * 0.5, 0.48, 9, 0.0)

	props.append({
		"tipo": "porta_interna",
		"pos": Vector3(meio_x, 1.05, FUNDO - 0.55),
		"tamanho": Vector3(1.1, 2.1, 1.4),
		"dobradica": Vector3(VAO_FUNDOS.x + 0.03, 0.0, FUNDO - 0.07),
		# A folha corre ao longo de +X a partir da dobradica e abre para DENTRO.
		"giro": 0.0,
		"angulo": 92.0,
		"rotulo": "Abrir a porta dos fundos",
		"destino": &"estufa",
		# Semente propria: a estufa e o mesmo lugar toda vez que se volta a
		# ESTA casa, e um lugar diferente na casa da fumaca da outra esquina.
		"semente": semente + 4242,
		"volta": FUNDOS_VOLTA,
		"volta_olhar": FUNDOS_OLHAR,
	})


# --- estudio ----------------------------------------------------------------

static func _estudio(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	var x0 := X_QUARTOS + PAREDE_INTERNA * 0.5
	var z0 := Z_SALA + PAREDE_INTERNA * 0.5
	var z1 := Z_BANHEIRO - PAREDE_INTERNA * 0.5
	props.append({
		"tipo": "porta_batente",
		"pos": Vector3(X_QUARTOS, 1.05, Z_SALA + 1.04),
		"tamanho": Vector3(1.3, 2.1, 1.0),
		"dobradica": Vector3(X_QUARTOS, 0.0, Z_SALA + 0.59),
		"giro": -PI * 0.5,
		"angulo": 92.0,
		"rotulo": "Abrir a porta do estudio",
	})

	var monitor := KitMovel.estudio(sup, colisao, Vector3(9.75, 0.0, z0 + 0.34), 0.0)
	props.append(_lampada(monitor + Vector3(0.0, 0.0, 0.25), Color("6f9bff"), 0.4, 2.0, 7747))
	KitBar.cadeira(sup, colisao, Vector3(9.6, 0.0, z0 + 1.0), PI, false)
	_cinzeiro(sup, props, Vector3(10.35, 0.755, z0 + 0.25))
	KitMovel.colchao(sup, Vector3(LARGURA - 0.5, 0.0, z1 - 1.0), 0.0, Color(0.20, 0.26, 0.50))
	KitMovel.espuma(sup, Vector3(LARGURA, 1.55, 9.2), -PI * 0.5, 4, 3, Color(0.18, 0.18, 0.2))
	KitMovel.cartaz(sup, Vector3(x0, 1.62, 10.6), PI * 0.5, 0.62, 17, 0.02)
	KitMovel.cartaz(sup, Vector3(x0, 1.50, 11.45), PI * 0.5, 0.40, 2, -0.05)
	KitMovel.pilha_ps2(sup, Vector3(LARGURA - 1.2, 0.0, z1 - 0.35), 0.4, [14, 15, 16], rng)

	# A luz negra: tubo roxo na parede do banheiro, de ponta a ponta.
	props.append({
		"tipo": "festa", "pos": Vector3.ZERO, "modo": LuzDeFesta.Modo.NEGRA,
		"caminho": PackedVector3Array([Vector3(x0 + 0.4, 2.45, z1 - 0.05),
			Vector3(LARGURA - 0.4, 2.45, z1 - 0.05)]),
		"cor": Color(0.50, 0.20, 1.0), "energia": 2.0, "alcance": 3.9,
		"fora": Vector3.FORWARD,
	})


# --- banheiro ---------------------------------------------------------------

static func _banheiro(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary]) -> void:
	var x0 := X_QUARTOS + PAREDE_INTERNA * 0.5
	var z0 := Z_BANHEIRO + PAREDE_INTERNA * 0.5
	props.append({
		"tipo": "porta_batente",
		"pos": Vector3(X_QUARTOS, 1.05, Z_SALA + 6.09),
		"tamanho": Vector3(1.3, 2.1, 1.0),
		"dobradica": Vector3(X_QUARTOS, 0.0, Z_SALA + 5.64),
		"giro": -PI * 0.5,
		"angulo": 92.0,
		"rotulo": "Abrir a porta do banheiro",
	})
	# Azulejo ate 1,6 m nas quatro paredes.
	var h := 1.6
	var azul := Color(0.92, 0.96, 1.0)
	var larg := LARGURA - x0
	var fundo := FUNDO - z0
	KitModular.caixa_cor(sup, KitMovel.AZULEJO, Vector3(LARGURA - 0.006, h * 0.5, z0 + fundo * 0.5),
		Vector3(0.012, h, fundo), azul)
	KitModular.caixa_cor(sup, KitMovel.AZULEJO, Vector3(x0 + larg * 0.5, h * 0.5, FUNDO - 0.006),
		Vector3(larg, h, 0.012), azul)
	KitModular.caixa_cor(sup, KitMovel.AZULEJO, Vector3(x0 + larg * 0.5, h * 0.5, z0 + 0.006),
		Vector3(larg, h, 0.012), azul)
	for trecho: Vector2 in [Vector2(z0, Z_SALA + 5.52), Vector2(Z_SALA + 6.54, FUNDO)]:
		KitModular.caixa_cor(sup, KitMovel.AZULEJO, Vector3(x0 + 0.006, h * 0.5, (trecho.x + trecho.y) * 0.5),
			Vector3(0.012, h, trecho.y - trecho.x), azul)

	KitMovel.vaso(sup, colisao, Vector3(LARGURA - 0.95, 0.0, FUNDO - 0.36), PI)
	KitMovel.pia_banheiro(sup, Vector3(LARGURA - 0.26, 0.0, z0 + 0.75), -PI * 0.5)
	KitMovel.chuveiro(sup, Vector3(x0, 0.0, FUNDO - 0.62), PI * 0.5, Color(0.25, 0.55, 0.70))
	var luz := KitMovel.calha(sup, Vector3(x0 + larg * 0.5, ALTURA, z0 + fundo * 0.5), PI * 0.5)
	props.append(_lampada(luz, Color("e6f2ff"), 0.85, 3.8, 7748))


# --- ar ----------------------------------------------------------------------

## Fumaca no ar parado de cada comodo (FogVolume, MODERNO) e a que escapa pelo
## vao dos fundos. Mais densa na sala, onde esta todo mundo; quase nada no
## banheiro.
static func _fumaca(_sup: Dictionary, props: Array[Dictionary]) -> void:
	props.append({"tipo": "fumaca_volume", "pos": Vector3(LARGURA * 0.5, 1.75, Z_SALA * 0.5),
		"tamanho": Vector3(LARGURA - 0.2, 1.9, Z_SALA - 0.2), "densidade": 0.045})
	props.append({"tipo": "fumaca_volume", "pos": Vector3(X_COZINHA * 0.5, 2.0, (Z_SALA + FUNDO) * 0.5),
		"tamanho": Vector3(X_COZINHA - 0.2, 1.4, FUNDO - Z_SALA - 0.2), "densidade": 0.025})
	props.append({"tipo": "fumaca_volume", "pos": Vector3((X_QUARTOS + LARGURA) * 0.5, 1.7, (Z_SALA + Z_BANHEIRO) * 0.5),
		"tamanho": Vector3(LARGURA - X_QUARTOS - 0.2, 1.8, Z_BANHEIRO - Z_SALA - 0.2), "densidade": 0.06})


# --- usos (CasaViva) ------------------------------------------------------------

## Os lugares com uso: onde um convidado para, e o que ele faz ali.
##
##   aprox    onde ele chega andando (sobre a malha de navegacao)
##   pos      onde o corpo fica — dentro do sofa, na banqueta; o convidado
##            escorrega de `aprox` para ca sem colisao
##   olhar    para onde ele vira
##   tipo     assento (sentado na `altura`), chao (pernas cruzadas), danca,
##            em_pe (fumando se fumar)
##
## O meio do sofa nao e uso: e o lugar de quem pega o controle do PS2.
static func _usos() -> Array[Dictionary]:
	var u: Array[Dictionary] = []
	var tv := TV
	var assento := func(pos: Vector3, aprox: Vector3, olhar: Vector3, altura: float,
			peso: float = 1.0) -> Dictionary:
		return {"tipo": &"assento", "pos": pos, "aprox": aprox, "olhar": olhar,
			"altura": altura, "duracao": Vector2(25.0, 60.0), "peso": peso}
	var em_pe := func(pos: Vector3, olhar: Vector3, duracao: Vector2, peso: float = 1.0,
			so_fumante: bool = false) -> Dictionary:
		return {"tipo": &"em_pe", "pos": pos, "aprox": pos, "olhar": olhar,
			"duracao": duracao, "peso": peso, "so_fumante": so_fumante}

	# Sofa: as duas pontas.
	for dz: float in [-0.607, 0.607]:
		u.append(assento.call(Vector3(7.18, 0.0, tv.z + dz), Vector3(8.02, 0.0, tv.z + dz),
			tv, 0.47, 1.3))
	# Banquetas do balcao, viradas para a cozinha.
	for x: float in [4.05, 5.35]:
		u.append(assento.call(Vector3(x, 0.0, Z_SALA - 0.42), Vector3(x, 0.0, Z_SALA - 1.0),
			Vector3(x, 1.1, Z_SALA + 0.8), 0.745))
	# Cadeiras da cozinha, em volta da mesa.
	var mesa := Vector3(2.7, 0.0, 11.0)
	u.append(assento.call(mesa + Vector3(0.0, 0.0, -0.76), mesa + Vector3(0.62, 0.0, -0.8),
		mesa + Vector3(0.0, 0.9, 0.0), 0.47))
	u.append(assento.call(mesa + Vector3(0.0, 0.0, 0.76), mesa + Vector3(0.62, 0.0, 0.8),
		mesa + Vector3(0.0, 0.9, 0.0), 0.47))
	u.append(assento.call(mesa + Vector3(-0.96, 0.0, 0.05), mesa + Vector3(-0.95, 0.0, 0.66),
		mesa + Vector3(0.0, 0.9, 0.0), 0.47))
	# Cadeira do estudio, de frente para o monitor.
	u.append(assento.call(Vector3(9.6, 0.0, Z_SALA + 1.1), Vector3(10.25, 0.0, Z_SALA + 1.2),
		Vector3(9.6, 0.98, Z_SALA + 0.3), 0.47, 0.8))
	# Colchao do estudio: sentado de pernas cruzadas.
	u.append({"tipo": &"chao", "pos": Vector3(11.1, 0.0, 10.9), "aprox": Vector3(10.3, 0.0, 10.9),
		"olhar": Vector3(9.5, 1.0, 9.0), "duracao": Vector2(30.0, 70.0), "peso": 0.6})
	# Pista de danca na frente do som.
	var som := Vector3(0.24, 1.0, 2.75)
	for p: Vector3 in [Vector3(1.35, 0.0, 2.25), Vector3(1.55, 0.0, 3.35), Vector3(2.35, 0.0, 2.8)]:
		u.append({"tipo": &"danca", "pos": p, "aprox": p, "olhar": som,
			"duracao": Vector2(15.0, 40.0), "peso": 1.4})
	# Fumar na janela da cozinha.
	u.append(em_pe.call(Vector3(0.5, 0.0, JANELA_Z), Vector3(0.0, 1.5, JANELA_Z),
		Vector2(15.0, 35.0), 1.0, true))
	# Geladeira: pega e vai embora.
	u.append(em_pe.call(Vector3(X_COZINHA - 0.45, 0.0, FUNDO - 1.25),
		Vector3(X_COZINHA - 0.45, 1.2, FUNDO), Vector2(3.0, 7.0), 0.8))
	# Encostado no balcao do lado da cozinha, olhando a sala.
	u.append(em_pe.call(Vector3(4.4, 0.0, Z_SALA + 0.6), Vector3(4.4, 1.2, 5.5),
		Vector2(15.0, 40.0)))
	# Fucando a estante de CD e os caixotes de LP.
	u.append(em_pe.call(Vector3(0.85, 0.0, 4.75), Vector3(0.1, 1.1, 4.75), Vector2(8.0, 20.0), 0.8))
	u.append(em_pe.call(Vector3(1.3, 0.0, 1.55), Vector3(0.7, 0.2, 1.1), Vector2(8.0, 18.0), 0.6))
	return u


# --- assentos, itens, gente ---------------------------------------------------

static func _assentos(props: Array[Dictionary]) -> void:
	props.append({
		"tipo": "assento",
		"pos": Vector3(7.25, 0.70, TV.z),
		"tamanho": Vector3(1.1, 1.1, 2.1),
		"onde": Vector3(7.9, 0.0, TV.z - 0.2),
		"olhar": TV,
		"olho": 0.86,
		"rotulo": "Sentar no sofa",
		"rotulo_levantar": "Levantar do sofa",
	})
	var poltrona := Vector3(9.55, 0.0, 6.35)
	var frente := (Vector3(8.4, 0.0, TV.z) - poltrona).normalized()
	props.append({
		"tipo": "assento",
		"pos": poltrona + Vector3(0.0, 0.70, 0.0),
		"tamanho": Vector3(1.1, 1.1, 1.1),
		"onde": poltrona + frente * 0.62,
		"olhar": Vector3(4.0, 1.15, 3.8),
		"olho": 0.90,
		"rotulo": "Sentar na poltrona",
		"rotulo_levantar": "Levantar da poltrona",
	})


static func _o_que_da_para_pegar(props: Array[Dictionary]) -> void:
	props.append({"tipo": "item", "item": &"remedio", "quantidade": 1, "indice": 0,
		"pos": Vector3(1.1, 0.88, FUNDO - 0.38)})
	props.append({"tipo": "item", "item": &"bandagem", "quantidade": 1, "indice": 1,
		"pos": Vector3(1.5, 0.88, FUNDO - 0.30)})
	props.append({"tipo": "item", "item": &"bateria", "quantidade": 1, "indice": 2,
		"pos": Vector3(8.6, 0.44, TV.z - 0.4)})


## Quem esta na casa.
##
## Os dois que jogam nao saem do lugar. Os outros circulam por PONTOS de uso —
## a pista na frente do som, o balcao, a mesa da cozinha —, e nao pelo meio da
## sala, e ninguem passa entre a TV e quem joga. O dono fica no fim do corredor,
## encostado ao lado da porta dos fundos: quem quer falar com ele atravessa a
## casa inteira, que e o unico jeito de a casa ser vista em vez de so cruzada.
static func _gente(props: Array[Dictionary], semente: int) -> void:
	var pontos: Array[Vector3] = [
		Vector3(2.0, 0.0, 2.4), Vector3(3.6, 0.0, 4.9), Vector3(5.1, 0.0, 2.6),
		Vector3(2.4, 0.0, 6.2), Vector3(4.7, 0.0, 6.6), Vector3(2.0, 0.0, 9.0),
		Vector3(4.6, 0.0, 9.6), Vector3(1.4, 0.0, 13.2), Vector3(5.0, 0.0, 13.0),
	]
	var pista := Vector3(3.2, 0.0, 3.8)

	# Os dois que jogam ficam dos lados, e nao entre o sofa e a TV: o meio do
	# sofa e o lugar de quem pega o terceiro controle.
	props.append(_pessoa(semente, 101, Vector3(8.3, 0.0, 5.6),
		Convidado.Papel.SENTADO, false, Vector3(TV.x, 0.0, TV.z), pontos, true))
	props.append(_pessoa(semente, 202, Vector3(9.35, 0.0, 2.2),
		Convidado.Papel.EM_PE, false, Vector3(TV.x, 0.0, TV.z), pontos, true))

	var lugares: Array[Vector3] = [
		Vector3(2.2, 0.0, 3.0), Vector3(4.2, 0.0, 2.2), Vector3(3.1, 0.0, 5.3),
		Vector3(4.7, 0.0, 6.55), Vector3(4.6, 0.0, 9.4), Vector3(1.7, 0.0, 9.3),
		Vector3(5.2, 0.0, 12.6), Vector3(5.6, 0.0, 4.3),
	]
	for k in lugares.size():
		props.append(_pessoa(semente, 303 + k * 97, lugares[k],
			Convidado.Papel.LIVRE, k != 2 and k != 5, pista, pontos))

	var dono := _pessoa(semente, 911, Vector3(X_COZINHA + 0.33, 0.0, FUNDO - 1.7),
		Convidado.Papel.ENCOSTADO, true, Vector3(7.4, 0.0, Z_SALA), [] as Array[Vector3])
	dono["dono"] = true
	dono["idade_min"] = 28
	dono["idade_max"] = 44
	props.append(dono)


static func _pessoa(semente: int, sal: int, onde: Vector3, papel: int,
		fuma: bool, foco: Vector3, pontos: Array[Vector3],
		controle: bool = false) -> Dictionary:
	return {
		"tipo": "convidado",
		"pos": onde,
		"semente": semente + sal,
		"papel": papel,
		"fuma": fuma,
		"controle": controle,
		"foco": foco,
		"pontos": pontos,
		"contexto": &"casa",
	}
