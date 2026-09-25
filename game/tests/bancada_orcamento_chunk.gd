## Onde estao os triangulos de um chunk: no que se ve ate o horizonte (casca) ou
## no que some a 40 m (balde @perto).
##
##     godot --headless --path game res://tests/bancada_orcamento_chunk.tscn
##     ... -- --raio=5              chunks de -5 a 5 (o mesmo alcance do teste_cidade)
##     ... -- --coords=2,-9;0,0     so estes, com os materiais mais caros de cada balde
##     ... -- --top=12              quantos materiais listar por balde
##     ... -- --pecas               tambem por peca (material#cor do vertice), com a
##                                  area media do triangulo; sem --coords, somada
##     ... -- --achar=metal#2a2c2e  onde a peca esta: chunks, altura e as primeiras
##                                  posicoes no mundo (para achar a peca no codigo)
##
## Por que existe
## -------------
## Os verificadores (cidade, bar, lojas) tem UM teto por chunk, somando tudo. Mas
## o chunk paga duas contas diferentes: a casca e desenhada em todo chunk dentro
## do alcance visual (96 a 192 m, uma centena deles), e o @perto so nos que estao
## a menos de ALCANCE_PERTO do jogador (uma dezena). Um triangulo de casca custa
## dez vezes o de @perto na tela. Esta regua separa as duas contas e diz que
## material pesa em cada uma, para o detalhe ir para o balde certo em vez de sair.
##
## Saida: `[orcamento] chunk=cx,cz total= casca= perto= longe=` por chunk e, no
## fim, media, p90 e pior de cada balde. `casca` inclui o balde @longe (a versao
## barata de uma miudeza, que troca com o @perto a ALCANCE_PERTO): e o que o chunk
## custa visto de longe. `vista_perto` e casca - longe + perto: o que ele custa
## com o jogador em volta. `total` soma os dois niveis e nao e custo de nada.
extends Node

var _coords: Array[Vector2i] = []
var _detalhe := false
var _top := 12
var _pecas := false
## Soma das pecas de casca de todos os chunks: chave -> [triangulos, area].
var _soma_pecas := {}
var _achar := ""
var _achados := 0


func _ready() -> void:
	var raio := 5
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--raio="):
			raio = arg.trim_prefix("--raio=").to_int()
		elif arg.begins_with("--achar="):
			_achar = arg.trim_prefix("--achar=")
		elif arg == "--pecas":
			_pecas = true
		elif arg.begins_with("--top="):
			_top = arg.trim_prefix("--top=").to_int()
		elif arg.begins_with("--coords="):
			for par: String in arg.trim_prefix("--coords=").split(";"):
				var p := par.split(",")
				_coords.append(Vector2i(p[0].to_int(), p[1].to_int()))
			_detalhe = true
	if _coords.is_empty():
		for cz in range(-raio, raio + 1):
			for cx in range(-raio, raio + 1):
				_coords.append(Vector2i(cx, cz))

	var cascas: Array[int] = []
	var pertos: Array[int] = []
	var longes: Array[int] = []
	var vistas_perto: Array[int] = []
	var totais: Array[int] = []
	var por_mat_casca := {}
	var por_mat_perto := {}
	for c: Vector2i in _coords:
		var dados := ChunkBuilder.construir(c.x, c.y)
		var sup: Dictionary = dados["superficies"]
		var casca := 0
		var perto := 0
		var longe := 0
		var mats := {}
		for mat: StringName in sup:
			var n := PSXMesh.dados_triangulos(sup[mat])
			if n == 0:
				continue
			mats[mat] = n
			if ChunkManager.e_perto(mat):
				perto += n
				por_mat_perto[mat] = int(por_mat_perto.get(mat, 0)) + n
			else:
				casca += n
				por_mat_casca[mat] = int(por_mat_casca.get(mat, 0)) + n
				if ChunkManager.e_longe(mat):
					longe += n
		if not _achar.is_empty():
			_procurar(c, sup)
		cascas.append(casca)
		pertos.append(perto)
		longes.append(longe)
		vistas_perto.append(casca - longe + perto)
		totais.append(casca + perto)
		print("[orcamento] chunk=%d,%d total=%d casca=%d perto=%d longe=%d vista_perto=%d props=%d"
			% [c.x, c.y, casca + perto, casca, perto, longe, casca - longe + perto,
			(dados["props"] as Array).size()])
		if _detalhe:
			_listar("  casca", mats, false)
			_listar("  perto", mats, true)
			if _pecas:
				_imprimir_pecas(_contar_pecas(sup, {}))
		elif _pecas:
			_contar_pecas(sup, _soma_pecas)

	print("[orcamento] chunks=%d" % _coords.size())
	_resumo("total", totais)
	_resumo("casca", cascas)
	_resumo("perto", pertos)
	_resumo("longe", longes)
	_resumo("vista_perto", vistas_perto)
	if not _detalhe:
		_listar("soma casca", por_mat_casca, false)
		_listar("soma perto", por_mat_perto, true)
		if _pecas:
			_imprimir_pecas(_soma_pecas)
	get_tree().quit(0)


func _listar(rotulo: String, mats: Dictionary, perto: bool) -> void:
	var lista: Array = []
	for m: StringName in mats:
		if ChunkManager.e_perto(m) == perto:
			lista.append([m, int(mats[m])])
	lista.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	var linha := "[orcamento] %s:" % rotulo
	for i in mini(_top, lista.size()):
		linha += " %s=%d" % [lista[i][0], lista[i][1]]
	print(linha)


func _resumo(rotulo: String, v: Array[int]) -> void:
	if v.is_empty():
		return
	var s := v.duplicate()
	s.sort()
	var soma := 0
	for x: int in s:
		soma += x
	print("[orcamento] %s media=%d p90=%d pior=%d" % [rotulo, soma / s.size(),
		s[int(float(s.size() - 1) * 0.9)], s[s.size() - 1]])


## Triangulos de casca por peca (material#cor do primeiro vertice), com a area
## media do triangulo: peca fina e repetida (grade, barra, degrau) e a que vira
## sub-pixel a 60 m e so pisca.
func _contar_pecas(sup: Dictionary, pecas: Dictionary) -> Dictionary:
	for mat: StringName in sup:
		if ChunkManager.e_perto(mat):
			continue
		var d: Dictionary = sup[mat]
		var v: PackedVector3Array = d["v"]
		var idx: PackedInt32Array = d.get("i", PackedInt32Array())
		var cores: PackedColorArray = d.get("c", PackedColorArray())
		for t in range(0, idx.size(), 3):
			var i0 := idx[t]
			var chave := "%s#%s" % [mat, cores[i0].to_html(false) if i0 < cores.size() else "-"]
			var a := v[i0]
			var area := (v[idx[t + 1]] - a).cross(v[idx[t + 2]] - a).length() * 0.5
			var q: Array = pecas.get(chave, [0, 0.0])
			q[0] += 1
			q[1] += area
			pecas[chave] = q
	return pecas


func _imprimir_pecas(pecas: Dictionary) -> void:
	var lista: Array = []
	for k: String in pecas:
		lista.append([k, pecas[k][0], pecas[k][1]])
	lista.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	for i in mini(_top * 2, lista.size()):
		print("[orcamento]    %-34s tris=%6d  area_media=%.4f m2" % [lista[i][0], lista[i][1],
			lista[i][2] / float(lista[i][1])])


func _procurar(c: Vector2i, sup: Dictionary) -> void:
	var mat := StringName(_achar.get_slice("#", 0))
	var cor := _achar.get_slice("#", 1)
	if not sup.has(mat):
		return
	var d: Dictionary = sup[mat]
	var v: PackedVector3Array = d["v"]
	var idx: PackedInt32Array = d.get("i", PackedInt32Array())
	var cores: PackedColorArray = d.get("c", PackedColorArray())
	var n := 0
	var caixa := AABB()
	for t in range(0, idx.size(), 3):
		var i0 := idx[t]
		if i0 >= cores.size() or cores[i0].to_html(false) != cor:
			continue
		var tri := AABB(v[i0], Vector3.ZERO).expand(v[idx[t + 1]]).expand(v[idx[t + 2]])
		caixa = tri if n == 0 else caixa.merge(tri)
		n += 1
		if n <= 3 and _achados < 12:
			_achados += 1
			var o := Vector3(c.x * 32.0, 0.0, c.y * 32.0)
			print("[orcamento] achado %s em %s tri %s .. %s" % [_achar, c, o + tri.position,
				o + tri.end])
	if n > 0:
		print("[orcamento] achar chunk=%d,%d tris=%d caixa=%s" % [c.x, c.y, n, caixa])
