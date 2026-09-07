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

enum Modelo { SEDA, HATCH, PERUA, PICAPE, TAXI }

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

## Medidas por modelo, em metros.
##   comprimento, largura, altura do capo, altura do teto, entre-eixos,
##   balanco dianteiro, tamanho da cabine em fracao do comprimento
const MEDIDAS := {
	Modelo.SEDA:   {"c": 4.30, "l": 1.70, "capo": 0.78, "teto": 1.38, "eixo": 2.55, "cabine": 0.46},
	Modelo.HATCH:  {"c": 3.75, "l": 1.62, "capo": 0.76, "teto": 1.42, "eixo": 2.30, "cabine": 0.50},
	Modelo.PERUA:  {"c": 4.55, "l": 1.74, "capo": 0.80, "teto": 1.56, "eixo": 2.62, "cabine": 0.60},
	Modelo.PICAPE: {"c": 4.70, "l": 1.78, "capo": 0.86, "teto": 1.52, "eixo": 2.80, "cabine": 0.34},
	Modelo.TAXI:   {"c": 4.30, "l": 1.70, "capo": 0.78, "teto": 1.38, "eixo": 2.55, "cabine": 0.46},
}

const RAIO_RODA := 0.30
const LARGURA_RODA := 0.20
## Altura do assoalho. E o que separa um carro de um carrinho de rolima: abaixo
## disso a caixa raspa no meio-fio em toda subida de rampa.
const ASSOALHO := 0.26


## Tudo que o Carro precisa para se montar.
static func montar(modelo: Modelo, tinta: Color, semente: int) -> Dictionary:
	var m: Dictionary = MEDIDAS[modelo]
	var comp: float = m["c"]
	var larg: float = m["l"]
	var capo: float = m["capo"]
	var teto: float = m["teto"]
	var eixo: float = m["eixo"]
	var cabine: float = m["cabine"]

	var cor := TINTA_TAXI if modelo == Modelo.TAXI else tinta
	var suja := (semente % 7) == 0

	var corpo := PSXMesh.dados_vazios()
	var luzes := PSXMesh.dados_vazios()

	_lataria(corpo, comp, larg, capo, teto, cabine, cor, suja)
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
		"bitola": larg - LARGURA_RODA - 0.06,
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
	var lc := larg - 0.06
	var h := lc * 0.5

	# Teto.
	_face(dados, Vector2(lc, comp_cabine - recuo * 2.0),
		Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
			Vector3(0.0, teto, (z0 + z1) * 0.5)), cor, C_TETO)

	# As duas laterais da cabine, como quadrilateros com a aresta de cima curta.
	for s: float in [1.0, -1.0]:
		var quad := _quad_lateral(
			Vector3(s * h, capo, z0), Vector3(s * h, capo, z1),
			Vector3(s * h, teto, z1 - recuo), Vector3(s * h, teto, z0 + recuo),
			C_VIDRO_LADO, cor)
		PSXMesh.acumular(dados, quad, Transform3D.IDENTITY)

	# Soleira: a faixa escura embaixo da porta. Um carro sem ela flutua.
	for s: float in [1.0, -1.0]:
		_face(dados, Vector2(comp * 0.82, 0.10),
			Transform3D(Basis(Vector3.UP, s * PI * 0.5),
				Vector3(s * (larg * 0.5 + 0.005), ASSOALHO + 0.05, 0.0)),
			cor * 0.45, C_SOLEIRA)


## Quadrilatero arbitrario com uma celula do atlas. Serve para as faces que nao
## sao retangulos, que aqui sao as duas laterais da cabine.
static func _quad_lateral(a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		celula: Vector2i, cor: Color) -> Dictionary:
	var dados := PSXMesh.dados_vazios()
	var r := uv(celula)
	var v: PackedVector3Array = dados["v"]
	var n: PackedVector3Array = dados["n"]
	var u: PackedVector2Array = dados["uv"]
	var cc: PackedColorArray = dados["c"]
	var i: PackedInt32Array = dados["i"]
	var normal := (b - a).cross(d - a).normalized()
	for p: Vector3 in [a, b, c, d]:
		v.append(p)
		n.append(normal)
		cc.append(cor)
	u.append(r.position + Vector2(0.0, r.size.y))
	u.append(r.position + r.size)
	u.append(r.position + Vector2(r.size.x, 0.0))
	u.append(r.position)
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
	var lv := larg - 0.14

	# Para-brisa, inclinado para tras.
	var incl := atan2(recuo, alt)
	var xf := Transform3D(Basis(Vector3.RIGHT, -incl),
		Vector3(0.0, capo + alt * 0.5, z1 - recuo * 0.5 + 0.01))
	_face(dados, Vector2(lv, sqrt(alt * alt + recuo * recuo)), xf,
		Color(0.72, 0.80, 0.86), C_PARABRISA)

	# Vigia, inclinado para a frente.
	var xf2 := Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -incl),
		Vector3(0.0, capo + alt * 0.5, z0 + recuo * 0.5 - 0.01))
	_face(dados, Vector2(lv, sqrt(alt * alt + recuo * recuo)), xf2,
		Color(0.62, 0.70, 0.76), C_VIDRO_TRAS)


## Grade, para-choques, placa e as lampadas.
static func _frente_e_tras(dados: Dictionary, luzes: Dictionary, comp: float,
		larg: float, capo: float, _cor: Color, _modelo: Modelo) -> void:
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
static func _eixo(larg: float) -> ArrayMesh:
	var dados := PSXMesh.dados_vazios()
	var bitola := (larg - LARGURA_RODA - 0.06) * 0.5
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
