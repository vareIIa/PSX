## O relevo de Minas em escala de bairro: os morros, os vales entre eles e o
## morro da matriz, com a praca no topo.
##
## Por que existe
## -------------
## A primeira ladeira (Relevo) era um ruido suave de sete metros: a rua mais
## ingreme da cidade tinha 10%, a mediana 2,5%, e na nevoa aquilo lia como rua
## ondulada, nao como Minas. Cidade mineira e morro: a igreja no alto, a rua que
## desce reta para o corrego e sobe do outro lado, o bairro pendurado na encosta,
## a escadaria onde nem carro sobe. Ruido suave nao faz encosta — faz ondulacao.
##
## Como e feito
## ------------
## Funcao pura da coordenada do NO (canto de chunk), sem cache: quem guarda e o
## Relevo, que ainda nivela parque e patamar por cima disto.
##
##   morro       um por celula de CELULA chunks, em posicao, altura e raio
##               sorteados pela celula. Perfil em cosseno: topo arredondado,
##               encosta mais ingreme no meio, pe que encosta no vale sem quina.
##   vale        o que sobra entre os morros: e o `max` dos morros vizinhos, e o
##               vinco onde duas encostas se encontram e o talvegue do corrego.
##   matriz      o morro da praca, mais alto e mais largo que os outros, com topo
##               plano do tamanho da quadra. A praca fica em y = 0 e a cidade
##               inteira DESCE dela: nenhuma coordenada da abertura muda.
##   miudo       dois metros de ruido para a encosta nao ser um cone perfeito.
##
## Dependencias: so o ruido da MalhaUrbana e o de valor do Relevo, funcoes puras.
## O Relevo e a MalhaUrbana podem perguntar aqui sem ciclo.
class_name Morros
extends RefCounted

## Centro do morro da matriz, em chunks: o meio da quadra ancorada da Praca da
## Matriz (Tracado._ancora, x 224..320 e z -96..0). A praca inteira cabe no topo.
const MATRIZ := Vector2(8.5, -1.5)
## Altura do morro da matriz acima do vale, raio da encosta e raio do topo plano,
## em chunks. O topo cobre os quatro cantos da quadra (2,12 chunks do centro).
const ALTURA_MATRIZ := 36.0
const RAIO_MATRIZ := 14.0
const TOPO_MATRIZ := 2.5
## Perto da matriz os outros morros encolhem: nada pode subir acima da igreja
## logo ao lado dela.
const LIVRE_DA_MATRIZ := Vector2(0.6, 1.4)

## Celula de um morro, em chunks (384 m), e os sorteios por celula.
const CELULA := 12.0
const ALTURA_MORRO := Vector2(10.0, 34.0)
const RAIO_MORRO := Vector2(0.6, 0.9)
## Posicao do morro dentro da celula: fora das bordas, para dois vizinhos nunca
## nascerem colados.
const MARGEM := 0.2

## Ruido miudo: amplitude em metros e escala em chunks. Some no topo da matriz.
const MIUDO := 2.0
const ESCALA_MIUDO := 4.0
const MIUDO_LIVRE := Vector2(2.0, 6.0)


## Altura do no (i, j), com a praca em 0. Sem nivelamento nenhum: o parque, o
## aterro da avenida e o patamar sao do Relevo.
static func bruto(i: int, j: int) -> float:
	var p := Vector2(float(i), float(j))
	var d_matriz := p.distance_to(MATRIZ)
	var alto := _perfil(d_matriz, ALTURA_MATRIZ, RAIO_MATRIZ, TOPO_MATRIZ)
	var ci := floori(p.x / CELULA)
	var cj := floori(p.y / CELULA)
	for dj in range(-1, 2):
		for di in range(-1, 2):
			var m := _morro(ci + di, cj + dj)
			if m.z <= 0.0:
				continue
			alto = maxf(alto, _perfil(p.distance_to(Vector2(m.x, m.y)), m.z, m.w, 0.0))
	var miudo := MIUDO * Relevo._valor(p.x / ESCALA_MIUDO, p.y / ESCALA_MIUDO, 41) \
		* smoothstep(MIUDO_LIVRE.x, MIUDO_LIVRE.y, d_matriz)
	return alto + miudo - ALTURA_MATRIZ


## O morro da celula (a, b): centro em chunks, altura e raio em chunks. Publica
## para o mapa e para o mirante saberem onde fica o alto de cada bairro.
static func morro(a: int, b: int) -> Dictionary:
	var m := _morro(a, b)
	return {"centro": Vector2(m.x, m.y), "altura": m.z, "raio": m.w}


## O mesmo, sem alocar: x e y o centro, z a altura, w o raio. `bruto` chama
## isto nove vezes por no, e o no de avenida chama `bruto` catorze vezes.
static func _morro(a: int, b: int) -> Vector4:
	var centro := (Vector2(float(a), float(b)) + Vector2(
		lerpf(MARGEM, 1.0 - MARGEM, _sorteio(a, b, 1)),
		lerpf(MARGEM, 1.0 - MARGEM, _sorteio(a, b, 2)))) * CELULA
	var altura := lerpf(ALTURA_MORRO.x, ALTURA_MORRO.y, _sorteio(a, b, 3))
	var raio := lerpf(RAIO_MORRO.x, RAIO_MORRO.y, _sorteio(a, b, 4)) * CELULA
	altura *= smoothstep(RAIO_MATRIZ * LIVRE_DA_MATRIZ.x, RAIO_MATRIZ * LIVRE_DA_MATRIZ.y,
		centro.distance_to(MATRIZ))
	return Vector4(centro.x, centro.y, altura, raio)


## O no esta no topo plano da matriz?
static func _no_topo(i: int, j: int) -> bool:
	return Vector2(float(i), float(j)).distance_to(MATRIZ) <= TOPO_MATRIZ


## Morro em cosseno: `altura` ate `topo`, zero a partir de `raio`.
static func _perfil(d: float, altura: float, raio: float, topo: float) -> float:
	var t := clampf((d - topo) / maxf(raio - topo, 0.01), 0.0, 1.0)
	return altura * 0.5 * (1.0 + cos(PI * t))


static func _sorteio(a: int, b: int, sal: int) -> float:
	return float(MalhaUrbana._ruido(a, b, 5000 + sal) % 10001) / 10000.0
