## Um pedaco do caminho de um carro da IA, em planta (x, z), medido pelo
## comprimento de arco `s` do EIXO TRASEIRO.
##
## Por que um caminho, e nao uma mira
## ----------------------------------
## A IA antiga perseguia um ponto: a 8,5 m do cruzamento mirava a "quina" das
## duas faixas e girava no maximo 2,3 rad/s atras dela, a qualquer velocidade.
## Medido numa replica da lei (PLANO_TRANSITO_AAA, secao 2): curva de raio
## 4,8 m a 40 km/h, 2,6 g de aceleracao lateral, a direita entrando 0,9 m na
## contramao e a esquerda subindo no meio-fio da avenida. Nao ha ajuste de
## taxa que conserte isso, porque o defeito e o desenho: quem persegue um ponto
## nao sabe que curva vai fazer ate estar dentro dela.
##
## Aqui a curva existe ANTES de o carro chegar. E a concordancia de estrada:
## espiral, arco e espiral, tangente as duas linhas de faixa. A curvatura sobe
## de zero, fica no raio e volta a zero — o volante gira, segura e desgira —, e
## o motorista sabe a curvatura dos proximos metros, entao reduz antes da
## esquina (`MotoristaIA`).
##
## Eixo traseiro, e nao centro
## ---------------------------
## O caminho e do meio do eixo traseiro, com o carro apontado pela tangente: e
## o modelo de bicicleta, em que a roda de tras nunca anda de lado. Pelo
## centro, o carro giraria em volta do proprio meio e a traseira escorregaria
## para fora a cada esquina — o gesto que mais denuncia carro de jogo. O preco
## e que a frente abre na curva, como num carro de verdade, e isso entra na
## escolha do raio (`curva_de_cruzamento`).
##
## Convencoes
## ----------
## Planta em Vector2(x, z). `rumo` e o `_giro` do Carro: frente =
## (-sin rumo, -cos rumo). Curvatura e d(rumo)/ds: positiva vira para a
## esquerda.
class_name Manobra
extends RefCounted

enum Tipo { RETA, CURVA }

## Passo da tabela da curva, em metros.
const DS := 0.25
## Sub-passos de integracao por amostra da tabela.
const SUB := 8

## A frota inteira cabe neste envelope: o maior entre-eixos e balanco (picape,
## 4,70 x 1,78 x 2,80; ver `Carroceria.MEDIDAS`). A escolha de raio e feita com
## ele, e nao com o carro que vai passar: a mesma esquina da a mesma curva a
## todo mundo, e o cache fica em poucas chaves. O prototipo mostrou que a picape
## e o pior caso das tres folgas em todas as esquinas.
const ENVELOPE_COMP := 4.75
const ENVELOPE_LARG := 1.78
const ENVELOPE_EIXO := 2.80

## Raios e fracoes de espiral tentados, do mais aberto para o mais fechado. A
## fracao e quanto da deflexao cada espiral leva; o resto e arco.
const RAIOS: Array[float] = [9.0, 8.5, 8.0, 7.5, 7.0, 6.5, 6.0, 5.5]
const FRACOES: Array[float] = [0.25, 0.3, 0.35, 0.4, 0.2]
## Folga que a escolha exige, em metros, entre qualquer canto da lataria e o
## eixo da rua, o meio-fio da calcada e (na esquerda) a borda da pista de saida.
const FOLGA_ALVO := 0.15

var tipo: Tipo = Tipo.RETA
var comprimento: float = 0.0

# --- o que o motorista pendura (quem monta preenche) ---
## Trecho em que o carro esta no comeco deste pedaco, e a partir de `s_troca`.
## Numa curva a troca e o meio dela (o cruzamento ficou para tras); numa troca
## de faixa e o meio do S.
var trecho := Vector4i.ZERO
var trecho_fim := Vector4i.ZERO
var s_troca := 0.0
## Velocidade da via, em m/s.
var v_via := 11.0
## Seta deste pedaco (+1 direita, -1 esquerda, 0 nenhuma) e onde a manobra
## comeca e termina, em `s` do pedaco.
var pisca := 0
var pisca_ini := 0.0
var pisca_fim := 0.0
## A maior |curvatura| de cada metro do pedaco. Ver `_preparar_faixas`.
var kbins := PackedFloat32Array()

# --- reta ---
var _a := Vector2.ZERO
var _dir := Vector2(0.0, 1.0)
var _rumo := 0.0
var _esq := Vector2.ZERO
## Desvio lateral (para a ESQUERDA, em metros) de `_d0` com inclinacao `_m0`
## ate `_d1`, entre `_l_ini` e `_l_fim`. Troca de faixa e d0 = 0, d1 = largura;
## volta para a faixa e d0 = afastamento atual, d1 = 0.
var _d0 := 0.0
var _m0 := 0.0
var _d1 := 0.0
var _l_ini := 0.0
var _l_fim := 0.0

# --- curva ---
var _pts := PackedVector2Array()
var _rumos := PackedFloat32Array()
var _curvs := PackedFloat32Array()
var _ds := DS
## Quanto a curva comeca antes do ponto de encontro das faixas (e termina
## depois dele), em metros.
var recuo := 0.0
var raio := 0.0
var fracao := 0.0


# --- construcao ------------------------------------------------------------

static func reta(a: Vector2, b: Vector2) -> Manobra:
	var m := Manobra.new()
	m.tipo = Tipo.RETA
	var d := b - a
	m.comprimento = d.length()
	m._a = a
	m._dir = d / m.comprimento if m.comprimento > 1e-4 else Vector2(0.0, 1.0)
	m._rumo = rumo_de(m._dir)
	m._esq = esquerda_de(m._rumo)
	return m


## Reta com desvio lateral suave (quintica: posicao, inclinacao e curvatura
## continuas nas duas pontas). `d0` e `d1` sao metros para a esquerda da reta
## a-b; `m0` e a inclinacao inicial (tangente do erro de rumo).
static func reta_desviada(a: Vector2, b: Vector2, d0: float, m0: float, d1: float,
		l_ini: float, l_fim: float) -> Manobra:
	var m := reta(a, b)
	m._d0 = d0
	m._m0 = m0
	m._d1 = d1
	m._l_ini = clampf(l_ini, 0.0, m.comprimento)
	m._l_fim = clampf(l_fim, m._l_ini, m.comprimento)
	return m


## Espiral, arco e espiral tangente as retas que se encontram em `pi`, vindo
## na direcao `dir_a` e saindo na `dir_b`. Deflexao de ate 180 graus exclusive.
static func curva(pi: Vector2, dir_a: Vector2, dir_b: Vector2, novo_raio: float,
		nova_fracao: float) -> Manobra:
	var m := Manobra.new()
	m.tipo = Tipo.CURVA
	m.raio = novo_raio
	m.fracao = nova_fracao
	var tabela := _integrar(rumo_de(dir_a), rumo_de(dir_b), novo_raio, nova_fracao, DS, SUB)
	var pts: PackedVector2Array = tabela[0]
	var fim := pts[pts.size() - 1]
	# Curva simetrica: o vetor do inicio ao fim e paralelo a (a + b), e o
	# comeco fica a `recuo` antes do encontro, o fim a `recuo` depois.
	var ab := dir_a + dir_b
	m.recuo = fim.dot(ab) / maxf(ab.length_squared(), 1e-6)
	var inicio := pi - dir_a * m.recuo
	for k in pts.size():
		pts[k] += inicio
	m._pts = pts
	m._rumos = tabela[1]
	m._curvs = tabela[2]
	m._ds = tabela[3]
	m.comprimento = float(pts.size() - 1) * m._ds
	return m


## Meia volta em arco puro, de uma faixa para a do outro sentido. So existe
## para o fim de linha (esquina cujas saidas sao todas becos), que a escolha de
## saida evita; e o ultimo recurso, e nao um movimento de rua.
static func retorno(inicio: Vector2, dir_a: Vector2, novo_raio: float) -> Manobra:
	var m := Manobra.new()
	m.tipo = Tipo.CURVA
	m.raio = novo_raio
	var ra := rumo_de(dir_a)
	var tabela := _integrar(ra, ra + PI, novo_raio, 0.0, DS, SUB)
	var pts: PackedVector2Array = tabela[0]
	for k in pts.size():
		pts[k] += inicio
	m._pts = pts
	m._rumos = tabela[1]
	m._curvs = tabela[2]
	m._ds = tabela[3]
	m.comprimento = float(pts.size() - 1) * m._ds
	return m


## Tabela [pontos, rumos, curvaturas, passo] da curva comecando na origem com
## rumo `ra` e terminando com rumo `rb`. Curvatura linear por partes (espiral,
## arco, espiral), integrada com trapezio no rumo e ponto medio na posicao.
static func _integrar(ra: float, rb: float, r: float, f: float, ds_alvo: float,
		sub: int) -> Array:
	var giro := wrapf(rb - ra, -PI, PI)
	if absf(absf(giro) - PI) < 1e-3:
		giro = PI
	var sinal := 1.0 if giro >= 0.0 else -1.0
	var th := absf(giro)
	var ths := th * clampf(f, 0.0, 0.5)
	var ls := 2.0 * r * ths
	var la := r * (th - 2.0 * ths)
	var total := 2.0 * ls + la
	var n := maxi(2, ceili(total / ds_alvo))
	var ds := total / float(n)
	var h := ds / float(sub)
	var pts := PackedVector2Array()
	var rumos := PackedFloat32Array()
	var curvs := PackedFloat32Array()
	pts.resize(n + 1)
	rumos.resize(n + 1)
	curvs.resize(n + 1)
	var x := 0.0
	var z := 0.0
	var g := ra
	var s := 0.0
	pts[0] = Vector2.ZERO
	rumos[0] = g
	curvs[0] = _kappa(0.0, ls, la, total, r, sinal)
	for i in n:
		for _j in sub:
			var k0 := _kappa(s, ls, la, total, r, sinal)
			var k1 := _kappa(s + h, ls, la, total, r, sinal)
			var g1 := g + h * 0.5 * (k0 + k1)
			var gm := g + h * 0.25 * (3.0 * k0 + k1) * 0.5
			x += -sin(gm) * h
			z += -cos(gm) * h
			g = g1
			s += h
		pts[i + 1] = Vector2(x, z)
		rumos[i + 1] = g
		curvs[i + 1] = _kappa(s, ls, la, total, r, sinal)
	return [pts, rumos, curvs, ds]


static func _kappa(s: float, ls: float, la: float, total: float, r: float,
		sinal: float) -> float:
	if ls <= 1e-6:
		return sinal / r
	if s < ls:
		return sinal * maxf(s, 0.0) / (ls * r)
	if s < ls + la:
		return sinal / r
	return sinal * maxf(total - s, 0.0) / (ls * r)


# --- leitura ---------------------------------------------------------------

## (x, z, rumo, curvatura) no comprimento `s` deste pedaco.
func amostra(s: float) -> Vector4:
	if tipo == Tipo.RETA:
		var p := _a + _dir * s
		var rumo := _rumo
		var k := 0.0
		if (_d0 != 0.0 or _d1 != 0.0 or _m0 != 0.0) and s >= _l_ini:
			var l := _l_fim - _l_ini
			var d := _d1
			var d1 := 0.0
			var d2 := 0.0
			if l > 1e-4 and s < _l_fim:
				var u := (s - _l_ini) / l
				var q := _suave(u)
				var hq := _hermite(u)
				d = _d0 * (1.0 - q.x) + _d1 * q.x + _m0 * l * hq.x
				d1 = ((_d1 - _d0) * q.y + _m0 * l * hq.y) / l
				d2 = ((_d1 - _d0) * q.z + _m0 * l * hq.z) / (l * l)
			p += _esq * d
			rumo += atan(d1)
			k = d2 / pow(1.0 + d1 * d1, 1.5)
		elif _d0 != 0.0 or _m0 != 0.0:
			# Antes do desvio comecar: segue afastado do mesmo tanto.
			p += _esq * _d0
		return Vector4(p.x, p.y, rumo, k)
	var t := clampf(s / _ds, 0.0, float(_pts.size() - 1))
	var i := mini(floori(t), _pts.size() - 2)
	var f := t - float(i)
	var q2 := _pts[i].lerp(_pts[i + 1], f)
	return Vector4(q2.x, q2.y, lerp_angle(_rumos[i], _rumos[i + 1], f),
		lerpf(_curvs[i], _curvs[i + 1], f))


func inicio() -> Vector2:
	var a := amostra(0.0)
	return Vector2(a.x, a.y)


func fim() -> Vector2:
	var a := amostra(comprimento)
	return Vector2(a.x, a.y)


## Tem curvatura em algum lugar? A reta sem desvio nao entra na conta de
## velocidade de curva.
func curva_alguma() -> bool:
	return tipo == Tipo.CURVA or _d0 != 0.0 or _d1 != 0.0 or _m0 != 0.0


## A maior |curvatura| de cada metro, amostrada a cada 25 cm. O motorista le
## isto a cada passo de fisica para saber a que velocidade pode chegar em cada
## metro dos proximos quarenta; amostrar o caminho ali custaria centenas de
## `amostra` por quadro na frota.
func preparar_faixas() -> void:
	kbins = PackedFloat32Array()
	if not curva_alguma():
		return
	var n := ceili(comprimento)
	kbins.resize(n)
	for b in n:
		var maior := 0.0
		for q in 5:
			maior = maxf(maior, absf(amostra(minf(float(b) + float(q) * 0.25,
				comprimento)).w))
		kbins[b] = maior


# --- utilidades ------------------------------------------------------------

static func rumo_de(d: Vector2) -> float:
	return atan2(-d.x, -d.y)


static func dir_de(rumo: float) -> Vector2:
	return Vector2(-sin(rumo), -cos(rumo))


static func esquerda_de(rumo: float) -> Vector2:
	return Vector2(-cos(rumo), sin(rumo))


## Degrau suave de quinta ordem e as duas derivadas em u.
static func _suave(u: float) -> Vector3:
	u = clampf(u, 0.0, 1.0)
	var u2 := u * u
	var u3 := u2 * u
	return Vector3(u3 * (10.0 - 15.0 * u + 6.0 * u2),
		30.0 * u2 * (1.0 - 2.0 * u + u2),
		60.0 * u * (1.0 - 3.0 * u + 2.0 * u2))


## Base de Hermite quintica da inclinacao inicial: vale 0 nas pontas, derivada
## 1 no inicio e 0 no fim, curvatura 0 nas duas.
static func _hermite(u: float) -> Vector3:
	u = clampf(u, 0.0, 1.0)
	var u2 := u * u
	var u3 := u2 * u
	return Vector3(u - 6.0 * u3 + 8.0 * u3 * u - 3.0 * u3 * u2,
		1.0 - 18.0 * u2 + 32.0 * u3 - 15.0 * u3 * u,
		-36.0 * u + 96.0 * u2 - 60.0 * u3)


# --- a curva do cruzamento -------------------------------------------------

## As curvas ja escolhidas, por geometria de esquina. Poucas chaves: a malha
## tem duas classes de rua e tres faixas possiveis.
static var _escolhas: Dictionary = {}
## O pior custo de uma escolha nova, em ms. Lido pela bancada.
static var custo_escolha_ms := 0.0


## A curva do cruzamento (i, j) para quem chega pelo trecho `de` e sai pelo
## `para` (os dois com faixa). Raio e espiral sao os mais abertos que deixam
## folga de `FOLGA_ALVO` entre a lataria e o eixo, o meio-fio e a borda da
## pista de saida (ver `_folga`).
static func curva_de_cruzamento(i: int, j: int, de: Vector4i, para: Vector4i) -> Manobra:
	# A mesma esquina da a mesma curva a todo carro, e quem planeja pede as duas
	# conversoes de cada cruzamento para pesar a escolha. So o fio principal
	# chama; sem trava. O que o motorista pendura na curva (trecho, seta, via)
	# tambem e o mesmo para todos.
	var chave := Vector4i(i, j, de.x * 1000 + de.z * 10 + (de.w + 1),
		para.x * 1000 + para.z * 10 + (para.w + 1))
	var pronta: Variant = _curvas.get(chave)
	if pronta != null:
		return pronta
	if _curvas.size() >= TETO_CURVAS:
		_curvas.clear()
	var m := _curva_de_cruzamento(i, j, de, para)
	_curvas[chave] = m
	return m


static var _curvas: Dictionary = {}
const TETO_CURVAS := 2000


## Onde a faixa de `de` cruza a de `para` no cruzamento (i, j), em planta. E o
## `Vias.ponto_de_curva` sem a altura: aquele pergunta ao `Relevo`, que na
## primeira vez de uma celula custava ate 116 ms na bancada, e aqui so se usa x
## e z.
static func encontro(i: int, j: int, de: Vector4i, para: Vector4i) -> Vector2:
	var x := float(i) * Vias.TAM
	var z := float(j) * Vias.TAM
	if de.z == 0:
		x = Vias.linha_x(i, de.w, de.x)
	elif para.z == 0:
		x = Vias.linha_x(i, para.w, para.x)
	if de.z == 1:
		z = Vias.linha_z(j, de.w, de.x)
	elif para.z == 1:
		z = Vias.linha_z(j, para.w, para.x)
	return Vector2(x, z)


static func _curva_de_cruzamento(i: int, j: int, de: Vector4i, para: Vector4i) -> Manobra:
	var pi := encontro(i, j, de, para)
	var da3 := Vias.direcao(de.z, de.w)
	var db3 := Vias.direcao(para.z, para.w)
	var dir_a := Vector2(da3.x, da3.z)
	var dir_b := Vector2(db3.x, db3.z)
	var escolha := escolher_raio(geometria(i, j, de, para))
	return curva(pi, dir_a, dir_b, escolha.x, escolha.y)


## A esquina reduzida ao que a curva enxerga, no referencial em que se chega
## andando para +Z com o centro na origem: [lado (+1 direita, -1 esquerda),
## afastamento da faixa de chegada ao eixo dela, afastamento da faixa de saida
## ao eixo dela, meia largura do asfalto da rua de chegada, meia largura do
## asfalto da rua de saida, meia pista da rua de saida].
static func geometria(i: int, j: int, de: Vector4i, para: Vector4i) -> PackedFloat32Array:
	var cx := float(i) * Vias.TAM
	var cz := float(j) * Vias.TAM
	var lane_ap := (absf(Vias.linha_x(i, de.w, de.x) - cx) if de.z == 0
		else absf(Vias.linha_z(j, de.w, de.x) - cz))
	var lane_sai := (absf(Vias.linha_x(i, para.w, para.x) - cx) if para.z == 0
		else absf(Vias.linha_z(j, para.w, para.x) - cz))
	var asf_ap := (Vias.meia_asfalto_x_no(i, j) if de.z == 0
		else Vias.meia_asfalto_z_no(i, j))
	var asf_sai := (Vias.meia_asfalto_x_no(i, j) if para.z == 0
		else Vias.meia_asfalto_z_no(i, j))
	var meia_sai := Vias.meia_x(i) if para.z == 0 else Vias.meia_z(j)
	return PackedFloat32Array([float(lado_da_curva(de, para)), lane_ap, lane_sai,
		asf_ap, asf_sai, meia_sai])


## +1 se ir de `de` para `para` e virar a DIREITA, -1 a esquerda, 0 reto.
##
## Andando para +Z a direita e -X (Vias, "mao de direcao"), e (+Z) x (-X) tem
## y NEGATIVO. A IA antiga (`Carro._lado_da_curva`) tomava y > 0 como direita e
## acendia a seta do lado oposto ao da curva.
static func lado_da_curva(de: Vector4i, para: Vector4i) -> int:
	var y := Vias.direcao(de.z, de.w).cross(Vias.direcao(para.z, para.w)).y
	if absf(y) < 0.05:
		return 0
	return 1 if y < 0.0 else -1


## As oito esquinas que a malha tem, ja resolvidas: lado | afastamento da faixa
## de chegada | da de saida | asfalto da chegada | da saida | meia pista da
## saida -> (raio, fracao). A busca (`_buscar_raio`) custa ate 12 ms na
## primeira vez de cada geometria — engasgo de quadro no meio da rua —, entao
## o resultado dela mora aqui, e a bancada confere que ainda e o mesmo
## (`conferir_tabela`). Geometria fora da tabela cai na busca, uma vez.
const TABELA := {
	"1|1.50|1.50|4.80|4.80|3.00": Vector2(7.5, 0.35),
	"-1|1.50|1.50|4.80|4.80|3.00": Vector2(7.5, 0.35),
	"1|1.50|3.38|4.80|6.70|4.50": Vector2(8.0, 0.2),
	"-1|1.50|1.13|4.80|6.70|4.50": Vector2(6.5, 0.2),
	"1|3.38|3.38|6.70|6.70|4.50": Vector2(8.5, 0.2),
	"-1|1.13|1.13|6.70|6.70|4.50": Vector2(8.0, 0.2),
	"1|3.38|1.50|6.70|4.80|3.00": Vector2(7.5, 0.35),
	"-1|1.13|1.50|6.70|4.80|3.00": Vector2(5.5, 0.25),
}


static func _chave(g: PackedFloat32Array) -> String:
	return "%d|%.2f|%.2f|%.2f|%.2f|%.2f" % [int(g[0]), g[1], g[2], g[3], g[4], g[5]]


## (raio, fracao) para uma esquina.
static func escolher_raio(g: PackedFloat32Array) -> Vector2:
	var chave := _chave(g)
	var achada: Variant = _escolhas.get(chave)
	if achada != null:
		return achada
	var tabelada: Variant = TABELA.get(chave)
	if tabelada != null:
		_escolhas[chave] = tabelada
		return tabelada
	push_warning("Manobra: esquina fora da tabela (%s); buscando raio" % chave)
	var saida := _buscar_raio(g)
	_escolhas[chave] = saida
	return saida


## Refaz a busca de cada linha da `TABELA` e devolve as que mudaram, como
## "chave: tabela -> busca". Vazio: a tabela ainda e o que a busca escolhe.
static func conferir_tabela() -> Array[String]:
	var diferentes: Array[String] = []
	for chave: String in TABELA:
		var partes := chave.split("|")
		var g := PackedFloat32Array()
		for p in partes:
			g.append(p.to_float())
		var busca := _buscar_raio(g)
		if not busca.is_equal_approx(TABELA[chave]):
			diferentes.append("%s: %s -> %s" % [chave, TABELA[chave], busca])
	return diferentes


## O raio mais aberto, e a espiral, com a folga pedida; sem nenhum que a
## tenha, o de maior folga.
static func _buscar_raio(g: PackedFloat32Array) -> Vector2:
	var t0 := Time.get_ticks_usec()
	var melhor := Vector3(-INF, 0.0, 0.0)  # folga, raio, fracao
	var saida := Vector2.ZERO
	for r: float in RAIOS:
		var deste := Vector3(-INF, r, 0.0)
		for f: float in FRACOES:
			var fo := _folga(g, r, f)
			if fo > deste.x:
				deste = Vector3(fo, r, f)
			if fo > melhor.x:
				melhor = Vector3(fo, r, f)
		if deste.x >= FOLGA_ALVO:
			saida = Vector2(deste.y, deste.z)
			break
	if saida == Vector2.ZERO:
		saida = Vector2(melhor.y, melhor.z)
	custo_escolha_ms = maxf(custo_escolha_ms, float(Time.get_ticks_usec() - t0) / 1000.0)
	return saida


## A menor folga da curva (raio `r`, fracao `f`) na esquina `g`, com o carro
## envelope andando pelo eixo traseiro. Negativa: algum canto passa do eixo de
## uma das ruas fora do miolo do cruzamento, sobe na calcada, ou (na esquerda)
## entra na faixa de estacionamento da rua de saida.
static func _folga(g: PackedFloat32Array, r: float, f: float) -> float:
	var lado := g[0]
	var lane_ap := g[1]
	var lane_sai := g[2]
	var asf_ap := g[3]
	var asf_sai := g[4]
	var meia_sai := g[5]
	var a := Vector2(0.0, 1.0)
	var b := Vector2(-1.0, 0.0) if lado > 0.0 else Vector2(1.0, 0.0)
	var pi := Vector2(-lane_ap, -lane_sai if lado > 0.0 else lane_sai)
	var tabela := _integrar(rumo_de(a), rumo_de(b), r, f, 0.25, 4)
	var pts: PackedVector2Array = tabela[0]
	var rumos: PackedFloat32Array = tabela[1]
	var fim := pts[pts.size() - 1]
	var ab := a + b
	var recuo_c := fim.dot(ab) / ab.length_squared()
	var inicio := pi - a * recuo_c
	var pior := INF
	# A curva, e um trecho de reta depois dela: a lataria ainda esta torta
	# quando o eixo traseiro sai da espiral.
	var extra := 12
	for k in pts.size() + extra:
		var p: Vector2
		var rumo: float
		if k < pts.size():
			p = inicio + pts[k]
			rumo = rumos[k]
		else:
			p = inicio + fim + b * float(k - pts.size() + 1) * 0.4
			rumo = rumos[rumos.size() - 1]
		var frente := dir_de(rumo)
		var esq := esquerda_de(rumo)
		var centro := p + frente * (ENVELOPE_EIXO * 0.5)
		for sf: float in [1.0, -1.0]:
			for sl: float in [1.0, -1.0]:
				var c := centro + frente * (sf * ENVELOPE_COMP * 0.5) \
					+ esq * (sl * ENVELOPE_LARG * 0.5)
				pior = minf(pior, _folga_canto(c, lado, asf_ap, asf_sai, meia_sai))
	return pior


static func _folga_canto(c: Vector2, lado: float, asf_ap: float, asf_sai: float,
		meia_sai: float) -> float:
	var ax := absf(c.x)
	var az := absf(c.y)
	# Calcada: o quarteirao da esquina e o que fica fora do asfalto das duas
	# ruas ao mesmo tempo. Distancia assinada ate ele: so a penetracao nao
	# bastava, porque a folga pedida nunca entrava na conta e o canto de dentro
	# da direita saia raspando a quina (0 a 5 cm na bancada).
	var dx := ax - asf_ap
	var dz := az - asf_sai
	var folga: float
	if dx > 0.0 and dz > 0.0:
		folga = -minf(dx, dz)
	elif dx > 0.0:
		folga = -dz
	elif dz > 0.0:
		folga = -dx
	else:
		folga = sqrt(dx * dx + dz * dz)
	# Braco de chegada (antes do miolo): a mao e x < 0.
	if c.y < -asf_sai and ax <= asf_ap + 5.0:
		folga = minf(folga, -c.x)
	# Braco de saida (alem do miolo): a mao e o lado de dentro do eixo, e a
	# esquerda nao passa da borda da pista (a faixa de estacionamento fica fora).
	if ax > asf_ap:
		var lat := -c.y if lado > 0.0 else c.y
		folga = minf(folga, lat)
		if lado < 0.0:
			folga = minf(folga, meia_sai - lat)
	return folga
