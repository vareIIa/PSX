## Interior simples do transito: bancos, painel e volante (PLANO_CARROS_AAA, F1).
##
## Existe porque o vidro do MODERNO deixou de ser opaco. Pela janela aparecia o
## motorista boiando num casco vazio: o tronco do `Corpo` e o forro escuro, sem
## banco em volta e sem painel na frente. Nao e cabine — o carro do jogador tem a
## `CarroCabine` e esconde esta malha quando ela entra.
##
## Tudo e montado JA no espaco final da lataria (-Z frente, motorista em -X), e
## medido contra o mesmo perfil que varreu o casco: um banco medido a olho
## atravessa a cupula do Fusca na altura do apoio de cabeca.
##
## Sem class_name pelo mesmo motivo dos modulos de Fusca e Marea: Carroceria o
## carrega em runtime, e o class_name dos dois lados seria referencia ciclica.
extends RefCounted

## Cores de forro sorteadas pela semente: courvin preto, cinza, caramelo, bege e
## vinho — o que os carros da epoca saiam de fabrica.
const FORROS: Array[Color] = [
	Color(0.16, 0.13, 0.11), Color(0.11, 0.11, 0.12),
	Color(0.24, 0.17, 0.12), Color(0.30, 0.27, 0.23),
	Color(0.20, 0.08, 0.07),
]
const PAINEL := Color(0.085, 0.085, 0.09)
const VOLANTE := Color(0.05, 0.05, 0.05)
## Topo do assento. O `Corpo` do motorista fica 0,36 m afundado (`Carro`), o que
## poe o quadril logo acima daqui e as pernas dentro da almofada.
const ASSENTO_Y := 0.46
## Inclinacao do encosto para tras, em radianos.
const ENCOSTO_GIRO := 0.22
const FOLGA_PAREDE := 0.05
const RAIO_VOLANTE := 0.19


static func montar(modelo: int, comp: float, larg: float, _teto: float,
		semente: int, vidro: Dictionary, info: Dictionary) -> Dictionary:
	var d := PSXMesh.dados_vazios()
	if info.is_empty() or not info.has("perfil"):
		return d
	var forro := Carroceria.marcar(FORROS[absi(semente * 31) % FORROS.size()],
		Carroceria.Classe.FORRO)
	var painel := Carroceria.marcar(PAINEL, Carroceria.Classe.PLASTICO)
	var volante := Carroceria.marcar(VOLANTE, Carroceria.Classe.BORRACHA)

	# Mesmo quadril em que `Carro._montar_motorista` senta o Corpo.
	var quadril_z := -comp * 0.04
	# A largura livre e a MENOR do volume do banco: o Marea afina perto do
	# assoalho e o Fusca perto do teto. Medida so no alto, a almofada saia pela
	# soleira do Marea como uma caixa escura pregada na porta.
	var livre := _meia_minima(info,
		[quadril_z - 0.44, quadril_z - 0.2, quadril_z + 0.2],
		[ASSENTO_Y - 0.12, ASSENTO_Y, ASSENTO_Y + 0.82])
	var x_banco := minf(larg * 0.24, livre - 0.22 - FOLGA_PAREDE)
	for s: float in [-1.0, 1.0]:
		_banco(d, Vector3(s * x_banco, ASSENTO_Y, quadril_z), 0.44, forro, true)
	# Quem senta o motorista le daqui, para o Corpo cair no banco que existe.
	d["banco"] = Vector3(-x_banco, ASSENTO_Y, quadril_z)

	# Banco de tras, se couber: a picape nao tem, e no hatch curto ele so entra
	# se o teto ainda estiver alto 86 cm atras do motorista.
	if modelo != Carroceria.Modelo.PICAPE:
		var zt := quadril_z + 0.86
		if (_topo(info, zt + 0.2) > ASSENTO_Y + 0.72
				and _meia(info, zt, ASSENTO_Y + 0.3) > 0.4):
			var w := (_meia_minima(info, [zt - 0.36, zt, zt + 0.3],
				[ASSENTO_Y - 0.12, ASSENTO_Y + 0.6]) - FOLGA_PAREDE) * 2.0
			_banco(d, Vector3(0.0, ASSENTO_Y, zt), w, forro, false)

	# Painel sob a base do para-brisa e volante entre ele e o motorista.
	if vidro.has("base"):
		var base: Vector2 = vidro["base"]
		var z_volante := minf(base.x + 0.50, quadril_z - 0.18)
		var frente := base.x + 0.01
		var fundo := minf(0.42, z_volante - 0.05 - frente)
		if fundo > 0.12:
			var alto := base.y - 0.03
			var zc := frente + fundo * 0.5
			var w := (_meia_minima(info, [frente, zc, frente + fundo],
				[alto - 0.24, alto]) - 0.03) * 2.0
			_bloco(d, Vector3(w, 0.24, fundo),
				Transform3D(Basis(), Vector3(0.0, alto - 0.12, zc)), painel)
		_volante(d, Vector3(-x_banco, 0.90, z_volante), volante)
	return d


## Assento, encosto e (na frente) apoio de cabeca. `p` e o topo do assento na
## altura do quadril.
static func _banco(d: Dictionary, p: Vector3, largura: float, cor: Color,
		com_cabeca: bool) -> void:
	_bloco(d, Vector3(largura, 0.12, 0.48),
		Transform3D(Basis(), p + Vector3(0.0, -0.06, -0.20)), cor)
	var giro := Basis(Vector3.RIGHT, ENCOSTO_GIRO)
	var pe := p + Vector3(0.0, 0.0, 0.06)
	_bloco(d, Vector3(largura - 0.02, 0.64, 0.11),
		Transform3D(giro, pe + giro * Vector3(0.0, 0.32, 0.055)), cor)
	if com_cabeca:
		_bloco(d, Vector3(0.26, 0.17, 0.09),
			Transform3D(giro, pe + giro * Vector3(0.0, 0.74, 0.055)), cor)


## Aro de doze gomos e uma barra, virado para o motorista e para cima.
static func _volante(d: Dictionary, c: Vector3, cor: Color) -> void:
	var normal := Vector3(0.0, 0.55, 0.83).normalized()
	var u := Vector3.RIGHT
	var v := normal.cross(u).normalized()
	var gomos := 12
	for k in gomos:
		var a0 := TAU * float(k) / float(gomos)
		var a1 := TAU * float(k + 1) / float(gomos)
		var d0 := u * cos(a0) + v * sin(a0)
		var d1 := u * cos(a1) + v * sin(a1)
		var fora0 := c + d0 * RAIO_VOLANTE
		var fora1 := c + d1 * RAIO_VOLANTE
		var dentro0 := c + d0 * (RAIO_VOLANTE - 0.03)
		var dentro1 := c + d1 * (RAIO_VOLANTE - 0.03)
		for lado: Vector3 in [normal, -normal]:
			CarroceriaVarrida.quad(d, fora0, fora1, dentro1, dentro0,
				Carroceria.C_PARACHOQUE, cor, cor, cor, cor, lado)
	_bloco(d, Vector3(RAIO_VOLANTE * 1.9, 0.035, 0.02),
		Transform3D(Basis(u, v, normal), c), cor)


## Caixa de seis faces com qualquer giro.
static func _bloco(d: Dictionary, tam: Vector3, xf: Transform3D, cor: Color) -> void:
	var h := tam * 0.5
	var faces: Array = [
		[Vector2(tam.x, tam.y), Transform3D(Basis(), Vector3(0.0, 0.0, h.z))],
		[Vector2(tam.x, tam.y), Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.0, -h.z))],
		[Vector2(tam.z, tam.y), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(h.x, 0.0, 0.0))],
		[Vector2(tam.z, tam.y), Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-h.x, 0.0, 0.0))],
		[Vector2(tam.x, tam.z), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.0, h.y, 0.0))],
		[Vector2(tam.x, tam.z), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, -h.y, 0.0))],
	]
	for f: Array in faces:
		Carroceria._face(d, f[0], xf * (f[1] as Transform3D), cor, Carroceria.C_PARACHOQUE)


## Meia largura do casco por dentro, num ponto do espaco final.
static func _meia(info: Dictionary, z: float, y: float) -> float:
	var e: Vector3 = info.get("escala", Vector3.ONE)
	return CarroceriaVarrida.x_casco_fino(info["perfil"], info["ombro"],
		-z / e.z, y / e.y) * e.x


static func _meia_minima(info: Dictionary, zs: Array, ys: Array) -> float:
	var m := INF
	for z: float in zs:
		for y: float in ys:
			m = minf(m, _meia(info, z, y))
	return m


## Altura do teto num Z do espaco final.
static func _topo(info: Dictionary, z: float) -> float:
	var e: Vector3 = info.get("escala", Vector3.ONE)
	var est := CarroceriaVarrida.estacao(info["perfil"], -z / e.z)
	return float(est[CarroceriaVarrida.TOPO]) * e.y
