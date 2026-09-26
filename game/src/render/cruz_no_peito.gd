## O crucifixo no peito dos padres da estrada, numa corrente de ferro, com
## fisica propria: a cruz pesa, a corrente cede, as duas balancam e batem no
## peito por cima da batina.
##
## Por que existe
## --------------
## A batina do gerador trazia a cruz fundida no pano: uma haste dura saindo do
## pescoco e uma cruz de espada, parada no ar quando o padre se curvava. O
## pedido e a cruz de Jesus (crucifixo latino, com o Cristo), numa corrente de
## verdade, com peso, que cai para a frente quando ele se debruca no carro e
## volta a bater no peito quando ele se ergue. A cruz de madeira de caixa que o
## `CapuzMacabro` punha no osso do torso sai junto.
##
## Como funciona
## -------------
## Tudo em espaco de mundo (o no e `top_level`), em passos fixos de `PASSO`:
##   - a corrente e um V de Verlet: de cada lado da gola (a linha presa da
##     murca, `BatinaAAA.peito`, no osso do torso) ate a argola da cruz,
##     `PONTOS` particulas por lado. So resiste a esticar (corrente nao
##     empurra, amontoa);
##   - a cruz e um corpo rigido de quatro particulas (argola, pe e as pontas dos
##     bracos), mais pesadas que a corrente, com as seis distancias entre elas
##     exatas: gira, tomba e deita no peito;
##   - as duas batem na frente da murca (capsulas deitadas nela, no osso do
##     torso, `BatinaAAA.peito`), nos colisores do corpo do padre
##     (`PanoGPU.colisores`, com o pano por cima: `SOBRE_O_PANO`) e no chao;
##   - os elos sao uma MultiMesh (`CruzNoPeito.ELO`), um a cada `PASSO_ELO` ao
##     longo da corrente, girando 90 graus de um para o outro.
## Longe da camera (`LONGE`) nao simula: corrente e cruz seguem o torso no
## repouso.
class_name CruzNoPeito
extends Node3D

const PASTA := "res://assets/monstros/padre/cruz/"
const CRUCIFIXO := PASTA + "crucifixo.glb"
const ELO := PASTA + "elo.glb"
## Distancia entre os centros de dois elos enganchados (m): o comprimento de
## fora do elo menos duas vezes o fio (0,016 - 2 x 0,0026).
const PASSO_ELO := 0.0108
## Corrente de cada lado, da gola a argola: a distancia no repouso mais esta
## sobra (a corrente pende, nao estica).
const SOBRA := 1.06
const PONTOS := 10
## A cruz no espaco dela (origem no furo da argola, +Y para cima, o Cristo
## olhando -Z; `tools/blender_cruz`): o pe da haste (a haste vai de -0,0069 a
## -0,1669) e as pontas dos bracos (a trave a 28% da haste, de +-0,0475).
const CRUZ_PE := Vector3(0.0, -0.165, 0.0)
const CRUZ_BRACO := Vector3(0.0465, -0.0517, 0.0)
## Massas (kg): cada ponto da corrente e cada um dos quatro da cruz.
const MASSA_ELO := 0.004
const MASSA_CRUZ := 0.012
## Raios de colisao: o fio da corrente e a espessura da cruz com o Cristo.
const RAIO_ELO := 0.004
const RAIO_CRUZ := 0.007
## Quanto o pano fica por cima do corpo nos colisores do tronco (a murca
## deitada no peito) e nos outros.
const SOBRE_O_PANO := 0.045
const SOBRE_O_RESTO := 0.015
const GRAVIDADE := Vector3(0.0, -9.8, 0.0)
## Passo fixo e iteracoes: 120 Hz e quatro voltas (a amarra de alcance segura
## o esticar). Os colisores do quadro vao em arrays empacotados, so os perto da
## corrente, e a colisao e em linha: o passo custava 140 us por padre com uma
## chamada de funcao por teste e os ossos relidos a cada passo.
const PASSO := 1.0 / 120.0
## Longe da lente (alem de `PERTO`) o passo dobra: 60 Hz, um por quadro.
const PASSO_LONGE := 1.0 / 60.0
const PERTO := 4.0
const PASSOS_MAX := 6
const ITERACOES := 4
## Arrasto do ar (1/s): pouco; o que para o balanco e o atrito no pano.
const ARRASTO := 0.9
## Encostado no pano, quanto do movimento de lado se perde por passo.
const ATRITO := 0.25
## Alem disto (m, na pessoa de 1,72) nao simula: corrente e cruz seguem o
## torso no repouso. Alem de `ELOS_ATE` os elos nem desenham (o elo de 1,6 cm
## ja e menor que um pixel a 4K) e alem de `CRUZ_ATE` a cruz some.
const LONGE := 10.0
const ELOS_ATE := 16.0
const CRUZ_ATE := 40.0
## Ao (re)nascer, passos de assentar com arrasto forte antes de aparecer: posta
## no repouso, a cruz comecava com o pe dentro da murca, era chutada para fora e
## virava de ponta-cabeca.
const ASSENTA := 40
const ASSENTA_ARRASTO := 25.0
const TELEPORTE := 1.5
## O torso que salta mais que isto num quadro (m, rad) e corte de pose, e nao
## movimento: a corrente assenta de novo. Da janela para de pe em quatro
## quadros o chicote jogava a cruz na cara.
const CORTE_M := 0.2
const CORTE_ANG := 0.6
## Nenhum elo passa desta velocidade (m/s).
const VEL_MAX := 4.0

## `--cruz-depurar`: imprime a argola, o pe, o comprimento de um lado e o custo
## medio por padre por quadro (us).
static var _depurar := OS.get_cmdline_user_args().has("--cruz-depurar")
static var _us := 0
static var _medidas := 0
static var _us_passo := 0
static var _passos := 0
static var _malha_cruz: Mesh
static var _malha_elo: Mesh
static var _tentou := false

var _corpo: Corpo
## No osso do torso: as ancoras, a argola no repouso e o comprimento de um lado.
var _ancora_e := Vector3.ZERO
var _ancora_d := Vector3.ZERO
var _argola := Vector3.ZERO
var _lado_comp := 0.0
## Elos de cada lado: fixos, espalhados pelo comprimento de agora (a corrente
## esticada sob o peso da cruz abre um fio entre os elos, e nao fica sem elo).
var _elos_lado := 0
## Os transforms dos elos, escritos de uma vez no buffer da MultiMesh.
var _buf := PackedFloat32Array()
var _longe_da_camera := 0.0
## O passo de agora (`PASSO` perto, `PASSO_LONGE` longe).
var _h := PASSO
var _esq: Skeleton3D
var _escala := 1.0
## [osso, a, b, raio, sobre] no espaco do osso: as capsulas deitadas na frente
## da murca.
var _colisores: Array = []
## Os colisores do pano (`PanoGPU.colisores`, [osso, a, b, raio]), lidos vivos
## a cada quadro: o vidro da janela e do capo entra depois de vestir e anda
## (`mover_colisor`). Com a copia feita ao vestir, a cruz do carona atravessava
## a janela e ficava pendurada dentro do carro.
var _colisores_pano: Array = []
var _p := PackedVector3Array()
var _pv := PackedVector3Array()
var _w := PackedFloat32Array()
var _raio := PackedFloat32Array()
## Comprimento de repouso entre pontos seguidos da corrente.
var _l_elo := 0.0
## As seis distancias da cruz: pares de indices e comprimentos.
var _rig: Array = []
## Os colisores do quadro, no mundo, so os perto da corrente: ponta a, eixo ab,
## 1/|ab|^2 e raio (ja com o pano e o raio da particula somado na hora).
var _col_a := PackedVector3Array()
var _col_ab := PackedVector3Array()
var _col_inv := PackedFloat32Array()
var _col_r := PackedFloat32Array()
var _cruz: MeshInstance3D
var _elos: MultiMeshInstance3D
var _acumulado := 0.0
var _torso_antes := Transform3D()
var _ultima := Vector3.INF
var _reiniciar := true


## Os indices: lado esquerdo 0..PONTOS-1, direito PONTOS..2*PONTOS-1, e a cruz
## (argola, pe, braco direito, braco esquerdo) no fim. A ancora nao e ponto: e
## o osso.
func _i_cruz(k: int) -> int:
	return 2 * PONTOS + k


static func _carregar() -> bool:
	if _malha_cruz != null:
		return true
	if _tentou:
		return false
	_tentou = true
	if not ResourceLoader.exists(CRUCIFIXO) or not ResourceLoader.exists(ELO):
		push_warning("CruzNoPeito: sem %s ou %s" % [CRUCIFIXO, ELO])
		return false
	_malha_cruz = _primeira_malha(load(CRUCIFIXO) as PackedScene)
	_malha_elo = _primeira_malha(load(ELO) as PackedScene)
	return _malha_cruz != null and _malha_elo != null


static func _primeira_malha(ps: PackedScene) -> Mesh:
	if ps == null:
		return null
	var r := ps.instantiate()
	var mis := r.find_children("*", "MeshInstance3D", true, false)
	var m: Mesh = (mis[0] as MeshInstance3D).mesh if not mis.is_empty() else null
	r.free()
	return m


## Pendura o crucifixo em `c`, na escala `s` da pessoa, na frente da murca
## (`peito`, de `BatinaAAA.peito`), batendo tambem em `colisores` ([osso, a, b,
## raio] de `PanoGPU.colisores`). Null se o modelo nao carregou.
static func vestir(c: Corpo, s: float, colisores: Array, peito: Dictionary) -> CruzNoPeito:
	if not _carregar() or peito.is_empty():
		return null
	var cr := CruzNoPeito.new()
	cr.name = "CruzNoPeito"
	cr._corpo = c
	cr._esq = c.esqueleto()
	cr._escala = s
	var no_torso := cr._esq.get_bone_global_rest(Corpo.Osso.TORSO).affine_inverse()
	cr._ancora_e = no_torso * (peito["ancora_e"] as Vector3)
	cr._ancora_d = no_torso * (peito["ancora_d"] as Vector3)
	cr._argola = no_torso * (peito["argola"] as Vector3)
	cr._lado_comp = cr._ancora_d.distance_to(cr._argola) * SOBRA
	for cap: Array in peito["capsulas"]:
		cr._colisores.append([Corpo.Osso.TORSO, no_torso * (cap[0] as Vector3),
			no_torso * (cap[1] as Vector3), float(cap[2]), 0.0])
	cr._colisores_pano = colisores
	c.add_child(cr)
	return cr


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	var n := 2 * PONTOS + 4
	_p.resize(n)
	_pv.resize(n)
	_w.resize(n)
	_raio.resize(n)
	for i in n:
		var cruz := i >= 2 * PONTOS
		_w[i] = 1.0 / (MASSA_CRUZ if cruz else MASSA_ELO)
		_raio[i] = (RAIO_CRUZ if cruz else RAIO_ELO) * _escala
	_l_elo = _lado_comp / float(PONTOS)
	var pontos := [Vector3.ZERO, CRUZ_PE, CRUZ_BRACO, Vector3(-CRUZ_BRACO.x, CRUZ_BRACO.y, 0.0)]
	for a in 4:
		for b in range(a + 1, 4):
			_rig.append([_i_cruz(a), _i_cruz(b), ((pontos[a] as Vector3) - (pontos[b] as Vector3)).length() * _escala])
	_cruz = MeshInstance3D.new()
	_cruz.name = "Crucifixo"
	_cruz.mesh = _malha_cruz
	_cruz.top_level = true
	_cruz.visibility_range_end = CRUZ_ATE * _escala
	add_child(_cruz)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _malha_elo
	_elos_lado = int(ceil(_lado_comp / (PASSO_ELO * _escala)))
	mm.instance_count = 2 * _elos_lado
	_elos = MultiMeshInstance3D.new()
	_elos.name = "Corrente"
	_elos.multimesh = mm
	_elos.top_level = true
	_elos.visibility_range_end = ELOS_ATE * _escala
	add_child(_elos)
	_buf.resize(mm.instance_count * 12)


func _torso() -> Transform3D:
	var t := _esq.global_transform * _esq.get_bone_global_pose(Corpo.Osso.TORSO)
	return Transform3D(t.basis.orthonormalized(), t.origin)


func _ancora(t: Transform3D, lado: float) -> Vector3:
	return t * (_ancora_d if lado > 0.0 else _ancora_e)


## O repouso: a cruz pendurada na frente do peito, os dois lados da corrente em
## linha da gola ate a argola.
func _por_no_repouso(t: Transform3D) -> void:
	var argola := t * _argola
	for lado_i in 2:
		var lado := 1.0 if lado_i == 0 else -1.0
		var a := _ancora(t, lado)
		for k in PONTOS:
			var f := float(k + 1) / float(PONTOS + 1)
			_p[lado_i * PONTOS + k] = a.lerp(argola, f)
	var pontos := [Vector3.ZERO, CRUZ_PE, CRUZ_BRACO, Vector3(-CRUZ_BRACO.x, CRUZ_BRACO.y, 0.0)]
	for k in 4:
		_p[_i_cruz(k)] = argola + t.basis * ((pontos[k] as Vector3) * _escala)
	for i in _p.size():
		_pv[i] = _p[i]


func _process(delta: float) -> void:
	if _esq == null or _malha_cruz == null:
		return
	var t0 := Time.get_ticks_usec()
	_simular(delta)
	if _depurar:
		_us += Time.get_ticks_usec() - t0
		_medidas += 1
		if _medidas % 600 == 0:
			print("[cruz] custo medio %.1f us por padre por quadro; um passo de fisica %.1f us" % [
				float(_us) / float(_medidas), float(_us_passo) / float(maxi(_passos, 1))])


func _simular(delta: float) -> void:
	if not _corpo.is_visible_in_tree():
		_reiniciar = true
		visible = false
		return
	visible = true
	var t := _torso()
	var cam := get_viewport().get_camera_3d()
	_longe_da_camera = cam.global_position.distance_to(t.origin) if cam != null else 0.0
	var longe := _longe_da_camera > LONGE * _escala
	if _ultima != Vector3.INF and t.origin.distance_to(_ultima) > TELEPORTE:
		_reiniciar = true
	if not _reiniciar and _torso_antes != Transform3D() and (
			t.origin.distance_to(_torso_antes.origin) > CORTE_M * _escala
			or (_torso_antes.basis.inverse() * t.basis).get_rotation_quaternion().get_angle() > CORTE_ANG):
		_reiniciar = true
	_ultima = t.origin
	if _reiniciar or longe:
		_por_no_repouso(t)
		if _reiniciar:
			_colisores_do_quadro()
			for _k in ASSENTA:
				_passo(t, ASSENTA_ARRASTO)
			for i in _p.size():
				_pv[i] = _p[i]
		_torso_antes = t
		_reiniciar = false
		_acumulado = 0.0
		_desenhar()
		return
	var h := PASSO if _longe_da_camera < PERTO * _escala else PASSO_LONGE
	if h != _h:
		# Verlet guarda a velocidade como deslocamento por passo: troca de passo
		# reescala o deslocamento, senao a corrente da um tranco.
		for i in _p.size():
			_pv[i] = _p[i] - (_p[i] - _pv[i]) * (h / _h)
		_h = h
	_acumulado = minf(_acumulado + delta, _h * PASSOS_MAX)
	var passos := int(_acumulado / _h)
	if passos > 0:
		_colisores_do_quadro()
	_acumulado -= float(passos) * _h
	for k in passos:
		var f := float(k + 1) / float(passos)
		var tp := Time.get_ticks_usec()
		_passo(_interpola(_torso_antes, t, f))
		if _depurar:
			_us_passo += Time.get_ticks_usec() - tp
			_passos += 1
	_torso_antes = t
	_desenhar()
	if _depurar and Engine.get_process_frames() % 60 == 0 and name == "CruzNoPeito" and _corpo.name == "Padre":
		var inv := t.affine_inverse()
		var comp := 0.0
		var ant := _ancora(t, 1.0)
		for k in PONTOS:
			comp += ant.distance_to(_p[k])
			ant = _p[k]
		comp += ant.distance_to(_p[_i_cruz(0)])
		print("[cruz] quadro=%d argola=%s pe=%s ancora_d=%s lado_d=%.3f rep=%.3f" % [
			Engine.get_process_frames(), inv * _p[_i_cruz(0)], inv * _p[_i_cruz(1)],
			_ancora_d, comp, float(PONTOS + 1) * _l_elo])


static func _interpola(a: Transform3D, b: Transform3D, f: float) -> Transform3D:
	return Transform3D(a.basis.slerp(b.basis, f), a.origin.lerp(b.origin, f))


func _passo(t: Transform3D, arrasto: float = ARRASTO) -> void:
	var h := _h
	var solta := maxf(0.0, 1.0 - arrasto * h)
	var v_max := VEL_MAX * h
	for i in _p.size():
		var v := (_p[i] - _pv[i]) * solta
		var lv := v.length()
		if lv > v_max:
			v *= v_max / lv
		_pv[i] = _p[i]
		_p[i] += v + GRAVIDADE * h * h
	var a_e := _ancora(t, 1.0)
	var a_d := _ancora(t, -1.0)
	var argola := _i_cruz(0)
	var l_elo := _l_elo
	for _it in ITERACOES:
		# A corrente: so estica ate o comprimento (amontoa livre). A primeira
		# de cada lado nao sai de um elo da ancora.
		for lado_i in 2:
			var base := lado_i * PONTOS
			var ancora := a_e if lado_i == 0 else a_d
			var d0 := _p[base] - ancora
			var l0 := d0.length()
			if l0 > l_elo:
				_p[base] = ancora + d0 * (l_elo / l0)
			for k in PONTOS:
				var i := base + k
				var j := base + k + 1 if k < PONTOS - 1 else argola
				var d := _p[j] - _p[i]
				var l := d.length()
				if l > l_elo:
					var wi := _w[i]
					var wj := _w[j]
					var c := d * ((l - l_elo) / (l * (wi + wj)))
					_p[i] += c * wi
					_p[j] -= c * wj
		# A cruz: rigida.
		for r: Array in _rig:
			var i := int(r[0])
			var j := int(r[1])
			var d := _p[j] - _p[i]
			var l := d.length()
			if l > 1e-7:
				var c := d * ((l - float(r[2])) / (l * 2.0))
				_p[i] += c
				_p[j] -= c
	# Amarra de alcance (LRA): nenhum ponto passa da ancora mais que a corrente
	# entre os dois. Sem ela a corrente de onze trechos esticava sob o peso da
	# cruz (Gauss-Seidel em seis voltas nao segura), os elos se abriam e a cruz
	# descia ate a cintura.
	for lado_i in 2:
		var base := lado_i * PONTOS
		var ancora := a_e if lado_i == 0 else a_d
		for k in PONTOS:
			_amarra(base + k, ancora, float(k + 1) * l_elo)
		_amarra(argola, ancora, float(PONTOS + 1) * l_elo)
	# Colisao com o corpo (por cima do pano) e com o chao, em linha.
	var chao := _corpo.global_position.y
	var nc := _col_a.size()
	for i in _p.size():
		var p := _p[i]
		var ri := _raio[i]
		for c in nc:
			var a := _col_a[c]
			var ab := _col_ab[c]
			var tt := clampf((p - a).dot(ab) * _col_inv[c], 0.0, 1.0)
			var q := a + ab * tt
			var d := p - q
			var l2 := d.length_squared()
			var r := _col_r[c] + ri
			if l2 < r * r:
				var l := sqrt(l2)
				var nrm := d / l if l > 1e-6 else Vector3.UP
				var np := q + nrm * r
				# Atrito: encostado no pano, o elo nao escorrega livre.
				var mov := np - _pv[i]
				_pv[i] += (mov - nrm * mov.dot(nrm)) * ATRITO
				p = np
		if p.y < chao + ri:
			p.y = chao + ri
		_p[i] = p


func _amarra(i: int, ancora: Vector3, alcance: float) -> void:
	var d := _p[i] - ancora
	var l := d.length()
	if l > alcance:
		var novo := ancora + d * (alcance / l)
		# A argola leva a cruz junto: o corpo rigido nao fica para tras.
		if i == _i_cruz(0):
			var mov := novo - _p[i]
			for k in range(1, 4):
				_p[_i_cruz(k)] += mov
		_p[i] = novo


## Os colisores no mundo, uma vez por quadro, so os que alcancam a corrente
## (a esfera em volta dela, com folga para o quadro).
func _colisores_do_quadro() -> void:
	var centro := Vector3.ZERO
	for p in _p:
		centro += p
	centro /= float(_p.size())
	var alcance := 0.0
	for p in _p:
		alcance = maxf(alcance, p.distance_to(centro))
	alcance += 0.15 * _escala
	_col_a.clear()
	_col_ab.clear()
	_col_inv.clear()
	_col_r.clear()
	var todos: Array = _colisores.duplicate()
	for col: Array in _colisores_pano:
		var o := int(col[0])
		# A cruz anda do peito ao joelho (debrucado no carro): perna de baixo e
		# canela nao entram.
		if o == Corpo.Osso.CANELA_E or o == Corpo.Osso.CANELA_D:
			continue
		var tronco := o == Corpo.Osso.TORSO or o == Corpo.Osso.QUADRIL
		todos.append([o, col[1], col[2], float(col[3]),
			(SOBRE_O_PANO if tronco else SOBRE_O_RESTO) * _escala])
	var poses := {}
	for c: Array in todos:
		var o := int(c[0])
		if not poses.has(o):
			var tb := _esq.global_transform * _esq.get_bone_global_pose(o)
			poses[o] = Transform3D(tb.basis.orthonormalized(), tb.origin)
		var tb: Transform3D = poses[o]
		var a := tb * (c[1] as Vector3)
		var b := tb * (c[2] as Vector3)
		var r := float(c[3]) + float(c[4])
		var ab := b - a
		var tt := clampf((centro - a).dot(ab) / maxf(ab.dot(ab), 1e-9), 0.0, 1.0)
		if (a + ab * tt).distance_to(centro) > alcance + r:
			continue
		_col_a.append(a)
		_col_ab.append(ab)
		_col_inv.append(1.0 / maxf(ab.dot(ab), 1e-9))
		_col_r.append(r)


func _desenhar() -> void:
	# A cruz pelas quatro particulas.
	var argola := _p[_i_cruz(0)]
	var y := (argola - _p[_i_cruz(1)]).normalized()
	var x := _p[_i_cruz(2)] - _p[_i_cruz(3)]
	x = (x - y * x.dot(y)).normalized()
	var z := x.cross(y)
	_cruz.global_transform = Transform3D(Basis(x, y, z).scaled(Vector3.ONE * _escala), argola)
	if _longe_da_camera > ELOS_ATE * _escala:
		return
	# Os elos ao longo dos dois lados, da gola a argola.
	var mm := _elos.multimesh
	var t := _torso()
	var n := 0
	for lado_i in 2:
		var linha := PackedVector3Array()
		linha.append(_ancora(t, 1.0 if lado_i == 0 else -1.0))
		for k in PONTOS:
			linha.append(_p[lado_i * PONTOS + k])
		linha.append(argola)
		var fundo := -t.basis.z
		var total := 0.0
		for q in range(linha.size() - 1):
			total += linha[q].distance_to(linha[q + 1])
		var passo := total / float(_elos_lado)
		var s := passo * 0.5
		var seg := 0
		var ini := 0.0
		var k_elo := 0
		while seg < linha.size() - 1 and k_elo < _elos_lado:
			var a := linha[seg]
			var b := linha[seg + 1]
			var lseg := a.distance_to(b)
			if s > ini + lseg:
				ini += lseg
				seg += 1
				continue
			var p := a.lerp(b, (s - ini) / maxf(lseg, 1e-6))
			var eixo := (b - a).normalized()
			var lado_v := fundo.cross(eixo)
			if lado_v.length_squared() < 1e-8:
				lado_v = t.basis.x
			lado_v = lado_v.normalized()
			if k_elo % 2 == 1:
				lado_v = eixo.cross(lado_v).normalized()
			var e := _escala
			var bx := lado_v * e
			var by := eixo * e
			var bz := lado_v.cross(eixo) * e
			var o := n * 12
			_buf[o] = bx.x
			_buf[o + 1] = by.x
			_buf[o + 2] = bz.x
			_buf[o + 3] = p.x
			_buf[o + 4] = bx.y
			_buf[o + 5] = by.y
			_buf[o + 6] = bz.y
			_buf[o + 7] = p.y
			_buf[o + 8] = bx.z
			_buf[o + 9] = by.z
			_buf[o + 10] = bz.z
			_buf[o + 11] = p.z
			n += 1
			k_elo += 1
			s += passo
	mm.buffer = _buf
	mm.visible_instance_count = n
