## Mobilia de casa brasileira de periferia, anos 2000, para a casa da fumaca.
##
## Por que um kit proprio e nao o atlas da casa
## ---------------------------------------------
## A sala antiga era feita de caixas do `casa_atlas`: um sofa eram quatro caixas
## com a MESMA celula de 32 px esticada em cada face, e a captura do MODERNO
## mostrava isso — blocos lisos, sem costura, sem almofada, sem peso. O movel
## le como movel pelo que ele tem de separado: a almofada que nao encosta na
## outra, o braco mais alto que o assento, o pe que tira o sofa do chao e deixa
## uma faixa de sombra por baixo. Aqui cada peca e montada com essas partes, e o
## material e PBR de verdade (courino, tecido, MDF, plastico — ambientCG CC0 via
## tools/baixar_texturas.py), com a cor posta por vertice.
##
## Convencao: toda peca recebe `base` (o ponto no CHAO, no meio da peca) e `giro`
## em Y; a FRENTE da peca e +Z local. Colisao so para o que o jogador pode
## esbarrar — nada de caixa invisivel em volta de controle e caneca.
class_name KitMovel
extends RefCounted

const COURINO: StringName = &"fumaca_courino"
const TECIDO: StringName = &"fumaca_tecido"
const TAPETE: StringName = &"fumaca_tapete"
const AZULEJO: StringName = &"fumaca_azulejo"
const MDF: StringName = &"fumaca_mdf"
const PLASTICO: StringName = &"fumaca_plastico"
const CAPAS: StringName = &"fumaca_capas"
const LUZ: StringName = &"fumaca_luz"
const METAL: StringName = &"metal"
const PEDRA: StringName = &"concreto"

const PRETO := Color(0.09, 0.09, 0.10)
const MDF_ESCURO := Color(0.42, 0.32, 0.26)
## Formica branca. A cor por vertice e de 8 bits e corta em 1: o branco sai do
## albedo cinza claro do plastico, e nao de tinta acima de um.
const BRANCO := Color(1.0, 1.0, 0.97)
const GRANITO := Color(0.22, 0.20, 0.19)
const INOX := Color(0.78, 0.80, 0.82)


# --- base -------------------------------------------------------------------

## Caixa com base livre, na moldura da peca. `p` e local; `r` gira a propria
## caixa (inclinar encosto, deitar caixinha).
static func cx(sup: Dictionary, mat: StringName, base: Vector3, b: Basis,
		p: Vector3, tam: Vector3, cor: Color, r: Basis = Basis()) -> void:
	KitModular.caixa_livre(sup, mat, base + b * p, tam, b * r, cor, 4.0)


## Placa com um pedaco do atlas de capas. `xf` e a transformada final; a placa
## olha para +Z dela.
static func capa(sup: Dictionary, xf: Transform3D, tam: Vector2, r: Rect2,
		cor: Color = Color.WHITE) -> void:
	var d := PSXMesh.placa_dados(tam, 100.0, cor)
	var uvs: PackedVector2Array = d["uv"]
	for k in uvs.size():
		uvs[k] = r.position + uvs[k] * r.size
	d["uv"] = uvs
	if not sup.has(CAPAS):
		sup[CAPAS] = PSXMesh.dados_vazios()
	PSXMesh.acumular(sup[CAPAS], d, xf)


static func _solido(colisao: Array[Dictionary], base: Vector3, giro: float,
		tam: Vector3, dy: float = 0.0) -> void:
	KitModular.solido(colisao, base + Vector3(0.0, tam.y * 0.5 + dy, 0.0), tam, giro)


# --- sala -------------------------------------------------------------------

## Sofa de courino de tres lugares. Base escura recuada (o sofa "flutua" sobre
## a propria sombra), estrutura, tres almofadas de assento com fresta, tres de
## encosto inclinadas, bracos largos com o topo arredondado por uma segunda
## caixa. A almofada do meio e a mais afundada: e onde sempre senta alguem.
static func sofa(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float, cor: Color, comp: float = 2.15, lugares: int = 3) -> void:
	var b := Basis(Vector3.UP, giro)
	var fundo := 0.92
	var escuro := cor * Color(0.55, 0.55, 0.55)
	cx(sup, MDF, base, b, Vector3(0.0, 0.05, -0.02), Vector3(comp - 0.16, 0.10, fundo - 0.14), PRETO)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			cx(sup, MDF, base, b, Vector3(sx * (comp * 0.5 - 0.12), 0.04, sz * (fundo * 0.5 - 0.12)),
				Vector3(0.06, 0.08, 0.06), MDF_ESCURO)
	cx(sup, COURINO, base, b, Vector3(0.0, 0.21, 0.0), Vector3(comp, 0.22, fundo), escuro)
	var braco := 0.19
	var util := comp - braco * 2.0
	var largura := util / float(lugares)
	for k in lugares:
		var x := -util * 0.5 + largura * (float(k) + 0.5)
		var afunda := 0.035 if k == lugares / 2 else 0.0
		cx(sup, COURINO, base, b, Vector3(x, 0.395 - afunda * 0.5, 0.07),
			Vector3(largura - 0.025, 0.15 - afunda, fundo - 0.26), cor)
		cx(sup, COURINO, base, b, Vector3(x, 0.66, -fundo * 0.5 + 0.21),
			Vector3(largura - 0.03, 0.42, 0.17), cor, Basis(Vector3.RIGHT, -0.17))
	cx(sup, COURINO, base, b, Vector3(0.0, 0.56, -fundo * 0.5 + 0.09),
		Vector3(comp, 0.50, 0.18), escuro)
	for sx: float in [-1.0, 1.0]:
		var x := sx * (comp * 0.5 - braco * 0.5)
		cx(sup, COURINO, base, b, Vector3(x, 0.40, 0.0), Vector3(braco, 0.40, fundo), escuro)
		cx(sup, COURINO, base, b, Vector3(x, 0.625, 0.01), Vector3(braco + 0.03, 0.07, fundo + 0.01), cor)
	_solido(colisao, base, giro, Vector3(comp, 0.85, fundo))


## A manta jogada por cima do encosto e caida no assento: um tecido que nao e
## caixa de sofa quebra a silhueta, e a cor dela e a unica estampa da sala.
static func manta(sup: Dictionary, base: Vector3, giro: float, x: float,
		cor: Color) -> void:
	var b := Basis(Vector3.UP, giro)
	cx(sup, TECIDO, base, b, Vector3(x, 0.82, -0.36), Vector3(0.62, 0.02, 0.30), cor,
		Basis(Vector3.RIGHT, 0.35))
	cx(sup, TECIDO, base, b, Vector3(x, 0.63, -0.25), Vector3(0.62, 0.36, 0.02), cor,
		Basis(Vector3.RIGHT, -0.17))
	cx(sup, TECIDO, base, b, Vector3(x + 0.05, 0.475, 0.02), Vector3(0.58, 0.02, 0.48), cor,
		Basis(Vector3.UP, 0.12))


static func poltrona(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float, cor: Color) -> void:
	var b := Basis(Vector3.UP, giro)
	var escuro := cor * Color(0.6, 0.6, 0.6)
	cx(sup, MDF, base, b, Vector3(0.0, 0.05, 0.0), Vector3(0.66, 0.10, 0.70), PRETO)
	cx(sup, TECIDO, base, b, Vector3(0.0, 0.22, 0.0), Vector3(0.86, 0.24, 0.86), escuro)
	cx(sup, TECIDO, base, b, Vector3(0.0, 0.40, 0.06), Vector3(0.54, 0.14, 0.66), cor)
	cx(sup, TECIDO, base, b, Vector3(0.0, 0.64, -0.33), Vector3(0.62, 0.56, 0.20), cor,
		Basis(Vector3.RIGHT, -0.15))
	for sx: float in [-1.0, 1.0]:
		cx(sup, TECIDO, base, b, Vector3(sx * 0.35, 0.44, 0.0), Vector3(0.16, 0.44, 0.86), escuro)
	_solido(colisao, base, giro, Vector3(0.9, 0.85, 0.9))


## Pufe redondo de courino: prisma de oito lados, em duas caixas giradas.
static func pufe(sup: Dictionary, base: Vector3, cor: Color) -> void:
	for k in 2:
		cx(sup, COURINO, base, Basis(Vector3.UP, PI * 0.25 * k),
			Vector3(0.0, 0.21, 0.0), Vector3(0.46, 0.42, 0.46), cor)


static func tapete(sup: Dictionary, centro: Vector3, tam: Vector2, giro: float,
		cor: Color) -> void:
	cx(sup, TAPETE, centro, Basis(Vector3.UP, giro), Vector3(0.0, 0.006, 0.0),
		Vector3(tam.x, 0.012, tam.y), cor)


## Mesa de centro de madeira escura com prateleira de baixo.
static func mesa_centro(sup: Dictionary, colisao: Array[Dictionary],
		base: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	cx(sup, MDF, base, b, Vector3(0.0, 0.415, 0.0), Vector3(1.10, 0.04, 0.60), MDF_ESCURO)
	cx(sup, MDF, base, b, Vector3(0.0, 0.13, 0.0), Vector3(1.0, 0.025, 0.50), MDF_ESCURO * 0.8)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			cx(sup, MDF, base, b, Vector3(sx * 0.50, 0.20, sz * 0.25),
				Vector3(0.05, 0.40, 0.05), MDF_ESCURO * 0.7)
	_solido(colisao, base, giro, Vector3(1.1, 0.44, 0.6))


## Rack de MDF preto com porta de vidro fume de um lado e nicho aberto do outro.
static func rack(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float, larg: float = 1.9) -> void:
	var b := Basis(Vector3.UP, giro)
	var fundo := 0.46
	var cor := Color(0.16, 0.15, 0.15)
	cx(sup, MDF, base, b, Vector3(0.0, 0.53, 0.0), Vector3(larg, 0.035, fundo), cor)
	cx(sup, MDF, base, b, Vector3(0.0, 0.075, 0.0), Vector3(larg, 0.03, fundo), cor)
	cx(sup, MDF, base, b, Vector3(0.0, 0.30, 0.0), Vector3(larg - 0.04, 0.02, fundo - 0.04), cor)
	cx(sup, MDF, base, b, Vector3(0.0, 0.30, -fundo * 0.5 + 0.01), Vector3(larg, 0.46, 0.02), cor * 0.7)
	for sx: float in [-1.0, 0.0, 1.0]:
		cx(sup, MDF, base, b, Vector3(sx * (larg * 0.5 - 0.015), 0.30, 0.0),
			Vector3(0.03, 0.46, fundo), cor)
	for sx: float in [-1.0, 1.0]:
		cx(sup, MDF, base, b, Vector3(sx * (larg * 0.5 - 0.08), 0.03, 0.0),
			Vector3(0.06, 0.06, fundo - 0.1), PRETO)
	# O vidro fume, com um puxador de metal.
	cx(sup, PLASTICO, base, b, Vector3(-larg * 0.25, 0.30, fundo * 0.5 - 0.01),
		Vector3(larg * 0.5 - 0.05, 0.42, 0.01), Color(0.10, 0.10, 0.12))
	cx(sup, METAL, base, b, Vector3(-0.06, 0.30, fundo * 0.5 + 0.005),
		Vector3(0.015, 0.12, 0.015), INOX)
	# DVD e videocassete no nicho aberto.
	cx(sup, PLASTICO, base, b, Vector3(larg * 0.25, 0.14, 0.02), Vector3(0.43, 0.07, 0.30), PRETO)
	cx(sup, PLASTICO, base, b, Vector3(larg * 0.25, 0.345, 0.02), Vector3(0.40, 0.055, 0.28), Color(0.20, 0.20, 0.21))
	cx(sup, LUZ, base, b, Vector3(larg * 0.25 + 0.13, 0.35, 0.162), Vector3(0.05, 0.012, 0.004), Color(0.2, 1.0, 0.4))
	_solido(colisao, base, giro, Vector3(larg, 0.56, fundo))


## TV de tubo de 29": moldura preta em quatro caixas em volta da tela (a tela e o
## prop `televisao`), faixa do alto-falante embaixo, o tubo fundo atras e o
## sino ainda mais atras. `tela` e o centro da imagem, na frente dela.
static func tv_tubo(sup: Dictionary, colisao: Array[Dictionary], tela: Vector3,
		giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var t := Televisao.TELA
	var borda := 0.075
	var cor := Color(0.07, 0.07, 0.08)
	var z := -0.03
	cx(sup, PLASTICO, tela, b, Vector3(0.0, t.y * 0.5 + borda * 0.5, z), Vector3(t.x + borda * 2.0, borda, 0.07), cor)
	cx(sup, PLASTICO, tela, b, Vector3(0.0, -t.y * 0.5 - 0.07, z), Vector3(t.x + borda * 2.0, 0.14, 0.07), cor)
	for sx: float in [-1.0, 1.0]:
		cx(sup, PLASTICO, tela, b, Vector3(sx * (t.x * 0.5 + borda * 0.5), 0.0, z),
			Vector3(borda, t.y, 0.07), cor)
	# O vao preto logo atras do vidro.
	cx(sup, PLASTICO, tela, b, Vector3(0.0, 0.0, -0.07), Vector3(t.x + 0.02, t.y + 0.02, 0.02), PRETO * 0.3)
	# Grade do alto-falante e o LED de ligado.
	cx(sup, PLASTICO, tela, b, Vector3(0.0, -t.y * 0.5 - 0.08, 0.006), Vector3(t.x * 0.8, 0.06, 0.005), Color(0.13, 0.13, 0.14))
	cx(sup, LUZ, tela, b, Vector3(t.x * 0.5 + 0.02, -t.y * 0.5 - 0.10, 0.007), Vector3(0.012, 0.012, 0.004), Color(1.0, 0.15, 0.1))
	# Tubo e sino.
	cx(sup, PLASTICO, tela, b, Vector3(0.0, -0.02, -0.28), Vector3(t.x + 0.10, t.y + 0.14, 0.44), cor * 1.2)
	cx(sup, PLASTICO, tela, b, Vector3(0.0, -0.01, -0.58), Vector3(0.44, 0.36, 0.18), cor * 1.2)
	KitModular.solido(colisao, tela + b * Vector3(0.0, -0.04, -0.3), Vector3(t.x + 0.2, t.y + 0.3, 0.7), giro)


## Caixa de som torre, de MDF preto, com dois alto-falantes e tweeter.
static func caixa_torre(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	cx(sup, MDF, base, b, Vector3(0.0, 0.48, 0.0), Vector3(0.28, 0.96, 0.30), Color(0.12, 0.11, 0.11))
	for y: float in [0.30, 0.60]:
		cx(sup, PLASTICO, base, b, Vector3(0.0, y, 0.152), Vector3(0.19, 0.19, 0.01), PRETO)
		cx(sup, PLASTICO, base, b, Vector3(0.0, y, 0.158), Vector3(0.07, 0.07, 0.01), Color(0.2, 0.2, 0.21))
	cx(sup, PLASTICO, base, b, Vector3(0.0, 0.84, 0.152), Vector3(0.07, 0.07, 0.01), Color(0.25, 0.25, 0.26))
	_solido(colisao, base, giro, Vector3(0.3, 0.96, 0.32))


## Estante de CD: seis prateleiras e lombadas de cor sortida, com vaos. Uma
## estante cheia de caixinha iguais le como textura; com cor e falha, le como
## colecao de alguem.
static func estante_cds(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float, rng: RandomNumberGenerator) -> void:
	var b := Basis(Vector3.UP, giro)
	var larg := 0.86
	var alto := 1.86
	var fundo := 0.20
	var cor := MDF_ESCURO * 0.7
	for sx: float in [-1.0, 1.0]:
		cx(sup, MDF, base, b, Vector3(sx * (larg * 0.5 - 0.01), alto * 0.5, 0.0), Vector3(0.02, alto, fundo), cor)
	cx(sup, MDF, base, b, Vector3(0.0, alto * 0.5, -fundo * 0.5 + 0.005), Vector3(larg, alto, 0.01), cor * 0.6)
	var n := 6
	for k in n + 1:
		var y := 0.04 + (alto - 0.06) * float(k) / float(n)
		cx(sup, MDF, base, b, Vector3(0.0, y, 0.0), Vector3(larg - 0.02, 0.02, fundo), cor)
		if k == n:
			break
		var x := -larg * 0.5 + 0.03
		while x < larg * 0.5 - 0.04:
			if rng.randf() < 0.07:
				x += 0.05
				continue
			var lombada := Color.from_hsv(rng.randf(), rng.randf_range(0.2, 0.8),
				rng.randf_range(0.25, 0.9))
			cx(sup, PLASTICO, base, b, Vector3(x + 0.006, y + 0.075, 0.02),
				Vector3(0.011, 0.125, 0.142), lombada)
			x += 0.0125
	_solido(colisao, base, giro, Vector3(larg, alto, fundo + 0.04))


## Micro system 3 em 1 em cima de um movel baixo, com o toca-discos ao lado.
static func som(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	cx(sup, MDF, base, b, Vector3(0.0, 0.33, 0.0), Vector3(1.3, 0.66, 0.44), MDF_ESCURO * 0.6)
	cx(sup, MDF, base, b, Vector3(0.0, 0.33, 0.221), Vector3(1.22, 0.58, 0.01), MDF_ESCURO * 0.4)
	# O aparelho: corpo prata, visor aceso e a gaveta de CD.
	cx(sup, PLASTICO, base, b, Vector3(-0.30, 0.80, 0.0), Vector3(0.30, 0.28, 0.32), Color(0.55, 0.56, 0.58))
	cx(sup, LUZ, base, b, Vector3(-0.30, 0.86, 0.162), Vector3(0.20, 0.045, 0.004), Color(0.25, 0.85, 1.0))
	cx(sup, PLASTICO, base, b, Vector3(-0.30, 0.74, 0.162), Vector3(0.24, 0.02, 0.004), PRETO)
	# O toca-discos: base, prato com disco e o braco.
	cx(sup, MDF, base, b, Vector3(0.30, 0.71, 0.0), Vector3(0.46, 0.10, 0.36), Color(0.14, 0.13, 0.13))
	cx(sup, PLASTICO, base, b, Vector3(0.26, 0.77, 0.0), Vector3(0.30, 0.012, 0.30), PRETO, Basis(Vector3.UP, 0.4))
	cx(sup, PLASTICO, base, b, Vector3(0.26, 0.777, 0.0), Vector3(0.10, 0.004, 0.10), Color(0.8, 0.2, 0.15), Basis(Vector3.UP, 0.4))
	cx(sup, METAL, base, b, Vector3(0.46, 0.79, -0.04), Vector3(0.012, 0.012, 0.24), INOX, Basis(Vector3.UP, -0.35))
	_solido(colisao, base, giro, Vector3(1.3, 0.9, 0.46))


## Caixote de feira cheio de LP, com o primeiro de capa para fora.
static func caixote_lp(sup: Dictionary, base: Vector3, giro: float, disco: int,
		rng: RandomNumberGenerator) -> void:
	var b := Basis(Vector3.UP, giro)
	var tabua := Color(0.78, 0.62, 0.44)
	for sz: float in [-1.0, 1.0]:
		cx(sup, &"tabua", base, b, Vector3(0.0, 0.17, sz * 0.19), Vector3(0.40, 0.30, 0.02), tabua)
	for sx: float in [-1.0, 1.0]:
		cx(sup, &"tabua", base, b, Vector3(sx * 0.19, 0.17, 0.0), Vector3(0.02, 0.30, 0.36), tabua * 0.9)
	cx(sup, &"tabua", base, b, Vector3(0.0, 0.02, 0.0), Vector3(0.40, 0.02, 0.40), tabua * 0.8)
	for k in 9:
		var z := -0.14 + k * 0.03
		cx(sup, PLASTICO, base, b, Vector3(0.0, 0.18, z), Vector3(0.31, 0.31, 0.004),
			Color.from_hsv(rng.randf(), 0.3, rng.randf_range(0.1, 0.5)), Basis(Vector3.RIGHT, -0.12))
	var xf := Transform3D(b * Basis(Vector3.RIGHT, -0.18), base + b * Vector3(0.0, 0.22, 0.13))
	capa(sup, xf, Vector2(0.31, 0.31), CapasAtlas.disco(disco))


## Capa de disco emoldurada, pendurada numa parede. `centro` na face da parede,
## `giro` para onde a parede olha.
static func quadro(sup: Dictionary, centro: Vector3, giro: float, lado: float,
		disco: int, torto: float = 0.0) -> void:
	var b := Basis(Vector3.UP, giro) * Basis(Vector3.BACK, torto)
	cx(sup, MDF, centro, b, Vector3(0.0, 0.0, 0.014), Vector3(lado + 0.07, lado + 0.07, 0.026), PRETO)
	capa(sup, Transform3D(b, centro + b * Vector3(0.0, 0.0, 0.029)), Vector2(lado, lado),
		CapasAtlas.disco(disco))


## Capa de disco colada na parede sem moldura, com quatro pedacos de fita.
static func cartaz(sup: Dictionary, centro: Vector3, giro: float, lado: float,
		disco: int, torto: float = 0.0) -> void:
	var b := Basis(Vector3.UP, giro) * Basis(Vector3.BACK, torto)
	capa(sup, Transform3D(b, centro + b * Vector3(0.0, 0.0, 0.006)), Vector2(lado, lado),
		CapasAtlas.disco(disco), Color(0.92, 0.92, 0.9))
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			cx(sup, PLASTICO, centro, b, Vector3(sx * lado * 0.46, sy * lado * 0.47, 0.009),
				Vector3(0.07, 0.025, 0.002), Color(0.95, 0.88, 0.62), Basis(Vector3.BACK, sx * sy * 0.6))


## Caixinha de jogo de PS2: corpo de plastico preto e o encarte na frente.
## `xf` poe o centro da caixinha; a capa olha para +Z dele.
static func caixinha_ps2(sup: Dictionary, xf: Transform3D, jogo: int) -> void:
	var tam := Vector3(0.135, 0.19, 0.014)
	if not sup.has(PLASTICO):
		sup[PLASTICO] = PSXMesh.dados_vazios()
	var pirata := jogo >= CapasAtlas.PRIMEIRO_PIRATA
	var corpo := Color(0.85, 0.86, 0.9) if pirata else Color(0.05, 0.05, 0.06)
	PSXMesh.acumular_tingido(sup[PLASTICO], PSXMesh.box_dados(tam, 4.0, 4.0), xf, corpo)
	capa(sup, xf * Transform3D(Basis(), Vector3(0.0, 0.0, tam.z * 0.5 + 0.001)),
		Vector2(tam.x - 0.006, tam.y - 0.004), CapasAtlas.jogo(jogo))


## Pilha de caixinhas deitadas, cada uma um pouco girada.
static func pilha_ps2(sup: Dictionary, base: Vector3, giro: float, jogos: Array,
		rng: RandomNumberGenerator) -> void:
	var y := 0.0
	for j: Variant in jogos:
		var b := Basis(Vector3.UP, giro + rng.randf_range(-0.25, 0.25)) \
			* Basis(Vector3.RIGHT, -PI * 0.5)
		caixinha_ps2(sup, Transform3D(b, base + Vector3(rng.randf_range(-0.01, 0.01),
			y + 0.007, rng.randf_range(-0.01, 0.01))), int(j))
		y += 0.0145


## Luminaria de chao: pe de metal, haste e cupula de tecido. A lampada e o prop
## `lampada` no centro da cupula; aqui fica o disco aceso por baixo dela, que e
## o que o olho procura quando pergunta de onde vem a luz.
static func luminaria_chao(sup: Dictionary, base: Vector3, cor_cupula: Color) -> Vector3:
	var b := Basis()
	cx(sup, METAL, base, b, Vector3(0.0, 0.015, 0.0), Vector3(0.28, 0.03, 0.28), PRETO)
	cx(sup, METAL, base, b, Vector3(0.0, 0.78, 0.0), Vector3(0.025, 1.52, 0.025), PRETO)
	# A cupula e tecido com a lampada acesa DENTRO: ela brilha, e brilha mais
	# que a parede atras. Cupula apagada com luz saindo de baixo le como abajur
	# desligado ao lado de um holofote.
	for k in 2:
		cx(sup, LUZ, base, Basis(Vector3.UP, PI * 0.25 * k), Vector3(0.0, 1.62, 0.0),
			Vector3(0.36, 0.28, 0.36), cor_cupula * Color(0.22, 0.14, 0.07))
	cx(sup, LUZ, base, b, Vector3(0.0, 1.475, 0.0), Vector3(0.30, 0.004, 0.30), Color(1.0, 0.72, 0.42))
	return base + Vector3(0.0, 1.58, 0.0)


## Abajur de mesa: base de ceramica e cupula. Devolve o centro da cupula.
static func abajur(sup: Dictionary, base: Vector3, cor: Color) -> Vector3:
	var b := Basis()
	cx(sup, PLASTICO, base, b, Vector3(0.0, 0.10, 0.0), Vector3(0.12, 0.20, 0.12), Color(0.85, 0.82, 0.75))
	for k in 2:
		cx(sup, LUZ, base, Basis(Vector3.UP, PI * 0.25 * k), Vector3(0.0, 0.30, 0.0),
			Vector3(0.26, 0.20, 0.26), cor * Color(0.22, 0.14, 0.07))
	cx(sup, LUZ, base, b, Vector3(0.0, 0.198, 0.0), Vector3(0.22, 0.004, 0.22), Color(1.0, 0.7, 0.4))
	return base + Vector3(0.0, 0.28, 0.0)


## Lampada pendurada no fio, sem luminaria: a do corredor de casa alugada.
static func bocal(sup: Dictionary, teto: Vector3, fio: float, cor: Color) -> Vector3:
	cx(sup, PLASTICO, teto, Basis(), Vector3(0.0, -fio * 0.5, 0.0), Vector3(0.008, fio, 0.008), PRETO)
	cx(sup, PLASTICO, teto, Basis(), Vector3(0.0, -fio - 0.03, 0.0), Vector3(0.035, 0.05, 0.035), Color(0.2, 0.2, 0.2))
	cx(sup, LUZ, teto, Basis(), Vector3(0.0, -fio - 0.09, 0.0), Vector3(0.06, 0.08, 0.06), cor)
	return teto + Vector3(0.0, -fio - 0.09, 0.0)


## Pendente de metal sobre o balcao.
static func pendente(sup: Dictionary, teto: Vector3, fio: float, cor: Color) -> Vector3:
	cx(sup, METAL, teto, Basis(), Vector3(0.0, -fio * 0.5, 0.0), Vector3(0.008, fio, 0.008), PRETO)
	for k in 2:
		cx(sup, METAL, teto, Basis(Vector3.UP, PI * 0.25 * k), Vector3(0.0, -fio - 0.08, 0.0),
			Vector3(0.26, 0.16, 0.26), cor)
	cx(sup, LUZ, teto, Basis(), Vector3(0.0, -fio - 0.158, 0.0), Vector3(0.20, 0.004, 0.20), Color(1.0, 0.75, 0.45))
	return teto + Vector3(0.0, -fio - 0.12, 0.0)


## Calha de lampada fluorescente no teto: a luz fria de cozinha de casa
## brasileira, que ninguem troca por outra.
static func calha(sup: Dictionary, teto: Vector3, giro: float) -> Vector3:
	var b := Basis(Vector3.UP, giro)
	cx(sup, METAL, teto, b, Vector3(0.0, -0.025, 0.0), Vector3(1.26, 0.05, 0.13), Color(0.9, 0.9, 0.88))
	cx(sup, LUZ, teto, b, Vector3(0.0, -0.07, 0.0), Vector3(1.20, 0.032, 0.032), Color(0.92, 0.97, 1.0))
	return teto + Vector3(0.0, -0.12, 0.0)


## Cortina fechada numa janela: pregas alternadas e o varao. A luz de rua que
## vaza pela beira de cima e a unica prova de que ha janela atras.
static func cortina(sup: Dictionary, centro: Vector3, giro: float, larg: float,
		alto: float, cor: Color) -> void:
	var b := Basis(Vector3.UP, giro)
	var n := int(larg / 0.11)
	for k in n:
		var x := -larg * 0.5 + (float(k) + 0.5) * larg / float(n)
		cx(sup, TECIDO, centro, b, Vector3(x, 0.0, 0.06 + (k % 2) * 0.035),
			Vector3(larg / float(n) + 0.02, alto, 0.02), cor * (0.9 + (k % 2) * 0.12))
	cx(sup, METAL, centro, b, Vector3(0.0, alto * 0.5 + 0.05, 0.07), Vector3(larg + 0.3, 0.025, 0.025), PRETO)
	cx(sup, LUZ, centro, b, Vector3(0.0, alto * 0.5 + 0.015, 0.02), Vector3(larg - 0.1, 0.012, 0.01), Color(1.0, 0.55, 0.2) * 0.6)


# --- cozinha ----------------------------------------------------------------

## Armario de pia com bancada de granito, cuba de inox e o aereo em cima.
static func pia_cozinha(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float, comp: float) -> void:
	var b := Basis(Vector3.UP, giro)
	cx(sup, PLASTICO, base, b, Vector3(0.0, 0.43, -0.01), Vector3(comp, 0.78, 0.56), BRANCO * 0.92)
	cx(sup, MDF, base, b, Vector3(0.0, 0.03, 0.02), Vector3(comp - 0.04, 0.06, 0.52), PRETO)
	var portas := maxi(2, int(comp / 0.45))
	for k in portas:
		var x := -comp * 0.5 + (float(k) + 0.5) * comp / float(portas)
		cx(sup, PLASTICO, base, b, Vector3(x, 0.44, 0.275), Vector3(comp / float(portas) - 0.012, 0.66, 0.012), BRANCO)
		cx(sup, METAL, base, b, Vector3(x + 0.12 * (1 if k % 2 == 0 else -1), 0.70, 0.29), Vector3(0.012, 0.09, 0.015), INOX)
	cx(sup, PEDRA, base, b, Vector3(0.0, 0.84, 0.0), Vector3(comp + 0.04, 0.035, 0.62), GRANITO)
	cx(sup, METAL, base, b, Vector3(-comp * 0.22, 0.86, 0.02), Vector3(0.52, 0.012, 0.38), INOX * 0.7)
	cx(sup, METAL, base, b, Vector3(-comp * 0.22, 0.97, -0.25), Vector3(0.03, 0.22, 0.03), INOX)
	cx(sup, METAL, base, b, Vector3(-comp * 0.22, 1.07, -0.17), Vector3(0.025, 0.025, 0.18), INOX)
	# Aereo.
	cx(sup, PLASTICO, base, b, Vector3(0.0, 1.85, -0.12), Vector3(comp, 0.62, 0.34), BRANCO * 0.92)
	for k in portas:
		var x := -comp * 0.5 + (float(k) + 0.5) * comp / float(portas)
		cx(sup, PLASTICO, base, b, Vector3(x, 1.85, 0.055), Vector3(comp / float(portas) - 0.012, 0.58, 0.012), BRANCO)
	_solido(colisao, base, giro, Vector3(comp + 0.04, 0.88, 0.62))


## Geladeira velha de duas portas, com adesivo e ima de pizzaria.
static func geladeira(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float, rng: RandomNumberGenerator) -> void:
	var b := Basis(Vector3.UP, giro)
	var branco := Color(1.0, 0.99, 0.95)
	cx(sup, PLASTICO, base, b, Vector3(0.0, 0.90, -0.02), Vector3(0.70, 1.76, 0.66), branco * 0.95)
	cx(sup, PLASTICO, base, b, Vector3(0.0, 1.47, 0.32), Vector3(0.69, 0.52, 0.04), branco)
	cx(sup, PLASTICO, base, b, Vector3(0.0, 0.60, 0.32), Vector3(0.69, 1.12, 0.04), branco)
	for y: float in [1.30, 0.95]:
		cx(sup, PLASTICO, base, b, Vector3(-0.28, y, 0.35), Vector3(0.03, 0.22, 0.03), Color(0.7, 0.7, 0.7))
	for k in 7:
		var cor := Color.from_hsv(rng.randf(), 0.7, rng.randf_range(0.5, 1.0))
		cx(sup, PLASTICO, base, b, Vector3(rng.randf_range(-0.22, 0.25),
			rng.randf_range(0.7, 1.6), 0.343), Vector3(rng.randf_range(0.05, 0.11),
			rng.randf_range(0.04, 0.09), 0.004), cor, Basis(Vector3.BACK, rng.randf_range(-0.3, 0.3)))
	_solido(colisao, base, giro, Vector3(0.72, 1.78, 0.72))


## Filtro de barro de duas velas: o objeto mais brasileiro de uma cozinha.
static func filtro_de_barro(sup: Dictionary, base: Vector3) -> void:
	var barro := Color(0.78, 0.46, 0.30)
	for k in 2:
		var giro := Basis(Vector3.UP, PI * 0.25 * k)
		cx(sup, &"tijolo", base, giro, Vector3(0.0, 0.14, 0.0), Vector3(0.22, 0.26, 0.22), barro)
		cx(sup, &"tijolo", base, giro, Vector3(0.0, 0.40, 0.0), Vector3(0.20, 0.24, 0.20), barro * 1.05)
	cx(sup, &"tijolo", base, Basis(), Vector3(0.0, 0.54, 0.0), Vector3(0.13, 0.04, 0.13), barro * 0.9)
	cx(sup, METAL, base, Basis(), Vector3(0.0, 0.08, 0.13), Vector3(0.02, 0.02, 0.05), INOX)


## Galao de agua de vinte litros no chao, azul.
static func galao(sup: Dictionary, base: Vector3) -> void:
	for k in 2:
		cx(sup, PLASTICO, base, Basis(Vector3.UP, PI * 0.25 * k), Vector3(0.0, 0.22, 0.0),
			Vector3(0.26, 0.40, 0.26), Color(0.35, 0.60, 0.95))
	cx(sup, PLASTICO, base, Basis(), Vector3(0.0, 0.46, 0.0), Vector3(0.07, 0.08, 0.07), Color(0.25, 0.45, 0.85))


## Mesa de cozinha com toalha xadrez.
static func mesa_cozinha(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float, toalha: Color) -> void:
	var b := Basis(Vector3.UP, giro)
	cx(sup, MDF, base, b, Vector3(0.0, 0.74, 0.0), Vector3(1.20, 0.03, 0.80), MDF_ESCURO)
	cx(sup, TECIDO, base, b, Vector3(0.0, 0.757, 0.0), Vector3(1.26, 0.006, 0.86), toalha)
	for sx: float in [-1.0, 1.0]:
		cx(sup, TECIDO, base, b, Vector3(sx * 0.63, 0.66, 0.0), Vector3(0.006, 0.20, 0.86), toalha * 0.9)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			cx(sup, METAL, base, b, Vector3(sx * 0.54, 0.37, sz * 0.34), Vector3(0.04, 0.74, 0.04), PRETO)
	_solido(colisao, base, giro, Vector3(1.26, 0.77, 0.86))


## Balcao da cozinha americana: base revestida de azulejo, tampo de granito.
static func balcao(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float, comp: float) -> void:
	var b := Basis(Vector3.UP, giro)
	cx(sup, AZULEJO, base, b, Vector3(0.0, 0.52, 0.0), Vector3(comp, 1.04, 0.14), Color(1.0, 1.0, 1.0))
	cx(sup, PEDRA, base, b, Vector3(0.0, 1.06, 0.06), Vector3(comp + 0.06, 0.04, 0.46), GRANITO)
	_solido(colisao, base, giro, Vector3(comp, 1.08, 0.3))


# --- quarto e estudio ---------------------------------------------------------

static func colchao(sup: Dictionary, base: Vector3, giro: float, lencol: Color) -> void:
	var b := Basis(Vector3.UP, giro)
	cx(sup, TECIDO, base, b, Vector3(0.0, 0.09, 0.0), Vector3(0.88, 0.18, 1.88), Color(0.8, 0.8, 0.75))
	cx(sup, TECIDO, base, b, Vector3(0.02, 0.185, 0.15), Vector3(0.92, 0.02, 1.4), lencol, Basis(Vector3.UP, 0.04))
	cx(sup, TECIDO, base, b, Vector3(0.0, 0.23, -0.72), Vector3(0.62, 0.10, 0.34), Color(0.9, 0.9, 0.88), Basis(Vector3.UP, -0.1))


## Escrivaninha com monitor de tubo bege, teclado, a MPC e o microfone.
static func estudio(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float) -> Vector3:
	var b := Basis(Vector3.UP, giro)
	cx(sup, MDF, base, b, Vector3(0.0, 0.74, 0.0), Vector3(1.40, 0.03, 0.62), MDF_ESCURO * 0.6)
	for sx: float in [-1.0, 1.0]:
		cx(sup, MDF, base, b, Vector3(sx * 0.68, 0.37, 0.0), Vector3(0.03, 0.74, 0.58), MDF_ESCURO * 0.5)
	var bege := Color(0.80, 0.77, 0.68)
	cx(sup, PLASTICO, base, b, Vector3(-0.15, 0.97, -0.08), Vector3(0.40, 0.34, 0.08), bege)
	cx(sup, PLASTICO, base, b, Vector3(-0.15, 0.96, -0.22), Vector3(0.34, 0.28, 0.24), bege * 0.95)
	cx(sup, PLASTICO, base, b, Vector3(-0.15, 0.78, -0.12), Vector3(0.18, 0.04, 0.16), bege * 0.9)
	cx(sup, LUZ, base, b, Vector3(-0.15, 0.98, -0.037), Vector3(0.32, 0.24, 0.004), Color(0.30, 0.50, 0.95) * 0.08)
	cx(sup, PLASTICO, base, b, Vector3(-0.15, 0.765, 0.12), Vector3(0.44, 0.02, 0.15), bege)
	# MPC: corpo cinza e dezesseis pads.
	cx(sup, PLASTICO, base, b, Vector3(0.42, 0.775, 0.02), Vector3(0.34, 0.04, 0.30), Color(0.35, 0.35, 0.37))
	for i in 4:
		for j in 4:
			cx(sup, PLASTICO, base, b, Vector3(0.36 + i * 0.045, 0.80, -0.04 + j * 0.045),
				Vector3(0.036, 0.01, 0.036), Color(0.75, 0.2, 0.2) if (i + j) % 5 == 0 else Color(0.6, 0.6, 0.62))
	# Pedestal do microfone com o pop filter.
	cx(sup, METAL, base, b, Vector3(0.55, 0.75, 0.55), Vector3(0.2, 0.02, 0.2), PRETO)
	cx(sup, METAL, base, b, Vector3(0.55, 1.12, 0.55), Vector3(0.02, 0.74, 0.02), PRETO)
	cx(sup, METAL, base, b, Vector3(0.55, 1.50, 0.50), Vector3(0.05, 0.12, 0.05), Color(0.3, 0.3, 0.32))
	cx(sup, TECIDO, base, b, Vector3(0.55, 1.50, 0.40), Vector3(0.14, 0.14, 0.01), Color(0.05, 0.05, 0.05))
	_solido(colisao, base, giro, Vector3(1.40, 0.76, 0.62))
	return base + b * Vector3(-0.15, 0.98, 0.1)


## Placas de espuma de estudio (caixa de ovo), em grade. `centro` na parede.
## Cada placa e a base e nove bicos girados 45 graus: e o relevo, e nao a cor,
## que faz a espuma ler como espuma quando a luz negra passa de raspao.
static func espuma(sup: Dictionary, centro: Vector3, giro: float, cols: int,
		linhas: int, cor: Color) -> void:
	var b := Basis(Vector3.UP, giro)
	var bico := Basis(Vector3.BACK, PI * 0.25)
	for i in cols:
		for j in linhas:
			var p := Vector3((float(i) - (cols - 1) * 0.5) * 0.5, (float(j) - (linhas - 1) * 0.5) * 0.5, 0.0)
			var tom := cor * (0.9 + 0.2 * float((i + j) % 2))
			cx(sup, TECIDO, centro, b, p + Vector3(0.0, 0.0, 0.015), Vector3(0.48, 0.48, 0.03), tom)
			for u in 3:
				for v in 3:
					var q := p + Vector3((u - 1) * 0.155, (v - 1) * 0.155, 0.045)
					cx(sup, TECIDO, centro, b, q, Vector3(0.075, 0.075, 0.05), tom, bico)


# --- banheiro ---------------------------------------------------------------

static func vaso(sup: Dictionary, colisao: Array[Dictionary], base: Vector3,
		giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var loica := BRANCO
	cx(sup, PLASTICO, base, b, Vector3(0.0, 0.18, 0.05), Vector3(0.24, 0.36, 0.34), loica)
	cx(sup, PLASTICO, base, b, Vector3(0.0, 0.39, 0.08), Vector3(0.38, 0.05, 0.50), loica)
	cx(sup, PLASTICO, base, b, Vector3(0.0, 0.62, -0.17), Vector3(0.40, 0.40, 0.16), loica)
	_solido(colisao, base, giro, Vector3(0.4, 0.8, 0.6))


static func pia_banheiro(sup: Dictionary, base: Vector3, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	var loica := BRANCO
	cx(sup, PLASTICO, base, b, Vector3(0.0, 0.40, -0.12), Vector3(0.16, 0.80, 0.16), loica)
	cx(sup, PLASTICO, base, b, Vector3(0.0, 0.84, 0.0), Vector3(0.50, 0.12, 0.40), loica)
	cx(sup, METAL, base, b, Vector3(0.0, 0.95, -0.14), Vector3(0.03, 0.10, 0.03), INOX)
	# Espelho sem moldura, com o armarinho em cima.
	cx(sup, METAL, base, b, Vector3(0.0, 1.45, -0.19), Vector3(0.46, 0.60, 0.01), Color(0.82, 0.86, 0.88))
	cx(sup, PLASTICO, base, b, Vector3(0.0, 1.85, -0.14), Vector3(0.50, 0.14, 0.12), loica)


## Chuveiro eletrico branco com o cano, e a cortina do box.
static func chuveiro(sup: Dictionary, parede: Vector3, giro: float, cor_cortina: Color) -> void:
	var b := Basis(Vector3.UP, giro)
	cx(sup, METAL, parede, b, Vector3(0.0, 2.05, 0.10), Vector3(0.025, 0.025, 0.20), INOX)
	cx(sup, PLASTICO, parede, b, Vector3(0.0, 2.02, 0.26), Vector3(0.14, 0.18, 0.12), BRANCO)
	cx(sup, PLASTICO, parede, b, Vector3(0.0, 1.90, 0.28), Vector3(0.16, 0.04, 0.16), BRANCO)
	cx(sup, METAL, parede, b, Vector3(0.0, 2.15, 0.85), Vector3(1.0, 0.02, 0.02), INOX)
	for k in 7:
		cx(sup, TECIDO, parede, b, Vector3(-0.45 + k * 0.08, 1.30, 0.85 + (k % 2) * 0.03),
			Vector3(0.09, 1.68, 0.01), cor_cortina)
