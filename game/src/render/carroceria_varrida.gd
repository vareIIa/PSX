## Ferramenta de carro varrido: perfil em Z, seccao em anel, e o giro certo.
##
## Nasceu inteira dentro do Fusca. Quando o Marea chegou, ou isto virava modulo
## ou eram duzentas e trinta linhas copiadas — e a copia levaria junto a
## CONVENCAO DE GIRO documentada em `quad`, que e o tipo de regra que, existindo
## em dois arquivos, diverge no primeiro dia em que alguem mexer num deles.
##
## O que mora aqui e o que nao depende de QUAL carro:
##
##   * as primitivas de malha (quad, tri, plana, disco) e o giro correto;
##   * a leitura do perfil — dado um Z, onde esta a lataria — que e o que
##     permite POSICIONAR detalhe na superficie em vez de chutar no espaco;
##   * a varredura do casco.
##
## O que NAO mora aqui e a tabela de perfil e as pecas aparafusadas (para-lama,
## grade, farol, para-choque): e ali que Fusca e Marea sao carros diferentes.
## Um besouro e uma abobada com para-lamas por fora; um sedan tres-volumes e uma
## caixa cuja lateral ja E a largura toda. Mesma maquina, tabelas opostas.
##
## Depende de Carroceria (celulas do atlas, uv). Carroceria NAO depende disto —
## ela resolve fusca/marea em runtime, o que e o que impede a referencia ciclica
## que derruba a compilacao do projeto inteiro.
class_name CarroceriaVarrida
extends RefCounted

## Colunas do perfil, depois de tirar o Z.
const BOT := 0
const CINT := 1
const TOPO := 2
const W_BOT := 3
const W_CINT := 4
const W_TOPO := 5


# --------------------------------------------------------------------------
# Ler o perfil
# --------------------------------------------------------------------------

## Interpola a estacao do perfil num Z qualquer.
##
## `perfil` anda da FRENTE para tras, entao z desce com o indice.
static func estacao(perfil: Array, z: float) -> Array:
	var n := perfil.size()
	if z >= perfil[0][0]:
		return (perfil[0] as Array).slice(1)
	if z <= perfil[n - 1][0]:
		return (perfil[n - 1] as Array).slice(1)
	for k in n - 1:
		var a: Array = perfil[k]
		var b: Array = perfil[k + 1]
		if z <= a[0] and z >= b[0]:
			var t: float = (a[0] - z) / (a[0] - b[0])
			var r: Array = []
			for j in range(1, 7):
				r.append(lerpf(a[j], b[j], t))
			return r
	return (perfil[n - 1] as Array).slice(1)


## Meia-largura e altura da seccao num `t`.
##
## `t` vai de -1 (assoalho) por 0 (cintura) ate 1 (topo). O ponto do OMBRO nao
## esta na tabela: e derivado de `ombro` = (fracao de altura, fracao de largura).
## A defasagem entre as duas e o que arqueia a seccao — 0.66/0.34 da a cupula do
## Fusca, 0.80/0.20 da a lateral quase reta de um sedan com so um chanfro no
## encontro com o teto.
##
## Toda consulta passa por aqui, e nao por uma reta da cintura ao topo. Com a
## reta, todo detalhe acima da cintura cai DENTRO da lataria: no Fusca as tres
## janelas de cada lado sumiram inteiras, engolidas pela barriga do ombro.
static func secao(e: Array, t: float, ombro: Vector2) -> Vector2:
	if t < 0.0:
		return Vector2(lerpf(e[W_CINT], e[W_BOT], -t), lerpf(e[CINT], e[BOT], -t))
	var w_omb: float = lerpf(e[W_CINT], e[W_TOPO], ombro.y)
	var y_omb: float = lerpf(e[CINT], e[TOPO], ombro.x)
	if t <= ombro.x:
		var k: float = t / ombro.x
		return Vector2(lerpf(e[W_CINT], w_omb, k), lerpf(e[CINT], y_omb, k))
	var k2: float = (t - ombro.x) / (1.0 - ombro.x)
	return Vector2(lerpf(w_omb, e[W_TOPO], k2), lerpf(y_omb, e[TOPO], k2))


## Ponto na lateral do casco. `s` e o lado (+1 / -1).
static func ponto_lado(perfil: Array, ombro: Vector2, z: float, t: float,
		s: float) -> Vector3:
	var wy := secao(estacao(perfil, z), t, ombro)
	return Vector3(s * wy.x, wy.y, z)


## Ponto na superficie de cima. `u` de -1 a 1 atravessa o carro.
static func ponto_topo(perfil: Array, z: float, u: float) -> Vector3:
	var e := estacao(perfil, z)
	return Vector3(u * e[W_TOPO], e[TOPO], z)


## Normal da superficie de cima num Z, para descolar friso e veneziana da
## lataria sem que afundem quando o painel sobe.
static func normal_topo(perfil: Array, z: float) -> Vector3:
	var d := 0.04
	var a := estacao(perfil, z + d)
	var b := estacao(perfil, z - d)
	return Vector3(0.0, 2.0 * d, -(a[TOPO] - b[TOPO])).normalized()


## Base orientada com a superficie de cima, para grudar peca chapada nela.
static func base_topo(perfil: Array, z: float) -> Basis:
	var n := normal_topo(perfil, z)
	return Basis(Vector3.RIGHT, n.cross(Vector3.RIGHT).normalized(), n)


## Meia-largura do casco numa altura. Busca por amostragem porque a relacao
## y->t deixou de ser linear quando o ombro entrou, e resolver na mao dava X
## errado no pe do para-lama — que e onde qualquer fresta abre para dentro.
## Meia largura do casco numa altura, achada por BISSECCAO.
##
## `x_casco` responde a mesma pergunta amostrando treze `t` e ficando com o mais
## proximo: o bastante para posicionar friso e arco de roda, e grosseiro demais
## para quem precisa ENCOSTAR na chapa por dentro — nas partes curvas o erro
## chega a dez centimetros, e era por ele que o forro de porta do Fusca nascia
## atravessando a lateral. Quem monta interior usa esta.
static func x_casco_fino(perfil: Array, ombro: Vector2, z: float,
		y: float) -> float:
	var e := estacao(perfil, z)
	var a := -1.0
	var b := 1.0
	if y <= secao(e, a, ombro).y:
		return secao(e, a, ombro).x
	if y >= secao(e, b, ombro).y:
		return secao(e, b, ombro).x
	for i in 28:
		var meio := (a + b) * 0.5
		if secao(e, meio, ombro).y < y:
			a = meio
		else:
			b = meio
	return secao(e, (a + b) * 0.5, ombro).x


static func x_casco(perfil: Array, ombro: Vector2, z: float, y: float) -> float:
	var e := estacao(perfil, z)
	if y < e[CINT]:
		var t2: float = clampf(inverse_lerp(e[CINT], e[BOT], y), 0.0, 1.0)
		return lerpf(e[W_CINT], e[W_BOT], t2)
	var melhor := 0.0
	var dist := INF
	for k in 13:
		var t := float(k) / 12.0
		var wy := secao(e, t, ombro)
		var d: float = absf(wy.y - y)
		if d < dist:
			dist = d
			melhor = t
	return secao(e, melhor, ombro).x


# --------------------------------------------------------------------------
# Varrer o casco
# --------------------------------------------------------------------------

## O anel de oito pontos de uma estacao, em ordem de volta.
static func anel(e: Array, ombro: Vector2) -> Array:
	var o := secao(e, ombro.x, ombro)
	return [
		Vector3(-e[W_BOT], e[BOT], 0.0), Vector3(e[W_BOT], e[BOT], 0.0),
		Vector3(e[W_CINT], e[CINT], 0.0), Vector3(o.x, o.y, 0.0),
		Vector3(e[W_TOPO], e[TOPO], 0.0), Vector3(-e[W_TOPO], e[TOPO], 0.0),
		Vector3(-o.x, o.y, 0.0), Vector3(-e[W_CINT], e[CINT], 0.0),
	]


## Quanto a borda do vao da janela dobra para dentro: a espessura da porta.
##
## Sem ela o vao e um corte de papel. Com o vidro transparente do MODERNO, o
## olho que passa rente a janela ve a chapa sem espessura nenhuma, e o carro le
## como maquete de cartolina.
const FUNDO_VAO := 0.035
const BORRACHA_VAO := Color(0.07, 0.07, 0.075)

## Vinco de porta, de capo e de tampa, como SULCO na chapa (PLANO_CARROS_AAA, F6).
##
## Antes eram faixas pretas de 2,4 cm coladas um centimetro por fora da lataria.
## Com o vidro, a tinta e o verniz do MODERNO elas liam como o que eram — risco
## de caneta — e o jogador reportou "carros cheios de rabiscos e sem
## profundidade real da porta". Agora a chapa afunda em V: dez milimetros de
## boca, seis de fundo. Os dois lados do V pegam luz diferente, e isso e a
## fresta de verdade em qualquer angulo; o fundo leva a sombra de oclusao assada
## no vertice, que e o que a mantem legivel quando o sulco fica abaixo de um
## pixel.
const VINCO_MEIA := 0.005
const VINCO_FUNDO := 0.006
const VINCO_ESCURO := 0.30
## Entrada e saida do vinco, na unidade do parametro (t da secao ou z).
const VINCO_RAMPA := 0.02
## Caixa de roda: o fundo do para-lama interno.
const CAVA := Color(0.11, 0.10, 0.09)
## Quanto a aba do arco sobe da chapa e quanto ela se afasta do contorno.
const ABA_ALTA := 0.009
const ABA_LARGA := 0.05

## Casco de longe (PLANO_CARROS_AAA, F9): sem vinco, sem caixa de roda, sem
## friso nem macaneta com volume. Quem liga e `Carroceria._casco_em_dados` em
## volta da montagem da versao de longe; a vinte e oito metros, na nevoa, um
## sulco de um centimetro e um puxador de doze sao menos que um pixel.
static var simples := false


## Varre o perfil: flancos, topo e assoalho em grade, mais as tampas do bico e
## do rabo.
##
## `tinta` recebe a altura e devolve a cor — e por onde entra a sujeira que sobe
## do barro na soleira ao creme no teto.
##
## `vaos` e `frontais` abrem as janelas no casco (PLANO_CARROS_AAA, F1). Sao as
## MESMAS tabelas que desenham o vidro por fora: `vaos` em (z0, z1, t0, t1) como
## `VAOS_LADO`, e `frontais` em [indice do trecho, recuo] como o para-brisa e o
## vigia. Antes o casco era fechado e o vidro uma placa opaca colada por cima;
## com vidro transparente, o que aparecia atras dele era a propria lataria.
##
## `vincos` recorta a chapa (PLANO_CARROS_AAA, F6):
##
##   "lado"    [[z, t0, t1], ...]   vinco vertical nos dois flancos
##   "lado_h"  [[t, z0, z1], ...]   vinco horizontal nos dois flancos (z0 > z1)
##   "topo"    [[u, z0, z1], ...]   vinco longitudinal no topo, em +u e -u
##   "topo_x"  [[z, u], ...]        vinco transversal no topo, de -u a +u
##   "arcos"   [{"contorno": PackedVector2Array (z, y), "x_dentro": float,
##               "centro": Vector2 (z, y)}, ...]
##             caixa de roda aberta no flanco, com para-lama interno. Ver
##             `contorno_arco`.
##
## A grade e CONFORME onde a batida acontece (PLANO_CARROS_AAA, F8)
## -----------------------------------------------------------------
## Nenhum vertice pode cair no meio da aresta de um vizinho. Na chapa lisa essa
## "junta em T" nao aparece — o vertice esta em cima da reta —, mas o amassado
## desloca o vertice e a aresta do vizinho continua reta: abre uma fresta, e o
## fundo aparece por ela. A primeira grade de vinco tinha isso na altura do
## para-choque, e a porta amassada saia com um triangulo de ceu na soleira.
##
## Por isso: um conjunto so de cortes em z por trecho, usado pelos dois flancos,
## pelo topo e pelo assoalho; os cortes em t da faixa de baixo (soleira ->
## cintura) e os cortes em u do topo sao os mesmos no carro inteiro; as tampas
## do bico e do rabo sao montadas com os vertices da borda da grade; e a coluna
## que passa por cima de uma roda prende os cantos no arco em vez de pular os
## cortes. A faixa de cima (cintura -> teto) continua com cortes por trecho —
## as janelas mudam de um trecho para o outro, e batida la em cima e rara.
static func casco(dados: Dictionary, perfil: Array, ombro: Vector2,
		celula: Vector2i, tinta: Callable, pular_topo_z: float = -1000.0,
		tampa_tras: bool = true, vaos: Array = [], frontais: Array = [],
		vincos: Dictionary = {}) -> void:
	var n := perfil.size()
	var recuo_frontal := {}
	for f: Array in frontais:
		var kf: int = f[0]
		if kf >= 0 and kf + 1 < n:
			recuo_frontal[kf] = float(f[1])
	if simples:
		vincos = {}
	var arcos: Array = vincos.get("arcos", [])
	var verticais: Array = vincos.get("lado", [])
	var horizontais: Array = vincos.get("lado_h", [])
	var longos: Array = vincos.get("topo", [])
	var travessas: Array = vincos.get("topo_x", [])
	var e_meio := estacao(perfil, (float(perfil[0][0]) + float(perfil[n - 1][0])) * 0.5)
	var tc_baixo := _cortes_baixo(verticais, horizontais, e_meio, ombro)
	# Os cortes em u valem por REGIAO do topo — capo, teto, tampa —, e nao pelo
	# carro inteiro: as regioes sao separadas pela moldura do para-brisa e do
	# vigia, que nao e grade, entao entre elas nao ha junta a casar. Com os
	# cortes do capo atravessando o teto, o sedan ia de 2,9 mil para 5,5 mil
	# triangulos de lataria.
	var uc_por_trecho: Array = []
	uc_por_trecho.resize(n - 1)
	var k0 := 0
	while k0 < n - 1:
		if recuo_frontal.has(k0):
			uc_por_trecho[k0] = [-1.0, 1.0]
			k0 += 1
			continue
		var k1 := k0
		while k1 + 1 < n - 1 and not recuo_frontal.has(k1 + 1):
			k1 += 1
		var z_de: float = perfil[k0][0]
		var z_ate: float = perfil[k1 + 1][0]
		var longos_aqui: Array = []
		for g: Array in longos:
			if float(g[2]) < z_de - 1e-4 and float(g[1]) > z_ate + 1e-4:
				longos_aqui.append(g)
		var travessas_aqui: Array = []
		for g: Array in travessas:
			if float(g[0]) <= z_de + 1e-4 and float(g[0]) >= z_ate - 1e-4:
				travessas_aqui.append(g)
		var uc_regiao := _cortes_topo(longos_aqui, travessas_aqui, e_meio)
		for k in range(k0, k1 + 1):
			uc_por_trecho[k] = uc_regiao
		k0 = k1 + 1
	var tc_bico: Array = []
	var tc_rabo: Array = []
	for k in n - 1:
		var uc: Array = uc_por_trecho[k]
		var ea: Array = (perfil[k] as Array).slice(1)
		var eb: Array = (perfil[k + 1] as Array).slice(1)
		var za: float = perfil[k][0]
		var zb: float = perfil[k + 1][0]
		var eixo_m := Vector3(0.0,
			(float(ea[BOT]) + float(ea[TOPO]) + float(eb[BOT]) + float(eb[TOPO])) * 0.25,
			(za + zb) * 0.5)
		var vaos_aqui := _vaos_no_trecho(vaos, za, zb)
		var zc := _cortes_z(za, zb, vaos_aqui, verticais, horizontais, arcos,
			longos, travessas)
		var tc := _cortes_t(tc_baixo, ombro, za, zb, vaos_aqui, verticais)
		if k == 0:
			tc_bico = tc
		if k == n - 2:
			tc_rabo = tc
		# O assoalho e a unica faixa que ninguem ve de perto: vai escura para
		# nao devolver luz de baixo e denunciar que o carro e oco.
		_assoalho(dados, perfil, zc, arcos, tinta)
		# A picape pula o topo na cacamba para o vao ficar aberto, e nao virar
		# um teto de perua.
		if (za + zb) * 0.5 > pular_topo_z:
			if recuo_frontal.has(k):
				var ra := anel(ea, ombro)
				var rb := anel(eb, ombro)
				var q0: Vector3 = ra[4] + Vector3(0, 0, za)
				var q1: Vector3 = ra[5] + Vector3(0, 0, za)
				var q2: Vector3 = rb[5] + Vector3(0, 0, zb)
				var q3: Vector3 = rb[4] + Vector3(0, 0, zb)
				var fora := ((q0 + q1 + q2 + q3) * 0.25 - eixo_m).normalized()
				_moldura(dados, q0, q1, q2, q3, float(recuo_frontal[k]), celula,
					tinta, fora)
			else:
				_topo(dados, perfil, zc, uc, longos, travessas, celula, tinta,
					eixo_m)
		for s: float in [1.0, -1.0]:
			_flanco(dados, perfil, ombro, zc, tc, s, vaos_aqui, verticais,
				horizontais, arcos, celula, tinta, eixo_m)
	for a: Dictionary in arcos:
		for s: float in [1.0, -1.0]:
			_caixa_de_roda(dados, perfil, ombro, a, s, celula, tinta)
	_tampa_conforme(dados, perfil, ombro, 0, tc_bico, uc_por_trecho[0], celula,
		tinta, Vector3.BACK)
	if tampa_tras:
		_tampa_conforme(dados, perfil, ombro, n - 1, tc_rabo, uc_por_trecho[n - 2],
			celula, tinta, Vector3.FORWARD)


## Os cortes em t da faixa de baixo, iguais no carro inteiro. Ver `casco`.
static func _cortes_baixo(verticais: Array, horizontais: Array, e_meio: Array,
		ombro: Vector2) -> Array:
	var tc: Array = [-1.0, 0.0]
	for g: Array in verticais:
		for t: float in [float(g[1]), float(g[1]) + VINCO_RAMPA,
				float(g[2]) - VINCO_RAMPA, float(g[2])]:
			if t > -1.0 + 1e-4 and t < -1e-4:
				tc.append(t)
	for h: Array in horizontais:
		var mt := VINCO_MEIA / maxf(0.05, _dy_dt(e_meio, float(h[0]), ombro))
		for t: float in [float(h[0]) - mt, float(h[0]), float(h[0]) + mt]:
			if t > -1.0 + 1e-4 and t < -1e-4:
				tc.append(t)
	return _unicos(tc, false)


## Os cortes em u de uma regiao do topo. Ver `casco`.
static func _cortes_topo(longos: Array, travessas: Array, e_meio: Array) -> Array:
	var mu := VINCO_MEIA / maxf(0.2, float(e_meio[W_TOPO]))
	var uc: Array = [-1.0, 1.0]
	for g: Array in longos:
		for sg: float in [1.0, -1.0]:
			var u := sg * float(g[0])
			uc.append_array([u - mu, u, u + mu])
	for g: Array in travessas:
		uc.append_array([-float(g[1]), float(g[1])])
	return _unicos(uc, false)


## Os cortes em t de um trecho: os de baixo, do carro inteiro, mais os de cima,
## deste trecho (ombro, janelas e o alto dos vincos de porta que passam aqui).
static func _cortes_t(tc_baixo: Array, ombro: Vector2, za: float, zb: float,
		vaos: Array, verticais: Array) -> Array:
	var tc: Array = tc_baixo.duplicate()
	tc.append_array([ombro.x, 1.0])
	for v: Array in vaos:
		tc.append(float(v[2]))
		tc.append(float(v[3]))
	for g: Array in verticais:
		var gz: float = g[0]
		if gz <= zb + 1e-4 or gz >= za - 1e-4:
			continue
		for t: float in [float(g[1]), float(g[1]) + VINCO_RAMPA,
				float(g[2]) - VINCO_RAMPA, float(g[2])]:
			if t > 1e-4:
				tc.append(t)
	return _unicos(tc, false)


## Os cortes em z de um trecho, os mesmos para flancos, topo e assoalho.
static func _cortes_z(za: float, zb: float, vaos: Array, verticais: Array,
		horizontais: Array, arcos: Array, longos: Array, travessas: Array) -> Array:
	var zc: Array = [za, zb]
	for v: Array in vaos:
		_cortar(zc, float(v[0]), za, zb)
		_cortar(zc, float(v[1]), za, zb)
	for g: Array in verticais:
		var gz: float = g[0]
		for z: float in [gz - VINCO_MEIA, gz, gz + VINCO_MEIA]:
			_cortar(zc, z, za, zb)
	for h: Array in horizontais:
		for z: float in [float(h[1]), float(h[1]) - VINCO_RAMPA,
				float(h[2]) + VINCO_RAMPA, float(h[2])]:
			_cortar(zc, z, za, zb)
	for a: Dictionary in arcos:
		for p: Vector2 in (a["contorno"] as PackedVector2Array):
			_cortar(zc, p.x, za, zb)
	for g: Array in longos:
		for z: float in [float(g[1]), float(g[1]) - VINCO_RAMPA,
				float(g[2]) + VINCO_RAMPA, float(g[2])]:
			_cortar(zc, z, za, zb)
	for g: Array in travessas:
		var gz: float = g[0]
		for z: float in [gz + VINCO_MEIA, gz, gz - VINCO_MEIA]:
			_cortar(zc, z, za, zb)
	return _unicos(zc, true)


## As janelas que cruzam o trecho [zb, za] (z desce da frente para tras).
static func _vaos_no_trecho(vaos: Array, za: float, zb: float) -> Array:
	var out: Array = []
	for v: Array in vaos:
		if float(v[0]) > zb + 1e-4 and float(v[1]) < za - 1e-4:
			out.append(v)
	return out


static func _no_vao(vaos: Array, z: float, t: float) -> bool:
	for v: Array in vaos:
		if z < float(v[0]) and z > float(v[1]) and t > float(v[2]) and t < float(v[3]):
			return true
	return false


static func _unicos(valores: Array, decrescente: bool) -> Array:
	valores.sort()
	if decrescente:
		valores.reverse()
	var out: Array = []
	for x: float in valores:
		if out.is_empty() or absf(x - float(out[-1])) > 1e-4:
			out.append(x)
	return out


## Um flanco inteiro, da soleira ao teto, no trecho do perfil, como grade.
##
## `zc` e `tc` sao os cortes do trecho (ver `casco`): a grade e cortada na
## cintura e no ombro — onde a secao muda de inclinacao, entao sem nenhum outro
## corte ela sai identica as tres faixas do anel que substitui —, nas bordas
## das janelas, nos dois lados e no meio de cada vinco, e em cada ponto do
## contorno das caixas de roda. Cada celula continua plana em t e linear em z:
## o carro nao muda de forma, so ganha o que foi recortado.
##
## Na coluna que passa por cima de uma roda, o chao da coluna e o arco. Os
## cantos de cada celula sao presos nele (`maxf(t, chao)`), e nao pulados:
## assim as duas colunas vizinhas tem os mesmos vertices na aresta que dividem,
## e a celula que cruza o arco vira triangulo.
static func _flanco(dados: Dictionary, perfil: Array, ombro: Vector2,
		zc: Array, tc: Array, s: float, vaos: Array, verticais: Array,
		horizontais: Array, arcos: Array, celula: Vector2i, tinta: Callable,
		eixo_m: Vector3) -> void:
	var estacoes: Array = []
	for z: float in zc:
		estacoes.append(estacao(perfil, z))
	for i in zc.size() - 1:
		var z0: float = zc[i]
		var z1: float = zc[i + 1]
		var e_col: Array = [estacoes[i], estacoes[i + 1]]
		var chao0 := -1.0
		var chao1 := -1.0
		var arco := _arco_em(arcos, (z0 + z1) * 0.5)
		if not arco.is_empty():
			chao0 = _t_na_estacao(estacoes[i], _y_do_arco(arco, z0))
			chao1 = _t_na_estacao(estacoes[i + 1], _y_do_arco(arco, z1))
		var piso := minf(chao0, chao1)
		var cortes: Array = [piso]
		for t: float in tc:
			if t > piso + 1e-4:
				cortes.append(t)
		for j in cortes.size() - 1:
			var ta: float = cortes[j]
			var tb: float = cortes[j + 1]
			var a0 := maxf(ta, chao0)
			var a1 := maxf(ta, chao1)
			var b0 := maxf(tb, chao0)
			var b1 := maxf(tb, chao1)
			if b0 - a0 < 1e-5 and b1 - a1 < 1e-5:
				continue
			if _no_vao(vaos, (z0 + z1) * 0.5, (ta + tb) * 0.5):
				continue
			var cantos := [
				Vector2(z0, a0), Vector2(z1, a1), Vector2(z1, b1), Vector2(z0, b0)]
			var p: Array = []
			var cores: Array = []
			var meio := Vector3.ZERO
			for c in 4:
				var q: Vector2 = cantos[c]
				var e_q: Array = e_col[0 if c == 0 or c == 3 else 1]
				var wy := secao(e_q, q.y, ombro)
				var ponto := Vector3(s * wy.x, wy.y, q.x)
				meio += ponto * 0.25
				var cor: Color = tinta.call(ponto.y)
				if _no_vinco(verticais, horizontais, q.x, q.y):
					ponto -= _normal_lado(e_q, q.y, ombro, s) * VINCO_FUNDO
					cor = Color(cor.r * VINCO_ESCURO, cor.g * VINCO_ESCURO,
						cor.b * VINCO_ESCURO, cor.a)
				p.append(ponto)
				cores.append(cor)
			var fora := (meio - eixo_m).normalized()
			quad(dados, p[0], p[1], p[2], p[3], celula,
				cores[0], cores[1], cores[2], cores[3], fora)
	# A espessura da porta em volta de cada vao, so nas bordas que caem neste
	# trecho: a de cima e a de baixo vao por trecho, a da frente e a de tras so
	# no trecho que contem aquele z.
	var za: float = zc[0]
	var zb: float = zc[zc.size() - 1]
	var dentro := Vector3(-s, 0.0, 0.0) * FUNDO_VAO
	var borracha := Carroceria.marcar(BORRACHA_VAO, Carroceria.Classe.BORRACHA)
	for v: Array in vaos:
		var zf := minf(float(v[0]), za)
		var zt := maxf(float(v[1]), zb)
		var t0: float = v[2]
		var t1: float = v[3]
		var centro := ponto_lado(perfil, ombro, (zf + zt) * 0.5, (t0 + t1) * 0.5, s)
		var bordas: Array = [
			[ponto_lado(perfil, ombro, zf, t0, s), ponto_lado(perfil, ombro, zt, t0, s)],
			[ponto_lado(perfil, ombro, zf, t1, s), ponto_lado(perfil, ombro, zt, t1, s)],
		]
		if float(v[0]) <= za + 1e-4 and float(v[0]) > zb + 1e-4:
			bordas.append([ponto_lado(perfil, ombro, zf, t0, s),
				ponto_lado(perfil, ombro, zf, t1, s)])
		if float(v[1]) >= zb - 1e-4 and float(v[1]) < za - 1e-4:
			bordas.append([ponto_lado(perfil, ombro, zt, t0, s),
				ponto_lado(perfil, ombro, zt, t1, s)])
		for b: Array in bordas:
			_borda_vao(dados, b[0], b[1], dentro, centro, borracha)


## O assoalho de um trecho, nos cortes do trecho: a aresta dele e a da soleira
## sao os mesmos vertices. Estreito entre as duas paredes da caixa de roda.
static func _assoalho(dados: Dictionary, perfil: Array, zc: Array, arcos: Array,
		tinta: Callable) -> void:
	for i in zc.size() - 1:
		var z0: float = zc[i]
		var z1: float = zc[i + 1]
		var arco := _arco_em(arcos, (z0 + z1) * 0.5)
		var e0 := estacao(perfil, z0)
		var e1 := estacao(perfil, z1)
		var x0: float = e0[W_BOT]
		var x1: float = e1[W_BOT]
		if not arco.is_empty():
			x0 = minf(x0, float(arco["x_dentro"]))
			x1 = minf(x1, float(arco["x_dentro"]))
		var p0 := Vector3(-x0, e0[BOT], z0)
		var p1 := Vector3(x0, e0[BOT], z0)
		var p2 := Vector3(x1, e1[BOT], z1)
		var p3 := Vector3(-x1, e1[BOT], z1)
		quad(dados, p0, p1, p2, p3, Carroceria.C_FUNDO,
			tinta.call(p0.y) * 0.35, tinta.call(p1.y) * 0.35,
			tinta.call(p2.y) * 0.35, tinta.call(p3.y) * 0.35, Vector3.DOWN)


## A faixa de cima de um trecho, nos cortes do trecho em z e nos cortes do
## carro em u, com os vincos de capo e de tampa.
static func _topo(dados: Dictionary, perfil: Array, zc: Array, uc: Array,
		longos: Array, travessas: Array, celula: Vector2i, tinta: Callable,
		eixo_m: Vector3) -> void:
	var estacoes: Array = []
	var normais: Array = []
	for z: float in zc:
		estacoes.append(estacao(perfil, z))
		normais.append(normal_topo(perfil, z))
	for i in zc.size() - 1:
		for j in uc.size() - 1:
			var cantos := [
				Vector2(zc[i], uc[j]), Vector2(zc[i], uc[j + 1]),
				Vector2(zc[i + 1], uc[j + 1]), Vector2(zc[i + 1], uc[j])]
			var p: Array = []
			var cores: Array = []
			var meio := Vector3.ZERO
			for c in 4:
				var q: Vector2 = cantos[c]
				var k := i if c < 2 else i + 1
				var e_q: Array = estacoes[k]
				var ponto := Vector3(q.y * float(e_q[W_TOPO]), e_q[TOPO], q.x)
				meio += ponto * 0.25
				var cor: Color = tinta.call(ponto.y)
				if _no_vinco_topo(longos, travessas, q.x, q.y):
					ponto -= (normais[k] as Vector3) * VINCO_FUNDO
					cor = Color(cor.r * VINCO_ESCURO, cor.g * VINCO_ESCURO,
						cor.b * VINCO_ESCURO, cor.a)
				p.append(ponto)
				cores.append(cor)
			var fora := (meio - eixo_m).normalized()
			quad(dados, p[0], p[1], p[2], p[3], celula,
				cores[0], cores[1], cores[2], cores[3], fora)


## Fecha uma ponta do varrido com os MESMOS vertices da borda da grade: a
## lateral direita de baixo para cima nos cortes `tc`, o topo da direita para a
## esquerda nos cortes `uc`, a lateral esquerda de cima para baixo, e o
## assoalho fecha. Um leque do meio. Sao eles que impedem de ver o carro por
## dentro quando ele vem de frente.
static func _tampa_conforme(dados: Dictionary, perfil: Array, ombro: Vector2,
		k: int, tc: Array, uc: Array, celula: Vector2i, tinta: Callable,
		fora: Vector3) -> void:
	var e: Array = (perfil[k] as Array).slice(1)
	var z: float = perfil[k][0]
	var borda: Array = []
	for t: float in tc:
		var wy := secao(e, t, ombro)
		borda.append(Vector3(wy.x, wy.y, z))
	for j in range(uc.size() - 2, 0, -1):
		borda.append(Vector3(float(uc[j]) * float(e[W_TOPO]), e[TOPO], z))
	for j in range(tc.size() - 1, -1, -1):
		var wy := secao(e, float(tc[j]), ombro)
		borda.append(Vector3(-wy.x, wy.y, z))
	var centro := Vector3.ZERO
	for p: Vector3 in borda:
		centro += p / float(borda.size())
	for i in borda.size():
		var a: Vector3 = borda[i]
		var b: Vector3 = borda[(i + 1) % borda.size()]
		tri(dados, centro, a, b, celula, tinta.call(centro.y), tinta.call(a.y),
			tinta.call(b.y), fora)


## Acrescenta um corte em z se ele cair DENTRO do trecho (za, zb).
static func _cortar(zc: Array, z: float, za: float, zb: float) -> void:
	if z < za - 1e-4 and z > zb + 1e-4:
		zc.append(z)


## O vertice (z, t) do flanco esta no fundo de algum vinco?
static func _no_vinco(verticais: Array, horizontais: Array, z: float,
		t: float) -> bool:
	for g: Array in verticais:
		if absf(z - float(g[0])) < 1e-4 and t > float(g[1]) + 1e-4 \
				and t < float(g[2]) - 1e-4:
			return true
	for h: Array in horizontais:
		if absf(t - float(h[0])) < 1e-4 and z < float(h[1]) - 1e-4 \
				and z > float(h[2]) + 1e-4:
			return true
	return false


## Normal para fora da secao num `t`, no plano (x, y). O vinco afunda ao longo
## dela: na soleira a chapa olha um pouco para baixo, no ombro para cima.
static func _normal_lado(e: Array, t: float, ombro: Vector2, s: float) -> Vector3:
	var d := secao(e, t + 0.01, ombro) - secao(e, t - 0.01, ombro)
	var nn := Vector2(d.y, -d.x).normalized()
	return Vector3(s * nn.x, nn.y, 0.0)


## Quantos metros de chapa cabem numa unidade de `t` ali. Converte a boca do
## vinco horizontal, que e em metros, para a unidade da grade.
static func _dy_dt(e: Array, t: float, ombro: Vector2) -> float:
	return (secao(e, t + 0.01, ombro) - secao(e, t - 0.01, ombro)).length() / 0.02


## O `t` da lateral numa altura, abaixo da cintura (onde mora a roda).
static func _t_da_altura(perfil: Array, z: float, y: float) -> float:
	return _t_na_estacao(estacao(perfil, z), y)


static func _t_na_estacao(e: Array, y: float) -> float:
	var alto: float = e[CINT] - e[BOT]
	if alto <= 1e-4:
		return -1.0
	return clampf(-(float(e[CINT]) - y) / alto, -1.0, 0.0)


## A caixa de roda que cobre este z, ou vazio.
static func _arco_em(arcos: Array, z: float) -> Dictionary:
	for a: Dictionary in arcos:
		var c: PackedVector2Array = a["contorno"]
		if z < c[0].x - 1e-4 and z > c[c.size() - 1].x + 1e-4:
			return a
	return {}


## A altura do arco num z, pela parte de cima do contorno (sem as descidas).
static func _y_do_arco(arco: Dictionary, z: float) -> float:
	var c: PackedVector2Array = arco["contorno"]
	for k in range(1, c.size() - 2):
		var a := c[k]
		var b := c[k + 1]
		if z <= a.x + 1e-4 and z >= b.x - 1e-4:
			var f := 0.0 if absf(a.x - b.x) < 1e-6 else (a.x - z) / (a.x - b.x)
			return lerpf(a.y, b.y, clampf(f, 0.0, 1.0))
	return c[1].y


## O contorno de uma caixa de roda, pronto para `casco`.
##
## `arco` e a tabela de (dz, dy) do modulo, da frente para tras, com dy a partir
## do eixo da roda. Ela tem seis pontos, que era o bastante para um decalque
## pintado na chapa; recortado, o arco de seis lados se ve como poligono. Aqui
## ele e reamostrado por Catmull-Rom e ganha as duas descidas ate a soleira.
static func contorno_arco(perfil: Array, zc: float, y_eixo: float, arco: Array,
		fundo: float, amostras: int = 4) -> Dictionary:
	var pts := PackedVector2Array()
	var n := arco.size()
	for k in n - 1:
		var p0: Vector2 = arco[maxi(k - 1, 0)]
		var p1: Vector2 = arco[k]
		var p2: Vector2 = arco[k + 1]
		var p3: Vector2 = arco[mini(k + 2, n - 1)]
		for m in amostras:
			var f := float(m) / float(amostras)
			var f2 := f * f
			var f3 := f2 * f
			var q := 0.5 * ((2.0 * p1) + (-p0 + p2) * f
				+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f3)
			pts.append(Vector2(zc + q.x, y_eixo + q.y))
	var ultimo: Vector2 = arco[n - 1]
	pts.append(Vector2(zc + ultimo.x, y_eixo + ultimo.y))
	var primeiro: Vector2 = arco[0]
	var e0 := estacao(perfil, zc + primeiro.x)
	var e1 := estacao(perfil, zc + ultimo.x)
	pts.insert(0, Vector2(zc + primeiro.x, minf(float(e0[BOT]), y_eixo + primeiro.y)))
	pts.append(Vector2(zc + ultimo.x, minf(float(e1[BOT]), y_eixo + ultimo.y)))
	var e := estacao(perfil, zc)
	return {
		"contorno": pts,
		"centro": Vector2(zc, y_eixo),
		"x_dentro": float(e[W_BOT]) - fundo,
	}


static func _no_vinco_topo(longos: Array, travessas: Array, z: float,
		u: float) -> bool:
	for g: Array in longos:
		if absf(absf(u) - float(g[0])) < 1e-4 and z < float(g[1]) - 1e-4 \
				and z > float(g[2]) + 1e-4:
			return true
	for g: Array in travessas:
		if absf(z - float(g[0])) < 1e-4 and absf(u) <= float(g[1]) + 1e-4:
			return true
	return false


## A caixa de roda de um lado: o para-lama interno que sobe do contorno ate a
## parede de dentro, a propria parede, e a aba em volta da boca.
##
## Antes a roda ficava encostada numa chapa inteira, com uma faixa escura
## pintada em volta: de lado era um adesivo, de tres quartos se via que atras do
## pneu nao havia buraco nenhum. Agora ha: a chapa foi recortada (`_flanco`) e
## aqui se fecha o oco. O fundo e escuro e fosco, e mais claro na boca, que e o
## que a luz alcanca.
static func _caixa_de_roda(dados: Dictionary, perfil: Array, ombro: Vector2,
		arco: Dictionary, s: float, celula: Vector2i, tinta: Callable) -> void:
	var c: PackedVector2Array = arco["contorno"]
	var xd: float = arco["x_dentro"]
	var centro: Vector2 = arco["centro"]
	var cava := Carroceria.marcar(CAVA, Carroceria.Classe.FUNDO)
	var cava_boca := Carroceria.marcar(CAVA * 1.6, Carroceria.Classe.FUNDO)
	var boca: Array = []
	var fundo: Array = []
	for q: Vector2 in c:
		boca.append(ponto_lado(perfil, ombro, q.x, _t_da_altura(perfil, q.x, q.y), s))
		fundo.append(Vector3(s * xd, q.y, q.x))
	for k in c.size() - 1:
		var mz := (c[k].x + c[k + 1].x) * 0.5
		var my := (c[k].y + c[k + 1].y) * 0.5
		var olha := Vector3(0.0, centro.y - my, centro.x - mz)
		if olha.length_squared() < 1e-8:
			olha = Vector3.DOWN
		quad(dados, boca[k], boca[k + 1], fundo[k + 1], fundo[k], Carroceria.C_FUNDO,
			cava_boca, cava_boca, cava, cava, olha.normalized())
	# A parede de dentro, em leque do pe do eixo.
	var e := estacao(perfil, centro.x)
	var pe := Vector3(s * xd, float(e[BOT]), centro.x)
	for k in c.size() - 1:
		tri(dados, pe, fundo[k], fundo[k + 1], Carroceria.C_FUNDO,
			cava, cava, cava, Vector3(s, 0.0, 0.0))
	# A aba: um friso de chapa em volta da boca, que sobe um centimetro e volta
	# para a lataria. E ela que pega a luz e desenha o arco — o trabalho que a
	# faixa escura fazia pintada.
	var dentro: Array = []
	var crista: Array = []
	var fora_aba: Array = []
	for k in range(1, c.size() - 1):
		var q := c[k]
		var radial := (q - centro).normalized()
		var qm := q + radial * ABA_LARGA * 0.45
		var qf := q + radial * ABA_LARGA
		var e_m := estacao(perfil, qm.x)
		var pm := ponto_lado(perfil, ombro, qm.x, _t_da_altura(perfil, qm.x, qm.y), s)
		pm += _normal_lado(e_m, _t_da_altura(perfil, qm.x, qm.y), ombro, s) * ABA_ALTA
		dentro.append(boca[k])
		crista.append(pm)
		var tf := _t_da_altura(perfil, qf.x, qf.y)
		# Um milimetro acima da chapa: rente a ela a aba brigaria pelo pixel.
		fora_aba.append(ponto_lado(perfil, ombro, qf.x, tf, s)
			+ _normal_lado(estacao(perfil, qf.x), tf, ombro, s) * 0.0015)
	for k in dentro.size() - 1:
		var sai := Vector3(s, 0.0, 0.0)
		var a0: Vector3 = dentro[k]
		var a1: Vector3 = dentro[k + 1]
		var b0: Vector3 = crista[k]
		var b1: Vector3 = crista[k + 1]
		var f0: Vector3 = fora_aba[k]
		var f1: Vector3 = fora_aba[k + 1]
		quad(dados, a0, a1, b1, b0, celula, tinta.call(a0.y) * 0.9,
			tinta.call(a1.y) * 0.9, tinta.call(b1.y), tinta.call(b0.y), sai)
		quad(dados, b0, b1, f1, f0, celula, tinta.call(b0.y), tinta.call(b1.y),
			tinta.call(f1.y), tinta.call(f0.y), sai)


## Um friso de borracha ou de cromo pregado na lateral, com volume.
##
## Era uma faixa chapada um centimetro por fora da chapa: de frente, risco
## preto; de lado, nada. Aqui ele tem perfil — chanfro em cima, face, chanfro
## embaixo — e as tres faces pegam luz diferente, que e o que faz um friso ler
## como peca e nao como tinta. `t` e o meio dele na secao, `altura` e
## `saliencia` em metros.
static func friso(dados: Dictionary, perfil: Array, ombro: Vector2, s: float,
		z0: float, z1: float, t: float, altura: float, saliencia: float,
		cor: Color, celula: Vector2i, passos: int = 3) -> void:
	if simples:
		return
	var perfis: Array = []
	for k in passos + 1:
		var z := lerpf(z0, z1, float(k) / float(passos))
		var e := estacao(perfil, z)
		var b := ponto_lado(perfil, ombro, z, t, s)
		var nrm := _normal_lado(e, t, ombro, s)
		var dt := 0.02
		var cima := (ponto_lado(perfil, ombro, z, t + dt, s)
			- ponto_lado(perfil, ombro, z, t - dt, s)).normalized()
		perfis.append([
			b + cima * altura * 0.5,
			b + cima * altura * 0.28 + nrm * saliencia,
			b - cima * altura * 0.28 + nrm * saliencia,
			b - cima * altura * 0.5,
		])
	var tons := [cor * 1.12, cor, cor * 0.62]
	var olhar := [Vector3(s * 0.5, 0.85, 0.0), Vector3(s, 0.0, 0.0),
		Vector3(s * 0.5, -0.85, 0.0)]
	for k in passos:
		var a: Array = perfis[k]
		var b: Array = perfis[k + 1]
		for f in 3:
			var c: Color = tons[f]
			quad(dados, a[f], b[f], b[f + 1], a[f + 1], celula, c, c, c, c,
				(olhar[f] as Vector3).normalized())
	# As duas pontas fechadas: sem elas o friso e uma calha vista de lado.
	for ponta: Array in [[perfis[0], Vector3(0, 0, 1)],
			[perfis[passos], Vector3(0, 0, -1)]]:
		var q: Array = ponta[0]
		var dz: Vector3 = ponta[1] if z0 > z1 else -(ponta[1] as Vector3)
		quad(dados, q[0], q[1], q[2], q[3], celula, cor * 0.8, cor * 0.8,
			cor * 0.8, cor * 0.8, dz)


## A macaneta de porta: o puxador de metal sobre a concha funda na chapa.
static func macaneta(dados: Dictionary, perfil: Array, ombro: Vector2, s: float,
		z: float, t: float, metal: Color, celula_metal: Vector2i) -> void:
	if simples:
		return
	var e := estacao(perfil, z)
	var b := ponto_lado(perfil, ombro, z, t, s)
	var nrm := _normal_lado(e, t, ombro, s)
	var cima := (ponto_lado(perfil, ombro, z, t + 0.02, s)
		- ponto_lado(perfil, ombro, z, t - 0.02, s)).normalized()
	var ao_longo := Vector3(0.0, 0.0, 1.0)
	# A concha: a sombra da cavidade atras do puxador, rente a chapa.
	var sombra := Carroceria.marcar(Color(0.05, 0.05, 0.055), Carroceria.Classe.FUNDO)
	var cw := 0.075
	var ch := 0.024
	var c0 := b + nrm * 0.0008
	quad(dados, c0 + ao_longo * cw - cima * ch, c0 - ao_longo * cw - cima * ch,
		c0 - ao_longo * cw + cima * ch, c0 + ao_longo * cw + cima * ch,
		Carroceria.C_FUNDO, sombra, sombra, sombra, sombra, nrm)
	# O puxador: uma barra de 12 cm, um centimetro e meio para fora.
	var meio := b + nrm * 0.008 + cima * 0.004
	var tam := Vector3(0.12, 0.018, 0.012)
	var eixos := [ao_longo * tam.x * 0.5, cima * tam.y * 0.5, nrm * tam.z * 0.5]
	var faces := [
		[eixos[2], eixos[0], eixos[1]], [-(eixos[2] as Vector3), eixos[0], eixos[1]],
		[eixos[1], eixos[0], eixos[2]], [-(eixos[1] as Vector3), eixos[0], eixos[2]],
		[eixos[0], eixos[1], eixos[2]], [-(eixos[0] as Vector3), eixos[1], eixos[2]],
	]
	for f: Array in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var c := meio + n
		var tom := metal * (1.1 if n.dot(cima) > 0.001 else (0.7 if n.dot(cima) < -0.001 else 1.0))
		quad(dados, c - u - v, c + u - v, c + u + v, c - u + v, celula_metal,
			tom, tom, tom, tom, n.normalized())


## A moldura de uma lente com volume (PLANO_CARROS_AAA, F4): o aro em volta, a
## parede de fora ate a carcaca e o tunel de dentro ate a lente, recuada.
##
## A lente era um adesivo emissivo colado um centimetro na frente de uma placa
## escura: de lado ela flutuava, de frente era um retangulo sem borda. Farol de
## verdade mora num buraco, atras de um aro que pega luz. `xf` e o plano da
## carcaca, olhando para +Z dele; `tamanho` e o da lente; `saliencia` e quanto
## o aro sai da carcaca e `recuo` quanto o tunel entra a partir do aro.
static func moldura_luz(dados: Dictionary, xf: Transform3D, tamanho: Vector2,
		aro: float, saliencia: float, recuo: float, cor: Color,
		celula: Vector2i) -> void:
	if simples:
		return
	var hx := tamanho.x * 0.5
	var hy := tamanho.y * 0.5
	var cantos: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	var dentro_f: Array = []
	var fora_f: Array = []
	var fora_t: Array = []
	var dentro_t: Array = []
	for c: Vector2 in cantos:
		dentro_f.append(xf * Vector3(c.x * hx, c.y * hy, saliencia))
		fora_f.append(xf * Vector3(c.x * (hx + aro), c.y * (hy + aro), saliencia))
		fora_t.append(xf * Vector3(c.x * (hx + aro), c.y * (hy + aro), 0.0))
		dentro_t.append(xf * Vector3(c.x * hx, c.y * hy, saliencia - recuo))
	var frente := xf.basis.z.normalized()
	var claro := Color(cor.r * 1.12, cor.g * 1.12, cor.b * 1.12, cor.a)
	var medio := Color(cor.r * 0.8, cor.g * 0.8, cor.b * 0.8, cor.a)
	var fundo := Color(cor.r * 0.5, cor.g * 0.5, cor.b * 0.5, cor.a)
	for k in 4:
		var k2 := (k + 1) % 4
		var meio := (cantos[k] + cantos[k2]) * 0.5
		var lado := (xf.basis.x * meio.x + xf.basis.y * meio.y).normalized()
		quad(dados, fora_f[k], fora_f[k2], dentro_f[k2], dentro_f[k], celula,
			claro, claro, claro, claro, frente)
		quad(dados, fora_t[k], fora_t[k2], fora_f[k2], fora_f[k], celula,
			medio, medio, medio, medio, lado)
		quad(dados, dentro_f[k], dentro_f[k2], dentro_t[k2], dentro_t[k], celula,
			medio, medio, fundo, fundo, -lado)


## O quadrilatero do para-brisa ou do vigia, com o miolo aberto.
##
## Sobram quatro faixas de lataria em volta do vao — a mesma moldura que o
## `inset` do vidro ja deixava visivel —, e o vidro de fora cobre o miolo.
static func _moldura(dados: Dictionary, q0: Vector3, q1: Vector3, q2: Vector3,
		q3: Vector3, recuo: float, celula: Vector2i, tinta: Callable,
		fora: Vector3) -> void:
	var fora_placa := normal_placa(q0, q1, q3)
	if fora_placa.dot(fora) < 0.0:
		fora_placa = -fora_placa
	var q := [q0, q1, q2, q3]
	var i := inset(q0, q1, q2, q3, recuo)
	for k in 4:
		var a: Vector3 = q[k]
		var b: Vector3 = q[(k + 1) % 4]
		var c: Vector3 = i[(k + 1) % 4]
		var d: Vector3 = i[k]
		quad(dados, a, b, c, d, celula, tinta.call(a.y), tinta.call(b.y),
			tinta.call(c.y), tinta.call(d.y), fora_placa)
	var centro: Vector3 = (i[0] + i[1] + i[2] + i[3]) * 0.25
	var dentro := -fora_placa * FUNDO_VAO
	var borracha := Carroceria.marcar(BORRACHA_VAO, Carroceria.Classe.BORRACHA)
	for k in 4:
		_borda_vao(dados, i[k], i[(k + 1) % 4], dentro, centro, borracha)


## Uma aresta do vao dobrada para dentro, virada para o miolo da janela.
static func _borda_vao(dados: Dictionary, a: Vector3, b: Vector3,
		dentro: Vector3, centro: Vector3, cor: Color) -> void:
	var meio := (a + b) * 0.5
	var olha := centro - meio
	if olha.length_squared() < 1e-10:
		return
	quad(dados, a, b, b + dentro, a + dentro, Carroceria.C_FUNDO,
		cor, cor, cor, cor, olha.normalized())


## Fecha uma ponta do varrido. Quatro triangulos por ponta, e sao eles que
## impedem de ver o carro por dentro quando ele vem de frente.
static func tampa(dados: Dictionary, perfil: Array, ombro: Vector2, k: int,
		celula: Vector2i, tinta: Callable, fora: Vector3) -> void:
	var e: Array = (perfil[k] as Array).slice(1)
	var z: float = perfil[k][0]
	var r := anel(e, ombro)
	for j in range(1, 7):
		var a: Vector3 = r[0] + Vector3(0, 0, z)
		var b: Vector3 = r[j] + Vector3(0, 0, z)
		var c: Vector3 = r[j + 1] + Vector3(0, 0, z)
		tri(dados, a, b, c, celula,
			tinta.call(a.y), tinta.call(b.y), tinta.call(c.y), fora)


## Normais suaves onde a chapa e curva, quinas vivas onde ela dobra.
##
## `quad` grava a normal da FACE nos quatro vertices, e cada faixa do casco sai
## chapada: com luz por pixel e verniz, o reflexo do ceu anda aos saltos de uma
## faixa para a outra e o carro le como poliedro — metade do "zero realismo"
## que o jogador apontou (PLANO_CARROS_AAA, F6). Carro de verdade e superficie
## continua com poucas dobras vivas: cintura, borda do capo, para-choque.
##
## Vertices no mesmo lugar (meio milimetro) trocam normal entre si so quando as
## faces deles dobram menos que `angulo_graus`. Acima disso a quina fica viva:
## a borda do vinco da porta, a espessura da janela e a tampa do bico nao se
## misturam com a chapa, e e isso que as faz aparecer.
static func suavizar(dados: Dictionary, angulo_graus: float) -> void:
	var v: PackedVector3Array = dados["v"]
	var n: PackedVector3Array = dados["n"]
	var limite := cos(deg_to_rad(angulo_graus))
	var grupos := {}
	for k in v.size():
		var chave := Vector3i((v[k] * 2000.0).round())
		if grupos.has(chave):
			(grupos[chave] as PackedInt32Array).append(k)
		else:
			grupos[chave] = PackedInt32Array([k])
	var saida := n.duplicate()
	for chave: Vector3i in grupos:
		var membros: PackedInt32Array = grupos[chave]
		if membros.size() < 2:
			continue
		for a in membros:
			var soma := Vector3.ZERO
			for b in membros:
				if n[a].dot(n[b]) >= limite:
					soma += n[b]
			if soma.length_squared() > 1e-10:
				saida[a] = soma.normalized()
	dados["n"] = saida


# --------------------------------------------------------------------------
# Primitivas de malha
# --------------------------------------------------------------------------


## Quatro pontos, uma celula do atlas, uma cor por vertice.
##
## `fora` diz para que lado a face olha. Nao da para deduzir do poligono: os
## dois lados de um carro sao a mesma sequencia espelhada em X, o que produz a
## MESMA ordem de giro nos dois e faz o culling comer um deles.
##
## CONVENCAO DE GIRO DO PROJETO: a face aparece do lado OPOSTO ao produto
## vetorial do seu giro. Quem prova isso e PSXMesh.placa_dados, que declara
## normal +Z e emite [0,2,1] — cujo produto vetorial da -Z; a calota em
## Carroceria._roda faz igual. Escrever o giro "para o lado da normal", que e o
## instinto, deixa TODA face virada para dentro: o carro vira um casco oco em
## que se ve o assoalho escuro por cima e a lataria some. Custou tres rodadas de
## depuracao no Fusca; nao reinventar.
static func quad(dados: Dictionary, p0: Vector3, p1: Vector3, p2: Vector3,
		p3: Vector3, celula: Vector2i, c0: Color, c1: Color, c2: Color,
		c3: Color, fora: Vector3) -> void:
	var r := Carroceria.uv(celula)
	var v: PackedVector3Array = dados["v"]
	var n: PackedVector3Array = dados["n"]
	var u: PackedVector2Array = dados["uv"]
	var cc: PackedColorArray = dados["c"]
	var i: PackedInt32Array = dados["i"]
	var normal := (p1 - p0).cross(p3 - p0)
	if normal.length_squared() < 1e-12:
		normal = (p2 - p1).cross(p0 - p1)
	normal = normal.normalized()
	var invertido := normal.dot(fora) < 0.0
	if invertido:
		normal = -normal
	# Subdivisao. Painel grande num quadrilatero so faz a UV afim do
	# psx_surface escorregar junto com a camera, que e o defeito que o resto do
	# jogo nao tem porque PSXMesh.placa_dados subdivide em MAX_QUAD_M. Detalhe
	# pequeno — friso, macaneta, veneziana — nao passa do limite e continua
	# saindo em dois triangulos, entao isto nao cobra nada de quem nao precisa.
	var passo_m: float = Carroceria.PASSO_PAINEL
	var cols := maxi(1, ceili(
		maxf(p0.distance_to(p1), p3.distance_to(p2)) / passo_m))
	var linhas := maxi(1, ceili(
		maxf(p0.distance_to(p3), p1.distance_to(p2)) / passo_m))
	var base := v.size()
	for j in linhas + 1:
		var fy := float(j) / float(linhas)
		for k in cols + 1:
			var fx := float(k) / float(cols)
			v.append(p0.lerp(p1, fx).lerp(p3.lerp(p2, fx), fy))
			n.append(normal)
			cc.append(c0.lerp(c1, fx).lerp(c3.lerp(c2, fx), fy))
			u.append(r.position + Vector2(fx, 1.0 - fy) * r.size)
	var larg := cols + 1
	for j in linhas:
		for k in cols:
			var q := base + j * larg + k
			if invertido:
				i.append_array([q, q + 1, q + larg + 1,
					q, q + larg + 1, q + larg])
			else:
				i.append_array([q, q + larg + 1, q + 1,
					q, q + larg, q + larg + 1])
	dados["v"] = v
	dados["n"] = n
	dados["uv"] = u
	dados["c"] = cc
	dados["i"] = i


static func tri(dados: Dictionary, p0: Vector3, p1: Vector3, p2: Vector3,
		celula: Vector2i, c0: Color, c1: Color, c2: Color,
		fora: Vector3) -> void:
	var r := Carroceria.uv(celula)
	var v: PackedVector3Array = dados["v"]
	var n: PackedVector3Array = dados["n"]
	var u: PackedVector2Array = dados["uv"]
	var cc: PackedColorArray = dados["c"]
	var i: PackedInt32Array = dados["i"]
	var normal := (p1 - p0).cross(p2 - p0).normalized()
	var invertido := normal.dot(fora) < 0.0
	if invertido:
		normal = -normal
	var base := v.size()
	for p: Vector3 in [p0, p1, p2]:
		v.append(p)
		n.append(normal)
	cc.append(c0)
	cc.append(c1)
	cc.append(c2)
	u.append(r.position + Vector2(0.0, r.size.y))
	u.append(r.position + r.size)
	u.append(r.position)
	if invertido:
		i.append_array([base, base + 1, base + 2])
	else:
		i.append_array([base, base + 2, base + 1])
	dados["v"] = v
	dados["n"] = n
	dados["uv"] = u
	dados["c"] = cc
	dados["i"] = i


## Placa plana com uma celula do atlas.
static func plana(dados: Dictionary, tamanho: Vector2, xform: Transform3D,
		cor: Color, celula: Vector2i) -> void:
	var d := PSXMesh.placa_dados(tamanho, Carroceria.PASSO_PAINEL, Color.WHITE)
	var r := Carroceria.uv(celula)
	var uvs: PackedVector2Array = d["uv"]
	for k in uvs.size():
		uvs[k] = r.position + uvs[k] * r.size
	d["uv"] = uvs
	PSXMesh.acumular_tingido(dados, d, xform, cor)


## Disco facetado virado para +Z da base. Farol redondo com celula quadrada nao
## passa por redondo nem a trinta metros.
static func disco(dados: Dictionary, centro: Vector3, giro: Basis, raio: float,
		celula: Vector2i, cor: Color, lados: int = 8) -> void:
	var r := Carroceria.uv(celula)
	var v: PackedVector3Array = dados["v"]
	var n: PackedVector3Array = dados["n"]
	var u: PackedVector2Array = dados["uv"]
	var cc: PackedColorArray = dados["c"]
	var i: PackedInt32Array = dados["i"]
	var normal := (giro * Vector3.BACK).normalized()
	var base := v.size()
	v.append(centro)
	n.append(normal)
	cc.append(cor)
	u.append(r.get_center())
	for k in lados + 1:
		var a := TAU * float(k) / float(lados)
		v.append(centro + giro * Vector3(cos(a) * raio, sin(a) * raio, 0.0))
		n.append(normal)
		cc.append(cor)
		u.append(r.get_center() + Vector2(cos(a), -sin(a)) * r.size * 0.5)
	for k in lados:
		i.append_array([base, base + 2 + k, base + 1 + k])
	dados["v"] = v
	dados["n"] = n
	dados["uv"] = u
	dados["c"] = cc
	dados["i"] = i


## Puxa os quatro cantos de um quadrilatero na direcao do centro.
static func inset(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
		f: float) -> Array:
	var c := (p0 + p1 + p2 + p3) * 0.25
	return [p0.lerp(c, f), p1.lerp(c, f), p2.lerp(c, f), p3.lerp(c, f)]


## Normal de um quad de vidro, apontando para fora (para cima da rampa).
##
## Nao usar o vetor do centro do carro: o centro mora no assoalho, entao
## "fora" vira quase +Y puro e o vidro descola para CIMA em vez de para
## fora da rampa. De 3P isso le como placa preta flutuando a frente do vao.
static func normal_placa(p0: Vector3, p1: Vector3, p3: Vector3) -> Vector3:
	var n := (p1 - p0).cross(p3 - p0)
	if not n.is_finite() or n.length_squared() < 1e-12:
		return Vector3.UP
	n = n.normalized()
	if n.y < 0.0:
		n = -n
	return n


# --------------------------------------------------------------------------
# Pintura
# --------------------------------------------------------------------------

## Sujeira por altura: barro na soleira, cor limpa no teto.
##
## Sai de graca por cor de vertice. A alternativa era uma celula de atlas por
## faixa de altura, que e textura que este projeto nao tem.
static func sujo(cor: Color, barro: Color, y: float, teto: float,
		forca: float) -> Color:
	var f := clampf((teto - y) / teto, 0.0, 1.0)
	return cor.lerp(barro, f * f * forca)
