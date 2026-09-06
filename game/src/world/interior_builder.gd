## Monta um apartamento a partir de uma semente, no mesmo formato do chunk.
##
## Devolve dados puros, entao roda em thread igual ao ChunkBuilder. E isso que
## permite a promessa da Fase 4: o interior e construido enquanto a porta abre,
## e o jogador nunca ve tela de carregamento.
##
## A planta e pequena de proposito. O ART-BIBLE cita Mikami: espaco fechado
## oprime, e uma cadeira sozinha numa sala vazia assusta mais que um cenario
## cheio de detalhe. Tres comodos apertados valem mais que uma cobertura.
class_name InteriorBuilder
extends RefCounted

const ALTURA := 2.5
const ALTURA_PORTA := 2.05

## Planta fixa, em metros. Corredor estreito na entrada, sala, quarto.
const LARGURA := 8.0
const FUNDO := 7.0
const CORREDOR := 2.0
const DIVISAO_Z := 4.0

## Onde o jogador aparece ao entrar, e para onde olha.
const ENTRADA := Vector3(1.0, 0.0, 3.0)
const OLHAR := Vector3(1.0, 1.6, 0.5)

const RODAPE := 0.11

## Paleta de parede. Apartamento japones dos anos 90 nao tem parede branca de
## catalogo: tem creme encardido, rosa desbotado, verde agua. A cor entra por
## vertice, entao as tres saem da mesma textura de reboco.
const CORES_PAREDE: Array[Color] = [
	Color("c9a89a"),  # rosa desbotado, o da referencia
	Color("cfc3a4"),  # creme encardido
	Color("aab5a6"),  # verde agua
	Color("c2b9ae"),  # bege neutro
]


static func construir(semente: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente

	var sup: Dictionary = {}
	var props: Array[Dictionary] = []
	var colisao: Array[Dictionary] = []

	_pisos(sup, rng)
	_paredes(sup, rng)
	_colisao(colisao)
	_mobilia(sup, colisao, rng)
	_batentes(sup)
	_luzes(props, rng)

	var tris := 0
	for mat: StringName in sup:
		tris += PSXMesh.dados_triangulos(sup[mat])

	return {
		"superficies": sup, "props": props, "colisao": colisao,
		"triangulos": tris, "entrada": ENTRADA, "olhar": OLHAR,
	}


static func _pisos(sup: Dictionary, rng: RandomNumberGenerator) -> void:
	var piso: StringName = &"piso_madeira" if rng.randf() < 0.7 else &"piso_ceramico"
	KitModular.chao(sup, &"piso_ceramico", Vector3.ZERO, Vector2(CORREDOR, FUNDO))
	KitModular.chao(sup, piso, Vector3(CORREDOR, 0.0, 0.0),
		Vector2(LARGURA - CORREDOR, DIVISAO_Z))
	KitModular.chao(sup, piso, Vector3(CORREDOR, 0.0, DIVISAO_Z),
		Vector2(LARGURA - CORREDOR, FUNDO - DIVISAO_Z))

	# Teto inteiro numa peca so. Ninguem olha o teto, mas sem ele a sala vaza
	# para o vazio e o efeito de espaco fechado, que e o ponto, se perde.
	var teto := PSXMesh.plane_dados(Vector2(LARGURA, FUNDO))
	KitModular.por(sup, &"teto", teto,
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
			Vector3(LARGURA * 0.5, ALTURA, FUNDO * 0.5)))


static func _paredes(sup: Dictionary, rng: RandomNumberGenerator) -> void:
	var mat: StringName = &"reboco"
	var cor := CORES_PAREDE[rng.randi() % CORES_PAREDE.size()]

	# Perimetro no sentido horario, para as normais olharem para dentro.
	# A porta de saida fica no vao da parede oeste.
	KitModular.parede_com_vaos(sup, mat, Vector2(0.0, 0.0), Vector2(LARGURA, 0.0), ALTURA, [], ALTURA_PORTA, cor, RODAPE)
	KitModular.parede_com_vaos(sup, mat, Vector2(LARGURA, 0.0), Vector2(LARGURA, FUNDO), ALTURA, [], ALTURA_PORTA, cor, RODAPE)
	KitModular.parede_com_vaos(sup, mat, Vector2(LARGURA, FUNDO), Vector2(0.0, FUNDO), ALTURA, [], ALTURA_PORTA, cor, RODAPE)
	KitModular.parede_com_vaos(sup, mat, Vector2(0.0, FUNDO), Vector2(0.0, 0.0), ALTURA,
		[Vector2(FUNDO - 3.5, FUNDO - 2.4)], ALTURA_PORTA, cor, RODAPE)

	# Divisoria do corredor, com passagem para cada comodo.
	KitModular.parede_com_vaos(sup, mat, Vector2(CORREDOR, 0.0), Vector2(CORREDOR, FUNDO),
		ALTURA, [Vector2(0.9, 1.9), Vector2(4.8, 5.8)], ALTURA_PORTA, cor, RODAPE)
	KitModular.parede_com_vaos(sup, mat, Vector2(CORREDOR, FUNDO), Vector2(CORREDOR, 0.0),
		ALTURA, [Vector2(FUNDO - 1.9, FUNDO - 0.9), Vector2(FUNDO - 5.8, FUNDO - 4.8)],
		ALTURA_PORTA, cor, RODAPE)

	# Divisoria entre sala e quarto, dos dois lados.
	KitModular.parede_com_vaos(sup, mat, Vector2(CORREDOR, DIVISAO_Z),
		Vector2(LARGURA, DIVISAO_Z), ALTURA, [Vector2(1.2, 2.2)], ALTURA_PORTA, cor, RODAPE)
	KitModular.parede_com_vaos(sup, mat, Vector2(LARGURA, DIVISAO_Z),
		Vector2(CORREDOR, DIVISAO_Z), ALTURA,
		[Vector2(LARGURA - CORREDOR - 2.2, LARGURA - CORREDOR - 1.2)], ALTURA_PORTA, cor, RODAPE)

	# Janela da sala, virada para a rua. E a unica fonte de luz fria aqui, e o
	# que amarra o interior ao exterior sem precisar ver a rua.
	KitModular.parede_livre(sup, &"janela_acesa",
		Vector3(LARGURA * 0.5 + 1.0, 1.45, 0.06), Vector2(1.4, 1.1), 0.0)

	if rng.randf() < 0.5:
		KitModular.parede_livre(sup, &"janela_apagada",
			Vector3(LARGURA - 0.06, 1.45, FUNDO - 1.6), Vector2(1.2, 1.0), -PI * 0.5)


static func _colisao(colisao: Array[Dictionary]) -> void:
	colisao.append({"tamanho": Vector3(LARGURA, 0.3, FUNDO),
		"pos": Vector3(LARGURA * 0.5, -0.15, FUNDO * 0.5)})
	colisao.append({"tamanho": Vector3(LARGURA, 0.3, FUNDO),
		"pos": Vector3(LARGURA * 0.5, ALTURA + 0.15, FUNDO * 0.5)})

	# Perimetro solido. As passagens internas ficam livres: bater em batente
	# invisivel dentro de casa e pior que atravessar uma parede.
	var e := 0.25
	colisao.append({"tamanho": Vector3(LARGURA + e, ALTURA, e),
		"pos": Vector3(LARGURA * 0.5, ALTURA * 0.5, -e * 0.5)})
	colisao.append({"tamanho": Vector3(LARGURA + e, ALTURA, e),
		"pos": Vector3(LARGURA * 0.5, ALTURA * 0.5, FUNDO + e * 0.5)})
	colisao.append({"tamanho": Vector3(e, ALTURA, FUNDO + e),
		"pos": Vector3(-e * 0.5, ALTURA * 0.5, FUNDO * 0.5)})
	colisao.append({"tamanho": Vector3(e, ALTURA, FUNDO + e),
		"pos": Vector3(LARGURA + e * 0.5, ALTURA * 0.5, FUNDO * 0.5)})

	# Divisorias, com folga nas passagens.
	colisao.append({"tamanho": Vector3(0.2, ALTURA, 0.9),
		"pos": Vector3(CORREDOR, ALTURA * 0.5, 0.45)})
	colisao.append({"tamanho": Vector3(0.2, ALTURA, 2.9),
		"pos": Vector3(CORREDOR, ALTURA * 0.5, 3.35)})
	colisao.append({"tamanho": Vector3(0.2, ALTURA, 1.2),
		"pos": Vector3(CORREDOR, ALTURA * 0.5, 6.4)})
	colisao.append({"tamanho": Vector3(1.2, ALTURA, 0.2),
		"pos": Vector3(CORREDOR + 0.6, ALTURA * 0.5, DIVISAO_Z)})
	colisao.append({"tamanho": Vector3(3.8, ALTURA, 0.2),
		"pos": Vector3(LARGURA - 1.9, ALTURA * 0.5, DIVISAO_Z)})


static func _mobilia(sup: Dictionary, colisao: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	# Pouca coisa, e encostada na parede. Sala cheia distrai; sala quase vazia
	# faz o jogador reparar no unico objeto que existe.
	var mesa := Vector3(1.3, 0.72, 0.8)
	var pos_mesa := Vector3(LARGURA - 1.6, mesa.y * 0.5, 1.4)
	KitModular.caixa(sup, &"tabua", pos_mesa, mesa)
	colisao.append({"tamanho": mesa, "pos": pos_mesa})

	var cama := Vector3(1.0, 0.45, 2.0)
	var pos_cama := Vector3(LARGURA - 1.2, cama.y * 0.5, FUNDO - 1.6)
	KitModular.caixa(sup, &"porta", pos_cama, cama)
	colisao.append({"tamanho": cama, "pos": pos_cama})

	if rng.randf() < 0.6:
		var armario := Vector3(0.9, 1.8, 0.55)
		var pos_arm := Vector3(CORREDOR + 0.7, armario.y * 0.5, DIVISAO_Z - 0.5)
		KitModular.caixa(sup, &"tabua", pos_arm, armario)
		colisao.append({"tamanho": armario, "pos": pos_arm})

	# Quadro no corredor. E o unico objeto na parede do corredor, e e ele que faz
	# o corredor parecer a casa de alguem em vez de um tunel.
	KitModular.parede_livre(sup, &"tabua",
		Vector3(CORREDOR - 0.05, 1.55, 2.7), Vector2(0.62, 0.46), -PI * 0.5)
	KitModular.parede_livre(sup, &"terra",
		Vector3(CORREDOR - 0.07, 1.55, 2.7), Vector2(0.5, 0.34), -PI * 0.5)

	# Mesinha com vaso, encostada na parede do corredor.
	var mesinha := Vector3(0.5, 0.68, 0.4)
	var pos_mesinha := Vector3(0.35, mesinha.y * 0.5, 5.4)
	KitModular.caixa(sup, &"tabua", pos_mesinha, mesinha)
	colisao.append({"tamanho": mesinha, "pos": pos_mesinha})
	KitModular.caixa(sup, &"porta", pos_mesinha + Vector3(0.0, 0.34 + 0.11, 0.0),
		Vector3(0.2, 0.22, 0.2))
	KitModular.caixa(sup, &"terra", pos_mesinha + Vector3(0.0, 0.34 + 0.42, 0.0),
		Vector3(0.34, 0.38, 0.34))


## Batente escuro em volta de cada passagem. Vao sem batente le como buraco
## recortado na parede, nao como porta.
static func _batentes(sup: Dictionary) -> void:
	var vaos: Array[Array] = [
		# posicao do centro do vao, largura, giro da parede
		[Vector3(CORREDOR, 0.0, 1.4), 1.0, -PI * 0.5],
		[Vector3(CORREDOR, 0.0, 5.3), 1.0, -PI * 0.5],
		[Vector3(CORREDOR + 1.7, 0.0, DIVISAO_Z), 1.0, 0.0],
		[Vector3(0.0, 0.0, 3.0), 1.1, PI * 0.5],
	]
	for v: Array in vaos:
		var centro: Vector3 = v[0]
		var larg: float = v[1]
		var giro: float = v[2]
		var lateral := Vector3(cos(giro), 0.0, -sin(giro))
		for lado: float in [-1.0, 1.0]:
			KitModular.parede_livre(sup, &"tabua",
				centro + lateral * (lado * (larg * 0.5 + 0.05)) + Vector3(0.0, ALTURA_PORTA * 0.5, 0.0),
				Vector2(0.1, ALTURA_PORTA), giro, Color(0.5, 0.45, 0.4))
		KitModular.parede_livre(sup, &"tabua",
			centro + Vector3(0.0, ALTURA_PORTA + 0.05, 0.0),
			Vector2(larg + 0.2, 0.1), giro, Color(0.5, 0.45, 0.4))


static func _luzes(props: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	# Uma lampada por comodo, fraca. Interior de horror vive de canto escuro.
	props.append({
		"tipo": "lampada",
		"pos": Vector3(LARGURA * 0.6, ALTURA - 0.25, DIVISAO_Z * 0.5),
		"padrao": Lampada.Padrao.FLUORESCENTE if rng.randf() < 0.45 \
			else Lampada.Padrao.ESTAVEL,
		"semente": 31000 + rng.randi() % 9000,
		"cor": Color("ffe0b0"), "energia": 2.6, "alcance": 8.0, "facho": false,
	})
	props.append({
		"tipo": "lampada",
		"pos": Vector3(CORREDOR * 0.5, ALTURA - 0.2, FUNDO * 0.55),
		"padrao": Lampada.Padrao.MORTA if rng.randf() < 0.3 else Lampada.Padrao.ESTAVEL,
		"semente": 41000 + rng.randi() % 9000,
		"cor": Color("cfd8d0"), "energia": 1.6, "alcance": 6.0, "facho": false,
	})
