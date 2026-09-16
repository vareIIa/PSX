## O leque de agua que a roda levanta do asfalto molhado.
##
## Por que isto importa mais do que parece
## ---------------------------------------
## O carro ja escurece e reflete na chuva, porque a carroceria usa o mesmo
## material de superficie que a rua. Mas ate aqui ele atravessava a agua sem
## deslocar nenhuma: dirigir na cidade encharcada era igual a dirigir na seca. O
## spray e a primeira coisa que liga as duas simulacoes — e o sinal que o olho
## usa para saber que o chao esta molhado mesmo sem olhar para baixo.
##
## Sai da roda de TRAS, e nao das quatro. Na traseira o leque abre atras do carro
## e fica em quadro na camera de perseguicao; na dianteira ele nasce debaixo da
## lataria e some sem nunca ser visto, custando o mesmo.
class_name SprayRoda
extends Node3D

const SHADER := "res://shaders/psx_chuva.gdshader"

## Abaixo desta velocidade a roda nao tem energia para levantar lamina, em m/s.
## Quatro metros por segundo sao 14 km/h — abaixo disso a agua escorre, nao voa.
const VEL_MINIMA := 4.0
## Velocidade em que o leque ja esta no maximo, em m/s. 20 m/s = 72 km/h.
const VEL_CHEIA := 20.0
## Abaixo deste molhado nao ha lamina para levantar.
const MOLHADO_MINIMO := 0.3
## Particulas no leque cheio, por roda.
const QUANTIDADE := 460

var _emissores: Array[GPUParticles3D] = []
var _mats: Array[ShaderMaterial] = []
var _carro: Node3D
var _rodas: Array[VehicleWheel3D] = []

## `--debug-agua` diz por que o leque NAO esta saindo.
##
## Tres portoes em serie (agua no chao, velocidade, estilo) e nenhum deles da
## erro quando fecha. Procurar isso a olho custou tempo demais em efeitos
## anteriores desta mesma fase; a pergunta "esta ligado, e se nao, qual portao"
## merece resposta em uma linha.
static var _debug: int = -1
var _relatou: bool = false


static func _quer_debug() -> bool:
	if _debug < 0:
		_debug = 1 if OS.get_cmdline_user_args().has("--debug-agua") else 0
	return _debug == 1


## Mesma assinatura do RastroPneu, de proposito: os dois acompanham as mesmas
## rodas a partir do mesmo ponto do Carro, e quem le um le o outro sem traduzir.
func acompanhar(c: Node3D, rodas: Array[VehicleWheel3D]) -> void:
	_carro = c
	_rodas.clear()
	# As duas de tras. O `_montar_rodas` do Carro cria frente nos indices 0 e 1.
	for k in rodas.size():
		if k >= 2:
			_rodas.append(rodas[k])
	_montar()


func _montar() -> void:
	for e: GPUParticles3D in _emissores:
		e.queue_free()
	_emissores.clear()
	_mats.clear()

	for _k in _rodas.size():
		var p := GPUParticles3D.new()
		p.name = "Spray%d" % _k
		p.lifetime = 0.55
		p.randomness = 1.0
		p.fixed_fps = 30
		p.interpolate = false
		# Coordenadas de MUNDO: a gota sai da roda e fica para tras. Em
		# coordenadas locais ela viajaria junto com o carro, e o leque ficaria
		# colado na roda como um pompom.
		p.local_coords = false
		p.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
		p.visibility_aabb = AABB(Vector3(-3.0, -1.0, -3.0), Vector3(6.0, 3.0, 6.0))
		p.emitting = false

		var proc := ParticleProcessMaterial.new()
		proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		proc.emission_sphere_radius = 0.16
		# Para tras e para cima. O angulo largo e o que faz leque em vez de jato.
		proc.direction = Vector3(0.0, 0.45, 1.0)
		proc.spread = 38.0
		proc.initial_velocity_min = 1.6
		proc.initial_velocity_max = 4.2
		proc.gravity = Vector3(0.0, -9.0, 0.0)
		proc.scale_min = 0.5
		proc.scale_max = 1.2
		p.process_material = proc

		var quad := QuadMesh.new()
		quad.size = Vector2(0.055, 0.095)
		quad.orientation = PlaneMesh.FACE_Z
		p.draw_pass_1 = quad

		var m := ShaderMaterial.new()
		m.shader = load(SHADER)
		m.set_shader_parameter(&"perto", 0.5)
		m.set_shader_parameter(&"longe", 16.0)
		m.set_shader_parameter(&"cor", Color(0.74, 0.79, 0.84, 1.0))
		p.material_override = m

		add_child(p)
		_emissores.append(p)
		_mats.append(m)


func _physics_process(_d: float) -> void:
	if _carro == null or _emissores.is_empty():
		return

	# Tres portoes, e todos precisam estar abertos: tem que haver agua no chao,
	# o carro tem que estar andando, e o estilo tem que ser o MODERNO — no PS1
	# STYLE o preset e a build de antes, e conteudo novo de chuva nao entra.
	var molhado := Clima.molhado_visivel()
	var vel: float = absf(float(_carro.call(&"velocidade")))
	if _quer_debug() and not _relatou:
		_relatou = true
		print("[agua] spray %s: molhado=%.2f (min %.2f) vel=%.1f (min %.1f) pixel=%s"
			% [_carro.name, molhado, MOLHADO_MINIMO, vel, VEL_MINIMA,
				Settings.luz_por_pixel])
	if molhado < MOLHADO_MINIMO or not Settings.luz_por_pixel:
		_desligar()
		return
	if vel < VEL_MINIMA:
		_desligar()
		return

	var f := clampf(inverse_lerp(VEL_MINIMA, VEL_CHEIA, vel), 0.0, 1.0)
	# O molhado entra multiplicando: rua so umida levanta um fiapo, rua
	# encharcada levanta o leque inteiro.
	var forca := f * clampf(inverse_lerp(MOLHADO_MINIMO, 1.0, molhado), 0.0, 1.0)

	for k in _emissores.size():
		var p := _emissores[k]
		var roda := _rodas[k]
		if not is_instance_valid(roda):
			continue
		# Do CHAO, nao do centro da roda: a agua e levantada do asfalto pelo
		# ponto de contato, e nascer no eixo poe o leque na altura do para-lama.
		p.global_position = roda.global_position - Vector3(0.0, roda.wheel_radius * 0.9, 0.0)
		# O leque acompanha a direcao do carro: sem isto ele aponta sempre para o
		# mesmo lado do mundo e o carro na curva joga agua de lado.
		p.global_basis = _carro.global_basis
		p.emitting = true
		p.amount = maxi(12, int(QUANTIDADE * forca))
		_mats[k].set_shader_parameter(&"intensidade", 0.6 + 1.1 * forca)


func _desligar() -> void:
	for p: GPUParticles3D in _emissores:
		p.emitting = false
