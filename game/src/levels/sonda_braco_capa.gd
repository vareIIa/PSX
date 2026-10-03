## `--capo-sonda[=N]`: o braco vivo do padre do capo contra a capa dele (capuz,
## murca e batina), medido na malha que se ve.
##
## Por que existe
## --------------
## "O braco dobra de forma anormal e atravessa a capa." Atravessar se mede: a
## pele do braco (o `BracoDoPadre`, que aparece no lugar do braco do `Corpo`
## quando a mao espalma no vidro) nao pode passar da superficie da batina. Olhar
## a rajada diz ONDE; esta sonda diz QUANTO, em milimetros, a cada segundo.
##
## Como mede
## ---------
## - A capa: a malha da `BatinaAAA` e desenhada pelo shader em cima das grades
##   do `PanoGPU` (Catmull-Rom das particulas mais um desvio por vertice). Aqui a
##   mesma conta e refeita na CPU, vertice a vertice, com as particulas lidas da
##   placa (`pos_rid` de cada grade). So os vertices perto do braco entram.
## - O braco: duas capsulas por braco vivo (umero e antebraco, do osso `braco`
##   ao `antebraco` e dele a `mao` do esqueleto do braco), com o raio da malha
##   dele medido uma vez por fatia (o percentil 90 da distancia ao eixo dos
##   vertices daquele osso, no repouso).
## - A penetracao de um vertice da capa e o raio do braco ali menos a distancia
##   dele ao eixo: positiva, o pano esta dentro do braco (o braco atravessou).
##   O pior de cada segundo sai no log, com o lugar.
## - Por braco, o que a pose faz: ombro-mao (do ombro do braco vivo ao punho), o
##   angulo do cotovelo, o recuo do ombro (do ombro do esqueleto ao do braco),
##   e o cotovelo fora do vidro e acima da lataria.
##
## A leitura das particulas sincroniza com a placa: `N` quadros entre medidas
## (3 por padrao). Nada disso roda sem a flag.
class_name SondaBracoCapa
extends RefCounted

const NOMES_GRADE := ["capuz", "murca", "batina", "mangaE", "mangaD"]
## As superficies da malha que ficam sempre a vista (capuz e murca; batina).
const SUPERFICIES := [0, 1]
## Particula a mais que isto de todo braco nao entra (m).
const PERTO := 0.32
const FATIAS := 8
## Quanto do umero, a partir da junta do ombro, fica dentro do ombro do corpo
## (m): o deltoide tem 4 a 5 cm por cima da junta.
const RAIZ := 0.05

var corpo: Corpo
var pano: PanoGPU
var carro: Node3D
## [BracoDoPadre, membro (EscaladorDoCarro.MAO_E/MAO_D)]
var bracos: Array = []
## O plano do para-brisa (espaco do carro): centro e normal para fora.
var vidro_centro := Vector3.ZERO
var vidro_normal := Vector3.UP
## A altura da lataria em (x, z), espaco do carro.
var topo: Callable
var cada: int = 3
## `--capo-sonda-passo=S`: de quanto em quanto tempo (s) sai a linha do pior.
var passo_log: float = 1.0

var _s: float = 1.0
var _grades: Array = []
## Por superficie: [uv2 PackedVector2Array, c0, c1, c2 PackedFloat32Array].
var _sup: Array = []
## Perfis de raio por braco: {membro: [umero PackedFloat32Array, ante ...]}
var _perfil: Dictionary = {}
var _quadro: int = 0
var _relogio: float = 0.0
var _seg_t: float = 0.0
## O braco anotado no fim do quadro anterior (o que foi desenhado junto com a
## capa que a placa devolve agora): [{membro, a, b, c, visivel}].
var _anotado: Array = []
## O pior do segundo e da janela inteira.
var _pior: Dictionary = {}
var _pior_total: Dictionary = {}
## O pior fora da raiz do umero (os primeiros `RAIZ` m dele, dentro do ombro do
## corpo: ali o pano deitado no ombro fica, com razao, a menos que o raio do
## braco da junta).
var _pior_fora: Dictionary = {}
var _pior_fora_total: Dictionary = {}
## O mesmo, so com as particulas (o que a colisao do pano ve).
var _pior_p: Dictionary = {}
var _pior_p_total: Dictionary = {}
var _faixa: Dictionary = {}
var _faixa_total: Dictionary = {}
var _medidas: int = 0
var _leitura: Array = []
## O raio do braco do `Corpo` (os colisores do `CorpoAAA`), por membro.
var _raio_corpo: Dictionary = {}
var _cotovelo_no_tronco: Dictionary = {}
## `--capo-sonda-cor`: uma bolinha amarela em cada vertice da capa dentro do braco.
var _marcas: MultiMeshInstance3D
## `--capo-sonda-despejo=T`: no tempo T, lista as particulas da murca perto do
## umero (grade, distancia ao eixo, lado) para ver se o braco passa entre elas.
var _despejo: float = -1.0
## `--capo-sonda-vertice`: a cada linha, a vizinhanca do pior vertice (as 16
## particulas do Catmull-Rom dele) em volta do eixo do braco.
var _despejo_vertice: bool = OS.get_cmdline_user_args().has("--capo-sonda-vertice")
var _pior_v_pen := -INF
var _pior_v: Array = []


func _init(c: Corpo, p: PanoGPU, car: Node3D, n: int) -> void:
	corpo = c
	pano = p
	carro = car
	cada = maxi(1, n)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--capo-sonda-despejo="):
			_despejo = float(a.trim_prefix("--capo-sonda-despejo="))
		if a.begins_with("--capo-sonda-passo="):
			passo_log = maxf(0.03, float(a.trim_prefix("--capo-sonda-passo=")))
	_s = c.altura() / Corpo.ALTURA_REF
	_grades = BatinaAAA._grades
	var m := BatinaAAA._malha
	var cols := p.colisores()
	for membro: int in [EscaladorDoCarro.MAO_E, EscaladorDoCarro.MAO_D]:
		var d := membro == EscaladorDoCarro.MAO_D
		var ru := -1.0
		var ra := -1.0
		var cu: Array = []
		var ca: Array = []
		for col: Array in cols:
			if int(col[0]) == (Corpo.Osso.BRACO_D if d else Corpo.Osso.BRACO_E) and ru < 0.0:
				ru = float(col[3])
				cu = col.duplicate()
			elif int(col[0]) == (Corpo.Osso.ANTEBRACO_D if d else Corpo.Osso.ANTEBRACO_E) and ra < 0.0:
				ra = float(col[3])
				ca = col.duplicate()
		if ru > 0.0 and ra > 0.0:
			# As capsulas do braco do `CorpoAAA` (medidas na malha dele), antes de
			# irem para o braco vivo: [osso, a, b] do umero e do antebraco.
			_raio_corpo[membro] = [cu, ca]
			var u := PackedFloat32Array()
			u.resize(FATIAS)
			u.fill(ru)
			var an := PackedFloat32Array()
			an.resize(FATIAS)
			an.fill(ra)
			_perfil[membro + 10] = [u, an, 1.0]
	if OS.get_cmdline_user_args().has("--capo-sonda-cor"):
		# A capa pintada por grade (capuz vermelho, murca verde, batina azul) e
		# uma luz de chave do lado do motorista: na foto, o magenta do braco que
		# aparece por cima do verde e o braco furando a murca.
		var mi := p.find_child("BatinaAAA", false, false) as MeshInstance3D
		if mi != null:
			var mat := mi.get_surface_override_material(0) as ShaderMaterial
			if mat != null:
				mat.set_shader_parameter(&"ver_grade", true)
		_marcas = MultiMeshInstance3D.new()
		_marcas.name = "MarcasDaSonda"
		_marcas.top_level = true
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var bola := SphereMesh.new()
		bola.radius = 0.006
		bola.height = 0.012
		bola.radial_segments = 6
		bola.rings = 3
		var mb := StandardMaterial3D.new()
		mb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mb.albedo_color = Color(1.0, 1.0, 0.0)
		mb.no_depth_test = true
		bola.material = mb
		mm.mesh = bola
		_marcas.multimesh = mm
		car.add_child(_marcas)
		var luz := DirectionalLight3D.new()
		luz.name = "LuzDaSonda"
		luz.light_energy = 1.2
		car.add_child(luz)
		luz.transform = Transform3D(Basis.looking_at(Vector3(0.8, -0.9, 0.5), Vector3.UP), Vector3(0, 3, 0))
	for si: int in SUPERFICIES:
		var arr := m.surface_get_arrays(si)
		_sup.append([arr[Mesh.ARRAY_TEX_UV2], arr[Mesh.ARRAY_CUSTOM0], arr[Mesh.ARRAY_CUSTOM1],
			arr[Mesh.ARRAY_CUSTOM2]])


func por_braco(b: BracoVivo, membro: int) -> void:
	for par: Array in bracos:
		if par[0] == b:
			return
	bracos.append([b, membro])
	_perfil[membro] = _medir_perfil(b)
	if OS.get_cmdline_user_args().has("--capo-sonda-cor"):
		# O braco em magenta chapado: na foto, magenta que passa da capa e o
		# braco atravessando (so para medir).
		var mi := b.get(&"_pele_mi") as MeshInstance3D
		if mi != null:
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.0, 1.0)
			mi.material_override = m
	var pf: Array = _perfil[membro]
	print("[capo-sonda] braco %s: raio do umero %s mm, do antebraco %s mm (p90 por fatia, mundo)" % [
		"D" if membro == EscaladorDoCarro.MAO_D else "E", _mm(pf[0], pf[2]), _mm(pf[1], pf[2])])


static func _mm(a: PackedFloat32Array, k: float) -> String:
	var s := ""
	for v in a:
		s += "%d " % roundi(v * k * 1000.0)
	return s.strip_edges()


## O raio da malha do braco por fatia do umero e do antebraco (espaco do
## esqueleto dele), e a escala do esqueleto para o mundo: [umero, ante, escala].
func _medir_perfil(b: BracoVivo) -> Array:
	var esq := b.get(&"_esq") as Skeleton3D
	var mi := b.get(&"_pele_mi") as MeshInstance3D
	var umero := PackedFloat32Array()
	var ante := PackedFloat32Array()
	umero.resize(FATIAS)
	ante.resize(FATIAS)
	if esq == null or mi == null or mi.skin == null:
		umero.fill(0.05)
		ante.fill(0.04)
		return [umero, ante, 1.0]
	var arr := mi.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ossos: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var por := ossos.size() / maxi(vs.size(), 1)
	var skin := mi.skin
	var bind_osso := PackedInt32Array()
	for j in skin.get_bind_count():
		var o := skin.get_bind_bone(j)
		if o < 0:
			o = esq.find_bone(skin.get_bind_name(j))
		bind_osso.append(o)
	var ob := esq.find_bone("braco")
	var oa := esq.find_bone("antebraco")
	var og := esq.find_bone("antebraco_giro")
	var om := esq.find_bone("mao")
	var p_omb := esq.get_bone_global_rest(ob).origin
	var p_cot := esq.get_bone_global_rest(oa).origin
	var p_pun := esq.get_bone_global_rest(om).origin
	var dist_u: Array = []
	var dist_a: Array = []
	for f in FATIAS:
		dist_u.append([])
		dist_a.append([])
	for i in vs.size():
		var jmax := 0
		var wmax := -1.0
		for k in por:
			var w := pesos[i * por + k]
			if w > wmax:
				wmax = w
				jmax = ossos[i * por + k]
		var o := bind_osso[jmax]
		var nome := esq.get_bone_name(o)
		# So o miolo (a pele e a manga presa nela): as tiras soltas da manga
		# (`manga_*`) e as faixas pendem de um lado so, e como raio em volta do
		# eixo virariam um tubo de 13 cm que o braco nao tem.
		var seg := -1
		if o == ob:
			seg = 0
		elif o == oa or o == og:
			seg = 1
		if seg < 0:
			continue
		var v := esq.get_bone_global_rest(o) * (skin.get_bind_pose(jmax) * vs[i])
		var a := p_omb if seg == 0 else p_cot
		var c := p_cot if seg == 0 else p_pun
		var ab := c - a
		var t := (v - a).dot(ab) / ab.length_squared()
		if t < 0.0 or t > 1.0:
			continue
		var d := v.distance_to(a + ab * t)
		var f := mini(int(t * FATIAS), FATIAS - 1)
		((dist_u if seg == 0 else dist_a)[f] as Array).append(d)
	# (Packed dentro de Array e copia: cada perfil e escrito pelo nome.)
	umero = _percentil(dist_u)
	ante = _percentil(dist_a)
	var k := esq.global_basis.x.length()
	return [umero, ante, k]


## O percentil 90 de cada fatia; fatia vazia (a junta) pega a vizinha.
static func _percentil(dist: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(FATIAS)
	for f in FATIAS:
		var l: Array = dist[f]
		l.sort()
		out[f] = float(l[int(l.size() * 0.9)]) if not l.is_empty() else 0.0
	for f in FATIAS:
		if out[f] <= 0.0:
			out[f] = out[f - 1] if f > 0 else out[mini(f + 1, FATIAS - 1)]
	return out


## O braco do quadro que acabou (chamado no fim do quadro de quem anima).
func anotar() -> void:
	_anotado.clear()
	var vivos := {}
	for par: Array in bracos:
		var bv := par[0] as BracoVivo
		if is_instance_valid(bv) and bv.is_visible_in_tree():
			vivos[par[1]] = true
	# Os bracos do `Corpo` que ainda aparecem (a subida, o rastejar): o umero e
	# o antebraco dos ossos dele, com o raio dos colisores do `CorpoAAA`.
	if corpo.is_visible_in_tree():
		var esqc := corpo.esqueleto()
		for membro: int in [EscaladorDoCarro.MAO_E, EscaladorDoCarro.MAO_D]:
			if vivos.has(membro) or not _raio_corpo.has(membro):
				continue
			var segs: Array = []
			for col: Array in _raio_corpo[membro]:
				var t := esqc.global_transform * esqc.get_bone_global_pose(int(col[0]))
				t = Transform3D(t.basis.orthonormalized(), t.origin)
				segs.append([t * (col[1] as Vector3), t * (col[2] as Vector3)])
			_anotado.append({"membro": membro + 10, "a": segs[0][0], "b": segs[0][1],
				"c": segs[1][1], "b2": segs[1][0]})
	for par: Array in bracos:
		var b := par[0] as BracoVivo
		if not is_instance_valid(b) or not b.is_visible_in_tree():
			continue
		var esq := b.get(&"_esq") as Skeleton3D
		if esq == null:
			continue
		var g := esq.global_transform
		var a := g * esq.get_bone_global_pose(esq.find_bone("braco")).origin
		var c := g * esq.get_bone_global_pose(esq.find_bone("antebraco")).origin
		var p := g * esq.get_bone_global_pose(esq.find_bone("mao")).origin
		var membro: int = par[1]
		var esqc := corpo.esqueleto()
		var osso := Corpo.Osso.BRACO_D if membro == EscaladorDoCarro.MAO_D else Corpo.Osso.BRACO_E
		var real := esqc.global_transform * esqc.get_bone_global_pose(osso).origin
		_anotado.append({"membro": membro, "a": a, "b": c, "c": p, "real": real,
			"palma": carro.global_transform * (b.pegada.get("o", Vector3.ZERO) as Vector3)})
		_pose(membro, a, c, p, real)
		# Para onde o cotovelo sai do ombro, no tronco (x para fora do lado dele,
		# y para a cabeca, z para as costas): o ultimo do segundo.
		var tr := esqc.global_transform * esqc.get_bone_global_pose(Corpo.Osso.TORSO)
		var dl := (tr.basis.orthonormalized().inverse() * (c - a)).normalized()
		dl.x *= 1.0 if membro == EscaladorDoCarro.MAO_D else -1.0
		_cotovelo_no_tronco[membro] = dl


func _pose(membro: int, a: Vector3, c: Vector3, p: Vector3, real: Vector3) -> void:
	var inv := carro.global_transform.affine_inverse()
	var ca := inv * c
	var om := a.distance_to(p)
	var ang := rad_to_deg((a - c).angle_to(p - c))
	var recuo := a.distance_to(real)
	var fora := vidro_normal.dot(ca - vidro_centro)
	var acima := ca.y - (topo.call(ca.x, ca.z) as float) if topo.is_valid() else 0.0
	var real_mao := real.distance_to(p)
	for alvo: Dictionary in [_faixa, _faixa_total]:
		var f: Dictionary = alvo.get(membro, {})
		for par: Array in [["om", om], ["cot", ang], ["recuo", recuo], ["fora", fora],
				["acima", acima], ["real_mao", real_mao]]:
			var v: float = par[1]
			var mn: float = f.get(par[0] + "_min", INF)
			var mx: float = f.get(par[0] + "_max", -INF)
			f[par[0] + "_min"] = minf(mn, v)
			f[par[0] + "_max"] = maxf(mx, v)
		alvo[membro] = f


## A cada quadro, antes de quem anima: le a capa (a do quadro anterior) e mede
## contra o braco anotado.
func passo(delta: float) -> void:
	_relogio += delta
	_quadro += 1
	if not _anotado.is_empty() and _quadro % cada == 0:
		_medir()
	_seg_t += delta
	if _seg_t >= passo_log - 0.001:
		_seg_t = 0.0
		_imprimir("t=%.1f" % _relogio, _pior, _faixa, _pior_p, _pior_fora)
		if _despejo_vertice and not _pior_v.is_empty():
			_vizinhanca()
		_pior_v_pen = -INF
		_pior_v = []
		_pior = {}
		_pior_fora = {}
		_pior_p = {}
		_faixa = {}


func resumo(rotulo: String = "RESUMO") -> void:
	_imprimir("%s %d medidas" % [rotulo, _medidas], _pior_total, _faixa_total, _pior_p_total,
		_pior_fora_total)


func _imprimir(cab: String, pior: Dictionary, faixa: Dictionary, pior_p: Dictionary = {},
		pior_f: Dictionary = {}) -> void:
	var linha := "[capo-sonda] %s" % cab
	if pior.is_empty():
		linha += " pen=-"
	else:
		var inf: Array = pior.get("info", [Vector2.ZERO, Vector3.ZERO])
		linha += " pen=%.1fmm (%s %s %s t=%.2f g=%s desvio=%s %s)" % [float(pior["pen"]) * 1000.0, pior["grade"],
			pior["braco"], pior["seg"], float(pior["t"]), inf[0], inf[1], inf[2] if inf.size() > 2 else ""]
	if not pior_f.is_empty():
		linha += " fora_da_raiz=%.1fmm (%s %s %s t=%.2f)" % [float(pior_f["pen"]) * 1000.0, pior_f["grade"],
			pior_f["braco"], pior_f["seg"], float(pior_f["t"])]
	if not pior_p.is_empty():
		var inf_p: Array = pior_p.get("info", [Vector2.ZERO, Vector3.ZERO])
		linha += " particulas=%.1fmm (%s %s %s t=%.2f g=%s)" % [float(pior_p["pen"]) * 1000.0, pior_p["grade"],
			pior_p["braco"], pior_p["seg"], float(pior_p["t"]), inf_p[0]]
	for membro: int in faixa:
		var f: Dictionary = faixa[membro]
		linha += " | %s ombro-mao %.2f-%.2f cot %d-%d graus recuo %.2f-%.2f fora_vidro %.2f-%.2f acima %.2f-%.2f ombro_real-punho %.2f-%.2f" % [
			"D" if membro == EscaladorDoCarro.MAO_D else "E",
			f["om_min"], f["om_max"], roundi(f["cot_min"]), roundi(f["cot_max"]),
			f["recuo_min"], f["recuo_max"], f["fora_min"], f["fora_max"],
			f["acima_min"], f["acima_max"], f["real_mao_min"], f["real_mao_max"]]
		if _cotovelo_no_tronco.has(membro):
			var dl: Vector3 = _cotovelo_no_tronco[membro]
			linha += " cot_no_tronco(fora,cabeca,costas)=(%.2f,%.2f,%.2f)" % [dl.x, dl.y, dl.z]
	print(linha)


func _ler_particulas() -> Array:
	var out: Array = []
	var rd := RenderingServer.get_rendering_device()
	if rd == null:
		return out
	_leitura = []
	var rids: Array[RID] = []
	for k in mini(pano.pecas.size(), 3):
		rids.append(pano.pecas[k].pos_rid)
	RenderingServer.call_on_render_thread(func() -> void:
		var l: Array = []
		for r: RID in rids:
			l.append(rd.texture_get_data(r, 0) if r.is_valid() else PackedByteArray())
		_leitura = l)
	RenderingServer.force_sync()
	for k in _leitura.size():
		var bytes: PackedByteArray = _leitura[k]
		var pc := pano.pecas[k]
		var pos := PackedVector3Array()
		pos.resize(pc.n)
		if bytes.size() < pc.n * 16:
			return []
		for i in pc.n:
			pos[i] = Vector3(bytes.decode_float(i * 16), bytes.decode_float(i * 16 + 4),
				bytes.decode_float(i * 16 + 8))
		out.append(pos)
	return out


func _medir() -> void:
	var parts := _ler_particulas()
	if parts.size() < 3:
		return
	_medidas += 1
	if _despejo > 0.0 and _relogio >= _despejo:
		_despejo = -1.0
		_despejar(parts)
	var marcas := PackedVector3Array()
	# As particulas perto de algum braco, por grade.
	var perto: Array = []
	for k in parts.size():
		var pos: PackedVector3Array = parts[k]
		var m := PackedByteArray()
		m.resize(pos.size())
		for i in pos.size():
			for an: Dictionary in _anotado:
				if _dist_seg(pos[i], an["a"], an["b"]) < PERTO or _dist_seg(pos[i], an.get("b2", an["b"]), an["c"]) < PERTO:
					m[i] = 1
					break
		perto.append(m)
	for si in _sup.size():
		var uv2: PackedVector2Array = _sup[si][0]
		var c0: PackedFloat32Array = _sup[si][1]
		var c1: PackedFloat32Array = _sup[si][2]
		var c2: PackedFloat32Array = _sup[si][3]
		for v in uv2.size():
			var id := int(c0[v * 4 + 3] + 0.5)
			if id >= parts.size():
				continue
			var g := uv2[v]
			var mix2 := c1[v * 4 + 2]
			var id2 := int(c1[v * 4 + 3] + 0.5)
			var ok := _celula_perto(perto, id, g)
			if not ok and mix2 > 0.0 and id2 < parts.size():
				ok = _celula_perto(perto, id2, Vector2(c1[v * 4], c1[v * 4 + 1]))
			if not ok:
				continue
			var p := _ponto(parts, id, g, Vector3(c0[v * 4], c0[v * 4 + 1], c0[v * 4 + 2]), c2[v * 4 + 3])
			if mix2 > 0.0 and id2 < parts.size():
				var p2 := _ponto(parts, id2, Vector2(c1[v * 4], c1[v * 4 + 1]),
					Vector3(c2[v * 4], c2[v * 4 + 1], c2[v * 4 + 2]), 0.0)
				p = p.lerp(p2, mix2)
			var p_cr := _ponto(parts, id, g, Vector3.ZERO, 0.0) if _despejo_vertice else Vector3.ZERO
			var pen := _contra_o_braco(p, NOMES_GRADE[id] if mix2 < 0.5 else NOMES_GRADE[id2],
				[g, Vector3(c0[v * 4], c0[v * 4 + 1], c0[v * 4 + 2]) * _s,
				"%s+%s %.2f" % [NOMES_GRADE[id], NOMES_GRADE[id2] if mix2 > 0.0 else "-", mix2]],
				[_pior, _pior_total], [_pior_fora, _pior_fora_total])
			if _despejo_vertice and pen > _pior_v_pen:
				_pior_v_pen = pen
				_pior_v = [id, g, p, p_cr, parts]
			if _marcas != null and pen > 0.002 and marcas.size() < 600:
				marcas.append(p)
	if _marcas != null:
		_marcas.multimesh.instance_count = marcas.size()
		for k in marcas.size():
			_marcas.multimesh.set_instance_transform(k, Transform3D(Basis(), marcas[k]))
	# As particulas mesmas (sem o desvio da malha): separa o que e colisao do
	# que e desenho.
	for k in parts.size():
		var pos: PackedVector3Array = parts[k]
		var m: PackedByteArray = perto[k]
		for i in pos.size():
			if m[i] != 0:
				_contra_o_braco(pos[i], NOMES_GRADE[k], [Vector2(i % int(_grades[k]["w"]), i / int(_grades[k]["w"])),
					Vector3.ZERO], [_pior_p, _pior_p_total])


func _contra_o_braco(p: Vector3, grade: String, info: Array, alvos: Array, fora: Array = []) -> float:
	var maior := -INF
	for an: Dictionary in _anotado:
		var membro: int = an["membro"]
		var pf: Array = _perfil[membro]
		for seg in 2:
			var a: Vector3 = an["a"] if seg == 0 else an.get("b2", an["b"])
			var b: Vector3 = an["b"] if seg == 0 else an["c"]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
			var d := p.distance_to(a + ab * t)
			var perf: PackedFloat32Array = pf[seg]
			var r := perf[mini(int(t * FATIAS), FATIAS - 1)] * float(pf[2])
			var pen := r - d
			maior = maxf(maior, pen)
			var lista := alvos
			if not fora.is_empty() and not (seg == 0 and t * ab.length() < RAIZ):
				lista = alvos + fora
			for alvo: Dictionary in lista:
				if pen > float(alvo.get("pen", -INF)):
					alvo["pen"] = pen
					alvo["grade"] = grade
					alvo["braco"] = ("D" if membro % 10 == EscaladorDoCarro.MAO_D else "E") 						+ ("(corpo)" if membro >= 10 else "")
					alvo["seg"] = "umero" if seg == 0 else "antebraco"
					alvo["t"] = t
					alvo["info"] = info
	return maior


func _despejar(parts: Array) -> void:
	for an: Dictionary in _anotado:
		var a: Vector3 = an["a"]
		var b: Vector3 = an["b"]
		var ab := b - a
		var eixo := ab.normalized()
		var tr := corpo.esqueleto().global_transform
		var qa := tr * corpo.esqueleto().get_bone_global_pose(0).origin
		var qb := tr * corpo.esqueleto().get_bone_global_pose(2).origin
		print("[capo-despejo] t=%.2f braco %d ombro %s cotovelo %s (comprimento %.3f)" % [_relogio,
			an["membro"], a, b, ab.length()])
		for k in [1, 0, 2]:
			var pos: PackedVector3Array = parts[k]
			var gw := int(_grades[k]["w"])
			var linha := ""
			for i in pos.size():
				var t := clampf((pos[i] - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
				var c := a + ab * t
				var d := pos[i] - c
				if d.length() > 0.13 or t <= 0.0 or t >= 1.0:
					continue
				var qab := qb - qa
				var sp_ := qa + qab * clampf((c - qa).dot(qab) / qab.length_squared(), 0.0, 1.0)
				var w := sp_ - c
				w -= eixo * w.dot(eixo)
				var lado := signf(d.normalized().dot(w.normalized()))
				linha += " %d,%d:%.0f%s@%.2f" % [i % gw, i / gw, d.length() * 1000.0,
					"-" if lado > 0.0 else "+", t]
			print("[capo-despejo]   %s:%s" % [NOMES_GRADE[k], linha])


## O pior vertice do segundo: onde ele esta (e o ponto do Catmull-Rom sem o
## desvio) e as 16 particulas dele, em distancia (mm) e angulo (graus) em volta
## do eixo do umero mais perto.
func _vizinhanca() -> void:
	var id: int = _pior_v[0]
	var g: Vector2 = _pior_v[1]
	var p: Vector3 = _pior_v[2]
	var p_cr: Vector3 = _pior_v[3]
	var parts: Array = _pior_v[4]
	var melhor := {}
	var dm := INF
	for an: Dictionary in _anotado:
		var a: Vector3 = an["a"]
		var b: Vector3 = an["b"]
		var d := _dist_seg(p, a, b)
		if d < dm:
			dm = d
			melhor = an
	if melhor.is_empty():
		return
	var a: Vector3 = melhor["a"]
	var ab: Vector3 = (melhor["b"] as Vector3) - a
	var eixo := ab.normalized()
	var ref := eixo.cross(Vector3.UP).normalized()
	var ref2 := eixo.cross(ref)
	var desc := func(q: Vector3) -> String:
		var t := (q - a).dot(ab) / ab.length_squared()
		var c := a + ab * clampf(t, 0.0, 1.0)
		var d := q - c
		var ang := rad_to_deg(atan2(d.dot(ref2), d.dot(ref)))
		return "%d@%d/%.2f" % [roundi(d.length() * 1000.0), roundi(ang), t]
	var gr: Dictionary = _grades[id]
	var w := int(gr["w"])
	var h := int(gr["h"])
	var pos: PackedVector3Array = parts[id]
	var bx := int(floor(fposmod(g.x, float(w))))
	var by := int(floor(clampf(g.y, 0.0, float(h - 1))))
	var linha := "[capo-vertice] %s g=%s vertice %s, sem desvio %s | particulas:" % [
		NOMES_GRADE[id], g, desc.call(p), desc.call(p_cr)]
	for j in 4:
		var lin := clampi(by + j - 1, 0, h - 1)
		linha += " L%d[" % lin
		for i in 4:
			var col := posmod(bx + i - 1, w)
			linha += " %s" % desc.call(pos[lin * w + col])
		linha += "]"
	print(linha)


func _celula_perto(perto: Array, id: int, g: Vector2) -> bool:
	var gr: Dictionary = _grades[id]
	var w := int(gr["w"])
	var h := int(gr["h"])
	var m: PackedByteArray = perto[id]
	var x := posmod(int(floor(g.x)), w)
	var y := clampi(int(floor(g.y)), 0, h - 1)
	return m[y * w + x] != 0 or m[y * w + posmod(x + 1, w)] != 0 \
		or m[mini(y + 1, h - 1) * w + x] != 0


static func _dist_seg(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _pesos(t: float) -> Vector4:
	var t2 := t * t
	var t3 := t2 * t
	return Vector4(-0.5 * t3 + t2 - 0.5 * t, 1.5 * t3 - 2.5 * t2 + 1.0,
		-1.5 * t3 + 2.0 * t2 + 0.5 * t, 0.5 * t3 - 0.5 * t2)


static func _dpesos(t: float) -> Vector4:
	var t2 := t * t
	return Vector4(-1.5 * t2 + 2.0 * t - 0.5, 4.5 * t2 - 5.0 * t,
		-4.5 * t2 + 4.0 * t + 0.5, 1.5 * t2 - t)


## A mesma conta do vertice da `BatinaAAA` (`ponto` no shader).
func _ponto(parts: Array, id: int, g: Vector2, o: Vector3, area0: float) -> Vector3:
	var gr: Dictionary = _grades[id]
	var w := int(gr["w"])
	var h := int(gr["h"])
	var pos: PackedVector3Array = parts[id]
	var gx := fposmod(g.x, float(w))
	var gy := clampf(g.y, 0.0, float(h - 1))
	var bx := int(floor(gx))
	var by := int(floor(gy))
	var fx := gx - float(bx)
	var fy := gy - float(by)
	var wx := _pesos(fx)
	var wy := _pesos(fy)
	var dx := _dpesos(fx)
	var dy := _dpesos(fy)
	var p := Vector3.ZERO
	var du := Vector3.ZERO
	var dv := Vector3.ZERO
	for j in 4:
		var lin := clampi(by + j - 1, 0, h - 1)
		var l := Vector3.ZERO
		var ld := Vector3.ZERO
		for i in 4:
			var q := pos[lin * w + posmod(bx + i - 1, w)]
			l += q * wx[i]
			ld += q * dx[i]
		p += l * wy[j]
		du += ld * wy[j]
		dv += l * dy[j]
	var cr := du.cross(dv)
	var n := (cr + Vector3(0.0, 1e-12, 0.0)).normalized()
	var tg := (du - n * n.dot(du) + Vector3(1e-12, 0.0, 0.0)).normalized()
	var bt := n.cross(tg)
	var recolhe := 1.0
	if area0 > 0.0:
		recolhe = smoothstep(0.12, 0.40, cr.length() / (area0 * _s * _s))
	return p + (tg * o.x + bt * o.y + n * o.z) * _s * recolhe
