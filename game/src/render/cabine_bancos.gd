## Os bancos: assento e encosto de gomos costurados, abas laterais, encosto de
## cabeca nas hastes cromadas, trilho, alavanca de reclinar e a fivela do
## cinto; e o banco de tras inteirico, de dois lugares.
##
## O desenho e o dos populares dos anos 90: o miolo de veludo listrado em gomos
## (as costuras sao o vao entre duas almofadas, e nao uma linha pintada) e as
## abas mais escuras e mais altas, que seguram o corpo na curva.
##
## Medidas que outros usam
## -----------------------
## O tampo do assento fica a 29,5 cm do assoalho e a borda da frente 8 cm a
## frente do olho: `MotoristaCena` larga o celular no banco do carona contando
## com os dois (`ASSENTO_TAMPO`, `ASSENTO_FRENTE`). Os bancos antigos eram uma
## caixa de 15 cm centrada a 22 cm; o miolo daqui chega ao mesmo tampo.
class_name CabineBancos
extends RefCounted

## Tampo do miolo do assento acima do assoalho, e o centro do assento atras do
## olho.
const TAMPO := 0.295
const ASSENTO_Z := 0.16
## Encosto: dobradica atras do assento, inclinacao e altura.
const ENCOSTO_INCLINACAO := 13.0
const ENCOSTO_ALTURA := 0.56
## Largura de cada aba lateral, em metros.
const ABA := 0.052


static func montar(it: CabineInterior) -> void:
	var g := it.g
	var piso: float = g["piso"]
	var olho: Vector3 = g["olho"]
	var bancos: Vector2 = g["bancos"]
	var ficha: Dictionary = g["ficha"]
	var cores := _cores(ficha)
	for s: float in [-1.0, 1.0]:
		_banco(it, Vector3(s * bancos.x, piso, olho.z + ASSENTO_Z), bancos.y, s, cores)
	if bool(ficha["banco_tras"]):
		_banco_de_tras(it, cores)


## Miolo (veludo listrado), aba (mais escura) e a base de plastico.
static func _cores(ficha: Dictionary) -> Dictionary:
	var b: Color = ficha["banco"]
	var miolo := Color(b.r * 1.10, b.g * 0.96, b.b * 0.82, 1.0)
	return {
		"miolo": miolo,
		"aba": Color(miolo.darkened(0.38), 0.0),
		"base": CabineInterior.COR_PECA,
	}


## Um banco da frente. `onde` e o assoalho embaixo do centro do assento; `s` e
## o lado, que e tambem o sinal do lado da porta (-1 o do motorista).
static func _banco(it: CabineInterior, onde: Vector3, larg: float, s: float,
		cores: Dictionary) -> void:
	var tec := it.m(&"tecido")
	var pl := it.m(&"plastico")
	var met := it.m(&"metal")
	var meia := larg * 0.5
	var miolo: Color = cores["miolo"]
	var aba: Color = cores["aba"]
	# O assento pende um pouco para tras, como todo assento de carro.
	var assento := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(3.0)), onde)
	tec.xf = assento
	# A base estofada, embaixo de tudo.
	tec.caixa(Vector3(0, TAMPO - 0.115, 0), Vector3(meia, 0.045, 0.235), 0.03, aba)
	# As abas, mais altas que o miolo.
	for lado: float in [-1.0, 1.0]:
		tec.caixa(Vector3(lado * (meia - ABA), TAMPO - 0.048, 0.005),
			Vector3(ABA, 0.046, 0.222), 0.034, aba, Basis(), 3, 0.012, 3)
	# O miolo em tres gomos: a costura e o vao entre eles.
	var gomos := 3
	var z0 := -0.215
	var z1 := 0.205
	var passo := (z1 - z0) / float(gomos)
	for k in gomos:
		var zc := z0 + passo * (float(k) + 0.5)
		# O gomo da frente dobra a quina do assento: raio maior.
		var r := 0.030 if k == 0 else 0.018
		tec.caixa(Vector3(0, TAMPO - 0.047, zc),
			Vector3(meia - ABA * 2.0 + 0.004, 0.035, passo * 0.5 - 0.002), r,
			Color(miolo, 1.0), Basis(), 3, 0.012, 3)
	tec.xf = Transform3D.IDENTITY

	# A base de plastico e o trilho no assoalho.
	pl.caixa(onde + Vector3(0, 0.10, -0.01), Vector3(meia - 0.035, 0.055, 0.205), 0.012,
		cores["base"])
	for lado: float in [-1.0, 1.0]:
		met.caixa(onde + Vector3(lado * meia * 0.62, 0.018, 0.0),
			Vector3(0.016, 0.014, 0.30), 0.004, Color(0.22, 0.22, 0.23, 0.5))
	# A alavanca de reclinar, do lado da porta, atras.
	var porta := s
	pl.caixa(onde + Vector3(porta * (meia + 0.008), TAMPO - 0.10, 0.19),
		Vector3(0.008, 0.012, 0.055), 0.006, CabineInterior.COR_PECA_LISA,
		Basis(Vector3.RIGHT, deg_to_rad(-18.0)))
	# A fivela do cinto, do lado do console.
	var fivela := onde + Vector3(-porta * (meia + 0.018), TAMPO - 0.02, 0.17)
	var haste := PackedVector3Array([onde + Vector3(-porta * (meia + 0.02), 0.10, 0.20),
		fivela + Vector3(0, -0.035, 0.01)])
	pl.tubo(haste, PackedFloat32Array([0.009]), CabineInterior.COR_PECA, 10)
	pl.caixa(fivela, Vector3(0.012, 0.035, 0.018), 0.008, CabineInterior.COR_PECA_LISA,
		Basis(Vector3.RIGHT, deg_to_rad(-15.0)))
	pl.caixa(fivela + Vector3(0, 0.030, -0.004), Vector3(0.008, 0.006, 0.012), 0.004,
		Color(0.55, 0.05, 0.03, 0.2), Basis(Vector3.RIGHT, deg_to_rad(-15.0)))

	# O encosto, na dobradica atras do assento.
	var dobradica := onde + Vector3(0, TAMPO - 0.06, 0.225)
	var b := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(ENCOSTO_INCLINACAO)), dobradica)
	_encosto(it, b, meia, cores, 4, true)
	_bolso(it, b, meia)


## O encosto no referencial da dobradica: +Y sobe pelo encosto, -Z e a frente
## (as costas de quem senta). A frente das almofadas e o +Y delas: por isso a
## base `frente` gira o +Y da caixa para o -Z do encosto.
static func _encosto(it: CabineInterior, b: Transform3D, meia: float,
		cores: Dictionary, gomos: int, com_cabeca: bool) -> void:
	var tec := it.m(&"tecido")
	var frente := Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
	var miolo: Color = cores["miolo"]
	var aba: Color = cores["aba"]
	var h := ENCOSTO_ALTURA
	tec.xf = b
	# A casca de tras.
	tec.caixa(Vector3(0, h * 0.5, 0.03), Vector3(meia, 0.05, h * 0.5), 0.035, aba, frente)
	for lado: float in [-1.0, 1.0]:
		tec.caixa(Vector3(lado * (meia - ABA), h * 0.48, -0.035),
			Vector3(ABA, 0.035, h * 0.46), 0.03, aba, frente, 3, 0.014, 3)
	var y0 := 0.05
	var y1 := h - 0.04
	var passo := (y1 - y0) / float(gomos)
	for k in gomos:
		var yc := y0 + passo * (float(k) + 0.5)
		# O apoio lombar: o segundo gomo de baixo sai um pouco mais.
		var lombar := 0.008 if k == 1 else 0.0
		tec.caixa(Vector3(0, yc, -0.030 - lombar),
			Vector3(meia - ABA * 2.0 + 0.004, 0.026, passo * 0.5 - 0.002), 0.016,
			Color(miolo, 1.0), frente, 3, 0.013, 3)
	tec.xf = Transform3D.IDENTITY
	if not com_cabeca:
		return
	_encosto_de_cabeca(it, b * Transform3D(Basis(), Vector3(0, h + 0.075, 0.012)),
		minf(meia * 0.56, 0.135), cores)


static func _encosto_de_cabeca(it: CabineInterior, c: Transform3D, meia: float,
		cores: Dictionary) -> void:
	var tec := it.m(&"tecido")
	var frente := Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
	tec.xf = c
	tec.caixa(Vector3.ZERO, Vector3(meia, 0.048, 0.072), 0.04, cores["aba"], frente, 4)
	tec.caixa(Vector3(0, -0.004, -0.030), Vector3(meia - 0.03, 0.022, 0.052), 0.02,
		Color(cores["miolo"], 1.0), frente, 3, 0.010, 3)
	tec.xf = Transform3D.IDENTITY
	# As duas hastes cromadas, da cabeca ate o encosto.
	for lado: float in [-1.0, 1.0]:
		var topo := c * Vector3(lado * meia * 0.45, -0.05, 0.0)
		var pe := c * Vector3(lado * meia * 0.45, -0.11, 0.0)
		it.m(&"metal").tubo(PackedVector3Array([pe, topo]), PackedFloat32Array([0.0055]),
			CabineInterior.COR_CROMO, 12)
		# O colar de plastico onde a haste entra no encosto.
		it.m(&"plastico").torno(Transform3D(c.basis * Basis(Vector3.RIGHT, -PI * 0.5),
			pe), [Vector2(0.0, 0.004), Vector2(0.0075, 0.004), Vector2(0.0095, 0.0)],
			CabineInterior.COR_PECA, 16)


## O bolso de revista nas costas do banco, com o elastico no alto.
static func _bolso(it: CabineInterior, b: Transform3D, meia: float) -> void:
	var tec := it.m(&"tecido")
	var tras := Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN)
	tec.xf = b
	tec.caixa(Vector3(0, 0.20, 0.084), Vector3(meia - 0.07, 0.006, 0.12), 0.006,
		Color(0.09, 0.08, 0.07, 0.0), tras, 3, 0.004, 2)
	tec.xf = Transform3D.IDENTITY
	var pl := it.m(&"plastico")
	pl.xf = b
	pl.caixa(Vector3(0, 0.318, 0.090), Vector3(meia - 0.07, 0.005, 0.004), 0.003,
		Color(0.05, 0.05, 0.05, 1.0))
	pl.xf = Transform3D.IDENTITY


## O banco de tras: um assento corrido, dois lugares de gomos e o encosto
## inteirico com dois encostos de cabeca.
##
## Ele pergunta a lataria antes de se inclinar
## -------------------------------------------
## Num sedan o vidro traseiro desce por cima do encosto. Com a mesma inclinacao
## e os encostos de cabeca do banco da frente, o alto dele saia 23 cm por fora
## do vidro (`checar_cabine_contida`). O banco antigo era uma caixa em pe e nao
## tinha o problema porque nao tinha forma. Aqui ele endireita e avanca ate
## caber, e so ganha encosto de cabeca se couber tambem.
static func _banco_de_tras(it: CabineInterior, cores: Dictionary) -> void:
	var g := it.g
	var piso: float = g["piso"]
	var olho: Vector3 = g["olho"]
	var info: Dictionary = g["info"]
	var z_tras: float = g["z_tras"]
	var z_encosto := lerpf(olho.z + 0.42, z_tras, 0.72)
	var meia := absf(CabineCasca.parede_x(info, piso + 0.45, z_encosto, 1.0)) * 0.86
	var h := ENCOSTO_ALTURA - 0.06
	var incl := ENCOSTO_INCLINACAO
	var z_min := olho.z + 0.42 + 0.30
	var cabeca := true
	var b := Transform3D()
	for tentativa in 12:
		b = _dobradica_de_tras(piso, z_encosto, incl)
		var pior := -1.0
		for q: Vector3 in [Vector3(meia, h, 0.08), Vector3(-meia, h, 0.08),
				Vector3(0, h, 0.08)]:
			pior = maxf(pior, it.sobra(b * q))
		if pior < -0.015:
			break
		if incl > 6.0:
			incl -= 3.0
		elif z_encosto - 0.03 > z_min:
			z_encosto -= 0.03
		else:
			break
	for lugar: float in [-1.0, 1.0]:
		var topo := b * Vector3(lugar * meia * 0.48, h + 0.15, 0.06)
		if it.sobra(topo) > -0.015:
			cabeca = false
	var tec := it.m(&"tecido")
	var aba: Color = cores["aba"]
	var miolo: Color = cores["miolo"]
	var onde := Vector3(0, piso, z_encosto - 0.25)
	tec.xf = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(3.0)), onde)
	tec.caixa(Vector3(0, TAMPO - 0.12, 0), Vector3(meia, 0.05, 0.23), 0.03, aba)
	for lugar: float in [-1.0, 1.0]:
		var xc := lugar * meia * 0.48
		var ml := meia * 0.40
		for k in 3:
			var zc := lerpf(-0.21, 0.20, (float(k) + 0.5) / 3.0)
			tec.caixa(Vector3(xc, TAMPO - 0.05, zc), Vector3(ml, 0.035, 0.066),
				0.024 if k == 0 else 0.016, Color(miolo, 1.0), Basis(), 3, 0.012, 3)
	tec.xf = Transform3D.IDENTITY
	var frente := Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
	tec.xf = b
	tec.caixa(Vector3(0, h * 0.5, 0.03), Vector3(meia, 0.05, h * 0.5), 0.035, aba, frente)
	for lugar: float in [-1.0, 1.0]:
		var xc := lugar * meia * 0.48
		for k in 4:
			var yc := lerpf(0.05, h - 0.04, (float(k) + 0.5) / 4.0)
			tec.caixa(Vector3(xc, yc, -0.028), Vector3(meia * 0.40, 0.024,
				(h - 0.09) / 8.0 - 0.002), 0.015, Color(miolo, 1.0), frente, 3, 0.012, 3)
	tec.xf = Transform3D.IDENTITY
	if not cabeca:
		return
	for lugar: float in [-1.0, 1.0]:
		_encosto_de_cabeca(it, b * Transform3D(Basis(),
			Vector3(lugar * meia * 0.48, h + 0.07, 0.015)), minf(meia * 0.26, 0.12), cores)


static func _dobradica_de_tras(piso: float, z_encosto: float, incl: float) -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, deg_to_rad(incl)),
		Vector3(0, piso + TAMPO - 0.07, z_encosto - 0.03))
