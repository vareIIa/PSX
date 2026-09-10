## Aplica o FogPreset ativo ao ambiente. Anexe a um WorldEnvironment.
##
## A nevoa mora no Environment e nao num shader de superficie porque precisa
## incidir depois da iluminacao. Ver docs/ART-BIBLE.md secao 8.
##
## Tambem gerencia uma DirectionalLight3D interna que simula sol (dia) ou lua
## (noite). A energia e angulo vem do FogPreset para que cada clima tenha sua
## iluminacao propria sem precisar de nos extras na cena.
class_name FogController
extends WorldEnvironment


## A nevoa da Praca da Matriz, num lugar so.
##
## Mora aqui, e nao em `abertura.gd`, porque quem forca esta nevoa sao DOIS
## arquivos: o roteiro da abertura e a `cidade.gd`, que precisa dela tambem no
## caminho sem cutscene (`--ir-para=270`). Posta em `Abertura`, a `cidade.gd`
## passava a depender da classe `Abertura` em tempo de compilacao e as duas
## fechavam ciclo — o projeto inteiro parava de carregar com "Cannot infer the
## type". `FogController` ja e dependencia das duas, entao aqui nao cria aresta
## nova.
##
## Preset proprio, e nao `noite_nublada`: aquele tem ceu 0,086, que na tela da
## 10 de 255. Medido em `PRINTS/ref_praca_matriz/01_acordar.png` o ceu da 37 e
## a nevoa ao fundo da 50 — na print a praca e ILUMINADA PELA NEVOA e o casario
## do fundo se dissolve em cinza claro em vez de sumir no preto.
const PRESET_PRACA := "res://resources/fog/fog_praca_noite.tres"

## Quando ligado, segue o preset escolhido pelo jogador em Settings.
## Desligue em interior, onde a nevoa e sempre off e a grade e propria.
@export var follow_settings: bool = true

## Preset usado quando follow_settings esta desligado.
@export var override_preset: FogPreset

## Se este controller responde por `get_first_node_in_group(&"fog_controller")`.
##
## O jogo inteiro descobre o clima em vigor por esse grupo, e a busca e na ARVORE
## toda — nao no World3D. Entao um segundo controller num SubViewport de mundo
## proprio (o fundo da criacao de personagem e um) passaria a atender pelo clima
## da rua, e a cidade inteira poderia acordar com a nevoa de outro lugar.
##
## Quem monta um ambiente fechado desliga isto e entrega o controller a mao a
## quem precisa dele — ver `CeuEstrada.fog`.
@export var registrar_global: bool = true

## Raio de streaming em metros do preset em uso. O ChunkManager le daqui.
var stream_radius: float = 64.0

## Preset imposto por cima de tudo. Nulo devolve o controle ao jogador.
var _forcado: FogPreset

## Luz direcional (sol ou lua) gerenciada por este controller.
var _luz_direcional: DirectionalLight3D

signal preset_applied(preset: FogPreset)


func _ready() -> void:
	if registrar_global:
		add_to_group(&"fog_controller")
	if environment == null:
		environment = Environment.new()
	_montar_luz_direcional()
	if follow_settings:
		Settings.changed.connect(_on_settings_changed)
	_apply()


func _montar_luz_direcional() -> void:
	_luz_direcional = DirectionalLight3D.new()
	_luz_direcional.name = "LuzDirecional"
	# ART-BIBLE secao 7: sem sombra dinamica no estilo PS1.
	_luz_direcional.shadow_enabled = false
	_luz_direcional.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(_luz_direcional)


func _on_settings_changed() -> void:
	_apply()


func _apply() -> void:
	var preset := _resolve_preset()
	if preset == null:
		push_error("FogController em %s: nenhum preset resolvido" % name)
		return

	var env := environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = preset.sky_color

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = preset.ambient_color
	env.ambient_light_energy = preset.ambient_energy

	env.fog_enabled = preset.fog_enabled
	if preset.fog_enabled:
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_depth_begin = preset.fog_begin
		env.fog_depth_end = preset.fog_end
		env.fog_depth_curve = 1.0
		env.fog_light_color = preset.fog_color
		env.fog_light_energy = 1.0
		env.fog_density = 1.0

	# Nada de glow, SSAO ou SSR. O PS1 nao tinha e eles modernizam o look na hora.
	env.glow_enabled = false
	env.ssao_enabled = false
	env.ssr_enabled = false
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false

	# Aplica a luz direcional (sol ou lua) do preset.
	_aplicar_luz_direcional(preset)

	stream_radius = preset.stream_radius
	# O streaming corta o desenho no fim da nevoa, entao ele precisa do preset
	# EM VIGOR e nao do escolhido no menu: um lugar que impoe outro clima por
	# `forcar` muda o quanto se enxerga, e o corte tem de acompanhar. Sem isto,
	# entrar numa cena de dia claro mantinha o corte da nevoa fechada do menu e
	# a rua acabava a vinte metros, sem nevoa nenhuma para esconder o corte.
	#
	# So o controller global fala pelo mundo: o de um SubViewport (o fundo da
	# criacao de personagem) nao manda no streaming da rua.
	if registrar_global:
		ChunkManager.usar_preset(preset)
	preset_applied.emit(preset)


## Configura a DirectionalLight3D conforme o clima.
## Em climas diurnos e uma luz solar quente; em climas noturnos e a lua fria.
func _aplicar_luz_direcional(preset: FogPreset) -> void:
	if _luz_direcional == null:
		return
	_luz_direcional.light_energy = preset.sol_energia
	_luz_direcional.light_color = preset.sol_cor
	# sol_rotacao.x = elevacao em graus (negativo = vindo de cima do horizonte)
	# sol_rotacao.y = azimute em graus (direcao horizontal)
	_luz_direcional.rotation_degrees = Vector3(
		preset.sol_rotacao.x,
		preset.sol_rotacao.y,
		0.0
	)


## Impoe um preset por cima da escolha do jogador. Usado ao entrar num interior,
## onde a nevoa da rua nao faz sentido e o ambiente e propriedade do lugar.
func forcar(caminho: String) -> void:
	if not ResourceLoader.exists(caminho):
		push_error("FogController: preset ausente %s" % caminho)
		return
	_forcado = load(caminho) as FogPreset
	_apply()


## Preset em vigor agora, ja considerando o que um interior tenha imposto por
## `forcar`. Quem depende do clima — chuva, nuvens, ceu noturno — le daqui e
## escuta `preset_applied`, nunca Settings direto: Settings so sabe a escolha do
## jogador para a rua e ignora o preset forcado do lugar onde ele esta.
func preset_atual() -> FogPreset:
	return _resolve_preset()


## Id do preset em vigor agora. Serve a verificacao automatizada, que precisa
## afirmar que entrar num lugar trocou o ambiente de verdade.
func preset_ativo() -> StringName:
	var p := _resolve_preset()
	return p.id if p != null else &""


func liberar() -> void:
	_forcado = null
	_apply()


func _resolve_preset() -> FogPreset:
	if _forcado != null:
		return _forcado
	if follow_settings:
		return Settings.fog_preset()
	return override_preset
