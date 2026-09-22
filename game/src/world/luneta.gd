## A luneta publica do mirante: [E] para olhar a cidade la embaixo.
##
## A malha e do chunk (MiranteBuilder._luneta); aqui mora so o que responde ao
## jogador. O modelo e o do controle do PS2 (ControlePS2): pegar prende o corpo
## atras da ocular, fecha a lente e toma a entrada; largar devolve tudo como
## estava.
##
##     mouse        mira, num arco em volta de para onde a luneta aponta
##     roda         aproxima e afasta
##     [E] / [Esc]  largar
##
## A vista em si e do Mirante: a nevoa ja esta aberta quando o jogador chega no
## terraco, e a luneta so aproxima o que a nevoa deixa ver.
class_name Luneta
extends Interativo

## Para onde a luneta aponta (o +Z local girado), como o `giro` do terraco.
@export var giro: float = 0.0
## Altura da ocular acima do pe da luneta (MiranteBuilder.ALTURA_LUNETA + ocular).
const OCULAR := 1.3
## Onde o corpo fica: atras da ocular, no sentido contrario ao da vista.
const ATRAS := 0.5
## O plano de corte perto da camera, na lente. A cabeca da luneta e malha do
## chunk e fica entre o olho e a vista: cortando ate aqui, ela some da imagem e
## o peitoril (a 1,1 m) continua.
const CORTE_PERTO := 0.9
## Lente: comeca em ZOOM_INICIAL graus e a roda anda entre ZOOM_MAXIMO e
## ZOOM_MINIMO, em passos multiplicativos (cada clique e o mesmo tanto de zoom).
const ZOOM_INICIAL := 15.0
const ZOOM_MAXIMO := 6.0
const ZOOM_MINIMO := 26.0
const PASSO_ZOOM := 1.18
## O arco da mira em volta do eixo da luneta. Ela gira num pivo, e nao solta.
const ARCO := deg_to_rad(80.0)
const PITCH := Vector2(deg_to_rad(-30.0), deg_to_rad(16.0))
## Sensibilidade do mouse na lente, na FOV normal do jogo; ela cai com o zoom
## para a mira nao pular meia cidade por pixel.
const SENSIBILIDADE := 0.0024
const FOV_REFERENCIA := 70.0
const DICA := "[roda] zoom   [E/Esc] largar a luneta"

var _jogador: Node3D
var _antes: Transform3D
var _pitch_antes := 0.0
var _fov := ZOOM_INICIAL
var _yaw := 0.0
var _pitch := 0.0
var _mascara: CanvasLayer
var _perto_antes := -1.0
## O jogador estava em terceira pessoa: a lente e de primeira, e na saida volta.
var _estava_de_fora := false


func _ready() -> void:
	super()
	rotulo = "Olhar pela luneta"
	add_to_group(&"luneta")
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(0.9, 1.7, 0.9)
	forma.shape = caixa
	forma.position = Vector3(0.0, 0.85, 0.0)
	add_child(forma)
	acionado.connect(_pegar)
	set_process_input(false)


## Para onde a luneta aponta, em yaw do jogador (que olha para o -Z dele).
func _yaw_do_eixo() -> float:
	return giro + PI


func _pegar(quem: Node) -> void:
	var j := quem as Node3D
	if _jogador != null or j == null or not j.has_method("travar"):
		return
	if j.has_method("dirigindo") and bool(j.call("dirigindo")):
		return
	_jogador = j
	_antes = j.global_transform
	_pitch_antes = float(j.call("pitch_atual")) if j.has_method("pitch_atual") else 0.0
	var frente := Vector3(sin(giro), 0.0, cos(giro))
	var onde := global_position - frente * ATRAS
	onde.y = j.global_position.y
	j.global_position = onde
	j.call("definir_olho", global_position.y + OCULAR - onde.y)
	j.call("travar", true)
	_estava_de_fora = _de_fora(j)
	if _estava_de_fora:
		j.call("_alternar_camera")
	_fov = ZOOM_INICIAL
	j.call("definir_fov", _fov)
	var cam := _camera()
	if cam != null:
		_perto_antes = cam.near
		cam.near = CORTE_PERTO
	_yaw = _yaw_do_eixo()
	_pitch = deg_to_rad(-4.0)
	_aplicar_mira()
	if j.has_method("ocupar"):
		j.call("ocupar", DICA, Callable(self, "_largar"))
	habilitado = false
	set_process_input(true)
	_mostrar_mascara(true)
	AudioDirector.tocar_ui(&"clique", -8.0)


func _largar() -> void:
	if _jogador == null:
		return
	var j := _jogador
	_jogador = null
	var cam := _camera(j)
	if cam != null and _perto_antes > 0.0:
		cam.near = _perto_antes
	_perto_antes = -1.0
	if is_instance_valid(j):
		j.global_transform = _antes
		j.call("liberar_olho")
		j.call("liberar_fov")
		if j.has_method("definir_pitch"):
			j.call("definir_pitch", _pitch_antes)
		j.call("travar", false)
		if j.has_method("desocupar"):
			j.call("desocupar")
		if _estava_de_fora and not _de_fora(j):
			j.call("_alternar_camera")
	_estava_de_fora = false
	habilitado = true
	set_process_input(false)
	_mostrar_mascara(false)
	AudioDirector.tocar_ui(&"clique", -12.0)


func _exit_tree() -> void:
	# O chunk descarregando (teleporte, save) com o jogador na lente: devolve o
	# corpo antes de sumir, senao ele fica preso sem ninguem para soltar.
	_largar()


func _input(evento: InputEvent) -> void:
	if _jogador == null:
		return
	if evento.is_action_pressed("pausa"):
		_largar()
	elif evento is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := evento as InputEventMouseMotion
		var s := SENSIBILIDADE * _fov / FOV_REFERENCIA
		_yaw -= mm.relative.x * s
		_pitch -= mm.relative.y * s
		_aplicar_mira()
	elif evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed:
		var botao := (evento as InputEventMouseButton).button_index
		if botao == MOUSE_BUTTON_WHEEL_UP:
			_fov = maxf(ZOOM_MAXIMO, _fov / PASSO_ZOOM)
		elif botao == MOUSE_BUTTON_WHEEL_DOWN:
			_fov = minf(ZOOM_MINIMO, _fov * PASSO_ZOOM)
		else:
			return
		_jogador.call("definir_fov", _fov)
	else:
		return
	get_viewport().set_input_as_handled()


## A camera esta no braco de terceira pessoa? O Player nao expoe o modo; quem
## sabe e o CameraRig, pai da camera.
func _de_fora(j: Node3D) -> bool:
	var cam := _camera(j)
	var no: Node = cam.get_parent() if cam != null else null
	while no != null and no != j:
		if "terceira_pessoa" in no:
			return bool(no.get("terceira_pessoa"))
		no = no.get_parent()
	return false


func _camera(j: Node3D = _jogador) -> Camera3D:
	if j == null or not is_instance_valid(j) or not j.has_method("camera"):
		return null
	return j.call("camera") as Camera3D


## Prende a mira no arco e poe no jogador: o yaw e o do corpo, o pitch o da
## cabeca, como no andar.
func _aplicar_mira() -> void:
	var eixo := _yaw_do_eixo()
	_yaw = eixo + clampf(wrapf(_yaw - eixo, -PI, PI), -ARCO * 0.5, ARCO * 0.5)
	_pitch = clampf(_pitch, PITCH.x, PITCH.y)
	_jogador.rotation.y = _yaw
	_jogador.call("definir_pitch", _pitch)


## As duas lentes: o quadro vira dois circulos que se cruzam, com a borda
## escurecendo. Uma camada so, criada na primeira vez.
func _mostrar_mascara(ligada: bool) -> void:
	if ligada and _mascara == null:
		_mascara = CanvasLayer.new()
		_mascara.layer = 90
		var tela := ColorRect.new()
		tela.set_anchors_preset(Control.PRESET_FULL_RECT)
		tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = _shader_mascara()
		tela.material = mat
		_mascara.add_child(tela)
		get_tree().root.add_child(_mascara)
	if _mascara != null:
		_mascara.visible = ligada


func _notification(o: int) -> void:
	if o == NOTIFICATION_PREDELETE and _mascara != null and is_instance_valid(_mascara):
		_mascara.queue_free()


static var _shader: Shader

static func _shader_mascara() -> Shader:
	if _shader != null:
		return _shader
	_shader = Shader.new()
	_shader.code = """
shader_type canvas_item;

// Duas lentes lado a lado, em proporcao da ALTURA da tela: o par fica redondo em
// qualquer janela. A borda tem meia lente de degrade escuro (vinheta da ocular)
// e a sobra e preto.
void fragment() {
	vec2 tam = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = (FRAGCOORD.xy - tam * 0.5) / tam.y;
	float r = 0.47;
	float sep = 0.21;
	float d = min(length(p - vec2(-sep, 0.0)), length(p - vec2(sep, 0.0)));
	float dentro = 1.0 - smoothstep(r - 0.012, r, d);
	float vinheta = smoothstep(r * 0.55, r, d) * 0.55;
	float escuro = 1.0 - dentro * (1.0 - vinheta);
	COLOR = vec4(0.0, 0.0, 0.0, escuro);
}
"""
	return _shader
