## A medida da janela do carona (`PadresNasJanelas`). So nasce com as flags, e
## nao muda nada na cena.
##
##   --carona-sonda       por quadro, o pior de cada segundo: a palma e a ponta
##                        dos dedos ao plano do vidro, a mao dentro do vao, o
##                        ombro a mao, o ombro do braco fora do ombro do corpo, o
##                        angulo do cotovelo, a testa ao vidro e o braco dentro da
##                        batina, da murca e do capuz (amostras no umero e no
##                        antebraco, com o raio da malha). E em cada golpe: as
##                        duas maos estavam pousadas?
##   --carona-lente=DIR   sete lentes, um quadro a cada 0,1 s do relogio da cena
##                        em DIR/<lente>/r_<t>.png (o formato do
##                        `tools/mosaico_rajada.py`): `rente` (de fora, rasante
##                        ao vidro, vindo da frente do carro), `fora` (de fora,
##                        na frente e ao lado), `costas` (de fora, atras e
##                        acima) e `dentro` (de dentro da cabine, perto).
##
## O pano e lido de volta da placa (`texture_get_data`) a cada quadro: trava o
## quadro, e por isso a sonda nao serve para medir tempo.
extends Node

## (de, para) no referencial da janela: x para a traseira do carro (o -Z do
## carro, que na cabine e a traseira), y para cima,
## z para fora do vidro, a partir do centro do vao; e o campo (graus).
const LENTES := {
	# Rasante ao vidro, vindo de tras: a palma e a testa no plano.
	"rente": [Vector3(0.95, 0.04, 0.12), Vector3(-0.15, -0.02, 0.03), 34.0],
	# De fora, do lado da frente do carro: a cara de perfil, o braco, o
	# cotovelo e a capa.
	"fora": [Vector3(-0.95, -0.12, 0.8), Vector3(0.05, -0.12, 0.28), 44.0],
	# De fora, acima e atras dele: os bracos saindo da murca, pelas costas.
	"costas": [Vector3(-0.35, 0.5, 1.25), Vector3(0.0, -0.1, 0.3), 46.0],
	# De dentro da cabine, perto: as palmas no vidro, a cara.
	"dentro": [Vector3(0.28, 0.02, -0.72), Vector3(-0.02, -0.02, 0.0), 52.0],
	# Os ombros de perto, como as do capo (`LentesDoCapo`): de lado (vindo da
	# frente do carro e da traseira) e de costas, na altura deles.
	"ombro_frente": [Vector3(-0.85, -0.12, 0.62), Vector3(-0.08, -0.22, 0.36), 40.0],
	"ombro_tras": [Vector3(0.85, -0.12, 0.62), Vector3(0.08, -0.22, 0.36), 40.0],
	"ombro_costas": [Vector3(0.05, 0.3, 1.05), Vector3(0.0, -0.2, 0.36), 42.0],
}
const LENTE_TAMANHO := Vector2i(960, 540)
const LENTE_PASSO := 0.1
## Amostras por osso (umero e antebraco) e faixas do perfil de raio.
const AMOSTRAS := 10
const FAIXAS := 10
## O ombro vive debaixo da murca, que assenta nele: as amostras a menos disto
## (m) do ombro do proprio braco nao contam.
const OMBRO_LIVRE := 0.12

var dono: Node
var sonda := false
var pasta := ""

var _t_seg := 0.0
var _pior: Dictionary = {}
var _perfis: Dictionary = {}
var _pano_lido: Dictionary = {}
var _lentes: Dictionary = {}
## A sonda do braco na capa do capo (`SondaBracoCapa`, `--capo-sonda`), a mesma
## regua: a malha DESENHADA da batina (grade mais desvio) contra o braco vivo.
var _sbc: RefCounted
var _sbc_tentou := false
var _proxima_foto := -1.0
var _minha_t := 0.0


func _init() -> void:
	name = "SondaDoCarona"
	# Depois do `PadresNasJanelas` (100): mede a pose ja deste quadro.
	process_priority = 101
	for a: String in OS.get_cmdline_user_args():
		if a == "--carona-sonda":
			sonda = true
		elif a.begins_with("--carona-lente="):
			pasta = a.trim_prefix("--carona-lente=")


static func quer() -> bool:
	for a: String in OS.get_cmdline_user_args():
		if a == "--carona-sonda" or a.begins_with("--carona-lente="):
			return true
	return false


func agora() -> float:
	var c: Node = dono.get("_cena")
	if c != null and is_instance_valid(c) and "_relogio_cena" in c:
		return float(c.get("_relogio_cena"))
	return _minha_t


# --- geometria da janela -----------------------------------------------------

func _cabine() -> Node3D:
	return dono.get("_cabine")


func _a() -> Dictionary:
	return dono.get("_a")


## O referencial da janela no mundo: origem no centro do vao, x para a frente
## do carro, y para cima (no plano), z para fora.
func _janela() -> Transform3D:
	var cab := _cabine()
	var a := _a()
	var carro: Node3D = dono.get("_carro")
	var n: Vector3 = (cab.global_basis * (a["normal"] as Vector3)).normalized()
	var frente := carro.global_basis * Vector3.FORWARD
	frente = (frente - n * n.dot(frente)).normalized()
	var cima := n.cross(frente).normalized()
	if cima.dot(Vector3.UP) < 0.0:
		cima = -cima
	return Transform3D(Basis(frente, cima, n), cab.to_global(a["centro"] as Vector3))


## A distancia (m) de um ponto do mundo ao plano do vidro: positivo fora.
func _ao_vidro(p: Vector3) -> float:
	var j := _janela()
	return (p - j.origin).dot(j.basis.z)


## A margem (m) de um ponto do mundo dentro do vao, no plano do vidro:
## positivo dentro, negativo fora (na porta, na coluna, no teto).
func _no_vao(p: Vector3) -> float:
	var cab := _cabine()
	var pts: PackedVector3Array = _a()["pontos"]
	var j := _janela()
	var inv := j.affine_inverse()
	var q3 := inv * p
	var q := Vector2(q3.x, q3.y)
	var poli := PackedVector2Array()
	for v: Vector3 in pts:
		var w := inv * cab.to_global(v)
		poli.append(Vector2(w.x, w.y))
	var d := INF
	for i in poli.size():
		var a2 := poli[i]
		var b2 := poli[(i + 1) % poli.size()]
		d = minf(d, q.distance_to(Geometry2D.get_closest_point_to_segment(q, a2, b2)))
	return d if Geometry2D.is_point_in_polygon(q, poli) else -d


# --- o braco -----------------------------------------------------------------

func _osso_mundo(esq: Skeleton3D, i: int) -> Vector3:
	return esq.global_transform * esq.get_bone_global_pose(i).origin


## A palma de verdade (mundo): o meio da face da palma na linha dos nos, preso
## no osso da mao do braco esculpido.
func _palma(b: BracoVivo) -> Vector3:
	var bp := b as BracoDoPadre
	if bp == null or bp._esq == null:
		return _cabine().to_global(b.pegada.get("o", Vector3.ZERO))
	var i: int = bp._o["mao"]
	var g := bp._esq.global_transform * bp._esq.get_bone_global_pose(i) * bp._rg[i].affine_inverse()
	return g * bp._o_rep


## As pontas dos cinco dedos (mundo): o fim da ultima falange.
func _pontas(bp: BracoDoPadre) -> PackedVector3Array:
	var out := PackedVector3Array()
	for d: String in ["indicador", "medio", "anelar", "minimo", "polegar"]:
		if not bp._o.has(d + "_3"):
			continue
		var i3: int = bp._o[d + "_3"]
		var i2: int = bp._o[d + "_2"]
		var comp := bp._rg[i3].origin.distance_to(bp._rg[i2].origin) * 0.9
		# Na reta da falange do meio para a ultima (o eixo Y do osso do glb nem
		# sempre segue o dedo).
		var p3 := bp._esq.get_bone_global_pose(i3).origin
		var p2 := bp._esq.get_bone_global_pose(i2).origin
		out.append(bp._esq.global_transform * (p3 + (p3 - p2).normalized() * comp))
	return out


## O raio da malha do braco (no espaco do esqueleto dele) ao longo do umero e
## do antebraco, por faixa de 1/FAIXAS do osso: a mediana da distancia dos
## vertices ao eixo, no repouso (o miolo do braco com a manga; as faixas soltas
## e a ponta da manga ficam acima dela). A mao fica de fora.
func _perfil(bp: BracoDoPadre) -> Array:
	if _perfis.has(bp.direita):
		return _perfis[bp.direita]
	var mi := bp._pele_mi
	var arr := mi.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ossos: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var por := ossos.size() / maxi(vs.size(), 1)
	var skin := mi.skin
	var esq := bp._esq
	# A malha no repouso: osso de repouso vezes a ligacao (igual para todos).
	var m := Transform3D.IDENTITY
	var nomes_lig: Array[int] = []
	if skin != null:
		for i in skin.get_bind_count():
			var o := skin.get_bind_bone(i)
			if o < 0:
				o = esq.find_bone(skin.get_bind_name(i))
			nomes_lig.append(o)
		m = esq.get_bone_global_rest(nomes_lig[0]) * skin.get_bind_pose(0)
	var ombro := bp._p("braco")
	var cot := bp._p("antebraco")
	var pun := bp._p("mao")
	var faixas: Array = [[], []]
	for s in 2:
		for f in FAIXAS:
			(faixas[s] as Array).append(PackedFloat32Array())
	for v in vs.size():
		# O osso de maior peso: a mao e os dedos ficam de fora.
		var melhor := 0
		var pm := -1.0
		for k in por:
			if pesos[v * por + k] > pm:
				pm = pesos[v * por + k]
				melhor = ossos[v * por + k]
		var osso := nomes_lig[melhor] if melhor < nomes_lig.size() else melhor
		var nome := esq.get_bone_name(osso)
		if nome == "mao" or nome.begins_with("indicador") or nome.begins_with("medio") \
				or nome.begins_with("anelar") or nome.begins_with("minimo") \
				or nome.begins_with("polegar"):
			continue
		var p := m * vs[v]
		var melhor_s := -1
		var melhor_d := INF
		var melhor_t := 0.0
		for s in 2:
			var a3 := ombro if s == 0 else cot
			var b3 := cot if s == 0 else pun
			var ab := b3 - a3
			var t := clampf((p - a3).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var d := p.distance_to(a3 + ab * t)
			if d < melhor_d:
				melhor_d = d
				melhor_s = s
				melhor_t = t
		var fx := mini(int(melhor_t * FAIXAS), FAIXAS - 1)
		var lista: PackedFloat32Array = faixas[melhor_s][fx]
		lista.append(melhor_d)
		faixas[melhor_s][fx] = lista
	var perfil: Array = [PackedFloat32Array(), PackedFloat32Array()]
	for s in 2:
		var pf := PackedFloat32Array()
		for f in FAIXAS:
			var lista: PackedFloat32Array = faixas[s][f]
			lista.sort()
			pf.append(lista[int(lista.size() * 0.5)] if lista.size() > 0 else 0.03)
		perfil[s] = pf
	_perfis[bp.direita] = perfil
	var txt := ""
	for s in 2:
		txt += " %s=[" % ["umero", "antebraco"][s]
		var l1 := ombro.distance_to(cot) if s == 0 else cot.distance_to(pun)
		for f in FAIXAS:
			txt += "%.1f " % ((perfil[s] as PackedFloat32Array)[f] * 100.0 * _escala_braco(bp) )
		txt += "] cm (osso %.1f cm)" % (l1 * 100.0 * _escala_braco(bp))
	print("[carona-sonda] raio da malha, braco %s:%s" % ["D" if bp.direita else "E", txt])
	return perfil


## Metros do mundo por unidade do esqueleto do braco.
func _escala_braco(bp: BracoDoPadre) -> float:
	var esq := bp._esq
	return esq.global_transform.basis.get_scale().x


# --- o pano ------------------------------------------------------------------

func _pano() -> PanoGPU:
	var c: Corpo = dono.get("_corpo")
	if c == null:
		return null
	var capuz := c.get_meta(&"capuz", null) as CapuzMacabro
	return capuz.pano if capuz != null else null


func _ler_pano() -> void:
	var pano := _pano()
	if pano == null:
		return
	if pano._rd == null:
		for pc in pano.pecas:
			if pc.img_pos != null:
				var f := PackedFloat32Array()
				for y in pc.h:
					for x in pc.w:
						var c := pc.img_pos.get_pixel(x, y)
						f.append_array([c.r, c.g, c.b, c.a])
				_pano_lido[pc.nome] = [f, pc.w, pc.h]
		return
	RenderingServer.call_on_render_thread(_ler_na_placa.bind(pano))


func _ler_na_placa(pano: PanoGPU) -> void:
	if not is_instance_valid(pano):
		return
	var rd := RenderingServer.get_rendering_device()
	for pc in pano.pecas:
		if not pc.pos_rid.is_valid():
			continue
		# A textura de posicoes nao deixa copiar; o estado sim: as N primeiras
		# vec4 sao as posicoes (mundo), linha a linha.
		if not pc.estado_rid.is_valid():
			continue
		var f := rd.buffer_get_data(pc.estado_rid, 0, pc.n * 16).to_float32_array()
		if f.size() >= pc.n * 4:
			_pano_lido[pc.nome] = [f, pc.w, pc.h]


## As amostras do braco `b` (mundo): [posicao, raio, rotulo, distancia ao
## ombro do proprio braco].
func _amostras(bp: BracoDoPadre, ombro_corpo: Vector3) -> Array:
	var esq := bp._esq
	var sh := _osso_mundo(esq, bp._o["braco"])
	var el := _osso_mundo(esq, bp._o["antebraco"])
	var wr := _osso_mundo(esq, bp._o["mao"])
	var perfil := _perfil(bp)
	var k := _escala_braco(bp)
	var out: Array = []
	for s in 2:
		var a3 := sh if s == 0 else el
		var b3 := el if s == 0 else wr
		for i in AMOSTRAS:
			var t := (float(i) + 0.5) / float(AMOSTRAS)
			var p := a3.lerp(b3, t)
			var r: float = (perfil[s] as PackedFloat32Array)[mini(int(t * FAIXAS), FAIXAS - 1)] * k
			out.append([p, r, "%s%.2f" % ["U" if s == 0 else "A", t], p.distance_to(sh)])
	return out


## O quanto o pano da peca `nome` passa por dentro do braco: {pen (m, o pior),
## onde, cruza}. Por amostra, a particula mais perto e a normal da grade ali
## (virada para longe do eixo do corpo) dao a distancia com sinal do eixo do
## braco ao pano; `raio - |distancia|` e o quanto a superficie do pano entra na
## do braco (negativo: folga). O braco inteiro debaixo da murca (a folga para
## cima) ou inteiro fora da batina nao conta; o pano cortando o braco conta.
## Amostra alem da borda livre (a barra, a gola) nao conta, nem as de perto
## do ombro do proprio braco (`OMBRO_LIVRE`: a murca assenta nele).
## `cruza`: o eixo do braco passa de um lado para o outro pelo meio do pano (e
## nao pela barra).
func _no_pano(nome: String, amostras: Array, eixo_a: Vector3, eixo_b: Vector3) -> Dictionary:
	var lido: Array = _pano_lido.get(nome, [])
	if lido.is_empty():
		return {}
	var f: PackedFloat32Array = lido[0]
	var w: int = lido[1]
	var h: int = lido[2]
	if f.size() < w * h * 4 or amostras.is_empty():
		return {}
	var caixa := AABB((amostras[0][0] as Vector3), Vector3.ZERO)
	for am: Array in amostras:
		caixa = caixa.expand(am[0])
	caixa = caixa.grow(0.2)
	var perto: Array[int] = []
	for i in w * h:
		var p := Vector3(f[i * 4], f[i * 4 + 1], f[i * 4 + 2])
		if caixa.has_point(p):
			perto.append(i)
	var res := {"pen": -INF, "onde": "", "cruza": ""}
	if perto.is_empty():
		return res
	var ant := 0.0
	var ant_ok := false
	var eixo := eixo_b - eixo_a
	for am: Array in amostras:
		var s: Vector3 = am[0]
		var r: float = am[1]
		if float(am[3]) < OMBRO_LIVRE:
			ant_ok = false
			continue
		var melhor := -1
		var dm := INF
		for i: int in perto:
			var d := s.distance_squared_to(Vector3(f[i * 4], f[i * 4 + 1], f[i * 4 + 2]))
			if d < dm:
				dm = d
				melhor = i
		var x := melhor % w
		var y := melhor / w
		var q := _p(f, w, x, y)
		var du := _p(f, w, posmod(x + 1, w), y) - _p(f, w, posmod(x - 1, w), y)
		var dv := _p(f, w, x, mini(y + 1, h - 1)) - _p(f, w, x, maxi(y - 1, 0))
		var n := du.cross(dv).normalized()
		var t := clampf((q - eixo_a).dot(eixo) / eixo.length_squared(), 0.0, 1.0)
		var fora := q - (eixo_a + eixo * t)
		if n.dot(fora) < 0.0:
			n = -n
		var sd := (s - q).dot(n)
		# Alem da barra (ultima linha) ou da gola (primeira): fora do pano.
		var dvn := dv.normalized()
		var alem := (y == h - 1 and (s - q).dot(dvn) > 0.01) or (y == 0 and (s - q).dot(dvn) < -0.01)
		var lateral := sqrt(maxf((s - q).length_squared() - sd * sd, 0.0))
		var passo := maxf(du.length(), dv.length()) * 0.75
		if alem or lateral > passo:
			ant_ok = false
			continue
		var pen := r - absf(sd)
		if pen > float(res["pen"]):
			res["pen"] = pen
			res["onde"] = am[2]
		if ant_ok and signf(ant) != signf(sd) and absf(ant) < 0.15 and absf(sd) < 0.15:
			res["cruza"] = am[2]
		ant = sd
		ant_ok = true
	return res


static func _p(f: PackedFloat32Array, w: int, x: int, y: int) -> Vector3:
	var i := y * w + x
	return Vector3(f[i * 4], f[i * 4 + 1], f[i * 4 + 2])


# --- o quadro ----------------------------------------------------------------

## Chamado pelo `PadresNasJanelas` no comeco do quadro dele, antes do pano:
## a `SondaBracoCapa` le a capa do quadro anterior e mede contra o braco
## anotado no fim dele.
func antes(delta: float) -> void:
	if _sbc != null:
		_sbc.call(&"passo", delta)


func _ligar_sbc() -> void:
	_sbc_tentou = true
	var quer := false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--capo-sonda"):
			quer = true
	var corpo: Corpo = dono.get("_corpo")
	var pano := _pano()
	var carro: Node3D = dono.get("_carro")
	if not quer or pano == null or carro == null or BatinaAAA._malha == null:
		return
	var sc := load("res://src/levels/sonda_braco_capa.gd") as GDScript
	if sc == null:
		return
	_sbc = sc.new(corpo, pano, carro, 3) as RefCounted
	var a := _a()
	var cab := _cabine()
	_sbc.set(&"vidro_centro", carro.to_local(cab.to_global(a["centro"] as Vector3)))
	_sbc.set(&"vidro_normal", (carro.global_basis.inverse() * (cab.global_basis
		* (a["normal"] as Vector3))).normalized())
	for b: BracoVivo in (dono.get("_maos") as Array):
		_sbc.call(&"por_braco", b, EscaladorDoCarro.MAO_D if b.direita else EscaladorDoCarro.MAO_E)


func _process(delta: float) -> void:
	_minha_t += delta
	var corpo: Corpo = dono.get("_corpo")
	if corpo == null or not is_instance_valid(corpo) or not corpo.visible:
		return
	if not _sbc_tentou and not (dono.get("_maos") as Array).is_empty():
		_ligar_sbc()
	if _sbc != null:
		_sbc.call(&"anotar")
	if not pasta.is_empty():
		_fotografar()
	if sonda:
		_sondar(delta)


func _pior_max(chave: String, v: float, onde: String = "") -> void:
	if not _pior.has(chave) or v > float(_pior[chave][0]):
		_pior[chave] = [v, onde]


func _pior_min(chave: String, v: float, onde: String = "") -> void:
	if not _pior.has(chave) or v < float(_pior[chave][0]):
		_pior[chave] = [v, onde]


var _altura_dita := false


func _sondar(delta: float) -> void:
	var corpo: Corpo = dono.get("_corpo")
	var esq := corpo.esqueleto()
	if not _altura_dita:
		_altura_dita = true
		# A altura dele em pe (a do `Corpo`, que veste a batina e a cabeca) e o
		# braco (fracao do braco do principal).
		var s := corpo.altura() / Corpo.ALTURA_REF
		var jinv := _janela().affine_inverse()
		var poli := ""
		for v: Vector3 in (_a()["pontos"] as PackedVector3Array):
			var w := jinv * _cabine().to_global(v)
			poli += " (%.2f, %.2f)" % [w.x, w.y]
		var no_vidro: Array = dono.get("_no_vidro")
		var ms := ""
		for q: Dictionary in no_vidro:
			var w := jinv * _cabine().to_global(q["o"] as Vector3)
			ms += " (%.2f, %.2f)" % [w.x, w.y]
		var olho := Vector3.INF
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			olho = jinv * cam.global_position
		print("[carona-sonda] janela (x para tras, y para cima, m):%s | palmas:%s | testa %s | lente %s" % [
			poli, ms, jinv * (dono.get("_pose") as CabecadaDoPadre).testa(), olho])
		print("[carona-sonda] altura: corpo %.3f m (escala do no %.3f, s %.4f), braco %.2f do principal" % [
			corpo.altura(), corpo.scale.x, s,
			float(dono.get_script().get_script_constant_map().get("ESCALA_BRACO", 1.0))])
	var maos: Array = dono.get("_maos")
	var pose: CabecadaDoPadre = dono.get("_pose")
	_ler_pano()
	if pose != null:
		var dt := _ao_vidro(pose.testa())
		_pior_min("testa_min", dt)
	var eixo_a := _osso_mundo(esq, Corpo.Osso.QUADRIL)
	var eixo_b := _osso_mundo(esq, Corpo.Osso.CABECA)
	if OS.get_cmdline_user_args().has("--carona-sonda-dump") and int(_minha_t * 30.0) % 6 == 0:
		var j0 := _janela().affine_inverse()
		print("[carona-pos] t=%.2f corpo=%s quadril=%s testa=%s desloca=%.3f dist=%.3f" % [agora(),
			j0 * corpo.global_position, j0 * _osso_mundo(esq, Corpo.Osso.QUADRIL),
			j0 * pose.testa() if pose != null else Vector3.INF,
			float(pose._desloca) if pose != null else 0.0, float(pose.distancia) if pose != null else 0.0])
	if OS.get_cmdline_user_args().has("--carona-sonda-dump") and int(_minha_t * 30.0) % 30 == 0:
		var pn := _pano()
		if pn != null:
			var cs := ""
			for c: Array in pn.colisores():
				cs += " [%d %.3f %.3f r=%.3f]" % [int(c[0]), (c[1] as Vector3).length(), (c[2] as Vector3).distance_to(c[1]), float(c[3])]
			print("[carona-colisores]" + cs)
		var txt := "[carona-dump] t=%.2f quadril=%s cabeca=%s" % [agora(), eixo_a, eixo_b]
		for nome: String in _pano_lido:
			var f: PackedFloat32Array = _pano_lido[nome][0]
			var n: int = int(_pano_lido[nome][1]) * int(_pano_lido[nome][2])
			var cx := AABB(Vector3(f[0], f[1], f[2]), Vector3.ZERO)
			for i in n:
				cx = cx.expand(Vector3(f[i * 4], f[i * 4 + 1], f[i * 4 + 2]))
			txt += " %s=%s+%s" % [nome, cx.position, cx.size]
		print(txt)
	for k in maos.size():
		var b := maos[k] as BracoVivo
		if b == null or not is_instance_valid(b) or not b.visible:
			continue
		var bp := b as BracoDoPadre
		var lado := "D" if b.direita else "E"
		var palma := _palma(b)
		var dp := _ao_vidro(palma)
		_pior_min("palma%s_min" % lado, dp)
		_pior_max("palma%s_max" % lado, dp)
		_pior_min("vao%s" % lado, _no_vao(palma))
		if bp == null or bp._esq == null:
			continue
		var pontas := _pontas(bp)
		var nomes := ["ind", "med", "ane", "min", "pol"]
		if OS.get_cmdline_user_args().has("--carona-sonda-dump") and int(_minha_t * 30.0) % 15 == 0:
			var txt := "[carona-dedos] t=%.2f %s:" % [agora(), lado]
			for i in pontas.size():
				var i3: int = bp._o[["indicador", "medio", "anelar", "minimo", "polegar"][i] + "_3"]
				var i2: int = bp._o[["indicador", "medio", "anelar", "minimo", "polegar"][i] + "_2"]
				var i1: int = bp._o[["indicador", "medio", "anelar", "minimo", "polegar"][i] + "_1"]
				txt += " %s=%.1f(j1 %.1f j2 %.1f j3 %.1f)" % [nomes[i], _ao_vidro(pontas[i]) * 1000.0,
					_ao_vidro(_osso_mundo(bp._esq, i1)) * 1000.0, _ao_vidro(_osso_mundo(bp._esq, i2)) * 1000.0,
					_ao_vidro(_osso_mundo(bp._esq, i3)) * 1000.0]
			print(txt)
		for i in pontas.size():
			var dv := _ao_vidro(pontas[i])
			_pior_min("dedo%s_min" % lado, dv, nomes[i])
			_pior_max("dedo%s_max" % lado, dv, nomes[i])
			_pior_min("vao_dedo%s" % lado, _no_vao(pontas[i]), nomes[i])
		var ombro_corpo := _osso_mundo(esq, Corpo.Osso.BRACO_D if b.direita else Corpo.Osso.BRACO_E)
		var sh := _osso_mundo(bp._esq, bp._o["braco"])
		var el := _osso_mundo(bp._esq, bp._o["antebraco"])
		var wr := _osso_mundo(bp._esq, bp._o["mao"])
		var om := ombro_corpo.distance_to(palma)
		_pior_min("ombro_mao%s_min" % lado, om)
		_pior_max("ombro_mao%s_max" % lado, om)
		_pior_max("ombro_fora%s" % lado, sh.distance_to(ombro_corpo))
		var ang := rad_to_deg((sh - el).angle_to(wr - el))
		_pior_min("cotovelo%s_min" % lado, ang)
		_pior_max("cotovelo%s_max" % lado, ang)
		# O cotovelo nao pode passar para dentro do vidro.
		_pior_min("cotovelo%s_vidro" % lado, _ao_vidro(el))
		var am := _amostras(bp, ombro_corpo)
		for peca: String in ["Batina", "Murca", "Capuz"]:
			var r := _no_pano(peca, am, eixo_a, eixo_b)
			if r.is_empty():
				continue
			if float(r["pen"]) > -INF:
				_pior_max("pen_%s%s" % [peca, lado], float(r["pen"]), String(r["onde"]))
			if not String(r["cruza"]).is_empty():
				_pior_max("cruza_%s%s" % [peca, lado], 1.0, String(r["cruza"]))
	_t_seg += delta
	if _t_seg >= 1.0:
		_t_seg = 0.0
		_imprimir()


func _imprimir() -> void:
	var l := "[carona-sonda] t=%.1f" % agora()
	var chaves := _pior.keys()
	chaves.sort()
	for c: String in chaves:
		var v: float = _pior[c][0]
		var onde: String = _pior[c][1]
		if c.begins_with("cotovelo") and not c.ends_with("vidro"):
			l += " %s=%.0f" % [c, v]
		elif c.begins_with("cruza"):
			l += " %s@%s" % [c, onde]
		else:
			l += " %s=%.1f%s" % [c, v * 1000.0 if c.begins_with("palma") or c.begins_with("dedo") \
				or c.begins_with("testa") or c.begins_with("pen") else v * 100.0,
				"mm" if c.begins_with("palma") or c.begins_with("dedo") or c.begins_with("testa") \
				or c.begins_with("pen") else "cm"]
			if not onde.is_empty():
				l += "@" + onde
	print(l)
	_pior.clear()


## Chamado pelo `PadresNasJanelas` no contato de cada golpe.
func golpe(g: int) -> void:
	if not sonda:
		return
	var pose: CabecadaDoPadre = dono.get("_pose")
	var maos: Array = dono.get("_maos")
	var pouso: Array = dono.get("_pouso_t")
	var l := "[carona-sonda] GOLPE %d t=%.2f testa=%.1fmm" % [g, agora(),
		_ao_vidro(pose.testa()) * 1000.0 if pose != null else INF]
	for k in maos.size():
		var b := maos[k] as BracoVivo
		if b == null or not is_instance_valid(b):
			continue
		var pt: float = pouso[k] if k < pouso.size() else -1.0
		var dp := _ao_vidro(_palma(b))
		var pousada := pt >= 0.0 and absf(dp) < 0.01
		l += " mao%s=%s(palma %.1fmm, pousou %s)" % ["D" if b.direita else "E",
			"SIM" if pousada else "NAO", dp * 1000.0,
			"ha %.2fs" % (agora() - pt) if pt >= 0.0 else "nunca"]
	print(l)


# --- as lentes ---------------------------------------------------------------

func _fotografar() -> void:
	if _lentes.is_empty():
		for nome: String in LENTES:
			var vp := SubViewport.new()
			vp.name = "Lente_" + nome
			vp.size = LENTE_TAMANHO
			vp.world_3d = get_viewport().world_3d
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			add_child(vp)
			var cam := Camera3D.new()
			cam.fov = float(LENTES[nome][2])
			cam.near = 0.02
			cam.cull_mask = 0xFFFFF
			var principal := get_viewport().get_camera_3d()
			if principal != null:
				cam.attributes = principal.attributes
				cam.environment = principal.environment
			vp.add_child(cam)
			cam.current = true
			_lentes[nome] = [vp, cam]
			DirAccess.make_dir_recursive_absolute(pasta.path_join(nome))
	var j := _janela()
	for nome: String in _lentes:
		var cam: Camera3D = _lentes[nome][1]
		var de: Vector3 = j * (LENTES[nome][0] as Vector3)
		var para: Vector3 = j * (LENTES[nome][1] as Vector3)
		cam.global_transform = Transform3D(Basis.looking_at(para - de, Vector3.UP), de)
	var t := agora()
	if _proxima_foto < 0.0:
		_proxima_foto = t
	if t + 1e-4 < _proxima_foto:
		return
	_proxima_foto += LENTE_PASSO
	_gravar(t)


func _gravar(t: float) -> void:
	await RenderingServer.frame_post_draw
	for nome: String in _lentes:
		var vp: SubViewport = _lentes[nome][0]
		vp.get_texture().get_image().save_png(pasta.path_join(nome).path_join("r_%07.2f.png" % t))
