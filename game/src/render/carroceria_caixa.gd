## Carros de caixa: sedan, hatch, perua, picape e taxi, varridos pela mesma
## maquina do Marea.
##
## Os genericos eram um paralelepipedo com uma estufa em cima. De lado a roda
## quase aparecia; de frente, no transito, o flanco ia ate o chao na largura
## cheia e tapava o pneu — o carro lia como caixa deslizando. A soleira de um
## sedan oitentista e mais estreita que a cintura: a roda nasce FORA dela, e e
## isso que faz o pneu existir a trinta metros dentro da nevoa.
##
## Aqui cada modelo e uma tabela de perfil. A silhueta e o que separa os cinco:
## o sedan tem o degrau do porta-malas, o hatch despenca no vigia, a perua leva
## o teto ate o rabo, a picape corta a cabine cedo e deixa a cacamba. Sem essas
## linhas, hatch e sedan sao o mesmo tijolo em comprimentos diferentes.
##
## Sem class_name de proposito: ver Carroceria._modulo().
extends RefCounted

const OMBRO := Vector2(0.86, 0.14)

const BARRO := Color(0.42, 0.33, 0.22)
const SUJEIRA_TETO := 0.90
const SUJEIRA_FORCA := 0.55

const VIDRO := Color(0.16, 0.19, 0.22)
const VIDRO_FRENTE := Color(0.24, 0.29, 0.33)

const CROMO := Color(0.70, 0.70, 0.72)
const PLASTICO := Color(0.30, 0.30, 0.31)
const SOMBRA := Color(0.10, 0.10, 0.11)
const CAVA := Color(0.17, 0.15, 0.13)
const FRESTA := Color(0.26, 0.22, 0.17)

## Arco quadrado de canto arredondado — a assinatura da caixa oitentista, a
## mesma do Marea. Folga de 6 cm no pneu de 0,30 m.
const ARCO := [
	Vector2(0.375, 0.00), Vector2(0.335, 0.235), Vector2(0.145, 0.365),
	Vector2(-0.105, 0.355), Vector2(-0.295, 0.255), Vector2(-0.375, 0.00),
]
const ABA_ARCO := 0.017

## Sedan tres-volumes. Degrau do porta-malas e o que o faz ler sedan e nao hatch.
const PERFIL_SEDA := [
	# z      bot   cint  topo    w_bot w_cint w_topo
	[ 2.15,  0.42, 0.60, 0.76,   0.58, 0.72,  0.64],
	[ 2.04,  0.30, 0.74, 0.86,   0.66, 0.80,  0.72],
	[ 1.70,  0.26, 0.86, 0.90,   0.70, 0.84,  0.78],
	[ 1.275, 0.26, 0.90, 0.92,   0.73, 0.85,  0.80],
	[ 0.78,  0.26, 0.90, 0.94,   0.73, 0.85,  0.80],
	[ 0.42,  0.26, 0.90, 1.36,   0.73, 0.85,  0.68],
	[ 0.08,  0.26, 0.90, 1.42,   0.73, 0.85,  0.66],
	[-0.72,  0.26, 0.90, 1.42,   0.73, 0.85,  0.66],
	[-0.92,  0.26, 0.90, 1.40,   0.73, 0.85,  0.66],
	[-1.10,  0.26, 0.90, 0.98,   0.73, 0.85,  0.76],
	[-1.275, 0.26, 0.90, 0.94,   0.73, 0.85,  0.78],
	[-1.55,  0.26, 0.88, 0.94,   0.72, 0.84,  0.78],
	[-1.85,  0.28, 0.82, 0.92,   0.68, 0.82,  0.76],
	[-2.04,  0.32, 0.74, 0.86,   0.64, 0.78,  0.72],
	[-2.15,  0.42, 0.60, 0.76,   0.56, 0.70,  0.62],
]

## Hatch dois-volumes. O teto despenca no vigia; nao ha degrau de mala.
const PERFIL_HATCH := [
	[ 1.875, 0.42, 0.62, 0.80,   0.54, 0.68,  0.60],
	[ 1.76,  0.30, 0.76, 0.88,   0.62, 0.76,  0.68],
	[ 1.42,  0.26, 0.86, 0.90,   0.66, 0.80,  0.74],
	[ 1.15,  0.26, 0.88, 0.92,   0.69, 0.81,  0.76],
	[ 0.62,  0.26, 0.88, 0.94,   0.69, 0.81,  0.76],
	[ 0.28,  0.26, 0.88, 1.38,   0.69, 0.81,  0.64],
	[-0.05,  0.26, 0.88, 1.46,   0.69, 0.81,  0.62],
	[-0.55,  0.26, 0.88, 1.46,   0.69, 0.81,  0.62],
	[-0.95,  0.26, 0.88, 1.44,   0.69, 0.81,  0.62],
	[-1.20,  0.26, 0.86, 1.12,   0.69, 0.80,  0.64],
	[-1.50,  0.28, 0.80, 1.00,   0.66, 0.78,  0.66],
	[-1.76,  0.34, 0.70, 0.90,   0.60, 0.74,  0.64],
	[-1.875, 0.42, 0.62, 0.82,   0.52, 0.66,  0.58],
]

## Perua. Teto corre ate o rabo; o vigia e a porta traseira, quase a prumo.
const PERFIL_PERUA := [
	[ 2.275, 0.42, 0.62, 0.80,   0.58, 0.72,  0.64],
	[ 2.16,  0.30, 0.76, 0.88,   0.66, 0.80,  0.72],
	[ 1.80,  0.26, 0.88, 0.92,   0.72, 0.85,  0.78],
	[ 1.31,  0.26, 0.92, 0.94,   0.75, 0.87,  0.80],
	[ 0.82,  0.26, 0.92, 0.96,   0.75, 0.87,  0.80],
	[ 0.42,  0.26, 0.92, 1.48,   0.75, 0.87,  0.68],
	[ 0.05,  0.26, 0.92, 1.58,   0.75, 0.87,  0.66],
	[-1.10,  0.26, 0.92, 1.58,   0.75, 0.87,  0.66],
	[-1.55,  0.26, 0.92, 1.56,   0.75, 0.87,  0.66],
	[-1.90,  0.26, 0.90, 1.52,   0.74, 0.86,  0.66],
	[-2.16,  0.32, 0.80, 1.10,   0.66, 0.80,  0.70],
	[-2.275, 0.42, 0.64, 0.88,   0.56, 0.72,  0.62],
]

## Picape. Cabine curta; atras dela o topo cai na altura da cacamba.
const PERFIL_PICAPE := [
	[ 2.35,  0.44, 0.64, 0.82,   0.60, 0.74,  0.66],
	[ 2.22,  0.32, 0.80, 0.94,   0.68, 0.84,  0.76],
	[ 1.80,  0.26, 0.96, 0.98,   0.74, 0.88,  0.82],
	[ 1.40,  0.26, 0.98, 1.00,   0.76, 0.89,  0.84],
	[ 0.90,  0.26, 0.98, 1.02,   0.76, 0.89,  0.84],
	[ 0.50,  0.26, 0.98, 1.48,   0.76, 0.89,  0.70],
	[ 0.10,  0.26, 0.98, 1.58,   0.76, 0.89,  0.68],
	[-0.50,  0.26, 0.98, 1.58,   0.76, 0.89,  0.68],
	[-0.58,  0.26, 0.98, 1.18,   0.76, 0.89,  0.68],
	[-0.82,  0.26, 0.70, 1.12,   0.76, 0.87,  0.82],
	[-1.10,  0.26, 0.70, 1.12,   0.76, 0.87,  0.82],
	[-1.40,  0.26, 0.70, 1.12,   0.76, 0.87,  0.82],
	[-2.22,  0.28, 0.70, 1.12,   0.74, 0.86,  0.82],
	[-2.35,  0.40, 0.64, 1.02,   0.60, 0.76,  0.72],
]

## Estado da montagem corrente. `montar` nao roda em paralelo.
static var _S: Dictionary = {}

## Colagem do vidro por fora da chapa e moldura de lataria do para-brisa e do
## vigia. Em const porque `aberturas()` precisa dos MESMOS numeros que o
## desenho usa. Ver `AberturasVidro`.
const FOLGA_VIDRO := 0.012
const FOLGA_FRONTAL := 0.010
const RECUO_FRONTAL := 0.10


## O perfil desta silhueta, para quem gera a casca INTERNA dela. Ver
## `CabineCasca`.
static func perfil_cabine(modelo: int, comp: float, larg: float,
		teto: float) -> Dictionary:
	var spec := _spec(modelo)
	return {
		"perfil": spec["perfil"], "ombro": spec["ombro"], "vaos": spec["vaos"],
		"seg_p": int(spec["seg_p"]), "seg_v": int(spec["seg_v"]),
		"recuo_frontal": RECUO_FRONTAL, "folga_vidro": FOLGA_VIDRO,
		"folga_frontal": FOLGA_FRONTAL,
		"escala": Vector3(larg / float(spec["larg"]), teto / float(spec["alt"]),
			comp / float(spec["comp"])),
	}


## Onde estao os vidros deste carro, no espaco final da lataria.
##
## Le a mesma silhueta que `montar` usa (`_spec`), entao sedan, hatch, perua,
## picape e taxi saem certos sem tabela nova. Ver `AberturasVidro`.
static func aberturas(modelo: int, comp: float, larg: float,
		teto: float) -> Array[Dictionary]:
	var spec := _spec(modelo)
	var perfil: Array = spec["perfil"]
	var ombro: Vector2 = spec["ombro"]
	var vaos: Array = spec["vaos"]
	var e := Vector3(larg / float(spec["larg"]), teto / float(spec["alt"]),
		comp / float(spec["comp"]))
	var nomes := AberturasVidro.nomes(vaos.size())
	var out: Array[Dictionary] = []
	for s: float in [1.0, -1.0]:
		for i in vaos.size():
			out.append(AberturasVidro.registro(nomes[i], int(s),
				AberturasVidro.lado(perfil, ombro, vaos[i], s, FOLGA_VIDRO),
				e, FOLGA_VIDRO))
	for par: Array in [[&"parabrisa", int(spec["seg_p"])],
			[&"vigia", int(spec["seg_v"])]]:
		var k: int = par[1]
		# A picape corta a cabine cedo e pode nao ter estacao de vigia.
		if k < 0 or k + 1 >= perfil.size():
			continue
		out.append(AberturasVidro.registro(par[0], 0,
			AberturasVidro.frontal(perfil, k, RECUO_FRONTAL, FOLGA_FRONTAL),
			e, FOLGA_FRONTAL))
	return out


static func montar(corpo: Dictionary, luzes: Dictionary, modelo: int,
		comp: float, larg: float, teto: float, cor: Color,
		com_vidros_frente: bool, suja: bool = true) -> void:
	_S = _spec(modelo)
	_S["suja"] = suja
	var c := PSXMesh.dados_vazios()
	var l := PSXMesh.dados_vazios()

	_casco(c, cor)
	_janelas_lado(c)
	if com_vidros_frente:
		_parabrisa_e_vigia(c)
	_arcos(c, cor)
	_frente(c, l)
	_traseira(c, l)
	_flancos(c, cor)
	if bool(_S["picape"]):
		_cacamba(c, cor)
	if bool(_S["taxi"]):
		_letreiro(c)

	var e := Vector3(
		larg / float(_S["larg"]),
		teto / float(_S["alt"]),
		comp / float(_S["comp"]))
	PSXMesh.acumular(corpo, c, Transform3D(Basis().scaled(e), Vector3.ZERO))
	PSXMesh.acumular(luzes, l, Transform3D(Basis().scaled(e), Vector3.ZERO))
	_S = {}


static func _spec(modelo: int) -> Dictionary:
	match modelo:
		Carroceria.Modelo.HATCH:
			return {
				"perfil": PERFIL_HATCH, "ombro": OMBRO,
				"comp": 3.75, "larg": 1.62, "alt": 1.46,
				"eixo_f": 1.15, "eixo_t": -1.15,
				"seg_p": 4, "seg_v": 8,
				"vaos": [
					[0.28, 0.16, 0.12, 0.50],
					[0.12, -0.50, 0.10, 0.82],
					[-0.58, -0.90, 0.10, 0.70],
				],
				"portas": [0.16, -0.52],
				"macanetas": [-0.08],
				"duas_portas": true, "picape": false, "taxi": false,
				"barato": true,
			}
		Carroceria.Modelo.PERUA:
			return {
				"perfil": PERFIL_PERUA, "ombro": OMBRO,
				"comp": 4.55, "larg": 1.74, "alt": 1.58,
				"eixo_f": 1.31, "eixo_t": -1.31,
				"seg_p": 4, "seg_v": 9,
				"vaos": [
					[0.36, 0.24, 0.12, 0.50],
					[0.20, -0.40, 0.10, 0.82],
					[-0.48, -1.05, 0.10, 0.80],
					[-1.12, -1.52, 0.10, 0.76],
				],
				"portas": [0.36, -0.44, -1.08],
				"macanetas": [-0.10, -0.72],
				"duas_portas": false, "picape": false, "taxi": false,
				"barato": false,
			}
		Carroceria.Modelo.PICAPE:
			return {
				"perfil": PERFIL_PICAPE, "ombro": OMBRO,
				"comp": 4.70, "larg": 1.78, "alt": 1.58,
				"eixo_f": 1.40, "eixo_t": -1.40,
				"seg_p": 4, "seg_v": 7,
				"vaos": [
					[0.42, 0.28, 0.12, 0.48],
					[0.24, -0.36, 0.10, 0.82],
				],
				"portas": [0.40, -0.38],
				"macanetas": [-0.12],
				"duas_portas": true, "picape": true, "taxi": false,
				"barato": true,
			}
		Carroceria.Modelo.TAXI:
			var t := _spec(Carroceria.Modelo.SEDA)
			t["taxi"] = true
			return t
		_:
			return {
				"perfil": PERFIL_SEDA, "ombro": OMBRO,
				"comp": 4.30, "larg": 1.70, "alt": 1.42,
				"eixo_f": 1.275, "eixo_t": -1.275,
				"seg_p": 4, "seg_v": 8,
				"vaos": [
					[0.34, 0.22, 0.12, 0.50],
					[0.18, -0.36, 0.10, 0.82],
					[-0.44, -0.82, 0.10, 0.78],
				],
				"portas": [0.34, -0.40, -0.82],
				"macanetas": [-0.10, -0.70],
				"duas_portas": false, "picape": false, "taxi": false,
				"barato": false,
			}


static func _ponto_lado(z: float, t: float, s: float) -> Vector3:
	return CarroceriaVarrida.ponto_lado(_S["perfil"], _S["ombro"], z, t, s)


static func _ponto_topo(z: float, u: float) -> Vector3:
	return CarroceriaVarrida.ponto_topo(_S["perfil"], z, u)


static func _normal_topo(z: float) -> Vector3:
	return CarroceriaVarrida.normal_topo(_S["perfil"], z)


static func _base_topo(z: float) -> Basis:
	return CarroceriaVarrida.base_topo(_S["perfil"], z)


static func _x_casco(z: float, y: float) -> float:
	return CarroceriaVarrida.x_casco(_S["perfil"], _S["ombro"], z, y)


static func _sujo(cor: Color, y: float) -> Color:
	var forca := SUJEIRA_FORCA if bool(_S.get("suja", false)) else SUJEIRA_FORCA * 0.40
	return CarroceriaVarrida.sujo(cor, BARRO, y, SUJEIRA_TETO, forca)


static func _casco(dados: Dictionary, cor: Color) -> void:
	var celula := (Carroceria.C_LATARIA_SUJA if bool(_S.get("suja", false))
		else Carroceria.C_LATARIA)
	var picape := bool(_S["picape"])
	CarroceriaVarrida.casco(dados, _S["perfil"], _S["ombro"], celula,
		func(y: float) -> Color: return _sujo(cor, y),
		-0.70 if picape else -1000.0, not picape)


static func _janelas_lado(dados: Dictionary) -> void:
	var vaos: Array = _S["vaos"]
	for s: float in [1.0, -1.0]:
		var fora := Vector3(s, 0.0, 0.0)
		for v: Array in vaos:
			var d := fora * FOLGA_VIDRO
			CarroceriaVarrida.quad(dados,
				_ponto_lado(v[0], v[2], s) + d, _ponto_lado(v[1], v[2], s) + d,
				_ponto_lado(v[1], v[3], s) + d, _ponto_lado(v[0], v[3], s) + d,
				Carroceria.C_VIDRO_LADO, VIDRO, VIDRO, VIDRO, VIDRO, fora)


static func _parabrisa_e_vigia(dados: Dictionary) -> void:
	var perfil: Array = _S["perfil"]
	for k: int in [int(_S["seg_p"]), int(_S["seg_v"])]:
		if k < 0 or k + 1 >= perfil.size():
			continue
		var za: float = perfil[k][0]
		var zb: float = perfil[k + 1][0]
		var ea: Array = (perfil[k] as Array).slice(1)
		var eb: Array = (perfil[k + 1] as Array).slice(1)
		var q0 := Vector3(-ea[5], ea[2], za)
		var q1 := Vector3(ea[5], ea[2], za)
		var q2 := Vector3(eb[5], eb[2], zb)
		var q3 := Vector3(-eb[5], eb[2], zb)
		var i := CarroceriaVarrida.inset(q0, q1, q2, q3, RECUO_FRONTAL)
		var fora := CarroceriaVarrida.normal_placa(q0, q1, q3)
		var d := fora * FOLGA_FRONTAL
		var celula := (Carroceria.C_PARABRISA if k == int(_S["seg_p"])
			else Carroceria.C_VIDRO_TRAS)
		CarroceriaVarrida.quad(dados, i[0] + d, i[1] + d, i[2] + d, i[3] + d,
			celula, VIDRO_FRENTE, VIDRO_FRENTE, VIDRO_FRENTE, VIDRO_FRENTE,
			fora)


static func _arcos(dados: Dictionary, cor: Color) -> void:
	for zc: float in [float(_S["eixo_f"]), float(_S["eixo_t"])]:
		for s: float in [1.0, -1.0]:
			var fora := Vector3(s, 0.0, 0.0)
			var borda := []
			var aba := []
			var dentro := []
			for a: Vector2 in ARCO:
				var y := 0.30 + a.y
				var z := zc + a.x
				borda.append(Vector3(s * (_x_casco(z, y) + 0.006), y, z))
				var ya := 0.30 + a.y * 1.10
				var za := zc + a.x * 1.06
				aba.append(Vector3(s * (_x_casco(za, ya) + ABA_ARCO), ya, za))
				var yi := 0.30 + a.y * 0.84
				var zi := zc + a.x * 0.84
				dentro.append(Vector3(s * (_x_casco(zi, yi) + 0.006), yi, zi))
			for k in ARCO.size() - 1:
				var b0: Vector3 = borda[k]
				var b1: Vector3 = borda[k + 1]
				var d0: Vector3 = dentro[k]
				var d1: Vector3 = dentro[k + 1]
				CarroceriaVarrida.quad(dados, d0, d1, b1, b0,
					Carroceria.C_FUNDO, CAVA, CAVA, CAVA * 0.7, CAVA * 0.7,
					fora)
				var a0: Vector3 = aba[k]
				var a1: Vector3 = aba[k + 1]
				CarroceriaVarrida.quad(dados, b0, b1, a1, a0,
					Carroceria.C_LATARIA_SUJA,
					_sujo(cor, b0.y) * 0.72, _sujo(cor, b1.y) * 0.72,
					_sujo(cor, a1.y), _sujo(cor, a0.y), fora)


static func _frente(dados: Dictionary, luzes: Dictionary) -> void:
	var perfil: Array = _S["perfil"]
	var zf: float = perfil[0][0]
	var barato := bool(_S["barato"])
	var meia: float = float(_S["larg"]) * 0.5
	var ox := meia * 0.64
	# Cintura da face dianteira, nao um Y chutado: no hatch/picape o capo
	# nao e o do sedan.
	var y_grade: float = float((perfil[1] as Array)[2])
	var grade_c := PLASTICO if barato else CROMO * 0.86

	CarroceriaVarrida.plana(dados, Vector2(meia * 0.92, 0.18),
		Transform3D(Basis(), Vector3(0.0, y_grade, zf + 0.004)),
		SOMBRA, Carroceria.C_GRADE)
	for k in 5:
		var yy := lerpf(y_grade - 0.070, y_grade + 0.070, float(k) / 4.0)
		CarroceriaVarrida.plana(dados, Vector2(meia * 0.84, 0.014),
			Transform3D(Basis(), Vector3(0.0, yy, zf + 0.010)),
			grade_c, Carroceria.C_GRADE)

	for s: float in [1.0, -1.0]:
		CarroceriaVarrida.plana(dados, Vector2(0.30, 0.155),
			Transform3D(Basis(), Vector3(s * ox, y_grade, zf + 0.006)),
			Color(0.16, 0.17, 0.19), Carroceria.C_GRADE)
		CarroceriaVarrida.plana(luzes, Vector2(0.235, 0.105),
			Transform3D(Basis(), Vector3(s * ox, y_grade, zf + 0.014)),
			Color.WHITE, Carroceria.C_FAROL)
		CarroceriaVarrida.plana(luzes, Vector2(0.070, 0.115),
			Transform3D(Basis(),
				Vector3(s * (ox + 0.175), y_grade, zf + 0.010)),
			Color(1.0, 0.66, 0.16), Carroceria.C_PISCA)

	_parachoque(dados, zf + 0.032, y_grade - 0.28, true, barato)
	CarroceriaVarrida.plana(dados, Vector2(0.30, 0.10),
		Transform3D(Basis(), Vector3(0.0, y_grade - 0.22, zf + 0.050)),
		Color(0.86, 0.86, 0.84), Carroceria.C_PLACA)

	var z_cowl: float = perfil[int(_S["seg_p"])][0]
	_fresta_topo(dados, z_cowl + 0.08, zf - 0.12, 0.72)
	for s: float in [1.0, -1.0]:
		var zc := z_cowl + 0.04
		CarroceriaVarrida.plana(dados, Vector2(0.30, 0.045),
			Transform3D(_base_topo(zc),
				_ponto_topo(zc, s * 0.40) + _normal_topo(zc) * 0.008),
			SOMBRA, Carroceria.C_GRADE)
		var zl := z_cowl + 0.02
		CarroceriaVarrida.plana(dados, Vector2(0.36, 0.016),
			Transform3D(_base_topo(zl) * Basis(Vector3.BACK, s * 0.28),
				_ponto_topo(zl, s * 0.32) + _normal_topo(zl) * 0.012),
			Color(0.12, 0.12, 0.13), Carroceria.C_PARACHOQUE)


static func _traseira(dados: Dictionary, luzes: Dictionary) -> void:
	var perfil: Array = _S["perfil"]
	var zt: float = perfil[perfil.size() - 1][0]
	var barato := bool(_S["barato"])
	var picape := bool(_S["picape"])
	var costas := Basis(Vector3.UP, PI)
	var meia: float = float(_S["larg"]) * 0.5
	var ox := meia * 0.64
	var y_luz: float = float((perfil[perfil.size() - 2] as Array)[2])
	if picape:
		y_luz = 0.92

	if not picape:
		CarroceriaVarrida.plana(dados, Vector2(meia * 0.84, 0.19),
			Transform3D(costas, Vector3(0.0, y_luz - 0.02, zt - 0.006)),
			SOMBRA * 1.8, Carroceria.C_TRASEIRA)
		CarroceriaVarrida.plana(dados, Vector2(0.30, 0.10),
			Transform3D(costas, Vector3(0.0, y_luz - 0.04, zt - 0.014)),
			Color(0.84, 0.84, 0.82), Carroceria.C_PLACA)

	for s: float in [1.0, -1.0]:
		var lx := s * ox
		CarroceriaVarrida.plana(dados, Vector2(0.30, 0.22),
			Transform3D(costas, Vector3(lx, y_luz, zt - 0.005)),
			Color(0.12, 0.12, 0.13), Carroceria.C_GRADE)
		CarroceriaVarrida.plana(luzes, Vector2(0.185, 0.185),
			Transform3D(costas, Vector3(lx - s * 0.050, y_luz, zt - 0.012)),
			Color.WHITE, Carroceria.C_LANTERNA)
		CarroceriaVarrida.plana(luzes, Vector2(0.080, 0.070),
			Transform3D(costas, Vector3(lx - s * 0.050, y_luz - 0.055, zt - 0.018)),
			Color.WHITE, Carroceria.C_RE)
		CarroceriaVarrida.plana(luzes, Vector2(0.070, 0.185),
			Transform3D(costas, Vector3(lx + s * 0.100, y_luz, zt - 0.012)),
			Color(1.0, 0.62, 0.14), Carroceria.C_PISCA)

	_parachoque(dados, zt - 0.032, y_luz - 0.36 if not picape else 0.42, false, barato)
	CarroceriaVarrida.plana(dados, Vector2(0.055, 0.05),
		Transform3D(costas, Vector3(meia * 0.40, 0.34, zt - 0.05)),
		Color(0.17, 0.16, 0.15), Carroceria.C_PARACHOQUE)

	if not picape:
		var z_vigia: float = perfil[int(_S["seg_v"])][0]
		_fresta_topo(dados, z_vigia - 0.08, zt + 0.14, 0.74)


static func _parachoque(dados: Dictionary, z: float, y: float,
		frente: bool, barato: bool) -> void:
	var dz := 1.0 if frente else -1.0
	var larg: float = float(_S["larg"]) * 0.5 - 0.04
	var alt := 0.135
	var us := [-1.0, -0.62, 0.0, 0.62, 1.0]
	var recuos := [0.16, 0.045, 0.0, 0.045, 0.16]
	var tinta: Color = PLASTICO * 1.15 if barato else CROMO
	var pontos := []
	for k in us.size():
		var zz: float = z - dz * recuos[k]
		pontos.append([
			Vector3(us[k] * larg, y + alt * 0.5, zz),
			Vector3(us[k] * larg, y - alt * 0.5, zz),
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
		CarroceriaVarrida.quad(dados, a0, b0, b1, a1, Carroceria.C_PARACHOQUE,
			tinta * 1.06, tinta * 1.06, tinta * 0.9, tinta * 0.9, fora)
		CarroceriaVarrida.quad(dados, a0, b0, b0 - recuo, a0 - recuo,
			Carroceria.C_PARACHOQUE, tinta * 1.16, tinta * 1.16,
			tinta * 0.88, tinta * 0.88, Vector3.UP)
		CarroceriaVarrida.quad(dados, a1, b1, b1 - recuo, a1 - recuo,
			Carroceria.C_PARACHOQUE, PLASTICO * 0.85, PLASTICO * 0.85,
			SOMBRA, SOMBRA, Vector3.DOWN)


static func _flancos(dados: Dictionary, _cor: Color) -> void:
	var eixo_f: float = float(_S["eixo_f"])
	var eixo_t: float = float(_S["eixo_t"])
	var portas: Array = _S["portas"]
	var macanetas: Array = _S["macanetas"]
	# Para ENTRE os arcos. Friso em cima do pneu era o risco claro que
	# atravessava a roda e, na picape, descia na cacamba virando diagonal.
	var z_faixa_f := eixo_f - 0.44
	var z_faixa_t := eixo_t + 0.44
	if bool(_S["picape"]):
		z_faixa_t = -0.42
	for s: float in [1.0, -1.0]:
		var fora := Vector3(s, 0.0, 0.0)
		_faixa_lado(dados, s, z_faixa_f, z_faixa_t, 0.04, -0.02,
			CROMO * 0.95, 4)
		_faixa_lado(dados, s, z_faixa_f, z_faixa_t, -0.22, -0.28,
			PLASTICO * 1.25, 5)
		_faixa_lado(dados, s, z_faixa_f * 0.85, z_faixa_t * 0.85, -0.82, -0.96,
			BARRO * 0.62, 3)
		for z: float in portas:
			var w := 0.012
			for k in 3:
				var t0 := lerpf(0.86, -0.90, float(k) / 3.0)
				var t1 := lerpf(0.86, -0.90, float(k + 1) / 3.0)
				var a := _ponto_lado(z, t0, s) + fora * 0.010
				var b := _ponto_lado(z, t1, s) + fora * 0.010
				CarroceriaVarrida.quad(dados,
					a + Vector3(0, 0, w), b + Vector3(0, 0, w),
					b - Vector3(0, 0, w), a - Vector3(0, 0, w),
					Carroceria.C_SOLEIRA, SOMBRA, SOMBRA, SOMBRA, SOMBRA, fora)
		for z: float in macanetas:
			CarroceriaVarrida.plana(dados, Vector2(0.11, 0.028),
				Transform3D(Basis(Vector3.UP, s * PI * 0.5),
					_ponto_lado(z, -0.14, s) + fora * 0.012),
				CROMO * 0.9, Carroceria.C_PARACHOQUE)

	var raiz := _ponto_lado(float(_S["vaos"][0][0]) - 0.04, 0.16, 1.0)
	var esp := raiz + Vector3(0.075, 0.035, 0.02)
	CarroceriaVarrida.plana(dados, Vector2(0.085, 0.055),
		Transform3D(Basis(Vector3.UP, 0.26), esp),
		Color(0.28, 0.32, 0.36), Carroceria.C_VIDRO_LADO)
	CarroceriaVarrida.plana(dados, Vector2(0.085, 0.055),
		Transform3D(Basis(Vector3.UP, PI + 0.26), esp),
		PLASTICO, Carroceria.C_PARACHOQUE)
	CarroceriaVarrida.quad(dados, raiz, esp + Vector3(0.0, -0.024, 0.0),
		esp + Vector3(0.0, -0.024, 0.028), raiz + Vector3(0.0, 0.0, 0.028),
		Carroceria.C_PARACHOQUE, PLASTICO, PLASTICO, PLASTICO, PLASTICO,
		Vector3.UP)


static func _faixa_lado(dados: Dictionary, s: float, z0: float, z1: float,
		t0: float, t1: float, cor: Color, passos: int) -> void:
	var fora := Vector3(s, 0.0, 0.0)
	for k in passos:
		var za := lerpf(z0, z1, float(k) / float(passos))
		var zb := lerpf(z0, z1, float(k + 1) / float(passos))
		CarroceriaVarrida.quad(dados,
			_ponto_lado(za, t0, s) + fora * 0.010,
			_ponto_lado(zb, t0, s) + fora * 0.010,
			_ponto_lado(zb, t1, s) + fora * 0.010,
			_ponto_lado(za, t1, s) + fora * 0.010,
			Carroceria.C_SOLEIRA, cor, cor, cor * 0.85, cor * 0.85, fora)


static func _fresta_topo(dados: Dictionary, z0: float, z1: float,
		u: float) -> void:
	for s: float in [1.0, -1.0]:
		for k in 3:
			var za := lerpf(z0, z1, float(k) / 3.0)
			var zb := lerpf(z0, z1, float(k + 1) / 3.0)
			var na := _normal_topo(za) * 0.007
			var nb := _normal_topo(zb) * 0.007
			CarroceriaVarrida.quad(dados,
				_ponto_topo(za, s * u) + na,
				_ponto_topo(za, s * (u + 0.035)) + na,
				_ponto_topo(zb, s * (u + 0.035)) + nb,
				_ponto_topo(zb, s * u) + nb,
				Carroceria.C_SOLEIRA, FRESTA, FRESTA, FRESTA, FRESTA,
				Vector3.UP)


## Piso, paredes internas e tampa da cacamba. O casco pula o teto atras da
## cabine; sem isto o vao mostra o oco do carro ate o assoalho.
static func _cacamba(dados: Dictionary, cor: Color) -> void:
	var perfil: Array = _S["perfil"]
	var z0 := -0.70
	var z1: float = float(perfil[perfil.size() - 1][0]) + 0.04
	var y_rail := 1.10
	var y_piso := 0.72
	var meia: float = float(_S["larg"]) * 0.5 - 0.08
	var piso := cor * 0.42
	CarroceriaVarrida.quad(dados,
		Vector3(-meia, y_piso, z0), Vector3(meia, y_piso, z0),
		Vector3(meia, y_piso, z1), Vector3(-meia, y_piso, z1),
		Carroceria.C_CACAMBA, piso, piso, piso * 0.8, piso * 0.8, Vector3.UP)
	for s: float in [1.0, -1.0]:
		CarroceriaVarrida.quad(dados,
			Vector3(s * meia, y_piso, z0), Vector3(s * meia, y_piso, z1),
			Vector3(s * meia, y_rail, z1), Vector3(s * meia, y_rail, z0),
			Carroceria.C_CACAMBA, SOMBRA, SOMBRA, PLASTICO, PLASTICO,
			Vector3(-s, 0.0, 0.0))
	# Cabeca da cacamba (atras da cabine).
	CarroceriaVarrida.quad(dados,
		Vector3(-meia, y_piso, z0), Vector3(meia, y_piso, z0),
		Vector3(meia, y_rail, z0), Vector3(-meia, y_rail, z0),
		Carroceria.C_CACAMBA, SOMBRA, SOMBRA, PLASTICO, PLASTICO,
		Vector3.BACK)
	# Tampa traseira + placa. Sem a tampa do casco, o rabo ficava oco.
	var costas := Basis(Vector3.UP, PI)
	CarroceriaVarrida.quad(dados,
		Vector3(-meia, y_piso, z1), Vector3(meia, y_piso, z1),
		Vector3(meia, y_rail, z1), Vector3(-meia, y_rail, z1),
		Carroceria.C_CACAMBA, PLASTICO, PLASTICO, cor * 0.7, cor * 0.7,
		Vector3.FORWARD)
	CarroceriaVarrida.plana(dados, Vector2(0.30, 0.10),
		Transform3D(costas, Vector3(0.0, y_piso + 0.14, z1 - 0.012)),
		Color(0.84, 0.84, 0.82), Carroceria.C_PLACA)


static func _letreiro(dados: Dictionary) -> void:
	var p := _ponto_topo(0.10, 0.0)
	for lado: float in [0.0, PI]:
		CarroceriaVarrida.plana(dados, Vector2(0.46, 0.14),
			Transform3D(Basis(Vector3.UP, lado),
				Vector3(0.0, p.y + 0.08, p.z)),
			Color.WHITE, Carroceria.C_LETREIRO_TAXI)
