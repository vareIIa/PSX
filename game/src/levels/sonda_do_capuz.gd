## `--capuz-sonda=DIR`: o que a placa desenha do padre de perto (capuz, murca e
## batina, o corpo e a cabeca), despejado quadro a quadro para medir fora do
## jogo (`tools/sonda_capuz.py`). So nasce com a flag e nao muda nada na cena.
##
## Por que existe
## --------------
## "Cabeca flutuando dentro do capuz" e "roupa atravessando o padre" se medem na
## malha que se ve: a batina e desenhada pelo shader em cima das grades do
## `PanoGPU` (Catmull-Rom das particulas mais um desvio por vertice), o corpo e
## pele no esqueleto, a cabeca gira a queixada no shader. Refazer isso vertice a
## vertice em GDScript custava segundos por quadro; aqui so sai o que muda (as
## particulas lidas da placa, os ossos, as ligacoes da pele, a cabeca e a lente)
## e, uma vez, as malhas. O numpy refaz a conta e mede.
##
## O que sai, por padre, em `DIR/<nome>/`:
## - `estatico.json` e os `.f32`/`.i32` das malhas (uma vez);
## - `q_<t>.json` e `q_<t>.f32` por quadro (as particulas de cada grade).
##
## `--capuz-sonda-perto=M` (3 m): so os padres a menos disto da lente.
## `--capuz-sonda-de=T` e `--capuz-sonda-ate=T`: o trecho do relogio da cena.
## `--capuz-lente=DIR`: tres lentes em volta da cabeca do padre (frente, lado e
## tres quartos, de fora), um quadro a cada `--capuz-lente-passo` (0,1 s) em
## `DIR/<lente>/r_<t>.png` (o formato do `tools/mosaico_rajada.py`).
## `--capuz-recorte=LADO`: o quadro da tela (o que o jogador ve) recortado num
## quadrado em volta da cabeca deste padre (`RECORTE_RAIO` m), com LADO px, em
## `DIR/<nome>/c_<t>.png`, a cada quadro medido: na rajada de 640 x 360 o do
## capo, atras do para-brisa, cabe em vinte pixels.
##
## A leitura das particulas sincroniza com a placa: trava o quadro. A sonda nao
## serve para medir tempo.
extends Node

const PERTO := 3.0
## As lentes de fora: (de, para) no referencial do tronco (x para a direita
## dele, y para cima, z para as costas; origem na cabeca) e o campo.
const LENTES := {
	"frente": [Vector3(0.0, -0.05, -0.75), Vector3(0.0, -0.12, 0.0), 40.0],
	"lado": [Vector3(0.75, -0.08, -0.12), Vector3(0.0, -0.14, 0.0), 40.0],
	"tres_quartos": [Vector3(-0.55, 0.05, -0.55), Vector3(0.0, -0.14, 0.0), 40.0],
}
const LENTE_TAMANHO := Vector2i(960, 540)
## O raio (m) do recorte em volta da cabeca (`--capuz-recorte`).
const RECORTE_RAIO := 0.32

var corpo: Corpo
var pano: PanoGPU
var rosto: Node3D
var pasta := ""

var _de := -INF
var _ate := INF
var _perto := PERTO
var _abertura: Object
var _procurou := false
var _anotado: Dictionary = {}
var _estatico := false
var _n := 0
var _pasta_lente := ""
var _lente_passo := 0.1
var _lente_proxima := -INF
var _lentes: Dictionary = {}
## `--capuz-sonda-quem=A,B`: so esses padres (pelo nome do no). Todos sem.
var _ativa := true
## `--capuz-lente-quem=A,B`: quem ganha as lentes de fora (o padre principal).
var _lente_quem: PackedStringArray = ["Padre"]
## `--capuz-recorte=LADO`: o quadro da tela recortado na cabeca (0 sem).
var _recorte := 0


func _init(c: Corpo, p: PanoGPU, r: Node3D, dir: String) -> void:
	corpo = c
	pano = p
	rosto = r
	pasta = dir.path_join(String(c.name))
	name = "SondaDoCapuz"
	# Depois de quem anima e do pano (100): a pose que vai ser desenhada.
	process_priority = 1000
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--capuz-sonda-perto="):
			_perto = float(a.trim_prefix("--capuz-sonda-perto="))
		elif a.begins_with("--capuz-sonda-de="):
			_de = float(a.trim_prefix("--capuz-sonda-de="))
		elif a.begins_with("--capuz-sonda-ate="):
			_ate = float(a.trim_prefix("--capuz-sonda-ate="))
		elif a.begins_with("--capuz-lente="):
			_pasta_lente = a.trim_prefix("--capuz-lente=").path_join(String(c.name))
		elif a.begins_with("--capuz-lente-passo="):
			_lente_passo = maxf(0.02, float(a.trim_prefix("--capuz-lente-passo=")))
		elif a.begins_with("--capuz-sonda-quem="):
			_ativa = String(c.name) in a.trim_prefix("--capuz-sonda-quem=").split(",")
		elif a.begins_with("--capuz-lente-quem="):
			_lente_quem = a.trim_prefix("--capuz-lente-quem=").split(",")
		elif a.begins_with("--capuz-recorte="):
			_recorte = int(a.trim_prefix("--capuz-recorte="))
	if not String(c.name) in _lente_quem:
		_pasta_lente = ""


## A pasta da sonda, se a flag veio ("" sem).
static func pasta_da_flag() -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--capuz-sonda="):
			return a.trim_prefix("--capuz-sonda=")
	return ""


func _ready() -> void:
	get_tree().process_frame.connect(_no_comeco)


func _relogio() -> float:
	if not _procurou:
		_procurou = true
		var n: Node = corpo
		while n != null:
			if "_relogio_cena" in n:
				_abertura = n
				break
			n = n.get_parent()
		if _abertura == null:
			var achados := get_tree().root.find_children("*", "AberturaEstrada", true, false)
			if not achados.is_empty():
				_abertura = achados[0]
	if _abertura != null and is_instance_valid(_abertura):
		return float(_abertura.get(&"_relogio_cena"))
	return float(Engine.get_process_frames()) / 30.0


## No fim do quadro: o que vai ser desenhado (a pose, a lente, a cabeca). As
## particulas deste quadro so ficam prontas na placa depois dele: saem no
## comeco do proximo (`_no_comeco`).
func _process(_delta: float) -> void:
	_anotado = {}
	if not _ativa or corpo == null or not is_instance_valid(corpo) or not corpo.is_visible_in_tree():
		return
	var t := _relogio()
	if t < _de or t > _ate:
		return
	var cam := get_viewport().get_camera_3d()
	var esq := corpo.esqueleto()
	if cam == null or esq == null:
		return
	var cabeca := esq.global_transform * esq.get_bone_global_pose(Corpo.Osso.CABECA)
	if cam.global_position.distance_to(cabeca.origin) > _perto:
		return
	_lentes_de_fora(t, esq)
	var q := {"t": t, "quadro": Engine.get_process_frames()}
	q["esqueleto"] = _tr(esq.global_transform)
	var ossos: Array = []
	for o in esq.get_bone_count():
		ossos.append(_tr(esq.get_bone_global_pose(o)))
	q["ossos"] = ossos
	var cm := corpo.get_meta(&"corpo_aaa") as MeshInstance3D if corpo.has_meta(&"corpo_aaa") else null
	if cm != null and is_instance_valid(cm) and cm.skin != null:
		var binds: Array = []
		for i in cm.skin.get_bind_count():
			binds.append(_tr(cm.skin.get_bind_pose(i)))
		q["binds"] = binds
		q["corpo_visivel"] = cm.is_visible_in_tree()
	var mi := pano.find_child("BatinaAAA", false, false) as MeshInstance3D
	if mi != null:
		var some: Array = []
		for s in mi.get_surface_override_material_count():
			some.append(mi.get_surface_override_material(s) == BatinaAAA.sumido())
		q["batina_some"] = some
		q["batina_visivel"] = mi.is_visible_in_tree()
		# O pano tirado de dentro da cabeca no shader (`BatinaAAA.proteger_cabeca`).
		for f: Node in mi.get_children():
			if f is BatinaAAA.VigiaDaBatina:
				var vm := (f as BatinaAAA.VigiaDaBatina).material
				for p: StringName in [&"cabeca_escala", &"cabeca_forca", &"queixada"]:
					var v: Variant = vm.get_shader_parameter(p)
					q["sdf_" + String(p)] = float(v) if v != null else 0.0
				var ci: Variant = vm.get_shader_parameter(&"cabeca_inv")
				if ci is Projection:
					ci = Transform3D(ci as Projection)
				if ci is Transform3D:
					q["sdf_cabeca"] = _tr((ci as Transform3D).affine_inverse())
	var pele := _pele()
	if pele != null:
		q["cabeca"] = _tr(_global_pela_pose(pele, esq))
		q["cabeca_visivel"] = pele.is_visible_in_tree()
		var mat := pele.material_override as ShaderMaterial
		if mat != null:
			for p: StringName in [&"abre", &"giro_max"]:
				var v: Variant = mat.get_shader_parameter(p)
				q[String(p)] = float(v) if v != null else 0.0
			var pv: Variant = mat.get_shader_parameter(&"pivo")
			q["pivo"] = _v(pv as Vector3) if pv is Vector3 else [0.0, -0.018, 0.030]
	q["lente"] = _tr(cam.global_transform)
	q["fov"] = cam.fov
	q["aspecto"] = cam.keep_aspect
	var tam := get_viewport().get_visible_rect().size
	q["tela"] = [tam.x, tam.y]
	_anotado = q
	if _recorte > 0 and not cam.is_position_behind(cabeca.origin):
		# O centro no meio da cabeca de verdade (a pele, e nao o osso, que fica no
		# pescoco) e o raio pela lente: a mesma porcao do padre perto ou longe. A
		# conta vai pela projecao da lente, em fracao da tela (0 a 1): a imagem
		# da viewport nao tem o tamanho do retangulo visivel.
		var centro := cabeca.origin
		if pele != null:
			centro = _global_pela_pose(pele, esq).origin
		var proj := cam.get_camera_projection()
		var vista := cam.global_transform.affine_inverse()
		var c2 := _na_tela(proj, vista, centro)
		var r2 := _na_tela(proj, vista, centro + cam.global_basis.x * RECORTE_RAIO).x - c2.x
		if r2 > 0.0:
			_gravar_recorte.call_deferred(t, c2, r2)


## `p` (mundo) na tela, em fracao dela (0 a 1, y para baixo).
static func _na_tela(proj: Projection, vista: Transform3D, p: Vector3) -> Vector2:
	var l := vista * p
	var c := proj * Vector4(l.x, l.y, l.z, 1.0)
	if absf(c.w) < 1e-6:
		return Vector2(-1.0, -1.0)
	return Vector2((c.x / c.w + 1.0) * 0.5, (1.0 - c.y / c.w) * 0.5)


## No comeco do quadro seguinte: as particulas do quadro anotado ja estao na
## placa. Le e grava.
func _no_comeco() -> void:
	if _anotado.is_empty():
		return
	var q := _anotado
	_anotado = {}
	if not _estatico:
		_estatico = true
		_gravar_estatico()
	var rd := RenderingServer.get_rendering_device()
	if rd == null:
		return
	var rids: Array[RID] = []
	for pc in pano.pecas:
		rids.append(pc.pos_rid)
	var lido: Array = []
	RenderingServer.call_on_render_thread(func() -> void:
		for r: RID in rids:
			lido.append(rd.texture_get_data(r, 0) if r.is_valid() else PackedByteArray()))
	RenderingServer.force_sync()
	var todas := PackedFloat32Array()
	var grades: Array = []
	for k in pano.pecas.size():
		var pc := pano.pecas[k]
		var b: PackedByteArray = lido[k] if k < lido.size() else PackedByteArray()
		var f := b.to_float32_array()
		if f.size() < pc.n * 4:
			return
		var xyz := PackedFloat32Array()
		xyz.resize(pc.n * 3)
		for i in pc.n:
			xyz[i * 3] = f[i * 4]
			xyz[i * 3 + 1] = f[i * 4 + 1]
			xyz[i * 3 + 2] = f[i * 4 + 2]
		grades.append([pc.nome, pc.w, pc.h, todas.size()])
		todas.append_array(xyz)
	q["grades"] = grades
	var nome := "q_%07.3f" % float(q["t"])
	_escrever(pasta.path_join(nome + ".f32"), todas.to_byte_array())
	var fj := FileAccess.open(pasta.path_join(nome + ".json"), FileAccess.WRITE)
	if fj != null:
		fj.store_string(JSON.stringify(q))
	_n += 1
	if _n == 1:
		print("[capuz-sonda] %s: primeiro quadro t=%.2f em %s" % [corpo.name, float(q["t"]), pasta])


## O quadro que o jogador viu, recortado num quadrado em volta de `centro`
## (fracao da tela) com meia largura `raio` (fracao da largura).
func _gravar_recorte(t: float, centro: Vector2, raio: float) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	var sz := Vector2(img.get_size())
	var lado := maxi(roundi(raio * sz.x * 2.0), 8)
	var c := centro * sz
	var r := Rect2i(Vector2i(roundi(c.x) - lado / 2, roundi(c.y) - lado / 2), Vector2i(lado, lado))
	var dentro := r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if dentro.size.x < 8 or dentro.size.y < 8:
		return
	# Fora da tela fica preto: o quadrado nao se deforma na borda.
	var saida := Image.create_empty(r.size.x, r.size.y, false, img.get_format())
	saida.blit_rect(img, dentro, dentro.position - r.position)
	saida.resize(_recorte, _recorte, Image.INTERPOLATE_BILINEAR)
	DirAccess.make_dir_recursive_absolute(pasta)
	saida.save_png(pasta.path_join("c_%07.3f.png" % t))


## As malhas, uma vez: a batina (os canais que o shader le), o corpo (pele no
## esqueleto) e a cabeca.
func _gravar_estatico() -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	var e := {"nome": String(corpo.name), "altura": corpo.altura(),
		"s": corpo.altura() / Corpo.ALTURA_REF, "osso_cabeca": Corpo.Osso.CABECA}
	var gr: Array = []
	for g: Dictionary in BatinaAAA._grades:
		gr.append({"nome": g["nome"], "tipo": g.get("tipo", ""), "w": g["w"], "h": g["h"]})
	e["grades_batina"] = gr
	var m := BatinaAAA._malha
	var sups: Array = []
	if m != null:
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var base := "batina_s%d" % s
			_escrever_v3(base + "_pos", arr[Mesh.ARRAY_VERTEX])
			_escrever_v3(base + "_nor", arr[Mesh.ARRAY_NORMAL])
			_escrever(pasta.path_join(base + "_tan.f32"), (arr[Mesh.ARRAY_TANGENT] as PackedFloat32Array).to_byte_array())
			_escrever_v2(base + "_uv", arr[Mesh.ARRAY_TEX_UV])
			_escrever_v2(base + "_uv2", arr[Mesh.ARRAY_TEX_UV2])
			for c: int in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2]:
				_escrever(pasta.path_join(base + "_c%d.f32" % (c - Mesh.ARRAY_CUSTOM0)),
					(arr[c] as PackedFloat32Array).to_byte_array())
			_escrever(pasta.path_join(base + "_ind.i32"), (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).to_byte_array())
			sups.append({"base": base, "n": (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()})
		e["superficie_de"] = m.get_meta(&"superficie_de", {})
	e["batina"] = sups
	var cm := corpo.get_meta(&"corpo_aaa") as MeshInstance3D if corpo.has_meta(&"corpo_aaa") else null
	if cm != null and cm.mesh != null:
		var cs: Array = []
		for s in cm.mesh.get_surface_count():
			var arr := cm.mesh.surface_get_arrays(s)
			var base := "corpo_s%d" % s
			_escrever_v3(base + "_pos", arr[Mesh.ARRAY_VERTEX])
			_escrever_v3(base + "_nor", arr[Mesh.ARRAY_NORMAL])
			var ob: Variant = arr[Mesh.ARRAY_BONES]
			var bones := PackedInt32Array(ob) if ob != null else PackedInt32Array()
			_escrever(pasta.path_join(base + "_ossos.i32"), bones.to_byte_array())
			_escrever(pasta.path_join(base + "_pesos.f32"), (arr[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array).to_byte_array())
			var cor := PackedFloat32Array()
			for c: Color in (arr[Mesh.ARRAY_COLOR] as PackedColorArray):
				cor.append_array([c.r, c.g, c.b, c.a])
			_escrever(pasta.path_join(base + "_cor.f32"), cor.to_byte_array())
			_escrever(pasta.path_join(base + "_ind.i32"), (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).to_byte_array())
			var nv := (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			cs.append({"base": base, "n": nv, "por": bones.size() / maxi(nv, 1)})
		e["corpo"] = cs
		var bb: Array = []
		for i in cm.skin.get_bind_count():
			bb.append(cm.skin.get_bind_bone(i))
		e["corpo_bind_osso"] = bb
	var pele := _pele()
	if pele != null and pele.mesh != null:
		var arr := pele.mesh.surface_get_arrays(0)
		_escrever_v3("cabeca_pos", arr[Mesh.ARRAY_VERTEX])
		_escrever_v3("cabeca_nor", arr[Mesh.ARRAY_NORMAL])
		_escrever_v2("cabeca_uv", arr[Mesh.ARRAY_TEX_UV])
		_escrever(pasta.path_join("cabeca_ind.i32"), (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).to_byte_array())
		e["cabeca"] = {"n": (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "classe": rosto.get_class() if rosto != null else ""}
		if rosto != null and rosto.has_method(&"elipsoide"):
			var el: AABB = rosto.call(&"elipsoide")
			e["elipsoide_no_osso"] = [_v(el.position), _v(el.size)]
	var cols: Array = []
	for col: Array in pano.colisores():
		cols.append([col[0], _v(col[1]), _v(col[2]), col[3]])
	e["colisores"] = cols
	var fj := FileAccess.open(pasta.path_join("estatico.json"), FileAccess.WRITE)
	if fj != null:
		fj.store_string(JSON.stringify(e, " "))


## A malha da pele da cabeca (a maior do rosto).
func _pele() -> MeshInstance3D:
	if rosto == null or not is_instance_valid(rosto):
		return null
	for campo: StringName in [&"_pele_mi", &"_no_pele"]:
		var p := rosto.get(campo) as MeshInstance3D if campo in rosto else null
		if p != null:
			return p
	var melhor: MeshInstance3D = null
	var mais := -1
	for n: Node in rosto.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not (mi.mesh is ArrayMesh):
			continue
		var k: int = mi.mesh.surface_get_array_len(0)
		if k > mais:
			mais = k
			melhor = mi
	return melhor


## A transformacao global de `n` (pendurado num `BoneAttachment3D` do osso da
## cabeca) pela pose do osso deste quadro: o anexo so se atualiza depois.
func _global_pela_pose(n: Node3D, esq: Skeleton3D) -> Transform3D:
	var cadeia := Transform3D()
	var no: Node = n
	while no != null and not (no is BoneAttachment3D):
		cadeia = (no as Node3D).transform * cadeia
		no = no.get_parent()
	if no == null:
		return n.global_transform
	var ba := no as BoneAttachment3D
	return esq.global_transform * esq.get_bone_global_pose(ba.bone_idx) * cadeia


## As lentes de fora (`--capuz-lente`), em volta da cabeca, no referencial do
## tronco.
func _lentes_de_fora(t: float, esq: Skeleton3D) -> void:
	if _pasta_lente.is_empty():
		return
	if _lentes.is_empty():
		for nome: String in LENTES:
			var vp := SubViewport.new()
			vp.name = "LenteCapuz_" + nome
			vp.size = LENTE_TAMANHO
			vp.world_3d = get_viewport().world_3d
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			add_child(vp)
			var cam := Camera3D.new()
			cam.fov = float(LENTES[nome][2])
			cam.near = 0.02
			vp.add_child(cam)
			cam.current = true
			_lentes[nome] = [vp, cam]
			DirAccess.make_dir_recursive_absolute(_pasta_lente.path_join(nome))
	var tr := esq.global_transform * esq.get_bone_global_pose(Corpo.Osso.TORSO)
	var cab := esq.global_transform * esq.get_bone_global_pose(Corpo.Osso.CABECA)
	var b := tr.basis.orthonormalized()
	for nome: String in _lentes:
		var de: Vector3 = cab.origin + b * (LENTES[nome][0] as Vector3)
		var para: Vector3 = cab.origin + b * (LENTES[nome][1] as Vector3)
		var cam := _lentes[nome][1] as Camera3D
		cam.global_transform = Transform3D(Basis.looking_at(para - de, b.y), de)
	if t < _lente_proxima:
		return
	_lente_proxima = t + _lente_passo - 0.001
	_gravar_lentes.call_deferred(t)


func _gravar_lentes(t: float) -> void:
	await RenderingServer.frame_post_draw
	for nome: String in _lentes:
		var vp := _lentes[nome][0] as SubViewport
		vp.get_texture().get_image().save_png(_pasta_lente.path_join(nome).path_join("r_%07.2f.png" % t))


func _escrever(caminho: String, b: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(caminho.get_base_dir())
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f != null:
		f.store_buffer(b)


func _escrever_v3(base: String, a: PackedVector3Array) -> void:
	var f := PackedFloat32Array()
	f.resize(a.size() * 3)
	for i in a.size():
		f[i * 3] = a[i].x
		f[i * 3 + 1] = a[i].y
		f[i * 3 + 2] = a[i].z
	_escrever(pasta.path_join(base + ".f32"), f.to_byte_array())


func _escrever_v2(base: String, a: PackedVector2Array) -> void:
	var f := PackedFloat32Array()
	f.resize(a.size() * 2)
	for i in a.size():
		f[i * 2] = a[i].x
		f[i * 2 + 1] = a[i].y
	_escrever(pasta.path_join(base + ".f32"), f.to_byte_array())


static func _v(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


## Basis por colunas (x, y, z) e a origem.
static func _tr(t: Transform3D) -> Array:
	return [_v(t.basis.x), _v(t.basis.y), _v(t.basis.z), _v(t.origin)]
