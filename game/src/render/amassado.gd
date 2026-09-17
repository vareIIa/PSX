## A lataria amassa onde bateu (PLANO_AAA_4K, Fase 7, A20).
##
## O que faz
## ---------
## Uma batida vira um campo de deslocamento: um ponto, uma direcao para DENTRO
## do carro, um raio e uma profundidade. Todo vertice dentro do raio anda para
## dentro, com queda suave ate a borda e uma ruga que depende do lugar — chapa
## amassada nao e uma tigela lisa, e o que o olho usa para ler "amassado" em vez
## de "modelo com defeito" e justamente a ruga.
##
## Por que na CPU, e nao no shader
## -------------------------------
## O shader da lataria e o mesmo `psx_surface` de toda superficie do jogo, com
## trabalho de outra sessao em cima, e um mapa de deslocamento por carro pediria
## uniforme por instancia em todos eles. Aqui a malha e reescrita uma vez por
## batida — batida e rara, e o carro do jogador e um so — e o resultado vale nos
## dois presets sem ninguem tocar em shader.
##
## A lataria e montada por carro (`Carroceria.montar` roda a cada `_ready`),
## entao amassar uma nao amassa as outras do mesmo modelo.
##
## Por que numa thread
## -------------------
## A primeira versao fazia tudo no quadro da batida e custou 508 ms: a frente do
## sedan e um quadro grande, e para ela acompanhar o amassado ela precisa ser
## dividida (ver `_subdividir`). Meio segundo de tela parada no instante da
## pancada e o pior engasgo possivel. Agora a conta roda no `WorkerThreadPool`,
## sobre arrays lidos UMA vez em `preparar` (ler malha de volta do servidor de
## renderizacao trava o quadro — memoria da Fase 6), e o quadro principal so
## sobe a malha pronta. O amassado aparece alguns quadros depois da pancada, que
## e o tempo de o som da batida ainda estar tocando.
##
## Por que a cabine amassa junto
## -----------------------------
## A cabine do jogador e desenhada 2 cm por DENTRO da lataria. Se so a chapa
## andasse 10 cm para dentro, ela atravessaria o forro da porta e o jogador veria
## a lataria de fora brotando dentro do carro. Medido na bancada de batida, por
## raio saindo do olho do motorista: amassando so a lataria, a chapa aparece na
## frente do forro em 76 de 151 raios (eram 9 antes da batida); amassando as
## duas, em 7.
##
## As batidas ficam guardadas: a cabine e desmontada quando o jogador desce e
## montada de novo quando ele sobe, e sem o historico ela voltaria lisa dentro
## de uma lataria torta.
class_name Amassado
extends RefCounted

## Uma rodada de amassado terminou e a malha ja esta na tela.
signal amassou(maior: float)

## Raio do amassado, de uma batida leve a uma em cheio, em metros.
const RAIO_MIN := 0.32
const RAIO_MAX := 0.72
## Profundidade no centro, em metros. Doze centimetros e um para-choque que
## entrou de verdade; mais que isso e o que o jogo nao tem para mostrar — motor,
## longarina — e a malha viraria um buraco.
const FUNDO_MIN := 0.02
const FUNDO_MAX := 0.12
## Quanto um vertice pode andar, somando todas as batidas.
const FUNDO_TETO := 0.16
## Quanto a ruga mexe na profundidade, para mais e para menos.
const RUGA := 0.45
## Batida mais fraca que isto nao marca a chapa: encostar num poste a 10 km/h
## faz barulho e nao faz amassado.
const FORCA_MINIMA := 0.12
## Profundidade (para dentro do carro, a partir da chapa) ate onde o amassado
## vale inteiro, e onde ele acaba. A chapa e o forro da porta estao a poucos
## centimetros um do outro e precisam receber o MESMO deslocamento; o banco, a
## meio metro, nao deve receber nenhum.
const PROFUNDO_CHEIO := 0.25
const PROFUNDO_FIM := 0.5
## A maior aresta que pode sobrar dentro do amassado, e quantas vezes a malha
## pode ser dividida para chegar la. Ver `_subdividir`.
const ARESTA_MAX := 0.2
const NIVEIS_MAX := 3

## As batidas, em espaco do carro: [ponto, direcao, raio, fundo].
var batidas: Array[Array] = []
## O maior deslocamento da ultima rodada, em metros.
var ultimo: float = 0.0
## Quanto a ultima rodada custou NO QUADRO PRINCIPAL, e quanto demorou da
## pancada ate a tela, em milissegundos.
var custo_principal_ms: float = 0.0
var atraso_ms: float = 0.0

## Por malha (id da instancia): o no, os arrays de cada superficie e as posicoes
## de nascimento. Lido uma vez, em `preparar`, e depois so a thread mexe.
var _cache: Dictionary = {}
var _tarefa: int = -1
var _fila: Array[Dictionary] = []
var _job: Dictionary = {}


## Le as malhas uma vez. Chame no quadro principal, fora da hora da batida.
func preparar(carro: Node3D, alvos: Array[MeshInstance3D], dividir: bool = true) -> void:
	for m: MeshInstance3D in alvos:
		if m == null or not is_instance_valid(m) or m.mesh == null:
			continue
		var id := m.get_instance_id()
		if _cache.has(id):
			continue
		var malha := m.mesh as ArrayMesh
		if malha == null:
			continue
		var sups: Array = []
		for s in malha.get_surface_count():
			var arrays := malha.surface_get_arrays(s)
			sups.append({
				"arrays": arrays,
				"original": (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate(),
				"material": malha.surface_get_material(s),
				"prim": malha.surface_get_primitive_type(s),
			})
		_cache[id] = {
			"no": weakref(m),
			"sups": sups,
			"x": carro.global_transform.affine_inverse() * m.global_transform,
			"dividir": dividir,
			"caixa": malha.get_aabb(),
		}


## Registra uma batida e manda amassar todas as malhas preparadas.
func bater(ponto: Vector3, dentro: Vector3, forca: float) -> bool:
	if forca < FORCA_MINIMA or dentro.length_squared() < 0.0001:
		return false
	var f := clampf((forca - FORCA_MINIMA) / (1.0 - FORCA_MINIMA), 0.0, 1.0)
	var batida := [ponto, dentro.normalized(), lerpf(RAIO_MIN, RAIO_MAX, f),
		lerpf(FUNDO_MIN, FUNDO_MAX, f)]
	batidas.append(batida)
	_enfileirar(_entradas(_cache.keys()), [batida])
	return true


## A mesma conta, mas so nas malhas pedidas e sem guardar a batida. E o controle
## da bancada: amassar so a lataria, para provar que a sonda enxerga o defeito.
func bater_so(alvos: Array[MeshInstance3D], ponto: Vector3, dentro: Vector3,
		forca: float) -> void:
	var f := clampf((forca - FORCA_MINIMA) / (1.0 - FORCA_MINIMA), 0.0, 1.0)
	var batida := [ponto, dentro.normalized(), lerpf(RAIO_MIN, RAIO_MAX, f),
		lerpf(FUNDO_MIN, FUNDO_MAX, f)]
	var ids: Array = []
	for m: MeshInstance3D in alvos:
		ids.append(m.get_instance_id())
	_enfileirar(_entradas(ids), [batida])


## Cabine nova, batidas velhas: prepara as malhas e passa TODAS as batidas nelas.
func reaplicar(carro: Node3D, alvos: Array[MeshInstance3D]) -> void:
	preparar(carro, alvos)
	if batidas.is_empty():
		return
	var ids: Array = []
	for m: MeshInstance3D in alvos:
		if m != null and is_instance_valid(m):
			ids.append(m.get_instance_id())
	_enfileirar(_entradas(ids), batidas.duplicate())


func ocupado() -> bool:
	return _tarefa >= 0 or not _fila.is_empty()


## Quanto o campo desloca um ponto do espaco do carro.
func deslocamento(p: Vector3) -> Vector3:
	var total := Vector3.ZERO
	for b: Array in batidas:
		total += _campo(p, b)
	if total.length() > FUNDO_TETO:
		total = total.normalized() * FUNDO_TETO
	return total


## Desloca um array de vertices a partir das posicoes de nascimento, com TODAS
## as batidas. Sem divisao e sem thread: e para malha pequena que tem dono
## proprio, como as luzes do `Carro`.
func deslocar(v: PackedVector3Array, originais: PackedVector3Array,
		x: Transform3D) -> void:
	var volta := x.affine_inverse()
	for k in mini(v.size(), originais.size()):
		var p := x * originais[k]
		v[k] = volta * (p + deslocamento(p))


# --- fila e thread ----------------------------------------------------------

func _entradas(ids: Array) -> Array:
	var saida: Array = []
	for id in ids:
		var e: Dictionary = _cache.get(id, {})
		if e.is_empty():
			continue
		var no := (e["no"] as WeakRef).get_ref() as MeshInstance3D
		if no == null:
			_cache.erase(id)
			continue
		saida.append(e)
	return saida


func _enfileirar(entradas: Array, quais: Array) -> void:
	if entradas.is_empty():
		return
	_fila.append({
		"entradas": entradas,
		"quais": quais,
		"inicio": Time.get_ticks_usec(),
		"maior": 0.0,
		"mudadas": [],
	})
	_rodar_proxima()


func _rodar_proxima() -> void:
	if _tarefa >= 0 or _fila.is_empty():
		return
	_job = _fila.pop_front()
	_tarefa = WorkerThreadPool.add_task(_trabalhar, false, "amassado")


## Na thread: so matematica sobre os arrays do cache. Nada aqui toca no servidor
## de renderizacao nem em no da arvore.
func _trabalhar() -> void:
	var maior := 0.0
	var mudadas: Array = []
	for e: Dictionary in _job["entradas"]:
		var x: Transform3D = e["x"]
		var caixa: AABB = x * (e["caixa"] as AABB)
		var perto := false
		for b: Array in _job["quais"]:
			if caixa.grow(float(b[2])).has_point(b[0] as Vector3):
				perto = true
				break
		if not perto:
			continue
		var mexeu := false
		for sup: Dictionary in e["sups"]:
			var arrays: Array = sup["arrays"]
			var original: PackedVector3Array = sup["original"]
			if e["dividir"]:
				for b: Array in _job["quais"]:
					original = _subdividir(arrays, original, x, b)
				sup["original"] = original
			var m := _deslocar_superficie(arrays, original, x, _job["quais"])
			if m > 0.0:
				mexeu = true
			maior = maxf(maior, m)
		if mexeu:
			mudadas.append(e)
	_job["maior"] = maior
	_job["mudadas"] = mudadas
	_publicar.call_deferred()


## No quadro principal: sobe as malhas prontas e chama a proxima rodada.
func _publicar() -> void:
	if _tarefa >= 0:
		WorkerThreadPool.wait_for_task_completion(_tarefa)
	_tarefa = -1
	var t0 := Time.get_ticks_usec()
	for e: Dictionary in _job["mudadas"]:
		var no := (e["no"] as WeakRef).get_ref() as MeshInstance3D
		if no == null:
			continue
		var malha := no.mesh as ArrayMesh
		if malha == null:
			continue
		malha.clear_surfaces()
		for sup: Dictionary in e["sups"]:
			malha.add_surface_from_arrays(sup["prim"], sup["arrays"])
			if sup["material"] != null:
				malha.surface_set_material(malha.get_surface_count() - 1, sup["material"])
		e["caixa"] = malha.get_aabb()
	custo_principal_ms = (Time.get_ticks_usec() - t0) / 1000.0
	atraso_ms = (Time.get_ticks_usec() - int(_job["inicio"])) / 1000.0
	ultimo = float(_job["maior"])
	_job = {}
	amassou.emit(ultimo)
	_rodar_proxima()


# --- o campo ----------------------------------------------------------------

## Desloca uma superficie a partir das posicoes de nascimento. Devolve o maior
## deslocamento.
static func _deslocar_superficie(arrays: Array, original: PackedVector3Array,
		x: Transform3D, quais: Array) -> float:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var volta := x.affine_inverse()
	var antes := v.duplicate()
	var maior := 0.0
	var mexeu := false
	for k in v.size():
		var p := x * original[k]
		var atual := x * v[k]
		var novo := atual
		for b: Array in quais:
			novo += _campo(p, b)
		var total := novo - p
		if total.length() > FUNDO_TETO:
			novo = p + total.normalized() * FUNDO_TETO
		if novo.is_equal_approx(atual):
			continue
		v[k] = volta * novo
		maior = maxf(maior, novo.distance_to(p))
		mexeu = true
	if mexeu:
		arrays[Mesh.ARRAY_VERTEX] = v
		_corrigir_normais(arrays, antes, v)
	return maior


## O deslocamento de um ponto por uma batida.
##
## A queda e a ruga sao medidas NO PLANO da chapa, e nao em linha reta: assim
## dois pontos um atras do outro — chapa e forro da porta — andam exatamente
## igual por construcao, em vez de quase igual. E a profundidade corta o
## amassado antes do banco e do volante, que estao a meio metro da chapa e nao
## tem por que entortar numa batida de porta.
static func _campo(p: Vector3, b: Array) -> Vector3:
	var centro: Vector3 = b[0]
	var dentro: Vector3 = b[1]
	var raio: float = b[2]
	var rel := p - centro
	var profundo := rel.dot(dentro)
	var plano := rel - dentro * profundo
	var d := plano.length()
	if d >= raio or profundo >= PROFUNDO_FIM:
		return Vector3.ZERO
	var t := d / raio
	var queda := (1.0 - t * t) * (1.0 - t * t)
	queda *= 1.0 - smoothstep(PROFUNDO_CHEIO, PROFUNDO_FIM, profundo)
	# Ruga: funcao do LUGAR no plano, e nao sorteio — a mesma batida da o mesmo
	# amassado na lataria, na cabine e em duas execucoes.
	var eixo_u := _eixo_u(dentro)
	var eixo_v := dentro.cross(eixo_u).normalized()
	var u := plano.dot(eixo_u)
	var w := plano.dot(eixo_v)
	var ruga := sin(u * 29.0 + w * 7.0) * cos(w * 23.0 - u * 5.0)
	var fundo: float = b[3]
	return dentro * fundo * queda * (1.0 + RUGA * ruga)


static func _eixo_u(dentro: Vector3) -> Vector3:
	var u := dentro.cross(Vector3.UP)
	if u.length_squared() < 1e-4:
		u = dentro.cross(Vector3.RIGHT)
	return u.normalized()


# --- divisao ----------------------------------------------------------------

## Divide em quatro todo triangulo grande que encosta no amassado.
##
## Por que existe. A primeira foto do sedan batido de frente mostrou a grade e
## a placa SUMIDAS. A frente do carro e um quadro grande com vertice so nas
## quinas: as quinas ficam na borda do amassado e quase nao andam, enquanto a
## grade (peca pequena, no meio) anda treze centimetros e some atras de uma
## chapa que continuou reta. Amassar vertice so funciona onde ha vertice.
##
## "Encosta" e medido de verdade: a distancia, no plano da chapa, do centro do
## amassado ate o TRIANGULO. A primeira versao usava o centro do triangulo mais
## o raio dele, e triangulo grande encostava em tudo — a frente do sedan foi de
## 598 para 10.423 triangulos.
##
## Regras, todas para nao abrir fresta:
##
## - Vertice novo vai para o FIM dos arrays. Os antigos mantem o indice, e quem
##   guardou "o vertice 40" antes da batida continua achando ele.
## - O ponto medio de uma aresta e criado uma vez so por par de indices.
## - Fechamento: triangulo que encosta no amassado e divide uma aresta com um
##   triangulo dividido tambem e dividido, mesmo sendo pequeno; senao o ponto
##   medio anda e o vizinho inteiro nao, e abre uma fenda em T. A comparacao e
##   por POSICAO, e nao por indice, porque aresta viva da malha tem vertice
##   duplicado dos dois lados (normal diferente).
## - Triangulo que nao encosta no amassado nao e dividido, e nao precisa: todo
##   ponto dele esta fora do campo, entao o ponto medio de uma aresta dele nao
##   anda.
##
## `originais` acompanha: o original de um vertice novo e o meio dos originais.
static func _subdividir(arrays: Array, originais: PackedVector3Array,
		x: Transform3D, b: Array) -> PackedVector3Array:
	var idx_var = arrays[Mesh.ARRAY_INDEX]
	if idx_var == null or (idx_var as PackedInt32Array).is_empty():
		return originais
	var centro: Vector3 = b[0]
	var dentro: Vector3 = b[1]
	var raio: float = b[2]
	var eixo_u := _eixo_u(dentro)
	var eixo_v := dentro.cross(eixo_u).normalized()
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var extras := {
		"n": arrays[Mesh.ARRAY_NORMAL],
		"uv": arrays[Mesh.ARRAY_TEX_UV],
		"uv2": arrays[Mesh.ARRAY_TEX_UV2],
		"cor": arrays[Mesh.ARRAY_COLOR],
		"tan": arrays[Mesh.ARRAY_TANGENT],
	}
	var orig := originais.duplicate()
	var idx: PackedInt32Array = idx_var
	for _nivel in NIVEIS_MAX:
		var total := idx.size() / 3
		# Posicao no plano da chapa, e profundidade, de cada vertice.
		var plano := PackedVector2Array()
		var fundo := PackedFloat32Array()
		plano.resize(orig.size())
		fundo.resize(orig.size())
		for k in orig.size():
			var rel := x * orig[k] - centro
			plano[k] = Vector2(rel.dot(eixo_u), rel.dot(eixo_v))
			fundo[k] = rel.dot(dentro)
		var toca := PackedByteArray()
		var marcado := PackedByteArray()
		toca.resize(total)
		marcado.resize(total)
		var algum := false
		for t in total:
			var a := idx[t * 3]
			var bb := idx[t * 3 + 1]
			var c := idx[t * 3 + 2]
			if minf(fundo[a], minf(fundo[bb], fundo[c])) >= PROFUNDO_FIM:
				continue
			if not _toca_disco(plano[a], plano[bb], plano[c], raio):
				continue
			toca[t] = 1
			var aresta := maxf((x.basis * (orig[a] - orig[bb])).length(), maxf(
				(x.basis * (orig[bb] - orig[c])).length(),
				(x.basis * (orig[c] - orig[a])).length()))
			if aresta > ARESTA_MAX:
				marcado[t] = 1
				algum = true
		if not algum:
			break
		# Fechamento por posicao, so entre triangulos que encostam.
		var mudou := true
		while mudou:
			mudou = false
			var cortadas := {}
			for t in total:
				if marcado[t] == 0:
					continue
				for e in 3:
					cortadas[_chave_aresta(orig[idx[t * 3 + e]],
						orig[idx[t * 3 + (e + 1) % 3]])] = true
			for t in total:
				if marcado[t] == 1 or toca[t] == 0:
					continue
				for e in 3:
					if cortadas.has(_chave_aresta(orig[idx[t * 3 + e]],
							orig[idx[t * 3 + (e + 1) % 3]])):
						marcado[t] = 1
						mudou = true
						break
		var meios := {}
		var novo_idx := PackedInt32Array()
		for t in total:
			var a := idx[t * 3]
			var bb := idx[t * 3 + 1]
			var c := idx[t * 3 + 2]
			if marcado[t] == 0:
				novo_idx.append(a)
				novo_idx.append(bb)
				novo_idx.append(c)
				continue
			var mab := _meio(a, bb, meios, v, orig, extras)
			var mbc := _meio(bb, c, meios, v, orig, extras)
			var mca := _meio(c, a, meios, v, orig, extras)
			for q: int in [a, mab, mca, mab, bb, mbc, mca, mbc, c, mab, mbc, mca]:
				novo_idx.append(q)
		idx = novo_idx
	arrays[Mesh.ARRAY_INDEX] = idx
	arrays[Mesh.ARRAY_VERTEX] = v
	if extras["n"] != null:
		arrays[Mesh.ARRAY_NORMAL] = extras["n"]
	if extras["uv"] != null:
		arrays[Mesh.ARRAY_TEX_UV] = extras["uv"]
	if extras["uv2"] != null:
		arrays[Mesh.ARRAY_TEX_UV2] = extras["uv2"]
	if extras["cor"] != null:
		arrays[Mesh.ARRAY_COLOR] = extras["cor"]
	if extras["tan"] != null:
		arrays[Mesh.ARRAY_TANGENT] = extras["tan"]
	# Qualquer outro array por vertice que este arquivo nao sabe dividir sai da
	# malha: com tamanho errado o motor recusa a superficie INTEIRA.
	for k in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2,
			Mesh.ARRAY_CUSTOM3, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
		arrays[k] = null
	return orig


## O triangulo (ja no plano da chapa, com o centro do amassado na origem)
## encosta no disco do amassado?
static func _toca_disco(a: Vector2, b: Vector2, c: Vector2, raio: float) -> bool:
	if Geometry2D.point_is_inside_triangle(Vector2.ZERO, a, b, c):
		return true
	var r2 := raio * raio
	if Geometry2D.get_closest_point_to_segment(Vector2.ZERO, a, b).length_squared() < r2:
		return true
	if Geometry2D.get_closest_point_to_segment(Vector2.ZERO, b, c).length_squared() < r2:
		return true
	return Geometry2D.get_closest_point_to_segment(Vector2.ZERO, c, a).length_squared() < r2


## Chave de aresta por posicao, igual nos dois sentidos.
static func _chave_aresta(a: Vector3, b: Vector3) -> int:
	var ka := _chave_ponto(a)
	var kb := _chave_ponto(b)
	return mini(ka, kb) * 1000003 + maxi(ka, kb)


static func _chave_ponto(p: Vector3) -> int:
	var q := Vector3i((p * 5000.0).round())
	return (q.x * 73856093) ^ (q.y * 19349663) ^ (q.z * 83492791)


## O vertice do meio de uma aresta, criado uma vez e posto no fim dos arrays.
##
## Os atributos opcionais vao num dicionario so para caber numa chamada: no
## Godot 4.7 array empacotado e passado por REFERENCIA, como parametro e dentro
## do dicionario (medido), entao o `append` aqui cresce o array de quem chamou.
static func _meio(a: int, b: int, meios: Dictionary, v: PackedVector3Array,
		orig: PackedVector3Array, extras: Dictionary) -> int:
	var chave := Vector2i(mini(a, b), maxi(a, b))
	if meios.has(chave):
		return meios[chave]
	var i := v.size()
	v.append((v[a] + v[b]) * 0.5)
	orig.append((orig[a] + orig[b]) * 0.5)
	if extras["n"] != null:
		var n: PackedVector3Array = extras["n"]
		var soma: Vector3 = n[a] + n[b]
		n.append(soma.normalized() if soma.length_squared() > 1e-8 else n[a])
	if extras["uv"] != null:
		var uv: PackedVector2Array = extras["uv"]
		uv.append((uv[a] + uv[b]) * 0.5)
	if extras["uv2"] != null:
		var uv2: PackedVector2Array = extras["uv2"]
		uv2.append((uv2[a] + uv2[b]) * 0.5)
	if extras["cor"] != null:
		var cor: PackedColorArray = extras["cor"]
		cor.append(cor[a].lerp(cor[b], 0.5))
	if extras["tan"] != null:
		# Quatro por vertice: direcao e o sinal da bitangente.
		var tan: PackedFloat32Array = extras["tan"]
		var ta := Vector3(tan[a * 4], tan[a * 4 + 1], tan[a * 4 + 2])
		var tb := Vector3(tan[b * 4], tan[b * 4 + 1], tan[b * 4 + 2])
		var tm := ta + tb
		tm = tm.normalized() if tm.length_squared() > 1e-8 else ta
		tan.append(tm.x)
		tan.append(tm.y)
		tan.append(tm.z)
		tan.append(tan[a * 4 + 3])
	meios[chave] = i
	return i


## Gira a normal de cada vertice pelo quanto os triangulos em volta giraram.
##
## Recalcular a normal do zero trocaria a sombra de pecas que nao amassaram —
## a normal autoral de uma chapa curva nao e a media das faces dela. Somando so
## a DIFERENCA de face antes e depois, quem nao se mexeu fica exatamente como
## estava, e a borda do amassado nao vira uma costura de luz.
static func _corrigir_normais(arrays: Array, antes: PackedVector3Array,
		depois: PackedVector3Array) -> void:
	var normais = arrays[Mesh.ARRAY_NORMAL]
	if normais == null or (normais as PackedVector3Array).size() != depois.size():
		return
	var n: PackedVector3Array = normais
	var indices = arrays[Mesh.ARRAY_INDEX]
	var tri: PackedInt32Array
	if indices != null and (indices as PackedInt32Array).size() > 0:
		tri = indices
	else:
		tri = PackedInt32Array()
		tri.resize(depois.size())
		for k in depois.size():
			tri[k] = k
	var giro := PackedVector3Array()
	giro.resize(depois.size())
	var tocado := PackedByteArray()
	tocado.resize(depois.size())
	for t in range(0, tri.size() - 2, 3):
		var a := tri[t]
		var b := tri[t + 1]
		var c := tri[t + 2]
		if depois[a] == antes[a] and depois[b] == antes[b] and depois[c] == antes[c]:
			continue
		var f0 := (antes[b] - antes[a]).cross(antes[c] - antes[a])
		var f1 := (depois[b] - depois[a]).cross(depois[c] - depois[a])
		if f0.length_squared() < 1e-12 or f1.length_squared() < 1e-12:
			continue
		var d := f1.normalized() - f0.normalized()
		for i: int in [a, b, c]:
			giro[i] = giro[i] + d
			tocado[i] = 1
	for k in n.size():
		if tocado[k] == 0:
			continue
		var novo := n[k] + giro[k]
		if novo.length_squared() > 1e-8:
			n[k] = novo.normalized()
	arrays[Mesh.ARRAY_NORMAL] = n
