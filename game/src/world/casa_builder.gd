## Planta de casa terrea, para as portas que dao em residencia em vez de predio.
##
## Mesmo contrato do InteriorBuilder e do ChunkBuilder: devolve dados puros, sem
## no nenhum, entao roda na thread enquanto a porta abre.
##
## A diferenca de intencao em relacao ao apartamento e proposital. O apartamento
## e apertado e quase vazio, para oprimir. A casa e o oposto: e o unico lugar do
## jogo onde alguem ainda mora, tem luz quente, movel usado e uma pessoa dentro.
## O contraste e que faz a rua la fora parecer pior quando o jogador sai.
##
## Planta, em metros, origem no canto sul-oeste:
##
##   z=8.4 +-------------------+-----------+
##         |     COZINHA       |  (selado) |
##   z=6.0 +--------[vao]------+           |
##         |                   |           |
##         |       SALA        |  z=5.4 [porta trancada]
##         |                   +-----------+
##         |                   |           |
##         |                   |  CORREDOR |
##   z=0   +----[entrada]------+-----------+
##        x=0                x=6.6       x=9.0
class_name CasaBuilder
extends RefCounted

const ALTURA := 2.45
const ALTURA_PORTA := 2.05
const RODAPE := 0.11

const LARGURA := 9.0
const FUNDO := 8.4

## Divisorias.
const DIV_X := 6.6      ## sala | corredor
const DIV_Z := 6.0      ## sala | cozinha
const FUNDO_CORREDOR := 5.4  ## onde fica a porta trancada

## Onde o jogador aparece ao entrar, e para onde olha. Chega de costas para a
## porta, olhando a sala inteira: e o primeiro quadro do comodo e vale mais que
## qualquer movel isolado.
const ENTRADA := Vector3(1.85, 0.0, 0.8)
const OLHAR := Vector3(3.2, 1.55, 5.2)

## Paredes de casa, mais quentes que as do apartamento.
const CORES_PAREDE: Array[Color] = [
	Color("cdbfa2"),  # creme
	Color("c3b9a6"),  # bege esverdeado
	Color("d0c0ac"),  # areia
]


static func construir(semente: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente

	var sup: Dictionary = {}
	var props: Array[Dictionary] = []
	var colisao: Array[Dictionary] = []

	var cor := CORES_PAREDE[rng.randi() % CORES_PAREDE.size()]

	_pisos(sup)
	_paredes(sup, cor)
	_colisao(colisao)
	_sala(sup, colisao, props, rng)
	_cozinha(sup, colisao, rng)
	_corredor(sup, colisao, props)
	_luzes(sup, props, rng)
	_morador(props, semente)

	var tris := 0
	for mat: StringName in sup:
		tris += PSXMesh.dados_triangulos(sup[mat])

	return {
		"superficies": sup, "props": props, "colisao": colisao,
		"triangulos": tris, "entrada": ENTRADA, "olhar": OLHAR,
		# Dobradica no lado oeste do vao da entrada; a folha abre para a rua,
		# como porta de casa japonesa.
		"saida": {
			"pos": Vector3(1.85, 1.0, 0.45),
			"tamanho": Vector3(1.3, 2.0, 0.9),
			"dobradica": Vector3(1.3, 0.0, 0.06),
			"giro": 0.0,
			"angulo": 96.0,
		},
	}


# --- casca ------------------------------------------------------------------

static func _pisos(sup: Dictionary) -> void:
	# Madeira na area social, ceramica na entrada e na cozinha. A troca de piso
	# marca o comodo sem precisar de parede, que e como casa de verdade resolve.
	KitModular.chao(sup, &"piso", Vector3(0.0, 0.0, 1.4), Vector2(DIV_X, DIV_Z - 1.4))
	KitModular.chao(sup, &"piso_ceramico", Vector3.ZERO, Vector2(3.2, 1.4))
	KitModular.chao(sup, &"piso", Vector3(3.2, 0.0, 0.0), Vector2(DIV_X - 3.2, 1.4))
	KitModular.chao(sup, &"piso_ceramico", Vector3(0.0, 0.0, DIV_Z),
		Vector2(DIV_X, FUNDO - DIV_Z))
	KitModular.chao(sup, &"piso", Vector3(DIV_X, 0.0, 0.0),
		Vector2(LARGURA - DIV_X, FUNDO_CORREDOR))
	KitModular.chao(sup, &"piso", Vector3(DIV_X, 0.0, FUNDO_CORREDOR),
		Vector2(LARGURA - DIV_X, FUNDO - FUNDO_CORREDOR))

	var teto := PSXMesh.plane_dados(Vector2(LARGURA, FUNDO))
	KitModular.por(sup, &"teto", teto,
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
			Vector3(LARGURA * 0.5, ALTURA, FUNDO * 0.5)))


static func _paredes(sup: Dictionary, cor: Color) -> void:
	var mat: StringName = &"reboco"

	# Perimetro no sentido anti horario visto de cima, para as normais olharem
	# para dentro. O vao da parede sul e a porta de entrada.
	KitModular.parede_com_vaos(sup, mat, Vector2(0.0, 0.0), Vector2(LARGURA, 0.0),
		ALTURA, [Vector2(1.3, 2.4)], ALTURA_PORTA, cor, RODAPE)
	KitModular.parede_com_vaos(sup, mat, Vector2(LARGURA, 0.0), Vector2(LARGURA, FUNDO),
		ALTURA, [], ALTURA_PORTA, cor, RODAPE)
	KitModular.parede_com_vaos(sup, mat, Vector2(LARGURA, FUNDO), Vector2(0.0, FUNDO),
		ALTURA, [], ALTURA_PORTA, cor, RODAPE)
	KitModular.parede_com_vaos(sup, mat, Vector2(0.0, FUNDO), Vector2(0.0, 0.0),
		ALTURA, [], ALTURA_PORTA, cor, RODAPE)

	# Divisoria sala | corredor, com a passagem. Os dois lados, senao o corredor
	# ve o verso da parede e a face some por cull_back.
	var vao_corredor: Array = [Vector2(2.0, 3.1)]
	KitModular.parede_com_vaos(sup, mat, Vector2(DIV_X, 0.0), Vector2(DIV_X, FUNDO),
		ALTURA, vao_corredor, ALTURA_PORTA, cor, RODAPE)
	KitModular.parede_com_vaos(sup, mat, Vector2(DIV_X, FUNDO), Vector2(DIV_X, 0.0),
		ALTURA, [Vector2(FUNDO - 3.1, FUNDO - 2.0)], ALTURA_PORTA, cor, RODAPE)

	# Divisoria sala | cozinha, vao largo de passagem.
	KitModular.parede_com_vaos(sup, mat, Vector2(0.0, DIV_Z), Vector2(DIV_X, DIV_Z),
		ALTURA, [Vector2(1.0, 2.6)], ALTURA_PORTA, cor, RODAPE)
	KitModular.parede_com_vaos(sup, mat, Vector2(DIV_X, DIV_Z), Vector2(0.0, DIV_Z),
		ALTURA, [Vector2(DIV_X - 2.6, DIV_X - 1.0)], ALTURA_PORTA, cor, RODAPE)

	# Fundo do corredor: o vao da porta trancada. A folha entra como prop.
	KitModular.parede_com_vaos(sup, mat, Vector2(DIV_X, FUNDO_CORREDOR),
		Vector2(LARGURA, FUNDO_CORREDOR), ALTURA, [Vector2(0.7, 1.7)],
		ALTURA_PORTA, cor, RODAPE)
	KitModular.parede_com_vaos(sup, mat, Vector2(LARGURA, FUNDO_CORREDOR),
		Vector2(DIV_X, FUNDO_CORREDOR), ALTURA, [Vector2(0.7, 1.7)],
		ALTURA_PORTA, cor, RODAPE)

	# O trecho que sela o comodo do fundo ja vem das duas linhas acima, que
	# correm o fundo inteiro. Repetir aqui so criaria duas faces no mesmo plano
	# brigando por profundidade.

	_batentes(sup)

	# Janelas. A da sala e a unica fonte fria do comodo e amarra o interior a rua
	# sem precisar mostrar a rua.
	KitModular.parede_livre(sup, &"janela_acesa", Vector3(0.07, 1.5, 3.4),
		Vector2(1.5, 1.2), PI * 0.5)
	KitModular.parede_livre(sup, &"janela_apagada", Vector3(2.6, 1.5, FUNDO - 0.07),
		Vector2(1.2, 1.0), PI)


## Batente escuro em volta de cada passagem. Vao sem batente le como buraco
## recortado na parede, nao como porta.
static func _batentes(sup: Dictionary) -> void:
	var vaos: Array[Array] = [
		[Vector3(1.85, 0.0, 0.0), 1.1, 0.0],              # entrada
		[Vector3(DIV_X, 0.0, 2.55), 1.1, -PI * 0.5],      # sala | corredor
		[Vector3(1.8, 0.0, DIV_Z), 1.6, 0.0],             # sala | cozinha
		[Vector3(DIV_X + 1.2, 0.0, FUNDO_CORREDOR), 1.0, 0.0],  # porta trancada
	]
	for v: Array in vaos:
		var centro: Vector3 = v[0]
		var larg: float = v[1]
		var giro: float = v[2]
		var lateral := Vector3(cos(giro), 0.0, -sin(giro))
		for lado: float in [-1.0, 1.0]:
			KitModular.parede_livre(sup, &"tabua",
				centro + lateral * (lado * (larg * 0.5 + 0.05))
					+ Vector3(0.0, ALTURA_PORTA * 0.5, 0.0),
				Vector2(0.1, ALTURA_PORTA), giro, KitCasa.MADEIRA_ESCURA)
		KitModular.parede_livre(sup, &"tabua",
			centro + Vector3(0.0, ALTURA_PORTA + 0.05, 0.0),
			Vector2(larg + 0.2, 0.1), giro, KitCasa.MADEIRA_ESCURA)


static func _colisao(colisao: Array[Dictionary]) -> void:
	var e := 0.25
	colisao.append({"tamanho": Vector3(LARGURA, 0.3, FUNDO),
		"pos": Vector3(LARGURA * 0.5, -0.15, FUNDO * 0.5)})
	colisao.append({"tamanho": Vector3(LARGURA, 0.3, FUNDO),
		"pos": Vector3(LARGURA * 0.5, ALTURA + 0.15, FUNDO * 0.5)})

	# Perimetro. A porta de entrada nao ganha vao na colisao: sair e pela area de
	# interacao, e buraco solido ali deixaria o jogador cair na cidade.
	colisao.append({"tamanho": Vector3(LARGURA + e, ALTURA, e),
		"pos": Vector3(LARGURA * 0.5, ALTURA * 0.5, -e * 0.5)})
	colisao.append({"tamanho": Vector3(LARGURA + e, ALTURA, e),
		"pos": Vector3(LARGURA * 0.5, ALTURA * 0.5, FUNDO + e * 0.5)})
	colisao.append({"tamanho": Vector3(e, ALTURA, FUNDO + e),
		"pos": Vector3(-e * 0.5, ALTURA * 0.5, FUNDO * 0.5)})
	colisao.append({"tamanho": Vector3(e, ALTURA, FUNDO + e),
		"pos": Vector3(LARGURA + e * 0.5, ALTURA * 0.5, FUNDO * 0.5)})

	# Divisoria sala | corredor, em dois trechos com a passagem no meio.
	colisao.append({"tamanho": Vector3(0.2, ALTURA, 2.0),
		"pos": Vector3(DIV_X, ALTURA * 0.5, 1.0)})
	colisao.append({"tamanho": Vector3(0.2, ALTURA, FUNDO - 3.1),
		"pos": Vector3(DIV_X, ALTURA * 0.5, 3.1 + (FUNDO - 3.1) * 0.5)})

	# Divisoria sala | cozinha.
	colisao.append({"tamanho": Vector3(1.0, ALTURA, 0.2),
		"pos": Vector3(0.5, ALTURA * 0.5, DIV_Z)})
	colisao.append({"tamanho": Vector3(DIV_X - 2.6, ALTURA, 0.2),
		"pos": Vector3(2.6 + (DIV_X - 2.6) * 0.5, ALTURA * 0.5, DIV_Z)})

	# Fundo do corredor, incluindo o vao: a porta esta trancada, entao ali e
	# parede para efeito de andar. Deixar o buraco livre seria pior que a porta
	# nao abrir, porque o jogador atravessaria a folha.
	colisao.append({"tamanho": Vector3(LARGURA - DIV_X, ALTURA, 0.2),
		"pos": Vector3(DIV_X + (LARGURA - DIV_X) * 0.5, ALTURA * 0.5, FUNDO_CORREDOR)})


# --- comodos ----------------------------------------------------------------

static func _sala(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	# Sofa encostado na divisoria da cozinha, virado para a TV na parede sul. O
	# eixo sofa-mesa-TV e a espinha da sala: e por ele que o jogador entende o
	# comodo em meio segundo.
	KitCasa.tapete(sup, Vector3(4.5, 0.0, 3.5), Vector2(2.9, 3.2))
	KitCasa.sofa(sup, colisao, Vector3(4.6, 0.0, DIV_Z - 0.46), PI)
	KitCasa.mesa_centro(sup, colisao, Vector3(4.55, 0.0, 3.5))
	KitCasa.televisao(sup, colisao, Vector3(4.8, 0.0, 0.4), 0.0, true)
	KitCasa.poltrona(sup, colisao, Vector3(5.95, 0.0, 4.5), -1.92)

	# Estante na parede oeste, aberta para o meio da sala.
	KitCasa.estante(sup, colisao, Vector3(0.19, 0.0, 4.9), PI * 0.5, rng.randi())

	var luz := KitCasa.abajur(sup, colisao, Vector3(3.35, 0.0, 5.5))
	props.append({
		"tipo": "lampada", "pos": luz, "padrao": Lampada.Padrao.ESTAVEL,
		"semente": rng.randi(), "cor": Color("ffdca8"), "energia": 1.9,
		"alcance": 5.0, "facho": false,
	})

	KitCasa.cortina(sup, Vector3(0.22, 1.55, 3.4), 1.9, 1.5, PI * 0.5)
	KitCasa.quadro(sup, Vector3(DIV_X - 0.06, 1.6, 4.3), Vector2(0.5, 0.38), -PI * 0.5)
	KitCasa.quadro(sup, Vector3(DIV_X - 0.06, 1.55, 5.2), Vector2(0.34, 0.44), -PI * 0.5,
		Color("585c4a"))
	KitCasa.relogio(sup, Vector3(3.3, 1.95, DIV_Z - 0.06), PI)
	KitCasa.vaso_planta(sup, colisao, Vector3(0.45, 0.0, 1.15), 1.15)

	# Bilhete na mesa de centro. E a unica coisa da sala que o jogador leva
	# embora, e existe para dar motivo de chegar perto do movel.
	props.append({
		"tipo": "item", "pos": Vector3(4.75, 0.52, 3.62),
		"item": &"bilhete", "quantidade": 1, "indice": 1,
	})


static func _cozinha(sup: Dictionary, colisao: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	KitCasa.bancada(sup, colisao, Vector3(2.2, 0.0, FUNDO - 0.32), 3.0, PI)
	KitCasa.geladeira(sup, colisao, Vector3(6.1, 0.0, FUNDO - 0.5), PI)
	KitCasa.mesa_jantar(sup, colisao, Vector3(4.6, 0.0, 6.95))
	KitCasa.cadeira(sup, colisao, Vector3(4.6, 0.0, 6.2), 0.0)
	KitCasa.cadeira(sup, colisao, Vector3(5.65, 0.0, 6.95), -PI * 0.5)
	if rng.randf() < 0.6:
		KitCasa.vaso_planta(sup, colisao, Vector3(0.4, 0.0, 6.4), 0.8)
	KitCasa.cortina(sup, Vector3(2.6, 1.55, FUNDO - 0.2), 1.5, 1.3, PI)


static func _corredor(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary]) -> void:
	# Parede leste, encarando o corredor: a normal tem que apontar para -X.
	KitCasa.quadro(sup, Vector3(LARGURA - 0.06, 1.6, 3.2), Vector2(0.4, 0.52),
		-PI * 0.5, Color("4a4436"))
	KitCasa.vaso_planta(sup, colisao, Vector3(8.6, 0.0, 0.5), 0.9)

	# Folha da porta trancada, parada no vao. E prop e nao geometria porque ela
	# responde ao jogador: chacoalha e nao abre.
	props.append({
		"tipo": "porta_trancada",
		"pos": Vector3(DIV_X + 0.7, 0.0, FUNDO_CORREDOR),
		"giro": 0.0,
		"rotulo": "Trancada",
	})


static func _luzes(sup: Dictionary, props: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	props.append({
		"tipo": "lampada",
		"pos": KitCasa.luminaria_teto(sup, ALTURA, 3.3, 3.4),
		"padrao": Lampada.Padrao.ESTAVEL, "semente": rng.randi(),
		"cor": Color("ffe3b4"), "energia": 2.5, "alcance": 9.0, "facho": false,
	})
	props.append({
		"tipo": "lampada", "pos": KitCasa.calha_teto(sup, ALTURA, 3.2, 7.1, 1.3),
		"padrao": Lampada.Padrao.FLUORESCENTE if rng.randf() < 0.4 \
			else Lampada.Padrao.ESTAVEL,
		"semente": rng.randi(), "cor": Color("dfe8e2"), "energia": 2.0,
		"alcance": 6.5, "facho": false,
	})
	# Corredor as escuras ou quase. O unico canto ruim da casa fica sendo o que
	# leva a porta que nao abre, e o jogador entende isso sozinho.
	props.append({
		"tipo": "lampada", "pos": KitCasa.luminaria_teto(sup, ALTURA, 7.8, 2.6),
		"padrao": Lampada.Padrao.MORTA if rng.randf() < 0.45 \
			else Lampada.Padrao.SODIO_FALHANDO,
		"semente": rng.randi(), "cor": Color("f0d2a0"), "energia": 1.2,
		"alcance": 4.5, "facho": false,
	})
	# Brilho da TV. Fluorescente serve de padrao porque tremula sem apagar, que e
	# como tubo ligado sem sinal se comporta.
	props.append({
		"tipo": "lampada", "pos": Vector3(4.8, 0.85, 1.1),
		"padrao": Lampada.Padrao.FLUORESCENTE, "semente": rng.randi(),
		"cor": Color("9dc4e0"), "energia": 1.1, "alcance": 3.8, "facho": false,
	})


static func _morador(props: Array[Dictionary], semente: int) -> void:
	# De pe na janela, de costas para quem entra. O jogador ve a silhueta antes
	# de ver a pessoa, e a virada e a primeira coisa que a casa faz por conta
	# propria.
	props.append({
		"tipo": "npc",
		"pos": Vector3(1.3, 0.0, 4.0),
		"giro": PI * 0.5,
		"semente": semente,
	})
