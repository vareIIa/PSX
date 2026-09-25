## O sangue e a carne que voam nas cabecadas do padre na janela.
##
## Por que existe
## --------------
## O sangue desenhado no vidro e na cara diz onde a testa bateu; o que faz o
## golpe doer e o que VOA: o esguicho no instante do impacto, os pedacos de
## pele e cartilagem, os coagulos. E quando o vidro estoura, o sangue que estava
## nele tem de cair junto com os cacos — um desenho parado no ar onde o vidro
## era mata a cena. Depois, com a cabeca dele dentro da cabine, o sangue pinga
## do queixo e da orbita e junta no parapeito da porta.
##
## Como funciona
## -------------
## Emissores feitos no preaquecimento e disparados por `restart` (criar o
## material de processo no quadro do golpe compilava o shader ali, e era o pico
## do trecho — ver `_preparar_estilhacos`):
##   esguicho  gotas finas esticadas na velocidade (`align_y`), muitas
##   pedacos   carne e cartilagem, poucas, girando, pesadas
##   coagulos  gotas gordas pretas-vermelhas
##   do_vidro  o sangue do vidro caindo com os cacos (caixa em volta das marcas)
##   pingos    o queixo pingando, contínuo, na cena de encarar
## Nada colide: o que cai atravessa para dentro da porta e do banco e some
## atras deles. Uma caixa de colisao com atrito (o "parapeito") fazia a gota
## parar no primeiro contato, e onde a caixa nao batia com o forro ela ficava
## parada no ar.
class_name GoreDeCabecada
extends Node3D

const GRAVIDADE := Vector3(0.0, -9.8, 0.0)

var _esguicho: GPUParticles3D
var _pedacos: GPUParticles3D
var _coagulos: GPUParticles3D
var _do_vidro: GPUParticles3D
var _pingos: GPUParticles3D
var _mat_sangue: StandardMaterial3D
var _mat_carne: StandardMaterial3D
var _pingar_de: Node3D
var _pingar_local := Vector3.ZERO


func preparar(pai: Node) -> void:
	name = "GoreDeCabecada"
	top_level = true
	pai.add_child(self)
	_mat_sangue = StandardMaterial3D.new()
	_mat_sangue.albedo_color = Color(0.30, 0.012, 0.01)
	_mat_sangue.roughness = 0.14
	_mat_sangue.metallic_specular = 0.5
	_mat_carne = StandardMaterial3D.new()
	_mat_carne.albedo_color = Color(0.62, 0.12, 0.09)
	_mat_carne.roughness = 0.26
	_mat_carne.metallic_specular = 0.4

	var gota := SphereMesh.new()
	gota.radius = 0.0012
	gota.height = 0.0048
	gota.radial_segments = 6
	gota.rings = 3
	gota.material = _mat_sangue
	var coag := SphereMesh.new()
	coag.radius = 0.0034
	coag.height = 0.0052
	coag.radial_segments = 7
	coag.rings = 4
	coag.material = _mat_sangue
	var pedaco := BoxMesh.new()
	pedaco.size = Vector3(0.007, 0.0045, 0.0028)
	pedaco.material = _mat_carne
	var pingo := SphereMesh.new()
	pingo.radius = 0.0018
	pingo.height = 0.0058
	pingo.radial_segments = 8
	pingo.rings = 4
	pingo.material = _mat_sangue

	# [nome, malha, quantas, vida, vel min, max, espalha, escala min, max, alinha, gira]
	_esguicho = _emissor("Esguicho", gota, 420, 1.6, 1.2, 4.6, 55.0, 0.5, 1.9, true, false)
	_pedacos = _emissor("Pedacos", pedaco, 26, 2.2, 0.9, 2.8, 45.0, 0.5, 1.6, false, true)
	_coagulos = _emissor("Coagulos", coag, 34, 2.2, 0.5, 2.0, 40.0, 0.6, 1.7, false, true)
	_do_vidro = _emissor("SangueDoVidro", gota, 360, 1.8, 0.8, 3.2, 30.0, 0.7, 2.2, true, false)
	# O queixo pinga, nao chove: uns seis pingos por segundo.
	_pingos = _emissor("Pingos", pingo, 30, 5.0, 0.0, 0.08, 6.0, 0.7, 1.5, true, false)
	_pingos.one_shot = false
	_pingos.explosiveness = 0.0
	_pingos.randomness = 0.6
	visible = false


func _emissor(nome: String, malha: Mesh, quantas: int, vida: float, v0: float, v1: float,
		espalha: float, e0: float, e1: float, alinha: bool, gira: bool) -> GPUParticles3D:
	var ps := GPUParticles3D.new()
	ps.name = nome
	ps.amount = quantas
	ps.lifetime = vida
	ps.one_shot = true
	ps.explosiveness = 0.92
	ps.local_coords = false
	ps.emitting = false
	ps.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.012
	p.direction = Vector3.FORWARD
	p.spread = espalha
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.gravity = GRAVIDADE
	p.damping_min = 0.4
	p.damping_max = 1.2
	p.scale_min = e0
	p.scale_max = e1
	p.particle_flag_align_y = alinha
	if gira:
		p.angular_velocity_min = -720.0
		p.angular_velocity_max = 720.0
		p.particle_flag_rotate_y = true
	p.collision_mode = ParticleProcessMaterial.COLLISION_DISABLED
	ps.process_material = p
	ps.draw_pass_1 = malha
	add_child(ps)
	return ps


func aquecer(ligar: bool, onde: Vector3) -> void:
	visible = ligar
	for ps: GPUParticles3D in [_esguicho, _pedacos, _coagulos, _do_vidro, _pingos]:
		ps.global_position = onde
		if ligar:
			ps.restart()
			ps.emitting = true
		else:
			ps.emitting = false


## Um golpe: o esguicho sai de `onde` (mundo) em volta de `para` (a direcao do
## espirro), com `forca` 0 a 1. `pedacos` solta carne e coagulo junto.
func golpe(onde: Vector3, para: Vector3, forca: float, pedacos: bool) -> void:
	visible = true
	_disparar(_esguicho, onde, para, lerpf(0.35, 1.0, forca), 1.0 + forca * 0.4)
	if pedacos:
		_disparar(_pedacos, onde, para, lerpf(0.4, 1.0, forca), 1.0)
		_disparar(_coagulos, onde, para, lerpf(0.4, 1.0, forca), 1.0)


## O vidro estourou: o sangue que estava nele (`caixa`, em mundo, em volta das
## marcas) cai junto com os cacos, na direcao `para`.
func do_vidro(centro: Vector3, meia: Vector3, base: Basis, para: Vector3) -> void:
	visible = true
	var p := _do_vidro.process_material as ParticleProcessMaterial
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.emission_box_extents = meia
	_do_vidro.global_transform = Transform3D(base, centro)
	p.direction = (base.inverse() * para).normalized()
	_do_vidro.restart()
	_do_vidro.emitting = true


func _disparar(ps: GPUParticles3D, onde: Vector3, para: Vector3, quanto: float, vel: float) -> void:
	var p := ps.process_material as ParticleProcessMaterial
	ps.global_transform = Transform3D(Basis(), onde)
	p.direction = para.normalized()
	ps.amount_ratio = clampf(quanto, 0.05, 1.0)
	ps.speed_scale = vel
	ps.restart()
	ps.emitting = true


## O queixo (ou a orbita) pingando: `no` e o osso/no que carrega o ponto, e
## `local` o ponto nele. `false` para.
func pingar(no: Node3D, local: Vector3, ligar: bool = true) -> void:
	visible = true
	_pingar_de = no if ligar else null
	_pingar_local = local
	_pingos.emitting = ligar


func desligar() -> void:
	set_process(false)
	visible = false
	for ps: GPUParticles3D in [_esguicho, _pedacos, _coagulos, _do_vidro, _pingos]:
		ps.emitting = false


func _process(_delta: float) -> void:
	if _pingar_de != null and is_instance_valid(_pingar_de):
		_pingos.global_position = _pingar_de.global_transform * _pingar_local
		(_pingos.process_material as ParticleProcessMaterial).direction = Vector3.DOWN
