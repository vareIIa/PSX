## A boca do padre sangrando depois do estouro: fios de sangue entre os labios
## que esticam quando ele fala e arrebentam, e o sangue pingando do labio de
## baixo (Parte 2 de `INTRO-PADRE/PLANO_BOCA_SANGUE.md`).
##
## Como funciona
## -------------
## Filho da `CabecaDoPadre` que sangra (o principal, `rasga_boca`, dano 3):
##   - tres fios entre a borda do labio de cima e a do de baixo (pontos da boca
##     nova, `tools/boca_padre_forma.py`); o de baixo gira com a queixada. O fio
##     cede no meio, afina esticando, arrebenta passado `ARREBENTA` e sobra um
##     pingo pendurado em cada labio, que encolhe; quando os labios chegam perto
##     (o M da fala) ele pode se refazer;
##   - o pingar do labio de baixo e uma fonte de gotas presa na boca.
## Os materiais sao os do olho pendurado (`OlhoSolto`): o mesmo shader, ja
## aquecido na cena.
class_name BocaSangrando
extends Node3D

## [x, y do labio de cima, y do de baixo] na malha da cabeca, em repouso.
const FIOS := [[-0.012, -0.0485, -0.0668], [0.003, -0.0515, -0.0703], [0.014, -0.0514, -0.0710]]
const Z_CIMA := -0.0995
const Z_BAIXO := -0.0985
## O fio arrebenta passando disto, e se refaz com os labios mais perto que isto
## (m, em escala de gente).
const ARREBENTA := 0.026
const REFAZ := 0.014
const RAIO := 0.0008
## O pingo que sobra pendurado depois de arrebentar (m) e quanto encolhe por s.
const PINGO := 0.007
const PINGO_ENCOLHE := 0.004

var _cab: CabecaDoPadre
var _escala := 1.0
var _fios: Array = []
var _malha: ImmediateMesh
var _mat: StandardMaterial3D
var _gotas: GPUParticles3D
var _rng := RandomNumberGenerator.new()


func ligar(cab: CabecaDoPadre) -> void:
	name = "BocaSangrando"
	top_level = true
	_cab = cab
	_escala = cab.global_basis.get_scale().x
	_rng.seed = 911
	_malha = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.name = "Fios"
	mi.mesh = _malha
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	add_child(mi)
	# O fio de muco do olho (`OlhoSolto._mat_fio`): sangue ralo, molhado.
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.42, 0.06, 0.05, 0.78)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.roughness = 0.05
	_mat.metallic_specular = 0.8
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for f: Array in FIOS:
		_fios.append({"vivo": true, "cima": 0.0, "baixo": 0.0})
	_gotas = _fonte_de_gotas()
	_gotas.emitting = true


## As gotas do olho (`OlhoSolto._fonte_de_gotas`), numa faixa do labio de baixo.
func _fonte_de_gotas() -> GPUParticles3D:
	var ps := GPUParticles3D.new()
	ps.name = "Pinga"
	ps.amount = 26
	ps.lifetime = 1.1
	ps.local_coords = false
	ps.visibility_aabb = AABB(Vector3(-2, -3, -2), Vector3(4, 4, 4))
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.016, 0.001, 0.002) * _escala
	p.direction = Vector3.DOWN
	p.spread = 8.0
	p.initial_velocity_min = 0.06
	p.initial_velocity_max = 0.12
	p.gravity = Vector3(0.0, -9.8, 0.0)
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


## Um ponto do labio de baixo (malha) com a queixada de agora, no mundo.
func _de_baixo(p: Vector3) -> Vector3:
	var a := -_cab._abre * CabecaDoPadre.GIRO_QUEIXADA
	var q := CabecaDoPadre.PIVO + Basis(Vector3.RIGHT, a) * (p - CabecaDoPadre.PIVO)
	return _cab.global_transform * q


func _process(delta: float) -> void:
	if _cab == null or not is_instance_valid(_cab):
		return
	_escala = _cab.global_basis.get_scale().x
	_malha.clear_surfaces()
	var meio_baixo := _de_baixo(Vector3(0.004, -0.071, Z_BAIXO))
	_gotas.global_position = meio_baixo + Vector3.DOWN * 0.002 * _escala
	_gotas.global_basis = _cab.global_basis.orthonormalized()
	for i in FIOS.size():
		var f: Array = FIOS[i]
		var st: Dictionary = _fios[i]
		var a := _cab.global_transform * Vector3(float(f[0]), float(f[1]) - 0.0008, Z_CIMA)
		var b := _de_baixo(Vector3(float(f[0]) + 0.0015, float(f[2]) + 0.0008, Z_BAIXO))
		var l := a.distance_to(b) / maxf(_escala, 1e-4)
		if bool(st["vivo"]):
			if l > ARREBENTA * (0.85 + 0.3 * float(i) / 2.0):
				st["vivo"] = false
				st["cima"] = PINGO * _rng.randf_range(0.6, 1.0)
				st["baixo"] = PINGO * _rng.randf_range(0.3, 0.6)
			else:
				# Cede no meio, e afina esticando.
				var meio := a.lerp(b, 0.5) + Vector3.DOWN * l * _escala * 0.22
				var fino := clampf(0.012 / maxf(l, 1e-4), 0.3, 1.2)
				_tubo([a, a.lerp(meio, 0.6), meio, meio.lerp(b, 0.6), b], RAIO * _escala * fino * 1.3,
					RAIO * _escala * fino)
		else:
			st["cima"] = maxf(float(st["cima"]) - PINGO_ENCOLHE * delta, 0.0)
			st["baixo"] = maxf(float(st["baixo"]) - PINGO_ENCOLHE * delta, 0.0)
			if float(st["cima"]) > 0.0005:
				_tubo([a, a + Vector3.DOWN * float(st["cima"]) * _escala], RAIO * _escala * 1.6,
					RAIO * _escala * 0.6)
			if float(st["baixo"]) > 0.0005:
				_tubo([b, b + Vector3.DOWN * float(st["baixo"]) * _escala * 0.5], RAIO * _escala * 1.3,
					RAIO * _escala * 0.5)
			if l < REFAZ and _rng.randf() < delta * 3.0:
				st["vivo"] = true


## Um tubo de 6 lados pela polilinha `pts`, com o raio de `r0` a `r1`.
func _tubo(pts: Array, r0: float, r1: float) -> void:
	var n := pts.size()
	if n < 2:
		return
	var lados := 6
	_malha.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat)
	var ant: Array = []
	var ref := Vector3.UP
	for i in n:
		var p: Vector3 = pts[i]
		var t := ((pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		if absf(t.dot(ref)) > 0.95:
			ref = Vector3.RIGHT
		var u := t.cross(ref).normalized()
		var w := t.cross(u).normalized()
		var r := lerpf(r0, r1, float(i) / float(n - 1))
		var anel: Array = []
		for k in lados:
			var ang := TAU * float(k) / float(lados)
			var dir := u * cos(ang) + w * sin(ang)
			anel.append([p + dir * r, dir])
		if i > 0:
			for k in lados:
				var k2 := (k + 1) % lados
				for q: Array in [ant[k], anel[k], anel[k2], ant[k], anel[k2], ant[k2]]:
					_malha.surface_set_normal(q[1])
					_malha.surface_add_vertex(q[0])
		ant = anel
	_malha.surface_end()
