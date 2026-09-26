## O olho esquerdo do padre saindo da orbita no terceiro golpe, e pendurado.
##
## Por que existe
## --------------
## A cara ja estava esmagada nos dois primeiros golpes; o terceiro precisava de
## uma coisa que o espectador nao esquece. O globo sai da orbita com o tranco,
## gira, e o nervo (preso no fundo da orbita) estica ate segurar — e ele fica
## pendurado na bochecha, balancando, pingando, enquanto o padre encara a lente
## com o outro olho. Entre a orbita e o globo, fios de muco e sangue esticam
## por alguns quadros e arrebentam.
##
## Como funciona
## -------------
## Tudo em espaco de mundo (o no e `top_level`):
##   - o nervo e uma corrente de Verlet presa no fundo da orbita (que anda com a
##     cabeca) e no globo; ele cede, esticando, ate `NERVO_MAX`, como tecido e
##     nao como corda;
##   - o globo e o fim da corrente, mais pesado, com gravidade, arrasto e um
##     giro que o nervo vai acertando (o fundo do olho aponta para ele);
##   - os fios de muco sao retas da borda da orbita ao globo que afinam
##     conforme esticam e arrebentam numa distancia ou num numero de quadros;
##   - nervo e fios sao tubos montados de novo a cada quadro (`ImmediateMesh`),
##     e o sangue sao duas fontes de gotas: a orbita e o globo.
class_name OlhoSolto
extends Node3D

## Onde o nervo prende, na malha da cabeca: na boca da orbita esquerda, junto
## da borda de baixo (a orbita do padre e funda: o fundo em z -0,06, a borda e
## a bochecha em -0,086). Preso no fundo, o globo pendurado ficava atras da
## bochecha.
const ORBITA := Vector3(-0.031, -0.002, -0.075)
## O nervo: comprimento que ja sai da orbita, o maximo que ele estica, quanto
## ele cede por segundo sob tensao, e os raios (m, em escala de gente).
## A corrente vai ate o CENTRO do globo: o nervo que aparece e o comprimento
## menos o raio dele (`CabecaDoPadre.OLHO_R`), no maximo 2 cm.
const NERVO_INICIO := 0.017
const NERVO_MAX := 0.02 + CabecaDoPadre.OLHO_R
const NERVO_CEDE := 0.12
const NERVO_RAIO := 0.0034
const PONTOS := 10
## O cabo desenhado: quantos aneis ao longo e lados.
const CABO_ANEIS := 28
const CABO_LADOS := 10
## O globo molhado gruda na bochecha: quanto da velocidade de lado ele perde
## por subpasso encostado.
const GRUDA := 0.35
## A cara como colisor: a frente da propria malha da cabeca, numa grade de
## alturas (z da frente por x, y, no espaco da malha) tirada uma vez dos
## vertices, mais o recuo dos amassados de agora (`CabecaDoPadre.recuo_em`).
## O elipsoide do cranio que havia antes ficava 2,5 cm na frente da orbita: com
## o nervo curto o globo boiava no ar. Perto da orbita (`SOLTO_DA_ORBITA`) o
## nervo passa livre: ali e o buraco dela.
const GRADE_DE := Vector2(-0.07, -0.12)
const GRADE_PASSO := 0.004
const GRADE_N := Vector2i(36, 48)
const SOLTO_DA_ORBITA := 0.012
## Os fios de muco: quantos, em que distancia arrebentam (m) e em quantos
## quadros no maximo.
const FIOS := 4
const FIO_ARREBENTA := Vector2(0.018, 0.04)
const FIO_QUADROS := Vector2i(8, 16)
const FIO_RAIO := 0.0007
const GRAVIDADE := Vector3(0.0, -9.8, 0.0)
## O passo da simulacao e o arrasto (1/s), por tempo e nao por quadro: com o
## arrasto por subpasso, a 4K e poucos quadros por segundo o globo quase nao
## perdia velocidade e chicoteava no nervo o stare inteiro. O globo, pesado e
## molhado, para em uma ou duas idas; o nervo, tecido, amortece mais.
const PASSO := 1.0 / 240.0
const ARRASTO_GLOBO := 8.0
const ARRASTO_NERVO := 12.0
const ITERACOES := 10

static var _frente := PackedFloat32Array()

var _cab: Node3D
var _olho: MeshInstance3D
var _escala := 1.0
var _nervo := PackedVector3Array()
var _antes := PackedVector3Array()
var _comprimento := NERVO_INICIO
var _giro := Vector3.ZERO
var _fios: Array = []   # [borda local na cabeca, ponto local no globo, quadros, arrebentou]
var _malha: ImmediateMesh
var _mi: MeshInstance3D
var _mat_nervo: StandardMaterial3D
var _mat_fio: StandardMaterial3D
var _gotas_orbita: GPUParticles3D
var _gotas_olho: GPUParticles3D
var _t := 0.0
var _solto := false
var _rng := RandomNumberGenerator.new()


## Prepara as malhas e as gotas (no preaquecimento: o material das particulas
## compila ali, e nao no quadro do golpe).
func preparar(pai: Node) -> void:
	name = "OlhoSolto"
	top_level = true
	pai.add_child(self)
	_rng.seed = 6061
	_montar_frente()
	_malha = ImmediateMesh.new()
	_mi = MeshInstance3D.new()
	_mi.name = "Nervo"
	_mi.mesh = _malha
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.extra_cull_margin = 2.0
	add_child(_mi)
	# Tecido molhado e fosco: a cor vem por vertice (rosa-carne, vasos,
	# sangue perto da orbita). Com rim e brilho alto o nervo lia plastico.
	_mat_nervo = StandardMaterial3D.new()
	_mat_nervo.vertex_color_use_as_albedo = true
	_mat_nervo.vertex_color_is_srgb = true
	_mat_nervo.roughness = 0.42
	_mat_nervo.metallic_specular = 0.35
	_mat_fio = StandardMaterial3D.new()
	_mat_fio.albedo_color = Color(0.42, 0.06, 0.05, 0.78)
	_mat_fio.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_fio.roughness = 0.05
	_mat_fio.metallic_specular = 0.8
	_mat_fio.cull_mode = BaseMaterial3D.CULL_DISABLED
	# So o que ja escorre: pingos soltando, sem borrifo.
	_gotas_orbita = _fonte_de_gotas("GotasOrbita", 22, 1.1)
	_gotas_olho = _fonte_de_gotas("GotasOlho", 10, 0.9)
	visible = false


func _fonte_de_gotas(nome: String, quantas: int, vida: float) -> GPUParticles3D:
	var ps := GPUParticles3D.new()
	ps.name = nome
	ps.amount = quantas
	ps.lifetime = vida
	ps.local_coords = false
	ps.emitting = false
	ps.visibility_aabb = AABB(Vector3(-2, -3, -2), Vector3(4, 4, 4))
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.004
	p.direction = Vector3.DOWN
	# Ja nascem caindo: parada, a gota alinhada na velocidade ficava de pe em
	# direcao nenhuma, um espinho vermelho espetado na orbita.
	p.spread = 8.0
	p.initial_velocity_min = 0.06
	p.initial_velocity_max = 0.12
	p.gravity = GRAVIDADE
	p.particle_flag_align_y = true
	p.scale_min = 0.6
	p.scale_max = 1.5
	ps.process_material = p
	var gota := SphereMesh.new()
	gota.radius = 0.0016
	gota.height = 0.0045
	gota.radial_segments = 8
	gota.rings = 4
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.30, 0.012, 0.01)
	m.roughness = 0.14
	m.metallic_specular = 0.5
	gota.material = m
	ps.draw_pass_1 = gota
	add_child(ps)
	return ps


## Aquece: tudo aparece na frente da lente em `onde` por uns quadros.
func aquecer(ligar: bool, onde: Vector3) -> void:
	if _solto:
		return
	visible = ligar
	if ligar:
		global_position = Vector3.ZERO
		_gotas_orbita.global_position = onde
		_gotas_olho.global_position = onde + Vector3.RIGHT * 0.1
		_gotas_orbita.emitting = true
		_gotas_olho.emitting = true
		_nervo = PackedVector3Array([onde, onde + Vector3.DOWN * 0.05])
		_fios = []
		_desenhar()
		_tubo(PackedVector3Array([onde, onde + Vector3.RIGHT * 0.05]), 0.002, 0.001, _mat_fio)
	else:
		_gotas_orbita.emitting = false
		_gotas_olho.emitting = false
		_malha.clear_surfaces()


## O olho sai: `cab` e a `CabecaDoPadre`, `impulso` a velocidade (m/s, mundo)
## com que o globo deixa a orbita.
func soltar(cab: Node3D, olho: MeshInstance3D, impulso: Vector3) -> void:
	if _solto or cab == null or olho == null:
		return
	_solto = true
	_cab = cab
	_olho = olho
	_escala = cab.global_basis.get_scale().x
	olho.reparent(self, true)
	visible = true
	var fundo := cab.global_transform * ORBITA
	var globo := olho.global_position
	_nervo.resize(PONTOS)
	_antes.resize(PONTOS)
	for i in PONTOS:
		var f := float(i) / float(PONTOS - 1)
		_nervo[i] = fundo.lerp(globo, f)
		_antes[i] = _nervo[i] - impulso * f * (1.0 / 60.0)
	_comprimento = maxf(NERVO_INICIO * _escala, fundo.distance_to(globo))
	_giro = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) \
		.normalized() * _rng.randf_range(9.0, 14.0)
	_fios.clear()
	for k in FIOS:
		var a := TAU * (float(k) + _rng.randf_range(-0.25, 0.25)) / float(FIOS)
		var borda := Vector3(-0.031 + cos(a) * 0.012, 0.004 + sin(a) * 0.010, -0.058)
		var no_globo := Vector3(cos(a), sin(a), 0.4).normalized() * CabecaDoPadre.OLHO_R
		_fios.append([borda, no_globo, _rng.randi_range(FIO_QUADROS.x, FIO_QUADROS.y),
			false, _rng.randf_range(FIO_ARREBENTA.x, FIO_ARREBENTA.y) * _escala])
	_gotas_orbita.restart()
	_gotas_orbita.emitting = true
	_gotas_olho.restart()
	_gotas_olho.emitting = true


func desligar() -> void:
	set_process(false)
	visible = false
	if _gotas_orbita != null:
		_gotas_orbita.emitting = false
	if _gotas_olho != null:
		_gotas_olho.emitting = false


func _process(delta: float) -> void:
	if not _solto or _cab == null or not is_instance_valid(_cab) or delta <= 0.0:
		return
	_t += delta
	var tempo := minf(delta, 1.0 / 15.0)
	var passos := clampi(ceili(tempo / PASSO), 1, 16)
	var dt := tempo / float(passos)
	var solta_globo := exp(-ARRASTO_GLOBO * dt)
	var solta_nervo := exp(-ARRASTO_NERVO * dt)
	var fundo := _cab.global_transform * ORBITA
	var r_olho := CabecaDoPadre.OLHO_R * _escala
	var da_cabeca := _cab.global_transform.affine_inverse()
	for _s in passos:
		# Verlet com arrasto; o globo pesa mais que o nervo.
		for i in range(1, PONTOS):
			var p := _nervo[i]
			var v := (p - _antes[i]) * (solta_globo if i == PONTOS - 1 else solta_nervo)
			_antes[i] = p
			_nervo[i] = p + v + GRAVIDADE * dt * dt
		_nervo[0] = fundo
		_antes[0] = fundo
		# O nervo cede sob tensao, ate o maximo: estica como carne.
		var tenso := fundo.distance_to(_nervo[PONTOS - 1]) > _comprimento * 0.97
		if tenso:
			_comprimento = minf(_comprimento + NERVO_CEDE * _escala * dt, NERVO_MAX * _escala)
		var seg := _comprimento / float(PONTOS - 1)
		for _it in ITERACOES:
			for i in range(PONTOS - 1):
				var a := _nervo[i]
				var b := _nervo[i + 1]
				var d := b - a
				var l := d.length()
				if l < 1e-6:
					continue
				var corr := d * ((l - seg) / l)
				# O ponto 0 esta preso; o globo (o ultimo) se mexe menos.
				var wa := 0.0 if i == 0 else 0.5
				var wb := 0.25 if i + 1 == PONTOS - 1 else 0.5
				var tot := wa + wb
				_nervo[i] = a + corr * (wa / tot)
				_nervo[i + 1] = b - corr * (wb / tot)
			# O globo nao entra na cara (depois de sair da orbita): pendura na
			# frente da bochecha.
			# So o globo: com os pontos do nervo colidindo (e grudando), o fio
			# dobrava na borda da orbita e ficava travado ali, e o globo nao
			# descia. O nervo e curto e passa pela boca da orbita.
			if _t > 0.05:
				_fora_da_cara(PONTOS - 1, da_cabeca, CabecaDoPadre.OLHO_R)
	# O globo: posicao no fim do nervo, o giro amortecido e o fundo dele
	# puxado para o nervo.
	if _olho != null and is_instance_valid(_olho):
		var g := _nervo[PONTOS - 1]
		var para_nervo := (_nervo[PONTOS - 2] - g).normalized()
		_giro *= exp(-delta * 3.5)
		var b := _olho.global_basis
		var escala := b.get_scale()
		var q := b.orthonormalized().get_rotation_quaternion()
		if _giro.length() > 0.001:
			q = Quaternion(_giro.normalized(), _giro.length() * delta) * q
		# O fundo do globo (-Y da esfera: a pupila e o polo +Y) vira para o nervo.
		var fundo_do_olho := (q * Vector3.DOWN).normalized()
		if fundo_do_olho.dot(para_nervo) < 0.9999:
			var acerta := Quaternion(fundo_do_olho, para_nervo)
			q = Quaternion.IDENTITY.slerp(acerta, clampf(delta * 6.0, 0.0, 1.0)) * q
		_olho.global_transform = Transform3D(Basis(q.normalized()).scaled(escala), g)
		_gotas_olho.global_position = g + Vector3.DOWN * r_olho
	_gotas_orbita.global_position = _cab.global_transform * Vector3(-0.031, -0.004, -0.062)
	# Os fios: esticam, afinam, arrebentam.
	for f: Array in _fios:
		if bool(f[3]):
			continue
		f[2] = int(f[2]) - 1
		var borda: Vector3 = _cab.global_transform * (f[0] as Vector3)
		var no_globo := _olho.global_transform * (f[1] as Vector3) if _olho != null else borda
		if int(f[2]) <= 0 or borda.distance_to(no_globo) > float(f[4]):
			f[3] = true
	_desenhar()


## A grade da frente da cara: para cada celula, o z mais a frente (o menor)
## dos vertices da malha que caem nela. Uma vez so, no preaquecimento.
static func _montar_frente() -> void:
	if not _frente.is_empty() or not CabecaDoPadre._carregar():
		return
	var m := CabecaDoPadre._malha_pele
	_frente.resize(GRADE_N.x * GRADE_N.y)
	_frente.fill(INF)
	for s in m.get_surface_count():
		var vs: PackedVector3Array = m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in vs:
			if v.z > -0.02:
				continue
			var cx := int((v.x - GRADE_DE.x) / GRADE_PASSO)
			var cy := int((v.y - GRADE_DE.y) / GRADE_PASSO)
			if cx < 0 or cy < 0 or cx >= GRADE_N.x or cy >= GRADE_N.y:
				continue
			var k := cy * GRADE_N.x + cx
			_frente[k] = minf(_frente[k], v.z)


## O z da frente da cara em (x, y) da malha, ou INF fora dela.
static func _frente_em(x: float, y: float) -> float:
	if _frente.is_empty():
		return INF
	var cx := int((x - GRADE_DE.x) / GRADE_PASSO)
	var cy := int((y - GRADE_DE.y) / GRADE_PASSO)
	if cx < 0 or cy < 0 or cx >= GRADE_N.x or cy >= GRADE_N.y:
		return INF
	return _frente[cy * GRADE_N.x + cx]


## O ponto `i` da corrente para fora da cara, `folga` na frente dela.
## Empurrar so a posicao virava velocidade no Verlet: o globo levava um chute a
## cada quadro e pulava de lugar. A correcao vai tambem para o quadro anterior,
## e o lado perde velocidade (molhado, gruda).
func _fora_da_cara(i: int, da_cabeca: Transform3D, folga: float) -> void:
	var q := da_cabeca * _nervo[i]
	if q.distance_to(ORBITA) < SOLTO_DA_ORBITA:
		return
	var z := _frente_em(q.x, q.y)
	if z == INF:
		return
	var cab := _cab as CabecaDoPadre
	if cab != null:
		z += cab.recuo_em(Vector3(q.x, q.y, z))
	z -= folga
	# So quem esta encostado atras da frente: bem mais fundo e o buraco da
	# orbita ou da boca, e ali nao ha pele para empurrar. O globo nasce dentro
	# da orbita (uns 3 cm atras da frente da celula dela) e tem de sair.
	var fundo := 0.045 if i == PONTOS - 1 else 0.02
	if q.z <= z or q.z > z + fundo:
		return
	var fora := _cab.global_transform * Vector3(q.x, q.y, z)
	var nrm := (fora - _nervo[i]).normalized()
	var v := _nervo[i] - _antes[i]
	v -= nrm * minf(v.dot(nrm), 0.0)
	v *= 1.0 - GRUDA
	_nervo[i] = fora
	_antes[i] = fora - v


func _desenhar() -> void:
	_malha.clear_surfaces()
	if _nervo.size() < 2:
		return
	# O nervo: afina conforme estica.
	var afina := sqrt(clampf(NERVO_INICIO * _escala * 2.5 / maxf(_comprimento, 1e-4), 0.6, 1.0))
	_cabo(_nervo, NERVO_RAIO * _escala * afina * 1.15, NERVO_RAIO * _escala * afina * 0.7)
	if _cab == null or _olho == null or not is_instance_valid(_olho):
		return
	for f: Array in _fios:
		var borda: Vector3 = _cab.global_transform * (f[0] as Vector3)
		var no_globo: Vector3 = _olho.global_transform * (f[1] as Vector3)
		if bool(f[3]):
			# Arrebentado: sobra um pingo pendurado em cada ponta.
			var pingo := Vector3.DOWN * 0.006 * _escala
			_tubo(PackedVector3Array([borda, borda + pingo]), FIO_RAIO * _escala * 1.6,
				FIO_RAIO * _escala * 0.4, _mat_fio)
			_tubo(PackedVector3Array([no_globo, no_globo + pingo * 0.8]), FIO_RAIO * _escala * 1.4,
				FIO_RAIO * _escala * 0.3, _mat_fio)
			continue
		var l := borda.distance_to(no_globo)
		var fino := clampf(0.012 * _escala / maxf(l, 1e-4), 0.25, 1.0)
		# O fio cede no meio: uma barriga para baixo.
		var meio := borda.lerp(no_globo, 0.5) + Vector3.DOWN * l * 0.18
		_tubo(PackedVector3Array([borda, meio, no_globo]), FIO_RAIO * _escala * fino,
			FIO_RAIO * _escala * fino, _mat_fio)


## O nervo como cabo de tecido: a polilinha alisada em `CABO_ANEIS` aneis, o
## raio de `r0` (orbita, grosso) a `r1` (globo) com calombos, a cor por
## vertice (carne rosa, sangue perto da orbita, listras de vaso) e dois vasos
## finos enrolados nele.
func _cabo(pts: PackedVector3Array, r0: float, r1: float) -> void:
	var liso := _alisar(pts, CABO_ANEIS)
	var n := liso.size()
	if n < 2:
		return
	var carne := Color(0.80, 0.50, 0.47)
	var escura := Color(0.52, 0.12, 0.10)
	var vaso := Color(0.36, 0.03, 0.03)
	var sangue := Color(0.30, 0.02, 0.02)
	var raios := PackedFloat32Array()
	raios.resize(n)
	for i in n:
		var f := float(i) / float(n - 1)
		var calombo := 1.0 + 0.16 * sin(f * 23.0 + 1.3) + 0.09 * sin(f * 51.0 + 4.1)
		# Junto da orbita o cabo alarga: o tecido rasgado do fundo dela.
		raios[i] = lerpf(r0, r1, pow(f, 0.7)) * calombo * (1.0 + 0.2 * maxf(0.0, 1.0 - f * 6.0))
	_malha.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat_nervo)
	var aneis: Array = []
	var ref := Vector3.UP
	for i in n:
		var t := (liso[mini(i + 1, n - 1)] - liso[maxi(i - 1, 0)]).normalized()
		if absf(t.dot(ref)) > 0.95:
			ref = Vector3.RIGHT
		var u := t.cross(ref).normalized()
		var v := t.cross(u).normalized()
		var f := float(i) / float(n - 1)
		var anel: Array = []
		for k in CABO_LADOS:
			var a := TAU * float(k) / float(CABO_LADOS)
			var dir := u * cos(a) + v * sin(a)
			# Carne manchada, listras de vaso pelo comprimento, e o sangue nas
			# duas pontas (a orbita e o globo): rosa liso lia tubo de borracha.
			var mancha := 0.5 + 0.5 * sin(f * 17.0 + float(k) * 0.9) * sin(f * 7.3 - float(k) * 1.7)
			var listra := smoothstep(0.6, 1.0, cos(a * 2.0 + f * 5.0))
			var c := carne.lerp(escura, mancha * 0.55)
			c = c.lerp(vaso, listra * 0.85)
			c = c.lerp(sangue, clampf(1.0 - f * 2.5, 0.0, 1.0) * 0.85)
			c = c.lerp(sangue, clampf((f - 0.85) * 6.0, 0.0, 1.0) * 0.6)
			anel.append([liso[i] + dir * raios[i], dir, c])
		aneis.append(anel)
	for i in range(1, n):
		for k in CABO_LADOS:
			var k2 := (k + 1) % CABO_LADOS
			for q: Array in [aneis[i - 1][k], aneis[i][k], aneis[i][k2],
					aneis[i - 1][k], aneis[i][k2], aneis[i - 1][k2]]:
				_malha.surface_set_color(q[2])
				_malha.surface_set_normal(q[1])
				_malha.surface_add_vertex(q[0])
	_malha.surface_end()


## A polilinha `pts` reamostrada em `n` pontos, com os cantos alisados (media
## dos vizinhos, as pontas presas).
func _alisar(pts: PackedVector3Array, n: int) -> PackedVector3Array:
	var m := pts.size()
	var out := PackedVector3Array()
	if m < 2:
		return out
	var acum := PackedFloat32Array([0.0])
	for i in range(1, m):
		acum.append(acum[i - 1] + pts[i].distance_to(pts[i - 1]))
	var total := maxf(acum[m - 1], 1e-6)
	var j := 0
	for i in n:
		var s := total * float(i) / float(n - 1)
		while j < m - 2 and acum[j + 1] < s:
			j += 1
		var seg := maxf(acum[j + 1] - acum[j], 1e-6)
		out.append(pts[j].lerp(pts[j + 1], clampf((s - acum[j]) / seg, 0.0, 1.0)))
	for _p in 2:
		var liso := out.duplicate()
		for i in range(1, n - 1):
			liso[i] = (out[i - 1] + out[i] * 2.0 + out[i + 1]) * 0.25
		out = liso
	return out


## Um tubo de 7 lados pela polilinha `pts`, com o raio indo de `r0` a `r1`.
func _tubo(pts: PackedVector3Array, r0: float, r1: float, mat: Material) -> void:
	var n := pts.size()
	if n < 2:
		return
	var lados := 7
	_malha.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	var anel_ant: Array[Vector3] = []
	var nor_ant: Array[Vector3] = []
	var ref := Vector3.UP
	for i in n:
		var t := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		if absf(t.dot(ref)) > 0.95:
			ref = Vector3.RIGHT
		var u := t.cross(ref).normalized()
		var v := t.cross(u).normalized()
		var r := lerpf(r0, r1, float(i) / float(n - 1))
		var anel: Array[Vector3] = []
		var nor: Array[Vector3] = []
		for k in lados:
			var a := TAU * float(k) / float(lados)
			var dir := u * cos(a) + v * sin(a)
			anel.append(pts[i] + dir * r)
			nor.append(dir)
		if i > 0:
			for k in lados:
				var k2 := (k + 1) % lados
				for par: Array in [[anel_ant[k], nor_ant[k]], [anel[k], nor[k]], [anel[k2], nor[k2]],
						[anel_ant[k], nor_ant[k]], [anel[k2], nor[k2]], [anel_ant[k2], nor_ant[k2]]]:
					_malha.surface_set_normal(par[1])
					_malha.surface_add_vertex(par[0])
		anel_ant = anel
		nor_ant = nor
	_malha.surface_end()
