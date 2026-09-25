## Moveis do bar com forma de movel: cadeira monobloco, mesa de plastico,
## banqueta, copo americano, cinzeiro e a estufa de salgado do mercado.
##
## Por que existe
## -------------
## O KitBar montava cada movel com `KitModular.caixa_cor`. A cadeira eram quatro
## caixas e lia como cubo amarelo; a mesa, um tampo quadrado num pe de caixa. E
## a cadeira ficava de COSTAS para a mesa: o encosto (local -z) caia entre a
## cadeira e o tampo. O usuario viu as duas coisas na primeira olhada
## (PLANO_BAR_E_CIDADE_AAA, B1 a B3).
##
## Molde, e nao peca solta
## -----------------------
## `Peca` (torno, tubo, prisma) escreve vertice a vertice, e cada `_v` tira o
## array do balde para uma variavel e da append: com o balde ainda no
## dicionario, o PackedArray e COPIADO a cada vertice. No balde do chunk, que ja
## tem milhares de vertices, isso e quadratico. Por isso cada movel e montado
## UMA vez num balde proprio (o molde, pequeno), guardado, e cada copia entra no
## chunk por `PSXMesh.acumular`, que copia o balde uma vez por chamada.
##
## O molde e compartilhado entre as threads do ChunkManager: a primeira que pede
## monta sob a trava, as outras so leem. Ler PackedArray de varias threads e
## seguro; escrever nunca acontece depois de pronto.
##
## Convencao: todo movel olha para +Z local (quem senta na cadeira olha +Z; o
## encosto fica em -Z), com a base no chao, no centro.
class_name MoveisDoBar
extends RefCounted

## Topo do assento da cadeira monobloco. `Convidado.altura_assento` usa este
## numero: o quadril pousa 5 cm acima dele (Corpo._pose_assento).
const ALTURA_ASSENTO := 0.445
## Topo do assento da banqueta de balcao.
const ALTURA_BANQUETA := 0.745
## Topo do tampo da mesa de plastico.
const ALTURA_MESA := 0.735
const LADO_MESA := 0.70
## Do centro da mesa ao centro do assento de uma cadeira virada para ela. Com
## 0,58 o joelho de quem senta (a 0,42 m do quadril) passa 7 cm por baixo do
## tampo, que e onde ele fica numa mesa de bar.
const AFASTAMENTO_CADEIRA := 0.58
## Quanto o quadril de quem senta fica atras do centro do assento, para o lado
## do encosto. Sem isso a coxa sai 5 cm alem da beira e a pessoa le "na ponta
## da cadeira".
const RECUO_QUADRIL := 0.045

## Plastico neutro (textura `bar_monobloco`, so o grao): a cor e a do vertice,
## a do jogo de mesa e cadeira de cada bar. O `bar_plastico` antigo e amarelo, e
## a tinta multiplica: a cadeira branca saia amarela e a azul saia marrom.
## Mesa e cadeira em baldes separados: o teste do bar conta mesa pelo balde.
const MAT_CADEIRA := &"bar_monobloco"
## A cadeira em dois niveis de detalhe (`_fazer_cadeira`). O guarda-sol segue no
## balde sem nivel.
const MAT_CADEIRA_PERTO := &"bar_monobloco@perto"
const MAT_CADEIRA_LONGE := &"bar_monobloco@longe"
const MAT_MESA := &"bar_monobloco_mesa"
## Miudeza de tampo: corta a 40 m (ChunkManager.ALCANCE_PERTO). De longe um copo
## e um pixel, e sao dezenas deles.
const MAT_MIUDO := &"mercado_louca@perto"

## Cerveja no copo americano e a espuma em cima.
const CERVEJA := Color("d8952a")
const ESPUMA := Color("f2ecdc")
const VIDRO_CINZEIRO := Color("b9c7c2")

static var _moldes: Dictionary = {}
static var _trava: Mutex = Mutex.new()


## Um molde pelo nome. Monta na primeira vez, sob a trava.
##
## As cores deste arquivo sao escritas em sRGB, como se escolhe no editor, e o
## molde as passa para linear: o `psx_surface` faz `ALBEDO = texel * COLOR`, com
## o texel ja linear e a COLOR crua. Sem a conversao o amarelo da cadeira saia
## creme e a cerveja do copo saia cor de cha. `linear` falso deixa o molde como
## veio — a estufa do mercado foi afinada no olho com a cor crua.
static func _molde(nome: StringName, fazer: Callable, linear: bool = true) -> Dictionary:
	_trava.lock()
	var m: Dictionary = _moldes.get(nome, {})
	if m.is_empty():
		m = fazer.call()
		if linear:
			for mat: StringName in m:
				var cores: PackedColorArray = m[mat]["c"]
				for k in cores.size():
					var a := cores[k].a
					cores[k] = cores[k].srgb_to_linear()
					cores[k].a = a
				m[mat]["c"] = cores
		_moldes[nome] = m
	_trava.unlock()
	return m


## Copia um molde para `sup` em `xf`. Com `cor` de alfa positivo (em sRGB, como
## as do molde), tinge o molde inteiro dessa cor: a cadeira e de uma cor so, e
## o molde sai branco.
static func por(sup: Dictionary, molde: Dictionary, xf: Transform3D,
		cor: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	for mat: StringName in molde:
		if not sup.has(mat):
			sup[mat] = PSXMesh.dados_vazios()
		if cor.a > 0.0:
			PSXMesh.acumular_tingido(sup[mat], molde[mat], xf, cor.srgb_to_linear())
		else:
			PSXMesh.acumular(sup[mat], molde[mat], xf)


## Giro que faz um movel em `de` olhar para `para` (+Z local na direcao).
static func giro_para(de: Vector3, para: Vector3) -> float:
	var d := para - de
	return atan2(d.x, d.z)


# --- cadeira ----------------------------------------------------------------

static func cadeira() -> Dictionary:
	return _molde(&"cadeira", _fazer_cadeira)


## Cadeira monobloco de bar, com braco: a de todo boteco do Brasil.
##
## Assento com a saia do plastico, quatro pernas abertas, a perna da frente sobe
## e vira o apoio do braco, a de tras sobe e vira o montante do encosto, e o
## encosto e VAZADO — duas faixas curvas, concavas para quem senta. E o vazado
## que diz "cadeira de plastico" a dez metros; encosto cheio lia como poltrona.
##
## Uns 180 triangulos. A cadeira de caixa custava 48 e era a peca mais
## repetida do bar; o ganho de silhueta e o que o usuario pediu.
##
## Dois niveis (ChunkManager, baldes @perto e @longe): esta, de perto, e a de
## `_cadeira_de_longe` a partir de ALCANCE_PERTO. Eram 3.600 triangulos por chunk
## de bar desenhados ate o horizonte (tests/bancada_orcamento_chunk.gd).
static func _fazer_cadeira() -> Dictionary:
	var s := {}
	var m := MAT_CADEIRA_PERTO
	var c := Color.WHITE
	_cadeira_de_longe(s, c)
	Peca.prisma(s, m, Transform3D.IDENTITY,
		Peca.retangulo_redondo(Vector2(0.46, 0.44), 0.07, 1), 0.385, ALTURA_ASSENTO, c)
	for lado: float in [-1.0, 1.0]:
		# Perna da frente, que sobe ate o braco.
		Peca.tubo(s, m, PackedVector3Array([
			Vector3(lado * 0.25, 0.0, 0.23), Vector3(lado * 0.215, 0.40, 0.175),
			Vector3(lado * 0.245, 0.635, 0.125),
		]), 0.024, 4, c, false, PackedFloat32Array([0.028, 0.024, 0.019]))
		# Perna de tras, que sobe e segura o encosto reclinado.
		Peca.tubo(s, m, PackedVector3Array([
			Vector3(lado * 0.25, 0.0, -0.24), Vector3(lado * 0.215, 0.40, -0.19),
			Vector3(lado * 0.21, 0.87, -0.295),
		]), 0.024, 4, c, false, PackedFloat32Array([0.028, 0.024, 0.02]))
		# Braco, da perna da frente ao montante.
		Peca.tubo(s, m, PackedVector3Array([
			Vector3(lado * 0.245, 0.635, 0.125), Vector3(lado * 0.232, 0.66, -0.07),
			Vector3(lado * 0.215, 0.68, -0.245),
		]), 0.021, 4, c, false)
	# Encosto: duas faixas curvas. O montante recua 10 cm em 46 de altura, e a
	# faixa de cima acompanha.
	_faixa(s, m, 0.58, 0.68, -0.235, 0.215, c)
	_faixa(s, m, 0.745, 0.865, -0.272, 0.228, c)
	return s


## A cadeira de 60 m em diante: a mesma silhueta em ~70 triangulos. Assento reto,
## perna reta do pe ao braco e ao encosto (a dobra do joelho e 3 cm), tres lados
## no tubo, e as duas faixas do encosto sem curva: o VAZADO entre elas (6,5 cm,
## dois pixels a 60 m em 4K) e o que ainda diz "cadeira de plastico".
static func _cadeira_de_longe(s: Dictionary, c: Color) -> void:
	var m := MAT_CADEIRA_LONGE
	Peca.prisma(s, m, Transform3D.IDENTITY, PackedVector2Array([Vector2(-0.23, -0.22),
		Vector2(0.23, -0.22), Vector2(0.23, 0.22), Vector2(-0.23, 0.22)]), 0.385,
		ALTURA_ASSENTO, c, true, false)
	for lado: float in [-1.0, 1.0]:
		Peca.tubo(s, m, PackedVector3Array([Vector3(lado * 0.25, 0.0, 0.23),
			Vector3(lado * 0.245, 0.635, 0.125)]), 0.026, 3, c, false)
		Peca.tubo(s, m, PackedVector3Array([Vector3(lado * 0.25, 0.0, -0.24),
			Vector3(lado * 0.21, 0.87, -0.295)]), 0.026, 3, c, false)
		Peca.tubo(s, m, PackedVector3Array([Vector3(lado * 0.245, 0.635, 0.125),
			Vector3(lado * 0.215, 0.68, -0.245)]), 0.021, 3, c, false)
	for f: Vector4 in [Vector4(0.58, 0.68, -0.235, 0.215), Vector4(0.745, 0.865, -0.272, 0.228)]:
		var z := f.z + 0.012
		Peca.prisma(s, m, Transform3D.IDENTITY, PackedVector2Array([Vector2(-f.w, z - 0.011),
			Vector2(f.w, z - 0.011), Vector2(f.w, z + 0.011), Vector2(-f.w, z + 0.011)]),
			f.x, f.y, c)


## Faixa curva de encosto, concava para +Z, entre `y0` e `y1`.
static func _faixa(s: Dictionary, m: StringName, y0: float, y1: float,
		z: float, meia: float, c: Color) -> void:
	const PASSOS := 4
	const ESPESSURA := 0.022
	const FLECHA := 0.035
	var contorno := PackedVector2Array()
	for k in PASSOS:
		var x := lerpf(-meia, meia, float(k) / float(PASSOS - 1))
		var t := x / meia
		contorno.append(Vector2(x, z + FLECHA * t * t - ESPESSURA * 0.5))
	for k in range(PASSOS - 1, -1, -1):
		var x := lerpf(-meia, meia, float(k) / float(PASSOS - 1))
		var t := x / meia
		contorno.append(Vector2(x, z + FLECHA * t * t + ESPESSURA * 0.5))
	Peca.prisma(s, m, Transform3D.IDENTITY, contorno, y0, y1, c)


# --- mesa -------------------------------------------------------------------

static func mesa() -> Dictionary:
	return _molde(&"mesa", _fazer_mesa)


## Mesa quadrada de plastico: tampo de canto arredondado com a aba funda e
## quatro pernas abertas. A de pe central de caixa lia como banco de praca.
static func _fazer_mesa() -> Dictionary:
	var s := {}
	var c := Color.WHITE
	Peca.prisma(s, MAT_MESA, Transform3D.IDENTITY,
		Peca.retangulo_redondo(Vector2(LADO_MESA, LADO_MESA), 0.06, 1),
		ALTURA_MESA - 0.075, ALTURA_MESA, c)
	for lx: float in [-1.0, 1.0]:
		for lz: float in [-1.0, 1.0]:
			Peca.tubo(s, MAT_MESA, PackedVector3Array([
				Vector3(lx * 0.285, ALTURA_MESA - 0.07, lz * 0.285),
				Vector3(lx * 0.315, 0.0, lz * 0.315),
			]), 0.028, 4, c, false, PackedFloat32Array([0.03, 0.022]))
	return s


static func toalha() -> Dictionary:
	return _molde(&"toalha", _fazer_toalha)


## Toalha xadrez: um palmo maior que o tampo e caida 5 cm na beira. E a beira
## caida que diz pano; do tamanho do tampo ela lia como tinta.
static func _fazer_toalha() -> Dictionary:
	var s := {}
	Peca.prisma(s, &"bar_xadrez", Transform3D.IDENTITY,
		Peca.retangulo_redondo(Vector2(LADO_MESA + 0.08, LADO_MESA + 0.08), 0.03, 1),
		ALTURA_MESA - 0.05, ALTURA_MESA + 0.006, Color.WHITE)
	return s


# --- banqueta ---------------------------------------------------------------

static func banqueta() -> Dictionary:
	return _molde(&"banqueta", _fazer_banqueta)


## Banqueta alta de balcao: assento redondo de madeira, quatro pes de ferro
## abertos e o aro de apoiar o pe.
static func _fazer_banqueta() -> Dictionary:
	var s := {}
	var ferro := Color("3c3e3c")
	Peca.cilindro(s, &"tabua", Vector3(0.0, ALTURA_BANQUETA - 0.045, 0.0), 0.175, 0.045,
		10, Color("8a6234"), true, true)
	var aro := PackedVector3Array()
	for k in 4:
		var a := PI * 0.25 + PI * 0.5 * float(k)
		var topo := Vector3(cos(a), 0.0, sin(a)) * 0.13 + Vector3(0.0, ALTURA_BANQUETA - 0.05, 0.0)
		var pe := Vector3(cos(a), 0.0, sin(a)) * 0.2
		Peca.tubo(s, &"metal_pintado", PackedVector3Array([topo, pe]), 0.016, 4, ferro, false)
		aro.append(Vector3(cos(a), 0.0, sin(a)) * 0.178 + Vector3(0.0, 0.26, 0.0))
	aro.append(aro[0])
	Peca.tubo(s, &"metal_pintado", aro, 0.012, 4, ferro, false)
	return s


# --- miudeza de tampo -------------------------------------------------------

static func copo() -> Dictionary:
	return _molde(&"copo", _fazer_copo)


## Copo americano de cerveja: o corpo de cerveja e o dedo de espuma em cima.
static func _fazer_copo() -> Dictionary:
	var s := {}
	Peca.torno(s, MAT_MIUDO, Transform3D.IDENTITY, PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.027, 0.0), Vector2(0.027, 0.0),
		Vector2(0.032, 0.074),
	]), 7, CERVEJA)
	Peca.torno(s, MAT_MIUDO, Transform3D.IDENTITY, PackedVector2Array([
		Vector2(0.032, 0.074), Vector2(0.034, 0.093), Vector2(0.034, 0.093),
		Vector2(0.0, 0.09),
	]), 7, ESPUMA)
	return s


static func cinzeiro() -> Dictionary:
	return _molde(&"cinzeiro", _fazer_cinzeiro)


## Cinzeiro de vidro grosso, com a boca funda.
static func _fazer_cinzeiro() -> Dictionary:
	var s := {}
	Peca.torno(s, MAT_MIUDO, Transform3D.IDENTITY, PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.052, 0.0), Vector2(0.052, 0.0),
		Vector2(0.056, 0.026), Vector2(0.056, 0.026), Vector2(0.042, 0.026),
		Vector2(0.036, 0.012), Vector2(0.0, 0.012),
	]), 8, VIDRO_CINZEIRO)
	return s


static func cupula() -> Dictionary:
	return _molde(&"cupula", _fazer_cupula)


## Cupula esmaltada de pendente de boteco: verde por fora, branca por dentro, e
## a lampada acesa na boca. A de caixa lia como caixa de som pendurada.
static func _fazer_cupula() -> Dictionary:
	var s := {}
	Peca.torno(s, &"metal_pintado", Transform3D.IDENTITY, PackedVector2Array([
		Vector2(0.0, 0.12), Vector2(0.03, 0.12), Vector2(0.05, 0.09),
		Vector2(0.155, -0.005),
	]), 10, Color("2f5a3a"))
	Peca.torno(s, &"metal_pintado", Transform3D.IDENTITY, PackedVector2Array([
		Vector2(0.15, -0.005), Vector2(0.048, 0.083), Vector2(0.0, 0.105),
	]), 10, Color("e8e4d8"))
	Peca.esfera(s, &"mercado_luz", Transform3D(Basis.IDENTITY, Vector3(0.0, 0.03, 0.0)),
		0.04, 6, 4, Color("fff1cc"))
	return s


# --- estufa de salgado (a do mercado) ---------------------------------------

static func estufa() -> Dictionary:
	return _molde(&"estufa", _fazer_estufa, false)


## A estufa do mercado (`KitSalao.estufa`): coxinha, pao de queijo e pastel
## modelados, no lugar da caixa com foto de salgado. A colisao sai daqui e quem
## poe a estufa no balcao faz a propria.
static func _fazer_estufa() -> Dictionary:
	var s := {}
	var descarte: Array[Dictionary] = []
	KitSalao.estufa(s, descarte, Vector3.ZERO, 0.0, 5501)
	# Tudo no balde de perto: sao 1.500 triangulos de coxinha e pao de queijo
	# num objeto de 60 cm, que a 40 m e um pixel alaranjado.
	var perto := {}
	for mat: StringName in s:
		perto[StringName(String(mat) + "@perto")] = s[mat]
	return perto


## Tamanho da estufa (largura, altura, fundo), para a colisao de quem a poe.
const TAMANHO_ESTUFA := Vector3(0.66, 0.6, 0.48)


# --- o que se pede no balcao (VendaDoBar) ------------------------------------------
# Moldes do pedido que o atendente pousa na formica (PedidoNoBalcao). Fora do
# chunk: os materiais sao os de nome puro, sem `@perto`, e as cores vao cruas
# (linear falso), como as da estufa — os salgados sao os do KitSalao.

const PINGA := Color("e8dca0")
const VIDRO_DOSE := Color("c8d6d2")
const LOUCA := Color("f2f0ea")
const TORRESMO_COURO := Color("b8742e")
const TORRESMO_GORDURA := Color("ecd6a0")


static func dose() -> Dictionary:
	return _molde(&"dose", _fazer_dose, false)


## A dose no copinho lagoinha: vidro grosso de fundo pesado, a pinga ate dois
## dedos da borda.
static func _fazer_dose() -> Dictionary:
	var s := {}
	Peca.torno(s, &"mercado_louca", Transform3D.IDENTITY, PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.021, 0.0), Vector2(0.021, 0.012),
		Vector2(0.024, 0.058), Vector2(0.021, 0.058), Vector2(0.018, 0.012),
		Vector2(0.0, 0.012),
	]), 8, VIDRO_DOSE)
	Peca.torno(s, &"mercado_louca", Transform3D.IDENTITY, PackedVector2Array([
		Vector2(0.0, 0.012), Vector2(0.018, 0.012), Vector2(0.021, 0.046),
		Vector2(0.0, 0.046),
	]), 8, PINGA)
	return s


static func pires(com: StringName) -> Dictionary:
	return _molde(StringName("pires_" + String(com)), _fazer_pires.bind(com), false)


## O pires de louca branca com o salgado da estufa em cima.
static func _fazer_pires(com: StringName) -> Dictionary:
	var s := {}
	Peca.torno(s, &"mercado_louca", Transform3D.IDENTITY, PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.045, 0.0), Vector2(0.07, 0.012),
		Vector2(0.074, 0.016), Vector2(0.062, 0.012), Vector2(0.0, 0.008),
	]), 12, LOUCA)
	if com == &"coxinha":
		KitSalao.coxinha(s, Vector3(0.0, 0.008, 0.0), 0.4, 1.15)
	elif com == &"torresmo":
		# Quatro pedacos: couro estufado por cima, gordura por baixo.
		var pedacos: Array[Vector4] = [Vector4(-0.022, 0.0, -0.012, 0.3),
			Vector4(0.02, 0.0, -0.016, -0.5), Vector4(-0.004, 0.0, 0.022, 1.2),
			Vector4(0.026, 0.017, 0.018, 0.2)]
		for p: Vector4 in pedacos:
			var xf := Transform3D(Basis(Vector3.UP, p.w), Vector3(p.x, 0.008 + p.y, p.z))
			Peca.prisma(s, &"mercado_produto", xf,
				Peca.retangulo_redondo(Vector2(0.042, 0.022), 0.006, 1), 0.0, 0.012,
				TORRESMO_GORDURA)
			Peca.prisma(s, &"mercado_produto", xf,
				Peca.retangulo_redondo(Vector2(0.044, 0.024), 0.008, 1), 0.012, 0.022,
				TORRESMO_COURO)
	return s


# --- guarda-sol (B12) ---------------------------------------------------------------

## As duas cores da listra de cada toldo (tools/gerar_bar.py e
## gerar_bar_variantes.py): o guarda-sol da mesa e do mesmo pano.
const LISTRAS := {
	&"bar_toldo": [Color(0.769, 0.196, 0.18), Color(0.831, 0.69, 0.227)],
	&"bar_toldo_verde": [Color(0.18, 0.463, 0.275), Color(0.933, 0.918, 0.871)],
	&"bar_toldo_azul": [Color(0.157, 0.314, 0.588), Color(0.933, 0.918, 0.871)],
	&"bar_toldo_laranja": [Color(0.839, 0.431, 0.141), Color(0.933, 0.918, 0.871)],
}
const RAIO_GUARDA_SOL := 1.0
const ALTURA_GUARDA_SOL := 2.44
const GOMOS := 8


static func guarda_sol(tecido: StringName) -> Dictionary:
	return _molde(StringName("guarda_sol_" + String(tecido)),
		_fazer_guarda_sol.bind(tecido))


## Guarda-sol de mesa de bar: oito gomos de lona alternando as duas cores da
## listra, a barriga entre uma vareta e outra, o babado recortado na borda, as
## varetas por baixo e o mastro com a ponteira. O de caixa (uma placa de 1,9 m e
## quatro abas) lia como mesa voando.
##
## Uns 260 triangulos: gomo em cima e embaixo (quem senta ve o avesso), duas
## colunas por gomo, que e o que da a barriga.
static func _fazer_guarda_sol(tecido: StringName) -> Dictionary:
	var s := {}
	var cores: Array = LISTRAS.get(tecido, LISTRAS[&"bar_toldo"])
	var r := RAIO_GUARDA_SOL
	var topo := ALTURA_GUARDA_SOL
	var borda := topo - 0.34
	# De cima: do eixo para a borda, descendo (a face olha para fora e para
	# cima). Por baixo: o mesmo perfil ao contrario, um centimetro abaixo.
	var cima := PackedVector2Array([Vector2(r, borda), Vector2(r * 0.55, topo - 0.14),
		Vector2(0.03, topo)])
	var baixo := PackedVector2Array([Vector2(0.03, topo - 0.012),
		Vector2(r * 0.55, topo - 0.152), Vector2(r, borda - 0.012)])
	var fatia := 1.0 / float(GOMOS)
	for i in GOMOS:
		var xf := Transform3D(Basis(Vector3.UP, -TAU * fatia * float(i)), Vector3.ZERO)
		var cor: Color = cores[i % 2]
		Peca.torno(s, MAT_CADEIRA, xf, cima, GOMOS, cor, fatia)
		Peca.torno(s, MAT_CADEIRA, xf, baixo, GOMOS, cor.darkened(0.25), fatia)
		# Babado: a aba de 12 cm pendurada na borda, por fora e por dentro.
		Peca.torno(s, MAT_CADEIRA, xf, PackedVector2Array([Vector2(r, borda - 0.13),
			Vector2(r, borda)]), GOMOS, cor, fatia)
		Peca.torno(s, MAT_CADEIRA, xf, PackedVector2Array([Vector2(r - 0.004, borda),
			Vector2(r - 0.004, borda - 0.13)]), GOMOS, cor.darkened(0.25), fatia)
		# A vareta, embaixo da costura entre um gomo e o proximo.
		var ang := TAU * fatia * float(i)
		var dir := Vector3(cos(ang), 0.0, -sin(ang))
		Peca.tubo(s, &"metal", PackedVector3Array([
			Vector3(0.0, topo - 0.03, 0.0) + dir * 0.03,
			Vector3(0.0, borda - 0.02, 0.0) + dir * (r - 0.02),
		]), 0.006, 3, Color("8a8c88"), false)
	# Mastro, do chao a ponteira, e a ponteira.
	Peca.tubo(s, &"metal", PackedVector3Array([Vector3.ZERO,
		Vector3(0.0, topo + 0.04, 0.0)]), 0.019, 6, Color("9a9c98"))
	Peca.esfera(s, &"metal", Transform3D(Basis.IDENTITY, Vector3(0.0, topo + 0.06, 0.0)),
		0.025, 6, 4, Color("5a5c58"))
	return s
