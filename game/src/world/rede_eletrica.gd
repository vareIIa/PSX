## A rede eletrica da rua: onde fica cada poste e que poste se liga a qual.
##
## Por que existe
## -------------
## Cada chunk tinha um poste so, na calcada da rua em X se houvesse uma e na da
## rua em Z se nao, e o cabo ia em linha reta desse poste ate o dos chunks +X e
## +Z. Quando um estava na rua em X e o outro na rua em Z, o vao cortava o lote
## na diagonal: fio entrando por uma casa e saindo pela outra, em todo
## quarteirao de esquina.
##
## A regra que impede isso
## -----------------------
## Um vao so liga dois postes do MESMO corredor de rua — a faixa entre as duas
## fachadas, que so tem asfalto, calcada e ar. Postes de trechos seguidos da
## mesma linha, de qualquer lado dela, estao no mesmo corredor, e o segmento
## entre eles tambem (a faixa e convexa, e atravessa o cruzamento reto). Virar
## a esquina pede um poste de esquina, na calcada da quina: o vao dele para cada
## rua fica dentro da uniao dos dois corredores.
##
##   poste de luz    o de sempre (ChunkBuilder._poste_local), um por chunk, com a
##                   lampada. Lugar ao longo da rua intocado: arvore, porta de
##                   loja e orelhao desviam dele desde antes.
##   poste de rede   o trecho de rua sem poste de luz ganha um, sem lampada. Ele
##                   desvia de arvore e de porta, e nao o contrario: plantar ou
##                   tirar arvore arrasta o rng do chunk e muda o resto dele.
##   poste de esquina  onde uma linha termina num cruzamento (T ou L), liga o
##                   ultimo poste dela ao primeiro da transversal.
##
## Tudo e funcao pura da coordenada, como MalhaUrbana: o chunk desenha o vao ate
## o poste do vizinho sem que o vizinho esteja carregado, e a arvore sabe onde
## passa o fio para abrir a poda antes de o fio existir.
##
## Convencao de linha (a de Vias): eixo 0 e a linha x = linha * 32, que corre em
## Z, com o trecho `k` entre z = k * 32 e (k + 1) * 32; eixo 1 e a linha
## z = linha * 32, que corre em X. `lado` +1 e a calcada do chunk do lado
## positivo da linha, -1 a do negativo.
class_name RedeEletrica
extends RefCounted

const TAM := 32.0

## Do centro do poste ate a face do meio-fio. Poste de concessionaria fica na
## faixa de servico, colado na guia — a 80 cm, onde estava, ele tomava o meio da
## calcada de 2,2 m e empurrava o pedestre para a fachada.
const DA_GUIA := 0.4

## Quanto o poste de esquina fica alem do meio-fio da transversal. Na quina ja
## moram o semaforo (a 0,88 das duas guias) e o sinal de pedestre (a 0,38):
## com 1,3 m o poste fica a quase um metro dos dois.
const ESQUINA_ALEM := 1.3

## Folga do poste de rede ate a caixa da travessia e ate tronco e porta.
const FOLGA_TRAVESSIA := 1.0
const FOLGA_ARVORE := 2.2
const FOLGA_PORTA := 2.6

## Onde o poste de rede tenta ficar ao longo do trecho, em ordem de preferencia.
const CANDIDATOS: Array[float] = [16.0, 13.5, 18.5, 11.0, 21.0, 9.0, 23.0, 7.5, 24.5]

## Cache dos postes por trecho. Os chunks vizinhos perguntam pelos mesmos
## trechos, e o poste de rede consulta a arborizacao do chunk, que nao e barata.
## Montado de varias threads ao mesmo tempo, dai a trava.
static var _cache: Dictionary = {}
static var _cruzetas: Dictionary = {}
static var _trava := Mutex.new()
const CACHE_MAXIMO := 8192


# --- linha e trecho -------------------------------------------------------------

static func via(eixo: int, linha: int, k: int) -> int:
	return MalhaUrbana.via_x_em(linha, k) if eixo == 0 else MalhaUrbana.via_z_em(linha, k)


## Rua e avenida tem poste; viela nao (e o unico lugar escuro da cidade).
static func acesa(v: int) -> bool:
	return v == MalhaUrbana.Via.RUA or v == MalhaUrbana.Via.AVENIDA


## O chunk dono da calcada `lado` do trecho.
static func chunk_do_lado(eixo: int, linha: int, k: int, lado: int) -> Vector2i:
	var l := linha if lado > 0 else linha - 1
	return Vector2i(l, k) if eixo == 0 else Vector2i(k, l)


## A borda do chunk dono que encosta no trecho.
static func borda(eixo: int, lado: int) -> String:
	if eixo == 0:
		return "x0" if lado > 0 else "x1"
	return "z0" if lado > 0 else "z1"


## A borda em que o poste de luz do chunk fica: a mesma prioridade de
## ChunkBuilder._poste_local (rua em X antes da rua em Z, borda 0 antes da 1).
static func borda_da_luz(b: Dictionary) -> String:
	for chave: String in ["x0", "x1", "z0", "z1"]:
		if acesa(b[chave]):
			return chave
	return ""


## Direcao da linha (para onde o trecho corre) e o vetor que sai da calcada
## `lado` e aponta para o eixo da rua.
static func direcao(eixo: int) -> Vector3:
	return Vector3(0.0, 0.0, 1.0) if eixo == 0 else Vector3(1.0, 0.0, 0.0)


static func para_rua(eixo: int, lado: int) -> Vector3:
	return Vector3(-float(lado), 0.0, 0.0) if eixo == 0 else Vector3(0.0, 0.0, -float(lado))


## Ponto do mundo na calcada do trecho, `ao_longo` metros do inicio dele e
## `afast` metros do eixo da linha. Y no chao do morro, em cima da guia.
static func ponto(eixo: int, linha: int, k: int, lado: int, ao_longo: float,
		afast: float) -> Vector3:
	var p: Vector3
	if eixo == 0:
		p = Vector3(linha * TAM + float(lado) * afast, 0.0, k * TAM + ao_longo)
	else:
		p = Vector3(k * TAM + ao_longo, 0.0, linha * TAM + float(lado) * afast)
	p.y = KitModular.ALTURA_MEIO_FIO + Relevo.altura(p.x, p.z)
	return p


## O carater da linha, por celula entre avenidas: a linha inteira de uma rua sai
## igual de ponta a ponta, e a avenida inteira tambem.
##
##   mt    media tensao (cruzeta com tres fases la no alto). A avenida e o
##         alimentador; quase metade das ruas leva ramal de media.
##   bt    0 multiplexado (um cabo preto trancado), 1 armacao secundaria antiga
##         (tres fios nus na vertical, a cara da cidade do interior).
##   tel   quantos cabos de telefone e TV correm embaixo, de um a tres.
static func linha_info(eixo: int, linha: int, k: int) -> Dictionary:
	var avenida := posmod(linha, MalhaUrbana.PERIODO) == 0
	var celula := 0 if avenida else floori(float(k) / MalhaUrbana.PERIODO)
	var h := MalhaUrbana._ruido(eixo * 7919 + linha, celula, 5501)
	return {
		"mt": avenida or h % 100 < 45,
		"bt": 1 if (h / 100) % 5 < 2 else 0,
		"tel": 1 + (h / 1000) % 3,
	}


# --- postes ---------------------------------------------------------------------

## Os postes do trecho, um por calcada no maximo. Vazio se o trecho nao e rua.
##
## Cada poste: pe (mundo, no chao), eixo, linha, k, lado, luz, esquina, rua (o
## vetor horizontal para o lado de onde a cruzeta abre), dir (ao longo da
## linha), chunk (o dono), mt/bt/tel.
static func postes_do_trecho(eixo: int, linha: int, k: int) -> Array[Dictionary]:
	var chave := Vector3i(eixo, linha, k)
	_trava.lock()
	var guardado: Variant = _cache.get(chave)
	_trava.unlock()
	if guardado != null:
		return guardado
	var saida := _montar_trecho(eixo, linha, k)
	_trava.lock()
	if _cache.size() > CACHE_MAXIMO:
		_cache.clear()
	_cache[chave] = saida
	_trava.unlock()
	return saida


static func _montar_trecho(eixo: int, linha: int, k: int) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var v := via(eixo, linha, k)
	if not acesa(v):
		return saida
	var afast := MalhaUrbana.meia_asfalto(v) + DA_GUIA
	for lado: int in [1, -1]:
		var c := chunk_do_lado(eixo, linha, k, lado)
		var b := MalhaUrbana.bordas(c.x, c.y)
		if borda_da_luz(b) != borda(eixo, lado):
			continue
		var local := ChunkBuilder._poste_local(b)
		var ao_longo := local.z if eixo == 0 else local.x
		saida.append(_poste(eixo, linha, k, lado, ponto(eixo, linha, k, lado, ao_longo, afast),
			true))
	if saida.is_empty():
		var lado := _lado_da_rede(eixo, linha, k)
		saida.append(_poste(eixo, linha, k, lado, ponto(eixo, linha, k, lado,
			_ao_longo_da_rede(eixo, linha, k, lado, afast), afast), false))
	return saida


static func _poste(eixo: int, linha: int, k: int, lado: int, pe: Vector3, luz: bool) -> Dictionary:
	var info := linha_info(eixo, linha, k)
	return {
		"pe": pe, "eixo": eixo, "linha": linha, "k": k, "lado": lado,
		"luz": luz, "esquina": false,
		"rua": para_rua(eixo, lado), "dir": direcao(eixo),
		"chunk": chunk_do_lado(eixo, linha, k, lado),
		"mt": bool(info["mt"]), "bt": int(info["bt"]), "tel": int(info["tel"]),
	}


## De que lado o trecho sem poste de luz ganha o poste de rede. Um lado so por
## linha dentro da celula: a posteacao corre de um lado da rua e so troca de
## calcada onde outro poste obriga.
static func _lado_da_rede(eixo: int, linha: int, k: int) -> int:
	var celula := floori(float(k) / MalhaUrbana.PERIODO)
	return 1 if MalhaUrbana._ruido(eixo * 131 + linha, celula, 6607) % 2 == 0 else -1


## Onde, ao longo do trecho, o poste de rede fica: longe da travessia das duas
## pontas, do tronco das arvores da mesma calcada e da porta do chunk.
static func _ao_longo_da_rede(eixo: int, linha: int, k: int, lado: int, afast: float) -> float:
	var c := chunk_do_lado(eixo, linha, k, lado)
	var origem := Vector3(c.x * TAM, 0.0, c.y * TAM)
	var obstaculos: Array[Vector3] = ChunkBuilder.arvores(c.x, c.y)
	var porta := ChunkBuilder._porta_do_chunk(c.x, c.y, MalhaUrbana.quadra_de(c.x, c.y))
	var inicio := _fim_da_travessia(eixo, linha, k)
	var fim := TAM - _fim_da_travessia(eixo, linha, k + 1)
	for ao_longo: float in CANDIDATOS:
		if ao_longo < inicio or ao_longo > fim:
			continue
		var p := ponto(eixo, linha, k, lado, ao_longo, afast) - origem
		var livre := true
		for o: Vector3 in obstaculos:
			if Vector2(o.x - p.x, o.z - p.z).length() < FOLGA_ARVORE:
				livre = false
				break
		if livre and not porta.is_empty():
			var pp: Vector3 = porta["pos"]
			if Vector2(pp.x - p.x, pp.z - p.z).length() < FOLGA_PORTA:
				livre = false
		if livre:
			return ao_longo
	return TAM * 0.5


## Quanto da ponta do trecho a caixa da travessia do no ocupa (zero sem
## cruzamento). `no_k` e o indice do no ao longo da linha.
static func _fim_da_travessia(eixo: int, linha: int, no_k: int) -> float:
	var i := linha if eixo == 0 else no_k
	var j := no_k if eixo == 0 else linha
	if not Vias.existe_cruzamento(i, j):
		return 2.0
	var meia := Vias.meia_asfalto_z_no(i, j) if eixo == 0 else Vias.meia_asfalto_x_no(i, j)
	return ChunkBuilder.vao_travessia(meia) + FOLGA_TRAVESSIA


# --- ligacoes -------------------------------------------------------------------

## Os pares de postes entre dois trechos seguidos da mesma linha: mesma calcada
## com mesma calcada; e, se cada trecho so tem um poste e eles estao em lados
## opostos, o vao atravessa a rua na diagonal — dentro do corredor do mesmo jeito.
static func _pares(a: Array[Dictionary], b: Array[Dictionary]) -> Array:
	var pares: Array = []
	for pa: Dictionary in a:
		for pb: Dictionary in b:
			if int(pa["lado"]) == int(pb["lado"]):
				pares.append([pa, pb])
	if pares.is_empty() and a.size() == 1 and b.size() == 1:
		pares.append([a[0], b[0]])
	return pares


## O poste `p` tem vao ao longo da propria linha (para tras ou para a frente)?
static func _tem_vao_na_linha(p: Dictionary) -> bool:
	var e := int(p["eixo"])
	var l := int(p["linha"])
	var k := int(p["k"])
	var aqui := postes_do_trecho(e, l, k)
	for par: Array in _pares(aqui, postes_do_trecho(e, l, k + 1)):
		if _mesmo(par[0], p):
			return true
	for par: Array in _pares(postes_do_trecho(e, l, k - 1), aqui):
		if _mesmo(par[1], p):
			return true
	return false


static func _mesmo(a: Dictionary, b: Dictionary) -> bool:
	return (a["pe"] as Vector3).is_equal_approx(b["pe"])


## As viradas de esquina do no (i, j): onde uma linha termina no cruzamento, o
## ultimo poste dela se liga ao primeiro da transversal por um poste na quina.
##
##   L    as duas linhas terminam: uma virada, na quina de dentro.
##   T    a haste termina: vira para o braco do lado do poste dela.
##   X    nada termina, nada vira. Beco sem saida tambem nao: la o ultimo poste
##        fica com estai.
##
## Cada virada: {"poste": o de esquina, "de": ultimo poste da linha que termina,
## "ate": primeiro poste da transversal}.
static func viradas(i: int, j: int) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var n := acesa(via(0, i, j))
	var s := acesa(via(0, i, j - 1))
	var l := acesa(via(1, j, i))
	var o := acesa(via(1, j, i - 1))
	var x_termina := n != s
	var z_termina := l != o
	if not (n or s) or not (l or o):
		return saida
	if not x_termina and not z_termina:
		return saida
	# A linha que termina e a haste; se as duas terminam (L), a haste e a de X e
	# a quina e a de dentro.
	var haste_eixo := 0 if x_termina else 1
	var sinal_haste: int
	var sinal_braco: int
	var haste: Array[Dictionary]
	if haste_eixo == 0:
		sinal_haste = 1 if n else -1
		haste = postes_do_trecho(0, i, j if n else j - 1)
		if z_termina:
			sinal_braco = 1 if l else -1
		else:
			sinal_braco = _lado_preferido(haste, sinal_haste, 0)
	else:
		sinal_haste = 1 if l else -1
		haste = postes_do_trecho(1, j, i if l else i - 1)
		sinal_braco = _lado_preferido(haste, sinal_haste, 1)
	if haste.is_empty():
		return saida
	# Quina (sx, sz) do no. A haste em X corre em Z: o sinal dela e sz.
	var sx := sinal_braco if haste_eixo == 0 else sinal_haste
	var sz := sinal_haste if haste_eixo == 0 else sinal_braco
	var braco: Array[Dictionary]
	if haste_eixo == 0:
		braco = postes_do_trecho(1, j, i if sx > 0 else i - 1)
	else:
		braco = postes_do_trecho(0, i, j if sz > 0 else j - 1)
	if braco.is_empty():
		return saida
	# O ultimo da haste: o da calcada da quina, se houver dois.
	var lado_haste := sx if haste_eixo == 0 else sz
	var de: Dictionary = haste[0]
	for p: Dictionary in haste:
		if int(p["lado"]) == lado_haste:
			de = p
	# O primeiro do braco: o da calcada do lado de onde a haste chega.
	var lado_braco := sz if haste_eixo == 0 else sx
	var ate: Dictionary = braco[0]
	for p: Dictionary in braco:
		if int(p["lado"]) == lado_braco:
			ate = p
	saida.append({"poste": _poste_de_esquina(i, j, sx, sz, haste_eixo, de), "de": de, "ate": ate})
	return saida


## Para que lado da haste a virada vai no T: o do braco que fica do lado do
## poste da haste, e o outro so se aquele nao existe.
static func _lado_preferido(haste: Array[Dictionary], _sinal_haste: int, haste_eixo: int) -> int:
	var lado := int(haste[0]["lado"]) if not haste.is_empty() else 1
	# Na haste em X o lado e +X/-X, que e o braco leste/oeste; na haste em Z, o
	# lado e +Z/-Z, braco norte/sul. Quem chama confere se o braco existe.
	var i_ou_j := int(haste[0]["linha"]) if not haste.is_empty() else 0
	var k := int(haste[0]["k"]) if not haste.is_empty() else 0
	# O no da ponta da haste e o que chamou; o braco do lado `lado` existe?
	if haste_eixo == 0:
		var j := k + 1 if _sinal_haste < 0 else k
		if acesa(via(1, j, i_ou_j if lado > 0 else i_ou_j - 1)):
			return lado
	else:
		var i := k + 1 if _sinal_haste < 0 else k
		if acesa(via(0, i, i_ou_j if lado > 0 else i_ou_j - 1)):
			return lado
	return -lado


## O poste da quina (sx, sz) do no (i, j), na calcada da haste, ESQUINA_ALEM
## depois da guia da transversal.
static func _poste_de_esquina(i: int, j: int, sx: int, sz: int, haste_eixo: int,
		de: Dictionary) -> Dictionary:
	var centro := Vector3(i * TAM, 0.0, j * TAM)
	var vx := via(0, i, j if sz > 0 else j - 1)
	var vz := via(1, j, i if sx > 0 else i - 1)
	if not acesa(vx):
		vx = via(0, i, j - 1 if sz > 0 else j)
	if not acesa(vz):
		vz = via(1, j, i - 1 if sx > 0 else i)
	var mx := MalhaUrbana.meia_asfalto(vx)
	var mz := MalhaUrbana.meia_asfalto(vz)
	var off: Vector3
	if haste_eixo == 0:
		off = Vector3(float(sx) * (mx + DA_GUIA), 0.0, float(sz) * (mz + DA_GUIA + ESQUINA_ALEM))
	else:
		off = Vector3(float(sx) * (mx + DA_GUIA + ESQUINA_ALEM), 0.0, float(sz) * (mz + DA_GUIA))
	var pe := centro + off
	pe.y = KitModular.ALTURA_MEIO_FIO + Relevo.altura(pe.x, pe.z)
	var chunk := Vector2i(i if sx > 0 else i - 1, j if sz > 0 else j - 1)
	return {
		"pe": pe, "eixo": haste_eixo, "linha": int(de["linha"]), "k": int(de["k"]),
		"lado": int(de["lado"]), "luz": false, "esquina": true,
		"rua": Vector3(-float(sx), 0.0, -float(sz)).normalized(),
		"dir": direcao(haste_eixo), "chunk": chunk,
		"mt": bool(de["mt"]), "bt": int(de["bt"]), "tel": int(de["tel"]),
	}


# --- o que o chunk monta --------------------------------------------------------

## Os postes que ficam dentro do chunk (os das quatro calcadas e os de esquina).
static func postes_do_chunk(cx: int, cz: int) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var dono := Vector2i(cx, cz)
	for t: Vector4i in _trechos_do_chunk(cx, cz):
		for p: Dictionary in postes_do_trecho(t.x, t.y, t.z):
			if int(p["lado"]) == t.w:
				saida.append(p)
	for v: Dictionary in _viradas_perto(cx, cz):
		if Vector2i(v["poste"]["chunk"]) == dono:
			saida.append(v["poste"])
	return saida


## As quatro calcadas do chunk como (eixo, linha, k, lado).
static func _trechos_do_chunk(cx: int, cz: int) -> Array[Vector4i]:
	return [Vector4i(0, cx, cz, 1), Vector4i(0, cx + 1, cz, -1),
		Vector4i(1, cz, cx, 1), Vector4i(1, cz + 1, cx, -1)]


## As viradas dos quatro nos das quinas do chunk.
static func _viradas_perto(cx: int, cz: int) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for dx in 2:
		for dz in 2:
			saida.append_array(viradas(cx + dx, cz + dz))
	return saida


## Os vaos que o chunk desenha, cada um uma vez na cidade inteira:
##   ao longo da linha   quem desenha e o dono do poste do trecho de tras;
##   travessia           o poste do lado +1, quando um dos dois ficaria sem vao;
##   virada              o dono do poste de esquina desenha os dois lances.
## Cada vao: {"a": poste, "b": poste, "tipo": &"linha"|&"travessia"|&"virada"}.
static func vaos_do_chunk(cx: int, cz: int) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var dono := Vector2i(cx, cz)
	for t: Vector4i in _trechos_do_chunk(cx, cz):
		var aqui := postes_do_trecho(t.x, t.y, t.z)
		for par: Array in _pares(aqui, postes_do_trecho(t.x, t.y, t.z + 1)):
			if int(par[0]["lado"]) == t.w and Vector2i(par[0]["chunk"]) == dono:
				saida.append({"a": par[0], "b": par[1], "tipo": &"linha"})
		if aqui.size() == 2 and t.w == 1:
			var mais: Dictionary = aqui[0] if int(aqui[0]["lado"]) == 1 else aqui[1]
			var menos: Dictionary = aqui[1] if int(aqui[0]["lado"]) == 1 else aqui[0]
			if not _tem_vao_na_linha(mais) or not _tem_vao_na_linha(menos):
				saida.append({"a": mais, "b": menos, "tipo": &"travessia"})
	for v: Dictionary in _viradas_perto(cx, cz):
		if Vector2i(v["poste"]["chunk"]) != dono:
			continue
		saida.append({"a": v["de"], "b": v["poste"], "tipo": &"virada"})
		saida.append({"a": v["poste"], "b": v["ate"], "tipo": &"virada"})
	return saida


## Todo vao que encosta no poste `p`, desenhado por quem for. Serve para o estai:
## poste com um vao so e fim de linha, e a tracao dele puxa para um lado.
static func vaos_do_poste(p: Dictionary) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var c: Vector2i = p["chunk"]
	# Um vao que toca p e desenhado por p ou por um chunk vizinho do dele.
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for v: Dictionary in vaos_do_chunk(c.x + dx, c.y + dz):
				if _mesmo(v["a"], p) or _mesmo(v["b"], p):
					saida.append(v)
	return saida


## Os vaos que passam por cima do chunk, desenhados por ele ou pelos vizinhos.
## A arvore le isto para abrir a poda.
static func vaos_perto(cx: int, cz: int) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var caixa := Rect2(cx * TAM - 2.0, cz * TAM - 2.0, TAM + 4.0, TAM + 4.0)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for v: Dictionary in vaos_do_chunk(cx + dx, cz + dz):
				var a: Vector3 = v["a"]["pe"]
				var b: Vector3 = v["b"]["pe"]
				var r := Rect2(Vector2(minf(a.x, b.x), minf(a.z, b.z)), Vector2.ZERO) \
					.expand(Vector2(maxf(a.x, b.x), maxf(a.z, b.z)))
				if r.grow(0.5).intersects(caixa):
					saida.append(v)
	return saida


## Os postes que podem mandar ramal para uma fachada da linha `eixo, linha` no
## trecho `k`: os das duas calcadas do trecho e dos dois vizinhos. Quem escolhe
## e o chunk da casa (ChunkBuilder._ramais), que conhece a fachada.
static func postes_para_ramal(eixo: int, linha: int, k: int) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for dk in range(-1, 2):
		saida.append_array(postes_do_trecho(eixo, linha, k + dk))
	return saida


## Para onde a cruzeta do poste abre: perpendicular a direcao media dos vaos
## dele, do lado da rua.
##
## Poste de meio de quarteirao tem os dois vaos ao longo da calcada, e a cruzeta
## sai perpendicular a guia, sobre a rua. O que manda um vao atravessando a rua
## nao pode: com a cruzeta na direcao do vao, cada fase de media passava por
## cima dos outros dois isoladores. A media dos vaos e feita no dobro do
## angulo (direcao sem sentido: ir e voltar e o mesmo eixo), e a cruzeta fica
## na perpendicular.
static func cruzeta(p: Dictionary) -> Vector3:
	var chave := Vector3i((Vector3(p["pe"]) * 100.0).round())
	_trava.lock()
	var guardado: Variant = _cruzetas.get(chave)
	_trava.unlock()
	if guardado != null:
		return guardado
	var rua: Vector3 = p["rua"]
	var aqui: Vector3 = p["pe"]
	var soma := Vector2.ZERO
	var saindo := Vector2.ZERO
	for v: Dictionary in vaos_do_poste(p):
		var outro: Vector3 = v["b"]["pe"] if _mesmo(v["a"], p) else v["a"]["pe"]
		var d := Vector2(outro.x - aqui.x, outro.z - aqui.z)
		if d.length_squared() < 1e-4:
			continue
		d = d.normalized()
		saindo += d
		var ang := d.angle()
		soma += Vector2(cos(2.0 * ang), sin(2.0 * ang))
	var saida := rua
	var eixo := NAN
	if soma.length() > 0.2:
		eixo = soma.angle() * 0.5
	elif saindo.length() > 0.2:
		# Dois vaos em angulo reto (ao longo da calcada e atravessando a rua): a
		# media no dobro do angulo zera. A cruzeta fica na bissetriz, e cada
		# vao sai dela a 45 graus.
		eixo = saindo.angle()
	if is_finite(eixo):
		var perp := Vector3(-sin(eixo), 0.0, cos(eixo))
		saida = perp if perp.dot(rua) >= 0.0 else -perp
	_trava.lock()
	if _cruzetas.size() > CACHE_MAXIMO:
		_cruzetas.clear()
	_cruzetas[chave] = saida
	_trava.unlock()
	return saida
