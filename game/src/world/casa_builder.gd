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
## Por que a casa varia
## --------------------
## Ate aqui toda porta de casa da cidade abria na MESMA sala, com o MESMO senhor
## na mesma janela contando a mesma historia. Uma casa assim e um lugar; vinte
## casas assim sao um cenario, e a segunda entrada denuncia a primeira. A
## variacao nao e enfeite: e o que decide se explorar a cidade paga alguma coisa.
##
## Varia em quatro camadas, da mais barata para a mais cara:
##
##   paleta    parede, piso, tecido e tapete saem de tinta por vertice
##   planta    as duas divisorias andam, e a sala muda de proporcao
##   arranjo   o eixo sofa-TV cai no sentido norte-sul ou leste-oeste
##   perfil    quem mora ali, o que a sala tem a mais e o que ele conta
##
## O perfil e a camada que o jogador vai lembrar. Ele nao decide um estilo de
## decoracao: decide QUEM esta em casa, e o movel vem atras. Uma casa de familia
## com a mesa posta e uma casa em mudanca com o sofa entre caixas fechadas nao
## sao a mesma sala pintada de outra cor.
##
## Planta, em metros, origem no canto sul-oeste (as divisorias andam):
##
##   z=8.4 +-------------------+-----------+
##         |     COZINHA       |  (selado) |
##  div_z  +--------[vao]------+           |
##         |                   |           |
##         |       SALA        |  f_corr [porta trancada]
##         |                   +-----------+
##         |                   |           |
##         |                   |  CORREDOR |
##   z=0   +----[entrada]------+-----------+
##        x=0                div_x       x=9.0
class_name CasaBuilder
extends RefCounted

const ALTURA := 2.45
const ALTURA_PORTA := 2.05
const RODAPE := 0.11

const LARGURA := 9.0
const FUNDO := 8.4

## Onde o jogador aparece ao entrar, e para onde olha. Chega de costas para a
## porta, olhando a sala inteira: e o primeiro quadro do comodo e vale mais que
## qualquer movel isolado. Fixo em todas as plantas porque e a mesma porta de
## rua — o que muda e o que ele ve dali.
const ENTRADA := Vector3(1.85, 0.0, 0.8)
const OLHAR := Vector3(3.2, 1.55, 5.2)

## Quem mora na casa. Nao e um estilo de decoracao: e uma pessoa, e o movel vem
## atras dela.
enum Perfil {
	FAMILIA,   ## casal com filho; casa cheia, mesa posta, luz forte
	IDOSO,     ## mora sozinho ha muito tempo; parede cheia de retrato
	MUDANCA,   ## esta indo embora ou acabou de chegar; caixa fechada com fita
	ALUGADO,   ## quarto alugado de gente jovem; bagunca e TV ligada
}

## Faixa de idade de quem abre a porta, por perfil. Interiores resolve a ficha
## no RegistroCivil com esta faixa — a mesma carteira que sai na rua sai aqui.
const IDADE_DO_PERFIL := {
	Perfil.FAMILIA: Vector2i(31, 52),
	Perfil.IDOSO: Vector2i(66, 88),
	Perfil.MUDANCA: Vector2i(27, 49),
	Perfil.ALUGADO: Vector2i(19, 30),
}

## Paredes de casa, mais quentes que as do apartamento.
const CORES_PAREDE: Array[Color] = [
	Color("cdbfa2"),  # creme
	Color("c3b9a6"),  # bege esverdeado
	Color("d0c0ac"),  # areia
	Color("c8bda4"),  # palha
	Color("bfb59f"),  # cinza quente
]

## Tecido do estofado. Faixa estreita e toda dessaturada: sofa colorido puxa o
## olho para o movel, e o olho tem que ir para os cantos.
const CORES_TECIDO: Array[Color] = [
	Color("7a6a58"), Color("6d6a5c"), Color("7f6f5e"), Color("6a6356"),
]

const CORES_TAPETE: Array[Color] = [
	Color("8f4a3c"), Color("6d5638"), Color("4f5548"), Color("7a4a44"),
]


static func construir(semente: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente

	var planta := _planta(rng)

	var sup: Dictionary = {}
	var props: Array[Dictionary] = []
	var colisao: Array[Dictionary] = []

	_pisos(sup, planta)
	_paredes(sup, planta)
	_colisao(colisao, planta)
	_sala(sup, colisao, props, planta, rng)
	_cozinha(sup, colisao, planta, rng)
	_corredor(sup, colisao, props, planta, rng)
	_luzes(sup, props, planta, rng)
	_morador(props, planta, semente)
	# Duas tomadas baixas nas paredes de fora, onde nao ha movel na frente (sem
	# sorteio: ver `PontosDeTomada`).
	props.append_array(PontosDeTomada.escolher([
		[Vector3(0.01, 0.0, 3.0), PI * 0.5],
		[Vector3(0.01, 0.0, 4.4), PI * 0.5],
		[Vector3(3.8, 0.0, 0.01), 0.0],
		[Vector3(5.0, 0.0, 0.01), 0.0],
		[Vector3(3.0, 0.0, FUNDO - 0.01), PI],
		[Vector3(LARGURA - 0.01, 0.0, 2.2), -PI * 0.5],
	], colisao, 2))

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


# --- planta -----------------------------------------------------------------

## Sorteia a casa inteira de uma vez.
##
## Tudo que varia sai daqui e desce por parametro, e nao ha segundo sorteio
## espalhado pelas funcoes de movel. Com o sorteio distribuido, acrescentar um
## vaso de planta no meio do arquivo mudaria a cor da parede de todas as casas
## da cidade, porque consumiria um numero a mais do mesmo fluxo.
static func _planta(rng: RandomNumberGenerator) -> Dictionary:
	var perfis: Array[Perfil] = [Perfil.FAMILIA, Perfil.IDOSO, Perfil.MUDANCA,
		Perfil.ALUGADO]
	var perfil: Perfil = perfis[rng.randi() % perfis.size()]

	# As divisorias andam dentro de uma faixa estreita. Larga demais, a sala de
	# uma casa vira corredor e a da outra vira salao, e as duas param de ler
	# como a mesma cidade.
	var div_x := rng.randf_range(5.9, 7.1)
	var div_z := rng.randf_range(5.4, 6.4)

	return {
		"perfil": perfil,
		"div_x": div_x,
		"div_z": div_z,
		# Fundo do corredor: onde fica a porta trancada. Sempre antes do fim da
		# casa, para sobrar o comodo selado atras dela.
		"fundo_corredor": clampf(div_z - rng.randf_range(0.3, 1.1), 4.6, 6.2),
		# Eixo da sala. Ver _sala: nao e espelho, sao duas salas diferentes.
		"eixo_ns": rng.randf() < 0.55,
		"cor_parede": CORES_PAREDE[rng.randi() % CORES_PAREDE.size()],
		"cor_tecido": CORES_TECIDO[rng.randi() % CORES_TECIDO.size()],
		"cor_tapete": CORES_TAPETE[rng.randi() % CORES_TAPETE.size()],
		# Ceramica na area social em vez de tabua. A madeira fica sendo a casa
		# mais antiga, e nao o padrao.
		"piso_social": &"piso_ceramico" if rng.randf() < 0.42 else &"piso",
		"tv_ligada": perfil != Perfil.IDOSO and rng.randf() < 0.8,
		"semente_estante": rng.randi(),
		"foco_tv": Vector3.ZERO,
	}


# --- casca ------------------------------------------------------------------

static func _pisos(sup: Dictionary, planta: Dictionary) -> void:
	var div_x: float = planta["div_x"]
	var div_z: float = planta["div_z"]
	var f_corr: float = planta["fundo_corredor"]
	var social: StringName = planta["piso_social"]

	# Ceramica na soleira e na cozinha, o piso social no resto. A troca de piso
	# marca o comodo sem precisar de parede, que e como casa de verdade resolve.
	KitModular.chao(sup, social, Vector3(0.0, 0.0, 1.4), Vector2(div_x, div_z - 1.4))
	KitModular.chao(sup, &"piso_ceramico", Vector3.ZERO, Vector2(3.2, 1.4))
	KitModular.chao(sup, social, Vector3(3.2, 0.0, 0.0), Vector2(div_x - 3.2, 1.4))
	KitModular.chao(sup, &"piso_ceramico", Vector3(0.0, 0.0, div_z),
		Vector2(div_x, FUNDO - div_z))
	KitModular.chao(sup, &"piso", Vector3(div_x, 0.0, 0.0),
		Vector2(LARGURA - div_x, f_corr))
	KitModular.chao(sup, &"piso", Vector3(div_x, 0.0, f_corr),
		Vector2(LARGURA - div_x, FUNDO - f_corr))

	var teto := PSXMesh.plane_dados(Vector2(LARGURA, FUNDO))
	KitModular.por(sup, &"teto", teto,
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
			Vector3(LARGURA * 0.5, ALTURA, FUNDO * 0.5)))


static func _paredes(sup: Dictionary, planta: Dictionary) -> void:
	var mat: StringName = &"reboco"
	var cor: Color = planta["cor_parede"]
	var div_x: float = planta["div_x"]
	var div_z: float = planta["div_z"]
	var f_corr: float = planta["fundo_corredor"]

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
	KitModular.parede_com_vaos(sup, mat, Vector2(div_x, 0.0), Vector2(div_x, FUNDO),
		ALTURA, [Vector2(2.0, 3.1)], ALTURA_PORTA, cor, RODAPE)
	KitModular.parede_com_vaos(sup, mat, Vector2(div_x, FUNDO), Vector2(div_x, 0.0),
		ALTURA, [Vector2(FUNDO - 3.1, FUNDO - 2.0)], ALTURA_PORTA, cor, RODAPE)

	# Divisoria sala | cozinha, vao largo de passagem.
	KitModular.parede_com_vaos(sup, mat, Vector2(0.0, div_z), Vector2(div_x, div_z),
		ALTURA, [Vector2(1.0, 2.6)], ALTURA_PORTA, cor, RODAPE)
	KitModular.parede_com_vaos(sup, mat, Vector2(div_x, div_z), Vector2(0.0, div_z),
		ALTURA, [Vector2(div_x - 2.6, div_x - 1.0)], ALTURA_PORTA, cor, RODAPE)

	# Fundo do corredor: o vao da porta trancada. A folha entra como prop.
	KitModular.parede_com_vaos(sup, mat, Vector2(div_x, f_corr),
		Vector2(LARGURA, f_corr), ALTURA, [Vector2(0.7, 1.7)],
		ALTURA_PORTA, cor, RODAPE)
	KitModular.parede_com_vaos(sup, mat, Vector2(LARGURA, f_corr),
		Vector2(div_x, f_corr), ALTURA, [Vector2(0.7, 1.7)],
		ALTURA_PORTA, cor, RODAPE)

	_batentes(sup, planta)

	# Janelas. A da sala e a unica fonte fria do comodo e amarra o interior a rua
	# sem precisar mostrar a rua.
	KitModular.parede_livre(sup, &"janela_acesa", Vector3(0.07, 1.5, 3.4),
		Vector2(1.5, 1.2), PI * 0.5)
	KitModular.parede_livre(sup, &"janela_apagada", Vector3(2.6, 1.5, FUNDO - 0.07),
		Vector2(1.2, 1.0), PI)


## Batente escuro em volta de cada passagem. Vao sem batente le como buraco
## recortado na parede, nao como porta.
##
## Sao CAIXAS atravessando a parede, e nao placas rente a ela. A primeira versao
## punha uma placa exatamente no plano da divisoria: as duas faces ficavam na
## mesma profundidade, e com o snap de vertice do contrato PSX a quina de cada
## porta da casa piscava entre a madeira e o reboco conforme o jogador andava.
## A caixa resolve por construcao — ela tem 16 cm de profundidade, entao nenhuma
## das suas faces divide plano com a parede, e ainda aparece pelos DOIS lados do
## vao, que a placa nunca fez.
static func _batentes(sup: Dictionary, planta: Dictionary) -> void:
	var div_x: float = planta["div_x"]
	var div_z: float = planta["div_z"]
	var f_corr: float = planta["fundo_corredor"]

	var vaos: Array[Array] = [
		[Vector3(1.85, 0.0, 0.0), 1.1, 0.0],                 # entrada
		[Vector3(div_x, 0.0, 2.55), 1.1, -PI * 0.5],         # sala | corredor
		[Vector3(1.8, 0.0, div_z), 1.6, 0.0],                # sala | cozinha
		[Vector3(div_x + 1.2, 0.0, f_corr), 1.0, 0.0],       # porta trancada
	]
	for v: Array in vaos:
		var centro: Vector3 = v[0]
		var larg: float = v[1]
		var giro: float = v[2]
		var lateral := Vector3(cos(giro), 0.0, -sin(giro))
		for lado: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"tabua",
				centro + lateral * (lado * (larg * 0.5 + 0.06))
					+ Vector3(0.0, ALTURA_PORTA * 0.5, 0.0),
				Vector3(0.12, ALTURA_PORTA, 0.16), KitCasa.MADEIRA_ESCURA, giro)
		KitModular.caixa_cor(sup, &"tabua",
			centro + Vector3(0.0, ALTURA_PORTA + 0.06, 0.0),
			Vector3(larg + 0.24, 0.12, 0.16), KitCasa.MADEIRA_ESCURA, giro)


static func _colisao(colisao: Array[Dictionary], planta: Dictionary) -> void:
	var e := 0.25
	var div_x: float = planta["div_x"]
	var div_z: float = planta["div_z"]
	var f_corr: float = planta["fundo_corredor"]

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
		"pos": Vector3(div_x, ALTURA * 0.5, 1.0)})
	colisao.append({"tamanho": Vector3(0.2, ALTURA, FUNDO - 3.1),
		"pos": Vector3(div_x, ALTURA * 0.5, 3.1 + (FUNDO - 3.1) * 0.5)})

	# Divisoria sala | cozinha.
	colisao.append({"tamanho": Vector3(1.0, ALTURA, 0.2),
		"pos": Vector3(0.5, ALTURA * 0.5, div_z)})
	colisao.append({"tamanho": Vector3(div_x - 2.6, ALTURA, 0.2),
		"pos": Vector3(2.6 + (div_x - 2.6) * 0.5, ALTURA * 0.5, div_z)})

	# Fundo do corredor, incluindo o vao: a porta esta trancada, entao ali e
	# parede para efeito de andar. Deixar o buraco livre seria pior que a porta
	# nao abrir, porque o jogador atravessaria a folha.
	colisao.append({"tamanho": Vector3(LARGURA - div_x, ALTURA, 0.2),
		"pos": Vector3(div_x + (LARGURA - div_x) * 0.5, ALTURA * 0.5, f_corr)})


# --- sala -------------------------------------------------------------------

## A sala, no eixo que a planta sorteou.
##
## Os dois arranjos nao sao a mesma sala espelhada. No eixo norte-sul o jogador
## entra por TRAS da TV e ve o sofa de frente, com a janela a esquerda; no eixo
## leste-oeste ele entra pelo LADO e a sala se abre na diagonal, com a TV contra
## a divisoria do corredor. Sao duas primeiras impressoes diferentes, que e a
## coisa mais cara que a sala tem para dar.
static func _sala(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], planta: Dictionary,
		rng: RandomNumberGenerator) -> void:
	var div_x: float = planta["div_x"]
	var div_z: float = planta["div_z"]
	var tecido: Color = planta["cor_tecido"]
	var tapete: Color = planta["cor_tapete"]

	var meio_x := div_x * 0.5 + 0.35
	var meio_z := (div_z + 1.4) * 0.5

	var foco := Vector3.ZERO
	if bool(planta["eixo_ns"]):
		# Sofa encostado na divisoria da cozinha, TV na parede sul.
		KitCasa.tapete(sup, Vector3(meio_x, 0.0, meio_z), Vector2(2.9, 3.2),
			0.0, tapete)
		KitCasa.sofa(sup, colisao, Vector3(meio_x, 0.0, div_z - 0.46), PI, tecido)
		KitCasa.mesa_centro(sup, colisao, Vector3(meio_x - 0.05, 0.0, meio_z))
		foco = Vector3(meio_x + 0.2, 0.0, 0.4)
		KitCasa.televisao(sup, colisao, foco, 0.0, bool(planta["tv_ligada"]))
		KitCasa.poltrona(sup, colisao, Vector3(div_x - 0.75, 0.0, meio_z + 0.9),
			-1.92, tecido)
	else:
		# Sofa na parede oeste, TV contra a divisoria do corredor.
		KitCasa.tapete(sup, Vector3(meio_x, 0.0, meio_z), Vector2(3.1, 2.8),
			0.0, tapete)
		KitCasa.sofa(sup, colisao, Vector3(1.05, 0.0, meio_z), PI * 0.5, tecido)
		KitCasa.mesa_centro(sup, colisao, Vector3(meio_x - 0.3, 0.0, meio_z))
		foco = Vector3(div_x - 0.42, 0.0, meio_z)
		KitCasa.televisao(sup, colisao, foco, -PI * 0.5, bool(planta["tv_ligada"]))
		KitCasa.poltrona(sup, colisao, Vector3(meio_x + 0.1, 0.0, div_z - 0.62),
			PI, tecido)

	planta["foco_tv"] = foco

	# Estante na parede oeste, fora do eixo da TV nos dois arranjos.
	var estante_z := div_z - 1.1 if bool(planta["eixo_ns"]) else 1.35
	KitCasa.estante(sup, colisao, Vector3(0.19, 0.0, estante_z), PI * 0.5,
		int(planta["semente_estante"]))

	var luz := KitCasa.abajur(sup, colisao,
		Vector3(div_x - 0.55, 0.0, div_z - 0.5))
	props.append({
		"tipo": "lampada", "pos": luz, "padrao": Lampada.Padrao.ESTAVEL,
		"semente": rng.randi(), "cor": Color("ffdca8"), "energia": 1.9,
		"alcance": 5.0, "facho": false,
	})

	KitCasa.cortina(sup, Vector3(0.22, 1.55, 3.4), 1.9, 1.5, PI * 0.5)
	KitCasa.quadro(sup, Vector3(div_x - 0.06, 1.6, 4.3), Vector2(0.5, 0.38),
		-PI * 0.5)
	KitCasa.relogio(sup, Vector3(3.3, 1.95, div_z - 0.06), PI)
	KitCasa.vaso_planta(sup, colisao, Vector3(0.45, 0.0, 1.15), 1.15)

	_extras_da_sala(sup, colisao, planta, rng, meio_x, meio_z)

	# Bilhete na mesa de centro. E a unica coisa da sala que o jogador leva
	# embora, e existe para dar motivo de chegar perto do movel.
	var mesa_x := meio_x - 0.05 if bool(planta["eixo_ns"]) else meio_x - 0.3
	props.append({
		"tipo": "item", "pos": Vector3(mesa_x + 0.2, 0.52, meio_z + 0.12),
		"item": &"bilhete", "quantidade": 1, "indice": 1,
	})


## O que separa uma casa da outra depois que o movel ja esta no lugar.
##
## Cada perfil poe de tres a cinco pecas, e nao mais. O que conta a historia e a
## peca ser INCOMPATIVEL com as outras casas, e nao haver muitas delas: uma
## pilha de caixa fechada com fita diz mais sobre quem mora ali do que dez
## enfeites genericos.
static func _extras_da_sala(sup: Dictionary, colisao: Array[Dictionary],
		planta: Dictionary, rng: RandomNumberGenerator,
		meio_x: float, meio_z: float) -> void:
	var perfil: Perfil = planta["perfil"]
	var div_x: float = planta["div_x"]
	var div_z: float = planta["div_z"]

	match perfil:
		Perfil.FAMILIA:
			# Parede de retrato e brinquedo no chao. O brinquedo e a peca que
			# poe uma crianca na casa sem precisar de uma crianca.
			KitCasa.quadro(sup, Vector3(div_x - 0.06, 1.62, 5.15),
				Vector2(0.30, 0.40), -PI * 0.5, Color("6c6250"))
			KitCasa.quadro(sup, Vector3(div_x - 0.06, 1.18, 5.15),
				Vector2(0.26, 0.20), -PI * 0.5, Color("585c4a"))
			var cores: Array[Color] = [Color("a8532f"), Color("2f5aa8"),
				Color("d0b23a")]
			for k in 3:
				KitModular.caixa_cor(sup, &"tabua",
					Vector3(meio_x - 0.9 + float(k) * 0.34, 0.07,
						meio_z - 1.25 + rng.randf_range(-0.12, 0.12)),
					Vector3(0.13, 0.13, 0.13), cores[k],
					rng.randf_range(0.0, PI))
			KitCasa.vaso_planta(sup, colisao, Vector3(div_x - 0.5, 0.0, 0.55), 0.9)

		Perfil.IDOSO:
			# Parede cheia de retrato pequeno e uma pilha de jornal ao lado da
			# poltrona. Casa de quem esta ha quarenta anos no mesmo lugar.
			for k in 4:
				KitCasa.quadro(sup,
					Vector3(div_x - 0.06, 1.34 + float(k % 2) * 0.42,
						4.55 + float(k / 2) * 0.52),
					Vector2(0.22, 0.28), -PI * 0.5,
					Color("6a6152") if k % 2 == 0 else Color("55503f"))
			for k in 6:
				KitModular.caixa_cor(sup, &"tabua",
					Vector3(0.72, 0.03 + float(k) * 0.028, div_z - 1.9),
					Vector3(0.30, 0.026, 0.24), Color("bab19a"),
					rng.randf_range(-0.09, 0.09))
			KitCasa.vaso_planta(sup, colisao, Vector3(0.45, 0.0, div_z - 0.6), 1.0)

		Perfil.MUDANCA:
			# Caixas fechadas com fita. A casa esta entre dois donos, e nao da
			# para dizer em qual direcao.
			var canto := Vector3(div_x - 1.15, 0.0, 1.0)
			for k in 3:
				var h := float(k) * 0.44
				var lado := 0.42 - float(k) * 0.03
				var giro := rng.randf_range(-0.15, 0.15)
				KitModular.caixa_cor(sup, &"tabua",
					canto + Vector3(0.0, h + 0.21, 0.0),
					Vector3(lado, 0.42, lado), Color("9c7f56"), giro)
				# Fita crepe: uma faixa clara atravessando a tampa.
				KitModular.caixa_cor(sup, &"reboco",
					canto + Vector3(0.0, h + 0.432, 0.0),
					Vector3(lado * 0.22, 0.012, lado + 0.01), Color("d9d2bc"),
					giro)
			KitModular.solido(colisao, canto + Vector3(0.0, 0.65, 0.0),
				Vector3(0.5, 1.3, 0.5))
			# Retangulo mais claro na parede, de onde saiu um quadro. Fica
			# quatro centimetros a frente do reboco: no mesmo plano os dois
			# brigam e a mancha pisca.
			KitModular.parede_livre(sup, &"reboco",
				Vector3(div_x - 0.04, 1.6, 3.55), Vector2(0.56, 0.44),
				-PI * 0.5, Color(planta["cor_parede"]).lightened(0.16))

		Perfil.ALUGADO:
			# Garrafa, cadeira fora de lugar e roupa por cima dela. Nada e caro
			# e nada esta arrumado, que e o retrato de um quarto alugado.
			for k in 5:
				KitModular.caixa_cor(sup, &"metal",
					Vector3(meio_x - 0.7 + rng.randf_range(0.0, 1.5), 0.12,
						meio_z - 0.9 + rng.randf_range(0.0, 1.4)),
					Vector3(0.07, 0.24, 0.07),
					Color("3f5638") if k % 2 == 0 else Color("6a4a2a"),
					rng.randf_range(0.0, PI))
			KitCasa.cadeira(sup, colisao, Vector3(0.9, 0.0, 1.55),
				rng.randf_range(-0.6, 0.6))
			KitModular.caixa_cor(sup, &"reboco",
				Vector3(0.9, 0.64, 1.55), Vector3(0.42, 0.26, 0.30),
				Color("6b5a72"), 0.35)


# --- cozinha ----------------------------------------------------------------

static func _cozinha(sup: Dictionary, colisao: Array[Dictionary],
		planta: Dictionary, rng: RandomNumberGenerator) -> void:
	var div_x: float = planta["div_x"]
	var div_z: float = planta["div_z"]
	var perfil: Perfil = planta["perfil"]
	var mesa := Vector3(div_x * 0.5 + 0.3, 0.0, (div_z + FUNDO) * 0.5)

	KitCasa.bancada(sup, colisao, Vector3(2.2, 0.0, FUNDO - 0.32), 3.0, PI)
	KitCasa.geladeira(sup, colisao, Vector3(div_x - 0.5, 0.0, FUNDO - 0.5), PI)
	KitCasa.mesa_jantar(sup, colisao, mesa)

	# Quantas cadeiras e quantos lugares postos dizem quanta gente mora aqui. E
	# a informacao mais barata da casa inteira.
	var cadeiras := 4 if perfil == Perfil.FAMILIA else (
		1 if perfil == Perfil.IDOSO else 2)
	var lugares: Array[Vector3] = [
		Vector3(0.0, 0.0, -0.75), Vector3(1.05, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.75), Vector3(-1.05, 0.0, 0.0),
	]
	var giros: Array[float] = [0.0, -PI * 0.5, PI, PI * 0.5]
	for k in cadeiras:
		KitCasa.cadeira(sup, colisao, mesa + lugares[k], giros[k])
		if perfil == Perfil.FAMILIA:
			# Mesa posta. Casa onde ainda se janta junto.
			KitModular.caixa_cor(sup, &"reboco",
				mesa + lugares[k] * 0.42 + Vector3(0.0, 0.77, 0.0),
				Vector3(0.22, 0.022, 0.22), Color("d8d4c8"))

	if perfil == Perfil.MUDANCA:
		# Duas caixas em cima da bancada: a cozinha ja foi embalada.
		for k in 2:
			KitModular.caixa_cor(sup, &"tabua",
				Vector3(1.5 + float(k) * 0.55, 1.06, FUNDO - 0.35),
				Vector3(0.38, 0.30, 0.34), Color("9c7f56"),
				rng.randf_range(-0.12, 0.12))

	if rng.randf() < 0.6:
		KitCasa.vaso_planta(sup, colisao, Vector3(0.4, 0.0, div_z + 0.45), 0.8)
	KitCasa.cortina(sup, Vector3(2.6, 1.55, FUNDO - 0.2), 1.5, 1.3, PI)


# --- corredor ---------------------------------------------------------------

static func _corredor(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], planta: Dictionary,
		rng: RandomNumberGenerator) -> void:
	var div_x: float = planta["div_x"]
	var f_corr: float = planta["fundo_corredor"]

	# Parede leste, encarando o corredor: a normal tem que apontar para -X.
	KitCasa.quadro(sup, Vector3(LARGURA - 0.06, 1.6, 3.2), Vector2(0.4, 0.52),
		-PI * 0.5, Color("4a4436"))
	KitCasa.vaso_planta(sup, colisao, Vector3(LARGURA - 0.4, 0.0, 0.5), 0.9)

	if rng.randf() < 0.5:
		# Sapatos junto a parede do corredor. Detalhe de casa habitada que custa
		# duas caixas.
		for k in 2:
			KitModular.caixa_cor(sup, &"tabua",
				Vector3(div_x + 0.35, 0.06, 1.1 + float(k) * 0.28),
				Vector3(0.12, 0.09, 0.26), Color("3b332a"),
				rng.randf_range(-0.25, 0.25))

	# Folha da porta trancada, parada no vao. E prop e nao geometria porque ela
	# responde ao jogador: chacoalha e nao abre.
	props.append({
		"tipo": "porta_trancada",
		"pos": Vector3(div_x + 0.7, 0.0, f_corr),
		"giro": 0.0,
		"rotulo": "Trancada",
	})


# --- luz --------------------------------------------------------------------

## Cinco luzes, sempre: teto da sala, abajur, cozinha, corredor e o brilho da
## TV. O numero e fixo de proposito — e o orcamento de luz de um interior, e o
## criterio de aceite da casa conta exatamente cinco. O que varia e o tom, a
## forca e o defeito de cada uma, e e isso que muda o clima de uma casa para a
## outra sem custar uma luz a mais.
static func _luzes(sup: Dictionary, props: Array[Dictionary],
		planta: Dictionary, rng: RandomNumberGenerator) -> void:
	var perfil: Perfil = planta["perfil"]
	var div_x: float = planta["div_x"]
	var div_z: float = planta["div_z"]
	var f_corr: float = planta["fundo_corredor"]

	# Casa de idoso e mais amarela e mais fraca; quarto alugado tem lampada fria
	# de loja. O tom da luz e a coisa que o jogador sente sem reparar.
	var quente := Color("ffe3b4")
	var energia := 2.5
	match perfil:
		Perfil.IDOSO:
			quente = Color("ffd79a")
			energia = 2.0
		Perfil.ALUGADO:
			quente = Color("f2f0e4")
			energia = 2.2
		Perfil.MUDANCA:
			quente = Color("ffe8c6")
			energia = 2.3
		_:
			pass

	var teto_ruim := perfil == Perfil.ALUGADO and rng.randf() < 0.5
	props.append({
		"tipo": "lampada",
		"pos": KitCasa.luminaria_teto(sup, ALTURA, div_x * 0.5 + 0.1, div_z * 0.55),
		"padrao": Lampada.Padrao.FLUORESCENTE if teto_ruim \
			else Lampada.Padrao.ESTAVEL,
		"semente": rng.randi(), "cor": quente, "energia": energia,
		"alcance": 9.0, "facho": false,
	})
	props.append({
		"tipo": "lampada",
		"pos": KitCasa.calha_teto(sup, ALTURA, div_x * 0.5,
			(div_z + FUNDO) * 0.5 + 0.4, 1.3),
		"padrao": Lampada.Padrao.FLUORESCENTE if rng.randf() < 0.4 \
			else Lampada.Padrao.ESTAVEL,
		"semente": rng.randi(), "cor": Color("dfe8e2"), "energia": 2.0,
		"alcance": 6.5, "facho": false,
	})
	# Corredor as escuras ou quase. O unico canto ruim da casa fica sendo o que
	# leva a porta que nao abre, e o jogador entende isso sozinho.
	props.append({
		"tipo": "lampada",
		"pos": KitCasa.luminaria_teto(sup, ALTURA,
			div_x + (LARGURA - div_x) * 0.5, f_corr * 0.5),
		"padrao": Lampada.Padrao.MORTA if rng.randf() < 0.45 \
			else Lampada.Padrao.SODIO_FALHANDO,
		"semente": rng.randi(), "cor": Color("f0d2a0"), "energia": 1.2,
		"alcance": 4.5, "facho": false,
	})
	# Brilho da TV. Fluorescente serve de padrao porque tremula sem apagar, que e
	# como tubo ligado sem sinal se comporta. Com a TV desligada ela vira uma
	# brasa fraca: o aparelho continua existindo no escuro, e a casa do idoso
	# perde a unica luz fria que as outras tem.
	var foco: Vector3 = planta["foco_tv"]
	var ligada := bool(planta["tv_ligada"])
	props.append({
		"tipo": "lampada", "pos": foco + Vector3(0.0, 0.85, 0.0),
		"padrao": Lampada.Padrao.FLUORESCENTE if ligada \
			else Lampada.Padrao.ESTAVEL,
		"semente": rng.randi(), "cor": Color("9dc4e0"),
		"energia": 1.1 if ligada else 0.25,
		"alcance": 3.8 if ligada else 1.6, "facho": false,
	})


# --- morador ----------------------------------------------------------------

## De pe na janela, de costas para quem entra. O jogador ve a silhueta antes de
## ver a pessoa, e a virada e a primeira coisa que a casa faz por conta propria.
##
## `idade_min` e `idade_max` descem ate Interiores, que resolve a ficha no
## RegistroCivil na thread principal. O builder nao consulta o registro:
## `identidade` mantem cache, e chamar de dentro do WorkerThreadPool e uma
## corrida esperando para acontecer.
static func _morador(props: Array[Dictionary], planta: Dictionary,
		semente: int) -> void:
	var faixa: Vector2i = IDADE_DO_PERFIL[planta["perfil"]]
	props.append({
		"tipo": "npc",
		# Ao lado da janela, e nao em cima dela. Tambem nao pode andar para o
		# sul: a captura enquadra o morador com um deslocamento fixo a partir
		# dele, e meio metro mais perto da entrada punha a camera dentro da TV.
		"pos": Vector3(1.3, 0.0, 4.0),
		"giro": PI * 0.5,
		"semente": semente,
		"idade_min": faixa.x,
		"idade_max": faixa.y,
		"perfil": int(planta["perfil"]),
	})
