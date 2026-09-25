## O que carro e pedestre precisam ler da esquina, do mesmo jeito
## (PLANO_TRANSITO_AAA, Passo 3): onde fica a linha de retencao PINTADA e onde
## ficam as quatro zebras.
##
## A linha que o carro usava nao era a pintada
## -------------------------------------------
## A IA antiga (e a dos Passos 1 e 2, que herdou a conta) parava o bico a
## `meia_pista` da transversal + `Vias.FOLGA_RETENCAO` do centro. A pintura
## (`ChunkBuilder._retencao`) e a zebra (`ChunkBuilder.travessias`) contam da
## `meia_asfalto` — pista MAIS a faixa de estacionamento, que entrou na malha
## depois da conta do carro. A diferenca e a faixa de estacionamento inteira:
## 1,8 m na rua e 2,2 m na avenida. O carro parava com o bico 1,4 m alem da
## linha pintada, em cima da zebra (rua: bico a 5,9 m do centro, zebra de 5,05 a
## 6,55 m), exatamente onde o pedestre passa (6,16 m). A blitz ja contava
## certo (`PlantaBlitz`, "ASFALTO da transversal").
##
## A linha pintada tambem nao e simetrica: nos bracos norte e leste ela cobre
## de `asf + 2,22` a `asf + 2,50`, nos bracos sul e oeste de `asf + 2,50` a
## `asf + 2,78` (o deslocamento de meia espessura nao troca de sinal com o
## braco). O carro para atras da borda mais longe dos dois casos, a mesma em
## toda esquina — como a blitz, que tambem soma a espessura.
class_name Esquina
extends RefCounted

enum Braco { N, S, L, O }

## Espessura da linha pintada, em metros (`ChunkBuilder._retencao`).
const ESPESSURA_LINHA := 0.28
## Recuo da zebra a partir da borda do asfalto e a profundidade dela
## (`ChunkBuilder.FAIXA_RECUO` e `FAIXA_PROFUNDIDADE`; a bancada confere). Copiados
## e nao lidos de la: classe leve nao puxa o ChunkBuilder (memoria "classe leve
## nao puxa ChunkBuilder").
const ZEBRA_RECUO := 0.25
const ZEBRA_PROFUNDIDADE := 1.5


## Uma zebra, no referencial do cruzamento: `a` aponta ao longo do braco, para
## fora do miolo; `u` atravessa a rua, que e por onde o pedestre anda. A faixa
## ocupa `lo..hi` ao longo de `a` e `-meia..meia` ao longo de `u`.
class Zebra:
	var ij := Vector2i.ZERO
	var braco := 0
	var centro := Vector2.ZERO
	var a := Vector2.ZERO
	var u := Vector2.ZERO
	var lo := 0.0
	var hi := 0.0
	var meia := 0.0
	## Eixo dos carros que andam neste braco (o que o boneco do pedestre olha).
	var eixo_carro := 0

	func ao_longo(p: Vector2) -> float:
		return (p - centro).dot(a)

	func atravessado(p: Vector2) -> float:
		return (p - centro).dot(u)

	## O ponto do meio da faixa, a `across` metros do eixo da rua.
	func ponto(across: float) -> Vector2:
		return centro + a * ((lo + hi) * 0.5) + u * across


## Distancia do centro do cruzamento `ij` ate a linha de retencao de quem chega
## andando no eixo `eixo`, pela borda da pintura mais longe do miolo. Ver o
## cabecalho.
static func linha(ij: Vector2i, eixo: int) -> float:
	var asf := (Vias.meia_asfalto_z_no(ij.x, ij.y) if eixo == 0
		else Vias.meia_asfalto_x_no(ij.x, ij.y))
	return asf + Vias.FOLGA_RETENCAO + ESPESSURA_LINHA


## O braco por onde chega quem anda no trecho `t` (andando para +Z, chega pelo
## sul).
static func braco_de_chegada(t: Vector4i) -> int:
	if t.z == 0:
		return Braco.S if t.w > 0 else Braco.N
	return Braco.O if t.w > 0 else Braco.L


## O braco por onde sai quem segue no trecho `t`.
static func braco_de_saida(t: Vector4i) -> int:
	if t.z == 0:
		return Braco.N if t.w > 0 else Braco.S
	return Braco.L if t.w > 0 else Braco.O


static func existe_braco(ij: Vector2i, braco: int) -> bool:
	match braco:
		Braco.N:
			return Vias.braco_n(ij.x, ij.y)
		Braco.S:
			return Vias.braco_s(ij.x, ij.y)
		Braco.L:
			return Vias.braco_l(ij.x, ij.y)
	return Vias.braco_o(ij.x, ij.y)


static var _zebras: Dictionary = {}
const TETO_ZEBRAS := 4000


## A zebra do braco `braco` de `ij`. As contas sao as de
## `ChunkBuilder.travessias`: a faixa fica alem do asfalto da transversal, e
## cobre o asfalto do proprio braco.
static func zebra(ij: Vector2i, braco: int) -> Zebra:
	var chave := Vector3i(ij.x, ij.y, braco)
	var pronta: Variant = _zebras.get(chave)
	if pronta != null:
		return pronta
	var z := Zebra.new()
	z.ij = ij
	z.braco = braco
	z.centro = Vector2(float(ij.x) * Vias.TAM, float(ij.y) * Vias.TAM)
	var asf := 0.0
	match braco:
		Braco.N, Braco.S:
			var sz := 1.0 if braco == Braco.N else -1.0
			z.a = Vector2(0.0, sz)
			z.u = Vector2(1.0, 0.0)
			asf = Vias.meia_asfalto_z_no(ij.x, ij.y)
			z.meia = MalhaUrbana.meia_asfalto(MalhaUrbana.via_x_em(ij.x,
				ij.y if braco == Braco.N else ij.y - 1))
			z.eixo_carro = 0
		_:
			var sx := 1.0 if braco == Braco.L else -1.0
			z.a = Vector2(sx, 0.0)
			z.u = Vector2(0.0, 1.0)
			asf = Vias.meia_asfalto_x_no(ij.x, ij.y)
			z.meia = MalhaUrbana.meia_asfalto(MalhaUrbana.via_z_em(ij.y,
				ij.x if braco == Braco.L else ij.x - 1))
			z.eixo_carro = 1
	z.lo = asf + ZEBRA_RECUO
	z.hi = asf + ZEBRA_RECUO + ZEBRA_PROFUNDIDADE
	if _zebras.size() >= TETO_ZEBRAS:
		_zebras.clear()
	_zebras[chave] = z
	return z
