## Loja de conveniencia. Mesmo contrato do CasaBuilder e do InteriorBuilder:
## dados puros, montados na thread.
##
## O ponto da loja nao e ter mais movel que a casa, e ser o contrario dela em
## tudo que o jogador sente. A casa e quente, baixa, apertada e escura nos
## cantos. A loja e branca, alta, larga e sem uma sombra em lugar nenhum. Depois
## de vinte minutos de nevoa cinza e poste de sodio, entrar aqui e agressivo: a
## luz machuca, o piso brilha, tudo esta arrumado.
##
## Uma loja aberta as tres da manha e o unico comodo do jogo em que a luz e o
## problema.
##
##
## A loja existe na rua (PLANO_MERCADO_AAA, F1)
## --------------------------------------------
## A mesma planta e montada de dois jeitos. Na rua (`no_mundo`), atras da
## propria vitrine, pelo `InteriorNoMundo`: o vidro, os montantes e o portao
## sao do predio (PredioMercado) e existem com o chunk; daqui sai o lado de
## dentro. No comodo teleportado (a abertura), a planta leva junto a frente
## inteira, com vidro fosco aceso no lugar da rua que la em cima nao existe.
##
## As medidas moram aqui e so aqui. A frente de loja na calcada, o lote na
## fileira e o teste de caminhada leem estas constantes.
##
##
## O lado de dentro da loja
## ------------------------
## O salao e metade do lugar. A outra metade e o BLOCO DE SERVICO: garagem,
## corredor, banheiro, copa, a sala do monitor e o estoque. Ele existe por uma
## razao que nao e "ter mais comodo".
##
## Uma loja de conveniencia tem duas caras. A de fora, vitrine acesa e
## letreiro, feita para atrair; e a de dentro, papelao, balde de mop, uma escala
## de turno pregada na cortica, que nao foi feita para ninguem ver. O salao
## sozinho conta so a primeira e le como cenario por mais bem montado que esteja.
## Atravessar UMA porta e cair na segunda e o que faz o jogador entender que
## aquele lugar e o emprego de alguem.
##
## Por isso a paleta vira de lado na travessia: branco chapado de um lado, verde
## de reparticao e concreto do outro. E a mesma virada que separa o palco da
## coxia, e ela nao custa mecanica nenhuma.
##
## Planta, em metros. Origem no canto interno da parede da frente, no piso; +Z
## entra na loja, a calcada fica em z < -PAREDE. As paredes de dentro tem 20 cm,
## e as linhas abaixo sao o EIXO delas.
##
##   z=16 +--------+----------+----------+----------------------------+
##        |BANHEIRO|   COPA   | MONITOR  |      ESTOQUE SECO          |
##        |        |          |  (CFTV)  |                            |
## z=12.4 +--[p]---+---[p]----+---[p]----+--[  vao  ]------+ bebida  |
##        |               CORREDOR DE SERVICO                        |
## z=10.8 +----[ vao ]----+--[p]==== 8 portas de geladeira =========+
##        |               |   |                                      |
##        |               |   | cafe  ilha 1  ilha 2   ilha 3   gon- |
##        |   GARAGEM     |   B                                 dola |
##        |   estante,    |   A  <- fila                        de   |
##        |   paletes,    |   L                                 pa-  |
##        |   carrinho    |   C          [ corredor central ]   rede |
##        |               |   A  [sorvete] [cestas]   [revistas]      |
##    z=0 +--[ PORTAO ]---+=pilar=vitrine==[PORTA AUTO]==vitrine=====+
##       x=0          x=4.6                  x=11                  x=17
##                              CALCADA
##
## O caixa fica encostado na divisa, e a porta de servico abre logo depois do
## fim dele, na parede das geladeiras: "atras do caixa" e um lugar de verdade, e
## o funcionario nao atravessa o salao carregando caixa.
class_name MercadoBuilder
extends RefCounted

# --- casca ------------------------------------------------------------------

## A sala por dentro, de reboco a reboco.
const LARGURA := 17.0
const FUNDO := 16.0
## Parede externa: da fachada ao reboco de dentro. A mesma da casa da fumaca
## (KitFumaca.PAREDE), porque e o mesmo predio da mesma fileira.
const PAREDE := 0.25
## Parede de dentro. Os eixos abaixo ficam no MEIO dela.
const PAREDE_INTERNA := 0.2
const MEIA := PAREDE_INTERNA * 0.5

## Eixo da parede que separa a garagem do salao.
const DIVISA := 4.6
## Eixo da parede das geladeiras: o fundo do salao e o comeco do corredor.
const FUNDO_SALAO := 10.8
## Eixo da parede entre o corredor e os comodos do fundo.
const CORREDOR_Z1 := 12.4
## Eixos das paredes entre os comodos do fundo, de oeste para leste.
const X_BANHEIRO := 2.9
const X_COPA := 7.7
const X_ESCRITORIO := 11.1

## Pe direito de loja, mais alto que o de casa. E parte do desconforto: o comodo
## e grande demais para uma pessoa so.
const ALTURA := 2.9
## Forro rebaixado dos fundos. Vinte centimetros a menos que o salao, e sao eles
## que fazem o corredor apertar depois da largura do salao.
const ALTURA_SERVICO := 2.68
## A garagem e o comodo mais alto do conjunto, para caber o tambor do portao.
const ALTURA_GARAGEM := KitMercado.ALTURA_GARAGEM
## O ponto mais alto de dentro. E o que o lote reserva (LoteNoMundo.sala).
const ALTURA_MAXIMA := ALTURA_GARAGEM
const ALTURA_PORTA := 2.3

## A porta automatica: duas folhas de vidro de Porta.FOLHA_LARGURA.
const CENTRO_PORTA := 11.0
const VAO_PORTA := Porta.FOLHA_LARGURA * 2.0
const PORTA_X0 := CENTRO_PORTA - VAO_PORTA * 0.5
const PORTA_X1 := CENTRO_PORTA + VAO_PORTA * 0.5
## O vidro do salao. Os pilares das pontas seguram a laje do predio de cima.
const VITRINE_X0 := 5.0
const VITRINE_X1 := 16.85

## O portao da garagem, na mesma calcada, na MESMA distancia da porta por
## dentro e por fora: a fachada e a planta.
const EIXO_PORTAO := 2.3
## Onde as folhas da porta automatica correm: um palmo para dentro do reboco, no
## plano em que nao batem nos montantes ao abrir por tras do vidro fixo.
const FOLHA_Z := 0.06

## Onde o jogador aparece no comodo teleportado, e para onde olha. Entra de
## frente para o corredor central, com a camara fria acesa no fundo: e o quadro
## que a loja existe para dar, e o que puxa o jogador para dentro.
const ENTRADA := Vector3(CENTRO_PORTA, 0.0, 1.1)
const OLHAR := Vector3(CENTRO_PORTA, 1.55, 9.6)

const COR_PAREDE := Color("e2e2dc")
const RODAPE := 0.12

## As tres ilhas de prateleira, em X, e ate onde elas correm em Z.
##
## Nenhuma fica sobre CENTRO_PORTA, e isso e a coisa mais importante desta
## linha. Quem entra cai no eixo da porta, e o que ele tem de ver la no fim e a
## camara fria acesa — nao a lateral de uma gondola a tres metros do nariz. As
## duas primeiras abracam o eixo, entao o corredor central e literalmente
## central: 1,50 m entre elas, e o eixo da porta passa no meio.
##
## Baixas, 1,52 m: abaixo do olho. De qualquer ponto do salao se ve a cabeca de
## quem esta no outro corredor, o que vale para a loja cheia e para o medo.
const ILHAS: Array[float] = [9.83, 12.19, 14.55]
const ILHA_Z0 := 3.0
const ILHA_Z1 := 8.4

# --- balcao -----------------------------------------------------------------

## Balcao do caixa: paralelo a divisa, correndo no eixo Z, com a frente para o
## salao.
##
## A faixa entre ele e a divisa e o lugar de trabalho de uma pessoa, e precisa
## ter largura de gente: 1,10 m do reboco ao fundo do balcao.
const BALCAO_X := 6.14
const BALCAO_Z := 3.9
const BALCAO_COMPRIMENTO := 4.4
## Onde o atendente fica, e onde o cliente para na frente dele. A registradora
## fica na ponta do balcao que da para a porta (KitMercado.balcao), e o cliente
## que chega do corredor encontra o caixa no caminho da saida.
const POSTO_ATENDENTE := Vector3(5.24, 0.0, 2.35)
const POSTO_CLIENTE := Vector3(6.95, 0.0, 2.35)

## O sal da semente do CLIENTE, o que esta do lado de fora do balcao.
##
## Mora aqui em cima, sozinho, porque dois lugares diferentes precisam chegar na
## mesma pessoa a partir dele: `_gente`, que poe o corpo dela no salao, e
## `_atendimento`, que poe a carteira dela em cima do balcao. O registro civil e
## funcao pura da semente, entao os dois recebem a mesma ficha sem trocar uma
## palavra — desde que usem o mesmo numero. Escrito solto nos dois lugares, ele
## divergiria no primeiro ajuste e a carteira passaria a ser de um estranho.
const SAL_DO_CLIENTE := 733
const SAL_DO_ATENDENTE := 611

## A faixa de idade do cliente. Vale a mesma amarracao do sal.
const IDADE_CLIENTE := Vector2i(18, 26)

# --- servico ----------------------------------------------------------------

const LARGURA_PORTA_INTERNA := 0.9
## Porta de servico, na parede das geladeiras, logo depois do fim do balcao.
const PORTA_SERVICO := 5.7
## Vao aberto entre o corredor e a garagem. Nao leva folha de proposito: e o
## caminho que o funcionario faz vinte vezes por turno com as maos ocupadas.
const VAO_GARAGEM := Vector2(1.6, 3.0)
## Portas do fundo, uma por comodo.
const PORTA_BANHEIRO := 1.4
const PORTA_COPA := 5.3
const PORTA_ESCRITORIO := 9.4
## O estoque seco nao tem porta: e onde o carrinho entra.
const VAO_ESTOQUE := Vector2(12.2, 13.6)

const VERDE := KitMercado.VERDE_SERVICO


## `no_mundo`: a loja que existe na rua, atras da propria vitrine. Sem ele, o
## comodo teleportado de sempre, com a frente fosca.
static func construir(semente: int, no_mundo: bool = false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente

	var sup: Dictionary = {}
	var props: Array[Dictionary] = []
	var colisao: Array[Dictionary] = []

	_casca(sup, colisao, no_mundo)
	_frente(sup, colisao, props, no_mundo)
	_gondolas(sup, colisao, rng)
	# O produto, um por um (PLANO_MERCADO_AAA, F2). O planograma e montado aqui,
	# na thread, e viaja no prop: a PrateleiraViva so desenha.
	props.append({
		"tipo": "prateleira_viva",
		"semente": semente,
		"planograma": Planograma.montar(semente),
	})
	_balcao(sup, colisao, props, rng, semente)
	_salao(sup, colisao, props)
	_fundo(sup, colisao, props)
	_luzes(sup, props, rng)
	_garagem(sup, colisao, props, rng, no_mundo)
	_corredor(sup, colisao, props)
	_banheiro(sup, colisao, props)
	_copa(sup, colisao, props, rng)
	var tela := _escritorio(sup, colisao, props)
	_estoque(sup, colisao, props)
	_mercadoria(props, rng)
	_gente(props, semente, no_mundo)

	var tris := 0
	for mat: StringName in sup:
		tris += PSXMesh.dados_triangulos(sup[mat])

	var d := {
		"superficies": sup, "props": props, "colisao": colisao,
		"triangulos": tris, "entrada": ENTRADA, "olhar": OLHAR,
		# As quatro cameras do circuito e a tela onde elas aparecem, para a F7
		# pendurar o olho de cada uma. As mesmas posicoes que a geometria usou.
		"cftv": cameras(),
		"tela_cftv": tela,
		"porta_dentro": Vector3(CENTRO_PORTA, 0.0, 0.9),
		"so_caminho": _so_caminho() if no_mundo else [],
	}
	if no_mundo:
		# O ar de dentro na rua: a nevoa e a da calcada, empurrada para longe
		# (FogPreset.ar_da_rua). O branco chapado sem nevoa nenhuma do comodo
		# teleportado apagaria a cidade do outro lado do vidro.
		d["ambiente"] = "res://resources/fog/fog_mercado_rua.tres"
		return d

	# A loja teleportada tem ambiente proprio: branco, chapado e sem sombra. E
	# metade do efeito do comodo, e nao daria para conseguir so com lampada.
	d["ambiente"] = "res://resources/fog/fog_mercado.tres"
	d["saida"] = {
		"pos": Vector3(CENTRO_PORTA, 1.0, 0.55),
		"tamanho": Vector3(2.4, 2.0, 1.1),
		# Porta automatica: as duas folhas correm para os lados. Porta de loja
		# que gira na dobradica entrega na hora que o lugar nao e uma loja.
		"deslizante": {
			"centro": Vector3(CENTRO_PORTA, 0.0, FOLHA_Z),
			"largura": VAO_PORTA * 0.5,
			"altura": Porta.FOLHA_ALTURA,
			"giro": 0.0,
			"curso": VAO_PORTA * 0.46,
		},
	}
	return d


## As quatro cameras do circuito fechado: onde estao e para onde olham, em
## coordenada de planta. Publica porque o monitor (F7) e o teste leem a mesma
## lista que a parede usa para pendurar as caixas.
static func cameras() -> Array[Dictionary]:
	return [
		# O caixa visto de cima, por tras de quem paga: e a camera que pega a mao
		# na gaveta.
		{"nome": "CAIXA", "pos": Vector3(8.2, 2.66, 0.16), "olhar": Vector3(6.2, 1.0, 3.2)},
		# A porta, vista de dentro: quem entra aparece de frente.
		{"nome": "ENTRADA", "pos": Vector3(16.84, 2.62, 9.7), "olhar": Vector3(11.0, 1.2, 0.8)},
		# O corredor das geladeiras, de ponta a ponta.
		{"nome": "GELADEIRA", "pos": Vector3(4.95, 2.62, 10.4), "olhar": Vector3(15.0, 1.1, 9.3)},
		# O deposito e o portao: a camera que ve o caminhao.
		{"nome": "DEPOSITO", "pos": Vector3(4.2, 2.7, 10.4), "olhar": Vector3(2.3, 0.8, 1.0)},
	]


# --- paredes ------------------------------------------------------------------

## Uma face de parede de `a` a `b`, virada para o ponto `dentro`.
##
## A `KitModular.parede_com_vaos` poe a normal de um lado fixo do sentido de
## percurso, e errar o sentido deixa a face virada para o lado de onde ninguem
## olha — a parede some de dentro e ninguem acusa. Aqui quem decide e o comodo:
## a face olha para `dentro` qualquer que seja a ordem dos pontos.
##
## `vaos` vem em coordenada ABSOLUTA do eixo em que a parede corre (X ou Z da
## planta), e nao em distancia a partir de `a`: e o numero que esta na planta
## la em cima, e o que se confere de olho.
static func _face(sup: Dictionary, material: StringName, a: Vector2, b: Vector2,
		dentro: Vector2, altura: float, vaos: Array = [], cor: Color = COR_PAREDE,
		rodape: float = 0.0, altura_vao: float = ALTURA_PORTA) -> void:
	var dir := (b - a).normalized()
	if Vector2(-dir.y, dir.x).dot(dentro - (a + b) * 0.5) < 0.0:
		var troca := a
		a = b
		b = troca
	var em_x := absf(b.x - a.x) > absf(b.y - a.y)
	var inicio := a.x if em_x else a.y
	var relativos: Array = []
	for v: Vector2 in vaos:
		var t0 := absf(v.x - inicio)
		var t1 := absf(v.y - inicio)
		relativos.append(Vector2(minf(t0, t1), maxf(t0, t1)))
	KitModular.parede_com_vaos(sup, material, a, b, altura, relativos, altura_vao,
		cor, rodape)


## O corpo de uma parede reta, com os vaos abertos. `a` e `b` no eixo dela.
static func _muro(colisao: Array[Dictionary], a: Vector2, b: Vector2,
		espessura: float, altura: float, vaos: Array = []) -> void:
	var em_x := absf(b.x - a.x) > absf(b.y - a.y)
	var de := minf(a.x, b.x) if em_x else minf(a.y, b.y)
	var ate := maxf(a.x, b.x) if em_x else maxf(a.y, b.y)
	var fixo := a.y if em_x else a.x
	var ordenados: Array = vaos.duplicate()
	ordenados.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var cursor := de
	for v: Vector2 in ordenados:
		if v.x > cursor:
			_trecho(colisao, em_x, fixo, cursor, v.x, espessura, altura)
		cursor = maxf(cursor, v.y)
	if cursor < ate:
		_trecho(colisao, em_x, fixo, cursor, ate, espessura, altura)


static func _trecho(colisao: Array[Dictionary], em_x: bool, fixo: float,
		de: float, ate: float, espessura: float, altura: float) -> void:
	var comp := ate - de
	if comp < 0.04:
		return
	var meio := (de + ate) * 0.5
	colisao.append({
		"tamanho": Vector3(comp, altura, espessura) if em_x
			else Vector3(espessura, altura, comp),
		"pos": Vector3(meio, altura * 0.5, fixo) if em_x
			else Vector3(fixo, altura * 0.5, meio),
	})


## O piso dentro da espessura de uma parede, sob um vao. Sem ele, olhando para
## baixo ao cruzar uma porta, o chao abre uma fresta de vinte centimetros para
## o vazio entre as duas faces.
static func _soleira(sup: Dictionary, material: StringName, x0: float, x1: float,
		z0: float, z1: float, cor: Color) -> void:
	KitModular.chao(sup, material, Vector3(x0, 0.0, z0), Vector2(x1 - x0, z1 - z0),
		PSXMesh.MAX_QUAD_M, cor)


## Revestimento de um vao aberto (sem folha) numa parede de dentro: as duas
## ombreiras e a testa, cobrindo a espessura. Mesmo motivo da soleira, de lado e
## em cima.
static func _revestir_vao(sup: Dictionary, material: StringName, em_x: bool,
		fixo: float, de: float, ate: float, altura: float, cor: Color) -> void:
	for lado: float in [de, ate]:
		KitModular.caixa_cor(sup, material,
			Vector3(lado, altura * 0.5, fixo) if em_x else Vector3(fixo, altura * 0.5, lado),
			Vector3(0.04, altura, PAREDE_INTERNA + 0.02) if em_x
				else Vector3(PAREDE_INTERNA + 0.02, altura, 0.04), cor)
	KitModular.caixa_cor(sup, material,
		Vector3((de + ate) * 0.5, altura + 0.02, fixo) if em_x
			else Vector3(fixo, altura + 0.02, (de + ate) * 0.5),
		Vector3(ate - de + 0.04, 0.04, PAREDE_INTERNA + 0.02) if em_x
			else Vector3(PAREDE_INTERNA + 0.02, 0.04, ate - de + 0.04), cor)


## Teto de um retangulo da planta, virado para baixo.
static func _teto(sup: Dictionary, material: StringName, canto: Vector2,
		tamanho: Vector2, altura: float, cor: Color = Color.WHITE) -> void:
	var dados := PSXMesh.plane_dados(tamanho)
	if not sup.has(material):
		sup[material] = PSXMesh.dados_vazios()
	PSXMesh.acumular_tingido(sup[material], dados,
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
			Vector3(canto.x + tamanho.x * 0.5, altura, canto.y + tamanho.y * 0.5)),
		cor)


# --- casca ------------------------------------------------------------------

static func _casca(sup: Dictionary, colisao: Array[Dictionary], no_mundo: bool) -> void:
	var sx0 := DIVISA + MEIA
	var sz1 := FUNDO_SALAO - MEIA
	var gx1 := DIVISA - MEIA
	var cz0 := FUNDO_SALAO + MEIA
	var cz1 := CORREDOR_Z1 - MEIA
	var fz0 := CORREDOR_Z1 + MEIA

	# --- salao ---
	KitModular.chao(sup, &"mercado_piso", Vector3(sx0, 0.0, 0.0),
		Vector2(LARGURA - sx0, sz1))
	_teto(sup, &"mercado_teto", Vector2(sx0, 0.0), Vector2(LARGURA - sx0, sz1), ALTURA)
	_face(sup, &"reboco", Vector2(LARGURA, 0.0), Vector2(LARGURA, sz1),
		Vector2(10.0, 5.0), ALTURA, [], COR_PAREDE, RODAPE)
	_face(sup, &"reboco", Vector2(sx0, sz1), Vector2(LARGURA, sz1), Vector2(10.0, 5.0),
		ALTURA, [_porta(PORTA_SERVICO)], COR_PAREDE, RODAPE)
	_face(sup, &"reboco", Vector2(sx0, 0.0), Vector2(sx0, sz1), Vector2(10.0, 5.0),
		ALTURA, [], COR_PAREDE, RODAPE)

	# --- garagem ---
	KitModular.chao(sup, &"concreto", Vector3(0.0, 0.0, 0.0), Vector2(gx1, sz1),
		PSXMesh.MAX_QUAD_M, KitMercado.PISO_SERVICO)
	_teto(sup, &"concreto", Vector2(0.0, 0.0), Vector2(gx1, sz1), ALTURA_GARAGEM,
		Color("585a56"))
	var concreto := Color("8e918a")
	_face(sup, &"concreto_sujo", Vector2(0.0, 0.0), Vector2(0.0, sz1), Vector2(2.0, 5.0),
		ALTURA_GARAGEM, [], concreto)
	_face(sup, &"concreto_sujo", Vector2(gx1, 0.0), Vector2(gx1, sz1), Vector2(2.0, 5.0),
		ALTURA_GARAGEM, [], concreto)
	_face(sup, &"concreto_sujo", Vector2(0.0, sz1), Vector2(gx1, sz1), Vector2(2.0, 5.0),
		ALTURA_GARAGEM, [VAO_GARAGEM], concreto)

	# --- corredor ---
	KitModular.chao(sup, &"piso_ceramico", Vector3(0.0, 0.0, cz0),
		Vector2(LARGURA, cz1 - cz0), PSXMesh.MAX_QUAD_M, Color("9a9c94"))
	_teto(sup, &"mercado_teto", Vector2(0.0, cz0), Vector2(LARGURA, cz1 - cz0),
		ALTURA_SERVICO, Color("c0c2bc"))
	var meio_corredor := Vector2(8.0, (cz0 + cz1) * 0.5)
	_face(sup, &"reboco", Vector2(0.0, cz0), Vector2(LARGURA, cz0), meio_corredor,
		ALTURA_SERVICO, [VAO_GARAGEM, _porta(PORTA_SERVICO)], VERDE, RODAPE)
	_face(sup, &"reboco", Vector2(0.0, cz1), Vector2(LARGURA, cz1), meio_corredor,
		ALTURA_SERVICO, [_porta(PORTA_BANHEIRO), _porta(PORTA_COPA),
			_porta(PORTA_ESCRITORIO), VAO_ESTOQUE], VERDE, RODAPE)
	_face(sup, &"reboco", Vector2(0.0, cz0), Vector2(0.0, cz1), meio_corredor,
		ALTURA_SERVICO, [], VERDE, RODAPE)
	_face(sup, &"reboco", Vector2(LARGURA, cz0), Vector2(LARGURA, cz1), meio_corredor,
		ALTURA_SERVICO, [], VERDE, RODAPE)

	# O chao sob os vaos das paredes de dentro, e o revestimento dos dois vaos
	# que nao levam folha. As portas tem o marco (KitMercado.batente).
	_soleira(sup, &"concreto", VAO_GARAGEM.x, VAO_GARAGEM.y, sz1, cz0,
		KitMercado.PISO_SERVICO)
	_soleira(sup, &"piso_ceramico", PORTA_SERVICO - 0.45, PORTA_SERVICO + 0.45, sz1, cz0,
		Color("9a9c94"))
	for x: float in [PORTA_BANHEIRO, PORTA_COPA, PORTA_ESCRITORIO]:
		_soleira(sup, &"piso_ceramico", x - 0.45, x + 0.45, cz1, fz0, Color("9a9c94"))
	_soleira(sup, &"concreto", VAO_ESTOQUE.x, VAO_ESTOQUE.y, cz1, fz0,
		KitMercado.PISO_SERVICO)
	_revestir_vao(sup, &"concreto_sujo", true, FUNDO_SALAO, VAO_GARAGEM.x,
		VAO_GARAGEM.y, ALTURA_PORTA, concreto)
	_revestir_vao(sup, &"reboco", true, CORREDOR_Z1, VAO_ESTOQUE.x, VAO_ESTOQUE.y,
		ALTURA_PORTA, VERDE)

	# --- o corpo das paredes ---
	var alto := ALTURA_MAXIMA
	# Externas: a espessura inteira fica do lado de fora do reboco.
	_muro(colisao, Vector2(-PAREDE * 0.5, -PAREDE), Vector2(-PAREDE * 0.5, FUNDO + PAREDE),
		PAREDE, alto)
	_muro(colisao, Vector2(LARGURA + PAREDE * 0.5, -PAREDE),
		Vector2(LARGURA + PAREDE * 0.5, FUNDO + PAREDE), PAREDE, alto)
	_muro(colisao, Vector2(-PAREDE, FUNDO + PAREDE * 0.5),
		Vector2(LARGURA + PAREDE, FUNDO + PAREDE * 0.5), PAREDE, alto)
	# De dentro.
	_muro(colisao, Vector2(DIVISA, 0.0), Vector2(DIVISA, FUNDO_SALAO), PAREDE_INTERNA, alto)
	_muro(colisao, Vector2(0.0, FUNDO_SALAO), Vector2(LARGURA, FUNDO_SALAO),
		PAREDE_INTERNA, alto, [VAO_GARAGEM, _porta(PORTA_SERVICO)])
	_muro(colisao, Vector2(0.0, CORREDOR_Z1), Vector2(LARGURA, CORREDOR_Z1),
		PAREDE_INTERNA, alto, [_porta(PORTA_BANHEIRO), _porta(PORTA_COPA),
			_porta(PORTA_ESCRITORIO), VAO_ESTOQUE])
	for x: float in [X_BANHEIRO, X_COPA, X_ESCRITORIO]:
		_muro(colisao, Vector2(x, CORREDOR_Z1), Vector2(x, FUNDO), PAREDE_INTERNA, alto)

	# Piso e forro invisiveis, para o jogador nao cair nem subir. Cobrem o lote
	# inteiro, ate a face da fachada: alem dela ja e calcada, e um degrau de
	# colisao ali viraria um ressalto no passeio.
	colisao.append({"tamanho": Vector3(LARGURA + PAREDE * 2.0, 0.3, FUNDO + PAREDE * 2.0),
		"pos": Vector3(LARGURA * 0.5, -0.15, FUNDO * 0.5)})
	colisao.append({"tamanho": Vector3(LARGURA + PAREDE * 2.0, 0.3, FUNDO + PAREDE * 2.0),
		"pos": Vector3(LARGURA * 0.5, ALTURA_MAXIMA + 0.15, FUNDO * 0.5)})


## O que a malha de navegacao precisa saber da frente e o corpo nao pode ter.
##
## Na rua o vidro, os pilares e o portao sao do predio (PredioMercado), com
## colisao propria que existe com o chunk. A CasaViva assa o caminho so desta
## planta, e sem eles aqui a malha abria a fachada inteira: o freguês tracava
## rota ATRAVES da vitrine e ficava esfregando no vidro. Mas eles nao podem ir
## para a `colisao`: o bloco do portao fechado impediria o jogador de sair pela
## garagem com o portao aberto. Viram so caminho — a garagem nao e rota de
## freguês de qualquer jeito.
static func _so_caminho() -> Array[Dictionary]:
	var caixas: Array[Dictionary] = []
	var vazio: Dictionary = {}
	KitMercado.vitrine_loja(vazio, caixas, Transform3D.IDENTITY, VITRINE_X0, VITRINE_X1,
		PORTA_X0, PORTA_X1, &"vitrine_loja", Color.WHITE, PI, true)
	# Os pilares e o portao, fechados de ponta a ponta.
	for tr: Vector2 in [Vector2(-PAREDE, VITRINE_X0), Vector2(VITRINE_X1, LARGURA + PAREDE)]:
		caixas.append({"tamanho": Vector3(tr.y - tr.x, ALTURA, PAREDE),
			"pos": Vector3((tr.x + tr.y) * 0.5, ALTURA * 0.5, -PAREDE * 0.5)})
	# O caminho de quem entra da calcada: o passeio na frente da porta, um degrau
	# abaixo do piso, e o degrau da soleira. A calcada e o degrau de verdade sao
	# do chunk; sem eles aqui a malha terminava na parede e ninguem entrava.
	caixas.append({"tamanho": Vector3(3.4, 0.1, 2.0),
		"pos": Vector3(CENTRO_PORTA, KitMercado.CALCADA_Y - 0.05, -PAREDE - 1.0)})
	# A rampa da porta, na mesma escada que o corpo pisa (PredioMercado).
	caixas.append_array(PredioMercado.degraus_da_rampa(CENTRO_PORTA,
		PredioMercado.DEGRAU.x, -PAREDE - PredioMercado.DEGRAU.y, KitMercado.CALCADA_Y,
		-PAREDE, 0.0))
	return caixas


## O vao de uma porta interna, centrada em `centro`, no eixo da parede.
static func _porta(centro: float) -> Vector2:
	return Vector2(centro - LARGURA_PORTA_INTERNA * 0.5, centro + LARGURA_PORTA_INTERNA * 0.5)


# --- a frente -----------------------------------------------------------------

## A parede da frente vista de dentro: a faixa cega acima do vidro, o reboco da
## garagem em volta do portao e, no comodo teleportado, a vitrine inteira.
##
## Na rua, o vidro, os montantes e os pilares sao do predio (PredioMercado):
## precisam existir com o chunk, quando a loja ainda nem foi montada, e sao
## vistos dos dois lados. O que so se ve de DENTRO fica aqui.
static func _frente(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], no_mundo: bool) -> void:
	var sx0 := DIVISA + MEIA
	var topo_vidro := KitMercado.VIDRO_Y.y + 0.1
	# Faixa cega do salao, do alto da travessa ate o forro.
	KitModular.parede_livre(sup, &"reboco",
		Vector3((sx0 + LARGURA) * 0.5, (topo_vidro + ALTURA) * 0.5, 0.0),
		Vector2(LARGURA - sx0, ALTURA - topo_vidro), 0.0, COR_PAREDE)
	# Os pedacos de reboco das duas pontas do vidro, do piso a faixa: o pilar
	# visto de dentro.
	for tr: Vector2 in [Vector2(sx0, VITRINE_X0), Vector2(VITRINE_X1, LARGURA)]:
		KitModular.parede_livre(sup, &"reboco",
			Vector3((tr.x + tr.y) * 0.5, topo_vidro * 0.5, 0.0),
			Vector2(tr.y - tr.x, topo_vidro), 0.0, COR_PAREDE)
	# A garagem por dentro: reboco em volta do vao do portao, ate a verga.
	var gx1 := DIVISA - MEIA
	var vao := Vector2(EIXO_PORTAO - KitMercado.LARGURA_PORTAO * 0.5,
		EIXO_PORTAO + KitMercado.LARGURA_PORTAO * 0.5)
	_face(sup, &"concreto_sujo", Vector2(0.0, 0.0), Vector2(gx1, 0.0), Vector2(2.0, 5.0),
		ALTURA_GARAGEM, [vao], Color("8e918a"), 0.0, KitMercado.ALTURA_PORTAO)
	# O operador da porta automatica: a caixa de aluminio sobre o vao, do lado
	# de dentro, que e onde o motor e a correia moram. As folhas correm por baixo
	# dela e somem atras do vidro fixo.
	KitModular.caixa_cor(sup, &"metal",
		Vector3(CENTRO_PORTA, Porta.FOLHA_ALTURA + 0.13, FOLHA_Z + 0.02),
		Vector3(VAO_PORTA * 2.0 + 0.1, 0.22, 0.2), KitMercado.ALUMINIO)
	KitModular.caixa_cor(sup, &"mercado_secao",
		Vector3(CENTRO_PORTA + VAO_PORTA * 0.8, Porta.FOLHA_ALTURA + 0.08, FOLHA_Z + 0.125),
		Vector3(0.03, 0.02, 0.01), Color("60e070"))
	# Tapete na porta. Escuro contra o piso quase branco, marca a soleira sem
	# precisar de degrau.
	KitMercado.tapete_entrada(sup, Vector3(CENTRO_PORTA, 0.0, 0.95), Vector2(2.2, 1.3), 0.0)

	if no_mundo:
		return

	# --- so no comodo teleportado ---
	# A vitrine inteira, com vidro fosco aceso. O interior vive dois mil metros
	# acima da cidade, e vidro transparente ali mostraria o vazio: painel branco
	# aceso e o que se ve mesmo, de dentro de uma loja iluminada olhando para uma
	# rua com nevoa.
	KitMercado.vitrine_loja(sup, colisao, Transform3D.IDENTITY, VITRINE_X0, VITRINE_X1,
		PORTA_X0, PORTA_X1, &"mercado_vidro", Color("dfeaee"), 0.0, true)
	# Pilares, vistos de dentro.
	for tr: Vector2 in [Vector2(sx0 - 0.2, VITRINE_X0), Vector2(VITRINE_X1, LARGURA)]:
		KitModular.solido(colisao, Vector3((tr.x + tr.y) * 0.5, ALTURA * 0.5, -PAREDE * 0.5),
			Vector3(tr.y - tr.x, ALTURA, PAREDE))
	# O portao, fechado para sempre: o batente aqui, e a folha no prop que sobe.
	var eixo := Vector3(EIXO_PORTAO, 0.0, KitMercado.VIDRO_Z)
	KitMercado.portao_garagem(sup, colisao, eixo, KitMercado.LARGURA_PORTAO, 0.0)
	for tr: Vector2 in [Vector2(-PAREDE, vao.x), Vector2(vao.y, sx0 - 0.2)]:
		KitModular.solido(colisao, Vector3((tr.x + tr.y) * 0.5, ALTURA_GARAGEM * 0.5,
			-PAREDE * 0.5), Vector3(tr.y - tr.x, ALTURA_GARAGEM, PAREDE))
	props.append({
		"tipo": "portao_garagem",
		"pos": Vector3(EIXO_PORTAO, 1.1, 0.9),
		"tamanho": Vector3(KitMercado.LARGURA_PORTAO, 2.2, 1.5),
		"centro": eixo,
		"largura": KitMercado.LARGURA_PORTAO,
		"giro": 0.0,
		"rotulo": "Abrir o portao",
		# Onde o jogador reaparece na rua, no referencial da PORTA: o portao fica
		# EIXO_PORTAO - CENTRO_PORTA metros ao longo da fachada, que na rua corre
		# ao contrario da planta (LoteNoMundo). A mesma distancia dentro e fora,
		# porque a fachada agora e a planta.
		"deslocamento": Vector3(CENTRO_PORTA - EIXO_PORTAO, 0.0, 1.3),
	})


# --- corredores -------------------------------------------------------------

static func _gondolas(sup: Dictionary, colisao: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	var comprimento := ILHA_Z1 - ILHA_Z0
	var z := (ILHA_Z0 + ILHA_Z1) * 0.5

	# As tres ilhas correm no eixo Z, alinhadas com quem entra pela porta.
	for i in ILHAS.size():
		KitMercado.gondola(sup, colisao, Vector3(ILHAS[i], 0.0, z), comprimento,
			PI * 0.5, i)

	# Parede leste: prateleira alta virada para dentro, quase de ponta a ponta.
	KitMercado.gondola_parede(sup, colisao, Vector3(LARGURA - 0.25, 0.0, 5.4),
		7.6, -PI * 0.5, rng.randi() % KitMercado.VARIANTES)
	# Divisa, entre o fim do balcao e a porta de servico.
	KitMercado.gondola_parede(sup, colisao, Vector3(DIVISA + MEIA + 0.25, 0.0, 8.9),
		2.6, PI * 0.5, rng.randi() % KitMercado.VARIANTES)

	# Cartaz de corredor sobre a boca de cada corredor, do lado da porta. A cor
	# agora vem da propria faixa do atlas, uma por ilha: tingir por vertice
	# multiplicava a palavra junto e apagava o contraste da letra.
	for i in ILHAS.size():
		KitMercado.placa_corredor(sup, ALTURA, ILHAS[i], ILHA_Z0 - 0.5, 0.0,
			Color.WHITE, i)


# --- o caixa ------------------------------------------------------------------

static func _balcao(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], rng: RandomNumberGenerator, semente: int) -> void:
	var tampo := KitMercado.ALTURA_BALCAO + 0.05
	# Frente para o salao (+X). A registradora cai na ponta de -Z, a da porta.
	KitMercado.balcao(sup, colisao, Vector3(BALCAO_X, 0.0, BALCAO_Z),
		BALCAO_COMPRIMENTO, PI * 0.5)

	# A estufa de salgados, na ponta de tras do tampo: a unica luz quente do
	# salao. Uma fonte alaranjada num canto de sala toda branca marca o lugar.
	var luz_quente := KitSalao.estufa(sup, colisao,
		Vector3(BALCAO_X, KitMercado.ALTURA_BALCAO + 0.04, 5.55), PI * 0.5)
	props.append({
		"tipo": "lampada", "pos": luz_quente + Vector3(0.4, 0.0, 0.0),
		"padrao": Lampada.Padrao.ESTAVEL, "semente": rng.randi(),
		"cor": Color("ffcf8a"), "energia": 1.1, "alcance": 2.8, "facho": false,
	})

	# O computador e de quem atende: tela e teclado virados para dentro do
	# balcao. Virado para o salao (como estava ate a F2) o atendente olhava as
	# costas do tubo, e o jogador reparou antes de qualquer teste.
	var alvo := KitMercado.computador(sup, colisao,
		Vector3(BALCAO_X - 0.04, tampo, 3.55), -PI * 0.5)
	props.append({
		"tipo": "computador",
		"pos": alvo,
		"tamanho": Vector3(0.9, 0.9, 0.8),
		"rotulo": "Consultar CPF ou nome",
	})
	_atendimento(sup, colisao, props, alvo, semente)

	# Baleiro na frente da registradora, do lado do cliente.
	KitMercado.expositor_balas(sup, colisao, Vector3(BALCAO_X + 0.12, tampo, 4.35),
		PI * 0.5)
	# A parede de cigarro, atras de quem atende.
	KitMercado.expositor_cigarro(sup, Vector3(DIVISA + MEIA + 0.1, 1.28, 3.2), 2.4,
		PI * 0.5)
	# A camera do caixa e o aviso de que ela existe. So a caixa aqui: o olho de
	# verdade e da F7 (MercadoBuilder.cameras).
	for cam: Dictionary in cameras():
		var p: Vector3 = cam["pos"]
		var o: Vector3 = cam["olhar"]
		KitMercado.camera_cftv(sup, p, atan2(o.x - p.x, o.z - p.z))


## A carteira que o cliente largou no balcao, e o leitor ao lado dela.
##
## Os tres objetos do atendimento ficam em linha sobre o tampo, na ordem em que
## o gesto acontece: a carteira do lado do cliente, o leitor no meio, o monitor
## do lado do atendente. Nao e arrumacao — e a instrucao. Um jogador que nunca
## viu isto antes le a sequencia inteira olhando para o balcao, sem uma palavra
## na tela, porque a ordem espacial e a ordem temporal.
##
## `monitor` chega pronto de quem montou o computador: e para onde a camera vira
## quando a leitura termina, e tem de ser a MESMA posicao que o prop do
## computador usa.
static func _atendimento(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], monitor: Vector3, semente: int) -> void:
	var tampo := KitMercado.ALTURA_BALCAO + 0.05
	# Do lado do cliente, torta. Ver KitMercado.identidade_no_balcao: os oito
	# graus sao o que separa "documento colocado" de "documento jogado".
	var carteira := Vector3(BALCAO_X + 0.15, tampo, 2.9)
	KitMercado.identidade_no_balcao(sup, carteira, PI * 0.5 + 0.14)

	var leitor := Vector3(BALCAO_X - 0.06, tampo - 0.02, 2.6)
	var luz := KitMercado.leitor_codigo(sup, colisao, leitor, -PI * 0.5)

	props.append({
		"tipo": "atendimento",
		# A area de acionamento e bem maior que o cartao: doze centimetros de
		# documento a um metro e meio de distancia dao tres pixels de mira, e
		# obrigar o jogador a acertar tres pixels nao e dificuldade, e defeito.
		"pos": carteira + Vector3(0.0, 0.12, 0.0),
		"tamanho": Vector3(0.5, 0.4, 0.4),
		"leitor": leitor + Vector3(0.0, 0.16, 0.0),
		"tamanho_leitor": Vector3(0.5, 0.45, 0.4),
		"luz": luz,
		"monitor": monitor,
		# O MESMO par que `_gente` usa para o cliente. Ver SAL_DO_CLIENTE.
		"semente": semente + SAL_DO_CLIENTE,
		"idade_min": IDADE_CLIENTE.x,
		"idade_max": IDADE_CLIENTE.y,
	})


# --- o salao ------------------------------------------------------------------

static func _salao(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary]) -> void:
	# Maquina de cafe no fim do balcao, de frente para o salao: quem pega o cafe
	# esta a um passo do caixa.
	# A maquina de cafe agora e a mesma da copa: vao do copo aberto, bandeja de
	# pingo e moedor. A antiga era uma caixa de `metal` com uma placa acesa.
	KitServico.maquina_cafe_de_piso(sup, colisao, Vector3(6.35, 0.0, 7.1), PI * 0.5)

	# Revistas encostadas no vidro, do outro lado de quem entra. E onde a loja de
	# verdade poe: quem le fica visivel da calcada.
	KitMercado.revisteiro(sup, colisao, Vector3(14.4, 0.0, 0.46), 3.4, 0.0)
	# O freezer de sorvete, tambem no vidro, do lado do caixa.
	KitMercado.freezer_sorvete(sup, colisao, Vector3(7.75, 0.0, 0.62), 1.5, 0.0)
	KitMercado.cestas(sup, colisao, Vector3(9.35, 0.0, 1.05), 0.2)
	KitSalao.lixeira(sup, colisao, Vector3(12.75, 0.0, 1.35), -0.15)
	# O espelho da quina que o caixa nao enxerga: o fundo da parede leste.
	KitMercado.espelho_convexo(sup, Vector3(16.62, 2.45, 10.3), -PI * 0.75)

	# Telefone da loja. Loja de conveniencia acesa a noite e o lugar mais seguro
	# do bairro, entao e onde o jogo deixa salvar. No piso: o aparelho tem o
	# proprio pe (PontoDeSave), e a 16 cm do chao ele flutuava.
	props.append({
		"tipo": "save",
		"pos": Vector3(LARGURA - 0.5, 0.0, 1.05),
		"giro": -PI * 0.5,
		"local": "Telefone da loja HIKARI",
	})


# --- fundo do salao -----------------------------------------------------------

static func _fundo(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary]) -> void:
	var x0 := 6.6
	var comprimento := LARGURA - x0
	var luzes := KitMercado.geladeira_parede(sup, colisao,
		Vector3(x0 + comprimento * 0.5, 0.0, FUNDO_SALAO - MEIA - 0.36), comprimento,
		PI, Planograma.PORTAS_GELADEIRA)

	# Duas luzes para catorze portas, e nao uma por porta: catorze luzes so na
	# camara fria gastariam a loja inteira. Quem brilha porta a porta sao os
	# tubos atras dos montantes, que sao superficie e nao luz.
	for k in [3, 10]:
		props.append({
			"tipo": "lampada", "pos": luzes[k],
			"padrao": Lampada.Padrao.ESTAVEL, "semente": 8100 + k * 37,
			"cor": Color("cfe4ff"), "energia": 1.6, "alcance": 7.0,
			"facho": false,
		})


# --- luz --------------------------------------------------------------------

static func _luzes(sup: Dictionary, props: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	# Calhas correndo sobre os corredores. Sao quatro e nao uma, porque o que
	# define a loja e a luz sem direcao: com uma fonte so voltariam as sombras
	# longas que o comodo inteiro existe para nao ter.
	var linhas: Array[float] = [8.0, CENTRO_PORTA, 13.37, 15.73]
	for i in linhas.size():
		var pos := KitMercado.calha(sup, ALTURA, linhas[i], 5.4, 7.0, PI * 0.5)
		# A do fundo a leste falha. Uma so, e longe da porta: numa loja em que
		# tudo funciona, a unica coisa que nao funciona fica sendo o assunto.
		var padrao := Lampada.Padrao.ESTAVEL
		if i == linhas.size() - 1:
			padrao = Lampada.Padrao.FLUORESCENTE
		props.append({
			"tipo": "lampada", "pos": pos, "padrao": padrao,
			"semente": rng.randi(), "cor": Color("f4faf6"),
			"energia": 2.4, "alcance": 9.0, "facho": false,
		})

	# Calha sobre o balcao, correndo junto com ele.
	var frente := KitMercado.calha(sup, ALTURA, BALCAO_X - 0.4, BALCAO_Z, 4.4, PI * 0.5)
	props.append({
		"tipo": "lampada", "pos": frente, "padrao": Lampada.Padrao.ESTAVEL,
		"semente": rng.randi(), "cor": Color("f4faf6"),
		"energia": 2.2, "alcance": 7.0, "facho": false,
	})


# --- garagem ------------------------------------------------------------------

## Garagem e deposito, num comodo so, da calcada ate o corredor.
static func _garagem(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], rng: RandomNumberGenerator, no_mundo: bool) -> void:
	var gx1 := DIVISA - MEIA
	# Estante de estoque na parede oeste, de ponta a ponta. E o fundo do quadro
	# para quem espia pelo vao do corredor: vazia, a garagem leria como sala
	# inacabada em vez de deposito.
	# Carga em tres dimensoes, e nao a imagem pregada de `estante_estoque`: esta
	# estante e vista de tres quartos (captura a09), e de tres quartos a imagem
	# chapada nao tem espessura nenhuma.
	KitEstoque.estante_carregada(sup, colisao, Vector3(0.38, 0.0, 6.6), 4.6,
		PI * 0.5, 71301)

	# Paletes com a entrega da noite. Alturas diferentes de proposito: duas
	# pilhas iguais leem como copia colada.
	# O caminho do vao do corredor ate o portao fica livre: quem desce a
	# garagem com o carrinho vai em linha reta, rente a estante.
	KitEstoque.palete(sup, colisao, Vector3(2.95, 0.0, 8.3), 0.12, 71311, 3)
	KitMercado.palete_bebida(sup, colisao, Vector3(3.75, 0.0, 5.9), 3, -0.2,
		Color("b3322c"))
	KitMercado.carrinho_carga(sup, colisao, Vector3(4.15, 0.0, 3.4), -PI * 0.5)
	KitMercado.tambor(sup, colisao, Vector3(0.5, 0.0, 10.2), Color("7a5a3c"), 0.4)
	KitMercado.sacos_lixo(sup, colisao, Vector3(0.62, 0.0, 3.55), 3, 0.6)
	KitMercado.grade_ar(sup, Vector3(gx1 - 0.06, 2.6, 5.0), Vector2(0.9, 0.6), -PI * 0.5)

	# A botoeira do portao, na parede ao lado do vao, na altura da mao.
	var botoeira := Vector3(gx1 - 0.05, 1.35, 0.55)
	KitMercado.botoeira(sup, botoeira, -PI * 0.5)
	if no_mundo:
		# Na rua o portao abre de verdade, e quem abre e esta caixa: a folha e do
		# predio (PortaoEnrolar), achada pela proximidade.
		props.append({
			"tipo": "portao_botoeira",
			"pos": botoeira,
			"tamanho": Vector3(0.5, 0.6, 0.6),
		})

	# Uma luminaria so, alta e crua. A garagem e o unico comodo do conjunto com
	# sombra de verdade, e e ela que faz a virada de clima valer: o salao nao tem
	# nenhuma.
	props.append({
		"tipo": "lampada", "pos": Vector3(EIXO_PORTAO, ALTURA_GARAGEM - 0.3, 5.4),
		"padrao": Lampada.Padrao.FLUORESCENTE, "semente": rng.randi(),
		"cor": Color("e8eee4"), "energia": 3.1, "alcance": 11.0, "facho": false,
	})
	KitMercado.calha(sup, ALTURA_GARAGEM, EIXO_PORTAO, 5.4, 2.4, PI * 0.5)


# --- corredor -----------------------------------------------------------------

static func _corredor(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary]) -> void:
	var cz0 := FUNDO_SALAO + MEIA
	var cz1 := CORREDOR_Z1 - MEIA
	var meio := (cz0 + cz1) * 0.5

	# A porta de servico: uma folha, dos dois lados a mesma, abrindo para o
	# corredor — do salao se empurra, com a mao ocupada.
	KitMercado.batente(sup, Vector3(PORTA_SERVICO, 0.0, FUNDO_SALAO),
		LARGURA_PORTA_INTERNA, ALTURA_PORTA, 0.0, Color("7a6f5e"), PAREDE_INTERNA + 0.04)
	props.append(_porta_batente(Vector3(PORTA_SERVICO, 1.05, FUNDO_SALAO),
		Vector3(PORTA_SERVICO - LARGURA_PORTA_INTERNA * 0.5, 0.0, FUNDO_SALAO + MEIA),
		0.0, "Porta de servico", Vector3(1.0, 2.1, 1.6), -92.0))

	# A maquina de refrigerante da equipe, na ponta oeste. Vermelha, e a unica
	# cor saturada do bloco inteiro: num corredor todo verde ela e o marco que
	# diz ao jogador onde ele esta quando volta da garagem.
	KitMercado.maquina_refri(sup, colisao, Vector3(0.42, 0.0, meio), PI * 0.5)

	# As regras do turno, pregadas na cortica ao lado da porta de servico. Sao o
	# contrato da F7: o que o funcionario da noite faz e o que ele nao faz.
	KitMercado.quadro_avisos(sup, Vector3(7.4, 1.55, cz0 + 0.03), 1.0, 0.0)

	KitMercado.balde_mop(sup, colisao, Vector3(10.4, 0.0, cz1 - 0.3), 0.3)
	# A bebida que repoe a camara fria, na ponta cega do corredor, depois do
	# estoque: de la ate a porta das geladeiras sao dez passos.
	KitMercado.palete_bebida(sup, colisao, Vector3(15.3, 0.0, meio), 3, 0.05,
		Color("2f7a3e"))
	KitMercado.palete_bebida(sup, colisao, Vector3(16.43, 0.0, meio - 0.02), 2,
		PI * 0.5, Color("d8b23a"))
	KitMercado.grade_ar(sup, Vector3(3.0, ALTURA_SERVICO - 0.3, cz1 - 0.06),
		Vector2(0.7, 0.4), PI)

	# Placas de porta. Cores, e nao texto: a 480x270 o jogador le a cor antes de
	# qualquer letra, e sao tres portas para distinguir.
	KitMercado.placa_porta(sup, Vector3(PORTA_BANHEIRO, ALTURA_PORTA + 0.18, cz1 - 0.02),
		PI, Color("3f6ea8"))
	KitMercado.placa_porta(sup, Vector3(PORTA_COPA, ALTURA_PORTA + 0.18, cz1 - 0.02),
		PI, Color("4a7a52"))
	KitMercado.placa_porta(sup, Vector3(PORTA_ESCRITORIO, ALTURA_PORTA + 0.18, cz1 - 0.02),
		PI, Color("8a6a3a"))

	props.append({
		"tipo": "lampada", "pos": Vector3(6.0, ALTURA_SERVICO - 0.22, meio),
		"padrao": Lampada.Padrao.ESTAVEL, "semente": 4412,
		"cor": Color("eef4ea"), "energia": 2.6, "alcance": 11.0, "facho": false,
	})
	KitMercado.calha(sup, ALTURA_SERVICO, 6.0, meio, 2.4, 0.0)
	KitMercado.calha(sup, ALTURA_SERVICO, 12.9, meio, 2.4, 0.0)


# --- comodos do fundo -----------------------------------------------------------

## As quatro paredes de dentro de um comodo do fundo. `porta` e o vao na parede
## do corredor, em X absoluto.
static func _comodo(sup: Dictionary, x0: float, x1: float, porta: Vector2,
		material: StringName, cor: Color, rodape: float) -> void:
	var z0 := CORREDOR_Z1 + MEIA
	var dentro := Vector2((x0 + x1) * 0.5, (z0 + FUNDO) * 0.5)
	_face(sup, material, Vector2(x0, z0), Vector2(x1, z0), dentro, ALTURA_SERVICO,
		[porta], cor, rodape)
	_face(sup, material, Vector2(x0, FUNDO), Vector2(x1, FUNDO), dentro,
		ALTURA_SERVICO, [], cor, rodape)
	_face(sup, material, Vector2(x0, z0), Vector2(x0, FUNDO), dentro,
		ALTURA_SERVICO, [], cor, rodape)
	_face(sup, material, Vector2(x1, z0), Vector2(x1, FUNDO), dentro,
		ALTURA_SERVICO, [], cor, rodape)


## A folha de uma porta do fundo, abrindo para dentro do comodo.
static func _porta_do_fundo(sup: Dictionary, props: Array[Dictionary], x: float,
		rotulo: String) -> void:
	KitMercado.batente(sup, Vector3(x, 0.0, CORREDOR_Z1), LARGURA_PORTA_INTERNA,
		ALTURA_PORTA, 0.0, Color("7a6f5e"), PAREDE_INTERNA + 0.04)
	props.append(_porta_batente(Vector3(x, 1.05, CORREDOR_Z1),
		Vector3(x - LARGURA_PORTA_INTERNA * 0.5, 0.0, CORREDOR_Z1 + MEIA), 0.0, rotulo,
		Vector3(1.0, 2.1, 1.6), -92.0))


static func _chao_do_fundo(sup: Dictionary, material: StringName, x0: float,
		x1: float, cor: Color, cor_teto: Color) -> void:
	var z0 := CORREDOR_Z1 + MEIA
	KitModular.chao(sup, material, Vector3(x0, 0.0, z0), Vector2(x1 - x0, FUNDO - z0),
		PSXMesh.MAX_QUAD_M, cor)
	_teto(sup, &"mercado_teto", Vector2(x0, z0), Vector2(x1 - x0, FUNDO - z0),
		ALTURA_SERVICO, cor_teto)


static func _banheiro(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary]) -> void:
	var x1 := X_BANHEIRO - MEIA
	# Ladrilho de 20 cm no piso e revestimento de 15 cm na parede, ate o teto,
	# que e o que todo banheiro de loja tem. O `piso_ceramico` antigo era 80/255
	# e o `mercado_azulejo` lia como ladrilho decorativo de cozinha.
	_chao_do_fundo(sup, &"mercado_ladrilho", 0.0, x1, Color.WHITE, Color("c8cac4"))
	_comodo(sup, 0.0, x1, _porta(PORTA_BANHEIRO), &"mercado_revestimento",
		Color.WHITE, 0.0)
	_porta_do_fundo(sup, props, PORTA_BANHEIRO, "Banheiro")

	# Louca, metal e plastico de verdade: `KitBanheiro` no lugar das caixas de
	# `metal` tingidas de branco, que saiam pretas nos dois estilos.
	KitBanheiro.montar(sup, colisao, 0.0, x1, CORREDOR_Z1 + MEIA, FUNDO,
		ALTURA_SERVICO, PORTA_BANHEIRO)

	props.append({
		"tipo": "lampada", "pos": Vector3(1.4, ALTURA_SERVICO - 0.2, 14.3),
		# ESTAVEL de proposito. Fluorescente que apaga no meio da captura deixava
		# o comodo preto, e ficar de costas para a porta ja faz o trabalho.
		"padrao": Lampada.Padrao.ESTAVEL, "semente": 4413,
		"cor": Color("eaf2f4"), "energia": 2.6, "alcance": 6.5, "facho": false,
	})
	KitMercado.calha(sup, ALTURA_SERVICO, 1.4, 14.3, 1.6, PI * 0.5)


static func _copa(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	var x0 := X_BANHEIRO + MEIA
	var x1 := X_COPA - MEIA
	# `mercado_ladrilho` no lugar do `piso_ceramico`, que tem albedo 80/255: com
	# a mobilia clara nova, o piso escuro era a unica coisa preta do comodo e
	# puxava o quadro inteiro para baixo.
	_chao_do_fundo(sup, &"mercado_ladrilho", x0, x1, Color("cfcec4"), Color("c0c2bc"))
	_comodo(sup, x0, x1, _porta(PORTA_COPA), &"reboco", VERDE, RODAPE)
	_porta_do_fundo(sup, props, PORTA_COPA, "Copa")

	# A mesa encostada no fundo, com a cadeira meio puxada. Cadeira empurrada
	# certinha le como movel de catalogo; puxada le como alguem que levantou.
	KitMercado.mesa_trabalho(sup, colisao, Vector3(5.9, 0.0, FUNDO - 0.36), 1.8, PI)
	KitServico.cadeira_plastica(sup, colisao, Vector3(5.7, 0.0, FUNDO - 1.2), 0.26)
	KitServico.cadeira_plastica(sup, colisao, Vector3(6.55, 0.0, FUNDO - 1.05),
		-0.7, Color("dfe0d6"))
	KitMercado.quadro_avisos(sup, Vector3(4.6, 1.62, FUNDO - 0.03), 1.1, PI)
	KitMercado.armario_vestiario(sup, colisao, Vector3(x0 + 0.22, 0.0, 14.5), 4,
		PI * 0.5)
	# Bancada, maquina de cafe, micro-ondas, frigobar e bebedouro no lugar da
	# `bancada_copa`, que era um gabinete de `metal` com seis caixas em cima: o
	# que separa a copa do escritorio nao e a planta, e o que ha na bancada.
	KitServico.montar_copa(sup, colisao, x0, x1, CORREDOR_Z1 + MEIA, FUNDO)
	KitMercado.grade_ar(sup, Vector3(4.2, ALTURA_SERVICO - 0.28, FUNDO - 0.06),
		Vector2(0.7, 0.4), PI)

	props.append({
		"tipo": "lampada", "pos": Vector3(5.3, ALTURA_SERVICO - 0.22, 14.3),
		"padrao": Lampada.Padrao.ESTAVEL, "semente": rng.randi(),
		"cor": Color("f2f0e2"), "energia": 2.8, "alcance": 7.5, "facho": false,
	})
	KitMercado.calha(sup, ALTURA_SERVICO, 5.3, 14.3, 2.2, 0.0)


## A sala do monitor: o escritorio do gerente, com o circuito fechado, o cofre e
## o arquivo. E a sala que a F7 transforma em ferramenta — o unico lugar da loja
## de onde se ve a loja inteira ao mesmo tempo.
static func _escritorio(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary]) -> Vector3:
	var x0 := X_COPA + MEIA
	var x1 := X_ESCRITORIO - MEIA
	_chao_do_fundo(sup, &"mercado_ladrilho", x0, x1, Color("cdc9bc"), Color("c4c4bc"))
	_comodo(sup, x0, x1, _porta(PORTA_ESCRITORIO), &"reboco", Color("cfc8b6"), RODAPE)
	_porta_do_fundo(sup, props, PORTA_ESCRITORIO, "Escritorio")

	var tampo := 0.74 + 0.025
	KitMercado.mesa_trabalho(sup, colisao, Vector3(9.4, 0.0, FUNDO - 0.34), 2.2, PI)
	var tela := KitMercado.monitor_cftv(sup, colisao, Vector3(9.05, tampo, FUNDO - 0.3), PI)
	# Cadeira giratoria de frente para o monitor. A `KitMercado.cadeira` estava
	# de costas para a tela (giro PI + 0,18), e cadeira de costas para a mesa le
	# como movel jogado no comodo.
	KitServico.cadeira_giratoria(sup, colisao, Vector3(9.15, 0.0, FUNDO - 1.05), 0.16)
	KitMercado.cofre(sup, colisao, Vector3(10.2, 0.0, FUNDO - 0.4), PI)
	KitMercado.arquivo(sup, colisao, Vector3(x0 + 0.32, 0.0, 13.3), PI * 0.5)
	KitMercado.quadro_avisos(sup, Vector3(x1 - 0.03, 1.55, 14.2), 0.9, -PI * 0.5)
	props.append({
		"tipo": "lampada", "pos": Vector3(9.4, ALTURA_SERVICO - 0.22, 14.3),
		"padrao": Lampada.Padrao.ESTAVEL, "semente": 4414,
		"cor": Color("f0ecdc"), "energia": 2.2, "alcance": 6.5, "facho": false,
	})
	KitMercado.calha(sup, ALTURA_SERVICO, 9.4, 14.3, 1.6, 0.0)
	return tela


static func _estoque(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary]) -> void:
	var x0 := X_ESCRITORIO + MEIA
	_chao_do_fundo(sup, &"concreto", x0, LARGURA, KitMercado.PISO_SERVICO,
		Color("b8bab4"))
	_comodo(sup, x0, LARGURA, VAO_ESTOQUE, &"reboco", VERDE, RODAPE)

	# Estante no fundo e na parede leste, e o carrinho de carga no meio: o
	# estoque seco e de onde sai tudo que nao e bebida.
	KitEstoque.estante_carregada(sup, colisao, Vector3(13.2, 0.0, FUNDO - 0.35), 3.8,
		PI, 71302)
	KitEstoque.estante_carregada(sup, colisao, Vector3(LARGURA - 0.35, 0.0, 14.1), 2.8,
		-PI * 0.5, 71303)
	KitEstoque.palete(sup, colisao, Vector3(14.9, 0.0, 14.0), -0.08, 71312, 2)
	KitMercado.carrinho_carga(sup, colisao, Vector3(x0 + 0.4, 0.0, 15.2), PI * 0.5)
	props.append({
		"tipo": "lampada", "pos": Vector3(14.1, ALTURA_SERVICO - 0.22, 14.3),
		"padrao": Lampada.Padrao.ESTAVEL, "semente": 4415,
		"cor": Color("eef0e8"), "energia": 2.6, "alcance": 7.5, "facho": false,
	})
	KitMercado.calha(sup, ALTURA_SERVICO, 14.1, 14.3, 2.2, 0.0)


## Descricao de uma porta de folha que abre no lugar, sem levar a outro comodo.
##
## Nao e a `porta_interna` da casa da fumaca: aquela empilha o comodo atual e
## constroi outro. Aqui o bloco de servico inteiro e UMA planta so, entao a
## folha e cenario animado — e o jogador atravessa andando, sem cortina e sem
## carregamento.
static func _porta_batente(pos: Vector3, dobradica: Vector3, giro: float,
		rotulo: String, tamanho: Vector3, angulo: float = 92.0) -> Dictionary:
	return {
		"tipo": "porta_batente",
		"pos": pos,
		"dobradica": dobradica,
		"giro": giro,
		"angulo": angulo,
		"rotulo": rotulo,
		"tamanho": tamanho,
	}


# --- mercadoria -------------------------------------------------------------

## Itens que o jogador leva. Poucos e espalhados: loja cheia de item para pegar
## vira deposito, e o valor de achar bandagem numa prateleira e justamente ela
## ser a unica coisa util num lugar cheio de coisa inutil.
static func _mercadoria(props: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	# O que estava solto nas prateleiras do salao (bandagem, bateria, remedio)
	# agora e produto de catalogo — Band-Aid, pilha, Aspirina — e se compra.
	# Solto so fica o que nao e da loja.
	var lista: Array[Dictionary] = [
		# Uma no deposito. E o premio de ter atravessado a porta do caixa: quem
		# so anda pelo salao nunca acha, e quem anda ate a garagem acha sem que
		# ninguem tenha avisado que havia algo la.
		{"item": &"bandagem", "pos": Vector3(0.7, 1.15, 6.2), "qtd": 1},
	]
	if rng.randf() < 0.5:
		lista.append({"item": &"municao_9mm",
			"pos": Vector3(BALCAO_X - 0.1, KitMercado.ALTURA_BALCAO + 0.24, 5.0),
			"qtd": rng.randi_range(4, 9)})

	for i in lista.size():
		var d: Dictionary = lista[i]
		props.append({
			"tipo": "item", "pos": d["pos"], "item": d["item"],
			"quantidade": d["qtd"], "indice": 10 + i,
		})


## Quem esta atras do balcao e quem vem comprar.
##
## Duas pessoas no caixa e o que faz o jogador entender, em quatro segundos, que
## esta cidade e habitada. O desconforto do comodo nao morre com isso: a luz
## continua branca e chapada, o pe direito continua alto demais. O que muda e
## que agora ha alguem para quem aquela luz esta acesa.
##
## O cliente passa pela gondola do corredor central e so depois vai ao caixa, e
## a ROTA passa pela boca do corredor: em linha reta da gondola ao balcao ele
## atravessava a primeira ilha e ficava esfregando nela (F0, medido: a mesma
## posicao aos 30 e aos 60 segundos). Na loja da rua quem acha o caminho e a
## malha de navegacao da CasaViva; os pontos continuam valendo para os dois.
static func _gente(props: Array[Dictionary], semente: int, no_mundo: bool) -> void:
	var gondola := Vector3(CENTRO_PORTA, 0.0, 6.2)
	var boca := Vector3(CENTRO_PORTA, 0.0, 2.3)
	var atendente := _pessoa(semente, SAL_DO_ATENDENTE, POSTO_ATENDENTE, POSTO_CLIENTE)
	atendente["classe"] = &"atendente"
	props.append(atendente)
	var compra := _pessoa(semente, SAL_DO_CLIENTE, Vector3(CENTRO_PORTA + 0.4, 0.0, 1.5),
		POSTO_ATENDENTE)
	compra["rotina"] = &"compra"
	compra["pontos"] = [gondola, boca, POSTO_CLIENTE]
	compra["pouso"] = Vector3(BALCAO_X + 0.3, KitMercado.ALTURA_BALCAO + 0.08, 2.95)
	if no_mundo:
		# Na rua ele vem de fora: nasce na calcada, e a porta abre para ele.
		compra["pos"] = Vector3(CENTRO_PORTA - 0.5, 0.0, -PAREDE - 0.12)
	props.append(compra)


## Uma pessoa de pe, de frente para `encara`.
##
## `pontos` vai vazio de proposito: e a lista de onde a pessoa pode ir passear,
## e atendente que sai andando pela loja deixa de ser atendente.
static func _pessoa(semente: int, sal: int, onde: Vector3,
		encara: Vector3) -> Dictionary:
	return {
		"tipo": "convidado",
		"pos": onde,
		"semente": semente + sal,
		"papel": Convidado.Papel.LIVRE,
		"fuma": false,
		# Explicita, e nao herdada do padrao do Interiores: a carteira em cima do
		# balcao le a mesma faixa para chegar na mesma pessoa.
		"idade_min": IDADE_CLIENTE.x,
		"idade_max": IDADE_CLIENTE.y,
		"foco": encara,
		"pontos": [],
		"chapado": false,
		"olhos": false,
		"contexto": &"loja",
	}
