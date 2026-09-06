## Pecas que diferenciam um predio do vizinho.
##
## A massa do predio e uma caixa, e vai continuar sendo: e o que cabe no
## orcamento e e o que o PS1 fazia. O problema de uma cidade feita de caixas nao
## e a caixa, e a repeticao — vinte volumes de concreto do mesmo tom, com o mesmo
## topo reto, viram um corredor sem marco nenhum.
##
## O que quebra isso, na ordem do que se ve primeiro andando na rua:
##
##   1. o remate do topo, que e a silhueta contra o ceu
##   2. a cor da massa, que separa uma quadra da outra ao atravessar
##   3. a sacada, que da profundidade a fachada residencial
##   4. o toldo, que marca o terreo comercial
##
## Tudo por vertice ou por caixa pequena: o mais caro daqui, a caixa d'agua com
## escada, custa 96 triangulos.
class_name KitPredio
extends RefCounted

const QUAD_REMATE := 4.0

## Listras de toldo. Quatro tons chapados: a listra de verdade viria da textura,
## e a textura de toldo ja tem a listra fina — isto aqui e a cor da loja.
const CORES_TOLDO: Array[Color] = [
	Color("8f4438"), Color("3f5a4a"), Color("41506e"), Color("7a6a3c"),
]


## Remate do topo do predio. `topo` e o centro da laje, `tamanho` a planta dela.
##
## `direcao` e para onde a fachada olha, no esquema de KitModular: e por onde o
## beiral avanca e de que lado a caixa d'agua fica visivel.
static func coroar(sup: Dictionary, tipo: MalhaUrbana.Coroamento, topo: Vector3,
		tamanho: Vector3, direcao: int, cor: Color,
		rng: RandomNumberGenerator) -> void:
	match tipo:
		MalhaUrbana.Coroamento.PLATIBANDA:
			platibanda(sup, topo, tamanho, cor)
		MalhaUrbana.Coroamento.CAIXA_DAGUA:
			platibanda(sup, topo, tamanho, cor, 0.42)
			caixa_dagua(sup, topo, tamanho, rng)
		MalhaUrbana.Coroamento.BEIRAL:
			beiral(sup, topo, tamanho, direcao, cor)
		_:
			platibanda(sup, topo, tamanho, cor, 0.42)
			antena(sup, topo, tamanho, rng)


## Mureta em volta da laje. O remate mais comum e o mais util: fecha o topo do
## volume, entao o predio para de parecer uma caixa cortada no meio.
static func platibanda(sup: Dictionary, topo: Vector3, tamanho: Vector3,
		cor: Color, altura: float = 0.78) -> void:
	const ESPESSURA := 0.2
	var y := topo.y + altura * 0.5
	var meio_x := tamanho.x * 0.5 - ESPESSURA * 0.5
	var meio_z := tamanho.z * 0.5 - ESPESSURA * 0.5
	var escura := cor.lerp(Color("8e8a80"), 0.35)

	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"concreto_sujo",
			Vector3(topo.x + meio_x * lado, y, topo.z),
			Vector3(ESPESSURA, altura, tamanho.z), escura, 0.0,
			PSXMesh.FACE_TODAS, QUAD_REMATE)
		KitModular.caixa_cor(sup, &"concreto_sujo",
			Vector3(topo.x, y, topo.z + meio_z * lado),
			Vector3(tamanho.x - ESPESSURA * 2.0, altura, ESPESSURA), escura, 0.0,
			PSXMesh.FACE_TODAS, QUAD_REMATE)


## Caixa d'agua sobre pes, com escada de marinheiro.
##
## E o elemento que mais diz "suburbio" numa silhueta de telhado, e por isso ela
## aparece mesmo nos predios baixos.
static func caixa_dagua(sup: Dictionary, topo: Vector3, tamanho: Vector3,
		rng: RandomNumberGenerator) -> void:
	var lado := minf(1.9, minf(tamanho.x, tamanho.z) * 0.4)
	var p := Vector3(
		topo.x + rng.randf_range(-1.0, 1.0) * (tamanho.x * 0.5 - lado),
		topo.y, topo.z + rng.randf_range(-1.0, 1.0) * (tamanho.z * 0.5 - lado))
	var pernas := 1.0
	var cor := Color("9aa0a2") if rng.randf() < 0.5 else Color("6d5f4e")

	for dx: float in [-1.0, 1.0]:
		for dz: float in [-1.0, 1.0]:
			KitModular.caixa_cor(sup, &"metal",
				p + Vector3(dx * lado * 0.36, pernas * 0.5, dz * lado * 0.36),
				Vector3(0.12, pernas, 0.12), Color("59554e"), 0.0,
				PSXMesh.FACE_TODAS, QUAD_REMATE)

	KitModular.caixa_cor(sup, &"metal", p + Vector3(0.0, pernas + lado * 0.4, 0.0),
		Vector3(lado, lado * 0.8, lado), cor, 0.0, PSXMesh.FACE_TODAS, QUAD_REMATE)
	KitModular.caixa_cor(sup, &"metal", p + Vector3(0.0, pernas + lado * 0.84, 0.0),
		Vector3(lado * 0.5, 0.12, lado * 0.5), cor.lerp(Color.BLACK, 0.3), 0.0,
		PSXMesh.FACE_TODAS, QUAD_REMATE)

	# Escada. Dois montantes e cinco degraus, o suficiente para a silhueta.
	for m: float in [-0.16, 0.16]:
		KitModular.caixa_cor(sup, &"metal",
			p + Vector3(lado * 0.52, (pernas + lado * 0.6) * 0.5, m),
			Vector3(0.05, pernas + lado * 0.6, 0.05), Color("59554e"), 0.0,
			PSXMesh.FACE_TODAS, 8.0)


## Beiral: laje que avanca sobre a calcada, com a testeira embaixo.
##
## Muda a fachada mais do que parece — a sombra dura na parede sob o avanco e o
## unico contorno horizontal que o predio tem.
static func beiral(sup: Dictionary, topo: Vector3, tamanho: Vector3,
		direcao: int, cor: Color) -> void:
	const AVANCO := 0.55
	var normal := KitModular._normal(direcao)
	var escura := cor.lerp(Color("6f6a62"), 0.45)
	var planta := Vector3(tamanho.x, 0.0, tamanho.z) + Vector3(
		absf(normal.x) * AVANCO * 2.0, 0.0, absf(normal.z) * AVANCO * 2.0)

	KitModular.caixa_cor(sup, &"concreto_sujo",
		topo + normal * AVANCO + Vector3(0.0, 0.13, 0.0),
		Vector3(planta.x + 0.4, 0.26, planta.z + 0.4), escura, 0.0,
		PSXMesh.FACE_TODAS, QUAD_REMATE)
	KitModular.caixa_cor(sup, &"concreto_sujo",
		topo + normal * AVANCO + Vector3(0.0, 0.42, 0.0),
		Vector3(planta.x, 0.32, planta.z), cor.lerp(Color("a09a90"), 0.3), 0.0,
		PSXMesh.FACE_TODAS, QUAD_REMATE)


## Mastro de antena com travessas. Predio comercial ou industrial.
static func antena(sup: Dictionary, topo: Vector3, tamanho: Vector3,
		rng: RandomNumberGenerator) -> void:
	var altura := rng.randf_range(2.6, 4.4)
	var p := Vector3(
		topo.x + rng.randf_range(-0.3, 0.3) * tamanho.x,
		topo.y + 0.4, topo.z + rng.randf_range(-0.3, 0.3) * tamanho.z)
	var giro := rng.randf_range(0.0, PI)

	KitModular.caixa_cor(sup, &"metal", p + Vector3(0.0, altura * 0.5, 0.0),
		Vector3(0.09, altura, 0.09), Color("6e6a62"), giro,
		PSXMesh.FACE_TODAS, 8.0)
	for i in 3:
		var y := altura * (0.5 + float(i) * 0.18)
		var comp := 1.5 - float(i) * 0.34
		KitModular.caixa_cor(sup, &"metal", p + Vector3(0.0, y, 0.0),
			Vector3(comp, 0.05, 0.05), Color("6e6a62"), giro,
			PSXMesh.FACE_TODAS, 8.0)


## Sacada corrida de um andar. `centro` fica no plano da fachada, na base do vao.
##
## Laje fina mais guarda-corpo. Custa 40 triangulos e e o que separa um predio
## residencial de um bloco de escritorio: a fachada ganha uma quebra a cada tres
## metros de altura, e a luz do poste bate nela de baixo.
static func sacada(sup: Dictionary, centro: Vector3, largura: float,
		direcao: int, cor: Color) -> void:
	const AVANCO := 0.85
	var normal := KitModular._normal(direcao)
	var giro := atan2(normal.x, normal.z)
	var meio := centro + normal * (AVANCO * 0.5)

	KitModular.caixa_cor(sup, &"concreto_sujo", meio + Vector3(0.0, 0.06, 0.0),
		Vector3(largura, 0.13, AVANCO), cor.lerp(Color("a5a099"), 0.3), giro,
		PSXMesh.FACE_TODAS, QUAD_REMATE)

	var frente := centro + normal * AVANCO
	KitModular.caixa_cor(sup, &"metal", frente + Vector3(0.0, 0.5, 0.0),
		Vector3(largura, 0.9, 0.07), Color("54585a"), giro,
		PSXMesh.FACE_TODAS, QUAD_REMATE)
	# Montante em cada ponta, para o guarda-corpo nao flutuar.
	var lateral := KitModular._lateral(direcao)
	for lado: float in [-1.0, 1.0]:
		KitModular.caixa_cor(sup, &"metal",
			frente + lateral * (largura * 0.5 * lado) + Vector3(0.0, 0.5, 0.0),
			Vector3(0.08, 0.98, AVANCO), Color("54585a"), giro,
			PSXMesh.FACE_TODAS, QUAD_REMATE)


## Toldo do terreo comercial. Inclinado para a calcada, com franja.
static func toldo(sup: Dictionary, centro: Vector3, largura: float,
		direcao: int, indice: int) -> void:
	const AVANCO := 1.25
	var normal := KitModular._normal(direcao)
	var giro := atan2(normal.x, normal.z)
	# Base composta: o toldo cai para a rua, e giro em Y sozinho nao inclina.
	var base := Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, 0.34)
	var cor := CORES_TOLDO[indice % CORES_TOLDO.size()]

	KitModular.caixa_livre(sup, &"toldo",
		centro + normal * (AVANCO * 0.5) + Vector3(0.0, 0.12, 0.0),
		Vector3(largura, 0.08, AVANCO * 1.1), base, cor, QUAD_REMATE)
	KitModular.caixa_cor(sup, &"toldo",
		centro + normal * AVANCO + Vector3(0.0, -0.32, 0.0),
		Vector3(largura, 0.3, 0.06), cor.lerp(Color.BLACK, 0.12), giro,
		PSXMesh.FACE_TODAS, QUAD_REMATE)
	for lado: float in [-1.0, 1.0]:
		var lateral := KitModular._lateral(direcao)
		KitModular.caixa_cor(sup, &"metal",
			centro + lateral * (largura * 0.5 * lado) + normal * (AVANCO * 0.5)
				+ Vector3(0.0, 0.02, 0.0),
			Vector3(0.06, 0.06, AVANCO), Color("50524e"), giro,
			PSXMesh.FACE_TODAS, 8.0)


## Grade de janela de terreo. Duas barras verticais sobre o vao.
##
## So no terreo, e so no distrito industrial e no baldio: grade em tudo le como
## favela generica, e grade em quase nada le como cidade que ainda confia.
static func grade(sup: Dictionary, centro: Vector3, tamanho: Vector2,
		direcao: int) -> void:
	var normal := KitModular._normal(direcao)
	var lateral := KitModular._lateral(direcao)
	var giro := atan2(normal.x, normal.z)
	var n := maxi(2, int(tamanho.x / 0.28))
	for i in n:
		var t := (float(i) + 0.5) / float(n) - 0.5
		KitModular.caixa_cor(sup, &"metal",
			centro + normal * 0.05 + lateral * (t * tamanho.x),
			Vector3(0.035, tamanho.y, 0.035), Color("3e4042"), giro,
			PSXMesh.FACE_TODAS, 8.0)
