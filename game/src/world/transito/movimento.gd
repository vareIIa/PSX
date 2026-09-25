## O caminho de um carro atraves de um cruzamento — chega por uma faixa, sai por
## outra — com o que o juiz precisa saber dele (PLANO_TRANSITO_AAA, Passo 3):
## onde ele cruza cada outro movimento, onde passa pelas duas zebras e onde a
## lataria ja deixou o cruzamento.
##
## E o caminho que o motorista anda: a curva sai de
## `Manobra.curva_de_cruzamento` (a mesma chave, o mesmo cache) e a reta e a da
## faixa. So a lataria e a do envelope da frota (`Manobra.ENVELOPE_*`): a mesma
## esquina tem as mesmas zonas para todo carro, e o cache fica por movimento, e
## nao por par de carros.
##
## Referencial
## -----------
## `s` e o comprimento de arco do eixo traseiro desde um ponto `RECUO` metros
## antes do centro, na faixa de chegada. O motorista liga o `s` dele a este pelo
## `s_ref`: o comeco da curva (conversao) ou o encontro das faixas (reto), que ele
## guarda no evento do cruzamento (`MotoristaIA._evento`).
##
## A lataria em tres discos
## ------------------------
## Um no meio do entre-eixos e um em cada ponta, de raio meia largura + `FOLGA`.
## Dois movimentos conflitam onde algum disco de um chega a menos de dois raios
## de algum disco do outro; a zona de cada um e o intervalo de `s` em que isso
## acontece. Pelo eixo traseiro sozinho a frente, que abre na curva, ficava de
## fora (0,77 m numa esquina de raio 7,5).
class_name Movimento
extends RefCounted

enum Tipo { RETO, DIREITA, ESQUERDA }

const PASSO := 0.5
const RECUO := 26.0
## Folga lateral de cada lataria na conta de conflito, em metros.
const FOLGA := 0.3
const RAIO := Manobra.ENVELOPE_LARG * 0.5 + FOLGA
const MEIO := Manobra.ENVELOPE_EIXO * 0.5
const PONTA := Manobra.ENVELOPE_COMP * 0.5 - Manobra.ENVELOPE_LARG * 0.5
## Do eixo traseiro ao bico e a traseira do envelope.
const BICO := Manobra.ENVELOPE_EIXO * 0.5 + Manobra.ENVELOPE_COMP * 0.5
const TRAS := Manobra.ENVELOPE_COMP * 0.5 - Manobra.ENVELOPE_EIXO * 0.5
## Amostras por grupo no descarte grosso da conta de conflito.
const GRUPO := 8
## Aceleracao lateral da curva (a do motorista, `MotoristaIA.A_LAT`) e as
## velocidades de via (`Carro.VEL_CRUZEIRO` e `VEL_AVENIDA`; a bancada do
## cruzamento confere). Copiadas: esta classe e leve e nao puxa o Carro, que puxa
## os autoloads — a bancada a le antes de eles existirem.
const A_LAT := 2.5
const V_RUA := 11.0
const V_AVENIDA := 14.0

var chave := ""
var ij := Vector2i.ZERO
var chegada := Vector4i.ZERO
var saida := Vector4i.ZERO
var tipo: int = Tipo.RETO
var s_ref := 0.0
## Bico do envelope na linha de retencao.
var s_linha := 0.0
## Traseira alem da zebra de saida: o carro deixou o cruzamento.
var s_fim := 0.0
## Velocidade de passagem: a da curva, ou a da via.
var v_passa := 11.0
## Zebras: (s em que a lataria comeca a cobrir a faixa, s em que deixa de
## cobrir, menor e maior `Zebra.atravessado` da lataria enquanto cobre).
## x = INF: nao passa por ela.
var z_chegada := Vector4(INF, -INF, INF, -INF)
var z_saida := Vector4(INF, -INF, INF, -INF)
var _s := PackedFloat32Array()
var _d := PackedVector2Array()
var _gc := PackedVector2Array()
var _gr := PackedFloat32Array()
## Primeira amostra que conta para conflito: o bico a um metro da linha. Antes
## dela cada carro esta na propria faixa de chegada.
var _k0 := 0
## Conflitos ja calculados com outros movimentos, pelo id do outro.
var _com: Dictionary = {}

static var _feitos: Dictionary = {}
const TETO := 3000
## O pior custo de montar um movimento e de calcular um conflito, em ms. Lidos
## pela bancada.
static var custo_montar_ms := 0.0
static var custo_conflito_ms := 0.0


## O movimento de quem chega a `ij` pelo trecho `chegada` (com faixa) e sai pelo
## `saida` (com faixa). Pronto no cache.
static func de(ij: Vector2i, chegada: Vector4i, saida: Vector4i) -> Movimento:
	var chave := "%d,%d|%d,%d,%d|%d,%d,%d" % [ij.x, ij.y, chegada.x, chegada.z, chegada.w,
		saida.x, saida.z, saida.w]
	var pronto: Variant = _feitos.get(chave)
	if pronto != null:
		return pronto
	var t0 := Time.get_ticks_usec()
	var m := _montar(ij, chegada, saida)
	m.chave = chave
	if _feitos.size() >= TETO:
		_feitos.clear()
	_feitos[chave] = m
	custo_montar_ms = maxf(custo_montar_ms, float(Time.get_ticks_usec() - t0) / 1000.0)
	return m


static func _montar(ij: Vector2i, chegada: Vector4i, saida: Vector4i) -> Movimento:
	var m := Movimento.new()
	m.ij = ij
	m.chegada = chegada
	m.saida = saida
	var c := Vector2(float(ij.x) * Vias.TAM, float(ij.y) * Vias.TAM)
	var da3 := Vias.direcao(chegada.z, chegada.w)
	var da := Vector2(da3.x, da3.z)
	var db3 := Vias.direcao(saida.z, saida.w)
	var db := Vector2(db3.x, db3.z)
	var faixa := Manobra.encontro(ij.x, ij.y, chegada, chegada)
	var p0 := faixa + da * ((c - faixa).dot(da) - RECUO)
	var pecas: Array[Manobra] = []
	if chegada.z != saida.z:
		var curva := Manobra.curva_de_cruzamento(ij.x, ij.y, chegada, saida)
		var r1 := Manobra.reta(p0, curva.inicio())
		pecas.append(r1)
		pecas.append(curva)
		pecas.append(Manobra.reta(curva.fim(), curva.fim() + db * 30.0))
		m.s_ref = r1.comprimento
		m.tipo = Tipo.DIREITA if Manobra.lado_da_curva(chegada, saida) > 0 else Tipo.ESQUERDA
		m.v_passa = sqrt(A_LAT * maxf(curva.raio, 1.0))
	else:
		var r1 := Manobra.reta(p0, faixa)
		pecas.append(r1)
		pecas.append(Manobra.reta(faixa, faixa + db * 30.0))
		m.s_ref = r1.comprimento
		var classe := Vias.classe_x(ij.x) if chegada.z == 0 else Vias.classe_z(ij.y)
		m.v_passa = V_AVENIDA if classe == MalhaUrbana.Via.AVENIDA else V_RUA

	var linha := Esquina.linha(ij, chegada.z)
	var zc := Esquina.zebra(ij, Esquina.braco_de_chegada(chegada))
	var zs := Esquina.zebra(ij, Esquina.braco_de_saida(saida))
	var meia_l := Manobra.ENVELOPE_LARG * 0.5
	var total := 0.0
	for p: Manobra in pecas:
		total += p.comprimento
	var achou_linha := false
	var k_peca := 0
	var base := 0.0
	var s := 0.0
	var parar := INF
	while s <= total and s <= parar:
		while k_peca < pecas.size() - 1 and s > base + pecas[k_peca].comprimento:
			base += pecas[k_peca].comprimento
			k_peca += 1
		var am := pecas[k_peca].amostra(minf(s - base, pecas[k_peca].comprimento))
		var p := Vector2(am.x, am.y)
		var f := Manobra.dir_de(am.z)
		var e := Manobra.esquerda_de(am.z)
		if not achou_linha and (p + f * BICO - c).dot(da) >= -linha:
			m.s_linha = s
			achou_linha = true
		m._s.append(s)
		m._d.append(p + f * (MEIO - PONTA))
		m._d.append(p + f * MEIO)
		m._d.append(p + f * (MEIO + PONTA))
		var cantos: Array[Vector2] = [p + f * BICO + e * meia_l, p + f * BICO - e * meia_l,
			p - f * TRAS + e * meia_l, p - f * TRAS - e * meia_l]
		m.z_chegada = _cobre(zc, cantos, s, m.z_chegada)
		m.z_saida = _cobre(zs, cantos, s, m.z_saida)
		# Saiu da zebra de saida: mais meio metro e acabou o cruzamento.
		if parar == INF and m.z_saida.x != INF and s > m.z_saida.y + 0.01:
			parar = s + 1.0
		s += PASSO
	m.s_fim = m.z_saida.y + 0.5 if m.z_saida.x != INF else total
	m._k0 = 0
	for k in m._s.size():
		if m._s[k] >= m.s_linha - 1.0:
			m._k0 = k
			break
	# Os grupos do descarte grosso.
	var k := m._k0
	while k < m._s.size():
		var fim := mini(k + GRUPO, m._s.size())
		var centro := Vector2.ZERO
		for q in range(k, fim):
			centro += m._d[3 * q + 1]
		centro /= float(fim - k)
		var r := 0.0
		for q in range(3 * k, 3 * fim):
			r = maxf(r, m._d[q].distance_to(centro))
		m._gc.append(centro)
		m._gr.append(r + RAIO)
		k = fim
	return m


## A zebra `z` com a lataria de cantos `cantos` na amostra `s`: amplia a janela
## `w` se a lataria cobre a faixa.
static func _cobre(z: Esquina.Zebra, cantos: Array[Vector2], s: float, w: Vector4) -> Vector4:
	var al_min := INF
	var al_max := -INF
	var ac_min := INF
	var ac_max := -INF
	for q: Vector2 in cantos:
		var al := z.ao_longo(q)
		var ac := z.atravessado(q)
		al_min = minf(al_min, al)
		al_max = maxf(al_max, al)
		ac_min = minf(ac_min, ac)
		ac_max = maxf(ac_max, ac)
	if al_max < z.lo or al_min > z.hi or ac_max < -z.meia or ac_min > z.meia:
		return w
	return Vector4(minf(w.x, s), maxf(w.y, s), minf(w.z, ac_min), maxf(w.w, ac_max))


## Onde `a` e `b` disputam o mesmo chao: (s de `a` em que entra, s em que sai,
## s de `b` em que entra, s em que sai). x = INF: nao se cruzam.
static func conflito(a: Movimento, b: Movimento) -> Vector4:
	var id := b.get_instance_id()
	var pronto: Variant = a._com.get(id)
	if pronto != null:
		return pronto
	var t0 := Time.get_ticks_usec()
	var r := _conflito(a, b)
	a._com[id] = r
	b._com[a.get_instance_id()] = Vector4(r.z, r.w, r.x, r.y)
	custo_conflito_ms = maxf(custo_conflito_ms, float(Time.get_ticks_usec() - t0) / 1000.0)
	return r


static func _conflito(a: Movimento, b: Movimento) -> Vector4:
	var r2 := 4.0 * RAIO * RAIO
	var longe := 2.0 * PONTA + 2.0 * RAIO
	var longe2 := longe * longe
	var saida := Vector4(INF, -INF, INF, -INF)
	for ga in a._gc.size():
		for gb in b._gc.size():
			var soma := a._gr[ga] + b._gr[gb]
			if a._gc[ga].distance_squared_to(b._gc[gb]) > soma * soma:
				continue
			var ia0 := a._k0 + ga * GRUPO
			var ib0 := b._k0 + gb * GRUPO
			for i in range(ia0, mini(ia0 + GRUPO, a._s.size())):
				var ma := a._d[3 * i + 1]
				for j in range(ib0, mini(ib0 + GRUPO, b._s.size())):
					if ma.distance_squared_to(b._d[3 * j + 1]) > longe2:
						continue
					var toca := false
					for u in 3:
						var da := a._d[3 * i + u]
						for w in 3:
							if da.distance_squared_to(b._d[3 * j + w]) < r2:
								toca = true
								break
						if toca:
							break
					if toca:
						saida.x = minf(saida.x, a._s[i])
						saida.y = maxf(saida.y, a._s[i])
						saida.z = minf(saida.z, b._s[j])
						saida.w = maxf(saida.w, b._s[j])
	return saida
