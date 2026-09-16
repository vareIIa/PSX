## Os vidros da cabine: uma malha, um material, e o espaco em METROS que a agua
## precisa.
##
## Por que isto existe
## -------------------
## A agua do para-brisa era um quadrado de 1,78 x 1,06 m preso SESSENTA
## CENTIMETROS A FRENTE DO OLHO e virado para ele. Nao era o vidro: era uma tela
## entre a lente e o mundo. Medido em 16/09/2026, ela desenhava agua em 21 a 47%
## do quadro onde nao havia vidro nenhum — sobre a porta, sobre a coluna e sobre
## o buraco da lataria — e, por ser perpendicular a camera, a gota saia redonda
## num vidro inclinado a 60 graus.
##
## Aqui o vidro e o vidro: cada abertura da lataria (`AberturasVidro`) vira uma
## placa no lugar dela, com a inclinacao dela. A agua passa a obedecer a
## profundidade, a perspectiva e o balanco da cabine de graca, porque ela esta
## presa ao carro e nao a camera.
##
## O que a malha carrega
## ---------------------
## Uma malha so, um material so — o vidro inteiro custa uma chamada de desenho.
## O que muda de uma janela para outra viaja nos atributos do vertice:
##
##   UV    posicao no MAPA DE AGUA (`AguaVidro`), ja dentro do retangulo deste
##         vidro. Sem mapa, e a posicao normalizada na propria placa.
##   UV2   posicao em METROS no plano do vidro: `u` atravessa, `v` desce
##   COLOR r = tem limpador, g = tipo, b e a = o tamanho do vidro em metros
##         dividido por `ESCALA_TAM`
##
## O tamanho viaja na cor porque o fragmento precisa dele para saber onde e a
## borda do vidro (o embacado e mais forte no canto) agora que a UV foi para o
## mapa — e porque assim nao e preciso um atributo `CUSTOM` a mais, com um
## formato de vertice a mais para dar errado em silencio num dos dois
## renderizadores.
##
## `v` apontando morro abaixo e o que faz a gravidade ser a mesma conta em todo
## vidro, inclinado ou nao. E o metro e o que faz a gota ter TAMANHO: a mesma
## grade de 9 mm no para-brisa e no quebra-vento, em vez de uma grade por placa
## que muda de tamanho junto com a janela.
class_name VidroCabine
extends RefCounted

const SHADER := "res://shaders/psx_vidro_agua.gdshader"

## Quanto o vidro da cabine recua para dentro do vidro da lataria.
##
## O vidro de fora e um decalque colado na chapa e virado para FORA; de dentro
## ele e descartado pelo `cull_back`, entao nao ha o que ver ali. Quatro
## milimetros para dentro garantem que, de FORA, quem ganha o pixel continua
## sendo o decalque da lataria — sem os dois brigarem.
const RECUO := 0.004

## Passo de subdivisao, em metros. A UV afim do PS1 escorrega em quad grande, e
## aqui ela carrega a posicao da agua: um para-brisa inteiro num quad so faria a
## gota escorregar junto com a camera.
const PASSO := 0.30

## Divisor do tamanho que viaja em COLOR.ba. Nenhum vidro de carro passa disto,
## e a cor de vertice so vai de 0 a 1.
const ESCALA_TAM := 8.0

## Tipos de abertura que recebem vidro, e o codigo de cada um.
const TIPOS := {
	&"parabrisa": 0.0,
	&"quebra_vento": 0.5,
	&"porta_frente": 0.5,
	&"porta_tras": 0.5,
	&"fixa_tras": 0.5,
	&"vigia": 1.0,
}


## O referencial de cada vidro, sem malha nenhuma.
##
## Vem antes da malha porque o mapa de agua precisa dos TAMANHOS para empacotar
## os retangulos, e a malha precisa dos retangulos para escrever o UV. Tentar
## fazer as duas coisas numa passada so e o ovo e a galinha.
##
## Cada painel traz origem, eixo `u` (atravessa), eixo `v` (morro abaixo),
## normal e tamanho em metros — que e o que o limpador precisa para girar NO
## PLANO do vidro e o que a corredora precisa para ter fisica.
static func referenciais(aberturas: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a: Dictionary in aberturas:
		if not TIPOS.has(a["tipo"]):
			continue
		var r := _referencial(a)
		if not r.is_empty():
			out.append(r)
	return out


static func _referencial(a: Dictionary) -> Dictionary:
	var p: PackedVector3Array = a["pontos"]
	if p.size() < 4:
		return {}
	var n: Vector3 = a["normal"]
	if n.length_squared() < 0.5:
		return {}
	var dentro := -n * RECUO
	var q := [p[0] + dentro, p[1] + dentro, p[2] + dentro, p[3] + dentro]

	# O eixo V desce: a projecao da vertical no plano do vidro. Num vidro
	# deitado (nao ha nenhum, mas o codigo nao pode explodir) ele degenera, e ai
	# vale a aresta de baixo.
	var v_eixo := (Vector3.DOWN - n * Vector3.DOWN.dot(n))
	if v_eixo.length_squared() < 1e-6:
		v_eixo = (q[1] - q[0]).normalized()
	v_eixo = v_eixo.normalized()
	var u_eixo := v_eixo.cross(n).normalized()
	# Para o lado: no para-brisa e no vigia, `u` cresce para a direita do carro;
	# na janela lateral, para a TRASEIRA — e assim o vento deita a agua sempre
	# no mesmo sentido de `u`, sem um "se" por lado.
	var lateral := absf(n.x) > 0.5
	var referencia := Vector3.BACK if lateral else Vector3.RIGHT
	if u_eixo.dot(referencia) < 0.0:
		u_eixo = -u_eixo

	var origem: Vector3 = q[0]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for ponto: Vector3 in q:
		var d: Vector3 = ponto - origem
		var m := Vector2(d.dot(u_eixo), d.dot(v_eixo))
		lo = lo.min(m)
		hi = hi.max(m)
	var tam := hi - lo
	if tam.x < 0.01 or tam.y < 0.01:
		return {}

	return {
		"tipo": a["tipo"],
		"lado": a["lado"],
		# A origem do referencial e o canto de menor (u, v), e nao o primeiro
		# ponto: e dela que UV2 e medido.
		"origem": origem + u_eixo * lo.x + v_eixo * lo.y,
		"u": u_eixo,
		"v": v_eixo,
		"normal": n,
		"tam": tam,
		"cantos": q,
		"lo": lo,
		"exposicao": _exposicao(n),
		"limpador": 1.0 if a["tipo"] == &"parabrisa" else 0.0,
	}


## Quanto deste vidro a chuva alcanca, de 0 a 1.
##
## A chuva cai de cima e o carro anda para a frente: o vidro recebe agua na
## medida em que ele olha para cima e para a frente. E por isso que o para-brisa
## enche e o quebra-vento nao — e por isso que o motorista acelera o limpador na
## estrada e nao na cidade, sem ninguem escrever "na estrada, acelerar".
static func _exposicao(n: Vector3) -> float:
	var para_cima := maxf(0.0, n.y)
	# A frente do carro e -Z no espaco final.
	var para_frente := maxf(0.0, -n.z)
	return clampf(0.28 + 0.55 * para_cima + 0.45 * para_frente, 0.0, 1.0)


## Monta a malha dos vidros. `rects` e o retangulo de cada painel no mapa de
## agua, na mesma ordem; vazio faz cada vidro usar o proprio 0..1.
static func montar(paineis: Array, rects: Array[Rect2] = []) -> ArrayMesh:
	if paineis.is_empty():
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in paineis.size():
		var r := rects[i] if i < rects.size() else Rect2(0.0, 0.0, 1.0, 1.0)
		_emitir(st, paineis[i], r)
	# Tangente: a optica da gota precisa levar a normal do relevo da agua para o
	# espaco de visao, e sem tangente nao ha esse caminho.
	st.generate_tangents()
	return st.commit()


static func _emitir(st: SurfaceTool, painel: Dictionary, rect: Rect2) -> void:
	var q: Array = painel["cantos"]
	var origem: Vector3 = painel["origem"]
	var u_eixo: Vector3 = painel["u"]
	var v_eixo: Vector3 = painel["v"]
	var n: Vector3 = painel["normal"]
	var tam: Vector2 = painel["tam"]
	var tipo: float = TIPOS[painel["tipo"]]
	var cor := Color(painel["limpador"], tipo, tam.x / ESCALA_TAM,
		tam.y / ESCALA_TAM)
	var cols := maxi(1, ceili(maxf((q[0] as Vector3).distance_to(q[1]),
		(q[3] as Vector3).distance_to(q[2])) / PASSO))
	var linhas := maxi(1, ceili(maxf((q[0] as Vector3).distance_to(q[3]),
		(q[1] as Vector3).distance_to(q[2])) / PASSO))
	for i in linhas:
		for j in cols:
			var a0: Vector3 = _canto(q, float(j) / cols, float(i) / linhas)
			var a1: Vector3 = _canto(q, float(j + 1) / cols, float(i) / linhas)
			var a2: Vector3 = _canto(q, float(j + 1) / cols, float(i + 1) / linhas)
			var a3: Vector3 = _canto(q, float(j) / cols, float(i + 1) / linhas)
			# O giro sai do OLHO da cabine: a placa tem de aparecer para quem
			# esta dentro. Ver a memoria "giro de face aponta ao contrario".
			for canto: Vector3 in [a0, a1, a2, a0, a2, a3]:
				var d: Vector3 = canto - origem
				var m := Vector2(d.dot(u_eixo), d.dot(v_eixo))
				var f := Vector2(m.x / tam.x, m.y / tam.y)
				st.set_normal(-n)
				st.set_color(cor)
				st.set_uv(rect.position + f * rect.size)
				st.set_uv2(m)
				st.add_vertex(canto)


## Ponto dentro do quadrilatero, por interpolacao bilinear.
static func _canto(q: Array, fx: float, fy: float) -> Vector3:
	return (q[0] as Vector3).lerp(q[1], fx).lerp((q[3] as Vector3).lerp(q[2], fx), fy)


## O material do vidro, com o shader da agua.
static func material() -> ShaderMaterial:
	if not ResourceLoader.exists(SHADER):
		push_error("VidroCabine: shader ausente em %s" % SHADER)
		return null
	var m := ShaderMaterial.new()
	m.shader = load(SHADER) as Shader
	return m
