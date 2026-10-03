## O padre cuspindo sangue na lente: na frase ("que bom que voce veio"), nas
## plosivas, e o sangue pingando da cara dele na lente no ultimo olhar (Parte 2
## de `INTRO-PADRE/PLANO_BOCA_SANGUE.md`).
##
## Como funciona
## -------------
## Em espaco de mundo (`top_level`):
##   - as gotas grossas sao uma lista na CPU (posicao, velocidade, raio),
##     balisticas, desenhadas num `MultiMeshInstance3D` (esticadas na
##     velocidade). A que cruza o plano da lente (`LENTE` na frente dela, dentro
##     do quadro) vira respingo no `SangueNaLente`, no ponto da tela onde bateu,
##     com os espinhos para onde ela ia;
##   - a nevoa fina e uma rajada de particulas so para o olho (`GPUParticles3D`),
##     e a parte dela que chega na lente e um `SangueNaLente.nevoa`, no tempo do
##     voo;
##   - na frase, `CabecaDoPadre.falar(FALA_QUE_BOM)` chama `na_frase`, que marca
##     os cuspes de `NA_FRASE` no relogio do jogo (o hit stop segura junto).
## Um so por cena (`de`), como o `SangueNaLente`.
class_name CuspeDeSangue
extends Node3D

const GOTAS_MAX := 160
const GRAVIDADE := Vector3(0.0, -9.8, 0.0)
const ARRASTO := 1.5
## A gota bate na "tela" quando passa deste tanto na frente da lente (m): um
## vidro virtual a um palmo do olho. A 3 cm a janela da lente tinha 2,7 cm de
## altura, e quase toda gota passava ao lado.
const LENTE := 0.12
## O respingo na tela: raio (fracao da altura) por metro de raio da gota, e os
## limites.
const TELA_POR_RAIO := 30.0
const TELA_MIN := 0.006
const TELA_MAX := 0.11
## Os cuspes da frase (s depois da primeira silaba, forca): o "b" de bom, o "v"
## de voce, o "v" de veio, e um escarro no fim.
const NA_FRASE := [[0.33, 0.8], [0.82, 0.65], [1.52, 1.0], [2.08, 1.7]]
## De onde sai (malha da cabeca): a boca, na frente dos dentes; e o queixo.
const BOCA := Vector3(0.0, -0.061, -0.103)
const QUEIXO := Vector3(0.004, -0.150, -0.083)
## Gotas grossas por cuspe de forca 1, raio delas (m), velocidade (m/s) e a
## abertura do cone (rad).
const GROSSAS := 15
const RAIO := Vector2(0.0009, 0.0028)
const VELOCIDADE := Vector2(3.2, 5.2)
const CONE := 0.28
## O pingar do queixo: intervalo entre gotas (s) e raio.
const PINGO_A_CADA := Vector2(0.18, 0.5)
const PINGO_RAIO := Vector2(0.0018, 0.0032)

static var _atual: CuspeDeSangue

var _gotas: Array[Dictionary] = []
var _mm: MultiMesh
var _mmi: MultiMeshInstance3D
var _nevoa: GPUParticles3D
var _rng := RandomNumberGenerator.new()
var _pinga_de: Node3D
var _pinga_ate := 0.0
var _pinga_prox := 0.0
var _t := 0.0


## O cuspe desta cena (um so, mesmo que perguntem de outro no).
static func de(cena: Node) -> CuspeDeSangue:
	if _atual != null and is_instance_valid(_atual) and _atual.is_inside_tree():
		return _atual
	var c := CuspeDeSangue.new()
	cena.add_child(c)
	_atual = c
	return c


func _ready() -> void:
	name = "CuspeDeSangue"
	top_level = true
	_rng.seed = 4242
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.instance_count = GOTAS_MAX
	var esfera := SphereMesh.new()
	esfera.radius = 1.0
	esfera.height = 2.0
	esfera.radial_segments = 10
	esfera.rings = 6
	_mm.mesh = esfera
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.30, 0.012, 0.01)
	m.roughness = 0.14
	m.metallic_specular = 0.5
	esfera.material = m
	_mmi = MultiMeshInstance3D.new()
	_mmi.name = "Gotas"
	_mmi.multimesh = _mm
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mmi.extra_cull_margin = 4.0
	add_child(_mmi)
	_nevoa = _fonte_de_nevoa()
	# O pipeline das gotas compila agora, na lente (uma gota de nada na frente
	# dela), e nao no primeiro cuspe.
	_mm.visible_instance_count = 1
	var cam := get_viewport().get_camera_3d()
	var onde := cam.global_transform * Vector3(0.0, 0.0, -0.5) if cam != null else Vector3.ZERO
	_mm.set_instance_transform(0, Transform3D(Basis().scaled(Vector3.ONE * 1e-5), onde))
	SangueNaLente.de(get_parent())


func _fonte_de_nevoa() -> GPUParticles3D:
	var ps := GPUParticles3D.new()
	ps.name = "Nevoa"
	ps.amount = 90
	ps.lifetime = 0.5
	ps.one_shot = true
	ps.explosiveness = 0.92
	ps.local_coords = false
	ps.emitting = false
	ps.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.006
	p.direction = Vector3(0.0, 0.1, 1.0)
	p.spread = 22.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = GRAVIDADE
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.scale_min = 0.4
	p.scale_max = 1.2
	ps.process_material = p
	var gota := SphereMesh.new()
	gota.radius = 0.0006
	gota.height = 0.0012
	gota.radial_segments = 6
	gota.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.30, 0.012, 0.01)
	m.roughness = 0.14
	m.metallic_specular = 0.5
	gota.material = m
	ps.draw_pass_1 = gota
	add_child(ps)
	return ps


## Os cuspes da frase, marcados a partir de agora no relogio do jogo.
func na_frase(cab: Node3D) -> void:
	for c: Array in NA_FRASE:
		var t := get_tree().create_timer(float(c[0]), false)
		t.timeout.connect(cuspir.bind(cab, float(c[1])))


## Um cuspe da boca de `cab` (a `CabecaDoPadre`) na direcao da lente.
func cuspir(cab: Node3D, forca: float = 1.0) -> void:
	if cab == null or not is_instance_valid(cab) or not cab.is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var boca := cab.global_transform * BOCA
	var dist := boca.distance_to(cam.global_position)
	# Mira um nada acima da lente: a gota cai no caminho.
	var alvo := cam.global_position + Vector3.UP * dist * 0.12
	var para := (alvo - boca).normalized()
	var n := int(round(float(GROSSAS) * forca)) + _rng.randi_range(-1, 2)
	for i in n:
		# Dois tercos vem na lente; o resto abre em volta.
		var cone := CONE * 0.35 if i % 3 != 2 else CONE * (0.8 + 0.5 * forca)
		var d := _no_cone(para, cone)
		var v := d * _rng.randf_range(VELOCIDADE.x, VELOCIDADE.y) * (0.8 + 0.2 * forca)
		var r := _rng.randf_range(RAIO.x, RAIO.y) * (0.8 + 0.3 * forca)
		_nova(boca + d * 0.004, v, r)
	# A nevoa: o que se ve saindo, e o que chega na lente no tempo do voo.
	_nevoa.global_transform = Transform3D(Basis.looking_at(-para, Vector3.UP), boca)
	_nevoa.amount = int(60 + 60 * forca)
	_nevoa.restart()
	_nevoa.emitting = true
	var voo := dist / 3.5
	var uv := _na_tela(cam, boca.lerp(cam.global_position, 0.7))
	if uv.x > -0.5:
		var lente := SangueNaLente.de(get_parent())
		var fin := func() -> void:
			if is_instance_valid(lente):
				lente.nevoa(uv + Vector2(_rng.randf_range(-0.05, 0.05), _rng.randf_range(-0.04, 0.06)),
					0.14 + 0.1 * forca, int(30 + 40 * forca))
		get_tree().create_timer(voo, false).timeout.connect(fin)


## O sangue pingando da cara de `cab` (o queixo) enquanto ela esta em cima da
## lente, por `duracao` segundos (0: ate `parar_de_pingar`).
func pingar_na_lente(cab: Node3D, duracao: float = 0.0) -> void:
	_pinga_de = cab
	_pinga_ate = _t + duracao if duracao > 0.0 else INF
	_pinga_prox = _t


func parar_de_pingar() -> void:
	_pinga_de = null


func _no_cone(eixo: Vector3, ang: float) -> Vector3:
	var u := eixo.cross(Vector3.UP)
	if u.length() < 0.01:
		u = eixo.cross(Vector3.RIGHT)
	u = u.normalized()
	var w := eixo.cross(u).normalized()
	var a := _rng.randf_range(0.0, TAU)
	var r := ang * sqrt(_rng.randf())
	return (eixo + (u * cos(a) + w * sin(a)) * tan(r)).normalized()


func _nova(p: Vector3, v: Vector3, r: float) -> void:
	if _gotas.size() >= GOTAS_MAX:
		_gotas.pop_front()
	_gotas.append({"p": p, "v": v, "r": r, "t": 0.0})


## O ponto `p` (mundo) na tela da lente, de 0 a 1 (y para baixo); x < -0,5 se
## atras dela.
func _na_tela(cam: Camera3D, p: Vector3) -> Vector2:
	if cam.is_position_behind(p):
		return Vector2(-1.0, -1.0)
	var tam := cam.get_viewport().get_visible_rect().size
	return cam.unproject_position(p) / tam


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	# O pingar do queixo.
	if _pinga_de != null and is_instance_valid(_pinga_de) and _t < _pinga_ate:
		if _t >= _pinga_prox:
			var q := _pinga_de.global_transform * (QUEIXO + Vector3(_rng.randf_range(-0.012, 0.012), 0.0,
				_rng.randf_range(-0.004, 0.004)))
			_nova(q, Vector3(_rng.randf_range(-0.05, 0.05), -0.05, _rng.randf_range(-0.05, 0.05)),
				_rng.randf_range(PINGO_RAIO.x, PINGO_RAIO.y))
			_pinga_prox = _t + _rng.randf_range(PINGO_A_CADA.x, PINGO_A_CADA.y)
	if delta <= 0.0:
		_desenhar()
		return
	var lente: SangueNaLente = SangueNaLente.de(get_parent()) if cam != null else null
	var cam_inv := cam.global_transform.affine_inverse() if cam != null else Transform3D.IDENTITY
	var fim: Array[Dictionary] = []
	for g: Dictionary in _gotas:
		var p: Vector3 = g["p"]
		var v: Vector3 = g["v"]
		var antes := p
		v += GRAVIDADE * delta
		v *= exp(-ARRASTO * delta)
		p += v * delta
		g["p"] = p
		g["v"] = v
		g["t"] = float(g["t"]) + delta
		if cam != null:
			var za := (cam_inv * antes).z
			var zb := (cam_inv * p).z
			# Cruzou o plano da lente (na frente dela) neste quadro.
			if za < -LENTE and zb >= -LENTE:
				var k := (-LENTE - za) / maxf(zb - za, 1e-6)
				var bate := antes.lerp(p, k)
				var uv := _na_tela(cam, bate)
				if uv.x >= 0.0 and uv.x <= 1.0 and uv.y >= 0.0 and uv.y <= 1.0 and lente != null:
					var r: float = g["r"]
					var vc := cam_inv.basis * v
					var dir := Vector2(vc.x, -vc.y)
					var raio := clampf(r * TELA_POR_RAIO, TELA_MIN, TELA_MAX)
					var forca := clampf(r / 0.0018, 0.35, 1.7)
					if r > 0.0025 and _rng.randf() < 0.35:
						lente.gota(uv, raio * 0.6, forca)
					else:
						lente.respingo(uv, raio, forca, dir)
				fim.append(g)
				continue
		if float(g["t"]) > 3.0:
			fim.append(g)
	for g: Dictionary in fim:
		_gotas.erase(g)
	_desenhar()


func _desenhar() -> void:
	var n := mini(_gotas.size(), GOTAS_MAX)
	_mm.visible_instance_count = n
	for i in n:
		var g: Dictionary = _gotas[i]
		var v: Vector3 = g["v"]
		var r: float = g["r"]
		var s := v.length()
		var b := Basis()
		if s > 0.05:
			# Esticada na velocidade: a gota voando e um risco curto.
			var y := v / s
			var x := y.cross(Vector3.UP)
			if x.length() < 0.01:
				x = y.cross(Vector3.RIGHT)
			x = x.normalized()
			var z := x.cross(y).normalized()
			var estica := 1.0 + clampf(s * 0.004 / r, 0.0, 3.0)
			b = Basis(x * r, y * r * estica, z * r)
		else:
			b = Basis().scaled(Vector3.ONE * r)
		_mm.set_instance_transform(i, Transform3D(b, g["p"]))
