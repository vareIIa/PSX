## O carro de PS1: caixas chanfradas, um atlas so e cor de vertice.
##
## Mesma economia do Corpo, pelo mesmo motivo. A variedade nao vem de modelo
## novo — vem de PROPORCAO (cinco silhuetas), de CELULA do atlas e da cor de
## vertice que multiplica a lataria. Um Fusca vermelho e uma perua bege sao o
## mesmo codigo com quatro numeros trocados.
##
## Orcamento de chamada de desenho
## -------------------------------
## Quatro por carro, e nao seis:
##
##   corpo    lataria, vidro, grade, para-choque, placa   — uma malha, um atlas
##   luzes    farol e lanterna, material emissivo         — precisa ser separada
##   frente   as DUAS rodas dianteiras numa malha so
##   tras     as DUAS rodas traseiras numa malha so
##
## As rodas de um eixo cabem na mesma malha porque giram juntas: o eixo inteiro
## roda em torno do proprio X e, na frente, esterca em torno do proprio Y. Uma
## malha por roda daria oito chamadas por carro e o transito sozinho comeria o
## teto de 120 do ART-BIBLE secao 10.
##
## O chanfro do teto nao e capricho. Uma caixa em cima de outra le como caixa em
## cima de outra; o corte de 45 graus na coluna A e o unico detalhe que faz a
## silhueta ler como "carro" a trinta metros dentro da nevoa, que e a distancia
## em que quase todo carro deste jogo vai ser visto.
class_name Carroceria
extends RefCounted

## O carro e a unica classe de malha do jogo com `use_snap = false`, e nao e
## descuido: e a mesma decisao que mat_carro_luz ja tinha tomado para o farol.
##
## O snap arredonda o vertice numa grade de tela. Numa parede parada isso e o
## tremor de PS1 que o ART-BIBLE secao 3 pede. Num carro nao: o carro anda em
## relacao a camera TODO frame, e e feito de decalque fino empilhado — friso,
## veneziana, macaneta, linha de porta, vidro colado um centimetro por fora da
## chapa. Cada um desses fica com a borda tremendo contra a chapa de tras.
##
## Medido na vitrine, varrendo a camera 4,5 graus em doze capturas e contando
## pixel que troca de claro para escuro tres vezes ou mais:
##
##     snap 240x135 (o de antes)   237 pixels
##     snap 480x270 (grade fina)   217 pixels
##     sem snap                    114 pixels
##
## A grade fina quase nao ajuda — o custo esta em existir snap, nao no tamanho
## do passo. Os 114 que sobram sao geometria de um pixel a 480x270, que e o
## limite da resolucao e nao tem conserto em shader.
const MATERIAL := "res://resources/materials/mat_carro.tres"
const MATERIAL_LUZ := "res://resources/materials/mat_carro_luz.tres"

const MOD_FUSCA := "res://src/render/carroceria_fusca.gd"
const MOD_MAREA := "res://src/render/carroceria_marea.gd"

## Atlas de 256x256 dividido em celulas de 32. Ver tools/gerar_carro.py.
const CELULA := 32.0
const ATLAS := 256.0

## Passo de subdivisao dos paineis, em metros.
##
## O carro era a UNICA malha do jogo que saia sem subdividir: `_face` pedia
## `placa_dados(..., 100.0)` enquanto a cidade inteira usa PSXMesh.MAX_QUAD_M.
## Com a lateral toda num quadrilatero so, a UV afim do psx_surface erra o meio
## do painel em cerca de 15% do comprimento — 65 cm num carro de 4,3 m — e o
## erro MUDA com o angulo da camera. E exatamente isso que se ve como "a textura
## escorrega quando a camera anda".
##
## Marea e Fusca nao tinham o defeito porque o casco varrido ja nasce em treze
## estacoes. Isto aqui e a mesma subdivisao, so que escrita como numero.
##
## O numero saiu de medida, e nao de gosto: capturando o mesmo sedan com
## `use_affine` ligado e desligado, a diferenca entre as duas imagens E o erro
## afim. Contando pixel com erro acima de 16 de 255:
##
##     sem subdividir (100 m)   1422 pixels    48 triangulos por carro
##     passo 1,60 m             1137 pixels
##     passo 0,85 m              490 pixels   184 triangulos
##     passo 0,45 m              357 pixels   458 triangulos
##
## De 0,85 para 0,45 sobram 9% de erro e o carro paga 274 triangulos. Nao vale.
const PASSO_PAINEL := 0.85

enum Modelo { SEDA, HATCH, PERUA, PICAPE, TAXI, MAREA, FUSCA }

## Celulas, por (coluna, linha) no atlas.
const C_LATARIA := Vector2i(0, 0)
const C_LATARIA_SUJA := Vector2i(1, 0)
const C_CAPO := Vector2i(2, 0)
const C_TETO := Vector2i(3, 0)
const C_PORTA := Vector2i(4, 0)
const C_TRASEIRA := Vector2i(5, 0)
const C_SOLEIRA := Vector2i(6, 0)
const C_CACAMBA := Vector2i(7, 0)

const C_PARABRISA := Vector2i(0, 1)
const C_VIDRO_LADO := Vector2i(1, 1)
const C_VIDRO_TRAS := Vector2i(2, 1)
const C_GRADE := Vector2i(3, 1)
const C_PARACHOQUE := Vector2i(4, 1)
const C_PLACA := Vector2i(5, 1)
const C_LETREIRO_TAXI := Vector2i(6, 1)
const C_FUNDO := Vector2i(7, 1)

const C_PNEU := Vector2i(0, 2)
const C_CALOTA := Vector2i(1, 2)

const C_FAROL := Vector2i(0, 3)
const C_LANTERNA := Vector2i(1, 3)
const C_FREIO := Vector2i(2, 3)
const C_RE := Vector2i(3, 3)
## Amarelo de seta. Nao ha celula dedicada de pisca no atlas do carro; reusa a
## lente amarela do semaforo que ja mora na mesma folha (col 5, lin 3).
const C_PISCA := Vector2i(5, 3)

## Cores de lataria. Faixa de valor larga de proposito: um transito todo em tons
## medios vira uma mancha so na nevoa. Precisa haver carro escuro e carro claro
## na mesma rua para a fila ter leitura.
const TINTAS: Array[Color] = [
	Color(0.82, 0.80, 0.76), Color(0.24, 0.26, 0.30),
	Color(0.62, 0.16, 0.14), Color(0.16, 0.30, 0.46),
	Color(0.70, 0.66, 0.42), Color(0.34, 0.42, 0.34),
	Color(0.90, 0.88, 0.84), Color(0.44, 0.30, 0.22),
	Color(0.14, 0.15, 0.17), Color(0.58, 0.58, 0.60),
	Color(0.72, 0.44, 0.20), Color(0.30, 0.46, 0.50),
]

## Amarelo de taxi. Fora da tabela porque nao e sorteado: o taxi e reconhecivel
## ou nao e taxi.
const TINTA_TAXI := Color(0.94, 0.76, 0.16)
## Bege sujo/enferrujado das refs do Fusca. Fora da tabela: o Fusca do transito
## tem que ler enferrujado, nao sortear creme limpo de Marea.
const TINTA_FUSCA := Color(0.78, 0.72, 0.62)

## Medidas por modelo, em metros.
##   comprimento, largura, altura do capo, altura do teto, entre-eixos,
##   balanco dianteiro, tamanho da cabine em fracao do comprimento
## A linha de cintura ("capo") ficou ACIMA da metade da altura em todos eles, e
## nao abaixo. Com o capo baixo de antes a estufa era mais alta que a lateral do
## casco e o carro lia como um aquario sobre rodas; num carro de verdade a
## lataria e a parte alta e o vidro e a faixa fina. E a mesma correcao que fez o
## Corpo parar de parecer um boneco de palito: proporcao, nao poligono.
const MEDIDAS := {
	Modelo.SEDA:   {"c": 4.30, "l": 1.70, "capo": 0.90, "teto": 1.42, "eixo": 2.55, "cabine": 0.46},
	Modelo.HATCH:  {"c": 3.75, "l": 1.62, "capo": 0.88, "teto": 1.46, "eixo": 2.30, "cabine": 0.50},
	Modelo.PERUA:  {"c": 4.55, "l": 1.74, "capo": 0.92, "teto": 1.58, "eixo": 2.62, "cabine": 0.60},
	Modelo.PICAPE: {"c": 4.70, "l": 1.78, "capo": 0.98, "teto": 1.58, "eixo": 2.80, "cabine": 0.34},
	Modelo.TAXI:   {"c": 4.30, "l": 1.70, "capo": 0.90, "teto": 1.42, "eixo": 2.55, "cabine": 0.46},
	# Marea e Fusca nao sao caixas chanfradas: cada um tem modulo proprio, com
	# perfil varrido, e estas medidas espelham COMP_REF/LARG_REF/ALT_REF de la.
	# "capo" aqui e a linha de cintura e "cabine" a fracao da estufa — nenhum dos
	# dois desenha o carro, mas carro_cabine.gd ainda le os dois.
	# Sedan tres-volumes das refs: 4,36 x 1,66 x 1,39 m, entre-eixos 2,57.
	Modelo.MAREA:  {"c": 4.36, "l": 1.66, "capo": 0.93, "teto": 1.39, "eixo": 2.57, "cabine": 0.50},
	# Fusca 1300 de verdade: 4,03 x 1,55 x 1,50 m, entre-eixos 2,40.
	Modelo.FUSCA:  {"c": 4.03, "l": 1.55, "capo": 0.97, "teto": 1.50, "eixo": 2.40, "cabine": 0.46},
}

## Quanto a cabine e mais estreita que o casco, somando os dois ombros.
##
## Existe como constante porque DUAS funcoes dependem dela: _lataria desenha a
## cabine com esta largura e _vidros encaixa para-brisa e vigia dentro dela. Com
## o numero repetido nas duas, estreitar a cabine deixou os vidros 8 cm mais
## largos que ela — para-brisa e vigia saiam pelas laterais como duas abas.
const RECUO_CABINE := 0.22
## Folga do para-brisa e do vigia para dentro da cabine, somando os dois lados.
const FOLGA_VIDRO := 0.12

## Quanto o vidro lateral recua para dentro do quadrilatero da cabine, e quanto
## a mais ele recua na aresta de baixo para formar a cintura.
const MOLDURA := 0.16
const MOLDURA_BASE := 0.34

## Cor do vidro. Nao multiplica a tinta da lataria: vidro de carro vermelho nao
## e vermelho. Fica levemente azulado e sempre escuro, que e o que faz o
## contraste com a lataria existir em qualquer uma das doze tintas.
const VIDRO := Color(0.20, 0.23, 0.27)

## Paleta compartilhada com Marea e Fusca.
##
## Os dois carros de modulo ganharam um vocabulario que os carros de caixa nao
## tinham: cromo de friso, plastico de para-choque, sombra de recorte e o tom da
## cava. Sem ele a lateral de um sedan e uma chapa de quatro metros sem nada que
## se conte nela, e era por isso que o transito lia como caixa deslizando ao
## lado de dois carros de verdade.
const CROMO := Color(0.70, 0.70, 0.72)
const PLASTICO := Color(0.30, 0.30, 0.31)
const SOMBRA := Color(0.10, 0.10, 0.11)
## Fundo da caixa de roda. Nao e SOMBRA: o pneu tambem e quase preto e, com os
## dois no mesmo tom, a roda desaparece dentro do arco.
const CAVA := Color(0.17, 0.15, 0.13)
## Fresta de painel: risco, nao canaleta. Preto puro no capo le como listra
## pintada; este tom continua sendo lataria.
const FRESTA := Color(0.26, 0.22, 0.17)
## Barro da soleira. A sujeira era so uma celula de atlas trocada — chapada, sem
## direcao. Como gradiente de vertice ela SOBE do chao, que e o unico jeito de
## ler como sujeira de rua e nao como pintura.
const BARRO := Color(0.42, 0.33, 0.22)
const SUJEIRA_FORCA := 0.55

## Contorno do arco de roda, em offsets (dz, dy) a partir do centro dela.
##
## Quadrado de canto arredondado, e nao semicirculo: e a assinatura da caixa
## oitentista, e e o mesmo contorno do Marea. O pneu tem 0,30 de raio e a folga
## de 6 cm e o que faz ele PREENCHER o arco em vez de boiar num buraco escuro.
const ARCO: Array[Vector2] = [
	Vector2(0.375, 0.00), Vector2(0.335, 0.235), Vector2(0.145, 0.365),
	Vector2(-0.105, 0.355), Vector2(-0.295, 0.255), Vector2(-0.375, 0.00),
]
## Quanto o beicinho do arco projeta para fora da lataria.
const ABA_ARCO := 0.017

const RAIO_RODA := 0.30
const LARGURA_RODA := 0.20
## Altura do assoalho. E o que separa um carro de um carrinho de rolima: abaixo
## disso a caixa raspa no meio-fio em toda subida de rampa.
const ASSOALHO := 0.26


## Os modulos de Fusca e Marea, resolvidos em RUNTIME e nao por class_name.
##
## Os dois precisam das celulas do atlas e de uv(), que moram aqui; e esta
## funcao precisa deles. Escrito com class_name dos dois lados isso e uma
## referencia ciclica: o GDScript nao registra nenhuma das classes e o projeto
## inteiro para de compilar com "Identifier not declared".
##
## load() nao e dependencia de parse, entao quebra o ciclo sem duplicar as
## celulas do atlas em tres arquivos — que era a outra saida, e a que deixa as
## copias divergirem no primeiro dia em que alguem mexer na folha.
##
## CUIDADO: por ser runtime, erro de parse nesses modulos NAO aparece em
## `--headless --quit`. O projeto sobe limpo e o carro sai pela metade. Quem
## pega isso e `game/_check_fusca.gd`, que carrega os dois antes de medir.
static var _modulos: Dictionary = {}


static func _modulo(caminho: String) -> GDScript:
	if not _modulos.has(caminho):
		_modulos[caminho] = load(caminho) as GDScript
	return _modulos[caminho]


## Tudo que o Carro precisa para se montar.
## `com_vidros_frente` false tira para-brisa e vigia. Serve para a camera em
## primeira pessoa dentro do carro: mesmo com uma face so, o vidro atrapalha a
## leitura da cena a poucos centimetros do olho.
static func montar(modelo: Modelo, tinta: Color, semente: int,
		com_vidros_frente: bool = true) -> Dictionary:
	var m: Dictionary = MEDIDAS[modelo]
	var comp: float = m["c"]
	var larg: float = m["l"]
	var capo: float = m["capo"]
	var teto: float = m["teto"]
	var eixo: float = m["eixo"]
	var cabine: float = m["cabine"]

	var cor := TINTA_TAXI if modelo == Modelo.TAXI else tinta
	if modelo == Modelo.FUSCA:
		cor = TINTA_FUSCA
	elif modelo == Modelo.MAREA:
		# Creme das refs; suja ainda depende da semente (1 em 7).
		cor = Color(0.90, 0.88, 0.80)
	# Fusca das refs e sempre sujo; os outros continuam com a chance de 1 em 7.
	var suja := modelo == Modelo.FUSCA or (semente % 7) == 0

	var corpo := PSXMesh.dados_vazios()
	var luzes := PSXMesh.dados_vazios()

	# Fusca e Marea saem inteiros dos modulos proprios: casco, vidro, arco, farol
	# e para-choque. Nenhum dos dois e uma caixa chanfrada com medidas diferentes
	# — sao perfis varridos, e nao havia como escrever isso aqui sem afundar as
	# funcoes genericas em "if modelo".
	if modelo == Modelo.FUSCA:
		_modulo(MOD_FUSCA).montar(corpo, luzes, comp, larg, teto, cor,
			com_vidros_frente)
	elif modelo == Modelo.MAREA:
		_modulo(MOD_MAREA).montar(corpo, luzes, comp, larg, teto, cor,
			com_vidros_frente)
	else:
		_lataria(corpo, comp, larg, capo, teto, cabine, cor, suja)
		if com_vidros_frente:
			_vidros(corpo, comp, larg, capo, teto, cabine)
		# As tres pecas que vieram do Marea. Nenhuma delas depende do modelo:
		# todas se posicionam por medida (largura, entre-eixos, extensao da
		# cabine), entao a picape ganha arco e friso pelo mesmo codigo do sedan.
		_arcos_roda(corpo, larg, eixo, cor, teto)
		_flancos(corpo, comp, larg, capo, teto, cabine, modelo)
		_frestas_capo(corpo, comp, larg, capo, cabine)
		_frente_e_tras(corpo, luzes, comp, larg, capo, cor, modelo)
		if modelo == Modelo.PICAPE:
			_cacamba(corpo, comp, larg, capo, cabine, cor)
		if modelo == Modelo.TAXI:
			_letreiro(corpo, larg, teto, comp, cabine)

	# A montagem acima trabalha com +Z na frente, que e como se desenha um carro
	# olhando para ele. O motor nao: Node3D aponta para -Z, e VehicleBody3D poe a
	# tracao e o esterco nesse mesmo sentido. Sem esta meia volta o carro inteiro
	# — grade, farol, placa, para-brisa — fica virado para tras e o transito anda
	# de re pela cidade com o vigia na frente.
	#
	# A volta e dada aqui, uma vez, em vez de espalhar sinais trocados por cinco
	# funcoes de geometria onde um deles ficaria para tras.
	var meia_volta := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var corpo_final := PSXMesh.dados_vazios()
	var luzes_final := PSXMesh.dados_vazios()
	PSXMesh.acumular(corpo_final, corpo, meia_volta)
	PSXMesh.acumular(luzes_final, luzes, meia_volta)

	# Bitola. Nos genericos ela sai da largura, porque num sedan de caixa a roda
	# fica rente a lateral. Nos dois carros de modulo, nao: a largura e feita
	# pelo para-lama (Fusca) ou pela aba do arco (Marea), e medindo a bitola pela
	# largura cheia o pneu nascia por FORA do beicinho — de frente o carro
	# aparecia com as quatro rodas para fora da carroceria, como um buggy.
	# So o Fusca estreita. Nele a largura de 1,55 m e feita pelos quatro
	# para-lamas, e medindo a bitola pela largura cheia o pneu nascia por FORA do
	# beicinho — o carro aparecia com as quatro rodas de fora, como um buggy.
	#
	# O Marea quase nao estreita, e de proposito. A lateral dele e chata: nao ha
	# para-lama, e o arco e um decalque escuro pintado na chapa. Se a roda recuar
	# para dentro da lataria, o decalque passa na frente e tapa a metade de cima
	# do pneu — sobra uma calota boiando num buraco preto. Rente a chapa, o pneu
	# fica na frente do decalque, que e como um arco de roda le num sedan caixa.
	var larg_eixo := larg
	if modelo == Modelo.FUSCA:
		larg_eixo = larg - 0.20
	elif modelo == Modelo.MAREA:
		larg_eixo = larg - 0.06

	return {
		"corpo": PSXMesh.dados_para_mesh(corpo_final),
		"luzes": PSXMesh.dados_para_mesh(luzes_final),
		"eixo_frente": _eixo(larg_eixo),
		"eixo_tras": _eixo(larg_eixo),
		"triangulos": (PSXMesh.dados_triangulos(corpo_final)
			+ PSXMesh.dados_triangulos(luzes_final)),
		"comprimento": comp,
		"largura": larg,
		"altura": teto,
		"entre_eixos": eixo,
		"bitola": _bitola(larg_eixo),
		"balanco": (comp - eixo) * 0.5,
		"cor": cor,
	}


# --- pecas ------------------------------------------------------------------

## Retangulo de UV de uma celula, com meio texel de margem para o filtro nearest
## nao puxar a celula vizinha na borda.
static func uv(c: Vector2i) -> Rect2:
	var m := 0.5 / ATLAS
	return Rect2(
		Vector2(float(c.x) * CELULA / ATLAS + m, float(c.y) * CELULA / ATLAS + m),
		Vector2(CELULA / ATLAS - m * 2.0, CELULA / ATLAS - m * 2.0))


## `barro` > 0 troca a cor chapada por um gradiente de altura, com a cor limpa
## nesse Y e a sujeira descendo dai ate o chao. E a receita do Marea e do Fusca,
## e so vale porque `_face` agora subdivide: num quadrilatero de quatro vertices
## um gradiente vertical nao tem onde acontecer.
static func _face(dados: Dictionary, tamanho: Vector2, xform: Transform3D,
		cor: Color, celula: Vector2i, barro: float = 0.0) -> void:
	var inicio := (dados["v"] as PackedVector3Array).size()
	var d := PSXMesh.placa_dados(tamanho, PASSO_PAINEL, Color.WHITE)
	var r := uv(celula)
	var uvs: PackedVector2Array = d["uv"]
	for k in uvs.size():
		uvs[k] = r.position + uvs[k] * r.size
	d["uv"] = uvs
	PSXMesh.acumular_tingido(dados, d, xform, cor)
	if barro <= 0.0:
		return
	var vs: PackedVector3Array = dados["v"]
	var cs: PackedColorArray = dados["c"]
	for k in range(inicio, cs.size()):
		cs[k] = _sujo(cor, vs[k].y, barro)
	dados["c"] = cs


## Sujeira por altura: barro na soleira, cor limpa no teto.
##
## Ao quadrado de proposito. Linear pinta o carro inteiro de marrom claro; ao
## quadrado a sujeira fica concentrada no primeiro palmo acima do chao, que e
## onde a roda joga barro de verdade.
static func _sujo(cor: Color, y: float, teto: float) -> Color:
	var f := clampf((teto - y) / maxf(teto, 0.001), 0.0, 1.0)
	return cor.lerp(BARRO, f * f * SUJEIRA_FORCA)


## Quadrilatero arbitrario, acumulado direto. Atalho para `_quad_lateral`, que
## devolve dados soltos e obriga todo chamador a lembrar do `acumular`.
static func _quad(dados: Dictionary, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3, celula: Vector2i, cor: Color, fora: Vector3) -> void:
	PSXMesh.acumular(dados, _quad_lateral(a, b, c, d, celula, cor, fora),
		Transform3D.IDENTITY)


## Placa com verso. O psx_surface usa cull_back; vidro de uma face some quando a
## camera esta do outro lado (cabine olhando para fora, ou rua olhando o verso
## de um para-brisa invertido). Marea e Fusca herdam o mesmo caminho — sem
## material novo, sem celula nova: C_PARABRISA / C_VIDRO_* + VIDRO dos dois lados.
static func _face_dois_lados(dados: Dictionary, tamanho: Vector2, xform: Transform3D,
		cor: Color, celula: Vector2i) -> void:
	_face(dados, tamanho, xform, cor, celula)
	_face(dados, tamanho,
		xform * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO), cor, celula)


## Um paralelepipedo com celula por face, e sem as faces que ninguem ve.
static func _caixa(dados: Dictionary, tamanho: Vector3, centro: Vector3,
		cor: Color, lado: Vector2i, frente: Vector2i, topo: Vector2i,
		com_base: bool = false, barro: float = 0.0) -> void:
	var h := tamanho * 0.5
	# +Z e a frente do carro.
	_face(dados, Vector2(tamanho.x, tamanho.y),
		Transform3D(Basis(), centro + Vector3(0, 0, h.z)), cor, frente, barro)
	_face(dados, Vector2(tamanho.x, tamanho.y),
		Transform3D(Basis(Vector3.UP, PI), centro - Vector3(0, 0, h.z)), cor, frente, barro)
	_face(dados, Vector2(tamanho.z, tamanho.y),
		Transform3D(Basis(Vector3.UP, PI * 0.5), centro + Vector3(h.x, 0, 0)), cor, lado, barro)
	_face(dados, Vector2(tamanho.z, tamanho.y),
		Transform3D(Basis(Vector3.UP, -PI * 0.5), centro - Vector3(h.x, 0, 0)), cor, lado, barro)
	_face(dados, Vector2(tamanho.x, tamanho.z),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), centro + Vector3(0, h.y, 0)), cor, topo, barro)
	if com_base:
		_face(dados, Vector2(tamanho.x, tamanho.z),
			Transform3D(Basis(Vector3.RIGHT, PI * 0.5), centro - Vector3(0, h.y, 0)),
			cor * 0.4, C_FUNDO)


## Casco e cabine.
##
## A cabine e um trapezio, e nao uma caixa: as duas laterais sao quadrilateros
## com a aresta de cima recuada, o que produz a coluna A inclinada. Sao quatro
## triangulos a mais e e o unico lugar do carro onde vale gastar.
static func _lataria(dados: Dictionary, comp: float, larg: float, capo: float,
		teto: float, cabine: float, cor: Color, suja: bool) -> void:
	var celula_lado := C_LATARIA_SUJA if suja else C_PORTA
	var altura_casco := capo - ASSOALHO

	# Casco, do assoalho ate a linha do capo. Carro sujo leva o gradiente de
	# altura do Marea e do Fusca por cima da celula suja; carro limpo continua
	# chapado, que e o que mantem a fila da rua com carro limpo e carro sujo.
	_caixa(dados, Vector3(larg, altura_casco, comp),
		Vector3(0.0, ASSOALHO + altura_casco * 0.5, 0.0), cor,
		celula_lado, C_TRASEIRA, C_CAPO, true, teto if suja else 0.0)

	# Cabine. Comeca depois do capo e termina antes da traseira.
	var comp_cabine := comp * cabine
	var z0 := -comp * 0.06 - comp_cabine * 0.5
	var z1 := z0 + comp_cabine
	var alt_cabine := teto - capo
	var recuo := alt_cabine * 0.55
	# A cabine e sensivelmente mais estreita que o casco. Com os 6 cm de antes
	# teto e casco liam como uma caixa unica; o ombro de 11 cm de cada lado e o
	# que faz a silhueta ter greenhouse, e nao custa triangulo nenhum.
	var lc := larg - RECUO_CABINE
	var h := lc * 0.5

	# Teto.
	_face(dados, Vector2(lc, comp_cabine - recuo * 2.0),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
			Vector3(0.0, teto, (z0 + z1) * 0.5)), cor, C_TETO)

	# As duas laterais da cabine, como quadrilateros com a aresta de cima curta.
	#
	# Sao DUAS camadas por lado, e nao uma. A camada de fora era so a celula de
	# vidro tingida pela cor do carro, o que fazia a cabine inteira ser janela:
	# de longe lia como um caixote preto pousado no capo, sem coluna, sem porta,
	# sem teto. Agora o quadrilatero grande e lataria e o vidro e um recorte
	# menor colado meio centimetro por fora — a moldura que sobra E a coluna A,
	# a coluna C e a linha de cintura, de graca, sem geometria de moldura.
	#
	# Custa quatro triangulos por carro. E o segundo lugar, depois do chanfro do
	# teto, onde vale gastar: e o detalhe que separa "carro" de "caixa".
	for s: float in [1.0, -1.0]:
		var fora := Vector3(s, 0.0, 0.0)
		var a := Vector3(s * h, capo, z0)
		var b := Vector3(s * h, capo, z1)
		var c := Vector3(s * h, teto, z1 - recuo)
		var d := Vector3(s * h, teto, z0 + recuo)
		PSXMesh.acumular(dados,
			_quad_lateral(a, b, c, d, celula_lado, cor, fora),
			Transform3D.IDENTITY)
		var desloca := fora * 0.006
		# So face externa. Face interna opaca bloquearia a cabine em primeira
		# pessoa, que e o mesmo P0 do para-brisa.
		PSXMesh.acumular(dados,
			_quad_lateral(
				_encolher(a, b, c, d, 0) + desloca,
				_encolher(a, b, c, d, 1) + desloca,
				_encolher(a, b, c, d, 2) + desloca,
				_encolher(a, b, c, d, 3) + desloca,
				C_VIDRO_LADO, VIDRO, fora),
			Transform3D.IDENTITY)



## Puxa um canto do quadrilatero da cabine em direcao ao centro dele.
##
## A moldura nao e uniforme de proposito: encolhe mais em baixo (MOLDURA_BASE)
## que em cima, porque a faixa de lataria embaixo da janela — a cintura — e o
## que da altura visual a porta. Uma moldura igual dos quatro lados le como
## adesivo colado na lateral.
static func _encolher(a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		k: int) -> Vector3:
	var cantos := [a, b, c, d]
	var centro: Vector3 = (a + b + c + d) * 0.25
	var p: Vector3 = cantos[k]
	var q := p.lerp(centro, MOLDURA)
	# k 0 e 1 sao os cantos de baixo.
	if k < 2:
		q.y = lerpf(p.y, centro.y, MOLDURA_BASE)
	return q


## Quadrilatero arbitrario com uma celula do atlas. Serve para as faces que nao
## sao retangulos, que aqui sao as duas laterais da cabine.
## `fora` e para que lado a face olha. Nao da para deduzir do proprio poligono:
## as duas laterais da cabine sao a mesma sequencia de pontos espelhada em X, o
## que produz a MESMA ordem de giro nas duas — uma acaba virada para dentro e o
## culling come ela. Era esse o defeito que fazia o carro perder a cabine
## inteira quando visto pelo lado direito e virar uma laje na rua.
static func _quad_lateral(a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		celula: Vector2i, cor: Color, fora: Vector3) -> Dictionary:
	var dados := PSXMesh.dados_vazios()
	var r := uv(celula)
	var v: PackedVector3Array = dados["v"]
	var n: PackedVector3Array = dados["n"]
	var u: PackedVector2Array = dados["uv"]
	var cc: PackedColorArray = dados["c"]
	var i: PackedInt32Array = dados["i"]
	var normal := (b - a).cross(d - a).normalized()
	# Endireita normal e giro de uma vez so: inverter a normal sem inverter os
	# indices conserta a luz e deixa a face invisivel do mesmo jeito.
	var invertido := normal.dot(fora) < 0.0
	if invertido:
		normal = -normal
	# Subdividido como o resto do jogo: a lateral da cabine tem 2 m de corda e
	# num quadrilatero so a UV afim escorrega junto com a camera.
	var cols := maxi(1, ceili(
		maxf(a.distance_to(b), d.distance_to(c)) / PASSO_PAINEL))
	var linhas := maxi(1, ceili(
		maxf(a.distance_to(d), b.distance_to(c)) / PASSO_PAINEL))
	for j in linhas + 1:
		var fy := float(j) / float(linhas)
		for k in cols + 1:
			var fx := float(k) / float(cols)
			v.append(a.lerp(b, fx).lerp(d.lerp(c, fx), fy))
			n.append(normal)
			cc.append(cor)
			u.append(r.position + Vector2(fx, 1.0 - fy) * r.size)
	var passo := cols + 1
	for j in linhas:
		for k in cols:
			var q := j * passo + k
			# CONVENCAO DE GIRO DO PROJETO: a face aparece do lado OPOSTO ao
			# produto vetorial do giro. Quem prova e PSXMesh.placa_dados, que
			# declara normal +Z e emite [0,2,1] — cujo produto vetorial da -Z.
			#
			# Este arquivo estava com os dois ramos TROCADOS, e por isso as duas
			# laterais da cabine — e o vidro colado nelas — sairam viradas para
			# DENTRO em todos os carros de caixa. Sedan, hatch, perua, picape e
			# taxi apareciam como uma laje com o para-brisa boiando em cima: o
			# teto (feito por `_face`, que sempre esteve certo) era a unica peca
			# da estufa que restava. Marea e Fusca escapavam por usarem o `quad`
			# do CarroceriaVarrida, que ja tinha a convencao correta.
			#
			# Ver memoria `giro-de-face-aponta-ao-contrario`.
			if invertido:
				i.append_array([q, q + 1, q + passo + 1,
					q, q + passo + 1, q + passo])
			else:
				i.append_array([q, q + passo + 1, q + 1,
					q, q + passo, q + passo + 1])
	dados["v"] = v
	dados["n"] = n
	dados["uv"] = u
	dados["c"] = cc
	dados["i"] = i
	return dados


## Para-brisa e vigia. Ficam colados por fora da cabine, meio centimetro a
## frente da lateral, e nunca arredondam junto com ela — e o mesmo cuidado que a
## vitrine do mercado exigiu.
static func _vidros(dados: Dictionary, comp: float, larg: float, capo: float,
		teto: float, cabine: float) -> void:
	var comp_cabine := comp * cabine
	var z0 := -comp * 0.06 - comp_cabine * 0.5
	var z1 := z0 + comp_cabine
	var alt := teto - capo
	var recuo := alt * 0.55
	var lv := larg - RECUO_CABINE - FOLGA_VIDRO

	# Para-brisa, UMA face virada para FORA. Com o cull_back do psx_surface a
	# camera de dentro ve o verso cullado e enxerga a rua. Face dos dois lados
	# em vidro OPACO preenche o verso e o motorista fica olhando para um plano
	# preto solido — foi o P0 da Estrada Velha. Nao voltar a _face_dois_lados
	# aqui sem alfa de verdade no material.
	var incl := atan2(recuo, alt)
	var xf := Transform3D(Basis(Vector3.RIGHT, -incl),
		Vector3(0.0, capo + alt * 0.5, z1 - recuo * 0.5 + 0.01))
	_face(dados, Vector2(lv, sqrt(alt * alt + recuo * recuo)), xf,
		VIDRO, C_PARABRISA)

	# Vigia: mesma regra, so face externa.
	var xf2 := Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -incl),
		Vector3(0.0, capo + alt * 0.5, z0 + recuo * 0.5 - 0.01))
	_face(dados, Vector2(lv, sqrt(alt * alt + recuo * recuo)), xf2,
		VIDRO, C_VIDRO_TRAS)


## Os quatro arcos de roda: cava escura recortada no flanco e a aba em volta.
##
## A cava nao e enfeite. Sem ela o que aparece atras do pneu e a lateral bem
## iluminada do casco, e a roda le como um disco pregado na chapa em vez de uma
## roda dentro de um vao. Foi o que fez o Marea deixar de parecer brinquedo.
##
## Num carro de caixa a superficie e trivial — o flanco e um plano em x fixo —
## entao aqui nao ha a busca por amostragem que o Marea precisa fazer.
static func _arcos_roda(dados: Dictionary, larg: float, eixo: float,
		cor: Color, teto: float) -> void:
	var x := larg * 0.5
	for zc: float in [eixo * 0.5, -eixo * 0.5]:
		for s: float in [1.0, -1.0]:
			var fora := Vector3(s, 0.0, 0.0)
			for k in ARCO.size() - 1:
				var p: Vector2 = ARCO[k]
				var q: Vector2 = ARCO[k + 1]
				# Tres aneis: o de dentro encosta no pneu, o do meio e a borda
				# do recorte, o de fora e o beicinho estufado.
				var d0 := Vector3(s * (x + 0.006), RAIO_RODA + p.y * 0.84,
					zc + p.x * 0.84)
				var d1 := Vector3(s * (x + 0.006), RAIO_RODA + q.y * 0.84,
					zc + q.x * 0.84)
				var b0 := Vector3(s * (x + 0.006), RAIO_RODA + p.y, zc + p.x)
				var b1 := Vector3(s * (x + 0.006), RAIO_RODA + q.y, zc + q.x)
				var a0 := Vector3(s * (x + ABA_ARCO), RAIO_RODA + p.y * 1.10,
					zc + p.x * 1.06)
				var a1 := Vector3(s * (x + ABA_ARCO), RAIO_RODA + q.y * 1.10,
					zc + q.x * 1.06)
				_quad(dados, d0, d1, b1, b0, C_FUNDO, CAVA, fora)
				_quad(dados, b0, b1, a1, a0, C_LATARIA_SUJA,
					_sujo(cor, (b0.y + a0.y) * 0.5, teto) * 0.86, fora)


## Frisos, recortes de porta, macanetas e retrovisor.
##
## De lado, um sedan de caixa e uma chapa de quatro metros sem nada que se conte
## nela: nao da para saber quantas portas tem, nem onde uma acaba. Estes riscos
## custam pouco e sao a maior parte da leitura de perto — mesma conclusao a que
## o Marea chegou no `_flancos` dele.
static func _flancos(dados: Dictionary, comp: float, larg: float, capo: float,
		teto: float, cabine: float, modelo: Modelo) -> void:
	var x := larg * 0.5
	var comp_cabine := comp * cabine
	var z0 := -comp * 0.06 - comp_cabine * 0.5
	var z1 := z0 + comp_cabine
	var x_cab := (larg - RECUO_CABINE) * 0.5
	var y_cint := capo - 0.05
	var duas_portas := modelo == Modelo.PICAPE

	for s: float in [1.0, -1.0]:
		# Soleira: a faixa escura embaixo da porta. Um carro sem ela flutua.
		# Vai so de roda a roda; a faixa longa de antes passava por cima dos
		# dois pneus e escondia a peca que prova que o carro toca o chao.
		_faixa_flanco(dados, s, x, 0.0, comp * 0.40, ASSOALHO + 0.05, 0.10,
			BARRO * 0.62, C_SOLEIRA)
		# Frisao de borracha na porta, na altura em que a rua bate sujeira.
		_faixa_flanco(dados, s, x, 0.0, comp * 0.70,
			ASSOALHO + (capo - ASSOALHO) * 0.46, 0.042,
			PLASTICO * 1.25, C_SOLEIRA)
		# Friso da cintura, logo abaixo das janelas.
		_faixa_flanco(dados, s, x, (z0 + z1) * 0.5, comp_cabine + comp * 0.12,
			y_cint, 0.026, CROMO * 0.95, C_PARACHOQUE)

		# Recortes das portas, do friso ate a soleira.
		#
		# 2 cm de largura, e nao 1,6: a 480x270 uma linha de 1,6 cm da 1,7 pixel
		# a quatro metros e meio, e o que tem menos de dois pixels nao fica
		# parado — rasteja de um lado para o outro conforme a camera anda. E o
		# mesmo motivo pelo qual as ripas da grade subiram de 1,2 para 1,6 cm.
		var linhas: Array[float] = [z1, z0]
		if not duas_portas:
			linhas.append((z0 + z1) * 0.5)
		for z: float in linhas:
			_face(dados, Vector2(0.020, y_cint - ASSOALHO - 0.12),
				Transform3D(Basis(Vector3.UP, s * PI * 0.5),
					Vector3(s * (x + 0.012),
						(ASSOALHO + 0.12 + y_cint) * 0.5, z)),
				SOMBRA, C_SOLEIRA)
		# Coluna B, na cabine. Sobe por CIMA do vidro lateral de proposito: e o
		# risco que faz um vidro unico ler como duas janelas, e sai em dois
		# triangulos em vez de recortar a cabine em dois quadrilateros.
		if not duas_portas:
			_face(dados, Vector2(0.024, teto - capo - 0.08),
				Transform3D(Basis(Vector3.UP, s * PI * 0.5),
					Vector3(s * (x_cab + 0.014), (capo + teto) * 0.5,
						(z0 + z1) * 0.5)),
				SOMBRA, C_SOLEIRA)

		# Macanetas. Ficam ABAIXO do friso da cintura: acima dele a macaneta
		# sobe para dentro do vidro e vira um risco claro boiando na janela.
		var macanetas: Array[float] = [(z0 + z1) * 0.5]
		if not duas_portas:
			macanetas = [z1 - comp_cabine * 0.26, z0 + comp_cabine * 0.26]
		for z: float in macanetas:
			_face(dados, Vector2(0.11, 0.028),
				Transform3D(Basis(Vector3.UP, s * PI * 0.5),
					Vector3(s * (x + 0.014), y_cint - 0.085, z)),
				CROMO * 0.9, C_PARACHOQUE)

	# Retrovisor, so do lado do motorista. Depois da meia volta que `montar`
	# aplica, o +X daqui vira o -X do mundo, que e onde fica o volante.
	var raiz := Vector3(x_cab, capo + 0.03, z1 - 0.05)
	var esp := raiz + Vector3(0.085, 0.045, 0.02)
	_face(dados, Vector2(0.085, 0.055),
		Transform3D(Basis(Vector3.UP, 0.26), esp),
		Color(0.28, 0.32, 0.36), C_VIDRO_LADO)
	_face(dados, Vector2(0.085, 0.055),
		Transform3D(Basis(Vector3.UP, PI + 0.26), esp), PLASTICO, C_PARACHOQUE)
	_quad(dados, raiz, esp + Vector3(0.0, -0.026, 0.0),
		esp + Vector3(0.0, -0.026, 0.028), raiz + Vector3(0.0, 0.0, 0.028),
		C_PARACHOQUE, PLASTICO, Vector3.UP)


## Uma faixa horizontal colada no flanco.
static func _faixa_flanco(dados: Dictionary, s: float, x: float, z: float,
		comprimento: float, y: float, altura: float, cor: Color,
		celula: Vector2i) -> void:
	_face(dados, Vector2(comprimento, altura),
		Transform3D(Basis(Vector3.UP, s * PI * 0.5),
			Vector3(s * (x + 0.010), y, z)), cor, celula)


## As frestas do capo e da tampa do porta-malas.
##
## Duas tiras escuras acompanhando a borda de cada painel. Sem elas o topo do
## carro e uma chapa unica do bico ao rabo e o capo simplesmente nao existe.
static func _frestas_capo(dados: Dictionary, comp: float, larg: float,
		capo: float, cabine: float) -> void:
	var comp_cabine := comp * cabine
	var z0 := -comp * 0.06 - comp_cabine * 0.5
	var z1 := z0 + comp_cabine
	var z_bico := comp * 0.5 - comp * 0.05
	var z_rabo := -comp * 0.5 + comp * 0.05
	for s: float in [1.0, -1.0]:
		for vao: Array in [[z1 + 0.04, z_bico], [z0 - 0.04, z_rabo]]:
			var za: float = vao[0]
			var zb: float = vao[1]
			_face(dados, Vector2(0.028, absf(zb - za)),
				Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
					Vector3(s * larg * 0.37, capo + 0.005, (za + zb) * 0.5)),
				FRESTA, C_SOLEIRA)


## Grade, para-choques, placa e as lampadas.
##
## Reescrito com o vocabulario do Marea. O que havia antes era uma barra de
## grade, uma barra de para-choque e quatro retangulos de luz: de frente, todo
## carro do jogo tinha a mesma cara. Agora a grade tem ripas, o farol tem
## moldura e pisca, a lanterna tem os tres compartimentos — freio, re e seta —
## e o para-choque contorna as pontas em vez de ser tabua pregada no bico.
static func _frente_e_tras(dados: Dictionary, luzes: Dictionary, comp: float,
		larg: float, capo: float, _cor: Color, _modelo: Modelo) -> void:
	var zf := comp * 0.5
	var zt := -comp * 0.5
	var y := ASSOALHO + (capo - ASSOALHO) * 0.52
	var ox := larg * 0.32
	var costas := Basis(Vector3.UP, PI)

	# --- frente ---------------------------------------------------------
	# Grade: painel fundo escuro com ripas claras por cima. A largura de 42% e
	# o que deixa o farol caber do lado sem os dois se sobreporem na mesma
	# profundidade — coplanares, os dois brigam pelo mesmo pixel.
	_face(dados, Vector2(larg * 0.42, 0.17),
		Transform3D(Basis(), Vector3(0.0, y + 0.09, zf + 0.006)),
		SOMBRA, C_GRADE)
	for k in 5:
		_face(dados, Vector2(larg * 0.38, 0.016),
			Transform3D(Basis(), Vector3(0.0,
				lerpf(y + 0.030, y + 0.150, float(k) / 4.0), zf + 0.013)),
			CROMO * 0.86, C_GRADE)

	for s: float in [1.0, -1.0]:
		_face(dados, Vector2(0.30, 0.155),
			Transform3D(Basis(), Vector3(s * ox, y + 0.09, zf + 0.005)),
			Color(0.16, 0.17, 0.19), C_GRADE)
		_face(luzes, Vector2(0.235, 0.105),
			Transform3D(Basis(), Vector3(s * ox, y + 0.09, zf + 0.013)),
			Color.WHITE, C_FAROL)
		# Pisca ambar na quina de fora, colado no farol.
		_face(luzes, Vector2(0.070, 0.115),
			Transform3D(Basis(),
				Vector3(s * (ox + 0.175), y + 0.09, zf + 0.010)),
			Color(1.0, 0.66, 0.16), C_PISCA)

	_parachoque(dados, larg, zf + 0.030, ASSOALHO + 0.10, true)
	_face(dados, Vector2(0.30, 0.10),
		Transform3D(Basis(), Vector3(0.0, ASSOALHO + 0.10, zf + 0.042)),
		Color(0.86, 0.86, 0.84), C_PLACA)

	# --- traseira -------------------------------------------------------
	# Painel fundo com a placa recuada dentro dele: e o degrau que da
	# profundidade a traseira sem gastar geometria de caixa.
	_face(dados, Vector2(larg * 0.42, 0.19),
		Transform3D(costas, Vector3(0.0, y + 0.09, zt - 0.006)),
		SOMBRA * 1.8, C_TRASEIRA)
	_face(dados, Vector2(0.30, 0.10),
		Transform3D(costas, Vector3(0.0, y + 0.09, zt - 0.013)),
		Color(0.84, 0.84, 0.82), C_PLACA)

	for s: float in [1.0, -1.0]:
		var lx := s * ox
		_face(dados, Vector2(0.315, 0.235),
			Transform3D(costas, Vector3(lx, y + 0.10, zt - 0.005)),
			Color(0.12, 0.12, 0.13), C_GRADE)
		_face(luzes, Vector2(0.185, 0.205),
			Transform3D(costas, Vector3(lx - s * 0.055, y + 0.10, zt - 0.012)),
			Color.WHITE, C_LANTERNA)
		_face(luzes, Vector2(0.085, 0.075),
			Transform3D(costas, Vector3(lx - s * 0.055, y + 0.045, zt - 0.018)),
			Color.WHITE, C_RE)
		_face(luzes, Vector2(0.070, 0.205),
			Transform3D(costas, Vector3(lx + s * 0.105, y + 0.10, zt - 0.012)),
			Color(1.0, 0.62, 0.14), C_PISCA)

	_parachoque(dados, larg, zt - 0.030, ASSOALHO + 0.10, false)
	# Escapamento saindo por baixo, do lado do motorista.
	_face(dados, Vector2(0.055, 0.05),
		Transform3D(costas, Vector3(larg * 0.20, ASSOALHO - 0.02, zt - 0.05)),
		Color(0.17, 0.16, 0.15), C_PARACHOQUE)


## Lamina de para-choque, contornando as pontas.
##
## Barra reta le como tabua pregada no bico; para-choque so vira para-choque
## quando dobra para tras nas duas pontas. Tres faces: a frente, o topo que
## pega luz e a barriga, que RECUA para o carro em vez de cair reta — vertical
## ela vira uma aba preta pendurada sob o bico, solta da lataria.
static func _parachoque(dados: Dictionary, larg: float, z: float, y: float,
		frente: bool) -> void:
	var dz := 1.0 if frente else -1.0
	var meia := larg * 0.5 - 0.015
	var alt := 0.135
	var us := [-1.0, -0.62, 0.0, 0.62, 1.0]
	var recuos := [0.16, 0.045, 0.0, 0.045, 0.16]
	var pontos := []
	for k in us.size():
		var zz: float = z - dz * recuos[k]
		pontos.append([
			Vector3(us[k] * meia, y + alt * 0.5, zz),
			Vector3(us[k] * meia, y - alt * 0.5, zz),
		])
	var fora := Vector3(0.0, 0.0, dz)
	var recuo := Vector3(0.0, 0.0, dz * 0.085)
	for k in pontos.size() - 1:
		var a: Array = pontos[k]
		var b: Array = pontos[k + 1]
		var a0: Vector3 = a[0]
		var a1: Vector3 = a[1]
		var b0: Vector3 = b[0]
		var b1: Vector3 = b[1]
		_quad(dados, a0, b0, b1, a1, C_PARACHOQUE, CROMO, fora)
		_quad(dados, a0, b0, b0 - recuo, a0 - recuo, C_PARACHOQUE,
			CROMO * 1.14, Vector3.UP)
		_quad(dados, a1, b1, b1 - recuo, a1 - recuo, C_PARACHOQUE,
			PLASTICO * 0.85, Vector3.DOWN)


static func _cacamba(dados: Dictionary, comp: float, larg: float, capo: float,
		cabine: float, cor: Color) -> void:
	var comp_cabine := comp * cabine
	var z0 := -comp * 0.5 + 0.06
	var z1 := -comp * 0.06 - comp_cabine * 0.5
	var alt := 0.34
	for s: float in [1.0, -1.0]:
		_face(dados, Vector2(z1 - z0, alt),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * larg * 0.5, capo + alt * 0.5, (z0 + z1) * 0.5)),
			cor, C_CACAMBA)
	_face(dados, Vector2(larg, alt),
		Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, capo + alt * 0.5, z0)),
		cor, C_CACAMBA)
	_face(dados, Vector2(larg, z1 - z0),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
			Vector3(0.0, capo, (z0 + z1) * 0.5)), cor * 0.7, C_CACAMBA)


static func _letreiro(dados: Dictionary, _larg: float, teto: float, comp: float,
		cabine: float) -> void:
	var z := -comp * 0.06 - comp * cabine * 0.5 + comp * cabine * 0.7
	for lado: float in [0.0, PI]:
		_face(dados, Vector2(0.46, 0.14),
			Transform3D(Basis(Vector3.UP, lado), Vector3(0.0, teto + 0.08, z)),
			Color.WHITE, C_LETREIRO_TAXI)


## As duas rodas de um eixo, numa malha so, centrada no meio do eixo.
##
## Nao leva a meia volta da lataria: a roda e simetrica em X, a calota de cada
## uma ja fica do lado de fora nos dois casos, e girar a malha inverteria o
## sentido do proprio giro em relacao ao deslocamento — as rodas andariam para
## tras com o carro indo para a frente.
##
## Oito lados no pneu. E o mesmo numero do poste de luz e pela mesma razao: a
## 480x270, o nono lado nao muda um pixel do contorno e custa dois triangulos
## por roda, quatro por eixo, dezesseis por carro.
## Bitola de eixo a eixo.
##
## A conta antiga deixava a face externa do pneu tres centimetros DENTRO da
## lataria: as quatro rodas ficavam enfiadas debaixo do casco e o carro lia como
## uma caixa deslizando. Aqui o pneu fica rente a lateral, que e onde ele fica
## num carro de verdade, e de quebra a base de apoio mais larga tira a tendencia
## de capotar em curva forte.
static func _bitola(larg: float) -> float:
	return larg - LARGURA_RODA + 0.02


static func _eixo(larg: float) -> ArrayMesh:
	var dados := PSXMesh.dados_vazios()
	var bitola := _bitola(larg) * 0.5
	for s: float in [1.0, -1.0]:
		_roda(dados, Vector3(s * bitola, 0.0, 0.0), s > 0.0)
	return PSXMesh.dados_para_mesh(dados)


static func _roda(dados: Dictionary, centro: Vector3, direita: bool) -> void:
	var lados := 8
	var meia := LARGURA_RODA * 0.5
	var r_pneu := uv(C_PNEU)
	var r_calota := uv(C_CALOTA)

	var v: PackedVector3Array = dados["v"]
	var n: PackedVector3Array = dados["n"]
	var u: PackedVector2Array = dados["uv"]
	var c: PackedColorArray = dados["c"]
	var i: PackedInt32Array = dados["i"]
	# A cor de vertice do pneu NAO escurece: quem ja e escuro e a celula do
	# atlas (media 41 de 255). Multiplicar a textura por 0,16, como estava aqui,
	# escurece duas vezes e derruba a banda para 6 de 255 — mais escuro que a
	# sombra da propria caixa de roda. Resultado: pneu nenhum aparecia em carro
	# nenhum do jogo, so a calota boiando no escuro.
	var borracha := Color(1.0, 0.98, 0.95)
	# O flanco leva poeira. Nas refs ele e visivelmente mais claro que o vao
	# atras dele, e e esse contraste que faz a roda ter volume de lado.
	var poeira := Color(2.35, 2.20, 2.00)

	# Banda de rodagem.
	for k in lados:
		var a0 := TAU * float(k) / float(lados)
		var a1 := TAU * float(k + 1) / float(lados)
		var p0 := Vector3(0.0, sin(a0) * RAIO_RODA, cos(a0) * RAIO_RODA)
		var p1 := Vector3(0.0, sin(a1) * RAIO_RODA, cos(a1) * RAIO_RODA)
		var base := v.size()
		v.append(centro + p0 + Vector3(-meia, 0, 0))
		v.append(centro + p1 + Vector3(-meia, 0, 0))
		v.append(centro + p1 + Vector3(meia, 0, 0))
		v.append(centro + p0 + Vector3(meia, 0, 0))
		var nr := Vector3(0.0, sin((a0 + a1) * 0.5), cos((a0 + a1) * 0.5))
		for _k in 4:
			n.append(nr)
			c.append(borracha)
		var ua := float(k) / float(lados)
		var ub := float(k + 1) / float(lados)
		u.append(r_pneu.position + Vector2(ua, 0.0) * r_pneu.size)
		u.append(r_pneu.position + Vector2(ub, 0.0) * r_pneu.size)
		u.append(r_pneu.position + Vector2(ub, 1.0) * r_pneu.size)
		u.append(r_pneu.position + Vector2(ua, 1.0) * r_pneu.size)
		i.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

	# O FLANCO do pneu, e depois a calota por cima dele.
	#
	# O flanco faltava, e a roda nao existia de lado. A banda de rodagem e um
	# cilindro: olhando o carro de perfil ela fica de canto e some, entao a unica
	# coisa que sobrava era a calota — um disquinho de 37 cm boiando dentro da
	# caixa de roda escura. Todo carro do jogo tinha isso. Oito triangulos por
	# roda resolvem: um disco cheio no raio do pneu, cor de pneu, e a calota
	# desenhada em cima.
	var x := meia + 0.004 if direita else -meia - 0.004
	var n_lado := Vector3(1.0 if direita else -1.0, 0, 0)
	var centro_pneu := v.size()
	v.append(centro + Vector3(x, 0, 0))
	n.append(n_lado)
	c.append(poeira)
	u.append(r_pneu.get_center())
	for k in lados + 1:
		var a := TAU * float(k) / float(lados)
		v.append(centro + Vector3(x, sin(a) * RAIO_RODA, cos(a) * RAIO_RODA))
		n.append(n_lado)
		c.append(poeira)
		u.append(r_pneu.get_center() + Vector2(cos(a), sin(a)) * r_pneu.size * 0.5)
	for k in lados:
		if direita:
			i.append_array([centro_pneu, centro_pneu + 1 + k, centro_pneu + 2 + k])
		else:
			i.append_array([centro_pneu, centro_pneu + 2 + k, centro_pneu + 1 + k])

	var xc := x + (0.004 if direita else -0.004)
	var centro_disco := v.size()
	v.append(centro + Vector3(xc, 0, 0))
	n.append(Vector3(1.0 if direita else -1.0, 0, 0))
	c.append(Color(0.62, 0.62, 0.64))
	u.append(r_calota.get_center())
	for k in lados + 1:
		var a := TAU * float(k) / float(lados)
		v.append(centro + Vector3(xc, sin(a) * RAIO_RODA * 0.62, cos(a) * RAIO_RODA * 0.62))
		n.append(Vector3(1.0 if direita else -1.0, 0, 0))
		c.append(Color(0.62, 0.62, 0.64))
		u.append(r_calota.get_center() + Vector2(cos(a), sin(a)) * r_calota.size * 0.5)
	for k in lados:
		if direita:
			i.append_array([centro_disco, centro_disco + 1 + k, centro_disco + 2 + k])
		else:
			i.append_array([centro_disco, centro_disco + 2 + k, centro_disco + 1 + k])

	dados["v"] = v
	dados["n"] = n
	dados["uv"] = u
	dados["c"] = c
	dados["i"] = i
