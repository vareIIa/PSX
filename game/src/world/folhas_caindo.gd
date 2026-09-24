## Folha caindo das copas da rua (PLANO_FLORA_AAA, rodada 2).
##
## A copa ja balanca em tres camadas (psx_folha_pixel) e a grama se dobra com a
## rajada; o que faltava para a rua de agosto em Minas era a folha seca que
## solta do oiti e da sibipiruna e desce rodando ate a calcada. Um emissor de
## particula por arvore PERTO do jogador (as arvores de calcada do ChunkBuilder,
## lista publica e sem sorteio), poucas folhas por arvore, mais na seca
## (Estacao). A folha deriva na direcao do vento das copas (VENTO_DIR do shader).
##
## Filho da GramaViva: some junto com ela no PS1 STYLE. `--sem-folhas-caindo`
## desliga.
class_name FolhasCaindo
extends Node3D

## Emissores ao mesmo tempo: as arvores mais perto do jogador.
const EMISSORES := 10
const RAIO := 30.0
## Onde a folha solta: embaixo da copa da arvore de calcada (porte pequeno).
const ALTURA_COPA := 4.0
const TEXTURA := "res://assets/textures_hd/folhas_soltas.png"
## A direcao do vento das copas (psx_folha_pixel.gdshader, VENTO_DIR).
const VENTO := Vector2(0.82, 0.57)

var _livres: Array[GPUParticles3D] = []
## Chave da arvore (posicao arredondada) -> emissor.
var _usados: Dictionary = {}
var _cache: Dictionary = {}
var _relogio := 0.0
var _processo: ParticleProcessMaterial
var _malha: QuadMesh


func _ready() -> void:
	name = "FolhasCaindo"
	if OS.get_cmdline_user_args().has("--sem-folhas-caindo"):
		set_process(false)
		return
	_processo = _material_de_processo()
	_malha = _folha()
	for i in EMISSORES:
		var e := GPUParticles3D.new()
		e.amount = 6
		e.lifetime = 7.0
		e.preprocess = 7.0
		e.randomness = 1.0
		e.explosiveness = 0.0
		e.local_coords = false
		e.emitting = false
		e.process_material = _processo
		e.draw_pass_1 = _malha
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		e.visibility_aabb = AABB(Vector3(-6.0, -6.0, -6.0), Vector3(12.0, 9.0, 12.0))
		add_child(e)
		_livres.append(e)


func _process(delta: float) -> void:
	_relogio -= delta
	if _relogio > 0.0 or not is_visible_in_tree():
		return
	_relogio = 0.5
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position
	var cx := floori(p.x / ChunkBuilder.TAM)
	var cz := floori(p.z / ChunkBuilder.TAM)
	var perto: Array[Vector3] = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for a: Vector3 in _arvores(cx + dx, cz + dz):
				if Vector2(a.x - p.x, a.z - p.z).length() < RAIO:
					perto.append(a)
	perto.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return Vector2(a.x - p.x, a.z - p.z).length_squared() < Vector2(b.x - p.x, b.z - p.z).length_squared())
	perto.resize(mini(perto.size(), EMISSORES))
	var quero := {}
	for a: Vector3 in perto:
		quero[Vector3i(roundi(a.x * 10.0), 0, roundi(a.z * 10.0))] = a
	# Solta o emissor da arvore que ficou longe (a folha que ja caiu termina de
	# cair: as particulas estao no mundo, nao no emissor).
	for k: Vector3i in _usados.keys():
		if not quero.has(k):
			var e: GPUParticles3D = _usados[k]
			e.emitting = false
			_usados.erase(k)
			_livres.append(e)
	var ritmo := 0.3 + 0.7 * Estacao.seca()
	for k: Vector3i in quero:
		if _usados.has(k) or _livres.is_empty():
			continue
		var e: GPUParticles3D = _livres.pop_back()
		e.global_position = (quero[k] as Vector3) + Vector3(0.0, ALTURA_COPA, 0.0)
		e.amount_ratio = ritmo
		e.emitting = true
		_usados[k] = e


## As arvores de calcada do chunk, no mundo, com o pe no relevo.
func _arvores(cx: int, cz: int) -> Array[Vector3]:
	var chave := Vector2i(cx, cz)
	if _cache.has(chave):
		return _cache[chave]
	var saida: Array[Vector3] = []
	for b: Vector3 in ChunkBuilder.arvores(cx, cz):
		var x := float(cx) * ChunkBuilder.TAM + b.x
		var z := float(cz) * ChunkBuilder.TAM + b.z
		saida.append(Vector3(x, Relevo.altura(x, z), z))
	if _cache.size() > 64:
		_cache.clear()
	_cache[chave] = saida
	return saida


func _material_de_processo() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(1.8, 0.8, 1.8)
	m.direction = Vector3(VENTO.x, -0.4, VENTO.y)
	m.spread = 35.0
	m.initial_velocity_min = 0.1
	m.initial_velocity_max = 0.5
	# Cai devagar e deriva com o vento: a folha plana plana.
	m.gravity = Vector3(VENTO.x * 0.35, -1.1, VENTO.y * 0.35)
	m.damping_min = 0.6
	m.damping_max = 1.2
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 1.6
	m.turbulence_noise_scale = 2.5
	m.turbulence_influence_min = 0.06
	m.turbulence_influence_max = 0.16
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.angular_velocity_min = -170.0
	m.angular_velocity_max = 170.0
	m.scale_min = 0.8
	m.scale_max = 1.3
	# Uma das tres folhas (a quarta celula e a trombeta do ipe, fora daqui).
	m.anim_offset_min = 0.0
	m.anim_offset_max = 0.74
	# Some no fim da vida, ja no chao, em vez de sumir no ar.
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 1.0))
	curva.add_point(Vector2(0.85, 1.0))
	curva.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curva
	m.scale_curve = ct
	return m


func _folha() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(TEXTURA) as Texture2D
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.particles_anim_h_frames = 2
	mat.particles_anim_v_frames = 2
	mat.particles_anim_loop = false
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.roughness = 0.8
	mat.backlight_enabled = true
	mat.backlight = Color(0.5, 0.45, 0.2)
	q.material = mat
	return q
