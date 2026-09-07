## A casa da fumaca: sala de amigos com a TV ligada e a partida rolando.
##
## Mesmo contrato do CasaBuilder e do MercadoBuilder — dados puros, sem no
## nenhum, montado na thread enquanto a porta abre.
##
## O que este comodo tem de dizer no primeiro quadro
## -------------------------------------------------
## A cidade inteira do jogo e vazia, molhada e iluminada a sodio. Este e o unico
## lugar dela com gente demais num espaco de menos, luz azul de tubo, som alto e
## cheiro. O contraste e o produto: quando o jogador sai por aquela porta, a rua
## fica pior do que estava antes de ele entrar.
##
## Por isso a luz. Nao ha lampada de teto acesa aqui — ha a TV, uma luminaria de
## canto e as brasas na mao de quem esta fumando. Um comodo assim, iluminado por
## cima, vira uma sala de estar qualquer. A luz e quente de proposito: o ar
## denso, a fumaca no teto e o amber da luminaria tem de ler sauna, nao neon.
##
## Planta, em metros, origem no canto sul-oeste:
##
##   z=6.4 +--------------------------------+
##         |   [rack e TV]        [caixa]   |
##         |                                |
##         |   (o chao onde jogam)          |
##   z=3.0 |  [sofa]      [mesa]            |
##         |                                |
##         |                       [skate]  |
##   z=0   +---------[entrada]--------------+
##        x=0                             x=7.2
class_name CasaFumacaBuilder
extends RefCounted

const ALTURA := 2.45
const ALTURA_PORTA := 2.05
const RODAPE := 0.11

const LARGURA := 7.2
const FUNDO := 6.4

## Onde o jogador aparece, e para onde olha. Chega de frente para a TV, com a
## sala inteira entre ele e ela: e o quadro que explica o comodo sem uma linha.
const ENTRADA := Vector3(2.2, 0.0, 0.85)
const OLHAR := Vector3(3.6, 1.15, 5.9)

## O tubo, contra a parede do fundo.
##
## O Z aqui e o da IMAGEM, e nao o do movel. A ordem em profundidade tem de ser
## exatamente esta, do jogador para a parede:
##
##   5.59  a imagem            (prop Televisao)
##   5.60  a moldura preta     (caixa fina)
##   5.62  a frente do gabinete
##   6.34  o fundo do gabinete, encostado na parede
##
## Na primeira versao a moldura ficou cinco centimetros a frente da imagem e a
## partida simplesmente nao aparecia: o que se via era um retangulo claro no
## fundo da sala. Foi a captura que mostrou — lendo o codigo, as duas linhas
## pareciam certas.
const TV := Vector3(3.6, 0.98, 5.59)
## Onde o console fica no chao, e de onde saem os cabos.
const CONSOLE := Vector3(3.05, 0.0, 4.92)

## Celulas do atlas da casa. Ver tools/gerar_casa.py.
##
## Existem porque KitModular.caixa mapeia UV POR METRO sobre a textura inteira:
## uma caixa de meio metro com o atlas da casa pega um retalho arbitrario dele.
## O sofa saiu vestindo o gramado do jogo de futebol e a mesa saiu com um
## saquinho estampado no tampo — foi a captura que mostrou, porque lendo o
## codigo os dois eram so `&"casa"`.
##
## Aqui cada peca diz que celula quer, e `_caixa` mapeia as seis faces nela.
const C_TV := Vector2i(0, 1)
const C_TV_TRAS := Vector2i(1, 1)
const C_MOLDURA := Vector2i(2, 1)
const C_CONSOLE := Vector2i(3, 1)
const C_CABO := Vector2i(5, 1)
const C_MADEIRA := Vector2i(6, 1)
const C_SOFA := Vector2i(7, 1)
const C_CD := Vector2i(0, 2)
const C_POSTER := Vector2i(1, 2)
const C_CINZEIRO := Vector2i(2, 2)
const C_GARRAFA := Vector2i(3, 2)
const C_SAQUINHO := Vector2i(1, 3)
const C_MOCHILA := Vector2i(2, 3)
const C_LIXA := Vector2i(3, 3)
const C_SHAPE := Vector2i(4, 3)
const C_SOM_FRENTE := Vector2i(5, 3)
const C_SOM_LADO := Vector2i(6, 3)


## Paredes de quem nao escolheu a cor: o branco encardido do aluguel, puxado
## um pouco para o creme quente — sob a fumaca amber, parede cinza le fria.
const CORES_PAREDE: Array[Color] = [
	Color("c4b49a"),
	Color("bca890"),
	Color("c8b294"),
]


static func construir(semente: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente

	var sup: Dictionary = {}
	var props: Array[Dictionary] = []
	var colisao: Array[Dictionary] = []

	var cor: Color = CORES_PAREDE[rng.randi() % CORES_PAREDE.size()]

	_casca(sup, cor)
	_colisao(colisao)
	_rack_e_tv(sup, colisao, props)
	_console_e_cabos(sup)
	_sofa(sup, colisao)
	_mesa(sup, colisao, rng)
	_canto_do_som(sup, colisao, props)
	_tralha(sup, colisao, rng)
	_fumaca(sup)
	_luzes(props)
	_gente(props, semente)

	var tris := 0
	for mat: StringName in sup:
		tris += PSXMesh.dados_triangulos(sup[mat])

	return {
		"superficies": sup, "props": props, "colisao": colisao,
		"triangulos": tris, "entrada": ENTRADA, "olhar": OLHAR,
		# Ambiente proprio: nevoa amber curta, grade quente — o ar de sauna
		# que some assim que a porta fecha atras do jogador.
		"ambiente": "res://resources/fog/fog_fumaca.tres",
		"saida": {
			"pos": Vector3(2.2, 1.0, 0.45),
			"tamanho": Vector3(1.3, 2.0, 0.9),
			"dobradica": Vector3(1.65, 0.0, 0.06),
			"giro": 0.0,
			"angulo": 92.0,
		},
	}


# --- desenho com celula -----------------------------------------------------

## Uma face plana com uma celula do atlas.
static func _face(sup: Dictionary, material: StringName, tamanho: Vector2,
		xform: Transform3D, celula: Vector2i, cor: Color = Color.WHITE) -> void:
	var d := PSXMesh.placa_dados(tamanho, 100.0, Color.WHITE)
	var r := Carroceria.uv(celula)
	var uvs: PackedVector2Array = d["uv"]
	for k in uvs.size():
		uvs[k] = r.position + uvs[k] * r.size
	d["uv"] = uvs
	if not sup.has(material):
		sup[material] = PSXMesh.dados_vazios()
	PSXMesh.acumular_tingido(sup[material], d, xform, cor)


## Caixa com celula por face, e sem a base, que ninguem ve.
##
## `topo` existe porque quase todo movel tem a face de cima diferente das
## laterais: o rack e madeira em volta e madeira em cima, mas a caixa de som e
## cone na frente e compensado nos lados.
static func _caixa(sup: Dictionary, centro: Vector3, tamanho: Vector3,
		celula: Vector2i, cor: Color = Color.WHITE, giro: float = 0.0,
		frente: Vector2i = Vector2i(-1, -1),
		topo: Vector2i = Vector2i(-1, -1)) -> void:
	var h := tamanho * 0.5
	var base := Basis(Vector3.UP, giro)
	var c_frente := celula if frente.x < 0 else frente
	var c_topo := celula if topo.x < 0 else topo
	var mat: StringName = &"casa"
	_face(sup, mat, Vector2(tamanho.x, tamanho.y),
		Transform3D(base, centro + base * Vector3(0, 0, h.z)), c_frente, cor)
	_face(sup, mat, Vector2(tamanho.x, tamanho.y),
		Transform3D(base * Basis(Vector3.UP, PI),
			centro - base * Vector3(0, 0, h.z)), celula, cor)
	_face(sup, mat, Vector2(tamanho.z, tamanho.y),
		Transform3D(base * Basis(Vector3.UP, PI * 0.5),
			centro + base * Vector3(h.x, 0, 0)), celula, cor)
	_face(sup, mat, Vector2(tamanho.z, tamanho.y),
		Transform3D(base * Basis(Vector3.UP, -PI * 0.5),
			centro - base * Vector3(h.x, 0, 0)), celula, cor)
	_face(sup, mat, Vector2(tamanho.x, tamanho.z),
		Transform3D(base * Basis(Vector3.RIGHT, -PI * 0.5),
			centro + Vector3(0, h.y, 0)), c_topo, cor)


## Caixa em angulo livre, para o que nao esta alinhado com a parede.
static func _caixa_livre(sup: Dictionary, centro: Vector3, tamanho: Vector3,
		base: Basis, celula: Vector2i, cor: Color = Color.WHITE,
		topo: Vector2i = Vector2i(-1, -1)) -> void:
	var h := tamanho * 0.5
	var c_topo := celula if topo.x < 0 else topo
	var mat: StringName = &"casa"
	_face(sup, mat, Vector2(tamanho.x, tamanho.y),
		Transform3D(base, centro + base * Vector3(0, 0, h.z)), celula, cor)
	_face(sup, mat, Vector2(tamanho.x, tamanho.y),
		Transform3D(base * Basis(Vector3.UP, PI),
			centro - base * Vector3(0, 0, h.z)), celula, cor)
	_face(sup, mat, Vector2(tamanho.z, tamanho.y),
		Transform3D(base * Basis(Vector3.UP, PI * 0.5),
			centro + base * Vector3(h.x, 0, 0)), celula, cor)
	_face(sup, mat, Vector2(tamanho.z, tamanho.y),
		Transform3D(base * Basis(Vector3.UP, -PI * 0.5),
			centro - base * Vector3(h.x, 0, 0)), celula, cor)
	_face(sup, mat, Vector2(tamanho.x, tamanho.z),
		Transform3D(base * Basis(Vector3.RIGHT, -PI * 0.5),
			centro + base * Vector3(0, h.y, 0)), c_topo, cor)
	_face(sup, mat, Vector2(tamanho.x, tamanho.z),
		Transform3D(base * Basis(Vector3.RIGHT, PI * 0.5),
			centro - base * Vector3(0, h.y, 0)), celula, cor)


# --- casca ------------------------------------------------------------------

static func _casca(sup: Dictionary, cor: Color) -> void:
	KitModular.chao(sup, &"piso", Vector3.ZERO, Vector2(LARGURA, FUNDO))
	var teto := PSXMesh.plane_dados(Vector2(LARGURA, FUNDO))
	KitModular.por(sup, &"teto", teto,
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
			Vector3(LARGURA * 0.5, ALTURA, FUNDO * 0.5)))

	var mat: StringName = &"reboco"
	# Perimetro anti horario visto de cima, para as normais olharem para dentro.
	KitModular.parede_com_vaos(sup, mat, Vector2(0.0, 0.0), Vector2(LARGURA, 0.0),
		ALTURA, [Vector2(1.65, 2.75)], ALTURA_PORTA, cor, RODAPE)
	KitModular.parede_com_vaos(sup, mat, Vector2(LARGURA, 0.0),
		Vector2(LARGURA, FUNDO), ALTURA, [], ALTURA_PORTA, cor, RODAPE)
	KitModular.parede_com_vaos(sup, mat, Vector2(LARGURA, FUNDO),
		Vector2(0.0, FUNDO), ALTURA, [], ALTURA_PORTA, cor, RODAPE)
	KitModular.parede_com_vaos(sup, mat, Vector2(0.0, FUNDO), Vector2(0.0, 0.0),
		ALTURA, [], ALTURA_PORTA, cor, RODAPE)

	# Cartazes. Sao a unica coisa nas paredes e por isso carregam o lugar: um
	# comodo de parede limpa le como cenario, e um com poster torto le como
	# quarto de alguem.
	_face(sup, &"casa", Vector2(0.62, 0.86),
		Transform3D(Basis(Vector3.UP, PI), Vector3(0.62, 1.62, FUNDO - 0.02)),
		C_POSTER)
	_face(sup, &"casa", Vector2(0.58, 0.8),
		Transform3D(Basis(Vector3.UP, -PI * 0.5),
			Vector3(LARGURA - 0.03, 1.55, 2.4)), C_POSTER)


static func _colisao(colisao: Array[Dictionary]) -> void:
	# Piso e as quatro paredes. O teto nao entra: ninguem chega la.
	colisao.append({"tamanho": Vector3(LARGURA, 0.4, FUNDO),
		"pos": Vector3(LARGURA * 0.5, -0.2, FUNDO * 0.5)})
	for lado: Array in [
			[Vector3(LARGURA, ALTURA, 0.3), Vector3(LARGURA * 0.5, ALTURA * 0.5, -0.15)],
			[Vector3(LARGURA, ALTURA, 0.3), Vector3(LARGURA * 0.5, ALTURA * 0.5, FUNDO + 0.15)],
			[Vector3(0.3, ALTURA, FUNDO), Vector3(-0.15, ALTURA * 0.5, FUNDO * 0.5)],
			[Vector3(0.3, ALTURA, FUNDO), Vector3(LARGURA + 0.15, ALTURA * 0.5, FUNDO * 0.5)]]:
		colisao.append({"tamanho": lado[0], "pos": lado[1]})


# --- a TV -------------------------------------------------------------------

## O rack e o gabinete, em caixas fundidas no comodo; a tela vira prop.
##
## O tubo de uma TV dessas e fundo: setenta centimetros de gabinete para trinta
## de imagem. Essa profundidade e o objeto — desenhada rasa, a TV vira um monitor
## e a data do comodo se perde.
static func _rack_e_tv(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary]) -> void:
	var rack := Vector3(TV.x, 0.0, FUNDO - 0.36)
	_caixa(sup, rack + Vector3(0.0, 0.28, 0.0), Vector3(1.6, 0.56, 0.7),
		C_MADEIRA)
	colisao.append({"tamanho": Vector3(1.5, 0.6, 0.62),
		"pos": rack + Vector3(0.0, 0.3, 0.0)})

	# Gabinete: a caixa funda, e a moldura preta em volta do tubo.
	_caixa(sup, Vector3(TV.x, TV.y, FUNDO - 0.42), Vector3(0.90, 0.80, 0.72),
		C_TV, Color.WHITE, 0.0, C_TV_TRAS)
	# A moldura fica ATRAS da imagem, encostada nela: e o vao preto em volta do
	# tubo, e nao uma tampa por cima dele.
	_caixa(sup, Vector3(TV.x, TV.y, TV.z + 0.025), Vector3(0.84, 0.72, 0.03),
		C_MOLDURA)
	colisao.append({"tamanho": Vector3(0.94, 0.84, 0.78),
		"pos": Vector3(TV.x, TV.y, FUNDO - 0.44)})

	# A imagem. Vira PI porque o tubo esta na parede do fundo e olha para a sala.
	props.append({
		"tipo": "televisao",
		"pos": Vector3(TV.x, TV.y, TV.z),
		"giro": PI,
	})


## O console no chao e a fiacao. Sao seis caixas finas e valem mais que o
## console: um PS2 limpo em cima do rack le como vitrine, e o mesmo console no
## chao com o cabo esticado ate o sofa le como sabado a noite.
static func _console_e_cabos(sup: Dictionary) -> void:
	_caixa(sup, CONSOLE + Vector3(0.0, 0.04, 0.0), Vector3(0.30, 0.08, 0.20),
		C_CONSOLE)

	# Cabo de video subindo ate a traseira da TV.
	_cabo(sup, CONSOLE + Vector3(0.0, 0.05, 0.0),
		Vector3(TV.x, 0.62, FUNDO - 0.5))
	# Os dois cabos de controle, saindo para quem esta jogando. Passam pelo chao
	# em L, como cabo de verdade passa: reto ate o meio e depois virando.
	_cabo(sup, CONSOLE + Vector3(0.06, 0.03, 0.0), Vector3(3.42, 0.06, 4.12))
	_cabo(sup, Vector3(3.42, 0.06, 4.12), Vector3(3.44, 0.34, 3.62))
	_cabo(sup, CONSOLE + Vector3(-0.06, 0.03, 0.0), Vector3(4.18, 0.06, 4.30))
	_cabo(sup, Vector3(4.18, 0.06, 4.30), Vector3(4.16, 0.92, 3.30))


static func _cabo(sup: Dictionary, de: Vector3, para: Vector3) -> void:
	var vetor := para - de
	var comp := vetor.length()
	if comp < 0.02:
		return
	var direcao := vetor / comp
	var eixo := Vector3.RIGHT.cross(direcao)
	var base := Basis()
	if eixo.length_squared() > 0.000001:
		base = Basis(eixo.normalized(), Vector3.RIGHT.angle_to(direcao))
	_caixa_livre(sup, de + vetor * 0.5, Vector3(comp, 0.022, 0.022), base,
		C_CABO, Color(0.7, 0.7, 0.72))


# --- mobilia ----------------------------------------------------------------

static func _sofa(sup: Dictionary, colisao: Array[Dictionary]) -> void:
	var base := Vector3(0.92, 0.0, 3.05)
	# Assento, encosto e dois bracos. Quatro caixas: a quinta nao acrescenta
	# nada que se veja a esta distancia.
	_caixa(sup, base + Vector3(0.0, 0.22, 0.0), Vector3(0.86, 0.44, 1.95), C_SOFA)
	_caixa(sup, base + Vector3(-0.31, 0.55, 0.0), Vector3(0.24, 0.66, 1.95), C_SOFA)
	for z: float in [-0.92, 0.92]:
		_caixa(sup, base + Vector3(0.02, 0.48, z), Vector3(0.80, 0.24, 0.18),
			C_SOFA)
	colisao.append({"tamanho": Vector3(0.95, 0.9, 2.0),
		"pos": base + Vector3(-0.05, 0.45, 0.0)})


static func _mesa(sup: Dictionary, colisao: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	var mesa := Vector3(2.55, 0.0, 3.0)
	_caixa(sup, mesa + Vector3(0.0, 0.38, 0.0), Vector3(0.72, 0.05, 1.15),
		C_MADEIRA)
	for canto: Vector3 in [Vector3(-0.30, 0.0, -0.50), Vector3(0.30, 0.0, -0.50),
			Vector3(-0.30, 0.0, 0.50), Vector3(0.30, 0.0, 0.50)]:
		_caixa(sup, mesa + canto + Vector3(0.0, 0.19, 0.0),
			Vector3(0.06, 0.38, 0.06), C_MADEIRA)
	colisao.append({"tamanho": Vector3(0.75, 0.42, 1.2),
		"pos": mesa + Vector3(0.0, 0.21, 0.0)})

	# O que esta em cima da mesa. Sao placas deitadas, e nao volumes: a
	# espessura de um saquinho e de uma caixa de CD nao existe a esta distancia,
	# e cada um deles em caixa custaria seis faces para mostrar uma.
	var tampo := mesa.y + 0.41
	_deitado(sup, &"casa", Vector3(mesa.x - 0.16, tampo, mesa.z - 0.30),
		Vector2(0.24, 0.24), C_CINZEIRO, rng.randf_range(0.0, TAU))
	# Os saquinhos. Dois na mesa e mais alguns espalhados: e o objeto que da nome
	# a casa e ele tem de ser legivel de longe, entao vai maior do que seria.
	_deitado(sup, &"casa_recorte", Vector3(mesa.x + 0.14, tampo, mesa.z - 0.12),
		Vector2(0.19, 0.19), C_SAQUINHO, rng.randf_range(0.0, TAU))
	_deitado(sup, &"casa_recorte", Vector3(mesa.x - 0.08, tampo, mesa.z + 0.24),
		Vector2(0.16, 0.16), C_SAQUINHO, rng.randf_range(0.0, TAU))
	_deitado(sup, &"casa", Vector3(mesa.x + 0.18, tampo, mesa.z + 0.40),
		Vector2(0.15, 0.15), C_CD, rng.randf_range(0.0, TAU))
	_deitado(sup, &"casa", Vector3(mesa.x - 0.20, tampo, mesa.z + 0.05),
		Vector2(0.22, 0.10), C_GARRAFA, rng.randf_range(0.0, TAU))


## Uma placa deitada no chao ou num tampo, com uma celula do atlas.
static func _deitado(sup: Dictionary, material: StringName, onde: Vector3,
		tamanho: Vector2, celula: Vector2i, giro: float) -> void:
	var d := PSXMesh.placa_dados(tamanho, 100.0, Color.WHITE)
	var r := Carroceria.uv(celula)
	var uvs: PackedVector2Array = d["uv"]
	for k in uvs.size():
		uvs[k] = r.position + uvs[k] * r.size
	d["uv"] = uvs
	KitModular.por(sup, material, d,
		Transform3D(Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, -PI * 0.5),
			onde + Vector3(0.0, 0.004, 0.0)))


## O canto do som: a caixa dos anos 2000, empilhada em cima de um caixote.
static func _canto_do_som(sup: Dictionary, colisao: Array[Dictionary],
		props: Array[Dictionary]) -> void:
	var caixa := Vector3(LARGURA - 0.75, 0.0, FUNDO - 0.85)
	_caixa(sup, caixa + Vector3(0.0, 0.22, 0.0), Vector3(0.5, 0.44, 0.42),
		C_MADEIRA)
	# A frente com os cones vira para o meio da sala, ou seja para -Z.
	_caixa(sup, caixa + Vector3(0.0, 0.72, 0.0), Vector3(0.42, 0.56, 0.36),
		C_SOM_LADO, Color.WHITE, PI, C_SOM_FRENTE)
	colisao.append({"tamanho": Vector3(0.52, 1.0, 0.44),
		"pos": caixa + Vector3(0.0, 0.5, 0.0)})

	# A batida sai daqui, e nao de lugar nenhum. Um som de sala que nao tem
	# fonte no espaco vira trilha; com fonte, o jogador anda em direcao a ela.
	props.append({
		"tipo": "som_ambiente",
		"pos": caixa + Vector3(0.0, 0.9, 0.0),
		"som": &"funk_batida",
		"volume": -13.0,
		"alcance": 14.0,
		"pasta": "casa",
	})


## O que esta pelo chao. E o que mais diz sobre quem mora aqui, e o que menos
## custa: sao placas e caixas soltas, sem colisao, para o jogador nao tropecar
## numa mochila a cada passo.
static func _tralha(sup: Dictionary, colisao: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	# Skate encostado na parede leste, de pe, apoiado pelo rabo.
	# O shape fica de pe, encostado e um pouco tombado — que e como skate fica
	# quando ninguem esta usando. Deitado no chao ele some sob a perspectiva.
	var skate := Vector3(LARGURA - 0.28, 0.0, 1.9)
	_caixa_livre(sup, skate + Vector3(0.0, 0.40, 0.0),
		Vector3(0.20, 0.80, 0.03), Basis(Vector3.FORWARD, 0.2), C_SHAPE,
		Color.WHITE, C_LIXA)
	for y: float in [0.10, 0.70]:
		for lado: float in [-0.07, 0.07]:
			_caixa(sup, skate + Vector3(-0.06, y, lado),
				Vector3(0.06, 0.06, 0.06), C_CABO, Color(0.75, 0.72, 0.66))

	# Duas mochilas largadas, uma perto da porta e outra ao pe do sofa.
	for onde: Vector3 in [Vector3(1.15, 0.0, 1.15), Vector3(1.62, 0.0, 3.9)]:
		_caixa(sup, onde + Vector3(0.0, 0.17, 0.0), Vector3(0.30, 0.34, 0.22),
			C_MOCHILA, Color.WHITE, rng.randf_range(0.0, TAU))
		colisao.append({"tamanho": Vector3(0.34, 0.36, 0.26),
			"pos": onde + Vector3(0.0, 0.18, 0.0)})

	# Cinzeiros espalhados: um na mesa ja existe, e mais dois pelo chao e pelo
	# rack. Tres cinzeiros num comodo so nao e exagero — e o que denuncia que a
	# noite comecou ha muito tempo.
	_deitado(sup, &"casa", Vector3(4.85, 0.0, 3.35), Vector2(0.24, 0.24),
		C_CINZEIRO, rng.randf_range(0.0, TAU))
	_deitado(sup, &"casa", Vector3(TV.x - 0.62, 0.57, FUNDO - 0.5),
		Vector2(0.22, 0.22), C_CINZEIRO, rng.randf_range(0.0, TAU))
	_deitado(sup, &"casa", Vector3(1.42, 0.45, 2.55), Vector2(0.21, 0.21),
		C_CINZEIRO, rng.randf_range(0.0, TAU))
	# E mais saquinho, no chao ao lado de quem esta jogando.
	for onde: Vector3 in [Vector3(3.95, 0.0, 4.55), Vector3(1.42, 0.45, 3.55),
			Vector3(TV.x + 0.62, 0.57, FUNDO - 0.5)]:
		_deitado(sup, &"casa_recorte", onde, Vector2(0.17, 0.17), C_SAQUINHO,
			rng.randf_range(0.0, TAU))
	# Garrafas.
	for onde: Vector3 in [Vector3(2.05, 0.0, 2.35), Vector3(5.2, 0.0, 4.6)]:
		_deitado(sup, &"casa_recorte", onde, Vector2(0.22, 0.14),
			C_GARRAFA, rng.randf_range(0.0, TAU))
	# Caixinhas de CD pelo chao, do lado do console.
	for k in 3:
		_deitado(sup, &"casa", Vector3(2.5 + float(k) * 0.24, 0.0, 5.2),
			Vector2(0.15, 0.15), C_CD, rng.randf_range(0.0, TAU))


# --- fumaca -----------------------------------------------------------------

## A camada parada embaixo do teto, e os fios que sobem dos cinzeiros.
##
## Sao tres placas horizontais e nao uma. Uma placa so, por mais densa que
## fosse, tem espessura zero: passando por baixo dela o jogador ve uma linha
## reta atravessando a sala. Tres, em alturas diferentes e com opacidades
## decrescentes, dao ESPESSURA — a fumaca fica mais fechada em cima e vai
## rareando na altura da cabeca, que e como fumaca de cigarro se acomoda num
## comodo fechado e e o que da a leitura de sauna.
##
## A UV corre nas tres, com deriva no material, e cada uma tem um numero de
## repeticoes diferente. Iguais, as tres se moveriam em bloco e a camada leria
## como uma imagem so deslizando; diferentes, elas se cruzam e o desenho muda
## sozinho o tempo todo.
# Opacidade um pouco mais alta e uma quarta camada na altura da cabeca:
# e o que fecha o veu umido sem virar parede branca.
const CAMADAS_FUMACA: Array = [
	[2.34, 0.78, 3.0],
	[2.14, 0.56, 2.2],
	[1.90, 0.38, 1.6],
	[1.62, 0.18, 1.2],
]

static func _fumaca(sup: Dictionary) -> void:
	for camada: Array in CAMADAS_FUMACA:
		var altura: float = camada[0]
		var opacidade: float = camada[1]
		var repeticoes: float = camada[2]
		# Tint quente no vertice: o material ja e amber, e o vertice reforca
		# vapor em vez de nevoa fria quando a TV ilumina a camada de tras.
		var d := PSXMesh.placa_dados(Vector2(LARGURA - 0.2, FUNDO - 0.2), 100.0,
			Color(1.0, 0.92, 0.82, opacidade))
		var uvs: PackedVector2Array = d["uv"]
		for k in uvs.size():
			uvs[k] = uvs[k] * repeticoes
		d["uv"] = uvs
		if not sup.has(&"fumaca_teto"):
			sup[&"fumaca_teto"] = PSXMesh.dados_vazios()
		# Virada para baixo: quem olha para ela esta embaixo dela.
		PSXMesh.acumular(sup[&"fumaca_teto"], d,
			Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
				Vector3(LARGURA * 0.5, altura, FUNDO * 0.5)))

	# Os fios que sobem dos cinzeiros. Duas placas cruzadas cada, para nao
	# sumirem quando o jogador contorna a mesa.
	for onde: Vector3 in [Vector3(2.39, 0.42, 2.70), Vector3(4.85, 0.02, 3.35),
			Vector3(1.42, 0.47, 2.55)]:
		_coluna_de_fumaca(sup, onde, 0.26, 1.5)


## Uma coluna de fumaca subindo de um ponto.
static func _coluna_de_fumaca(sup: Dictionary, base: Vector3, largura: float,
		altura: float) -> void:
	if not sup.has(&"fumaca_baseado"):
		sup[&"fumaca_baseado"] = PSXMesh.dados_vazios()
	for giro: float in [0.0, PI * 0.5]:
		# Transparente no pe e cheia no alto: a fumaca so vira visivel depois de
		# subir alguns centimetros, e comecar opaca no cinzeiro poe um bloco
		# branco em cima da bituca.
		var d := PSXMesh.placa_dados(Vector2(largura, altura), altura * 0.5,
			Color(1.0, 0.94, 0.86, 0.68))
		PSXMesh.acumular(sup[&"fumaca_baseado"], d,
			Transform3D(Basis(Vector3.UP, giro),
				base + Vector3(0.0, altura * 0.5, 0.0)))


# --- luz e gente ------------------------------------------------------------

## Nao ha lampada de teto.
##
## E a decisao mais importante do comodo. A sala e iluminada pela TV, por uma
## luminaria fraca no canto do sofa e pelas brasas — e e isso que faz o lugar
## ser o que e. Com luz de teto, tudo aqui vira uma sala de estar com objetos
## espalhados.
static func _luzes(props: Array[Dictionary]) -> void:
	# Amber um pouco mais forte e um segundo ponto quente perto da mesa:
	# sem luz de teto, a sala precisa de calor espalhado para ler umida.
	props.append({
		"tipo": "lampada",
		"pos": Vector3(0.75, 1.42, 2.05),
		"padrao": Lampada.Padrao.ESTAVEL,
		"semente": 7731,
		"cor": Color("ffc089"),
		"energia": 1.15,
		"alcance": 3.8,
	})
	props.append({
		"tipo": "lampada",
		"pos": Vector3(2.55, 1.05, 3.0),
		"padrao": Lampada.Padrao.ESTAVEL,
		"semente": 7732,
		"cor": Color("ffb070"),
		"energia": 0.55,
		"alcance": 2.6,
	})


## Quem esta na sala.
##
## Dois sao os jogadores e nao saem do lugar. Os outros circulam. A maioria esta
## fumando, que e o que da nome a casa — mas nao todos: um comodo em que todo
## mundo faz a mesma coisa ao mesmo tempo le como coreografia.
static func _gente(props: Array[Dictionary], semente: int) -> void:
	# Os pontos por onde os que circulam andam. Ficam longe do eixo entre a TV e
	# quem esta jogando: alguem passando na frente da tela a cada dez segundos
	# seria engracado uma vez e irritante nas outras.
	var pontos: Array[Vector3] = [
		Vector3(1.5, 0.0, 1.7), Vector3(1.7, 0.0, 4.6),
		Vector3(5.6, 0.0, 2.0), Vector3(5.9, 0.0, 4.2),
		Vector3(2.9, 0.0, 1.5), Vector3(5.1, 0.0, 5.4),
	]
	var meio := Vector3(3.4, 0.0, 3.2)

	# O que esta sentado no chao, e o que esta de pe atras dele.
	props.append(_pessoa(semente, 101, Vector3(3.44, 0.0, 3.62),
		Convidado.Papel.SENTADO, false, Vector3(TV.x, 0.0, TV.z), pontos))
	props.append(_pessoa(semente, 202, Vector3(4.16, 0.0, 3.30),
		Convidado.Papel.EM_PE, false, Vector3(TV.x, 0.0, TV.z), pontos))

	# Mais quatro circulando. Tres fumando: a proporcao importa e e o que separa
	# uma casa de amigos de um cartaz.
	var lugares: Array[Vector3] = [
		Vector3(1.35, 0.0, 2.6), Vector3(5.5, 0.0, 3.1),
		Vector3(2.2, 0.0, 4.8), Vector3(5.3, 0.0, 5.1),
	]
	for k in lugares.size():
		props.append(_pessoa(semente, 303 + k * 97, lugares[k],
			Convidado.Papel.LIVRE, k != 2, meio, pontos))


static func _pessoa(semente: int, sal: int, onde: Vector3, papel: int,
		fuma: bool, foco: Vector3, pontos: Array[Vector3]) -> Dictionary:
	return {
		"tipo": "convidado",
		"pos": onde,
		"semente": semente + sal,
		"papel": papel,
		"fuma": fuma,
		"foco": foco,
		"pontos": pontos,
	}
