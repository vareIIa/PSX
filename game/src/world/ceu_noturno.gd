## Ceu noturno com estrelas e lua. Segue a camera como a chuva.
##
## Estrelas sao GPUParticles3D com quads minusculos espalhados numa esfera
## grande centrada na camera. A rotacao da camera move as estrelas para o lugar
## certo (cima = ceu, frente = horizonte) sem que elas girem com a cabeca.
##
## A lua e um MeshInstance3D simples posicionado numa direcao fixa, com shader
## proprio. A posicao relativa a camera e re-calculada todo frame para que a lua
## fique sempre no mesmo lugar do ceu independente de onde o jogador esta.
##
## Ambos so ficam visiveis quando o preset ativo tem tem_estrelas = true ou
## tem_lua = true. Ativacao/desativacao e instantanea — nao ha transicao,
## porque a troca de clima e uma escolha de debug/menu.
class_name CeuNoturno
extends Node3D

const SHADER_ESTRELAS := "res://shaders/psx_estrelas.gdshader"
const SHADER_LUA := "res://shaders/psx_lua.gdshader"

## Teto do raio da esfera de estrelas, em metros. O valor em uso e menor quando
## a camera nao enxerga tao longe — ver `_raio()`.
const RAIO_CEU_MAX := 320.0
## Fracao do `far` da camera em que o ceu e desenhado. Precisa sobrar folga:
## exatamente no far o quad e cortado pelo proprio plano.
const FRACAO_FAR := 0.88
## Altitude fixa da lua no ceu. 0 = horizonte, 90 = zênite.
##
## Tem que caber na metade de cima do enquadramento: a camera do jogo abre 66
## graus na vertical, entao tudo acima de ~33 graus esta fora da tela para quem
## olha reto. A 38 graus a lua nascia acima da borda de cima e nunca aparecia.
const ALTITUDE_LUA := 21.0
## Azimute da lua (direcao horizontal em graus). 0 = norte, 90 = leste.
## A rua corre no eixo -Z, que e para onde o jogador olha ao nascer; a lua fica
## nesse lado do ceu. No valor antigo ela ficava atras da cabeca do jogador.
const AZIMUTE_LUA := 196.0
## Tamanho visual do disco da lua em metros.
const TAMANHO_LUA := 18.0

## Quantidade de estrelas. Ajuste de arte.
@export_range(100, 2000, 50) var quantidade_estrelas: int = 650
## Node3D seguido. Vazio faz o ceu procurar a camera ativa.
@export var alvo: Node3D

var _estrelas: GPUParticles3D
var _lua: MeshInstance3D
var _mat_estrelas: ShaderMaterial
var _mat_lua: ShaderMaterial
var _rng := RandomNumberGenerator.new()
## Raio em uso. Recalculado quando a camera muda de far.
var _raio_atual: float = 0.0


## Raio em que o ceu e desenhado.
##
## Nao e constante porque a camera do jogo tem `far = 220 m`: estrela nascida a
## 320 m cai inteira atras do plano de corte e nao chega a ser desenhada. Era
## por isso que a noite estrelada era um ceu preto liso. O ceu se ajusta a
## camera em vez de a camera ao ceu — quem desenha longe demais some.
func _raio(cam: Camera3D) -> float:
	if cam == null:
		return RAIO_CEU_MAX
	# Com o anel distante (Horizonte) o ceu mora alem da cidade de longe.
	return minf(maxf(RAIO_CEU_MAX, Horizonte.ceu_minimo), cam.far * FRACAO_FAR)



const FOG_GROUP := &"fog_controller"

## FogController da cena. E ele, nao Settings, que sabe o clima em vigor:
## dentro de um interior o controller impoe um preset proprio e a escolha de rua
## do jogador nao vale mais.
var _fog: FogController


## Liga este no ao preset em vigor. Sem controller na cena (cena de teste solta)
## cai em Settings, que ao menos reflete a escolha do jogador.
func _seguir_fog() -> void:
	_fog = get_tree().get_first_node_in_group(FOG_GROUP) as FogController
	if _fog != null:
		_fog.preset_applied.connect(_aplicar_preset)
	else:
		Settings.changed.connect(_aplicar_preset_de_settings)


func _aplicar_preset_de_settings() -> void:
	_aplicar_preset(Settings.fog_preset())


func _preset_ativo() -> FogPreset:
	return _fog.preset_atual() if _fog != null else Settings.fog_preset()

func _ready() -> void:
	_montar_estrelas()
	_montar_lua()
	_seguir_fog()
	_aplicar_preset(_preset_ativo())


func _montar_estrelas() -> void:
	_estrelas = GPUParticles3D.new()
	_estrelas.name = "Estrelas"
	_estrelas.amount = quantidade_estrelas
	# Estrelas sao estaticas: vida longa, sem reemissao constante.
	_estrelas.lifetime = 9999.0
	_estrelas.one_shot = false
	_estrelas.explosiveness = 1.0
	_estrelas.randomness = 0.0
	_estrelas.fixed_fps = 0
	_estrelas.local_coords = false

	var proc := ParticleProcessMaterial.new()
	# Casca da esfera, nao o volume: `EMISSION_SHAPE_SPHERE` preenche a bola
	# inteira e espalharia estrelas a dois metros do nariz do jogador e sob o
	# asfalto. Estrela mora na casca, toda a mesma distancia.
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	proc.emission_sphere_radius = RAIO_CEU_MAX
	proc.direction = Vector3.ZERO
	proc.spread = 0.0
	proc.gravity = Vector3.ZERO
	proc.initial_velocity_min = 0.0
	proc.initial_velocity_max = 0.0
	# Cor cheia e sem rampa. A rampa que estava aqui variava a cor ao longo da
	# VIDA da particula, nao de estrela para estrela: como toda estrela nasce no
	# mesmo instante e vive 9999 s, todas ficavam paradas no primeiro tom da
	# rampa — alfa 0,3 sobre um ceu quase preto, que o grao do pos-processo
	# engolia. A diferenca de magnitude vem do tamanho, que ja e sorteado por
	# particula em scale_min/scale_max.
	proc.color = Color(0.92, 0.95, 1.0, 1.0)
	# O tamanho e ditado pela resolucao interna, nao pelo gosto. A 193 m, num
	# framebuffer de 480x270 com 66 graus de abertura, cada grau vale 4 px: o
	# quad de 0,36 m da versao anterior dava 0,4 px e nao sobrevivia a
	# rasterizacao. Aqui as estrelas ficam entre 2 e 5 px, que e o ponto de luz
	# do PS1 — visivel, e ainda assim ponto.
	proc.scale_min = 0.6
	proc.scale_max = 1.6
	# Sem AABB explicito o no e descartado pelo culling: o padrao do
	# GPUParticles3D e um cubo de 8 m, e as estrelas estao a centenas de metros.
	_estrelas.visibility_aabb = AABB(
		Vector3.ONE * -RAIO_CEU_MAX, Vector3.ONE * RAIO_CEU_MAX * 2.0)
	_estrelas.process_material = proc

	var quad := QuadMesh.new()
	quad.size = Vector2(2.4, 2.4)
	_estrelas.draw_pass_1 = quad

	_mat_estrelas = ShaderMaterial.new()
	if ResourceLoader.exists(SHADER_ESTRELAS):
		_mat_estrelas.shader = load(SHADER_ESTRELAS)
	else:
		push_error("CeuNoturno: shader ausente em %s" % SHADER_ESTRELAS)
	# Ponto de luz tem que vencer o grao do pos-processo, senao vira ruido.
	_mat_estrelas.set_shader_parameter(&"brilho", 1.5)
	_estrelas.material_override = _mat_estrelas

	add_child(_estrelas)


func _montar_lua() -> void:
	_lua = MeshInstance3D.new()
	_lua.name = "Lua"
	_lua.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var quad := QuadMesh.new()
	quad.size = Vector2(TAMANHO_LUA, TAMANHO_LUA)
	_lua.mesh = quad

	_mat_lua = ShaderMaterial.new()
	if ResourceLoader.exists(SHADER_LUA):
		_mat_lua.shader = load(SHADER_LUA)
	else:
		push_error("CeuNoturno: shader ausente em %s" % SHADER_LUA)
	_lua.material_override = _mat_lua

	add_child(_lua)


func _aplicar_preset(preset: FogPreset) -> void:
	if preset == null:
		return
	_estrelas.visible = preset.tem_estrelas
	_lua.visible = preset.tem_lua

	# Cor da lua segue a cor do sol_cor do preset (que e a luz lunar no clima).
	if _mat_lua != null:
		_mat_lua.set_shader_parameter(&"cor_lua", preset.sol_cor)


func _process(_delta: float) -> void:
	var seguido := alvo
	if seguido == null:
		seguido = get_viewport().get_camera_3d()
	if seguido == null:
		return

	var cam := get_viewport().get_camera_3d()
	var raio := _raio(cam)
	if not is_equal_approx(raio, _raio_atual):
		_raio_atual = raio
		var proc := _estrelas.process_material as ParticleProcessMaterial
		# Alem do teto de sempre (so com o Horizonte), estrela e lua crescem na
		# mesma razao do raio: o angulo delas fica o mesmo.
		var k := maxf(1.0, raio / RAIO_CEU_MAX)
		if proc != null:
			proc.emission_sphere_radius = raio
			proc.scale_min = 0.6 * k
			proc.scale_max = 1.6 * k
			_estrelas.visibility_aabb = AABB(Vector3.ONE * -raio, Vector3.ONE * raio * 2.0)
			_estrelas.restart()
		_lua.scale = Vector3.ONE * k

	# Estrelas: centralizar na camera para que o ceu sempre envolva o jogador.
	# A rotacao da camera DEVE ser preservada para as estrelas ficarem no lugar
	# certo ao olhar para cima — ao contrario da chuva, que nao deve girar.
	_estrelas.global_position = seguido.global_position

	# Lua: posicao fixa no ceu calculada por altitude e azimute.
	var rad_alt := deg_to_rad(ALTITUDE_LUA)
	var rad_az := deg_to_rad(AZIMUTE_LUA)
	var dir_lua := Vector3(
		cos(rad_alt) * sin(rad_az),
		sin(rad_alt),
		cos(rad_alt) * cos(rad_az)
	)
	_lua.global_position = seguido.global_position + dir_lua * _raio_atual * 0.92
	# A lua sempre olha para a camera (billboarding manual).
	_lua.look_at(seguido.global_position, Vector3.UP)
