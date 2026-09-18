## Onde ficam os VIDROS de um carro, no espaco final da lataria.
##
## Por que isto existe
## -------------------
## O vidro de fora e o vidro de dentro tem de ser o MESMO vidro. Ate aqui nao
## eram: cada modulo de lataria (Marea, Fusca, Caixa) desenhava as janelas da
## propria tabela, e a `CarroCabine` desenhava um trapezio chutado da coluna A
## ate a coluna B. Medido em 16/09/2026, o resultado era vidro da cabine sobre
## CHAPA em 3 a 8% do quadro, e no Fusca 25% de janela da lataria sem vidro
## nenhum por dentro (`tests/medir_cabine_cobertura.gd`).
##
## Este arquivo nao tem tabela: ele so sabe a MATEMATICA. Cada modulo continua
## dono dos proprios vaos e chama daqui, de modo que a abertura devolvida sai
## dos mesmos numeros que desenharam o vidro. Divergir virou impossivel, e nao
## so improvavel.
##
## Sistema de coordenadas
## ----------------------
## Os modulos trabalham com +Z na frente, que e como se desenha um carro
## olhando para ele, e `Carroceria.montar` da meia volta no fim, porque o motor
## aponta para -Z. As funcoes daqui recebem ponto de modulo e devolvem ponto
## FINAL — ja escalado e ja virado — que e o espaco em que a cabine, a camera e
## a fisica vivem.
class_name AberturasVidro
extends RefCounted

## Nomes de vao por posicao na tabela, conforme quantos vaos o carro tem. A
## picape so tem dois (cabine curta), o Fusca e os hatches tem tres, e um sedan
## de quatro portas tem quatro.
const NOMES_2 := [&"quebra_vento", &"porta_frente"]
const NOMES_3 := [&"quebra_vento", &"porta_frente", &"fixa_tras"]
const NOMES_4 := [&"quebra_vento", &"porta_frente", &"porta_tras", &"fixa_tras"]


static func nomes(quantos: int) -> Array:
	match quantos:
		2:
			return NOMES_2
		4:
			return NOMES_4
		_:
			return NOMES_3


## Os quatro cantos de uma janela lateral, como o modulo a desenha: os cantos do
## vao no flanco, deslocados `folga` para FORA (o vidro e um recorte colado, e
## nao um buraco na chapa).
##
## `vao` e [z0, z1, t0, t1], com t indo da cintura ao topo — a mesma tupla que
## as tabelas `vaos` dos modulos usam.
static func lado(perfil: Array, ombro: Vector2, vao: Array, s: float,
		folga: float) -> PackedVector3Array:
	var d := Vector3(s, 0.0, 0.0) * folga
	return PackedVector3Array([
		CarroceriaVarrida.ponto_lado(perfil, ombro, vao[0], vao[2], s) + d,
		CarroceriaVarrida.ponto_lado(perfil, ombro, vao[1], vao[2], s) + d,
		CarroceriaVarrida.ponto_lado(perfil, ombro, vao[1], vao[3], s) + d,
		CarroceriaVarrida.ponto_lado(perfil, ombro, vao[0], vao[3], s) + d,
	])


## Onde um vao lateral e cortado: as duas pontas e toda estacao do perfil que
## cai entre elas, na ordem de `vao[0]` para `vao[1]`.
##
## Por que cortar
## --------------
## A lataria e interpolada em linha reta ENTRE estacoes, e dobra NAS estacoes.
## Um vidro de quatro cantos que atravessa uma estacao tem a aresta de cima reta,
## enquanto o recorte da casca de dentro segue a dobra do teto: na fresta entre
## os dois o olho ve chapa por dentro. Medido em 17/09/2026, quando a porta do
## sedan passou a comecar sob a coluna A: 1,0% de buraco a 35 graus e 1,7% a 60
## (eram 0,2% e 0,6%, pelo mesmo motivo e com a porta mais curta).
static func cortes(perfil: Array, vao: Array) -> PackedFloat32Array:
	var z0 := float(vao[0])
	var z1 := float(vao[1])
	var dentro: Array[float] = []
	for e: Array in perfil:
		var z := float(e[0])
		if z < maxf(z0, z1) - 0.005 and z > minf(z0, z1) + 0.005:
			dentro.append(z)
	# Da ponta z0 para a ponta z1, qualquer que seja o sentido.
	if z0 > z1:
		dentro.sort_custom(func(a: float, b: float) -> bool: return a > b)
	else:
		dentro.sort()
	var out := PackedFloat32Array([z0])
	for z: float in dentro:
		out.append(z)
	out.append(z1)
	return out


## O contorno de um vao lateral, com um vertice em cada corte: a aresta de baixo
## de `vao[0]` a `vao[1]`, e a de cima de volta. E o vidro que a lataria
## desenha — os quatro cantos de `lado` sao so as pontas dele.
static func contorno(perfil: Array, ombro: Vector2, vao: Array, s: float,
		folga: float) -> PackedVector3Array:
	var d := Vector3(s, 0.0, 0.0) * folga
	var zs := cortes(perfil, vao)
	var out := PackedVector3Array()
	for z: float in zs:
		out.append(CarroceriaVarrida.ponto_lado(perfil, ombro, z, vao[2], s) + d)
	for k in range(zs.size() - 1, -1, -1):
		out.append(CarroceriaVarrida.ponto_lado(perfil, ombro, zs[k], vao[3], s) + d)
	return out


## Os quatro cantos do para-brisa ou do vigia: a face de cima entre duas
## estacoes do perfil, encolhida por `recuo` (a moldura de lataria em volta do
## vidro) e deslocada `folga` para fora.
static func frontal(perfil: Array, k: int, recuo: float,
		folga: float) -> PackedVector3Array:
	var za: float = perfil[k][0]
	var zb: float = perfil[k + 1][0]
	var ea: Array = (perfil[k] as Array).slice(1)
	var eb: Array = (perfil[k + 1] as Array).slice(1)
	var q0 := Vector3(-ea[5], ea[2], za)
	var q1 := Vector3(ea[5], ea[2], za)
	var q2 := Vector3(eb[5], eb[2], zb)
	var q3 := Vector3(-eb[5], eb[2], zb)
	var i := CarroceriaVarrida.inset(q0, q1, q2, q3, recuo)
	var d := CarroceriaVarrida.normal_placa(q0, q1, q3) * folga
	return PackedVector3Array([i[0] + d, i[1] + d, i[2] + d, i[3] + d])


## Uma abertura pronta para quem constroi o interior.
##
##   tipo     quebra_vento, porta_frente, porta_tras, fixa_tras, parabrisa, vigia
##   lado     -1 esquerda, +1 direita, 0 no meio (para-brisa e vigia)
##   pontos   quatro cantos no espaco FINAL do carro
##   normal   para fora, no espaco final
##   centro   media dos quatro cantos, no espaco final
##   folga    quanto o vidro esta colado por fora da chapa, em metros
##   area     em metros quadrados, util para repartir o mapa de agua
##   contorno o vidro inteiro, com um vertice em cada estacao do perfil que a
##            janela atravessa (ver `cortes`). Igual a `pontos` quando nao ha
##            nenhuma.
##
## `lado` sai da GEOMETRIA, e nao do `s` de quem chamou: o `s` do modulo vale
## antes da meia volta, e a meia volta troca esquerda por direita. Passado
## adiante como veio, ele poria a maçaneta na porta do passageiro.
static func registro(tipo: StringName, _lado_do_modulo: int,
		pontos: PackedVector3Array, escala: Vector3,
		folga: float, borda := PackedVector3Array()) -> Dictionary:
	var finais := finalizar(pontos, escala)
	var contorno_final := finalizar(borda, escala) if not borda.is_empty() else finais
	var n := Vector3.ZERO
	var centro := Vector3.ZERO
	var lado := 0
	if finais.size() >= 4:
		centro = (finais[0] + finais[1] + finais[2] + finais[3]) * 0.25
		# Meia largura de carro e uns 0,8 m: 0,15 separa janela de lateral de
		# para-brisa sem chance de empate.
		lado = signi(int(round(centro.x * 100.0))) if absf(centro.x) > 0.15 else 0
		# Mesma regra de `normal_placa`, mas sem forcar para cima: aqui a janela
		# lateral aponta para o lado.
		n = (finais[1] - finais[0]).cross(finais[3] - finais[0])
		n = n.normalized() if n.length_squared() > 1e-12 else Vector3.ZERO
		if n.dot(Vector3(centro.x, 0.0, 0.0) if lado != 0 else Vector3.UP) < 0.0:
			n = -n
	return {
		"tipo": tipo,
		"lado": lado,
		"pontos": finais,
		"normal": n,
		"centro": centro,
		"folga": folga,
		"area": area(finais),
		"contorno": contorno_final,
	}


## Escala do modulo e a meia volta de `Carroceria.montar`, nesta ordem. Sem a
## meia volta, tudo o que sair daqui nasce apontando para a traseira.
static func finalizar(pontos: PackedVector3Array,
		escala: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p: Vector3 in pontos:
		var q := p * escala
		out.append(Vector3(-q.x, q.y, -q.z))
	return out


## Area do quadrilatero, pelos dois triangulos.
static func area(p: PackedVector3Array) -> float:
	if p.size() < 4:
		return 0.0
	return (((p[1] - p[0]).cross(p[2] - p[0])).length()
		+ ((p[2] - p[0]).cross(p[3] - p[0])).length()) * 0.5
