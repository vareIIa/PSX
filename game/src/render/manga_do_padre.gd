## A manga comprida da batina no braco AAA do padre (`BracoDoPadre`): cobre do
## ombro ate perto do punho, e so a mao e um palmo do antebraco saem dela.
##
## Por que existe
## --------------
## Quando o braco vivo entra no lugar do braco do `Corpo` (a mao na janela do
## principal, as maos no vidro do capo e do carona), a manga da `BatinaAAA`
## some com o braco escondido (`VigiaDaBatina`), e o braco esculpido so tem um
## trapo no ombro. O braco erguido ficava nu do ombro a mao: comprido, fino,
## "a roupa desce". O pedido e o contrario: a manga continua tapando, com
## sombra dentro, e a mao sai do escuro dela.
##
## Como funciona
## -------------
## - A malha e a manga da propria `BatinaAAA` (a superficie dela, com a textura,
##   a trama e a oclusao assada), desenhada pelo mesmo shader: o braco e a roupa
##   continuam sendo a mesma batina. Sem a franja rasgada da barra
##   (`LINHA_DA_BOCA`). O punho tem sangue pintado na textura (linhas 6 a 8 da
##   grade): na luz branca da bancada le como pele, na da cena, escuro.
## - No repouso, a grade da manga (16 x 12 do pano) e posta no braco esculpido
##   como peca inteira: o eixo dela no do braco, a frente dela (-Z do `Corpo`)
##   para o lado do polegar, a boca na fracao `BARRA` do antebraco, na escala do
##   braco (`escala` dele sobre o braco do `Corpo`). O alto dela cai no ombro.
## - O pano e um `PanoGPU` so dela, com um osso por anel da grade (os ossos vao
##   prontos, `PanoGPU.ossos_de_fora`). Os aneis andam numa linha que faz curva
##   no cotovelo e giram aos poucos do braco para o antebraco; do lado de dentro
##   da curva o anel achata, e o pano franze na dobra em vez de cruzar consigo.
##   Cada particula fica presa no anel dela com a folga e a ancora de alcance da
##   batina: a barra balanca e pende para o lado da gravidade, mas nao escorrega
##   pelo braco erguido.
## - Bate no braco, no antebraco e na mao (os raios da malha do braco, os do
##   `BracoNoPano`), e no plano da palma quando ela espalma (o vidro): a manga
##   do antebraco encostado no vidro nao passa para dentro do carro.
## - A sombra: a oclusao assada da manga, o avesso escurecendo da boca para
##   dentro (`boca_linha` no shader da batina) e, no braco, `manga_boca`: a pele
##   escurece da boca da manga para dentro, ate quase preto um palmo adentro. A
##   mao sai do escuro.
##
## `--braco-sem-manga` volta ao braco nu (A/B). `--manga-barra=F` troca a
## `BARRA`.
class_name MangaDoPadre
extends Node3D

## Quanto do antebraco a manga cobre (do cotovelo ao punho): o resto e a mao
## saem dela.
const BARRA := 0.72
## A barra que se ve, na linha da grade da manga. A manga da batina acaba numa
## franja rasgada (tiras de ~10 cm, das linhas 8,5 a 11) feita para o braco
## pendurado: com o braco erguido as tiras ficavam em pe como labareda. A malha
## vai ate aqui; as linhas de baixo continuam no pano, sem malha, e dao o peso
## da barra.
const LINHA_DA_BOCA := 8.6
## O braco do `Corpo` de 1,72 m, do ombro ao punho (m): a manga da batina foi
## feita nele.
const BRACO_DO_CORPO := Corpo.Y_OMBRO - Corpo.Y_PUNHO
## A frente do `Corpo` (a manga da batina foi feita nele, de frente para -Z).
const FRENTE_DO_CORPO := Vector3(0.0, 0.0, -1.0)
## A mais no raio do braco (m): a malha e a grade mais o desvio de cada
## vertice, e a particula para no raio mais a espessura (`BracoNoPano.MARGEM`).
const MARGEM := 0.014
## O raio (m) da esfera que faz o plano da palma, e quanto do lado do braco
## fica a face dela (a manga nao encosta no vidro).
const PLANO_RAIO := 2.0
const PLANO_FOLGA := 0.015
## O cotovelo a esta distancia (m) do plano da palma: o plano liga de todo. Mais
## perto (o braco no plano da mao, pendurado), desliga.
const PLANO_LIGA := Vector2(0.05, 0.12)
## O chao do pano (a origem do esqueleto de procuracao) fica isto abaixo do
## ombro: o chao de verdade nao e dele.
const FUNDO := 2.0
## A mao andou mais que isto num quadro: o pano volta ao repouso.
const SALTO := 0.35
## O raio da boca da manga na grade (m, na pessoa de 1,72 m, com o desvio da
## malha), e ate onde a pele escurece dentro dela (vezes o raio).
const BOCA_RAIO := 0.07
## O raio da curva da linha dos aneis no cotovelo, vezes o raio medio da
## manga: a linha abraca o cotovelo (com a curva grande a quina do cotovelo
## furava a manga por fora), e o que passa do raio da curva, do lado de dentro,
## achata (`ACHATA_ATE` do raio, ate `ACHATA_MIN` do anel).
const CURVA := 0.6
const ACHATA_ATE := 0.9
const ACHATA_MIN := 0.2
## Quantos metros antes e depois da curva o achatado ainda vale (em rampa).
const RAMPA := 0.06
## Onde fica o colisor desligado (no espaco do osso do anel).
const LONGE := Vector3(0.0, -100.0, 0.0)

## Por lado (direita): {malha, grade, id}.
static var _dados: Dictionary = {}

var _braco: BracoDoPadre
var _esq: Skeleton3D
var _pano: PanoGPU
var _mi: MeshInstance3D
var _escala: float = -1.0
var _barra: float = BARRA
## Na escala do braco: a manga sobre a da batina.
var _k: float = 1.0
var _col_plano: int = -1
var _col_mao: int = -1
var _raio_mao: float = 0.0
## Por anel: o centro no eixo do braco (m do ombro, na pessoa) e no repouso.
var _u := PackedFloat32Array()
var _c_rep := PackedVector3Array()
var _raio_curva: float = 0.1
## O maior raio de cada anel (m, na pessoa) e os ossos de agora (mundo).
var _r_anel := PackedFloat32Array()
var _ossos: Array[Transform3D] = []
var _l1: float = 0.0
## O repouso do braco e do antebraco (sem escala), e os nos dos dedos no osso
## da mao (espaco do esqueleto do braco).
var _gira_braco := Basis()
var _gira_ante := Basis()
var _dedos_na_mao := Vector3.ZERO
var _punho_antes := Vector3.INF


## Se o braco AAA leva a manga (a batina AAA carregada e sem `--braco-sem-manga`).
static func usar() -> bool:
	if OS.get_cmdline_user_args().has("--braco-sem-manga"):
		return false
	return BatinaAAA.usar()


## A manga de um lado: a superficie da malha da batina, sem os triangulos que
## tocam outra grade (a costura da cava, que le a batina e a murca e fica dentro
## do corpo), e a grade dela. O lado direito da pessoa e o de x > 0 (a frente
## e -Z).
static func _preparar(direita: bool) -> Dictionary:
	if _dados.has(direita):
		return _dados[direita]
	var d := {}
	_dados[direita] = d
	var id := -1
	for k in BatinaAAA._grades.size():
		var g: Dictionary = BatinaAAA._grades[k]
		if String(g.get("tipo", "")) != "manga":
			continue
		var p0: Array = (g["repouso"] as Array)[0]
		if (float(p0[0]) > 0.0) == direita:
			id = k
	var sups: Dictionary = BatinaAAA._malha.get_meta(&"superficie_de", {})
	var sup := -1
	for k: Variant in sups:
		if int(k) == id:
			sup = int(sups[k])
	if id < 0 or sup < 0:
		push_warning("MangaDoPadre: sem a manga %s na batina" % ("direita" if direita else "esquerda"))
		return d
	var fonte := BatinaAAA._malha
	var arr := fonte.surface_get_arrays(sup)
	var c0: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM0]
	var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var fica := PackedInt32Array()
	for t in idx.size() / 3:
		var ok := true
		for j in 3:
			var v := idx[t * 3 + j]
			if int(c0[v * 4 + 3] + 0.5) != id or uv2[v].y > LINHA_DA_BOCA:
				ok = false
		if ok:
			fica.append_array([idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]])
	arr[Mesh.ARRAY_INDEX] = fica
	var fmt: int = fonte.surface_get_format(sup)
	var flags := 0
	for c in 4:
		var desloca := Mesh.ARRAY_FORMAT_CUSTOM_BASE + c * Mesh.ARRAY_FORMAT_CUSTOM_BITS
		flags |= fmt & (Mesh.ARRAY_FORMAT_CUSTOM_MASK << desloca)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
	d["malha"] = m
	d["grade"] = BatinaAAA._grades[id]
	d["id"] = id
	return d


## Veste o braco `b` (ja montado: o esqueleto e o repouso lidos).
func montar(b: BracoDoPadre) -> void:
	_braco = b
	name = "Manga"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--manga-barra="):
			_barra = clampf(float(a.trim_prefix("--manga-barra=")), 0.0, 1.0)
	_esq = Skeleton3D.new()
	_esq.name = "EsqueletoDaManga"
	_esq.top_level = true
	for i in PanoGPU.OSSOS:
		_esq.add_bone("o%d" % i)
	add_child(_esq)
	_vestir()


## A peca de pano e a malha na escala de agora do braco. De novo quando a cena
## troca a `escala` (o capo e o carona tem o braco menor).
func _vestir() -> void:
	var t0 := Time.get_ticks_usec()
	var b := _braco
	var d := _preparar(b.direita)
	if d.is_empty():
		return
	if _pano != null:
		remove_child(_pano)
		_pano.queue_free()
		_pano = null
		_mi = null
	_escala = b.escala
	var e := _escala
	# O braco no repouso do modelo (reto): ombro, cotovelo e punho.
	var sh := b._p("braco")
	var cot := b._p("antebraco")
	var pun := b._p("mao")
	var l1 := sh.distance_to(cot)
	var l2 := cot.distance_to(pun)
	var eixo := (pun - sh).normalized()
	var polegar := b._lado_rep - eixo * b._lado_rep.dot(eixo)
	polegar = polegar.normalized()
	# A manga da batina no repouso: do centro da cava ao da boca.
	var g: Dictionary = d["grade"]
	var w := int(g["w"])
	var h := int(g["h"])
	var r: Array = g["repouso"]
	var anel := func(j: int) -> Vector3:
		var c := Vector3.ZERO
		for i in w:
			var p: Array = r[j * w + i]
			c += Vector3(p[0], p[1], p[2])
		return c / float(w)
	var topo: Vector3 = anel.call(0)
	var lb := floori(LINHA_DA_BOCA)
	var boca: Vector3 = (anel.call(lb) as Vector3).lerp(anel.call(mini(lb + 1, h - 1)),
		LINHA_DA_BOCA - float(lb))
	var t := (boca - topo).normalized()
	var frente := (FRENTE_DO_CORPO - t * FRENTE_DO_CORPO.dot(t)).normalized()
	# Peca inteira: o eixo da manga no do braco, a frente dela no polegar (a
	# frente do braco pendurado, para onde o antebraco dobra), e o lado de fora
	# no dorso (`BracoDoPadre._ler_repouso`: dorso = eixo x polegar na direita).
	var gira := Basis(eixo, polegar, eixo.cross(polegar)) * Basis(t, frente, t.cross(frente)).transposed()
	_k = (l1 + l2) * e / BRACO_DO_CORPO
	var boca_no_braco := (cot + (pun - cot).normalized() * (_barra * l2)) * e
	var n := w * h
	if h > PanoGPU.OSSOS:
		push_warning("MangaDoPadre: a manga tem %d aneis, o pano le %d ossos" % [h, PanoGPU.OSSOS])
		return
	# Cada anel da manga no seu osso: o centro dele no eixo do braco (`_u`, m do
	# ombro) e as particulas presas so nele. O osso anda numa linha que faz
	# curva no cotovelo (`seguir`): dois ossos misturados dobravam a grade sobre
	# si mesma no lado de dentro do cotovelo, e o desvio da malha virava espeto.
	var rep := PackedVector3Array()
	rep.resize(n)
	var osso := PackedInt32Array()
	osso.resize(n)
	var peso_b := PackedFloat32Array()
	peso_b.resize(n)
	var folga := PackedFloat32Array(g["folga"])
	_u.resize(h)
	_c_rep.resize(h)
	_r_anel.resize(h)
	var medio := 0.0
	for j in h:
		var c := Vector3.ZERO
		for i in w:
			var p: Array = r[j * w + i]
			var q := boca_no_braco + gira * ((Vector3(p[0], p[1], p[2]) - boca) * _k)
			rep[j * w + i] = q
			osso[j * w + i] = j
			folga[j * w + i] *= _k
			c += q
		c /= float(w)
		_u[j] = (c - sh * e).dot(eixo)
		_c_rep[j] = sh * e + eixo * _u[j]
		for i in w:
			var dist := (rep[j * w + i] - _c_rep[j]).length()
			_r_anel[j] = maxf(_r_anel[j], dist)
			medio += dist / float(n)
	_raio_curva = medio * CURVA
	_l1 = l1 * e
	_gira_braco = b._rg[int(b._o[&"braco"])].basis.orthonormalized()
	_gira_ante = b._rg[int(b._o[&"antebraco"])].basis.orthonormalized()
	var dedos := Vector3.ZERO
	for nome: String in BracoDoPadre.DEDOS:
		dedos += b._p(nome + "_1")
	dedos /= float(BracoDoPadre.DEDOS.size())
	_dedos_na_mao = b._rg[int(b._o[&"mao"])].affine_inverse() * dedos
	# O esqueleto de procuracao: um osso por anel, no repouso sem giro, no
	# centro do anel (os que sobram ficam na origem).
	for i in PanoGPU.OSSOS:
		var rest := Transform3D(Basis(), _c_rep[i] if i < h else Vector3.ZERO)
		_esq.set_bone_rest(i, rest)
		_esq.set_bone_pose_position(i, rest.origin)
		_esq.set_bone_pose_rotation(i, Quaternion.IDENTITY)
	_pano = PanoGPU.new()
	_pano.esqueleto = _esq
	var raio := BracoNoPano.RAIO_MODELO * e + Vector3.ONE * MARGEM
	var ult := h - 1
	_col_mao = -1
	if not OS.get_cmdline_user_args().has("--manga-sem-colisor"):
		# O braco no anel de cima e o antebraco no da boca (os dois andam inteiros
		# com o osso deles); a mao e o plano da palma, movidos a cada quadro.
		_pano.colisor(0, sh * e - _c_rep[0], cot * e - _c_rep[0], raio.x)
		_pano.colisor(ult, cot * e - _c_rep[ult], pun * e - _c_rep[ult], raio.y)
		_col_mao = _pano.colisor(ult, LONGE, LONGE, raio.z)
	_raio_mao = raio.z
	_col_plano = _pano.colisor(ult, LONGE, LONGE, 0.001)
	var opcoes: Dictionary = (g["opcoes"] as Dictionary).duplicate()
	opcoes["sem_malha"] = true
	opcoes["espessura"] = float(opcoes.get("espessura", 0.01)) * _k
	var pc := _pano.adicionar("Manga", w, h, bool(g["periodico"]), rep, osso, osso, peso_b,
		folga, PackedFloat32Array(g["puxa"]), PackedByteArray(g["preso"]),
		PackedByteArray(g["existe"]), PackedInt32Array(g["ancora"]), opcoes)
	var mat := BatinaAAA.material(_k)
	mat.set_shader_parameter(&"franja_cai", 1.0)
	mat.set_shader_parameter(&"boca_linha", LINHA_DA_BOCA)
	var id := int(d["id"])
	_pano.ligar_textura(pc, mat, StringName("pos%d" % id))
	mat.set_shader_parameter(StringName("grade%d" % id), Vector2i(w, h))
	_mi = MeshInstance3D.new()
	_mi.name = "MalhaDaManga"
	_mi.mesh = d["malha"]
	_mi.material_override = mat
	_mi.custom_aabb = AABB(Vector3(-1.2, -1.2, -1.2), Vector3(2.4, 2.4, 2.4))
	_mi.layers = b.layers
	_pano.acompanhar(_mi, mat)
	add_child(_pano)
	_punho_antes = Vector3.INF
	print("[manga] %s vestida na escala %.3f em %.1f ms" % [b.name, _escala,
		(Time.get_ticks_usec() - t0) / 1000.0])


## O pano volta ao repouso no proximo quadro (o braco mudou de lugar de uma vez).
func reiniciar() -> void:
	if _pano != null:
		_pano.reiniciar()


## A cada quadro, depois de o `BracoDoPadre` montar a pose: os ossos dos
## aneis, a mao e o plano da palma no pano, e a boca da manga na pele. `tx` leva
## o espaco do esqueleto do braco ao do no do braco; `globais` sao os ossos
## montados (espaco do esqueleto); `palma` e `dorso` a face da palma e as costas
## da mao (idem).
func seguir(tx: Transform3D, globais: Dictionary, palma: Vector3, dorso: Vector3,
		pele: MeshInstance3D) -> void:
	var b := _braco
	if b == null:
		return
	if not is_equal_approx(b.escala, _escala):
		_vestir()
	if _pano == null:
		return
	var g := b.global_transform * tx
	var tb := g * (globais[b._o[&"braco"]] as Transform3D)
	var ta := g * (globais[b._o[&"antebraco"]] as Transform3D)
	var tm := g * (globais[b._o[&"mao"]] as Transform3D)
	var sh := tb.origin
	var cot := ta.origin
	var punho := tm.origin
	# O giro de cada osso desde o repouso (o anel no repouso nao tem giro).
	var gb := Quaternion(tb.basis.orthonormalized() * _gira_braco.transposed())
	var ga := Quaternion(ta.basis.orthonormalized() * _gira_ante.transposed())
	var yb := (cot - sh).normalized()
	var ya := (punho - cot).normalized()
	# A curva do cotovelo: um arco tangente ao braco e ao antebraco, do raio da
	# manga; os aneis dali giram aos poucos de um osso ao outro.
	var ang := yb.angle_to(ya)
	var ult := _u.size() - 1
	var tg := 0.0
	var dentro := Vector3.ZERO
	var eixo_curva := Vector3.ZERO
	if ang > 0.03:
		tg = minf(_raio_curva * tan(ang * 0.5), minf(_l1 * 0.5, (_u[ult] - _l1) * 0.9))
		dentro = (ya - yb * ya.dot(yb)).normalized()
		eixo_curva = yb.cross(ya).normalized()
	var raio_arco := tg / tan(ang * 0.5) if tg > 0.0 else 0.0
	var origem := sh + Vector3.DOWN * FUNDO
	_esq.global_transform = Transform3D(Basis(), origem)
	# Dentro da curva os aneis vizinhos se cruzam alem do raio do arco (os
	# planos deles se encontram no centro da curva): la o anel achata na
	# direcao de dentro, e o pano franze na dobra do cotovelo em vez de virar
	# espeto. O de cima e o da boca nunca achatam (os colisores andam neles).
	# Do lado de dentro, no antebraco: para o braco de cima.
	var dentro_a := (-yb - ya * (-yb).dot(ya)).normalized()
	_ossos.resize(PanoGPU.OSSOS)
	for j in _u.size():
		var u := _u[j]
		var pos: Vector3
		var giro: Quaternion
		var para_dentro := Vector3.ZERO
		var achata := 0.0
		if tg <= 0.0 or u <= _l1 - tg:
			pos = sh + yb * u
			giro = gb
			if tg > 0.0:
				para_dentro = dentro
				achata = 1.0 - smoothstep(0.0, RAMPA, (_l1 - tg) - u)
		elif u >= _l1 + tg:
			pos = cot + ya * (u - _l1)
			giro = ga
			para_dentro = dentro_a
			achata = 1.0 - smoothstep(0.0, RAMPA, u - (_l1 + tg))
		else:
			var s := (u - (_l1 - tg)) / (2.0 * tg)
			var inicio := cot - yb * tg
			var centro := inicio + dentro * raio_arco
			pos = centro + (inicio - centro).rotated(eixo_curva, s * ang)
			giro = gb.slerp(ga, s)
			para_dentro = (centro - pos).normalized()
			achata = 1.0
		var base := Basis(giro)
		if j > 0 and j < ult and achata > 0.0 and _r_anel[j] > 0.0:
			var f := lerpf(1.0, clampf(ACHATA_ATE * raio_arco / _r_anel[j], ACHATA_MIN, 1.0), achata)
			var d := para_dentro
			var sq := Basis(Vector3.RIGHT + d * (d.x * (f - 1.0)), Vector3.UP + d * (d.y * (f - 1.0)),
				Vector3.BACK + d * (d.z * (f - 1.0)))
			base = sq * base
		_ossos[j] = Transform3D(base, pos)
	for j in range(_u.size(), PanoGPU.OSSOS):
		_ossos[j] = Transform3D(Basis(), origem)
	_pano.ossos_de_fora = _ossos
	var no_ult := _ossos[ult].affine_inverse()
	if OS.get_cmdline_user_args().has("--manga-sonda") and Engine.get_process_frames() % 60 == 0:
		var ps := []
		for j in _u.size():
			ps.append("%.3f:%s" % [_u[j], _ossos[j].origin])
		print("[manga-sonda] %s ang %.1f tg %.3f raio %.3f l1 %.3f sh %s cot %s pun %s | %s" % [
			b.name, rad_to_deg(ang), tg, raio_arco, _l1, sh, cot, punho, " ".join(ps)])
	_mi.layers = b.layers
	if _punho_antes != Vector3.INF and punho.distance_to(_punho_antes) > SALTO:
		_pano.reiniciar()
	_punho_antes = punho
	if _col_mao >= 0:
		_pano.mover_colisor(_col_mao, no_ult * punho, no_ult * (tm * _dedos_na_mao), _raio_mao)
	# O plano da palma: do lado contrario ao cotovelo, so com o cotovelo fora
	# dele (a mao espalmada no vidro, o braco vindo de tras).
	var p := g * palma
	var nd := (g.basis * dorso).normalized()
	var lado := (cot - p).dot(nd)
	var liga := smoothstep(PLANO_LIGA.x, PLANO_LIGA.y, absf(lado))
	if liga > 0.01:
		var nn := nd * signf(lado)
		var c := p - nn * (PLANO_RAIO - PLANO_FOLGA + (1.0 - liga) * 0.3)
		_pano.mover_colisor(_col_plano, no_ult * c, no_ult * c, PLANO_RAIO)
	else:
		_pano.mover_colisor(_col_plano, LONGE, LONGE, 0.001)
	# A boca da manga na pele (a sombra dela no antebraco).
	var boca := cot + ya * (_barra * cot.distance_to(punho))
	pele.set_instance_shader_parameter(&"manga_boca", Vector4(boca.x, boca.y, boca.z, BOCA_RAIO * _k))
	pele.set_instance_shader_parameter(&"manga_eixo", ya)
