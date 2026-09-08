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

const MATERIAL := "res://resources/materials/mat_carro.tres"
const MATERIAL_LUZ := "res://resources/materials/mat_carro_luz.tres"

## Atlas de 256x256 dividido em celulas de 32. Ver tools/gerar_carro.py.
const CELULA := 32.0
const ATLAS := 256.0

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
const TINTA_FUSCA := Color(0.82, 0.76, 0.64)

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
	# Marea: comprimento unico para a cabine casar por medida. Detalhe e de Renato.
	Modelo.MAREA:  {"c": 4.39, "l": 1.74, "capo": 0.92, "teto": 1.44, "eixo": 2.54, "cabine": 0.48},
	# Fusca: proporcao de besouro, NAO sedan. Curto, estreito, teto alto, eixo curto.
	Modelo.FUSCA:  {"c": 3.78, "l": 1.50, "capo": 0.74, "teto": 1.50, "eixo": 2.10, "cabine": 0.48},
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

const RAIO_RODA := 0.30
const LARGURA_RODA := 0.20
## Altura do assoalho. E o que separa um carro de um carrinho de rolima: abaixo
## disso a caixa raspa no meio-fio em toda subida de rampa.
const ASSOALHO := 0.26


## Tudo que o Carro precisa para se montar.
static func montar(modelo: Modelo, tinta: Color, semente: int, com_vidros_frente: bool = true) -> Dictionary:
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

	if modelo == Modelo.FUSCA:
		_lataria_fusca(corpo, comp, larg, capo, teto, cabine, cor)
		if com_vidros_frente:
			_vidros(corpo, comp, larg, capo, teto, cabine)
		_frente_e_tras(corpo, luzes, comp, larg, capo, cor, modelo)
	else:
		_lataria(corpo, comp, larg, capo, teto, cabine, cor, suja)
		if com_vidros_frente:
			_vidros(corpo, comp, larg, capo, teto, cabine)
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

	return {
		"corpo": PSXMesh.dados_para_mesh(corpo_final),
		"luzes": PSXMesh.dados_para_mesh(luzes_final),
		"eixo_frente": _eixo(larg),
		"eixo_tras": _eixo(larg),
		"triangulos": (PSXMesh.dados_triangulos(corpo_final)
			+ PSXMesh.dados_triangulos(luzes_final)),
		"comprimento": comp,
		"largura": larg,
		"altura": teto,
		"entre_eixos": eixo,
		"bitola": _bitola(larg),
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


static func _face(dados: Dictionary, tamanho: Vector2, xform: Transform3D,
		cor: Color, celula: Vector2i) -> void:
	var d := PSXMesh.placa_dados(tamanho, 100.0, Color.WHITE)
	var r := uv(celula)
	var uvs: PackedVector2Array = d["uv"]
	for k in uvs.size():
		uvs[k] = r.position + uvs[k] * r.size
	d["uv"] = uvs
	PSXMesh.acumular_tingido(dados, d, xform, cor)


## Placa com verso. CUIDADO: em vidro OPaco isso preenche o verso e a cabine
## FP ve preto solido (P0 Estrada Velha). So usar com alfa de verdade, ou em
## pecas que a camera de dentro nunca encara. Para-brisa/vigia usam _face unica.
static func _face_dois_lados(dados: Dictionary, tamanho: Vector2, xform: Transform3D,
		cor: Color, celula: Vector2i) -> void:
	_face(dados, tamanho, xform, cor, celula)
	_face(dados, tamanho,
		xform * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO), cor, celula)


## Um paralelepipedo com celula por face, e sem as faces que ninguem ve.
static func _caixa(dados: Dictionary, tamanho: Vector3, centro: Vector3,
		cor: Color, lado: Vector2i, frente: Vector2i, topo: Vector2i,
		com_base: bool = false) -> void:
	var h := tamanho * 0.5
	# +Z e a frente do carro.
	_face(dados, Vector2(tamanho.x, tamanho.y),
		Transform3D(Basis(), centro + Vector3(0, 0, h.z)), cor, frente)
	_face(dados, Vector2(tamanho.x, tamanho.y),
		Transform3D(Basis(Vector3.UP, PI), centro - Vector3(0, 0, h.z)), cor, frente)
	_face(dados, Vector2(tamanho.z, tamanho.y),
		Transform3D(Basis(Vector3.UP, PI * 0.5), centro + Vector3(h.x, 0, 0)), cor, lado)
	_face(dados, Vector2(tamanho.z, tamanho.y),
		Transform3D(Basis(Vector3.UP, -PI * 0.5), centro - Vector3(h.x, 0, 0)), cor, lado)
	_face(dados, Vector2(tamanho.x, tamanho.z),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), centro + Vector3(0, h.y, 0)), cor, topo)
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

	# Casco, do assoalho ate a linha do capo.
	_caixa(dados, Vector3(larg, altura_casco, comp),
		Vector3(0.0, ASSOALHO + altura_casco * 0.5, 0.0), cor,
		celula_lado, C_TRASEIRA, C_CAPO, true)

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
		# So face externa. Face interna opaca bloquearia a cabine FP / vista lateral.
		PSXMesh.acumular(dados,
			_quad_lateral(
				_encolher(a, b, c, d, 0) + desloca,
				_encolher(a, b, c, d, 1) + desloca,
				_encolher(a, b, c, d, 2) + desloca,
				_encolher(a, b, c, d, 3) + desloca,
				C_VIDRO_LADO, VIDRO, fora),
			Transform3D.IDENTITY)

	# Soleira: a faixa escura embaixo da porta. Um carro sem ela flutua.
	#
	# Vai so DE RODA A RODA, e nao pelos 82% do comprimento de antes. A faixa
	# longa passava por cima dos dois pneus e escondia justamente a peca que
	# prova que o carro toca o chao — a rua inteira parecia deslizar.
	_face_soleira(dados, comp, larg, cor)


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


## A faixa escura da porta, limitada ao vao entre as duas caixas de roda.
static func _face_soleira(dados: Dictionary, comp: float, larg: float,
		cor: Color) -> void:
	var vao := comp * 0.40
	for s: float in [1.0, -1.0]:
		_face(dados, Vector2(vao, 0.10),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.5 + 0.005), ASSOALHO + 0.05, 0.0)),
			cor * 0.45, C_SOLEIRA)


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
	for p: Vector3 in [a, b, c, d]:
		v.append(p)
		n.append(normal)
		cc.append(cor)
	u.append(r.position + Vector2(0.0, r.size.y))
	u.append(r.position + r.size)
	u.append(r.position + Vector2(r.size.x, 0.0))
	u.append(r.position)
	if invertido:
		i.append_array([0, 2, 1, 0, 3, 2])
	else:
		i.append_array([0, 1, 2, 0, 2, 3])
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

	# Para-brisa, UMA face para FORA. Com cull_back do psx_surface, a cabine FP
	# ve o verso cullado e enxerga a rua (transparente). Face interna opaca era o
	# P0: para-brisa preto solido na Estrada Velha. Nao voltar _face_dois_lados
	# aqui sem alfa de verdade no material.
	var incl := atan2(recuo, alt)
	var xf := Transform3D(Basis(Vector3.RIGHT, -incl),
		Vector3(0.0, capo + alt * 0.5, z1 - recuo * 0.5 + 0.01))
	_face(dados, Vector2(lv, sqrt(alt * alt + recuo * recuo)), xf,
		Color(0.72, 0.80, 0.86), C_PARABRISA)

	# Vigia: mesma regra — so face externa.
	var xf2 := Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -incl),
		Vector3(0.0, capo + alt * 0.5, z0 + recuo * 0.5 - 0.01))
	_face(dados, Vector2(lv, sqrt(alt * alt + recuo * recuo)), xf2,
		Color(0.72, 0.80, 0.86), C_VIDRO_TRAS)


## Grade, para-choques, placa e as lampadas.
static func _frente_e_tras(dados: Dictionary, luzes: Dictionary, comp: float,
		larg: float, capo: float, cor: Color, modelo: Modelo) -> void:
	if modelo == Modelo.FUSCA:
		_frente_e_tras_fusca(dados, luzes, comp, larg, capo, cor)
		return
	if modelo == Modelo.MAREA:
		_frente_e_tras_marea(dados, luzes, comp, larg, capo, cor)
		return
	var zf := comp * 0.5 + 0.005
	var zt := -comp * 0.5 - 0.005
	var y := ASSOALHO + (capo - ASSOALHO) * 0.52

	_face(dados, Vector2(larg * 0.78, 0.18),
		Transform3D(Basis(), Vector3(0.0, y + 0.06, zf)), Color(0.30, 0.30, 0.32), C_GRADE)
	for z: float in [zf, zt]:
		var frente := z > 0.0
		_face(dados, Vector2(larg, 0.16),
			Transform3D(Basis(Vector3.UP, 0.0 if frente else PI),
				Vector3(0.0, ASSOALHO + 0.10, z)),
			Color(0.52, 0.52, 0.54), C_PARACHOQUE)
		_face(dados, Vector2(0.32, 0.11),
			Transform3D(Basis(Vector3.UP, 0.0 if frente else PI),
				Vector3(0.0, ASSOALHO + 0.24, z + (0.006 if frente else -0.006))),
			Color.WHITE, C_PLACA)

	# Farois e lanternas, na malha emissiva. Dois de cada lado, encostados na
	# quina — e a posicao que faz o par ler como par a distancia.
	var ox := larg * 0.34
	for s: float in [1.0, -1.0]:
		_face(luzes, Vector2(0.26, 0.13),
			Transform3D(Basis(), Vector3(s * ox, y + 0.10, zf + 0.006)),
			Color.WHITE, C_FAROL)
		_face(luzes, Vector2(0.24, 0.14),
			Transform3D(Basis(Vector3.UP, PI), Vector3(s * ox, y + 0.10, zt - 0.006)),
			Color.WHITE, C_LANTERNA)


## Fiat Marea PSX: grade em ripas, farol quadrado com pisca na quina, lanterna
## em blocos vermelho/laranja/branco, tres venezianas na coluna C e placa cinza.
##
## Laranja e branco da lanterna ficam no CORPO (malha nao-emissiva) para o
## swap de UV do freio/seta no Carro continuar mexendo so nas faces C_LANTERNA
## da malha de luzes — um vertice a mais com C_PISCA/C_RE la quebraria o delta.
static func _frente_e_tras_marea(dados: Dictionary, luzes: Dictionary, comp: float,
		larg: float, capo: float, _cor: Color) -> void:
	var zf := comp * 0.5 + 0.005
	var zt := -comp * 0.5 - 0.005
	var y := ASSOALHO + (capo - ASSOALHO) * 0.52

	# Grade larga em ripas horizontais (leitura de Marea a distancia).
	_face(dados, Vector2(larg * 0.72, 0.22),
		Transform3D(Basis(), Vector3(0.0, y + 0.04, zf)),
		Color(0.22, 0.22, 0.24), C_GRADE)
	for k in 4:
		var yy := y - 0.02 + float(k) * 0.055
		_face(dados, Vector2(larg * 0.68, 0.028),
			Transform3D(Basis(), Vector3(0.0, yy, zf + 0.004)),
			Color(0.16, 0.16, 0.18), C_GRADE)

	# Para-choques escuros + placa: frente branca, traseira cinza em branco.
	for z: float in [zf, zt]:
		var frente := z > 0.0
		var basis := Basis(Vector3.UP, 0.0 if frente else PI)
		_face(dados, Vector2(larg, 0.15),
			Transform3D(basis, Vector3(0.0, ASSOALHO + 0.10, z)),
			Color(0.42, 0.42, 0.44), C_PARACHOQUE)
		var cor_placa := Color.WHITE if frente else Color(0.48, 0.48, 0.50)
		_face(dados, Vector2(0.36, 0.12),
			Transform3D(basis,
				Vector3(0.0, ASSOALHO + 0.24, z + (0.006 if frente else -0.006))),
			cor_placa, C_PLACA)

	# Farois quadrados + pisca ambar na quina de fora (malha emissiva).
	var ox := larg * 0.36
	for s: float in [1.0, -1.0]:
		_face(luzes, Vector2(0.28, 0.16),
			Transform3D(Basis(), Vector3(s * ox, y + 0.10, zf + 0.008)),
			Color.WHITE, C_FAROL)
		_face(luzes, Vector2(0.09, 0.16),
			Transform3D(Basis(), Vector3(s * (ox + 0.17), y + 0.10, zf + 0.009)),
			Color(1.0, 0.70, 0.22), C_PISCA)

		# Lanterna: vermelho de fora (emissivo) | laranja/branco (corpo) | vermelho interno.
		var bx := s * ox
		_face(luzes, Vector2(0.14, 0.16),
			Transform3D(Basis(Vector3.UP, PI), Vector3(bx + s * 0.12, y + 0.10, zt - 0.008)),
			Color.WHITE, C_LANTERNA)
		_face(dados, Vector2(0.11, 0.08),
			Transform3D(Basis(Vector3.UP, PI), Vector3(bx, y + 0.14, zt - 0.006)),
			Color.WHITE, C_PISCA)
		_face(dados, Vector2(0.11, 0.07),
			Transform3D(Basis(Vector3.UP, PI), Vector3(bx, y + 0.05, zt - 0.006)),
			Color.WHITE, C_RE)
		_face(dados, Vector2(0.12, 0.16),
			Transform3D(Basis(Vector3.UP, PI), Vector3(bx - s * 0.12, y + 0.10, zt - 0.006)),
			Color.WHITE, C_LANTERNA)

	# Tres venezianas escuras na coluna C (atras da estufa).
	var cabine := float(MEDIDAS[Modelo.MAREA]["cabine"])
	var comp_cabine := comp * cabine
	var z0 := -comp * 0.06 - comp_cabine * 0.5
	var z_vent := z0 + 0.10
	var lc := larg - RECUO_CABINE
	for s: float in [1.0, -1.0]:
		for k in 3:
			var yy := capo + 0.10 + float(k) * 0.08
			_face(dados, Vector2(0.16, 0.035),
				Transform3D(Basis(Vector3.UP, s * PI * 0.5),
					Vector3(s * (lc * 0.5 + 0.008), yy, z_vent)),
				Color(0.14, 0.14, 0.15), C_GRADE)

	# Respiros no capo, perto do para-brisa (leitura de sedan 90s).
	for s: float in [1.0, -1.0]:
		_face(dados, Vector2(0.18, 0.06),
			Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
				Vector3(s * larg * 0.22, capo + 0.004, comp * 0.12)),
			Color(0.20, 0.20, 0.22), C_GRADE)


## Fusca: silhueta de besouro em caixas PSX (refs PRINTS/ref_fusca).
##
## Porta BAIXA entre para-lamas ALTOS (arco legivel de lado), capo/deck
## inclinados, teto em cupula. Cabine z0/recuo = _vidros (P0 face unica + tint).
## Sem _face_dois_lados no para-brisa. Sem mexer em Marea.
static func _lataria_fusca(dados: Dictionary, comp: float, larg: float, capo: float,
		teto: float, cabine: float, cor: Color) -> void:
	var suja := C_LATARIA_SUJA
	var ferrugem := Color(cor.r * 0.58, cor.g * 0.36, cor.b * 0.20)
	var ferrugem_clara := Color(cor.r * 0.74, cor.g * 0.52, cor.b * 0.32)
	var chrome := Color(0.78, 0.78, 0.80)
	var altura_casco := capo - ASSOALHO

	# Barriga baixa continua (assoalho ate meia porta) — nao preenche o arco.
	_caixa(dados, Vector3(larg * 0.86, altura_casco * 0.55, comp * 0.92),
		Vector3(0.0, ASSOALHO + altura_casco * 0.30, 0.0), cor,
		suja, C_TRASEIRA, C_CAPO, true)

	# Painel da porta (mais baixo que o topo dos para-lamas).
	_caixa(dados, Vector3(larg * 0.90, altura_casco * 0.42, comp * 0.34),
		Vector3(0.0, ASSOALHO + altura_casco * 0.68, 0.0), cor,
		suja, suja, C_CAPO, false)

	# Capo curto caindo (volume + placa).
	_caixa(dados, Vector3(larg * 0.72, altura_casco * 0.36, comp * 0.22),
		Vector3(0.0, ASSOALHO + altura_casco * 0.62, comp * 0.34), cor,
		suja, C_CAPO, C_CAPO, false)
	_face(dados, Vector2(larg * 0.70, comp * 0.20),
		Transform3D(Basis(Vector3.RIGHT, -0.58),
			Vector3(0.0, capo - 0.04, comp * 0.32)), cor, C_CAPO)

	# Deck do motor caindo para tras.
	_caixa(dados, Vector3(larg * 0.74, altura_casco * 0.40, comp * 0.24),
		Vector3(0.0, ASSOALHO + altura_casco * 0.66, -comp * 0.34), cor,
		suja, C_TRASEIRA, C_TRASEIRA, false)
	_face(dados, Vector2(larg * 0.72, comp * 0.20),
		Transform3D(Basis(Vector3.RIGHT, -2.45),
			Vector3(0.0, capo - 0.02, -comp * 0.32)), cor, C_TRASEIRA)

	# Para-lamas ALTOS (quase na linha do capo) e LARGOS — leitura de besouro.
	# Corpo creme no topo do arco; ferrugem so na base (como nas refs).
	var fl_top := ASSOALHO + altura_casco * 0.78
	for s: float in [1.0, -1.0]:
		var sx := s * (larg * 0.52)
		# --- dianteiro ---
		_caixa(dados, Vector3(0.38, altura_casco * 0.85, 0.50),
			Vector3(sx, ASSOALHO + altura_casco * 0.48, comp * 0.28), cor,
			suja, suja, C_CAPO, false)
		_caixa(dados, Vector3(0.30, altura_casco * 0.55, 0.34),
			Vector3(sx + s * 0.04, fl_top - 0.06, comp * 0.28), cor,
			suja, suja, C_CAPO, false)
		_caixa(dados, Vector3(0.34, altura_casco * 0.38, 0.40),
			Vector3(sx, ASSOALHO + altura_casco * 0.28, comp * 0.28), ferrugem,
			suja, suja, C_CAPO, false)
		# --- traseiro ---
		_caixa(dados, Vector3(0.40, altura_casco * 0.88, 0.54),
			Vector3(sx, ASSOALHO + altura_casco * 0.50, -comp * 0.28), cor,
			suja, suja, C_TRASEIRA, false)
		_caixa(dados, Vector3(0.32, altura_casco * 0.58, 0.36),
			Vector3(sx + s * 0.04, fl_top - 0.04, -comp * 0.28), cor,
			suja, suja, C_TRASEIRA, false)
		_caixa(dados, Vector3(0.36, altura_casco * 0.40, 0.44),
			Vector3(sx, ASSOALHO + altura_casco * 0.28, -comp * 0.28), ferrugem,
			suja, suja, C_TRASEIRA, false)
		# Soleira / running board.
		_face(dados, Vector2(comp * 0.32, 0.10),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.50), ASSOALHO + 0.05, 0.0)),
			ferrugem, C_SOLEIRA)
		# Friso cromado na porta (entre para-lamas).
		_face(dados, Vector2(comp * 0.30, 0.030),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.46), capo - 0.18, 0.0)),
			chrome, C_PARACHOQUE)
		# Mancha de ferrugem na porta.
		_face(dados, Vector2(0.36, 0.20),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.455), ASSOALHO + 0.32, 0.0)),
			ferrugem_clara, suja)

	# Arco lateral dos para-lamas (3 placas inclinadas = semicirculo PSX).
	# Sem isso o lado le como caixa com mancha marrom; com isso o perfil sobe
	# e desce sobre a roda como nas refs.
	for s: float in [1.0, -1.0]:
		var sx2 := s * (larg * 0.54 + 0.01)
		var basis_lado := Basis(Vector3.UP, s * PI * 0.5)
		for z_arco: float in [comp * 0.28, -comp * 0.28]:
			# Base vertical do arco.
			_face(dados, Vector2(0.36, altura_casco * 0.50),
				Transform3D(basis_lado, Vector3(sx2, ASSOALHO + altura_casco * 0.40, z_arco)),
				cor, suja)
			# Ombro superior inclinado para fora (bulbo).
			_face(dados, Vector2(0.30, altura_casco * 0.28),
				Transform3D(basis_lado * Basis(Vector3.RIGHT, -0.55),
					Vector3(sx2 + s * 0.02, ASSOALHO + altura_casco * 0.72, z_arco)),
				cor, suja)
			# Tampo do arco (quase horizontal).
			_face(dados, Vector2(0.28, 0.18),
				Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
					Vector3(s * (larg * 0.52), ASSOALHO + altura_casco * 0.92, z_arco)),
				cor, C_CAPO)

	# Cabine alinhada ao _vidros (P0).
	var comp_cabine := comp * cabine
	var z0 := -comp * 0.06 - comp_cabine * 0.5
	var z1 := z0 + comp_cabine
	var alt_cabine := teto - capo
	var recuo := alt_cabine * 0.55
	var lc := larg - RECUO_CABINE * 0.90
	var h := lc * 0.5
	var z_mid := (z0 + z1) * 0.5

	# Cupula: topo + duas placas inclinadas (frente/tras) encostadas.
	var teto_comp := maxf(0.20, comp_cabine - recuo * 1.90)
	_face(dados, Vector2(lc * 0.90, teto_comp),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
			Vector3(0.0, teto, z_mid)), cor, C_TETO)
	_face(dados, Vector2(lc * 0.86, recuo * 1.05),
		Transform3D(Basis(Vector3.RIGHT, -0.88),
			Vector3(0.0, teto - 0.04, z1 - recuo * 0.50)), cor, C_TETO)
	_face(dados, Vector2(lc * 0.86, recuo * 1.05),
		Transform3D(Basis(Vector3.RIGHT, -2.26),
			Vector3(0.0, teto - 0.04, z0 + recuo * 0.50)), cor, C_TETO)

	for s: float in [1.0, -1.0]:
		var fora := Vector3(s, 0.0, 0.0)
		var a := Vector3(s * h, capo, z0)
		var b := Vector3(s * h, capo, z1)
		var c := Vector3(s * h * 0.93, teto, z1 - recuo)
		var d := Vector3(s * h * 0.93, teto, z0 + recuo)
		PSXMesh.acumular(dados,
			_quad_lateral(a, b, c, d, suja, cor, fora), Transform3D.IDENTITY)
		var desloca := fora * 0.009
		PSXMesh.acumular(dados,
			_quad_lateral(
				_encolher(a, b, c, d, 0) + desloca,
				_encolher(a, b, c, d, 1) + desloca,
				_encolher(a, b, c, d, 2) + desloca,
				_encolher(a, b, c, d, 3) + desloca,
				C_VIDRO_LADO, VIDRO, fora), Transform3D.IDENTITY)

	# Retrovisor.
	_caixa(dados, Vector3(0.06, 0.05, 0.10),
		Vector3(larg * 0.36, capo + alt_cabine * 0.38, z1 - 0.02),
		Color(0.34, 0.34, 0.36), C_PARACHOQUE, C_PARACHOQUE, C_PARACHOQUE, false)


## Frente/traseira do Fusca: farol redondo nos para-lamas, venezianas no deck,
## lanterna bipartida e overriders (refs).
static func _frente_e_tras_fusca(dados: Dictionary, luzes: Dictionary, comp: float,
		larg: float, capo: float, _cor: Color) -> void:
	var zf := comp * 0.5 + 0.005
	var zt := -comp * 0.5 - 0.005
	var y := ASSOALHO + (capo - ASSOALHO) * 0.52

	_face(dados, Vector2(larg * 0.24, 0.06),
		Transform3D(Basis(), Vector3(0.0, y - 0.08, zf)),
		Color(0.22, 0.22, 0.24), C_GRADE)

	for z: float in [zf, zt]:
		var frente := z > 0.0
		var basis := Basis(Vector3.UP, 0.0 if frente else PI)
		_face(dados, Vector2(larg * 0.92, 0.10),
			Transform3D(basis, Vector3(0.0, ASSOALHO + 0.10, z)),
			Color(0.62, 0.62, 0.64), C_PARACHOQUE)
		for s: float in [1.0, -1.0]:
			_face(dados, Vector2(0.048, 0.22),
				Transform3D(basis, Vector3(s * larg * 0.20, ASSOALHO + 0.17,
					z + (0.012 if frente else -0.012))),
				Color(0.70, 0.70, 0.72), C_PARACHOQUE)
		_face(dados, Vector2(0.22, 0.08),
			Transform3D(basis, Vector3(0.0, ASSOALHO + 0.22,
				z + (0.006 if frente else -0.006))),
			Color(0.80, 0.80, 0.82), C_PLACA)

	# Farol "redondo" a 480p: anel + nucleo + losango (le circular).
	var ox := larg * 0.42
	for s: float in [1.0, -1.0]:
		_face(dados, Vector2(0.30, 0.30),
			Transform3D(Basis(), Vector3(s * ox, y + 0.10, zf + 0.010)),
			Color(0.14, 0.14, 0.16), C_GRADE)
		_face(dados, Vector2(0.22, 0.22),
			Transform3D(Basis(Vector3.FORWARD, PI * 0.25),
				Vector3(s * ox, y + 0.10, zf + 0.012)),
			Color(0.20, 0.20, 0.22), C_GRADE)
		_face(luzes, Vector2(0.18, 0.18),
			Transform3D(Basis(), Vector3(s * ox, y + 0.10, zf + 0.018)),
			Color.WHITE, C_FAROL)
		_face(luzes, Vector2(0.10, 0.055),
			Transform3D(Basis(), Vector3(s * ox, y + 0.26, zf - 0.04)),
			Color(1.0, 0.68, 0.16), C_PISCA)
		_face(luzes, Vector2(0.11, 0.06),
			Transform3D(Basis(Vector3.UP, PI), Vector3(s * ox, y + 0.18, zt - 0.012)),
			Color(1.0, 0.50, 0.12), C_LANTERNA)
		_face(luzes, Vector2(0.11, 0.08),
			Transform3D(Basis(Vector3.UP, PI), Vector3(s * ox, y + 0.08, zt - 0.012)),
			Color.WHITE, C_FREIO)

	# Venezianas no deck (largas + laterais baixas).
	for k in 3:
		var yy := capo - 0.02 + float(k) * 0.045
		_face(dados, Vector2(larg * 0.46, 0.030),
			Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, yy, zt + 0.18)),
			Color(0.12, 0.12, 0.14), C_GRADE)
	for s: float in [1.0, -1.0]:
		_face(dados, Vector2(larg * 0.15, 0.026),
			Transform3D(Basis(Vector3.UP, PI),
				Vector3(s * larg * 0.24, capo - 0.06, zt + 0.16)),
			Color(0.12, 0.12, 0.14), C_GRADE)

	_face(dados, Vector2(0.07, 0.045),
		Transform3D(Basis(Vector3.UP, PI), Vector3(-larg * 0.16, ASSOALHO + 0.05, zt - 0.02)),
		Color(0.24, 0.24, 0.25), C_PARACHOQUE)
	_face(dados, Vector2(0.09, 0.035),
		Transform3D(Basis(Vector3.UP, PI * 0.5),
			Vector3(larg * 0.45, capo - 0.12, 0.02)),
		Color(0.20, 0.20, 0.22), C_PARACHOQUE)


## A cacamba da picape: tres paredes baixas em cima do casco.
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
	var preto := Color(0.16, 0.16, 0.17)

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
			c.append(preto)
		var ua := float(k) / float(lados)
		var ub := float(k + 1) / float(lados)
		u.append(r_pneu.position + Vector2(ua, 0.0) * r_pneu.size)
		u.append(r_pneu.position + Vector2(ub, 0.0) * r_pneu.size)
		u.append(r_pneu.position + Vector2(ub, 1.0) * r_pneu.size)
		u.append(r_pneu.position + Vector2(ua, 1.0) * r_pneu.size)
		i.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

	# A calota, so no lado de fora. O lado de dentro nunca e visto e um disco a
	# menos por roda sao seis triangulos por carro.
	var x := meia + 0.004 if direita else -meia - 0.004
	var centro_disco := v.size()
	v.append(centro + Vector3(x, 0, 0))
	n.append(Vector3(1.0 if direita else -1.0, 0, 0))
	c.append(Color(0.62, 0.62, 0.64))
	u.append(r_calota.get_center())
	for k in lados + 1:
		var a := TAU * float(k) / float(lados)
		v.append(centro + Vector3(x, sin(a) * RAIO_RODA * 0.62, cos(a) * RAIO_RODA * 0.62))
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
